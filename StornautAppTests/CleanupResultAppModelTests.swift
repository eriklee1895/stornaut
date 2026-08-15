import Foundation
import StornautCore
import Testing
@testable import StornautApp

@MainActor
@Test
func firstValidTerminalRoutesReviewToCleanupResult() async throws {
    let review = try ReviewAppFixture()
    let snapshot = try ReviewSnapshot(
        plan: review.plan,
        projection: review.projection,
        generation: 1,
        executionAvailability: .debugFake
    )
    let selection = try #require(snapshot.reviewSelection)
    let fixture = try CleanupResultTestSupport.fixture(
        plan: review.plan,
        selection: selection,
        scenario: .completed
    )
    let evaluation = try ReviewConfirmationFixture.evaluate(
        plan: review.plan,
        selection: selection,
        activityFacts: .inactive
    )
    let stream = CleanupResultExecutionDriver()
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            preflightReview: { _, _ in evaluation },
            reviewExecutionAvailability: .debugFake,
            startReviewExecution: { _, _, _ in
                await stream.makeStream()
            },
            cleanupResultEnrichment: { _ in
                CleanupResultEnrichment(
                    itemFacts: fixture.retainedFacts,
                    evidenceAvailability: .retained
                )
            }
        ),
        initialScanWorkspaceRoute: .review,
        initialReviewState: .ready(snapshot),
        refreshesServices: false
    )

    model.preflightReview()
    await waitForCleanupResult {
        model.reviewState.phase == .confirming
    }
    model.confirmReviewExecution()
    await stream.waitUntilStarted()
    await stream.yield(.progress(.queued(total: 1)))
    await stream.yield(.terminal(fixture.executionState))
    await waitForCleanupResult {
        model.scanWorkspaceRoute == .cleanupResult
    }

    #expect(model.cleanupResultState.phase == .presented)
    #expect(
        model.cleanupResultState.snapshot?.manifest.id
            == fixture.result.manifest.id
    )

    await stream.yield(
        .terminal(
            try CleanupResultTestSupport.fixture(.partial)
                .executionState
        )
    )
    await Task.yield()
    #expect(
        model.cleanupResultState.snapshot?.manifest.id
            == fixture.result.manifest.id
    )
}

@MainActor
@Test
func executionStreamWithoutTerminalNeverClaimsCleanupResult() async throws {
    let review = try ReviewAppFixture()
    let snapshot = try ReviewSnapshot(
        plan: review.plan,
        projection: review.projection,
        generation: 1,
        executionAvailability: .debugFake
    )
    let selection = try #require(snapshot.reviewSelection)
    let evaluation = try ReviewConfirmationFixture.evaluate(
        plan: review.plan,
        selection: selection,
        activityFacts: .inactive
    )
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            preflightReview: { _, _ in evaluation },
            reviewExecutionAvailability: .debugFake,
            startReviewExecution: { _, _, _ in
                AsyncStream { continuation in
                    continuation.yield(.progress(.queued(total: 1)))
                    continuation.finish()
                }
            }
        ),
        initialScanWorkspaceRoute: .review,
        initialReviewState: .ready(snapshot),
        refreshesServices: false
    )

    model.preflightReview()
    await waitForCleanupResult {
        model.reviewState.phase == .confirming
    }
    model.confirmReviewExecution()
    await waitForCleanupResult {
        model.reviewState.phase == .executionBlocked
    }

    #expect(model.scanWorkspaceRoute == .review)
    #expect(model.cleanupResultState == .idle)
}

@MainActor
@Test
func doneClearsResultAndReturnsToScanResults() throws {
    let fixture = try CleanupResultTestSupport.fixture(.completed)
    let state = CleanupResultReducer().receivedTerminal(
        fixture.executionState,
        itemFacts: fixture.retainedFacts,
        evidenceAvailability: .retained,
        state: .idle
    )
    let model = StornautAppModel(
        dependencies: AppDependencies(loadLatestQuickScan: { nil }),
        initialScanWorkspaceRoute: .cleanupResult,
        initialCleanupResultState: state,
        refreshesServices: false
    )

    model.doneCleanupResult()

    #expect(model.scanWorkspaceRoute == .results)
    #expect(model.cleanupResultState == .idle)
    #expect(model.reviewState == .idle)
}

