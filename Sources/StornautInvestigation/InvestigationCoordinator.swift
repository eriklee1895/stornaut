import Foundation
import StornautCodex
import StornautCore

public enum InvestigationCoordinatorError:
    Error,
    Sendable,
    Equatable
{
    case admissionConsumed
    case admissionExpired
    case admissionIdentityMismatch
    case conflictingScientificReplay
    case invalidScientificDelta
    case invalidMonotonicClock
    case runtimeIdentityLost
    case runtimeCleanupUnconfirmed
    case scientificAdmissionClosed
    case terminalEventWindowClosed
    case terminalDeadlineExceeded
    case noActiveRun
    case runAlreadyActive
    case runIdentityMismatch
    case terminalNotReady
}

public struct InvestigationScientificDeltaV1:
    Sendable,
    Equatable
{
    public let id: DomainToken
    public let sourceThreadID: DomainToken
    public let sourceTurnID: DomainToken
    public let resolvedTargetIDs: [InvestigationTargetID]
    public let remainingUnknown: InvestigationRemainingUnknown
    public let stepResult: InvestigationScientificStepResult

    public init(
        id: DomainToken,
        sourceThreadID: DomainToken,
        sourceTurnID: DomainToken,
        resolvedTargetIDs: [InvestigationTargetID],
        remainingUnknown: InvestigationRemainingUnknown,
        stepResult: InvestigationScientificStepResult
    ) {
        self.id = id
        self.sourceThreadID = sourceThreadID
        self.sourceTurnID = sourceTurnID
        self.resolvedTargetIDs = resolvedTargetIDs
        self.remainingUnknown = remainingUnknown
        self.stepResult = stepResult
    }
}

public struct InvestigationScientificProgressV1:
    Sendable,
    Equatable
{
    public let stage: InvestigationStage
    public let coveragePermille: UInt64
    public let consecutiveNoGainSteps: UInt64
    public let stopEvaluation: InvestigationStopEvaluation

    package init(
        stage: InvestigationStage,
        coveragePermille: UInt64,
        consecutiveNoGainSteps: UInt64,
        stopEvaluation: InvestigationStopEvaluation
    ) {
        self.stage = stage
        self.coveragePermille = coveragePermille
        self.consecutiveNoGainSteps = consecutiveNoGainSteps
        self.stopEvaluation = stopEvaluation
    }
}

public struct InvestigationProbeExecutionV1:
    Sendable,
    Equatable
{
    public let result: ProbeResult
    public let usage: ProbeBudgetUsage?

    package init(
        result: ProbeResult,
        usage: ProbeBudgetUsage?
    ) {
        self.result = result
        self.usage = usage
    }
}

public struct InvestigationStartResultV1: Sendable, Equatable {
    public let investigationID: InvestigationID
    public let runID: InvestigationRunID
    public let rootSessionID: DomainToken
    public let state: InvestigationSessionState

    package init(
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        rootSessionID: DomainToken,
        state: InvestigationSessionState
    ) {
        self.investigationID = investigationID
        self.runID = runID
        self.rootSessionID = rootSessionID
        self.state = state
    }
}

public struct InvestigationClosingResultV1: Sendable, Equatable {
    public let investigationID: InvestigationID
    public let runID: InvestigationRunID
    public let primaryCause: InvestigationTerminalCause
    public let t0Nanoseconds: UInt64

    package init(
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        primaryCause: InvestigationTerminalCause,
        t0Nanoseconds: UInt64
    ) {
        self.investigationID = investigationID
        self.runID = runID
        self.primaryCause = primaryCause
        self.t0Nanoseconds = t0Nanoseconds
    }
}

