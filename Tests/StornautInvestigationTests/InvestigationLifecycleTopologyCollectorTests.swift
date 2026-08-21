import Darwin
import Foundation
import Testing
@testable import StornautInvestigationMachine
import StornautInvestigation
import StornautInvestigationRuntime
import StornautLifecycle

@Suite("Investigation lifecycle topology collector")
struct InvestigationLifecycleTopologyCollectorTests {
    @Test
    func collectorRemainsBindlessAndRetirementValidationStaysFocused()
        throws
    {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appending(
                path: "Sources/StornautInvestigationMachine/"
                    + "InvestigationLifecycleTopologyCollector.swift"
            ),
            encoding: .utf8
        )
        let retirementValidationStart = try #require(source.range(
            of: "    private func validateRetirementClaim("
        ))
        let retirementValidationSuffix =
            source[retirementValidationStart.lowerBound...]
        let retirementValidationEnd = try #require(
            retirementValidationSuffix.range(
                of: "\n    private func requireWindow("
            )
        )
        let retirementValidationSource = String(
            retirementValidationSuffix[
                ..<retirementValidationEnd.lowerBound
            ]
        )
        let compactRetirementValidation =
            retirementValidationSource.replacingOccurrences(
                of: #"\s+"#,
                with: "",
                options: .regularExpression
            )

        for required in [
            "protocol InvestigationLifecyclePostTeardownObserving",
            "func observePostTeardown(",
            "appProcessIdentity: LifecycleProcessIdentity",
            "helperProcessIdentity: LifecycleProcessIdentity",
            "window: LifecycleRootTopologyObservationWindow",
            "post = try await postTeardownObserver.observePostTeardown(",
            "appProcessIdentity: request.appProcessIdentity",
            "helperProcessIdentity:",
            "retirementClaim.helperPeerIdentity",
        ] {
            #expect(source.contains(required))
        }
        for comparison in [
            "claim.request.handle.investigationID==request.investigationID",
            "claim.configurationSHA256==request.configurationSHA256",
            "claim.ownerRetirementObservation==.retiredOwnedResources",
            "residue.investigationID==request.investigationID",
            "residue.userID==request.userID",
            "residue.provedEmpty",
            "claim.helperPeerIdentity.processID>1",
            "claim.helperPeerIdentity.processIDVersion>0",
            "claim.helperPeerIdentity.effectiveUserID==0",
            "claim.helperIdentity.processID==claim.helperPeerIdentity.processID",
            "claim.helperIdentity.processIDVersion==claim.helperPeerIdentity.processIDVersion",
            "claim.helperIdentity.auditSessionID==claim.helperPeerIdentity.auditSessionID",
            "claim.helperIdentity.effectiveUserID==claim.helperPeerIdentity.effectiveUserID",
            "claim.helperIdentity.auditTokenWords==claim.helperPeerIdentity.auditToken.words",
            "claim.helperPeerIdentity.auditSessionID==residue.auditSessionID",
            "claim.helperPeerIdentity.processID!=request.appProcessIdentity.processID",
            "claim.appIdentity.processID==request.appProcessIdentity.processID",
            "claim.appIdentity.processIDVersion==request.appProcessIdentity.processIDVersion",
            "claim.appIdentity.auditSessionID==request.appProcessIdentity.auditSessionID",
            "claim.appIdentity.effectiveUserID==request.userID",
            "claim.appIdentity.auditTokenWords==request.appProcessIdentity.auditToken.words",
            "claim.claimedAt<=request.openedAt",
            "claim.request.validBefore>=request.openedAt",
            "claim.request.validBefore>=claim.claimedAt",
            "residue.observedAt<=claim.recordedAt",
            "claim.recordedAt<=claim.request.issuedAt",
            "claim.request.issuedAt<=claim.claimedAt",
            "residue.observedAt<=request.validBefore",
        ] {
            #expect(compactRetirementValidation.contains(comparison))
        }

        let closedSlices = source + "\n" + retirementValidationSource
        for forbidden in [
            "bindingMismatch",
            "InvestigationLifecyclePostTeardownBindingReading",
            "PostTeardownExpectedTopologyBindingReader",
            "expectedBindingReader",
            "topologyBinding",
            "LifecycleBundleSigningIdentityReader",
            "Codable",
            "JSONEncoder",
            "JSONDecoder",
            "machineDriverProcessIdentity",
            "machineDriverProcessID",
            "machineDriverPID",
            "driverProcessIdentity",
            "driverProcessID",
            "driverPID",
            "StornautExecution",
            "ActionExecutor",
            "TrashMoving",
            "RegisteredAction",
            "MoveToTrash",
            "FileManagerTrashAdapter",
            "posix_spawn",
            "Process(",
        ] {
            #expect(!closedSlices.contains(forbidden))
        }
    }

    @Test
    func collectsOneOrderedOpaquePostTeardownCohort() async throws {
        let fixture = try LifecycleTopologyCollectorFixture()
        let retirementStore = try await fixture.retirementClaimStore()
        let topology = ScriptedPostTeardownObserver(results: [
            .success(try fixture.postTeardownObservation()),
        ])
        let transition = RecordingTopologyTransition()
        let collector = InvestigationLifecycleTopologyCollector(
            postTeardownObserver: topology,
            effectiveUserID: { 0 },
            now: fixture.clock.read
        )

        let request = try fixture.collectionRequest()
        let cohort = try await collector.collect(
            request: request,
            retirementClaimStore: retirementStore,
            transition: transition
        )

        #expect(cohort.investigationID == fixture.investigationID)
        #expect(cohort.helperProcessIdentity == fixture.helperIdentity)
        #expect(cohort.appProcessIdentity == fixture.appIdentity)
        #expect(cohort.lifecycleResidueObservation.provedEmpty)
        #expect(
            cohort.ownerRetirementObservation
                == .retiredOwnedResources
        )
        #expect(
            cohort.postTeardownTopology.provesPostTeardownTopology
        )
        #expect(await transition.invocationCount == 1)
        #expect(await topology.invocationCount == 1)
        #expect(await topology.calls == [PostTeardownObservationCall(
            appProcessIdentity: fixture.appIdentity,
            helperProcessIdentity: fixture.helperIdentity,
            window: try LifecycleRootTopologyObservationWindow(
                openedAt: request.openedAt,
                validBefore: request.validBefore
            )
        )])
        #expect(
            !((InvestigationLifecycleTopologyCohort.self as Any.Type)
                is any Codable.Type)
        )
    }

    @Test
    func nonRootAndForeignRetirementFailBeforeTopologyOrTransition()
        async throws
    {
        let fixture = try LifecycleTopologyCollectorFixture()
        let topology = ScriptedPostTeardownObserver(results: [])
        let transition = RecordingTopologyTransition()
        let nonRoot = InvestigationLifecycleTopologyCollector(
            postTeardownObserver: topology,
            effectiveUserID: { 501 },
            now: fixture.clock.read
        )

        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .rootAuthorityRequired
        ) {
            _ = try await nonRoot.collect(
                request: fixture.collectionRequest(),
                retirementClaimStore:
                    try await fixture.retirementClaimStore(),
                transition: transition
            )
        }
        #expect(await topology.invocationCount == 0)
        #expect(await transition.invocationCount == 0)

        let foreign = InvestigationLifecycleTopologyCollector(
            postTeardownObserver: topology,
            effectiveUserID: { 0 },
            now: fixture.clock.read
        )
        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .retirementEvidenceMismatch
        ) {
            _ = try await foreign.collect(
                request: fixture.collectionRequest(
                    configuration: try fixture.configuration(
                        nonce: UUID()
                    )
                ),
                retirementClaimStore:
                    try await fixture.retirementClaimStore(),
                transition: transition
            )
        }
        #expect(await topology.invocationCount == 0)
        #expect(await transition.invocationCount == 0)
    }

    @Test
    func mismatchedRecordedAndPeerHelperIdentityFailsBeforeTransition()
        async throws
    {
        let fixture = try LifecycleTopologyCollectorFixture()
        let topology = ScriptedPostTeardownObserver(results: [])
        let transition = RecordingTopologyTransition()
        let collector = InvestigationLifecycleTopologyCollector(
            postTeardownObserver: topology,
            effectiveUserID: { 0 },
            now: fixture.clock.read
        )
        let mismatchedPeer = fixture.processIdentity(
            processID: fixture.helperIdentity.processID,
            processIDVersion:
                fixture.helperIdentity.processIDVersion + 1,
            auditSessionID: fixture.helperIdentity.auditSessionID,
            effectiveUserID: fixture.helperIdentity.effectiveUserID
        )

        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .retirementEvidenceMismatch
        ) {
            _ = try await collector.collect(
                request: fixture.collectionRequest(),
                retirementClaimStore: try await fixture
                    .retirementClaimStore(
                        helperPeerIdentityOverride: mismatchedPeer
                    ),
                transition: transition
            )
        }
        #expect(await transition.invocationCount == 0)
        #expect(await topology.invocationCount == 0)
    }

    @Test
    func transitionFailureAndDeadlineAreTerminal() async throws {
        let fixture = try LifecycleTopologyCollectorFixture()
        let transition = RecordingTopologyTransition(
            error: InvestigationLifecycleTopologyCollectorError
                .transitionFailed
        )
        let topology = ScriptedPostTeardownObserver(results: [])
        let collector = InvestigationLifecycleTopologyCollector(
            postTeardownObserver: topology,
            effectiveUserID: { 0 },
            now: fixture.clock.read
        )

        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .transitionFailed
        ) {
            _ = try await collector.collect(
                request: fixture.collectionRequest(),
                retirementClaimStore:
                    try await fixture.retirementClaimStore(),
                transition: transition
            )
        }
        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .collectorConsumed
        ) {
            _ = try await collector.collect(
                request: fixture.collectionRequest(),
                retirementClaimStore:
                    try await fixture.retirementClaimStore(),
                transition: RecordingTopologyTransition()
            )
        }
    }

    @Test
    func expiredWindowFailsClosedBeforeTransition()
        async throws
    {
        let fixture = try LifecycleTopologyCollectorFixture()
        let topology = ScriptedPostTeardownObserver(results: [])
        let transition = RecordingTopologyTransition()
        let deadlineCollector = InvestigationLifecycleTopologyCollector(
            postTeardownObserver: topology,
            effectiveUserID: { 0 },
            now: fixture.clock.read
        )
        let request = try fixture.collectionRequest()
        fixture.clock.advance(31)
        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .observationOutsideWindow
        ) {
            _ = try await deadlineCollector.collect(
                request: request,
                retirementClaimStore:
                    try await fixture.retirementClaimStore(),
                transition: transition
            )
        }
        #expect(await topology.invocationCount == 0)
        #expect(await transition.invocationCount == 0)
    }

    @Test
    func foreignSignedConfigurationFailsBeforeTopologyOrTransition()
        async throws
    {
        let fixture = try LifecycleTopologyCollectorFixture()
        let foreignBinding = SignedInvestigationRuntimeBinding(
            repositoryHEAD: fixture.signedBinding.repositoryHEAD,
            sourceFingerprintSHA256: String(repeating: "e", count: 64),
            appExecutableSHA256:
                fixture.signedBinding.appExecutableSHA256,
            helperExecutableSHA256:
                fixture.signedBinding.helperExecutableSHA256,
            runtimeReceiptSHA256:
                fixture.signedBinding.runtimeReceiptSHA256,
            promptSHA256: fixture.signedBinding.promptSHA256,
            envelopeSchemaSHA256:
                fixture.signedBinding.envelopeSchemaSHA256,
            facadeSHA256: fixture.signedBinding.facadeSHA256,
            codexExecutableSHA256:
                fixture.signedBinding.codexExecutableSHA256,
            appBundleIdentifier:
                fixture.signedBinding.appBundleIdentifier,
            helperServiceIdentifier:
                fixture.signedBinding.helperServiceIdentifier,
            machineDriver: fixture.signedBinding.machineDriver
        )
        let topology = ScriptedPostTeardownObserver(results: [
            .success(try fixture.postTeardownObservation()),
        ])
        let transition = RecordingTopologyTransition()
        let collector = InvestigationLifecycleTopologyCollector(
            postTeardownObserver: topology,
            effectiveUserID: { 0 },
            now: fixture.clock.read
        )
        let request = try fixture.collectionRequest(
            configuration: fixture.configuration(
                binding: foreignBinding
            )
        )

        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .retirementEvidenceMismatch
        ) {
            _ = try await collector.collect(
                request: request,
                retirementClaimStore:
                    try await fixture.retirementClaimStore(),
                transition: transition
            )
        }
        #expect(await topology.invocationCount == 0)
        #expect(await transition.invocationCount == 0)
    }

    @Test
    func rootAndDeadlineAreRevalidatedImmediatelyBeforeTransition()
        async throws
    {
        let fixture = try LifecycleTopologyCollectorFixture()
        let rootTransition = RecordingTopologyTransition()
        let rootReads = ScriptedEffectiveUserID(values: [0, 501])
        let rootTopology = ScriptedPostTeardownObserver(results: [])
        let rootCollector = InvestigationLifecycleTopologyCollector(
            postTeardownObserver: rootTopology,
            effectiveUserID: rootReads.read,
            now: fixture.clock.read
        )
        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .rootAuthorityRequired
        ) {
            _ = try await rootCollector.collect(
                request: fixture.collectionRequest(),
                retirementClaimStore:
                    try await fixture.retirementClaimStore(),
                transition: rootTransition
            )
        }
        #expect(await rootTransition.invocationCount == 0)

        let deadlineTransition = RecordingTopologyTransition()
        let deadlineTopology = ScriptedPostTeardownObserver(results: [])
        let deadlineClock = ScriptedTopologyClock(values: [
            fixture.clock.read(),
            fixture.clock.read().addingTimeInterval(31),
        ])
        let deadlineCollector = InvestigationLifecycleTopologyCollector(
            postTeardownObserver: deadlineTopology,
            effectiveUserID: { 0 },
            now: deadlineClock.read
        )
        let deadlineRequest = try fixture.collectionRequest()
        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .observationOutsideWindow
        ) {
            _ = try await deadlineCollector.collect(
                request: deadlineRequest,
                retirementClaimStore:
                    try await fixture.retirementClaimStore(),
                transition: deadlineTransition
            )
        }
        #expect(await deadlineTransition.invocationCount == 0)
    }

    @Test
    func rootAndDeadlineAreRevalidatedAfterTransitionBeforeObservation()
        async throws
    {
        let fixture = try LifecycleTopologyCollectorFixture()
        let rootTopology = ScriptedPostTeardownObserver(results: [])
        let rootTransition = RecordingTopologyTransition()
        let rootCollector = InvestigationLifecycleTopologyCollector(
            postTeardownObserver: rootTopology,
            effectiveUserID: ScriptedEffectiveUserID(
                values: [0, 0, 501]
            ).read,
            now: fixture.clock.read
        )

        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .rootAuthorityRequired
        ) {
            _ = try await rootCollector.collect(
                request: fixture.collectionRequest(),
                retirementClaimStore:
                    try await fixture.retirementClaimStore(),
                transition: rootTransition
            )
        }
        #expect(await rootTransition.invocationCount == 1)
        #expect(await rootTopology.invocationCount == 0)

        let deadlineTopology = ScriptedPostTeardownObserver(results: [])
        let deadlineTransition = RecordingTopologyTransition()
        let deadlineClock = ScriptedTopologyClock(values: [
            fixture.clock.read(),
            fixture.clock.read(),
            fixture.clock.read().addingTimeInterval(31),
        ])
        let deadlineCollector = InvestigationLifecycleTopologyCollector(
            postTeardownObserver: deadlineTopology,
            effectiveUserID: { 0 },
            now: deadlineClock.read
        )

        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .observationOutsideWindow
        ) {
            _ = try await deadlineCollector.collect(
                request: fixture.collectionRequest(),
                retirementClaimStore:
                    try await fixture.retirementClaimStore(),
                transition: deadlineTransition
            )
        }
        #expect(await deadlineTransition.invocationCount == 1)
        #expect(await deadlineTopology.invocationCount == 0)
    }

    @Test
    func postTeardownFailureIsTerminalAndNeverReturnsZeroResidue()
        async throws
    {
        let fixture = try LifecycleTopologyCollectorFixture()
        let topology = ScriptedPostTeardownObserver(results: [
            .success(try fixture.nonAbsentPostTeardownObservation()),
        ])
        let transition = RecordingTopologyTransition()
        let collector = InvestigationLifecycleTopologyCollector(
            postTeardownObserver: topology,
            effectiveUserID: { 0 },
            now: fixture.clock.read
        )

        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .postTeardownTopologyUnproved
        ) {
            _ = try await collector.collect(
                request: fixture.collectionRequest(),
                retirementClaimStore:
                    try await fixture.retirementClaimStore(),
                transition: transition
            )
        }
        #expect(await transition.invocationCount == 1)
        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .collectorConsumed
        ) {
            _ = try await collector.collect(
                request: fixture.collectionRequest(),
                retirementClaimStore:
                    try await fixture.retirementClaimStore(),
                transition: transition
            )
        }
    }

    @Test
    func observationStartedBeforeTransitionNeverProducesResidue() async throws {
        let fixture = try LifecycleTopologyCollectorFixture()
        let stalePostTeardown = try fixture.postTeardownObservation()
        let brokenTopology = ScriptedPostTeardownObserver(results: [
            .success(stalePostTeardown),
        ])
        let transition = AdvancingTopologyTransition(clock: fixture.clock)
        let collector = InvestigationLifecycleTopologyCollector(
            postTeardownObserver: brokenTopology,
            effectiveUserID: { 0 },
            now: fixture.clock.read
        )

        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .postTeardownTopologyUnproved
        ) {
            _ = try await collector.collect(
                request: fixture.collectionRequest(),
                retirementClaimStore:
                    try await fixture.retirementClaimStore(),
                transition: transition
            )
        }
    }

    @Test
    func concurrentCollectionHasExactlyOneAdmission() async throws {
        let fixture = try LifecycleTopologyCollectorFixture()
        let transition = SuspendedTopologyTransition()
        let topology = ScriptedPostTeardownObserver(results: [
            .success(try fixture.postTeardownObservation()),
        ])
        let collector = InvestigationLifecycleTopologyCollector(
            postTeardownObserver: topology,
            effectiveUserID: { 0 },
            now: fixture.clock.read
        )
        let retirementStore = try await fixture.retirementClaimStore()

        let first = Task {
            try await collector.collect(
                request: fixture.collectionRequest(),
                retirementClaimStore: retirementStore,
                transition: transition
            )
        }
        await transition.waitUntilInvoked()
        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .collectorConsumed
        ) {
            _ = try await collector.collect(
                request: fixture.collectionRequest(),
                retirementClaimStore: retirementStore,
                transition: RecordingTopologyTransition()
            )
        }
        await transition.resume()
        _ = try await first.value

        let replayCollector = InvestigationLifecycleTopologyCollector(
            postTeardownObserver: ScriptedPostTeardownObserver(results: []),
            effectiveUserID: { 0 },
            now: fixture.clock.read
        )
        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .retirementEvidenceMismatch
        ) {
            _ = try await replayCollector.collect(
                request: fixture.collectionRequest(),
                retirementClaimStore: retirementStore,
                transition: RecordingTopologyTransition()
            )
        }
    }

    @Test
    func cancellationAfterTransitionStartsConsumesTheCollector()
        async throws
    {
        let fixture = try LifecycleTopologyCollectorFixture()
        let transition = SuspendedTopologyTransition()
        let collector = InvestigationLifecycleTopologyCollector(
            postTeardownObserver: ScriptedPostTeardownObserver(results: [
                .success(try fixture.postTeardownObservation()),
            ]),
            effectiveUserID: { 0 },
            now: fixture.clock.read
        )
        let store = try await fixture.retirementClaimStore()
        let task = Task {
            try await collector.collect(
                request: fixture.collectionRequest(),
                retirementClaimStore: store,
                transition: transition
            )
        }
        await transition.waitUntilInvoked()
        task.cancel()
        await transition.resume()
        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .collectorConsumed
        ) {
            _ = try await collector.collect(
                request: fixture.collectionRequest(),
                retirementClaimStore:
                    try await fixture.retirementClaimStore(),
                transition: RecordingTopologyTransition()
            )
        }
    }
}

