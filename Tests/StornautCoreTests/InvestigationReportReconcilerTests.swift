import Foundation
import Testing
@testable import StornautCore

@Suite("Investigation report reconciliation")
struct InvestigationReportReconcilerTests {
    @Test
    func currentAndStaleSourcesPreserveTruthWithoutUnsafeReview_BitsUT() async throws {
        let fixture = try InvestigationStoreV4Fixture()
        let clock = InvestigationReportProjectionClock(now: fixture.planningAt)
        let store = try EvidenceStore(
            configuration: .memory,
            testHooks: EvidenceStoreTestHooks(now: { clock.now })
        )
        try await fixture.seed(store)
        let session = try await store.createInvestigation(
            fixture.command(
                investigationID: "investigation-report-reconcile",
                runID: "investigation-run-report-reconcile"
            )
        )
        let reportID = try await persistProjectedReport(
            store: store, session: session
        )
        let reconciler = InvestigationReportReconciler(store: store)

        let current = await reconciler.reconcile(
            investigationID: session.id,
            runID: session.runID,
            reportID: reportID
        )
        #expect(current.sourceStatus == .matching)
        #expect(current.report?.id == reportID)
        #expect(current.reviewEligible)

        let foreign = await reconciler.reconcile(
            investigationID: session.id,
            runID: InvestigationRunID(
                rawValue: "investigation-run-report-foreign"
            )!,
            reportID: reportID
        )
        #expect(foreign.sourceStatus == .missing)
        #expect(foreign.report == nil)
        #expect(!foreign.reviewEligible)

        try await store._testReplaceClassificationPayload(
            id: fixture.classification.id,
            payload: String(
                decoding: try DomainJSON.encode(
                    fixture.changedClassification()
                ),
                as: UTF8.self
            )
        )
        let stale = await reconciler.reconcile(
            investigationID: session.id,
            runID: session.runID,
            reportID: reportID
        )
        #expect(stale.sourceStatus == .stale)
        #expect(stale.report?.id == reportID)
        #expect(!stale.reviewEligible)
    }

    @Test
    func exactExpiryAndMissingIdentityRemainDistinct_BitsUT() async throws {
        let fixture = try InvestigationStoreV4Fixture()
        let clock = InvestigationReportProjectionClock(now: fixture.planningAt)
        let store = try EvidenceStore(
            configuration: .memory,
            testHooks: EvidenceStoreTestHooks(now: { clock.now })
        )
        try await fixture.seed(store)
        let session = try await store.createInvestigation(
            fixture.command(
                investigationID: "investigation-report-expiry",
                runID: "investigation-run-report-expiry"
            )
        )
        let reportID = try await persistProjectedReport(
            store: store, session: session
        )
        let reconciler = InvestigationReportReconciler(store: store)
        clock.now = session.expiresAt

        let expired = await reconciler.reconcile(
            investigationID: session.id,
            runID: session.runID,
            reportID: reportID
        )
        #expect(expired.sourceStatus == .expired)
        #expect(expired.report == nil)
        #expect(!expired.reviewEligible)

        let missing = await reconciler.reconcile(
            investigationID: InvestigationID(
                rawValue: "investigation-report-missing"
            )!,
            runID: InvestigationRunID(
                rawValue: "investigation-run-report-missing"
            )!,
            reportID: InvestigationReportID(
                rawValue: "investigation-report-missing"
            )!
        )
        #expect(missing.sourceStatus == .missing)
        #expect(missing.report == nil)
        #expect(!missing.reviewEligible)
    }
}

private func persistProjectedReport(
    store: EvidenceStore,
    session: InvestigationStoredSession
) async throws -> InvestigationReportID {
    _ = try await store.transitionInvestigationRun(
        InvestigationRunTransitionCommand(
            investigationID: session.id, runID: session.runID,
            expectedRunState: .planned, runState: .ready,
            sessionState: .ready, stage: .prioritize,
            updatedAt: session.createdAt.addingTimeInterval(1)
        )
    )
    _ = try await store.transitionInvestigationRun(
        InvestigationRunTransitionCommand(
            investigationID: session.id, runID: session.runID,
            expectedRunState: .ready, runState: .running,
            sessionState: .running, stage: .identify,
            updatedAt: session.createdAt.addingTimeInterval(2)
        )
    )
    _ = try await store.transitionInvestigationRun(
        InvestigationRunTransitionCommand(
            investigationID: session.id, runID: session.runID,
            expectedRunState: .running, runState: .terminalBarrier,
            sessionState: .terminalBarrier, stage: .verify,
            terminalCause: .paused,
            updatedAt: session.createdAt.addingTimeInterval(3)
        )
    )
    let reportID = InvestigationReportID(
        rawValue: "investigation-report-reconciled"
    )!
    _ = try await store.commitInvestigationTerminal(
        try InvestigationTerminalCommand(
            investigationID: session.id, runID: session.runID,
            runState: .partial, sessionState: .partial,
            stage: .buildPlan, cause: .paused,
            report: InvestigationTerminalReportInput(
                id: reportID, kind: .partial,
                payload: try InvestigationReportPayload(
                    summary: "Retained partial report"
                ),
                evidence: [
                    InvestigationEvidenceInput(
                        id: InvestigationEvidenceID(
                            rawValue: "investigation-evidence-reconciled"
                        )!,
                        targetID: session.plan.targets[0].id,
                        kind: .finding,
                        payload: try InvestigationEvidencePayload(
                            summary: "Bounded finding",
                            advisoryID: DomainToken(rawValue: "finding-a"),
                            sourceLabel: DomainToken(
                                rawValue: "source.probeBroker"
                            ),
                            confidence: DomainToken(
                                rawValue: "confidence.high"
                            )!,
                            uncertainty: "No material uncertainty"
                        )
                    ),
                    InvestigationEvidenceInput(
                        id: InvestigationEvidenceID(
                            rawValue: "investigation-evidence-reconciled-unresolved"
                        )!,
                        targetID: session.plan.targets[1].id,
                        kind: .unresolved,
                        payload: try InvestigationEvidencePayload(
                            summary: "Target remains unresolved",
                            advisoryID: DomainToken(
                                rawValue: session.plan.targets[1].id.rawValue
                            ),
                            sourceLabel: DomainToken(
                                rawValue: "source.unresolved"
                            ),
                            confidence: DomainToken(
                                rawValue: "confidence.low"
                            )!,
                            uncertainty: "Additional evidence is required"
                        )
                    ),
                ],
                degradations: []
            ),
            budgetEvents: [
                InvestigationBudgetEventInput(
                    id: InvestigationBudgetEventID(
                        rawValue: "investigation-budget-event-reconciled"
                    )!,
                    ordinal: 0, kind: .terminalSummary,
                    payload: InvestigationBudgetEventPayload(
                        dimension: DomainToken(
                            rawValue: "budget.total-tokens"
                        ),
                        amount: 1,
                        quality: DomainToken(rawValue: "quality.observed")
                    )
                ),
            ],
            terminalAt: session.createdAt.addingTimeInterval(4)
        )
    )
    return reportID
}

private final class InvestigationReportProjectionClock:
    @unchecked Sendable
{
    var now: Date

    init(now: Date) {
        self.now = now
    }
}
