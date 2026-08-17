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
    let appProcessIdentity: LifecycleProcessIdentity
    let openedAt: Date
    let validBefore: Date

    init(
        investigationID: LifecycleInvestigationID,
        userID: UInt32,
        scenario: SignedInvestigationRuntimeDiagnosticScenario = .success,
        signedBinding: SignedInvestigationRuntimeBinding,
        appProcessIdentity: LifecycleProcessIdentity,
        openedAt: Date,
        validBefore: Date
    ) throws {
        let duration = validBefore.timeIntervalSince(openedAt)
        guard
            userID > 0,
            signedBinding.isValid,
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
        self.investigationID = investigationID
        self.userID = userID
        self.scenario = scenario
        self.signedBinding = signedBinding
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
    let installedTopology: LifecycleRootTopologyObservation
    let postTeardownTopology: LifecycleRootTopologyObservation
    let observedAt: Date

    fileprivate init(
        request: InvestigationLifecycleTopologyCollectionRequest,
        retirementEvidence: InvestigationLifecycleRetirementEvidence,
        installedTopology: LifecycleRootTopologyObservation,
        postTeardownTopology: LifecycleRootTopologyObservation
    ) {
        investigationID = request.investigationID
        userID = request.userID
        scenario = request.scenario
        signedBinding = request.signedBinding
        appProcessIdentity = request.appProcessIdentity
        helperProcessIdentity =
            retirementEvidence.helperProcessIdentity
        helperAttestedAt = retirementEvidence.helperAttestedAt
        lifecycleResidueObservation =
            retirementEvidence.residueObservation
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
        retirementEvidenceStore:
            InvestigationLifecycleRetirementEvidenceStore,
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
        guard let retirementEvidence =
            await retirementEvidenceStore.consume()
        else {
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
        try validateRetirementEvidence(
            retirementEvidence,
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
                retirementEvidence.helperProcessIdentity,
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
                == retirementEvidence.helperProcessIdentity,
            installed.startedAt >= request.openedAt,
            installed.observedAt >= installed.startedAt,
            installed.observedAt <= request.validBefore,
            retirementEvidence.helperAttestedAt
                <= retirementEvidence.residueObservation.observedAt,
            retirementEvidence.residueObservation.observedAt
                <= installed.startedAt
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
                retirementEvidence.helperProcessIdentity,
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
                == retirementEvidence.helperProcessIdentity,
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
            retirementEvidence: retirementEvidence,
            installedTopology: installed,
            postTeardownTopology: post
        )
    }

    private func validateRetirementEvidence(
        _ evidence: InvestigationLifecycleRetirementEvidence,
        request: InvestigationLifecycleTopologyCollectionRequest,
        topologyBinding: LifecycleRootTopologyBinding
    ) throws {
        let residue = evidence.residueObservation
        guard
            residue.investigationID == request.investigationID,
            residue.userID == request.userID,
            residue.provedEmpty,
            evidence.helperProcessIdentity.processID > 1,
            evidence.helperProcessIdentity.processIDVersion > 0,
            evidence.helperProcessIdentity.effectiveUserID == 0,
            evidence.helperProcessIdentity.auditSessionID
                == residue.auditSessionID,
            evidence.helperProcessIdentity.processID
                != request.appProcessIdentity.processID,
            evidence.helperAttestedAt >= request.openedAt,
            evidence.helperAttestedAt <= residue.observedAt,
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
