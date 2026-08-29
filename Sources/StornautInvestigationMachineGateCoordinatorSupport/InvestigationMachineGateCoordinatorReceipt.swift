#if DEBUG
import Darwin
import Foundation
import StornautInvestigationHandoffContract
import StornautInvestigationMachineGateSupport
package enum InvestigationMachineGateCoordinatorReceiptError:
    Error, Equatable, Sendable {
    case invalidValue
    case invalidEncoding
}
// Terminal evidence only: no readiness/root authority; self-digest is zeroed.
package struct InvestigationMachineGateCoordinatorReceiptV1:
    Equatable, Sendable {
    package static let domain =
        "stornaut.task39.machine.gate-coordinator-receipt.v1"
    package static let schemaVersion: UInt32 = 1
    package static let maximumByteCount = 4_096
    package let buildProvenanceSHA256: String
    package let signedBindingSHA256: InvestigationHandoffSHA256
    package let outerAttemptUUID: UUID
    package let wholeProjectedInputSHA256: InvestigationHandoffSHA256
    package let capsule: InvestigationMachineGateNodeObservation
    package let gateExecutableSHA256: InvestigationHandoffSHA256
    package let gateTransportReceiptSHA256: InvestigationHandoffSHA256
    package let gateProcessID: pid_t
    package let gateProcessGroupID: pid_t
    package let gateSessionID: pid_t
    package let exactGateWaitClassification:
        InvestigationMachineGateWaitClassification
    package let receiptReachedEOF: Bool
    package let receiptOverflowObserved: Bool
    package let receiptDeadlineExpired: Bool
    package let capsuleSettlementRemoved: Bool
    package let attemptBaseRetired: Bool
    package let runtimeArtifactsRetired: Bool
    package let monotonicStartedNanoseconds: UInt64
    package let monotonicCompletedNanoseconds: UInt64
    package let receiptSHA256: InvestigationHandoffSHA256
    package init(
        buildProvenanceSHA256: String,
        signedBindingSHA256: InvestigationHandoffSHA256,
        outerAttemptUUID: UUID,
        wholeProjectedInputSHA256: InvestigationHandoffSHA256,
        capsule: InvestigationMachineGateNodeObservation,
        gateExecutableSHA256: InvestigationHandoffSHA256,
        gateTransportReceiptSHA256: InvestigationHandoffSHA256,
        gateProcessID: pid_t,
        gateProcessGroupID: pid_t,
        gateSessionID: pid_t,
        exactGateWaitClassification:
            InvestigationMachineGateWaitClassification,
        receiptReachedEOF: Bool,
        receiptOverflowObserved: Bool,
        receiptDeadlineExpired: Bool,
        capsuleSettlementRemoved: Bool,
        attemptBaseRetired: Bool,
        runtimeArtifactsRetired: Bool,
        monotonicStartedNanoseconds: UInt64,
        monotonicCompletedNanoseconds: UInt64
    ) throws {
        try Self.validate(
            buildProvenanceSHA256: buildProvenanceSHA256,
            signedBindingSHA256: signedBindingSHA256,
            outerAttemptUUID: outerAttemptUUID,
            wholeProjectedInputSHA256: wholeProjectedInputSHA256,
            capsule: capsule,
            gateExecutableSHA256: gateExecutableSHA256,
            gateTransportReceiptSHA256: gateTransportReceiptSHA256,
            gateProcessID: gateProcessID,
            gateProcessGroupID: gateProcessGroupID,
            gateSessionID: gateSessionID,
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
        self.buildProvenanceSHA256 = buildProvenanceSHA256
        self.signedBindingSHA256 = signedBindingSHA256
        self.outerAttemptUUID = outerAttemptUUID
        self.wholeProjectedInputSHA256 = wholeProjectedInputSHA256
        self.capsule = capsule
        self.gateExecutableSHA256 = gateExecutableSHA256
        self.gateTransportReceiptSHA256 = gateTransportReceiptSHA256
        self.gateProcessID = gateProcessID
        self.gateProcessGroupID = gateProcessGroupID
        self.gateSessionID = gateSessionID
        self.exactGateWaitClassification = exactGateWaitClassification
        self.receiptReachedEOF = receiptReachedEOF
        self.receiptOverflowObserved = receiptOverflowObserved
        self.receiptDeadlineExpired = receiptDeadlineExpired
        self.capsuleSettlementRemoved = capsuleSettlementRemoved
        self.attemptBaseRetired = attemptBaseRetired
        self.runtimeArtifactsRetired = runtimeArtifactsRetired
        self.monotonicStartedNanoseconds = monotonicStartedNanoseconds
        self.monotonicCompletedNanoseconds = monotonicCompletedNanoseconds
        do {
            receiptSHA256 = .hashing(try Self.transcript(
                buildProvenanceSHA256: buildProvenanceSHA256,
                signedBindingSHA256: signedBindingSHA256,
                outerAttemptUUID: outerAttemptUUID,
                wholeProjectedInputSHA256: wholeProjectedInputSHA256,
                capsule: capsule,
                gateExecutableSHA256: gateExecutableSHA256,
                gateTransportReceiptSHA256: gateTransportReceiptSHA256,
                gateProcessID: gateProcessID,
                gateProcessGroupID: gateProcessGroupID,
                gateSessionID: gateSessionID,
                exactGateWaitClassification: exactGateWaitClassification,
                receiptReachedEOF: receiptReachedEOF,
                receiptOverflowObserved: receiptOverflowObserved,
                receiptDeadlineExpired: receiptDeadlineExpired,
                capsuleSettlementRemoved: capsuleSettlementRemoved,
                attemptBaseRetired: attemptBaseRetired,
                runtimeArtifactsRetired: runtimeArtifactsRetired,
                monotonicStartedNanoseconds: monotonicStartedNanoseconds,
                monotonicCompletedNanoseconds:
                    monotonicCompletedNanoseconds,
                receiptSHA256Bytes: Data(
                    repeating: 0,
                    count: InvestigationHandoffSHA256.byteCount
                )
            ))
        } catch {
            throw InvestigationMachineGateCoordinatorReceiptError
                .invalidValue
        }
        guard coordinatorDigestIsNonzero(receiptSHA256) else {
            throw InvestigationMachineGateCoordinatorReceiptError
                .invalidValue
        }
    }
    package func encoded() throws -> Data {
        try Self.validate(
            buildProvenanceSHA256: buildProvenanceSHA256,
            signedBindingSHA256: signedBindingSHA256,
            outerAttemptUUID: outerAttemptUUID,
            wholeProjectedInputSHA256: wholeProjectedInputSHA256,
            capsule: capsule,
            gateExecutableSHA256: gateExecutableSHA256,
            gateTransportReceiptSHA256: gateTransportReceiptSHA256,
            gateProcessID: gateProcessID,
            gateProcessGroupID: gateProcessGroupID,
            gateSessionID: gateSessionID,
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
        do {
            let zeroed = try Self.transcript(
                buildProvenanceSHA256: buildProvenanceSHA256,
                signedBindingSHA256: signedBindingSHA256,
                outerAttemptUUID: outerAttemptUUID,
                wholeProjectedInputSHA256: wholeProjectedInputSHA256,
                capsule: capsule,
                gateExecutableSHA256: gateExecutableSHA256,
                gateTransportReceiptSHA256: gateTransportReceiptSHA256,
                gateProcessID: gateProcessID,
                gateProcessGroupID: gateProcessGroupID,
                gateSessionID: gateSessionID,
                exactGateWaitClassification: exactGateWaitClassification,
                receiptReachedEOF: receiptReachedEOF,
                receiptOverflowObserved: receiptOverflowObserved,
                receiptDeadlineExpired: receiptDeadlineExpired,
                capsuleSettlementRemoved: capsuleSettlementRemoved,
                attemptBaseRetired: attemptBaseRetired,
                runtimeArtifactsRetired: runtimeArtifactsRetired,
                monotonicStartedNanoseconds: monotonicStartedNanoseconds,
                monotonicCompletedNanoseconds:
                    monotonicCompletedNanoseconds,
                receiptSHA256Bytes: Data(
                    repeating: 0,
                    count: InvestigationHandoffSHA256.byteCount
                )
            )
            guard InvestigationHandoffSHA256.hashing(zeroed)
                    == receiptSHA256
            else {
                throw InvestigationMachineGateCoordinatorReceiptError
                    .invalidEncoding
            }
            return try Self.transcript(
                buildProvenanceSHA256: buildProvenanceSHA256,
                signedBindingSHA256: signedBindingSHA256,
                outerAttemptUUID: outerAttemptUUID,
                wholeProjectedInputSHA256: wholeProjectedInputSHA256,
                capsule: capsule,
                gateExecutableSHA256: gateExecutableSHA256,
                gateTransportReceiptSHA256: gateTransportReceiptSHA256,
                gateProcessID: gateProcessID,
                gateProcessGroupID: gateProcessGroupID,
                gateSessionID: gateSessionID,
                exactGateWaitClassification: exactGateWaitClassification,
                receiptReachedEOF: receiptReachedEOF,
                receiptOverflowObserved: receiptOverflowObserved,
                receiptDeadlineExpired: receiptDeadlineExpired,
                capsuleSettlementRemoved: capsuleSettlementRemoved,
                attemptBaseRetired: attemptBaseRetired,
                runtimeArtifactsRetired: runtimeArtifactsRetired,
                monotonicStartedNanoseconds: monotonicStartedNanoseconds,
                monotonicCompletedNanoseconds:
                    monotonicCompletedNanoseconds,
                receiptSHA256Bytes: receiptSHA256.rawBytes
            )
        } catch let error as InvestigationMachineGateCoordinatorReceiptError {
            throw error
        } catch {
            throw InvestigationMachineGateCoordinatorReceiptError
                .invalidEncoding
        }
    }
    package static func decode(_ data: Data) throws -> Self {
        do {
            let fields = try HandoffBinaryTranscript.decode(
                data,
                expectedDomain: domain,
                expectedBusinessFieldByteCounts: [
                    64...64, 32...32, 16...16, 32...32,
                    8...8, 8...8, 8...8, 8...8, 32...32, 32...32,
                    4...4, 4...4, 4...4, 5...5,
                    1...1, 1...1, 1...1, 1...1, 1...1, 1...1,
                    8...8, 8...8, 32...32,
                ],
                maximumByteCount: maximumByteCount
            )
            guard let buildSHA256 = String(
                data: fields[0], encoding: .utf8
            ) else {
                throw InvestigationMachineGateCoordinatorReceiptError
                    .invalidEncoding
            }
            let value = try Self(
                buildProvenanceSHA256: buildSHA256,
                signedBindingSHA256: try .init(rawBytes: fields[1]),
                outerAttemptUUID: try coordinatorDecodeUUID(fields[2]),
                wholeProjectedInputSHA256: try .init(rawBytes: fields[3]),
                capsule: .init(
                    device: try coordinatorDecodeUInt64(fields[4]),
                    inode: try coordinatorDecodeUInt64(fields[5]),
                    generation: try coordinatorDecodeUInt64(fields[6]),
                    size: Int64(bitPattern:
                        try coordinatorDecodeUInt64(fields[7]))
                ),
                gateExecutableSHA256: try .init(rawBytes: fields[8]),
                gateTransportReceiptSHA256: try .init(
                    rawBytes: fields[9]
                ),
                gateProcessID: try coordinatorDecodePID(fields[10]),
                gateProcessGroupID: try coordinatorDecodePID(fields[11]),
                gateSessionID: try coordinatorDecodePID(fields[12]),
                exactGateWaitClassification:
                    try coordinatorDecodeWait(fields[13]),
                receiptReachedEOF: try coordinatorDecodeBoolean(fields[14]),
                receiptOverflowObserved:
                    try coordinatorDecodeBoolean(fields[15]),
                receiptDeadlineExpired:
                    try coordinatorDecodeBoolean(fields[16]),
                capsuleSettlementRemoved:
                    try coordinatorDecodeBoolean(fields[17]),
                attemptBaseRetired: try coordinatorDecodeBoolean(fields[18]),
                runtimeArtifactsRetired:
                    try coordinatorDecodeBoolean(fields[19]),
                monotonicStartedNanoseconds:
                    try coordinatorDecodeUInt64(fields[20]),
                monotonicCompletedNanoseconds:
                    try coordinatorDecodeUInt64(fields[21])
            )
            let encodedSHA256 = try InvestigationHandoffSHA256(
                rawBytes: fields[22]
            )
            guard
                encodedSHA256 == value.receiptSHA256,
                try value.encoded() == data
            else {
                throw InvestigationMachineGateCoordinatorReceiptError
                    .invalidEncoding
            }
            return value
        } catch let error as InvestigationMachineGateCoordinatorReceiptError {
            throw error
        } catch {
            throw InvestigationMachineGateCoordinatorReceiptError
                .invalidEncoding
        }
    }
    private static func validate(
        buildProvenanceSHA256: String,
        signedBindingSHA256: InvestigationHandoffSHA256,
        outerAttemptUUID: UUID,
        wholeProjectedInputSHA256: InvestigationHandoffSHA256,
        capsule: InvestigationMachineGateNodeObservation,
        gateExecutableSHA256: InvestigationHandoffSHA256,
        gateTransportReceiptSHA256: InvestigationHandoffSHA256,
        gateProcessID: pid_t,
        gateProcessGroupID: pid_t,
        gateSessionID: pid_t,
        exactGateWaitClassification:
            InvestigationMachineGateWaitClassification,
        receiptReachedEOF: Bool,
        receiptOverflowObserved: Bool,
        receiptDeadlineExpired: Bool,
        capsuleSettlementRemoved: Bool,
        attemptBaseRetired: Bool,
        runtimeArtifactsRetired: Bool,
        monotonicStartedNanoseconds: UInt64,
        monotonicCompletedNanoseconds: UInt64
    ) throws {
        guard
            coordinatorValidLowercaseSHA256(buildProvenanceSHA256),
            coordinatorDigestIsNonzero(signedBindingSHA256),
            coordinatorUUIDIsNonzero(outerAttemptUUID),
            coordinatorDigestIsNonzero(wholeProjectedInputSHA256),
            capsule.device > 0, capsule.inode > 0,
            (1...Int64(InvestigationProjectedCohortInput.maximumByteCount))
                .contains(capsule.size),
            coordinatorDigestIsNonzero(gateExecutableSHA256),
            coordinatorDigestIsNonzero(gateTransportReceiptSHA256),
            gateProcessID > 1,
            gateProcessGroupID == gateProcessID,
            gateSessionID > 1,
            gateSessionID != gateProcessGroupID,
            exactGateWaitClassification == .exited(status: 0),
            receiptReachedEOF,
            !receiptOverflowObserved,
            !receiptDeadlineExpired,
            capsuleSettlementRemoved,
            attemptBaseRetired,
            runtimeArtifactsRetired,
            monotonicStartedNanoseconds > 0,
            monotonicCompletedNanoseconds > monotonicStartedNanoseconds
        else {
            throw InvestigationMachineGateCoordinatorReceiptError
                .invalidValue
        }
    }
    private static func transcript(
        buildProvenanceSHA256: String,
        signedBindingSHA256: InvestigationHandoffSHA256,
        outerAttemptUUID: UUID,
        wholeProjectedInputSHA256: InvestigationHandoffSHA256,
        capsule: InvestigationMachineGateNodeObservation,
        gateExecutableSHA256: InvestigationHandoffSHA256,
        gateTransportReceiptSHA256: InvestigationHandoffSHA256,
        gateProcessID: pid_t,
        gateProcessGroupID: pid_t,
        gateSessionID: pid_t,
        exactGateWaitClassification:
            InvestigationMachineGateWaitClassification,
        receiptReachedEOF: Bool,
        receiptOverflowObserved: Bool,
        receiptDeadlineExpired: Bool,
        capsuleSettlementRemoved: Bool,
        attemptBaseRetired: Bool,
        runtimeArtifactsRetired: Bool,
        monotonicStartedNanoseconds: UInt64,
        monotonicCompletedNanoseconds: UInt64,
        receiptSHA256Bytes: Data
    ) throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: domain,
            businessFields: [
                Data(buildProvenanceSHA256.utf8),
                signedBindingSHA256.rawBytes,
                coordinatorData(outerAttemptUUID),
                wholeProjectedInputSHA256.rawBytes,
                coordinatorData(capsule.device),
                coordinatorData(capsule.inode),
                coordinatorData(capsule.generation),
                coordinatorData(UInt64(bitPattern: capsule.size)),
                gateExecutableSHA256.rawBytes,
                gateTransportReceiptSHA256.rawBytes,
                try coordinatorData(gateProcessID),
                try coordinatorData(gateProcessGroupID),
                try coordinatorData(gateSessionID),
                try coordinatorData(exactGateWaitClassification),
                coordinatorData(receiptReachedEOF),
                coordinatorData(receiptOverflowObserved),
                coordinatorData(receiptDeadlineExpired),
                coordinatorData(capsuleSettlementRemoved),
                coordinatorData(attemptBaseRetired),
                coordinatorData(runtimeArtifactsRetired),
                coordinatorData(monotonicStartedNanoseconds),
                coordinatorData(monotonicCompletedNanoseconds),
                receiptSHA256Bytes,
            ],
            maximumByteCount: maximumByteCount
        )
    }
}
private func coordinatorValidLowercaseSHA256(_ value: String) -> Bool {
    let bytes = Array(value.utf8)
    guard bytes.count == InvestigationHandoffSHA256.byteCount * 2 else {
        return false
    }
    return bytes.allSatisfy {
        (UInt8(ascii: "0")...UInt8(ascii: "9")).contains($0)
            || (UInt8(ascii: "a")...UInt8(ascii: "f")).contains($0)
    } && bytes.contains { $0 != UInt8(ascii: "0") }
}
private func coordinatorDigestIsNonzero(
    _ value: InvestigationHandoffSHA256
) -> Bool {
    value.rawBytes.contains { $0 != 0 }
}
private func coordinatorUUIDIsNonzero(_ value: UUID) -> Bool {
    var uuid = value.uuid
    return withUnsafeBytes(of: &uuid) { bytes in
        bytes.contains { $0 != 0 }
    }
}
private func coordinatorData(_ value: Bool) -> Data {
    Data([value ? 1 : 0])
}
private func coordinatorData(_ value: UInt32) -> Data {
    Data([
        UInt8(truncatingIfNeeded: value >> 24),
        UInt8(truncatingIfNeeded: value >> 16),
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value),
    ])
}
private func coordinatorData(_ value: UInt64) -> Data {
    Data([
        UInt8(truncatingIfNeeded: value >> 56),
        UInt8(truncatingIfNeeded: value >> 48),
        UInt8(truncatingIfNeeded: value >> 40),
        UInt8(truncatingIfNeeded: value >> 32),
        UInt8(truncatingIfNeeded: value >> 24),
        UInt8(truncatingIfNeeded: value >> 16),
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value),
    ])
}
private func coordinatorData(_ value: UUID) -> Data {
    var uuid = value.uuid
    return withUnsafeBytes(of: &uuid) { Data($0) }
}
private func coordinatorData(_ value: pid_t) throws -> Data {
    coordinatorData(UInt32(bitPattern: value))
}
private func coordinatorData(
    _ value: InvestigationMachineGateWaitClassification
) throws -> Data {
    switch value {
    case .exited(let status):
        coordinatorData(UInt8(1)) + coordinatorData(UInt32(bitPattern: status))
    case .signaled(let signal):
        coordinatorData(UInt8(2)) + coordinatorData(UInt32(bitPattern: signal))
    case .stopped(let signal):
        coordinatorData(UInt8(3)) + coordinatorData(UInt32(bitPattern: signal))
    }
}
private func coordinatorData(_ value: UInt8) -> Data {
    Data([value])
}
private func coordinatorDecodeBoolean(_ data: Data) throws -> Bool {
    guard data.count == 1 else {
        throw InvestigationMachineGateCoordinatorReceiptError.invalidEncoding
    }
    switch data[data.startIndex] {
    case 0: return false
    case 1: return true
    default:
        throw InvestigationMachineGateCoordinatorReceiptError.invalidEncoding
    }
}
private func coordinatorDecodeUInt32(_ data: Data) throws -> UInt32 {
    guard data.count == 4 else {
        throw InvestigationMachineGateCoordinatorReceiptError.invalidEncoding
    }
    return data.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
}
private func coordinatorDecodeUInt64(_ data: Data) throws -> UInt64 {
    guard data.count == 8 else {
        throw InvestigationMachineGateCoordinatorReceiptError.invalidEncoding
    }
    return data.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
}
private func coordinatorDecodePID(_ data: Data) throws -> pid_t {
    Int32(bitPattern: try coordinatorDecodeUInt32(data))
}
private func coordinatorDecodeUUID(_ data: Data) throws -> UUID {
    guard data.count == 16 else {
        throw InvestigationMachineGateCoordinatorReceiptError.invalidEncoding
    }
    let bytes = Array(data)
    return UUID(uuid: (
        bytes[0], bytes[1], bytes[2], bytes[3],
        bytes[4], bytes[5], bytes[6], bytes[7],
        bytes[8], bytes[9], bytes[10], bytes[11],
        bytes[12], bytes[13], bytes[14], bytes[15]
    ))
}
private func coordinatorDecodeWait(
    _ data: Data
) throws -> InvestigationMachineGateWaitClassification {
    guard data.count == 5 else {
        throw InvestigationMachineGateCoordinatorReceiptError.invalidEncoding
    }
    let kind = data[data.startIndex]
    let raw = try coordinatorDecodeUInt32(Data(data.dropFirst()))
    let value = Int32(bitPattern: raw)
    switch kind {
    case 1: return .exited(status: value)
    case 2: return .signaled(signal: value)
    case 3: return .stopped(signal: value)
    default:
        throw InvestigationMachineGateCoordinatorReceiptError.invalidEncoding
    }
}
#endif
