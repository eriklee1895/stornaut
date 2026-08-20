import Foundation
import StornautLifecycle

public struct InvestigationMachineClaimServerObservation:
    Sendable,
    Equatable
{
    public let continuousNanoseconds: UInt64
    public let wallUTCMicroseconds: Int64

    public init(
        continuousNanoseconds: UInt64,
        wallUTCMicroseconds: Int64
    ) throws {
        guard continuousNanoseconds > 0, wallUTCMicroseconds > 0 else {
            throw InvestigationMachineClaimServerPublicValueError.invalidValue
        }
        self.continuousNanoseconds = continuousNanoseconds
        self.wallUTCMicroseconds = wallUTCMicroseconds
    }
}

public struct InvestigationMachineClaimServerDeadline:
    Sendable,
    Equatable
{
    public let deadlineNanoseconds: UInt64

    public init(deadlineNanoseconds: UInt64) throws {
        guard deadlineNanoseconds > 0 else {
            throw InvestigationMachineClaimServerPublicValueError.invalidValue
        }
        self.deadlineNanoseconds = deadlineNanoseconds
    }
}

public protocol InvestigationMachineClaimServerClock: Sendable {
    func observation() throws -> InvestigationMachineClaimServerObservation
}

public protocol InvestigationMachineClaimServerScheduledHandle: Sendable {
    func cancel()
}

public protocol InvestigationMachineClaimServerScheduling: Sendable {
    func schedule(
        deadline: InvestigationMachineClaimServerDeadline,
        callback: @escaping @Sendable () -> Void
    ) throws -> any InvestigationMachineClaimServerScheduledHandle
}

public enum InvestigationMachineClaimServerTerminalReason:
    Sendable,
    Equatable
{
    case claimDeadlineExpired
    case releaseDeadlineExpired
    case postReplyExitDue
    case cancelled
    case connectionInvalidated
    case bindingMismatch
    case duplicateOrReplay
    case invalidTimeObservation
    case arithmeticOverflow
    case deadlineArmFailure
    case schedulerFiredEarly
    case replyDispatchFailed
    case postReplyDeadlineExpiredBeforeDispatch
}

public protocol InvestigationMachineClaimServerTerminalHandling: Sendable {
    func handle(_ reason: InvestigationMachineClaimServerTerminalReason)
}

private enum InvestigationMachineClaimServerPublicValueError: Error {
    case invalidValue
}

package protocol InvestigationMachineClaimServerCoreClock: Sendable {
    func observation() throws
        -> LifecycleMachineRetirementDeadlineObservation
}

package protocol InvestigationMachineClaimServerCoreScheduledHandle:
    Sendable
{
    func cancel()
}

package protocol InvestigationMachineClaimServerCoreScheduling: Sendable {
    func schedule(
        ticket: LifecycleMachineRetirementDeadlineTicket,
        callback: @escaping @Sendable () -> Void
    ) throws -> any InvestigationMachineClaimServerCoreScheduledHandle
}

package protocol InvestigationMachineClaimServerCoreTerminalHandling:
    Sendable
{
    func handle(_ reason: LifecycleMachineRetirementDeadlineTerminalReason)
}

package struct InvestigationMachineClaimServerRuntime: Sendable {
    let clock: any InvestigationMachineClaimServerCoreClock
    let scheduler: any InvestigationMachineClaimServerCoreScheduling
    let terminal: any InvestigationMachineClaimServerCoreTerminalHandling
    let terminalGate: InvestigationMachineClaimServerTerminalGate

    package init(
        clock: any InvestigationMachineClaimServerClock,
        scheduler: any InvestigationMachineClaimServerScheduling,
        terminal: any InvestigationMachineClaimServerTerminalHandling
    ) {
        let terminalGate = InvestigationMachineClaimServerTerminalGate(
            destination: terminal
        )
        self.clock = InvestigationMachineClaimServerClockBridge(clock)
        self.scheduler = InvestigationMachineClaimServerSchedulerBridge(
            scheduler
        )
        self.terminal = InvestigationMachineClaimServerTerminalBridge(
            terminalGate
        )
        self.terminalGate = terminalGate
    }
}

package final class InvestigationMachineClaimServerTerminalGate:
    InvestigationMachineClaimServerTerminalHandling,
    @unchecked Sendable
{
    private let destination: any InvestigationMachineClaimServerTerminalHandling
    private let lock = NSLock()
    private var delivered = false

    init(destination: any InvestigationMachineClaimServerTerminalHandling) {
        self.destination = destination
    }

    package func handle(
        _ reason: InvestigationMachineClaimServerTerminalReason
    ) {
        let shouldDeliver = lock.withLock {
            guard !delivered else { return false }
            delivered = true
            return true
        }
        if shouldDeliver { destination.handle(reason) }
    }
}

