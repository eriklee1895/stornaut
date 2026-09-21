import Testing
@testable import StornautCore

@Test
func investigationStagesAreClosedAndOrdered() {
    #expect(InvestigationStage.allCases == [
        .prioritize,
        .identify,
        .verify,
        .buildPlan,
    ])
}

@Test
func investigationStopEvaluatorAppliesNormativePrecedence() throws {
    let hard = InvestigationBudgetExhaustion(
        dimension: .coordinatorTurns,
        enforcement: .hardAdmission
    )
    let observed = InvestigationBudgetExhaustion(
        dimension: .observedTotalTokens,
        enforcement: .eventTimeObserved
    )
    let allFacts = try InvestigationStopFacts(
        safetyLoss: .containmentLost,
        userCancellationRequested: true,
        userStopRequested: true,
        hardBudgetExhaustion: hard,
        observedBudgetExhaustion: observed,
        coveragePermille: 1_000,
        requestedCoveragePermille: 900,
        remainingUnknown: .measured(ByteCount(0)!),
        remainingUnknownThreshold: ByteCount(1_073_741_824)!,
        consecutiveNoGainSteps: 4,
        consecutiveNoGainLimit: 2,
        tokenUsageQuality: .observed,
        pauseRequested: true
    )
    let evaluator = InvestigationStopEvaluator()

    #expect(
        evaluator.evaluate(allFacts)
            == .blocked(.containmentLost)
    )
    #expect(
        evaluator.evaluate(
            allFacts.withFailure(.terminalPersistenceFailed)
        ) == .blocked(.containmentLost)
    )
    #expect(
        evaluator.evaluate(
            allFacts.withoutSafetyLoss()
                .withFailure(.terminalPersistenceFailed)
        ) == .failed(.terminalPersistenceFailed)
    )
    #expect(
        evaluator.evaluate(allFacts.withoutSafetyLoss())
            == .stop(.userCancelled)
    )
    #expect(
        evaluator.evaluate(
            allFacts.withoutSafetyLoss().withoutCancellation()
        ) == .stop(.userStopped)
    )
    #expect(
        evaluator.evaluate(
            allFacts.withoutSafetyLoss()
                .withoutCancellation()
                .withoutUserStop()
        ) == .stop(.budgetExhausted(hard))
    )
    #expect(
        evaluator.evaluate(
            allFacts.withoutSafetyLoss()
                .withoutCancellation()
                .withoutUserStop()
                .withoutHardBudget()
        ) == .stop(.budgetExhausted(observed))
    )
    #expect(
        evaluator.evaluate(
            allFacts.withoutSafetyLoss()
                .withoutCancellation()
                .withoutUserStop()
                .withoutHardBudget()
                .withoutObservedBudget()
        ) == .stop(.coverageReached)
    )
}

@Test
func investigationStopEvaluatorRequiresStrictMeasuredUnknownThreshold()
    throws
{
    let evaluator = InvestigationStopEvaluator()
    let threshold = ByteCount(1_073_741_824)!
    let base = try InvestigationStopFacts.open(
        requestedCoveragePermille: 900,
        remainingUnknownThreshold: threshold,
        consecutiveNoGainLimit: 3
    )

    #expect(
        evaluator.evaluate(
            base.withRemainingUnknown(.measured(ByteCount(1_073_741_823)!))
        ) == .stop(.remainingUnknownBelowThreshold)
    )
    #expect(
        evaluator.evaluate(
            base.withRemainingUnknown(.measured(threshold))
        ) == .continueInvestigation
    )
    #expect(
        evaluator.evaluate(
            base.withRemainingUnknown(.unmeasurable)
        ) == .continueInvestigation
    )
}

@Test
func investigationStopEvaluatorStopsNoGainOnlyAtTheExactLimit() throws {
    let evaluator = InvestigationStopEvaluator()
    let base = try InvestigationStopFacts.open(
        requestedCoveragePermille: 900,
        remainingUnknownThreshold: ByteCount(1_073_741_824)!,
        consecutiveNoGainLimit: 3
    )

    #expect(
        evaluator.evaluate(
            base.withConsecutiveNoGainSteps(2)
        ) == .continueInvestigation
    )
    #expect(
        evaluator.evaluate(
            base.withConsecutiveNoGainSteps(3)
        ) == .stop(.noEvidenceGain)
    )
    #expect(
        evaluator.evaluate(
            base.withConsecutiveNoGainSteps(4)
        ) == .stop(.noEvidenceGain)
    )
}

