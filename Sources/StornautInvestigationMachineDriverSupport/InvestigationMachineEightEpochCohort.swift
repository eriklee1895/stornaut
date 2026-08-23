import Foundation
import StornautInvestigationHandoffContract

package enum InvestigationMachineEightEpochCohortError:
    Error, Sendable, Equatable
{
    case alreadyConsumed
    case invalidSelection
    case reusedExecution
    case planNotExhausted
    case cancelled
}

protocol InvestigationMachineEightEpochPlan: Sendable {
    func takeNext() async throws -> InvestigationMachineFixedEpochSelection
}

extension InvestigationMachineFixedEpochPlan:
    InvestigationMachineEightEpochPlan {}

package protocol InvestigationMachineEightEpochExecutionFactory: Sendable {
    func makeExecution(
        for selection: InvestigationMachineFixedEpochSelection,
        mode: InvestigationMachineOuterContainmentMode
    ) async throws -> InvestigationMachineEightEpochExecution
}

package final class InvestigationMachineEightEpochExecution:
    @unchecked Sendable
{
    private let selection: InvestigationMachineFixedEpochSelection
    private let mode: InvestigationMachineOuterContainmentMode
    private let composer: any InvestigationMachineSingleEpochComposing
    private let prover: any InvestigationMachineOuterContainmentProving
    private let lock = NSLock()
    private var consumed = false

    init(
        selection: InvestigationMachineFixedEpochSelection,
        mode: InvestigationMachineOuterContainmentMode,
        composer: any InvestigationMachineSingleEpochComposing,
        prover: any InvestigationMachineOuterContainmentProving
    ) {
        self.selection = selection
        self.mode = mode
        self.composer = composer
        self.prover = prover
    }

    fileprivate func consume(
        for expectedSelection: InvestigationMachineFixedEpochSelection,
        mode expectedMode: InvestigationMachineOuterContainmentMode
    ) throws -> (
        composer: any InvestigationMachineSingleEpochComposing,
        prover: any InvestigationMachineOuterContainmentProving
    ) {
        try lock.withLock {
            guard !consumed else {
                throw InvestigationMachineEightEpochCohortError.reusedExecution
            }
            consumed = true
            guard
                selection == expectedSelection,
                mode == expectedMode,
                composer.isBound(to: expectedSelection)
            else {
                throw InvestigationMachineEightEpochCohortError.invalidSelection
            }
            return (composer, prover)
        }
    }
}

package struct InvestigationMachineEightEpochCompletionSummary:
    Sendable, Equatable
{
    package let outerAttemptUUID: UUID
    package let wholeCapsuleSHA256: InvestigationHandoffSHA256
    package let wholeInputSHA256: InvestigationHandoffSHA256
    package let completedEpochCount: UInt32
}

