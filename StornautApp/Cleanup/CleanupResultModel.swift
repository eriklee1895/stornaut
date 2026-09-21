import Foundation
import StornautCore

enum CleanupResultOutcome: String, Sendable, Equatable {
    case completed
    case completedWithIssues
    case failed
    case stopped
    case auditPending
    case outcomeUnknown
}

enum CleanupManifestPersistence: String, Sendable, Equatable {
    case saved
    case auditPending
}

enum CleanupResultAction: String, Sendable, Equatable {
    case openTrash
    case viewManifest
    case retrySavingAudit
    case retry
    case done
}

enum CleanupRecoveryPresentation: String, Sendable, Equatable {
    case recoverableFromTrash
    case originalRemains
    case notStarted
    case outcomeUnknown
}

enum CleanupSystemObservationPresentation:
    String,
    Sendable,
    Equatable
{
    case measured
    case unavailable
}

struct CleanupResultRow: Identifiable, Sendable, Equatable {
    let actionID: CleanupActionID
    let planItemID: CleanupPlanItemID
    let itemName: String?
    let exactOriginalPath: String?
    let producer: DomainLabel?
    let action: ProposedCleanupAction
    let result: ManifestActionResult
    let recovery: CleanupRecoveryState
    let recoveryPresentation: CleanupRecoveryPresentation
    let measures: CleanupManifestMeasures
    let policyDisposition: ReclaimDisposition
    let policyReasonKeys: [DomainToken]
    let startedAt: Date?
    let finishedAt: Date?
    let error: CleanupManifestError?
    let evidenceLineage: [DomainToken]
    let recoveryDetailKey: DomainToken?

    var id: CleanupActionID { actionID }
}

struct CleanupManifestDetailEntry:
    Identifiable,
    Sendable,
    Equatable
{
    let actionID: CleanupActionID
    let planItemID: CleanupPlanItemID
    let itemName: String?
    let exactOriginalPath: String?
    let action: ProposedCleanupAction
    let result: ManifestActionResult
    let recovery: CleanupRecoveryState
    let policyDisposition: ReclaimDisposition
    let policyReasonKeys: [DomainToken]
    let startedAt: Date?
    let finishedAt: Date?
    let error: CleanupManifestError?
    let measures: CleanupManifestMeasures
    let evidenceLineage: [DomainToken]
    let recoveryDetailKey: DomainToken?

    var id: CleanupActionID { actionID }
}

struct CleanupManifestDetailModel: Sendable, Equatable {
    let manifestID: CleanupManifestID
    let planID: CleanupPlanID
    let createdAt: Date
    let expiresAt: Date
    let persistence: CleanupManifestPersistence
    let entries: [CleanupManifestDetailEntry]
    let systemObservation: ManifestSystemObservation?
    let evidenceAvailability: CleanupResultEvidenceAvailability

    let hasRawJSON = false
    let hasExecutionAction = false
}

struct CleanupResultModel: Sendable, Equatable {
    let phase: CleanupResultPhase
    let outcome: CleanupResultOutcome?
    let manifestPersistence: CleanupManifestPersistence?
    let summary: CleanupManifestSummary?
    let movedToTrashBytes: ByteCount
    let movedToTrashItemCount: Int
    let permanentlyReleasedBytes: ByteCount
    let rows: [CleanupResultRow]
    let systemObservation: ManifestSystemObservation?
    let systemObservationPresentation:
        CleanupSystemObservationPresentation
    let evidenceAvailability: CleanupResultEvidenceAvailability
    let availableActions: [CleanupResultAction]
    let manifestDetail: CleanupManifestDetailModel?
    let reasonKey: DomainToken?
    let corruptRecordID: String?

    let hasSyntheticReclaimedTotal = false

