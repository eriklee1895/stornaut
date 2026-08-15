import CryptoKit
import Darwin
import Foundation
import SQLite3
import Testing

@Test(
    .enabled(
        if: ProcessInfo.processInfo.environment[
            "STORNAUT_RUN_TASK37_CAPACITY_PREFLIGHT"
        ] == "1",
        "Task 37 pre-implementation Release capacity preflight"
    )
)
func investigationStoreCapacityPreflightBenchmark() throws {
    let fixture = try InvestigationStoreCapacityPreflightFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }

    var samples: [InvestigationStoreCapacityPreflightSample] = []
    for sampleIndex in 0..<3 {
        let insertionDatabase = fixture.databaseURL(
            operation: "insertion",
            sampleIndex: sampleIndex
        )
        samples.append(
            try fixture.measure(
                operation: "insertion",
                sampleIndex: sampleIndex,
                databaseURL: insertionDatabase
            ) {
                try fixture.createMaximumSourceDatabase(at: insertionDatabase)
            }
        )

        let rejoinDatabase = fixture.databaseURL(
            operation: "rejoin",
            sampleIndex: sampleIndex
        )
        try fixture.copyDatabase(
            from: insertionDatabase,
            to: rejoinDatabase
        )
        samples.append(
            try fixture.measure(
                operation: "rejoin",
                sampleIndex: sampleIndex,
                databaseURL: rejoinDatabase
            ) {
                try fixture.verifyMaximumSourceDatabase(at: rejoinDatabase)
            }
        )

        for operation in ["terminal", "recovery", "continuation"] {
            let operationDatabase = fixture.databaseURL(
                operation: operation,
                sampleIndex: sampleIndex
            )
            try fixture.copyDatabase(
                from: insertionDatabase,
                to: operationDatabase
            )
            samples.append(
                try fixture.measure(
                    operation: operation,
                    sampleIndex: sampleIndex,
                    databaseURL: operationDatabase
                ) {
                    switch operation {
                    case "terminal":
                        try fixture.commitMaximumTerminal(
                            at: operationDatabase,
                            reportSuffix: "terminal"
                        )
                    case "recovery":
                        try fixture.commitMaximumTerminal(
                            at: operationDatabase,
                            reportSuffix: "recovery"
                        )
                    default:
                        try fixture.createMaximumContinuation(
                            at: operationDatabase
                        )
                    }
                }
            )
        }
    }

    #expect(samples.count == 15)
    #expect(samples.allSatisfy { $0.duration < .seconds(75) })
    for sample in samples {
        print(
            "Investigation Store capacity preflight:",
            "operation=\(sample.operation)",
            "sample=\(sample.sampleIndex + 1)",
            "duration=\(sample.duration)",
            "peakIncrement=\(sample.peakIncrement)",
            "databaseBytes=\(sample.databaseBytes)"
        )
    }
}

private struct InvestigationStoreCapacityPreflightSample {
    let operation: String
    let sampleIndex: Int
    let duration: Duration
    let peakIncrement: UInt64
    let databaseBytes: UInt64
}

