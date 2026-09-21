import StornautCore
import Testing
@testable import StornautApp

@Test
func completedCleanupResultUsesManifestSummaryWithoutCombiningAccounting()
    throws
{
    let fixture = try CleanupResultTestSupport.fixture(.completed)
    let snapshot = try CleanupResultSnapshot(
        executionState: fixture.executionState,
        itemFacts: fixture.retainedFacts,
        evidenceAvailability: .retained
    )

    let model = CleanupResultModel(state: .presented(snapshot))

    #expect(model.outcome == .completed)
    #expect(model.manifestPersistence == .saved)
    #expect(model.summary == fixture.result.manifest.summary)
    #expect(
        model.movedToTrashBytes
            == fixture.result.manifest.summary.movedToTrashAllocatedBytes
    )
    #expect(
        model.permanentlyReleasedBytes
            == fixture.result.manifest.summary
                .permanentlyReleasedAllocatedBytes
    )
    #expect(model.permanentlyReleasedBytes == ByteCount(0))
    #expect(model.systemObservation?.freeSpaceDelta.value == 350_000)
    #expect(model.hasSyntheticReclaimedTotal == false)
    #expect(model.rows.count == fixture.result.manifest.records.count)
    #expect(model.availableActions == [.openTrash, .viewManifest, .done])
}

@Test
func partialAndFailedOutcomesPreserveKnownOriginalRecovery() throws {
    let partial = try CleanupResultTestSupport.fixture(.partial)
    let partialSnapshot = try CleanupResultSnapshot(
        executionState: partial.executionState,
        itemFacts: partial.retainedFacts,
        evidenceAvailability: .retained
    )
    let partialModel = CleanupResultModel(
        state: .presented(partialSnapshot)
    )

    #expect(partialModel.outcome == .completedWithIssues)
    #expect(partialModel.summary?.succeededCount == 1)
    #expect(partialModel.summary?.failedCount == 1)
    #expect(
        partialModel.rows.first {
            $0.result == .failed
        }?.recoveryPresentation == .originalRemains
    )

    let failed = try CleanupResultTestSupport.fixture(.failed)
    let failedModel = CleanupResultModel(
        state: .presented(
            try CleanupResultSnapshot(
                executionState: failed.executionState,
                itemFacts: failed.retainedFacts,
                evidenceAvailability: .retained
            )
        )
    )
    #expect(failedModel.outcome == .failed)
    #expect(failedModel.summary?.succeededCount == 0)
    #expect(failedModel.availableActions == [.viewManifest, .done])
    #expect(!failedModel.availableActions.contains(.retry))
}

@Test
func stoppedAndUnknownOutcomesNeverOfferBlindRetry() throws {
    let stopped = try CleanupResultTestSupport.fixture(.stopped)
    let stoppedModel = CleanupResultModel(
        state: .presented(
            try CleanupResultSnapshot(
                executionState: stopped.executionState,
                itemFacts: stopped.retainedFacts,
                evidenceAvailability: .retained
            )
        )
    )
    #expect(stoppedModel.outcome == .stopped)
    #expect(stoppedModel.summary?.cancelledCount == 1)
    #expect(!stoppedModel.availableActions.contains(.retry))

    let unknown = try CleanupResultTestSupport.fixture(.outcomeUnknown)
    let unknownModel = CleanupResultModel(
        state: .presented(
            try CleanupResultSnapshot(
                executionState: unknown.executionState,
                itemFacts: unknown.retainedFacts,
                evidenceAvailability: .retained
            )
        )
    )
    #expect(unknownModel.outcome == .outcomeUnknown)
    #expect(unknownModel.summary?.unknownCount == 1)
    #expect(
        unknownModel.rows.first {
            $0.result == .outcomeUnknown
        }?.recoveryPresentation == .outcomeUnknown
    )
    #expect(!unknownModel.availableActions.contains(.retry))
    #expect(!unknownModel.availableActions.contains(.openTrash))
}

@Test
func auditPendingKeepsActionTruthAndExposesOnlyAuditRetry() throws {
    let fixture = try CleanupResultTestSupport.fixture(.auditPending)
    let model = CleanupResultModel(
        state: .presented(
            try CleanupResultSnapshot(
                executionState: fixture.executionState,
                itemFacts: fixture.retainedFacts,
                evidenceAvailability: .retained
            )
        )
    )

    #expect(model.outcome == .auditPending)
    #expect(model.manifestPersistence == .auditPending)
    #expect(model.summary?.succeededCount == 2)
    #expect(model.availableActions.contains(.retrySavingAudit))
    #expect(!model.availableActions.contains(.retry))
}

@Test
func missingSystemObservationIsUnknownRatherThanZero() throws {
    let fixture = try CleanupResultTestSupport.fixture(
        .completed,
        includesObservation: false
    )
    let model = CleanupResultModel(
        state: .presented(
            try CleanupResultSnapshot(
                executionState: fixture.executionState,
                itemFacts: fixture.retainedFacts,
                evidenceAvailability: .retained
            )
        )
    )

    #expect(model.systemObservation == nil)
    #expect(model.systemObservationPresentation == .unavailable)
}

