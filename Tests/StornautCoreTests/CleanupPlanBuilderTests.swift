import CryptoKit
import Foundation
import Testing
@testable import StornautCore

@Test
func cleanupPlanBuilderInvestigationModeDoesNotPersistBeforeJoin() async throws {
    let fixture = try CleanupPlanBuilderFixture(paths: [
        ".npm/_cacache",
        "Library/Caches/pip",
    ])
    defer { fixture.remove() }
    let store = try EvidenceStore(configuration: .memory)
    let scan = try await fixture.scan(store: store)
    let builder = try fixture.builder(
        store: store,
        activitySource: CleanupPlanBuilderActivitySource(
            snapshot: fixture.activitySnapshot(processes: [])
        ),
        identitySlug: "investigation-first"
    )
    let page = try await store.cleanupPlanningPage(
        sessionID: scan.sessionID, after: nil, limit: 100
    )
    let record = try #require(page.records.first {
        $0.snapshot.relativePath == ".npm/_cacache"
    })
    let result = try #require(
        await builder.buildForInvestigation(
            sessionID: scan.sessionID,
            targetBindings: [
                InvestigationReportTargetBinding(
                    try InvestigationTarget(
                        scanSessionID: scan.sessionID,
                        scanScopeID: scan.scopeID,
                        sourceBinding: .classification(
                            classificationID: record.classification.id,
                            snapshotID: record.snapshot.id
                        ),
                        kind: .unknownLargeConsumer,
                        reasonKeys: [DomainToken(rawValue: "reason.unknown")!],
                        expectedAllocatedBytes:
                            record.snapshot.allocatedByteCount,
                        uncertaintyPermille: 900, relevancePermille: 900,
                        investigationCostPermille: 250,
                        createdAt: fixture.observedAt
                    )
                ),
            ]
        ).planReady
    )
    #expect(try await store.cleanupPlans(
        sessionID: scan.sessionID, limit: 100, offset: 0
    ).records.isEmpty)
    #expect(result.0.items.count == 1)
    #expect(result.0.items[0].snapshotID == record.snapshot.id)
    #expect(result.1.rows.count == 1)
    #expect(result.1.totalRowCount == 1)
}

private func investigationJoinPlan(
    fixture: InvestigationStoreV4Fixture,
    suffix: String
) throws -> CleanupPlan {
    let identity = fixture.snapshots[1].fileIdentity!
    let item = try CleanupPlanItem(
        id: CleanupPlanItemID(
            rawValue: "plan-item-investigation-join-\(suffix)"
        )!,
        snapshotID: fixture.classification.snapshotID,
        classificationID: fixture.classification.id,
        ruleID: DomainToken(rawValue: "rule.investigation.join")!,
        executionProfileID: DomainToken(
            rawValue: "profile.investigation.join"
        )!,
        proposedAction: .moveToTrash,
        expectedRelativePath: PersistedPath(
            rawValue: fixture.snapshots[1].relativePath
        )!,
        expectedIdentity: identity,
        logicalBytes: fixture.snapshots[1].logicalByteCount!,
        allocatedBytes: fixture.snapshots[1].allocatedByteCount!,
        evidenceFingerprint: DomainToken(
            rawValue: "evidence.investigation.join"
        )!,
        activityFingerprint: DomainToken(
            rawValue: "activity.investigation.join"
        )!
    )
    return try CleanupPlan(
        id: CleanupPlanID(rawValue: "plan-investigation-join-\(suffix)")!,
        scanSessionID: fixture.session.id,
        scanScopeID: fixture.scopeID,
        primaryRootIdentity: fixture.snapshots[0].fileIdentity!,
        catalogVersion: fixture.classification.catalogVersion,
        executionProfileVersion: DomainToken(
            rawValue: "profile-catalog.investigation.join"
        )!,
        planFingerprint: DomainToken(
            rawValue: "plan-fingerprint.investigation.join.\(suffix)"
        )!,
        createdAt: fixture.planningAt,
        expiresAt: fixture.planningAt.addingTimeInterval(300),
        items: [item]
    )
}

private final class CleanupPlanBuilderJoinClock: @unchecked Sendable {
    let now: Date

    init(now: Date) { self.now = now }
}

private final class CleanupPlanJoinCancellationControl: @unchecked Sendable {
    private let lock = NSLock()
    private var armed = false
    private var cancelled = false

    var isCancelled: Bool { lock.withLock { cancelled } }

    func arm() {
        lock.withLock { armed = true }
    }

    func observe(_ progress: InvestigationStoreProgress) {
        lock.withLock {
            if armed && progress.phase == .verification { cancelled = true }
        }
    }

    func reset() {
        lock.withLock {
            armed = false
            cancelled = false
        }
    }
}

