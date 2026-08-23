import Foundation
import Testing

@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationInstalledL2
@testable import StornautInvestigationMachineDriverSupport

@Suite("Investigation machine eight-epoch cohort", .serialized)
struct InvestigationMachineEightEpochCohortTests {
    @Test
    func eightOrderedEpochsProduceExactSummaryAndExhaustion() async throws {
        let fixture = try EightEpochFixture()
        let plan = ScriptedEightEpochPlan(selections: fixture.selections)
        let factory = ScriptedEightEpochFactory(fixtures: fixture.epochs)
        let cohort = InvestigationMachineEightEpochCohort(
            plan: plan, executionFactory: factory
        )

        let summary = try await cohort.run()
        let snapshot = factory.snapshot()

        #expect(summary.outerAttemptUUID == fixture.cohort.outerAttemptUUID)
        #expect(summary.wholeCapsuleSHA256 == fixture.cohort.capsuleSHA256)
        #expect(summary.wholeInputSHA256 == fixture.cohort.inputSHA256)
        #expect(summary.completedEpochCount == 8)
        #expect(!(InvestigationMachineEightEpochCompletionSummary.self
            is any Codable.Type))
        #expect(await plan.readCount == 9)
        #expect(snapshot.calls.map(\.ordinal) == Array(UInt32(0)...7))
        #expect(snapshot.calls.map(\.scenario)
            == InvestigationHandoffScenario.allCases)
        #expect(snapshot.calls.map(\.mode) == [
            .normal, .normal, .normal, .normal,
            .normal, .normal, .parentCrash, .normal,
        ])
        #expect(snapshot.executionIdentifiers.count == 8)
        #expect(Set(snapshot.executionIdentifiers).count == 8)
        #expect(snapshot.composerRunCounts == Array(repeating: 1, count: 8))
        #expect(snapshot.proverCallCounts == Array(repeating: 1, count: 8))
        for index in fixture.epochs.indices {
            let expectedPrevious = index == 0
                ? nil : fixture.epochs[index - 1].helperIdentity
            #expect(snapshot.previousHelpers[index] == [expectedPrevious])
        }
    }

    @Test
    func ninthSelectionInsteadOfExhaustionFailsClosed() async throws {
        let fixture = try EightEpochFixture()
        let plan = ScriptedEightEpochPlan(
            selections: fixture.selections,
            terminal: .selection(fixture.selections[7])
        )
        let factory = ScriptedEightEpochFactory(fixtures: fixture.epochs)
        let cohort = InvestigationMachineEightEpochCohort(
            plan: plan, executionFactory: factory
        )

        #expect(
            await observedError { _ = try await cohort.run() }
                == .cohort(.planNotExhausted)
        )
        #expect(await plan.readCount == 9)
        #expect(factory.snapshot().calls.count == 8)
        #expect(
            await observedError { _ = try await cohort.run() }
                == .cohort(.alreadyConsumed)
        )
    }

    @Test
    func ninthPlanFailureIsPreservedAndCohortStaysTerminal() async throws {
        let fixture = try EightEpochFixture()
        let plan = ScriptedEightEpochPlan(
            selections: fixture.selections, terminal: .failure(.plan)
        )
        let cohort = InvestigationMachineEightEpochCohort(
            plan: plan,
            executionFactory: ScriptedEightEpochFactory(fixtures: fixture.epochs)
        )

        #expect(await observedError { _ = try await cohort.run() }
            == .test(.plan))
        #expect(await plan.readCount == 9)
        #expect(await observedError { _ = try await cohort.run() }
            == .cohort(.alreadyConsumed))
    }

    @Test
    func concurrentAndRepeatedRunHaveExactlyOneWinner() async throws {
        let fixture = try EightEpochFixture()
        let gate = EightEpochGate()
        let plan = ScriptedEightEpochPlan(selections: fixture.selections)
        let factory = ScriptedEightEpochFactory(
            fixtures: fixture.epochs, composerGateOrdinal: 0, gate: gate
        )
        let cohort = InvestigationMachineEightEpochCohort(
            plan: plan, executionFactory: factory
        )
        let first = Task { try await cohort.run() }

        await gate.waitUntilEntered()
        #expect(
            await observedError { _ = try await cohort.run() }
                == .cohort(.alreadyConsumed)
        )
        await gate.open()
        #expect(try await first.value.completedEpochCount == 8)
        #expect(
            await observedError { _ = try await cohort.run() }
                == .cohort(.alreadyConsumed)
        )
        #expect(factory.snapshot().composerRunCounts.reduce(0, +) == 8)
    }

    @Test
    func cancellationBeforeRunConsumesWithoutReadingThePlan() async throws {
        let fixture = try EightEpochFixture()
        let plan = ScriptedEightEpochPlan(selections: fixture.selections)
        let factory = ScriptedEightEpochFactory(fixtures: fixture.epochs)
        let cohort = InvestigationMachineEightEpochCohort(
            plan: plan, executionFactory: factory
        )
        let operation = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await cohort.run()
        }

        #expect(await observedError { _ = try await operation.value }
            == .cohort(.cancelled))
        #expect(await plan.readCount == 0)
        #expect(factory.snapshot().calls.isEmpty)
        #expect(await observedError { _ = try await cohort.run() }
            == .cohort(.alreadyConsumed))
    }

    @Test(arguments: EightEpochFailureCase.allCases)
    fileprivate func everyFailureIsTerminalAndDoesNotPrefetch(
        _ failure: EightEpochFailureCase
    ) async throws {
        let fixture = try EightEpochFixture()
        let plan = ScriptedEightEpochPlan(
            selections: fixture.selections,
            failureIndex: failure == .plan ? failure.index : nil
        )
        let factory = ScriptedEightEpochFactory(
            fixtures: fixture.epochs, failure: failure
        )
        let cohort = InvestigationMachineEightEpochCohort(
            plan: plan, executionFactory: factory
        )

        #expect(await observedError { _ = try await cohort.run() }
            == failure.expectedError)
        let snapshot = factory.snapshot()
        #expect(await plan.readCount == failure.index + 1)
        #expect(snapshot.calls.allSatisfy { Int($0.ordinal) <= failure.index })
        #expect(snapshot.calls.count == failure.expectedFactoryCallCount)
        #expect(snapshot.composerRunCounts.reduce(0, +)
            == failure.expectedComposerRunCount)
        #expect(snapshot.proverCallCounts.reduce(0, +)
            == failure.expectedProverCallCount)
        #expect(await observedError { _ = try await cohort.run() }
            == .cohort(.alreadyConsumed))
    }

    @Test(arguments: EightEpochSelectionMutation.allCases)
    fileprivate func selectionBindingDriftStopsBeforeFactoryAndPrefetch(
        _ mutation: EightEpochSelectionMutation
    ) async throws {
        let fixture = try EightEpochFixture()
        var selections = fixture.selections
        selections[3] = try mutation.apply(to: fixture, at: 3)
        let plan = ScriptedEightEpochPlan(selections: selections)
        let factory = ScriptedEightEpochFactory(fixtures: fixture.epochs)
        let cohort = InvestigationMachineEightEpochCohort(
            plan: plan, executionFactory: factory
        )

        #expect(await observedError { _ = try await cohort.run() }
            == .cohort(.invalidSelection))
        let snapshot = factory.snapshot()
        #expect(await plan.readCount == 4)
        #expect(snapshot.calls.map(\.ordinal) == [0, 1, 2])
        #expect(snapshot.composerRunCounts.reduce(0, +) == 3)
        #expect(snapshot.proverCallCounts.reduce(0, +) == 3)
    }

    @Test
    func cancellationAfterSelectionStopsBeforeFactoryOrPrefetch() async throws {
        let fixture = try EightEpochFixture()
        let gate = EightEpochGate()
        let plan = ScriptedEightEpochPlan(
            selections: fixture.selections, gateIndex: 3, gate: gate
        )
        let factory = ScriptedEightEpochFactory(fixtures: fixture.epochs)
        let cohort = InvestigationMachineEightEpochCohort(
            plan: plan, executionFactory: factory
        )
        let operation = Task { try await cohort.run() }

        await gate.waitUntilEntered()
        operation.cancel()
        await gate.open()

        #expect(await observedError { _ = try await operation.value }
            == .cohort(.cancelled))
        #expect(await plan.readCount == 4)
        #expect(factory.snapshot().calls.map(\.ordinal) == [0, 1, 2])
    }

    @Test
    func cancellationAfterFactoryStopsBeforeExecutionOrPrefetch() async throws {
        let fixture = try EightEpochFixture()
        let gate = EightEpochGate()
        let plan = ScriptedEightEpochPlan(selections: fixture.selections)
        let factory = ScriptedEightEpochFactory(
            fixtures: fixture.epochs, factoryGateOrdinal: 3, gate: gate
        )
        let cohort = InvestigationMachineEightEpochCohort(
            plan: plan, executionFactory: factory
        )
        let operation = Task { try await cohort.run() }

        await gate.waitUntilEntered()
        operation.cancel()
        await gate.open()

        #expect(await observedError { _ = try await operation.value }
            == .cohort(.cancelled))
        #expect(await plan.readCount == 4)
        #expect(factory.snapshot().calls.map(\.ordinal) == [0, 1, 2, 3])
        #expect(factory.snapshot().composerRunCounts.reduce(0, +) == 3)
    }

    @Test
    func cancellationAfterExactExhaustionCannotReturnSuccess() async throws {
        let fixture = try EightEpochFixture()
        let gate = EightEpochGate()
        let plan = ScriptedEightEpochPlan(
            selections: fixture.selections, gateIndex: 8, gate: gate
        )
        let factory = ScriptedEightEpochFactory(fixtures: fixture.epochs)
        let cohort = InvestigationMachineEightEpochCohort(
            plan: plan, executionFactory: factory
        )
        let operation = Task { try await cohort.run() }

        await gate.waitUntilEntered()
        operation.cancel()
        await gate.open()

        #expect(await observedError { _ = try await operation.value }
            == .cohort(.cancelled))
        #expect(await plan.readCount == 9)
        #expect(factory.snapshot().composerRunCounts.reduce(0, +) == 8)
    }

    @Test(arguments: EightEpochExternalPriority.allCases)
    fileprivate func externalContainmentFailureOutranksCallerCancellation(
        _ priority: EightEpochExternalPriority
    ) async throws {
        let fixture = try EightEpochFixture()
        let proofGate = EightEpochProofGate()
        let plan = ScriptedEightEpochPlan(selections: fixture.selections)
        let factory = ScriptedEightEpochFactory(
            fixtures: fixture.epochs, proofGateOrdinal: 0, proofGate: proofGate
        )
        let cohort = InvestigationMachineEightEpochCohort(
            plan: plan, executionFactory: factory
        )
        let operation = Task { try await cohort.run() }

        await proofGate.waitUntilEntered()
        operation.cancel()
        await proofGate.release(try await priority.outcome(fixture: fixture))

        #expect(await observedError { _ = try await operation.value }
            == priority.expectedError)
        #expect(await proofGate.observedCancellation == [false])
        #expect(await plan.readCount == 1)
        #expect(factory.snapshot().calls.map(\.ordinal) == [0])
    }

    @Test
    func exactOrdinalSevenContinuityDestroysOnce() async throws {
        let fixture = try EightEpochFixture()
        let continuity = try await fixture.continuity(through: 7)

        try continuity.destroyAfterFinal(selection: fixture.selections[7])
        #expect(throws: InvestigationMachineHelperEpochContinuityError
            .alreadyConsumed) {
            try continuity.destroyAfterFinal(selection: fixture.selections[7])
        }
    }

    @Test(arguments: EightEpochInvalidFinalDestroy.allCases)
    fileprivate func finalDestroyRejectsGenesisEarlierAndForeignSelection(
        _ invalid: EightEpochInvalidFinalDestroy
    ) async throws {
        let fixture = try EightEpochFixture()
        let continuity: InvestigationMachineHelperEpochContinuity
        let selection: InvestigationMachineFixedEpochSelection
        switch invalid {
        case .genesis:
            continuity = try .genesis(for: fixture.selections[0])
            selection = fixture.selections[0]
        case .earlierSuccessor:
            continuity = try await fixture.continuity(through: 5)
            selection = fixture.selections[5]
        case .foreignFinalSelection:
            continuity = try await fixture.continuity(through: 7)
            selection = try EightEpochFixture(
                cohort: .foreign
            ).selections[7]
        }

        #expect(throws: InvestigationMachineHelperEpochContinuityError
            .invalidCompletion) {
            try continuity.destroyAfterFinal(selection: selection)
        }
        #expect(throws: InvestigationMachineHelperEpochContinuityError
            .alreadyConsumed) {
            try continuity.destroyAfterFinal(selection: selection)
        }
    }
}

