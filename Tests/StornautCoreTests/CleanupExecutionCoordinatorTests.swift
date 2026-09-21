import Foundation
import Testing
@testable import StornautCore

@Test
func cleanupExecutionCoordinatorHasNoDefaultFoundationTrashSurface() throws {
    let root = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let sourceURL = root.appending(
        path:
            "Sources/StornautCore/Actions/CleanupExecutionCoordinator.swift"
    )
    let source = try String(contentsOf: sourceURL, encoding: .utf8)

    #expect(!source.contains("FileManagerTrashAdapter"))
    #expect(!source.contains("TrashMoving()"))
    #expect(!source.contains("ActionExecutor("))
    #expect(!source.contains("runRegisteredAction"))
}

@Test
func cleanupExecutionAuthorityLivesOutsideCore()
    throws
{
    let root = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let runtimeURL = root.appending(
        path:
            "Sources/StornautCore/Actions/CleanupExecutionRuntime.swift"
    )
    let authorityURL = root.appending(
        path:
            "Sources/StornautExecution/Actions/CleanupExecutionAuthority.swift"
    )
    let runtime = try String(contentsOf: runtimeURL, encoding: .utf8)
    let authority = try String(contentsOf: authorityURL, encoding: .utf8)

    #expect(!runtime.contains("FileManagerTrashAdapter"))
    #expect(!runtime.contains("ActionExecutor"))
    #expect(!runtime.contains("TrashMoving"))
    #expect(authority.contains("FileManagerTrashAdapter()"))
    #expect(authority.contains("ActionRegistry(definitions: [])"))
    #expect(authority.contains("DenyRegisteredActionRunner()"))
    #expect(!authority.contains("FoundationRegisteredActionRunner()"))
    #expect(!runtime.contains("public let authorization"))
    #expect(!runtime.contains("public let coordinator"))
    #expect(
        !runtime.contains(
            """
                public init(
                    store: EvidenceStore,
            """
        )
    )
}

@Test
func cleanupExecutionRuntimeConsumesOneExactPendingPreflight()
    async throws
{
    let harness = try await CleanupExecutionHarness()
    let runtime = CleanupExecutionRuntime(
        collect: { plan, selection in
            guard plan == harness.plan,
                  selection == harness.selection
            else {
                return .blocked(
                    error: .invalidSelection,
                    affectedItemIDs: Set(
                        selection.items.map(\.itemID)
                    )
                )
            }
            return .collected(harness.collected)
        },
        authorizationController: harness.authorizationController,
        coordinator: harness.coordinator,
        now: ExecutionHarnessClock(harness.now).now
    )

    let evaluation = try await runtime.preflight(
        plan: harness.plan,
        selection: harness.selection
    )
    let confirmation = try #require(
        evaluation.allowed?.confirmation
    )
    let first = await runtime.execute(
        plan: harness.plan,
        selection: harness.selection,
        confirmation: confirmation
    )
    let second = await runtime.execute(
        plan: harness.plan,
        selection: harness.selection,
        confirmation: confirmation
    )

    #expect(first.isCompleted)
    #expect(second == .rejected(.authorization))
    #expect(await harness.executor.callCount == 2)
}

@Test
func cleanupExecutionCoordinatorContinuesFromCanonicalStoreJournal()
    async throws
{
    let now = CleanupPersistenceTestSupport.createdAt
        .addingTimeInterval(10.000_123)
    let harness = try await CleanupExecutionHarness(
        now: now,
        canonicalizeJournals: true,
        canonicalizeManifests: true
    )
    let request = try await harness.request()

    let state = await harness.coordinator.run(request)

    #expect(state.isCompleted)
    #expect(await harness.executor.callCount == 2)
    #expect(
        await harness.store.currentJournal?.stage == .finalized
    )
}

@Test
func cleanupExecutionManifestTimelineIncludesFinalVolumeSample()
    async throws
{
    let finalSampleAt = try backwardDriftingDomainDate(
        after: CleanupPersistenceTestSupport.createdAt
            .addingTimeInterval(40)
    )
    let now = finalSampleAt.addingTimeInterval(-30)
    let sampler = try SequencedCleanupVolumeSampler(
        samples: [
            CleanupVolumeSample(
                device: 101,
                freeBytes: ByteCount(1_000_000)!,
                source: DomainToken(
                    rawValue: "test.volume-sampler"
                )!,
                sampledAt: now
            ),
            CleanupVolumeSample(
                device: 101,
                freeBytes: ByteCount(1_000_128)!,
                source: DomainToken(
                    rawValue: "test.volume-sampler"
                )!,
                sampledAt: finalSampleAt
            ),
        ]
    )
    let harness = try await CleanupExecutionHarness(
        now: now,
        volumeSampler: sampler
    )
    let request = try await harness.request()

    let state = await harness.coordinator.run(request)
    let result = try #require(state.result)

    #expect(state.isCompleted)
    #expect(
        abs(
            (
                result.manifest.systemObservation?.sampledAfterAt
                    .timeIntervalSince(finalSampleAt)
            ) ?? .infinity
        ) < 0.001
    )
    let persistedSampleAt = try #require(
        result.manifest.systemObservation?.sampledAfterAt
    )
    #expect(result.manifest.createdAt >= persistedSampleAt)
}

@Test
func cleanupExecutionRuntimeBlockedCollectionLeavesNoAuthority()
    async throws
{
    let harness = try await CleanupExecutionHarness()
    let runtime = CleanupExecutionRuntime(
        collect: { _, selection in
            .blocked(
                error: .storeTruthUnavailable,
                affectedItemIDs: Set(
                    selection.items.map(\.itemID)
                )
            )
        },
        authorizationController: harness.authorizationController,
        coordinator: harness.coordinator,
        now: ExecutionHarnessClock(harness.now).now
    )

    await #expect(
        throws: CleanupExecutionRuntimeError.policyContextUnavailable(
            .storeTruthUnavailable
        )
    ) {
        _ = try await runtime.preflight(
            plan: harness.plan,
            selection: harness.selection
        )
    }
    let state = await runtime.execute(
        plan: harness.plan,
        selection: harness.selection,
        confirmation: harness.confirmation
    )

    #expect(state == .rejected(.authorization))
    #expect(await harness.executor.callCount == 0)
}

