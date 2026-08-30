// Package-closed state machine for the authority-free machine gate.
import Darwin
import Foundation
import StornautInvestigationHandoffContract

struct InvestigationMachineGateSettledSpawnFailure:
    Error, Equatable, Sendable
{
    let processID: pid_t
    let processGroupID: pid_t
    let childAlreadyReaped: Bool
    let childGroupEmpty: Bool
}

public enum InvestigationMachineGateSupport {
    package static let completedExitStatus: Int32 = 0
    package static let invalidInvocationExitStatus: Int32 = 80
    package static let containmentUncertainExitStatus: Int32 = 82
    package static let forwardedSignalExitStatus: Int32 = 83
    package static let transportFailureExitStatus: Int32 = 84

    public static func run() -> Int32 {
        do {
            let result = try InvestigationMachineFixedGateLauncher(
                system: DarwinInvestigationMachineFixedGateSystem()
            ).run(inheritedCapsuleDescriptor: STDIN_FILENO)
            return status(for: result.receipt)
        } catch InvestigationMachineGateError.invalidInvocation {
            return invalidInvocationExitStatus
        } catch InvestigationMachineGateError.forwardedSignal(_) {
            return forwardedSignalExitStatus
        } catch {
            return containmentUncertainExitStatus
        }
    }

    package static func status(
        for receipt: InvestigationMachineGateTransportReceipt
    ) -> Int32 {
        if receipt.forwardedSignal != nil { return forwardedSignalExitStatus }
        guard
            receipt.waitClassification == .exited(status: 0),
            receipt.terminationProgression == .natural,
            receipt.borrowedDescriptorOutcome == .closed,
            !receipt.output.overflowObserved,
            receipt.output.reachedEOF,
            !receipt.output.deadlineExpired
        else { return transportFailureExitStatus }
        return completedExitStatus
    }
}

protocol InvestigationMachineFixedGateLauncherSystem: AnyObject, Sendable {
    func perform(
        _ event: InvestigationMachineGateLauncherEvent
    ) throws -> InvestigationMachineGateLauncherResponse
    func forwardedSignal() -> Int32?
    func consumePendingForwardedSignal() throws -> Int32?
}

extension InvestigationMachineFixedGateLauncherSystem {
    func forwardedSignal() -> Int32? { nil }
    func consumePendingForwardedSignal() throws -> Int32? {
        forwardedSignal()
    }
}

struct InvestigationMachineFixedGateLauncher: Sendable {
    private let system: any InvestigationMachineFixedGateLauncherSystem

    init(system: any InvestigationMachineFixedGateLauncherSystem) {
        self.system = system
    }

