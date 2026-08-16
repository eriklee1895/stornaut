import Foundation
import StornautCore
import Testing

@Test
func cleanupExecutionPackageSeamIsUsableOnlyInsideThePackage() async {
    let collector: any CleanupItemPolicyContextCollecting =
        PackageSeamItemCollector()
    let executor: any CleanupActionExecuting = PackageSeamExecutor()
    let sampler: any CleanupVolumeSampling = PackageSeamVolumeSampler()
    let authorization = CleanupAuthorizationController()
    let coordinator = CleanupExecutionCoordinator(
        store: PackageSeamStore(),
        authorizationController: authorization,
        workflowCoordinator: CleanupWorkflowCoordinator(),
        itemCollector: collector,
        executor: executor,
        volumeSampler: sampler
    )

    try? await coordinator.requestStopAfterCurrent()
    _ = await coordinator.recover()
}

@Test
func cleanupExecutionFailureContractPreservesTypedTrashSemantics() {
    let failures: [CleanupActionExecutionFailure] = [
        .permissionDenied,
        .missingItem,
        .identityChanged,
        .postconditionFailed,
        .operationFailed("bounded"),
    ]

    #expect(failures.count == 5)
    #expect(failures[0] == .permissionDenied)
    #expect(failures[4] == .operationFailed("bounded"))
}

@Test
func cleanupExecutionPackageSeamExposesRuntimeCompositionMembers() {
    _ = FoundationCleanupVolumeSampler()
}

private actor PackageSeamStore: CleanupExecutionStore {
    func scanSession(id: ScanSessionID) async throws -> ScanSession? {
        _ = id
        return nil
    }

    func savePolicyDecision(_ decision: PolicyDecision) async throws {
        _ = decision
    }

    func saveCleanupRunJournal(_ journal: CleanupRunJournal) async throws {
        _ = journal
    }

    func cleanupRunJournal(
        id: CleanupRunID
    ) async throws -> CleanupRunJournal? {
        _ = id
        return nil
    }

    func cleanupRunJournals(
        limit: Int,
        offset: Int
    ) async throws -> StorePage<CleanupRunJournal> {
        _ = limit
        _ = offset
        return StorePage(records: [], corruptRecordIDs: [])
    }

    func saveCleanupManifest(_ manifest: CleanupManifest) async throws {
        _ = manifest
    }

    func cleanupManifest(
        id: CleanupManifestID
    ) async throws -> CleanupManifest? {
        _ = id
        return nil
    }

    func cleanupPlan(id: CleanupPlanID) async throws -> CleanupPlan? {
        _ = id
        return nil
    }
}

private struct PackageSeamItemCollector:
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

private struct PackageSeamExecutor: CleanupActionExecuting {
    func preflight(
        _ action: CleanupAction,
        context: ActionPolicyContext
    ) throws -> ActionPreflightToken {
        _ = action
        _ = context
        throw ActionExecutionError.invalidPreflightToken
    }

    func execute(
        _ token: ActionPreflightToken,
        context: ActionPolicyContext
    ) async throws -> ActionExecution {
        _ = token
        _ = context
        throw ActionExecutionError.invalidPreflightToken
    }

    func postflight(
        _ execution: ActionExecution
    ) throws -> ActionResult {
        _ = execution
        throw ActionExecutionError.invalidPreflightToken
    }
}

private struct PackageSeamVolumeSampler: CleanupVolumeSampling {
    func sample(
        rootURL: URL,
        sampledAt: Date
    ) throws -> CleanupVolumeSample {
        _ = rootURL
        return try CleanupVolumeSample(
            device: 1,
            freeBytes: ByteCount(0)!,
            source: DomainToken(rawValue: "test.package-seam")!,
            sampledAt: sampledAt
        )
    }
}

private func issuePackageSeamAuthorization(
    controller: CleanupAuthorizationController,
    evaluation: CleanupPolicyEvaluation,
    confirmation: CleanupConfirmation,
    collectedContext: CleanupPolicyCollectedContext
) async throws -> ExecutionAuthorization {
    try await controller.issue(
        evaluation: evaluation,
        confirmation: confirmation,
        collectedContext: collectedContext
    )
}

private func makePackageSeamRequest(
    plan: CleanupPlan,
    selection: ReviewSelection,
    evaluation: CleanupPolicyEvaluation,
    confirmation: CleanupConfirmation,
    collectedContext: CleanupPolicyCollectedContext,
    authorization: ExecutionAuthorization
) -> CleanupExecutionRequest {
    CleanupExecutionRequest(
        plan: plan,
        selection: selection,
        evaluation: evaluation,
        confirmation: confirmation,
        collectedContext: collectedContext,
        authorization: authorization
    )
}
