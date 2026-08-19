import Foundation

package struct InvestigationMachineRetirementClaimRequest:
    Sendable,
    Equatable
{
    package static let domain =
        "stornaut.task39.machine-claim.request"
    package static let maximumByteCount = 1_024
    package static let maximumWallWindowMicroseconds: Int64 = 15_000_000

    package let handle: InvestigationHandoffRetirementHandle
    package let claimChallenge: UUID
    package let issuedAt: InvestigationHandoffUTCMicroseconds
    package let requestValidBefore: InvestigationHandoffUTCMicroseconds
    package let claimConnectionEpoch: UUID
    package let epochDeadlineNanoseconds: UInt64

    package init(
        handle: InvestigationHandoffRetirementHandle,
        claimChallenge: UUID,
        issuedAt: InvestigationHandoffUTCMicroseconds,
        requestValidBefore: InvestigationHandoffUTCMicroseconds,
        claimConnectionEpoch: UUID,
        epochDeadlineNanoseconds: UInt64
    ) throws {
        guard
            handoffUUIDIsNonzero(claimChallenge),
            handoffUUIDIsNonzero(claimConnectionEpoch),
            epochDeadlineNanoseconds > 0,
            issuedAt < requestValidBefore,
            requestValidBefore <= handle.validBefore,
            requestValidBefore.rawValue - issuedAt.rawValue
                <= Self.maximumWallWindowMicroseconds
        else {
            throw InvestigationHandoffContractError.invalidValue
        }
        self.handle = handle
        self.claimChallenge = claimChallenge
        self.issuedAt = issuedAt
        self.requestValidBefore = requestValidBefore
        self.claimConnectionEpoch = claimConnectionEpoch
        self.epochDeadlineNanoseconds = epochDeadlineNanoseconds
    }

    package func encoded() throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: Self.domain,
            businessFields: [
                handle.encoded(),
                handoffData(claimChallenge),
                handoffData(issuedAt.rawValue),
                handoffData(requestValidBefore.rawValue),
                handoffData(claimConnectionEpoch),
                handoffData(epochDeadlineNanoseconds),
            ],
            maximumByteCount: Self.maximumByteCount
        )
    }

    package func bindingSHA256() throws -> InvestigationHandoffSHA256 {
        .hashing(try encoded())
    }

    package static func decode(_ data: Data) throws -> Self {
        let fields = try HandoffBinaryTranscript.decode(
            data,
            expectedDomain: domain,
            expectedBusinessFieldByteCounts: [
                1...InvestigationHandoffRetirementHandle.maximumByteCount,
                16...16,
                8...8,
                8...8,
                16...16,
                8...8,
            ],
            maximumByteCount: maximumByteCount
        )
        return try Self(
            handle: InvestigationHandoffRetirementHandle.decode(fields[0]),
            claimChallenge: handoffUUID(fields[1]),
            issuedAt: InvestigationHandoffUTCMicroseconds(
                rawValue: handoffDecodeInt64(fields[2])
            ),
            requestValidBefore: InvestigationHandoffUTCMicroseconds(
                rawValue: handoffDecodeInt64(fields[3])
            ),
            claimConnectionEpoch: handoffUUID(fields[4]),
            epochDeadlineNanoseconds: handoffDecodeUInt64(fields[5])
        )
    }
}

package enum InvestigationMachineProcessRole:
    UInt8,
    Sendable,
    CaseIterable
{
    case app = 0x01
    case helper = 0x02

    var requiredEffectiveUserID: UInt32 {
        switch self {
        case .app: 501
        case .helper: 0
        }
    }
}

