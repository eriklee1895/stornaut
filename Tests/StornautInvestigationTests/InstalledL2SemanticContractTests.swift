import Foundation
import Testing
@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationInstalledL2

@Suite("Installed L2 semantic contract")
struct InstalledL2SemanticContractTests {
    @Test
    func exactInstalledFactsProduceCompleteOrdinarySemanticObservation() throws {
        let fixture = try InstalledL2SemanticFixture()
        let observation = try fixture.evaluate()

        #expect(observation.projectionSHA256 == fixture.projection.projectionSHA256)
        #expect(observation.epochUUID == fixture.projection.epochUUID)
        #expect(observation.configurationNonce == fixture.projection.configurationNonce)
        #expect(observation.artifacts.count == 8)
        #expect(observation.app == fixture.app)
        #expect(observation.helper == fixture.helper)
        #expect(observation.appIdentity == fixture.app.identity)
        #expect(observation.helperIdentity == fixture.helper.identity)
        #expect(
            observation.machineDriver.executableSHA256
                == fixture.projection.machineDriverExecutableSHA256
        )
        #expect(observation.machineDriver.staticSigning == fixture.driverSigning)
        #expect(observation.machineDriver.liveSigning == fixture.driverSigning)
        #expect(observation.service == .loaded(identity: fixture.helper.identity))
        #expect(observation.started == fixture.started)
        #expect(observation.observed == fixture.observed)
        #expect(!(InvestigationInstalledL2SemanticObservation.self is any Codable.Type))
        #expect(!(InvestigationInstalledL2SemanticContract.self is any Codable.Type))
    }

    @Test
    func installedPredicateRequiresEveryClosedArtifactRole() throws {
        let fixture = try InstalledL2SemanticFixture()
        #expect(Set(InvestigationInstalledL2ArtifactRole.allCases) == Set([
            .installedRoot, .installedApp, .appExecutable, .helperExecutable,
            .machineDriverExecutable, .launchDaemonPlist, .runtimeRoot, .leaseRoot,
        ]))

        for role in InvestigationInstalledL2ArtifactRole.allCases {
            var missing = fixture.artifacts
            missing.removeValue(forKey: role)
            #expect(throws: (any Error).self) {
                _ = try fixture.evaluate(artifacts: missing)
            }
        }
    }

    @Test(arguments: InvestigationInstalledL2ArtifactRole.allCases)
    func everyArtifactInvalidOrUnavailableFailsClosed(
        _ role: InvestigationInstalledL2ArtifactRole
    ) throws {
        let fixture = try InstalledL2SemanticFixture()
        for state in [
            InvestigationInstalledL2ArtifactObservation.invalid,
            .unavailable,
        ] {
            var artifacts = fixture.artifacts
            artifacts[role] = state
            #expect(throws: (any Error).self) {
                _ = try fixture.evaluate(artifacts: artifacts)
            }
        }
    }

    @Test
    func onlyRuntimeAndLeaseRootsMayBeAbsent() throws {
        let fixture = try InstalledL2SemanticFixture()
        for optional in [
            InvestigationInstalledL2ArtifactRole.runtimeRoot, .leaseRoot,
        ] {
            var artifacts = fixture.artifacts
            artifacts[optional] = .absent
            #expect(try fixture.evaluate(artifacts: artifacts).artifacts[optional] == .absent)
        }
        for required in InvestigationInstalledL2ArtifactRole.allCases where
            required != .runtimeRoot && required != .leaseRoot
        {
            var artifacts = fixture.artifacts
            artifacts[required] = .absent
            #expect(throws: (any Error).self) {
                _ = try fixture.evaluate(artifacts: artifacts)
            }
        }
    }

    @Test(arguments: InstalledL2ProjectionFactMutation.allCases)
    fileprivate func projectionCommitmentsMustMatchIndependentFacts(
        _ mutation: InstalledL2ProjectionFactMutation
    ) throws {
        let fixture = try InstalledL2SemanticFixture()
        #expect(throws: (any Error).self) {
            _ = try fixture.evaluate(projectionMutation: mutation)
        }
    }

    @Test(arguments: InstalledL2ProcessFactMutation.allCases)
    fileprivate func appHelperAndServiceRequireExactCompleteIdentities(
        _ mutation: InstalledL2ProcessFactMutation
    ) throws {
        let fixture = try InstalledL2SemanticFixture()
        #expect(throws: (any Error).self) {
            _ = try fixture.evaluate(processMutation: mutation)
        }
    }

    @Test(arguments: InstalledL2ClockMutation.allCases)
    fileprivate func pairedClockSamplesRejectRollbackAndWallExpiry(
        _ mutation: InstalledL2ClockMutation
    ) throws {
        let fixture = try InstalledL2SemanticFixture()
        #expect(throws: (any Error).self) {
            _ = try fixture.evaluate(clockMutation: mutation)
        }
    }

    @Test
    func semanticValuesRejectOpenIdentifiersAndCodeDirectoryWidths() throws {
        let fixture = try InstalledL2SemanticFixture()
        for identifier in ["", "foreign\nidentifier", String(repeating: "a", count: 257)] {
            #expect(throws: (any Error).self) {
                _ = try fixture.signing(identifier: identifier)
            }
        }
        for count in [0, 19, 21, 31, 33] {
            #expect(throws: (any Error).self) {
                _ = try fixture.signing(codeDirectoryHash: Data(repeating: 1, count: count))
            }
        }
        for count in [20, 32] {
            #expect(try fixture.signing(
                codeDirectoryHash: Data(repeating: 1, count: count)
            ).codeDirectoryHash.count == count)
        }
    }
}

