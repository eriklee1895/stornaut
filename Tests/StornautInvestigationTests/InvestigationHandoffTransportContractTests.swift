import CryptoKit
import Foundation
import Testing
@testable import StornautInvestigationHandoffContract

@Suite("Investigation handoff transport contract")
struct InvestigationHandoffTransportContractTests {
    @Test
    func taggedTranscriptUsesExactGoldenBytes() throws {
        let encoded = try HandoffBinaryTranscript.encode(
            domain: "a",
            businessFields: [Data([0x01])],
            maximumByteCount: 64
        )

        #expect(
            encoded.hexString
                == "53544e430000000000016100010000000400000001"
                    + "00020000000101"
        )
        #expect(
            try HandoffBinaryTranscript.decode(
                encoded,
                expectedDomain: "a",
                expectedBusinessFieldByteCounts: [1...1],
                maximumByteCount: 64
            ) == [Data([0x01])]
        )
    }

    @Test
    func taggedTranscriptRejectsEveryStructuralDrift() throws {
        let valid = try HandoffBinaryTranscript.encode(
            domain: "domain",
            businessFields: [Data([0xaa]), Data([0xbb])],
            maximumByteCount: 128
        )
        let domainFieldByteCount = 6 + "domain".utf8.count
        let versionFieldOffset = 4 + domainFieldByteCount
        let firstBusinessFieldOffset = versionFieldOffset + 10
        let secondBusinessFieldOffset = firstBusinessFieldOffset + 7

        var wrongMagic = valid
        wrongMagic[0] ^= 0xff
        var wrongVersion = valid
        wrongVersion[versionFieldOffset + 9] = 2
        var missingField = valid
        missingField.removeSubrange(firstBusinessFieldOffset..<secondBusinessFieldOffset)
        var duplicateField = valid
        duplicateField.insert(
            contentsOf: valid[firstBusinessFieldOffset..<secondBusinessFieldOffset],
            at: secondBusinessFieldOffset
        )
        var reorderedFields = valid
        reorderedFields[firstBusinessFieldOffset] = 0
        reorderedFields[firstBusinessFieldOffset + 1] = 3
        var zeroLength = valid
        zeroLength.replaceSubrange(
            (firstBusinessFieldOffset + 2)..<(firstBusinessFieldOffset + 6),
            with: [0, 0, 0, 0]
        )
        var unknownField = valid
        unknownField[secondBusinessFieldOffset] = 0
        unknownField[secondBusinessFieldOffset + 1] = 4
        let trailing = valid + Data([0])

        for mutation in [
            wrongMagic,
            wrongVersion,
            missingField,
            duplicateField,
            reorderedFields,
            zeroLength,
            unknownField,
            trailing,
        ] {
            #expect(throws: (any Error).self) {
                _ = try HandoffBinaryTranscript.decode(
                    mutation,
                    expectedDomain: "domain",
                    expectedBusinessFieldByteCounts: [1...1, 1...1],
                    maximumByteCount: 128
                )
            }
        }
    }

    @Test
    func taggedTranscriptRejectsInvalidDomainAndBoundsBeforeAllocation() {
        #expect(throws: (any Error).self) {
            _ = try HandoffBinaryTranscript.encode(
                domain: "",
                businessFields: [Data([1])],
                maximumByteCount: 64
            )
        }
        #expect(throws: (any Error).self) {
            _ = try HandoffBinaryTranscript.encode(
                domain: "non-ascii-ß",
                businessFields: [Data([1])],
                maximumByteCount: 64
            )
        }
        #expect(throws: (any Error).self) {
            _ = try HandoffBinaryTranscript.encode(
                domain: String(repeating: "a", count: 65),
                businessFields: [Data([1])],
                maximumByteCount: 128
            )
        }
        #expect(throws: (any Error).self) {
            _ = try HandoffBinaryTranscript.encode(
                domain: "a",
                businessFields: [Data(repeating: 1, count: 64)],
                maximumByteCount: 32
            )
        }
    }

    @Test
    func sha256HasOneRawWireTruthAndStrictHexAdapter() throws {
        let bytes = Data((0..<32).map(UInt8.init))
        let value = try InvestigationHandoffSHA256(rawBytes: bytes)

        #expect(value.rawBytes == bytes)
        #expect(
            value.lowercaseHex
                == "000102030405060708090a0b0c0d0e0f"
                    + "101112131415161718191a1b1c1d1e1f"
        )
        #expect(
            try InvestigationHandoffSHA256(
                lowercaseHex: value.lowercaseHex
            ) == value
        )
        #expect(
            InvestigationHandoffSHA256.hashing(Data("abc".utf8))
                .lowercaseHex
                == "ba7816bf8f01cfea414140de5dae2223"
                    + "b00361a396177a9cb410ff61f20015ad"
        )

        for invalid in [
            Data(repeating: 0, count: 31),
            Data(repeating: 0, count: 33),
        ] {
            #expect(throws: (any Error).self) {
                _ = try InvestigationHandoffSHA256(rawBytes: invalid)
            }
        }
        for invalid in [
            String(repeating: "a", count: 63),
            String(repeating: "a", count: 65),
            String(repeating: "A", count: 64),
            String(repeating: "z", count: 64),
        ] {
            #expect(throws: (any Error).self) {
                _ = try InvestigationHandoffSHA256(lowercaseHex: invalid)
            }
        }
    }

    @Test
    func utcMicrosecondsUseCheckedConservativeFlooring() throws {
        #expect(
            try InvestigationHandoffUTCMicroseconds(
                timeIntervalSince1970: 1.999_999_9
            ).rawValue == 1_999_999
        )
        #expect(
            try InvestigationHandoffUTCMicroseconds(
                rawValue: 1_999_999
            ).timeIntervalSince1970 == 1.999_999
        )
        for invalid in [
            -1.0,
            0.0,
            Double.infinity,
            Double.nan,
        ] {
            #expect(throws: (any Error).self) {
                _ = try InvestigationHandoffUTCMicroseconds(
                    timeIntervalSince1970: invalid
                )
            }
        }
    }

    @Test
    func scenarioCodesAreClosedAndCanonical() {
        #expect(
            InvestigationHandoffScenario.allCases.map(\.rawValue)
                == Array(UInt32(1)...UInt32(8))
        )
        #expect(
            InvestigationHandoffScenario.allCases.map(\.name) == [
                "success",
                "cancellation",
                "timeout",
                "invalidEnvelope",
                "identityMismatch",
                "transportLoss",
                "lifecycleRecovery",
                "artifactCleanupFailure",
            ]
        )
        #expect(InvestigationHandoffScenario(rawValue: 0) == nil)
        #expect(InvestigationHandoffScenario(rawValue: 9) == nil)
    }

    @Test
    func frameKindsFreezeSequenceDirectionSenderAndPayloadBounds() {
        #expect(
            InvestigationHandoffFrameKind.allCases.map(\.rawValue)
                == Array(UInt16(1)...UInt16(11))
        )
        #expect(
            InvestigationHandoffFrameKind.allCases.map(\.sequence)
                == Array(UInt32(1)...UInt32(11))
        )
        #expect(
            InvestigationHandoffFrameKind.allCases.map(\.direction) == [
                .appToDriver,
                .driverToApp,
                .appToDriver,
                .driverToApp,
                .appToDriver,
                .appToDriver,
                .appToDriver,
                .driverToApp,
                .driverToApp,
                .appToDriver,
                .driverToApp,
            ]
        )
        #expect(
            InvestigationHandoffFrameKind.allCases.map(
                \.expectedSenderEffectiveUserID
            ) == [0, 0, 501, 0, 501, 501, 501, 0, 0, 501, 0]
        )
        #expect(
            InvestigationHandoffFrameKind.configuration
                .admitsPayloadByteCount(1)
        )
        #expect(
            InvestigationHandoffFrameKind.configuration
                .admitsPayloadByteCount(65_536)
        )
        #expect(
            !InvestigationHandoffFrameKind.configuration
                .admitsPayloadByteCount(0)
        )
        #expect(
            !InvestigationHandoffFrameKind.configuration
                .admitsPayloadByteCount(65_537)
        )
        #expect(
            InvestigationHandoffFrameKind.preDropReady
                .admitsPayloadByteCount(0)
        )
        #expect(
            !InvestigationHandoffFrameKind.preDropReady
                .admitsPayloadByteCount(1)
        )
    }

    @Test
    func emptyFrameUsesExactFiftySixByteGoldenEncoding() throws {
        let frame = try InvestigationHandoffFrame(
            kind: .preDropReady,
            epochUUID: try fixedUUID(0x11),
            epochDeadlineNanoseconds: 0x0102_0304_0506_0708,
            sender: try processClaim(
                processID: 42,
                processIDVersion: 7,
                effectiveUserID: 0,
                auditSessionID: 9
            ),
            payload: .empty
        )

        let encoded = try frame.encoded()
        #expect(encoded.count == 56)
        #expect(
            encoded.hexString
                == "53544e48000100010000000000000001"
                    + "00000000000000000000000000000011"
                    + "0102030405060708"
                    + "0000002a000000070000000000000009"
        )
        #expect(try InvestigationHandoffFrame.decode(encoded) == frame)
    }

    @Test
    func frameRejectsHeaderKindSenderAndPayloadDrift() throws {
        let valid = try emptyFrame()
        let validData = try valid.encoded()
        var mutations: [Data] = []

        var wrongMagic = validData
        wrongMagic[0] ^= 0xff
        mutations.append(wrongMagic)
        var wrongVersion = validData
        wrongVersion[5] = 2
        mutations.append(wrongVersion)
        var unknownKind = validData
        unknownKind[6] = 0
        unknownKind[7] = 12
        mutations.append(unknownKind)
        var wrongSequence = validData
        wrongSequence[15] = 2
        mutations.append(wrongSequence)
        var zeroEpoch = validData
        zeroEpoch.replaceSubrange(16..<32, with: repeatElement(UInt8(0), count: 16))
        mutations.append(zeroEpoch)
        var zeroDeadline = validData
        zeroDeadline.replaceSubrange(32..<40, with: repeatElement(UInt8(0), count: 8))
        mutations.append(zeroDeadline)
        var wrongSender = validData
        wrongSender[51] = 1
        mutations.append(wrongSender)
        var unexpectedPayload = validData
        unexpectedPayload[11] = 1
        unexpectedPayload.append(0)
        mutations.append(unexpectedPayload)

        for mutation in mutations {
            #expect(throws: (any Error).self) {
                _ = try InvestigationHandoffFrame.decode(mutation)
            }
        }
        #expect(throws: (any Error).self) {
            _ = try InvestigationHandoffFrame.decode(validData + Data([0]))
        }
    }

    @Test
    func dropEvidenceRoundTripsOnlyExactPostDropFacts() throws {
        let evidence = try dropEvidence()
        let frame = try InvestigationHandoffFrame(
            kind: .dropEvidence,
            epochUUID: try fixedUUID(0x31),
            epochDeadlineNanoseconds: 9_000_000_000,
            sender: try processClaim(
                processID: 42,
                processIDVersion: 7,
                effectiveUserID: 501,
                auditSessionID: 9
            ),
            payload: .dropEvidence(evidence)
        )

        #expect(try InvestigationHandoffFrame.decode(frame.encoded()) == frame)
        #expect(
            evidence.supplementaryGroups
                == Array(UInt32(1)...UInt32(15)) + [20]
        )
        #expect(evidence.auditTokenWords[1] == 501)
        #expect(evidence.auditTokenWords[5] == 42)
        #expect(evidence.auditTokenWords[6] == 9)
        #expect(evidence.auditTokenWords[7] == 7)

        #expect(throws: (any Error).self) {
            _ = try dropEvidence(groups: Array(UInt32(1)...UInt32(15)))
        }
        #expect(throws: (any Error).self) {
            _ = try dropEvidence(
                groups: [2, 1] + Array(UInt32(3)...UInt32(16))
            )
        }
        #expect(throws: (any Error).self) {
            _ = try dropEvidence(setuidErrno: 0)
        }
        #expect(throws: (any Error).self) {
            _ = try dropEvidence(
                auditTokenWords: [501, 501, 21, 501, 20, 42, 9, 7]
            )
        }
    }

    @Test
    func configurationHandleAndAcknowledgementBindOneIdentity() throws {
        let epoch = try cohortEpoch(ordinal: 0)
        let acknowledgement = try configurationAcknowledgement(for: epoch)
        let handle = try retirementHandle(for: epoch)
        let handleAcknowledgement = InvestigationHandoffRetirementHandleAcknowledgement(
            handleSHA256: InvestigationHandoffSHA256.hashing(
                try handle.encoded()
            )
        )

        try epoch.validate(
            configurationAcknowledgement: acknowledgement,
            retirementHandle: handle
        )
        #expect(
            try InvestigationHandoffConfigurationAcknowledgement.decode(
                acknowledgement.encoded()
            ) == acknowledgement
        )
        #expect(
            try InvestigationHandoffRetirementHandle.decode(
                handle.encoded()
            ) == handle
        )
        #expect(
            try InvestigationHandoffRetirementHandleAcknowledgement.decode(
                handleAcknowledgement.encoded()
            ) == handleAcknowledgement
        )

        let foreignHandle = try InvestigationHandoffRetirementHandle(
            token: handle.token,
            investigationUUID: fixedUUID(0xf0),
            retireOperationUUID: handle.retireOperationUUID,
            configurationSHA256: handle.configurationSHA256,
            validBefore: handle.validBefore
        )
        #expect(throws: (any Error).self) {
            try epoch.validate(
                configurationAcknowledgement: acknowledgement,
                retirementHandle: foreignHandle
            )
        }
    }

    @Test
    func singleFrameDecoderRejectsPartialInputAndStreamDecoderAcceptsAnyChunking() throws {
        let first = try emptyFrame()
        let second = try InvestigationHandoffFrame(
            kind: .dropRelease,
            epochUUID: first.epochUUID,
            epochDeadlineNanoseconds: first.epochDeadlineNanoseconds,
            sender: try processClaim(
                processID: 99,
                processIDVersion: 3,
                effectiveUserID: 0,
                auditSessionID: 9
            ),
            payload: .empty
        )
        let firstData = try first.encoded()
        let combined = firstData + (try second.encoded())

        for count in 0..<firstData.count {
            #expect(throws: (any Error).self) {
                _ = try InvestigationHandoffFrame.decode(
                    firstData.prefix(count)
                )
            }
        }

        var decoder = InvestigationHandoffFrameStreamDecoder()
        var decoded: [InvestigationHandoffFrame] = []
        for byte in combined {
            decoded += try decoder.append(Data([byte]))
        }
        try decoder.finish()
        #expect(decoded == [first, second])

        var coalesced = InvestigationHandoffFrameStreamDecoder()
        #expect(try coalesced.append(combined) == [first, second])
        try coalesced.finish()

        var incomplete = InvestigationHandoffFrameStreamDecoder()
        _ = try incomplete.append(firstData.dropLast())
        #expect(throws: (any Error).self) {
            try incomplete.finish()
        }
    }

    @Test
    func streamDecoderRejectsUnadmittedLengthBeforeBufferGrowth() throws {
        var bytes = try emptyFrame().encoded()
        bytes[8] = 0
        bytes[9] = 1
        bytes[10] = 0
        bytes[11] = 1
        var decoder = InvestigationHandoffFrameStreamDecoder()

        #expect(throws: (any Error).self) {
            _ = try decoder.append(bytes.prefix(56))
        }
        #expect(
            InvestigationHandoffFrameStreamDecoder.maximumBufferedByteCount
                == 65_592
        )
    }

    @Test
    func streamDecoderAcceptsCoalescedInputBeyondOneFrameBuffer() throws {
        let frame = try emptyFrame()
        let bytes = try frame.encoded()
        let frameCount = 1_200
        var coalesced = Data()
        coalesced.reserveCapacity(bytes.count * frameCount)
        for _ in 0..<frameCount {
            coalesced.append(bytes)
        }
        #expect(
            coalesced.count
                > InvestigationHandoffFrameStreamDecoder
                    .maximumBufferedByteCount
        )

        var decoder = InvestigationHandoffFrameStreamDecoder()
        let decoded = try decoder.append(coalesced)
        try decoder.finish()

        #expect(decoded.count == frameCount)
        #expect(decoded.allSatisfy { $0 == frame })
    }

    @Test
    func capsuleRoundTripsEightCanonicalEpochsAndSelfDigest() throws {
        let capsule = try cohortCapsule()
        let encoded = try capsule.encoded()
        let decoded = try InvestigationCohortCapsule.decode(encoded)

        #expect(decoded == capsule)
        #expect(encoded.count == 1_984)
        #expect(
            capsule.wholeCapsuleSHA256.lowercaseHex
                == "a5096b18fc2741906a561bedcee18b3168c6d7472bad8e3167c7abbccf634801"
        )
        #expect(
            Data(SHA256.hash(data: encoded)).hexString
                == "47ce5039abd62cdd4e3c5fc011c42af84d9539cb4ccdd26b0723b0fb47df890f"
        )
        #expect(decoded.epochs.count == 8)
        #expect(decoded.epochs.map(\.ordinal) == Array(UInt32(0)...UInt32(7)))
        #expect(
            decoded.epochs.map(\.scenario)
                == InvestigationHandoffScenario.allCases
        )
        #expect(decoded.wholeCapsuleSHA256 == capsule.wholeCapsuleSHA256)
        #expect(encoded.count <= InvestigationCohortCapsule.maximumByteCount)
    }

    @Test
    func capsuleDigestUsesExactZeroBeforeHashRule() throws {
        let capsule = try cohortCapsule()
        let encoded = try capsule.encoded()
        let digestRange = try transcriptPayloadRange(
            tag: 4,
            in: encoded
        )
        var zeroed = encoded
        zeroed.replaceSubrange(
            digestRange,
            with: repeatElement(UInt8(0), count: 32)
        )
        let independentlyComputed = Data(SHA256.hash(data: zeroed))

        #expect(digestRange.count == 32)
        #expect(Data(encoded[digestRange]) == independentlyComputed)
        #expect(capsule.wholeCapsuleSHA256.rawBytes == independentlyComputed)
    }

    @Test
    func capsuleRejectsUUIDScenarioOrderAndDigestDrift() throws {
        let epochs = try (0..<8).map { try cohortEpoch(ordinal: UInt32($0)) }

        var duplicateEpoch = epochs
        duplicateEpoch[1] = try cohortEpoch(
            ordinal: 1,
            epochUUID: epochs[0].epochUUID
        )
        #expect(throws: (any Error).self) {
            _ = try InvestigationCohortCapsule(
                outerAttemptUUID: fixedUUID(1),
                epochs: duplicateEpoch
            )
        }

        var duplicateConfiguration = epochs
        duplicateConfiguration[1] = try cohortEpoch(
            ordinal: 1,
            configurationNonce: epochs[0].configurationNonce
        )
        #expect(throws: (any Error).self) {
            _ = try InvestigationCohortCapsule(
                outerAttemptUUID: fixedUUID(1),
                epochs: duplicateConfiguration
            )
        }

        var reordered = epochs
        reordered.swapAt(0, 1)
        #expect(throws: (any Error).self) {
            _ = try InvestigationCohortCapsule(
                outerAttemptUUID: fixedUUID(1),
                epochs: reordered
            )
        }

        let encoded = try cohortCapsule().encoded()
        var tampered = encoded
        tampered[tampered.index(before: tampered.endIndex)] ^= 0xff
        #expect(throws: (any Error).self) {
            _ = try InvestigationCohortCapsule.decode(tampered)
        }
    }

    @Test
    func epochRejectsConfigurationBoundsAndDigestMismatch() throws {
        #expect(throws: (any Error).self) {
            _ = try cohortEpoch(ordinal: 0, configuration: Data())
        }
        #expect(throws: (any Error).self) {
            _ = try cohortEpoch(
                ordinal: 0,
                configuration: Data(repeating: 0, count: 65_537)
            )
        }

        let maximum = try cohortEpoch(
            ordinal: 0,
            configuration: Data(repeating: 0xab, count: 65_536)
        )
        #expect(maximum.configuration.count == 65_536)

        let configuration = Data("configuration".utf8)
        #expect(throws: (any Error).self) {
            _ = try InvestigationCohortEpoch(
                ordinal: 0,
                epochUUID: fixedUUID(0x10),
                scenario: .success,
                configurationNonce: fixedUUID(0x20),
                configuration: configuration,
                configurationSHA256: try digest(0xee),
                signedRuntimeBindingSHA256: try digest(0x40)
            )
        }
    }

    @Test
    func capsuleRejectsUnknownTagsVersionsLengthAndTrailingBytes() throws {
        let valid = try cohortCapsule().encoded()
        var wrongMagic = valid
        wrongMagic[0] ^= 0xff
        var wrongVersion = valid
        let versionOffset = try transcriptPayloadRange(tag: 1, in: valid)
        wrongVersion[versionOffset.upperBound - 1] = 2
        var unknownTag = valid
        let outerAttemptTagOffset = 4
            + 6 + "stornaut.task39.l3c3cii.cohort".utf8.count
            + 10
        unknownTag[outerAttemptTagOffset] = 0
        unknownTag[outerAttemptTagOffset + 1] = 13
        let trailing = valid + Data([0])

        for mutation in [wrongMagic, wrongVersion, unknownTag, trailing] {
            #expect(throws: (any Error).self) {
                _ = try InvestigationCohortCapsule.decode(mutation)
            }
        }
    }

    @Test
    func projectedCohortInputPreservesV1CapsuleAndPairsEveryProjection() throws {
        let capsule = try cohortCapsule()
        let capsuleBytes = try capsule.encoded()
        let input = try projectedCohortInput(capsule: capsule)
        let encoded = try input.encoded()
        let decoded = try InvestigationProjectedCohortInput.decode(encoded)

        #expect(try decoded.capsule.encoded() == capsuleBytes)
        #expect(decoded.capsule == capsule)
        #expect(decoded.projections.count == 8)
        #expect(decoded.wholeInputSHA256 == input.wholeInputSHA256)
        #expect(try decoded.encoded() == encoded)
        #expect(
            InvestigationProjectedCohortInput.maximumByteCount
                == 1_069_056
        )
        #expect(!(InvestigationProjectedCohortInput.self is any Codable.Type))
        for index in 0..<InvestigationCohortCapsule.epochCount {
            let selection = try decoded.selection(at: index)
            #expect(selection.epoch == capsule.epochs[index])
            #expect(selection.projection == decoded.projections[index])
            #expect(selection.projection.epochUUID == selection.epoch.epochUUID)
            #expect(
                selection.projection.configurationNonce
                    == selection.epoch.configurationNonce
            )
            #expect(
                selection.projection.configurationSHA256
                    == selection.epoch.configurationSHA256
            )
            #expect(
                selection.projection.signedRuntimeBindingSHA256
                    == selection.epoch.signedRuntimeBindingSHA256
            )
        }
        #expect(throws: (any Error).self) {
            _ = try decoded.selection(at: 8)
        }
    }

    @Test
    func projectedCohortInputDigestUsesExactZeroBeforeHashRule() throws {
        let encoded = try projectedCohortInput().encoded()
        let digestRange = try transcriptPayloadRange(tag: 4, in: encoded)
        var zeroed = encoded
        zeroed.replaceSubrange(
            digestRange,
            with: repeatElement(UInt8(0), count: 32)
        )

        #expect(
            Data(encoded[digestRange])
                == Data(SHA256.hash(data: zeroed))
        )
    }

    @Test(arguments: ProjectedCohortBindingMutation.allCases)
    fileprivate func projectedCohortInputRejectsEveryBindingMismatch(
        _ mutation: ProjectedCohortBindingMutation
    ) throws {
        let capsule = try cohortCapsule()
        var projections = try capsule.epochs.map {
            try projectedIdentity($0)
        }
        projections[3] = try projectedIdentity(
            capsule.epochs[3],
            mutation: mutation
        )

        #expect(throws: (any Error).self) {
            _ = try InvestigationProjectedCohortInput(
                capsule: capsule,
                projections: projections
            )
        }
    }

    @Test
    func projectedCohortInputRejectsCountOrderAndDigestDrift() throws {
        let input = try projectedCohortInput()
        let capsule = input.capsule
        #expect(throws: (any Error).self) {
            _ = try InvestigationProjectedCohortInput(
                capsule: capsule,
                projections: Array(input.projections.dropLast())
            )
        }
        var reordered = input.projections
        reordered.swapAt(0, 1)
        #expect(throws: (any Error).self) {
            _ = try InvestigationProjectedCohortInput(
                capsule: capsule,
                projections: reordered
            )
        }

        let encoded = try input.encoded()
        var digestDrift = encoded
        let digestRange = try transcriptPayloadRange(tag: 4, in: encoded)
        digestDrift[digestRange.lowerBound] ^= 0xff
        for mutation in [
            try capsule.encoded(),
            digestDrift,
            Data(encoded.dropLast()),
            encoded + Data([0]),
        ] {
            #expect(throws: (any Error).self) {
                _ = try InvestigationProjectedCohortInput.decode(mutation)
            }
        }
    }

    @Test
    func projectedCohortInputRejectsNestedProjectionDrift() throws {
        let encoded = try projectedCohortInput().encoded()
        let firstProjection = try transcriptPayloadRange(tag: 5, in: encoded)
        let firstProjectionDigest = try transcriptPayloadRange(
            tag: 16,
            in: Data(encoded[firstProjection])
        )
        var mutation = encoded
        mutation[firstProjection.lowerBound + firstProjectionDigest.lowerBound]
            ^= 0xff
        let outerDigest = try transcriptPayloadRange(tag: 4, in: mutation)
        mutation.replaceSubrange(
            outerDigest,
            with: repeatElement(UInt8(0), count: 32)
        )
        mutation.replaceSubrange(
            outerDigest,
            with: Data(SHA256.hash(data: mutation))
        )

        #expect(throws: (any Error).self) {
            _ = try InvestigationProjectedCohortInput.decode(mutation)
        }
    }

    @Test
    func projectedCohortInputRejectsEveryOuterStructuralDrift() throws {
        let valid = try projectedCohortInput().encoded()
        let domain = try transcriptPayloadRange(tag: 0, in: valid)
        let version = try transcriptPayloadRange(tag: 1, in: valid)
        let capsule = try transcriptPayloadRange(tag: 2, in: valid)
        let count = try transcriptPayloadRange(tag: 3, in: valid)

        var wrongMagic = valid
        wrongMagic[0] ^= 0xff
        var wrongDomain = valid
        wrongDomain[domain.lowerBound] ^= 0x01
        var wrongVersion = valid
        wrongVersion[version.upperBound - 1] = 2
        var unknownTag = valid
        unknownTag[capsule.lowerBound - 5] = 13
        var lengthDrift = valid
        lengthDrift[capsule.lowerBound - 1] ^= 0x01
        var countDrift = valid
        countDrift[count.upperBound - 1] = 7

        for mutation in [
            wrongMagic, wrongDomain, wrongVersion, unknownTag, lengthDrift,
            countDrift,
        ] {
            #expect(throws: (any Error).self) {
                _ = try InvestigationProjectedCohortInput.decode(mutation)
            }
        }
    }

    @Test
    func projectedCohortInputRejectsNestedCapsuleDrift() throws {
        let encoded = try projectedCohortInput().encoded()
        let capsuleRange = try transcriptPayloadRange(tag: 2, in: encoded)
        let capsuleDigest = try transcriptPayloadRange(
            tag: 4,
            in: Data(encoded[capsuleRange])
        )
        var mutation = encoded
        mutation[capsuleRange.lowerBound + capsuleDigest.lowerBound] ^= 0xff
        let outerDigest = try transcriptPayloadRange(tag: 4, in: mutation)
        mutation.replaceSubrange(
            outerDigest,
            with: repeatElement(UInt8(0), count: 32)
        )
        mutation.replaceSubrange(
            outerDigest,
            with: Data(SHA256.hash(data: mutation))
        )

        #expect(throws: (any Error).self) {
            _ = try InvestigationProjectedCohortInput.decode(mutation)
        }
    }
}

