import Foundation
import Testing
@testable import StornautCore

@Test
func activityReducerFusesFixtureCasesConservatively() throws {
    let fixture = try loadActivityFusionFixture()
    let reducer = ActivityReducer()

    for fixtureCase in fixture.cases {
        let result = reducer.reduce(
            ActivityReductionInput(
                baseDisposition: fixtureCase.baseDisposition,
                baseRisk: .medium,
                requiredKeys: try fixtureCase.requiredKeys.map(
                    ActivityKey.init(validating:)
                ),
                observations: try fixtureCase.observations.map {
                    try ActivityObservation(
                        key: ActivityKey(validating: $0.key),
                        state: $0.state,
                        source: $0.source,
                        origin: $0.origin,
                        observedAt: Date(
                            timeIntervalSince1970: $0.observedAt / 1_000
                        ),
                        reason: DomainToken(
                            validating: "fixture.\(fixtureCase.id)"
                        )
                    )
                },
                timestamps: [],
                recentActivityCutoff: Date(
                    timeIntervalSince1970: 1_786_300_000
                )
            )
        )

        #expect(
            result.disposition == fixtureCase.expectedDisposition,
            "Unexpected disposition for \(fixtureCase.id)"
        )
        #expect(
            result.missingKeys.map(\.rawValue)
                == fixtureCase.expectedMissing.sorted(),
            "Unexpected missing keys for \(fixtureCase.id)"
        )
        #expect(
            result.observations.count == fixtureCase.observations.count
        )
    }
}

@Test
func activityReducerLimitsProviderFailureToDependentRequirements() throws {
    let unavailableGit = try ActivityObservation(
        key: .gitClean,
        state: .unavailable,
        source: .git,
        origin: .external,
        observedAt: Date(timeIntervalSince1970: 10),
        reason: DomainToken(validating: "activity.git.permission-denied")
    )
    let inactiveProcess = try ActivityObservation(
        key: .processInactive,
        state: .satisfied,
        source: .runningProcess,
        origin: .external,
        observedAt: Date(timeIntervalSince1970: 10),
        reason: DomainToken(validating: "activity.process.none")
    )

    let processOnly = ActivityReducer().reduce(
        ActivityReductionInput(
            baseDisposition: .reviewRecommended,
            baseRisk: .medium,
            requiredKeys: [.processInactive],
            observations: [unavailableGit, inactiveProcess],
            timestamps: [],
            recentActivityCutoff: Date(timeIntervalSince1970: 20)
        )
    )
    let gitDependent = ActivityReducer().reduce(
        ActivityReductionInput(
            baseDisposition: .reviewRecommended,
            baseRisk: .medium,
            requiredKeys: [.gitClean, .processInactive],
            observations: [unavailableGit, inactiveProcess],
            timestamps: [],
            recentActivityCutoff: Date(timeIntervalSince1970: 20)
        )
    )

    #expect(processOnly.disposition == .reviewRecommended)
    #expect(processOnly.missingKeys.isEmpty)
    #expect(gitDependent.disposition == .unknown)
    #expect(gitDependent.missingKeys == [.gitClean])

    let conflictedProcess = ActivityReducer().reduce(
        ActivityReductionInput(
            baseDisposition: .reviewRecommended,
            baseRisk: .medium,
            requiredKeys: [.processInactive],
            observations: [
                inactiveProcess,
                try ActivityObservation(
                    key: .processInactive,
                    state: .unavailable,
                    source: .runningApplication,
                    origin: .external,
                    observedAt: Date(timeIntervalSince1970: 10),
                    reason: DomainToken(
                        validating: "activity.app.permission-denied"
                    )
                ),
            ],
            timestamps: [],
            recentActivityCutoff: Date(timeIntervalSince1970: 20)
        )
    )
    #expect(conflictedProcess.disposition == .unknown)
    #expect(conflictedProcess.missingKeys == [.processInactive])
}

