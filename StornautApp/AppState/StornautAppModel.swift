import Foundation
import Observation
import StornautCore

@MainActor
@Observable
final class StornautAppModel {
    private(set) var pageState: AppPageState
    private(set) var scanActivity: AppScanActivity
    private(set) var scanState: ScanFlowState
    private(set) var historyState: HistoryState
    private(set) var settingsState: SettingsState

    private let dependencies: AppDependencies
    private let reducer: AppPageReducer
    private let scanReducer: ScanFlowReducer
    private let now: @Sendable () -> Date
    private let refreshesServices: Bool
    private var refreshIsActive = false
    private var scanTask: Task<Void, Never>?
    private var elapsedTask: Task<Void, Never>?
    private var cancellationTask: Task<Void, Never>?
    private var scanGeneration: UInt64 = 0
    private var historyRefreshGeneration: UInt64?
    private var historyDeleteIsActive = false
    private var historyGeneration: UInt64 = 0
    private var settingsRefreshGeneration: UInt64?
    private var settingsMutationIsActive = false
    private var settingsGeneration: UInt64 = 0

    init(
        dependencies: AppDependencies,
        initialState: AppPageState = .empty,
        initialScanActivity: AppScanActivity = .idle,
        initialScanState: ScanFlowState? = nil,
        initialHistoryState: HistoryState = .idle,
        initialSettingsState: SettingsState = .idle,
        reducer: AppPageReducer = AppPageReducer(),
        scanReducer: ScanFlowReducer = ScanFlowReducer(),
        now: @escaping @Sendable () -> Date = Date.init,
        refreshesServices: Bool = true
    ) {
        self.dependencies = dependencies
        pageState = initialState
        scanActivity = initialScanActivity
        scanState = initialScanState
            ?? initialState.projection.map(ScanFlowState.retained)
            ?? .idle
        historyState = initialHistoryState
        settingsState = initialSettingsState
        if let language = initialSettingsState.snapshot?
            .preferences.language
        {
            StornautLocalization.apply(language)
        }
        self.reducer = reducer
        self.scanReducer = scanReducer
        self.now = now
        self.refreshesServices = refreshesServices
    }

    func refreshIfNeeded() async {
        guard refreshesServices else {
            return
        }
        await refresh()
    }

    func refresh() async {
        guard !refreshIsActive else {
            return
        }
        let previous = pageState
        let generation = scanGeneration
        refreshIsActive = true
        pageState = reducer.beginRefresh(previous: previous)
        defer { refreshIsActive = false }
        do {
            let projection = try await dependencies.loadLatestQuickScan()
            guard generation == scanGeneration else {
                return
            }
            pageState = reducer.loaded(
                projection,
                previous: pageState,
                now: now()
            )
            if !scanState.isActive {
                scanState = projection.map(ScanFlowState.retained)
                    ?? .idle
            }
        } catch is CancellationError {
            if generation == scanGeneration {
                pageState = previous
            }
        } catch {
            guard generation == scanGeneration else {
                return
            }
            pageState = reducer.failed(
                reasonKey: DomainToken(
                    rawValue: "app.state.store-unavailable"
                )!,
                previous: pageState,
                now: now()
            )
        }
    }

    func startQuickScan() {
        guard !scanState.isActive,
              scanTask == nil,
              cancellationTask == nil,
              !historyDeleteIsActive,
              !settingsMutationIsActive
        else {
            return
        }
        scanGeneration &+= 1
        historyGeneration &+= 1
        settingsGeneration &+= 1
        if historyRefreshGeneration != nil {
            historyState = historyState.page.map(HistoryState.loaded) ?? .idle
            historyRefreshGeneration = nil
        }
        if settingsRefreshGeneration != nil {
            settingsState = settingsState.snapshot.map(SettingsState.loaded)
                ?? .idle
            settingsRefreshGeneration = nil
        }
        scanState = scanReducer.started(
            previous: scanState,
            at: now(),
            rootPath: dependencies.quickScanRootPath
        )
        scanActivity = .active
        startElapsedUpdates()
        scanTask = Task { [weak self] in
            guard let self else {
                return
            }
            do {
                let configuration = try await self.dependencies
                    .loadQuickScanConfiguration()
                if let configuration {
                    self.scanState = self.scanReducer.configuredRoot(
                        state: self.scanState,
                        rootPath: configuration.rootPath
                    )
                }
            } catch {
                self.scanState = self.scanReducer.failed(
                    state: self.scanState,
                    reasonKey: token("scan.error.configuration")
                )
                self.pageState = self.scanFailurePageState()
                self.invalidateHistoryAfterScanAttempt()
                self.scanActivity = .idle
                self.elapsedTask?.cancel()
                self.elapsedTask = nil
                self.scanTask = nil
                return
            }
            await self.consumeQuickScan()
        }
    }

