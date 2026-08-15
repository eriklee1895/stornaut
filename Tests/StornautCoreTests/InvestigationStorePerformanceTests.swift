import Foundation
import SQLite3
import Testing
@testable import StornautCore

@Test
func investigationSourceQueriesStreamWithoutTemporarySorts() async throws {
    let store = try EvidenceStore(configuration: .memory)
    let fixture = try InvestigationStoreV4Fixture()
    try await fixture.seed(store)

    let plans = try await store._testInvestigationSourceQueryPlans(
        scanSessionID: fixture.session.id,
        scanScopeID: fixture.scopeID
    )
    #expect(
        Set(plans.keys) == Set([
            "evidence-v1",
            "scan-session-v1",
            "space-ledger-v1",
            "path-snapshot-v1",
            "classification-v1",
        ])
    )
    #expect(
        plans.values.allSatisfy {
            !$0.contains("USE TEMP B-TREE")
        }
    )
    #expect(
        plans["path-snapshot-v1"]?.contains(
            "idx_investigation_source_path_snapshots_canonical"
        ) == true
    )
    #expect(
        plans["classification-v1"]?.contains(
            "idx_investigation_source_snapshot_membership"
        ) == true
    )
    #expect(
        plans["evidence-v1"]?.contains(
            "idx_investigation_source_snapshot_membership"
        ) == true
    )
    #expect(
        plans["classification-v1"]?.contains(
            "idx_investigation_source_classifications_canonical"
        ) == true
    )
    #expect(
        plans["evidence-v1"]?.contains(
            "idx_investigation_source_evidence_canonical"
        ) == true
    )
}

@Test
func investigationConnectionAuthorizerRejectsEveryProbe() async throws {
    let store = try EvidenceStore(configuration: .memory)
    let probes: [SQLiteInvestigationAuthorizationProbe] = [
        .defaultWrite,
        .wrongInsertTable,
        .wrongUpdateColumn,
        .nestedMode,
        .schemaMutationOutsideMigration,
    ]

    for probe in probes {
        await #expect(throws: EvidenceStoreError.authorizationViolation) {
            try await store._testInvestigationAuthorizationProbe(probe)
        }
    }
    #expect(await store.storeHealth() == .ready)
}

@Test
func investigationCancellationAndDeadlineRollbackWithoutResidue() async throws {
    let fixture = try InvestigationStoreV4Fixture()
    let cancellation = InvestigationCancellationTestControl()
    let cancelledStore = try EvidenceStore(
        configuration: .memory,
        testHooks: EvidenceStoreTestHooks(
            isCancelled: { cancellation.isCancelled }
        )
    )
    try await fixture.seed(cancelledStore)
    let cancelledCommand = fixture.command(
        investigationID: "investigation-operation-cancelled",
        runID: "investigation-run-operation-cancelled"
    )
    cancellation.cancel()

    await #expect(throws: EvidenceStoreError.operationCancelled) {
        _ = try await cancelledStore.createInvestigation(cancelledCommand)
    }
    cancellation.reset()
    #expect(
        try await cancelledStore._testInvestigationRowCounts(
            id: cancelledCommand.investigationID
        ) == .zero
    )
    #expect(await cancelledStore.storeHealth() == .ready)

    let deadline = InvestigationMonotonicTestClock()
    let deadlineStore = try EvidenceStore(
        configuration: .memory,
        testHooks: EvidenceStoreTestHooks(
            monotonicNanoseconds: { deadline.next() },
            isCancelled: { false }
        )
    )
    try await fixture.seed(deadlineStore)
    let deadlineCommand = fixture.command(
        investigationID: "investigation-operation-deadline",
        runID: "investigation-run-operation-deadline"
    )
    deadline.armDeadline()

    await #expect(throws: EvidenceStoreError.operationDeadlineExceeded) {
        _ = try await deadlineStore.createInvestigation(deadlineCommand)
    }
    #expect(
        try await deadlineStore._testInvestigationRowCounts(
            id: deadlineCommand.investigationID
        ) == .zero
    )
    #expect(await deadlineStore.storeHealth() == .ready)
}

@Test
func investigationProgressIsTypedEphemeralAndMonotonic() async throws {
    let fixture = try InvestigationStoreV4Fixture()
    let recorder = InvestigationProgressRecorder()
    let store = try EvidenceStore(
        configuration: .memory,
        investigationProgress: { recorder.record($0) }
    )
    try await fixture.seed(store)
    let command = fixture.command(
        investigationID: "investigation-progress-monotonic",
        runID: "investigation-run-progress-monotonic"
    )

    _ = try await store.createInvestigation(command)
    let progress = recorder.values
    let phaseOrdinals = progress.compactMap {
        InvestigationStoreProgressPhase.allCases.firstIndex(of: $0.phase)
    }

    #expect(progress.first?.phase == .lockAcquisition)
    #expect(progress.contains(where: { $0.phase == .sourceProjection }))
    #expect(progress.contains(where: { $0.phase == .persistence }))
    #expect(progress.contains(where: { $0.phase == .verification }))
    #expect(zip(phaseOrdinals, phaseOrdinals.dropFirst()).allSatisfy(<=))
    #expect(
        zip(
            progress.map(\.checkedRows),
            progress.dropFirst().map(\.checkedRows)
        ).allSatisfy(<=)
    )
    #expect(
        zip(
            progress.map(\.checkedBytes),
            progress.dropFirst().map(\.checkedBytes)
        ).allSatisfy(<=)
    )
    #expect(progress.last?.checkedRows == 15)
    #expect((progress.last?.checkedBytes ?? 0) > 0)
}