package struct InvestigationMachineProcessIdentity:
    Sendable,
    Equatable
{
    package static let domain =
        "stornaut.task39.machine-claim.process-identity"
    package static let helperIdentityDomain =
        "stornaut.task39.machine-claim.helper-identity"
    package static let maximumByteCount = 1_024

    package let role: InvestigationMachineProcessRole
    package let processID: UInt32
    package let processIDVersion: UInt32
    package let auditSessionID: UInt32
    package let effectiveUserID: UInt32
    package let auditTokenWords: [UInt32]

    package init(
        role: InvestigationMachineProcessRole,
        processID: UInt32,
        processIDVersion: UInt32,
        auditSessionID: UInt32,
        effectiveUserID: UInt32,
        auditTokenWords: [UInt32]
    ) throws {
        guard
            processID > 1,
            processIDVersion > 0,
            auditSessionID > 0,
            effectiveUserID == role.requiredEffectiveUserID,
            auditTokenWords.count == 8,
            auditTokenWords[1] == effectiveUserID,
            auditTokenWords[5] == processID,
            auditTokenWords[6] == auditSessionID,
            auditTokenWords[7] == processIDVersion
        else {
            throw InvestigationHandoffContractError.invalidValue
        }
        self.role = role
        self.processID = processID
        self.processIDVersion = processIDVersion
        self.auditSessionID = auditSessionID
        self.effectiveUserID = effectiveUserID
        self.auditTokenWords = auditTokenWords
    }

    package func encoded() throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: Self.domain,
            businessFields: [
                handoffData(role.rawValue),
                handoffData(processID),
                handoffData(processIDVersion),
                handoffData(auditSessionID),
                handoffData(effectiveUserID),
                claimUInt32ArrayData(auditTokenWords),
            ],
            maximumByteCount: Self.maximumByteCount
        )
    }

    package static func decode(_ data: Data) throws -> Self {
        let fields = try HandoffBinaryTranscript.decode(
            data,
            expectedDomain: domain,
            expectedBusinessFieldByteCounts: [
                1...1, 4...4, 4...4, 4...4, 4...4, 32...32,
            ],
            maximumByteCount: maximumByteCount
        )
        guard let role = InvestigationMachineProcessRole(
            rawValue: fields[0][fields[0].startIndex]
        ) else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        return try Self(
            role: role,
            processID: handoffDecodeUInt32(fields[1]),
            processIDVersion: handoffDecodeUInt32(fields[2]),
            auditSessionID: handoffDecodeUInt32(fields[3]),
            effectiveUserID: handoffDecodeUInt32(fields[4]),
            auditTokenWords: try claimDecodeUInt32Array(
                fields[5],
                expectedCount: 8
            )
        )
    }

    package func helperIdentityTranscript() throws -> Data {
        guard role == .helper else {
            throw InvestigationHandoffContractError.invalidValue
        }
        return try HandoffBinaryTranscript.encode(
            domain: Self.helperIdentityDomain,
            businessFields: [
                handoffData(processID),
                handoffData(processIDVersion),
                handoffData(auditSessionID),
                handoffData(effectiveUserID),
            ] + auditTokenWords.map(handoffData),
            maximumByteCount: Self.maximumByteCount
        )
    }

    package func helperIdentitySHA256() throws -> InvestigationHandoffSHA256 {
        .hashing(try helperIdentityTranscript())
    }
}

package struct InvestigationMachineOwnerRetirement:
    Sendable,
    Equatable
{
    package static let domain =
        "stornaut.task39.machine-claim.owner-retirement"
    package static let maximumByteCount = 512

    package init() {}

    package func encoded() throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: Self.domain,
            businessFields: [
                handoffData(UInt8(0x02)),
                handoffData(UInt8(0x01)),
                handoffData(UInt8(0x01)),
                handoffData(UInt8(0x01)),
            ],
            maximumByteCount: Self.maximumByteCount
        )
    }

    package static func decode(_ data: Data) throws -> Self {
        let fields = try HandoffBinaryTranscript.decode(
            data,
            expectedDomain: domain,
            expectedBusinessFieldByteCounts: [1...1, 1...1, 1...1, 1...1],
            maximumByteCount: maximumByteCount
        )
        guard fields.map({ $0[$0.startIndex] }) == [0x02, 0x01, 0x01, 0x01] else {
            throw InvestigationHandoffContractError.invalidValue
        }
        return Self()
    }
}