private struct PostTeardownObservationCall: Sendable, Equatable {
    let appProcessIdentity: LifecycleProcessIdentity
    let helperProcessIdentity: LifecycleProcessIdentity
    let window: LifecycleRootTopologyObservationWindow
}

private actor ScriptedPostTeardownObserver:
    InvestigationLifecyclePostTeardownObserving
{
    private var results: [
        Result<
            LifecycleRootTopologyObservation,
            LifecycleRootTopologyObservationError
        >
    ]
    private(set) var invocationCount = 0
    private(set) var calls: [PostTeardownObservationCall] = []

    init(
        results: [
            Result<
                LifecycleRootTopologyObservation,
                LifecycleRootTopologyObservationError
            >
        ]
    ) {
        self.results = results
    }

    func observePostTeardown(
        appProcessIdentity: LifecycleProcessIdentity,
        helperProcessIdentity: LifecycleProcessIdentity,
        window: LifecycleRootTopologyObservationWindow
    ) async throws -> LifecycleRootTopologyObservation {
        invocationCount += 1
        calls.append(PostTeardownObservationCall(
            appProcessIdentity: appProcessIdentity,
            helperProcessIdentity: helperProcessIdentity,
            window: window
        ))
        guard !results.isEmpty else {
            throw LifecycleRootTopologyObservationError.invalidRequest
        }
        return try results.removeFirst().get()
    }
}

