import CryptoKit
import Darwin
import Foundation
import Testing
@testable import StornautCore

@Test
func nativeQuickScanActivityProviderUsesOneGitSnapshotPerRule()
    async throws
{
    let catalog = try task20Catalog()
    let rule = try #require(
        catalog.rules.first {
            Set($0.requiredActivityKeys.map(\.rawValue)) == Set([
                ActivityKey.gitClean.rawValue,
            ])
        }
    )
    let dualGitRule = try CompiledRule(
        id: rule.id,
        match: rule.match,
        excludedPatterns: rule.excludedPatterns,
        producer: rule.producer,
        rationaleKey: rule.rationaleKey,
        category: rule.category,
        disposition: rule.disposition,
        risk: rule.risk,
        confidenceRequirement: rule.confidenceRequirement,
        veto: rule.veto,
        requiredEvidenceKeys: rule.requiredEvidenceKeys,
        requiredActivityKeys: [
            DomainToken(rawValue: ActivityKey.gitClean.rawValue)!,
            DomainToken(
                rawValue: ActivityKey.gitUpstreamSynchronized.rawValue
            )!,
        ],
        recovery: rule.recovery,
        recommendedAction: rule.recommendedAction,
        provenance: rule.provenance,
        fixtureIDs: rule.fixtureIDs,
        appliedOverlayIDs: rule.appliedOverlayIDs
    )
    let snapshot = try task20BoundaryCompatibleSnapshot(
        relativePath: "projects/sample/derived"
    )
    let rootURL = URL(filePath: "/tmp/task20-git-snapshot")
    let observedAt = Date(timeIntervalSince1970: 1_786_320_050)
    let gitProvider = Task20GitActivityCollector(observedAt: observedAt)
    let provider = NativeQuickScanActivityProvider(
        gitProvider: gitProvider
    )

    let observations = try await provider.observations(
        for: snapshot,
        rule: dualGitRule,
        rootURL: rootURL,
        observedAt: observedAt
    )

    #expect(await gitProvider.callCount == 1)
    #expect(
        await gitProvider.lastRepositoryURL
            == rootURL.appending(
                path: snapshot.relativePath
            ).deletingLastPathComponent()
    )
    #expect(
        observations.map(\.key) == [
            .gitClean,
            .gitUpstreamSynchronized,
        ]
    )
    #expect(observations.allSatisfy { $0.observedAt == observedAt })
}

@Test
func quickScanCoordinatorRunsTheRealDeterministicPipeline() async throws {
    let fixture = try Task20Fixture()
    defer { fixture.remove() }
    let store = try EvidenceStore(configuration: fixture.storeConfiguration)
    let coordinator = QuickScanCoordinator(
        store: store,
        historyStore: store,
        catalog: try task20Catalog(),
        activityProvider: FixtureQuickScanActivityProvider(),
        volumeSampler: Task20VolumeSampler(),
        now: Task20DateSource().now,
        snapshotID: task20SnapshotID,
        classificationID: task20ClassificationID,
        evidenceID: task20EvidenceID
    )
    let request = ScanRequest(
        rootURL: fixture.targetURL,
        maximumWorkers: 2,
        persistenceBatchSize: 2,
        sessionID: try ScanSessionID(validating: "scan-task20-complete"),
        scopeID: try ScanScopeID(validating: "scope-task20-complete")
    )
    try fixture.makeTargetReadOnly()
    let before = try auditedTree(at: fixture.targetURL)

    let events = try await collectProductEvents(
        try await coordinator.start(request)
    )
    let projection = try #require(events.compactMap(\.terminal).last)

    #expect(events.compactMap(\.stage) == QuickScanStage.allCases)
    #expect(events.compactMap(\.ledger).count == 1)
    #expect(events.compactMap(\.classification).count
        == projection.classifications.count)
    #expect(
        Dictionary(
            uniqueKeysWithValues: events.compactMap {
                $0.classifiedPair
            }
        ) == Dictionary(
            uniqueKeysWithValues: projection.classifications.map {
                ($0.snapshotID, $0)
            }
        )
    )
    #expect(projection.session.terminalState == .completed)
    #expect(projection.snapshots.count >= 8)
    #expect(
        projection.classifications.count
            < projection.snapshots.count
    )
    #expect(projection.ledger != nil)
    #expect(projection.issues.isEmpty)
    #expect(
        projection.evidence.contains {
            $0.summaryKey.rawValue == "activity.fixture.dirty"
                && $0.kind == .git
        }
    )
    let cacheSnapshot = try #require(
        projection.snapshots.first {
            $0.relativePath == ".fixture-cache"
        }
    )
    let cacheFile = try #require(
        projection.snapshots.first {
            $0.relativePath == ".fixture-cache/cache.bin"
        }
    )
    let cacheOwner = try #require(
        projection.ledger?.owners.first {
            $0.snapshotID == cacheSnapshot.id
        }
    )
    #expect(
        cacheOwner.allocatedBytes?.value
            == cacheSnapshot.allocatedByteCount!.value
                + cacheFile.allocatedByteCount!.value
    )
    #expect(
        classification(
            at: ".fixture-cache",
            in: projection
        )?.disposition == .readyToReclaim
    )
    #expect(
        classification(
            at: "projects/sample/derived",
            in: projection
        )?.disposition == .protected
    )
    #expect(
        classification(
            at: "projects/sample/.ssh",
            in: projection
        )?.disposition == .protected
    )
    #expect(
        classification(
            at: "mystery",
            in: projection
        )?.disposition == .unknown
    )
    #expect(
        classification(
            at: ".fixture-cache",
            in: projection
        )?.missingEvidenceKeys.isEmpty == true
    )
    #expect(try auditedTree(at: fixture.targetURL) == before)
    #expect(
        FileManager.default.fileExists(
            atPath: fixture.codexMarkerURL.path
        ) == false
    )
    #expect(
        try await store.classifications(
            sessionID: request.sessionID,
            limit: 100,
            offset: 0
        ).records == projection.classifications
    )
    #expect(
        try await store.spaceLedger(sessionID: request.sessionID)
            == projection.ledger
    )
}

