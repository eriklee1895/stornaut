import Darwin
import Foundation
import StornautInvestigationHandoffContract
import StornautInvestigationMachineGateSupport

#if DEBUG
package enum InvestigationFixedGateHandoffError:
    Error, Equatable, Sendable
{
    case invalidCanonicalInput
    case publicationFailed
    case spawnFailedBeforeTransfer
    case spawnUncertain(processID: pid_t)
    case invalidPreparedFrame
    case invalidTransportReceipt
    case identityMismatch
    case gateTerminated(InvestigationMachineGateWaitClassification)
    case forwardedSignal(Int32)
    case deadlineExceeded
    case exactReapUncertain
    case transportCloseUncertain
    case settlementResidue
    case settlementFailed
    case proofRejected
    case unexpectedResponse
    case alreadyConsumed
}

enum InvestigationFixedGateHandoffSystemError:
    Error, Equatable, Sendable
{
    case publicationFailed
    case preSpawnNoTransfer
    case spawnUncertain(processID: pid_t, processGroupID: pid_t)
    case gateTerminated(InvestigationMachineGateWaitClassification)
    case waitUncertain
    case closeUncertain
    case settlementFailed
    case proofRejected
    case unexpectedResponse
}

enum InvestigationFixedGateHandoffOperation: Equatable, Sendable {
    case publishCanonicalCapsule(Data)
    case spawnFixedGate
    case observeSpawnedProcess(processID: pid_t)
    case readPreparedFrame(maximumByteCount: Int)
    case observePreparedStop(processID: pid_t)
    case continueFixedGate(processID: pid_t)
    case readTerminalReceipt(maximumByteCount: Int)
    case waitForExactGate(processID: pid_t)
    case observeGateProcessGroupEmpty(processGroupID: pid_t)
    case closeTransport
    case settleExactGateReaped
    case settleNeverHandedOff
}

enum InvestigationFixedGateHandoffResponse: Equatable, Sendable {
    case publishedCapsule(
        outerAttemptUUID: UUID,
        wholeInputSHA256: InvestigationHandoffSHA256,
        node: InvestigationMachineGateNodeObservation
    )
    case spawnedGate(
        processID: pid_t,
        processGroupID: pid_t,
        executableSHA256: InvestigationHandoffSHA256
    )
    case processExists(Bool)
    case frame(bytes: Data, reachedEOF: Bool, overflowObserved: Bool)
    case waitClassification(InvestigationMachineGateWaitClassification)
    case exactGateReap(
        waitClassification: InvestigationMachineGateWaitClassification,
        exactChildReaped: Bool
    )
    case processGroupEmpty(Bool)
    case completed
    case settlement(InvestigationOwnerOnlyCapsuleSettlementResult)
}

protocol InvestigationFixedGateHandoffSystem: AnyObject, Sendable {
    func perform(
        _ operation: InvestigationFixedGateHandoffOperation
    ) throws -> InvestigationFixedGateHandoffResponse
}

package enum InvestigationFixedGateSettlementProjection:
    Equatable, Sendable
{
    case removed
}

