import Foundation
import Testing
@testable import StornautInvestigationHandoffContract

@Suite("Investigation installed L2 projection contract")
struct InvestigationInstalledL2ProjectionContractTests {
    @Test
    func projectionUsesTheExactCanonicalTranscriptAndSelfDigest() throws {
        let fixture = try InstalledL2ProjectionFixture()
        let projection = try fixture.projection()
        let expected = try fixture.goldenEncoded()
        let expectedDigest = try fixture.goldenProjectionSHA256()

        #expect(expected.count == 585)
        #expect(try projection.encoded() == expected)
        #expect(try InvestigationInstalledL2IdentityProjection.decode(expected) == projection)
        #expect(projection.projectionSHA256 == expectedDigest)
        #expect(
            InvestigationHandoffSHA256.hashing(expected).lowercaseHex
                == "46084732041cc7629bc47689caf9855bdd5a0a16c3f07ef3d10e7546e107d212"
        )
        #expect(projection.epochUUID == fixture.epochUUID)
        #expect(projection.configurationNonce == fixture.configurationNonce)
        #expect(projection.configurationValidBefore == fixture.configurationValidBefore)
        #expect(projection.machineDriverCodeDirectoryHash == fixture.driverCodeDirectoryHash)
        #expect(!(InvestigationInstalledL2IdentityProjection.self is any Codable.Type))
    }

    @Test
    func projectionDecoderRejectsEveryStructuralAndDigestDrift() throws {
        let fixture = try InstalledL2ProjectionFixture()
        let valid = try fixture.goldenEncoded()
        let domainFieldBytes = 6 + InvestigationInstalledL2IdentityProjection.domain.utf8.count
        let versionOffset = 4 + domainFieldBytes
        let firstFieldOffset = versionOffset + 10
        let firstFieldEnd = firstFieldOffset + 22
        var wrongMagic = valid; wrongMagic[0] ^= 0xff
        var wrongDomain = valid; wrongDomain[10] ^= 0x01
        var wrongVersion = valid; wrongVersion[versionOffset + 9] = 2
        var missing = valid; missing.removeSubrange(firstFieldOffset..<firstFieldEnd)
        var duplicate = valid
        duplicate.insert(contentsOf: valid[firstFieldOffset..<firstFieldEnd], at: firstFieldEnd)
        var reordered = valid; reordered[firstFieldOffset + 1] = 3
        var lengthDrift = valid; lengthDrift[firstFieldOffset + 5] = 15
        var digestDrift = valid; digestDrift[digestDrift.count - 1] ^= 0xff

        for mutation in [
            wrongMagic, wrongDomain, wrongVersion, missing, duplicate, reordered,
            lengthDrift, Data(valid.dropLast()), valid + Data([0]), digestDrift,
            Data(
                repeating: 0,
                count: InvestigationInstalledL2IdentityProjection.maximumByteCount + 1
            ),
        ] {
            #expect(throws: (any Error).self) {
                _ = try InvestigationInstalledL2IdentityProjection.decode(mutation)
            }
        }
    }

    @Test
    func projectionDecoderRejectsInvalidUTF8WithARecomputedSelfDigest() throws {
        var mutation = try InstalledL2ProjectionFixture().goldenEncoded()
        let appIdentifier = try Self.payloadRange(tag: 8, in: mutation)
        mutation[appIdentifier.lowerBound] = 0xff
        let digest = try Self.payloadRange(tag: 16, in: mutation)
        mutation.replaceSubrange(digest, with: Data(repeating: 0, count: 32))
        mutation.replaceSubrange(
            digest,
            with: InvestigationHandoffSHA256.hashing(mutation).rawBytes
        )

        #expect(throws: (any Error).self) {
            _ = try InvestigationInstalledL2IdentityProjection.decode(mutation)
        }
    }

    private static func payloadRange(
        tag expectedTag: UInt16,
        in data: Data
    ) throws -> Range<Data.Index> {
        var offset = 4
        while offset + 6 <= data.count {
            let tag = UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
            let length = Int(data[offset + 2]) << 24
                | Int(data[offset + 3]) << 16
                | Int(data[offset + 4]) << 8
                | Int(data[offset + 5])
            let lower = offset + 6
            let upper = lower + length
            guard upper <= data.count else {
                throw InstalledL2ProjectionFixtureError.invalidGolden
            }
            if tag == expectedTag { return lower..<upper }
            offset = upper
        }
        throw InstalledL2ProjectionFixtureError.invalidGolden
    }

    @Test(arguments: InstalledL2ProjectionSemanticMutation.allCases)
    fileprivate func projectionRejectsEverySemanticDrift(
        _ mutation: InstalledL2ProjectionSemanticMutation
    ) throws {
        let fixture = try InstalledL2ProjectionFixture()
        #expect(throws: (any Error).self) {
            _ = try fixture.projection(mutation: mutation)
        }
    }

    @Test(arguments: [20, 32])
    func projectionAcceptsOnlyAdmittedCodeDirectoryWidths(_ count: Int) throws {
        let fixture = try InstalledL2ProjectionFixture()
        let projection = try fixture.projection(
            codeDirectoryHash: Data(repeating: 0x44, count: count)
        )
        #expect(projection.machineDriverCodeDirectoryHash.count == count)
        #expect(try InvestigationInstalledL2IdentityProjection.decode(
            projection.encoded()
        ) == projection)
    }

    @Test(arguments: InstalledL2ProjectionCommitmentMutation.allCases)
    fileprivate func everyProjectedCommitmentChangesTheSelfDigest(
        _ mutation: InstalledL2ProjectionCommitmentMutation
    ) throws {
        let fixture = try InstalledL2ProjectionFixture()
        let baseline = try fixture.projection()
        let changed = try fixture.projection(commitmentMutation: mutation)
        #expect(changed.projectionSHA256 != baseline.projectionSHA256)
        #expect(try changed.encoded() != baseline.encoded())
        #expect(try InvestigationInstalledL2IdentityProjection.decode(
            changed.encoded()
        ) == changed)
    }

    @Test
    func projectionCarriesNoConfigurationBodyOrAuthoritySurface() throws {
        let encoded = try InstalledL2ProjectionFixture().projection().encoded()
        for forbidden in [
            "opaque-configuration-body", "diagnosticRootPath", "sourceRootPath",
            "supportRootPath", "reportPath", "storePath", "expectedModel",
            "expectedProvider", "optIn", "maximumTurns", "handle-token",
            "/private/tmp/path",
        ] {
            #expect(encoded.range(of: Data(forbidden.utf8)) == nil)
        }
    }

    @Test
    func projectionDigestHexBoundaryAdmitsOnlyExactLowercaseSHA256() throws {
        let lowercase =
            "3723e09d065ee04d17ea0b5de4a4bf23afffc5c0d51e772770d763accc0ad601"
        #expect(
            try InvestigationHandoffSHA256(lowercaseHex: lowercase).lowercaseHex
                == lowercase
        )
        for malformed in [
            lowercase.uppercased(), String(lowercase.dropLast()), lowercase + "0",
        ] {
            #expect(throws: (any Error).self) {
                _ = try InvestigationHandoffSHA256(lowercaseHex: malformed)
            }
        }
    }

    @Test
    func temporalContractKeepsWallAndContinuousDomainsIndependent() throws {
        let fixture = try InstalledL2ProjectionFixture()
        let projection = try fixture.projection()
        let claimEvidence = try fixture.claimEvidence(
            claimedAt: 100,
            releaseDeadlineNanoseconds: 201
        )
        let value = try InvestigationInstalledL2TemporalWindow(
            projection: projection,
            claimEvidence: claimEvidence,
            epochBootstrap: fixture.epochBootstrap(
                epochDeadlineNanoseconds: 201
            ),
            started: InvestigationInstalledL2ClockSample(
                wallUTC: fixture.utc(100), continuousNanoseconds: 200
            ),
            observed: InvestigationInstalledL2ClockSample(
                wallUTC: fixture.utc(100), continuousNanoseconds: 200
            )
        )
        let expectedWall = try fixture.utc(100)
        #expect(value.projectionSHA256 == projection.projectionSHA256)
        #expect(
            value.claimEvidenceSHA256
                == InvestigationHandoffSHA256.hashing(try claimEvidence.encoded())
        )
        #expect(value.epochUUID == fixture.epochUUID)
        #expect(value.claimedAt == expectedWall)
        #expect(value.started.wallUTC == expectedWall)
        #expect(value.observed.continuousNanoseconds == 200)
        #expect(!(InvestigationInstalledL2TemporalWindow.self is any Codable.Type))
        #expect(!(InvestigationInstalledL2ClockSample.self is any Codable.Type))
    }

    @Test
    func temporalContractUsesOrderingAtRepresentableClockMaxima() throws {
        let fixture = try InstalledL2ProjectionFixture()
        let projection = try fixture.projection(validBefore: fixture.utc(.max))
        let claimEvidence = try fixture.claimEvidence(
            claimedAt: .max - 3,
            releaseDeadlineNanoseconds: .max
        )
        let bootstrap = try fixture.epochBootstrap(
            epochDeadlineNanoseconds: .max
        )
        let value = try InvestigationInstalledL2TemporalWindow(
            projection: projection,
            claimEvidence: claimEvidence,
            epochBootstrap: bootstrap,
            started: .init(
                wallUTC: fixture.utc(.max - 2),
                continuousNanoseconds: .max - 2
            ),
            observed: .init(
                wallUTC: fixture.utc(.max - 1),
                continuousNanoseconds: .max - 1
            )
        )
        #expect(value.configurationValidBefore.rawValue == .max)
        #expect(value.releaseDeadlineNanoseconds == .max)
        #expect(value.epochDeadlineNanoseconds == .max)

        #expect(throws: (any Error).self) {
            _ = try InvestigationInstalledL2TemporalWindow(
                projection: projection,
                claimEvidence: claimEvidence,
                epochBootstrap: bootstrap,
                started: .init(
                    wallUTC: fixture.utc(.max - 1),
                    continuousNanoseconds: .max - 1
                ),
                observed: .init(
                    wallUTC: fixture.utc(.max),
                    continuousNanoseconds: .max
                )
            )
        }
    }

    @Test(arguments: InstalledL2TemporalMutation.allCases)
    fileprivate func temporalContractRejectsRollbackExpiryAndCrossOrdering(
        _ mutation: InstalledL2TemporalMutation
    ) throws {
        let fixture = try InstalledL2ProjectionFixture()
        #expect(throws: (any Error).self) {
            _ = try fixture.temporalWindow(mutation: mutation)
        }
    }
}

