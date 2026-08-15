import Foundation
import StornautCore
import StornautLifecycle
import Testing
@testable import StornautApp

@Test
func phaseCTrashDiagnosticLaunchRequestAcceptsOnlyOneAbsoluteConfig() {
    let request = PhaseCTrashDiagnosticLaunchRequest(arguments: [
        "Stornaut",
        "--stornaut-phase-c-trash-config=/tmp/stornaut-phase-c-trash.A/config.json",
    ])

    #expect(
        request?.configURL
            == URL(
                filePath:
                    "/tmp/stornaut-phase-c-trash.A/config.json"
            ).standardizedFileURL
    )
    #expect(
        PhaseCTrashDiagnosticLaunchRequest(arguments: [
            "Stornaut",
            "--stornaut-phase-c-trash-config=relative/config.json",
        ]) == nil
    )
    #expect(
        PhaseCTrashDiagnosticLaunchRequest(arguments: [
            "Stornaut",
            "--stornaut-phase-c-trash-config=/tmp/first/config.json",
            "--stornaut-phase-c-trash-config=/tmp/second/config.json",
        ]) == nil
    )
    #expect(
        PhaseCTrashDiagnosticLaunchRequest(arguments: [
            "Stornaut",
            "--stornaut-phase-c-trash-config",
            "/tmp/stornaut-phase-c-trash.A/config.json",
        ]) == nil
    )
    #expect(
        PhaseCTrashDiagnosticLaunchRequest(arguments: [
            "Stornaut",
            "--stornaut-phase-c-trash-config=/tmp/stornaut-phase-c-trash.A/config.json",
            "--stornaut-phase-c-trash-config",
        ]) == nil
    )
}

@Test
func phaseCTrashRecoveryLaunchRequestAcceptsOnlyOneAbsoluteConfig() {
    let request = PhaseCTrashRecoveryLaunchRequest(arguments: [
        "Stornaut",
        "--stornaut-phase-c-trash-recovery-config=/tmp/stornaut-phase-c-trash.A/recovery-config-aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee.json",
    ])

    #expect(
        request?.configURL
            == URL(
                filePath:
                    "/tmp/stornaut-phase-c-trash.A/recovery-config-aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee.json"
            ).standardizedFileURL
    )
    #expect(
        PhaseCTrashRecoveryLaunchRequest(arguments: [
            "Stornaut",
            "--stornaut-phase-c-trash-recovery-config=relative/recovery-config-aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee.json",
        ]) == nil
    )
    #expect(
        PhaseCTrashRecoveryLaunchRequest(arguments: [
            "Stornaut",
            "--stornaut-phase-c-trash-recovery-config=/tmp/first/recovery-config-aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee.json",
            "--stornaut-phase-c-trash-recovery-config=/tmp/second/recovery-config-aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee.json",
        ]) == nil
    )
    #expect(
        PhaseCTrashRecoveryLaunchRequest(arguments: [
            "Stornaut",
            "--stornaut-phase-c-trash-config=/tmp/stornaut-phase-c-trash.A/config.json",
            "--stornaut-phase-c-trash-recovery-config=/tmp/stornaut-phase-c-trash.A/recovery-config-aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee.json",
        ]) == nil
    )
    #expect(
        PhaseCTrashDiagnosticLaunchRequest(arguments: [
            "Stornaut",
            "--stornaut-phase-c-trash-config=/tmp/stornaut-phase-c-trash.A/config.json",
            "--stornaut-phase-c-trash-recovery-config=/tmp/stornaut-phase-c-trash.A/recovery-config-aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee.json",
        ]) == nil
    )
}

@MainActor
@Test
func phaseCTrashDiagnosticLaunchSelectsOnlyTheInertComposition() {
    let valid = StornautApp.makeComposition(arguments: [
        "Stornaut",
        "--stornaut-phase-c-trash-config=/tmp/stornaut-phase-c-trash.A/config.json",
    ])
    let malformedDuplicate = StornautApp.makeComposition(arguments: [
        "Stornaut",
        "--stornaut-phase-c-trash-config=/tmp/stornaut-phase-c-trash.A/config.json",
        "--stornaut-phase-c-trash-config",
    ])
    let relative = StornautApp.makeComposition(arguments: [
        "Stornaut",
        "--stornaut-phase-c-trash-config=relative/config.json",
    ])

    #expect(valid.kind == .phaseCTrashDiagnostic)
    #expect(malformedDuplicate.kind == .production)
    #expect(relative.kind == .production)
}

@MainActor
@Test
func phaseCTrashRecoveryLaunchSelectsOnlyTheInertComposition() {
    let valid = StornautApp.makeComposition(arguments: [
        "Stornaut",
        "--stornaut-phase-c-trash-recovery-config=/tmp/stornaut-phase-c-trash.A/recovery-config-aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee.json",
    ])
    let mixed = StornautApp.makeComposition(arguments: [
        "Stornaut",
        "--stornaut-phase-c-trash-config=/tmp/stornaut-phase-c-trash.A/config.json",
        "--stornaut-phase-c-trash-recovery-config=/tmp/stornaut-phase-c-trash.A/recovery-config-aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee.json",
    ])

    #expect(valid.kind == .phaseCTrashDiagnostic)
    #expect(mixed.kind == .production)
}

@MainActor
@Test
func phaseCTrashDiagnosticCompositionDoesNotRefreshOrdinaryAppServices()
    async
{
    let composition = AppComposition.phaseCTrashDiagnostic()

    await composition.model.refreshIfNeeded()
    await composition.model.refreshSettingsIfNeeded()

    #expect(composition.model.pageState == .empty)
    #expect(composition.model.settingsState == .idle)
    #expect(composition.model.scanActivity == .idle)
}

@Test
func phaseCTrashDiagnosticHarnessCreatesTheAttestedMarkerLayout()
    throws
{
    let fixture = try PhaseCTrashDiagnosticTestFixture()
    defer { fixture.remove() }

    try PhaseCTrashDiagnosticHarness.createFixture(
        diagnosticRoot: fixture.diagnosticRoot,
        fixtureRoot: fixture.fixtureRoot,
        itemURL: fixture.originalURL,
        nonce: fixture.nonce,
        markerName: fixture.itemMarkerName,
        marker: fixture.marker
    )
    let identity = try #require(
        FileIdentity.read(at: fixture.originalURL)
    )

    #expect(
        FileManager.default.fileExists(
            atPath: fixture.diagnosticRoot.appending(
                path:
                    ".stornaut-phase-c-trash-fixture-\(fixture.nonce)"
            ).path
        )
    )
    #expect(
        !FileManager.default.fileExists(
            atPath: fixture.fixtureRoot.appending(
                path:
                    ".stornaut-phase-c-trash-fixture-\(fixture.nonce)"
            ).path
        )
    )
    _ = try ExecutableEvidenceResolver.phaseCTrashDiagnostic(
        diagnosticRootURL: fixture.diagnosticRoot,
        fixtureRootURL: fixture.fixtureRoot,
        nonce: fixture.nonce,
        expectedTargetIdentity: identity
    )
}