@Test
func cleanupExecutionRuntimeOlderPreflightCannotReplaceNewerAuthority()
    async throws
{
    let harness = try await CleanupExecutionHarness()
    let olderSelection = try ReviewSelection(
        plan: harness.plan,
        generation: harness.selection.generation + 1,
        items: harness.selection.items,
        dispositions: Dictionary(
            uniqueKeysWithValues: harness.plan.items.map {
                ($0.id, ReclaimDisposition.readyToReclaim)
            }
        )
    )
    let olderCollected = try cleanupExecutionCollectedContext(
        harness: harness,
        selection: olderSelection
    )
    let collector = OrderedRuntimePreflightCollector(
        delayedSelection: olderSelection,
        delayedOutcome: .collected(olderCollected),
        currentOutcome: .collected(harness.collected)
    )
    let runtime = CleanupExecutionRuntime(
        collect: { _, selection in
            await collector.collect(selection: selection)
        },
        authorizationController: harness.authorizationController,
        coordinator: harness.coordinator,
        now: ExecutionHarnessClock(harness.now).now
    )

    let olderTask = Task {
        try await runtime.preflight(
            plan: harness.plan,
            selection: olderSelection
        )
    }
    await collector.waitUntilDelayedCollectionStarts()
    let currentEvaluation = try await runtime.preflight(
        plan: harness.plan,
        selection: harness.selection
    )
    let currentConfirmation = try #require(
        currentEvaluation.allowed?.confirmation
    )
    await collector.releaseDelayedCollection()
    _ = try await olderTask.value

    let state = await runtime.execute(
        plan: harness.plan,
        selection: harness.selection,
        confirmation: currentConfirmation
    )

    #expect(state.isCompleted)
    #expect(await harness.executor.callCount == 2)
}

@Test
func cleanupExecutionPreparedJournalPreservesAdmittedOrderAndAuthority()
    throws
{
    let plan = try CleanupPersistenceTestSupport.plan()
    let selection = try ReviewSelection(
        plan: plan,
        generation: 3,
        items: plan.items.map {
            ReviewSelectionItem(
                itemID: $0.id,
                origin: .explicitUser
            )
        },
        dispositions: Dictionary(
            uniqueKeysWithValues: plan.items.map {
                ($0.id, ReclaimDisposition.readyToReclaim)
            }
        )
    )
    let decisions = try plan.items.map {
        try CleanupPersistenceTestSupport.decision(
            plan: plan,
            item: $0,
            selectionOrigin: .explicitUser
        )
    }

    let journal = try CleanupExecutionJournalBuilder().preparedJournal(
        plan: plan,
        selection: selection,
        decisions: decisions,
        runID: CleanupRunID(rawValue: "run-execution")!,
        manifestID: CleanupManifestID(rawValue: "manifest-execution")!,
        createdAt: CleanupPersistenceTestSupport.createdAt
    )

    #expect(journal.stage == .prepared)
    #expect(journal.entries.map(\.planItemID) == selection.items.map(\.itemID))
    #expect(journal.selectionGeneration == selection.generation)
    #expect(journal.selectionFingerprint == selection.fingerprint)
    #expect(journal.entries.allSatisfy { $0.action == .moveToTrash })
}

@Test
func cleanupExecutionCoordinatorRunsSeriallyAndFinalizesManifest()
    async throws
{
    let harness = try await CleanupExecutionHarness()
    let request = try await harness.request()

    let state = await harness.coordinator.run(request)
    let result = try #require(state.result)

    #expect(state.isCompleted)
    #expect(await harness.executor.callCount == 2)
    #expect(await harness.executor.maximumConcurrentCalls == 1)
    #expect(
        await harness.executor.targetPaths
            == harness.selection.items.compactMap { selected in
                harness.plan.items.first {
                    $0.id == selected.itemID
                }?.expectedRelativePath?.rawValue
            }
    )
    #expect(result.journal.stage == .finalized)
    #expect(result.manifest.records.map(\.result) == [
        .succeeded,
        .succeeded,
    ])
    #expect(result.manifest.summary.succeededCount == 2)
    #expect(
        result.manifest.summary.permanentlyReleasedLogicalBytes
            == ByteCount(0)
    )
    #expect(
        await harness.store.savedJournalStages == [
            .prepared,
            .actionStarted,
            .actionOutcomeRecorded,
            .actionStarted,
            .actionOutcomeRecorded,
            .manifestPending,
            .finalized,
        ]
    )
}

@Test
func cleanupExecutionCoordinatorPerformsZeroWritesWhenPreparedSaveFails()
    async throws
{
    let harness = try await CleanupExecutionHarness(
        storeFailure: .journalSave(call: 1)
    )
    let request = try await harness.request()

    let state = await harness.coordinator.run(request)

    #expect(state == .rejected(.persistence))
    #expect(await harness.executor.callCount == 0)
    #expect(await harness.store.savedJournalStages.isEmpty)
}

@Test
func cleanupExecutionCoordinatorPerformsZeroWritesWhenStartedSaveFails()
    async throws
{
    let harness = try await CleanupExecutionHarness(
        storeFailure: .journalSave(call: 2)
    )
    let request = try await harness.request()

    let state = await harness.coordinator.run(request)

    #expect(state == .rejected(.persistence))
    #expect(await harness.executor.callCount == 0)
    #expect(await harness.store.savedJournalStages == [.prepared])
}

@Test
func cleanupExecutionCoordinatorCancellationBeforeFirstActionHasZeroWrites()
    async throws
{
    let harness = try await CleanupExecutionHarness()
    let request = try await harness.request()
    let task = Task {
        await harness.coordinator.run(request)
    }
    task.cancel()

    let state = await task.value
    let result = try #require(state.result)

    #expect(await harness.executor.callCount == 0)
    #expect(result.manifest.summary.cancelledCount == 2)
    #expect(result.manifest.records.allSatisfy {
        $0.result == .cancelled
    })
}

@Test
func cleanupExecutionCoordinatorRejectsSelectionMutationAfterAuthorization()
    async throws
{
    let harness = try await CleanupExecutionHarness()
    let request = try await harness.request()
    let selectedItem = harness.plan.items[1]
    let changedSelection = try ReviewSelection(
        plan: harness.plan,
        generation: harness.selection.generation + 1,
        items: [
            ReviewSelectionItem(
                itemID: selectedItem.id,
                origin: .explicitUser
            ),
        ],
        dispositions: [selectedItem.id: .readyToReclaim]
    )
    let changed = CleanupExecutionRequest(
        plan: request.plan,
        selection: changedSelection,
        evaluation: request.evaluation,
        confirmation: request.confirmation,
        collectedContext: request.collectedContext,
        authorization: request.authorization
    )

    let state = await harness.coordinator.run(changed)

    #expect(state == .rejected(.planMismatch))
    #expect(await harness.executor.callCount == 0)
}

@Test
func cleanupExecutionCoordinatorFinalRevalidationFailureHasZeroMutationCalls()
    async throws
{
    let executor = FinalRevalidationFailureExecutor()
    let harness = try await CleanupExecutionHarness(executor: executor)
    let request = try await harness.request()

    let state = await harness.coordinator.run(request)
    let result = try #require(state.result)

    #expect(await executor.callCount == 0)
    #expect(result.manifest.records.map(\.result) == [
        .failed,
        .cancelled,
    ])
    #expect(result.manifest.records[0].recovery == .notStarted)
}

