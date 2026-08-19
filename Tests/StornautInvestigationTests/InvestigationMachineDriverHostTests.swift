import Darwin
import Foundation
import Testing
import StornautInvestigation
@testable import StornautInvestigationMachine
@testable import StornautInvestigationMachineDriverSupport
import StornautInvestigationRuntime
import StornautLifecycle

@Suite("Investigation machine driver host")
struct InvestigationMachineDriverHostTests {
    @Test
    func productionFactoryIsUnavailableBeforeHandoffOrTopology() async throws {
        let fixture = try DriverHostFixture()
        let events = DriverHostEventRecorder()
        let handoff = RecordingDriverHandoff(
            handle: fixture.handle,
            events: events
        )

        #expect(
            throws: InvestigationMachineDriverHostError
                .implementationUnavailable
        ) {
            _ = try InvestigationMachineDriverHost.production(
                configuration: fixture.topology.configuration,
                appProcessIdentity: fixture.topology.appIdentity,
                userID: fixture.topology.userID,
                handoff: handoff,
                transition: DriverHostTransition(events: events, error: nil),
                effectiveUserID: { 0 },
                now: fixture.topology.clock.read
            )
        }
        #expect(await events.snapshot.isEmpty)

        let source = try String(
            contentsOf: URL(filePath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(path: "Sources/StornautInvestigationMachine/InvestigationMachineDriverHost.swift"),
            encoding: .utf8
        )
        #expect(source.contains("case implementationUnavailable"))
        #expect(source.contains("throw InvestigationMachineDriverHostError.implementationUnavailable"))
        #expect(!source.contains("LifecycleMachineClaimXPCClient()"))
        #expect(!source.contains("InstalledMachineRetirementHelperSigningVerifier"))
    }