    func run(
        inheritedCapsuleDescriptor: Int32
    ) throws -> InvestigationMachineFixedGateLauncherResult {
        guard inheritedCapsuleDescriptor == STDIN_FILENO else {
            throw InvestigationMachineGateError.invalidInvocation
        }
        let invocation = try invocation(system.perform(.validateInvocation))
        try InvestigationMachineGateInvocationValidator.validate(invocation)
        let started = try nanoseconds(system.perform(.observeStart))
        guard started > 0 else {
            throw InvestigationMachineGateError.invalidObservation
        }
        let launcherSHA256 = try sha256(
            system.perform(.observeLauncherExecutable)
        )
        let initialInput = try inputContext(
            system.perform(.observeInitialInput)
        )
        try initialInput.validate()
        let initialTerminal = try terminal(
            system.perform(.observeInitialTTY)
        )
        guard
            initialTerminal.foregroundProcessGroupID
                == invocation.foregroundProcessGroupID
        else {
            throw InvestigationMachineGateError.restorationUncertain
        }

        var state = LaunchState(
            inheritedCapsuleDescriptor: inheritedCapsuleDescriptor,
            recoveryProcessGroupID: invocation.processGroupID,
            savedForegroundProcessGroupID: invocation.foregroundProcessGroupID,
            initialTerminal: initialTerminal
        )
        do {
            let pair = try descriptorPair(system.perform(.makeOutputPipe))
            state.outputReadDescriptor = pair.read
            state.outputWriteDescriptor = pair.write

            let childProcessID: pid_t
            do {
                childProcessID = try processID(
                    system.perform(.spawnSuspendedChild)
                )
            } catch let error as InvestigationMachineGateSettledSpawnFailure {
                state.childProcessID = error.processID
                state.childProcessGroupID = error.processGroupID
                state.childReaped = error.childAlreadyReaped
                state.childGroupEmpty = error.childGroupEmpty
                state.gateJoinedCoordinatorGroup = error.childGroupEmpty
                throw InvestigationMachineGateError.containmentUncertain
            } catch let error as InvestigationMachineGateSpawnFailure {
                state.childProcessID = error.processID
                state.childProcessGroupID = error.processGroupID
                throw InvestigationMachineGateError.containmentUncertain
            }
            state.childProcessID = childProcessID
            state.childProcessGroupID = invocation.processGroupID
            try closeOutputWrite(&state)
            let observedGroup = try processGroupID(
                system.perform(.verifyChildProcessGroup)
            )
            guard observedGroup == invocation.processGroupID else {
                throw InvestigationMachineGateError.invalidChildProcessGroup
            }
            state.childProcessGroupID = observedGroup
            let childIdentity = try childIdentity(
                system.perform(.observeChildIdentity)
            )
            guard
                childIdentity.processID == childProcessID,
                childIdentity.parentProcessID == invocation.processID,
                childIdentity.processGroupID == observedGroup
            else {
                throw InvestigationMachineGateError.invalidChildProcessGroup
            }
            try completed(system.perform(.joinCoordinatorProcessGroup(
                invocation.foregroundProcessGroupID
            )))
            state.gateJoinedCoordinatorGroup = true
            try completed(system.perform(.verifyGateAndChildTopology))

            let prepared = try InvestigationMachineGatePreparedFrame(
                gateProcessID: invocation.processID,
                coordinatorProcessID: invocation.parentProcessID,
                sessionID: invocation.sessionID,
                childProcessID: childProcessID,
                recoveryProcessGroupID: observedGroup,
                savedForegroundProcessGroupID: invocation.foregroundProcessGroupID,
                childParentProcessID: childIdentity.parentProcessID,
                childSessionID: childIdentity.sessionID,
                childStartSeconds: childIdentity.startSeconds,
                childStartMicroseconds: childIdentity.startMicroseconds,
                initialStopStatus: 0x7f,
                outerAttemptUUID: initialInput.outerAttemptUUID,
                wholeInputSHA256: initialInput.expectedWholeInputSHA256,
                capsule: initialInput.capsule, terminal: initialTerminal,
                absoluteDeadlineNanoseconds: try addingDeadline(
                    started,
                    InvestigationMachineFixedGateContract.deadlineNanoseconds
                )
            ).encoded()
            try completed(system.perform(.writePreparedFrame(prepared)))
            try completed(system.perform(.stopGateForCoordinator))
            try completed(system.perform(.verifyGateAndChildTopology))
            try completed(system.perform(.verifyForegroundProcessGroup(
                invocation.foregroundProcessGroupID
            )))
            let transitionTerminal = try terminal(
                system.perform(.revalidateTransitionTTY)
            )
            guard transitionTerminal == initialTerminal else {
                throw InvestigationMachineGateError.restorationUncertain
            }
            if let signal = try system.consumePendingForwardedSignal() {
                throw InvestigationMachineGateError.forwardedSignal(signal)
            }

            try completed(system.perform(
                .setForegroundProcessGroup(observedGroup)
            ))
            state.childOwnedForeground = true
            try completed(system.perform(.continueChildGroup(observedGroup)))
            state.childContinued = true
            _ = try system.consumePendingForwardedSignal()
            let childTerminal = try terminal(
                system.perform(.observeChildTTY)
            )
            guard
                childTerminal.device == initialTerminal.device,
                childTerminal.inode == initialTerminal.inode,
                childTerminal.foregroundProcessGroupID == observedGroup
            else {
                throw InvestigationMachineGateError.restorationUncertain
            }

            var output = try output(system.perform(.drainOutput))
            let firstWait = try childState(
                system.perform(.observeWaitableChild)
            )
            let terminal = try retire(
                state: &state, firstObservation: firstWait
            )
            if !output.reachedEOF && !output.overflowObserved {
                output = try self.output(system.perform(.drainOutput))
            }
            guard output.reachedEOF || output.overflowObserved else {
                throw InvestigationMachineGateError.containmentUncertain
            }
            let finalInput = try input(
                system.perform(.observeFinalInput)
            )
            guard
                finalInput.node == initialInput.capsule,
                finalInput.initialOffset == initialInput.initialOffset,
                finalInput.finalOffset == initialInput.capsule.size,
                finalInput.reachedEOF,
                finalInput.sha256 == initialInput.expectedWholeInputSHA256
            else {
                throw InvestigationMachineGateError.containmentUncertain
            }
            _ = try system.consumePendingForwardedSignal()

            try closeOutputRead(&state)
            try closeBorrowedInput(&state)
            let completedAt = try nanoseconds(
                system.perform(.observeCompletion)
            )
            guard
                completedAt >= started,
                completedAt - started
                    <= InvestigationMachineFixedGateContract.deadlineNanoseconds
            else {
                throw InvestigationMachineGateError.containmentUncertain
            }

            let receipt = try InvestigationMachineGateTransportReceipt(
                launcherExecutableSHA256: launcherSHA256,
                outerAttemptUUID: initialInput.outerAttemptUUID,
                wholeInputSHA256: initialInput.expectedWholeInputSHA256,
                preparedFrameSHA256: .hashing(prepared),
                capsule: initialInput.capsule,
                gateProcessID: invocation.processID,
                coordinatorProcessID: invocation.parentProcessID,
                sessionID: invocation.sessionID,
                recoveryProcessGroupID: observedGroup,
                savedForegroundProcessGroupID:
                    invocation.foregroundProcessGroupID,
                childIdentity: childIdentity,
                input: finalInput,
                initialTerminal: initialTerminal,
                childTerminal: childTerminal,
                finalTerminal: terminal.finalTerminal,
                output: output,
                waitClassification: terminal.waitClassification,
                forwardedSignal: system.forwardedSignal(),
                monotonicStartedNanoseconds: started,
                monotonicCompletedNanoseconds: completedAt,
                terminationProgression: terminal.progression,
                childProcessGroupEmpty: true,
                exactChildReaped: true,
                savedForegroundProcessGroupRestored: true,
                borrowedDescriptorOutcome: .closed
            )
            try completed(system.perform(
                .writeTerminalReceipt(try receipt.encoded())
            ))
            state.terminalReceiptWritten = true
            state.terminalOutputClosed = true
            return .init(receipt: receipt)
        } catch {
            let failure = error
            let cleanup = cleanupAfterFailure(state: &state)
            if cleanup.restorationUncertain {
                throw InvestigationMachineGateError.restorationUncertain
            }
            if cleanup.containmentUncertain {
                throw InvestigationMachineGateError.containmentUncertain
            }
            if cleanup.borrowedDescriptorCloseUncertain {
                throw InvestigationMachineGateError.containmentUncertain
            }
            throw failure
        }
    }

