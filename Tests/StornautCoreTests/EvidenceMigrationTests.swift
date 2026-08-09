import Foundation
import Testing
@testable import StornautCore

@Test
func evidenceStoreCreatesAndMigratesSchemaAtomically() async throws {
    let root = try EvidenceStoreTestSupport.temporaryDirectory("migration")
    defer { try? FileManager.default.removeItem(at: root) }
    let configuration = try EvidenceStoreTestSupport.makeFileConfiguration(
        root: root
    )

    let fresh = try EvidenceStore(configuration: configuration)
    let freshDiagnostics = try await fresh.diagnostics()
    #expect(freshDiagnostics.schemaVersion == 2)
    #expect(freshDiagnostics.applicationID == .evidence)
    #expect(freshDiagnostics.journalMode == "delete")
    #expect(freshDiagnostics.foreignKeysEnabled)

    let legacyRoot = try EvidenceStoreTestSupport.temporaryDirectory("legacy")
    defer { try? FileManager.default.removeItem(at: legacyRoot) }
    let legacyConfiguration = try EvidenceStoreTestSupport.makeFileConfiguration(
        root: legacyRoot
    )
    let sql = try String(
        contentsOf: EvidenceStoreTestSupport.repositoryRoot.appending(
            path: "Tests/Fixtures/EvidenceStore/v0-evidence.sql"
        ),
        encoding: .utf8
    )
    try FileManager.default.createDirectory(
        at: legacyConfiguration.supportDirectoryURL,
        withIntermediateDirectories: true
    )
    _ = try EvidenceStoreTestSupport.runSQLite(
        databaseURL: legacyConfiguration.evidenceDatabaseURL,
        sql: sql
    )

    let migrated = try EvidenceStore(configuration: legacyConfiguration)
    let sessions = try await migrated.scanSessions(limit: 10, offset: 0)
    #expect(sessions.records.map(\.id.rawValue) == ["scan-legacy-v0"])
    #expect(sessions.corruptRecordIDs.isEmpty)
    #expect(try await migrated.diagnostics().schemaVersion == 2)

    let v1Root = try EvidenceStoreTestSupport.temporaryDirectory("v1")
    defer { try? FileManager.default.removeItem(at: v1Root) }
    let v1Configuration = try EvidenceStoreTestSupport.makeFileConfiguration(
        root: v1Root
    )
    try FileManager.default.createDirectory(
        at: v1Configuration.supportDirectoryURL,
        withIntermediateDirectories: true
    )
    let v1SQL = try String(
        contentsOf: EvidenceStoreTestSupport.repositoryRoot.appending(
            path: "Tests/Fixtures/EvidenceStore/v1-evidence.sql"
        ),
        encoding: .utf8
    )
    _ = try EvidenceStoreTestSupport.runSQLite(
        databaseURL: v1Configuration.evidenceDatabaseURL,
        sql: v1SQL
    )
    let v2 = try EvidenceStore(configuration: v1Configuration)
    #expect(try await v2.diagnostics().schemaVersion == 2)
    #expect(
        try EvidenceStoreTestSupport.runSQLite(
            databaseURL: v1Configuration.evidenceDatabaseURL,
            sql: """
            SELECT count(*) FROM sqlite_master
            WHERE type='table' AND name='volume_baselines';
            """
        ) == "1"
    )
}

