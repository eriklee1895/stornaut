import Foundation
import StornautCore
import Testing
@testable import StornautApp

@MainActor
@Test
func appModelLoadsAndSavesClosedSettingsPreferences() async throws {
    let driver = SettingsAppTestDriver(
        snapshot: try SettingsAppTestFactory.snapshot()
    )
    let model = settingsAppModel(driver: driver)

    await model.refreshSettings()
    #expect(model.settingsState.phase == .loaded)
    #expect(model.settingsState.snapshot?.preferences == .defaults)

    let updated = try SettingsPreferences(
        language: .simplifiedChinese,
        appearance: .dark,
        investigationBudget: .focused
    )
    await model.updateSettingsPreferences(updated)

    #expect(await driver.savedPreferences == [updated])
    #expect(model.settingsState.phase == .loaded)
    #expect(model.settingsState.snapshot?.preferences == updated)
}

@MainActor
@Test
func activeQuickScanRejectsSettingsMutationAndEvidenceClear() async throws {
    let driver = SettingsAppTestDriver(
        snapshot: try SettingsAppTestFactory.snapshot()
    )
    let stream = AsyncThrowingStream<QuickScanProductEvent, Error> { _ in }
    let model = StornautAppModel(
        dependencies: settingsDependencies(
            driver: driver,
            startQuickScan: { stream }
        ),
        initialSettingsState: .loaded(
            try SettingsAppTestFactory.snapshot()
        ),
        now: { SettingsAppTestFactory.now },
        refreshesServices: false
    )
    model.startQuickScan()
    await Task.yield()

    await model.updateSettingsPreferences(
        try SettingsPreferences(appearance: .dark)
    )
    await model.clearSettingsEvidence()

    #expect(await driver.savedPreferences.isEmpty)
    #expect(await driver.clearEvidenceCount == 0)
    #expect(
        model.settingsState.reasonKey?.rawValue
            == "settings.error.scanActive"
    )
}

@MainActor
@Test
func clearEvidenceInvalidatesOverviewScanAndHistoryWithoutTouchingManifests()
    async throws
{
    let projection = try OverviewTestProjectionFactory.projection(
        slug: "settings-clear-evidence"
    )
    let driver = SettingsAppTestDriver(
        snapshot: try SettingsAppTestFactory.snapshot(
            counts: SettingsRecordCounts(
                evidence: 2,
                manifests: 3,
                localKnowledge: 1
            )
        )
    )
    let model = StornautAppModel(
        dependencies: settingsDependencies(driver: driver),
        initialState: try .success(
            projection: projection,
            refreshedAt: SettingsAppTestFactory.now
        ),
        initialScanState: .retained(projection),
        initialHistoryState: .loaded(
            HistoryPage(
                records: [
                    HistoryRecord(
                        session: projection.session,
                        ledger: projection.ledger
                    ),
                ]
            )
        ),
        initialSettingsState: .loaded(await driver.snapshot),
        now: { SettingsAppTestFactory.now },
        refreshesServices: false
    )

    await model.clearSettingsEvidence()

    #expect(await driver.clearEvidenceCount == 1)
    #expect(await driver.clearManifestsCount == 0)
    #expect(model.pageState == .empty)
    #expect(model.scanState == .idle)
    #expect(model.historyState == .idle)
    #expect(model.settingsState.snapshot?.counts.evidence == 0)
    #expect(model.settingsState.snapshot?.counts.manifests == 3)
}

@MainActor
@Test
func forgetKnowledgeUpdatesOnlyKnowledgePage() async throws {
    let fact = try SettingsAppTestFactory.fact(
        catalogVersion: "builtin-runtime-tool-residue-v1"
    )
    let driver = SettingsAppTestDriver(
        snapshot: try SettingsAppTestFactory.snapshot(
            knowledge: [fact],
            counts: SettingsRecordCounts(
                evidence: 3,
                manifests: 2,
                localKnowledge: 101
            )
        )
    )
    let model = settingsAppModel(driver: driver)
    await model.refreshSettings()

    await model.forgetSettingsKnowledge(fact.id)

    #expect(await driver.forgottenKnowledgeIDs == [fact.id])
    #expect(model.settingsState.snapshot?.knowledge.isEmpty == true)
    #expect(model.settingsState.snapshot?.counts.localKnowledge == 100)
}

@MainActor
@Test
func staleSettingsRefreshCannotOverwriteNewPreferenceMutation() async throws {
    let loader = SuspendedSettingsLoader(
        snapshot: try SettingsAppTestFactory.snapshot()
    )
    let saved = try SettingsPreferences(appearance: .dark)
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            loadSettings: { await loader.load() },
            saveSettingsPreferences: { _ in }
        ),
        initialSettingsState: .loaded(
            try SettingsAppTestFactory.snapshot()
        ),
        now: { SettingsAppTestFactory.now },
        refreshesServices: false
    )

    let refresh = Task { @MainActor in
        await model.refreshSettings()
    }
    await loader.waitUntilStarted()
    await model.updateSettingsPreferences(saved)
    await loader.resume()
    await refresh.value

    #expect(model.settingsState.snapshot?.preferences == saved)
}

