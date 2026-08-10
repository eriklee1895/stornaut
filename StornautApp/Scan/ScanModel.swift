import Foundation
import StornautCore

enum ScanPresentation: String, Sendable, Equatable {
    case idle
    case active
    case stopping
    case completed
    case partial
    case cancelled
    case limitedPermission
    case failed
}

enum ScanPrimaryAction: String, Sendable, Equatable {
    case start
    case stop
}

enum ScanResultFilter:
    String,
    CaseIterable,
    Sendable,
    Equatable,
    Identifiable
{
    case all
    case ready
    case review
    case unknown
    case protected

    var id: String { rawValue }

    func includes(_ disposition: ReclaimDisposition) -> Bool {
        switch self {
        case .all:
            true
        case .ready:
            disposition == .readyToReclaim
        case .review:
            disposition == .reviewRecommended
        case .unknown:
            disposition == .unknown
        case .protected:
            disposition == .protected
        }
    }
}

struct ScanMetrics: Sendable, Equatable {
    let scopeScanned: Int
    let candidatesFound: Int
    let measuredBytes: ByteCount
    let elapsed: TimeInterval
}

struct ScanResultRow: Identifiable, Sendable, Equatable {
    let id: SnapshotID
    let classificationID: ClassificationID
    let relativePath: PersistedPath
    let itemName: String
    let modifiedAt: Date?
    let producer: DomainLabel?
    let category: ArtifactCategory
    let recoveryMethodKey: DomainToken?
    let recoveryCost: RebuildCost?
    let allocatedBytes: ByteCount?
    let measurementStatus: MeasurementStatus
    let measurementReasonKey: String?
    let disposition: ReclaimDisposition
    let missingEvidence: [DomainToken]

    var allocatedDisplay: String {
        allocatedBytes == nil ? "—" : ""
    }
}

struct ScanResultGroup: Identifiable, Sendable, Equatable {
    let category: ArtifactCategory
    let rows: [ScanResultRow]

    var id: ArtifactCategory { category }
}

struct ScanResultSummary: Sendable, Equatable {
    let readyCount: Int
    let reviewCount: Int
    let unknownCount: Int
    let protectedCount: Int
}

enum ScanInspectorAction: String, Sendable, Equatable {
    case close
}

struct ScanEvidenceInspectorModel: Sendable, Equatable {
    let snapshotID: SnapshotID
    let exactPath: PersistedPath
    let relativePath: PersistedPath
    let producer: DomainLabel?
    let category: ArtifactCategory
    let modifiedAt: Date?
    let recoveryMethodKey: DomainToken?
    let recoveryCost: RebuildCost?
    let allocatedBytes: ByteCount?
    let measurementStatus: MeasurementStatus
    let disposition: ReclaimDisposition
    let supportingEvidence: [EvidenceRecord]
    let missingEvidence: [DomainToken]
    let availableActions: [ScanInspectorAction]
}

struct ScanModel: Sendable, Equatable {
    let presentation: ScanPresentation
    let metrics: ScanMetrics
    let stageStates: [ScanStageState]
    let currentRelativePath: PersistedPath?
    let rows: [ScanResultRow]
    let groups: [ScanResultGroup]
    let summary: ScanResultSummary
    let primaryAction: ScanPrimaryAction
    let reasonKey: DomainToken?
    let projection: QuickScanProjection?

    private let evidenceBySnapshot: [SnapshotID: [EvidenceRecord]]
    private let rootPath: PersistedPath?