    func stopQuickScan() {
        guard scanState.phase == .active,
              cancellationTask == nil
        else {
            return
        }
        scanState = scanReducer.stopRequested(state: scanState)
        cancellationTask = Task { [weak self] in
            guard let self else {
                return
            }
            _ = await self.dependencies.cancelQuickScan()
            self.cancellationTask = nil
        }
    }

    func refreshHistoryIfNeeded() async {
        guard historyState.phase == .idle else {
            return
        }
        await refreshHistory()
    }

    func refreshHistory() async {
        guard historyRefreshGeneration == nil,
              !historyDeleteIsActive
        else {
            return
        }
        guard !scanState.isActive else {
            historyState = .failed(
                page: historyState.page,
                reasonKey: token("history.error.scanActiveRead")
            )
            return
        }
        let retained = historyState.page
        let generation = historyGeneration
        historyRefreshGeneration = generation
        historyState = .loading(retained)
        defer {
            if historyRefreshGeneration == generation {
                historyRefreshGeneration = nil
            }
        }
        do {
            let page = try await dependencies.loadScanHistory()
            guard generation == historyGeneration else {
                return
            }
            historyState = .loaded(page)
        } catch is CancellationError {
            if generation == historyGeneration {
                historyState = retained.map(HistoryState.loaded) ?? .idle
            }
        } catch {
            guard generation == historyGeneration else {
                return
            }
            historyState = .failed(
                page: retained,
                reasonKey: token("history.error.storeUnavailable")
            )
        }
    }

    func deleteHistorySession(
        _ sessionID: ScanSessionID
    ) async {
        guard !historyDeleteIsActive,
              historyRefreshGeneration == nil,
              let page = historyState.page
        else {
            return
        }
        guard !scanState.isActive else {
            historyState = .failed(
                page: page,
                reasonKey: token("history.error.scanActive")
            )
            return
        }
        historyDeleteIsActive = true
        historyGeneration &+= 1
        historyState = .deleting(sessionID, page: page)
        defer { historyDeleteIsActive = false }
        do {
            try await dependencies.deleteScanHistory(sessionID)
        } catch {
            historyState = .failed(
                page: page,
                reasonKey: token("history.error.deleteFailed")
            )
            return
        }
        let localPage = HistoryPage(
            records: page.records.filter {
                $0.session.id != sessionID
            },
            corruptSessionIDs: page.corruptSessionIDs,
            corruptLedgerSessionIDs: page.corruptLedgerSessionIDs.filter {
                $0 != sessionID.rawValue
            }
        )
        historyState = .loaded(localPage)
        do {
            historyState = .loaded(
                try await dependencies.loadScanHistory()
            )
        } catch {
            historyState = .failed(
                page: localPage,
                reasonKey: token("history.error.storeUnavailable")
            )
        }
        do {
            let projection = try await dependencies.loadLatestQuickScan()
            pageState = reducer.loaded(
                projection,
                previous: pageState,
                now: now()
            )
            if !scanState.isActive {
                scanState = projection.map(ScanFlowState.retained) ?? .idle
            }
        } catch {
            guard pageState.projection?.session.id == sessionID else {
                return
            }
            pageState = try! AppPageState(
                phase: .error,
                projection: nil,
                reasonKey: token("app.state.store-unavailable"),
                recoveryIntent: .retryLatestSnapshot,
                refreshedAt: now()
            )
            scanState = .idle
        }
    }

