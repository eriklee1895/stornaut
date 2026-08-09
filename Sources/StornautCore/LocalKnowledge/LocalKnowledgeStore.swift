import Foundation
import SQLite3

public enum LocalKnowledgeIDTag: DomainIDTag {
    public static let prefix = "knowledge-"
}

public typealias LocalKnowledgeID = DomainID<LocalKnowledgeIDTag>

public enum LocalKnowledgeKind: String, Codable, Sendable, CaseIterable {
    case producerMapping
    case pathPreference
    case keepDecision
    case recoveryMethod
}

public struct LocalKnowledgeFact: Codable, Sendable, Equatable {
    public let id: LocalKnowledgeID
    public let kind: LocalKnowledgeKind
    public let scope: PersistedPath
    public let value: DomainLabel
    public let provenance: DomainToken
    public let updatedAt: Date
    public let stale: Bool

    public init(
        id: LocalKnowledgeID,
        kind: LocalKnowledgeKind,
        scope: PersistedPath,
        value: DomainLabel,
        provenance: DomainToken,
        updatedAt: Date,
        stale: Bool
    ) throws {
        self.id = id
        self.kind = kind
        self.scope = scope
        self.value = value
        self.provenance = provenance
        self.updatedAt = updatedAt
        self.stale = stale
    }
}

