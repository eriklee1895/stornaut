import Foundation
import Testing
@testable import StornautCore

@Test
func investigationTerminalCommitIsAtomicAndExactlyReplayable() async throws {
    let fixture = try InvestigationStoreV4Fixture()
    let clock = InvestigationTestWallClock(now: fixture.planningAt)
    let store = try EvidenceStore(
        configuration: .memory,
        testHooks: EvidenceStoreTestHooks(now: { clock.now })
    )
    try await fixture.seed(store)
    let created = try await store.createInvestigation(
        fixture.command(
            investigationID: "investigation-terminal-completed",
            runID: "investigation-run-terminal-completed"
        )
    )
    try await enterTerminalBarrier(
        store: store,
        session: created,
        cause: .coverageReached
    )
    clock.now = fixture.planningAt.addingTimeInterval(60)
    let command = try terminalCommand(
        session: created,
        state: .completed,
        sessionState: .completed,
        reportID: "investigation-report-terminal-completed",
        cause: .coverageReached,
        terminalAt: clock.now
    )

    let first = try await store.commitInvestigationTerminal(command)
    let replay = try await store.commitInvestigationTerminal(command)

    #expect(first == replay)
    #expect(first.investigation.state == .completed)
    #expect(first.report?.kind == .final)
    #expect(
        try await store._testInvestigationRowCounts(id: created.id)
            == InvestigationStoreRowCounts(
                sessions: 1,
                sourceRows: 5,
                relevanceTokens: 2,
                targets: 2,
                runs: 1,
                runTargets: 2,
                reports: 1,
                evidence: 2,
                degradations: 1,
                budgetEvents: 2
            )
    )

    let conflicting = try terminalCommand(
        session: created,
        state: .completed,
        sessionState: .completed,
        reportID: "investigation-report-terminal-alternate",
        cause: .coverageReached,
        terminalAt: clock.now
    )
    await #expect(
        throws: InvestigationPersistenceError.conflictingTerminalReplay
    ) {
        _ = try await store.commitInvestigationTerminal(conflicting)
    }
}

@Test
func investigationBlockedTerminalPersistsNoReportOrEvidence() async throws {
    let fixture = try InvestigationStoreV4Fixture()
    let store = try EvidenceStore(configuration: .memory)
    try await fixture.seed(store)
    let created = try await store.createInvestigation(
        fixture.command(
            investigationID: "investigation-terminal-blocked",
            runID: "investigation-run-terminal-blocked"
        )
    )
    try await enterTerminalBarrier(
        store: store,
        session: created,
        cause: .runtimeTerminalUnobserved
    )
    let command = try InvestigationTerminalCommand(
        investigationID: created.id,
        runID: created.runID,
        runState: .blocked,
        sessionState: .blocked,
        stage: .verify,
        cause: .runtimeTerminalUnobserved,
        report: nil,
        budgetEvents: [
            budgetEvent(
                suffix: "blocked-summary",
                ordinal: 0,
                kind: .terminalSummary
            ),
        ],
        terminalAt: fixture.planningAt.addingTimeInterval(30)
    )

    let result = try await store.commitInvestigationTerminal(command)

    #expect(result.investigation.state == .blocked)
    #expect(result.report == nil)
    #expect(
        try await store._testInvestigationRowCounts(id: created.id)
            == InvestigationStoreRowCounts(
                sessions: 1,
                sourceRows: 5,
                relevanceTokens: 2,
                targets: 2,
                runs: 1,
                runTargets: 2,
                reports: 0,
                evidence: 0,
                degradations: 0,
                budgetEvents: 1
            )
    )
}