@MainActor
@Test
func openTrashUsesTypedDependencyAndPreservesResultOnFailure()
    async throws
{
    let fixture = try CleanupResultTestSupport.fixture(.completed)
    let driver = CleanupResultDependencyDriver(openTrashResult: false)
    let state = CleanupResultReducer().receivedTerminal(
        fixture.executionState,
        itemFacts: fixture.retainedFacts,
        evidenceAvailability: .retained,
        state: .idle
    )
    let model = StornautAppModel(
        dependencies: driver.dependencies,
        initialScanWorkspaceRoute: .cleanupResult,
        initialCleanupResultState: state,
        refreshesServices: false
    )

    model.openTrashFromCleanupResult()
    await driver.waitForOpenTrash()
    await waitForCleanupResult {
        model.cleanupResultState.phase == .trashUnavailable
    }

    #expect(await driver.openTrashCount == 1)
    #expect(
        model.cleanupResultState.snapshot?.manifest.id
            == fixture.result.manifest.id
    )
}

@MainActor
@Test
func auditRetryCallsOnlyPersistenceAndKeepsExactManifestRows()
    async throws
{
    let pending = try CleanupResultTestSupport.fixture(.auditPending)
    let finalized = try CleanupResultTestSupport.fixture(.completed)
    let driver = CleanupResultDependencyDriver(
        auditRetryResult: finalized.executionState
    )
    let state = CleanupResultReducer().receivedTerminal(
        pending.executionState,
        itemFacts: pending.retainedFacts,
        evidenceAvailability: .retained,
        state: .idle
    )
    let model = StornautAppModel(
        dependencies: driver.dependencies,
        initialScanWorkspaceRoute: .cleanupResult,
        initialCleanupResultState: state,
        refreshesServices: false
    )

    model.retryCleanupResultAudit()
    await driver.waitForAuditRetry()
    await waitForCleanupResult {
        model.cleanupResultState.phase == .presented
    }

    #expect(await driver.auditRetryCount == 1)
    #expect(
        model.cleanupResultState.snapshot?.manifest.records
            == pending.result.manifest.records
    )
}

@Test
func productionDependenciesCannotEmitCleanupTerminal() {
    let dependencies = AppDependencies.production()

    #expect(
        dependencies.reviewExecutionAvailability == .writeDisabled
    )
}

@Test
func cleanupResultEnrichmentUsesRetainedScopeAfterSettingsRootChanges()
    async throws
{
    let storageRoot = FileManager.default.temporaryDirectory.appending(
        path: "stornaut-cleanup-enrichment-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    let retainedRoot = storageRoot.appending(
        path: "retained",
        directoryHint: .isDirectory
    )
    let changedRoot = storageRoot.appending(
        path: "changed",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: retainedRoot,
        withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
        at: changedRoot,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: storageRoot) }

    let configuration = try LocalStoreConfiguration(
        applicationSupportBaseURL: storageRoot.appending(
            path: "Application Support",
            directoryHint: .isDirectory
        ),
        cachesBaseURL: storageRoot.appending(
            path: "Caches",
            directoryHint: .isDirectory
        )
    )
    let fixture = try CleanupResultTestSupport.fixture(.completed)
    let plan = fixture.plan
    let scope = ScanScope(
        id: try #require(plan.scanScopeID),
        rootPath: try #require(
            PersistedPath(
                rawValue: retainedRoot.standardizedFileURL.path
            )
        ),
        completedAt: plan.createdAt
    )
    let session = try ScanSession(
        id: plan.scanSessionID,
        startedAt: plan.createdAt.addingTimeInterval(-1),
        finishedAt: plan.createdAt,
        terminalState: .completed,
        completedScopes: [scope],
        unfinishedScopes: []
    )
    let store = try EvidenceStore(configuration: configuration)
    try await store.saveScanSession(session)
    try await store.saveCleanupPlan(plan)
    try await SettingsPreferencesStore(
        configuration: configuration
    ).save(
        SettingsPreferences(
            primaryRoot: try SettingsPrimaryRoot.bookmark(
                for: changedRoot
            )
        )
    )
    let dependencies = AppDependencies.live(
        configuration: configuration,
        rootURL: changedRoot
    )

    let enrichment = await dependencies.cleanupResultEnrichment(
        fixture.result
    )

    #expect(enrichment.evidenceAvailability == .retained)
    #expect(
        enrichment.itemFacts.map(\.exactOriginalPath)
            == plan.items.map {
                retainedRoot.appending(
                    path: $0.expectedRelativePath!.rawValue,
                    directoryHint: .isDirectory
                ).path
            }
    )
    #expect(
        enrichment.itemFacts.allSatisfy {
            !$0.exactOriginalPath.hasPrefix(
                changedRoot.standardizedFileURL.path + "/"
            )
        }
    )
}

