import Foundation
import Testing
@testable import StornautLifecycle

@Suite("Lifecycle machine retirement deadline state")
struct LifecycleMachineRetirementEscrowDeadlineStateTests {
    @Test
    func normalPathFreezesEveryDeadlineAndArmsExitOnlyAfterReply() throws {
        let fixture = DeadlineStateFixture()
        let state = LifecycleMachineRetirementEscrowDeadlineState()

        let reservation = state.reserve(try fixture.reservation())
        let claimTicket = try #require(reservation.scheduledTicket)
        #expect(reservation.disposition == .applied)
        #expect(reservation.phase == .claimDeadlinePendingArm)
        #expect(claimTicket.kind == .claim)
        #expect(claimTicket.generation == 1)
        #expect(claimTicket.deadlineNanoseconds == 31_000_000_000)

        let claimArmed = state.armSucceeded(claimTicket)
        #expect(claimArmed.phase == .awaitingClaim)
        #expect(claimArmed.effects.isEmpty)

        let claim = state.claim(try fixture.claim())
        let releaseTicket = try #require(claim.scheduledTicket)
        #expect(claim.disposition == .applied)
        #expect(claim.phase == .releaseDeadlinePendingArm)
        #expect(claim.cancelledTickets == [claimTicket])
        #expect(claim.releaseDeadlineNanoseconds == 7_000_000_000)
        #expect(releaseTicket.kind == .release)
        #expect(releaseTicket.generation == 2)
        #expect(releaseTicket.deadlineNanoseconds == 7_000_000_000)

        #expect(
            state.armSucceeded(releaseTicket).phase
                == .claimResponsePendingCommit
        )
        #expect(
            state.commitClaimResponse(
                reservationID: fixture.reservationID,
                connectionEpoch: fixture.connectionEpoch
            ).phase == .claimedAwaitingRelease
        )

        let release = state.release(
            try fixture.release(deadlineNanoseconds: 7_000_000_000)
        )
        #expect(release.disposition == .applied)
        #expect(release.phase == .releaseResponsePendingCommit)
        #expect(release.cancelledTickets == [releaseTicket])
        #expect(release.scheduledTicket == nil)
        #expect(release.postReplyExitDeadlineNanoseconds == 8_000_000_000)
        #expect(
            state.commitReleaseResponse(
                reservationID: fixture.reservationID,
                connectionEpoch: fixture.connectionEpoch,
                releaseChallenge: fixture.releaseChallenge
            ).phase == .releasedAwaitingReplyDispatch
        )

        let replyCommitted = state.replyDidDispatch(
            reservationID: fixture.reservationID,
            connectionEpoch: fixture.connectionEpoch,
            observation: try fixture.observation(
                monotonic: 3_500_000_000,
                wallOffsetMicroseconds: 2_500_000
            )
        )
        let exitTicket = try #require(replyCommitted.scheduledTicket)
        #expect(replyCommitted.phase == .postReplyExitPendingArm)
        #expect(exitTicket.kind == .postReplyExit)
        #expect(exitTicket.generation == 3)
        #expect(exitTicket.deadlineNanoseconds == 8_000_000_000)

        #expect(state.armSucceeded(exitTicket).phase == .releasedExitScheduled)
        let exitDue = state.deadlineFired(
            exitTicket,
            observation: try fixture.observation(
                monotonic: 8_000_000_000,
                wallOffsetMicroseconds: 7_000_000
            )
        )
        #expect(exitDue.disposition == .terminal(.postReplyExitDue))
        #expect(exitDue.phase == .terminal(.postReplyExitDue))
        #expect(exitDue.effects.isEmpty)
    }

    @Test
    func staleArmSuccessCancelsTheActuallyCreatedExternalTimer() throws {
        let fixture = DeadlineStateFixture()
        let state = LifecycleMachineRetirementEscrowDeadlineState()
        let ticket = try #require(
            state.reserve(try fixture.reservation()).scheduledTicket
        )

        let cancelled = state.cancel(reservationID: fixture.reservationID)
        #expect(cancelled.disposition == .terminal(.cancelled))
        #expect(cancelled.cancelledTickets == [ticket])

        let lateArm = state.armSucceeded(ticket)
        #expect(lateArm.disposition == .stale)
        #expect(lateArm.cancelledTickets == [ticket])
        #expect(lateArm.phase == .terminal(.cancelled))

        let repeated = state.armSucceeded(ticket)
        #expect(repeated.disposition == .stale)
        #expect(repeated.effects.isEmpty)
    }

    @Test
    func callbackMayWinWhileArmAcknowledgementIsPending() throws {
        let fixture = DeadlineStateFixture()
        let dueState = LifecycleMachineRetirementEscrowDeadlineState()
        let dueTicket = try #require(
            dueState.reserve(try fixture.reservation()).scheduledTicket
        )
        let due = dueState.deadlineFired(
            dueTicket,
            observation: try fixture.observation(
                monotonic: dueTicket.deadlineNanoseconds,
                wallOffsetMicroseconds: 30_000_000
            )
        )
        #expect(due.disposition == .terminal(.claimDeadlineExpired))
        #expect(dueState.armSucceeded(dueTicket).cancelledTickets == [dueTicket])

        let earlyState = LifecycleMachineRetirementEscrowDeadlineState()
        let earlyTicket = try #require(
            earlyState.reserve(try fixture.reservation()).scheduledTicket
        )
        let early = earlyState.deadlineFired(
            earlyTicket,
            observation: try fixture.observation(
                monotonic: earlyTicket.deadlineNanoseconds - 1,
                wallOffsetMicroseconds: 29_999_999
            )
        )
        #expect(early.disposition == .terminal(.schedulerFiredEarly))
        #expect(
            earlyState.armSucceeded(earlyTicket).cancelledTickets
                == [earlyTicket]
        )
    }

    @Test
    func everyArmedEarlyCallbackReturnsOneSelfCancelEffect() throws {
        let fixture = DeadlineStateFixture()

        let claim = try fixture.awaitingClaimState()
        let claimResult = claim.state.deadlineFired(
            claim.claimTicket,
            observation: try fixture.observation(
                monotonic: claim.claimTicket.deadlineNanoseconds - 1,
                wallOffsetMicroseconds: 29_999_999
            )
        )
        #expect(claimResult.disposition == .terminal(.schedulerFiredEarly))
        #expect(claimResult.cancelledTickets == [claim.claimTicket])

        let release = try fixture.claimedAwaitingReleaseState()
        let releaseResult = release.state.deadlineFired(
            release.releaseTicket,
            observation: try fixture.observation(
                monotonic: release.releaseTicket.deadlineNanoseconds - 1,
                wallOffsetMicroseconds: 5_999_999
            )
        )
        #expect(releaseResult.disposition == .terminal(.schedulerFiredEarly))
        #expect(releaseResult.cancelledTickets == [release.releaseTicket])

        let exit = try fixture.exitScheduledState()
        let exitResult = exit.state.deadlineFired(
            exit.exitTicket,
            observation: try fixture.observation(
                monotonic: exit.exitTicket.deadlineNanoseconds - 1,
                wallOffsetMicroseconds: 6_999_999
            )
        )
        #expect(exitResult.disposition == .terminal(.schedulerFiredEarly))
        #expect(exitResult.cancelledTickets == [exit.exitTicket])
    }

    @Test
    func armFailureIsTerminalOnlyForTheMatchingPendingTicket() throws {
        let fixture = DeadlineStateFixture()
        let state = LifecycleMachineRetirementEscrowDeadlineState()
        let ticket = try #require(
            state.reserve(try fixture.reservation()).scheduledTicket
        )
        let foreign = LifecycleMachineRetirementDeadlineTicket(
            kind: .claim,
            generation: ticket.generation + 1,
            reservationID: ticket.reservationID,
            deadlineNanoseconds: ticket.deadlineNanoseconds
        )

        #expect(state.armFailed(foreign).disposition == .stale)
        #expect(state.phase == .claimDeadlinePendingArm)
        #expect(
            state.armFailed(ticket).disposition
                == .terminal(.deadlineArmFailure)
        )
        #expect(state.armFailed(ticket).disposition == .stale)
    }

    @Test
    func claimUsesEpochAndHandleCapsButNotConsumedRequestWindow() throws {
        let fixture = DeadlineStateFixture()

        let epochLimited = try fixture.awaitingClaimState()
        let epochClaim = epochLimited.state.claim(
            try fixture.claim(epochDeadlineNanoseconds: 5_000_000_000)
        )
        #expect(epochClaim.releaseDeadlineNanoseconds == 5_000_000_000)

        let handleLimited = try fixture.awaitingClaimState(
            handleValidBeforeOffsetMicroseconds: 3_000_000
        )
        let handleClaim = handleLimited.state.claim(
            try fixture.claim(
                requestValidBeforeOffsetMicroseconds: 2_500_000,
                epochDeadlineNanoseconds: 20_000_000_000
            )
        )
        #expect(handleClaim.releaseDeadlineNanoseconds == 4_000_000_000)

        let requestWindowConsumed = try fixture.awaitingClaimState()
        let requestClaim = requestWindowConsumed.state.claim(
            try fixture.claim(
                requestValidBeforeOffsetMicroseconds: 1_000_001
            )
        )
        #expect(requestClaim.releaseDeadlineNanoseconds == 7_000_000_000)
    }

    @Test
    func requestBoundsAndObservationRollbackFailClosed() throws {
        let fixture = DeadlineStateFixture()

        let futureIssued = try fixture.awaitingClaimState()
        let futureResult = futureIssued.state.claim(
            try fixture.claim(
                requestIssuedAtOffsetMicroseconds: 1_000_001
            )
        )
        #expect(futureResult.disposition == .terminal(.invalidTimeObservation))

        let overlong = try fixture.awaitingClaimState()
        let overlongResult = overlong.state.claim(
            try fixture.claim(
                requestIssuedAtOffsetMicroseconds: 0,
                requestValidBeforeOffsetMicroseconds: 15_000_001
            )
        )
        #expect(overlongResult.disposition == .terminal(.invalidTimeObservation))

        let rollback = try fixture.claimedAwaitingReleaseState()
        let rollbackResult = rollback.state.release(
            try fixture.release(
                deadlineNanoseconds: rollback.releaseDeadline,
                monotonic: 1_999_999_999,
                wallOffsetMicroseconds: 999_999
            )
        )
        #expect(rollbackResult.disposition == .terminal(.invalidTimeObservation))
    }

    @Test
    func checkedTimeAndGenerationArithmeticNeverSaturates() throws {
        let fixture = DeadlineStateFixture()
        let state = LifecycleMachineRetirementEscrowDeadlineState()
        let overflow = state.reserve(
            try fixture.reservation(
                monotonic: UInt64.max - 999,
                wallOffsetMicroseconds: 29_999_999
            )
        )
        #expect(overflow.disposition == .terminal(.arithmeticOverflow))
        #expect(overflow.scheduledTicket == nil)

        for generation in [UInt64(0), UInt64.max] {
            let generationState =
                LifecycleMachineRetirementEscrowDeadlineState(
                    initialGeneration: generation
                )
            let result = generationState.reserve(try fixture.reservation())
            #expect(result.disposition == .terminal(.arithmeticOverflow))
            #expect(result.scheduledTicket == nil)
        }

        let claimGeneration = try fixture.awaitingClaimState(
            initialGeneration: UInt64.max - 1
        )
        let claimOverflow = claimGeneration.state.claim(try fixture.claim())
        #expect(claimOverflow.disposition == .terminal(.arithmeticOverflow))
        #expect(claimOverflow.cancelledTickets == [claimGeneration.claimTicket])

        let replyGeneration = try fixture.releasedAwaitingReplyState(
            initialGeneration: UInt64.max - 2
        )
        let replyOverflow = replyGeneration.state.replyDidDispatch(
            reservationID: fixture.reservationID,
            connectionEpoch: fixture.connectionEpoch,
            observation: try fixture.observation(
                monotonic: 3_500_000_000,
                wallOffsetMicroseconds: 2_500_000
            )
        )
        #expect(replyOverflow.disposition == .terminal(.arithmeticOverflow))
        #expect(replyOverflow.scheduledTicket == nil)
    }

    @Test
    func requestTicksAndForwardWallJumpRemainFailClosed() throws {
        let fixture = DeadlineStateFixture()

        let equality = try fixture.awaitingClaimState()
        #expect(
            equality.state.claim(
                try fixture.claim(
                    requestIssuedAtOffsetMicroseconds: 1_000_000
                )
            ).disposition == .applied
        )

        let exactWindow = try fixture.awaitingClaimState()
        #expect(
            exactWindow.state.claim(
                try fixture.claim(
                    requestIssuedAtOffsetMicroseconds: 0,
                    requestValidBeforeOffsetMicroseconds: 15_000_000
                )
            ).disposition == .applied
        )

        let atValidBefore = try fixture.awaitingClaimState()
        #expect(
            atValidBefore.state.claim(
                try fixture.claim(
                    requestValidBeforeOffsetMicroseconds: 1_000_000
                )
            ).disposition == .terminal(.invalidTimeObservation)
        )

        let forwardJump = try fixture.awaitingClaimState()
        let shortened = forwardJump.state.claim(
            try fixture.claim(
                requestIssuedAtOffsetMicroseconds: 20_000_000,
                requestValidBeforeOffsetMicroseconds: 29_500_000,
                monotonic: 2_000_000_000,
                wallOffsetMicroseconds: 29_000_000
            )
        )
        #expect(shortened.releaseDeadlineNanoseconds == 3_000_000_000)
    }

    @Test
    func concurrentDuplicateClaimsTerminallyConsumeTheAttempt() async throws {
        let fixture = DeadlineStateFixture()
        let prepared = try fixture.awaitingClaimState()
        let claim = try fixture.claim()

        let results = await withTaskGroup(
            of: LifecycleMachineRetirementDeadlineDisposition.self
        ) { group in
            for _ in 0..<16 {
                group.addTask { prepared.state.claim(claim).disposition }
            }
            var values: [LifecycleMachineRetirementDeadlineDisposition] = []
            for await value in group { values.append(value) }
            return values
        }

        #expect(results.filter { $0 == .applied }.count <= 1)
        #expect(results.contains(.terminal(.duplicateOrReplay)))
        #expect(prepared.state.phase == .terminal(.duplicateOrReplay))
    }

    @Test
    func linearizationPairsPreserveTheWinnerAndNeverResurrectTerminalState()
        throws
    {
        let fixture = DeadlineStateFixture()

        let claimFirst = try fixture.awaitingClaimState()
        let claimWon = claimFirst.state.claim(try fixture.claim())
        let claimReleaseTicket = try #require(claimWon.scheduledTicket)
        let staleClaimDeadline = claimFirst.state.deadlineFired(
            claimFirst.claimTicket,
            observation: try fixture.observation(
                monotonic: claimFirst.claimTicket.deadlineNanoseconds,
                wallOffsetMicroseconds: 30_000_000
            )
        )
        #expect(staleClaimDeadline.disposition == .stale)
        #expect(staleClaimDeadline.scheduledTicket == nil)
        #expect(claimFirst.state.phase == .releaseDeadlinePendingArm)
        #expect(claimWon.cancelledTickets == [claimFirst.claimTicket])
        #expect(claimWon.scheduledTicket == claimReleaseTicket)

        let claimDeadlineFirst = try fixture.awaitingClaimState()
        let claimTimedOut = claimDeadlineFirst.state.deadlineFired(
            claimDeadlineFirst.claimTicket,
            observation: try fixture.observation(
                monotonic: claimDeadlineFirst.claimTicket.deadlineNanoseconds,
                wallOffsetMicroseconds: 30_000_000
            )
        )
        let lateClaim = claimDeadlineFirst.state.claim(try fixture.claim())
        #expect(claimTimedOut.disposition == .terminal(.claimDeadlineExpired))
        #expect(lateClaim.disposition == .stale)
        #expect(lateClaim.scheduledTicket == nil)
        #expect(
            claimDeadlineFirst.state.phase
                == .terminal(.claimDeadlineExpired)
        )

        let releaseFirst = try fixture.claimedAwaitingReleaseState()
        let releaseWon = releaseFirst.state.release(
            try fixture.release(
                deadlineNanoseconds: releaseFirst.releaseDeadline
            )
        )
        let releaseCommitted = releaseFirst.state.commitReleaseResponse(
            reservationID: fixture.reservationID,
            connectionEpoch: fixture.connectionEpoch,
            releaseChallenge: fixture.releaseChallenge
        )
        let staleReleaseDeadline = releaseFirst.state.deadlineFired(
            releaseFirst.releaseTicket,
            observation: try fixture.observation(
                monotonic: releaseFirst.releaseTicket.deadlineNanoseconds,
                wallOffsetMicroseconds: 6_000_000
            )
        )
        #expect(releaseWon.cancelledTickets == [releaseFirst.releaseTicket])
        #expect(releaseCommitted.phase == .releasedAwaitingReplyDispatch)
        #expect(staleReleaseDeadline.disposition == .stale)
        #expect(staleReleaseDeadline.scheduledTicket == nil)
        #expect(releaseFirst.state.phase == .releasedAwaitingReplyDispatch)

        let releaseDeadlineFirst = try fixture.claimedAwaitingReleaseState()
        let releaseTimedOut = releaseDeadlineFirst.state.deadlineFired(
            releaseDeadlineFirst.releaseTicket,
            observation: try fixture.observation(
                monotonic: releaseDeadlineFirst.releaseTicket.deadlineNanoseconds,
                wallOffsetMicroseconds: 6_000_000
            )
        )
        let lateRelease = releaseDeadlineFirst.state.release(
            try fixture.release(
                deadlineNanoseconds: releaseDeadlineFirst.releaseDeadline
            )
        )
        #expect(
            releaseTimedOut.disposition == .terminal(.releaseDeadlineExpired)
        )
        #expect(lateRelease.disposition == .stale)
        #expect(lateRelease.scheduledTicket == nil)
        #expect(
            releaseDeadlineFirst.state.phase
                == .terminal(.releaseDeadlineExpired)
        )

        let releaseThenCancel = try fixture.claimedAwaitingReleaseState()
        let released = releaseThenCancel.state.release(
            try fixture.release(
                deadlineNanoseconds: releaseThenCancel.releaseDeadline
            )
        )
        let committedRelease = releaseThenCancel.state.commitReleaseResponse(
            reservationID: fixture.reservationID,
            connectionEpoch: fixture.connectionEpoch,
            releaseChallenge: fixture.releaseChallenge
        )
        let cancelledAfterRelease = releaseThenCancel.state.cancel(
            reservationID: fixture.reservationID
        )
        #expect(released.phase == .releaseResponsePendingCommit)
        #expect(committedRelease.phase == .releasedAwaitingReplyDispatch)
        #expect(cancelledAfterRelease.disposition == .terminal(.cancelled))
        #expect(cancelledAfterRelease.effects.isEmpty)

        let cancelThenRelease = try fixture.claimedAwaitingReleaseState()
        let cancelWon = cancelThenRelease.state.cancel(
            reservationID: fixture.reservationID
        )
        let releaseLost = cancelThenRelease.state.release(
            try fixture.release(
                deadlineNanoseconds: cancelThenRelease.releaseDeadline
            )
        )
        #expect(cancelWon.cancelledTickets == [cancelThenRelease.releaseTicket])
        #expect(releaseLost.disposition == .stale)
        #expect(releaseLost.scheduledTicket == nil)
        #expect(cancelThenRelease.state.phase == .terminal(.cancelled))

        let replyThenInvalidate = try fixture.releasedAwaitingReplyState()
        let replyWon = replyThenInvalidate.state.replyDidDispatch(
            reservationID: fixture.reservationID,
            connectionEpoch: fixture.connectionEpoch,
            observation: try fixture.observation(
                monotonic: 3_500_000_000,
                wallOffsetMicroseconds: 2_500_000
            )
        )
        let exitTicket = try #require(replyWon.scheduledTicket)
        let invalidatedAfterReply = replyThenInvalidate.state.invalidate(
            reservationID: fixture.reservationID,
            connectionEpoch: fixture.connectionEpoch
        )
        #expect(invalidatedAfterReply.cancelledTickets == [exitTicket])
        #expect(
            invalidatedAfterReply.disposition
                == .terminal(.connectionInvalidated)
        )

        let invalidateThenReply = try fixture.releasedAwaitingReplyState()
        let invalidateWon = invalidateThenReply.state.invalidate(
            reservationID: fixture.reservationID,
            connectionEpoch: fixture.connectionEpoch
        )
        let replyLost = invalidateThenReply.state.replyDidDispatch(
            reservationID: fixture.reservationID,
            connectionEpoch: fixture.connectionEpoch,
            observation: try fixture.observation(
                monotonic: 3_500_000_000,
                wallOffsetMicroseconds: 2_500_000
            )
        )
        #expect(invalidateWon.disposition == .terminal(.connectionInvalidated))
        #expect(replyLost.disposition == .stale)
        #expect(replyLost.scheduledTicket == nil)
        #expect(
            invalidateThenReply.state.phase
                == .terminal(.connectionInvalidated)
        )
    }

    @Test
    func foreignBindingConsumesWhileForeignInvalidationIsHarmless() throws {
        let fixture = DeadlineStateFixture()
        let foreignInvalidation = try fixture.claimedAwaitingReleaseState()
        let ignored = foreignInvalidation.state.invalidate(
            reservationID: fixture.reservationID,
            connectionEpoch: fixture.foreignUUID
        )
        #expect(ignored.disposition == .stale)
        #expect(
            foreignInvalidation.state.phase == .claimedAwaitingRelease
        )

        let mismatch = try fixture.claimedAwaitingReleaseState()
        let wrongRelease = mismatch.state.release(
            try fixture.release(
                deadlineNanoseconds: mismatch.releaseDeadline,
                requestBinding: fixture.foreignDigest
            )
        )
        #expect(wrongRelease.disposition == .terminal(.bindingMismatch))
        #expect(mismatch.state.phase == .terminal(.bindingMismatch))
    }

    @Test
    func duplicateReleaseReplyAndEveryBindingAxisConsumeTerminally() throws {
        let fixture = DeadlineStateFixture()

        let duplicateRelease = try fixture.releasedAwaitingReplyState()
        let replay = duplicateRelease.state.release(
            try fixture.release(
                deadlineNanoseconds: duplicateRelease.releaseDeadline
            )
        )
        #expect(replay.disposition == .terminal(.duplicateOrReplay))

        let duplicateReply = try fixture.exitPendingState()
        let repeatedReply = duplicateReply.state.replyDidDispatch(
            reservationID: fixture.reservationID,
            connectionEpoch: fixture.connectionEpoch,
            observation: try fixture.observation(
                monotonic: 3_600_000_000,
                wallOffsetMicroseconds: 2_600_000
            )
        )
        #expect(repeatedReply.disposition == .terminal(.duplicateOrReplay))
        #expect(repeatedReply.cancelledTickets == [duplicateReply.exitTicket])

        for drift in DeadlineStateFixture.ReleaseDrift.allCases {
            let prepared = try fixture.claimedAwaitingReleaseState()
            let result = prepared.state.release(
                try fixture.release(
                    deadlineNanoseconds: prepared.releaseDeadline,
                    drift: drift
                )
            )
            #expect(result.disposition == .terminal(.bindingMismatch))
        }
    }

    @Test
    func staleArmFailureCannotErasePendingLateArmCleanup() throws {
        let fixture = DeadlineStateFixture()
        let state = LifecycleMachineRetirementEscrowDeadlineState()
        let ticket = try #require(
            state.reserve(try fixture.reservation()).scheduledTicket
        )
        _ = state.cancel(reservationID: fixture.reservationID)
        #expect(state.armFailed(ticket).disposition == .stale)
        #expect(state.armSucceeded(ticket).cancelledTickets == [ticket])
    }

    @Test
    func bindingRejectionOwnsPendingArmedAndIdempotentCleanup() throws {
        let fixture = DeadlineStateFixture()
        let empty = LifecycleMachineRetirementEscrowDeadlineState()
        #expect(
            empty.rejectBinding(reservationID: fixture.reservationID)
                .disposition == .stale
        )

        let pending = LifecycleMachineRetirementEscrowDeadlineState()
        let pendingTicket = try #require(
            pending.reserve(try fixture.reservation()).scheduledTicket
        )
        #expect(
            pending.rejectBinding(reservationID: fixture.foreignUUID)
                .disposition == .stale
        )
        let pendingRejected = pending.rejectBinding(
            reservationID: fixture.reservationID
        )
        #expect(pendingRejected.disposition == .terminal(.bindingMismatch))
        #expect(pendingRejected.cancelledTickets == [pendingTicket])
        #expect(pendingRejected.scheduledTicket == nil)
        #expect(pending.armSucceeded(pendingTicket).cancelledTickets == [pendingTicket])

        let armed = try fixture.awaitingClaimState()
        let armedRejected = armed.state.rejectBinding(
            reservationID: fixture.reservationID
        )
        #expect(armedRejected.disposition == .terminal(.bindingMismatch))
        #expect(armedRejected.cancelledTickets == [armed.claimTicket])
        let repeated = armed.state.rejectBinding(
            reservationID: fixture.reservationID
        )
        #expect(repeated.disposition == .stale)
        #expect(repeated.effects.isEmpty)
        #expect(armed.state.phase == .terminal(.bindingMismatch))
    }

    @Test
    func observationRejectionIsBoundToTheExactCurrentTicket() throws {
        let fixture = DeadlineStateFixture()
        let pending = LifecycleMachineRetirementEscrowDeadlineState()
        let pendingTicket = try #require(
            pending.reserve(try fixture.reservation()).scheduledTicket
        )
        let foreign = LifecycleMachineRetirementDeadlineTicket(
            kind: .claim, generation: pendingTicket.generation + 1,
            reservationID: pendingTicket.reservationID,
            deadlineNanoseconds: pendingTicket.deadlineNanoseconds
        )
        #expect(pending.rejectObservation(ticket: foreign).disposition == .stale)
        let pendingRejected = pending.rejectObservation(ticket: pendingTicket)
        #expect(
            pendingRejected.disposition == .terminal(.invalidTimeObservation)
        )
        #expect(pendingRejected.cancelledTickets == [pendingTicket])
        #expect(pendingRejected.scheduledTicket == nil)
        #expect(pending.armSucceeded(pendingTicket).cancelledTickets == [pendingTicket])

        let replaced = try fixture.awaitingClaimState()
        let oldTicket = replaced.claimTicket
        let claim = replaced.state.claim(try fixture.claim())
        let releaseTicket = try #require(claim.scheduledTicket)
        #expect(replaced.state.rejectObservation(ticket: oldTicket).disposition == .stale)
        #expect(replaced.state.phase == .releaseDeadlinePendingArm)
        let currentRejected = replaced.state.rejectObservation(
            ticket: releaseTicket
        )
        #expect(
            currentRejected.disposition == .terminal(.invalidTimeObservation)
        )
        #expect(currentRejected.cancelledTickets == [releaseTicket])
        #expect(
            replaced.state.rejectObservation(ticket: releaseTicket).disposition
                == .stale
        )
    }

    @Test
    func operationObservationRejectionOwnsOnlyTheExactLiveReservation() throws {
        let fixture = DeadlineStateFixture()
        let empty = LifecycleMachineRetirementEscrowDeadlineState()
        #expect(
            empty.rejectOperationObservation(
                reservationID: fixture.reservationID
            ).disposition == .stale
        )

        let pending = LifecycleMachineRetirementEscrowDeadlineState()
        let pendingTicket = try #require(
            pending.reserve(try fixture.reservation()).scheduledTicket
        )
        #expect(
            pending.rejectOperationObservation(
                reservationID: fixture.foreignUUID
            ).disposition == .stale
        )
        let rejectedPending = pending.rejectOperationObservation(
            reservationID: fixture.reservationID
        )
        #expect(
            rejectedPending.disposition == .terminal(.invalidTimeObservation)
        )
        #expect(rejectedPending.cancelledTickets == [pendingTicket])
        #expect(
            pending.armSucceeded(pendingTicket).cancelledTickets
                == [pendingTicket]
        )

        let armed = try fixture.awaitingClaimState()
        let rejectedArmed = armed.state.rejectOperationObservation(
            reservationID: fixture.reservationID
        )
        #expect(
            rejectedArmed.disposition == .terminal(.invalidTimeObservation)
        )
        #expect(rejectedArmed.cancelledTickets == [armed.claimTicket])
        let repeated = armed.state.rejectOperationObservation(
            reservationID: fixture.reservationID
        )
        #expect(repeated.disposition == .stale)
        #expect(repeated.effects.isEmpty)
        #expect(
            armed.state.phase == .terminal(.invalidTimeObservation)
        )
    }

    @Test
    func claimResponseCommitLinearizesBothDeadlineOrders() throws {
        let fixture = DeadlineStateFixture()

        let callbackFirst = try fixture.claimResponsePendingState()
        let expired = callbackFirst.state.deadlineFired(
            callbackFirst.releaseTicket,
            observation: try fixture.observation(
                monotonic: callbackFirst.releaseTicket.deadlineNanoseconds,
                wallOffsetMicroseconds: 6_000_000
            )
        )
        #expect(expired.disposition == .terminal(.releaseDeadlineExpired))
        let rejectedCommit = callbackFirst.state.commitClaimResponse(
            reservationID: fixture.reservationID,
            connectionEpoch: fixture.connectionEpoch
        )
        #expect(
            rejectedCommit.disposition
                == .terminal(.releaseDeadlineExpired)
        )

        let commitFirst = try fixture.claimResponsePendingState()
        let committed = commitFirst.state.commitClaimResponse(
            reservationID: fixture.reservationID,
            connectionEpoch: fixture.connectionEpoch
        )
        #expect(committed.disposition == .applied)
        #expect(committed.phase == .claimedAwaitingRelease)
        let laterExpiry = commitFirst.state.deadlineFired(
            commitFirst.releaseTicket,
            observation: try fixture.observation(
                monotonic: commitFirst.releaseTicket.deadlineNanoseconds,
                wallOffsetMicroseconds: 6_000_000
            )
        )
        #expect(
            laterExpiry.disposition == .terminal(.releaseDeadlineExpired)
        )
        #expect(
            commitFirst.state.phase == .terminal(.releaseDeadlineExpired)
        )
    }

    @Test
    func releaseResponseCommitMustPrecedeReplyDispatch() throws {
        let fixture = DeadlineStateFixture()
        let replyFirst = try fixture.releaseResponsePendingState()
        let prematureReply = replyFirst.state.replyDidDispatch(
            reservationID: fixture.reservationID,
            connectionEpoch: fixture.connectionEpoch,
            observation: try fixture.observation(
                monotonic: 3_500_000_000,
                wallOffsetMicroseconds: 2_500_000
            )
        )
        #expect(prematureReply.disposition == .terminal(.duplicateOrReplay))
        #expect(
            replyFirst.state.commitReleaseResponse(
                reservationID: fixture.reservationID,
                connectionEpoch: fixture.connectionEpoch,
                releaseChallenge: fixture.releaseChallenge
            ).disposition == .terminal(.duplicateOrReplay)
        )

        let commitFirst = try fixture.releaseResponsePendingState()
        #expect(
            commitFirst.state.commitReleaseResponse(
                reservationID: fixture.reservationID,
                connectionEpoch: fixture.connectionEpoch,
                releaseChallenge: fixture.releaseChallenge
            ).phase == .releasedAwaitingReplyDispatch
        )
        let reply = commitFirst.state.replyDidDispatch(
            reservationID: fixture.reservationID,
            connectionEpoch: fixture.connectionEpoch,
            observation: try fixture.observation(
                monotonic: 3_500_000_000,
                wallOffsetMicroseconds: 2_500_000
            )
        )
        #expect(reply.disposition == .applied)
        #expect(reply.phase == .postReplyExitPendingArm)
    }

    @Test
    func releaseResponseCommitLinearizesBothDeadlineOrders() throws {
        let fixture = DeadlineStateFixture()

        let callbackFirst = try fixture.releaseResponsePendingState()
        let releaseTicket = callbackFirst.releaseTicket
        let expired = callbackFirst.state.deadlineFired(
            releaseTicket,
            observation: try fixture.observation(
                monotonic: releaseTicket.deadlineNanoseconds,
                wallOffsetMicroseconds: 6_000_000
            )
        )
        #expect(expired.disposition == .terminal(.releaseDeadlineExpired))
        let rejectedCommit = callbackFirst.state.commitReleaseResponse(
            reservationID: fixture.reservationID,
            connectionEpoch: fixture.connectionEpoch,
            releaseChallenge: fixture.releaseChallenge
        )
        #expect(
            rejectedCommit.disposition
                == .terminal(.releaseDeadlineExpired)
        )

        let commitFirst = try fixture.releaseResponsePendingState()
        let committedTicket = commitFirst.releaseTicket
        #expect(
            commitFirst.state.commitReleaseResponse(
                reservationID: fixture.reservationID,
                connectionEpoch: fixture.connectionEpoch,
                releaseChallenge: fixture.releaseChallenge
            ).phase == .releasedAwaitingReplyDispatch
        )
        let laterExpiry = commitFirst.state.deadlineFired(
            committedTicket,
            observation: try fixture.observation(
                monotonic: committedTicket.deadlineNanoseconds,
                wallOffsetMicroseconds: 6_000_000
            )
        )
        #expect(laterExpiry.disposition == .stale)
        #expect(
            commitFirst.state.phase == .releasedAwaitingReplyDispatch
        )
    }

    @Test
    func releaseChallengeMustBeFreshAcrossEveryRetainedUUID() throws {
        let fixture = DeadlineStateFixture()
        for challenge in [
            fixture.claimChallenge,
            fixture.connectionEpoch,
            fixture.reservationID,
        ] {
            let prepared = try fixture.claimedAwaitingReleaseState()
            let result = prepared.state.release(
                try fixture.release(
                    deadlineNanoseconds: prepared.releaseDeadline,
                    releaseChallenge: challenge
                )
            )
            #expect(result.disposition == .terminal(.bindingMismatch))
        }
    }

    @Test
    func staleReplacedDeadlineCallbacksCannotDestroyLaterStates() throws {
        let fixture = DeadlineStateFixture()
        let prepared = try fixture.awaitingClaimState()
        let oldClaimTicket = prepared.claimTicket
        let claim = prepared.state.claim(try fixture.claim())
        let releaseTicket = try #require(claim.scheduledTicket)

        let staleClaim = prepared.state.deadlineFired(
            oldClaimTicket,
            observation: try fixture.observation(
                monotonic: oldClaimTicket.deadlineNanoseconds,
                wallOffsetMicroseconds: 30_000_000
            )
        )
        #expect(staleClaim.disposition == .stale)
        #expect(prepared.state.phase == .releaseDeadlinePendingArm)

        _ = prepared.state.armSucceeded(releaseTicket)
        _ = prepared.state.commitClaimResponse(
            reservationID: fixture.reservationID,
            connectionEpoch: fixture.connectionEpoch
        )
        let release = prepared.state.release(
            try fixture.release(
                deadlineNanoseconds: try #require(
                    claim.releaseDeadlineNanoseconds
                )
            )
        )
        #expect(release.phase == .releaseResponsePendingCommit)
        #expect(
            prepared.state.commitReleaseResponse(
                reservationID: fixture.reservationID,
                connectionEpoch: fixture.connectionEpoch,
                releaseChallenge: fixture.releaseChallenge
            ).phase == .releasedAwaitingReplyDispatch
        )
        let staleRelease = prepared.state.deadlineFired(
            releaseTicket,
            observation: try fixture.observation(
                monotonic: releaseTicket.deadlineNanoseconds,
                wallOffsetMicroseconds: 6_000_000
            )
        )
        #expect(staleRelease.disposition == .stale)
        #expect(prepared.state.phase == .releasedAwaitingReplyDispatch)
    }

    @Test
    func replyDispatchCannotCreateOrExtendAnExpiredExitDeadline() throws {
        let fixture = DeadlineStateFixture()
        let prepared = try fixture.releasedAwaitingReplyState()
        #expect(prepared.postReplyDeadline == 8_000_000_000)

        let expired = prepared.state.replyDidDispatch(
            reservationID: fixture.reservationID,
            connectionEpoch: fixture.connectionEpoch,
            observation: try fixture.observation(
                monotonic: prepared.postReplyDeadline,
                wallOffsetMicroseconds: 7_000_000
            )
        )
        #expect(
            expired.disposition
                == .terminal(.postReplyDeadlineExpiredBeforeDispatch)
        )
        #expect(expired.scheduledTicket == nil)

        let failed = try fixture.releasedAwaitingReplyState()
        let dispatchFailure = failed.state.replyDispatchFailed(
            reservationID: fixture.reservationID,
            connectionEpoch: fixture.connectionEpoch
        )
        #expect(dispatchFailure.disposition == .terminal(.replyDispatchFailed))
        #expect(dispatchFailure.scheduledTicket == nil)
    }

    @Test
    func cancellationAndMatchingInvalidationAreOneShotAndIdempotent() throws {
        let fixture = DeadlineStateFixture()
        let pending = LifecycleMachineRetirementEscrowDeadlineState()
        let pendingTicket = try #require(
            pending.reserve(try fixture.reservation()).scheduledTicket
        )
        #expect(
            pending.cancel(reservationID: fixture.reservationID)
                .cancelledTickets == [pendingTicket]
        )
        #expect(
            pending.cancel(reservationID: fixture.reservationID).disposition
                == .stale
        )

        let claimed = try fixture.claimedAwaitingReleaseState()
        let invalidated = claimed.state.invalidate(
            reservationID: fixture.reservationID,
            connectionEpoch: fixture.connectionEpoch
        )
        #expect(invalidated.disposition == .terminal(.connectionInvalidated))
        #expect(invalidated.cancelledTickets == [claimed.releaseTicket])
        #expect(
            claimed.state.invalidate(
                reservationID: fixture.reservationID,
                connectionEpoch: fixture.connectionEpoch
            ).disposition == .stale
        )
    }

    @Test
    func domainValuesRejectMalformedDigestsUUIDsAndObservations() {
        #expect(throws: (any Error).self) {
            _ = try LifecycleMachineRetirementDeadlineDigest(
                rawBytes: Data(repeating: 0, count: 31)
            )
        }
        #expect(throws: (any Error).self) {
            _ = try LifecycleMachineRetirementDeadlineObservation(
                monotonicNanoseconds: 0,
                wallUTCMicroseconds: 1
            )
        }
        #expect(
            !((LifecycleMachineRetirementEscrowDeadlineState.self as Any.Type)
                is any Codable.Type)
        )
    }
}

