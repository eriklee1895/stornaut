import Foundation

public enum ScanTerminalState: String, Codable, Sendable, CaseIterable {
    case completed
    case partial
    case cancelled
    case failed
}

public enum ScanScopeCompletionReason: String, Codable, Sendable {
    case interrupted
    case cancelled
    case permissionDenied
    case mountBoundary
    case userExcluded
    case metadataChanged
    case storeFailure
    case scannerFailure
}

public struct ScanEntryCounts: Codable, Sendable, Equatable {
    public let total: Int
    public let regularFiles: Int
    public let directories: Int
    public let symbolicLinks: Int
    public let inaccessible: Int
    public let other: Int

    public init(
        total: Int,
        regularFiles: Int,
        directories: Int,
        symbolicLinks: Int,
        inaccessible: Int,
        other: Int
    ) throws {
        let values = [
            total,
            regularFiles,
            directories,
            symbolicLinks,
            inaccessible,
            other,
        ]
        let counted = Self.checkedSum(Array(values.dropFirst()))
        guard values.allSatisfy({ $0 >= 0 }),
              counted == total
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.total = total
        self.regularFiles = regularFiles
        self.directories = directories
        self.symbolicLinks = symbolicLinks
        self.inaccessible = inaccessible
        self.other = other
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            total: container.decode(Int.self, forKey: .total),
            regularFiles: container.decode(
                Int.self,
                forKey: .regularFiles
            ),
            directories: container.decode(Int.self, forKey: .directories),
            symbolicLinks: container.decode(
                Int.self,
                forKey: .symbolicLinks
            ),
            inaccessible: container.decode(
                Int.self,
                forKey: .inaccessible
            ),
            other: container.decode(Int.self, forKey: .other)
        )
    }

    private static func checkedSum(_ values: [Int]) -> Int? {
        values.reduce(Optional(0)) { partial, value in
            guard let partial else {
                return nil
            }
            let result = partial.addingReportingOverflow(value)
            return result.overflow ? nil : result.partialValue
        }
    }
}

public struct ScanIssueCounts: Codable, Sendable, Equatable {
    public let permissionDenied: Int
    public let mountBoundary: Int
    public let userExcluded: Int
    public let metadataUnavailable: Int
    public let directoryReadFailed: Int

    public init(
        permissionDenied: Int,
        mountBoundary: Int,
        userExcluded: Int,
        metadataUnavailable: Int,
        directoryReadFailed: Int
    ) throws {
        let values = [
            permissionDenied,
            mountBoundary,
            userExcluded,
            metadataUnavailable,
            directoryReadFailed,
        ]
        guard values.allSatisfy({ $0 >= 0 }),
              Self.checkedSum(values) != nil
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.permissionDenied = permissionDenied
        self.mountBoundary = mountBoundary
        self.userExcluded = userExcluded
        self.metadataUnavailable = metadataUnavailable
        self.directoryReadFailed = directoryReadFailed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            permissionDenied: container.decode(
                Int.self,
                forKey: .permissionDenied
            ),
            mountBoundary: container.decode(
                Int.self,
                forKey: .mountBoundary
            ),
            userExcluded: container.decode(
                Int.self,
                forKey: .userExcluded
            ),
            metadataUnavailable: container.decode(
                Int.self,
                forKey: .metadataUnavailable
            ),
            directoryReadFailed: container.decode(
                Int.self,
                forKey: .directoryReadFailed
            )
        )
    }

    public var total: Int {
        Self.checkedSum([
            permissionDenied,
            mountBoundary,
            userExcluded,
            metadataUnavailable,
            directoryReadFailed,
        ])!
    }

    private static func checkedSum(_ values: [Int]) -> Int? {
        values.reduce(Optional(0)) { partial, value in
            guard let partial else {
                return nil
            }
            let result = partial.addingReportingOverflow(value)
            return result.overflow ? nil : result.partialValue
        }
    }
}

public struct ScanAggregate: Codable, Sendable, Equatable {
    public let entries: ScanEntryCounts
    public let issues: ScanIssueCounts
    public let logicalFileBytes: Int64
    public let allocatedFileBytes: Int64