package struct InvestigationMachineL1Residue:
    Sendable,
    Equatable
{
    package static let domain =
        "stornaut.task39.machine-claim.l1-residue"
    package static let maximumByteCount = 1_024

    package let investigationUUID: UUID
    package let auditSessionID: UInt32
    package let userID: UInt32
    package let observedAt: InvestigationHandoffUTCMicroseconds
    package let remainingAuditSessionMembers: UInt32
    package let matchingLeases: UInt32
    package let leaseRootEntries: UInt32
    package let investigationArtifacts: UInt32

    package init(
        investigationUUID: UUID,
        auditSessionID: UInt32,
        userID: UInt32,
        observedAt: InvestigationHandoffUTCMicroseconds,
        remainingAuditSessionMembers: UInt32,
        matchingLeases: UInt32,
        leaseRootEntries: UInt32,
        investigationArtifacts: UInt32
    ) throws {
        guard
            handoffUUIDIsNonzero(investigationUUID),
            auditSessionID > 0,
            userID == 501,
            remainingAuditSessionMembers == 0,
            matchingLeases == 0,
            leaseRootEntries == 0,
            investigationArtifacts == 0
        else {
            throw InvestigationHandoffContractError.invalidValue
        }
        self.investigationUUID = investigationUUID
        self.auditSessionID = auditSessionID
        self.userID = userID
        self.observedAt = observedAt
        self.remainingAuditSessionMembers = remainingAuditSessionMembers
        self.matchingLeases = matchingLeases
        self.leaseRootEntries = leaseRootEntries
        self.investigationArtifacts = investigationArtifacts
    }

    package func encoded() throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: Self.domain,
            businessFields: [
                handoffData(investigationUUID),
                handoffData(auditSessionID),
                handoffData(userID),
                handoffData(observedAt.rawValue),
                handoffData(remainingAuditSessionMembers),
                handoffData(matchingLeases),
                handoffData(leaseRootEntries),
                handoffData(investigationArtifacts),
            ],
            maximumByteCount: Self.maximumByteCount
        )
    }

    package static func decode(_ data: Data) throws -> Self {
        let fields = try HandoffBinaryTranscript.decode(
            data,
            expectedDomain: domain,
            expectedBusinessFieldByteCounts: [
                16...16, 4...4, 4...4, 8...8,
                4...4, 4...4, 4...4, 4...4,
            ],
            maximumByteCount: maximumByteCount
        )
        return try Self(
            investigationUUID: handoffUUID(fields[0]),
            auditSessionID: handoffDecodeUInt32(fields[1]),
            userID: handoffDecodeUInt32(fields[2]),
            observedAt: InvestigationHandoffUTCMicroseconds(
                rawValue: handoffDecodeInt64(fields[3])
            ),
            remainingAuditSessionMembers: handoffDecodeUInt32(fields[4]),
            matchingLeases: handoffDecodeUInt32(fields[5]),
            leaseRootEntries: handoffDecodeUInt32(fields[6]),
            investigationArtifacts: handoffDecodeUInt32(fields[7])
        )
    }
}