    @Test
    func authorityClosedSupportPreservesFixedUnavailableStatuses() async {
        #expect(
            InvestigationMachineDriverSupport.status(effectiveUserID: 501)
                == 77
        )
        #expect(
            InvestigationMachineDriverSupport.status(effectiveUserID: 0)
                == 78
        )
    }

    @Test
    func nonRootFailsBeforeHandoffOrClaimAndConsumesHost() async throws {
        let fixture = try DriverHostFixture()
        let events = DriverHostEventRecorder()
        let handoff = RecordingDriverHandoff(
            handle: fixture.handle,
            events: events
        )
        let claimant = RecordingDriverClaimant(
            claim: fixture.claim,
            events: events
        )
        let host = fixture.host(
            handoff: handoff,
            claimant: claimant,
            events: events,
            effectiveUserID: { 501 }
        )

        await #expect(
            throws: InvestigationMachineDriverHostError
                .rootAuthorityRequired
        ) {
            _ = try await host.run()
        }
        #expect(await events.snapshot.isEmpty)
        await #expect(
            throws: InvestigationMachineDriverHostError.hostConsumed
        ) {
            _ = try await host.run()
        }
    }

    @Test
    func successfulRunPreservesClaimInstalledTransitionPostOrder()
        async throws
    {
        let fixture = try DriverHostFixture()
        let events = DriverHostEventRecorder()
        let handoff = RecordingDriverHandoff(
            handle: fixture.handle,
            events: events
        )
        let claimant = RecordingDriverClaimant(
            claim: fixture.claim,
            events: events
        )
        let host = fixture.host(
            handoff: handoff,
            claimant: claimant,
            events: events
        )

        let authority = try await host.run()

        #expect(await events.snapshot == [
            "handoff",
            "claim",
            "installed",
            "transition",
            "postTeardown",
        ])
        #expect(
            authority.cohort.investigationID
                == fixture.topology.investigationID
        )
        #expect(authority.cohort.installedTopology.provesInstalledTopology)
        #expect(
            authority.cohort.postTeardownTopology
                .provesPostTeardownTopology
        )
        #expect(!(InvestigationMachineTopologyAuthority.self is any Codable.Type))
        await #expect(
            throws: InvestigationMachineDriverHostError.hostConsumed
        ) {
            _ = try await host.run()
        }
    }

    @Test
    func concurrentAndFailedHandoffsRemainTerminalAndOneShot() async throws {
        let fixture = try DriverHostFixture()
        let events = DriverHostEventRecorder()
        let handoff = SuspendedDriverHandoff(events: events)
        let claimant = RecordingDriverClaimant(
            claim: fixture.claim,
            events: events
        )
        let host = fixture.host(
            handoff: handoff,
            claimant: claimant,
            events: events
        )
        let first = Task { try await host.run() }

        try await handoff.waitUntilTaken()
        await #expect(
            throws: InvestigationMachineDriverHostError.hostConsumed
        ) {
            _ = try await host.run()
        }
        await handoff.fail()
        await #expect(
            throws: InvestigationMachineDriverHostError.handoffUnavailable
        ) {
            _ = try await first.value
        }
        #expect(await events.snapshot == ["handoff"])
        #expect(await handoff.invocationCount == 1)
        await #expect(
            throws: InvestigationMachineDriverHostError.hostConsumed
        ) {
            _ = try await host.run()
        }
    }

    @Test
    func claimFailureDoesNotObserveTopologyOrRetry() async throws {
        let fixture = try DriverHostFixture()
        let events = DriverHostEventRecorder()
        let handoff = RecordingDriverHandoff(
            handle: fixture.handle,
            events: events
        )
        let claimant = RecordingDriverClaimant(
            error: InvestigationMachineRetirementClaimError.sourceFailed,
            events: events
        )
        let host = fixture.host(
            handoff: handoff,
            claimant: claimant,
            events: events
        )

        await #expect(
            throws: InvestigationMachineRetirementClaimError.sourceFailed
        ) {
            _ = try await host.run()
        }
        #expect(await events.snapshot == ["handoff", "claim"])
        #expect(await claimant.invocationCount == 1)
        await #expect(
            throws: InvestigationMachineDriverHostError.hostConsumed
        ) {
            _ = try await host.run()
        }
        #expect(await claimant.invocationCount == 1)
    }

    @Test
    func cancellationAfterClaimStartsPreventsTopologyAndIsTerminal()
        async throws
    {
        let fixture = try DriverHostFixture()
        let events = DriverHostEventRecorder()
        let claimant = SuspendedDriverClaimant(
            claim: fixture.claim,
            events: events
        )
        let host = fixture.host(
            handoff: RecordingDriverHandoff(
                handle: fixture.handle,
                events: events
            ),
            claimant: claimant,
            events: events
        )
        let task = Task { try await host.run() }

        try await claimant.waitUntilClaimed()
        task.cancel()
        await claimant.resume()

        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
        #expect(await events.snapshot == ["handoff", "claim"])
        #expect(await claimant.invocationCount == 1)
        await #expect(
            throws: InvestigationMachineDriverHostError.hostConsumed
        ) {
            _ = try await host.run()
        }
    }

    @Test
    func topologyAndTransitionFailuresNeverEmitAuthority() async throws {
        let installedFixture = try DriverHostFixture()
        let installedEvents = DriverHostEventRecorder()
        let installedHost = installedFixture.host(
            handoff: RecordingDriverHandoff(
                handle: installedFixture.handle,
                events: installedEvents
            ),
            claimant: RecordingDriverClaimant(
                claim: installedFixture.claim,
                events: installedEvents
            ),
            events: installedEvents,
            installedError: LifecycleRootTopologyObservationError
                .invalidRequest
        )
        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .installedTopologyUnproved
        ) {
            _ = try await installedHost.run()
        }
        #expect(await installedEvents.snapshot == [
            "handoff", "claim", "installed",
        ])
        await #expect(
            throws: InvestigationMachineDriverHostError.hostConsumed
        ) {
            _ = try await installedHost.run()
        }

        let transitionFixture = try DriverHostFixture()
        let transitionEvents = DriverHostEventRecorder()
        let transitionHost = transitionFixture.host(
            handoff: RecordingDriverHandoff(
                handle: transitionFixture.handle,
                events: transitionEvents
            ),
            claimant: RecordingDriverClaimant(
                claim: transitionFixture.claim,
                events: transitionEvents
            ),
            events: transitionEvents,
            transitionError: DriverHostInjectedFailure()
        )
        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .transitionFailed
        ) {
            _ = try await transitionHost.run()
        }
        #expect(await transitionEvents.snapshot == [
            "handoff", "claim", "installed", "transition",
        ])
        await #expect(
            throws: InvestigationMachineDriverHostError.hostConsumed
        ) {
            _ = try await transitionHost.run()
        }

        let postFixture = try DriverHostFixture()
        let postEvents = DriverHostEventRecorder()
        let postHost = postFixture.host(
            handoff: RecordingDriverHandoff(
                handle: postFixture.handle,
                events: postEvents
            ),
            claimant: RecordingDriverClaimant(
                claim: postFixture.claim,
                events: postEvents
            ),
            events: postEvents,
            postTeardownError: LifecycleRootTopologyObservationError
                .invalidRequest
        )
        await #expect(
            throws: InvestigationLifecycleTopologyCollectorError
                .postTeardownTopologyUnproved
        ) {
            _ = try await postHost.run()
        }
        #expect(await postEvents.snapshot == [
            "handoff",
            "claim",
            "installed",
            "transition",
            "postTeardown",
        ])
        await #expect(
            throws: InvestigationMachineDriverHostError.hostConsumed
        ) {
            _ = try await postHost.run()
        }
    }

    @Test
    func strictClaimSourceForwardsOnceAndKeepsTransportInternal() async throws {
        let fixture = try DriverHostFixture()
        let requests = DriverClaimRequestRecorder()
        let success = StrictMachineRetirementClaimSource(fetch: { request in
            await requests.record(request)
            return (
                fixture.response,
                fixture.topology.helperIdentity,
                fixture.claim.helperPeerAttestedAt
            )
        })

        let result = try await success.fetch(request: fixture.request)

        #expect(result.0 == fixture.response)
        #expect(result.1 == fixture.topology.helperIdentity)
        #expect(await requests.snapshot == [fixture.request])

        let source = try String(
            contentsOf: URL(filePath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(path: "Sources/StornautInvestigationMachine/InvestigationMachineRetirementClaim.swift"),
            encoding: .utf8
        )
        #expect(source.contains("enum InvestigationMachineRetirementClaimSourceError"))
        #expect(source.contains("case outcomeUnknown"))
        #expect(!source.contains("LifecycleMachineClaimXPCError"))
    }

    @Test
    func productionClaimantPreservesPostDispatchOutcomeUnknown() async throws {
        let fixture = try DriverHostFixture()
        let source = StrictMachineRetirementClaimSource(fetch: { _ in
            throw InvestigationMachineRetirementClaimSourceError.outcomeUnknown
        })
        let claimant = try InvestigationMachineRetirementClaimant(
            source: source,
            signingVerifier: DriverHostHelperSigningVerifier(),
            effectiveUserID: { 0 },
            now: fixture.topology.clock.read,
            challenge: { fixture.request.challengeNonce },
            configuration: fixture.topology.configuration,
            expectedAppIdentity: try LifecycleMachineProcessIdentityRecord(
                processID: fixture.topology.appIdentity.processID,
                processIDVersion:
                    fixture.topology.appIdentity.processIDVersion,
                auditSessionID:
                    fixture.topology.appIdentity.auditSessionID,
                effectiveUserID:
                    fixture.topology.appIdentity.effectiveUserID,
                auditTokenWords:
                    fixture.topology.appIdentity.auditToken.words
            ),
            expectedUserID: fixture.topology.userID
        )

        await #expect(
            throws: InvestigationMachineRetirementClaimError.outcomeUnknown
        ) {
            _ = try await claimant.claim(handle: fixture.handle)
        }

        let suspended = SuspendedOutcomeUnknownClaimSource()
        let cancelledClaimant = try InvestigationMachineRetirementClaimant(
            source: suspended,
            signingVerifier: DriverHostHelperSigningVerifier(),
            effectiveUserID: { 0 },
            now: fixture.topology.clock.read,
            challenge: { fixture.request.challengeNonce },
            configuration: fixture.topology.configuration,
            expectedAppIdentity: try LifecycleMachineProcessIdentityRecord(
                processID: fixture.topology.appIdentity.processID,
                processIDVersion:
                    fixture.topology.appIdentity.processIDVersion,
                auditSessionID:
                    fixture.topology.appIdentity.auditSessionID,
                effectiveUserID:
                    fixture.topology.appIdentity.effectiveUserID,
                auditTokenWords:
                    fixture.topology.appIdentity.auditToken.words
            ),
            expectedUserID: fixture.topology.userID
        )
        let task = Task {
            try await cancelledClaimant.claim(handle: fixture.handle)
        }
        try await suspended.waitUntilFetched()
        task.cancel()
        await suspended.failOutcomeUnknown()

        await #expect(
            throws: InvestigationMachineRetirementClaimError.outcomeUnknown
        ) {
            _ = try await task.value
        }
    }

    @Test
    func packageEntryPointIsRootGatedAndFailsClosedWithoutLiveHandoff() async {
        let nonRoot = await InvestigationMachineDriverEntryPoint.run(
            effectiveUserID: { 501 }
        )
        let root = await InvestigationMachineDriverEntryPoint.run(
            effectiveUserID: { 0 }
        )

        #expect(
            nonRoot
                == InvestigationMachineDriverEntryPoint
                    .rootAuthorityRequiredExitStatus
        )
        #expect(
            root
                == InvestigationMachineDriverEntryPoint
                    .handoffUnavailableExitStatus
        )
        #expect(root != 0)
    }
}

