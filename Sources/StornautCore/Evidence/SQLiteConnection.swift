import CSQLiteSupport
import Foundation
import SQLite3

public enum EvidenceStoreError: Error, Sendable, Equatable {
    case unsafeStoragePath
    case openFailed(code: Int32)
    case sqlite(operation: String, code: Int32, extendedCode: Int32)
    case storeBusy
    case operationCancelled
    case operationDeadlineExceeded
    case rollbackUnconfirmed
    case authorizationViolation
    case unsupportedFutureSchema(version: Int)
    case wrongApplicationID(
        expected: StoreApplicationID,
        actual: StoreApplicationID
    )
    case unknownApplicationID(value: Int32)
    case unrecognizedUnclaimedDatabase
    case schemaMismatch
    case recordIdentityMismatch
    case migrationFailed(version: Int)
    case integrityCheckFailed
    case invalidPage
    case retentionLimitExceeded
    case payloadTooLarge(limit: Int)
    case legacyCleanupRecord
    case immutableRecordConflict
    case invalidJournalTransition
}

public enum EvidenceStoreHealth: String, Sendable, Equatable {
    case ready
    case rollbackUnconfirmed
}

enum SQLiteValue: Sendable {
    case integer(Int64)
    case text(String)
    case blob(Data)
    case null
}

#if DEBUG
enum SQLiteInvestigationAuthorizationProbe: Sendable {
    case defaultWrite
    case wrongInsertTable
    case wrongUpdateColumn
    case nestedMode
    case schemaMutationOutsideMigration
}
#endif

struct SQLiteConnectionTestHooks: Sendable {
    let monotonicNanoseconds: @Sendable () -> UInt64
    let isCancelled: @Sendable () -> Bool
    let investigationProgress:
        @Sendable (InvestigationStoreProgress) -> Void
    let forceRollbackUnconfirmedOperations: Set<String>

    init(
        monotonicNanoseconds: @escaping @Sendable () -> UInt64 = {
            DispatchTime.now().uptimeNanoseconds
        },
        isCancelled: @escaping @Sendable () -> Bool = {
            Task<Never, Never>.isCancelled
        },
        investigationProgress: @escaping @Sendable (
            InvestigationStoreProgress
        ) -> Void = { _ in },
        forceRollbackUnconfirmedOperations: Set<String> = []
    ) {
        self.monotonicNanoseconds = monotonicNanoseconds
        self.isCancelled = isCancelled
        self.investigationProgress = investigationProgress
        self.forceRollbackUnconfirmedOperations =
            forceRollbackUnconfirmedOperations
    }
}

private enum SQLiteInvestigationAuthorizationMode {
    case deny
    case migration
    case insert(table: String)
    case update(table: String, columns: Set<String>)
    case delete(table: String)
    case ownerDelete
    case sourceStagingCreate
}

private enum SQLiteOperationInterruption {
    case cancelled
    case deadlineExceeded
}

private final class SQLiteOperationControl {
    let deadlineNanoseconds: UInt64
    let monotonicNanoseconds: @Sendable () -> UInt64
    let isCancelled: @Sendable () -> Bool
    var interruption: SQLiteOperationInterruption?

    init(
        startedAtNanoseconds: UInt64,
        durationNanoseconds: UInt64,
        monotonicNanoseconds: @escaping @Sendable () -> UInt64,
        isCancelled: @escaping @Sendable () -> Bool
    ) throws {
        let deadline = startedAtNanoseconds.addingReportingOverflow(
            durationNanoseconds
        )
        guard !deadline.overflow else {
            throw EvidenceStoreError.operationDeadlineExceeded
        }
        deadlineNanoseconds = deadline.partialValue
        self.monotonicNanoseconds = monotonicNanoseconds
        self.isCancelled = isCancelled
    }

    func shouldInterrupt() -> Bool {
        if isCancelled() {
            interruption = .cancelled
            return true
        }
        if monotonicNanoseconds() >= deadlineNanoseconds {
            interruption = .deadlineExceeded
            return true
        }
        return false
    }
}

private let sqliteOperationProgressCallback:
    @convention(c) (UnsafeMutableRawPointer?) -> Int32 =
{ context in
    guard let context else {
        return 1
    }
    let connection = Unmanaged<SQLiteConnection>
        .fromOpaque(context)
        .takeUnretainedValue()
    return connection.operationShouldInterrupt() ? 1 : 0
}

private let sqliteInvestigationAuthorizerCallback:
    @convention(c) (
        UnsafeMutableRawPointer?,
        Int32,
        UnsafePointer<CChar>?,
        UnsafePointer<CChar>?,
        UnsafePointer<CChar>?,
        UnsafePointer<CChar>?
    ) -> Int32 =
{ context, action, first, second, _, _ in
    guard let context else {
        return SQLITE_DENY
    }
    let connection = Unmanaged<SQLiteConnection>
        .fromOpaque(context)
        .takeUnretainedValue()
    return connection.authorize(
        action: action,
        first: first.map(String.init(cString:)),
        second: second.map(String.init(cString:))
    )
}

final class SQLiteConnection: @unchecked Sendable {
    private let database: OpaquePointer
    private let testHooks: SQLiteConnectionTestHooks
    private var authorizationMode: SQLiteInvestigationAuthorizationMode =
        .deny
    private var operationControl: SQLiteOperationControl?
    private var progressPhase: InvestigationStoreProgressPhase?
    private var progressRows: UInt64 = 0
    private var progressBytes: UInt64 = 0
    private var lastReportedProgressRows: UInt64 = 0
    private var lastReportedProgressBytes: UInt64 = 0
    private(set) var health: EvidenceStoreHealth = .ready

    init(
        path: String,
        testHooks: SQLiteConnectionTestHooks = SQLiteConnectionTestHooks()
    ) throws {
        var database: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE
            | SQLITE_OPEN_CREATE
            | SQLITE_OPEN_FULLMUTEX
            | SQLITE_OPEN_NOFOLLOW
            | SQLITE_OPEN_EXRESCODE
            | SQLITE_OPEN_PRIVATECACHE
        let code = sqlite3_open_v2(path, &database, flags, nil)
        guard code == SQLITE_OK, let database else {
            if let database {
                sqlite3_close_v2(database)
            }
            throw EvidenceStoreError.openFailed(code: code)
        }
        self.database = database
        self.testHooks = testHooks
        sqlite3_extended_result_codes(database, 1)
        sqlite3_busy_timeout(database, 2_000)
        let authorizerCode = sqlite3_set_authorizer(
            database,
            sqliteInvestigationAuthorizerCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
        guard authorizerCode == SQLITE_OK else {
            sqlite3_close_v2(database)
            throw EvidenceStoreError.openFailed(code: authorizerCode)
        }
    }

    deinit {
        sqlite3_progress_handler(database, 0, nil, nil)
        sqlite3_set_authorizer(database, nil, nil)
        sqlite3_close_v2(database)
    }

    func execute(
        _ sql: String,
        bindings: [SQLiteValue] = [],
        operation: String
    ) throws {
        guard health == .ready else {
            throw EvidenceStoreError.rollbackUnconfirmed
        }
        try checkOperationControl()
        let statement = try prepare(sql, operation: operation)
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement, operation: operation)
        try checkOperationControl()
        let code = sqlite3_step(statement)
        guard code == SQLITE_DONE else {
            throw error(operation: operation, code: code)
        }
    }

