import Foundation
import StornautCore
import Testing
@testable import StornautApp

@MainActor
@Test
func appModelOpensAndClosesReviewWithoutChangingTopLevelDestination()
    async throws
{
    let fixture = try ReviewAppFixture()
    let driver = ReviewDependencyDriver(
        buildOutcome: .planReady(fixture.plan, fixture.projection),
        executionAvailability: .writeDisabled
    )
    let model = StornautAppModel(
        dependencies: driver.dependencies,
        refreshesServices: false
    )

    model.openReview()
    await driver.waitForBuild()
    await waitForReview {
        model.reviewState.phase == .ready
    }

    #expect(model.scanWorkspaceRoute == .review)
    #expect(await driver.buildCount == 1)
    #expect(model.reviewState.snapshot?.plan == fixture.plan)

    model.closeReview()
    #expect(model.scanWorkspaceRoute == .results)
    #expect(model.reviewState.phase == .ready)
}

@MainActor
@Test
func closedReviewBuildCannotBlockOrOverwriteItsReplacement()
    async throws
{
    let fixture = try ReviewAppFixture()
    let builder = ReplacingReviewBuilder(
        replacement: .planReady(fixture.plan, fixture.projection)
    )
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil },
            buildReview: { await builder.build() }
        ),
        refreshesServices: false
    )

    model.openReview()
    await builder.waitUntilFirstStarted()
    model.closeReview()
    #expect(model.scanWorkspaceRoute == .results)
    #expect(model.reviewState.phase == .idle)

    model.openReview()
    await builder.waitForCallCount(2)
    await waitForReview {
        model.reviewState.phase == .ready
    }
    #expect(model.reviewState.snapshot?.plan == fixture.plan)

    await builder.resumeFirst()
    await Task.yield()

    #expect(await builder.callCount == 2)
    #expect(model.scanWorkspaceRoute == .review)
    #expect(model.reviewState.phase == .ready)
    #expect(model.reviewState.snapshot?.plan == fixture.plan)
}

@MainActor
@Test
func appModelPreflightUsesExactSelectionAndWriteDisabledNeverExecutes()
    async throws
{
    let fixture = try ReviewAppFixture()
    let initial = try ReviewSnapshot(
        plan: fixture.plan,
        projection: fixture.projection,
        generation: 1,
        executionAvailability: .writeDisabled
    )
    let selected = try initial.settingSelection(
        classificationID: fixture.reviewRow.classificationID,
        isSelected: true
    )
    let selection = try #require(selected.reviewSelection)
    let evaluation = try ReviewConfirmationFixture.evaluate(
        plan: fixture.plan,
        selection: selection,
        activityFacts: .inactive
    )
    let driver = ReviewDependencyDriver(
        buildOutcome: .planReady(fixture.plan, fixture.projection),
        preflightOutcome: evaluation,
        executionAvailability: .writeDisabled
    )
    let model = StornautAppModel(
        dependencies: driver.dependencies,
        initialScanWorkspaceRoute: .review,
        initialReviewState: .ready(selected),
        refreshesServices: false
    )

    model.preflightReview()
    await driver.waitForPreflight()
    await waitForReview {
        model.reviewState.phase == .confirming
    }
    model.confirmReviewExecution()

    #expect(
        await driver.preflightSelections == [selection]
    )
    #expect(model.reviewState == .executionBlocked(
        selected,
        .writeDisabled
    ))
    #expect(await driver.executeCount == 0)
}

