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

@MainActor
@Test
func debugFixturesCoverEveryApprovedPhaseDeterministically() throws {
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
}

@MainActor
@Test
func liveDependencyCreationIsDeferredUntilAsyncLoad() async throws {
    let factory = AppTestDependencyFactory()
    let dependencies = AppDependencies.live(
        configuration: .memory,
        makeCoordinator: { configuration in
            try await factory.makeCoordinator(
                configuration: configuration
            )
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
        makeCoordinator: { configuration in
            try await factory.makeCoordinator(
                configuration: configuration
            )
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
        makeCoordinator: { configuration in
            try await factory.makeCoordinator(
                configuration: configuration
            )
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
        configuration: LocalStoreConfiguration
    ) throws -> QuickScanCoordinator {
        callCount += 1
        usleep(10_000)
        let store = try EvidenceStore(configuration: configuration)
        return try QuickScanCoordinator(store: store)
    }
}

private actor AppTestRetryingDependencyFactory {
    private(set) var callCount = 0

    func makeCoordinator(
        configuration: LocalStoreConfiguration
    ) async throws -> QuickScanCoordinator {
        callCount += 1
        try await Task.sleep(for: .milliseconds(50))
        if callCount == 1 {
            throw AppTestLoaderError.coordinatorCreationFailed
        }
        let store = try EvidenceStore(configuration: configuration)
        return try QuickScanCoordinator(store: store)
    }
}

private enum AppTestLoaderError: Error {
    case coordinatorCreationFailed
    case fixtureConstructionFailed
}
