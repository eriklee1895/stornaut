import Foundation
import Testing
@testable import StornautCore

@Test
func investigationBudgetPresetsMatchTheClosedMatrix() {
    #expect(
        InvestigationBudgetLimits.forPreset(.focused)
            == InvestigationBudgetLimits(
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
    )
    #expect(
        InvestigationBudgetLimits.forPreset(.balanced)
            == InvestigationBudgetLimits(
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
    )
    #expect(
        InvestigationBudgetLimits.forPreset(.thorough)
            == InvestigationBudgetLimits(
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
    )
    #expect(
        InvestigationBudgetLimits.forPreset(.focused)
            .singleContextInputBytes == 262_144
    )
}

@Test
func investigationBudgetLedgerReservesExactHardBoundaries() throws {
    let identity = fixtureInvestigationBudgetIdentity()
    var ledger = InvestigationBudgetLedger(
        identity: identity,
        limits: .forPreset(.focused)
    )

    try ledger.reserve(
        .coordinatorTurns,
        amount: 3,
        coordinatorOrdinal: 1
    )
    try ledger.reserve(
        .coordinatorTurns,
        amount: 1,
        coordinatorOrdinal: 2
    )
    #expect(ledger.hardUsage.coordinatorTurns == 4)
    #expect(
        ledger.hardAdmission(
            .coordinatorTurns,
            amount: 1
        ) == .wouldExceed
    )
    #expect(throws: InvestigationBudgetError.hardLimitExceeded) {
        try ledger.reserve(
            .coordinatorTurns,
            amount: 1,
            coordinatorOrdinal: 3
        )
    }
    #expect(throws: InvestigationBudgetError.invalidAmount) {
        try ledger.reserve(
            .probeCalls,
            amount: 0,
            coordinatorOrdinal: 3
        )
    }
    #expect(throws: InvestigationBudgetError.nonIncreasingOrdinal) {
        try ledger.reserve(
            .probeCalls,
            amount: 1,
            coordinatorOrdinal: 2
        )
    }

    try ledger.reserve(
        .probeReadBytes,
        amount: 8 * 1_048_576,
        coordinatorOrdinal: 3
    )
    try ledger.reserve(
        .probeOutputBytes,
        amount: 2 * 1_048_576,
        coordinatorOrdinal: 4
    )
    for coordinatorOrdinal in 5 ... 8 {
        try ledger.reserveContextInput(
            byteCount: 262_144,
            coordinatorOrdinal: UInt64(coordinatorOrdinal)
        )
    }
    #expect(ledger.hardUsage.probeReadBytes == 8 * 1_048_576)
    #expect(ledger.hardUsage.probeOutputBytes == 2 * 1_048_576)
    #expect(ledger.hardUsage.cumulativeContextBytes == 1_048_576)
}

@Test
func investigationBudgetLedgerCoversEveryHardDimensionAtomically() throws {
    let limits = InvestigationBudgetLimits.forPreset(.focused)

    for dimension in InvestigationHardBudgetDimension.allCases {
        let limit = hardLimit(for: dimension, limits: limits)
        var ledger = InvestigationBudgetLedger(
            identity: fixtureInvestigationBudgetIdentity(),
            limits: limits
        )

        var ordinal: UInt64 = 1
        if dimension == .cumulativeContextBytes {
            for _ in 0..<3 {
                try ledger.reserveContextInput(
                    byteCount: limits.singleContextInputBytes,
                    coordinatorOrdinal: ordinal
                )
                ordinal += 1
            }
            try ledger.reserveContextInput(
                byteCount: limits.singleContextInputBytes - 1,
                coordinatorOrdinal: ordinal
            )
            ordinal += 1
        } else {
            #expect(
                ledger.hardAdmission(
                    dimension,
                    amount: limit - 1
                ) == .admitted
            )
            try ledger.reserve(
                dimension,
                amount: limit - 1,
                coordinatorOrdinal: ordinal
            )
            ordinal += 1
        }
        #expect(hardUsage(for: dimension, ledger: ledger) == limit - 1)
        #expect(
            ledger.hardAdmission(
                dimension,
                amount: 1
            ) == .admitted
        )
        #expect(
            ledger.hardAdmission(
                dimension,
                amount: 2
            ) == .wouldExceed
        )

        try ledger.reserve(
            dimension,
            amount: 1,
            coordinatorOrdinal: ordinal
        )
        ordinal += 1
        #expect(hardUsage(for: dimension, ledger: ledger) == limit)
        #expect(
            ledger.hardAdmission(
                dimension,
                amount: 1
            ) == .wouldExceed
        )
        #expect(throws: InvestigationBudgetError.hardLimitExceeded) {
            try ledger.reserve(
                dimension,
                amount: 1,
                coordinatorOrdinal: ordinal
            )
        }
        #expect(hardUsage(for: dimension, ledger: ledger) == limit)

        #expect(throws: InvestigationBudgetError.nonIncreasingOrdinal) {
            try ledger.reserve(
                dimension,
                amount: 1,
                coordinatorOrdinal: ordinal - 1
            )
        }
        #expect(hardUsage(for: dimension, ledger: ledger) == limit)
    }
}

