import Foundation

public enum CleanupWorkflowCoordinatorError:
    Error,
    Sendable,
    Equatable
{
    case conflict
    case invalidLease
}

public struct CleanupWorkflowLease: Sendable, Equatable {
    fileprivate let id: UUID
    public let conflict: CleanupWorkflowConflict

    fileprivate init(
        id: UUID,
        conflict: CleanupWorkflowConflict
    ) {
        self.id = id
        self.conflict = conflict
    }
}

public actor CleanupWorkflowCoordinator:
    CleanupWorkflowAvailabilityObserving
{
    private var activeLease: CleanupWorkflowLease?
    private var rootLeaseAvailable = true

    public init() {}

    public func acquire(
        _ conflict: CleanupWorkflowConflict
    ) throws -> CleanupWorkflowLease {
        guard activeLease == nil else {
            throw CleanupWorkflowCoordinatorError.conflict
        }
        let lease = CleanupWorkflowLease(
            id: UUID(),
            conflict: conflict
        )
        activeLease = lease
        return lease
    }

    public func release(_ lease: CleanupWorkflowLease) {
        guard activeLease == lease else { return }
        activeLease = nil
    }

    public func setRootLeaseAvailable(_ available: Bool) {
        rootLeaseAvailable = available
    }

    public func snapshot() -> CleanupWorkflowAvailabilitySnapshot {
        CleanupWorkflowAvailabilitySnapshot(
            rootLeaseAvailable: rootLeaseAvailable,
            activeConflicts: Set(activeLease.map { [$0.conflict] } ?? [])
        )
    }

    func snapshot(
        excluding lease: CleanupWorkflowLease
    ) throws -> CleanupWorkflowAvailabilitySnapshot {
        guard activeLease == lease else {
            throw CleanupWorkflowCoordinatorError.invalidLease
        }
        return CleanupWorkflowAvailabilitySnapshot(
            rootLeaseAvailable: rootLeaseAvailable,
            activeConflicts: []
        )
    }
}

public enum CleanupExecutionAvailableAction:
    String,
    Sendable,
    Equatable
{
    case retrySavingAudit
    case inspectRecovery
    case scanAgain
    case refreshAffectedItems
    case cancel
}

public struct CleanupExecutionResult: Sendable, Equatable {
    public let journal: CleanupRunJournal
    public let manifest: CleanupManifest

    public init(
        journal: CleanupRunJournal,
        manifest: CleanupManifest
    ) throws {
        let expectedSummary = try CleanupManifestSummary(
            records: manifest.records
        )
        guard journal.stage == .manifestPending
                || journal.stage == .auditPending
                || journal.stage == .finalized,
              journal.manifestID == manifest.id,
              journal.planID == manifest.planID,
              journal.manifestCreatedAt == manifest.createdAt,
              journal.systemObservation == manifest.systemObservation,
              manifest.summary == expectedSummary,
              journal.entries.count == manifest.records.count,
              zip(journal.entries, manifest.records).allSatisfy({
                  entry, record in
                  entry.actionID == record.actionID
                      && entry.planItemID == record.planItemID
                      && entry.policyDecisionID == record.policyDecisionID
                      && entry.policyDisposition == record.policyDisposition
                      && entry.policyReasonKeys == record.policyReasonKeys
                      && entry.action == record.action
                      && entry.outcome?.result == record.result
                      && entry.outcome?.recovery == record.recovery
                      && entry.outcome?.measures == record.measures
                      && entry.startedAt == record.startedAt
                      && (
                          entry.state == .cancelled
                              ? record.finishedAt == nil
                              : entry.outcome?.finishedAt
                                == record.finishedAt
                      )
                      && entry.outcome?.error == record.error
              })
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.journal = journal
        self.manifest = manifest
    }
}

public enum CleanupExecutionRejection:
    String,
    Sendable,
    Equatable
{
    case authorization
    case workflowConflict
    case planMismatch
    case persistence
    case programmingError
}

public enum CleanupExecutionState: Sendable, Equatable {
    case completed(CleanupExecutionResult)
    case partiallyFailed(CleanupExecutionResult)
    case stopped(CleanupExecutionResult)
    case auditPending(CleanupExecutionResult)
    case recoveryRequired(CleanupExecutionResult)
    case recoveryBlocked(CleanupRunJournal)
    case recoveryCorrupt(Int)
    case stale(CleanupStaleResult, CleanupExecutionResult)
    case rejected(CleanupExecutionRejection)

    public var availableActions: [CleanupExecutionAvailableAction] {
        switch self {
        case .auditPending:
            [.retrySavingAudit]
        case .recoveryRequired:
            [.inspectRecovery, .scanAgain]
        case .recoveryBlocked:
            [.inspectRecovery, .scanAgain]
        case .recoveryCorrupt:
            [.inspectRecovery, .scanAgain]
        case .stale:
            [.refreshAffectedItems, .cancel]
        case .completed, .partiallyFailed, .stopped, .rejected:
            []
        }
    }

    public var isCompleted: Bool {
        guard case .completed = self else {
            return false
        }
        return true
    }
}

struct CleanupExecutionRequest: Sendable {
    let plan: CleanupPlan
    let selection: ReviewSelection
    let evaluation: CleanupPolicyEvaluation
    let confirmation: CleanupConfirmation
    let collectedContext: CleanupPolicyCollectedContext
    let authorization: ExecutionAuthorization
}
