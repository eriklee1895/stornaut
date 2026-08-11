import Foundation
import SQLite3

public enum EvidenceStoreError: Error, Sendable, Equatable {
    case unsafeStoragePath
    case openFailed(code: Int32)
    case sqlite(operation: String, code: Int32, extendedCode: Int32)
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
}

enum SQLiteValue: Sendable {
    case integer(Int64)
    case text(String)
    case null
}

final class SQLiteConnection: @unchecked Sendable {
    let database: OpaquePointer

    init(path: String) throws {
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
        sqlite3_extended_result_codes(database, 1)
        sqlite3_busy_timeout(database, 2_000)
    }

    deinit {
        sqlite3_close_v2(database)
    }

    func execute(
        _ sql: String,
        bindings: [SQLiteValue] = [],
        operation: String
    ) throws {
        let statement = try prepare(sql, operation: operation)
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement, operation: operation)
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
            try Task.checkCancellation()
            guard sqlite3_reset(statement) == SQLITE_OK,
                  sqlite3_clear_bindings(statement) == SQLITE_OK
            else {
                throw error(operation: operation, code: SQLITE_MISUSE)
            }
            try bind(bindings, to: statement, operation: operation)
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
        let statement = try prepare(sql, operation: operation)
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement, operation: operation)
        var records: [T] = []
        while true {
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
        try execute("BEGIN IMMEDIATE", operation: "\(operation).begin")
        do {
            let value = try body()
            try execute("COMMIT", operation: "\(operation).commit")
            return value
        } catch {
            try? execute("ROLLBACK", operation: "\(operation).rollback")
            throw error
        }
    }

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

    private func prepare(
        _ sql: String,
        operation: String
    ) throws -> OpaquePointer {
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

    private func bind(
        _ bindings: [SQLiteValue],
        to statement: OpaquePointer,
        operation: String
    ) throws {
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
            case .null:
                code = sqlite3_bind_null(statement, index)
            }
            guard code == SQLITE_OK else {
                throw error(operation: operation, code: code)
            }
        }
    }

    private func error(
        operation: String,
        code: Int32
    ) -> EvidenceStoreError {
        .sqlite(
            operation: operation,
            code: code & 0xFF,
            extendedCode: sqlite3_extended_errcode(database)
        )
    }
}

func columnText(_ statement: OpaquePointer, _ index: Int32) -> String {
    guard let text = sqlite3_column_text(statement, index) else {
        return ""
    }
    return String(cString: text)
}

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
