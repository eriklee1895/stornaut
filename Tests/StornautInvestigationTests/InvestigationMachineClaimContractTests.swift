import Foundation
import Testing
@testable import StornautInvestigationHandoffContract

@Suite("Investigation machine claim binary contract")
struct InvestigationMachineClaimContractTests {
    @Test
    func claimRequestUsesExactNestedGoldenBytesAndWholeRequestBinding() throws {
        let request = try claimRequest()
        let encoded = try request.encoded()

        let goldenRequest =
            "53544e4300000000002573746f726e6175742e7461736b33392e"
                    + "6d616368696e652d636c61696d2e726571756573740001000000"
                    + "04000000010002000000b353544e4300000000002973746f726e6175742e"
                    + "7461736b33392e68616e646f66662e7265746972656d656e742d68"
                    + "616e646c6500010000000400000001000200000010000000000000000000"
                    + "000000000000100003000000100000000000000000000000000000"
                    + "00110004000000100000000000000000000000000000001200050000"
                    + "00201313131313131313131313131313131313131313131313131313"
                    + "13131313131300060000000800000000001e84800003000000100000"
                    + "000000000000000000000000002000040000000800000000000f4240"
                    + "000500000008000000000016e3600006000000100000000000000000"
                    + "00000000000000210007000000080102030405060708"
        #expect(encoded.hexString == goldenRequest)
        #expect(try InvestigationMachineRetirementClaimRequest.decode(encoded) == request)
        #expect(
            try request.bindingSHA256().lowercaseHex
                == "23b4e8ff69eca805e0831ab6bd259826"
                    + "440ff6ad1b3971e5812406a3e5f68ba4"
        )
        #expect(
            encoded.occurrenceCount(of: uuidBytes(try fixedUUID(0x10))) == 1
        )
        #expect(encoded.count <= InvestigationMachineRetirementClaimRequest.maximumByteCount)
    }

    @Test
    func claimRequestRejectsWindowDeadlineUUIDAndNestedTranscriptDrift() throws {
        let handle = try retirementHandle()
        let issuedAt = try utc(1_000_000)

        for validBefore in [1_000_000, 16_000_001, 2_000_001] {
            #expect(throws: (any Error).self) {
                _ = try InvestigationMachineRetirementClaimRequest(
                    handle: handle,
                    claimChallenge: fixedUUID(0x20),
                    issuedAt: issuedAt,
                    requestValidBefore: utc(Int64(validBefore)),
                    claimConnectionEpoch: fixedUUID(0x21),
                    epochDeadlineNanoseconds: 1
                )
            }
        }
        for zeroField in [0, 1] {
            #expect(throws: (any Error).self) {
                _ = try InvestigationMachineRetirementClaimRequest(
                    handle: handle,
                    claimChallenge:
                        zeroField == 0 ? zeroUUID() : fixedUUID(0x20),
                    issuedAt: issuedAt,
                    requestValidBefore: utc(1_500_000),
                    claimConnectionEpoch:
                        zeroField == 1 ? zeroUUID() : fixedUUID(0x21),
                    epochDeadlineNanoseconds: 1
                )
            }
        }
        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineRetirementClaimRequest(
                handle: handle,
                claimChallenge: fixedUUID(0x20),
                issuedAt: issuedAt,
                requestValidBefore: utc(1_500_000),
                claimConnectionEpoch: fixedUUID(0x21),
                epochDeadlineNanoseconds: 0
            )
        }

        let valid = try claimRequest().encoded()
        let fields = try transcriptFields(valid)
        let requestBusinessFields = Array(fields.dropFirst(2))
        let missing = try HandoffBinaryTranscript.encode(
            domain: InvestigationMachineRetirementClaimRequest.domain,
            businessFields: Array(requestBusinessFields.dropLast()),
            maximumByteCount: InvestigationMachineRetirementClaimRequest.maximumByteCount
        )
        let duplicate = try HandoffBinaryTranscript.encode(
            domain: InvestigationMachineRetirementClaimRequest.domain,
            businessFields: requestBusinessFields + [requestBusinessFields.last!],
            maximumByteCount: InvestigationMachineRetirementClaimRequest.maximumByteCount
        )
        var permuted = valid
        let firstBusinessTag = try transcriptTagOffset(tag: 2, in: permuted)
        permuted[firstBusinessTag + 1] = 3
        var malformedNested = requestBusinessFields
        malformedNested[0].append(0)
        let invalidNested = try HandoffBinaryTranscript.encode(
            domain: InvestigationMachineRetirementClaimRequest.domain,
            businessFields: malformedNested,
            maximumByteCount: InvestigationMachineRetirementClaimRequest.maximumByteCount
        )

        for mutation in [missing, duplicate, permuted, invalidNested, valid + Data([0])] {
            #expect(throws: (any Error).self) {
                _ = try InvestigationMachineRetirementClaimRequest.decode(mutation)
            }
        }
    }

    @Test
    func processIdentityFreezesRoleAndAllFourAuditTokenAxes() throws {
        let app = try appIdentity()
        let helper = try helperIdentity()

        #expect(try InvestigationMachineProcessIdentity.decode(app.encoded()) == app)
        #expect(try InvestigationMachineProcessIdentity.decode(helper.encoded()) == helper)
        #expect(app.role == .app)
        #expect(helper.role == .helper)
        #expect(app.effectiveUserID == 501)
        #expect(helper.effectiveUserID == 0)

        for invalid: [UInt32] in [
            [501, 501, 20, 501, 20, 43, 9, 7],
            [501, 502, 20, 501, 20, 42, 9, 7],
            [501, 501, 20, 501, 20, 42, 10, 7],
            [501, 501, 20, 501, 20, 42, 9, 8],
            [501, 501, 20, 501, 20, 42, 9],
        ] {
            #expect(throws: (any Error).self) {
                _ = try InvestigationMachineProcessIdentity(
                    role: .app,
                    processID: 42,
                    processIDVersion: 7,
                    auditSessionID: 9,
                    effectiveUserID: 501,
                    auditTokenWords: invalid
                )
            }
        }
        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineProcessIdentity(
                role: .helper,
                processID: 42,
                processIDVersion: 7,
                auditSessionID: 9,
                effectiveUserID: 501,
                auditTokenWords: [501, 501, 20, 501, 20, 42, 9, 7]
            )
        }
        var unknownRole = try app.encoded()
        let rolePayload = try transcriptPayloadRange(tag: 2, in: unknownRole)
        unknownRole[rolePayload.lowerBound] = 3
        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineProcessIdentity.decode(unknownRole)
        }
    }

    @Test
    func helperIdentityDigestUsesDistinctDomainAndExactGoldenBytes() throws {
        let helper = try helperIdentity()
        let transcript = try helper.helperIdentityTranscript()

        let goldenIdentity =
            "53544e4300000000002d73746f726e6175742e7461736b33392e"
                    + "6d616368696e652d636c61696d2e68656c7065722d6964656e74"
                    + "697479000100000004000000010002000000040000005400030000000400"
                    + "000008000400000004000000090005000000040000000000060000"
                    + "000400000000000700000004000000000008000000040000001400"
                    + "090000000400000000000a0000000400000014000b000000040000"
                    + "0054000c0000000400000009000d0000000400000008"
        #expect(transcript.hexString == goldenIdentity)
        #expect(
            try helper.helperIdentitySHA256().lowercaseHex
                == "4a162a07401f35f263992223ce5f5fc2"
                    + "310e438f7ef3e59650957574245e31c0"
        )
        #expect(
            transcript != (try helper.encoded())
        )
        #expect(throws: (any Error).self) {
            _ = try appIdentity().helperIdentitySHA256()
        }
    }

    @Test
    func ownerRetirementAndL1ResidueAdmitOnlyClosedTerminalFacts() throws {
        let owner = InvestigationMachineOwnerRetirement()
        let ownerBytes = try owner.encoded()
        let goldenOwner =
            "53544e4300000000002e73746f726e6175742e7461736b33392e"
                    + "6d616368696e652d636c61696d2e6f776e65722d726574697265"
                    + "6d656e740001000000040000000100020000000102000300000001010004"
                    + "000000010100050000000101"
        #expect(ownerBytes.hexString == goldenOwner)
        #expect(try InvestigationMachineOwnerRetirement.decode(ownerBytes) == owner)

        var invalidOwner = ownerBytes
        let ownership = try transcriptPayloadRange(tag: 2, in: invalidOwner)
        invalidOwner[ownership.lowerBound] = 1
        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineOwnerRetirement.decode(invalidOwner)
        }

        let residue = try l1Residue()
        #expect(try InvestigationMachineL1Residue.decode(residue.encoded()) == residue)
        for counts in [
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [0, 0, 0, 1],
        ] {
            #expect(throws: (any Error).self) {
                _ = try InvestigationMachineL1Residue(
                    investigationUUID: fixedUUID(0x11),
                    auditSessionID: 9,
                    userID: 501,
                    observedAt: utc(900_000),
                    remainingAuditSessionMembers: UInt32(counts[0]),
                    matchingLeases: UInt32(counts[1]),
                    leaseRootEntries: UInt32(counts[2]),
                    investigationArtifacts: UInt32(counts[3])
                )
            }
        }
    }

    @Test
    func evidenceRoundTripsCompleteNestedFactsWithoutHandleOrToken() throws {
        let evidence = try claimEvidence()
        let encoded = try evidence.encoded()
        let decoded = try InvestigationMachineClaimEvidence.decode(encoded)

        #expect(decoded == evidence)
        let goldenEvidence =
            "53544e4300000000002673746f726e6175742e7461736b33392e6d616368"
                + "696e652d636c61696d2e65766964656e6365000100000004000000010002"
                + "0000002023b4e8ff69eca805e0831ab6bd259826440ff6ad1b3971e58124"
                + "06a3e5f68ba4000300000010000000000000000000000000000000200004"
                + "000000100000000000000000000000000000002100050000009753544e43"
                + "00000000002e73746f726e6175742e7461736b33392e6d616368696e652d"
                + "636c61696d2e70726f636573732d6964656e746974790001000000040000"
                + "0001000200000001010003000000040000002a0004000000040000000700"
                + "050000000400000009000600000004000001f5000700000020000001f500"
                + "0001f500000014000001f5000000140000002a0000000900000007000600"
                + "00009753544e4300000000002e73746f726e6175742e7461736b33392e6d"
                + "616368696e652d636c61696d2e70726f636573732d6964656e7469747900"
                + "010000000400000001000200000001020003000000040000005400040000"
                + "000400000008000500000004000000090006000000040000000000070000"
                + "002000000000000000000000001400000000000000140000005400000009"
                + "00000008000700000004000001f500080000000800000000000e7ef00009"
                + "00000008000000000013d620000a0000005e53544e4300000000002e7374"
                + "6f726e6175742e7461736b33392e6d616368696e652d636c61696d2e6f77"
                + "6e65722d7265746972656d656e7400010000000400000001000200000001"
                + "02000300000001010004000000010100050000000101000b0000009c5354"
                + "4e4300000000002873746f726e6175742e7461736b33392e6d616368696e"
                + "652d636c61696d2e6c312d72657369647565000100000004000000010002"
                + "000000100000000000000000000000000000001100030000000400000009"
                + "000400000004000001f500050000000800000000000dbba0000600000004"
                + "000000000007000000040000000000080000000400000000000900000004"
                + "00000000000c000000081112131415161718"
        #expect(encoded.count == 768)
        #expect(encoded.hexString == goldenEvidence)
        #expect(encoded.count <= InvestigationMachineClaimEvidence.maximumByteCount)
        #expect(!encoded.containsSubsequence(uuidBytes(try fixedUUID(0x10))))
        #expect(!encoded.containsSubsequence(try retirementHandle().encoded()))
        #expect(decoded.appIdentity.role == .app)
        #expect(decoded.helperIdentity.role == .helper)
        #expect(decoded.ownerRetirement == InvestigationMachineOwnerRetirement())
        #expect(decoded.l1Residue.remainingAuditSessionMembers == 0)
        #expect(decoded.l1Residue.matchingLeases == 0)
        #expect(decoded.l1Residue.leaseRootEntries == 0)
        #expect(decoded.l1Residue.investigationArtifacts == 0)
    }

    @Test
    func evidenceRejectsTimestampAndNestedRoleDrift() throws {
        #expect(throws: (any Error).self) {
            _ = try claimEvidence(recordedAt: 1_300_001, claimedAt: 1_300_000)
        }
        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineClaimEvidence(
                requestBindingSHA256: digest(0x31),
                originalClaimChallenge: fixedUUID(0x20),
                claimConnectionEpoch: fixedUUID(0x21),
                appIdentity: appIdentity(),
                helperIdentity: helperIdentity(),
                appUserID: 501,
                recordedAt: utc(950_000),
                claimedAt: utc(1_300_000),
                ownerRetirement: InvestigationMachineOwnerRetirement(),
                l1Residue: l1Residue(observedAt: 950_001),
                releaseDeadlineNanoseconds: 1
            )
        }
        #expect(throws: (any Error).self) {
            _ = try claimEvidence(
                appIdentity: helperIdentity(),
                helperIdentity: appIdentity()
            )
        }
        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineClaimEvidence(
                requestBindingSHA256: digest(0x31),
                originalClaimChallenge: fixedUUID(0x20),
                claimConnectionEpoch: fixedUUID(0x21),
                appIdentity: appIdentity(),
                helperIdentity: helperIdentity(),
                appUserID: 501,
                recordedAt: utc(1_200_000),
                claimedAt: utc(1_300_000),
                ownerRetirement: InvestigationMachineOwnerRetirement(),
                l1Residue: l1Residue(),
                releaseDeadlineNanoseconds: 0
            )
        }
    }

    @Test
    func contextualValidationRejectsEveryImmutableExpectationDrift() throws {
        let request = try claimRequest()
        let evidence = try claimEvidence(request: request)
        try evidence.validate(against: expectation(request: request))

        let alternateSessionApp = try appIdentity(auditSessionID: 10)
        let alternateSessionHelper = try helperIdentity(auditSessionID: 10)
        let identityMutations = [
            try expectation(
                request: request,
                appIdentity: alternateSessionApp,
                helperIdentity: alternateSessionHelper
            ),
            try expectation(request: request, appIdentity: alternateAppIdentity()),
            try expectation(request: request, helperIdentity: alternateHelperIdentity()),
        ]
        for mutation in identityMutations {
            #expect(throws: (any Error).self) {
                try evidence.validate(against: mutation)
            }
        }
        #expect(throws: (any Error).self) {
            _ = try expectation(request: request, appUserID: 502)
        }

        let requestExpectation = try InvestigationMachineClaimExpectation(
            request: request,
            appUserID: 501,
            appIdentity: appIdentity(),
            helperIdentity: helperIdentity()
        )
        let requestBinding = try request.bindingSHA256()
        #expect(
            requestExpectation.requestBindingSHA256
                == requestBinding
        )
        #expect(requestExpectation.originalClaimChallenge == request.claimChallenge)
        #expect(requestExpectation.investigationUUID == request.handle.investigationUUID)

        let deadlineMutation = try claimRequest(
            epochDeadlineNanoseconds: 0x0102_0304_0506_0709
        )
        #expect(throws: (any Error).self) {
            try evidence.validate(against: expectation(request: deadlineMutation))
        }

        let requestMutations = [
            try claimRequest(claimChallenge: fixedUUID(0x22)),
            try claimRequest(claimConnectionEpoch: fixedUUID(0x23)),
            try claimRequest(investigationUUID: fixedUUID(0x14)),
            try claimRequest(issuedAt: 900_000),
            try claimRequest(issuedAt: 1_400_000),
            try claimRequest(requestValidBefore: 1_300_000),
        ]
        for mutation in requestMutations {
            let mutationBinding = try mutation.bindingSHA256()
            let evidenceWithMatchingBinding = try claimEvidence(
                request: request,
                requestBindingSHA256: mutationBinding
            )
            #expect(throws: (any Error).self) {
                try evidenceWithMatchingBinding.validate(
                    against: expectation(request: mutation)
                )
            }
        }
    }

    @Test
    func evidenceRejectsEveryOuterAndNestedStructuralDrift() throws {
        let valid = try claimEvidence().encoded()
        let fields = try transcriptFields(valid)
        let business = Array(fields.dropFirst(2))
        let missing = try HandoffBinaryTranscript.encode(
            domain: InvestigationMachineClaimEvidence.domain,
            businessFields: Array(business.dropLast()),
            maximumByteCount: InvestigationMachineClaimEvidence.maximumByteCount
        )
        let duplicate = try HandoffBinaryTranscript.encode(
            domain: InvestigationMachineClaimEvidence.domain,
            businessFields: business + [business.last!],
            maximumByteCount: InvestigationMachineClaimEvidence.maximumByteCount
        )
        var permuted = valid
        let firstTag = try transcriptTagOffset(tag: 2, in: permuted)
        permuted[firstTag + 1] = 3
        var nestedAppTrailing = business
        nestedAppTrailing[3].append(0)
        let appTrailing = try HandoffBinaryTranscript.encode(
            domain: InvestigationMachineClaimEvidence.domain,
            businessFields: nestedAppTrailing,
            maximumByteCount: InvestigationMachineClaimEvidence.maximumByteCount
        )
        var nestedMutations: [Data] = [appTrailing]
        let appFields = Array(
            try transcriptFields(business[3]).dropFirst(2)
        )
        let helperFields = Array(
            try transcriptFields(business[4]).dropFirst(2)
        )
        var nested = business
        nested[3] = try HandoffBinaryTranscript.encode(
            domain: InvestigationMachineProcessIdentity.domain,
            businessFields: Array(appFields.dropLast()),
            maximumByteCount: InvestigationMachineProcessIdentity.maximumByteCount
        )
        nestedMutations.append(try encodedEvidence(fields: nested))
        nested = business
        nested[4] = try HandoffBinaryTranscript.encode(
            domain: InvestigationMachineProcessIdentity.domain,
            businessFields: helperFields + [helperFields.last!],
            maximumByteCount: InvestigationMachineProcessIdentity.maximumByteCount
        )
        nestedMutations.append(try encodedEvidence(fields: nested))
        nested = business
        var ownerPermutation = nested[8]
        let ownerTag = try transcriptTagOffset(tag: 2, in: ownerPermutation)
        ownerPermutation[ownerTag + 1] = 3
        nested[8] = ownerPermutation
        nestedMutations.append(try encodedEvidence(fields: nested))
        let residueFields = Array(
            try transcriptFields(business[9]).dropFirst(2)
        )
        nested = business
        nested[9] = try HandoffBinaryTranscript.encode(
            domain: InvestigationMachineL1Residue.domain + "-x",
            businessFields: residueFields,
            maximumByteCount: InvestigationMachineL1Residue.maximumByteCount
        )
        nestedMutations.append(try encodedEvidence(fields: nested))
        nested = business
        var residueVersion = nested[9]
        let version = try transcriptPayloadRange(tag: 1, in: residueVersion)
        residueVersion[version.upperBound - 1] = 2
        nested[9] = residueVersion
        nestedMutations.append(try encodedEvidence(fields: nested))

        for mutation in [missing, duplicate, permuted, valid + Data([0])]
            + nestedMutations
        {
            #expect(throws: (any Error).self) {
                _ = try InvestigationMachineClaimEvidence.decode(mutation)
            }
        }
    }

    @Test
    func releaseAndReleasedUseExactGoldenBytesAndNoReversibleProjection() throws {
        let release = try claimRelease(requestBindingSHA256: digest(0x31))
        let released = try claimReleased(requestBindingSHA256: digest(0x31))
        let releaseBytes = try release.encoded()
        let releasedBytes = try released.encoded()

        let requestDigest = String(repeating: "31", count: 32)
        let helperDigest =
            "4a162a07401f35f263992223ce5f5fc2"
                + "310e438f7ef3e59650957574245e31c0"
        let challenge = String(repeating: "00", count: 15) + "40"
        let connectionEpoch = String(repeating: "00", count: 15) + "21"
        let goldenRelease =
            "53544e4300000000002573746f726e6175742e7461736b33392e"
                + "6d616368696e652d636c61696d2e72656c65617365"
                + "00010000000400000001"
                + "000200000020" + requestDigest
                + "000300000010" + challenge
                + "000400000020" + helperDigest
                + "000500000010" + connectionEpoch
                + "0006000000081112131415161718"
        let goldenReleased =
            "53544e4300000000002673746f726e6175742e7461736b33392e"
                + "6d616368696e652d636c61696d2e72656c6561736564"
                + "00010000000400000001"
                + "000200000020" + requestDigest
                + "000300000010" + challenge
                + "000400000020" + helperDigest
                + "000500000010" + connectionEpoch
                + "00060000000101"
                + "0007000000082122232425262728"
        #expect(releaseBytes.hexString == goldenRelease)
        #expect(releasedBytes.hexString == goldenReleased)
        #expect(try InvestigationMachineClaimRelease.decode(releaseBytes) == release)
        #expect(try InvestigationMachineClaimReleased.decode(releasedBytes) == released)
        #expect(!releaseBytes.containsSubsequence(uuidBytes(try fixedUUID(0x10))))
        #expect(!releasedBytes.containsSubsequence(uuidBytes(try fixedUUID(0x10))))
        #expect(releaseBytes.count <= InvestigationMachineClaimRelease.maximumByteCount)
        #expect(releasedBytes.count <= InvestigationMachineClaimReleased.maximumByteCount)
    }

    @Test
    func releaseValidationRejectsDigestIdentityConnectionChallengeAndDeadlineDrift() throws {
        let evidence = try claimEvidence()
        let release = try claimRelease()
        let released = try claimReleased()
        try release.validate(
            against: evidence,
            expectedReleaseChallenge: fixedUUID(0x40)
        )
        try released.validateEcho(of: release)
        #expect(
            released.postReplyExitDeadlineNanoseconds
                != release.releaseDeadlineNanoseconds
        )

        let releaseMutations = [
            try claimRelease(requestBindingSHA256: digest(0x32)),
            try claimRelease(releaseChallenge: fixedUUID(0x41)),
            try claimRelease(claimedHelperIdentitySHA256: digest(0x42)),
            try claimRelease(claimConnectionEpoch: fixedUUID(0x22)),
            try claimRelease(releaseDeadlineNanoseconds: 0x1112_1314_1516_1719),
        ]
        for mutation in releaseMutations {
            #expect(throws: (any Error).self) {
                try mutation.validate(
                    against: evidence,
                    expectedReleaseChallenge: fixedUUID(0x40)
                )
            }
        }

        let releasedMutations = [
            try claimReleased(requestBindingSHA256: digest(0x32)),
            try claimReleased(releaseChallenge: fixedUUID(0x41)),
            try claimReleased(claimedHelperIdentitySHA256: digest(0x42)),
            try claimReleased(claimConnectionEpoch: fixedUUID(0x22)),
        ]
        for mutation in releasedMutations {
            #expect(throws: (any Error).self) {
                try mutation.validateEcho(of: release)
            }
        }
        #expect(throws: (any Error).self) {
            _ = try claimRelease(releaseChallenge: zeroUUID())
        }
        #expect(throws: (any Error).self) {
            _ = try claimReleased(postReplyExitDeadlineNanoseconds: 0)
        }
        var notScheduled = try released.encoded()
        let scheduledPayload = try transcriptPayloadRange(
            tag: 6,
            in: notScheduled
        )
        notScheduled[scheduledPayload.lowerBound] = 0
        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineClaimReleased.decode(notScheduled)
        }
    }

    @Test
    func frozenLimitsSeparateWireValuesFromLaterClockOwnership() {
        #expect(InvestigationMachineRetirementClaimRequest.maximumByteCount == 1_024)
        #expect(
            InvestigationMachineRetirementClaimRequest
                .maximumWallWindowMicroseconds == 15_000_000
        )
        #expect(InvestigationMachineClaimEvidence.maximumByteCount == 4_096)
        #expect(InvestigationMachineClaimRelease.maximumByteCount == 1_024)
        #expect(
            InvestigationMachineClaimRelease.maximumReleaseWindowNanoseconds
                == 5_000_000_000
        )
        #expect(InvestigationMachineClaimReleased.maximumByteCount == 1_024)
        #expect(
            InvestigationMachineClaimReleased.maximumPostReplyExitWindowNanoseconds
                == 5_000_000_000
        )
    }

    @Test
    func sharedXPCProtocolHasOnlyTheTwoExactDataSelectors() {
        #expect(
            NSStringFromProtocol(InvestigationMachineClaimXPCWire.self)
                == "StornautInvestigationMachineClaimXPCWire"
        )
        #expect(
            NSStringFromSelector(#selector(
                InvestigationMachineClaimXPCWire
                    .claimMachineRetirement(_:withReply:)
            )) == "claimMachineRetirement:withReply:"
        )
        #expect(
            NSStringFromSelector(#selector(
                InvestigationMachineClaimXPCWire
                    .releaseMachineRetirement(_:withReply:)
            )) == "releaseMachineRetirement:withReply:"
        )
    }

    @Test
    func XPCReplyShapeAndClosedReasonKeysFailClosed() throws {
        let claimPayload = try claimEvidence().encoded()
        let releasePayload = try claimReleased().encoded()
        #expect(
            try InvestigationMachineClaimXPCReply.validateClaim(
                response: claimPayload,
                reasonKey: nil
            ) == .success(claimPayload)
        )
        #expect(
            try InvestigationMachineClaimXPCReply.validateRelease(
                response: releasePayload,
                reasonKey: nil
            ) == .success(releasePayload)
        )
        for reason in InvestigationMachineClaimXPCReason.allCases {
            #expect(
                try InvestigationMachineClaimXPCReply.validateClaim(
                    response: nil,
                    reasonKey: reason.rawValue
                ) == .failure(reason)
            )
        }
        #expect(
            InvestigationMachineClaimXPCReason.allCases.map(\.rawValue) == [
                "runtime.lifecycle.machine-claim.invalid-request",
                "runtime.lifecycle.machine-claim.invalid-peer",
                "runtime.lifecycle.machine-claim.empty",
                "runtime.lifecycle.machine-claim.consumed",
                "runtime.lifecycle.machine-claim.expired",
                "runtime.lifecycle.machine-claim.mismatch",
                "runtime.lifecycle.machine-claim.unavailable",
            ]
        )
        for untrusted in [
            "",
            "unknown",
            "runtime.lifecycle.machine-claim.unavailable-ß",
            String(repeating: "a", count: 129),
        ] {
            #expect(
                try InvestigationMachineClaimXPCReply.validateClaim(
                    response: nil,
                    reasonKey: untrusted
                ) == .failure(.unavailable)
            )
        }
        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineClaimXPCReply.validateClaim(
                response: nil,
                reasonKey: nil
            )
        }
        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineClaimXPCReply.validateClaim(
                response: claimPayload,
                reasonKey: InvestigationMachineClaimXPCReason.unavailable.rawValue
            )
        }
        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineClaimXPCReply.validateClaim(
                response: Data(repeating: 1, count: 4_097),
                reasonKey: nil
            )
        }
        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineClaimXPCReply.validateRelease(
                response: Data(repeating: 1, count: 1_025),
                reasonKey: nil
            )
        }
        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineClaimXPCReply.validateClaim(
                response: Data([1]),
                reasonKey: nil
            )
        }
        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineClaimXPCReply.validateRelease(
                response: Data([1]),
                reasonKey: nil
            )
        }
    }

    @Test
    func XPCRequestBoundsAreCheckedBeforeAnyDecoderRuns() throws {
        let claim = try claimRequest().encoded()
        let release = try claimRelease().encoded()
        try InvestigationMachineClaimXPCRequest.validateClaim(claim)
        try InvestigationMachineClaimXPCRequest.validateRelease(release)
        #expect(throws: (any Error).self) {
            try InvestigationMachineClaimXPCRequest.validateClaim(Data())
        }
        #expect(throws: (any Error).self) {
            try InvestigationMachineClaimXPCRequest.validateClaim(
                Data(repeating: 0, count: 1_025)
            )
        }
        #expect(throws: (any Error).self) {
            try InvestigationMachineClaimXPCRequest.validateRelease(
                Data(repeating: 0, count: 1_025)
            )
        }
        #expect(throws: (any Error).self) {
            try InvestigationMachineClaimXPCRequest.validateClaim(Data([1]))
        }
        #expect(throws: (any Error).self) {
            try InvestigationMachineClaimXPCRequest.validateRelease(Data([1]))
        }
    }
}

