import Darwin
import Foundation
import StornautProcessSupport

struct CodexAppServerSessionRequest: Sendable {
    let executableURL: URL
    let workspace: CodexRuntimeWorkspacePaths
    let projectedAuthSourceURL: URL
    let containmentConfiguration: CodexContainmentConfiguration
    let environment: CodexRuntimeEnvironment
    let runtime: CodexAppServerRuntime
    let timeout: Duration
    let standardOutputByteLimit: Int
    let standardErrorByteLimit: Int
    let lineByteLimit: Int
}

struct CodexAppServerSessionResult: Sendable, Equatable {
    let observation: CodexAppServerObservation
    let standardErrorByteCount: Int
}

enum CodexAppServerSessionError: Error, Sendable, Equatable {
    case invalidRequest
    case launchFailed
    case inputWriteFailed
    case outputReadFailed
    case outputLimitExceeded
    case errorLimitExceeded
    case protocolFailure(CodexAppServerRuntimeError)
    case timedOut
    case cancelled
    case nonzeroExit
    case terminationFailed
}

struct CodexAppServerSessionRunner: Sendable {
    func run(
        _ request: CodexAppServerSessionRequest
    ) async throws -> CodexAppServerSessionResult {
        let cancellation = AppServerSessionCancellation()
        return try await withTaskCancellationHandler {
            try await Task.detached(priority: .utility) {
                try runSynchronously(
                    request,
                    cancellation: cancellation
                )
            }.value
        } onCancel: {
            cancellation.cancel()
        }
    }

    private func runSynchronously(
        _ request: CodexAppServerSessionRequest,
        cancellation: AppServerSessionCancellation
    ) throws -> CodexAppServerSessionResult {
        guard
            request.executableURL.isFileURL,
            request.executableURL.path.hasPrefix("/"),
            isCanonicalRegularExecutable(request.executableURL),
            workspaceIsOwnerOnly(request.workspace),
            globalInstructionsAreAbsent(
                in: request.workspace.runtimeURL
            ),
            environmentIsClosed(request.environment),
            request.timeout > .zero,
            request.standardOutputByteLimit > 0,
            request.standardErrorByteLimit > 0,
            request.lineByteLimit > 0,
            request.lineByteLimit <= request.standardOutputByteLimit,
            request.runtime.status == .ready,
            request.environment.values["CODEX_HOME"]
                == request.workspace.runtimeURL.path,
            request.environment.values["HOME"]
                == request.workspace.homeURL.path,
            request.environment.values["TMPDIR"]
                == request.workspace.runtimeURL.appending(
                    path: "tmp",
                    directoryHint: .isDirectory
                ).path
        else {
            throw CodexAppServerSessionError.invalidRequest
        }

        let arguments: [String]
        do {
            let policy = CodexContainmentPolicy()
            let expectedConfiguration = try policy.configuration(
                workspace: request.workspace,
                projectedAuthSourceURL: request.projectedAuthSourceURL
            )
            guard expectedConfiguration == request.containmentConfiguration else {
                throw CodexAppServerSessionError.invalidRequest
            }
            try policy.validateInstalled(
                request.containmentConfiguration,
                in: request.workspace
            )
            arguments = try policy.launchArguments(
                codexExecutableURL: request.executableURL,
                workspace: request.workspace
            )
        } catch {
            throw CodexAppServerSessionError.invalidRequest
        }
        let process: SpawnedDiagnosticProcess
        do {
            process = try spawnDiagnosticProcess(
                executableURL: request.executableURL,
                arguments: arguments,
                environment: request.environment.values,
                currentDirectoryURL: request.workspace.workURL
            )
        } catch {
            throw CodexAppServerSessionError.launchFailed
        }

        var reaped = false
        let writer: BoundedAppServerWriter
        do {
            writer = try BoundedAppServerWriter(
                descriptor: process.standardInput
            )
        } catch {
            forceCleanupDiagnosticProcess(process)
            throw CodexAppServerSessionError.launchFailed
        }
        let reader = BoundedAppServerLineReader(
            descriptor: process.standardOutput,
            lineByteLimit: request.lineByteLimit,
            sessionByteLimit: request.standardOutputByteLimit
        )
        let errorHandle = FileHandle(
            fileDescriptor: process.standardError,
            closeOnDealloc: true
        )
        let standardError = BoundedAppServerErrorOutput(
            limit: request.standardErrorByteLimit
        )
        let errorGroup = DispatchGroup()
        errorGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            standardError.drain(errorHandle)
            errorGroup.leave()
        }
        defer {
            request.runtime.eraseCredentials()
            writer.close()
            reader.close()
            try? errorHandle.close()
            if !reaped {
                forceCleanupDiagnosticProcess(process)
            }
            errorGroup.wait()
        }