@Test
func activityReducerTreatsOnlyRecentExternalTimeAsProtection() throws {
    let cutoff = Date(timeIntervalSince1970: 1_000)
    let staleExternal = try ActivityTimestampObservation(
        source: .filesystemModification,
        origin: .external,
        observedAt: cutoff.addingTimeInterval(-1)
    )
    let recentStornaut = try ActivityTimestampObservation(
        source: .filesystemModification,
        origin: .stornaut,
        observedAt: cutoff.addingTimeInterval(10)
    )
    let recentExternal = try ActivityTimestampObservation(
        source: .filesystemModification,
        origin: .external,
        observedAt: cutoff.addingTimeInterval(10)
    )
    let input = ActivityReductionInput(
        baseDisposition: .reviewRecommended,
        baseRisk: .medium,
        requiredKeys: [],
        observations: [],
        timestamps: [staleExternal, recentStornaut],
        recentActivityCutoff: cutoff
    )

    let nonUserResult = ActivityReducer().reduce(input)
    let activeResult = ActivityReducer().reduce(
        ActivityReductionInput(
            baseDisposition: input.baseDisposition,
            baseRisk: input.baseRisk,
            requiredKeys: input.requiredKeys,
            observations: input.observations,
            timestamps: input.timestamps + [recentExternal],
            recentActivityCutoff: cutoff
        )
    )
    let unknownResult = ActivityReducer().reduce(
        ActivityReductionInput(
            baseDisposition: .unknown,
            baseRisk: .high,
            requiredKeys: [],
            observations: [],
            timestamps: [staleExternal],
            recentActivityCutoff: cutoff
        )
    )

    #expect(nonUserResult.disposition == .reviewRecommended)
    #expect(activeResult.disposition == .protected)
    #expect(activeResult.risk == .high)
    #expect(unknownResult.disposition == .unknown)
}

@Test
func activityReducerNeverPromotesConservativeBaseDisposition() throws {
    let satisfied = try ActivityObservation(
        key: .processInactive,
        state: .satisfied,
        source: .runningApplication,
        origin: .external,
        observedAt: Date(timeIntervalSince1970: 10),
        reason: DomainToken(validating: "activity.app.none")
    )

    for base in [
        ReclaimDisposition.reviewRecommended,
        .protected,
        .unknown,
    ] {
        let result = ActivityReducer().reduce(
            ActivityReductionInput(
                baseDisposition: base,
                baseRisk: base == .protected ? .critical : .medium,
                requiredKeys: [.processInactive],
                observations: [satisfied],
                timestamps: [],
                recentActivityCutoff: Date(timeIntervalSince1970: 20)
            )
        )
        #expect(result.disposition == base)
        #expect(result.disposition != .readyToReclaim)
    }
}

@Test
func runningActivityProviderUsesAppAndProcessSignalsWithoutShell() async throws {
    let source = FixtureRunningActivitySource(
        result: .success(
            RunningActivitySnapshot(
                applications: [
                    try RunningApplicationRecord(
                        bundleIdentifier: DomainToken(
                            validating: "com.apple.dt.Xcode"
                        ),
                        localizedName: DomainLabel(validating: "Xcode"),
                        processIdentifier: 42
                    ),
                ],
                processes: [
                    try RunningProcessRecord(
                        name: DomainLabel(validating: "swift-build"),
                        processIdentifier: 43
                    ),
                ],
                observedAt: Date(timeIntervalSince1970: 30)
            )
        )
    )
    let provider = RunningActivityProvider(source: source)

    let active = await provider.collect(
        query: try RelatedProcessQuery(
            bundleIdentifiers: [
                DomainToken(validating: "com.apple.dt.Xcode"),
            ],
            processNames: [
                DomainLabel(validating: "swift-build"),
            ]
        ),
        observedAt: Date(timeIntervalSince1970: 31)
    )
    let inactive = await provider.collect(
        query: try RelatedProcessQuery(
            bundleIdentifiers: [
                DomainToken(validating: "com.example.Other"),
            ],
            processNames: [
                DomainLabel(validating: "other-tool"),
            ]
        ),
        observedAt: Date(timeIntervalSince1970: 31)
    )

    #expect(active.status == .available)
    #expect(active.observation.state == .contradicted)
    #expect(active.matchedBundleIdentifiers == [
        DomainToken(rawValue: "com.apple.dt.Xcode")!,
    ])
    #expect(active.matchedProcessNames == [
        DomainLabel(rawValue: "swift-build")!,
    ])
    #expect(inactive.observation.state == .satisfied)
}

@Test
func runningActivityPermissionFailureRemainsUnavailable() async throws {
    let provider = RunningActivityProvider(
        source: FixtureRunningActivitySource(
            result: .failure(.permissionDenied)
        )
    )

    let result = await provider.collect(
        query: try RelatedProcessQuery(
            bundleIdentifiers: [],
            processNames: [
                DomainLabel(validating: "fixture-process"),
            ]
        ),
        observedAt: Date(timeIntervalSince1970: 31)
    )

    #expect(result.status == .unavailable(.permissionDenied))
    #expect(result.observation.state == .unavailable)
    #expect(result.matchedBundleIdentifiers.isEmpty)
    #expect(result.matchedProcessNames.isEmpty)
}