private func persistCleanupPlanJoinParent(
    store: EvidenceStore,
    investigationID: InvestigationID,
    runID: InvestigationRunID,
    plan _: CleanupPlan?
) async throws -> InvestigationReportID {
    let session = try #require(try await store.investigation(id: investigationID))
    _ = try await store.transitionInvestigationRun(
        InvestigationRunTransitionCommand(
            investigationID: investigationID, runID: runID,
            expectedRunState: .planned, runState: .ready,
            sessionState: .ready, stage: .prioritize,
            updatedAt: session.createdAt.addingTimeInterval(1)
        )
    )
    _ = try await store.transitionInvestigationRun(
        InvestigationRunTransitionCommand(
            investigationID: investigationID, runID: runID,
            expectedRunState: .ready, runState: .running,
            sessionState: .running, stage: .identify,
            updatedAt: session.createdAt.addingTimeInterval(2)
        )
    )
    _ = try await store.transitionInvestigationRun(
        InvestigationRunTransitionCommand(
            investigationID: investigationID, runID: runID,
            expectedRunState: .running, runState: .terminalBarrier,
            sessionState: .terminalBarrier, stage: .verify,
            terminalCause: .paused,
            updatedAt: session.createdAt.addingTimeInterval(3)
        )
    )
    let reportID = InvestigationReportID(
        rawValue: "investigation-report-review-atomic-join"
    )!
    let unresolved = try session.plan.targets.enumerated().map { index, target in
        InvestigationEvidenceInput(
            id: InvestigationEvidenceID(
                rawValue: "investigation-evidence-review-atomic-\(index)"
            )!,
            targetID: target.id, kind: .unresolved,
            payload: try InvestigationEvidencePayload(
                summary: "Unresolved target",
                advisoryID: DomainToken(rawValue: target.id.rawValue),
                sourceLabel: DomainToken(rawValue: "source.unresolved"),
                confidence: DomainToken(rawValue: "confidence.low")!,
                uncertainty: "Further investigation is required"
            )
        )
    }
    _ = try await store.commitInvestigationTerminal(
        try InvestigationTerminalCommand(
            investigationID: investigationID, runID: runID,
            runState: .partial, sessionState: .partial, stage: .buildPlan,
            cause: .paused,
            report: InvestigationTerminalReportInput(
                id: reportID, kind: .partial,
                payload: try InvestigationReportPayload(
                    summary: "Partial report for cleanup join"
                ),
                evidence: unresolved, degradations: []
            ),
            budgetEvents: [
                InvestigationBudgetEventInput(
                    id: InvestigationBudgetEventID(
                        rawValue: "investigation-budget-event-review-atomic"
                    )!, ordinal: 0, kind: .terminalSummary,
                    payload: InvestigationBudgetEventPayload()
                ),
            ],
            terminalAt: session.createdAt.addingTimeInterval(4)
        )
    )
    return reportID
}

@Test
func investigationCleanupPlanJoinIsAtomicAcrossSourceRevalidation() async throws {
    let fixture = try InvestigationStoreV4Fixture()
    let clock = CleanupPlanBuilderJoinClock(now: fixture.planningAt)
    let store = try EvidenceStore(
        configuration: .memory,
        testHooks: EvidenceStoreTestHooks(now: { clock.now })
    )
    try await fixture.seed(store)
    let investigationID = InvestigationID(
        rawValue: "investigation-review-atomic-join"
    )!
    _ = try await store.createInvestigation(
        fixture.command(
            investigationID: investigationID.rawValue,
            runID: "investigation-run-review-atomic-join"
        )
    )
    let first = try investigationJoinPlan(fixture: fixture, suffix: "first")
    let reportID = try await persistCleanupPlanJoinParent(
        store: store,
        investigationID: investigationID,
        runID: InvestigationRunID(
            rawValue: "investigation-run-review-atomic-join"
        )!,
        plan: nil
    )
    #expect(try await store.commitCleanupPlanForInvestigation(
        investigationID: investigationID,
        runID: InvestigationRunID(
            rawValue: "investigation-run-review-atomic-join"
        )!,
        reportID: reportID,
        plan: first
    ) == .matching)
    #expect(try await store.cleanupPlan(id: first.id) == first)

    let original = fixture.classification
    let changed = try Classification(
        id: original.id, snapshotID: original.snapshotID,
        ruleID: original.ruleID, producer: original.producer,
        category: original.category, disposition: original.disposition,
        risk: original.risk, confidence: original.confidence,
        recovery: original.recovery,
        requiredEvidenceKeys: original.requiredEvidenceKeys,
        missingEvidenceKeys: original.missingEvidenceKeys,
        catalogVersion: DomainToken(rawValue: "catalog-source-drift")!,
        classifiedAt: original.classifiedAt
    )
    try await store._testReplaceClassificationPayload(
        id: original.id,
        payload: String(decoding: try DomainJSON.encode(changed), as: UTF8.self)
    )

    let second = try investigationJoinPlan(fixture: fixture, suffix: "second")
    #expect(try await store.commitCleanupPlanForInvestigation(
        investigationID: investigationID,
        runID: InvestigationRunID(
            rawValue: "investigation-run-review-atomic-join"
        )!,
        reportID: reportID,
        plan: second
    ) == .stale)
    #expect(try await store.cleanupPlan(id: second.id) == nil)
}

@Test
func investigationCleanupPlanJoinCancellationRollsBackInsertedPlan_BitsUT() async throws {
    let fixture = try InvestigationStoreV4Fixture()
    let cancellation = CleanupPlanJoinCancellationControl()
    let store = try EvidenceStore(
        configuration: .memory,
        testHooks: EvidenceStoreTestHooks(
            isCancelled: { cancellation.isCancelled },
            investigationProgress: { cancellation.observe($0) }
        )
    )
    try await fixture.seed(store)
    let investigationID = InvestigationID(
        rawValue: "investigation-review-cancelled-join"
    )!
    let runID = InvestigationRunID(
        rawValue: "investigation-run-review-cancelled-join"
    )!
    _ = try await store.createInvestigation(
        fixture.command(
            investigationID: investigationID.rawValue, runID: runID.rawValue
        )
    )
    let reportID = try await persistCleanupPlanJoinParent(
        store: store, investigationID: investigationID, runID: runID, plan: nil
    )
    let plan = try investigationJoinPlan(fixture: fixture, suffix: "cancelled")
    cancellation.arm()

    await #expect(throws: EvidenceStoreError.operationCancelled) {
        _ = try await store.commitCleanupPlanForInvestigation(
            investigationID: investigationID, runID: runID,
            reportID: reportID, plan: plan
        )
    }
    cancellation.reset()
    #expect(try await store.cleanupPlan(id: plan.id) == nil)
    #expect(await store.storeHealth() == .ready)
}

