import Darwin
import Foundation
import StornautCore
@testable import StornautApp

enum CleanupResultTestSupport {
    static let createdAt = Date(timeIntervalSince1970: 1_786_600_000)

    enum Scenario {
        case completed
        case partial
        case partialMove
        case failed
        case stopped
        case auditPending
        case outcomeUnknown
    }

    struct Fixture {
        let plan: CleanupPlan
        let executionState: CleanupExecutionState
        let result: CleanupExecutionResult
        let retainedFacts: [CleanupResultItemFacts]
    }

    static func fixture(
        _ scenario: Scenario,
        includesObservation: Bool = true,
        zeroByteItems: Bool = false
    ) throws -> Fixture {
        let plan = try makePlan(zeroByteItems: zeroByteItems)
        return try fixture(
            plan: plan,
            selectedItems: plan.items,
            selectionGeneration: 7,
            selectionFingerprint: DomainToken(
                rawValue: "selection.cleanup-result.fingerprint"
            )!,
            decisions: nil,
            scenario: scenario,
            includesObservation: includesObservation
        )
    }

    static func fixture(
        plan: CleanupPlan,
        selection: ReviewSelection,
        scenario: Scenario,
        includesObservation: Bool = true
    ) throws -> Fixture {
        let selectedItems = selection.items.compactMap { selected in
            plan.items.first { $0.id == selected.itemID }
        }
        guard selectedItems.count == selection.items.count else {
            throw DomainContractError.invalidMeasurement
        }
        let evaluation = try ReviewConfirmationFixture.evaluate(
            plan: plan,
            selection: selection,
            activityFacts: .inactive
        )
        guard let decisions = evaluation.allowed?.decisions else {
            throw DomainContractError.invalidMeasurement
        }
        return try fixture(
            plan: plan,
            selectedItems: selectedItems,
            selectionGeneration: selection.generation,
            selectionFingerprint: selection.fingerprint,
            decisions: decisions,
            scenario: scenario,
            includesObservation: includesObservation
        )
    }

    private static func fixture(
        plan: CleanupPlan,
        selectedItems: [CleanupPlanItem],
        selectionGeneration: UInt64,
        selectionFingerprint: DomainToken,
        decisions: [PolicyDecision]?,
        scenario: Scenario,
        includesObservation: Bool
    ) throws -> Fixture {
        guard !selectedItems.isEmpty else {
            throw DomainContractError.invalidMeasurement
        }
        let specifications = specifications(
            scenario: scenario,
            items: selectedItems
        )
        let records = try specifications.enumerated().map {
            try record(
                specification: $0.element,
                index: $0.offset,
                decision: decisions?[$0.offset]
            )
        }
        let observation = try includesObservation
            ? systemObservation()
            : nil
        let manifest = try CleanupManifest(
            id: CleanupManifestID(
                rawValue: "manifest-cleanup-result-\(scenario.slug)"
            )!,
            planID: plan.id,
            createdAt: createdAt.addingTimeInterval(20),
            expiresAt: createdAt.addingTimeInterval(90 * 86_400),
            records: records,
            summary: CleanupManifestSummary(records: records),
            systemObservation: observation
        )
        let journal = try CleanupRunJournal(
            id: CleanupRunID(
                rawValue: "run-cleanup-result-\(scenario.slug)"
            )!,
            planID: plan.id,
            manifestID: manifest.id,
            selectionGeneration: selectionGeneration,
            selectionFingerprint: selectionFingerprint,
            stage: scenario == .auditPending ? .auditPending : .finalized,
            retentionClass: .audit,
            stopAfterCurrentRequested: scenario == .stopped,
            entries: try zip(specifications, records).map {
                try journalEntry(
                    specification: $0.0,
                    record: $0.1
                )
            },
            createdAt: createdAt,
            updatedAt: createdAt.addingTimeInterval(21),
            expiresAt: createdAt.addingTimeInterval(90 * 86_400),
            manifestCreatedAt: manifest.createdAt,
            systemObservation: observation
        )
        let result = try CleanupExecutionResult(
            journal: journal,
            manifest: manifest
        )
        let state: CleanupExecutionState = switch scenario {
        case .completed:
            .completed(result)
        case .partial, .partialMove, .failed:
            .partiallyFailed(result)
        case .stopped:
            .stopped(result)
        case .auditPending:
            .auditPending(result)
        case .outcomeUnknown:
            .recoveryRequired(result)
        }
        return Fixture(
            plan: plan,
            executionState: state,
            result: result,
            retainedFacts: selectedItems.map {
                let itemName = URL(
                    fileURLWithPath: $0.expectedRelativePath!.rawValue
                ).lastPathComponent
                return CleanupResultItemFacts(
                    planItemID: $0.id,
                    itemName: itemName,
                    exactOriginalPath:
                        "/tmp/stornaut-review-fixture/"
                            + $0.expectedRelativePath!.rawValue,
                    expectedIdentity: $0.expectedIdentity!,
                    evidenceFingerprint: $0.evidenceFingerprint!,
                    producer: DomainLabel(
                        rawValue: itemName
                    ),
                    recoveryDetailKey: DomainToken(
                        rawValue: "cleanup.recovery.trash"
                    )!,
                    evidenceLineage: [
                        DomainToken(
                            rawValue: "cleanup.evidence.rule"
                        )!,
                    ]
                )
            }
        )
    }