    func refreshSettingsIfNeeded() async {
        guard settingsState.phase == .idle else {
            return
        }
        await refreshSettings()
    }

    func refreshSettings() async {
        guard settingsRefreshGeneration == nil,
              !settingsMutationIsActive
        else {
            return
        }
        let retained = settingsState.snapshot
        let generation = settingsGeneration
        settingsRefreshGeneration = generation
        settingsState = .loading(retained)
        defer {
            if settingsRefreshGeneration == generation {
                settingsRefreshGeneration = nil
            }
        }
        do {
            let snapshot = try await dependencies.loadSettings()
            guard generation == settingsGeneration else {
                return
            }
            StornautLocalization.apply(snapshot.preferences.language)
            settingsState = .loaded(snapshot)
        } catch is CancellationError {
            if generation == settingsGeneration {
                settingsState = retained.map(SettingsState.loaded) ?? .idle
            }
        } catch {
            guard generation == settingsGeneration else {
                return
            }
            settingsState = .failed(
                snapshot: retained,
                reasonKey: token("settings.error.loadFailed")
            )
        }
    }

    func updateSettingsPreferences(
        _ preferences: SettingsPreferences
    ) async {
        guard beginSettingsMutation(.preferences) else {
            return
        }
        let previous = settingsState.snapshot
        defer { settingsMutationIsActive = false }
        do {
            try await dependencies.saveSettingsPreferences(preferences)
            StornautLocalization.apply(preferences.language)
            let base = previous ?? SettingsSnapshot.fallback(
                preferences: preferences,
                rootURL:
                    FileManager.default.homeDirectoryForCurrentUser,
                refreshedAt: now()
            )
            settingsState = .loaded(
                base.replacing(
                    preferences: preferences,
                    primaryRoot: primaryRootStatus(
                        for: preferences,
                        previous: previous
                    ),
                    refreshedAt: now()
                )
            )
        } catch {
            settingsState = .failed(
                snapshot: previous,
                reasonKey: token("settings.error.saveFailed")
            )
        }
    }

    func chooseSettingsPrimaryRoot() async {
        guard beginSettingsMutation(.root) else {
            return
        }
        let previous = settingsState.snapshot
        defer { settingsMutationIsActive = false }
        do {
            guard let preferences =
                try await dependencies.chooseSettingsPrimaryRoot()
            else {
                settingsState = previous.map(SettingsState.loaded) ?? .idle
                return
            }
            let persisted = (
                previous ?? SettingsSnapshot.fallback(
                    preferences: preferences,
                    rootURL:
                        FileManager.default.homeDirectoryForCurrentUser,
                    refreshedAt: now()
                )
            ).replacing(
                preferences: preferences,
                primaryRoot: primaryRootStatus(
                    for: preferences,
                    previous: previous
                ),
                refreshedAt: now()
            )
            settingsState = .loaded(persisted)
            let refreshed = try await dependencies.loadSettings()
            settingsState = .loaded(
                refreshed.replacing(
                    preferences: preferences,
                    refreshedAt: now()
                )
            )
        } catch {
            settingsState = .failed(
                snapshot: settingsState.snapshot ?? previous,
                reasonKey: token("settings.error.rootFailed")
            )
        }
    }

    func resetSettingsPrimaryRoot() async {
        guard let snapshot = settingsState.snapshot,
              let preferences = try? snapshot.preferences.replacing(
                  primaryRoot: .some(nil),
                  exclusions: []
              )
        else {
            return
        }
        await updateSettingsPreferences(preferences)
        await refreshSettings()
    }