@Test
func investigationBudgetWallClockAdmissionUsesStrictMonotonicBoundary() throws {
    let limits = InvestigationBudgetLimits.forPreset(.focused)

    #expect(
        try limits.wallClockAdmission(
            elapsed: .nanoseconds(599_999_999_999)
        ) == .admitted
    )
    #expect(
        try limits.wallClockAdmission(
            elapsed: .nanoseconds(600_000_000_000)
        ) == .wouldExceed
    )
    #expect(
        try limits.wallClockAdmission(
            elapsed: .nanoseconds(600_000_000_001)
        ) == .wouldExceed
    )
    #expect(throws: InvestigationBudgetError.invalidElapsedTime) {
        try limits.wallClockAdmission(elapsed: .nanoseconds(-1))
    }
    #expect(throws: InvestigationBudgetError.invalidElapsedTime) {
        try limits.wallClockAdmission(
            elapsed: Duration(
                secondsComponent: 0,
                attosecondsComponent: 1
            )
        )
    }
    #expect(throws: InvestigationBudgetError.invalidElapsedTime) {
        try limits.wallClockAdmission(elapsed: .seconds(Int64.max))
    }
}

@Test
func investigationBudgetLedgerEnforcesSingleAndCumulativeContextLimits() throws {
    let identity = fixtureInvestigationBudgetIdentity()
    var ledger = InvestigationBudgetLedger(
        identity: identity,
        limits: .forPreset(.focused)
    )

    #expect(
        ledger.contextInputAdmission(byteCount: 262_144) == .admitted
    )
    #expect(
        ledger.contextInputAdmission(byteCount: 262_145) == .wouldExceed
    )
    #expect(throws: InvestigationBudgetError.hardLimitExceeded) {
        try ledger.reserveContextInput(
            byteCount: 262_145,
            coordinatorOrdinal: 1
        )
    }

    for ordinal in 1 ... 4 {
        try ledger.reserveContextInput(
            byteCount: 262_144,
            coordinatorOrdinal: UInt64(ordinal)
        )
    }
    #expect(ledger.hardUsage.cumulativeContextBytes == 1_048_576)
    #expect(
        ledger.contextInputAdmission(byteCount: 1) == .wouldExceed
    )
    #expect(throws: InvestigationBudgetError.hardLimitExceeded) {
        try ledger.reserveContextInput(
            byteCount: 1,
            coordinatorOrdinal: 5
        )
    }
    #expect(
        ledger.hardAdmission(
            .cumulativeContextBytes,
            amount: 262_145
        ) == .wouldExceed
    )
}