private extension InvestigationMachineClaimContractTests {
    func fixedUUID(_ finalByte: UInt8) throws -> UUID {
        let suffix = String(format: "%02x", finalByte)
        return try #require(UUID(
            uuidString: "00000000-0000-0000-0000-0000000000" + suffix
        ))
    }

    func zeroUUID() -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    }

    func uuidBytes(_ value: UUID) -> Data {
        var bytes = value.uuid
        return withUnsafeBytes(of: &bytes) { Data($0) }
    }

    func digest(_ byte: UInt8) throws -> InvestigationHandoffSHA256 {
        try InvestigationHandoffSHA256(
            rawBytes: Data(repeating: byte, count: 32)
        )
    }

    func utc(_ rawValue: Int64) throws -> InvestigationHandoffUTCMicroseconds {
        try InvestigationHandoffUTCMicroseconds(rawValue: rawValue)
    }

    func retirementHandle() throws -> InvestigationHandoffRetirementHandle {
        try InvestigationHandoffRetirementHandle(
            token: fixedUUID(0x10),
            investigationUUID: fixedUUID(0x11),
            retireOperationUUID: fixedUUID(0x12),
            configurationSHA256: digest(0x13),
            validBefore: utc(2_000_000)
        )
    }

    func claimRequest(
        claimChallenge: UUID? = nil,
        claimConnectionEpoch: UUID? = nil,
        investigationUUID: UUID? = nil,
        issuedAt: Int64 = 1_000_000,
        requestValidBefore: Int64 = 1_500_000,
        epochDeadlineNanoseconds: UInt64 = 0x0102_0304_0506_0708
    ) throws -> InvestigationMachineRetirementClaimRequest {
        let handle = try InvestigationHandoffRetirementHandle(
            token: fixedUUID(0x10),
            investigationUUID: investigationUUID ?? fixedUUID(0x11),
            retireOperationUUID: fixedUUID(0x12),
            configurationSHA256: digest(0x13),
            validBefore: utc(2_000_000)
        )
        return try InvestigationMachineRetirementClaimRequest(
            handle: handle,
            claimChallenge: claimChallenge ?? fixedUUID(0x20),
            issuedAt: utc(issuedAt),
            requestValidBefore: utc(requestValidBefore),
            claimConnectionEpoch:
                claimConnectionEpoch ?? fixedUUID(0x21),
            epochDeadlineNanoseconds: epochDeadlineNanoseconds
        )
    }

    func appIdentity(
        processID: UInt32 = 42,
        processIDVersion: UInt32 = 7,
        auditSessionID: UInt32 = 9
    ) throws -> InvestigationMachineProcessIdentity {
        try InvestigationMachineProcessIdentity(
            role: .app,
            processID: processID,
            processIDVersion: processIDVersion,
            auditSessionID: auditSessionID,
            effectiveUserID: 501,
            auditTokenWords: [
                501, 501, 20, 501, 20, processID,
                auditSessionID, processIDVersion,
            ]
        )
    }

    func alternateAppIdentity() throws -> InvestigationMachineProcessIdentity {
        try appIdentity(processID: 43, processIDVersion: 17)
    }

    func helperIdentity(
        processID: UInt32 = 84,
        processIDVersion: UInt32 = 8,
        auditSessionID: UInt32 = 9
    ) throws -> InvestigationMachineProcessIdentity {
        try InvestigationMachineProcessIdentity(
            role: .helper,
            processID: processID,
            processIDVersion: processIDVersion,
            auditSessionID: auditSessionID,
            effectiveUserID: 0,
            auditTokenWords: [
                0, 0, 20, 0, 20, processID,
                auditSessionID, processIDVersion,
            ]
        )
    }

    func alternateHelperIdentity() throws -> InvestigationMachineProcessIdentity {
        try helperIdentity(processID: 85, processIDVersion: 18)
    }

    func l1Residue(
        investigationUUID: UUID? = nil,
        auditSessionID: UInt32 = 9,
        userID: UInt32 = 501,
        observedAt: Int64 = 900_000
    ) throws -> InvestigationMachineL1Residue {
        try InvestigationMachineL1Residue(
            investigationUUID: investigationUUID ?? fixedUUID(0x11),
            auditSessionID: auditSessionID,
            userID: userID,
            observedAt: utc(observedAt),
            remainingAuditSessionMembers: 0,
            matchingLeases: 0,
            leaseRootEntries: 0,
            investigationArtifacts: 0
        )
    }

    func claimEvidence(
        request: InvestigationMachineRetirementClaimRequest? = nil,
        requestBindingSHA256: InvestigationHandoffSHA256? = nil,
        originalClaimChallenge: UUID? = nil,
        claimConnectionEpoch: UUID? = nil,
        appIdentity: InvestigationMachineProcessIdentity? = nil,
        helperIdentity: InvestigationMachineProcessIdentity? = nil,
        recordedAt: Int64 = 950_000,
        claimedAt: Int64 = 1_300_000,
        releaseDeadlineNanoseconds: UInt64 = 0x1112_1314_1516_1718
    ) throws -> InvestigationMachineClaimEvidence {
        let boundRequest = try request ?? claimRequest()
        return try InvestigationMachineClaimEvidence(
            requestBindingSHA256:
                requestBindingSHA256 ?? boundRequest.bindingSHA256(),
            originalClaimChallenge:
                originalClaimChallenge ?? boundRequest.claimChallenge,
            claimConnectionEpoch:
                claimConnectionEpoch ?? boundRequest.claimConnectionEpoch,
            appIdentity: appIdentity ?? self.appIdentity(),
            helperIdentity: helperIdentity ?? self.helperIdentity(),
            appUserID: 501,
            recordedAt: utc(recordedAt),
            claimedAt: utc(claimedAt),
            ownerRetirement: InvestigationMachineOwnerRetirement(),
            l1Residue: l1Residue(),
            releaseDeadlineNanoseconds: releaseDeadlineNanoseconds
        )
    }

    func expectation(
        request: InvestigationMachineRetirementClaimRequest? = nil,
        appUserID: UInt32 = 501,
        appIdentity: InvestigationMachineProcessIdentity? = nil,
        helperIdentity: InvestigationMachineProcessIdentity? = nil
    ) throws -> InvestigationMachineClaimExpectation {
        try InvestigationMachineClaimExpectation(
            request: request ?? claimRequest(),
            appUserID: appUserID,
            appIdentity: appIdentity ?? self.appIdentity(),
            helperIdentity: helperIdentity ?? self.helperIdentity()
        )
    }

    func claimRelease(
        requestBindingSHA256: InvestigationHandoffSHA256? = nil,
        releaseChallenge: UUID? = nil,
        claimedHelperIdentitySHA256: InvestigationHandoffSHA256? = nil,
        claimConnectionEpoch: UUID? = nil,
        releaseDeadlineNanoseconds: UInt64 = 0x1112_1314_1516_1718
    ) throws -> InvestigationMachineClaimRelease {
        try InvestigationMachineClaimRelease(
            requestBindingSHA256:
                requestBindingSHA256 ?? claimRequest().bindingSHA256(),
            releaseChallenge: releaseChallenge ?? fixedUUID(0x40),
            claimedHelperIdentitySHA256:
                claimedHelperIdentitySHA256
                ?? helperIdentity().helperIdentitySHA256(),
            claimConnectionEpoch: claimConnectionEpoch ?? fixedUUID(0x21),
            releaseDeadlineNanoseconds: releaseDeadlineNanoseconds
        )
    }

    func claimReleased(
        requestBindingSHA256: InvestigationHandoffSHA256? = nil,
        releaseChallenge: UUID? = nil,
        claimedHelperIdentitySHA256: InvestigationHandoffSHA256? = nil,
        claimConnectionEpoch: UUID? = nil,
        postReplyExitDeadlineNanoseconds: UInt64 = 0x2122_2324_2526_2728
    ) throws -> InvestigationMachineClaimReleased {
        try InvestigationMachineClaimReleased(
            requestBindingSHA256:
                requestBindingSHA256 ?? claimRequest().bindingSHA256(),
            releaseChallenge: releaseChallenge ?? fixedUUID(0x40),
            claimedHelperIdentitySHA256:
                claimedHelperIdentitySHA256
                ?? helperIdentity().helperIdentitySHA256(),
            claimConnectionEpoch: claimConnectionEpoch ?? fixedUUID(0x21),
            exitScheduled: true,
            postReplyExitDeadlineNanoseconds: postReplyExitDeadlineNanoseconds
        )
    }

    func transcriptFields(_ data: Data) throws -> [Data] {
        var fields: [Data] = []
        var offset = 4
        while offset < data.count {
            guard offset + 6 <= data.count else { throw ClaimContractTestError.invalid }
            let length = Int(data[offset + 2]) << 24
                | Int(data[offset + 3]) << 16
                | Int(data[offset + 4]) << 8
                | Int(data[offset + 5])
            let payload = (offset + 6)..<(offset + 6 + length)
            guard payload.upperBound <= data.count else {
                throw ClaimContractTestError.invalid
            }
            fields.append(data.subdata(in: payload))
            offset = payload.upperBound
        }
        return fields
    }

    func encodedEvidence(fields: [Data]) throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: InvestigationMachineClaimEvidence.domain,
            businessFields: fields,
            maximumByteCount: InvestigationMachineClaimEvidence.maximumByteCount
        )
    }

    func transcriptTagOffset(tag expectedTag: UInt16, in data: Data) throws -> Int {
        var offset = 4
        while offset < data.count {
            guard offset + 6 <= data.count else { throw ClaimContractTestError.invalid }
            let tag = UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
            let length = Int(data[offset + 2]) << 24
                | Int(data[offset + 3]) << 16
                | Int(data[offset + 4]) << 8
                | Int(data[offset + 5])
            if tag == expectedTag { return offset }
            offset += 6 + length
        }
        throw ClaimContractTestError.invalid
    }

    func transcriptPayloadRange(
        tag expectedTag: UInt16,
        in data: Data
    ) throws -> Range<Data.Index> {
        let offset = try transcriptTagOffset(tag: expectedTag, in: data)
        let length = Int(data[offset + 2]) << 24
            | Int(data[offset + 3]) << 16
            | Int(data[offset + 4]) << 8
            | Int(data[offset + 5])
        return (offset + 6)..<(offset + 6 + length)
    }
}

private enum ClaimContractTestError: Error {
    case invalid
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }

    func containsSubsequence(_ candidate: Data) -> Bool {
        range(of: candidate) != nil
    }

    func occurrenceCount(of candidate: Data) -> Int {
        guard !candidate.isEmpty else { return 0 }
        var count = 0
        var cursor = startIndex
        while cursor < endIndex,
              let range = range(of: candidate, in: cursor..<endIndex)
        {
            count += 1
            cursor = range.upperBound
        }
        return count
    }
}