@Test
func quickScanActivityFailureInvalidatesOnlyDependentCandidates() async throws {
    let fixture = try Task20Fixture()
    defer { fixture.remove() }
    let store = try EvidenceStore(configuration: fixture.storeConfiguration)
    let coordinator = QuickScanCoordinator(
        store: store,
        catalog: try task20Catalog(),
        activityProvider: FailingQuickScanActivityProvider(),
        volumeSampler: Task20VolumeSampler(),
        now: Task20DateSource().now,
        snapshotID: task20SnapshotID,
        classificationID: task20ClassificationID,
        evidenceID: task20EvidenceID
    )
    let request = ScanRequest(
        rootURL: fixture.targetURL,
        maximumWorkers: 1,
        sessionID: try ScanSessionID(validating: "scan-task20-partial"),
        scopeID: try ScanScopeID(validating: "scope-task20-partial")
    )

    let events = try await collectProductEvents(
        try await coordinator.start(request)
    )
    let projection = try #require(events.compactMap(\.terminal).last)

    #expect(projection.session.terminalState == .partial)
    #expect(projection.ledger != nil)
    #expect(
        projection.issues.contains {
            $0.kind == .activityUnavailable
        }
    )
    #expect(
        classification(
            at: ".fixture-cache",
            in: projection
        )?.disposition == .unknown
    )
    #expect(
        classification(
            at: ".fixture-cache",
            in: projection
        )?.missingEvidenceKeys.map(\.rawValue)
            .contains("activity.process.inactive") == true
    )
    #expect(
        classification(
            at: "projects/sample/.ssh",
            in: projection
        )?.disposition == .protected
    )
    #expect(
        classification(
            at: "mystery",
            in: projection
        )?.disposition == .unknown
    )
    let reopened = QuickScanCoordinator(
        store: store,
        catalog: try task20Catalog(),
        activityProvider: FixtureQuickScanActivityProvider(),
        volumeSampler: Task20VolumeSampler()
    )
    let loaded = try await reopened.loadLatest()
    #expect(
        loaded?.issues.contains {
            $0.kind == .activityUnavailable
        } == true
    )
}

@Test
func quickScanPermissionGapRemainsUnmeasurableAndPartial() async throws {
    let fixture = try Task20Fixture()
    defer { fixture.remove() }
    let blockedURL = fixture.targetURL.appending(
        path: "limited",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: blockedURL,
        withIntermediateDirectories: true
    )
    try Data("unreadable".utf8).write(
        to: blockedURL.appending(path: "value.bin")
    )
    let store = try EvidenceStore(configuration: fixture.storeConfiguration)
    let coordinator = QuickScanCoordinator(
        store: store,
        catalog: try task20Catalog(),
        activityProvider: FixtureQuickScanActivityProvider(),
        volumeSampler: Task20VolumeSampler(),
        now: Task20DateSource().now,
        snapshotID: task20SnapshotID,
        classificationID: task20ClassificationID
    )
    let request = ScanRequest(
        rootURL: fixture.targetURL,
        maximumWorkers: 1,
        sessionID: try ScanSessionID(
            validating: "scan-task20-unmeasurable"
        ),
        scopeID: try ScanScopeID(
            validating: "scope-task20-unmeasurable"
        ),
        testHooks: SurveyorTestHooks(
            issueBeforeDirectoryRead: { url in
                url.standardizedFileURL == blockedURL.standardizedFileURL
                    ? .permissionDenied
                    : nil
            }
        )
    )

    let projection = try #require(
        try await collectProductEvents(
            try await coordinator.start(request)
        ).compactMap(\.terminal).last
    )

    #expect(projection.session.terminalState == .partial)
    #expect(projection.ledger?.status == .partial)
    #expect(projection.ledger?.unmeasurable.status == .unmeasurable)
    #expect(projection.ledger?.unmeasurable.bytes == nil)
    #expect(projection.ledger?.unknownIncludesUnmeasurable == true)
    #expect(
        projection.ledger?.coverageGaps.contains {
            $0.relativePath.rawValue == "limited"
                && $0.status == .permissionDenied
        } == true
    )
}

@Test
func quickScanLiteralGlobCharactersRemainUnknown() async throws {
    let fixture = try Task20Fixture()
    defer { fixture.remove() }
    let unusualName = "literal*?[name]\\directory"
    let unusualURL = fixture.targetURL.appending(
        path: unusualName,
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: unusualURL,
        withIntermediateDirectories: true
    )
    try Data("literal filename".utf8).write(
        to: unusualURL.appending(path: "value.bin")
    )
    let store = try EvidenceStore(configuration: fixture.storeConfiguration)
    let coordinator = QuickScanCoordinator(
        store: store,
        catalog: try task20Catalog(),
        activityProvider: FixtureQuickScanActivityProvider(),
        volumeSampler: Task20VolumeSampler(),
        now: Task20DateSource().now,
        snapshotID: task20SnapshotID,
        classificationID: task20ClassificationID
    )
    let request = ScanRequest(
        rootURL: fixture.targetURL,
        maximumWorkers: 1,
        sessionID: try ScanSessionID(
            validating: "scan-task20-literal-glob"
        ),
        scopeID: try ScanScopeID(
            validating: "scope-task20-literal-glob"
        )
    )

    let projection = try #require(
        try await collectProductEvents(
            try await coordinator.start(request)
        ).compactMap(\.terminal).last
    )

    #expect(projection.session.terminalState == .completed)
    #expect(
        classification(
            at: unusualName,
            in: projection
        )?.disposition == .unknown
    )
    #expect(projection.issues.isEmpty)
}

@Test
func quickScanClassificationStoreFailurePreservesSnapshotsAsPartial()
    async throws
{
    let fixture = try Task20Fixture()
    defer { fixture.remove() }
    let backing = try EvidenceStore(configuration: fixture.storeConfiguration)
    let store = FailingClassificationProductStore(backing: backing)
    let coordinator = QuickScanCoordinator(
        store: store,
        catalog: try task20Catalog(),
        activityProvider: FixtureQuickScanActivityProvider(),
        volumeSampler: Task20VolumeSampler(),
        now: Task20DateSource().now,
        snapshotID: task20SnapshotID,
        classificationID: task20ClassificationID
    )
    let request = ScanRequest(
        rootURL: fixture.targetURL,
        maximumWorkers: 1,
        sessionID: try ScanSessionID(
            validating: "scan-task20-store-partial"
        ),
        scopeID: try ScanScopeID(
            validating: "scope-task20-store-partial"
        )
    )

    let projection = try #require(
        try await collectProductEvents(
            try await coordinator.start(request)
        ).compactMap(\.terminal).last
    )

    #expect(projection.session.terminalState == .partial)
    #expect(!projection.snapshots.isEmpty)
    #expect(projection.classifications.isEmpty)
    #expect(projection.ledger == nil)
    #expect(
        projection.issues.map(\.kind) == [.persistenceUnavailable]
    )
    #expect(
        try await backing.scanSession(id: request.sessionID)?
            .terminalState == .partial
    )
    #expect(
        try await backing.scanSession(id: request.sessionID)?
            .unfinishedScopes.first?.reason == .storeFailure
    )
    let reopened = QuickScanCoordinator(
        store: backing,
        catalog: try task20Catalog(),
        activityProvider: FixtureQuickScanActivityProvider(),
        volumeSampler: Task20VolumeSampler()
    )
    let loaded = try await reopened.loadLatest()
    #expect(
        loaded?.issues.contains {
            $0.kind == .persistenceUnavailable
        } == true
    )
}

