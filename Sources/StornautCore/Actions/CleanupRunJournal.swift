import Foundation

public enum CleanupJournalEntryState: String, Codable, Sendable, CaseIterable {
    case prepared
    case started
    case outcomeRecorded
    case cancelled
}

public enum CleanupRunJournalStage: String, Codable, Sendable, CaseIterable {
    case prepared
    case actionStarted
    case actionOutcomeRecorded
    case manifestPending
    case auditPending
    case finalized
}

public enum CleanupJournalRetentionClass:
    String,
    Codable,
    Sendable,
    CaseIterable
{
    case evidenceLinked
    case audit
}

public struct CleanupJournalOutcome: Codable, Sendable, Equatable {
    public let result: ManifestActionResult
    public let recovery: CleanupRecoveryState
    public let measures: CleanupManifestMeasures
    public let destinationIdentity: FileIdentity?
    public let error: CleanupManifestError?
    public let finishedAt: Date

    public init(
        result: ManifestActionResult,
        recovery: CleanupRecoveryState,
        measures: CleanupManifestMeasures,
        destinationIdentity: FileIdentity?,
        error: CleanupManifestError?,
        finishedAt: Date
    ) throws {
        let valid: Bool
        switch result {
        case .succeeded:
            valid = recovery == .movedToTrash
                && destinationIdentity != nil
                && error == nil
                && measures.processedLogicalBytes
                    == measures.candidateLogicalBytes
                && measures.processedAllocatedBytes
                    == measures.candidateAllocatedBytes
                && measures.movedToTrashLogicalBytes
                    == measures.processedLogicalBytes
                && measures.movedToTrashAllocatedBytes
                    == measures.processedAllocatedBytes
        case .failed:
            valid = recovery == .originalConfirmed
                && destinationIdentity == nil
                && error != nil
                && measures.movedToTrashLogicalBytes == ByteCount(0)
                && measures.movedToTrashAllocatedBytes == ByteCount(0)
        case .partiallyFailed:
            valid = recovery == .movedToTrash
                && destinationIdentity != nil
                && error != nil
        case .cancelled:
            valid = recovery == .notStarted
                && destinationIdentity == nil
                && error == nil
                && measures.processedLogicalBytes == ByteCount(0)
                && measures.processedAllocatedBytes == ByteCount(0)
                && measures.movedToTrashLogicalBytes == ByteCount(0)
                && measures.movedToTrashAllocatedBytes == ByteCount(0)
        case .outcomeUnknown:
            valid = recovery == .outcomeUnknown
                && destinationIdentity == nil
                && error != nil
                && measures.movedToTrashLogicalBytes == ByteCount(0)
                && measures.movedToTrashAllocatedBytes == ByteCount(0)
        }
        guard valid else {
            throw DomainContractError.invalidMeasurement
        }
        self.result = result
        self.recovery = recovery
        self.measures = measures
        self.destinationIdentity = destinationIdentity
        self.error = error
        self.finishedAt = finishedAt
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            result: container.decode(ManifestActionResult.self, forKey: .result),
            recovery: container.decode(
                CleanupRecoveryState.self,
                forKey: .recovery
            ),
            measures: container.decode(
                CleanupManifestMeasures.self,
                forKey: .measures
            ),
            destinationIdentity: container.decodeIfPresent(
                FileIdentity.self,
                forKey: .destinationIdentity
            ),
            error: container.decodeIfPresent(
                CleanupManifestError.self,
                forKey: .error
            ),
            finishedAt: container.decode(Date.self, forKey: .finishedAt)
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case result
        case recovery
        case measures
        case destinationIdentity
        case error
        case finishedAt
    }
}

public struct CleanupRunJournalEntry: Codable, Sendable, Equatable {
    public let actionID: CleanupActionID
    public let planItemID: CleanupPlanItemID
    public let policyDecisionID: PolicyDecisionID
    public let policyDisposition: ReclaimDisposition
    public let policyReasonKeys: [DomainToken]
    public let action: ProposedCleanupAction
    public let expectedIdentity: FileIdentity
    public let actionFingerprint: DomainToken
    public let state: CleanupJournalEntryState
    public let startedAt: Date?
    public let outcome: CleanupJournalOutcome?