private enum EightEpochTestError: Error, Sendable, Equatable {
    case plan
    case factory
    case composer
}

private enum EightEpochObservedError: Equatable {
    case cohort(InvestigationMachineEightEpochCohortError)
    case continuity(InvestigationMachineHelperEpochContinuityError)
    case test(EightEpochTestError)
    case intake(InvestigationMachineFixedCapsuleIntakeError)
    case other(String)
}

private func observedError<Result>(
    _ operation: () async throws -> Result
) async -> EightEpochObservedError? {
    do {
        _ = try await operation()
        return nil
    } catch let error as InvestigationMachineEightEpochCohortError {
        return .cohort(error)
    } catch let error as InvestigationMachineHelperEpochContinuityError {
        return .continuity(error)
    } catch let error as EightEpochTestError {
        return .test(error)
    } catch let error as InvestigationMachineFixedCapsuleIntakeError {
        return .intake(error)
    } catch {
        return .other(String(reflecting: error))
    }
}

private enum EightEpochFailureCase: CaseIterable {
    case plan
    case factory
    case composer
    case containmentUncertain
    case misboundExecution
    case reusedExecution
    case misboundMode
    case transferredNormal
    case localLifecycle

    var index: Int {
        switch self {
        case .plan: 0
        case .reusedExecution: 1
        case .factory, .misboundExecution, .misboundMode,
             .transferredNormal: 3
        case .localLifecycle: 6
        case .composer, .containmentUncertain: 7
        }
    }

