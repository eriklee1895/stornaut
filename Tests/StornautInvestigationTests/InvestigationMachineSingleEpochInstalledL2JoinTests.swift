import Foundation
import Testing
@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationInstalledL2
@testable import StornautInvestigationMachineDriverSupport

@Suite("Investigation machine installed-L2 join")
struct InvestigationMachineSingleEpochInstalledL2JoinTests {
    @Test
    func exactTypedJoinObservesOnceAndMintsOpaqueProof() async throws {
        let fixture = try InstalledL2JoinFixture()
        let observer = RecordingSingleEpochSemanticObserver(
            result: .success(fixture.semantic)
        )
        let join = InvestigationMachineSingleEpochInstalledL2Join(
            observer: observer
        )

        let semantic = try await join.observe(
            projection: fixture.projection,
            appIdentity: fixture.appIdentity,
            claimEvidence: fixture.claimEvidence,
            epochUUID: fixture.epoch.epochUUID,
            deadlineNanoseconds: fixture.epochDeadline
        )
        let proof = try InvestigationMachineSingleEpochInstalledL2Join.prove(
            projection: fixture.projection,
            claimEvidence: fixture.claimEvidence,
            semanticObservation: semantic,
            repeatedAppIdentity: fixture.appIdentity,
            epochUUID: fixture.epoch.epochUUID,
            deadlineNanoseconds: fixture.epochDeadline
        )

        #expect(observer.calls == [.init(
            projection: fixture.projection,
            app: fixture.appIdentity,
            helper: fixture.helperIdentity
        )])
        #expect(!(InvestigationMachineSingleEpochInstalledL2Proof.self
            is any Codable.Type))
        #expect(!(type(of: proof) is any Codable.Type))
    }

    @Test(arguments: InstalledL2CommitmentDrift.allCases)
    fileprivate func commitmentRejectsEveryProjectionEpochDrift(
        _ drift: InstalledL2CommitmentDrift
    ) throws {
        let fixture = try InstalledL2JoinFixture()
        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineSingleEpochCommitment(
                epoch: fixture.epoch,
                projection: try fixture.projection(drift: drift)
            )
        }
    }

    @Test(arguments: InstalledL2ClaimJoinDrift.allCases)
    fileprivate func claimEvidenceMustMatchProjectionAppHelperAndDeadline(
        _ drift: InstalledL2ClaimJoinDrift
    ) async throws {
        let fixture = try InstalledL2JoinFixture()
        let observer = RecordingSingleEpochSemanticObserver(
            result: .success(fixture.semantic)
        )
        let join = InvestigationMachineSingleEpochInstalledL2Join(
            observer: observer
        )

        await #expect(throws: (any Error).self) {
            _ = try await join.observe(
                projection: fixture.projection,
                appIdentity: fixture.appIdentity,
                claimEvidence: try fixture.claimEvidence(drift: drift),
                epochUUID: fixture.epoch.epochUUID,
                deadlineNanoseconds: fixture.epochDeadline
            )
        }
        #expect(observer.calls.count == (drift == .helper ? 1 : 0))
    }

    @Test(arguments: InstalledL2SemanticJoinDrift.allCases)
    fileprivate func semanticObservationMustMatchEveryTypedJoinAxis(
        _ drift: InstalledL2SemanticJoinDrift
    ) async throws {
        let fixture = try InstalledL2JoinFixture()
        let observer = RecordingSingleEpochSemanticObserver(
            result: .success(try fixture.semantic(drift: drift))
        )
        let join = InvestigationMachineSingleEpochInstalledL2Join(
            observer: observer
        )

        await #expect(throws: (any Error).self) {
            _ = try await join.observe(
                projection: fixture.projection,
                appIdentity: fixture.appIdentity,
                claimEvidence: fixture.claimEvidence,
                epochUUID: fixture.epoch.epochUUID,
                deadlineNanoseconds: fixture.epochDeadline
            )
        }
        #expect(observer.calls.count == 1)
    }

    @Test
    func observerFailureNeverCreatesJoinEvidence() async throws {
        let fixture = try InstalledL2JoinFixture()
        let observer = RecordingSingleEpochSemanticObserver(
            result: .failure(.installedContractUnproved)
        )
        let join = InvestigationMachineSingleEpochInstalledL2Join(
            observer: observer
        )

        await #expect(throws: (any Error).self) {
            _ = try await join.observe(
                projection: fixture.projection,
                appIdentity: fixture.appIdentity,
                claimEvidence: fixture.claimEvidence,
                epochUUID: fixture.epoch.epochUUID,
                deadlineNanoseconds: fixture.epochDeadline
            )
        }
        #expect(observer.calls.count == 1)
    }

    @Test
    func repeatedAppMismatchCannotMintProof() async throws {
        let fixture = try InstalledL2JoinFixture()
        let observer = RecordingSingleEpochSemanticObserver(
            result: .success(fixture.semantic)
        )
        let semantic = try await InvestigationMachineSingleEpochInstalledL2Join(
            observer: observer
        ).observe(
            projection: fixture.projection,
            appIdentity: fixture.appIdentity,
            claimEvidence: fixture.claimEvidence,
            epochUUID: fixture.epoch.epochUUID,
            deadlineNanoseconds: fixture.epochDeadline
        )

        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineSingleEpochInstalledL2Join.prove(
                projection: fixture.projection,
                claimEvidence: fixture.claimEvidence,
                semanticObservation: semantic,
                repeatedAppIdentity: fixture.foreignAppIdentity,
                epochUUID: fixture.epoch.epochUUID,
                deadlineNanoseconds: fixture.epochDeadline
            )
        }
    }
}

