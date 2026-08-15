import Foundation
import Testing
@testable import StornautCore

@Test
func investigationRetentionUsesExactInjectedBoundary() async throws {
    let fixture = try InvestigationStoreV4Fixture()
    let clock = InvestigationTestClock(now: fixture.planningAt)
    let store = try EvidenceStore(
        configuration: .memory,
        testHooks: EvidenceStoreTestHooks(now: { clock.now })
    )
    try await fixture.seed(store)
    let command = fixture.command(
        investigationID: "investigation-retention-boundary",
        runID: "investigation-run-retention-boundary"
    )
    let stored = try await store.createInvestigation(command)

    clock.now = stored.expiresAt.addingTimeInterval(-0.001)
    #expect(
        try await store.rejoinInvestigation(
            id: stored.id,
            barrier: .activeRunRefresh
        ) == .matching
    )
    try await store.expireRecords(now: clock.now)
    #expect(try await store.investigation(id: stored.id) == stored)

    clock.now = stored.expiresAt
    #expect(
        try await store.rejoinInvestigation(
            id: stored.id,
            barrier: .runtimeAdmission
        ) == .expired
    )
    try await store.expireRecords(now: clock.now)
    #expect(try await store.investigation(id: stored.id) == nil)
    #expect(
        try await store._testInvestigationRowCounts(id: stored.id) == .zero
    )
}

@Test
func investigationHistoryPagesUseStableUpdateThenIdentityOrder() async throws {
    let fixture = try InvestigationStoreV4Fixture()
    let store = try EvidenceStore(configuration: .memory)
    try await fixture.seed(store)
    let second = try await store.createInvestigation(
        fixture.command(
            investigationID: "investigation-history-b",
            runID: "investigation-run-history-b"
        )
    )
    let first = try await store.createInvestigation(
        fixture.command(
            investigationID: "investigation-history-a",
            runID: "investigation-run-history-a"
        )
    )

    let pageOne = try await store.investigations(
        limit: 1,
        offset: 0
    )
    let pageTwo = try await store.investigations(
        limit: 1,
        offset: 1
    )

    #expect(pageOne.records == [first])
    #expect(pageTwo.records == [second])
    #expect(pageOne.corruptRecordIDs.isEmpty)
    #expect(pageTwo.corruptRecordIDs.isEmpty)
    await #expect(throws: EvidenceStoreError.invalidPage) {
        _ = try await store.investigations(
            limit: 101,
            offset: 0
        )
    }
}

@Test
func exactInvestigationDeletePreservesSourceAndSibling() async throws {
    let fixture = try InvestigationStoreV4Fixture()
    let store = try EvidenceStore(configuration: .memory)
    try await fixture.seed(store)
    let deleted = try await store.createInvestigation(
        fixture.command(
            investigationID: "investigation-delete-a",
            runID: "investigation-run-delete-a"
        )
    )
    let retained = try await store.createInvestigation(
        fixture.command(
            investigationID: "investigation-delete-b",
            runID: "investigation-run-delete-b"
        )
    )

    #expect(try await store.deleteInvestigation(id: deleted.id))
    #expect(!(try await store.deleteInvestigation(id: deleted.id)))
    #expect(try await store.investigation(id: deleted.id) == nil)
    #expect(try await store.investigation(id: retained.id) == retained)
    #expect(try await store.scanSession(id: fixture.session.id) == fixture.session)
    #expect(
        try await store.pathSnapshots(
            sessionID: fixture.session.id,
            limit: 10,
            offset: 0
        ).records == fixture.snapshots
    )
    #expect(
        try await store._testInvestigationRowCounts(id: deleted.id) == .zero
    )
}

private final class InvestigationTestClock: @unchecked Sendable {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}