    func executeBatch(
        _ sql: String,
        bindings rows: [[SQLiteValue]],
        operation: String
    ) throws {
        let statement = try prepare(sql, operation: operation)
        defer { sqlite3_finalize(statement) }
        for bindings in rows {
            try checkOperationControl()
            guard sqlite3_reset(statement) == SQLITE_OK,
                  sqlite3_clear_bindings(statement) == SQLITE_OK
            else {
                throw error(operation: operation, code: SQLITE_MISUSE)
            }
            try bind(bindings, to: statement, operation: operation)
            try checkOperationControl()
            let code = sqlite3_step(statement)
            guard code == SQLITE_DONE else {
                throw error(operation: operation, code: code)
            }
        }
    }

    func query<T>(
        _ sql: String,
        bindings: [SQLiteValue] = [],
        operation: String,
        row: (OpaquePointer) throws -> T
    ) throws -> [T] {
        guard health == .ready else {
            throw EvidenceStoreError.rollbackUnconfirmed
        }
        try checkOperationControl()
        let statement = try prepare(sql, operation: operation)
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement, operation: operation)
        var records: [T] = []
        while true {
            try checkOperationControl()
            let code = sqlite3_step(statement)
            switch code {
            case SQLITE_ROW:
                records.append(try row(statement))
            case SQLITE_DONE:
                return records
            default:
                throw error(operation: operation, code: code)
            }
        }
    }

    func scalarInt(
        _ sql: String,
        operation: String
    ) throws -> Int64 {
        let rows = try query(sql, operation: operation) {
            sqlite3_column_int64($0, 0)
        }
        guard let value = rows.first else {
            throw error(operation: operation, code: SQLITE_ERROR)
        }
        return value
    }

    func scalarText(
        _ sql: String,
        operation: String
    ) throws -> String {
        let rows = try query(sql, operation: operation) {
            columnText($0, 0)
        }
        guard let value = rows.first else {
            throw error(operation: operation, code: SQLITE_ERROR)
        }
        return value
    }

    func transaction<T>(
        operation: String,
        body: () throws -> T
    ) throws -> T {
        guard health == .ready else {
            throw EvidenceStoreError.rollbackUnconfirmed
        }
        let isBounded = Self.isBoundedInvestigationOperation(operation)
        defer {
            if operationControl != nil {
                endOperation()
            }
        }
        if isBounded {
            try beginOperation(durationNanoseconds: 90_000_000_000)
            reportInvestigationProgress(
                phase: .lockAcquisition,
                force: true
            )
        }
        do {
            try execute("BEGIN IMMEDIATE", operation: "\(operation).begin")
        } catch {
            throw error
        }
        do {
            let value = try body()
            try execute("COMMIT", operation: "\(operation).commit")
            return value
        } catch {
            reportInvestigationProgress(
                phase: .rollback,
                force: true
            )
            endOperation()
            if testHooks.forceRollbackUnconfirmedOperations
                .contains(operation)
            {
                health = .rollbackUnconfirmed
                throw EvidenceStoreError.rollbackUnconfirmed
            }
            do {
                try beginOperation(
                    durationNanoseconds: 5_000_000_000,
                    isCancelled: { false }
                )
                try execute(
                    "ROLLBACK",
                    operation: "\(operation).rollback"
                )
                guard sqlite3_get_autocommit(database) != 0 else {
                    throw EvidenceStoreError.rollbackUnconfirmed
                }
                endOperation()
            } catch {
                endOperation()
                health = .rollbackUnconfirmed
                throw EvidenceStoreError.rollbackUnconfirmed
            }
            throw error
        }
    }

    func enableDefensiveMode() throws {
        var enabled: Int32 = 0
        let code = stornaut_sqlite_enable_defensive(
            database,
            &enabled
        )
        guard code == SQLITE_OK, enabled == 1 else {
            throw error(operation: "configure.defensive", code: code)
        }
    }

#if DEBUG
    func runAuthorizationProbe(
        _ probe: SQLiteInvestigationAuthorizationProbe
    ) throws {
        switch probe {
        case .defaultWrite:
            try prepareAuthorizationProbe(
                """
                UPDATE investigation_sessions
                SET state = state
                WHERE 0
                """,
                mode: .deny
            )
        case .wrongInsertTable:
            try prepareAuthorizationProbe(
                """
                INSERT INTO investigation_sessions (
                    id, scan_session_id, scan_scope_id, source_fingerprint,
                    state, stage, source_row_count, relevance_token_count,
                    source_payload_byte_count, source_canonical_byte_count,
                    created_at_ms, updated_at_ms, expires_at_ms
                ) VALUES (
                    'investigation-probe', 'scan-probe', 'scope-probe',
                    zeroblob(32), 'planned', 'prioritize', 2, 0, 1, 1,
                    0, 0, 1
                )
                """,
                mode: .insert(table: "investigation_runs")
            )
        case .wrongUpdateColumn:
            try prepareAuthorizationProbe(
                """
                UPDATE investigation_sessions
                SET stage = stage
                WHERE 0
                """,
                mode: .update(
                    table: "investigation_sessions",
                    columns: ["state"]
                )
            )
        case .nestedMode:
            guard case .deny = authorizationMode else {
                throw EvidenceStoreError.authorizationViolation
            }
            authorizationMode = .insert(table: "investigation_sessions")
            defer { authorizationMode = .deny }
            let statement = try prepare(
                "SELECT 1",
                operation: "investigation.load"
            )
            sqlite3_finalize(statement)
        case .schemaMutationOutsideMigration:
            try prepareAuthorizationProbe(
                "CREATE TABLE investigation_probe (id INTEGER)",
                mode: .deny
            )
        }
    }
