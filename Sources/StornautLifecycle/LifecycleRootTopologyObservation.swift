import Darwin
import Foundation

package enum LifecycleRootTopologyPhase: Sendable, Equatable, CaseIterable {
    case installed
    case postTeardown
}

package enum LifecycleRootTopologyArtifactRole:
    Sendable,
    Hashable,
    CaseIterable
{
    case installedRoot
    case installedApp
    case appExecutable
    case helperExecutable
    case launchDaemonPlist
    case runtimeRoot
    case leaseRoot
}

package enum LifecycleRootTopologyArtifactObservation: Sendable, Equatable {
    case absent
    case presentValid
    case invalid(reasonKey: String)
    case unavailable(reasonKey: String)
}

package enum LifecycleRootTopologyServiceProbeResult: Sendable, Equatable {
    case absent
    case loaded(identity: LifecycleProcessIdentity)
    case unavailable(reasonKey: String)
}

package enum LifecycleRootTopologyServiceObservation: Sendable, Equatable {
    case absent
    case loadedValid
    case invalid(reasonKey: String)
    case unavailable(reasonKey: String)
}

package enum LifecycleRootTopologyProcessObservation: Sendable, Equatable {
    case absent
    case sameIdentityAlive
    case identityReused
    case unresolved(reasonKey: String)
}

struct LifecycleRootTopologyProcessSnapshot: Sendable, Equatable {
    let identity: LifecycleProcessIdentity
    let executableURL: URL
    let signingIdentity: LifecycleSigningIdentity
}

enum LifecycleRootTopologyProcessReadResult: Sendable, Equatable {
    case absent
    case identityReused
    case observed(LifecycleRootTopologyProcessSnapshot)
    case unresolved(reasonKey: String)
}

protocol LifecycleRootTopologyArtifactReading: Sendable {
    func observe(
        _ role: LifecycleRootTopologyArtifactRole,
        contract: LifecycleLocalInstallationContract,
        binding: LifecycleRootTopologyBinding
    ) -> LifecycleRootTopologyArtifactObservation
}

protocol LifecycleRootTopologyProcessReading: Sendable {
    func read(processID: pid_t) -> LifecycleRootTopologyProcessReadResult
}

package protocol LifecycleRootTopologyServiceProbing: Sendable {
    func observeFixedService(
        label: String
    ) -> LifecycleRootTopologyServiceProbeResult
}

package enum LifecycleRootTopologyObservationError:
    Error,
    Sendable,
    Equatable
{
    case invalidRequest
    case observationOutsideWindow
}

package struct LifecycleRootTopologyBinding: Sendable, Equatable {
    package let appSigningEvidence: LifecycleBundleSigningEvidence
    package let helperSigningEvidence: LifecycleBundleSigningEvidence
    package let appBundleIdentifier: String
    package let helperServiceIdentifier: String

    package init(
        appSigningEvidence: LifecycleBundleSigningEvidence,
        helperSigningEvidence: LifecycleBundleSigningEvidence,
        appBundleIdentifier: String,
        helperServiceIdentifier: String
    ) throws {
        guard
            appSigningEvidence.identity.signingIdentifier
                == appBundleIdentifier,
            helperSigningEvidence.identity.signingIdentifier
                == helperServiceIdentifier + ".helper",
            appSigningEvidence.identity != helperSigningEvidence.identity,
            rootTopologyIdentifier(appBundleIdentifier),
            rootTopologyIdentifier(helperServiceIdentifier)
        else {
            throw LifecycleRootTopologyObservationError.invalidRequest
        }
        self.appSigningEvidence = appSigningEvidence
        self.helperSigningEvidence = helperSigningEvidence
        self.appBundleIdentifier = appBundleIdentifier
        self.helperServiceIdentifier = helperServiceIdentifier
    }
}

package struct LifecycleRootTopologyObservationWindow: Sendable, Equatable {
    package static let maximumDuration: TimeInterval = 60

    package let openedAt: Date
    package let validBefore: Date

    package init(openedAt: Date, validBefore: Date) throws {
        let duration = validBefore.timeIntervalSince(openedAt)
        guard
            openedAt.timeIntervalSinceReferenceDate.isFinite,
            validBefore.timeIntervalSinceReferenceDate.isFinite,
            duration > 0,
            duration <= Self.maximumDuration
        else {
            throw LifecycleRootTopologyObservationError.invalidRequest
        }
        self.openedAt = openedAt
        self.validBefore = validBefore
    }

    func contains(_ date: Date) -> Bool {
        date >= openedAt && date <= validBefore
    }
}

