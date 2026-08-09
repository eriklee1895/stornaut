import Foundation
import SQLite3

public struct StoreDiagnostics: Sendable, Equatable {
    public let schemaVersion: Int
    public let applicationID: StoreApplicationID
    public let journalMode: String
    public let foreignKeysEnabled: Bool
}

public struct StorePage<Record: Sendable>: Sendable {
    public let records: [Record]
    public let corruptRecordIDs: [String]

    public init(records: [Record], corruptRecordIDs: [String]) {
        self.records = records
        self.corruptRecordIDs = corruptRecordIDs
    }
}

struct EvidenceStoreTestHooks: Sendable {
    let failMigrationToVersion: Int?

    init(failMigrationToVersion: Int? = nil) {
        self.failMigrationToVersion = failMigrationToVersion
    }
}

public actor EvidenceStore {
    private static let schemaVersion = 1
    private static let sevenDaysMilliseconds: Int64 = 7 * 86_400 * 1_000
    private static let ninetyDaysMilliseconds: Int64 = 90 * 86_400 * 1_000

    private let connection: SQLiteConnection

    public init(configuration: LocalStoreConfiguration) throws {
        try self.init(
            configuration: configuration,
            testHooks: EvidenceStoreTestHooks()
        )
    }

    init(
        configuration: LocalStoreConfiguration,
        testHooks: EvidenceStoreTestHooks
    ) throws {
        try LocalStorePathPolicy.prepare(
            configuration: configuration,
            databaseURL: configuration.evidenceDatabaseURL
        )
        try verifySQLiteHeaderIfPresent(
            configuration.evidenceDatabaseURL,
            isMemory: configuration.isMemory
        )
        let connection = try SQLiteConnection(
            path: configuration.isMemory
                ? ":memory:"
                : configuration.evidenceDatabaseURL.path
        )
        self.connection = connection
        try Self.validateCompatibility(
            connection,
            expectedApplicationID: .evidence
        )
        try Self.configureConnection(connection)
        try Self.verifyIntegrity(connection)
        try Self.migrate(connection, testHooks: testHooks)
        try Self.verifySchema(connection)
        try Self.finalizeRole(
            connection,
            applicationID: .evidence
        )
        try Self.verifyIntegrity(connection)
        try LocalStorePathPolicy.finalizeDatabase(
            configuration.evidenceDatabaseURL,
            isMemory: configuration.isMemory,
            excludeFromBackup: true
        )
    }

    public func diagnostics() throws -> StoreDiagnostics {
        let version = try connection.scalarInt(
            "PRAGMA user_version",
            operation: "diagnostics.version"
        )
        let rawApplicationID = try connection.scalarInt(
            "PRAGMA application_id",
            operation: "diagnostics.applicationID"
        )
        guard let applicationID = StoreApplicationID(
            rawValue: Int32(rawApplicationID)
        ) else {
            throw EvidenceStoreError.unknownApplicationID(
                value: Int32(rawApplicationID)
            )
        }
        let journalMode = try connection.scalarText(
            "PRAGMA journal_mode",
            operation: "diagnostics.journalMode"
        )
        let foreignKeys = try connection.scalarInt(
            "PRAGMA foreign_keys",
            operation: "diagnostics.foreignKeys"
        ) == 1
        return StoreDiagnostics(
            schemaVersion: Int(version),
            applicationID: applicationID,
            journalMode: journalMode,
            foreignKeysEnabled: foreignKeys
        )
    }

    public func saveScanSession(_ session: ScanSession) throws {
        let payload = try encodeStorePayload(session)
        let expiresAt = addingStoreMilliseconds(
            Self.sevenDaysMilliseconds,
            to: storeMilliseconds(session.finishedAt)
        )
        try connection.execute(
            """
            INSERT INTO scan_sessions
            (id, started_at_ms, finished_at_ms, expires_at_ms, payload)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                started_at_ms=excluded.started_at_ms,
                finished_at_ms=excluded.finished_at_ms,
                expires_at_ms=excluded.expires_at_ms,
                payload=excluded.payload
            """,
            bindings: [
                .text(session.id.rawValue),
                .integer(storeMilliseconds(session.startedAt)),
                .integer(storeMilliseconds(session.finishedAt)),
                .integer(expiresAt),
                .text(payload),
            ],
            operation: "scanSession.save"
        )
    }

    public func scanSession(id: ScanSessionID) throws -> ScanSession? {
        try decodeOne(
            table: "scan_sessions",
            id: id.rawValue,
            type: ScanSession.self,
            recordID: \.id.rawValue,
            storageColumns: ", started_at_ms, finished_at_ms, expires_at_ms",
            validateStorage: { session, statement in
                sqlite3_column_int64(statement, 1)
                    == storeMilliseconds(session.startedAt)
                    && sqlite3_column_int64(statement, 2)
                    == storeMilliseconds(session.finishedAt)
                    && sqlite3_column_int64(statement, 3)
                    == addingStoreMilliseconds(
                        Self.sevenDaysMilliseconds,
                        to: storeMilliseconds(session.finishedAt)
                    )
            },
            operation: "scanSession.load"
        )
    }

    public func scanSessions(
        limit: Int,
        offset: Int
    ) throws -> StorePage<ScanSession> {
        try validatePage(limit: limit, offset: offset)
        return try decodePage(
            sql: """
            SELECT id, payload, started_at_ms, finished_at_ms, expires_at_ms
            FROM scan_sessions
            ORDER BY finished_at_ms DESC, id ASC
            LIMIT ? OFFSET ?
            """,
            bindings: [.integer(Int64(limit)), .integer(Int64(offset))],
            type: ScanSession.self,
            recordID: \.id.rawValue,
            validateStorage: { session, statement in
                sqlite3_column_int64(statement, 2)
                    == storeMilliseconds(session.startedAt)
                    && sqlite3_column_int64(statement, 3)
                    == storeMilliseconds(session.finishedAt)
                    && sqlite3_column_int64(statement, 4)
                    == addingStoreMilliseconds(
                        Self.sevenDaysMilliseconds,
                        to: storeMilliseconds(session.finishedAt)
                    )
            },
            operation: "scanSession.page"
        )
    }

    public func savePathSnapshots(_ snapshots: [PathSnapshot]) throws {
        try Task.checkCancellation()
        try connection.transaction(operation: "snapshot.batch") {
            for snapshot in snapshots {
                try Task.checkCancellation()
                let payload = try encodeStorePayload(snapshot)
                try connection.execute(
                    """
                    INSERT INTO path_snapshots
                    (id, session_id, relative_path, observed_at_ms, payload)
                    VALUES (?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        session_id=excluded.session_id,
                        relative_path=excluded.relative_path,
                        observed_at_ms=excluded.observed_at_ms,
                        payload=excluded.payload
                    """,
                    bindings: [
                        .text(snapshot.id.rawValue),
                        .text(snapshot.sessionID.rawValue),
                        .text(snapshot.relativePath),
                        .integer(storeMilliseconds(snapshot.observedAt)),
                        .text(payload),
                    ],
                    operation: "snapshot.save"
                )
            }
        }
    }

    public func pathSnapshots(
        sessionID: ScanSessionID,
        limit: Int,
        offset: Int
    ) throws -> StorePage<PathSnapshot> {
        try validatePage(limit: limit, offset: offset)
        return try decodePage(
            sql: """
            SELECT id, payload, session_id, relative_path, observed_at_ms
            FROM path_snapshots
            WHERE session_id = ?
            ORDER BY relative_path ASC, id ASC
            LIMIT ? OFFSET ?
            """,
            bindings: [
                .text(sessionID.rawValue),
                .integer(Int64(limit)),
                .integer(Int64(offset)),
            ],
            type: PathSnapshot.self,
            recordID: \.id.rawValue,
            validateStorage: { snapshot, statement in
                columnText(statement, 2) == snapshot.sessionID.rawValue
                    && columnText(statement, 3) == snapshot.relativePath
                    && sqlite3_column_int64(statement, 4)
                    == storeMilliseconds(snapshot.observedAt)
            },
            operation: "snapshot.page"
        )
    }

    public func saveClassifications(
        _ classifications: [Classification]
    ) throws {
        try Task.checkCancellation()
        try connection.transaction(operation: "classification.batch") {
            for classification in classifications {
                try Task.checkCancellation()
                try connection.execute(
                    """
                    INSERT INTO classifications
                    (id, snapshot_id, disposition, classified_at_ms, payload)
                    VALUES (?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        snapshot_id=excluded.snapshot_id,
                        disposition=excluded.disposition,
                        classified_at_ms=excluded.classified_at_ms,
                        payload=excluded.payload
                    """,
                    bindings: [
                        .text(classification.id.rawValue),
                        .text(classification.snapshotID.rawValue),
                        .text(classification.disposition.rawValue),
                        .integer(storeMilliseconds(classification.classifiedAt)),
                        .text(try encodeStorePayload(classification)),
                    ],
                    operation: "classification.save"
                )
            }
        }
    }

    public func classifications(
        sessionID: ScanSessionID,
        limit: Int,
        offset: Int,
        disposition: ReclaimDisposition? = nil
    ) throws -> StorePage<Classification> {
        try validatePage(limit: limit, offset: offset)
        let dispositionClause = disposition == nil
            ? ""
            : "AND c.disposition = ?"
        var bindings: [SQLiteValue] = [.text(sessionID.rawValue)]
        if let disposition {
            bindings.append(.text(disposition.rawValue))
        }
        bindings.append(.integer(Int64(limit)))
        bindings.append(.integer(Int64(offset)))
        return try decodePage(
            sql: """
            SELECT c.id, c.payload, c.snapshot_id, c.disposition,
                   c.classified_at_ms
            FROM classifications c
            JOIN path_snapshots s ON s.id = c.snapshot_id
            WHERE s.session_id = ?
            \(dispositionClause)
            ORDER BY c.classified_at_ms ASC, c.id ASC
            LIMIT ? OFFSET ?
            """,
            bindings: bindings,
            type: Classification.self,
            recordID: \.id.rawValue,
            validateStorage: { classification, statement in
                columnText(statement, 2) == classification.snapshotID.rawValue
                    && columnText(statement, 3)
                    == classification.disposition.rawValue
                    && sqlite3_column_int64(statement, 4)
                    == storeMilliseconds(classification.classifiedAt)
            },
            operation: "classification.list"
        )
    }

    public func saveEvidence(_ evidence: [EvidenceRecord]) throws {
        try saveRecords(
            evidence,
            table: "evidence",
            id: { $0.id.rawValue },
            parentID: { $0.targetID.rawValue },
            parentColumn: "snapshot_id",
            timestamp: { $0.observedAt },
            operation: "evidence.save"
        )
    }

    public func evidence(
        sessionID: ScanSessionID,
        limit: Int,
        offset: Int
    ) throws -> StorePage<EvidenceRecord> {
        try validatePage(limit: limit, offset: offset)
        return try decodePage(
            sql: """
            SELECT e.id, e.payload, e.snapshot_id, e.observed_at_ms
            FROM evidence e
            JOIN path_snapshots s ON s.id = e.snapshot_id
            WHERE s.session_id = ?
            ORDER BY e.observed_at_ms ASC, e.id ASC
            LIMIT ? OFFSET ?
            """,
            bindings: [
                .text(sessionID.rawValue),
                .integer(Int64(limit)),
                .integer(Int64(offset)),
            ],
            type: EvidenceRecord.self,
            recordID: \.id.rawValue,
            validateStorage: { evidence, statement in
                columnText(statement, 2) == evidence.targetID.rawValue
                    && sqlite3_column_int64(statement, 3)
                    == storeMilliseconds(evidence.observedAt)
            },
            operation: "evidence.list"
        )
    }

    public func saveSpaceAccounting(_ accounting: SpaceAccounting) throws {
        try saveSingleton(
            table: "space_accounting",
            id: accounting.sessionID.rawValue,
            parentColumn: "session_id",
            parentID: accounting.sessionID.rawValue,
            payload: DomainJSON.encode(accounting),
            operation: "accounting.save"
        )
    }

    public func spaceAccounting(
        sessionID: ScanSessionID
    ) throws -> SpaceAccounting? {
        try decodeOne(
            table: "space_accounting",
            id: sessionID.rawValue,
            type: SpaceAccounting.self,
            recordID: \.sessionID.rawValue,
            storageColumns: ", session_id",
            validateStorage: { accounting, statement in
                columnText(statement, 1) == accounting.sessionID.rawValue
            },
            operation: "accounting.load"
        )
    }

    public func saveCleanupPlan(_ plan: CleanupPlan) throws {
        try saveExpiringRecord(
            table: "cleanup_plans",
            id: plan.id.rawValue,
            parentID: plan.scanSessionID.rawValue,
            parentColumn: "session_id",
            timestampColumn: "created_at_ms",
            timestamp: plan.createdAt,
            expiresAt: plan.expiresAt,
            maximumLifetimeMilliseconds: Self.sevenDaysMilliseconds,
            payload: DomainJSON.encode(plan),
            operation: "plan.save"
        )
    }

    public func cleanupPlan(id: CleanupPlanID) throws -> CleanupPlan? {
        try decodeOne(
            table: "cleanup_plans",
            id: id.rawValue,
            type: CleanupPlan.self,
            recordID: \.id.rawValue,
            storageColumns: ", session_id, created_at_ms, expires_at_ms",
            validateStorage: { plan, statement in
                columnText(statement, 1) == plan.scanSessionID.rawValue
                    && sqlite3_column_int64(statement, 2)
                    == storeMilliseconds(plan.createdAt)
                    && sqlite3_column_int64(statement, 3)
                    == storeMilliseconds(plan.expiresAt)
            },
            operation: "plan.load"
        )
    }

    public func savePolicyDecision(_ decision: PolicyDecision) throws {
        try saveSingleton(
            table: "policy_decisions",
            id: decision.id.rawValue,
            parentColumn: "plan_id",
            parentID: decision.planID.rawValue,
            payload: DomainJSON.encode(decision),
            operation: "decision.save"
        )
    }

    public func policyDecision(id: PolicyDecisionID) throws -> PolicyDecision? {
        try decodeOne(
            table: "policy_decisions",
            id: id.rawValue,
            type: PolicyDecision.self,
            recordID: \.id.rawValue,
            storageColumns: ", plan_id",
            validateStorage: { decision, statement in
                columnText(statement, 1) == decision.planID.rawValue
            },
            operation: "decision.load"
        )
    }

    public func saveCleanupManifest(_ manifest: CleanupManifest) throws {
        try saveExpiringRecord(
            table: "cleanup_manifests",
            id: manifest.id.rawValue,
            parentID: manifest.planID.rawValue,
            parentColumn: "plan_id",
            timestampColumn: "created_at_ms",
            timestamp: manifest.createdAt,
            expiresAt: manifest.expiresAt,
            maximumLifetimeMilliseconds: Self.ninetyDaysMilliseconds,
            payload: DomainJSON.encode(manifest),
            operation: "manifest.save"
        )
    }

    public func cleanupManifest(
        id: CleanupManifestID
    ) throws -> CleanupManifest? {
        try decodeOne(
            table: "cleanup_manifests",
            id: id.rawValue,
            type: CleanupManifest.self,
            recordID: \.id.rawValue,
            storageColumns: ", plan_id, created_at_ms, expires_at_ms",
            validateStorage: { manifest, statement in
                columnText(statement, 1) == manifest.planID.rawValue
                    && sqlite3_column_int64(statement, 2)
                    == storeMilliseconds(manifest.createdAt)
                    && sqlite3_column_int64(statement, 3)
                    == storeMilliseconds(manifest.expiresAt)
            },
            operation: "manifest.load"
        )
    }

    public func deleteScanSession(id: ScanSessionID) throws {
        try connection.execute(
            "DELETE FROM scan_sessions WHERE id = ?",
            bindings: [.text(id.rawValue)],
            operation: "scanSession.delete"
        )
    }

    public func expireRecords(now: Date) throws {
        let nowMilliseconds = storeMilliseconds(now)
        let evidenceCutoff = subtractingStoreMilliseconds(
            Self.sevenDaysMilliseconds,
            from: nowMilliseconds
        )
        let manifestCutoff = subtractingStoreMilliseconds(
            Self.ninetyDaysMilliseconds,
            from: nowMilliseconds
        )
        try connection.transaction(operation: "retention.expire") {
            try connection.execute(
                """
                DELETE FROM cleanup_plans
                WHERE expires_at_ms <= ? OR created_at_ms <= ?
                """,
                bindings: [
                    .integer(nowMilliseconds),
                    .integer(evidenceCutoff),
                ],
                operation: "retention.plans"
            )
            try connection.execute(
                """
                DELETE FROM scan_sessions
                WHERE expires_at_ms <= ? OR finished_at_ms <= ?
                """,
                bindings: [
                    .integer(nowMilliseconds),
                    .integer(evidenceCutoff),
                ],
                operation: "retention.evidence"
            )
            try connection.execute(
                """
                DELETE FROM cleanup_manifests
                WHERE expires_at_ms <= ? OR created_at_ms <= ?
                """,
                bindings: [
                    .integer(nowMilliseconds),
                    .integer(manifestCutoff),
                ],
                operation: "retention.manifest"
            )
        }
    }

    public func clearEvidence() throws {
        try connection.execute(
            "DELETE FROM scan_sessions",
            operation: "clear.evidence"
        )
    }

    public func clearManifests() throws {
        try connection.execute(
            "DELETE FROM cleanup_manifests",
            operation: "clear.manifests"
        )
    }

    func _testInsertMalformedScanSession(
        id: String,
        payload: String
    ) throws {
        try connection.execute(
            """
            INSERT INTO scan_sessions
            (id, started_at_ms, finished_at_ms, expires_at_ms, payload)
            VALUES (?, 0, 0, 9223372036854775807, ?)
            """,
            bindings: [.text(id), .text(payload)],
            operation: "test.malformedSession"
        )
    }

    func _testReplaceScanSessionPayload(
        id: String,
        payload: String
    ) throws {
        try connection.execute(
            "UPDATE scan_sessions SET payload = ? WHERE id = ?",
            bindings: [.text(payload), .text(id)],
            operation: "test.replaceSessionPayload"
        )
    }

    func _testChangeClassificationDisposition(
        id: ClassificationID,
        disposition: ReclaimDisposition
    ) throws {
        try connection.execute(
            "UPDATE classifications SET disposition = ? WHERE id = ?",
            bindings: [
                .text(disposition.rawValue),
                .text(id.rawValue),
            ],
            operation: "test.changeClassificationDisposition"
        )
    }

    func _testChangeCleanupPlanExpiry(
        id: CleanupPlanID,
        milliseconds: Int64
    ) throws {
        try connection.execute(
            "UPDATE cleanup_plans SET expires_at_ms = ? WHERE id = ?",
            bindings: [
                .integer(milliseconds),
                .text(id.rawValue),
            ],
            operation: "test.changeCleanupPlanExpiry"
        )
    }

    func _testQueryPlan(_ kind: StoreQueryPlanKind) throws -> String {
        let sql: String
        switch kind {
        case .snapshotsBySession:
            sql = """
            EXPLAIN QUERY PLAN
            SELECT id, payload FROM path_snapshots
            WHERE session_id = 'scan-fixture'
            ORDER BY relative_path ASC, id ASC
            LIMIT 20 OFFSET 0
            """
        case .classificationsByDisposition:
            sql = """
            EXPLAIN QUERY PLAN
            SELECT id, payload FROM classifications
            WHERE disposition = 'unknown'
            ORDER BY classified_at_ms DESC, id ASC
            LIMIT 20 OFFSET 0
            """
        case .sessionRetention:
            sql = """
            EXPLAIN QUERY PLAN
            SELECT id FROM scan_sessions
            WHERE expires_at_ms <= 1
            """
        case .sessionHistory:
            sql = """
            EXPLAIN QUERY PLAN
            SELECT id FROM scan_sessions
            ORDER BY finished_at_ms DESC, id ASC
            LIMIT 20 OFFSET 0
            """
        }
        return try connection.query(
            sql,
            operation: "test.queryPlan"
        ) { columnText($0, 3) }.joined(separator: "\n")
    }

    public func exportBackup(to destinationURL: URL) throws {
        guard destinationURL.isFileURL,
              destinationURL.path.hasPrefix("/")
        else {
            throw EvidenceStoreError.unsafeStoragePath
        }
        let parent = destinationURL.deletingLastPathComponent()
        var parentInfo = stat()
        guard lstat(parent.path, &parentInfo) == 0,
              parentInfo.st_mode & S_IFMT == S_IFDIR
        else {
            throw EvidenceStoreError.unsafeStoragePath
        }
        var destinationInfo = stat()
        if lstat(destinationURL.path, &destinationInfo) == 0 {
            guard destinationInfo.st_mode & S_IFMT == S_IFREG else {
                throw EvidenceStoreError.unsafeStoragePath
            }
        } else if errno != ENOENT {
            throw EvidenceStoreError.unsafeStoragePath
        }
        let canonicalParent = try canonicalizingExistingAncestor(parent)
        let temporaryURL = canonicalParent.appending(
            path: ".stornaut-export-\(UUID().uuidString).sqlite"
        )
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        try LocalStorePathPolicy.createPrivateFileExclusive(temporaryURL)
        try connection.backup(to: temporaryURL.path)
        var coordinationError: NSError?
        var replacementError: Error?
        NSFileCoordinator().coordinate(
            writingItemAt: destinationURL,
            options: .forReplacing,
            error: &coordinationError
        ) { coordinatedURL in
            do {
                guard try canonicalizingExistingAncestor(
                    coordinatedURL.deletingLastPathComponent()
                ) == canonicalParent else {
                    throw EvidenceStoreError.unsafeStoragePath
                }
                var coordinatedInfo = stat()
                if lstat(coordinatedURL.path, &coordinatedInfo) == 0 {
                    guard coordinatedInfo.st_mode & S_IFMT == S_IFREG else {
                        throw EvidenceStoreError.unsafeStoragePath
                    }
                } else if errno != ENOENT {
                    throw EvidenceStoreError.unsafeStoragePath
                }
                guard rename(temporaryURL.path, coordinatedURL.path) == 0 else {
                    throw EvidenceStoreError.sqlite(
                        operation: "backup.publish",
                        code: SQLITE_IOERR,
                        extendedCode: SQLITE_IOERR
                    )
                }
            } catch {
                replacementError = error
            }
        }
        if coordinationError != nil || replacementError != nil {
            throw EvidenceStoreError.sqlite(
                operation: "backup.publish",
                code: SQLITE_IOERR,
                extendedCode: SQLITE_IOERR
            )
        }
    }

    private static func configureConnection(
        _ connection: SQLiteConnection
    ) throws {
        try connection.execute(
            "PRAGMA foreign_keys=ON",
            operation: "configure.foreignKeys"
        )
        try connection.execute(
            "PRAGMA synchronous=FULL",
            operation: "configure.synchronous"
        )
        try connection.execute(
            "PRAGMA trusted_schema=OFF",
            operation: "configure.trustedSchema"
        )
        try connection.execute(
            "PRAGMA writable_schema=OFF",
            operation: "configure.writableSchema"
        )
    }

    private static func finalizeRole(
        _ connection: SQLiteConnection,
        applicationID: StoreApplicationID
    ) throws {
        let mode = try connection.scalarText(
            "PRAGMA journal_mode=DELETE",
            operation: "configure.journalMode"
        ).lowercased()
        guard mode == "delete" || mode == "memory" else {
            throw EvidenceStoreError.sqlite(
                operation: "configure.journalMode",
                code: SQLITE_ERROR,
                extendedCode: SQLITE_ERROR
            )
        }
        guard try connection.scalarInt(
            "PRAGMA foreign_keys",
            operation: "configure.verifyForeignKeys"
        ) == 1 else {
            throw EvidenceStoreError.sqlite(
                operation: "configure.verifyForeignKeys",
                code: SQLITE_ERROR,
                extendedCode: SQLITE_ERROR
            )
        }
        let rawApplicationID = try connection.scalarInt(
            "PRAGMA application_id",
            operation: "configure.applicationID"
        )
        guard rawApplicationID == Int64(applicationID.rawValue) else {
            throw EvidenceStoreError.schemaMismatch
        }
    }

    private static func schemaObjects(
        _ connection: SQLiteConnection
    ) throws -> Set<String> {
        Set(try connection.query(
            """
            SELECT type, name
            FROM sqlite_master
            WHERE name NOT LIKE 'sqlite_%'
            ORDER BY type, name
            """,
            operation: "schema.objects"
        ) {
            "\(columnText($0, 0)):\(columnText($0, 1))"
        })
    }

    private static func schemaSignature(
        _ connection: SQLiteConnection
    ) throws -> [String] {
        try connection.query(
            """
            SELECT type, name, sql
            FROM sqlite_master
            WHERE name NOT LIKE 'sqlite_%'
            ORDER BY type, name
            """,
            operation: "schema.signature"
        ) {
            [
                columnText($0, 0),
                columnText($0, 1),
                columnText($0, 2)
                    .split(whereSeparator: \.isWhitespace)
                    .joined(separator: " "),
            ].joined(separator: "|")
        }
    }

    private static func verifySchema(
        _ connection: SQLiteConnection
    ) throws {
        let expected = try SQLiteConnection(path: ":memory:")
        try configureConnection(expected)
        try createSchema(expected)
        guard try schemaSignature(connection) == schemaSignature(expected) else {
            throw EvidenceStoreError.schemaMismatch
        }
    }

    private static func verifyUnclaimedSchema(
        _ connection: SQLiteConnection,
        version: Int
    ) throws {
        let objects = try schemaObjects(connection)
        guard version == 0,
              objects.isEmpty
                || objects == Set(["table:legacy_scan_sessions"])
        else {
            throw EvidenceStoreError.unrecognizedUnclaimedDatabase
        }
    }

    private static func verifyClaimedPreMigrationSchema(
        _ connection: SQLiteConnection,
        version: Int
    ) throws {
        guard version != 0 else {
            let objects = try schemaObjects(connection)
            guard objects.isEmpty
                    || objects == Set(["table:legacy_scan_sessions"])
            else {
                throw EvidenceStoreError.schemaMismatch
            }
            return
        }
        guard version == schemaVersion else {
            throw EvidenceStoreError.schemaMismatch
        }
    }

    private static func claimRole(_ connection: SQLiteConnection) throws {
        try connection.execute(
            "PRAGMA application_id=\(StoreApplicationID.evidence.rawValue)",
            operation: "migration.setApplicationID"
        )
        guard try connection.scalarInt(
            "PRAGMA application_id",
            operation: "migration.verifyApplicationID"
        ) == Int64(StoreApplicationID.evidence.rawValue) else {
            throw EvidenceStoreError.schemaMismatch
        }
    }

    private static func validateCompatibility(
        _ connection: SQLiteConnection,
        expectedApplicationID: StoreApplicationID
    ) throws {
        let version = Int(try connection.scalarInt(
            "PRAGMA user_version",
            operation: "compatibility.version"
        ))
        guard version <= schemaVersion else {
            throw EvidenceStoreError.unsupportedFutureSchema(version: version)
        }
        let rawApplicationID = try connection.scalarInt(
            "PRAGMA application_id",
            operation: "compatibility.applicationID"
        )
        if rawApplicationID == 0 {
            try verifyUnclaimedSchema(connection, version: version)
            return
        }
        guard let actual = StoreApplicationID(
            rawValue: Int32(rawApplicationID)
        ) else {
            throw EvidenceStoreError.unknownApplicationID(
                value: Int32(rawApplicationID)
            )
        }
        guard actual == expectedApplicationID else {
            throw EvidenceStoreError.wrongApplicationID(
                expected: expectedApplicationID,
                actual: actual
            )
        }
        try verifyClaimedPreMigrationSchema(connection, version: version)
    }

    private static func migrate(
        _ connection: SQLiteConnection,
        testHooks: EvidenceStoreTestHooks
    ) throws {
        let version = Int(try connection.scalarInt(
            "PRAGMA user_version",
            operation: "migration.version"
        ))
        guard version <= schemaVersion else {
            throw EvidenceStoreError.unsupportedFutureSchema(version: version)
        }
        guard version < schemaVersion else {
            return
        }
        do {
            try connection.transaction(operation: "migration.v1") {
                try claimRole(connection)
                if try connection.scalarInt(
                    """
                    SELECT count(*) FROM sqlite_master
                    WHERE type='table' AND name='legacy_scan_sessions'
                    """,
                    operation: "migration.legacyExists"
                ) > 0 {
                    try createSchema(connection)
                    try connection.execute(
                        """
                        INSERT INTO scan_sessions
                        (id, started_at_ms, finished_at_ms, expires_at_ms, payload)
                        SELECT id, started_at_ms, finished_at_ms, expires_at_ms, payload
                        FROM legacy_scan_sessions
                        """,
                        operation: "migration.copyLegacySessions"
                    )
                    try connection.execute(
                        "DROP TABLE legacy_scan_sessions",
                        operation: "migration.dropLegacy"
                    )
                } else {
                    try createSchema(connection)
                }
                if testHooks.failMigrationToVersion == 1 {
                    throw EvidenceStoreError.migrationFailed(version: 1)
                }
                try connection.execute(
                    "PRAGMA user_version=1",
                    operation: "migration.setVersion"
                )
            }
        } catch {
            throw EvidenceStoreError.migrationFailed(version: 1)
        }
    }

    private static func createSchema(
        _ connection: SQLiteConnection
    ) throws {
        for (operation, sql) in evidenceSchemaStatements {
            try connection.execute(sql, operation: operation)
        }
    }

    private static func verifyIntegrity(
        _ connection: SQLiteConnection
    ) throws {
        guard try connection.scalarText(
            "PRAGMA quick_check",
            operation: "integrity.quickCheck"
        ).lowercased() == "ok" else {
            throw EvidenceStoreError.integrityCheckFailed
        }
        let foreignKeyViolations = try connection.query(
            "PRAGMA foreign_key_check",
            operation: "integrity.foreignKeys"
        ) { _ in true }
        guard foreignKeyViolations.isEmpty else {
            throw EvidenceStoreError.integrityCheckFailed
        }
    }

    private func saveRecords<T: Encodable>(
        _ records: [T],
        table: String,
        id: (T) -> String,
        parentID: (T) -> String,
        parentColumn: String,
        timestamp: (T) -> Date,
        operation: String
    ) throws {
        try Task.checkCancellation()
        try connection.transaction(operation: operation) {
            for record in records {
                try Task.checkCancellation()
                let payload = try encodeStorePayload(record)
                try connection.execute(
                    """
                    INSERT INTO \(table)
                    (id, \(parentColumn), \(timestampColumn(for: table)), payload)
                    VALUES (?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        \(parentColumn)=excluded.\(parentColumn),
                        \(timestampColumn(for: table))=excluded.\(timestampColumn(for: table)),
                        payload=excluded.payload
                    """,
                    bindings: [
                        .text(id(record)),
                        .text(parentID(record)),
                        .integer(storeMilliseconds(timestamp(record))),
                        .text(payload),
                    ],
                    operation: operation
                )
            }
        }
    }

    private func saveSingleton(
        table: String,
        id: String,
        parentColumn: String,
        parentID: String,
        payload: Data,
        operation: String
    ) throws {
        try connection.execute(
            """
            INSERT INTO \(table) (id, \(parentColumn), payload)
            VALUES (?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                \(parentColumn)=excluded.\(parentColumn),
                payload=excluded.payload
            """,
            bindings: [
                .text(id),
                .text(parentID),
                .text(try boundedPayloadString(payload)),
            ],
            operation: operation
        )
    }

    private func saveExpiringRecord(
        table: String,
        id: String,
        parentID: String,
        parentColumn: String,
        timestampColumn: String,
        timestamp: Date,
        expiresAt: Date,
        maximumLifetimeMilliseconds: Int64,
        payload: Data,
        operation: String
    ) throws {
        let timestampMilliseconds = storeMilliseconds(timestamp)
        let retentionDeadline = addingStoreMilliseconds(
            maximumLifetimeMilliseconds,
            to: timestampMilliseconds
        )
        let requestedExpiry = storeMilliseconds(expiresAt)
        guard requestedExpiry <= retentionDeadline else {
            throw EvidenceStoreError.retentionLimitExceeded
        }
        try connection.execute(
            """
            INSERT INTO \(table)
            (id, \(parentColumn), \(timestampColumn), expires_at_ms, payload)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                \(parentColumn)=excluded.\(parentColumn),
                \(timestampColumn)=excluded.\(timestampColumn),
                expires_at_ms=excluded.expires_at_ms,
                payload=excluded.payload
            """,
            bindings: [
                .text(id),
                .text(parentID),
                .integer(timestampMilliseconds),
                .integer(requestedExpiry),
                .text(try boundedPayloadString(payload)),
            ],
            operation: operation
        )
    }

    private func decodeOne<T: Decodable>(
        table: String,
        id: String,
        type: T.Type,
        recordID: (T) -> String,
        storageColumns: String = "",
        validateStorage: (T, OpaquePointer) -> Bool = { _, _ in true },
        operation: String
    ) throws -> T? {
        let records = try connection.query(
            "SELECT payload\(storageColumns) FROM \(table) WHERE id = ?",
            bindings: [.text(id)],
            operation: operation
        ) { statement -> T in
            let record = try DomainJSON.decode(
                type,
                from: Data(columnText(statement, 0).utf8)
            )
            guard recordID(record) == id,
                  validateStorage(record, statement)
            else {
                throw EvidenceStoreError.recordIdentityMismatch
            }
            return record
        }
        guard let record = records.first else {
            return nil
        }
        return record
    }

    private func decodePage<T: Decodable & Sendable>(
        sql: String,
        bindings: [SQLiteValue],
        type: T.Type,
        recordID: (T) -> String,
        validateStorage: (T, OpaquePointer) -> Bool = { _, _ in true },
        operation: String
    ) throws -> StorePage<T> {
        let rows = try connection.query(
            sql,
            bindings: bindings,
            operation: operation
        ) { statement -> StoreDecodedRow<T> in
            let id = columnText(statement, 0)
            let payload = columnText(statement, 1)
            do {
                let record = try DomainJSON.decode(type, from: Data(payload.utf8))
                guard recordID(record) == id,
                      validateStorage(record, statement)
                else {
                    throw EvidenceStoreError.recordIdentityMismatch
                }
                return .record(record)
            } catch {
                return .corrupt(id)
            }
        }
        var records: [T] = []
        var corrupt: [String] = []
        for row in rows {
            switch row {
            case let .record(record):
                records.append(record)
            case let .corrupt(id):
                corrupt.append(id)
            }
        }
        return StorePage(records: records, corruptRecordIDs: corrupt)
    }

    private func validatePage(limit: Int, offset: Int) throws {
        guard limit > 0,
              limit <= maximumStorePageSize,
              offset >= 0
        else {
            throw EvidenceStoreError.invalidPage
        }
    }

    private func boundedPayloadString(_ data: Data) throws -> String {
        guard data.count <= maximumStorePayloadBytes else {
            throw EvidenceStoreError.payloadTooLarge(
                limit: maximumStorePayloadBytes
            )
        }
        return String(decoding: data, as: UTF8.self)
    }

    private func timestampColumn(for table: String) -> String {
        switch table {
        case "classifications":
            "classified_at_ms"
        default:
            "observed_at_ms"
        }
    }
}

