import Darwin
import Foundation
import StornautCore

public struct CodexRunRequest: Sendable, Equatable {
    public let executableURL: URL
    public let isolatedWorkingDirectoryURL: URL
    public let schemaURL: URL
    public let prompt: Data
    public let timeout: Duration
    public let terminationGracePeriod: Duration
    public let stdoutByteLimit: Int
    public let stderrByteLimit: Int
    public let jsonLineByteLimit: Int
    public let unknownMetadataByteLimit: Int
    public let environment: [String: String]

    public init(
        executableURL: URL,
        isolatedWorkingDirectoryURL: URL,
        schemaURL: URL,
        prompt: Data,
        timeout: Duration,
        terminationGracePeriod: Duration,
        stdoutByteLimit: Int,
        stderrByteLimit: Int,
        jsonLineByteLimit: Int,
        unknownMetadataByteLimit: Int,
        environment: [String: String]
    ) {
        self.executableURL = executableURL
        self.isolatedWorkingDirectoryURL = isolatedWorkingDirectoryURL
        self.schemaURL = schemaURL
        self.prompt = prompt
        self.timeout = timeout
        self.terminationGracePeriod = terminationGracePeriod
        self.stdoutByteLimit = stdoutByteLimit
        self.stderrByteLimit = stderrByteLimit
        self.jsonLineByteLimit = jsonLineByteLimit
        self.unknownMetadataByteLimit = unknownMetadataByteLimit
        self.environment = environment
    }

    public static func fixedArguments(
        schemaURL: URL,
        workingDirectoryURL: URL
    ) -> [String] {
        [
            "exec",
            "--strict-config",
            "--ephemeral",
            "--json",
            "--output-schema",
            schemaURL.path,
            "--sandbox",
            "read-only",
            "--ignore-user-config",
            "--ignore-rules",
            "--skip-git-repo-check",
            "-C",
            workingDirectoryURL.path,
            "-c",
            "project_doc_max_bytes=0",
            "-c",
            "skills.include_instructions=false",
            "-c",
            "skills.bundled.enabled=false",
            "-c",
            "include_environment_context=false",
            "-c",
            "include_permissions_instructions=false",
            "-c",
            "include_apps_instructions=false",
            "-c",
            "include_collaboration_mode_instructions=false",
            "-c",
            "analytics.enabled=false",
            "-c",
            "otel.metrics_exporter=\"none\"",
            "-c",
            "features.shell_tool=false",
            "-c",
            "features.unified_exec=false",
            "-c",
            "features.hooks=false",
            "-c",
            "features.plugins=false",
            "-c",
            "features.apps=false",
            "-c",
            "features.computer_use=false",
            "-c",
            "features.browser_use=false",
            "-c",
            "features.browser_use_external=false",
            "-c",
            "features.browser_use_full_cdp_access=false",
            "-c",
            "features.image_generation=false",
            "-c",
            "orchestrator.skills.enabled=false",
            "-c",
            "orchestrator.mcp.enabled=false",
            "-",
        ]
    }
}

public enum CodexStderrEvent: Sendable, Equatable {
    case received(byteCount: Int)
}

public enum CodexLifecycleEvent: Sendable, Equatable {
    case processGroupCreated
    case interruptSent
    case terminateSent
    case killSent
}

public enum CodexProcessEvent: Sendable, Equatable {
    case started
    case protocolEvent(CodexEvent)
    case unknown(type: String, metadata: [String: String])
    case stderr(CodexStderrEvent)
    case lifecycle(CodexLifecycleEvent)
    case completed(InvestigationEnvelope)
}

public enum CodexProcessError: Error, Sendable, Equatable {
    case invalidExecutable
    case invalidWorkingDirectory
    case invalidSchema
    case invalidCodexHome
    case globalInstructionsNotIsolated
    case invalidLimits
    case spawnFailed(code: Int32)
    case processGroupIsolationFailed
    case inputWriteFailed
    case stdoutReadFailed
    case stderrReadFailed
    case stdoutByteLimitExceeded(limit: Int)
    case stderrByteLimitExceeded(limit: Int)
    case eventBufferLimitExceeded(limit: Int)
    case protocolViolation
    case turnFailed
    case missingFinalEnvelope
    case invalidFinalEnvelope
    case nonzeroExit(status: Int32)
    case timedOut
    case cancelled
    case waitFailed(errno: Int32)
    case terminationFailed(ProcessTreeTerminationError)
}