private enum InstalledL2ProjectionFactMutation: CaseIterable {
    case appExecutable, helperExecutable, driverExecutable
    case appSigning, helperSigning, driverSigningIdentifier
    case driverRequirement, driverCodeDirectory, driverAdHoc, driverStaticLive
}

private enum InstalledL2ProcessFactMutation: CaseIterable {
    case appRole, helperRole, sameProcess
    case appStaticLive, helperStaticLive
    case serviceAbsent, serviceForeign
}

private enum InstalledL2ClockMutation: CaseIterable {
    case wallRollback, wallExpiry, continuousRollback, zeroStarted, zeroObserved
}

private struct InstalledL2SemanticFixture {
    let projection: InvestigationInstalledL2IdentityProjection
    let artifacts: [
        InvestigationInstalledL2ArtifactRole: InvestigationInstalledL2ArtifactObservation
    ]
    let app: InvestigationInstalledL2ProcessEvidence
    let helper: InvestigationInstalledL2ProcessEvidence
    let driverSigning: InvestigationInstalledL2SigningIdentity
    let started: InvestigationInstalledL2ClockSample
    let observed: InvestigationInstalledL2ClockSample

    init() throws {
        let appSigning = try Self.signing(
            identifier: "com.eriklee.stornaut", byte: 0x41, adHoc: false
        )
        let helperSigning = try Self.signing(
            identifier: "com.eriklee.stornaut.lifecycle.helper",
            byte: 0x42,
            adHoc: false
        )
        driverSigning = try Self.signing(
            identifier: "com.eriklee.stornaut.investigation.machine-driver",
            byte: 0x43,
            adHoc: true
        )
        projection = try .init(
            epochUUID: Self.uuid(0x11),
            configurationNonce: Self.uuid(0x12),
            configurationValidBefore: .init(rawValue: 1_000),
            configurationSHA256: Self.digest(0x21),
            signedRuntimeBindingSHA256: Self.digest(0x22),
            appExecutableSHA256: Self.digest(0x31),
            appBundleIdentifier: "com.eriklee.stornaut",
            helperExecutableSHA256: Self.digest(0x32),
            helperServiceIdentifier: "com.eriklee.stornaut.lifecycle",
            machineDriverExecutableSHA256: Self.digest(0x33),
            machineDriverSigningIdentifier:
                "com.eriklee.stornaut.investigation.machine-driver",
            machineDriverDesignatedRequirementSHA256:
                driverSigning.designatedRequirementSHA256,
            machineDriverCodeDirectoryHash: driverSigning.codeDirectoryHash,
            machineClaimServiceIdentifier:
                "com.eriklee.stornaut.lifecycle.machine-claim"
        )
        artifacts = Dictionary(
            uniqueKeysWithValues: InvestigationInstalledL2ArtifactRole.allCases.map {
                ($0, .presentValid)
            }
        )
        app = try .init(
            identity: Self.identity(role: .app, pid: 41, version: 7, asid: 8),
            executableSHA256: projection.appExecutableSHA256,
            staticSigning: appSigning,
            liveSigning: appSigning
        )
        helper = try .init(
            identity: Self.identity(role: .helper, pid: 84, version: 9, asid: 10),
            executableSHA256: projection.helperExecutableSHA256,
            staticSigning: helperSigning,
            liveSigning: helperSigning
        )
        started = try .init(wallUTC: .init(rawValue: 100), continuousNanoseconds: 200)
        observed = try .init(wallUTC: .init(rawValue: 101), continuousNanoseconds: 201)
    }