@Test
func investigationCleanupPlanJoinRejectsItemOutsideRetainedTargets_BitsUT() async throws {
    let fixture = try InvestigationStoreV4Fixture()
    let store = try EvidenceStore(configuration: .memory)
    try await fixture.seed(store)
    let investigationID = InvestigationID(
        rawValue: "investigation-review-foreign-item"
    )!
    let runID = InvestigationRunID(
        rawValue: "investigation-run-review-foreign-item"
    )!
    _ = try await store.createInvestigation(
        fixture.command(
            investigationID: investigationID.rawValue, runID: runID.rawValue
        )
    )
    let reportID = try await persistCleanupPlanJoinParent(
        store: store, investigationID: investigationID, runID: runID, plan: nil
    )
    let original = try investigationJoinPlan(fixture: fixture, suffix: "foreign")
    let foreignItem = try CleanupPlanItem(
        id: CleanupPlanItemID(rawValue: "plan-item-investigation-foreign")!,
        snapshotID: SnapshotID(rawValue: "snapshot-not-investigated")!,
        classificationID: ClassificationID(
            rawValue: "classification-not-investigated"
        )!,
        ruleID: original.items[0].ruleID!,
        executionProfileID: original.items[0].executionProfileID!,
        proposedAction: .moveToTrash,
        expectedRelativePath: original.items[0].expectedRelativePath!,
        expectedIdentity: original.items[0].expectedIdentity!,
        logicalBytes: original.items[0].logicalBytes!,
        allocatedBytes: original.items[0].allocatedBytes!,
        evidenceFingerprint: original.items[0].evidenceFingerprint!,
        activityFingerprint: original.items[0].activityFingerprint!
    )
    let foreignPlan = try CleanupPlan(
        id: original.id, scanSessionID: original.scanSessionID,
        scanScopeID: original.scanScopeID!,
        primaryRootIdentity: original.primaryRootIdentity!,
        catalogVersion: original.catalogVersion!,
        executionProfileVersion: original.executionProfileVersion!,
        planFingerprint: original.planFingerprint!,
        createdAt: original.createdAt, expiresAt: original.expiresAt,
        items: [foreignItem]
    )

    await #expect(throws: InvestigationPersistenceError.invalidCommand) {
        _ = try await store.commitCleanupPlanForInvestigation(
            investigationID: investigationID, runID: runID,
            reportID: reportID, plan: foreignPlan
        )
    }
    #expect(try await store.cleanupPlan(id: foreignPlan.id) == nil)
}

@Test(arguments: [true, false])
func investigationCleanupPlanJoinRejectsForeignRunOrReport_BitsUT(
    mutateRun: Bool
) async throws {
    let fixture = try InvestigationStoreV4Fixture()
    let store = try EvidenceStore(configuration: .memory)
    try await fixture.seed(store)
    let investigationID = InvestigationID(
        rawValue: "investigation-review-foreign-lineage"
    )!
    let runID = InvestigationRunID(
        rawValue: "investigation-run-review-foreign-lineage"
    )!
    _ = try await store.createInvestigation(
        fixture.command(
            investigationID: investigationID.rawValue, runID: runID.rawValue
        )
    )
    let reportID = try await persistCleanupPlanJoinParent(
        store: store, investigationID: investigationID, runID: runID, plan: nil
    )
    let plan = try investigationJoinPlan(fixture: fixture, suffix: "lineage")
    let requestedRunID = mutateRun
        ? InvestigationRunID(rawValue: "investigation-run-review-foreign")!
        : runID
    let requestedReportID = mutateRun
        ? reportID
        : InvestigationReportID(rawValue: "investigation-report-review-foreign")!

    await #expect(throws: InvestigationPersistenceError.invalidCommand) {
        _ = try await store.commitCleanupPlanForInvestigation(
            investigationID: investigationID, runID: requestedRunID,
            reportID: requestedReportID, plan: plan
        )
    }
    #expect(try await store.cleanupPlan(id: plan.id) == nil)
}