@Test
func quickScanEndBaselineFailurePreservesFactsAsPartial() async throws {
    let fixture = try Task20Fixture()
    defer { fixture.remove() }
    let store = try EvidenceStore(configuration: fixture.storeConfiguration)
    let coordinator = QuickScanCoordinator(
        store: store,
        catalog: try task20Catalog(),
        activityProvider: FixtureQuickScanActivityProvider(),
        volumeSampler: FailingEndVolumeSampler(),
        now: Task20DateSource().now,
        snapshotID: task20SnapshotID,
        classificationID: task20ClassificationID
    )
    let request = ScanRequest(
        rootURL: fixture.targetURL,
        maximumWorkers: 1,
        sessionID: try ScanSessionID(
            validating: "scan-task20-end-baseline-partial"
        ),
        scopeID: try ScanScopeID(
            validating: "scope-task20-end-baseline-partial"
        )
    )

    let projection = try #require(
        try await collectProductEvents(
            try await coordinator.start(request)
        ).compactMap(\.terminal).last
    )

    #expect(projection.session.terminalState == .partial)
    #expect(!projection.snapshots.isEmpty)
    #expect(!projection.classifications.isEmpty)
    #expect(projection.ledger == nil)
    #expect(
        projection.issues.contains {
            $0.kind == .ledgerUnavailable
                && $0.reasonKey.rawValue
                    == "quick-scan.ledger.end-baseline-unavailable"
        }
    )
    #expect(
        try await store.scanSession(id: request.sessionID)?
            .terminalState == .partial
    )
    #expect(
        try await store.scanSession(id: request.sessionID)?
            .unfinishedScopes.first?.reason == .metadataChanged
    )
    let reopened = QuickScanCoordinator(
        store: store,
        catalog: try task20Catalog(),
        activityProvider: FixtureQuickScanActivityProvider(),
        volumeSampler: Task20VolumeSampler()
    )
    let loaded = try await reopened.loadLatest()
    #expect(
        loaded?.issues.contains {
            $0.kind == .ledgerUnavailable
        } == true
    )
}

@Test
func quickScanFinalSessionStoreFailurePreservesDurableLedgerAsPartial()
    async throws
{
    let fixture = try Task20Fixture()
    defer { fixture.remove() }
    let backing = try EvidenceStore(configuration: fixture.storeConfiguration)
    let store = BlockingCommitProductStore(
        backing: backing,
        blockPoint: .failingFinalSessionSave
    )
    let coordinator = QuickScanCoordinator(
        store: store,
        catalog: try task20Catalog(),
        activityProvider: FixtureQuickScanActivityProvider(),
        volumeSampler: Task20VolumeSampler(),
        now: Task20DateSource().now,
        snapshotID: task20SnapshotID,
        classificationID: task20ClassificationID
    )
    let request = ScanRequest(
        rootURL: fixture.targetURL,
        maximumWorkers: 1,
        sessionID: try ScanSessionID(
            validating: "scan-task20-final-session-partial"
        ),
        scopeID: try ScanScopeID(
            validating: "scope-task20-final-session-partial"
        )
    )

    let projection = try #require(
        try await collectProductEvents(
            try await coordinator.start(request)
        ).compactMap(\.terminal).last
    )

    #expect(projection.session.terminalState == .partial)
    #expect(!projection.snapshots.isEmpty)
    #expect(!projection.classifications.isEmpty)
    #expect(projection.ledger != nil)
    #expect(
        projection.issues.contains {
            $0.kind == .persistenceUnavailable
                && $0.reasonKey.rawValue
                    == "quick-scan.terminal.persistence-unavailable"
        }
    )
    #expect(
        try await backing.scanSession(id: request.sessionID)?
            .terminalState == .partial
    )
    #expect(
        try await backing.scanSession(id: request.sessionID)?
            .unfinishedScopes.first?.reason == .storeFailure
    )
    let reopened = QuickScanCoordinator(
        store: backing,
        catalog: try task20Catalog(),
        activityProvider: FixtureQuickScanActivityProvider(),
        volumeSampler: Task20VolumeSampler()
    )
    let loaded = try await reopened.loadLatest()
    #expect(loaded?.session.terminalState == .partial)
    #expect(loaded?.ledger == projection.ledger)
    #expect(
        loaded?.issues.contains {
            $0.kind == .persistenceUnavailable
        } == true
    )
}

@Test
func quickScanCancellationAndConcurrentIntentRemainControlled() async throws {
    let fixture = try Task20Fixture(extraFileCount: 160)
    defer { fixture.remove() }
    let store = try EvidenceStore(configuration: fixture.storeConfiguration)
    let coordinator = QuickScanCoordinator(
        store: store,
        catalog: try task20Catalog(),
        activityProvider: FixtureQuickScanActivityProvider(),
        volumeSampler: Task20VolumeSampler(),
        now: Task20DateSource().now,
        snapshotID: task20SnapshotID,
        classificationID: task20ClassificationID
    )
    let request = ScanRequest(
        rootURL: fixture.targetURL,
        maximumWorkers: 1,
        persistenceBatchSize: 1,
        sessionID: try ScanSessionID(validating: "scan-task20-cancel"),
        scopeID: try ScanScopeID(validating: "scope-task20-cancel"),
        testHooks: SurveyorTestHooks(
            beforeDirectoryRead: { _ in usleep(3_000) }
        )
    )
    let stream = try await coordinator.start(request)
    let collector = Task {
        try await collectProductEvents(stream)
    }
    try await waitForActiveCoordinator(coordinator)
    try await waitForPersistedSnapshots(
        store,
        sessionID: request.sessionID
    )

    await #expect(throws: QuickScanLifecycleError.scanAlreadyRunning) {
        _ = try await coordinator.start(
            ScanRequest(rootURL: fixture.targetURL)
        )
    }
    await #expect(throws: QuickScanLifecycleError.scanAlreadyRunning) {
        _ = try await coordinator.loadHistory()
    }
    await coordinator.cancel()
    await coordinator.cancel()
    let events = try await collector.value
    let projection = try #require(events.compactMap(\.terminal).last)

    #expect(projection.session.terminalState == .cancelled)
    #expect(projection.ledger == nil)
    #expect(!projection.snapshots.isEmpty)
    #expect(await coordinator.hasActiveScan == false)
    #expect(
        try await store.scanSession(id: request.sessionID)?
            .terminalState == .cancelled
    )
}

@Test
func quickScanWaitsForInFlightHistoryAccessBeforeStarting() async throws {
    let fixture = try Task20Fixture()
    defer { fixture.remove() }
    let store = try EvidenceStore(configuration: fixture.storeConfiguration)
    let historyStore = BlockingHistoryStore(backing: store)
    let coordinator = QuickScanCoordinator(
        store: store,
        historyStore: historyStore,
        catalog: try task20Catalog(),
        activityProvider: FixtureQuickScanActivityProvider(),
        volumeSampler: Task20VolumeSampler()
    )
    let history = Task {
        try await coordinator.loadHistory()
    }
    try await historyStore.waitUntilBlocked()

    let start = Task {
        try await coordinator.start(
            ScanRequest(rootURL: fixture.targetURL)
        )
    }
    try await Task.sleep(for: .milliseconds(25))
    #expect(await coordinator.hasActiveScan == false)

    await historyStore.release()
    _ = try await history.value
    let stream = try await start.value
    #expect(await coordinator.hasActiveScan)
    await coordinator.cancel()
    _ = try await collectProductEvents(stream)
    #expect(await coordinator.hasActiveScan == false)
}

