import Foundation

public struct InvestigationBudgetLimits: Codable, Sendable, Equatable {
    public static let singleContextInputByteLimit: UInt64 = 262_144

    public let wallClockNanoseconds: UInt64
    public let coordinatorTurns: UInt64
    public let probeCalls: UInt64
    public let probeReadBytes: UInt64
    public let probeOutputBytes: UInt64
    public let cumulativeContextBytes: UInt64
    public let concurrentProbes: UInt64
    public let consecutiveNoGainSteps: UInt64
    public let observedDirectToolStarts: UInt64
    public let observedTotalTokens: UInt64
    public let singleContextInputBytes: UInt64

    init(
        wallClockNanoseconds: UInt64,
        coordinatorTurns: UInt64,
        probeCalls: UInt64,
        probeReadBytes: UInt64,
        probeOutputBytes: UInt64,
        cumulativeContextBytes: UInt64,
        concurrentProbes: UInt64,
        consecutiveNoGainSteps: UInt64,
        observedDirectToolStarts: UInt64,
        observedTotalTokens: UInt64,
        singleContextInputBytes: UInt64 = singleContextInputByteLimit
    ) {
        self.wallClockNanoseconds = wallClockNanoseconds
        self.coordinatorTurns = coordinatorTurns
        self.probeCalls = probeCalls
        self.probeReadBytes = probeReadBytes
        self.probeOutputBytes = probeOutputBytes
        self.cumulativeContextBytes = cumulativeContextBytes
        self.concurrentProbes = concurrentProbes
        self.consecutiveNoGainSteps = consecutiveNoGainSteps
        self.observedDirectToolStarts = observedDirectToolStarts
        self.observedTotalTokens = observedTotalTokens
        self.singleContextInputBytes = singleContextInputBytes
    }

    public static func forPreset(
        _ preset: InvestigationBudgetPreset
    ) -> InvestigationBudgetLimits {
        switch preset {
        case .focused:
            InvestigationBudgetLimits(
                wallClockNanoseconds: 600_000_000_000,
                coordinatorTurns: 4,
                probeCalls: 16,
                probeReadBytes: 8 * 1_048_576,
                probeOutputBytes: 2 * 1_048_576,
                cumulativeContextBytes: 1_048_576,
                concurrentProbes: 2,
                consecutiveNoGainSteps: 2,
                observedDirectToolStarts: 32,
                observedTotalTokens: 100_000
            )
        case .balanced:
            InvestigationBudgetLimits(
                wallClockNanoseconds: 1_800_000_000_000,
                coordinatorTurns: 12,
                probeCalls: 48,
                probeReadBytes: 32 * 1_048_576,
                probeOutputBytes: 8 * 1_048_576,
                cumulativeContextBytes: 4 * 1_048_576,
                concurrentProbes: 4,
                consecutiveNoGainSteps: 3,
                observedDirectToolStarts: 96,
                observedTotalTokens: 300_000
            )
        case .thorough:
            InvestigationBudgetLimits(
                wallClockNanoseconds: 3_600_000_000_000,
                coordinatorTurns: 24,
                probeCalls: 96,
                probeReadBytes: 64 * 1_048_576,
                probeOutputBytes: 16 * 1_048_576,
                cumulativeContextBytes: 8 * 1_048_576,
                concurrentProbes: 8,
                consecutiveNoGainSteps: 4,
                observedDirectToolStarts: 192,
                observedTotalTokens: 600_000
            )
        }
    }

