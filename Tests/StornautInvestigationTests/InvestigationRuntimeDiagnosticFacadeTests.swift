import Foundation
import StornautCore
import Testing
@testable import StornautCodex
@testable import StornautInvestigation
@testable import StornautInvestigationRuntime

@Suite("Investigation runtime diagnostic facade")
struct InvestigationRuntimeDiagnosticFacadeTests {
    @Test
    func codexCompositionClaimsPreparedRootAndInjectsCanonicalInputOnce()
        async throws
    {
        let fixture = InteractiveCompositionFixture()
        let client = FakeInteractiveCodexSession(
            root: fixture.codexRoot,
            turnIDs: [
                "turn-server-first",
                "turn-server-second",
            ]
        )
        let adapter = InvestigationCodexSessionAdapter(client: client)

        try await adapter.prepareRoot(fixture.preparation)
        let root = try adapter.start(fixture.start)
        #expect(root.id == fixture.rootToken)
        #expect(root.sessionID == fixture.rootToken)

        #expect(throws: InvestigationCodexSessionAdapterError.invalidState) {
            _ = try adapter.start(fixture.start)
        }

        let first = try await adapter.startTurn(
            fixture.turnRequest(
                reservationTurnID: "turn-reservation-first",
                context: "first bounded turn context"
            )
        )
        let second = try await adapter.startTurn(
            fixture.turnRequest(
                reservationTurnID: "turn-reservation-second",
                context: "second bounded turn context"
            )
        )

