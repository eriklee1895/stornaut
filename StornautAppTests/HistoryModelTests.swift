import Foundation
import StornautCore
import Testing
@testable import StornautApp

@Test
func historyProjectsEmptyAndStableDateGroupedRecords() throws {
    let now = HistoryTestFactory.now
    let records = try [
        HistoryTestFactory.record(
            slug: "today-complete",
            finishedAt: now.addingTimeInterval(-3_600),
            terminalState: .completed
        ),
        HistoryTestFactory.record(
            slug: "yesterday-partial",
            finishedAt: now.addingTimeInterval(-26 * 3_600),
            terminalState: .partial
        ),
        HistoryTestFactory.record(
            slug: "earlier-cancelled",
            finishedAt: now.addingTimeInterval(-3 * 86_400),
            terminalState: .cancelled
        ),
    ]

    let empty = HistoryModel(
        state: .loaded(.empty),
        now: now,
        calendar: HistoryTestFactory.calendar
    )
    #expect(empty.presentation == .empty)
    #expect(empty.groups.isEmpty)
    #expect(empty.selectedID == nil)

    let model = HistoryModel(
        state: .loaded(HistoryPage(records: records)),
        now: now,
        calendar: HistoryTestFactory.calendar
    )

    #expect(model.presentation == .loaded)
    #expect(model.records.map(\.sessionID.rawValue) == [
        "scan-today-complete",
        "scan-yesterday-partial",
        "scan-earlier-cancelled",
    ])
    #expect(model.groups.map(\.kind) == [.today, .yesterday, .earlier])
    #expect(model.selectedID == records[0].session.id)
}

@Test
func historySeparatesTerminalRetentionCoverageAndLedgerMeasures() throws {
    let now = HistoryTestFactory.now
    let expired = try HistoryTestFactory.record(
        slug: "expired-limited",
        finishedAt: now.addingTimeInterval(-8 * 86_400),
        terminalState: .partial,
        permissionGap: true
    )
    let model = HistoryModel(
        state: .loaded(HistoryPage(records: [expired])),
        now: now,
        calendar: HistoryTestFactory.calendar
    )
    let record = try #require(model.records.first)

    #expect(record.terminalState == .partial)
    #expect(record.retention.state == .expired)
    #expect(record.expiresAt
        == expired.session.finishedAt.addingTimeInterval(7 * 86_400))
    #expect(record.coverage == .limited)
    #expect(record.ledgerRows.map(\.kind) == [
        .known,
        .unknown,
        .unmeasurable,
        .free,
    ])
    #expect(
        record.ledgerRows.first {
            $0.kind == .unmeasurable
        }?.bytes == nil
    )
    #expect(record.ledgerRows.first { $0.kind == .free }?.bytes != nil)
}

@Test
func historyNeverFabricatesAScopeForAValidScopeLessSession() throws {
    let session = try ScanSession(
        id: ScanSessionID(rawValue: "scan-scope-unavailable")!,
        startedAt: HistoryTestFactory.now.addingTimeInterval(-60),
        finishedAt: HistoryTestFactory.now,
        terminalState: .failed,
        completedScopes: [],
        unfinishedScopes: []
    )
    let model = HistoryModel(
        state: .loaded(
            HistoryPage(
                records: [
                    HistoryRecord(session: session, ledger: nil),
                ]
            )
        ),
        now: HistoryTestFactory.now,
        calendar: HistoryTestFactory.calendar
    )

    let record = try #require(model.records.first)
    #expect(record.scopePath == nil)
    #expect(record.coverage == .unavailable)
}