@MainActor
@Test
func acceptedTerminalReleasesExecutionEvenWhenProducerStaysOpen()
    async throws
{
    let review = try ReviewAppFixture()
    let snapshot = try ReviewSnapshot(
        plan: review.plan,
        projection: review.projection,
        generation: 1,
        executionAvailability: .debugFake
    )
    let selection = try #require(snapshot.reviewSelection)
    let fixture = try CleanupResultTestSupport.fixture(
        plan: review.plan,
        selection: selection,
        scenario: .completed
    )
    let evaluation = try ReviewConfirmationFixture.evaluate(
        plan: review.plan,
        selection: selection,
        activityFacts: .inactive
    )
    let stream = CleanupResultExecutionDriver()
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            preflightReview: { _, _ in evaluation },
            reviewExecutionAvailability: .debugFake,
            startReviewExecution: { _, _, _ in
                await stream.makeStream()
            },
            cleanupResultEnrichment: { _ in
                CleanupResultEnrichment(
                    itemFacts: fixture.retainedFacts,
                    evidenceAvailability: .retained
                )
            }
        ),
        initialScanWorkspaceRoute: .review,
        initialReviewState: .ready(snapshot),
        refreshesServices: false
    )

    model.preflightReview()
    await waitForCleanupResult {
        model.reviewState.phase == .confirming
    }
    model.confirmReviewExecution()
    await stream.waitUntilStarted()
    await stream.yield(.terminal(fixture.executionState))
    await waitForCleanupResult {
        model.scanWorkspaceRoute == .cleanupResult
    }

    model.doneCleanupResult()
    model.openReview()

    await waitForCleanupResult {
        model.scanWorkspaceRoute == .review
    }
}

@MainActor
@Test
func typedExpiredEnrichmentNeverExposesReturnedPathFacts()
    async throws
{
    let review = try ReviewAppFixture()
    let snapshot = try ReviewSnapshot(
        plan: review.plan,
        projection: review.projection,
        generation: 1,
        executionAvailability: .debugFake
    )
    let selection = try #require(snapshot.reviewSelection)
    let fixture = try CleanupResultTestSupport.fixture(
        plan: review.plan,
        selection: selection,
        scenario: .completed
    )
    let evaluation = try ReviewConfirmationFixture.evaluate(
        plan: review.plan,
        selection: selection,
        activityFacts: .inactive
    )
    let stream = CleanupResultExecutionDriver()
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            preflightReview: { _, _ in evaluation },
            reviewExecutionAvailability: .debugFake,
            startReviewExecution: { _, _, _ in
                await stream.makeStream()
            },
            cleanupResultEnrichment: { _ in
                CleanupResultEnrichment(
                    itemFacts: fixture.retainedFacts,
                    evidenceAvailability: .expired
                )
            }
        ),
        initialScanWorkspaceRoute: .review,
        initialReviewState: .ready(snapshot),
        refreshesServices: false
    )

    model.preflightReview()
    await waitForCleanupResult {
        model.reviewState.phase == .confirming
    }
    model.confirmReviewExecution()
    await stream.waitUntilStarted()
    await stream.yield(.terminal(fixture.executionState))
    await waitForCleanupResult {
        model.scanWorkspaceRoute == .cleanupResult
    }

    #expect(model.cleanupResultState.snapshot?.itemFacts.isEmpty == true)
    #expect(
        model.cleanupResultState.snapshot?.evidenceAvailability
            == .expired
    )
}

