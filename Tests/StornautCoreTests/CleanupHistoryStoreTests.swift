import Foundation
import Testing
@testable import StornautCore

@Test
func cleanupHistoryJoinsOnlyRetainedExactlyBoundPlanFacts() async throws {
    let store = try EvidenceStore(configuration: .memory)
    let plan = try CleanupPersistenceTestSupport.plan()
    let manifest = try CleanupPersistenceTestSupport.manifest(plan: plan)
    let session: ScanSession = try EvidenceStoreTestSupport.fixture(
        ScanSession.self,
        name: "scan-session-v1"
    )
    try await store.saveScanSession(session)
    try await store.saveCleanupPlan(plan)
    try await store.saveCleanupManifest(manifest)

    let retained = try await store.cleanupManifestHistory(
        limit: 10,
        offset: 0,
        now: manifest.createdAt
    )
    let retainedRecord = try #require(retained.records.first)
    #expect(retainedRecord.manifest == manifest)
    #expect(retainedRecord.evidenceAvailability == .retained)
    #expect(retainedRecord.linkedPlan == plan)
    #expect(retained.corruptManifestIDs.isEmpty)

    try await store.clearEvidence()

    let expired = try await store.cleanupManifestHistory(
        limit: 10,
        offset: 0,
        now: manifest.createdAt.addingTimeInterval(8 * 86_400)
    )
    let expiredRecord = try #require(expired.records.first)
    #expect(expiredRecord.manifest == manifest)
    #expect(expiredRecord.evidenceAvailability == .expired)
    #expect(expiredRecord.linkedPlan == nil)
}

@Test
func cleanupHistoryPagesUseStableTimestampThenIdentityOrder() async throws {
    let store = try EvidenceStore(configuration: .memory)
    let plan = try CleanupPersistenceTestSupport.plan()
    let original = try CleanupPersistenceTestSupport.manifest(plan: plan)
    let first = try relabelManifest(original, id: "manifest-a")
    let second = try relabelManifest(original, id: "manifest-b")
    try await store.saveCleanupManifest(second)
    try await store.saveCleanupManifest(first)

    let pageOne = try await store.cleanupManifestHistory(
        limit: 1,
        offset: 0,
        now: original.createdAt
    )
    let pageTwo = try await store.cleanupManifestHistory(
        limit: 1,
        offset: 1,
        now: original.createdAt
    )

    #expect(pageOne.records.map(\.manifest.id.rawValue) == ["manifest-a"])
    #expect(pageTwo.records.map(\.manifest.id.rawValue) == ["manifest-b"])
}

@Test
func cleanupHistoryIsolatesCorruptManifestWithoutHidingHealthyPages()
    async throws
{
    let store = try EvidenceStore(configuration: .memory)
    let plan = try CleanupPersistenceTestSupport.plan()
    let original = try CleanupPersistenceTestSupport.manifest(plan: plan)
    let first = try relabelManifest(original, id: "manifest-healthy-a")
    let second = try relabelManifest(original, id: "manifest-healthy-b")
    try await store.saveCleanupManifest(first)
    try await store._testInsertMalformedCleanupManifest(
        id: "manifest-corrupt",
        planID: plan.id,
        createdAt: original.createdAt,
        expiresAt: original.expiresAt,
        payload: "{not-json"
    )
    try await store.saveCleanupManifest(second)

    let firstPage = try await store.cleanupManifestHistory(
        limit: 2,
        offset: 0,
        now: original.createdAt
    )
    let secondPage = try await store.cleanupManifestHistory(
        limit: 2,
        offset: 2,
        now: original.createdAt
    )

    #expect(firstPage.records.map(\.manifest.id.rawValue)
        == ["manifest-healthy-a"])
    #expect(firstPage.corruptManifestIDs == ["manifest-corrupt"])
    #expect(secondPage.records.map(\.manifest.id.rawValue)
        == ["manifest-healthy-b"])
    #expect(secondPage.corruptManifestIDs.isEmpty)
}

@Test
func cleanupHistoryRetentionRemainsSchemaV3AndIndependentFromEvidence()
    async throws
{
    let store = try EvidenceStore(configuration: .memory)
    let plan = try CleanupPersistenceTestSupport.plan()
    let manifest = try CleanupPersistenceTestSupport.manifest(plan: plan)
    let session: ScanSession = try EvidenceStoreTestSupport.fixture(
        ScanSession.self,
        name: "scan-session-v1"
    )
    try await store.saveScanSession(session)
    try await store.saveCleanupPlan(plan)
    try await store.saveCleanupManifest(manifest)

    try await store.expireRecords(
        now: max(
            plan.expiresAt,
            session.finishedAt.addingTimeInterval(7 * 86_400)
        ).addingTimeInterval(1)
    )

    #expect(try await store.diagnostics().schemaVersion == 3)
    #expect(try await store.cleanupPlan(id: plan.id) == nil)
    #expect(try await store.scanSession(id: session.id) == nil)
    #expect(try await store.cleanupManifest(id: manifest.id) == manifest)
    #expect(
        try await store.cleanupManifestHistory(
            limit: 10,
            offset: 0,
            now: manifest.createdAt.addingTimeInterval(8 * 86_400)
        ).records.first?.evidenceAvailability == .expired
    )
}