@Test
func phaseCTrashDiagnosticWiresOneAttestationAcrossEveryDecisionLayer()
    throws
{
    let repositoryRoot = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let dependenciesSource = try String(
        contentsOf: repositoryRoot.appending(
            path: "StornautApp/AppState/AppDependencies.swift"
        ),
        encoding: .utf8
    )
    let harnessSource = try String(
        contentsOf: repositoryRoot.appending(
            path:
                "StornautApp/Diagnostics/PhaseCTrashDiagnosticHarness.swift"
        ),
        encoding: .utf8
    )

    for required in [
        "diagnosticEvidenceResolver:",
        "private let diagnosticEvidenceResolver:",
        "QuickScanCoordinator\n                        .phaseCTrashDiagnostic(",
        "CleanupPlanBuilder\n                    .phaseCTrashDiagnostic(",
        "makeExecutionRuntime(\n            store,\n            observer,\n            workflowCoordinator,\n            diagnosticEvidenceResolver",
    ] {
        #expect(dependenciesSource.contains(required))
    }
    for required in [
        "let evidenceResolver = try ExecutableEvidenceResolver\n                .phaseCTrashDiagnostic(",
        "diagnosticEvidenceResolver: evidenceResolver",
        "resolver: $3",
    ] {
        #expect(harnessSource.contains(required))
    }
    #expect(
        harnessSource.components(
            separatedBy: "ExecutableEvidenceResolver"
        ).count == 2
    )
}

@Test
func phaseCTrashDiagnosticBuildsAndPreflightsOnlyItsIsolatedTarget()
    async throws
{
    let fixture = try PhaseCTrashDiagnosticTestFixture()
    defer { fixture.remove() }
    let identity = try fixture.createExecutableTarget()
    let resolver = try ExecutableEvidenceResolver
        .phaseCTrashDiagnostic(
            diagnosticRootURL: fixture.diagnosticRoot,
            fixtureRootURL: fixture.fixtureRoot,
            nonce: fixture.nonce,
            expectedTargetIdentity: identity
        )
    let observation = CleanupTrashDiagnosticObservation()
    let configuration = try LocalStoreConfiguration(
        applicationSupportBaseURL: fixture.diagnosticRoot.appending(
            path: "support",
            directoryHint: .isDirectory
        ),
        cachesBaseURL: fixture.diagnosticRoot.appending(
            path: "caches",
            directoryHint: .isDirectory
        )
    )
    let dependencies = AppDependencies.phaseCTrashDiagnostic(
        configuration: configuration,
        rootURL: fixture.fixtureRoot,
        diagnosticEvidenceResolver: resolver,
        makeExecutionRuntime: {
            try CleanupExecutionRuntime.diagnostic(
                store: $0,
                rootObserver: $1,
                workflowCoordinator: $2,
                resolver: $3,
                observation: observation
            )
        }
    )

    let stream = try await dependencies.startQuickScan()
    var projection: QuickScanProjection?
    for try await event in stream {
        if case let .terminal(value) = event {
            projection = value
        }
    }
    let completed = try #require(projection)
    let inspectionStore = try EvidenceStore(
        configuration: configuration
    )
    let persistedSession = try await inspectionStore.scanSession(
        id: completed.session.id
    )
    let summary = try await inspectionStore.quickScanSummary(
        sessionID: completed.session.id
    )
    let snapshots = try await inspectionStore.pathSnapshots(
        sessionID: completed.session.id,
        limit: 100,
        offset: 0
    )
    let evidence = try await inspectionStore.evidence(
        sessionID: completed.session.id,
        limit: 100,
        offset: 0
    )

    let storedSession = try #require(persistedSession)
    #expect(storedSession.id == completed.session.id)
    #expect(storedSession.terminalState == completed.session.terminalState)
    #expect(
        storedSession.completedScopes.count
            == completed.session.completedScopes.count
    )
    #expect(
        zip(
            storedSession.completedScopes,
            completed.session.completedScopes
        ).allSatisfy {
            $0.id == $1.id
                && $0.rootPath == $1.rootPath
                && abs(
                    $0.completedAt.timeIntervalSince($1.completedAt)
                ) < 0.001
        }
    )
    #expect(storedSession.unfinishedScopes == completed.session.unfinishedScopes)
    #expect(storedSession.aggregate == completed.session.aggregate)
    #expect(
        abs(
            storedSession.startedAt.timeIntervalSince(
                completed.session.startedAt
            )
        ) < 0.001
    )
    #expect(
        abs(
            storedSession.finishedAt.timeIntervalSince(
                completed.session.finishedAt
            )
        ) < 0.001
    )
    #expect(summary.retainedSnapshotCount == snapshots.records.count)
    #expect(summary.classificationCount > 0)
    #expect(summary.classificationCount <= snapshots.records.count)
    #expect(summary.evidenceCount == evidence.records.count)
    #expect(snapshots.corruptRecordIDs.isEmpty)
    #expect(evidence.corruptRecordIDs.isEmpty)
    #expect(Set(evidence.records.map(\.id)).count == evidence.records.count)
    let targetSnapshot = try #require(
        snapshots.records.first {
            $0.relativePath == ".npm/_cacache"
        }
    )
    #expect(targetSnapshot.fileIdentity == identity)
    #expect(
        evidence.records
            .filter { $0.targetID == targetSnapshot.id }
            .allSatisfy {
                $0.observedAt >= storedSession.startedAt
                    && $0.observedAt <= storedSession.finishedAt
            }
    )
    let build = await dependencies.buildReview()
    let plan: CleanupPlan
    let item: CleanupPlanItem
    switch build {
    case let .planReady(value, review):
        plan = value
        item = try #require(value.items.first)
        #expect(value.items.count == 1)
        #expect(review.counts.executableReady == 1)
    case let .unavailable(reasons):
        Issue.record(
            "isolated diagnostic plan unavailable: \(reasons)"
        )
        return
    case let .empty(review):
        Issue.record(
            "isolated diagnostic plan was empty: \(review)"
        )
        return
    case let .scanAgain(reasons):
        Issue.record(
            "isolated diagnostic requested another scan: \(reasons)"
        )
        return
    }
    #expect(completed.session.terminalState == .completed)
    #expect(item.expectedRelativePath?.rawValue == ".npm/_cacache")
    #expect(item.expectedIdentity == identity)
    let storedPlan = try #require(
        try await inspectionStore.cleanupPlan(id: plan.id)
    )
    #expect(storedPlan == plan)
    let policyRecords = try await inspectionStore.cleanupPolicyRecords(
        plan: plan,
        selectedItemIDs: [item.id]
    )
    #expect(policyRecords.count == 1)
    #expect(policyRecords[0].planItem == item)

    let selection = try ReviewSelection(
        plan: plan,
        generation: 1,
        items: [
            ReviewSelectionItem(
                itemID: item.id,
                origin: .defaultReady
            ),
        ],
        dispositions: [item.id: .readyToReclaim]
    )
    let evaluation = try await dependencies.preflightReview(
        plan,
        selection
    )

    #expect(evaluation.allowed != nil)
    #expect(observation.attemptCount() == 0)
    #expect(FileIdentity.read(at: fixture.originalURL) == identity)
}