private struct InstalledL2SemanticCall: Sendable, Equatable {
    let projection: InvestigationInstalledL2IdentityProjection
    let app: InvestigationMachineProcessIdentity
    let helper: InvestigationMachineProcessIdentity
}

private final class RecordingSingleEpochSemanticObserver:
    InvestigationMachineSingleEpochInstalledL2SemanticObserving,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var storedCalls: [InstalledL2SemanticCall] = []
    private let result: Result<
        InvestigationInstalledL2SemanticObservation,
        InvestigationInstalledL2SemanticError
    >

    var calls: [InstalledL2SemanticCall] { lock.withLock { storedCalls } }

    init(
        result: Result<
            InvestigationInstalledL2SemanticObservation,
            InvestigationInstalledL2SemanticError
        >
    ) {
        self.result = result
    }

    func observe(
        projection: InvestigationInstalledL2IdentityProjection,
        expectedApp: InvestigationMachineProcessIdentity,
        expectedHelper: InvestigationMachineProcessIdentity
    ) throws -> InvestigationInstalledL2SemanticObservation {
        lock.withLock {
            storedCalls.append(.init(
                projection: projection, app: expectedApp, helper: expectedHelper
            ))
        }
        return try result.get()
    }
}

private enum InstalledL2CommitmentDrift: CaseIterable {
    case epoch, nonce, configuration, binding
}

private enum InstalledL2ClaimJoinDrift: CaseIterable {
    case app, helper, investigation, releaseDeadline
}

private enum InstalledL2SemanticJoinDrift: CaseIterable {
    case projection, app, helper, claimedAfterStart, releaseBeforeObserved
}

private struct InstalledL2JoinFixture {
    let epoch: InvestigationCohortEpoch
    let projection: InvestigationInstalledL2IdentityProjection
    let appIdentity: InvestigationMachineProcessIdentity
    let helperIdentity: InvestigationMachineProcessIdentity
    let foreignAppIdentity: InvestigationMachineProcessIdentity
    let claimEvidence: InvestigationMachineClaimEvidence
    let semantic: InvestigationInstalledL2SemanticObservation
    let epochDeadline: UInt64 = 500

    init() throws {
        let configuration = Data("opaque-configuration".utf8)
        epoch = try .init(
            ordinal: 0, epochUUID: Self.uuid(0x11), scenario: .success,
            configurationNonce: Self.uuid(0x12), configuration: configuration,
            configurationSHA256: .hashing(configuration),
            signedRuntimeBindingSHA256: Self.digest(0x13)
        )
        let driverSigning = try Self.signing(
            "com.eriklee.stornaut.investigation.machine-driver", 0x43, true
        )
        projection = try Self.projection(
            epoch: epoch, driverSigning: driverSigning
        )
        appIdentity = try Self.identity(
            role: .app, pid: 701, version: 11, asid: 44_001, euid: 501
        )
        foreignAppIdentity = try Self.identity(
            role: .app, pid: 711, version: 21, asid: 44_001, euid: 501
        )
        helperIdentity = try Self.identity(
            role: .helper, pid: 702, version: 12, asid: 44_001, euid: 0
        )
        claimEvidence = try Self.claimEvidence(
            projection: projection, app: appIdentity, helper: helperIdentity,
            releaseDeadline: 400
        )
        semantic = try Self.semantic(
            projection: projection, app: appIdentity, helper: helperIdentity,
            driverSigning: driverSigning, startedWall: 300, observedWall: 301,
            startedContinuous: 350, observedContinuous: 351
        )
    }