private final class DriverHostFixture: @unchecked Sendable {
    let topology: LifecycleTopologyCollectorFixture
    let handle: LifecycleMachineRetirementHandle
    let request: LifecycleMachineRetirementClaimRequest
    let response: LifecycleMachineRetirementClaimResponse
    let claim: InvestigationMachineRetirementClaim

    init() throws {
        topology = try LifecycleTopologyCollectorFixture()
        let now = topology.clock.read()
        handle = try LifecycleMachineRetirementHandle(
            token: UUID(
                uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"
            )!,
            investigationID: topology.investigationID,
            retireOperationID: UUID(
                uuidString: "bbbbbbbb-cccc-4ddd-8eee-ffffffffffff"
            )!,
            configurationSHA256:
                topology.configuration.machineConfigurationSHA256(),
            validBefore: now.addingTimeInterval(15)
        )
        request = try LifecycleMachineRetirementClaimRequest(
            handle: handle,
            challengeNonce: UUID(
                uuidString: "cccccccc-dddd-4eee-8fff-aaaaaaaaaaaa"
            )!,
            issuedAt: now.addingTimeInterval(-2),
            validBefore: now.addingTimeInterval(13)
        )
        response = try LifecycleMachineRetirementClaimResponse(
            request: request,
            appIdentity: try Self.record(topology.appIdentity),
            helperIdentity: try Self.record(topology.helperIdentity),
            userID: topology.userID,
            recordedAt: now.addingTimeInterval(-3),
            claimedAt: now.addingTimeInterval(-1),
            ownerRetirementObservation: .retiredOwnedResources,
            residueObservation: try LifecycleInvestigationResidueObservation(
                investigationID: topology.investigationID,
                auditSessionID: topology.helperIdentity.auditSessionID,
                userID: topology.userID,
                observedAt: now.addingTimeInterval(-4),
                remainingAuditSessionMemberCount: 0,
                matchingLeaseCount: 0,
                leaseRootEntryCount: 0,
                investigationArtifactCount: 0
            )
        )
        claim = InvestigationMachineRetirementClaim(
            response: response,
            helperPeerIdentity: topology.helperIdentity,
            helperPeerAttestedAt: now.addingTimeInterval(-1)
        )
    }

