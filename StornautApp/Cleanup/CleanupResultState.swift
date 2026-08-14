import Foundation
import StornautCore

enum CleanupResultEvidenceAvailability:
    String,
    Sendable,
    Equatable
{
    case retained
    case expired
}

struct CleanupResultItemFacts: Sendable, Equatable {
    let planItemID: CleanupPlanItemID
    let itemName: String
    let exactOriginalPath: String
    let expectedIdentity: FileIdentity
    let evidenceFingerprint: DomainToken
    let producer: DomainLabel?
    let recoveryDetailKey: DomainToken
    let evidenceLineage: [DomainToken]
}

struct CleanupResultEnrichment: Sendable, Equatable {
    let itemFacts: [CleanupResultItemFacts]
    let evidenceAvailability: CleanupResultEvidenceAvailability
}

enum CleanupResultContractError: Error, Sendable, Equatable {
    case invalidTerminalState
    case invalidEvidenceFacts
}

struct CleanupResultSnapshot: Sendable, Equatable {
    let executionState: CleanupExecutionState
    let result: CleanupExecutionResult
    let manifest: CleanupManifest
    let journal: CleanupRunJournal
    let itemFacts: [CleanupPlanItemID: CleanupResultItemFacts]
    let evidenceAvailability: CleanupResultEvidenceAvailability

    init(
        executionState: CleanupExecutionState,
        itemFacts: [CleanupResultItemFacts],
        evidenceAvailability: CleanupResultEvidenceAvailability
    ) throws {
        guard let result = Self.result(from: executionState) else {
            throw CleanupResultContractError.invalidTerminalState
        }
        let expectedSummary = try CleanupManifestSummary(
            records: result.manifest.records
        )
        guard expectedSummary == result.manifest.summary,
              result.journal.manifestID == result.manifest.id,
              result.journal.planID == result.manifest.planID
        else {
            throw CleanupResultContractError.invalidTerminalState
        }

        let manifestItemIDs = Set(
            result.manifest.records.map(\.planItemID)
        )
        let suppliedItemIDs = itemFacts.map(\.planItemID)
        guard Set(suppliedItemIDs).count == suppliedItemIDs.count,
              suppliedItemIDs.allSatisfy(manifestItemIDs.contains),
              itemFacts.allSatisfy(Self.isValid)
        else {
            throw CleanupResultContractError.invalidEvidenceFacts
        }

        self.executionState = executionState
        self.result = result
        manifest = result.manifest
        journal = result.journal
        self.evidenceAvailability = evidenceAvailability
        self.itemFacts = evidenceAvailability == .retained
            ? Dictionary(
                uniqueKeysWithValues: itemFacts.map {
                    ($0.planItemID, $0)
                }
            )
            : [:]
    }

    private static func result(
        from state: CleanupExecutionState
    ) -> CleanupExecutionResult? {
        switch state {
        case let .completed(result),
             let .partiallyFailed(result),
             let .stopped(result),
             let .auditPending(result),
             let .recoveryRequired(result):
            result
        case .recoveryBlocked, .recoveryCorrupt, .stale, .rejected:
            nil
        }
    }

    private static func isValid(
        _ facts: CleanupResultItemFacts
    ) -> Bool {
        !facts.itemName.isEmpty
            && !facts.exactOriginalPath.isEmpty
            && facts.exactOriginalPath.hasPrefix("/")
            && facts.evidenceLineage.count <= 32
            && Set(facts.evidenceLineage).count
                == facts.evidenceLineage.count
    }
}

extension CleanupExecutionState {
    var cleanupResult: CleanupExecutionResult? {
        switch self {
        case let .completed(result),
             let .partiallyFailed(result),
             let .stopped(result),
             let .auditPending(result),
             let .recoveryRequired(result):
            result
        case .recoveryBlocked, .recoveryCorrupt, .stale, .rejected:
            nil
        }
    }
}