public actor LocalKnowledgeStore {
    private static let schemaVersion = 1
    private let connection: SQLiteConnection

    public init(configuration: LocalStoreConfiguration) throws {
        try LocalStorePathPolicy.prepare(
            configuration: configuration,
            databaseURL: configuration.localKnowledgeDatabaseURL
        )
        try verifySQLiteHeaderIfPresent(
            configuration.localKnowledgeDatabaseURL,
            isMemory: configuration.isMemory
        )
        let connection = try SQLiteConnection(
            path: configuration.isMemory
                ? ":memory:"
                : configuration.localKnowledgeDatabaseURL.path
        )
        self.connection = connection
        try Self.validateCompatibility(connection)
        try Self.configureConnection(connection)
        try Self.verifyIntegrity(connection)
        try Self.migrate(connection)
        try Self.verifySchema(connection)
        try Self.finalizeRole(connection)
        try Self.verifyIntegrity(connection)
        try LocalStorePathPolicy.finalizeDatabase(
            configuration.localKnowledgeDatabaseURL,
            isMemory: configuration.isMemory,
            excludeFromBackup: false
        )
    }

    public func save(_ fact: LocalKnowledgeFact) throws {
        try connection.execute(
            """
            INSERT INTO local_knowledge
            (id, kind, scope, updated_at_ms, payload)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                kind=excluded.kind,
                scope=excluded.scope,
                updated_at_ms=excluded.updated_at_ms,
                payload=excluded.payload
            """,
            bindings: [
                .text(fact.id.rawValue),
                .text(fact.kind.rawValue),
                .text(fact.scope.rawValue),
                .integer(storeMilliseconds(fact.updatedAt)),
                .text(try encodeStorePayload(fact)),
            ],
            operation: "knowledge.save"
        )
    }

    public func fact(id: LocalKnowledgeID) throws -> LocalKnowledgeFact? {
        let rows = try connection.query(
            """
            SELECT payload, kind, scope, updated_at_ms
            FROM local_knowledge WHERE id = ?
            """,
            bindings: [.text(id.rawValue)],
            operation: "knowledge.load"
        ) { statement -> LocalKnowledgeFact in
            let fact = try DomainJSON.decode(
                LocalKnowledgeFact.self,
                from: Data(columnText(statement, 0).utf8)
            )
            guard fact.id == id,
                  columnText(statement, 1) == fact.kind.rawValue,
                  columnText(statement, 2) == fact.scope.rawValue,
                  sqlite3_column_int64(statement, 3)
                    == storeMilliseconds(fact.updatedAt)
            else {
                throw EvidenceStoreError.recordIdentityMismatch
            }
            return fact
        }
        guard let fact = rows.first else {
            return nil
        }
        return fact
    }

    public func forget(id: LocalKnowledgeID) throws {
        try connection.execute(
            "DELETE FROM local_knowledge WHERE id = ?",
            bindings: [.text(id.rawValue)],
            operation: "knowledge.forget"
        )
    }

    public func forgetAll() throws {
        try connection.execute(
            "DELETE FROM local_knowledge",
            operation: "knowledge.forgetAll"
        )
    }

    public func facts(
        limit: Int,
        offset: Int
    ) throws -> StorePage<LocalKnowledgeFact> {
        guard limit > 0, limit <= maximumStorePageSize, offset >= 0 else {
            throw EvidenceStoreError.invalidPage
        }
        let rows = try connection.query(
            """
            SELECT id, payload, kind, scope, updated_at_ms
            FROM local_knowledge
            ORDER BY updated_at_ms DESC, id ASC
            LIMIT ? OFFSET ?
            """,
            bindings: [.integer(Int64(limit)), .integer(Int64(offset))],
            operation: "knowledge.page"
        ) { statement -> KnowledgeDecodedRow in
            let id = columnText(statement, 0)
            let payload = columnText(statement, 1)
            do {
                let fact = try DomainJSON.decode(
                    LocalKnowledgeFact.self,
                    from: Data(payload.utf8)
                )
                guard fact.id.rawValue == id,
                      columnText(statement, 2) == fact.kind.rawValue,
                      columnText(statement, 3) == fact.scope.rawValue,
                      sqlite3_column_int64(statement, 4)
                        == storeMilliseconds(fact.updatedAt)
                else {
                    throw EvidenceStoreError.recordIdentityMismatch
                }
                return .record(fact)
            } catch {
                return .corrupt(id)
            }
        }
        var records: [LocalKnowledgeFact] = []
        var corrupt: [String] = []
        for row in rows {
            switch row {
            case let .record(fact):
                records.append(fact)
            case let .corrupt(id):
                corrupt.append(id)
            }
        }
        return StorePage(records: records, corruptRecordIDs: corrupt)
    }

    func _testInsertMalformedFact(id: String, payload: String) throws {
        try connection.execute(
            """
            INSERT INTO local_knowledge
            (id, kind, scope, updated_at_ms, payload)
            VALUES (?, 'keepDecision', 'fixture/malformed', 0, ?)
            """,
            bindings: [.text(id), .text(payload)],
            operation: "knowledge.test.malformed"
        )
    }

    private static func configureConnection(
        _ connection: SQLiteConnection
    ) throws {
        try connection.execute(
            "PRAGMA foreign_keys=ON",
            operation: "knowledge.foreignKeys"
        )
        try connection.execute(
            "PRAGMA synchronous=FULL",
            operation: "knowledge.synchronous"
        )
        try connection.execute(
            "PRAGMA trusted_schema=OFF",
            operation: "knowledge.trustedSchema"
        )
        try connection.execute(
            "PRAGMA writable_schema=OFF",
            operation: "knowledge.writableSchema"
        )
    }

    private static func finalizeRole(
        _ connection: SQLiteConnection
    ) throws {
        let mode = try connection.scalarText(
            "PRAGMA journal_mode=DELETE",
            operation: "knowledge.journalMode"
        ).lowercased()
        guard mode == "delete" || mode == "memory" else {
            throw EvidenceStoreError.sqlite(
                operation: "knowledge.journalMode",
                code: SQLITE_ERROR,
                extendedCode: SQLITE_ERROR
            )
        }
        let rawID = try connection.scalarInt(
            "PRAGMA application_id",
            operation: "knowledge.applicationID"
        )
        guard rawID == Int64(StoreApplicationID.localKnowledge.rawValue) else {
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
            operation: "knowledge.schema.objects"
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
            operation: "knowledge.schema.signature"
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

    private static func verifySchema(_ connection: SQLiteConnection) throws {
        let expected = try SQLiteConnection(path: ":memory:")
        try configureConnection(expected)
        try createSchema(expected)
        guard try schemaSignature(connection) == schemaSignature(expected) else {
            throw EvidenceStoreError.schemaMismatch
        }
    }

    private static func claimRole(_ connection: SQLiteConnection) throws {
        try connection.execute(
            "PRAGMA application_id=\(StoreApplicationID.localKnowledge.rawValue)",
            operation: "knowledge.setApplicationID"
        )
        guard try connection.scalarInt(
            "PRAGMA application_id",
            operation: "knowledge.verifyApplicationID"
        ) == Int64(StoreApplicationID.localKnowledge.rawValue) else {
            throw EvidenceStoreError.schemaMismatch
        }
    }

    private static func validateCompatibility(
        _ connection: SQLiteConnection
    ) throws {
        let version = Int(try connection.scalarInt(
            "PRAGMA user_version",
            operation: "knowledge.compatibility.version"
        ))
        guard version <= schemaVersion else {
            throw EvidenceStoreError.unsupportedFutureSchema(version: version)
        }
        let rawID = try connection.scalarInt(
            "PRAGMA application_id",
            operation: "knowledge.compatibility.applicationID"
        )
        if rawID == 0 {
            guard version == 0,
                  try schemaObjects(connection).isEmpty
            else {
                throw EvidenceStoreError.unrecognizedUnclaimedDatabase
            }
            return
        }
        guard let actual = StoreApplicationID(rawValue: Int32(rawID)) else {
            throw EvidenceStoreError.unknownApplicationID(value: Int32(rawID))
        }
        guard actual == .localKnowledge else {
            throw EvidenceStoreError.wrongApplicationID(
                expected: .localKnowledge,
                actual: actual
            )
        }
        guard version == schemaVersion else {
            throw EvidenceStoreError.schemaMismatch
        }
    }

    private static func migrate(_ connection: SQLiteConnection) throws {
        let version = Int(try connection.scalarInt(
            "PRAGMA user_version",
            operation: "knowledge.version"
        ))
        guard version <= schemaVersion else {
            throw EvidenceStoreError.unsupportedFutureSchema(version: version)
        }
        guard version < schemaVersion else {
            return
        }
        do {
            try connection.transaction(operation: "knowledge.migration.v1") {
                try claimRole(connection)
                try createSchema(connection)
                try connection.execute(
                    "PRAGMA user_version=1",
                    operation: "knowledge.setVersion"
                )
            }
        } catch {
            throw EvidenceStoreError.migrationFailed(version: 1)
        }
    }

    private static func createSchema(_ connection: SQLiteConnection) throws {
        try connection.execute(
            """
            CREATE TABLE local_knowledge (
                id TEXT PRIMARY KEY NOT NULL,
                kind TEXT NOT NULL,
                scope TEXT NOT NULL,
                updated_at_ms INTEGER NOT NULL,
                payload TEXT NOT NULL
            ) STRICT
            """,
            operation: "knowledge.schema"
        )
        try connection.execute(
            "CREATE INDEX idx_local_knowledge_scope ON local_knowledge(scope, kind, id)",
            operation: "knowledge.scopeIndex"
        )
    }

    private static func verifyIntegrity(
        _ connection: SQLiteConnection
    ) throws {
        guard try connection.scalarText(
            "PRAGMA quick_check",
            operation: "knowledge.preflightIntegrity"
        ).lowercased() == "ok" else {
            throw EvidenceStoreError.integrityCheckFailed
        }
    }
}

private enum KnowledgeDecodedRow {
    case record(LocalKnowledgeFact)
    case corrupt(String)
}
