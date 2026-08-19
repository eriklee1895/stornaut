import Foundation
import StornautLifecycle

package protocol InvestigationMachineClaimServerClock: Sendable {
    func observation() throws
        -> LifecycleMachineRetirementDeadlineObservation
}

package protocol InvestigationMachineClaimServerScheduledHandle:
    Sendable
{
    func cancel()
}

package protocol InvestigationMachineClaimServerScheduling: Sendable {
    func schedule(
        ticket: LifecycleMachineRetirementDeadlineTicket,
        callback: @escaping @Sendable () -> Void
    ) throws -> any InvestigationMachineClaimServerScheduledHandle
}

package protocol InvestigationMachineClaimServerTerminalHandling:
    Sendable
{
    func handle(_ reason: LifecycleMachineRetirementDeadlineTerminalReason)
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
                (any InvestigationMachineClaimServerScheduledHandle)?
            let removeSlot: Bool
        }

        private let lock = NSLock()
        private var handle:
            (any InvestigationMachineClaimServerScheduledHandle)?
        private var cancelRequested = false
        private var cancelApplied = false
        private var callbackFinished = false

        func install(
            _ handle: any InvestigationMachineClaimServerScheduledHandle
        ) -> Action {
            lock.withLock {
                self.handle = handle
                let handleToCancel: (any
                    InvestigationMachineClaimServerScheduledHandle)?
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
                    InvestigationMachineClaimServerScheduledHandle)?
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

    private let clock: any InvestigationMachineClaimServerClock
    private let scheduler: any InvestigationMachineClaimServerScheduling
    private let terminal: any InvestigationMachineClaimServerTerminalHandling
    private let lock = NSLock()
    private var slots: [LifecycleMachineRetirementDeadlineTicket: Slot] = [:]
    private var terminalDelivered = false

    package init(
        clock: any InvestigationMachineClaimServerClock,
        scheduler: any InvestigationMachineClaimServerScheduling,
        terminal: any InvestigationMachineClaimServerTerminalHandling
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
        let handle: (any InvestigationMachineClaimServerScheduledHandle)
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
