import Foundation
import StornautCore
import Testing
@testable import StornautInvestigation

@Suite("Investigation runtime diagnostic facade")
struct InvestigationRuntimeDiagnosticFacadeTests {
    @Test
    func validatedSessionEventsDriveTheClosedCoordinator()
        async throws
    {
        let fixture = try InvestigationCoordinatorFixture()
        let session = FakeProductionInvestigationSession(
            root: fixture.root,
            lines: [
                fixture.rootStartedLine(),
                fixture.turnStartedLine(),
                fixture.tokenUsageLine(total: 120),
                fixture.finalEnvelopeLine(),
                fixture.turnCompletedLine(),
            ]
        )
        let facade = InvestigationRuntimeDiagnosticFacade(
            store: fixture.store,
            session: session,
            lifecycle: fixture.lifecycle,
            probe: fixture.probe,
            idProvider: fixture.idProvider,
            monotonicNow: { fixture.clock.nowNanoseconds },
            wallNow: { fixture.now }
        )

        let started = try await facade.start(fixture.admission())
        #expect(started.rootSessionID == fixture.root.sessionID)
        #expect(session.startRequests.count == 1)
        #expect(
            session.startRequests[0].investigationID
                == fixture.session.id
        )
        #expect(
            session.startRequests[0].context.targetIDs
                == fixture.plan.targets.map(\.id)
        )

        #expect(
            try await facade.forwardNextValidatedAppServerLine()
        )
        _ = try await facade.startTurn(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            contextBytes: fixture.initialContextBytes
        )
        while try await facade.forwardNextValidatedAppServerLine() {}

        let progress = try await facade.acceptScientificDelta(
            InvestigationScientificDeltaV1(
                id: DomainToken(rawValue: "delta-task39-facade")!,
                sourceThreadID: fixture.root.id,
                sourceTurnID: fixture.rootTurnID,
                resolvedTargetIDs: fixture.plan.targets.map(\.id),
                remainingUnknown: .measured(ByteCount(0)!),
                stepResult: .verifiedGain
            )
        )
        #expect(progress.stopEvaluation == .stop(.coverageReached))

        let terminal = try await facade.settle()

        #expect(terminal.investigation.state == .completed)
        #expect(terminal.report?.kind == .final)
        #expect(session.turnRequests.count == 1)
        #expect(session.retiredRunIDs == [fixture.session.runID])
    }

    @Test
    func noValidatedLineDoesNotSynthesizeCoordinatorEvidence()
        async throws
    {
        let fixture = try InvestigationCoordinatorFixture()
        let session = FakeProductionInvestigationSession(
            root: fixture.root,
            lines: []
        )
        let facade = InvestigationRuntimeDiagnosticFacade(
            store: fixture.store,
            session: session,
            lifecycle: fixture.lifecycle,
            probe: fixture.probe,
            idProvider: fixture.idProvider,
            monotonicNow: { fixture.clock.nowNanoseconds },
            wallNow: { fixture.now }
        )
        _ = try await facade.start(fixture.admission())

        #expect(
            try await facade.forwardNextValidatedAppServerLine() == false
        )
        #expect(session.deliveredLineCount == 0)
        #expect(fixture.store.terminalCommands.isEmpty)
    }

    @Test
    func failedSessionStartDrainsAndRetiresWithoutRetainingFacadeState()
        async throws
    {
        let fixture = try InvestigationCoordinatorFixture()
        let session = FakeProductionInvestigationSession(
            root: fixture.root,
            lines: []
        )
        session.startError = ProductionSessionTestError.startFailed
        let facade = InvestigationRuntimeDiagnosticFacade(
            store: fixture.store,
            session: session,
            lifecycle: fixture.lifecycle,
            probe: fixture.probe,
            idProvider: fixture.idProvider,
            monotonicNow: { fixture.clock.nowNanoseconds },
            wallNow: { fixture.now }
        )

        await #expect(throws: ProductionSessionTestError.startFailed) {
            _ = try await facade.start(fixture.admission())
        }

        #expect(fixture.lifecycle.drainedRuns == [fixture.session.runID])
        #expect(session.retiredRunIDs == [fixture.session.runID])
        await #expect(
            throws: InvestigationRuntimeDiagnosticFacadeError.noActiveRun
        ) {
            _ = try await facade.forwardNextValidatedAppServerLine()
        }
    }

    @Test
    func failedLineReadClosesDrainsAndRetiresTheRun() async throws {
        let fixture = try InvestigationCoordinatorFixture()
        let session = FakeProductionInvestigationSession(
            root: fixture.root,
            lines: []
        )
        session.lineError = ProductionSessionTestError.lineReadFailed
        let facade = InvestigationRuntimeDiagnosticFacade(
            store: fixture.store,
            session: session,
            lifecycle: fixture.lifecycle,
            probe: fixture.probe,
            idProvider: fixture.idProvider,
            monotonicNow: { fixture.clock.nowNanoseconds },
            wallNow: { fixture.now }
        )
        _ = try await facade.start(fixture.admission())

        await #expect(
            throws: ProductionSessionTestError.lineReadFailed
        ) {
            _ = try await facade.forwardNextValidatedAppServerLine()
        }

        #expect(fixture.lifecycle.drainedRuns == [fixture.session.runID])
        #expect(session.retiredRunIDs == [fixture.session.runID])
        await #expect(
            throws: InvestigationRuntimeDiagnosticFacadeError.noActiveRun
        ) {
            _ = try await facade.forwardNextValidatedAppServerLine()
        }
    }

    @Test
    func failedLineReadRevokesFacadeWhenClosingPersistenceFails()
        async throws
    {
        let fixture = try InvestigationCoordinatorFixture()
        let session = FakeProductionInvestigationSession(
            root: fixture.root,
            lines: []
        )
        session.lineError = ProductionSessionTestError.lineReadFailed
        fixture.store.transitionErrors = [
            ProductionSessionTestError.transitionFailed,
        ]
        let facade = InvestigationRuntimeDiagnosticFacade(
            store: fixture.store,
            session: session,
            lifecycle: fixture.lifecycle,
            probe: fixture.probe,
            idProvider: fixture.idProvider,
            monotonicNow: { fixture.clock.nowNanoseconds },
            wallNow: { fixture.now }
        )
        _ = try await facade.start(fixture.admission())

        await #expect(
            throws: InvestigationCoordinatorError.runtimeCleanupUnconfirmed
        ) {
            _ = try await facade.forwardNextValidatedAppServerLine()
        }

        #expect(fixture.lifecycle.drainedRuns == [fixture.session.runID])
        #expect(session.retiredRunIDs == [fixture.session.runID])
        await #expect(
            throws: InvestigationRuntimeDiagnosticFacadeError.noActiveRun
        ) {
            _ = try await facade.forwardNextValidatedAppServerLine()
        }
    }
}