@MainActor
@Test
func appModelMapsStaleAndRefreshesThroughPlanBuilder() async throws {
    let fixture = try ReviewAppFixture()
    let snapshot = try ReviewSnapshot(
        plan: fixture.plan,
        projection: fixture.projection,
        generation: 1,
        executionAvailability: .writeDisabled
    )
    let selection = try #require(snapshot.reviewSelection)
    let blocked = try ReviewConfirmationFixture.evaluate(
        plan: fixture.plan,
        selection: selection,
        activityFacts: .active
    )
    let driver = ReviewDependencyDriver(
        buildOutcome: .planReady(fixture.plan, fixture.projection),
        preflightOutcome: blocked,
        executionAvailability: .writeDisabled
    )
    let model = StornautAppModel(
        dependencies: driver.dependencies,
        initialScanWorkspaceRoute: .review,
        initialReviewState: .ready(snapshot),
        refreshesServices: false
    )

    model.preflightReview()
    await driver.waitForPreflight()
    await waitForReview {
        model.reviewState.phase == .stale
    }
    #expect(model.reviewState.stale?.availableActions == [
        .refreshAffectedItems,
        .cancel,
    ])
    #expect(model.reviewStaleSheetIsPresented)

    model.cancelReviewSheet()
    #expect(model.reviewState.phase == .stale)
    #expect(!model.reviewStaleSheetIsPresented)

    model.refreshStaleReview()
    await driver.waitForBuild(count: 1)
    await waitForReview {
        model.reviewState.phase == .ready
    }
    #expect(await driver.buildCount == 1)
}

@MainActor
@Test
func appModelRejectsSelectionChangesWhilePreflightIsInFlight()
    throws
{
    let fixture = try ReviewAppFixture()
    let snapshot = try ReviewSnapshot(
        plan: fixture.plan,
        projection: fixture.projection,
        generation: 7,
        executionAvailability: .debugFake
    )
    let model = StornautAppModel(
        dependencies: AppDependencies(
            loadLatestQuickScan: { nil }
        ),
        initialScanWorkspaceRoute: .review,
        initialReviewState: .preflighting(snapshot),
        refreshesServices: false
    )

    model.setReviewSelection(
        classificationID: fixture.reviewRow.classificationID,
        isSelected: true
    )

    #expect(model.reviewState == .preflighting(snapshot))
}

@MainActor
@Test
func debugFakeExecutionReportsProgressAndStopAfterCurrentOnce()
    async throws
{
    let fixture = try ReviewAppFixture()
    let snapshot = try ReviewSnapshot(
        plan: fixture.plan,
        projection: fixture.projection,
        generation: 1,
        executionAvailability: .debugFake
    )
    let selection = try #require(snapshot.reviewSelection)
    let evaluation = try ReviewConfirmationFixture.evaluate(
        plan: fixture.plan,
        selection: selection,
        activityFacts: .inactive
    )
    let driver = ReviewDependencyDriver(
        buildOutcome: .planReady(fixture.plan, fixture.projection),
        preflightOutcome: evaluation,
        executionAvailability: .debugFake
    )
    let model = StornautAppModel(
        dependencies: driver.dependencies,
        initialScanWorkspaceRoute: .review,
        initialReviewState: .ready(snapshot),
        refreshesServices: false
    )

    model.preflightReview()
    await driver.waitForPreflight()
    await waitForReview {
        model.reviewState.phase == .confirming
    }
    model.confirmReviewExecution()
    await driver.waitForExecution()
    await waitForReview {
        model.reviewState.phase == .executing
    }
    model.stopReviewAfterCurrent()
    model.stopReviewAfterCurrent()
    await driver.waitForStop()

    #expect(await driver.executeCount == 1)
    #expect(await driver.stopCount == 1)
    #expect(model.reviewState.progress == .stopRequested(
        completed: 0,
        total: 1
    ))
}

private struct ReviewDependencyDriver {
    let dependencies: AppDependencies
    private let storage: ReviewDependencyStorage

    init(
        buildOutcome: CleanupPlanBuildOutcome,
        preflightOutcome: CleanupPolicyEvaluation? = nil,
        executionAvailability: ReviewExecutionAvailability
    ) {
        let storage = ReviewDependencyStorage(
            buildOutcome: buildOutcome,
            preflightOutcome: preflightOutcome
        )
        self.storage = storage
        dependencies = AppDependencies(
            loadLatestQuickScan: { nil },
            buildReview: {
                await storage.build()
            },
            preflightReview: {
                try await storage.preflight(
                    plan: $0,
                    selection: $1
                )
            },
            reviewExecutionAvailability: executionAvailability,
            startReviewExecution: {
                await storage.startExecution(
                    plan: $0,
                    selection: $1,
                    confirmation: $2
                )
            },
            stopReviewAfterCurrent: {
                await storage.stop()
            }
        )
    }