package struct InvestigationMachineGateHandoffReceipt:
    Equatable, Sendable
{
    package let outerAttemptUUID: UUID
    package let wholeInputSHA256: InvestigationHandoffSHA256
    package let capsule: InvestigationMachineGateNodeObservation
    package let gateProcessID: pid_t
    package let gateProcessGroupID: pid_t
    package let gateExecutableSHA256: InvestigationHandoffSHA256
    package let preparedFrameSHA256: InvestigationHandoffSHA256
    package let gateTransportReceipt: InvestigationMachineGateTransportReceipt
    package let gateTransportReceiptSHA256: InvestigationHandoffSHA256
    package let exactGateWaitClassification:
        InvestigationMachineGateWaitClassification
    package let settlement: InvestigationFixedGateSettlementProjection

    init(
        outerAttemptUUID: UUID,
        wholeInputSHA256: InvestigationHandoffSHA256,
        capsule: InvestigationMachineGateNodeObservation,
        gateProcessID: pid_t,
        gateProcessGroupID: pid_t,
        gateExecutableSHA256: InvestigationHandoffSHA256,
        preparedFrame: InvestigationMachineGatePreparedFrame,
        gateTransportReceipt: InvestigationMachineGateTransportReceipt,
        exactGateWaitClassification:
            InvestigationMachineGateWaitClassification,
        settlement: InvestigationOwnerOnlyCapsuleSettlementResult
    ) throws {
        try Self.validate(
            outerAttemptUUID: outerAttemptUUID,
            wholeInputSHA256: wholeInputSHA256, capsule: capsule,
            gateProcessID: gateProcessID,
            gateProcessGroupID: gateProcessGroupID,
            gateExecutableSHA256: gateExecutableSHA256,
            preparedFrame: preparedFrame,
            gateTransportReceipt: gateTransportReceipt,
            exactGateWaitClassification: exactGateWaitClassification
        )
        let preparedBytes: Data
        let transportBytes: Data
        do {
            preparedBytes = try preparedFrame.encoded()
            transportBytes = try gateTransportReceipt.encoded()
        } catch {
            throw InvestigationFixedGateHandoffError
                .invalidTransportReceipt
        }
        let preparedSHA256 = InvestigationHandoffSHA256.hashing(
            preparedBytes
        )
        let transportSHA256 = InvestigationHandoffSHA256.hashing(
            transportBytes
        )

        if let signal = gateTransportReceipt.forwardedSignal {
            throw InvestigationFixedGateHandoffError.forwardedSignal(signal)
        }
        guard !gateTransportReceipt.output.deadlineExpired else {
            throw InvestigationFixedGateHandoffError.deadlineExceeded
        }
        guard
            InvestigationMachineGateSupport.status(for: gateTransportReceipt)
                == InvestigationMachineGateSupport.completedExitStatus,
            exactGateWaitClassification == .exited(
                status: InvestigationMachineGateSupport.completedExitStatus
            )
        else {
            throw InvestigationFixedGateHandoffError.gateTerminated(
                exactGateWaitClassification
            )
        }
        guard case .removed = settlement else {
            throw InvestigationFixedGateHandoffError.settlementResidue
        }

        self.outerAttemptUUID = outerAttemptUUID
        self.wholeInputSHA256 = wholeInputSHA256
        self.capsule = capsule
        self.gateProcessID = gateProcessID
        self.gateProcessGroupID = gateProcessGroupID
        self.gateExecutableSHA256 = gateExecutableSHA256
        preparedFrameSHA256 = preparedSHA256
        self.gateTransportReceipt = gateTransportReceipt
        gateTransportReceiptSHA256 = transportSHA256
        self.exactGateWaitClassification = exactGateWaitClassification
        self.settlement = .removed
    }

    static func validate(
        outerAttemptUUID: UUID,
        wholeInputSHA256: InvestigationHandoffSHA256,
        capsule: InvestigationMachineGateNodeObservation,
        gateProcessID: pid_t,
        gateProcessGroupID: pid_t,
        gateExecutableSHA256: InvestigationHandoffSHA256,
        preparedFrame: InvestigationMachineGatePreparedFrame,
        gateTransportReceipt: InvestigationMachineGateTransportReceipt,
        exactGateWaitClassification:
            InvestigationMachineGateWaitClassification
    ) throws {
        let preparedSHA256: InvestigationHandoffSHA256
        do {
            preparedSHA256 = .hashing(try preparedFrame.encoded())
        } catch {
            throw InvestigationFixedGateHandoffError.invalidTransportReceipt
        }
        guard
            ivB1UUIDIsNonzero(outerAttemptUUID),
            ivB1DigestIsNonzero(wholeInputSHA256),
            ivB1CapsuleIsValid(capsule),
            gateProcessID > 1,
            gateProcessGroupID == gateProcessID,
            ivB1DigestIsNonzero(gateExecutableSHA256),
            preparedFrame.gateProcessID == gateProcessID,
            preparedFrame.recoveryProcessGroupID == gateProcessGroupID,
            preparedFrame.outerAttemptUUID == outerAttemptUUID,
            preparedFrame.wholeInputSHA256 == wholeInputSHA256,
            preparedFrame.capsule == capsule,
            gateTransportReceipt.launcherExecutableSHA256
                == gateExecutableSHA256,
            gateTransportReceipt.outerAttemptUUID == outerAttemptUUID,
            gateTransportReceipt.wholeInputSHA256 == wholeInputSHA256,
            gateTransportReceipt.preparedFrameSHA256 == preparedSHA256,
            gateTransportReceipt.capsule == capsule,
            gateTransportReceipt.gateProcessID == gateProcessID,
            gateTransportReceipt.recoveryProcessGroupID
                == gateProcessGroupID,
            gateTransportReceipt.coordinatorProcessID
                == preparedFrame.coordinatorProcessID,
            gateTransportReceipt.sessionID == preparedFrame.sessionID,
            gateTransportReceipt.savedForegroundProcessGroupID
                == preparedFrame.savedForegroundProcessGroupID,
            gateTransportReceipt.childIdentity
                == preparedFrame.childIdentity,
            gateTransportReceipt.initialTerminal == preparedFrame.terminal,
            exactGateWaitClassification == .exited(
                status: InvestigationMachineGateSupport.status(
                    for: gateTransportReceipt
                )
            )
        else {
            throw InvestigationFixedGateHandoffError.identityMismatch
        }
    }
}

private func ivB1DigestIsNonzero(
    _ value: InvestigationHandoffSHA256
) -> Bool {
    value.rawBytes.contains { $0 != 0 }
}

private func ivB1UUIDIsNonzero(_ value: UUID) -> Bool {
    withUnsafeBytes(of: value.uuid) { bytes in
        bytes.contains { $0 != 0 }
    }
}

private func ivB1CapsuleIsValid(
    _ value: InvestigationMachineGateNodeObservation
) -> Bool {
    value.device > 0 && value.inode > 0
        && (1...Int64(InvestigationProjectedCohortInput.maximumByteCount))
            .contains(value.size)
}
#endif
