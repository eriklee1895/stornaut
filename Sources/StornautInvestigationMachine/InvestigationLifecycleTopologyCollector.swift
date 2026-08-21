import Darwin
import Foundation
import StornautInvestigation
import StornautInvestigationRuntime
import StornautLifecycle

enum InvestigationLifecycleTopologyCollectorError:
    Error,
    Sendable,
    Equatable
{
    case invalidRequest
    case rootAuthorityRequired
    case collectorConsumed
    case bindingMismatch
    case retirementEvidenceMismatch
    case transitionFailed
    case postTeardownTopologyUnproved
    case observationOutsideWindow
}

struct InvestigationLifecycleTopologyCollectionRequest:
    Sendable,
    Equatable
{
    let investigationID: LifecycleInvestigationID
    let userID: UInt32
    let scenario: SignedInvestigationRuntimeDiagnosticScenario
    let signedBinding: SignedInvestigationRuntimeBinding
    let configurationSHA256: String
    let appProcessIdentity: LifecycleProcessIdentity
    let openedAt: Date
    let validBefore: Date

    init(
        userID: UInt32,
        configuration:
            SignedInvestigationRuntimeDiagnosticConfiguration,
        appProcessIdentity: LifecycleProcessIdentity,
        openedAt: Date,
        validBefore: Date
    ) throws {
        let duration = validBefore.timeIntervalSince(openedAt)
        let configurationSHA256: String
        do {
            configurationSHA256 =
                try configuration.machineConfigurationSHA256()
        } catch {
            throw InvestigationLifecycleTopologyCollectorError
                .invalidRequest
        }
        guard
            userID > 0,
            configuration.binding.isValid,
            configuration.validBefore >= validBefore,
            appProcessIdentity.processID > 1,
            appProcessIdentity.processIDVersion > 0,
            appProcessIdentity.auditSessionID > 0,
            appProcessIdentity.effectiveUserID == userID,
            openedAt.timeIntervalSince1970.isFinite,
            validBefore.timeIntervalSince1970.isFinite,
            duration > 0,
            duration
                <= LifecycleRootTopologyObservationWindow.maximumDuration
        else {
            throw InvestigationLifecycleTopologyCollectorError
                .invalidRequest
        }
        investigationID = LifecycleInvestigationID(
            rawValue: configuration.nonce
        )
        self.userID = userID
        scenario = configuration.scenario
        signedBinding = configuration.binding
        self.configurationSHA256 = configurationSHA256
        self.appProcessIdentity = appProcessIdentity
        self.openedAt = openedAt
        self.validBefore = validBefore
    }
}

protocol InvestigationLifecyclePostTeardownBindingReading: Sendable {
    func readBinding(
        signedBinding: SignedInvestigationRuntimeBinding
    ) throws -> LifecycleRootTopologyBinding
}