#endif

    func backup(to destinationPath: String) throws {
        let destination = try SQLiteConnection(path: destinationPath)
        guard let backup = sqlite3_backup_init(
            destination.database,
            "main",
            database,
            "main"
        ) else {
            throw destination.error(
                operation: "backup.initialize",
                code: sqlite3_errcode(destination.database)
            )
        }
        let stepCode = sqlite3_backup_step(backup, -1)
        let finishCode = sqlite3_backup_finish(backup)
        guard stepCode == SQLITE_DONE, finishCode == SQLITE_OK else {
            throw destination.error(
                operation: "backup.copy",
                code: stepCode == SQLITE_DONE ? finishCode : stepCode
            )
        }
    }

    func createInvestigationSource(
        investigationID: InvestigationID,
        scanSessionID: ScanSessionID,
        scanScopeID: ScanScopeID,
        relevanceTokens: [DomainToken],
        planningAt: Date
    ) throws -> InvestigationSourceProjection {
        reportInvestigationProgress(
            phase: .sourceProjection,
            force: true
        )
        try execute(
            investigationSourceStagingSchema,
            operation: "investigation.sourceStaging.create"
        )
        try execute(
            "DELETE FROM investigation_source_staging",
            operation: "investigation.sourceStaging.clear"
        )
        var factory = SQLiteInvestigationSourceFactory(
            connection: self,
            scanSessionID: scanSessionID,
            scanScopeID: scanScopeID,
            relevanceTokens: relevanceTokens
        )
        let statement = try prepare(
            investigationSourceStagingInsert,
            operation: "investigation.sourceStaging.prepare"
        )
        defer { sqlite3_finalize(statement) }
        var sink = SQLiteInvestigationManifestStagingSink(
            connection: self,
            statement: statement
        )
        let projection = try InvestigationSourceProjectionBuilder().build(
            factory: &factory,
            planningAt: planningAt,
            manifestSink: &sink
        )
        try sink.finish(expectedRowCount: projection.summary.sourceRowCount)
        return projection
    }

    func persistStagedInvestigationSource(
        investigationID: InvestigationID
    ) throws {
        reportInvestigationProgress(
            phase: .persistence,
            force: true
        )
        for family in SQLiteInvestigationSourceFamily.manifestPersistenceOrder {
            try execute(
                family.manifestInsertQuery,
                bindings: [.text(investigationID.rawValue)],
                operation: "investigation.sourceManifest.persist"
            )
        }
    }

    func rejoinInvestigationSource(
        investigationID: InvestigationID,
        scanSessionID: ScanSessionID,
        scanScopeID: ScanScopeID,
        relevanceTokens: [DomainToken],
        planningAt: Date
    ) throws -> InvestigationSourceProjection {
        reportInvestigationProgress(
            phase: .sourceProjection,
            force: true
        )
        var factory = SQLiteInvestigationSourceFactory(
            connection: self,
            scanSessionID: scanSessionID,
            scanScopeID: scanScopeID,
            relevanceTokens: relevanceTokens
        )
        let statement = try prepare(
            investigationSourceManifestSelect,
            operation: "investigation.sourceManifest.load"
        )
        defer { sqlite3_finalize(statement) }
        do {
            try bind(
                [.text(investigationID.rawValue)],
                to: statement,
                operation: "investigation.sourceManifest.load"
            )
        } catch {
            throw error
        }
        var sink = SQLiteInvestigationManifestCompareSink(
            connection: self,
            statement: statement
        )
        let projection = try InvestigationSourceProjectionBuilder().build(
            factory: &factory,
            planningAt: planningAt,
            manifestSink: &sink
        )
        try sink.finish(expectedRowCount: projection.summary.sourceRowCount)
        return projection
    }

    func investigationSourceQueryPlans(
        scanSessionID: ScanSessionID,
        scanScopeID: ScanScopeID
    ) throws -> [String: String] {
        var plans: [String: String] = [:]
        for family in SQLiteInvestigationSourceFamily.allCases {
            plans[family.rowKind.rawValue] = try query(
                "EXPLAIN QUERY PLAN\n\(family.query)",
                bindings: family.bindings(
                    scanSessionID: scanSessionID,
                    scanScopeID: scanScopeID
                ),
                operation:
                    "test.investigationSourceQueryPlan."
                    + family.rowKind.rawValue
            ) {
                columnText($0, 3)
            }.joined(separator: "\n")
        }
        return plans
    }

    func reportInvestigationPlanningProgress() {
        reportInvestigationProgress(
            phase: .planning,
            force: true
        )
    }

    func verifyInvestigationSourceRowCount(
        investigationID: InvestigationID,
        expectedRowCount: UInt64
    ) throws -> Bool {
        reportInvestigationProgress(
            phase: .verification,
            force: true
        )
        guard let expected = Int64(exactly: expectedRowCount) else {
            return false
        }
        let result = try query(
            """
            SELECT count(*), min(ordinal), max(ordinal)
            FROM investigation_source_rows
            WHERE investigation_id = ?
            """,
            bindings: [.text(investigationID.rawValue)],
            operation: "investigation.sourceManifest.verifyCount"
        ) {
            (
                count: sqlite3_column_int64($0, 0),
                minimum: sqlite3_column_int64($0, 1),
                maximum: sqlite3_column_int64($0, 2)
            )
        }.first
        guard let result else {
            return false
        }
        return result.count == expected
            && result.minimum == 0
            && result.maximum == expected - 1
    }

#if DEBUG
    func serializedDatabase() throws -> Data {
        var size: sqlite3_int64 = 0
        guard let bytes = sqlite3_serialize(
            database,
            "main",
            &size,
            0
        ), size >= 0, size <= Int.max
        else {
            throw error(
                operation: "diagnostic.serialize",
                code: sqlite3_errcode(database)
            )
        }
        defer { sqlite3_free(bytes) }
        return Data(bytes: bytes, count: Int(size))
    }
