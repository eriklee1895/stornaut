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
        id: EvidenceID,
        targetID: SnapshotID,
        kind: EvidenceKind,
        source: EvidenceSource,
        summaryKey: DomainToken,
        observedAt: Date,
        freshness: EvidenceFreshness
    ) {
        schemaVersion = .v1
        self.id = id
        self.targetID = targetID
        self.kind = kind
        self.source = source
        self.summaryKey = summaryKey
        self.observedAt = observedAt
        self.freshness = freshness
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(
            DomainSchemaVersion.self,
            forKey: .schemaVersion
        )
        try requireDomainSchemaVersion(schemaVersion, expected: .v1)
        self.schemaVersion = schemaVersion
        id = try container.decode(EvidenceID.self, forKey: .id)
        targetID = try container.decode(SnapshotID.self, forKey: .targetID)
        kind = try container.decode(EvidenceKind.self, forKey: .kind)
        source = try container.decode(EvidenceSource.self, forKey: .source)
        summaryKey = try container.decode(
            DomainToken.self,
            forKey: .summaryKey
        )
        observedAt = try container.decode(Date.self, forKey: .observedAt)
        freshness = try container.decode(
            EvidenceFreshness.self,
            forKey: .freshness
        )
    }
}

public struct LegacyInvestigationTargetV1: Codable, Sendable, Equatable {
    public let schemaVersion: DomainSchemaVersion
    public let id: InvestigationTargetID
    public let snapshotID: SnapshotID
    public let expectedBytes: ByteCount?
    public let reasonKey: DomainToken
    public let createdAt: Date

    public init(
        id: InvestigationTargetID,
        snapshotID: SnapshotID,
        expectedBytes: ByteCount?,
        reasonKey: DomainToken,
        createdAt: Date
    ) {
        schemaVersion = .v1
        self.id = id
        self.snapshotID = snapshotID
        self.expectedBytes = expectedBytes
        self.reasonKey = reasonKey
        self.createdAt = createdAt
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(
            DomainSchemaVersion.self,
            forKey: .schemaVersion
        )
        try requireDomainSchemaVersion(schemaVersion, expected: .v1)
        self.schemaVersion = schemaVersion
        id = try container.decode(InvestigationTargetID.self, forKey: .id)
        snapshotID = try container.decode(SnapshotID.self, forKey: .snapshotID)
        expectedBytes = try container.decodeIfPresent(
            ByteCount.self,
            forKey: .expectedBytes
        )
        reasonKey = try container.decode(DomainToken.self, forKey: .reasonKey)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case id
        case snapshotID
        case expectedBytes
        case reasonKey
        case createdAt
    }
}
