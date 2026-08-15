import Darwin
import Foundation
import Testing
@testable import StornautCore

@Test
func cleanupPolicyCollectorUsesOneActivityCaptureAndProducesAllowedContext()
    async throws
{
    let fixture = try await CleanupPolicyCollectorFixture()
    defer { fixture.remove() }
    let source = CleanupPolicyCollectorActivitySource(
        snapshot: fixture.activitySnapshot
    )
    let collector = fixture.collector(
        activitySource: source,
        leaseAvailable: true
    )

    let outcome = await collector.collect(
        plan: fixture.plan,
        selection: fixture.selection
    )
    let context = try #require(outcome.context)
    let evaluation = try CleanupPolicyGate().evaluate(
        plan: fixture.plan,
        selection: fixture.selection,
        context: context,
        evaluatedAt: fixture.now
    )

    #expect(await source.callCount == 1)
    #expect(context.items.count == 1)
    #expect(context.items[0].currentIdentity
        == fixture.plan.items[0].expectedIdentity)
    #expect(context.items[0].evidenceFacts == .current)
    #expect(context.items[0].activityFacts == .inactive)
    #expect(evaluation.allowed != nil)
}

@Test
func cleanupPolicyCollectorAdmitsOnlyMatchingDiagnosticEvidence()
    async throws
{
    let nonce = UUID().uuidString.lowercased()
    let fixture = try await CleanupPolicyCollectorFixture(
        diagnosticNonce: nonce
    )
    defer { fixture.remove() }
    let unrelatedNode = RunningActivitySnapshot(
        applications: [],
        processes: [
            try RunningProcessRecord(
                name: DomainLabel(validating: "node"),
                processIdentifier: 7_035
            ),
        ],
        observedAt: fixture.now.addingTimeInterval(-2)
    )
    let diagnosticSource = CleanupPolicyCollectorActivitySource(
        snapshot: unrelatedNode
    )
    let targetIdentity = try #require(fixture.snapshot.fileIdentity)
    let diagnosticResolver = try ExecutableEvidenceResolver
        .phaseCTrashDiagnostic(
            diagnosticRootURL: fixture.removalRootURL,
            fixtureRootURL: fixture.rootURL,
            nonce: nonce,
            expectedTargetIdentity: targetIdentity,
            activityProvider: RunningActivityProvider(
                source: diagnosticSource
            )
        )
    let diagnosticCollector = fixture.collector(
        activitySource: diagnosticSource,
        leaseAvailable: true,
        resolver: diagnosticResolver
    )

    let diagnosticOutcome = await diagnosticCollector.collect(
        plan: fixture.plan,
        selection: fixture.selection
    )
    let diagnosticContext = try #require(diagnosticOutcome.context)
    let diagnosticEvaluation = try CleanupPolicyGate().evaluate(
        plan: fixture.plan,
        selection: fixture.selection,
        context: diagnosticContext,
        evaluatedAt: fixture.now
    )

    #expect(diagnosticContext.items[0].evidenceFacts == .current)
    #expect(
        diagnosticContext.items[0].activityFacts
            == CleanupActivityPolicyFacts.inactive
    )
    #expect(diagnosticEvaluation.allowed != nil)

    let ordinarySource = CleanupPolicyCollectorActivitySource(
        snapshot: unrelatedNode
    )
    let ordinaryCollector = fixture.collector(
        activitySource: ordinarySource,
        leaseAvailable: true
    )
    let ordinaryOutcome = await ordinaryCollector.collect(
        plan: fixture.plan,
        selection: fixture.selection
    )
    let ordinaryContext = try #require(ordinaryOutcome.context)
    let ordinaryEvaluation = try CleanupPolicyGate().evaluate(
        plan: fixture.plan,
        selection: fixture.selection,
        context: ordinaryContext,
        evaluatedAt: fixture.now
    )

    #expect(ordinaryContext.items[0].evidenceFacts == .missing)
    #expect(
        ordinaryContext.items[0].activityFacts
            == CleanupActivityPolicyFacts.active
    )
    #expect(ordinaryEvaluation.blocked != nil)
}

