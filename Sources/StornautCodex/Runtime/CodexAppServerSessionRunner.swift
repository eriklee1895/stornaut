import Darwin
import Foundation
import StornautProcessSupport

private protocol CodexAppServerProtocolDriving:
    AnyObject,
    Sendable
{
    var protocolCompleted: Bool { get }
    func beginProtocol() throws -> [Data]
    func receiveProtocol(_ line: Data) throws -> [Data]
    func eraseSensitiveState()
}

struct CodexAppServerSessionRequest: Sendable {
    let executableURL: URL
    let appServerExecutableURL: URL
    let workspace: CodexRuntimeWorkspacePaths
    let projectedAuthSourceURL: URL
    let containmentConfiguration: CodexContainmentConfiguration
    let environment: CodexRuntimeEnvironment
    let runtime: CodexAppServerRuntime
    let timeout: Duration
    let standardOutputByteLimit: Int
    let standardErrorByteLimit: Int
    let lineByteLimit: Int

    init(
        executableURL: URL,
        appServerExecutableURL: URL? = nil,
        workspace: CodexRuntimeWorkspacePaths,
        projectedAuthSourceURL: URL,
        containmentConfiguration: CodexContainmentConfiguration,
        environment: CodexRuntimeEnvironment,
        runtime: CodexAppServerRuntime,
        timeout: Duration,
        standardOutputByteLimit: Int,
        standardErrorByteLimit: Int,
        lineByteLimit: Int
    ) {
        self.executableURL = executableURL
        self.appServerExecutableURL =
            appServerExecutableURL ?? executableURL
        self.workspace = workspace
        self.projectedAuthSourceURL = projectedAuthSourceURL
        self.containmentConfiguration = containmentConfiguration
        self.environment = environment
        self.runtime = runtime
        self.timeout = timeout
        self.standardOutputByteLimit = standardOutputByteLimit
        self.standardErrorByteLimit = standardErrorByteLimit
        self.lineByteLimit = lineByteLimit
    }
}

struct CodexAppServerSessionResult: Sendable, Equatable {
    let observation: CodexAppServerObservation
    let standardErrorByteCount: Int
}

struct CodexProviderCatalogPreflightSessionRequest: Sendable {
    let executableURL: URL
    let appServerExecutableURL: URL
    let workspace: CodexRuntimeWorkspacePaths
    let deniedAuthSourceURL: URL
    let containmentConfiguration: CodexContainmentConfiguration
    let environment: CodexRuntimeEnvironment
    let runtime: CodexProviderCatalogPreflightRuntime
    let timeout: Duration
    let standardOutputByteLimit: Int
    let standardErrorByteLimit: Int
    let lineByteLimit: Int

    init(
        executableURL: URL,
        appServerExecutableURL: URL? = nil,
        workspace: CodexRuntimeWorkspacePaths,
        deniedAuthSourceURL: URL,
        containmentConfiguration: CodexContainmentConfiguration,
        environment: CodexRuntimeEnvironment,
        runtime: CodexProviderCatalogPreflightRuntime,
        timeout: Duration,
        standardOutputByteLimit: Int,
        standardErrorByteLimit: Int,
        lineByteLimit: Int
    ) {
        self.executableURL = executableURL
        self.appServerExecutableURL =
            appServerExecutableURL ?? executableURL
        self.workspace = workspace
        self.deniedAuthSourceURL = deniedAuthSourceURL
        self.containmentConfiguration = containmentConfiguration
        self.environment = environment
        self.runtime = runtime
        self.timeout = timeout
        self.standardOutputByteLimit = standardOutputByteLimit
        self.standardErrorByteLimit = standardErrorByteLimit
        self.lineByteLimit = lineByteLimit
    }
}

struct CodexProviderCatalogPreflightSessionResult:
    Sendable,
    Equatable
{
    let report: CodexProviderCatalogPreflightReport
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
    case providerCatalogProtocolFailure(
        CodexProviderCatalogPreflightError
    )
    case timedOut
    case cancelled
    case nonzeroExit
    case terminationFailed
}

extension CodexAppServerRuntime: CodexAppServerProtocolDriving {
    fileprivate var protocolCompleted: Bool {
        status == .completed
    }

    fileprivate func beginProtocol() throws -> [Data] {
        try begin()
    }

    fileprivate func receiveProtocol(
        _ line: Data
    ) throws -> [Data] {
        try receive(line)
    }

    fileprivate func eraseSensitiveState() {
        eraseCredentials()
    }
}

