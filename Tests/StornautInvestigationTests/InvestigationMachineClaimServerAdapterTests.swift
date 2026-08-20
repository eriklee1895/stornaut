import CryptoKit
import Dispatch
import Foundation
import Testing
@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationMachineClaimServer
@testable import StornautLifecycle

@Suite("Investigation Machine claim server adapter")
struct InvestigationMachineClaimServerAdapterTests {
    @Test
    func publicFacadeExposesOnlyClosedScalarDataAndLifecycleSurfaces() throws {
        let root = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let adapter = try String(
            contentsOf: root.appending(
                path: "Sources/StornautInvestigationMachineClaimServer/InvestigationMachineClaimServerAdapter.swift"
            ),
            encoding: .utf8
        )
        let effects = try String(
            contentsOf: root.appending(
                path: "Sources/StornautInvestigationMachineClaimServer/InvestigationMachineClaimServerEffects.swift"
            ),
            encoding: .utf8
        )
        for marker in [
            "public final class InvestigationMachineClaimServer:",
            "public final class InvestigationMachineClaimServerSession:",
            "public func activate() throws",
            "public func makeSession() throws",
            "public func isPending() -> Bool",
            "InvestigationMachineClaimXPCWire",
        ] {
            #expect(adapter.contains(marker))
        }
        for marker in [
            "public struct InvestigationMachineClaimServerObservation:",
            "public struct InvestigationMachineClaimServerDeadline:",
            "public protocol InvestigationMachineClaimServerClock:",
            "public protocol InvestigationMachineClaimServerScheduling:",
            "public protocol InvestigationMachineClaimServerScheduledHandle:",
            "public protocol InvestigationMachineClaimServerTerminalHandling:",
            "public enum InvestigationMachineClaimServerTerminalReason:",
        ] {
            #expect(effects.contains(marker))
        }
        let publicSurface = (adapter + "\n" + effects)
            .split(separator: "\n")
            .filter { $0.contains("public " ) }
            .joined(separator: "\n")
        for forbidden in [
            "LifecycleMachineRetirementReservationTransfer",
            "LifecycleMachineRetirementDeadlineTicket",
            "LifecycleMachineRetirementDeadlineObservation",
            "LifecycleMachineRetirementDeadlineTerminalReason",
            "tokenSHA256", "authorization", "executable", "signal",
            "Cleanup", "Policy", "Executor",
        ] {
            #expect(!publicSurface.contains(forbidden))
        }
    }

