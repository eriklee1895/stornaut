import Foundation
import StornautCore
import Testing
@testable import StornautApp

@MainActor
@Test
func appModelLoadsHistoryThroughTypedDependencyAndPreservesOnFailure()
    async throws
{
    let first = try HistoryAppTestFactory.record(slug: "first")
    let loader = HistoryAppTestLoader(
        results: [
            .success(HistoryPage(records: [first])),
            .failure(HistoryAppTestError.unavailable),
        ]
    )
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            loadScanHistory: { try await loader.load() }
        ),
        now: { HistoryAppTestFactory.now },
        refreshesServices: false
    )

    await model.refreshHistory()
    #expect(model.historyState.phase == .loaded)
    #expect(model.historyState.page?.records == [first])

    await model.refreshHistory()
    #expect(model.historyState.phase == .error)
    #expect(model.historyState.page?.records == [first])
    #expect(
        model.historyState.reasonKey?.rawValue
            == "history.error.storeUnavailable"
    )
}

@MainActor
@Test
func appModelConfirmedHistoryDeletionReloadsAndMovesPastDeletedRecord()
    async throws
{
    let newest = try HistoryAppTestFactory.record(slug: "newest")
    let older = try HistoryAppTestFactory.record(
        slug: "older",
        finishedAt: HistoryAppTestFactory.now.addingTimeInterval(-60)
    )
    let driver = HistoryAppTestDriver(records: [newest, older])
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            loadScanHistory: { await driver.load() },
            deleteScanHistory: { await driver.delete($0) }
        ),
        now: { HistoryAppTestFactory.now },
        refreshesServices: false
    )
    await model.refreshHistory()

    await model.deleteHistorySession(newest.session.id)

    #expect(await driver.deletedIDs == [newest.session.id])
    #expect(model.historyState.phase == .loaded)
    #expect(model.historyState.page?.records == [older])
    let projected = HistoryModel(
        state: model.historyState,
        now: HistoryAppTestFactory.now,
        calendar: HistoryAppTestFactory.calendar,
        selectedID: newest.session.id
    )
    #expect(projected.selectedID == older.session.id)
}

@MainActor
@Test
func appModelHistoryDeletionFailsClosedDuringActiveScan() async throws {
    let record = try HistoryAppTestFactory.record(slug: "active-scan")
    let driver = HistoryAppTestDriver(records: [record])
    let stream = AsyncThrowingStream<QuickScanProductEvent, Error> { _ in }
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            startQuickScan: { stream },
            cancelQuickScan: { false },
            loadScanHistory: { await driver.load() },
            deleteScanHistory: { await driver.delete($0) }
        ),
        now: { HistoryAppTestFactory.now },
        refreshesServices: false
    )
    await model.refreshHistory()
    model.startQuickScan()
    await Task.yield()

    await model.deleteHistorySession(record.session.id)

    #expect(await driver.deletedIDs.isEmpty)
    #expect(model.historyState.page?.records == [record])
    #expect(
        model.historyState.reasonKey?.rawValue
            == "history.error.scanActive"
    )
}

@MainActor
@Test
func staleHistoryRefreshCannotOverwriteNewScanInvalidation() async throws {
    let record = try HistoryAppTestFactory.record(slug: "stale-refresh")
    let loader = SuspendedHistoryLoader(
        page: HistoryPage(records: [record])
    )
    let stream = AsyncThrowingStream<QuickScanProductEvent, Error> { _ in }
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            startQuickScan: { stream },
            cancelQuickScan: { false },
            loadScanHistory: { await loader.load() }
        ),
        now: { HistoryAppTestFactory.now },
        refreshesServices: false
    )

    let refresh = Task { @MainActor in
        await model.refreshHistory()
    }
    await loader.waitUntilStarted()
    model.startQuickScan()
    await loader.resume()
    await refresh.value

    #expect(model.scanState.phase == .active)
    #expect(model.historyState.phase != .loaded)
    #expect(model.historyState.page?.records != [record])
}

@MainActor
@Test
func quickScanStartFailureReleasesAnInvalidatedHistoryRefresh() async throws {
    let record = try HistoryAppTestFactory.record(
        slug: "refresh-start-failure"
    )
    let loader = SuspendedHistoryLoader(
        page: HistoryPage(records: [record])
    )
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            startQuickScan: {
                throw HistoryAppTestError.unavailable
            },
            loadScanHistory: { await loader.load() }
        ),
        initialHistoryState: .loaded(
            HistoryPage(records: [record])
        ),
        now: { HistoryAppTestFactory.now },
        refreshesServices: false
    )

    let refresh = Task { @MainActor in
        await model.refreshHistory()
    }
    await loader.waitUntilStarted()
    model.startQuickScan()
    await loader.resume()
    await refresh.value
    await waitUntil {
        model.scanState.phase == .failed
    }

    #expect(model.historyState.phase != .loading)
    #expect(model.historyState.page?.records == [record])
}