    private static func specifications(
        scenario: Scenario,
        items: [CleanupPlanItem]
    ) -> [RecordSpecification] {
        switch scenario {
        case .completed, .auditPending:
            items.map(RecordSpecification.succeeded)
        case .partial:
            items.enumerated().map {
                $0.offset == 0
                    ? .succeeded(item: $0.element)
                    : .failed(item: $0.element)
            }
        case .partialMove:
            items.map(RecordSpecification.partiallyFailed)
        case .failed:
            items.map(RecordSpecification.failed)
        case .stopped:
            items.enumerated().map {
                $0.offset == 0
                    ? .succeeded(item: $0.element)
                    : .cancelled(item: $0.element)
            }
        case .outcomeUnknown:
            items.enumerated().map {
                $0.offset == 0
                    ? .unknown(item: $0.element)
                    : .cancelled(item: $0.element)
            }
        }
    }

    private static func makePlan(
        zeroByteItems: Bool = false
    ) throws -> CleanupPlan {
        let items = try [
            planItem(
                slug: "npm",
                path: ".npm/_cacache",
                inode: 101,
                logicalBytes: zeroByteItems ? 0 : 320_000,
                allocatedBytes: zeroByteItems ? 0 : 300_000
            ),
            planItem(
                slug: "pip",
                path: "Library/Caches/pip",
                inode: 102,
                logicalBytes: zeroByteItems ? 0 : 240_000,
                allocatedBytes: zeroByteItems ? 0 : 200_000
            ),
        ]
        return try CleanupPlan(
            id: CleanupPlanID(rawValue: "plan-cleanup-result-fixture")!,
            scanSessionID: ScanSessionID(
                rawValue: "scan-cleanup-result-fixture"
            )!,
            scanScopeID: ScanScopeID(
                rawValue: "scope-cleanup-result-fixture"
            )!,
            primaryRootIdentity: try identity(
                inode: 100,
                logicalBytes: 0,
                allocatedBytes: 0
            ),
            catalogVersion: DomainToken(
                rawValue: "catalog.cleanup-result"
            )!,
            executionProfileVersion: DomainToken(
                rawValue: "profiles.cleanup-result"
            )!,
            planFingerprint: DomainToken(
                rawValue: "plan.cleanup-result.fingerprint"
            )!,
            createdAt: createdAt,
            expiresAt: createdAt.addingTimeInterval(7 * 86_400),
            items: items
        )
    }