    @Test
    func publicSessionOwnsActivationConnectionAndReplyCommitOrdering() throws {
        let root = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appending(
                path: "Sources/StornautInvestigationMachineClaimServer/InvestigationMachineClaimServerAdapter.swift"
            ),
            encoding: .utf8
        )
        #expect(source.contains("retirementEscrow.transferReservation()"))
        #expect(source.contains("func claimMachineRetirement("))
        #expect(source.contains("func releaseMachineRetirement("))
        #expect(source.contains("adapter.invalidate()"))
        #expect(source.contains("adapter.cancel()"))
        #expect(source.contains("guard !invalidated else"))
        #expect(source.contains("guard activeSession == nil else"))
        let releaseStart = try #require(
            source.range(of: "func releaseMachineRetirement(")
        )
        let releaseSuffix = source[releaseStart.lowerBound...]
        let reply = try #require(releaseSuffix.range(of: "reply(data, nil)"))
        let commit = try #require(
            releaseSuffix.range(of: "adapter.replyDidDispatch()")
        )
        #expect(reply.lowerBound < commit.lowerBound)
        let afterReply = String(releaseSuffix[reply.lowerBound...])
        #expect(afterReply.components(separatedBy: "reply(").count == 2)
    }

    @Test
    func publicServerTransfersOneLifecycleReservationAndIssuesOneSession()
        throws
    {
        let fixture = ClaimServerFixture()
        let escrow = try fixture.recordedEscrow()
        let clock = PublicClaimServerClock([
            try fixture.publicObservation(
                monotonic: 1_000_000_000, wallOffset: 0
            ),
        ])
        let scheduler = PublicClaimServerScheduler()
        let terminal = PublicClaimServerTerminal()
        let server = InvestigationMachineClaimServer(
            retirementEscrow: escrow,
            clock: clock, scheduler: scheduler, terminal: terminal
        )

        #expect(server.isPending())
        try server.activate()
        #expect(server.isPending())
        let session = try server.makeSession()
        #expect(throws: Error.self) { _ = try server.makeSession() }
        #expect(throws: Error.self) { try server.activate() }

        session.invalidate()
        session.invalidate()
        #expect(!server.isPending())
        #expect(terminal.reasons == [.cancelled])
        #expect(scheduler.handles.count == 1)
        #expect(scheduler.handles[0].cancelCount == 1)
    }

    @Test
    func publicReleaseRepliesOnceBeforePostReplyArmFailure() throws {
        let fixture = ClaimServerFixture()
        let clock = PublicClaimServerClock([
            try fixture.publicObservation(
                monotonic: 1_000_000_000, wallOffset: 0
            ),
            try fixture.publicObservation(
                monotonic: 2_000_000_000, wallOffset: 1_000_000
            ),
            try fixture.publicObservation(
                monotonic: 3_000_000_000, wallOffset: 2_000_000
            ),
            try fixture.publicObservation(
                monotonic: 3_500_000_000, wallOffset: 2_500_000
            ),
        ])
        let scheduler = PublicClaimServerScheduler(failOnSchedule: 3)
        let terminal = PublicClaimServerTerminal()
        let server = InvestigationMachineClaimServer(
            retirementEscrow: try fixture.recordedEscrow(),
            clock: clock, scheduler: scheduler, terminal: terminal
        )
        try server.activate()
        let session = try server.makeSession()

        let claimReply = PublicClaimServerReplyRecorder()
        session.claimMachineRetirement(
            try fixture.request().encoded(),
            withReply: claimReply.call
        )
        let claimData = try #require(claimReply.values.first?.0)
        let evidence = try InvestigationMachineClaimEvidence.decode(claimData)
        let releaseReply = PublicClaimServerReplyRecorder()

        session.releaseMachineRetirement(
            try fixture.release(evidence: evidence).encoded(),
            withReply: releaseReply.call
        )

        #expect(releaseReply.values.count == 1)
        #expect(releaseReply.values[0].0 != nil)
        #expect(releaseReply.values[0].1 == nil)
        #expect(terminal.reasons == [.deadlineArmFailure])
        #expect(!server.isPending())
    }

    @Test
    func cancelledActivationNeverPublishesAClaimSession() async throws {
        let fixture = ClaimServerFixture()
        let clock = BlockingPublicClaimServerClock(
            try fixture.publicObservation(
                monotonic: 1_000_000_000, wallOffset: 0
            )
        )
        let scheduler = PublicClaimServerScheduler()
        let terminal = PublicClaimServerTerminal()
        let server = InvestigationMachineClaimServer(
            retirementEscrow: try fixture.recordedEscrow(),
            clock: clock, scheduler: scheduler, terminal: terminal
        )
        let activation = Task.detached {
            do {
                try server.activate()
                return true
            } catch {
                return false
            }
        }
        #expect(clock.waitUntilObservationEntered())

        server.cancel()
        #expect(throws: Error.self) { _ = try server.makeSession() }
        clock.allowObservationToReturn()
        #expect(!(await activation.value))

        #expect(throws: Error.self) { _ = try server.makeSession() }
        #expect(!server.isPending())
        #expect(terminal.reasons == [.cancelled])
    }

    @Test
    func claimReplyWinsBeforeReentrantSessionInvalidation() throws {
        let fixture = ClaimServerFixture()
        let events = PublicClaimServerEventLog()
        let terminal = PublicClaimServerTerminal { _ in
            events.append("terminal")
        }
        let server = InvestigationMachineClaimServer(
            retirementEscrow: try fixture.recordedEscrow(),
            clock: PublicClaimServerClock([
                try fixture.publicObservation(
                    monotonic: 1_000_000_000, wallOffset: 0
                ),
                try fixture.publicObservation(
                    monotonic: 2_000_000_000, wallOffset: 1_000_000
                ),
            ]),
            scheduler: PublicClaimServerScheduler(),
            terminal: terminal
        )
        try server.activate()
        let session = try server.makeSession()

        session.claimMachineRetirement(
            try fixture.request().encoded()
        ) { data, reason in
            session.invalidate()
            #expect(data != nil)
            #expect(reason == nil)
            events.append("reply")
        }

        #expect(events.values == ["reply", "terminal"])
        #expect(terminal.reasons == [.connectionInvalidated])
    }

    @Test
    func releaseReplyArmsExitBeforeReentrantSessionInvalidation() throws {
        let fixture = ClaimServerFixture()
        let events = PublicClaimServerEventLog()
        let scheduler = PublicClaimServerScheduler()
        let terminal = PublicClaimServerTerminal { _ in
            events.append("terminal")
        }
        let server = InvestigationMachineClaimServer(
            retirementEscrow: try fixture.recordedEscrow(),
            clock: PublicClaimServerClock([
                try fixture.publicObservation(
                    monotonic: 1_000_000_000, wallOffset: 0
                ),
                try fixture.publicObservation(
                    monotonic: 2_000_000_000, wallOffset: 1_000_000
                ),
                try fixture.publicObservation(
                    monotonic: 3_000_000_000, wallOffset: 2_000_000
                ),
                try fixture.publicObservation(
                    monotonic: 3_500_000_000, wallOffset: 2_500_000
                ),
            ]),
            scheduler: scheduler,
            terminal: terminal
        )
        try server.activate()
        let session = try server.makeSession()
        let claimReply = PublicClaimServerReplyRecorder()
        session.claimMachineRetirement(
            try fixture.request().encoded(),
            withReply: claimReply.call
        )
        let evidence = try InvestigationMachineClaimEvidence.decode(
            try #require(claimReply.values.first?.0)
        )

        session.releaseMachineRetirement(
            try fixture.release(evidence: evidence).encoded()
        ) { data, reason in
            session.invalidate()
            #expect(data != nil)
            #expect(reason == nil)
            events.append("reply")
        }

        #expect(events.values == ["reply", "terminal"])
        #expect(terminal.reasons == [.connectionInvalidated])
        #expect(scheduler.totalScheduleCount == 3)
        #expect(!server.isPending())
    }

    @Test
    func claimAndReleaseTranslateToExactHandleFreeBytes() async throws {
        let fixture = ClaimServerFixture()
        let runtime = try fixture.runtime()

        let evidenceData = try runtime.adapter.claim(
            try fixture.request().encoded()
        )
        let evidence = try InvestigationMachineClaimEvidence.decode(evidenceData)
        let expectedEvidenceData = try fixture.expectedEvidence().encoded()
        let expectedRequestDigest = try fixture.request().bindingSHA256()
        let expectedHelper = try fixture.handoffIdentity(role: .helper)
        #expect(evidenceData == expectedEvidenceData)
        #expect(evidence.requestBindingSHA256 == expectedRequestDigest)
        #expect(evidence.helperIdentity == expectedHelper)
        #expect(evidence.l1Residue.auditSessionID == fixture.helperASID)
        #expect(!evidenceData.containsSubsequence(fixture.uuidBytes(fixture.token)))
        #expect(runtime.scheduler.liveKinds == [.release])
        #expect(runtime.state.phase == .claimedAwaitingRelease)

        let releasedData = try runtime.adapter.release(
            try fixture.release(evidence: evidence).encoded()
        )
        let expectedReleasedData = try fixture.expectedReleased().encoded()
        #expect(releasedData == expectedReleasedData)
        #expect(runtime.scheduler.liveKinds.isEmpty)
        #expect(runtime.state.phase == .releasedAwaitingReplyDispatch)
        #expect(!releasedData.containsSubsequence(fixture.uuidBytes(fixture.token)))

        runtime.clock.append(
            try fixture.observation(
                monotonic: 3_500_000_000,
                wallOffset: 2_500_000
            )
        )
        try runtime.adapter.replyDidDispatch()
        #expect(runtime.scheduler.liveKinds == [.postReplyExit])
        #expect(runtime.state.phase == .releasedExitScheduled)
        #expect(runtime.terminal.reasons.isEmpty)
    }

    @Test
    func serverConsumesTheCanonicalTransferMicrosecondsWithoutReprojection()
        throws
    {
        let canonicalValidBefore: Int64 = 1_098_290_087_000_249
        let lossyDate = Date(
            timeIntervalSince1970:
                TimeInterval(canonicalValidBefore) / 1_000_000
        )
        let reprojected = Int64(
            (lossyDate.timeIntervalSince1970 * 1_000_000).rounded(.down)
        )
        #expect(reprojected == canonicalValidBefore - 1)
        let fixture = ClaimServerFixture(
            baseWall: canonicalValidBefore - 30_000_000
        )
        let transfer = try fixture.transfer(
            validBeforeUTCMicroseconds: canonicalValidBefore,
            recordedAtUTCMicroseconds: fixture.baseWall + 500_000,
            ownerRetirementObservation: .retiredOwnedResources,
            residueObservation: fixture.residueObservation()
        )
        let runtime = try fixture.runtime(transfer: transfer)
        let request = try fixture.request(
            handleValidBeforeUTCMicroseconds: canonicalValidBefore
        )

        _ = try runtime.adapter.claim(try request.encoded())

        #expect(runtime.state.phase == .claimedAwaitingRelease)
    }

    @Test
    func helperAndRequestDigestsAreIndependentlyRecomputed() async throws {
        let fixture = ClaimServerFixture()
        let runtime = try fixture.runtime()
        let request = try fixture.request()
        let evidence = try InvestigationMachineClaimEvidence.decode(
            try runtime.adapter.claim(try request.encoded())
        )

        let expectedRequestDigest = try request.bindingSHA256()
        let expectedHelperDigest = try fixture.handoffIdentity(role: .helper)
            .helperIdentitySHA256()
        #expect(evidence.requestBindingSHA256 == expectedRequestDigest)
        #expect(
            try evidence.helperIdentity.helperIdentitySHA256()
                == expectedHelperDigest
        )

        let wrongToken = try fixture.request(token: fixture.foreignUUID)
        let rejected = try fixture.runtime()
        let wrongTokenResult = await claimCallResult(
            adapter: rejected.adapter, requestData: try wrongToken.encoded()
        )
        #expect(wrongTokenResult == .failure(.bindingMismatch))
        #expect(rejected.state.phase == .terminal(.bindingMismatch))
        #expect(rejected.scheduler.scheduleCount == 1)
    }

    @Test
    func malformedAndLegacyJSONFailBeforeClaimStateConsumption() async throws {
        let fixture = ClaimServerFixture()
        for input in [
            Data(),
            Data("{\"protocolVersion\":2}".utf8),
            Data([0x53, 0x54, 0x4e, 0x43]),
            try fixture.request().encoded() + Data([0]),
        ] {
            let runtime = try fixture.runtime()
            let result = await claimCallResult(
                adapter: runtime.adapter, requestData: input
            )
            #expect(result == .failure(.invalidRequest))
            #expect(runtime.state.phase == .awaitingClaim)
            #expect(runtime.scheduler.liveKinds == [.claim])
        }
    }

    @Test
    func replayAndEveryReleaseBindingDriftAreTerminal() async throws {
        let fixture = ClaimServerFixture()
        let replay = try fixture.runtime()
        let requestData = try fixture.request().encoded()
        _ = try replay.adapter.claim(requestData)
        let replayResult = await claimCallResult(
            adapter: replay.adapter, requestData: requestData
        )
        #expect(replayResult == .failure(.duplicateOrReplay))
        #expect(replay.state.phase == .terminal(.duplicateOrReplay))

        for drift in ClaimServerFixture.ReleaseDrift.allCases {
            let runtime = try fixture.runtime()
            let evidence = try InvestigationMachineClaimEvidence.decode(
                try runtime.adapter.claim(try fixture.request().encoded())
            )
            let releaseData = try fixture.release(
                evidence: evidence, drift: drift
            ).encoded()
            let result = await releaseCallResult(
                adapter: runtime.adapter, releaseData: releaseData
            )
            #expect(result == .failure(.bindingMismatch))
            #expect(runtime.state.phase == .terminal(.bindingMismatch))
        }
    }

    @Test
    func releaseReplyCannotArmExitBeforeDispatchCommitment() async throws {
        let fixture = ClaimServerFixture()
        let runtime = try fixture.runtime()
        let evidence = try InvestigationMachineClaimEvidence.decode(
            try runtime.adapter.claim(try fixture.request().encoded())
        )
        _ = try runtime.adapter.release(
            try fixture.release(evidence: evidence).encoded()
        )

        #expect(runtime.scheduler.liveKinds.isEmpty)
        #expect(runtime.state.phase == .releasedAwaitingReplyDispatch)
        runtime.clock.append(
            try fixture.observation(
                monotonic: 3_500_000_000,
                wallOffset: 2_500_000
            )
        )
        try runtime.adapter.replyDidDispatch()
        #expect(runtime.scheduler.liveKinds == [.postReplyExit])
        #expect(runtime.scheduler.lastDeadline == fixture.postReplyDeadline)
    }

    @Test
    func callbackBeforeHandleReturnCancelsTheLatePhysicalHandle() throws {
        let fixture = ClaimServerFixture()
        let state = LifecycleMachineRetirementEscrowDeadlineState()
        let clock = SequenceClaimServerClock([
            try fixture.observation(
                monotonic: fixture.handleMonotonicDeadline
            ),
        ])
        let scheduler = RecordingClaimServerScheduler(mode: .fireBeforeReturn)
        let terminal = RecordingClaimServerTerminal()
        let executor = InvestigationMachineClaimServerEffectExecutor(
            clock: clock,
            scheduler: scheduler,
            terminal: terminal
        )
        let transition = state.reserve(try fixture.semanticReservation())

        try executor.apply(transition, to: state)

        #expect(state.phase == .terminal(.claimDeadlineExpired))
        #expect(scheduler.handles.count == 1)
        #expect(scheduler.handles[0].cancelCount == 1)
        #expect(terminal.reasons == [.claimDeadlineExpired])
        #expect(executor.pendingSlotCount == 0)
    }

    @Test
    func schedulerFailureAndStaleCallbacksRemainOneShot() async throws {
        let fixture = ClaimServerFixture()
        let failedState = LifecycleMachineRetirementEscrowDeadlineState()
        let failedTerminal = RecordingClaimServerTerminal()
        let failed = InvestigationMachineClaimServerEffectExecutor(
            clock: SequenceClaimServerClock([]),
            scheduler: RecordingClaimServerScheduler(mode: .fail),
            terminal: failedTerminal
        )
        #expect(throws: InvestigationMachineClaimServerEffectError.self) {
            try failed.apply(
                failedState.reserve(try fixture.semanticReservation()),
                to: failedState
            )
        }
        #expect(failedState.phase == .terminal(.deadlineArmFailure))
        #expect(failedTerminal.reasons == [.deadlineArmFailure])

        let runtime = try fixture.runtime()
        let claimCallback = try #require(runtime.scheduler.callback(for: .claim))
        _ = try runtime.adapter.claim(try fixture.request().encoded())
        runtime.clock.append(
            try fixture.observation(monotonic: fixture.handleMonotonicDeadline)
        )
        claimCallback()
        #expect(runtime.state.phase == .claimedAwaitingRelease)
        #expect(runtime.terminal.reasons.isEmpty)
    }

    @Test
    func operationClockFailuresTerminalizeTheExactLiveReservation() async throws {
        let fixture = ClaimServerFixture()

        let claimFailure = try fixture.runtime(observations: [
            try fixture.observation(monotonic: 1_000_000_000),
        ])
        do {
            _ = try claimFailure.adapter.claim(
                try fixture.request().encoded()
            )
            Issue.record("claim unexpectedly succeeded without an observation")
        } catch {
            #expect(
                error as? InvestigationMachineClaimServerError == .unavailable
            )
        }
        #expect(
            claimFailure.state.phase == .terminal(.invalidTimeObservation)
        )
        #expect(claimFailure.terminal.reasons == [.invalidTimeObservation])
        #expect(claimFailure.executor.pendingSlotCount == 0)
        do {
            _ = try claimFailure.adapter.claim(
                try fixture.request().encoded()
            )
            Issue.record("claim clock failure remained retryable")
        } catch {
            #expect(error is InvestigationMachineClaimServerError)
        }

        let releaseFailure = try fixture.runtime(observations: [
            try fixture.observation(monotonic: 1_000_000_000),
            try fixture.observation(
                monotonic: 2_000_000_000, wallOffset: 1_000_000
            ),
        ])
        let releaseEvidence = try InvestigationMachineClaimEvidence.decode(
            try releaseFailure.adapter.claim(try fixture.request().encoded())
        )
        do {
            _ = try releaseFailure.adapter.release(
                try fixture.release(evidence: releaseEvidence).encoded()
            )
            Issue.record("release unexpectedly succeeded without an observation")
        } catch {
            #expect(
                error as? InvestigationMachineClaimServerError == .unavailable
            )
        }
        #expect(
            releaseFailure.state.phase == .terminal(.invalidTimeObservation)
        )
        #expect(releaseFailure.terminal.reasons == [.invalidTimeObservation])
        #expect(releaseFailure.executor.pendingSlotCount == 0)

        let replyFailure = try fixture.runtime(observations: [
            try fixture.observation(monotonic: 1_000_000_000),
            try fixture.observation(
                monotonic: 2_000_000_000, wallOffset: 1_000_000
            ),
            try fixture.observation(
                monotonic: 3_000_000_000, wallOffset: 2_000_000
            ),
        ])
        let replyEvidence = try InvestigationMachineClaimEvidence.decode(
            try replyFailure.adapter.claim(try fixture.request().encoded())
        )
        _ = try replyFailure.adapter.release(
            try fixture.release(evidence: replyEvidence).encoded()
        )
        do {
            try replyFailure.adapter.replyDidDispatch()
            Issue.record("reply dispatch unexpectedly succeeded without an observation")
        } catch {
            #expect(
                error as? InvestigationMachineClaimServerError == .unavailable
            )
        }
        #expect(replyFailure.state.phase == .terminal(.invalidTimeObservation))
        #expect(replyFailure.terminal.reasons == [.invalidTimeObservation])
        #expect(replyFailure.executor.pendingSlotCount == 0)
    }

    @Test
    func normalArmedDeadlineCompletionRemovesItsCancellationSlot() throws {
        let fixture = ClaimServerFixture()
        let state = LifecycleMachineRetirementEscrowDeadlineState()
        let clock = SequenceClaimServerClock([
            try fixture.observation(
                monotonic: fixture.handleMonotonicDeadline
            ),
        ])
        let scheduler = RecordingClaimServerScheduler(mode: .manual)
        let terminal = RecordingClaimServerTerminal()
        let executor = InvestigationMachineClaimServerEffectExecutor(
            clock: clock, scheduler: scheduler, terminal: terminal
        )
        try executor.apply(
            state.reserve(try fixture.semanticReservation()),
            to: state
        )
        #expect(executor.pendingSlotCount == 1)

        let callback = try #require(scheduler.callback(for: .claim))
        callback()

        #expect(state.phase == .terminal(.claimDeadlineExpired))
        #expect(terminal.reasons == [.claimDeadlineExpired])
        #expect(executor.pendingSlotCount == 0)
    }

    @Test
    func concurrentClaimsInterleaveOnlyAsFailClosedStateTransitions() async throws {
        let fixture = ClaimServerFixture()
        let clock = CountingClaimServerClock([
            try fixture.observation(monotonic: 1_000_000_000),
            try fixture.observation(
                monotonic: 2_000_000_000, wallOffset: 1_000_000
            ),
            try fixture.observation(
                monotonic: 2_100_000_000, wallOffset: 1_100_000
            ),
        ])
        let scheduler = BlockingReleaseClaimServerScheduler()
        let terminal = RecordingClaimServerTerminal()
        let state = LifecycleMachineRetirementEscrowDeadlineState()
        let executor = InvestigationMachineClaimServerEffectExecutor(
            clock: clock, scheduler: scheduler, terminal: terminal
        )
        let adapter = try InvestigationMachineClaimServerAdapter(
            transfer: fixture.transfer(),
            clock: clock, state: state, executor: executor
        )
        let requestData = try fixture.request().encoded()

        let first = Task.detached {
            await claimCallResult(adapter: adapter, requestData: requestData)
        }
        #expect(scheduler.waitUntilReleaseScheduleEntered())
        let secondGate = ClaimServerStartGate()
        let second = Task.detached {
            secondGate.signal()
            return await claimCallResult(
                adapter: adapter, requestData: requestData
            )
        }
        #expect(secondGate.waitUntilSignalled())

        let crossedFormerActorBoundary =
            clock.waitUntilThirdObservation(timeout: .now() + 1)
        #expect(crossedFormerActorBoundary)
        scheduler.allowReleaseScheduleToReturn()

        let firstResult = await first.value
        let secondResult = await second.value
        #expect(firstResult == .failure(.duplicateOrReplay))
        #expect(secondResult == .failure(.duplicateOrReplay))
        #expect(state.phase == .terminal(.duplicateOrReplay))
        #expect(terminal.reasons == [.duplicateOrReplay])
        #expect(executor.pendingSlotCount == 0)
    }

    @Test
    func transferRejectsUnprovedRetirementResidueAndIdentityFacts() throws {
        let fixture = ClaimServerFixture()
        for owner in [
            LifecycleInteractiveWorkerRetirementObservation.noOwnedResources,
            .retiredPreparedWorkspace,
        ] {
            #expect(throws: InvestigationMachineClaimServerError.invalidRequest) {
                _ = try fixture.runtime(transfer: fixture.transfer(
                    ownerRetirementObservation: owner,
                    residueObservation: fixture.residueObservation()
                ))
            }
        }

        let nonemptyResidues = [
            try fixture.residueObservation(remainingMembers: 1),
            try fixture.residueObservation(
                matchingLeases: 1, leaseRootEntries: 1
            ),
            try fixture.residueObservation(leaseRootEntries: 1),
            try fixture.residueObservation(investigationArtifacts: 1),
        ]
        for residue in nonemptyResidues {
            #expect(throws: InvestigationMachineClaimServerError.invalidRequest) {
                _ = try fixture.runtime(transfer: fixture.transfer(
                    ownerRetirementObservation: .retiredOwnedResources,
                    residueObservation: residue
                ))
            }
        }

        let identityDrifts = [
            try fixture.residueObservation(
                investigation: fixture.foreignUUID
            ),
            try fixture.residueObservation(
                auditSessionID: Int32(fixture.helperASID + 1)
            ),
            try fixture.residueObservation(userID: 502),
        ]
        for residue in identityDrifts {
            #expect(throws: InvestigationMachineClaimServerError.invalidRequest) {
                _ = try fixture.runtime(transfer: fixture.transfer(
                    ownerRetirementObservation: .retiredOwnedResources,
                    residueObservation: residue
                ))
            }
        }
    }

    @Test
    func transferPreservesCheckedResidueTimeAndSixtySecondFreshness() async throws {
        let fixture = ClaimServerFixture()
        let exactBoundary = Date(
            timeIntervalSince1970: TimeInterval(
                fixture.baseWall + 500_000 - 60_000_000
            ) / 1_000_000
        )
        _ = try fixture.runtime(transfer: fixture.transfer(
            ownerRetirementObservation: .retiredOwnedResources,
            residueObservation: fixture.residueObservation(
                observedAt: exactBoundary
            )
        ))

        for observedAt in [
            Date(
                timeIntervalSince1970: TimeInterval(
                    fixture.baseWall + 500_001
                ) / 1_000_000
            ),
            Date(
                timeIntervalSince1970: TimeInterval(
                    fixture.baseWall + 500_000 - 60_000_010
                ) / 1_000_000
            ),
        ] {
            #expect(throws: InvestigationMachineClaimServerError.invalidRequest) {
                _ = try fixture.runtime(transfer: fixture.transfer(
                    ownerRetirementObservation: .retiredOwnedResources,
                    residueObservation: fixture.residueObservation(
                        observedAt: observedAt
                    )
                ))
            }
        }

        let fractionalInterval =
            TimeInterval(fixture.baseWall) / 1_000_000 + 0.400_000_75
        let fractionalDate = Date(timeIntervalSince1970: fractionalInterval)
        let runtime = try fixture.runtime(transfer: fixture.transfer(
            ownerRetirementObservation: .retiredOwnedResources,
            residueObservation: fixture.residueObservation(
                observedAt: fractionalDate
            )
        ))
        let evidence = try InvestigationMachineClaimEvidence.decode(
            try runtime.adapter.claim(try fixture.request().encoded())
        )
        let expected = try InvestigationHandoffUTCMicroseconds(
            timeIntervalSince1970: fractionalDate.timeIntervalSince1970
        )
        #expect(evidence.l1Residue.observedAt == expected)
    }

    @Test
    func everyRetainedUUIDIsRejectedAsAReleaseChallenge() async throws {
        let fixture = ClaimServerFixture()
        for challenge in [
            fixture.claimChallenge,
            fixture.connectionEpoch,
            fixture.reservationID,
        ] {
            let runtime = try fixture.runtime()
            let evidence = try InvestigationMachineClaimEvidence.decode(
                try runtime.adapter.claim(try fixture.request().encoded())
            )
            let releaseData = try fixture.release(
                evidence: evidence, releaseChallenge: challenge
            ).encoded()
            let result = await releaseCallResult(
                adapter: runtime.adapter, releaseData: releaseData
            )
            #expect(result == .failure(.bindingMismatch))
            #expect(runtime.state.phase == .terminal(.bindingMismatch))
        }
    }

    @Test
    func callbackClockFailureAndStaleReplacementCleanOnlyTheirOwnSlots() async throws {
        let fixture = ClaimServerFixture()
        let armedState = LifecycleMachineRetirementEscrowDeadlineState()
        let armedScheduler = RecordingClaimServerScheduler(mode: .manual)
        let armedTerminal = RecordingClaimServerTerminal()
        let armedExecutor = InvestigationMachineClaimServerEffectExecutor(
            clock: SequenceClaimServerClock([]),
            scheduler: armedScheduler,
            terminal: armedTerminal
        )
        try armedExecutor.apply(
            armedState.reserve(try fixture.semanticReservation()),
            to: armedState
        )
        let armedCallback = try #require(
            armedScheduler.callback(for: .claim)
        )
        armedCallback()
        #expect(armedState.phase == .terminal(.invalidTimeObservation))
        #expect(armedScheduler.handles[0].cancelCount == 1)
        #expect(armedTerminal.reasons == [.invalidTimeObservation])
        #expect(armedExecutor.pendingSlotCount == 0)

        let pendingState = LifecycleMachineRetirementEscrowDeadlineState()
        let pendingScheduler = RecordingClaimServerScheduler(
            mode: .fireBeforeReturn
        )
        let pendingTerminal = RecordingClaimServerTerminal()
        let pendingExecutor = InvestigationMachineClaimServerEffectExecutor(
            clock: SequenceClaimServerClock([]),
            scheduler: pendingScheduler,
            terminal: pendingTerminal
        )
        try pendingExecutor.apply(
            pendingState.reserve(try fixture.semanticReservation()),
            to: pendingState
        )
        #expect(pendingState.phase == .terminal(.invalidTimeObservation))
        #expect(pendingScheduler.handles[0].cancelCount == 1)
        #expect(pendingTerminal.reasons == [.invalidTimeObservation])
        #expect(pendingExecutor.pendingSlotCount == 0)

        let runtime = try fixture.runtime()
        let staleClaimCallback = try #require(
            runtime.scheduler.callback(for: .claim)
        )
        _ = try runtime.adapter.claim(try fixture.request().encoded())
        #expect(runtime.executor.pendingSlotCount == 1)
        staleClaimCallback()
        #expect(runtime.state.phase == .claimedAwaitingRelease)
        #expect(runtime.terminal.reasons.isEmpty)
        #expect(runtime.executor.pendingSlotCount == 1)
        #expect(runtime.scheduler.liveKinds == [.release])
    }

    @Test
    func concurrentClaimAndReleaseFailClosedBeforeClaimResponseCommit() async throws {
        let fixture = ClaimServerFixture()
        let clock = CountingClaimServerClock([
            try fixture.observation(monotonic: 1_000_000_000),
            try fixture.observation(
                monotonic: 2_000_000_000, wallOffset: 1_000_000
            ),
            try fixture.observation(
                monotonic: 3_000_000_000, wallOffset: 2_000_000
            ),
        ])
        let scheduler = BlockingReleaseClaimServerScheduler()
        let terminal = RecordingClaimServerTerminal()
        let state = LifecycleMachineRetirementEscrowDeadlineState()
        let executor = InvestigationMachineClaimServerEffectExecutor(
            clock: clock, scheduler: scheduler, terminal: terminal
        )
        let adapter = try InvestigationMachineClaimServerAdapter(
            transfer: fixture.transfer(),
            clock: clock, state: state, executor: executor
        )
        let requestData = try fixture.request().encoded()
        let releaseData = try fixture.release(
            evidence: fixture.expectedEvidence()
        ).encoded()

        let claimTask = Task.detached {
            await claimCallResult(adapter: adapter, requestData: requestData)
        }
        #expect(scheduler.waitUntilReleaseScheduleEntered())
        let releaseGate = ClaimServerStartGate()
        let releaseTask = Task.detached {
            releaseGate.signal()
            return await releaseCallResult(
                adapter: adapter, releaseData: releaseData
            )
        }
        #expect(releaseGate.waitUntilSignalled())
        scheduler.allowReleaseScheduleToReturn()

        #expect(await claimTask.value == .failure(.bindingMismatch))
        #expect(await releaseTask.value == .failure(.bindingMismatch))
        #expect(state.phase == .terminal(.bindingMismatch))
        #expect(terminal.reasons == [.bindingMismatch])
        #expect(executor.pendingSlotCount == 0)
    }

    @Test
    func concurrentReleaseAndReplyFailClosedBeforeReleaseResponseCommit() async throws {
        let fixture = ClaimServerFixture()
        let clock = BlockingObservationClaimServerClock(
            values: [
                try fixture.observation(monotonic: 1_000_000_000),
                try fixture.observation(
                    monotonic: 2_000_000_000, wallOffset: 1_000_000
                ),
                try fixture.observation(
                    monotonic: 3_000_000_000, wallOffset: 2_000_000
                ),
                try fixture.observation(
                    monotonic: 3_500_000_000, wallOffset: 2_500_000
                ),
            ],
            blockedObservation: 3
        )
        let scheduler = RecordingClaimServerScheduler(mode: .manual)
        let terminal = RecordingClaimServerTerminal()
        let state = LifecycleMachineRetirementEscrowDeadlineState()
        let executor = InvestigationMachineClaimServerEffectExecutor(
            clock: clock, scheduler: scheduler, terminal: terminal
        )
        let adapter = try InvestigationMachineClaimServerAdapter(
            transfer: fixture.transfer(),
            clock: clock, state: state, executor: executor
        )
        let evidence = try InvestigationMachineClaimEvidence.decode(
            try adapter.claim(try fixture.request().encoded())
        )
        let releaseData = try fixture.release(evidence: evidence).encoded()

        let releaseTask = Task.detached {
            await releaseCallResult(
                adapter: adapter, releaseData: releaseData
            )
        }
        #expect(clock.waitUntilBlockedObservationEntered())
        let replyGate = ClaimServerStartGate()
        let replyTask = Task.detached {
            replyGate.signal()
            return await replyCallResult(adapter: adapter)
        }
        #expect(replyGate.waitUntilSignalled())
        #expect(clock.waitUntilObservation(4, timeout: .now() + 1))
        clock.allowBlockedObservationToReturn()

        #expect(await releaseTask.value == .failure(.unavailable))
        #expect(await replyTask.value == .failure(.duplicateOrReplay))
        #expect(state.phase == .terminal(.duplicateOrReplay))
        #expect(terminal.reasons == [.duplicateOrReplay])
    }

    @Test
    func claimRejectsEvidenceRecordedAfterItsIssuedTime() async throws {
        let fixture = ClaimServerFixture()
        let runtime = try fixture.runtime(
            transfer: fixture.transfer(
                recordedAtUTCMicroseconds: fixture.baseWall + 600_000
            )
        )
        let result = await claimCallResult(
            adapter: runtime.adapter,
            requestData: try fixture.request().encoded()
        )
        #expect(result == .failure(.bindingMismatch))
        #expect(runtime.state.phase == .terminal(.bindingMismatch))
        #expect(runtime.terminal.reasons == [.bindingMismatch])
        #expect(runtime.executor.pendingSlotCount == 0)
    }

    @Test
    func postReplyArmFailureCannotReturnSuccess() async throws {
        let fixture = ClaimServerFixture()
        let clock = SequenceClaimServerClock([
            try fixture.observation(monotonic: 1_000_000_000),
            try fixture.observation(
                monotonic: 2_000_000_000, wallOffset: 1_000_000
            ),
            try fixture.observation(
                monotonic: 3_000_000_000, wallOffset: 2_000_000
            ),
            try fixture.observation(
                monotonic: 3_500_000_000, wallOffset: 2_500_000
            ),
        ])
        let scheduler = KindFailingClaimServerScheduler(
            failingKind: .postReplyExit
        )
        let terminal = RecordingClaimServerTerminal()
        let state = LifecycleMachineRetirementEscrowDeadlineState()
        let executor = InvestigationMachineClaimServerEffectExecutor(
            clock: clock, scheduler: scheduler, terminal: terminal
        )
        let adapter = try InvestigationMachineClaimServerAdapter(
            transfer: fixture.transfer(),
            clock: clock, state: state, executor: executor
        )
        let evidence = try InvestigationMachineClaimEvidence.decode(
            try adapter.claim(try fixture.request().encoded())
        )
        _ = try adapter.release(
            try fixture.release(evidence: evidence).encoded()
        )

        let result = await replyCallResult(adapter: adapter)

        #expect(result == .failure(.unavailable))
        #expect(state.phase == .terminal(.deadlineArmFailure))
        #expect(terminal.reasons == [.deadlineArmFailure])
        #expect(executor.pendingSlotCount == 0)
    }

    @Test
    func strictClaimAndReleaseWireDriftFailAtTheServerBoundary() async throws {
        let fixture = ClaimServerFixture()
        let claim = try fixture.request().encoded()
        for mutation in fixture.strictWireMutations(claim) {
            let runtime = try fixture.runtime()
            let result = await claimCallResult(
                adapter: runtime.adapter, requestData: mutation
            )
            #expect(result == .failure(.invalidRequest))
            #expect(runtime.state.phase == .awaitingClaim)
            #expect(runtime.terminal.reasons.isEmpty)
            #expect(runtime.executor.pendingSlotCount == 1)
        }

        for mutationIndex in 0..<5 {
            let runtime = try fixture.runtime()
            let evidence = try InvestigationMachineClaimEvidence.decode(
                try runtime.adapter.claim(claim)
            )
            let release = try fixture.release(evidence: evidence).encoded()
            let mutation = fixture.strictWireMutations(release)[mutationIndex]
            let result = await releaseCallResult(
                adapter: runtime.adapter, releaseData: mutation
            )
            #expect(result == .failure(.bindingMismatch))
            #expect(runtime.state.phase == .terminal(.bindingMismatch))
            #expect(runtime.terminal.reasons == [.bindingMismatch])
            #expect(runtime.executor.pendingSlotCount == 0)
        }
    }

    @Test
    func everyDecodedHandleBindingAxisRejectsThroughTheStateOwner() async throws {
        let fixture = ClaimServerFixture()
        for drift in ClaimServerFixture.ClaimDrift.allCases {
            let runtime = try fixture.runtime()
            let result = await claimCallResult(
                adapter: runtime.adapter,
                requestData: try fixture.request(drift: drift).encoded()
            )
            #expect(result == .failure(.bindingMismatch))
            #expect(runtime.state.phase == .terminal(.bindingMismatch))
            #expect(runtime.terminal.reasons == [.bindingMismatch])
            #expect(runtime.executor.pendingSlotCount == 0)
        }
    }

    @Test
    func schedulerReentryCompletesWithoutAdapterIsolationDeadlock() async throws {
        let fixture = ClaimServerFixture()
        let probe = ReentrantClaimServerProbe()
        let scheduler = ReentrantClaimServerScheduler(
            reenterOnSchedule: .release, probe: probe
        )
        let runtime = try fixture.runtime(
            scheduler: scheduler, terminal: RecordingClaimServerTerminal()
        )
        probe.configure(
            adapter: runtime.adapter,
            requestData: try fixture.request().encoded()
        )

        let outer = await claimCallResult(
            adapter: runtime.adapter,
            requestData: try fixture.request().encoded()
        )

        #expect(probe.completedWithinDeadline)
        #expect(probe.result == .failure(.duplicateOrReplay))
        #expect(outer == .failure(.duplicateOrReplay))
        #expect(runtime.state.phase == .terminal(.duplicateOrReplay))
    }

    @Test
    func cancellationHandleReentryCompletesWithoutAdapterIsolationDeadlock() async throws {
        let fixture = ClaimServerFixture()
        let probe = ReentrantClaimServerProbe()
        let scheduler = ReentrantClaimServerScheduler(
            reenterOnCancel: .claim, probe: probe
        )
        let runtime = try fixture.runtime(
            scheduler: scheduler, terminal: RecordingClaimServerTerminal()
        )
        probe.configure(
            adapter: runtime.adapter,
            requestData: try fixture.request().encoded()
        )

        let outer = await claimCallResult(
            adapter: runtime.adapter,
            requestData: try fixture.request().encoded()
        )

        #expect(probe.completedWithinDeadline)
        #expect(probe.result == .failure(.duplicateOrReplay))
        #expect(outer == .failure(.duplicateOrReplay))
        #expect(runtime.state.phase == .terminal(.duplicateOrReplay))
    }

    @Test
    func terminalHandlerReentryCompletesWithoutAdapterIsolationDeadlock() async throws {
        let fixture = ClaimServerFixture()
        let probe = ReentrantClaimServerProbe()
        let terminal = ReentrantClaimServerTerminal(probe: probe)
        let runtime = try fixture.runtime(
            scheduler: RecordingClaimServerScheduler(mode: .manual),
            terminal: terminal
        )
        probe.configure(
            adapter: runtime.adapter,
            requestData: try fixture.request().encoded()
        )

        let outer = await claimCallResult(
            adapter: runtime.adapter,
            requestData: try fixture.request(drift: .token).encoded()
        )

        #expect(probe.completedWithinDeadline)
        #expect(probe.result == .failure(.unavailable))
        #expect(outer == .failure(.bindingMismatch))
        #expect(runtime.state.phase == .terminal(.bindingMismatch))
        #expect(terminal.reasons == [.bindingMismatch])
    }
}