@Test
func investigationBudgetLedgerOwnsProbeLeasesAndNoGainOnce() throws {
    let identity = fixtureInvestigationBudgetIdentity()
    var ledger = InvestigationBudgetLedger(
        identity: identity,
        limits: .forPreset(.focused)
    )

    let first = try ledger.acquireProbeLease(coordinatorOrdinal: 1)
    let second = try ledger.acquireProbeLease(coordinatorOrdinal: 2)
    #expect(ledger.activeProbeLeaseCount == 2)
    #expect(throws: InvestigationBudgetError.hardLimitExceeded) {
        _ = try ledger.acquireProbeLease(coordinatorOrdinal: 3)
    }
    try ledger.releaseProbeLease(
        first,
        identity: identity,
        coordinatorOrdinal: 3
    )
    #expect(ledger.activeProbeLeaseCount == 1)
    #expect(throws: InvestigationBudgetError.invalidLeaseRelease) {
        try ledger.releaseProbeLease(
            first,
            identity: identity,
            coordinatorOrdinal: 4
        )
    }

    try ledger.recordScientificStep(
        .verifiedNoGain,
        coordinatorOrdinal: 4
    )
    try ledger.recordScientificStep(
        .verifiedNoGain,
        coordinatorOrdinal: 5
    )
    #expect(ledger.consecutiveNoGainSteps == 2)
    try ledger.recordScientificStep(
        .verifiedGain,
        coordinatorOrdinal: 6
    )
    #expect(ledger.consecutiveNoGainSteps == 0)
    #expect(throws: InvestigationBudgetError.nonIncreasingOrdinal) {
        try ledger.recordScientificStep(
            .verifiedGain,
            coordinatorOrdinal: 6
        )
    }
    try ledger.releaseProbeLease(
        second,
        identity: identity,
        coordinatorOrdinal: 7
    )
    #expect(ledger.activeProbeLeaseCount == 0)
}

@Test
func investigationBudgetNoGainIgnoresNonScientificStepOutcomes() throws {
    var ledger = InvestigationBudgetLedger(
        identity: fixtureInvestigationBudgetIdentity(),
        limits: .forPreset(.focused)
    )

    try ledger.recordScientificStep(
        .verifiedNoGain,
        coordinatorOrdinal: 1
    )
    #expect(ledger.consecutiveNoGainSteps == 1)

    for (ordinal, result) in [
        (UInt64(2), InvestigationScientificStepResult.invalid),
        (UInt64(3), .cancelled),
        (UInt64(4), .protocolFailed),
    ] {
        try ledger.recordScientificStep(
            result,
            coordinatorOrdinal: ordinal
        )
        #expect(ledger.consecutiveNoGainSteps == 1)
    }

    try ledger.recordScientificStep(
        .verifiedNoGain,
        coordinatorOrdinal: 5
    )
    #expect(ledger.consecutiveNoGainSteps == 2)
    try ledger.recordScientificStep(
        .verifiedGain,
        coordinatorOrdinal: 6
    )
    #expect(ledger.consecutiveNoGainSteps == 0)
}

@Test
func investigationBudgetProbeLeaseFailuresAreExactlyOnceAndAtomic() throws {
    let identity = fixtureInvestigationBudgetIdentity()
    var ledger = InvestigationBudgetLedger(
        identity: identity,
        limits: .forPreset(.focused)
    )

    let first = try ledger.acquireProbeLease(coordinatorOrdinal: 1)
    #expect(ledger.activeProbeLeaseCount == 1)
    let second = try ledger.acquireProbeLease(coordinatorOrdinal: 2)
    #expect(ledger.activeProbeLeaseCount == 2)
    #expect(throws: InvestigationBudgetError.hardLimitExceeded) {
        _ = try ledger.acquireProbeLease(coordinatorOrdinal: 3)
    }
    #expect(ledger.activeProbeLeaseCount == 2)

    let wrongIdentity = InvestigationBudgetIdentity(
        investigationID: identity.investigationID,
        runID: InvestigationRunID(
            rawValue: "investigation-run-wrong-release"
        )!,
        rootSessionID: identity.rootSessionID
    )
    #expect(throws: InvestigationBudgetError.identityMismatch) {
        try ledger.releaseProbeLease(
            first,
            identity: wrongIdentity,
            coordinatorOrdinal: 3
        )
    }
    #expect(ledger.activeProbeLeaseCount == 2)

    try ledger.releaseProbeLease(
        first,
        identity: identity,
        coordinatorOrdinal: 3
    )
    #expect(ledger.activeProbeLeaseCount == 1)
    #expect(throws: InvestigationBudgetError.invalidLeaseRelease) {
        try ledger.releaseProbeLease(
            first,
            identity: identity,
            coordinatorOrdinal: 4
        )
    }
    #expect(ledger.activeProbeLeaseCount == 1)

    try ledger.releaseProbeLease(
        second,
        identity: identity,
        coordinatorOrdinal: 4
    )
    #expect(ledger.activeProbeLeaseCount == 0)
}

