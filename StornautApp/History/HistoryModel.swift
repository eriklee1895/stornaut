import Foundation
import StornautCore

enum HistoryPresentation: String, Sendable, Equatable {
    case empty
    case noResults
    case loading
    case loaded
    case deleting
    case error
}

enum HistoryDateGroupKind: String, Sendable, Equatable, Identifiable {
    case today
    case yesterday
    case earlier

    var id: String { rawValue }
}

enum HistoryTerminalFilter:
    String,
    CaseIterable,
    Sendable,
    Equatable,
    Identifiable
{
    case all
    case complete
    case partial
    case stopped
    case failed

    var id: String { rawValue }

    func includes(_ state: ScanTerminalState) -> Bool {
        switch self {
        case .all:
            true
        case .complete:
            state == .completed
        case .partial:
            state == .partial
        case .stopped:
            state == .cancelled
        case .failed:
            state == .failed
        }
    }
}

enum HistoryDateFilter:
    String,
    CaseIterable,
    Sendable,
    Equatable,
    Identifiable
{
    case allRetained
    case today
    case lastSevenDays

    var id: String { rawValue }
}

enum HistoryTypeFilter:
    String,
    CaseIterable,
    Sendable,
    Equatable,
    Identifiable
{
    case all
    case quickScan
    case cleanupManifest

    var id: String { rawValue }
}

enum HistoryCoverage: String, Sendable, Equatable {
    case complete
    case limited
    case unavailable
}

enum HistoryLedgerStatus: String, Sendable, Equatable {
    case available
    case unavailable
    case corrupt
}

struct HistoryRetention: Sendable, Equatable {
    let state: RetentionState
    let expiresAt: Date
    let remaining: TimeInterval
}

enum HistoryLedgerRowKind: String, Sendable, Equatable {
    case known
    case unknown
    case unmeasurable
    case free
}

struct HistoryLedgerRow: Sendable, Equatable {
    let kind: HistoryLedgerRowKind
    let status: AccountingMeasurementStatus
    let bytes: ByteCount?
    let sources: [AccountingSource]
}

struct HistoryRecordModel: Identifiable, Sendable, Equatable {
    let sessionID: ScanSessionID
    let startedAt: Date
    let finishedAt: Date
    let duration: TimeInterval
    let terminalState: ScanTerminalState
    let scopePath: PersistedPath?
    let unfinishedReason: ScanScopeCompletionReason?
    let expiresAt: Date
    let retention: HistoryRetention
    let coverage: HistoryCoverage
    let ledgerStatus: HistoryLedgerStatus
    let ledgerRows: [HistoryLedgerRow]
    let volumeCapacityStatus: AccountingMeasurementStatus?
    let volumeCapacity: ByteCount?
    let volumeSources: [AccountingSource]
    let ledgerReconciliationStatus: SpaceLedgerStatus?
    let caveats: [SpaceLedgerCaveat]

    var id: ScanSessionID { sessionID }
}

struct HistoryManifestItemModel: Identifiable, Sendable, Equatable {
    let actionID: CleanupActionID
    let planItemID: CleanupPlanItemID
    let policyDisposition: ReclaimDisposition
    let policyReasonKeys: [DomainToken]
    let action: ProposedCleanupAction
    let result: ManifestActionResult
    let recovery: CleanupRecoveryState
    let measures: CleanupManifestMeasures
    let startedAt: Date?
    let finishedAt: Date?
    let error: CleanupManifestError?
    let itemName: String?
    let relativePath: PersistedPath?

    var id: CleanupActionID { actionID }
}

struct HistoryManifestFailureDescriptor: Sendable, Equatable {
    let stageKey: String
    let failureKey: String

    init(_ error: CleanupManifestError) {
        stageKey = "cleanup.failure.stage." + error.stage.rawValue
        failureKey = switch error.code.rawValue {
        case "trash.destination.unavailable":
            "cleanup.failure.trashUnavailable"
        case "cleanup.recovery.unknown":
            "cleanup.failure.outcomeUnknown"
        default:
            "cleanup.failure.unknown"
        }
    }
}

enum HistoryManifestOutcome: String, Sendable, Equatable {
    case completed
    case completedWithIssues
    case stopped
    case failed
    case outcomeUnknown
}