package struct InvestigationMachineClaimEvidence:
    Sendable,
    Equatable
{
    package static let domain =
        "stornaut.task39.machine-claim.evidence"
    package static let maximumByteCount = 4_096

    package let requestBindingSHA256: InvestigationHandoffSHA256
    package let originalClaimChallenge: UUID
    package let claimConnectionEpoch: UUID
    package let appIdentity: InvestigationMachineProcessIdentity
    package let helperIdentity: InvestigationMachineProcessIdentity
    package let appUserID: UInt32
    package let recordedAt: InvestigationHandoffUTCMicroseconds
    package let claimedAt: InvestigationHandoffUTCMicroseconds
    package let ownerRetirement: InvestigationMachineOwnerRetirement
    package let l1Residue: InvestigationMachineL1Residue
    package let releaseDeadlineNanoseconds: UInt64

    package init(
        requestBindingSHA256: InvestigationHandoffSHA256,
        originalClaimChallenge: UUID,
        claimConnectionEpoch: UUID,
        appIdentity: InvestigationMachineProcessIdentity,
        helperIdentity: InvestigationMachineProcessIdentity,
        appUserID: UInt32,
        recordedAt: InvestigationHandoffUTCMicroseconds,
        claimedAt: InvestigationHandoffUTCMicroseconds,
        ownerRetirement: InvestigationMachineOwnerRetirement,
        l1Residue: InvestigationMachineL1Residue,
        releaseDeadlineNanoseconds: UInt64
    ) throws {
        guard
            handoffUUIDIsNonzero(originalClaimChallenge),
            handoffUUIDIsNonzero(claimConnectionEpoch),
            appIdentity.role == .app,
            helperIdentity.role == .helper,
            appUserID == 501,
            appIdentity.effectiveUserID == appUserID,
            helperIdentity.effectiveUserID == 0,
            appIdentity.auditSessionID == helperIdentity.auditSessionID,
            l1Residue.auditSessionID == appIdentity.auditSessionID,
            l1Residue.userID == appUserID,
            l1Residue.observedAt <= recordedAt,
            recordedAt <= claimedAt,
            releaseDeadlineNanoseconds > 0
        else {
            throw InvestigationHandoffContractError.invalidValue
        }
        self.requestBindingSHA256 = requestBindingSHA256
        self.originalClaimChallenge = originalClaimChallenge
        self.claimConnectionEpoch = claimConnectionEpoch
        self.appIdentity = appIdentity
        self.helperIdentity = helperIdentity
        self.appUserID = appUserID
        self.recordedAt = recordedAt
        self.claimedAt = claimedAt
        self.ownerRetirement = ownerRetirement
        self.l1Residue = l1Residue
        self.releaseDeadlineNanoseconds = releaseDeadlineNanoseconds
    }

    package func encoded() throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: Self.domain,
            businessFields: [
                requestBindingSHA256.rawBytes,
                handoffData(originalClaimChallenge),
                handoffData(claimConnectionEpoch),
                appIdentity.encoded(),
                helperIdentity.encoded(),
                handoffData(appUserID),
                handoffData(recordedAt.rawValue),
                handoffData(claimedAt.rawValue),
                ownerRetirement.encoded(),
                l1Residue.encoded(),
                handoffData(releaseDeadlineNanoseconds),
            ],
            maximumByteCount: Self.maximumByteCount
        )
    }

    package static func decode(_ data: Data) throws -> Self {
        let fields = try HandoffBinaryTranscript.decode(
            data,
            expectedDomain: domain,
            expectedBusinessFieldByteCounts: [
                32...32,
                16...16,
                16...16,
                1...InvestigationMachineProcessIdentity.maximumByteCount,
                1...InvestigationMachineProcessIdentity.maximumByteCount,
                4...4,
                8...8,
                8...8,
                1...InvestigationMachineOwnerRetirement.maximumByteCount,
                1...InvestigationMachineL1Residue.maximumByteCount,
                8...8,
            ],
            maximumByteCount: maximumByteCount
        )
        return try Self(
            requestBindingSHA256: InvestigationHandoffSHA256(
                rawBytes: fields[0]
            ),
            originalClaimChallenge: handoffUUID(fields[1]),
            claimConnectionEpoch: handoffUUID(fields[2]),
            appIdentity: InvestigationMachineProcessIdentity.decode(fields[3]),
            helperIdentity: InvestigationMachineProcessIdentity.decode(fields[4]),
            appUserID: handoffDecodeUInt32(fields[5]),
            recordedAt: InvestigationHandoffUTCMicroseconds(
                rawValue: handoffDecodeInt64(fields[6])
            ),
            claimedAt: InvestigationHandoffUTCMicroseconds(
                rawValue: handoffDecodeInt64(fields[7])
            ),
            ownerRetirement: InvestigationMachineOwnerRetirement.decode(
                fields[8]
            ),
            l1Residue: InvestigationMachineL1Residue.decode(fields[9]),
            releaseDeadlineNanoseconds: handoffDecodeUInt64(fields[10])
        )
    }

    package func validate(
        against expectation: InvestigationMachineClaimExpectation
    ) throws {
        guard
            requestBindingSHA256 == expectation.requestBindingSHA256,
            originalClaimChallenge == expectation.originalClaimChallenge,
            claimConnectionEpoch == expectation.claimConnectionEpoch,
            appUserID == expectation.appUserID,
            appIdentity == expectation.appIdentity,
            helperIdentity == expectation.helperIdentity,
            l1Residue.investigationUUID == expectation.investigationUUID,
            l1Residue.auditSessionID == expectation.auditSessionID,
            l1Residue.userID == expectation.appUserID,
            recordedAt <= expectation.issuedAt,
            expectation.issuedAt <= claimedAt,
            claimedAt < expectation.requestValidBefore
        else {
            throw InvestigationHandoffContractError.invalidValue
        }
    }
}