    init(
        flowState: ScanFlowState,
        pageState: AppPageState,
        query: String = "",
        filter: ScanResultFilter = .all
    ) {
        presentation = Self.presentation(for: flowState.phase)
        metrics = ScanMetrics(
            scopeScanned: flowState.scopeScanned,
            candidatesFound: flowState.candidatesFound,
            measuredBytes: flowState.measuredBytes,
            elapsed: flowState.elapsed
        )
        stageStates = flowState.stageStates
        currentRelativePath = flowState.currentRelativePath
        primaryAction = flowState.isActive ? .stop : .start
        reasonKey = flowState.reasonKey ?? pageState.reasonKey
        projection = flowState.projection ?? pageState.projection
        rootPath = flowState.rootPath
            ?? projection?.session.completedScopes.first?.rootPath
            ?? projection?.session.unfinishedScopes.first?.rootPath

        let sourceSnapshots: [PathSnapshot]
        let sourceClassifications: [Classification]
        let sourceEvidence: [EvidenceRecord]
        let sourceLedger: SpaceLedger?
        let hasFlowFacts = !flowState.snapshots.isEmpty
            || !flowState.classifications.isEmpty
            || !flowState.evidence.isEmpty
            || flowState.ledger != nil
        if flowState.isActive || hasFlowFacts {
            sourceSnapshots = flowState.snapshots
            sourceClassifications = flowState.classifications
            sourceEvidence = flowState.evidence
            sourceLedger = flowState.ledger
        } else if let projection = flowState.projection
            ?? pageState.projection
        {
            sourceSnapshots = projection.snapshots
            sourceClassifications = projection.classifications
            sourceEvidence = projection.evidence
            sourceLedger = projection.ledger
        } else {
            sourceSnapshots = []
            sourceClassifications = []
            sourceEvidence = []
            sourceLedger = nil
        }
        evidenceBySnapshot = Dictionary(
            grouping: sourceEvidence,
            by: \.targetID
        ).mapValues {
            $0.sorted(by: evidenceSort)
        }

        let snapshots = Dictionary(
            uniqueKeysWithValues: sourceSnapshots.map { ($0.id, $0) }
        )
        let owners = (sourceLedger?.owners ?? []).reduce(
            into: [ClassificationID: SpaceLedgerOwner]()
        ) {
            $0[$1.classificationID] = $1
        }
        let coverageGaps = (sourceLedger?.coverageGaps ?? []).reduce(
            into: [SnapshotID: SpaceLedgerCoverageGap]()
        ) {
            $0[$1.snapshotID] = $1
        }
        let allRows = sourceClassifications.compactMap {
            classification -> ScanResultRow? in
            guard let snapshot = snapshots[classification.snapshotID],
                  snapshot.relativePath != ".",
                  let relativePath = PersistedPath(
                      rawValue: snapshot.relativePath
                  )
            else {
                return nil
            }
            let owner = owners[classification.id]
            let allocatedBytes = owner.flatMap {
                $0.snapshotID == snapshot.id
                    && $0.category == classification.category
                    && $0.disposition == classification.disposition
                    ? $0.allocatedBytes
                    : nil
            }
            let coverageGap = coverageGaps[snapshot.id]
            let resultMeasurementStatus = coverageGap?.status
                ?? snapshot.measurementStatus
            return ScanResultRow(
                id: snapshot.id,
                classificationID: classification.id,
                relativePath: relativePath,
                itemName: Self.itemName(
                    relativePath: snapshot.relativePath
                ),
                modifiedAt: snapshot.modifiedAt,
                producer: classification.producer,
                category: classification.category,
                recoveryMethodKey: classification.recovery?.methodKey,
                recoveryCost: classification.recovery?.cost,
                allocatedBytes: allocatedBytes,
                measurementStatus: resultMeasurementStatus,
                measurementReasonKey: Self.measurementReasonKey(
                    status: resultMeasurementStatus,
                    hasLedgerOwner: owner != nil,
                    hasCoverageGap: coverageGap != nil
                ),
                disposition: classification.disposition,
                missingEvidence: classification.missingEvidenceKeys.sorted {
                    $0.rawValue < $1.rawValue
                }
            )
        }.sorted(by: rowSort)

        summary = ScanResultSummary(
            readyCount: allRows.count {
                $0.disposition == ReclaimDisposition.readyToReclaim
            },
            reviewCount: allRows.count {
                $0.disposition == ReclaimDisposition.reviewRecommended
            },
            unknownCount: allRows.count {
                $0.disposition == ReclaimDisposition.unknown
            },
            protectedCount: allRows.count {
                $0.disposition == ReclaimDisposition.protected
            }
        )

        let normalizedQuery = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        rows = allRows.filter { row in
            filter.includes(row.disposition)
                && (
                    normalizedQuery.isEmpty
                        || row.relativePath.rawValue.localizedCaseInsensitiveContains(
                            normalizedQuery
                        )
                        || row.itemName.localizedCaseInsensitiveContains(
                            normalizedQuery
                        )
                        || row.producer?.rawValue
                            .localizedCaseInsensitiveContains(
                                normalizedQuery
                            ) == true
                )
        }
        let grouped = Dictionary(grouping: rows, by: \.category)
        groups = ArtifactCategory.allCases.map {
            ScanResultGroup(
                category: $0,
                rows: grouped[$0, default: []]
            )
        }
    }

