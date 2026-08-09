import Foundation

public struct ProcessRequest: Sendable, Equatable {
    public let executableURL: URL
    public let arguments: [String]
    public let environment: [String: String]
    public let standardInput: Data
    public let standardOutputLimit: Int
    public let standardErrorLimit: Int
    public let timeout: Duration

    public init(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        standardInput: Data = Data(),
        standardOutputLimit: Int,
        standardErrorLimit: Int,
        timeout: Duration
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.environment = environment
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
        try await Task.detached(priority: .utility) {
            try runSynchronously(request)
        }.value
    }
}

private func runSynchronously(_ request: ProcessRequest) throws -> ProcessOutput {
    guard request.standardOutputLimit >= 0, request.standardErrorLimit >= 0 else {
        throw ProcessRunningError.invalidOutputLimit
    }
    guard request.standardInput.isEmpty else {
        throw ProcessRunningError.standardInputUnsupported
    }

    let process = Process()
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    let termination = DispatchSemaphore(value: 0)
    let readers = DispatchGroup()
    let stdout = LockedBox(BoundedOutput())
    let stderr = LockedBox(BoundedOutput())

    process.executableURL = request.executableURL
    process.arguments = request.arguments
    process.environment = request.environment
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    process.terminationHandler = { _ in
        termination.signal()
    }

    readers.enter()
    DispatchQueue.global(qos: .utility).async {
        let output = drain(
            stdoutPipe.fileHandleForReading,
            limit: request.standardOutputLimit
        )
        stdout.set(output)
        readers.leave()
    }

    readers.enter()
    DispatchQueue.global(qos: .utility).async {
        let output = drain(
            stderrPipe.fileHandleForReading,
            limit: request.standardErrorLimit
        )
        stderr.set(output)
        readers.leave()
    }

    do {
        try process.run()
    } catch {
        stdoutPipe.fileHandleForWriting.closeFile()
        stderrPipe.fileHandleForWriting.closeFile()
        readers.wait()
        throw ProcessRunningError.launchFailed(String(describing: error))
    }

    let waitResult = termination.wait(timeout: request.timeout.dispatchDeadline)
    guard waitResult == .success else {
        process.terminate()
        if termination.wait(timeout: .now() + .milliseconds(250)) == .timedOut {
            kill(process.processIdentifier, SIGKILL)
            _ = termination.wait(timeout: .now() + .seconds(2))
        }
        throw ProcessRunningError.timedOut
    }

    readers.wait()
    let stdoutValue = stdout.value
    let stderrValue = stderr.value
    if let reason = stdoutValue.readError {
        throw ProcessRunningError.outputReadFailed(
            stream: "stdout",
            reason: reason
        )
    }
    if let reason = stderrValue.readError {
        throw ProcessRunningError.outputReadFailed(
            stream: "stderr",
            reason: reason
        )
    }
    return ProcessOutput(
        exitStatus: process.terminationStatus,
        stdout: stdoutValue.data,
        stderr: stderrValue.data,
        stdoutWasTruncated: stdoutValue.wasTruncated,
        stderrWasTruncated: stderrValue.wasTruncated
    )
}

private struct BoundedOutput: Sendable {
    var data = Data()
    var wasTruncated = false
    var readError: String?
}

private final class LockedBox<Value: Sendable>: @unchecked Sendable {
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

private func drain(_ fileHandle: FileHandle, limit: Int) -> BoundedOutput {
    var output = BoundedOutput()

    while true {
        do {
            guard let chunk = try fileHandle.read(upToCount: 4_096), !chunk.isEmpty else {
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

private extension Duration {
    var dispatchDeadline: DispatchTime {
        guard self > .zero else {
            return .now()
        }

        let components = self.components
        let seconds = components.seconds
        let fractionalNanoseconds = components.attoseconds / 1_000_000_000
        let secondsInNanoseconds = seconds.multipliedReportingOverflow(by: 1_000_000_000)
        let total: Int64
        if secondsInNanoseconds.overflow {
            total = .max
        } else {
            let addition = secondsInNanoseconds.partialValue.addingReportingOverflow(
                fractionalNanoseconds
            )
            total = addition.overflow ? .max : addition.partialValue
        }
        return .now() + .nanoseconds(Int(clamping: total))
    }
}
