import Darwin
import Foundation
import StornautCore
import Testing
@testable import StornautApp

#if DEBUG
@MainActor
@Test
func debugFixtureSelectorAcceptsOnlyOneExactKnownArgument() throws {
    #expect(
        DebugAppFixtureSelection(arguments: [
            "Stornaut",
            "--stornaut-debug-fixture=success",
        ])?.fixture == .success
    )
    #expect(
        DebugAppFixtureSelection(arguments: [
            "Stornaut",
            "--stornaut-debug-fixture=unknown-value",
        ]) == nil
    )
    #expect(
        DebugAppFixtureSelection(arguments: [
            "Stornaut",
            "--stornaut-debug-fixture=success",
            "--stornaut-debug-fixture=partial",
        ]) == nil
    )
    #expect(
        DebugAppFixtureSelection(arguments: [
            "Stornaut",
            "--stornaut-debug-fixture=success-extra",
        ]) == nil
    )
    #expect(
        DebugAppFixtureSelection(arguments: [
            "Stornaut",
            "--stornaut-debug-fixture",
            "success",
        ]) == nil
    )
}

@Test
func debugInitialDestinationAcceptsOnlyOneExactKnownArgument() {
    #expect(
        DebugInitialDestination.selection(arguments: [
            "Stornaut",
            "--stornaut-debug-destination=scan",
        ]) == .scan
    )
    #expect(
        DebugInitialDestination.selection(arguments: [
            "Stornaut",
            "--stornaut-debug-destination=unknown",
        ]) == .overview
    )
    #expect(
        DebugInitialDestination.selection(arguments: [
            "Stornaut",
            "--stornaut-debug-destination=scan",
            "--stornaut-debug-destination=history",
        ]) == .overview
    )
}

@Test
func debugHistorySelectorAcceptsOnlyOneExactKnownArgument() {
    #expect(
        DebugHistoryFixtureSelection(arguments: [
            "Stornaut",
            "--stornaut-debug-history=populated",
        ])?.fixture == .populated
    )
    #expect(
        DebugHistoryFixtureSelection(arguments: [
            "Stornaut",
            "--stornaut-debug-history=unknown",
        ]) == nil
    )
    #expect(
        DebugHistoryFixtureSelection(arguments: [
            "Stornaut",
            "--stornaut-debug-history=populated",
            "--stornaut-debug-history=expired",
        ]) == nil
    )
}

@Test
func debugReviewSelectorAcceptsOnlyOneExactKnownArgument() {
    #expect(
        DebugReviewFixtureSelection(arguments: [
            "Stornaut",
            "--stornaut-debug-review=default",
        ])?.fixture == .default
    )
    #expect(
        DebugReviewFixtureSelection(arguments: [
            "Stornaut",
            "--stornaut-debug-review=unknown",
        ]) == nil
    )
    #expect(
        DebugReviewFixtureSelection(arguments: [
            "Stornaut",
            "--stornaut-debug-review=default",
            "--stornaut-debug-review=stale",
        ]) == nil
    )
}

@Test
func debugCleanupSelectorAcceptsOnlyOneExactKnownArgument() {
    #expect(
        DebugCleanupFixtureSelection(arguments: [
            "Stornaut",
            "--stornaut-debug-cleanup=completed",
        ])?.fixture == .completed
    )
    #expect(
        DebugCleanupFixtureSelection(arguments: [
            "Stornaut",
            "--stornaut-debug-cleanup=unknown",
        ]) == nil
    )
    #expect(
        DebugCleanupFixtureSelection(arguments: [
            "Stornaut",
            "--stornaut-debug-cleanup=completed",
            "--stornaut-debug-cleanup=partial",
        ]) == nil
    )
}