@Test
func cleanupPlanBuilderJoinsCompleteTruthAndSuggestsOnlyReadyProfiles()
    async throws
{
    let fixture = try CleanupPlanBuilderFixture(
        paths: [
            ".npm/_cacache",
            "Library/Caches/pip",
            "Library/Caches/go-build",
            ".cache/uv",
        ]
    )
    defer { fixture.remove() }
    let store = try EvidenceStore(configuration: .memory)
    let scan = try await fixture.scan(store: store)
    let persistedSession = try #require(
        try await store.scanSession(id: scan.sessionID)
    )
    let persistedEvidence = try await store.evidence(
        sessionID: scan.sessionID,
        limit: 100,
        offset: 0
    ).records
    #expect(persistedEvidence.allSatisfy {
        $0.observedAt >= persistedSession.startedAt
    })
    let buildActivity = CleanupPlanBuilderActivitySource(
        snapshot: fixture.activitySnapshot(processes: [])
    )
    let builder = try fixture.builder(
        store: store,
        activitySource: buildActivity
    )

    let outcome = await builder.build(
        sessionID: scan.sessionID,
        rootURL: fixture.rootURL
    )
    let (plan, projection) = try #require(outcome.planReady)

    #expect(await buildActivity.callCount == 1)
    #expect(plan.catalogVersion?.rawValue
        == "builtin-runtime-tool-residue-v2")
    #expect(plan.executionProfileVersion?.rawValue
        == "safe-execution-v1")
    #expect(plan.items.map(\.expectedRelativePath?.rawValue) == [
        ".npm/_cacache",
        "Library/Caches/go-build",
        "Library/Caches/pip",
    ])
    #expect(plan.items.allSatisfy {
        $0.proposedAction == .moveToTrash
    })
    #expect(projection.rows.filter(\.suggestedDefault).map(\.relativePath) == [
        ".npm/_cacache",
        "Library/Caches/pip",
    ])
    #expect(projection.counts.executableReady == 2)
    #expect(projection.counts.executableReview == 1)
    #expect(projection.counts.noExecutionProfile >= 1)
    #expect(
        projection.rows.first {
            $0.relativePath == "Library/Caches/go-build"
        }?.suggestedDefault == false
    )
    #expect(
        projection.rows.first {
            $0.relativePath == ".cache/uv"
        }?.eligibility == .noExecutionProfile
    )
    #expect(
        try await store.cleanupPlan(id: plan.id) == plan
    )
}

@Test
func cleanupPlanBuilderDowngradesCurrentActivityWithoutPromotingTruth()
    async throws
{
    let fixture = try CleanupPlanBuilderFixture(
        paths: [
            ".npm/_cacache",
            "Library/Caches/pip",
            "Library/Caches/go-build",
        ]
    )
    defer { fixture.remove() }
    let store = try EvidenceStore(configuration: .memory)
    let scan = try await fixture.scan(store: store)
    let buildActivity = CleanupPlanBuilderActivitySource(
        snapshot: fixture.activitySnapshot(
            processes: ["node"]
        )
    )
    let builder = try fixture.builder(
        store: store,
        activitySource: buildActivity
    )

    let outcome = await builder.build(
        sessionID: scan.sessionID,
        rootURL: fixture.rootURL
    )
    let (plan, projection) = try #require(outcome.planReady)

    #expect(await buildActivity.callCount == 1)
    #expect(plan.items.map(\.expectedRelativePath?.rawValue) == [
        "Library/Caches/go-build",
        "Library/Caches/pip",
    ])
    let npm = try #require(
        projection.rows.first {
            $0.relativePath == ".npm/_cacache"
        }
    )
    #expect(npm.persistedDisposition == .readyToReclaim)
    #expect(npm.currentDisposition == .protected)
    #expect(npm.eligibility == .currentEvidenceBlocked)
    #expect(!npm.suggestedDefault)
}

@Test
func cleanupPlanBuilderRequiresCurrentCatalogAndNeverRewritesOldTruth()
    async throws
{
    let fixture = try CleanupPlanBuilderFixture(
        paths: [".npm/_cacache"]
    )
    defer { fixture.remove() }
    let store = try EvidenceStore(configuration: .memory)
    let currentCatalog = try BuiltInRuleCatalog.load()
    let oldCatalog = try RuleCatalog(
        catalogVersion: DomainToken(
            rawValue: "builtin-runtime-tool-residue-v1"
        )!,
        rules: currentCatalog.rules
    )
    let scan = try await fixture.scan(
        store: store,
        catalog: oldCatalog,
        profileCatalog: nil
    )
    let builder = try fixture.builder(
        store: store,
        activitySource: CleanupPlanBuilderActivitySource(
            snapshot: fixture.activitySnapshot(processes: [])
        )
    )

    let outcome = await builder.build(
        sessionID: scan.sessionID,
        rootURL: fixture.rootURL
    )

    #expect(outcome.scanAgainReasons.map(\.rawValue) == [
        "review.scan-again.catalog-changed",
    ])
    let persisted = try await store.classifications(
        sessionID: scan.sessionID,
        limit: 100,
        offset: 0
    ).records
    #expect(persisted.allSatisfy {
        $0.catalogVersion == oldCatalog.catalogVersion
    })
    #expect(
        try await store.cleanupPlans(
            sessionID: scan.sessionID,
            limit: 100,
            offset: 0
        ).records.isEmpty
    )
}

@Test
func cleanupPlanBuilderReturnsEmptyProjectionWithoutPersistingEmptyPlan()
    async throws
{
    let fixture = try CleanupPlanBuilderFixture(paths: [".cache/uv"])
    defer { fixture.remove() }
    let store = try EvidenceStore(configuration: .memory)
    let scan = try await fixture.scan(store: store)
    let builder = try fixture.builder(
        store: store,
        activitySource: CleanupPlanBuilderActivitySource(
            snapshot: fixture.activitySnapshot(processes: [])
        )
    )

    let outcome = await builder.build(
        sessionID: scan.sessionID,
        rootURL: fixture.rootURL
    )
    let projection = try #require(outcome.emptyProjection)

    #expect(projection.executableCount == 0)
    #expect(projection.counts.noExecutionProfile == 1)
    #expect(
        projection.rows.first {
            $0.relativePath == ".cache/uv"
        }?.eligibility == .noExecutionProfile
    )
    #expect(
        try await store.cleanupPlans(
            sessionID: scan.sessionID,
            limit: 100,
            offset: 0
        ).records.isEmpty
    )
}