struct PostTeardownExpectedTopologyBindingReader:
    InvestigationLifecyclePostTeardownBindingReading,
    Sendable
{
    private let signingReader: LifecycleBundleSigningIdentityReader

    init(
        signingReader: LifecycleBundleSigningIdentityReader = .init()
    ) {
        self.signingReader = signingReader
    }

    func readBinding(
        signedBinding: SignedInvestigationRuntimeBinding
    ) throws -> LifecycleRootTopologyBinding {
        let contract = try LifecycleLocalInstallationContract()
        let appEvidence = try signingReader.evidence(
            bundleURL: contract.installedAppURL
        )
        let helperEvidence = try signingReader.evidence(
            bundleURL: contract.helperExecutableURL
        )
        let machineDriverEvidence = try signingReader.evidence(
            bundleURL: contract.machineDriverExecutableURL
        )
        guard
            signedBinding.isValid,
            signedBinding.appExecutableSHA256
                == appEvidence.executableSHA256,
            signedBinding.helperExecutableSHA256
                == helperEvidence.executableSHA256,
            signedBinding.appBundleIdentifier
                == contract.appBundleIdentifier,
            signedBinding.helperServiceIdentifier == contract.label,
            signedBinding.machineDriver.executableSHA256
                == machineDriverEvidence.executableSHA256,
            signedBinding.machineDriver.signingIdentifier
                == machineDriverEvidence.identity.signingIdentifier,
            signedBinding.machineDriver.designatedRequirementSHA256
                == machineDriverEvidence.identity
                    .designatedRequirementSHA256,
            signedBinding.machineDriver.codeDirectoryHash
                == machineDriverEvidence.identity.codeDirectoryHash,
            signedBinding.machineDriver.machineClaimServiceIdentifier
                == contract.machineClaimMachServiceName
        else {
            throw InvestigationLifecycleTopologyCollectorError
                .bindingMismatch
        }
        do {
            return try LifecycleRootTopologyBinding(
                appSigningEvidence: appEvidence,
                helperSigningEvidence: helperEvidence,
                machineDriverSigningEvidence: machineDriverEvidence,
                appBundleIdentifier: contract.appBundleIdentifier,
                helperServiceIdentifier: contract.label
            )
        } catch {
            throw InvestigationLifecycleTopologyCollectorError
                .bindingMismatch
        }
    }
}

protocol InvestigationLifecyclePostTeardownObserving: Sendable {
    func observePostTeardown(
        binding: LifecycleRootTopologyBinding,
        appProcessIdentity: LifecycleProcessIdentity,
        helperProcessIdentity: LifecycleProcessIdentity,
        window: LifecycleRootTopologyObservationWindow
    ) async throws -> LifecycleRootTopologyObservation
}

struct DarwinInvestigationLifecyclePostTeardownObserver:
    InvestigationLifecyclePostTeardownObserving,
    Sendable
{
    func observePostTeardown(
        binding: LifecycleRootTopologyBinding,
        appProcessIdentity: LifecycleProcessIdentity,
        helperProcessIdentity: LifecycleProcessIdentity,
        window: LifecycleRootTopologyObservationWindow
    ) async throws -> LifecycleRootTopologyObservation {
        try LifecycleRootTopologyObserver(
            serviceProbe: DarwinPostTeardownLifecycleServiceProbe()
        ).observe(
            LifecycleRootTopologyObservationRequest(
                binding: binding,
                appProcessIdentity: appProcessIdentity,
                helperProcessIdentity: helperProcessIdentity,
                window: window
            )
        )
    }
}

protocol InvestigationLifecycleTopologyTransitioning: Sendable {
    func transition() async throws
}

struct InvestigationLifecycleTopologyCohort: Sendable, Equatable {
    let investigationID: LifecycleInvestigationID
    let userID: UInt32
    let scenario: SignedInvestigationRuntimeDiagnosticScenario
    let signedBinding: SignedInvestigationRuntimeBinding
    let appProcessIdentity: LifecycleProcessIdentity
    let helperProcessIdentity: LifecycleProcessIdentity
    let helperAttestedAt: Date
    let lifecycleResidueObservation:
        LifecycleInvestigationResidueObservation
    let ownerRetirementObservation:
        LifecycleInteractiveWorkerRetirementObservation
    let postTeardownTopology: LifecycleRootTopologyObservation
    let observedAt: Date

    fileprivate init(
        request: InvestigationLifecycleTopologyCollectionRequest,
        retirementClaim: InvestigationMachineRetirementClaim,
        postTeardownTopology: LifecycleRootTopologyObservation
    ) {
        investigationID = request.investigationID
        userID = request.userID
        scenario = request.scenario
        signedBinding = request.signedBinding
        appProcessIdentity = request.appProcessIdentity
        helperProcessIdentity =
            retirementClaim.helperPeerIdentity
        helperAttestedAt = retirementClaim.helperPeerAttestedAt
        lifecycleResidueObservation =
            retirementClaim.residueObservation
        ownerRetirementObservation =
            retirementClaim.ownerRetirementObservation
        self.postTeardownTopology = postTeardownTopology
        observedAt = postTeardownTopology.observedAt
    }
}