enum CleanupResultPhase: String, Sendable, Equatable {
    case idle
    case presented
    case openingTrash
    case trashUnavailable
    case retryingAudit
    case corrupt
    case unavailable
}

enum CleanupResultState: Sendable, Equatable {
    case idle
    case presented(CleanupResultSnapshot)
    case openingTrash(CleanupResultSnapshot)
    case trashUnavailable(CleanupResultSnapshot)
    case retryingAudit(CleanupResultSnapshot)
    case corrupt(String?)
    case unavailable(DomainToken)

    var phase: CleanupResultPhase {
        switch self {
        case .idle:
            .idle
        case .presented:
            .presented
        case .openingTrash:
            .openingTrash
        case .trashUnavailable:
            .trashUnavailable
        case .retryingAudit:
            .retryingAudit
        case .corrupt:
            .corrupt
        case .unavailable:
            .unavailable
        }
    }

    var snapshot: CleanupResultSnapshot? {
        switch self {
        case let .presented(snapshot),
             let .openingTrash(snapshot),
             let .trashUnavailable(snapshot),
             let .retryingAudit(snapshot):
            snapshot
        case .idle, .corrupt, .unavailable:
            nil
        }
    }
}

struct CleanupResultReducer: Sendable {
    func receivedTerminal(
        _ executionState: CleanupExecutionState,
        itemFacts: [CleanupResultItemFacts],
        evidenceAvailability: CleanupResultEvidenceAvailability,
        state: CleanupResultState
    ) -> CleanupResultState {
        guard state.snapshot == nil,
              state.phase == .idle
        else {
            return state
        }
        do {
            return .presented(
                try CleanupResultSnapshot(
                    executionState: executionState,
                    itemFacts: itemFacts,
                    evidenceAvailability: evidenceAvailability
                )
            )
        } catch {
            return .unavailable(
                DomainToken(
                    rawValue: "cleanup.result.invalid-terminal"
                )!
            )
        }
    }

    func beginOpenTrash(
        state: CleanupResultState
    ) -> CleanupResultState {
        guard case let .presented(snapshot) = state else {
            return state
        }
        return .openingTrash(snapshot)
    }

    func openTrashFinished(
        succeeded: Bool,
        state: CleanupResultState
    ) -> CleanupResultState {
        guard case let .openingTrash(snapshot) = state else {
            return state
        }
        return succeeded
            ? .presented(snapshot)
            : .trashUnavailable(snapshot)
    }

    func dismissTrashFailure(
        state: CleanupResultState
    ) -> CleanupResultState {
        guard case let .trashUnavailable(snapshot) = state else {
            return state
        }
        return .presented(snapshot)
    }

    func beginAuditRetry(
        state: CleanupResultState
    ) -> CleanupResultState {
        guard case let .presented(snapshot) = state,
              snapshot.manifest.summary.unknownCount == 0,
              snapshot.journal.stage == .auditPending
                || snapshot.journal.stage == .manifestPending
        else {
            return state
        }
        return .retryingAudit(snapshot)
    }

    func auditRetryFinished(
        _ executionState: CleanupExecutionState?,
        state: CleanupResultState
    ) -> CleanupResultState {
        guard case let .retryingAudit(snapshot) = state else {
            return state
        }
        guard let executionState else {
            return .presented(snapshot)
        }
        do {
            let replacement = try CleanupResultSnapshot(
                executionState: executionState,
                itemFacts: Array(snapshot.itemFacts.values),
                evidenceAvailability: snapshot.evidenceAvailability
            )
            guard replacement.manifest == snapshot.manifest,
                  snapshot.journal.canTransition(
                      to: replacement.journal
                  )
            else {
                return .presented(snapshot)
            }
            return .presented(replacement)
        } catch {
            return .presented(snapshot)
        }
    }

    func done(state: CleanupResultState) -> CleanupResultState {
        .idle
    }
}
