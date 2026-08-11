import Foundation
import Testing
@testable import StornautCore

@Test
func evidenceStoreRoundTripsEveryTypedRepository() async throws {
    let store = try EvidenceStore(configuration: .memory)
    let session: ScanSession = try EvidenceStoreTestSupport.fixture(
        ScanSession.self,
        name: "scan-session-v1"
    )
    let developerTree = try DomainJSON.decode(
        StoredDeveloperTreeFixture.self,
        from: EvidenceStoreTestSupport.fixtureData(
            directory: "QuickScan",
            name: "anonymous-developer-tree"
        )
    )
    let plan = try CleanupPersistenceTestSupport.plan()
    let decision = try CleanupPersistenceTestSupport.decision(
        plan: plan,
        item: plan.items[0]
    )
    let manifest = try CleanupPersistenceTestSupport.manifest(plan: plan)

    try await store.saveScanSession(session)
    try await store.saveScanSession(developerTree.session)
    try await store.savePathSnapshots(developerTree.snapshots)
    try await store.saveClassifications(developerTree.classifications)
    try await store.saveEvidence(developerTree.evidence)
    try await store.saveSpaceAccounting(developerTree.accounting)
    try await store.saveCleanupPlan(plan)
    try await store.savePolicyDecision(decision)
    try await store.saveCleanupManifest(manifest)

    #expect(try await store.scanSession(id: session.id) == session)
    let storedSnapshots = try await store.pathSnapshots(
        sessionID: developerTree.session.id,
        limit: 20,
        offset: 0
    ).records
    #expect(
        storedSnapshots.map(\.relativePath)
            == developerTree.snapshots.map(\.relativePath).sorted()
    )
    #expect(Set(storedSnapshots.map(\.id)) == Set(developerTree.snapshots.map(\.id)))
    #expect(
        try await store.classifications(
            sessionID: developerTree.session.id,
            limit: 20,
            offset: 0
        ).records == developerTree.classifications
    )
    let protectedClassification = try #require(
        developerTree.classifications.first {
            $0.disposition == .protected
        }
    )
    try await store._testChangeClassificationDisposition(
        id: protectedClassification.id,
        disposition: .readyToReclaim
    )
    let corruptedFilterPage = try await store.classifications(
        sessionID: developerTree.session.id,
        limit: 20,
        offset: 0,
        disposition: .readyToReclaim
    )
    #expect(!corruptedFilterPage.records.contains(protectedClassification))
    #expect(
        corruptedFilterPage.corruptRecordIDs
            == [protectedClassification.id.rawValue]
    )
    #expect(
        try await store.evidence(
            sessionID: developerTree.session.id,
            limit: 20,
            offset: 0
        ).records
            == developerTree.evidence
    )
    #expect(
        try await store.spaceAccounting(sessionID: developerTree.session.id)
            == developerTree.accounting
    )
    #expect(try await store.cleanupPlan(id: plan.id) == plan)
    #expect(try await store.policyDecision(id: decision.id) == decision)
    #expect(try await store.cleanupManifest(id: manifest.id) == manifest)
}

@Test
func cascadeAndCancellationNeverLeaveFalseCompleteData() async throws {
    let store = try EvidenceStore(configuration: .memory)
    let tree = try DomainJSON.decode(
        StoredDeveloperTreeFixture.self,
        from: EvidenceStoreTestSupport.fixtureData(
            directory: "QuickScan",
            name: "anonymous-developer-tree"
        )
    )
    try await store.saveScanSession(tree.session)
    try await store.savePathSnapshots(tree.snapshots)

    try await store.deleteScanSession(id: tree.session.id)
    #expect(
        try await store.pathSnapshots(
            sessionID: tree.session.id,
            limit: 20,
            offset: 0
        ).records.isEmpty
    )

    try await store.saveScanSession(tree.session)
    let cancelled = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        try await store.savePathSnapshots(tree.snapshots)
    }
    await #expect(throws: CancellationError.self) {
        try await cancelled.value
    }
    #expect(
        try await store.pathSnapshots(
            sessionID: tree.session.id,
            limit: 20,
            offset: 0
        ).records.isEmpty
    )
}