@Test
func quickScanImmediateCancellationIsNotLost() async throws {
    let fixture = try Task20Fixture(extraFileCount: 40)
    defer { fixture.remove() }
    let store = try EvidenceStore(configuration: fixture.storeConfiguration)
    let coordinator = QuickScanCoordinator(
        store: store,
        catalog: try task20Catalog(),
        activityProvider: FixtureQuickScanActivityProvider(),
        volumeSampler: Task20VolumeSampler(),
        now: Task20DateSource().now,
        snapshotID: task20SnapshotID,
        classificationID: task20ClassificationID
    )
    let request = ScanRequest(
        rootURL: fixture.targetURL,
        maximumWorkers: 1,
        sessionID: try ScanSessionID(
            validating: "scan-task20-immediate-cancel"
        ),
        scopeID: try ScanScopeID(
            validating: "scope-task20-immediate-cancel"
        ),
        testHooks: SurveyorTestHooks(
            beforeDirectoryRead: { _ in usleep(2_000) }
        )
    )
    let stream = try await coordinator.start(request)

    await coordinator.cancel()
    let projection = try #require(
        try await collectProductEvents(stream).compactMap(\.terminal).last
    )

    #expect(projection.session.terminalState == .cancelled)
    #expect(
        try await store.scanSession(id: request.sessionID)?
            .terminalState == .cancelled
    )
}

@Test
func quickScanCancellationDuringActivityCannotPersistCompleted() async throws {
    let fixture = try Task20Fixture()
    defer { fixture.remove() }
    let store = try EvidenceStore(configuration: fixture.storeConfiguration)
    let activity = BlockingQuickScanActivityProvider()
    let coordinator = QuickScanCoordinator(
        store: store,
        catalog: try task20Catalog(),
        activityProvider: activity,
        volumeSampler: Task20VolumeSampler(),
        now: Task20DateSource().now,
        snapshotID: task20SnapshotID,
        classificationID: task20ClassificationID
    )
    let request = ScanRequest(
        rootURL: fixture.targetURL,
        maximumWorkers: 1,
        sessionID: try ScanSessionID(
            validating: "scan-task20-activity-cancel"
        ),
        scopeID: try ScanScopeID(
            validating: "scope-task20-activity-cancel"
        )
    )
    let collector = Task {
        try await collectProductEvents(
            try await coordinator.start(request)
        )
    }
    try await activity.waitUntilCalled()

    await coordinator.cancel()
    await activity.release()
    let events = try await collector.value
    let projection = try #require(events.compactMap(\.terminal).last)

    #expect(projection.session.terminalState == .cancelled)
    #expect(projection.ledger == nil)
    #expect(
        try await store.scanSession(id: request.sessionID)?
            .terminalState == .cancelled
    )
    #expect(
        try await store.spaceLedger(sessionID: request.sessionID) == nil
    )
}

@Test
func quickScanCancellationBeforeFinalizationCommitPersistsCancelled()
    async throws
{
    let fixture = try Task20Fixture()
    defer { fixture.remove() }
    let backing = try EvidenceStore(configuration: fixture.storeConfiguration)
    let store = BlockingCommitProductStore(
        backing: backing,
        blockPoint: .volumeBaselineLoad
    )
    let coordinator = QuickScanCoordinator(
        store: store,
        catalog: try task20Catalog(),
        activityProvider: FixtureQuickScanActivityProvider(),
        volumeSampler: Task20VolumeSampler(),
        now: Task20DateSource().now,
        snapshotID: task20SnapshotID,
        classificationID: task20ClassificationID
    )
    let request = ScanRequest(
        rootURL: fixture.targetURL,
        maximumWorkers: 1,
        sessionID: try ScanSessionID(
            validating: "scan-task20-prefinalization-cancel"
        ),
        scopeID: try ScanScopeID(
            validating: "scope-task20-prefinalization-cancel"
        )
    )
    let collector = Task {
        try await collectProductEvents(
            try await coordinator.start(request)
        )
    }
    try await store.waitUntilBlockedSaveStarts()

    let cancellationAccepted = await coordinator.cancel()
    await store.releaseBlockedSave()
    let events = try await collector.value
    let projection = try #require(events.compactMap(\.terminal).last)

    #expect(cancellationAccepted)
    #expect(projection.session.terminalState == .cancelled)
    #expect(projection.ledger == nil)
    #expect(
        try await backing.scanSession(id: request.sessionID)?
            .terminalState == .cancelled
    )
    let reopened = QuickScanCoordinator(
        store: backing,
        catalog: try task20Catalog(),
        activityProvider: FixtureQuickScanActivityProvider(),
        volumeSampler: Task20VolumeSampler()
    )
    let loaded = try await reopened.loadLatest()
    #expect(loaded?.session.terminalState == .cancelled)
    #expect(loaded?.ledger == nil)
}

@Test
func quickScanCancellationAfterFinalizationCommitIsRejected() async throws {
    let fixture = try Task20Fixture()
    defer { fixture.remove() }
    let backing = try EvidenceStore(configuration: fixture.storeConfiguration)
    let store = BlockingCommitProductStore(
        backing: backing,
        blockPoint: .finalSessionSave
    )
    let coordinator = QuickScanCoordinator(
        store: store,
        catalog: try task20Catalog(),
        activityProvider: FixtureQuickScanActivityProvider(),
        volumeSampler: Task20VolumeSampler(),
        now: Task20DateSource().now,
        snapshotID: task20SnapshotID,
        classificationID: task20ClassificationID
    )
    let request = ScanRequest(
        rootURL: fixture.targetURL,
        maximumWorkers: 1,
        sessionID: try ScanSessionID(
            validating: "scan-task20-postfinalization-cancel"
        ),
        scopeID: try ScanScopeID(
            validating: "scope-task20-postfinalization-cancel"
        )
    )
    let collector = Task {
        try await collectProductEvents(
            try await coordinator.start(request)
        )
    }
    try await store.waitUntilBlockedSaveStarts()

    let cancellationAccepted = await coordinator.cancel()
    await store.releaseBlockedSave()
    let events = try await collector.value
    let projection = try #require(events.compactMap(\.terminal).last)

    #expect(cancellationAccepted == false)
    #expect(projection.session.terminalState == .completed)
    #expect(projection.ledger != nil)
    #expect(
        try await backing.scanSession(id: request.sessionID)?
            .terminalState == .completed
    )
}