@Test
func investigationAtomicTerminalSettlementMovesFromRequestStateInOneTransaction()
    async throws
{
    let fixture = try InvestigationStoreV4Fixture()
    let store = try EvidenceStore(configuration: .memory)
    try await fixture.seed(store)
    let created = try await store.createInvestigation(
        fixture.command(
            investigationID: "investigation-terminal-atomic",
            runID: "investigation-run-terminal-atomic"
        )
    )
    _ = try await store.transitionInvestigationRun(
        InvestigationRunTransitionCommand(
            investigationID: created.id,
            runID: created.runID,
            expectedRunState: .planned,
            runState: .ready,
            sessionState: .ready,
            stage: .prioritize,
            updatedAt: created.createdAt.addingTimeInterval(1)
        )
    )
    _ = try await store.transitionInvestigationRun(
        InvestigationRunTransitionCommand(
            investigationID: created.id,
            runID: created.runID,
            expectedRunState: .ready,
            runState: .running,
            sessionState: .running,
            stage: .identify,
            updatedAt: created.createdAt.addingTimeInterval(2)
        )
    )
    _ = try await store.transitionInvestigationRun(
        InvestigationRunTransitionCommand(
            investigationID: created.id,
            runID: created.runID,
            expectedRunState: .running,
            runState: .stopRequested,
            sessionState: .stopRequested,
            stage: .verify,
            updatedAt: created.createdAt.addingTimeInterval(3)
        )
    )
    let command = try terminalCommand(
        session: created,
        state: .partial,
        sessionState: .partial,
        reportID: "investigation-report-terminal-atomic",
        cause: .userStopped,
        terminalAt: created.createdAt.addingTimeInterval(4)
    )

    let result = try await store.settleInvestigationTerminal(
        command,
        expectedRunState: .stopRequested,
        maximumDurationNanoseconds: 90_000_000_000
    )
    let replay = try await store.settleInvestigationTerminal(
        command,
        expectedRunState: .stopRequested,
        maximumDurationNanoseconds: 90_000_000_000
    )

    #expect(result == replay)
    #expect(result.investigation.state == .partial)
    #expect(result.report?.id == command.report?.id)
}

@Test
func investigationTerminalSettlementHonorsShorterOuterDeadline()
    async throws
{
    let fixture = try InvestigationStoreV4Fixture()
    let deadline = InvestigationTerminalDeadlineClock()
    let store = try EvidenceStore(
        configuration: .memory,
        testHooks: EvidenceStoreTestHooks(
            monotonicNanoseconds: { deadline.next() },
            isCancelled: { false }
        )
    )
    try await fixture.seed(store)
    let created = try await store.createInvestigation(
        fixture.command(
            investigationID: "investigation-terminal-outer-deadline",
            runID: "investigation-run-terminal-outer-deadline"
        )
    )
    try await enterTerminalBarrier(
        store: store,
        session: created,
        cause: .coverageReached
    )
    let command = try terminalCommand(
        session: created,
        state: .completed,
        sessionState: .completed,
        reportID: "investigation-report-terminal-outer-deadline",
        cause: .coverageReached,
        terminalAt: created.createdAt.addingTimeInterval(4)
    )
    deadline.arm(deadlineNanoseconds: 35_000_000_000)

    await #expect(throws: EvidenceStoreError.operationDeadlineExceeded) {
        _ = try await store.settleInvestigationTerminal(
            command,
            expectedRunState: .terminalBarrier,
            maximumDurationNanoseconds: 35_000_000_000
        )
    }
    #expect(
        try await store.investigation(id: created.id)?.state
            == .terminalBarrier
    )
    #expect(await store.storeHealth() == .ready)
}

@Test
func investigationTerminalRecordsPageWithinExactOwners() async throws {
    let fixture = try InvestigationStoreV4Fixture()
    let store = try EvidenceStore(configuration: .memory)
    try await fixture.seed(store)
    let created = try await store.createInvestigation(
        fixture.command(
            investigationID: "investigation-terminal-paging",
            runID: "investigation-run-terminal-paging"
        )
    )
    try await enterTerminalBarrier(
        store: store,
        session: created,
        cause: .paused
    )
    let command = try terminalCommand(
        session: created,
        state: .partial,
        sessionState: .paused,
        reportID: "investigation-report-terminal-paging",
        cause: .paused,
        terminalAt: fixture.planningAt.addingTimeInterval(45)
    )
    _ = try await store.commitInvestigationTerminal(command)
    let reportID = try #require(command.report?.id)

    let reports = try await store.investigationReports(
        investigationID: created.id,
        runID: created.runID,
        limit: 10,
        offset: 0
    )
    let evidenceOne = try await store.investigationEvidence(
        investigationID: created.id,
        reportID: reportID,
        limit: 1,
        offset: 0
    )
    let evidenceTwo = try await store.investigationEvidence(
        investigationID: created.id,
        reportID: reportID,
        limit: 1,
        offset: 1
    )
    let budgets = try await store.investigationBudgetEvents(
        investigationID: created.id,
        runID: created.runID,
        limit: 10,
        offset: 0
    )

    #expect(reports.records.map(\.id) == [reportID])
    #expect(evidenceOne.records.map(\.ordinal) == [0])
    #expect(evidenceTwo.records.map(\.ordinal) == [1])
    #expect(budgets.records.map(\.ordinal) == [0, 1])
    #expect(reports.corruptRecordIDs.isEmpty)
    #expect(evidenceOne.corruptRecordIDs.isEmpty)
    #expect(evidenceTwo.corruptRecordIDs.isEmpty)
    #expect(budgets.corruptRecordIDs.isEmpty)
}