@Test
func investigationStopEvaluatorPreservesBudgetQualityAndPauseIsNonterminal()
    throws
{
    let evaluator = InvestigationStopEvaluator()
    let observedDirectTool = InvestigationBudgetExhaustion(
        dimension: .observedDirectToolStarts,
        enforcement: .eventTimeObserved
    )
    let observedTokens = InvestigationBudgetExhaustion(
        dimension: .observedTotalTokens,
        enforcement: .eventTimeObserved
    )
    let base = try InvestigationStopFacts.open(
        requestedCoveragePermille: 900,
        remainingUnknownThreshold: ByteCount(1_073_741_824)!,
        consecutiveNoGainLimit: 3
    )

    #expect(
        evaluator.evaluate(
            base.withObservedBudgetExhaustion(observedDirectTool)
        ) == .stop(.budgetExhausted(observedDirectTool))
    )
    #expect(
        evaluator.evaluate(
            base.withObservedBudgetExhaustion(observedTokens)
                .withTokenUsageQuality(.unavailable)
        ) == .continueInvestigation
    )
    #expect(
        evaluator.evaluate(
            base.withObservedBudgetExhaustion(observedTokens)
                .withTokenUsageQuality(.observed)
        ) == .stop(.budgetExhausted(observedTokens))
    )
    #expect(
        evaluator.evaluate(
            base.withTokenUsageQuality(.unavailable)
        ) == .continueInvestigation
    )
    #expect(
        evaluator.evaluate(
            base.withPauseRequested(true)
        ) == .pause
    )
    #expect(
        evaluator.evaluate(
            base.withPauseRequested(true)
                .withUserCancellationRequested(true)
        ) == .stop(.userCancelled)
    )
}

@Test
func investigationStopFactsRejectMalformedScientificState() {
    let validThreshold = ByteCount(1_073_741_824)!

    for (coverage, requested, noGain, noGainLimit) in [
        (UInt64(1_001), UInt64(900), UInt64(0), UInt64(3)),
        (UInt64(0), UInt64(0), UInt64(0), UInt64(3)),
        (UInt64(0), UInt64(1_001), UInt64(0), UInt64(3)),
        (UInt64(0), UInt64(900), UInt64(0), UInt64(0)),
    ] {
        #expect(throws: InvestigationStopFactsError.invalidFacts) {
            _ = try InvestigationStopFacts(
                safetyLoss: nil,
                userCancellationRequested: false,
                userStopRequested: false,
                hardBudgetExhaustion: nil,
                observedBudgetExhaustion: nil,
                coveragePermille: coverage,
                requestedCoveragePermille: requested,
                remainingUnknown: .unmeasurable,
                remainingUnknownThreshold: validThreshold,
                consecutiveNoGainSteps: noGain,
                consecutiveNoGainLimit: noGainLimit,
                tokenUsageQuality: .unavailable,
                pauseRequested: false
            )
        }
    }
}

@Test
func investigationStopFactsRejectMismatchedBudgetProvenance() throws {
    let base = try InvestigationStopFacts.open(
        requestedCoveragePermille: 900,
        remainingUnknownThreshold: ByteCount(1_073_741_824)!,
        consecutiveNoGainLimit: 3
    )
    let hardObservedDimension = InvestigationBudgetExhaustion(
        dimension: .observedTotalTokens,
        enforcement: .hardAdmission
    )
    let observedHardDimension = InvestigationBudgetExhaustion(
        dimension: .probeCalls,
        enforcement: .eventTimeObserved
    )

    #expect(throws: InvestigationStopFactsError.invalidFacts) {
        _ = try base.replacing(
            hardBudgetExhaustion: hardObservedDimension
        )
    }
    #expect(throws: InvestigationStopFactsError.invalidFacts) {
        _ = try base.replacing(
            observedBudgetExhaustion: observedHardDimension
        )
    }
}

@Test
func investigationStopOutcomesPreserveExactBlockedAndFailedReasons() throws {
    let evaluator = InvestigationStopEvaluator()
    let base = try InvestigationStopFacts.open(
        requestedCoveragePermille: 900,
        remainingUnknownThreshold: ByteCount(1_073_741_824)!,
        consecutiveNoGainLimit: 3
    )

    for reason in InvestigationBlockReason.allCases {
        #expect(
            evaluator.evaluate(base.withBlockReason(reason))
                == .blocked(reason)
        )
    }
    #expect(
        evaluator.evaluate(
            base.withFailure(.terminalPersistenceFailed)
        ) == .failed(.terminalPersistenceFailed)
    )
}

private extension InvestigationStopFacts {
    func withoutSafetyLoss() -> Self {
        replacing(safetyLoss: nil)
    }

    func withFailure(_ value: InvestigationFailureReason?) -> Self {
        replacing(failureReason: value)
    }

    func withBlockReason(_ value: InvestigationBlockReason) -> Self {
        replacing(safetyLoss: value)
    }

    func withoutCancellation() -> Self {
        replacing(userCancellationRequested: false)
    }

    func withoutUserStop() -> Self {
        replacing(userStopRequested: false)
    }

    func withoutHardBudget() -> Self {
        try! replacing(hardBudgetExhaustion: nil)
    }

    func withoutObservedBudget() -> Self {
        try! replacing(observedBudgetExhaustion: nil)
    }

    func withRemainingUnknown(
        _ value: InvestigationRemainingUnknown
    ) -> Self {
        replacing(remainingUnknown: value)
    }

    func withConsecutiveNoGainSteps(_ value: UInt64) -> Self {
        replacing(consecutiveNoGainSteps: value)
    }

    func withObservedBudgetExhaustion(
        _ value: InvestigationBudgetExhaustion
    ) -> Self {
        try! replacing(observedBudgetExhaustion: value)
    }

    func withTokenUsageQuality(
        _ value: InvestigationTokenUsageQuality
    ) -> Self {
        replacing(tokenUsageQuality: value)
    }

    func withPauseRequested(_ value: Bool) -> Self {
        replacing(pauseRequested: value)
    }

    func withUserCancellationRequested(_ value: Bool) -> Self {
        replacing(userCancellationRequested: value)
    }
}