        let deadline = request.timeout.dispatchDeadline
        do {
            for var message in try request.runtime.begin() {
                try writeAndErase(
                    &message,
                    to: writer,
                    deadline: deadline,
                    cancellation: cancellation
                )
            }
        } catch let error as CodexAppServerSessionError {
            throw error
        } catch {
            throw CodexAppServerSessionError.inputWriteFailed
        }

        while request.runtime.status != .completed {
            guard !cancellation.isCancelled else {
                throw CodexAppServerSessionError.cancelled
            }
            let line: Data
            do {
                line = try reader.nextLine(
                    deadline: deadline,
                    cancellation: cancellation
                )
            } catch let error as BoundedAppServerLineReader.Error {
                switch error {
                case .timedOut:
                    throw CodexAppServerSessionError.timedOut
                case .cancelled:
                    throw CodexAppServerSessionError.cancelled
                case .lineLimitExceeded, .sessionLimitExceeded:
                    throw CodexAppServerSessionError.outputLimitExceeded
                case .readFailed, .unexpectedEOF:
                    throw CodexAppServerSessionError.outputReadFailed
                }
            }
            let responses: [Data]
            do {
                responses = try request.runtime.receive(line)
            } catch let error as CodexAppServerRuntimeError {
                throw CodexAppServerSessionError.protocolFailure(error)
            } catch {
                throw CodexAppServerSessionError.protocolFailure(
                    .invalidMessage
                )
            }
            do {
                for var response in responses {
                    try writeAndErase(
                        &response,
                        to: writer,
                        deadline: deadline,
                        cancellation: cancellation
                    )
                }
            } catch let error as CodexAppServerSessionError {
                throw error
            } catch {
                throw CodexAppServerSessionError.inputWriteFailed
            }
        }

        writer.close()
        guard waitForExit(process.pid, deadline: deadline) else {
            throw CodexAppServerSessionError.timedOut
        }
        if ProcessTreeTerminator.processGroupHasMembers(
            process.processGroup,
            excluding: process.pid
        ) {
            usleep(50_000)
        }
        if ProcessTreeTerminator.processGroupHasMembers(
            process.processGroup,
            excluding: process.pid
        ) {
            do {
                try terminateDiagnosticProcessGroup(process.processGroup)
            } catch {
                throw CodexAppServerSessionError.terminationFailed
            }
        }
        let waitStatus: Int32
        do {
            waitStatus = try reapDiagnosticProcess(process.pid)
        } catch {
            throw CodexAppServerSessionError.terminationFailed
        }
        reaped = true
        errorGroup.wait()
        guard !standardError.readFailed else {
            throw CodexAppServerSessionError.outputReadFailed
        }
        guard !standardError.wasTruncated else {
            throw CodexAppServerSessionError.errorLimitExceeded
        }
        guard normalizedDiagnosticExitStatus(waitStatus) == 0 else {
            throw CodexAppServerSessionError.nonzeroExit
        }
        return CodexAppServerSessionResult(
            observation: request.runtime.observation,
            standardErrorByteCount: standardError.byteCount
        )
    }

    private func writeAndErase(
        _ data: inout Data,
        to writer: BoundedAppServerWriter,
        deadline: DispatchTime,
        cancellation: AppServerSessionCancellation
    ) throws {
        defer {
            data.resetBytes(in: 0..<data.count)
        }
        do {
            try writer.write(
                data,
                deadline: deadline,
                cancellation: cancellation
            )
        } catch BoundedAppServerWriter.Error.timedOut {
            throw CodexAppServerSessionError.timedOut
        } catch BoundedAppServerWriter.Error.cancelled {
            throw CodexAppServerSessionError.cancelled
        } catch {
            throw CodexAppServerSessionError.inputWriteFailed
        }
    }

    private func waitForExit(
        _ processID: pid_t,
        deadline: DispatchTime
    ) -> Bool {
        while deadline.uptimeNanoseconds
            > DispatchTime.now().uptimeNanoseconds
        {
            var information = siginfo_t()
            let result = waitid(
                P_PID,
                UInt32(processID),
                &information,
                WEXITED | WNOHANG | WNOWAIT
            )
            if result == 0, information.si_pid == processID {
                return true
            }
            if result != 0, errno != EINTR {
                return false
            }
            usleep(5_000)
        }
        return false
    }
}