@Test
func investigationRecoveryPromotionRejoinsAndCommitsRetainedCommand() async throws {
    let root = try EvidenceStoreTestSupport.temporaryDirectory(
        "investigation-recovery-promotion"
    )
    defer { try? FileManager.default.removeItem(at: root) }
    let configuration = try EvidenceStoreTestSupport.makeFileConfiguration(
        root: root
    )
    let fixture = try InvestigationStoreV4Fixture()
    let store = try EvidenceStore(configuration: configuration)
    try await fixture.seed(store)
    let created = try await store.createInvestigation(
        fixture.command(
            investigationID: "investigation-recovery-promotion",
            runID: "investigation-run-recovery-promotion"
        )
    )
    try await enterTerminalBarrier(
        store: store,
        session: created,
        cause: .coverageReached
    )
    let command = try terminalCommand(
        session: created,
        state: .completed,
        sessionState: .completed,
        reportID: "investigation-report-recovery-promotion",
        cause: .coverageReached,
        terminalAt: fixture.planningAt.addingTimeInterval(60)
    )

    let reopened = try EvidenceStore(configuration: configuration)
    let recovered = try await reopened.promoteInvestigationRecovery(command)
    let replay = try await reopened.promoteInvestigationRecovery(command)

    #expect(recovered == replay)
    #expect(recovered.investigation.state == .completed)
    #expect(recovered.report?.id == command.report?.id)
    #expect(
        try await reopened.rejoinInvestigation(
            id: created.id,
            barrier: .recoveryPromotion
        ) == .matching
    )
}

@Test(arguments: InvestigationTerminalRejoinFailure.allCases)
private func investigationTerminalCommitPreservesExactRejoinFailure(
    failure: InvestigationTerminalRejoinFailure
) async throws {
    let fixture = try InvestigationStoreV4Fixture()
    let clock = InvestigationTestWallClock(now: fixture.planningAt)
    let store = try EvidenceStore(
        configuration: .memory,
        testHooks: EvidenceStoreTestHooks(now: { clock.now })
    )
    try await fixture.seed(store)
    let created = try await store.createInvestigation(
        fixture.command(
            investigationID:
                "investigation-terminal-\(failure.rawValue)",
            runID: "investigation-run-terminal-\(failure.rawValue)"
        )
    )
    try await enterTerminalBarrier(
        store: store,
        session: created,
        cause: .coverageReached
    )
    let command = try terminalCommand(
        session: created,
        state: .completed,
        sessionState: .completed,
        reportID: "investigation-report-terminal-\(failure.rawValue)",
        cause: .coverageReached,
        terminalAt: fixture.planningAt.addingTimeInterval(60)
    )

    switch failure {
    case .stale:
        try await store._testReplaceClassificationPayload(
            id: fixture.classification.id,
            payload: String(
                decoding: try DomainJSON.encode(
                    fixture.changedClassification()
                ),
                as: UTF8.self
            )
        )
    case .corrupt:
        try await store._testReplaceClassificationPayload(
            id: fixture.classification.id,
            payload: #"{"corrupt":"classification"}"#
        )
    case .expired:
        clock.now = created.expiresAt
    case .missing:
        try await store.deleteScanSession(id: fixture.session.id)
    }

    await #expect(throws: failure.expectedError) {
        _ = try await store.commitInvestigationTerminal(command)
    }
    #expect(
        try await store._testInvestigationRowCounts(id: created.id)
            == InvestigationStoreRowCounts(
                sessions: 1,
                sourceRows: 5,
                relevanceTokens: 2,
                targets: 2,
                runs: 1,
                runTargets: 2,
                reports: 0,
                evidence: 0,
                degradations: 0,
                budgetEvents: 0
            )
    )
}

