import Foundation

package enum LifecycleMachineRetirementDeadlineValueError:
    Error,
    Sendable,
    Equatable
{
    case invalidValue
}

package struct LifecycleMachineRetirementDeadlineDigest: Sendable, Equatable {
    package let rawBytes: Data

    package init(rawBytes: Data) throws {
        guard rawBytes.count == 32 else {
            throw LifecycleMachineRetirementDeadlineValueError.invalidValue
        }
        self.rawBytes = rawBytes
    }
}

package struct LifecycleMachineRetirementDeadlineObservation:
    Sendable,
    Equatable
{
    package let monotonicNanoseconds: UInt64
    package let wallUTCMicroseconds: Int64

    package init(
        monotonicNanoseconds: UInt64,
        wallUTCMicroseconds: Int64
    ) throws {
        guard monotonicNanoseconds > 0, wallUTCMicroseconds > 0 else {
            throw LifecycleMachineRetirementDeadlineValueError.invalidValue
        }
        self.monotonicNanoseconds = monotonicNanoseconds
        self.wallUTCMicroseconds = wallUTCMicroseconds
    }
}

package struct LifecycleMachineRetirementDeadlineReservation:
    Sendable,
    Equatable
{
    package let reservationID: UUID
    package let handleValidBeforeUTCMicroseconds: Int64
    package let observation: LifecycleMachineRetirementDeadlineObservation

    package init(
        reservationID: UUID,
        handleValidBeforeUTCMicroseconds: Int64,
        observation: LifecycleMachineRetirementDeadlineObservation
    ) throws {
        guard
            !reservationID.lifecycleDeadlineIsZero,
            handleValidBeforeUTCMicroseconds > 0
        else {
            throw LifecycleMachineRetirementDeadlineValueError.invalidValue
        }
        self.reservationID = reservationID
        self.handleValidBeforeUTCMicroseconds =
            handleValidBeforeUTCMicroseconds
        self.observation = observation
    }
}

package struct LifecycleMachineRetirementDeadlineClaim: Sendable, Equatable {
    package let reservationID: UUID
    package let requestBindingSHA256:
        LifecycleMachineRetirementDeadlineDigest
    package let helperIdentitySHA256:
        LifecycleMachineRetirementDeadlineDigest
    package let claimChallenge: UUID
    package let connectionEpoch: UUID
    package let requestIssuedAtUTCMicroseconds: Int64
    package let requestValidBeforeUTCMicroseconds: Int64
    package let epochDeadlineNanoseconds: UInt64
    package let observation: LifecycleMachineRetirementDeadlineObservation

    package init(
        reservationID: UUID,
        requestBindingSHA256: LifecycleMachineRetirementDeadlineDigest,
        helperIdentitySHA256: LifecycleMachineRetirementDeadlineDigest,
        claimChallenge: UUID,
        connectionEpoch: UUID,
        requestIssuedAtUTCMicroseconds: Int64,
        requestValidBeforeUTCMicroseconds: Int64,
        epochDeadlineNanoseconds: UInt64,
        observation: LifecycleMachineRetirementDeadlineObservation
    ) throws {
        guard
            !reservationID.lifecycleDeadlineIsZero,
            !claimChallenge.lifecycleDeadlineIsZero,
            !connectionEpoch.lifecycleDeadlineIsZero,
            requestIssuedAtUTCMicroseconds > 0,
            requestValidBeforeUTCMicroseconds > 0,
            epochDeadlineNanoseconds > 0
        else {
            throw LifecycleMachineRetirementDeadlineValueError.invalidValue
        }
        self.reservationID = reservationID
        self.requestBindingSHA256 = requestBindingSHA256
        self.helperIdentitySHA256 = helperIdentitySHA256
        self.claimChallenge = claimChallenge
        self.connectionEpoch = connectionEpoch
        self.requestIssuedAtUTCMicroseconds =
            requestIssuedAtUTCMicroseconds
        self.requestValidBeforeUTCMicroseconds =
            requestValidBeforeUTCMicroseconds
        self.epochDeadlineNanoseconds = epochDeadlineNanoseconds
        self.observation = observation
    }
}