public struct CodexProcess: Sendable {
    private let eventBufferCapacity: Int

    public init() {
        eventBufferCapacity = 64
    }

    init(eventBufferCapacity: Int) {
        self.eventBufferCapacity = max(1, eventBufferCapacity)
    }

    public func run(
        _ request: CodexRunRequest
    ) -> AsyncThrowingStream<CodexProcessEvent, Error> {
        let channel = CodexProcessEventChannel(
            capacity: eventBufferCapacity
        )
        let control = CodexProcessControl()

        Task.detached(priority: .utility) {
            do {
                try await executeCodexProcess(
                    request,
                    channel: channel,
                    control: control
                )
                channel.finish()
            } catch {
                channel.finish(throwing: error)
            }
        }

        return AsyncThrowingStream {
            try await channel.next(control: control)
        }
    }
}

private func executeCodexProcess(
    _ request: CodexRunRequest,
    channel: CodexProcessEventChannel,
    control: CodexProcessControl
) async throws {
    try validate(request)

    let process = try spawn(request)
    try channel.send(.started)
    try channel.send(.lifecycle(.processGroupCreated))

    let inputTask = Task.detached(priority: .utility) {
        do {
            try writeAll(request.prompt, to: process.standardInput)
        } catch let error as CodexProcessError {
            control.recordAsynchronousError(error)
            throw error
        }
    }
    let stdoutTask = Task.detached(priority: .utility) {
        do {
            return try readStandardOutput(
                from: process.standardOutput,
                request: request,
                channel: channel
            )
        } catch let error as CodexProcessError {
            control.recordAsynchronousError(error)
            throw error
        }
    }
    let stderrTask = Task.detached(priority: .utility) {
        do {
            return try readStandardError(
                from: process.standardError,
                limit: request.stderrByteLimit
            )
        } catch let error as CodexProcessError {
            control.recordAsynchronousError(error)
            throw error
        }
    }

    let terminationReason = try await waitForExitOrTermination(
        pid: process.pid,
        timeout: request.timeout,
        control: control
    )

    if let terminationReason {
        let transitions: [ProcessTreeTerminationTransition]
        if try processHasWaitableExit(process.pid) {
            if ProcessTreeTerminator.processGroupHasMembers(
                process.processGroup,
                excluding: process.pid
            ) {
                do {
                    transitions = try await ProcessTreeTerminator()
                        .terminateProcessGroup(
                            process.processGroup,
                            gracePeriod: request.terminationGracePeriod
                        )
                } catch let error as ProcessTreeTerminationError {
                    throw CodexProcessError.terminationFailed(error)
                } catch {
                    throw CodexProcessError.terminationFailed(.unexpected)
                }
            } else {
                transitions = []
            }
        } else {
            do {
                transitions = try await ProcessTreeTerminator()
                    .terminateProcessGroup(
                        process.processGroup,
                        gracePeriod: request.terminationGracePeriod
                    )
            } catch let error as ProcessTreeTerminationError {
                throw CodexProcessError.terminationFailed(error)
            } catch {
                throw CodexProcessError.terminationFailed(.unexpected)
            }
        }
        for transition in transitions {
            switch transition {
            case .interruptSent:
                try? channel.send(.lifecycle(.interruptSent))
            case .terminateSent:
                try? channel.send(.lifecycle(.terminateSent))
            case .killSent:
                try? channel.send(.lifecycle(.killSent))
            }
        }
        _ = try reap(process.pid)
        _ = try? await inputTask.value
        _ = try? await stdoutTask.value
        _ = try? await stderrTask.value
        throw terminationReason
    }

    if ProcessTreeTerminator.processGroupHasMembers(
        process.processGroup,
        excluding: process.pid
    ) {
        try await Task.sleep(for: .milliseconds(50))
    }
    if ProcessTreeTerminator.processGroupHasMembers(
        process.processGroup,
        excluding: process.pid
    ) {
        let transitions: [ProcessTreeTerminationTransition]
        do {
            transitions = try await ProcessTreeTerminator()
                .terminateProcessGroup(
                    process.processGroup,
                    gracePeriod: request.terminationGracePeriod
                )
        } catch let error as ProcessTreeTerminationError {
            throw CodexProcessError.terminationFailed(error)
        } catch {
            throw CodexProcessError.terminationFailed(.unexpected)
        }
        for transition in transitions {
            switch transition {
            case .interruptSent:
                try? channel.send(.lifecycle(.interruptSent))
            case .terminateSent:
                try? channel.send(.lifecycle(.terminateSent))
            case .killSent:
                try? channel.send(.lifecycle(.killSent))
            }
        }
    }
    let waitStatus = try reap(process.pid)
    let standardError = try await stderrTask.value
    if !standardError.isEmpty {
        try channel.send(.stderr(.received(byteCount: standardError.count)))
    }

    if let asynchronousError = control.asynchronousError {
        _ = try? await inputTask.value
        _ = try? await stdoutTask.value
        throw asynchronousError
    }

    let exitStatus = normalizedExitStatus(waitStatus)
    guard exitStatus == 0 else {
        _ = try? await inputTask.value
        _ = try? await stdoutTask.value
        throw CodexProcessError.nonzeroExit(status: exitStatus)
    }

    try await inputTask.value
    let stdoutResult = try await stdoutTask.value
    guard stdoutResult.sawTurnCompleted else {
        throw stdoutResult.sawTurnFailed
            ? CodexProcessError.turnFailed
            : CodexProcessError.missingFinalEnvelope
    }
    guard let finalMessage = stdoutResult.finalAgentMessage else {
        throw CodexProcessError.missingFinalEnvelope
    }

    let envelope: InvestigationEnvelope
    do {
        envelope = try InvestigationEnvelope.decodeValidated(
            from: Data(finalMessage.utf8)
        )
    } catch {
        throw CodexProcessError.invalidFinalEnvelope
    }
    try channel.send(.completed(envelope))
}