@Test
func cleanupPlanBuilderRejectsPersistedExecutionEvidenceStateDrift()
    async throws
{
    let fixture = try CleanupPlanBuilderFixture(
        paths: [".npm/_cacache"]
    )
    defer { fixture.remove() }
    let store = try EvidenceStore(configuration: .memory)
    let scan = try await fixture.scan(store: store)
    let page = try await store.evidence(
        sessionID: scan.sessionID,
        limit: 100,
        offset: 0
    )
    let original = try #require(
        page.records.first {
            $0.source.identifier.rawValue
                == "execution.ah.nopii.compilerAttested.evidence.cache.layout"
        }
    )
    try await store.saveEvidence([
        EvidenceRecord(
            id: original.id,
            targetID: original.targetID,
            kind: original.kind,
            source: original.source,
            summaryKey: DomainToken(
                rawValue:
                    "execution.evidence.cache.layout.unavailable"
            )!,
            observedAt: original.observedAt,
            freshness: .current
        ),
    ])
    let builder = try fixture.builder(
        store: store,
        activitySource: CleanupPlanBuilderActivitySource(
            snapshot: fixture.activitySnapshot(processes: [])
        )
    )

    let outcome = await builder.build(
        sessionID: scan.sessionID,
        rootURL: fixture.rootURL
    )
    let projection = try #require(outcome.emptyProjection)

    #expect(projection.executableCount == 0)
    #expect(projection.counts.currentEvidenceBlocked == 1)
    #expect(
        projection.rows.first {
            $0.relativePath == ".npm/_cacache"
        }?.eligibility == .currentEvidenceBlocked
    )
    #expect(
        try await store.cleanupPlans(
            sessionID: scan.sessionID,
            limit: 100,
            offset: 0
        ).records.isEmpty
    )
}

@Test
func cleanupPlanBuilderStreamsFourThousandRowsAndRetainsLateProfiles()
    async throws
{
    let fixture = try CleanupPlanBuilderFixture(
        paths: [
            ".npm/_cacache",
            "Library/Caches/pip",
            "Library/Caches/go-build",
        ]
    )
    defer { fixture.remove() }
    let store = try EvidenceStore(configuration: .memory)
    let sessionID = try await seedLargeCleanupPlanningStore(
        store: store,
        fixture: fixture,
        fallbackCount: 4_096
    )
    let activity = CleanupPlanBuilderActivitySource(
        snapshot: fixture.activitySnapshot(processes: [])
    )
    let builder = try fixture.builder(
        store: store,
        activitySource: activity
    )

    let start = ContinuousClock.now
    let outcome = await builder.build(
        sessionID: sessionID,
        rootURL: fixture.rootURL
    )
    let elapsed = start.duration(to: .now)
    let (plan, projection) = try #require(outcome.planReady)

    #expect(await activity.callCount == 1)
    #expect(plan.items.count == 3)
    #expect(projection.totalRowCount == 4_099)
    #expect(projection.rows.count == ReviewProjection.maximumRows)
    #expect(
        Set(projection.rows.compactMap(\.ruleID?.rawValue)).isSuperset(
            of: [
                "cache-go-build",
                "cache-npm-content",
                "cache-pip",
            ]
        )
    )
    #expect(elapsed < .seconds(2))
}

@Test
func cleanupPlanFingerprintIgnoresRandomPlanAndItemIdentifiers()
    async throws
{
    let fixture = try CleanupPlanBuilderFixture(
        paths: [
            ".npm/_cacache",
            "Library/Caches/pip",
        ]
    )
    defer { fixture.remove() }
    let store = try EvidenceStore(configuration: .memory)
    let scan = try await fixture.scan(store: store)
    let first = try fixture.builder(
        store: store,
        activitySource: CleanupPlanBuilderActivitySource(
            snapshot: fixture.activitySnapshot(processes: [])
        ),
        identitySlug: "first"
    )
    let second = try fixture.builder(
        store: store,
        activitySource: CleanupPlanBuilderActivitySource(
            snapshot: fixture.activitySnapshot(processes: [])
        ),
        identitySlug: "second"
    )

    let firstOutcome = await first.build(
        sessionID: scan.sessionID,
        rootURL: fixture.rootURL
    )
    let secondOutcome = await second.build(
        sessionID: scan.sessionID,
        rootURL: fixture.rootURL
    )
    let firstPlan = try #require(firstOutcome.planReady?.0)
    let secondPlan = try #require(secondOutcome.planReady?.0)

    #expect(firstPlan.id != secondPlan.id)
    #expect(firstPlan.items.map(\.id) != secondPlan.items.map(\.id))
    #expect(firstPlan.planFingerprint == secondPlan.planFingerprint)
}