private final class BoundedAppServerWriter {
    enum Error: Swift.Error {
        case invalidDescriptor
        case timedOut
        case cancelled
        case writeFailed
    }

    private let descriptor: Int32
    private var isClosed = false

    init(descriptor: Int32) throws {
        let flags = fcntl(descriptor, F_GETFL)
        guard
            flags >= 0,
            fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) == 0
        else {
            Darwin.close(descriptor)
            throw Error.invalidDescriptor
        }
        self.descriptor = descriptor
    }

    func write(
        _ data: Data,
        deadline: DispatchTime,
        cancellation: AppServerSessionCancellation
    ) throws {
        try data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            var offset = 0
            while offset < bytes.count {
                guard !cancellation.isCancelled else {
                    throw Error.cancelled
                }
                let now = DispatchTime.now().uptimeNanoseconds
                guard deadline.uptimeNanoseconds > now else {
                    throw Error.timedOut
                }
                let count = Darwin.write(
                    descriptor,
                    baseAddress.advanced(by: offset),
                    bytes.count - offset
                )
                if count > 0 {
                    offset += count
                    continue
                }
                if count == 0 {
                    throw Error.writeFailed
                }
                if errno == EINTR {
                    continue
                }
                guard errno == EAGAIN || errno == EWOULDBLOCK else {
                    throw Error.writeFailed
                }
                var pollDescriptor = pollfd(
                    fd: descriptor,
                    events: Int16(POLLOUT | POLLHUP),
                    revents: 0
                )
                let result = poll(
                    &pollDescriptor,
                    1,
                    pollTimeoutMilliseconds(
                        deadline: deadline
                    )
                )
                if result == 0 {
                    continue
                }
                if result < 0 {
                    if errno == EINTR { continue }
                    throw Error.writeFailed
                }
                guard pollDescriptor.revents & Int16(POLLOUT) != 0 else {
                    throw Error.writeFailed
                }
            }
        }
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        Darwin.close(descriptor)
    }

    private func pollTimeoutMilliseconds(
        deadline: DispatchTime
    ) -> Int32 {
        let now = DispatchTime.now().uptimeNanoseconds
        guard deadline.uptimeNanoseconds > now else { return 0 }
        let remainingNanoseconds = deadline.uptimeNanoseconds - now
        return Int32(
            min(
                max(1, min(remainingNanoseconds / 1_000_000, 50)),
                UInt64(Int32.max)
            )
        )
    }
}

private func isCanonicalRegularExecutable(_ url: URL) -> Bool {
    let canonical = url.resolvingSymlinksInPath().standardizedFileURL
    guard canonical.path == url.standardizedFileURL.path else {
        return false
    }
    var information = stat()
    return lstat(canonical.path, &information) == 0
        && information.st_mode & S_IFMT == S_IFREG
        && FileManager.default.isExecutableFile(atPath: canonical.path)
}

private func workspaceIsOwnerOnly(
    _ workspace: CodexRuntimeWorkspacePaths
) -> Bool {
    guard workspace.directories.allSatisfy({
        var information = stat()
        return lstat($0.path, &information) == 0
            && information.st_mode & S_IFMT == S_IFDIR
            && information.st_uid == geteuid()
            && information.st_mode & 0o777 == 0o700
    }) else {
        return false
    }
    let temporaryDirectory = workspace.runtimeURL.appending(
        path: "tmp",
        directoryHint: .isDirectory
    )
    var information = stat()
    return lstat(temporaryDirectory.path, &information) == 0
        && information.st_mode & S_IFMT == S_IFDIR
        && information.st_uid == geteuid()
        && information.st_mode & 0o777 == 0o700
}

private func globalInstructionsAreAbsent(in runtimeHomeURL: URL) -> Bool {
    ["AGENTS.override.md", "AGENTS.md"].allSatisfy {
        !FileManager.default.fileExists(
            atPath: runtimeHomeURL.appending(path: $0).path
        )
    }
}