struct HistoryManifestRecordModel: Identifiable, Sendable, Equatable {
    let manifestID: CleanupManifestID
    let planID: CleanupPlanID
    let createdAt: Date
    let expiresAt: Date
    let retention: HistoryRetention
    let evidenceAvailability: CleanupManifestEvidenceAvailability
    let outcome: HistoryManifestOutcome
    let summary: CleanupManifestSummary
    let items: [HistoryManifestItemModel]
    let systemObservation: ManifestSystemObservation?

    var id: CleanupManifestID { manifestID }
}

enum HistoryItemModel: Identifiable, Sendable, Equatable {
    case quickScan(HistoryRecordModel)
    case cleanupManifest(HistoryManifestRecordModel)

    var id: HistoryRecordID {
        switch self {
        case let .quickScan(record):
            .quickScan(record.sessionID)
        case let .cleanupManifest(record):
            .cleanupManifest(record.manifestID)
        }
    }

    var eventAt: Date {
        switch self {
        case let .quickScan(record):
            record.finishedAt
        case let .cleanupManifest(record):
            record.createdAt
        }
    }
}

struct HistoryDateGroup: Identifiable, Sendable, Equatable {
    let kind: HistoryDateGroupKind
    let items: [HistoryItemModel]

    var id: HistoryDateGroupKind { kind }

    var records: [HistoryRecordModel] {
        items.compactMap {
            guard case let .quickScan(record) = $0 else {
                return nil
            }
            return record
        }
    }
}

struct HistoryCorruptRecord: Identifiable, Sendable, Equatable {
    enum Source: String, Sendable, Equatable {
        case quickScan
        case cleanupManifest
    }

    let source: Source
    let rawID: String

    var id: String { "\(source.rawValue):\(rawID)" }
}

struct HistoryTrendSample: Identifiable, Sendable, Equatable {
    let sessionID: ScanSessionID
    let finishedAt: Date
    let capacityBytes: ByteCount
    let usedBytes: ByteCount
    let freeBytes: ByteCount

    var id: ScanSessionID { sessionID }
}

struct HistoryTrendModel: Sendable, Equatable {
    let samples: [HistoryTrendSample]
    let events: [HistoryTrendEvent]
    let causalityDisclaimerKey: String
}

struct HistoryTrendEvent: Identifiable, Sendable, Equatable {
    let id: HistoryRecordID
    let createdAt: Date
}

struct HistoryDeleteContract: Sendable, Equatable {
    let recordID: HistoryRecordID
    let isUndoable: Bool
    let altersScannedFiles: Bool
    let altersTrash: Bool
    let altersLocalKnowledge: Bool

    var sessionID: ScanSessionID? {
        guard case let .quickScan(id) = recordID else {
            return nil
        }
        return id
    }
}

struct HistoryModel: Sendable, Equatable {
    let presentation: HistoryPresentation
    let records: [HistoryRecordModel]
    let manifestRecords: [HistoryManifestRecordModel]
    let items: [HistoryItemModel]
    let groups: [HistoryDateGroup]
    let corruptRecords: [HistoryCorruptRecord]
    let selectedID: ScanSessionID?
    let selectedRecordID: HistoryRecordID?
    let trend: HistoryTrendModel?
    let deletingSessionID: ScanSessionID?
    let deletingRecordID: HistoryRecordID?
    let reasonKey: DomainToken?