private struct DeadlineStateFixture {
    enum ReleaseDrift: CaseIterable {
        case helperDigest
        case connectionEpoch
        case releaseDeadline
    }

    let baseWall: Int64 = 2_000_000_000_000_000
    let baseMonotonic: UInt64 = 1_000_000_000
    let reservationID = UUID(
        uuidString: "11111111-1111-4111-8111-111111111111"
    )!
    let claimChallenge = UUID(
        uuidString: "22222222-2222-4222-8222-222222222222"
    )!
    let connectionEpoch = UUID(
        uuidString: "33333333-3333-4333-8333-333333333333"
    )!
    let releaseChallenge = UUID(
        uuidString: "44444444-4444-4444-8444-444444444444"
    )!
    let foreignUUID = UUID(
        uuidString: "55555555-5555-4555-8555-555555555555"
    )!
    let requestBinding = try! LifecycleMachineRetirementDeadlineDigest(
        rawBytes: Data(repeating: 0x31, count: 32)
    )
    let helperBinding = try! LifecycleMachineRetirementDeadlineDigest(
        rawBytes: Data(repeating: 0x42, count: 32)
    )
    let foreignDigest = try! LifecycleMachineRetirementDeadlineDigest(
        rawBytes: Data(repeating: 0x53, count: 32)
    )