package struct LifecycleMachineRetirementDeadlineRelease: Sendable, Equatable {
    package let reservationID: UUID
    package let requestBindingSHA256:
        LifecycleMachineRetirementDeadlineDigest
    package let helperIdentitySHA256:
        LifecycleMachineRetirementDeadlineDigest
    package let connectionEpoch: UUID
    package let releaseChallenge: UUID
    package let releaseDeadlineNanoseconds: UInt64
    package let observation: LifecycleMachineRetirementDeadlineObservation

    package init(
        reservationID: UUID,
        requestBindingSHA256: LifecycleMachineRetirementDeadlineDigest,
        helperIdentitySHA256: LifecycleMachineRetirementDeadlineDigest,
        connectionEpoch: UUID,
        releaseChallenge: UUID,
        releaseDeadlineNanoseconds: UInt64,
        observation: LifecycleMachineRetirementDeadlineObservation
    ) throws {
        guard
            !reservationID.lifecycleDeadlineIsZero,
            !connectionEpoch.lifecycleDeadlineIsZero,
            !releaseChallenge.lifecycleDeadlineIsZero,
            releaseDeadlineNanoseconds > 0
        else {
            throw LifecycleMachineRetirementDeadlineValueError.invalidValue
        }
        self.reservationID = reservationID
        self.requestBindingSHA256 = requestBindingSHA256
        self.helperIdentitySHA256 = helperIdentitySHA256
        self.connectionEpoch = connectionEpoch
        self.releaseChallenge = releaseChallenge
        self.releaseDeadlineNanoseconds = releaseDeadlineNanoseconds
        self.observation = observation
    }
}

package enum LifecycleMachineRetirementDeadlineKind:
    Sendable,
    Equatable,
    Hashable
{
    case claim
    case release
    case postReplyExit
}

package struct LifecycleMachineRetirementDeadlineTicket:
    Sendable,
    Equatable,
    Hashable
{
    package let kind: LifecycleMachineRetirementDeadlineKind
    package let generation: UInt64
    package let reservationID: UUID
    package let deadlineNanoseconds: UInt64
}

package enum LifecycleMachineRetirementDeadlineTerminalReason:
    Sendable,
    Equatable
{
    case claimDeadlineExpired
    case releaseDeadlineExpired
    case postReplyExitDue
    case cancelled
    case connectionInvalidated
    case bindingMismatch
    case duplicateOrReplay
    case invalidTimeObservation
    case arithmeticOverflow
    case deadlineArmFailure
    case schedulerFiredEarly
    case replyDispatchFailed
    case postReplyDeadlineExpiredBeforeDispatch
}

package enum LifecycleMachineRetirementDeadlinePhase: Sendable, Equatable {
    case empty
    case claimDeadlinePendingArm
    case awaitingClaim
    case releaseDeadlinePendingArm
    case claimResponsePendingCommit
    case claimedAwaitingRelease
    case releaseResponsePendingCommit
    case releasedAwaitingReplyDispatch
    case postReplyExitPendingArm
    case releasedExitScheduled
    case terminal(LifecycleMachineRetirementDeadlineTerminalReason)
}

package enum LifecycleMachineRetirementDeadlineDisposition: Sendable, Equatable {
    case applied
    case stale
    case terminal(LifecycleMachineRetirementDeadlineTerminalReason)
}

package enum LifecycleMachineRetirementDeadlineEffect: Sendable, Equatable {
    case schedule(LifecycleMachineRetirementDeadlineTicket)
    case cancel(LifecycleMachineRetirementDeadlineTicket)
}

package struct LifecycleMachineRetirementDeadlineTransition: Sendable, Equatable {
    package let disposition: LifecycleMachineRetirementDeadlineDisposition
    package let phase: LifecycleMachineRetirementDeadlinePhase
    package let effects: [LifecycleMachineRetirementDeadlineEffect]
    package let releaseDeadlineNanoseconds: UInt64?
    package let postReplyExitDeadlineNanoseconds: UInt64?
}