@Test
func migrationFailureRollsBackAndFutureSchemaIsNotMutated() async throws {
    let root = try EvidenceStoreTestSupport.temporaryDirectory("rollback")
    defer { try? FileManager.default.removeItem(at: root) }
    let configuration = try EvidenceStoreTestSupport.makeFileConfiguration(
        root: root
    )
    try FileManager.default.createDirectory(
        at: configuration.supportDirectoryURL,
        withIntermediateDirectories: true
    )
    _ = try EvidenceStoreTestSupport.runSQLite(
        databaseURL: configuration.evidenceDatabaseURL,
        sql: "PRAGMA user_version=0;"
    )

    #expect(throws: EvidenceStoreError.migrationFailed(version: 1)) {
        _ = try EvidenceStore(
            configuration: configuration,
            testHooks: .init(failMigrationToVersion: 1)
        )
    }
    #expect(
        try EvidenceStoreTestSupport.runSQLite(
            databaseURL: configuration.evidenceDatabaseURL,
            sql: "PRAGMA user_version;"
        ) == "0"
    )
    #expect(
        try EvidenceStoreTestSupport.runSQLite(
            databaseURL: configuration.evidenceDatabaseURL,
            sql: "PRAGMA application_id;"
        ) == "0"
    )
    #expect(
        try EvidenceStoreTestSupport.runSQLite(
            databaseURL: configuration.evidenceDatabaseURL,
            sql: "SELECT count(*) FROM sqlite_master WHERE name='scan_sessions';"
        ) == "0"
    )

    do {
        _ = try EvidenceStore(configuration: configuration)
    }
    _ = try EvidenceStoreTestSupport.runSQLite(
        databaseURL: configuration.evidenceDatabaseURL,
        sql: """
        DROP TABLE volume_baselines;
        PRAGMA user_version=1;
        """
    )
    #expect(throws: EvidenceStoreError.migrationFailed(version: 2)) {
        _ = try EvidenceStore(
            configuration: configuration,
            testHooks: .init(failMigrationToVersion: 2)
        )
    }
    #expect(
        try EvidenceStoreTestSupport.runSQLite(
            databaseURL: configuration.evidenceDatabaseURL,
            sql: "PRAGMA user_version;"
        ) == "1"
    )
    #expect(
        try EvidenceStoreTestSupport.runSQLite(
            databaseURL: configuration.evidenceDatabaseURL,
            sql: """
            SELECT count(*) FROM sqlite_master
            WHERE name='volume_baselines';
            """
        ) == "0"
    )

    _ = try EvidenceStoreTestSupport.runSQLite(
        databaseURL: configuration.evidenceDatabaseURL,
        sql: "PRAGMA user_version=99;"
    )
    let modeBeforeFutureOpen = try EvidenceStoreTestSupport.runSQLite(
        databaseURL: configuration.evidenceDatabaseURL,
        sql: "PRAGMA journal_mode;"
    )
    #expect(throws: EvidenceStoreError.unsupportedFutureSchema(version: 99)) {
        _ = try EvidenceStore(configuration: configuration)
    }
    #expect(
        try EvidenceStoreTestSupport.runSQLite(
            databaseURL: configuration.evidenceDatabaseURL,
            sql: "PRAGMA user_version;"
        ) == "99"
    )
    #expect(
        try EvidenceStoreTestSupport.runSQLite(
            databaseURL: configuration.evidenceDatabaseURL,
            sql: "PRAGMA journal_mode;"
        ) == modeBeforeFutureOpen
    )
}

@Test
func storeRejectsWrongRoleAndTransitionsWalToDelete() async throws {
    let root = try EvidenceStoreTestSupport.temporaryDirectory("roles")
    defer { try? FileManager.default.removeItem(at: root) }
    let configuration = try EvidenceStoreTestSupport.makeFileConfiguration(
        root: root
    )
    try FileManager.default.createDirectory(
        at: configuration.supportDirectoryURL,
        withIntermediateDirectories: true
    )
    _ = try EvidenceStoreTestSupport.runSQLite(
        databaseURL: configuration.evidenceDatabaseURL,
        sql: """
        PRAGMA journal_mode=WAL;
        PRAGMA application_id=\(StoreApplicationID.localKnowledge.rawValue);
        """
    )

    #expect(
        throws: EvidenceStoreError.wrongApplicationID(
            expected: .evidence,
            actual: .localKnowledge
        )
    ) {
        _ = try EvidenceStore(configuration: configuration)
    }
    #expect(
        try EvidenceStoreTestSupport.runSQLite(
            databaseURL: configuration.evidenceDatabaseURL,
            sql: "PRAGMA journal_mode;"
        ) == "wal"
    )

    _ = try EvidenceStoreTestSupport.runSQLite(
        databaseURL: configuration.evidenceDatabaseURL,
        sql: "PRAGMA application_id=0;"
    )
    let store = try EvidenceStore(configuration: configuration)
    #expect(try await store.diagnostics().journalMode == "delete")
    #expect(
        try EvidenceStoreTestSupport.runSQLite(
            databaseURL: configuration.evidenceDatabaseURL,
            sql: "PRAGMA journal_mode;"
        ) == "delete"
    )
}

