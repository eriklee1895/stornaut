import StornautCore
import Testing
@testable import StornautApp

@Test
func cleanupResultSnapshotAcceptsOnlyManifestBearingTerminalTruth()
    throws
{
    let fixture = try CleanupResultTestSupport.fixture(.completed)

    let snapshot = try CleanupResultSnapshot(
        executionState: fixture.executionState,
        itemFacts: fixture.retainedFacts,
        evidenceAvailability: .retained
    )

    #expect(snapshot.result == fixture.result)
    #expect(snapshot.manifest == fixture.result.manifest)
    #expect(snapshot.journal == fixture.result.journal)
    #expect(snapshot.manifest.summary == fixture.result.manifest.summary)

    #expect(throws: CleanupResultContractError.invalidTerminalState) {
        _ = try CleanupResultSnapshot(
            executionState: .rejected(.authorization),
            itemFacts: [],
            evidenceAvailability: .expired
        )
    }
}

@Test
func cleanupResultSnapshotRejectsDuplicateOrUnboundFacts() throws {
    let fixture = try CleanupResultTestSupport.fixture(.completed)
    let duplicate = fixture.retainedFacts + [fixture.retainedFacts[0]]

    #expect(throws: CleanupResultContractError.invalidEvidenceFacts) {
        _ = try CleanupResultSnapshot(
            executionState: fixture.executionState,
            itemFacts: duplicate,
            evidenceAvailability: .retained
        )
    }

    let unknown = CleanupResultItemFacts(
        planItemID: CleanupPlanItemID(
            rawValue: "plan-item-cleanup-result-unknown"
        )!,
        itemName: "must not leak",
        exactOriginalPath: "/tmp/must-not-leak",
        expectedIdentity:
            fixture.result.journal.entries[0].expectedIdentity,
        evidenceFingerprint: DomainToken(
            rawValue: "evidence.cleanup-result.unknown"
        )!,
        producer: nil,
        recoveryDetailKey: DomainToken(
            rawValue: "cleanup.recovery.unknown"
        )!,
        evidenceLineage: []
    )
    #expect(throws: CleanupResultContractError.invalidEvidenceFacts) {
        _ = try CleanupResultSnapshot(
            executionState: fixture.executionState,
            itemFacts: [unknown],
            evidenceAvailability: .retained
        )
    }
}

@Test
func expiredEvidenceDropsPathRichFactsWithoutChangingManifest() throws {
    let fixture = try CleanupResultTestSupport.fixture(.completed)

    let snapshot = try CleanupResultSnapshot(
        executionState: fixture.executionState,
        itemFacts: fixture.retainedFacts,
        evidenceAvailability: .expired
    )

    #expect(snapshot.itemFacts.isEmpty)
    #expect(snapshot.evidenceAvailability == .expired)
    #expect(snapshot.manifest == fixture.result.manifest)
}

@Test
func cleanupResultReducerAcceptsFirstTerminalAndIgnoresReplacement()
    throws
{
    let first = try CleanupResultTestSupport.fixture(.completed)
    let replacement = try CleanupResultTestSupport.fixture(.partial)
    let reducer = CleanupResultReducer()

    let presented = reducer.receivedTerminal(
        first.executionState,
        itemFacts: first.retainedFacts,
        evidenceAvailability: .retained,
        state: .idle
    )
    let unchanged = reducer.receivedTerminal(
        replacement.executionState,
        itemFacts: replacement.retainedFacts,
        evidenceAvailability: .retained,
        state: presented
    )

    #expect(presented.phase == .presented)
    #expect(unchanged == presented)
    #expect(unchanged.snapshot?.manifest.id == first.result.manifest.id)
}

