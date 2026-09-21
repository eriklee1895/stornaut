import Foundation

struct InvestigationReportReadSnapshot: Sendable, Equatable {
    public let sourceStatus: InvestigationRejoinResult
    public let plan: InvestigationPlan?
    public let terminalCause: InvestigationTerminalCause?
    public let report: InvestigationStoredReport?
    public let evidence: [InvestigationStoredEvidence]
    public let degradations: [InvestigationStoredDegradation]
    public let budgetEvents: [InvestigationStoredBudgetEvent]
    public let corruptRecordIDs: [String]
}

public struct InvestigationReportReconciliation: Sendable, Equatable {
    public let sourceStatus: InvestigationRejoinResult
    public let report: InvestigationReportProjection?
    public let isolatedRecordIDs: [String]
    public let reviewEligible: Bool
}

public struct InvestigationReportReconciler: Sendable {
    private typealias SnapshotReader = @Sendable (
        InvestigationID,
        InvestigationRunID,
        InvestigationReportID
    ) async throws -> InvestigationReportReadSnapshot

    private let readSnapshot: SnapshotReader

    public init(store: EvidenceStore) {
        readSnapshot = { investigationID, runID, reportID in
            try await store.investigationReportReadSnapshot(
                investigationID: investigationID,
                runID: runID,
                reportID: reportID
            )
        }
    }

    public func reconcile(
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        reportID: InvestigationReportID
    ) async -> InvestigationReportReconciliation {
        do {
            let snapshot = try await readSnapshot(
                investigationID, runID, reportID
            )
            switch snapshot.sourceStatus {
            case .matching, .stale:
                break
            case .expired, .corrupt, .missing:
                return InvestigationReportReconciliation(
                    sourceStatus: snapshot.sourceStatus,
                    report: nil,
                    isolatedRecordIDs: snapshot.corruptRecordIDs,
                    reviewEligible: false
                )
            }
            guard let plan = snapshot.plan,
                  let terminalCause = snapshot.terminalCause,
                  let report = snapshot.report
            else {
                return InvestigationReportReconciliation(
                    sourceStatus: snapshot.sourceStatus,
                    report: nil,
                    isolatedRecordIDs: snapshot.corruptRecordIDs,
                    reviewEligible: false
                )
            }
            let result = InvestigationReportProjection.make(
                report: report,
                plan: plan,
                terminalCause: terminalCause,
                evidence: snapshot.evidence,
                degradations: snapshot.degradations,
                budgetEvents: snapshot.budgetEvents
            )
            let isolated = Set(
                snapshot.corruptRecordIDs + result.isolatedRecordIDs
            ).sorted()
            return InvestigationReportReconciliation(
                sourceStatus: snapshot.sourceStatus,
                report: result.projection,
                isolatedRecordIDs: isolated,
                reviewEligible: snapshot.sourceStatus == .matching
                    && result.reviewEligible
                    && isolated.isEmpty
            )
        } catch {
            return InvestigationReportReconciliation(
                sourceStatus: .corrupt,
                report: nil,
                isolatedRecordIDs: [reportID.rawValue],
                reviewEligible: false
            )
        }
    }
}
