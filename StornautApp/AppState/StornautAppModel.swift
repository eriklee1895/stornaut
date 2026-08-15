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
    private(set) var scanWorkspaceRoute: ScanWorkspaceRoute
    private(set) var reviewState: ReviewState
    private(set) var reviewStaleSheetIsPresented: Bool
    private(set) var cleanupResultState: CleanupResultState

    private let dependencies: AppDependencies
    private let reducer: AppPageReducer
    private let scanReducer: ScanFlowReducer
    private let reviewReducer: ReviewReducer
    private let cleanupResultReducer: CleanupResultReducer
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
    private var reviewTask: Task<Void, Never>?
    private var reviewExecutionTask: Task<Void, Never>?
    private var reviewStopIsPending = false
    private var reviewGeneration: UInt64 = 0
    private var reviewExecutionGeneration: UInt64 = 0
    private var cleanupResultTask: Task<Void, Never>?
    private var cleanupResultGeneration: UInt64 = 0

    init(
        dependencies: AppDependencies,
        initialState: AppPageState = .empty,
        initialScanActivity: AppScanActivity = .idle,
        initialScanState: ScanFlowState? = nil,
        initialHistoryState: HistoryState = .idle,
        initialSettingsState: SettingsState = .idle,
        initialScanWorkspaceRoute: ScanWorkspaceRoute = .results,
        initialReviewState: ReviewState = .idle,
        initialCleanupResultState: CleanupResultState = .idle,
        reducer: AppPageReducer = AppPageReducer(),
        scanReducer: ScanFlowReducer = ScanFlowReducer(),
        reviewReducer: ReviewReducer = ReviewReducer(),
        cleanupResultReducer:
            CleanupResultReducer = CleanupResultReducer(),
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
        scanWorkspaceRoute = initialScanWorkspaceRoute
        reviewState = initialReviewState
        reviewStaleSheetIsPresented = initialReviewState.stale != nil
        cleanupResultState = initialCleanupResultState
        if let language = initialSettingsState.snapshot?
            .preferences.language
        {
            StornautLocalization.apply(language)
        }
        self.reducer = reducer
        self.scanReducer = scanReducer
        self.reviewReducer = reviewReducer
        self.cleanupResultReducer = cleanupResultReducer
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
              reviewTask == nil,
              reviewExecutionTask == nil,
              !historyDeleteIsActive,
              !settingsMutationIsActive
        else {
            return
        }
        scanGeneration &+= 1
        scanWorkspaceRoute = .results
        reviewState = .idle
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

    func openReview() {
        guard scanWorkspaceRoute == .results,
              reviewTask == nil,
              reviewExecutionTask == nil,
              !scanState.isActive,
              !historyDeleteIsActive,
              !settingsMutationIsActive
        else {
            return
        }
        cleanupResultState = .idle
        scanWorkspaceRoute = ReviewRouteReducer().openReview(
            from: scanWorkspaceRoute
        )
        reviewStaleSheetIsPresented = false
        reviewState = reviewReducer.beginLoading(previous: reviewState)
        reviewGeneration &+= 1
        let generation = reviewGeneration
        reviewTask = Task { [weak self] in
            guard let self else { return }
            let outcome = await self.dependencies.buildReview()
            guard !Task.isCancelled,
                  self.reviewGeneration == generation,
                  self.scanWorkspaceRoute == .review
            else {
                return
            }
            self.reviewState = self.reviewReducer.loaded(
                outcome,
                previous: self.reviewState,
                executionAvailability:
                    self.dependencies.reviewExecutionAvailability
            )
            if self.reviewGeneration == generation {
                self.reviewTask = nil
            }
        }
    }

    func closeReview() {
        guard reviewExecutionTask == nil else {
            return
        }
        reviewGeneration &+= 1
        reviewTask?.cancel()
        reviewTask = nil
        reviewStaleSheetIsPresented = false
        switch reviewState {
        case let .loading(snapshot):
            reviewState = snapshot.map(ReviewState.ready) ?? .idle
        case let .preflighting(snapshot):
            reviewState = .ready(snapshot)
        default:
            break
        }
        scanWorkspaceRoute = ReviewRouteReducer().closeReview(
            from: scanWorkspaceRoute
        )
    }

    func focusReviewRow(_ classificationID: ClassificationID?) {
        guard let snapshot = reviewState.snapshot else { return }
        replaceReviewSnapshot(snapshot.focusing(classificationID))
    }

    func setReviewSelection(
        classificationID: ClassificationID,
        isSelected: Bool
    ) {
        guard case let .ready(snapshot) = reviewState,
              let updated = try? snapshot.settingSelection(
                  classificationID: classificationID,
                  isSelected: isSelected
              )
        else {
            return
        }
        replaceReviewSnapshot(updated)
    }

    func preflightReview() {
        guard scanWorkspaceRoute == .review,
              reviewTask == nil,
              reviewExecutionTask == nil,
              case let .ready(snapshot) = reviewState,
              let selection = snapshot.reviewSelection
        else {
            return
        }
        reviewState = reviewReducer.beginPreflight(state: reviewState)
        reviewStaleSheetIsPresented = false
        reviewGeneration &+= 1
        let generation = reviewGeneration
        reviewTask = Task { [weak self] in
            guard let self else { return }
            do {
                let evaluation = try await self.dependencies
                    .preflightReview(snapshot.plan, selection)
                guard !Task.isCancelled,
                      self.reviewGeneration == generation,
                      self.scanWorkspaceRoute == .review
                else {
                    return
                }
                self.reviewState = self.reviewReducer.preflightCompleted(
                    evaluation,
                    state: self.reviewState
                )
                self.reviewStaleSheetIsPresented =
                    self.reviewState.phase == .stale
            } catch {
                guard !Task.isCancelled,
                      self.reviewGeneration == generation,
                      self.scanWorkspaceRoute == .review
                else {
                    return
                }
                self.reviewState = .unavailable([
                    token("review.unavailable.preflight"),
                ])
            }
            if self.reviewGeneration == generation {
                self.reviewTask = nil
            }
        }
    }

    func cancelReviewSheet() {
        switch reviewState {
        case let .confirming(snapshot, _):
            reviewState = .ready(snapshot)
        case .stale:
            reviewStaleSheetIsPresented = false
        default:
            break
        }
    }

    func refreshStaleReview() {
        guard case .stale = reviewState else { return }
        reviewStaleSheetIsPresented = false
        reviewState = .idle
        scanWorkspaceRoute = .results
        openReview()
    }

    func confirmReviewExecution() {
        guard reviewExecutionTask == nil,
              case let .confirming(snapshot, confirmation) = reviewState,
              let selection = snapshot.reviewSelection
        else {
            return
        }
        let next = reviewReducer.confirmExecution(state: reviewState)
        reviewState = next
        guard case .executing = next else {
            return
        }
        reviewExecutionGeneration &+= 1
        let executionGeneration = reviewExecutionGeneration
        reviewExecutionTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.reviewExecutionGeneration == executionGeneration {
                    self.reviewExecutionTask = nil
                }
            }
            do {
                let stream = try await self.dependencies
                    .startReviewExecution(
                        snapshot.plan,
                        selection,
                        confirmation
                    )
                var acceptedTerminal = false
                eventLoop: for await event in stream {
                    guard !Task.isCancelled else { return }
                    switch event {
                    case let .progress(progress):
                        guard !acceptedTerminal,
                              self.scanWorkspaceRoute == .review,
                              !self.reviewState
                                .stopAfterCurrentWasRequested
                        else {
                            continue
                        }
                        self.reviewState = .executing(snapshot, progress)
                    case let .terminal(executionState):
                        guard !acceptedTerminal,
                              self.scanWorkspaceRoute == .review,
                              let result = executionState.cleanupResult,
                              Self.matches(
                                  result: result,
                                  snapshot: snapshot,
                                  selection: selection,
                                  confirmation: confirmation
                              )
                        else {
                            continue
                        }
                        let enrichment = await self.dependencies
                            .cleanupResultEnrichment(result)
                        guard !Task.isCancelled,
                              self.reviewExecutionGeneration
                                == executionGeneration,
                              self.scanWorkspaceRoute == .review,
                              Self.matches(
                                  enrichment: enrichment,
                                  snapshot: snapshot
                              )
                        else {
                            continue
                        }
                        let next = self.cleanupResultReducer
                            .receivedTerminal(
                                executionState,
                                itemFacts: enrichment.itemFacts,
                                evidenceAvailability:
                                    enrichment.evidenceAvailability,
                                state: self.cleanupResultState
                            )
                        guard next.phase == .presented else {
                            continue
                        }
                        acceptedTerminal = true
                        self.cleanupResultState = next
                        self.scanWorkspaceRoute = ReviewRouteReducer()
                            .openCleanupResult(
                                from: self.scanWorkspaceRoute,
                                terminalWasAccepted: true
                            )
                        break eventLoop
                    }
                }
                if !acceptedTerminal,
                   self.scanWorkspaceRoute == .review
                {
                    self.reviewState = .executionBlocked(
                        snapshot,
                        .missingTerminal
                    )
                }
            } catch {
                if self.reviewExecutionGeneration == executionGeneration,
                   self.scanWorkspaceRoute == .review
                {
                    self.reviewState = .executionBlocked(
                        snapshot,
                        .writeDisabled
                    )
                }
            }
        }
    }

    func doneCleanupResult() {
        reviewExecutionGeneration &+= 1
        reviewExecutionTask?.cancel()
        reviewExecutionTask = nil
        cleanupResultGeneration &+= 1
        cleanupResultTask?.cancel()
        cleanupResultTask = nil
        cleanupResultState = cleanupResultReducer.done(
            state: cleanupResultState
        )
        reviewState = .idle
        reviewStaleSheetIsPresented = false
        scanWorkspaceRoute = ReviewRouteReducer()
            .closeCleanupResult(from: scanWorkspaceRoute)
    }

    func openTrashFromCleanupResult() {
        guard cleanupResultTask == nil,
              cleanupResultState.phase == .presented
                    || cleanupResultState.phase == .trashUnavailable
        else {
            return
        }
        if cleanupResultState.phase == .trashUnavailable {
            cleanupResultState = cleanupResultReducer
                .dismissTrashFailure(state: cleanupResultState)
        }
        let opening = cleanupResultReducer.beginOpenTrash(
            state: cleanupResultState
        )
        guard opening.phase == .openingTrash else { return }
        cleanupResultState = opening
        cleanupResultGeneration &+= 1
        let generation = cleanupResultGeneration
        cleanupResultTask = Task { [weak self] in
            guard let self else { return }
            let succeeded = await self.dependencies.openTrash()
            guard generation == self.cleanupResultGeneration else {
                return
            }
            self.cleanupResultState = self.cleanupResultReducer
                .openTrashFinished(
                    succeeded: succeeded,
                    state: self.cleanupResultState
                )
            self.cleanupResultTask = nil
        }
    }

    func dismissCleanupResultTrashFailure() {
        guard cleanupResultTask == nil else { return }
        cleanupResultState = cleanupResultReducer
            .dismissTrashFailure(state: cleanupResultState)
    }

    func retryCleanupResultAudit() {
        guard cleanupResultTask == nil,
              let snapshot = cleanupResultState.snapshot
        else {
            return
        }
        let retrying = cleanupResultReducer.beginAuditRetry(
            state: cleanupResultState
        )
        guard retrying.phase == .retryingAudit else { return }
        cleanupResultState = retrying
        cleanupResultGeneration &+= 1
        let generation = cleanupResultGeneration
        cleanupResultTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.dependencies
                .retryCleanupAudit(snapshot.result)
            guard generation == self.cleanupResultGeneration else {
                return
            }
            self.cleanupResultState = self.cleanupResultReducer
                .auditRetryFinished(
                    result,
                    state: self.cleanupResultState
                )
            self.cleanupResultTask = nil
        }
    }

    func stopReviewAfterCurrent() {
        guard reviewState.phase == .executing,
              !reviewState.stopAfterCurrentWasRequested,
              !reviewStopIsPending,
              let snapshot = reviewState.snapshot
        else {
            return
        }
        reviewStopIsPending = true
        let total = snapshot.selectedCount
        reviewState = .executing(
            snapshot,
            .stopRequested(completed: 0, total: total)
        )
        Task { [weak self] in
            guard let self else { return }
            await self.dependencies.stopReviewAfterCurrent()
            self.reviewStopIsPending = false
        }
    }

    func cancelReviewExecutionWait() {
        guard reviewState.stopAfterCurrentWasRequested,
              let snapshot = reviewState.snapshot
        else {
            return
        }
        reviewExecutionGeneration &+= 1
        reviewExecutionTask?.cancel()
        reviewExecutionTask = nil
        reviewStopIsPending = false
        reviewState = .executionBlocked(
            snapshot,
            .missingTerminal
        )
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
        historyGeneration &+= 1
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
        await deleteHistoryRecord(.quickScan(sessionID))
    }

    func deleteHistoryRecord(
        _ recordID: HistoryRecordID
    ) async {
        guard !historyDeleteIsActive,
              historyRefreshGeneration == nil,
              let page = historyState.page
        else {
            return
        }
        guard !scanState.isActive,
              scanWorkspaceRoute == .results,
              reviewTask == nil,
              reviewExecutionTask == nil
        else {
            historyState = .failed(
                page: page,
                reasonKey: token("history.error.scanActive")
            )
            return
        }
        historyDeleteIsActive = true
        historyGeneration &+= 1
        let deletionGeneration = historyGeneration
        historyState = .deleting(recordID, page: page)
        defer { historyDeleteIsActive = false }
        do {
            switch recordID {
            case let .quickScan(sessionID):
                try await dependencies.deleteScanHistory(sessionID)
            case let .cleanupManifest(manifestID):
                try await dependencies.deleteManifestHistory(manifestID)
            }
        } catch {
            guard deletionGeneration == historyGeneration else {
                return
            }
            historyState = .failed(
                page: page,
                reasonKey: token("history.error.deleteFailed")
            )
            return
        }
        guard deletionGeneration == historyGeneration else {
            return
        }
        let localPage: HistoryPage = switch recordID {
        case let .quickScan(sessionID):
            HistoryPage(
                records: page.records.filter {
                    $0.session.id != sessionID
                },
                manifests: page.manifests,
                corruptSessionIDs: page.corruptSessionIDs,
                corruptLedgerSessionIDs:
                    page.corruptLedgerSessionIDs.filter {
                        $0 != sessionID.rawValue
                    },
                corruptManifestIDs: page.corruptManifestIDs
            )
        case let .cleanupManifest(manifestID):
            HistoryPage(
                records: page.records,
                manifests: page.manifests.filter {
                    $0.manifest.id != manifestID
                },
                corruptSessionIDs: page.corruptSessionIDs,
                corruptLedgerSessionIDs: page.corruptLedgerSessionIDs,
                corruptManifestIDs:
                    page.corruptManifestIDs.filter {
                        $0 != manifestID.rawValue
                    }
            )
        }
        historyState = .loaded(localPage)
        do {
            let reloaded = try await dependencies.loadScanHistory()
            guard deletionGeneration == historyGeneration else {
                return
            }
            historyState = .loaded(reloaded)
        } catch {
            guard deletionGeneration == historyGeneration else {
                return
            }
            historyState = .failed(
                page: localPage,
                reasonKey: token("history.error.storeUnavailable")
            )
        }
        guard case let .quickScan(sessionID) = recordID else {
            return
        }
        do {
            let projection = try await dependencies.loadLatestQuickScan()
            guard deletionGeneration == historyGeneration else {
                return
            }
            pageState = reducer.loaded(
                projection,
                previous: pageState,
                now: now()
            )
            if !scanState.isActive {
                scanState = projection.map(ScanFlowState.retained) ?? .idle
            }
        } catch {
            guard deletionGeneration == historyGeneration,
                  pageState.projection?.session.id == sessionID
            else {
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

    func exportHistoryRecord(
        _ recordID: HistoryRecordID
    ) async {
        guard let page = historyState.page else {
            return
        }
        let exportGeneration = historyGeneration
        let currentProjection = HistoryModel(
            state: historyState,
            now: now(),
            calendar: .autoupdatingCurrent,
            selectedRecordID: recordID
        )
        guard let item = currentProjection.items.first(where: {
            $0.id == recordID
        }) else {
            return
        }
        let retentionIsExpired = switch item {
        case let .quickScan(record):
            record.retention.state == .expired
        case let .cleanupManifest(record):
            record.retention.state == .expired
        }
        guard !retentionIsExpired else {
            return
        }
        do {
            let document = try HistoryExport.document(
                for: item,
                homeDirectory:
                    FileManager.default.homeDirectoryForCurrentUser
            )
            _ = try await dependencies.exportHistory(document)
        } catch {
            guard exportGeneration == historyGeneration else {
                return
            }
            historyState = .failed(
                page: page,
                reasonKey: token("history.error.exportFailed")
            )
        }
    }

    func refreshSettingsIfNeeded() async {
        guard refreshesServices,
              settingsState.phase == .idle
        else {
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
            scanGeneration &+= 1
            invalidateReviewWorkflow()
            invalidateCleanupResultWorkflow()
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
            invalidateCleanupResultWorkflow()
            historyGeneration &+= 1
            historyRefreshGeneration = nil
            if let page = historyState.page {
                historyState = .loaded(
                    HistoryPage(
                        records: page.records,
                        corruptSessionIDs: page.corruptSessionIDs,
                        corruptLedgerSessionIDs:
                            page.corruptLedgerSessionIDs
                    )
                )
            } else {
                historyState = .idle
            }
        } catch {
            settingsState = .failed(
                snapshot: previous,
                reasonKey: token("settings.error.clearManifestsFailed")
            )
        }
    }

    private func invalidateReviewWorkflow() {
        reviewGeneration &+= 1
        reviewTask?.cancel()
        reviewTask = nil
        reviewExecutionGeneration &+= 1
        reviewExecutionTask?.cancel()
        reviewExecutionTask = nil
        reviewStopIsPending = false
        reviewState = .idle
        reviewStaleSheetIsPresented = false
        scanWorkspaceRoute = .results
    }

    private func invalidateCleanupResultWorkflow() {
        cleanupResultGeneration &+= 1
        cleanupResultTask?.cancel()
        cleanupResultTask = nil
        cleanupResultState = .idle
        if scanWorkspaceRoute == .cleanupResult {
            scanWorkspaceRoute = .results
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
        guard !scanState.isActive,
              reviewTask == nil,
              reviewExecutionTask == nil
        else {
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

    private func replaceReviewSnapshot(_ snapshot: ReviewSnapshot) {
        switch reviewState {
        case .ready:
            reviewState = .ready(snapshot)
        case .loading:
            reviewState = .loading(snapshot)
        case .preflighting:
            reviewState = .preflighting(snapshot)
        case let .stale(_, stale):
            reviewState = .stale(snapshot, stale)
        case let .confirming(_, confirmation):
            reviewState = .confirming(snapshot, confirmation)
        case let .executing(_, progress):
            reviewState = .executing(snapshot, progress)
        case let .executionBlocked(_, reason):
            reviewState = .executionBlocked(snapshot, reason)
        case .idle, .empty, .scanAgain, .unavailable:
            break
        }
    }

    private static func matches(
        result: CleanupExecutionResult,
        snapshot: ReviewSnapshot,
        selection: ReviewSelection,
        confirmation: CleanupConfirmation
    ) -> Bool {
        let selectedItems = selection.items.compactMap { selected in
            snapshot.plan.items.first {
                $0.id == selected.itemID
            }
        }
        guard selectedItems.count == selection.items.count,
              result.manifest.planID == snapshot.plan.id,
              result.journal.selectionGeneration == selection.generation,
              result.journal.selectionFingerprint == selection.fingerprint,
              result.manifest.records.map(\.planItemID)
                == selection.items.map(\.itemID),
              confirmation.planID == snapshot.plan.id,
              confirmation.selectionGeneration == selection.generation,
              confirmation.orderedItemIDs
                == selection.items.map(\.itemID),
              confirmation.itemCount == selection.items.count,
              confirmation.action == .moveToTrash,
              confirmation.planFingerprint
                == snapshot.plan.planFingerprint,
              confirmation.selectionFingerprint == selection.fingerprint,
              confirmation.logicalBytes
                == result.manifest.summary.selectedLogicalBytes,
              confirmation.allocatedBytes
                == result.manifest.summary.selectedAllocatedBytes,
              result.journal.entries.count == selectedItems.count
        else {
            return false
        }
        return zip(
            result.journal.entries,
            selectedItems
        ).allSatisfy { entry, item in
            guard let expectedIdentity = item.expectedIdentity,
                  let logicalBytes = item.logicalBytes,
                  let allocatedBytes = item.allocatedBytes,
                  let row = snapshot.projection.rows.first(where: {
                      $0.classificationID == item.classificationID
                  })
            else {
                return false
            }
            return entry.planItemID == item.id
                && entry.expectedIdentity == expectedIdentity
                && entry.action == item.proposedAction
                && entry.policyDisposition == row.currentDisposition
                && entry.outcome?.measures.candidateLogicalBytes
                    == logicalBytes
                && entry.outcome?.measures.candidateAllocatedBytes
                    == allocatedBytes
        }
    }

    private static func matches(
        enrichment: CleanupResultEnrichment,
        snapshot: ReviewSnapshot
    ) -> Bool {
        let planItems = Dictionary(
            uniqueKeysWithValues: snapshot.plan.items.map {
                ($0.id, $0)
            }
        )
        return enrichment.itemFacts.allSatisfy { facts in
            guard let item = planItems[facts.planItemID] else {
                return false
            }
            return facts.expectedIdentity == item.expectedIdentity
                && facts.evidenceFingerprint == item.evidenceFingerprint
        }
    }
}

private func token(_ rawValue: String) -> DomainToken {
    DomainToken(rawValue: rawValue)!
}
