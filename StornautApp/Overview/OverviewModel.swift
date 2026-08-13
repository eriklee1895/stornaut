import Foundation
import StornautCore

enum OverviewPresentation: String, Sendable, Equatable {
    case empty
    case loading
    case current
    case scanInProgress
    case partial
    case cancelled
    case limitedPermission
    case stale
    case inconsistent
    case error
}

enum OverviewPrimaryAction: String, Sendable, Equatable {
    case openScan
    case retryLatestSnapshot
}

enum OverviewDeepDiveState: String, Sendable, Equatable {
    case implementationUnavailable
}

enum OverviewMetricKind: String, Sendable, Equatable {
    case free
    case explained
    case readyToReclaim
}

struct OverviewMetric: Sendable, Equatable {
    let kind: OverviewMetricKind
    let bytes: ByteCount?
    let fraction: Double?
}

struct OverviewMetrics: Sendable, Equatable {
    let free: OverviewMetric
    let explained: OverviewMetric
    let readyToReclaim: OverviewMetric
}

struct OverviewSnapshot: Sendable, Equatable {
    let sessionID: ScanSessionID
    let sampledAt: Date
    let scopePath: PersistedPath
    let terminalState: ScanTerminalState
    let ledgerStatus: SpaceLedgerStatus?
}

enum OverviewLedgerKind: String, CaseIterable, Sendable, Equatable {
    case known
    case unknown
    case unmeasurable
    case free
}

struct OverviewLedgerRow: Sendable, Equatable {
    let kind: OverviewLedgerKind
    let status: AccountingMeasurementStatus
    let bytes: ByteCount?
    let sources: [OverviewLedgerSource]
    let coverageGapCount: Int
    let includesUnmeasurable: Bool
}

struct OverviewLedgerSource: Sendable, Equatable {
    let kind: AccountingSourceKind
    let identifier: DomainToken
    let sampledAt: Date
}

enum OverviewOrbitKind: String, Sendable, Equatable {
    case packageAndBuildCaches
    case rebuildableProjectArtifacts
    case toolRuntimesAndImages
    case updatesAndTemporaryFiles
    case largeRepositoriesAndHistory
    case protected
    case unknown
    case free
}

struct OverviewOrbitSegment: Identifiable, Sendable, Equatable {
    let kind: OverviewOrbitKind
    let bytes: ByteCount

    var id: OverviewOrbitKind { kind }
}

enum OverviewOpportunityActivity: String, Sendable, Equatable {
    case checked
    case unavailable
    case unknown
}

struct OverviewOpportunity: Identifiable, Sendable, Equatable {
    let classificationID: ClassificationID
    let relativePath: PersistedPath
    let producer: DomainLabel?
    let category: ArtifactCategory
    let disposition: ReclaimDisposition
    let allocatedBytes: ByteCount
    let recoveryCost: RebuildCost?
    let activity: OverviewOpportunityActivity

    var id: ClassificationID { classificationID }
}

struct OverviewModel: Sendable, Equatable {
    let presentation: OverviewPresentation
    let snapshot: OverviewSnapshot?
    let metrics: OverviewMetrics?
    let ledgerRows: [OverviewLedgerRow]
    let orbitSegments: [OverviewOrbitSegment]
    let opportunities: [OverviewOpportunity]
    let coverage: CoverageBadgeModel?
    let primaryAction: OverviewPrimaryAction?
    let recoveryIntent: SafeRecoveryIntent?
    let deepDive: OverviewDeepDiveState
    let reasonKey: DomainToken?