        #expect(first.turnID.rawValue == "turn-server-first")
        #expect(second.turnID.rawValue == "turn-server-second")
        #expect(client.turnInputs == [
            [
                "canonical investigation prompt",
                "canonical investigation context",
                "first bounded turn context",
            ],
            ["second bounded turn context"],
        ])
        #expect(client.turnThreadIDs == [
            fixture.rootToken.rawValue,
            fixture.rootToken.rawValue,
        ])
    }

    @Test
    func codexCompositionMapsMetadataNotificationsInterruptAndRetirement()
        async throws
    {
        let fixture = InteractiveCompositionFixture()
        let notification = Data(
            "{\"method\":\"thread/started\"}\n".utf8
        )
        let client = FakeInteractiveCodexSession(
            root: fixture.codexRoot,
            turnIDs: ["turn-server-first"],
            notifications: [notification],
            metadata: CodexInteractiveThreadMetadata(
                id: "thread-child",
                parentThreadID: fixture.rootToken.rawValue,
                sessionID: fixture.rootToken.rawValue
            )
        )
        let adapter = InvestigationCodexSessionAdapter(client: client)
        try await adapter.prepareRoot(fixture.preparation)
        _ = try adapter.start(fixture.start)
        let turn = try await adapter.startTurn(
            fixture.turnRequest(
                reservationTurnID: "turn-reservation-first",
                context: "bounded turn context"
            )
        )

        #expect(
            try await adapter.nextValidatedAppServerLine(
                rootSessionID: fixture.rootToken
            ) == notification
        )
        let metadata = try await adapter.readThreadMetadata(
            threadID: DomainToken(rawValue: "thread-child")!,
            rootSessionID: fixture.rootToken
        )
        #expect(metadata.id.rawValue == "thread-child")
        #expect(metadata.parentThreadID == fixture.rootToken)
        #expect(metadata.sessionID == fixture.rootToken)

        try await adapter.interrupt(turn)
        try await adapter.retireArtifacts(
            investigationID: fixture.investigationID,
            runID: fixture.runID
        )

        #expect(client.interruptedTurns == [
            CodexInteractiveTurnIdentity(
                threadID: fixture.rootToken.rawValue,
                turnID: "turn-server-first"
            ),
        ])
        #expect(client.retireCount == 1)
        await #expect(
            throws: InvestigationCodexSessionAdapterError.invalidState
        ) {
            try await adapter.retireArtifacts(
                investigationID: fixture.investigationID,
                runID: fixture.runID
            )
        }
    }

    @Test
    func codexCompositionSerializesCanonicalTurnAdmission()
        async throws
    {
        let fixture = InteractiveCompositionFixture()
        let gate = InteractiveTurnGate()
        let client = FakeInteractiveCodexSession(
            root: fixture.codexRoot,
            turnIDs: ["turn-server-first"],
            turnGate: gate
        )
        let adapter = InvestigationCodexSessionAdapter(client: client)
        try await adapter.prepareRoot(fixture.preparation)
        _ = try adapter.start(fixture.start)

        let first = Task {
            try await adapter.startTurn(
                fixture.turnRequest(
                    reservationTurnID: "turn-reservation-first",
                    context: "first bounded turn context"
                )
            )
        }
        await gate.waitUntilStarted()

        await #expect(
            throws: InvestigationCodexSessionAdapterError.invalidState
        ) {
            _ = try await adapter.startTurn(
                fixture.turnRequest(
                    reservationTurnID: "turn-reservation-second",
                    context: "second bounded turn context"
                )
            )
        }

        await gate.release()
        #expect(try await first.value.turnID.rawValue == "turn-server-first")
        #expect(client.turnInputs == [[
            "canonical investigation prompt",
            "canonical investigation context",
            "first bounded turn context",
        ]])
    }

    @Test
    func facadePreparesServerOwnedRootBeforeStoreAdmission()
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

        #expect(session.prepareRootCount == 1)
        #expect(session.operationLog.prefix(2) == [
            "session.prepare-root",
            "session.claim-root",
        ])
    }

    @Test
    func productionTurnStartRemainsAsynchronousAtTheRuntimeBoundary()
        throws
    {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let protocolSource = try String(
            contentsOf: repositoryRoot.appending(
                path:
                    "Sources/StornautInvestigation/InvestigationRuntimeProtocols.swift"
            ),
            encoding: .utf8
        )
        let coordinatorSource = try String(
            contentsOf: repositoryRoot.appending(
                path:
                    "Sources/StornautInvestigation/InvestigationCoordinator.swift"
            ),
            encoding: .utf8
        )

        #expect(
            protocolSource.contains(
                """
                func startTurn(
                        _ request: InvestigationRuntimeTurnStartRequestV1
                    ) async throws -> InvestigationRuntimeTurnIdentityV1
                """
            )
        )
        #expect(
            coordinatorSource.contains(
                "runtimeIdentity = try await runtime.startTurn("
            )
        )
    }

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
    func failedTurnStartClosesDrainsAndRetiresTheRun() async throws {
        let fixture = try InvestigationCoordinatorFixture()
        let session = FakeProductionInvestigationSession(
            root: fixture.root,
            lines: [fixture.rootStartedLine()]
        )
        session.turnError = ProductionSessionTestError.turnStartFailed
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
        #expect(try await facade.forwardNextValidatedAppServerLine())

        await #expect(
            throws: ProductionSessionTestError.turnStartFailed
        ) {
            _ = try await facade.startTurn(
                threadID: fixture.root.id,
                turnID: fixture.rootTurnID,
                contextBytes: fixture.initialContextBytes
            )
        }

        #expect(fixture.lifecycle.drainedRuns == [fixture.session.runID])
        #expect(session.retiredRunIDs == [fixture.session.runID])
        await #expect(
            throws: InvestigationRuntimeDiagnosticFacadeError.noActiveRun
        ) {
            _ = try await facade.startTurn(
                threadID: fixture.root.id,
                turnID: fixture.rootTurnID,
                contextBytes: fixture.initialContextBytes
            )
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
    var turnError: Error?
    var lineError: Error?
    private var lines: [Data]
    private(set) var startRequests: [InvestigationRuntimeStartRequestV1] = []
    private(set) var turnRequests:
        [InvestigationRuntimeTurnStartRequestV1] = []
    private(set) var retiredRunIDs: [InvestigationRunID] = []
    private(set) var deliveredLineCount = 0
    private(set) var prepareRootCount = 0
    private(set) var operationLog: [String] = []

    init(root: InvestigationRuntimeRootV1, lines: [Data]) {
        self.root = root
        self.lines = lines
    }

    func prepareRoot(
        _ request: InvestigationRuntimeRootPreparationRequestV1
    ) async throws {
        try lock.withLock {
            prepareRootCount += 1
            operationLog.append("session.prepare-root")
            if let startError {
                throw startError
            }
        }
    }

    func start(
        _ request: InvestigationRuntimeStartRequestV1
    ) throws -> InvestigationRuntimeRootV1 {
        lock.withLock {
            startRequests.append(request)
            operationLog.append("session.claim-root")
            return root
        }
    }

    func startTurn(
        _ request: InvestigationRuntimeTurnStartRequestV1
    ) async throws -> InvestigationRuntimeTurnIdentityV1 {
        try lock.withLock {
            turnRequests.append(request)
            if let turnError {
                throw turnError
            }
            return request.identity
        }
    }

    func readThreadMetadata(
        threadID: DomainToken,
        rootSessionID: DomainToken
    ) async throws -> InvestigationRuntimeThreadMetadataV1 {
        throw ProductionSessionTestError.metadataUnavailable
    }

    func interrupt(
        _ turn: InvestigationRuntimeTurnIdentityV1
    ) async throws {}

    func retireArtifacts(
        investigationID: InvestigationID,
        runID: InvestigationRunID
    ) async throws {
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
    case turnStartFailed
    case lineReadFailed
    case metadataUnavailable
    case transitionFailed
}

private struct InteractiveCompositionFixture {
    let investigationID = InvestigationID(
        rawValue: "investigation-composition-fixture"
    )!
    let runID = InvestigationRunID(
        rawValue: "investigation-run-composition-fixture"
    )!
    let receiptID = DomainToken(
        rawValue: "receipt-composition-fixture"
    )!
    let rootToken = DomainToken(rawValue: "thread-root")!

    var codexRoot: CodexInteractiveRootIdentity {
        CodexInteractiveRootIdentity(
            id: rootToken.rawValue,
            sessionID: rootToken.rawValue
        )
    }

    var preparation: InvestigationRuntimeRootPreparationRequestV1 {
        InvestigationRuntimeRootPreparationRequestV1(
            investigationID: investigationID,
            runID: runID,
            receiptID: receiptID,
            schema: .collabToolCallV1
        )
    }

    var start: InvestigationRuntimeStartRequestV1 {
        InvestigationRuntimeStartRequestV1(
            investigationID: investigationID,
            runID: runID,
            receiptID: receiptID,
            schema: .collabToolCallV1,
            ephemeral: true,
            context: InvestigationRuntimeStartContextV1(
                promptText: "canonical investigation prompt",
                contextBytes: Data(
                    "canonical investigation context".utf8
                ),
                targetIDs: [
                    InvestigationTargetID(
                        rawValue: "target-composition-fixture"
                    )!,
                ]
            )
        )
    }

    func turnRequest(
        reservationTurnID: String,
        context: String
    ) -> InvestigationRuntimeTurnStartRequestV1 {
        InvestigationRuntimeTurnStartRequestV1(
            identity: InvestigationRuntimeTurnIdentityV1(
                investigationID: investigationID,
                runID: runID,
                threadID: rootToken,
                turnID: DomainToken(rawValue: reservationTurnID)!
            ),
            contextBytes: Data(context.utf8),
            reservedTurnCount: 1,
            reservedContextBytes: UInt64(context.utf8.count)
        )
    }
}

private final class FakeInteractiveCodexSession:
    CodexInteractiveSessionDriving,
    @unchecked Sendable
{
    private let lock = NSLock()
    private let root: CodexInteractiveRootIdentity
    private var turnIDs: [String]
    private var notifications: [Data]
    private let metadata: CodexInteractiveThreadMetadata?
    private(set) var turnInputs: [[String]] = []
    private(set) var turnThreadIDs: [String] = []
    private(set) var interruptedTurns: [CodexInteractiveTurnIdentity] = []
    private(set) var retireCount = 0
    private let turnGate: InteractiveTurnGate?

    init(
        root: CodexInteractiveRootIdentity,
        turnIDs: [String],
        notifications: [Data] = [],
        metadata: CodexInteractiveThreadMetadata? = nil,
        turnGate: InteractiveTurnGate? = nil
    ) {
        self.root = root
        self.turnIDs = turnIDs
        self.notifications = notifications
        self.metadata = metadata
        self.turnGate = turnGate
    }

    func prepareRoot() async throws -> CodexInteractiveRootIdentity {
        root
    }

    func startTurn(
        threadID: String,
        inputTexts: [String]
    ) async throws -> CodexInteractiveTurnIdentity {
        let identity = try lock.withLock {
            guard !turnIDs.isEmpty else {
                throw ProductionSessionTestError.startFailed
            }
            turnThreadIDs.append(threadID)
            turnInputs.append(inputTexts)
            return CodexInteractiveTurnIdentity(
                threadID: threadID,
                turnID: turnIDs.removeFirst()
            )
        }
        if let turnGate {
            await turnGate.arriveAndWait()
        }
        return identity
    }

    func readThread(
        threadID: String
    ) async throws -> CodexInteractiveThreadMetadata {
        try lock.withLock {
            guard let metadata, metadata.id == threadID else {
                throw ProductionSessionTestError.metadataUnavailable
            }
            return metadata
        }
    }

    func interrupt(
        _ identity: CodexInteractiveTurnIdentity
    ) async throws {
        lock.withLock {
            interruptedTurns.append(identity)
        }
    }

    func nextValidatedNotification() async throws -> Data {
        try lock.withLock {
            guard !notifications.isEmpty else {
                throw ProductionSessionTestError.lineReadFailed
            }
            return notifications.removeFirst()
        }
    }

    func retire() async throws {
        lock.withLock {
            retireCount += 1
        }
    }
}

private actor InteractiveTurnGate {
    private var started = false
    private var released = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func waitUntilStarted() async {
        guard !started else {
            return
        }
        await withCheckedContinuation {
            startWaiters.append($0)
        }
    }

    func arriveAndWait() async {
        started = true
        let waiters = startWaiters
        startWaiters.removeAll()
        waiters.forEach { $0.resume() }
        guard !released else {
            return
        }
        await withCheckedContinuation {
            releaseWaiters.append($0)
        }
    }

    func release() {
        released = true
        let waiters = releaseWaiters
        releaseWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }
}