    public init(
        actionID: CleanupActionID,
        planItemID: CleanupPlanItemID,
        policyDecisionID: PolicyDecisionID,
        policyDisposition: ReclaimDisposition,
        policyReasonKeys: [DomainToken],
        action: ProposedCleanupAction,
        expectedIdentity: FileIdentity,
        actionFingerprint: DomainToken,
        state: CleanupJournalEntryState,
        startedAt: Date?,
        outcome: CleanupJournalOutcome?
    ) throws {
        let executableDisposition = policyDisposition == .readyToReclaim
            || policyDisposition == .reviewRecommended
        let expectedLogicalBytes = ByteCount(exactly: expectedIdentity.size)
        let expectedAllocatedBytes = ByteCount(
            exactly: expectedIdentity.allocatedBytes
        )
        let valid: Bool
        switch state {
        case .prepared:
            valid = startedAt == nil && outcome == nil
        case .started:
            valid = startedAt != nil && outcome == nil
        case .outcomeRecorded:
            valid = startedAt != nil
                && outcome != nil
                && outcome!.result != .cancelled
                && outcome!.finishedAt >= startedAt!
        case .cancelled:
            valid = startedAt == nil
                && outcome?.result == .cancelled
        }
        guard executableDisposition,
              !policyReasonKeys.isEmpty,
              policyReasonKeys.count <= 32,
              Set(policyReasonKeys).count == policyReasonKeys.count,
              action == .moveToTrash,
              expectedLogicalBytes != nil,
              expectedAllocatedBytes != nil,
              outcome == nil
                || (outcome!.measures.candidateLogicalBytes
                    == expectedLogicalBytes
                    && outcome!.measures.candidateAllocatedBytes
                    == expectedAllocatedBytes),
              valid
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.actionID = actionID
        self.planItemID = planItemID
        self.policyDecisionID = policyDecisionID
        self.policyDisposition = policyDisposition
        self.policyReasonKeys = policyReasonKeys
        self.action = action
        self.expectedIdentity = expectedIdentity
        self.actionFingerprint = actionFingerprint
        self.state = state
        self.startedAt = startedAt
        self.outcome = outcome
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            actionID: container.decode(CleanupActionID.self, forKey: .actionID),
            planItemID: container.decode(
                CleanupPlanItemID.self,
                forKey: .planItemID
            ),
            policyDecisionID: container.decode(
                PolicyDecisionID.self,
                forKey: .policyDecisionID
            ),
            policyDisposition: container.decode(
                ReclaimDisposition.self,
                forKey: .policyDisposition
            ),
            policyReasonKeys: container.decode(
                [DomainToken].self,
                forKey: .policyReasonKeys
            ),
            action: container.decode(
                ProposedCleanupAction.self,
                forKey: .action
            ),
            expectedIdentity: container.decode(
                FileIdentity.self,
                forKey: .expectedIdentity
            ),
            actionFingerprint: container.decode(
                DomainToken.self,
                forKey: .actionFingerprint
            ),
            state: container.decode(
                CleanupJournalEntryState.self,
                forKey: .state
            ),
            startedAt: container.decodeIfPresent(Date.self, forKey: .startedAt),
            outcome: container.decodeIfPresent(
                CleanupJournalOutcome.self,
                forKey: .outcome
            )
        )
    }

    func canTransition(to next: Self) -> Bool {
        guard actionID == next.actionID,
              planItemID == next.planItemID,
              policyDecisionID == next.policyDecisionID,
              policyDisposition == next.policyDisposition,
              policyReasonKeys == next.policyReasonKeys,
              action == next.action,
              expectedIdentity == next.expectedIdentity,
              actionFingerprint == next.actionFingerprint
        else {
            return false
        }
        switch (state, next.state) {
        case (.prepared, .prepared):
            return startedAt == next.startedAt && outcome == next.outcome
        case (.prepared, .started):
            return next.startedAt != nil && next.outcome == nil
        case (.prepared, .cancelled):
            return next.startedAt == nil && next.outcome?.result == .cancelled
        case (.started, .started):
            return startedAt == next.startedAt && outcome == next.outcome
        case (.started, .outcomeRecorded):
            return startedAt == next.startedAt && next.outcome != nil
        case (.outcomeRecorded, .outcomeRecorded),
             (.cancelled, .cancelled):
            return self == next
        default:
            return false
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case actionID
        case planItemID
        case policyDecisionID
        case policyDisposition
        case policyReasonKeys
        case action
        case expectedIdentity
        case actionFingerprint
        case state
        case startedAt
        case outcome
    }
}