    func projection(
        drift: InstalledL2CommitmentDrift
    ) throws -> InvestigationInstalledL2IdentityProjection {
        let driver = semantic.machineDriver.staticSigning
        let changedEpoch = drift == .epoch ? Self.uuid(0x21) : epoch.epochUUID
        let changedNonce = drift == .nonce
            ? Self.uuid(0x22) : epoch.configurationNonce
        let changedConfiguration = drift == .configuration
            ? try Self.digest(0x23) : epoch.configurationSHA256
        let changedBinding = drift == .binding
            ? try Self.digest(0x24) : epoch.signedRuntimeBindingSHA256
        return try .init(
            epochUUID: changedEpoch, configurationNonce: changedNonce,
            configurationValidBefore: projection.configurationValidBefore,
            configurationSHA256: changedConfiguration,
            signedRuntimeBindingSHA256: changedBinding,
            appExecutableSHA256: projection.appExecutableSHA256,
            appBundleIdentifier: projection.appBundleIdentifier,
            helperExecutableSHA256: projection.helperExecutableSHA256,
            helperServiceIdentifier: projection.helperServiceIdentifier,
            machineDriverExecutableSHA256:
                projection.machineDriverExecutableSHA256,
            machineDriverSigningIdentifier: driver.signingIdentifier,
            machineDriverDesignatedRequirementSHA256:
                driver.designatedRequirementSHA256,
            machineDriverCodeDirectoryHash: driver.codeDirectoryHash,
            machineClaimServiceIdentifier: projection.machineClaimServiceIdentifier
        )
    }

    func claimEvidence(
        drift: InstalledL2ClaimJoinDrift
    ) throws -> InvestigationMachineClaimEvidence {
        let app = drift == .app ? foreignAppIdentity : appIdentity
        let helper = drift == .helper
            ? try Self.identity(
                role: .helper, pid: 712, version: 22, asid: 44_002, euid: 0
            ) : helperIdentity
        let nonce = drift == .investigation
            ? Self.uuid(0x31) : projection.configurationNonce
        return try Self.claimEvidence(
            projection: projection, app: app, helper: helper,
            investigationUUID: nonce,
            releaseDeadline: drift == .releaseDeadline ? epochDeadline + 1 : 400
        )
    }

    func semantic(
        drift: InstalledL2SemanticJoinDrift
    ) throws -> InvestigationInstalledL2SemanticObservation {
        let app = drift == .app ? foreignAppIdentity : appIdentity
        let helper = drift == .helper
            ? try Self.identity(
                role: .helper, pid: 713, version: 23, asid: 44_003, euid: 0
            ) : helperIdentity
        let projected = drift == .projection
            ? try projection(drift: .epoch) : projection
        let claimedAfter = drift == .claimedAfterStart ? Int64(200) : 300
        let observedContinuous = drift == .releaseBeforeObserved ? UInt64(401) : 351
        return try Self.semantic(
            projection: projected, app: app, helper: helper,
            driverSigning: semantic.machineDriver.staticSigning,
            startedWall: claimedAfter, observedWall: claimedAfter + 1,
            startedContinuous: 350, observedContinuous: observedContinuous
        )
    }

    private static func projection(
        epoch: InvestigationCohortEpoch,
        driverSigning: InvestigationInstalledL2SigningIdentity
    ) throws -> InvestigationInstalledL2IdentityProjection {
        try .init(
            epochUUID: epoch.epochUUID,
            configurationNonce: epoch.configurationNonce,
            configurationValidBefore: .init(rawValue: 1_000),
            configurationSHA256: epoch.configurationSHA256,
            signedRuntimeBindingSHA256: epoch.signedRuntimeBindingSHA256,
            appExecutableSHA256: digest(0x31),
            appBundleIdentifier: "com.eriklee.stornaut",
            helperExecutableSHA256: digest(0x32),
            helperServiceIdentifier: "com.eriklee.stornaut.lifecycle",
            machineDriverExecutableSHA256: digest(0x33),
            machineDriverSigningIdentifier: driverSigning.signingIdentifier,
            machineDriverDesignatedRequirementSHA256:
                driverSigning.designatedRequirementSHA256,
            machineDriverCodeDirectoryHash: driverSigning.codeDirectoryHash,
            machineClaimServiceIdentifier:
                "com.eriklee.stornaut.lifecycle.machine-claim"
        )
    }