@Test
func ordinaryLiveCompositionHasNoExecutableDependencySurface() throws {
    let repositoryRoot = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let source = try String(
        contentsOf: repositoryRoot.appending(
            path: "StornautApp/AppState/AppDependencies.swift"
        ),
        encoding: .utf8
    )
    let liveStart = try #require(
        source.range(of: "    static func live(")
    )
    let liveSuffix = source[liveStart.lowerBound...]
    let diagnosticStart = try #require(
        liveSuffix.range(
            of: "\n#if DEBUG\n    static func phaseCTrashDiagnostic("
        )
    )
    let liveBody = liveSuffix[..<diagnosticStart.lowerBound]

    #expect(!liveBody.contains("ReviewExecutionAvailability"))
    #expect(!liveBody.contains("ExecutableEvidenceResolver"))
    #expect(!liveBody.contains("ExecutionRuntimeFactory"))
    #expect(!liveBody.contains("productionTrash"))
    #expect(!liveBody.contains("makeExecutionRuntime"))
}

@Test
func phaseCRecoveryRevalidatesRetainedArtifactsAtExecutionBoundary()
    throws
{
    let repositoryRoot = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let source = try String(
        contentsOf: repositoryRoot.appending(
            path:
                "StornautApp/Diagnostics/PhaseCTrashRecoveryHarness.swift"
        ),
        encoding: .utf8
    )
    let executeStart = try #require(
        source.range(of: "    private static func execute(")
    )
    let executeSuffix = source[executeStart.lowerBound...]
    let retainedRead = try #require(
        executeSuffix.range(of: "let retainedConfig =")
    )
    let storeOpen = try #require(
        executeSuffix.range(of: "let store = try EvidenceStore(")
    )
    let boundary = executeSuffix[
        retainedRead.lowerBound..<storeOpen.lowerBound
    ]

    #expect(
        boundary.contains(
            "try revalidateRetainedArtifacts(config)"
        )
    )
    #expect(
        executeSuffix.contains(
            "let preOpenBinding = try retainedArtifactBinding(config)"
        )
    )
    #expect(
        executeSuffix.contains(
            "try retainedArtifactBinding(config)"
                + "\n                    == preOpenBinding"
        )
    )
    #expect(
        executeSuffix.contains(
            "try await store.diagnosticDatabaseSHA256()"
        )
    )
    #expect(
        executeSuffix.contains(
            "let residual = PhaseCTrashDiagnosticResidual.make("
        )
    )
    #expect(
        executeSuffix.contains(
            "let trashPresent = residual.trashPresent"
        )
    )
}

@Test
func phaseCTrashRecoveryConfigurationBindsRetainedEvidenceAndCurrentApp()
    throws
{
    let fixture = try PhaseCTrashRecoveryTestFixture()
    defer { fixture.remove() }
    let data = try JSONSerialization.data(
        withJSONObject: fixture.configurationObject()
    )

    let configuration = try PhaseCTrashRecoveryConfiguration.validated(
        data: data,
        configURL: fixture.recoveryConfigURL,
        environment: [
            PhaseCTrashRecoveryConfiguration.optInEnvironmentKey:
                fixture.recoveryOptInNonce,
        ],
        now: fixture.now,
        bundleIdentifier: "com.eriklee.stornaut",
        executableSHA256: fixture.recoveryExecutableSHA256
    )

    #expect(configuration.diagnosticNonce == fixture.diagnosticNonce)
    #expect(configuration.expectedJournalID == fixture.journalID)
    #expect(configuration.expectedManifestID == fixture.manifestID)
    #expect(
        configuration.expectedOriginalIdentity
            == fixture.originalIdentity
    )
    #expect(
        configuration.expectedDestinationParentIdentity
            == fixture.destinationParentIdentity
    )

    var unknown = fixture.configurationObject()
    unknown["unexpected"] = true
    #expect(throws: PhaseCTrashRecoveryError.invalidConfiguration) {
        _ = try PhaseCTrashRecoveryConfiguration.validated(
            data: JSONSerialization.data(withJSONObject: unknown),
            configURL: fixture.recoveryConfigURL,
            environment: [
                PhaseCTrashRecoveryConfiguration.optInEnvironmentKey:
                    fixture.recoveryOptInNonce,
            ],
            now: fixture.now,
            bundleIdentifier: "com.eriklee.stornaut",
            executableSHA256: fixture.recoveryExecutableSHA256
        )
    }

    var changedReport = fixture.configurationObject()
    changedReport["expectedRetainedReportSHA256"] =
        String(repeating: "f", count: 64)
    #expect(throws: PhaseCTrashRecoveryError.retainedEvidenceMismatch) {
        _ = try PhaseCTrashRecoveryConfiguration.validated(
            data: JSONSerialization.data(
                withJSONObject: changedReport
            ),
            configURL: fixture.recoveryConfigURL,
            environment: [
                PhaseCTrashRecoveryConfiguration.optInEnvironmentKey:
                    fixture.recoveryOptInNonce,
            ],
            now: fixture.now,
            bundleIdentifier: "com.eriklee.stornaut",
            executableSHA256: fixture.recoveryExecutableSHA256
        )
    }
}