private final class ScriptedEffectiveUserID: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [uid_t]

    init(values: [uid_t]) {
        self.values = values
    }

    func read() -> uid_t {
        lock.withLock {
            guard values.count > 1 else { return values[0] }
            return values.removeFirst()
        }
    }
}

private final class ScriptedTopologyClock: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Date]

    init(values: [Date]) {
        self.values = values
    }

    func read() -> Date {
        lock.withLock {
            guard values.count > 1 else { return values[0] }
            return values.removeFirst()
        }
    }
}

private actor RecordingTopologyTransition:
    InvestigationLifecycleTopologyTransitioning
{
    private(set) var invocationCount = 0
    private let error: (any Error)?

    init(error: (any Error)? = nil) {
        self.error = error
    }

    func transition() async throws {
        invocationCount += 1
        if let error {
            throw error
        }
    }
}

private struct AdvancingTopologyTransition:
    InvestigationLifecycleTopologyTransitioning
{
    let clock: TopologyCollectorClock

    func transition() async {
        clock.advance(1)
    }
}

private actor SuspendedTopologyTransition:
    InvestigationLifecycleTopologyTransitioning
{
    private var invoked: CheckedContinuation<Void, Never>?
    private var waiter: CheckedContinuation<Void, Never>?

    func transition() async {
        waiter?.resume()
        waiter = nil
        await withCheckedContinuation { invoked = $0 }
    }

    func waitUntilInvoked() async {
        if invoked != nil { return }
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.waitForInvocation()
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(2))
            }
            _ = await group.next()
            group.cancelAll()
        }
    }

    private func waitForInvocation() async {
        if invoked != nil { return }
        await withCheckedContinuation {
            waiter = $0
        }
    }

    func resume() {
        invoked?.resume()
        invoked = nil
    }
}