#endif

    fileprivate func prepare(
        _ sql: String,
        operation: String
    ) throws -> OpaquePointer {
        try checkOperationControl()
        let mode = Self.authorizationMode(for: operation)
        guard case .deny = authorizationMode else {
            throw EvidenceStoreError.authorizationViolation
        }
        authorizationMode = mode
        defer { authorizationMode = .deny }
        var statement: OpaquePointer?
        let code = sqlite3_prepare_v3(
            database,
            sql,
            -1,
            UInt32(SQLITE_PREPARE_PERSISTENT),
            &statement,
            nil
        )
        guard code == SQLITE_OK, let statement else {
            throw error(operation: operation, code: code)
        }
        return statement
    }

    fileprivate func bind(
        _ bindings: [SQLiteValue],
        to statement: OpaquePointer,
        operation: String
    ) throws {
        try checkOperationControl()
        guard sqlite3_bind_parameter_count(statement) == bindings.count else {
            throw error(operation: operation, code: SQLITE_MISUSE)
        }
        for (offset, binding) in bindings.enumerated() {
            let index = Int32(offset + 1)
            let code: Int32
            switch binding {
            case let .integer(value):
                code = sqlite3_bind_int64(statement, index, value)
            case let .text(value):
                code = value.withCString {
                    sqlite3_bind_text(
                        statement,
                        index,
                        $0,
                        -1,
                        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                    )
                }
            case let .blob(value):
                guard value.count <= Int(Int32.max) else {
                    throw error(operation: operation, code: SQLITE_TOOBIG)
                }
                if value.isEmpty {
                    code = sqlite3_bind_zeroblob(statement, index, 0)
                } else {
                    code = value.withUnsafeBytes {
                        sqlite3_bind_blob(
                            statement,
                            index,
                            $0.baseAddress,
                            Int32($0.count),
                            unsafeBitCast(
                                -1,
                                to: sqlite3_destructor_type.self
                            )
                        )
                    }
                }
            case .null:
                code = sqlite3_bind_null(statement, index)
            }
            guard code == SQLITE_OK else {
                throw error(operation: operation, code: code)
            }
        }
    }

    fileprivate func error(
        operation: String,
        code: Int32
    ) -> Error {
        if health == .rollbackUnconfirmed {
            return EvidenceStoreError.rollbackUnconfirmed
        }
        if code & 0xFF == SQLITE_BUSY || code & 0xFF == SQLITE_LOCKED {
            return EvidenceStoreError.storeBusy
        }
        if code & 0xFF == SQLITE_INTERRUPT,
           let interruption = operationControl?.interruption
        {
            switch interruption {
            case .cancelled:
                return EvidenceStoreError.operationCancelled
            case .deadlineExceeded:
                return EvidenceStoreError.operationDeadlineExceeded
            }
        }
        if code & 0xFF == SQLITE_AUTH {
            return EvidenceStoreError.authorizationViolation
        }
        return EvidenceStoreError.sqlite(
            operation: operation,
            code: code & 0xFF,
            extendedCode: sqlite3_extended_errcode(database)
        )
    }

    fileprivate func operationShouldInterrupt() -> Bool {
        operationControl?.shouldInterrupt() ?? false
    }

    fileprivate func authorize(
        action: Int32,
        first: String?,
        second: String?
    ) -> Int32 {
        if action == SQLITE_ATTACH
            || action == SQLITE_DETACH
            || action == SQLITE_ALTER_TABLE
            || action == SQLITE_CREATE_VTABLE
            || action == SQLITE_DROP_VTABLE
        {
            return SQLITE_DENY
        }
        if action == SQLITE_PRAGMA,
           first?.lowercased() == "writable_schema",
           let second
        {
            let value = second.lowercased()
            return value == "off" || value == "0"
                ? SQLITE_OK : SQLITE_DENY
        }
        if action == SQLITE_FUNCTION,
           second?.lowercased() == "load_extension"
        {
            return SQLITE_DENY
        }
        switch action {
        case SQLITE_READ, SQLITE_SELECT, SQLITE_FUNCTION,
             SQLITE_RECURSIVE, SQLITE_TRANSACTION, SQLITE_SAVEPOINT,
             SQLITE_PRAGMA:
            return SQLITE_OK
        default:
            break
        }

        let table = first ?? ""
        switch authorizationMode {
        case .deny:
            return Self.involvesInvestigationData(
                action: action,
                first: first
            ) ? SQLITE_DENY : SQLITE_OK
        case .migration:
            if table == "sqlite_master" || table == "sqlite_temp_master" {
                return SQLITE_OK
            }
            if action == SQLITE_REINDEX {
                return Self.isInvestigationMigrationIndex(table)
                    ? SQLITE_OK : SQLITE_DENY
            }
            if action == SQLITE_CREATE_INDEX {
                let isAllowedNamedIndex =
                    Self.isInvestigationMigrationIndex(table)
                    && Self.isInvestigationMigrationIndexTable(second)
                let isAllowedAutomaticIndex =
                    table.hasPrefix("sqlite_autoindex_investigation_")
                    && second.map(Self.isInvestigationTable) == true
                return isAllowedNamedIndex || isAllowedAutomaticIndex
                    ? SQLITE_OK : SQLITE_DENY
            }
            switch action {
            case SQLITE_CREATE_TABLE, SQLITE_CREATE_TRIGGER:
                return table.hasPrefix("investigation_")
                    || second?.hasPrefix("investigation_") == true
                    ? SQLITE_OK : SQLITE_DENY
            default:
                return SQLITE_DENY
            }
        case let .insert(allowedTable):
            return action == SQLITE_INSERT && table == allowedTable
                ? SQLITE_OK : SQLITE_DENY
        case let .update(allowedTable, columns):
            return action == SQLITE_UPDATE
                && table == allowedTable
                && second.map(columns.contains) == true
                ? SQLITE_OK : SQLITE_DENY
        case let .delete(allowedTable):
            return action == SQLITE_DELETE && table == allowedTable
                ? SQLITE_OK : SQLITE_DENY
        case .ownerDelete:
            return action == SQLITE_DELETE
                && Self.isInvestigationTable(table)
                ? SQLITE_OK : SQLITE_DENY
        case .sourceStagingCreate:
            if table == "sqlite_temp_master" {
                return SQLITE_OK
            }
            return action == SQLITE_CREATE_TEMP_TABLE
                && table == "investigation_source_staging"
                ? SQLITE_OK : SQLITE_DENY
        }
    }

    private func beginOperation(
        durationNanoseconds: UInt64,
        isCancelled: (@Sendable () -> Bool)? = nil
    ) throws {
        guard operationControl == nil else {
            throw EvidenceStoreError.authorizationViolation
        }
        let control = try SQLiteOperationControl(
            startedAtNanoseconds: testHooks.monotonicNanoseconds(),
            durationNanoseconds: durationNanoseconds,
            monotonicNanoseconds: testHooks.monotonicNanoseconds,
            isCancelled: isCancelled ?? testHooks.isCancelled
        )
        operationControl = control
        progressPhase = nil
        progressRows = 0
        progressBytes = 0
        lastReportedProgressRows = 0
        lastReportedProgressBytes = 0
        sqlite3_progress_handler(
            database,
            1_000,
            sqliteOperationProgressCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
        try checkOperationControl()
    }

    private func endOperation() {
        sqlite3_progress_handler(database, 0, nil, nil)
        operationControl = nil
        progressPhase = nil
        progressRows = 0
        progressBytes = 0
        lastReportedProgressRows = 0
        lastReportedProgressBytes = 0
    }

    fileprivate func checkOperationControl() throws {
        guard let control = operationControl,
              control.shouldInterrupt()
        else {
            return
        }
        sqlite3_interrupt(database)
        switch control.interruption {
        case .cancelled:
            throw EvidenceStoreError.operationCancelled
        case .deadlineExceeded:
            throw EvidenceStoreError.operationDeadlineExceeded
        case nil:
            throw EvidenceStoreError.operationCancelled
        }
    }

    fileprivate func recordInvestigationProgress(
        rowBytes: UInt64
    ) throws {
        let nextRows = progressRows.addingReportingOverflow(1)
        let nextBytes = progressBytes.addingReportingOverflow(rowBytes)
        guard !nextRows.overflow, !nextBytes.overflow else {
            throw InvestigationPersistenceError.quotaExceeded
        }
        progressRows = nextRows.partialValue
        progressBytes = nextBytes.partialValue
        let rowsSinceReport = progressRows - lastReportedProgressRows
        let bytesSinceReport = progressBytes - lastReportedProgressBytes
        if rowsSinceReport >= 1_024 || bytesSinceReport >= 16 * 1_048_576 {
            reportInvestigationProgress(
                phase: progressPhase ?? .sourceProjection,
                force: true
            )
        }
    }

    private func reportInvestigationProgress(
        phase: InvestigationStoreProgressPhase,
        force: Bool
    ) {
        guard operationControl != nil else {
            return
        }
        if let currentPhase = progressPhase,
           let currentIndex =
               InvestigationStoreProgressPhase.allCases.firstIndex(
                   of: currentPhase
               ),
           let requestedIndex =
               InvestigationStoreProgressPhase.allCases.firstIndex(of: phase),
           requestedIndex < currentIndex,
           phase != .rollback
        {
            return
        }
        progressPhase = phase
        guard force else {
            return
        }
        lastReportedProgressRows = progressRows
        lastReportedProgressBytes = progressBytes
        testHooks.investigationProgress(
            InvestigationStoreProgress(
                phase: phase,
                checkedRows: progressRows,
                checkedBytes: progressBytes
            )
        )
    }

    private static func isBoundedInvestigationOperation(
        _ operation: String
    ) -> Bool {
        switch operation {
        case "investigation.create",
             "investigation.rejoin",
             "investigation.terminal",
             "investigation.continuation",
             "investigation.recoveryPromotion":
            true
        default:
            false
        }
    }

    private static func involvesInvestigationData(
        action: Int32,
        first: String?
    ) -> Bool {
        guard let first else {
            return false
        }
        switch action {
        case SQLITE_INSERT, SQLITE_UPDATE, SQLITE_DELETE:
            return isInvestigationTable(first)
                || first == "investigation_source_staging"
        case SQLITE_CREATE_TABLE, SQLITE_CREATE_INDEX,
             SQLITE_CREATE_TRIGGER, SQLITE_CREATE_TEMP_TABLE,
             SQLITE_DROP_TABLE, SQLITE_DROP_INDEX, SQLITE_DROP_TRIGGER,
             SQLITE_DROP_TEMP_TABLE:
            return first.hasPrefix("investigation_")
        default:
            return false
        }
    }

    private static func isInvestigationTable(_ table: String) -> Bool {
        investigationTables.contains(table)
    }

    private static func isInvestigationMigrationIndex(
        _ name: String
    ) -> Bool {
        name.hasPrefix("idx_investigation_")
    }

    private static func isInvestigationMigrationIndexTable(
        _ table: String?
    ) -> Bool {
        guard let table else {
            return false
        }
        return isInvestigationTable(table)
            || table == "path_snapshots"
            || table == "classifications"
            || table == "evidence"
    }

    private static func authorizationMode(
        for operation: String
    ) -> SQLiteInvestigationAuthorizationMode {
        if operation.hasPrefix("schema.investigation") {
            return .migration
        }
        switch operation {
        case "investigation.sourceStaging.create":
            return .sourceStagingCreate
        case "investigation.sourceStaging.clear":
            return .delete(table: "investigation_source_staging")
        case "investigation.sourceStaging.prepare":
            return .insert(table: "investigation_source_staging")
        case "investigation.sourceManifest.persist":
            return .insert(table: "investigation_source_rows")
        case "investigation.create.session":
            return .insert(table: "investigation_sessions")
        case "investigation.create.relevanceToken":
            return .insert(table: "investigation_relevance_tokens")
        case "investigation.create.target":
            return .insert(table: "investigation_targets")
        case "investigation.create.run",
             "investigation.continuation.run":
            return .insert(table: "investigation_runs")
        case "investigation.create.runTarget",
             "investigation.continuation.target":
            return .insert(table: "investigation_run_targets")
        case "investigation.terminal.budget":
            return .insert(table: "investigation_budget_events")
        case "investigation.terminal.report":
            return .insert(table: "investigation_reports")
        case "investigation.terminal.evidence":
            return .insert(table: "investigation_evidence")
        case "investigation.terminal.degradation":
            return .insert(table: "investigation_report_degradations")
        case "investigation.transition.run":
            return .update(
                table: "investigation_runs",
                columns: ["state", "stage", "terminal_cause", "updated_at_ms"]
            )
        case "investigation.transition.session":
            return .update(
                table: "investigation_sessions",
                columns: ["state", "stage", "updated_at_ms"]
            )
        case "investigation.terminal.run":
            return .update(
                table: "investigation_runs",
                columns: [
                    "state", "stage", "terminal_report_id",
                    "budget_event_count", "budget_payload_byte_count",
                    "updated_at_ms", "terminal_at_ms",
                ]
            )
        case "investigation.terminal.session":
            return .update(
                table: "investigation_sessions",
                columns: [
                    "state", "stage", "report_count",
                    "evidence_row_count", "evidence_payload_byte_count",
                    "degradation_row_count",
                    "degradation_payload_byte_count",
                    "budget_event_count", "budget_payload_byte_count",
                    "updated_at_ms",
                ]
            )
        case "investigation.continuation.session":
            return .update(
                table: "investigation_sessions",
                columns: ["state", "stage", "run_count", "updated_at_ms"]
            )
        case "investigation.delete.session",
             "retention.investigations":
            return .ownerDelete
        default:
            return .deny
        }
    }

#if DEBUG
    private func prepareAuthorizationProbe(
        _ sql: String,
        mode: SQLiteInvestigationAuthorizationMode
    ) throws {
        guard case .deny = authorizationMode else {
            throw EvidenceStoreError.authorizationViolation
        }
        authorizationMode = mode
        defer { authorizationMode = .deny }
        var statement: OpaquePointer?
        let code = sqlite3_prepare_v3(
            database,
            sql,
            -1,
            UInt32(SQLITE_PREPARE_PERSISTENT),
            &statement,
            nil
        )
        if let statement {
            sqlite3_finalize(statement)
        }
        guard code == SQLITE_OK else {
            throw error(operation: "test.authorizationProbe", code: code)
        }
    }
#endif
}