    init(
        state: HistoryState,
        now: Date,
        calendar: Calendar,
        query: String = "",
        terminalFilter: HistoryTerminalFilter = .all,
        typeFilter: HistoryTypeFilter = .all,
        dateFilter: HistoryDateFilter = .allRetained,
        selectedID: ScanSessionID? = nil,
        selectedRecordID: HistoryRecordID? = nil
    ) {
        reasonKey = state.reasonKey
        deletingSessionID = state.deletingSessionID
        deletingRecordID = state.deletingRecordID
        let page = state.page ?? .empty
        let corruptLedgerIDs = Set(page.corruptLedgerSessionIDs)
        let projectedScans = page.records.map {
            Self.project(
                $0,
                now: now,
                ledgerIsCorrupt: corruptLedgerIDs.contains(
                    $0.session.id.rawValue
                )
            )
        }.sorted(by: recordSort)
        let projectedManifests = page.manifests.map {
            Self.project($0, now: now)
        }.sorted(by: manifestSort)
        let normalizedQuery = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let filteredRecords = projectedScans.filter { record in
            (typeFilter == .all || typeFilter == .quickScan)
                && terminalFilter.includes(record.terminalState)
                && Self.dateFilter(
                    dateFilter,
                    includes: record.finishedAt,
                    now: now,
                    calendar: calendar
                )
                && Self.matches(record, query: normalizedQuery)
        }
        let filteredManifests = projectedManifests.filter { record in
            (typeFilter == .all || typeFilter == .cleanupManifest)
                && Self.includes(record, terminalFilter: terminalFilter)
                && Self.dateFilter(
                    dateFilter,
                    includes: record.createdAt,
                    now: now,
                    calendar: calendar
                )
                && Self.matches(record, query: normalizedQuery)
        }
        records = filteredRecords
        manifestRecords = filteredManifests
        let projectedItems =
            projectedScans.map(HistoryItemModel.quickScan)
                + projectedManifests.map(HistoryItemModel.cleanupManifest)
        let filteredItems = (
            filteredRecords.map(HistoryItemModel.quickScan)
                + filteredManifests.map(HistoryItemModel.cleanupManifest)
        ).sorted(by: itemSort)
        items = filteredItems
        let groupOrder: [HistoryDateGroupKind] = [
            .today,
            .yesterday,
            .earlier,
        ]
        groups = groupOrder.compactMap { kind in
            let values = filteredItems.filter {
                Self.dateGroup(
                    for: $0.eventAt,
                    now: now,
                    calendar: calendar
                ) == kind
            }
            return values.isEmpty
                ? nil
                : HistoryDateGroup(kind: kind, items: values)
        }
        let canShowCorrupt = terminalFilter == .all
            && dateFilter == .allRetained
        let corruptScans = canShowCorrupt
            && (typeFilter == .all || typeFilter == .quickScan)
            ? page.corruptSessionIDs.compactMap {
                normalizedQuery.isEmpty
                    || $0.localizedCaseInsensitiveContains(normalizedQuery)
                    ? HistoryCorruptRecord(source: .quickScan, rawID: $0)
                    : nil
            }
            : []
        let corruptManifests = canShowCorrupt
            && (typeFilter == .all || typeFilter == .cleanupManifest)
            ? page.corruptManifestIDs.compactMap {
                normalizedQuery.isEmpty
                    || $0.localizedCaseInsensitiveContains(normalizedQuery)
                    ? HistoryCorruptRecord(
                        source: .cleanupManifest,
                        rawID: $0
                    )
                    : nil
            }
            : []
        let filteredCorruptRecords = (corruptManifests + corruptScans).sorted {
            $0.id < $1.id
        }
        corruptRecords = filteredCorruptRecords
        let projectedPresentation: HistoryPresentation
        switch state.phase {
        case .idle:
            projectedPresentation = .empty
        case .loading:
            projectedPresentation = .loading
        case .loaded:
            if filteredItems.isEmpty && filteredCorruptRecords.isEmpty {
                projectedPresentation =
                    page.records.isEmpty
                    && page.manifests.isEmpty
                    && page.corruptSessionIDs.isEmpty
                    && page.corruptManifestIDs.isEmpty
                    ? .empty
                    : .noResults
            } else {
                projectedPresentation = .loaded
            }
        case .deleting:
            projectedPresentation = .deleting
        case .error:
            projectedPresentation = .error
        }
        let visibleIDs = Set(filteredItems.map(\.id))
        let legacySelection = selectedID.map(HistoryRecordID.quickScan)
        let requestedSelection = selectedRecordID ?? legacySelection
        let healthySelection = requestedSelection.flatMap {
            visibleIDs.contains($0) ? $0 : nil
        }
        let fallbackSelection = filteredItems.first { item in
            switch item {
            case let .quickScan(record):
                record.ledgerStatus != .corrupt
            case .cleanupManifest:
                true
            }
        }?.id ?? filteredItems.first?.id
        self.selectedRecordID = healthySelection ?? fallbackSelection
        if case let .quickScan(id) = self.selectedRecordID {
            self.selectedID = id
        } else {
            self.selectedID = nil
        }
        trend = Self.trend(
            from: projectedScans,
            events: projectedItems.map {
                HistoryTrendEvent(id: $0.id, createdAt: $0.eventAt)
            }
        )
        presentation = projectedPresentation
    }