package struct LifecycleRootTopologyObservationRequest: Sendable, Equatable {
    package let phase: LifecycleRootTopologyPhase
    package let binding: LifecycleRootTopologyBinding
    package let appProcessIdentity: LifecycleProcessIdentity
    package let helperProcessIdentity: LifecycleProcessIdentity
    package let window: LifecycleRootTopologyObservationWindow

    package init(
        phase: LifecycleRootTopologyPhase,
        binding: LifecycleRootTopologyBinding,
        appProcessIdentity: LifecycleProcessIdentity,
        helperProcessIdentity: LifecycleProcessIdentity,
        window: LifecycleRootTopologyObservationWindow
    ) throws {
        guard
            appProcessIdentity.processID > 1,
            appProcessIdentity.processIDVersion > 0,
            appProcessIdentity.auditSessionID > 0,
            appProcessIdentity.effectiveUserID > 0,
            helperProcessIdentity.processID > 1,
            helperProcessIdentity.processIDVersion > 0,
            helperProcessIdentity.auditSessionID > 0,
            helperProcessIdentity.effectiveUserID == 0,
            appProcessIdentity.processID != helperProcessIdentity.processID,
            appProcessIdentity != helperProcessIdentity
        else {
            throw LifecycleRootTopologyObservationError.invalidRequest
        }
        self.phase = phase
        self.binding = binding
        self.appProcessIdentity = appProcessIdentity
        self.helperProcessIdentity = helperProcessIdentity
        self.window = window
    }
}

package struct LifecycleRootTopologyObservation: Sendable, Equatable {
    package let phase: LifecycleRootTopologyPhase
    package let binding: LifecycleRootTopologyBinding
    package let appProcessIdentity: LifecycleProcessIdentity
    package let helperProcessIdentity: LifecycleProcessIdentity
    package let artifacts: [
        LifecycleRootTopologyArtifactRole:
            LifecycleRootTopologyArtifactObservation
    ]
    package let appProcess: LifecycleRootTopologyProcessObservation
    package let helperProcess: LifecycleRootTopologyProcessObservation
    package let service: LifecycleRootTopologyServiceObservation
    package let startedAt: Date
    package let observedAt: Date

    fileprivate init(
        phase: LifecycleRootTopologyPhase,
        binding: LifecycleRootTopologyBinding,
        appProcessIdentity: LifecycleProcessIdentity,
        helperProcessIdentity: LifecycleProcessIdentity,
        artifacts: [
            LifecycleRootTopologyArtifactRole:
                LifecycleRootTopologyArtifactObservation
        ],
        appProcess: LifecycleRootTopologyProcessObservation,
        helperProcess: LifecycleRootTopologyProcessObservation,
        service: LifecycleRootTopologyServiceObservation,
        startedAt: Date,
        observedAt: Date
    ) {
        self.phase = phase
        self.binding = binding
        self.appProcessIdentity = appProcessIdentity
        self.helperProcessIdentity = helperProcessIdentity
        self.artifacts = artifacts
        self.appProcess = appProcess
        self.helperProcess = helperProcess
        self.service = service
        self.startedAt = startedAt
        self.observedAt = observedAt
    }

    package var provesInstalledTopology: Bool {
        phase == .installed && installedContractSatisfied
    }

    package var provesPostTeardownTopology: Bool {
        phase == .postTeardown && postTeardownContractSatisfied
    }

    package var satisfiesPhaseContract: Bool {
        provesInstalledTopology || provesPostTeardownTopology
    }

    private var installedContractSatisfied: Bool {
        let required: [LifecycleRootTopologyArtifactRole] = [
            .installedRoot,
            .installedApp,
            .appExecutable,
            .helperExecutable,
            .launchDaemonPlist,
        ]
        return required.allSatisfy { artifacts[$0] == .presentValid }
            && [.runtimeRoot, .leaseRoot].allSatisfy {
                artifacts[$0] == .presentValid || artifacts[$0] == .absent
            }
            && appProcess == .sameIdentityAlive
            && helperProcess == .sameIdentityAlive
            && service == .loadedValid
    }

    private var postTeardownContractSatisfied: Bool {
        LifecycleRootTopologyArtifactRole.allCases.allSatisfy {
            artifacts[$0] == .absent
        }
            && appProcess.provesOriginalIdentityAbsent
            && helperProcess.provesOriginalIdentityAbsent
            && service == .absent
    }
}