@Test
func clearManifestsDeletesManifestPendingAuditJournal() async throws {
    let store = try EvidenceStore(configuration: .memory)
    let originalPlan = try CleanupPersistenceTestSupport.plan()
    let plan = try CleanupPersistenceTestSupport.plan(
        items: [
            originalPlan.items[0],
        ]
    )
    let session: ScanSession = try EvidenceStoreTestSupport.fixture(
        ScanSession.self,
        name: "scan-session-v1"
    )
    let decision = try CleanupPersistenceTestSupport.decision(
        plan: plan,
        item: plan.items[0]
    )
    let prepared = try CleanupPersistenceTestSupport.journal(
        plan: plan,
        entries: [
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[0],
                decision: decision
            ),
        ]
    )
    let started = try CleanupPersistenceTestSupport.journal(
        plan: plan,
        stage: .actionStarted,
        entries: [
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[0],
                state: .started,
                decision: decision
            ),
        ]
    )
    let outcome = try CleanupPersistenceTestSupport.journal(
        plan: plan,
        stage: .actionOutcomeRecorded,
        entries: [
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[0],
                state: .outcomeRecorded,
                decision: decision
            ),
        ]
    )
    let pending = try CleanupPersistenceTestSupport.journal(
        plan: plan,
        stage: .manifestPending,
        entries: [
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[0],
                state: .outcomeRecorded
            ),
        ]
    )
    try await store.saveScanSession(session)
    try await store.saveCleanupPlan(plan)
    try await store.savePolicyDecision(decision)
    try await store.saveCleanupRunJournal(prepared)
    try await store.saveCleanupRunJournal(started)
    try await store.saveCleanupRunJournal(outcome)
    try await store.saveCleanupRunJournal(pending)

    try await store.clearManifests()

    #expect(try await store.cleanupRunJournal(id: pending.id) == nil)
    #expect(try await store.cleanupPlan(id: plan.id) == plan)
}

@Test
func deletingManifestAtomicallyRemovesOnlyItsExactAuditJournal()
    async throws
{
    let store = try EvidenceStore(configuration: .memory)
    let plan = try CleanupPersistenceTestSupport.plan()
    let manifest = try CleanupPersistenceTestSupport.manifest(plan: plan)
    let session: ScanSession = try EvidenceStoreTestSupport.fixture(
        ScanSession.self,
        name: "scan-session-v1"
    )
    let decisions = try plan.items.map {
        try CleanupPersistenceTestSupport.decision(plan: plan, item: $0)
    }
    try await store.saveScanSession(session)
    try await store.saveCleanupPlan(plan)
    for decision in decisions {
        try await store.savePolicyDecision(decision)
    }
    let prepared = try CleanupPersistenceTestSupport.journal(plan: plan)
    let firstStarted = try CleanupPersistenceTestSupport.journal(
        plan: plan,
        stage: .actionStarted,
        entries: [
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[0],
                state: .started,
                decision: decisions[0]
            ),
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[1],
                decision: decisions[1]
            ),
        ]
    )
    let firstOutcome = try CleanupPersistenceTestSupport.journal(
        plan: plan,
        stage: .actionOutcomeRecorded,
        entries: [
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[0],
                state: .outcomeRecorded,
                decision: decisions[0]
            ),
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[1],
                decision: decisions[1]
            ),
        ]
    )
    let secondStarted = try journal(
        firstOutcome,
        stage: .actionStarted,
        entries: [
            firstOutcome.entries[0],
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[1],
                state: .started,
                decision: decisions[1]
            ),
        ]
    )
    let secondOutcome = try journal(
        secondStarted,
        stage: .actionOutcomeRecorded,
        entries: [
            secondStarted.entries[0],
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[1],
                state: .outcomeRecorded,
                decision: decisions[1]
            ),
        ]
    )
    let pending = try auditJournal(
        secondOutcome,
        manifest: manifest,
        stage: .manifestPending,
        entries: secondOutcome.entries
    )
    let finalized = try auditJournal(
        pending,
        manifest: manifest,
        stage: .finalized,
        entries: pending.entries
    )
    try await store.saveCleanupRunJournal(prepared)
    try await store.saveCleanupRunJournal(firstStarted)
    try await store.saveCleanupRunJournal(firstOutcome)
    try await store.saveCleanupRunJournal(secondStarted)
    try await store.saveCleanupRunJournal(secondOutcome)
    try await store.saveCleanupRunJournal(pending)
    try await store.saveCleanupRunJournal(finalized)
    try await store.saveCleanupManifest(manifest)

    let deleted = try await store.deleteCleanupManifest(id: manifest.id)

    #expect(deleted)
    #expect(try await store.cleanupManifest(id: manifest.id) == nil)
    #expect(try await store.cleanupRunJournal(id: finalized.id) == nil)
    #expect(try await store.cleanupPlan(id: plan.id) == plan)
    #expect(try await store.scanSession(id: session.id) == session)
}