private enum InstalledL2ProjectionSemanticMutation: CaseIterable {
    case zeroEpoch, zeroNonce, reusedUUID
    case appBundle, helperService, driverSigning, machineClaimService
    case shortCodeDirectory, intermediateCodeDirectory, longCodeDirectory
}

private enum InstalledL2TemporalMutation: CaseIterable {
    case foreignProjectionEpoch, foreignClaimProjection
    case claimedAfterStart, wallRollback, wallExpiry
    case continuousRollback, releaseExpiry, releaseAfterEpoch, zeroContinuous
}

private enum InstalledL2ProjectionCommitmentMutation: CaseIterable {
    case epochUUID, configurationNonce, validBefore, configuration, binding, appExecutable
    case helperExecutable, driverExecutable, driverRequirement, driverCodeDirectory
}

private struct InstalledL2ProjectionFixture {
    let epochUUID: UUID
    let configurationNonce: UUID
    let configurationValidBefore: InvestigationHandoffUTCMicroseconds
    let configurationSHA256: InvestigationHandoffSHA256
    let bindingSHA256: InvestigationHandoffSHA256
    let appExecutableSHA256: InvestigationHandoffSHA256
    let helperExecutableSHA256: InvestigationHandoffSHA256
    let driverExecutableSHA256: InvestigationHandoffSHA256
    let driverRequirementSHA256: InvestigationHandoffSHA256
    let driverCodeDirectoryHash = Data(repeating: 0x44, count: 20)