    init(
        pageState: AppPageState,
        scanActivity: AppScanActivity = .idle
    ) {
        presentation = Self.presentation(
            for: pageState,
            scanActivity: scanActivity
        )
        reasonKey = pageState.reasonKey
        recoveryIntent = pageState.recoveryIntent
        deepDive = .implementationUnavailable

        guard let projection = pageState.projection else {
            snapshot = nil
            metrics = nil
            ledgerRows = []
            orbitSegments = []
            opportunities = []
            coverage = nil
            if scanActivity == .active {
                primaryAction = .openScan
            } else if pageState.phase == .loading {
                primaryAction = nil
            } else if pageState.phase == .error {
                primaryAction = .retryLatestSnapshot
            } else {
                primaryAction = .openScan
            }
            return
        }

        snapshot = Self.snapshot(from: projection)
        if let ledger = projection.ledger {
            metrics = Self.metrics(
                projection: projection,
                ledger: ledger
            )
            ledgerRows = Self.ledgerRows(from: ledger)
            orbitSegments = Self.orbitSegments(from: ledger)
            opportunities = Self.opportunities(
                projection: projection,
                ledger: ledger
            )
            coverage = CoverageBadgeModel(
                gapCount: ledger.coverageGaps.count,
                unmeasurableBytes: ledger.unmeasurable.bytes
            )
        } else {
            metrics = nil
            ledgerRows = []
            orbitSegments = []
            opportunities = []
            coverage = nil
        }
        if scanActivity == .active {
            primaryAction = .openScan
        } else if pageState.phase == .loading {
            primaryAction = nil
        } else if pageState.phase == .error {
            primaryAction = .retryLatestSnapshot
        } else {
            primaryAction = .openScan
        }
    }

    private static func presentation(
        for pageState: AppPageState,
        scanActivity: AppScanActivity
    ) -> OverviewPresentation {
        if scanActivity == .active {
            return .scanInProgress
        }
        return switch pageState.phase {
        case .empty:
            .empty
        case .loading:
            .loading
        case .partial:
            .partial
        case .cancelled:
            .cancelled
        case .success:
            pageState.projection?.ledger?.status == .inconsistent
                ? .inconsistent
                : .current
        case .limitedPermission:
            .limitedPermission
        case .stale:
            .stale
        case .error:
            .error
        }
    }

    private static func snapshot(
        from projection: QuickScanProjection
    ) -> OverviewSnapshot {
        let scope = projection.session.completedScopes.first?.rootPath
            ?? projection.session.unfinishedScopes.first?.rootPath
            ?? PersistedPath(rawValue: ".")!
        let sampledAt = projection.ledger?.free.sources
            .map(\.sampledAt)
            .max()
            ?? projection.session.finishedAt
        return OverviewSnapshot(
            sessionID: projection.session.id,
            sampledAt: sampledAt,
            scopePath: scope,
            terminalState: projection.session.terminalState,
            ledgerStatus: projection.ledger?.status
        )
    }

    private static func metrics(
        projection: QuickScanProjection,
        ledger: SpaceLedger
    ) -> OverviewMetrics {
        let used = subtract(
            ledger.volumeCapacity.bytes,
            ledger.free.bytes
        )
        let explainedFraction = ratio(
            numerator: ledger.known.bytes,
            denominator: used
        )
        let classifications = Dictionary(
            uniqueKeysWithValues: projection.classifications.map {
                ($0.id, $0)
            }
        )
        let readyBytes = readyBytes(
            owners: ledger.owners,
            classifications: classifications
        )
        return OverviewMetrics(
            free: OverviewMetric(
                kind: .free,
                bytes: ledger.free.bytes,
                fraction: ratio(
                    numerator: ledger.free.bytes,
                    denominator: ledger.volumeCapacity.bytes
                )
            ),
            explained: OverviewMetric(
                kind: .explained,
                bytes: ledger.known.bytes,
                fraction: explainedFraction
            ),
            readyToReclaim: OverviewMetric(
                kind: .readyToReclaim,
                bytes: readyBytes,
                fraction: ratio(
                    numerator: readyBytes,
                    denominator: used
                )
            )
        )
    }

