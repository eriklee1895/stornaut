import Foundation
import StornautCore

enum ReviewGroupKind:
    String,
    CaseIterable,
    Sendable,
    Equatable,
    Identifiable
{
    case ready
    case review
    case protected
    case unknown
    case registeredActions

    var id: String { rawValue }

    var titleKey: String {
        "review.group.\(rawValue)"
    }

    var helpKey: String {
        "review.group.\(rawValue).help"
    }
}

enum ReviewPrimaryAction: String, Sendable, Equatable {
    case preflight
    case stopAfterCurrent
    case none
}

struct ReviewRow: Identifiable, Sendable, Equatable {
    let classificationID: ClassificationID
    let planItemID: CleanupPlanItemID?
    let itemName: String
    let relativePath: String
    let producer: DomainLabel?
    let modifiedAt: Date?
    let recoveryCost: RebuildCost?
    let action: ProposedCleanupAction?
    let allocatedBytes: ByteCount?
    let disposition: ReclaimDisposition
    let eligibility: ReviewEligibility
    let reasonKeys: [DomainToken]
    let isSelected: Bool
    let isFocused: Bool
    let isSelectionEnabled: Bool
    let disabledReasonKey: String?

    var id: ClassificationID { classificationID }
}

struct ReviewGroup: Identifiable, Sendable, Equatable {
    let kind: ReviewGroupKind
    let rows: [ReviewRow]

    var id: ReviewGroupKind { kind }
}

struct ReviewSummary: Sendable, Equatable {
    let selectedCount: Int
    let estimatedTrashBytes: ByteCount
    let selectedRegisteredActionCount: Int
    let permanentReleaseBytes: ByteCount
}

enum ReviewInspectorAction: String, Sendable, Equatable {
    case close
}

struct ReviewInspectorModel: Sendable, Equatable {
    let classificationID: ClassificationID
    let itemName: String
    let exactPath: String
    let producer: DomainLabel?
    let modifiedAt: Date?
    let recoveryCost: RebuildCost?
    let disposition: ReclaimDisposition
    let reasonKeys: [DomainToken]
    let supportingEvidence: [EvidenceRecord]
    let missingEvidence: [DomainToken]
    let isSelected: Bool
    let availableActions: [ReviewInspectorAction]

    let hasExecutionAction = false
}

enum ReviewConfirmationAction: String, Sendable, Equatable {
    case cancel
    case confirm
}

struct ReviewConfirmationModel: Sendable, Equatable {
    let itemCount: Int
    let action: ProposedCleanupAction
    let estimatedTrashBytes: ByteCount
    let selectedReviewCount: Int
    let permanentReleaseBytes: ByteCount
    let recoveryCaveatKey: DomainToken
    let availableActions: [ReviewConfirmationAction]
    let canConfirmExecution: Bool

    init(
        snapshot: ReviewSnapshot,
        confirmation: CleanupConfirmation
    ) throws {
        guard confirmation.planID == snapshot.plan.id,
              confirmation.selectionGeneration == snapshot.generation,
              confirmation.orderedItemIDs == snapshot.selectedItemIDs,
              confirmation.itemCount == snapshot.selectedCount,
              confirmation.reviewItemCount
                == snapshot.selectedReviewCount,
              confirmation.allocatedBytes
                == snapshot.selectedAllocatedBytes,
              confirmation.action == .moveToTrash
        else {
            throw ReviewAppContractError.inconsistentProjection
        }
        itemCount = confirmation.itemCount
        action = confirmation.action
        estimatedTrashBytes = confirmation.allocatedBytes
        selectedReviewCount = confirmation.reviewItemCount
        permanentReleaseBytes = ByteCount(0)!
        recoveryCaveatKey = confirmation.recoveryCaveatKey
        canConfirmExecution =
            snapshot.executionAvailability == .debugFake
        availableActions = canConfirmExecution
            ? [.cancel, .confirm]
            : [.cancel]
    }

    static func isValid(
        snapshot: ReviewSnapshot,
        confirmation: CleanupConfirmation
    ) -> Bool {
        (try? ReviewConfirmationModel(
            snapshot: snapshot,
            confirmation: confirmation
        )) != nil
    }
}

struct ReviewStaleModel: Sendable, Equatable {
    let affectedItemIDs: Set<CleanupPlanItemID>
    let affectedItemNames: [String]
    let reasonGroups: Set<CleanupStaleReasonGroup>
    let availableActions: [CleanupStaleAction]

