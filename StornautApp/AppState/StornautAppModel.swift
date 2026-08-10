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

    init(
        dependencies: AppDependencies,
        initialState: AppPageState = .empty,
        initialScanActivity: AppScanActivity = .idle,
        initialScanState: ScanFlowState? = nil,
        initialHistoryState: HistoryState = .idle,
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
              !historyDeleteIsActive
        else {
            return
        }
        scanGeneration &+= 1
        historyGeneration &+= 1
        if historyRefreshGeneration != nil {
            historyState = historyState.page.map(HistoryState.loaded) ?? .idle
            historyRefreshGeneration = nil
        }
        scanState = scanReducer.started(
            previous: scanState,
            at: now(),
            rootPath: dependencies.quickScanRootPath
        )
        scanActivity = .active
        startElapsedUpdates()
        scanTask = Task { [weak self] in
            await self?.consumeQuickScan()
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