@Test
func cleanupExecutionCoordinatorStopsOnFreshPolicyDenyWithoutAdapterCall()
    async throws
{
    let harness = try await CleanupExecutionHarness(
        deniedItemID: try CleanupPersistenceTestSupport.plan().items[0].id
    )
    let request = try await harness.request()

    let state = await harness.coordinator.run(request)
    let result = try #require(state.result)

    #expect(await harness.executor.callCount == 0)
    #expect(result.manifest.records.map(\.result) == [
        .failed,
        .cancelled,
    ])
    #expect(result.manifest.records[0].recovery == .notStarted)
}

@Test
func cleanupExecutionCoordinatorStopsAfterCurrentWithoutStartingNext()
    async throws
{
    let executor = BlockingCleanupExecutor()
    let harness = try await CleanupExecutionHarness(executor: executor)
    let request = try await harness.request()
    let task = Task {
        await harness.coordinator.run(request)
    }
    await executor.waitUntilBlocked()

    let stopStarted = ContinuousClock.now
    try await harness.coordinator.requestStopAfterCurrent()
    let stopElapsed = stopStarted.duration(to: .now)
    #expect(
        await harness.store.currentJournal?
            .stopAfterCurrentRequested == true
    )
    #expect(stopElapsed < .milliseconds(100))
    await executor.release()
    let state = await task.value
    let result = try #require(state.result)

    #expect(await executor.callCount == 1)
    #expect(result.manifest.records.map(\.result) == [
        .succeeded,
        .cancelled,
    ])
    #expect(result.journal.stopAfterCurrentRequested)
    #expect(state.availableActions.isEmpty)
}

@Test
func cleanupExecutionCoordinatorContinuesAfterKnownUnchangedTrashFailure()
    async throws
{
    let executor = FailingThenSuccessCleanupExecutor()
    let harness = try await CleanupExecutionHarness(executor: executor)
    let request = try await harness.request()

    let state = await harness.coordinator.run(request)
    let result = try #require(state.result)

    #expect(await executor.callCount == 2)
    #expect(result.manifest.records.map(\.result) == [
        .failed,
        .succeeded,
    ])
    #expect(result.manifest.records[0].recovery == .originalConfirmed)
    #expect(result.manifest.summary.failedCount == 1)
    #expect(result.manifest.summary.succeededCount == 1)
}

@Test
func cleanupExecutionCoordinatorStopsWhenTrashFailureIdentityIsUncertain()
    async throws
{
    let executor = FailingThenSuccessCleanupExecutor()
    let harness = try await CleanupExecutionHarness(
        executor: executor,
        originalIdentityAvailable: false
    )
    let request = try await harness.request()

    let state = await harness.coordinator.run(request)
    let result = try #require(state.result)

    #expect(await executor.callCount == 1)
    #expect(result.manifest.records.map(\.result) == [
        .outcomeUnknown,
        .cancelled,
    ])
    #expect(result.manifest.summary.unknownCount == 1)
    #expect(state.availableActions == [.inspectRecovery, .scanAgain])
}

@Test
func cleanupExecutionCoordinatorTreatsPostStartCancellationAsUnknown()
    async throws
{
    let executor = CancellationCleanupExecutor()
    let harness = try await CleanupExecutionHarness(executor: executor)
    let request = try await harness.request()

    let state = await harness.coordinator.run(request)
    let result = try #require(state.result)

    #expect(await executor.callCount == 1)
    #expect(result.manifest.records.map(\.result) == [
        .outcomeUnknown,
        .cancelled,
    ])
    #expect(result.manifest.summary.unknownCount == 1)
    #expect(state.availableActions == [.inspectRecovery, .scanAgain])
}

@Test
func cleanupExecutionFailureRemainsPartialWhenLaterItemsAreCancelled()
    async throws
{
    let executor = FailingThenBlockingCleanupExecutor()
    let harness = try await CleanupExecutionHarness(executor: executor)
    let request = try await harness.request()
    let task = Task {
        await harness.coordinator.run(request)
    }
    await executor.waitUntilSecondBlocked()
    try await harness.coordinator.requestStopAfterCurrent()
    await executor.release()

    let state = await task.value
    let result = try #require(state.result)

    #expect(result.manifest.summary.failedCount == 1)
    #expect(result.manifest.summary.succeededCount == 1)
    #expect(state.availableActions.isEmpty)
    guard case .partiallyFailed = state else {
        Issue.record("failure must dominate stopped presentation")
        return
    }
}

@Test
func cleanupExecutionWorkflowConflictConsumesAuthorizationWithoutWrites()
    async throws
{
    let harness = try await CleanupExecutionHarness()
    let request = try await harness.request()
    let conflictingLease = try await harness.workflow.acquire(.quickScan)

    let first = await harness.coordinator.run(request)
    await harness.workflow.release(conflictingLease)
    let second = await harness.coordinator.run(request)

    #expect(first == .rejected(.workflowConflict))
    #expect(second == .rejected(.authorization))
    #expect(await harness.executor.callCount == 0)
}

@Test
func cleanupExecutionCoordinatorRetriesAuditWithoutReplayingActions()
    async throws
{
    let harness = try await CleanupExecutionHarness(
        storeFailure: .manifestSave
    )
    let request = try await harness.request()

    let first = await harness.coordinator.run(request)
    let pending = try #require(first.result)
    #expect(first.availableActions == [.retrySavingAudit])
    #expect(await harness.executor.callCount == 2)

    await harness.store.clearFailure()
    let retried = await harness.coordinator.retrySavingAudit(pending)

    #expect(retried.isCompleted)
    #expect(await harness.executor.callCount == 2)
    #expect(retried.result?.manifest == pending.manifest)
}

@Test
func cleanupExecutionCoordinatorRejectsTamperedAuditRetryWithoutReplay()
    async throws
{
    let harness = try await CleanupExecutionHarness(
        storeFailure: .manifestSave
    )
    let request = try await harness.request()
    let first = await harness.coordinator.run(request)
    let pending = try #require(first.result)
    let tampered = try CleanupManifest(
        id: pending.manifest.id,
        planID: pending.manifest.planID,
        createdAt: pending.manifest.createdAt,
        expiresAt: pending.manifest.expiresAt.addingTimeInterval(-1),
        records: pending.manifest.records,
        summary: pending.manifest.summary,
        systemObservation: pending.manifest.systemObservation
    )

    let state = await harness.coordinator.retrySavingAudit(
        try CleanupExecutionResult(
            journal: pending.journal,
            manifest: tampered
        )
    )

    #expect(state == .rejected(.programmingError))
    #expect(await harness.executor.callCount == 2)
}

