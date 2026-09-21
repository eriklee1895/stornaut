import Darwin
import Foundation
import StornautInvestigation
import StornautInvestigationMachineDriverSupport
import StornautInvestigationRuntime
import StornautLifecycle

enum InvestigationMachineDriverHostError:
    Error,
    Sendable,
    Equatable
{
    case rootAuthorityRequired
    case hostConsumed
    case handoffUnavailable
    case implementationUnavailable
}

protocol InvestigationMachineRetirementHandleHandoff: Sendable {
    func takeOnce() async throws -> LifecycleMachineRetirementHandle
}

protocol InvestigationMachineRetirementClaiming: Sendable {
    func claim(
        handle: LifecycleMachineRetirementHandle
    ) async throws -> InvestigationMachineRetirementClaim
}

extension InvestigationMachineRetirementClaimant:
    InvestigationMachineRetirementClaiming
{}

struct InvestigationMachineTopologyAuthority: Sendable {
    let cohort: InvestigationLifecycleTopologyCohort
}

struct StrictMachineRetirementClaimSource:
    InvestigationMachineRetirementClaimSource,
    Sendable
{
    typealias Result = (
        LifecycleMachineRetirementClaimResponse,
        LifecycleProcessIdentity,
        Date
    )

    private let fetchOperation: @Sendable (
        LifecycleMachineRetirementClaimRequest
    ) async throws -> Result

    init(
        fetch: @escaping @Sendable (
            LifecycleMachineRetirementClaimRequest
        ) async throws -> Result
    ) {
        fetchOperation = fetch
    }

    func fetch(
        request: LifecycleMachineRetirementClaimRequest
    ) async throws -> Result {
        try await fetchOperation(request)
    }
}

actor InvestigationMachineDriverHost {
    private enum State {
        case ready
        case running
        case consumed
    }

    nonisolated let configuration:
        SignedInvestigationRuntimeDiagnosticConfiguration
    private let appProcessIdentity: LifecycleProcessIdentity
    private let userID: UInt32
    private let handoff: any InvestigationMachineRetirementHandleHandoff
    private let claimant: any InvestigationMachineRetirementClaiming
    private let collectorFactory: @Sendable (LifecycleProcessIdentity)
        -> InvestigationLifecycleTopologyCollector
    private let transition:
        any InvestigationLifecycleTopologyTransitioning
    nonisolated let transitionBindingToken: UUID?
    private let effectiveUserID: @Sendable () -> uid_t
    private let now: @Sendable () -> Date
    private var state = State.ready

    init(
        configuration: SignedInvestigationRuntimeDiagnosticConfiguration,
        appProcessIdentity: LifecycleProcessIdentity,
        userID: UInt32,
        handoff: any InvestigationMachineRetirementHandleHandoff,
        claimant: any InvestigationMachineRetirementClaiming,
        collectorFactory: @escaping @Sendable (LifecycleProcessIdentity)
            -> InvestigationLifecycleTopologyCollector,
        transition: any InvestigationLifecycleTopologyTransitioning,
        effectiveUserID: @escaping @Sendable () -> uid_t = geteuid,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.configuration = configuration
        self.appProcessIdentity = appProcessIdentity
        self.userID = userID
        self.handoff = handoff
        self.claimant = claimant
        self.collectorFactory = collectorFactory
        self.transition = transition
        transitionBindingToken =
            (transition as? InvestigationFixedScenarioRunner)?
                .bindingToken
        self.effectiveUserID = effectiveUserID
        self.now = now
    }

    static func production(
        configuration: SignedInvestigationRuntimeDiagnosticConfiguration,
        appProcessIdentity: LifecycleProcessIdentity,
        userID: UInt32,
        handoff: any InvestigationMachineRetirementHandleHandoff,
        transition: any InvestigationLifecycleTopologyTransitioning,
        effectiveUserID: @escaping @Sendable () -> uid_t = geteuid,
        now: @escaping @Sendable () -> Date = Date.init
    ) throws -> InvestigationMachineDriverHost {
        _ = (
            configuration, appProcessIdentity, userID, handoff, transition,
            effectiveUserID, now
        )
        throw InvestigationMachineDriverHostError.implementationUnavailable
    }

    func run() async throws -> InvestigationMachineTopologyAuthority {
        guard state == .ready else {
            throw InvestigationMachineDriverHostError.hostConsumed
        }
        state = .running
        defer { state = .consumed }

        try Task.checkCancellation()
        guard effectiveUserID() == 0 else {
            throw InvestigationMachineDriverHostError
                .rootAuthorityRequired
        }
        let handle: LifecycleMachineRetirementHandle
        do {
            handle = try await handoff.takeOnce()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            throw InvestigationMachineDriverHostError.handoffUnavailable
        }
        try Task.checkCancellation()
        let claim = try await claimant.claim(handle: handle)
        try Task.checkCancellation()

        let store = InvestigationMachineRetirementClaimStore()
        try await store.record(claim)
        let openedAt = now()
        let validBefore = min(
            configuration.validBefore,
            claim.request.validBefore
        )
        let request = try InvestigationLifecycleTopologyCollectionRequest(
            userID: userID,
            configuration: configuration,
            appProcessIdentity: appProcessIdentity,
            openedAt: openedAt,
            validBefore: validBefore
        )
        let collector = collectorFactory(claim.helperPeerIdentity)
        let cohort = try await collector.collect(
            request: request,
            retirementClaimStore: store,
            transition: transition
        )
        return InvestigationMachineTopologyAuthority(cohort: cohort)
    }
}

package enum InvestigationMachineDriverEntryPoint {
    static let rootAuthorityRequiredExitStatus =
        InvestigationMachineDriverSupport.rootAuthorityRequiredExitStatus
    static let handoffUnavailableExitStatus =
        InvestigationMachineDriverSupport.handoffUnavailableExitStatus

    package static func run() async -> Int32 {
        await InvestigationMachineDriverSupport.run()
    }

    static func run(
        effectiveUserID: @escaping @Sendable () -> uid_t
    ) async -> Int32 {
        guard effectiveUserID() == 0 else {
            return rootAuthorityRequiredExitStatus
        }
        return handoffUnavailableExitStatus
    }
}
