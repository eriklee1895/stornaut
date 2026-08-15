import Foundation

public enum CleanupExecutionRuntimeError:
    Error,
    Sendable,
    Equatable
{
    case policyContextUnavailable(CleanupPolicyCollectionError)
}

public actor CleanupExecutionRuntime {
    typealias Clock = @Sendable () -> Date
    typealias Collect = @Sendable (
        CleanupPlan,
        ReviewSelection
    ) async -> CleanupPolicyCollectionOutcome

    private struct PendingPreflight: Sendable {
        let plan: CleanupPlan
        let selection: ReviewSelection
        let evaluation: CleanupPolicyEvaluation
        let collectedContext: CleanupPolicyCollectedContext
    }

    private let collect: Collect
    private let policyGate: CleanupPolicyGate
    private let authorizationController: CleanupAuthorizationController
    private let coordinator: CleanupExecutionCoordinator
    private let now: Clock
    private var pending: PendingPreflight?
    private var preflightGeneration: UInt64 = 0

    init(
        store: EvidenceStore,
        rootObserver: any CleanupPolicyRootObserving,
        workflowCoordinator: CleanupWorkflowCoordinator
    ) throws {
        let collector = try CleanupPolicyContextCollector(
            store: store,
            rootObserver: rootObserver,
            workflowObserver: workflowCoordinator
        )
        let authorizationController = CleanupAuthorizationController()
        let executor = ActionExecutor(
            policyGate: ActionPolicyGate(
                registry: ActionRegistry(definitions: [])
            ),
            trashMoving: TrashMoving(
                adapter: FileManagerTrashAdapter()
            ),
            registeredActionRunner: DenyRegisteredActionRunner()
        )
        self.collect = { plan, selection in
            await collector.collect(
                plan: plan,
                selection: selection
            )
        }
        policyGate = CleanupPolicyGate()
        self.authorizationController = authorizationController
        coordinator = CleanupExecutionCoordinator(
            store: store,
            authorizationController: authorizationController,
            workflowCoordinator: workflowCoordinator,
            itemCollector: collector,
            executor: executor,
            volumeSampler: FoundationCleanupVolumeSampler()
        )
        now = Date.init
    }

#if DEBUG
    public static func diagnostic(
        store: EvidenceStore,
        rootObserver: any CleanupPolicyRootObserving,
        workflowCoordinator: CleanupWorkflowCoordinator,
        resolver: ExecutableEvidenceResolver,
        observation: CleanupTrashDiagnosticObservation
    ) throws -> CleanupExecutionRuntime {
        let collector = try CleanupPolicyContextCollector
            .phaseCTrashDiagnostic(
            store: store,
            resolver: resolver,
            rootObserver: rootObserver,
            workflowObserver: workflowCoordinator
        )
        let authorizationController = CleanupAuthorizationController()
        let executor = ActionExecutor(
            policyGate: ActionPolicyGate(
                registry: ActionRegistry(definitions: [])
            ),
            trashMoving: TrashMoving(
                adapter: RecordingFileManagerTrashAdapter(
                    observation: observation
                )
            ),
            registeredActionRunner: DenyRegisteredActionRunner()
        )
        return CleanupExecutionRuntime(
            collect: { plan, selection in
                await collector.collect(
                    plan: plan,
                    selection: selection
                )
            },
            authorizationController: authorizationController,
            coordinator: CleanupExecutionCoordinator(
                store: store,
                authorizationController: authorizationController,
                workflowCoordinator: workflowCoordinator,
                itemCollector: collector,
                executor: executor,
                volumeSampler: FoundationCleanupVolumeSampler()
            )
        )
    }

    public static func diagnosticRecovery(
        store: EvidenceStore,
        workflowCoordinator: CleanupWorkflowCoordinator,
        observation: CleanupRecoveryDiagnosticObservation
    ) -> CleanupExecutionRuntime {
        let authorizationController = CleanupAuthorizationController()
        return CleanupExecutionRuntime(
            collect: { _, selection in
                .blocked(
                    error: .invalidSelection,
                    affectedItemIDs: Set(
                        selection.items.map(\.itemID)
                    )
                )
            },
            authorizationController: authorizationController,
            coordinator: CleanupExecutionCoordinator(
                store: store,
                authorizationController: authorizationController,
                workflowCoordinator: workflowCoordinator,
                itemCollector: DenyRecoveryItemCollector(),
                executor: DenyRecoveryExecutor(
                    observation: observation
                )
            )
        )
    }
#endif

    init(
        collect: @escaping Collect,
        policyGate: CleanupPolicyGate = CleanupPolicyGate(),
        authorizationController: CleanupAuthorizationController,
        coordinator: CleanupExecutionCoordinator,
        now: @escaping Clock = Date.init
    ) {
        self.collect = collect
        self.policyGate = policyGate
        self.authorizationController = authorizationController
        self.coordinator = coordinator
        self.now = now
    }

    public func preflight(
        plan: CleanupPlan,
        selection: ReviewSelection
    ) async throws -> CleanupPolicyEvaluation {
        preflightGeneration &+= 1
        let generation = preflightGeneration
        pending = nil
        let collection = await collect(plan, selection)
        guard case let .collected(collectedContext) = collection else {
            guard case let .blocked(error, _) = collection else {
                preconditionFailure("unknown policy collection outcome")
            }
            throw CleanupExecutionRuntimeError
                .policyContextUnavailable(error)
        }
        let evaluation = try policyGate.evaluate(
            plan: plan,
            selection: selection,
            context: collectedContext.policyContext,
            evaluatedAt: now()
        )
        guard evaluation.allowed != nil else {
            return evaluation
        }
        guard preflightGeneration == generation else {
            return evaluation
        }
        pending = PendingPreflight(
            plan: plan,
            selection: selection,
            evaluation: evaluation,
            collectedContext: collectedContext
        )
        return evaluation
    }

    public func execute(
        plan: CleanupPlan,
        selection: ReviewSelection,
        confirmation: CleanupConfirmation
    ) async -> CleanupExecutionState {
        guard let pending else {
            return .rejected(.authorization)
        }
        self.pending = nil
        guard pending.plan == plan,
              pending.selection == selection,
              pending.evaluation.allowed?.confirmation == confirmation,
              pending.collectedContext.policyContext.contextFingerprint
                == confirmation.contextFingerprint
        else {
            return .rejected(.planMismatch)
        }
        do {
            let authorization = try await authorizationController.issue(
                evaluation: pending.evaluation,
                confirmation: confirmation,
                collectedContext: pending.collectedContext
            )
            return await coordinator.run(
                CleanupExecutionRequest(
                    plan: plan,
                    selection: selection,
                    evaluation: pending.evaluation,
                    confirmation: confirmation,
                    collectedContext: pending.collectedContext,
                    authorization: authorization
                )
            )
        } catch {
            return .rejected(.authorization)
        }
    }

    public func requestStopAfterCurrent() async {
        try? await coordinator.requestStopAfterCurrent()
    }

    public func retrySavingAudit(
        _ result: CleanupExecutionResult
    ) async -> CleanupExecutionState {
        await coordinator.retrySavingAudit(result)
    }

    public func recover() async -> [CleanupExecutionState] {
        await coordinator.recover()
    }
}