private let investigationTables: Set<String> = [
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
]

func columnText(_ statement: OpaquePointer, _ index: Int32) -> String {
    guard let text = sqlite3_column_text(statement, index) else {
        return ""
    }
    return String(cString: text)
}

func columnBlob(_ statement: OpaquePointer, _ index: Int32) -> Data {
    let count = Int(sqlite3_column_bytes(statement, index))
    guard count > 0,
          let bytes = sqlite3_column_blob(statement, index)
    else {
        return Data()
    }
    return Data(bytes: bytes, count: count)
}

func columnData(_ statement: OpaquePointer, _ index: Int32) -> Data {
    let count = Int(sqlite3_column_bytes(statement, index))
    guard count > 0,
          let bytes = sqlite3_column_text(statement, index)
    else {
        return Data()
    }
    return Data(bytes: bytes, count: count)
}

private struct SQLiteInvestigationSourceFactory:
    InvestigationSourceCursorFactory
{
    let connection: SQLiteConnection
    let scanSessionID: ScanSessionID
    let primaryScopeID: ScanScopeID
    let relevanceTokens: [DomainToken]
    private(set) var cursorCount = 0

    init(
        connection: SQLiteConnection,
        scanSessionID: ScanSessionID,
        scanScopeID: ScanScopeID,
        relevanceTokens: [DomainToken]
    ) {
        self.connection = connection
        self.scanSessionID = scanSessionID
        primaryScopeID = scanScopeID
        self.relevanceTokens = relevanceTokens
    }

    var generation: InvestigationSourceGeneration {
        InvestigationSourceGeneration(
            token: DomainToken(rawValue: "evidence-store-source-v4")!
        )
    }

    mutating func makeCursor() throws -> any InvestigationSourceCursor {
        guard cursorCount < 2 else {
            throw InvestigationSourceProjectionError.cursorCountExceeded
        }
        cursorCount += 1
        return try SQLiteInvestigationSourceCursor(
            connection: connection,
            scanSessionID: scanSessionID,
            scanScopeID: primaryScopeID
        )
    }
}

