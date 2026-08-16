import Foundation
@testable import StornautCore
@testable import StornautInvestigation

final class InvestigationTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var storedNanoseconds: UInt64

    init(nanoseconds: UInt64 = 1_000_000_000) {
        storedNanoseconds = nanoseconds
    }

    var nowNanoseconds: UInt64 {
        lock.withLock { storedNanoseconds }
    }

    func advance(by duration: Duration) {
        let components = duration.components
        let seconds = UInt64(max(0, components.seconds))
        let nanoseconds = UInt64(
            max(0, components.attoseconds / 1_000_000_000)
        )
        lock.withLock {
            storedNanoseconds += seconds * 1_000_000_000 + nanoseconds
        }
    }
}

struct InvestigationCoordinatorFixture {
    let now = Date(timeIntervalSince1970: 1_800_100_000)
    let plan: InvestigationPlan
    let session: InvestigationStoredSession
    let receipt: InvestigationRuntimeReceiptV1
    let root: InvestigationRuntimeRootV1
    let clock: InvestigationTestClock
    let store: FakeInvestigationStore
    let runtime: FakeInvestigationRuntime
    let lifecycle: FakeInvestigationLifecycle
    let probe: FakeInvestigationProbe
    let idProvider: FakeInvestigationIDProvider
    let rootTurnID = DomainToken(rawValue: "turn-task38-root")!
    let secondRootTurnID = DomainToken(rawValue: "turn-task38-root-second")!
    let initialContextBytes = Data("bounded-turn-context".utf8)

    init() throws {
        let investigationID = InvestigationID(
            rawValue: "investigation-task38-fixture"
        )!
        let runID = InvestigationRunID(
            rawValue: "investigation-run-task38-fixture"
        )!
        let scanSessionID = ScanSessionID(
            rawValue: "scan-task38-fixture"
        )!
        let scanScopeID = ScanScopeID(
            rawValue: "scope-task38-fixture"
        )!
        let target = try InvestigationTarget(
            scanSessionID: scanSessionID,
            scanScopeID: scanScopeID,
            sourceBinding: .snapshot(
                SnapshotID(rawValue: "snapshot-task38-fixture")!
            ),
            kind: .unknownLargeConsumer,
            reasonKeys: [DomainToken(rawValue: "reason.task38")!],
            expectedAllocatedBytes: ByteCount(2_147_483_648),
            uncertaintyPermille: 900,
            relevancePermille: 800,
            investigationCostPermille: 500,
            createdAt: now
        )
        plan = try InvestigationPlan(
            id: investigationID,
            scanSessionID: scanSessionID,
            scanScopeID: scanScopeID,
            sourceFingerprint: try InvestigationFingerprint(
                validating: Data(repeating: 0x38, count: 32)
            ),
            budgetPreset: .focused,
            targets: [target],
            createdAt: now,
            expiresAt: now.addingTimeInterval(3_600),
            requestedCoveragePermille:
                InvestigationPlan.policyRequestedCoveragePermille,
            remainingUnknownByteThreshold:
                InvestigationPlan.policyRemainingUnknownByteThreshold,
            requiredCapabilities: InvestigationCapability.required
        )
        session = InvestigationStoredSession(
            id: investigationID,
            runID: runID,
            plan: plan,
            state: .ready,
            stage: .prioritize,
            sourceRowCount: 5,
            relevanceTokenCount: 1,
            createdAt: now,
            updatedAt: now,
            expiresAt: now.addingTimeInterval(3_600)
        )
        receipt = InvestigationRuntimeReceiptV1(
            id: DomainToken(rawValue: "runtime-receipt-task38")!,
            schema: .collabToolCallV1,
            capabilityTokens: InvestigationCapability.required
        )
        root = InvestigationRuntimeRootV1(
            id: DomainToken(rawValue: "thread-task38-root")!,
            sessionID: DomainToken(rawValue: "thread-task38-root")!
        )
        clock = InvestigationTestClock()
        store = FakeInvestigationStore(session: session)
        runtime = FakeInvestigationRuntime(root: root)
        lifecycle = FakeInvestigationLifecycle()
        probe = FakeInvestigationProbe()
        idProvider = FakeInvestigationIDProvider()
    }