public actor InvestigationCoordinator {
    private struct ActiveRun {
        let investigationID: InvestigationID
        let runID: InvestigationRunID
        let plan: InvestigationPlan
        let root: InvestigationRuntimeRootV1
        let receipt: InvestigationRuntimeReceiptV1
        let runStartNanoseconds: UInt64
        let protocolContext: InvestigationProtocolContext
        var state: InvestigationRunState
        var stage: InvestigationStage
        var normalizer: InvestigationEventNormalizer
        var resolvedTargetIDs = Set<InvestigationTargetID>()
        var measurableRemainingUnknownBytes: ByteCount?
        var consecutiveNoGainSteps: UInt64 = 0
        var scientificDeltas:
            [DomainToken: InvestigationScientificDeltaV1] = [:]
        var scientificSourceTurns: [TurnKey: DomainToken] = [:]
        var latestProbeUsage: ProbeBudgetUsage?
        var latestAgentMessages: [TurnKey: Data] = [:]
        var barrier: InvestigationTerminalBarrier?
        var primaryCause: InvestigationTerminalCause?
        var retainedTerminalCommand: InvestigationTerminalCommand?
        var terminalBudgetDimension: InvestigationBudgetDimension?
        var lifecycleDrained = false
        var artifactsRetired = false

        mutating func mergeProbeUsage(
            _ usage: ProbeBudgetUsage?
        ) {
            guard let usage else {
                return
            }
            guard let latestProbeUsage else {
                self.latestProbeUsage = usage
                return
            }
            self.latestProbeUsage = ProbeBudgetUsage(
                callCount: max(
                    latestProbeUsage.callCount,
                    usage.callCount
                ),
                readBytes: max(
                    latestProbeUsage.readBytes,
                    usage.readBytes
                ),
                outputBytes: max(
                    latestProbeUsage.outputBytes,
                    usage.outputBytes
                )
            )
        }
    }

    private struct TurnKey: Sendable, Hashable {
        let threadID: DomainToken
        let turnID: DomainToken
    }

    private let store: any InvestigationStoreOwning
    private let runtime: any InvestigationRuntimeOwning
    private let lifecycle: any InvestigationLifecycleOwning
    private let probe: any InvestigationProbeOwning
    private let idProvider: any InvestigationIDProviding
    private let monotonicNow: @Sendable () -> UInt64
    private let wallNow: @Sendable () -> Date
    private let compressor: InvestigationContextCompressor
    private var activeRun: ActiveRun?
    private var startInProgress = false
    private var recoveryInProgress = false

    package init(
        store: any InvestigationStoreOwning,
        runtime: any InvestigationRuntimeOwning,
        lifecycle: any InvestigationLifecycleOwning,
        probe: any InvestigationProbeOwning,
        idProvider: any InvestigationIDProviding,
        monotonicNow: @escaping @Sendable () -> UInt64,
        wallNow: @escaping @Sendable () -> Date = Date.init,
        compressor: InvestigationContextCompressor =
            InvestigationContextCompressor()
    ) {
        self.store = store
        self.runtime = runtime
        self.lifecycle = lifecycle
        self.probe = probe
        self.idProvider = idProvider
        self.monotonicNow = monotonicNow
        self.wallNow = wallNow
        self.compressor = compressor
    }

    public func start(
        _ admission: InvestigationStartAdmissionV1
    ) async throws -> InvestigationStartResultV1 {
        guard activeRun == nil,
              !startInProgress,
              !recoveryInProgress
        else {
            throw InvestigationCoordinatorError.runAlreadyActive
        }
        startInProgress = true
        defer { startInProgress = false }
        try admission.consume(at: monotonicNow())
        let startedAt = wallNow()
        let request = admission.storeRequest(startedAt: startedAt)
        let receipt = admission.runtimeReceipt
        let monotonicNow = self.monotonicNow
        let runtime = self.runtime
        let probe = self.probe
        let compressor = self.compressor
        let startAttempt = InvestigationRuntimeStartAttempt()
        let compressedBox = InvestigationCompressedContextBox()
        let rootBox = InvestigationRuntimeRootBox()
        let runStartBox = InvestigationNanosecondsBox()

        do {
            let admitted = try await store.admitRuntimeStart(
                request
            ) { context in
                guard context.plan.id == admission.investigationID,
                      context.runID == admission.runID,
                      context.plan.sourceFingerprint
                        == admission.sourceFingerprint,
                      context.plan.fingerprint == admission.planFingerprint,
                      context.plan.targetSetFingerprint
                        == admission.targetSetFingerprint,
                      context.runtimeReceiptID == receipt.id,
                      context.runtimeReceiptSchema.rawValue
                        == receipt.schema.rawValue
                else {
                    throw InvestigationCoordinatorError
                        .admissionIdentityMismatch
                }
                let compressed = try compressor.compress(
                    plan: context.plan,
                    runID: context.runID,
                    receipt: receipt,
                    priorPartialSummary: nil
                )
                compressedBox.value = compressed
                try probe.prepare(
                    runID: context.runID,
                    limits: context.plan.budgetLimits
                )
                let prompt = try InvestigationPromptV1.load()
                runStartBox.value = monotonicNow()
                startAttempt.markAttempted()
                let root = try runtime.start(
                    InvestigationRuntimeStartRequestV1(
                        investigationID: context.plan.id,
                        runID: context.runID,
                        receiptID: receipt.id,
                        schema: receipt.schema,
                        ephemeral: true,
                        context: InvestigationRuntimeStartContextV1(
                            promptText: prompt,
                            contextBytes: compressed.contextBytes,
                            targetIDs: context.targetIDs
                        )
                    )
                )
                guard root.id == root.sessionID else {
                    throw InvestigationCoordinatorError.runtimeIdentityLost
                }
                rootBox.value = root
                return .started(rootSessionID: root.sessionID)
            }
            guard let compressed = compressedBox.value,
                  let root = rootBox.value,
                  let runStartNanoseconds = runStartBox.value
            else {
                throw InvestigationCoordinatorError.runtimeIdentityLost
            }
            activeRun = ActiveRun(
                investigationID: admission.investigationID,
                runID: admission.runID,
                plan: admitted.investigation.plan,
                root: root,
                receipt: receipt,
                runStartNanoseconds: runStartNanoseconds,
                protocolContext: compressed.protocolContext,
                state: .running,
                stage: admitted.investigation.stage,
                normalizer: InvestigationEventNormalizer(
                    identity: InvestigationBudgetIdentity(
                        investigationID: admission.investigationID,
                        runID: admission.runID,
                        rootSessionID: root.sessionID
                    ),
                    receipt: receipt,
                    limits: admitted.investigation.plan.budgetLimits
                ),
                terminalBudgetDimension: nil
            )
            try activeRun?.normalizer.acceptRoot(root)
            return InvestigationStartResultV1(
                investigationID: admission.investigationID,
                runID: admission.runID,
                rootSessionID: admitted.rootSessionID,
                state: admitted.investigation.state
            )
        } catch {
            if startAttempt.wasAttempted {
                try await cleanFailedRuntimeStart(
                    investigationID: admission.investigationID,
                    runID: admission.runID
                )
            }
            throw error
        }
    }

    package func acceptRootStartedNotification(
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        root: InvestigationRuntimeRootV1,
        payload: Data
    ) throws {
        try withActiveRun(
            investigationID: investigationID,
            runID: runID
        ) {
            try $0.normalizer.acceptRootStartedNotification(
                root,
                payload: payload
            )
        }
    }

    public func acceptAppServerLine(
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        line: Data
    ) async throws {
        do {
            var run = try requireActiveRun(
                investigationID: investigationID,
                runID: runID
            )
            try requireRuntimeEventWindow(run)
            let event = try InvestigationAppServerWireAdapter(
                receipt: run.receipt,
                root: run.root
            ).decode(line)
            switch event {
            case let .rootStarted(root, payload):
                try run.normalizer.acceptRootStartedNotification(
                    root,
                    payload: payload
                )
                activeRun = run
            case let .turnStarted(threadID, turnID, payload):
                try run.normalizer.acceptTurnStarted(
                    threadID: threadID,
                    turnID: turnID,
                    payload: payload
                )
                activeRun = run
            case let .itemStarted(item):
                let result = try run.normalizer.acceptItemStarted(item)
                let reachedCeiling = result.observedDirectToolStarts
                    >= run.normalizer.limits.observedDirectToolStarts
                activeRun = run
                if reachedCeiling, run.barrier == nil {
                    _ = try await requestClosing(
                        investigationID: investigationID,
                        runID: runID,
                        requestState: .stopRequested,
                        cause: .budgetExhausted,
                        budgetDimension: .observedDirectToolStarts
                    )
                }
            case let .itemCompleted(item):
                let result = try run.normalizer.acceptItemCompleted(item)
                for childID in result.admittedChildThreadIDs {
                    let metadata = try runtime.readThreadMetadata(
                        threadID: childID,
                        rootSessionID: run.root.sessionID
                    )
                    try run.normalizer.verifyChild(metadata)
                }
                activeRun = run
            case let .tokenUsage(usage):
                let result = try run.normalizer.acceptTokenUsage(usage)
                let reachedCeiling = result.quality == .observed
                    && (result.totalTokens ?? 0)
                        >= run.normalizer.limits.observedTotalTokens
                activeRun = run
                if reachedCeiling, run.barrier == nil {
                    _ = try await requestClosing(
                        investigationID: investigationID,
                        runID: runID,
                        requestState: .stopRequested,
                        cause: .budgetExhausted,
                        budgetDimension: .observedTotalTokens
                    )
                }
            case let .agentMessage(threadID, turnID, data):
                run.latestAgentMessages[
                    TurnKey(threadID: threadID, turnID: turnID)
                ] = data
                activeRun = run
            case let .turnTerminal(threadID, turnID, payload):
                let key = TurnKey(
                    threadID: threadID,
                    turnID: turnID
                )
                if let envelope = run.latestAgentMessages.removeValue(
                    forKey: key
                ) {
                    try run.normalizer.retainFinalEnvelope(
                        threadID: threadID,
                        turnID: turnID,
                        data: envelope
                    )
                }
                try run.normalizer.acceptTurnTerminal(
                    threadID: threadID,
                    turnID: turnID,
                    payload: payload
                )
                activeRun = run
            }
        } catch {
            if let current = activeRun,
               current.investigationID == investigationID,
               current.runID == runID,
               current.barrier == nil
            {
                _ = try? await requestClosing(
                    investigationID: investigationID,
                    runID: runID,
                    requestState: .terminalBarrier,
                    cause: .protocolLost
                )
            }
            throw error
        }
    }

    package func startTurn(
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        threadID: DomainToken,
        turnID: DomainToken,
        contextBytes: Data
    ) async throws -> InvestigationRuntimeTurnIdentityV1 {
        var run = try await requireScientificAdmission(
            investigationID: investigationID,
            runID: runID
        )
        if let dimension = run.normalizer.turnAdmissionExhaustion(
            contextByteCount: UInt64(contextBytes.count)
        ) {
            activeRun = run
            _ = try await requestClosing(
                investigationID: investigationID,
                runID: runID,
                requestState: .stopRequested,
                cause: .budgetExhausted,
                budgetDimension: dimension
            )
            throw InvestigationCoordinatorError.scientificAdmissionClosed
        }
        let hardUsage = try run.normalizer.reserveTurnStart(
            threadID: threadID,
            turnID: turnID,
            contextByteCount: UInt64(contextBytes.count)
        )
        activeRun = run
        let runtimeIdentity: InvestigationRuntimeTurnIdentityV1
        do {
            runtimeIdentity = try runtime.startTurn(
                InvestigationRuntimeTurnStartRequestV1(
                    identity: InvestigationRuntimeTurnIdentityV1(
                        investigationID: investigationID,
                        runID: runID,
                        threadID: threadID,
                        turnID: turnID
                    ),
                    contextBytes: contextBytes,
                    reservedTurnCount: hardUsage.coordinatorTurns,
                    reservedContextBytes: hardUsage.cumulativeContextBytes
                )
            )
        } catch {
            var retained = try requireActiveRun(
                investigationID: investigationID,
                runID: runID
            )
            try retained.normalizer.abandonTurnStart(
                threadID: threadID,
                turnID: turnID
            )
            activeRun = retained
            throw error
        }
        do {
            var retained = try requireActiveRun(
                investigationID: investigationID,
                runID: runID
            )
            try retained.normalizer.bindReservedTurn(
                reservationThreadID: threadID,
                reservationTurnID: turnID,
                runtimeIdentity: runtimeIdentity
            )
            activeRun = retained
            return runtimeIdentity
        } catch {
            var retained = try requireActiveRun(
                investigationID: investigationID,
                runID: runID
            )
            try retained.normalizer.abandonTurnStart(
                threadID: threadID,
                turnID: turnID
            )
            activeRun = retained
            _ = try? await requestClosing(
                investigationID: investigationID,
                runID: runID,
                requestState: .terminalBarrier,
                cause: .protocolLost
            )
            throw error
        }
    }

    package func executeProbe(
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        sourceThreadID: DomainToken,
        sourceTurnID: DomainToken,
        request: ProbeRequest
    ) async throws -> InvestigationProbeExecutionV1 {
        var run = try await requireScientificAdmission(
            investigationID: investigationID,
            runID: runID
        )
        guard run.normalizer.isActiveTurn(
            threadID: sourceThreadID,
            turnID: sourceTurnID
        ) else {
            throw InvestigationCoordinatorError.invalidScientificDelta
        }
        let lease: InvestigationProbeLease
        do {
            lease = try run.normalizer.acquireProbeLease()
        } catch InvestigationBudgetError.hardLimitExceeded {
            activeRun = run
            _ = try await requestClosing(
                investigationID: investigationID,
                runID: runID,
                requestState: .stopRequested,
                cause: .budgetExhausted,
                budgetDimension: .concurrentProbes
            )
            throw InvestigationCoordinatorError.scientificAdmissionClosed
        }
        activeRun = run
        let result = await probe.execute(request, runID: runID)
        let usage = await probe.usage(runID: runID)
        var resumed = try requireActiveRun(
            investigationID: investigationID,
            runID: runID
        )
        try resumed.normalizer.releaseProbeLease(lease)
        resumed.mergeProbeUsage(usage)
        activeRun = resumed

        let dimension: InvestigationBudgetDimension? = switch result {
        case .failure(.sessionCallBudgetExceeded):
            .probeCalls
        case .failure(.sessionReadBudgetExceeded):
            .probeReadBytes
        case .failure(.sessionOutputBudgetExceeded):
            .probeOutputBytes
        default:
            nil
        }
        if let dimension, resumed.barrier == nil {
            _ = try await requestClosing(
                investigationID: investigationID,
                runID: runID,
                requestState: .stopRequested,
                cause: .budgetExhausted,
                budgetDimension: dimension
            )
        }
        return InvestigationProbeExecutionV1(
            result: result,
            usage: usage
        )
    }

    package func acceptScientificDelta(
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        delta: InvestigationScientificDeltaV1
    ) async throws -> InvestigationScientificProgressV1 {
        var run = try requireActiveRun(
            investigationID: investigationID,
            runID: runID
        )
        if let prior = run.scientificDeltas[delta.id] {
            guard prior == delta else {
                throw InvestigationCoordinatorError
                    .conflictingScientificReplay
            }
            return scientificProgress(
                run: run,
                evaluation: try evaluateStop(run)
            )
        }
        run = try await requireScientificAdmission(
            investigationID: investigationID,
            runID: runID
        )
        guard run.normalizer.isTerminalTurn(
            threadID: delta.sourceThreadID,
            turnID: delta.sourceTurnID
        ) else {
            throw InvestigationCoordinatorError.invalidScientificDelta
        }
        let sourceTurn = TurnKey(
            threadID: delta.sourceThreadID,
            turnID: delta.sourceTurnID
        )
        guard run.scientificSourceTurns[sourceTurn] == nil else {
            throw InvestigationCoordinatorError.invalidScientificDelta
        }
        guard Set(delta.resolvedTargetIDs).count
                == delta.resolvedTargetIDs.count,
              Set(delta.resolvedTargetIDs).isSubset(
                  of: Set(run.plan.targets.map(\.id))
              )
        else {
            throw InvestigationCoordinatorError.invalidScientificDelta
        }
        let newResolved = Set(delta.resolvedTargetIDs)
            .subtracting(run.resolvedTargetIDs)
        let remainingGain: Bool = switch (
            run.measurableRemainingUnknownBytes,
            delta.remainingUnknown
        ) {
        case let (.some(prior), .measured(current)):
            current < prior
        case (nil, .measured):
            true
        case (_, .unmeasurable):
            false
        }
        let hasVerifiedGain = !newResolved.isEmpty || remainingGain
        switch delta.stepResult {
        case .verifiedGain:
            guard hasVerifiedGain else {
                throw InvestigationCoordinatorError.invalidScientificDelta
            }
        case .verifiedNoGain:
            guard !hasVerifiedGain,
                  Set(delta.resolvedTargetIDs)
                    .isSubset(of: run.resolvedTargetIDs)
            else {
                throw InvestigationCoordinatorError.invalidScientificDelta
            }
        case .invalid, .cancelled, .protocolFailed:
            guard !hasVerifiedGain, delta.resolvedTargetIDs.isEmpty else {
                throw InvestigationCoordinatorError.invalidScientificDelta
            }
        }
        try run.normalizer.recordScientificStep(delta.stepResult)
        if delta.stepResult == .verifiedGain {
            run.resolvedTargetIDs.formUnion(newResolved)
        }
        if case let .measured(bytes) = delta.remainingUnknown {
            run.measurableRemainingUnknownBytes = bytes
        }
        run.consecutiveNoGainSteps =
            run.normalizer.consecutiveNoGainSteps
        run.scientificDeltas[delta.id] = delta
        run.scientificSourceTurns[sourceTurn] = delta.id
        if delta.stepResult == .verifiedGain
            || delta.stepResult == .verifiedNoGain
        {
            run.stage = nextStage(
                current: run.stage,
                allTargetsResolved:
                    run.resolvedTargetIDs.count == run.plan.targets.count
            )
        }
        let evaluation = try evaluateStop(run)
        activeRun = run
        switch evaluation {
        case let .blocked(reason):
            _ = try await requestClosing(
                investigationID: investigationID,
                runID: runID,
                requestState: .terminalBarrier,
                cause: terminalCause(reason)
            )
        case .failed:
            _ = try await requestClosing(
                investigationID: investigationID,
                runID: runID,
                requestState: .terminalBarrier,
                cause: .terminalPersistenceFailed
            )
        case let .stop(reason):
            let mapped = stopCause(reason)
            _ = try await requestClosing(
                investigationID: investigationID,
                runID: runID,
                requestState: .stopRequested,
                cause: mapped.cause,
                budgetDimension: mapped.dimension
            )
        case .pause:
            _ = try await requestClosing(
                investigationID: investigationID,
                runID: runID,
                requestState: .pauseRequested,
                cause: .paused
            )
        case .continueInvestigation:
            break
        }
        return scientificProgress(run: run, evaluation: evaluation)
    }

    package func acceptTurnStarted(
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        threadID: DomainToken,
        turnID: DomainToken,
        payload: Data
    ) throws {
        try withActiveRun(
            investigationID: investigationID,
            runID: runID
        ) {
            try requireRuntimeEventWindow($0)
            try $0.normalizer.acceptTurnStarted(
                threadID: threadID,
                turnID: turnID,
                payload: payload
            )
        }
    }

    package func acceptItemStarted(
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        event: InvestigationRuntimeItemEventV1
    ) async throws -> InvestigationItemNormalizationV1 {
        var run = try requireActiveRun(
            investigationID: investigationID,
            runID: runID
        )
        try requireRuntimeEventWindow(run)
        let result = try run.normalizer.acceptItemStarted(event)
        let reachedCeiling = result.observedDirectToolStarts
            >= run.normalizer.limits.observedDirectToolStarts
        activeRun = run
        if reachedCeiling, run.barrier == nil {
            _ = try await requestClosing(
                investigationID: investigationID,
                runID: runID,
                requestState: .stopRequested,
                cause: .budgetExhausted,
                budgetDimension: .observedDirectToolStarts
            )
        }
        return result
    }

    package func acceptItemCompleted(
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        event: InvestigationRuntimeItemEventV1
    ) throws -> InvestigationItemNormalizationV1 {
        try withActiveRun(
            investigationID: investigationID,
            runID: runID
        ) {
            try requireRuntimeEventWindow($0)
            return try $0.normalizer.acceptItemCompleted(event)
        }
    }

    package func verifyChild(
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        metadata: InvestigationRuntimeThreadMetadataV1
    ) throws {
        try withActiveRun(
            investigationID: investigationID,
            runID: runID
        ) {
            try requireRuntimeEventWindow($0)
            try $0.normalizer.verifyChild(metadata)
        }
    }

    package func acceptTokenUsage(
        _ event: InvestigationRuntimeTokenUsageEventV1
    ) async throws -> InvestigationTokenNormalizationV1 {
        guard var run = activeRun else {
            throw InvestigationCoordinatorError.noActiveRun
        }
        try requireRuntimeEventWindow(run)
        let result = try run.normalizer.acceptTokenUsage(event)
        let reachedCeiling = result.quality == .observed
            && (result.totalTokens ?? 0)
                >= run.normalizer.limits.observedTotalTokens
        activeRun = run
        if reachedCeiling, run.barrier == nil {
            _ = try await requestClosing(
                investigationID: run.investigationID,
                runID: run.runID,
                requestState: .stopRequested,
                cause: .budgetExhausted,
                budgetDimension: .observedTotalTokens
            )
        }
        return result
    }

    package func acceptTurnTerminal(
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        threadID: DomainToken,
        turnID: DomainToken,
        payload: Data
    ) throws {
        try withActiveRun(
            investigationID: investigationID,
            runID: runID
        ) {
            try requireRuntimeEventWindow($0)
            try $0.normalizer.acceptTurnTerminal(
                threadID: threadID,
                turnID: turnID,
                payload: payload
            )
        }
    }

    package func retainFinalEnvelope(
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        threadID: DomainToken,
        turnID: DomainToken,
        data: Data
    ) throws {
        try withActiveRun(
            investigationID: investigationID,
            runID: runID
        ) {
            try requireRuntimeEventWindow($0)
            try $0.normalizer.retainFinalEnvelope(
                threadID: threadID,
                turnID: turnID,
                data: data
            )
        }
    }

    public func requestPause(
        investigationID: InvestigationID,
        runID: InvestigationRunID
    ) async throws -> InvestigationClosingResultV1 {
        try await requestClosing(
            investigationID: investigationID,
            runID: runID,
            requestState: .pauseRequested,
            cause: .paused
        )
    }

    public func requestStop(
        investigationID: InvestigationID,
        runID: InvestigationRunID
    ) async throws -> InvestigationClosingResultV1 {
        try await requestClosing(
            investigationID: investigationID,
            runID: runID,
            requestState: .stopRequested,
            cause: .userStopped
        )
    }

    public func cancel(
        investigationID: InvestigationID,
        runID: InvestigationRunID
    ) async throws -> InvestigationClosingResultV1 {
        try await requestClosing(
            investigationID: investigationID,
            runID: runID,
            requestState: .stopRequested,
            cause: .userCancelled
        )
    }

    package func failClosedTransport(
        investigationID: InvestigationID,
        runID: InvestigationRunID
    ) async throws {
        var closingError: Error?
        do {
            _ = try await requestClosing(
                investigationID: investigationID,
                runID: runID,
                requestState: .terminalBarrier,
                cause: .protocolLost
            )
        } catch {
            closingError = error
        }
        try await cleanFailedRuntimeStart(
            investigationID: investigationID,
            runID: runID
        )
        activeRun = nil
        if let closingError {
            throw closingError
        }
    }

    public func settle(
        investigationID: InvestigationID,
        runID: InvestigationRunID
    ) async throws -> InvestigationTerminalResult {
        var run = try requireActiveRun(
            investigationID: investigationID,
            runID: runID
        )
        guard run.barrier != nil,
              let primaryCause = run.primaryCause
        else {
            throw InvestigationCoordinatorError.terminalNotReady
        }
        let currentNanoseconds = monotonicNow()
        guard let barrier = run.barrier,
              currentNanoseconds >= barrier.t0Nanoseconds
        else {
            activeRun = run
            throw InvestigationCoordinatorError.invalidMonotonicClock
        }
        var phase = barrier.phase(atNanoseconds: currentNanoseconds)
        guard phase != .rollbackCleanup,
              phase != .rollbackUnconfirmed
        else {
            activeRun = run
            throw InvestigationCoordinatorError.terminalDeadlineExceeded
        }
        var elapsedNanoseconds =
            currentNanoseconds - barrier.t0Nanoseconds
        var remainingStoreNanoseconds =
            135_000_000_000 - elapsedNanoseconds
        if let retained = run.retainedTerminalCommand {
            let result = try await store.settleTerminal(
                retained,
                expectedRunState: run.state,
                maximumDurationNanoseconds: remainingStoreNanoseconds
            )
            activeRun = nil
            return result
        }

        if phase == .awaitingTerminalEvents,
           !run.normalizer.treeReadyForFinalization
        {
            activeRun = run
            throw InvestigationCoordinatorError.terminalNotReady
        }
        let drain = try? await lifecycle.drain(
            investigationID: investigationID,
            runID: runID
        )
        run = try requireActiveRun(
            investigationID: investigationID,
            runID: runID
        )
        let postDrainNanoseconds = monotonicNow()
        guard let postDrainBarrier = run.barrier,
              postDrainNanoseconds >= postDrainBarrier.t0Nanoseconds
        else {
            activeRun = run
            throw InvestigationCoordinatorError.invalidMonotonicClock
        }
        phase = postDrainBarrier.phase(
            atNanoseconds: postDrainNanoseconds
        )
        guard phase != .rollbackCleanup,
              phase != .rollbackUnconfirmed
        else {
            activeRun = run
            throw InvestigationCoordinatorError.terminalDeadlineExceeded
        }
        elapsedNanoseconds =
            postDrainNanoseconds - postDrainBarrier.t0Nanoseconds
        remainingStoreNanoseconds =
            135_000_000_000 - elapsedNanoseconds
        run.lifecycleDrained = drain?.provedEmpty == true
            && run.normalizer.activeProbeLeaseCount == 0
        if run.lifecycleDrained {
            do {
                try runtime.retireArtifacts(
                    investigationID: investigationID,
                    runID: runID
                )
                run.artifactsRetired = true
            } catch {
                run.artifactsRetired = false
            }
        }
        let mayFinalizeUnconfirmed =
            phase == .terminalPersistence
        if (!run.lifecycleDrained || !run.artifactsRetired),
           !mayFinalizeUnconfirmed
        {
            activeRun = run
            throw InvestigationCoordinatorError.terminalNotReady
        }

        let tree: InvestigationTreeFinalizationV1?
        do {
            tree = try run.normalizer.finalizeTree()
        } catch InvestigationEventError.liveDescendant,
                InvestigationEventError.unclassifiedDescendant {
            guard phase != .awaitingTerminalEvents else {
                activeRun = run
                throw InvestigationCoordinatorError.terminalNotReady
            }
            tree = nil
        }

        var effectiveCause: InvestigationTerminalCause
        var runState: InvestigationRunState
        var sessionState: InvestigationSessionState
        var reportKind: InvestigationReportKind?
        if tree == nil {
            effectiveCause = .runtimeTerminalUnobserved
            runState = .blocked
            sessionState = .blocked
            reportKind = nil
        } else if !run.lifecycleDrained {
            effectiveCause = .lifecycleDrainUnconfirmed
            runState = .blocked
            sessionState = .blocked
            reportKind = nil
        } else if !run.artifactsRetired {
            effectiveCause = .terminalPersistenceFailed
            runState = .failed
            sessionState = .failed
            reportKind = nil
        } else {
            effectiveCause = primaryCause
            switch primaryCause {
            case .paused:
                runState = .partial
                sessionState = .paused
                reportKind = .partial
            case .userStopped, .userCancelled:
                runState = .partial
                sessionState = .partial
                reportKind = .partial
            case .coverageReached,
                 .remainingUnknownBelowThreshold,
                 .budgetExhausted,
                 .noEvidenceGain:
                runState = .completed
                sessionState = .completed
                reportKind = .final
            case .containmentLost,
                 .lifecycleLost,
                 .runtimeIdentityLost,
                 .protocolLost,
                 .runtimeTerminalUnobserved,
                 .lifecycleDrainUnconfirmed:
                runState = .blocked
                sessionState = .blocked
                reportKind = nil
            case .terminalPersistenceFailed:
                runState = .failed
                sessionState = .failed
                reportKind = nil
            }
        }

        let terminalAt = wallNow()
        var report: InvestigationTerminalReportInput?
        if let kind = reportKind {
            do {
                if kind == .final,
                   run.normalizer.terminalEnvelopeData == nil
                {
                    throw InvestigationReportNormalizationError
                        .invalidEnvelope
                }
                report = try makeTerminalReport(
                    kind: kind,
                    run: run,
                    tree: tree
                )
            } catch {
                effectiveCause = .protocolLost
                runState = .blocked
                sessionState = .blocked
                reportKind = nil
                report = nil
            }
        }
        let command = try InvestigationTerminalCommand(
            investigationID: investigationID,
            runID: runID,
            runState: runState,
            sessionState: sessionState,
            stage: run.stage,
            cause: effectiveCause,
            report: report,
            budgetEvents: terminalBudgetEvents(
                run: run,
                cause: effectiveCause,
                tree: tree
            ),
            terminalAt: terminalAt
        )
        run.retainedTerminalCommand = command
        activeRun = run
        let result = try await store.settleTerminal(
            command,
            expectedRunState: run.state,
            maximumDurationNanoseconds: remainingStoreNanoseconds
        )
        activeRun = nil
        return result
    }

    public func recover(
        now: Date,
        limit: Int
    ) async throws -> [InvestigationTerminalResult] {
        guard activeRun == nil,
              !startInProgress,
              !recoveryInProgress
        else {
            throw InvestigationCoordinatorError.runAlreadyActive
        }
        recoveryInProgress = true
        defer { recoveryInProgress = false }
        let candidates = try await store.recoveryCandidates(
            now: now,
            limit: limit
        )
        var results: [InvestigationTerminalResult] = []
        for candidate in candidates {
            let drain = try? await lifecycle.drain(
                investigationID: candidate.investigationID,
                runID: candidate.runID
            )
            let provedEmpty = drain?.provedEmpty == true
            var artifactsRetired = false
            if provedEmpty {
                do {
                    try runtime.retireArtifacts(
                        investigationID: candidate.investigationID,
                        runID: candidate.runID
                    )
                    artifactsRetired = true
                } catch {}
            }
            let persistedCause: InvestigationTerminalCause
            let runState: InvestigationRunState
            let sessionState: InvestigationSessionState
            if !provedEmpty {
                persistedCause = .lifecycleDrainUnconfirmed
                runState = .blocked
                sessionState = .blocked
            } else if !artifactsRetired {
                persistedCause = .terminalPersistenceFailed
                runState = .failed
                sessionState = .failed
            } else {
                persistedCause = candidate.state == .terminalBarrier
                    ? candidate.terminalCause ?? .runtimeTerminalUnobserved
                    : .runtimeTerminalUnobserved
                if persistedCause == .terminalPersistenceFailed {
                    runState = .failed
                    sessionState = .failed
                } else {
                    runState = .blocked
                    sessionState = .blocked
                }
            }
            let command = try InvestigationTerminalCommand(
                investigationID: candidate.investigationID,
                runID: candidate.runID,
                runState: runState,
                sessionState: sessionState,
                stage: candidate.stage,
                cause: persistedCause,
                report: nil,
                budgetEvents: [
                    terminalSummaryEvent(
                        runID: candidate.runID,
                        cause: persistedCause,
                        tree: nil
                    ),
                ],
                terminalAt: now
            )
            results.append(
                try await store.settleRecovery(
                    command,
                    expectedRunState: candidate.state,
                    maximumDurationNanoseconds: 90_000_000_000
                )
            )
        }
        return results
    }

    private func requestClosing(
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        requestState: InvestigationRunState,
        cause: InvestigationTerminalCause,
        budgetDimension: InvestigationBudgetDimension? = nil
    ) async throws -> InvestigationClosingResultV1 {
        var run = try requireActiveRun(
            investigationID: investigationID,
            runID: runID
        )
        if let barrier = run.barrier,
           let primaryCause = run.primaryCause
        {
            return InvestigationClosingResultV1(
                investigationID: investigationID,
                runID: runID,
                primaryCause: primaryCause,
                t0Nanoseconds: barrier.t0Nanoseconds
            )
        }
        let transition = try InvestigationRunTransitionCommand(
            investigationID: investigationID,
            runID: runID,
            expectedRunState: .running,
            runState: requestState,
            sessionState: InvestigationSessionState(
                rawValue: requestState.rawValue
            )!,
            stage: run.stage,
            terminalCause: requestState == .terminalBarrier
                ? cause : nil,
            updatedAt: wallNow()
        )
        run.state = requestState
        let t0 = monotonicNow()
        var barrier = InvestigationTerminalBarrier(t0Nanoseconds: t0)
        let interrupts = barrier.interruptsNeeded(
            for: run.normalizer.activeTurnIdentities
        )
        run.barrier = barrier
        run.primaryCause = cause
        run.terminalBudgetDimension = budgetDimension
        activeRun = run
        var interruptError: Error?
        for turn in interrupts {
            do {
                try runtime.interrupt(turn)
            } catch {
                if interruptError == nil {
                    interruptError = error
                }
            }
        }
        do {
            _ = try await store.transition(transition)
        } catch {
            if var current = activeRun,
               current.investigationID == investigationID,
               current.runID == runID
            {
                current.state = .running
                activeRun = current
            }
            throw error
        }
        if let interruptError {
            throw interruptError
        }
        return InvestigationClosingResultV1(
            investigationID: investigationID,
            runID: runID,
            primaryCause: cause,
            t0Nanoseconds: t0
        )
    }

    private func requireScientificAdmission(
        investigationID: InvestigationID,
        runID: InvestigationRunID
    ) async throws -> ActiveRun {
        let run = try requireActiveRun(
            investigationID: investigationID,
            runID: runID
        )
        guard run.state == .running,
              run.barrier == nil,
              run.normalizer.runtimeReadyForScientificWork
        else {
            throw InvestigationCoordinatorError.scientificAdmissionClosed
        }
        let now = monotonicNow()
        guard now >= run.runStartNanoseconds else {
            activeRun = run
            _ = try await requestClosing(
                investigationID: investigationID,
                runID: runID,
                requestState: .terminalBarrier,
                cause: .protocolLost
            )
            throw InvestigationCoordinatorError.invalidMonotonicClock
        }
        let elapsed = now - run.runStartNanoseconds
        guard elapsed < run.plan.budgetLimits.wallClockNanoseconds else {
            activeRun = run
            _ = try await requestClosing(
                investigationID: investigationID,
                runID: runID,
                requestState: .stopRequested,
                cause: .budgetExhausted,
                budgetDimension: .wallClock
            )
            throw InvestigationCoordinatorError.scientificAdmissionClosed
        }
        return run
    }

    private func evaluateStop(
        _ run: ActiveRun
    ) throws -> InvestigationStopEvaluation {
        let targetCount = UInt64(run.plan.targets.count)
        let resolvedCount = UInt64(run.resolvedTargetIDs.count)
        let product = resolvedCount.multipliedReportingOverflow(by: 1_000)
        guard targetCount > 0, !product.overflow else {
            throw InvestigationCoordinatorError.invalidScientificDelta
        }
        let coverage = product.partialValue / targetCount
        let observed = run.normalizer.observedUsage
        let observedExhaustion: InvestigationBudgetExhaustion?
        if observed.directToolCeilingReached {
            observedExhaustion = InvestigationBudgetExhaustion(
                dimension: .observedDirectToolStarts,
                enforcement: .eventTimeObserved
            )
        } else if observed.tokenCeilingReached {
            observedExhaustion = InvestigationBudgetExhaustion(
                dimension: .observedTotalTokens,
                enforcement: .eventTimeObserved
            )
        } else {
            observedExhaustion = nil
        }
        let threshold = run.plan.remainingUnknownByteThreshold
            ?? InvestigationPlan.policyRemainingUnknownByteThreshold
        let remaining: InvestigationRemainingUnknown =
            run.measurableRemainingUnknownBytes.map {
                .measured($0)
            } ?? .unmeasurable
        let facts = try InvestigationStopFacts(
            safetyLoss: nil,
            userCancellationRequested: false,
            userStopRequested: false,
            hardBudgetExhaustion: nil,
            observedBudgetExhaustion: observedExhaustion,
            coveragePermille: coverage,
            requestedCoveragePermille:
                run.plan.requestedCoveragePermille,
            remainingUnknown: remaining,
            remainingUnknownThreshold: threshold,
            consecutiveNoGainSteps:
                run.normalizer.consecutiveNoGainSteps,
            consecutiveNoGainLimit:
                run.plan.budgetLimits.consecutiveNoGainSteps,
            tokenUsageQuality: observed.tokenQuality,
            pauseRequested: false
        )
        return InvestigationStopEvaluator().evaluate(facts)
    }

    private func scientificProgress(
        run: ActiveRun,
        evaluation: InvestigationStopEvaluation
    ) -> InvestigationScientificProgressV1 {
        let resolved = UInt64(run.resolvedTargetIDs.count)
        let total = UInt64(run.plan.targets.count)
        return InvestigationScientificProgressV1(
            stage: run.stage,
            coveragePermille: total == 0
                ? 0 : resolved * 1_000 / total,
            consecutiveNoGainSteps:
                run.normalizer.consecutiveNoGainSteps,
            stopEvaluation: evaluation
        )
    }

    private func nextStage(
        current: InvestigationStage,
        allTargetsResolved: Bool
    ) -> InvestigationStage {
        if allTargetsResolved {
            return .buildPlan
        }
        return switch current {
        case .prioritize:
            .identify
        case .identify:
            .verify
        case .verify, .buildPlan:
            current
        }
    }

    private func stopCause(
        _ reason: InvestigationStopReason
    ) -> (
        cause: InvestigationTerminalCause,
        dimension: InvestigationBudgetDimension?
    ) {
        switch reason {
        case .coverageReached:
            (.coverageReached, nil)
        case .remainingUnknownBelowThreshold:
            (.remainingUnknownBelowThreshold, nil)
        case let .budgetExhausted(exhaustion):
            (.budgetExhausted, exhaustion.dimension)
        case .noEvidenceGain:
            (.noEvidenceGain, .consecutiveNoGainSteps)
        case .userStopped:
            (.userStopped, nil)
        case .userCancelled:
            (.userCancelled, nil)
        }
    }

    private func terminalCause(
        _ reason: InvestigationBlockReason
    ) -> InvestigationTerminalCause {
        switch reason {
        case .containmentLost:
            .containmentLost
        case .lifecycleLost:
            .lifecycleLost
        case .runtimeIdentityLost:
            .runtimeIdentityLost
        case .protocolLost:
            .protocolLost
        case .runtimeTerminalUnobserved:
            .runtimeTerminalUnobserved
        case .lifecycleDrainUnconfirmed:
            .lifecycleDrainUnconfirmed
        }
    }

    private func makeTerminalReport(
        kind: InvestigationReportKind,
        run: ActiveRun,
        tree: InvestigationTreeFinalizationV1?
    ) throws -> InvestigationTerminalReportInput {
        let id = try idProvider.reportID(
            investigationID: run.investigationID,
            runID: run.runID
        )
        if let finalEnvelopeData = run.normalizer.terminalEnvelopeData {
            return try InvestigationReportNormalizer.normalize(
                data: finalEnvelopeData,
                context: run.protocolContext,
                reportID: id,
                kind: kind,
                usage: tree
            )
        }
        let unresolved = try run.plan.targets.map {
            InvestigationEvidenceInput(
                id: InvestigationEvidenceID(
                    rawValue:
                        "investigation-evidence-\($0.id.rawValue.suffix(72))"
                )!,
                targetID: $0.id,
                kind: .unresolved,
                payload: try InvestigationEvidencePayload(
                    summary: "No verified terminal advisory was retained.",
                    sourceLabel: DomainToken(
                        rawValue: "source.runtime-unavailable"
                    )!,
                    confidence: DomainToken(
                        rawValue: "confidence.low"
                    )!,
                    uncertainty:
                        "The target remains unresolved after bounded closure."
                )
            )
        }
        let degradations = tree?.usageQuality == .unavailable
            ? [try InvestigationReportNormalizer.usageUnavailable()]
            : []
        return InvestigationTerminalReportInput(
            id: id,
            kind: kind,
            payload: try InvestigationReportPayload(
                summary: "Bounded investigation closed without a retained advisory."
            ),
            evidence: unresolved,
            degradations: degradations
        )
    }

    private func terminalSummaryEvent(
        runID: InvestigationRunID,
        cause: InvestigationTerminalCause,
        tree: InvestigationTreeFinalizationV1?,
        budgetDimension: InvestigationBudgetDimension? = nil,
        ordinal: UInt64 = 0
    ) -> InvestigationBudgetEventInput {
        InvestigationBudgetEventInput(
            id: InvestigationBudgetEventID(
                rawValue:
                    "investigation-budget-event-\(runID.rawValue.suffix(72))-terminal"
            )!,
            ordinal: ordinal,
            kind: .terminalSummary,
            payload: InvestigationBudgetEventPayload(
                dimension: DomainToken(
                    rawValue: budgetDimension?.rawValue ?? cause.rawValue
                ),
                amount: tree?.totalTokens,
                quality: DomainToken(
                    rawValue: tree?.usageQuality.rawValue
                        ?? InvestigationTokenUsageQuality.unavailable.rawValue
                )
            )
        )
    }

    private func terminalBudgetEvents(
        run: ActiveRun,
        cause: InvestigationTerminalCause,
        tree: InvestigationTreeFinalizationV1?
    ) -> [InvestigationBudgetEventInput] {
        var events: [InvestigationBudgetEventInput] = []
        let runSuffix = String(run.runID.rawValue.suffix(48))

        func append(
            suffix: String,
            kind: InvestigationPersistedBudgetEventKind,
            dimension: InvestigationBudgetDimension,
            amount: UInt64,
            quality: InvestigationBudgetEnforcement
        ) {
            guard amount > 0 else {
                return
            }
            events.append(
                InvestigationBudgetEventInput(
                    id: InvestigationBudgetEventID(
                        rawValue:
                            "investigation-budget-event-\(runSuffix)-\(suffix)"
                    )!,
                    ordinal: UInt64(events.count),
                    kind: kind,
                    payload: InvestigationBudgetEventPayload(
                        dimension: DomainToken(
                            rawValue: dimension.rawValue
                        ),
                        amount: amount,
                        quality: DomainToken(
                            rawValue: quality.rawValue
                        )
                    )
                )
            )
        }

        let hard = run.normalizer.hardUsage
        append(
            suffix: "turns",
            kind: .reservation,
            dimension: .coordinatorTurns,
            amount: hard.coordinatorTurns,
            quality: .hardAdmission
        )
        append(
            suffix: "context",
            kind: .reservation,
            dimension: .cumulativeContextBytes,
            amount: hard.cumulativeContextBytes,
            quality: .hardAdmission
        )
        if let usage = run.latestProbeUsage {
            append(
                suffix: "probe-calls",
                kind: .reservation,
                dimension: .probeCalls,
                amount: UInt64(usage.callCount),
                quality: .hardAdmission
            )
            append(
                suffix: "probe-read",
                kind: .reservation,
                dimension: .probeReadBytes,
                amount: UInt64(usage.readBytes),
                quality: .hardAdmission
            )
            append(
                suffix: "probe-output",
                kind: .commit,
                dimension: .probeOutputBytes,
                amount: UInt64(usage.outputBytes),
                quality: .hardAdmission
            )
        }
        let observed = run.normalizer.observedUsage
        append(
            suffix: "direct-tools",
            kind: .directToolObservation,
            dimension: .observedDirectToolStarts,
            amount: observed.directToolStarts,
            quality: .eventTimeObserved
        )
        if let tokens = tree?.totalTokens {
            append(
                suffix: "tokens",
                kind: .tokenObservation,
                dimension: .observedTotalTokens,
                amount: tokens,
                quality: .eventTimeObserved
            )
        }
        let gainCount = UInt64(
            run.scientificDeltas.values.filter {
                $0.stepResult == .verifiedGain
            }.count
        )
        append(
            suffix: "gain",
            kind: .evidenceGain,
            dimension: .consecutiveNoGainSteps,
            amount: gainCount,
            quality: .hardAdmission
        )
        append(
            suffix: "no-gain",
            kind: .noEvidenceGain,
            dimension: .consecutiveNoGainSteps,
            amount: run.normalizer.consecutiveNoGainSteps,
            quality: .hardAdmission
        )
        events.append(
            terminalSummaryEvent(
                runID: run.runID,
                cause: cause,
                tree: tree,
                budgetDimension: run.terminalBudgetDimension,
                ordinal: UInt64(events.count)
            )
        )
        return events
    }

    private func requireActiveRun(
        investigationID: InvestigationID,
        runID: InvestigationRunID
    ) throws -> ActiveRun {
        guard let activeRun else {
            throw InvestigationCoordinatorError.noActiveRun
        }
        guard activeRun.investigationID == investigationID,
              activeRun.runID == runID
        else {
            throw InvestigationCoordinatorError.runIdentityMismatch
        }
        return activeRun
    }

    private func requireRuntimeEventWindow(
        _ run: ActiveRun
    ) throws {
        guard let barrier = run.barrier else {
            return
        }
        guard barrier.phase(atNanoseconds: monotonicNow())
                == .awaitingTerminalEvents
        else {
            throw InvestigationCoordinatorError.terminalEventWindowClosed
        }
    }

    private func withActiveRun<T>(
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        operation: (inout ActiveRun) throws -> T
    ) throws -> T {
        var run = try requireActiveRun(
            investigationID: investigationID,
            runID: runID
        )
        let result = try operation(&run)
        activeRun = run
        return result
    }

    private func cleanFailedRuntimeStart(
        investigationID: InvestigationID,
        runID: InvestigationRunID
    ) async throws {
        let drain: InvestigationLifecycleDrainResultV1
        do {
            drain = try await lifecycle.drain(
                investigationID: investigationID,
                runID: runID
            )
        } catch {
            throw InvestigationCoordinatorError.runtimeCleanupUnconfirmed
        }
        guard drain.provedEmpty else {
            throw InvestigationCoordinatorError.runtimeCleanupUnconfirmed
        }
        do {
            try runtime.retireArtifacts(
                investigationID: investigationID,
                runID: runID
            )
        } catch {
            throw InvestigationCoordinatorError.runtimeCleanupUnconfirmed
        }
    }
}

private final class InvestigationCompressedContextBox:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var stored: InvestigationCompressedContextV1?

    var value: InvestigationCompressedContextV1? {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

private final class InvestigationRuntimeRootBox:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var stored: InvestigationRuntimeRootV1?

    var value: InvestigationRuntimeRootV1? {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

private final class InvestigationNanosecondsBox:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var stored: UInt64?

    var value: UInt64? {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

private final class InvestigationRuntimeStartAttempt:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var attempted = false

    var wasAttempted: Bool {
        lock.withLock { attempted }
    }

    func markAttempted() {
        lock.withLock {
            attempted = true
        }
    }
}
