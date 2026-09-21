import Darwin
import Foundation

package enum LifecycleRootTopologyArtifactRole:
    Sendable,
    Hashable,
    CaseIterable
{
    case installedRoot
    case installedApp
    case appExecutable
    case helperExecutable
    case machineDriverExecutable
    case launchDaemonPlist
    case runtimeRoot
    case leaseRoot
}

package enum LifecycleRootTopologyArtifactObservation: Sendable, Equatable {
    case absent
    case present
    case unavailable(reasonKey: String)
}

package enum LifecycleRootTopologyServiceProbeResult: Sendable, Equatable {
    case absent
    case unavailable(reasonKey: String)
}

package enum LifecycleRootTopologyServiceObservation: Sendable, Equatable {
    case absent
    case unavailable(reasonKey: String)
}

package enum LifecycleRootTopologyProcessObservation: Sendable, Equatable {
    case absent
    case sameIdentityAlive
    case identityReused
    case unresolved(reasonKey: String)
}

protocol LifecycleRootTopologyArtifactAbsenceReading: Sendable {
    func observeAbsence(
        _ role: LifecycleRootTopologyArtifactRole,
        contract: LifecycleLocalInstallationContract
    ) -> LifecycleRootTopologyArtifactObservation
}

protocol LifecycleRootTopologyProcessAbsenceReading: Sendable {
    func observeAbsence(
        of expectedIdentity: LifecycleProcessIdentity
    ) -> LifecycleRootTopologyProcessObservation
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
    package let appProcessIdentity: LifecycleProcessIdentity
    package let helperProcessIdentity: LifecycleProcessIdentity
    package let window: LifecycleRootTopologyObservationWindow

    package init(
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
        self.appProcessIdentity = appProcessIdentity
        self.helperProcessIdentity = helperProcessIdentity
        self.window = window
    }
}

package struct LifecycleRootTopologyObservation: Sendable, Equatable {
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
        self.appProcessIdentity = appProcessIdentity
        self.helperProcessIdentity = helperProcessIdentity
        self.artifacts = artifacts
        self.appProcess = appProcess
        self.helperProcess = helperProcess
        self.service = service
        self.startedAt = startedAt
        self.observedAt = observedAt
    }

    package var provesPostTeardownTopology: Bool {
        postTeardownContractSatisfied
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
    private let artifactReader:
        any LifecycleRootTopologyArtifactAbsenceReading
    private let processReader:
        any LifecycleRootTopologyProcessAbsenceReading
    private let serviceProbe: any LifecycleRootTopologyServiceProbing
    private let now: @Sendable () -> Date

    init(
        artifactReader: any LifecycleRootTopologyArtifactAbsenceReading,
        processReader: any LifecycleRootTopologyProcessAbsenceReading,
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
            artifactReader: DarwinRootTopologyArtifactAbsenceReader(),
            processReader: DarwinRootTopologyProcessAbsenceReader(),
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
        let artifacts = Dictionary(
            uniqueKeysWithValues:
                LifecycleRootTopologyArtifactRole.allCases.map { role in
                    (
                        role,
                        artifactReader.observeAbsence(
                            role,
                            contract: contract
                        )
                    )
                }
        )
        let appProcess = processReader.observeAbsence(
            of: request.appProcessIdentity
        )
        let helperProcess = processReader.observeAbsence(
            of: request.helperProcessIdentity
        )
        let service = classify(
            serviceProbe.observeFixedService(label: contract.label)
        )
        let observedAt = now()
        guard request.window.contains(observedAt), observedAt >= startedAt else {
            throw LifecycleRootTopologyObservationError
                .observationOutsideWindow
        }

        return LifecycleRootTopologyObservation(
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
        _ result: LifecycleRootTopologyServiceProbeResult
    ) -> LifecycleRootTopologyServiceObservation {
        switch result {
        case .absent:
            return .absent
        case let .unavailable(reasonKey):
            return .unavailable(reasonKey: reasonKey)
        }
    }
}

private extension LifecycleRootTopologyProcessObservation {
    var provesOriginalIdentityAbsent: Bool {
        self == .absent || self == .identityReused
    }
}