@Test
func debugCleanupAutoRunAcceptsOnlyOneExactArgument() {
    #expect(
        DebugCleanupAutoRun.enabled(arguments: [
            "Stornaut",
            "--stornaut-debug-auto-cleanup-terminal",
        ])
    )
    #expect(
        !DebugCleanupAutoRun.enabled(arguments: [
            "Stornaut",
            "--stornaut-debug-auto-cleanup-terminal=true",
        ])
    )
    #expect(
        !DebugCleanupAutoRun.enabled(arguments: [
            "Stornaut",
            "--stornaut-debug-auto-cleanup-terminal",
            "--stornaut-debug-auto-cleanup-terminal",
        ])
    )
}

@Test
func debugHistoryPresentationAcceptsOnlyOneExactKnownArgument() {
    #expect(
        DebugHistoryInitialPresentation.selection(arguments: [
            "Stornaut",
            "--stornaut-debug-history-presentation=trend",
        ]) == .trend
    )
    #expect(
        DebugHistoryInitialPresentation.selection(arguments: [
            "Stornaut",
            "--stornaut-debug-history-presentation=unknown",
        ]) == .detail
    )
    #expect(
        DebugHistoryInitialPresentation.selection(arguments: [
            "Stornaut",
            "--stornaut-debug-history-presentation=trend",
            "--stornaut-debug-history-presentation=detail",
        ]) == .detail
    )
}

@Test
func debugSettingsSelectorsAcceptOnlyExactSingleArguments() {
    #expect(
        DebugSettingsFixtureSelection(arguments: [
            "Stornaut",
            "--stornaut-debug-settings=populated",
        ])?.fixture == .populated
    )
    #expect(
        DebugSettingsFixtureSelection(arguments: [
            "Stornaut",
            "--stornaut-debug-settings=unknown",
        ]) == nil
    )
    #expect(
        DebugSettingsFixtureSelection(arguments: [
            "Stornaut",
            "--stornaut-debug-settings=populated",
            "--stornaut-debug-settings=empty",
        ]) == nil
    )
    #expect(
        DebugSettingsInitialSection.selection(arguments: [
            "Stornaut",
            "--stornaut-debug-settings-section=privacyAndData",
        ]) == .privacyAndData
    )
    #expect(
        DebugSettingsInitialSection.selection(arguments: [
            "Stornaut",
            "--stornaut-debug-settings-section=unknown",
        ]) == .general
    )
    #expect(
        DebugSettingsLanguage.selection(arguments: [
            "Stornaut",
            "-AppleLanguages", "(zh-Hans)",
        ]) == .simplifiedChinese
    )
}