@Test
func historyIsolatesCorruptSessionAndLedgerRecords() throws {
    let healthy = try HistoryTestFactory.record(
        slug: "healthy",
        finishedAt: HistoryTestFactory.now,
        terminalState: .completed
    )
    let missingLedger = try HistoryTestFactory.record(
        slug: "missing-ledger",
        finishedAt: HistoryTestFactory.now.addingTimeInterval(-60),
        terminalState: .partial,
        includesLedger: false
    )
    let page = HistoryPage(
        records: [healthy, missingLedger],
        corruptSessionIDs: ["scan-corrupt-session"],
        corruptLedgerSessionIDs: [healthy.session.id.rawValue]
    )
    let model = HistoryModel(
        state: .loaded(page),
        now: HistoryTestFactory.now,
        calendar: HistoryTestFactory.calendar
    )

    #expect(model.records.count == 2)
    #expect(
        model.records.first {
            $0.sessionID == healthy.session.id
        }?.ledgerStatus == .corrupt
    )
    #expect(
        model.records.first {
            $0.sessionID == missingLedger.session.id
        }?.ledgerStatus == .unavailable
    )
    #expect(model.corruptRecords.map(\.rawID) == ["scan-corrupt-session"])
    #expect(model.selectedID == missingLedger.session.id)
}

@Test
func historyNeverImpliesCorruptRowsMatchUnknownStatusOrDate() {
    let page = HistoryPage(
        records: [],
        corruptSessionIDs: ["scan-corrupt-session"]
    )
    let defaultModel = HistoryModel(
        state: .loaded(page),
        now: HistoryTestFactory.now,
        calendar: HistoryTestFactory.calendar
    )
    let matchingSearch = HistoryModel(
        state: .loaded(page),
        now: HistoryTestFactory.now,
        calendar: HistoryTestFactory.calendar,
        query: "corrupt-session"
    )
    let complete = HistoryModel(
        state: .loaded(page),
        now: HistoryTestFactory.now,
        calendar: HistoryTestFactory.calendar,
        terminalFilter: .complete
    )
    let today = HistoryModel(
        state: .loaded(page),
        now: HistoryTestFactory.now,
        calendar: HistoryTestFactory.calendar,
        dateFilter: .today
    )

    #expect(defaultModel.corruptRecords.map(\.rawID)
        == ["scan-corrupt-session"])
    #expect(matchingSearch.corruptRecords.map(\.rawID)
        == ["scan-corrupt-session"])
    #expect(complete.corruptRecords.isEmpty)
    #expect(complete.presentation == .noResults)
    #expect(today.corruptRecords.isEmpty)
    #expect(today.presentation == .noResults)
}

@Test
func historySearchStatusAndDateFiltersAreReadOnly() throws {
    let now = HistoryTestFactory.now
    let records = try [
        HistoryTestFactory.record(
            slug: "current-projects",
            rootPath: "/tmp/Projects",
            finishedAt: now.addingTimeInterval(-1_800),
            terminalState: .completed
        ),
        HistoryTestFactory.record(
            slug: "older-cache",
            rootPath: "/tmp/Cache",
            finishedAt: now.addingTimeInterval(-4 * 86_400),
            terminalState: .cancelled
        ),
    ]
    let page = HistoryPage(records: records)

    let search = HistoryModel(
        state: .loaded(page),
        now: now,
        calendar: HistoryTestFactory.calendar,
        query: "projects"
    )
    let stopped = HistoryModel(
        state: .loaded(page),
        now: now,
        calendar: HistoryTestFactory.calendar,
        terminalFilter: .stopped
    )
    let today = HistoryModel(
        state: .loaded(page),
        now: now,
        calendar: HistoryTestFactory.calendar,
        dateFilter: .today
    )

    #expect(search.records.compactMap(\.scopePath?.rawValue) == [
        "/tmp/Projects",
    ])
    #expect(stopped.records.map(\.terminalState) == [.cancelled])
    #expect(today.records.map(\.sessionID) == [records[0].session.id])
    #expect(page.records == records)
}

@Test
func historyDistinguishesNoMatchesFromNoPersistedHistory() throws {
    let record = try HistoryTestFactory.record(
        slug: "filter-no-match",
        finishedAt: HistoryTestFactory.now,
        terminalState: .completed
    )

    let empty = HistoryModel(
        state: .loaded(.empty),
        now: HistoryTestFactory.now,
        calendar: HistoryTestFactory.calendar
    )
    let noMatches = HistoryModel(
        state: .loaded(HistoryPage(records: [record])),
        now: HistoryTestFactory.now,
        calendar: HistoryTestFactory.calendar,
        query: "not-present"
    )

    #expect(empty.presentation == .empty)
    #expect(noMatches.presentation == .noResults)
    #expect(noMatches.records.isEmpty)
}