    var expectedError: EightEpochObservedError {
        switch self {
        case .plan: .test(.plan)
        case .factory: .test(.factory)
        case .composer: .test(.composer)
        case .containmentUncertain: .continuity(.containmentUncertain)
        case .misboundExecution: .cohort(.invalidSelection)
        case .reusedExecution: .cohort(.reusedExecution)
        case .misboundMode: .cohort(.invalidSelection)
        case .transferredNormal, .localLifecycle:
            .continuity(.invalidCompletion)
        }
    }

    var expectedFactoryCallCount: Int {
        self == .plan ? index : index + 1
    }

    var expectedComposerRunCount: Int {
        switch self {
        case .plan, .factory, .misboundExecution, .misboundMode,
             .reusedExecution: index
        case .composer, .containmentUncertain, .transferredNormal,
             .localLifecycle: index + 1
        }
    }

    var expectedProverCallCount: Int {
        switch self {
        case .plan, .factory, .composer, .misboundExecution, .misboundMode,
             .reusedExecution, .transferredNormal, .localLifecycle:
            index
        case .containmentUncertain:
            index + 1
        }
    }
}

private enum EightEpochSelectionMutation: CaseIterable {
    case ordinalAndScenarioOrder
    case outerAttempt
    case capsuleDigest
    case inputDigest
    case projectionEpoch
    case projectionNonce
    case projectionConfigurationDigest
    case projectionRuntimeDigest
    case duplicateEpochUUID
    case duplicateConfigurationNonce

