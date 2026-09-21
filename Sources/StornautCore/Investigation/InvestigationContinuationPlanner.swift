import Foundation

public struct InvestigationContinuationPlanner: Sendable {
    typealias ContinuationSource = @Sendable (
        InvestigationContinuationCommand
    ) async throws -> InvestigationStoredSession

    private let continuationSource: ContinuationSource

    init(
        continuationSource: @escaping ContinuationSource
    ) {
        self.continuationSource = continuationSource
    }

    public init(store: EvidenceStore) {
        continuationSource = { command in
            try await store.createInvestigationContinuation(command)
        }
    }

    public func create(
        investigationID: InvestigationID,
        parentRunID: InvestigationRunID,
        parentReportID: InvestigationReportID,
        newRunID: InvestigationRunID,
        budgetPreset: InvestigationBudgetPreset,
        planningAt: Date
    ) async throws -> InvestigationStoredSession {
        let command = try InvestigationContinuationCommand(
            investigationID: investigationID,
            parentRunID: parentRunID,
            parentReportID: parentReportID,
            newRunID: newRunID,
            budgetPreset: budgetPreset,
            planningAt: planningAt
        )
        return try await continuationSource(command)
    }
}