package struct LifecycleRootTopologyObserver: Sendable {
    private let artifactReader: any LifecycleRootTopologyArtifactReading
    private let processReader: any LifecycleRootTopologyProcessReading
    private let serviceProbe: any LifecycleRootTopologyServiceProbing
    private let now: @Sendable () -> Date

    init(
        artifactReader: any LifecycleRootTopologyArtifactReading,
        processReader: any LifecycleRootTopologyProcessReading,
        serviceProbe: any LifecycleRootTopologyServiceProbing,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.artifactReader = artifactReader
        self.processReader = processReader
        self.serviceProbe = serviceProbe
        self.now = now
    }

    package init(
        serviceProbe: any LifecycleRootTopologyServiceProbing
    ) {
        self.init(
            artifactReader: DarwinRootTopologyArtifactReader(),
            processReader: DarwinRootTopologyProcessReader(),
            serviceProbe: serviceProbe
        )
    }

    package func observe(
        _ request: LifecycleRootTopologyObservationRequest
    ) throws -> LifecycleRootTopologyObservation {
        let startedAt = now()
        guard request.window.contains(startedAt) else {
            throw LifecycleRootTopologyObservationError
                .observationOutsideWindow
        }
        let contract = try LifecycleLocalInstallationContract()
        guard request.binding.matches(contract) else {
            throw LifecycleRootTopologyObservationError.invalidRequest
        }

        let artifacts = Dictionary(
            uniqueKeysWithValues:
                LifecycleRootTopologyArtifactRole.allCases.map { role in
                    (
                        role,
                        artifactReader.observe(
                            role,
                            contract: contract,
                            binding: request.binding
                        )
                    )
                }
        )
        let appProcess = classify(
            processReader.read(
                processID: request.appProcessIdentity.processID
            ),
            expectedIdentity: request.appProcessIdentity,
            expectedExecutableURL: contract.appExecutableURL,
            expectedSigningIdentity:
                request.binding.appSigningEvidence.identity
        )
        let helperProcess = classify(
            processReader.read(
                processID: request.helperProcessIdentity.processID
            ),
            expectedIdentity: request.helperProcessIdentity,
            expectedExecutableURL: contract.helperExecutableURL,
            expectedSigningIdentity:
                request.binding.helperSigningEvidence.identity
        )
        let service = classify(
            serviceProbe.observeFixedService(label: contract.label),
            expectedIdentity: request.helperProcessIdentity
        )
        let observedAt = now()
        guard request.window.contains(observedAt), observedAt >= startedAt else {
            throw LifecycleRootTopologyObservationError
                .observationOutsideWindow
        }

        return LifecycleRootTopologyObservation(
            phase: request.phase,
            binding: request.binding,
            appProcessIdentity: request.appProcessIdentity,
            helperProcessIdentity: request.helperProcessIdentity,
            artifacts: artifacts,
            appProcess: appProcess,
            helperProcess: helperProcess,
            service: service,
            startedAt: startedAt,
            observedAt: observedAt
        )
    }

    private func classify(
        _ result: LifecycleRootTopologyProcessReadResult,
        expectedIdentity: LifecycleProcessIdentity,
        expectedExecutableURL: URL,
        expectedSigningIdentity: LifecycleSigningIdentity
    ) -> LifecycleRootTopologyProcessObservation {
        switch result {
        case .absent:
            return .absent
        case .identityReused:
            return .identityReused
        case let .unresolved(reasonKey):
            return .unresolved(reasonKey: reasonKey)
        case let .observed(snapshot):
            guard snapshot.identity.processID == expectedIdentity.processID else {
                return .unresolved(
                    reasonKey: "runtime.topology.process-binding-mismatch"
                )
            }
            guard snapshot.identity == expectedIdentity else {
                return .identityReused
            }
            guard
                snapshot.executableURL.standardizedFileURL
                    == expectedExecutableURL.standardizedFileURL,
                snapshot.signingIdentity == expectedSigningIdentity
            else {
                return .unresolved(
                    reasonKey: "runtime.topology.process-binding-mismatch"
                )
            }
            return .sameIdentityAlive
        }
    }

    private func classify(
        _ result: LifecycleRootTopologyServiceProbeResult,
        expectedIdentity: LifecycleProcessIdentity
    ) -> LifecycleRootTopologyServiceObservation {
        switch result {
        case .absent:
            return .absent
        case let .loaded(identity):
            guard identity == expectedIdentity else {
                return .invalid(
                    reasonKey:
                        "runtime.topology.service-identity-mismatch"
                )
            }
            return .loadedValid
        case let .unavailable(reasonKey):
            return .unavailable(reasonKey: reasonKey)
        }
    }
}

private extension LifecycleRootTopologyBinding {
    func matches(_ contract: LifecycleLocalInstallationContract) -> Bool {
        appBundleIdentifier == contract.appBundleIdentifier
            && helperServiceIdentifier == contract.label
            && appSigningEvidence.identity.signingIdentifier
                == contract.appBundleIdentifier
            && helperSigningEvidence.identity.signingIdentifier
                == contract.helperSigningIdentifier
    }
}

private extension LifecycleRootTopologyProcessObservation {
    var provesOriginalIdentityAbsent: Bool {
        self == .absent || self == .identityReused
    }
}

private func rootTopologyIdentifier(_ value: String) -> Bool {
    !value.isEmpty
        && value.utf8.count <= 256
        && value.unicodeScalars.allSatisfy {
            (0x30...0x39).contains($0.value)
                || (0x41...0x5A).contains($0.value)
                || (0x61...0x7A).contains($0.value)
                || $0.value == 0x2D
                || $0.value == 0x2E
                || $0.value == 0x5F
        }
}
