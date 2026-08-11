import Foundation

public enum CleanupCompatibility: String, Codable, Sendable, Equatable {
    case legacyV1
    case current
}

public enum CleanupSelectionOrigin: String, Codable, Sendable, Equatable {
    case defaultReady
    case explicitUser
}

public enum ProposedCleanupAction: Codable, Sendable, Equatable {
    case moveToTrash
    case registeredAction(id: DomainToken)

    public init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard container.allKeys.count == 1, let key = container.allKeys.first
        else {
            throw DomainContractError.invalidMeasurement
        }
        switch key {
        case .moveToTrash:
            _ = try container.decode(EmptyPayload.self, forKey: key)
            self = .moveToTrash
        case .registeredAction:
            let payload = try container.decode(
                RegisteredActionPayload.self,
                forKey: key
            )
            self = .registeredAction(id: payload.id)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .moveToTrash:
            try container.encode(EmptyPayload(), forKey: .moveToTrash)
        case let .registeredAction(id):
            try container.encode(
                RegisteredActionPayload(id: id),
                forKey: .registeredAction
            )
        }
    }

    private struct EmptyPayload: Codable {
        init() {}

        init(from decoder: Decoder) throws {
            try rejectUnknownCodingKeys(decoder, allowedKeys: [])
        }
    }

    private struct RegisteredActionPayload: Codable {
        let id: DomainToken

        init(id: DomainToken) {
            self.id = id
        }

        init(from decoder: Decoder) throws {
            try rejectUnknownCodingKeys(
                decoder,
                allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
            )
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(DomainToken.self, forKey: .id)
        }

        private enum CodingKeys: String, CodingKey, CaseIterable {
            case id
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case moveToTrash
        case registeredAction
    }
}

public struct CleanupPlanItem: Codable, Sendable, Equatable {
    public let id: CleanupPlanItemID
    public let snapshotID: SnapshotID
    public let classificationID: ClassificationID
    public let ruleID: DomainToken?
    public let executionProfileID: DomainToken?
    public let proposedAction: ProposedCleanupAction
    public let expectedRelativePath: PersistedPath?
    public let expectedIdentity: FileIdentity?
    public let logicalBytes: ByteCount?
    public let allocatedBytes: ByteCount?
    public let evidenceFingerprint: DomainToken?
    public let activityFingerprint: DomainToken?

    public init(
        id: CleanupPlanItemID,
        snapshotID: SnapshotID,
        classificationID: ClassificationID,
        ruleID: DomainToken,
        executionProfileID: DomainToken,
        proposedAction: ProposedCleanupAction,
        expectedRelativePath: PersistedPath,
        expectedIdentity: FileIdentity,
        logicalBytes: ByteCount,
        allocatedBytes: ByteCount,
        evidenceFingerprint: DomainToken,
        activityFingerprint: DomainToken
    ) throws {
        guard proposedAction == .moveToTrash,
              Self.isValidRelativePath(expectedRelativePath),
              !expectedIdentity.isSymbolicLink,
              logicalBytes.value == UInt64(exactly: expectedIdentity.size),
              allocatedBytes.value
                == UInt64(exactly: expectedIdentity.allocatedBytes)
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.id = id
        self.snapshotID = snapshotID
        self.classificationID = classificationID
        self.ruleID = ruleID
        self.executionProfileID = executionProfileID
        self.proposedAction = proposedAction
        self.expectedRelativePath = expectedRelativePath
        self.expectedIdentity = expectedIdentity
        self.logicalBytes = logicalBytes
        self.allocatedBytes = allocatedBytes
        self.evidenceFingerprint = evidenceFingerprint
        self.activityFingerprint = activityFingerprint
    }