    func admission() -> InvestigationStartAdmissionV1 {
        InvestigationStartAdmissionV1(
            id: DomainToken(rawValue: "start-admission-task38")!,
            investigationID: session.id,
            runID: session.runID,
            sourceFingerprint: plan.sourceFingerprint,
            planFingerprint: plan.fingerprint,
            targetSetFingerprint: plan.targetSetFingerprint,
            runtimeReceipt: receipt,
            disclosureReceiptID: DomainToken(
                rawValue: "disclosure-task38"
            )!,
            workflowReservationID: DomainToken(
                rawValue: "workflow-task38"
            )!,
            finalAdmissionID: DomainToken(
                rawValue: "final-gate-task38"
            )!,
            validBeforeNanoseconds: clock.nowNanoseconds + 1_000_000_000
        )
    }

    func coordinator() -> InvestigationCoordinator {
        InvestigationCoordinator(
            store: store,
            runtime: runtime,
            lifecycle: lifecycle,
            probe: probe,
            idProvider: idProvider,
            monotonicNow: { clock.nowNanoseconds }
        )
    }

    func payload(_ value: String) -> Data {
        Data("{\"fixture\":\"\(value)\"}".utf8)
    }

    func appServerLine(_ object: [String: Any]) -> Data {
        var data = try! JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
        data.append(0x0A)
        return data
    }

    func rootStartedLine() -> Data {
        appServerLine([
            "method": "thread/started",
            "params": [
                "thread": [
                    "id": root.id.rawValue,
                ],
            ],
        ])
    }

    func turnStartedLine(
        threadID: DomainToken? = nil,
        turnID: DomainToken? = nil
    ) -> Data {
        appServerLine([
            "method": "turn/started",
            "params": [
                "threadId": (threadID ?? root.id).rawValue,
                "turn": [
                    "id": (turnID ?? rootTurnID).rawValue,
                    "status": "inProgress",
                ],
            ],
        ])
    }

    func tokenUsageLine(
        total: Int,
        threadID: DomainToken? = nil,
        turnID: DomainToken? = nil
    ) -> Data {
        appServerLine([
            "method": "thread/tokenUsage/updated",
            "params": [
                "threadId": (threadID ?? root.id).rawValue,
                "turnId": (turnID ?? rootTurnID).rawValue,
                "tokenUsage": [
                    "total": [
                        "totalTokens": total,
                        "inputTokens": total / 2,
                        "cachedInputTokens": total / 4,
                        "outputTokens": total / 2,
                    ],
                    "last": [
                        "totalTokens": 10,
                        "inputTokens": 5,
                        "cachedInputTokens": 2,
                        "outputTokens": 5,
                    ],
                ],
            ],
        ])
    }

    func finalEnvelopeLine() -> Data {
        let targetID = plan.targets[0].id.rawValue
        let envelope: [String: Any] = [
            "protocolVersion": 2,
            "investigationID": session.id.rawValue,
            "runID": session.runID.rawValue,
            "summary": "Verified bounded advisory.",
            "coverage": [
                "investigatedTargetIDs": [targetID],
                "unresolvedTargets": [],
            ],
            "evidence": [
                [
                    "id": "evidence-task38",
                    "targetID": targetID,
                    "source": "probeBroker",
                    "summary": "Structured evidence.",
                    "publicURL": NSNull(),
                ],
            ],
            "findings": [
                [
                    "id": "finding-task38",
                    "targetID": targetID,
                    "summary": "The target was investigated.",
                    "evidenceIDs": ["evidence-task38"],
                    "confidence": "high",
                    "uncertainty": "Current facts remain advisory.",
                ],
            ],
            "candidateProposals": [],
            "capabilityDegradations": [],
        ]
        let text = String(
            decoding: try! JSONSerialization.data(
                withJSONObject: envelope,
                options: [.sortedKeys]
            ),
            as: UTF8.self
        )
        return appServerLine([
            "method": "item/completed",
            "params": [
                "threadId": root.id.rawValue,
                "turnId": rootTurnID.rawValue,
                "item": [
                    "id": "item-final-task38",
                    "type": "agentMessage",
                    "text": text,
                ],
            ],
        ])
    }

    func turnCompletedLine() -> Data {
        appServerLine([
            "method": "turn/completed",
            "params": [
                "threadId": root.id.rawValue,
                "turn": [
                    "id": rootTurnID.rawValue,
                    "status": "completed",
                ],
            ],
        ])
    }

