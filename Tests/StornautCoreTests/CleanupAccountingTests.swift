import Foundation
import Testing
@testable import StornautCore

@Test
func cleanupAccountingDerivesManifestOnlyFromTerminalJournal() throws {
    let plan = try CleanupPersistenceTestSupport.plan()
    let firstDecision = try CleanupPersistenceTestSupport.decision(
        plan: plan,
        item: plan.items[0]
    )
    let secondDecision = try CleanupPersistenceTestSupport.decision(
        plan: plan,
        item: plan.items[1]
    )
    let journal = try CleanupRunJournal(
        id: CleanupRunID(rawValue: "run-accounting")!,
        planID: plan.id,
        manifestID: CleanupManifestID(rawValue: "manifest-accounting")!,
        selectionGeneration: 3,
        selectionFingerprint: DomainToken(
            rawValue: "selection.accounting.fingerprint"
        )!,
        stage: .manifestPending,
        retentionClass: .audit,
        stopAfterCurrentRequested: false,
        entries: [
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[0],
                state: .outcomeRecorded,
                decision: firstDecision
            ),
            try cancelledAccountingEntry(
                item: plan.items[1],
                decision: secondDecision
            ),
        ],
        createdAt: CleanupPersistenceTestSupport.createdAt,
        updatedAt: CleanupPersistenceTestSupport.updatedAt
            .addingTimeInterval(3),
        expiresAt: CleanupPersistenceTestSupport.createdAt
            .addingTimeInterval(90 * 86_400)
    )
    let before = try CleanupVolumeSample(
        device: 101,
        freeBytes: ByteCount(1_000)!,
        source: DomainToken(rawValue: "foundation.volume")!,
        sampledAt: CleanupPersistenceTestSupport.createdAt
    )
    let after = try CleanupVolumeSample(
        device: 101,
        freeBytes: ByteCount(1_100)!,
        source: DomainToken(rawValue: "foundation.volume")!,
        sampledAt: CleanupPersistenceTestSupport.updatedAt
    )

    let manifest = try CleanupAccounting().manifest(
        journal: journal,
        volumeBefore: before,
        volumeAfter: after,
        createdAt: CleanupPersistenceTestSupport.updatedAt
            .addingTimeInterval(4)
    )

    #expect(manifest.records.map(\.result) == [.succeeded, .cancelled])
    #expect(manifest.summary.succeededCount == 1)
    #expect(manifest.summary.cancelledCount == 1)
    #expect(
        manifest.summary.permanentlyReleasedLogicalBytes == ByteCount(0)
    )
    #expect(manifest.systemObservation?.freeSpaceDelta == SignedByteDelta(100))
    #expect(manifest.systemObservation?.unexplainedDelta
        == SignedByteDelta(100))
}

@Test
func cleanupAccountingKeepsOutcomesWhenVolumeSamplingIsUnavailable() throws {
    let plan = try CleanupPersistenceTestSupport.plan(
        items: [
            CleanupPersistenceTestSupport.planItem(
                slug: "accounting-single",
                relativePath: "Library/Caches/accounting-single",
                inode: 700
            ),
        ]
    )
    let decision = try CleanupPersistenceTestSupport.decision(
        plan: plan,
        item: plan.items[0]
    )
    let journal = try CleanupRunJournal(
        id: CleanupRunID(rawValue: "run-accounting-no-volume")!,
        planID: plan.id,
        manifestID: CleanupManifestID(
            rawValue: "manifest-accounting-no-volume"
        )!,
        selectionGeneration: 3,
        selectionFingerprint: DomainToken(
            rawValue: "selection.accounting-no-volume.fingerprint"
        )!,
        stage: .manifestPending,
        retentionClass: .audit,
        stopAfterCurrentRequested: false,
        entries: [
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[0],
                state: .outcomeRecorded,
                decision: decision
            ),
        ],
        createdAt: CleanupPersistenceTestSupport.createdAt,
        updatedAt: CleanupPersistenceTestSupport.updatedAt
            .addingTimeInterval(3),
        expiresAt: CleanupPersistenceTestSupport.createdAt
            .addingTimeInterval(90 * 86_400)
    )

    let manifest = try CleanupAccounting().manifest(
        journal: journal,
        volumeBefore: nil,
        volumeAfter: nil,
        createdAt: CleanupPersistenceTestSupport.updatedAt
            .addingTimeInterval(4)
    )

    #expect(manifest.records.count == 1)
    #expect(manifest.records[0].result == .succeeded)
    #expect(manifest.systemObservation == nil)
}

@Test
func manifestSystemObservationRejectsContradictoryUnexplainedDelta() {
    #expect(throws: DomainContractError.invalidMeasurement) {
        _ = try ManifestSystemObservation(
            source: DomainToken(rawValue: "foundation.volume")!,
            freeBytesBefore: ByteCount(1_000)!,
            sampledBeforeAt: CleanupPersistenceTestSupport.createdAt,
            freeBytesAfter: ByteCount(1_100)!,
            sampledAfterAt: CleanupPersistenceTestSupport.updatedAt,
            freeSpaceDelta: SignedByteDelta(100),
            unexplainedDelta: SignedByteDelta(-900)
        )
    }
}

@Test
func foundationCleanupVolumeSamplerReadsOnlyTheSelectedVolume() throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "stornaut-volume-sample-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: root) }
    let sampledAt = CleanupPersistenceTestSupport.createdAt

    let sample = try FoundationCleanupVolumeSampler().sample(
        rootURL: root,
        sampledAt: sampledAt
    )

    #expect(sample.sampledAt == sampledAt)
    #expect(sample.freeBytes.value > 0)
    #expect(
        sample.source.rawValue
            == "foundation.volume-available-capacity"
    )
    #expect(FileManager.default.fileExists(atPath: root.path))
}

private func cancelledAccountingEntry(
    item: CleanupPlanItem,
    decision: PolicyDecision
) throws -> CleanupRunJournalEntry {
    try CleanupRunJournalEntry(
        actionID: CleanupActionID(
            rawValue: "action-\(item.id.rawValue)"
        )!,
        planItemID: item.id,
        policyDecisionID: decision.id,
        policyDisposition: decision.disposition,
        policyReasonKeys: decision.reasonKeys,
        action: item.proposedAction,
        expectedIdentity: item.expectedIdentity!,
        actionFingerprint: DomainToken(
            rawValue: "action.\(item.id.rawValue).fingerprint"
        )!,
        state: .cancelled,
        startedAt: nil,
        outcome: CleanupJournalOutcome(
            result: .cancelled,
            recovery: .notStarted,
            measures: try CleanupManifestMeasures(
                candidateLogicalBytes: item.logicalBytes!,
                candidateAllocatedBytes: item.allocatedBytes!,
                processedLogicalBytes: ByteCount(0)!,
                processedAllocatedBytes: ByteCount(0)!,
                movedToTrashLogicalBytes: ByteCount(0)!,
                movedToTrashAllocatedBytes: ByteCount(0)!,
                permanentlyReleasedLogicalBytes: ByteCount(0)!,
                permanentlyReleasedAllocatedBytes: ByteCount(0)!
            ),
            destinationIdentity: nil,
            error: nil,
            finishedAt: CleanupPersistenceTestSupport.updatedAt
        )
    )
}