    public init(
        entries: ScanEntryCounts,
        issues: ScanIssueCounts,
        logicalFileBytes: Int64,
        allocatedFileBytes: Int64
    ) throws {
        guard issues.total <= entries.total,
              logicalFileBytes >= 0,
              allocatedFileBytes >= 0
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.entries = entries
        self.issues = issues
        self.logicalFileBytes = logicalFileBytes
        self.allocatedFileBytes = allocatedFileBytes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            entries: container.decode(
                ScanEntryCounts.self,
                forKey: .entries
            ),
            issues: container.decode(
                ScanIssueCounts.self,
                forKey: .issues
            ),
            logicalFileBytes: container.decode(
                Int64.self,
                forKey: .logicalFileBytes
            ),
            allocatedFileBytes: container.decode(
                Int64.self,
                forKey: .allocatedFileBytes
            )
        )
    }
}

public struct ScanScope: Codable, Sendable, Equatable {
    public let id: ScanScopeID
    public let rootPath: PersistedPath
    public let completedAt: Date

    public init(
        id: ScanScopeID,
        rootPath: PersistedPath,
        completedAt: Date
    ) {
        self.id = id
        self.rootPath = rootPath
        self.completedAt = completedAt
    }
}

public struct UnfinishedScanScope: Codable, Sendable, Equatable {
    public let id: ScanScopeID
    public let rootPath: PersistedPath
    public let reason: ScanScopeCompletionReason

    public init(
        id: ScanScopeID,
        rootPath: PersistedPath,
        reason: ScanScopeCompletionReason
    ) {
        self.id = id
        self.rootPath = rootPath
        self.reason = reason
    }
}

public struct ScanSession: Codable, Sendable, Equatable {
    public let schemaVersion: DomainSchemaVersion
    public let id: ScanSessionID
    public let startedAt: Date
    public let finishedAt: Date
    public let terminalState: ScanTerminalState
    public let completedScopes: [ScanScope]
    public let unfinishedScopes: [UnfinishedScanScope]
    public let aggregate: ScanAggregate?

    public init(
        schemaVersion: DomainSchemaVersion = .v1,
        id: ScanSessionID,
        startedAt: Date,
        finishedAt: Date,
        terminalState: ScanTerminalState,
        completedScopes: [ScanScope],
        unfinishedScopes: [UnfinishedScanScope],
        aggregate: ScanAggregate? = nil
    ) throws {
        try requireDomainSchemaVersion(schemaVersion, expected: .v1)
        guard finishedAt >= startedAt,
              terminalState != .completed || unfinishedScopes.isEmpty,
              Set(completedScopes.map(\.id)).count == completedScopes.count,
              Set(unfinishedScopes.map(\.id)).count == unfinishedScopes.count,
              Set(completedScopes.map(\.id)).isDisjoint(
                with: Set(unfinishedScopes.map(\.id))
              ),
              completedScopes.allSatisfy({
                  $0.completedAt >= startedAt && $0.completedAt <= finishedAt
              })
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.schemaVersion = schemaVersion
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.terminalState = terminalState
        self.completedScopes = completedScopes
        self.unfinishedScopes = unfinishedScopes
        self.aggregate = aggregate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(
                DomainSchemaVersion.self,
                forKey: .schemaVersion
            ),
            id: container.decode(ScanSessionID.self, forKey: .id),
            startedAt: container.decode(Date.self, forKey: .startedAt),
            finishedAt: container.decode(Date.self, forKey: .finishedAt),
            terminalState: container.decode(
                ScanTerminalState.self,
                forKey: .terminalState
            ),
            completedScopes: container.decode(
                [ScanScope].self,
                forKey: .completedScopes
            ),
            unfinishedScopes: container.decode(
                [UnfinishedScanScope].self,
                forKey: .unfinishedScopes
            ),
            aggregate: container.decodeIfPresent(
                ScanAggregate.self,
                forKey: .aggregate
            )
        )
    }
}