    public func wallClockAdmission(
        elapsed: Duration
    ) throws -> InvestigationBudgetAdmission {
        guard elapsed >= .zero else {
            throw InvestigationBudgetError.invalidElapsedTime
        }
        let components = elapsed.components
        guard components.seconds >= 0,
              components.attoseconds >= 0,
              components.attoseconds % 1_000_000_000 == 0
        else {
            throw InvestigationBudgetError.invalidElapsedTime
        }
        let wholeNanoseconds = UInt64(components.seconds)
            .multipliedReportingOverflow(by: 1_000_000_000)
        guard !wholeNanoseconds.overflow else {
            throw InvestigationBudgetError.invalidElapsedTime
        }
        let fractionalNanoseconds = UInt64(
            components.attoseconds / 1_000_000_000
        )
        let totalNanoseconds = wholeNanoseconds.partialValue
            .addingReportingOverflow(fractionalNanoseconds)
        guard !totalNanoseconds.overflow else {
            throw InvestigationBudgetError.invalidElapsedTime
        }
        return totalNanoseconds.partialValue < wallClockNanoseconds
            ? .admitted
            : .wouldExceed
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decoded = InvestigationBudgetLimits(
            wallClockNanoseconds: try container.decode(
                UInt64.self,
                forKey: .wallClockNanoseconds
            ),
            coordinatorTurns: try container.decode(
                UInt64.self,
                forKey: .coordinatorTurns
            ),
            probeCalls: try container.decode(
                UInt64.self,
                forKey: .probeCalls
            ),
            probeReadBytes: try container.decode(
                UInt64.self,
                forKey: .probeReadBytes
            ),
            probeOutputBytes: try container.decode(
                UInt64.self,
                forKey: .probeOutputBytes
            ),
            cumulativeContextBytes: try container.decode(
                UInt64.self,
                forKey: .cumulativeContextBytes
            ),
            concurrentProbes: try container.decode(
                UInt64.self,
                forKey: .concurrentProbes
            ),
            consecutiveNoGainSteps: try container.decode(
                UInt64.self,
                forKey: .consecutiveNoGainSteps
            ),
            observedDirectToolStarts: try container.decode(
                UInt64.self,
                forKey: .observedDirectToolStarts
            ),
            observedTotalTokens: try container.decode(
                UInt64.self,
                forKey: .observedTotalTokens
            ),
            singleContextInputBytes: try container.decode(
                UInt64.self,
                forKey: .singleContextInputBytes
            )
        )
        guard decoded.isOneOfClosedPresets else {
            throw InvestigationDomainError.invalidBudget
        }
        self = decoded
    }

    private var isOneOfClosedPresets: Bool {
        InvestigationBudgetPreset.allCases.contains {
            self == Self.forPreset($0)
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case wallClockNanoseconds
        case coordinatorTurns
        case probeCalls
        case probeReadBytes
        case probeOutputBytes
        case cumulativeContextBytes
        case concurrentProbes
        case consecutiveNoGainSteps
        case observedDirectToolStarts
        case observedTotalTokens
        case singleContextInputBytes
    }
}

extension InvestigationBudgetLimits: StrictIntegerDomainJSON {}

public enum InvestigationBudgetError: Error, Sendable, Equatable {
    case invalidAmount
    case invalidElapsedTime
    case hardLimitExceeded
    case nonIncreasingOrdinal
    case invalidLeaseRelease
    case identityMismatch
    case conflictingReplay
    case counterDecreased
    case invalidObservation
    case integerOverflow
}

public enum InvestigationHardBudgetDimension:
    String,
    Sendable,
    Hashable,
    CaseIterable
{
    case coordinatorTurns = "coordinator-turns-v1"
    case probeCalls = "probe-calls-v1"
    case probeReadBytes = "probe-read-bytes-v1"
    case probeOutputBytes = "probe-output-bytes-v1"
    case cumulativeContextBytes = "cumulative-context-bytes-v1"
}

public enum InvestigationBudgetAdmission: Sendable, Equatable {
    case admitted
    case wouldExceed
}

public struct InvestigationHardBudgetUsage: Sendable, Equatable {
    public fileprivate(set) var coordinatorTurns: UInt64 = 0
    public fileprivate(set) var probeCalls: UInt64 = 0
    public fileprivate(set) var probeReadBytes: UInt64 = 0
    public fileprivate(set) var probeOutputBytes: UInt64 = 0
    public fileprivate(set) var cumulativeContextBytes: UInt64 = 0

