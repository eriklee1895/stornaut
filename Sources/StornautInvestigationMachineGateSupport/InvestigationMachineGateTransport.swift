// Package-closed transport for the authority-free machine gate.
import Darwin
import Foundation
import StornautInvestigationHandoffContract

package enum InvestigationMachineFixedGateContract {
    package static let launcherPath = "/usr/bin/sudo"
    package static let driverPath =
        "/Library/Application Support/Stornaut/"
        + "Stornaut-R5-Diagnostic.app/Contents/MacOS/"
        + "StornautInvestigationMachineDriver"
    package static let arguments = [
        launcherPath, "-N", "-p",
        "Stornaut Task 39 ii-c administrator authorization: ",
        "--", driverPath,
    ]
    package static let environment: [String] = []
    package static let requiredUserID: uid_t = 501
    package static let requiredGroupID: gid_t = 20
    package static let deadlineNanoseconds: UInt64 = 1_200_000_000_000
    package static let maximumCapturedOutputByteCount = 512
    package static let maximumReadOutputByteCount = 513
    package static let forwardedSignals: [Int32] = [
        SIGHUP, SIGINT, SIGQUIT, SIGTERM,
    ]
    package static let childSpawnFlags = Int16(
        POSIX_SPAWN_CLOEXEC_DEFAULT
            | POSIX_SPAWN_START_SUSPENDED
            | POSIX_SPAWN_SETSIGMASK
            | POSIX_SPAWN_SETSIGDEF
    )
}

package enum InvestigationMachineGateError: Error, Equatable, Sendable {
    case invalidInvocation
    case invalidFrame
    case invalidObservation
    case invalidReceipt
    case unexpectedResponse
    case invalidChildProcessGroup
    case restorationUncertain
    case containmentUncertain
    case receiptWriteFailed
    case forwardedSignal(Int32)
}

struct InvestigationMachineGateSpawnFailure: Error, Equatable, Sendable {
    let processID: pid_t
    let processGroupID: pid_t
}

package struct InvestigationMachineGateNodeObservation: Equatable, Sendable {
    package let device: UInt64
    package let inode: UInt64
    package let generation: UInt64
    package let size: Int64

    package init(
        device: UInt64, inode: UInt64, generation: UInt64, size: Int64
    ) {
        self.device = device
        self.inode = inode
        self.generation = generation
        self.size = size
    }

    fileprivate var isValidCapsuleNode: Bool {
        device > 0 && inode > 0
            && (1...Int64(InvestigationProjectedCohortInput.maximumByteCount))
                .contains(size)
    }
}

package struct InvestigationMachineGateTerminalObservation:
    Equatable,
    Sendable
{
    package let device: UInt64
    package let inode: UInt64
    package let foregroundProcessGroupID: pid_t

    package init(
        device: UInt64, inode: UInt64, foregroundProcessGroupID: pid_t
    ) {
        self.device = device
        self.inode = inode
        self.foregroundProcessGroupID = foregroundProcessGroupID
    }

    fileprivate var isValid: Bool {
        device > 0 && inode > 0 && foregroundProcessGroupID > 0
    }

    fileprivate func hasSameNode(
        as other: InvestigationMachineGateTerminalObservation
    ) -> Bool {
        device == other.device && inode == other.inode
    }
}

package struct InvestigationMachineGateInputObservation: Equatable, Sendable {
    package let node: InvestigationMachineGateNodeObservation
    package let initialOffset: Int64
    package let finalOffset: Int64
    package let reachedEOF: Bool
    package let sha256: InvestigationHandoffSHA256

    package init(
        node: InvestigationMachineGateNodeObservation,
        initialOffset: Int64,
        finalOffset: Int64,
        reachedEOF: Bool,
        sha256: InvestigationHandoffSHA256
    ) {
        self.node = node
        self.initialOffset = initialOffset
        self.finalOffset = finalOffset
        self.reachedEOF = reachedEOF
        self.sha256 = sha256
    }
}

package struct InvestigationMachineGateInputContext: Equatable, Sendable {
    package let outerAttemptUUID: UUID
    package let expectedWholeInputSHA256: InvestigationHandoffSHA256
    package let capsule: InvestigationMachineGateNodeObservation
    package let initialOffset: Int64

    package var wholeInputSHA256: InvestigationHandoffSHA256 {
        expectedWholeInputSHA256
    }

    package var node: InvestigationMachineGateNodeObservation {
        capsule
    }

    package init(
        outerAttemptUUID: UUID,
        expectedWholeInputSHA256: InvestigationHandoffSHA256,
        capsule: InvestigationMachineGateNodeObservation,
        initialOffset: Int64
    ) {
        self.outerAttemptUUID = outerAttemptUUID
        self.expectedWholeInputSHA256 = expectedWholeInputSHA256
        self.capsule = capsule
        self.initialOffset = initialOffset
    }

    package init(
        outerAttemptUUID: UUID,
        wholeInputSHA256: InvestigationHandoffSHA256,
        node: InvestigationMachineGateNodeObservation,
        initialOffset: Int64
    ) {
        self.init(
            outerAttemptUUID: outerAttemptUUID,
            expectedWholeInputSHA256: wholeInputSHA256,
            capsule: node,
            initialOffset: initialOffset
        )
    }

    package func validate() throws {
        guard
            gateUUIDIsNonzero(outerAttemptUUID),
            gateDigestIsNonzero(expectedWholeInputSHA256),
            capsule.isValidCapsuleNode,
            initialOffset == 0
        else {
            throw InvestigationMachineGateError.invalidObservation
        }
    }
}

package struct InvestigationMachineGateOutputObservation: Equatable, Sendable {
    package let byteCount: Int
    package let sha256: InvestigationHandoffSHA256
    package let overflowObserved: Bool
    package let reachedEOF: Bool
    package let deadlineExpired: Bool

    package init(
        byteCount: Int,
        sha256: InvestigationHandoffSHA256,
        overflowObserved: Bool,
        reachedEOF: Bool = true,
        deadlineExpired: Bool = false
    ) {
        self.byteCount = byteCount
        self.sha256 = sha256
        self.overflowObserved = overflowObserved
        self.reachedEOF = reachedEOF
        self.deadlineExpired = deadlineExpired
    }
}

