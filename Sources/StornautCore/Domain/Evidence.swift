import Foundation

public enum EvidenceKind: String, Codable, Sendable, CaseIterable {
    case space
    case producer
    case activity
    case git
    case rebuildability
    case rule
    case policy
    case permission
    case volume
}

public enum EvidenceSourceKind: String, Codable, Sendable, CaseIterable {
    case surveyor
    case rule
    case activityProvider
    case localKnowledge
    case policyGate
    case system
}

public struct EvidenceSource: Codable, Sendable, Equatable {
    public let kind: EvidenceSourceKind
    public let identifier: DomainToken

    public init(kind: EvidenceSourceKind, identifier: DomainToken) {
        self.kind = kind
        self.identifier = identifier
    }
}

public enum EvidenceFreshness: String, Codable, Sendable, CaseIterable {
    case current
    case stale
    case expired
}

public struct EvidenceRecord: Codable, Sendable, Equatable {
    public let schemaVersion: DomainSchemaVersion
    public let id: EvidenceID
    public let targetID: SnapshotID
    public let kind: EvidenceKind
    public let source: EvidenceSource
    public let summaryKey: DomainToken
    public let observedAt: Date
    public let freshness: EvidenceFreshness

    public init(
        schemaVersion: DomainSchemaVersion = .v1,
        id: EvidenceID,
        targetID: SnapshotID,
        kind: EvidenceKind,
        source: EvidenceSource,
        summaryKey: DomainToken,
        observedAt: Date,
        freshness: EvidenceFreshness
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.targetID = targetID
        self.kind = kind
        self.source = source
        self.summaryKey = summaryKey
        self.observedAt = observedAt
        self.freshness = freshness
    }
}

public struct InvestigationTarget: Codable, Sendable, Equatable {
    public let schemaVersion: DomainSchemaVersion
    public let id: InvestigationTargetID
    public let snapshotID: SnapshotID
    public let expectedBytes: ByteCount?
    public let reasonKey: DomainToken
    public let createdAt: Date

    public init(
        schemaVersion: DomainSchemaVersion = .v1,
        id: InvestigationTargetID,
        snapshotID: SnapshotID,
        expectedBytes: ByteCount?,
        reasonKey: DomainToken,
        createdAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.snapshotID = snapshotID
        self.expectedBytes = expectedBytes
        self.reasonKey = reasonKey
        self.createdAt = createdAt
    }
}