package final class LifecycleMachineRetirementEscrowDeadlineState:
    @unchecked Sendable
{
    package static let maximumClaimRequestWindowMicroseconds: Int64 =
        15_000_000
    package static let maximumReleaseWindowNanoseconds: UInt64 =
        5_000_000_000
    package static let maximumPostReplyExitWindowNanoseconds: UInt64 =
        5_000_000_000

    private struct ReservationContext: Sendable, Equatable {
        let reservationID: UUID
        let handleValidBeforeUTCMicroseconds: Int64
        let retainedHandleMonotonicCap: UInt64
        var lastObservation: LifecycleMachineRetirementDeadlineObservation
    }

    private struct ClaimContext: Sendable, Equatable {
        var reservation: ReservationContext
        let requestBindingSHA256: LifecycleMachineRetirementDeadlineDigest
        let helperIdentitySHA256: LifecycleMachineRetirementDeadlineDigest
        let claimChallenge: UUID
        let connectionEpoch: UUID
        let epochDeadlineNanoseconds: UInt64
        let releaseDeadlineNanoseconds: UInt64
    }

    private struct ReleasedContext: Sendable, Equatable {
        var claim: ClaimContext
        let releaseChallenge: UUID
        let postReplyExitDeadlineNanoseconds: UInt64
    }

    private enum State {
        case empty
        case claimPending(ReservationContext, LifecycleMachineRetirementDeadlineTicket)
        case awaitingClaim(ReservationContext, LifecycleMachineRetirementDeadlineTicket)
        case releasePending(ClaimContext, LifecycleMachineRetirementDeadlineTicket)
        case claimResponsePending(ClaimContext, LifecycleMachineRetirementDeadlineTicket)
        case claimed(ClaimContext, LifecycleMachineRetirementDeadlineTicket)
        case releaseResponsePending(ReleasedContext, LifecycleMachineRetirementDeadlineTicket)
        case releasedWaiting(ReleasedContext)
        case exitPending(ReleasedContext, LifecycleMachineRetirementDeadlineTicket)
        case exitScheduled(ReleasedContext, LifecycleMachineRetirementDeadlineTicket)
        case terminal(LifecycleMachineRetirementDeadlineTerminalReason)
    }

    private let lock = NSLock()
    private var state = State.empty
    private var nextGeneration: UInt64
    private var lateArmCancellation =
        Set<LifecycleMachineRetirementDeadlineTicket>()

    package init(initialGeneration: UInt64 = 1) {
        nextGeneration = initialGeneration
    }

    package var phase: LifecycleMachineRetirementDeadlinePhase {
        lock.withLock { phaseLocked }
    }

    package func reserve(
        _ value: LifecycleMachineRetirementDeadlineReservation
    ) -> LifecycleMachineRetirementDeadlineTransition {
        lock.withLock {
            guard case .empty = state else {
                return terminalizeLocked(.duplicateOrReplay)
            }
            guard
                value.handleValidBeforeUTCMicroseconds
                    > value.observation.wallUTCMicroseconds
            else {
                return terminalizeLocked(.invalidTimeObservation)
            }
            guard let cap = monotonicCap(
                validBefore: value.handleValidBeforeUTCMicroseconds,
                observation: value.observation
            ) else {
                return terminalizeLocked(.arithmeticOverflow)
            }
            let context = ReservationContext(
                reservationID: value.reservationID,
                handleValidBeforeUTCMicroseconds:
                    value.handleValidBeforeUTCMicroseconds,
                retainedHandleMonotonicCap: cap,
                lastObservation: value.observation
            )
            guard let ticket = makeTicketLocked(
                kind: .claim,
                reservationID: value.reservationID,
                deadline: cap
            ) else {
                return terminalizeLocked(.arithmeticOverflow)
            }
            state = .claimPending(context, ticket)
            return transitionLocked(
                .applied,
                effects: [.schedule(ticket)]
            )
        }
    }

    package func armSucceeded(
        _ ticket: LifecycleMachineRetirementDeadlineTicket
    ) -> LifecycleMachineRetirementDeadlineTransition {
        lock.withLock {
            switch state {
            case let .claimPending(context, expected) where expected == ticket:
                state = .awaitingClaim(context, ticket)
                return transitionLocked(.applied)
            case let .releasePending(context, expected) where expected == ticket:
                state = .claimResponsePending(context, ticket)
                return transitionLocked(.applied)
            case let .exitPending(context, expected) where expected == ticket:
                state = .exitScheduled(context, ticket)
                return transitionLocked(.applied)
            default:
                if lateArmCancellation.remove(ticket) != nil {
                    return transitionLocked(
                        .stale,
                        effects: [.cancel(ticket)]
                    )
                }
                return transitionLocked(.stale)
            }
        }
    }

    package func armFailed(
        _ ticket: LifecycleMachineRetirementDeadlineTicket
    ) -> LifecycleMachineRetirementDeadlineTransition {
        lock.withLock {
            guard pendingTicketLocked == ticket else {
                return transitionLocked(.stale)
            }
            return terminalizeLocked(
                .deadlineArmFailure,
                cancelCurrent: false
            )
        }
    }

    package func claim(
        _ value: LifecycleMachineRetirementDeadlineClaim
    ) -> LifecycleMachineRetirementDeadlineTransition {
        lock.withLock {
            guard case let .awaitingClaim(storedContext, claimTicket) = state else {
                return duplicateClaimLocked(value)
            }
            var context = storedContext
            guard value.reservationID == context.reservationID else {
                return terminalizeLocked(.bindingMismatch)
            }
            guard
                value.observation.monotonicNanoseconds
                    < claimTicket.deadlineNanoseconds
            else {
                return terminalizeLocked(.claimDeadlineExpired)
            }
            guard
                value.requestIssuedAtUTCMicroseconds
                    <= value.observation.wallUTCMicroseconds,
                value.observation.wallUTCMicroseconds
                    < value.requestValidBeforeUTCMicroseconds,
                value.requestValidBeforeUTCMicroseconds
                    <= context.handleValidBeforeUTCMicroseconds,
                let requestWindow = checkedPositiveDifference(
                    value.requestValidBeforeUTCMicroseconds,
                    value.requestIssuedAtUTCMicroseconds
                ),
                requestWindow <= Self.maximumClaimRequestWindowMicroseconds,
                value.epochDeadlineNanoseconds
                    > value.observation.monotonicNanoseconds
            else {
                return terminalizeLocked(.invalidTimeObservation)
            }
            guard let freshCap = validateAndFreshCapLocked(
                value.observation,
                context: context
            ) else {
                return terminalizeLocked(.invalidTimeObservation)
            }
            guard let fiveSecondCap = checkedAdd(
                value.observation.monotonicNanoseconds,
                Self.maximumReleaseWindowNanoseconds
            ) else {
                return terminalizeLocked(.arithmeticOverflow)
            }
            let deadline = min(
                fiveSecondCap,
                value.epochDeadlineNanoseconds,
                context.retainedHandleMonotonicCap,
                freshCap
            )
            guard deadline > value.observation.monotonicNanoseconds else {
                return terminalizeLocked(.invalidTimeObservation)
            }
            context.lastObservation = value.observation
            let claim = ClaimContext(
                reservation: context,
                requestBindingSHA256: value.requestBindingSHA256,
                helperIdentitySHA256: value.helperIdentitySHA256,
                claimChallenge: value.claimChallenge,
                connectionEpoch: value.connectionEpoch,
                epochDeadlineNanoseconds: value.epochDeadlineNanoseconds,
                releaseDeadlineNanoseconds: deadline
            )
            guard let releaseTicket = makeTicketLocked(
                kind: .release,
                reservationID: context.reservationID,
                deadline: deadline
            ) else {
                return terminalizeLocked(.arithmeticOverflow)
            }
            state = .releasePending(claim, releaseTicket)
            return transitionLocked(
                .applied,
                effects: [.cancel(claimTicket), .schedule(releaseTicket)],
                releaseDeadline: deadline
            )
        }
    }

    package func release(
        _ value: LifecycleMachineRetirementDeadlineRelease
    ) -> LifecycleMachineRetirementDeadlineTransition {
        lock.withLock {
            guard case let .claimed(storedContext, releaseTicket) = state else {
                return duplicateReleaseLocked(value)
            }
            var context = storedContext
            guard
                value.reservationID == context.reservation.reservationID,
                value.requestBindingSHA256 == context.requestBindingSHA256,
                value.helperIdentitySHA256 == context.helperIdentitySHA256,
                value.connectionEpoch == context.connectionEpoch,
                value.releaseDeadlineNanoseconds
                    == context.releaseDeadlineNanoseconds,
                value.releaseChallenge != context.claimChallenge,
                value.releaseChallenge != context.connectionEpoch,
                value.releaseChallenge != context.reservation.reservationID
            else {
                return terminalizeLocked(.bindingMismatch)
            }
            guard
                value.observation.monotonicNanoseconds
                    < context.releaseDeadlineNanoseconds
            else {
                return terminalizeLocked(.releaseDeadlineExpired)
            }
            guard let freshCap = validateAndFreshCapLocked(
                value.observation,
                context: context.reservation
            ) else {
                return terminalizeLocked(.invalidTimeObservation)
            }
            guard let fiveSecondCap = checkedAdd(
                value.observation.monotonicNanoseconds,
                Self.maximumPostReplyExitWindowNanoseconds
            ) else {
                return terminalizeLocked(.arithmeticOverflow)
            }
            let deadline = min(
                fiveSecondCap,
                context.epochDeadlineNanoseconds,
                context.reservation.retainedHandleMonotonicCap,
                freshCap
            )
            guard deadline > value.observation.monotonicNanoseconds else {
                return terminalizeLocked(.invalidTimeObservation)
            }
            context.reservation.lastObservation = value.observation
            let released = ReleasedContext(
                claim: context,
                releaseChallenge: value.releaseChallenge,
                postReplyExitDeadlineNanoseconds: deadline
            )
            state = .releaseResponsePending(released, releaseTicket)
            return transitionLocked(
                .applied,
                effects: [.cancel(releaseTicket)],
                releaseDeadline: context.releaseDeadlineNanoseconds,
                postReplyDeadline: deadline
            )
        }
    }

    package func commitClaimResponse(
        reservationID: UUID,
        connectionEpoch: UUID
    ) -> LifecycleMachineRetirementDeadlineTransition {
        lock.withLock {
            switch state {
            case let .claimResponsePending(context, ticket):
                guard
                    context.reservation.reservationID == reservationID,
                    context.connectionEpoch == connectionEpoch
                else {
                    return terminalizeLocked(.bindingMismatch)
                }
                state = .claimed(context, ticket)
                return transitionLocked(.applied)
            case let .terminal(reason):
                return transitionLocked(.terminal(reason))
            default:
                return terminalizeLocked(.duplicateOrReplay)
            }
        }
    }

    package func commitReleaseResponse(
        reservationID: UUID,
        connectionEpoch: UUID,
        releaseChallenge: UUID
    ) -> LifecycleMachineRetirementDeadlineTransition {
        lock.withLock {
            switch state {
            case let .releaseResponsePending(context, _):
                guard
                    context.claim.reservation.reservationID == reservationID,
                    context.claim.connectionEpoch == connectionEpoch,
                    context.releaseChallenge == releaseChallenge
                else {
                    return terminalizeLocked(.bindingMismatch)
                }
                state = .releasedWaiting(context)
                return transitionLocked(.applied)
            case let .terminal(reason):
                return transitionLocked(.terminal(reason))
            default:
                return terminalizeLocked(.duplicateOrReplay)
            }
        }
    }

    package func replyDidDispatch(
        reservationID: UUID,
        connectionEpoch: UUID,
        observation: LifecycleMachineRetirementDeadlineObservation
    ) -> LifecycleMachineRetirementDeadlineTransition {
        lock.withLock {
            guard case var .releasedWaiting(context) = state else {
                return duplicateReplyLocked(
                    reservationID: reservationID,
                    connectionEpoch: connectionEpoch
                )
            }
            guard
                reservationID == context.claim.reservation.reservationID,
                connectionEpoch == context.claim.connectionEpoch
            else {
                return terminalizeLocked(.bindingMismatch)
            }
            guard
                observation.monotonicNanoseconds
                    < context.postReplyExitDeadlineNanoseconds
            else {
                return terminalizeLocked(
                    .postReplyDeadlineExpiredBeforeDispatch
                )
            }
            guard let freshCap = validateAndFreshCapLocked(
                observation,
                context: context.claim.reservation
            ), freshCap >= context.postReplyExitDeadlineNanoseconds else {
                return terminalizeLocked(.invalidTimeObservation)
            }
            context.claim.reservation.lastObservation = observation
            guard let ticket = makeTicketLocked(
                kind: .postReplyExit,
                reservationID: reservationID,
                deadline: context.postReplyExitDeadlineNanoseconds
            ) else {
                return terminalizeLocked(.arithmeticOverflow)
            }
            state = .exitPending(context, ticket)
            return transitionLocked(
                .applied,
                effects: [.schedule(ticket)],
                releaseDeadline: context.claim.releaseDeadlineNanoseconds,
                postReplyDeadline: context.postReplyExitDeadlineNanoseconds
            )
        }
    }

    package func replyDispatchFailed(
        reservationID: UUID,
        connectionEpoch: UUID
    ) -> LifecycleMachineRetirementDeadlineTransition {
        lock.withLock {
            guard case let .releasedWaiting(context) = state else {
                return transitionLocked(.stale)
            }
            guard
                reservationID == context.claim.reservation.reservationID,
                connectionEpoch == context.claim.connectionEpoch
            else {
                return terminalizeLocked(.bindingMismatch)
            }
            return terminalizeLocked(.replyDispatchFailed)
        }
    }

    package func deadlineFired(
        _ ticket: LifecycleMachineRetirementDeadlineTicket,
        observation: LifecycleMachineRetirementDeadlineObservation
    ) -> LifecycleMachineRetirementDeadlineTransition {
        lock.withLock {
            guard currentTicketLocked == ticket else {
                return transitionLocked(.stale)
            }
            guard let context = reservationContextLocked else {
                return transitionLocked(.stale)
            }
            guard observationsAreNondecreasing(
                observation,
                after: context.lastObservation
            ) else {
                return terminalizeLocked(.invalidTimeObservation)
            }
            if observation.monotonicNanoseconds < ticket.deadlineNanoseconds {
                let isPending = pendingTicketLocked == ticket
                return terminalizeLocked(
                    .schedulerFiredEarly,
                    cancelCurrent: !isPending,
                    rememberLateArm: isPending ? ticket : nil
                )
            }
            let reason: LifecycleMachineRetirementDeadlineTerminalReason =
                switch ticket.kind {
                case .claim: .claimDeadlineExpired
                case .release: .releaseDeadlineExpired
                case .postReplyExit: .postReplyExitDue
                }
            return terminalizeLocked(
                reason,
                cancelCurrent: false,
                rememberLateArm: pendingTicketLocked == ticket
                    ? ticket : nil
            )
        }
    }

    package func cancel(
        reservationID: UUID
    ) -> LifecycleMachineRetirementDeadlineTransition {
        lock.withLock {
            guard
                let context = reservationContextLocked,
                context.reservationID == reservationID,
                !phaseLocked.lifecycleDeadlineIsTerminal
            else {
                return transitionLocked(.stale)
            }
            return terminalizeLocked(
                .cancelled,
                rememberLateArm: pendingTicketLocked
            )
        }
    }

    package func invalidate(
        reservationID: UUID,
        connectionEpoch: UUID
    ) -> LifecycleMachineRetirementDeadlineTransition {
        lock.withLock {
            guard let claim = claimContextLocked else {
                return transitionLocked(.stale)
            }
            guard
                claim.reservation.reservationID == reservationID,
                claim.connectionEpoch == connectionEpoch
            else {
                return transitionLocked(.stale)
            }
            return terminalizeLocked(
                .connectionInvalidated,
                rememberLateArm: pendingTicketLocked
            )
        }
    }

    package func rejectBinding(
        reservationID: UUID
    ) -> LifecycleMachineRetirementDeadlineTransition {
        lock.withLock {
            guard
                let context = reservationContextLocked,
                context.reservationID == reservationID
            else {
                return transitionLocked(.stale)
            }
            return terminalizeLocked(
                .bindingMismatch,
                rememberLateArm: pendingTicketLocked
            )
        }
    }

    package func rejectObservation(
        ticket: LifecycleMachineRetirementDeadlineTicket
    ) -> LifecycleMachineRetirementDeadlineTransition {
        lock.withLock {
            guard currentTicketLocked == ticket else {
                return transitionLocked(.stale)
            }
            return terminalizeLocked(
                .invalidTimeObservation,
                rememberLateArm: pendingTicketLocked == ticket ? ticket : nil
            )
        }
    }

    package func rejectOperationObservation(
        reservationID: UUID
    ) -> LifecycleMachineRetirementDeadlineTransition {
        lock.withLock {
            guard
                let context = reservationContextLocked,
                context.reservationID == reservationID
            else {
                return transitionLocked(.stale)
            }
            return terminalizeLocked(
                .invalidTimeObservation,
                rememberLateArm: pendingTicketLocked
            )
        }
    }

    private var phaseLocked: LifecycleMachineRetirementDeadlinePhase {
        switch state {
        case .empty: .empty
        case .claimPending: .claimDeadlinePendingArm
        case .awaitingClaim: .awaitingClaim
        case .releasePending: .releaseDeadlinePendingArm
        case .claimResponsePending: .claimResponsePendingCommit
        case .claimed: .claimedAwaitingRelease
        case .releaseResponsePending: .releaseResponsePendingCommit
        case .releasedWaiting: .releasedAwaitingReplyDispatch
        case .exitPending: .postReplyExitPendingArm
        case .exitScheduled: .releasedExitScheduled
        case let .terminal(reason): .terminal(reason)
        }
    }

    private var currentTicketLocked:
        LifecycleMachineRetirementDeadlineTicket?
    {
        switch state {
        case let .claimPending(_, ticket),
             let .awaitingClaim(_, ticket),
             let .releasePending(_, ticket),
             let .claimResponsePending(_, ticket),
             let .claimed(_, ticket),
             let .releaseResponsePending(_, ticket),
             let .exitPending(_, ticket),
             let .exitScheduled(_, ticket):
            ticket
        case .empty, .releasedWaiting, .terminal:
            nil
        }
    }

    private var pendingTicketLocked:
        LifecycleMachineRetirementDeadlineTicket?
    {
        switch state {
        case let .claimPending(_, ticket),
             let .releasePending(_, ticket),
             let .exitPending(_, ticket):
            ticket
        default:
            nil
        }
    }

    private var reservationContextLocked: ReservationContext? {
        switch state {
        case let .claimPending(context, _),
             let .awaitingClaim(context, _):
            context
        case let .releasePending(context, _),
             let .claimResponsePending(context, _),
             let .claimed(context, _):
            context.reservation
        case let .releaseResponsePending(context, _),
             let .releasedWaiting(context),
             let .exitPending(context, _),
             let .exitScheduled(context, _):
            context.claim.reservation
        case .empty, .terminal:
            nil
        }
    }

    private var claimContextLocked: ClaimContext? {
        switch state {
        case let .releasePending(context, _),
             let .claimResponsePending(context, _),
             let .claimed(context, _):
            context
        case let .releaseResponsePending(context, _),
             let .releasedWaiting(context),
             let .exitPending(context, _),
             let .exitScheduled(context, _):
            context.claim
        default:
            nil
        }
    }

    private func duplicateClaimLocked(
        _ value: LifecycleMachineRetirementDeadlineClaim
    ) -> LifecycleMachineRetirementDeadlineTransition {
        guard let claim = claimContextLocked else {
            return transitionLocked(.stale)
        }
        let reason: LifecycleMachineRetirementDeadlineTerminalReason =
            value.reservationID == claim.reservation.reservationID
                && value.connectionEpoch == claim.connectionEpoch
                ? .duplicateOrReplay
                : .bindingMismatch
        return terminalizeLocked(
            reason,
            rememberLateArm: pendingTicketLocked
        )
    }

    private func duplicateReleaseLocked(
        _ value: LifecycleMachineRetirementDeadlineRelease
    ) -> LifecycleMachineRetirementDeadlineTransition {
        guard let claim = claimContextLocked else {
            return transitionLocked(.stale)
        }
        let reason: LifecycleMachineRetirementDeadlineTerminalReason =
            value.reservationID == claim.reservation.reservationID
                && value.connectionEpoch == claim.connectionEpoch
                ? .duplicateOrReplay
                : .bindingMismatch
        return terminalizeLocked(
            reason,
            rememberLateArm: pendingTicketLocked
        )
    }

    private func duplicateReplyLocked(
        reservationID: UUID,
        connectionEpoch: UUID
    ) -> LifecycleMachineRetirementDeadlineTransition {
        guard let claim = claimContextLocked else {
            return transitionLocked(.stale)
        }
        let reason: LifecycleMachineRetirementDeadlineTerminalReason =
            reservationID == claim.reservation.reservationID
                && connectionEpoch == claim.connectionEpoch
                ? .duplicateOrReplay
                : .bindingMismatch
        return terminalizeLocked(
            reason,
            rememberLateArm: pendingTicketLocked
        )
    }

    private func makeTicketLocked(
        kind: LifecycleMachineRetirementDeadlineKind,
        reservationID: UUID,
        deadline: UInt64
    ) -> LifecycleMachineRetirementDeadlineTicket? {
        guard nextGeneration > 0 else { return nil }
        let generation = nextGeneration
        let (following, overflow) = nextGeneration.addingReportingOverflow(1)
        guard !overflow else { return nil }
        nextGeneration = following
        return LifecycleMachineRetirementDeadlineTicket(
            kind: kind,
            generation: generation,
            reservationID: reservationID,
            deadlineNanoseconds: deadline
        )
    }

    private func transitionLocked(
        _ disposition: LifecycleMachineRetirementDeadlineDisposition,
        effects: [LifecycleMachineRetirementDeadlineEffect] = [],
        releaseDeadline: UInt64? = nil,
        postReplyDeadline: UInt64? = nil
    ) -> LifecycleMachineRetirementDeadlineTransition {
        LifecycleMachineRetirementDeadlineTransition(
            disposition: disposition,
            phase: phaseLocked,
            effects: effects,
            releaseDeadlineNanoseconds: releaseDeadline,
            postReplyExitDeadlineNanoseconds: postReplyDeadline
        )
    }

    private func terminalizeLocked(
        _ reason: LifecycleMachineRetirementDeadlineTerminalReason,
        cancelCurrent: Bool = true,
        rememberLateArm: LifecycleMachineRetirementDeadlineTicket? = nil
    ) -> LifecycleMachineRetirementDeadlineTransition {
        if case .terminal = state {
            return transitionLocked(.stale)
        }
        let current = currentTicketLocked
        if let rememberLateArm {
            lateArmCancellation.insert(rememberLateArm)
        }
        state = .terminal(reason)
        return transitionLocked(
            .terminal(reason),
            effects: cancelCurrent ? current.map { [.cancel($0)] } ?? [] : []
        )
    }

    private func validateAndFreshCapLocked(
        _ observation: LifecycleMachineRetirementDeadlineObservation,
        context: ReservationContext
    ) -> UInt64? {
        guard
            observationsAreNondecreasing(
                observation,
                after: context.lastObservation
            ),
            observation.wallUTCMicroseconds
                < context.handleValidBeforeUTCMicroseconds
        else {
            return nil
        }
        return monotonicCap(
            validBefore: context.handleValidBeforeUTCMicroseconds,
            observation: observation
        )
    }
}