private struct ClaimServerFixture {
    enum ClaimDrift: CaseIterable {
        case token
        case investigation
        case retireOperation
        case configuration
        case validBefore
    }

    enum ReleaseDrift: CaseIterable {
        case requestDigest
        case helperDigest
        case connectionEpoch
        case deadline
    }

    let token = UUID(uuidString: "10101010-1010-4010-8010-101010101010")!
    let investigation = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    let retireOperation = UUID(uuidString: "12121212-1212-4212-8212-121212121212")!
    let claimChallenge = UUID(uuidString: "20202020-2020-4020-8020-202020202020")!
    let connectionEpoch = UUID(uuidString: "21212121-2121-4121-8121-212121212121")!
    let releaseChallenge = UUID(uuidString: "40404040-4040-4040-8040-404040404040")!
    let foreignUUID = UUID(uuidString: "50505050-5050-4050-8050-505050505050")!
    let configDigest = try! InvestigationHandoffSHA256(
        rawBytes: Data(repeating: 0x13, count: 32)
    )
    let baseWall: Int64
    let helperASID: UInt32 = 9
    let releaseDeadline: UInt64 = 7_000_000_000
    let postReplyDeadline: UInt64 = 8_000_000_000
    let handleMonotonicDeadline: UInt64 = 31_000_000_000