    private func retire(
        state: inout LaunchState, firstObservation: ChildState
    ) throws -> TerminalEvidence {
        guard let group = state.childProcessGroupID else {
            throw InvestigationMachineGateError.containmentUncertain
        }
        var observation = firstObservation
        var progression = InvestigationMachineGateTerminationProgression.natural

        if case .stopped = observation {
            try restoreForeground(&state)
            try completed(system.perform(.sendTermToChildGroup(group)))
            progression = .term
            try completed(system.perform(.continueChildGroup(group)))
            state.childContinued = true
            observation = try childState(
                system.perform(.waitForTerminationGrace)
            )
        } else if case .running = observation {
            try restoreForeground(&state)
            try completed(system.perform(.sendTermToChildGroup(group)))
            progression = .term
            try completed(system.perform(.continueChildGroup(group)))
            state.childContinued = true
            observation = try childState(
                system.perform(.waitForTerminationGrace)
            )
        } else {
            try restoreForeground(&state)
        }

        var groupIsLeaderOnly = try leaderOnly(
            system.perform(.observeLeaderOnlyChildGroup)
        )
        if !groupIsLeaderOnly && progression == .natural {
            try completed(system.perform(.sendTermToChildGroup(group)))
            progression = .term
            try completed(system.perform(.continueChildGroup(group)))
            state.childContinued = true
            observation = try childState(
                system.perform(.waitForTerminationGrace)
            )
            groupIsLeaderOnly = try leaderOnly(
                system.perform(.observeLeaderOnlyChildGroup)
            )
        }

        if case .running = observation {
            try completed(system.perform(.sendKillToChildGroup(group)))
            progression = .termThenKill
            observation = try childState(
                system.perform(.observeWaitableChild)
            )
            groupIsLeaderOnly = try leaderOnly(
                system.perform(.observeLeaderOnlyChildGroup)
            )
        } else if !groupIsLeaderOnly {
            try completed(system.perform(.sendKillToChildGroup(group)))
            progression = .termThenKill
            observation = try childState(
                system.perform(.observeWaitableChild)
            )
            groupIsLeaderOnly = try leaderOnly(
                system.perform(.observeLeaderOnlyChildGroup)
            )
        }
        guard
            case .terminal(let waitClassification) = observation,
            groupIsLeaderOnly
        else {
            throw InvestigationMachineGateError.containmentUncertain
        }
        try completed(system.perform(.reapExactChild))
        state.childReaped = true
        try completed(system.perform(.observeEmptyChildGroup))
        state.childGroupEmpty = true
        let finalTerminal = try revalidateRestoredForeground(&state)
        return .init(
            waitClassification: waitClassification, progression: progression,
            finalTerminal: finalTerminal
        )
    }

