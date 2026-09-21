import Foundation

public enum InvestigationStage:
    String,
    Codable,
    Sendable,
    Equatable,
    CaseIterable
{
    case prioritize = "prioritize"
    case identify = "identify"
    case verify = "verify"
    case buildPlan = "buildPlan"
}

public enum InvestigationBlockReason:
    String,
    Sendable,
    Equatable,
    CaseIterable
{
    case containmentLost = "containment-lost-v1"
    case lifecycleLost = "lifecycle-lost-v1"
    case runtimeIdentityLost = "runtime-identity-lost-v1"
    case protocolLost = "protocol-lost-v1"
    case runtimeTerminalUnobserved = "runtime-terminal-unobserved-v1"
    case lifecycleDrainUnconfirmed = "lifecycle-drain-unconfirmed-v1"
}

public typealias InvestigationSafetyLoss = InvestigationBlockReason

public enum InvestigationBudgetDimension:
    String,
    Sendable,
    Equatable
{
    case wallClock = "wall-clock-v1"
    case coordinatorTurns = "coordinator-turns-v1"
    case probeCalls = "probe-calls-v1"
    case probeReadBytes = "probe-read-bytes-v1"
    case probeOutputBytes = "probe-output-bytes-v1"
    case cumulativeContextBytes = "cumulative-context-bytes-v1"
    case concurrentProbes = "concurrent-probes-v1"
    case consecutiveNoGainSteps = "consecutive-no-gain-steps-v1"
    case observedDirectToolStarts = "observed-direct-tool-starts-v1"
    case observedTotalTokens = "observed-total-tokens-v1"
}

public enum InvestigationBudgetEnforcement:
    String,
    Sendable,
    Equatable
{
    case hardAdmission = "hard-admission-v1"
    case eventTimeObserved = "event-time-observed-v1"
}

public struct InvestigationBudgetExhaustion:
    Sendable,
    Equatable
{
    public let dimension: InvestigationBudgetDimension
    public let enforcement: InvestigationBudgetEnforcement

    public init(
        dimension: InvestigationBudgetDimension,
        enforcement: InvestigationBudgetEnforcement
    ) {
        self.dimension = dimension
        self.enforcement = enforcement
    }
}

public enum InvestigationRemainingUnknown: Sendable, Equatable {
    case measured(ByteCount)
    case unmeasurable
}

public enum InvestigationStopReason: Sendable, Equatable {
    case coverageReached
    case remainingUnknownBelowThreshold
    case budgetExhausted(InvestigationBudgetExhaustion)
    case noEvidenceGain
    case userStopped
    case userCancelled
}

public enum InvestigationFailureReason:
    String,
    Sendable,
    Equatable
{
    case terminalPersistenceFailed = "terminal-persistence-failed-v1"
}

public enum InvestigationStopEvaluation: Sendable, Equatable {
    case blocked(InvestigationSafetyLoss)
    case failed(InvestigationFailureReason)
    case stop(InvestigationStopReason)
    case pause
    case continueInvestigation
}

public enum InvestigationStopFactsError: Error, Sendable, Equatable {
    case invalidFacts
}

public struct InvestigationStopFacts: Sendable, Equatable {
    public let safetyLoss: InvestigationSafetyLoss?
    public let failureReason: InvestigationFailureReason?
    public let userCancellationRequested: Bool
    public let userStopRequested: Bool
    public let hardBudgetExhaustion: InvestigationBudgetExhaustion?
    public let observedBudgetExhaustion: InvestigationBudgetExhaustion?
    public let coveragePermille: UInt64
    public let requestedCoveragePermille: UInt64
    public let remainingUnknown: InvestigationRemainingUnknown
    public let remainingUnknownThreshold: ByteCount
    public let consecutiveNoGainSteps: UInt64
    public let consecutiveNoGainLimit: UInt64
    public let tokenUsageQuality: InvestigationTokenUsageQuality
    public let pauseRequested: Bool