    func apply(
        to fixture: EightEpochFixture, at index: Int
    ) throws -> InvestigationMachineFixedEpochSelection {
        if self == .ordinalAndScenarioOrder {
            return fixture.selections[index + 1]
        }
        let original = fixture.selections[index]
        if self == .duplicateEpochUUID || self == .duplicateConfigurationNonce {
            let epoch = try InvestigationCohortEpoch(
                ordinal: original.epoch.ordinal,
                epochUUID: self == .duplicateEpochUUID
                    ? fixture.selections[0].epoch.epochUUID
                    : original.epoch.epochUUID,
                scenario: original.epoch.scenario,
                configurationNonce: self == .duplicateConfigurationNonce
                    ? fixture.selections[0].epoch.configurationNonce
                    : original.epoch.configurationNonce,
                configuration: original.epoch.configuration,
                configurationSHA256: original.epoch.configurationSHA256,
                signedRuntimeBindingSHA256:
                    original.epoch.signedRuntimeBindingSHA256
            )
            return .init(
                outerAttemptUUID: original.outerAttemptUUID,
                wholeCapsuleSHA256: original.wholeCapsuleSHA256,
                wholeInputSHA256: original.wholeInputSHA256, epoch: epoch,
                projection: try fixture.projection(for: epoch)
            )
        }
        let projection: InvestigationInstalledL2IdentityProjection
        switch self {
        case .projectionEpoch:
            projection = try fixture.projection(
                for: original.epoch, epochUUID: EightEpochFixture.uuid(0xd1)
            )
        case .projectionNonce:
            projection = try fixture.projection(
                for: original.epoch, configurationNonce: EightEpochFixture.uuid(0xd2)
            )
        case .projectionConfigurationDigest:
            projection = try fixture.projection(
                for: original.epoch,
                configurationSHA256: EightEpochFixture.digest(0xd3)
            )
        case .projectionRuntimeDigest:
            projection = try fixture.projection(
                for: original.epoch,
                signedRuntimeBindingSHA256: EightEpochFixture.digest(0xd4)
            )
        case .ordinalAndScenarioOrder, .outerAttempt, .capsuleDigest, .inputDigest,
             .duplicateEpochUUID, .duplicateConfigurationNonce:
            projection = original.projection
        }
        return InvestigationMachineFixedEpochSelection(
            outerAttemptUUID: self == .outerAttempt
                ? EightEpochFixture.uuid(0xe1) : original.outerAttemptUUID,
            wholeCapsuleSHA256: self == .capsuleDigest
                ? try EightEpochFixture.digest(0xe2)
                : original.wholeCapsuleSHA256,
            wholeInputSHA256: self == .inputDigest
                ? try EightEpochFixture.digest(0xe3)
                : original.wholeInputSHA256,
            epoch: original.epoch, projection: projection
        )
    }
}

private enum EightEpochExternalPriority: CaseIterable {
    case uncertainty
    case foreignProof
    case exactProof

    var expectedError: EightEpochObservedError {
        switch self {
        case .uncertainty: .continuity(.containmentUncertain)
        case .foreignProof: .continuity(.invalidCompletion)
        case .exactProof: .continuity(.cancelled)
        }
    }

    func outcome(
        fixture: EightEpochFixture
    ) async throws -> InvestigationMachineOuterContainmentOutcome {
        switch self {
        case .uncertainty:
            return .terminalUncertain
        case .foreignProof:
            let foreign = try EightEpochFixture(cohort: .foreign)
            let epoch = foreign.epochs[0]
            let predecessor = try InvestigationMachineHelperEpochContinuity
                .genesis(for: epoch.selection)
                .consume(for: epoch.selection)
            return .contained(try InvestigationMachineOuterContainmentProof(
                selection: epoch.selection, result: epoch.result,
                predecessor: predecessor,
                terminalProofSHA256: EightEpochFixture.digest(0xf1)
            ))
        case .exactProof:
            let epoch = fixture.epochs[0]
            let predecessor = try InvestigationMachineHelperEpochContinuity
                .genesis(for: epoch.selection)
                .consume(for: epoch.selection)
            return .contained(try InvestigationMachineOuterContainmentProof(
                selection: epoch.selection, result: epoch.result,
                predecessor: predecessor,
                terminalProofSHA256: EightEpochFixture.digest(0xf2)
            ))
        }
    }
}

private enum EightEpochInvalidFinalDestroy: CaseIterable {
    case genesis
    case earlierSuccessor
    case foreignFinalSelection
}

private struct EightEpochFactoryCall: Sendable, Equatable {
    let ordinal: UInt32
    let scenario: InvestigationHandoffScenario
    let mode: InvestigationMachineOuterContainmentMode
}

private struct EightEpochFactorySnapshot {
    let calls: [EightEpochFactoryCall]
    let executionIdentifiers: [ObjectIdentifier]
    let composerRunCounts: [Int]
    let previousHelpers: [[InvestigationMachineProcessIdentity?]]
    let proverCallCounts: [Int]
}