private struct InvestigationMachineClaimServerClockBridge:
    InvestigationMachineClaimServerCoreClock
{
    let source: any InvestigationMachineClaimServerClock

    init(_ source: any InvestigationMachineClaimServerClock) {
        self.source = source
    }

    func observation() throws
        -> LifecycleMachineRetirementDeadlineObservation
    {
        let value = try source.observation()
        return try LifecycleMachineRetirementDeadlineObservation(
            monotonicNanoseconds: value.continuousNanoseconds,
            wallUTCMicroseconds: value.wallUTCMicroseconds
        )
    }
}

private struct InvestigationMachineClaimServerSchedulerBridge:
    InvestigationMachineClaimServerCoreScheduling
{
    let source: any InvestigationMachineClaimServerScheduling

    init(_ source: any InvestigationMachineClaimServerScheduling) {
        self.source = source
    }

    func schedule(
        ticket: LifecycleMachineRetirementDeadlineTicket,
        callback: @escaping @Sendable () -> Void
    ) throws -> any InvestigationMachineClaimServerCoreScheduledHandle {
        let handle = try source.schedule(
            deadline: InvestigationMachineClaimServerDeadline(
                deadlineNanoseconds: ticket.deadlineNanoseconds
            ),
            callback: callback
        )
        return InvestigationMachineClaimServerScheduledHandleBridge(handle)
    }
}

private struct InvestigationMachineClaimServerScheduledHandleBridge:
    InvestigationMachineClaimServerCoreScheduledHandle
{
    let source: any InvestigationMachineClaimServerScheduledHandle

    init(_ source: any InvestigationMachineClaimServerScheduledHandle) {
        self.source = source
    }

    func cancel() { source.cancel() }
}

private struct InvestigationMachineClaimServerTerminalBridge:
    InvestigationMachineClaimServerCoreTerminalHandling
{
    let destination: any InvestigationMachineClaimServerTerminalHandling

    init(_ destination: any InvestigationMachineClaimServerTerminalHandling) {
        self.destination = destination
    }

    func handle(_ reason: LifecycleMachineRetirementDeadlineTerminalReason) {
        destination.handle(InvestigationMachineClaimServerTerminalReason(reason))
    }
}

private extension InvestigationMachineClaimServerTerminalReason {
    init(_ reason: LifecycleMachineRetirementDeadlineTerminalReason) {
        self = switch reason {
        case .claimDeadlineExpired: .claimDeadlineExpired
        case .releaseDeadlineExpired: .releaseDeadlineExpired
        case .postReplyExitDue: .postReplyExitDue
        case .cancelled: .cancelled
        case .connectionInvalidated: .connectionInvalidated
        case .bindingMismatch: .bindingMismatch
        case .duplicateOrReplay: .duplicateOrReplay
        case .invalidTimeObservation: .invalidTimeObservation
        case .arithmeticOverflow: .arithmeticOverflow
        case .deadlineArmFailure: .deadlineArmFailure
        case .schedulerFiredEarly: .schedulerFiredEarly
        case .replyDispatchFailed: .replyDispatchFailed
        case .postReplyDeadlineExpiredBeforeDispatch:
            .postReplyDeadlineExpiredBeforeDispatch
        }
    }
}

package enum InvestigationMachineClaimServerEffectError: Error, Sendable {
    case scheduleFailed
}