    public init(
        safetyLoss: InvestigationSafetyLoss?,
        userCancellationRequested: Bool,
        userStopRequested: Bool,
        hardBudgetExhaustion: InvestigationBudgetExhaustion?,
        observedBudgetExhaustion: InvestigationBudgetExhaustion?,
        coveragePermille: UInt64,
        requestedCoveragePermille: UInt64,
        remainingUnknown: InvestigationRemainingUnknown,
        remainingUnknownThreshold: ByteCount,
        consecutiveNoGainSteps: UInt64,
        consecutiveNoGainLimit: UInt64,
        tokenUsageQuality: InvestigationTokenUsageQuality = .unavailable,
        failureReason: InvestigationFailureReason? = nil,
        pauseRequested: Bool
    ) throws {
        guard coveragePermille <= 1_000,
              (1...1_000).contains(requestedCoveragePermille),
              consecutiveNoGainLimit > 0,
              Self.isValidHardExhaustion(hardBudgetExhaustion),
              Self.isValidObservedExhaustion(observedBudgetExhaustion)
        else {
            throw InvestigationStopFactsError.invalidFacts
        }
        self.safetyLoss = safetyLoss
        self.failureReason = failureReason
        self.userCancellationRequested = userCancellationRequested
        self.userStopRequested = userStopRequested
        self.hardBudgetExhaustion = hardBudgetExhaustion
        self.observedBudgetExhaustion = observedBudgetExhaustion
        self.coveragePermille = coveragePermille
        self.requestedCoveragePermille = requestedCoveragePermille
        self.remainingUnknown = remainingUnknown
        self.remainingUnknownThreshold = remainingUnknownThreshold
        self.consecutiveNoGainSteps = consecutiveNoGainSteps
        self.consecutiveNoGainLimit = consecutiveNoGainLimit
        self.tokenUsageQuality = tokenUsageQuality
        self.pauseRequested = pauseRequested
    }

    public static func open(
        requestedCoveragePermille: UInt64,
        remainingUnknownThreshold: ByteCount,
        consecutiveNoGainLimit: UInt64
    ) throws -> InvestigationStopFacts {
        try InvestigationStopFacts(
            safetyLoss: nil,
            userCancellationRequested: false,
            userStopRequested: false,
            hardBudgetExhaustion: nil,
            observedBudgetExhaustion: nil,
            coveragePermille: 0,
            requestedCoveragePermille: requestedCoveragePermille,
            remainingUnknown: .unmeasurable,
            remainingUnknownThreshold: remainingUnknownThreshold,
            consecutiveNoGainSteps: 0,
            consecutiveNoGainLimit: consecutiveNoGainLimit,
            tokenUsageQuality: .unavailable,
            failureReason: nil,
            pauseRequested: false
        )
    }

    public func replacing(
        safetyLoss: InvestigationSafetyLoss?
    ) -> InvestigationStopFacts {
        copy(safetyLoss: safetyLoss)
    }

    public func replacing(
        failureReason: InvestigationFailureReason?
    ) -> InvestigationStopFacts {
        copy(failureReason: failureReason)
    }

    public func replacing(
        userCancellationRequested: Bool
    ) -> InvestigationStopFacts {
        copy(userCancellationRequested: userCancellationRequested)
    }

    public func replacing(
        userStopRequested: Bool
    ) -> InvestigationStopFacts {
        copy(userStopRequested: userStopRequested)
    }

    public func replacing(
        hardBudgetExhaustion: InvestigationBudgetExhaustion?
    ) throws -> InvestigationStopFacts {
        guard Self.isValidHardExhaustion(hardBudgetExhaustion) else {
            throw InvestigationStopFactsError.invalidFacts
        }
        return copy(hardBudgetExhaustion: hardBudgetExhaustion)
    }

    public func replacing(
        observedBudgetExhaustion: InvestigationBudgetExhaustion?
    ) throws -> InvestigationStopFacts {
        guard Self.isValidObservedExhaustion(observedBudgetExhaustion) else {
            throw InvestigationStopFactsError.invalidFacts
        }
        return copy(observedBudgetExhaustion: observedBudgetExhaustion)
    }

    public func replacing(
        remainingUnknown: InvestigationRemainingUnknown
    ) -> InvestigationStopFacts {
        copy(remainingUnknown: remainingUnknown)
    }

    public func replacing(
        consecutiveNoGainSteps: UInt64
    ) -> InvestigationStopFacts {
        copy(consecutiveNoGainSteps: consecutiveNoGainSteps)
    }

    public func replacing(
        tokenUsageQuality: InvestigationTokenUsageQuality
    ) -> InvestigationStopFacts {
        copy(tokenUsageQuality: tokenUsageQuality)
    }

    public func replacing(
        pauseRequested: Bool
    ) -> InvestigationStopFacts {
        copy(pauseRequested: pauseRequested)
    }