@MainActor
@Test
func debugFixturesCoverEveryApprovedPhaseDeterministically() async throws {
    let expected: [DebugAppFixture: AppPagePhase] = [
        .empty: .empty,
        .loading: .loading,
        .partial: .partial,
        .cancelled: .cancelled,
        .success: .success,
        .limitedPermission: .limitedPermission,
        .stale: .stale,
        .error: .error,
    ]

    #expect(Set(DebugAppFixture.allCases) == Set(expected.keys))

    for fixture in DebugAppFixture.allCases {
        let first = try fixture.makeState()
        let second = try fixture.makeState()

        #expect(first.phase == expected[fixture])
        #expect(first == second)
    }
    let states = try DebugAppFixture.allCases.map {
        try $0.makeState()
    }
    let projectionIDs = Set(states.compactMap {
        $0.projection?.session.id
    })
    #expect(
        projectionIDs.count == states.filter {
            $0.projection != nil
        }.count
    )

    let loadingComposition = try AppComposition.debugFixture(
        selection: DebugAppFixtureSelection(arguments: [
            "Stornaut",
            "--stornaut-debug-fixture=loading",
        ])!
    )
    let successComposition = try AppComposition.debugFixture(
        selection: DebugAppFixtureSelection(arguments: [
            "Stornaut",
            "--stornaut-debug-fixture=success",
        ])!
    )
    #expect(loadingComposition.model.scanActivity == .active)
    #expect(loadingComposition.model.scanState.phase == .active)
    #expect(
        loadingComposition.model.scanState.currentStage
            == .classifyArtifacts
    )
    #expect(loadingComposition.model.scanState.scopeScanned == 128)
    #expect(successComposition.model.scanActivity == .idle)
    #expect(successComposition.model.scanState.phase == .completed)

    for fixture in DebugHistoryFixture.allCases {
        let selection = DebugHistoryFixtureSelection(arguments: [
            "Stornaut",
            "--stornaut-debug-history=\(fixture.rawValue)",
        ])!
        let composition = try AppComposition.debugFixture(
            selection: DebugAppFixtureSelection(arguments: [
                "Stornaut",
                "--stornaut-debug-fixture=success",
            ])!,
            historySelection: selection
        )
        #expect(composition.model.historyState.phase == .loaded)
    }
    let retainedHistory = try AppComposition.debugFixture(
        selection: DebugAppFixtureSelection(arguments: [
            "Stornaut",
            "--stornaut-debug-fixture=success",
        ])!,
        historySelection: DebugHistoryFixtureSelection(arguments: [
            "Stornaut",
            "--stornaut-debug-history=populated",
        ])!
    )
    let retainedManifest = try #require(
        retainedHistory.model.historyState.page?.manifests.first
    )
    #expect(retainedManifest.evidenceAvailability == .retained)
    #expect(retainedManifest.linkedPlan != nil)
    #expect(
        retainedManifest.linkedPlan!.expiresAt
            > retainedManifest.manifest.createdAt
    )
    let expiredHistory = try AppComposition.debugFixture(
        selection: DebugAppFixtureSelection(arguments: [
            "Stornaut",
            "--stornaut-debug-fixture=success",
        ])!,
        historySelection: DebugHistoryFixtureSelection(arguments: [
            "Stornaut",
            "--stornaut-debug-history=expired",
        ])!
    )
    let expiredManifest = try #require(
        expiredHistory.model.historyState.page?.manifests.first
    )
    #expect(expiredManifest.evidenceAvailability == .expired)
    #expect(expiredManifest.linkedPlan == nil)

    let expectedReviewPhases: [DebugReviewFixture: ReviewPhase] = [
        .default: .ready,
        .inspector: .ready,
        .stale: .stale,
        .limited: .scanAgain,
        .empty: .empty,
        .overlapConflict: .unavailable,
        .preflightFailure: .ready,
        .executing: .executing,
    ]
    for fixture in DebugReviewFixture.allCases {
        let composition = try AppComposition.debugFixture(
            selection: DebugAppFixtureSelection(arguments: [
                "Stornaut",
                "--stornaut-debug-fixture=success",
            ])!,
            reviewSelection: DebugReviewFixtureSelection(arguments: [
                "Stornaut",
                "--stornaut-debug-review=\(fixture.rawValue)",
            ])!
        )
        #expect(
            composition.model.reviewState.phase
                == expectedReviewPhases[fixture]
        )
        #expect(composition.model.scanWorkspaceRoute == .review)
    }
    let reviewComposition = try AppComposition.debugFixture(
        selection: DebugAppFixtureSelection(arguments: [
            "Stornaut",
            "--stornaut-debug-fixture=success",
        ])!,
        reviewSelection: DebugReviewFixtureSelection(arguments: [
            "Stornaut",
            "--stornaut-debug-review=inspector",
        ])!
    )
    let reviewModel = ReviewModel(
        state: reviewComposition.model.reviewState,
        pageProjection: reviewComposition.model.pageState.projection
    )
    let reviewInspector = try #require(reviewModel.inspector)
    #expect(reviewModel.summary.selectedCount == 2)
    #expect(
        reviewModel.summary.estimatedTrashBytes == ByteCount(300_000)!
    )
    #expect(reviewInspector.producer?.rawValue == "Go command")
    #expect(
        reviewInspector.modifiedAt
            == Date(timeIntervalSince1970: 1_786_320_000)
    )
    #expect(reviewInspector.recoveryCost == .medium)
    #expect(
        reviewInspector.exactPath
            == "/tmp/stornaut-review-fixture/Library/Caches/go-build"
    )
    #expect(
        reviewModel.rows.first {
            $0.relativePath == "."
        }?.itemName == "stornaut-review-fixture"
    )

    for fixture in DebugCleanupFixture.allCases {
        let composition = try AppComposition.debugFixture(
            selection: DebugAppFixtureSelection(arguments: [
                "Stornaut",
                "--stornaut-debug-fixture=success",
            ])!,
            cleanupSelection: DebugCleanupFixtureSelection(arguments: [
                "Stornaut",
                "--stornaut-debug-cleanup=\(fixture.rawValue)",
            ])!
        )
        if fixture != .corrupt {
            composition.model.preflightReview()
            await waitForCleanupFixture {
                composition.model.reviewState.phase == .confirming
            }
            composition.model.confirmReviewExecution()
            await waitForCleanupFixture {
                composition.model.scanWorkspaceRoute == .cleanupResult
            }
            if fixture == .trashUnavailable {
                composition.model.openTrashFromCleanupResult()
                await waitForCleanupFixture {
                    composition.model.cleanupResultState.phase
                        == .trashUnavailable
                }
            }
        }
        #expect(composition.model.scanWorkspaceRoute == .cleanupResult)
        #expect(
            composition.model.cleanupResultState.phase
                == (
                    fixture == .corrupt
                        ? .corrupt
                        : fixture == .trashUnavailable
                            ? .trashUnavailable
                            : .presented
                )
        )
        if fixture != .corrupt {
            let model = CleanupResultModel(
                state: composition.model.cleanupResultState
            )
            #expect(model.summary != nil)
            #expect(!model.rows.isEmpty)
            #expect(
                model.permanentlyReleasedBytes == ByteCount(0)!
            )
        }
    }

    for fixture in DebugSettingsFixture.allCases {
        let composition = try AppComposition.debugFixture(
            selection: DebugAppFixtureSelection(arguments: [
                "Stornaut",
                "--stornaut-debug-fixture=success",
            ])!,
            settingsSelection: DebugSettingsFixtureSelection(arguments: [
                "Stornaut",
                "--stornaut-debug-settings=\(fixture.rawValue)",
            ])!
        )
        #expect(composition.model.settingsState.phase == .loaded)
    }

    let expectedRuntimeStates: [
        DebugSettingsFixture: (
            SettingsRuntimeGateStatus,
            SettingsRuntimeGateReason?
        )
    ] = [
        .populated: (.verified, nil),
        .empty: (.verified, nil),
        .corrupt: (.verified, nil),
        .codexMissing: (.blocked, .codexUnavailable),
        .syntaxUnsupported: (.blocked, .syntaxUnsupported),
        .runtimeStale: (.blocked, .evidenceStale),
        .runtimeFailed: (.blocked, .evidenceFailed),
        .runtimeUnverified: (.unverified, .evidenceUnverified),
    ]
    for (fixture, expected) in expectedRuntimeStates {
        let composition = try AppComposition.debugFixture(
            selection: DebugAppFixtureSelection(arguments: [
                "Stornaut",
                "--stornaut-debug-fixture=success",
            ])!,
            settingsSelection: DebugSettingsFixtureSelection(arguments: [
                "Stornaut",
                "--stornaut-debug-settings=\(fixture.rawValue)",
            ])!
        )
        let model = SettingsModel(
            state: composition.model.settingsState,
            latestProjection: nil
        )

        #expect(model.codex.runtimeGate == expected.0)
        #expect(model.codex.runtimeGateReason == expected.1)
        #expect(
            model.codex.deepDiveAvailability
                == .implementationUnavailable
        )
        #expect(model.codex.deepDiveCanStart == false)
    }
}