    func host(
        handoff: any InvestigationMachineRetirementHandleHandoff,
        claimant: any InvestigationMachineRetirementClaiming,
        events: DriverHostEventRecorder,
        effectiveUserID: @escaping @Sendable () -> uid_t = { 0 },
        installedError: LifecycleRootTopologyObservationError? = nil,
        transitionError: (any Error)? = nil,
        postTeardownError: LifecycleRootTopologyObservationError? = nil
    ) -> InvestigationMachineDriverHost {
        InvestigationMachineDriverHost(
            configuration: topology.configuration,
            appProcessIdentity: topology.appIdentity,
            userID: topology.userID,
            handoff: handoff,
            claimant: claimant,
            collectorFactory: { _ in
                InvestigationLifecycleTopologyCollector(
                    topologyObserver: DriverHostTopologyObserver(
                        installed: try! self.topology
                            .installedObservation(),
                        postTeardown: try! self.topology
                            .postTeardownObservation(),
                        events: events,
                        installedError: installedError,
                        postTeardownError: postTeardownError
                    ),
                    bindingReader: DriverHostBindingReader(
                        binding: self.topology.binding
                    ),
                    effectiveUserID: effectiveUserID,
                    now: self.topology.clock.read
                )
            },
            transition: DriverHostTransition(
                events: events,
                error: transitionError
            ),
            effectiveUserID: effectiveUserID,
            now: topology.clock.read
        )
    }

