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
    func collectsOneOrderedOpaqueL1L2Cohort() async throws {
        let fixture = try LifecycleTopologyCollectorFixture()
        let retirementStore = try await fixture.retirementEvidenceStore()
        let topology = ScriptedTopologyObserver(
            results: [
                .success(try fixture.installedObservation()),
                .success(try fixture.postTeardownObservation()),
            ]
        )
        let transition = RecordingTopologyTransition()
        let collector = InvestigationLifecycleTopologyCollector(
            topologyObserver: topology,
            bindingReader: FixedTopologyBindingReader(
                binding: fixture.binding
            ),
            effectiveUserID: { 0 },
            now: fixture.clock.read
        )

        let cohort = try await collector.collect(
            request: fixture.collectionRequest(),
            retirementEvidenceStore: retirementStore,
            transition: transition
        )

        #expect(cohort.investigationID == fixture.investigationID)
        #expect(cohort.helperProcessIdentity == fixture.helperIdentity)
        #expect(cohort.appProcessIdentity == fixture.appIdentity)
        #expect(cohort.lifecycleResidueObservation.provedEmpty)
        #expect(cohort.installedTopology.provesInstalledTopology)
        #expect(
            cohort.postTeardownTopology.provesPostTeardownTopology
        )
        #expect(await transition.invocationCount == 1)
        #expect(await topology.phases == [.installed, .postTeardown])
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
        let topology = ScriptedTopologyObserver(results: [])
        let transition = RecordingTopologyTransition()
        let nonRoot = InvestigationLifecycleTopologyCollector(
            topologyObserver: topology,
            bindingReader: FixedTopologyBindingReader(
                binding: fixture.binding
            ),
            effectiveUserID: { 501 },
            now: fixture.clock.read
        )

        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .rootAuthorityRequired
        ) {
            _ = try await nonRoot.collect(
                request: fixture.collectionRequest(),
                retirementEvidenceStore:
                    try await fixture.retirementEvidenceStore(),
                transition: transition
            )
        }
        #expect(await topology.phases.isEmpty)
        #expect(await transition.invocationCount == 0)

        let foreign = InvestigationLifecycleTopologyCollector(
            topologyObserver: topology,
            bindingReader: FixedTopologyBindingReader(
                binding: fixture.binding
            ),
            effectiveUserID: { 0 },
            now: fixture.clock.read
        )
        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .retirementEvidenceMismatch
        ) {
            _ = try await foreign.collect(
                request: fixture.collectionRequest(
                    investigationID: LifecycleInvestigationID()
                ),
                retirementEvidenceStore:
                    try await fixture.retirementEvidenceStore(),
                transition: transition
            )
        }
        #expect(await topology.phases.isEmpty)
        #expect(await transition.invocationCount == 0)
    }

    @Test
    func invalidPhaseTransitionFailureAndDeadlineAreTerminal() async throws {
        let fixture = try LifecycleTopologyCollectorFixture()
        let transition = RecordingTopologyTransition(
            error: InvestigationLifecycleTopologyCollectorError
                .transitionFailed
        )
        let topology = ScriptedTopologyObserver(results: [
            .success(try fixture.installedObservation()),
        ])
        let collector = InvestigationLifecycleTopologyCollector(
            topologyObserver: topology,
            bindingReader: FixedTopologyBindingReader(
                binding: fixture.binding
            ),
            effectiveUserID: { 0 },
            now: fixture.clock.read
        )

        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .transitionFailed
        ) {
            _ = try await collector.collect(
                request: fixture.collectionRequest(),
                retirementEvidenceStore:
                    try await fixture.retirementEvidenceStore(),
                transition: transition
            )
        }
        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .collectorConsumed
        ) {
            _ = try await collector.collect(
                request: fixture.collectionRequest(),
                retirementEvidenceStore:
                    try await fixture.retirementEvidenceStore(),
                transition: RecordingTopologyTransition()
            )
        }
    }

    @Test
    func bindingDriftAndExpiredWindowFailClosedBeforeTransition()
        async throws
    {
        let fixture = try LifecycleTopologyCollectorFixture()
        let mismatched = try LifecycleRootTopologyBinding(
            appSigningEvidence: try LifecycleBundleSigningEvidence(
                identity: fixture.binding.appSigningEvidence.identity,
                executableSHA256: String(repeating: "e", count: 64),
                isAdHoc: true
            ),
            helperSigningEvidence:
                fixture.binding.helperSigningEvidence,
            appBundleIdentifier: fixture.binding.appBundleIdentifier,
            helperServiceIdentifier:
                fixture.binding.helperServiceIdentifier
        )
        let topology = ScriptedTopologyObserver(results: [])
        let transition = RecordingTopologyTransition()
        let bindingCollector = InvestigationLifecycleTopologyCollector(
            topologyObserver: topology,
            bindingReader: FixedTopologyBindingReader(binding: mismatched),
            effectiveUserID: { 0 },
            now: fixture.clock.read
        )
        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .retirementEvidenceMismatch
        ) {
            _ = try await bindingCollector.collect(
                request: fixture.collectionRequest(),
                retirementEvidenceStore:
                    try await fixture.retirementEvidenceStore(),
                transition: transition
            )
        }
        #expect(await topology.phases.isEmpty)
        #expect(await transition.invocationCount == 0)

        let deadlineCollector = InvestigationLifecycleTopologyCollector(
            topologyObserver: topology,
            bindingReader: FixedTopologyBindingReader(
                binding: fixture.binding
            ),
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
                retirementEvidenceStore:
                    try await fixture.retirementEvidenceStore(),
                transition: transition
            )
        }
        #expect(await topology.phases.isEmpty)
        #expect(await transition.invocationCount == 0)
    }

    @Test
    func rootAndDeadlineAreRevalidatedImmediatelyBeforeTransition()
        async throws
    {
        let fixture = try LifecycleTopologyCollectorFixture()
        let root = MutableEffectiveUserID(value: 0)
        let rootTransition = RecordingTopologyTransition()
        let rootTopology = ScriptedTopologyObserver(
            results: [.success(try fixture.installedObservation())],
            afterObservation: { root.set(501) }
        )
        let rootCollector = InvestigationLifecycleTopologyCollector(
            topologyObserver: rootTopology,
            bindingReader: FixedTopologyBindingReader(
                binding: fixture.binding
            ),
            effectiveUserID: root.read,
            now: fixture.clock.read
        )
        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .rootAuthorityRequired
        ) {
            _ = try await rootCollector.collect(
                request: fixture.collectionRequest(),
                retirementEvidenceStore:
                    try await fixture.retirementEvidenceStore(),
                transition: rootTransition
            )
        }
        #expect(await rootTransition.invocationCount == 0)

        let deadlineTransition = RecordingTopologyTransition()
        let deadlineTopology = ScriptedTopologyObserver(
            results: [.success(try fixture.installedObservation())],
            afterObservation: { fixture.clock.advance(31) }
        )
        let deadlineCollector = InvestigationLifecycleTopologyCollector(
            topologyObserver: deadlineTopology,
            bindingReader: FixedTopologyBindingReader(
                binding: fixture.binding
            ),
            effectiveUserID: { 0 },
            now: fixture.clock.read
        )
        let deadlineRequest = try fixture.collectionRequest()
        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .observationOutsideWindow
        ) {
            _ = try await deadlineCollector.collect(
                request: deadlineRequest,
                retirementEvidenceStore:
                    try await fixture.retirementEvidenceStore(),
                transition: deadlineTransition
            )
        }
        #expect(await deadlineTransition.invocationCount == 0)
    }

    @Test
    func postTeardownFailureIsTerminalAndNeverReturnsZeroResidue()
        async throws
    {
        let fixture = try LifecycleTopologyCollectorFixture()
        let topology = ScriptedTopologyObserver(results: [
            .success(try fixture.installedObservation()),
            .success(try fixture.installedObservation()),
        ])
        let transition = RecordingTopologyTransition()
        let collector = InvestigationLifecycleTopologyCollector(
            topologyObserver: topology,
            bindingReader: FixedTopologyBindingReader(
                binding: fixture.binding
            ),
            effectiveUserID: { 0 },
            now: fixture.clock.read
        )

        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .postTeardownTopologyUnproved
        ) {
            _ = try await collector.collect(
                request: fixture.collectionRequest(),
                retirementEvidenceStore:
                    try await fixture.retirementEvidenceStore(),
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
                retirementEvidenceStore:
                    try await fixture.retirementEvidenceStore(),
                transition: transition
            )
        }
    }

    @Test
    func nonzeroRetirementAndBrokenTopologyNeverProduceResidue() async throws {
        let fixture = try LifecycleTopologyCollectorFixture()
        let brokenTopology = ScriptedTopologyObserver(results: [
            .success(try fixture.postTeardownObservation()),
        ])
        let collector = InvestigationLifecycleTopologyCollector(
            topologyObserver: brokenTopology,
            bindingReader: FixedTopologyBindingReader(
                binding: fixture.binding
            ),
            effectiveUserID: { 0 },
            now: fixture.clock.read
        )

        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .installedTopologyUnproved
        ) {
            _ = try await collector.collect(
                request: fixture.collectionRequest(),
                retirementEvidenceStore:
                    try await fixture.retirementEvidenceStore(),
                transition: RecordingTopologyTransition()
            )
        }
    }

    @Test
    func concurrentCollectionHasExactlyOneAdmission() async throws {
        let fixture = try LifecycleTopologyCollectorFixture()
        let transition = SuspendedTopologyTransition()
        let topology = ScriptedTopologyObserver(results: [
            .success(try fixture.installedObservation()),
            .success(try fixture.postTeardownObservation()),
        ])
        let collector = InvestigationLifecycleTopologyCollector(
            topologyObserver: topology,
            bindingReader: FixedTopologyBindingReader(
                binding: fixture.binding
            ),
            effectiveUserID: { 0 },
            now: fixture.clock.read
        )
        let retirementStore = try await fixture.retirementEvidenceStore()

        let first = Task {
            try await collector.collect(
                request: fixture.collectionRequest(),
                retirementEvidenceStore: retirementStore,
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
                retirementEvidenceStore: retirementStore,
                transition: RecordingTopologyTransition()
            )
        }
        await transition.resume()
        _ = try await first.value

        let replayCollector = InvestigationLifecycleTopologyCollector(
            topologyObserver: ScriptedTopologyObserver(results: []),
            bindingReader: FixedTopologyBindingReader(
                binding: fixture.binding
            ),
            effectiveUserID: { 0 },
            now: fixture.clock.read
        )
        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .retirementEvidenceMismatch
        ) {
            _ = try await replayCollector.collect(
                request: fixture.collectionRequest(),
                retirementEvidenceStore: retirementStore,
                transition: RecordingTopologyTransition()
            )
        }
    }

    @Test
    func cancellationAfterInstalledObservationConsumesTheCollector()
        async throws
    {
        let fixture = try LifecycleTopologyCollectorFixture()
        let transition = SuspendedTopologyTransition()
        let collector = InvestigationLifecycleTopologyCollector(
            topologyObserver: ScriptedTopologyObserver(results: [
                .success(try fixture.installedObservation()),
                .success(try fixture.postTeardownObservation()),
            ]),
            bindingReader: FixedTopologyBindingReader(
                binding: fixture.binding
            ),
            effectiveUserID: { 0 },
            now: fixture.clock.read
        )
        let store = try await fixture.retirementEvidenceStore()
        let task = Task {
            try await collector.collect(
                request: fixture.collectionRequest(),
                retirementEvidenceStore: store,
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
                retirementEvidenceStore:
                    try await fixture.retirementEvidenceStore(),
                transition: RecordingTopologyTransition()
            )
        }
    }
}