    public init() {}
}

public struct InvestigationBudgetIdentity:
    Sendable,
    Hashable
{
    public let investigationID: InvestigationID
    public let runID: InvestigationRunID
    public let rootSessionID: DomainToken

    public init(
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        rootSessionID: DomainToken
    ) {
        self.investigationID = investigationID
        self.runID = runID
        self.rootSessionID = rootSessionID
    }
}

public enum InvestigationRuntimeObservationKind:
    String,
    Sendable,
    Hashable
{
    case directToolStarted = "direct-tool-started-v1"
    case tokenUsageUpdated = "token-usage-updated-v1"
}

public struct InvestigationRuntimeObservation:
    Sendable,
    Hashable
{
    public let identity: InvestigationBudgetIdentity
    public let threadID: DomainToken
    public let parentThreadID: DomainToken?
    public let turnID: DomainToken
    public let itemID: DomainToken?
    public let kind: InvestigationRuntimeObservationKind
    public let sourceMethod: DomainToken
    public let coordinatorOrdinal: UInt64
    public let payloadFingerprint: InvestigationFingerprint

    public init(
        identity: InvestigationBudgetIdentity,
        threadID: DomainToken,
        parentThreadID: DomainToken?,
        turnID: DomainToken,
        itemID: DomainToken?,
        kind: InvestigationRuntimeObservationKind,
        sourceMethod: DomainToken,
        coordinatorOrdinal: UInt64,
        payloadFingerprint: InvestigationFingerprint
    ) {
        self.identity = identity
        self.threadID = threadID
        self.parentThreadID = parentThreadID
        self.turnID = turnID
        self.itemID = itemID
        self.kind = kind
        self.sourceMethod = sourceMethod
        self.coordinatorOrdinal = coordinatorOrdinal
        self.payloadFingerprint = payloadFingerprint
    }
}

public struct InvestigationTokenUsage: Sendable, Hashable {
    public let totalTokens: UInt64
    public let inputTokens: UInt64
    public let cachedInputTokens: UInt64
    public let outputTokens: UInt64

    public init(
        totalTokens: UInt64,
        inputTokens: UInt64,
        cachedInputTokens: UInt64,
        outputTokens: UInt64
    ) {
        self.totalTokens = totalTokens
        self.inputTokens = inputTokens
        self.cachedInputTokens = cachedInputTokens
        self.outputTokens = outputTokens
    }

    fileprivate var isValid: Bool {
        cachedInputTokens <= inputTokens
            && inputTokens <= totalTokens
            && outputTokens <= totalTokens
    }

    fileprivate func isNondecreasing(
        from prior: InvestigationTokenUsage
    ) -> Bool {
        totalTokens >= prior.totalTokens
            && inputTokens >= prior.inputTokens
            && cachedInputTokens >= prior.cachedInputTokens
            && outputTokens >= prior.outputTokens
    }
}

public struct InvestigationTokenUsageObservation:
    Sendable,
    Hashable
{
    public let observation: InvestigationRuntimeObservation
    public let total: InvestigationTokenUsage

    public init(
        observation: InvestigationRuntimeObservation,
        total: InvestigationTokenUsage
    ) {
        self.observation = observation
        self.total = total
    }
}

public enum InvestigationTokenUsageQuality:
    String,
    Sendable,
    Equatable
{
    case unavailable = "usage-unavailable-v1"
    case observed = "usage-observed-v1"
}

public struct InvestigationObservedBudgetUsage: Sendable, Equatable {
    public let directToolStarts: UInt64
    public let directToolCeilingReached: Bool
    public let tokenQuality: InvestigationTokenUsageQuality
    public let totalTokens: UInt64?
    public let tokenCeilingReached: Bool
}

public struct InvestigationProbeLease: Sendable, Hashable {
    public let id: DomainToken
    public let runID: InvestigationRunID
    public let acquisitionOrdinal: UInt64

    fileprivate init(
        id: DomainToken,
        runID: InvestigationRunID,
        acquisitionOrdinal: UInt64
    ) {
        self.id = id
        self.runID = runID
        self.acquisitionOrdinal = acquisitionOrdinal
    }
}

public enum InvestigationScientificStepResult: Sendable, Equatable {
    case verifiedGain
    case verifiedNoGain
    case invalid
    case cancelled
    case protocolFailed
}

public struct InvestigationBudgetLedger: Sendable {
    public let identity: InvestigationBudgetIdentity
    public let limits: InvestigationBudgetLimits
    public private(set) var hardUsage = InvestigationHardBudgetUsage()
    public private(set) var consecutiveNoGainSteps: UInt64 = 0