    func observation(
        monotonic: UInt64,
        wallOffsetMicroseconds: Int64
    ) throws -> LifecycleMachineRetirementDeadlineObservation {
        try LifecycleMachineRetirementDeadlineObservation(
            monotonicNanoseconds: monotonic,
            wallUTCMicroseconds: baseWall + wallOffsetMicroseconds
        )
    }

    func reservation(
        monotonic: UInt64? = nil,
        wallOffsetMicroseconds: Int64 = 0,
        handleValidBeforeOffsetMicroseconds: Int64 = 30_000_000
    ) throws -> LifecycleMachineRetirementDeadlineReservation {
        try LifecycleMachineRetirementDeadlineReservation(
            reservationID: reservationID,
            handleValidBeforeUTCMicroseconds:
                baseWall + handleValidBeforeOffsetMicroseconds,
            observation: observation(
                monotonic: monotonic ?? baseMonotonic,
                wallOffsetMicroseconds: wallOffsetMicroseconds
            )
        )
    }

    func claim(
        requestIssuedAtOffsetMicroseconds: Int64 = 500_000,
        requestValidBeforeOffsetMicroseconds: Int64 = 10_000_000,
        epochDeadlineNanoseconds: UInt64 = 20_000_000_000,
        monotonic: UInt64 = 2_000_000_000,
        wallOffsetMicroseconds: Int64 = 1_000_000
    ) throws -> LifecycleMachineRetirementDeadlineClaim {
        try LifecycleMachineRetirementDeadlineClaim(
            reservationID: reservationID,
            requestBindingSHA256: requestBinding,
            helperIdentitySHA256: helperBinding,
            claimChallenge: claimChallenge,
            connectionEpoch: connectionEpoch,
            requestIssuedAtUTCMicroseconds:
                baseWall + requestIssuedAtOffsetMicroseconds,
            requestValidBeforeUTCMicroseconds:
                baseWall + requestValidBeforeOffsetMicroseconds,
            epochDeadlineNanoseconds: epochDeadlineNanoseconds,
            observation: observation(
                monotonic: monotonic,
                wallOffsetMicroseconds: wallOffsetMicroseconds
            )
        )
    }