@Test
func deletingManifestFailsClosedWhenSamePlanJournalCannotBeBound()
    async throws
{
    let store = try EvidenceStore(configuration: .memory)
    let plan = try CleanupPersistenceTestSupport.plan()
    let manifest = try CleanupPersistenceTestSupport.manifest(plan: plan)
    try await store.saveCleanupManifest(manifest)
    try await store._testInsertMalformedCleanupJournal(
        id: "run-malformed-same-plan",
        planID: plan.id,
        payload: "{not-json"
    )

    await #expect(throws: EvidenceStoreError.recordIdentityMismatch) {
        try await store.deleteCleanupManifest(id: manifest.id)
    }
    #expect(try await store.cleanupManifest(id: manifest.id) == manifest)
}

@Test
func scanDeletionNeverDeletesRetainedManifest() async throws {
    let store = try EvidenceStore(configuration: .memory)
    let plan = try CleanupPersistenceTestSupport.plan()
    let manifest = try CleanupPersistenceTestSupport.manifest(plan: plan)
    let session: ScanSession = try EvidenceStoreTestSupport.fixture(
        ScanSession.self,
        name: "scan-session-v1"
    )
    try await store.saveScanSession(session)
    try await store.saveCleanupPlan(plan)
    try await store.saveCleanupManifest(manifest)

    try await store.deleteScanSession(id: session.id)

    #expect(try await store.scanSession(id: session.id) == nil)
    #expect(try await store.cleanupManifest(id: manifest.id) == manifest)
}

private func relabelManifest(
    _ manifest: CleanupManifest,
    id: String
) throws -> CleanupManifest {
    try CleanupManifest(
        id: CleanupManifestID(rawValue: id)!,
        planID: manifest.planID,
        createdAt: manifest.createdAt,
        expiresAt: manifest.expiresAt,
        records: manifest.records,
        summary: manifest.summary,
        systemObservation: manifest.systemObservation
    )
}

private func auditJournal(
    _ previous: CleanupRunJournal,
    manifest: CleanupManifest,
    stage: CleanupRunJournalStage,
    entries: [CleanupRunJournalEntry]
) throws -> CleanupRunJournal {
    try CleanupRunJournal(
        id: previous.id,
        planID: previous.planID,
        manifestID: manifest.id,
        selectionGeneration: previous.selectionGeneration,
        selectionFingerprint: previous.selectionFingerprint,
        stage: stage,
        retentionClass: .audit,
        stopAfterCurrentRequested: previous.stopAfterCurrentRequested,
        entries: entries,
        createdAt: previous.createdAt,
        updatedAt: previous.updatedAt.addingTimeInterval(
            stage == .manifestPending ? 1 : 2
        ),
        expiresAt: previous.createdAt.addingTimeInterval(90 * 86_400),
        manifestCreatedAt: manifest.createdAt,
        systemObservation: manifest.systemObservation
    )
}

private func journal(
    _ previous: CleanupRunJournal,
    stage: CleanupRunJournalStage,
    entries: [CleanupRunJournalEntry]
) throws -> CleanupRunJournal {
    try CleanupRunJournal(
        id: previous.id,
        planID: previous.planID,
        manifestID: previous.manifestID,
        selectionGeneration: previous.selectionGeneration,
        selectionFingerprint: previous.selectionFingerprint,
        stage: stage,
        retentionClass: .audit,
        stopAfterCurrentRequested: previous.stopAfterCurrentRequested,
        entries: entries,
        createdAt: previous.createdAt,
        updatedAt: previous.updatedAt.addingTimeInterval(1),
        expiresAt: previous.createdAt.addingTimeInterval(90 * 86_400)
    )
}
