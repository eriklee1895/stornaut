import Foundation
import StornautCore
import Testing
@testable import StornautApp

@MainActor
@Test
func appPageReducerMapsEveryApprovedPhase() throws {
    let reducer = AppPageReducer()
    let now = AppTestProjectionFactory.now

    #expect(reducer.loaded(nil, previous: .empty, now: now).phase == .empty)
    #expect(
        reducer.loaded(
            try AppTestProjectionFactory.success(),
            previous: .empty,
            now: now
        ).phase == .success
    )
    #expect(
        reducer.loaded(
            try AppTestProjectionFactory.partial(),
            previous: .empty,
            now: now
        ).phase == .partial
    )
    #expect(
        reducer.loaded(
            try AppTestProjectionFactory.cancelled(),
            previous: .empty,
            now: now
        ).phase == .cancelled
    )
    #expect(
        reducer.loaded(
            try AppTestProjectionFactory.limitedPermission(),
            previous: .empty,
            now: now
        ).phase == .limitedPermission
    )
    #expect(
        reducer.loaded(
            try AppTestProjectionFactory.failed(),
            previous: .empty,
            now: now
        ).phase == .error
    )
    #expect(reducer.beginRefresh(previous: .empty).phase == .loading)
    #expect(
        reducer.markStale(
            previous: try AppPageState.success(
                projection: AppTestProjectionFactory.success(),
                refreshedAt: now
            ),
            reasonKey: DomainToken(rawValue: "app.state.stale")!,
            now: now
        ).phase == .stale
    )
}

@MainActor
@Test
func appPageReducerPreservesValidProjectionAcrossTransitions() throws {
    let reducer = AppPageReducer()
    let now = AppTestProjectionFactory.now
    let projection = try AppTestProjectionFactory.success()
    let success = try AppPageState.success(
        projection: projection,
        refreshedAt: now
    )

    let loading = reducer.beginRefresh(previous: success)
    #expect(loading.phase == .loading)
    #expect(loading.projection == projection)

    let failed = reducer.failed(
        reasonKey: DomainToken(rawValue: "app.state.store-unavailable")!,
        previous: loading,
        now: now.addingTimeInterval(1)
    )
    #expect(failed.phase == .error)
    #expect(failed.projection == projection)
    #expect(failed.recoveryIntent == .retryLatestSnapshot)
    #expect(failed.refreshedAt == now)

    let stale = reducer.markStale(
        previous: failed,
        reasonKey: DomainToken(rawValue: "app.state.snapshot-stale")!,
        now: now.addingTimeInterval(2)
    )
    #expect(stale.phase == .stale)
    #expect(stale.projection == projection)
    #expect(stale.recoveryIntent == .refreshLatestSnapshot)
    #expect(stale.refreshedAt == now)
}

@MainActor
@Test
func appPageStateRejectsContradictorySuccessAndLimitedState() throws {
    let now = AppTestProjectionFactory.now

    #expect(throws: AppStateContractError.invalidPhase) {
        _ = try AppPageState(
            phase: .success,
            projection: AppTestProjectionFactory.partial(),
            reasonKey: nil,
            recoveryIntent: nil,
            refreshedAt: now
        )
    }
    #expect(throws: AppStateContractError.invalidPhase) {
        _ = try AppPageState(
            phase: .limitedPermission,
            projection: AppTestProjectionFactory.success(),
            reasonKey: DomainToken(rawValue: "app.state.permission-limited"),
            recoveryIntent: .reviewPermissions,
            refreshedAt: now
        )
    }
    #expect(throws: AppStateContractError.invalidPhase) {
        _ = try AppPageState(
            phase: .partial,
            projection: AppTestProjectionFactory.partial(),
            reasonKey: nil,
            recoveryIntent: nil,
            refreshedAt: now
        )
    }
    #expect(throws: AppStateContractError.invalidPhase) {
        _ = try AppPageState(
            phase: .cancelled,
            projection: AppTestProjectionFactory.cancelled(),
            reasonKey: DomainToken(rawValue: "app.state.cancelled"),
            recoveryIntent: nil,
            refreshedAt: now
        )
    }
    #expect(throws: AppStateContractError.invalidPhase) {
        _ = try AppPageState(
            phase: .loading,
            projection: AppTestProjectionFactory.success(),
            reasonKey: nil,
            recoveryIntent: nil,
            refreshedAt: nil
        )
    }
    #expect(throws: AppStateContractError.invalidPhase) {
        _ = try AppPageState(
            phase: .empty,
            projection: nil,
            reasonKey: nil,
            recoveryIntent: nil,
            refreshedAt: now
        )
    }
}