    private static func ledgerRows(
        from ledger: SpaceLedger
    ) -> [OverviewLedgerRow] {
        [
            ledgerRow(
                kind: .known,
                measure: ledger.known,
                ledger: ledger
            ),
            ledgerRow(
                kind: .unknown,
                measure: ledger.unknown,
                ledger: ledger
            ),
            ledgerRow(
                kind: .unmeasurable,
                measure: ledger.unmeasurable,
                ledger: ledger
            ),
            ledgerRow(
                kind: .free,
                measure: ledger.free,
                ledger: ledger
            ),
        ]
    }

    private static func ledgerRow(
        kind: OverviewLedgerKind,
        measure: SpaceLedgerMeasure,
        ledger: SpaceLedger
    ) -> OverviewLedgerRow {
        OverviewLedgerRow(
            kind: kind,
            status: measure.status,
            bytes: measure.bytes,
            sources: measure.sources.map {
                OverviewLedgerSource(
                    kind: $0.kind,
                    identifier: $0.identifier,
                    sampledAt: $0.sampledAt
                )
            }.sorted {
                if $0.kind.rawValue != $1.kind.rawValue {
                    return $0.kind.rawValue < $1.kind.rawValue
                }
                if $0.identifier.rawValue != $1.identifier.rawValue {
                    return $0.identifier.rawValue < $1.identifier.rawValue
                }
                return $0.sampledAt < $1.sampledAt
            },
            coverageGapCount: kind == .unmeasurable
                ? ledger.coverageGaps.count
                : 0,
            includesUnmeasurable: kind == .unknown
                && ledger.unknownIncludesUnmeasurable
        )
    }

    private static func orbitSegments(
        from ledger: SpaceLedger
    ) -> [OverviewOrbitSegment] {
        var totals: [OverviewOrbitKind: UInt64] = [:]
        for owner in ledger.owners {
            guard owner.category != .unknownLargeConsumers,
                  let bytes = owner.allocatedBytes
            else {
                continue
            }
            let kind = orbitKind(for: owner.category)
            guard let total = checkedAdd(totals[kind, default: 0], bytes.value)
            else {
                return []
            }
            totals[kind] = total
        }
        if let unknown = ledger.unknown.bytes {
            totals[.unknown] = unknown.value
        }
        if let free = ledger.free.bytes {
            totals[.free] = free.value
        }
        let order: [OverviewOrbitKind] = [
            .packageAndBuildCaches,
            .rebuildableProjectArtifacts,
            .toolRuntimesAndImages,
            .updatesAndTemporaryFiles,
            .largeRepositoriesAndHistory,
            .protected,
            .unknown,
            .free,
        ]
        return order.compactMap { kind in
            guard let value = totals[kind],
                  value > 0,
                  let bytes = ByteCount(value)
            else {
                return nil
            }
            return OverviewOrbitSegment(kind: kind, bytes: bytes)
        }
    }

    private static func opportunities(
        projection: QuickScanProjection,
        ledger: SpaceLedger
    ) -> [OverviewOpportunity] {
        let classifications = Dictionary(
            uniqueKeysWithValues: projection.classifications.map {
                ($0.id, $0)
            }
        )
        let currentEvidenceTargets = Set(
            projection.evidence.compactMap {
                ($0.kind == .activity || $0.kind == .git)
                    && $0.freshness == .current
                    && $0.summaryKey.rawValue
                        != "quick-scan.activity.provider-failure"
                    ? $0.targetID
                    : nil
            }
        )
        let unavailableEvidenceTargets = Set(
            projection.evidence.compactMap {
                ($0.kind == .activity || $0.kind == .git)
                    && $0.summaryKey.rawValue
                        == "quick-scan.activity.provider-failure"
                    ? $0.targetID
                    : nil
            }
        )
        return ledger.owners.compactMap { owner in
            guard let classification = classifications[
                owner.classificationID
            ],
                  classification.snapshotID == owner.snapshotID,
                  classification.category == owner.category,
                  classification.disposition == owner.disposition,
                  classification.disposition == .readyToReclaim
                    || classification.disposition == .reviewRecommended,
                  let bytes = owner.allocatedBytes
            else {
                return nil
            }
            let missingActivity = classification.missingEvidenceKeys.contains {
                $0.rawValue.hasPrefix("activity.")
            }
            let activity: OverviewOpportunityActivity
            if missingActivity
                || unavailableEvidenceTargets.contains(
                    classification.snapshotID
                )
            {
                activity = .unavailable
            } else if currentEvidenceTargets.contains(
                classification.snapshotID
            ) {
                activity = .checked
            } else {
                activity = .unknown
            }
            return OverviewOpportunity(
                classificationID: classification.id,
                relativePath: owner.relativePath,
                producer: classification.producer,
                category: classification.category,
                disposition: classification.disposition,
                allocatedBytes: bytes,
                recoveryCost: classification.recovery?.cost,
                activity: activity
            )
        }.sorted(by: opportunitySort).prefix(3).map { $0 }
    }