    private var lastCoordinatorOrdinal: UInt64 = 0
    private var activeProbeLeases: [DomainToken: InvestigationProbeLease] = [:]
    private var directToolObservations:
        [DirectToolObservationKey: InvestigationRuntimeObservation] = [:]
    private var tokenUsageByThread:
        [DomainToken: InvestigationTokenUsageObservation] = [:]
    private var tokenUsageObservedTurns: Set<ObservedTurnKey> = []

    public init(
        identity: InvestigationBudgetIdentity,
        limits: InvestigationBudgetLimits
    ) {
        self.identity = identity
        self.limits = limits
    }

    public var activeProbeLeaseCount: UInt64 {
        UInt64(activeProbeLeases.count)
    }

    public var observedUsage: InvestigationObservedBudgetUsage {
        let directToolStarts = UInt64(directToolObservations.count)
        let observedTurnCount = UInt64(tokenUsageObservedTurns.count)
        let hasCompleteTurnUsage = observedTurnCount > 0
            && (hardUsage.coordinatorTurns == 0
                || observedTurnCount == hardUsage.coordinatorTurns)
        let tokenTotal = hasCompleteTurnUsage
            ? aggregateTokenTotal() : nil
        return InvestigationObservedBudgetUsage(
            directToolStarts: directToolStarts,
            directToolCeilingReached:
                directToolStarts >= limits.observedDirectToolStarts,
            tokenQuality: hasCompleteTurnUsage ? .observed : .unavailable,
            totalTokens: tokenTotal,
            tokenCeilingReached: tokenTotal.map {
                $0 >= limits.observedTotalTokens
            } ?? false
        )
    }

    public func hardAdmission(
        _ dimension: InvestigationHardBudgetDimension,
        amount: UInt64
    ) -> InvestigationBudgetAdmission {
        guard amount > 0 else {
            return .wouldExceed
        }
        if dimension == .cumulativeContextBytes,
           amount > limits.singleContextInputBytes
        {
            return .wouldExceed
        }
        let consumed = hardValue(for: dimension)
        let limit = hardLimit(for: dimension)
        guard consumed <= limit, amount <= limit - consumed else {
            return .wouldExceed
        }
        return .admitted
    }

    public mutating func reserve(
        _ dimension: InvestigationHardBudgetDimension,
        amount: UInt64,
        coordinatorOrdinal: UInt64
    ) throws {
        guard amount > 0 else {
            throw InvestigationBudgetError.invalidAmount
        }
        try requireIncreasingOrdinal(coordinatorOrdinal)
        guard hardAdmission(dimension, amount: amount) == .admitted else {
            throw InvestigationBudgetError.hardLimitExceeded
        }
        let current = hardValue(for: dimension)
        let addition = current.addingReportingOverflow(amount)
        guard !addition.overflow else {
            throw InvestigationBudgetError.integerOverflow
        }
        setHardValue(addition.partialValue, for: dimension)
        lastCoordinatorOrdinal = coordinatorOrdinal
    }

    public func contextInputAdmission(
        byteCount: UInt64
    ) -> InvestigationBudgetAdmission {
        hardAdmission(.cumulativeContextBytes, amount: byteCount)
    }

    public mutating func reserveContextInput(
        byteCount: UInt64,
        coordinatorOrdinal: UInt64
    ) throws {
        try reserve(
            .cumulativeContextBytes,
            amount: byteCount,
            coordinatorOrdinal: coordinatorOrdinal
        )
    }