@Test
func phaseCTrashRecoverySourceCannotReplayProductExecution() throws {
    let repositoryRoot = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let source = try String(
        contentsOf: repositoryRoot.appending(
            path:
                "StornautApp/Diagnostics/PhaseCTrashRecoveryHarness.swift"
        ),
        encoding: .utf8
    )

    for required in [
        "CleanupExecutionRuntime.diagnosticRecovery(",
        "observation.invocationCount() == 0",
        "PhaseCTrashDiagnosticRestore.restore(",
        "stage == .actionOutcomeRecorded",
        "stage == .finalized",
    ] {
        #expect(source.contains(required))
    }
    for forbidden in [
        "createFixture(",
        "startQuickScan(",
        "buildReview(",
        "preflightReview(",
        "startReviewExecution(",
        "CleanupExecutionRuntime.diagnostic(",
        "CleanupTrashDiagnosticObservation",
        "FileManagerTrashAdapter",
        "trashItem(",
    ] {
        #expect(!source.contains(forbidden))
    }
}

@Test
func phaseCTrashDiagnosticConfigurationRejectsUnknownKeysAndPathEscape()
    throws
{
    let fixture = try PhaseCTrashDiagnosticTestFixture()
    defer { fixture.remove() }
    let valid = fixture.configurationObject()
    let validData = try JSONSerialization.data(withJSONObject: valid)

    let configuration = try PhaseCTrashDiagnosticConfiguration.validated(
        data: validData,
        configURL: fixture.configURL,
        environment: [
            "STORNAUT_PHASE_C_TRASH_OPT_IN": fixture.optInNonce,
        ],
        now: fixture.now,
        bundleIdentifier: "com.eriklee.stornaut",
        executableSHA256: fixture.executableSHA256
    )

    #expect(configuration.fixtureRoot == fixture.fixtureRoot.path)
    #expect(configuration.expectedRelativePath == ".npm/_cacache")

    if fixture.diagnosticRoot.path.hasPrefix("/var/") {
        let privateAliasRootPath =
            "/private" + fixture.diagnosticRoot.path
        var privateAlias = valid
        privateAlias["diagnosticRoot"] = privateAliasRootPath
        privateAlias["fixtureRoot"] =
            privateAliasRootPath + "/fixture"
        privateAlias["applicationSupportBase"] =
            privateAliasRootPath + "/support"
        privateAlias["cachesBase"] =
            privateAliasRootPath + "/caches"
        privateAlias["reportPath"] =
            privateAliasRootPath + "/report.json"
        let privateConfigURL = URL(
            filePath: privateAliasRootPath + "/config.json"
        ).standardizedFileURL
        let aliasConfiguration = try
            PhaseCTrashDiagnosticConfiguration.validated(
                data: JSONSerialization.data(
                    withJSONObject: privateAlias
                ),
                configURL: privateConfigURL,
                environment: [
                    "STORNAUT_PHASE_C_TRASH_OPT_IN":
                        fixture.optInNonce,
                ],
                now: fixture.now,
                bundleIdentifier: "com.eriklee.stornaut",
                executableSHA256: fixture.executableSHA256
            )
        #expect(
            aliasConfiguration.diagnosticRoot == privateAliasRootPath
        )
    }

    var unknown = valid
    unknown["unexpected"] = true
    #expect(throws: PhaseCTrashDiagnosticError.invalidConfiguration) {
        _ = try PhaseCTrashDiagnosticConfiguration.validated(
            data: JSONSerialization.data(withJSONObject: unknown),
            configURL: fixture.configURL,
            environment: [
                "STORNAUT_PHASE_C_TRASH_OPT_IN": fixture.optInNonce,
            ],
            now: fixture.now,
            bundleIdentifier: "com.eriklee.stornaut",
            executableSHA256: fixture.executableSHA256
        )
    }

    var escaped = valid
    escaped["reportPath"] = fixture.diagnosticRoot
        .deletingLastPathComponent()
        .appending(path: "escaped-report.json").path
    #expect(throws: PhaseCTrashDiagnosticError.unsafePath) {
        _ = try PhaseCTrashDiagnosticConfiguration.validated(
            data: JSONSerialization.data(withJSONObject: escaped),
            configURL: fixture.configURL,
            environment: [
                "STORNAUT_PHASE_C_TRASH_OPT_IN": fixture.optInNonce,
            ],
            now: fixture.now,
            bundleIdentifier: "com.eriklee.stornaut",
            executableSHA256: fixture.executableSHA256
        )
    }
}

@Test
func phaseCTrashDiagnosticConfigurationRejectsStaleOrMismatchedOptIn()
    throws
{
    let fixture = try PhaseCTrashDiagnosticTestFixture()
    defer { fixture.remove() }
    let data = try JSONSerialization.data(
        withJSONObject: fixture.configurationObject()
    )

    #expect(throws: PhaseCTrashDiagnosticError.optInMismatch) {
        _ = try PhaseCTrashDiagnosticConfiguration.validated(
            data: data,
            configURL: fixture.configURL,
            environment: [:],
            now: fixture.now,
            bundleIdentifier: "com.eriklee.stornaut",
            executableSHA256: fixture.executableSHA256
        )
    }
    #expect(throws: PhaseCTrashDiagnosticError.buildMismatch) {
        _ = try PhaseCTrashDiagnosticConfiguration.validated(
            data: data,
            configURL: fixture.configURL,
            environment: [
                "STORNAUT_PHASE_C_TRASH_OPT_IN": fixture.optInNonce,
            ],
            now: fixture.now,
            bundleIdentifier: "com.eriklee.stornaut",
            executableSHA256: String(repeating: "b", count: 64)
        )
    }
    #expect(throws: PhaseCTrashDiagnosticError.expired) {
        _ = try PhaseCTrashDiagnosticConfiguration.validated(
            data: data,
            configURL: fixture.configURL,
            environment: [
                "STORNAUT_PHASE_C_TRASH_OPT_IN": fixture.optInNonce,
            ],
            now: fixture.now.addingTimeInterval(301),
            bundleIdentifier: "com.eriklee.stornaut",
            executableSHA256: fixture.executableSHA256
        )
    }
}