    private func restoreForeground(_ state: inout LaunchState) throws {
        try completed(system.perform(.setForegroundProcessGroup(
            state.savedForegroundProcessGroupID
        )))
        state.childOwnedForeground = false
        try completed(system.perform(.verifyForegroundProcessGroup(
            state.savedForegroundProcessGroupID
        )))
        state.foregroundRestored = true
    }

    private func revalidateRestoredForeground(
        _ state: inout LaunchState
    ) throws -> InvestigationMachineGateTerminalObservation {
        // Re-assert the exact saved group after reap even when an earlier
        // retirement step restored it. The cached flag is evidence of an
        // earlier transition, not authority to skip the terminal proof.
        try restoreForeground(&state)
        let value = try terminal(system.perform(.revalidateFinalTTY))
        guard value == state.initialTerminal else {
            throw InvestigationMachineGateError.restorationUncertain
        }
        state.terminalRevalidated = true
        return value
    }

    private func closeOutputRead(_ state: inout LaunchState) throws {
        guard let descriptor = state.outputReadDescriptor else { return }
        state.outputReadDescriptor = nil
        try completed(system.perform(.closeOutputDescriptor(descriptor)))
    }

    private func closeOutputWrite(_ state: inout LaunchState) throws {
        guard let descriptor = state.outputWriteDescriptor else { return }
        state.outputWriteDescriptor = nil
        try completed(system.perform(.closeOutputDescriptor(descriptor)))
    }

    private func closeBorrowedInput(_ state: inout LaunchState) throws {
        guard !state.borrowedInputCloseAttempted else {
            if !state.borrowedInputClosed {
                throw InvestigationMachineGateError.containmentUncertain
            }
            return
        }
        state.borrowedInputCloseAttempted = true
        try completed(system.perform(.closeBorrowedDescriptor(
            state.inheritedCapsuleDescriptor
        )))
        state.borrowedInputClosed = true
    }