@Test
func investigationBudgetLedgerSupportsMaximumLengthRunIDs() throws {
    let runPrefix = InvestigationRunIDTag.prefix
    let runID = InvestigationRunID(
        rawValue: runPrefix
            + String(repeating: "r", count: 128 - runPrefix.utf8.count)
    )!
    let identity = InvestigationBudgetIdentity(
        investigationID: InvestigationID(
            rawValue: "investigation-maximum-run-id"
        )!,
        runID: runID,
        rootSessionID: DomainToken(rawValue: "session-maximum-run-id")!
    )
    var ledger = InvestigationBudgetLedger(
        identity: identity,
        limits: .forPreset(.focused)
    )

    let lease = try ledger.acquireProbeLease(coordinatorOrdinal: 1)

    #expect(lease.id.rawValue.hasPrefix("probe-lease-"))
    #expect(lease.id.rawValue.utf8.count <= 128)
    try ledger.releaseProbeLease(
        lease,
        identity: identity,
        coordinatorOrdinal: 2
    )
}

@Test
func investigationBudgetLedgerDeduplicatesDirectToolsAcrossThreads() throws {
    let identity = fixtureInvestigationBudgetIdentity()
    var ledger = InvestigationBudgetLedger(
        identity: identity,
        limits: .forPreset(.focused)
    )
    let root = InvestigationRuntimeObservation(
        identity: identity,
        threadID: DomainToken(rawValue: "thread-root")!,
        parentThreadID: nil,
        turnID: DomainToken(rawValue: "turn-root")!,
        itemID: DomainToken(rawValue: "item-root")!,
        kind: .directToolStarted,
        sourceMethod: DomainToken(rawValue: "item.started")!,
        coordinatorOrdinal: 1,
        payloadFingerprint: fixtureBudgetFingerprint(1)
    )
    let child = InvestigationRuntimeObservation(
        identity: identity,
        threadID: DomainToken(rawValue: "thread-child")!,
        parentThreadID: DomainToken(rawValue: "thread-root")!,
        turnID: DomainToken(rawValue: "turn-child")!,
        itemID: DomainToken(rawValue: "item-child")!,
        kind: .directToolStarted,
        sourceMethod: DomainToken(rawValue: "item.started")!,
        coordinatorOrdinal: 2,
        payloadFingerprint: fixtureBudgetFingerprint(2)
    )

    try ledger.acceptDirectToolStart(root)
    try ledger.acceptDirectToolStart(child)
    try ledger.acceptDirectToolStart(root)
    #expect(ledger.observedUsage.directToolStarts == 2)
    #expect(ledger.observedUsage.directToolCeilingReached == false)

    let conflicting = InvestigationRuntimeObservation(
        identity: identity,
        threadID: root.threadID,
        parentThreadID: nil,
        turnID: root.turnID,
        itemID: root.itemID,
        kind: .directToolStarted,
        sourceMethod: root.sourceMethod,
        coordinatorOrdinal: 3,
        payloadFingerprint: fixtureBudgetFingerprint(9)
    )
    #expect(throws: InvestigationBudgetError.conflictingReplay) {
        try ledger.acceptDirectToolStart(conflicting)
    }

    let wrongIdentity = InvestigationRuntimeObservation(
        identity: InvestigationBudgetIdentity(
            investigationID: identity.investigationID,
            runID: InvestigationRunID(rawValue: "investigation-run-other")!,
            rootSessionID: identity.rootSessionID
        ),
        threadID: root.threadID,
        parentThreadID: nil,
        turnID: DomainToken(rawValue: "turn-other")!,
        itemID: DomainToken(rawValue: "item-other")!,
        kind: .directToolStarted,
        sourceMethod: root.sourceMethod,
        coordinatorOrdinal: 4,
        payloadFingerprint: fixtureBudgetFingerprint(4)
    )
    #expect(throws: InvestigationBudgetError.identityMismatch) {
        try ledger.acceptDirectToolStart(wrongIdentity)
    }
}