private enum StoreDecodedRow<Record> {
    case record(Record)
    case corrupt(String)
}

private let evidenceSchemaStatements: [(String, String)] = [
    (
        "schema.scanSessions",
        """
        CREATE TABLE IF NOT EXISTS scan_sessions (
            id TEXT PRIMARY KEY NOT NULL,
            started_at_ms INTEGER NOT NULL,
            finished_at_ms INTEGER NOT NULL,
            expires_at_ms INTEGER NOT NULL,
            payload TEXT NOT NULL
        ) STRICT
        """
    ),
    (
        "schema.pathSnapshots",
        """
        CREATE TABLE IF NOT EXISTS path_snapshots (
            id TEXT PRIMARY KEY NOT NULL,
            session_id TEXT NOT NULL REFERENCES scan_sessions(id) ON DELETE CASCADE,
            relative_path TEXT NOT NULL,
            observed_at_ms INTEGER NOT NULL,
            payload TEXT NOT NULL
        ) STRICT
        """
    ),
    (
        "schema.classifications",
        """
        CREATE TABLE IF NOT EXISTS classifications (
            id TEXT PRIMARY KEY NOT NULL,
            snapshot_id TEXT NOT NULL REFERENCES path_snapshots(id) ON DELETE CASCADE,
            disposition TEXT NOT NULL,
            classified_at_ms INTEGER NOT NULL,
            payload TEXT NOT NULL
        ) STRICT
        """
    ),
    (
        "schema.evidence",
        """
        CREATE TABLE IF NOT EXISTS evidence (
            id TEXT PRIMARY KEY NOT NULL,
            snapshot_id TEXT NOT NULL REFERENCES path_snapshots(id) ON DELETE CASCADE,
            observed_at_ms INTEGER NOT NULL,
            payload TEXT NOT NULL
        ) STRICT
        """
    ),
    (
        "schema.accounting",
        """
        CREATE TABLE IF NOT EXISTS space_accounting (
            id TEXT PRIMARY KEY NOT NULL,
            session_id TEXT NOT NULL REFERENCES scan_sessions(id) ON DELETE CASCADE,
            payload TEXT NOT NULL
        ) STRICT
        """
    ),
    (
        "schema.cleanupPlans",
        """
        CREATE TABLE IF NOT EXISTS cleanup_plans (
            id TEXT PRIMARY KEY NOT NULL,
            session_id TEXT NOT NULL REFERENCES scan_sessions(id) ON DELETE CASCADE,
            created_at_ms INTEGER NOT NULL,
            expires_at_ms INTEGER NOT NULL,
            payload TEXT NOT NULL
        ) STRICT
        """
    ),
    (
        "schema.policyDecisions",
        """
        CREATE TABLE IF NOT EXISTS policy_decisions (
            id TEXT PRIMARY KEY NOT NULL,
            plan_id TEXT NOT NULL REFERENCES cleanup_plans(id) ON DELETE CASCADE,
            payload TEXT NOT NULL
        ) STRICT
        """
    ),
    (
        "schema.cleanupManifests",
        """
        CREATE TABLE IF NOT EXISTS cleanup_manifests (
            id TEXT PRIMARY KEY NOT NULL,
            plan_id TEXT NOT NULL,
            created_at_ms INTEGER NOT NULL,
            expires_at_ms INTEGER NOT NULL,
            payload TEXT NOT NULL
        ) STRICT
        """
    ),
    (
        "schema.scanTimeIndex",
        "CREATE INDEX IF NOT EXISTS idx_scan_sessions_finished ON scan_sessions(finished_at_ms DESC, id)"
    ),
    (
        "schema.snapshotPathIndex",
        "CREATE INDEX IF NOT EXISTS idx_path_snapshots_session_relative ON path_snapshots(session_id, relative_path, id)"
    ),
    (
        "schema.classificationIndex",
        "CREATE INDEX IF NOT EXISTS idx_classifications_snapshot ON classifications(snapshot_id, classified_at_ms, id)"
    ),
    (
        "schema.classificationDispositionIndex",
        "CREATE INDEX IF NOT EXISTS idx_classifications_disposition ON classifications(disposition, classified_at_ms DESC, id)"
    ),
    (
        "schema.evidenceIndex",
        "CREATE INDEX IF NOT EXISTS idx_evidence_snapshot ON evidence(snapshot_id, observed_at_ms, id)"
    ),
    (
        "schema.retentionIndex",
        "CREATE INDEX IF NOT EXISTS idx_scan_sessions_expiry ON scan_sessions(expires_at_ms)"
    ),
    (
        "schema.planRetentionIndex",
        "CREATE INDEX IF NOT EXISTS idx_cleanup_plans_expiry ON cleanup_plans(expires_at_ms)"
    ),
    (
        "schema.manifestRetentionIndex",
        "CREATE INDEX IF NOT EXISTS idx_cleanup_manifests_expiry ON cleanup_manifests(expires_at_ms)"
    ),
]

func storeMilliseconds(_ date: Date) -> Int64 {
    let value = date.timeIntervalSince1970 * 1_000
    guard value.isFinite else {
        return value.sign == .minus ? .min : .max
    }
    if value <= Double(Int64.min) {
        return .min
    }
    if value >= Double(Int64.max) {
        return .max
    }
    return Int64(value.rounded())
}

func addingStoreMilliseconds(_ delta: Int64, to value: Int64) -> Int64 {
    let (result, overflow) = value.addingReportingOverflow(delta)
    return overflow ? .max : result
}

func subtractingStoreMilliseconds(_ delta: Int64, from value: Int64) -> Int64 {
    let (result, overflow) = value.subtractingReportingOverflow(delta)
    return overflow ? .min : result
}

enum StoreQueryPlanKind: Sendable {
    case snapshotsBySession
    case classificationsByDisposition
    case sessionRetention
    case sessionHistory
}