@Test
func quickScanProductBackpressureNeverLeavesFalseSuccess() async throws {
    let fixture = try Task20Fixture(extraFileCount: 32)
    defer { fixture.remove() }
    let store = try EvidenceStore(configuration: fixture.storeConfiguration)
    let coordinator = QuickScanCoordinator(
        store: store,
        catalog: try task20Catalog(),
        activityProvider: FixtureQuickScanActivityProvider(),
        volumeSampler: Task20VolumeSampler(),
        now: Task20DateSource().now,
        snapshotID: task20SnapshotID,
        classificationID: task20ClassificationID
    )
    let request = ScanRequest(
        rootURL: fixture.targetURL,
        maximumWorkers: 1,
        lifecycleEventBufferCapacity: 1,
        sessionID: try ScanSessionID(
            validating: "scan-task20-backpressure"
        ),
        scopeID: try ScanScopeID(
            validating: "scope-task20-backpressure"
        )
    )
    let stream = try await coordinator.start(request)
    try await waitForInactiveCoordinator(coordinator)

    await #expect(
        throws: QuickScanProductError.eventBufferExceeded(limit: 1)
    ) {
        _ = try await collectProductEvents(stream)
    }
    #expect(
        try await store.scanSession(id: request.sessionID)?
            .terminalState != .completed
    )
}

@Test
func quickScanRestartLoadsLatestHealthyProjection() async throws {
    let fixture = try Task20Fixture()
    defer { fixture.remove() }
    let firstStore = try EvidenceStore(
        configuration: fixture.storeConfiguration
    )
    let first = QuickScanCoordinator(
        store: firstStore,
        catalog: try task20Catalog(),
        activityProvider: FixtureQuickScanActivityProvider(),
        volumeSampler: Task20VolumeSampler(),
        now: Task20DateSource().now,
        snapshotID: task20SnapshotID,
        classificationID: task20ClassificationID
    )
    let request = ScanRequest(
        rootURL: fixture.targetURL,
        maximumWorkers: 1,
        sessionID: try ScanSessionID(validating: "scan-task20-restart"),
        scopeID: try ScanScopeID(validating: "scope-task20-restart")
    )
    let terminal = try #require(
        try await collectProductEvents(
            try await first.start(request)
        ).compactMap(\.terminal).last
    )

    let reopenedStore = try EvidenceStore(
        configuration: fixture.storeConfiguration
    )
    let reopened = QuickScanCoordinator(
        store: reopenedStore,
        catalog: try task20Catalog(),
        activityProvider: FixtureQuickScanActivityProvider(),
        volumeSampler: Task20VolumeSampler(),
        now: Task20DateSource().now,
        snapshotID: task20SnapshotID,
        classificationID: task20ClassificationID
    )
    let loaded = try await reopened.loadLatest()

    #expect(loaded == terminal)
    #expect(loaded?.session.id == request.sessionID)
    #expect(loaded?.ledger != nil)
    #expect(!loaded!.snapshots.isEmpty)
    #expect(loaded?.evidence == terminal.evidence)
}

@Test
func quickScanRestartSkipsCorruptNewerSessionWithoutPollutingHealthyState()
    async throws
{
    let fixture = try Task20Fixture()
    defer { fixture.remove() }
    let store = try EvidenceStore(configuration: fixture.storeConfiguration)
    let coordinator = QuickScanCoordinator(
        store: store,
        catalog: try task20Catalog(),
        activityProvider: FixtureQuickScanActivityProvider(),
        volumeSampler: Task20VolumeSampler(),
        now: Task20DateSource().now,
        snapshotID: task20SnapshotID,
        classificationID: task20ClassificationID
    )
    let request = ScanRequest(
        rootURL: fixture.targetURL,
        maximumWorkers: 1,
        sessionID: try ScanSessionID(
            validating: "scan-task20-healthy-restart"
        ),
        scopeID: try ScanScopeID(
            validating: "scope-task20-healthy-restart"
        )
    )
    _ = try await collectProductEvents(
        try await coordinator.start(request)
    )
    try await store._testInsertMalformedScanSession(
        id: "scan-task20-corrupt-newer",
        payload: "{not-json"
    )

    let loaded = try await coordinator.loadLatest()

    #expect(loaded?.session.id == request.sessionID)
    #expect(loaded?.session.terminalState == .completed)
    #expect(loaded?.corruptRecordIDs.isEmpty == true)
    #expect(loaded?.issues.isEmpty == true)
    #expect(loaded?.ledger != nil)
}

@Test
func quickScanOutputIsReproducibleWithInjectedClockAndIdentity() async throws {
    let fixture = try Task20Fixture()
    defer { fixture.remove() }
    let request = ScanRequest(
        rootURL: fixture.targetURL,
        maximumWorkers: 1,
        sessionID: try ScanSessionID(validating: "scan-task20-deterministic"),
        scopeID: try ScanScopeID(validating: "scope-task20-deterministic")
    )

    let first = try await deterministicProjection(
        request: request,
        store: EvidenceStore(configuration: .memory)
    )
    let second = try await deterministicProjection(
        request: request,
        store: EvidenceStore(configuration: .memory)
    )

    #expect(first == second)
    #expect(
        try DomainJSON.encode(first)
            == DomainJSON.encode(second)
    )
}

private func deterministicProjection(
    request: ScanRequest,
    store: EvidenceStore
) async throws -> QuickScanProjection {
    let coordinator = QuickScanCoordinator(
        store: store,
        catalog: try task20Catalog(),
        activityProvider: FixtureQuickScanActivityProvider(),
        volumeSampler: Task20VolumeSampler(),
        now: Task20DateSource().now,
        snapshotID: task20SnapshotID,
        classificationID: task20ClassificationID,
        evidenceID: task20EvidenceID
    )
    return try #require(
        try await collectProductEvents(
            try await coordinator.start(request)
        ).compactMap(\.terminal).last
    )
}

private struct FixtureQuickScanActivityProvider:
    QuickScanActivityProviding
{
    func observations(
        for snapshot: PathSnapshot,
        rule: CompiledRule,
        rootURL: URL,
        observedAt: Date
    ) async throws -> [ActivityObservation] {
        rule.requiredActivityKeys.map { key in
            let activityKey = try! ActivityKey(
                validating: key.rawValue
            )
            let isDirtyProject = snapshot.relativePath
                == "projects/sample/derived"
                && activityKey == .gitClean
            return try! ActivityObservation(
                key: activityKey,
                state: isDirtyProject ? .contradicted : .satisfied,
                source: activityKey == .processInactive
                    ? .runningProcess
                    : .git,
                origin: .external,
                observedAt: observedAt,
                reason: try! DomainToken(
                    validating: isDirtyProject
                        ? "activity.fixture.dirty"
                        : "activity.fixture.satisfied"
                )
            )
        }
    }
}

private actor Task20GitActivityCollector:
    QuickScanGitActivityCollecting
{
    private(set) var callCount = 0
    private(set) var lastRepositoryURL: URL?
    private let observedAt: Date

    init(observedAt: Date) {
        self.observedAt = observedAt
    }

    func collect(
        repositoryURL: URL,
        observedAt: Date
    ) async -> GitActivitySnapshot {
        callCount += 1
        lastRepositoryURL = repositoryURL
        let observations = [
            try! ActivityObservation(
                key: .gitClean,
                state: .satisfied,
                source: .git,
                origin: .external,
                observedAt: self.observedAt,
                reason: DomainToken(rawValue: "activity.git.clean")!
            ),
            try! ActivityObservation(
                key: .gitUpstreamSynchronized,
                state: .satisfied,
                source: .git,
                origin: .external,
                observedAt: self.observedAt,
                reason: DomainToken(
                    rawValue: "activity.git.upstream-synced"
                )!
            ),
        ]
        return GitActivitySnapshot(
            status: .available,
            hasStagedChanges: false,
            hasModifiedFiles: false,
            hasUntrackedFiles: false,
            branch: DomainLabel(rawValue: "main"),
            upstream: DomainLabel(rawValue: "origin/main"),
            aheadCount: 0,
            behindCount: 0,
            lastCommitAt: nil,
            lastCommitStatus: .available,
            observations: observations,
            timestamps: []
        )
    }
}