package enum InvestigationMachineGateWaitClassification: Equatable, Sendable {
    case exited(status: Int32)
    case signaled(signal: Int32)
    case stopped(signal: Int32)

    fileprivate var isValid: Bool {
        switch self {
        case .exited(let status):
            (0...255).contains(status)
        case .signaled(let signal), .stopped(let signal):
            gateValidSignal(signal)
        }
    }

    fileprivate var encodedBytes: Data {
        switch self {
        case .exited(let status):
            gateData(UInt8(1)) + gateData(UInt32(status))
        case .signaled(let signal):
            gateData(UInt8(2)) + gateData(UInt32(signal))
        case .stopped(let signal):
            gateData(UInt8(3)) + gateData(UInt32(signal))
        }
    }

    fileprivate static func decode(_ data: Data) throws -> Self {
        guard data.count == 5 else {
            throw InvestigationMachineGateError.invalidReceipt
        }
        let kind = data[data.startIndex]
        let value = try gateDecodeUInt32(Data(data.dropFirst()))
        guard let signed = Int32(exactly: value) else {
            throw InvestigationMachineGateError.invalidReceipt
        }
        let result: Self
        switch kind {
        case 1: result = .exited(status: signed)
        case 2: result = .signaled(signal: signed)
        case 3: result = .stopped(signal: signed)
        default: throw InvestigationMachineGateError.invalidReceipt
        }
        guard result.isValid, result.encodedBytes == data else {
            throw InvestigationMachineGateError.invalidReceipt
        }
        return result
    }
}

package enum InvestigationMachineGateTerminationProgression:
    UInt8,
    Equatable,
    Sendable
{
    case natural = 1
    case term = 2
    case termThenKill = 3
}

package enum InvestigationMachineGateBorrowedDescriptorOutcome:
    Equatable,
    Sendable
{
    case closed
    case closeFailed(errno: Int32)

    fileprivate var encodedBytes: Data {
        switch self {
        case .closed:
            gateData(UInt8(1)) + gateData(UInt32(0))
        case .closeFailed(let value):
            gateData(UInt8(2)) + gateData(UInt32(value))
        }
    }

    fileprivate var isValid: Bool {
        switch self {
        case .closed: true
        case .closeFailed(let value): value > 0
        }
    }

    fileprivate static func decode(_ data: Data) throws -> Self {
        guard data.count == 5 else {
            throw InvestigationMachineGateError.invalidReceipt
        }
        let kind = data[data.startIndex]
        let value = try gateDecodeUInt32(Data(data.dropFirst()))
        let result: Self
        switch kind {
        case 1 where value == 0:
            result = .closed
        case 2:
            guard let signed = Int32(exactly: value), signed > 0 else {
                throw InvestigationMachineGateError.invalidReceipt
            }
            result = .closeFailed(errno: signed)
        default:
            throw InvestigationMachineGateError.invalidReceipt
        }
        guard result.isValid, result.encodedBytes == data else {
            throw InvestigationMachineGateError.invalidReceipt
        }
        return result
    }
}

package struct InvestigationMachineGateInvocationObservation:
    Equatable,
    Sendable
{
    package let argumentCount: Int
    package let environmentCount: Int
    package let realUserID: uid_t
    package let effectiveUserID: uid_t
    package let realGroupID: gid_t
    package let effectiveGroupID: gid_t
    package let inputDescriptorValid: Bool
    package let outputDescriptorWritable: Bool
    package let terminalDescriptorWritableCharacterDevice: Bool
    package let processID: pid_t
    package let parentProcessID: pid_t
    package let sessionID: pid_t
    package let processGroupID: pid_t
    package let foregroundProcessGroupID: pid_t

    package init(
        argumentCount: Int, environmentCount: Int,
        realUserID: uid_t, effectiveUserID: uid_t,
        realGroupID: gid_t, effectiveGroupID: gid_t,
        inputDescriptorValid: Bool, outputDescriptorWritable: Bool,
        terminalDescriptorWritableCharacterDevice: Bool,
        processID: pid_t, parentProcessID: pid_t, sessionID: pid_t,
        processGroupID: pid_t, foregroundProcessGroupID: pid_t
    ) {
        self.argumentCount = argumentCount
        self.environmentCount = environmentCount
        self.realUserID = realUserID
        self.effectiveUserID = effectiveUserID
        self.realGroupID = realGroupID
        self.effectiveGroupID = effectiveGroupID
        self.inputDescriptorValid = inputDescriptorValid
        self.outputDescriptorWritable = outputDescriptorWritable
        self.terminalDescriptorWritableCharacterDevice =
            terminalDescriptorWritableCharacterDevice
        self.processID = processID
        self.parentProcessID = parentProcessID
        self.sessionID = sessionID
        self.processGroupID = processGroupID
        self.foregroundProcessGroupID = foregroundProcessGroupID
    }

    package func replacing(
        argumentCount: Int? = nil,
        environmentCount: Int? = nil,
        realUserID: uid_t? = nil,
        effectiveUserID: uid_t? = nil,
        realGroupID: gid_t? = nil,
        effectiveGroupID: gid_t? = nil,
        inputDescriptorValid: Bool? = nil,
        outputDescriptorWritable: Bool? = nil,
        terminalDescriptorWritableCharacterDevice: Bool? = nil,
        processID: pid_t? = nil,
        parentProcessID: pid_t? = nil,
        sessionID: pid_t? = nil,
        processGroupID: pid_t? = nil,
        foregroundProcessGroupID: pid_t? = nil
    ) -> Self {
        Self(
            argumentCount: argumentCount ?? self.argumentCount,
            environmentCount: environmentCount ?? self.environmentCount,
            realUserID: realUserID ?? self.realUserID,
            effectiveUserID: effectiveUserID ?? self.effectiveUserID,
            realGroupID: realGroupID ?? self.realGroupID,
            effectiveGroupID: effectiveGroupID ?? self.effectiveGroupID,
            inputDescriptorValid:
                inputDescriptorValid ?? self.inputDescriptorValid,
            outputDescriptorWritable:
                outputDescriptorWritable ?? self.outputDescriptorWritable,
            terminalDescriptorWritableCharacterDevice:
                terminalDescriptorWritableCharacterDevice
                    ?? self.terminalDescriptorWritableCharacterDevice,
            processID: processID ?? self.processID,
            parentProcessID: parentProcessID ?? self.parentProcessID,
            sessionID: sessionID ?? self.sessionID,
            processGroupID: processGroupID ?? self.processGroupID,
            foregroundProcessGroupID:
                foregroundProcessGroupID ?? self.foregroundProcessGroupID
        )
    }
}

