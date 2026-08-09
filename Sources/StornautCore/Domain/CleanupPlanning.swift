import Foundation

public enum ProposedCleanupAction: Codable, Sendable, Equatable {
    case moveToTrash
    case registeredAction(id: DomainToken)
}

public struct CleanupPlanItem: Codable, Sendable, Equatable {
    public let id: CleanupPlanItemID
    public let snapshotID: SnapshotID
    public let classificationID: ClassificationID
    public let proposedAction: ProposedCleanupAction
    public let logicalBytes: ByteCount?
    public let allocatedBytes: ByteCount?

    public init(
        id: CleanupPlanItemID,
        snapshotID: SnapshotID,
        classificationID: ClassificationID,
        proposedAction: ProposedCleanupAction,
        logicalBytes: ByteCount?,
        allocatedBytes: ByteCount?
    ) throws {
        guard (logicalBytes == nil) == (allocatedBytes == nil) else {
            throw DomainContractError.invalidMeasurement
        }
        self.id = id
        self.snapshotID = snapshotID
        self.classificationID = classificationID
        self.proposedAction = proposedAction
        self.logicalBytes = logicalBytes
        self.allocatedBytes = allocatedBytes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(CleanupPlanItemID.self, forKey: .id),
            snapshotID: container.decode(SnapshotID.self, forKey: .snapshotID),
            classificationID: container.decode(
                ClassificationID.self,
                forKey: .classificationID
            ),
            proposedAction: container.decode(
                ProposedCleanupAction.self,
                forKey: .proposedAction
            ),
            logicalBytes: container.decodeIfPresent(
                ByteCount.self,
                forKey: .logicalBytes
            ),
            allocatedBytes: container.decodeIfPresent(
                ByteCount.self,
                forKey: .allocatedBytes
            )
        )
    }
}

public struct CleanupPlan: Codable, Sendable, Equatable {
    public let schemaVersion: DomainSchemaVersion
    public let id: CleanupPlanID
    public let scanSessionID: ScanSessionID
    public let createdAt: Date
    public let expiresAt: Date
    public let items: [CleanupPlanItem]

    public init(
        schemaVersion: DomainSchemaVersion = .v1,
        id: CleanupPlanID,
        scanSessionID: ScanSessionID,
        createdAt: Date,
        expiresAt: Date,
        items: [CleanupPlanItem]
    ) throws {
        guard expiresAt >= createdAt,
              Set(items.map(\.id)).count == items.count
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.schemaVersion = schemaVersion
        self.id = id
        self.scanSessionID = scanSessionID
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.items = items
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(
                DomainSchemaVersion.self,
                forKey: .schemaVersion
            ),
            id: container.decode(CleanupPlanID.self, forKey: .id),
            scanSessionID: container.decode(
                ScanSessionID.self,
                forKey: .scanSessionID
            ),
            createdAt: container.decode(Date.self, forKey: .createdAt),
            expiresAt: container.decode(Date.self, forKey: .expiresAt),
            items: container.decode([CleanupPlanItem].self, forKey: .items)
        )
    }
}

public enum PolicyDecisionOutcome: String, Codable, Sendable, CaseIterable {
    case allowed
    case denied
}

public struct PolicyDecision: Codable, Sendable, Equatable {
    public let schemaVersion: DomainSchemaVersion
    public let id: PolicyDecisionID
    public let planID: CleanupPlanID
    public let itemID: CleanupPlanItemID
    public let outcome: PolicyDecisionOutcome
    public let disposition: ReclaimDisposition
    public let reasonKeys: [DomainToken]
    public let evaluatedAt: Date

    public init(
        schemaVersion: DomainSchemaVersion = .v1,
        id: PolicyDecisionID,
        planID: CleanupPlanID,
        itemID: CleanupPlanItemID,
        outcome: PolicyDecisionOutcome,
        disposition: ReclaimDisposition,
        reasonKeys: [DomainToken],
        evaluatedAt: Date
    ) throws {
        let executableDisposition = disposition == .readyToReclaim
            || disposition == .reviewRecommended
        guard !reasonKeys.isEmpty,
              outcome != .allowed || executableDisposition
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.schemaVersion = schemaVersion
        self.id = id
        self.planID = planID
        self.itemID = itemID
        self.outcome = outcome
        self.disposition = disposition
        self.reasonKeys = reasonKeys
        self.evaluatedAt = evaluatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(
                DomainSchemaVersion.self,
                forKey: .schemaVersion
            ),
            id: container.decode(PolicyDecisionID.self, forKey: .id),
            planID: container.decode(CleanupPlanID.self, forKey: .planID),
            itemID: container.decode(CleanupPlanItemID.self, forKey: .itemID),
            outcome: container.decode(
                PolicyDecisionOutcome.self,
                forKey: .outcome
            ),
            disposition: container.decode(
                ReclaimDisposition.self,
                forKey: .disposition
            ),
            reasonKeys: container.decode([DomainToken].self, forKey: .reasonKeys),
            evaluatedAt: container.decode(Date.self, forKey: .evaluatedAt)
        )
    }
}