private struct FailingQuickScanActivityProvider:
    QuickScanActivityProviding
{
    func observations(
        for snapshot: PathSnapshot,
        rule: CompiledRule,
        rootURL: URL,
        observedAt: Date
    ) async throws -> [ActivityObservation] {
        throw Task20TestError.activityUnavailable
    }
}

private actor BlockingQuickScanActivityProvider:
    QuickScanActivityProviding
{
    private var called = false
    private var released = false

    func observations(
        for snapshot: PathSnapshot,
        rule: CompiledRule,
        rootURL: URL,
        observedAt: Date
    ) async throws -> [ActivityObservation] {
        called = true
        while !released {
            try await Task.sleep(for: .milliseconds(10))
        }
        return try rule.requiredActivityKeys.map {
            try ActivityObservation(
                key: ActivityKey(validating: $0.rawValue),
                state: .satisfied,
                source: $0.rawValue == ActivityKey.processInactive.rawValue
                    ? .runningProcess
                    : .git,
                origin: .external,
                observedAt: observedAt,
                reason: DomainToken(
                    rawValue: "activity.fixture.satisfied"
                )!
            )
        }
    }

    func waitUntilCalled() async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        while !called {
            guard clock.now < deadline else {
                throw Task20TestError.timedOut
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    func release() {
        released = true
    }
}

private actor FailingClassificationProductStore:
    QuickScanProductPersisting
{
    let backing: EvidenceStore

    init(backing: EvidenceStore) {
        self.backing = backing
    }

    func beginScanSession(_ session: ScanSession) async throws {
        try await backing.beginScanSession(session)
    }

    func saveScanSession(_ session: ScanSession) async throws {
        try await backing.saveScanSession(session)
    }

    func savePathSnapshots(_ snapshots: [PathSnapshot]) async throws {
        try await backing.savePathSnapshots(snapshots)
    }

    func saveVolumeBaseline(_ baseline: VolumeBaseline) async throws {
        try await backing.saveVolumeBaseline(baseline)
    }

    func scanSession(id: ScanSessionID) async throws -> ScanSession? {
        try await backing.scanSession(id: id)
    }

    func scanSessions(
        limit: Int,
        offset: Int
    ) async throws -> StorePage<ScanSession> {
        try await backing.scanSessions(limit: limit, offset: offset)
    }

    func pathSnapshots(
        sessionID: ScanSessionID,
        limit: Int,
        offset: Int
    ) async throws -> StorePage<PathSnapshot> {
        try await backing.pathSnapshots(
            sessionID: sessionID,
            limit: limit,
            offset: offset
        )
    }

    func saveClassifications(
        _ classifications: [Classification]
    ) async throws {
        throw Task20TestError.classificationStoreFailed
    }

    func classifications(
        sessionID: ScanSessionID,
        limit: Int,
        offset: Int,
        disposition: ReclaimDisposition?
    ) async throws -> StorePage<Classification> {
        try await backing.classifications(
            sessionID: sessionID,
            limit: limit,
            offset: offset,
            disposition: disposition
        )
    }

    func saveEvidence(_ evidence: [EvidenceRecord]) async throws {
        try await backing.saveEvidence(evidence)
    }

    func evidence(
        sessionID: ScanSessionID,
        limit: Int,
        offset: Int
    ) async throws -> StorePage<EvidenceRecord> {
        try await backing.evidence(
            sessionID: sessionID,
            limit: limit,
            offset: offset
        )
    }

    func saveSpaceLedger(_ ledger: SpaceLedger) async throws {
        try await backing.saveSpaceLedger(ledger)
    }

    func volumeBaseline(
        sessionID: ScanSessionID,
        scopeID: ScanScopeID
    ) async throws -> VolumeBaseline? {
        return try await backing.volumeBaseline(
            sessionID: sessionID,
            scopeID: scopeID
        )
    }

    func spaceLedger(
        sessionID: ScanSessionID
    ) async throws -> SpaceLedger? {
        try await backing.spaceLedger(sessionID: sessionID)
    }
}

private actor BlockingCommitProductStore:
    QuickScanProductPersisting
{
    enum BlockPoint {
        case volumeBaselineLoad
        case finalSessionSave
        case failingFinalSessionSave
    }

    let backing: EvidenceStore
    private let blockPoint: BlockPoint
    private var blockedSaveStarted = false
    private var blockedSaveReleased = false

    init(
        backing: EvidenceStore,
        blockPoint: BlockPoint
    ) {
        self.backing = backing
        self.blockPoint = blockPoint
    }

    func beginScanSession(_ session: ScanSession) async throws {
        try await backing.beginScanSession(session)
    }

    func saveScanSession(_ session: ScanSession) async throws {
        if blockPoint == .finalSessionSave,
           session.terminalState == .completed
        {
            try await blockCurrentSave()
        }
        if blockPoint == .failingFinalSessionSave,
           session.terminalState == .completed
        {
            throw Task20TestError.finalSessionStoreFailed
        }
        try await backing.saveScanSession(session)
    }

    func savePathSnapshots(_ snapshots: [PathSnapshot]) async throws {
        try await backing.savePathSnapshots(snapshots)
    }

    func saveVolumeBaseline(_ baseline: VolumeBaseline) async throws {
        try await backing.saveVolumeBaseline(baseline)
    }

    func scanSession(id: ScanSessionID) async throws -> ScanSession? {
        try await backing.scanSession(id: id)
    }

    func scanSessions(
        limit: Int,
        offset: Int
    ) async throws -> StorePage<ScanSession> {
        try await backing.scanSessions(limit: limit, offset: offset)
    }

    func pathSnapshots(
        sessionID: ScanSessionID,
        limit: Int,
        offset: Int
    ) async throws -> StorePage<PathSnapshot> {
        try await backing.pathSnapshots(
            sessionID: sessionID,
            limit: limit,
            offset: offset
        )
    }

    func saveClassifications(
        _ classifications: [Classification]
    ) async throws {
        try await backing.saveClassifications(classifications)
    }

    func classifications(
        sessionID: ScanSessionID,
        limit: Int,
        offset: Int,
        disposition: ReclaimDisposition?
    ) async throws -> StorePage<Classification> {
        try await backing.classifications(
            sessionID: sessionID,
            limit: limit,
            offset: offset,
            disposition: disposition
        )
    }

    func saveEvidence(_ evidence: [EvidenceRecord]) async throws {
        try await backing.saveEvidence(evidence)
    }

    func evidence(
        sessionID: ScanSessionID,
        limit: Int,
        offset: Int
    ) async throws -> StorePage<EvidenceRecord> {
        try await backing.evidence(
            sessionID: sessionID,
            limit: limit,
            offset: offset
        )
    }

    func saveSpaceLedger(_ ledger: SpaceLedger) async throws {
        try await backing.saveSpaceLedger(ledger)
    }

    func volumeBaseline(
        sessionID: ScanSessionID,
        scopeID: ScanScopeID
    ) async throws -> VolumeBaseline? {
        if blockPoint == .volumeBaselineLoad {
            try await blockCurrentSave()
        }
        return try await backing.volumeBaseline(
            sessionID: sessionID,
            scopeID: scopeID
        )
    }

    func spaceLedger(
        sessionID: ScanSessionID
    ) async throws -> SpaceLedger? {
        try await backing.spaceLedger(sessionID: sessionID)
    }

    func waitUntilBlockedSaveStarts() async throws {
        let deadline = ContinuousClock().now.advanced(by: .seconds(5))
        while !blockedSaveStarted {
            guard ContinuousClock().now < deadline else {
                throw Task20TestError.timedOut
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    func releaseBlockedSave() {
        blockedSaveReleased = true
    }

    private func blockCurrentSave() async throws {
        blockedSaveStarted = true
        while !blockedSaveReleased {
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}

private actor BlockingHistoryStore: QuickScanHistoryPersisting {
    private let backing: EvidenceStore
    private var blocked = false
    private var released = false

    init(backing: EvidenceStore) {
        self.backing = backing
    }

    func expireRecords(now: Date) async throws {
        blocked = true
        while !released {
            await Task.yield()
        }
        try await backing.expireRecords(now: now)
    }

    func recordCounts() async throws -> EvidenceRecordCounts {
        try await backing.recordCounts()
    }

    func clearEvidence() async throws {
        try await backing.clearEvidence()
    }

    func clearManifests() async throws {
        try await backing.clearManifests()
    }

    func scanHistory(
        limit: Int,
        offset: Int
    ) async throws -> ScanHistoryPage {
        try await backing.scanHistory(limit: limit, offset: offset)
    }

    func deleteScanSession(id: ScanSessionID) async throws {
        try await backing.deleteScanSession(id: id)
    }

    func waitUntilBlocked() async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        while !blocked {
            guard clock.now < deadline else {
                throw Task20TestError.timedOut
            }
            await Task.yield()
        }
    }

    func release() {
        released = true
    }
}

private func task20Catalog() throws -> RuleCatalog {
    try DomainJSON.decode(
        RuleCatalog.self,
        from: Data(
            contentsOf: EvidenceStoreTestSupport.repositoryRoot.appending(
                path: "Tests/Fixtures/QuickScan/task20-compiled-catalog.json"
            )
        )
    )
}

private func collectProductEvents(
    _ stream: AsyncThrowingStream<QuickScanProductEvent, Error>
) async throws -> [QuickScanProductEvent] {
    var events: [QuickScanProductEvent] = []
    for try await event in stream {
        events.append(event)
    }
    return events
}

private func classification(
    at relativePath: String,
    in projection: QuickScanProjection
) -> Classification? {
    guard let snapshot = projection.snapshots.first(where: {
        $0.relativePath == relativePath
    }) else {
        return nil
    }
    return projection.classifications.first {
        $0.snapshotID == snapshot.id
    }
}

private func task20SnapshotID(_ relativePath: String) -> SnapshotID {
    try! SnapshotID(
        validating: "snapshot-task20-\(stableFixtureToken(relativePath))"
    )
}

private func task20BoundaryCompatibleSnapshot(
    relativePath: String
) throws -> PathSnapshot {
    let identity = try FileIdentity(
        device: 1,
        inode: 2,
        mode: UInt16(S_IFDIR | 0o755),
        ownerUserID: getuid(),
        ownerGroupID: getgid(),
        size: 0,
        allocatedBytes: 0,
        modificationSeconds: 1,
        modificationNanoseconds: 0
    )
    return try PathSnapshot(
        id: task20SnapshotID(relativePath),
        sessionID: ScanSessionID(rawValue: "scan-task20-git-snapshot")!,
        scopeID: ScanScopeID(rawValue: "scope-task20-git-snapshot")!,
        relativePath: relativePath,
        kind: .directory,
        logicalByteCount: ByteCount(0),
        allocatedByteCount: ByteCount(0),
        modifiedAt: Date(timeIntervalSince1970: 1),
        fileIdentity: identity,
        symlinkTarget: nil,
        measurementStatus: .measured,
        observedAt: Date(timeIntervalSince1970: 1)
    )
}

private func task20ClassificationID(
    _ snapshotID: SnapshotID
) -> ClassificationID {
    try! ClassificationID(
        validating: "classification-\(snapshotID.rawValue)"
    )
}

private func task20EvidenceID(
    _ snapshotID: SnapshotID,
    _ observation: ActivityObservation
) -> EvidenceID {
    let token = stableFixtureToken(
        "\(snapshotID.rawValue)|\(observation.key.rawValue)"
    )
    return try! EvidenceID(
        validating: "evidence-task20-\(token)"
    )
}

private func stableFixtureToken(_ value: String) -> String {
    SHA256.hash(data: Data(value.utf8))
        .prefix(8)
        .map { String(format: "%02x", $0) }
        .joined()
}

private func waitForActiveCoordinator(
    _ coordinator: QuickScanCoordinator
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(5))
    while await coordinator.hasActiveScan == false {
        guard clock.now < deadline else {
            throw Task20TestError.timedOut
        }
        try await Task.sleep(for: .milliseconds(10))
    }
}

private func waitForInactiveCoordinator(
    _ coordinator: QuickScanCoordinator
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(5))
    while await coordinator.hasActiveScan {
        guard clock.now < deadline else {
            throw Task20TestError.timedOut
        }
        try await Task.sleep(for: .milliseconds(10))
    }
}

private func waitForPersistedSnapshots(
    _ store: EvidenceStore,
    sessionID: ScanSessionID
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(5))
    while clock.now < deadline {
        if try await !store.pathSnapshots(
            sessionID: sessionID,
            limit: 1,
            offset: 0
        ).records.isEmpty {
            return
        }
        try await Task.sleep(for: .milliseconds(10))
    }
    throw Task20TestError.timedOut
}

private final class Task20DateSource: @unchecked Sendable {
    private let lock = NSLock()
    private var milliseconds: TimeInterval = 1_786_320_000

    func now() -> Date {
        lock.withLock {
            milliseconds += 0.001
            return Date(timeIntervalSince1970: milliseconds)
        }
    }
}

private final class Task20VolumeSampler:
    VolumeBaselineSampling,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var sampleCount = 0

    func sample(
        request: ScanRequest,
        sampledAt: Date
    ) throws -> VolumeBaseline {
        var information = stat()
        guard lstat(request.rootURL.path, &information) == 0 else {
            throw Task20TestError.invalidFixture
        }
        let available = lock.withLock {
            sampleCount += 1
            return sampleCount == 1 ? UInt64(600_000) : 590_000
        }
        return try VolumeBaseline(
            sessionID: request.sessionID,
            scopeID: request.scopeID,
            rootPath: PersistedPath(
                validating: request.rootURL.path
            ),
            rootIdentity: FileIdentity(
                device: UInt64(bitPattern: Int64(information.st_dev)),
                inode: UInt64(information.st_ino),
                mode: UInt16(information.st_mode),
                ownerUserID: information.st_uid,
                ownerGroupID: information.st_gid,
                size: Int64(information.st_size),
                allocatedBytes: Int64(information.st_blocks) * 512,
                modificationSeconds: Int64(
                    information.st_mtimespec.tv_sec
                ),
                modificationNanoseconds: Int64(
                    information.st_mtimespec.tv_nsec
                )
            ),
            totalCapacity: ByteCount(1_000_000),
            availableCapacity: ByteCount(available),
            availableCapacityForImportantUsage: nil,
            availableCapacityForOpportunisticUsage: nil,
            volumeIsReadOnly: false,
            source: AccountingSource(
                kind: .volumeResourceValues,
                identifier: try DomainToken(
                    validating: "fixture.task20-volume"
                ),
                sampledAt: sampledAt
            )
        )
    }
}

private final class FailingEndVolumeSampler:
    VolumeBaselineSampling,
    @unchecked Sendable
{
    private let lock = NSLock()
    private let initialSampler = Task20VolumeSampler()
    private var sampleCount = 0

    func sample(
        request: ScanRequest,
        sampledAt: Date
    ) throws -> VolumeBaseline {
        let isInitialSample = lock.withLock {
            sampleCount += 1
            return sampleCount == 1
        }
        guard isInitialSample else {
            throw Task20TestError.endBaselineUnavailable
        }
        return try initialSampler.sample(
            request: request,
            sampledAt: sampledAt
        )
    }
}

private struct Task20Fixture {
    let rootURL: URL
    let targetURL: URL
    let storeRootURL: URL
    let storeConfiguration: LocalStoreConfiguration
    let codexMarkerURL: URL

    init(extraFileCount: Int = 0) throws {
        rootURL = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-task20-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        targetURL = rootURL.appending(
            path: "target",
            directoryHint: .isDirectory
        )
        storeRootURL = rootURL.appending(
            path: "owned-store",
            directoryHint: .isDirectory
        )
        codexMarkerURL = rootURL.appending(path: "codex-was-launched")
        try FileManager.default.createDirectory(
            at: targetURL,
            withIntermediateDirectories: true
        )
        for relativePath in [
            ".fixture-cache/cache.bin",
            "projects/sample/derived/output.bin",
            "projects/sample/.ssh/id_fixture",
            "mystery/blob.bin",
        ] {
            let url = targetURL.appending(path: relativePath)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data("task20-\(relativePath)".utf8).write(to: url)
        }
        for index in 0..<extraFileCount {
            let url = targetURL.appending(
                path: "bulk/\(index)/nested/value.bin"
            )
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data(repeating: UInt8(index % 251), count: 64)
                .write(to: url)
        }
        try FileManager.default.createDirectory(
            at: storeRootURL,
            withIntermediateDirectories: true
        )
        storeConfiguration = try LocalStoreConfiguration(
            applicationSupportBaseURL: storeRootURL.appending(
                path: "Application Support"
            ),
            cachesBaseURL: storeRootURL.appending(path: "Caches")
        )
        let fakeCodex = targetURL.appending(path: "codex")
        try Data(
            "#!/bin/sh\nprintf launched > '\(codexMarkerURL.path)'\n".utf8
        ).write(to: fakeCodex)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: fakeCodex.path
        )
    }

    func remove() {
        makeTargetWritable()
        try? FileManager.default.removeItem(at: rootURL)
    }

    func makeTargetReadOnly() throws {
        for url in try targetEntriesDeepestFirst() {
            let isDirectory = try url.resourceValues(
                forKeys: [.isDirectoryKey]
            ).isDirectory == true
            try FileManager.default.setAttributes(
                [.posixPermissions: isDirectory ? 0o555 : 0o444],
                ofItemAtPath: url.path
            )
        }
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o555],
            ofItemAtPath: targetURL.path
        )
    }

    private func makeTargetWritable() {
        guard let entries = try? targetEntriesDeepestFirst() else {
            return
        }
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: targetURL.path
        )
        for url in entries {
            let isDirectory = try? url.resourceValues(
                forKeys: [.isDirectoryKey]
            ).isDirectory
            try? FileManager.default.setAttributes(
                [.posixPermissions: isDirectory == true ? 0o700 : 0o600],
                ofItemAtPath: url.path
            )
        }
    }

    private func targetEntriesDeepestFirst() throws -> [URL] {
        let enumerator = try #require(
            FileManager.default.enumerator(
                at: targetURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            )
        )
        return enumerator.compactMap { $0 as? URL }.sorted {
            $0.pathComponents.count > $1.pathComponents.count
        }
    }
}