    func evaluate(
        artifacts: [
            InvestigationInstalledL2ArtifactRole: InvestigationInstalledL2ArtifactObservation
        ]? = nil,
        projectionMutation: InstalledL2ProjectionFactMutation? = nil,
        processMutation: InstalledL2ProcessFactMutation? = nil,
        clockMutation: InstalledL2ClockMutation? = nil
    ) throws -> InvestigationInstalledL2SemanticObservation {
        var appIdentity = app.identity
        var appExecutable = app.executableSHA256
        var appStaticSigning = app.staticSigning
        var appLiveSigning = app.liveSigning
        var helperIdentity = helper.identity
        var helperExecutable = helper.executableSHA256
        var helperStaticSigning = helper.staticSigning
        var helperLiveSigning = helper.liveSigning
        var driverExecutable = projection.machineDriverExecutableSHA256
        var driverStaticSigning = self.driverSigning
        var driverLiveSigning = self.driverSigning
        var service: InvestigationInstalledL2ServiceObservation =
            .loaded(identity: helper.identity)
        var started = self.started
        var observed = self.observed

        switch projectionMutation {
        case .appExecutable:
            appExecutable = try Self.digest(0x71)
        case .helperExecutable:
            helperExecutable = try Self.digest(0x72)
        case .driverExecutable:
            driverExecutable = try Self.digest(0x73)
        case .appSigning:
            appStaticSigning = try signing(identifier: "foreign.app")
            appLiveSigning = appStaticSigning
        case .helperSigning:
            helperStaticSigning = try signing(identifier: "foreign.helper")
            helperLiveSigning = helperStaticSigning
        case .driverSigningIdentifier:
            driverStaticSigning = try signing(identifier: "foreign.driver", adHoc: true)
            driverLiveSigning = driverStaticSigning
        case .driverRequirement:
            driverStaticSigning = try signing(byte: 0x74, adHoc: true)
            driverLiveSigning = driverStaticSigning
        case .driverCodeDirectory:
            driverStaticSigning = try signing(
                codeDirectoryHash: Data(repeating: 0x75, count: 20), adHoc: true
            )
            driverLiveSigning = driverStaticSigning
        case .driverAdHoc:
            driverStaticSigning = try signing(adHoc: false)
            driverLiveSigning = driverStaticSigning
        case .driverStaticLive:
            driverLiveSigning = try signing(identifier: "foreign.driver", adHoc: true)
        case nil:
            break
        }

        switch processMutation {
        case .appRole:
            appIdentity = try Self.identity(
                role: .helper, pid: 41, version: 7, asid: 8
            )
        case .helperRole:
            helperIdentity = try Self.identity(
                role: .app, pid: 84, version: 9, asid: 10
            )
        case .sameProcess:
            helperIdentity = appIdentity
        case .appStaticLive:
            appLiveSigning = try signing(identifier: "foreign.app")
        case .helperStaticLive:
            helperLiveSigning = try signing(identifier: "foreign.helper")
        case .serviceAbsent:
            service = .absent
        case .serviceForeign:
            service = .loaded(identity: try Self.identity(
                role: .helper, pid: 85, version: 10, asid: 11
            ))
        case nil:
            break
        }

        switch clockMutation {
        case .wallRollback:
            observed = try .init(wallUTC: .init(rawValue: 99), continuousNanoseconds: 201)
        case .wallExpiry:
            observed = try .init(wallUTC: projection.configurationValidBefore, continuousNanoseconds: 201)
        case .continuousRollback:
            observed = try .init(wallUTC: .init(rawValue: 101), continuousNanoseconds: 199)
        case .zeroStarted:
            started = try .init(wallUTC: .init(rawValue: 100), continuousNanoseconds: 0)
        case .zeroObserved:
            observed = try .init(wallUTC: .init(rawValue: 101), continuousNanoseconds: 0)
        case nil:
            break
        }
        let app = try InvestigationInstalledL2ProcessEvidence(
            identity: appIdentity,
            executableSHA256: appExecutable,
            staticSigning: appStaticSigning,
            liveSigning: appLiveSigning
        )
        let helper = try InvestigationInstalledL2ProcessEvidence(
            identity: helperIdentity,
            executableSHA256: helperExecutable,
            staticSigning: helperStaticSigning,
            liveSigning: helperLiveSigning
        )
        let machineDriver = try InvestigationInstalledL2MachineDriverEvidence(
            executableSHA256: driverExecutable,
            staticSigning: driverStaticSigning,
            liveSigning: driverLiveSigning
        )

        return try InvestigationInstalledL2SemanticContract.evaluate(
            projection: projection,
            artifacts: artifacts ?? self.artifacts,
            app: app,
            helper: helper,
            machineDriver: machineDriver,
            service: service,
            started: started,
            observed: observed
        )
    }

