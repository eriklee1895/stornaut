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
    let plan: CleanupPlan = try EvidenceStoreTestSupport.fixture(
        CleanupPlan.self,
        name: "cleanup-plan-v1"
    )
    let decision: PolicyDecision = try EvidenceStoreTestSupport.fixture(
        PolicyDecision.self,
        name: "policy-decision-v1"
    )
    let manifest: CleanupManifest = try EvidenceStoreTestSupport.fixture(
        CleanupManifest.self,
        name: "cleanup-manifest-v1"
    )

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