    public mutating func reserveTurn(
        contextByteCount: UInt64,
        coordinatorOrdinal: UInt64
    ) throws {
        guard contextByteCount > 0 else {
            throw InvestigationBudgetError.invalidAmount
        }
        try requireIncreasingOrdinal(coordinatorOrdinal)
        guard hardAdmission(.coordinatorTurns, amount: 1) == .admitted,
              hardAdmission(
                  .cumulativeContextBytes,
                  amount: contextByteCount
              ) == .admitted
        else {
            throw InvestigationBudgetError.hardLimitExceeded
        }
        let nextTurnCount = hardUsage.coordinatorTurns
            .addingReportingOverflow(1)
        let nextContextBytes = hardUsage.cumulativeContextBytes
            .addingReportingOverflow(contextByteCount)
        guard !nextTurnCount.overflow, !nextContextBytes.overflow else {
            throw InvestigationBudgetError.integerOverflow
        }
        hardUsage.coordinatorTurns = nextTurnCount.partialValue
        hardUsage.cumulativeContextBytes = nextContextBytes.partialValue
        lastCoordinatorOrdinal = coordinatorOrdinal
    }

    public mutating func acquireProbeLease(
        coordinatorOrdinal: UInt64
    ) throws -> InvestigationProbeLease {
        try requireIncreasingOrdinal(coordinatorOrdinal)
        guard activeProbeLeaseCount < limits.concurrentProbes else {
            throw InvestigationBudgetError.hardLimitExceeded
        }
        guard let id = DomainToken(
            rawValue: "probe-lease-\(coordinatorOrdinal)"
        ) else {
            throw InvestigationBudgetError.invalidObservation
        }
        let lease = InvestigationProbeLease(
            id: id,
            runID: identity.runID,
            acquisitionOrdinal: coordinatorOrdinal
        )
        guard activeProbeLeases[id] == nil else {
            throw InvestigationBudgetError.conflictingReplay
        }
        activeProbeLeases[id] = lease
        lastCoordinatorOrdinal = coordinatorOrdinal
        return lease
    }

    public mutating func releaseProbeLease(
        _ lease: InvestigationProbeLease,
        identity suppliedIdentity: InvestigationBudgetIdentity,
        coordinatorOrdinal: UInt64
    ) throws {
        guard suppliedIdentity == identity else {
            throw InvestigationBudgetError.identityMismatch
        }
        try requireIncreasingOrdinal(coordinatorOrdinal)
        guard lease.runID == identity.runID,
              activeProbeLeases[lease.id] == lease
        else {
            throw InvestigationBudgetError.invalidLeaseRelease
        }
        activeProbeLeases.removeValue(forKey: lease.id)
        lastCoordinatorOrdinal = coordinatorOrdinal
    }

    public mutating func recordScientificStep(
        _ result: InvestigationScientificStepResult,
        coordinatorOrdinal: UInt64
    ) throws {
        try requireIncreasingOrdinal(coordinatorOrdinal)
        switch result {
        case .verifiedGain:
            consecutiveNoGainSteps = 0
        case .verifiedNoGain:
            let addition = consecutiveNoGainSteps.addingReportingOverflow(1)
            guard !addition.overflow else {
                throw InvestigationBudgetError.integerOverflow
            }
            consecutiveNoGainSteps = addition.partialValue
        case .invalid, .cancelled, .protocolFailed:
            break
        }
        lastCoordinatorOrdinal = coordinatorOrdinal
    }

    public mutating func acceptDirectToolStart(
        _ observation: InvestigationRuntimeObservation
    ) throws {
        guard observation.identity == identity else {
            throw InvestigationBudgetError.identityMismatch
        }
        guard observation.kind == .directToolStarted,
              let itemID = observation.itemID
        else {
            throw InvestigationBudgetError.invalidObservation
        }
        let key = DirectToolObservationKey(
            threadID: observation.threadID,
            turnID: observation.turnID,
            itemID: itemID
        )
        if let prior = directToolObservations[key] {
            guard prior == observation else {
                throw InvestigationBudgetError.conflictingReplay
            }
            return
        }
        try requireIncreasingOrdinal(observation.coordinatorOrdinal)
        let nextCount = UInt64(directToolObservations.count)
            .addingReportingOverflow(1)
        guard !nextCount.overflow else {
            throw InvestigationBudgetError.integerOverflow
        }
        directToolObservations[key] = observation
        lastCoordinatorOrdinal = observation.coordinatorOrdinal
    }