package actor InvestigationMachineEightEpochCohort {
    private enum State {
        case ready
        case running
        case terminal
    }

    private let plan: any InvestigationMachineEightEpochPlan
    private let executionFactory:
        any InvestigationMachineEightEpochExecutionFactory
    private var state = State.ready

    package init(
        plan: InvestigationMachineFixedEpochPlan,
        executionFactory: any InvestigationMachineEightEpochExecutionFactory
    ) {
        self.plan = plan
        self.executionFactory = executionFactory
    }

    init(
        plan: any InvestigationMachineEightEpochPlan,
        executionFactory: any InvestigationMachineEightEpochExecutionFactory
    ) {
        self.plan = plan
        self.executionFactory = executionFactory
    }

    package func run() async throws
        -> InvestigationMachineEightEpochCompletionSummary
    {
        guard case .ready = state else {
            throw InvestigationMachineEightEpochCohortError.alreadyConsumed
        }
        state = .running
        defer { state = .terminal }

        var expectedOuterAttemptUUID: UUID?
        var expectedCapsuleSHA256: InvestigationHandoffSHA256?
        var expectedInputSHA256: InvestigationHandoffSHA256?
        var continuity: InvestigationMachineHelperEpochContinuity?
        var finalSelection: InvestigationMachineFixedEpochSelection?
        var usedExecutions = Set<ObjectIdentifier>()
        // Retention makes object identity meaningful for the whole cohort; an
        // allocator cannot recycle an earlier wrapper address between epochs.
        var retainedExecutions = [InvestigationMachineEightEpochExecution]()
        var cohortIdentifiers = Set<UUID>()

        for index in 0..<InvestigationCohortCapsule.epochCount {
            guard !Task.isCancelled else {
                throw InvestigationMachineEightEpochCohortError.cancelled
            }
            let selection = try await plan.takeNext()
            guard !Task.isCancelled else {
                throw InvestigationMachineEightEpochCohortError.cancelled
            }
            try validate(
                selection, expectedIndex: index,
                expectedOuterAttemptUUID: expectedOuterAttemptUUID,
                expectedCapsuleSHA256: expectedCapsuleSHA256,
                expectedInputSHA256: expectedInputSHA256,
                cohortIdentifiers: &cohortIdentifiers
            )
            if expectedOuterAttemptUUID == nil {
                expectedOuterAttemptUUID = selection.outerAttemptUUID
                expectedCapsuleSHA256 = selection.wholeCapsuleSHA256
                expectedInputSHA256 = selection.wholeInputSHA256
                continuity = try InvestigationMachineHelperEpochContinuity
                    .genesis(for: selection)
            }

            let mode = containmentMode(for: selection.epoch.scenario)
            let execution = try await executionFactory.makeExecution(
                for: selection, mode: mode
            )
            guard !Task.isCancelled else {
                throw InvestigationMachineEightEpochCohortError.cancelled
            }
            guard usedExecutions.insert(ObjectIdentifier(execution)).inserted
            else {
                throw InvestigationMachineEightEpochCohortError.reusedExecution
            }
            retainedExecutions.append(execution)
            let dependencies = try execution.consume(
                for: selection, mode: mode
            )
            guard let predecessor = continuity else {
                throw InvestigationMachineEightEpochCohortError.invalidSelection
            }
            let outerJoin = InvestigationMachineOuterCompletionJoin(
                prover: dependencies.prover
            )
            let composition = InvestigationMachineSingleEpochComposition(
                selection: selection, predecessor: predecessor,
                composer: dependencies.composer, outerJoin: outerJoin
            )
            continuity = try await composition.run()
            finalSelection = selection
        }

        guard
            let finalContinuity = continuity,
            let finalSelection,
            let outerAttemptUUID = expectedOuterAttemptUUID,
            let wholeCapsuleSHA256 = expectedCapsuleSHA256,
            let wholeInputSHA256 = expectedInputSHA256
        else {
            throw InvestigationMachineEightEpochCohortError.invalidSelection
        }
        try finalContinuity.destroyAfterFinal(selection: finalSelection)
        do {
            _ = try await plan.takeNext()
            throw InvestigationMachineEightEpochCohortError.planNotExhausted
        } catch let error as InvestigationMachineFixedCapsuleIntakeError {
            guard error == InvestigationMachineFixedCapsuleIntakeError.exhausted
            else { throw error }
        }
        guard !Task.isCancelled else {
            throw InvestigationMachineEightEpochCohortError.cancelled
        }
        return InvestigationMachineEightEpochCompletionSummary(
            outerAttemptUUID: outerAttemptUUID,
            wholeCapsuleSHA256: wholeCapsuleSHA256,
            wholeInputSHA256: wholeInputSHA256,
            completedEpochCount: UInt32(InvestigationCohortCapsule.epochCount)
        )
    }

    private func validate(
        _ selection: InvestigationMachineFixedEpochSelection,
        expectedIndex: Int,
        expectedOuterAttemptUUID: UUID?,
        expectedCapsuleSHA256: InvestigationHandoffSHA256?,
        expectedInputSHA256: InvestigationHandoffSHA256?,
        cohortIdentifiers: inout Set<UUID>
    ) throws {
        guard
            selection.epoch.ordinal == UInt32(expectedIndex),
            selection.epoch.scenario.rawValue
                == selection.epoch.ordinal + 1,
            selection.projection.epochUUID == selection.epoch.epochUUID,
            selection.projection.configurationNonce
                == selection.epoch.configurationNonce,
            selection.projection.configurationSHA256
                == selection.epoch.configurationSHA256,
            selection.projection.signedRuntimeBindingSHA256
                == selection.epoch.signedRuntimeBindingSHA256,
            selection.outerAttemptUUID != zeroUUID,
            selection.wholeCapsuleSHA256.rawBytes.contains(where: { $0 != 0 }),
            selection.wholeInputSHA256.rawBytes.contains(where: { $0 != 0 }),
            expectedOuterAttemptUUID == nil
                || selection.outerAttemptUUID == expectedOuterAttemptUUID,
            expectedCapsuleSHA256 == nil
                || selection.wholeCapsuleSHA256 == expectedCapsuleSHA256,
            expectedInputSHA256 == nil
                || selection.wholeInputSHA256 == expectedInputSHA256
        else {
            throw InvestigationMachineEightEpochCohortError.invalidSelection
        }
        if expectedOuterAttemptUUID == nil {
            guard cohortIdentifiers.insert(selection.outerAttemptUUID).inserted
            else {
                throw InvestigationMachineEightEpochCohortError.invalidSelection
            }
        }
        guard
            cohortIdentifiers.insert(selection.epoch.epochUUID).inserted,
            cohortIdentifiers.insert(selection.epoch.configurationNonce).inserted
        else {
            throw InvestigationMachineEightEpochCohortError.invalidSelection
        }
    }

    private func containmentMode(
        for scenario: InvestigationHandoffScenario
    ) -> InvestigationMachineOuterContainmentMode {
        switch scenario {
        case .lifecycleRecovery: .parentCrash
        case .success, .cancellation, .timeout, .invalidEnvelope,
             .identityMismatch, .transportLoss, .artifactCleanupFailure:
            .normal
        }
    }

    private var zeroUUID: UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    }
}