package enum InvestigationMachineGateInvocationValidator {
    package static func validate(
        _ value: InvestigationMachineGateInvocationObservation
    ) throws {
        guard
            value.argumentCount == 1,
            value.environmentCount == 0,
            value.realUserID
                == InvestigationMachineFixedGateContract.requiredUserID,
            value.effectiveUserID
                == InvestigationMachineFixedGateContract.requiredUserID,
            value.realGroupID
                == InvestigationMachineFixedGateContract.requiredGroupID,
            value.effectiveGroupID
                == InvestigationMachineFixedGateContract.requiredGroupID,
            value.inputDescriptorValid,
            value.outputDescriptorWritable,
            value.terminalDescriptorWritableCharacterDevice,
            value.processID > 1,
            value.parentProcessID > 1, value.sessionID > 1,
            value.parentProcessID == value.sessionID,
            value.sessionID == value.foregroundProcessGroupID,
            value.processGroupID == value.processID,
            value.foregroundProcessGroupID > 1,
            value.foregroundProcessGroupID != value.processGroupID
        else {
            throw InvestigationMachineGateError.invalidInvocation
        }
    }
}

package struct InvestigationMachineGateChildIdentity: Equatable, Sendable {
    package let processID: pid_t
    package let parentProcessID: pid_t
    package let processGroupID: pid_t
    package let sessionID: pid_t
    package let startSeconds: UInt64
    package let startMicroseconds: UInt64

    package init(
        processID: pid_t, parentProcessID: pid_t, processGroupID: pid_t,
        sessionID: pid_t,
        startSeconds: UInt64, startMicroseconds: UInt64
    ) {
        self.processID = processID
        self.parentProcessID = parentProcessID
        self.processGroupID = processGroupID
        self.sessionID = sessionID
        self.startSeconds = startSeconds
        self.startMicroseconds = startMicroseconds
    }

    fileprivate var isValid: Bool {
        processID > 1 && parentProcessID > 1 && processGroupID > 1
            && sessionID > 1
            && processID != processGroupID && startSeconds > 0
            && startMicroseconds < 1_000_000
    }
}

package struct InvestigationMachineGatePreparedFrame: Equatable, Sendable {
    package static let domain =
        "stornaut.task39.machine-gate.prepared-frame"
    package static let maximumByteCount = 512
    package static let encodedByteCount =
        InvestigationMachineGateWire.headerByteCount
        + InvestigationMachineGateWire.preparedPayloadByteCount

    package let gateProcessID: pid_t
    package let coordinatorProcessID: pid_t
    package let sessionID: pid_t
    package let childProcessID: pid_t
    package let recoveryProcessGroupID: pid_t
    package let savedForegroundProcessGroupID: pid_t
    package let childIdentity: InvestigationMachineGateChildIdentity
    package let outerAttemptUUID: UUID
    package let wholeInputSHA256: InvestigationHandoffSHA256
    package let capsule: InvestigationMachineGateNodeObservation
    package let terminal: InvestigationMachineGateTerminalObservation
    package let absoluteDeadlineNanoseconds: UInt64
    package let initialStopStatus: Int32

    package init(
        gateProcessID: pid_t,
        coordinatorProcessID: pid_t, sessionID: pid_t,
        childProcessID: pid_t,
        recoveryProcessGroupID: pid_t,
        savedForegroundProcessGroupID: pid_t,
        childParentProcessID: pid_t,
        childSessionID: pid_t,
        childStartSeconds: UInt64, childStartMicroseconds: UInt64,
        initialStopStatus: Int32,
        outerAttemptUUID: UUID,
        wholeInputSHA256: InvestigationHandoffSHA256,
        capsule: InvestigationMachineGateNodeObservation,
        terminal: InvestigationMachineGateTerminalObservation,
        absoluteDeadlineNanoseconds: UInt64
    ) throws {
        guard
            gateProcessID > 1, coordinatorProcessID > 1, sessionID > 1,
            coordinatorProcessID == sessionID,
            sessionID == savedForegroundProcessGroupID,
            childProcessID > 1,
            gateProcessID != childProcessID,
            recoveryProcessGroupID == gateProcessID,
            savedForegroundProcessGroupID > 0,
            recoveryProcessGroupID != savedForegroundProcessGroupID,
            gateUUIDIsNonzero(outerAttemptUUID),
            gateDigestIsNonzero(wholeInputSHA256),
            capsule.isValidCapsuleNode, terminal.isValid,
            terminal.foregroundProcessGroupID
                == savedForegroundProcessGroupID,
            absoluteDeadlineNanoseconds > 0
        else {
            throw InvestigationMachineGateError.invalidFrame
        }
        self.gateProcessID = gateProcessID
        self.coordinatorProcessID = coordinatorProcessID
        self.sessionID = sessionID
        self.childProcessID = childProcessID
        self.recoveryProcessGroupID = recoveryProcessGroupID
        self.savedForegroundProcessGroupID = savedForegroundProcessGroupID
        childIdentity = .init(
            processID: childProcessID, parentProcessID: childParentProcessID,
            processGroupID: recoveryProcessGroupID,
            sessionID: childSessionID,
            startSeconds: childStartSeconds,
            startMicroseconds: childStartMicroseconds
        )
        guard childIdentity.isValid, childIdentity.parentProcessID == gateProcessID,
              childIdentity.sessionID == sessionID, initialStopStatus == 0x7f
        else { throw InvestigationMachineGateError.invalidFrame }
        self.outerAttemptUUID = outerAttemptUUID
        self.wholeInputSHA256 = wholeInputSHA256
        self.capsule = capsule
        self.terminal = terminal
        self.absoluteDeadlineNanoseconds = absoluteDeadlineNanoseconds
        self.initialStopStatus = initialStopStatus
    }

    package func encoded() throws -> Data {
        var payload = Data()
        payload.reserveCapacity(
            InvestigationMachineGateWire.preparedPayloadByteCount
        )
        payload.append(try gateData(gateProcessID))
        payload.append(try gateData(coordinatorProcessID))
        payload.append(try gateData(sessionID))
        payload.append(try gateData(childProcessID))
        payload.append(try gateData(recoveryProcessGroupID))
        payload.append(try gateData(savedForegroundProcessGroupID))
        payload.append(try gateData(childIdentity.parentProcessID))
        payload.append(try gateData(childIdentity.sessionID))
        payload.append(gateData(childIdentity.startSeconds))
        payload.append(gateData(childIdentity.startMicroseconds))
        payload.append(gateData(UInt32(bitPattern: initialStopStatus)))
        payload.append(gateData(outerAttemptUUID))
        payload.append(wholeInputSHA256.rawBytes)
        payload.append(gateData(capsule.device))
        payload.append(gateData(capsule.inode))
        payload.append(gateData(capsule.generation))
        payload.append(gateData(capsule.size))
        payload.append(gateData(terminal.device))
        payload.append(gateData(terminal.inode))
        payload.append(try gateData(terminal.foregroundProcessGroupID))
        payload.append(gateData(absoluteDeadlineNanoseconds))
        guard
            payload.count
                == InvestigationMachineGateWire.preparedPayloadByteCount
        else {
            throw InvestigationMachineGateError.invalidFrame
        }
        let encoded = try InvestigationMachineGateWire.encode(
            kind: .prepared, sequence: 1, payload: payload
        )
        guard
            encoded.count == Self.encodedByteCount,
            encoded.count <= Self.maximumByteCount,
            encoded.count <= Int(PIPE_BUF)
        else {
            throw InvestigationMachineGateError.invalidFrame
        }
        return encoded
    }

    package static func decode(_ data: Data) throws -> Self {
        do {
            let payload = try InvestigationMachineGateWire.decode(
                data, expectedKind: .prepared, expectedSequence: 1,
                expectedPayloadByteCount:
                    InvestigationMachineGateWire.preparedPayloadByteCount
            )
            var cursor = InvestigationMachineGateBinaryCursor(data: payload)
            let value = try Self(
                gateProcessID: cursor.readProcessID(),
                coordinatorProcessID: cursor.readProcessID(),
                sessionID: cursor.readProcessID(),
                childProcessID: cursor.readProcessID(),
                recoveryProcessGroupID: cursor.readProcessID(),
                savedForegroundProcessGroupID:
                    cursor.readProcessID(),
                childParentProcessID: cursor.readProcessID(),
                childSessionID: cursor.readProcessID(),
                childStartSeconds: cursor.readUInt64(),
                childStartMicroseconds: cursor.readUInt64(),
                initialStopStatus: Int32(
                    bitPattern: try cursor.readUInt32()
                ),
                outerAttemptUUID: cursor.readUUID(),
                wholeInputSHA256: InvestigationHandoffSHA256(
                    rawBytes: cursor.read(
                        count: InvestigationHandoffSHA256.byteCount
                    )
                ),
                capsule: .init(
                    device: try cursor.readUInt64(),
                    inode: try cursor.readUInt64(),
                    generation: try cursor.readUInt64(),
                    size: try cursor.readInt64()
                ),
                terminal: .init(
                    device: try cursor.readUInt64(),
                    inode: try cursor.readUInt64(),
                    foregroundProcessGroupID: try cursor.readProcessID()
                ),
                absoluteDeadlineNanoseconds: try cursor.readUInt64()
            )
            guard
                cursor.isAtEnd,
                data.count == Self.encodedByteCount,
                try value.encoded() == data
            else {
                throw InvestigationMachineGateError.invalidFrame
            }
            return value
        } catch {
            throw InvestigationMachineGateError.invalidFrame
        }
    }
}