@MainActor
@Test
func startingScanRestoresRetainedSettingsWhileRefreshFinishesStale()
    async throws
{
    let initial = try SettingsAppTestFactory.snapshot()
    let loader = SuspendedSettingsLoader(snapshot: initial)
    let stream = AsyncThrowingStream<QuickScanProductEvent, Error> {
        continuation in
        continuation.finish()
    }
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            startQuickScan: { stream },
            loadSettings: { await loader.load() }
        ),
        initialSettingsState: .loaded(initial),
        now: { SettingsAppTestFactory.now },
        refreshesServices: false
    )

    let refresh = Task { @MainActor in
        await model.refreshSettings()
    }
    await loader.waitUntilStarted()
    model.startQuickScan()
    await loader.resume()
    await refresh.value

    #expect(model.settingsState.phase == .loaded)
    #expect(model.settingsState.snapshot == initial)
}

@MainActor
@Test
func rootSelectionKeepsPersistedRootWhenFactsReloadFails() async throws {
    let initial = try SettingsAppTestFactory.snapshot()
    let bookmark = try SettingsPrimaryRootBookmark(
        data: Data([0x01]),
        displayPath: PersistedPath(rawValue: "/tmp/new-settings-root")!
    )
    let updated = try initial.preferences.replacing(
        primaryRoot: .some(bookmark),
        exclusions: []
    )
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            quickScanRootPath: PersistedPath(
                rawValue: "/tmp/fallback-settings-root"
            ),
            loadSettings: {
                throw SettingsAppTestError.unavailable
            },
            chooseSettingsPrimaryRoot: { updated }
        ),
        initialSettingsState: .loaded(initial),
        now: { SettingsAppTestFactory.now },
        refreshesServices: false
    )

    await model.chooseSettingsPrimaryRoot()

    #expect(model.settingsState.phase == .error)
    #expect(model.settingsState.snapshot?.preferences == updated)
    #expect(
        model.settingsState.snapshot?.primaryRoot
            == SettingsPrimaryRootStatus(
                path: bookmark.displayPath,
                availability: .available
            )
    )
}

@MainActor
private func settingsAppModel(
    driver: SettingsAppTestDriver
) -> StornautAppModel {
    StornautAppModel(
        dependencies: settingsDependencies(driver: driver),
        now: { SettingsAppTestFactory.now },
        refreshesServices: false
    )
}

private func settingsDependencies(
    driver: SettingsAppTestDriver,
    startQuickScan: @escaping @Sendable () async throws
        -> AppDependencies.QuickScanStream = {
            throw SettingsAppTestError.unavailable
        }
) -> AppDependencies {
    AppDependencies(
        loadLatestQuickScan: { nil },
        startQuickScan: startQuickScan,
        loadSettings: { await driver.load() },
        saveSettingsPreferences: { await driver.save($0) },
        clearSettingsEvidence: { await driver.clearEvidence() },
        clearSettingsManifests: { await driver.clearManifests() },
        forgetSettingsKnowledge: { await driver.forget($0) },
        forgetAllSettingsKnowledge: { await driver.forgetAll() }
    )
}

private actor SettingsAppTestDriver {
    private(set) var snapshot: SettingsSnapshot
    private(set) var savedPreferences: [SettingsPreferences] = []
    private(set) var clearEvidenceCount = 0
    private(set) var clearManifestsCount = 0
    private(set) var forgottenKnowledgeIDs: [LocalKnowledgeID] = []

    init(snapshot: SettingsSnapshot) {
        self.snapshot = snapshot
    }

    func load() -> SettingsSnapshot {
        snapshot
    }

    func save(_ preferences: SettingsPreferences) {
        savedPreferences.append(preferences)
        snapshot = snapshot.replacing(preferences: preferences)
    }

    func clearEvidence() {
        clearEvidenceCount += 1
        snapshot = snapshot.replacing(
            counts: SettingsRecordCounts(
                evidence: 0,
                manifests: snapshot.counts.manifests,
                localKnowledge: snapshot.counts.localKnowledge
            )
        )
    }

    func clearManifests() {
        clearManifestsCount += 1
        snapshot = snapshot.replacing(
            counts: SettingsRecordCounts(
                evidence: snapshot.counts.evidence,
                manifests: 0,
                localKnowledge: snapshot.counts.localKnowledge
            )
        )
    }

    func forget(_ id: LocalKnowledgeID) {
        forgottenKnowledgeIDs.append(id)
        let knowledge = snapshot.knowledge.filter { $0.id != id }
        snapshot = snapshot.replacing(
            counts: SettingsRecordCounts(
                evidence: snapshot.counts.evidence,
                manifests: snapshot.counts.manifests,
                localKnowledge: max(
                    0,
                    snapshot.counts.localKnowledge
                        - (
                            knowledge.count < snapshot.knowledge.count
                                ? 1
                                : 0
                        )
                )
            ),
            knowledge: knowledge
        )
    }

    func forgetAll() {
        let counts = snapshot.counts
        snapshot = snapshot.replacing(
            counts: SettingsRecordCounts(
                evidence: counts.evidence,
                manifests: counts.manifests,
                localKnowledge: 0
            ),
            knowledge: []
        )
    }
}

private actor SuspendedSettingsLoader {
    private let snapshot: SettingsSnapshot
    private var continuation: CheckedContinuation<Void, Never>?

    init(snapshot: SettingsSnapshot) {
        self.snapshot = snapshot
    }

    func load() async -> SettingsSnapshot {
        await withCheckedContinuation {
            continuation = $0
        }
        return snapshot
    }

    func waitUntilStarted() async {
        while continuation == nil {
            await Task.yield()
        }
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}

private enum SettingsAppTestError: Error {
    case unavailable
}