@MainActor
private func waitForCleanupFixture(
    _ condition: () -> Bool
) async {
    for _ in 0..<1_000 {
        if condition() {
            return
        }
        await Task.yield()
    }
}

@MainActor
@Test
func debugFixtureCompositionNeverLoadsProductionServices() async throws {
    let selected = try AppComposition.debugFixture(
        arguments: [
            "Stornaut",
            "--stornaut-debug-fixture=limited-permission",
        ]
    )
    let composition = try #require(selected)

    #expect(composition.model.pageState.phase == .limitedPermission)
    let original = composition.model.pageState

    await composition.model.refreshIfNeeded()

    #expect(composition.model.pageState == original)
}

@MainActor
@Test
func selectedDebugFixtureFailureNeverFallsBackToProduction() {
    let selection = DebugAppFixtureSelection(arguments: [
        "Stornaut",
        "--stornaut-debug-fixture=success",
    ])

    #expect(selection != nil)
    #expect(throws: AppTestLoaderError.fixtureConstructionFailed) {
        _ = try AppComposition.debugFixture(
            selection: selection!,
            makeState: { _ in
                throw AppTestLoaderError.fixtureConstructionFailed
            }
        )
    }
}
#endif

@MainActor
@Test
func liveDependenciesCanLoadAnEmptyInMemoryStore() async throws {
    let dependencies = AppDependencies.live(configuration: .memory)

    #expect(try await dependencies.loadLatestQuickScan() == nil)
    #expect(
        dependencies.reviewExecutionAvailability == .writeDisabled
    )
}

