import Foundation
import Testing
import StornautCore
@testable import StornautInvestigation

@Suite("Investigation coordinator terminal and recovery")
struct InvestigationRecoveryTests {
    @Test
    func userStopInterruptsOnceThenCommitsVerifiedPartial() async throws {
        let fixture = try InvestigationCoordinatorFixture()
        let coordinator = fixture.coordinator()
        _ = try await coordinator.start(fixture.admission())
        try await fixture.startRootTurn(on: coordinator)

        let first = try await coordinator.requestStop(
            investigationID: fixture.session.id,
            runID: fixture.session.runID
        )
        let replay = try await coordinator.requestStop(
            investigationID: fixture.session.id,
            runID: fixture.session.runID
        )
        #expect(first.t0Nanoseconds == replay.t0Nanoseconds)
        #expect(fixture.runtime.interrupts.count == 1)

        _ = try await coordinator.acceptTokenUsage(
            fixture.usage(total: 120, payload: "terminal-usage")
        )
        try await coordinator.acceptTurnTerminal(
            investigationID: fixture.session.id,
            runID: fixture.session.runID,
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            payload: fixture.payload("terminal-turn")
        )
        let result = try await coordinator.settle(
            investigationID: fixture.session.id,
            runID: fixture.session.runID
        )

        #expect(result.investigation.state == .partial)
        #expect(result.report?.kind == .partial)
        #expect(fixture.store.terminalCommands.count == 1)
        #expect(fixture.store.terminalCommands[0].cause == .userStopped)
        #expect(fixture.lifecycle.drainedRuns == [fixture.session.runID])
        #expect(fixture.runtime.retiredRuns == [fixture.session.runID])
        #expect(fixture.store.operationLog.suffix(3) == [
            "transition.terminalBarrier",
            "terminal.userStopped",
            "terminal.committed",
        ])
    }

    @Test
    func missingTerminalAfterWindowPersistsBlockedZeroReport() async throws {
        let fixture = try InvestigationCoordinatorFixture()
        let coordinator = fixture.coordinator()
        _ = try await coordinator.start(fixture.admission())
        try await fixture.startRootTurn(on: coordinator)
        _ = try await coordinator.cancel(
            investigationID: fixture.session.id,
            runID: fixture.session.runID
        )
        await #expect(throws: InvestigationCoordinatorError.terminalNotReady) {
            _ = try await coordinator.settle(
                investigationID: fixture.session.id,
                runID: fixture.session.runID
            )
        }
        fixture.clock.advance(by: .seconds(15))

        let result = try await coordinator.settle(
            investigationID: fixture.session.id,
            runID: fixture.session.runID
        )

        #expect(result.investigation.state == .blocked)
        #expect(result.report == nil)
        #expect(
            fixture.store.terminalCommands[0].cause
                == .runtimeTerminalUnobserved
        )
        #expect(fixture.store.terminalCommands[0].report == nil)
    }

    @Test
    func terminalEventWindowClosesAtExact15Seconds() async throws {
        let fixture = try InvestigationCoordinatorFixture()
        let coordinator = fixture.coordinator()
        _ = try await coordinator.start(fixture.admission())
        try await fixture.startRootTurn(on: coordinator)
        _ = try await coordinator.requestStop(
            investigationID: fixture.session.id,
            runID: fixture.session.runID
        )

        fixture.clock.advance(by: .nanoseconds(14_999_999_999))
        _ = try await coordinator.acceptTokenUsage(
            fixture.usage(total: 100, payload: "last-window-usage")
        )
        fixture.clock.advance(by: .nanoseconds(1))
        await #expect(
            throws: InvestigationCoordinatorError.terminalEventWindowClosed
        ) {
            try await coordinator.acceptTurnTerminal(
                investigationID: fixture.session.id,
                runID: fixture.session.runID,
                threadID: fixture.root.id,
                turnID: fixture.rootTurnID,
                payload: fixture.payload("too-late-terminal")
            )
        }

        let result = try await coordinator.settle(
            investigationID: fixture.session.id,
            runID: fixture.session.runID
        )
        #expect(result.investigation.state == .blocked)
        #expect(
            fixture.store.terminalCommands[0].cause
                == .runtimeTerminalUnobserved
        )
    }

    @Test
    func unprovedDrainPersistsBlockedZeroReport() async throws {
        let fixture = try InvestigationCoordinatorFixture()
        fixture.lifecycle.result = InvestigationLifecycleDrainResultV1(
            auditSessionEmpty: false,
            managedProxyOwnerEmpty: true
        )
        let coordinator = fixture.coordinator()
        _ = try await coordinator.start(fixture.admission())
        try await fixture.startAndFinishRootTurn(on: coordinator)
        _ = try await coordinator.requestPause(
            investigationID: fixture.session.id,
            runID: fixture.session.runID
        )

        await #expect(
            throws: InvestigationCoordinatorError.terminalNotReady
        ) {
            _ = try await coordinator.settle(
                investigationID: fixture.session.id,
                runID: fixture.session.runID
            )
        }
        #expect(fixture.store.terminalCommands.isEmpty)
        fixture.clock.advance(by: .seconds(45))
        let result = try await coordinator.settle(
            investigationID: fixture.session.id,
            runID: fixture.session.runID
        )

        #expect(result.investigation.state == .blocked)
        #expect(result.report == nil)
        #expect(
            fixture.store.terminalCommands[0].cause
                == .lifecycleDrainUnconfirmed
        )
        #expect(fixture.runtime.retiredRuns.isEmpty)
    }

    @Test
    func unprovedProbeWorkerDrainPersistsBlockedZeroReportAt45Seconds()
        async throws
    {
        let fixture = try InvestigationCoordinatorFixture()
        fixture.lifecycle.result = InvestigationLifecycleDrainResultV1(
            auditSessionEmpty: true,
            managedProxyOwnerEmpty: true,
            probeWorkerEmpty: false
        )
        let coordinator = fixture.coordinator()
        _ = try await coordinator.start(fixture.admission())
        try await fixture.startAndFinishRootTurn(on: coordinator)
        _ = try await coordinator.requestStop(
            investigationID: fixture.session.id,
            runID: fixture.session.runID
        )

        fixture.clock.advance(by: .seconds(44))
        await #expect(
            throws: InvestigationCoordinatorError.terminalNotReady
        ) {
            _ = try await coordinator.settle(
                investigationID: fixture.session.id,
                runID: fixture.session.runID
            )
        }
        fixture.clock.advance(by: .seconds(1))
        let result = try await coordinator.settle(
            investigationID: fixture.session.id,
            runID: fixture.session.runID
        )

        #expect(result.investigation.state == .blocked)
        #expect(result.report == nil)
        #expect(
            fixture.store.terminalCommands[0].cause
                == .lifecycleDrainUnconfirmed
        )
        #expect(fixture.runtime.retiredRuns.isEmpty)
    }

    @Test
    func terminalCommitRetryReusesOneAllocatedReportID() async throws {
        let fixture = try InvestigationCoordinatorFixture()
        fixture.store.terminalFailuresRemaining = 1
        let coordinator = fixture.coordinator()
        _ = try await coordinator.start(fixture.admission())
        try await fixture.startAndFinishRootTurn(on: coordinator)
        _ = try await coordinator.requestPause(
            investigationID: fixture.session.id,
            runID: fixture.session.runID
        )

        await #expect(throws: InvestigationRuntimeError.terminalFailed) {
            _ = try await coordinator.settle(
                investigationID: fixture.session.id,
                runID: fixture.session.runID
            )
        }
        let result = try await coordinator.settle(
            investigationID: fixture.session.id,
            runID: fixture.session.runID
        )

        #expect(result.investigation.state == .paused)
        #expect(fixture.idProvider.reportRequests.count == 1)
        #expect(fixture.store.terminalCommands.count == 2)
        #expect(
            fixture.store.terminalCommands[0].report?.id
                == fixture.store.terminalCommands[1].report?.id
        )
    }

    @Test
    func closingTransitionFailureKeepsAdmissionClosedAndSettlesFromStoreState()
        async throws
    {
        let fixture = try InvestigationCoordinatorFixture()
        fixture.store.transitionErrors = [
            InvestigationRuntimeError.transitionFailed,
        ]
        let coordinator = fixture.coordinator()
        _ = try await coordinator.start(fixture.admission())
        try await fixture.startRootTurn(on: coordinator)

        await #expect(throws: InvestigationRuntimeError.transitionFailed) {
            _ = try await coordinator.requestStop(
                investigationID: fixture.session.id,
                runID: fixture.session.runID
            )
        }
        await #expect(
            throws: InvestigationCoordinatorError.scientificAdmissionClosed
        ) {
            try await coordinator.startTurn(
                investigationID: fixture.session.id,
                runID: fixture.session.runID,
                threadID: fixture.root.id,
                turnID: fixture.secondRootTurnID,
                contextBytes: fixture.initialContextBytes
            )
        }
        _ = try await coordinator.acceptTokenUsage(
            fixture.usage(total: 120, payload: "transition-failed-usage")
        )
        try await coordinator.acceptTurnTerminal(
            investigationID: fixture.session.id,
            runID: fixture.session.runID,
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            payload: fixture.payload("transition-failed-terminal")
        )

        let result = try await coordinator.settle(
            investigationID: fixture.session.id,
            runID: fixture.session.runID
        )

        #expect(result.investigation.state == .partial)
        #expect(fixture.runtime.interrupts.count == 1)
        #expect(fixture.store.terminalExpectedRunStates == [.running])
    }

    @Test
    func interruptFailureKeepsPersistedClosingAndDoesNotRetryInterrupt()
        async throws
    {
        let fixture = try InvestigationCoordinatorFixture()
        fixture.runtime.interruptErrors = [
            InvestigationRuntimeError.interruptFailed,
        ]
        let coordinator = fixture.coordinator()
        _ = try await coordinator.start(fixture.admission())
        try await fixture.startRootTurn(on: coordinator)

        await #expect(throws: InvestigationRuntimeError.interruptFailed) {
            _ = try await coordinator.requestStop(
                investigationID: fixture.session.id,
                runID: fixture.session.runID
            )
        }
        let replay = try await coordinator.requestStop(
            investigationID: fixture.session.id,
            runID: fixture.session.runID
        )
        #expect(replay.primaryCause == .userStopped)
        #expect(fixture.runtime.interrupts.count == 1)
        await #expect(
            throws: InvestigationCoordinatorError.scientificAdmissionClosed
        ) {
            try await coordinator.startTurn(
                investigationID: fixture.session.id,
                runID: fixture.session.runID,
                threadID: fixture.root.id,
                turnID: fixture.secondRootTurnID,
                contextBytes: fixture.initialContextBytes
            )
        }
        _ = try await coordinator.acceptTokenUsage(
            fixture.usage(total: 120, payload: "interrupt-failed-usage")
        )
        try await coordinator.acceptTurnTerminal(
            investigationID: fixture.session.id,
            runID: fixture.session.runID,
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            payload: fixture.payload("interrupt-failed-terminal")
        )

        let result = try await coordinator.settle(
            investigationID: fixture.session.id,
            runID: fixture.session.runID
        )

        #expect(result.investigation.state == .partial)
        #expect(fixture.store.terminalExpectedRunStates == [.stopRequested])
    }

    @Test
    func activeProbeLeasePreventsTerminalCommitUntilProbeReturns()
        async throws
    {
        let fixture = try InvestigationCoordinatorFixture()
        let gate = InvestigationProbeExecutionGate()
        fixture.probe.executionGate = gate
        fixture.probe.results = [.failure(.cancelled)]
        let coordinator = fixture.coordinator()
        _ = try await coordinator.start(fixture.admission())
        try await fixture.startRootTurn(on: coordinator)

        let probeTask = Task {
            try await coordinator.executeProbe(
                investigationID: fixture.session.id,
                runID: fixture.session.runID,
                sourceThreadID: fixture.root.id,
                sourceTurnID: fixture.rootTurnID,
                request: ProbeRequest(
                    capability: .directorySummary,
                    targetURL: URL(fileURLWithPath: "/tmp")
                )
            )
        }
        await gate.waitUntilStarted()
        _ = try await coordinator.requestStop(
            investigationID: fixture.session.id,
            runID: fixture.session.runID
        )
        _ = try await coordinator.acceptTokenUsage(
            fixture.usage(total: 100, payload: "probe-terminal-usage")
        )
        try await coordinator.acceptTurnTerminal(
            investigationID: fixture.session.id,
            runID: fixture.session.runID,
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            payload: fixture.payload("probe-terminal")
        )

        await #expect(
            throws: InvestigationCoordinatorError.terminalNotReady
        ) {
            _ = try await coordinator.settle(
                investigationID: fixture.session.id,
                runID: fixture.session.runID
            )
        }
        #expect(fixture.store.terminalCommands.isEmpty)
        #expect(fixture.runtime.retiredRuns.isEmpty)

        await gate.release()
        _ = try await probeTask.value
        let result = try await coordinator.settle(
            investigationID: fixture.session.id,
            runID: fixture.session.runID
        )

        #expect(result.investigation.state == .partial)
        #expect(fixture.store.terminalCommands.count == 1)
        #expect(fixture.runtime.retiredRuns == [fixture.session.runID])
    }

    @Test
    func exact135SecondBoundaryRefusesLateStoreCommit() async throws {
        let fixture = try InvestigationCoordinatorFixture()
        let coordinator = fixture.coordinator()
        _ = try await coordinator.start(fixture.admission())
        try await fixture.startAndFinishRootTurn(on: coordinator)
        _ = try await coordinator.requestStop(
            investigationID: fixture.session.id,
            runID: fixture.session.runID
        )

        fixture.clock.advance(by: .seconds(135))
        await #expect(
            throws: InvestigationCoordinatorError.terminalDeadlineExceeded
        ) {
            _ = try await coordinator.settle(
                investigationID: fixture.session.id,
                runID: fixture.session.runID
            )
        }
        #expect(fixture.store.terminalCommands.isEmpty)
        #expect(fixture.runtime.retiredRuns.isEmpty)
    }

    @Test
    func terminalStoreDeadlineUsesOnlyRemainingOuterEnvelope() async throws {
        for (elapsedSeconds, expectedNanoseconds) in [
            (45, UInt64(90_000_000_000)),
            (100, UInt64(35_000_000_000)),
        ] {
            let fixture = try InvestigationCoordinatorFixture()
            let coordinator = fixture.coordinator()
            _ = try await coordinator.start(fixture.admission())
            try await fixture.startAndFinishRootTurn(on: coordinator)
            _ = try await coordinator.requestStop(
                investigationID: fixture.session.id,
                runID: fixture.session.runID
            )
            fixture.clock.advance(by: .seconds(elapsedSeconds))

            _ = try await coordinator.settle(
                investigationID: fixture.session.id,
                runID: fixture.session.runID
            )

            #expect(
                fixture.store.terminalMaximumDurations
                    == [expectedNanoseconds]
            )
        }
    }

    @Test
    func activeCoordinatorRefusesCrashRecovery() async throws {
        let fixture = try InvestigationCoordinatorFixture()
        fixture.store.recoveryRecords = [
            InvestigationRecoveryCandidate(
                investigationID: fixture.session.id,
                runID: fixture.session.runID,
                state: .running,
                stage: .verify,
                terminalCause: nil,
                plan: fixture.plan,
                updatedAt: fixture.now,
                expiresAt: fixture.now.addingTimeInterval(3_600)
            ),
        ]
        let coordinator = fixture.coordinator()
        _ = try await coordinator.start(fixture.admission())

        await #expect(throws: InvestigationCoordinatorError.runAlreadyActive) {
            _ = try await coordinator.recover(
                now: fixture.now,
                limit: 10
            )
        }

        #expect(fixture.lifecycle.drainedRuns.isEmpty)
        #expect(fixture.runtime.retiredRuns.isEmpty)
        #expect(fixture.store.terminalCommands.isEmpty)
    }

    @Test
    func recoveryInProgressRefusesNewRuntimeStart() async throws {
        let fixture = try InvestigationCoordinatorFixture()
        let gate = InvestigationProbeExecutionGate()
        fixture.store.recoveryGate = gate
        let coordinator = fixture.coordinator()

        let recovery = Task {
            try await coordinator.recover(
                now: fixture.now,
                limit: 10
            )
        }
        await gate.waitUntilStarted()

        await #expect(throws: InvestigationCoordinatorError.runAlreadyActive) {
            _ = try await coordinator.start(fixture.admission())
        }

        await gate.release()
        #expect(try await recovery.value.isEmpty)
        #expect(fixture.store.admissionCount == 0)
        #expect(fixture.runtime.startRequests.isEmpty)
    }

    @Test
    func recoveryNeverStartsOrResumesOldRuntimeThread() async throws {
        let fixture = try InvestigationCoordinatorFixture()
        fixture.store.recoveryRecords = [
            InvestigationRecoveryCandidate(
                investigationID: fixture.session.id,
                runID: fixture.session.runID,
                state: .running,
                stage: .verify,
                terminalCause: nil,
                plan: fixture.plan,
                updatedAt: fixture.now,
                expiresAt: fixture.now.addingTimeInterval(3_600)
            ),
        ]
        try fixture.store.primeRecoveryState(
            state: .running,
            stage: .verify
        )

        let recovered = try await fixture.coordinator().recover(
            now: fixture.now,
            limit: 10
        )

        #expect(recovered.count == 1)
        #expect(recovered[0].investigation.state == .blocked)
        #expect(fixture.runtime.startRequests.isEmpty)
        #expect(fixture.runtime.interrupts.isEmpty)
        #expect(fixture.lifecycle.drainedRuns == [fixture.session.runID])
        #expect(fixture.runtime.retiredRuns == [fixture.session.runID])
        #expect(fixture.store.recoveryRecords.isEmpty)
        #expect(
            fixture.store.terminalCommands[0].cause
                == .runtimeTerminalUnobserved
        )
    }

    @Test
    func recoveryRetiresExact24HourCrashResidueAndIsIdempotent()
        async throws
    {
        let fixture = try InvestigationCoordinatorFixture()
        let recoveryNow = fixture.now.addingTimeInterval(24 * 60 * 60)
        fixture.store.recoveryRecords = [
            InvestigationRecoveryCandidate(
                investigationID: fixture.session.id,
                runID: fixture.session.runID,
                state: .running,
                stage: .verify,
                terminalCause: nil,
                plan: fixture.plan,
                updatedAt: fixture.now,
                expiresAt: recoveryNow.addingTimeInterval(3_600)
            ),
        ]
        try fixture.store.primeRecoveryState(
            state: .running,
            stage: .verify
        )
        let coordinator = fixture.coordinator()

        let first = try await coordinator.recover(
            now: recoveryNow,
            limit: 10
        )
        let replay = try await coordinator.recover(
            now: recoveryNow,
            limit: 10
        )

        #expect(first.count == 1)
        #expect(replay.isEmpty)
        #expect(fixture.lifecycle.drainedRuns == [fixture.session.runID])
        #expect(fixture.runtime.retiredRuns == [fixture.session.runID])
        #expect(fixture.runtime.startRequests.isEmpty)
    }

    @Test
    func recoveryRequiresProbeWorkerDrainBeforeArtifactRetirement()
        async throws
    {
        let fixture = try InvestigationCoordinatorFixture()
        fixture.lifecycle.result = InvestigationLifecycleDrainResultV1(
            auditSessionEmpty: true,
            managedProxyOwnerEmpty: true,
            probeWorkerEmpty: false
        )
        fixture.store.recoveryRecords = [
            InvestigationRecoveryCandidate(
                investigationID: fixture.session.id,
                runID: fixture.session.runID,
                state: .running,
                stage: .verify,
                terminalCause: nil,
                plan: fixture.plan,
                updatedAt: fixture.now,
                expiresAt: fixture.now.addingTimeInterval(3_600)
            ),
        ]
        try fixture.store.primeRecoveryState(
            state: .running,
            stage: .verify
        )

        let recovered = try await fixture.coordinator().recover(
            now: fixture.now,
            limit: 10
        )

        #expect(recovered.count == 1)
        #expect(recovered[0].investigation.state == .blocked)
        #expect(fixture.runtime.retiredRuns.isEmpty)
        #expect(
            fixture.store.terminalCommands[0].cause
                == .lifecycleDrainUnconfirmed
        )
    }

    @Test
    func recoveryArtifactFailurePersistsTerminalFailureNotLifecycleFailure()
        async throws
    {
        let fixture = try InvestigationCoordinatorFixture()
        fixture.runtime.drainError = InvestigationRuntimeError.artifactFailed
        fixture.store.recoveryRecords = [
            InvestigationRecoveryCandidate(
                investigationID: fixture.session.id,
                runID: fixture.session.runID,
                state: .terminalBarrier,
                stage: .verify,
                terminalCause: .userStopped,
                plan: fixture.plan,
                updatedAt: fixture.now,
                expiresAt: fixture.now.addingTimeInterval(3_600)
            ),
        ]
        try fixture.store.primeRecoveryState(
            state: .terminalBarrier,
            stage: .verify
        )

        let recovered = try await fixture.coordinator().recover(
            now: fixture.now,
            limit: 10
        )

        #expect(recovered.count == 1)
        #expect(recovered[0].investigation.state == .failed)
        #expect(recovered[0].report == nil)
        #expect(
            fixture.store.terminalCommands[0].cause
                == .terminalPersistenceFailed
        )
    }

    @Test
    func artifactRetirementFailurePersistsFailedZeroReport() async throws {
        let fixture = try InvestigationCoordinatorFixture()
        fixture.runtime.drainError = InvestigationRuntimeError.artifactFailed
        let coordinator = fixture.coordinator()
        _ = try await coordinator.start(fixture.admission())
        try await fixture.startAndFinishRootTurn(on: coordinator)
        _ = try await coordinator.requestPause(
            investigationID: fixture.session.id,
            runID: fixture.session.runID
        )

        await #expect(
            throws: InvestigationCoordinatorError.terminalNotReady
        ) {
            _ = try await coordinator.settle(
                investigationID: fixture.session.id,
                runID: fixture.session.runID
            )
        }
        #expect(fixture.store.terminalCommands.isEmpty)
        fixture.clock.advance(by: .seconds(45))
        let result = try await coordinator.settle(
            investigationID: fixture.session.id,
            runID: fixture.session.runID
        )

        #expect(result.investigation.state == .failed)
        #expect(result.report == nil)
        #expect(
            fixture.store.terminalCommands[0].cause
                == .terminalPersistenceFailed
        )
    }

    @Test
    func recoveryPreservesStoredTerminalCauseInSummary() async throws {
        let fixture = try InvestigationCoordinatorFixture()
        fixture.store.recoveryRecords = [
            InvestigationRecoveryCandidate(
                investigationID: fixture.session.id,
                runID: fixture.session.runID,
                state: .terminalBarrier,
                stage: .verify,
                terminalCause: .userStopped,
                plan: fixture.plan,
                updatedAt: fixture.now,
                expiresAt: fixture.now.addingTimeInterval(3_600)
            ),
        ]
        try fixture.store.primeRecoveryState(
            state: .terminalBarrier,
            stage: .verify
        )

        _ = try await fixture.coordinator().recover(
            now: fixture.now,
            limit: 10
        )

        let command = try #require(fixture.store.terminalCommands.first)
        #expect(command.cause == .userStopped)
        #expect(
            command.budgetEvents.first?.payload.dimension?.rawValue
                == InvestigationTerminalCause.userStopped.rawValue
        )
    }
}