@Test(
    arguments: [
        ("first", 0),
        ("middle", 2_049),
        ("last", 4_098),
    ]
)
func cleanupPlanBuilderRejectsCorruptJoinedRowsOnEveryPage(
    label: String,
    index: Int
) async throws {
    let fixture = try CleanupPlanBuilderFixture(
        paths: [
            ".npm/_cacache",
            "Library/Caches/pip",
            "Library/Caches/go-build",
        ]
    )
    defer { fixture.remove() }
    let store = try EvidenceStore(configuration: .memory)
    let sessionID = try await seedLargeCleanupPlanningStore(
        store: store,
        fixture: fixture,
        fallbackCount: 4_096
    )
    let classification = try await cleanupPlanningClassification(
        store: store,
        sessionID: sessionID,
        index: index
    )
    try await store._testReplaceClassificationPayload(
        id: classification.id,
        payload: "{"
    )
    let builder = try fixture.builder(
        store: store,
        activitySource: CleanupPlanBuilderActivitySource(
            snapshot: fixture.activitySnapshot(processes: [])
        ),
        identitySlug: label
    )

    let outcome = await builder.build(
        sessionID: sessionID,
        rootURL: fixture.rootURL
    )

    #expect(outcome.scanAgainReasons.map(\.rawValue) == [
        "review.scan-again.corrupt-truth",
    ])
    #expect(
        try await store.cleanupPlans(
            sessionID: sessionID,
            limit: 100,
            offset: 0
        ).records.isEmpty
    )
}

private func cleanupPlanningClassification(
    store: EvidenceStore,
    sessionID: ScanSessionID,
    index: Int
) async throws -> Classification {
    var cursor: CleanupPlanningCursor?
    var remaining = index
    while true {
        let page = try await store.cleanupPlanningPage(
            sessionID: sessionID,
            after: cursor,
            limit: 100
        )
        if remaining < page.records.count {
            return page.records[remaining].classification
        }
        remaining -= page.records.count
        guard let next = page.nextCursor,
              next != cursor,
              page.rowCount == 100
        else {
            throw DomainContractError.invalidMeasurement
        }
        cursor = next
    }
}

private final class CleanupPlanBuilderFixture: @unchecked Sendable {
    let rootURL: URL
    let observedAt = Date(timeIntervalSince1970: 1_786_651_000)
    private let paths: [String]