#if DEBUG
extension InvestigationMachineGatePreparedFrame {
    init(
        gateProcessID: pid_t, childProcessID: pid_t,
        childProcessGroupID: pid_t, savedForegroundProcessGroupID: pid_t,
        outerAttemptUUID: UUID, wholeInputSHA256: InvestigationHandoffSHA256,
        capsule: InvestigationMachineGateNodeObservation,
        terminal: InvestigationMachineGateTerminalObservation,
        absoluteDeadlineNanoseconds: UInt64
    ) throws {
        throw InvestigationMachineGateError.invalidFrame
    }
}
#endif

package struct InvestigationMachineGateTransportReceipt:
    Equatable,
    Sendable
{
    package static let domain =
        "stornaut.task39.machine-gate.transport-receipt"
    package static let maximumByteCount = 512
    package static let encodedByteCount =
        InvestigationMachineGateWire.headerByteCount
        + InvestigationMachineGateWire.terminalPayloadByteCount

    package let launcherExecutableSHA256: InvestigationHandoffSHA256
    package let outerAttemptUUID: UUID
    package let wholeInputSHA256: InvestigationHandoffSHA256
    package let preparedFrameSHA256: InvestigationHandoffSHA256
    package let capsule: InvestigationMachineGateNodeObservation
    package let gateProcessID: pid_t
    package let coordinatorProcessID: pid_t
    package let sessionID: pid_t
    package let recoveryProcessGroupID: pid_t
    package let savedForegroundProcessGroupID: pid_t
    package let childIdentity: InvestigationMachineGateChildIdentity
    package let input: InvestigationMachineGateInputObservation
    package let initialTerminal: InvestigationMachineGateTerminalObservation
    package let childTerminal: InvestigationMachineGateTerminalObservation
    package let finalTerminal: InvestigationMachineGateTerminalObservation
    package let output: InvestigationMachineGateOutputObservation
    package let waitClassification: InvestigationMachineGateWaitClassification
    package let forwardedSignal: Int32?
    package let monotonicStartedNanoseconds: UInt64
    package let monotonicCompletedNanoseconds: UInt64
    package let terminationProgression:
        InvestigationMachineGateTerminationProgression
    package let childProcessGroupEmpty: Bool
    package let exactChildReaped: Bool
    package let savedForegroundProcessGroupRestored: Bool
    package let borrowedDescriptorOutcome:
        InvestigationMachineGateBorrowedDescriptorOutcome

    package init(
        launcherExecutableSHA256: InvestigationHandoffSHA256,
        outerAttemptUUID: UUID,
        wholeInputSHA256: InvestigationHandoffSHA256,
        preparedFrameSHA256: InvestigationHandoffSHA256,
        capsule: InvestigationMachineGateNodeObservation,
        gateProcessID: pid_t, coordinatorProcessID: pid_t, sessionID: pid_t,
        recoveryProcessGroupID: pid_t,
        savedForegroundProcessGroupID: pid_t,
        childIdentity: InvestigationMachineGateChildIdentity,
        input: InvestigationMachineGateInputObservation,
        initialTerminal: InvestigationMachineGateTerminalObservation,
        childTerminal: InvestigationMachineGateTerminalObservation,
        finalTerminal: InvestigationMachineGateTerminalObservation,
        output: InvestigationMachineGateOutputObservation,
        waitClassification: InvestigationMachineGateWaitClassification,
        forwardedSignal: Int32?,
        monotonicStartedNanoseconds: UInt64,
        monotonicCompletedNanoseconds: UInt64,
        terminationProgression:
            InvestigationMachineGateTerminationProgression,
        childProcessGroupEmpty: Bool,
        exactChildReaped: Bool,
        savedForegroundProcessGroupRestored: Bool,
        borrowedDescriptorOutcome:
            InvestigationMachineGateBorrowedDescriptorOutcome
    ) throws {
        guard
            gateDigestIsNonzero(launcherExecutableSHA256),
            gateUUIDIsNonzero(outerAttemptUUID),
            gateDigestIsNonzero(wholeInputSHA256),
            gateDigestIsNonzero(preparedFrameSHA256),
            capsule.isValidCapsuleNode,
            gateProcessID > 1, coordinatorProcessID > 1, sessionID > 1,
            coordinatorProcessID == sessionID,
            sessionID == savedForegroundProcessGroupID,
            recoveryProcessGroupID == gateProcessID,
            savedForegroundProcessGroupID > 1,
            savedForegroundProcessGroupID != recoveryProcessGroupID,
            childIdentity.isValid,
            childIdentity.parentProcessID == gateProcessID,
            childIdentity.processGroupID == recoveryProcessGroupID,
            childIdentity.sessionID == sessionID,
            gateInputIsConsistent(
                input, capsule: capsule,
                wholeInputSHA256: wholeInputSHA256
            ),
            initialTerminal.isValid, childTerminal.isValid,
            finalTerminal.isValid,
            initialTerminal.foregroundProcessGroupID
                == savedForegroundProcessGroupID,
            childTerminal.foregroundProcessGroupID == recoveryProcessGroupID,
            initialTerminal.hasSameNode(as: childTerminal),
            initialTerminal.hasSameNode(as: finalTerminal),
            savedForegroundProcessGroupRestored,
            finalTerminal.foregroundProcessGroupID
                == savedForegroundProcessGroupID,
            gateOutputIsValid(output),
            waitClassification.isValid,
            gateForwardedSignalIsValid(forwardedSignal),
            monotonicStartedNanoseconds > 0,
            monotonicCompletedNanoseconds >= monotonicStartedNanoseconds,
            monotonicCompletedNanoseconds - monotonicStartedNanoseconds
                <= InvestigationMachineFixedGateContract.deadlineNanoseconds,
            childProcessGroupEmpty,
            exactChildReaped,
            borrowedDescriptorOutcome.isValid
        else {
            throw InvestigationMachineGateError.invalidReceipt
        }
        self.launcherExecutableSHA256 = launcherExecutableSHA256
        self.outerAttemptUUID = outerAttemptUUID
        self.wholeInputSHA256 = wholeInputSHA256
        self.preparedFrameSHA256 = preparedFrameSHA256
        self.capsule = capsule
        self.gateProcessID = gateProcessID
        self.coordinatorProcessID = coordinatorProcessID
        self.sessionID = sessionID
        self.recoveryProcessGroupID = recoveryProcessGroupID
        self.savedForegroundProcessGroupID = savedForegroundProcessGroupID
        self.childIdentity = childIdentity
        self.input = input
        self.initialTerminal = initialTerminal
        self.childTerminal = childTerminal
        self.finalTerminal = finalTerminal
        self.output = output
        self.waitClassification = waitClassification
        self.forwardedSignal = forwardedSignal
        self.monotonicStartedNanoseconds = monotonicStartedNanoseconds
        self.monotonicCompletedNanoseconds = monotonicCompletedNanoseconds
        self.terminationProgression = terminationProgression
        self.childProcessGroupEmpty = childProcessGroupEmpty
        self.exactChildReaped = exactChildReaped
        self.savedForegroundProcessGroupRestored =
            savedForegroundProcessGroupRestored
        self.borrowedDescriptorOutcome = borrowedDescriptorOutcome
    }

    package func encoded() throws -> Data {
        var payload = Data()
        payload.reserveCapacity(
            InvestigationMachineGateWire.terminalPayloadByteCount
        )
        payload.append(launcherExecutableSHA256.rawBytes)
        payload.append(gateData(outerAttemptUUID))
        payload.append(wholeInputSHA256.rawBytes)
        payload.append(preparedFrameSHA256.rawBytes)
        payload.append(gateData(capsule.device))
        payload.append(gateData(capsule.inode))
        payload.append(gateData(capsule.generation))
        payload.append(gateData(capsule.size))
        payload.append(try gateData(gateProcessID))
        payload.append(try gateData(coordinatorProcessID))
        payload.append(try gateData(sessionID))
        payload.append(try gateData(recoveryProcessGroupID))
        payload.append(try gateData(savedForegroundProcessGroupID))
        payload.append(try gateData(childIdentity.processID))
        payload.append(try gateData(childIdentity.parentProcessID))
        payload.append(try gateData(childIdentity.processGroupID))
        payload.append(try gateData(childIdentity.sessionID))
        payload.append(gateData(childIdentity.startSeconds))
        payload.append(gateData(childIdentity.startMicroseconds))
        payload.append(gateData(input.node.device))
        payload.append(gateData(input.node.inode))
        payload.append(gateData(input.node.generation))
        payload.append(gateData(input.node.size))
        payload.append(gateData(input.initialOffset))
        payload.append(gateData(input.finalOffset))
        payload.append(gateData(input.reachedEOF))
        payload.append(input.sha256.rawBytes)
        payload.append(gateData(initialTerminal.device))
        payload.append(gateData(initialTerminal.inode))
        payload.append(try gateData(
            initialTerminal.foregroundProcessGroupID
        ))
        payload.append(gateData(childTerminal.device))
        payload.append(gateData(childTerminal.inode))
        payload.append(try gateData(
            childTerminal.foregroundProcessGroupID
        ))
        payload.append(gateData(finalTerminal.device))
        payload.append(gateData(finalTerminal.inode))
        payload.append(try gateData(
            finalTerminal.foregroundProcessGroupID
        ))
        payload.append(try gateDataUInt32(output.byteCount))
        payload.append(output.sha256.rawBytes)
        payload.append(gateData(output.overflowObserved))
        payload.append(gateData(output.reachedEOF))
        payload.append(gateData(output.deadlineExpired))
        payload.append(waitClassification.encodedBytes)
        payload.append(gateData(forwardedSignal))
        payload.append(gateData(monotonicStartedNanoseconds))
        payload.append(gateData(monotonicCompletedNanoseconds))
        payload.append(gateData(terminationProgression.rawValue))
        payload.append(gateData(childProcessGroupEmpty))
        payload.append(gateData(exactChildReaped))
        payload.append(gateData(savedForegroundProcessGroupRestored))
        payload.append(borrowedDescriptorOutcome.encodedBytes)
        guard
            payload.count
                == InvestigationMachineGateWire.terminalPayloadByteCount
        else {
            throw InvestigationMachineGateError.invalidReceipt
        }
        let encoded = try InvestigationMachineGateWire.encode(
            kind: .terminal, sequence: 2, payload: payload
        )
        guard
            encoded.count == Self.encodedByteCount,
            encoded.count <= Self.maximumByteCount,
            encoded.count <= Int(PIPE_BUF)
        else {
            throw InvestigationMachineGateError.invalidReceipt
        }
        return encoded
    }

    package static func decode(_ data: Data) throws -> Self {
        do {
            let payload = try InvestigationMachineGateWire.decode(
                data, expectedKind: .terminal, expectedSequence: 2,
                expectedPayloadByteCount:
                    InvestigationMachineGateWire.terminalPayloadByteCount
            )
            var cursor = InvestigationMachineGateBinaryCursor(data: payload)
            let launcherExecutableSHA256 = try InvestigationHandoffSHA256(
                rawBytes: cursor.read(
                    count: InvestigationHandoffSHA256.byteCount
                )
            )
            let outerAttemptUUID = try cursor.readUUID()
            let wholeInputSHA256 = try InvestigationHandoffSHA256(
                rawBytes: cursor.read(
                    count: InvestigationHandoffSHA256.byteCount
                )
            )
            let preparedFrameSHA256 = try InvestigationHandoffSHA256(
                rawBytes: cursor.read(
                    count: InvestigationHandoffSHA256.byteCount
                )
            )
            let capsule = InvestigationMachineGateNodeObservation(
                device: try cursor.readUInt64(),
                inode: try cursor.readUInt64(),
                generation: try cursor.readUInt64(),
                size: try cursor.readInt64()
            )
            let gateProcessID = try cursor.readProcessID()
            let coordinatorProcessID = try cursor.readProcessID()
            let sessionID = try cursor.readProcessID()
            let recoveryProcessGroupID = try cursor.readProcessID()
            let savedForegroundProcessGroupID = try cursor.readProcessID()
            let childIdentity = InvestigationMachineGateChildIdentity(
                processID: try cursor.readProcessID(),
                parentProcessID: try cursor.readProcessID(),
                processGroupID: try cursor.readProcessID(),
                sessionID: try cursor.readProcessID(),
                startSeconds: try cursor.readUInt64(),
                startMicroseconds: try cursor.readUInt64()
            )
            let input = InvestigationMachineGateInputObservation(
                node: .init(
                    device: try cursor.readUInt64(),
                    inode: try cursor.readUInt64(),
                        generation: try cursor.readUInt64(),
                    size: try cursor.readInt64()
                ),
                initialOffset: try cursor.readInt64(),
                finalOffset: try cursor.readInt64(),
                reachedEOF: try cursor.readBoolean(),
                sha256: try InvestigationHandoffSHA256(
                    rawBytes: cursor.read(
                        count: InvestigationHandoffSHA256.byteCount
                    )
                )
            )
            let initialTerminal = InvestigationMachineGateTerminalObservation(
                device: try cursor.readUInt64(),
                inode: try cursor.readUInt64(),
                foregroundProcessGroupID: try cursor.readProcessID()
            )
            let childTerminal = InvestigationMachineGateTerminalObservation(
                device: try cursor.readUInt64(),
                inode: try cursor.readUInt64(),
                foregroundProcessGroupID: try cursor.readProcessID()
            )
            let finalTerminal = InvestigationMachineGateTerminalObservation(
                device: try cursor.readUInt64(),
                inode: try cursor.readUInt64(),
                foregroundProcessGroupID: try cursor.readProcessID()
            )
            let output = InvestigationMachineGateOutputObservation(
                byteCount: try cursor.readIntFromUInt32(),
                sha256: try InvestigationHandoffSHA256(
                    rawBytes: cursor.read(
                        count: InvestigationHandoffSHA256.byteCount
                    )
                ),
                overflowObserved: try cursor.readBoolean(),
                reachedEOF: try cursor.readBoolean(),
                deadlineExpired: try cursor.readBoolean()
            )
            let waitClassification =
                try InvestigationMachineGateWaitClassification.decode(
                    cursor.read(count: 5)
                )
            let forwardedSignal = try cursor.readOptionalSignal()
            let monotonicStartedNanoseconds = try cursor.readUInt64()
            let monotonicCompletedNanoseconds = try cursor.readUInt64()
            let progressionRaw = try cursor.readUInt8()
            guard let progression =
                InvestigationMachineGateTerminationProgression(
                    rawValue: progressionRaw
                )
            else {
                throw InvestigationMachineGateError.invalidReceipt
            }
            let childProcessGroupEmpty = try cursor.readBoolean()
            let exactChildReaped = try cursor.readBoolean()
            let savedForegroundProcessGroupRestored =
                try cursor.readBoolean()
            let borrowedDescriptorOutcome =
                try InvestigationMachineGateBorrowedDescriptorOutcome.decode(
                    cursor.read(count: 5)
                )
            let value = try Self(
                launcherExecutableSHA256: launcherExecutableSHA256,
                outerAttemptUUID: outerAttemptUUID,
                wholeInputSHA256: wholeInputSHA256,
                preparedFrameSHA256: preparedFrameSHA256,
                capsule: capsule,
                gateProcessID: gateProcessID,
                coordinatorProcessID: coordinatorProcessID,
                sessionID: sessionID,
                recoveryProcessGroupID: recoveryProcessGroupID,
                savedForegroundProcessGroupID: savedForegroundProcessGroupID,
                childIdentity: childIdentity,
                input: input,
                initialTerminal: initialTerminal,
                childTerminal: childTerminal,
                finalTerminal: finalTerminal,
                output: output,
                waitClassification: waitClassification,
                forwardedSignal: forwardedSignal,
                monotonicStartedNanoseconds: monotonicStartedNanoseconds,
                monotonicCompletedNanoseconds: monotonicCompletedNanoseconds,
                terminationProgression: progression,
                childProcessGroupEmpty: childProcessGroupEmpty,
                exactChildReaped: exactChildReaped,
                savedForegroundProcessGroupRestored:
                    savedForegroundProcessGroupRestored,
                borrowedDescriptorOutcome: borrowedDescriptorOutcome
            )
            guard
                cursor.isAtEnd,
                data.count == Self.encodedByteCount,
                try value.encoded() == data
            else {
                throw InvestigationMachineGateError.invalidReceipt
            }
            return value
        } catch {
            throw InvestigationMachineGateError.invalidReceipt
        }
    }
}