    func signing(
        identifier: String =
            "com.eriklee.stornaut.investigation.machine-driver",
        byte: UInt8 = 0x43,
        codeDirectoryHash: Data? = nil,
        adHoc: Bool = true
    ) throws -> InvestigationInstalledL2SigningIdentity {
        try Self.signing(
            identifier: identifier, byte: byte,
            codeDirectoryHash: codeDirectoryHash, adHoc: adHoc
        )
    }

    private static func signing(
        identifier: String,
        byte: UInt8,
        codeDirectoryHash: Data? = nil,
        adHoc: Bool
    ) throws -> InvestigationInstalledL2SigningIdentity {
        try .init(
            signingIdentifier: identifier,
            designatedRequirementSHA256: digest(byte),
            codeDirectoryHash: codeDirectoryHash ?? Data(repeating: byte, count: 20),
            isAdHoc: adHoc
        )
    }

    private static func identity(
        role: InvestigationMachineProcessRole,
        pid: UInt32,
        version: UInt32,
        asid: UInt32
    ) throws -> InvestigationMachineProcessIdentity {
        let euid: UInt32 = role == .app ? 501 : 0
        return try .init(
            role: role, processID: pid, processIDVersion: version,
            auditSessionID: asid, effectiveUserID: euid,
            auditTokenWords: [euid, euid, 20, euid, 20, pid, asid, version]
        )
    }

    private static func digest(_ byte: UInt8) throws -> InvestigationHandoffSHA256 {
        try .init(rawBytes: Data(repeating: byte, count: 32))
    }

    private static func uuid(_ byte: UInt8) throws -> UUID {
        guard let value = UUID(uuidString: String(
            format: "00000000-0000-4000-8000-0000000000%02x", byte
        )) else {
            throw InstalledL2SemanticFixtureError.invalidUUID
        }
        return value
    }
}

private enum InstalledL2SemanticFixtureError: Error {
    case invalidUUID
}