    init() throws {
        epochUUID = try Self.uuid(0x11)
        configurationNonce = try Self.uuid(0x12)
        configurationValidBefore = try .init(rawValue: 2_000_000_030_000_000)
        configurationSHA256 = try Self.digest(0x21)
        bindingSHA256 = try Self.digest(0x22)
        appExecutableSHA256 = try Self.digest(0x31)
        helperExecutableSHA256 = try Self.digest(0x32)
        driverExecutableSHA256 = try Self.digest(0x33)
        driverRequirementSHA256 = try Self.digest(0x34)
    }

    func projection(
        mutation: InstalledL2ProjectionSemanticMutation? = nil,
        commitmentMutation: InstalledL2ProjectionCommitmentMutation? = nil,
        codeDirectoryHash: Data? = nil,
        validBefore: InvestigationHandoffUTCMicroseconds? = nil
    ) throws -> InvestigationInstalledL2IdentityProjection {
        try .init(
            epochUUID: mutation == .zeroEpoch ? Self.zeroUUID
                : commitmentMutation == .epochUUID ? Self.uuid(0x13) : epochUUID,
            configurationNonce: mutation == .zeroNonce ? Self.zeroUUID
                : mutation == .reusedUUID ? epochUUID
                : commitmentMutation == .configurationNonce
                    ? Self.uuid(0x14) : configurationNonce,
            configurationValidBefore: validBefore
                ?? (commitmentMutation == .validBefore
                    ? utc(configurationValidBefore.rawValue + 1)
                    : configurationValidBefore),
            configurationSHA256: commitmentMutation == .configuration
                ? Self.digest(0x41) : configurationSHA256,
            signedRuntimeBindingSHA256: commitmentMutation == .binding
                ? Self.digest(0x42) : bindingSHA256,
            appExecutableSHA256: commitmentMutation == .appExecutable
                ? Self.digest(0x43) : appExecutableSHA256,
            appBundleIdentifier: mutation == .appBundle
                ? "foreign.app" : Self.appBundleIdentifier,
            helperExecutableSHA256: commitmentMutation == .helperExecutable
                ? Self.digest(0x44) : helperExecutableSHA256,
            helperServiceIdentifier: mutation == .helperService
                ? "foreign.helper" : Self.helperServiceIdentifier,
            machineDriverExecutableSHA256: commitmentMutation == .driverExecutable
                ? Self.digest(0x45) : driverExecutableSHA256,
            machineDriverSigningIdentifier: mutation == .driverSigning
                ? "foreign.driver" : Self.driverSigningIdentifier,
            machineDriverDesignatedRequirementSHA256:
                commitmentMutation == .driverRequirement
                    ? Self.digest(0x46) : driverRequirementSHA256,
            machineDriverCodeDirectoryHash: codeDirectoryHash
                ?? mutation.codeDirectoryHash
                ?? (commitmentMutation == .driverCodeDirectory
                    ? Data(repeating: 0x55, count: 20) : driverCodeDirectoryHash),
            machineClaimServiceIdentifier: mutation == .machineClaimService
                ? "foreign.claim" : Self.machineClaimServiceIdentifier
        )
    }