    func usage(
        total: UInt64,
        payload: String
    ) -> InvestigationRuntimeTokenUsageEventV1 {
        InvestigationRuntimeTokenUsageEventV1(
            threadID: root.id,
            turnID: rootTurnID,
            total: InvestigationTokenUsage(
                totalTokens: total,
                inputTokens: total / 2,
                cachedInputTokens: total / 4,
                outputTokens: total / 2
            ),
            last: InvestigationTokenUsage(
                totalTokens: 10,
                inputTokens: 5,
                cachedInputTokens: 2,
                outputTokens: 5
            ),
            payload: self.payload(payload)
        )
    }

    func startRootTurn(
        on coordinator: InvestigationCoordinator
    ) async throws {
        try await coordinator.acceptRootStartedNotification(
            investigationID: session.id,
            runID: session.runID,
            root: root,
            payload: payload("root-started")
        )
        _ = try await coordinator.startTurn(
            investigationID: session.id,
            runID: session.runID,
            threadID: root.id,
            turnID: rootTurnID,
            contextBytes: initialContextBytes
        )
        try await coordinator.acceptTurnStarted(
            investigationID: session.id,
            runID: session.runID,
            threadID: root.id,
            turnID: rootTurnID,
            payload: payload("root-turn")
        )
    }

    func startAndFinishRootTurn(
        on coordinator: InvestigationCoordinator
    ) async throws {
        try await startRootTurn(on: coordinator)
        _ = try await coordinator.acceptTokenUsage(
            usage(total: 100, payload: "usage-100")
        )
        try await coordinator.acceptTurnTerminal(
            investigationID: session.id,
            runID: session.runID,
            threadID: root.id,
            turnID: rootTurnID,
            payload: payload("root-terminal")
        )
    }
}

