// Darwin implementation for the authority-free machine gate.
import Darwin
import Foundation
import Security
import StornautInvestigationHandoffContract

@_silgen_name("_NSGetEnviron")
private func investigationMachineGateEnvironmentPointer()
    -> UnsafeMutablePointer<UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?>

enum InvestigationMachineGateDeadlinePolicy {
    static let cleanupReserveNanoseconds: UInt64 = 5_000_000_000

    static func operationDeadline(
        absoluteDeadlineNanoseconds: UInt64
    ) throws -> UInt64 {
        guard absoluteDeadlineNanoseconds > cleanupReserveNanoseconds else {
            throw InvestigationMachineGateError.containmentUncertain
        }
        return absoluteDeadlineNanoseconds - cleanupReserveNanoseconds
    }
}

enum InvestigationMachineGateEnvironmentValidator {
    private static let injectedKey = "__CF_USER_TEXT_ENCODING"

    static func normalizedSourceEnvironmentCount(
        _ entries: [String]
    ) throws -> Int {
        guard entries.count <= 1 else {
            throw InvestigationMachineGateError.invalidInvocation
        }
        guard let entry = entries.first else { return 0 }
        let components = entry.split(
            separator: "=", maxSplits: 1, omittingEmptySubsequences: false
        )
        guard
            components.count == 2, components[0] == injectedKey,
            validInjectedValue(String(components[1]))
        else {
            throw InvestigationMachineGateError.invalidInvocation
        }
        return 0
    }

    private static func validInjectedValue(_ value: String) -> Bool {
        let fields = value.split(
            separator: ":", omittingEmptySubsequences: false
        )
        guard fields.count == 3 else { return false }
        return fields.allSatisfy { field in
            guard field.count >= 3, field.hasPrefix("0x") else { return false }
            return field.dropFirst(2).allSatisfy(\.isHexDigit)
        }
    }
}

enum InvestigationMachineGatePreJoinAction: Equatable {
    case reapExactChild
    case joinCoordinator
    case proveRecoveryGroupEmpty
    case complete
    case reject
}

enum InvestigationMachineGateRuntimePolicy {
    static func initialStopObservationWasReaped(
        _ classification: InvestigationMachineGateWaitClassification
    ) -> Bool {
        switch classification {
        case .stopped:
            false
        case .exited, .signaled:
            true
        }
    }

    static func missingGroupSignalIsSettled(
        directChildWaitable: Bool, recoveryGroupMembers: [pid_t]
    ) -> Bool {
        directChildWaitable && recoveryGroupMembers.isEmpty
    }

    static func shouldForwardPendingSignal(
        directChildTerminal: Bool, recoveryGroupMembers: [pid_t]
    ) -> Bool {
        !directChildTerminal || !recoveryGroupMembers.isEmpty
    }

    static func preJoinAction(
        childReaped: Bool, gateJoinedCoordinator: Bool,
        recoveryGroupMembers: [pid_t], gateProcessID: pid_t
    ) -> InvestigationMachineGatePreJoinAction {
        if !childReaped { return .reapExactChild }
        if !gateJoinedCoordinator {
            return recoveryGroupMembers == [gateProcessID]
                ? .joinCoordinator : .reject
        }
        return recoveryGroupMembers.isEmpty
            ? .complete : .proveRecoveryGroupEmpty
    }
}

private let investigationMachineGateAdHocFlag: UInt32 = 0x0002

