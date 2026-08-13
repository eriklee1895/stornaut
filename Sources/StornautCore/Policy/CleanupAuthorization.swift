import Foundation

public enum CleanupAuthorizationError: Error, Sendable, Equatable {
    case policyBlocked
    case confirmationMismatch
    case expired
    case workflowConflict
    case unknownAuthorization
    case alreadyConsumed
    case invalidated
}

public struct ExecutionAuthorization: Sendable {
    fileprivate let nonce: UUID
    fileprivate let planID: CleanupPlanID
    fileprivate let selectionGeneration: UInt64
    fileprivate let orderedItemIDs: [CleanupPlanItemID]
    fileprivate let decisionFingerprint: DomainToken
    fileprivate let admissionDeadline: Date

    fileprivate init(
        nonce: UUID,
        confirmation: CleanupConfirmation,
        admissionDeadline: Date
    ) {
        self.nonce = nonce
        planID = confirmation.planID
        selectionGeneration = confirmation.selectionGeneration
        orderedItemIDs = confirmation.orderedItemIDs
        decisionFingerprint = confirmation.decisionFingerprint
        self.admissionDeadline = admissionDeadline
    }
}

struct ExecutionAuthorizationAdmission: Sendable {
    public let planID: CleanupPlanID
    public let selectionGeneration: UInt64
    public let orderedItemIDs: [CleanupPlanItemID]
    public let decisionFingerprint: DomainToken
    public let admittedAt: Date
    let rootAccess: CleanupPolicyRootAccess

    fileprivate init(
        authorization: ExecutionAuthorization,
        admittedAt: Date,
        rootAccess: CleanupPolicyRootAccess
    ) {
        planID = authorization.planID
        selectionGeneration = authorization.selectionGeneration
        orderedItemIDs = authorization.orderedItemIDs
        decisionFingerprint = authorization.decisionFingerprint
        self.admittedAt = admittedAt
        self.rootAccess = rootAccess
    }
}

actor CleanupAuthorizationController {
    typealias Clock = @Sendable () -> Date

    private enum State {
        case pending(PendingAuthorization)
        case consumed
        case invalidated
    }

    private struct PendingAuthorization {
        let authorization: ExecutionAuthorization
        let confirmation: CleanupConfirmation
        let rootAccess: CleanupPolicyRootAccess
    }

    private var states: [UUID: State] = [:]
    private var authorizationByDecisionFingerprint:
        [DomainToken: UUID] = [:]
    private let now: Clock

    init(now: @escaping Clock = Date.init) {
        self.now = now
    }

    func issue(
        evaluation: CleanupPolicyEvaluation,
        confirmation: CleanupConfirmation,
        collectedContext: CleanupPolicyCollectedContext
    ) throws -> ExecutionAuthorization {
        let issuedAt = now()
        guard issuedAt.timeIntervalSince1970.isFinite,
              let allowed = evaluation.allowed
        else {
            throw CleanupAuthorizationError.policyBlocked
        }
        guard allowed.confirmation == confirmation,
              confirmation.contextFingerprint
                == collectedContext.policyContext.contextFingerprint,
              collectedContext.rootAccess.isAvailable,
              allowed.decisions.count == confirmation.itemCount,
              allowed.decisions.allSatisfy({
                  $0.outcome == .allowed
                      && confirmation.orderedItemIDs.contains($0.itemID)
              })
        else {
            throw CleanupAuthorizationError.confirmationMismatch
        }
        guard issuedAt <= confirmation.admissionNotAfter else {
            throw CleanupAuthorizationError.expired
        }
        if let existingNonce = authorizationByDecisionFingerprint[
            confirmation.decisionFingerprint
        ], let existingState = states[existingNonce] {
            switch existingState {
            case let .pending(pending):
                return pending.authorization
            case .consumed:
                throw CleanupAuthorizationError.alreadyConsumed
            case .invalidated:
                throw CleanupAuthorizationError.invalidated
            }
        }
        let deadline = min(
            confirmation.admissionNotAfter,
            issuedAt.addingTimeInterval(
                CleanupPolicyContext.maximumAge
            )
        )
        let authorization = ExecutionAuthorization(
            nonce: UUID(),
            confirmation: confirmation,
            admissionDeadline: deadline
        )
        states[authorization.nonce] = .pending(
            PendingAuthorization(
                authorization: authorization,
                confirmation: confirmation,
                rootAccess: collectedContext.rootAccess
            )
        )
        authorizationByDecisionFingerprint[
            confirmation.decisionFingerprint
        ] = authorization.nonce
        return authorization
    }

    func admit(
        _ authorization: ExecutionAuthorization,
        confirmation: CleanupConfirmation,
        workflow: CleanupWorkflowAvailabilitySnapshot
    ) throws -> ExecutionAuthorizationAdmission {
        let now = now()
        guard let state = states[authorization.nonce] else {
            throw CleanupAuthorizationError.unknownAuthorization
        }
        switch state {
        case .consumed:
            throw CleanupAuthorizationError.alreadyConsumed
        case .invalidated:
            throw CleanupAuthorizationError.invalidated
        case let .pending(pending):
            states[authorization.nonce] = .consumed
            guard now.timeIntervalSince1970.isFinite else {
                throw CleanupAuthorizationError.expired
            }
            guard pending.authorization.planID
                    == authorization.planID,
                  pending.authorization.selectionGeneration
                    == authorization.selectionGeneration,
                  pending.authorization.orderedItemIDs
                    == authorization.orderedItemIDs,
                  pending.authorization.decisionFingerprint
                    == authorization.decisionFingerprint,
                  pending.authorization.admissionDeadline
                    == authorization.admissionDeadline,
                  pending.confirmation == confirmation
            else {
                throw CleanupAuthorizationError.confirmationMismatch
            }
            guard now <= authorization.admissionDeadline else {
                throw CleanupAuthorizationError.expired
            }
            guard workflow.isAvailable else {
                throw CleanupAuthorizationError.workflowConflict
            }
            return ExecutionAuthorizationAdmission(
                authorization: authorization,
                admittedAt: now,
                rootAccess: pending.rootAccess
            )
        }
    }

    func invalidateAll() {
        for (nonce, state) in states {
            if case .pending = state {
                states[nonce] = .invalidated
            }
        }
    }
}
