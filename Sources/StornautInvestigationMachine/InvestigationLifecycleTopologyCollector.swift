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
    case installedTopologyUnproved
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

protocol InvestigationLifecycleTopologyBindingReading: Sendable {
    func readBinding(
        signedBinding: SignedInvestigationRuntimeBinding
    ) throws -> LifecycleRootTopologyBinding
}

struct InstalledLifecycleTopologyBindingReader:
    InvestigationLifecycleTopologyBindingReading,
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
        guard
            signedBinding.isValid,
            signedBinding.appExecutableSHA256
                == appEvidence.executableSHA256,
            signedBinding.helperExecutableSHA256
                == helperEvidence.executableSHA256,
            signedBinding.appBundleIdentifier
                == contract.appBundleIdentifier,
            signedBinding.helperServiceIdentifier == contract.label
        else {
            throw InvestigationLifecycleTopologyCollectorError
                .bindingMismatch
        }
        do {
            return try LifecycleRootTopologyBinding(
                appSigningEvidence: appEvidence,
                helperSigningEvidence: helperEvidence,
                appBundleIdentifier: contract.appBundleIdentifier,
                helperServiceIdentifier: contract.label
            )
        } catch {
            throw InvestigationLifecycleTopologyCollectorError
                .bindingMismatch
        }
    }
}

protocol InvestigationLifecycleTopologyObserving: Sendable {
    func observe(
        _ request: LifecycleRootTopologyObservationRequest
    ) async throws -> LifecycleRootTopologyObservation
}

struct DarwinInvestigationLifecycleTopologyObserver:
    InvestigationLifecycleTopologyObserving,
    Sendable
{
    private let expectedHelperIdentity: LifecycleProcessIdentity

    init(expectedHelperIdentity: LifecycleProcessIdentity) {
        self.expectedHelperIdentity = expectedHelperIdentity
    }

    func observe(
        _ request: LifecycleRootTopologyObservationRequest
    ) async throws -> LifecycleRootTopologyObservation {
        try LifecycleRootTopologyObserver(
            serviceProbe: DarwinFixedLifecycleServiceProbe(
                expectedIdentity: expectedHelperIdentity
            )
        ).observe(request)
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
    let installedTopology: LifecycleRootTopologyObservation
    let postTeardownTopology: LifecycleRootTopologyObservation
    let observedAt: Date

    fileprivate init(
        request: InvestigationLifecycleTopologyCollectionRequest,
        retirementClaim: InvestigationMachineRetirementClaim,
        installedTopology: LifecycleRootTopologyObservation,
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
        self.installedTopology = installedTopology
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

    private let topologyObserver:
        any InvestigationLifecycleTopologyObserving
    private let bindingReader:
        any InvestigationLifecycleTopologyBindingReading
    private let effectiveUserID: @Sendable () -> uid_t
    private let now: @Sendable () -> Date
    private var state = State.ready

    init(
        topologyObserver: any InvestigationLifecycleTopologyObserving,
        bindingReader: any InvestigationLifecycleTopologyBindingReading,
        effectiveUserID: @escaping @Sendable () -> uid_t = geteuid,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.topologyObserver = topologyObserver
        self.bindingReader = bindingReader
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
            topologyBinding = try bindingReader.readBinding(
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
        let installedRequest = try LifecycleRootTopologyObservationRequest(
            phase: .installed,
            binding: topologyBinding,
            appProcessIdentity: request.appProcessIdentity,
            helperProcessIdentity:
                retirementClaim.helperPeerIdentity,
            window: window
        )
        let installed: LifecycleRootTopologyObservation
        do {
            installed = try await topologyObserver.observe(
                installedRequest
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw InvestigationLifecycleTopologyCollectorError
                .installedTopologyUnproved
        }
        try Task.checkCancellation()
        guard
            state == .collecting,
            installed.provesInstalledTopology,
            installed.binding == topologyBinding,
            installed.appProcessIdentity == request.appProcessIdentity,
            installed.helperProcessIdentity
                == retirementClaim.helperPeerIdentity,
            installed.startedAt >= request.openedAt,
            installed.observedAt >= installed.startedAt,
            installed.observedAt <= request.validBefore,
            retirementClaim.residueObservation.observedAt
                <= retirementClaim.recordedAt,
            retirementClaim.recordedAt
                <= retirementClaim.request.issuedAt,
            retirementClaim.request.issuedAt
                <= retirementClaim.claimedAt,
            retirementClaim.claimedAt <= installed.startedAt
        else {
            throw InvestigationLifecycleTopologyCollectorError
                .installedTopologyUnproved
        }
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
        try requireWindow(request, at: now())
        let postRequest = try LifecycleRootTopologyObservationRequest(
            phase: .postTeardown,
            binding: topologyBinding,
            appProcessIdentity: request.appProcessIdentity,
            helperProcessIdentity:
                retirementClaim.helperPeerIdentity,
            window: window
        )
        let post: LifecycleRootTopologyObservation
        do {
            post = try await topologyObserver.observe(postRequest)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw InvestigationLifecycleTopologyCollectorError
                .postTeardownTopologyUnproved
        }
        try Task.checkCancellation()
        guard
            state == .collecting,
            post.provesPostTeardownTopology,
            post.binding == topologyBinding,
            post.appProcessIdentity == request.appProcessIdentity,
            post.helperProcessIdentity
                == retirementClaim.helperPeerIdentity,
            post.startedAt >= installed.observedAt,
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
            installedTopology: installed,
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
            residue.observedAt <= request.validBefore,
            topologyBinding.appSigningEvidence.executableSHA256
                == request.signedBinding.appExecutableSHA256,
            topologyBinding.helperSigningEvidence.executableSHA256
                == request.signedBinding.helperExecutableSHA256,
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