    let reservationID = UUID(
        uuidString: "30303030-3030-4030-8030-303030303030"
    )!

    init(baseWall: Int64 = 2_000_000_000_000_000) {
        self.baseWall = baseWall
    }

    func runtime(
        observations: [LifecycleMachineRetirementDeadlineObservation]? = nil,
        transfer: LifecycleMachineRetirementReservationTransfer? = nil
    ) throws -> ClaimServerRuntime {
        let values: [LifecycleMachineRetirementDeadlineObservation]
        if let observations {
            values = observations
        } else {
            values = [
                try observation(monotonic: 1_000_000_000, wallOffset: 0),
                try observation(
                    monotonic: 2_000_000_000, wallOffset: 1_000_000
                ),
                try observation(
                    monotonic: 3_000_000_000, wallOffset: 2_000_000
                ),
            ]
        }
        let clock = SequenceClaimServerClock(values)
        let scheduler = RecordingClaimServerScheduler(mode: .manual)
        let terminal = RecordingClaimServerTerminal()
        let state = LifecycleMachineRetirementEscrowDeadlineState()
        let executor = InvestigationMachineClaimServerEffectExecutor(
            clock: clock, scheduler: scheduler, terminal: terminal
        )
        let adapter = try InvestigationMachineClaimServerAdapter(
            transfer: transfer ?? self.transfer(),
            clock: clock,
            state: state,
            executor: executor
        )
        return ClaimServerRuntime(
            adapter: adapter, state: state, clock: clock,
            scheduler: scheduler, terminal: terminal, executor: executor
        )
    }