@MainActor
@Test
func appModelLoadsThroughInjectedDependencyAndPreservesOnFailure() async throws {
    let projection = try AppTestProjectionFactory.success()
    let loader = AppTestLatestProjectionLoader(
        results: [
            .success(projection),
            .failure(AppTestLoaderError.unavailable),
        ]
    )
    let model = StornautAppModel(
        dependencies: AppDependencies(loadLatestQuickScan: loader.load),
        now: { AppTestProjectionFactory.now }
    )

    await model.refresh()
    #expect(model.pageState.phase == .success)
    #expect(model.pageState.projection == projection)
    #expect(model.scanState.phase == .completed)
    #expect(model.scanState.projection == projection)

    await model.refresh()
    #expect(model.pageState.phase == .error)
    #expect(model.pageState.projection == projection)
    #expect(model.scanState.phase == .completed)
    #expect(model.scanState.projection == projection)
    #expect(await loader.callCount == 2)
}

@MainActor
@Test
func appModelCancellationRestoresThePreviousPage() async throws {
    let projection = try AppTestProjectionFactory.success()
    let initial = try AppPageState.success(
        projection: projection,
        refreshedAt: AppTestProjectionFactory.now
    )
    let model = StornautAppModel(
        dependencies: AppDependencies {
            throw CancellationError()
        },
        initialState: initial,
        now: { AppTestProjectionFactory.now }
    )

    await model.refresh()

    #expect(model.pageState == initial)
}

@MainActor
@Test
func appRefreshNeverOverwritesAnActiveScanFlow() async throws {
    let projection = try AppTestProjectionFactory.success()
    let stream = AsyncThrowingStream<QuickScanProductEvent, Error> {
        _ in
    }
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { projection },
            startQuickScan: { stream },
            cancelQuickScan: { false }
        ),
        now: { AppTestProjectionFactory.now }
    )

    model.startQuickScan()
    await Task.yield()
    let activeStartedAt = model.scanState.startedAt
    await model.refresh()

    #expect(model.pageState.projection == projection)
    #expect(model.scanState.phase == .active)
    #expect(model.scanState.startedAt == activeStartedAt)
}

@MainActor
@Test
func staleRefreshCompletionCannotOverwriteANewerScanTerminal()
    async throws
{
    let stale = try AppTestProjectionFactory.success()
    let fresh = try OverviewTestProjectionFactory.projection(
        slug: "scan-newer-than-refresh"
    )
    let loader = AppTestSuspendedProjectionLoader(projection: stale)
    let streamDriver = AppTestPageStateScanDriver()
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: loader.load,
            startQuickScan: { await streamDriver.start() },
            cancelQuickScan: { false }
        ),
        now: { AppTestProjectionFactory.now }
    )

    let refresh = Task { @MainActor in
        await model.refresh()
    }
    await loader.waitUntilStarted()
    model.startQuickScan()
    await streamDriver.waitUntilStarted()
    await streamDriver.emit(.terminal(fresh))
    await streamDriver.finish()
    await loader.resume()
    await refresh.value

    #expect(model.pageState.projection == fresh)
    #expect(model.scanState.projection == fresh)
}

private actor AppTestLatestProjectionLoader {
    private var results: [
        Result<QuickScanProjection?, any Error>
    ]
    private(set) var callCount = 0

    init(results: [Result<QuickScanProjection?, any Error>]) {
        self.results = results
    }

    func load() async throws -> QuickScanProjection? {
        callCount += 1
        guard !results.isEmpty else {
            return nil
        }
        return try results.removeFirst().get()
    }
}

private actor AppTestSuspendedProjectionLoader {
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

private actor AppTestPageStateScanDriver {
    typealias Stream = AsyncThrowingStream<QuickScanProductEvent, Error>
    private var continuation: Stream.Continuation?

    func start() -> Stream {
        Stream { continuation in
            self.continuation = continuation
        }
    }

    func waitUntilStarted() async {
        while continuation == nil {
            await Task.yield()
        }
    }

    func emit(_ event: QuickScanProductEvent) {
        continuation?.yield(event)
    }

    func finish() {
        continuation?.finish()
    }
}

private enum AppTestLoaderError: Error {
    case unavailable
}
