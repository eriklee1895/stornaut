import Foundation
import CryptoKit
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

struct PathSnapshotCursor: Sendable, Equatable {
    let relativePath: String
    let id: String
}

struct PathSnapshotCursorPage: Sendable {
    let page: StorePage<PathSnapshot>
    let nextCursor: PathSnapshotCursor?
    let rowCount: Int
}

struct CleanupPlanningCursor: Sendable, Equatable {
    let relativePath: String
    let snapshotID: String
    let classificationID: String
}

struct CleanupPlanningRecord: Sendable, Equatable {
    let snapshot: PathSnapshot
    let classification: Classification
}

struct CleanupPlanningPage: Sendable {
    let records: [CleanupPlanningRecord]
    let corruptRecordIDs: [String]
    let nextCursor: CleanupPlanningCursor?
    let rowCount: Int
}

public struct CleanupPolicyStoreRecord: Sendable, Equatable {
    public let planItem: CleanupPlanItem
    public let snapshot: PathSnapshot
    public let classification: Classification
    public let evidence: [EvidenceRecord]

    public init(
        planItem: CleanupPlanItem,
        snapshot: PathSnapshot,
        classification: Classification,
        evidence: [EvidenceRecord]
    ) {
        self.planItem = planItem
        self.snapshot = snapshot
        self.classification = classification
        self.evidence = evidence
    }
}

public struct ScanHistoryPage: Sendable, Equatable {
    public let sessions: [ScanSession]
    public let ledgersBySessionID: [ScanSessionID: SpaceLedger]
    public let corruptSessionIDs: [String]
    public let corruptLedgerSessionIDs: [String]

    public init(
        sessions: [ScanSession],
        ledgersBySessionID: [ScanSessionID: SpaceLedger],
        corruptSessionIDs: [String],
        corruptLedgerSessionIDs: [String]
    ) {
        self.sessions = sessions
        self.ledgersBySessionID = ledgersBySessionID
        self.corruptSessionIDs = corruptSessionIDs
        self.corruptLedgerSessionIDs = corruptLedgerSessionIDs
    }
}

public enum CleanupManifestEvidenceAvailability:
    String,
    Sendable,
    Equatable
{
    case retained
    case expired
}

public struct CleanupManifestHistoryRecord: Sendable, Equatable {
    public let manifest: CleanupManifest
    public let linkedPlan: CleanupPlan?
    public let evidenceAvailability: CleanupManifestEvidenceAvailability

    public init(
        manifest: CleanupManifest,
        linkedPlan: CleanupPlan?,
        evidenceAvailability: CleanupManifestEvidenceAvailability
    ) {
        self.manifest = manifest
        self.linkedPlan = linkedPlan
        self.evidenceAvailability = evidenceAvailability
    }
}

public struct CleanupManifestHistoryPage: Sendable, Equatable {
    public let records: [CleanupManifestHistoryRecord]
    public let corruptManifestIDs: [String]

    public init(
        records: [CleanupManifestHistoryRecord],
        corruptManifestIDs: [String]
    ) {
        self.records = records
        self.corruptManifestIDs = Array(Set(corruptManifestIDs)).sorted()
    }
}

public struct EvidenceHistorySnapshot: Sendable, Equatable {
    public let scans: ScanHistoryPage
    public let manifests: CleanupManifestHistoryPage

    public init(
        scans: ScanHistoryPage,
        manifests: CleanupManifestHistoryPage
    ) {
        self.scans = scans
        self.manifests = manifests
    }
}

public struct EvidenceRecordCounts: Sendable, Equatable {
    public let evidenceSessions: Int
    public let manifests: Int

    public init(evidenceSessions: Int, manifests: Int) {
        self.evidenceSessions = evidenceSessions
        self.manifests = manifests
    }
}

public struct QuickScanStoreSummary: Sendable, Equatable {
    public let snapshotCount: Int
    public let retainedSnapshotCount: Int
    public let classificationCount: Int
    public let evidenceCount: Int
    public let dispositionCounts: QuickScanDispositionCounts

    public init(
        snapshotCount: Int,
        retainedSnapshotCount: Int? = nil,
        classificationCount: Int,
        evidenceCount: Int,
        dispositionCounts: QuickScanDispositionCounts
    ) throws {
        let retainedSnapshotCount =
            retainedSnapshotCount ?? snapshotCount
        guard snapshotCount >= 0,
              retainedSnapshotCount >= 0,
              retainedSnapshotCount <= snapshotCount,
              classificationCount >= 0,
              evidenceCount >= 0,
              dispositionCounts.total == classificationCount
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.snapshotCount = snapshotCount
        self.retainedSnapshotCount = retainedSnapshotCount
        self.classificationCount = classificationCount
        self.evidenceCount = evidenceCount
        self.dispositionCounts = dispositionCounts
    }
}

struct EvidenceStoreTestHooks: Sendable {
    let failMigrationToVersion: Int?
    let now: @Sendable () -> Date
    let monotonicNanoseconds: @Sendable () -> UInt64
    let isCancelled: @Sendable () -> Bool
    let investigationProgress:
        @Sendable (InvestigationStoreProgress) -> Void
    let forceRollbackUnconfirmedOperations: Set<String>

    init(
        failMigrationToVersion: Int? = nil,
        now: @escaping @Sendable () -> Date = Date.init,
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
        self.failMigrationToVersion = failMigrationToVersion
        self.now = now
        self.monotonicNanoseconds = monotonicNanoseconds
        self.isCancelled = isCancelled
        self.investigationProgress = investigationProgress
        self.forceRollbackUnconfirmedOperations =
            forceRollbackUnconfirmedOperations
    }
}

private struct PreparedInvestigationPayload<Value: Sendable>:
    Sendable
{
    let input: Value
    let payload: String
}

private struct PreparedInvestigationReport: Sendable {
    let input: InvestigationTerminalReportInput
    let payload: String
    let evidence:
        [PreparedInvestigationPayload<InvestigationEvidenceInput>]
    let degradations:
        [PreparedInvestigationPayload<InvestigationDegradationInput>]
    let evidencePayloadBytes: Int64
    let degradationPayloadBytes: Int64
}

private struct PreparedInvestigationTerminal: Sendable {
    let report: PreparedInvestigationReport?
    let budgetEvents:
        [PreparedInvestigationPayload<InvestigationBudgetEventInput>]
    let budgetPayloadBytes: Int64
}

private struct InvestigationTerminalRunIdentity {
    let runState: InvestigationRunState
    let sessionState: InvestigationSessionState
    let terminalCause: InvestigationTerminalCause?
    let terminalReportID: InvestigationReportID?
    let updatedAtMilliseconds: Int64
    let terminalAtMilliseconds: Int64?
}

private struct InvestigationAggregateCounts {
    let reportCount: Int64
    let evidenceCount: Int64
    let evidenceBytes: Int64
    let degradationCount: Int64
    let degradationBytes: Int64
    let budgetCount: Int64
    let budgetBytes: Int64
}

private struct InvestigationLoadedRun {
    let parentRunID: InvestigationRunID?
    let parentReportID: InvestigationReportID?
    let state: InvestigationRunState
    let stage: InvestigationStage
    let terminalCause: InvestigationTerminalCause?
    let reportID: InvestigationReportID?
    let reportKind: InvestigationReportKind?
    let plan: InvestigationPlan
}