@Test
func cleanupExecutionOutcomePersistenceFailureRecoversWithoutReplay()
    async throws
{
    let harness = try await CleanupExecutionHarness(
        storeFailure: .journalSave(call: 3)
    )
    let request = try await harness.request()

    let blocked = await harness.coordinator.run(request)
    guard case .recoveryBlocked = blocked else {
        Issue.record("started action without durable outcome must block")
        return
    }
    #expect(await harness.executor.callCount == 1)

    await harness.store.clearFailure()
    let recovered = await harness.coordinator.recover()
    let result = try #require(recovered.first?.result)

    #expect(await harness.executor.callCount == 1)
    #expect(result.manifest.records.map(\.result) == [
        .outcomeUnknown,
        .cancelled,
    ])
}

@Test
func cleanupExecutionAuditRetryFinalizesAfterEvidenceWasCleared()
    async throws
{
    let store = try EvidenceStore(configuration: .memory)
    let plan = try CleanupPersistenceTestSupport.plan()
    let decisions = try plan.items.map {
        try CleanupPersistenceTestSupport.decision(plan: plan, item: $0)
    }
    let prepared = try CleanupPersistenceTestSupport.journal(plan: plan)
    let started = try CleanupPersistenceTestSupport.journal(
        plan: plan,
        stage: .actionStarted,
        entries: [
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[0],
                state: .started,
                decision: decisions[0]
            ),
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[1],
                decision: decisions[1]
            ),
        ]
    )
    let session: ScanSession = try EvidenceStoreTestSupport.fixture(
        ScanSession.self,
        name: "scan-session-v1"
    )
    try await store.saveScanSession(session)
    try await store.saveCleanupPlan(plan)
    for decision in decisions {
        try await store.savePolicyDecision(decision)
    }
    try await store.saveCleanupRunJournal(prepared)
    try await store.saveCleanupRunJournal(started)
    let firstOutcome = try CleanupPersistenceTestSupport.journal(
        plan: plan,
        stage: .actionOutcomeRecorded,
        entries: [
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[0],
                state: .outcomeRecorded,
                decision: decisions[0]
            ),
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[1],
                decision: decisions[1]
            ),
        ]
    )
    try await store.saveCleanupRunJournal(firstOutcome)
    let cancelled = try cancelledCoordinatorEntry(
        item: plan.items[1],
        decision: decisions[1],
        finishedAt: firstOutcome.updatedAt.addingTimeInterval(1)
    )
    let manifestPending = try CleanupRunJournal(
        id: firstOutcome.id,
        planID: firstOutcome.planID,
        manifestID: firstOutcome.manifestID,
        selectionGeneration: firstOutcome.selectionGeneration,
        selectionFingerprint: firstOutcome.selectionFingerprint,
        stage: .manifestPending,
        retentionClass: .audit,
        stopAfterCurrentRequested: true,
        entries: [firstOutcome.entries[0], cancelled],
        createdAt: firstOutcome.createdAt,
        updatedAt: firstOutcome.updatedAt.addingTimeInterval(1),
        expiresAt: firstOutcome.expiresAt,
        manifestCreatedAt: firstOutcome.updatedAt.addingTimeInterval(2)
    )
    try await store.saveCleanupRunJournal(manifestPending)
    try await store.clearEvidence()
    #expect(try await store.cleanupPlan(id: plan.id) == nil)
    let manifest = try CleanupAccounting().manifest(
        journal: manifestPending,
        volumeBefore: nil,
        volumeAfter: nil,
        createdAt: manifestPending.manifestCreatedAt!
    )
    try await store.saveCleanupManifest(manifest)
    let finalized = try CleanupRunJournal(
        id: manifestPending.id,
        planID: manifestPending.planID,
        manifestID: manifestPending.manifestID,
        selectionGeneration: manifestPending.selectionGeneration,
        selectionFingerprint: manifestPending.selectionFingerprint,
        stage: .finalized,
        retentionClass: .audit,
        stopAfterCurrentRequested: true,
        entries: manifestPending.entries,
        createdAt: manifestPending.createdAt,
        updatedAt: manifestPending.updatedAt.addingTimeInterval(1),
        expiresAt: manifestPending.expiresAt,
        manifestCreatedAt: manifest.createdAt
    )
    try await store.saveCleanupRunJournal(finalized)
    #expect(try await store.cleanupRunJournal(id: finalized.id) == finalized)
}

@Test
func cleanupExecutionRecoveryMakesStartedOutcomeUnknownWithoutReplay()
    async throws
{
    let harness = try await CleanupExecutionHarness()
    let prepared = try harness.preparedJournal()
    let started = try harness.startedJournal(from: prepared)
    await harness.store.seed(journal: started)

    let states = await harness.coordinator.recover()
    let recovered = try #require(states.first?.result)

    #expect(await harness.executor.callCount == 0)
    #expect(recovered.manifest.summary.unknownCount == 1)
    #expect(recovered.manifest.summary.cancelledCount == 1)
    #expect(recovered.manifest.records.map(\.result) == [
        .outcomeUnknown,
        .cancelled,
    ])
}

@Test
func cleanupExecutionRecoveryCancelsPreparedJournalWithoutReplay()
    async throws
{
    let harness = try await CleanupExecutionHarness()
    await harness.store.seed(journal: try harness.preparedJournal())

    let states = await harness.coordinator.recover()
    let recovered = try #require(states.first?.result)

    #expect(await harness.executor.callCount == 0)
    #expect(recovered.manifest.summary.cancelledCount == 2)
    #expect(recovered.manifest.summary.unknownCount == 0)
    #expect(recovered.manifest.records.allSatisfy {
        $0.result == .cancelled
    })
}

@Test
func cleanupExecutionDiagnosticRecoveryFinalizesWithoutExecutorReplay()
    async throws
{
    let store = try EvidenceStore(configuration: .memory)
    let basePlan = try CleanupPersistenceTestSupport.plan()
    let plan = try CleanupPersistenceTestSupport.plan(
        items: [basePlan.items[0]]
    )
    let decision = try CleanupPersistenceTestSupport.decision(
        plan: plan,
        item: plan.items[0]
    )
    let prepared = try CleanupPersistenceTestSupport.journal(
        plan: plan,
        entries: [
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[0],
                decision: decision
            ),
        ]
    )
    let started = try CleanupPersistenceTestSupport.journal(
        plan: plan,
        stage: .actionStarted,
        entries: [
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[0],
                state: .started,
                decision: decision
            ),
        ]
    )
    let journal = try CleanupPersistenceTestSupport.journal(
        plan: plan,
        stage: .actionOutcomeRecorded,
        entries: [
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[0],
                state: .outcomeRecorded,
                decision: decision
            ),
        ]
    )
    let session: ScanSession = try EvidenceStoreTestSupport.fixture(
        ScanSession.self,
        name: "scan-session-v1"
    )
    try await store.saveScanSession(session)
    try await store.saveCleanupPlan(plan)
    try await store.savePolicyDecision(decision)
    try await store.saveCleanupRunJournal(prepared)
    try await store.saveCleanupRunJournal(started)
    try await store.saveCleanupRunJournal(journal)
    let observation = CleanupRecoveryDiagnosticObservation()
    let runtime = CleanupExecutionRuntime.diagnosticRecovery(
        store: store,
        workflowCoordinator: CleanupWorkflowCoordinator(),
        observation: observation
    )

    let states = await runtime.recover()
    let result = try #require(states.first?.result)

    #expect(states.count == 1)
    #expect(states.first?.isCompleted == true)
    #expect(result.journal.stage == .finalized)
    #expect(result.manifest.summary.succeededCount == 1)
    #expect(observation.invocationCount() == 0)
}