    func release(
        deadlineNanoseconds: UInt64,
        monotonic: UInt64 = 3_000_000_000,
        wallOffsetMicroseconds: Int64 = 2_000_000,
        requestBinding: LifecycleMachineRetirementDeadlineDigest? = nil,
        releaseChallenge: UUID? = nil,
        drift: ReleaseDrift? = nil
    ) throws -> LifecycleMachineRetirementDeadlineRelease {
        try LifecycleMachineRetirementDeadlineRelease(
            reservationID: reservationID,
            requestBindingSHA256: requestBinding ?? self.requestBinding,
            helperIdentitySHA256:
                drift == .helperDigest ? foreignDigest : helperBinding,
            connectionEpoch:
                drift == .connectionEpoch ? foreignUUID : connectionEpoch,
            releaseChallenge: releaseChallenge ?? self.releaseChallenge,
            releaseDeadlineNanoseconds:
                drift == .releaseDeadline
                    ? deadlineNanoseconds + 1
                    : deadlineNanoseconds,
            observation: observation(
                monotonic: monotonic,
                wallOffsetMicroseconds: wallOffsetMicroseconds
            )
        )
    }

    func awaitingClaimState(
        handleValidBeforeOffsetMicroseconds: Int64 = 30_000_000,
        initialGeneration: UInt64 = 1
    ) throws -> (
        state: LifecycleMachineRetirementEscrowDeadlineState,
        claimTicket: LifecycleMachineRetirementDeadlineTicket
    ) {
        let state = LifecycleMachineRetirementEscrowDeadlineState(
            initialGeneration: initialGeneration
        )
        let ticket = try #require(
            state.reserve(
                try reservation(
                    handleValidBeforeOffsetMicroseconds:
                        handleValidBeforeOffsetMicroseconds
                )
            ).scheduledTicket
        )
        #expect(state.armSucceeded(ticket).phase == .awaitingClaim)
        return (state, ticket)
    }

    func claimedAwaitingReleaseState() throws -> (
        state: LifecycleMachineRetirementEscrowDeadlineState,
        releaseTicket: LifecycleMachineRetirementDeadlineTicket,
        releaseDeadline: UInt64
    ) {
        let prepared = try claimResponsePendingState()
        #expect(
            prepared.state.commitClaimResponse(
                reservationID: reservationID,
                connectionEpoch: connectionEpoch
            ).phase == .claimedAwaitingRelease
        )
        return (
            prepared.state, prepared.releaseTicket,
            prepared.releaseDeadline
        )
    }

    func claimResponsePendingState() throws -> (
        state: LifecycleMachineRetirementEscrowDeadlineState,
        releaseTicket: LifecycleMachineRetirementDeadlineTicket,
        releaseDeadline: UInt64
    ) {
        let prepared = try awaitingClaimState()
        let transition = prepared.state.claim(try claim())
        let ticket = try #require(transition.scheduledTicket)
        let deadline = try #require(transition.releaseDeadlineNanoseconds)
        #expect(
            prepared.state.armSucceeded(ticket).phase
                == .claimResponsePendingCommit
        )
        return (prepared.state, ticket, deadline)
    }

    func releasedAwaitingReplyState() throws -> (
        state: LifecycleMachineRetirementEscrowDeadlineState,
        postReplyDeadline: UInt64,
        releaseDeadline: UInt64
    ) {
        try releasedAwaitingReplyState(initialGeneration: 1)
    }

    func releasedAwaitingReplyState(
        initialGeneration: UInt64
    ) throws -> (
        state: LifecycleMachineRetirementEscrowDeadlineState,
        postReplyDeadline: UInt64,
        releaseDeadline: UInt64
    ) {
        let pending = try releaseResponsePendingState(
            initialGeneration: initialGeneration
        )
        #expect(
            pending.state.commitReleaseResponse(
                reservationID: reservationID,
                connectionEpoch: connectionEpoch,
                releaseChallenge: releaseChallenge
            ).phase == .releasedAwaitingReplyDispatch
        )
        return (
            pending.state, pending.postReplyDeadline,
            pending.releaseDeadline
        )
    }

    func releaseResponsePendingState(
        initialGeneration: UInt64 = 1
    ) throws -> (
        state: LifecycleMachineRetirementEscrowDeadlineState,
        releaseTicket: LifecycleMachineRetirementDeadlineTicket,
        postReplyDeadline: UInt64,
        releaseDeadline: UInt64
    ) {
        let awaiting = try awaitingClaimState(
            initialGeneration: initialGeneration
        )
        let claimTransition = awaiting.state.claim(try claim())
        let releaseTicket = try #require(claimTransition.scheduledTicket)
        let releaseDeadline = try #require(
            claimTransition.releaseDeadlineNanoseconds
        )
        #expect(
            awaiting.state.armSucceeded(releaseTicket).phase
                == .claimResponsePendingCommit
        )
        #expect(
            awaiting.state.commitClaimResponse(
                reservationID: reservationID,
                connectionEpoch: connectionEpoch
            ).phase == .claimedAwaitingRelease
        )
        let transition = awaiting.state.release(
            try release(deadlineNanoseconds: releaseDeadline)
        )
        let deadline = try #require(
            transition.postReplyExitDeadlineNanoseconds
        )
        #expect(transition.phase == .releaseResponsePendingCommit)
        return (awaiting.state, releaseTicket, deadline, releaseDeadline)
    }

    func exitPendingState() throws -> (
        state: LifecycleMachineRetirementEscrowDeadlineState,
        exitTicket: LifecycleMachineRetirementDeadlineTicket
    ) {
        let released = try releasedAwaitingReplyState()
        let transition = released.state.replyDidDispatch(
            reservationID: reservationID,
            connectionEpoch: connectionEpoch,
            observation: try observation(
                monotonic: 3_500_000_000,
                wallOffsetMicroseconds: 2_500_000
            )
        )
        return (released.state, try #require(transition.scheduledTicket))
    }

    func exitScheduledState() throws -> (
        state: LifecycleMachineRetirementEscrowDeadlineState,
        exitTicket: LifecycleMachineRetirementDeadlineTicket
    ) {
        let pending = try exitPendingState()
        #expect(
            pending.state.armSucceeded(pending.exitTicket).phase
                == .releasedExitScheduled
        )
        return pending
    }

}

private extension LifecycleMachineRetirementDeadlineTransition {
    var scheduledTicket: LifecycleMachineRetirementDeadlineTicket? {
        effects.compactMap { effect
            -> LifecycleMachineRetirementDeadlineTicket? in
            guard case let .schedule(ticket) = effect else { return nil }
            return ticket
        }.first
    }

    var cancelledTickets: [LifecycleMachineRetirementDeadlineTicket] {
        effects.compactMap { effect
            -> LifecycleMachineRetirementDeadlineTicket? in
            guard case let .cancel(ticket) = effect else { return nil }
            return ticket
        }
    }
}
