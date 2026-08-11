import Darwin
import Foundation
@testable import StornautCore

enum CleanupPersistenceTestSupport {
    static let createdAt = Date(timeIntervalSince1970: 1_786_500_000)
    static let updatedAt = createdAt.addingTimeInterval(5)

    static func identity(
        inode: UInt64,
        size: Int64 = 4_096,
        allocatedBytes: Int64 = 8_192
    ) throws -> FileIdentity {
        try FileIdentity(
            device: 101,
            inode: inode,
            mode: UInt16(S_IFDIR | 0o700),
            ownerUserID: 501,
            ownerGroupID: 20,
            size: size,
            allocatedBytes: allocatedBytes,
            modificationSeconds: 1_786_499_900,
            modificationNanoseconds: 123
        )
    }

    static func planItem(
        slug: String,
        relativePath: String,
        inode: UInt64,
        disposition: ReclaimDisposition = .readyToReclaim
    ) throws -> CleanupPlanItem {
        _ = disposition
        return try CleanupPlanItem(
            id: CleanupPlanItemID(rawValue: "plan-item-\(slug)")!,
            snapshotID: SnapshotID(rawValue: "snapshot-\(slug)")!,
            classificationID: ClassificationID(
                rawValue: "classification-\(slug)"
            )!,
            ruleID: DomainToken(rawValue: "cache.\(slug)")!,
            executionProfileID: DomainToken(
                rawValue: "profile.phase-c.\(slug)"
            )!,
            proposedAction: .moveToTrash,
            expectedRelativePath: PersistedPath(rawValue: relativePath)!,
            expectedIdentity: try identity(
                inode: inode,
                size: 8_388_608,
                allocatedBytes: 7_340_032
            ),
            logicalBytes: ByteCount(8_388_608)!,
            allocatedBytes: ByteCount(7_340_032)!,
            evidenceFingerprint: DomainToken(
                rawValue: "evidence.\(slug).fingerprint"
            )!,
            activityFingerprint: DomainToken(
                rawValue: "activity.\(slug).fingerprint"
            )!
        )
    }

    static func plan(
        items: [CleanupPlanItem]? = nil
    ) throws -> CleanupPlan {
        try CleanupPlan(
            id: CleanupPlanID(rawValue: "plan-phase-c-fixture")!,
            scanSessionID: ScanSessionID(
                rawValue: "scan-fixture-cancelled"
            )!,
            scanScopeID: ScanScopeID(rawValue: "scope-fixture-caches")!,
            primaryRootIdentity: try identity(inode: 1),
            catalogVersion: DomainToken(rawValue: "catalog.phase-c-v1")!,
            executionProfileVersion: DomainToken(
                rawValue: "profile.phase-c-v1"
            )!,
            planFingerprint: DomainToken(
                rawValue: "plan.phase-c.fingerprint"
            )!,
            createdAt: createdAt,
            expiresAt: createdAt.addingTimeInterval(7 * 86_400),
            items: try items ?? [
                planItem(
                    slug: "npm",
                    relativePath: ".npm/_cacache",
                    inode: 11
                ),
                planItem(
                    slug: "pip",
                    relativePath: "Library/Caches/pip",
                    inode: 12
                ),
            ]
        )
    }

    static func decision(
        plan: CleanupPlan,
        item: CleanupPlanItem,
        outcome: PolicyDecisionOutcome = .allowed,
        disposition: ReclaimDisposition = .readyToReclaim,
        selectionOrigin: CleanupSelectionOrigin = .defaultReady
    ) throws -> PolicyDecision {
        try PolicyDecision(
            id: PolicyDecisionID(
                rawValue: "decision-\(item.id.rawValue)"
            )!,
            planID: plan.id,
            itemID: item.id,
            outcome: outcome,
            disposition: disposition,
            selectionGeneration: 3,
            selectionOrigin: selectionOrigin,
            planFingerprint: plan.planFingerprint!,
            decisionFingerprint: DomainToken(
                rawValue: "decision.\(item.id.rawValue).fingerprint"
            )!,
            reasonKeys: [
                DomainToken(rawValue: "policy.profile.allowed")!,
            ],
            evaluatedAt: updatedAt
        )
    }

    static func measures(
        movedLogical: UInt64 = 8_388_608,
        movedAllocated: UInt64 = 7_340_032,
        processedLogical: UInt64 = 8_388_608,
        processedAllocated: UInt64 = 7_340_032,
        permanent: UInt64 = 0
    ) throws -> CleanupManifestMeasures {
        try CleanupManifestMeasures(
            candidateLogicalBytes: ByteCount(8_388_608)!,
            candidateAllocatedBytes: ByteCount(7_340_032)!,
            processedLogicalBytes: ByteCount(processedLogical)!,
            processedAllocatedBytes: ByteCount(processedAllocated)!,
            movedToTrashLogicalBytes: ByteCount(movedLogical)!,
            movedToTrashAllocatedBytes: ByteCount(movedAllocated)!,
            permanentlyReleasedLogicalBytes: ByteCount(permanent)!,
            permanentlyReleasedAllocatedBytes: ByteCount(permanent)!
        )
    }