private struct FixedTopologyBindingReader:
    InvestigationLifecycleTopologyBindingReading
{
    let binding: LifecycleRootTopologyBinding

    func readBinding(
        signedBinding _: SignedInvestigationRuntimeBinding
    ) throws -> LifecycleRootTopologyBinding {
        binding
    }
}

private actor ScriptedTopologyObserver:
    InvestigationLifecycleTopologyObserving
{
    private var results: [
        Result<
            LifecycleRootTopologyObservation,
            LifecycleRootTopologyObservationError
        >
    ]
    private(set) var phases: [LifecycleRootTopologyPhase] = []
    private let afterObservation: @Sendable () -> Void

    init(
        results: [
            Result<
                LifecycleRootTopologyObservation,
                LifecycleRootTopologyObservationError
            >
        ],
        afterObservation: @escaping @Sendable () -> Void = {}
    ) {
        self.results = results
        self.afterObservation = afterObservation
    }

    func observe(
        _ request: LifecycleRootTopologyObservationRequest
    ) async throws -> LifecycleRootTopologyObservation {
        phases.append(request.phase)
        guard !results.isEmpty else {
            throw LifecycleRootTopologyObservationError.invalidRequest
        }
        let value = try results.removeFirst().get()
        afterObservation()
        return value
    }
}

private final class MutableEffectiveUserID: @unchecked Sendable {
    private let lock = NSLock()
    private var value: uid_t

    init(value: uid_t) {
        self.value = value
    }

    func read() -> uid_t {
        lock.withLock { value }
    }

    func set(_ value: uid_t) {
        lock.withLock { self.value = value }
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