extension CodexProviderCatalogPreflightRuntime:
    CodexAppServerProtocolDriving
{
    fileprivate var protocolCompleted: Bool {
        status == .completed
    }

    fileprivate func beginProtocol() throws -> [Data] {
        try begin()
    }

    fileprivate func receiveProtocol(
        _ line: Data
    ) throws -> [Data] {
        try receive(line)
    }

    fileprivate func eraseSensitiveState() {}
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

    func runProviderCatalogPreflight(
        _ request: CodexProviderCatalogPreflightSessionRequest
    ) async throws -> CodexProviderCatalogPreflightSessionResult {
        let cancellation = AppServerSessionCancellation()
        return try await withTaskCancellationHandler {
            try await Task.detached(priority: .utility) {
                try runProviderCatalogPreflightSynchronously(
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
            request.appServerExecutableURL.isFileURL,
            request.appServerExecutableURL.path.hasPrefix("/"),
            isCanonicalRegularExecutable(
                request.appServerExecutableURL
            ),
            appServerExecutableIsAdmitted(
                outerExecutableURL: request.executableURL,
                appServerExecutableURL:
                    request.appServerExecutableURL,
                workspace: request.workspace,
                readScope: request.containmentConfiguration.readScope
            ),
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

        let arguments = try validatedArguments(
            executableURL: request.appServerExecutableURL,
            workspace: request.workspace,
            deniedAuthSourceURL: request.projectedAuthSourceURL,
            containmentConfiguration: request.containmentConfiguration
        )
        let standardErrorByteCount = try runProtocolSession(
            executableURL: request.executableURL,
            arguments: arguments,
            workspace: request.workspace,
            environment: request.environment,
            runtime: request.runtime,
            timeout: request.timeout,
            standardOutputByteLimit: request.standardOutputByteLimit,
            standardErrorByteLimit: request.standardErrorByteLimit,
            lineByteLimit: request.lineByteLimit,
            cancellation: cancellation
        )
        return CodexAppServerSessionResult(
            observation: request.runtime.observation,
            standardErrorByteCount: standardErrorByteCount
        )
    }

    private func runProviderCatalogPreflightSynchronously(
        _ request: CodexProviderCatalogPreflightSessionRequest,
        cancellation: AppServerSessionCancellation
    ) throws -> CodexProviderCatalogPreflightSessionResult {
        guard
            request.executableURL.isFileURL,
            request.executableURL.path.hasPrefix("/"),
            isCanonicalRegularExecutable(request.executableURL),
            request.appServerExecutableURL.isFileURL,
            request.appServerExecutableURL.path.hasPrefix("/"),
            isCanonicalRegularExecutable(
                request.appServerExecutableURL
            ),
            appServerExecutableIsAdmitted(
                outerExecutableURL: request.executableURL,
                appServerExecutableURL:
                    request.appServerExecutableURL,
                workspace: request.workspace,
                readScope: request.containmentConfiguration.readScope
            ),
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

        let arguments = try validatedArguments(
            executableURL: request.appServerExecutableURL,
            workspace: request.workspace,
            deniedAuthSourceURL: request.deniedAuthSourceURL,
            containmentConfiguration: request.containmentConfiguration
        )
        let standardErrorByteCount = try runProtocolSession(
            executableURL: request.executableURL,
            arguments: arguments,
            workspace: request.workspace,
            environment: request.environment,
            runtime: request.runtime,
            timeout: request.timeout,
            standardOutputByteLimit: request.standardOutputByteLimit,
            standardErrorByteLimit: request.standardErrorByteLimit,
            lineByteLimit: request.lineByteLimit,
            cancellation: cancellation
        )
        guard let report = request.runtime.report else {
            throw CodexAppServerSessionError.protocolFailure(
                .invalidMessage
            )
        }
        return CodexProviderCatalogPreflightSessionResult(
            report: report,
            standardErrorByteCount: standardErrorByteCount
        )
    }

    private func validatedArguments(
        executableURL: URL,
        workspace: CodexRuntimeWorkspacePaths,
        deniedAuthSourceURL: URL,
        containmentConfiguration: CodexContainmentConfiguration
    ) throws -> [String] {
        do {
            let policy = CodexContainmentPolicy()
            let expectedConfiguration = try policy.configuration(
                workspace: workspace,
                projectedAuthSourceURL: deniedAuthSourceURL,
                readScope: containmentConfiguration.readScope
            )
            guard expectedConfiguration == containmentConfiguration else {
                throw CodexAppServerSessionError.invalidRequest
            }
            try policy.validateInstalled(
                containmentConfiguration,
                in: workspace
            )
            return try policy.launchArguments(
                codexExecutableURL: executableURL,
                workspace: workspace
            )
        } catch {
            throw CodexAppServerSessionError.invalidRequest
        }
    }

    private func runProtocolSession(
        executableURL: URL,
        arguments: [String],
        workspace: CodexRuntimeWorkspacePaths,
        environment: CodexRuntimeEnvironment,
        runtime: any CodexAppServerProtocolDriving,
        timeout: Duration,
        standardOutputByteLimit: Int,
        standardErrorByteLimit: Int,
        lineByteLimit: Int,
        cancellation: AppServerSessionCancellation
    ) throws -> Int {
        let process: SpawnedDiagnosticProcess
        do {
            process = try spawnDiagnosticProcess(
                executableURL: executableURL,
                arguments: arguments,
                environment: environment.values,
                currentDirectoryURL: workspace.workURL
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
            lineByteLimit: lineByteLimit,
            sessionByteLimit: standardOutputByteLimit
        )
        let errorHandle = FileHandle(
            fileDescriptor: process.standardError,
            closeOnDealloc: true
        )
        let standardError = BoundedAppServerErrorOutput(
            limit: standardErrorByteLimit
        )
        let errorGroup = DispatchGroup()
        errorGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            standardError.drain(errorHandle)
            errorGroup.leave()
        }
        defer {
            runtime.eraseSensitiveState()
            writer.close()
            reader.close()
            try? errorHandle.close()
            if !reaped {
                forceCleanupDiagnosticProcess(process)
            }
            errorGroup.wait()
        }

        let deadline = timeout.dispatchDeadline
        do {
            for var message in try runtime.beginProtocol() {
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

        while !runtime.protocolCompleted {
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
                responses = try runtime.receiveProtocol(line)
            } catch let error as CodexAppServerRuntimeError {
                throw CodexAppServerSessionError.protocolFailure(error)
            } catch let error as CodexProviderCatalogPreflightError {
                throw CodexAppServerSessionError
                    .providerCatalogProtocolFailure(error)
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
        do {
            try terminateDiagnosticProcessGroup(process.processGroup)
        } catch {
            throw CodexAppServerSessionError.terminationFailed
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
        guard protocolCompletionExitStatusIsAllowed(waitStatus) else {
            throw CodexAppServerSessionError.nonzeroExit
        }
        return standardError.byteCount
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

private func protocolCompletionExitStatusIsAllowed(
    _ waitStatus: Int32
) -> Bool {
    let status = normalizedDiagnosticExitStatus(waitStatus)
    return status == 0
        || status == 128 + SIGINT
        || status == 128 + SIGTERM
        || status == 128 + SIGKILL
}

final class BoundedAppServerWriter {
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

private func appServerExecutableIsAdmitted(
    outerExecutableURL: URL,
    appServerExecutableURL: URL,
    workspace: CodexRuntimeWorkspacePaths,
    readScope: CodexContainmentReadScope
) -> Bool {
    switch readScope {
    case .fullDiskReadOnly:
        return appServerExecutableURL == outerExecutableURL
    case .syntheticDiagnostic:
        let expected = workspace.fixturesURL.appending(
            path: "codex-r5-package/bin/codex"
        ).standardizedFileURL
        guard appServerExecutableURL.standardizedFileURL == expected else {
            return false
        }
        var information = stat()
        return lstat(expected.path, &information) == 0
            && information.st_mode & S_IFMT == S_IFREG
            && information.st_uid == geteuid()
            && information.st_mode & 0o777 == 0o500
            && information.st_nlink == 1
    }
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

final class BoundedAppServerLineReader {
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

final class AppServerSessionCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.withLock { cancelled }
    }

    func cancel() {
        lock.withLock { cancelled = true }
    }
}

final class BoundedAppServerErrorOutput: @unchecked Sendable {
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

    func drain(
        descriptor: Int32,
        cancellation: AppServerSessionCancellation
    ) {
        while true {
            let isCancelled = cancellation.isCancelled
            var pollDescriptor = pollfd(
                fd: descriptor,
                events: Int16(POLLIN | POLLHUP),
                revents: 0
            )
            let result = poll(
                &pollDescriptor,
                1,
                isCancelled ? 0 : 50
            )
            if result == 0 {
                if isCancelled {
                    return
                }
                continue
            }
            if result < 0 {
                if errno == EINTR { continue }
                lock.withLock { failed = true }
                return
            }
            var bytes = [UInt8](repeating: 0, count: 4_096)
            let readCount = Darwin.read(
                descriptor,
                &bytes,
                bytes.count
            )
            if readCount == 0 {
                return
            }
            if readCount < 0 {
                if errno == EINTR { continue }
                lock.withLock { failed = true }
                return
            }
            record(readCount)
        }
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
                record(chunk.count)
            } catch {
                lock.withLock { failed = true }
                return
            }
        }
    }

    private func record(_ byteCount: Int) {
        lock.withLock {
            let next = count.addingReportingOverflow(byteCount)
            if next.overflow || next.partialValue > limit {
                truncated = true
                count = limit
            } else {
                count = next.partialValue
            }
        }
    }
}