    private func cleanupAfterFailure(
        state: inout LaunchState
    ) -> CleanupOutcome {
        var outcome = CleanupOutcome()
        // Before the gate joins C, -G includes the gate itself. Delegate that
        // phase to exact-PID settlement; only post-join cleanup may signal G.
        if state.childProcessID != nil, !state.childReaped,
            !state.gateJoinedCoordinatorGroup
        {
            do {
                try completed(system.perform(.settleChildBeforeCoordinatorJoin))
                state.childReaped = true
                state.childGroupEmpty = true
                state.gateJoinedCoordinatorGroup = true
            } catch {
                outcome.containmentUncertain = true
            }
        }
        if state.childOwnedForeground || !state.foregroundRestored {
            do { _ = try revalidateRestoredForeground(&state) }
            catch { outcome.restorationUncertain = true }
        }
        do { try closeOutputWrite(&state) }
        catch { outcome.containmentUncertain = true }
        if let group = state.childProcessGroupID, !state.childReaped,
            state.gateJoinedCoordinatorGroup
        {
            var terminalObserved = false
            var stoppedObserved = false
            do {
                let observed = try childState(
                    system.perform(.observeWaitableChild)
                )
                if case .terminal = observed { terminalObserved = true }
                if case .stopped = observed { stoppedObserved = true }
            } catch {
                outcome.containmentUncertain = true
            }
            var leaderOnlyObserved = false
            do {
                leaderOnlyObserved = try leaderOnly(
                    system.perform(.observeLeaderOnlyChildGroup)
                )
            } catch {
                outcome.containmentUncertain = true
            }
            if !terminalObserved || !leaderOnlyObserved {
                do {
                    try completed(system.perform(.sendTermToChildGroup(group)))
                    try completed(system.perform(.continueChildGroup(group)))
                    state.childContinued = true
                } catch {
                    outcome.containmentUncertain = true
                }
            }
            if terminalObserved && stoppedObserved {
                do {
                    try completed(system.perform(.continueChildGroup(group)))
                } catch {
                    outcome.containmentUncertain = true
                }
            }
            if !terminalObserved || !leaderOnlyObserved {
                do {
                    let grace = try childState(
                        system.perform(.waitForTerminationGrace)
                    )
                    if case .terminal = grace { terminalObserved = true }
                    leaderOnlyObserved = try leaderOnly(
                        system.perform(.observeLeaderOnlyChildGroup)
                    )
                } catch {
                    outcome.containmentUncertain = true
                }
            }
            if !terminalObserved || !leaderOnlyObserved {
                do {
                    try completed(system.perform(.sendKillToChildGroup(group)))
                } catch {
                    outcome.containmentUncertain = true
                }
                do {
                    let terminal = try childState(
                        system.perform(.observeWaitableChild)
                    )
                    guard case .terminal = terminal else {
                        throw InvestigationMachineGateError
                            .containmentUncertain
                    }
                    terminalObserved = true
                    leaderOnlyObserved = try leaderOnly(
                        system.perform(.observeLeaderOnlyChildGroup)
                    )
                } catch {
                    outcome.containmentUncertain = true
                }
            }
            if terminalObserved && leaderOnlyObserved {
                do {
                    try completed(system.perform(.reapExactChild))
                    state.childReaped = true
                } catch {
                    outcome.containmentUncertain = true
                }
                do {
                    try completed(system.perform(.observeEmptyChildGroup))
                    state.childGroupEmpty = true
                } catch {
                    outcome.containmentUncertain = true
                }
            }
        }
        // Retirement can race terminal ownership changes. Always repeat the
        // exact restore + verify + FD-2 observation after every possible reap;
        // any failure remains the dominant cleanup result.
        do { _ = try revalidateRestoredForeground(&state) }
        catch { outcome.restorationUncertain = true }
        do { try closeOutputRead(&state) }
        catch { outcome.containmentUncertain = true }
        if state.borrowedInputCloseAttempted && !state.borrowedInputClosed {
            outcome.borrowedDescriptorCloseUncertain = true
        } else {
            do { try closeBorrowedInput(&state) }
            catch { outcome.borrowedDescriptorCloseUncertain = true }
        }
        if !state.terminalOutputClosed {
            do {
                try completed(system.perform(
                    .closeOutputDescriptor(STDOUT_FILENO)
                ))
                state.terminalOutputClosed = true
            } catch {
                outcome.containmentUncertain = true
            }
        }
        return outcome
    }
}

private extension InvestigationMachineFixedGateLauncher {
    enum ChildState {
        case running
        case stopped(Int32)
        case terminal(InvestigationMachineGateWaitClassification)
    }

    struct TerminalEvidence {
        let waitClassification: InvestigationMachineGateWaitClassification
        let progression: InvestigationMachineGateTerminationProgression
        let finalTerminal: InvestigationMachineGateTerminalObservation
    }