    private static func planItem(
        slug: String,
        path: String,
        inode: UInt64,
        logicalBytes: UInt64,
        allocatedBytes: UInt64
    ) throws -> CleanupPlanItem {
        let identity = try identity(
            inode: inode,
            logicalBytes: logicalBytes,
            allocatedBytes: allocatedBytes
        )
        return try CleanupPlanItem(
            id: CleanupPlanItemID(
                rawValue: "plan-item-cleanup-result-\(slug)"
            )!,
            snapshotID: SnapshotID(
                rawValue: "snapshot-cleanup-result-\(slug)"
            )!,
            classificationID: ClassificationID(
                rawValue: "classification-cleanup-result-\(slug)"
            )!,
            ruleID: DomainToken(rawValue: "cache.\(slug)")!,
            executionProfileID: DomainToken(
                rawValue: "profile.cleanup-result.\(slug)"
            )!,
            proposedAction: .moveToTrash,
            expectedRelativePath: PersistedPath(rawValue: path)!,
            expectedIdentity: identity,
            logicalBytes: ByteCount(logicalBytes)!,
            allocatedBytes: ByteCount(allocatedBytes)!,
            evidenceFingerprint: DomainToken(
                rawValue: "evidence.cleanup-result.\(slug)"
            )!,
            activityFingerprint: DomainToken(
                rawValue: "activity.cleanup-result.\(slug)"
            )!
        )
    }

    private static func identity(
        inode: UInt64,
        logicalBytes: UInt64,
        allocatedBytes: UInt64
    ) throws -> FileIdentity {
        try FileIdentity(
            device: 301,
            inode: inode,
            mode: UInt16(S_IFDIR | 0o700),
            ownerUserID: 501,
            ownerGroupID: 20,
            size: Int64(logicalBytes),
            allocatedBytes: Int64(allocatedBytes),
            modificationSeconds: 1_786_599_900,
            modificationNanoseconds: 123
        )
    }

    private static func record(
        specification: RecordSpecification,
        index: Int,
        decision: PolicyDecision?
    ) throws -> CleanupManifestRecord {
        let item = specification.item
        return try CleanupManifestRecord(
            actionID: CleanupActionID(
                rawValue: "action-cleanup-result-\(index)"
            )!,
            planItemID: item.id,
            policyDecisionID: decision?.id
                ?? PolicyDecisionID(
                    rawValue: "decision-cleanup-result-\(index)"
                )!,
            policyDisposition:
                decision?.disposition ?? .readyToReclaim,
            policyReasonKeys: decision?.reasonKeys ?? [
                DomainToken(rawValue: "policy.profile.allowed")!,
            ],
            action: .moveToTrash,
            result: specification.result,
            recovery: specification.recovery,
            measures: try measures(for: specification),
            startedAt: specification.startedAt,
            finishedAt: specification.finishedAt,
            error: specification.error
        )
    }

    private static func journalEntry(
        specification: RecordSpecification,
        record: CleanupManifestRecord
    ) throws -> CleanupRunJournalEntry {
        let item = specification.item
        let destination = specification.recovery == .movedToTrash
            ? item.expectedIdentity
            : nil
        return try CleanupRunJournalEntry(
            actionID: record.actionID,
            planItemID: item.id,
            policyDecisionID: record.policyDecisionID!,
            policyDisposition: record.policyDisposition,
            policyReasonKeys: record.policyReasonKeys,
            action: record.action,
            expectedIdentity: item.expectedIdentity!,
            actionFingerprint: DomainToken(
                rawValue: "action.cleanup-result.fingerprint"
            )!,
            state: specification.result == .cancelled
                ? .cancelled
                : .outcomeRecorded,
            startedAt: specification.startedAt,
            outcome: CleanupJournalOutcome(
                result: specification.result,
                recovery: specification.recovery,
                measures: record.measures,
                destinationIdentity: destination,
                error: specification.error,
                finishedAt:
                    specification.finishedAt
                        ?? createdAt.addingTimeInterval(15)
            )
        )
    }