@MainActor
@Test
func invalidatedHistoryRefreshCannotBlockOrOverwriteItsReplacement()
    async throws
{
    let retained = try HistoryAppTestFactory.record(slug: "retained")
    let replacement = try HistoryAppTestFactory.record(slug: "replacement")
    let loader = ReplacingHistoryLoader(
        replacement: HistoryPage(records: [replacement])
    )
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            startQuickScan: {
                throw HistoryAppTestError.unavailable
            },
            loadScanHistory: { await loader.load() }
        ),
        initialHistoryState: .loaded(
            HistoryPage(records: [retained])
        ),
        now: { HistoryAppTestFactory.now },
        refreshesServices: false
    )

    let staleRefresh = Task { @MainActor in
        await model.refreshHistory()
    }
    await loader.waitUntilFirstStarted()
    model.startQuickScan()
    await waitUntil {
        model.scanState.phase == .failed
    }

    await model.refreshHistory()

    #expect(await loader.callCount == 2)
    #expect(model.historyState.phase == .loaded)
    #expect(model.historyState.page?.records == [replacement])

    await loader.resumeFirst()
    await staleRefresh.value

    #expect(model.historyState.phase == .loaded)
    #expect(model.historyState.page?.records == [replacement])
}

private actor HistoryAppTestLoader {
    private var results: [Result<HistoryPage, any Error>]

    init(results: [Result<HistoryPage, any Error>]) {
        self.results = results
    }

    func load() throws -> HistoryPage {
        try results.removeFirst().get()
    }
}

private actor HistoryAppTestDriver {
    private var records: [HistoryRecord]
    private(set) var deletedIDs: [ScanSessionID] = []

    init(records: [HistoryRecord]) {
        self.records = records
    }

    func load() -> HistoryPage {
        HistoryPage(records: records)
    }

    func delete(_ sessionID: ScanSessionID) {
        deletedIDs.append(sessionID)
        records.removeAll { $0.session.id == sessionID }
    }
}

private actor SuspendedHistoryLoader {
    private let page: HistoryPage
    private var continuation: CheckedContinuation<Void, Never>?
    private var started = false

    init(page: HistoryPage) {
        self.page = page
    }

    func load() async -> HistoryPage {
        started = true
        await withCheckedContinuation {
            continuation = $0
        }
        return page
    }

    func waitUntilStarted() async {
        while !started {
            await Task.yield()
        }
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}

private actor ReplacingHistoryLoader {
    private let replacement: HistoryPage
    private var firstContinuation:
        CheckedContinuation<Void, Never>?
    private(set) var callCount = 0

    init(replacement: HistoryPage) {
        self.replacement = replacement
    }

    func load() async -> HistoryPage {
        callCount += 1
        if callCount == 1 {
            await withCheckedContinuation {
                firstContinuation = $0
            }
            return .empty
        }
        return replacement
    }

    func waitUntilFirstStarted() async {
        while callCount == 0 || firstContinuation == nil {
            await Task.yield()
        }
    }

    func resumeFirst() {
        firstContinuation?.resume()
        firstContinuation = nil
    }
}

private enum HistoryAppTestFactory {
    static let now = Date(timeIntervalSince1970: 1_786_406_400)
    static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    static func record(
        slug: String,
        finishedAt: Date = now
    ) throws -> HistoryRecord {
        let projection = try OverviewTestProjectionFactory.projection(
            slug: "history-\(slug)"
        )
        let session = try ScanSession(
            id: projection.session.id,
            startedAt: finishedAt.addingTimeInterval(-60),
            finishedAt: finishedAt,
            terminalState: .completed,
            completedScopes: projection.session.completedScopes.map {
                ScanScope(
                    id: $0.id,
                    rootPath: $0.rootPath,
                    completedAt: finishedAt
                )
            },
            unfinishedScopes: []
        )
        let ledger = try #require(projection.ledger)
        let data = try DomainJSON.encode(ledger)
        var object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        object["sessionID"] = session.id.rawValue
        let adjusted = try DomainJSON.decode(
            SpaceLedger.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        return HistoryRecord(session: session, ledger: adjusted)
    }
}

private enum HistoryAppTestError: Error {
    case unavailable
}

@MainActor
private func waitUntil(
    timeout: TimeInterval = 2,
    condition: () -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition(), Date() < deadline {
        await Task.yield()
    }
}