private final class FakeProductionInvestigationSession:
    InvestigationProductionSessionDriving,
    @unchecked Sendable
{
    private let lock = NSLock()
    let root: InvestigationRuntimeRootV1
    var startError: Error?
    var lineError: Error?
    private var lines: [Data]
    private(set) var startRequests: [InvestigationRuntimeStartRequestV1] = []
    private(set) var turnRequests:
        [InvestigationRuntimeTurnStartRequestV1] = []
    private(set) var retiredRunIDs: [InvestigationRunID] = []
    private(set) var deliveredLineCount = 0

    init(root: InvestigationRuntimeRootV1, lines: [Data]) {
        self.root = root
        self.lines = lines
    }

    func start(
        _ request: InvestigationRuntimeStartRequestV1
    ) throws -> InvestigationRuntimeRootV1 {
        try lock.withLock {
            startRequests.append(request)
            if let startError {
                throw startError
            }
            return root
        }
    }

    func startTurn(
        _ request: InvestigationRuntimeTurnStartRequestV1
    ) throws -> InvestigationRuntimeTurnIdentityV1 {
        lock.withLock {
            turnRequests.append(request)
            return request.identity
        }
    }

    func readThreadMetadata(
        threadID: DomainToken,
        rootSessionID: DomainToken
    ) throws -> InvestigationRuntimeThreadMetadataV1 {
        throw ProductionSessionTestError.metadataUnavailable
    }

    func interrupt(
        _ turn: InvestigationRuntimeTurnIdentityV1
    ) throws {}

    func retireArtifacts(
        investigationID: InvestigationID,
        runID: InvestigationRunID
    ) throws {
        lock.withLock {
            retiredRunIDs.append(runID)
        }
    }

    func nextValidatedAppServerLine(
        rootSessionID: DomainToken
    ) async throws -> Data? {
        try lock.withLock {
            if let lineError {
                throw lineError
            }
            guard rootSessionID == root.sessionID,
                  !lines.isEmpty
            else {
                return nil
            }
            deliveredLineCount += 1
            return lines.removeFirst()
        }
    }
}

private enum ProductionSessionTestError: Error, Equatable {
    case startFailed
    case lineReadFailed
    case metadataUnavailable
    case transitionFailed
}
