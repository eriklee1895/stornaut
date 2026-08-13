import Foundation
import Testing
@testable import StornautCore

@Test
func cleanupWorkflowCoordinatorExcludesMutationsDuringExecution() async throws {
    let coordinator = CleanupWorkflowCoordinator()
    let cleanupLease = try await coordinator.acquire(.cleanupExecution)

    #expect(
        await coordinator.snapshot()
            == CleanupWorkflowAvailabilitySnapshot(
                rootLeaseAvailable: true,
                activeConflicts: [.cleanupExecution]
            )
    )
    await #expect(throws: CleanupWorkflowCoordinatorError.conflict) {
        _ = try await coordinator.acquire(.quickScan)
    }
    await #expect(throws: CleanupWorkflowCoordinatorError.conflict) {
        _ = try await coordinator.acquire(.settingsMutation)
    }
    await #expect(throws: CleanupWorkflowCoordinatorError.conflict) {
        _ = try await coordinator.acquire(.historyMutation)
    }
    await #expect(throws: CleanupWorkflowCoordinatorError.conflict) {
        _ = try await coordinator.acquire(.cleanupExecution)
    }

    await coordinator.release(cleanupLease)
    #expect(await coordinator.snapshot() == .available)
}

@Test
func cleanupExecutionStateExposesOnlyAuditRetryForAuditPending() throws {
    let manifest = try CleanupPersistenceTestSupport.manifest()
    let journal = try executionStateJournal(
        manifest: manifest,
        stage: .auditPending
    )

    let state = CleanupExecutionState.auditPending(
        try CleanupExecutionResult(
            journal: journal,
            manifest: manifest
        )
    )

    #expect(state.availableActions == [.retrySavingAudit])
    #expect(!state.isCompleted)
}

@Test
func cleanupExecutionStaleExposesOnlyRefreshAndCancel() throws {
    let plan = try CleanupPersistenceTestSupport.plan()
    let stale = CleanupStaleResult(
        affectedItemIDs: [plan.items[0].id],
        reasonGroups: [.identity]
    )
    let manifest = try CleanupPersistenceTestSupport.manifest(plan: plan)
    let journal = try executionStateJournal(
        manifest: manifest,
        stage: .finalized
    )

    let state = CleanupExecutionState.stale(
        stale,
        try CleanupExecutionResult(
            journal: journal,
            manifest: manifest
        )
    )

    #expect(state.availableActions == [.refreshAffectedItems, .cancel])
}

@Test
func cleanupExecutionResultRejectsMismatchedJournalAndManifest() throws {
    let manifest = try CleanupPersistenceTestSupport.manifest()
    let journal = try executionStateJournal(
        manifest: manifest,
        stage: .finalized
    )
    let different = try CleanupManifest(
        id: CleanupManifestID(rawValue: "manifest-different")!,
        planID: manifest.planID,
        createdAt: manifest.createdAt,
        expiresAt: manifest.expiresAt,
        records: manifest.records,
        summary: manifest.summary,
        systemObservation: manifest.systemObservation
    )

    #expect(throws: DomainContractError.invalidMeasurement) {
        _ = try CleanupExecutionResult(
            journal: journal,
            manifest: different
        )
    }
}

private func executionStateJournal(
    manifest: CleanupManifest,
    stage: CleanupRunJournalStage
) throws -> CleanupRunJournal {
    let plan = try CleanupPersistenceTestSupport.plan()
    let entries = try manifest.records.map { record in
        let item = try #require(
            plan.items.first { $0.id == record.planItemID }
        )
        return try CleanupRunJournalEntry(
            actionID: record.actionID,
            planItemID: record.planItemID,
            policyDecisionID: try #require(record.policyDecisionID),
            policyDisposition: record.policyDisposition,
            policyReasonKeys: record.policyReasonKeys,
            action: record.action,
            expectedIdentity: item.expectedIdentity!,
            actionFingerprint: DomainToken(
                rawValue: "action.\(item.id.rawValue).fingerprint"
            )!,
            state: .outcomeRecorded,
            startedAt: record.startedAt,
            outcome: CleanupJournalOutcome(
                result: record.result,
                recovery: record.recovery,
                measures: record.measures,
                destinationIdentity: item.expectedIdentity,
                error: record.error,
                finishedAt: try #require(record.finishedAt)
            )
        )
    }
    return try CleanupRunJournal(
        id: CleanupRunID(rawValue: "run-execution-state")!,
        planID: manifest.planID,
        manifestID: manifest.id,
        selectionGeneration: 3,
        selectionFingerprint: DomainToken(
            rawValue: "selection.execution-state.fingerprint"
        )!,
        stage: stage,
        retentionClass: .audit,
        stopAfterCurrentRequested: false,
        entries: entries,
        createdAt: CleanupPersistenceTestSupport.updatedAt,
        updatedAt: manifest.createdAt,
        expiresAt: manifest.expiresAt,
        manifestCreatedAt: manifest.createdAt,
        systemObservation: manifest.systemObservation
    )
}