#if DEBUG
extension InvestigationMachineGateTransportReceipt {
    init(
        launcherExecutableSHA256: InvestigationHandoffSHA256,
        outerAttemptUUID: UUID, wholeInputSHA256: InvestigationHandoffSHA256,
        preparedFrameSHA256: InvestigationHandoffSHA256,
        capsule: InvestigationMachineGateNodeObservation,
        gateProcessID: pid_t, inheritedProcessGroupID: pid_t,
        childProcessID: pid_t, childProcessGroupID: pid_t,
        input: InvestigationMachineGateInputObservation,
        initialTerminal: InvestigationMachineGateTerminalObservation,
        childTerminal: InvestigationMachineGateTerminalObservation,
        finalTerminal: InvestigationMachineGateTerminalObservation,
        output: InvestigationMachineGateOutputObservation,
        waitClassification: InvestigationMachineGateWaitClassification,
        forwardedSignal: Int32?, monotonicStartedNanoseconds: UInt64,
        monotonicCompletedNanoseconds: UInt64,
        terminationProgression: InvestigationMachineGateTerminationProgression,
        childProcessGroupEmpty: Bool, exactChildReaped: Bool,
        savedForegroundProcessGroupRestored: Bool,
        borrowedDescriptorOutcome: InvestigationMachineGateBorrowedDescriptorOutcome
    ) throws {
        throw InvestigationMachineGateError.invalidReceipt
    }
}
#endif

