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
func appModelConfirmedManifestDeletionKeepsScanAndDeletesOnlyManifest()
    async throws
{
    let scan = try HistoryAppTestFactory.record(slug: "manifest-neighbor")
    let fixture = try CleanupResultTestSupport.fixture(.completed)
    let manifestRecord = CleanupManifestHistoryRecord(
        manifest: fixture.result.manifest,
        linkedPlan: fixture.plan,
        evidenceAvailability: .retained
    )
    let driver = HistoryManifestAppTestDriver(
        scans: [scan],
        manifests: [manifestRecord]
    )
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            loadScanHistory: { await driver.load() },
            deleteScanHistory: { await driver.deleteScan($0) },
            deleteManifestHistory: { await driver.deleteManifest($0) }
        ),
        now: { HistoryAppTestFactory.now },
        refreshesServices: false
    )
    await model.refreshHistory()

    await model.deleteHistoryRecord(
        .cleanupManifest(fixture.result.manifest.id)
    )

    #expect(await driver.deletedScanIDs.isEmpty)
    #expect(await driver.deletedManifestIDs == [
        fixture.result.manifest.id,
    ])
    #expect(model.historyState.page?.records == [scan])
    #expect(model.historyState.page?.manifests.isEmpty == true)
}

@MainActor
@Test
func manifestDeletionReloadCannotOverwriteLaterEvidenceClear() async throws {
    let fixture = try CleanupResultTestSupport.fixture(.completed)
    let manifestRecord = CleanupManifestHistoryRecord(
        manifest: fixture.result.manifest,
        linkedPlan: fixture.plan,
        evidenceAvailability: .retained
    )
    let stalePage = HistoryPage(
        records: [],
        manifests: [manifestRecord]
    )
    let loader = SuspendedHistoryDeleteReload(page: stalePage)
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            loadScanHistory: { await loader.load() },
            deleteManifestHistory: { _ in },
            clearSettingsEvidence: {}
        ),
        initialHistoryState: .loaded(stalePage),
        initialSettingsState: .loaded(
            try SettingsAppTestFactory.snapshot()
        ),
        now: { HistoryAppTestFactory.now },
        refreshesServices: false
    )

    let deletion = Task { @MainActor in
        await model.deleteHistoryRecord(
            HistoryRecordID.cleanupManifest(
                fixture.result.manifest.id
            )
        )
    }
    await loader.waitUntilStarted()
    await model.clearSettingsEvidence()
    await loader.resume()
    await deletion.value

    #expect(model.historyState == HistoryState.idle)
}

@MainActor
@Test
func historyDeletionSuccessCannotRestoreHistoryAfterEvidenceClear()
    async throws
{
    let record = try HistoryAppTestFactory.record(
        slug: "delete-success-stale-history"
    )
    let page = HistoryPage(records: [record])
    let deleter = SuspendedHistoryDeleter(shouldFail: false)
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            loadScanHistory: { .empty },
            deleteScanHistory: {
                try await deleter.delete($0)
            },
            clearSettingsEvidence: {}
        ),
        initialHistoryState: .loaded(page),
        initialSettingsState: .loaded(
            try SettingsAppTestFactory.snapshot()
        ),
        now: { HistoryAppTestFactory.now },
        refreshesServices: false
    )

    let deletion = Task { @MainActor in
        await model.deleteHistorySession(record.session.id)
    }
    await deleter.waitUntilStarted()
    await model.clearSettingsEvidence()
    await deleter.resume()
    await deletion.value

    #expect(model.historyState == HistoryState.idle)
}