@Test
func historyDeletionNeverTouchesTargetTrashOrLocalKnowledge() async throws {
    let root = try EvidenceStoreTestSupport.temporaryDirectory(
        "history-delete-audit"
    )
    defer { try? FileManager.default.removeItem(at: root) }
    let configuration = try EvidenceStoreTestSupport.makeFileConfiguration(
        root: root
    )
    let evidence = try EvidenceStore(configuration: configuration)
    let knowledge = try LocalKnowledgeStore(configuration: configuration)
    let record = try historyRecord(
        slug: "history-delete-audit",
        finishedAt: Date(timeIntervalSince1970: 1_786_320_200)
    )
    let target = root.appending(path: "target/value.txt")
    let trashMarker = root.appending(path: "trash-marker.txt")
    try FileManager.default.createDirectory(
        at: target.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try Data("target".utf8).write(to: target)
    try Data("trash".utf8).write(to: trashMarker)
    let fact = try LocalKnowledgeFact(
        id: LocalKnowledgeID(rawValue: "knowledge-history-delete-audit")!,
        payload: .keepDecision,
        binding: LocalKnowledgeBinding(
            scope: PersistedPath(rawValue: "/tmp/history-delete-audit")!,
            fileIdentity: try FileIdentity(
                device: 1,
                inode: 2,
                mode: UInt16(S_IFDIR | 0o755),
                ownerUserID: getuid(),
                ownerGroupID: getgid(),
                size: 0,
                allocatedBytes: 0,
                modificationSeconds: 1,
                modificationNanoseconds: 0
            ),
            activityFingerprint: DomainToken(
                rawValue: "activity.history-delete-audit"
            )!,
            catalogVersion: DomainToken(
                rawValue: "catalog-history-delete-audit"
            )!
        ),
        provenance: .userConfirmed,
        observedAt: record.session.finishedAt,
        updatedAt: record.session.finishedAt
    )
    try await evidence.saveScanSession(record.session)
    try await evidence.saveSpaceLedger(record.ledger)
    try await knowledge.save(fact)
    let targetBefore = try Data(contentsOf: target)
    let trashBefore = try Data(contentsOf: trashMarker)

    try await evidence.deleteScanSession(id: record.session.id)

    #expect(try await evidence.scanSession(id: record.session.id) == nil)
    #expect(try Data(contentsOf: target) == targetBefore)
    #expect(try Data(contentsOf: trashMarker) == trashBefore)
    #expect(try await knowledge.fact(id: fact.id) == fact)
}

@Test
func scanHistoryBatchesLedgersAndIsolatesCorruptPayloads() async throws {
    let store = try EvidenceStore(configuration: .memory)
    let first = try historyRecord(
        slug: "history-first",
        finishedAt: Date(timeIntervalSince1970: 1_786_320_100)
    )
    let second = try historyRecord(
        slug: "history-second",
        finishedAt: Date(timeIntervalSince1970: 1_786_320_200)
    )
    try await store.saveScanSession(first.session)
    try await store.saveSpaceLedger(first.ledger)
    try await store.saveScanSession(second.session)
    try await store.saveSpaceLedger(second.ledger)
    try await store._testCorruptSpaceLedger(
        sessionID: second.session.id,
        payload: "{not-json"
    )
    try await store._testInsertMalformedScanSession(
        id: "scan-history-corrupt",
        payload: "{not-json"
    )

    let page = try await store.scanHistory(limit: 10, offset: 0)

    #expect(page.sessions == [second.session, first.session])
    #expect(page.ledgersBySessionID == [
        first.session.id: first.ledger,
    ])
    #expect(page.corruptSessionIDs == ["scan-history-corrupt"])
    #expect(page.corruptLedgerSessionIDs == [second.session.id.rawValue])
    await #expect(throws: EvidenceStoreError.invalidPage) {
        _ = try await store.scanHistory(limit: 101, offset: 0)
    }
}

@Test
func coordinatorSweepsExpiredEvidenceBeforeHistoryOrLatestProjection()
    async throws
{
    let now = Date(timeIntervalSince1970: 1_786_449_600)
    let store = try EvidenceStore(configuration: .memory)
    let record = try historyRecord(
        slug: "history-expired-sweep",
        finishedAt: now.addingTimeInterval(-8 * 86_400)
    )
    try await store.saveScanSession(record.session)
    try await store.saveSpaceLedger(record.ledger)
    let coordinator = QuickScanCoordinator(
        store: store,
        historyStore: store,
        catalog: try BuiltInRuleCatalog.load(),
        now: { now }
    )

    let history = try await coordinator.loadHistory()

    #expect(history.sessions.isEmpty)
    #expect(
        try await store.scanSession(id: record.session.id) == nil
    )

    try await store.saveScanSession(record.session)
    try await store.saveSpaceLedger(record.ledger)

    #expect(try await coordinator.loadLatest() == nil)
    #expect(
        try await store.scanSession(id: record.session.id) == nil
    )
}

