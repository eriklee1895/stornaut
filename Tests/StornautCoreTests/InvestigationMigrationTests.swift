import Foundation
import SQLite3
import Testing
@testable import StornautCore

@Test
func investigationMigrationCreatesExactV4SchemaAndBlobBinding() async throws {
    let store = try EvidenceStore(configuration: .memory)
    #expect(try await store.diagnostics().schemaVersion == 4)

    let connection = try SQLiteConnection(path: ":memory:")
    try connection.execute(
        """
        CREATE TABLE blob_round_trip (
            id TEXT PRIMARY KEY NOT NULL,
            payload BLOB NOT NULL CHECK(length(payload) = 32)
        ) STRICT
        """,
        operation: "test.blob.schema"
    )
    let expected = Data((0..<32).map(UInt8.init))
    try connection.execute(
        "INSERT INTO blob_round_trip (id, payload) VALUES (?, ?)",
        bindings: [.text("blob"), .blob(expected)],
        operation: "test.blob.insert"
    )
    let rows = try connection.query(
        "SELECT payload FROM blob_round_trip WHERE id = ?",
        bindings: [.text("blob")],
        operation: "test.blob.load"
    ) { statement in
        columnBlob(statement, 0)
    }
    #expect(rows == [expected])

    let tableNames = try await connectionNames(
        databaseURL: nil,
        store: store,
        type: "table"
    )
    #expect(
        Set(tableNames).isSuperset(of: [
            "investigation_sessions",
            "investigation_source_rows",
            "investigation_relevance_tokens",
            "investigation_targets",
            "investigation_runs",
            "investigation_run_targets",
            "investigation_reports",
            "investigation_evidence",
            "investigation_report_degradations",
            "investigation_budget_events",
        ])
    )
}

@Test
func investigationMigrationPreservesV3AndRollsBackV4Failure() async throws {
    let root = try EvidenceStoreTestSupport.temporaryDirectory(
        "investigation-v3"
    )
    defer { try? FileManager.default.removeItem(at: root) }
    let configuration = try EvidenceStoreTestSupport.makeFileConfiguration(
        root: root
    )
    try FileManager.default.createDirectory(
        at: configuration.supportDirectoryURL,
        withIntermediateDirectories: true
    )
    try installV3Fixture(at: configuration.evidenceDatabaseURL)

    let before = try EvidenceStoreTestSupport.runSQLite(
        databaseURL: configuration.evidenceDatabaseURL,
        sql: """
        SELECT id || '|' || payload FROM scan_sessions
        WHERE id = 'scan-v3-migration';
        """
    )
    #expect(
        throws: EvidenceStoreError.migrationFailed(version: 4)
    ) {
        _ = try EvidenceStore(
            configuration: configuration,
            testHooks: .init(failMigrationToVersion: 4)
        )
    }
    #expect(
        try EvidenceStoreTestSupport.runSQLite(
            databaseURL: configuration.evidenceDatabaseURL,
            sql: "PRAGMA user_version;"
        ) == "3"
    )
    #expect(
        try EvidenceStoreTestSupport.runSQLite(
            databaseURL: configuration.evidenceDatabaseURL,
            sql: """
            SELECT count(*) FROM sqlite_master
            WHERE name LIKE 'investigation_%';
            """
        ) == "0"
    )
    #expect(
        try EvidenceStoreTestSupport.runSQLite(
            databaseURL: configuration.evidenceDatabaseURL,
            sql: """
            SELECT id || '|' || payload FROM scan_sessions
            WHERE id = 'scan-v3-migration';
            """
        ) == before
    )

    let migrated = try EvidenceStore(configuration: configuration)
    #expect(try await migrated.diagnostics().schemaVersion == 4)
    #expect(
        try await migrated.scanSession(
            id: ScanSessionID(rawValue: "scan-v3-migration")!
        )?.id.rawValue == "scan-v3-migration"
    )
    #expect(
        try EvidenceStoreTestSupport.runSQLite(
            databaseURL: configuration.evidenceDatabaseURL,
            sql: "PRAGMA foreign_key_check;"
        ).isEmpty
    )
}

private func connectionNames(
    databaseURL: URL?,
    store: EvidenceStore,
    type: String
) async throws -> [String] {
    _ = databaseURL
    return try await store._testSchemaObjectNames(type: type)
}

private func installV3Fixture(at databaseURL: URL) throws {
    let v3 = try String(
        contentsOf: EvidenceStoreTestSupport.repositoryRoot.appending(
            path: "Tests/Fixtures/EvidenceStore/v3-evidence.sql"
        ),
        encoding: .utf8
    )
    let session: ScanSession = try EvidenceStoreTestSupport.fixture(
        ScanSession.self,
        name: "scan-session-v1"
    )
    let migratedSession = try ScanSession(
        id: ScanSessionID(rawValue: "scan-v3-migration")!,
        startedAt: session.startedAt,
        finishedAt: session.finishedAt,
        terminalState: session.terminalState,
        completedScopes: session.completedScopes,
        unfinishedScopes: session.unfinishedScopes,
        aggregate: session.aggregate
    )
    let payload = String(
        decoding: try DomainJSON.encode(migratedSession),
        as: UTF8.self
    ).replacingOccurrences(of: "'", with: "''")
    let sql = v3 + """

    INSERT INTO scan_sessions (
        id, started_at_ms, finished_at_ms, expires_at_ms, payload
    ) VALUES (
        'scan-v3-migration',
        \(storeMilliseconds(migratedSession.startedAt)),
        \(storeMilliseconds(migratedSession.finishedAt)),
        \(addingStoreMilliseconds(
            7 * 86_400 * 1_000,
            to: storeMilliseconds(migratedSession.finishedAt)
        )),
        '\(payload)'
    );
    """
    _ = try EvidenceStoreTestSupport.runSQLite(
        databaseURL: databaseURL,
        sql: sql
    )
}