    func chooseSettingsExclusion() async {
        guard beginSettingsMutation(.exclusion) else {
            return
        }
        let previous = settingsState.snapshot
        defer { settingsMutationIsActive = false }
        do {
            guard let preferences =
                try await dependencies.chooseSettingsExclusion()
            else {
                settingsState = previous.map(SettingsState.loaded) ?? .idle
                return
            }
            let base = previous ?? SettingsSnapshot.fallback(
                preferences: preferences,
                rootURL: FileManager.default.homeDirectoryForCurrentUser,
                refreshedAt: now()
            )
            settingsState = .loaded(
                base.replacing(
                    preferences: preferences,
                    refreshedAt: now()
                )
            )
        } catch {
            settingsState = .failed(
                snapshot: previous,
                reasonKey: token("settings.error.exclusionFailed")
            )
        }
    }

    func removeSettingsExclusion(
        _ exclusion: ScanExclusion
    ) async {
        guard let snapshot = settingsState.snapshot,
              let preferences = try? snapshot.preferences.replacing(
                  exclusions: snapshot.preferences.exclusions.filter {
                      $0 != exclusion
                  }
              )
        else {
            return
        }
        await updateSettingsPreferences(preferences)
    }

    func openFullDiskAccessSettings() async {
        guard await dependencies.openFullDiskAccessSettings() else {
            settingsState = .failed(
                snapshot: settingsState.snapshot,
                reasonKey: token("settings.error.systemSettingsFailed")
            )
            return
        }
    }

    func clearSettingsEvidence() async {
        guard beginSettingsMutation(.clearEvidence) else {
            return
        }
        let previous = settingsState.snapshot
        defer { settingsMutationIsActive = false }
        do {
            try await dependencies.clearSettingsEvidence()
            if let previous {
                settingsState = .loaded(
                    previous.replacing(
                        counts: SettingsRecordCounts(
                            evidence: 0,
                            manifests: previous.counts.manifests,
                            localKnowledge:
                                previous.counts.localKnowledge
                        ),
                        refreshedAt: now()
                    )
                )
            }
            pageState = .empty
            scanState = .idle
            historyGeneration &+= 1
            historyRefreshGeneration = nil
            historyState = .idle
        } catch {
            settingsState = .failed(
                snapshot: previous,
                reasonKey: token("settings.error.clearEvidenceFailed")
            )
        }
    }

    func clearSettingsManifests() async {
        guard beginSettingsMutation(.clearManifests) else {
            return
        }
        let previous = settingsState.snapshot
        defer { settingsMutationIsActive = false }
        do {
            try await dependencies.clearSettingsManifests()
            if let previous {
                settingsState = .loaded(
                    previous.replacing(
                        counts: SettingsRecordCounts(
                            evidence: previous.counts.evidence,
                            manifests: 0,
                            localKnowledge:
                                previous.counts.localKnowledge
                        ),
                        refreshedAt: now()
                    )
                )
            }
        } catch {
            settingsState = .failed(
                snapshot: previous,
                reasonKey: token("settings.error.clearManifestsFailed")
            )
        }
    }

    func forgetSettingsKnowledge(
        _ id: LocalKnowledgeID
    ) async {
        guard beginSettingsMutation(.forgetKnowledge) else {
            return
        }
        let previous = settingsState.snapshot
        defer { settingsMutationIsActive = false }
        do {
            try await dependencies.forgetSettingsKnowledge(id)
            if let previous {
                let knowledge = previous.knowledge.filter { $0.id != id }
                settingsState = .loaded(
                    previous.replacing(
                        counts: SettingsRecordCounts(
                            evidence: previous.counts.evidence,
                            manifests: previous.counts.manifests,
                            localKnowledge: max(
                                0,
                                previous.counts.localKnowledge
                                    - (
                                        knowledge.count
                                            < previous.knowledge.count ? 1 : 0
                                    )
                            )
                        ),
                        knowledge: knowledge,
                        refreshedAt: now()
                    )
                )
            }
        } catch {
            settingsState = .failed(
                snapshot: previous,
                reasonKey: token("settings.error.forgetFailed")
            )
        }
    }