@Test
func malformedRecordIsIsolatedAndDatabaseCorruptionFailsClosed() async throws {
    let store = try EvidenceStore(configuration: .memory)
    let session: ScanSession = try EvidenceStoreTestSupport.fixture(
        ScanSession.self,
        name: "scan-session-v1"
    )
    try await store.saveScanSession(session)
    try await store._testInsertMalformedScanSession(
        id: "scan-malformed",
        payload: "{not-json"
    )
    let mismatchedID = "scan-mismatched-payload"
    try await store._testInsertMalformedScanSession(
        id: mismatchedID,
        payload: String(decoding: try DomainJSON.encode(session), as: UTF8.self)
    )

    let page = try await store.scanSessions(limit: 10, offset: 0)
    #expect(page.records == [session])
    #expect(Set(page.corruptRecordIDs) == ["scan-malformed", mismatchedID])
    let originalPayload = String(
        decoding: try DomainJSON.encode(session),
        as: UTF8.self
    )
    try await store._testReplaceScanSessionPayload(
        id: session.id.rawValue,
        payload: originalPayload.replacingOccurrences(
            of: session.id.rawValue,
            with: mismatchedID
        )
    )
    await #expect(throws: EvidenceStoreError.recordIdentityMismatch) {
        _ = try await store.scanSession(id: session.id)
    }

    let root = try EvidenceStoreTestSupport.temporaryDirectory("corrupt")
    defer { try? FileManager.default.removeItem(at: root) }
    let configuration = try EvidenceStoreTestSupport.makeFileConfiguration(
        root: root
    )
    try FileManager.default.createDirectory(
        at: configuration.supportDirectoryURL,
        withIntermediateDirectories: true
    )
    try Data("not-a-sqlite-database".utf8).write(
        to: configuration.evidenceDatabaseURL
    )
    #expect(throws: EvidenceStoreError.integrityCheckFailed) {
        _ = try EvidenceStore(configuration: configuration)
    }
}

@Test
func boundedPagingUsesIndexes() async throws {
    let store = try EvidenceStore(configuration: .memory)
    let session: ScanSession = try EvidenceStoreTestSupport.fixture(
        ScanSession.self,
        name: "scan-session-v1"
    )
    try await store.saveScanSession(session)
    let page = try await store.scanSessions(limit: 1, offset: 0)
    #expect(page.records.count == 1)
    await #expect(throws: EvidenceStoreError.invalidPage) {
        _ = try await store.scanSessions(limit: 0, offset: 0)
    }
    await #expect(throws: EvidenceStoreError.invalidPage) {
        _ = try await store.scanSessions(limit: 101, offset: 0)
    }
    await #expect(throws: EvidenceStoreError.invalidPage) {
        _ = try await store.classifications(
            sessionID: session.id,
            limit: 0,
            offset: 0
        )
    }
    #expect(
        try await store._testQueryPlan(.snapshotsBySession)
            .contains("idx_path_snapshots_session_relative")
    )
    #expect(
        try await store._testQueryPlan(.classificationsByDisposition)
            .contains("idx_classifications_disposition")
    )
    #expect(
        try await store._testQueryPlan(.sessionRetention)
            .contains("idx_scan_sessions_expiry")
    )
    #expect(
        try await store._testQueryPlan(.sessionHistory)
            .contains("idx_scan_sessions_finished")
    )
}

@Test
func storePayloadBoundsKeepLedgerAllowanceRoleSpecific() throws {
    let overGenericLimit = Data(
        repeating: 0x61,
        count: maximumStorePayloadBytes + 1
    )
    #expect(throws: EvidenceStoreError.payloadTooLarge(
        limit: maximumStorePayloadBytes
    )) {
        _ = try boundedStorePayloadString(overGenericLimit)
    }
    #expect(
        try boundedStorePayloadString(
            overGenericLimit,
            limit: maximumSpaceLedgerPayloadBytes
        ).utf8.count == overGenericLimit.count
    )
    let overLedgerLimit = Data(
        repeating: 0x61,
        count: maximumSpaceLedgerPayloadBytes + 1
    )
    #expect(throws: EvidenceStoreError.payloadTooLarge(
        limit: maximumSpaceLedgerPayloadBytes
    )) {
        _ = try boundedStorePayloadString(
            overLedgerLimit,
            limit: maximumSpaceLedgerPayloadBytes
        )
    }
}