final class FakeInvestigationStore:
    InvestigationStoreOwning,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var session: InvestigationStoredSession
    private(set) var admissionCount = 0
    private(set) var terminalCommands: [InvestigationTerminalCommand] = []
    private(set) var terminalExpectedRunStates:
        [InvestigationRunState] = []
    private(set) var terminalMaximumDurations: [UInt64] = []
    private(set) var operationLog: [String] = []
    var failureAfterOperation: Error?
    var transitionErrors: [Error] = []
    var terminalFailuresRemaining = 0
    var recoveryRecords: [InvestigationRecoveryCandidate] = []
    var recoveryGate: InvestigationProbeExecutionGate?

    init(session: InvestigationStoredSession) {
        self.session = session
    }

    func primeRecoveryState(
        state: InvestigationSessionState,
        stage: InvestigationStage
    ) throws {
        try lock.withLock {
            guard let runState = InvestigationRunState(
                rawValue: state.rawValue
            ) else {
                throw InvestigationPersistenceError.invalidCommand
            }
            _ = runState
            session = InvestigationStoredSession(
                id: session.id,
                runID: session.runID,
                plan: session.plan,
                state: state,
                stage: stage,
                sourceRowCount: session.sourceRowCount,
                relevanceTokenCount: session.relevanceTokenCount,
                createdAt: session.createdAt,
                updatedAt: session.updatedAt,
                expiresAt: session.expiresAt
            )
        }
    }

    func admitRuntimeStart(
        _ request: InvestigationRuntimeAdmissionRequestV1,
        operation: @Sendable (
            InvestigationRuntimeAdmissionContextV1
        ) throws -> InvestigationRuntimeAdmissionClosureResultV1
    ) async throws -> InvestigationRuntimeAdmissionResultV1 {
        let current = lock.withLock { session }
        guard request.investigationID == current.id,
              request.runID == current.runID,
              request.sourceFingerprint == current.plan.sourceFingerprint,
              request.planFingerprint == current.plan.fingerprint,
              request.targetSetFingerprint
                == current.plan.targetSetFingerprint
        else {
            throw InvestigationPersistenceError.conflictingReplay
        }
        let context = InvestigationRuntimeAdmissionContextV1(
            plan: current.plan,
            runID: current.runID,
            runtimeReceiptID: request.runtimeReceiptID,
            runtimeReceiptSchema: request.runtimeReceiptSchema
        )
        let closureResult = try operation(context)
        if let failureAfterOperation {
            throw failureAfterOperation
        }
        let running = lock.withLock {
            admissionCount += 1
            operationLog.append("runtime.admitted")
            session = InvestigationStoredSession(
                id: current.id,
                runID: current.runID,
                plan: current.plan,
                state: .running,
                stage: current.stage,
                sourceRowCount: current.sourceRowCount,
                relevanceTokenCount: current.relevanceTokenCount,
                createdAt: current.createdAt,
                updatedAt: request.startedAt,
                expiresAt: current.expiresAt
            )
            return session
        }
        return InvestigationRuntimeAdmissionResultV1(
            investigation: running,
            rootSessionID: closureResult.rootSessionID
        )
    }

    func transition(
        _ command: InvestigationRunTransitionCommand
    ) async throws -> InvestigationStoredSession {
        try lock.withLock {
            if !transitionErrors.isEmpty {
                throw transitionErrors.removeFirst()
            }
            guard session.id == command.investigationID,
                  session.runID == command.runID,
                  session.state.rawValue
                    == command.expectedRunState.rawValue
            else {
                throw InvestigationPersistenceError.conflictingReplay
            }
            operationLog.append("transition.\(command.runState.rawValue)")
            session = InvestigationStoredSession(
                id: session.id,
                runID: session.runID,
                plan: session.plan,
                state: command.sessionState,
                stage: command.stage,
                sourceRowCount: session.sourceRowCount,
                relevanceTokenCount: session.relevanceTokenCount,
                createdAt: session.createdAt,
                updatedAt: command.updatedAt,
                expiresAt: session.expiresAt
            )
            return session
        }
    }

    func settleTerminal(
        _ command: InvestigationTerminalCommand,
        expectedRunState: InvestigationRunState,
        maximumDurationNanoseconds: UInt64
    ) async throws -> InvestigationTerminalResult {
        try lock.withLock {
            terminalCommands.append(command)
            terminalExpectedRunStates.append(expectedRunState)
            terminalMaximumDurations.append(maximumDurationNanoseconds)
            guard session.state.rawValue == expectedRunState.rawValue else {
                throw InvestigationPersistenceError.conflictingReplay
            }
            if terminalFailuresRemaining > 0 {
                terminalFailuresRemaining -= 1
                throw InvestigationRuntimeError.terminalFailed
            }
            operationLog.append("transition.terminalBarrier")
            operationLog.append("terminal.\(command.cause)")
            session = InvestigationStoredSession(
                id: session.id,
                runID: session.runID,
                plan: session.plan,
                state: command.sessionState,
                stage: command.stage,
                sourceRowCount: session.sourceRowCount,
                relevanceTokenCount: session.relevanceTokenCount,
                createdAt: session.createdAt,
                updatedAt: command.terminalAt,
                expiresAt: session.expiresAt
            )
            recoveryRecords.removeAll {
                $0.investigationID == command.investigationID
                    && $0.runID == command.runID
            }
            operationLog.append("terminal.committed")
            return InvestigationTerminalResult(
                investigation: session,
                report: command.report.map {
                    InvestigationStoredReport(
                        investigationID: command.investigationID,
                        runID: command.runID,
                        id: $0.id,
                        kind: $0.kind,
                        createdAt: command.terminalAt,
                        payload: $0.payload
                    )
                }
            )
        }
    }

    func recoveryCandidates(
        now: Date,
        limit: Int
    ) async throws -> [InvestigationRecoveryCandidate] {
        if let recoveryGate {
            await recoveryGate.arriveAndWait()
        }
        return lock.withLock {
            Array(recoveryRecords.prefix(limit))
        }
    }

    func settleRecovery(
        _ command: InvestigationTerminalCommand,
        expectedRunState: InvestigationRunState,
        maximumDurationNanoseconds: UInt64
    ) async throws -> InvestigationTerminalResult {
        try await settleTerminal(
            command,
            expectedRunState: expectedRunState,
            maximumDurationNanoseconds: maximumDurationNanoseconds
        )
    }
}