    private static func record(
        _ identity: LifecycleProcessIdentity
    ) throws -> LifecycleMachineProcessIdentityRecord {
        try LifecycleMachineProcessIdentityRecord(
            processID: identity.processID,
            processIDVersion: identity.processIDVersion,
            auditSessionID: identity.auditSessionID,
            effectiveUserID: identity.effectiveUserID,
            auditTokenWords: identity.auditToken.words
        )
    }
}

private actor DriverHostEventRecorder {
    private var values: [String] = []

    var snapshot: [String] { values }

    func record(_ value: String) {
        values.append(value)
    }
}

private struct RecordingDriverHandoff:
    InvestigationMachineRetirementHandleHandoff
{
    let handle: LifecycleMachineRetirementHandle
    let events: DriverHostEventRecorder

    func takeOnce() async throws -> LifecycleMachineRetirementHandle {
        await events.record("handoff")
        return handle
    }
}

private actor SuspendedDriverHandoff:
    InvestigationMachineRetirementHandleHandoff
{
    private struct HandoffFailure: Error {}

    let events: DriverHostEventRecorder
    private let entered = DriverPhaseLatch()
    private(set) var invocationCount = 0
    private var continuation:
        CheckedContinuation<LifecycleMachineRetirementHandle, any Error>?

    init(events: DriverHostEventRecorder) {
        self.events = events
    }

    func takeOnce() async throws -> LifecycleMachineRetirementHandle {
        invocationCount += 1
        await events.record("handoff")
        return try await withCheckedThrowingContinuation {
            continuation = $0
            Task { await entered.signal() }
        }
    }

    func waitUntilTaken() async throws {
        try await entered.wait()
    }

    func fail() {
        continuation?.resume(throwing: HandoffFailure())
        continuation = nil
    }
}

private actor RecordingDriverClaimant:
    InvestigationMachineRetirementClaiming
{
    private let result: Result<
        InvestigationMachineRetirementClaim,
        any Error
    >
    private let events: DriverHostEventRecorder
    private(set) var invocationCount = 0

    init(
        claim: InvestigationMachineRetirementClaim,
        events: DriverHostEventRecorder
    ) {
        result = .success(claim)
        self.events = events
    }

    init(
        error: any Error,
        events: DriverHostEventRecorder
    ) {
        result = .failure(error)
        self.events = events
    }

    func claim(
        handle _: LifecycleMachineRetirementHandle
    ) async throws -> InvestigationMachineRetirementClaim {
        invocationCount += 1
        await events.record("claim")
        return try result.get()
    }
}

private actor SuspendedDriverClaimant:
    InvestigationMachineRetirementClaiming
{
    let claimValue: InvestigationMachineRetirementClaim
    let events: DriverHostEventRecorder
    private let entered = DriverPhaseLatch()
    private(set) var invocationCount = 0
    private var continuation:
        CheckedContinuation<InvestigationMachineRetirementClaim, Never>?

    init(
        claim: InvestigationMachineRetirementClaim,
        events: DriverHostEventRecorder
    ) {
        claimValue = claim
        self.events = events
    }

    func claim(
        handle _: LifecycleMachineRetirementHandle
    ) async -> InvestigationMachineRetirementClaim {
        invocationCount += 1
        await events.record("claim")
        return await withCheckedContinuation {
            continuation = $0
            Task { await entered.signal() }
        }
    }

    func waitUntilClaimed() async throws {
        try await entered.wait()
    }

    func resume() {
        continuation?.resume(returning: claimValue)
        continuation = nil
    }
}

private struct DriverPhaseTimeout: Error {}