    init(
        legacyID id: CleanupPlanItemID,
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
        ruleID = nil
        executionProfileID = nil
        self.proposedAction = proposedAction
        expectedRelativePath = nil
        expectedIdentity = nil
        self.logicalBytes = logicalBytes
        self.allocatedBytes = allocatedBytes
        evidenceFingerprint = nil
        activityFingerprint = nil
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(CleanupPlanItemID.self, forKey: .id)
        let snapshotID = try container.decode(
            SnapshotID.self,
            forKey: .snapshotID
        )
        let classificationID = try container.decode(
            ClassificationID.self,
            forKey: .classificationID
        )
        let proposedAction = try container.decode(
            ProposedCleanupAction.self,
            forKey: .proposedAction
        )
        let logicalBytes = try container.decodeIfPresent(
            ByteCount.self,
            forKey: .logicalBytes
        )
        let allocatedBytes = try container.decodeIfPresent(
            ByteCount.self,
            forKey: .allocatedBytes
        )
        if container.contains(.ruleID)
            || container.contains(.executionProfileID)
            || container.contains(.expectedRelativePath)
            || container.contains(.expectedIdentity)
            || container.contains(.evidenceFingerprint)
            || container.contains(.activityFingerprint)
        {
            try self.init(
                id: id,
                snapshotID: snapshotID,
                classificationID: classificationID,
                ruleID: container.decode(DomainToken.self, forKey: .ruleID),
                executionProfileID: container.decode(
                    DomainToken.self,
                    forKey: .executionProfileID
                ),
                proposedAction: proposedAction,
                expectedRelativePath: container.decode(
                    PersistedPath.self,
                    forKey: .expectedRelativePath
                ),
                expectedIdentity: container.decode(
                    FileIdentity.self,
                    forKey: .expectedIdentity
                ),
                logicalBytes: try Self.requireBytes(logicalBytes),
                allocatedBytes: try Self.requireBytes(allocatedBytes),
                evidenceFingerprint: container.decode(
                    DomainToken.self,
                    forKey: .evidenceFingerprint
                ),
                activityFingerprint: container.decode(
                    DomainToken.self,
                    forKey: .activityFingerprint
                )
            )
        } else {
            try self.init(
                legacyID: id,
                snapshotID: snapshotID,
                classificationID: classificationID,
                proposedAction: proposedAction,
                logicalBytes: logicalBytes,
                allocatedBytes: allocatedBytes
            )
        }
    }

    private static func requireBytes(
        _ value: ByteCount?
    ) throws -> ByteCount {
        guard let value else {
            throw DomainContractError.invalidMeasurement
        }
        return value
    }

    private static func isValidRelativePath(_ path: PersistedPath) -> Bool {
        let rawValue = path.rawValue
        guard !rawValue.hasPrefix("/"),
              rawValue.utf8.count <= 4_096
        else {
            return false
        }
        let components = rawValue.split(
            separator: "/",
            omittingEmptySubsequences: false
        )
        return !components.isEmpty
            && components.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case snapshotID
        case classificationID
        case ruleID
        case executionProfileID
        case proposedAction
        case expectedRelativePath
        case expectedIdentity
        case logicalBytes
        case allocatedBytes
        case evidenceFingerprint
        case activityFingerprint
    }
}

public struct CleanupPlan: Codable, Sendable, Equatable {
    public let schemaVersion: DomainSchemaVersion
    public let compatibility: CleanupCompatibility
    public let id: CleanupPlanID
    public let scanSessionID: ScanSessionID
    public let scanScopeID: ScanScopeID?
    public let primaryRootIdentity: FileIdentity?
    public let catalogVersion: DomainToken?
    public let executionProfileVersion: DomainToken?
    public let planFingerprint: DomainToken?
    public let createdAt: Date
    public let expiresAt: Date
    public let items: [CleanupPlanItem]

    public init(
        id: CleanupPlanID,
        scanSessionID: ScanSessionID,
        scanScopeID: ScanScopeID,
        primaryRootIdentity: FileIdentity,
        catalogVersion: DomainToken,
        executionProfileVersion: DomainToken,
        planFingerprint: DomainToken,
        createdAt: Date,
        expiresAt: Date,
        items: [CleanupPlanItem]
    ) throws {
        guard primaryRootIdentity.isDirectory,
              Self.hasValidCurrentItems(
                  items,
                  primaryRootIdentity: primaryRootIdentity
              ),
              expiresAt >= createdAt
        else {
            throw DomainContractError.invalidMeasurement
        }
        schemaVersion = .v2
        compatibility = .current
        self.id = id
        self.scanSessionID = scanSessionID
        self.scanScopeID = scanScopeID
        self.primaryRootIdentity = primaryRootIdentity
        self.catalogVersion = catalogVersion
        self.executionProfileVersion = executionProfileVersion
        self.planFingerprint = planFingerprint
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.items = items
    }

