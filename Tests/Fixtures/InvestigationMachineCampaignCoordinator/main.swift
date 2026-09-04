import Darwin
import Foundation
import CInvestigationMachineCampaignSupport
import StornautInvestigationMachineCampaignSupport
import StornautInvestigationHandoffContract

@main
private struct InvestigationMachineCampaignCoordinatorFixture {
    static func main() {
        do {
            guard CommandLine.argc == 1, getpid() > 1, getsid(0) == getpid(),
                  getpgrp() == getpid(), tcgetpgrp(STDERR_FILENO) == getpid()
            else { throw FixtureError.invalid }
            #if CAMPAIGN_FIXTURE_PREARM_FAILURE
            let body = try preArmFailureFrame()
            var count = UInt32(body.count).bigEndian
            let frame = withUnsafeBytes(of: &count) { Data($0) } + body
            try writeAll(
                STORNAUT_INVESTIGATION_CAMPAIGN_RECEIPT_FD, frame)
            guard close(STORNAUT_INVESTIGATION_CAMPAIGN_RECEIPT_FD) == 0,
                  close(STDIN_FILENO) == 0, close(STDOUT_FILENO) == 0,
                  close(STDERR_FILENO) == 0
            else { throw FixtureError.posix(errno) }
            _exit(81)
            #else
            try writeAll(
                STDERR_FILENO, Data("campaign-physical-diagnostic\n".utf8))
            let receipt = try InvestigationMachineCoordinatorRawReceiptV1(
                buildProvenanceSHA256: String(repeating: "a", count: 64),
                signedBindingSHA256: digest(0x42),
                outerAttemptUUID: uuid(0x41),
                wholeProjectedInputSHA256: digest(0x43),
                capsule: .init(device: 1, inode: 2, generation: 3, size: 4),
                gateExecutableSHA256: digest(0x44),
                gateTransportReceiptSHA256: digest(0x45),
                gateProcessID: 4_001, gateProcessGroupID: 4_001,
                gateSessionID: 3_901,
                exactGateWaitClassification: .exited(status: 0),
                receiptReachedEOF: true, receiptOverflowObserved: false,
                receiptDeadlineExpired: false, capsuleSettlementRemoved: true,
                attemptBaseRetired: true, runtimeArtifactsRetired: true,
                monotonicStartedNanoseconds: 10,
                monotonicCompletedNanoseconds: 20
            )
            let body = try receipt.encoded()
            var count = UInt32(body.count).bigEndian
            var frame = withUnsafeBytes(of: &count) { Data($0) } + body
            #if CAMPAIGN_FIXTURE_TRUNCATED
            frame.removeLast()
            #elseif CAMPAIGN_FIXTURE_TRAILING
            frame.append(0xff)
            #endif
            try writeAll(
                STORNAUT_INVESTIGATION_CAMPAIGN_RECEIPT_FD, frame)
            #if CAMPAIGN_FIXTURE_MISSING_EOF
            guard close(STDIN_FILENO) == 0, close(STDOUT_FILENO) == 0,
                  close(STDERR_FILENO) == 0
            else { throw FixtureError.posix(errno) }
            usleep(7_000_000)
            _exit(0)
            #else
            guard close(STORNAUT_INVESTIGATION_CAMPAIGN_RECEIPT_FD) == 0,
                  close(STDIN_FILENO) == 0, close(STDOUT_FILENO) == 0,
                  close(STDERR_FILENO) == 0
            else { throw FixtureError.posix(errno) }
            usleep(250_000)
            #if CAMPAIGN_FIXTURE_NONZERO
            _exit(17)
            #else
            _exit(0)
            #endif
            #endif
            #endif
        } catch { exit(70) }
    }
}

private enum FixtureError: Error { case invalid, posix(Int32) }

private func preArmFailureFrame() throws -> Data {
    let checkpoint = Data([2]) + digest(0x91).rawBytes + digest(0x92).rawBytes
    let fields = [
        Data([2]),
        checkpoint,
        Data([2]),
        uint32Data(81),
        Data(repeating: 0, count: 32),
    ]
    let zeroed = try HandoffBinaryTranscript.encode(
        domain: "stornaut.task39.iic.coordinator-prearm-failure.v1",
        businessFields: fields,
        maximumByteCount: 512
    )
    var finalFields = fields
    finalFields[4] = InvestigationHandoffSHA256.hashing(zeroed).rawBytes
    return try HandoffBinaryTranscript.encode(
        domain: "stornaut.task39.iic.coordinator-prearm-failure.v1",
        businessFields: finalFields,
        maximumByteCount: 512
    )
}

private func writeAll(_ descriptor: Int32, _ data: Data) throws {
    var offset = 0
    while offset < data.count {
        let count = data.withUnsafeBytes { bytes in
            write(descriptor, bytes.baseAddress! + offset, data.count - offset)
        }
        if count < 0, errno == EINTR { continue }
        guard count > 0 else { throw FixtureError.posix(errno) }
        offset += count
    }
}

private func digest(_ byte: UInt8) -> InvestigationHandoffSHA256 {
    .hashing(Data(repeating: byte, count: 32))
}

private func uint32Data(_ value: UInt32) -> Data {
    Data([
        UInt8(value >> 24),
        UInt8(truncatingIfNeeded: value >> 16),
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value),
    ])
}

private func uuid(_ byte: UInt8) -> UUID {
    UUID(uuid: (byte, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
}