private extension CleanupExecutionState {
    var result: CleanupExecutionResult? {
        switch self {
        case let .completed(result),
             let .partiallyFailed(result),
             let .stopped(result),
             let .auditPending(result),
             let .recoveryRequired(result),
             let .stale(_, result):
            result
        case .recoveryBlocked, .recoveryCorrupt, .rejected:
            nil
        }
    }
}

private func cancelledCoordinatorEntry(
    item: CleanupPlanItem,
    decision: PolicyDecision,
    finishedAt: Date
) throws -> CleanupRunJournalEntry {
    try CleanupRunJournalEntry(
        actionID: CleanupActionID(
            rawValue: "action-\(item.id.rawValue)"
        )!,
        planItemID: item.id,
        policyDecisionID: decision.id,
        policyDisposition: decision.disposition,
        policyReasonKeys: decision.reasonKeys,
        action: item.proposedAction,
        expectedIdentity: item.expectedIdentity!,
        actionFingerprint: DomainToken(
            rawValue: "action.\(item.id.rawValue).fingerprint"
        )!,
        state: .cancelled,
        startedAt: nil,
        outcome: CleanupJournalOutcome(
            result: .cancelled,
            recovery: .notStarted,
            measures: try CleanupManifestMeasures(
                candidateLogicalBytes: item.logicalBytes!,
                candidateAllocatedBytes: item.allocatedBytes!,
                processedLogicalBytes: ByteCount(0)!,
                processedAllocatedBytes: ByteCount(0)!,
                movedToTrashLogicalBytes: ByteCount(0)!,
                movedToTrashAllocatedBytes: ByteCount(0)!,
                permanentlyReleasedLogicalBytes: ByteCount(0)!,
                permanentlyReleasedAllocatedBytes: ByteCount(0)!
            ),
            destinationIdentity: nil,
            error: nil,
            finishedAt: finishedAt
        )
    )
}

private struct CleanupExecutionHarness {
    let now: Date
    let rootURL = URL(filePath: "/tmp/stornaut-execution-fixture")
    let plan: CleanupPlan
    let selection: ReviewSelection
    let evaluation: CleanupPolicyEvaluation
    let confirmation: CleanupConfirmation
    let collected: CleanupPolicyCollectedContext
    let store: FakeCleanupExecutionStore
    let executor: any HarnessCleanupExecutor
    let authorizationController: CleanupAuthorizationController
    let workflow = CleanupWorkflowCoordinator()
    let coordinator: CleanupExecutionCoordinator

    init(
        storeFailure: FakeCleanupExecutionStore.Failure? = nil,
        executor: (any HarnessCleanupExecutor)? = nil,
        deniedItemID: CleanupPlanItemID? = nil,
        originalIdentityAvailable: Bool = true,
        now: Date = CleanupPersistenceTestSupport.createdAt
            .addingTimeInterval(10),
        canonicalizeJournals: Bool = false,
        canonicalizeManifests: Bool = false,
        volumeSampler: (any CleanupVolumeSampling)? = nil
    ) async throws {
        self.now = now
        plan = try CleanupPersistenceTestSupport.plan()
        selection = try ReviewSelection(
            plan: plan,
            generation: 3,
            items: plan.items.map {
                ReviewSelectionItem(
                    itemID: $0.id,
                    origin: .explicitUser
                )
            },
            dispositions: Dictionary(
                uniqueKeysWithValues: plan.items.map {
                    ($0.id, ReclaimDisposition.readyToReclaim)
                }
            )
        )
        let contexts = try plan.items.map {
            try cleanupExecutionContext(
                item: $0,
                disposition: .readyToReclaim
            )
        }
        let policyContext = try CleanupPolicyContext(
            capturedAt: now,
            planID: plan.id,
            scanSessionID: plan.scanSessionID,
            scanScopeID: plan.scanScopeID!,
            scanIsTerminal: true,
            planFingerprint: plan.planFingerprint!,
            selectionGeneration: selection.generation,
            selectionFingerprint: selection.fingerprint,
            rootIdentity: plan.primaryRootIdentity!,
            catalogVersion: plan.catalogVersion!,
            executionProfileVersion: plan.executionProfileVersion!,
            workflow: .available,
            items: contexts
        )
        evaluation = try CleanupPolicyGate().evaluate(
            plan: plan,
            selection: selection,
            context: policyContext,
            evaluatedAt: now
        )
        confirmation = try #require(evaluation.allowed?.confirmation)
        collected = CleanupPolicyCollectedContext(
            policyContext: policyContext,
            rootURL: rootURL,
            rootAccess: .direct
        )
        store = FakeCleanupExecutionStore(
            plan: plan,
            failure: storeFailure,
            canonicalizeJournals: canonicalizeJournals,
            canonicalizeManifests: canonicalizeManifests
        )
        let executor = executor ?? SerialSuccessCleanupExecutor()
        self.executor = executor
        let authorizationClock = ExecutionHarnessClock(now)
        authorizationController = CleanupAuthorizationController(
            now: authorizationClock.now
        )
        let collector = FakeCleanupItemCollector(
            plan: plan,
            selection: selection,
            rootURL: rootURL,
            now: now,
            deniedItemID: deniedItemID
        )
        let planValue = plan
        coordinator = CleanupExecutionCoordinator(
            store: store,
            authorizationController: authorizationController,
            workflowCoordinator: workflow,
            itemCollector: collector,
            executor: executor,
            volumeSampler: volumeSampler,
            identityReader: { url in
                if url.path.contains("/tmp/fake-trash/") {
                    return planValue.items.first {
                        $0.expectedRelativePath?.rawValue
                            .split(separator: "/").last
                            .map(String.init)
                            == url.lastPathComponent
                    }?.expectedIdentity
                }
                if !originalIdentityAvailable {
                    return nil
                }
                return planValue.items.first {
                    url.path.hasSuffix(
                        $0.expectedRelativePath!.rawValue
                    )
                }?.expectedIdentity
            },
            now: ExecutionHarnessClock(now).now,
            runID: {
                CleanupRunID(rawValue: "run-coordinator-fixture")!
            },
            manifestID: {
                CleanupManifestID(
                    rawValue: "manifest-coordinator-fixture"
                )!
            },
            actionID: { itemID in
                CleanupActionID(
                    rawValue: "action-\(itemID.rawValue)"
                )!
            }
        )
    }