@MainActor
@Test
func historyDeletionFailureCannotRestoreHistoryAfterEvidenceClear()
    async throws
{
    let record = try HistoryAppTestFactory.record(
        slug: "delete-failure-stale-history"
    )
    let page = HistoryPage(records: [record])
    let deleter = SuspendedHistoryDeleter(shouldFail: true)
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            deleteScanHistory: {
                try await deleter.delete($0)
            },
            clearSettingsEvidence: {}
        ),
        initialHistoryState: .loaded(page),
        initialSettingsState: .loaded(
            try SettingsAppTestFactory.snapshot()
        ),
        now: { HistoryAppTestFactory.now },
        refreshesServices: false
    )

    let deletion = Task { @MainActor in
        await model.deleteHistorySession(record.session.id)
    }
    await deleter.waitUntilStarted()
    await model.clearSettingsEvidence()
    await deleter.resume()
    await deletion.value

    #expect(model.historyState == HistoryState.idle)
}

@MainActor
@Test
func scanDeletionOverviewReloadCannotOverwriteLaterEvidenceClear()
    async throws
{
    let record = try HistoryAppTestFactory.record(
        slug: "scan-delete-stale-overview"
    )
    let projection = try OverviewTestProjectionFactory.projection(
        slug: "scan-delete-stale-overview"
    )
    let loader = SuspendedDeletionOverviewLoader(projection: projection)
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { await loader.load() },
            loadScanHistory: { .empty },
            deleteScanHistory: { _ in },
            clearSettingsEvidence: {}
        ),
        initialHistoryState: .loaded(
            HistoryPage(records: [record])
        ),
        initialSettingsState: .loaded(
            try SettingsAppTestFactory.snapshot()
        ),
        now: { HistoryAppTestFactory.now },
        refreshesServices: false
    )

    let deletion = Task { @MainActor in
        await model.deleteHistorySession(record.session.id)
    }
    await loader.waitUntilStarted()
    await model.clearSettingsEvidence()
    await loader.resume()
    await deletion.value

    #expect(model.pageState == .empty)
    #expect(model.scanState == .idle)
}

@MainActor
@Test
func exportFailureCannotRestoreHistoryAfterEvidenceClear() async throws {
    let record = try HistoryAppTestFactory.record(
        slug: "export-failure-stale-history"
    )
    let page = HistoryPage(records: [record])
    let item = try #require(
        HistoryModel(
            state: .loaded(page),
            now: HistoryAppTestFactory.now,
            calendar: HistoryAppTestFactory.calendar
        ).items.first
    )
    let exporter = SuspendedFailingHistoryExporter()
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            exportHistory: {
                try await exporter.export($0)
            },
            clearSettingsEvidence: {}
        ),
        initialHistoryState: .loaded(page),
        initialSettingsState: .loaded(
            try SettingsAppTestFactory.snapshot()
        ),
        now: { HistoryAppTestFactory.now },
        refreshesServices: false
    )

    let export = Task { @MainActor in
        await model.exportHistoryRecord(item.id)
    }
    await exporter.waitUntilStarted()
    await model.clearSettingsEvidence()
    await exporter.resume()
    await export.value

    #expect(model.historyState == HistoryState.idle)
}

@MainActor
@Test
func exportFailureCannotOverwriteNewerHistoryRefresh() async throws {
    let stale = try HistoryAppTestFactory.record(
        slug: "export-failure-stale-refresh"
    )
    let refreshed = try HistoryAppTestFactory.record(
        slug: "export-failure-newer-refresh"
    )
    let stalePage = HistoryPage(records: [stale])
    let refreshedPage = HistoryPage(records: [refreshed])
    let exporter = SuspendedFailingHistoryExporter()
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            loadScanHistory: { refreshedPage },
            exportHistory: {
                try await exporter.export($0)
            }
        ),
        initialHistoryState: .loaded(stalePage),
        now: { HistoryAppTestFactory.now },
        refreshesServices: false
    )

    let export = Task { @MainActor in
        await model.exportHistoryRecord(.quickScan(stale.session.id))
    }
    await exporter.waitUntilStarted()
    await model.refreshHistory()
    #expect(model.historyState == .loaded(refreshedPage))

    await exporter.resume()
    await export.value

    #expect(model.historyState == .loaded(refreshedPage))
}