    private static func claimEvidence(
        projection: InvestigationInstalledL2IdentityProjection,
        app: InvestigationMachineProcessIdentity,
        helper: InvestigationMachineProcessIdentity,
        investigationUUID: UUID? = nil,
        releaseDeadline: UInt64
    ) throws -> InvestigationMachineClaimEvidence {
        try .init(
            requestBindingSHA256: digest(0x41),
            originalClaimChallenge: uuid(0x42),
            claimConnectionEpoch: uuid(0x43),
            appIdentity: app, helperIdentity: helper, appUserID: 501,
            recordedAt: .init(rawValue: 250),
            claimedAt: .init(rawValue: 275),
            ownerRetirement: .init(),
            l1Residue: .init(
                investigationUUID:
                    investigationUUID ?? projection.configurationNonce,
                auditSessionID: helper.auditSessionID, userID: 501,
                observedAt: .init(rawValue: 200),
                remainingAuditSessionMembers: 0, matchingLeases: 0,
                leaseRootEntries: 0, investigationArtifacts: 0
            ),
            releaseDeadlineNanoseconds: releaseDeadline
        )
    }

    private static func semantic(
        projection: InvestigationInstalledL2IdentityProjection,
        app: InvestigationMachineProcessIdentity,
        helper: InvestigationMachineProcessIdentity,
        driverSigning: InvestigationInstalledL2SigningIdentity,
        startedWall: Int64, observedWall: Int64,
        startedContinuous: UInt64, observedContinuous: UInt64
    ) throws -> InvestigationInstalledL2SemanticObservation {
        let appSigning = try signing(
            "com.eriklee.stornaut", 0x51, false
        )
        let helperSigning = try signing(
            "com.eriklee.stornaut.lifecycle.helper", 0x52, false
        )
        let artifacts = Dictionary(uniqueKeysWithValues:
            InvestigationInstalledL2ArtifactRole.allCases.map {
                ($0, InvestigationInstalledL2ArtifactObservation.presentValid)
            }
        )
        return try InvestigationInstalledL2SemanticContract.evaluate(
            projection: projection, artifacts: artifacts,
            app: try .init(
                identity: app, executableSHA256: projection.appExecutableSHA256,
                staticSigning: appSigning, liveSigning: appSigning
            ),
            helper: try .init(
                identity: helper,
                executableSHA256: projection.helperExecutableSHA256,
                staticSigning: helperSigning, liveSigning: helperSigning
            ),
            machineDriver: try .init(
                executableSHA256: projection.machineDriverExecutableSHA256,
                staticSigning: driverSigning, liveSigning: driverSigning
            ),
            service: .loaded(identity: helper),
            started: try .init(
                wallUTC: .init(rawValue: startedWall),
                continuousNanoseconds: startedContinuous
            ),
            observed: try .init(
                wallUTC: .init(rawValue: observedWall),
                continuousNanoseconds: observedContinuous
            )
        )
    }

    private static func signing(
        _ identifier: String, _ byte: UInt8, _ adHoc: Bool
    ) throws -> InvestigationInstalledL2SigningIdentity {
        try .init(
            signingIdentifier: identifier,
            designatedRequirementSHA256: digest(byte),
            codeDirectoryHash: Data(repeating: byte, count: 20),
            isAdHoc: adHoc
        )
    }

    private static func identity(
        role: InvestigationMachineProcessRole, pid: UInt32, version: UInt32,
        asid: UInt32, euid: UInt32
    ) throws -> InvestigationMachineProcessIdentity {
        try .init(
            role: role, processID: pid, processIDVersion: version,
            auditSessionID: asid, effectiveUserID: euid,
            auditTokenWords: [euid, euid, 20, euid, 20, pid, asid, version]
        )
    }

    private static func digest(_ byte: UInt8)
        throws -> InvestigationHandoffSHA256
    { try .init(rawBytes: Data(repeating: byte, count: 32)) }

    private static func uuid(_ byte: UInt8) -> UUID {
        UUID(uuid: (byte, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    }
}