@Test
func storageTrendRequiresFourComparableCompletedSnapshots() throws {
    let now = HistoryTestFactory.now
    var three: [HistoryRecord] = []
    for index in 0..<3 {
        let offset = -Double(3 - index) * 86_400
        three.append(
            try HistoryTestFactory.record(
                slug: "trend-three-\(index)",
                finishedAt: now.addingTimeInterval(offset),
                terminalState: .completed
            )
        )
    }
    var four: [HistoryRecord] = []
    for index in 0..<4 {
        let offset = -Double(4 - index) * 86_400
        four.append(
            try HistoryTestFactory.record(
                slug: "trend-four-\(index)",
                finishedAt: now.addingTimeInterval(offset),
                terminalState: .completed,
                freeBytes: UInt64(300 + index * 50)
            )
        )
    }

    let unavailable = HistoryModel(
        state: .loaded(HistoryPage(records: three)),
        now: now,
        calendar: HistoryTestFactory.calendar
    )
    let available = HistoryModel(
        state: .loaded(HistoryPage(records: four)),
        now: now,
        calendar: HistoryTestFactory.calendar
    )

    #expect(unavailable.trend == nil)
    let trend: HistoryTrendModel = try #require(available.trend)
    #expect(trend.samples.count == 4)
    let dates = trend.samples.map { $0.finishedAt }
    #expect(dates == dates.sorted())
    #expect(trend.samples.allSatisfy {
        $0.usedBytes.value + $0.freeBytes.value == $0.capacityBytes.value
    })
    #expect(trend.causalityDisclaimerKey == "history.trend.nonCausal")
}

@Test
func storageTrendRejectsEstimatedCapacityOrFreeSamples() throws {
    let records = try (0..<4).map { index in
        try HistoryTestFactory.record(
            slug: "trend-estimated-\(index)",
            finishedAt: HistoryTestFactory.now.addingTimeInterval(
                -Double(4 - index) * 86_400
            ),
            terminalState: .completed
        )
    }
    let estimated = try HistoryTestFactory.withEstimatedFree(records[0])
    var mixed = records
    mixed[0] = estimated

    let model = HistoryModel(
        state: .loaded(HistoryPage(records: mixed)),
        now: HistoryTestFactory.now,
        calendar: HistoryTestFactory.calendar
    )

    #expect(estimated.ledger?.free.status == .estimated)
    #expect(model.trend == nil)
}

@Test
func storageTrendRequiresFourDistinctTimestamps() throws {
    let records = try (0..<4).map { index in
        try HistoryTestFactory.record(
            slug: "trend-duplicate-time-\(index)",
            finishedAt: HistoryTestFactory.now.addingTimeInterval(
                -Double(index / 2) * 86_400
            ),
            terminalState: .completed
        )
    }
    let model = HistoryModel(
        state: .loaded(HistoryPage(records: records)),
        now: HistoryTestFactory.now,
        calendar: HistoryTestFactory.calendar
    )

    #expect(Set(records.map(\.session.finishedAt)).count == 2)
    #expect(model.trend == nil)
}

@Test
func storageTrendRejectsInconsistentLedgerSamples() throws {
    let now = HistoryTestFactory.now
    var records: [HistoryRecord] = []
    for index in 0..<4 {
        records.append(
            try HistoryTestFactory.record(
                slug: "trend-inconsistent-\(index)",
                finishedAt: now.addingTimeInterval(
                    -Double(4 - index) * 86_400
                ),
                terminalState: .completed
            )
        )
    }
    let inconsistentProjection = try OverviewTestProjectionFactory.projection(
        slug: "history-trend-inconsistent",
        totalCapacity: 10_000
    )
    let inconsistent = try #require(inconsistentProjection.ledger)
    records[0] = HistoryRecord(
        session: inconsistentProjection.session,
        ledger: inconsistent
    )

    let model = HistoryModel(
        state: .loaded(HistoryPage(records: records)),
        now: now,
        calendar: HistoryTestFactory.calendar
    )

    #expect(inconsistent.status == .inconsistent)
    #expect(model.trend == nil)
}

