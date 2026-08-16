import Foundation
import Testing
import StornautCore
@testable import StornautInvestigation

@Suite("Investigation scientific coordinator loop")
struct InvestigationScientificLoopTests {
    @Test
    func strictWireAndVerifiedCoverageProduceFinalTerminalTruth()
        async throws
    {
        let fixture = try InvestigationCoordinatorFixture()
        let coordinator = fixture.coordinator()
        _ = try await coordinator.start(fixture.admission())
        try await coordinator.acceptAppServerLine(
            investigationID: fixture.session.id,
            runID: fixture.session.runID,
            line: fixture.rootStartedLine()
        )
        _ = try await coordinator.startTurn(
            investigationID: fixture.session.id,
            runID: fixture.session.runID,
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            contextBytes: fixture.initialContextBytes
        )
        for line in [
            fixture.turnStartedLine(),
            fixture.tokenUsageLine(total: 120),
            fixture.finalEnvelopeLine(),
            fixture.turnCompletedLine(),
        ] {
            try await coordinator.acceptAppServerLine(
                investigationID: fixture.session.id,
                runID: fixture.session.runID,
                line: line
            )
        }

        let progress = try await coordinator.acceptScientificDelta(
            investigationID: fixture.session.id,
            runID: fixture.session.runID,
            delta: InvestigationScientificDeltaV1(
                id: DomainToken(rawValue: "delta-coverage-task38")!,
                sourceThreadID: fixture.root.id,
                sourceTurnID: fixture.rootTurnID,
                resolvedTargetIDs: fixture.plan.targets.map(\.id),
                remainingUnknown: .measured(ByteCount(0)!),
                stepResult: .verifiedGain
            )
        )
        #expect(progress.coveragePermille == 1_000)
        #expect(progress.stage == .buildPlan)
        #expect(progress.stopEvaluation == .stop(.coverageReached))

        let result = try await coordinator.settle(
            investigationID: fixture.session.id,
            runID: fixture.session.runID
        )

        #expect(result.investigation.state == .completed)
        #expect(result.report?.kind == .final)
        let command = try #require(fixture.store.terminalCommands.first)
        #expect(command.cause == .coverageReached)
        #expect(
            command.budgetEvents.map(\.ordinal)
                == Array(0..<UInt64(command.budgetEvents.count))
        )
        #expect(
            command.budgetEvents.map(\.payload.dimension?.rawValue)
                .contains(InvestigationBudgetDimension.coordinatorTurns.rawValue)
        )
        #expect(
            command.budgetEvents.map(\.payload.dimension?.rawValue)
                .contains(
                    InvestigationBudgetDimension.observedTotalTokens.rawValue
                )
        )
    }

    @Test
    func coverageWithoutStrictTerminalEnvelopeFailsClosed() async throws {
        let fixture = try InvestigationCoordinatorFixture()
        let coordinator = fixture.coordinator()
        _ = try await coordinator.start(fixture.admission())
        try await fixture.startAndFinishRootTurn(on: coordinator)

        _ = try await coordinator.acceptScientificDelta(
            investigationID: fixture.session.id,
            runID: fixture.session.runID,
            delta: InvestigationScientificDeltaV1(
                id: DomainToken(rawValue: "delta-no-envelope-task38")!,
                sourceThreadID: fixture.root.id,
                sourceTurnID: fixture.rootTurnID,
                resolvedTargetIDs: fixture.plan.targets.map(\.id),
                remainingUnknown: .measured(ByteCount(0)!),
                stepResult: .verifiedGain
            )
        )
        let result = try await coordinator.settle(
            investigationID: fixture.session.id,
            runID: fixture.session.runID
        )

        #expect(result.investigation.state == .blocked)
        #expect(result.report == nil)
        #expect(fixture.store.terminalCommands[0].cause == .protocolLost)
    }

    @Test
    func exactWallClockLimitClosesBeforeTurnReservation() async throws {
        let fixture = try InvestigationCoordinatorFixture()
        let coordinator = fixture.coordinator()
        _ = try await coordinator.start(fixture.admission())
        try await coordinator.acceptAppServerLine(
            investigationID: fixture.session.id,
            runID: fixture.session.runID,
            line: fixture.rootStartedLine()
        )
        fixture.clock.advance(by: .seconds(600))

        await #expect(
            throws: InvestigationCoordinatorError.scientificAdmissionClosed
        ) {
            try await coordinator.startTurn(
                investigationID: fixture.session.id,
                runID: fixture.session.runID,
                threadID: fixture.root.id,
                turnID: fixture.rootTurnID,
                contextBytes: fixture.initialContextBytes
            )
        }
        let closing = try await coordinator.requestStop(
            investigationID: fixture.session.id,
            runID: fixture.session.runID
        )
        #expect(closing.primaryCause == .budgetExhausted)
        #expect(fixture.runtime.turnStartRequests.isEmpty)
    }

    @Test
    func probeExecutionUsesInjectedOperationalOwnerAndExactUsage()
        async throws
    {
        let fixture = try InvestigationCoordinatorFixture()
        fixture.probe.results = [
            .failure(.pathDenied),
        ]
        fixture.probe.storedUsage = ProbeBudgetUsage(
            callCount: 1,
            readBytes: 0,
            outputBytes: 96
        )
        let coordinator = fixture.coordinator()
        _ = try await coordinator.start(fixture.admission())
        try await fixture.startRootTurn(on: coordinator)

        let execution = try await coordinator.executeProbe(
            investigationID: fixture.session.id,
            runID: fixture.session.runID,
            sourceThreadID: fixture.root.id,
            sourceTurnID: fixture.rootTurnID,
            request: ProbeRequest(
                capability: .directorySummary,
                targetURL: URL(fileURLWithPath: "/tmp")
            )
        )

        #expect(execution.result == .failure(.pathDenied))
        #expect(execution.usage?.callCount == 1)
        #expect(fixture.probe.requests.count == 1)
        #expect(fixture.probe.preparedRuns == [fixture.session.runID])
    }

    @Test
    func outOfOrderProbeCompletionsCannotRegressCumulativeUsage()
        async throws
    {
        let fixture = try InvestigationCoordinatorFixture()
        let olderUsageGate = InvestigationProbeExecutionGate()
        fixture.probe.results = [
            .failure(.pathDenied),
            .failure(.pathDenied),
        ]
        fixture.probe.usageSnapshots = [
            ProbeBudgetUsage(
                callCount: 1,
                readBytes: 100,
                outputBytes: 200
            ),
            ProbeBudgetUsage(
                callCount: 2,
                readBytes: 200,
                outputBytes: 400
            ),
        ]
        fixture.probe.usageGates = [olderUsageGate, nil]
        let coordinator = fixture.coordinator()
        _ = try await coordinator.start(fixture.admission())
        try await fixture.startRootTurn(on: coordinator)

        let first = Task {
            try await coordinator.executeProbe(
                investigationID: fixture.session.id,
                runID: fixture.session.runID,
                sourceThreadID: fixture.root.id,
                sourceTurnID: fixture.rootTurnID,
                request: ProbeRequest(
                    capability: .directorySummary,
                    targetURL: URL(fileURLWithPath: "/tmp/first")
                )
            )
        }
        await olderUsageGate.waitUntilStarted()
        _ = try await coordinator.executeProbe(
            investigationID: fixture.session.id,
            runID: fixture.session.runID,
            sourceThreadID: fixture.root.id,
            sourceTurnID: fixture.rootTurnID,
            request: ProbeRequest(
                capability: .directorySummary,
                targetURL: URL(fileURLWithPath: "/tmp/second")
            )
        )
        await olderUsageGate.release()
        _ = try await first.value

        _ = try await coordinator.requestStop(
            investigationID: fixture.session.id,
            runID: fixture.session.runID
        )
        _ = try await coordinator.acceptTokenUsage(
            fixture.usage(total: 100, payload: "probe-usage-terminal")
        )
        try await coordinator.acceptTurnTerminal(
            investigationID: fixture.session.id,
            runID: fixture.session.runID,
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            payload: fixture.payload("probe-usage-terminal")
        )
        _ = try await coordinator.settle(
            investigationID: fixture.session.id,
            runID: fixture.session.runID
        )

        let events = try #require(
            fixture.store.terminalCommands.first?.budgetEvents
        )
        func amount(
            for dimension: InvestigationBudgetDimension
        ) -> UInt64? {
            events.first {
                $0.payload.dimension?.rawValue == dimension.rawValue
            }?.payload.amount
        }
        #expect(amount(for: .probeCalls) == 2)
        #expect(amount(for: .probeReadBytes) == 200)
        #expect(amount(for: .probeOutputBytes) == 400)
    }

    @Test
    func twoVerifiedNoGainTurnsCloseAtFocusedLimit() async throws {
        let fixture = try InvestigationCoordinatorFixture()
        let coordinator = fixture.coordinator()
        _ = try await coordinator.start(fixture.admission())
        try await fixture.startAndFinishRootTurn(on: coordinator)
        let first = try await coordinator.acceptScientificDelta(
            investigationID: fixture.session.id,
            runID: fixture.session.runID,
            delta: InvestigationScientificDeltaV1(
                id: DomainToken(rawValue: "delta-no-gain-one")!,
                sourceThreadID: fixture.root.id,
                sourceTurnID: fixture.rootTurnID,
                resolvedTargetIDs: [],
                remainingUnknown: .unmeasurable,
                stepResult: .verifiedNoGain
            )
        )
        #expect(first.stopEvaluation == .continueInvestigation)
        #expect(first.consecutiveNoGainSteps == 1)

        _ = try await coordinator.startTurn(
            investigationID: fixture.session.id,
            runID: fixture.session.runID,
            threadID: fixture.root.id,
            turnID: fixture.secondRootTurnID,
            contextBytes: fixture.initialContextBytes
        )
        try await coordinator.acceptTurnStarted(
            investigationID: fixture.session.id,
            runID: fixture.session.runID,
            threadID: fixture.root.id,
            turnID: fixture.secondRootTurnID,
            payload: fixture.payload("second-turn")
        )
        try await coordinator.acceptTurnTerminal(
            investigationID: fixture.session.id,
            runID: fixture.session.runID,
            threadID: fixture.root.id,
            turnID: fixture.secondRootTurnID,
            payload: fixture.payload("second-terminal")
        )

        let second = try await coordinator.acceptScientificDelta(
            investigationID: fixture.session.id,
            runID: fixture.session.runID,
            delta: InvestigationScientificDeltaV1(
                id: DomainToken(rawValue: "delta-no-gain-two")!,
                sourceThreadID: fixture.root.id,
                sourceTurnID: fixture.secondRootTurnID,
                resolvedTargetIDs: [],
                remainingUnknown: .unmeasurable,
                stepResult: .verifiedNoGain
            )
        )

        #expect(second.stopEvaluation == .stop(.noEvidenceGain))
        #expect(second.consecutiveNoGainSteps == 2)
        await #expect(
            throws: InvestigationCoordinatorError.scientificAdmissionClosed
        ) {
            try await coordinator.startTurn(
                investigationID: fixture.session.id,
                runID: fixture.session.runID,
                threadID: fixture.root.id,
                turnID: DomainToken(rawValue: "turn-third")!,
                contextBytes: fixture.initialContextBytes
            )
        }
    }
}
