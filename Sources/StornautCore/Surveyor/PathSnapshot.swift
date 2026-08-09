import Foundation

public enum PathKind: String, Codable, Sendable, Equatable {
    case regularFile
    case directory
    case symbolicLink
    case other
    case inaccessible
}

public typealias SnapshotKind = PathKind

public enum ScanIssue: String, Codable, Sendable, Equatable {
    case permissionDenied
    case mountBoundary
    case metadataUnavailable
    case directoryReadFailed
}

public enum MeasurementStatus: String, Codable, Sendable, Equatable {
    case measured
    case permissionDenied
    case mountBoundary
    case metadataUnavailable
    case directoryReadFailed

    init(issue: ScanIssue?) {
        switch issue {
        case nil:
            self = .measured
        case .permissionDenied:
            self = .permissionDenied
        case .mountBoundary:
            self = .mountBoundary
        case .metadataUnavailable:
            self = .metadataUnavailable
        case .directoryReadFailed:
            self = .directoryReadFailed
        }
    }

    var issue: ScanIssue? {
        switch self {
        case .measured:
            nil
        case .permissionDenied:
            .permissionDenied
        case .mountBoundary:
            .mountBoundary
        case .metadataUnavailable:
            .metadataUnavailable
        case .directoryReadFailed:
            .directoryReadFailed
        }
    }
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
    public let schemaVersion: DomainSchemaVersion
    public let id: SnapshotID
    public let sessionID: ScanSessionID
    public let scopeID: ScanScopeID
    public let relativePath: String
    public let kind: PathKind
    public let logicalByteCount: ByteCount?
    public let allocatedByteCount: ByteCount?
    public let modifiedAt: Date?
    public let fileIdentity: FileIdentity?
    public let symlinkTarget: String?
    public let measurementStatus: MeasurementStatus
    public let observedAt: Date