actor InvestigationLifecycleTopologyCollector {
    private enum State {
        case ready
        case collecting
        case consumed
    }

    private let postTeardownObserver:
        any InvestigationLifecyclePostTeardownObserving
    private let expectedBindingReader:
        any InvestigationLifecyclePostTeardownBindingReading
    private let effectiveUserID: @Sendable () -> uid_t
    private let now: @Sendable () -> Date
    private var state = State.ready

    init(
        postTeardownObserver:
            any InvestigationLifecyclePostTeardownObserving,
        expectedBindingReader:
            any InvestigationLifecyclePostTeardownBindingReading,
        effectiveUserID: @escaping @Sendable () -> uid_t = geteuid,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.postTeardownObserver = postTeardownObserver
        self.expectedBindingReader = expectedBindingReader
        self.effectiveUserID = effectiveUserID
        self.now = now
    }

    func collect(
        request: InvestigationLifecycleTopologyCollectionRequest,
        retirementClaimStore:
            InvestigationMachineRetirementClaimStore,
        transition: any InvestigationLifecycleTopologyTransitioning
    ) async throws -> InvestigationLifecycleTopologyCohort {
        guard state == .ready else {
            throw InvestigationLifecycleTopologyCollectorError
                .collectorConsumed
        }
        state = .collecting
        defer { state = .consumed }

        try Task.checkCancellation()
        guard effectiveUserID() == 0 else {
            throw InvestigationLifecycleTopologyCollectorError
                .rootAuthorityRequired
        }
        let startedAt = now()
        try requireWindow(request, at: startedAt)
        let retirementClaim: InvestigationMachineRetirementClaim
        do {
            retirementClaim = try await retirementClaimStore.consume()
        } catch {
            throw InvestigationLifecycleTopologyCollectorError
                .retirementEvidenceMismatch
        }
        let topologyBinding: LifecycleRootTopologyBinding
        do {
            topologyBinding = try expectedBindingReader.readBinding(
                signedBinding: request.signedBinding
            )
        } catch {
            throw InvestigationLifecycleTopologyCollectorError
                .bindingMismatch
        }
        try validateRetirementClaim(
            retirementClaim,
            request: request,
            topologyBinding: topologyBinding
        )
        let window = try LifecycleRootTopologyObservationWindow(
            openedAt: request.openedAt,
            validBefore: request.validBefore
        )
        try Task.checkCancellation()
        guard effectiveUserID() == 0 else {
            throw InvestigationLifecycleTopologyCollectorError
                .rootAuthorityRequired
        }
        try requireWindow(request, at: now())
        do {
            try await transition.transition()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw InvestigationLifecycleTopologyCollectorError
                .transitionFailed
        }
        try Task.checkCancellation()
        guard state == .collecting else {
            throw InvestigationLifecycleTopologyCollectorError
                .collectorConsumed
        }
        guard effectiveUserID() == 0 else {
            throw InvestigationLifecycleTopologyCollectorError
                .rootAuthorityRequired
        }
        let transitionedAt = now()
        try requireWindow(request, at: transitionedAt)
        let post: LifecycleRootTopologyObservation
        do {
            post = try await postTeardownObserver.observePostTeardown(
                binding: topologyBinding,
                appProcessIdentity: request.appProcessIdentity,
                helperProcessIdentity:
                    retirementClaim.helperPeerIdentity,
                window: window
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw InvestigationLifecycleTopologyCollectorError
                .postTeardownTopologyUnproved
        }
        try Task.checkCancellation()
        guard state == .collecting else {
            throw InvestigationLifecycleTopologyCollectorError
                .collectorConsumed
        }
        guard
            post.provesPostTeardownTopology,
            post.binding == topologyBinding,
            post.appProcessIdentity == request.appProcessIdentity,
            post.helperProcessIdentity
                == retirementClaim.helperPeerIdentity,
            post.startedAt >= transitionedAt,
            post.observedAt >= post.startedAt,
            post.observedAt <= request.validBefore
        else {
            throw InvestigationLifecycleTopologyCollectorError
                .postTeardownTopologyUnproved
        }
        try requireWindow(request, at: post.observedAt)
        return InvestigationLifecycleTopologyCohort(
            request: request,
            retirementClaim: retirementClaim,
            postTeardownTopology: post
        )
    }

    private func validateRetirementClaim(
        _ claim: InvestigationMachineRetirementClaim,
        request: InvestigationLifecycleTopologyCollectionRequest,
        topologyBinding: LifecycleRootTopologyBinding
    ) throws {
        let residue = claim.residueObservation
        guard
            claim.request.handle.investigationID
                == request.investigationID,
            claim.configurationSHA256
                == request.configurationSHA256,
            claim.ownerRetirementObservation
                == .retiredOwnedResources,
            residue.investigationID == request.investigationID,
            residue.userID == request.userID,
            residue.provedEmpty,
            claim.helperPeerIdentity.processID > 1,
            claim.helperPeerIdentity.processIDVersion > 0,
            claim.helperPeerIdentity.effectiveUserID == 0,
            claim.helperPeerIdentity.auditSessionID
                == residue.auditSessionID,
            claim.helperPeerIdentity.processID
                != request.appProcessIdentity.processID,
            claim.appIdentity.processID
                == request.appProcessIdentity.processID,
            claim.appIdentity.processIDVersion
                == request.appProcessIdentity.processIDVersion,
            claim.appIdentity.auditSessionID
                == request.appProcessIdentity.auditSessionID,
            claim.appIdentity.effectiveUserID == request.userID,
            claim.appIdentity.auditTokenWords
                == request.appProcessIdentity.auditToken.words,
            claim.claimedAt <= request.openedAt,
            claim.request.validBefore >= request.openedAt,
            claim.request.validBefore >= claim.claimedAt,
            residue.observedAt <= claim.recordedAt,
            claim.recordedAt <= claim.request.issuedAt,
            claim.request.issuedAt <= claim.claimedAt,
            residue.observedAt <= request.validBefore,
            topologyBinding.appSigningEvidence.executableSHA256
                == request.signedBinding.appExecutableSHA256,
            topologyBinding.helperSigningEvidence.executableSHA256
                == request.signedBinding.helperExecutableSHA256,
            topologyBinding.machineDriverSigningEvidence
                .executableSHA256
                == request.signedBinding.machineDriver.executableSHA256,
            topologyBinding.machineDriverSigningEvidence.identity
                .signingIdentifier
                == request.signedBinding.machineDriver.signingIdentifier,
            topologyBinding.machineDriverSigningEvidence.identity
                .designatedRequirementSHA256
                == request.signedBinding.machineDriver
                    .designatedRequirementSHA256,
            topologyBinding.machineDriverSigningEvidence.identity
                .codeDirectoryHash
                == request.signedBinding.machineDriver.codeDirectoryHash,
            request.signedBinding.machineDriver
                .machineClaimServiceIdentifier
                == SignedInvestigationRuntimeMachineDriverBinding
                    .requiredMachineClaimServiceIdentifier,
            topologyBinding.appBundleIdentifier
                == request.signedBinding.appBundleIdentifier,
            topologyBinding.helperServiceIdentifier
                == request.signedBinding.helperServiceIdentifier
        else {
            throw InvestigationLifecycleTopologyCollectorError
                .retirementEvidenceMismatch
        }
    }

    private func requireWindow(
        _ request: InvestigationLifecycleTopologyCollectionRequest,
        at date: Date
    ) throws {
        guard
            date >= request.openedAt,
            date <= request.validBefore
        else {
            throw InvestigationLifecycleTopologyCollectorError
                .observationOutsideWindow
        }
    }
}