    let hasProceedAnyway = false

    init(
        snapshot: ReviewSnapshot,
        stale: CleanupStaleResult
    ) {
        affectedItemIDs = stale.affectedItemIDs
        reasonGroups = stale.reasonGroups
        availableActions = stale.availableActions
        affectedItemNames = snapshot.plan.items.compactMap { item in
            guard stale.affectedItemIDs.contains(item.id) else {
                return nil
            }
            let path = item.expectedRelativePath?.rawValue ?? item.id.rawValue
            return URL(fileURLWithPath: path).lastPathComponent
        }
    }
}

struct ReviewModel: Sendable, Equatable {
    let phase: ReviewPhase
    let rows: [ReviewRow]
    let groups: [ReviewGroup]
    let summary: ReviewSummary
    let primaryAction: ReviewPrimaryAction
    let primaryActionTitleKey: String
    let inspector: ReviewInspectorModel?
    let confirmation: ReviewConfirmationModel?
    let stale: ReviewStaleModel?
    let progress: ReviewExecutionProgress?
    let reasonKeys: [DomainToken]

    init(
        state: ReviewState,
        pageProjection: QuickScanProjection?
    ) {
        phase = state.phase
        progress = state.progress
        let snapshot = state.snapshot
        let scanFacts = ReviewScanFacts(projection: pageProjection)
        let primaryRootPath = pageProjection?.session.completedScopes
            .first?.rootPath.rawValue
        let itemsByClassification = Dictionary(
            uniqueKeysWithValues: snapshot?.plan.items.map {
                ($0.classificationID, $0)
            } ?? []
        )
        let projectedRows: [ReviewRow]
        if let snapshot {
            projectedRows = snapshot.projection.rows.map { projected in
                let item = itemsByClassification[
                    projected.classificationID
                ]
                let facts = scanFacts[
                    projected.classificationID,
                    projected.snapshotID
                ]
                let enabled = state.phase == .ready
                    && projected.eligibility == .executable
                    && (
                        projected.currentDisposition == .readyToReclaim
                            || projected.currentDisposition
                                == .reviewRecommended
                    )
                return ReviewRow(
                    classificationID: projected.classificationID,
                    planItemID: item?.id,
                    itemName: Self.itemName(
                        projected.relativePath,
                        rootPath: primaryRootPath
                    ),
                    relativePath: projected.relativePath,
                    producer: facts?.classification.producer,
                    modifiedAt: facts?.snapshot.modifiedAt,
                    recoveryCost: facts?.classification.recovery?.cost,
                    action: item?.proposedAction,
                    allocatedBytes: item?.allocatedBytes
                        ?? facts?.snapshot.allocatedByteCount,
                    disposition: projected.currentDisposition,
                    eligibility: projected.eligibility,
                    reasonKeys: projected.reasonKeys,
                    isSelected: item.map {
                        snapshot.selectedItemIDs.contains($0.id)
                    } ?? false,
                    isFocused:
                        snapshot.focusedClassificationID
                            == projected.classificationID,
                    isSelectionEnabled: enabled,
                    disabledReasonKey: Self.disabledReason(
                        row: projected
                    )
                )
            }
        } else {
            projectedRows = []
        }
        rows = projectedRows
        groups = ReviewGroupKind.allCases.map { kind in
            ReviewGroup(
                kind: kind,
                rows: projectedRows.filter { Self.group(for: $0) == kind }
            )
        }
        summary = ReviewSummary(
            selectedCount: snapshot?.selectedCount ?? 0,
            estimatedTrashBytes:
                snapshot?.selectedAllocatedBytes ?? ByteCount(0)!,
            selectedRegisteredActionCount: 0,
            permanentReleaseBytes: ByteCount(0)!
        )
        switch state {
        case .preflighting, .loading:
            primaryAction = .none
        case .executing:
            primaryAction = state.stopAfterCurrentWasRequested
                ? .none
                : .stopAfterCurrent
        case .ready:
            primaryAction = .preflight
        case .idle, .empty, .scanAgain, .unavailable,
             .stale, .confirming, .executionBlocked:
            primaryAction = .none
        }
        primaryActionTitleKey = primaryAction == .stopAfterCurrent
            ? "review.action.stopAfterCurrent"
            : "review.action.moveItemsToTrash"
        if let focused = projectedRows.first(where: \.isFocused) {
            let facts = scanFacts[
                focused.classificationID,
                snapshot?.projection.rows.first {
                    $0.classificationID == focused.classificationID
                }?.snapshotID
            ]
            inspector = ReviewInspectorModel(
                classificationID: focused.classificationID,
                itemName: focused.itemName,
                exactPath: Self.exactPath(
                    rootPath: primaryRootPath,
                    relativePath: focused.relativePath
                ),
                producer: focused.producer,
                modifiedAt: focused.modifiedAt,
                recoveryCost: focused.recoveryCost,
                disposition: focused.disposition,
                reasonKeys: focused.reasonKeys,
                supportingEvidence: facts?.evidence ?? [],
                missingEvidence:
                    facts?.classification.missingEvidenceKeys ?? [],
                isSelected: focused.isSelected,
                availableActions: [.close]
            )
        } else {
            inspector = nil
        }
        if case let .confirming(snapshot, value) = state {
            confirmation = try? ReviewConfirmationModel(
                snapshot: snapshot,
                confirmation: value
            )
        } else {
            confirmation = nil
        }
        if case let .stale(snapshot, value) = state {
            stale = ReviewStaleModel(
                snapshot: snapshot,
                stale: value
            )
        } else {
            stale = nil
        }
        switch state {
        case let .scanAgain(reasons), let .unavailable(reasons):
            reasonKeys = reasons
        default:
            reasonKeys = []
        }
    }