@Test
func investigationBudgetLedgerRetainsExactDirectToolOverrun() throws {
    let identity = fixtureInvestigationBudgetIdentity()
    var ledger = InvestigationBudgetLedger(
        identity: identity,
        limits: .forPreset(.focused)
    )

    for index in 0..<33 {
        try ledger.acceptDirectToolStart(
            InvestigationRuntimeObservation(
                identity: identity,
                threadID: DomainToken(rawValue: "thread-root")!,
                parentThreadID: nil,
                turnID: DomainToken(rawValue: "turn-\(index)")!,
                itemID: DomainToken(rawValue: "item-\(index)")!,
                kind: .directToolStarted,
                sourceMethod: DomainToken(rawValue: "item.started")!,
                coordinatorOrdinal: UInt64(index + 1),
                payloadFingerprint: fixtureBudgetFingerprint(
                    UInt8(index)
                )
            )
        )
    }

    #expect(ledger.limits.observedDirectToolStarts == 32)
    #expect(ledger.observedUsage.directToolStarts == 33)
    #expect(ledger.observedUsage.directToolCeilingReached)
}

@Test
func investigationBudgetLedgerAggregatesLatestCumulativeTokenSnapshots() throws {
    let identity = fixtureInvestigationBudgetIdentity()
    var ledger = InvestigationBudgetLedger(
        identity: identity,
        limits: .forPreset(.focused)
    )
    #expect(ledger.observedUsage.tokenQuality == .unavailable)
    #expect(ledger.observedUsage.totalTokens == nil)

    let root = fixtureTokenObservation(
        identity: identity,
        thread: "thread-root",
        turn: "turn-root",
        ordinal: 1,
        total: .init(
            totalTokens: 40_000,
            inputTokens: 30_000,
            cachedInputTokens: 20_000,
            outputTokens: 10_000
        ),
        fingerprintByte: 1
    )
    let child = fixtureTokenObservation(
        identity: identity,
        thread: "thread-child",
        turn: "turn-child",
        ordinal: 2,
        total: .init(
            totalTokens: 20_000,
            inputTokens: 15_000,
            cachedInputTokens: 5_000,
            outputTokens: 5_000
        ),
        fingerprintByte: 2
    )
    try ledger.acceptTokenUsage(root)
    try ledger.acceptTokenUsage(child)
    try ledger.acceptTokenUsage(root)
    #expect(ledger.observedUsage.tokenQuality == .observed)
    #expect(ledger.observedUsage.totalTokens == 60_000)

    let increased = fixtureTokenObservation(
        identity: identity,
        thread: "thread-root",
        turn: "turn-root",
        ordinal: 3,
        total: .init(
            totalTokens: 90_000,
            inputTokens: 70_000,
            cachedInputTokens: 50_000,
            outputTokens: 20_000
        ),
        fingerprintByte: 3
    )
    try ledger.acceptTokenUsage(increased)
    #expect(ledger.observedUsage.totalTokens == 110_000)
    #expect(ledger.observedUsage.tokenCeilingReached == true)

    let decreased = fixtureTokenObservation(
        identity: identity,
        thread: "thread-root",
        turn: "turn-root",
        ordinal: 4,
        total: .init(
            totalTokens: 89_999,
            inputTokens: 70_000,
            cachedInputTokens: 50_000,
            outputTokens: 19_999
        ),
        fingerprintByte: 4
    )
    #expect(throws: InvestigationBudgetError.counterDecreased) {
        try ledger.acceptTokenUsage(decreased)
    }

    let sameTotalWithComponentDecrease = fixtureTokenObservation(
        identity: identity,
        thread: "thread-root",
        turn: "turn-root",
        ordinal: 5,
        total: .init(
            totalTokens: 90_000,
            inputTokens: 69_999,
            cachedInputTokens: 50_000,
            outputTokens: 20_000
        ),
        fingerprintByte: 5
    )
    #expect(throws: InvestigationBudgetError.counterDecreased) {
        try ledger.acceptTokenUsage(sameTotalWithComponentDecrease)
    }

    let sameSnapshotWithDifferentPayload = fixtureTokenObservation(
        identity: identity,
        thread: "thread-root",
        turn: "turn-root",
        ordinal: 6,
        total: .init(
            totalTokens: 90_000,
            inputTokens: 70_000,
            cachedInputTokens: 50_000,
            outputTokens: 20_000
        ),
        fingerprintByte: 6
    )
    #expect(throws: InvestigationBudgetError.conflictingReplay) {
        try ledger.acceptTokenUsage(sameSnapshotWithDifferentPayload)
    }
}