private final class SQLiteInvestigationSourceCursor:
    InvestigationSourceCursor,
    @unchecked Sendable
{
    private let connection: SQLiteConnection
    private let scanSessionID: ScanSessionID
    private let scanScopeID: ScanScopeID
    private var familyIndex = 0
    private var statement: OpaquePointer?
    private var isFinished = false

    init(
        connection: SQLiteConnection,
        scanSessionID: ScanSessionID,
        scanScopeID: ScanScopeID
    ) throws {
        self.connection = connection
        self.scanSessionID = scanSessionID
        self.scanScopeID = scanScopeID
    }

    deinit {
        if let statement {
            sqlite3_finalize(statement)
        }
    }

    func next() throws -> InvestigationStoredSourceRow? {
        guard !isFinished else {
            return nil
        }
        while familyIndex < SQLiteInvestigationSourceFamily.allCases.count {
            let family =
                SQLiteInvestigationSourceFamily.allCases[familyIndex]
            let statement = try preparedStatement(for: family)
            try connection.checkOperationControl()
            let code = sqlite3_step(statement)
            if code == SQLITE_DONE {
                sqlite3_finalize(statement)
                self.statement = nil
                familyIndex += 1
                continue
            }
            guard code == SQLITE_ROW else {
                throw connection.error(
                    operation: "investigation.sourceCursor.step",
                    code: code
                )
            }
            return try decodeRow(
                statement,
                expectedRowKind: family.rowKind
            )
        }
        isFinished = true
        return nil
    }

    private func preparedStatement(
        for family: SQLiteInvestigationSourceFamily
    ) throws -> OpaquePointer {
        if let statement {
            return statement
        }
        let statement = try connection.prepare(
            family.query,
            operation: "investigation.sourceCursor.prepare"
        )
        do {
            try connection.bind(
                family.bindings(
                    scanSessionID: scanSessionID,
                    scanScopeID: scanScopeID
                ),
                to: statement,
                operation: "investigation.sourceCursor.bind"
            )
        } catch {
            sqlite3_finalize(statement)
            throw error
        }
        self.statement = statement
        return statement
    }

    private func decodeRow(
        _ statement: OpaquePointer,
        expectedRowKind: InvestigationSourceRowKind
    ) throws -> InvestigationStoredSourceRow {
        guard let rowKind = InvestigationSourceRowKind(
            rawValue: columnText(statement, 0)
        ), rowKind == expectedRowKind else {
            throw InvestigationSourceProjectionError.storageMismatch
        }
        let primaryID = columnText(statement, 1)
        let payload = columnData(statement, 12)
        try connection.recordInvestigationProgress(
            rowBytes: UInt64(payload.count)
        )
        let columns: [InvestigationStorageColumn]
        switch rowKind {
        case .scanSession:
            columns = [
                .init(name: "id", value: .text(primaryID)),
                .init(
                    name: "expires_at_ms",
                    value: .int64(sqlite3_column_int64(statement, 9))
                ),
                .init(
                    name: "started_at_ms",
                    value: .int64(sqlite3_column_int64(statement, 7))
                ),
                .init(
                    name: "finished_at_ms",
                    value: .int64(sqlite3_column_int64(statement, 8))
                ),
            ]
        case .pathSnapshot:
            columns = [
                .init(name: "id", value: .text(primaryID)),
                .init(
                    name: "session_id",
                    value: .text(columnText(statement, 3))
                ),
                .init(
                    name: "relative_path",
                    value: .text(columnText(statement, 4))
                ),
                .init(
                    name: "observed_at_ms",
                    value: .int64(sqlite3_column_int64(statement, 10))
                ),
            ]
        case .classification:
            columns = [
                .init(name: "id", value: .text(primaryID)),
                .init(
                    name: "disposition",
                    value: .text(columnText(statement, 6))
                ),
                .init(
                    name: "snapshot_id",
                    value: .text(columnText(statement, 5))
                ),
                .init(
                    name: "classified_at_ms",
                    value: .int64(sqlite3_column_int64(statement, 11))
                ),
            ]
        case .evidence:
            columns = [
                .init(name: "id", value: .text(primaryID)),
                .init(
                    name: "snapshot_id",
                    value: .text(columnText(statement, 5))
                ),
                .init(
                    name: "observed_at_ms",
                    value: .int64(sqlite3_column_int64(statement, 10))
                ),
            ]
        case .spaceLedger:
            columns = [
                .init(name: "id", value: .text(primaryID)),
                .init(
                    name: "session_id",
                    value: .text(columnText(statement, 3))
                ),
            ]
        }
        return try InvestigationStoredSourceRow(
            rowKind: rowKind,
            storageColumns: columns,
            exactPayload: payload
        )
    }
}

private struct SQLiteInvestigationManifestStagingSink:
    InvestigationManifestSink
{
    let connection: SQLiteConnection
    let statement: OpaquePointer
    private var ordinal: Int64 = 0

    init(
        connection: SQLiteConnection,
        statement: OpaquePointer
    ) {
        self.connection = connection
        self.statement = statement
    }

    mutating func record(
        _ row: InvestigationSourceManifestRow
    ) throws {
        guard sqlite3_reset(statement) == SQLITE_OK,
              sqlite3_clear_bindings(statement) == SQLITE_OK
        else {
            throw connection.error(
                operation: "investigation.sourceStaging.reset",
                code: SQLITE_MISUSE
            )
        }
        try connection.bind(
            [
                .integer(ordinal),
                .text(row.rowKind.rawValue),
                .text(row.primaryID),
                .integer(Int64(row.payloadByteCount)),
                .blob(row.payloadSHA256.bytes),
            ],
            to: statement,
            operation: "investigation.sourceStaging.bind"
        )
        let code = sqlite3_step(statement)
        guard code == SQLITE_DONE else {
            throw connection.error(
                operation: "investigation.sourceStaging.step",
                code: code
            )
        }
        try connection.recordInvestigationProgress(
            rowBytes: row.payloadByteCount
        )
        ordinal += 1
    }

    func finish(expectedRowCount: UInt64) throws {
        guard UInt64(ordinal) == expectedRowCount else {
            throw InvestigationSourceProjectionError.membershipMismatch
        }
    }
}

private struct SQLiteInvestigationManifestCompareSink:
    InvestigationManifestSink
{
    let connection: SQLiteConnection
    let statement: OpaquePointer
    private var ordinal: Int64 = 0

    init(
        connection: SQLiteConnection,
        statement: OpaquePointer
    ) {
        self.connection = connection
        self.statement = statement
    }

    mutating func record(
        _ row: InvestigationSourceManifestRow
    ) throws {
        try connection.checkOperationControl()
        guard sqlite3_step(statement) == SQLITE_ROW,
              sqlite3_column_int64(statement, 0) == ordinal
        else {
            throw InvestigationSourceProjectionError.secondPassDrift
        }
        let values = Dictionary(
            uniqueKeysWithValues: row.storageColumns.map {
                ($0.name, $0.value)
            }
        )
        guard columnText(statement, 1) == row.rowKind.rawValue,
              columnText(statement, 2) == row.primaryID,
              columnText(statement, 3) == row.primaryID,
              columnMatches(values["session_id"], statement: statement, at: 4),
              columnMatches(
                  values["relative_path"],
                  statement: statement,
                  at: 5
              ),
              columnMatches(
                  values["snapshot_id"],
                  statement: statement,
                  at: 6
              ),
              columnMatches(
                  values["disposition"],
                  statement: statement,
                  at: 7
              ),
              columnMatches(
                  values["started_at_ms"],
                  statement: statement,
                  at: 8
              ),
              columnMatches(
                  values["finished_at_ms"],
                  statement: statement,
                  at: 9
              ),
              columnMatches(
                  values["expires_at_ms"],
                  statement: statement,
                  at: 10
              ),
              columnMatches(
                  values["observed_at_ms"],
                  statement: statement,
                  at: 11
              ),
              columnMatches(
                  values["classified_at_ms"],
                  statement: statement,
                  at: 12
              ),
              sqlite3_column_int64(statement, 13)
                == Int64(row.payloadByteCount),
              columnBlob(statement, 14) == row.payloadSHA256.bytes
        else {
            throw InvestigationSourceProjectionError.secondPassDrift
        }
        try connection.recordInvestigationProgress(
            rowBytes: row.payloadByteCount
        )
        ordinal += 1
    }

    mutating func finish(expectedRowCount: UInt64) throws {
        guard UInt64(ordinal) == expectedRowCount else {
            throw InvestigationSourceProjectionError.secondPassDrift
        }
        try connection.checkOperationControl()
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw InvestigationSourceProjectionError.secondPassDrift
        }
    }

    private func columnMatches(
        _ expected: InvestigationStorageValue?,
        statement: OpaquePointer,
        at index: Int32
    ) -> Bool {
        switch expected {
        case let .text(value):
            return sqlite3_column_type(statement, index) == SQLITE_TEXT
                && columnText(statement, index) == value
        case let .int64(value):
            return sqlite3_column_type(statement, index) == SQLITE_INTEGER
                && sqlite3_column_int64(statement, index) == value
        case nil:
            return sqlite3_column_type(statement, index) == SQLITE_NULL
        }
    }
}

