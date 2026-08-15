import Foundation
import Testing
@testable import StornautCore

@Test
func investigationContinuationUsesPersistedUnresolvedSubsetAndReplays() async throws {
    let fixture = try InvestigationStoreV4Fixture()
    let clock = InvestigationSourceRejoinWallClock(now: fixture.planningAt)
    let store = try EvidenceStore(
        configuration: .memory,
        testHooks: EvidenceStoreTestHooks(now: { clock.now })
    )
    try await fixture.seed(store)
    let parent = try await store.createInvestigation(
        fixture.command(
            investigationID: "investigation-continuation-success",
            runID: "investigation-run-continuation-parent"
        )
    )
    let parentPlan = parent.plan
    let reportID = try await persistPartialParent(
        store: store,
        session: parent,
        terminalAt: fixture.planningAt.addingTimeInterval(4)
    )
    let command = try InvestigationContinuationCommand(
        investigationID: parent.id,
        parentRunID: parent.runID,
        parentReportID: reportID,
        newRunID: InvestigationRunID(
            rawValue: "investigation-run-continuation-child"
        )!,
        budgetPreset: .balanced,
        planningAt: fixture.planningAt.addingTimeInterval(5)
    )

    let child = try await store.createInvestigationContinuation(command)
    let replay = try await store.createInvestigationContinuation(command)
    let reloadedParentPlan = try await store._testInvestigationRunPlan(
        investigationID: parent.id,
        runID: parent.runID
    )

    #expect(child == replay)
    #expect(child.runID == command.newRunID)
    #expect(child.plan.budgetPreset == .balanced)
    #expect(child.plan.targets.map(\.id) == [parent.plan.targets[1].id])
    #expect(reloadedParentPlan == parentPlan)
    #expect(
        try await store._testInvestigationRowCounts(id: parent.id)
            == InvestigationStoreRowCounts(
                sessions: 1,
                sourceRows: 5,
                relevanceTokens: 2,
                targets: 2,
                runs: 2,
                runTargets: 3,
                reports: 1,
                evidence: 1,
                degradations: 0,
                budgetEvents: 1
            )
    )

    let conflicting = try InvestigationContinuationCommand(
        investigationID: parent.id,
        parentRunID: parent.runID,
        parentReportID: reportID,
        newRunID: command.newRunID,
        budgetPreset: .thorough,
        planningAt: command.planningAt
    )
    await #expect(throws: InvestigationPersistenceError.conflictingReplay) {
        _ = try await store.createInvestigationContinuation(conflicting)
    }
}

@Test
func investigationContinuationReplayStillRequiresFreshSource() async throws {
    let fixture = try InvestigationStoreV4Fixture()
    let store = try EvidenceStore(configuration: .memory)
    try await fixture.seed(store)
    let parent = try await store.createInvestigation(
        fixture.command(
            investigationID: "investigation-continuation-replay-drift",
            runID: "investigation-run-continuation-replay-drift"
        )
    )
    let reportID = try await persistPartialParent(
        store: store,
        session: parent,
        terminalAt: fixture.planningAt.addingTimeInterval(4)
    )
    let command = try InvestigationContinuationCommand(
        investigationID: parent.id,
        parentRunID: parent.runID,
        parentReportID: reportID,
        newRunID: InvestigationRunID(
            rawValue: "investigation-run-continuation-replay-drift-child"
        )!,
        budgetPreset: .focused,
        planningAt: fixture.planningAt.addingTimeInterval(5)
    )
    _ = try await store.createInvestigationContinuation(command)

    try await store._testReplaceClassificationPayload(
        id: fixture.classification.id,
        payload: String(
            decoding: try DomainJSON.encode(
                fixture.changedClassification()
            ),
            as: UTF8.self
        )
    )

    await #expect(throws: InvestigationPersistenceError.sourceStale) {
        _ = try await store.createInvestigationContinuation(command)
    }
}

@Test
func investigationContinuationReplayUsesCurrentExpiryBoundary() async throws {
    let fixture = try InvestigationStoreV4Fixture()
    let clock = InvestigationSourceRejoinWallClock(now: fixture.planningAt)
    let store = try EvidenceStore(
        configuration: .memory,
        testHooks: EvidenceStoreTestHooks(now: { clock.now })
    )
    try await fixture.seed(store)
    let parent = try await store.createInvestigation(
        fixture.command(
            investigationID: "investigation-continuation-replay-expiry",
            runID: "investigation-run-continuation-replay-expiry"
        )
    )
    let reportID = try await persistPartialParent(
        store: store,
        session: parent,
        terminalAt: fixture.planningAt.addingTimeInterval(4)
    )
    let command = try InvestigationContinuationCommand(
        investigationID: parent.id,
        parentRunID: parent.runID,
        parentReportID: reportID,
        newRunID: InvestigationRunID(
            rawValue: "investigation-run-continuation-replay-expiry-child"
        )!,
        budgetPreset: .focused,
        planningAt: fixture.planningAt.addingTimeInterval(5)
    )
    let child = try await store.createInvestigationContinuation(command)
    clock.now = child.expiresAt

    await #expect(throws: InvestigationPersistenceError.sourceExpired) {
        _ = try await store.createInvestigationContinuation(command)
    }
}