@Test
func productionDependenciesKeepReviewExecutionWriteDisabled() {
    #expect(
        AppDependencies.production().reviewExecutionAvailability
            == .writeDisabled
    )
}

@Test
func ordinaryLiveDependenciesRejectReviewExecution()
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
    let confirmation = try #require(
        evaluation.allowed?.confirmation
    )
    let dependencies = AppDependencies.live(
        configuration: .memory
    )

    await #expect(throws: (any Error).self) {
        _ = try await dependencies.startReviewExecution(
            fixture.plan,
            selection,
            confirmation
        )
    }
}

@Test
func liveExecutionReservesItsSingleFlightBeforeRuntimeResolution()
    throws
{
    let repositoryRoot = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let source = try String(
        contentsOf: repositoryRoot.appending(
            path: "StornautApp/AppState/AppDependencies.swift"
        ),
        encoding: .utf8
    )
    let function = try #require(
        source.range(of: "    func startReviewExecution(")
    )
    let suffix = source[function.lowerBound...]
    let end = try #require(
        suffix.range(of: "\n    func stopReviewAfterCurrent(")
    )
    let body = suffix[..<end.lowerBound]
    let reservation = try #require(
        body.range(of: "executionIsActive = true")
    )
    let runtimeResolution = try #require(
        body.range(of: "try await resolvedExecutionRuntime()")
    )

    #expect(reservation.lowerBound < runtimeResolution.lowerBound)
}

@Test
func liveDependenciesRunOnlyTheExplicitTemporaryRoot() async throws {
    let rootURL = FileManager.default.temporaryDirectory.appending(
        path: "stornaut-app-live-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: rootURL,
        withIntermediateDirectories: false
    )
    defer { try? FileManager.default.removeItem(at: rootURL) }
    try Data("fixture".utf8).write(
        to: rootURL.appending(path: "value.bin")
    )
    let dependencies = AppDependencies.live(
        configuration: .memory,
        rootURL: rootURL
    )

    let stream = try await dependencies.startQuickScan()
    var terminal: QuickScanProjection?
    for try await event in stream {
        if case let .terminal(projection) = event {
            terminal = projection
        }
    }

    let projection = try #require(terminal)
    #expect(projection.session.terminalState == .completed)
    #expect(
        projection.session.completedScopes.map(\.rootPath.rawValue)
            == [rootURL.standardizedFileURL.path]
    )
    #expect(dependencies.quickScanRootPath?.rawValue
        == rootURL.standardizedFileURL.path)
    let review = await dependencies.buildReview()
    switch review {
    case let .planReady(plan, projection):
        #expect(plan.scanSessionID == projection.sessionID)
    case .empty:
        break
    case .scanAgain, .unavailable:
        Issue.record(
            "Review could not read the Quick Scan written by the same in-memory composition."
        )
    }
}