private let investigationSourceStagingSchema = """
CREATE TEMP TABLE IF NOT EXISTS investigation_source_staging (
    ordinal INTEGER PRIMARY KEY NOT NULL,
    row_kind TEXT NOT NULL,
    primary_id TEXT NOT NULL,
    source_payload_byte_count INTEGER NOT NULL,
    source_payload_sha256 BLOB NOT NULL
) STRICT
"""

private let investigationSourceStagingInsert = """
INSERT INTO investigation_source_staging (
    ordinal, row_kind, primary_id,
    source_payload_byte_count, source_payload_sha256
) VALUES (?, ?, ?, ?, ?)
"""

private let investigationSourceManifestSelect = """
SELECT ordinal, row_kind, primary_id, source_id, source_session_id,
       source_relative_path, source_snapshot_id, source_disposition,
       source_started_at_ms, source_finished_at_ms, source_expires_at_ms,
       source_observed_at_ms, source_classified_at_ms,
       source_payload_byte_count, source_payload_sha256
FROM investigation_source_rows
WHERE investigation_id = ?
ORDER BY ordinal
"""

private enum SQLiteInvestigationSourceFamily:
    Int,
    CaseIterable
{
    case evidence
    case scanSession
    case spaceLedger
    case pathSnapshot
    case classification

    static let manifestPersistenceOrder: [Self] = [
        .scanSession,
        .spaceLedger,
        .pathSnapshot,
        .classification,
        .evidence,
    ]

    var rowKind: InvestigationSourceRowKind {
        switch self {
        case .evidence:
            .evidence
        case .scanSession:
            .scanSession
        case .spaceLedger:
            .spaceLedger
        case .pathSnapshot:
            .pathSnapshot
        case .classification:
            .classification
        }
    }

    var query: String {
        switch self {
        case .evidence:
            investigationEvidenceSourceQuery
        case .scanSession:
            investigationScanSessionSourceQuery
        case .spaceLedger:
            investigationSpaceLedgerSourceQuery
        case .pathSnapshot:
            investigationPathSnapshotSourceQuery
        case .classification:
            investigationClassificationSourceQuery
        }
    }

    var manifestInsertQuery: String {
        switch self {
        case .evidence:
            investigationEvidenceManifestInsert
        case .scanSession:
            investigationScanSessionManifestInsert
        case .spaceLedger:
            investigationSpaceLedgerManifestInsert
        case .pathSnapshot:
            investigationPathSnapshotManifestInsert
        case .classification:
            investigationClassificationManifestInsert
        }
    }

    func bindings(
        scanSessionID: ScanSessionID,
        scanScopeID: ScanScopeID
    ) -> [SQLiteValue] {
        switch self {
        case .scanSession:
            [.text(scanSessionID.rawValue)]
        case .spaceLedger:
            [
                .text(scanSessionID.rawValue),
                .text(scanSessionID.rawValue),
            ]
        case .evidence, .pathSnapshot, .classification:
            [
                .text(scanSessionID.rawValue),
                .text(scanScopeID.rawValue),
            ]
        }
    }
}

private let investigationEvidenceManifestInsert = """
INSERT INTO investigation_source_rows (
    investigation_id, ordinal, row_kind, primary_id, source_id,
    source_session_id, source_relative_path, source_snapshot_id,
    source_disposition, source_started_at_ms, source_finished_at_ms,
    source_expires_at_ms, source_observed_at_ms, source_classified_at_ms,
    source_payload_byte_count, source_payload_sha256
)
SELECT ?, staged.ordinal, staged.row_kind, evidence.id, evidence.id,
       NULL, NULL, evidence.snapshot_id, NULL, NULL, NULL, NULL,
       evidence.observed_at_ms, NULL, staged.source_payload_byte_count,
       staged.source_payload_sha256
FROM investigation_source_staging AS staged
JOIN evidence AS evidence ON evidence.id = staged.primary_id
WHERE staged.row_kind = 'evidence-v1'
ORDER BY staged.ordinal
"""

private let investigationScanSessionManifestInsert = """
INSERT INTO investigation_source_rows (
    investigation_id, ordinal, row_kind, primary_id, source_id,
    source_session_id, source_relative_path, source_snapshot_id,
    source_disposition, source_started_at_ms, source_finished_at_ms,
    source_expires_at_ms, source_observed_at_ms, source_classified_at_ms,
    source_payload_byte_count, source_payload_sha256
)
SELECT ?, staged.ordinal, staged.row_kind, session.id, session.id,
       NULL, NULL, NULL, NULL, session.started_at_ms,
       session.finished_at_ms, session.expires_at_ms, NULL, NULL,
       staged.source_payload_byte_count, staged.source_payload_sha256
FROM investigation_source_staging AS staged
JOIN scan_sessions AS session ON session.id = staged.primary_id
WHERE staged.row_kind = 'scan-session-v1'
ORDER BY staged.ordinal
"""

private let investigationSpaceLedgerManifestInsert = """
INSERT INTO investigation_source_rows (
    investigation_id, ordinal, row_kind, primary_id, source_id,
    source_session_id, source_relative_path, source_snapshot_id,
    source_disposition, source_started_at_ms, source_finished_at_ms,
    source_expires_at_ms, source_observed_at_ms, source_classified_at_ms,
    source_payload_byte_count, source_payload_sha256
)
SELECT ?, staged.ordinal, staged.row_kind, accounting.id, accounting.id,
       accounting.session_id, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
       NULL, staged.source_payload_byte_count, staged.source_payload_sha256
FROM investigation_source_staging AS staged
JOIN space_accounting AS accounting ON accounting.id = staged.primary_id
WHERE staged.row_kind = 'space-ledger-v1'
ORDER BY staged.ordinal
"""