final class FakeInvestigationRuntime:
    InvestigationRuntimeOwning,
    @unchecked Sendable
{
    private let lock = NSLock()
    var root: InvestigationRuntimeRootV1
    var startError: Error?
    var drainError: Error?
    var turnStartErrors: [Error] = []
    var returnedTurnIDs: [DomainToken] = []
    var returnedTurnIdentities: [InvestigationRuntimeTurnIdentityV1] = []
    var interruptErrors: [Error] = []
    var threadMetadata:
        [DomainToken: InvestigationRuntimeThreadMetadataV1] = [:]
    var onTurnStart: ((InvestigationRuntimeTurnStartRequestV1) -> Void)?
    private(set) var startRequests: [InvestigationRuntimeStartRequestV1] = []
    private(set) var turnStartRequests:
        [InvestigationRuntimeTurnStartRequestV1] = []
    private(set) var interrupts: [InvestigationRuntimeTurnIdentityV1] = []
    private(set) var retiredRuns: [InvestigationRunID] = []
    private(set) var operationLog: [String] = []

    init(root: InvestigationRuntimeRootV1) {
        self.root = root
    }

    func start(
        _ request: InvestigationRuntimeStartRequestV1
    ) throws -> InvestigationRuntimeRootV1 {
        try lock.withLock {
            startRequests.append(request)
            operationLog.append("runtime.start")
            if let startError {
                throw startError
            }
            return root
        }
    }

    func startTurn(
        _ request: InvestigationRuntimeTurnStartRequestV1
    ) throws -> InvestigationRuntimeTurnIdentityV1 {
        try lock.withLock {
            turnStartRequests.append(request)
            operationLog.append("runtime.turn.start")
            onTurnStart?(request)
            if !turnStartErrors.isEmpty {
                throw turnStartErrors.removeFirst()
            }
            if !returnedTurnIdentities.isEmpty {
                return returnedTurnIdentities.removeFirst()
            }
            return InvestigationRuntimeTurnIdentityV1(
                investigationID: request.identity.investigationID,
                runID: request.identity.runID,
                threadID: request.identity.threadID,
                turnID: returnedTurnIDs.isEmpty
                    ? request.identity.turnID
                    : returnedTurnIDs.removeFirst()
            )
        }
    }

    func readThreadMetadata(
        threadID: DomainToken,
        rootSessionID: DomainToken
    ) throws -> InvestigationRuntimeThreadMetadataV1 {
        try lock.withLock {
            guard let metadata = threadMetadata[threadID],
                  metadata.sessionID == rootSessionID
            else {
                throw InvestigationRuntimeError.threadReadFailed
            }
            return metadata
        }
    }

    func interrupt(
        _ turn: InvestigationRuntimeTurnIdentityV1
    ) throws {
        try lock.withLock {
            interrupts.append(turn)
            if !interruptErrors.isEmpty {
                throw interruptErrors.removeFirst()
            }
        }
    }

    func retireArtifacts(
        investigationID: InvestigationID,
        runID: InvestigationRunID
    ) throws {
        try lock.withLock {
            if let drainError {
                throw drainError
            }
            retiredRuns.append(runID)
        }
    }
}

final class FakeInvestigationLifecycle:
    InvestigationLifecycleOwning,
    @unchecked Sendable
{
    private let lock = NSLock()
    var result = InvestigationLifecycleDrainResultV1(
        auditSessionEmpty: true,
        managedProxyOwnerEmpty: true
    )
    var drainGate: InvestigationProbeExecutionGate?
    private(set) var drainedRuns: [InvestigationRunID] = []

    func drain(
        investigationID: InvestigationID,
        runID: InvestigationRunID
    ) async throws -> InvestigationLifecycleDrainResultV1 {
        let snapshot = lock.withLock {
            drainedRuns.append(runID)
            return (drainGate, result)
        }
        if let gate = snapshot.0 {
            await gate.arriveAndWait()
        }
        return snapshot.1
    }
}

final class FakeInvestigationProbe:
    InvestigationProbeOwning,
    @unchecked Sendable
{
    private let lock = NSLock()
    private(set) var preparedRuns: [InvestigationRunID] = []
    private(set) var requests: [(ProbeRequest, InvestigationRunID)] = []
    var results: [ProbeResult] = []
    var prepareError: Error?
    var storedUsage: ProbeBudgetUsage?
    var usageSnapshots: [ProbeBudgetUsage?] = []
    var usageGates: [InvestigationProbeExecutionGate?] = []
    var executionGate: InvestigationProbeExecutionGate?

    func prepare(
        runID: InvestigationRunID,
        limits: InvestigationBudgetLimits
    ) throws {
        try lock.withLock {
            if let prepareError {
                throw prepareError
            }
            preparedRuns.append(runID)
        }
    }

    func execute(
        _ request: ProbeRequest,
        runID: InvestigationRunID
    ) async -> ProbeResult {
        let execution = lock.withLock {
            requests.append((request, runID))
            return (
                executionGate,
                results.isEmpty
                    ? ProbeResult.failure(.accessFailed)
                    : results.removeFirst()
            )
        }
        if let gate = execution.0 {
            await gate.arriveAndWait()
        }
        return execution.1
    }

    func usage(
        runID: InvestigationRunID
    ) async -> ProbeBudgetUsage? {
        let snapshot = lock.withLock {
            (
                usageGates.isEmpty ? nil : usageGates.removeFirst(),
                usageSnapshots.isEmpty
                    ? storedUsage
                    : usageSnapshots.removeFirst()
            )
        }
        if let gate = snapshot.0 {
            await gate.arriveAndWait()
        }
        return snapshot.1
    }
}

