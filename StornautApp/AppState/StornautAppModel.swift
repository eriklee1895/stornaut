import Foundation
import Observation
import StornautCore

@MainActor
@Observable
final class StornautAppModel {
    private(set) var pageState: AppPageState
    private(set) var scanActivity: AppScanActivity

    private let dependencies: AppDependencies
    private let reducer: AppPageReducer
    private let now: @Sendable () -> Date
    private let refreshesServices: Bool
    private var refreshIsActive = false

    init(
        dependencies: AppDependencies,
        initialState: AppPageState = .empty,
        initialScanActivity: AppScanActivity = .idle,
        reducer: AppPageReducer = AppPageReducer(),
        now: @escaping @Sendable () -> Date = Date.init,
        refreshesServices: Bool = true
    ) {
        self.dependencies = dependencies
        pageState = initialState
        scanActivity = initialScanActivity
        self.reducer = reducer
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
        refreshIsActive = true
        pageState = reducer.beginRefresh(previous: previous)
        defer { refreshIsActive = false }
        do {
            pageState = reducer.loaded(
                try await dependencies.loadLatestQuickScan(),
                previous: pageState,
                now: now()
            )
        } catch is CancellationError {
            pageState = previous
        } catch {
            pageState = reducer.failed(
                reasonKey: DomainToken(
                    rawValue: "app.state.store-unavailable"
                )!,
                previous: pageState,
                now: now()
            )
        }
    }

}