    func request() async throws -> CleanupExecutionRequest {
        let authorization = try await authorizationController.issue(
            evaluation: evaluation,
            confirmation: confirmation,
            collectedContext: collected
        )
        return CleanupExecutionRequest(
            plan: plan,
            selection: selection,
            evaluation: evaluation,
            confirmation: confirmation,
            collectedContext: collected,
            authorization: authorization
        )
    }

    func preparedJournal() throws -> CleanupRunJournal {
        try CleanupExecutionJournalBuilder(
            actionID: { itemID in
                CleanupActionID(
                    rawValue: "action-\(itemID.rawValue)"
                )!
            }
        ).preparedJournal(
            plan: plan,
            selection: selection,
            decisions: evaluation.allowed!.decisions,
            runID: CleanupRunID(rawValue: "run-recovery-fixture")!,
            manifestID: CleanupManifestID(
                rawValue: "manifest-recovery-fixture"
            )!,
            createdAt: now
        )
    }

    func startedJournal(
        from prepared: CleanupRunJournal
    ) throws -> CleanupRunJournal {
        var entries = prepared.entries
        entries[0] = try CleanupRunJournalEntry(
            actionID: entries[0].actionID,
            planItemID: entries[0].planItemID,
            policyDecisionID: entries[0].policyDecisionID,
            policyDisposition: entries[0].policyDisposition,
            policyReasonKeys: entries[0].policyReasonKeys,
            action: entries[0].action,
            expectedIdentity: entries[0].expectedIdentity,
            actionFingerprint: entries[0].actionFingerprint,
            state: .started,
            startedAt: now.addingTimeInterval(1),
            outcome: nil
        )
        return try CleanupRunJournal(
            id: prepared.id,
            planID: prepared.planID,
            manifestID: prepared.manifestID,
            selectionGeneration: prepared.selectionGeneration,
            selectionFingerprint: prepared.selectionFingerprint,
            stage: .actionStarted,
            retentionClass: .audit,
            stopAfterCurrentRequested: false,
            entries: entries,
            createdAt: prepared.createdAt,
            updatedAt: now.addingTimeInterval(1),
            expiresAt: prepared.createdAt
                .addingTimeInterval(90 * 86_400)
        )
    }
}

private func cleanupExecutionContext(
    item: CleanupPlanItem,
    disposition: ReclaimDisposition
) throws -> CleanupPolicyItemContext {
    try CleanupPolicyItemContext(
        itemID: item.id,
        snapshotID: item.snapshotID,
        classificationID: item.classificationID,
        ruleID: item.ruleID!,
        executionProfileID: item.executionProfileID!,
        proposedAction: item.proposedAction,
        persistedDisposition: disposition,
        currentDisposition: disposition,
        expectedRelativePath: item.expectedRelativePath!,
        currentRelativePath: item.expectedRelativePath!,
        expectedIdentity: item.expectedIdentity!,
        currentIdentity: item.expectedIdentity!,
        evidenceFingerprint: item.evidenceFingerprint!,
        currentEvidenceFingerprint: item.evidenceFingerprint!,
        activityFingerprint: item.activityFingerprint!,
        currentActivityFingerprint: item.activityFingerprint!,
        pathFacts: .allowed,
        evidenceFacts: .current,
        activityFacts: .inactive
    )
}

private func cleanupExecutionCollectedContext(
    harness: CleanupExecutionHarness,
    selection: ReviewSelection
) throws -> CleanupPolicyCollectedContext {
    CleanupPolicyCollectedContext(
        policyContext: try CleanupPolicyContext(
            capturedAt: harness.now,
            planID: harness.plan.id,
            scanSessionID: harness.plan.scanSessionID,
            scanScopeID: harness.plan.scanScopeID!,
            scanIsTerminal: true,
            planFingerprint: harness.plan.planFingerprint!,
            selectionGeneration: selection.generation,
            selectionFingerprint: selection.fingerprint,
            rootIdentity: harness.plan.primaryRootIdentity!,
            catalogVersion: harness.plan.catalogVersion!,
            executionProfileVersion:
                harness.plan.executionProfileVersion!,
            workflow: .available,
            items: try harness.plan.items.map {
                try cleanupExecutionContext(
                    item: $0,
                    disposition: .readyToReclaim
                )
            }
        ),
        rootURL: harness.rootURL,
        rootAccess: .direct
    )
}

private struct CleanupExecutionDateBox: Codable {
    let value: Date
}

private func backwardDriftingDomainDate(after start: Date) throws -> Date {
    for offset in 0..<10_000 {
        let candidate = start.addingTimeInterval(
            Double(offset) / 1_000_000
        )
        let canonical = try DomainJSON.decode(
            CleanupExecutionDateBox.self,
            from: DomainJSON.encode(
                CleanupExecutionDateBox(value: candidate)
            )
        ).value
        if canonical < candidate {
            return candidate
        }
    }
    throw DomainContractError.invalidMeasurement
}

private final class SequencedCleanupVolumeSampler:
    @unchecked Sendable,
    CleanupVolumeSampling
{
    private let lock = NSLock()
    private let samples: [CleanupVolumeSample]
    private var index = 0

    init(samples: [CleanupVolumeSample]) throws {
        guard !samples.isEmpty else {
            throw DomainContractError.invalidMeasurement
        }
        self.samples = samples
    }

    func sample(
        rootURL: URL,
        sampledAt: Date
    ) throws -> CleanupVolumeSample {
        _ = rootURL
        _ = sampledAt
        return lock.withLock {
            let sample = samples[min(index, samples.count - 1)]
            index += 1
            return sample
        }
    }
}