@Test
func phaseCTrashDiagnosticPreflightReceiptUsesOnlySafeFixedSibling()
    throws
{
    let fixture = try PhaseCTrashDiagnosticTestFixture()
    defer { fixture.remove() }
    let startedAt = Date()

    let signingReceipt = PhaseCTrashDiagnosticPreflightReceipt.make(
        error: LifecycleSigningIdentityError.unavailable,
        startedAt: startedAt
    )
    #expect(signingReceipt.schemaVersion == 1)
    #expect(signingReceipt.outcome == "signedAppTrashPreflightBlocked")
    #expect(signingReceipt.errorStage == "signing")
    #expect(signingReceipt.error == .signingEvidenceUnavailable)
    #expect(signingReceipt.startedAt == startedAt)
    #expect(signingReceipt.finishedAt >= startedAt)
    #expect(
        phaseCTrashDiagnosticPreflightReceiptURL(
            configURL: fixture.configURL
        ) == fixture.diagnosticRoot.appending(
            path: "preflight-error.json"
        )
    )

    let configurationReceipt =
        PhaseCTrashDiagnosticPreflightReceipt.make(
            error: PhaseCTrashDiagnosticError.expired,
            startedAt: startedAt
        )
    #expect(configurationReceipt.errorStage == "configuration")
    #expect(configurationReceipt.error == .expired)

    try Data().write(
        to: fixture.diagnosticRoot.appending(path: "unexpected")
    )
    #expect(
        phaseCTrashDiagnosticPreflightReceiptURL(
            configURL: fixture.configURL
        ) == nil
    )
    #expect(
        phaseCTrashDiagnosticPreflightReceiptURL(
            configURL: fixture.diagnosticRoot
                .deletingLastPathComponent()
                .appending(path: "config.json")
        ) == nil
    )
}

@Test
func phaseCTrashDiagnosticReportEncodesCompleteSchemaWithExplicitNulls()
    throws
{
    let report = PhaseCTrashDiagnosticReport(
        schemaVersion: 2,
        nonce: "11111111-2222-4333-8444-555555555555",
        startedAt: Date(timeIntervalSince1970: 100),
        finishedAt: Date(timeIntervalSince1970: 101),
        outcome: "signedAppTrashBlocked",
        configured: true,
        planned: false,
        observed: false,
        contained: false,
        restored: false,
        bundleIdentifier: "com.eriklee.stornaut",
        executablePath: nil,
        executableSHA256: nil,
        designatedRequirementSHA256: String(
            repeating: "a",
            count: 64
        ),
        codeDirectoryHash: String(repeating: "b", count: 40),
        adHocSigned: nil,
        appSandboxEntitlement: nil,
        expectedRelativePath: ".npm/_cacache",
        planID: nil,
        selectionGeneration: nil,
        selectionFingerprint: nil,
        decisionFingerprint: nil,
        originalIdentity: nil,
        returnedTrashPath: nil,
        destinationIdentity: nil,
        trashAttemptCount: 0,
        journalID: nil,
        journalStage: nil,
        journalEntryCount: nil,
        manifestID: nil,
        manifestRecordCount: nil,
        succeededCount: nil,
        failedCount: nil,
        cancelledCount: nil,
        unknownCount: nil,
        selectedLogicalBytes: nil,
        processedLogicalBytes: nil,
        movedToTrashLogicalBytes: nil,
        permanentlyReleasedLogicalBytes: nil,
        systemObservationRecorded: false,
        restoreOutcome: nil,
        residual: PhaseCTrashDiagnosticResidual(
            originalPresent: true,
            trashPresent: nil,
            fixtureRootPresent: true
        ),
        errorStage: "planning",
        error: .planFailed,
        limitations: ["diagnostic-owned disposable fixture only"]
    )

    let encoded = try JSONEncoder.phaseCTest.encode(report)
    let object = try #require(
        JSONSerialization.jsonObject(with: encoded)
            as? [String: Any]
    )
    #expect(
        Set(object.keys) == PhaseCTrashDiagnosticReport.requiredJSONKeys
    )
    for key in [
        "planID",
        "selectionGeneration",
        "returnedTrashPath",
        "manifestID",
        "restoreOutcome",
    ] {
        #expect(object[key] is NSNull)
    }
    #expect(object["trashAttemptCount"] as? Int == 0)
    let residual = try #require(
        object["residual"] as? [String: Any]
    )
    #expect(residual["trashPresent"] is NSNull)
}

@Test
func phaseCTrashDiagnosticSanitizesEveryExecutionRejectionReason() {
    let cases: [
        (
            CleanupExecutionState,
            PhaseCTrashDiagnosticError
        )
    ] = [
        (
            .rejected(.authorization),
            .executionRejectedAuthorization
        ),
        (
            .rejected(.workflowConflict),
            .executionRejectedWorkflowConflict
        ),
        (
            .rejected(.planMismatch),
            .executionRejectedPlanMismatch
        ),
        (
            .rejected(.persistence),
            .executionRejectedPersistence
        ),
        (
            .rejected(.programmingError),
            .executionRejectedProgrammingError
        ),
    ]

    for (state, expected) in cases {
        #expect(state.phaseCDiagnosticFailure == expected)
        #expect(state.phaseCDiagnosticResult == nil)
    }
}

@Test
func phaseCTrashDiagnosticRestoreRequiresExactMarkerIdentityAndDestination()
    throws
{
    let fixture = try PhaseCTrashDiagnosticTestFixture()
    defer { fixture.remove() }
    try FileManager.default.createDirectory(
        at: fixture.originalURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let trashURL = fixture.diagnosticRoot.appending(
        path: "simulated-trash",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: trashURL,
        withIntermediateDirectories: false
    )
    try Data(fixture.marker.utf8).write(
        to: trashURL.appending(path: fixture.itemMarkerName)
    )
    let identity = try #require(FileIdentity.read(at: trashURL))
    let parentIdentity = try #require(
        FileIdentity.read(
            at: fixture.originalURL.deletingLastPathComponent()
        )
    )

    let outcome = PhaseCTrashDiagnosticRestore.restore(
        returnedTrashURL: trashURL,
        originalURL: fixture.originalURL,
        expectedIdentity: identity,
        expectedDestinationParentIdentity: parentIdentity,
        marker: fixture.marker,
        markerName: fixture.itemMarkerName
    )

    #expect(outcome == .restored)
    #expect(FileIdentity.read(at: fixture.originalURL) == identity)
    #expect(!FileManager.default.fileExists(atPath: trashURL.path))
}