    func deleteContract(
        for recordID: HistoryRecordID
    ) -> HistoryDeleteContract? {
        guard items.contains(where: { $0.id == recordID }) else {
            return nil
        }
        return HistoryDeleteContract(
            recordID: recordID,
            isUndoable: false,
            altersScannedFiles: false,
            altersTrash: false,
            altersLocalKnowledge: false
        )
    }

    func deleteContract(
        for sessionID: ScanSessionID
    ) -> HistoryDeleteContract? {
        deleteContract(for: .quickScan(sessionID))
    }

    private static func includes(
        _ record: HistoryManifestRecordModel,
        terminalFilter: HistoryTerminalFilter
    ) -> Bool {
        switch terminalFilter {
        case .all:
            true
        case .complete:
            record.outcome == .completed
        case .partial:
            record.outcome == .completedWithIssues
                || record.outcome == .outcomeUnknown
        case .stopped:
            record.outcome == .stopped
        case .failed:
            record.outcome == .failed
        }
    }

    private static func matches(
        _ record: HistoryRecordModel,
        query: String
    ) -> Bool {
        query.isEmpty
            || record.sessionID.rawValue.localizedCaseInsensitiveContains(
                query
            )
            || record.scopePath?.rawValue.localizedCaseInsensitiveContains(
                query
            ) == true
    }

    private static func matches(
        _ record: HistoryManifestRecordModel,
        query: String
    ) -> Bool {
        query.isEmpty
            || record.manifestID.rawValue.localizedCaseInsensitiveContains(
                query
            )
            || record.planID.rawValue.localizedCaseInsensitiveContains(query)
            || record.items.contains {
                $0.actionID.rawValue.localizedCaseInsensitiveContains(query)
                    || $0.planItemID.rawValue
                        .localizedCaseInsensitiveContains(query)
                    || $0.itemName?
                        .localizedCaseInsensitiveContains(query) == true
                    || $0.relativePath?.rawValue
                        .localizedCaseInsensitiveContains(query) == true
            }
    }

    private static func project(
        _ record: CleanupManifestHistoryRecord,
        now: Date
    ) -> HistoryManifestRecordModel {
        let manifest = record.manifest
        let retention = retention(expiresAt: manifest.expiresAt, now: now)
        let enrichmentIsRetained =
            record.evidenceAvailability == .retained
                && (record.linkedPlan?.expiresAt ?? .distantPast) > now
        let evidenceAvailability: CleanupManifestEvidenceAvailability =
            enrichmentIsRetained ? .retained : .expired
        let planItems = Dictionary(
            uniqueKeysWithValues: (
                enrichmentIsRetained
                    ? record.linkedPlan?.items ?? []
                    : []
            ).map {
                ($0.id, $0)
            }
        )
        let items = manifest.records.map { manifestRecord in
            let planItem = enrichmentIsRetained
                ? planItems[manifestRecord.planItemID]
                : nil
            let relativePath = planItem?.expectedRelativePath
            return HistoryManifestItemModel(
                actionID: manifestRecord.actionID,
                planItemID: manifestRecord.planItemID,
                policyDisposition: manifestRecord.policyDisposition,
                policyReasonKeys: manifestRecord.policyReasonKeys,
                action: manifestRecord.action,
                result: manifestRecord.result,
                recovery: manifestRecord.recovery,
                measures: manifestRecord.measures,
                startedAt: manifestRecord.startedAt,
                finishedAt: manifestRecord.finishedAt,
                error: manifestRecord.error,
                itemName: relativePath.map {
                    URL(fileURLWithPath: $0.rawValue).lastPathComponent
                },
                relativePath: relativePath
            )
        }
        return HistoryManifestRecordModel(
            manifestID: manifest.id,
            planID: manifest.planID,
            createdAt: manifest.createdAt,
            expiresAt: manifest.expiresAt,
            retention: retention,
            evidenceAvailability: evidenceAvailability,
            outcome: manifestOutcome(manifest.summary),
            summary: manifest.summary,
            items: items,
            systemObservation: manifest.systemObservation
        )
    }

