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