@Test
func historyDeleteContractNamesOnlyEvidenceRecordEffects() throws {
    let record = try HistoryTestFactory.record(
        slug: "delete-contract",
        finishedAt: HistoryTestFactory.now,
        terminalState: .completed
    )
    let model = HistoryModel(
        state: .loaded(HistoryPage(records: [record])),
        now: HistoryTestFactory.now,
        calendar: HistoryTestFactory.calendar
    )
    let contract = try #require(model.deleteContract(for: record.session.id))

    #expect(contract.sessionID == record.session.id)
    #expect(contract.altersScannedFiles == false)
    #expect(contract.altersTrash == false)
    #expect(contract.altersLocalKnowledge == false)
    #expect(contract.isUndoable == false)
}

@Test
func historyLocalizationKeysResolveInBothLanguages() throws {
    let bundle = try #require(Bundle(identifier: "com.eriklee.stornaut"))

    for language in ["en", "zh-Hans"] {
        let path = try #require(
            bundle.path(forResource: language, ofType: "lproj")
        )
        let localized = try #require(Bundle(path: path))

        for key in HistoryLocalizationKeys.all {
            #expect(
                localized.localizedString(
                    forKey: key,
                    value: nil,
                    table: nil
                ) != key
            )
        }
    }
}

private enum HistoryLocalizationKeys {
    static let all = [
        "history.title",
        "history.subtitle",
        "history.search",
        "history.filter.status.all",
        "history.filter.date.allRetained",
        "history.group.today",
        "history.group.yesterday",
        "history.group.earlier",
        "history.noResults.title",
        "history.noResults.message",
        "history.record.quickScan",
        "history.status.completed",
        "history.status.partial",
        "history.corrupt.title",
        "history.detail.session",
        "history.detail.ledger",
        "history.detail.related",
        "history.scope.unavailable",
        "history.ledger.known",
        "history.ledger.unknown",
        "history.ledger.unmeasurable",
        "history.ledger.free",
        "history.action.delete",
        "history.delete.confirm.title",
        "history.delete.confirm.message",
        "history.trend.title",
        "history.trend.nonCausal",
    ]
}

private enum HistoryTestFactory {
    static let now = Date(timeIntervalSince1970: 1_786_449_600)
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static func record(
        slug: String,
        rootPath: String? = nil,
        finishedAt: Date,
        terminalState: ScanTerminalState,
        permissionGap: Bool = false,
        includesLedger: Bool = true,
        freeBytes: UInt64 = 400
    ) throws -> HistoryRecord {
        let sessionID = ScanSessionID(rawValue: "scan-\(slug)")!
        let scopeID = ScanScopeID(rawValue: "scope-\(slug)")!
        let path = PersistedPath(
            rawValue: rootPath ?? "/tmp/\(slug)"
        )!
        let session = try ScanSession(
            id: sessionID,
            startedAt: finishedAt.addingTimeInterval(-60),
            finishedAt: finishedAt,
            terminalState: terminalState,
            completedScopes: terminalState == .completed
                ? [
                    ScanScope(
                        id: scopeID,
                        rootPath: path,
                        completedAt: finishedAt
                    ),
                ]
                : [],
            unfinishedScopes: terminalState == .completed
                ? []
                : [
                    UnfinishedScanScope(
                        id: scopeID,
                        rootPath: path,
                        reason: permissionGap
                            ? .permissionDenied
                            : terminalState == .cancelled
                                ? .cancelled
                                : terminalState == .failed
                                    ? .storeFailure
                                    : .metadataChanged
                    ),
                ]
        )
        return HistoryRecord(
            session: session,
            ledger: includesLedger
                ? try ledger(
                    session: session,
                    scopeID: scopeID,
                    rootPath: path,
                    permissionGap: permissionGap,
                    freeBytes: freeBytes
                )
                : nil
        )
    }

