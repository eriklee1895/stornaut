import Foundation

public enum ManifestActionResult: String, Codable, Sendable, CaseIterable {
    case succeeded
    case failed
    case partiallyFailed
    case cancelled
}

public struct ManifestSystemObservation: Codable, Sendable, Equatable {
    public let source: DomainToken
    public let freeBytesBefore: ByteCount
    public let sampledBeforeAt: Date
    public let freeBytesAfter: ByteCount
    public let sampledAfterAt: Date
    public let freeSpaceDelta: SignedByteDelta
    public let unexplainedDelta: SignedByteDelta?

    public init(
        source: DomainToken,
        freeBytesBefore: ByteCount,
        sampledBeforeAt: Date,
        freeBytesAfter: ByteCount,
        sampledAfterAt: Date,
        freeSpaceDelta: SignedByteDelta,
        unexplainedDelta: SignedByteDelta?
    ) throws {
        let expectedDelta = Int64(freeBytesAfter.value)
            - Int64(freeBytesBefore.value)
        guard sampledAfterAt >= sampledBeforeAt,
              freeSpaceDelta.value == expectedDelta
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.source = source
        self.freeBytesBefore = freeBytesBefore
        self.sampledBeforeAt = sampledBeforeAt
        self.freeBytesAfter = freeBytesAfter
        self.sampledAfterAt = sampledAfterAt
        self.freeSpaceDelta = freeSpaceDelta
        self.unexplainedDelta = unexplainedDelta
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            source: container.decode(DomainToken.self, forKey: .source),
            freeBytesBefore: container.decode(
                ByteCount.self,
                forKey: .freeBytesBefore
            ),
            sampledBeforeAt: container.decode(
                Date.self,
                forKey: .sampledBeforeAt
            ),
            freeBytesAfter: container.decode(
                ByteCount.self,
                forKey: .freeBytesAfter
            ),
            sampledAfterAt: container.decode(
                Date.self,
                forKey: .sampledAfterAt
            ),
            freeSpaceDelta: container.decode(
                SignedByteDelta.self,
                forKey: .freeSpaceDelta
            ),
            unexplainedDelta: container.decodeIfPresent(
                SignedByteDelta.self,
                forKey: .unexplainedDelta
            )
        )
    }
}

public struct CleanupManifestRecord: Codable, Sendable, Equatable {
    public let actionID: CleanupActionID
    public let planItemID: CleanupPlanItemID
    public let policyDisposition: ReclaimDisposition
    public let action: ProposedCleanupAction
    public let result: ManifestActionResult
    public let logicalBytesBefore: ByteCount
    public let allocatedBytesBefore: ByteCount
    public let logicalBytesAfter: ByteCount?
    public let allocatedBytesAfter: ByteCount?
    public let logicalBytesProcessed: ByteCount
    public let allocatedBytesProcessed: ByteCount
    public let startedAt: Date
    public let finishedAt: Date
    public let errorCode: DomainToken?

    public init(
        actionID: CleanupActionID,
        planItemID: CleanupPlanItemID,
        policyDisposition: ReclaimDisposition,
        action: ProposedCleanupAction,
        result: ManifestActionResult,
        logicalBytesBefore: ByteCount,
        allocatedBytesBefore: ByteCount,
        logicalBytesAfter: ByteCount?,
        allocatedBytesAfter: ByteCount?,
        logicalBytesProcessed: ByteCount,
        allocatedBytesProcessed: ByteCount,
        startedAt: Date,
        finishedAt: Date,
        errorCode: DomainToken?
    ) throws {
        let executableDisposition =
            policyDisposition == .readyToReclaim
                || policyDisposition == .reviewRecommended
        let errorMatchesResult: Bool
        switch result {
        case .succeeded:
            errorMatchesResult = errorCode == nil
        case .failed, .partiallyFailed:
            errorMatchesResult = errorCode != nil
        case .cancelled:
            errorMatchesResult = true
        }
        guard finishedAt >= startedAt,
              executableDisposition,
              errorMatchesResult,
              (logicalBytesAfter == nil) == (allocatedBytesAfter == nil),
              result != .succeeded || logicalBytesAfter != nil
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.actionID = actionID
        self.planItemID = planItemID
        self.policyDisposition = policyDisposition
        self.action = action
        self.result = result
        self.logicalBytesBefore = logicalBytesBefore
        self.allocatedBytesBefore = allocatedBytesBefore
        self.logicalBytesAfter = logicalBytesAfter
        self.allocatedBytesAfter = allocatedBytesAfter
        self.logicalBytesProcessed = logicalBytesProcessed
        self.allocatedBytesProcessed = allocatedBytesProcessed
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.errorCode = errorCode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            actionID: container.decode(CleanupActionID.self, forKey: .actionID),
            planItemID: container.decode(
                CleanupPlanItemID.self,
                forKey: .planItemID
            ),
            policyDisposition: container.decode(
                ReclaimDisposition.self,
                forKey: .policyDisposition
            ),
            action: container.decode(
                ProposedCleanupAction.self,
                forKey: .action
            ),
            result: container.decode(
                ManifestActionResult.self,
                forKey: .result
            ),
            logicalBytesBefore: container.decode(
                ByteCount.self,
                forKey: .logicalBytesBefore
            ),
            allocatedBytesBefore: container.decode(
                ByteCount.self,
                forKey: .allocatedBytesBefore
            ),
            logicalBytesAfter: container.decodeIfPresent(
                ByteCount.self,
                forKey: .logicalBytesAfter
            ),
            allocatedBytesAfter: container.decodeIfPresent(
                ByteCount.self,
                forKey: .allocatedBytesAfter
            ),
            logicalBytesProcessed: container.decode(
                ByteCount.self,
                forKey: .logicalBytesProcessed
            ),
            allocatedBytesProcessed: container.decode(
                ByteCount.self,
                forKey: .allocatedBytesProcessed
            ),
            startedAt: container.decode(Date.self, forKey: .startedAt),
            finishedAt: container.decode(Date.self, forKey: .finishedAt),
            errorCode: container.decodeIfPresent(
                DomainToken.self,
                forKey: .errorCode
            )
        )
    }
}

public struct CleanupManifest: Codable, Sendable, Equatable {
    public let schemaVersion: DomainSchemaVersion
    public let id: CleanupManifestID
    public let planID: CleanupPlanID
    public let createdAt: Date
    public let expiresAt: Date
    public let records: [CleanupManifestRecord]
    public let systemObservation: ManifestSystemObservation?

    public init(
        schemaVersion: DomainSchemaVersion = .v1,
        id: CleanupManifestID,
        planID: CleanupPlanID,
        createdAt: Date,
        expiresAt: Date,
        records: [CleanupManifestRecord],
        systemObservation: ManifestSystemObservation?
    ) throws {
        guard expiresAt >= createdAt,
              Set(records.map(\.actionID)).count == records.count
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.schemaVersion = schemaVersion
        self.id = id
        self.planID = planID
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.records = records
        self.systemObservation = systemObservation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(
                DomainSchemaVersion.self,
                forKey: .schemaVersion
            ),
            id: container.decode(CleanupManifestID.self, forKey: .id),
            planID: container.decode(CleanupPlanID.self, forKey: .planID),
            createdAt: container.decode(Date.self, forKey: .createdAt),
            expiresAt: container.decode(Date.self, forKey: .expiresAt),
            records: container.decode(
                [CleanupManifestRecord].self,
                forKey: .records
            ),
            systemObservation: container.decodeIfPresent(
                ManifestSystemObservation.self,
                forKey: .systemObservation
            )
        )
    }
}