    func goldenEncoded() throws -> Data {
        try Self.data(hexadecimal: Self.goldenProjectionHex)
    }

    func goldenProjectionSHA256() throws -> InvestigationHandoffSHA256 {
        try .init(
            lowercaseHex:
                "3723e09d065ee04d17ea0b5de4a4bf23afffc5c0d51e772770d763accc0ad601"
        )
    }

    func temporalWindow(
        mutation: InstalledL2TemporalMutation
    ) throws -> InvestigationInstalledL2TemporalWindow {
        let claimed = try utc(mutation == .claimedAfterStart ? 102 : 100)
        let startedWall = try utc(101)
        let observedWall = try utc(mutation == .wallRollback ? 100 : 102)
        let wallExpiry = try utc(mutation == .wallExpiry ? 102 : 103)
        let startedContinuous: UInt64 = mutation == .zeroContinuous ? 0 : 200
        let observedContinuous: UInt64 = mutation == .continuousRollback ? 199 : 201
        let release: UInt64 = mutation == .releaseExpiry ? 201 : 202
        let epoch: UInt64 = mutation == .releaseAfterEpoch ? 201 : 202
        let projection = try projection(validBefore: wallExpiry)
        let claimEvidence = try claimEvidence(
            claimedAt: claimed.rawValue,
            releaseDeadlineNanoseconds: release,
            investigationUUID: mutation == .foreignClaimProjection
                ? Self.uuid(0x14) : nil
        )
        return try .init(
            projection: projection,
            claimEvidence: claimEvidence,
            epochBootstrap: .init(
                epochUUID: mutation == .foreignProjectionEpoch
                    ? Self.uuid(0x13) : epochUUID,
                epochDeadlineNanoseconds: epoch
            ),
            started: InvestigationInstalledL2ClockSample(
                wallUTC: startedWall, continuousNanoseconds: startedContinuous
            ),
            observed: InvestigationInstalledL2ClockSample(
                wallUTC: observedWall, continuousNanoseconds: observedContinuous
            )
        )
    }

    func claimEvidence(
        claimedAt: Int64,
        releaseDeadlineNanoseconds: UInt64,
        investigationUUID: UUID? = nil
    ) throws -> InvestigationMachineClaimEvidence {
        let app = try InvestigationMachineProcessIdentity(
            role: .app,
            processID: 42,
            processIDVersion: 7,
            auditSessionID: 8,
            effectiveUserID: 501,
            auditTokenWords: [501, 501, 20, 501, 20, 42, 8, 7]
        )
        let helper = try InvestigationMachineProcessIdentity(
            role: .helper,
            processID: 84,
            processIDVersion: 9,
            auditSessionID: 10,
            effectiveUserID: 0,
            auditTokenWords: [0, 0, 20, 0, 20, 84, 10, 9]
        )
        return try InvestigationMachineClaimEvidence(
            requestBindingSHA256: Self.digest(0x61),
            originalClaimChallenge: Self.uuid(0x62),
            claimConnectionEpoch: Self.uuid(0x63),
            appIdentity: app,
            helperIdentity: helper,
            appUserID: 501,
            recordedAt: utc(95),
            claimedAt: utc(claimedAt),
            ownerRetirement: .init(),
            l1Residue: .init(
                investigationUUID: investigationUUID ?? configurationNonce,
                auditSessionID: helper.auditSessionID,
                userID: 501,
                observedAt: utc(90),
                remainingAuditSessionMembers: 0,
                matchingLeases: 0,
                leaseRootEntries: 0,
                investigationArtifacts: 0
            ),
            releaseDeadlineNanoseconds: releaseDeadlineNanoseconds
        )
    }

