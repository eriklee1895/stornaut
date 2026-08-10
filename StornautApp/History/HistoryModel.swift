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

struct HistoryDateGroup: Identifiable, Sendable, Equatable {
    let kind: HistoryDateGroupKind
    let records: [HistoryRecordModel]

    var id: HistoryDateGroupKind { kind }
}

struct HistoryCorruptRecord: Identifiable, Sendable, Equatable {
    let rawID: String

    var id: String { rawID }
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
    let causalityDisclaimerKey: String
}

struct HistoryDeleteContract: Sendable, Equatable {
    let sessionID: ScanSessionID
    let isUndoable: Bool
    let altersScannedFiles: Bool
    let altersTrash: Bool
    let altersLocalKnowledge: Bool
}

struct HistoryModel: Sendable, Equatable {
    let presentation: HistoryPresentation
    let records: [HistoryRecordModel]
    let groups: [HistoryDateGroup]
    let corruptRecords: [HistoryCorruptRecord]
    let selectedID: ScanSessionID?
    let trend: HistoryTrendModel?
    let deletingSessionID: ScanSessionID?
    let reasonKey: DomainToken?

    init(
        state: HistoryState,
        now: Date,
        calendar: Calendar,
        query: String = "",
        terminalFilter: HistoryTerminalFilter = .all,
        dateFilter: HistoryDateFilter = .allRetained,
        selectedID: ScanSessionID? = nil
    ) {
        reasonKey = state.reasonKey
        deletingSessionID = state.deletingSessionID
        let page = state.page ?? .empty
        let corruptLedgerIDs = Set(page.corruptLedgerSessionIDs)
        let projected = page.records.map {
            Self.project(
                $0,
                now: now,
                ledgerIsCorrupt: corruptLedgerIDs.contains(
                    $0.session.id.rawValue
                )
            )
        }.sorted(by: recordSort)
        let normalizedQuery = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let filteredRecords = projected.filter { record in
            terminalFilter.includes(record.terminalState)
                && Self.dateFilter(
                    dateFilter,
                    includes: record.finishedAt,
                    now: now,
                    calendar: calendar
                )
                && (
                    normalizedQuery.isEmpty
                        || record.sessionID.rawValue
                            .localizedCaseInsensitiveContains(
                                normalizedQuery
                            )
                        || record.scopePath?.rawValue
                            .localizedCaseInsensitiveContains(
                                normalizedQuery
                            ) == true
                )
        }
        records = filteredRecords
        let groupOrder: [HistoryDateGroupKind] = [
            .today,
            .yesterday,
            .earlier,
        ]
        groups = groupOrder.compactMap { kind in
            let values = filteredRecords.filter {
                Self.dateGroup(
                    for: $0.finishedAt,
                    now: now,
                    calendar: calendar
                ) == kind
            }
            return values.isEmpty
                ? nil
                : HistoryDateGroup(kind: kind, records: values)
        }
        let projectedCorruptRecords: [HistoryCorruptRecord]
        if terminalFilter == .all, dateFilter == .allRetained {
            projectedCorruptRecords = page.corruptSessionIDs.compactMap {
                normalizedQuery.isEmpty
                    || $0.localizedCaseInsensitiveContains(normalizedQuery)
                    ? HistoryCorruptRecord(rawID: $0)
                    : nil
            }
        } else {
            projectedCorruptRecords = []
        }
        corruptRecords = projectedCorruptRecords
        let projectedPresentation: HistoryPresentation
        switch state.phase {
        case .idle:
            projectedPresentation = .empty
        case .loading:
            projectedPresentation = .loading
        case .loaded:
            if filteredRecords.isEmpty && projectedCorruptRecords.isEmpty {
                projectedPresentation = page.records.isEmpty
                    && page.corruptSessionIDs.isEmpty
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
        let visibleIDs = Set(filteredRecords.map(\.id))
        let healthySelection = selectedID.flatMap {
            visibleIDs.contains($0) ? $0 : nil
        }
        self.selectedID = healthySelection ?? filteredRecords.first {
            $0.ledgerStatus != .corrupt
        }?.id ?? filteredRecords.first?.id
        trend = Self.trend(from: projected)
        presentation = projectedPresentation
    }

    func deleteContract(
        for sessionID: ScanSessionID
    ) -> HistoryDeleteContract? {
        guard records.contains(where: { $0.id == sessionID }) else {
            return nil
        }
        return HistoryDeleteContract(
            sessionID: sessionID,
            isUndoable: false,
            altersScannedFiles: false,
            altersTrash: false,
            altersLocalKnowledge: false
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
        from records: [HistoryRecordModel]
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
