import Foundation
import Testing
@testable import StornautCore

@Test
func phaseCOneHundredItemPolicyAuthorizationAndAuditStayBounded()
    async throws
{
    let now = CleanupPersistenceTestSupport.createdAt
        .addingTimeInterval(10)
    let items = try (0..<100).map { index in
        try CleanupPersistenceTestSupport.planItem(
            slug: "benchmark-\(index)",
            relativePath: "Library/Caches/phase-c-benchmark-\(index)",
            inode: UInt64(10_000 + index)
        )
    }
    let plan = try CleanupPersistenceTestSupport.plan(items: items)
    let selection = try ReviewSelection(
        plan: plan,
        generation: 3,
        items: items.map {
            ReviewSelectionItem(
                itemID: $0.id,
                origin: .explicitUser
            )
        },
        dispositions: Dictionary(
            uniqueKeysWithValues: items.map {
                ($0.id, ReclaimDisposition.readyToReclaim)
            }
        )
    )
    let context = try CleanupPolicyContext(
        capturedAt: now,
        planID: plan.id,
        scanSessionID: plan.scanSessionID,
        scanScopeID: plan.scanScopeID!,
        scanIsTerminal: true,
        planFingerprint: plan.planFingerprint!,
        selectionGeneration: selection.generation,
        selectionFingerprint: selection.fingerprint,
        rootIdentity: plan.primaryRootIdentity!,
        catalogVersion: plan.catalogVersion!,
        executionProfileVersion: plan.executionProfileVersion!,
        workflow: .available,
        items: try items.map(phaseCBenchmarkContext)
    )

    let policyStarted = ContinuousClock.now
    let evaluation = try CleanupPolicyGate().evaluate(
        plan: plan,
        selection: selection,
        context: context,
        evaluatedAt: now
    )
    let policyElapsed = policyStarted.duration(to: .now)
    let allowed = try #require(evaluation.allowed)
    #expect(allowed.decisions.count == 100)
    #expect(policyElapsed < .seconds(2))

    let collected = CleanupPolicyCollectedContext(
        policyContext: context,
        rootURL: URL(filePath: "/tmp/stornaut-phase-c-benchmark"),
        rootAccess: .direct
    )
    let controller = CleanupAuthorizationController(now: { now })
    let authorizationStarted = ContinuousClock.now
    let authorization = try await controller.issue(
        evaluation: evaluation,
        confirmation: allowed.confirmation,
        collectedContext: collected
    )
    _ = try await controller.admit(
        authorization,
        confirmation: allowed.confirmation,
        workflow: .available
    )
    let authorizationElapsed = authorizationStarted.duration(to: .now)
    #expect(authorizationElapsed < .milliseconds(50))

    let journal = try phaseCBenchmarkFinalizedJournal(
        plan: plan,
        selection: selection,
        decisions: allowed.decisions,
        createdAt: now
    )
    let manifest = try CleanupAccounting().manifest(
        journal: journal,
        volumeBefore: nil,
        volumeAfter: nil,
        createdAt: try #require(journal.manifestCreatedAt)
    )
    let journalData = try DomainJSON.encode(journal)
    let manifestData = try DomainJSON.encode(manifest)

    #expect(journal.entries.count == 100)
    #expect(manifest.records.count == 100)
    #expect(journalData.count < 1_048_576)
    #expect(manifestData.count < 1_048_576)
    #expect(
        manifest.summary.permanentlyReleasedLogicalBytes
            == ByteCount(0)
    )
}

private func phaseCBenchmarkContext(
    _ item: CleanupPlanItem
) throws -> CleanupPolicyItemContext {
    try CleanupPolicyItemContext(
        itemID: item.id,
        snapshotID: item.snapshotID,
        classificationID: item.classificationID,
        ruleID: item.ruleID!,
        executionProfileID: item.executionProfileID!,
        proposedAction: item.proposedAction,
        persistedDisposition: .readyToReclaim,
        currentDisposition: .readyToReclaim,
        expectedRelativePath: item.expectedRelativePath!,
        currentRelativePath: item.expectedRelativePath!,
        expectedIdentity: item.expectedIdentity!,
        currentIdentity: item.expectedIdentity!,
        evidenceFingerprint: item.evidenceFingerprint!,
        currentEvidenceFingerprint: item.evidenceFingerprint!,
        activityFingerprint: item.activityFingerprint!,
        currentActivityFingerprint: item.activityFingerprint!,
        pathFacts: .allowed,
        evidenceFacts: .current,
        activityFacts: .inactive
    )
}

private func phaseCBenchmarkFinalizedJournal(
    plan: CleanupPlan,
    selection: ReviewSelection,
    decisions: [PolicyDecision],
    createdAt: Date
) throws -> CleanupRunJournal {
    let decisionsByItem = Dictionary(
        uniqueKeysWithValues: decisions.map { ($0.itemID, $0) }
    )
    let finishedAt = createdAt.addingTimeInterval(1)
    let manifestCreatedAt = createdAt.addingTimeInterval(2)
    let entries = try plan.items.map { item in
        let decision = try #require(decisionsByItem[item.id])
        let measures = try CleanupManifestMeasures(
            candidateLogicalBytes: item.logicalBytes!,
            candidateAllocatedBytes: item.allocatedBytes!,
            processedLogicalBytes: item.logicalBytes!,
            processedAllocatedBytes: item.allocatedBytes!,
            movedToTrashLogicalBytes: item.logicalBytes!,
            movedToTrashAllocatedBytes: item.allocatedBytes!,
            permanentlyReleasedLogicalBytes: ByteCount(0)!,
            permanentlyReleasedAllocatedBytes: ByteCount(0)!
        )
        return try CleanupRunJournalEntry(
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
            state: .outcomeRecorded,
            startedAt: createdAt,
            outcome: CleanupJournalOutcome(
                result: .succeeded,
                recovery: .movedToTrash,
                measures: measures,
                destinationIdentity: item.expectedIdentity,
                error: nil,
                finishedAt: finishedAt
            )
        )
    }
    return try CleanupRunJournal(
        id: CleanupRunID(rawValue: "run-phase-c-benchmark")!,
        planID: plan.id,
        manifestID: CleanupManifestID(
            rawValue: "manifest-phase-c-benchmark"
        )!,
        selectionGeneration: selection.generation,
        selectionFingerprint: selection.fingerprint,
        stage: .finalized,
        retentionClass: .audit,
        stopAfterCurrentRequested: false,
        entries: entries,
        createdAt: createdAt,
        updatedAt: manifestCreatedAt,
        expiresAt: createdAt.addingTimeInterval(90 * 86_400),
        manifestCreatedAt: manifestCreatedAt,
        systemObservation: nil
    )
}