@Test
func cleanupPolicyCollectorFailsClosedForUnavailableActivityAndRootLease()
    async throws
{
    let fixture = try await CleanupPolicyCollectorFixture()
    defer { fixture.remove() }
    let source = CleanupPolicyCollectorActivitySource(
        failure: .permissionDenied
    )
    let collector = fixture.collector(
        activitySource: source,
        leaseAvailable: false
    )

    let outcome = await collector.collect(
        plan: fixture.plan,
        selection: fixture.selection
    )
    let context = try #require(outcome.context)
    let evaluation = try CleanupPolicyGate().evaluate(
        plan: fixture.plan,
        selection: fixture.selection,
        context: context,
        evaluatedAt: fixture.now
    )
    let blocked = try #require(evaluation.blocked)
    let reasons = Set(
        blocked.decisions.flatMap(\.reasonKeys).map(\.rawValue)
    )

    #expect(await source.callCount == 1)
    #expect(context.rootIdentity == nil)
    #expect(!context.workflow.rootLeaseAvailable)
    #expect(context.items[0].activityFacts == .unavailable)
    #expect(reasons.contains("policy.root.changed"))
    #expect(reasons.contains("policy.root.lease-lost"))
    #expect(reasons.contains("policy.activity.unavailable"))
}

@Test
func cleanupPolicyCollectorBlocksStoreFailureWithoutActivityCapture()
    async throws
{
    let fixture = try await CleanupPolicyCollectorFixture()
    defer { fixture.remove() }
    let source = CleanupPolicyCollectorActivitySource(
        snapshot: fixture.activitySnapshot
    )
    let collector = fixture.collector(
        store: FailingCleanupPolicyStore(),
        activitySource: source,
        leaseAvailable: true
    )

    let outcome = await collector.collect(
        plan: fixture.plan,
        selection: fixture.selection
    )

    guard case let .blocked(error, affected) = outcome else {
        Issue.record("expected a blocked collection")
        return
    }
    #expect(error == .storeTruthUnavailable)
    #expect(affected == Set(fixture.selection.items.map(\.itemID)))
    #expect(await source.callCount == 0)
}

@Test
func cleanupPolicyCollectorRejectsTamperedPersistedClassificationSemantics()
    async throws
{
    let fixture = try await CleanupPolicyCollectorFixture()
    defer { fixture.remove() }
    let source = CleanupPolicyCollectorActivitySource(
        snapshot: fixture.activitySnapshot
    )
    let tampered = try Classification(
        id: fixture.classification.id,
        snapshotID: fixture.classification.snapshotID,
        ruleID: fixture.classification.ruleID,
        producer: fixture.classification.producer,
        category: .unknownLargeConsumers,
        disposition: fixture.classification.disposition,
        risk: fixture.classification.risk,
        confidence: fixture.classification.confidence,
        recovery: fixture.classification.recovery,
        requiredEvidenceKeys:
            fixture.classification.requiredEvidenceKeys,
        missingEvidenceKeys: fixture.classification.missingEvidenceKeys,
        catalogVersion: fixture.classification.catalogVersion,
        classifiedAt: fixture.classification.classifiedAt
    )
    let store = CleanupPolicyCollectorStore(
        session: fixture.session,
        records: [
            CleanupPolicyStoreRecord(
                planItem: fixture.plan.items[0],
                snapshot: fixture.snapshot,
                classification: tampered,
                evidence: fixture.evidence
            ),
        ]
    )
    let collector = fixture.collector(
        store: store,
        activitySource: source,
        leaseAvailable: true
    )

    let outcome = await collector.collect(
        plan: fixture.plan,
        selection: fixture.selection
    )

    guard case let .blocked(error, affected) = outcome else {
        Issue.record("expected tampered classification to be blocked")
        return
    }
    #expect(error == .itemTruthUnavailable)
    #expect(affected == [fixture.plan.items[0].id])
}

