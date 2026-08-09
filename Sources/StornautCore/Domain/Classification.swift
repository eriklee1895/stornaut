import Foundation

public enum ReclaimDisposition: String, Codable, Sendable, CaseIterable {
    case readyToReclaim
    case reviewRecommended
    case protected
    case unknown
}

public enum RiskLevel: String, Codable, Sendable, CaseIterable {
    case low
    case medium
    case high
    case critical
}

public enum EvidenceConfidence: String, Codable, Sendable, CaseIterable {
    case low
    case medium
    case high
}

public enum ArtifactCategory: String, Codable, Sendable, CaseIterable {
    case packageAndBuildCaches
    case rebuildableProjectArtifacts
    case toolRuntimesAndImages
    case updatesAndTemporaryFiles
    case largeRepositoriesAndHistory
    case unknownLargeConsumers
    case protected
}

public enum RebuildCost: String, Codable, Sendable, CaseIterable {
    case low
    case medium
    case high
    case unknown
}

public struct RecoveryGuidance: Codable, Sendable, Equatable {
    public let methodKey: DomainToken
    public let cost: RebuildCost

    public init(methodKey: DomainToken, cost: RebuildCost) {
        self.methodKey = methodKey
        self.cost = cost
    }
}

public struct Classification: Codable, Sendable, Equatable {
    public let schemaVersion: DomainSchemaVersion
    public let id: ClassificationID
    public let snapshotID: SnapshotID
    public let ruleID: DomainToken?
    public let producer: DomainLabel?
    public let category: ArtifactCategory
    public let disposition: ReclaimDisposition
    public let risk: RiskLevel
    public let confidence: EvidenceConfidence
    public let recovery: RecoveryGuidance?
    public let requiredEvidenceKeys: [DomainToken]
    public let missingEvidenceKeys: [DomainToken]
    public let catalogVersion: DomainToken
    public let classifiedAt: Date

    public init(
        schemaVersion: DomainSchemaVersion = .v1,
        id: ClassificationID,
        snapshotID: SnapshotID,
        ruleID: DomainToken?,
        producer: DomainLabel?,
        category: ArtifactCategory,
        disposition: ReclaimDisposition,
        risk: RiskLevel,
        confidence: EvidenceConfidence,
        recovery: RecoveryGuidance?,
        requiredEvidenceKeys: [DomainToken],
        missingEvidenceKeys: [DomainToken],
        catalogVersion: DomainToken,
        classifiedAt: Date
    ) throws {
        let requiredEvidence = Set(requiredEvidenceKeys)
        let missingEvidence = Set(missingEvidenceKeys)
        guard requiredEvidence.count == requiredEvidenceKeys.count,
              missingEvidence.count == missingEvidenceKeys.count,
              missingEvidence.isSubset(of: requiredEvidence),
              category != .protected || disposition == .protected
        else {
            throw DomainContractError.invalidMeasurement
        }
        if disposition == .readyToReclaim {
            guard ruleID != nil,
                  recovery != nil,
                  missingEvidenceKeys.isEmpty
            else {
                throw DomainContractError.invalidMeasurement
            }
        }
        self.schemaVersion = schemaVersion
        self.id = id
        self.snapshotID = snapshotID
        self.ruleID = ruleID
        self.producer = producer
        self.category = category
        self.disposition = disposition
        self.risk = risk
        self.confidence = confidence
        self.recovery = recovery
        self.requiredEvidenceKeys = requiredEvidenceKeys
        self.missingEvidenceKeys = missingEvidenceKeys
        self.catalogVersion = catalogVersion
        self.classifiedAt = classifiedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(
                DomainSchemaVersion.self,
                forKey: .schemaVersion
            ),
            id: container.decode(ClassificationID.self, forKey: .id),
            snapshotID: container.decode(SnapshotID.self, forKey: .snapshotID),
            ruleID: container.decodeIfPresent(DomainToken.self, forKey: .ruleID),
            producer: container.decodeIfPresent(
                DomainLabel.self,
                forKey: .producer
            ),
            category: container.decode(ArtifactCategory.self, forKey: .category),
            disposition: container.decode(
                ReclaimDisposition.self,
                forKey: .disposition
            ),
            risk: container.decode(RiskLevel.self, forKey: .risk),
            confidence: container.decode(
                EvidenceConfidence.self,
                forKey: .confidence
            ),
            recovery: container.decodeIfPresent(
                RecoveryGuidance.self,
                forKey: .recovery
            ),
            requiredEvidenceKeys: container.decode(
                [DomainToken].self,
                forKey: .requiredEvidenceKeys
            ),
            missingEvidenceKeys: container.decode(
                [DomainToken].self,
                forKey: .missingEvidenceKeys
            ),
            catalogVersion: container.decode(
                DomainToken.self,
                forKey: .catalogVersion
            ),
            classifiedAt: container.decode(Date.self, forKey: .classifiedAt)
        )
    }
}