    var buildCount: Int {
        get async { await storage.buildCount }
    }

    var preflightSelections: [ReviewSelection] {
        get async { await storage.preflightSelections }
    }

    var executeCount: Int {
        get async { await storage.executeCount }
    }

    var stopCount: Int {
        get async { await storage.stopCount }
    }

    func waitForBuild(count: Int = 1) async {
        while await storage.buildCount < count {
            await Task.yield()
        }
    }

    func waitForPreflight() async {
        while await storage.preflightSelections.isEmpty {
            await Task.yield()
        }
    }

    func waitForExecution() async {
        while await storage.executeCount == 0 {
            await Task.yield()
        }
    }

    func waitForStop() async {
        while await storage.stopCount == 0 {
            await Task.yield()
        }
    }
}

private actor ReviewDependencyStorage {
    typealias Stream = AsyncStream<ReviewExecutionEvent>

    private let buildOutcome: CleanupPlanBuildOutcome
    private let preflightOutcome: CleanupPolicyEvaluation?
    private var executionContinuation: Stream.Continuation?
    private(set) var buildCount = 0
    private(set) var preflightSelections: [ReviewSelection] = []
    private(set) var executeCount = 0
    private(set) var stopCount = 0

    init(
        buildOutcome: CleanupPlanBuildOutcome,
        preflightOutcome: CleanupPolicyEvaluation?
    ) {
        self.buildOutcome = buildOutcome
        self.preflightOutcome = preflightOutcome
    }

    func build() async -> CleanupPlanBuildOutcome {
        buildCount += 1
        return buildOutcome
    }

    func preflight(
        plan: CleanupPlan,
        selection: ReviewSelection
    ) async throws -> CleanupPolicyEvaluation {
        preflightSelections.append(selection)
        guard let preflightOutcome else {
            throw ReviewDependencyTestError.missingPreflight
        }
        return preflightOutcome
    }

    func startExecution(
        plan: CleanupPlan,
        selection: ReviewSelection,
        confirmation: CleanupConfirmation
    ) async -> Stream {
        executeCount += 1
        return Stream { continuation in
            executionContinuation = continuation
            continuation.yield(
                .progress(.queued(total: selection.items.count))
            )
        }
    }

    func stop() async {
        stopCount += 1
        if let itemID = preflightSelections.last?.items.first?.itemID,
           let total = preflightSelections.last?.items.count
        {
            executionContinuation?.yield(
                .progress(
                    .current(
                        index: 1,
                        total: total,
                        itemID: itemID
                    )
                )
            )
        }
    }
}

private enum ReviewDependencyTestError: Error {
    case missingPreflight
}

private actor ReplacingReviewBuilder {
    private let replacement: CleanupPlanBuildOutcome
    private var firstContinuation:
        CheckedContinuation<Void, Never>?
    private(set) var callCount = 0

    init(replacement: CleanupPlanBuildOutcome) {
        self.replacement = replacement
    }

    func build() async -> CleanupPlanBuildOutcome {
        callCount += 1
        if callCount == 1 {
            await withCheckedContinuation {
                firstContinuation = $0
            }
            return .unavailable([
                DomainToken(
                    rawValue: "review.unavailable.stale-build"
                )!,
            ])
        }
        return replacement
    }

    func waitUntilFirstStarted() async {
        while callCount == 0 || firstContinuation == nil {
            await Task.yield()
        }
    }

    func waitForCallCount(_ count: Int) async {
        while callCount < count {
            await Task.yield()
        }
    }

    func resumeFirst() {
        firstContinuation?.resume()
        firstContinuation = nil
    }
}

@MainActor
private func waitForReview(
    _ condition: () -> Bool
) async {
    for _ in 0..<1_000 {
        if condition() {
            return
        }
        await Task.yield()
    }
}