    private init(
        legacyID id: CleanupPlanID,
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
        schemaVersion = .v2
        compatibility = .legacyV1
        self.id = id
        self.scanSessionID = scanSessionID
        scanScopeID = nil
        primaryRootIdentity = nil
        catalogVersion = nil
        executionProfileVersion = nil
        planFingerprint = nil
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.items = items
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let persistedVersion = try container.decode(
            DomainSchemaVersion.self,
            forKey: .schemaVersion
        )
        let compatibility = try container.decodeIfPresent(
            CleanupCompatibility.self,
            forKey: .compatibility
        ) ?? (persistedVersion == .v1 ? .legacyV1 : .current)
        switch (persistedVersion, compatibility) {
        case (.v1, .legacyV1), (.v2, .legacyV1):
            try self.init(
                legacyID: container.decode(CleanupPlanID.self, forKey: .id),
                scanSessionID: container.decode(
                    ScanSessionID.self,
                    forKey: .scanSessionID
                ),
                createdAt: container.decode(Date.self, forKey: .createdAt),
                expiresAt: container.decode(Date.self, forKey: .expiresAt),
                items: container.decode(
                    [CleanupPlanItem].self,
                    forKey: .items
                )
            )
        case (.v2, .current):
            try self.init(
                id: container.decode(CleanupPlanID.self, forKey: .id),
                scanSessionID: container.decode(
                    ScanSessionID.self,
                    forKey: .scanSessionID
                ),
                scanScopeID: container.decode(
                    ScanScopeID.self,
                    forKey: .scanScopeID
                ),
                primaryRootIdentity: container.decode(
                    FileIdentity.self,
                    forKey: .primaryRootIdentity
                ),
                catalogVersion: container.decode(
                    DomainToken.self,
                    forKey: .catalogVersion
                ),
                executionProfileVersion: container.decode(
                    DomainToken.self,
                    forKey: .executionProfileVersion
                ),
                planFingerprint: container.decode(
                    DomainToken.self,
                    forKey: .planFingerprint
                ),
                createdAt: container.decode(Date.self, forKey: .createdAt),
                expiresAt: container.decode(Date.self, forKey: .expiresAt),
                items: container.decode(
                    [CleanupPlanItem].self,
                    forKey: .items
                )
            )
        case (.v1, .current):
            throw DomainContractError.unsupportedSchemaVersion(
                expected: .v2,
                actual: .v1
            )
        }
    }

    private static func hasValidCurrentItems(
        _ items: [CleanupPlanItem],
        primaryRootIdentity: FileIdentity
    ) -> Bool {
        guard !items.isEmpty,
              items.count <= 100,
              Set(items.map(\.id)).count == items.count,
              Set(items.map(\.snapshotID)).count == items.count,
              Set(items.map(\.classificationID)).count == items.count,
              items.allSatisfy({
                  $0.ruleID != nil
                      && $0.executionProfileID != nil
                      && $0.expectedRelativePath != nil
                      && $0.expectedIdentity != nil
                      && $0.logicalBytes != nil
                      && $0.allocatedBytes != nil
                      && $0.evidenceFingerprint != nil
                      && $0.activityFingerprint != nil
                      && $0.proposedAction == .moveToTrash
                      && $0.expectedIdentity?.device
                        == primaryRootIdentity.device
              })
        else {
            return false
        }
        for firstIndex in items.indices {
            for secondIndex in items.indices where secondIndex > firstIndex {
                guard items[firstIndex].expectedIdentity
                        != items[secondIndex].expectedIdentity,
                      !sameFileObject(
                          items[firstIndex].expectedIdentity!,
                          items[secondIndex].expectedIdentity!
                      ),
                      !pathsOverlap(
                          items[firstIndex].expectedRelativePath!,
                          items[secondIndex].expectedRelativePath!
                      )
                else {
                    return false
                }
            }
        }
        return true
    }

    private static func pathsOverlap(
        _ first: PersistedPath,
        _ second: PersistedPath
    ) -> Bool {
        let firstComponents = first.rawValue.split(separator: "/")
        let secondComponents = second.rawValue.split(separator: "/")
        let prefixCount = min(firstComponents.count, secondComponents.count)
        return Array(firstComponents.prefix(prefixCount))
            == Array(secondComponents.prefix(prefixCount))
    }

    private static func sameFileObject(
        _ first: FileIdentity,
        _ second: FileIdentity
    ) -> Bool {
        first.device == second.device && first.inode == second.inode
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case compatibility
        case id
        case scanSessionID
        case scanScopeID
        case primaryRootIdentity
        case catalogVersion
        case executionProfileVersion
        case planFingerprint
        case createdAt
        case expiresAt
        case items
    }
}

public enum PolicyDecisionOutcome: String, Codable, Sendable, CaseIterable {
    case allowed
    case denied
}

public struct PolicyDecision: Codable, Sendable, Equatable {
    public let schemaVersion: DomainSchemaVersion
    public let compatibility: CleanupCompatibility
    public let id: PolicyDecisionID
    public let planID: CleanupPlanID
    public let itemID: CleanupPlanItemID
    public let outcome: PolicyDecisionOutcome
    public let disposition: ReclaimDisposition
    public let selectionGeneration: UInt64?
    public let selectionOrigin: CleanupSelectionOrigin?
    public let planFingerprint: DomainToken?
    public let decisionFingerprint: DomainToken?
    public let reasonKeys: [DomainToken]
    public let evaluatedAt: Date

