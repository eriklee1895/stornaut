import Darwin
import Foundation

public struct RegisteredActionProcessOutput: Sendable, Equatable {
    public let exitStatus: Int32
    public let stdout: Data
    public let stderr: Data
    public let stdoutWasTruncated: Bool
    public let stderrWasTruncated: Bool

    public init(
        exitStatus: Int32,
        stdout: Data,
        stderr: Data,
        stdoutWasTruncated: Bool = false,
        stderrWasTruncated: Bool = false
    ) {
        self.exitStatus = exitStatus
        self.stdout = stdout
        self.stderr = stderr
        self.stdoutWasTruncated = stdoutWasTruncated
        self.stderrWasTruncated = stderrWasTruncated
    }
}

public protocol RegisteredActionRunning: Sendable {
    func run(
        _ invocation: RegisteredActionInvocation
    ) async throws -> RegisteredActionProcessOutput
}

public enum RegisteredActionRunnerError: Error, Sendable, Equatable {
    case launchFailed(String)
    case timedOut
    case outputReadFailed(stream: String, reason: String)
    case terminationFailed(ProcessTreeTerminationError)
}

public struct FoundationRegisteredActionRunner: RegisteredActionRunning {
    public init() {}

    public func run(
        _ invocation: RegisteredActionInvocation
    ) async throws -> RegisteredActionProcessOutput {
        try await runRegisteredAction(invocation)
    }
}

private let registeredActionReaderQueue = DispatchQueue(
    label: "com.eriklee.stornaut.registered-action-reader",
    qos: .userInitiated,
    attributes: .concurrent
)

private func runRegisteredAction(
    _ invocation: RegisteredActionInvocation
) async throws -> RegisteredActionProcessOutput {
    let process = try spawnRegisteredActionWithPipes(invocation)
    let readers = DispatchGroup()
    let stdout = ActionLockedBox(ActionBoundedOutput())
    let stderr = ActionLockedBox(ActionBoundedOutput())

    readers.enter()
    registeredActionReaderQueue.async {
        stdout.set(
            drainActionOutput(
                process.standardOutput,
                limit: invocation.standardOutputLimit
            )
        )
        readers.leave()
    }
    readers.enter()
    registeredActionReaderQueue.async {
        stderr.set(
            drainActionOutput(
                process.standardError,
                limit: invocation.standardErrorLimit
            )
        )
        readers.leave()
    }

    let waitStatus: Int32
    do {
        waitStatus = try await waitForRegisteredAction(
            process.pid,
            timeout: invocation.timeout
        )
    } catch {
        try? process.standardOutput.close()
        try? process.standardError.close()
        throw error
    }

    await withCheckedContinuation { continuation in
        readers.notify(queue: registeredActionReaderQueue) {
            continuation.resume()
        }
    }
    let stdoutValue = stdout.value
    let stderrValue = stderr.value
    if let reason = stdoutValue.readError {
        throw RegisteredActionRunnerError.outputReadFailed(
            stream: "stdout",
            reason: reason
        )
    }
    if let reason = stderrValue.readError {
        throw RegisteredActionRunnerError.outputReadFailed(
            stream: "stderr",
            reason: reason
        )
    }
    return RegisteredActionProcessOutput(
        exitStatus: normalizeRegisteredActionStatus(waitStatus),
        stdout: stdoutValue.data,
        stderr: stderrValue.data,
        stdoutWasTruncated: stdoutValue.wasTruncated,
        stderrWasTruncated: stderrValue.wasTruncated
    )
}

private struct SpawnedRegisteredAction {
    let pid: pid_t
    let standardOutput: FileHandle
    let standardError: FileHandle
}