    struct LaunchState {
        let inheritedCapsuleDescriptor: Int32
        let recoveryProcessGroupID: pid_t
        let savedForegroundProcessGroupID: pid_t
        let initialTerminal: InvestigationMachineGateTerminalObservation
        var outputReadDescriptor: Int32?
        var outputWriteDescriptor: Int32?
        var childProcessID: pid_t?
        var childProcessGroupID: pid_t?
        var childOwnedForeground = false
        var childContinued = false
        var foregroundRestored = false
        var terminalRevalidated = false
        var childReaped = false
        var childGroupEmpty = false
        var gateJoinedCoordinatorGroup = false
        var borrowedInputCloseAttempted = false
        var borrowedInputClosed = false
        var terminalReceiptWritten = false
        var terminalOutputClosed = false
    }

    struct CleanupOutcome {
        var restorationUncertain = false
        var containmentUncertain = false
        var borrowedDescriptorCloseUncertain = false
    }

    func invocation(_ value: InvestigationMachineGateLauncherResponse) throws
        -> InvestigationMachineGateInvocationObservation
    {
        guard case .invocation(let result) = value else { throw unexpected() }
        return result
    }

    func nanoseconds(_ value: InvestigationMachineGateLauncherResponse) throws
        -> UInt64
    {
        guard case .nanoseconds(let result) = value else { throw unexpected() }
        return result
    }

    func sha256(_ value: InvestigationMachineGateLauncherResponse) throws
        -> InvestigationHandoffSHA256
    {
        guard case .sha256(let result) = value else { throw unexpected() }
        return result
    }

    func inputContext(
        _ value: InvestigationMachineGateLauncherResponse
    ) throws -> InvestigationMachineGateInputContext {
        guard case .inputContext(let result) = value else { throw unexpected() }
        return result
    }

    func terminal(_ value: InvestigationMachineGateLauncherResponse) throws
        -> InvestigationMachineGateTerminalObservation
    {
        guard case .terminal(let result) = value else { throw unexpected() }
        return result
    }

    func descriptorPair(
        _ value: InvestigationMachineGateLauncherResponse
    ) throws -> (read: Int32, write: Int32) {
        guard case .descriptorPair(let read, let write) = value,
              read > STDERR_FILENO, write > STDERR_FILENO, read != write
        else { throw unexpected() }
        return (read, write)
    }

    func processID(_ value: InvestigationMachineGateLauncherResponse) throws
        -> pid_t
    {
        guard case .processID(let result) = value, result > 1 else {
            throw InvestigationMachineGateError.containmentUncertain
        }
        return result
    }

    func processGroupID(
        _ value: InvestigationMachineGateLauncherResponse
    ) throws -> pid_t {
        guard case .processGroupID(let result) = value, result > 1 else {
            throw InvestigationMachineGateError.containmentUncertain
        }
        return result
    }

    func childIdentity(
        _ value: InvestigationMachineGateLauncherResponse
    ) throws -> InvestigationMachineGateChildIdentity {
        guard case .childIdentity(let result) = value else {
            throw unexpected()
        }
        return result
    }

    func output(_ value: InvestigationMachineGateLauncherResponse) throws
        -> InvestigationMachineGateOutputObservation
    {
        guard case .output(let result) = value else { throw unexpected() }
        return result
    }

    func childState(_ value: InvestigationMachineGateLauncherResponse) throws
        -> ChildState
    {
        switch value {
        case .childRunning:
            return .running
        case .waitClassification(.stopped(let signal)):
            return .stopped(signal)
        case .waitClassification(let result):
            return .terminal(result)
        default:
            throw unexpected()
        }
    }

    func input(_ value: InvestigationMachineGateLauncherResponse) throws
        -> InvestigationMachineGateInputObservation
    {
        guard case .input(let result) = value else { throw unexpected() }
        return result
    }

    func completed(_ value: InvestigationMachineGateLauncherResponse) throws {
        guard case .completed = value else { throw unexpected() }
    }

    func leaderOnly(
        _ value: InvestigationMachineGateLauncherResponse
    ) throws -> Bool {
        switch value {
        case .completed: true
        case .childGroupActive: false
        default: throw unexpected()
        }
    }

    func unexpected() -> InvestigationMachineGateError { .unexpectedResponse }

    func addingDeadline(_ value: UInt64, _ delta: UInt64) throws -> UInt64 {
        let result = value.addingReportingOverflow(delta)
        guard !result.overflow else {
            throw InvestigationMachineGateError.containmentUncertain
        }
        return result.partialValue
    }
}
