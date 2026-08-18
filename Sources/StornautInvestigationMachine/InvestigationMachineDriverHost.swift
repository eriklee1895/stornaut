import Darwin
import Foundation
import StornautInvestigation
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

    init() {
        let client = LifecycleMachineClaimXPCClient()
        fetchOperation = { request in
            let result = try await client.claim(request)
            return (
                result.response,
                result.helperIdentity,
                result.helperAttestedAt
            )
        }
    }

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

struct InstalledMachineRetirementHelperSigningVerifier:
    InvestigationMachineRetirementHelperSigningVerifying,
    Sendable
{
    private let staticEvidence: @Sendable () throws
        -> LifecycleBundleSigningEvidence
    private let dynamicVerification: @Sendable (LifecycleAuditToken)
        -> LifecycleCodeSigningVerification

    init() {
        staticEvidence = {
            let contract = try LifecycleLocalInstallationContract()
            return try LifecycleBundleSigningIdentityReader().evidence(
                bundleURL: contract.helperExecutableURL
            )
        }
        dynamicVerification = { auditToken in
            SecurityLifecycleCodeSigningVerifier().verify(
                auditToken: auditToken
            )
        }
    }

    init(
        staticEvidence: @escaping @Sendable () throws
            -> LifecycleBundleSigningEvidence,
        dynamicVerification: @escaping @Sendable (LifecycleAuditToken)
            -> LifecycleCodeSigningVerification
    ) {
        self.staticEvidence = staticEvidence
        self.dynamicVerification = dynamicVerification
    }

    func verifies(helperIdentity: LifecycleProcessIdentity) -> Bool {
        guard
            validRootIdentity(helperIdentity),
            let contract = try? LifecycleLocalInstallationContract(),
            let staticEvidence = try? staticEvidence(),
            staticEvidence.identity.signingIdentifier
                == contract.helperSigningIdentifier,
            case let .verified(
                processID,
                effectiveUserID,
                signingIdentifier,
                designatedRequirementSHA256,
                codeDirectoryHash
            ) = dynamicVerification(helperIdentity.auditToken)
        else {
            return false
        }
        return processID == helperIdentity.processID
            && effectiveUserID == 0
            && signingIdentifier
                == staticEvidence.identity.signingIdentifier
            && designatedRequirementSHA256
                == staticEvidence.identity.designatedRequirementSHA256
            && codeDirectoryHash
                == staticEvidence.identity.codeDirectoryHash
    }

    private func validRootIdentity(
        _ identity: LifecycleProcessIdentity
    ) -> Bool {
        guard
            identity.processID > 1,
            identity.processIDVersion > 0,
            identity.auditSessionID > 0,
            identity.effectiveUserID == 0,
            identity.auditToken.words.count
                == LifecycleAuditToken.wordCount
        else {
            return false
        }
        var token = audit_token_t()
        let copied = withUnsafeMutableBytes(of: &token) { destination in
            identity.auditToken.words.withUnsafeBytes { source in
                guard destination.count == source.count else {
                    return false
                }
                destination.copyBytes(from: source)
                return true
            }
        }
        return copied
            && audit_token_to_pid(token) == identity.processID
            && audit_token_to_pidversion(token)
                == identity.processIDVersion
            && audit_token_to_asid(token)
                == identity.auditSessionID
            && audit_token_to_euid(token) == 0
    }
}

actor InvestigationMachineDriverHost {
    private enum State {
        case ready
        case running
        case consumed
    }

    private let configuration:
        SignedInvestigationRuntimeDiagnosticConfiguration
    private let appProcessIdentity: LifecycleProcessIdentity
    private let userID: UInt32
    private let handoff: any InvestigationMachineRetirementHandleHandoff
    private let claimant: any InvestigationMachineRetirementClaiming
    private let collectorFactory: @Sendable (LifecycleProcessIdentity)
        -> InvestigationLifecycleTopologyCollector
    private let transition:
        any InvestigationLifecycleTopologyTransitioning
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
        let claimant = try InvestigationMachineRetirementClaimant(
            source: StrictMachineRetirementClaimSource(),
            signingVerifier:
                InstalledMachineRetirementHelperSigningVerifier(),
            effectiveUserID: effectiveUserID,
            now: now,
            configuration: configuration,
            expectedAppIdentity: try machineIdentityRecord(
                appProcessIdentity
            ),
            expectedUserID: userID
        )
        return InvestigationMachineDriverHost(
            configuration: configuration,
            appProcessIdentity: appProcessIdentity,
            userID: userID,
            handoff: handoff,
            claimant: claimant,
            collectorFactory: { helperIdentity in
                InvestigationLifecycleTopologyCollector(
                    topologyObserver:
                        DarwinInvestigationLifecycleTopologyObserver(
                            expectedHelperIdentity: helperIdentity
                        ),
                    bindingReader:
                        InstalledLifecycleTopologyBindingReader(),
                    effectiveUserID: effectiveUserID,
                    now: now
                )
            },
            transition: transition,
            effectiveUserID: effectiveUserID,
            now: now
        )
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
    static let rootAuthorityRequiredExitStatus: Int32 = 77
    static let handoffUnavailableExitStatus: Int32 = 78

    package static func run() async -> Int32 {
        await run(effectiveUserID: geteuid)
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

private func machineIdentityRecord(
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