private actor OrderedRuntimePreflightCollector {
    let delayedSelection: ReviewSelection
    let delayedOutcome: CleanupPolicyCollectionOutcome
    let currentOutcome: CleanupPolicyCollectionOutcome
    private var delayedCollectionStarted = false
    private var startWaiter: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    init(
        delayedSelection: ReviewSelection,
        delayedOutcome: CleanupPolicyCollectionOutcome,
        currentOutcome: CleanupPolicyCollectionOutcome
    ) {
        self.delayedSelection = delayedSelection
        self.delayedOutcome = delayedOutcome
        self.currentOutcome = currentOutcome
    }

    func collect(
        selection: ReviewSelection
    ) async -> CleanupPolicyCollectionOutcome {
        guard selection == delayedSelection else {
            return currentOutcome
        }
        delayedCollectionStarted = true
        startWaiter?.resume()
        startWaiter = nil
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
        return delayedOutcome
    }

    func waitUntilDelayedCollectionStarts() async {
        if delayedCollectionStarted {
            return
        }
        await withCheckedContinuation { continuation in
            startWaiter = continuation
        }
    }

    func releaseDelayedCollection() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

private actor FakeCleanupItemCollector:
    CleanupItemPolicyContextCollecting
{
    let plan: CleanupPlan
    let selection: ReviewSelection
    let rootURL: URL
    let now: Date
    let deniedItemID: CleanupPlanItemID?

    init(
        plan: CleanupPlan,
        selection: ReviewSelection,
        rootURL: URL,
        now: Date,
        deniedItemID: CleanupPlanItemID?
    ) {
        self.plan = plan
        self.selection = selection
        self.rootURL = rootURL
        self.now = now
        self.deniedItemID = deniedItemID
    }

    func collectItem(
        plan: CleanupPlan,
        selection: ReviewSelection,
        itemID: CleanupPlanItemID,
        workflow: CleanupWorkflowAvailabilitySnapshot
    ) -> CleanupPolicyCollectionOutcome {
        guard self.plan == plan,
              self.selection == selection,
              let item = plan.items.first(where: { $0.id == itemID })
        else {
            return .blocked(
                error: .invalidSelection,
                affectedItemIDs: [itemID]
            )
        }
        do {
            return .collected(
                CleanupPolicyCollectedContext(
                    policyContext: try CleanupPolicyContext(
                        capturedAt: now,
                        planID: plan.id,
                        scanSessionID: plan.scanSessionID,
                        scanScopeID: plan.scanScopeID!,
                        scanIsTerminal: true,
                        planFingerprint: plan.planFingerprint!,
                        selectionGeneration: selection.generation,
                        selectionFingerprint: selection.fingerprint,
                        rootIdentity: plan.primaryRootIdentity!,
                        catalogVersion: plan.catalogVersion!,
                        executionProfileVersion:
                            plan.executionProfileVersion!,
                        workflow: workflow,
                        items: [
                            try cleanupExecutionContext(
                                item: item,
                                disposition: item.id == deniedItemID
                                    ? .protected
                                    : .readyToReclaim
                            ),
                        ]
                    ),
                    rootURL: rootURL,
                    rootAccess: .direct
                )
            )
        } catch {
            return .blocked(
                error: .itemTruthUnavailable,
                affectedItemIDs: [itemID]
            )
        }
    }
}

private protocol HarnessCleanupExecutor: CleanupActionExecuting {
    var callCount: Int { get async }
    var maximumConcurrentCalls: Int { get async }
    var targetPaths: [String] { get async }
}

private actor SerialSuccessCleanupExecutor: HarnessCleanupExecutor {
    private var actions: [CleanupAction] = []
    private var activeCalls = 0
    private var maximum = 0

    var callCount: Int { actions.count }
    var maximumConcurrentCalls: Int { maximum }
    var targetPaths: [String] {
        actions.compactMap { action in
            guard case let .moveToTrash(pathAction) = action else {
                return nil
            }
            let rootComponents = URL(
                filePath: "/tmp/stornaut-execution-fixture"
            ).pathComponents.count
            return pathAction.targetURL.pathComponents
                .dropFirst(rootComponents)
                .joined(separator: "/")
        }
    }

    nonisolated func preflight(
        _ action: CleanupAction,
        context: ActionPolicyContext
    ) throws -> ActionPreflightToken {
        ActionPreflightToken(
            action: action,
            registeredInvocation: nil,
            executableIdentity: nil
        )
    }

    func execute(
        _ token: ActionPreflightToken,
        context: ActionPolicyContext
    ) async throws -> ActionExecution {
        actions.append(token.action)
        activeCalls += 1
        maximum = max(maximum, activeCalls)
        defer { activeCalls -= 1 }
        guard case let .moveToTrash(pathAction) = token.action else {
            throw ActionExecutionError.invalidPreflightToken
        }
        return .trash(
            receipt: TrashedItemReceipt(
                originalURL: pathAction.targetURL,
                originalIdentity: pathAction.expectedIdentity,
                resultingTrashURL: URL(
                    filePath: "/tmp/fake-trash"
                ).appending(path: pathAction.targetURL.lastPathComponent),
                movedAt: Date(),
                logicalBytesMoved: pathAction.expectedIdentity.size,
                allocatedBytesMoved:
                    pathAction.expectedIdentity.allocatedBytes
            ),
            startedAt: Date(),
            finishedAt: Date()
        )
    }

    nonisolated func postflight(
        _ execution: ActionExecution
    ) throws -> ActionResult {
        guard case let .trash(receipt, startedAt, finishedAt) = execution else {
            throw ActionExecutionError.unexpectedResult
        }
        return ActionResult(
            status: .succeeded,
            logicalBytesAffected: receipt.logicalBytesMoved,
            allocatedBytesAffected: receipt.allocatedBytesMoved,
            completedItems: 1,
            failedItems: 0,
            exitStatus: nil,
            startedAt: startedAt,
            finishedAt: finishedAt,
            trashReceipt: receipt
        )
    }
}

private actor BlockingCleanupExecutor: HarnessCleanupExecutor {
    private let base = SerialSuccessCleanupExecutor()
    private var blocked = false
    private var waiter: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    var callCount: Int { get async { await base.callCount } }
    var maximumConcurrentCalls: Int {
        get async { await base.maximumConcurrentCalls }
    }
    var targetPaths: [String] {
        get async { await base.targetPaths }
    }

    nonisolated func preflight(
        _ action: CleanupAction,
        context: ActionPolicyContext
    ) throws -> ActionPreflightToken {
        try base.preflight(action, context: context)
    }

    func execute(
        _ token: ActionPreflightToken,
        context: ActionPolicyContext
    ) async throws -> ActionExecution {
        if !blocked {
            blocked = true
            waiter?.resume()
            waiter = nil
            await withCheckedContinuation { continuation in
                releaseContinuation = continuation
            }
        }
        return try await base.execute(token, context: context)
    }

    nonisolated func postflight(
        _ execution: ActionExecution
    ) throws -> ActionResult {
        try base.postflight(execution)
    }

    func waitUntilBlocked() async {
        if blocked { return }
        await withCheckedContinuation { continuation in
            waiter = continuation
        }
    }

    func release() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

private actor FailingThenSuccessCleanupExecutor: HarnessCleanupExecutor {
    private let base = SerialSuccessCleanupExecutor()
    private var attempts = 0

    var callCount: Int { attempts }
    var maximumConcurrentCalls: Int {
        get async { await base.maximumConcurrentCalls }
    }
    var targetPaths: [String] {
        get async { await base.targetPaths }
    }

    nonisolated func preflight(
        _ action: CleanupAction,
        context: ActionPolicyContext
    ) throws -> ActionPreflightToken {
        try base.preflight(action, context: context)
    }

    func execute(
        _ token: ActionPreflightToken,
        context: ActionPolicyContext
    ) async throws -> ActionExecution {
        attempts += 1
        if attempts == 1 {
            throw CleanupActionExecutionFailure.permissionDenied
        }
        return try await base.execute(token, context: context)
    }

    nonisolated func postflight(
        _ execution: ActionExecution
    ) throws -> ActionResult {
        try base.postflight(execution)
    }
}

private actor CancellationCleanupExecutor: HarnessCleanupExecutor {
    private var attempts = 0

    var callCount: Int { attempts }
    var maximumConcurrentCalls: Int { attempts > 0 ? 1 : 0 }
    var targetPaths: [String] { [] }

    nonisolated func preflight(
        _ action: CleanupAction,
        context: ActionPolicyContext
    ) throws -> ActionPreflightToken {
        ActionPreflightToken(
            action: action,
            registeredInvocation: nil,
            executableIdentity: nil
        )
    }

    func execute(
        _ token: ActionPreflightToken,
        context: ActionPolicyContext
    ) async throws -> ActionExecution {
        attempts += 1
        throw CancellationError()
    }

    nonisolated func postflight(
        _ execution: ActionExecution
    ) throws -> ActionResult {
        throw ActionExecutionError.unexpectedResult
    }
}

private actor FinalRevalidationFailureExecutor: HarnessCleanupExecutor {
    var callCount: Int { 0 }
    var maximumConcurrentCalls: Int { 0 }
    var targetPaths: [String] { [] }

    nonisolated func preflight(
        _ action: CleanupAction,
        context: ActionPolicyContext
    ) throws -> ActionPreflightToken {
        ActionPreflightToken(
            action: action,
            registeredInvocation: nil,
            executableIdentity: nil
        )
    }

    func execute(
        _ token: ActionPreflightToken,
        context: ActionPolicyContext
    ) async throws -> ActionExecution {
        throw ActionPolicyError.identityChanged
    }

    nonisolated func postflight(
        _ execution: ActionExecution
    ) throws -> ActionResult {
        throw ActionExecutionError.unexpectedResult
    }
}

private actor FailingThenBlockingCleanupExecutor: HarnessCleanupExecutor {
    private let base = SerialSuccessCleanupExecutor()
    private var attempts = 0
    private var blocked = false
    private var waiter: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    var callCount: Int { attempts }
    var maximumConcurrentCalls: Int {
        get async { await base.maximumConcurrentCalls }
    }
    var targetPaths: [String] {
        get async { await base.targetPaths }
    }

    nonisolated func preflight(
        _ action: CleanupAction,
        context: ActionPolicyContext
    ) throws -> ActionPreflightToken {
        try base.preflight(action, context: context)
    }

    func execute(
        _ token: ActionPreflightToken,
        context: ActionPolicyContext
    ) async throws -> ActionExecution {
        attempts += 1
        if attempts == 1 {
            throw CleanupActionExecutionFailure.permissionDenied
        }
        blocked = true
        waiter?.resume()
        waiter = nil
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
        return try await base.execute(token, context: context)
    }

    nonisolated func postflight(
        _ execution: ActionExecution
    ) throws -> ActionResult {
        try base.postflight(execution)
    }

    func waitUntilSecondBlocked() async {
        if blocked { return }
        await withCheckedContinuation { continuation in
            waiter = continuation
        }
    }

    func release() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

private actor FakeCleanupExecutionStore: CleanupExecutionStore {
    enum Failure: Equatable {
        case journalSave(call: Int)
        case manifestSave
    }

    let plan: CleanupPlan
    private var failure: Failure?
    private let canonicalizeJournals: Bool
    private let canonicalizeManifests: Bool
    private var journalSaveCalls = 0
    private var decisions: [PolicyDecisionID: PolicyDecision] = [:]
    private var journal: CleanupRunJournal?
    private var manifest: CleanupManifest?
    private(set) var savedJournalStages: [CleanupRunJournalStage] = []
    var currentJournal: CleanupRunJournal? { journal }

    init(
        plan: CleanupPlan,
        failure: Failure?,
        canonicalizeJournals: Bool = false,
        canonicalizeManifests: Bool = false
    ) {
        self.plan = plan
        self.failure = failure
        self.canonicalizeJournals = canonicalizeJournals
        self.canonicalizeManifests = canonicalizeManifests
    }

    func clearFailure() {
        failure = nil
    }

    func seed(journal: CleanupRunJournal) {
        self.journal = journal
    }

    func savePolicyDecision(_ decision: PolicyDecision) {
        decisions[decision.id] = decision
    }

    func scanSession(id: ScanSessionID) -> ScanSession? {
        nil
    }

    func saveCleanupRunJournal(
        _ journal: CleanupRunJournal
    ) throws {
        journalSaveCalls += 1
        if failure == .journalSave(call: journalSaveCalls) {
            throw EvidenceStoreError.integrityCheckFailed
        }
        self.journal = canonicalizeJournals
            ? try DomainJSON.decode(
                CleanupRunJournal.self,
                from: DomainJSON.encode(journal)
            )
            : journal
        savedJournalStages.append(journal.stage)
    }

    func cleanupRunJournal(
        id: CleanupRunID
    ) -> CleanupRunJournal? {
        journal?.id == id ? journal : nil
    }

    func cleanupRunJournals(
        limit: Int,
        offset: Int
    ) -> StorePage<CleanupRunJournal> {
        StorePage(
            records: journal.map { [$0] } ?? [],
            corruptRecordIDs: []
        )
    }

    func saveCleanupManifest(_ manifest: CleanupManifest) throws {
        if failure == .manifestSave {
            throw EvidenceStoreError.integrityCheckFailed
        }
        self.manifest = canonicalizeManifests
            ? try DomainJSON.decode(
                CleanupManifest.self,
                from: DomainJSON.encode(manifest)
            )
            : manifest
    }

    func cleanupManifest(
        id: CleanupManifestID
    ) -> CleanupManifest? {
        manifest?.id == id ? manifest : nil
    }

    func cleanupPlan(id: CleanupPlanID) -> CleanupPlan? {
        plan.id == id ? plan : nil
    }
}

private final class ExecutionHarnessClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date

    init(_ value: Date) {
        self.value = value
    }

    func now() -> Date {
        lock.withLock { value }
    }
}