@Test
func cleanupResultRouteRequiresAcceptedTerminalAndDoneReturnsToResults()
    throws
{
    let fixture = try CleanupResultTestSupport.fixture(.completed)
    let reducer = ReviewRouteReducer()

    #expect(
        reducer.openCleanupResult(
            from: .review,
            terminalWasAccepted: false
        ) == .review
    )
    #expect(
        reducer.openCleanupResult(
            from: .review,
            terminalWasAccepted: true
        ) == .cleanupResult
    )
    #expect(
        reducer.closeCleanupResult(from: .cleanupResult) == .results
    )
    #expect(
        reducer.openCleanupResult(
            from: .results,
            terminalWasAccepted: true
        ) == .results
    )

    let snapshot = try CleanupResultSnapshot(
        executionState: fixture.executionState,
        itemFacts: fixture.retainedFacts,
        evidenceAvailability: .retained
    )
    #expect(CleanupResultReducer().done(state: .presented(snapshot)) == .idle)
}

@Test
func trashFailureAndAuditRetryPreserveImmutableResult() throws {
    let completed = try CleanupResultTestSupport.fixture(.completed)
    let audit = try CleanupResultTestSupport.fixture(.auditPending)
    let completedSnapshot = try CleanupResultSnapshot(
        executionState: completed.executionState,
        itemFacts: completed.retainedFacts,
        evidenceAvailability: .retained
    )
    let auditSnapshot = try CleanupResultSnapshot(
        executionState: audit.executionState,
        itemFacts: audit.retainedFacts,
        evidenceAvailability: .retained
    )
    let reducer = CleanupResultReducer()

    let opening = reducer.beginOpenTrash(
        state: .presented(completedSnapshot)
    )
    let failed = reducer.openTrashFinished(
        succeeded: false,
        state: opening
    )
    #expect(failed.phase == .trashUnavailable)
    #expect(failed.snapshot == completedSnapshot)

    let retrying = reducer.beginAuditRetry(
        state: .presented(auditSnapshot)
    )
    #expect(retrying.phase == .retryingAudit)
    #expect(retrying.snapshot == auditSnapshot)
}

@Test
func auditRetryRejectsAReplacementRunWithTheSameManifest() throws {
    let pending = try CleanupResultTestSupport.fixture(.auditPending)
    let snapshot = try CleanupResultSnapshot(
        executionState: pending.executionState,
        itemFacts: pending.retainedFacts,
        evidenceAvailability: .retained
    )
    let differentJournal = try CleanupRunJournal(
        id: CleanupRunID(rawValue: "run-cleanup-result-replacement")!,
        planID: pending.result.journal.planID,
        manifestID: pending.result.journal.manifestID,
        selectionGeneration:
            pending.result.journal.selectionGeneration,
        selectionFingerprint:
            pending.result.journal.selectionFingerprint,
        stage: .finalized,
        retentionClass: .audit,
        stopAfterCurrentRequested:
            pending.result.journal.stopAfterCurrentRequested,
        entries: pending.result.journal.entries,
        createdAt: pending.result.journal.createdAt,
        updatedAt:
            pending.result.journal.updatedAt.addingTimeInterval(1),
        expiresAt: pending.result.journal.expiresAt,
        manifestCreatedAt:
            pending.result.journal.manifestCreatedAt,
        systemObservation:
            pending.result.journal.systemObservation
    )
    let replacement = try CleanupExecutionResult(
        journal: differentJournal,
        manifest: pending.result.manifest
    )
    let reducer = CleanupResultReducer()
    let retrying = reducer.beginAuditRetry(
        state: .presented(snapshot)
    )

    let finished = reducer.auditRetryFinished(
        .completed(replacement),
        state: retrying
    )

    #expect(finished == .presented(snapshot))
}

@Test
func unknownAuditPendingCannotEnterAuditRetry() throws {
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
    let pending = try CleanupExecutionResult(
        journal: pendingJournal,
        manifest: unknown.result.manifest
    )
    let snapshot = try CleanupResultSnapshot(
        executionState: .auditPending(pending),
        itemFacts: unknown.retainedFacts,
        evidenceAvailability: .retained
    )

    #expect(
        CleanupResultReducer().beginAuditRetry(
            state: .presented(snapshot)
        ) == .presented(snapshot)
    )
}

@Test
func doneAlwaysClearsUnavailableCleanupResultState() {
    let state = CleanupResultState.unavailable(
        DomainToken(rawValue: "cleanup.result.invalid-terminal")!
    )

    #expect(CleanupResultReducer().done(state: state) == .idle)
}