@Test
func phaseCTrashDiagnosticRestoreNeverOverwritesOrMovesChangedIdentity()
    throws
{
    let fixture = try PhaseCTrashDiagnosticTestFixture()
    defer { fixture.remove() }
    try FileManager.default.createDirectory(
        at: fixture.originalURL,
        withIntermediateDirectories: true
    )
    let trashURL = fixture.diagnosticRoot.appending(
        path: "simulated-trash",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: trashURL,
        withIntermediateDirectories: false
    )
    try Data(fixture.marker.utf8).write(
        to: trashURL.appending(path: fixture.itemMarkerName)
    )
    let identity = try #require(FileIdentity.read(at: trashURL))
    let parentIdentity = try #require(
        FileIdentity.read(
            at: fixture.originalURL.deletingLastPathComponent()
        )
    )

    #expect(
        PhaseCTrashDiagnosticRestore.restore(
            returnedTrashURL: trashURL,
            originalURL: fixture.originalURL,
            expectedIdentity: identity,
            expectedDestinationParentIdentity: parentIdentity,
            marker: fixture.marker,
            markerName: fixture.itemMarkerName
        ) == .originalOccupied
    )
    #expect(FileIdentity.read(at: trashURL) == identity)

    try FileManager.default.removeItem(at: fixture.originalURL)
    let changed = try FileIdentity(
        device: identity.device,
        inode: identity.inode &+ 1,
        mode: identity.mode,
        ownerUserID: identity.ownerUserID,
        ownerGroupID: identity.ownerGroupID,
        linkCount: identity.linkCount,
        size: identity.size,
        allocatedBytes: identity.allocatedBytes,
        modificationSeconds: identity.modificationSeconds,
        modificationNanoseconds: identity.modificationNanoseconds
    )
    #expect(
        PhaseCTrashDiagnosticRestore.restore(
            returnedTrashURL: trashURL,
            originalURL: fixture.originalURL,
            expectedIdentity: changed,
            expectedDestinationParentIdentity: parentIdentity,
            marker: fixture.marker,
            markerName: fixture.itemMarkerName
        ) == .identityChanged
    )
    #expect(FileIdentity.read(at: trashURL) == identity)
}

@Test
func phaseCTrashDiagnosticRestoreRejectsReplacedDestinationParent()
    throws
{
    let fixture = try PhaseCTrashDiagnosticTestFixture()
    defer { fixture.remove() }
    let originalParent = fixture.originalURL
        .deletingLastPathComponent()
    try FileManager.default.createDirectory(
        at: originalParent,
        withIntermediateDirectories: true
    )
    let escapedParent = fixture.diagnosticRoot.appending(
        path: "escaped-parent",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: escapedParent,
        withIntermediateDirectories: false
    )
    let trashURL = fixture.diagnosticRoot.appending(
        path: "simulated-trash-parent-swap",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: trashURL,
        withIntermediateDirectories: false
    )
    try Data(fixture.marker.utf8).write(
        to: trashURL.appending(path: fixture.itemMarkerName)
    )
    let identity = try #require(FileIdentity.read(at: trashURL))
    let parentIdentity = try #require(
        FileIdentity.read(at: originalParent)
    )
    try FileManager.default.removeItem(at: originalParent)
    try FileManager.default.createSymbolicLink(
        at: originalParent,
        withDestinationURL: escapedParent
    )

    let outcome = PhaseCTrashDiagnosticRestore.restore(
        returnedTrashURL: trashURL,
        originalURL: fixture.originalURL,
        expectedIdentity: identity,
        expectedDestinationParentIdentity: parentIdentity,
        marker: fixture.marker,
        markerName: fixture.itemMarkerName
    )

    #expect(outcome != .restored)
    #expect(FileIdentity.read(at: trashURL) == identity)
    #expect(
        !FileManager.default.fileExists(
            atPath: escapedParent.appending(
                path: fixture.originalURL.lastPathComponent
            ).path
        )
    )
}

@Test
func phaseCTrashDiagnosticRestoreDoesNotFollowParentReplacedAfterValidation()
    throws
{
    let fixture = try PhaseCTrashDiagnosticTestFixture()
    defer { fixture.remove() }
    let originalParent = fixture.originalURL
        .deletingLastPathComponent()
    try FileManager.default.createDirectory(
        at: originalParent,
        withIntermediateDirectories: true
    )
    let escapedParent = fixture.diagnosticRoot.appending(
        path: "escaped-parent-after-validation",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: escapedParent,
        withIntermediateDirectories: false
    )
    let trashURL = fixture.diagnosticRoot.appending(
        path: "simulated-trash-parent-race",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: trashURL,
        withIntermediateDirectories: false
    )
    try Data(fixture.marker.utf8).write(
        to: trashURL.appending(path: fixture.itemMarkerName)
    )
    let identity = try #require(FileIdentity.read(at: trashURL))
    let parentIdentity = try #require(
        FileIdentity.read(at: originalParent)
    )

    let outcome = PhaseCTrashDiagnosticRestore.restore(
        returnedTrashURL: trashURL,
        originalURL: fixture.originalURL,
        expectedIdentity: identity,
        expectedDestinationParentIdentity: parentIdentity,
        marker: fixture.marker,
        markerName: fixture.itemMarkerName,
        beforeMove: {
            try FileManager.default.removeItem(at: originalParent)
            try FileManager.default.createSymbolicLink(
                at: originalParent,
                withDestinationURL: escapedParent
            )
        }
    )

    #expect(outcome != .restored)
    #expect(FileIdentity.read(at: trashURL) == identity)
    #expect(
        !FileManager.default.fileExists(
            atPath: escapedParent.appending(
                path: fixture.originalURL.lastPathComponent
            ).path
        )
    )
}

@Test
func phaseCTrashDiagnosticRestoreNeverRetriesAPriorAttempt()
    throws
{
    let fixture = try PhaseCTrashDiagnosticTestFixture()
    defer { fixture.remove() }
    try FileManager.default.createDirectory(
        at: fixture.originalURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let trashURL = fixture.diagnosticRoot.appending(
        path: "simulated-trash-prior-attempt",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: trashURL,
        withIntermediateDirectories: false
    )
    try Data(fixture.marker.utf8).write(
        to: trashURL.appending(path: fixture.itemMarkerName)
    )
    let identity = try #require(FileIdentity.read(at: trashURL))
    let parentIdentity = try #require(
        FileIdentity.read(
            at: fixture.originalURL.deletingLastPathComponent()
        )
    )
    let moveProbe = PhaseCTestMoveProbe()

    let outcome = PhaseCTrashDiagnosticRestore.restoreIfNeeded(
        existingOutcome: .moveFailed,
        returnedTrashURL: trashURL,
        originalURL: fixture.originalURL,
        expectedIdentity: identity,
        expectedDestinationParentIdentity: parentIdentity,
        marker: fixture.marker,
        markerName: fixture.itemMarkerName,
        beforeMove: moveProbe.move
    )

    #expect(outcome == .moveFailed)
    #expect(moveProbe.callCount == 0)
    #expect(FileIdentity.read(at: trashURL) == identity)
}