@MainActor
@Test
func terminalAdmissionRejectsJournalIdentityDriftFromPlan()
    async throws
{
    let review = try ReviewAppFixture()
    let snapshot = try ReviewSnapshot(
        plan: review.plan,
        projection: review.projection,
        generation: 1,
        executionAvailability: .debugFake
    )
    let selection = try #require(snapshot.reviewSelection)
    let fixture = try CleanupResultTestSupport.fixture(
        plan: review.plan,
        selection: selection,
        scenario: .completed
    )
    let evaluation = try ReviewConfirmationFixture.evaluate(
        plan: review.plan,
        selection: selection,
        activityFacts: .inactive
    )
    let firstEntry = fixture.result.journal.entries[0]
    let driftedIdentity = try FileIdentity(
        device: firstEntry.expectedIdentity.device,
        inode: firstEntry.expectedIdentity.inode + 1,
        mode: firstEntry.expectedIdentity.mode,
        ownerUserID: firstEntry.expectedIdentity.ownerUserID,
        ownerGroupID: firstEntry.expectedIdentity.ownerGroupID,
        size: firstEntry.expectedIdentity.size,
        allocatedBytes: firstEntry.expectedIdentity.allocatedBytes,
        modificationSeconds:
            firstEntry.expectedIdentity.modificationSeconds,
        modificationNanoseconds:
            firstEntry.expectedIdentity.modificationNanoseconds
    )
    let firstOutcome = try #require(firstEntry.outcome)
    let driftedOutcome = try CleanupJournalOutcome(
        result: firstOutcome.result,
        recovery: firstOutcome.recovery,
        measures: firstOutcome.measures,
        destinationIdentity: driftedIdentity,
        error: firstOutcome.error,
        finishedAt: firstOutcome.finishedAt
    )
    var entries = fixture.result.journal.entries
    entries[0] = try CleanupRunJournalEntry(
        actionID: firstEntry.actionID,
        planItemID: firstEntry.planItemID,
        policyDecisionID: firstEntry.policyDecisionID,
        policyDisposition: firstEntry.policyDisposition,
        policyReasonKeys: firstEntry.policyReasonKeys,
        action: firstEntry.action,
        expectedIdentity: driftedIdentity,
        actionFingerprint: firstEntry.actionFingerprint,
        state: firstEntry.state,
        startedAt: firstEntry.startedAt,
        outcome: driftedOutcome
    )
    let driftedJournal = try CleanupRunJournal(
        id: fixture.result.journal.id,
        planID: fixture.result.journal.planID,
        manifestID: fixture.result.journal.manifestID,
        selectionGeneration:
            fixture.result.journal.selectionGeneration,
        selectionFingerprint:
            fixture.result.journal.selectionFingerprint,
        stage: fixture.result.journal.stage,
        retentionClass: fixture.result.journal.retentionClass,
        stopAfterCurrentRequested:
            fixture.result.journal.stopAfterCurrentRequested,
        entries: entries,
        createdAt: fixture.result.journal.createdAt,
        updatedAt: fixture.result.journal.updatedAt,
        expiresAt: fixture.result.journal.expiresAt,
        manifestCreatedAt:
            fixture.result.journal.manifestCreatedAt,
        systemObservation:
            fixture.result.journal.systemObservation
    )
    let driftedResult = try CleanupExecutionResult(
        journal: driftedJournal,
        manifest: fixture.result.manifest
    )
    let stream = CleanupResultExecutionDriver()
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            preflightReview: { _, _ in evaluation },
            reviewExecutionAvailability: .debugFake,
            startReviewExecution: { _, _, _ in
                await stream.makeStream()
            }
        ),
        initialScanWorkspaceRoute: .review,
        initialReviewState: .ready(snapshot),
        refreshesServices: false
    )

    model.preflightReview()
    await waitForCleanupResult {
        model.reviewState.phase == .confirming
    }
    model.confirmReviewExecution()
    await stream.waitUntilStarted()
    await stream.yield(.terminal(.completed(driftedResult)))
    await stream.finish()
    await waitForCleanupResult {
        model.reviewState.phase == .executionBlocked
    }

    #expect(model.cleanupResultState == .idle)
    #expect(model.scanWorkspaceRoute == .review)
}