@Test
func liveDependenciesUsePersistedPrimaryRootAndExclusions() async throws {
    let storageRoot = try appTestTemporaryDirectory(
        "settings-storage"
    )
    let fallbackRoot = try appTestTemporaryDirectory(
        "settings-fallback"
    )
    let selectedRoot = try appTestTemporaryDirectory(
        "settings-selected"
    )
    defer {
        try? FileManager.default.removeItem(at: storageRoot)
        try? FileManager.default.removeItem(at: fallbackRoot)
        try? FileManager.default.removeItem(at: selectedRoot)
    }
    let excluded = selectedRoot.appending(
        path: "Excluded",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: excluded,
        withIntermediateDirectories: true
    )
    try Data("hidden".utf8).write(
        to: excluded.appending(path: "hidden.bin")
    )
    try Data("visible".utf8).write(
        to: selectedRoot.appending(path: "visible.bin")
    )
    let configuration = try LocalStoreConfiguration(
        applicationSupportBaseURL: storageRoot.appending(
            path: "Application Support",
            directoryHint: .isDirectory
        ),
        cachesBaseURL: storageRoot.appending(
            path: "Caches",
            directoryHint: .isDirectory
        )
    )
    let preferences = try SettingsPreferences(
        primaryRoot: SettingsPrimaryRoot.bookmark(for: selectedRoot),
        exclusions: [
            ScanExclusion(rawValue: "Excluded")!,
        ]
    )
    try await SettingsPreferencesStore(
        configuration: configuration
    ).save(preferences)
    let dependencies = AppDependencies.live(
        configuration: configuration,
        rootURL: fallbackRoot
    )

    let stream = try await dependencies.startQuickScan()
    var terminal: QuickScanProjection?
    for try await event in stream {
        if case let .terminal(projection) = event {
            terminal = projection
        }
    }
    let projection = try #require(terminal)

    #expect(
        projection.session.unfinishedScopes.map(\.rootPath.rawValue)
            == [selectedRoot.standardizedFileURL.path]
    )
    #expect(
        projection.snapshots.contains {
            $0.relativePath == "Excluded"
                && $0.measurementStatus == .userExcluded
        }
    )
    #expect(
        projection.snapshots.contains {
            $0.relativePath == "Excluded/hidden.bin"
        } == false
    )
    #expect(
        projection.snapshots.contains {
            $0.relativePath == "visible.bin"
        }
    )
}

@Test
func unavailableConfiguredRootNeverFallsBackToBroaderScope() async throws {
    let storageRoot = try appTestTemporaryDirectory(
        "settings-unavailable-storage"
    )
    let fallbackRoot = try appTestTemporaryDirectory(
        "settings-unavailable-fallback"
    )
    let selectedRoot = try appTestTemporaryDirectory(
        "settings-unavailable-selected"
    )
    defer {
        try? FileManager.default.removeItem(at: storageRoot)
        try? FileManager.default.removeItem(at: fallbackRoot)
        try? FileManager.default.removeItem(at: selectedRoot)
    }
    try Data("must-not-scan".utf8).write(
        to: fallbackRoot.appending(path: "fallback-marker.bin")
    )
    let configuration = try LocalStoreConfiguration(
        applicationSupportBaseURL: storageRoot.appending(
            path: "Application Support",
            directoryHint: .isDirectory
        ),
        cachesBaseURL: storageRoot.appending(
            path: "Caches",
            directoryHint: .isDirectory
        )
    )
    let preferences = try SettingsPreferences(
        primaryRoot: SettingsPrimaryRoot.bookmark(for: selectedRoot)
    )
    try await SettingsPreferencesStore(
        configuration: configuration
    ).save(preferences)
    try FileManager.default.removeItem(at: selectedRoot)
    let dependencies = AppDependencies.live(
        configuration: configuration,
        rootURL: fallbackRoot
    )

    await #expect(throws: (any Error).self) {
        _ = try await dependencies.startQuickScan()
    }
    #expect(try await dependencies.loadLatestQuickScan() == nil)
}