private final class ScriptedEightEpochFactory:
    InvestigationMachineEightEpochExecutionFactory, @unchecked Sendable
{
    private let fixtures: [EightEpochEpochFixture]
    private let failure: EightEpochFailureCase?
    private let composerGateOrdinal: Int?
    private let factoryGateOrdinal: Int?
    private let proofGateOrdinal: Int?
    private let gate: EightEpochGate?
    private let proofGate: EightEpochProofGate?
    private let lock = NSLock()
    private var calls: [EightEpochFactoryCall] = []
    private var executions: [InvestigationMachineEightEpochExecution] = []
    private var returnedExecutionIdentifiers: [ObjectIdentifier] = []
    private var composers: [EightEpochComposer] = []
    private var provers: [EightEpochProver] = []

    init(
        fixtures: [EightEpochEpochFixture],
        failure: EightEpochFailureCase? = nil,
        composerGateOrdinal: Int? = nil,
        factoryGateOrdinal: Int? = nil,
        proofGateOrdinal: Int? = nil,
        gate: EightEpochGate? = nil,
        proofGate: EightEpochProofGate? = nil
    ) {
        self.fixtures = fixtures
        self.failure = failure
        self.composerGateOrdinal = composerGateOrdinal
        self.factoryGateOrdinal = factoryGateOrdinal
        self.proofGateOrdinal = proofGateOrdinal
        self.gate = gate
        self.proofGate = proofGate
    }

    func makeExecution(
        for selection: InvestigationMachineFixedEpochSelection,
        mode: InvestigationMachineOuterContainmentMode
    ) async throws -> InvestigationMachineEightEpochExecution {
        let index = Int(selection.epoch.ordinal)
        lock.withLock {
            calls.append(.init(
                ordinal: selection.epoch.ordinal,
                scenario: selection.epoch.scenario, mode: mode
            ))
        }
        if index == factoryGateOrdinal, let gate { await gate.suspend() }
        if failure == .factory, index == failure?.index {
            throw EightEpochTestError.factory
        }
        if failure == .reusedExecution, index == failure?.index {
            return lock.withLock {
                let reused = executions[0]
                returnedExecutionIdentifiers.append(ObjectIdentifier(reused))
                return reused
            }
        }

        let fixture = fixtures[index]
        let result: InvestigationMachineSingleEpochResult
        if failure == .transferredNormal, index == failure?.index {
            result = .ownershipTransferred(fixture.ownership)
        } else if failure == .localLifecycle, index == failure?.index {
            result = .localCompletion(fixture.localCompletion)
        } else {
            result = fixture.result
        }
        let composer = EightEpochComposer(
            selection: selection, result: result,
            failure: failure == .composer && index == failure?.index,
            gate: index == composerGateOrdinal ? gate : nil
        )
        let regularProver = EightEpochProver(
            behavior: failure == .containmentUncertain
                && index == failure?.index ? .uncertain : .exact
        )
        let prover: any InvestigationMachineOuterContainmentProving =
            index == proofGateOrdinal ? proofGate! : regularProver
        let wrapperSelection = failure == .misboundExecution
            && index == failure?.index
            ? fixtures[index + 1].selection : selection
        let wrapperMode: InvestigationMachineOuterContainmentMode =
            failure == .misboundMode && index == failure?.index
                ? (mode == .normal ? .parentCrash : .normal) : mode
        let execution = InvestigationMachineEightEpochExecution(
            selection: wrapperSelection, mode: wrapperMode,
            composer: composer, prover: prover
        )
        lock.withLock {
            executions.append(execution)
            returnedExecutionIdentifiers.append(ObjectIdentifier(execution))
            composers.append(composer)
            provers.append(regularProver)
        }
        return execution
    }

    func snapshot() -> EightEpochFactorySnapshot {
        lock.withLock {
            EightEpochFactorySnapshot(
                calls: calls,
                executionIdentifiers: returnedExecutionIdentifiers,
                composerRunCounts: composers.map(\.runCount),
                previousHelpers: composers.map(\.previousHelpers),
                proverCallCounts: provers.map(\.callCount)
            )
        }
    }
}

private final class EightEpochComposer:
    InvestigationMachineSingleEpochComposing, @unchecked Sendable
{
    private let selection: InvestigationMachineFixedEpochSelection
    private let result: InvestigationMachineSingleEpochResult
    private let failure: Bool
    private let gate: EightEpochGate?
    private let lock = NSLock()
    private var calls: [InvestigationMachineProcessIdentity?] = []

    var runCount: Int { lock.withLock { calls.count } }
    var previousHelpers: [InvestigationMachineProcessIdentity?] {
        lock.withLock { calls }
    }

    init(
        selection: InvestigationMachineFixedEpochSelection,
        result: InvestigationMachineSingleEpochResult,
        failure: Bool = false, gate: EightEpochGate? = nil
    ) {
        self.selection = selection
        self.result = result
        self.failure = failure
        self.gate = gate
    }

    func isBound(to value: InvestigationMachineFixedEpochSelection) -> Bool {
        selection == value
    }

    func run(
        previousHelperIdentity: InvestigationMachineProcessIdentity?
    ) async throws -> InvestigationMachineSingleEpochResult {
        lock.withLock { calls.append(previousHelperIdentity) }
        if let gate { await gate.suspend() }
        if failure { throw EightEpochTestError.composer }
        return result
    }
}

private final class EightEpochProver:
    InvestigationMachineOuterContainmentProving, @unchecked Sendable
{
    enum Behavior { case exact, uncertain }
    private let behavior: Behavior
    private let lock = NSLock()
    private var calls = 0
    var callCount: Int { lock.withLock { calls } }

    init(behavior: Behavior) { self.behavior = behavior }

    func proveContainment(
        selection: InvestigationMachineFixedEpochSelection,
        result: InvestigationMachineSingleEpochResult,
        predecessor: InvestigationMachineHelperEpochPredecessor
    ) async -> InvestigationMachineOuterContainmentOutcome {
        lock.withLock { calls += 1 }
        guard behavior == .exact else { return .terminalUncertain }
        guard let proof = try? InvestigationMachineOuterContainmentProof(
            selection: selection, result: result, predecessor: predecessor,
            terminalProofSHA256: EightEpochFixture.digest(0xa1)
        ) else {
            return .terminalUncertain
        }
        return .contained(proof)
    }
}

