import Foundation

public enum ActionResultStatus: String, Codable, Sendable, Equatable {
    case dryRun
    case succeeded
    case partiallyFailed
}

public struct ActionResult: Codable, Sendable, Equatable {
    public let status: ActionResultStatus
    public let logicalBytesAffected: Int64
    public let allocatedBytesAffected: Int64
    public let completedItems: Int
    public let failedItems: Int
    public let exitStatus: Int32?
    public let startedAt: Date
    public let finishedAt: Date
    public let trashReceipt: TrashedItemReceipt?

    public init(
        status: ActionResultStatus,
        logicalBytesAffected: Int64,
        allocatedBytesAffected: Int64,
        completedItems: Int,
        failedItems: Int,
        exitStatus: Int32?,
        startedAt: Date,
        finishedAt: Date,
        trashReceipt: TrashedItemReceipt?
    ) {
        self.status = status
        self.logicalBytesAffected = logicalBytesAffected
        self.allocatedBytesAffected = allocatedBytesAffected
        self.completedItems = completedItems
        self.failedItems = failedItems
        self.exitStatus = exitStatus
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.trashReceipt = trashReceipt
    }
}

public enum ActionExecution: Sendable, Equatable {
    case trash(
        receipt: TrashedItemReceipt,
        startedAt: Date,
        finishedAt: Date
    )
    case registered(
        invocation: RegisteredActionInvocation,
        output: RegisteredActionProcessOutput?,
        startedAt: Date,
        finishedAt: Date
    )
}

public enum ActionExecutionError: Error, Sendable, Equatable {
    case invalidPreflightToken
    case timedOut
    case launchFailed(String)
    case outputReadFailed(stream: String, reason: String)
    case terminationFailed(ProcessTreeTerminationError)
    case malformedOutput
    case unexpectedResult
    case outputTruncated
}