private enum ProjectedCohortBindingMutation: CaseIterable {
    case epochUUID
    case configurationNonce
    case configurationSHA256
    case signedRuntimeBindingSHA256
}

private extension InvestigationHandoffTransportContractTests {
    func fixedUUID(_ finalByte: UInt8) throws -> UUID {
        let value = String(format: "%02x", finalByte)
        return try #require(
            UUID(
                uuidString: "00000000-0000-0000-0000-0000000000"
                    + value
            )
        )
    }

    func digest(_ byte: UInt8) throws -> InvestigationHandoffSHA256 {
        try InvestigationHandoffSHA256(
            rawBytes: Data(repeating: byte, count: 32)
        )
    }

    func processClaim(
        processID: UInt32,
        processIDVersion: UInt32,
        effectiveUserID: UInt32,
        auditSessionID: UInt32
    ) throws -> InvestigationHandoffProcessClaim {
        try InvestigationHandoffProcessClaim(
            processID: processID,
            processIDVersion: processIDVersion,
            effectiveUserID: effectiveUserID,
            auditSessionID: auditSessionID
        )
    }

    func emptyFrame() throws -> InvestigationHandoffFrame {
        try InvestigationHandoffFrame(
            kind: .preDropReady,
            epochUUID: fixedUUID(0x11),
            epochDeadlineNanoseconds: 0x0102_0304_0506_0708,
            sender: processClaim(
                processID: 42,
                processIDVersion: 7,
                effectiveUserID: 0,
                auditSessionID: 9
            ),
            payload: .empty
        )
    }

    func dropEvidence(
        groups: [UInt32] = Array(UInt32(1)...UInt32(15)) + [20],
        setuidErrno: UInt32 = 1,
        auditTokenWords: [UInt32] = [501, 501, 20, 501, 20, 42, 9, 7]
    ) throws -> InvestigationHandoffDropEvidence {
        try InvestigationHandoffDropEvidence(
            realUserID: 501,
            effectiveUserID: 501,
            savedUserID: 501,
            realGroupID: 20,
            effectiveGroupID: 20,
            savedGroupID: 20,
            supplementaryGroups: groups,
            auditTokenWords: auditTokenWords,
            setuidRootErrno: setuidErrno,
            seteuidRootErrno: 1,
            setgidRootErrno: 1
        )
    }

    func cohortEpoch(
        ordinal: UInt32,
        epochUUID: UUID? = nil,
        configurationNonce: UUID? = nil,
        configuration: Data? = nil
    ) throws -> InvestigationCohortEpoch {
        let bytes = configuration
            ?? Data(("configuration-" + String(ordinal)).utf8)
        let scenario = try #require(
            InvestigationHandoffScenario(rawValue: ordinal + 1)
        )
        return try InvestigationCohortEpoch(
            ordinal: ordinal,
            epochUUID: epochUUID ?? fixedUUID(UInt8(0x10 + ordinal)),
            scenario: scenario,
            configurationNonce:
                configurationNonce ?? fixedUUID(UInt8(0x20 + ordinal)),
            configuration: bytes,
            configurationSHA256: .hashing(bytes),
            signedRuntimeBindingSHA256: digest(UInt8(0x40 + ordinal))
        )
    }

    func cohortCapsule() throws -> InvestigationCohortCapsule {
        try InvestigationCohortCapsule(
            outerAttemptUUID: fixedUUID(1),
            epochs: (0..<8).map { try cohortEpoch(ordinal: UInt32($0)) }
        )
    }

    func projectedCohortInput(
        capsule: InvestigationCohortCapsule? = nil
    ) throws -> InvestigationProjectedCohortInput {
        let capsule = try capsule ?? cohortCapsule()
        return try InvestigationProjectedCohortInput(
            capsule: capsule,
            projections: capsule.epochs.map {
                try projectedIdentity($0)
            }
        )
    }

    func projectedIdentity(
        _ epoch: InvestigationCohortEpoch,
        mutation: ProjectedCohortBindingMutation? = nil
    ) throws -> InvestigationInstalledL2IdentityProjection {
        let ordinal = UInt8(epoch.ordinal)
        return try InvestigationInstalledL2IdentityProjection(
            epochUUID: mutation == .epochUUID
                ? fixedUUID(UInt8(0x70 + ordinal)) : epoch.epochUUID,
            configurationNonce: mutation == .configurationNonce
                ? fixedUUID(UInt8(0x78 + ordinal))
                : epoch.configurationNonce,
            configurationValidBefore: .init(
                rawValue: 2_000_000_000_000_000 + Int64(ordinal)
            ),
            configurationSHA256: mutation == .configurationSHA256
                ? digest(0x91) : epoch.configurationSHA256,
            signedRuntimeBindingSHA256:
                mutation == .signedRuntimeBindingSHA256
                    ? digest(0x92) : epoch.signedRuntimeBindingSHA256,
            appExecutableSHA256: digest(0x51),
            appBundleIdentifier:
                InvestigationInstalledL2IdentityProjection
                .fixedAppBundleIdentifier,
            helperExecutableSHA256: digest(0x52),
            helperServiceIdentifier:
                InvestigationInstalledL2IdentityProjection
                .fixedHelperServiceIdentifier,
            machineDriverExecutableSHA256: digest(0x53),
            machineDriverSigningIdentifier:
                InvestigationInstalledL2IdentityProjection
                .fixedMachineDriverSigningIdentifier,
            machineDriverDesignatedRequirementSHA256: digest(0x54),
            machineDriverCodeDirectoryHash: Data(
                repeating: 0x55, count: 20
            ),
            machineClaimServiceIdentifier:
                InvestigationInstalledL2IdentityProjection
                .fixedMachineClaimServiceIdentifier
        )
    }

    func configurationAcknowledgement(
        for epoch: InvestigationCohortEpoch
    ) throws -> InvestigationHandoffConfigurationAcknowledgement {
        try InvestigationHandoffConfigurationAcknowledgement(
            epochUUID: epoch.epochUUID,
            ordinal: epoch.ordinal,
            configurationNonce: epoch.configurationNonce,
            scenario: epoch.scenario,
            configurationSHA256: epoch.configurationSHA256,
            signedRuntimeBindingSHA256:
                epoch.signedRuntimeBindingSHA256
        )
    }

    func retirementHandle(
        for epoch: InvestigationCohortEpoch
    ) throws -> InvestigationHandoffRetirementHandle {
        try InvestigationHandoffRetirementHandle(
            token: fixedUUID(0x70),
            investigationUUID: epoch.configurationNonce,
            retireOperationUUID: fixedUUID(0x71),
            configurationSHA256: epoch.configurationSHA256,
            validBefore: try InvestigationHandoffUTCMicroseconds(
                rawValue: 2_000_000
            )
        )
    }

    func transcriptPayloadRange(
        tag expectedTag: UInt16,
        in data: Data
    ) throws -> Range<Data.Index> {
        var offset = 4
        while offset < data.count {
            let tag = UInt16(data[offset]) << 8
                | UInt16(data[offset + 1])
            let length = Int(data[offset + 2]) << 24
                | Int(data[offset + 3]) << 16
                | Int(data[offset + 4]) << 8
                | Int(data[offset + 5])
            let payload = (offset + 6)..<(offset + 6 + length)
            if tag == expectedTag {
                return payload
            }
            offset = payload.upperBound
        }
        throw HandoffTestError.fieldMissing
    }
}

private enum HandoffTestError: Error {
    case fieldMissing
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