private actor EightEpochProofGate: InvestigationMachineOuterContainmentProving {
    private var entered = false
    private var outcome: InvestigationMachineOuterContainmentOutcome?
    private var entryWaiters: [CheckedContinuation<Void, Never>] = []
    private var outcomeWaiters: [CheckedContinuation<
        InvestigationMachineOuterContainmentOutcome, Never
    >] = []
    private(set) var observedCancellation: [Bool] = []

    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { entryWaiters.append($0) }
    }

    func release(_ value: InvestigationMachineOuterContainmentOutcome) {
        outcome = value
        let waiters = outcomeWaiters
        outcomeWaiters.removeAll()
        waiters.forEach { $0.resume(returning: value) }
    }

    func proveContainment(
        selection: InvestigationMachineFixedEpochSelection,
        result: InvestigationMachineSingleEpochResult,
        predecessor: InvestigationMachineHelperEpochPredecessor
    ) async -> InvestigationMachineOuterContainmentOutcome {
        _ = selection
        _ = result
        _ = predecessor
        observedCancellation.append(Task.isCancelled)
        entered = true
        let waiters = entryWaiters
        entryWaiters.removeAll()
        waiters.forEach { $0.resume() }
        if let outcome { return outcome }
        return await withCheckedContinuation { outcomeWaiters.append($0) }
    }
}

private actor EightEpochGate {
    private var entered = false
    private var opened = false
    private var entryWaiters: [CheckedContinuation<Void, Never>] = []
    private var openWaiters: [CheckedContinuation<Void, Never>] = []

    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { entryWaiters.append($0) }
    }

    func open() {
        opened = true
        let waiters = openWaiters
        openWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func suspend() async {
        entered = true
        let waiters = entryWaiters
        entryWaiters.removeAll()
        waiters.forEach { $0.resume() }
        if opened { return }
        await withCheckedContinuation { openWaiters.append($0) }
    }
}

private actor ScriptedEightEpochPlan: InvestigationMachineEightEpochPlan {
    enum Terminal: Sendable {
        case exhausted
        case selection(InvestigationMachineFixedEpochSelection)
        case failure(EightEpochTestError)
    }

    private let selections: [InvestigationMachineFixedEpochSelection]
    private let terminal: Terminal
    private let failureIndex: Int?
    private let gateIndex: Int?
    private let gate: EightEpochGate?
    private var nextIndex = 0
    private(set) var readCount = 0

    init(
        selections: [InvestigationMachineFixedEpochSelection],
        terminal: Terminal = .exhausted, failureIndex: Int? = nil,
        gateIndex: Int? = nil, gate: EightEpochGate? = nil
    ) {
        self.selections = selections
        self.terminal = terminal
        self.failureIndex = failureIndex
        self.gateIndex = gateIndex
        self.gate = gate
    }

    func takeNext() async throws -> InvestigationMachineFixedEpochSelection {
        let index = nextIndex
        nextIndex += 1
        readCount += 1
        if index == gateIndex, let gate { await gate.suspend() }
        if index == failureIndex { throw EightEpochTestError.plan }
        if selections.indices.contains(index) { return selections[index] }
        switch terminal {
        case .exhausted:
            throw InvestigationMachineFixedCapsuleIntakeError.exhausted
        case let .selection(selection):
            return selection
        case let .failure(error):
            throw error
        }
    }
}

private struct EightEpochCohortIdentity: Sendable, Equatable {
    let outerAttemptUUID: UUID
    let capsuleSHA256: InvestigationHandoffSHA256
    let inputSHA256: InvestigationHandoffSHA256

    static var foreign: Self {
        get throws {
            try .init(
                outerAttemptUUID: EightEpochFixture.uuid(0xc1),
                capsuleSHA256: EightEpochFixture.digest(0xc2),
                inputSHA256: EightEpochFixture.digest(0xc3)
            )
        }
    }
}

private struct EightEpochEpochFixture: Sendable {
    let selection: InvestigationMachineFixedEpochSelection
    let helperIdentity: InvestigationMachineProcessIdentity
    let localCompletion: InvestigationMachineSingleEpochLocalCompletionCandidate
    let ownership: InvestigationMachineSingleEpochOwnershipCandidate

    var result: InvestigationMachineSingleEpochResult {
        selection.epoch.scenario == .lifecycleRecovery
            ? .ownershipTransferred(ownership)
            : .localCompletion(localCompletion)
    }
}

private struct EightEpochFixture: Sendable {
    let cohort: EightEpochCohortIdentity
    let epochs: [EightEpochEpochFixture]
    var selections: [InvestigationMachineFixedEpochSelection] {
        epochs.map(\.selection)
    }

    init(cohort: EightEpochCohortIdentity? = nil) throws {
        let resolvedCohort = try cohort ?? .init(
            outerAttemptUUID: Self.uuid(0x01),
            capsuleSHA256: Self.digest(0x02),
            inputSHA256: Self.digest(0x03)
        )
        self.cohort = resolvedCohort
        epochs = try (0..<InvestigationCohortCapsule.epochCount).map {
            try Self.makeEpoch(ordinal: UInt32($0), cohort: resolvedCohort)
        }
    }

