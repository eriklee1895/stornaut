import Foundation
import Testing
@testable import StornautCore

@Suite("Investigation continuation planner")
struct InvestigationContinuationPlannerTests {
    @Test
    func typedRequestDelegatesToStoreOwnedContinuation_BitsUT() async throws {
        let fixture = try InvestigationReportProjectionFixture()
        let requests = InvestigationContinuationRequestLog()
        let expected = InvestigationStoredSession(
            id: fixture.plan.id,
            runID: InvestigationRunID(
                rawValue: "investigation-run-continuation-child"
            )!,
            plan: fixture.plan, state: .planned, stage: .prioritize,
            sourceRowCount: 1, relevanceTokenCount: 1,
            createdAt: fixture.createdAt, updatedAt: fixture.createdAt,
            expiresAt: fixture.plan.expiresAt
        )
        let planner = InvestigationContinuationPlanner { request in
            requests.record(request)
            return expected
        }

        let result = try await planner.create(
            investigationID: fixture.plan.id,
            parentRunID: fixture.runID,
            parentReportID: fixture.reportID,
            newRunID: expected.runID,
            budgetPreset: .balanced,
            planningAt: fixture.createdAt
        )

        #expect(result == expected)
        let request = try #require(requests.values.first)
        #expect(requests.values.count == 1)
        #expect(request.investigationID == fixture.plan.id)
        #expect(request.parentRunID == fixture.runID)
        #expect(request.parentReportID == fixture.reportID)
        #expect(request.newRunID == expected.runID)
        #expect(request.budgetPreset == .balanced)
        #expect(request.planningAt == fixture.createdAt)
    }

    @Test
    func sameRunIdentityFailsBeforeStoreCall_BitsUT() async throws {
        let fixture = try InvestigationReportProjectionFixture()
        let requests = InvestigationContinuationRequestLog()
        let planner = InvestigationContinuationPlanner { request in
            requests.record(request)
            throw InvestigationPersistenceError.invalidCommand
        }

        await #expect(throws: InvestigationPersistenceDomainError.self) {
            _ = try await planner.create(
                investigationID: fixture.plan.id,
                parentRunID: fixture.runID,
                parentReportID: fixture.reportID,
                newRunID: fixture.runID,
                budgetPreset: .focused,
                planningAt: fixture.createdAt
            )
        }
        #expect(requests.values.isEmpty)
    }
}

private final class InvestigationContinuationRequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [InvestigationContinuationCommand] = []

    var values: [InvestigationContinuationCommand] {
        lock.withLock { storage }
    }

    func record(_ value: InvestigationContinuationCommand) {
        lock.withLock { storage.append(value) }
    }
}