private func observationsAreNondecreasing(
    _ later: LifecycleMachineRetirementDeadlineObservation,
    after earlier: LifecycleMachineRetirementDeadlineObservation
) -> Bool {
    later.monotonicNanoseconds >= earlier.monotonicNanoseconds
        && later.wallUTCMicroseconds >= earlier.wallUTCMicroseconds
}

private func monotonicCap(
    validBefore: Int64,
    observation: LifecycleMachineRetirementDeadlineObservation
) -> UInt64? {
    guard let remaining = checkedPositiveDifference(
        validBefore,
        observation.wallUTCMicroseconds
    ) else {
        return nil
    }
    let (nanoseconds, multiplicationOverflow) =
        UInt64(remaining).multipliedReportingOverflow(by: 1_000)
    guard !multiplicationOverflow else { return nil }
    return checkedAdd(observation.monotonicNanoseconds, nanoseconds)
}

private func checkedPositiveDifference(
    _ later: Int64,
    _ earlier: Int64
) -> Int64? {
    let (difference, overflow) = later.subtractingReportingOverflow(earlier)
    guard !overflow, difference > 0 else { return nil }
    return difference
}

private func checkedAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64? {
    let (value, overflow) = lhs.addingReportingOverflow(rhs)
    return overflow ? nil : value
}

private extension LifecycleMachineRetirementDeadlinePhase {
    var lifecycleDeadlineIsTerminal: Bool {
        if case .terminal = self { return true }
        return false
    }
}

private extension UUID {
    var lifecycleDeadlineIsZero: Bool {
        uuidString == "00000000-0000-0000-0000-000000000000"
    }
}
