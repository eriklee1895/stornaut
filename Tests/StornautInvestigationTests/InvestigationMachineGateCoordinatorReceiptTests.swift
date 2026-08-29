import CryptoKit
import Darwin
import Foundation
import Testing
@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationMachineGateCoordinatorSupport
@testable import StornautInvestigationMachineGateSupport
@Suite("Investigation machine gate coordinator receipt", .serialized)
struct InvestigationMachineGateCoordinatorReceiptTests {
    @Test
    func constantsFieldsAndAuthoritySurfaceAreExact() throws {
        let receipt = try CoordinatorReceiptValues().makeReceipt()
        #expect(InvestigationMachineGateCoordinatorReceiptV1.domain
            == coordinatorReceiptDomain)
        #expect(InvestigationMachineGateCoordinatorReceiptV1.schemaVersion == 1)
        #expect(InvestigationMachineGateCoordinatorReceiptV1.maximumByteCount == 4_096)
        #expect(receipt.buildProvenanceSHA256 == coordinatorBuildSHA256)
        #expect(receipt.signedBindingSHA256 == digest(0x11))
        #expect(receipt.outerAttemptUUID == coordinatorAttemptUUID)
        #expect(receipt.wholeProjectedInputSHA256 == digest(0x22))
        #expect(receipt.capsule == coordinatorCapsule)
        #expect(receipt.gateExecutableSHA256 == digest(0x33))
        #expect(receipt.gateTransportReceiptSHA256 == digest(0x44))
        #expect(receipt.gateProcessID == 5_001)
        #expect(receipt.gateProcessGroupID == 5_001)
        #expect(receipt.gateSessionID == 4_001)
        #expect(receipt.exactGateWaitClassification == .exited(status: 0))
        #expect(receipt.receiptReachedEOF)
        #expect(!receipt.receiptOverflowObserved)
        #expect(!receipt.receiptDeadlineExpired)
        #expect(receipt.capsuleSettlementRemoved)
        #expect(receipt.attemptBaseRetired)
        #expect(receipt.runtimeArtifactsRetired)
        #expect(receipt.monotonicStartedNanoseconds == 1_000_000)
        #expect(receipt.monotonicCompletedNanoseconds == 1_000_999)
        #expect(!(InvestigationMachineGateCoordinatorReceiptV1.self
            is any Codable.Type))
        let labels = Set(Mirror(reflecting: receipt).children.compactMap(\.label))
        for forbidden in [
            "path", "descriptor", "token", "proof", "readiness",
            "root", "sudo", "authorization",
        ] {
            #expect(!labels.contains {
                $0.localizedCaseInsensitiveContains(forbidden)
            })
        }
    }
    @Test
    func binaryRoundTripMatchesIndependentGoldenAndZeroBeforeHash() throws {
        let values = CoordinatorReceiptValues()
        let receipt = try values.makeReceipt()
        let encoded = try receipt.encoded()
        let zeroed = independentCoordinatorTranscript(
            values, receiptSHA256: Data(repeating: 0, count: 32)
        )
        let expectedSHA256 = Data(SHA256.hash(data: zeroed))
        let golden = independentCoordinatorTranscript(
            values, receiptSHA256: expectedSHA256
        )
        let decoded = try InvestigationMachineGateCoordinatorReceiptV1.decode(
            encoded
        )
        #expect(encoded == golden)
        #expect(encoded.count == coordinatorGoldenByteCount)
        #expect(encoded.hexString == coordinatorGoldenHex)
        #expect(expectedSHA256.hexString == coordinatorGoldenSHA256)
        #expect(receipt.receiptSHA256.rawBytes == expectedSHA256)
        #expect(decoded == receipt)
        #expect(try decoded.encoded() == encoded)
        #expect(encoded.count <= InvestigationMachineGateCoordinatorReceiptV1
            .maximumByteCount)
    }
    @Test(arguments: CoordinatorReceiptValueMutation.allCases)
    func initializerRejectsEveryInvalidValue(
        _ mutation: CoordinatorReceiptValueMutation
    ) throws {
        #expect(throws: (any Error).self) {
            _ = try mutation.apply(to: CoordinatorReceiptValues()).makeReceipt()
        }
    }
    @Test(arguments: CoordinatorReceiptEncodingMutation.allCases)
    func strictDecoderRejectsStructuralSemanticAndSelfHashDrift(
        _ mutation: CoordinatorReceiptEncodingMutation
    ) throws {
        let encoded = try CoordinatorReceiptValues().makeReceipt().encoded()
        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineGateCoordinatorReceiptV1.decode(
                mutation.apply(to: encoded)
            )
        }
    }
}
enum CoordinatorReceiptValueMutation: CaseIterable, Sendable {
    case shortBuildSHA, uppercaseBuildSHA, nonHexBuildSHA, zeroBuildSHA
    case zeroSignedBinding, zeroAttemptUUID, zeroProjectedInput
    case zeroCapsuleDevice, zeroCapsuleInode, zeroCapsuleSize
    case zeroGateExecutable, zeroTransportReceipt
    case invalidGatePID, mismatchedGatePGID, invalidSession, reusedSessionGroup
    case nonzeroExit, signaledWait, stoppedWait
    case missingEOF, overflow, deadline, settlementNotRemoved
    case attemptBaseNotRetired, runtimeArtifactsNotRetired
    case zeroStart, equalTime, reversedTime
    fileprivate func apply(to source: CoordinatorReceiptValues)
        -> CoordinatorReceiptValues
    {
        var value = source
        switch self {
        case .shortBuildSHA: value.buildProvenanceSHA256.removeLast()
        case .uppercaseBuildSHA:
            value.buildProvenanceSHA256 = String(repeating: "A", count: 64)
        case .nonHexBuildSHA:
            value.buildProvenanceSHA256 = String(repeating: "g", count: 64)
        case .zeroBuildSHA:
            value.buildProvenanceSHA256 = String(repeating: "0", count: 64)
        case .zeroSignedBinding: value.signedBindingSHA256 = digest(0)
        case .zeroAttemptUUID: value.outerAttemptUUID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        case .zeroProjectedInput: value.wholeProjectedInputSHA256 = digest(0)
        case .zeroCapsuleDevice: value.capsule = capsule(device: 0)
        case .zeroCapsuleInode: value.capsule = capsule(inode: 0)
        case .zeroCapsuleSize: value.capsule = capsule(size: 0)
        case .zeroGateExecutable: value.gateExecutableSHA256 = digest(0)
        case .zeroTransportReceipt: value.gateTransportReceiptSHA256 = digest(0)
        case .invalidGatePID: value.gateProcessID = 1
        case .mismatchedGatePGID: value.gateProcessGroupID += 1
        case .invalidSession: value.gateSessionID = 1
        case .reusedSessionGroup: value.gateSessionID = value.gateProcessGroupID
        case .nonzeroExit: value.exactGateWaitClassification = .exited(status: 1)
        case .signaledWait: value.exactGateWaitClassification = .signaled(signal: SIGTERM)
        case .stoppedWait: value.exactGateWaitClassification = .stopped(signal: SIGSTOP)
        case .missingEOF: value.receiptReachedEOF = false
        case .overflow: value.receiptOverflowObserved = true
        case .deadline: value.receiptDeadlineExpired = true
        case .settlementNotRemoved: value.capsuleSettlementRemoved = false
        case .attemptBaseNotRetired: value.attemptBaseRetired = false
        case .runtimeArtifactsNotRetired: value.runtimeArtifactsRetired = false
        case .zeroStart: value.monotonicStartedNanoseconds = 0
        case .equalTime: value.monotonicCompletedNanoseconds = value.monotonicStartedNanoseconds
        case .reversedTime: value.monotonicCompletedNanoseconds = value.monotonicStartedNanoseconds - 1
        }
        return value
    }
}
enum CoordinatorReceiptEncodingMutation: CaseIterable, Sendable {
    case wrongMagic, wrongDomain, wrongVersion, unknownTag, duplicateField
    case truncated, trailing, oversized, tamperedPayload
    case zeroAttemptUUID, zeroDigest, invalidGatePID, invalidTopology
    case invalidBoolean, falseEOF, trueOverflow, trueDeadline
    case falseSettlement, falseAttemptRetirement, falseRuntimeRetirement
    case reversedTime, zeroSelfHash, mismatchedSelfHash
    func apply(to source: Data) throws -> Data {
        var value = source
        switch self {
        case .wrongMagic: value[0] ^= 0xff
        case .wrongDomain:
            value[coordinatorFieldRange(tag: 0, in: value).lowerBound] ^= 1
        case .wrongVersion:
            value.replaceSubrange(
                coordinatorFieldRange(tag: 1, in: value),
                with: coordinatorUInt32(2)
            )
        case .unknownTag:
            let range = coordinatorFullFieldRange(tag: 8, in: value)
            value[range.lowerBound] = 0x7f
        case .duplicateField:
            let range = coordinatorFullFieldRange(tag: 8, in: value)
            value.insert(contentsOf: value[range], at: range.upperBound)
        case .truncated: value.removeLast()
        case .trailing: value.append(0)
        case .oversized:
            value.append(Data(
                repeating: 0,
                count: InvestigationMachineGateCoordinatorReceiptV1
                    .maximumByteCount - value.count + 1
            ))
        case .tamperedPayload:
            value[coordinatorFieldRange(tag: 10, in: value).lowerBound] ^= 1
        case .zeroAttemptUUID:
            replace(tag: 4, in: &value, with: Data(repeating: 0, count: 16))
            value = resign(value)
        case .zeroDigest:
            replace(tag: 3, in: &value, with: Data(repeating: 0, count: 32))
            value = resign(value)
        case .invalidGatePID:
            replace(tag: 12, in: &value, with: coordinatorInt32(1))
            value = resign(value)
        case .invalidTopology:
            replace(tag: 13, in: &value, with: coordinatorInt32(5_002))
            value = resign(value)
        case .invalidBoolean:
            replace(tag: 16, in: &value, with: Data([2])); value = resign(value)
        case .falseEOF:
            replace(tag: 16, in: &value, with: Data([0])); value = resign(value)
        case .trueOverflow:
            replace(tag: 17, in: &value, with: Data([1])); value = resign(value)
        case .trueDeadline:
            replace(tag: 18, in: &value, with: Data([1])); value = resign(value)
        case .falseSettlement:
            replace(tag: 19, in: &value, with: Data([0])); value = resign(value)
        case .falseAttemptRetirement:
            replace(tag: 20, in: &value, with: Data([0])); value = resign(value)
        case .falseRuntimeRetirement:
            replace(tag: 21, in: &value, with: Data([0])); value = resign(value)
        case .reversedTime:
            replace(tag: 23, in: &value, with: coordinatorUInt64(999_999))
            value = resign(value)
        case .zeroSelfHash:
            replace(tag: 24, in: &value, with: Data(repeating: 0, count: 32))
        case .mismatchedSelfHash:
            value[coordinatorFieldRange(tag: 24, in: value).lowerBound] ^= 1
        }
        return value
    }
}
private struct CoordinatorReceiptValues {
    var buildProvenanceSHA256 = coordinatorBuildSHA256
    var signedBindingSHA256 = digest(0x11)
    var outerAttemptUUID = coordinatorAttemptUUID
    var wholeProjectedInputSHA256 = digest(0x22)
    var capsule = coordinatorCapsule
    var gateExecutableSHA256 = digest(0x33)
    var gateTransportReceiptSHA256 = digest(0x44)
    var gateProcessID: pid_t = 5_001
    var gateProcessGroupID: pid_t = 5_001
    var gateSessionID: pid_t = 4_001
    var exactGateWaitClassification = InvestigationMachineGateWaitClassification.exited(status: 0)
    var receiptReachedEOF = true
    var receiptOverflowObserved = false
    var receiptDeadlineExpired = false
    var capsuleSettlementRemoved = true
    var attemptBaseRetired = true
    var runtimeArtifactsRetired = true
    var monotonicStartedNanoseconds: UInt64 = 1_000_000
    var monotonicCompletedNanoseconds: UInt64 = 1_000_999
    func makeReceipt() throws -> InvestigationMachineGateCoordinatorReceiptV1 {
        try .init(
            buildProvenanceSHA256: buildProvenanceSHA256,
            signedBindingSHA256: signedBindingSHA256,
            outerAttemptUUID: outerAttemptUUID,
            wholeProjectedInputSHA256: wholeProjectedInputSHA256,
            capsule: capsule, gateExecutableSHA256: gateExecutableSHA256,
            gateTransportReceiptSHA256: gateTransportReceiptSHA256,
            gateProcessID: gateProcessID,
            gateProcessGroupID: gateProcessGroupID, gateSessionID: gateSessionID,
            exactGateWaitClassification: exactGateWaitClassification,
            receiptReachedEOF: receiptReachedEOF,
            receiptOverflowObserved: receiptOverflowObserved,
            receiptDeadlineExpired: receiptDeadlineExpired,
            capsuleSettlementRemoved: capsuleSettlementRemoved,
            attemptBaseRetired: attemptBaseRetired,
            runtimeArtifactsRetired: runtimeArtifactsRetired,
            monotonicStartedNanoseconds: monotonicStartedNanoseconds,
            monotonicCompletedNanoseconds: monotonicCompletedNanoseconds
        )
    }
}
private let coordinatorReceiptDomain =
    "stornaut.task39.machine.gate-coordinator-receipt.v1"
