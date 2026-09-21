import Foundation

public struct ProcessRequest: Sendable, Equatable {
    public let executableURL: URL
    public let arguments: [String]
    public let environment: [String: String]
    public let currentDirectoryURL: URL?
    public let standardInput: Data
    public let standardOutputLimit: Int
    public let standardErrorLimit: Int
    public let timeout: Duration

    public init(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        currentDirectoryURL: URL? = nil,
        standardInput: Data = Data(),
        standardOutputLimit: Int,
        standardErrorLimit: Int,
        timeout: Duration
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.environment = environment
        self.currentDirectoryURL = currentDirectoryURL
        self.standardInput = standardInput
        self.standardOutputLimit = standardOutputLimit
        self.standardErrorLimit = standardErrorLimit
        self.timeout = timeout
    }
}

public struct ProcessOutput: Sendable, Equatable {
    public let exitStatus: Int32
    public let stdout: Data
    public let stderr: Data
    public let stdoutWasTruncated: Bool
    public let stderrWasTruncated: Bool

    public init(
        exitStatus: Int32,
        stdout: Data,
        stderr: Data = Data(),
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

public protocol ProcessRunning: Sendable {
    func run(_ request: ProcessRequest) async throws -> ProcessOutput
}

public enum ProcessRunningError: Error, Sendable, Equatable {
    case invalidOutputLimit
    case standardInputUnsupported
    case launchFailed(String)
    case outputReadFailed(stream: String, reason: String)
    case timedOut
}

public struct FoundationProcessRunner: ProcessRunning {
    public init() {}

    public func run(_ request: ProcessRequest) async throws -> ProcessOutput {
        try await withCheckedThrowingContinuation { continuation in
            foundationProcessRunnerQueue.async {
                do {
                    continuation.resume(
                        returning: try runSynchronously(request)
                    )
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private let foundationProcessRunnerQueue = DispatchQueue(
    label: "com.eriklee.stornaut.foundation-process-runner",
    qos: .userInitiated,
    attributes: .concurrent
)

private func runSynchronously(_ request: ProcessRequest) throws -> ProcessOutput {
    guard request.standardOutputLimit >= 0, request.standardErrorLimit >= 0 else {
        throw ProcessRunningError.invalidOutputLimit
    }
    guard request.standardInput.isEmpty else {
        throw ProcessRunningError.standardInputUnsupported
    }
    guard request.timeout > .zero else {
        throw ProcessRunningError.timedOut
    }
    let currentDirectoryURL = request.currentDirectoryURL
        ?? URL(
            filePath: FileManager.default.currentDirectoryPath,
            directoryHint: .isDirectory
        )
    do {
        let output = try FoundationCodexRuntimeDiagnosticProcessRunner().run(
            executableURL: request.executableURL,
            arguments: request.arguments,
            environment: request.environment,
            currentDirectoryURL: currentDirectoryURL,
            standardInput: nil,
            standardOutputLimit: request.standardOutputLimit,
            standardErrorLimit: request.standardErrorLimit,
            timeout: request.timeout,
            rejectTruncatedOutput: false,
            requireUTF8: false
        )
        return ProcessOutput(
            exitStatus: output.exitStatus,
            stdout: output.stdout,
            stderr: output.stderr,
            stdoutWasTruncated: output.stdoutWasTruncated,
            stderrWasTruncated: output.stderrWasTruncated
        )
    } catch CodexRuntimeDiagnosticError.timedOut {
        throw ProcessRunningError.timedOut
    } catch let CodexRuntimeDiagnosticError.outputReadFailed(stream) {
        throw ProcessRunningError.outputReadFailed(
            stream: stream,
            reason: "bounded diagnostic pipe read failed"
        )
    } catch let error as CodexRuntimeDiagnosticError {
        throw ProcessRunningError.launchFailed(String(describing: error))
    }
}