    private static func manifestOutcome(
        _ summary: CleanupManifestSummary
    ) -> HistoryManifestOutcome {
        if summary.unknownCount > 0 {
            return .outcomeUnknown
        }
        if summary.failedCount > 0, summary.succeededCount > 0 {
            return .completedWithIssues
        }
        if summary.failedCount > 0 {
            return .failed
        }
        if summary.cancelledCount > 0 {
            return summary.succeededCount > 0
                ? .completedWithIssues
                : .stopped
        }
        return .completed
    }

    private static func retention(
        expiresAt: Date,
        now: Date
    ) -> HistoryRetention {
        let remaining = expiresAt.timeIntervalSince(now)
        let state: RetentionState
        if remaining <= 0 {
            state = .expired
        } else if remaining <= 2 * 86_400 {
            state = .expiringSoon
        } else {
            state = .retained
        }
        return HistoryRetention(
            state: state,
            expiresAt: expiresAt,
            remaining: max(0, remaining)
        )
    }

    private static func project(
        _ record: HistoryRecord,
        now: Date,
        ledgerIsCorrupt: Bool
    ) -> HistoryRecordModel {
        let session = record.session
        let expiresAt = session.finishedAt.addingTimeInterval(7 * 86_400)
        let remaining = expiresAt.timeIntervalSince(now)
        let retentionState: RetentionState
        if remaining <= 0 {
            retentionState = .expired
        } else if remaining <= 2 * 86_400 {
            retentionState = .expiringSoon
        } else {
            retentionState = .retained
        }
        let scope = session.completedScopes.first?.rootPath
            ?? session.unfinishedScopes.first?.rootPath
        let ledgerStatus: HistoryLedgerStatus = ledgerIsCorrupt
            ? .corrupt
            : record.ledger == nil ? .unavailable : .available
        let rows = ledgerIsCorrupt
            ? []
            : record.ledger.map(ledgerRows) ?? []
        let coverage: HistoryCoverage
        if ledgerIsCorrupt || record.ledger == nil {
            coverage = .unavailable
        } else if record.ledger?.coverageGaps.isEmpty == true {
            coverage = .complete
        } else {
            coverage = .limited
        }
        return HistoryRecordModel(
            sessionID: session.id,
            startedAt: session.startedAt,
            finishedAt: session.finishedAt,
            duration: max(
                0,
                session.finishedAt.timeIntervalSince(session.startedAt)
            ),
            terminalState: session.terminalState,
            scopePath: scope,
            unfinishedReason: session.unfinishedScopes.first?.reason,
            expiresAt: expiresAt,
            retention: HistoryRetention(
                state: retentionState,
                expiresAt: expiresAt,
                remaining: max(0, remaining)
            ),
            coverage: coverage,
            ledgerStatus: ledgerStatus,
            ledgerRows: rows,
            volumeCapacityStatus: ledgerIsCorrupt
                ? nil
                : record.ledger?.volumeCapacity.status,
            volumeCapacity: ledgerIsCorrupt
                ? nil
                : record.ledger?.volumeCapacity.bytes,
            volumeSources: ledgerIsCorrupt
                ? []
                : record.ledger?.volumeCapacity.sources ?? [],
            ledgerReconciliationStatus: ledgerIsCorrupt
                ? nil
                : record.ledger?.status,
            caveats: ledgerIsCorrupt
                ? []
                : record.ledger?.caveats ?? []
        )
    }

    private static func ledgerRows(
        _ ledger: SpaceLedger
    ) -> [HistoryLedgerRow] {
        [
            HistoryLedgerRow(
                kind: .known,
                status: ledger.known.status,
                bytes: ledger.known.bytes,
                sources: ledger.known.sources
            ),
            HistoryLedgerRow(
                kind: .unknown,
                status: ledger.unknown.status,
                bytes: ledger.unknown.bytes,
                sources: ledger.unknown.sources
            ),
            HistoryLedgerRow(
                kind: .unmeasurable,
                status: ledger.unmeasurable.status,
                bytes: ledger.unmeasurable.bytes,
                sources: ledger.unmeasurable.sources
            ),
            HistoryLedgerRow(
                kind: .free,
                status: ledger.free.status,
                bytes: ledger.free.bytes,
                sources: ledger.free.sources
            ),
        ]
    }