    private static func opportunitySort(
        _ lhs: OverviewOpportunity,
        _ rhs: OverviewOpportunity
    ) -> Bool {
        let lhsRank = lhs.disposition == .readyToReclaim ? 0 : 1
        let rhsRank = rhs.disposition == .readyToReclaim ? 0 : 1
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }
        if lhs.allocatedBytes != rhs.allocatedBytes {
            return lhs.allocatedBytes > rhs.allocatedBytes
        }
        if lhs.relativePath.rawValue != rhs.relativePath.rawValue {
            return lhs.relativePath.rawValue < rhs.relativePath.rawValue
        }
        return lhs.classificationID.rawValue
            < rhs.classificationID.rawValue
    }

    private static func orbitKind(
        for category: ArtifactCategory
    ) -> OverviewOrbitKind {
        switch category {
        case .packageAndBuildCaches:
            .packageAndBuildCaches
        case .rebuildableProjectArtifacts:
            .rebuildableProjectArtifacts
        case .toolRuntimesAndImages:
            .toolRuntimesAndImages
        case .updatesAndTemporaryFiles:
            .updatesAndTemporaryFiles
        case .largeRepositoriesAndHistory:
            .largeRepositoriesAndHistory
        case .unknownLargeConsumers:
            .unknown
        case .protected:
            .protected
        }
    }

    private static func subtract(
        _ lhs: ByteCount?,
        _ rhs: ByteCount?
    ) -> ByteCount? {
        guard let lhs, let rhs, rhs <= lhs else {
            return nil
        }
        return ByteCount(lhs.value - rhs.value)
    }

    private static func readyBytes(
        owners: [SpaceLedgerOwner],
        classifications: [ClassificationID: Classification]
    ) -> ByteCount? {
        let readyOwners = owners.filter {
            $0.disposition == .readyToReclaim
        }
        guard !readyOwners.isEmpty else {
            return ByteCount(0)
        }
        var values: [ByteCount] = []
        for owner in readyOwners {
            guard let classification = classifications[
                owner.classificationID
            ],
                  classification.snapshotID == owner.snapshotID,
                  classification.category == owner.category,
                  classification.disposition == owner.disposition,
                  let bytes = owner.allocatedBytes
            else {
                return nil
            }
            values.append(bytes)
        }
        return sum(values)
    }

    private static func sum(_ values: [ByteCount]) -> ByteCount? {
        var total: UInt64 = 0
        for value in values {
            guard let next = checkedAdd(total, value.value) else {
                return nil
            }
            total = next
        }
        return ByteCount(total)
    }

    private static func checkedAdd(
        _ lhs: UInt64,
        _ rhs: UInt64
    ) -> UInt64? {
        let result = lhs.addingReportingOverflow(rhs)
        guard !result.overflow,
              result.partialValue <= UInt64(Int64.max)
        else {
            return nil
        }
        return result.partialValue
    }

    private static func ratio(
        numerator: ByteCount?,
        denominator: ByteCount?
    ) -> Double? {
        guard let numerator, let denominator, denominator.value > 0 else {
            return nil
        }
        guard numerator <= denominator else {
            return nil
        }
        return Double(numerator.value) / Double(denominator.value)
    }
}