public struct CleanupRunJournal: Codable, Sendable, Equatable {
    public let schemaVersion: DomainSchemaVersion
    public let id: CleanupRunID
    public let planID: CleanupPlanID
    public let manifestID: CleanupManifestID
    public let selectionGeneration: UInt64
    public let selectionFingerprint: DomainToken
    public let stage: CleanupRunJournalStage
    public let retentionClass: CleanupJournalRetentionClass
    public let stopAfterCurrentRequested: Bool
    public let entries: [CleanupRunJournalEntry]
    public let createdAt: Date
    public let updatedAt: Date
    public let expiresAt: Date

    public init(
        id: CleanupRunID,
        planID: CleanupPlanID,
        manifestID: CleanupManifestID,
        selectionGeneration: UInt64,
        selectionFingerprint: DomainToken,
        stage: CleanupRunJournalStage,
        retentionClass: CleanupJournalRetentionClass,
        stopAfterCurrentRequested: Bool,
        entries: [CleanupRunJournalEntry],
        createdAt: Date,
        updatedAt: Date,
        expiresAt: Date
    ) throws {
        let maximumLifetime: TimeInterval =
            retentionClass == .evidenceLinked ? 7 * 86_400 : 90 * 86_400
        guard !entries.isEmpty,
              entries.count <= 100,
              Set(entries.map(\.actionID)).count == entries.count,
              Set(entries.map(\.planItemID)).count == entries.count,
              createdAt <= updatedAt,
              updatedAt <= expiresAt,
              expiresAt <= createdAt.addingTimeInterval(maximumLifetime),
              Self.hasValidEntryOrder(entries, stage: stage),
              Self.stageMatchesEntries(
                  stage,
                  retentionClass: retentionClass,
                  entries: entries
              )
        else {
            throw DomainContractError.invalidMeasurement
        }
        schemaVersion = .v2
        self.id = id
        self.planID = planID
        self.manifestID = manifestID
        self.selectionGeneration = selectionGeneration
        self.selectionFingerprint = selectionFingerprint
        self.stage = stage
        self.retentionClass = retentionClass
        self.stopAfterCurrentRequested = stopAfterCurrentRequested
        self.entries = entries
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.expiresAt = expiresAt
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
        try requireDomainSchemaVersion(schemaVersion, expected: .v2)
        try self.init(
            id: container.decode(CleanupRunID.self, forKey: .id),
            planID: container.decode(CleanupPlanID.self, forKey: .planID),
            manifestID: container.decode(
                CleanupManifestID.self,
                forKey: .manifestID
            ),
            selectionGeneration: container.decode(
                UInt64.self,
                forKey: .selectionGeneration
            ),
            selectionFingerprint: container.decode(
                DomainToken.self,
                forKey: .selectionFingerprint
            ),
            stage: container.decode(
                CleanupRunJournalStage.self,
                forKey: .stage
            ),
            retentionClass: container.decode(
                CleanupJournalRetentionClass.self,
                forKey: .retentionClass
            ),
            stopAfterCurrentRequested: container.decode(
                Bool.self,
                forKey: .stopAfterCurrentRequested
            ),
            entries: container.decode(
                [CleanupRunJournalEntry].self,
                forKey: .entries
            ),
            createdAt: container.decode(Date.self, forKey: .createdAt),
            updatedAt: container.decode(Date.self, forKey: .updatedAt),
            expiresAt: container.decode(Date.self, forKey: .expiresAt)
        )
    }