private func terminalCommand(
    session: InvestigationStoredSession,
    state: InvestigationRunState,
    sessionState: InvestigationSessionState,
    reportID: String,
    cause: InvestigationTerminalCause,
    terminalAt: Date
) throws -> InvestigationTerminalCommand {
    let targets = session.plan.targets
    return try InvestigationTerminalCommand(
        investigationID: session.id,
        runID: session.runID,
        runState: state,
        sessionState: sessionState,
        stage: .buildPlan,
        cause: cause,
        report: InvestigationTerminalReportInput(
            id: InvestigationReportID(rawValue: reportID)!,
            kind: state == .completed ? .final : .partial,
            payload: try InvestigationReportPayload(
                summary: "Verified terminal advisory"
            ),
            evidence: [
                try InvestigationEvidenceInput(
                    id: InvestigationEvidenceID(
                        rawValue: "investigation-evidence-terminal-000"
                    )!,
                    targetID: targets[0].id,
                    kind: .finding,
                    payload: InvestigationEvidencePayload(
                        summary: "Verified target evidence",
                        confidence: DomainToken(rawValue: "confidence.high")!,
                        uncertainty: "No unresolved material uncertainty",
                        webProvenance: PersistedWebProvenance(
                            sanitizing:
                                "https://docs.example.com/private-token",
                            transport: .publicInternet
                        )
                    )
                ),
                try InvestigationEvidenceInput(
                    id: InvestigationEvidenceID(
                        rawValue: "investigation-evidence-terminal-001"
                    )!,
                    targetID: targets[1].id,
                    kind: .unresolved,
                    payload: InvestigationEvidencePayload(
                        summary: "Target remains unresolved",
                        confidence: DomainToken(rawValue: "confidence.low")!,
                        uncertainty: "Additional retained evidence required"
                    )
                ),
            ],
            degradations: [
                InvestigationDegradationInput(
                    id: InvestigationDegradationID(
                        rawValue: "investigation-degradation-terminal-000"
                    )!,
                    kind: .usageUnavailable,
                    payload: try InvestigationDegradationPayload(
                        reasonKey: DomainToken(
                            rawValue: "usage.unavailable"
                        )!,
                        summary: "Token usage was unavailable"
                    )
                ),
            ]
        ),
        budgetEvents: [
            budgetEvent(
                suffix: "observation",
                ordinal: 0,
                kind: .tokenObservation
            ),
            budgetEvent(
                suffix: "terminal-summary",
                ordinal: 1,
                kind: .terminalSummary
            ),
        ],
        terminalAt: terminalAt
    )
}

private func enterTerminalBarrier(
    store: EvidenceStore,
    session: InvestigationStoredSession,
    cause: InvestigationTerminalCause
) async throws {
    _ = try await store.transitionInvestigationRun(
        InvestigationRunTransitionCommand(
            investigationID: session.id,
            runID: session.runID,
            expectedRunState: .planned,
            runState: .ready,
            sessionState: .ready,
            stage: .prioritize,
            updatedAt: session.createdAt.addingTimeInterval(1)
        )
    )
    _ = try await store.transitionInvestigationRun(
        InvestigationRunTransitionCommand(
            investigationID: session.id,
            runID: session.runID,
            expectedRunState: .ready,
            runState: .running,
            sessionState: .running,
            stage: .identify,
            updatedAt: session.createdAt.addingTimeInterval(2)
        )
    )
    _ = try await store.transitionInvestigationRun(
        InvestigationRunTransitionCommand(
            investigationID: session.id,
            runID: session.runID,
            expectedRunState: .running,
            runState: .terminalBarrier,
            sessionState: .terminalBarrier,
            stage: .verify,
            terminalCause: cause,
            updatedAt: session.createdAt.addingTimeInterval(3)
        )
    )
}

private func budgetEvent(
    suffix: String,
    ordinal: UInt64,
    kind: InvestigationPersistedBudgetEventKind
) -> InvestigationBudgetEventInput {
    InvestigationBudgetEventInput(
        id: InvestigationBudgetEventID(
            rawValue: "investigation-budget-event-\(suffix)"
        )!,
        ordinal: ordinal,
        kind: kind,
        payload: InvestigationBudgetEventPayload(
            dimension: DomainToken(rawValue: "budget.total-tokens"),
            amount: ordinal + 1,
            quality: DomainToken(rawValue: "quality.observed")
        )
    )
}

private final class InvestigationTerminalDeadlineClock:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var deadlineNanoseconds: UInt64?
    private var readCount = 0

    func arm(deadlineNanoseconds: UInt64) {
        lock.withLock {
            self.deadlineNanoseconds = deadlineNanoseconds
            readCount = 0
        }
    }

    func next() -> UInt64 {
        lock.withLock {
            guard let deadlineNanoseconds else {
                return 0
            }
            defer { readCount += 1 }
            return readCount == 0 ? 0 : deadlineNanoseconds
        }
    }
}

private final class InvestigationTestWallClock: @unchecked Sendable {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

private enum InvestigationTerminalRejoinFailure:
    String,
    CaseIterable,
    Sendable
{
    case stale
    case corrupt
    case expired
    case missing

    var expectedError: InvestigationPersistenceError {
        switch self {
        case .stale:
            .sourceStale
        case .corrupt:
            .sourceCorrupt
        case .expired:
            .sourceExpired
        case .missing:
            .sourceMissing
        }
    }
}