private func spawnRegisteredActionWithPipes(
    _ invocation: RegisteredActionInvocation
) throws -> SpawnedRegisteredAction {
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    let handles = [
        stdoutPipe.fileHandleForReading,
        stdoutPipe.fileHandleForWriting,
        stderrPipe.fileHandleForReading,
        stderrPipe.fileHandleForWriting,
    ]

    do {
        for handle in handles {
            guard fcntl(
                handle.fileDescriptor,
                F_SETFD,
                FD_CLOEXEC
            ) == 0 else {
                throw RegisteredActionRunnerError.launchFailed(
                    "close-on-exec failed: \(errno)"
                )
            }
        }
        let pid = try spawnRegisteredAction(
            invocation,
            standardOutput: stdoutPipe.fileHandleForWriting.fileDescriptor,
            standardError: stderrPipe.fileHandleForWriting.fileDescriptor
        )
        stdoutPipe.fileHandleForWriting.closeFile()
        stderrPipe.fileHandleForWriting.closeFile()
        return SpawnedRegisteredAction(
            pid: pid,
            standardOutput: stdoutPipe.fileHandleForReading,
            standardError: stderrPipe.fileHandleForReading
        )
    } catch {
        for handle in handles {
            try? handle.close()
        }
        if let error = error as? RegisteredActionRunnerError {
            throw error
        }
        throw RegisteredActionRunnerError.launchFailed(
            String(describing: error)
        )
    }
}

private func spawnRegisteredAction(
    _ invocation: RegisteredActionInvocation,
    standardOutput: Int32,
    standardError: Int32
) throws -> pid_t {
    let standardInput = open("/dev/null", O_RDONLY)
    guard standardInput >= 0 else {
        throw RegisteredActionRunnerError.launchFailed(
            "open /dev/null failed: \(errno)"
        )
    }
    defer { close(standardInput) }

    var fileActions: posix_spawn_file_actions_t?
    guard posix_spawn_file_actions_init(&fileActions) == 0 else {
        throw RegisteredActionRunnerError.launchFailed("file actions")
    }
    defer { posix_spawn_file_actions_destroy(&fileActions) }

    for (source, target) in [
        (standardInput, STDIN_FILENO),
        (standardOutput, STDOUT_FILENO),
        (standardError, STDERR_FILENO),
    ] {
        let result = posix_spawn_file_actions_adddup2(
            &fileActions,
            source,
            target
        )
        guard result == 0 else {
            throw RegisteredActionRunnerError.launchFailed(
                "dup2 failed: \(result)"
            )
        }
    }
    for descriptor in Set([
        standardInput,
        standardOutput,
        standardError,
    ]) where descriptor > STDERR_FILENO {
        let result = posix_spawn_file_actions_addclose(
            &fileActions,
            descriptor
        )
        guard result == 0 else {
            throw RegisteredActionRunnerError.launchFailed(
                "close action failed: \(result)"
            )
        }
    }

    var attributes: posix_spawnattr_t?
    guard posix_spawnattr_init(&attributes) == 0 else {
        throw RegisteredActionRunnerError.launchFailed("spawn attributes")
    }
    defer { posix_spawnattr_destroy(&attributes) }
    let flagsResult = posix_spawnattr_setflags(
        &attributes,
        Int16(
            POSIX_SPAWN_SETPGROUP
                | POSIX_SPAWN_CLOEXEC_DEFAULT
        )
    )
    let groupResult = posix_spawnattr_setpgroup(&attributes, 0)
    guard flagsResult == 0, groupResult == 0 else {
        throw RegisteredActionRunnerError.launchFailed(
            "process group isolation"
        )
    }

    let arguments = [invocation.executableURL.path] + invocation.arguments
    let environment = invocation.environment
        .map { "\($0.key)=\($0.value)" }
        .sorted()
    var pid: pid_t = 0
    let spawnResult = try withRegisteredCStringArray(arguments) { argv in
        try withRegisteredCStringArray(environment) { envp in
            invocation.executableURL.path.withCString { executable in
                posix_spawn(
                    &pid,
                    executable,
                    &fileActions,
                    &attributes,
                    argv,
                    envp
                )
            }
        }
    }
    guard spawnResult == 0 else {
        throw RegisteredActionRunnerError.launchFailed(
            "posix_spawn failed: \(spawnResult)"
        )
    }
    guard getpgid(pid) == pid, pid != getpgrp() else {
        kill(pid, SIGKILL)
        _ = waitpid(pid, nil, 0)
        throw RegisteredActionRunnerError.launchFailed(
            "process group isolation"
        )
    }
    return pid
}