    private func copy(
        safetyLoss: InvestigationSafetyLoss?? = nil,
        failureReason: InvestigationFailureReason?? = nil,
        userCancellationRequested: Bool? = nil,
        userStopRequested: Bool? = nil,
        hardBudgetExhaustion: InvestigationBudgetExhaustion?? = nil,
        observedBudgetExhaustion: InvestigationBudgetExhaustion?? = nil,
        remainingUnknown: InvestigationRemainingUnknown? = nil,
        consecutiveNoGainSteps: UInt64? = nil,
        tokenUsageQuality: InvestigationTokenUsageQuality? = nil,
        pauseRequested: Bool? = nil
    ) -> InvestigationStopFacts {
        try! InvestigationStopFacts(
            safetyLoss: safetyLoss ?? self.safetyLoss,
            userCancellationRequested:
                userCancellationRequested
                ?? self.userCancellationRequested,
            userStopRequested: userStopRequested ?? self.userStopRequested,
            hardBudgetExhaustion:
                hardBudgetExhaustion ?? self.hardBudgetExhaustion,
            observedBudgetExhaustion:
                observedBudgetExhaustion ?? self.observedBudgetExhaustion,
            coveragePermille: coveragePermille,
            requestedCoveragePermille: requestedCoveragePermille,
            remainingUnknown: remainingUnknown ?? self.remainingUnknown,
            remainingUnknownThreshold: remainingUnknownThreshold,
            consecutiveNoGainSteps:
                consecutiveNoGainSteps ?? self.consecutiveNoGainSteps,
            consecutiveNoGainLimit: consecutiveNoGainLimit,
            tokenUsageQuality: tokenUsageQuality ?? self.tokenUsageQuality,
            failureReason: failureReason ?? self.failureReason,
            pauseRequested: pauseRequested ?? self.pauseRequested
        )
    }

    private static func isValidHardExhaustion(
        _ exhaustion: InvestigationBudgetExhaustion?
    ) -> Bool {
        guard let exhaustion else {
            return true
        }
        guard exhaustion.enforcement == .hardAdmission else {
            return false
        }
        return switch exhaustion.dimension {
        case .wallClock,
             .coordinatorTurns,
             .probeCalls,
             .probeReadBytes,
             .probeOutputBytes,
             .cumulativeContextBytes,
             .concurrentProbes,
             .consecutiveNoGainSteps:
            true
        case .observedDirectToolStarts, .observedTotalTokens:
            false
        }
    }

    private static func isValidObservedExhaustion(
        _ exhaustion: InvestigationBudgetExhaustion?
    ) -> Bool {
        guard let exhaustion else {
            return true
        }
        guard exhaustion.enforcement == .eventTimeObserved else {
            return false
        }
        return switch exhaustion.dimension {
        case .observedDirectToolStarts, .observedTotalTokens:
            true
        case .wallClock,
             .coordinatorTurns,
             .probeCalls,
             .probeReadBytes,
             .probeOutputBytes,
             .cumulativeContextBytes,
             .concurrentProbes,
             .consecutiveNoGainSteps:
            false
        }
    }
}

public struct InvestigationStopEvaluator: Sendable {
    public init() {}

    public func evaluate(
        _ facts: InvestigationStopFacts
    ) -> InvestigationStopEvaluation {
        if let safetyLoss = facts.safetyLoss {
            return .blocked(safetyLoss)
        }
        if let failureReason = facts.failureReason {
            return .failed(failureReason)
        }
        if facts.userCancellationRequested {
            return .stop(.userCancelled)
        }
        if facts.userStopRequested {
            return .stop(.userStopped)
        }
        if let exhaustion = facts.hardBudgetExhaustion {
            return .stop(.budgetExhausted(exhaustion))
        }
        if let exhaustion = facts.observedBudgetExhaustion {
            if exhaustion.dimension == .observedTotalTokens,
               facts.tokenUsageQuality != .observed
            {
                return continueAfterObservedBudget(facts)
            }
            return .stop(.budgetExhausted(exhaustion))
        }
        return continueAfterObservedBudget(facts)
    }

    private func continueAfterObservedBudget(
        _ facts: InvestigationStopFacts
    ) -> InvestigationStopEvaluation {
        if facts.coveragePermille >= facts.requestedCoveragePermille {
            return .stop(.coverageReached)
        }
        if case let .measured(bytes) = facts.remainingUnknown,
           bytes < facts.remainingUnknownThreshold
        {
            return .stop(.remainingUnknownBelowThreshold)
        }
        if facts.consecutiveNoGainSteps >= facts.consecutiveNoGainLimit {
            return .stop(.noEvidenceGain)
        }
        if facts.pauseRequested {
            return .pause
        }
        return .continueInvestigation
    }
}