    init(paths: [String]) throws {
        self.paths = paths
        rootURL = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-plan-builder-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: false
        )
        for path in paths {
            try FileManager.default.createDirectory(
                at: rootURL.appending(
                    path: path,
                    directoryHint: .isDirectory
                ),
                withIntermediateDirectories: true
            )
        }
    }

    func scan(
        store: EvidenceStore,
        catalog: RuleCatalog? = nil,
        profileCatalog: ExecutionProfileCatalog? = nil
    ) async throws -> (
        sessionID: ScanSessionID,
        scopeID: ScanScopeID
    ) {
        let rules = try catalog ?? BuiltInRuleCatalog.load()
        let usesExecutionProfiles =
            rules.catalogVersion.rawValue
                == "builtin-runtime-tool-residue-v2"
        let profiles: ExecutionProfileCatalog?
        if let profileCatalog {
            profiles = profileCatalog
        } else if usesExecutionProfiles {
            profiles = try BuiltInExecutionProfileCatalog.load(
                ruleCatalog: rules
            )
        } else {
            profiles = nil
        }
        let activity = CleanupPlanBuilderActivitySource(
            snapshot: activitySnapshot(processes: [])
        )
        let coordinator = QuickScanCoordinator(
            store: store,
            catalog: rules,
            activityProvider: CleanupPlanBuilderGenericActivityProvider(),
            executionProfileCatalog: profiles,
            executableEvidenceResolver: profiles == nil
                ? nil
                : ExecutableEvidenceResolver(
                    activityProvider: RunningActivityProvider(
                        source: activity
                    )
                ),
            now: { self.observedAt },
            snapshotID: cleanupPlanBuilderSnapshotID,
            classificationID: cleanupPlanBuilderClassificationID,
            evidenceID: cleanupPlanBuilderActivityEvidenceID,
            executionEvidenceID: cleanupPlanBuilderEvidenceID
        )
        let sessionID = ScanSessionID(
            rawValue:
                "scan-plan-\(cleanupPlanBuilderDigest(rootURL.lastPathComponent))"
        )!
        let scopeID = ScanScopeID(
            rawValue:
                "scope-plan-\(cleanupPlanBuilderDigest(rootURL.lastPathComponent))"
        )!
        let request = ScanRequest(
            rootURL: rootURL,
            maximumWorkers: 1,
            persistenceBatchSize: 2,
            sessionID: sessionID,
            scopeID: scopeID
        )
        for try await _ in try await coordinator.start(request) {}
        return (sessionID, scopeID)
    }

    func builder(
        store: EvidenceStore,
        activitySource: CleanupPlanBuilderActivitySource,
        identitySlug: String = "default"
    ) throws -> CleanupPlanBuilder {
        let rules = try BuiltInRuleCatalog.load()
        let profiles = try BuiltInExecutionProfileCatalog.load(
            ruleCatalog: rules
        )
        return CleanupPlanBuilder(
            store: store,
            ruleCatalog: rules,
            executionProfileCatalog: profiles,
            evidenceResolver: ExecutableEvidenceResolver(
                activityProvider: RunningActivityProvider(
                    source: activitySource
                )
            ),
            now: { self.observedAt.addingTimeInterval(1) },
            planID: {
                CleanupPlanID(
                    rawValue:
                        "plan-task29-\(identitySlug)-\(cleanupPlanBuilderDigest(self.rootURL.lastPathComponent))"
                )!
            },
            itemID: { snapshotID, _ in
                CleanupPlanItemID(
                    rawValue:
                        "plan-item-\(identitySlug)-\(cleanupPlanBuilderDigest(snapshotID.rawValue))"
                )!
            },
            evidenceID: cleanupPlanBuilderEvidenceID
        )
    }

    func activitySnapshot(
        processes: [String]
    ) -> RunningActivitySnapshot {
        RunningActivitySnapshot(
            applications: [],
            processes: processes.enumerated().map { index, name in
                try! RunningProcessRecord(
                    name: DomainLabel(rawValue: name)!,
                    processIdentifier: Int32(500 + index)
                )
            },
            observedAt: observedAt.addingTimeInterval(1)
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}

private func seedLargeCleanupPlanningStore(
    store: EvidenceStore,
    fixture: CleanupPlanBuilderFixture,
    fallbackCount: Int
) async throws -> ScanSessionID {
    let rules = try BuiltInRuleCatalog.load()
    let profiles = try BuiltInExecutionProfileCatalog.load(
        ruleCatalog: rules
    )
    let sessionID = ScanSessionID(rawValue: "scan-plan-large-fixture")!
    let scopeID = ScanScopeID(rawValue: "scope-plan-large-fixture")!
    let rootIdentity = try #require(FileIdentity.read(at: fixture.rootURL))
    let finishedAt = fixture.observedAt
    let total = fallbackCount + profiles.profiles.count
    let session = try ScanSession(
        id: sessionID,
        startedAt: finishedAt.addingTimeInterval(-1),
        finishedAt: finishedAt,
        terminalState: .completed,
        completedScopes: [
            ScanScope(
                id: scopeID,
                rootPath: PersistedPath(rawValue: fixture.rootURL.path)!,
                completedAt: finishedAt
            ),
        ],
        unfinishedScopes: [],
        aggregate: ScanAggregate(
            entries: try ScanEntryCounts(
                total: total,
                regularFiles: 0,
                directories: total,
                symbolicLinks: 0,
                inaccessible: 0,
                other: 0
            ),
            issues: try ScanIssueCounts(
                permissionDenied: 0,
                mountBoundary: 0,
                userExcluded: 0,
                metadataUnavailable: 0,
                directoryReadFailed: 0
            ),
            logicalFileBytes: 0,
            allocatedFileBytes: 0
        )
    )
    try await store.saveScanSession(session)
    try await store.saveVolumeBaseline(
        VolumeBaseline(
            sessionID: sessionID,
            scopeID: scopeID,
            rootPath: PersistedPath(rawValue: fixture.rootURL.path)!,
            rootIdentity: rootIdentity,
            totalCapacity: nil,
            availableCapacity: nil,
            availableCapacityForImportantUsage: nil,
            availableCapacityForOpportunisticUsage: nil,
            volumeIsReadOnly: false,
            source: AccountingSource(
                kind: .volumeResourceValues,
                identifier: DomainToken(rawValue: "fixture.volume")!,
                sampledAt: finishedAt
            )
        )
    )
    var snapshots: [PathSnapshot] = []
    var classifications: [Classification] = []
    snapshots.reserveCapacity(total)
    classifications.reserveCapacity(total)
    for index in 0..<fallbackCount {
        let path = String(format: "0-fallback/%05d", index)
        let snapshot = try syntheticPlanningSnapshot(
            sessionID: sessionID,
            scopeID: scopeID,
            relativePath: path,
            identity: FileIdentity(
                device: rootIdentity.device,
                inode: UInt64(10_000 + index),
                mode: UInt16(S_IFDIR | 0o700),
                ownerUserID: getuid(),
                ownerGroupID: getgid(),
                size: 4_096,
                allocatedBytes: 8_192,
                modificationSeconds: Int64(finishedAt.timeIntervalSince1970),
                modificationNanoseconds: 0
            ),
            observedAt: finishedAt
        )
        snapshots.append(snapshot)
        classifications.append(
            try Classification(
                id: cleanupPlanBuilderClassificationID(snapshot.id),
                snapshotID: snapshot.id,
                ruleID: nil,
                producer: nil,
                category: .unknownLargeConsumers,
                disposition: .unknown,
                risk: .high,
                confidence: .low,
                recovery: nil,
                requiredEvidenceKeys: [],
                missingEvidenceKeys: [],
                catalogVersion: rules.catalogVersion,
                classifiedAt: finishedAt
            )
        )
    }
    var evidence: [EvidenceRecord] = []
    for profile in profiles.profiles {
        let rule = try #require(
            rules.rules.first { $0.id == profile.ruleID }
        )
        let url = fixture.rootURL.appending(
            path: profile.relativePath.rawValue,
            directoryHint: .isDirectory
        )
        let identity = try #require(FileIdentity.read(at: url))
        let snapshot = try syntheticPlanningSnapshot(
            sessionID: sessionID,
            scopeID: scopeID,
            relativePath: profile.relativePath.rawValue,
            identity: identity,
            observedAt: finishedAt
        )
        snapshots.append(snapshot)
        classifications.append(
            try Classification(
                id: cleanupPlanBuilderClassificationID(snapshot.id),
                snapshotID: snapshot.id,
                ruleID: DomainToken(rawValue: rule.id.rawValue)!,
                producer: rule.producer,
                category: rule.category,
                disposition: rule.disposition,
                risk: rule.risk,
                confidence: .high,
                recovery: rule.recovery,
                requiredEvidenceKeys: Array(Set(
                    rule.requiredEvidenceKeys
                        + rule.requiredActivityKeys
                )).sorted { $0.rawValue < $1.rawValue },
                missingEvidenceKeys: [],
                catalogVersion: rules.catalogVersion,
                classifiedAt: finishedAt
            )
        )
        evidence.append(contentsOf: profile.resolverBindings.map { binding in
            EvidenceRecord(
                id: cleanupPlanBuilderEvidenceID(snapshot.id, binding.key),
                targetID: snapshot.id,
                kind: binding.resolver == .currentActivity
                    ? .activity
                    : binding.resolver == .currentFilesystem
                        ? .producer
                        : .rule,
                source: EvidenceSource(
                    kind: binding.resolver == .currentActivity
                        ? .activityProvider
                        : binding.resolver == .currentFilesystem
                            ? .surveyor
                            : .rule,
                    identifier: DomainToken(
                        rawValue:
                            "execution.ah.nopii.\(binding.resolver.rawValue).\(binding.key.rawValue)"
                    )!
                ),
                summaryKey: DomainToken(
                    rawValue: "execution.\(binding.key.rawValue).satisfied"
                )!,
                observedAt: finishedAt,
                freshness: .current
            )
        })
    }
    for batchStart in stride(from: 0, to: snapshots.count, by: 512) {
        let end = min(batchStart + 512, snapshots.count)
        try await store.savePathSnapshots(
            Array(snapshots[batchStart..<end])
        )
        try await store.saveClassifications(
            Array(classifications[batchStart..<end])
        )
    }
    try await store.saveEvidence(evidence)
    return sessionID
}