@Test
func runningActivityIncompleteProcessCoverageCannotClaimInactive() async throws {
    let provider = RunningActivityProvider(
        source: FixtureRunningActivitySource(
            result: .success(
                RunningActivitySnapshot(
                    applications: [],
                    processes: [],
                    processStatus: .unavailable(.permissionDenied),
                    observedAt: Date(timeIntervalSince1970: 30)
                )
            )
        )
    )

    let result = await provider.collect(
        query: try RelatedProcessQuery(
            bundleIdentifiers: [],
            processNames: [
                DomainLabel(validating: "hidden-process"),
            ]
        ),
        observedAt: Date(timeIntervalSince1970: 31)
    )

    #expect(result.status == .unavailable(.permissionDenied))
    #expect(result.observation.state == .unavailable)
}

@Test
func activityProvidersSanitizeInvalidObservationTime() async throws {
    let invalidDate = Date(
        timeIntervalSinceReferenceDate: .infinity
    )
    let gitRunner = RecordingUnavailableGitRunner()
    let git = await GitActivityProvider(runner: gitRunner).collect(
        repositoryURL: URL(filePath: "/tmp/invalid-time"),
        observedAt: invalidDate
    )
    let running = await RunningActivityProvider(
        source: FixtureRunningActivitySource(
            result: .failure(.permissionDenied)
        )
    ).collect(
        query: try RelatedProcessQuery(
            bundleIdentifiers: [],
            processNames: [
                DomainLabel(validating: "fixture-process"),
            ]
        ),
        observedAt: invalidDate
    )

    #expect(git.status == .unavailable(.invalidInput))
    #expect(git.observations.allSatisfy {
        isValidActivityDate($0.observedAt)
    })
    #expect(running.status == .unavailable(.permissionDenied))
    #expect(isValidActivityDate(running.observation.observedAt))
}

@Test
func activityFingerprintIgnoresObservationAndStornautTimestampNoise() throws {
    let observation = try ActivityObservation(
        key: .processInactive,
        state: .satisfied,
        source: .runningProcess,
        origin: .external,
        observedAt: Date(timeIntervalSince1970: 10),
        reason: DomainToken(validating: "activity.process.inactive")
    )
    let laterObservation = try ActivityObservation(
        key: observation.key,
        state: observation.state,
        source: observation.source,
        origin: observation.origin,
        observedAt: Date(timeIntervalSince1970: 20),
        reason: observation.reason
    )
    let stornautTimestamp = try ActivityTimestampObservation(
        source: .filesystemModification,
        origin: .stornaut,
        observedAt: Date(timeIntervalSince1970: 30)
    )

    #expect(
        activityFingerprint(
            observations: [observation],
            timestamps: []
        ) == activityFingerprint(
            observations: [laterObservation],
            timestamps: [stornautTimestamp]
        )
    )
}

private actor FixtureRunningActivitySource: RunningActivitySnapshotting {
    let result: Result<RunningActivitySnapshot, RunningActivityProviderFailure>

    init(
        result: Result<
            RunningActivitySnapshot,
            RunningActivityProviderFailure
        >
    ) {
        self.result = result
    }

    func snapshot() async throws -> RunningActivitySnapshot {
        try result.get()
    }
}

private actor RecordingUnavailableGitRunner: GitCommandRunning {
    func run(_ request: GitCommandRequest) async throws -> GitCommandOutput {
        throw GitCommandRunnerError.launchFailed
    }
}

private struct ActivityFusionFixture: Decodable {
    let schemaVersion: Int
    let cases: [ActivityFusionFixtureCase]
}

private struct ActivityFusionFixtureCase: Decodable {
    let id: String
    let baseDisposition: ReclaimDisposition
    let requiredKeys: [String]
    let observations: [Observation]
    let expectedDisposition: ReclaimDisposition
    let expectedMissing: [String]

    struct Observation: Decodable {
        let key: String
        let state: ActivityEvidenceState
        let source: ActivityEvidenceSource
        let origin: ActivityObservationOrigin
        let observedAt: TimeInterval
    }
}

private func loadActivityFusionFixture() throws -> ActivityFusionFixture {
    let url = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Fixtures/Activity/fusion-cases.json")
    let decoder = JSONDecoder()
    let fixture = try decoder.decode(
        ActivityFusionFixture.self,
        from: Data(contentsOf: url)
    )
    #expect(fixture.schemaVersion == 1)
    return fixture
}
