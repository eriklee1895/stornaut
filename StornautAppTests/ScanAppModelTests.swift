import Foundation
import StornautCore
import Testing
@testable import StornautApp

@MainActor
@Test
func appModelStartsQuickScanOnlyFromExplicitIntentAndOnlyOnce() async throws {
    let driver = AppTestScanDriver()
    let rootPath = PersistedPath(
        rawValue: "/tmp/stornaut-explicit-root"
    )!
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            startQuickScan: { await driver.start() },
            cancelQuickScan: { await driver.cancel() },
            quickScanRootPath: rootPath
        ),
        now: { OverviewTestProjectionFactory.now },
        refreshesServices: false
    )

    #expect(model.scanState.phase == .idle)
    #expect(await driver.startCount == 0)

    model.startQuickScan()
    model.startQuickScan()
    await driver.waitForStart()

    #expect(model.scanState.phase == .active)
    #expect(model.scanActivity == .active)
    #expect(model.scanState.rootPath == rootPath)
    #expect(await driver.startCount == 1)
}

@MainActor
@Test
func appModelConsumesEventsAfterUnrelatedNavigationLifetime() async throws {
    let driver = AppTestScanDriver()
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            startQuickScan: { await driver.start() },
            cancelQuickScan: { await driver.cancel() }
        ),
        now: { OverviewTestProjectionFactory.now },
        refreshesServices: false
    )

    model.startQuickScan()
    await driver.waitForStart()
    await driver.emit(.stageChanged(.indexVolumes))
    await driver.emit(.stageChanged(.mapProjects))
    await waitUntil {
        model.scanState.currentStage == .mapProjects
    }

    #expect(model.scanState.phase == .active)
    #expect(await driver.cancelCount == 0)
}

@MainActor
@Test
func appModelStopRequestsCancellationOnceAndWaitsForTerminal() async throws {
    let driver = AppTestScanDriver()
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            startQuickScan: { await driver.start() },
            cancelQuickScan: { await driver.cancel() }
        ),
        now: { OverviewTestProjectionFactory.now },
        refreshesServices: false
    )

    model.startQuickScan()
    await driver.waitForStart()
    model.stopQuickScan()
    model.stopQuickScan()
    await driver.waitForCancel()

    #expect(model.scanState.phase == .stopping)
    #expect(model.scanActivity == .active)
    #expect(await driver.cancelCount == 1)

    let cancelled = try OverviewTestProjectionFactory.projection(
        slug: "scan-model-stop",
        terminalState: .cancelled
    )
    await driver.emit(.terminal(cancelled))
    await driver.finish()
    await waitUntil {
        model.scanState.phase == .cancelled
    }

    #expect(model.scanActivity == .idle)
    #expect(model.pageState.phase == .cancelled)
    #expect(model.pageState.projection == cancelled)
}

@MainActor
@Test
func appModelRetriesImmediateStopAfterTheCoordinatorStreamExists()
    async throws
{
    let driver = AppTestDelayedScanDriver()
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            startQuickScan: { try await driver.start() },
            cancelQuickScan: { await driver.cancel() }
        ),
        now: { OverviewTestProjectionFactory.now },
        refreshesServices: false
    )

    model.startQuickScan()
    model.stopQuickScan()
    await driver.waitForSuccessfulCancel()

    #expect(model.scanState.phase == .stopping)
    #expect(await driver.cancelCount >= 2)

    let cancelled = try OverviewTestProjectionFactory.projection(
        slug: "scan-immediate-stop",
        terminalState: .cancelled
    )
    await driver.emit(.terminal(cancelled))
    await driver.finish()
    await waitUntil {
        model.scanState.phase == .cancelled
    }

    #expect(model.scanActivity == .idle)
}