    func runtime(
        scheduler: any InvestigationMachineClaimServerCoreScheduling,
        terminal: any InvestigationMachineClaimServerCoreTerminalHandling
    ) throws -> InjectedClaimServerRuntime {
        let clock = SequenceClaimServerClock([
            try observation(monotonic: 1_000_000_000, wallOffset: 0),
            try observation(
                monotonic: 2_000_000_000, wallOffset: 1_000_000
            ),
            try observation(
                monotonic: 3_000_000_000, wallOffset: 2_000_000
            ),
        ])
        let state = LifecycleMachineRetirementEscrowDeadlineState()
        let executor = InvestigationMachineClaimServerEffectExecutor(
            clock: clock, scheduler: scheduler, terminal: terminal
        )
        let adapter = try InvestigationMachineClaimServerAdapter(
            transfer: transfer(),
            clock: clock, state: state, executor: executor
        )
        return InjectedClaimServerRuntime(
            adapter: adapter, state: state, executor: executor
        )
    }

    func transfer() throws -> LifecycleMachineRetirementReservationTransfer {
        try transfer(
            recordedAtUTCMicroseconds: baseWall + 500_000,
            ownerRetirementObservation: .retiredOwnedResources,
            residueObservation: residueObservation()
        )
    }

    func recordedEscrow() throws -> LifecycleMachineRetirementEscrow {
        let escrow = LifecycleMachineRetirementEscrow(
            now: {
                Date(
                    timeIntervalSince1970:
                        TimeInterval(baseWall + 500_000) / 1_000_000
                )
            },
            token: { token },
            reservationID: { reservationID }
        )
        _ = try escrow.record(
            investigationID: LifecycleInvestigationID(
                rawValue: investigation
            ),
            retireOperationID: retireOperation,
            configurationSHA256: String(repeating: "13", count: 32),
            validBefore: Date(
                timeIntervalSince1970:
                    TimeInterval(baseWall + 30_000_000) / 1_000_000
            ),
            appIdentity: lifecycleIdentity(role: .app),
            helperIdentity: lifecycleIdentity(role: .helper),
            userID: 501,
            ownerRetirementObservation: .retiredOwnedResources,
            residueObservation: residueObservation()
        )
        return escrow
    }