    public init(
        schemaVersion: DomainSchemaVersion = .v1,
        id: SnapshotID,
        sessionID: ScanSessionID,
        scopeID: ScanScopeID,
        relativePath: String,
        kind: PathKind,
        logicalByteCount: ByteCount?,
        allocatedByteCount: ByteCount?,
        modifiedAt: Date?,
        fileIdentity: FileIdentity?,
        symlinkTarget: String?,
        measurementStatus: MeasurementStatus,
        observedAt: Date
    ) throws {
        let hasCompleteMetadata = logicalByteCount != nil
            && allocatedByteCount != nil
            && modifiedAt != nil
            && fileIdentity != nil
        let identityMatchesBytes = fileIdentity.map { identity in
            logicalByteCount?.value == UInt64(exactly: identity.size)
                && allocatedByteCount?.value
                    == UInt64(exactly: identity.allocatedBytes)
        } ?? !hasCompleteMetadata
        let identityMatchesKind = fileIdentity.map { identity in
            switch kind {
            case .regularFile:
                identity.isRegularFile
            case .directory:
                identity.isDirectory
            case .symbolicLink:
                identity.isSymbolicLink
            case .other:
                !identity.isRegularFile
                    && !identity.isDirectory
                    && !identity.isSymbolicLink
            case .inaccessible:
                false
            }
        } ?? !hasCompleteMetadata
        let identityMatchesModifiedAt = fileIdentity.map { identity in
            guard let modifiedAt else {
                return false
            }
            let expected = TimeInterval(identity.modificationSeconds)
                + TimeInterval(identity.modificationNanoseconds)
                    / 1_000_000_000
            return abs(modifiedAt.timeIntervalSince1970 - expected) < 0.001
        } ?? !hasCompleteMetadata
        let valid: Bool
        switch (kind, measurementStatus) {
        case (.inaccessible, .permissionDenied),
             (.inaccessible, .metadataUnavailable),
             (.inaccessible, .directoryReadFailed):
            valid = logicalByteCount == nil
                && allocatedByteCount == nil
                && fileIdentity == nil
        case (.directory, .mountBoundary):
            valid = hasCompleteMetadata
        case (.regularFile, .measured),
             (.directory, .measured),
             (.symbolicLink, .measured),
             (.other, .measured):
            valid = hasCompleteMetadata
        default:
            valid = false
        }
        guard valid,
              identityMatchesBytes,
              identityMatchesKind,
              identityMatchesModifiedAt,
              Self.isValidRelativePath(relativePath),
              Self.isValidSymlinkTarget(symlinkTarget, kind: kind)
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.schemaVersion = schemaVersion
        self.id = id
        self.sessionID = sessionID
        self.scopeID = scopeID
        self.relativePath = relativePath
        self.kind = kind
        self.logicalByteCount = logicalByteCount
        self.allocatedByteCount = allocatedByteCount
        self.modifiedAt = modifiedAt
        self.fileIdentity = fileIdentity
        self.symlinkTarget = symlinkTarget
        self.measurementStatus = measurementStatus
        self.observedAt = observedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(
                DomainSchemaVersion.self,
                forKey: .schemaVersion
            ),
            id: container.decode(SnapshotID.self, forKey: .id),
            sessionID: container.decode(ScanSessionID.self, forKey: .sessionID),
            scopeID: container.decode(ScanScopeID.self, forKey: .scopeID),
            relativePath: container.decode(String.self, forKey: .relativePath),
            kind: container.decode(PathKind.self, forKey: .kind),
            logicalByteCount: container.decodeIfPresent(
                ByteCount.self,
                forKey: .logicalByteCount
            ),
            allocatedByteCount: container.decodeIfPresent(
                ByteCount.self,
                forKey: .allocatedByteCount
            ),
            modifiedAt: container.decodeIfPresent(
                Date.self,
                forKey: .modifiedAt
            ),
            fileIdentity: container.decodeIfPresent(
                FileIdentity.self,
                forKey: .fileIdentity
            ),
            symlinkTarget: container.decodeIfPresent(
                String.self,
                forKey: .symlinkTarget
            ),
            measurementStatus: container.decode(
                MeasurementStatus.self,
                forKey: .measurementStatus
            ),
            observedAt: container.decode(Date.self, forKey: .observedAt)
        )
    }

    public var logicalBytes: Int64? {
        logicalByteCount?.int64Value
    }

    public var allocatedBytes: Int64? {
        allocatedByteCount?.int64Value
    }

    public var device: UInt64? {
        fileIdentity?.device
    }

    public var inode: UInt64? {
        fileIdentity?.inode
    }

    public var issue: ScanIssue? {
        measurementStatus.issue
    }

    private static func isValidRelativePath(_ path: String) -> Bool {
        guard path == "." || !path.isEmpty,
              !path.hasPrefix("/"),
              !path.contains("\0"),
              path.utf8.count <= 16_384
        else {
            return false
        }
        if path == "." {
            return true
        }
        return path.split(separator: "/", omittingEmptySubsequences: false)
            .allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    private static func isValidSymlinkTarget(
        _ target: String?,
        kind: PathKind
    ) -> Bool {
        if kind != .symbolicLink {
            return target == nil
        }
        guard let target else {
            return true
        }
        return !target.isEmpty
            && !target.contains("\0")
            && target.utf8.count <= 16_384
    }
}

public struct SurveyorObservation: Sendable, Equatable {
    public let snapshot: PathSnapshot
    public let progress: ScanProgress

    public init(snapshot: PathSnapshot, progress: ScanProgress) {
        self.snapshot = snapshot
        self.progress = progress
    }

    public var relativePath: String { snapshot.relativePath }
    public var kind: PathKind { snapshot.kind }
    public var logicalBytes: Int64? { snapshot.logicalBytes }
    public var allocatedBytes: Int64? { snapshot.allocatedBytes }
    public var device: UInt64? { snapshot.device }
    public var inode: UInt64? { snapshot.inode }
    public var observedAt: Date { snapshot.observedAt }
    public var issue: ScanIssue? { snapshot.issue }
    public var measurementStatus: MeasurementStatus {
        snapshot.measurementStatus
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
