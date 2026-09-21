import Foundation
import StornautInvestigationHandoffContract

package enum InvestigationInstalledL2ArtifactRole:
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

package enum InvestigationInstalledL2ArtifactObservation:
    Sendable,
    Equatable
{
    case absent
    case presentValid
    case invalid
    case unavailable
}

package struct InvestigationInstalledL2SigningIdentity:
    Sendable,
    Equatable
{
    package let signingIdentifier: String
    package let designatedRequirementSHA256: InvestigationHandoffSHA256
    package let codeDirectoryHash: Data
    package let isAdHoc: Bool

    package init(
        signingIdentifier: String,
        designatedRequirementSHA256: InvestigationHandoffSHA256,
        codeDirectoryHash: Data,
        isAdHoc: Bool
    ) throws {
        guard
            Self.validIdentifier(signingIdentifier),
            codeDirectoryHash.count == 20 || codeDirectoryHash.count == 32
        else {
            throw InvestigationInstalledL2SemanticError.invalidValue
        }
        self.signingIdentifier = signingIdentifier
        self.designatedRequirementSHA256 = designatedRequirementSHA256
        self.codeDirectoryHash = codeDirectoryHash
        self.isAdHoc = isAdHoc
    }

    private static func validIdentifier(_ value: String) -> Bool {
        !value.isEmpty
            && value.utf8.count <= 256
            && value.unicodeScalars.allSatisfy { scalar in
                (0x30...0x39).contains(scalar.value)
                    || (0x41...0x5A).contains(scalar.value)
                    || (0x61...0x7A).contains(scalar.value)
                    || scalar.value == 0x2D
                    || scalar.value == 0x2E
                    || scalar.value == 0x5F
            }
    }
}

package struct InvestigationInstalledL2ProcessEvidence:
    Sendable,
    Equatable
{
    package let identity: InvestigationMachineProcessIdentity
    package let executableSHA256: InvestigationHandoffSHA256
    package let staticSigning: InvestigationInstalledL2SigningIdentity
    package let liveSigning: InvestigationInstalledL2SigningIdentity

    package init(
        identity: InvestigationMachineProcessIdentity,
        executableSHA256: InvestigationHandoffSHA256,
        staticSigning: InvestigationInstalledL2SigningIdentity,
        liveSigning: InvestigationInstalledL2SigningIdentity
    ) throws {
        guard staticSigning == liveSigning else {
            throw InvestigationInstalledL2SemanticError.invalidValue
        }
        self.identity = identity
        self.executableSHA256 = executableSHA256
        self.staticSigning = staticSigning
        self.liveSigning = liveSigning
    }
}

package struct InvestigationInstalledL2MachineDriverEvidence:
    Sendable,
    Equatable
{
    package let executableSHA256: InvestigationHandoffSHA256
    package let staticSigning: InvestigationInstalledL2SigningIdentity
    package let liveSigning: InvestigationInstalledL2SigningIdentity

    package init(
        executableSHA256: InvestigationHandoffSHA256,
        staticSigning: InvestigationInstalledL2SigningIdentity,
        liveSigning: InvestigationInstalledL2SigningIdentity
    ) throws {
        guard staticSigning == liveSigning else {
            throw InvestigationInstalledL2SemanticError.invalidValue
        }
        self.executableSHA256 = executableSHA256
        self.staticSigning = staticSigning
        self.liveSigning = liveSigning
    }
}

package enum InvestigationInstalledL2ServiceObservation:
    Sendable,
    Equatable
{
    case absent
    case loaded(identity: InvestigationMachineProcessIdentity)
    case unavailable
}

package enum InvestigationInstalledL2SemanticError:
    Error,
    Sendable,
    Equatable
{
    case invalidValue
    case installedContractUnproved
}