@MainActor
@Test
func historyExportReprojectsLoadedManifestAfterPlanExpiry() async throws {
    let fixture = try CleanupResultTestSupport.fixture(.completed)
    let page = HistoryPage(
        records: [],
        manifests: [
            CleanupManifestHistoryRecord(
                manifest: fixture.result.manifest,
                linkedPlan: fixture.plan,
                evidenceAvailability: .retained
            ),
        ]
    )
    let clock = HistoryAppTestClock(
        fixture.plan.expiresAt.addingTimeInterval(-1)
    )
    let item = try #require(
        HistoryModel(
            state: .loaded(page),
            now: clock.now(),
            calendar: HistoryAppTestFactory.calendar
        ).items.first
    )
    let exporter = CapturingHistoryExporter()
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            exportHistory: {
                await exporter.export($0)
            }
        ),
        initialHistoryState: .loaded(page),
        now: clock.now,
        refreshesServices: false
    )

    clock.set(fixture.plan.expiresAt)
    await model.exportHistoryRecord(item.id)

    let document = try #require(await exporter.document)
    let object = try #require(
        JSONSerialization.jsonObject(with: document.data)
            as? [String: Any]
    )
    let manifest = try #require(
        object["cleanupManifest"] as? [String: Any]
    )
    let records = try #require(
        manifest["records"] as? [[String: Any]]
    )
    #expect(manifest["evidenceAvailability"] as? String == "expired")
    for record in records {
        #expect(record["itemName"] == nil)
        #expect(record["relativePath"] == nil)
    }
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

private actor HistoryManifestAppTestDriver {
    private var scans: [HistoryRecord]
    private var manifests: [CleanupManifestHistoryRecord]
    private(set) var deletedScanIDs: [ScanSessionID] = []
    private(set) var deletedManifestIDs: [CleanupManifestID] = []

    init(
        scans: [HistoryRecord],
        manifests: [CleanupManifestHistoryRecord]
    ) {
        self.scans = scans
        self.manifests = manifests
    }

    func load() -> HistoryPage {
        HistoryPage(records: scans, manifests: manifests)
    }

    func deleteScan(_ id: ScanSessionID) {
        deletedScanIDs.append(id)
        scans.removeAll { $0.session.id == id }
    }

    func deleteManifest(_ id: CleanupManifestID) {
        deletedManifestIDs.append(id)
        manifests.removeAll { $0.manifest.id == id }
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

private actor SuspendedHistoryDeleteReload {
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

private actor SuspendedHistoryDeleter {
    private let shouldFail: Bool
    private var continuation: CheckedContinuation<Void, Never>?
    private var started = false

    init(shouldFail: Bool) {
        self.shouldFail = shouldFail
    }

    func delete(_ id: ScanSessionID) async throws {
        _ = id
        started = true
        await withCheckedContinuation {
            continuation = $0
        }
        if shouldFail {
            throw HistoryAppTestError.unavailable
        }
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

private actor SuspendedDeletionOverviewLoader {
    private let projection: QuickScanProjection
    private var continuation: CheckedContinuation<Void, Never>?
    private var started = false

    init(projection: QuickScanProjection) {
        self.projection = projection
    }

    func load() async -> QuickScanProjection {
        started = true
        await withCheckedContinuation {
            continuation = $0
        }
        return projection
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

private actor SuspendedFailingHistoryExporter {
    private var continuation: CheckedContinuation<Void, Never>?
    private var started = false

    func export(_ document: HistoryExportDocument) async throws -> Bool {
        _ = document
        started = true
        await withCheckedContinuation {
            continuation = $0
        }
        throw HistoryAppTestError.unavailable
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

private actor CapturingHistoryExporter {
    private(set) var document: HistoryExportDocument?

    func export(_ document: HistoryExportDocument) -> Bool {
        self.document = document
        return true
    }
}

private final class HistoryAppTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date

    init(_ value: Date) {
        self.value = value
    }

    func now() -> Date {
        lock.withLock { value }
    }

    func set(_ value: Date) {
        lock.withLock {
            self.value = value
        }
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