package enum InvestigationMachineGateLauncherEvent: Equatable, Sendable {
    case validateInvocation
    case observeLauncherExecutable
    case observeStart
    case observeInitialInput
    case observeInitialTTY
    case makeOutputPipe
    case spawnSuspendedChild
    case verifyChildProcessGroup
    case observeChildIdentity
    case joinCoordinatorProcessGroup(pid_t)
    case verifyGateAndChildTopology
    case settleChildBeforeCoordinatorJoin
    case writePreparedFrame(Data)
    case stopGateForCoordinator
    case revalidateTransitionTTY
    case setForegroundProcessGroup(pid_t)
    case observeChildTTY
    case continueChildGroup(pid_t)
    case drainOutput
    case observeFinalInput
    case observeWaitableChild
    case observeLeaderOnlyChildGroup
    case waitForTerminationGrace
    case sendTermToChildGroup(pid_t)
    case sendKillToChildGroup(pid_t)
    case reapExactChild
    case observeEmptyChildGroup
    case verifyForegroundProcessGroup(pid_t)
    case revalidateFinalTTY
    case closeOutputDescriptor(Int32)
    case closeBorrowedDescriptor(Int32)
    case observeCompletion
    case writeTerminalReceipt(Data)
}

package enum InvestigationMachineGateLauncherResponse: Equatable, Sendable {
    case invocation(InvestigationMachineGateInvocationObservation)
    case sha256(InvestigationHandoffSHA256)
    case nanoseconds(UInt64)
    case inputContext(InvestigationMachineGateInputContext)
    case input(InvestigationMachineGateInputObservation)
    case terminal(InvestigationMachineGateTerminalObservation)
    case descriptorPair(read: Int32, write: Int32)
    case processID(pid_t)
    case processGroupID(pid_t)
    case childIdentity(InvestigationMachineGateChildIdentity)
    case output(InvestigationMachineGateOutputObservation)
    case outputFailure
    case childRunning
    case childGroupActive
    case waitClassification(InvestigationMachineGateWaitClassification)
    case completed
}