package struct InvestigationMachineClaimExpectation:
    Sendable,
    Equatable
{
    package let requestBindingSHA256: InvestigationHandoffSHA256
    package let originalClaimChallenge: UUID
    package let claimConnectionEpoch: UUID
    package let investigationUUID: UUID
    package let auditSessionID: UInt32
    package let appUserID: UInt32
    package let appIdentity: InvestigationMachineProcessIdentity
    package let helperIdentity: InvestigationMachineProcessIdentity
    package let issuedAt: InvestigationHandoffUTCMicroseconds
    package let requestValidBefore: InvestigationHandoffUTCMicroseconds

    package init(
        request: InvestigationMachineRetirementClaimRequest,
        appUserID: UInt32,
        appIdentity: InvestigationMachineProcessIdentity,
        helperIdentity: InvestigationMachineProcessIdentity
    ) throws {
        guard
            appUserID == 501,
            appIdentity.role == .app,
            helperIdentity.role == .helper,
            appIdentity.effectiveUserID == appUserID,
            helperIdentity.effectiveUserID == 0,
            appIdentity.auditSessionID == helperIdentity.auditSessionID
        else {
            throw InvestigationHandoffContractError.invalidValue
        }
        requestBindingSHA256 = try request.bindingSHA256()
        originalClaimChallenge = request.claimChallenge
        claimConnectionEpoch = request.claimConnectionEpoch
        investigationUUID = request.handle.investigationUUID
        auditSessionID = appIdentity.auditSessionID
        self.appUserID = appUserID
        self.appIdentity = appIdentity
        self.helperIdentity = helperIdentity
        issuedAt = request.issuedAt
        requestValidBefore = request.requestValidBefore
    }
}

package struct InvestigationMachineClaimRelease:
    Sendable,
    Equatable
{
    package static let domain =
        "stornaut.task39.machine-claim.release"
    package static let maximumByteCount = 1_024
    package static let maximumReleaseWindowNanoseconds: UInt64 = 5_000_000_000

    package let requestBindingSHA256: InvestigationHandoffSHA256
    package let releaseChallenge: UUID
    package let claimedHelperIdentitySHA256: InvestigationHandoffSHA256
    package let claimConnectionEpoch: UUID
    package let releaseDeadlineNanoseconds: UInt64

    package init(
        requestBindingSHA256: InvestigationHandoffSHA256,
        releaseChallenge: UUID,
        claimedHelperIdentitySHA256: InvestigationHandoffSHA256,
        claimConnectionEpoch: UUID,
        releaseDeadlineNanoseconds: UInt64
    ) throws {
        guard
            handoffUUIDIsNonzero(releaseChallenge),
            handoffUUIDIsNonzero(claimConnectionEpoch),
            releaseDeadlineNanoseconds > 0
        else {
            throw InvestigationHandoffContractError.invalidValue
        }
        self.requestBindingSHA256 = requestBindingSHA256
        self.releaseChallenge = releaseChallenge
        self.claimedHelperIdentitySHA256 = claimedHelperIdentitySHA256
        self.claimConnectionEpoch = claimConnectionEpoch
        self.releaseDeadlineNanoseconds = releaseDeadlineNanoseconds
    }

    package func encoded() throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: Self.domain,
            businessFields: [
                requestBindingSHA256.rawBytes,
                handoffData(releaseChallenge),
                claimedHelperIdentitySHA256.rawBytes,
                handoffData(claimConnectionEpoch),
                handoffData(releaseDeadlineNanoseconds),
            ],
            maximumByteCount: Self.maximumByteCount
        )
    }

    package static func decode(_ data: Data) throws -> Self {
        let fields = try HandoffBinaryTranscript.decode(
            data,
            expectedDomain: domain,
            expectedBusinessFieldByteCounts: [
                32...32, 16...16, 32...32, 16...16, 8...8,
            ],
            maximumByteCount: maximumByteCount
        )
        return try Self(
            requestBindingSHA256: InvestigationHandoffSHA256(
                rawBytes: fields[0]
            ),
            releaseChallenge: handoffUUID(fields[1]),
            claimedHelperIdentitySHA256: InvestigationHandoffSHA256(
                rawBytes: fields[2]
            ),
            claimConnectionEpoch: handoffUUID(fields[3]),
            releaseDeadlineNanoseconds: handoffDecodeUInt64(fields[4])
        )
    }

    package func validate(
        against evidence: InvestigationMachineClaimEvidence,
        expectedReleaseChallenge: UUID
    ) throws {
        guard
            handoffUUIDIsNonzero(expectedReleaseChallenge),
            requestBindingSHA256 == evidence.requestBindingSHA256,
            releaseChallenge == expectedReleaseChallenge,
            claimedHelperIdentitySHA256
                == (try evidence.helperIdentity.helperIdentitySHA256()),
            claimConnectionEpoch == evidence.claimConnectionEpoch,
            releaseDeadlineNanoseconds == evidence.releaseDeadlineNanoseconds
        else {
            throw InvestigationHandoffContractError.invalidValue
        }
    }
}