    private static func dateGroup(
        for date: Date,
        now: Date,
        calendar: Calendar
    ) -> HistoryDateGroupKind {
        if calendar.isDate(date, inSameDayAs: now) {
            return .today
        }
        if let yesterday = calendar.date(
            byAdding: .day,
            value: -1,
            to: now
        ),
           calendar.isDate(date, inSameDayAs: yesterday)
        {
            return .yesterday
        }
        return .earlier
    }

    private static func dateFilter(
        _ filter: HistoryDateFilter,
        includes date: Date,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        switch filter {
        case .allRetained:
            true
        case .today:
            calendar.isDate(date, inSameDayAs: now)
        case .lastSevenDays:
            date >= now.addingTimeInterval(-7 * 86_400)
                && date <= now
        }
    }

    private static func trend(
        from records: [HistoryRecordModel],
        events: [HistoryTrendEvent]
    ) -> HistoryTrendModel? {
        let candidates = records.compactMap {
            record -> HistoryTrendSample? in
            guard record.terminalState == .completed,
                  record.ledgerStatus == .available,
                  record.ledgerReconciliationStatus != .inconsistent,
                  record.ledgerRows.first(
                      where: { $0.kind == .free }
                  )?.status == .measured,
                  let capacity = record.volumeCapacity,
                  let free = record.ledgerRows.first(
                      where: { $0.kind == .free }
                  )?.bytes,
                  record.volumeCapacityStatus == .measured,
                  free <= capacity,
                  let used = ByteCount(capacity.value - free.value)
            else {
                return nil
            }
            return HistoryTrendSample(
                sessionID: record.sessionID,
                finishedAt: record.finishedAt,
                capacityBytes: capacity,
                usedBytes: used,
                freeBytes: free
            )
        }.sorted {
            if $0.finishedAt != $1.finishedAt {
                return $0.finishedAt < $1.finishedAt
            }
            return $0.sessionID.rawValue < $1.sessionID.rawValue
        }
        var seenTimestamps = Set<Date>()
        let samples = candidates.filter {
            seenTimestamps.insert($0.finishedAt).inserted
        }
        guard samples.count >= 4 else {
            return nil
        }
        return HistoryTrendModel(
            samples: samples,
            events: events.sorted {
                if $0.createdAt != $1.createdAt {
                    return $0.createdAt < $1.createdAt
                }
                return $0.id.rawValue < $1.id.rawValue
            },
            causalityDisclaimerKey: "history.trend.nonCausal"
        )
    }
}

private func recordSort(
    _ lhs: HistoryRecordModel,
    _ rhs: HistoryRecordModel
) -> Bool {
    if lhs.finishedAt != rhs.finishedAt {
        return lhs.finishedAt > rhs.finishedAt
    }
    return lhs.sessionID.rawValue < rhs.sessionID.rawValue
}

private func manifestSort(
    _ lhs: HistoryManifestRecordModel,
    _ rhs: HistoryManifestRecordModel
) -> Bool {
    if lhs.createdAt != rhs.createdAt {
        return lhs.createdAt > rhs.createdAt
    }
    return lhs.manifestID.rawValue < rhs.manifestID.rawValue
}

private func itemSort(
    _ lhs: HistoryItemModel,
    _ rhs: HistoryItemModel
) -> Bool {
    if lhs.eventAt != rhs.eventAt {
        return lhs.eventAt > rhs.eventAt
    }
    let typeOrder: (HistoryRecordID) -> Int = {
        switch $0 {
        case .quickScan:
            0
        case .cleanupManifest:
            1
        }
    }
    if typeOrder(lhs.id) != typeOrder(rhs.id) {
        return typeOrder(lhs.id) < typeOrder(rhs.id)
    }
    return lhs.id.rawValue < rhs.id.rawValue
}