@Test
func cleanupPolicyStoreLoadsSelectedTruthInPlanOrderAndRejectsUnknownItems()
    async throws
{
    let fixture = try await CleanupPolicyCollectorFixture()
    defer { fixture.remove() }
    let store = try EvidenceStore(configuration: .memory)
    try await store.saveScanSession(fixture.session)
    try await store.savePathSnapshots([fixture.snapshot])
    try await store.saveClassifications([fixture.classification])
    try await store.saveEvidence(fixture.evidence)
    try await store.saveCleanupPlan(fixture.plan)

    let records = try await store.cleanupPolicyRecords(
        plan: fixture.plan,
        selectedItemIDs: [fixture.plan.items[0].id]
    )

    #expect(records.count == 1)
    #expect(records[0].planItem == fixture.plan.items[0])
    #expect(records[0].snapshot.id == fixture.snapshot.id)
    #expect(records[0].snapshot.sessionID == fixture.snapshot.sessionID)
    #expect(records[0].snapshot.scopeID == fixture.snapshot.scopeID)
    #expect(records[0].snapshot.relativePath == fixture.snapshot.relativePath)
    #expect(records[0].snapshot.kind == fixture.snapshot.kind)
    #expect(records[0].snapshot.logicalByteCount
        == fixture.snapshot.logicalByteCount)
    #expect(records[0].snapshot.allocatedByteCount
        == fixture.snapshot.allocatedByteCount)
    #expect(records[0].snapshot.fileIdentity
        == fixture.snapshot.fileIdentity)
    #expect(abs(
        try #require(records[0].snapshot.modifiedAt)
            .timeIntervalSince(try #require(fixture.snapshot.modifiedAt))
    ) < 0.001)
    #expect(records[0].classification == fixture.classification)
    #expect(records[0].evidence == fixture.evidence.sorted {
        if $0.observedAt != $1.observedAt {
            return $0.observedAt < $1.observedAt
        }
        return $0.id.rawValue < $1.id.rawValue
    })
    await #expect(throws: EvidenceStoreError.recordIdentityMismatch) {
        _ = try await store.cleanupPolicyRecords(
            plan: fixture.plan,
            selectedItemIDs: [
                CleanupPlanItemID(rawValue: "plan-item-unknown")!,
            ]
        )
    }
}

private struct CleanupPolicyCollectorFixture {
    let now: Date
    let rootURL: URL
    let removalRootURL: URL
    let cacheURL: URL
    let rules: RuleCatalog
    let profiles: ExecutionProfileCatalog
    let activitySnapshot: RunningActivitySnapshot
    let session: ScanSession
    let snapshot: PathSnapshot
    let classification: Classification
    let evidence: [EvidenceRecord]
    let plan: CleanupPlan
    let selection: ReviewSelection
    let store: CleanupPolicyCollectorStore