@MainActor
@Test
func appModelTerminalSynchronizesLatestSnapshotForEveryPage() async throws {
    let driver = AppTestScanDriver()
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            startQuickScan: { await driver.start() },
            cancelQuickScan: { await driver.cancel() }
        ),
        now: { OverviewTestProjectionFactory.now },
        refreshesServices: false
    )
    let completed = try OverviewTestProjectionFactory.projection(
        slug: "scan-model-completed"
    )

    model.startQuickScan()
    await driver.waitForStart()
    await driver.emit(.terminal(completed))
    await driver.finish()
    await waitUntil {
        model.scanState.phase == .completed
    }

    #expect(model.pageState.phase == .success)
    #expect(model.pageState.projection == completed)
    #expect(model.scanActivity == .idle)
}

@MainActor
@Test
func appModelStartFailurePreservesLatestProjection() async throws {
    let retained = try OverviewTestProjectionFactory.projection(
        slug: "scan-model-start-failure"
    )
    let initial = try AppPageState.success(
        projection: retained,
        refreshedAt: OverviewTestProjectionFactory.now
    )
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { retained },
            startQuickScan: {
                throw AppTestScanError.startFailed
            },
            cancelQuickScan: { false }
        ),
        initialState: initial,
        initialHistoryState: .loaded(.empty),
        now: { OverviewTestProjectionFactory.now },
        refreshesServices: false
    )

    model.startQuickScan()
    await waitUntil {
        model.scanState.phase == .failed
    }

    #expect(model.scanState.projection == retained)
    #expect(model.pageState.projection == retained)
    #expect(model.scanActivity == .idle)
    #expect(model.scanState.reasonKey?.rawValue == "scan.error.start")
    #expect(model.historyState.phase == .loaded)
}

@MainActor
@Test
func appModelStreamFailureInvalidatesHistoryForStoreReload() async throws {
    let stream = AsyncThrowingStream<QuickScanProductEvent, Error> {
        continuation in
        continuation.finish(throwing: AppTestScanError.startFailed)
    }
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            startQuickScan: { stream },
            cancelQuickScan: { false }
        ),
        initialHistoryState: .loaded(.empty),
        now: { OverviewTestProjectionFactory.now },
        refreshesServices: false
    )

    model.startQuickScan()
    await waitUntil {
        model.scanState.phase == .failed
    }

    #expect(model.historyState.phase == .idle)
}

private actor AppTestScanDriver {
    typealias Stream = AsyncThrowingStream<QuickScanProductEvent, Error>

    private var continuation: Stream.Continuation?
    private(set) var startCount = 0
    private(set) var cancelCount = 0

    func start() -> Stream {
        startCount += 1
        return Stream { continuation in
            self.continuation = continuation
        }
    }

    func cancel() -> Bool {
        cancelCount += 1
        return true
    }

    func emit(_ event: QuickScanProductEvent) {
        continuation?.yield(event)
    }

    func finish() {
        continuation?.finish()
    }

    func waitForStart() async {
        while startCount == 0 || continuation == nil {
            await Task.yield()
        }
    }

    func waitForCancel() async {
        while cancelCount == 0 {
            await Task.yield()
        }
    }
}

private actor AppTestDelayedScanDriver {
    typealias Stream = AsyncThrowingStream<QuickScanProductEvent, Error>

    private var continuation: Stream.Continuation?
    private(set) var cancelCount = 0
    private var successfulCancel = false

    func start() async throws -> Stream {
        try await Task.sleep(for: .milliseconds(50))
        return Stream { continuation in
            self.continuation = continuation
        }
    }

    func cancel() -> Bool {
        cancelCount += 1
        let succeeded = continuation != nil
        successfulCancel = successfulCancel || succeeded
        return succeeded
    }

    func emit(_ event: QuickScanProductEvent) {
        continuation?.yield(event)
    }

    func finish() {
        continuation?.finish()
    }

    func waitForSuccessfulCancel() async {
        while !successfulCancel {
            await Task.yield()
        }
    }
}

@MainActor
private func waitUntil(
    _ condition: () -> Bool
) async {
    for _ in 0..<1_000 {
        if condition() {
            return
        }
        await Task.yield()
    }
}

private enum AppTestScanError: Error {
    case startFailed
}