    private static func group(for row: ReviewRow) -> ReviewGroupKind {
        if row.disposition == .protected {
            return .protected
        }
        if row.disposition == .unknown {
            return .unknown
        }
        if row.disposition == .readyToReclaim
            && row.eligibility == .executable
        {
            return .ready
        }
        return .review
    }

    private static func disabledReason(
        row: ReviewProjectionRow
    ) -> String? {
        switch row.eligibility {
        case .executable:
            return nil
        case .noExecutionProfile:
            return "review.disabled.noExecutionProfile"
        case .persistedDispositionBlocked:
            return row.currentDisposition == .protected
                ? "review.disabled.protected"
                : "review.disabled.unknown"
        case .currentEvidenceBlocked:
            return "review.disabled.currentEvidence"
        }
    }

    private static func itemName(
        _ relativePath: String,
        rootPath: String?
    ) -> String {
        if relativePath == ".", let rootPath {
            let rootName = URL(fileURLWithPath: rootPath)
                .lastPathComponent
            return rootName.isEmpty ? rootPath : rootName
        }
        let value = URL(fileURLWithPath: relativePath)
            .lastPathComponent
        return value.isEmpty ? relativePath : value
    }

    private static func exactPath(
        rootPath: String?,
        relativePath: String
    ) -> String {
        guard let rootPath else { return relativePath }
        return URL(fileURLWithPath: rootPath)
            .appending(path: relativePath)
            .standardizedFileURL.path
    }
}

private struct ReviewScanFact: Sendable, Equatable {
    let snapshot: PathSnapshot
    let classification: Classification
    let evidence: [EvidenceRecord]
}

private struct ReviewScanFacts: Sendable {
    private let byClassification:
        [ClassificationID: ReviewScanFact]
    private let bySnapshot: [SnapshotID: ReviewScanFact]

    init(projection: QuickScanProjection?) {
        let snapshots = Dictionary(
            uniqueKeysWithValues: projection?.snapshots.map {
                ($0.id, $0)
            } ?? []
        )
        let evidence = Dictionary(
            grouping: projection?.evidence ?? [],
            by: \.targetID
        )
        let facts = projection?.classifications.compactMap {
            classification -> ReviewScanFact? in
            guard let snapshot = snapshots[classification.snapshotID]
            else {
                return nil
            }
            return ReviewScanFact(
                snapshot: snapshot,
                classification: classification,
                evidence: evidence[snapshot.id, default: []]
            )
        } ?? []
        byClassification = Dictionary(
            uniqueKeysWithValues: facts.map {
                ($0.classification.id, $0)
            }
        )
        bySnapshot = Dictionary(
            uniqueKeysWithValues: facts.map {
                ($0.snapshot.id, $0)
            }
        )
    }

    subscript(
        classificationID: ClassificationID,
        snapshotID: SnapshotID?
    ) -> ReviewScanFact? {
        byClassification[classificationID]
            ?? snapshotID.flatMap { bySnapshot[$0] }
    }
}