@MainActor
@Test
func terminalAdmissionAcceptsFreshPerItemPolicyDecisions()
    async throws
{
    let review = try ReviewAppFixture()
    let snapshot = try ReviewSnapshot(
        plan: review.plan,
        projection: review.projection,
        generation: 1,
        executionAvailability: .debugFake
    )
    let selection = try #require(snapshot.reviewSelection)
    let fixture = try CleanupResultTestSupport.fixture(
        plan: review.plan,
        selection: selection,
        scenario: .completed
    )
    let evaluation = try ReviewConfirmationFixture.evaluate(
        plan: review.plan,
        selection: selection,
        activityFacts: .inactive
    )
    let refreshed = try resultWithFreshPolicyBindings(fixture.result)
    let stream = CleanupResultExecutionDriver()
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            preflightReview: { _, _ in evaluation },
            reviewExecutionAvailability: .debugFake,
            startReviewExecution: { _, _, _ in
                await stream.makeStream()
            },
            cleanupResultEnrichment: { _ in
                CleanupResultEnrichment(
                    itemFacts: fixture.retainedFacts,
                    evidenceAvailability: .retained
                )
            }
        ),
        initialScanWorkspaceRoute: .review,
        initialReviewState: .ready(snapshot),
        refreshesServices: false
    )

    model.preflightReview()
    await waitForCleanupResult {
        model.reviewState.phase == .confirming
    }
    model.confirmReviewExecution()
    await stream.waitUntilStarted()
    await stream.yield(.terminal(.completed(refreshed)))
    await waitForCleanupResult {
        model.scanWorkspaceRoute == .cleanupResult
    }

    #expect(
        model.cleanupResultState.snapshot?.journal
            == refreshed.journal
    )
}

@MainActor
@Test
func stopWaitingReleasesANonTerminalExecutionStream() async throws {
    let review = try ReviewAppFixture()
    let snapshot = try ReviewSnapshot(
        plan: review.plan,
        projection: review.projection,
        generation: 1,
        executionAvailability: .debugFake
    )
    let evaluation = try ReviewConfirmationFixture.evaluate(
        plan: review.plan,
        selection: #require(snapshot.reviewSelection),
        activityFacts: .inactive
    )
    let stream = CleanupResultExecutionDriver()
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            preflightReview: { _, _ in evaluation },
            reviewExecutionAvailability: .debugFake,
            startReviewExecution: { _, _, _ in
                await stream.makeStream()
            }
        ),
        initialScanWorkspaceRoute: .review,
        initialReviewState: .ready(snapshot),
        refreshesServices: false
    )

    model.preflightReview()
    await waitForCleanupResult {
        model.reviewState.phase == .confirming
    }
    model.confirmReviewExecution()
    await stream.waitUntilStarted()
    await stream.yield(.progress(.queued(total: 1)))
    model.stopReviewAfterCurrent()
    model.cancelReviewExecutionWait()

    #expect(model.reviewState.phase == .executionBlocked)
    model.closeReview()
    #expect(model.scanWorkspaceRoute == .results)
}

@MainActor
@Test
func openingANewReviewClearsUnavailableCleanupAdmissionState() throws {
    let model = StornautAppModel(
        dependencies: AppDependencies(loadLatestQuickScan: { nil }),
        initialCleanupResultState: .unavailable(
            DomainToken(rawValue: "cleanup.result.invalid-terminal")!
        ),
        refreshesServices: false
    )

    model.openReview()

    #expect(model.cleanupResultState == .idle)
}

private actor CleanupResultExecutionDriver {
    typealias Stream = AsyncStream<ReviewExecutionEvent>

    private var continuation: Stream.Continuation?
    private var started = false

    func makeStream() -> Stream {
        Stream { continuation in
            self.continuation = continuation
            started = true
        }
    }

    func waitUntilStarted() async {
        while !started {
            await Task.yield()
        }
    }

    func yield(_ event: ReviewExecutionEvent) {
        continuation?.yield(event)
    }

    func finish() {
        continuation?.finish()
    }
}