    func transfer(
        recordedAtUTCMicroseconds: Int64
    ) throws -> LifecycleMachineRetirementReservationTransfer {
        try transfer(
            recordedAtUTCMicroseconds: recordedAtUTCMicroseconds,
            ownerRetirementObservation: .retiredOwnedResources,
            residueObservation: residueObservation()
        )
    }

    func transfer(
        validBeforeUTCMicroseconds: Int64? = nil,
        recordedAtUTCMicroseconds: Int64? = nil,
        ownerRetirementObservation:
            LifecycleInteractiveWorkerRetirementObservation,
        residueObservation: LifecycleInvestigationResidueObservation
    ) throws -> LifecycleMachineRetirementReservationTransfer {
        LifecycleMachineRetirementReservationTransfer(
            reservationID: reservationID,
            tokenSHA256: tokenDigest(token),
            investigationID: LifecycleInvestigationID(rawValue: investigation),
            retireOperationID: retireOperation,
            configurationSHA256: String(repeating: "13", count: 32),
            validBeforeUTCMicroseconds:
                validBeforeUTCMicroseconds ?? baseWall + 30_000_000,
            appIdentity: try lifecycleIdentity(role: .app),
            helperIdentity: try lifecycleIdentity(role: .helper),
            userID: 501,
            recordedAt: Date(
                timeIntervalSince1970: TimeInterval(
                    recordedAtUTCMicroseconds ?? baseWall + 500_000
                ) / 1_000_000
            ),
            ownerRetirementObservation: ownerRetirementObservation,
            residueObservation: residueObservation
        )
    }

    func residueObservation(
        investigation: UUID? = nil,
        auditSessionID: Int32? = nil,
        userID: UInt32 = 501,
        observedAtMicroseconds: Int64? = nil,
        observedAt: Date? = nil,
        remainingMembers: Int = 0,
        matchingLeases: Int = 0,
        leaseRootEntries: Int = 0,
        investigationArtifacts: Int = 0
    ) throws -> LifecycleInvestigationResidueObservation {
        try LifecycleInvestigationResidueObservation(
            investigationID: LifecycleInvestigationID(
                rawValue: investigation ?? self.investigation
            ),
            auditSessionID: auditSessionID ?? Int32(helperASID),
            userID: userID,
            observedAt: observedAt ?? Date(
                timeIntervalSince1970: TimeInterval(
                    observedAtMicroseconds ?? baseWall + 400_000
                ) / 1_000_000
            ),
            remainingAuditSessionMemberCount: remainingMembers,
            matchingLeaseCount: matchingLeases,
            leaseRootEntryCount: leaseRootEntries,
            investigationArtifactCount: investigationArtifacts
        )
    }

    func request(
        token: UUID? = nil,
        drift: ClaimDrift? = nil,
        handleValidBeforeUTCMicroseconds: Int64? = nil
    ) throws
        -> InvestigationMachineRetirementClaimRequest
    {
        try InvestigationMachineRetirementClaimRequest(
            handle: InvestigationHandoffRetirementHandle(
                token: drift == .token ? foreignUUID : token ?? self.token,
                investigationUUID: drift == .investigation
                    ? foreignUUID : investigation,
                retireOperationUUID: drift == .retireOperation
                    ? foreignUUID : retireOperation,
                configurationSHA256: drift == .configuration
                    ? InvestigationHandoffSHA256(
                        rawBytes: Data(repeating: 0x55, count: 32)
                    ) : configDigest,
                validBefore: InvestigationHandoffUTCMicroseconds(
                    rawValue:
                        handleValidBeforeUTCMicroseconds
                        ?? baseWall + 30_000_000
                        + (drift == .validBefore ? 1 : 0)
                )
            ),
            claimChallenge: claimChallenge,
            issuedAt: InvestigationHandoffUTCMicroseconds(
                rawValue: baseWall + 500_000
            ),
            requestValidBefore: InvestigationHandoffUTCMicroseconds(
                rawValue: baseWall + 10_000_000
            ),
            claimConnectionEpoch: connectionEpoch,
            epochDeadlineNanoseconds: 20_000_000_000
        )
    }

    func expectedEvidence() throws -> InvestigationMachineClaimEvidence {
        let request = try request()
        return try InvestigationMachineClaimEvidence(
            requestBindingSHA256: request.bindingSHA256(),
            originalClaimChallenge: claimChallenge,
            claimConnectionEpoch: connectionEpoch,
            appIdentity: try handoffIdentity(role: .app),
            helperIdentity: try handoffIdentity(role: .helper),
            appUserID: 501,
            recordedAt: InvestigationHandoffUTCMicroseconds(
                rawValue: baseWall + 500_000
            ),
            claimedAt: InvestigationHandoffUTCMicroseconds(
                rawValue: baseWall + 1_000_000
            ),
            ownerRetirement: InvestigationMachineOwnerRetirement(),
            l1Residue: InvestigationMachineL1Residue(
                investigationUUID: investigation,
                auditSessionID: helperASID,
                userID: 501,
                observedAt: InvestigationHandoffUTCMicroseconds(
                    rawValue: baseWall + 400_000
                ),
                remainingAuditSessionMembers: 0,
                matchingLeases: 0,
                leaseRootEntries: 0,
                investigationArtifacts: 0
            ),
            releaseDeadlineNanoseconds: releaseDeadline
        )
    }

    func release(
        evidence: InvestigationMachineClaimEvidence,
        drift: ReleaseDrift? = nil,
        releaseChallenge: UUID? = nil
    ) throws -> InvestigationMachineClaimRelease {
        try InvestigationMachineClaimRelease(
            requestBindingSHA256: drift == .requestDigest
                ? InvestigationHandoffSHA256(rawBytes: Data(repeating: 1, count: 32))
                : evidence.requestBindingSHA256,
            releaseChallenge: releaseChallenge ?? self.releaseChallenge,
            claimedHelperIdentitySHA256: drift == .helperDigest
                ? InvestigationHandoffSHA256(rawBytes: Data(repeating: 2, count: 32))
                : evidence.helperIdentity.helperIdentitySHA256(),
            claimConnectionEpoch: drift == .connectionEpoch
                ? foreignUUID : connectionEpoch,
            releaseDeadlineNanoseconds: drift == .deadline
                ? releaseDeadline + 1 : releaseDeadline
        )
    }

    func expectedReleased() throws -> InvestigationMachineClaimReleased {
        let evidence = try expectedEvidence()
        return try InvestigationMachineClaimReleased(
            requestBindingSHA256: evidence.requestBindingSHA256,
            releaseChallenge: releaseChallenge,
            claimedHelperIdentitySHA256:
                evidence.helperIdentity.helperIdentitySHA256(),
            claimConnectionEpoch: connectionEpoch,
            exitScheduled: true,
            postReplyExitDeadlineNanoseconds: postReplyDeadline
        )
    }

    func semanticReservation() throws
        -> LifecycleMachineRetirementDeadlineReservation
    {
        try LifecycleMachineRetirementDeadlineReservation(
            reservationID: reservationID,
            handleValidBeforeUTCMicroseconds: baseWall + 30_000_000,
            observation: observation(monotonic: 1_000_000_000, wallOffset: 0)
        )
    }

    func observation(
        monotonic: UInt64, wallOffset: Int64 = 0
    ) throws -> LifecycleMachineRetirementDeadlineObservation {
        try LifecycleMachineRetirementDeadlineObservation(
            monotonicNanoseconds: monotonic,
            wallUTCMicroseconds: baseWall + wallOffset
        )
    }

    func publicObservation(
        monotonic: UInt64, wallOffset: Int64 = 0
    ) throws -> InvestigationMachineClaimServerObservation {
        try InvestigationMachineClaimServerObservation(
            continuousNanoseconds: monotonic,
            wallUTCMicroseconds: baseWall + wallOffset
        )
    }

    func lifecycleIdentity(role: InvestigationMachineProcessRole) throws
        -> LifecycleMachineProcessIdentityRecord
    {
        let app = role == .app
        return try LifecycleMachineProcessIdentityRecord(
            processID: app ? 42 : 84, processIDVersion: app ? 7 : 8,
            auditSessionID: app ? 7 : Int32(helperASID),
            effectiveUserID: app ? 501 : 0,
            auditTokenWords: app
                ? [501, 501, 20, 501, 20, 42, 7, 7]
                : [0, 0, 20, 0, 20, 84, helperASID, 8]
        )
    }