private func environmentIsClosed(
    _ environment: CodexRuntimeEnvironment
) -> Bool {
    Set(environment.values.keys).isSubset(
        of: CodexRuntimeEnvironment.allowedKeys
    )
        && environment.values.values.allSatisfy {
            !$0.isEmpty
                && $0.unicodeScalars.allSatisfy {
                    $0.value >= 0x20 && $0.value != 0x7F
                }
        }
}

private final class BoundedAppServerLineReader {
    enum Error: Swift.Error {
        case timedOut
        case cancelled
        case lineLimitExceeded
        case sessionLimitExceeded
        case readFailed
        case unexpectedEOF
    }

    private let descriptor: Int32
    private let lineByteLimit: Int
    private let sessionByteLimit: Int
    private var buffer = Data()
    private var totalBytes = 0
    private var isClosed = false

    init(
        descriptor: Int32,
        lineByteLimit: Int,
        sessionByteLimit: Int
    ) {
        self.descriptor = descriptor
        self.lineByteLimit = lineByteLimit
        self.sessionByteLimit = sessionByteLimit
    }

    func nextLine(
        deadline: DispatchTime,
        cancellation: AppServerSessionCancellation
    ) throws -> Data {
        while true {
            guard !cancellation.isCancelled else {
                throw Error.cancelled
            }
            if let newline = buffer.firstIndex(of: 0x0A) {
                let line = Data(buffer[...newline])
                buffer.removeSubrange(...newline)
                guard
                    line.count > 1,
                    line.count <= lineByteLimit
                else {
                    if line.count > lineByteLimit {
                        throw Error.lineLimitExceeded
                    }
                    throw Error.readFailed
                }
                return line
            }
            guard buffer.count <= lineByteLimit else {
                throw Error.lineLimitExceeded
            }
            let now = DispatchTime.now().uptimeNanoseconds
            guard deadline.uptimeNanoseconds > now else {
                throw Error.timedOut
            }
            let remainingNanoseconds = deadline.uptimeNanoseconds - now
            let timeoutMilliseconds = Int32(
                min(
                    max(
                        1,
                        min(
                            remainingNanoseconds / 1_000_000,
                            50
                        )
                    ),
                    UInt64(Int32.max)
                )
            )
            var pollDescriptor = pollfd(
                fd: descriptor,
                events: Int16(POLLIN | POLLHUP),
                revents: 0
            )
            let result = poll(
                &pollDescriptor,
                1,
                timeoutMilliseconds
            )
            if result == 0 {
                continue
            }
            if result < 0 {
                if errno == EINTR { continue }
                throw Error.readFailed
            }
            var bytes = [UInt8](repeating: 0, count: 4_096)
            let count = Darwin.read(descriptor, &bytes, bytes.count)
            if count == 0 {
                throw Error.unexpectedEOF
            }
            if count < 0 {
                if errno == EINTR { continue }
                throw Error.readFailed
            }
            totalBytes += count
            guard totalBytes <= sessionByteLimit else {
                throw Error.sessionLimitExceeded
            }
            buffer.append(contentsOf: bytes.prefix(count))
            guard
                buffer.firstIndex(of: 0x0A) != nil
                    || buffer.count <= lineByteLimit
            else {
                throw Error.lineLimitExceeded
            }
        }
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        Darwin.close(descriptor)
    }
}

private final class AppServerSessionCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.withLock { cancelled }
    }

    func cancel() {
        lock.withLock { cancelled = true }
    }
}

private final class BoundedAppServerErrorOutput: @unchecked Sendable {
    private let lock = NSLock()
    private let limit: Int
    private var count = 0
    private var truncated = false
    private var failed = false

    init(limit: Int) {
        self.limit = limit
    }

    var byteCount: Int {
        lock.withLock { count }
    }

    var wasTruncated: Bool {
        lock.withLock { truncated }
    }

    var readFailed: Bool {
        lock.withLock { failed }
    }

    func drain(_ handle: FileHandle) {
        while true {
            do {
                guard
                    let chunk = try handle.read(upToCount: 4_096),
                    !chunk.isEmpty
                else {
                    return
                }
                lock.withLock {
                    let next = count.addingReportingOverflow(chunk.count)
                    if next.overflow || next.partialValue > limit {
                        truncated = true
                        count = limit
                    } else {
                        count = next.partialValue
                    }
                }
            } catch {
                lock.withLock { failed = true }
                return
            }
        }
    }
}