    private static func measures(
        for specification: RecordSpecification
    ) throws -> CleanupManifestMeasures {
        let item = specification.item
        let logical = item.logicalBytes!
        let allocated = item.allocatedBytes!
        let processed: Bool = switch specification.result {
        case .succeeded:
            true
        case .failed, .cancelled, .outcomeUnknown:
            false
        case .partiallyFailed:
            true
        }
        let moved = specification.recovery == .movedToTrash
        return try CleanupManifestMeasures(
            candidateLogicalBytes: logical,
            candidateAllocatedBytes: allocated,
            processedLogicalBytes: processed ? logical : ByteCount(0)!,
            processedAllocatedBytes:
                processed ? allocated : ByteCount(0)!,
            movedToTrashLogicalBytes:
                moved ? logical : ByteCount(0)!,
            movedToTrashAllocatedBytes:
                moved ? allocated : ByteCount(0)!,
            permanentlyReleasedLogicalBytes: ByteCount(0)!,
            permanentlyReleasedAllocatedBytes: ByteCount(0)!
        )
    }

    private static func systemObservation()
        throws -> ManifestSystemObservation
    {
        try ManifestSystemObservation(
            source: DomainToken(rawValue: "system.volume.home")!,
            freeBytesBefore: ByteCount(10_000_000)!,
            sampledBeforeAt: createdAt.addingTimeInterval(1),
            freeBytesAfter: ByteCount(10_350_000)!,
            sampledAfterAt: createdAt.addingTimeInterval(19),
            freeSpaceDelta: SignedByteDelta(350_000),
            unexplainedDelta: SignedByteDelta(350_000)
        )
    }
}

private struct RecordSpecification {
    let item: CleanupPlanItem
    let result: ManifestActionResult
    let recovery: CleanupRecoveryState
    let startedAt: Date?
    let finishedAt: Date?
    let error: CleanupManifestError?

    static func succeeded(item: CleanupPlanItem) -> Self {
        Self(
            item: item,
            result: .succeeded,
            recovery: .movedToTrash,
            startedAt: CleanupResultTestSupport.createdAt
                .addingTimeInterval(10),
            finishedAt: CleanupResultTestSupport.createdAt
                .addingTimeInterval(11),
            error: nil
        )
    }

    static func failed(item: CleanupPlanItem) -> Self {
        Self(
            item: item,
            result: .failed,
            recovery: .originalConfirmed,
            startedAt: CleanupResultTestSupport.createdAt
                .addingTimeInterval(12),
            finishedAt: CleanupResultTestSupport.createdAt
                .addingTimeInterval(13),
            error: CleanupManifestError(
                stage: .moveToTrash,
                code: DomainToken(rawValue: "trash.destination.unavailable")!
            )
        )
    }

    static func partiallyFailed(item: CleanupPlanItem) -> Self {
        Self(
            item: item,
            result: .partiallyFailed,
            recovery: .movedToTrash,
            startedAt: CleanupResultTestSupport.createdAt
                .addingTimeInterval(10),
            finishedAt: CleanupResultTestSupport.createdAt
                .addingTimeInterval(13),
            error: CleanupManifestError(
                stage: .postflight,
                code: DomainToken(rawValue: "cleanup.postflight.partial")!
            )
        )
    }

    static func cancelled(item: CleanupPlanItem) -> Self {
        Self(
            item: item,
            result: .cancelled,
            recovery: .notStarted,
            startedAt: nil,
            finishedAt: nil,
            error: nil
        )
    }

    static func unknown(item: CleanupPlanItem) -> Self {
        Self(
            item: item,
            result: .outcomeUnknown,
            recovery: .outcomeUnknown,
            startedAt: CleanupResultTestSupport.createdAt
                .addingTimeInterval(12),
            finishedAt: CleanupResultTestSupport.createdAt
                .addingTimeInterval(13),
            error: CleanupManifestError(
                stage: .crashRecovery,
                code: DomainToken(rawValue: "cleanup.recovery.unknown")!
            )
        )
    }
}

private extension CleanupResultTestSupport.Scenario {
    var slug: String {
        switch self {
        case .completed:
            "completed"
        case .partial:
            "partial"
        case .partialMove:
            "partial-move"
        case .failed:
            "failed"
        case .stopped:
            "stopped"
        case .auditPending:
            "audit-pending"
        case .outcomeUnknown:
            "outcome-unknown"
        }
    }
}