private func waitForRegisteredAction(
    _ pid: pid_t,
    timeout: Duration
) async throws -> Int32 {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while clock.now < deadline {
        if leaderHasWaitableExit(pid) {
            if !ProcessTreeTerminator.processGroupHasMembers(
                ProcessGroupID(rawValue: pid),
                excluding: pid
            ) {
                try? await Task.sleep(for: .milliseconds(50))
            }
            try await terminateRemainingRegisteredActionMembers(pid)
            return try reapRegisteredAction(pid)
        }
        try? await Task.sleep(for: .milliseconds(5))
    }

    do {
        _ = try await ProcessTreeTerminator().terminateProcessGroup(
            ProcessGroupID(rawValue: pid),
            gracePeriod: .milliseconds(250)
        )
    } catch let error as ProcessTreeTerminationError {
        throw RegisteredActionRunnerError.terminationFailed(error)
    } catch {
        throw RegisteredActionRunnerError.terminationFailed(.unexpected)
    }
    _ = try reapRegisteredAction(pid)
    throw RegisteredActionRunnerError.timedOut
}

private func leaderHasWaitableExit(_ pid: pid_t) -> Bool {
    var information = siginfo_t()
    let result = waitid(
        P_PID,
        UInt32(pid),
        &information,
        WEXITED | WNOHANG | WNOWAIT
    )
    return result == 0 && information.si_pid == pid
}

private func terminateRemainingRegisteredActionMembers(
    _ pid: pid_t
) async throws {
    let processGroup = ProcessGroupID(rawValue: pid)
    guard ProcessTreeTerminator.processGroupHasMembers(
        processGroup,
        excluding: pid
    ) else {
        return
    }
    do {
        _ = try await ProcessTreeTerminator().terminateProcessGroup(
            processGroup,
            gracePeriod: .milliseconds(250)
        )
    } catch let error as ProcessTreeTerminationError {
        throw RegisteredActionRunnerError.terminationFailed(error)
    } catch {
        throw RegisteredActionRunnerError.terminationFailed(.unexpected)
    }
}

private func reapRegisteredAction(_ pid: pid_t) throws -> Int32 {
    var status: Int32 = 0
    while waitpid(pid, &status, 0) < 0 {
        if errno != EINTR {
            throw RegisteredActionRunnerError.launchFailed(
                "waitpid failed: \(errno)"
            )
        }
    }
    return status
}

private func normalizeRegisteredActionStatus(_ waitStatus: Int32) -> Int32 {
    if waitStatus & 0x7F == 0 {
        return (waitStatus >> 8) & 0xFF
    }
    return 128 + (waitStatus & 0x7F)
}

private func withRegisteredCStringArray<Result>(
    _ strings: [String],
    body: (
        UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
    ) throws -> Result
) throws -> Result {
    guard strings.allSatisfy({ !$0.utf8.contains(0) }) else {
        throw RegisteredActionRunnerError.launchFailed(
            "NUL in invocation"
        )
    }
    var storage: [UnsafeMutablePointer<CChar>?] = []
    defer {
        for pointer in storage {
            free(pointer)
        }
    }
    for string in strings {
        guard let pointer = strdup(string) else {
            throw RegisteredActionRunnerError.launchFailed(
                "argument allocation"
            )
        }
        storage.append(pointer)
    }
    storage.append(nil)
    return try storage.withUnsafeMutableBufferPointer { buffer in
        try body(buffer.baseAddress!)
    }
}

private struct ActionBoundedOutput: Sendable {
    var data = Data()
    var wasTruncated = false
    var readError: String?
}

private final class ActionLockedBox<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: Value

    init(_ value: Value) {
        storedValue = value
    }

    var value: Value {
        lock.withLock { storedValue }
    }

    func set(_ value: Value) {
        lock.withLock {
            storedValue = value
        }
    }
}

private func drainActionOutput(
    _ fileHandle: FileHandle,
    limit: Int
) -> ActionBoundedOutput {
    var output = ActionBoundedOutput()
    while true {
        do {
            guard let chunk = try fileHandle.read(upToCount: 4_096),
                  !chunk.isEmpty
            else {
                return output
            }
            let remaining = max(0, limit - output.data.count)
            if remaining > 0 {
                output.data.append(chunk.prefix(remaining))
            }
            if chunk.count > remaining {
                output.wasTruncated = true
            }
        } catch {
            output.readError = String(describing: error)
            return output
        }
    }
}
