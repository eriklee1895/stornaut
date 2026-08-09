import Foundation

public enum ScanTerminalState: String, Codable, Sendable, CaseIterable {
    case completed
    case partial
    case cancelled
    case failed
}

public enum ScanScopeCompletionReason: String, Codable, Sendable {
    case cancelled
    case permissionDenied
    case mountBoundary
    case metadataChanged
    case storeFailure
    case scannerFailure
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

    public init(
        schemaVersion: DomainSchemaVersion = .v1,
        id: ScanSessionID,
        startedAt: Date,
        finishedAt: Date,
        terminalState: ScanTerminalState,
        completedScopes: [ScanScope],
        unfinishedScopes: [UnfinishedScanScope]
    ) throws {
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
            )
        )
    }
}