private func resultWithFreshPolicyBindings(
    _ result: CleanupExecutionResult
) throws -> CleanupExecutionResult {
    let records = try result.manifest.records.enumerated().map {
        index, record in
        try CleanupManifestRecord(
            actionID: record.actionID,
            planItemID: record.planItemID,
            policyDecisionID: PolicyDecisionID(
                rawValue: "decision-fresh-\(index)"
            )!,
            policyDisposition: record.policyDisposition,
            policyReasonKeys: [
                DomainToken(rawValue: "policy.item.allowed")!,
            ],
            action: record.action,
            result: record.result,
            recovery: record.recovery,
            measures: record.measures,
            startedAt: record.startedAt,
            finishedAt: record.finishedAt,
            error: record.error
        )
    }
    let manifest = try CleanupManifest(
        id: result.manifest.id,
        planID: result.manifest.planID,
        createdAt: result.manifest.createdAt,
        expiresAt: result.manifest.expiresAt,
        records: records,
        summary: CleanupManifestSummary(records: records),
        systemObservation: result.manifest.systemObservation
    )
    let entries = try zip(
        result.journal.entries,
        records
    ).enumerated().map { index, pair in
        let (entry, record) = pair
        return try CleanupRunJournalEntry(
            actionID: entry.actionID,
            planItemID: entry.planItemID,
            policyDecisionID: record.policyDecisionID!,
            policyDisposition: record.policyDisposition,
            policyReasonKeys: record.policyReasonKeys,
            action: entry.action,
            expectedIdentity: entry.expectedIdentity,
            actionFingerprint: DomainToken(
                rawValue: "action.fresh-\(index)"
            )!,
            state: entry.state,
            startedAt: entry.startedAt,
            outcome: entry.outcome
        )
    }
    let journal = try CleanupRunJournal(
        id: result.journal.id,
        planID: result.journal.planID,
        manifestID: result.journal.manifestID,
        selectionGeneration: result.journal.selectionGeneration,
        selectionFingerprint: result.journal.selectionFingerprint,
        stage: result.journal.stage,
        retentionClass: result.journal.retentionClass,
        stopAfterCurrentRequested:
            result.journal.stopAfterCurrentRequested,
        entries: entries,
        createdAt: result.journal.createdAt,
        updatedAt: result.journal.updatedAt,
        expiresAt: result.journal.expiresAt,
        manifestCreatedAt: result.journal.manifestCreatedAt,
        systemObservation: result.journal.systemObservation
    )
    return try CleanupExecutionResult(
        journal: journal,
        manifest: manifest
    )
}

private struct CleanupResultDependencyDriver {
    let dependencies: AppDependencies
    private let storage: CleanupResultDependencyStorage

    init(
        openTrashResult: Bool = true,
        auditRetryResult: CleanupExecutionState? = nil
    ) {
        let storage = CleanupResultDependencyStorage(
            openTrashResult: openTrashResult,
            auditRetryResult: auditRetryResult
        )
        self.storage = storage
        dependencies = AppDependencies(
            loadLatestQuickScan: { nil },
            openTrash: {
                await storage.openTrash()
            },
            retryCleanupAudit: {
                await storage.retryAudit($0)
            }
        )
    }

    var openTrashCount: Int {
        get async { await storage.openTrashCount }
    }

    var auditRetryCount: Int {
        get async { await storage.auditRetryCount }
    }

    func waitForOpenTrash() async {
        while await storage.openTrashCount == 0 {
            await Task.yield()
        }
    }

    func waitForAuditRetry() async {
        while await storage.auditRetryCount == 0 {
            await Task.yield()
        }
    }
}

private actor CleanupResultDependencyStorage {
    private let openTrashResult: Bool
    private let auditRetryResult: CleanupExecutionState?
    private(set) var openTrashCount = 0
    private(set) var auditRetryCount = 0

    init(
        openTrashResult: Bool,
        auditRetryResult: CleanupExecutionState?
    ) {
        self.openTrashResult = openTrashResult
        self.auditRetryResult = auditRetryResult
    }

    func openTrash() -> Bool {
        openTrashCount += 1
        return openTrashResult
    }

    func retryAudit(
        _ result: CleanupExecutionResult
    ) -> CleanupExecutionState? {
        _ = result
        auditRetryCount += 1
        return auditRetryResult
    }
}

@MainActor
private func waitForCleanupResult(
    _ condition: () -> Bool
) async {
    for _ in 0..<1_000 {
        if condition() {
            return
        }
        await Task.yield()
    }
}