    func inspector(
        for snapshotID: SnapshotID
    ) -> ScanEvidenceInspectorModel? {
        guard let row = rows.first(where: { $0.id == snapshotID }) else {
            return nil
        }
        return ScanEvidenceInspectorModel(
            snapshotID: row.id,
            exactPath: Self.exactPath(
                rootPath: rootPath,
                relativePath: row.relativePath
            ),
            relativePath: row.relativePath,
            producer: row.producer,
            category: row.category,
            modifiedAt: row.modifiedAt,
            recoveryMethodKey: row.recoveryMethodKey,
            recoveryCost: row.recoveryCost,
            allocatedBytes: row.allocatedBytes,
            measurementStatus: row.measurementStatus,
            disposition: row.disposition,
            supportingEvidence:
                evidenceBySnapshot[row.id, default: []],
            missingEvidence: row.missingEvidence,
            availableActions: [.close]
        )
    }

    private static func exactPath(
        rootPath: PersistedPath?,
        relativePath: PersistedPath
    ) -> PersistedPath {
        guard let rootPath else {
            return relativePath
        }
        let root = rootPath.rawValue == "/"
            ? ""
            : rootPath.rawValue.trimmingCharacters(
                in: CharacterSet(charactersIn: "/")
            )
        return PersistedPath(
            rawValue: "/" + [root, relativePath.rawValue]
                .filter { !$0.isEmpty }
                .joined(separator: "/")
        ) ?? relativePath
    }

    private static func presentation(
        for phase: ScanFlowPhase
    ) -> ScanPresentation {
        switch phase {
        case .idle:
            .idle
        case .active:
            .active
        case .stopping:
            .stopping
        case .completed:
            .completed
        case .partial:
            .partial
        case .cancelled:
            .cancelled
        case .limitedPermission:
            .limitedPermission
        case .failed:
            .failed
        }
    }

    private static func itemName(relativePath: String) -> String {
        guard relativePath != "." else {
            return relativePath
        }
        let name = URL(fileURLWithPath: relativePath).lastPathComponent
        return name.isEmpty ? relativePath : name
    }

    private static func measurementReasonKey(
        status: MeasurementStatus,
        hasLedgerOwner: Bool,
        hasCoverageGap: Bool
    ) -> String? {
        if hasCoverageGap || status != .measured {
            return "scan.measurement.\(status.rawValue)"
        }
        return hasLedgerOwner
            ? "scan.measurement.unavailable"
            : "scan.measurement.pendingAccounting"
    }
}

private func rowSort(
    _ lhs: ScanResultRow,
    _ rhs: ScanResultRow
) -> Bool {
    let order: [ReclaimDisposition: Int] = [
        .readyToReclaim: 0,
        .reviewRecommended: 1,
        .unknown: 2,
        .protected: 3,
    ]
    let lhsOrder = order[lhs.disposition, default: 4]
    let rhsOrder = order[rhs.disposition, default: 4]
    if lhsOrder != rhsOrder {
        return lhsOrder < rhsOrder
    }
    switch (lhs.allocatedBytes, rhs.allocatedBytes) {
    case let (lhs?, rhs?) where lhs != rhs:
        return lhs > rhs
    case (.some, nil):
        return true
    case (nil, .some):
        return false
    default:
        break
    }
    if lhs.relativePath.rawValue != rhs.relativePath.rawValue {
        return lhs.relativePath.rawValue < rhs.relativePath.rawValue
    }
    return lhs.id.rawValue < rhs.id.rawValue
}

private func evidenceSort(
    _ lhs: EvidenceRecord,
    _ rhs: EvidenceRecord
) -> Bool {
    if lhs.kind.rawValue != rhs.kind.rawValue {
        return lhs.kind.rawValue < rhs.kind.rawValue
    }
    if lhs.summaryKey.rawValue != rhs.summaryKey.rawValue {
        return lhs.summaryKey.rawValue < rhs.summaryKey.rawValue
    }
    return lhs.id.rawValue < rhs.id.rawValue
}