@Test
func localKnowledgeRejectsFutureAndWrongRoleWithoutMutation() throws {
    let root = try EvidenceStoreTestSupport.temporaryDirectory("knowledge-role")
    defer { try? FileManager.default.removeItem(at: root) }
    let configuration = try EvidenceStoreTestSupport.makeFileConfiguration(
        root: root
    )
    try FileManager.default.createDirectory(
        at: configuration.supportDirectoryURL,
        withIntermediateDirectories: true
    )
    _ = try EvidenceStoreTestSupport.runSQLite(
        databaseURL: configuration.localKnowledgeDatabaseURL,
        sql: """
        PRAGMA journal_mode=WAL;
        PRAGMA application_id=\(StoreApplicationID.evidence.rawValue);
        """
    )
    #expect(
        throws: EvidenceStoreError.wrongApplicationID(
            expected: .localKnowledge,
            actual: .evidence
        )
    ) {
        _ = try LocalKnowledgeStore(configuration: configuration)
    }
    #expect(
        try EvidenceStoreTestSupport.runSQLite(
            databaseURL: configuration.localKnowledgeDatabaseURL,
            sql: "PRAGMA journal_mode;"
        ) == "wal"
    )

    _ = try EvidenceStoreTestSupport.runSQLite(
        databaseURL: configuration.localKnowledgeDatabaseURL,
        sql: """
        PRAGMA application_id=0;
        PRAGMA user_version=99;
        """
    )
    #expect(throws: EvidenceStoreError.unsupportedFutureSchema(version: 99)) {
        _ = try LocalKnowledgeStore(configuration: configuration)
    }
    #expect(
        try EvidenceStoreTestSupport.runSQLite(
            databaseURL: configuration.localKnowledgeDatabaseURL,
            sql: "PRAGMA journal_mode;"
        ) == "wal"
    )
}

@Test
func storesRejectUnclaimedForeignSchemasAndDamagedOwnedSchemas() throws {
    let root = try EvidenceStoreTestSupport.temporaryDirectory("unclaimed")
    defer { try? FileManager.default.removeItem(at: root) }
    let configuration = try EvidenceStoreTestSupport.makeFileConfiguration(
        root: root
    )
    try FileManager.default.createDirectory(
        at: configuration.supportDirectoryURL,
        withIntermediateDirectories: true
    )
    _ = try EvidenceStoreTestSupport.runSQLite(
        databaseURL: configuration.evidenceDatabaseURL,
        sql: "CREATE TABLE foreign_data (value TEXT);"
    )
    #expect(throws: EvidenceStoreError.unrecognizedUnclaimedDatabase) {
        _ = try EvidenceStore(configuration: configuration)
    }
    _ = try EvidenceStoreTestSupport.runSQLite(
        databaseURL: configuration.localKnowledgeDatabaseURL,
        sql: "CREATE TABLE foreign_data (value TEXT);"
    )
    #expect(throws: EvidenceStoreError.unrecognizedUnclaimedDatabase) {
        _ = try LocalKnowledgeStore(configuration: configuration)
    }

    try FileManager.default.removeItem(at: configuration.evidenceDatabaseURL)
    do {
        _ = try EvidenceStore(configuration: configuration)
    }
    _ = try EvidenceStoreTestSupport.runSQLite(
        databaseURL: configuration.evidenceDatabaseURL,
        sql: "DROP TABLE evidence;"
    )
    #expect(throws: EvidenceStoreError.schemaMismatch) {
        _ = try EvidenceStore(configuration: configuration)
    }
    _ = try EvidenceStoreTestSupport.runSQLite(
        databaseURL: configuration.evidenceDatabaseURL,
        sql: """
        CREATE TABLE evidence (
            id TEXT PRIMARY KEY NOT NULL,
            snapshot_id TEXT NOT NULL,
            observed_at_ms INTEGER NOT NULL,
            payload TEXT NOT NULL
        ) STRICT;
        CREATE INDEX idx_evidence_snapshot
        ON evidence(snapshot_id, observed_at_ms, id);
        """
    )
    #expect(throws: EvidenceStoreError.schemaMismatch) {
        _ = try EvidenceStore(configuration: configuration)
    }
}

@Test
func evidenceStoreRejectsPersistedForeignKeyViolations() throws {
    let root = try EvidenceStoreTestSupport.temporaryDirectory("foreign-key")
    defer { try? FileManager.default.removeItem(at: root) }
    let configuration = try EvidenceStoreTestSupport.makeFileConfiguration(
        root: root
    )
    do {
        _ = try EvidenceStore(configuration: configuration)
    }
    _ = try EvidenceStoreTestSupport.runSQLite(
        databaseURL: configuration.evidenceDatabaseURL,
        sql: """
        PRAGMA foreign_keys=OFF;
        INSERT INTO path_snapshots
        (id, session_id, relative_path, observed_at_ms, payload)
        VALUES ('snapshot-orphan', 'scan-missing', 'fixture/orphan', 0, '{}');
        """
    )

    #expect(throws: EvidenceStoreError.integrityCheckFailed) {
        _ = try EvidenceStore(configuration: configuration)
    }
}