final class DarwinInvestigationMachineFixedGateSystem:
    @unchecked Sendable, InvestigationMachineFixedGateLauncherSystem
{
    private static let maximumProcessGroupMembers = 4_096
    private static let terminationGraceNanoseconds: UInt64 = 1_000_000_000
    private static let cleanupDeadlineNanoseconds =
        InvestigationMachineGateDeadlinePolicy.cleanupReserveNanoseconds
    private static let pollSliceNanoseconds: UInt64 = 10_000_000

    private let lock = NSLock()
    private var state = State()

    func perform(
        _ event: InvestigationMachineGateLauncherEvent
    ) throws -> InvestigationMachineGateLauncherResponse {
        try lock.withLock { try performLocked(event) }
    }

    func forwardedSignal() -> Int32? {
        lock.withLock { state.forwardedSignal }
    }

    func consumePendingForwardedSignal() throws -> Int32? {
        try lock.withLock {
            try consumeAndForwardPendingSignal()
            return state.forwardedSignal
        }
    }

    private func performLocked(
        _ event: InvestigationMachineGateLauncherEvent
    ) throws -> InvestigationMachineGateLauncherResponse {
        switch event {
        case .validateInvocation:
            guard !state.invocationValidated else { throw unexpected() }
            let value = try validateInvocation()
            state.invocationValidated = true
            state.recoveryProcessGroupID = value.processGroupID
            state.savedForegroundProcessGroupID =
                value.foregroundProcessGroupID
            return .invocation(value)

        case .observeStart:
            guard state.invocationValidated, state.startedNanoseconds == nil
            else { throw unexpected() }
            let value = try continuousNanoseconds()
            state.startedNanoseconds = value
            state.deadlineNanoseconds = try adding(
                InvestigationMachineFixedGateContract.deadlineNanoseconds,
                to: value
            )
            return .nanoseconds(value)

        case .observeLauncherExecutable:
            guard state.startedNanoseconds != nil, state.launcherSHA256 == nil
            else { throw unexpected() }
            let value = try executableSHA256()
            state.launcherSHA256 = value
            return .sha256(value)

        case .observeInitialInput:
            guard state.launcherSHA256 != nil, state.initialInput == nil
            else { throw unexpected() }
            let value = try observeInitialInput()
            state.initialInput = value
            return .inputContext(value)

        case .observeInitialTTY:
            guard state.initialInput != nil, state.initialTerminal == nil
            else { throw unexpected() }
            let value = try terminalObservation()
            state.initialTerminal = value
            return .terminal(value)

        case .makeOutputPipe:
            guard state.initialTerminal != nil, state.outputRead == nil,
                  state.outputWrite == nil
            else { throw unexpected() }
            let pair = try makeOutputPipe()
            state.outputRead = pair.read
            state.outputWrite = pair.write
            return .descriptorPair(read: pair.read, write: pair.write)

        case .spawnSuspendedChild:
            guard
                state.childProcessID == nil, let read = state.outputRead,
                let write = state.outputWrite, read > STDERR_FILENO,
                write > STDERR_FILENO
            else { throw unexpected() }
            let processID = try spawnSuspendedChild(
                outputRead: read, outputWrite: write
            )
            return .processID(processID)

        case .closeOutputDescriptor(let descriptor):
            guard
                descriptor == state.outputRead
                    || descriptor == state.outputWrite
                    || (descriptor == STDOUT_FILENO
                        && !state.coordinatorStreamCloseAttempted)
            else { throw unexpected() }
            if descriptor == state.outputRead { state.outputRead = nil }
            if descriptor == state.outputWrite { state.outputWrite = nil }
            if descriptor == STDOUT_FILENO {
                state.coordinatorStreamCloseAttempted = true
            }
            try closeDescriptor(descriptor)
            if descriptor == STDOUT_FILENO {
                state.coordinatorStreamClosed = true
            }
            return .completed

        case .verifyChildProcessGroup:
            guard let child = state.childProcessID else { throw unexpected() }
            let group = getpgid(child)
            guard
                group == state.recoveryProcessGroupID,
                try stableChildIdentity(processID: child)
            else {
                throw InvestigationMachineGateError.invalidChildProcessGroup
            }
            state.childProcessGroupID = group
            state.childGroupVerified = true
            return .processGroupID(group)

        case .observeChildIdentity:
            guard let value = state.childIdentity else { throw containment() }
            return .childIdentity(value.transportIdentity)

        case .joinCoordinatorProcessGroup(let group):
            guard
                group == state.savedForegroundProcessGroupID,
                getpgrp() == state.recoveryProcessGroupID,
                setpgid(0, group) == 0, getpgrp() == group
            else { throw containment() }
            state.gateJoinedCoordinatorGroup = true
            return .completed

        case .verifyGateAndChildTopology:
            guard
                state.gateJoinedCoordinatorGroup,
                getpgrp() == state.savedForegroundProcessGroupID,
                let child = state.childProcessID,
                getpgid(child) == state.recoveryProcessGroupID,
                try stableChildIdentity(processID: child),
                try childIsStopped(processID: child)
            else { throw containment() }
            return .completed

        case .settleChildBeforeCoordinatorJoin:
            guard
                let child = state.childProcessID,
                let recoveryGroup = state.recoveryProcessGroupID,
                let coordinatorGroup = state.savedForegroundProcessGroupID,
                getpgrp() == recoveryGroup || getpgrp() == coordinatorGroup
            else { throw containment() }
            if getpgrp() == coordinatorGroup {
                state.gateJoinedCoordinatorGroup = true
            }
            let settled = cleanupFailedInitialStop(processID: child)
            guard settled.reaped, settled.groupEmpty else {
                throw containment()
            }
            return .completed

        case .writePreparedFrame(let data):
            guard !state.preparedFrameWritten,
                  data.count <= InvestigationMachineGatePreparedFrame.maximumByteCount,
                  data.count <= Int(PIPE_BUF)
            else { throw unexpected() }
            _ = try InvestigationMachineGatePreparedFrame.decode(data)
            try writeOneRecord(descriptor: STDOUT_FILENO, data: data)
            state.preparedFrameWritten = true
            return .completed

        case .stopGateForCoordinator:
            guard state.preparedFrameWritten, !state.stoppedForCoordinator
            else { throw unexpected() }
            state.stoppedForCoordinator = true
            guard raise(SIGSTOP) == 0 else { throw containment() }
            return .completed

        case .revalidateTransitionTTY:
            let value = try terminalObservation()
            guard value == state.initialTerminal else { throw restoration() }
            return .terminal(value)

        case .setForegroundProcessGroup(let group):
            guard
                group > 1,
                group == state.childProcessGroupID
                    || group == state.savedForegroundProcessGroupID
            else { throw restoration() }
            let current = tcgetpgrp(STDERR_FILENO)
            guard current > 1 else { throw restoration() }
            if group == state.savedForegroundProcessGroupID {
                guard
                    current == group || current == state.childProcessGroupID
                else { throw restoration() }
            } else {
                guard current == state.savedForegroundProcessGroupID else {
                    throw restoration()
                }
            }
            if current != group { try setForeground(group) }
            state.foregroundProcessGroupID = group
            return .completed

        case .verifyForegroundProcessGroup(let group):
            guard tcgetpgrp(STDERR_FILENO) == group else { throw restoration() }
            return .completed

        case .continueChildGroup(let group):
            try sendSignal(toGroup: group, signal: SIGCONT)
            return .completed

        case .observeChildTTY:
            return .terminal(try terminalObservation())

        case .collectResolvedRootDriverValidation(
            let initialLaunch,
            let expectedOuterAttemptUUID,
            let expectedWholeInputSHA256,
            let recoveryProcessGroupID,
            let coordinatorSessionID
        ):
            guard !state.resolvedRootValidationCollected else {
                throw unexpected()
            }
            let value = try collectResolvedRootDriverValidation(
                initialLaunch: initialLaunch,
                expectedOuterAttemptUUID: expectedOuterAttemptUUID,
                expectedWholeInputSHA256: expectedWholeInputSHA256,
                recoveryProcessGroupID: recoveryProcessGroupID,
                coordinatorSessionID: coordinatorSessionID
            )
            state.resolvedRootValidationCollected = true
            return .resolvedRootDriverValidationInput(value)

        case .drainOutput:
            guard let descriptor = state.outputRead else { throw unexpected() }
            return .output(try drainOutput(descriptor: descriptor))

        case .observeWaitableChild:
            return try observeChildState()

        case .waitForTerminationGrace:
            return try waitForTerminationGrace()

        case .sendTermToChildGroup(let group):
            try requireVerifiedChildGroup(group)
            try beginCleanupDeadlineIfNeeded()
            try sendSignal(toGroup: group, signal: SIGTERM)
            return .completed

        case .sendKillToChildGroup(let group):
            try requireVerifiedChildGroup(group)
            try beginCleanupDeadlineIfNeeded()
            try sendSignal(toGroup: group, signal: SIGKILL)
            state.killSent = true
            return .completed

        case .observeLeaderOnlyChildGroup:
            guard
                let child = state.childProcessID,
                let recoveryGroup = state.recoveryProcessGroupID
            else { throw containment() }
            if state.killSent {
                let deadline = try cleanupDeadline()
                while try continuousNanoseconds() < deadline {
                    let members = try processGroupMembers(recoveryGroup)
                    if (members.isEmpty || members == [child]),
                        try waitableChild(child) != nil
                    {
                        return .completed
                    }
                    try pause()
                }
                throw containment()
            }
            let members = try processGroupMembers(recoveryGroup)
            guard try waitableChild(child) != nil else {
                return .childGroupActive
            }
            return members.isEmpty || members == [child]
                ? .completed : .childGroupActive

        case .reapExactChild:
            guard let child = state.childProcessID, !state.childReaped else {
                throw unexpected()
            }
            var status: Int32 = 0
            while true {
                let result = waitpid(child, &status, WNOHANG)
                if result == child {
                    let classification = try classify(status)
                    guard
                        state.lastWaitClassification == nil
                            || state.lastWaitClassification == classification
                    else { throw containment() }
                    state.childReaped = true
                    state.lastWaitClassification = classification
                    return .completed
                }
                if result < 0, errno == EINTR { continue }
                throw containment()
            }

        case .observeEmptyChildGroup:
            guard let group = state.childProcessGroupID,
                  try processGroupMembers(group).isEmpty
            else { throw containment() }
            state.childGroupEmpty = true
            return .completed

        case .revalidateFinalTTY:
            let value = try terminalObservation()
            guard value == state.initialTerminal else { throw restoration() }
            return .terminal(value)

        case .collectResolvedRootDriverRetirement(let lineage):
            guard
                state.resolvedRootValidationCollected,
                state.childReaped,
                state.childGroupEmpty,
                !state.resolvedRootRetirementCollected
            else { throw unexpected() }
            let value = try collectResolvedRootDriverRetirement(lineage)
            state.resolvedRootRetirementCollected = true
            return .resolvedRootDriverRetirementEnumeration(value)

        case .observeFinalInput:
            return .input(try observeFinalInput())

        case .closeBorrowedDescriptor(let descriptor):
            guard
                descriptor == STDIN_FILENO,
                !state.inputCloseAttempted
            else {
                throw unexpected()
            }
            state.inputCloseAttempted = true
            try closeDescriptor(descriptor)
            state.inputClosed = true
            return .completed

        case .observeCompletion:
            let value = try continuousNanoseconds()
            guard let started = state.startedNanoseconds,
                  value >= started, let deadline = state.deadlineNanoseconds,
                  value <= deadline
            else { throw containment() }
            return .nanoseconds(value)

        case .writeTerminalReceipt(let data):
            guard !state.terminalReceiptWritten,
                  data.count <= InvestigationMachineGateTransportReceipt.maximumByteCount,
                  data.count <= Int(PIPE_BUF)
            else { throw InvestigationMachineGateError.receiptWriteFailed }
            _ = try InvestigationMachineGateTransportReceipt.decode(data)
            do { try writeOneRecord(descriptor: STDOUT_FILENO, data: data) }
            catch { throw InvestigationMachineGateError.receiptWriteFailed }
            state.terminalReceiptWritten = true
            state.coordinatorStreamCloseAttempted = true
            try closeDescriptor(STDOUT_FILENO)
            state.coordinatorStreamClosed = true
            return .completed

        }
    }
}

private extension DarwinInvestigationMachineFixedGateSystem {
    struct State {
        var invocationValidated = false
        var originalSIGCHLDHandlerBits: UInt?
        var forwardedSignal: Int32?
        var startedNanoseconds: UInt64?
        var deadlineNanoseconds: UInt64?
        var cleanupDeadlineNanoseconds: UInt64?
        var killSent = false
        var launcherSHA256: InvestigationHandoffSHA256?
        var initialInput: InvestigationMachineGateInputContext?
        var initialInputMetadata: DescriptorMetadata?
        var initialTerminal: InvestigationMachineGateTerminalObservation?
        var savedForegroundProcessGroupID: pid_t?
        var recoveryProcessGroupID: pid_t?
        var gateJoinedCoordinatorGroup = false
        var sessionID: pid_t?
        var foregroundProcessGroupID: pid_t?
        var outputRead: Int32?
        var outputWrite: Int32?
        var capturedOutput = Data()
        var outputReachedEOF = false
        var outputDeadlineExpired = false
        var childProcessID: pid_t?
        var childProcessGroupID: pid_t?
        var childIdentity: ChildIdentity?
        var childGroupVerified = false
        var childReaped = false
        var childGroupEmpty = false
        var preparedFrameWritten = false
        var stoppedForCoordinator = false
        var inputCloseAttempted = false
        var inputClosed = false
        var terminalReceiptWritten = false
        var coordinatorStreamCloseAttempted = false
        var coordinatorStreamClosed = false
        var lastWaitClassification: InvestigationMachineGateWaitClassification?
        var resolvedRootValidationCollected = false
        var resolvedRootRetirementCollected = false
    }