    static func manifestRecord(
        plan: CleanupPlan,
        item: CleanupPlanItem,
        decision: PolicyDecision,
        actionID: String = "action-phase-c-001"
    ) throws -> CleanupManifestRecord {
        try CleanupManifestRecord(
            actionID: CleanupActionID(rawValue: actionID)!,
            planItemID: item.id,
            policyDecisionID: decision.id,
            policyDisposition: decision.disposition,
            policyReasonKeys: decision.reasonKeys,
            action: .moveToTrash,
            result: .succeeded,
            recovery: .movedToTrash,
            measures: try measures(),
            startedAt: updatedAt,
            finishedAt: updatedAt.addingTimeInterval(1),
            error: nil
        )
    }

    static func manifest(
        plan: CleanupPlan? = nil
    ) throws -> CleanupManifest {
        let plan = try plan ?? self.plan()
        let item = plan.items[0]
        let decision = try decision(plan: plan, item: item)
        let record = try manifestRecord(
            plan: plan,
            item: item,
            decision: decision
        )
        return try CleanupManifest(
            id: CleanupManifestID(rawValue: "manifest-phase-c-fixture")!,
            planID: plan.id,
            createdAt: updatedAt.addingTimeInterval(2),
            expiresAt: updatedAt.addingTimeInterval(90 * 86_400),
            records: [record],
            summary: try CleanupManifestSummary(records: [record]),
            systemObservation: nil
        )
    }

    static func journalEntry(
        item: CleanupPlanItem,
        state: CleanupJournalEntryState = .prepared,
        decision: PolicyDecision? = nil
    ) throws -> CleanupRunJournalEntry {
        let decision = try decision ?? self.decision(
            plan: plan(items: [item]),
            item: item
        )
        let outcome: CleanupJournalOutcome?
        switch state {
        case .prepared, .started:
            outcome = nil
        case .outcomeRecorded:
            outcome = try CleanupJournalOutcome(
                result: .succeeded,
                recovery: .movedToTrash,
                measures: measures(),
                destinationIdentity: identity(inode: 500),
                error: nil,
                finishedAt: updatedAt.addingTimeInterval(1)
            )
        case .cancelled:
            outcome = try CleanupJournalOutcome(
                result: .cancelled,
                recovery: .notStarted,
                measures: CleanupManifestMeasures(
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
                finishedAt: updatedAt.addingTimeInterval(1)
            )
        }
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
            state: state,
            startedAt: state == .started || state == .outcomeRecorded
                ? updatedAt
                : nil,
            outcome: outcome
        )
    }

    static func journal(
        plan: CleanupPlan? = nil,
        stage: CleanupRunJournalStage = .prepared,
        entries: [CleanupRunJournalEntry]? = nil
    ) throws -> CleanupRunJournal {
        let plan = try plan ?? self.plan()
        let entries = try entries ?? plan.items.map {
            try journalEntry(item: $0)
        }
        let retentionClass: CleanupJournalRetentionClass =
            stage == .prepared ? .evidenceLinked : .audit
        let maximumDays = retentionClass == .evidenceLinked ? 7 : 90
        let updateOffset: TimeInterval
        switch stage {
        case .prepared:
            updateOffset = 0
        case .actionStarted:
            updateOffset = 1
        case .actionOutcomeRecorded:
            updateOffset = 2
        case .manifestPending:
            updateOffset = 3
        case .auditPending:
            updateOffset = 4
        case .finalized:
            updateOffset = 5
        }
        return try CleanupRunJournal(
            id: CleanupRunID(rawValue: "run-phase-c-fixture")!,
            planID: plan.id,
            manifestID: CleanupManifestID(
                rawValue: "manifest-phase-c-fixture"
            )!,
            selectionGeneration: 3,
            selectionFingerprint: DomainToken(
                rawValue: "selection.phase-c.fingerprint"
            )!,
            stage: stage,
            retentionClass: retentionClass,
            stopAfterCurrentRequested: false,
            entries: entries,
            createdAt: createdAt,
            updatedAt: updatedAt.addingTimeInterval(updateOffset),
            expiresAt: createdAt.addingTimeInterval(
                Double(maximumDays * 86_400)
            )
        )
    }
}
