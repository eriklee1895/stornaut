import Foundation
import Observation
import StornautCore

@MainActor
@Observable
final class StornautAppModel {
    private(set) var pageState: AppPageState
    private(set) var scanActivity: AppScanActivity
    private(set) var scanState: ScanFlowState

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

    init(
        dependencies: AppDependencies,
        initialState: AppPageState = .empty,
        initialScanActivity: AppScanActivity = .idle,
        initialScanState: ScanFlowState? = nil,
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
              cancellationTask == nil
        else {
            return
        }
        scanGeneration &+= 1
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
                    break
                }
            }
            if !terminalObserved {
                scanState = scanReducer.failed(
                    state: scanState,
                    reasonKey: token("scan.error.stream")
                )
                pageState = scanFailurePageState()
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
            }
        }
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