    init(diagnosticNonce: String? = nil) async throws {
        now = Date(timeIntervalSince1970: 1_786_640_000)
        if diagnosticNonce != nil {
            removalRootURL = FileManager.default.temporaryDirectory
                .appending(
                    path:
                        "stornaut-phase-c-trash.\(UUID().uuidString)",
                    directoryHint: .isDirectory
                )
            rootURL = removalRootURL.appending(
                path: "fixture",
                directoryHint: .isDirectory
            )
        } else {
            rootURL = FileManager.default.temporaryDirectory.appending(
                path: "stornaut-policy-collector-\(UUID().uuidString)",
                directoryHint: .isDirectory
            )
            removalRootURL = rootURL
        }
        cacheURL = rootURL.appending(
            path: ".npm/_cacache",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: cacheURL,
            withIntermediateDirectories: true
        )
        if let diagnosticNonce {
            for url in [
                removalRootURL,
                rootURL,
                rootURL.appending(
                    path: ".npm",
                    directoryHint: .isDirectory
                ),
                cacheURL,
            ] {
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o700],
                    ofItemAtPath: url.path
                )
            }
            try Data(
                "stornaut-phase-c-root:\(diagnosticNonce)".utf8
            ).write(
                to: removalRootURL.appending(
                    path:
                        ".stornaut-phase-c-trash-fixture-\(diagnosticNonce)"
                )
            )
            try Data(
                "stornaut-phase-c-trash-item:\(diagnosticNonce)".utf8
            ).write(
                to: cacheURL.appending(
                    path:
                        ".stornaut-phase-c-trash-item-\(diagnosticNonce)"
                )
            )
        }
        let rootIdentity = try #require(FileIdentity.read(at: rootURL))
        let cacheIdentity = try #require(FileIdentity.read(at: cacheURL))
        rules = try BuiltInRuleCatalog.load()
        profiles = try BuiltInExecutionProfileCatalog.load(
            ruleCatalog: rules
        )
        let rule = try #require(
            rules.rules.first { $0.id.rawValue == "cache-npm-content" }
        )
        let profile = try #require(
            profiles.profile(ruleID: rule.id)
        )
        activitySnapshot = RunningActivitySnapshot(
            applications: [],
            processes: [],
            observedAt: now.addingTimeInterval(-2)
        )
        let activityContext = RunningActivityContext(
            snapshot: activitySnapshot,
            failure: nil,
            observedAt: activitySnapshot.observedAt
        )
        let sessionID = ScanSessionID(rawValue: "scan-policy-collector")!
        let scopeID = ScanScopeID(rawValue: "scope-policy-collector")!
        let snapshotID = SnapshotID(rawValue: "snapshot-policy-collector")!
        let classificationID = ClassificationID(
            rawValue: "classification-policy-collector"
        )!
        session = try ScanSession(
            id: sessionID,
            startedAt: now.addingTimeInterval(-10),
            finishedAt: now.addingTimeInterval(-1),
            terminalState: .completed,
            completedScopes: [
                ScanScope(
                    id: scopeID,
                    rootPath: PersistedPath(rawValue: rootURL.path)!,
                    completedAt: now.addingTimeInterval(-1)
                ),
            ],
            unfinishedScopes: [],
            aggregate: try ScanAggregate(
                entries: ScanEntryCounts(
                    total: 1,
                    regularFiles: 0,
                    directories: 1,
                    symbolicLinks: 0,
                    inaccessible: 0,
                    other: 0
                ),
                issues: ScanIssueCounts(
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
        snapshot = try PathSnapshot(
            id: snapshotID,
            sessionID: sessionID,
            scopeID: scopeID,
            relativePath: ".npm/_cacache",
            kind: .directory,
            logicalByteCount: ByteCount(
                UInt64(cacheIdentity.size)
            )!,
            allocatedByteCount: ByteCount(
                UInt64(cacheIdentity.allocatedBytes)
            )!,
            modifiedAt: Date(
                timeIntervalSince1970:
                    TimeInterval(cacheIdentity.modificationSeconds)
                    + TimeInterval(cacheIdentity.modificationNanoseconds)
                    / 1_000_000_000
            ),
            fileIdentity: cacheIdentity,
            symlinkTarget: nil,
            measurementStatus: .measured,
            observedAt: now.addingTimeInterval(-2)
        )
        let resolver: ExecutableEvidenceResolver
        if let diagnosticNonce {
            resolver = try ExecutableEvidenceResolver
                .phaseCTrashDiagnostic(
                    diagnosticRootURL: removalRootURL,
                    fixtureRootURL: rootURL,
                    nonce: diagnosticNonce,
                    expectedTargetIdentity: cacheIdentity,
                    activityProvider: RunningActivityProvider(
                        source: CleanupPolicyCollectorActivitySource(
                            snapshot: activitySnapshot
                        )
                    )
                )
        } else {
            resolver = ExecutableEvidenceResolver(
                activityProvider: RunningActivityProvider(
                    source: CleanupPolicyCollectorActivitySource(
                        snapshot: activitySnapshot
                    )
                )
            )
        }
        let resolution = try resolver.resolveQuickScan(
            snapshot: snapshot,
            rule: rule,
            profile: profile,
            profileCatalogVersion: profiles.catalogVersion,
            activityContext: activityContext,
            evidenceID: { _, key in
                EvidenceID(
                    rawValue: "evidence-policy-\(key.rawValue)"
                )!
            }
        )
        evidence = resolution.evidenceRecords
        classification = try DeterministicClassifier().classify(
            snapshot: snapshot,
            candidates: [rule],
            satisfiedEvidenceKeys: resolution.satisfiedEvidenceKeys,
            activityObservations: resolution.activityObservations,
            classifiedAt: now.addingTimeInterval(-1),
            classificationID: classificationID,
            catalogVersion: rules.catalogVersion
        )
        let item = try CleanupPlanItem(
            id: CleanupPlanItemID(
                rawValue: "plan-item-policy-collector"
            )!,
            snapshotID: snapshot.id,
            classificationID: classification.id,
            ruleID: DomainToken(rawValue: rule.id.rawValue)!,
            executionProfileID: profile.id,
            proposedAction: .moveToTrash,
            expectedRelativePath: PersistedPath(
                rawValue: snapshot.relativePath
            )!,
            expectedIdentity: cacheIdentity,
            logicalBytes: snapshot.logicalByteCount!,
            allocatedBytes: snapshot.allocatedByteCount!,
            evidenceFingerprint: resolution.evidenceFingerprint,
            activityFingerprint: resolution.activityFingerprint
        )
        plan = try CleanupPlan(
            id: CleanupPlanID(rawValue: "plan-policy-collector")!,
            scanSessionID: session.id,
            scanScopeID: scopeID,
            primaryRootIdentity: rootIdentity,
            catalogVersion: rules.catalogVersion,
            executionProfileVersion: profiles.catalogVersion,
            planFingerprint: DomainToken(
                rawValue: "plan.policy-collector.fingerprint"
            )!,
            createdAt: now.addingTimeInterval(-1),
            expiresAt: now.addingTimeInterval(60),
            items: [item]
        )
        selection = try ReviewSelection(
            plan: plan,
            generation: 1,
            items: [
                ReviewSelectionItem(
                    itemID: item.id,
                    origin: .defaultReady
                ),
            ],
            dispositions: [item.id: classification.disposition]
        )
        store = CleanupPolicyCollectorStore(
            session: session,
            records: [
                CleanupPolicyStoreRecord(
                    planItem: item,
                    snapshot: snapshot,
                    classification: classification,
                    evidence: evidence
                ),
            ]
        )
    }

    func collector(
        store: (any CleanupPolicyStoreReading)? = nil,
        activitySource: CleanupPolicyCollectorActivitySource,
        leaseAvailable: Bool,
        resolver: ExecutableEvidenceResolver? = nil
    ) -> CleanupPolicyContextCollector {
        CleanupPolicyContextCollector(
            store: store ?? self.store,
            ruleCatalog: rules,
            profileCatalog: profiles,
            resolver: resolver ?? ExecutableEvidenceResolver(
                activityProvider: RunningActivityProvider(
                    source: activitySource
                )
            ),
            rootObserver: FixedCleanupPolicyRootObserver(
                rootURL: rootURL,
                leaseAvailable: leaseAvailable
            ),
            workflowObserver:
                FixedCleanupWorkflowAvailabilityObserver(.available),
            homeDirectoryURL: rootURL.deletingLastPathComponent()
                .appending(path: "not-home"),
            isMountRoot: { _ in false },
            now: { now }
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: removalRootURL)
    }
}

private actor CleanupPolicyCollectorStore: CleanupPolicyStoreReading {
    let session: ScanSession
    let records: [CleanupPolicyStoreRecord]

    init(
        session: ScanSession,
        records: [CleanupPolicyStoreRecord]
    ) {
        self.session = session
        self.records = records
    }

    func scanSession(id: ScanSessionID) -> ScanSession? {
        id == session.id ? session : nil
    }

    func cleanupPolicyRecords(
        plan: CleanupPlan,
        selectedItemIDs: [CleanupPlanItemID]
    ) -> [CleanupPolicyStoreRecord] {
        records.filter {
            selectedItemIDs.contains($0.planItem.id)
        }
    }
}

private struct FailingCleanupPolicyStore: CleanupPolicyStoreReading {
    func scanSession(id: ScanSessionID) async throws -> ScanSession? {
        throw EvidenceStoreError.integrityCheckFailed
    }

    func cleanupPolicyRecords(
        plan: CleanupPlan,
        selectedItemIDs: [CleanupPlanItemID]
    ) async throws -> [CleanupPolicyStoreRecord] {
        throw EvidenceStoreError.integrityCheckFailed
    }
}

private struct FixedCleanupPolicyRootObserver:
    CleanupPolicyRootObserving
{
    let rootURL: URL
    let leaseAvailable: Bool

    func observeRoot() async -> CleanupPolicyRootObservation {
        CleanupPolicyRootObservation(
            rootURL: rootURL,
            access: leaseAvailable ? .direct : .unavailable
        )
    }
}

private actor CleanupPolicyCollectorActivitySource:
    RunningActivitySnapshotting
{
    let snapshotValue: RunningActivitySnapshot?
    let failure: ActivityProviderFailure?
    private(set) var callCount = 0

    init(snapshot: RunningActivitySnapshot) {
        snapshotValue = snapshot
        failure = nil
    }

    init(failure: ActivityProviderFailure) {
        snapshotValue = nil
        self.failure = failure
    }

    func snapshot() throws -> RunningActivitySnapshot {
        callCount += 1
        if let failure {
            throw failure
        }
        return snapshotValue!
    }
}