private func syntheticPlanningSnapshot(
    sessionID: ScanSessionID,
    scopeID: ScanScopeID,
    relativePath: String,
    identity: FileIdentity,
    observedAt: Date
) throws -> PathSnapshot {
    try PathSnapshot(
        id: cleanupPlanBuilderSnapshotID(relativePath),
        sessionID: sessionID,
        scopeID: scopeID,
        relativePath: relativePath,
        kind: .directory,
        logicalByteCount: ByteCount(UInt64(identity.size))!,
        allocatedByteCount: ByteCount(UInt64(identity.allocatedBytes))!,
        modifiedAt: Date(
            timeIntervalSince1970:
                TimeInterval(identity.modificationSeconds)
                    + TimeInterval(identity.modificationNanoseconds)
                    / 1_000_000_000
        ),
        fileIdentity: identity,
        symlinkTarget: nil,
        measurementStatus: .measured,
        observedAt: observedAt
    )
}

private actor CleanupPlanBuilderActivitySource:
    RunningActivitySnapshotting
{
    private let snapshotValue: RunningActivitySnapshot
    private(set) var callCount = 0

    init(snapshot: RunningActivitySnapshot) {
        snapshotValue = snapshot
    }

    func snapshot() async throws -> RunningActivitySnapshot {
        callCount += 1
        return snapshotValue
    }
}

private struct CleanupPlanBuilderGenericActivityProvider:
    QuickScanActivityProviding
{
    func observations(
        for snapshot: PathSnapshot,
        rule: CompiledRule,
        rootURL: URL,
        observedAt: Date
    ) async throws -> [ActivityObservation] {
        try rule.requiredActivityKeys.map {
            try ActivityObservation(
                key: ActivityKey(validating: $0.rawValue),
                state: .satisfied,
                source: .runningProcess,
                origin: .external,
                observedAt: observedAt,
                reason: DomainToken(
                    rawValue: "activity.fixture.inactive"
                )!
            )
        }
    }
}

private extension CleanupPlanBuildOutcome {
    var planReady: (CleanupPlan, ReviewProjection)? {
        guard case let .planReady(plan, projection) = self else {
            return nil
        }
        return (plan, projection)
    }

    var emptyProjection: ReviewProjection? {
        guard case let .empty(projection) = self else {
            return nil
        }
        return projection
    }

    var scanAgainReasons: [DomainToken] {
        guard case let .scanAgain(reasons) = self else {
            return []
        }
        return reasons
    }
}

private func cleanupPlanBuilderSnapshotID(_ relativePath: String) -> SnapshotID {
    SnapshotID(
        rawValue: "snapshot-\(cleanupPlanBuilderDigest(relativePath))"
    )!
}

private func cleanupPlanBuilderClassificationID(
    _ snapshotID: SnapshotID
) -> ClassificationID {
    ClassificationID(
        rawValue:
            "classification-\(cleanupPlanBuilderDigest(snapshotID.rawValue))"
    )!
}

private func cleanupPlanBuilderActivityEvidenceID(
    _ snapshotID: SnapshotID,
    _ observation: ActivityObservation
) -> EvidenceID {
    cleanupPlanBuilderEvidenceID(
        snapshotID,
        DomainToken(rawValue: observation.key.rawValue)!
    )
}

private func cleanupPlanBuilderEvidenceID(
    _ snapshotID: SnapshotID,
    _ key: DomainToken
) -> EvidenceID {
    let digest = cleanupPlanBuilderDigest(
        "\(snapshotID.rawValue)|\(key.rawValue)"
    )
    return EvidenceID(rawValue: "evidence-\(digest)")!
}

private func cleanupPlanBuilderDigest(_ value: String) -> String {
    SHA256.hash(data: Data(value.utf8))
        .prefix(12)
        .map { String(format: "%02x", $0) }
        .joined()
}