    func epochBootstrap(
        epochDeadlineNanoseconds: UInt64
    ) throws -> InvestigationHandoffEpochBootstrap {
        try .init(
            epochUUID: epochUUID,
            epochDeadlineNanoseconds: epochDeadlineNanoseconds
        )
    }

    func utc(_ value: Int64) throws -> InvestigationHandoffUTCMicroseconds {
        try .init(rawValue: value)
    }

    private static func digest(_ byte: UInt8) throws -> InvestigationHandoffSHA256 {
        try .init(rawBytes: Data(repeating: byte, count: 32))
    }
    private static func uuid(_ byte: UInt8) throws -> UUID {
        try #require(UUID(uuidString: String(
            format: "00000000-0000-4000-8000-0000000000%02x", byte
        )))
    }
    private static let zeroUUID = UUID(
        uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    )
    private static func data(hexadecimal: String) throws -> Data {
        let characters = Array(hexadecimal.utf8)
        guard characters.count.isMultiple(of: 2) else {
            throw InstalledL2ProjectionFixtureError.invalidGolden
        }
        var result = Data()
        result.reserveCapacity(characters.count / 2)
        for index in stride(from: 0, to: characters.count, by: 2) {
            guard
                let high = hexNibble(characters[index]),
                let low = hexNibble(characters[index + 1])
            else {
                throw InstalledL2ProjectionFixtureError.invalidGolden
            }
            result.append((high << 4) | low)
        }
        return result
    }

    private static func hexNibble(_ character: UInt8) -> UInt8? {
        switch character {
        case 0x30...0x39: character - 0x30
        case 0x61...0x66: character - 0x61 + 10
        default: nil
        }
    }

    private static let goldenProjectionHex =
        "53544e4300000000003073746f726e6175742e7461736b33392e696e7374616c6c65"
        + "642d6c322e6964656e746974792d70726f6a656374696f6e00010000000400000001"
        + "00020000001000000000000040008000000000000011000300000010000000000000"
        + "4000800000000000001200040000000800071afd4b56c38000050000002021212121"
        + "21212121212121212121212121212121212121212121212121212121000600000020"
        + "22222222222222222222222222222222222222222222222222222222222222220007"
        + "00000020313131313131313131313131313131313131313131313131313131313131"
        + "3131000800000014636f6d2e6572696b6c65652e73746f726e617574000900000020"
        + "3232323232323232323232323232323232323232323232323232323232323232000a"
        + "0000001e636f6d2e6572696b6c65652e73746f726e6175742e6c6966656379636c65"
        + "000b0000002033333333333333333333333333333333333333333333333333333333"
        + "33333333000c00000031636f6d2e6572696b6c65652e73746f726e6175742e696e76"
        + "65737469676174696f6e2e6d616368696e652d647269766572000d00000020343434"
        + "3434343434343434343434343434343434343434343434343434343434000e000000"
        + "144444444444444444444444444444444444444444000f0000002c636f6d2e657269"
        + "6b6c65652e73746f726e6175742e6c6966656379636c652e6d616368696e652d636c"
        + "61696d0010000000203723e09d065ee04d17ea0b5de4a4bf23afffc5c0d51e772770"
        + "d763accc0ad601"
    private static let appBundleIdentifier = "com.eriklee.stornaut"
    private static let helperServiceIdentifier = "com.eriklee.stornaut.lifecycle"
    private static let driverSigningIdentifier =
        "com.eriklee.stornaut.investigation.machine-driver"
    private static let machineClaimServiceIdentifier =
        "com.eriklee.stornaut.lifecycle.machine-claim"
}

private enum InstalledL2ProjectionFixtureError: Error {
    case invalidGolden
}

private extension Optional where Wrapped == InstalledL2ProjectionSemanticMutation {
    var codeDirectoryHash: Data? {
        switch self {
        case .shortCodeDirectory: Data(repeating: 0x44, count: 19)
        case .intermediateCodeDirectory: Data(repeating: 0x44, count: 21)
        case .longCodeDirectory: Data(repeating: 0x44, count: 33)
        default: nil
        }
    }
}