package struct InvestigationMachineFixedGateLauncherResult:
    Equatable,
    Sendable
{
    package let receipt: InvestigationMachineGateTransportReceipt

    package init(receipt: InvestigationMachineGateTransportReceipt) {
        self.receipt = receipt
    }
}

package typealias InvestigationMachineGateLauncherRunResult =
    InvestigationMachineFixedGateLauncherResult

private enum InvestigationMachineGateWireKind: UInt8 {
    case prepared = 1
    case terminal = 2
}

private enum InvestigationMachineGateWire {
    static let magic: UInt32 = 0x5354_4e47
    static let version: UInt16 = 1
    static let headerByteCount = 12
    static let preparedPayloadByteCount = 160
    static let terminalPayloadByteCount = 410

    static func encode(
        kind: InvestigationMachineGateWireKind,
        sequence: UInt8,
        payload: Data
    ) throws -> Data {
        guard
            !payload.isEmpty,
            let payloadByteCount = UInt32(exactly: payload.count),
            headerByteCount + payload.count <= Int(PIPE_BUF)
        else {
            throw InvestigationMachineGateError.invalidFrame
        }
        var encoded = Data()
        encoded.reserveCapacity(headerByteCount + payload.count)
        encoded.append(gateData(magic))
        encoded.append(gateData(version))
        encoded.append(gateData(kind.rawValue))
        encoded.append(gateData(sequence))
        encoded.append(gateData(payloadByteCount))
        encoded.append(payload)
        guard encoded.count == headerByteCount + payload.count else {
            throw InvestigationMachineGateError.invalidFrame
        }
        return encoded
    }

    static func decode(
        _ data: Data,
        expectedKind: InvestigationMachineGateWireKind,
        expectedSequence: UInt8,
        expectedPayloadByteCount: Int
    ) throws -> Data {
        guard
            expectedSequence > 0,
            expectedPayloadByteCount > 0,
            data.count == headerByteCount + expectedPayloadByteCount,
            data.count <= Int(PIPE_BUF)
        else {
            throw InvestigationMachineGateError.invalidFrame
        }
        var cursor = InvestigationMachineGateBinaryCursor(data: data)
        guard
            try cursor.readUInt32() == magic,
            try cursor.readUInt16() == version,
            try cursor.readUInt8() == expectedKind.rawValue,
            try cursor.readUInt8() == expectedSequence,
            let declaredPayloadByteCount = Int(
                exactly: try cursor.readUInt32()
            ),
            declaredPayloadByteCount == expectedPayloadByteCount,
            declaredPayloadByteCount == cursor.remainingByteCount
        else {
            throw InvestigationMachineGateError.invalidFrame
        }
        let payload = try cursor.read(count: declaredPayloadByteCount)
        guard cursor.isAtEnd else {
            throw InvestigationMachineGateError.invalidFrame
        }
        return payload
    }
}

private struct InvestigationMachineGateBinaryCursor {
    private let data: Data
    private var offset = 0

    init(data: Data) {
        self.data = data
    }

    var remainingByteCount: Int {
        data.count - offset
    }

    var isAtEnd: Bool {
        offset == data.count
    }

    mutating func read(count: Int) throws -> Data {
        guard
            count >= 0,
            offset >= 0,
            offset <= data.count,
            count <= data.count - offset
        else {
            throw InvestigationMachineGateError.invalidFrame
        }
        let range = offset..<(offset + count)
        offset += count
        return data.subdata(in: range)
    }

    mutating func readUInt8() throws -> UInt8 {
        let bytes = try read(count: 1)
        guard let value = bytes.first else {
            throw InvestigationMachineGateError.invalidFrame
        }
        return value
    }

    mutating func readUInt16() throws -> UInt16 {
        let bytes = try read(count: 2)
        return bytes.reduce(UInt16(0)) { ($0 << 8) | UInt16($1) }
    }