    func handoffIdentity(role: InvestigationMachineProcessRole) throws
        -> InvestigationMachineProcessIdentity
    {
        let record = try lifecycleIdentity(role: role)
        return try InvestigationMachineProcessIdentity(
            role: role, processID: UInt32(record.processID),
            processIDVersion: UInt32(record.processIDVersion),
            auditSessionID: UInt32(record.auditSessionID),
            effectiveUserID: record.effectiveUserID,
            auditTokenWords: record.auditTokenWords
        )
    }

    func tokenDigest(_ token: UUID) -> Data {
        var raw = token.uuid
        return withUnsafeBytes(of: &raw) { Data(SHA256.hash(data: Data($0))) }
    }

    func uuidBytes(_ value: UUID) -> Data {
        var raw = value.uuid
        return withUnsafeBytes(of: &raw) { Data($0) }
    }

    func strictWireMutations(_ value: Data) -> [Data] {
        var wrongMagic = value
        wrongMagic[wrongMagic.startIndex] ^= 0xff

        var wrongVersion = value
        let versionPayload = strictWirePayloadRange(tag: 1, in: wrongVersion)!
        wrongVersion[versionPayload.upperBound - 1] ^= 0x01

        var wrongBusinessTag = value
        let businessTag = strictWireTagOffset(tag: 2, in: wrongBusinessTag)!
        wrongBusinessTag[businessTag + 1] = 3

        var wrongLength = value
        let lengthOffset = businessTag + 2
        wrongLength[lengthOffset + 3] &+= 1

        return [
            wrongMagic, wrongVersion, wrongBusinessTag, wrongLength,
            value + Data([0]),
        ]
    }

    private func strictWireTagOffset(
        tag expectedTag: UInt16,
        in data: Data
    ) -> Int? {
        var offset = 4
        while offset < data.count {
            guard offset + 6 <= data.count else { return nil }
            let tag = UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
            let length = Int(data[offset + 2]) << 24
                | Int(data[offset + 3]) << 16
                | Int(data[offset + 4]) << 8
                | Int(data[offset + 5])
            if tag == expectedTag { return offset }
            guard length <= data.count - offset - 6 else { return nil }
            offset += 6 + length
        }
        return nil
    }

    private func strictWirePayloadRange(
        tag: UInt16,
        in data: Data
    ) -> Range<Data.Index>? {
        guard let offset = strictWireTagOffset(tag: tag, in: data) else {
            return nil
        }
        let length = Int(data[offset + 2]) << 24
            | Int(data[offset + 3]) << 16
            | Int(data[offset + 4]) << 8
            | Int(data[offset + 5])
        let range = (offset + 6)..<(offset + 6 + length)
        return range.upperBound <= data.endIndex ? range : nil
    }
}

private struct ClaimServerRuntime {
    let adapter: InvestigationMachineClaimServerAdapter
    let state: LifecycleMachineRetirementEscrowDeadlineState
    let clock: SequenceClaimServerClock
    let scheduler: RecordingClaimServerScheduler
    let terminal: RecordingClaimServerTerminal
    let executor: InvestigationMachineClaimServerEffectExecutor
}

private struct InjectedClaimServerRuntime {
    let adapter: InvestigationMachineClaimServerAdapter
    let state: LifecycleMachineRetirementEscrowDeadlineState
    let executor: InvestigationMachineClaimServerEffectExecutor
}

private enum ClaimCallResult: Sendable, Equatable {
    case success
    case failure(InvestigationMachineClaimServerError)
    case unexpectedFailure
}

private func claimCallResult(
    adapter: InvestigationMachineClaimServerAdapter,
    requestData: Data
) async -> ClaimCallResult {
    do {
        _ = try adapter.claim(requestData)
        return .success
    } catch let error as InvestigationMachineClaimServerError {
        return .failure(error)
    } catch {
        return .unexpectedFailure
    }
}

private func releaseCallResult(
    adapter: InvestigationMachineClaimServerAdapter,
    releaseData: Data
) async -> ClaimCallResult {
    do {
        _ = try adapter.release(releaseData)
        return .success
    } catch let error as InvestigationMachineClaimServerError {
        return .failure(error)
    } catch {
        return .unexpectedFailure
    }
}

private func replyCallResult(
    adapter: InvestigationMachineClaimServerAdapter
) async -> ClaimCallResult {
    do {
        try adapter.replyDidDispatch()
        return .success
    } catch let error as InvestigationMachineClaimServerError {
        return .failure(error)
    } catch {
        return .unexpectedFailure
    }
}

private final class SequenceClaimServerClock:
    InvestigationMachineClaimServerCoreClock,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var values: [LifecycleMachineRetirementDeadlineObservation]
    init(_ values: [LifecycleMachineRetirementDeadlineObservation]) {
        self.values = values
    }
    func append(_ value: LifecycleMachineRetirementDeadlineObservation) {
        lock.withLock { values.append(value) }
    }
    func observation() throws -> LifecycleMachineRetirementDeadlineObservation {
        try lock.withLock {
            guard !values.isEmpty else { throw ClaimServerTestError.noClockValue }
            return values.removeFirst()
        }
    }
}

private final class CountingClaimServerClock:
    InvestigationMachineClaimServerCoreClock,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var values: [LifecycleMachineRetirementDeadlineObservation]
    private var observationCount = 0
    private let thirdObservation = DispatchSemaphore(value: 0)

    init(_ values: [LifecycleMachineRetirementDeadlineObservation]) {
        self.values = values
    }

    func observation() throws -> LifecycleMachineRetirementDeadlineObservation {
        let result = try lock.withLock {
            guard !values.isEmpty else {
                throw ClaimServerTestError.noClockValue
            }
            observationCount += 1
            return (values.removeFirst(), observationCount == 3)
        }
        if result.1 { thirdObservation.signal() }
        return result.0
    }

    func waitUntilThirdObservation(timeout: DispatchTime) -> Bool {
        thirdObservation.wait(timeout: timeout) == .success
    }
}

private final class BlockingObservationClaimServerClock:
    InvestigationMachineClaimServerCoreClock,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var values: [LifecycleMachineRetirementDeadlineObservation]
    private var observationCount = 0
    private let blockedObservation: Int
    private let blockedObservationEntered = DispatchSemaphore(value: 0)
    private let blockedObservationMayReturn = DispatchSemaphore(value: 0)
    private var observationSignals: [Int: DispatchSemaphore] = [:]

    init(
        values: [LifecycleMachineRetirementDeadlineObservation],
        blockedObservation: Int
    ) {
        self.values = values
        self.blockedObservation = blockedObservation
    }

    func observation() throws -> LifecycleMachineRetirementDeadlineObservation {
        let result = try lock.withLock {
            guard !values.isEmpty else {
                throw ClaimServerTestError.noClockValue
            }
            observationCount += 1
            let signal = observationSignals[observationCount]
            return (values.removeFirst(), observationCount, signal)
        }
        result.2?.signal()
        if result.1 == blockedObservation {
            blockedObservationEntered.signal()
            blockedObservationMayReturn.wait()
        }
        return result.0
    }

    func waitUntilBlockedObservationEntered() -> Bool {
        blockedObservationEntered.wait(timeout: .now() + 1) == .success
    }

    func allowBlockedObservationToReturn() {
        blockedObservationMayReturn.signal()
    }

    func waitUntilObservation(
        _ count: Int,
        timeout: DispatchTime
    ) -> Bool {
        let signal: DispatchSemaphore? = lock.withLock {
            if observationCount >= count { return nil }
            if let existing = observationSignals[count] { return existing }
            let created = DispatchSemaphore(value: 0)
            observationSignals[count] = created
            return created
        }
        guard let signal else { return true }
        return signal.wait(timeout: timeout) == .success
    }
}

private final class RecordingClaimServerHandle:
    InvestigationMachineClaimServerCoreScheduledHandle,
    @unchecked Sendable
{
    private let lock = NSLock()
    private(set) var cancelCount = 0
    func cancel() { lock.withLock { cancelCount += 1 } }
}

private final class ReentrantClaimServerProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var adapter: InvestigationMachineClaimServerAdapter?
    private var requestData: Data?
    private var storedResult: ClaimCallResult?
    private var storedCompletedWithinDeadline = false

    var result: ClaimCallResult? {
        lock.withLock { storedResult }
    }

    var completedWithinDeadline: Bool {
        lock.withLock { storedCompletedWithinDeadline }
    }

    func configure(
        adapter: InvestigationMachineClaimServerAdapter,
        requestData: Data
    ) {
        lock.withLock {
            self.adapter = adapter
            self.requestData = requestData
        }
    }

    func run() {
        let inputs = lock.withLock { (adapter, requestData) }
        guard let adapter = inputs.0, let requestData = inputs.1 else {
            return
        }
        let completed = DispatchSemaphore(value: 0)
        Task.detached { [weak self] in
            let value = await claimCallResult(
                adapter: adapter, requestData: requestData
            )
            self?.lock.withLock { self?.storedResult = value }
            completed.signal()
        }
        let didComplete = completed.wait(timeout: .now() + 1) == .success
        lock.withLock { storedCompletedWithinDeadline = didComplete }
    }
}

private final class ReentrantClaimServerHandle:
    InvestigationMachineClaimServerCoreScheduledHandle,
    @unchecked Sendable
{
    private let shouldReenter: Bool
    private let probe: ReentrantClaimServerProbe

    init(shouldReenter: Bool, probe: ReentrantClaimServerProbe) {
        self.shouldReenter = shouldReenter
        self.probe = probe
    }

    func cancel() {
        if shouldReenter { probe.run() }
    }
}