private let investigationPathSnapshotManifestInsert = """
INSERT INTO investigation_source_rows (
    investigation_id, ordinal, row_kind, primary_id, source_id,
    source_session_id, source_relative_path, source_snapshot_id,
    source_disposition, source_started_at_ms, source_finished_at_ms,
    source_expires_at_ms, source_observed_at_ms, source_classified_at_ms,
    source_payload_byte_count, source_payload_sha256
)
SELECT ?, staged.ordinal, staged.row_kind, snapshot.id, snapshot.id,
       snapshot.session_id, snapshot.relative_path, NULL, NULL, NULL, NULL,
       NULL, snapshot.observed_at_ms, NULL,
       staged.source_payload_byte_count, staged.source_payload_sha256
FROM investigation_source_staging AS staged
JOIN path_snapshots AS snapshot ON snapshot.id = staged.primary_id
WHERE staged.row_kind = 'path-snapshot-v1'
ORDER BY staged.ordinal
"""

private let investigationClassificationManifestInsert = """
INSERT INTO investigation_source_rows (
    investigation_id, ordinal, row_kind, primary_id, source_id,
    source_session_id, source_relative_path, source_snapshot_id,
    source_disposition, source_started_at_ms, source_finished_at_ms,
    source_expires_at_ms, source_observed_at_ms, source_classified_at_ms,
    source_payload_byte_count, source_payload_sha256
)
SELECT ?, staged.ordinal, staged.row_kind, classification.id,
       classification.id, NULL, NULL, classification.snapshot_id,
       classification.disposition, NULL, NULL, NULL, NULL,
       classification.classified_at_ms, staged.source_payload_byte_count,
       staged.source_payload_sha256
FROM investigation_source_staging AS staged
JOIN classifications AS classification
  ON classification.id = staged.primary_id
WHERE staged.row_kind = 'classification-v1'
ORDER BY staged.ordinal
"""

private let investigationEvidenceSourceQuery = """
SELECT 'evidence-v1' AS row_kind, evidence.id AS primary_id,
       evidence.id AS source_id, NULL AS source_session_id,
       NULL AS source_relative_path, evidence.snapshot_id,
       NULL AS source_disposition, NULL AS source_started_at_ms,
       NULL AS source_finished_at_ms, NULL AS source_expires_at_ms,
       evidence.observed_at_ms AS source_observed_at_ms,
       NULL AS source_classified_at_ms, evidence.payload
FROM evidence AS evidence
INDEXED BY idx_investigation_source_evidence_canonical
JOIN path_snapshots AS snapshot
INDEXED BY idx_investigation_source_snapshot_membership
  ON snapshot.id = evidence.snapshot_id
WHERE snapshot.session_id = ?
  AND json_extract(snapshot.payload, '$.scopeID') = ?
ORDER BY length(CAST(evidence.id AS BLOB)), CAST(evidence.id AS BLOB)
"""

private let investigationScanSessionSourceQuery = """
SELECT 'scan-session-v1' AS row_kind, session.id AS primary_id,
       session.id AS source_id, NULL AS source_session_id,
       NULL AS source_relative_path, NULL AS source_snapshot_id,
       NULL AS source_disposition,
       session.started_at_ms AS source_started_at_ms,
       session.finished_at_ms AS source_finished_at_ms,
       session.expires_at_ms AS source_expires_at_ms,
       NULL AS source_observed_at_ms,
       NULL AS source_classified_at_ms, session.payload
FROM scan_sessions AS session
WHERE session.id = ?
ORDER BY length(CAST(session.id AS BLOB)), CAST(session.id AS BLOB)
"""

private let investigationSpaceLedgerSourceQuery = """
SELECT 'space-ledger-v1' AS row_kind, accounting.id AS primary_id,
       accounting.id AS source_id,
       accounting.session_id AS source_session_id,
       NULL AS source_relative_path, NULL AS source_snapshot_id,
       NULL AS source_disposition, NULL AS source_started_at_ms,
       NULL AS source_finished_at_ms, NULL AS source_expires_at_ms,
       NULL AS source_observed_at_ms,
       NULL AS source_classified_at_ms, accounting.payload
FROM space_accounting AS accounting
WHERE accounting.id = ? AND accounting.session_id = ?
ORDER BY length(CAST(accounting.id AS BLOB)),
         CAST(accounting.id AS BLOB)
"""

private let investigationPathSnapshotSourceQuery = """
SELECT 'path-snapshot-v1' AS row_kind, snapshot.id AS primary_id,
       snapshot.id AS source_id,
       snapshot.session_id AS source_session_id,
       snapshot.relative_path AS source_relative_path,
       NULL AS source_snapshot_id, NULL AS source_disposition,
       NULL AS source_started_at_ms, NULL AS source_finished_at_ms,
       NULL AS source_expires_at_ms,
       snapshot.observed_at_ms AS source_observed_at_ms,
       NULL AS source_classified_at_ms, snapshot.payload
FROM path_snapshots AS snapshot
INDEXED BY idx_investigation_source_path_snapshots_canonical
WHERE snapshot.session_id = ?
  AND json_extract(snapshot.payload, '$.scopeID') = ?
ORDER BY length(CAST(snapshot.id AS BLOB)), CAST(snapshot.id AS BLOB)
"""

private let investigationClassificationSourceQuery = """
SELECT 'classification-v1' AS row_kind,
       classification.id AS primary_id,
       classification.id AS source_id, NULL AS source_session_id,
       NULL AS source_relative_path,
       classification.snapshot_id AS source_snapshot_id,
       classification.disposition AS source_disposition,
       NULL AS source_started_at_ms, NULL AS source_finished_at_ms,
       NULL AS source_expires_at_ms, NULL AS source_observed_at_ms,
       classification.classified_at_ms AS source_classified_at_ms,
       classification.payload
FROM classifications AS classification
INDEXED BY idx_investigation_source_classifications_canonical
JOIN path_snapshots AS snapshot
INDEXED BY idx_investigation_source_snapshot_membership
  ON snapshot.id = classification.snapshot_id
WHERE snapshot.session_id = ?
  AND json_extract(snapshot.payload, '$.scopeID') = ?
ORDER BY length(CAST(classification.id AS BLOB)),
         CAST(classification.id AS BLOB)
"""

let maximumStorePayloadBytes = 1_048_576
let maximumSpaceLedgerPayloadBytes = 16 * 1_048_576
let maximumStorePageSize = 100

func encodeStorePayload<T: Encodable>(_ value: T) throws -> String {
    let data = try DomainJSON.encode(value)
    guard data.count <= maximumStorePayloadBytes else {
        throw EvidenceStoreError.payloadTooLarge(
            limit: maximumStorePayloadBytes
        )
    }
    return String(decoding: data, as: UTF8.self)
}

func boundedStorePayloadString(
    _ data: Data,
    limit: Int = maximumStorePayloadBytes
) throws -> String {
    guard data.count <= limit else {
        throw EvidenceStoreError.payloadTooLarge(limit: limit)
    }
    return String(decoding: data, as: UTF8.self)
}

func verifySQLiteHeaderIfPresent(
    _ url: URL,
    isMemory: Bool
) throws {
    guard !isMemory,
          FileManager.default.fileExists(atPath: url.path)
    else {
        return
    }
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    let header = try handle.read(upToCount: 16) ?? Data()
    guard header.isEmpty
            || header == Data("SQLite format 3\u{0}".utf8)
    else {
        throw EvidenceStoreError.integrityCheckFailed
    }
}