    mutating func readUInt32() throws -> UInt32 {
        let bytes = try read(count: 4)
        return bytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }

    mutating func readUInt64() throws -> UInt64 {
        let bytes = try read(count: 8)
        return bytes.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
    }

    mutating func readInt64() throws -> Int64 {
        Int64(bitPattern: try readUInt64())
    }

    mutating func readProcessID() throws -> pid_t {
        guard let value = pid_t(exactly: try readUInt32()) else {
            throw InvestigationMachineGateError.invalidFrame
        }
        return value
    }

    mutating func readIntFromUInt32() throws -> Int {
        guard let value = Int(exactly: try readUInt32()) else {
            throw InvestigationMachineGateError.invalidFrame
        }
        return value
    }

    mutating func readBoolean() throws -> Bool {
        switch try readUInt8() {
        case 0: false
        case 1: true
        default: throw InvestigationMachineGateError.invalidFrame
        }
    }

    mutating func readOptionalSignal() throws -> Int32? {
        let rawValue = try readUInt32()
        guard rawValue != 0 else { return nil }
        guard
            let value = Int32(exactly: rawValue),
            gateValidSignal(value)
        else {
            throw InvestigationMachineGateError.invalidFrame
        }
        return value
    }

    mutating func readUUID() throws -> UUID {
        try gateDecodeUUID(read(count: 16))
    }
}

private func gateInputIsConsistent(
    _ input: InvestigationMachineGateInputObservation,
    capsule: InvestigationMachineGateNodeObservation,
    wholeInputSHA256: InvestigationHandoffSHA256
) -> Bool {
    input.node == capsule
        && input.initialOffset == 0
        && input.finalOffset == capsule.size
        && input.finalOffset >= input.initialOffset
        && input.reachedEOF
        && input.sha256 == wholeInputSHA256
        && gateDigestIsNonzero(input.sha256)
}

private func gateOutputIsValid(
    _ output: InvestigationMachineGateOutputObservation
) -> Bool {
    (0...InvestigationMachineFixedGateContract.maximumCapturedOutputByteCount)
        .contains(output.byteCount)
        && (!output.overflowObserved
            || output.byteCount
                == InvestigationMachineFixedGateContract
                    .maximumCapturedOutputByteCount)
        && (output.reachedEOF || output.overflowObserved)
        && gateDigestIsNonzero(output.sha256)
}

private func gateValidSignal(_ value: Int32) -> Bool {
    value > 0 && value < 128
}

private func gateForwardedSignalIsValid(_ value: Int32?) -> Bool {
    guard let value else { return true }
    return InvestigationMachineFixedGateContract.forwardedSignals
        .contains(value)
}

private func gateDigestIsNonzero(
    _ value: InvestigationHandoffSHA256
) -> Bool {
    value.rawBytes.contains { $0 != 0 }
}

private func gateUUIDIsNonzero(_ value: UUID) -> Bool {
    gateData(value).contains { $0 != 0 }
}

private func gateData(_ value: UInt8) -> Data {
    Data([value])
}

private func gateData(_ value: Bool) -> Data {
    gateData(value ? UInt8(1) : UInt8(0))
}

private func gateData(_ value: UInt16) -> Data {
    Data([
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value),
    ])
}

private func gateData(_ value: UInt32) -> Data {
    Data([
        UInt8(truncatingIfNeeded: value >> 24),
        UInt8(truncatingIfNeeded: value >> 16),
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value),
    ])
}

private func gateData(_ value: UInt64) -> Data {
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

private func gateData(_ value: Int64) -> Data {
    gateData(UInt64(bitPattern: value))
}

private func gateData(_ value: pid_t) throws -> Data {
    guard let encoded = UInt32(exactly: value) else {
        throw InvestigationMachineGateError.invalidObservation
    }
    return gateData(encoded)
}

private func gateData(_ value: Int) throws -> Data {
    guard let encoded = UInt64(exactly: value) else {
        throw InvestigationMachineGateError.invalidObservation
    }
    return gateData(encoded)
}

private func gateDataUInt32(_ value: Int) throws -> Data {
    guard let encoded = UInt32(exactly: value) else {
        throw InvestigationMachineGateError.invalidObservation
    }
    return gateData(encoded)
}

private func gateData(_ value: Int32?) -> Data {
    gateData(UInt32(value ?? 0))
}

private func gateData(_ value: UUID) -> Data {
    var bytes = value.uuid
    return withUnsafeBytes(of: &bytes) { Data($0) }
}

private func gateDecodeUInt8(_ data: Data) throws -> UInt8 {
    guard data.count == 1, let value = data.first else {
        throw InvestigationMachineGateError.invalidObservation
    }
    return value
}

private func gateDecodeUInt32(_ data: Data) throws -> UInt32 {
    guard data.count == 4 else {
        throw InvestigationMachineGateError.invalidObservation
    }
    return data.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
}

private func gateDecodeUInt64(_ data: Data) throws -> UInt64 {
    guard data.count == 8 else {
        throw InvestigationMachineGateError.invalidObservation
    }
    return data.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
}

private func gateDecodeInt64(_ data: Data) throws -> Int64 {
    Int64(bitPattern: try gateDecodeUInt64(data))
}

private func gateDecodeInt(_ data: Data) throws -> Int {
    guard let value = Int(exactly: try gateDecodeUInt64(data)) else {
        throw InvestigationMachineGateError.invalidObservation
    }
    return value
}

private func gateDecodeProcessID(_ data: Data) throws -> pid_t {
    guard let value = pid_t(exactly: try gateDecodeUInt32(data)) else {
        throw InvestigationMachineGateError.invalidObservation
    }
    return value
}

private func gateDecodeBoolean(_ data: Data) throws -> Bool {
    switch try gateDecodeUInt8(data) {
    case 0: false
    case 1: true
    default: throw InvestigationMachineGateError.invalidObservation
    }
}

private func gateDecodeOptionalSignal(_ data: Data) throws -> Int32? {
    let value = try gateDecodeUInt32(data)
    guard value != 0 else { return nil }
    guard let signal = Int32(exactly: value), gateValidSignal(signal) else {
        throw InvestigationMachineGateError.invalidObservation
    }
    return signal
}

private func gateDecodeUUID(_ data: Data) throws -> UUID {
    guard data.count == 16 else {
        throw InvestigationMachineGateError.invalidObservation
    }
    var bytes: uuid_t = (
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    )
    let copied = withUnsafeMutableBytes(of: &bytes) { destination in
        data.copyBytes(to: destination)
    }
    guard copied == 16 else {
        throw InvestigationMachineGateError.invalidObservation
    }
    return UUID(uuid: bytes)
}