private let coordinatorBuildSHA256 = String(repeating: "a", count: 64)
private let coordinatorAttemptUUID = UUID(
    uuidString: "00000000-0000-0000-0000-000000000039"
)!
private let coordinatorCapsule = capsule()
private let coordinatorGoldenByteCount = 520
private let coordinatorGoldenSHA256 =
    "89e952a5996f13b9f20c8789a6c4ea185f230918f6c196f7810144a018c1f2ac"
private let coordinatorGoldenHex =
    "53544e4300000000003373746f726e6175742e7461736b33392e6d616368696e" +
    "652e676174652d636f6f7264696e61746f722d726563656970742e7631000100" +
    "0000040000000100020000004061616161616161616161616161616161616161" +
    "6161616161616161616161616161616161616161616161616161616161616161" +
    "6161616161616161616161616100030000002011111111111111111111111111" +
    "1111111111111111111111111111111111111100040000001000000000000000" +
    "0000000000000000390005000000202222222222222222222222222222222222" +
    "2222222222222222222222222222220006000000080102030405060708000700" +
    "0000081112131415161718000800000008212223242526272800090000000800" +
    "00000000001000000a0000002033333333333333333333333333333333333333" +
    "33333333333333333333333333000b0000002044444444444444444444444444" +
    "44444444444444444444444444444444444444000c0000000400001389000d00" +
    "00000400001389000e0000000400000fa1000f00000005010000000000100000" +
    "0001010011000000010000120000000100001300000001010014000000010100" +
    "15000000010100160000000800000000000f424000170000000800000000000f" +
    "462700180000002089e952a5996f13b9f20c8789a6c4ea185f230918f6c196f7" +
    "810144a018c1f2ac"