    func validateInvocation() throws
        -> InvestigationMachineGateInvocationObservation
    {
        guard CommandLine.argc == 1, try normalizeEnvironment() == 0 else {
            throw InvestigationMachineGateError.invalidInvocation
        }
        let openDescriptors = try descriptorInventory()
        guard openDescriptors == [STDIN_FILENO, STDOUT_FILENO, STDERR_FILENO]
        else { throw InvestigationMachineGateError.invalidInvocation }

        let inputValid = try initialInputDescriptorIsValid()
        let outputValid = try outputDescriptorIsValid()
        let terminalValid = try terminalDescriptorIsValid()
        let processGroup = getpgrp()
        let foreground = tcgetpgrp(STDERR_FILENO)
        let parent = getppid()
        let session = getsid(0)
        guard
            processGroup == getpid(), foreground > 1,
            foreground != processGroup, parent > 1, session > 1,
            parent == session, session == foreground
        else {
            throw InvestigationMachineGateError.invalidInvocation
        }
        let previousSIGCHLD = Darwin.signal(SIGCHLD, SIG_DFL)
        guard
            unsafeBitCast(previousSIGCHLD, to: UInt.self)
                != unsafeBitCast(SIG_ERR, to: UInt.self)
        else { throw InvestigationMachineGateError.invalidInvocation }
        state.originalSIGCHLDHandlerBits = unsafeBitCast(
            previousSIGCHLD, to: UInt.self
        )
        try verifyInheritedSignalMask()
        state.sessionID = session
        return .init(
            argumentCount: Int(CommandLine.argc),
            environmentCount: 0,
            realUserID: getuid(), effectiveUserID: geteuid(),
            realGroupID: getgid(), effectiveGroupID: getegid(),
            inputDescriptorValid: inputValid,
            outputDescriptorWritable: outputValid,
            terminalDescriptorWritableCharacterDevice: terminalValid,
            processID: getpid(), parentProcessID: parent,
            sessionID: session, processGroupID: processGroup,
            foregroundProcessGroupID: foreground
        )
    }

    func environmentEntries() -> [String] {
        guard let environment = investigationMachineGateEnvironmentPointer()
            .pointee
        else { return [] }
        var entries: [String] = []
        var index = 0
        while let pointer = environment[index] {
            entries.append(String(cString: pointer))
            index += 1
        }
        return entries
    }

    func normalizeEnvironment() throws -> Int {
        let entries = environmentEntries()
        let normalized = try InvestigationMachineGateEnvironmentValidator
            .normalizedSourceEnvironmentCount(entries)
        if !entries.isEmpty {
            guard unsetenv("__CF_USER_TEXT_ENCODING") == 0,
                  environmentEntries().isEmpty
            else { throw invalidInvocation() }
        }
        return normalized
    }

    func descriptorInventory() throws -> [Int32] {
        var values = [proc_fdinfo](repeating: proc_fdinfo(), count: 64)
        let byteCount = values.withUnsafeMutableBytes { buffer in
            proc_pidinfo(
                getpid(), PROC_PIDLISTFDS, 0, buffer.baseAddress,
                Int32(buffer.count)
            )
        }
        guard
            byteCount >= 0,
            Int(byteCount) < values.count * MemoryLayout<proc_fdinfo>.stride,
            Int(byteCount).isMultiple(of: MemoryLayout<proc_fdinfo>.stride)
        else { throw invalidInvocation() }
        let descriptors = values
            .prefix(Int(byteCount) / MemoryLayout<proc_fdinfo>.stride)
            .map(\.proc_fd).sorted()
        guard Set(descriptors).count == descriptors.count else {
            throw invalidInvocation()
        }
        return descriptors
    }

    func initialInputDescriptorIsValid() throws -> Bool {
        let metadata = try metadata(STDIN_FILENO)
        let flags = try descriptorStatusFlags(STDIN_FILENO)
        let offset = lseek(STDIN_FILENO, 0, SEEK_CUR)
        let aclIsEmpty = try extendedACLIsEmpty(STDIN_FILENO)
        let attributesAreEmpty = try extendedAttributeNames(STDIN_FILENO).isEmpty
        return metadata.type == mode_t(S_IFREG)
            && metadata.ownerUID
                == InvestigationMachineFixedGateContract.requiredUserID
            && metadata.ownerGID
                == InvestigationMachineFixedGateContract.requiredGroupID
            && metadata.permissions == 0o600
            && metadata.linkCount == 1
            && metadata.flags == 0
            && metadata.size > 0
            && metadata.size
                <= Int64(InvestigationProjectedCohortInput.maximumByteCount)
            && flags & O_ACCMODE == O_RDONLY
            && offset == 0
            && aclIsEmpty
            && attributesAreEmpty
    }

    func outputDescriptorIsValid() throws -> Bool {
        let value = try metadata(STDOUT_FILENO)
        let flags = try descriptorStatusFlags(STDOUT_FILENO)
        guard value.type == mode_t(S_IFIFO), flags & O_ACCMODE == O_WRONLY else {
            return false
        }
        guard fcntl(STDOUT_FILENO, F_SETNOSIGPIPE, 1) == 0 else {
            throw invalidInvocation()
        }
        return fcntl(STDOUT_FILENO, F_GETNOSIGPIPE) == 1
    }

    func terminalDescriptorIsValid() throws -> Bool {
        let value = try metadata(STDERR_FILENO)
        let flags = try descriptorStatusFlags(STDERR_FILENO)
        let access = flags & O_ACCMODE
        return value.type == mode_t(S_IFCHR)
            && (access == O_WRONLY || access == O_RDWR)
            && isatty(STDERR_FILENO) == 1
    }

    func verifyInheritedSignalMask() throws {
        var observed = sigset_t()
        // POSIX ignores `how` when `set` is nil.  Use the non-restoring
        // operation name here as well so both the implementation and the
        // structural gate make it explicit that this call only observes the
        // mask inherited atomically from the coordinator.
        guard pthread_sigmask(SIG_BLOCK, nil, &observed) == 0 else {
            throw invalidInvocation()
        }
        for signal in InvestigationMachineFixedGateContract.forwardedSignals
            + [SIGTTIN, SIGTTOU, SIGTSTP]
        where sigismember(&observed, signal) != 1 {
            throw invalidInvocation()
        }
    }

