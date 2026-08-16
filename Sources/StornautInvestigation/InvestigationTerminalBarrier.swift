import StornautCore

package enum InvestigationTerminalBarrierPhase:
    Sendable,
    Equatable
{
    case awaitingTerminalEvents
    case drainingLifecycle
    case terminalPersistence
    case rollbackCleanup
    case rollbackUnconfirmed
}

package struct InvestigationTerminalBarrier: Sendable {
    package let t0Nanoseconds: UInt64
    private var interruptedTurns = Set<InvestigationRuntimeTurnIdentityV1>()

    package init(t0Nanoseconds: UInt64) {
        self.t0Nanoseconds = t0Nanoseconds
    }

    package func phase(
        atNanoseconds current: UInt64
    ) -> InvestigationTerminalBarrierPhase {
        let elapsed = current >= t0Nanoseconds
            ? current - t0Nanoseconds
            : 0
        switch elapsed {
        case 0..<15_000_000_000:
            return .awaitingTerminalEvents
        case 15_000_000_000..<45_000_000_000:
            return .drainingLifecycle
        case 45_000_000_000..<135_000_000_000:
            return .terminalPersistence
        case 135_000_000_000..<140_000_000_000:
            return .rollbackCleanup
        default:
            return .rollbackUnconfirmed
        }
    }

    package mutating func interruptsNeeded(
        for activeTurns: [InvestigationRuntimeTurnIdentityV1]
    ) -> [InvestigationRuntimeTurnIdentityV1] {
        var result: [InvestigationRuntimeTurnIdentityV1] = []
        for turn in activeTurns where interruptedTurns.insert(turn).inserted {
            result.append(turn)
        }
        return result
    }
}

package enum InvestigationTerminalSettlementResult:
    Sendable,
    Equatable
{
    case completed
    case partial(InvestigationTerminalCause)
    case blocked(InvestigationBlockReason)
    case failed(InvestigationFailureReason)
}

package enum InvestigationTerminalSettlement {
    package static func classify(
        cause: InvestigationTerminalCause,
        allTurnsTerminal: Bool,
        lifecycleProvedEmpty: Bool,
        artifactsRetired: Bool,
        storeCommitted: Bool
    ) -> InvestigationTerminalSettlementResult {
        guard allTurnsTerminal else {
            return .blocked(.runtimeTerminalUnobserved)
        }
        guard lifecycleProvedEmpty else {
            return .blocked(.lifecycleDrainUnconfirmed)
        }
        guard artifactsRetired, storeCommitted else {
            return .failed(.terminalPersistenceFailed)
        }
        switch cause {
        case .userCancelled, .userStopped, .paused:
            return .partial(cause)
        case .coverageReached,
             .remainingUnknownBelowThreshold,
             .budgetExhausted,
             .noEvidenceGain:
            return .completed
        case .containmentLost:
            return .blocked(.containmentLost)
        case .lifecycleLost:
            return .blocked(.lifecycleLost)
        case .runtimeIdentityLost:
            return .blocked(.runtimeIdentityLost)
        case .protocolLost:
            return .blocked(.protocolLost)
        case .runtimeTerminalUnobserved:
            return .blocked(.runtimeTerminalUnobserved)
        case .lifecycleDrainUnconfirmed:
            return .blocked(.lifecycleDrainUnconfirmed)
        case .terminalPersistenceFailed:
            return .failed(.terminalPersistenceFailed)
        }
    }
}