    init(state: CleanupResultState) {
        phase = state.phase
        guard let snapshot = state.snapshot else {
            outcome = nil
            manifestPersistence = nil
            summary = nil
            movedToTrashBytes = ByteCount(0)!
            movedToTrashItemCount = 0
            permanentlyReleasedBytes = ByteCount(0)!
            rows = []
            systemObservation = nil
            systemObservationPresentation = .unavailable
            evidenceAvailability = .expired
            availableActions = []
            manifestDetail = nil
            if case let .unavailable(reason) = state {
                reasonKey = reason
            } else {
                reasonKey = nil
            }
            if case let .corrupt(identifier) = state {
                corruptRecordID = identifier
            } else {
                corruptRecordID = nil
            }
            return
        }

        let facts = snapshot.itemFacts
        let projectedRows = snapshot.manifest.records.map { record in
            let itemFacts = facts[record.planItemID]
            return CleanupResultRow(
                actionID: record.actionID,
                planItemID: record.planItemID,
                itemName: itemFacts?.itemName,
                exactOriginalPath: itemFacts?.exactOriginalPath,
                producer: itemFacts?.producer,
                action: record.action,
                result: record.result,
                recovery: record.recovery,
                recoveryPresentation: Self.recoveryPresentation(
                    record.recovery
                ),
                measures: record.measures,
                policyDisposition: record.policyDisposition,
                policyReasonKeys: record.policyReasonKeys,
                startedAt: record.startedAt,
                finishedAt: record.finishedAt,
                error: record.error,
                evidenceLineage: itemFacts?.evidenceLineage ?? [],
                recoveryDetailKey: itemFacts?.recoveryDetailKey
            )
        }

        outcome = Self.outcome(for: snapshot)
        manifestPersistence = Self.persistence(for: snapshot)
        let manifestSummary = snapshot.manifest.summary
        summary = manifestSummary
        movedToTrashBytes = manifestSummary.movedToTrashAllocatedBytes
        movedToTrashItemCount = projectedRows.filter {
            $0.recovery == .movedToTrash
        }.count
        permanentlyReleasedBytes =
            manifestSummary.permanentlyReleasedAllocatedBytes
        rows = projectedRows
        systemObservation = snapshot.manifest.systemObservation
        systemObservationPresentation =
            systemObservation == nil ? .unavailable : .measured
        evidenceAvailability = snapshot.evidenceAvailability
        availableActions = Self.actions(
            outcome: outcome!,
            persistence: manifestPersistence!,
            movedToTrashItemCount: movedToTrashItemCount
        )
        manifestDetail = CleanupManifestDetailModel(
            manifestID: snapshot.manifest.id,
            planID: snapshot.manifest.planID,
            createdAt: snapshot.manifest.createdAt,
            expiresAt: snapshot.manifest.expiresAt,
            persistence: manifestPersistence!,
            entries: projectedRows.map {
                CleanupManifestDetailEntry(
                    actionID: $0.actionID,
                    planItemID: $0.planItemID,
                    itemName: $0.itemName,
                    exactOriginalPath: $0.exactOriginalPath,
                    action: $0.action,
                    result: $0.result,
                    recovery: $0.recovery,
                    policyDisposition: $0.policyDisposition,
                    policyReasonKeys: $0.policyReasonKeys,
                    startedAt: $0.startedAt,
                    finishedAt: $0.finishedAt,
                    error: $0.error,
                    measures: $0.measures,
                    evidenceLineage: $0.evidenceLineage,
                    recoveryDetailKey: $0.recoveryDetailKey
                )
            },
            systemObservation: snapshot.manifest.systemObservation,
            evidenceAvailability: snapshot.evidenceAvailability
        )
        reasonKey = nil
        corruptRecordID = nil
    }

    private static func persistence(
        for snapshot: CleanupResultSnapshot
    ) -> CleanupManifestPersistence {
        switch snapshot.journal.stage {
        case .auditPending, .manifestPending:
            .auditPending
        case .finalized:
            .saved
        case .prepared, .actionStarted, .actionOutcomeRecorded:
            .auditPending
        }
    }

    private static func outcome(
        for snapshot: CleanupResultSnapshot
    ) -> CleanupResultOutcome {
        let summary = snapshot.manifest.summary
        if summary.unknownCount > 0 {
            return .outcomeUnknown
        }
        if persistence(for: snapshot) == .auditPending {
            return .auditPending
        }
        if case .stopped = snapshot.executionState {
            return .stopped
        }
        if summary.failedCount > 0 {
            return summary.succeededCount > 0
                    || summary.movedToTrashAllocatedBytes.value > 0
                ? .completedWithIssues
                : .failed
        }
        if summary.cancelledCount > 0 {
            return .stopped
        }
        return .completed
    }

    private static func recoveryPresentation(
        _ recovery: CleanupRecoveryState
    ) -> CleanupRecoveryPresentation {
        switch recovery {
        case .movedToTrash:
            .recoverableFromTrash
        case .originalConfirmed:
            .originalRemains
        case .notStarted:
            .notStarted
        case .outcomeUnknown:
            .outcomeUnknown
        }
    }

    private static func actions(
        outcome: CleanupResultOutcome,
        persistence: CleanupManifestPersistence,
        movedToTrashItemCount: Int
    ) -> [CleanupResultAction] {
        var actions: [CleanupResultAction] = []
        if movedToTrashItemCount > 0, outcome != .outcomeUnknown {
            actions.append(.openTrash)
        }
        actions.append(.viewManifest)
        if persistence == .auditPending, outcome != .outcomeUnknown {
            actions.append(.retrySavingAudit)
        }
        actions.append(.done)
        return actions
    }
}

enum CleanupResultFormatting {
    static func signedBytes(
        _ delta: SignedByteDelta,
        formatter: StornautByteFormatter = StornautByteFormatter()
    ) -> String {
        let prefix = delta.value > 0
            ? "+"
            : delta.value < 0 ? "-" : ""
        return prefix
            + formatter.string(
                for: ByteCount(UInt64(delta.value.magnitude))
            )
    }
}