    public mutating func acceptTokenUsage(
        _ usage: InvestigationTokenUsageObservation
    ) throws {
        let observation = usage.observation
        guard observation.identity == identity else {
            throw InvestigationBudgetError.identityMismatch
        }
        guard observation.kind == .tokenUsageUpdated,
              observation.itemID == nil,
              usage.total.isValid
        else {
            throw InvestigationBudgetError.invalidObservation
        }
        if let prior = tokenUsageByThread[observation.threadID] {
            if prior == usage {
                return
            }
            guard usage.total != prior.total else {
                throw InvestigationBudgetError.conflictingReplay
            }
            guard usage.total.isNondecreasing(from: prior.total) else {
                throw InvestigationBudgetError.counterDecreased
            }
        }
        try requireIncreasingOrdinal(observation.coordinatorOrdinal)

        var candidate = tokenUsageByThread
        candidate[observation.threadID] = usage
        _ = try aggregateTokenTotal(candidate)
        var observedTurns = tokenUsageObservedTurns
        observedTurns.insert(
            ObservedTurnKey(
                threadID: observation.threadID,
                turnID: observation.turnID
            )
        )
        guard hardUsage.coordinatorTurns == 0
                || UInt64(observedTurns.count) <= hardUsage.coordinatorTurns
        else {
            throw InvestigationBudgetError.invalidObservation
        }
        tokenUsageByThread = candidate
        tokenUsageObservedTurns = observedTurns
        lastCoordinatorOrdinal = observation.coordinatorOrdinal
    }

    private func hardValue(
        for dimension: InvestigationHardBudgetDimension
    ) -> UInt64 {
        switch dimension {
        case .coordinatorTurns:
            hardUsage.coordinatorTurns
        case .probeCalls:
            hardUsage.probeCalls
        case .probeReadBytes:
            hardUsage.probeReadBytes
        case .probeOutputBytes:
            hardUsage.probeOutputBytes
        case .cumulativeContextBytes:
            hardUsage.cumulativeContextBytes
        }
    }

    private mutating func setHardValue(
        _ value: UInt64,
        for dimension: InvestigationHardBudgetDimension
    ) {
        switch dimension {
        case .coordinatorTurns:
            hardUsage.coordinatorTurns = value
        case .probeCalls:
            hardUsage.probeCalls = value
        case .probeReadBytes:
            hardUsage.probeReadBytes = value
        case .probeOutputBytes:
            hardUsage.probeOutputBytes = value
        case .cumulativeContextBytes:
            hardUsage.cumulativeContextBytes = value
        }
    }

    private func hardLimit(
        for dimension: InvestigationHardBudgetDimension
    ) -> UInt64 {
        switch dimension {
        case .coordinatorTurns:
            limits.coordinatorTurns
        case .probeCalls:
            limits.probeCalls
        case .probeReadBytes:
            limits.probeReadBytes
        case .probeOutputBytes:
            limits.probeOutputBytes
        case .cumulativeContextBytes:
            limits.cumulativeContextBytes
        }
    }

    private func requireIncreasingOrdinal(_ ordinal: UInt64) throws {
        guard ordinal > lastCoordinatorOrdinal else {
            throw InvestigationBudgetError.nonIncreasingOrdinal
        }
    }

    private func aggregateTokenTotal() -> UInt64? {
        try? aggregateTokenTotal(tokenUsageByThread)
    }

    private func aggregateTokenTotal(
        _ values: [DomainToken: InvestigationTokenUsageObservation]
    ) throws -> UInt64 {
        var total: UInt64 = 0
        for value in values.values {
            let addition = total.addingReportingOverflow(
                value.total.totalTokens
            )
            guard !addition.overflow else {
                throw InvestigationBudgetError.integerOverflow
            }
            total = addition.partialValue
        }
        return total
    }
}

private struct DirectToolObservationKey: Sendable, Hashable {
    let threadID: DomainToken
    let turnID: DomainToken
    let itemID: DomainToken
}

private struct ObservedTurnKey: Sendable, Hashable {
    let threadID: DomainToken
    let turnID: DomainToken
}