@Test
func phaseCTrashDiagnosticResidualKeepsUnlocatedTrashUnknown()
    throws
{
    let fixture = try PhaseCTrashDiagnosticTestFixture()
    defer { fixture.remove() }
    try FileManager.default.createDirectory(
        at: fixture.originalURL,
        withIntermediateDirectories: true
    )
    let identity = try #require(
        FileIdentity.read(at: fixture.originalURL)
    )
    try FileManager.default.moveItem(
        at: fixture.originalURL,
        to: fixture.diagnosticRoot.appending(
            path: "unlocated-after-attempt",
            directoryHint: .isDirectory
        )
    )

    let residual = PhaseCTrashDiagnosticResidual.make(
        originalURL: fixture.originalURL,
        returnedTrashURL: nil,
        expectedIdentity: identity,
        fixtureRoot: fixture.fixtureRoot,
        trashWasAttempted: true
    )

    #expect(residual.originalPresent == false)
    #expect(residual.trashPresent == nil)
    #expect(residual.fixtureRootPresent)

    let wrongReturnedURL = fixture.diagnosticRoot.appending(
        path: "wrong-returned-object",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: wrongReturnedURL,
        withIntermediateDirectories: false
    )
    let mismatchedResidual = PhaseCTrashDiagnosticResidual.make(
        originalURL: fixture.originalURL,
        returnedTrashURL: wrongReturnedURL,
        expectedIdentity: identity,
        fixtureRoot: fixture.fixtureRoot,
        trashWasAttempted: true
    )

    #expect(mismatchedResidual.originalPresent == false)
    #expect(mismatchedResidual.trashPresent == nil)

    try FileManager.default.createDirectory(
        at: fixture.originalURL,
        withIntermediateDirectories: true
    )
    let restoredWithReplacedTrashPath =
        PhaseCTrashDiagnosticResidual.make(
            originalURL: fixture.originalURL,
            returnedTrashURL: wrongReturnedURL,
            expectedIdentity: try #require(
                FileIdentity.read(at: fixture.originalURL)
            ),
            fixtureRoot: fixture.fixtureRoot,
            trashWasAttempted: true
        )

    #expect(restoredWithReplacedTrashPath.originalPresent)
    #expect(restoredWithReplacedTrashPath.trashPresent == nil)

    let unqueryableReturnedURL = fixture.diagnosticRoot.appending(
        path: String(repeating: "x", count: Int(PATH_MAX) + 1)
    )
    let unqueryableResidual = PhaseCTrashDiagnosticResidual.make(
        originalURL: fixture.originalURL,
        returnedTrashURL: unqueryableReturnedURL,
        expectedIdentity: try #require(
            FileIdentity.read(at: fixture.originalURL)
        ),
        fixtureRoot: fixture.fixtureRoot,
        trashWasAttempted: true
    )

    #expect(unqueryableResidual.originalPresent)
    #expect(unqueryableResidual.trashPresent == nil)
    #expect(recoveryPathPresence(unqueryableReturnedURL) == nil)
}

private extension JSONEncoder {
    static var phaseCTest: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private final class PhaseCTestMoveProbe:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var calls = 0

    var callCount: Int {
        lock.withLock { calls }
    }

    func move() throws {
        lock.withLock {
            calls += 1
        }
    }
}

private struct PhaseCTrashDiagnosticTestFixture {
    let now = Date(timeIntervalSince1970: 1_787_000_000)
    let nonce = "11111111-2222-4333-8444-555555555555"
    let optInNonce = "66666666-7777-4888-8999-aaaaaaaaaaaa"
    let executableSHA256 = String(repeating: "a", count: 64)
    let diagnosticRoot: URL
    let configURL: URL
    let fixtureRoot: URL
    let originalURL: URL
    let marker: String
    let itemMarkerName: String

    init() throws {
        diagnosticRoot = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-phase-c-trash.\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        configURL = diagnosticRoot.appending(path: "config.json")
        fixtureRoot = diagnosticRoot.appending(
            path: "fixture",
            directoryHint: .isDirectory
        )
        originalURL = fixtureRoot.appending(
            path: ".npm/_cacache",
            directoryHint: .isDirectory
        )
        marker = "stornaut-phase-c-trash-item:\(nonce)"
        itemMarkerName = ".stornaut-phase-c-trash-item-\(nonce)"
        try FileManager.default.createDirectory(
            at: diagnosticRoot,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        try Data("{}".utf8).write(to: configURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: configURL.path
        )
    }

    func configurationObject() -> [String: Any] {
        [
            "schemaVersion": 1,
            "nonce": nonce,
            "optInStatement":
                "I authorize Stornaut Task 35 to Trash and restore only this disposable fixture.",
            "optInNonce": optInNonce,
            "diagnosticRoot": diagnosticRoot.path,
            "fixtureRoot": fixtureRoot.path,
            "applicationSupportBase": diagnosticRoot
                .appending(path: "support").path,
            "cachesBase": diagnosticRoot.appending(path: "caches").path,
            "reportPath": diagnosticRoot.appending(path: "report.json").path,
            "expectedBundleIdentifier": "com.eriklee.stornaut",
            "expectedExecutableSHA256": executableSHA256,
            "expectedRelativePath": ".npm/_cacache",
            "issuedAt": now.timeIntervalSince1970,
            "expiresAt": now.addingTimeInterval(300).timeIntervalSince1970,
        ]
    }

    func createExecutableTarget() throws -> FileIdentity {
        try FileManager.default.createDirectory(
            at: originalURL.appending(
                path: "content-v2/sha512",
                directoryHint: .isDirectory
            ),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        for url in [
            fixtureRoot,
            fixtureRoot.appending(
                path: ".npm",
                directoryHint: .isDirectory
            ),
            originalURL,
        ] {
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: url.path
            )
        }
        try Data("stornaut-phase-c-root:\(nonce)".utf8).write(
            to: diagnosticRoot.appending(
                path: ".stornaut-phase-c-trash-fixture-\(nonce)"
            ),
            options: .withoutOverwriting
        )
        try Data(marker.utf8).write(
            to: originalURL.appending(path: itemMarkerName),
            options: .withoutOverwriting
        )
        try Data("disposable".utf8).write(
            to: originalURL.appending(
                path: "content-v2/sha512/disposable"
            ),
            options: .withoutOverwriting
        )
        return try #require(FileIdentity.read(at: originalURL))
    }

    func remove() {
        try? FileManager.default.removeItem(at: diagnosticRoot)
    }
}

private struct PhaseCTrashRecoveryTestFixture {
    let now = Date(timeIntervalSince1970: 1_787_000_000)
    let diagnosticNonce =
        "11111111-2222-4333-8444-555555555555"
    let recoveryNonce =
        "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"
    let recoveryOptInNonce =
        "99999999-8888-4777-8666-555555555555"
    let originalExecutableSHA256 = String(repeating: "a", count: 64)
    let recoveryExecutableSHA256 = String(repeating: "b", count: 64)
    let journalID = "run-11111111-2222-4333-8444-555555555555"
    let manifestID =
        "manifest-aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"
    let diagnosticRoot: URL
    let recoveryConfigURL: URL
    let retainedConfigURL: URL
    let retainedReportURL: URL
    let databaseURL: URL
    let recoveryReportURL: URL
    let returnedTrashURL: URL
    let originalIdentity: FileIdentity
    let destinationParentIdentity: FileIdentity
    let retainedConfigSHA256: String
    let retainedReportSHA256: String
    let databaseSHA256: String