    private static func ledger(
        session: ScanSession,
        scopeID: ScanScopeID,
        rootPath: PersistedPath,
        permissionGap: Bool,
        freeBytes: UInt64
    ) throws -> SpaceLedger {
        let identity = try FileIdentity(
            device: 1,
            inode: 1,
            mode: UInt16(S_IFDIR | 0o755),
            ownerUserID: getuid(),
            ownerGroupID: getgid(),
            size: 0,
            allocatedBytes: 0,
            modificationSeconds: Int64(session.finishedAt.timeIntervalSince1970),
            modificationNanoseconds: 0
        )
        let start = try VolumeBaseline(
            sessionID: session.id,
            scopeID: scopeID,
            rootPath: rootPath,
            rootIdentity: identity,
            totalCapacity: ByteCount(1_000),
            availableCapacity: ByteCount(min(1_000, freeBytes + 20)),
            availableCapacityForImportantUsage: nil,
            availableCapacityForOpportunisticUsage: nil,
            volumeIsReadOnly: false,
            source: source(
                id: "history.start",
                at: session.startedAt
            )
        )
        let end = try VolumeBaseline(
            sessionID: session.id,
            scopeID: scopeID,
            rootPath: rootPath,
            rootIdentity: identity,
            totalCapacity: ByteCount(1_000),
            availableCapacity: ByteCount(freeBytes),
            availableCapacityForImportantUsage: nil,
            availableCapacityForOpportunisticUsage: nil,
            volumeIsReadOnly: false,
            source: source(
                id: "history.end",
                at: session.finishedAt
            )
        )
        let snapshot: PathSnapshot
        if permissionGap {
            snapshot = try PathSnapshot(
                id: SnapshotID(rawValue: "snapshot-\(session.id.rawValue)-gap")!,
                sessionID: session.id,
                scopeID: scopeID,
                relativePath: "Restricted",
                kind: .inaccessible,
                logicalByteCount: nil,
                allocatedByteCount: nil,
                modifiedAt: nil,
                fileIdentity: nil,
                symlinkTarget: nil,
                measurementStatus: .permissionDenied,
                observedAt: session.finishedAt
            )
        } else {
            snapshot = try PathSnapshot(
                id: SnapshotID(rawValue: "snapshot-\(session.id.rawValue)-root")!,
                sessionID: session.id,
                scopeID: scopeID,
                relativePath: ".",
                kind: .directory,
                logicalByteCount: ByteCount(0),
                allocatedByteCount: ByteCount(0),
                modifiedAt: session.finishedAt,
                fileIdentity: identity,
                symlinkTarget: nil,
                measurementStatus: .measured,
                observedAt: session.finishedAt
            )
        }
        return try SpaceLedgerReconciler().reconcile(
            SpaceLedgerInput(
                startBaseline: start,
                endBaseline: end,
                snapshots: [snapshot],
                classifications: []
            )
        )
    }

    private static func source(
        id: String,
        at date: Date
    ) -> AccountingSource {
        AccountingSource(
            kind: .volumeResourceValues,
            identifier: DomainToken(rawValue: id)!,
            sampledAt: date
        )
    }

    static func withEstimatedFree(
        _ record: HistoryRecord
    ) throws -> HistoryRecord {
        let ledger = try #require(record.ledger)
        let data = try DomainJSON.encode(ledger)
        var object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var free = try #require(object["free"] as? [String: Any])
        free["status"] = AccountingMeasurementStatus.estimated.rawValue
        object["free"] = free
        object["status"] = SpaceLedgerStatus.partial.rawValue
        return HistoryRecord(
            session: record.session,
            ledger: try DomainJSON.decode(
                SpaceLedger.self,
                from: JSONSerialization.data(withJSONObject: object)
            )
        )
    }
}