private struct SpawnedCodexProcess {
    let pid: pid_t
    let processGroup: ProcessGroupID
    let standardInput: Int32
    let standardOutput: Int32
    let standardError: Int32
}

private func spawn(_ request: CodexRunRequest) throws -> SpawnedCodexProcess {
    try spawnWithoutInheritingUnmappedDescriptors(request)
}

private func spawnWithoutInheritingUnmappedDescriptors(
    _ request: CodexRunRequest
) throws -> SpawnedCodexProcess {
    let stdinPipe = try createPipe()
    let stdoutPipe = try createPipe()
    let stderrPipe = try createPipe()
    var parentDescriptors = [
        stdinPipe.read,
        stdinPipe.write,
        stdoutPipe.read,
        stdoutPipe.write,
        stderrPipe.read,
        stderrPipe.write,
    ]

    do {
        var fileActions: posix_spawn_file_actions_t?
        guard posix_spawn_file_actions_init(&fileActions) == 0 else {
            throw CodexProcessError.spawnFailed(code: EINVAL)
        }
        defer { posix_spawn_file_actions_destroy(&fileActions) }

        try addDup(stdinPipe.read, to: STDIN_FILENO, actions: &fileActions)
        try addDup(stdoutPipe.write, to: STDOUT_FILENO, actions: &fileActions)
        try addDup(stderrPipe.write, to: STDERR_FILENO, actions: &fileActions)
        for descriptor in parentDescriptors {
            try addClose(descriptor, actions: &fileActions)
        }
        let changeDirectoryResult = request.isolatedWorkingDirectoryURL.path
            .withCString {
                posix_spawn_file_actions_addchdir(&fileActions, $0)
            }
        guard changeDirectoryResult == 0 else {
            throw CodexProcessError.spawnFailed(code: changeDirectoryResult)
        }

        var attributes: posix_spawnattr_t?
        guard posix_spawnattr_init(&attributes) == 0 else {
            throw CodexProcessError.spawnFailed(code: EINVAL)
        }
        defer { posix_spawnattr_destroy(&attributes) }
        guard
            posix_spawnattr_setflags(
                &attributes,
                Int16(
                    POSIX_SPAWN_SETPGROUP
                        | POSIX_SPAWN_CLOEXEC_DEFAULT
                )
            ) == 0,
            posix_spawnattr_setpgroup(&attributes, 0) == 0
        else {
            throw CodexProcessError.spawnFailed(code: EINVAL)
        }

        let arguments = [request.executableURL.path]
            + CodexRunRequest.fixedArguments(
                schemaURL: request.schemaURL,
                workingDirectoryURL: request.isolatedWorkingDirectoryURL
            )
        let environment = sanitizedEnvironment(request.environment)
            .map { "\($0.key)=\($0.value)" }
            .sorted()
        var pid: pid_t = 0
        let result = try withCStringArray(arguments) { argv in
            try withCStringArray(environment) { envp in
                request.executableURL.path.withCString { executable in
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
        guard result == 0 else {
            throw CodexProcessError.spawnFailed(code: result)
        }

        close(stdinPipe.read)
        close(stdoutPipe.write)
        close(stderrPipe.write)
        parentDescriptors.removeAll()
        guard fcntl(stdinPipe.write, F_SETNOSIGPIPE, 1) == 0 else {
            let failure = errno
            kill(pid, SIGKILL)
            _ = waitpid(pid, nil, 0)
            close(stdinPipe.write)
            close(stdoutPipe.read)
            close(stderrPipe.read)
            throw CodexProcessError.spawnFailed(code: failure)
        }

        let processGroup = getpgid(pid)
        guard processGroup == pid, processGroup != getpgrp() else {
            kill(pid, SIGKILL)
            _ = waitpid(pid, nil, 0)
            close(stdinPipe.write)
            close(stdoutPipe.read)
            close(stderrPipe.read)
            throw CodexProcessError.processGroupIsolationFailed
        }

        return SpawnedCodexProcess(
            pid: pid,
            processGroup: ProcessGroupID(rawValue: processGroup),
            standardInput: stdinPipe.write,
            standardOutput: stdoutPipe.read,
            standardError: stderrPipe.read
        )
    } catch {
        for descriptor in parentDescriptors {
            close(descriptor)
        }
        throw error
    }
}

private func validate(_ request: CodexRunRequest) throws {
    let fileManager = FileManager.default
    guard
        request.executableURL.isFileURL,
        request.executableURL.path.hasPrefix("/"),
        fileManager.isExecutableFile(atPath: request.executableURL.path),
        isRegularFile(request.executableURL)
    else {
        throw CodexProcessError.invalidExecutable
    }
    guard
        request.isolatedWorkingDirectoryURL.isFileURL,
        request.isolatedWorkingDirectoryURL.path.hasPrefix("/"),
        isDirectory(request.isolatedWorkingDirectoryURL)
    else {
        throw CodexProcessError.invalidWorkingDirectory
    }
    guard
        request.schemaURL.isFileURL,
        request.schemaURL.path.hasPrefix("/"),
        isRegularFile(request.schemaURL)
    else {
        throw CodexProcessError.invalidSchema
    }
    guard
        request.timeout > .zero,
        request.terminationGracePeriod >= .zero,
        request.stdoutByteLimit > 0,
        request.stderrByteLimit > 0,
        request.jsonLineByteLimit > 0,
        request.jsonLineByteLimit <= request.stdoutByteLimit,
        request.unknownMetadataByteLimit >= 0
    else {
        throw CodexProcessError.invalidLimits
    }
    guard
        let codexHomePath = request.environment["CODEX_HOME"],
        codexHomePath.hasPrefix("/")
    else {
        throw CodexProcessError.invalidCodexHome
    }
    let codexHomeURL = URL(
        filePath: codexHomePath,
        directoryHint: .isDirectory
    ).standardizedFileURL
    guard isDirectory(codexHomeURL) else {
        throw CodexProcessError.invalidCodexHome
    }
    guard globalInstructionsAreAbsent(in: codexHomeURL) else {
        throw CodexProcessError.globalInstructionsNotIsolated
    }
}

private func isRegularFile(_ url: URL) -> Bool {
    (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
}

private func isDirectory(_ url: URL) -> Bool {
    (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
}

private func globalInstructionsAreAbsent(in codexHomeURL: URL) -> Bool {
    for name in ["AGENTS.override.md", "AGENTS.md"] {
        let url = codexHomeURL.appending(path: name)
        var information = stat()
        let result = url.withUnsafeFileSystemRepresentation { path in
            guard let path else {
                return Int32(EINVAL)
            }
            return lstat(path, &information)
        }
        if result != 0 {
            if errno == ENOENT {
                continue
            }
            return false
        }
        guard
            information.st_mode & S_IFMT == S_IFREG,
            information.st_size == 0
        else {
            return false
        }
    }
    return true
}

private func sanitizedEnvironment(
    _ environment: [String: String]
) -> [String: String] {
    let allowedKeys = Set([
        "CODEX_HOME",
        "HOME",
        "LANG",
        "LC_ALL",
        "LC_CTYPE",
        "PATH",
        "TERM",
        "TMPDIR",
    ])
    var sanitized = environment.filter { allowedKeys.contains($0.key) }
    if let path = sanitized["PATH"] {
        let absoluteEntries = path
            .split(separator: ":", omittingEmptySubsequences: true)
            .prefix(CodexLocator.defaultMaximumPATHEntries)
            .map(String.init)
            .filter { $0.hasPrefix("/") }
        sanitized["PATH"] = absoluteEntries.joined(separator: ":")
    }
    return sanitized
}

private func createPipe() throws -> (read: Int32, write: Int32) {
    var descriptors = [Int32](repeating: -1, count: 2)
    guard pipe(&descriptors) == 0 else {
        throw CodexProcessError.spawnFailed(code: errno)
    }

    var readDescriptor = descriptors[0]
    var writeDescriptor = descriptors[1]
    do {
        readDescriptor = try descriptorAboveStandardIO(readDescriptor)
        writeDescriptor = try descriptorAboveStandardIO(writeDescriptor)
        return (readDescriptor, writeDescriptor)
    } catch {
        close(readDescriptor)
        close(writeDescriptor)
        throw error
    }
}

private func descriptorAboveStandardIO(
    _ descriptor: Int32
) throws -> Int32 {
    if descriptor > STDERR_FILENO {
        guard fcntl(descriptor, F_SETFD, FD_CLOEXEC) == 0 else {
            throw CodexProcessError.spawnFailed(code: errno)
        }
        return descriptor
    }

    let movedDescriptor = fcntl(
        descriptor,
        F_DUPFD_CLOEXEC,
        STDERR_FILENO + 1
    )
    guard movedDescriptor >= 0 else {
        throw CodexProcessError.spawnFailed(code: errno)
    }
    close(descriptor)
    return movedDescriptor
}

private func addDup(
    _ descriptor: Int32,
    to target: Int32,
    actions: inout posix_spawn_file_actions_t?
) throws {
    let result = posix_spawn_file_actions_adddup2(
        &actions,
        descriptor,
        target
    )
    guard result == 0 else {
        throw CodexProcessError.spawnFailed(code: result)
    }
}

private func addClose(
    _ descriptor: Int32,
    actions: inout posix_spawn_file_actions_t?
) throws {
    let result = posix_spawn_file_actions_addclose(&actions, descriptor)
    guard result == 0 else {
        throw CodexProcessError.spawnFailed(code: result)
    }
}

private func withCStringArray<Result>(
    _ strings: [String],
    body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws -> Result
) throws -> Result {
    guard strings.allSatisfy({ !$0.utf8.contains(0) }) else {
        throw CodexProcessError.spawnFailed(code: EINVAL)
    }

    var storage: [UnsafeMutablePointer<CChar>?] = []
    defer {
        for pointer in storage {
            free(pointer)
        }
    }
    for string in strings {
        guard let pointer = strdup(string) else {
            throw CodexProcessError.spawnFailed(code: ENOMEM)
        }
        storage.append(pointer)
    }
    storage.append(nil)
    return try storage.withUnsafeMutableBufferPointer { buffer in
        try body(buffer.baseAddress!)
    }
}

private struct StandardOutputResult {
    var finalAgentMessage: String?
    var sawTurnCompleted = false
    var sawTurnFailed = false
}

private func readStandardOutput(
    from descriptor: Int32,
    request: CodexRunRequest,
    channel: CodexProcessEventChannel
) throws -> StandardOutputResult {
    defer { close(descriptor) }
    var decoder = JSONLDecoder(
        lineByteLimit: request.jsonLineByteLimit,
        sessionByteLimit: request.stdoutByteLimit,
        unknownMetadataByteLimit: request.unknownMetadataByteLimit
    )
    var result = StandardOutputResult()
    var buffer = [UInt8](repeating: 0, count: 4_096)

    while true {
        let count = read(descriptor, &buffer, buffer.count)
        if count == 0 {
            break
        }
        if count < 0 {
            if errno == EINTR {
                continue
            }
            throw CodexProcessError.stdoutReadFailed
        }
        let data = Data(buffer.prefix(count))
        let events: [CodexEvent]
        do {
            events = try decoder.append(data)
        } catch let error as JSONLDecoderError {
            if case let .sessionByteLimitExceeded(limit) = error {
                throw CodexProcessError.stdoutByteLimitExceeded(limit: limit)
            }
            throw CodexProcessError.protocolViolation
        }
        for event in events {
            try handle(event, result: &result, channel: channel)
        }
    }

    do {
        for event in try decoder.finish() {
            try handle(event, result: &result, channel: channel)
        }
    } catch {
        throw CodexProcessError.protocolViolation
    }
    return result
}

private func handle(
    _ event: CodexEvent,
    result: inout StandardOutputResult,
    channel: CodexProcessEventChannel
) throws {
    switch event {
    case let .unknown(unknown):
        try channel.send(
            .unknown(type: unknown.type, metadata: unknown.metadata)
        )
    case let .itemCompleted(item):
        if let text = item.agentMessageText {
            result.finalAgentMessage = text
        }
        try channel.send(
            .protocolEvent(
                .itemCompleted(item.redactedForStreaming())
            )
        )
    case .turnCompleted:
        result.sawTurnCompleted = true
        try channel.send(.protocolEvent(event))
    case .turnFailed:
        result.sawTurnFailed = true
        try channel.send(.protocolEvent(event))
    default:
        try channel.send(.protocolEvent(event))
    }
}

private func readStandardError(
    from descriptor: Int32,
    limit: Int
) throws -> Data {
    defer { close(descriptor) }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1_024)

    while true {
        let count = read(descriptor, &buffer, buffer.count)
        if count == 0 {
            return data
        }
        if count < 0 {
            if errno == EINTR {
                continue
            }
            throw CodexProcessError.stderrReadFailed
        }
        guard data.count + count <= limit else {
            throw CodexProcessError.stderrByteLimitExceeded(limit: limit)
        }
        data.append(contentsOf: buffer.prefix(count))
    }
}

private func writeAll(_ data: Data, to descriptor: Int32) throws {
    defer { close(descriptor) }
    try data.withUnsafeBytes { bytes in
        guard let baseAddress = bytes.baseAddress else {
            return
        }
        var offset = 0
        while offset < bytes.count {
            let written = write(
                descriptor,
                baseAddress.advanced(by: offset),
                bytes.count - offset
            )
            if written < 0 {
                if errno == EINTR {
                    continue
                }
                throw CodexProcessError.inputWriteFailed
            }
            offset += written
        }
    }
}

private func waitForExitOrTermination(
    pid: pid_t,
    timeout: Duration,
    control: CodexProcessControl
) async throws -> CodexProcessError? {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)

    while true {
        if try processHasWaitableExit(pid) {
            return nil
        }
        if control.isCancellationRequested {
            return .cancelled
        }
        if let asynchronousError = control.asynchronousError {
            return asynchronousError
        }
        if clock.now >= deadline {
            return .timedOut
        }
        try? await Task.sleep(for: .milliseconds(10))
    }
}

private func processHasWaitableExit(_ pid: pid_t) throws -> Bool {
    var information = siginfo_t()
    let result = waitid(
        P_PID,
        UInt32(pid),
        &information,
        WEXITED | WNOHANG | WNOWAIT
    )
    guard result == 0 else {
        throw CodexProcessError.waitFailed(errno: errno)
    }
    return information.si_pid == pid
}

private func reap(_ pid: pid_t) throws -> Int32 {
    var status: Int32 = 0
    while waitpid(pid, &status, 0) < 0 {
        if errno != EINTR {
            throw CodexProcessError.waitFailed(errno: errno)
        }
    }
    return status
}

private func normalizedExitStatus(_ waitStatus: Int32) -> Int32 {
    if waitStatus & 0x7F == 0 {
        return (waitStatus >> 8) & 0xFF
    }
    return 128 + (waitStatus & 0x7F)
}

private final class CodexProcessControl: @unchecked Sendable {
    private let lock = NSLock()
    private var cancellationRequested = false
    private var recordedAsynchronousError: CodexProcessError?

    var isCancellationRequested: Bool {
        lock.withLock { cancellationRequested }
    }

    var asynchronousError: CodexProcessError? {
        lock.withLock { recordedAsynchronousError }
    }

    func requestCancellation() {
        lock.withLock {
            cancellationRequested = true
        }
    }

    func recordAsynchronousError(_ error: CodexProcessError) {
        lock.withLock {
            if recordedAsynchronousError == nil {
                recordedAsynchronousError = error
            }
        }
    }

}

private final class CodexProcessEventChannel: @unchecked Sendable {
    private enum State {
        case open
        case finished
        case failed(Error)
    }

    private let condition = NSCondition()
    private let capacity: Int
    private var state: State = .open
    private var queuedEvents: [CodexProcessEvent] = []
    private var waiters: [
        CheckedContinuation<CodexProcessEvent?, Error>
    ] = []
    private var consumerCancelled = false

    init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    func send(_ event: CodexProcessEvent) throws {
        condition.lock()
        guard isOpen, !consumerCancelled else {
            condition.unlock()
            return
        }
        let waiter: CheckedContinuation<CodexProcessEvent?, Error>?
        if !waiters.isEmpty {
            waiter = waiters.removeFirst()
        } else {
            guard queuedEvents.count < capacity else {
                condition.unlock()
                throw CodexProcessError.eventBufferLimitExceeded(
                    limit: capacity
                )
            }
            queuedEvents.append(event)
            waiter = nil
        }
        condition.unlock()
        waiter?.resume(returning: event)
    }

    func finish(throwing error: Error? = nil) {
        condition.lock()
        guard isOpen else {
            condition.unlock()
            return
        }
        state = error.map(State.failed) ?? .finished
        let pending = waiters
        waiters.removeAll()
        condition.broadcast()
        condition.unlock()
        for waiter in pending {
            if let error {
                waiter.resume(throwing: error)
            } else {
                waiter.resume(returning: nil)
            }
        }
    }

    func next(
        control: CodexProcessControl
    ) async throws -> CodexProcessEvent? {
        try await withTaskCancellationHandler {
            if Task.isCancelled {
                control.requestCancellation()
                cancelConsumption()
            }
            return try await withCheckedThrowingContinuation {
                continuation in
                let immediate: (
                    event: CodexProcessEvent?,
                    error: Error?,
                    shouldResume: Bool
                )
                condition.lock()
                if consumerCancelled {
                    immediate = (
                        nil,
                        CodexProcessError.cancelled,
                        true
                    )
                } else if !queuedEvents.isEmpty {
                    immediate = (queuedEvents.removeFirst(), nil, true)
                    condition.broadcast()
                } else {
                    switch state {
                    case .open:
                        waiters.append(continuation)
                        immediate = (nil, nil, false)
                    case .finished:
                        immediate = (nil, nil, true)
                    case let .failed(error):
                        immediate = (nil, error, true)
                    }
                }
                condition.unlock()
                guard immediate.shouldResume else {
                    return
                }
                if let error = immediate.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: immediate.event)
                }
            }
        } onCancel: {
            control.requestCancellation()
            cancelConsumption()
        }
    }

    private var isOpen: Bool {
        if case .open = state {
            return true
        }
        return false
    }

    private func cancelConsumption() {
        condition.lock()
        guard !consumerCancelled else {
            condition.unlock()
            return
        }
        consumerCancelled = true
        state = .failed(CodexProcessError.cancelled)
        queuedEvents.removeAll()
        let pending = waiters
        waiters.removeAll()
        condition.broadcast()
        condition.unlock()
        for waiter in pending {
            waiter.resume(throwing: CodexProcessError.cancelled)
        }
    }
}