@Test
func snapshotCursorPagingDoesNotSkipOrDuplicateRows() async throws {
    let fixture = try QuickScanStoreFixture(snapshotCount: 250)
    let store = try EvidenceStore(configuration: .memory)
    try await store.saveScanSession(fixture.session)
    try await store.savePathSnapshots(fixture.snapshots)
    var records: [PathSnapshot] = []
    var cursor: PathSnapshotCursor?

    while true {
        let page = try await store.pathSnapshots(
            sessionID: fixture.session.id,
            after: cursor,
            limit: 37
        )
        records.append(contentsOf: page.page.records)
        if page.rowCount < 37 {
            break
        }
        let next = try #require(page.nextCursor)
        #expect(next != cursor)
        cursor = next
    }

    #expect(records.map(\.id) == fixture.snapshots.sorted {
        $0.relativePath < $1.relativePath
    }.map(\.id))
    #expect(Set(records.map(\.id)).count == 250)
}

@Test
func onlineBackupExportsAConsistentPrivateSnapshot() async throws {
    let root = try EvidenceStoreTestSupport.temporaryDirectory("backup")
    defer { try? FileManager.default.removeItem(at: root) }
    let configuration = try EvidenceStoreTestSupport.makeFileConfiguration(
        root: root
    )
    let store = try EvidenceStore(configuration: configuration)
    let session: ScanSession = try EvidenceStoreTestSupport.fixture(
        ScanSession.self,
        name: "scan-session-v1"
    )
    try await store.saveScanSession(session)
    let exportURL = root.appending(path: "export/Evidence.sqlite")
    try FileManager.default.createDirectory(
        at: exportURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )

    try await store.exportBackup(to: exportURL)

    #expect(
        try EvidenceStoreTestSupport.runSQLite(
            databaseURL: exportURL,
            sql: "PRAGMA quick_check;"
        ) == "ok"
    )
    #expect(
        try EvidenceStoreTestSupport.runSQLite(
            databaseURL: exportURL,
            sql: "SELECT count(*) FROM scan_sessions;"
        ) == "1"
    )
    let replacementSession = try ScanSession(
        id: ScanSessionID(validating: "scan-backup-replacement"),
        startedAt: session.startedAt,
        finishedAt: session.finishedAt,
        terminalState: session.terminalState,
        completedScopes: session.completedScopes,
        unfinishedScopes: session.unfinishedScopes
    )
    try await store.saveScanSession(replacementSession)
    try await store.exportBackup(to: exportURL)
    #expect(
        try EvidenceStoreTestSupport.runSQLite(
            databaseURL: exportURL,
            sql: "SELECT count(*) FROM scan_sessions;"
        ) == "2"
    )
    var information = stat()
    #expect(lstat(exportURL.path, &information) == 0)
    #expect(information.st_mode & 0o777 == 0o600)
}

private struct StoredDeveloperTreeFixture: Decodable {
    let session: ScanSession
    let snapshots: [PathSnapshot]
    let classifications: [Classification]
    let evidence: [EvidenceRecord]
    let accounting: SpaceAccounting
}

private struct QuickScanStoreFixture {
    let session: ScanSession
    let snapshots: [PathSnapshot]

