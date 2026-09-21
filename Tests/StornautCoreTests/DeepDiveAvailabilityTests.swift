import Testing
@testable import StornautCore

@Suite("Deep Dive availability")
struct DeepDiveAvailabilityTests {
    @Test
    func allReadyDimensionsProduceConfigurationAvailabilityOnly() {
        let projection = DeepDiveAvailabilityEvaluator.evaluate(
            readyDimensions()
        )

        #expect(projection.aggregate == .available)
        #expect(projection.normalProductStartEnabled == false)
        #expect(projection.quickScanAvailable)
        #expect(projection.dimensions == readyDimensions())
    }

    @Test(arguments: [
        (DeepDiveSourceReadiness.missing, DeepDiveAggregateAvailability.needsBaselineScan),
        (.stale, .needsBaselineScan),
        (.partial, .needsBaselineScan),
    ])
    func sourceFailuresRemainTyped(
        source: DeepDiveSourceReadiness,
        expected: DeepDiveAggregateAvailability
    ) {
        let dimensions = readyDimensions().replacing(source: source)
        let projection = DeepDiveAvailabilityEvaluator.evaluate(dimensions)

        #expect(projection.aggregate == expected)
        #expect(projection.dimensions.source == source)
        #expect(projection.quickScanAvailable)
    }

    @Test(arguments: [
        (DeepDiveDisclosureReadiness.notPresented, DeepDiveAggregateAvailability.needsDisclosure),
        (.declined, .disclosureDeclined),
        (.obsolete, .needsDisclosure),
    ])
    func disclosureFailuresRemainTyped(
        disclosure: DeepDiveDisclosureReadiness,
        expected: DeepDiveAggregateAvailability
    ) {
        let dimensions = readyDimensions().replacing(
            disclosure: disclosure
        )

        #expect(
            DeepDiveAvailabilityEvaluator.evaluate(dimensions).aggregate
                == expected
        )
    }

    @Test(arguments: [
        DeepDiveCodexReadiness.notInstalled,
        .syntaxUnsupported,
        .authenticationUnavailable,
        .checkFailed,
    ])
    func everyCodexFailureMapsToUnavailable(
        codex: DeepDiveCodexReadiness
    ) {
        let dimensions = readyDimensions().replacing(codex: codex)

        #expect(
            DeepDiveAvailabilityEvaluator.evaluate(dimensions).aggregate
                == .codexUnavailable
        )
        #expect(dimensions.codex == codex)
    }

    @Test(arguments: [
        (DeepDiveRuntimeReadiness.unverified, DeepDiveAggregateAvailability.runtimeBlocked),
        (.failed, .runtimeBlocked),
        (.stale, .runtimeStale),
    ])
    func everyRuntimeFailureRemainsDistinct(
        runtime: DeepDiveRuntimeReadiness,
        expected: DeepDiveAggregateAvailability
    ) {
        let dimensions = readyDimensions().replacing(runtime: runtime)

        #expect(
            DeepDiveAvailabilityEvaluator.evaluate(dimensions).aggregate
                == expected
        )
        #expect(dimensions.runtime == runtime)
    }

    @Test(arguments: [
        DeepDiveDependencyReadiness.task38FacadeUnavailable,
        .storeUnavailable,
        .lifecycleUnavailable,
    ])
    func everyDependencyFailureMapsToUnavailable(
        dependencies: DeepDiveDependencyReadiness
    ) {
        #expect(
            DeepDiveAvailabilityEvaluator.evaluate(
                readyDimensions().replacing(dependencies: dependencies)
            ).aggregate == .dependenciesUnavailable
        )
    }

    @Test(arguments: [
        DeepDiveWorkflowReadiness.quickScanRunning,
        .cleanupExecuting,
        .historyMutationInProgress,
        .settingsMutationInProgress,
    ])
    func everyConflictingWorkflowMapsToBusy(
        workflow: DeepDiveWorkflowReadiness
    ) {
        #expect(
            DeepDiveAvailabilityEvaluator.evaluate(
                readyDimensions().replacing(workflow: workflow)
            ).aggregate == .workflowBusy
        )
    }

    @Test
    func invalidOrMismatchedBudgetMapsToInvalidBudget() {
        #expect(
            DeepDiveAvailabilityEvaluator.evaluate(
                readyDimensions().replacing(budget: .invalid)
            ).aggregate == .invalidBudget
        )
        #expect(
            DeepDiveAvailabilityEvaluator.evaluate(
                readyDimensions().replacing(
                    budget: .valid(
                        preset: .focused,
                        limits: .forPreset(.thorough)
                    )
                )
            ).aggregate == .invalidBudget
        )
    }

    @Test
    func runtimeAndConsentCannotSubstituteForEachOther() {
        let acceptedWithoutRuntime = readyDimensions().replacing(
            runtime: .unverified
        )
        let runtimeWithoutAcceptance = readyDimensions().replacing(
            disclosure: .notPresented
        )

        #expect(
            DeepDiveAvailabilityEvaluator.evaluate(acceptedWithoutRuntime)
                .aggregate == .runtimeBlocked
        )
        #expect(
            DeepDiveAvailabilityEvaluator.evaluate(runtimeWithoutAcceptance)
                .aggregate == .needsDisclosure
        )
    }

    @Test
    func safetyRuntimeStateWinsPresentationWithoutErasingOtherFailures() {
        let dimensions = readyDimensions().replacing(
            source: .missing,
            disclosure: .notPresented,
            runtime: .stale
        )
        let projection = DeepDiveAvailabilityEvaluator.evaluate(dimensions)

        #expect(projection.aggregate == .runtimeStale)
        #expect(projection.dimensions.source == .missing)
        #expect(projection.dimensions.disclosure == .notPresented)
        #expect(projection.dimensions.runtime == .stale)
    }
}

private func readyDimensions() -> DeepDiveAdmissionDimensions {
    DeepDiveAdmissionDimensions(
        source: .ready,
        disclosure: .accepted,
        codex: .available,
        runtime: .admitted,
        dependencies: .available,
        workflow: .idle,
        budget: .valid(
            preset: .balanced,
            limits: .forPreset(.balanced)
        )
    )
}
