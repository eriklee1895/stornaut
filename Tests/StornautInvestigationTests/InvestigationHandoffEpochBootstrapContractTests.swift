import Foundation
import Testing
@testable import StornautInvestigationHandoffContract

@Suite("Investigation handoff epoch bootstrap contract")
struct InvestigationHandoffEpochBootstrapContractTests {
    @Test
    func bootstrapUsesTheExactThirtyTwoByteGoldenVector() throws {
        let bootstrap = try InvestigationHandoffEpochBootstrap(
            epochUUID: fixedUUID(0x11),
            epochDeadlineNanoseconds: 0x0102_0304_0506_0708
        )

        let encoded = bootstrap.encoded()
        #expect(
            encoded.hexString
                == "53544e5000010020"
                    + "00000000000000000000000000000011"
                    + "0102030405060708"
        )
        #expect(encoded.count == 32)
        #expect(
            try InvestigationHandoffEpochBootstrap.decode(encoded)
                == bootstrap
        )
    }

    @Test
    func constantsFreezeMagicVersionAndTotalSize() {
        #expect(InvestigationHandoffEpochBootstrap.magic == 0x5354_4e50)
        #expect(InvestigationHandoffEpochBootstrap.version == 1)
        #expect(InvestigationHandoffEpochBootstrap.byteCount == 32)
    }

    @Test
    func bootstrapRejectsZeroEpochIdentityAndDeadline() throws {
        #expect(throws: (any Error).self) {
            _ = try InvestigationHandoffEpochBootstrap(
                epochUUID: zeroUUID(),
                epochDeadlineNanoseconds: 1
            )
        }
        #expect(throws: (any Error).self) {
            _ = try InvestigationHandoffEpochBootstrap(
                epochUUID: fixedUUID(0x11),
                epochDeadlineNanoseconds: 0
            )
        }
    }

    @Test
    func decoderRejectsMagicVersionAndDeclaredSizeDrift() throws {
        let valid = try bootstrap().encoded()
        var wrongMagic = valid
        wrongMagic[0] ^= 0xff
        var wrongVersion = valid
        wrongVersion[5] = 2
        var shortDeclaredSize = valid
        shortDeclaredSize[7] = 31
        var longDeclaredSize = valid
        longDeclaredSize[7] = 33
        var littleEndianVersion = valid
        littleEndianVersion.replaceSubrange(4..<6, with: [1, 0])
        var littleEndianSize = valid
        littleEndianSize.replaceSubrange(6..<8, with: [32, 0])

        for mutation in [
            wrongMagic,
            wrongVersion,
            shortDeclaredSize,
            longDeclaredSize,
            littleEndianVersion,
            littleEndianSize,
        ] {
            #expect(throws: (any Error).self) {
                _ = try InvestigationHandoffEpochBootstrap.decode(mutation)
            }
        }
    }

    @Test
    func decoderRejectsEveryPartialTrailingAndOversizedInput() throws {
        let valid = try bootstrap().encoded()
        for count in 0..<InvestigationHandoffEpochBootstrap.byteCount {
            #expect(throws: (any Error).self) {
                _ = try InvestigationHandoffEpochBootstrap.decode(
                    Data(valid.prefix(count))
                )
            }
        }
        for mutation in [
            valid + Data([0]),
            valid + Data(repeating: 0, count: 1_024),
        ] {
            #expect(throws: (any Error).self) {
                _ = try InvestigationHandoffEpochBootstrap.decode(mutation)
            }
        }
    }

    @Test
    func decoderRejectsZeroValuesAndReadsDeadlineBigEndian() throws {
        let valid = try bootstrap().encoded()
        var zeroEpoch = valid
        zeroEpoch.replaceSubrange(8..<24, with: repeatElement(UInt8(0), count: 16))
        var zeroDeadline = valid
        zeroDeadline.replaceSubrange(24..<32, with: repeatElement(UInt8(0), count: 8))

        for mutation in [zeroEpoch, zeroDeadline] {
            #expect(throws: (any Error).self) {
                _ = try InvestigationHandoffEpochBootstrap.decode(mutation)
            }
        }

        var reversedDeadline = valid
        reversedDeadline.replaceSubrange(
            24..<32,
            with: valid[24..<32].reversed()
        )
        #expect(
            try InvestigationHandoffEpochBootstrap
                .decode(reversedDeadline)
                .epochDeadlineNanoseconds == 0x0807_0605_0403_0201
        )
    }

    @Test
    func bootstrapCarriesOnlyEpochIdentityAndDeadline() throws {
        let encoded = try bootstrap().encoded()
        let forbiddenPayloads = [
            Data("configuration".utf8),
            Data("/private/tmp/path".utf8),
            Data("com.eriklee.stornaut.lifecycle.machine-claim".utf8),
            Data(repeating: 0x70, count: 32),
        ]
        #expect(forbiddenPayloads.allSatisfy { encoded.range(of: $0) == nil })
    }
}

private extension InvestigationHandoffEpochBootstrapContractTests {
    func bootstrap() throws -> InvestigationHandoffEpochBootstrap {
        try InvestigationHandoffEpochBootstrap(
            epochUUID: fixedUUID(0x11),
            epochDeadlineNanoseconds: 0x0102_0304_0506_0708
        )
    }

    func fixedUUID(_ finalByte: UInt8) throws -> UUID {
        let suffix = String(format: "%02x", finalByte)
        return try #require(UUID(
            uuidString: "00000000-0000-0000-0000-0000000000" + suffix
        ))
    }

    func zeroUUID() -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