@Test
func investigationPostWriteCancellationRollsBackCompleteLineage() async throws {
    let fixture = try InvestigationStoreV4Fixture()
    let cancellation = InvestigationCancellationTestControl()
    let recorder = InvestigationProgressRecorder()
    let store = try EvidenceStore(
        configuration: .memory,
        testHooks: EvidenceStoreTestHooks(
            isCancelled: { cancellation.isCancelled },
            investigationProgress: { progress in
                recorder.record(progress)
                if progress.phase == .verification {
                    cancellation.cancel()
                }
            }
        )
    )
    try await fixture.seed(store)
    let command = fixture.command(
        investigationID: "investigation-post-write-cancelled",
        runID: "investigation-run-post-write-cancelled"
    )

    await #expect(throws: EvidenceStoreError.operationCancelled) {
        _ = try await store.createInvestigation(command)
    }
    cancellation.reset()

    #expect(recorder.values.contains(where: { $0.phase == .persistence }))
    #expect(recorder.values.contains(where: { $0.phase == .verification }))
    #expect(recorder.values.last?.phase == .rollback)
    #expect(
        try await store._testInvestigationRowCounts(
            id: command.investigationID
        ) == .zero
    )
    #expect(await store.storeHealth() == .ready)
}

@Test
func investigationBusyWriterFailsBeforeSourceWork() async throws {
    let root = try EvidenceStoreTestSupport.temporaryDirectory(
        "investigation-busy"
    )
    defer { try? FileManager.default.removeItem(at: root) }
    let configuration = try EvidenceStoreTestSupport.makeFileConfiguration(
        root: root
    )
    let fixture = try InvestigationStoreV4Fixture()
    let recorder = InvestigationProgressRecorder()
    let store = try EvidenceStore(
        configuration: configuration,
        investigationProgress: { recorder.record($0) }
    )
    try await fixture.seed(store)
    let command = fixture.command(
        investigationID: "investigation-store-busy",
        runID: "investigation-run-store-busy"
    )
    let lock = try InvestigationSQLiteWriterLock(
        path: configuration.evidenceDatabaseURL.path
    )
    defer { lock.release() }
    let started = ContinuousClock().now

    await #expect(throws: EvidenceStoreError.storeBusy) {
        _ = try await store.createInvestigation(command)
    }
    let elapsed = started.duration(to: ContinuousClock().now)

    #expect(elapsed >= .seconds(1))
    #expect(elapsed < .seconds(3))
    #expect(recorder.values.map(\.phase) == [.lockAcquisition])
    #expect(
        try await store._testInvestigationRowCounts(
            id: command.investigationID
        ) == .zero
    )
}

@Test
func investigationRollbackUnconfirmedQuarantinesFutureMutations() async throws {
    let fixture = try InvestigationStoreV4Fixture(hasCandidate: false)
    let store = try EvidenceStore(
        configuration: .memory,
        testHooks: EvidenceStoreTestHooks(
            forceRollbackUnconfirmedOperations: ["investigation.create"]
        )
    )
    try await fixture.seed(store)
    let command = fixture.command(
        investigationID: "investigation-rollback-unconfirmed",
        runID: "investigation-run-rollback-unconfirmed"
    )

    await #expect(throws: EvidenceStoreError.rollbackUnconfirmed) {
        _ = try await store.createInvestigation(command)
    }
    #expect(await store.storeHealth() == .rollbackUnconfirmed)
    await #expect(throws: EvidenceStoreError.rollbackUnconfirmed) {
        try await store.saveScanSession(fixture.session)
    }
    await #expect(throws: EvidenceStoreError.rollbackUnconfirmed) {
        _ = try await store.deleteInvestigation(id: command.investigationID)
    }
}

private final class InvestigationMonotonicTestClock:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var armed = false
    private var armedReadCount = 0

    func armDeadline() {
        lock.withLock {
            armed = true
            armedReadCount = 0
        }
    }

    func next() -> UInt64 {
        lock.withLock {
            guard armed else {
                return 0
            }
            defer { armedReadCount += 1 }
            return armedReadCount == 0 ? 0 : 90_000_000_000
        }
    }
}

private final class InvestigationCancellationTestControl:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.withLock { cancelled }
    }

    func cancel() {
        lock.withLock {
            cancelled = true
        }
    }

    func reset() {
        lock.withLock {
            cancelled = false
        }
    }
}

private final class InvestigationProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [InvestigationStoreProgress] = []

    var values: [InvestigationStoreProgress] {
        lock.withLock { storage }
    }

    func record(_ progress: InvestigationStoreProgress) {
        lock.withLock {
            storage.append(progress)
        }
    }
}

private final class InvestigationSQLiteWriterLock {
    private var database: OpaquePointer?

    init(path: String) throws {
        let code = sqlite3_open_v2(
            path,
            &database,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard code == SQLITE_OK, let database else {
            throw EvidenceStoreError.openFailed(code: code)
        }
        guard sqlite3_exec(
            database,
            "BEGIN IMMEDIATE",
            nil,
            nil,
            nil
        ) == SQLITE_OK else {
            sqlite3_close_v2(database)
            self.database = nil
            throw EvidenceStoreError.storeBusy
        }
    }

    deinit {
        release()
    }

    func release() {
        guard let database else {
            return
        }
        sqlite3_exec(database, "ROLLBACK", nil, nil, nil)
        sqlite3_close_v2(database)
        self.database = nil
    }
}