    func executableSHA256() throws -> InvestigationHandoffSHA256 {
        var path = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let count = proc_pidpath(getpid(), &path, UInt32(path.count))
        guard count > 0, count < path.count,
              let executable = String(
                validating: path.prefix(Int(count)).map(UInt8.init(bitPattern:)),
                as: UTF8.self
              )
        else {
            throw InvestigationMachineGateError.invalidObservation
        }
        let descriptor = Darwin.open(executable, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else { throw containment() }
        defer { _ = Darwin.close(descriptor) }
        let before = try metadata(descriptor)
        let namedBefore = try namedMetadata(executable)
        guard
            before.type == mode_t(S_IFREG), before.linkCount == 1,
            before == namedBefore
        else {
            throw containment()
        }
        let value = try readRegularFile(descriptor: descriptor, maximum: 64 << 20)
        guard
            try metadata(descriptor) == before,
            try namedMetadata(executable) == before
        else { throw containment() }
        return InvestigationHandoffSHA256.hashing(value)
    }

    func observeInitialInput() throws -> InvestigationMachineGateInputContext {
        let metadata = try metadata(STDIN_FILENO)
        let offset = lseek(STDIN_FILENO, 0, SEEK_CUR)
        guard offset == 0 else { throw containment() }
        let bytes = try preadRegularFile(
            descriptor: STDIN_FILENO, size: metadata.size
        )
        guard
            lseek(STDIN_FILENO, 0, SEEK_CUR) == 0,
            try self.metadata(STDIN_FILENO) == metadata,
            try extendedACLIsEmpty(STDIN_FILENO),
            try extendedAttributeNames(STDIN_FILENO).isEmpty
        else { throw containment() }
        let decoded = try InvestigationProjectedCohortInput.decode(bytes)
        guard try decoded.encoded() == bytes else { throw containment() }
        let value = InvestigationMachineGateInputContext(
            outerAttemptUUID: decoded.capsule.outerAttemptUUID,
            expectedWholeInputSHA256: decoded.wholeInputSHA256,
            capsule: node(metadata), initialOffset: 0
        )
        try value.validate()
        state.initialInputMetadata = metadata
        return value
    }

    func observeFinalInput() throws -> InvestigationMachineGateInputObservation {
        guard let initial = state.initialInput else { throw unexpected() }
        let metadata = try metadata(STDIN_FILENO)
        let finalOffset = lseek(STDIN_FILENO, 0, SEEK_CUR)
        guard
            node(metadata) == initial.capsule,
            metadata == state.initialInputMetadata,
            finalOffset == metadata.size,
            try extendedACLIsEmpty(STDIN_FILENO),
            try extendedAttributeNames(STDIN_FILENO).isEmpty
        else {
            throw containment()
        }
        let bytes = try preadRegularFile(
            descriptor: STDIN_FILENO, size: metadata.size
        )
        guard
            lseek(STDIN_FILENO, 0, SEEK_CUR) == finalOffset,
            try self.metadata(STDIN_FILENO) == metadata
        else {
            throw containment()
        }
        let decoded = try InvestigationProjectedCohortInput.decode(bytes)
        guard try decoded.encoded() == bytes,
              decoded.wholeInputSHA256 == initial.expectedWholeInputSHA256
        else { throw containment() }
        return .init(
            node: node(metadata), initialOffset: initial.initialOffset,
            finalOffset: finalOffset, reachedEOF: true,
            sha256: decoded.wholeInputSHA256
        )
    }

    func makeOutputPipe() throws -> (read: Int32, write: Int32) {
        var descriptors = [Int32](repeating: -1, count: 2)
        guard pipe(&descriptors) == 0 else { throw containment() }
        do {
            try setCloseOnExec(descriptors[0])
            try setCloseOnExec(descriptors[1])
            return (descriptors[0], descriptors[1])
        } catch {
            _ = Darwin.close(descriptors[0])
            _ = Darwin.close(descriptors[1])
            throw error
        }
    }

    func spawnSuspendedChild(
        outputRead: Int32, outputWrite: Int32
    ) throws -> pid_t {
        var actions: posix_spawn_file_actions_t?
        guard posix_spawn_file_actions_init(&actions) == 0 else {
            throw containment()
        }
        defer { posix_spawn_file_actions_destroy(&actions) }
        guard
            posix_spawn_file_actions_addinherit_np(&actions, STDIN_FILENO) == 0,
            posix_spawn_file_actions_adddup2(
                &actions, outputWrite, STDOUT_FILENO
            ) == 0,
            posix_spawn_file_actions_addinherit_np(&actions, STDERR_FILENO) == 0,
            posix_spawn_file_actions_addclose(&actions, outputRead) == 0,
            posix_spawn_file_actions_addclose(&actions, outputWrite) == 0
        else { throw containment() }

        var attributes: posix_spawnattr_t?
        guard posix_spawnattr_init(&attributes) == 0 else { throw containment() }
        defer { posix_spawnattr_destroy(&attributes) }
        var childMask = sigset_t()
        var childDefaults = sigset_t()
        let childDefaultSignals =
            InvestigationMachineFixedGateContract.forwardedSignals
                + [SIGTTOU, SIGTTIN, SIGTSTP, SIGPIPE]
        guard
            sigemptyset(&childDefaults) == 0,
            sigemptyset(&childMask) == 0,
            childDefaultSignals.allSatisfy({ signal in
                sigaddset(&childDefaults, signal) == 0
            }),
            posix_spawnattr_setflags(
                &attributes, InvestigationMachineFixedGateContract.childSpawnFlags
            ) == 0,
            posix_spawnattr_setsigmask(&attributes, &childMask) == 0,
            posix_spawnattr_setsigdefault(&attributes, &childDefaults) == 0
        else { throw containment() }

        var processID: pid_t = 0
        let result = try withCStringArray(
            InvestigationMachineFixedGateContract.arguments
        ) { arguments in
            try withCStringArray(
                InvestigationMachineFixedGateContract.environment
            ) { environment in
                InvestigationMachineFixedGateContract.launcherPath.withCString {
                    posix_spawn(
                        &processID, $0, &actions, &attributes,
                        arguments, environment
                    )
                }
            }
        }
        guard result == 0, processID > 1 else { throw containment() }
        guard let recoveryGroup = state.recoveryProcessGroupID else {
            throw containment()
        }
        state.childProcessID = processID
        state.childProcessGroupID = recoveryGroup
        do {
            state.childIdentity = try observeChildIdentity(
                processID: processID
            )
            guard try stableChildIdentity(processID: processID) else {
                throw containment()
            }
            state.childGroupVerified = true
            guard
                try waitForInitialStop(processID),
                getpgid(processID) == recoveryGroup
            else { throw containment() }
            state.childProcessGroupID = recoveryGroup
            state.childGroupVerified = true
            state.childIdentity = try observeChildIdentity(processID: processID)
        } catch {
            let cleanup = cleanupFailedInitialStop(processID: processID)
            state.childReaped = cleanup.reaped
            if !cleanup.reaped || !cleanup.groupEmpty {
                throw InvestigationMachineGateSpawnFailure(
                    processID: processID, processGroupID: recoveryGroup
                )
            }
            throw InvestigationMachineGateSettledSpawnFailure(
                processID: processID, processGroupID: recoveryGroup,
                childAlreadyReaped: true, childGroupEmpty: true
            )
        }
        return processID
    }

    func cleanupFailedInitialStop(
        processID: pid_t
    ) -> (reaped: Bool, groupEmpty: Bool) {
        do {
            guard let recoveryGroup = state.recoveryProcessGroupID else {
                return (false, false)
            }
            if state.childReaped {
                return try finishPreJoinSettlement(
                    recoveryGroup: recoveryGroup
                )
            }
            // `processID` is the unreaped direct child returned by posix_spawn.
            // Even when its first identity observation failed, pre-join cleanup
            // signals only this exact PID and never the group containing us.
            state.childProcessID = processID
            state.childProcessGroupID = recoveryGroup
            try beginCleanupDeadlineIfNeeded()
            guard Darwin.kill(processID, SIGKILL) == 0 else {
                guard errno == ESRCH else { return (false, false) }
                if try waitableChild(processID) == nil {
                    return (false, false)
                }
                let reaped = try boundedReapFailedInitialStop(
                    processID: processID
                )
                guard reaped else { return (false, false) }
                return try finishPreJoinSettlement(
                    recoveryGroup: recoveryGroup
                )
            }
            let reaped = try boundedReapFailedInitialStop(
                processID: processID
            )
            guard reaped else { return (false, false) }
            return try finishPreJoinSettlement(recoveryGroup: recoveryGroup)
        } catch {
            return (false, false)
        }
    }

    func finishPreJoinSettlement(
        recoveryGroup: pid_t
    ) throws -> (reaped: Bool, groupEmpty: Bool) {
        let beforeJoin = try rawProcessGroupMembers(recoveryGroup)
        switch InvestigationMachineGateRuntimePolicy.preJoinAction(
            childReaped: true, gateJoinedCoordinator:
                state.gateJoinedCoordinatorGroup,
            recoveryGroupMembers: beforeJoin, gateProcessID: getpid()
        ) {
        case .joinCoordinator:
            guard
                let coordinatorGroup = state.savedForegroundProcessGroupID,
                setpgid(0, coordinatorGroup) == 0,
                getpgrp() == coordinatorGroup
            else { return (true, false) }
            state.gateJoinedCoordinatorGroup = true
        case .complete:
            return (true, true)
        case .reapExactChild, .proveRecoveryGroupEmpty, .reject:
            return (true, false)
        }
        let afterJoin = try rawProcessGroupMembers(recoveryGroup)
        let action = InvestigationMachineGateRuntimePolicy.preJoinAction(
            childReaped: true, gateJoinedCoordinator: true,
            recoveryGroupMembers: afterJoin, gateProcessID: getpid()
        )
        return (true, action == .complete)
    }

    func boundedReapFailedInitialStop(
        processID: pid_t
    ) throws -> Bool {
        let deadline = try cleanupDeadline()
        while try continuousNanoseconds() < deadline {
            if let _ = try waitableChild(processID) {
                var status: Int32 = 0
                while true {
                    let result = waitpid(processID, &status, WNOHANG)
                    if result == processID {
                        state.childReaped = true
                        return true
                    }
                    if result < 0, errno == EINTR { continue }
                    if result == 0 { break }
                    return false
                }
            }
            try pause()
        }
        return false
    }

    func waitForInitialStop(_ processID: pid_t) throws -> Bool {
        let deadline = try operationDeadline()
        while try continuousNanoseconds() < deadline {
            var status: Int32 = 0
            let result = waitpid(processID, &status, WUNTRACED | WNOHANG)
            if result == processID {
                // Darwin reports POSIX_SPAWN_START_SUSPENDED as raw 0x7f
                // with a zero stop-signal field. This is distinct from a
                // later job-control stop, whose field is nonzero.
                if status == 0x7f { return true }
                let classification = try classify(status)
                state.lastWaitClassification = classification
                state.childReaped = InvestigationMachineGateRuntimePolicy
                    .initialStopObservationWasReaped(classification)
                return false
            }
            if result < 0, errno != EINTR { throw containment() }
            try pause()
        }
        throw containment()
    }

    func drainOutput(descriptor: Int32) throws
        -> InvestigationMachineGateOutputObservation
    {
        let deadline = state.childReaped
            ? try cleanupDeadline() : try operationDeadline()
        if state.outputReachedEOF {
            return outputObservation()
        }
        state.capturedOutput.reserveCapacity(
            InvestigationMachineFixedGateContract.maximumReadOutputByteCount
        )
        while state.capturedOutput.count
            < InvestigationMachineFixedGateContract.maximumReadOutputByteCount
        {
            var event = pollfd(
                fd: descriptor, events: Int16(POLLIN | POLLHUP), revents: 0
            )
            try consumeAndForwardPendingSignal()
            let result = poll(&event, 1, try pollMilliseconds(deadline))
            if result == 0 {
                if let child = state.childProcessID,
                    let terminal = try waitableChild(child)
                {
                    state.lastWaitClassification = terminal
                    break
                }
                let now = try continuousNanoseconds()
                let businessDeadline = try operationDeadline()
                if now >= businessDeadline {
                    state.outputDeadlineExpired = true
                    break
                }
                continue
            }
            if result < 0 {
                if errno == EINTR { continue }
                throw containment()
            }
            if event.revents & Int16(POLLERR | POLLNVAL) != 0 {
                throw containment()
            }
            var bytes = [UInt8](repeating: 0, count:
                InvestigationMachineFixedGateContract.maximumReadOutputByteCount
                    - state.capturedOutput.count)
            let count = Darwin.read(descriptor, &bytes, bytes.count)
            if count > 0 {
                state.capturedOutput.append(contentsOf: bytes.prefix(count))
            }
            if count == 0 { state.outputReachedEOF = true; break }
            if count < 0, errno == EINTR || errno == EAGAIN { continue }
            if count < 0 { throw containment() }
            if state.capturedOutput.count
                == InvestigationMachineFixedGateContract.maximumReadOutputByteCount
            { break }
        }
        return outputObservation()
    }

    func collectResolvedRootDriverValidation(
        initialLaunch: InvestigationMachineInitialSudoLaunchIdentity,
        expectedOuterAttemptUUID: UUID,
        expectedWholeInputSHA256: InvestigationHandoffSHA256,
        recoveryProcessGroupID: UInt32,
        coordinatorSessionID: UInt32
    ) throws -> InvestigationMachineResolvedRootDriverValidationInput {
        guard
            let descriptor = state.outputRead,
            let recoveryGroup = state.recoveryProcessGroupID,
            pid_t(recoveryProcessGroupID) == recoveryGroup,
            UInt32(state.sessionID ?? 0) == coordinatorSessionID
        else { throw containment() }
        let claim = try readResolvedRootDriverClaim(descriptor: descriptor)
        let resolvedProcessID = pid_t(claim.process.processID)
        let firstIdentity =
            try InvestigationMachineResolvedRootDriverSupport
            .gateObservedProcessIdentity(
            processID: resolvedProcessID
        )
        let firstStopped = try processIsStopped(
            processID: resolvedProcessID
        )
        let firstObservedAt = try continuousNanoseconds()
        let fixedExecutable = try fixedExecutableIdentity()
        let liveExecutablePathBeforeSigning =
            try InvestigationMachineResolvedRootDriverSupport
            .liveExecutablePath(
                processID: resolvedProcessID
            )
        let liveSigning =
            try InvestigationMachineResolvedRootDriverSupport
            .liveSigningIdentity(
            processID: resolvedProcessID
        )
        let liveExecutablePathAfterSigning =
            try InvestigationMachineResolvedRootDriverSupport
            .liveExecutablePath(
                processID: resolvedProcessID
            )
        try InvestigationMachineResolvedRootDriverSupport
            .validateLiveExecutablePaths(
                before: liveExecutablePathBeforeSigning,
                after: liveExecutablePathAfterSigning
            )
        let secondIdentity =
            try InvestigationMachineResolvedRootDriverSupport
            .gateObservedProcessIdentity(
            processID: resolvedProcessID
        )
        let secondStopped = try processIsStopped(
            processID: resolvedProcessID
        )
        let secondObservedAt = try continuousNanoseconds()
        guard
            firstIdentity == secondIdentity,
            firstStopped,
            secondStopped
        else { throw InvestigationMachineGateError.invalidObservation }
        let members = try processGroupMembers(recoveryGroup)
        let identities = try Dictionary(
            uniqueKeysWithValues: members.map {
                (
                    $0,
                    try InvestigationMachineResolvedRootDriverSupport
                        .gateObservedProcessIdentity(processID: $0)
                )
            }
        )
        let lineageEdges =
            try InvestigationMachineResolvedRootDriverSupport
            .resolveLineageEdges(
            initialLaunch: initialLaunch,
            resolved: firstIdentity,
            identitiesByPID: identities,
            recoveryProcessGroupID: recoveryProcessGroupID,
            coordinatorSessionID: coordinatorSessionID
        )
        let projectedInput = try projectedInput()
        return .init(
            claim: claim,
            expectedOuterAttemptUUID: expectedOuterAttemptUUID,
            expectedWholeInputSHA256: expectedWholeInputSHA256,
            initialLaunch: initialLaunch,
            recoveryProcessGroupID: recoveryProcessGroupID,
            coordinatorSessionID: coordinatorSessionID,
            lineageEdges: lineageEdges,
            firstProcessSample: .init(
                identity: firstIdentity,
                isStopped: firstStopped,
                observedAtContinuousNanoseconds: firstObservedAt
            ),
            secondProcessSample: .init(
                identity: secondIdentity,
                isStopped: secondStopped,
                observedAtContinuousNanoseconds: secondObservedAt
            ),
            fixedExecutableNode: fixedExecutable.node,
            fixedExecutableSHA256: fixedExecutable.sha256,
            fixedStaticSigning: fixedExecutable.staticSigning,
            liveSigning: liveSigning,
            liveSigningProcessID: claim.process.processID,
            projectedCohortInput: projectedInput
        )
    }

    func collectResolvedRootDriverRetirement(
        _ lineage: [InvestigationMachineGateObservedProcessIdentity]
    ) throws -> InvestigationMachineResolvedRootDriverRetirementEnumeration {
        let observations = try lineage.map { identity in
            let pid = identity.processID
            do {
                let current =
                    try InvestigationMachineResolvedRootDriverSupport
                    .gateObservedProcessIdentity(processID: pid_t(pid))
                return InvestigationMachineResolvedRootDriverRetirementObservation(
                    processID: pid,
                    state: .present(current)
                )
            } catch let error as InvestigationMachineGateError
            where error == .invalidObservation {
                return InvestigationMachineResolvedRootDriverRetirementObservation(
                    processID: pid,
                    state: .absent
                )
            } catch {
                throw containment()
            }
        }
        return .init(isComplete: true, observations: observations)
    }

    func outputObservation() -> InvestigationMachineGateOutputObservation {
        let overflow = state.capturedOutput.count
            > InvestigationMachineFixedGateContract.maximumCapturedOutputByteCount
        let prefix = state.capturedOutput.prefix(
            InvestigationMachineFixedGateContract.maximumCapturedOutputByteCount
        )
        return .init(
            byteCount: prefix.count,
            sha256: InvestigationHandoffSHA256.hashing(Data(prefix)),
            overflowObserved: overflow, reachedEOF: state.outputReachedEOF
            , deadlineExpired: state.outputDeadlineExpired
        )
    }

    func readResolvedRootDriverClaim(descriptor: Int32) throws
        -> ResolvedRootDriverClaimV1
    {
        let deadline = try operationDeadline()
        let prefix = try readOutputExact(
            descriptor: descriptor, count: 4, deadline: deadline
        )
        guard prefix.count == 4 else {
            throw InvestigationMachineGateError.invalidObservation
        }
        let count = Int(
            prefix.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        )
        guard count == ResolvedRootDriverClaimV1.encodedByteCount else {
            throw InvestigationMachineGateError.invalidObservation
        }
        let claimBytes = try readOutputExact(
            descriptor: descriptor, count: count, deadline: deadline
        )
        state.capturedOutput.append(prefix)
        state.capturedOutput.append(claimBytes)
        guard
            state.capturedOutput.count
                <= InvestigationMachineFixedGateContract
                    .maximumReadOutputByteCount
        else { throw InvestigationMachineGateError.invalidObservation }
        var event = pollfd(fd: descriptor, events: Int16(POLLIN | POLLHUP), revents: 0)
        let available = poll(&event, 1, 0)
        guard available == 0, event.revents == 0 else {
            throw InvestigationMachineGateError.invalidObservation
        }
        do {
            let value = try ResolvedRootDriverClaimV1.decode(claimBytes)
            guard try value.encoded() == claimBytes else {
                throw InvestigationMachineGateError.invalidObservation
            }
            try waitForStoppedResolvedRootDriver(
                processID: pid_t(value.process.processID),
                descriptor: descriptor,
                deadline: deadline
            )
            return value
        } catch {
            throw InvestigationMachineGateError.invalidObservation
        }
    }

    func readOutputExact(
        descriptor: Int32, count: Int, deadline: UInt64
    ) throws -> Data {
        guard count > 0 else { throw InvestigationMachineGateError.invalidObservation }
        var data = Data()
        data.reserveCapacity(count)
        while data.count < count {
            try consumeAndForwardPendingSignal()
            var event = pollfd(
                fd: descriptor, events: Int16(POLLIN | POLLHUP), revents: 0
            )
            let result = poll(&event, 1, try pollMilliseconds(deadline))
            if result == 0 { continue }
            if result < 0 {
                if errno == EINTR { continue }
                throw containment()
            }
            if event.revents & Int16(POLLERR | POLLNVAL) != 0 {
                throw containment()
            }
            var bytes = [UInt8](repeating: 0, count: count - data.count)
            let readCount = Darwin.read(descriptor, &bytes, bytes.count)
            if readCount > 0 {
                data.append(contentsOf: bytes.prefix(readCount))
                continue
            }
            if readCount == 0 {
                throw InvestigationMachineGateError.invalidObservation
            }
            if errno == EINTR || errno == EAGAIN { continue }
            throw containment()
        }
        return data
    }

    func observeChildState() throws -> InvestigationMachineGateLauncherResponse {
        guard let child = state.childProcessID else { throw unexpected() }
        // A terminal direct child can still have descendants in G. Consume
        // before the fast return so pending group signals reach them.
        try consumeAndForwardPendingSignal()
        if let terminal = try waitableChild(child) {
            state.lastWaitClassification = terminal
            return .waitClassification(terminal)
        }
        if state.killSent {
            let deadline = try cleanupDeadline()
            while try continuousNanoseconds() < deadline {
                if let terminal = try waitableChild(child) {
                    state.lastWaitClassification = terminal
                    return .waitClassification(terminal)
                }
                try pause()
            }
            throw containment()
        }
        return .childRunning
    }

    func waitForTerminationGrace() throws
        -> InvestigationMachineGateLauncherResponse
    {
        let started = try continuousNanoseconds()
        let localDeadline = try adding(Self.terminationGraceNanoseconds, to: started)
        let deadline = min(localDeadline, try cleanupDeadline())
        while try continuousNanoseconds() < deadline {
            let observed = try observeChildState()
            if case .waitClassification = observed,
                let recoveryGroup = state.recoveryProcessGroupID
            {
                let members = try processGroupMembers(recoveryGroup)
                if members.isEmpty
                    || state.childProcessID.map({ members == [$0] }) == true
                {
                    return observed
                }
            }
            try pause()
        }
        return .childRunning
    }

    func waitableChild(
        _ processID: pid_t
    ) throws -> InvestigationMachineGateWaitClassification? {
        while true {
            var information = siginfo_t()
            let result = waitid(
                P_PID, UInt32(bitPattern: processID), &information,
                WEXITED | WSTOPPED | WNOHANG | WNOWAIT
            )
            if result == 0 {
                guard information.si_pid != 0 else { return nil }
                switch information.si_code {
                case CLD_EXITED:
                    return .exited(status: information.si_status)
                case CLD_KILLED, CLD_DUMPED:
                    return .signaled(signal: information.si_status)
                case CLD_STOPPED:
                    return .stopped(signal: information.si_status)
                default:
                    throw containment()
                }
            }
            if errno == EINTR { continue }
            throw containment()
        }
    }

    func processGroupMembers(_ processGroupID: pid_t) throws -> [pid_t] {
        try requireVerifiedChildGroup(processGroupID)
        return try rawProcessGroupMembers(processGroupID)
    }

    func rawProcessGroupMembers(_ processGroupID: pid_t) throws -> [pid_t] {
        guard processGroupID > 1 else { throw containment() }
        var values = [pid_t](
            repeating: 0, count: Self.maximumProcessGroupMembers
        )
        let count = values.withUnsafeMutableBytes { buffer in
            proc_listpids(
                UInt32(PROC_PGRP_ONLY), UInt32(bitPattern: processGroupID),
                buffer.baseAddress, Int32(buffer.count)
            )
        }
        guard
            count >= 0, Int(count) < values.count * MemoryLayout<pid_t>.size,
            Int(count).isMultiple(of: MemoryLayout<pid_t>.size)
        else { throw containment() }
        let raw = Array(
            values.prefix(Int(count) / MemoryLayout<pid_t>.size)
        )
        guard
            raw.allSatisfy({ $0 > 1 }),
            Set(raw).count == raw.count
        else { throw containment() }
        let admitted = raw.sorted()
        return admitted
    }

    func processIsStopped(processID: pid_t) throws -> Bool {
        var information = proc_bsdinfo()
        let count = proc_pidinfo(
            processID,
            PROC_PIDTBSDINFO,
            0,
            &information,
            Int32(MemoryLayout<proc_bsdinfo>.size)
        )
        guard count == MemoryLayout<proc_bsdinfo>.size else {
            throw InvestigationMachineGateError.invalidObservation
        }
        return information.pbi_status == UInt32(SSTOP)
    }

    func waitForStoppedResolvedRootDriver(
        processID: pid_t,
        descriptor: Int32,
        deadline: UInt64
    ) throws {
        while true {
            if try processIsStopped(processID: processID) { return }
            try consumeAndForwardPendingSignal()
            var event = pollfd(
                fd: descriptor, events: Int16(POLLIN | POLLHUP), revents: 0
            )
            let available = poll(&event, 1, 0)
            guard available == 0, event.revents == 0 else {
                throw InvestigationMachineGateError.invalidObservation
            }
            _ = try pollMilliseconds(deadline)
            try pause()
        }
    }

    func terminalObservation() throws
        -> InvestigationMachineGateTerminalObservation
    {
        let value = try metadata(STDERR_FILENO)
        let group = tcgetpgrp(STDERR_FILENO)
        guard value.type == mode_t(S_IFCHR), group > 1,
              try terminalDescriptorIsValid()
        else { throw restoration() }
        return .init(
            device: value.device, inode: value.inode,
            foregroundProcessGroupID: group
        )
    }

    func setForeground(_ group: pid_t) throws {
        while tcsetpgrp(STDERR_FILENO, group) != 0 {
            if errno == EINTR { continue }
            throw restoration()
        }
    }

    func sendSignal(toGroup group: pid_t, signal: Int32) throws {
        try requireVerifiedChildGroup(group)
        errno = 0
        let result = Darwin.kill(-group, signal)
        if result == 0 { return }
        if errno == ESRCH {
            guard let child = state.childProcessID,
                  InvestigationMachineGateRuntimePolicy
                    .missingGroupSignalIsSettled(
                        directChildWaitable: try waitableChild(child) != nil,
                        recoveryGroupMembers:
                            try rawProcessGroupMembers(group)
                    )
            else { throw containment() }
            return
        }
        guard result == 0
        else { throw containment() }
    }

    func classify(_ status: Int32) throws
        -> InvestigationMachineGateWaitClassification
    {
        let low = status & 0x7f
        if low == 0 { return .exited(status: (status >> 8) & 0xff) }
        if low == 0x7f { return .stopped(signal: (status >> 8) & 0xff) }
        guard low > 0, low < NSIG else { throw containment() }
        return .signaled(signal: low)
    }

    func metadata(_ descriptor: Int32) throws -> DescriptorMetadata {
        var value = stat()
        guard fstat(descriptor, &value) == 0 else { throw invalidInvocation() }
        return .init(
            device: UInt64(bitPattern: Int64(value.st_dev)),
            inode: UInt64(value.st_ino), generation: UInt64(value.st_gen),
            type: value.st_mode & mode_t(S_IFMT),
            ownerUID: value.st_uid, ownerGID: value.st_gid,
            permissions: value.st_mode & 0o7777,
            linkCount: UInt64(value.st_nlink), size: value.st_size,
            flags: value.st_flags
        )
    }

    func namedMetadata(_ path: String) throws -> DescriptorMetadata {
        var value = stat()
        guard lstat(path, &value) == 0 else { throw containment() }
        return .init(
            device: UInt64(bitPattern: Int64(value.st_dev)),
            inode: UInt64(value.st_ino), generation: UInt64(value.st_gen),
            type: value.st_mode & mode_t(S_IFMT),
            ownerUID: value.st_uid, ownerGID: value.st_gid,
            permissions: value.st_mode & 0o7777,
            linkCount: UInt64(value.st_nlink), size: value.st_size,
            flags: value.st_flags
        )
    }

    func descriptorStatusFlags(_ descriptor: Int32) throws -> Int32 {
        let value = fcntl(descriptor, F_GETFL)
        guard value >= 0 else { throw invalidInvocation() }
        return value
    }

    func extendedACLIsEmpty(_ descriptor: Int32) throws -> Bool {
        errno = 0
        guard let acl = acl_get_fd_np(descriptor, ACL_TYPE_EXTENDED) else {
            if errno == ENOENT { return true }
            throw invalidInvocation()
        }
        var entry: acl_entry_t?
        let result = acl_get_entry(acl, Int32(ACL_FIRST_ENTRY.rawValue), &entry)
        let savedErrno = errno
        guard acl_free(UnsafeMutableRawPointer(acl)) == 0, result >= 0 else {
            errno = savedErrno
            throw invalidInvocation()
        }
        return result != 0
    }

    func extendedAttributeNames(_ descriptor: Int32) throws -> [String] {
        let count = flistxattr(descriptor, nil, 0, 0)
        guard count >= 0, count <= 65_536 else { throw invalidInvocation() }
        guard count > 0 else { return [] }
        var bytes = [UInt8](repeating: 0, count: count)
        let read = bytes.withUnsafeMutableBytes { buffer in
            flistxattr(
                descriptor,
                buffer.baseAddress?.assumingMemoryBound(to: CChar.self),
                buffer.count, 0
            )
        }
        guard read == count, bytes.last == 0 else { throw invalidInvocation() }
        return bytes.split(separator: 0).map { String(decoding: $0, as: UTF8.self) }
    }

    func preadRegularFile(descriptor: Int32, size: Int64) throws -> Data {
        guard size > 0, let count = Int(exactly: size) else { throw containment() }
        var data = Data(count: count)
        var offset = 0
        while offset < count {
            let read = data.withUnsafeMutableBytes { buffer in
                pread(
                    descriptor, buffer.baseAddress?.advanced(by: offset),
                    count - offset, off_t(offset)
                )
            }
            if read > 0 { offset += read; continue }
            if read < 0, errno == EINTR { continue }
            throw containment()
        }
        var byte: UInt8 = 0
        guard pread(descriptor, &byte, 1, off_t(count)) == 0 else {
            throw containment()
        }
        return data
    }

    func readRegularFile(descriptor: Int32, maximum: Int) throws -> Data {
        let value = try metadata(descriptor)
        guard value.type == mode_t(S_IFREG), value.size > 0,
              value.size <= Int64(maximum)
        else { throw containment() }
        return try preadRegularFile(descriptor: descriptor, size: value.size)
    }

    func writeOneRecord(descriptor: Int32, data: Data) throws {
        while true {
            let count = data.withUnsafeBytes { bytes in
                Darwin.write(descriptor, bytes.baseAddress, bytes.count)
            }
            if count == data.count { return }
            if count < 0, errno == EINTR { continue }
            throw containment()
        }
    }

    func closeDescriptor(_ descriptor: Int32) throws {
        guard Darwin.close(descriptor) == 0 else { throw containment() }
    }

    func setCloseOnExec(_ descriptor: Int32) throws {
        let flags = fcntl(descriptor, F_GETFD)
        guard flags >= 0, fcntl(descriptor, F_SETFD, flags | FD_CLOEXEC) == 0
        else { throw containment() }
    }

    func pollMilliseconds(_ deadline: UInt64) throws -> Int32 {
        let now = try continuousNanoseconds()
        guard now < deadline else { throw containment() }
        return Int32(min(max(1, (deadline - now) / 1_000_000), 50))
    }

    func operationDeadline() throws -> UInt64 {
        guard let deadline = state.deadlineNanoseconds else { throw unexpected() }
        return try InvestigationMachineGateDeadlinePolicy.operationDeadline(
            absoluteDeadlineNanoseconds: deadline
        )
    }

    func beginCleanupDeadlineIfNeeded() throws {
        if state.cleanupDeadlineNanoseconds == nil {
            let local = try adding(
                Self.cleanupDeadlineNanoseconds, to: continuousNanoseconds()
            )
            state.cleanupDeadlineNanoseconds = min(
                local, state.deadlineNanoseconds ?? local
            )
        }
    }

    func cleanupDeadline() throws -> UInt64 {
        try beginCleanupDeadlineIfNeeded()
        guard let value = state.cleanupDeadlineNanoseconds else {
            throw containment()
        }
        return value
    }

    func requireVerifiedChildGroup(_ group: pid_t) throws {
        guard
            state.childGroupVerified,
            group == state.recoveryProcessGroupID,
            group == state.childProcessGroupID,
            group > 1, group != getpgrp(),
            let child = state.childProcessID
        else { throw containment() }
        if !state.childReaped {
            guard try stableChildIdentity(processID: child) else {
                throw containment()
            }
        }
    }

    func observeChildIdentity(processID: pid_t) throws -> ChildIdentity {
        var information = proc_bsdinfo()
        let count = proc_pidinfo(
            processID, PROC_PIDTBSDINFO, 0, &information,
            Int32(MemoryLayout<proc_bsdinfo>.size)
        )
        guard
            count == MemoryLayout<proc_bsdinfo>.size,
            information.pbi_pid == UInt32(processID),
            information.pbi_ppid == UInt32(getpid()),
            information.pbi_pgid
                == UInt32(state.recoveryProcessGroupID ?? -1),
            getsid(processID) == state.sessionID,
            information.pbi_start_tvsec > 0,
            information.pbi_start_tvusec < 1_000_000
        else { throw containment() }
        return .init(
            processID: processID, parentProcessID: getpid(),
            processGroupID: state.recoveryProcessGroupID ?? -1,
            startSeconds: UInt64(information.pbi_start_tvsec),
            startMicroseconds: UInt64(information.pbi_start_tvusec),
            sessionID: state.sessionID ?? -1
        )
    }

    func stableChildIdentity(processID: pid_t) throws -> Bool {
        guard let expected = state.childIdentity else { return false }
        return try observeChildIdentity(processID: processID) == expected
    }

    func childIsStopped(processID: pid_t) throws -> Bool {
        var information = proc_bsdinfo()
        let count = proc_pidinfo(
            processID, PROC_PIDTBSDINFO, 0, &information,
            Int32(MemoryLayout<proc_bsdinfo>.size)
        )
        return count == MemoryLayout<proc_bsdinfo>.size
            && information.pbi_status == UInt32(SSTOP)
    }

    func consumeAndForwardPendingSignal() throws {
        var pending = sigset_t()
        guard sigpending(&pending) == 0 else { throw containment() }
        for signal in InvestigationMachineFixedGateContract.forwardedSignals {
            guard sigismember(&pending, signal) == 1 else { continue }
            var singleton = sigset_t()
            guard
                sigemptyset(&singleton) == 0,
                sigaddset(&singleton, signal) == 0
            else { throw containment() }
            var observed: Int32 = 0
            guard sigwait(&singleton, &observed) == 0, observed == signal else {
                throw containment()
            }
            if state.forwardedSignal == nil { state.forwardedSignal = signal }
            guard
                let group = state.childProcessGroupID,
                state.childGroupVerified, !state.childReaped
            else { continue }
            guard let child = state.childProcessID else { throw containment() }
            let childState = try waitableChild(child)
            let directChildTerminal: Bool = switch childState {
            case .exited?, .signaled?: true
            case .stopped?, nil: false
            }
            if InvestigationMachineGateRuntimePolicy.shouldForwardPendingSignal(
                directChildTerminal: directChildTerminal,
                recoveryGroupMembers: try rawProcessGroupMembers(group)
            ) {
                try sendSignal(toGroup: group, signal: signal)
            }
        }
    }

    func pause() throws {
        var requested = timespec(
            tv_sec: 0, tv_nsec: Int(Self.pollSliceNanoseconds)
        )
        while true {
            var remaining = timespec()
            if nanosleep(&requested, &remaining) == 0 { return }
            if errno != EINTR { throw containment() }
            requested = remaining
        }
    }

    func continuousNanoseconds() throws -> UInt64 {
        var timebase = mach_timebase_info_data_t()
        guard mach_timebase_info(&timebase) == KERN_SUCCESS, timebase.denom > 0
        else { throw containment() }
        let product = mach_continuous_time()
            .multipliedFullWidth(by: UInt64(timebase.numer))
        guard product.high < UInt64(timebase.denom) else { throw containment() }
        return UInt64(timebase.denom).dividingFullWidth(product).quotient
    }

    func adding(_ delta: UInt64, to value: UInt64) throws -> UInt64 {
        let result = value.addingReportingOverflow(delta)
        guard !result.overflow else { throw containment() }
        return result.partialValue
    }

    func node(_ value: DescriptorMetadata)
        -> InvestigationMachineGateNodeObservation
    {
        .init(
            device: value.device, inode: value.inode,
            generation: value.generation, size: value.size
        )
    }

    func withCStringArray<Result>(
        _ strings: [String],
        body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws -> Result
    ) throws -> Result {
        guard strings.allSatisfy({ !$0.utf8.contains(0) }) else {
            throw containment()
        }
        var storage: [UnsafeMutablePointer<CChar>?] = strings.map { value in
            value.withCString { strdup($0) }
        }
        guard storage.allSatisfy({ $0 != nil }) else {
            storage.compactMap { $0 }.forEach { free($0) }
            throw containment()
        }
        defer { storage.compactMap { $0 }.forEach { free($0) } }
        storage.append(nil)
        return try storage.withUnsafeMutableBufferPointer {
            try body($0.baseAddress!)
        }
    }

    func projectedInput() throws -> InvestigationProjectedCohortInput {
        let metadata = try metadata(STDIN_FILENO)
        let bytes = try preadRegularFile(descriptor: STDIN_FILENO, size: metadata.size)
        let value = try InvestigationProjectedCohortInput.decode(bytes)
        guard try value.encoded() == bytes else { throw containment() }
        return value
    }

    func fixedExecutableIdentity() throws
        -> InvestigationResolvedRootDriverExecutableIdentityV1
    {
        let path = ResolvedRootDriverClaimV1.fixedExecutablePath
        let before = try namedMetadata(path)
        let descriptor = Darwin.open(path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else { throw containment() }
        defer { _ = Darwin.close(descriptor) }
        let opened = try metadata(descriptor)
        guard before == opened, opened.type == mode_t(S_IFREG) else {
            throw containment()
        }
        let bytes = try readRegularFile(descriptor: descriptor, maximum: 16 << 20)
        guard try namedMetadata(path) == before, try metadata(descriptor) == opened
        else { throw containment() }
        let node = try InvestigationResolvedRootDriverNodeIdentityV1(
            deviceID: opened.device,
            inode: opened.inode,
            generation: UInt32(exactly: opened.generation) ?? 0,
            isRegularFile: opened.type == mode_t(S_IFREG),
            ownerUserID: UInt32(opened.ownerUID),
            ownerGroupID: UInt32(opened.ownerGID),
            mode: UInt32(opened.permissions),
            linkCount: opened.linkCount,
            size: opened.size,
            flags: opened.flags
        )
        let staticCode = try staticCode(forExecutableAt: path)
        let staticSigning = try signingIdentity(staticCode)
        return try .init(
            path: path,
            node: node,
            sha256: .hashing(bytes),
            staticSigning: staticSigning,
            liveSigning: staticSigning
        )
    }

    func staticCode(forExecutableAt path: String) throws -> SecStaticCode {
        var code: SecStaticCode?
        guard
            SecStaticCodeCreateWithPath(
                URL(fileURLWithPath: path) as CFURL,
                SecCSFlags(),
                &code
            ) == errSecSuccess,
            let code,
            SecStaticCodeCheckValidity(
                code,
                SecCSFlags(rawValue: kSecCSStrictValidate),
                nil
            ) == errSecSuccess
        else { throw containment() }
        return code
    }

    func signingIdentity(_ staticCode: SecStaticCode) throws
        -> InvestigationResolvedRootDriverSigningIdentityV1
    {
        var information: CFDictionary?
        let flags = SecCSFlags(
            rawValue: kSecCSSigningInformation | kSecCSRequirementInformation
        )
        guard
            SecCodeCopySigningInformation(staticCode, flags, &information)
                == errSecSuccess,
            let dictionary = information as? [CFString: Any],
            let identifier = dictionary[kSecCodeInfoIdentifier] as? String,
            let codeDirectoryHash = dictionary[kSecCodeInfoUnique] as? Data,
            let signatureFlags = dictionary[kSecCodeInfoFlags] as? NSNumber,
            let requirement = gateRequirement(
                dictionary[kSecCodeInfoDesignatedRequirement]
            ),
            let requirementData = gateRequirementData(requirement)
        else { throw containment() }
        return try .init(
            signingIdentifier: identifier,
            designatedRequirementSHA256: .hashing(requirementData),
            codeDirectoryHash: codeDirectoryHash,
            isAdHoc: signatureFlags.uint32Value
                & investigationMachineGateAdHocFlag != 0
        )
    }

    func gateRequirement(_ value: Any?) -> SecRequirement? {
        guard let value else { return nil }
        let object = value as AnyObject
        guard CFGetTypeID(object) == SecRequirementGetTypeID() else { return nil }
        return unsafeDowncast(object, to: SecRequirement.self)
    }

    func gateRequirementData(_ requirement: SecRequirement) -> Data? {
        var data: CFData?
        guard
            SecRequirementCopyData(requirement, SecCSFlags(), &data)
                == errSecSuccess,
            let data
        else { return nil }
        return data as Data
    }

    func invalidInvocation() -> InvestigationMachineGateError {
        .invalidInvocation
    }

    func unexpected() -> InvestigationMachineGateError {
        .unexpectedResponse
    }

    func restoration() -> InvestigationMachineGateError {
        .restorationUncertain
    }

    func containment() -> InvestigationMachineGateError {
        .containmentUncertain
    }

    struct DescriptorMetadata: Equatable {
        let device: UInt64
        let inode: UInt64
        let generation: UInt64
        let type: mode_t
        let ownerUID: uid_t
        let ownerGID: gid_t
        let permissions: mode_t
        let linkCount: UInt64
        let size: Int64
        let flags: UInt32
    }

    struct ChildIdentity: Equatable {
        let processID: pid_t
        let parentProcessID: pid_t
        let processGroupID: pid_t
        let startSeconds: UInt64
        let startMicroseconds: UInt64
        let sessionID: pid_t

        var transportIdentity: InvestigationMachineGateChildIdentity {
            .init(
                processID: processID, parentProcessID: parentProcessID,
                processGroupID: processGroupID, sessionID: sessionID,
                startSeconds: startSeconds,
                startMicroseconds: startMicroseconds
            )
        }
    }
}