    init(snapshotCount: Int) throws {
        let sessionID = try ScanSessionID(
            validating: "scan-cursor-fixture"
        )
        let scopeID = try ScanScopeID(
            validating: "scope-cursor-fixture"
        )
        let observedAt = Date(timeIntervalSince1970: 1_786_320_000)
        session = try ScanSession(
            id: sessionID,
            startedAt: observedAt,
            finishedAt: observedAt.addingTimeInterval(1),
            terminalState: .completed,
            completedScopes: [
                ScanScope(
                    id: scopeID,
                    rootPath: PersistedPath(rawValue: "/tmp/cursor-fixture")!,
                    completedAt: observedAt.addingTimeInterval(1)
                ),
            ],
            unfinishedScopes: []
        )
        snapshots = try (0..<snapshotCount).reversed().map { index in
            let size = Int64(index + 1)
            return try PathSnapshot(
                id: SnapshotID(
                    rawValue: String(
                        format: "snapshot-cursor-%04d",
                        index
                    )
                )!,
                sessionID: sessionID,
                scopeID: scopeID,
                relativePath: String(
                    format: "files/%04d.bin",
                    index
                ),
                kind: .regularFile,
                logicalByteCount: ByteCount(UInt64(size)),
                allocatedByteCount: ByteCount(UInt64(size)),
                modifiedAt: observedAt,
                fileIdentity: FileIdentity(
                    device: 1,
                    inode: UInt64(index + 1),
                    mode: UInt16(S_IFREG | 0o600),
                    ownerUserID: getuid(),
                    ownerGroupID: getgid(),
                    size: size,
                    allocatedBytes: size,
                    modificationSeconds: Int64(
                        observedAt.timeIntervalSince1970
                    ),
                    modificationNanoseconds: 0
                ),
                symlinkTarget: nil,
                measurementStatus: .measured,
                observedAt: observedAt
            )
        }
    }
}

private struct HistoryStoreRecord {
    let session: ScanSession
    let ledger: SpaceLedger
}

private func historyRecord(
    slug: String,
    finishedAt: Date
) throws -> HistoryStoreRecord {
    let sessionID = ScanSessionID(rawValue: "scan-\(slug)")!
    let scopeID = ScanScopeID(rawValue: "scope-\(slug)")!
    let rootPath = PersistedPath(rawValue: "/tmp/\(slug)")!
    let rootIdentity = try FileIdentity(
        device: 1,
        inode: 1,
        mode: UInt16(S_IFDIR | 0o755),
        ownerUserID: getuid(),
        ownerGroupID: getgid(),
        size: 0,
        allocatedBytes: 0,
        modificationSeconds: Int64(finishedAt.timeIntervalSince1970),
        modificationNanoseconds: 0
    )
    let session = try ScanSession(
        id: sessionID,
        startedAt: finishedAt.addingTimeInterval(-60),
        finishedAt: finishedAt,
        terminalState: .completed,
        completedScopes: [
            ScanScope(
                id: scopeID,
                rootPath: rootPath,
                completedAt: finishedAt
            ),
        ],
        unfinishedScopes: []
    )
    let start = try VolumeBaseline(
        sessionID: sessionID,
        scopeID: scopeID,
        rootPath: rootPath,
        rootIdentity: rootIdentity,
        totalCapacity: ByteCount(1_000),
        availableCapacity: ByteCount(400),
        availableCapacityForImportantUsage: nil,
        availableCapacityForOpportunisticUsage: nil,
        volumeIsReadOnly: false,
        source: AccountingSource(
            kind: .volumeResourceValues,
            identifier: DomainToken(rawValue: "history.fixture.start")!,
            sampledAt: finishedAt.addingTimeInterval(-60)
        )
    )
    let end = try VolumeBaseline(
        sessionID: sessionID,
        scopeID: scopeID,
        rootPath: rootPath,
        rootIdentity: rootIdentity,
        totalCapacity: ByteCount(1_000),
        availableCapacity: ByteCount(450),
        availableCapacityForImportantUsage: nil,
        availableCapacityForOpportunisticUsage: nil,
        volumeIsReadOnly: false,
        source: AccountingSource(
            kind: .volumeResourceValues,
            identifier: DomainToken(rawValue: "history.fixture.end")!,
            sampledAt: finishedAt
        )
    )
    let rootSnapshot = try PathSnapshot(
        id: SnapshotID(rawValue: "snapshot-\(slug)-root")!,
        sessionID: sessionID,
        scopeID: scopeID,
        relativePath: ".",
        kind: .directory,
        logicalByteCount: ByteCount(0),
        allocatedByteCount: ByteCount(0),
        modifiedAt: finishedAt,
        fileIdentity: rootIdentity,
        symlinkTarget: nil,
        measurementStatus: .measured,
        observedAt: finishedAt
    )
    let ledger = try SpaceLedgerReconciler().reconcile(
        SpaceLedgerInput(
            startBaseline: start,
            endBaseline: end,
            snapshots: [rootSnapshot],
            classifications: []
        )
    )
    return HistoryStoreRecord(session: session, ledger: ledger)
}