    func forgetAllSettingsKnowledge() async {
        guard beginSettingsMutation(.forgetAllKnowledge) else {
            return
        }
        let previous = settingsState.snapshot
        defer { settingsMutationIsActive = false }
        do {
            try await dependencies.forgetAllSettingsKnowledge()
            if let previous {
                settingsState = .loaded(
                    previous.replacing(
                        counts: SettingsRecordCounts(
                            evidence: previous.counts.evidence,
                            manifests: previous.counts.manifests,
                            localKnowledge: 0
                        ),
                        knowledge: [],
                        corruptKnowledgeIDs: [],
                        refreshedAt: now()
                    )
                )
            }
        } catch {
            settingsState = .failed(
                snapshot: previous,
                reasonKey: token("settings.error.forgetAllFailed")
            )
        }
    }

    private func beginSettingsMutation(
        _ mutation: SettingsMutationKind
    ) -> Bool {
        guard !settingsMutationIsActive else {
            return false
        }
        guard !scanState.isActive else {
            settingsState = .failed(
                snapshot: settingsState.snapshot,
                reasonKey: token("settings.error.scanActive")
            )
            return false
        }
        settingsMutationIsActive = true
        settingsGeneration &+= 1
        settingsRefreshGeneration = nil
        if let snapshot = settingsState.snapshot {
            settingsState = .mutating(
                mutation,
                snapshot: snapshot
            )
        }
        return true
    }

    private func primaryRootStatus(
        for preferences: SettingsPreferences,
        previous: SettingsSnapshot?
    ) -> SettingsPrimaryRootStatus {
        if preferences.primaryRoot == previous?.preferences.primaryRoot,
           let status = previous?.primaryRoot
        {
            return status
        }
        if let bookmark = preferences.primaryRoot {
            return SettingsPrimaryRootStatus(
                path: bookmark.displayPath,
                availability: .available
            )
        }
        let fallback = dependencies.quickScanRootPath
            ?? PersistedPath(
                rawValue:
                    FileManager.default.homeDirectoryForCurrentUser.path
            )!
        return SettingsPrimaryRootStatus(
            path: fallback,
            availability: .fallbackHome
        )
    }

    private func consumeQuickScan() async {
        var streamStarted = false
        var terminalObserved = false
        defer {
            elapsedTask?.cancel()
            elapsedTask = nil
            scanActivity = .idle
            scanTask = nil
        }
        do {
            let stream = try await dependencies.startQuickScan()
            streamStarted = true
            if scanState.stopWasRequested {
                _ = await dependencies.cancelQuickScan()
            }
            for try await event in stream {
                scanState = scanReducer.reduce(
                    event,
                    state: scanState
                )
                if case let .terminal(projection) = event {
                    terminalObserved = true
                    elapsedTask?.cancel()
                    elapsedTask = nil
                    pageState = reducer.loaded(
                        projection,
                        previous: pageState,
                        now: now()
                    )
                    historyGeneration &+= 1
                    historyState = .idle
                    break
                }
            }
            if !terminalObserved {
                scanState = scanReducer.failed(
                    state: scanState,
                    reasonKey: token("scan.error.stream")
                )
                pageState = scanFailurePageState()
                invalidateHistoryAfterScanAttempt()
            }
        } catch {
            if !terminalObserved {
                scanState = scanReducer.failed(
                    state: scanState,
                    reasonKey: token(
                        streamStarted
                            ? "scan.error.stream"
                            : "scan.error.start"
                    )
                )
                pageState = scanFailurePageState()
                if streamStarted {
                    invalidateHistoryAfterScanAttempt()
                }
            }
        }
    }

    private func invalidateHistoryAfterScanAttempt() {
        historyGeneration &+= 1
        historyRefreshGeneration = nil
        historyState = .idle
    }

    private func startElapsedUpdates() {
        elapsedTask?.cancel()
        elapsedTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.scanState.isActive else {
                    return
                }
                self.scanState = self.scanReducer.elapsed(
                    state: self.scanState,
                    at: self.now()
                )
            }
        }
    }

    private func scanFailurePageState() -> AppPageState {
        reducer.failed(
            reasonKey: token("app.state.scan-failed"),
            previous: pageState,
            now: now()
        )
    }
}

private func token(_ rawValue: String) -> DomainToken {
    DomainToken(rawValue: rawValue)!
}