@Test
func expiredEvidenceRemovesNamesPathsAndLineageButKeepsAuditIDs()
    throws
{
    let fixture = try CleanupResultTestSupport.fixture(.completed)
    let model = CleanupResultModel(
        state: .presented(
            try CleanupResultSnapshot(
                executionState: fixture.executionState,
                itemFacts: fixture.retainedFacts,
                evidenceAvailability: .expired
            )
        )
    )

    #expect(model.evidenceAvailability == .expired)
    #expect(model.rows.allSatisfy { $0.itemName == nil })
    #expect(model.rows.allSatisfy { $0.exactOriginalPath == nil })
    #expect(model.rows.allSatisfy { $0.evidenceLineage.isEmpty })
    #expect(
        model.rows.map(\.planItemID)
            == fixture.result.manifest.records.map(\.planItemID)
    )
    #expect(model.manifestDetail?.evidenceAvailability == .expired)
}

@Test
func manifestDetailPreservesJournalOrderAndClosedTypedFacts() throws {
    let fixture = try CleanupResultTestSupport.fixture(.partial)
    let model = CleanupResultModel(
        state: .presented(
            try CleanupResultSnapshot(
                executionState: fixture.executionState,
                itemFacts: fixture.retainedFacts,
                evidenceAvailability: .retained
            )
        )
    )

    #expect(
        model.manifestDetail?.entries.map(\.actionID)
            == fixture.result.journal.entries.map(\.actionID)
    )
    #expect(
        model.manifestDetail?.entries.map(\.policyDisposition)
            == fixture.result.manifest.records.map(\.policyDisposition)
    )
    #expect(model.manifestDetail?.hasRawJSON == false)
    #expect(model.manifestDetail?.hasExecutionAction == false)
}

@Test
func partiallyFailedTrashRowsRemainCompletedWithIssuesAndCountAsMoved()
    throws
{
    let fixture = try CleanupResultTestSupport.fixture(.partialMove)
    let model = CleanupResultModel(
        state: .presented(
            try CleanupResultSnapshot(
                executionState: fixture.executionState,
                itemFacts: fixture.retainedFacts,
                evidenceAvailability: .retained
            )
        )
    )

    #expect(model.outcome == .completedWithIssues)
    #expect(model.movedToTrashItemCount == fixture.plan.items.count)
    #expect(model.movedToTrashBytes.value > 0)
}

@Test
func unknownOutcomeOutranksAuditPersistenceAndSuppressesRetry()
    throws
{
    let unknown = try CleanupResultTestSupport.fixture(.outcomeUnknown)
    let pendingJournal = try CleanupRunJournal(
        id: unknown.result.journal.id,
        planID: unknown.result.journal.planID,
        manifestID: unknown.result.journal.manifestID,
        selectionGeneration:
            unknown.result.journal.selectionGeneration,
        selectionFingerprint:
            unknown.result.journal.selectionFingerprint,
        stage: .auditPending,
        retentionClass: .audit,
        stopAfterCurrentRequested:
            unknown.result.journal.stopAfterCurrentRequested,
        entries: unknown.result.journal.entries,
        createdAt: unknown.result.journal.createdAt,
        updatedAt:
            unknown.result.journal.updatedAt.addingTimeInterval(1),
        expiresAt: unknown.result.journal.expiresAt,
        manifestCreatedAt:
            unknown.result.journal.manifestCreatedAt,
        systemObservation:
            unknown.result.journal.systemObservation
    )
    let pendingResult = try CleanupExecutionResult(
        journal: pendingJournal,
        manifest: unknown.result.manifest
    )
    let model = CleanupResultModel(
        state: .presented(
            try CleanupResultSnapshot(
                executionState: .auditPending(pendingResult),
                itemFacts: unknown.retainedFacts,
                evidenceAvailability: .retained
            )
        )
    )

    #expect(model.outcome == .outcomeUnknown)
    #expect(model.manifestPersistence == .auditPending)
    #expect(!model.availableActions.contains(.retrySavingAudit))
}

@Test
func signedSystemObservationPreservesNegativeZeroAndPositiveValues() {
    #expect(
        CleanupResultFormatting.signedBytes(
            SignedByteDelta(-350_000)
        ).hasPrefix("-")
    )
    #expect(
        CleanupResultFormatting.signedBytes(
            SignedByteDelta(0)
        ) == "0 B"
    )
    #expect(
        CleanupResultFormatting.signedBytes(
            SignedByteDelta(350_000)
        ).hasPrefix("+")
    )
}

@Test
func manifestDetailCarriesEveryRequiredTypedFact() throws {
    let fixture = try CleanupResultTestSupport.fixture(.partialMove)
    let model = CleanupResultModel(
        state: .presented(
            try CleanupResultSnapshot(
                executionState: fixture.executionState,
                itemFacts: fixture.retainedFacts,
                evidenceAvailability: .retained
            )
        )
    )
    let entry = try #require(model.manifestDetail?.entries.first)

    #expect(!entry.policyReasonKeys.isEmpty)
    #expect(!entry.evidenceLineage.isEmpty)
    #expect(entry.recoveryDetailKey != nil)
    #expect(entry.measures.candidateAllocatedBytes.value > 0)
    #expect(entry.measures.permanentlyReleasedAllocatedBytes == ByteCount(0))
    #expect(model.manifestDetail?.systemObservation != nil)
}

@Test
func zeroByteMovedItemsStillOfferTrashNavigation() throws {
    let fixture = try CleanupResultTestSupport.fixture(
        .completed,
        zeroByteItems: true
    )
    let model = CleanupResultModel(
        state: .presented(
            try CleanupResultSnapshot(
                executionState: fixture.executionState,
                itemFacts: fixture.retainedFacts,
                evidenceAvailability: .retained
            )
        )
    )

    #expect(model.movedToTrashBytes == ByteCount(0))
    #expect(model.movedToTrashItemCount == fixture.plan.items.count)
    #expect(model.availableActions.contains(.openTrash))
}