    func continuity(
        through finalOrdinal: Int
    ) async throws -> InvestigationMachineHelperEpochContinuity {
        var continuity = try InvestigationMachineHelperEpochContinuity
            .genesis(for: epochs[0].selection)
        for index in 0...finalOrdinal {
            let epoch = epochs[index]
            continuity = try await InvestigationMachineSingleEpochComposition(
                selection: epoch.selection, predecessor: continuity,
                composer: EightEpochComposer(
                    selection: epoch.selection, result: epoch.result
                ),
                outerJoin: .init(prover: EightEpochProver(behavior: .exact))
            ).run()
        }
        return continuity
    }

    func projection(
        for epoch: InvestigationCohortEpoch,
        epochUUID: UUID? = nil,
        configurationNonce: UUID? = nil,
        configurationSHA256: InvestigationHandoffSHA256? = nil,
        signedRuntimeBindingSHA256: InvestigationHandoffSHA256? = nil
    ) throws -> InvestigationInstalledL2IdentityProjection {
        try Self.projection(
            for: epoch, epochUUID: epochUUID,
            configurationNonce: configurationNonce,
            configurationSHA256: configurationSHA256,
            signedRuntimeBindingSHA256: signedRuntimeBindingSHA256
        )
    }

    private static func makeEpoch(
        ordinal: UInt32, cohort: EightEpochCohortIdentity
    ) throws -> EightEpochEpochFixture {
        let scenario = try #require(
            InvestigationHandoffScenario(rawValue: ordinal + 1)
        )
        let configuration = Data("cohort-configuration-\(ordinal)".utf8)
        let epoch = try InvestigationCohortEpoch(
            ordinal: ordinal, epochUUID: uuid(UInt8(0x10 + ordinal)),
            scenario: scenario,
            configurationNonce: uuid(UInt8(0x20 + ordinal)),
            configuration: configuration,
            configurationSHA256: .hashing(configuration),
            signedRuntimeBindingSHA256: digest(UInt8(0x30 + ordinal))
        )
        let projection = try projection(for: epoch)
        let selection = InvestigationMachineFixedEpochSelection(
            outerAttemptUUID: cohort.outerAttemptUUID,
            wholeCapsuleSHA256: cohort.capsuleSHA256,
            wholeInputSHA256: cohort.inputSHA256,
            epoch: epoch, projection: projection
        )
        let appIdentity = try identity(
            role: .app, pid: 700 + ordinal, version: 10 + ordinal,
            asid: 44_000 + ordinal, euid: 501
        )
        let helperIdentity = try identity(
            role: .helper, pid: 800 + ordinal, version: 20 + ordinal,
            asid: 55_000 + ordinal, euid: 0
        )
        let claim = try InvestigationMachineClaimEvidence(
            requestBindingSHA256: digest(UInt8(0x60 + ordinal)),
            originalClaimChallenge: uuid(UInt8(0x70 + ordinal)),
            claimConnectionEpoch: uuid(UInt8(0x80 + ordinal)),
            appIdentity: appIdentity, helperIdentity: helperIdentity,
            appUserID: 501, recordedAt: .init(rawValue: 250),
            claimedAt: .init(rawValue: 275), ownerRetirement: .init(),
            l1Residue: .init(
                investigationUUID: epoch.configurationNonce,
                auditSessionID: helperIdentity.auditSessionID, userID: 501,
                observedAt: .init(rawValue: 200),
                remainingAuditSessionMembers: 0, matchingLeases: 0,
                leaseRootEntries: 0, investigationArtifacts: 0
            ),
            releaseDeadlineNanoseconds: 400
        )
        let appSigning = try signing(
            "com.eriklee.stornaut", UInt8(0x91 + ordinal), false
        )
        let helperSigning = try signing(
            "com.eriklee.stornaut.lifecycle.helper",
            UInt8(0xa1 + ordinal), false
        )
        let driverSigning = try signing(
            "com.eriklee.stornaut.investigation.machine-driver",
            0x43, true
        )
        let semantic = try InvestigationInstalledL2SemanticContract.evaluate(
            projection: projection,
            artifacts: Dictionary(uniqueKeysWithValues:
                InvestigationInstalledL2ArtifactRole.allCases.map {
                    ($0, .presentValid)
                }
            ),
            app: try .init(
                identity: appIdentity,
                executableSHA256: projection.appExecutableSHA256,
                staticSigning: appSigning, liveSigning: appSigning
            ),
            helper: try .init(
                identity: helperIdentity,
                executableSHA256: projection.helperExecutableSHA256,
                staticSigning: helperSigning, liveSigning: helperSigning
            ),
            machineDriver: try .init(
                executableSHA256: projection.machineDriverExecutableSHA256,
                staticSigning: driverSigning, liveSigning: driverSigning
            ),
            service: .loaded(identity: helperIdentity),
            started: try .init(
                wallUTC: .init(rawValue: 300), continuousNanoseconds: 350
            ),
            observed: try .init(
                wallUTC: .init(rawValue: 301), continuousNanoseconds: 351
            )
        )
        let installedProof = try InvestigationMachineSingleEpochInstalledL2Join
            .prove(
                projection: projection, claimEvidence: claim,
                semanticObservation: semantic,
                repeatedAppIdentity: appIdentity, epochUUID: epoch.epochUUID,
                deadlineNanoseconds: 500
            )
        let ownership = try InvestigationMachineSingleEpochOwnershipCandidate(
            commitment: try .init(selection: selection),
            appIdentity: appIdentity, claimEvidence: claim,
            semanticObservation: semantic, repeatedAppIdentity: appIdentity,
            installedL2Proof: installedProof, epochDeadlineNanoseconds: 500
        )
        let released = try InvestigationMachineClaimReleased(
            requestBindingSHA256: claim.requestBindingSHA256,
            releaseChallenge: uuid(UInt8(0xb1 + ordinal)),
            claimedHelperIdentitySHA256:
                helperIdentity.helperIdentitySHA256(),
            claimConnectionEpoch: claim.claimConnectionEpoch,
            exitScheduled: true, postReplyExitDeadlineNanoseconds: 450
        )
        let driver = InvestigationMachineSingleEpochDriverObservation(
            .eightEpochFixture
        )
        let localCompletion = try
            InvestigationMachineSingleEpochLocalCompletionCandidate(
                ownership: ownership, claimRelease: released,
                retirement: .init(), initialDriverObservation: driver,
                finalDriverObservation: driver
            )
        return .init(
            selection: selection, helperIdentity: helperIdentity,
            localCompletion: localCompletion, ownership: ownership
        )
    }

    fileprivate static func projection(
        for epoch: InvestigationCohortEpoch,
        epochUUID: UUID? = nil,
        configurationNonce: UUID? = nil,
        configurationSHA256: InvestigationHandoffSHA256? = nil,
        signedRuntimeBindingSHA256: InvestigationHandoffSHA256? = nil
    ) throws -> InvestigationInstalledL2IdentityProjection {
        let driverSigning = try signing(
            "com.eriklee.stornaut.investigation.machine-driver", 0x43, true
        )
        return try .init(
            epochUUID: epochUUID ?? epoch.epochUUID,
            configurationNonce: configurationNonce ?? epoch.configurationNonce,
            configurationValidBefore: .init(rawValue: 1_000),
            configurationSHA256:
                configurationSHA256 ?? epoch.configurationSHA256,
            signedRuntimeBindingSHA256:
                signedRuntimeBindingSHA256
                    ?? epoch.signedRuntimeBindingSHA256,
            appExecutableSHA256: digest(0x51),
            appBundleIdentifier: "com.eriklee.stornaut",
            helperExecutableSHA256: digest(0x52),
            helperServiceIdentifier: "com.eriklee.stornaut.lifecycle",
            machineDriverExecutableSHA256: digest(0x53),
            machineDriverSigningIdentifier: driverSigning.signingIdentifier,
            machineDriverDesignatedRequirementSHA256:
                driverSigning.designatedRequirementSHA256,
            machineDriverCodeDirectoryHash: driverSigning.codeDirectoryHash,
            machineClaimServiceIdentifier:
                "com.eriklee.stornaut.lifecycle.machine-claim"
        )
    }

    static func digest(_ byte: UInt8) throws -> InvestigationHandoffSHA256 {
        try .init(rawBytes: Data(repeating: byte, count: 32))
    }

    static func uuid(_ byte: UInt8) -> UUID {
        UUID(uuid: (byte, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    }

    private static func identity(
        role: InvestigationMachineProcessRole, pid: UInt32, version: UInt32,
        asid: UInt32, euid: UInt32
    ) throws -> InvestigationMachineProcessIdentity {
        try .init(
            role: role, processID: pid, processIDVersion: version,
            auditSessionID: asid, effectiveUserID: euid,
            auditTokenWords: [euid, euid, 20, euid, 20, pid, asid, version]
        )
    }

    private static func signing(
        _ identifier: String, _ byte: UInt8, _ adHoc: Bool
    ) throws -> InvestigationInstalledL2SigningIdentity {
        try .init(
            signingIdentifier: identifier,
            designatedRequirementSHA256: digest(byte),
            codeDirectoryHash: Data(repeating: byte, count: 20),
            isAdHoc: adHoc
        )
    }
}

private extension InvestigationMachineInstalledDriverObservation {
    static var eightEpochFixture: Self {
        let node = InvestigationMachineInstalledDriverNodeIdentity(
            deviceID: 1, inode: 2, generation: 3, isRegularFile: true,
            ownerUserID: 0, ownerGroupID: 0, mode: 0o755, linkCount: 1,
            size: 65_536, flags: 0, modificationSeconds: 4,
            modificationNanoseconds: 5, statusChangeSeconds: 6,
            statusChangeNanoseconds: 7
        )
        let signing = InvestigationMachineInstalledDriverSigningIdentity(
            signingIdentifier: fixedSigningIdentifier,
            designatedRequirementSHA256: String(repeating: "a", count: 64),
            codeDirectoryHash: String(repeating: "b", count: 40),
            isAdHoc: true
        )
        let manifest = InvestigationMachineInstalledManifestIdentity(
            path: fixedLaunchDaemonManifestPath, node: node,
            sha256: fixedLaunchDaemonManifestSHA256,
            label: fixedLifecycleLabel, program: fixedLifecycleProgram,
            primaryServiceIdentifier: fixedLifecycleLabel,
            machineClaimServiceIdentifier: fixedMachineClaimServiceIdentifier
        )
        return .init(
            executablePath: fixedExecutablePath, node: node,
            executableSHA256: String(repeating: "c", count: 64),
            signing: signing, manifest: manifest
        )
    }
}
