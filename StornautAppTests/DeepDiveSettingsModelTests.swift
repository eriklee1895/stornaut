import Foundation
import StornautCore
import Testing
@testable import StornautApp

@Suite("Deep Dive Settings admission projection")
struct DeepDiveSettingsModelTests {
    @Test
    func allReadyDimensionsRemainConfigurationOnlyUntilTask44() throws {
        let model = SettingsModel(
            state: .loaded(
                try SettingsAppTestFactory.snapshot(
                    codex: .installedSupportedAuthenticated,
                    runtimeEvidence: .admitted(
                        SettingsAppTestFactory.runtimeReceipt()
                    ),
                    disclosureReadiness: .accepted,
                    dependencyReadiness: .available
                )
            ),
            latestProjection: try OverviewTestProjectionFactory.projection(
                slug: "settings-deep-dive-ready"
            ),
            workflowReadiness: .idle
        )

        #expect(model.codex.deepDive.dimensions.source == .ready)
        #expect(model.codex.deepDive.dimensions.disclosure == .accepted)
        #expect(model.codex.deepDive.dimensions.codex == .available)
        #expect(model.codex.deepDive.dimensions.runtime == .admitted)
        #expect(model.codex.deepDive.dimensions.dependencies == .available)
        #expect(model.codex.deepDive.dimensions.workflow == .idle)
        #expect(
            model.codex.deepDive.dimensions.budget
                == .valid(
                    preset: .balanced,
                    limits: .forPreset(.balanced)
                )
        )
        #expect(model.codex.deepDive.aggregate == .available)
        #expect(model.codex.deepDive.safetyRuntimeVerified)
        #expect(model.codex.deepDive.productFlowAdmissionPending)
        #expect(model.codex.deepDive.normalProductStartEnabled == false)
        #expect(model.codex.deepDive.quickScanAvailable)
    }

    @Test
    func sourceDisclosureAndRuntimeCannotSubstituteForEachOther() throws {
        let baseline = try OverviewTestProjectionFactory.projection(
            slug: "settings-deep-dive-independent"
        )
        let receipt = SettingsAppTestFactory.runtimeReceipt()
        let noConsent = SettingsModel(
            state: .loaded(
                try SettingsAppTestFactory.snapshot(
                    codex: .installedSupportedAuthenticated,
                    runtimeEvidence: .admitted(receipt),
                    disclosureReadiness: .notPresented,
                    dependencyReadiness: .available
                )
            ),
            latestProjection: baseline
        )
        let noRuntime = SettingsModel(
            state: .loaded(
                try SettingsAppTestFactory.snapshot(
                    codex: .installedSupportedAuthenticated,
                    runtimeEvidence: .unverified,
                    disclosureReadiness: .accepted,
                    dependencyReadiness: .available
                )
            ),
            latestProjection: baseline
        )
        let noBaseline = SettingsModel(
            state: .loaded(
                try SettingsAppTestFactory.snapshot(
                    codex: .installedSupportedAuthenticated,
                    runtimeEvidence: .admitted(receipt),
                    disclosureReadiness: .accepted,
                    dependencyReadiness: .available
                )
            ),
            latestProjection: nil
        )

        #expect(noConsent.codex.deepDive.aggregate == .needsDisclosure)
        #expect(noRuntime.codex.deepDive.aggregate == .runtimeBlocked)
        #expect(noBaseline.codex.deepDive.aggregate == .needsBaselineScan)
    }

    @Test
    func safetyFailurePrecedenceRetainsEveryUnderlyingDimension() throws {
        let model = SettingsModel(
            state: .loaded(
                try SettingsAppTestFactory.snapshot(
                    codex: .unavailable,
                    runtimeEvidence: .stale(nil),
                    disclosureReadiness: .declined,
                    dependencyReadiness: .storeUnavailable
                )
            ),
            latestProjection: nil,
            workflowReadiness: .settingsMutationInProgress,
            budgetReadiness: .invalid
        )

        #expect(model.codex.deepDive.aggregate == .runtimeStale)
        #expect(model.codex.deepDive.dimensions.source == .missing)
        #expect(model.codex.deepDive.dimensions.disclosure == .declined)
        #expect(model.codex.deepDive.dimensions.codex == .notInstalled)
        #expect(model.codex.deepDive.dimensions.runtime == .stale)
        #expect(
            model.codex.deepDive.dimensions.dependencies
                == .storeUnavailable
        )
        #expect(
            model.codex.deepDive.dimensions.workflow
                == .settingsMutationInProgress
        )
        #expect(model.codex.deepDive.dimensions.budget == .invalid)
    }

    @Test(arguments: [
        (DeepDiveAggregateAvailability.needsBaselineScan, SettingsDeepDiveRepairAction.runQuickScan),
        (.needsDisclosure, .reviewDisclosure),
        (.disclosureDeclined, .reviewDisclosure),
        (.codexUnavailable, .checkCodexAgain),
        (.runtimeBlocked, .runSafetyCheck),
        (.runtimeStale, .runSafetyCheck),
        (.invalidBudget, .chooseBudget),
    ])
    func aggregateStateOffersOnlyItsSafePrimaryRepair(
        aggregate: DeepDiveAggregateAvailability,
        action: SettingsDeepDiveRepairAction
    ) {
        #expect(
            SettingsDeepDiveRepairActions.primary(for: aggregate) == action
        )
    }

    @Test
    func disclosureProjectionIsVersionedActionableAndAggregate() throws {
        let model = SettingsModel(
            state: .loaded(
                try SettingsAppTestFactory.snapshot(
                    disclosureReadiness: .accepted
                )
            ),
            latestProjection: nil
        )

        #expect(
            model.codex.disclosure.version.rawValue
                == "deep-dive-disclosure-v1"
        )
        #expect(model.codex.disclosure.items.count == 9)
        #expect(model.codex.disclosure.canReview)
        #expect(model.codex.disclosure.canAccept)
        #expect(model.codex.disclosure.canForget)
        #expect(model.codex.hasProviderSelector == false)
        #expect(model.codex.hasArbitraryCLIFlags == false)
        #expect(model.codex.hasSafetyBypass == false)
    }
}
