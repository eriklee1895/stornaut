import Foundation

public enum SnapshotKind: String, Codable, Sendable, Equatable {
    case regularFile
    case directory
    case symbolicLink
    case other
    case inaccessible
}

public enum ScanIssue: String, Codable, Sendable, Equatable {
    case permissionDenied
    case mountBoundary
    case metadataUnavailable
    case directoryReadFailed
}

public struct ScanProgress: Codable, Sendable, Equatable {
    public let completedEntries: Int
    public let regularFileCount: Int
    public let directoryCount: Int
    public let symlinkCount: Int
    public let errorCount: Int
    public let logicalFileBytes: Int64
    public let allocatedFileBytes: Int64

    public init(
        completedEntries: Int,
        regularFileCount: Int,
        directoryCount: Int,
        symlinkCount: Int,
        errorCount: Int,
        logicalFileBytes: Int64,
        allocatedFileBytes: Int64
    ) {
        self.completedEntries = completedEntries
        self.regularFileCount = regularFileCount
        self.directoryCount = directoryCount
        self.symlinkCount = symlinkCount
        self.errorCount = errorCount
        self.logicalFileBytes = logicalFileBytes
        self.allocatedFileBytes = allocatedFileBytes
    }
}

public struct PathSnapshot: Codable, Sendable, Equatable {
    public let relativePath: String
    public let kind: SnapshotKind
    public let logicalBytes: Int64?
    public let allocatedBytes: Int64?
    public let device: UInt64?
    public let inode: UInt64?
    public let observedAt: Date
    public let issue: ScanIssue?
    public let progress: ScanProgress

    public init(
        relativePath: String,
        kind: SnapshotKind,
        logicalBytes: Int64?,
        allocatedBytes: Int64?,
        device: UInt64?,
        inode: UInt64?,
        observedAt: Date,
        issue: ScanIssue?,
        progress: ScanProgress
    ) {
        self.relativePath = relativePath
        self.kind = kind
        self.logicalBytes = logicalBytes
        self.allocatedBytes = allocatedBytes
        self.device = device
        self.inode = inode
        self.observedAt = observedAt
        self.issue = issue
        self.progress = progress
    }
}

public enum SurveyorError: Error, Sendable, Equatable {
    case invalidRoot
    case invalidWorkerCount
    case invalidQueueCapacity
    case invalidStreamBufferCapacity
    case streamBufferExceeded
    case cancelled
    case internalInvariant
}