private struct DenyRegisteredActionRunner: RegisteredActionRunning {
    func run(
        _ invocation: RegisteredActionInvocation
    ) async throws -> RegisteredActionProcessOutput {
        _ = invocation
        throw RegisteredActionRunnerError.launchFailed(
            "registered actions are unavailable"
        )
    }
}

#if DEBUG
public final class CleanupRecoveryDiagnosticObservation:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var calls = 0

    public init() {}

    fileprivate func recordInvocation() {
        lock.withLock {
            calls += 1
        }
    }

    public func invocationCount() -> Int {
        lock.withLock { calls }
    }
}

private struct DenyRecoveryItemCollector:
    CleanupItemPolicyContextCollecting
{
    func collectItem(
        plan: CleanupPlan,
        selection: ReviewSelection,
        itemID: CleanupPlanItemID,
        workflow: CleanupWorkflowAvailabilitySnapshot
    ) async -> CleanupPolicyCollectionOutcome {
        _ = plan
        _ = selection
        _ = workflow
        return .blocked(
            error: .itemTruthUnavailable,
            affectedItemIDs: [itemID]
        )
    }
}

private struct DenyRecoveryExecutor: CleanupActionExecuting {
    let observation: CleanupRecoveryDiagnosticObservation

    func preflight(
        _ action: CleanupAction,
        context: ActionPolicyContext
    ) throws -> ActionPreflightToken {
        _ = action
        _ = context
        observation.recordInvocation()
        throw ActionExecutionError.invalidPreflightToken
    }

    func execute(
        _ token: ActionPreflightToken,
        context: ActionPolicyContext
    ) async throws -> ActionExecution {
        _ = token
        _ = context
        observation.recordInvocation()
        throw ActionExecutionError.invalidPreflightToken
    }

    func postflight(
        _ execution: ActionExecution
    ) throws -> ActionResult {
        _ = execution
        observation.recordInvocation()
        throw ActionExecutionError.invalidPreflightToken
    }
}

public final class CleanupTrashDiagnosticObservation:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var trashAttemptCount = 0
    private var returnedTrashURL: URL?

    public init() {}

    fileprivate func recordAttempt() {
        lock.withLock {
            trashAttemptCount += 1
        }
    }

    fileprivate func record(returnedTrashURL: URL?) {
        lock.withLock {
            self.returnedTrashURL = returnedTrashURL
        }
    }

    public func attemptCount() -> Int {
        lock.withLock { trashAttemptCount }
    }

    public func trashURL() -> URL? {
        lock.withLock { returnedTrashURL }
    }
}

private struct RecordingFileManagerTrashAdapter: TrashAdapting {
    let observation: CleanupTrashDiagnosticObservation

    func trashItem(at url: URL) throws -> URL? {
        observation.recordAttempt()
        let result = try FileManagerTrashAdapter().trashItem(at: url)
        observation.record(returnedTrashURL: result)
        return result
    }
}
#endif
