import Darwin
import Foundation
import StornautInvestigationHandoffContract
import StornautInvestigationMachineGateSupport

#if DEBUG
/// The package-closed, one-shot coordinator side of the fixed machine gate.
///
/// All descriptor, path, lease-token and proof capabilities remain behind the
/// injected system boundary.  The only successful projection is a typed
/// receipt after the exact gate has been reaped, its process group has been
/// observed empty, the transport has been closed, and the capsule has settled.
package final class InvestigationFixedGateHandoff: @unchecked Sendable {
    private struct Publication: Sendable {
        let outerAttemptUUID: UUID
        let wholeInputSHA256: InvestigationHandoffSHA256
        let node: InvestigationMachineGateNodeObservation
    }

    private struct Spawn: Sendable {
        let processID: pid_t
        let processGroupID: pid_t
        let executableSHA256: InvestigationHandoffSHA256
    }

    private struct FrameRead: Sendable {
        let bytes: Data
        let reachedEOF: Bool
        let overflowObserved: Bool
    }

    private struct CleanupOutcome {
        let waitClassification: InvestigationMachineGateWaitClassification?
        let overridingError: InvestigationFixedGateHandoffError?
    }

    private let system: any InvestigationFixedGateHandoffSystem
    private let consumptionLock = NSLock()
    private var consumed = false


    init(system: any InvestigationFixedGateHandoffSystem) {
        self.system = system
    }

    package func run(
        canonicalProjectedInput: Data
    ) throws -> InvestigationMachineGateHandoffReceipt {
        guard consume() else {
            throw InvestigationFixedGateHandoffError.alreadyConsumed
        }

        let projectedInput = try decodeCanonicalInput(canonicalProjectedInput)
        let publication = try publish(
            canonicalProjectedInput, expected: projectedInput
        )

        let spawn: Spawn
        do {
            spawn = try spawnGate()
        } catch InvestigationFixedGateHandoffSystemError.preSpawnNoTransfer {
            try settleNeverHandedOff()
            throw InvestigationFixedGateHandoffError.spawnFailedBeforeTransfer
        } catch InvestigationFixedGateHandoffSystemError.spawnUncertain(
            let processID, let processGroupID
        ) {
            try finishUncertainSpawn(
                processID: processID, processGroupID: processGroupID
            )
            throw InvestigationFixedGateHandoffError.spawnUncertain(
                processID: processID
            )
        } catch let error as InvestigationFixedGateHandoffError {
            throw error
        } catch {
            throw mapSystemError(error)
        }

        var primaryError: InvestigationFixedGateHandoffError?
        var preparedFrame: InvestigationMachineGatePreparedFrame?
        var transportReceipt: InvestigationMachineGateTransportReceipt?

        do {
            let preparedRead = try readFrame(
                .readPreparedFrame(
                    maximumByteCount:
                        InvestigationMachineGatePreparedFrame.maximumByteCount
                )
            )
            let prepared = try decodePrepared(preparedRead)
            guard preparedMatches(
                prepared, publication: publication, spawn: spawn
            ) else {
                throw InvestigationFixedGateHandoffError.identityMismatch
            }
            preparedFrame = prepared

            let stop = try waitClassification(
                .observePreparedStop(processID: spawn.processID)
            )
            guard case .stopped(signal: SIGSTOP) = stop else {
                throw InvestigationFixedGateHandoffError.gateTerminated(stop)
            }
            try requireCompleted(
                .continueFixedGate(processID: spawn.processID)
            )

            let terminalRead = try readFrame(
                .readTerminalReceipt(
                    maximumByteCount:
                        InvestigationMachineGateTransportReceipt.maximumByteCount
                )
            )
            transportReceipt = try decodeTerminal(terminalRead)
        } catch {
            primaryError = mapOperationalError(error)
        }

        let cleanup = cleanupSpawnedGate(
            processID: spawn.processID,
            processGroupID: spawn.processGroupID
        )
        if let overridingError = cleanup.overridingError {
            throw overridingError
        }
        if let primaryError {
            throw primaryError
        }
        guard
            let preparedFrame,
            let transportReceipt,
            let waitClassification = cleanup.waitClassification
        else {
            throw InvestigationFixedGateHandoffError.unexpectedResponse
        }
        guard deadlineMatches(
            preparedFrame: preparedFrame, receipt: transportReceipt
        ) else {
            throw InvestigationFixedGateHandoffError.identityMismatch
        }
        try InvestigationMachineGateHandoffReceipt.validate(
            outerAttemptUUID: publication.outerAttemptUUID,
            wholeInputSHA256: publication.wholeInputSHA256,
            capsule: publication.node,
            gateProcessID: spawn.processID,
            gateProcessGroupID: spawn.processGroupID,
            gateExecutableSHA256: spawn.executableSHA256,
            preparedFrame: preparedFrame,
            gateTransportReceipt: transportReceipt,
            exactGateWaitClassification: waitClassification
        )
        if let signal = transportReceipt.forwardedSignal {
            throw InvestigationFixedGateHandoffError.forwardedSignal(signal)
        }
        guard !transportReceipt.output.deadlineExpired else {
            throw InvestigationFixedGateHandoffError.deadlineExceeded
        }
        guard
            InvestigationMachineGateSupport.status(for: transportReceipt)
                == InvestigationMachineGateSupport.completedExitStatus,
            waitClassification == .exited(
                status: InvestigationMachineGateSupport.completedExitStatus
            )
        else {
            throw InvestigationFixedGateHandoffError.gateTerminated(
                waitClassification
            )
        }
        let settlement: InvestigationOwnerOnlyCapsuleSettlementResult
        do {
            settlement = try settlementResponse(.settleExactGateReaped)
        } catch {
            throw mapSettlementError(error)
        }
        guard case .removed = settlement else {
            throw InvestigationFixedGateHandoffError.settlementResidue
        }

        return try InvestigationMachineGateHandoffReceipt(
            outerAttemptUUID: publication.outerAttemptUUID,
            wholeInputSHA256: publication.wholeInputSHA256,
            capsule: publication.node,
            gateProcessID: spawn.processID,
            gateProcessGroupID: spawn.processGroupID,
            gateExecutableSHA256: spawn.executableSHA256,
            preparedFrame: preparedFrame,
            gateTransportReceipt: transportReceipt,
            exactGateWaitClassification: waitClassification,
            settlement: settlement
        )
    }

    private func consume() -> Bool {
        consumptionLock.withLock {
            guard !consumed else { return false }
            consumed = true
            return true
        }
    }

    private func decodeCanonicalInput(
        _ bytes: Data
    ) throws -> InvestigationProjectedCohortInput {
        do {
            guard
                !bytes.isEmpty,
                bytes.count <= InvestigationProjectedCohortInput.maximumByteCount
            else {
                throw InvestigationFixedGateHandoffError.invalidCanonicalInput
            }
            let value = try InvestigationProjectedCohortInput.decode(bytes)
            guard try value.encoded() == bytes else {
                throw InvestigationFixedGateHandoffError.invalidCanonicalInput
            }
            return value
        } catch let error as InvestigationFixedGateHandoffError {
            throw error
        } catch {
            throw InvestigationFixedGateHandoffError.invalidCanonicalInput
        }
    }

    private func publish(
        _ bytes: Data, expected: InvestigationProjectedCohortInput
    ) throws -> Publication {
        let response: InvestigationFixedGateHandoffResponse
        do {
            response = try system.perform(.publishCanonicalCapsule(bytes))
        } catch {
            throw InvestigationFixedGateHandoffError.publicationFailed
        }
        guard case .publishedCapsule(
            let outerAttemptUUID, let wholeInputSHA256, let node
        ) = response else {
            throw InvestigationFixedGateHandoffError.publicationFailed
        }

        let publication = Publication(
            outerAttemptUUID: outerAttemptUUID,
            wholeInputSHA256: wholeInputSHA256,
            node: node
        )
        guard
            outerAttemptUUID == expected.capsule.outerAttemptUUID,
            wholeInputSHA256 == expected.wholeInputSHA256,
            node.device > 0, node.inode > 0,
            node.size == Int64(bytes.count)
        else {
            try settleNeverHandedOff()
            throw InvestigationFixedGateHandoffError.identityMismatch
        }
        return publication
    }

    private func spawnGate() throws -> Spawn {
        let response = try system.perform(.spawnFixedGate)
        guard case .spawnedGate(
            let processID, let processGroupID, let executableSHA256
        ) = response else {
            throw InvestigationFixedGateHandoffSystemError.unexpectedResponse
        }
        let spawn = Spawn(
            processID: processID, processGroupID: processGroupID,
            executableSHA256: executableSHA256
        )
        guard
            processID > 1, processGroupID == processID,
            executableSHA256.rawBytes.contains(where: { $0 != 0 })
        else {
            let cleanup = cleanupSpawnedGate(
                processID: processID, processGroupID: processGroupID
            )
            if let overridingError = cleanup.overridingError {
                throw overridingError
            }
            throw InvestigationFixedGateHandoffError.identityMismatch
        }
        return spawn
    }

    private func finishUncertainSpawn(
        processID: pid_t, processGroupID: pid_t
    ) throws {
        guard processID > 1, processGroupID == processID else { return }

        let response: InvestigationFixedGateHandoffResponse
        do {
            response = try system.perform(
                .observeSpawnedProcess(processID: processID)
            )
        } catch {
            if let closeError = closeTransportOnly() { throw closeError }
            return
        }
        guard case .processExists(let exists) = response, exists else {
            if let closeError = closeTransportOnly() { throw closeError }
            return
        }

        let cleanup = cleanupSpawnedGate(
            processID: processID, processGroupID: processGroupID
        )
        if let overridingError = cleanup.overridingError {
            throw overridingError
        }
    }

    private func decodePrepared(
        _ read: FrameRead
    ) throws -> InvestigationMachineGatePreparedFrame {
        guard
            !read.reachedEOF, !read.overflowObserved,
            read.bytes.count
                == InvestigationMachineGatePreparedFrame.encodedByteCount,
            read.bytes.count
                <= InvestigationMachineGatePreparedFrame.maximumByteCount
        else {
            throw InvestigationFixedGateHandoffError.invalidPreparedFrame
        }
        do {
            let value = try InvestigationMachineGatePreparedFrame.decode(
                read.bytes
            )
            guard try value.encoded() == read.bytes else {
                throw InvestigationFixedGateHandoffError.invalidPreparedFrame
            }
            return value
        } catch let error as InvestigationFixedGateHandoffError {
            throw error
        } catch {
            throw InvestigationFixedGateHandoffError.invalidPreparedFrame
        }
    }

    private func decodeTerminal(
        _ read: FrameRead
    ) throws -> InvestigationMachineGateTransportReceipt {
        guard
            read.reachedEOF, !read.overflowObserved,
            read.bytes.count
                == InvestigationMachineGateTransportReceipt.encodedByteCount,
            read.bytes.count
                <= InvestigationMachineGateTransportReceipt.maximumByteCount
        else {
            throw InvestigationFixedGateHandoffError.invalidTransportReceipt
        }
        do {
            let value = try InvestigationMachineGateTransportReceipt.decode(
                read.bytes
            )
            guard try value.encoded() == read.bytes else {
                throw InvestigationFixedGateHandoffError
                    .invalidTransportReceipt
            }
            return value
        } catch let error as InvestigationFixedGateHandoffError {
            throw error
        } catch {
            throw InvestigationFixedGateHandoffError.invalidTransportReceipt
        }
    }

    private func preparedMatches(
        _ prepared: InvestigationMachineGatePreparedFrame,
        publication: Publication, spawn: Spawn
    ) -> Bool {
        guard
            prepared.gateProcessID == spawn.processID,
            prepared.recoveryProcessGroupID == spawn.processGroupID,
            prepared.outerAttemptUUID == publication.outerAttemptUUID,
            prepared.wholeInputSHA256 == publication.wholeInputSHA256,
            prepared.capsule == publication.node
        else {
            return false
        }
        let (expectedDeadline, overflow) =
            prepared.absoluteDeadlineNanoseconds.subtractingReportingOverflow(
                InvestigationMachineFixedGateContract.deadlineNanoseconds
            )
        return !overflow && expectedDeadline > 0
    }

    private func deadlineMatches(
        preparedFrame: InvestigationMachineGatePreparedFrame,
        receipt: InvestigationMachineGateTransportReceipt
    ) -> Bool {
        let (deadline, overflow) =
            receipt.monotonicStartedNanoseconds.addingReportingOverflow(
                InvestigationMachineFixedGateContract.deadlineNanoseconds
            )
        return !overflow
            && preparedFrame.absoluteDeadlineNanoseconds == deadline
    }

    private func cleanupSpawnedGate(
        processID: pid_t, processGroupID: pid_t
    ) -> CleanupOutcome {
        var waitClassification: InvestigationMachineGateWaitClassification?
        var exactReaped = false
        var overridingError: InvestigationFixedGateHandoffError?

        do {
            let response = try system.perform(
                .waitForExactGate(processID: processID)
            )
            guard case .exactGateReap(
                let classification, let exactChildReaped
            ) = response else {
                throw InvestigationFixedGateHandoffSystemError.unexpectedResponse
            }
            waitClassification = classification
            exactReaped = exactChildReaped && isTerminal(classification)
            if !exactReaped {
                overridingError = .exactReapUncertain
            }
        } catch {
            overridingError = .exactReapUncertain
        }

        if exactReaped {
            do {
                let response = try system.perform(
                    .observeGateProcessGroupEmpty(
                        processGroupID: processGroupID
                    )
                )
                guard case .processGroupEmpty(let empty) = response else {
                    throw InvestigationFixedGateHandoffSystemError
                        .unexpectedResponse
                }
                if !empty { overridingError = .exactReapUncertain }
            } catch {
                overridingError = .exactReapUncertain
            }
        }

        let closeError = closeTransportOnly()
        if closeError != nil {
            overridingError = .transportCloseUncertain
        }

        return CleanupOutcome(
            waitClassification: waitClassification,
            overridingError: overridingError
        )
    }

    private func closeTransportOnly() -> InvestigationFixedGateHandoffError? {
        do {
            try requireCompleted(.closeTransport)
            return nil
        } catch {
            return .transportCloseUncertain
        }
    }

    private func settleNeverHandedOff() throws {
        let settlement: InvestigationOwnerOnlyCapsuleSettlementResult
        do {
            settlement = try settlementResponse(.settleNeverHandedOff)
        } catch {
            throw mapSettlementError(error)
        }
        guard case .removed = settlement else {
            throw InvestigationFixedGateHandoffError.settlementResidue
        }
    }

    private func settlementResponse(
        _ operation: InvestigationFixedGateHandoffOperation
    ) throws -> InvestigationOwnerOnlyCapsuleSettlementResult {
        let response = try system.perform(operation)
        guard case .settlement(let value) = response else {
            throw InvestigationFixedGateHandoffSystemError.unexpectedResponse
        }
        return value
    }

    private func readFrame(
        _ operation: InvestigationFixedGateHandoffOperation
    ) throws -> FrameRead {
        let response = try system.perform(operation)
        guard case .frame(
            let bytes, let reachedEOF, let overflowObserved
        ) = response else {
            throw InvestigationFixedGateHandoffSystemError.unexpectedResponse
        }
        return FrameRead(
            bytes: bytes, reachedEOF: reachedEOF,
            overflowObserved: overflowObserved
        )
    }

    private func waitClassification(
        _ operation: InvestigationFixedGateHandoffOperation
    ) throws -> InvestigationMachineGateWaitClassification {
        let response = try system.perform(operation)
        guard case .waitClassification(let value) = response else {
            throw InvestigationFixedGateHandoffSystemError.unexpectedResponse
        }
        return value
    }

    private func requireCompleted(
        _ operation: InvestigationFixedGateHandoffOperation
    ) throws {
        guard case .completed = try system.perform(operation) else {
            throw InvestigationFixedGateHandoffSystemError.unexpectedResponse
        }
    }

    private func isTerminal(
        _ value: InvestigationMachineGateWaitClassification
    ) -> Bool {
        switch value {
        case .exited, .signaled: true
        case .stopped: false
        }
    }

    private func mapOperationalError(
        _ error: Error
    ) -> InvestigationFixedGateHandoffError {
        if let value = error as? InvestigationFixedGateHandoffError {
            return value
        }
        return mapSystemError(error)
    }

    private func mapSystemError(
        _ error: Error
    ) -> InvestigationFixedGateHandoffError {
        guard let value = error as? InvestigationFixedGateHandoffSystemError
        else {
            return .unexpectedResponse
        }
        switch value {
        case .publicationFailed:
            return .publicationFailed
        case .preSpawnNoTransfer:
            return .spawnFailedBeforeTransfer
        case .spawnUncertain(let processID, _):
            return .spawnUncertain(processID: processID)
        case .gateTerminated(let classification):
            return .gateTerminated(classification)
        case .waitUncertain:
            return .exactReapUncertain
        case .closeUncertain:
            return .transportCloseUncertain
        case .settlementFailed:
            return .settlementFailed
        case .proofRejected:
            return .proofRejected
        case .unexpectedResponse:
            return .unexpectedResponse
        }
    }

    private func mapSettlementError(
        _ error: Error
    ) -> InvestigationFixedGateHandoffError {
        guard let value = error as? InvestigationFixedGateHandoffSystemError
        else {
            return .settlementFailed
        }
        switch value {
        case .proofRejected:
            return .proofRejected
        case .settlementFailed:
            return .settlementFailed
        default:
            return .settlementFailed
        }
    }
}
#endif