private func capsule(
    device: UInt64 = 0x0102_0304_0506_0708,
    inode: UInt64 = 0x1112_1314_1516_1718,
    generation: UInt64 = 0x2122_2324_2526_2728,
    size: Int64 = 4_096
) -> InvestigationMachineGateNodeObservation {
    .init(device: device, inode: inode, generation: generation, size: size)
}
private func digest(_ byte: UInt8) -> InvestigationHandoffSHA256 {
    try! .init(rawBytes: Data(repeating: byte, count: 32))
}
private func independentCoordinatorTranscript(
    _ value: CoordinatorReceiptValues, receiptSHA256: Data
) -> Data {
    let wait = coordinatorWaitData(value.exactGateWaitClassification)
    let fields: [Data] = [
        Data(value.buildProvenanceSHA256.utf8),
        value.signedBindingSHA256.rawBytes, coordinatorUUID(value.outerAttemptUUID),
        value.wholeProjectedInputSHA256.rawBytes,
        coordinatorUInt64(value.capsule.device), coordinatorUInt64(value.capsule.inode),
        coordinatorUInt64(value.capsule.generation),
        coordinatorUInt64(UInt64(bitPattern: value.capsule.size)),
        value.gateExecutableSHA256.rawBytes,
        value.gateTransportReceiptSHA256.rawBytes,
        coordinatorInt32(value.gateProcessID), coordinatorInt32(value.gateProcessGroupID),
        coordinatorInt32(value.gateSessionID), wait,
        coordinatorBoolean(value.receiptReachedEOF),
        coordinatorBoolean(value.receiptOverflowObserved),
        coordinatorBoolean(value.receiptDeadlineExpired),
        coordinatorBoolean(value.capsuleSettlementRemoved),
        coordinatorBoolean(value.attemptBaseRetired),
        coordinatorBoolean(value.runtimeArtifactsRetired),
        coordinatorUInt64(value.monotonicStartedNanoseconds),
        coordinatorUInt64(value.monotonicCompletedNanoseconds), receiptSHA256,
    ]
    var result = Data([0x53, 0x54, 0x4e, 0x43])
    appendCoordinatorField(0, Data(coordinatorReceiptDomain.utf8), to: &result)
    appendCoordinatorField(1, coordinatorUInt32(1), to: &result)
    for (index, field) in fields.enumerated() {
        appendCoordinatorField(UInt16(index + 2), field, to: &result)
    }
    return result
}
private func coordinatorWaitData(
    _ value: InvestigationMachineGateWaitClassification
) -> Data {
    switch value {
    case .exited(let status): Data([1]) + coordinatorInt32(status)
    case .signaled(let signal): Data([2]) + coordinatorInt32(signal)
    case .stopped(let signal): Data([3]) + coordinatorInt32(signal)
    }
}
private func resign(_ source: Data) -> Data {
    var value = source
    replace(tag: 24, in: &value, with: Data(repeating: 0, count: 32))
    replace(tag: 24, in: &value, with: Data(SHA256.hash(data: value)))
    return value
}
private func replace(tag: UInt16, in value: inout Data, with bytes: Data) {
    let range = coordinatorFieldRange(tag: tag, in: value)
    precondition(range.count == bytes.count)
    value.replaceSubrange(range, with: bytes)
}
private func coordinatorFieldRange(tag: UInt16, in value: Data) -> Range<Int> {
    let full = coordinatorFullFieldRange(tag: tag, in: value)
    return (full.lowerBound + 6)..<full.upperBound
}
private func coordinatorFullFieldRange(tag: UInt16, in value: Data) -> Range<Int> {
    var offset = 4
    while offset + 6 <= value.count {
        let current = UInt16(value[offset]) << 8 | UInt16(value[offset + 1])
        let count = Int(coordinatorReadUInt32(value, offset: offset + 2))
        let range = offset..<(offset + 6 + count)
        if current == tag { return range }
        offset = range.upperBound
    }
    preconditionFailure("missing coordinator field")
}
private func appendCoordinatorField(
    _ tag: UInt16, _ payload: Data, to result: inout Data
) {
    result.append(contentsOf: [UInt8(tag >> 8), UInt8(truncatingIfNeeded: tag)])
    result.append(coordinatorUInt32(UInt32(payload.count)))
    result.append(payload)
}
private func coordinatorReadUInt32(_ value: Data, offset: Int) -> UInt32 {
    value[offset..<(offset + 4)].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
}
private func coordinatorBoolean(_ value: Bool) -> Data { Data([value ? 1 : 0]) }
private func coordinatorInt32(_ value: Int32) -> Data {
    coordinatorUInt32(UInt32(bitPattern: value))
}
private func coordinatorUInt32(_ value: UInt32) -> Data {
    Data([UInt8(value >> 24), UInt8(truncatingIfNeeded: value >> 16),
          UInt8(truncatingIfNeeded: value >> 8), UInt8(truncatingIfNeeded: value)])
}
private func coordinatorUInt64(_ value: UInt64) -> Data {
    Data((0..<8).reversed().map { UInt8(truncatingIfNeeded: value >> UInt64($0 * 8)) })
}
private func coordinatorUUID(_ value: UUID) -> Data {
    var bytes = value.uuid
    return withUnsafeBytes(of: &bytes) { Data($0) }
}
private extension Data {
    var hexString: String { map { String(format: "%02x", $0) }.joined() }
}