package struct InvestigationMachineClaimReleased:
    Sendable,
    Equatable
{
    package static let domain =
        "stornaut.task39.machine-claim.released"
    package static let maximumByteCount = 1_024
    package static let maximumPostReplyExitWindowNanoseconds: UInt64 =
        5_000_000_000

    package let requestBindingSHA256: InvestigationHandoffSHA256
    package let releaseChallenge: UUID
    package let claimedHelperIdentitySHA256: InvestigationHandoffSHA256
    package let claimConnectionEpoch: UUID
    package let exitScheduled: Bool
    package let postReplyExitDeadlineNanoseconds: UInt64

    package init(
        requestBindingSHA256: InvestigationHandoffSHA256,
        releaseChallenge: UUID,
        claimedHelperIdentitySHA256: InvestigationHandoffSHA256,
        claimConnectionEpoch: UUID,
        exitScheduled: Bool,
        postReplyExitDeadlineNanoseconds: UInt64
    ) throws {
        guard
            handoffUUIDIsNonzero(releaseChallenge),
            handoffUUIDIsNonzero(claimConnectionEpoch),
            exitScheduled,
            postReplyExitDeadlineNanoseconds > 0
        else {
            throw InvestigationHandoffContractError.invalidValue
        }
        self.requestBindingSHA256 = requestBindingSHA256
        self.releaseChallenge = releaseChallenge
        self.claimedHelperIdentitySHA256 = claimedHelperIdentitySHA256
        self.claimConnectionEpoch = claimConnectionEpoch
        self.exitScheduled = exitScheduled
        self.postReplyExitDeadlineNanoseconds =
            postReplyExitDeadlineNanoseconds
    }

    package func encoded() throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: Self.domain,
            businessFields: [
                requestBindingSHA256.rawBytes,
                handoffData(releaseChallenge),
                claimedHelperIdentitySHA256.rawBytes,
                handoffData(claimConnectionEpoch),
                handoffData(UInt8(0x01)),
                handoffData(postReplyExitDeadlineNanoseconds),
            ],
            maximumByteCount: Self.maximumByteCount
        )
    }

    package static func decode(_ data: Data) throws -> Self {
        let fields = try HandoffBinaryTranscript.decode(
            data,
            expectedDomain: domain,
            expectedBusinessFieldByteCounts: [
                32...32, 16...16, 32...32, 16...16, 1...1, 8...8,
            ],
            maximumByteCount: maximumByteCount
        )
        guard fields[4][fields[4].startIndex] == 0x01 else {
            throw InvestigationHandoffContractError.invalidValue
        }
        return try Self(
            requestBindingSHA256: InvestigationHandoffSHA256(
                rawBytes: fields[0]
            ),
            releaseChallenge: handoffUUID(fields[1]),
            claimedHelperIdentitySHA256: InvestigationHandoffSHA256(
                rawBytes: fields[2]
            ),
            claimConnectionEpoch: handoffUUID(fields[3]),
            exitScheduled: true,
            postReplyExitDeadlineNanoseconds: handoffDecodeUInt64(fields[5])
        )
    }

    package func validateEcho(
        of release: InvestigationMachineClaimRelease
    ) throws {
        guard
            requestBindingSHA256 == release.requestBindingSHA256,
            releaseChallenge == release.releaseChallenge,
            claimedHelperIdentitySHA256
                == release.claimedHelperIdentitySHA256,
            claimConnectionEpoch == release.claimConnectionEpoch,
            exitScheduled
        else {
            throw InvestigationHandoffContractError.invalidValue
        }
    }
}

@objc(StornautInvestigationMachineClaimXPCWire)
public protocol InvestigationMachineClaimXPCWire {
    func claimMachineRetirement(
        _ request: Data,
        withReply reply: @escaping (Data?, String?) -> Void
    )