private actor DriverPhaseLatch {
    private struct Waiter {
        let continuation: CheckedContinuation<Bool, Never>
        let timeout: Task<Void, Never>
    }

    private var signaled = false
    private var waiters: [UUID: Waiter] = [:]

    func signal() {
        guard !signaled else { return }
        signaled = true
        let pending = waiters
        waiters.removeAll()
        for waiter in pending.values {
            waiter.timeout.cancel()
            waiter.continuation.resume(returning: true)
        }
    }

    func wait() async throws {
        if signaled { return }
        let identifier = UUID()
        let reached: Bool = await withCheckedContinuation {
            (continuation: CheckedContinuation<Bool, Never>) in
            let timeoutTask = Task.detached { [self] in
                do {
                    try await Task.sleep(for: .seconds(2))
                } catch {
                    return
                }
                await expire(identifier)
            }
            waiters[identifier] = Waiter(
                continuation: continuation,
                timeout: timeoutTask
            )
        }
        guard reached else { throw DriverPhaseTimeout() }
    }

    private func expire(_ identifier: UUID) {
        guard let waiter = waiters.removeValue(forKey: identifier) else {
            return
        }
        waiter.continuation.resume(returning: false)
    }
}

private struct DriverHostBindingReader:
    InvestigationLifecycleTopologyBindingReading
{
    let binding: LifecycleRootTopologyBinding

    func readBinding(
        signedBinding _: SignedInvestigationRuntimeBinding
    ) throws -> LifecycleRootTopologyBinding {
        binding
    }
}

private actor DriverHostTopologyObserver:
    InvestigationLifecycleTopologyObserving
{
    let installed: LifecycleRootTopologyObservation
    let postTeardown: LifecycleRootTopologyObservation
    let events: DriverHostEventRecorder
    let installedError: LifecycleRootTopologyObservationError?
    let postTeardownError: LifecycleRootTopologyObservationError?

    init(
        installed: LifecycleRootTopologyObservation,
        postTeardown: LifecycleRootTopologyObservation,
        events: DriverHostEventRecorder,
        installedError: LifecycleRootTopologyObservationError?,
        postTeardownError: LifecycleRootTopologyObservationError?
    ) {
        self.installed = installed
        self.postTeardown = postTeardown
        self.events = events
        self.installedError = installedError
        self.postTeardownError = postTeardownError
    }

    func observe(
        _ request: LifecycleRootTopologyObservationRequest
    ) async throws -> LifecycleRootTopologyObservation {
        switch request.phase {
        case .installed:
            await events.record("installed")
            if let installedError { throw installedError }
            return installed
        case .postTeardown:
            await events.record("postTeardown")
            if let postTeardownError { throw postTeardownError }
            return postTeardown
        }
    }
}

private struct DriverHostTransition:
    InvestigationLifecycleTopologyTransitioning
{
    let events: DriverHostEventRecorder
    let error: (any Error)?

    func transition() async throws {
        await events.record("transition")
        if let error { throw error }
    }
}

private struct DriverHostInjectedFailure: Error {}

private actor DriverClaimRequestRecorder {
    private var requests: [LifecycleMachineRetirementClaimRequest] = []

    var snapshot: [LifecycleMachineRetirementClaimRequest] { requests }

    func record(_ request: LifecycleMachineRetirementClaimRequest) {
        requests.append(request)
    }
}

private struct DriverHostHelperSigningVerifier:
    InvestigationMachineRetirementHelperSigningVerifying
{
    func verifies(helperIdentity _: LifecycleProcessIdentity) -> Bool {
        true
    }
}

private actor SuspendedOutcomeUnknownClaimSource:
    InvestigationMachineRetirementClaimSource
{
    private let entered = DriverPhaseLatch()
    private var continuation: CheckedContinuation<
        StrictMachineRetirementClaimSource.Result,
        any Error
    >?

    func fetch(
        request _: LifecycleMachineRetirementClaimRequest
    ) async throws -> StrictMachineRetirementClaimSource.Result {
        return try await withCheckedThrowingContinuation {
            continuation = $0
            Task { await entered.signal() }
        }
    }

    func waitUntilFetched() async throws {
        try await entered.wait()
    }

    func failOutcomeUnknown() {
        continuation?.resume(
            throwing: InvestigationMachineRetirementClaimSourceError
                .outcomeUnknown
        )
        continuation = nil
    }
}