    public init(
        id: PolicyDecisionID,
        planID: CleanupPlanID,
        itemID: CleanupPlanItemID,
        outcome: PolicyDecisionOutcome,
        disposition: ReclaimDisposition,
        selectionGeneration: UInt64,
        selectionOrigin: CleanupSelectionOrigin,
        planFingerprint: DomainToken,
        decisionFingerprint: DomainToken,
        reasonKeys: [DomainToken],
        evaluatedAt: Date
    ) throws {
        let executableDisposition = disposition == .readyToReclaim
            || disposition == .reviewRecommended
        guard !reasonKeys.isEmpty,
              reasonKeys.count <= 32,
              Set(reasonKeys).count == reasonKeys.count,
              outcome != .allowed || executableDisposition,
              outcome != .allowed
                || disposition != .reviewRecommended
                || selectionOrigin == .explicitUser
        else {
            throw DomainContractError.invalidMeasurement
        }
        schemaVersion = .v2
        compatibility = .current
        self.id = id
        self.planID = planID
        self.itemID = itemID
        self.outcome = outcome
        self.disposition = disposition
        self.selectionGeneration = selectionGeneration
        self.selectionOrigin = selectionOrigin
        self.planFingerprint = planFingerprint
        self.decisionFingerprint = decisionFingerprint
        self.reasonKeys = reasonKeys
        self.evaluatedAt = evaluatedAt
    }

    private init(
        legacyID id: PolicyDecisionID,
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
        schemaVersion = .v2
        compatibility = .legacyV1
        self.id = id
        self.planID = planID
        self.itemID = itemID
        self.outcome = outcome
        self.disposition = disposition
        selectionGeneration = nil
        selectionOrigin = nil
        planFingerprint = nil
        decisionFingerprint = nil
        self.reasonKeys = reasonKeys
        self.evaluatedAt = evaluatedAt
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let persistedVersion = try container.decode(
            DomainSchemaVersion.self,
            forKey: .schemaVersion
        )
        let compatibility = try container.decodeIfPresent(
            CleanupCompatibility.self,
            forKey: .compatibility
        ) ?? (persistedVersion == .v1 ? .legacyV1 : .current)
        switch (persistedVersion, compatibility) {
        case (.v1, .legacyV1), (.v2, .legacyV1):
            try self.init(
                legacyID: container.decode(
                    PolicyDecisionID.self,
                    forKey: .id
                ),
                planID: container.decode(CleanupPlanID.self, forKey: .planID),
                itemID: container.decode(
                    CleanupPlanItemID.self,
                    forKey: .itemID
                ),
                outcome: container.decode(
                    PolicyDecisionOutcome.self,
                    forKey: .outcome
                ),
                disposition: container.decode(
                    ReclaimDisposition.self,
                    forKey: .disposition
                ),
                reasonKeys: container.decode(
                    [DomainToken].self,
                    forKey: .reasonKeys
                ),
                evaluatedAt: container.decode(
                    Date.self,
                    forKey: .evaluatedAt
                )
            )
        case (.v2, .current):
            try self.init(
                id: container.decode(PolicyDecisionID.self, forKey: .id),
                planID: container.decode(CleanupPlanID.self, forKey: .planID),
                itemID: container.decode(
                    CleanupPlanItemID.self,
                    forKey: .itemID
                ),
                outcome: container.decode(
                    PolicyDecisionOutcome.self,
                    forKey: .outcome
                ),
                disposition: container.decode(
                    ReclaimDisposition.self,
                    forKey: .disposition
                ),
                selectionGeneration: container.decode(
                    UInt64.self,
                    forKey: .selectionGeneration
                ),
                selectionOrigin: container.decode(
                    CleanupSelectionOrigin.self,
                    forKey: .selectionOrigin
                ),
                planFingerprint: container.decode(
                    DomainToken.self,
                    forKey: .planFingerprint
                ),
                decisionFingerprint: container.decode(
                    DomainToken.self,
                    forKey: .decisionFingerprint
                ),
                reasonKeys: container.decode(
                    [DomainToken].self,
                    forKey: .reasonKeys
                ),
                evaluatedAt: container.decode(
                    Date.self,
                    forKey: .evaluatedAt
                )
            )
        case (.v1, .current):
            throw DomainContractError.unsupportedSchemaVersion(
                expected: .v2,
                actual: .v1
            )
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case compatibility
        case id
        case planID
        case itemID
        case outcome
        case disposition
        case selectionGeneration
        case selectionOrigin
        case planFingerprint
        case decisionFingerprint
        case reasonKeys
        case evaluatedAt
    }
}