actor InvestigationProbeExecutionGate {
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

enum InvestigationRuntimeError: Error, Equatable {
    case startFailed
    case turnStartFailed
    case threadReadFailed
    case interruptFailed
    case transitionFailed
    case artifactFailed
    case terminalFailed
}

final class FakeInvestigationIDProvider:
    InvestigationIDProviding,
    @unchecked Sendable
{
    private let lock = NSLock()
    private(set) var reportRequests:
        [(InvestigationID, InvestigationRunID)] = []

    func reportID(
        investigationID: InvestigationID,
        runID: InvestigationRunID
    ) throws -> InvestigationReportID {
        lock.withLock {
            reportRequests.append((investigationID, runID))
            return InvestigationReportID(
                rawValue: "investigation-report-task38-fixture"
            )!
        }
    }
}

struct InvestigationEventFixture {
    let identity: InvestigationBudgetIdentity
    let receipt: InvestigationRuntimeReceiptV1
    let root: InvestigationRuntimeRootV1
    let rootTurnID = DomainToken(rawValue: "turn-root")!
    let childTurnID = DomainToken(rawValue: "turn-child")!
    let spawnItemID = DomainToken(rawValue: "item-spawn")!
    let childID = DomainToken(rawValue: "thread-child")!

    init(schema: InvestigationCollaborationSchemaV1) throws {
        root = InvestigationRuntimeRootV1(
            id: DomainToken(rawValue: "thread-root")!,
            sessionID: DomainToken(rawValue: "thread-root")!
        )
        identity = InvestigationBudgetIdentity(
            investigationID: InvestigationID(
                rawValue: "investigation-event-fixture"
            )!,
            runID: InvestigationRunID(
                rawValue: "investigation-run-event-fixture"
            )!,
            rootSessionID: root.id
        )
        receipt = InvestigationRuntimeReceiptV1(
            id: DomainToken(rawValue: "receipt-event-fixture")!,
            schema: schema,
            capabilityTokens: InvestigationCapability.required
        )
    }

    func normalizer() -> InvestigationEventNormalizer {
        InvestigationEventNormalizer(
            identity: identity,
            receipt: receipt,
            limits: .forPreset(.focused)
        )
    }

    func payload(_ value: String) -> Data {
        Data("{\"fixture\":\"\(value)\"}".utf8)
    }

    func acceptRoot(
        on normalizer: inout InvestigationEventNormalizer
    ) throws {
        try normalizer.acceptRoot(root)
        try normalizer.acceptRootStartedNotification(
            root,
            payload: payload("root-started")
        )
    }

    func usage(
        total: UInt64,
        payload: String
    ) -> InvestigationRuntimeTokenUsageEventV1 {
        InvestigationRuntimeTokenUsageEventV1(
            threadID: root.id,
            turnID: rootTurnID,
            total: InvestigationTokenUsage(
                totalTokens: total,
                inputTokens: total / 2,
                cachedInputTokens: total / 4,
                outputTokens: total / 2
            ),
            last: InvestigationTokenUsage(
                totalTokens: 10,
                inputTokens: 5,
                cachedInputTokens: 2,
                outputTokens: 5
            ),
            payload: self.payload(payload)
        )
    }

    func spawnEvent(payload: String) -> InvestigationRuntimeItemEventV1 {
        InvestigationRuntimeItemEventV1(
            threadID: root.id,
            turnID: rootTurnID,
            itemID: spawnItemID,
            type: receipt.schema.itemType,
            tool: receipt.schema.spawnTool,
            senderThreadID: root.id,
            childThreadIDs: [childID],
            mcpReadOnly: nil,
            payload: self.payload(payload)
        )
    }

    var childMetadata: InvestigationRuntimeThreadMetadataV1 {
        InvestigationRuntimeThreadMetadataV1(
            id: childID,
            parentThreadID: root.id,
            sessionID: root.id
        )
    }
}