private struct InvestigationStoreCapacityPreflightFixture {
    let root: URL
    private let clock = ContinuousClock()
    private let footprint = InvestigationStoreCapacityPreflightFootprint()

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-task37-capacity-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
    }

    func databaseURL(operation: String, sampleIndex: Int) -> URL {
        root.appending(
            path: "\(operation)-\(sampleIndex + 1).sqlite"
        )
    }

    func copyDatabase(from source: URL, to destination: URL) throws {
        try FileManager.default.copyItem(at: source, to: destination)
    }

    func measure(
        operation: String,
        sampleIndex: Int,
        databaseURL: URL,
        body: () throws -> Void
    ) throws -> InvestigationStoreCapacityPreflightSample {
        let baseline = try footprint.sample()
        let duration = try clock.measure(body)
        let final = try footprint.sample()
        let peak = try footprint.peak()
        let databaseBytes = try databaseURL.resourceValues(
            forKeys: [.fileSizeKey]
        ).fileSize ?? 0
        return InvestigationStoreCapacityPreflightSample(
            operation: operation,
            sampleIndex: sampleIndex,
            duration: duration,
            peakIncrement: max(peak, final) >= baseline
                ? max(peak, final) - baseline
                : 0,
            databaseBytes: UInt64(databaseBytes)
        )
    }

    func createMaximumSourceDatabase(at url: URL) throws {
        let database = try InvestigationStoreCapacityPreflightDatabase(url: url)
        try database.execute("PRAGMA foreign_keys=ON")
        try database.execute("PRAGMA synchronous=FULL")
        try database.execute("PRAGMA journal_mode=DELETE")
        try database.execute(investigationStoreCapacityPreflightSchema)
        try database.execute("BEGIN IMMEDIATE")
        do {
            try database.execute(
                """
                INSERT INTO investigation_sessions (
                    id, scan_session_id, scan_scope_id, source_fingerprint,
                    state, stage, source_row_count, relevance_token_count,
                    source_payload_byte_count, source_canonical_byte_count,
                    run_count, created_at_ms, updated_at_ms, expires_at_ms
                ) VALUES (
                    'investigation-capacity', 'scan-capacity',
                    'scope-capacity', zeroblob(32), 'planned', 'prioritize',
                    300002, 2, 268435456, 536870912, 1,
                    1800000000000, 1800000000000, 1800604800000
                )
                """
            )
            let sourceStatement = try database.statement(
                """
                INSERT INTO investigation_source_rows (
                    investigation_id, ordinal, row_kind, primary_id,
                    source_id, source_session_id, source_relative_path,
                    source_snapshot_id, source_disposition,
                    source_started_at_ms, source_finished_at_ms,
                    source_expires_at_ms, source_observed_at_ms,
                    source_classified_at_ms, source_payload_byte_count,
                    source_payload_sha256
                ) VALUES (
                    'investigation-capacity', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                    ?, ?, ?, ?, ?
                )
                """
            )
            defer { sqlite3_finalize(sourceStatement) }
            var canonicalHash = SHA256()
            var remainingCanonicalBytes = 536_870_912
            var remainingPayloadBytes = 268_435_456
            for ordinal in 0..<300_002 {
                let row = sourceRow(
                    ordinal: ordinal,
                    remainingPayloadBytes: remainingPayloadBytes
                )
                try database.reset(sourceStatement)
                try database.bind(row.bindings, to: sourceStatement)
                try database.stepDone(sourceStatement)
                remainingPayloadBytes -= row.payloadByteCount
                let canonicalChunkCount = min(
                    remainingCanonicalBytes,
                    row.canonicalByteCount
                )
                canonicalHash.update(
                    data: Data(
                        repeating: UInt8(truncatingIfNeeded: ordinal),
                        count: canonicalChunkCount
                    )
                )
                remainingCanonicalBytes -= canonicalChunkCount
            }
            while remainingCanonicalBytes > 0 {
                let count = min(remainingCanonicalBytes, 1_048_576)
                canonicalHash.update(
                    data: Data(repeating: 0xA5, count: count)
                )
                remainingCanonicalBytes -= count
            }
            _ = canonicalHash.finalize()
            let tokenStatement = try database.statement(
                """
                INSERT INTO investigation_relevance_tokens
                (investigation_id, ordinal, token)
                VALUES ('investigation-capacity', ?, ?)
                """
            )
            defer { sqlite3_finalize(tokenStatement) }
            for (ordinal, token) in ["capacity.large", "capacity.unknown"]
                .enumerated()
            {
                try database.reset(tokenStatement)
                try database.bind(
                    [.integer(Int64(ordinal)), .text(token)],
                    to: tokenStatement
                )
                try database.stepDone(tokenStatement)
            }
            let targetStatement = try database.statement(
                """
                INSERT INTO investigation_targets (
                    investigation_id, target_id, ordinal, target_kind, payload
                ) VALUES (
                    'investigation-capacity', ?, ?,
                    'unknown-large-consumer-v1', ?
                )
                """
            )
            defer { sqlite3_finalize(targetStatement) }
            let membershipStatement = try database.statement(
                """
                INSERT INTO investigation_run_targets (
                    investigation_id, run_id, ordinal, target_id
                ) VALUES (
                    'investigation-capacity',
                    'investigation-run-capacity', ?, ?
                )
                """
            )
            defer { sqlite3_finalize(membershipStatement) }
            try database.execute(
                """
                INSERT INTO investigation_runs (
                    investigation_id, run_id, run_ordinal,
                    target_set_fingerprint, plan_fingerprint, plan_json,
                    budget_preset, plan_created_at_ms, plan_expires_at_ms,
                    target_count, state, stage, created_at_ms, updated_at_ms,
                    payload
                ) VALUES (
                    'investigation-capacity', 'investigation-run-capacity', 0,
                    zeroblob(32), zeroblob(32), '{}', 'thorough',
                    1800000000000, 1800003600000, 512, 'planned',
                    'prioritize', 1800000000000, 1800000000000, '{}'
                )
                """
            )
            for ordinal in 0..<512 {
                let targetID = String(
                    format: "target-%064llx",
                    UInt64(ordinal + 1)
                )
                try database.reset(targetStatement)
                try database.bind(
                    [
                        .text(targetID),
                        .integer(Int64(ordinal)),
                        .text("{\"ordinal\":\(ordinal)}"),
                    ],
                    to: targetStatement
                )
                try database.stepDone(targetStatement)
                try database.reset(membershipStatement)
                try database.bind(
                    [.integer(Int64(ordinal)), .text(targetID)],
                    to: membershipStatement
                )
                try database.stepDone(membershipStatement)
            }
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
        try database.verify()
    }

    func verifyMaximumSourceDatabase(at url: URL) throws {
        let database = try InvestigationStoreCapacityPreflightDatabase(url: url)
        try database.execute("PRAGMA foreign_keys=ON")
        try database.execute("BEGIN IMMEDIATE")
        do {
            let statement = try database.statement(
                """
                SELECT ordinal, row_kind, primary_id,
                       source_payload_byte_count, source_payload_sha256
                FROM investigation_source_rows
                WHERE investigation_id = 'investigation-capacity'
                ORDER BY ordinal
                """
            )
            defer { sqlite3_finalize(statement) }
            var count = 0
            var payloadBytes: Int64 = 0
            var canonicalHash = SHA256()
            var remainingCanonicalBytes = 536_870_912
            while sqlite3_step(statement) == SQLITE_ROW {
                guard sqlite3_column_int(statement, 0) == count,
                      sqlite3_column_bytes(statement, 1) > 0,
                      sqlite3_column_bytes(statement, 2) > 0,
                      sqlite3_column_bytes(statement, 4) == 32
                else {
                    throw InvestigationStoreCapacityPreflightError.invalidRow
                }
                payloadBytes += sqlite3_column_int64(statement, 3)
                let chunkCount = min(remainingCanonicalBytes, 1_789)
                canonicalHash.update(
                    data: Data(
                        repeating: UInt8(truncatingIfNeeded: count),
                        count: chunkCount
                    )
                )
                remainingCanonicalBytes -= chunkCount
                count += 1
            }
            while remainingCanonicalBytes > 0 {
                let chunkCount = min(remainingCanonicalBytes, 1_048_576)
                canonicalHash.update(
                    data: Data(repeating: 0xA5, count: chunkCount)
                )
                remainingCanonicalBytes -= chunkCount
            }
            _ = canonicalHash.finalize()
            guard count == 300_002,
                  payloadBytes == 268_435_456
            else {
                throw InvestigationStoreCapacityPreflightError.invalidCount
            }
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
        try database.verify()
    }

    func commitMaximumTerminal(
        at url: URL,
        reportSuffix: String
    ) throws {
        let database = try InvestigationStoreCapacityPreflightDatabase(url: url)
        try database.execute("PRAGMA foreign_keys=ON")
        let reportID = "investigation-report-\(reportSuffix)"
        try database.execute("BEGIN IMMEDIATE")
        do {
            try database.execute(
                """
                INSERT INTO investigation_reports (
                    investigation_id, report_id, run_id, report_kind,
                    created_at_ms, evidence_row_count,
                    evidence_payload_byte_count, degradation_row_count,
                    degradation_payload_byte_count, payload
                ) VALUES (
                    'investigation-capacity', '\(reportID)',
                    'investigation-run-capacity', 'final', 1800000100000,
                    512, 8388608, 64, 524288, '{}'
                )
                """
            )
            let evidenceStatement = try database.statement(
                """
                INSERT INTO investigation_evidence (
                    investigation_id, report_id, run_id, target_id,
                    evidence_id, ordinal, evidence_kind, payload
                ) VALUES (
                    'investigation-capacity', ?, 'investigation-run-capacity',
                    ?, ?, ?, 'finding', ?
                )
                """
            )
            defer { sqlite3_finalize(evidenceStatement) }
            for ordinal in 0..<512 {
                try database.reset(evidenceStatement)
                try database.bind(
                    [
                        .text(reportID),
                        .text(String(
                            format: "target-%064llx",
                            UInt64(ordinal + 1)
                        )),
                        .text("investigation-evidence-\(reportSuffix)-\(ordinal)"),
                        .integer(Int64(ordinal)),
                        .text(String(repeating: "e", count: 16_384)),
                    ],
                    to: evidenceStatement
                )
                try database.stepDone(evidenceStatement)
            }
            let degradationStatement = try database.statement(
                """
                INSERT INTO investigation_report_degradations (
                    investigation_id, report_id, run_id, degradation_id,
                    ordinal, degradation_kind, payload
                ) VALUES (
                    'investigation-capacity', ?,
                    'investigation-run-capacity', ?, ?,
                    'runtime-limited', ?
                )
                """
            )
            defer { sqlite3_finalize(degradationStatement) }
            for ordinal in 0..<64 {
                try database.reset(degradationStatement)
                try database.bind(
                    [
                        .text(reportID),
                        .text(
                            "investigation-degradation-\(reportSuffix)-\(ordinal)"
                        ),
                        .integer(Int64(ordinal)),
                        .text(String(repeating: "d", count: 8_192)),
                    ],
                    to: degradationStatement
                )
                try database.stepDone(degradationStatement)
            }
            let budgetStatement = try database.statement(
                """
                INSERT INTO investigation_budget_events (
                    investigation_id, run_id, event_id, ordinal,
                    event_kind, payload
                ) VALUES (
                    'investigation-capacity', 'investigation-run-capacity',
                    ?, ?, 'reservation', ?
                )
                """
            )
            defer { sqlite3_finalize(budgetStatement) }
            for ordinal in 0..<4_096 {
                try database.reset(budgetStatement)
                try database.bind(
                    [
                        .text(
                            "investigation-budget-event-\(reportSuffix)-\(ordinal)"
                        ),
                        .integer(Int64(ordinal)),
                        .text(String(repeating: "b", count: 1_024)),
                    ],
                    to: budgetStatement
                )
                try database.stepDone(budgetStatement)
            }
            try database.execute(
                """
                UPDATE investigation_runs
                SET state='completed', terminal_report_id='\(reportID)',
                    terminal_at_ms=1800000100000,
                    updated_at_ms=1800000100000,
                    budget_event_count=4096,
                    budget_payload_byte_count=4194304
                WHERE investigation_id='investigation-capacity'
                  AND run_id='investigation-run-capacity'
                """
            )
            try database.execute(
                """
                UPDATE investigation_sessions
                SET state='completed', updated_at_ms=1800000100000,
                    report_count=1, evidence_row_count=512,
                    evidence_payload_byte_count=8388608,
                    degradation_row_count=64,
                    degradation_payload_byte_count=524288,
                    budget_event_count=4096,
                    budget_payload_byte_count=4194304
                WHERE id='investigation-capacity'
                """
            )
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
        try database.verify()
    }

    func createMaximumContinuation(at url: URL) throws {
        let database = try InvestigationStoreCapacityPreflightDatabase(url: url)
        try database.execute("PRAGMA foreign_keys=ON")
        try database.execute("BEGIN IMMEDIATE")
        do {
            try database.execute(
                """
                INSERT INTO investigation_runs (
                    investigation_id, run_id, run_ordinal,
                    target_set_fingerprint, plan_fingerprint, plan_json,
                    budget_preset, plan_created_at_ms, plan_expires_at_ms,
                    target_count, state, stage, created_at_ms, updated_at_ms,
                    payload
                ) VALUES (
                    'investigation-capacity',
                    'investigation-run-continuation', 1,
                    zeroblob(32), zeroblob(32), '{}', 'thorough',
                    1800000200000, 1800003800000, 512, 'planned',
                    'prioritize', 1800000200000, 1800000200000, '{}'
                )
                """
            )
            let statement = try database.statement(
                """
                INSERT INTO investigation_run_targets (
                    investigation_id, run_id, ordinal, target_id
                ) VALUES (
                    'investigation-capacity',
                    'investigation-run-continuation', ?, ?
                )
                """
            )
            defer { sqlite3_finalize(statement) }
            for ordinal in 0..<512 {
                try database.reset(statement)
                try database.bind(
                    [
                        .integer(Int64(ordinal)),
                        .text(String(
                            format: "target-%064llx",
                            UInt64(ordinal + 1)
                        )),
                    ],
                    to: statement
                )
                try database.stepDone(statement)
            }
            try database.execute(
                """
                UPDATE investigation_sessions
                SET run_count=2, updated_at_ms=1800000200000
                WHERE id='investigation-capacity'
                """
            )
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
        try database.verify()
    }

    private func sourceRow(
        ordinal: Int,
        remainingPayloadBytes: Int
    ) -> (
        bindings: [InvestigationStoreCapacityPreflightBinding],
        payloadByteCount: Int,
        canonicalByteCount: Int
    ) {
        let rowKind: String
        let primaryID: String
        var sourceSessionID: InvestigationStoreCapacityPreflightBinding = .null
        var relativePath: InvestigationStoreCapacityPreflightBinding = .null
        var snapshotID: InvestigationStoreCapacityPreflightBinding = .null
        var disposition: InvestigationStoreCapacityPreflightBinding = .null
        var startedAt: InvestigationStoreCapacityPreflightBinding = .null
        var finishedAt: InvestigationStoreCapacityPreflightBinding = .null
        var expiresAt: InvestigationStoreCapacityPreflightBinding = .null
        var observedAt: InvestigationStoreCapacityPreflightBinding = .null
        var classifiedAt: InvestigationStoreCapacityPreflightBinding = .null
        let payloadByteCount = min(
            max(1, remainingPayloadBytes - (300_001 - ordinal)),
            ordinal == 100_001 ? 16_777_216 : 1_048_576
        )
        switch ordinal {
        case 0:
            rowKind = "scan-session-v1"
            primaryID = "scan-capacity"
            startedAt = .integer(1_800_000_000_000)
            finishedAt = .integer(1_800_000_001_000)
            expiresAt = .integer(1_800_604_800_000)
        case 1...100_000:
            rowKind = "path-snapshot-v1"
            primaryID = "snapshot-\(ordinal)"
            sourceSessionID = .text("scan-capacity")
            relativePath = .text("capacity/\(ordinal)")
            observedAt = .integer(1_800_000_001_000)
        case 100_001:
            rowKind = "space-ledger-v1"
            primaryID = "scan-capacity"
            sourceSessionID = .text("scan-capacity")
        case 100_002...200_001:
            let index = ordinal - 100_001
            rowKind = "classification-v1"
            primaryID = "classification-\(index)"
            snapshotID = .text("snapshot-\(index)")
            disposition = .text("unknown")
            classifiedAt = .integer(1_800_000_001_000)
        default:
            let index = ordinal - 200_001
            rowKind = "evidence-v1"
            primaryID = "evidence-\(index)"
            snapshotID = .text("snapshot-\(index)")
            observedAt = .integer(1_800_000_001_000)
        }
        return (
            [
                .integer(Int64(ordinal)),
                .text(rowKind),
                .text(primaryID),
                .text(primaryID),
                sourceSessionID,
                relativePath,
                snapshotID,
                disposition,
                startedAt,
                finishedAt,
                expiresAt,
                observedAt,
                classifiedAt,
                .integer(Int64(payloadByteCount)),
                .blob(Data(SHA256.hash(data: Data(primaryID.utf8)))),
            ],
            payloadByteCount,
            1_789
        )
    }
}

private enum InvestigationStoreCapacityPreflightBinding {
    case integer(Int64)
    case text(String)
    case blob(Data)
    case null
}

private enum InvestigationStoreCapacityPreflightError: Error {
    case invalidCount
    case invalidRow
    case sqlite(Int32, String)
}

private final class InvestigationStoreCapacityPreflightDatabase {
    private let database: OpaquePointer

    init(url: URL) throws {
        var pointer: OpaquePointer?
        let code = sqlite3_open_v2(
            url.path,
            &pointer,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard code == SQLITE_OK, let pointer else {
            throw InvestigationStoreCapacityPreflightError.sqlite(
                code,
                "open"
            )
        }
        database = pointer
    }

    deinit {
        sqlite3_close_v2(database)
    }

    func execute(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        let code = sqlite3_exec(database, sql, nil, nil, &error)
        guard code == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(error)
            throw InvestigationStoreCapacityPreflightError.sqlite(code, message)
        }
    }

    func statement(_ sql: String) throws -> OpaquePointer {
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
            throw InvestigationStoreCapacityPreflightError.sqlite(
                code,
                String(cString: sqlite3_errmsg(database))
            )
        }
        return statement
    }

    func reset(_ statement: OpaquePointer) throws {
        guard sqlite3_reset(statement) == SQLITE_OK,
              sqlite3_clear_bindings(statement) == SQLITE_OK
        else {
            throw InvestigationStoreCapacityPreflightError.sqlite(
                SQLITE_MISUSE,
                "reset"
            )
        }
    }

    func bind(
        _ bindings: [InvestigationStoreCapacityPreflightBinding],
        to statement: OpaquePointer
    ) throws {
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
                code = value.withUnsafeBytes {
                    sqlite3_bind_blob(
                        statement,
                        index,
                        $0.baseAddress,
                        Int32($0.count),
                        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                    )
                }
            case .null:
                code = sqlite3_bind_null(statement, index)
            }
            guard code == SQLITE_OK else {
                throw InvestigationStoreCapacityPreflightError.sqlite(
                    code,
                    "bind"
                )
            }
        }
    }

    func stepDone(_ statement: OpaquePointer) throws {
        let code = sqlite3_step(statement)
        guard code == SQLITE_DONE else {
            throw InvestigationStoreCapacityPreflightError.sqlite(
                code,
                String(cString: sqlite3_errmsg(database))
            )
        }
    }

    func verify() throws {
        let quickCheck = try scalarText("PRAGMA quick_check")
        guard quickCheck == "ok",
              try scalarInt("SELECT count(*) FROM pragma_foreign_key_check") == 0
        else {
            throw InvestigationStoreCapacityPreflightError.invalidRow
        }
    }

    private func scalarInt(_ sql: String) throws -> Int64 {
        let statement = try statement(sql)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw InvestigationStoreCapacityPreflightError.invalidRow
        }
        return sqlite3_column_int64(statement, 0)
    }

    private func scalarText(_ sql: String) throws -> String {
        let statement = try statement(sql)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              let bytes = sqlite3_column_text(statement, 0)
        else {
            throw InvestigationStoreCapacityPreflightError.invalidRow
        }
        return String(cString: bytes)
    }
}