    init() throws {
        diagnosticRoot = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-phase-c-trash.\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        recoveryConfigURL = diagnosticRoot.appending(
            path: "recovery-config-\(recoveryNonce).json"
        )
        retainedConfigURL = diagnosticRoot.appending(path: "config.json")
        retainedReportURL = diagnosticRoot.appending(path: "report.json")
        databaseURL = diagnosticRoot.appending(
            path: "support/com.eriklee.stornaut/Evidence.sqlite"
        )
        recoveryReportURL = diagnosticRoot.appending(
            path: "recovery-report-\(recoveryNonce).json"
        )
        returnedTrashURL = FileManager.default
            .homeDirectoryForCurrentUser.appending(
            path: ".Trash/_cacache",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.createDirectory(
            at: diagnosticRoot.appending(
                path: "caches/com.eriklee.stornaut",
                directoryHint: .isDirectory
            ),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.createDirectory(
            at: diagnosticRoot.appending(
                path: "fixture/.npm",
                directoryHint: .isDirectory
            ),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let identitySourceURL = diagnosticRoot.appending(
            path: "simulated-trash-identity",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: identitySourceURL,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        originalIdentity = try #require(
            FileIdentity.read(at: identitySourceURL)
        )
        destinationParentIdentity = try #require(
            FileIdentity.read(
                at: diagnosticRoot.appending(
                    path: "fixture/.npm",
                    directoryHint: .isDirectory
                )
            )
        )
        let retainedConfig = Data("retained-config".utf8)
        let retainedReport = Data("retained-report".utf8)
        let database = Data("sqlite-placeholder".utf8)
        try retainedConfig.write(to: retainedConfigURL)
        try retainedReport.write(to: retainedReportURL)
        try database.write(to: databaseURL)
        try Data(
            "stornaut-phase-c-root:\(diagnosticNonce)".utf8
        ).write(
            to: diagnosticRoot.appending(
                path:
                    ".stornaut-phase-c-trash-fixture-\(diagnosticNonce)"
            )
        )
        retainedConfigSHA256 =
            PhaseCTrashRecoveryConfiguration.sha256(retainedConfig)
        retainedReportSHA256 =
            PhaseCTrashRecoveryConfiguration.sha256(retainedReport)
        databaseSHA256 =
            PhaseCTrashRecoveryConfiguration.sha256(database)
        try Data("{}".utf8).write(to: recoveryConfigURL)
        for path in [
            retainedConfigURL.path,
            retainedReportURL.path,
            databaseURL.path,
            recoveryConfigURL.path,
        ] {
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: path
            )
        }
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: diagnosticRoot.path
        )
    }

    func configurationObject() -> [String: Any] {
        [
            "schemaVersion": 1,
            "recoveryNonce": recoveryNonce,
            "recoveryOptInStatement":
                "I authorize Stornaut Task 35 to recover the retained journal and restore only its exact disposable fixture without another Trash attempt.",
            "recoveryOptInNonce": recoveryOptInNonce,
            "diagnosticNonce": diagnosticNonce,
            "diagnosticRoot": diagnosticRoot.path,
            "retainedConfigPath": retainedConfigURL.path,
            "retainedReportPath": retainedReportURL.path,
            "applicationSupportBase": diagnosticRoot
                .appending(path: "support").path,
            "cachesBase": diagnosticRoot.appending(path: "caches").path,
            "evidenceDatabasePath": databaseURL.path,
            "recoveryReportPath": recoveryReportURL.path,
            "expectedBundleIdentifier": "com.eriklee.stornaut",
            "expectedRecoveryExecutableSHA256":
                recoveryExecutableSHA256,
            "expectedOriginalExecutableSHA256":
                originalExecutableSHA256,
            "expectedRetainedConfigSHA256":
                retainedConfigSHA256,
            "expectedRetainedReportSHA256":
                retainedReportSHA256,
            "expectedDatabaseSHA256": databaseSHA256,
            "expectedRelativePath": ".npm/_cacache",
            "expectedJournalID": journalID,
            "expectedManifestID": manifestID,
            "expectedOriginalIdentity":
                identityObject(originalIdentity),
            "expectedDestinationParentIdentity":
                identityObject(destinationParentIdentity),
            "expectedReturnedTrashPath": returnedTrashURL.path,
            "issuedAt": now.timeIntervalSince1970,
            "expiresAt":
                now.addingTimeInterval(300).timeIntervalSince1970,
        ]
    }

    func remove() {
        try? FileManager.default.removeItem(at: diagnosticRoot)
    }

    private func identityObject(
        _ identity: FileIdentity
    ) -> [String: Any] {
        [
            "device": identity.device,
            "inode": identity.inode,
            "mode": identity.mode,
            "ownerUserID": identity.ownerUserID,
            "ownerGroupID": identity.ownerGroupID,
            "linkCount": identity.linkCount,
            "size": identity.size,
            "allocatedBytes": identity.allocatedBytes,
            "modificationSeconds": identity.modificationSeconds,
            "modificationNanoseconds":
                identity.modificationNanoseconds,
        ]
    }
}