package struct InvestigationInstalledL2SemanticObservation:
    Sendable,
    Equatable
{
    package let projectionSHA256: InvestigationHandoffSHA256
    package let epochUUID: UUID
    package let configurationNonce: UUID
    package let artifacts: [
        InvestigationInstalledL2ArtifactRole:
            InvestigationInstalledL2ArtifactObservation
    ]
    package let app: InvestigationInstalledL2ProcessEvidence
    package let helper: InvestigationInstalledL2ProcessEvidence
    package let machineDriver: InvestigationInstalledL2MachineDriverEvidence
    package let service: InvestigationInstalledL2ServiceObservation
    package let started: InvestigationInstalledL2ClockSample
    package let observed: InvestigationInstalledL2ClockSample

    package var appIdentity: InvestigationMachineProcessIdentity { app.identity }
    package var helperIdentity: InvestigationMachineProcessIdentity { helper.identity }

    package init(
        projection: InvestigationInstalledL2IdentityProjection,
        artifacts: [
            InvestigationInstalledL2ArtifactRole:
                InvestigationInstalledL2ArtifactObservation
        ],
        app: InvestigationInstalledL2ProcessEvidence,
        helper: InvestigationInstalledL2ProcessEvidence,
        machineDriver: InvestigationInstalledL2MachineDriverEvidence,
        service: InvestigationInstalledL2ServiceObservation,
        started: InvestigationInstalledL2ClockSample,
        observed: InvestigationInstalledL2ClockSample
    ) {
        projectionSHA256 = projection.projectionSHA256
        epochUUID = projection.epochUUID
        configurationNonce = projection.configurationNonce
        self.artifacts = artifacts
        self.app = app
        self.helper = helper
        self.machineDriver = machineDriver
        self.service = service
        self.started = started
        self.observed = observed
    }
}

package enum InvestigationInstalledL2SemanticContract {
    package static func evaluate(
        projection: InvestigationInstalledL2IdentityProjection,
        artifacts: [
            InvestigationInstalledL2ArtifactRole:
                InvestigationInstalledL2ArtifactObservation
        ],
        app: InvestigationInstalledL2ProcessEvidence,
        helper: InvestigationInstalledL2ProcessEvidence,
        machineDriver: InvestigationInstalledL2MachineDriverEvidence,
        service: InvestigationInstalledL2ServiceObservation,
        started: InvestigationInstalledL2ClockSample,
        observed: InvestigationInstalledL2ClockSample
    ) throws -> InvestigationInstalledL2SemanticObservation {
        let allRoles = Set(InvestigationInstalledL2ArtifactRole.allCases)
        guard Set(artifacts.keys) == allRoles else {
            throw InvestigationInstalledL2SemanticError.invalidValue
        }

        let required: [InvestigationInstalledL2ArtifactRole] = [
            .installedRoot, .installedApp, .appExecutable, .helperExecutable,
            .machineDriverExecutable, .launchDaemonPlist,
        ]
        guard
            required.allSatisfy({ artifacts[$0] == .presentValid }),
            [InvestigationInstalledL2ArtifactRole.runtimeRoot, .leaseRoot]
                .allSatisfy({
                    artifacts[$0] == .presentValid || artifacts[$0] == .absent
                }),
            app.identity.role == .app,
            helper.identity.role == .helper,
            app.identity != helper.identity,
            app.identity.processID != helper.identity.processID,
            app.staticSigning == app.liveSigning,
            helper.staticSigning == helper.liveSigning,
            app.executableSHA256 == projection.appExecutableSHA256,
            helper.executableSHA256 == projection.helperExecutableSHA256,
            machineDriver.executableSHA256
                == projection.machineDriverExecutableSHA256,
            app.staticSigning.signingIdentifier
                == projection.appBundleIdentifier,
            helper.staticSigning.signingIdentifier
                == projection.helperServiceIdentifier + ".helper",
            machineDriver.staticSigning == machineDriver.liveSigning,
            machineDriver.staticSigning.signingIdentifier
                == projection.machineDriverSigningIdentifier,
            machineDriver.staticSigning.designatedRequirementSHA256
                == projection.machineDriverDesignatedRequirementSHA256,
            machineDriver.staticSigning.codeDirectoryHash
                == projection.machineDriverCodeDirectoryHash,
            machineDriver.staticSigning.isAdHoc,
            service == .loaded(identity: helper.identity),
            started.wallUTC <= observed.wallUTC,
            observed.wallUTC < projection.configurationValidBefore,
            started.continuousNanoseconds <= observed.continuousNanoseconds
        else {
            throw InvestigationInstalledL2SemanticError
                .installedContractUnproved
        }

        return InvestigationInstalledL2SemanticObservation(
            projection: projection,
            artifacts: artifacts,
            app: app,
            helper: helper,
            machineDriver: machineDriver,
            service: service,
            started: started,
            observed: observed
        )
    }
}