private final class InvestigationStoreCapacityPreflightFootprint {
    func sample() throws -> UInt64 {
        try info().phys_footprint
    }

    func peak() throws -> UInt64 {
        let peak = try info().ledger_phys_footprint_peak
        guard peak >= 0 else {
            throw InvestigationStoreCapacityPreflightError.invalidRow
        }
        return UInt64(peak)
    }

    private func info() throws -> task_vm_info_data_t {
        var value = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size
                / MemoryLayout<natural_t>.size
        )
        let code = withUnsafeMutablePointer(to: &value) { pointer in
            pointer.withMemoryRebound(
                to: integer_t.self,
                capacity: Int(count)
            ) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(TASK_VM_INFO),
                    $0,
                    &count
                )
            }
        }
        guard code == KERN_SUCCESS else {
            throw InvestigationStoreCapacityPreflightError.invalidRow
        }
        return value
    }
}

private let investigationStoreCapacityPreflightSchema = """
CREATE TABLE investigation_sessions (
    id TEXT PRIMARY KEY NOT NULL,
    scan_session_id TEXT NOT NULL,
    scan_scope_id TEXT NOT NULL,
    source_fingerprint BLOB NOT NULL CHECK(length(source_fingerprint)=32),
    state TEXT NOT NULL,
    stage TEXT NOT NULL,
    source_row_count INTEGER NOT NULL,
    relevance_token_count INTEGER NOT NULL,
    source_payload_byte_count INTEGER NOT NULL,
    source_canonical_byte_count INTEGER NOT NULL,
    run_count INTEGER NOT NULL DEFAULT 0,
    report_count INTEGER NOT NULL DEFAULT 0,
    evidence_row_count INTEGER NOT NULL DEFAULT 0,
    evidence_payload_byte_count INTEGER NOT NULL DEFAULT 0,
    degradation_row_count INTEGER NOT NULL DEFAULT 0,
    degradation_payload_byte_count INTEGER NOT NULL DEFAULT 0,
    budget_event_count INTEGER NOT NULL DEFAULT 0,
    budget_payload_byte_count INTEGER NOT NULL DEFAULT 0,
    created_at_ms INTEGER NOT NULL,
    updated_at_ms INTEGER NOT NULL,
    expires_at_ms INTEGER NOT NULL,
    UNIQUE(id, scan_session_id)
) STRICT;
CREATE TABLE investigation_source_rows (
    investigation_id TEXT NOT NULL,
    ordinal INTEGER NOT NULL,
    row_kind TEXT NOT NULL,
    primary_id TEXT NOT NULL,
    source_id TEXT NOT NULL,
    source_session_id TEXT,
    source_owner_session_id TEXT GENERATED ALWAYS AS (
        CASE row_kind
            WHEN 'scan-session-v1' THEN primary_id
            WHEN 'path-snapshot-v1' THEN source_session_id
            WHEN 'space-ledger-v1' THEN source_session_id
            ELSE NULL
        END
    ) STORED,
    source_relative_path TEXT,
    source_snapshot_id TEXT,
    source_snapshot_row_kind TEXT GENERATED ALWAYS AS (
        CASE WHEN source_snapshot_id IS NULL
            THEN NULL ELSE 'path-snapshot-v1' END
    ) STORED,
    source_disposition TEXT,
    source_started_at_ms INTEGER,
    source_finished_at_ms INTEGER,
    source_expires_at_ms INTEGER,
    source_observed_at_ms INTEGER,
    source_classified_at_ms INTEGER,
    source_payload_byte_count INTEGER NOT NULL,
    source_payload_sha256 BLOB NOT NULL CHECK(length(source_payload_sha256)=32),
    PRIMARY KEY(investigation_id, ordinal),
    UNIQUE(investigation_id, row_kind, primary_id),
    FOREIGN KEY(investigation_id)
        REFERENCES investigation_sessions(id) ON DELETE CASCADE
        DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(investigation_id, source_owner_session_id)
        REFERENCES investigation_sessions(id, scan_session_id)
        ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(
        investigation_id, source_snapshot_row_kind, source_snapshot_id
    ) REFERENCES investigation_source_rows(
        investigation_id, row_kind, primary_id
    ) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE TABLE investigation_relevance_tokens (
    investigation_id TEXT NOT NULL,
    ordinal INTEGER NOT NULL,
    token TEXT NOT NULL,
    PRIMARY KEY(investigation_id, ordinal),
    UNIQUE(investigation_id, token),
    FOREIGN KEY(investigation_id)
        REFERENCES investigation_sessions(id) ON DELETE CASCADE
) STRICT;
CREATE TABLE investigation_targets (
    investigation_id TEXT NOT NULL,
    target_id TEXT NOT NULL,
    ordinal INTEGER NOT NULL,
    target_kind TEXT NOT NULL,
    payload TEXT NOT NULL,
    PRIMARY KEY(investigation_id, target_id),
    UNIQUE(investigation_id, ordinal),
    FOREIGN KEY(investigation_id)
        REFERENCES investigation_sessions(id) ON DELETE CASCADE
) STRICT;
CREATE TABLE investigation_runs (
    investigation_id TEXT NOT NULL,
    run_id TEXT NOT NULL,
    run_ordinal INTEGER NOT NULL,
    target_set_fingerprint BLOB NOT NULL,
    plan_fingerprint BLOB NOT NULL,
    plan_json TEXT NOT NULL,
    budget_preset TEXT NOT NULL,
    plan_created_at_ms INTEGER NOT NULL,
    plan_expires_at_ms INTEGER NOT NULL,
    target_count INTEGER NOT NULL,
    parent_run_id TEXT,
    parent_report_id TEXT,
    state TEXT NOT NULL,
    stage TEXT NOT NULL,
    terminal_cause TEXT,
    terminal_report_id TEXT,
    budget_event_count INTEGER NOT NULL DEFAULT 0,
    budget_payload_byte_count INTEGER NOT NULL DEFAULT 0,
    created_at_ms INTEGER NOT NULL,
    updated_at_ms INTEGER NOT NULL,
    terminal_at_ms INTEGER,
    payload TEXT NOT NULL,
    PRIMARY KEY(investigation_id, run_id),
    UNIQUE(investigation_id, run_ordinal),
    FOREIGN KEY(investigation_id)
        REFERENCES investigation_sessions(id) ON DELETE CASCADE
) STRICT;
CREATE TABLE investigation_run_targets (
    investigation_id TEXT NOT NULL,
    run_id TEXT NOT NULL,
    ordinal INTEGER NOT NULL,
    target_id TEXT NOT NULL,
    PRIMARY KEY(investigation_id, run_id, ordinal),
    UNIQUE(investigation_id, run_id, target_id),
    FOREIGN KEY(investigation_id, run_id)
        REFERENCES investigation_runs(investigation_id, run_id),
    FOREIGN KEY(investigation_id, target_id)
        REFERENCES investigation_targets(investigation_id, target_id)
) STRICT;
CREATE TABLE investigation_reports (
    investigation_id TEXT NOT NULL,
    report_id TEXT NOT NULL,
    run_id TEXT NOT NULL,
    report_kind TEXT NOT NULL,
    created_at_ms INTEGER NOT NULL,
    evidence_row_count INTEGER NOT NULL,
    evidence_payload_byte_count INTEGER NOT NULL,
    degradation_row_count INTEGER NOT NULL,
    degradation_payload_byte_count INTEGER NOT NULL,
    payload TEXT NOT NULL,
    PRIMARY KEY(investigation_id, report_id),
    UNIQUE(investigation_id, run_id),
    UNIQUE(investigation_id, report_id, run_id)
) STRICT;
CREATE TABLE investigation_evidence (
    investigation_id TEXT NOT NULL,
    report_id TEXT NOT NULL,
    run_id TEXT NOT NULL,
    target_id TEXT NOT NULL,
    evidence_id TEXT NOT NULL,
    ordinal INTEGER NOT NULL,
    evidence_kind TEXT NOT NULL,
    payload TEXT NOT NULL,
    PRIMARY KEY(investigation_id, report_id, evidence_id),
    UNIQUE(investigation_id, report_id, ordinal),
    FOREIGN KEY(investigation_id, report_id, run_id)
        REFERENCES investigation_reports(investigation_id, report_id, run_id),
    FOREIGN KEY(investigation_id, run_id, target_id)
        REFERENCES investigation_run_targets(
            investigation_id, run_id, target_id
        )
) STRICT;
CREATE TABLE investigation_report_degradations (
    investigation_id TEXT NOT NULL,
    report_id TEXT NOT NULL,
    run_id TEXT NOT NULL,
    degradation_id TEXT NOT NULL,
    ordinal INTEGER NOT NULL,
    degradation_kind TEXT NOT NULL,
    payload TEXT NOT NULL,
    PRIMARY KEY(investigation_id, report_id, degradation_id),
    UNIQUE(investigation_id, report_id, ordinal),
    FOREIGN KEY(investigation_id, report_id, run_id)
        REFERENCES investigation_reports(investigation_id, report_id, run_id)
) STRICT;
CREATE TABLE investigation_budget_events (
    investigation_id TEXT NOT NULL,
    run_id TEXT NOT NULL,
    event_id TEXT NOT NULL,
    ordinal INTEGER NOT NULL,
    event_kind TEXT NOT NULL,
    payload TEXT NOT NULL,
    PRIMARY KEY(investigation_id, run_id, event_id),
    UNIQUE(investigation_id, run_id, ordinal),
    FOREIGN KEY(investigation_id, run_id)
        REFERENCES investigation_runs(investigation_id, run_id)
) STRICT;
"""