@Test
func investigationBudgetLedgerKeepsPartialTurnUsageUnavailable() throws {
    let identity = fixtureInvestigationBudgetIdentity()
    var ledger = InvestigationBudgetLedger(
        identity: identity,
        limits: .forPreset(.focused)
    )
    try ledger.reserve(
        .coordinatorTurns,
        amount: 2,
        coordinatorOrdinal: 1
    )
    try ledger.acceptTokenUsage(
        fixtureTokenObservation(
            identity: identity,
            thread: "thread-root",
            turn: "turn-root",
            ordinal: 2,
            total: .init(
                totalTokens: 100_000,
                inputTokens: 80_000,
                cachedInputTokens: 20_000,
                outputTokens: 20_000
            ),
            fingerprintByte: 8
        )
    )

    #expect(ledger.observedUsage.tokenQuality == .unavailable)
    #expect(ledger.observedUsage.totalTokens == nil)
    #expect(ledger.observedUsage.tokenCeilingReached == false)
}

private func fixtureInvestigationBudgetIdentity()
    -> InvestigationBudgetIdentity
{
    InvestigationBudgetIdentity(
        investigationID: InvestigationID(rawValue: "investigation-budget")!,
        runID: InvestigationRunID(rawValue: "investigation-run-budget")!,
        rootSessionID: DomainToken(rawValue: "session-budget")!
    )
}

private func hardLimit(
    for dimension: InvestigationHardBudgetDimension,
    limits: InvestigationBudgetLimits
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

private func hardUsage(
    for dimension: InvestigationHardBudgetDimension,
    ledger: InvestigationBudgetLedger
) -> UInt64 {
    switch dimension {
    case .coordinatorTurns:
        ledger.hardUsage.coordinatorTurns
    case .probeCalls:
        ledger.hardUsage.probeCalls
    case .probeReadBytes:
        ledger.hardUsage.probeReadBytes
    case .probeOutputBytes:
        ledger.hardUsage.probeOutputBytes
    case .cumulativeContextBytes:
        ledger.hardUsage.cumulativeContextBytes
    }
}

private func fixtureBudgetFingerprint(_ byte: UInt8)
    -> InvestigationFingerprint
{
    try! InvestigationFingerprint(
        validating: Data(repeating: byte, count: 32)
    )
}

private func fixtureTokenObservation(
    identity: InvestigationBudgetIdentity,
    thread: String,
    turn: String,
    ordinal: UInt64,
    total: InvestigationTokenUsage,
    fingerprintByte: UInt8
) -> InvestigationTokenUsageObservation {
    InvestigationTokenUsageObservation(
        observation: InvestigationRuntimeObservation(
            identity: identity,
            threadID: DomainToken(rawValue: thread)!,
            parentThreadID: thread == "thread-root"
                ? nil : DomainToken(rawValue: "thread-root")!,
            turnID: DomainToken(rawValue: turn)!,
            itemID: nil,
            kind: .tokenUsageUpdated,
            sourceMethod: DomainToken(rawValue: "thread.tokenUsage.updated")!,
            coordinatorOrdinal: ordinal,
            payloadFingerprint: fixtureBudgetFingerprint(fingerprintByte)
        ),
        total: total
    )
}
