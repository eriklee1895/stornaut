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
    #expect(freshDiagnostics.schemaVersion == 3)
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
    #expect(try await migrated.diagnostics().schemaVersion == 3)

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
    let v3FromV1 = try EvidenceStore(configuration: v1Configuration)
    #expect(try await v3FromV1.diagnostics().schemaVersion == 3)
    #expect(
        try EvidenceStoreTestSupport.runSQLite(
            databaseURL: v1Configuration.evidenceDatabaseURL,
            sql: """
            SELECT count(*) FROM sqlite_master
            WHERE type='table' AND name='volume_baselines';
            """
        ) == "1"
    )

    let v2Root = try EvidenceStoreTestSupport.temporaryDirectory("v2")
    defer { try? FileManager.default.removeItem(at: v2Root) }
    let v2Configuration = try EvidenceStoreTestSupport.makeFileConfiguration(
        root: v2Root
    )
    try FileManager.default.createDirectory(
        at: v2Configuration.supportDirectoryURL,
        withIntermediateDirectories: true
    )
    let v2SQL = try String(
        contentsOf: EvidenceStoreTestSupport.repositoryRoot.appending(
            path: "Tests/Fixtures/EvidenceStore/v2-evidence.sql"
        ),
        encoding: .utf8
    )
    _ = try EvidenceStoreTestSupport.runSQLite(
        databaseURL: v2Configuration.evidenceDatabaseURL,
        sql: v2SQL
    )
    let v3FromV2 = try EvidenceStore(configuration: v2Configuration)
    #expect(try await v3FromV2.diagnostics().schemaVersion == 3)
    #expect(
        try EvidenceStoreTestSupport.runSQLite(
            databaseURL: v2Configuration.evidenceDatabaseURL,
            sql: """
            SELECT count(*) FROM sqlite_master
            WHERE type='table' AND name='cleanup_run_journals';
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

    try FileManager.default.removeItem(
        at: configuration.evidenceDatabaseURL
    )
    _ = try EvidenceStoreTestSupport.runSQLite(
        databaseURL: configuration.evidenceDatabaseURL,
        sql: "PRAGMA user_version=0;"
    )
    #expect(throws: EvidenceStoreError.migrationFailed(version: 3)) {
        _ = try EvidenceStore(
            configuration: configuration,
            testHooks: .init(failMigrationToVersion: 3)
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
            sql: """
            SELECT count(*) FROM sqlite_master
            WHERE name IN (
                'scan_sessions',
                'volume_baselines',
                'cleanup_run_journals'
            );
            """
        ) == "0"
    )

    try FileManager.default.removeItem(
        at: configuration.evidenceDatabaseURL
    )
    let v1SQL = try String(
        contentsOf: EvidenceStoreTestSupport.repositoryRoot.appending(
            path: "Tests/Fixtures/EvidenceStore/v1-evidence.sql"
        ),
        encoding: .utf8
    )
    _ = try EvidenceStoreTestSupport.runSQLite(
        databaseURL: configuration.evidenceDatabaseURL,
        sql: v1SQL
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

    try FileManager.default.removeItem(
        at: configuration.evidenceDatabaseURL
    )
    let v2SQL = try String(
        contentsOf: EvidenceStoreTestSupport.repositoryRoot.appending(
            path: "Tests/Fixtures/EvidenceStore/v2-evidence.sql"
        ),
        encoding: .utf8
    )
    _ = try EvidenceStoreTestSupport.runSQLite(
        databaseURL: configuration.evidenceDatabaseURL,
        sql: v2SQL
    )
    #expect(throws: EvidenceStoreError.migrationFailed(version: 3)) {
        _ = try EvidenceStore(
            configuration: configuration,
            testHooks: .init(failMigrationToVersion: 3)
        )
    }
    #expect(
        try EvidenceStoreTestSupport.runSQLite(
            databaseURL: configuration.evidenceDatabaseURL,
            sql: "PRAGMA user_version;"
        ) == "2"
    )
    #expect(
        try EvidenceStoreTestSupport.runSQLite(
            databaseURL: configuration.evidenceDatabaseURL,
            sql: """
            SELECT count(*) FROM sqlite_master
            WHERE name='cleanup_run_journals';
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
func localKnowledgeMigratesV1AndIsolatesGenericLegacyFacts() async throws {
    let root = try EvidenceStoreTestSupport.temporaryDirectory(
        "knowledge-migration"
    )
    defer { try? FileManager.default.removeItem(at: root) }
    let configuration = try EvidenceStoreTestSupport.makeFileConfiguration(
        root: root
    )
    try FileManager.default.createDirectory(
        at: configuration.supportDirectoryURL,
        withIntermediateDirectories: true
    )
    let legacyPayload = """
    {"id":"knowledge-legacy","kind":"keepDecision","provenance":"user.confirmed","scope":"fixture-root/legacy","stale":false,"updatedAt":1000,"value":"Keep"}
    """
    _ = try EvidenceStoreTestSupport.runSQLite(
        databaseURL: configuration.localKnowledgeDatabaseURL,
        sql: """
        PRAGMA application_id=\(StoreApplicationID.localKnowledge.rawValue);
        PRAGMA user_version=1;
        CREATE TABLE local_knowledge (
            id TEXT PRIMARY KEY NOT NULL,
            kind TEXT NOT NULL,
            scope TEXT NOT NULL,
            updated_at_ms INTEGER NOT NULL,
            payload TEXT NOT NULL
        ) STRICT;
        CREATE INDEX idx_local_knowledge_scope
        ON local_knowledge(scope, kind, id);
        INSERT INTO local_knowledge
        (id, kind, scope, updated_at_ms, payload)
        VALUES (
            'knowledge-legacy',
            'keepDecision',
            'fixture-root/legacy',
            1000,
            '\(legacyPayload)'
        );
        """
    )

    let store = try LocalKnowledgeStore(configuration: configuration)
    let page = try await store.facts(limit: 10, offset: 0)

    #expect(page.records.isEmpty)
    #expect(page.corruptRecordIDs == ["knowledge-legacy"])
    #expect(
        try EvidenceStoreTestSupport.runSQLite(
            databaseURL: configuration.localKnowledgeDatabaseURL,
            sql: "PRAGMA user_version;"
        ) == "2"
    )
}

@Test
func damagedLocalKnowledgeV1IsRejectedWithoutVersionMutation() throws {
    let root = try EvidenceStoreTestSupport.temporaryDirectory(
        "knowledge-damaged-v1"
    )
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
        PRAGMA application_id=\(StoreApplicationID.localKnowledge.rawValue);
        PRAGMA user_version=1;
        CREATE TABLE local_knowledge (
            id TEXT PRIMARY KEY NOT NULL,
            payload TEXT NOT NULL
        ) STRICT;
        """
    )

    #expect(throws: EvidenceStoreError.schemaMismatch) {
        _ = try LocalKnowledgeStore(configuration: configuration)
    }
    #expect(
        try EvidenceStoreTestSupport.runSQLite(
            databaseURL: configuration.localKnowledgeDatabaseURL,
            sql: "PRAGMA user_version;"
        ) == "1"
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