public actor EvidenceStore {
    private static let schemaVersion = 4
    private static let sevenDaysMilliseconds: Int64 = 7 * 86_400 * 1_000
    private static let ninetyDaysMilliseconds: Int64 = 90 * 86_400 * 1_000

    private let connection: SQLiteConnection
    private let now: @Sendable () -> Date

    public init(configuration: LocalStoreConfiguration) throws {
        try self.init(
            configuration: configuration,
            testHooks: EvidenceStoreTestHooks()
        )
    }

    public init(
        configuration: LocalStoreConfiguration,
        investigationProgress: @escaping @Sendable (
            InvestigationStoreProgress
        ) -> Void
    ) throws {
        try self.init(
            configuration: configuration,
            testHooks: EvidenceStoreTestHooks(
                investigationProgress: investigationProgress
            )
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
                : configuration.evidenceDatabaseURL.path,
            testHooks: SQLiteConnectionTestHooks(
                monotonicNanoseconds: testHooks.monotonicNanoseconds,
                isCancelled: testHooks.isCancelled,
                investigationProgress: testHooks.investigationProgress,
                forceRollbackUnconfirmedOperations:
                    testHooks.forceRollbackUnconfirmedOperations
            )
        )
        self.connection = connection
        now = testHooks.now
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

    public func storeHealth() -> EvidenceStoreHealth {
        connection.health
    }

    public func createInvestigation(
        _ command: InvestigationCreateCommand
    ) throws -> InvestigationStoredSession {
        try validateInvestigationCreateCommand(command)
        return try connection.transaction(operation: "investigation.create") {
            if let existing = try loadInvestigation(
                id: command.investigationID
            ) {
                guard try investigationReplay(
                    existing,
                    matches: command
                ) else {
                    throw InvestigationPersistenceError.conflictingReplay
                }
                return existing
            }

            let source: InvestigationSourceProjection
            do {
                source = try connection.createInvestigationSource(
                    investigationID: command.investigationID,
                    scanSessionID: command.scanSessionID,
                    scanScopeID: command.scanScopeID,
                    relevanceTokens: command.relevanceTokens,
                    planningAt: command.planningAt
                )
            } catch {
                throw mapInvestigationSourceError(error)
            }
            connection.reportInvestigationPlanningProgress()
            let planning: InvestigationPlanningResult
            do {
                planning = try InvestigationCandidatePlanner().plan(
                    investigationID: command.investigationID,
                    source: source,
                    budgetPreset: command.budgetPreset,
                    planningAt: command.planningAt
                )
            } catch {
                throw mapInvestigationPlanningError(error)
            }
            guard planning.diagnostics.outcome == .planned,
                  !planning.plan.targets.isEmpty
            else {
                throw InvestigationPersistenceError.noEligibleTargets
            }

            let createdAtMilliseconds = storeMilliseconds(
                command.planningAt
            )
            let retentionAddition = createdAtMilliseconds
                .addingReportingOverflow(Self.sevenDaysMilliseconds)
            let sourceExpiryMilliseconds = storeMilliseconds(
                source.policyIndex.session.expiresAt
            )
            guard !retentionAddition.overflow else {
                throw InvestigationPersistenceError.invalidCommand
            }
            let expiresAtMilliseconds = min(
                sourceExpiryMilliseconds,
                retentionAddition.partialValue
            )
            guard expiresAtMilliseconds > createdAtMilliseconds,
                  let sourceRowCount = Int64(
                      exactly: source.summary.sourceRowCount
                  ),
                  let relevanceTokenCount = Int64(
                      exactly: source.summary.relevanceTokens.count
                  ),
                  let sourcePayloadByteCount = Int64(
                      exactly: source.summary.exactPayloadBytes
                  ),
                  let sourceCanonicalByteCount = Int64(
                      exactly: source.summary.completeCanonicalBytes
                  )
            else {
                throw InvestigationPersistenceError.invalidCommand
            }

            try connection.execute(
                """
                INSERT INTO investigation_sessions (
                    id, scan_session_id, scan_scope_id, source_fingerprint,
                    state, stage, source_row_count, relevance_token_count,
                    source_payload_byte_count, source_canonical_byte_count,
                    run_count, report_count, evidence_row_count,
                    evidence_payload_byte_count, degradation_row_count,
                    degradation_payload_byte_count, budget_event_count,
                    budget_payload_byte_count, created_at_ms, updated_at_ms,
                    expires_at_ms
                ) VALUES (
                    ?, ?, ?, ?, 'planned', 'prioritize', ?, ?, ?, ?, 1,
                    0, 0, 0, 0, 0, 0, 0, ?, ?, ?
                )
                """,
                bindings: [
                    .text(command.investigationID.rawValue),
                    .text(command.scanSessionID.rawValue),
                    .text(command.scanScopeID.rawValue),
                    .blob(source.summary.sourceFingerprint.bytes),
                    .integer(sourceRowCount),
                    .integer(relevanceTokenCount),
                    .integer(sourcePayloadByteCount),
                    .integer(sourceCanonicalByteCount),
                    .integer(createdAtMilliseconds),
                    .integer(createdAtMilliseconds),
                    .integer(expiresAtMilliseconds),
                ],
                operation: "investigation.create.session"
            )
            try connection.persistStagedInvestigationSource(
                investigationID: command.investigationID
            )
            for (ordinal, token) in source.summary.relevanceTokens.enumerated() {
                try connection.execute(
                    """
                    INSERT INTO investigation_relevance_tokens (
                        investigation_id, ordinal, token
                    ) VALUES (?, ?, ?)
                    """,
                    bindings: [
                        .text(command.investigationID.rawValue),
                        .integer(Int64(ordinal)),
                        .text(token.rawValue),
                    ],
                    operation: "investigation.create.relevanceToken"
                )
            }
            for (ordinal, target) in planning.plan.targets.enumerated() {
                try connection.execute(
                    """
                    INSERT INTO investigation_targets (
                        investigation_id, target_id, ordinal,
                        target_kind, payload
                    ) VALUES (?, ?, ?, ?, ?)
                    """,
                    bindings: [
                        .text(command.investigationID.rawValue),
                        .text(target.id.rawValue),
                        .integer(Int64(ordinal)),
                        .text(target.kind.rawValue),
                        .text(try encodeInvestigationPayload(target)),
                    ],
                    operation: "investigation.create.target"
                )
            }

            let planJSON = try boundedInvestigationPlanJSON(planning.plan)
            let runPayload = InvestigationRunStoragePayload(
                investigationID: command.investigationID,
                runID: command.initialRunID
            )
            try connection.execute(
                """
                INSERT INTO investigation_runs (
                    investigation_id, run_id, run_ordinal,
                    target_set_fingerprint, plan_fingerprint, plan_json,
                    budget_preset, plan_created_at_ms, plan_expires_at_ms,
                    target_count, parent_run_id, parent_report_id,
                    state, stage, terminal_cause, terminal_report_id,
                    budget_event_count, budget_payload_byte_count,
                    created_at_ms, updated_at_ms, terminal_at_ms, payload
                ) VALUES (
                    ?, ?, 0, ?, ?, ?, ?, ?, ?, ?, NULL, NULL,
                    'planned', 'prioritize', NULL, NULL, 0, 0,
                    ?, ?, NULL, ?
                )
                """,
                bindings: [
                    .text(command.investigationID.rawValue),
                    .text(command.initialRunID.rawValue),
                    .blob(planning.plan.targetSetFingerprint.bytes),
                    .blob(planning.plan.fingerprint.bytes),
                    .text(planJSON),
                    .text(command.budgetPreset.rawValue),
                    .integer(storeMilliseconds(planning.plan.createdAt)),
                    .integer(storeMilliseconds(planning.plan.expiresAt)),
                    .integer(Int64(planning.plan.targets.count)),
                    .integer(createdAtMilliseconds),
                    .integer(createdAtMilliseconds),
                    .text(try encodeInvestigationPayload(runPayload)),
                ],
                operation: "investigation.create.run"
            )
            for (ordinal, target) in planning.plan.targets.enumerated() {
                try connection.execute(
                    """
                    INSERT INTO investigation_run_targets (
                        investigation_id, run_id, ordinal, target_id
                    ) VALUES (?, ?, ?, ?)
                    """,
                    bindings: [
                        .text(command.investigationID.rawValue),
                        .text(command.initialRunID.rawValue),
                        .integer(Int64(ordinal)),
                        .text(target.id.rawValue),
                    ],
                    operation: "investigation.create.runTarget"
                )
            }
            try verifyInvestigationSource(
                id: command.investigationID,
                expected: source
            )
            let foreignKeyViolations = try connection.query(
                "PRAGMA foreign_key_check",
                operation: "investigation.create.foreignKeys"
            ) { _ in true }
            guard foreignKeyViolations.isEmpty else {
                throw InvestigationPersistenceError.invalidStoredRecord
            }
            guard let stored = try loadInvestigation(
                id: command.investigationID
            ) else {
                throw InvestigationPersistenceError.invalidStoredRecord
            }
            return stored
        }
    }

    public func rejoinInvestigation(
        id: InvestigationID,
        barrier: InvestigationRejoinBarrier
    ) throws -> InvestigationRejoinResult {
        try connection.transaction(operation: "investigation.rejoin") {
            _ = barrier
            return try rejoinInvestigationInCurrentTransaction(
                id: id,
                currentTime: now()
            )
        }
    }

    public func investigation(
        id: InvestigationID
    ) throws -> InvestigationStoredSession? {
        try loadInvestigation(id: id)
    }

    public func investigations(
        limit: Int,
        offset: Int
    ) throws -> StorePage<InvestigationStoredSession> {
        try validatePage(limit: limit, offset: offset)
        let ids = try connection.query(
            """
            SELECT id
            FROM investigation_sessions
            ORDER BY updated_at_ms DESC, id ASC
            LIMIT ? OFFSET ?
            """,
            bindings: [
                .integer(Int64(limit)),
                .integer(Int64(offset)),
            ],
            operation: "investigation.page.identities"
        ) {
            columnText($0, 0)
        }
        var records: [InvestigationStoredSession] = []
        var corruptRecordIDs: [String] = []
        for rawID in ids {
            do {
                let id = try InvestigationID(validating: rawID)
                guard let record = try loadInvestigation(id: id) else {
                    corruptRecordIDs.append(rawID)
                    continue
                }
                records.append(record)
            } catch {
                corruptRecordIDs.append(rawID)
            }
        }
        return StorePage(
            records: records,
            corruptRecordIDs: corruptRecordIDs
        )
    }

    public func transitionInvestigationRun(
        _ command: InvestigationRunTransitionCommand
    ) throws -> InvestigationStoredSession {
        try connection.transaction(operation: "investigation.transition") {
            let current = try connection.query(
                """
                SELECT run.state, session.state, run.updated_at_ms
                FROM investigation_runs run
                JOIN investigation_sessions session
                  ON session.id = run.investigation_id
                WHERE run.investigation_id = ? AND run.run_id = ?
                """,
                bindings: [
                    .text(command.investigationID.rawValue),
                    .text(command.runID.rawValue),
                ],
                operation: "investigation.transition.current"
            ) {
                (
                    runState: columnText($0, 0),
                    sessionState: columnText($0, 1),
                    updatedAt: sqlite3_column_int64($0, 2)
                )
            }
            guard let row = current.first,
                  current.count == 1,
                  row.runState == command.expectedRunState.rawValue,
                  row.sessionState == command.expectedRunState.rawValue,
                  storeMilliseconds(command.updatedAt) >= row.updatedAt
            else {
                throw InvestigationPersistenceError.conflictingReplay
            }
            let updatedAt = storeMilliseconds(command.updatedAt)
            try connection.execute(
                """
                UPDATE investigation_runs
                SET state = ?, stage = ?, terminal_cause = ?,
                    updated_at_ms = ?
                WHERE investigation_id = ? AND run_id = ?
                  AND state = ?
                """,
                bindings: [
                    .text(command.runState.rawValue),
                    .text(command.stage.rawValue),
                    command.terminalCause.map {
                        .text($0.rawValue)
                    } ?? .null,
                    .integer(updatedAt),
                    .text(command.investigationID.rawValue),
                    .text(command.runID.rawValue),
                    .text(command.expectedRunState.rawValue),
                ],
                operation: "investigation.transition.run"
            )
            try connection.execute(
                """
                UPDATE investigation_sessions
                SET state = ?, stage = ?, updated_at_ms = ?
                WHERE id = ? AND state = ?
                """,
                bindings: [
                    .text(command.sessionState.rawValue),
                    .text(command.stage.rawValue),
                    .integer(updatedAt),
                    .text(command.investigationID.rawValue),
                    .text(command.expectedRunState.rawValue),
                ],
                operation: "investigation.transition.session"
            )
            guard let stored = try loadInvestigation(
                id: command.investigationID
            ), stored.state == command.sessionState,
               stored.stage == command.stage
            else {
                throw InvestigationPersistenceError.invalidStoredRecord
            }
            return stored
        }
    }

    public func commitInvestigationTerminal(
        _ command: InvestigationTerminalCommand
    ) throws -> InvestigationTerminalResult {
        try commitInvestigationTerminal(
            command,
            transactionOperation: "investigation.terminal"
        )
    }

    public func promoteInvestigationRecovery(
        _ command: InvestigationTerminalCommand
    ) throws -> InvestigationTerminalResult {
        try commitInvestigationTerminal(
            command,
            transactionOperation: "investigation.recoveryPromotion"
        )
    }

    private func commitInvestigationTerminal(
        _ command: InvestigationTerminalCommand,
        transactionOperation: String
    ) throws -> InvestigationTerminalResult {
        try connection.transaction(operation: transactionOperation) {
            if let replay = try terminalReplay(command) {
                return replay
            }
            let currentTime = now()
            switch try rejoinInvestigationInCurrentTransaction(
                id: command.investigationID,
                currentTime: currentTime
            ) {
            case .matching:
                break
            case .stale:
                throw InvestigationPersistenceError.sourceStale
            case .corrupt:
                throw InvestigationPersistenceError.sourceCorrupt
            case .expired:
                throw InvestigationPersistenceError.sourceExpired
            case .missing:
                throw InvestigationPersistenceError.sourceMissing
            }
            let current = try terminalRunIdentity(
                investigationID: command.investigationID,
                runID: command.runID
            )
            guard current.runState == .terminalBarrier,
                  current.sessionState == .terminalBarrier,
                  current.terminalCause == command.cause,
                  current.terminalReportID == nil,
                  current.terminalAtMilliseconds == nil,
                  storeMilliseconds(command.terminalAt)
                    >= current.updatedAtMilliseconds
            else {
                throw InvestigationPersistenceError.conflictingTerminalReplay
            }

            let prepared = try prepareTerminalCommand(command)
            for event in prepared.budgetEvents {
                try connection.execute(
                    """
                    INSERT INTO investigation_budget_events (
                        investigation_id, run_id, event_id,
                        ordinal, event_kind, payload
                    ) VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    bindings: [
                        .text(command.investigationID.rawValue),
                        .text(command.runID.rawValue),
                        .text(event.input.id.rawValue),
                        .integer(Int64(event.input.ordinal)),
                        .text(event.input.kind.rawValue),
                        .text(event.payload),
                    ],
                    operation: "investigation.terminal.budget"
                )
            }
            if let report = prepared.report {
                try connection.execute(
                    """
                    INSERT INTO investigation_reports (
                        investigation_id, report_id, run_id, report_kind,
                        created_at_ms, evidence_row_count,
                        evidence_payload_byte_count, degradation_row_count,
                        degradation_payload_byte_count, payload
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    bindings: [
                        .text(command.investigationID.rawValue),
                        .text(report.input.id.rawValue),
                        .text(command.runID.rawValue),
                        .text(report.input.kind.rawValue),
                        .integer(storeMilliseconds(command.terminalAt)),
                        .integer(Int64(report.evidence.count)),
                        .integer(report.evidencePayloadBytes),
                        .integer(Int64(report.degradations.count)),
                        .integer(report.degradationPayloadBytes),
                        .text(report.payload),
                    ],
                    operation: "investigation.terminal.report"
                )
                for (ordinal, evidence) in report.evidence.enumerated() {
                    try connection.execute(
                        """
                        INSERT INTO investigation_evidence (
                            investigation_id, report_id, run_id, target_id,
                            evidence_id, ordinal, evidence_kind, payload
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        bindings: [
                            .text(command.investigationID.rawValue),
                            .text(report.input.id.rawValue),
                            .text(command.runID.rawValue),
                            .text(evidence.input.targetID.rawValue),
                            .text(evidence.input.id.rawValue),
                            .integer(Int64(ordinal)),
                            .text(evidence.input.kind.rawValue),
                            .text(evidence.payload),
                        ],
                        operation: "investigation.terminal.evidence"
                    )
                }
                for (ordinal, degradation) in
                    report.degradations.enumerated()
                {
                    try connection.execute(
                        """
                        INSERT INTO investigation_report_degradations (
                            investigation_id, report_id, run_id,
                            degradation_id, ordinal,
                            degradation_kind, payload
                        ) VALUES (?, ?, ?, ?, ?, ?, ?)
                        """,
                        bindings: [
                            .text(command.investigationID.rawValue),
                            .text(report.input.id.rawValue),
                            .text(command.runID.rawValue),
                            .text(degradation.input.id.rawValue),
                            .integer(Int64(ordinal)),
                            .text(degradation.input.kind.rawValue),
                            .text(degradation.payload),
                        ],
                        operation: "investigation.terminal.degradation"
                    )
                }
            }

            let terminalAt = storeMilliseconds(command.terminalAt)
            try connection.execute(
                """
                UPDATE investigation_runs
                SET state = ?, stage = ?, terminal_report_id = ?,
                    budget_event_count = ?,
                    budget_payload_byte_count = ?,
                    updated_at_ms = ?, terminal_at_ms = ?
                WHERE investigation_id = ? AND run_id = ?
                  AND state = 'terminalBarrier'
                """,
                bindings: [
                    .text(command.runState.rawValue),
                    .text(command.stage.rawValue),
                    command.report.map {
                        .text($0.id.rawValue)
                    } ?? .null,
                    .integer(Int64(prepared.budgetEvents.count)),
                    .integer(prepared.budgetPayloadBytes),
                    .integer(terminalAt),
                    .integer(terminalAt),
                    .text(command.investigationID.rawValue),
                    .text(command.runID.rawValue),
                ],
                operation: "investigation.terminal.run"
            )
            let aggregates = try investigationAggregates(
                id: command.investigationID
            )
            try connection.execute(
                """
                UPDATE investigation_sessions
                SET state = ?, stage = ?, report_count = ?,
                    evidence_row_count = ?,
                    evidence_payload_byte_count = ?,
                    degradation_row_count = ?,
                    degradation_payload_byte_count = ?,
                    budget_event_count = ?,
                    budget_payload_byte_count = ?,
                    updated_at_ms = ?
                WHERE id = ? AND state = 'terminalBarrier'
                """,
                bindings: [
                    .text(command.sessionState.rawValue),
                    .text(command.stage.rawValue),
                    .integer(aggregates.reportCount),
                    .integer(aggregates.evidenceCount),
                    .integer(aggregates.evidenceBytes),
                    .integer(aggregates.degradationCount),
                    .integer(aggregates.degradationBytes),
                    .integer(aggregates.budgetCount),
                    .integer(aggregates.budgetBytes),
                    .integer(terminalAt),
                    .text(command.investigationID.rawValue),
                ],
                operation: "investigation.terminal.session"
            )
            try verifyInvestigationTerminalCounters(
                investigationID: command.investigationID,
                runID: command.runID,
                reportID: command.report?.id
            )
            let foreignKeyViolations = try connection.query(
                "PRAGMA foreign_key_check",
                operation: "investigation.terminal.foreignKeys"
            ) { _ in true }
            guard foreignKeyViolations.isEmpty,
                  let result = try loadTerminalResult(
                      investigationID: command.investigationID,
                      reportID: command.report?.id
                  )
            else {
                throw InvestigationPersistenceError.invalidStoredRecord
            }
            return result
        }
    }

    public func investigationReports(
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        limit: Int,
        offset: Int
    ) throws -> StorePage<InvestigationStoredReport> {
        try validatePage(limit: limit, offset: offset)
        let rows = try connection.query(
            """
            SELECT report_id
            FROM investigation_reports
            WHERE investigation_id = ? AND run_id = ?
            ORDER BY created_at_ms DESC, report_id ASC
            LIMIT ? OFFSET ?
            """,
            bindings: [
                .text(investigationID.rawValue),
                .text(runID.rawValue),
                .integer(Int64(limit)),
                .integer(Int64(offset)),
            ],
            operation: "investigation.report.page"
        ) {
            columnText($0, 0)
        }
        var records: [InvestigationStoredReport] = []
        var corrupt: [String] = []
        for rawID in rows {
            do {
                let id = try InvestigationReportID(validating: rawID)
                guard let record = try loadInvestigationReport(
                    investigationID: investigationID,
                    reportID: id
                ), record.runID == runID
                else {
                    corrupt.append(rawID)
                    continue
                }
                records.append(record)
            } catch {
                corrupt.append(rawID)
            }
        }
        return StorePage(records: records, corruptRecordIDs: corrupt)
    }

    public func investigationEvidence(
        investigationID: InvestigationID,
        reportID: InvestigationReportID,
        limit: Int,
        offset: Int
    ) throws -> StorePage<InvestigationStoredEvidence> {
        try validatePage(limit: limit, offset: offset)
        let rows = try connection.query(
            """
            SELECT report_id, run_id, target_id, evidence_id,
                   ordinal, evidence_kind, payload
            FROM investigation_evidence
            WHERE investigation_id = ? AND report_id = ?
            ORDER BY ordinal ASC, evidence_id ASC
            LIMIT ? OFFSET ?
            """,
            bindings: [
                .text(investigationID.rawValue),
                .text(reportID.rawValue),
                .integer(Int64(limit)),
                .integer(Int64(offset)),
            ],
            operation: "investigation.evidence.page"
        ) { statement in
            (
                reportID: columnText(statement, 0),
                runID: columnText(statement, 1),
                targetID: columnText(statement, 2),
                evidenceID: columnText(statement, 3),
                ordinal: sqlite3_column_int64(statement, 4),
                kind: columnText(statement, 5),
                payload: columnText(statement, 6)
            )
        }
        var records: [InvestigationStoredEvidence] = []
        var corrupt: [String] = []
        for row in rows {
            do {
                let record = try InvestigationStoredEvidence(
                    investigationID: investigationID,
                    reportID: InvestigationReportID(
                        validating: row.reportID
                    ),
                    runID: InvestigationRunID(validating: row.runID),
                    targetID: InvestigationTargetID(
                        validating: row.targetID
                    ),
                    id: InvestigationEvidenceID(
                        validating: row.evidenceID
                    ),
                    ordinal: checkedInvestigationOrdinal(row.ordinal),
                    kind: try investigationEnum(
                        InvestigationPersistedEvidenceKind.self,
                        rawValue: row.kind
                    ),
                    payload: try decodeInvestigationPayload(
                        InvestigationEvidencePayload.self,
                        text: row.payload
                    )
                )
                guard record.reportID == reportID else {
                    throw InvestigationPersistenceError.invalidStoredRecord
                }
                records.append(record)
            } catch {
                corrupt.append(row.evidenceID)
            }
        }
        return StorePage(records: records, corruptRecordIDs: corrupt)
    }

    public func investigationBudgetEvents(
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        limit: Int,
        offset: Int
    ) throws -> StorePage<InvestigationStoredBudgetEvent> {
        try validatePage(limit: limit, offset: offset)
        let rows = try connection.query(
            """
            SELECT run_id, event_id, ordinal, event_kind, payload
            FROM investigation_budget_events
            WHERE investigation_id = ? AND run_id = ?
            ORDER BY ordinal ASC, event_id ASC
            LIMIT ? OFFSET ?
            """,
            bindings: [
                .text(investigationID.rawValue),
                .text(runID.rawValue),
                .integer(Int64(limit)),
                .integer(Int64(offset)),
            ],
            operation: "investigation.budget.page"
        ) { statement in
            (
                runID: columnText(statement, 0),
                eventID: columnText(statement, 1),
                ordinal: sqlite3_column_int64(statement, 2),
                kind: columnText(statement, 3),
                payload: columnText(statement, 4)
            )
        }
        var records: [InvestigationStoredBudgetEvent] = []
        var corrupt: [String] = []
        for row in rows {
            do {
                let record = try InvestigationStoredBudgetEvent(
                    investigationID: investigationID,
                    runID: InvestigationRunID(validating: row.runID),
                    id: InvestigationBudgetEventID(
                        validating: row.eventID
                    ),
                    ordinal: checkedInvestigationOrdinal(row.ordinal),
                    kind: try investigationEnum(
                        InvestigationPersistedBudgetEventKind.self,
                        rawValue: row.kind
                    ),
                    payload: try decodeInvestigationPayload(
                        InvestigationBudgetEventPayload.self,
                        text: row.payload
                    )
                )
                guard record.runID == runID else {
                    throw InvestigationPersistenceError.invalidStoredRecord
                }
                records.append(record)
            } catch {
                corrupt.append(row.eventID)
            }
        }
        return StorePage(records: records, corruptRecordIDs: corrupt)
    }

    public func createInvestigationContinuation(
        _ command: InvestigationContinuationCommand
    ) throws -> InvestigationStoredSession {
        try connection.transaction(operation: "investigation.continuation") {
            let existing = try loadInvestigationRun(
                investigationID: command.investigationID,
                runID: command.newRunID
            )
            if let existing {
                guard existing.parentRunID == command.parentRunID,
                      existing.parentReportID == command.parentReportID,
                      existing.plan.budgetPreset == command.budgetPreset,
                      existing.plan.createdAt == command.planningAt
                else {
                    throw InvestigationPersistenceError.conflictingReplay
                }
            }
            switch try rejoinInvestigationInCurrentTransaction(
                id: command.investigationID,
                currentTime: now()
            ) {
            case .matching:
                break
            case .stale:
                throw InvestigationPersistenceError.sourceStale
            case .corrupt:
                throw InvestigationPersistenceError.sourceCorrupt
            case .expired:
                throw InvestigationPersistenceError.sourceExpired
            case .missing:
                throw InvestigationPersistenceError.sourceMissing
            }
            if existing != nil {
                guard let stored = try loadInvestigation(
                    id: command.investigationID
                ), stored.runID == command.newRunID
                else {
                    throw InvestigationPersistenceError.invalidStoredRecord
                }
                return stored
            }
            let parent = try loadInvestigationRun(
                investigationID: command.investigationID,
                runID: command.parentRunID
            )
            guard let parent,
                  parent.state == .partial,
                  parent.reportID == command.parentReportID,
                  parent.reportKind == .partial,
                  let sessionIdentity = try investigationSourceIdentity(
                      id: command.investigationID
                  ),
                  storeMilliseconds(command.planningAt)
                    < sessionIdentity.expiresAtMilliseconds
            else {
                throw InvestigationPersistenceError.invalidCommand
            }
            let unresolvedIDs = try connection.query(
                """
                SELECT target_id
                FROM investigation_evidence
                WHERE investigation_id = ? AND report_id = ?
                  AND run_id = ? AND evidence_kind = 'unresolved'
                ORDER BY ordinal
                """,
                bindings: [
                    .text(command.investigationID.rawValue),
                    .text(command.parentReportID.rawValue),
                    .text(command.parentRunID.rawValue),
                ],
                operation: "investigation.continuation.unresolved"
            ) {
                columnText($0, 0)
            }
            guard !unresolvedIDs.isEmpty,
                  Set(unresolvedIDs).count == unresolvedIDs.count
            else {
                throw InvestigationPersistenceError.noEligibleTargets
            }
            let unresolvedSet = Set(unresolvedIDs)
            let targets = parent.plan.targets.filter {
                unresolvedSet.contains($0.id.rawValue)
            }
            guard targets.count == unresolvedSet.count else {
                throw InvestigationPersistenceError.invalidStoredRecord
            }
            let limits = InvestigationBudgetLimits.forPreset(
                command.budgetPreset
            )
            let wallClockSeconds =
                limits.wallClockNanoseconds / 1_000_000_000
            let budgetExpiry = command.planningAt.addingTimeInterval(
                TimeInterval(wallClockSeconds)
            )
            let sourceExpiry = Date(
                timeIntervalSince1970:
                    TimeInterval(sessionIdentity.expiresAtMilliseconds)
                        / 1_000
            )
            let plan = try InvestigationPlan(
                id: command.investigationID,
                scanSessionID: parent.plan.scanSessionID,
                scanScopeID: parent.plan.scanScopeID,
                sourceFingerprint: sessionIdentity.sourceFingerprint,
                budgetPreset: command.budgetPreset,
                targets: targets,
                createdAt: command.planningAt,
                expiresAt: min(sourceExpiry, budgetExpiry),
                requestedCoveragePermille:
                    InvestigationPlan.policyRequestedCoveragePermille,
                remainingUnknownByteThreshold:
                    InvestigationPlan.policyRemainingUnknownByteThreshold,
                requiredCapabilities: InvestigationCapability.required
            )
            let runCount = try connection.query(
                """
                SELECT run_count FROM investigation_sessions WHERE id = ?
                """,
                bindings: [.text(command.investigationID.rawValue)],
                operation: "investigation.continuation.runCount"
            ) {
                sqlite3_column_int64($0, 0)
            }
            guard let currentRunCount = runCount.first,
                  runCount.count == 1,
                  (1..<16).contains(currentRunCount)
            else {
                throw InvestigationPersistenceError.quotaExceeded
            }
            let planJSON = try boundedInvestigationPlanJSON(plan)
            let payload = InvestigationRunStoragePayload(
                investigationID: command.investigationID,
                runID: command.newRunID
            )
            let createdAt = storeMilliseconds(command.planningAt)
            try connection.execute(
                """
                INSERT INTO investigation_runs (
                    investigation_id, run_id, run_ordinal,
                    target_set_fingerprint, plan_fingerprint, plan_json,
                    budget_preset, plan_created_at_ms, plan_expires_at_ms,
                    target_count, parent_run_id, parent_report_id,
                    state, stage, terminal_cause, terminal_report_id,
                    budget_event_count, budget_payload_byte_count,
                    created_at_ms, updated_at_ms, terminal_at_ms, payload
                ) VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                    'planned', 'prioritize', NULL, NULL, 0, 0,
                    ?, ?, NULL, ?
                )
                """,
                bindings: [
                    .text(command.investigationID.rawValue),
                    .text(command.newRunID.rawValue),
                    .integer(currentRunCount),
                    .blob(plan.targetSetFingerprint.bytes),
                    .blob(plan.fingerprint.bytes),
                    .text(planJSON),
                    .text(command.budgetPreset.rawValue),
                    .integer(storeMilliseconds(plan.createdAt)),
                    .integer(storeMilliseconds(plan.expiresAt)),
                    .integer(Int64(targets.count)),
                    .text(command.parentRunID.rawValue),
                    .text(command.parentReportID.rawValue),
                    .integer(createdAt),
                    .integer(createdAt),
                    .text(try encodeInvestigationPayload(payload)),
                ],
                operation: "investigation.continuation.run"
            )
            for (ordinal, target) in targets.enumerated() {
                try connection.execute(
                    """
                    INSERT INTO investigation_run_targets (
                        investigation_id, run_id, ordinal, target_id
                    ) VALUES (?, ?, ?, ?)
                    """,
                    bindings: [
                        .text(command.investigationID.rawValue),
                        .text(command.newRunID.rawValue),
                        .integer(Int64(ordinal)),
                        .text(target.id.rawValue),
                    ],
                    operation: "investigation.continuation.target"
                )
            }
            try connection.execute(
                """
                UPDATE investigation_sessions
                SET state = 'planned', stage = 'prioritize',
                    run_count = ?, updated_at_ms = ?
                WHERE id = ? AND state IN ('partial', 'paused')
                  AND run_count = ?
                """,
                bindings: [
                    .integer(currentRunCount + 1),
                    .integer(createdAt),
                    .text(command.investigationID.rawValue),
                    .integer(currentRunCount),
                ],
                operation: "investigation.continuation.session"
            )
            let foreignKeyViolations = try connection.query(
                "PRAGMA foreign_key_check",
                operation: "investigation.continuation.foreignKeys"
            ) { _ in true }
            guard foreignKeyViolations.isEmpty,
                  let stored = try loadInvestigation(
                      id: command.investigationID
                  ), stored.runID == command.newRunID
            else {
                throw InvestigationPersistenceError.invalidStoredRecord
            }
            return stored
        }
    }

    public func investigationRecoveryCandidates(
        now: Date,
        limit: Int,
        offset: Int
    ) throws -> StorePage<InvestigationRecoveryCandidate> {
        try validatePage(limit: limit, offset: offset)
        let rows = try connection.query(
            """
            SELECT run.investigation_id, run.run_id, run.state, run.stage,
                   run.terminal_cause, run.plan_json, run.plan_fingerprint,
                   run.target_set_fingerprint, run.updated_at_ms,
                   session.expires_at_ms
            FROM investigation_runs run
            JOIN investigation_sessions session
              ON session.id = run.investigation_id
            WHERE run.state NOT IN ('completed', 'partial', 'blocked', 'failed')
              AND session.expires_at_ms > ?
            ORDER BY run.updated_at_ms ASC, run.investigation_id ASC,
                     run.run_ordinal ASC
            LIMIT ? OFFSET ?
            """,
            bindings: [
                .integer(storeMilliseconds(now)),
                .integer(Int64(limit)),
                .integer(Int64(offset)),
            ],
            operation: "investigation.recovery.page"
        ) { statement in
            (
                investigationID: columnText(statement, 0),
                runID: columnText(statement, 1),
                state: columnText(statement, 2),
                stage: columnText(statement, 3),
                cause: sqlite3_column_type(statement, 4) == SQLITE_NULL
                    ? nil : columnText(statement, 4),
                planJSON: columnText(statement, 5),
                planFingerprint: columnBlob(statement, 6),
                targetSetFingerprint: columnBlob(statement, 7),
                updatedAt: sqlite3_column_int64(statement, 8),
                expiresAt: sqlite3_column_int64(statement, 9)
            )
        }
        var records: [InvestigationRecoveryCandidate] = []
        var corrupt: [String] = []
        for row in rows {
            let recordID = "\(row.investigationID):\(row.runID)"
            do {
                let plan = try decodeInvestigationPayload(
                    InvestigationPlan.self,
                    text: row.planJSON
                )
                guard plan.fingerprint.bytes == row.planFingerprint,
                      plan.targetSetFingerprint.bytes
                        == row.targetSetFingerprint
                else {
                    throw InvestigationPersistenceError.invalidStoredRecord
                }
                records.append(
                    try InvestigationRecoveryCandidate(
                        investigationID: InvestigationID(
                            validating: row.investigationID
                        ),
                        runID: InvestigationRunID(validating: row.runID),
                        state: investigationEnum(
                            InvestigationRunState.self,
                            rawValue: row.state
                        ),
                        stage: investigationEnum(
                            InvestigationStage.self,
                            rawValue: row.stage
                        ),
                        terminalCause: try row.cause.map {
                            try investigationEnum(
                                InvestigationTerminalCause.self,
                                rawValue: $0
                            )
                        },
                        plan: plan,
                        updatedAt: Date(
                            timeIntervalSince1970:
                                TimeInterval(row.updatedAt) / 1_000
                        ),
                        expiresAt: Date(
                            timeIntervalSince1970:
                                TimeInterval(row.expiresAt) / 1_000
                        )
                    )
                )
            } catch {
                corrupt.append(recordID)
            }
        }
        return StorePage(records: records, corruptRecordIDs: corrupt)
    }

    public func deleteInvestigation(
        id: InvestigationID
    ) throws -> Bool {
        try connection.transaction(operation: "investigation.delete") {
            let exists = try connection.query(
                "SELECT 1 FROM investigation_sessions WHERE id = ?",
                bindings: [.text(id.rawValue)],
                operation: "investigation.delete.exists"
            ) { _ in true }.first == true
            guard exists else {
                return false
            }
            try connection.execute(
                "DELETE FROM investigation_sessions WHERE id = ?",
                bindings: [.text(id.rawValue)],
                operation: "investigation.delete.session"
            )
            let foreignKeyViolations = try connection.query(
                "PRAGMA foreign_key_check",
                operation: "investigation.delete.foreignKeys"
            ) { _ in true }
            guard foreignKeyViolations.isEmpty else {
                throw InvestigationPersistenceError.invalidStoredRecord
            }
            return true
        }
    }

#if DEBUG
    public func diagnosticDatabaseSHA256() throws -> String {
        SHA256.hash(data: try connection.serializedDatabase()).map {
            String(format: "%02x", $0)
        }.joined()
    }
#endif

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

    public func beginScanSession(_ session: ScanSession) throws {
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
            """,
            bindings: [
                .text(session.id.rawValue),
                .integer(storeMilliseconds(session.startedAt)),
                .integer(storeMilliseconds(session.finishedAt)),
                .integer(expiresAt),
                .text(payload),
            ],
            operation: "scanSession.begin"
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

    public func scanHistory(
        limit: Int,
        offset: Int
    ) throws -> ScanHistoryPage {
        let sessions = try scanSessions(limit: limit, offset: offset)
        guard !sessions.records.isEmpty else {
            return ScanHistoryPage(
                sessions: [],
                ledgersBySessionID: [:],
                corruptSessionIDs: sessions.corruptRecordIDs,
                corruptLedgerSessionIDs: []
            )
        }
        let sessionIDs = sessions.records.map(\.id)
        let placeholders = Array(
            repeating: "?",
            count: sessionIDs.count
        ).joined(separator: ", ")
        let rows = try connection.query(
            """
            SELECT id, payload, session_id
            FROM space_accounting
            WHERE session_id IN (\(placeholders))
            ORDER BY session_id ASC
            """,
            bindings: sessionIDs.map {
                .text($0.rawValue)
            },
            operation: "history.ledgers"
        ) { statement -> StoreDecodedRow<SpaceLedger> in
            let id = columnText(statement, 0)
            let payload = columnText(statement, 1)
            let parentID = columnText(statement, 2)
            do {
                let ledger = try DomainJSON.decode(
                    SpaceLedger.self,
                    from: Data(payload.utf8)
                )
                guard id == parentID,
                      ledger.sessionID.rawValue == id,
                      sessionIDs.contains(ledger.sessionID)
                else {
                    throw EvidenceStoreError.recordIdentityMismatch
                }
                return .record(ledger)
            } catch {
                return .corrupt(parentID)
            }
        }
        var ledgers: [ScanSessionID: SpaceLedger] = [:]
        var corruptLedgerIDs: [String] = []
        for row in rows {
            switch row {
            case let .record(ledger):
                ledgers[ledger.sessionID] = ledger
            case let .corrupt(id):
                corruptLedgerIDs.append(id)
            }
        }
        return ScanHistoryPage(
            sessions: sessions.records,
            ledgersBySessionID: ledgers,
            corruptSessionIDs: sessions.corruptRecordIDs.sorted(),
            corruptLedgerSessionIDs: Array(Set(corruptLedgerIDs)).sorted()
        )
    }

    public func quickScanSummary(
        sessionID: ScanSessionID
    ) throws -> QuickScanStoreSummary {
        let persistedSnapshotCount = try connection.query(
            """
            SELECT COUNT(*)
            FROM path_snapshots
            WHERE session_id = ?
            """,
            bindings: [.text(sessionID.rawValue)],
            operation: "summary.snapshots"
        ) {
            sqlite3_column_int64($0, 0)
        }.first
        let classificationCount = try connection.query(
            """
            SELECT COUNT(*)
            FROM classifications c
            JOIN path_snapshots s ON s.id = c.snapshot_id
            WHERE s.session_id = ?
            """,
            bindings: [.text(sessionID.rawValue)],
            operation: "summary.classifications"
        ) {
            sqlite3_column_int64($0, 0)
        }.first
        let evidenceCount = try connection.query(
            """
            SELECT COUNT(*)
            FROM evidence e
            JOIN path_snapshots s ON s.id = e.snapshot_id
            WHERE s.session_id = ?
            """,
            bindings: [.text(sessionID.rawValue)],
            operation: "summary.evidence"
        ) {
            sqlite3_column_int64($0, 0)
        }.first
        let dispositionRows = try connection.query(
            """
            SELECT c.disposition, COUNT(*)
            FROM classifications c
            JOIN path_snapshots s ON s.id = c.snapshot_id
            WHERE s.session_id = ?
            GROUP BY c.disposition
            """,
            bindings: [.text(sessionID.rawValue)],
            operation: "summary.dispositions"
        ) { statement in
            (
                columnText(statement, 0),
                sqlite3_column_int64(statement, 1)
            )
        }
        var dispositionCounts = Dictionary(
            uniqueKeysWithValues: ReclaimDisposition.allCases.map {
                ($0, 0)
            }
        )
        for (rawDisposition, count) in dispositionRows {
            guard let disposition = ReclaimDisposition(
                rawValue: rawDisposition
            ), let count = Int(exactly: count), count >= 0 else {
                throw EvidenceStoreError.schemaMismatch
            }
            dispositionCounts[disposition] = count
        }
        guard let rawSnapshotCount = persistedSnapshotCount,
              let rawClassificationCount = classificationCount,
              let rawEvidenceCount = evidenceCount,
              let snapshotCount = Int(exactly: rawSnapshotCount),
              let classificationCount = Int(exactly: rawClassificationCount),
              let evidenceCount = Int(exactly: rawEvidenceCount)
        else {
            throw EvidenceStoreError.schemaMismatch
        }
        return try QuickScanStoreSummary(
            snapshotCount: try scanSession(id: sessionID)?
                .aggregate?.entries.total ?? snapshotCount,
            retainedSnapshotCount: snapshotCount,
            classificationCount: classificationCount,
            evidenceCount: evidenceCount,
            dispositionCounts: QuickScanDispositionCounts(
                readyToReclaim:
                    dispositionCounts[.readyToReclaim, default: 0],
                reviewRecommended:
                    dispositionCounts[.reviewRecommended, default: 0],
                protected: dispositionCounts[.protected, default: 0],
                unknown: dispositionCounts[.unknown, default: 0]
            )
        )
    }

    public func savePathSnapshots(_ snapshots: [PathSnapshot]) throws {
        try Task.checkCancellation()
        let rows = try snapshots.map { snapshot in
            [
                SQLiteValue.text(snapshot.id.rawValue),
                .text(snapshot.sessionID.rawValue),
                .text(snapshot.relativePath),
                .integer(storeMilliseconds(snapshot.observedAt)),
                .text(try encodeStorePayload(snapshot)),
            ]
        }
        try connection.transaction(operation: "snapshot.batch") {
            try connection.executeBatch(
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
                bindings: rows,
                operation: "snapshot.save"
            )
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

    func pathSnapshots(
        sessionID: ScanSessionID,
        after cursor: PathSnapshotCursor?,
        limit: Int
    ) throws -> PathSnapshotCursorPage {
        guard limit > 0,
              limit <= ScanRequest.maximumPersistenceBatchSize
        else {
            throw EvidenceStoreError.invalidPage
        }
        let cursorClause = cursor == nil
            ? ""
            : """
              AND (
                relative_path > ?
                OR (relative_path = ? AND id > ?)
              )
              """
        var bindings: [SQLiteValue] = [.text(sessionID.rawValue)]
        if let cursor {
            bindings.append(.text(cursor.relativePath))
            bindings.append(.text(cursor.relativePath))
            bindings.append(.text(cursor.id))
        }
        bindings.append(.integer(Int64(limit)))
        let rows = try connection.query(
            """
            SELECT id, payload, session_id, relative_path, observed_at_ms
            FROM path_snapshots
            WHERE session_id = ?
            \(cursorClause)
            ORDER BY relative_path ASC, id ASC
            LIMIT ?
            """,
            bindings: bindings,
            operation: "snapshot.cursorPage"
        ) { statement -> (
            decoded: StoreDecodedRow<PathSnapshot>,
            cursor: PathSnapshotCursor
        ) in
            let id = columnText(statement, 0)
            let payload = columnText(statement, 1)
            let parentID = columnText(statement, 2)
            let relativePath = columnText(statement, 3)
            let observedAt = sqlite3_column_int64(statement, 4)
            let decoded: StoreDecodedRow<PathSnapshot>
            do {
                let snapshot = try DomainJSON.decode(
                    PathSnapshot.self,
                    from: Data(payload.utf8)
                )
                guard snapshot.id.rawValue == id,
                      snapshot.sessionID.rawValue == parentID,
                      snapshot.relativePath == relativePath,
                      storeMilliseconds(snapshot.observedAt) == observedAt
                else {
                    throw EvidenceStoreError.recordIdentityMismatch
                }
                decoded = .record(snapshot)
            } catch {
                decoded = .corrupt(id)
            }
            return (
                decoded,
                PathSnapshotCursor(relativePath: relativePath, id: id)
            )
        }
        var records: [PathSnapshot] = []
        var corrupt: [String] = []
        for row in rows {
            switch row.decoded {
            case let .record(record):
                records.append(record)
            case let .corrupt(id):
                corrupt.append(id)
            }
        }
        return PathSnapshotCursorPage(
            page: StorePage(
                records: records,
                corruptRecordIDs: corrupt
            ),
            nextCursor: rows.last?.cursor,
            rowCount: rows.count
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

    func cleanupPlanningPage(
        sessionID: ScanSessionID,
        after cursor: CleanupPlanningCursor?,
        limit: Int
    ) throws -> CleanupPlanningPage {
        try validatePage(limit: limit, offset: 0)
        let cursorClause = cursor == nil
            ? ""
            : """
              AND (
                s.relative_path > ?
                OR (
                    s.relative_path = ?
                    AND s.id > ?
                )
                OR (
                    s.relative_path = ?
                    AND s.id = ?
                    AND c.id > ?
                )
              )
              """
        var bindings: [SQLiteValue] = [.text(sessionID.rawValue)]
        if let cursor {
            bindings.append(.text(cursor.relativePath))
            bindings.append(.text(cursor.relativePath))
            bindings.append(.text(cursor.snapshotID))
            bindings.append(.text(cursor.relativePath))
            bindings.append(.text(cursor.snapshotID))
            bindings.append(.text(cursor.classificationID))
        }
        bindings.append(.integer(Int64(limit)))
        let rows = try connection.query(
            """
            SELECT s.id, s.payload, s.session_id, s.relative_path,
                   s.observed_at_ms,
                   c.id, c.payload, c.snapshot_id, c.disposition,
                   c.classified_at_ms
            FROM classifications c
            JOIN path_snapshots s ON s.id = c.snapshot_id
            WHERE s.session_id = ?
            \(cursorClause)
            ORDER BY s.relative_path ASC, s.id ASC, c.id ASC
            LIMIT ?
            """,
            bindings: bindings,
            operation: "cleanupPlanning.page"
        ) { statement -> (
            record: CleanupPlanningRecord?,
            corrupt: [String],
            cursor: CleanupPlanningCursor
        ) in
            let snapshotID = columnText(statement, 0)
            let relativePath = columnText(statement, 3)
            let classificationID = columnText(statement, 5)
            let rowCursor = CleanupPlanningCursor(
                relativePath: relativePath,
                snapshotID: snapshotID,
                classificationID: classificationID
            )
            do {
                let snapshot = try DomainJSON.decode(
                    PathSnapshot.self,
                    from: Data(columnText(statement, 1).utf8)
                )
                let classification = try DomainJSON.decode(
                    Classification.self,
                    from: Data(columnText(statement, 6).utf8)
                )
                guard snapshot.id.rawValue == snapshotID,
                      snapshot.sessionID.rawValue
                        == columnText(statement, 2),
                      snapshot.sessionID == sessionID,
                      snapshot.relativePath == relativePath,
                      storeMilliseconds(snapshot.observedAt)
                        == sqlite3_column_int64(statement, 4),
                      classification.id.rawValue == classificationID,
                      classification.snapshotID == snapshot.id,
                      classification.snapshotID.rawValue
                        == columnText(statement, 7),
                      classification.disposition.rawValue
                        == columnText(statement, 8),
                      storeMilliseconds(classification.classifiedAt)
                        == sqlite3_column_int64(statement, 9)
                else {
                    throw EvidenceStoreError.recordIdentityMismatch
                }
                return (
                    CleanupPlanningRecord(
                        snapshot: snapshot,
                        classification: classification
                    ),
                    [],
                    rowCursor
                )
            } catch {
                return (
                    nil,
                    [
                        "snapshot:\(snapshotID)",
                        "classification:\(classificationID)",
                    ],
                    rowCursor
                )
            }
        }
        return CleanupPlanningPage(
            records: rows.compactMap(\.record),
            corruptRecordIDs: rows.flatMap(\.corrupt),
            nextCursor: rows.last?.cursor,
            rowCount: rows.count
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

    public func saveSpaceLedger(_ ledger: SpaceLedger) throws {
        try saveSingleton(
            table: "space_accounting",
            id: ledger.sessionID.rawValue,
            parentColumn: "session_id",
            parentID: ledger.sessionID.rawValue,
            payload: DomainJSON.encode(ledger),
            payloadLimit: maximumSpaceLedgerPayloadBytes,
            operation: "spaceLedger.save"
        )
    }

    public func saveVolumeBaseline(_ baseline: VolumeBaseline) throws {
        try connection.execute(
            """
            INSERT INTO volume_baselines
            (session_id, scope_id, sampled_at_ms, payload)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(session_id, scope_id) DO UPDATE SET
                sampled_at_ms=excluded.sampled_at_ms,
                payload=excluded.payload
            """,
            bindings: [
                .text(baseline.sessionID.rawValue),
                .text(baseline.scopeID.rawValue),
                .integer(storeMilliseconds(baseline.source.sampledAt)),
                .text(try encodeStorePayload(baseline)),
            ],
            operation: "volumeBaseline.save"
        )
    }

    public func volumeBaseline(
        sessionID: ScanSessionID,
        scopeID: ScanScopeID
    ) throws -> VolumeBaseline? {
        let records = try connection.query(
            """
            SELECT payload, session_id, scope_id, sampled_at_ms
            FROM volume_baselines
            WHERE scope_id = ? AND session_id = ?
            """,
            bindings: [
                .text(scopeID.rawValue),
                .text(sessionID.rawValue),
            ],
            operation: "volumeBaseline.load"
        ) { statement -> VolumeBaseline in
            let baseline = try DomainJSON.decode(
                VolumeBaseline.self,
                from: Data(columnText(statement, 0).utf8)
            )
            guard columnText(statement, 1) == baseline.sessionID.rawValue,
                  columnText(statement, 2) == baseline.scopeID.rawValue,
                  sqlite3_column_int64(statement, 3)
                    == storeMilliseconds(baseline.source.sampledAt)
            else {
                throw EvidenceStoreError.recordIdentityMismatch
            }
            return baseline
        }
        return records.first
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

    public func spaceLedger(
        sessionID: ScanSessionID
    ) throws -> SpaceLedger? {
        try decodeOne(
            table: "space_accounting",
            id: sessionID.rawValue,
            type: SpaceLedger.self,
            recordID: \.sessionID.rawValue,
            storageColumns: ", session_id",
            validateStorage: { ledger, statement in
                columnText(statement, 1) == ledger.sessionID.rawValue
            },
            operation: "spaceLedger.load"
        )
    }

    public func saveCleanupPlan(_ plan: CleanupPlan) throws {
        guard plan.compatibility == .current else {
            throw EvidenceStoreError.legacyCleanupRecord
        }
        guard let session = try scanSession(id: plan.scanSessionID),
              let scopeID = plan.scanScopeID,
              session.completedScopes.contains(where: { $0.id == scopeID })
        else {
            throw EvidenceStoreError.recordIdentityMismatch
        }
        try insertImmutableExpiringRecord(
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

    public func cleanupPlans(
        sessionID: ScanSessionID,
        limit: Int,
        offset: Int
    ) throws -> StorePage<CleanupPlan> {
        try validatePage(limit: limit, offset: offset)
        return try decodePage(
            sql: """
            SELECT id, payload, session_id, created_at_ms, expires_at_ms
            FROM cleanup_plans
            WHERE session_id = ?
            ORDER BY created_at_ms DESC, id ASC
            LIMIT ? OFFSET ?
            """,
            bindings: [
                .text(sessionID.rawValue),
                .integer(Int64(limit)),
                .integer(Int64(offset)),
            ],
            type: CleanupPlan.self,
            recordID: \.id.rawValue,
            validateStorage: { plan, statement in
                columnText(statement, 2) == plan.scanSessionID.rawValue
                    && sqlite3_column_int64(statement, 3)
                    == storeMilliseconds(plan.createdAt)
                    && sqlite3_column_int64(statement, 4)
                    == storeMilliseconds(plan.expiresAt)
            },
            operation: "plan.page"
        )
    }

    public func cleanupPolicyRecords(
        plan: CleanupPlan,
        selectedItemIDs: [CleanupPlanItemID]
    ) throws -> [CleanupPolicyStoreRecord] {
        guard plan.compatibility == .current,
              !selectedItemIDs.isEmpty,
              selectedItemIDs.count <= ReviewSelection.maximumItemCount,
              Set(selectedItemIDs).count == selectedItemIDs.count,
              try cleanupPlan(id: plan.id) == plan
        else {
            throw EvidenceStoreError.recordIdentityMismatch
        }
        let selected = Set(selectedItemIDs)
        let orderedItems = plan.items.filter { selected.contains($0.id) }
        guard orderedItems.count == selectedItemIDs.count else {
            throw EvidenceStoreError.recordIdentityMismatch
        }
        return try orderedItems.map { item in
            guard let snapshot = try policySnapshot(id: item.snapshotID),
                  let classification = try policyClassification(
                      id: item.classificationID
                  ),
                  snapshot.sessionID == plan.scanSessionID,
                  snapshot.scopeID == plan.scanScopeID,
                  classification.snapshotID == snapshot.id,
                  item.snapshotID == snapshot.id,
                  item.classificationID == classification.id
            else {
                throw EvidenceStoreError.recordIdentityMismatch
            }
            return CleanupPolicyStoreRecord(
                planItem: item,
                snapshot: snapshot,
                classification: classification,
                evidence: try policyEvidence(snapshotID: snapshot.id)
            )
        }
    }

    public func savePolicyDecision(_ decision: PolicyDecision) throws {
        guard decision.compatibility == .current else {
            throw EvidenceStoreError.legacyCleanupRecord
        }
        guard let plan = try cleanupPlan(id: decision.planID),
              plan.compatibility == .current,
              plan.items.contains(where: { $0.id == decision.itemID }),
              plan.planFingerprint == decision.planFingerprint
        else {
            throw EvidenceStoreError.recordIdentityMismatch
        }
        try insertImmutableSingleton(
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

    public func policyDecisions(
        planID: CleanupPlanID,
        limit: Int,
        offset: Int
    ) throws -> StorePage<PolicyDecision> {
        try validatePage(limit: limit, offset: offset)
        return try decodePage(
            sql: """
            SELECT id, payload, plan_id
            FROM policy_decisions
            WHERE plan_id = ?
            ORDER BY id ASC
            LIMIT ? OFFSET ?
            """,
            bindings: [
                .text(planID.rawValue),
                .integer(Int64(limit)),
                .integer(Int64(offset)),
            ],
            type: PolicyDecision.self,
            recordID: \.id.rawValue,
            validateStorage: { decision, statement in
                columnText(statement, 2) == decision.planID.rawValue
            },
            operation: "decision.page"
        )
    }

    public func saveCleanupRunJournal(
        _ journal: CleanupRunJournal
    ) throws {
        let payload = try encodeStorePayload(journal)
        let maximumLifetime = journal.retentionClass == .evidenceLinked
            ? Self.sevenDaysMilliseconds
            : Self.ninetyDaysMilliseconds
        let createdAt = storeMilliseconds(journal.createdAt)
        let expiresAt = storeMilliseconds(journal.expiresAt)
        guard expiresAt <= addingStoreMilliseconds(
            maximumLifetime,
            to: createdAt
        ) else {
            throw EvidenceStoreError.retentionLimitExceeded
        }
        try connection.transaction(operation: "journal.save") {
            let current = try cleanupRunJournal(id: journal.id)
            if let current {
                guard current.canTransition(to: journal) else {
                    throw EvidenceStoreError.invalidJournalTransition
                }
            }
            let retainedPlan = try cleanupPlan(id: journal.planID)
            if
                retainedPlan == nil,
                let current,
                current.retentionClass == .audit
            {
                guard zip(current.entries, journal.entries).allSatisfy({
                    existing, candidate in
                    existing.state != .prepared
                        || candidate.state == .prepared
                        || candidate.state == .cancelled
                }) else {
                    throw EvidenceStoreError.invalidJournalTransition
                }
            } else {
                guard let plan = retainedPlan,
                      plan.compatibility == .current,
                      journal.entries.count <= plan.items.count
                else {
                    throw EvidenceStoreError.invalidJournalTransition
                }
                let planItemsByID = Dictionary(
                    uniqueKeysWithValues: plan.items.enumerated().map {
                        ($0.element.id, (index: $0.offset, item: $0.element))
                }
                )
                var previousPlanIndex = -1
                for entry in journal.entries {
                    guard let indexedItem = planItemsByID[entry.planItemID],
                          indexedItem.index > previousPlanIndex
                    else {
                        throw EvidenceStoreError.invalidJournalTransition
                    }
                    previousPlanIndex = indexedItem.index
                    let item = indexedItem.item
                    let permitsDeniedDecision =
                        entry.state == .outcomeRecorded
                            && entry.outcome?.result == .failed
                            && entry.outcome?.recovery == .notStarted
                    guard entry.planItemID == item.id,
                          entry.action == item.proposedAction,
                          entry.expectedIdentity == item.expectedIdentity,
                          let decision = try policyDecision(
                              id: entry.policyDecisionID
                          ),
                          decision.compatibility == .current,
                          decision.planID == plan.id,
                          decision.itemID == item.id,
                          decision.outcome == .allowed
                            || (permitsDeniedDecision
                                && decision.outcome == .denied),
                          decision.disposition == entry.policyDisposition,
                          decision.reasonKeys == entry.policyReasonKeys,
                          decision.selectionGeneration
                            == journal.selectionGeneration
                    else {
                        throw EvidenceStoreError.invalidJournalTransition
                    }
                }
            }
            if current == nil {
                guard journal.stage == .prepared,
                      journal.selectionFingerprint.rawValue
                        .hasPrefix("selection.")
                    else {
                        throw EvidenceStoreError.invalidJournalTransition
                    }
            }
            try connection.execute(
                """
                INSERT INTO cleanup_run_journals
                (id, plan_id, stage, retention_class, updated_at_ms, expires_at_ms, payload)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    plan_id=excluded.plan_id,
                    stage=excluded.stage,
                    retention_class=excluded.retention_class,
                    updated_at_ms=excluded.updated_at_ms,
                    expires_at_ms=excluded.expires_at_ms,
                    payload=excluded.payload
                """,
                bindings: [
                    .text(journal.id.rawValue),
                    .text(journal.planID.rawValue),
                    .text(journal.stage.rawValue),
                    .text(journal.retentionClass.rawValue),
                    .integer(storeMilliseconds(journal.updatedAt)),
                    .integer(expiresAt),
                    .text(payload),
                ],
                operation: "journal.save.record"
            )
        }
    }

    public func cleanupRunJournal(
        id: CleanupRunID
    ) throws -> CleanupRunJournal? {
        try decodeOne(
            table: "cleanup_run_journals",
            id: id.rawValue,
            type: CleanupRunJournal.self,
            recordID: \.id.rawValue,
            storageColumns:
                ", plan_id, stage, retention_class, updated_at_ms, expires_at_ms",
            validateStorage: { journal, statement in
                columnText(statement, 1) == journal.planID.rawValue
                    && columnText(statement, 2) == journal.stage.rawValue
                    && columnText(statement, 3)
                    == journal.retentionClass.rawValue
                    && sqlite3_column_int64(statement, 4)
                    == storeMilliseconds(journal.updatedAt)
                    && sqlite3_column_int64(statement, 5)
                    == storeMilliseconds(journal.expiresAt)
            },
            operation: "journal.load"
        )
    }

    public func cleanupRunJournals(
        limit: Int,
        offset: Int
    ) throws -> StorePage<CleanupRunJournal> {
        try validatePage(limit: limit, offset: offset)
        return try decodePage(
            sql: """
            SELECT id, payload, plan_id, stage, retention_class,
                   updated_at_ms, expires_at_ms
            FROM cleanup_run_journals
            ORDER BY updated_at_ms DESC, id ASC
            LIMIT ? OFFSET ?
            """,
            bindings: [.integer(Int64(limit)), .integer(Int64(offset))],
            type: CleanupRunJournal.self,
            recordID: \.id.rawValue,
            validateStorage: { journal, statement in
                columnText(statement, 2) == journal.planID.rawValue
                    && columnText(statement, 3) == journal.stage.rawValue
                    && columnText(statement, 4)
                    == journal.retentionClass.rawValue
                    && sqlite3_column_int64(statement, 5)
                    == storeMilliseconds(journal.updatedAt)
                    && sqlite3_column_int64(statement, 6)
                    == storeMilliseconds(journal.expiresAt)
            },
            operation: "journal.page"
        )
    }

    public func saveCleanupManifest(_ manifest: CleanupManifest) throws {
        guard manifest.compatibility == .current else {
            throw EvidenceStoreError.legacyCleanupRecord
        }
        let createdAt = storeMilliseconds(manifest.createdAt)
        let expiresAt = storeMilliseconds(manifest.expiresAt)
        guard expiresAt <= addingStoreMilliseconds(
            Self.ninetyDaysMilliseconds,
            to: createdAt
        ) else {
            throw EvidenceStoreError.retentionLimitExceeded
        }
        let payload = try encodeStorePayload(manifest)
        try connection.transaction(operation: "manifest.insert") {
            let existing = try connection.query(
                """
                SELECT plan_id, created_at_ms, expires_at_ms, payload
                FROM cleanup_manifests
                WHERE id = ?
                """,
                bindings: [.text(manifest.id.rawValue)],
                operation: "manifest.identity"
            ) { statement in
                (
                    planID: columnText(statement, 0),
                    createdAt: sqlite3_column_int64(statement, 1),
                    expiresAt: sqlite3_column_int64(statement, 2),
                    payload: columnText(statement, 3)
                )
            }.first
            if let existing {
                guard existing.planID == manifest.planID.rawValue,
                      existing.createdAt == createdAt,
                      existing.expiresAt == expiresAt,
                      existing.payload == payload
                else {
                    throw EvidenceStoreError.immutableRecordConflict
                }
                return
            }
            try connection.execute(
                """
                INSERT INTO cleanup_manifests
                (id, plan_id, created_at_ms, expires_at_ms, payload)
                VALUES (?, ?, ?, ?, ?)
                """,
                bindings: [
                    .text(manifest.id.rawValue),
                    .text(manifest.planID.rawValue),
                    .integer(createdAt),
                    .integer(expiresAt),
                    .text(payload),
                ],
                operation: "manifest.insert.record"
            )
        }
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

    public func cleanupManifests(
        limit: Int,
        offset: Int
    ) throws -> StorePage<CleanupManifest> {
        try validatePage(limit: limit, offset: offset)
        return try decodePage(
            sql: """
            SELECT id, payload, plan_id, created_at_ms, expires_at_ms
            FROM cleanup_manifests
            ORDER BY created_at_ms DESC, id ASC
            LIMIT ? OFFSET ?
            """,
            bindings: [.integer(Int64(limit)), .integer(Int64(offset))],
            type: CleanupManifest.self,
            recordID: \.id.rawValue,
            validateStorage: { manifest, statement in
                columnText(statement, 2) == manifest.planID.rawValue
                    && sqlite3_column_int64(statement, 3)
                    == storeMilliseconds(manifest.createdAt)
                    && sqlite3_column_int64(statement, 4)
                    == storeMilliseconds(manifest.expiresAt)
            },
            operation: "manifest.page"
        )
    }

    public func cleanupManifestHistory(
        limit: Int,
        offset: Int,
        now: Date
    ) throws -> CleanupManifestHistoryPage {
        let page = try cleanupManifests(limit: limit, offset: offset)
        let records = try page.records.map { manifest in
            let plan = try cleanupHistoryPlan(id: manifest.planID)
            let retainedPlan = plan.flatMap {
                Self.planEnrichment(
                    $0,
                    matches: manifest,
                    now: now
                ) ? $0 : nil
            }
            return CleanupManifestHistoryRecord(
                manifest: manifest,
                linkedPlan: retainedPlan,
                evidenceAvailability: retainedPlan == nil
                    ? .expired
                    : .retained
            )
        }
        return CleanupManifestHistoryPage(
            records: records,
            corruptManifestIDs: page.corruptRecordIDs
        )
    }

    public func deleteCleanupManifest(
        id: CleanupManifestID
    ) throws -> Bool {
        try connection.transaction(operation: "manifest.delete") {
            guard let manifest = try cleanupManifest(id: id) else {
                return false
            }
            let journals = try connection.query(
                """
                SELECT id, payload, plan_id, stage, retention_class,
                       updated_at_ms, expires_at_ms
                FROM cleanup_run_journals
                WHERE plan_id = ?
                ORDER BY id ASC
                """,
                bindings: [.text(manifest.planID.rawValue)],
                operation: "manifest.delete.journals"
            ) { statement -> CleanupRunJournal in
                let storedID = columnText(statement, 0)
                do {
                    let journal = try DomainJSON.decode(
                        CleanupRunJournal.self,
                        from: Data(columnText(statement, 1).utf8)
                    )
                    guard journal.id.rawValue == storedID,
                          columnText(statement, 2)
                            == journal.planID.rawValue,
                          columnText(statement, 3)
                            == journal.stage.rawValue,
                          columnText(statement, 4)
                            == journal.retentionClass.rawValue,
                          sqlite3_column_int64(statement, 5)
                            == storeMilliseconds(journal.updatedAt),
                          sqlite3_column_int64(statement, 6)
                            == storeMilliseconds(journal.expiresAt)
                    else {
                        throw EvidenceStoreError.recordIdentityMismatch
                    }
                    return journal
                } catch {
                    throw EvidenceStoreError.recordIdentityMismatch
                }
            }
            for journal in journals where journal.manifestID == manifest.id {
                try connection.execute(
                    "DELETE FROM cleanup_run_journals WHERE id = ?",
                    bindings: [.text(journal.id.rawValue)],
                    operation: "manifest.delete.journal"
                )
            }
            try connection.execute(
                "DELETE FROM cleanup_manifests WHERE id = ?",
                bindings: [.text(manifest.id.rawValue)],
                operation: "manifest.delete.record"
            )
            return true
        }
    }

    public func deleteScanSession(id: ScanSessionID) throws {
        try connection.transaction(operation: "scanSession.delete") {
            try connection.execute(
                """
                DELETE FROM cleanup_run_journals
                WHERE retention_class = 'evidenceLinked'
                  AND plan_id IN (
                    SELECT id FROM cleanup_plans WHERE session_id = ?
                  )
                """,
                bindings: [.text(id.rawValue)],
                operation: "scanSession.deletePreparedJournals"
            )
            try connection.execute(
                "DELETE FROM scan_sessions WHERE id = ?",
                bindings: [.text(id.rawValue)],
                operation: "scanSession.deleteEvidence"
            )
        }
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
                DELETE FROM investigation_sessions
                WHERE expires_at_ms <= ?
                """,
                bindings: [.integer(nowMilliseconds)],
                operation: "retention.investigations"
            )
            try connection.execute(
                """
                DELETE FROM cleanup_run_journals
                WHERE retention_class = 'evidenceLinked'
                  AND (
                    expires_at_ms <= ?
                    OR updated_at_ms <= ?
                  )
                """,
                bindings: [
                    .integer(nowMilliseconds),
                    .integer(evidenceCutoff),
                ],
                operation: "retention.evidenceLinkedJournals"
            )
            try connection.execute(
                """
                DELETE FROM cleanup_run_journals
                WHERE retention_class = 'audit'
                  AND (
                    expires_at_ms <= ?
                    OR updated_at_ms <= ?
                  )
                """,
                bindings: [
                    .integer(nowMilliseconds),
                    .integer(manifestCutoff),
                ],
                operation: "retention.auditJournals"
            )
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
                DELETE FROM cleanup_run_journals
                WHERE retention_class = 'evidenceLinked'
                  AND NOT EXISTS (
                    SELECT 1 FROM cleanup_plans
                    WHERE cleanup_plans.id = cleanup_run_journals.plan_id
                  )
                """,
                operation: "retention.orphanedEvidenceLinkedJournals"
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
        try connection.transaction(operation: "clear.evidence") {
            try connection.execute(
                """
                DELETE FROM cleanup_run_journals
                WHERE retention_class = 'evidenceLinked'
                """,
                operation: "clear.evidenceLinkedJournals"
            )
            try connection.execute(
                "DELETE FROM scan_sessions",
                operation: "clear.evidenceRecords"
            )
        }
    }

    public func clearManifests() throws {
        try connection.transaction(operation: "clear.manifests") {
            try connection.execute(
                """
                DELETE FROM cleanup_run_journals
                WHERE retention_class = 'audit'
                """,
                operation: "clear.journals"
            )
            try connection.execute(
                "DELETE FROM cleanup_manifests",
                operation: "clear.manifestRecords"
            )
        }
    }

    public func recordCounts() throws -> EvidenceRecordCounts {
        let evidence = try connection.scalarInt(
            "SELECT count(*) FROM scan_sessions",
            operation: "counts.evidence"
        )
        let manifests = try connection.scalarInt(
            "SELECT count(*) FROM cleanup_manifests",
            operation: "counts.manifests"
        )
        guard let evidenceCount = Int(exactly: evidence),
              let manifestCount = Int(exactly: manifests),
              evidenceCount >= 0,
              manifestCount >= 0
        else {
            throw EvidenceStoreError.recordIdentityMismatch
        }
        return EvidenceRecordCounts(
            evidenceSessions: evidenceCount,
            manifests: manifestCount
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

    func _testSchemaObjectNames(type: String) throws -> [String] {
        try connection.query(
            """
            SELECT name
            FROM sqlite_master
            WHERE type = ? AND name NOT LIKE 'sqlite_%'
            ORDER BY name
            """,
            bindings: [.text(type)],
            operation: "test.schemaObjectNames"
        ) {
            columnText($0, 0)
        }
    }

    func _testInvestigationRowCounts(
        id: InvestigationID
    ) throws -> InvestigationStoreRowCounts {
        let tables = [
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
        let counts = try tables.map { table in
            let value = try connection.query(
                """
                SELECT count(*) FROM \(table)
                WHERE \(table == "investigation_sessions"
                    ? "id" : "investigation_id") = ?
                """,
                bindings: [.text(id.rawValue)],
                operation: "test.investigationCount.\(table)"
            ) {
                sqlite3_column_int64($0, 0)
            }.first ?? -1
            guard let count = Int(exactly: value), count >= 0 else {
                throw InvestigationPersistenceError.invalidStoredRecord
            }
            return count
        }
        return InvestigationStoreRowCounts(
            sessions: counts[0],
            sourceRows: counts[1],
            relevanceTokens: counts[2],
            targets: counts[3],
            runs: counts[4],
            runTargets: counts[5],
            reports: counts[6],
            evidence: counts[7],
            degradations: counts[8],
            budgetEvents: counts[9]
        )
    }

    func _testInvestigationRunPlan(
        investigationID: InvestigationID,
        runID: InvestigationRunID
    ) throws -> InvestigationPlan? {
        try loadInvestigationRun(
            investigationID: investigationID,
            runID: runID
        )?.plan
    }

#if DEBUG
    func _testInvestigationAuthorizationProbe(
        _ probe: SQLiteInvestigationAuthorizationProbe
    ) throws {
        try connection.runAuthorizationProbe(probe)
    }
#endif

    func _testReplaceClassificationPayload(
        id: ClassificationID,
        payload: String
    ) throws {
        try connection.execute(
            "UPDATE classifications SET payload = ? WHERE id = ?",
            bindings: [
                .text(payload),
                .text(id.rawValue),
            ],
            operation: "test.replaceClassificationPayload"
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

    func _testInsertMalformedCleanupJournal(
        id: String,
        planID: CleanupPlanID = CleanupPlanID(
            rawValue: "plan-corrupt"
        )!,
        payload: String
    ) throws {
        try connection.execute(
            """
            INSERT INTO cleanup_run_journals
            (id, plan_id, stage, retention_class, updated_at_ms, expires_at_ms, payload)
            VALUES (?, ?, 'prepared', 'evidenceLinked', 0, 1, ?)
            """,
            bindings: [
                .text(id),
                .text(planID.rawValue),
                .text(payload),
            ],
            operation: "test.malformedJournal"
        )
    }

    func _testInsertMalformedCleanupPlan(
        id: String,
        sessionID: ScanSessionID,
        payload: String
    ) throws {
        try connection.execute(
            """
            INSERT INTO cleanup_plans
            (id, session_id, created_at_ms, expires_at_ms, payload)
            VALUES (?, ?, 0, 1, ?)
            """,
            bindings: [
                .text(id),
                .text(sessionID.rawValue),
                .text(payload),
            ],
            operation: "test.malformedPlan"
        )
    }

    func _testInsertMalformedPolicyDecision(
        id: String,
        planID: CleanupPlanID,
        payload: String
    ) throws {
        try connection.execute(
            """
            INSERT INTO policy_decisions
            (id, plan_id, payload)
            VALUES (?, ?, ?)
            """,
            bindings: [
                .text(id),
                .text(planID.rawValue),
                .text(payload),
            ],
            operation: "test.malformedDecision"
        )
    }

    func _testInsertMalformedCleanupManifest(
        id: String,
        planID: CleanupPlanID? = nil,
        createdAt: Date? = nil,
        expiresAt: Date? = nil,
        payload: String
    ) throws {
        let createdAt = createdAt ?? Date(timeIntervalSince1970: 0)
        let expiresAt = expiresAt ?? Date(timeIntervalSince1970: 0.001)
        try connection.execute(
            """
            INSERT INTO cleanup_manifests
            (id, plan_id, created_at_ms, expires_at_ms, payload)
            VALUES (?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(id),
                .text(planID?.rawValue ?? "plan-corrupt"),
                .integer(storeMilliseconds(createdAt)),
                .integer(storeMilliseconds(expiresAt)),
                .text(payload),
            ],
            operation: "test.malformedManifest"
        )
    }

    func _testCorruptSpaceLedger(
        sessionID: ScanSessionID,
        payload: String
    ) throws {
        try connection.execute(
            "UPDATE space_accounting SET payload = ? WHERE session_id = ?",
            bindings: [
                .text(payload),
                .text(sessionID.rawValue),
            ],
            operation: "test.corruptSpaceLedger"
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

    func _testInvestigationSourceQueryPlans(
        scanSessionID: ScanSessionID,
        scanScopeID: ScanScopeID
    ) throws -> [String: String] {
        try connection.investigationSourceQueryPlans(
            scanSessionID: scanSessionID,
            scanScopeID: scanScopeID
        )
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
        try connection.enableDefensiveMode()
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
        if version == 1 {
            let expected = try SQLiteConnection(path: ":memory:")
            try configureConnection(expected)
            try createSchemaV1(expected)
            guard try schemaSignature(connection) == schemaSignature(expected) else {
                throw EvidenceStoreError.schemaMismatch
            }
            return
        }
        if version == 2 {
            let expected = try SQLiteConnection(path: ":memory:")
            try configureConnection(expected)
            try createSchemaV1(expected)
            try createSchemaV2(expected)
            guard try schemaSignature(connection) == schemaSignature(expected) else {
                throw EvidenceStoreError.schemaMismatch
            }
            return
        }
        if version == 3 {
            let expected = try SQLiteConnection(path: ":memory:")
            try configureConnection(expected)
            try createSchemaV1(expected)
            try createSchemaV2(expected)
            try createSchemaV3(expected)
            guard try schemaSignature(connection) == schemaSignature(expected) else {
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
        let originalVersion = Int(try connection.scalarInt(
            "PRAGMA user_version",
            operation: "migration.version"
        ))
        guard originalVersion <= schemaVersion else {
            throw EvidenceStoreError.unsupportedFutureSchema(
                version: originalVersion
            )
        }
        guard originalVersion < schemaVersion else {
            return
        }
        var targetVersion = originalVersion + 1
        do {
            try connection.transaction(operation: "migration.toV4") {
                var version = originalVersion
                if version == 0 {
                    targetVersion = 1
                    try claimRole(connection)
                    if try connection.scalarInt(
                        """
                        SELECT count(*) FROM sqlite_master
                        WHERE type='table' AND name='legacy_scan_sessions'
                        """,
                        operation: "migration.legacyExists"
                    ) > 0 {
                        try createSchemaV1(connection)
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
                        try createSchemaV1(connection)
                    }
                    if testHooks.failMigrationToVersion == 1 {
                        throw EvidenceStoreError.migrationFailed(version: 1)
                    }
                    try connection.execute(
                        "PRAGMA user_version=1",
                        operation: "migration.setVersion1"
                    )
                    version = 1
                }
                if version < 2 {
                    targetVersion = 2
                    try claimRole(connection)
                    try createSchemaV2(connection)
                    if testHooks.failMigrationToVersion == 2 {
                        throw EvidenceStoreError.migrationFailed(version: 2)
                    }
                    try connection.execute(
                        "PRAGMA user_version=2",
                        operation: "migration.setVersion2"
                    )
                    version = 2
                }
                if version < 3 {
                    targetVersion = 3
                    try claimRole(connection)
                    try createSchemaV3(connection)
                    if testHooks.failMigrationToVersion == 3 {
                        throw EvidenceStoreError.migrationFailed(version: 3)
                    }
                    try connection.execute(
                        "PRAGMA user_version=3",
                        operation: "migration.setVersion3"
                    )
                    version = 3
                }
                if version < 4 {
                    targetVersion = 4
                    try claimRole(connection)
                    try createSchemaV4(connection)
                    if testHooks.failMigrationToVersion == 4 {
                        throw EvidenceStoreError.migrationFailed(version: 4)
                    }
                    try connection.execute(
                        "PRAGMA user_version=4",
                        operation: "migration.setVersion4"
                    )
                }
            }
        } catch {
            throw EvidenceStoreError.migrationFailed(version: targetVersion)
        }
    }

    private static func createSchema(
        _ connection: SQLiteConnection
    ) throws {
        try createSchemaV1(connection)
        try createSchemaV2(connection)
        try createSchemaV3(connection)
        try createSchemaV4(connection)
    }

    private static func createSchemaV1(
        _ connection: SQLiteConnection
    ) throws {
        for (operation, sql) in evidenceSchemaV1Statements {
            try connection.execute(sql, operation: operation)
        }
    }

    private static func createSchemaV2(
        _ connection: SQLiteConnection
    ) throws {
        for (operation, sql) in evidenceSchemaV2Statements {
            try connection.execute(sql, operation: operation)
        }
    }

    private static func createSchemaV3(
        _ connection: SQLiteConnection
    ) throws {
        for (operation, sql) in evidenceSchemaV3Statements {
            try connection.execute(sql, operation: operation)
        }
    }

    private static func createSchemaV4(
        _ connection: SQLiteConnection
    ) throws {
        for (operation, sql) in evidenceSchemaV4Statements {
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

    private func validateInvestigationCreateCommand(
        _ command: InvestigationCreateCommand
    ) throws {
        guard command.relevanceTokens.count <= 256,
              Set(command.relevanceTokens).count
                == command.relevanceTokens.count,
              command.planningAt.timeIntervalSince1970.isFinite
        else {
            throw InvestigationPersistenceError.invalidCommand
        }
        var previous: Data?
        for token in command.relevanceTokens {
            let bytes = Data(token.rawValue.utf8)
            if let previous {
                guard previous.count < bytes.count
                    || (
                        previous.count == bytes.count
                        && previous.lexicographicallyPrecedes(bytes)
                    )
                else {
                    throw InvestigationPersistenceError.invalidCommand
                }
            }
            previous = bytes
        }
    }

    private func mapInvestigationSourceError(_ error: Error) -> Error {
        guard let error = error as? InvestigationSourceProjectionError else {
            return error
        }
        switch error {
        case .sourceMissing:
            return InvestigationPersistenceError.sourceMissing
        case .sourceExpired:
            return InvestigationPersistenceError.sourceExpired
        case .secondPassDrift:
            return InvestigationPersistenceError.sourceStale
        case .payloadMismatch,
             .storageMismatch,
             .sourceProjectionTooLarge,
             .nonCanonicalOrder,
             .duplicateSourceRow,
             .membershipMismatch,
             .cursorCountExceeded:
            return InvestigationPersistenceError.sourceCorrupt
        }
    }

    private func mapInvestigationPlanningError(_ error: Error) -> Error {
        guard let error = error as? InvestigationPlanningError else {
            return error
        }
        switch error {
        case let .sourceIneligible(eligibility):
            switch eligibility {
            case .sourceMissing:
                return InvestigationPersistenceError.sourceMissing
            case .sourceExpired:
                return InvestigationPersistenceError.sourceExpired
            case .sourceStale:
                return InvestigationPersistenceError.sourceStale
            case .sourceCorrupt,
                 .terminalStateIneligible,
                 .primaryScopeMissingOrDuplicate,
                 .primaryScopeUnfinished,
                 .permissionOrBoundaryLimited:
                return InvestigationPersistenceError.sourceCorrupt
            case .eligible:
                return InvestigationPersistenceError.invalidCommand
            }
        case .invalidRelevanceToken,
             .candidateReasonMissing,
             .candidateReasonLimitExceeded,
             .duplicateCandidate,
             .integerOverflow:
            return InvestigationPersistenceError.invalidCommand
        }
    }

    private func investigationReplay(
        _ existing: InvestigationStoredSession,
        matches command: InvestigationCreateCommand
    ) throws -> Bool {
        guard existing.id == command.investigationID,
              existing.initialRunID == command.initialRunID,
              existing.plan.scanSessionID == command.scanSessionID,
              existing.plan.scanScopeID == command.scanScopeID,
              existing.plan.budgetPreset == command.budgetPreset,
              existing.plan.createdAt == command.planningAt,
              existing.state == .planned,
              existing.stage == .prioritize
        else {
            return false
        }
        let identity = try investigationSourceIdentity(
            id: command.investigationID
        )
        return identity?.relevanceTokens == command.relevanceTokens
    }

    private func rejoinInvestigationInCurrentTransaction(
        id: InvestigationID,
        currentTime: Date
    ) throws -> InvestigationRejoinResult {
        guard let identity = try investigationSourceIdentity(id: id) else {
            return .missing
        }
        guard storeMilliseconds(currentTime)
                < identity.expiresAtMilliseconds
        else {
            return .expired
        }
        let projection: InvestigationSourceProjection
        do {
            projection = try connection.rejoinInvestigationSource(
                investigationID: id,
                scanSessionID: identity.scanSessionID,
                scanScopeID: identity.scanScopeID,
                relevanceTokens: identity.relevanceTokens,
                planningAt: currentTime
            )
        } catch let error as InvestigationSourceProjectionError {
            switch error {
            case .sourceMissing:
                return .missing
            case .sourceExpired:
                return .expired
            case .secondPassDrift:
                return .stale
            case .payloadMismatch,
                 .storageMismatch,
                 .sourceProjectionTooLarge,
                 .nonCanonicalOrder,
                 .duplicateSourceRow,
                 .membershipMismatch,
                 .cursorCountExceeded:
                return .corrupt
            }
        } catch {
            return .corrupt
        }
        guard projection.summary.scanSessionID == identity.scanSessionID,
              projection.summary.primaryScopeID == identity.scanScopeID,
              projection.summary.sourceFingerprint
                == identity.sourceFingerprint,
              projection.summary.sourceRowCount
                == identity.sourceRowCount,
              projection.summary.exactPayloadBytes
                == identity.sourcePayloadByteCount,
              projection.summary.completeCanonicalBytes
                == identity.sourceCanonicalByteCount,
              projection.summary.relevanceTokens
                == identity.relevanceTokens
        else {
            return .stale
        }
        return .matching
    }

    private func prepareTerminalCommand(
        _ command: InvestigationTerminalCommand
    ) throws -> PreparedInvestigationTerminal {
        guard command.budgetEvents.count <= 4_096,
              command.budgetEvents.enumerated().allSatisfy({
                  $0.offset == $0.element.ordinal
              }),
              Set(command.budgetEvents.map(\.id)).count
                == command.budgetEvents.count
        else {
            throw InvestigationPersistenceError.quotaExceeded
        }
        let budgetEvents = try command.budgetEvents.map {
            PreparedInvestigationPayload(
                input: $0,
                payload: try encodeInvestigationPayload(
                    $0.payload,
                    limit: 16 * 1_024
                )
            )
        }
        let budgetPayloadBytes = try checkedInvestigationPayloadBytes(
            budgetEvents.map(\.payload),
            maximum: 4 * 1_048_576
        )
        guard let report = command.report else {
            return PreparedInvestigationTerminal(
                report: nil,
                budgetEvents: budgetEvents,
                budgetPayloadBytes: budgetPayloadBytes
            )
        }
        guard report.evidence.count <= 512,
              report.degradations.count <= 64,
              Set(report.evidence.map(\.id)).count == report.evidence.count,
              Set(report.degradations.map(\.id)).count
                == report.degradations.count
        else {
            throw InvestigationPersistenceError.quotaExceeded
        }
        let evidence = try report.evidence.map {
            PreparedInvestigationPayload(
                input: $0,
                payload: try encodeInvestigationPayload(
                    $0.payload,
                    limit: 64 * 1_024
                )
            )
        }
        let degradations = try report.degradations.map {
            PreparedInvestigationPayload(
                input: $0,
                payload: try encodeInvestigationPayload(
                    $0.payload,
                    limit: 16 * 1_024
                )
            )
        }
        return PreparedInvestigationTerminal(
            report: PreparedInvestigationReport(
                input: report,
                payload: try encodeInvestigationPayload(
                    report.payload,
                    limit: 1_048_576
                ),
                evidence: evidence,
                degradations: degradations,
                evidencePayloadBytes:
                    try checkedInvestigationPayloadBytes(
                        evidence.map(\.payload),
                        maximum: 8 * 1_048_576
                    ),
                degradationPayloadBytes:
                    try checkedInvestigationPayloadBytes(
                        degradations.map(\.payload),
                        maximum: 512 * 1_024
                    )
            ),
            budgetEvents: budgetEvents,
            budgetPayloadBytes: budgetPayloadBytes
        )
    }

    private func checkedInvestigationPayloadBytes(
        _ payloads: [String],
        maximum: Int64
    ) throws -> Int64 {
        var total: Int64 = 0
        for payload in payloads {
            guard let count = Int64(exactly: payload.utf8.count) else {
                throw InvestigationPersistenceError.quotaExceeded
            }
            let addition = total.addingReportingOverflow(count)
            guard !addition.overflow, addition.partialValue <= maximum else {
                throw InvestigationPersistenceError.quotaExceeded
            }
            total = addition.partialValue
        }
        return total
    }

    private func terminalRunIdentity(
        investigationID: InvestigationID,
        runID: InvestigationRunID
    ) throws -> InvestigationTerminalRunIdentity {
        let rows = try connection.query(
            """
            SELECT run.state, session.state, run.terminal_cause,
                   run.terminal_report_id, run.updated_at_ms,
                   run.terminal_at_ms
            FROM investigation_runs run
            JOIN investigation_sessions session
              ON session.id = run.investigation_id
            WHERE run.investigation_id = ? AND run.run_id = ?
            """,
            bindings: [
                .text(investigationID.rawValue),
                .text(runID.rawValue),
            ],
            operation: "investigation.terminal.identity"
        ) { statement in
            (
                runState: columnText(statement, 0),
                sessionState: columnText(statement, 1),
                terminalCause: sqlite3_column_type(statement, 2)
                    == SQLITE_NULL ? nil : columnText(statement, 2),
                terminalReportID: sqlite3_column_type(statement, 3)
                    == SQLITE_NULL ? nil : columnText(statement, 3),
                updatedAt: sqlite3_column_int64(statement, 4),
                terminalAt: sqlite3_column_type(statement, 5)
                    == SQLITE_NULL
                    ? nil
                    : sqlite3_column_int64(statement, 5)
            )
        }
        guard let row = rows.first,
              rows.count == 1,
              let runState = InvestigationRunState(rawValue: row.runState),
              let sessionState = InvestigationSessionState(
                  rawValue: row.sessionState
              )
        else {
            throw InvestigationPersistenceError.invalidStoredRecord
        }
        return try InvestigationTerminalRunIdentity(
            runState: runState,
            sessionState: sessionState,
            terminalCause: row.terminalCause.map {
                guard let value = InvestigationTerminalCause(rawValue: $0)
                else {
                    throw InvestigationPersistenceError.invalidStoredRecord
                }
                return value
            },
            terminalReportID: row.terminalReportID.map {
                try InvestigationReportID(validating: $0)
            },
            updatedAtMilliseconds: row.updatedAt,
            terminalAtMilliseconds: row.terminalAt
        )
    }

    private func investigationAggregates(
        id: InvestigationID
    ) throws -> InvestigationAggregateCounts {
        let rows = try connection.query(
            """
            SELECT
                (SELECT count(*) FROM investigation_reports
                 WHERE investigation_id = ?),
                (SELECT count(*) FROM investigation_evidence
                 WHERE investigation_id = ?),
                (SELECT COALESCE(sum(length(CAST(payload AS BLOB))), 0)
                 FROM investigation_evidence
                 WHERE investigation_id = ?),
                (SELECT count(*) FROM investigation_report_degradations
                 WHERE investigation_id = ?),
                (SELECT COALESCE(sum(length(CAST(payload AS BLOB))), 0)
                 FROM investigation_report_degradations
                 WHERE investigation_id = ?),
                (SELECT count(*) FROM investigation_budget_events
                 WHERE investigation_id = ?),
                (SELECT COALESCE(sum(length(CAST(payload AS BLOB))), 0)
                 FROM investigation_budget_events
                 WHERE investigation_id = ?)
            """,
            bindings: Array(
                repeating: .text(id.rawValue),
                count: 7
            ),
            operation: "investigation.terminal.aggregates"
        ) {
            InvestigationAggregateCounts(
                reportCount: sqlite3_column_int64($0, 0),
                evidenceCount: sqlite3_column_int64($0, 1),
                evidenceBytes: sqlite3_column_int64($0, 2),
                degradationCount: sqlite3_column_int64($0, 3),
                degradationBytes: sqlite3_column_int64($0, 4),
                budgetCount: sqlite3_column_int64($0, 5),
                budgetBytes: sqlite3_column_int64($0, 6)
            )
        }
        guard let result = rows.first, rows.count == 1 else {
            throw InvestigationPersistenceError.invalidStoredRecord
        }
        return result
    }

    private func verifyInvestigationTerminalCounters(
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        reportID: InvestigationReportID?
    ) throws {
        let aggregates = try investigationAggregates(id: investigationID)
        let sessionRows = try connection.query(
            """
            SELECT report_count, evidence_row_count,
                   evidence_payload_byte_count, degradation_row_count,
                   degradation_payload_byte_count, budget_event_count,
                   budget_payload_byte_count
            FROM investigation_sessions
            WHERE id = ?
            """,
            bindings: [.text(investigationID.rawValue)],
            operation: "investigation.terminal.verifySession"
        ) {
            (
                reportCount: sqlite3_column_int64($0, 0),
                evidenceCount: sqlite3_column_int64($0, 1),
                evidenceBytes: sqlite3_column_int64($0, 2),
                degradationCount: sqlite3_column_int64($0, 3),
                degradationBytes: sqlite3_column_int64($0, 4),
                budgetCount: sqlite3_column_int64($0, 5),
                budgetBytes: sqlite3_column_int64($0, 6)
            )
        }
        let runRows = try connection.query(
            """
            SELECT budget_event_count, budget_payload_byte_count
            FROM investigation_runs
            WHERE investigation_id = ? AND run_id = ?
            """,
            bindings: [
                .text(investigationID.rawValue),
                .text(runID.rawValue),
            ],
            operation: "investigation.terminal.verifyRun"
        ) {
            (
                count: sqlite3_column_int64($0, 0),
                bytes: sqlite3_column_int64($0, 1)
            )
        }
        let directRunBudget = try connection.query(
            """
            SELECT count(*),
                   COALESCE(sum(length(CAST(payload AS BLOB))), 0)
            FROM investigation_budget_events
            WHERE investigation_id = ? AND run_id = ?
            """,
            bindings: [
                .text(investigationID.rawValue),
                .text(runID.rawValue),
            ],
            operation: "investigation.terminal.verifyRunBudget"
        ) {
            (
                count: sqlite3_column_int64($0, 0),
                bytes: sqlite3_column_int64($0, 1)
            )
        }
        guard let session = sessionRows.first,
              let run = runRows.first,
              let directBudget = directRunBudget.first,
              sessionRows.count == 1,
              runRows.count == 1,
              directRunBudget.count == 1,
              session.reportCount == aggregates.reportCount,
              session.evidenceCount == aggregates.evidenceCount,
              session.evidenceBytes == aggregates.evidenceBytes,
              session.degradationCount == aggregates.degradationCount,
              session.degradationBytes == aggregates.degradationBytes,
              session.budgetCount == aggregates.budgetCount,
              session.budgetBytes == aggregates.budgetBytes,
              run.count == directBudget.count,
              run.bytes == directBudget.bytes
        else {
            throw InvestigationPersistenceError.invalidStoredRecord
        }
        if let reportID {
            let reportRows = try connection.query(
                """
                SELECT report.evidence_row_count,
                       report.evidence_payload_byte_count,
                       report.degradation_row_count,
                       report.degradation_payload_byte_count,
                       (SELECT count(*) FROM investigation_evidence evidence
                        WHERE evidence.investigation_id = report.investigation_id
                          AND evidence.report_id = report.report_id),
                       (SELECT COALESCE(
                            sum(length(CAST(payload AS BLOB))), 0
                        ) FROM investigation_evidence evidence
                        WHERE evidence.investigation_id = report.investigation_id
                          AND evidence.report_id = report.report_id),
                       (SELECT count(*)
                        FROM investigation_report_degradations degradation
                        WHERE degradation.investigation_id =
                                report.investigation_id
                          AND degradation.report_id = report.report_id),
                       (SELECT COALESCE(
                            sum(length(CAST(payload AS BLOB))), 0
                        ) FROM investigation_report_degradations degradation
                        WHERE degradation.investigation_id =
                                report.investigation_id
                          AND degradation.report_id = report.report_id)
                FROM investigation_reports report
                WHERE report.investigation_id = ?
                  AND report.report_id = ?
                """,
                bindings: [
                    .text(investigationID.rawValue),
                    .text(reportID.rawValue),
                ],
                operation: "investigation.terminal.verifyReport"
            ) { statement in
                (0..<8).map {
                    sqlite3_column_int64(statement, Int32($0))
                }
            }
            guard reportRows.count == 1,
                  reportRows[0][0] == reportRows[0][4],
                  reportRows[0][1] == reportRows[0][5],
                  reportRows[0][2] == reportRows[0][6],
                  reportRows[0][3] == reportRows[0][7]
            else {
                throw InvestigationPersistenceError.invalidStoredRecord
            }
        }
    }

    private func terminalReplay(
        _ command: InvestigationTerminalCommand
    ) throws -> InvestigationTerminalResult? {
        let rows = try connection.query(
            """
            SELECT state, terminal_cause, terminal_report_id, terminal_at_ms
            FROM investigation_runs
            WHERE investigation_id = ? AND run_id = ?
            """,
            bindings: [
                .text(command.investigationID.rawValue),
                .text(command.runID.rawValue),
            ],
            operation: "investigation.terminal.replay.identity"
        ) { statement in
            (
                state: columnText(statement, 0),
                cause: sqlite3_column_type(statement, 1) == SQLITE_NULL
                    ? nil : columnText(statement, 1),
                reportID: sqlite3_column_type(statement, 2) == SQLITE_NULL
                    ? nil : columnText(statement, 2),
                terminalAt: sqlite3_column_type(statement, 3) == SQLITE_NULL
                    ? nil : sqlite3_column_int64(statement, 3)
            )
        }
        guard let row = rows.first else {
            throw InvestigationPersistenceError.invalidStoredRecord
        }
        guard row.state != InvestigationRunState.terminalBarrier.rawValue else {
            return nil
        }
        guard row.state == command.runState.rawValue,
              row.cause == command.cause.rawValue,
              row.reportID == command.report?.id.rawValue,
              row.terminalAt == storeMilliseconds(command.terminalAt),
              try terminalRowsMatch(command),
              let result = try loadTerminalResult(
                  investigationID: command.investigationID,
                  reportID: command.report?.id
              )
        else {
            throw InvestigationPersistenceError.conflictingTerminalReplay
        }
        return result
    }

    private func terminalRowsMatch(
        _ command: InvestigationTerminalCommand
    ) throws -> Bool {
        let prepared = try prepareTerminalCommand(command)
        let events = try connection.query(
            """
            SELECT event_id, ordinal, event_kind, payload
            FROM investigation_budget_events
            WHERE investigation_id = ? AND run_id = ?
            ORDER BY ordinal
            """,
            bindings: [
                .text(command.investigationID.rawValue),
                .text(command.runID.rawValue),
            ],
            operation: "investigation.terminal.replay.budget"
        ) {
            (
                id: columnText($0, 0),
                ordinal: sqlite3_column_int64($0, 1),
                kind: columnText($0, 2),
                payload: columnText($0, 3)
            )
        }
        guard events.count == prepared.budgetEvents.count,
              zip(events, prepared.budgetEvents).allSatisfy({
                  $0.0.id == $0.1.input.id.rawValue
                    && $0.0.ordinal == Int64($0.1.input.ordinal)
                    && $0.0.kind == $0.1.input.kind.rawValue
                    && $0.0.payload == $0.1.payload
              })
        else {
            return false
        }
        guard let report = prepared.report else {
            return true
        }
        let storedReports = try connection.query(
            """
            SELECT report_kind, created_at_ms, payload
            FROM investigation_reports
            WHERE investigation_id = ? AND report_id = ? AND run_id = ?
            """,
            bindings: [
                .text(command.investigationID.rawValue),
                .text(report.input.id.rawValue),
                .text(command.runID.rawValue),
            ],
            operation: "investigation.terminal.replay.report"
        ) {
            (
                kind: columnText($0, 0),
                createdAt: sqlite3_column_int64($0, 1),
                payload: columnText($0, 2)
            )
        }
        guard storedReports.count == 1,
              storedReports[0].kind == report.input.kind.rawValue,
              storedReports[0].createdAt
                == storeMilliseconds(command.terminalAt),
              storedReports[0].payload == report.payload
        else {
            return false
        }
        let storedEvidence = try connection.query(
            """
            SELECT evidence_id, ordinal, target_id, evidence_kind, payload
            FROM investigation_evidence
            WHERE investigation_id = ? AND report_id = ?
            ORDER BY ordinal
            """,
            bindings: [
                .text(command.investigationID.rawValue),
                .text(report.input.id.rawValue),
            ],
            operation: "investigation.terminal.replay.evidence"
        ) {
            (
                id: columnText($0, 0),
                ordinal: sqlite3_column_int64($0, 1),
                targetID: columnText($0, 2),
                kind: columnText($0, 3),
                payload: columnText($0, 4)
            )
        }
        let storedDegradations = try connection.query(
            """
            SELECT degradation_id, ordinal, degradation_kind, payload
            FROM investigation_report_degradations
            WHERE investigation_id = ? AND report_id = ?
            ORDER BY ordinal
            """,
            bindings: [
                .text(command.investigationID.rawValue),
                .text(report.input.id.rawValue),
            ],
            operation: "investigation.terminal.replay.degradation"
        ) {
            (
                id: columnText($0, 0),
                ordinal: sqlite3_column_int64($0, 1),
                kind: columnText($0, 2),
                payload: columnText($0, 3)
            )
        }
        let evidenceMatches =
            storedEvidence.count == report.evidence.count
            && zip(
                storedEvidence,
                report.evidence.enumerated()
            ).allSatisfy { stored, expected in
                stored.id == expected.element.input.id.rawValue
                    && stored.ordinal == Int64(expected.offset)
                    && stored.targetID
                        == expected.element.input.targetID.rawValue
                    && stored.kind
                        == expected.element.input.kind.rawValue
                    && stored.payload == expected.element.payload
            }
        let degradationsMatch =
            storedDegradations.count == report.degradations.count
            && zip(
                storedDegradations,
                report.degradations.enumerated()
            ).allSatisfy { stored, expected in
                stored.id == expected.element.input.id.rawValue
                    && stored.ordinal == Int64(expected.offset)
                    && stored.kind
                        == expected.element.input.kind.rawValue
                    && stored.payload == expected.element.payload
            }
        return evidenceMatches && degradationsMatch
    }

    private func loadTerminalResult(
        investigationID: InvestigationID,
        reportID: InvestigationReportID?
    ) throws -> InvestigationTerminalResult? {
        guard let investigation = try loadInvestigation(
            id: investigationID
        ) else {
            return nil
        }
        let report: InvestigationStoredReport?
        if let reportID {
            report = try loadInvestigationReport(
                investigationID: investigationID,
                reportID: reportID
            )
        } else {
            report = nil
        }
        return InvestigationTerminalResult(
            investigation: investigation,
            report: report
        )
    }

    private func loadInvestigationReport(
        investigationID: InvestigationID,
        reportID: InvestigationReportID
    ) throws -> InvestigationStoredReport? {
        let rows = try connection.query(
            """
            SELECT run_id, report_kind, created_at_ms, payload,
                   evidence_row_count, evidence_payload_byte_count,
                   degradation_row_count, degradation_payload_byte_count
            FROM investigation_reports
            WHERE investigation_id = ? AND report_id = ?
            """,
            bindings: [
                .text(investigationID.rawValue),
                .text(reportID.rawValue),
            ],
            operation: "investigation.report.load"
        ) { statement in
            (
                runID: columnText(statement, 0),
                kind: columnText(statement, 1),
                createdAt: sqlite3_column_int64(statement, 2),
                payload: columnText(statement, 3),
                evidenceCount: sqlite3_column_int64(statement, 4),
                evidenceBytes: sqlite3_column_int64(statement, 5),
                degradationCount: sqlite3_column_int64(statement, 6),
                degradationBytes: sqlite3_column_int64(statement, 7)
            )
        }
        guard let row = rows.first else {
            return nil
        }
        guard rows.count == 1 else {
            throw InvestigationPersistenceError.invalidStoredRecord
        }
        let direct = try connection.query(
            """
            SELECT
                (SELECT count(*) FROM investigation_evidence
                 WHERE investigation_id = ? AND report_id = ?),
                (SELECT COALESCE(sum(length(CAST(payload AS BLOB))), 0)
                 FROM investigation_evidence
                 WHERE investigation_id = ? AND report_id = ?),
                (SELECT count(*) FROM investigation_report_degradations
                 WHERE investigation_id = ? AND report_id = ?),
                (SELECT COALESCE(sum(length(CAST(payload AS BLOB))), 0)
                 FROM investigation_report_degradations
                 WHERE investigation_id = ? AND report_id = ?)
            """,
            bindings: [
                .text(investigationID.rawValue),
                .text(reportID.rawValue),
                .text(investigationID.rawValue),
                .text(reportID.rawValue),
                .text(investigationID.rawValue),
                .text(reportID.rawValue),
                .text(investigationID.rawValue),
                .text(reportID.rawValue),
            ],
            operation: "investigation.report.verify"
        ) {
            (
                evidenceCount: sqlite3_column_int64($0, 0),
                evidenceBytes: sqlite3_column_int64($0, 1),
                degradationCount: sqlite3_column_int64($0, 2),
                degradationBytes: sqlite3_column_int64($0, 3)
            )
        }
        guard let counts = direct.first,
              direct.count == 1,
              row.evidenceCount == counts.evidenceCount,
              row.evidenceBytes == counts.evidenceBytes,
              row.degradationCount == counts.degradationCount,
              row.degradationBytes == counts.degradationBytes
        else {
            throw InvestigationPersistenceError.invalidStoredRecord
        }
        return try InvestigationStoredReport(
            investigationID: investigationID,
            runID: InvestigationRunID(validating: row.runID),
            id: reportID,
            kind: investigationEnum(
                InvestigationReportKind.self,
                rawValue: row.kind
            ),
            createdAt: Date(
                timeIntervalSince1970: TimeInterval(row.createdAt) / 1_000
            ),
            payload: decodeInvestigationPayload(
                InvestigationReportPayload.self,
                text: row.payload
            )
        )
    }

    private func decodeInvestigationPayload<T: Codable>(
        _ type: T.Type,
        text: String
    ) throws -> T {
        let data = Data(text.utf8)
        let value = try DomainJSON.decode(type, from: data)
        guard try DomainJSON.encode(value) == data else {
            throw InvestigationPersistenceError.invalidStoredRecord
        }
        return value
    }

    private func checkedInvestigationOrdinal(
        _ value: Int64
    ) throws -> UInt64 {
        guard value >= 0 else {
            throw InvestigationPersistenceError.invalidStoredRecord
        }
        return UInt64(value)
    }

    private func investigationEnum<Value>(
        _ type: Value.Type,
        rawValue: String
    ) throws -> Value where Value: RawRepresentable, Value.RawValue == String {
        guard let value = Value(rawValue: rawValue) else {
            throw InvestigationPersistenceError.invalidStoredRecord
        }
        return value
    }

    private func investigationSourceIdentity(
        id: InvestigationID
    ) throws -> InvestigationSourceStorageIdentity? {
        let rows = try connection.query(
            """
            SELECT scan_session_id, scan_scope_id, source_fingerprint,
                   source_row_count, relevance_token_count,
                   source_payload_byte_count, source_canonical_byte_count,
                   expires_at_ms
            FROM investigation_sessions
            WHERE id = ?
            """,
            bindings: [.text(id.rawValue)],
            operation: "investigation.sourceIdentity"
        ) { statement in
            (
                scanSessionID: columnText(statement, 0),
                scanScopeID: columnText(statement, 1),
                sourceFingerprint: columnBlob(statement, 2),
                sourceRowCount: sqlite3_column_int64(statement, 3),
                relevanceTokenCount: sqlite3_column_int64(statement, 4),
                sourcePayloadByteCount: sqlite3_column_int64(statement, 5),
                sourceCanonicalByteCount: sqlite3_column_int64(statement, 6),
                expiresAtMilliseconds: sqlite3_column_int64(statement, 7)
            )
        }
        guard let row = rows.first else {
            return nil
        }
        let tokens = try connection.query(
            """
            SELECT ordinal, token
            FROM investigation_relevance_tokens
            WHERE investigation_id = ?
            ORDER BY ordinal
            """,
            bindings: [.text(id.rawValue)],
            operation: "investigation.sourceIdentity.tokens"
        ) { statement in
            (
                ordinal: sqlite3_column_int64(statement, 0),
                token: columnText(statement, 1)
            )
        }
        guard row.sourceRowCount >= 0,
              row.relevanceTokenCount >= 0,
              row.sourcePayloadByteCount >= 0,
              row.sourceCanonicalByteCount >= 0,
              tokens.count == Int(row.relevanceTokenCount),
              tokens.enumerated().allSatisfy({
                  $0.offset == $0.element.ordinal
              })
        else {
            throw InvestigationPersistenceError.invalidStoredRecord
        }
        return try InvestigationSourceStorageIdentity(
            scanSessionID: ScanSessionID(validating: row.scanSessionID),
            scanScopeID: ScanScopeID(validating: row.scanScopeID),
            sourceFingerprint: InvestigationFingerprint(
                validating: row.sourceFingerprint
            ),
            sourceRowCount: UInt64(row.sourceRowCount),
            relevanceTokens: tokens.map {
                try DomainToken(validating: $0.token)
            },
            sourcePayloadByteCount: UInt64(row.sourcePayloadByteCount),
            sourceCanonicalByteCount: UInt64(
                row.sourceCanonicalByteCount
            ),
            expiresAtMilliseconds: row.expiresAtMilliseconds
        )
    }

    private func loadInvestigation(
        id: InvestigationID
    ) throws -> InvestigationStoredSession? {
        let rows = try connection.query(
            """
            SELECT session.state, session.stage, session.source_row_count,
                   session.relevance_token_count, session.created_at_ms,
                   session.updated_at_ms, session.expires_at_ms,
                   run.run_id, run.plan_fingerprint, run.plan_json,
                   run.budget_preset, run.plan_created_at_ms,
                   run.plan_expires_at_ms, run.target_count,
                   run.target_set_fingerprint, run.state, run.stage,
                   run.payload
            FROM investigation_sessions session
            JOIN investigation_runs run
              ON run.investigation_id = session.id
             AND run.run_ordinal = (
                 SELECT MAX(current_run.run_ordinal)
                 FROM investigation_runs current_run
                 WHERE current_run.investigation_id = session.id
             )
            WHERE session.id = ?
            """,
            bindings: [.text(id.rawValue)],
            operation: "investigation.load"
        ) { statement in
            (
                sessionState: columnText(statement, 0),
                sessionStage: columnText(statement, 1),
                sourceRowCount: sqlite3_column_int64(statement, 2),
                relevanceTokenCount: sqlite3_column_int64(statement, 3),
                createdAtMilliseconds: sqlite3_column_int64(statement, 4),
                updatedAtMilliseconds: sqlite3_column_int64(statement, 5),
                expiresAtMilliseconds: sqlite3_column_int64(statement, 6),
                runID: columnText(statement, 7),
                planFingerprint: columnBlob(statement, 8),
                planJSON: columnText(statement, 9),
                budgetPreset: columnText(statement, 10),
                planCreatedAtMilliseconds: sqlite3_column_int64(
                    statement,
                    11
                ),
                planExpiresAtMilliseconds: sqlite3_column_int64(
                    statement,
                    12
                ),
                targetCount: sqlite3_column_int64(statement, 13),
                targetSetFingerprint: columnBlob(statement, 14),
                runState: columnText(statement, 15),
                runStage: columnText(statement, 16),
                runPayload: columnText(statement, 17)
            )
        }
        guard let row = rows.first else {
            return nil
        }
        guard rows.count == 1,
              let sessionState = InvestigationSessionState(
                  rawValue: row.sessionState
              ),
              let sessionStage = InvestigationStage(
                  rawValue: row.sessionStage
              ),
              let runState = InvestigationRunState(rawValue: row.runState),
              let runStage = InvestigationStage(rawValue: row.runStage),
              sessionStage == runStage,
              sessionState.rawValue == runState.rawValue
                || (sessionState == .paused && runState == .partial),
              row.sourceRowCount >= 0,
              row.relevanceTokenCount >= 0,
              row.targetCount > 0
        else {
            throw InvestigationPersistenceError.invalidStoredRecord
        }
        let runID = try InvestigationRunID(validating: row.runID)
        let planData = Data(row.planJSON.utf8)
        let plan = try DomainJSON.decode(
            InvestigationPlan.self,
            from: planData
        )
        let runPayload = try DomainJSON.decode(
            InvestigationRunStoragePayload.self,
            from: Data(row.runPayload.utf8)
        )
        guard try DomainJSON.encode(plan) == planData,
              plan.id == id,
              plan.budgetPreset.rawValue == row.budgetPreset,
              storeMilliseconds(plan.createdAt)
                == row.planCreatedAtMilliseconds,
              storeMilliseconds(plan.expiresAt)
                == row.planExpiresAtMilliseconds,
              plan.targets.count == row.targetCount,
              plan.fingerprint.bytes == row.planFingerprint,
              plan.targetSetFingerprint.bytes == row.targetSetFingerprint,
              runPayload.investigationID == id,
              runPayload.runID == runID
        else {
            throw InvestigationPersistenceError.invalidStoredRecord
        }
        let targetIDs = try connection.query(
            """
            SELECT target_id
            FROM investigation_run_targets
            WHERE investigation_id = ? AND run_id = ?
            ORDER BY ordinal
            """,
            bindings: [.text(id.rawValue), .text(runID.rawValue)],
            operation: "investigation.load.runTargets"
        ) {
            columnText($0, 0)
        }
        guard targetIDs == plan.targets.map(\.id.rawValue) else {
            throw InvestigationPersistenceError.invalidStoredRecord
        }
        return InvestigationStoredSession(
            id: id,
            runID: runID,
            plan: plan,
            state: sessionState,
            stage: sessionStage,
            sourceRowCount: UInt64(row.sourceRowCount),
            relevanceTokenCount: UInt64(row.relevanceTokenCount),
            createdAt: Date(
                timeIntervalSince1970:
                    TimeInterval(row.createdAtMilliseconds) / 1_000
            ),
            updatedAt: Date(
                timeIntervalSince1970:
                    TimeInterval(row.updatedAtMilliseconds) / 1_000
            ),
            expiresAt: Date(
                timeIntervalSince1970:
                    TimeInterval(row.expiresAtMilliseconds) / 1_000
            )
        )
    }

    private func loadInvestigationRun(
        investigationID: InvestigationID,
        runID: InvestigationRunID
    ) throws -> InvestigationLoadedRun? {
        let rows = try connection.query(
            """
            SELECT run.plan_json, run.plan_fingerprint,
                   run.target_set_fingerprint, run.budget_preset,
                   run.plan_created_at_ms, run.plan_expires_at_ms,
                   run.target_count, run.parent_run_id,
                   run.parent_report_id, run.state, run.stage,
                   run.terminal_cause, run.terminal_report_id,
                   report.report_kind, run.payload
            FROM investigation_runs run
            LEFT JOIN investigation_reports report
              ON report.investigation_id = run.investigation_id
             AND report.report_id = run.terminal_report_id
             AND report.run_id = run.run_id
            WHERE run.investigation_id = ? AND run.run_id = ?
            """,
            bindings: [
                .text(investigationID.rawValue),
                .text(runID.rawValue),
            ],
            operation: "investigation.run.load"
        ) { statement in
            (
                planJSON: columnText(statement, 0),
                planFingerprint: columnBlob(statement, 1),
                targetSetFingerprint: columnBlob(statement, 2),
                budgetPreset: columnText(statement, 3),
                planCreatedAt: sqlite3_column_int64(statement, 4),
                planExpiresAt: sqlite3_column_int64(statement, 5),
                targetCount: sqlite3_column_int64(statement, 6),
                parentRunID: sqlite3_column_type(statement, 7) == SQLITE_NULL
                    ? nil : columnText(statement, 7),
                parentReportID:
                    sqlite3_column_type(statement, 8) == SQLITE_NULL
                    ? nil : columnText(statement, 8),
                state: columnText(statement, 9),
                stage: columnText(statement, 10),
                terminalCause:
                    sqlite3_column_type(statement, 11) == SQLITE_NULL
                    ? nil : columnText(statement, 11),
                reportID:
                    sqlite3_column_type(statement, 12) == SQLITE_NULL
                    ? nil : columnText(statement, 12),
                reportKind:
                    sqlite3_column_type(statement, 13) == SQLITE_NULL
                    ? nil : columnText(statement, 13),
                payload: columnText(statement, 14)
            )
        }
        guard let row = rows.first else {
            return nil
        }
        guard rows.count == 1, row.targetCount > 0 else {
            throw InvestigationPersistenceError.invalidStoredRecord
        }
        let planData = Data(row.planJSON.utf8)
        let plan = try DomainJSON.decode(
            InvestigationPlan.self,
            from: planData
        )
        let payload = try DomainJSON.decode(
            InvestigationRunStoragePayload.self,
            from: Data(row.payload.utf8)
        )
        let state = try investigationEnum(
            InvestigationRunState.self,
            rawValue: row.state
        )
        let stage = try investigationEnum(
            InvestigationStage.self,
            rawValue: row.stage
        )
        let terminalCause = try row.terminalCause.map {
            try investigationEnum(
                InvestigationTerminalCause.self,
                rawValue: $0
            )
        }
        let parentRunID = try row.parentRunID.map {
            try InvestigationRunID(validating: $0)
        }
        let parentReportID = try row.parentReportID.map {
            try InvestigationReportID(validating: $0)
        }
        let reportID = try row.reportID.map {
            try InvestigationReportID(validating: $0)
        }
        let reportKind = try row.reportKind.map {
            try investigationEnum(
                InvestigationReportKind.self,
                rawValue: $0
            )
        }
        guard try DomainJSON.encode(plan) == planData,
              plan.id == investigationID,
              plan.budgetPreset.rawValue == row.budgetPreset,
              storeMilliseconds(plan.createdAt) == row.planCreatedAt,
              storeMilliseconds(plan.expiresAt) == row.planExpiresAt,
              plan.targets.count == row.targetCount,
              plan.fingerprint.bytes == row.planFingerprint,
              plan.targetSetFingerprint.bytes
                == row.targetSetFingerprint,
              payload.investigationID == investigationID,
              payload.runID == runID,
              (parentRunID == nil) == (parentReportID == nil),
              terminalIdentityIsValid(
                  state: state,
                  reportID: reportID,
                  reportKind: reportKind
              )
        else {
            throw InvestigationPersistenceError.invalidStoredRecord
        }
        let targetIDs = try connection.query(
            """
            SELECT target_id
            FROM investigation_run_targets
            WHERE investigation_id = ? AND run_id = ?
            ORDER BY ordinal
            """,
            bindings: [
                .text(investigationID.rawValue),
                .text(runID.rawValue),
            ],
            operation: "investigation.run.loadTargets"
        ) {
            columnText($0, 0)
        }
        guard targetIDs == plan.targets.map(\.id.rawValue) else {
            throw InvestigationPersistenceError.invalidStoredRecord
        }
        return InvestigationLoadedRun(
            parentRunID: parentRunID,
            parentReportID: parentReportID,
            state: state,
            stage: stage,
            terminalCause: terminalCause,
            reportID: reportID,
            reportKind: reportKind,
            plan: plan
        )
    }

    private func terminalIdentityIsValid(
        state: InvestigationRunState,
        reportID: InvestigationReportID?,
        reportKind: InvestigationReportKind?
    ) -> Bool {
        switch state {
        case .completed:
            reportID != nil && reportKind == .final
        case .partial:
            reportID != nil && reportKind == .partial
        case .planned,
             .awaitingDisclosure,
             .ready,
             .running,
             .pauseRequested,
             .stopRequested,
             .terminalBarrier,
             .blocked,
             .failed:
            reportID == nil && reportKind == nil
        }
    }

    private func verifyInvestigationSource(
        id: InvestigationID,
        expected: InvestigationSourceProjection
    ) throws {
        guard let identity = try investigationSourceIdentity(id: id),
              identity.scanSessionID == expected.summary.scanSessionID,
              identity.scanScopeID == expected.summary.primaryScopeID,
              identity.sourceFingerprint
                == expected.summary.sourceFingerprint,
              identity.sourceRowCount == expected.summary.sourceRowCount,
              identity.relevanceTokens
                == expected.summary.relevanceTokens,
              identity.sourcePayloadByteCount
                == expected.summary.exactPayloadBytes,
              identity.sourceCanonicalByteCount
                == expected.summary.completeCanonicalBytes,
              try connection.verifyInvestigationSourceRowCount(
                  investigationID: id,
                  expectedRowCount: expected.summary.sourceRowCount
              )
        else {
            throw InvestigationPersistenceError.invalidStoredRecord
        }
    }

    private func encodeInvestigationPayload<T: Encodable>(
        _ payload: T,
        limit: Int = maximumStorePayloadBytes
    ) throws -> String {
        let data = try DomainJSON.encode(payload)
        guard data.count <= limit else {
            throw EvidenceStoreError.payloadTooLarge(
                limit: limit
            )
        }
        return String(decoding: data, as: UTF8.self)
    }

    private func boundedInvestigationPlanJSON(
        _ plan: InvestigationPlan
    ) throws -> String {
        let data = try DomainJSON.encode(plan)
        guard data.count <= InvestigationPlan.maximumJSONBytes else {
            throw EvidenceStoreError.payloadTooLarge(
                limit: InvestigationPlan.maximumJSONBytes
            )
        }
        return String(decoding: data, as: UTF8.self)
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
        payloadLimit: Int = maximumStorePayloadBytes,
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
                .text(
                    try boundedStorePayloadString(
                        payload,
                        limit: payloadLimit
                    )
                ),
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

    private func insertImmutableSingleton(
        table: String,
        id: String,
        parentColumn: String,
        parentID: String,
        payload: Data,
        operation: String
    ) throws {
        let payload = try boundedStorePayloadString(payload)
        try connection.transaction(operation: operation) {
            let existing = try connection.query(
                """
                SELECT \(parentColumn), payload
                FROM \(table)
                WHERE id = ?
                """,
                bindings: [.text(id)],
                operation: "\(operation).identity"
            ) {
                (
                    parentID: columnText($0, 0),
                    payload: columnText($0, 1)
                )
            }.first
            if let existing {
                guard existing.parentID == parentID,
                      existing.payload == payload
                else {
                    throw EvidenceStoreError.immutableRecordConflict
                }
                return
            }
            try connection.execute(
                """
                INSERT INTO \(table) (id, \(parentColumn), payload)
                VALUES (?, ?, ?)
                """,
                bindings: [.text(id), .text(parentID), .text(payload)],
                operation: "\(operation).record"
            )
        }
    }

    private func insertImmutableExpiringRecord(
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
        let requestedExpiry = storeMilliseconds(expiresAt)
        guard requestedExpiry <= addingStoreMilliseconds(
            maximumLifetimeMilliseconds,
            to: timestampMilliseconds
        ) else {
            throw EvidenceStoreError.retentionLimitExceeded
        }
        let payload = try boundedStorePayloadString(payload)
        try connection.transaction(operation: operation) {
            let existing = try connection.query(
                """
                SELECT \(parentColumn), \(timestampColumn), expires_at_ms, payload
                FROM \(table)
                WHERE id = ?
                """,
                bindings: [.text(id)],
                operation: "\(operation).identity"
            ) {
                (
                    parentID: columnText($0, 0),
                    timestamp: sqlite3_column_int64($0, 1),
                    expiresAt: sqlite3_column_int64($0, 2),
                    payload: columnText($0, 3)
                )
            }.first
            if let existing {
                guard existing.parentID == parentID,
                      existing.timestamp == timestampMilliseconds,
                      existing.expiresAt == requestedExpiry,
                      existing.payload == payload
                else {
                    throw EvidenceStoreError.immutableRecordConflict
                }
                return
            }
            try connection.execute(
                """
                INSERT INTO \(table)
                (id, \(parentColumn), \(timestampColumn), expires_at_ms, payload)
                VALUES (?, ?, ?, ?, ?)
                """,
                bindings: [
                    .text(id),
                    .text(parentID),
                    .integer(timestampMilliseconds),
                    .integer(requestedExpiry),
                    .text(payload),
                ],
                operation: "\(operation).record"
            )
        }
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

    private func cleanupHistoryPlan(
        id: CleanupPlanID
    ) throws -> CleanupPlan? {
        let rows = try connection.query(
            """
            SELECT id, payload, session_id, created_at_ms, expires_at_ms
            FROM cleanup_plans
            WHERE id = ?
            """,
            bindings: [.text(id.rawValue)],
            operation: "history.plan"
        ) { statement -> StoreDecodedRow<CleanupPlan> in
            let storedID = columnText(statement, 0)
            do {
                let plan = try DomainJSON.decode(
                    CleanupPlan.self,
                    from: Data(columnText(statement, 1).utf8)
                )
                guard plan.id.rawValue == storedID,
                      columnText(statement, 2)
                        == plan.scanSessionID.rawValue,
                      sqlite3_column_int64(statement, 3)
                        == storeMilliseconds(plan.createdAt),
                      sqlite3_column_int64(statement, 4)
                        == storeMilliseconds(plan.expiresAt)
                else {
                    throw EvidenceStoreError.recordIdentityMismatch
                }
                return .record(plan)
            } catch {
                return .corrupt(storedID)
            }
        }
        guard let row = rows.first else {
            return nil
        }
        switch row {
        case let .record(plan):
            return plan
        case .corrupt:
            return nil
        }
    }

    private static func planEnrichment(
        _ plan: CleanupPlan,
        matches manifest: CleanupManifest,
        now: Date
    ) -> Bool {
        guard plan.compatibility == .current,
              plan.id == manifest.planID,
              now < plan.expiresAt
        else {
            return false
        }
        let items = Dictionary(
            uniqueKeysWithValues: plan.items.map { ($0.id, $0) }
        )
        return manifest.records.allSatisfy { record in
            guard let item = items[record.planItemID] else {
                return false
            }
            return item.proposedAction == record.action
        }
    }

    private func policySnapshot(
        id: SnapshotID
    ) throws -> PathSnapshot? {
        try decodeOne(
            table: "path_snapshots",
            id: id.rawValue,
            type: PathSnapshot.self,
            recordID: \.id.rawValue,
            storageColumns: ", session_id, relative_path, observed_at_ms",
            validateStorage: { snapshot, statement in
                columnText(statement, 1) == snapshot.sessionID.rawValue
                    && columnText(statement, 2) == snapshot.relativePath
                    && sqlite3_column_int64(statement, 3)
                    == storeMilliseconds(snapshot.observedAt)
            },
            operation: "cleanupPolicy.snapshot"
        )
    }

    private func policyClassification(
        id: ClassificationID
    ) throws -> Classification? {
        try decodeOne(
            table: "classifications",
            id: id.rawValue,
            type: Classification.self,
            recordID: \.id.rawValue,
            storageColumns:
                ", snapshot_id, disposition, classified_at_ms",
            validateStorage: { classification, statement in
                columnText(statement, 1)
                    == classification.snapshotID.rawValue
                    && columnText(statement, 2)
                    == classification.disposition.rawValue
                    && sqlite3_column_int64(statement, 3)
                    == storeMilliseconds(classification.classifiedAt)
            },
            operation: "cleanupPolicy.classification"
        )
    }

    private func policyEvidence(
        snapshotID: SnapshotID
    ) throws -> [EvidenceRecord] {
        let rows = try connection.query(
            """
            SELECT id, payload, snapshot_id, observed_at_ms
            FROM evidence
            WHERE snapshot_id = ?
            ORDER BY observed_at_ms ASC, id ASC
            LIMIT 101
            """,
            bindings: [.text(snapshotID.rawValue)],
            operation: "cleanupPolicy.evidence"
        ) { statement -> EvidenceRecord in
            let id = columnText(statement, 0)
            let record = try DomainJSON.decode(
                EvidenceRecord.self,
                from: Data(columnText(statement, 1).utf8)
            )
            guard record.id.rawValue == id,
                  record.targetID == snapshotID,
                  columnText(statement, 2) == snapshotID.rawValue,
                  sqlite3_column_int64(statement, 3)
                    == storeMilliseconds(record.observedAt)
            else {
                throw EvidenceStoreError.recordIdentityMismatch
            }
            return record
        }
        guard rows.count <= 100,
              Set(rows.map(\.id)).count == rows.count
        else {
            throw EvidenceStoreError.recordIdentityMismatch
        }
        return rows
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
        try boundedStorePayloadString(data)
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

private let evidenceSchemaV1Statements: [(String, String)] = [
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

private let evidenceSchemaV2Statements: [(String, String)] = [
    (
        "schema.volumeBaselines",
        """
        CREATE TABLE IF NOT EXISTS volume_baselines (
            session_id TEXT NOT NULL REFERENCES scan_sessions(id) ON DELETE CASCADE,
            scope_id TEXT NOT NULL,
            sampled_at_ms INTEGER NOT NULL,
            payload TEXT NOT NULL,
            PRIMARY KEY (session_id, scope_id)
        ) STRICT
        """
    ),
    (
        "schema.volumeBaselineIndex",
        "CREATE INDEX IF NOT EXISTS idx_volume_baselines_session_scope ON volume_baselines(session_id, scope_id)"
    ),
]

private let evidenceSchemaV3Statements: [(String, String)] = [
    (
        "schema.cleanupRunJournals",
        """
        CREATE TABLE IF NOT EXISTS cleanup_run_journals (
            id TEXT PRIMARY KEY NOT NULL,
            plan_id TEXT NOT NULL,
            stage TEXT NOT NULL
                CHECK (
                    stage IN (
                        'prepared',
                        'actionStarted',
                        'actionOutcomeRecorded',
                        'manifestPending',
                        'auditPending',
                        'finalized'
                    )
                ),
            retention_class TEXT NOT NULL
                CHECK (retention_class IN ('evidenceLinked', 'audit')),
            updated_at_ms INTEGER NOT NULL,
            expires_at_ms INTEGER NOT NULL,
            payload TEXT NOT NULL
        ) STRICT
        """
    ),
    (
        "schema.cleanupRunJournalExpiryIndex",
        "CREATE INDEX IF NOT EXISTS idx_cleanup_run_journals_expiry ON cleanup_run_journals(retention_class, expires_at_ms, id)"
    ),
    (
        "schema.cleanupRunJournalStageIndex",
        "CREATE INDEX IF NOT EXISTS idx_cleanup_run_journals_stage ON cleanup_run_journals(stage, updated_at_ms DESC, id)"
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