private final class ReentrantClaimServerScheduler:
    InvestigationMachineClaimServerCoreScheduling,
    @unchecked Sendable
{
    private let reenterOnSchedule: LifecycleMachineRetirementDeadlineKind?
    private let reenterOnCancel: LifecycleMachineRetirementDeadlineKind?
    private let probe: ReentrantClaimServerProbe

    init(
        reenterOnSchedule: LifecycleMachineRetirementDeadlineKind? = nil,
        reenterOnCancel: LifecycleMachineRetirementDeadlineKind? = nil,
        probe: ReentrantClaimServerProbe
    ) {
        self.reenterOnSchedule = reenterOnSchedule
        self.reenterOnCancel = reenterOnCancel
        self.probe = probe
    }

    func schedule(
        ticket: LifecycleMachineRetirementDeadlineTicket,
        callback _: @escaping @Sendable () -> Void
    ) throws -> any InvestigationMachineClaimServerCoreScheduledHandle {
        if ticket.kind == reenterOnSchedule { probe.run() }
        return ReentrantClaimServerHandle(
            shouldReenter: ticket.kind == reenterOnCancel,
            probe: probe
        )
    }
}

private final class RecordingClaimServerScheduler:
    InvestigationMachineClaimServerCoreScheduling,
    @unchecked Sendable
{
    enum Mode { case manual, fireBeforeReturn, fail }
    private let lock = NSLock()
    private let mode: Mode
    private var callbacks: [
        LifecycleMachineRetirementDeadlineKind: @Sendable () -> Void
    ] = [:]
    private var handlesByKind: [
        LifecycleMachineRetirementDeadlineKind: RecordingClaimServerHandle
    ] = [:]
    private(set) var handles: [RecordingClaimServerHandle] = []
    private(set) var scheduleCount = 0
    private(set) var lastDeadline: UInt64?

    init(mode: Mode) { self.mode = mode }

    func schedule(
        ticket: LifecycleMachineRetirementDeadlineTicket,
        callback: @escaping @Sendable () -> Void
    ) throws -> any InvestigationMachineClaimServerCoreScheduledHandle {
        if mode == .fail { throw ClaimServerTestError.schedulerFailure }
        let handle = RecordingClaimServerHandle()
        lock.withLock {
            scheduleCount += 1
            lastDeadline = ticket.deadlineNanoseconds
            callbacks[ticket.kind] = callback
            handlesByKind[ticket.kind] = handle
            handles.append(handle)
        }
        if mode == .fireBeforeReturn { callback() }
        return handle
    }

    func callback(
        for kind: LifecycleMachineRetirementDeadlineKind
    ) -> (@Sendable () -> Void)? {
        lock.withLock { callbacks[kind] }
    }

    var liveKinds: Set<LifecycleMachineRetirementDeadlineKind> {
        lock.withLock {
            Set(handlesByKind.compactMap { kind, handle in
                handle.cancelCount == 0 ? kind : nil
            })
        }
    }
}

private final class BlockingReleaseClaimServerScheduler:
    InvestigationMachineClaimServerCoreScheduling,
    @unchecked Sendable
{
    private let releaseScheduleEntered = DispatchSemaphore(value: 0)
    private let releaseScheduleMayReturn = DispatchSemaphore(value: 0)

    func schedule(
        ticket: LifecycleMachineRetirementDeadlineTicket,
        callback _: @escaping @Sendable () -> Void
    ) throws -> any InvestigationMachineClaimServerCoreScheduledHandle {
        let handle = RecordingClaimServerHandle()
        if ticket.kind == .release {
            releaseScheduleEntered.signal()
            releaseScheduleMayReturn.wait()
        }
        return handle
    }

    func waitUntilReleaseScheduleEntered() -> Bool {
        releaseScheduleEntered.wait(timeout: .now() + 1) == .success
    }

    func allowReleaseScheduleToReturn() {
        releaseScheduleMayReturn.signal()
    }
}

private final class KindFailingClaimServerScheduler:
    InvestigationMachineClaimServerCoreScheduling,
    @unchecked Sendable
{
    private let failingKind: LifecycleMachineRetirementDeadlineKind

    init(failingKind: LifecycleMachineRetirementDeadlineKind) {
        self.failingKind = failingKind
    }

    func schedule(
        ticket: LifecycleMachineRetirementDeadlineTicket,
        callback _: @escaping @Sendable () -> Void
    ) throws -> any InvestigationMachineClaimServerCoreScheduledHandle {
        if ticket.kind == failingKind {
            throw ClaimServerTestError.schedulerFailure
        }
        return RecordingClaimServerHandle()
    }
}

private final class RecordingClaimServerTerminal:
    InvestigationMachineClaimServerCoreTerminalHandling,
    @unchecked Sendable
{
    private let lock = NSLock()
    private(set) var reasons: [LifecycleMachineRetirementDeadlineTerminalReason] = []
    func handle(_ reason: LifecycleMachineRetirementDeadlineTerminalReason) {
        lock.withLock { reasons.append(reason) }
    }
}

private final class ReentrantClaimServerTerminal:
    InvestigationMachineClaimServerCoreTerminalHandling,
    @unchecked Sendable
{
    private let lock = NSLock()
    private let probe: ReentrantClaimServerProbe
    private(set) var reasons: [
        LifecycleMachineRetirementDeadlineTerminalReason
    ] = []

    init(probe: ReentrantClaimServerProbe) {
        self.probe = probe
    }

    func handle(_ reason: LifecycleMachineRetirementDeadlineTerminalReason) {
        lock.withLock { reasons.append(reason) }
        probe.run()
    }
}

private final class PublicClaimServerClock:
    InvestigationMachineClaimServerClock,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var values: [InvestigationMachineClaimServerObservation]

    init(_ values: [InvestigationMachineClaimServerObservation]) {
        self.values = values
    }

    func observation() throws -> InvestigationMachineClaimServerObservation {
        try lock.withLock {
            guard !values.isEmpty else {
                throw ClaimServerTestError.noClockValue
            }
            return values.removeFirst()
        }
    }
}

private final class BlockingPublicClaimServerClock:
    InvestigationMachineClaimServerClock,
    @unchecked Sendable
{
    private let value: InvestigationMachineClaimServerObservation
    private let entered = DispatchSemaphore(value: 0)
    private let mayReturn = DispatchSemaphore(value: 0)

    init(_ value: InvestigationMachineClaimServerObservation) {
        self.value = value
    }

    func observation() throws -> InvestigationMachineClaimServerObservation {
        entered.signal()
        mayReturn.wait()
        return value
    }

    func waitUntilObservationEntered() -> Bool {
        entered.wait(timeout: .now() + 1) == .success
    }

    func allowObservationToReturn() { mayReturn.signal() }
}

private final class PublicClaimServerHandle:
    InvestigationMachineClaimServerScheduledHandle,
    @unchecked Sendable
{
    private let lock = NSLock()
    private(set) var cancelCount = 0

    func cancel() { lock.withLock { cancelCount += 1 } }
}

private final class PublicClaimServerScheduler:
    InvestigationMachineClaimServerScheduling,
    @unchecked Sendable
{
    private let lock = NSLock()
    private let failOnSchedule: Int?
    private var scheduleCount = 0
    private(set) var handles: [PublicClaimServerHandle] = []

    init(failOnSchedule: Int? = nil) {
        self.failOnSchedule = failOnSchedule
    }

    var totalScheduleCount: Int { lock.withLock { scheduleCount } }

    func schedule(
        deadline _: InvestigationMachineClaimServerDeadline,
        callback _: @escaping @Sendable () -> Void
    ) throws -> any InvestigationMachineClaimServerScheduledHandle {
        try lock.withLock {
            scheduleCount += 1
            if scheduleCount == failOnSchedule {
                throw ClaimServerTestError.schedulerFailure
            }
            let handle = PublicClaimServerHandle()
            handles.append(handle)
            return handle
        }
    }
}

private final class PublicClaimServerTerminal:
    InvestigationMachineClaimServerTerminalHandling,
    @unchecked Sendable
{
    private let lock = NSLock()
    private(set) var reasons: [
        InvestigationMachineClaimServerTerminalReason
    ] = []
    private let onReason: @Sendable (
        InvestigationMachineClaimServerTerminalReason
    ) -> Void

    init(
        onReason: @escaping @Sendable (
            InvestigationMachineClaimServerTerminalReason
        ) -> Void = { _ in }
    ) {
        self.onReason = onReason
    }

    func handle(_ reason: InvestigationMachineClaimServerTerminalReason) {
        lock.withLock { reasons.append(reason) }
        onReason(reason)
    }
}

private final class PublicClaimServerEventLog: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var values: [String] = []

    func append(_ value: String) { lock.withLock { values.append(value) } }
}

private final class PublicClaimServerReplyRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var values: [(Data?, String?)] = []

    func call(_ data: Data?, _ reason: String?) {
        lock.withLock { values.append((data, reason)) }
    }
}

private enum ClaimServerTestError: Error {
    case noClockValue
    case schedulerFailure
}

private final class ClaimServerStartGate: @unchecked Sendable {
    private let semaphore = DispatchSemaphore(value: 0)

    func signal() {
        semaphore.signal()
    }

    func waitUntilSignalled() -> Bool {
        semaphore.wait(timeout: .now() + 1) == .success
    }
}

private extension Data {
    func containsSubsequence(_ bytes: Data) -> Bool {
        guard !bytes.isEmpty, bytes.count <= count else { return false }
        return range(of: bytes) != nil
    }
}