@Test
func investigationRecoveryCandidatesAreBoundedAndExpireExactly() async throws {
    let fixture = try InvestigationStoreV4Fixture()
    let store = try EvidenceStore(configuration: .memory)
    try await fixture.seed(store)
    let created = try await store.createInvestigation(
        fixture.command(
            investigationID: "investigation-recovery-candidate",
            runID: "investigation-run-recovery-candidate"
        )
    )

    let beforeExpiry = try await store.investigationRecoveryCandidates(
        now: created.expiresAt.addingTimeInterval(-0.001),
        limit: 1,
        offset: 0
    )
    let atExpiry = try await store.investigationRecoveryCandidates(
        now: created.expiresAt,
        limit: 1,
        offset: 0
    )

    #expect(beforeExpiry.records.count == 1)
    #expect(beforeExpiry.records.first?.investigationID == created.id)
    #expect(beforeExpiry.records.first?.runID == created.runID)
    #expect(beforeExpiry.records.first?.state == .planned)
    #expect(beforeExpiry.corruptRecordIDs.isEmpty)
    #expect(atExpiry.records.isEmpty)
    #expect(atExpiry.corruptRecordIDs.isEmpty)
}

@Test
func investigationContinuationRejectsSourceDriftAndExactExpiry() async throws {
    let fixture = try InvestigationStoreV4Fixture()
    let store = try EvidenceStore(configuration: .memory)
    try await fixture.seed(store)
    let driftParent = try await store.createInvestigation(
        fixture.command(
            investigationID: "investigation-continuation-drift",
            runID: "investigation-run-continuation-drift"
        )
    )
    let driftReportID = try await persistPartialParent(
        store: store,
        session: driftParent,
        terminalAt: fixture.planningAt.addingTimeInterval(4)
    )
    try await store._testReplaceClassificationPayload(
        id: fixture.classification.id,
        payload: String(
            decoding: try DomainJSON.encode(
                fixture.changedClassification()
            ),
            as: UTF8.self
        )
    )
    let driftCommand = try InvestigationContinuationCommand(
        investigationID: driftParent.id,
        parentRunID: driftParent.runID,
        parentReportID: driftReportID,
        newRunID: InvestigationRunID(
            rawValue: "investigation-run-continuation-drift-child"
        )!,
        budgetPreset: .focused,
        planningAt: fixture.planningAt.addingTimeInterval(5)
    )
    await #expect(throws: InvestigationPersistenceError.sourceStale) {
        _ = try await store.createInvestigationContinuation(driftCommand)
    }

    let expiryFixture = try InvestigationStoreV4Fixture()
    let expiryClock = InvestigationSourceRejoinWallClock(
        now: expiryFixture.planningAt
    )
    let expiryStore = try EvidenceStore(
        configuration: .memory,
        testHooks: EvidenceStoreTestHooks(now: { expiryClock.now })
    )
    try await expiryFixture.seed(expiryStore)
    let expiryParent = try await expiryStore.createInvestigation(
        expiryFixture.command(
            investigationID: "investigation-continuation-expiry",
            runID: "investigation-run-continuation-expiry"
        )
    )
    let expiryReportID = try await persistPartialParent(
        store: expiryStore,
        session: expiryParent,
        terminalAt: expiryFixture.planningAt.addingTimeInterval(4)
    )
    let expiryCommand = try InvestigationContinuationCommand(
        investigationID: expiryParent.id,
        parentRunID: expiryParent.runID,
        parentReportID: expiryReportID,
        newRunID: InvestigationRunID(
            rawValue: "investigation-run-continuation-expiry-child"
        )!,
        budgetPreset: .focused,
        planningAt: expiryParent.expiresAt
    )
    expiryClock.now = expiryParent.expiresAt
    await #expect(throws: InvestigationPersistenceError.sourceExpired) {
        _ = try await expiryStore.createInvestigationContinuation(
            expiryCommand
        )
    }
}

private func persistPartialParent(
    store: EvidenceStore,
    session: InvestigationStoredSession,
    terminalAt: Date
) async throws -> InvestigationReportID {
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
            terminalCause: .paused,
            updatedAt: session.createdAt.addingTimeInterval(3)
        )
    )
    let reportID = InvestigationReportID(
        rawValue:
            "investigation-report-\(session.id.rawValue.suffix(48))"
    )!
    let command = try InvestigationTerminalCommand(
        investigationID: session.id,
        runID: session.runID,
        runState: .partial,
        sessionState: .partial,
        stage: .buildPlan,
        cause: .paused,
        report: InvestigationTerminalReportInput(
            id: reportID,
            kind: .partial,
            payload: try InvestigationReportPayload(
                summary: "Partial retained investigation"
            ),
            evidence: [
                InvestigationEvidenceInput(
                    id: InvestigationEvidenceID(
                        rawValue:
                            "investigation-evidence-\(session.id.rawValue.suffix(48))"
                    )!,
                    targetID: session.plan.targets[1].id,
                    kind: .unresolved,
                    payload: try InvestigationEvidencePayload(
                        summary: "Target remains unresolved",
                        confidence: DomainToken(
                            rawValue: "confidence.low"
                        )!,
                        uncertainty: "Continuation is required"
                    )
                ),
            ],
            degradations: []
        ),
        budgetEvents: [
            InvestigationBudgetEventInput(
                id: InvestigationBudgetEventID(
                    rawValue:
                        "investigation-budget-event-\(session.id.rawValue.suffix(48))"
                )!,
                ordinal: 0,
                kind: .terminalSummary,
                payload: InvestigationBudgetEventPayload(
                    dimension: DomainToken(
                        rawValue: "budget.total-tokens"
                    ),
                    amount: 1,
                    quality: DomainToken(rawValue: "quality.observed")
                )
            ),
        ],
        terminalAt: terminalAt
    )
    _ = try await store.commitInvestigationTerminal(command)
    return reportID
}

private final class InvestigationSourceRejoinWallClock:
    @unchecked Sendable
{
    var now: Date

    init(now: Date) {
        self.now = now
    }
}