@MainActor
@Test
func liveDependencyCreationIsDeferredUntilAsyncLoad() async throws {
    let factory = AppTestDependencyFactory()
    let dependencies = AppDependencies.live(
        configuration: .memory,
        makeCoordinator: { store in
            try await factory.makeCoordinator(store: store)
        }
    )

    #expect(await factory.callCount == 0)
    #expect(try await dependencies.loadLatestQuickScan() == nil)
    #expect(try await dependencies.loadLatestQuickScan() == nil)
    #expect(await factory.callCount == 1)
}

@MainActor
@Test
func concurrentInitialLoadsShareOneCoordinatorFactory() async throws {
    let factory = AppTestDependencyFactory()
    let dependencies = AppDependencies.live(
        configuration: .memory,
        makeCoordinator: { store in
            try await factory.makeCoordinator(store: store)
        }
    )

    async let first = dependencies.loadLatestQuickScan()
    async let second = dependencies.loadLatestQuickScan()

    let values = try await [first, second]
    #expect(values.allSatisfy { $0 == nil })
    #expect(await factory.callCount == 1)
}

@Test
func concurrentRetriesReplaceOnlyTheirOwnFailedCoordinatorFlight() async throws {
    let factory = AppTestRetryingDependencyFactory()
    let dependencies = AppDependencies.live(
        configuration: .memory,
        makeCoordinator: { store in
            try await factory.makeCoordinator(store: store)
        }
    )

    let values = try await withThrowingTaskGroup(
        of: QuickScanProjection?.self
    ) { group in
        for _ in 0..<32 {
            group.addTask {
                do {
                    return try await dependencies.loadLatestQuickScan()
                } catch {
                    return try await dependencies.loadLatestQuickScan()
                }
            }
        }
        return try await group.reduce(into: []) {
            $0.append($1)
        }
    }

    #expect(values.count == 32)
    #expect(values.allSatisfy { $0 == nil })
    #expect(await factory.callCount == 2)
}

private actor AppTestDependencyFactory {
    private(set) var callCount = 0

    func makeCoordinator(
        store: EvidenceStore
    ) throws -> QuickScanCoordinator {
        callCount += 1
        usleep(10_000)
        return try QuickScanCoordinator(store: store)
    }
}

private actor AppTestRetryingDependencyFactory {
    private(set) var callCount = 0

    func makeCoordinator(
        store: EvidenceStore
    ) async throws -> QuickScanCoordinator {
        callCount += 1
        try await Task.sleep(for: .milliseconds(50))
        if callCount == 1 {
            throw AppTestLoaderError.coordinatorCreationFailed
        }
        return try QuickScanCoordinator(store: store)
    }
}

private final class AppTestExecutionFactoryProbe:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var calls = 0

    var callCount: Int {
        lock.withLock { calls }
    }

    func make(
        store: EvidenceStore,
        rootObserver: any CleanupPolicyRootObserving,
        workflowCoordinator: CleanupWorkflowCoordinator,
        resolver: ExecutableEvidenceResolver
    ) throws -> CleanupExecutionRuntime {
        _ = resolver
        lock.withLock {
            calls += 1
        }
        throw AppTestLoaderError.executionFactoryReached
    }
}

private enum AppTestLoaderError: Error {
    case coordinatorCreationFailed
    case executionFactoryReached
    case fixtureConstructionFailed
}

private func appTestTemporaryDirectory(
    _ suffix: String
) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(
        path: "stornaut-app-\(suffix)-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: url,
        withIntermediateDirectories: false
    )
    return url
}