    func releaseMachineRetirement(
        _ request: Data,
        withReply reply: @escaping (Data?, String?) -> Void
    )
}

package enum InvestigationMachineClaimXPCReason:
    String,
    Sendable,
    CaseIterable
{
    case invalidRequest = "runtime.lifecycle.machine-claim.invalid-request"
    case invalidPeer = "runtime.lifecycle.machine-claim.invalid-peer"
    case empty = "runtime.lifecycle.machine-claim.empty"
    case consumed = "runtime.lifecycle.machine-claim.consumed"
    case expired = "runtime.lifecycle.machine-claim.expired"
    case mismatch = "runtime.lifecycle.machine-claim.mismatch"
    case unavailable = "runtime.lifecycle.machine-claim.unavailable"
}

package enum InvestigationMachineClaimXPCReplyValue:
    Sendable,
    Equatable
{
    case success(Data)
    case failure(InvestigationMachineClaimXPCReason)
}

package enum InvestigationMachineClaimXPCRequest {
    package static func validateClaim(_ data: Data) throws {
        try validate(data, maximumByteCount: 1_024)
        _ = try InvestigationMachineRetirementClaimRequest.decode(data)
    }

    package static func validateRelease(_ data: Data) throws {
        try validate(data, maximumByteCount: 1_024)
        _ = try InvestigationMachineClaimRelease.decode(data)
    }

    private static func validate(
        _ data: Data,
        maximumByteCount: Int
    ) throws {
        guard (1...maximumByteCount).contains(data.count) else {
            throw InvestigationHandoffContractError.sizeLimitExceeded
        }
    }
}

package enum InvestigationMachineClaimXPCReply {
    package static func validateClaim(
        response: Data?,
        reasonKey: String?
    ) throws -> InvestigationMachineClaimXPCReplyValue {
        try validate(
            response: response,
            reasonKey: reasonKey,
            maximumByteCount: 4_096
        )
    }

    package static func validateRelease(
        response: Data?,
        reasonKey: String?
    ) throws -> InvestigationMachineClaimXPCReplyValue {
        try validate(
            response: response,
            reasonKey: reasonKey,
            maximumByteCount: 1_024
        )
    }

    private static func validate(
        response: Data?,
        reasonKey: String?,
        maximumByteCount: Int
    ) throws -> InvestigationMachineClaimXPCReplyValue {
        switch (response, reasonKey) {
        case let (.some(data), .none):
            guard (1...maximumByteCount).contains(data.count) else {
                throw InvestigationHandoffContractError.sizeLimitExceeded
            }
            if maximumByteCount == InvestigationMachineClaimEvidence.maximumByteCount {
                _ = try InvestigationMachineClaimEvidence.decode(data)
            } else {
                _ = try InvestigationMachineClaimReleased.decode(data)
            }
            return .success(data)
        case let (.none, .some(reasonKey)):
            return .failure(sanitizedReason(reasonKey))
        default:
            throw InvestigationHandoffContractError.invalidEncoding
        }
    }

    private static func sanitizedReason(
        _ value: String
    ) -> InvestigationMachineClaimXPCReason {
        let bytes = Array(value.utf8)
        guard
            (1...128).contains(bytes.count),
            bytes.allSatisfy({ $0 > 0 && $0 < 0x80 }),
            let reason = InvestigationMachineClaimXPCReason(rawValue: value)
        else {
            return .unavailable
        }
        return reason
    }
}

private func claimUInt32ArrayData(_ values: [UInt32]) -> Data {
    values.reduce(into: Data()) { output, value in
        output.append(handoffData(value))
    }
}

private func claimDecodeUInt32Array(
    _ data: Data,
    expectedCount: Int
) throws -> [UInt32] {
    guard
        expectedCount >= 0,
        data.count == expectedCount * MemoryLayout<UInt32>.size
    else {
        throw InvestigationHandoffContractError.invalidEncoding
    }
    var cursor = HandoffBinaryCursor(data: data)
    var values: [UInt32] = []
    values.reserveCapacity(expectedCount)
    for _ in 0..<expectedCount {
        values.append(try cursor.readUInt32())
    }
    guard cursor.isAtEnd else {
        throw InvestigationHandoffContractError.invalidEncoding
    }
    return values
}