    public func canTransition(to next: Self) -> Bool {
        guard id == next.id,
              planID == next.planID,
              manifestID == next.manifestID,
              selectionGeneration == next.selectionGeneration,
              selectionFingerprint == next.selectionFingerprint,
              createdAt == next.createdAt,
              entries.count == next.entries.count,
              Self.canTransitionStage(stage, to: next.stage),
              stage != next.stage || entries == next.entries,
              (self == next && updatedAt == next.updatedAt)
                || (self != next && updatedAt < next.updatedAt),
              (!stopAfterCurrentRequested || next.stopAfterCurrentRequested),
              retentionClass != .audit || next.retentionClass == .audit,
              expiresAt <= next.expiresAt,
              zip(entries, next.entries).allSatisfy({ current, candidate in
                  current.canTransition(to: candidate)
              })
        else {
            return false
        }
        return true
    }

    private static func canTransitionStage(
        _ current: CleanupRunJournalStage,
        to next: CleanupRunJournalStage
    ) -> Bool {
        if current == next {
            return true
        }
        switch (current, next) {
        case (.prepared, .actionStarted),
             (.prepared, .manifestPending),
             (.actionStarted, .actionOutcomeRecorded),
             (.actionOutcomeRecorded, .actionStarted),
             (.actionOutcomeRecorded, .manifestPending),
             (.manifestPending, .auditPending),
             (.manifestPending, .finalized),
             (.auditPending, .finalized):
            return true
        default:
            return false
        }
    }

    private static func hasValidEntryOrder(
        _ entries: [CleanupRunJournalEntry],
        stage: CleanupRunJournalStage
    ) -> Bool {
        enum PrefixState {
            case outcomes
            case started
            case prepared
            case cancelled
        }
        var prefixState = PrefixState.outcomes
        for entry in entries {
            switch entry.state {
            case .outcomeRecorded:
                guard prefixState == .outcomes else {
                    return false
                }
            case .started:
                guard prefixState == .outcomes else {
                    return false
                }
                prefixState = .started
            case .prepared:
                guard prefixState != .cancelled else {
                    return false
                }
                prefixState = .prepared
            case .cancelled:
                guard stage == .manifestPending
                        || stage == .auditPending
                        || stage == .finalized,
                      prefixState == .outcomes
                        || prefixState == .cancelled
                else {
                    return false
                }
                prefixState = .cancelled
            }
        }
        return true
    }

    private static func stageMatchesEntries(
        _ stage: CleanupRunJournalStage,
        retentionClass: CleanupJournalRetentionClass,
        entries: [CleanupRunJournalEntry]
    ) -> Bool {
        let startedCount = entries.filter { $0.state == .started }.count
        let terminalCount = entries.filter {
            $0.state == .outcomeRecorded || $0.state == .cancelled
        }.count
        switch stage {
        case .prepared:
            return retentionClass == .evidenceLinked
                && entries.allSatisfy { $0.state == .prepared }
        case .actionStarted:
            return retentionClass == .audit && startedCount == 1
        case .actionOutcomeRecorded:
            return retentionClass == .audit
                && startedCount == 0
                && terminalCount > 0
                && entries.first?.state == .outcomeRecorded
        case .manifestPending, .auditPending, .finalized:
            return retentionClass == .audit
                && startedCount == 0
                && terminalCount == entries.count
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case id
        case planID
        case manifestID
        case selectionGeneration
        case selectionFingerprint
        case stage
        case retentionClass
        case stopAfterCurrentRequested
        case entries
        case createdAt
        case updatedAt
        case expiresAt
    }
}