private struct AuditedTreeEntry: Equatable {
    let identity: FileIdentity
    let contentHash: String?
}

private func auditedTree(
    at root: URL
) throws -> [String: AuditedTreeEntry] {
    let enumerator = try #require(
        FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: []
        )
    )
    var result: [String: AuditedTreeEntry] = [
        ".": AuditedTreeEntry(
            identity: try #require(FileIdentity.read(at: root)),
            contentHash: nil
        ),
    ]
    for case let url as URL in enumerator {
        let relativePath = String(
            url.path.dropFirst(root.path.count + 1)
        )
        let values = try url.resourceValues(
            forKeys: [.isRegularFileKey]
        )
        let digest = values.isRegularFile == true
            ? SHA256.hash(data: try Data(contentsOf: url))
                .map { String(format: "%02x", $0) }
                .joined()
            : nil
        result[relativePath] = AuditedTreeEntry(
            identity: try #require(FileIdentity.read(at: url)),
            contentHash: digest
        )
    }
    return result
}

private extension QuickScanProductEvent {
    var stage: QuickScanStage? {
        guard case let .stageChanged(value) = self else {
            return nil
        }
        return value
    }

    var classification: Classification? {
        guard case let .classifiedSnapshotObserved(_, value) = self else {
            return nil
        }
        return value
    }

    var classifiedPair: (SnapshotID, Classification)? {
        guard case let .classifiedSnapshotObserved(snapshot, classification)
            = self,
              snapshot.id == classification.snapshotID
        else {
            return nil
        }
        return (snapshot.id, classification)
    }

    var ledger: SpaceLedger? {
        guard case let .ledgerUpdated(value) = self else {
            return nil
        }
        return value
    }

    var terminal: QuickScanProjection? {
        guard case let .terminal(value) = self else {
            return nil
        }
        return value
    }
}

private enum Task20TestError: Error {
    case activityUnavailable
    case classificationStoreFailed
    case endBaselineUnavailable
    case finalSessionStoreFailed
    case invalidFixture
    case timedOut
}