package final class InvestigationMachineClaimServerEffectExecutor:
    @unchecked Sendable
{
    private final class Slot: @unchecked Sendable {
        struct Action {
            let handleToCancel:
                (any InvestigationMachineClaimServerCoreScheduledHandle)?
            let removeSlot: Bool
        }

        private let lock = NSLock()
        private var handle:
            (any InvestigationMachineClaimServerCoreScheduledHandle)?
        private var cancelRequested = false
        private var cancelApplied = false
        private var callbackFinished = false

        func install(
            _ handle: any InvestigationMachineClaimServerCoreScheduledHandle
        ) -> Action {
            lock.withLock {
                self.handle = handle
                let handleToCancel: (any
                    InvestigationMachineClaimServerCoreScheduledHandle)?
                if cancelRequested, !cancelApplied {
                    cancelApplied = true
                    handleToCancel = handle
                } else {
                    handleToCancel = nil
                }
                return Action(
                    handleToCancel: handleToCancel,
                    removeSlot: callbackFinished || cancelRequested
                )
            }
        }

        func cancel() -> Action {
            lock.withLock {
                cancelRequested = true
                let handleToCancel: (any
                    InvestigationMachineClaimServerCoreScheduledHandle)?
                if !cancelApplied, let handle {
                    cancelApplied = true
                    handleToCancel = handle
                } else {
                    handleToCancel = nil
                }
                return Action(
                    handleToCancel: handleToCancel,
                    removeSlot: handle != nil
                )
            }
        }

        func finishCallback() -> Action {
            lock.withLock {
                callbackFinished = true
                guard handle == nil else {
                    return Action(handleToCancel: nil, removeSlot: true)
                }
                cancelRequested = true
                return Action(handleToCancel: nil, removeSlot: false)
            }
        }
    }

    private let clock: any InvestigationMachineClaimServerCoreClock
    private let scheduler: any InvestigationMachineClaimServerCoreScheduling
    private let terminal: any InvestigationMachineClaimServerCoreTerminalHandling
    private let lock = NSLock()
    private var slots: [LifecycleMachineRetirementDeadlineTicket: Slot] = [:]
    private var terminalDelivered = false

    package init(
        clock: any InvestigationMachineClaimServerCoreClock,
        scheduler: any InvestigationMachineClaimServerCoreScheduling,
        terminal: any InvestigationMachineClaimServerCoreTerminalHandling
    ) {
        self.clock = clock
        self.scheduler = scheduler
        self.terminal = terminal
    }

    package var pendingSlotCount: Int {
        lock.withLock { slots.count }
    }

    package func apply(
        _ transition: LifecycleMachineRetirementDeadlineTransition,
        to state: LifecycleMachineRetirementEscrowDeadlineState
    ) throws {
        for effect in transition.effects {
            switch effect {
            case let .cancel(ticket):
                cancel(ticket)
            case let .schedule(ticket):
                try schedule(ticket, state: state)
            }
        }
        deliverTerminalIfNeeded(transition)
    }

    private func schedule(
        _ ticket: LifecycleMachineRetirementDeadlineTicket,
        state: LifecycleMachineRetirementEscrowDeadlineState
    ) throws {
        let slot = Slot()
        lock.withLock { slots[ticket] = slot }
        let handle: (any InvestigationMachineClaimServerCoreScheduledHandle)
        do {
            handle = try scheduler.schedule(ticket: ticket) {
                [weak self, weak state] in
                guard let self, let state else { return }
                defer { finishCallback(ticket) }
                let transition: LifecycleMachineRetirementDeadlineTransition
                do {
                    transition = state.deadlineFired(
                        ticket,
                        observation: try clock.observation()
                    )
                } catch {
                    transition = state.rejectObservation(ticket: ticket)
                }
                try? apply(transition, to: state)
            }
        } catch {
            remove(ticket)
            let failed = state.armFailed(ticket)
            try? apply(failed, to: state)
            throw InvestigationMachineClaimServerEffectError.scheduleFailed
        }
        let armed = state.armSucceeded(ticket)
        try apply(armed, to: state)
        perform(slot.install(handle), ticket: ticket)
    }

    private func cancel(_ ticket: LifecycleMachineRetirementDeadlineTicket) {
        guard let slot = lock.withLock({ slots[ticket] }) else { return }
        perform(slot.cancel(), ticket: ticket)
    }

    private func finishCallback(
        _ ticket: LifecycleMachineRetirementDeadlineTicket
    ) {
        guard let slot = lock.withLock({ slots[ticket] }) else { return }
        perform(slot.finishCallback(), ticket: ticket)
    }

    private func perform(
        _ action: Slot.Action,
        ticket: LifecycleMachineRetirementDeadlineTicket
    ) {
        action.handleToCancel?.cancel()
        if action.removeSlot { remove(ticket) }
    }

    private func remove(_ ticket: LifecycleMachineRetirementDeadlineTicket) {
        _ = lock.withLock { slots.removeValue(forKey: ticket) }
    }

    private func deliverTerminalIfNeeded(
        _ transition: LifecycleMachineRetirementDeadlineTransition
    ) {
        guard case let .terminal(reason) = transition.disposition else {
            return
        }
        let shouldDeliver = lock.withLock {
            guard !terminalDelivered else { return false }
            terminalDelivered = true
            return true
        }
        if shouldDeliver { terminal.handle(reason) }
    }
}
