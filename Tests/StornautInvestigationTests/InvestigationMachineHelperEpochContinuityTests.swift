import Foundation
import Testing
@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationInstalledL2
@testable import StornautInvestigationMachineDriverSupport
@Suite("Investigation machine helper epoch continuity", .serialized)
struct InvestigationMachineHelperEpochContinuityTests {
    @Test(arguments: HelperContinuityCommitmentMutation.allCases)
    fileprivate func commitmentRejectsInvalidCohortBinding(
        _ mutation: HelperContinuityCommitmentMutation
    ) throws {
        let fixture = try HelperContinuityFixture(ordinal: 0)
        let zero = try InvestigationHandoffSHA256(
            rawBytes: Data(repeating: 0, count: 32)
        )
        let selection = InvestigationMachineFixedEpochSelection(
            outerAttemptUUID: mutation == .outerAttempt
                ? UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
                : fixture.selection.outerAttemptUUID,
            wholeCapsuleSHA256: mutation == .capsuleDigest
                ? zero : fixture.selection.wholeCapsuleSHA256,
            wholeInputSHA256: mutation == .inputDigest
                ? zero : fixture.selection.wholeInputSHA256,
            epoch: fixture.selection.epoch,
            projection: fixture.selection.projection
        )
        #expect(throws: InvestigationMachineSingleEpochError
            .invalidCommitment) {
            _ = try InvestigationMachineSingleEpochCommitment(
                selection: selection
            )
        }
    }
    @Test
    func genesisIsOrdinalZeroOnlyAndOneShot() throws {
        let first = try HelperContinuityFixture(ordinal: 0)
        let second = try HelperContinuityFixture(
            ordinal: 1, cohort: first.cohort
        )
        let genesis = try InvestigationMachineHelperEpochContinuity
            .genesis(for: first.selection)
        let predecessor = try genesis.consume(for: first.selection)
        #expect(predecessor.previousHelperIdentity == nil)
        #expect(predecessor.continuitySHA256.rawBytes.contains { $0 != 0 })
        #expect(!(InvestigationMachineHelperEpochPredecessor.self
            is any Codable.Type))
        #expect(!(InvestigationMachineOuterContainmentProof.self
            is any Codable.Type))
        #expect(!(InvestigationMachineOuterCompletionJoin.self
            is any Codable.Type))
        #expect(!(InvestigationMachineSingleEpochComposition.self
            is any Codable.Type))
        #expect(throws: InvestigationMachineHelperEpochContinuityError
            .alreadyConsumed) {
            _ = try genesis.consume(for: first.selection)
        }
        #expect(throws: InvestigationMachineHelperEpochContinuityError
            .invalidPredecessor) {
            _ = try InvestigationMachineHelperEpochContinuity
                .genesis(for: second.selection)
        }
        #expect(!(InvestigationMachineHelperEpochContinuity.self
            is any Codable.Type))
    }
    @Test
    func normalOuterProofMintsExactNextPredecessor() async throws {
        let first = try HelperContinuityFixture(ordinal: 0)
        let second = try HelperContinuityFixture(
            ordinal: 1, cohort: first.cohort
        )
        let prover = HelperContinuityProver(.exact)
        let join = InvestigationMachineOuterCompletionJoin(prover: prover)
        let predecessor = try InvestigationMachineHelperEpochContinuity
            .genesis(for: first.selection).consume(for: first.selection)
        let continuity = try await join.seal(
            selection: first.selection, result: first.localResult,
            predecessor: predecessor
        )
        #expect(try continuity.consume(for: second.selection)
            .previousHelperIdentity == first.helperIdentity)
        #expect(prover.callCount == 1)
        await #expect(throws: InvestigationMachineHelperEpochContinuityError
            .alreadyConsumed) {
            _ = try await join.seal(
                selection: first.selection, result: first.localResult,
                predecessor: predecessor
            )
        }
    }
    @Test
    func parentCrashUsesFrozenOwnershipHelperOnly() async throws {
        let crash = try HelperContinuityFixture(ordinal: 6)
        let final = try HelperContinuityFixture(
            ordinal: 7, cohort: crash.cohort
        )
        let join = InvestigationMachineOuterCompletionJoin(
            prover: HelperContinuityProver(.exact)
        )
        let predecessor = try await crash.predecessor()
        let continuity = try await join.seal(
            selection: crash.selection, result: crash.transferredResult,
            predecessor: predecessor
        )
        #expect(try continuity.consume(for: final.selection)
            .previousHelperIdentity == crash.helperIdentity)
    }
    @Test(arguments: HelperContinuityInvalidMode.allCases)
    fileprivate func completionModeMustMatchTheFrozenBusinessRow(
        _ invalid: HelperContinuityInvalidMode
    ) async throws {
        let fixture = try HelperContinuityFixture(
            ordinal: invalid == .localLifecycle ? 6 : 0
        )
        let result = invalid == .localLifecycle
            ? fixture.localResult : fixture.transferredResult
        let prover = HelperContinuityProver(.exact)
        let predecessor = try await fixture.predecessor()
        await #expect(throws: InvestigationMachineHelperEpochContinuityError
            .invalidCompletion) {
            _ = try await InvestigationMachineOuterCompletionJoin(
                prover: prover
            ).seal(
                selection: fixture.selection, result: result,
                predecessor: predecessor
            )
        }
        #expect(prover.callCount == 0)
    }
    @Test
    func uncertaintyAndForeignProofNeverMintContinuity() async throws {
        let fixture = try HelperContinuityFixture(ordinal: 0)
        let uncertain = InvestigationMachineOuterCompletionJoin(
            prover: HelperContinuityProver(.uncertain)
        )
        let predecessor = try await fixture.predecessor()
        await #expect(throws: InvestigationMachineHelperEpochContinuityError
            .containmentUncertain) {
            _ = try await uncertain.seal(
                selection: fixture.selection, result: fixture.localResult,
                predecessor: predecessor
            )
        }
        let foreign = try HelperContinuityFixture(
            ordinal: 0, cohort: .foreign
        )
        let foreignProof = try InvestigationMachineOuterContainmentProof(
            selection: foreign.selection, result: foreign.localResult,
            predecessor: try await foreign.predecessor(),
            terminalProofSHA256: HelperContinuityFixture.digest(0xa1)
        )
        let mismatched = InvestigationMachineOuterCompletionJoin(
            prover: HelperContinuityProver(.fixed(foreignProof))
        )
        await #expect(throws: InvestigationMachineHelperEpochContinuityError
            .invalidCompletion) {
            _ = try await mismatched.seal(
                selection: fixture.selection, result: fixture.localResult,
                predecessor: try await fixture.predecessor()
            )
        }
    }
    @Test
    func foreignCohortCompletionFailsBeforeOuterProof() async throws {
        let current = try HelperContinuityFixture(ordinal: 0)
        let foreign = try HelperContinuityFixture(
            ordinal: 0, cohort: .foreign
        )
        let prover = HelperContinuityProver(.exact)
        await #expect(throws: InvestigationMachineHelperEpochContinuityError
            .invalidCompletion) {
            _ = try await InvestigationMachineOuterCompletionJoin(
                prover: prover
            ).seal(
                selection: current.selection, result: foreign.localResult,
                predecessor: try await current.predecessor()
            )
        }
        #expect(prover.callCount == 0)
    }
    @Test
    func proofFromDifferentLocalEvidenceCannotSealCompletion() async throws {
        let baseline = try HelperContinuityFixture(ordinal: 0)
        let altered = try HelperContinuityFixture(
            ordinal: 0, cohort: baseline.cohort, driverSHACharacter: "d"
        )
        let baselineProof = try InvestigationMachineOuterContainmentProof(
            selection: baseline.selection, result: baseline.localResult,
            predecessor: try await baseline.predecessor(),
            terminalProofSHA256: HelperContinuityFixture.digest(0xa1)
        )
        #expect(
            baseline.localCompletion.driverObservationSHA256
                != altered.localCompletion.driverObservationSHA256
        )
        #expect(
            baseline.localCompletion.bindingSHA256
                != altered.localCompletion.bindingSHA256
        )
        await #expect(throws: InvestigationMachineHelperEpochContinuityError
            .invalidCompletion) {
            _ = try await InvestigationMachineOuterCompletionJoin(
                prover: HelperContinuityProver(.fixed(baselineProof))
            ).seal(
                selection: altered.selection, result: altered.localResult,
                predecessor: try await altered.predecessor()
            )
        }
    }
    @Test
    func cancellationWaitsForOuterProofAndPermanentlyConsumesJoin() async throws {
        let fixture = try HelperContinuityFixture(ordinal: 0)
        let gate = HelperContinuityProofGate()
        let join = InvestigationMachineOuterCompletionJoin(prover: gate)
        let predecessor = try await fixture.predecessor()
        let task = Task {
            try await join.seal(
                selection: fixture.selection, result: fixture.localResult,
                predecessor: predecessor
            )
        }
        await gate.waitUntilStarted()
        task.cancel()
        await gate.release(
            .contained(try InvestigationMachineOuterContainmentProof(
                selection: fixture.selection, result: fixture.localResult,
                predecessor: predecessor,
                terminalProofSHA256: HelperContinuityFixture.digest(0xa1)
            ))
        )
        await #expect(throws: InvestigationMachineHelperEpochContinuityError
            .cancelled) {
            _ = try await task.value
        }
        #expect(await gate.callCount == 1)
        #expect(await gate.observedCancellation == [false])
        await #expect(throws: InvestigationMachineHelperEpochContinuityError
            .alreadyConsumed) {
            _ = try await join.seal(
                selection: fixture.selection, result: fixture.localResult,
                predecessor: predecessor
            )
        }
    }
    @Test(arguments: [false, true])
    fileprivate func cancellationPreservesExternalFailurePriority(
        _ foreignProof: Bool
    ) async throws {
        let fixture = try HelperContinuityFixture(ordinal: 0)
        let gate = HelperContinuityProofGate()
        let predecessor = try await fixture.predecessor()
        let task = Task {
            try await InvestigationMachineOuterCompletionJoin(prover: gate)
                .seal(
                    selection: fixture.selection, result: fixture.localResult,
                    predecessor: predecessor
                )
        }
        await gate.waitUntilStarted()
        task.cancel()
        let outcome: InvestigationMachineOuterContainmentOutcome
        if !foreignProof {
            outcome = .terminalUncertain
        } else {
            let foreign = try HelperContinuityFixture(
                ordinal: 0, cohort: .foreign
            )
            outcome = .contained(try InvestigationMachineOuterContainmentProof(
                selection: foreign.selection, result: foreign.localResult,
                predecessor: try await foreign.predecessor(),
                terminalProofSHA256: HelperContinuityFixture.digest(0xa1)
            ))
        }
        await gate.release(outcome)
        await #expect(throws: foreignProof
            ? InvestigationMachineHelperEpochContinuityError.invalidCompletion
            : .containmentUncertain) {
            _ = try await task.value
        }
        #expect(await gate.observedCancellation == [false])
    }
    @Test
    func concurrentSealHasExactlyOneOuterProofWinner() async throws {
        let fixture = try HelperContinuityFixture(ordinal: 0)
        let gate = HelperContinuityProofGate()
        let join = InvestigationMachineOuterCompletionJoin(prover: gate)
        let predecessor = try await fixture.predecessor()
        let first = Task {
            try await join.seal(
                selection: fixture.selection, result: fixture.localResult,
                predecessor: predecessor
            )
        }
        await gate.waitUntilStarted()
        await #expect(throws: InvestigationMachineHelperEpochContinuityError
            .alreadyConsumed) {
            _ = try await join.seal(
                selection: fixture.selection, result: fixture.localResult,
                predecessor: predecessor
            )
        }
        await gate.release(
            .contained(try InvestigationMachineOuterContainmentProof(
                selection: fixture.selection, result: fixture.localResult,
                predecessor: predecessor,
                terminalProofSHA256: HelperContinuityFixture.digest(0xa1)
            ))
        )
        _ = try await first.value
        #expect(await gate.callCount == 1)
    }
    @Test
    func onePredecessorCannotBeReplayedAcrossDistinctJoins() async throws {
        let fixture = try HelperContinuityFixture(ordinal: 0)
        let predecessor = try await fixture.predecessor()
        let first = InvestigationMachineOuterCompletionJoin(
            prover: HelperContinuityProver(.exact)
        )
        let second = InvestigationMachineOuterCompletionJoin(
            prover: HelperContinuityProver(.exact)
        )
        _ = try await first.seal(
            selection: fixture.selection, result: fixture.localResult,
            predecessor: predecessor
        )
        await #expect(throws: InvestigationMachineHelperEpochContinuityError
            .alreadyConsumed) {
            _ = try await second.seal(
                selection: fixture.selection, result: fixture.localResult,
                predecessor: predecessor
            )
        }
    }
    @Test(arguments: HelperContinuityPredecessorMutation.allCases)
    fileprivate func successorRejectsForeignOrWrongOrdinalAndConsumesReplay(
        _ mutation: HelperContinuityPredecessorMutation
    ) async throws {
        let first = try HelperContinuityFixture(ordinal: 0)
        let continuity = try await InvestigationMachineOuterCompletionJoin(
            prover: HelperContinuityProver(.exact)
        ).seal(
            selection: first.selection, result: first.localResult,
            predecessor: try await first.predecessor()
        )
        let next = try HelperContinuityFixture(
            ordinal: mutation == .wrongOrdinal ? 2 : 1,
            cohort: mutation.cohort(from: first.cohort)
        )
        #expect(throws: InvestigationMachineHelperEpochContinuityError
            .invalidPredecessor) {
            _ = try continuity.consume(for: next.selection)
        }
        let exact = try HelperContinuityFixture(
            ordinal: 1, cohort: first.cohort
        )
        #expect(throws: InvestigationMachineHelperEpochContinuityError
            .alreadyConsumed) {
            _ = try continuity.consume(for: exact.selection)
        }
    }
    @Test
    func compositionConsumesGenesisAndIsOneShot() async throws {
        let fixture = try HelperContinuityFixture(ordinal: 0)
        let next = try HelperContinuityFixture(
            ordinal: 1, cohort: fixture.cohort
        )
        let composer = HelperContinuityComposer(
            selection: fixture.selection, result: fixture.localResult
        )
        let composition = InvestigationMachineSingleEpochComposition(
            selection: fixture.selection,
            predecessor: try .genesis(for: fixture.selection),
            composer: composer,
            outerJoin: .init(prover: HelperContinuityProver(.exact))
        )
        let continuity = try await composition.run()
        #expect(composer.previousHelpers == [nil])
        #expect(try continuity.consume(for: next.selection)
            .previousHelperIdentity == fixture.helperIdentity)
        await #expect(throws: InvestigationMachineHelperEpochContinuityError
            .alreadyConsumed) {
            _ = try await composition.run()
        }
    }
    @Test
    func compositionRejectsSameHelperBeforeOuterProof() async throws {
        let first = try HelperContinuityFixture(ordinal: 0)
        let next = try HelperContinuityFixture(
            ordinal: 1, cohort: first.cohort,
            helperIdentity: first.helperIdentity
        )
        let continuity = try await InvestigationMachineOuterCompletionJoin(
            prover: HelperContinuityProver(.exact)
        ).seal(
            selection: first.selection, result: first.localResult,
            predecessor: try await first.predecessor()
        )
        let composer = HelperContinuityComposer(
            selection: next.selection, result: next.localResult
        )
        let prover = HelperContinuityProver(.exact)
        let composition = InvestigationMachineSingleEpochComposition(
            selection: next.selection, predecessor: continuity,
            composer: composer, outerJoin: .init(prover: prover)
        )
        await #expect(throws: InvestigationMachineHelperEpochContinuityError
            .invalidCompletion) {
            _ = try await composition.run()
        }
        #expect(composer.previousHelpers == [first.helperIdentity])
        #expect(prover.callCount == 0)
    }
    @Test
    func misboundComposerDoesNotConsumeGenesis() async throws {
        let expected = try HelperContinuityFixture(ordinal: 0)
        let foreign = try HelperContinuityFixture(
            ordinal: 0, cohort: .foreign
        )
        let genesis = try InvestigationMachineHelperEpochContinuity
            .genesis(for: expected.selection)
        let composition = InvestigationMachineSingleEpochComposition(
            selection: expected.selection, predecessor: genesis,
            composer: HelperContinuityComposer(
                selection: foreign.selection, result: foreign.localResult
            ),
            outerJoin: .init(prover: HelperContinuityProver(.exact))
        )
        await #expect(throws: InvestigationMachineHelperEpochContinuityError
            .invalidCompletion) {
            _ = try await composition.run()
        }
        #expect(try genesis.consume(for: expected.selection)
            .previousHelperIdentity == nil)
    }
    @Test
    func zeroTerminalProofDigestCannotClaimContainment() async throws {
        let fixture = try HelperContinuityFixture(ordinal: 0)
        await #expect(throws: InvestigationMachineHelperEpochContinuityError
            .invalidCompletion) {
            _ = try InvestigationMachineOuterContainmentProof(
                selection: fixture.selection, result: fixture.localResult,
                predecessor: try await fixture.predecessor(),
                terminalProofSHA256: .init(
                    rawBytes: Data(repeating: 0, count: 32)
                )
            )
        }
    }
}
private enum HelperContinuityInvalidMode: CaseIterable {
    case localLifecycle
    case transferredNormal
}
private enum HelperContinuityCommitmentMutation: CaseIterable {
    case outerAttempt, capsuleDigest, inputDigest
}
private enum HelperContinuityPredecessorMutation: CaseIterable {
    case outerAttempt, capsuleDigest, inputDigest, wrongOrdinal
    func cohort(
        from value: HelperContinuityCohort
    ) throws -> HelperContinuityCohort {
        switch self {
        case .outerAttempt:
            return .init(
                outerAttemptUUID: HelperContinuityFixture.uuid(0xf1),
                capsuleSHA256: value.capsuleSHA256,
                inputSHA256: value.inputSHA256
            )
        case .capsuleDigest:
            return .init(
                outerAttemptUUID: value.outerAttemptUUID,
                capsuleSHA256: try HelperContinuityFixture.digest(0xf2),
                inputSHA256: value.inputSHA256
            )
        case .inputDigest:
            return .init(
                outerAttemptUUID: value.outerAttemptUUID,
                capsuleSHA256: value.capsuleSHA256,
                inputSHA256: try HelperContinuityFixture.digest(0xf3)
            )
        case .wrongOrdinal:
            return value
        }
    }
}
private struct HelperContinuityCohort: Sendable, Equatable {
    let outerAttemptUUID: UUID
    let capsuleSHA256: InvestigationHandoffSHA256
    let inputSHA256: InvestigationHandoffSHA256
    static var foreign: Self {
        get throws {
            try .init(
                outerAttemptUUID: HelperContinuityFixture.uuid(0xe1),
                capsuleSHA256: HelperContinuityFixture.digest(0xe2),
                inputSHA256: HelperContinuityFixture.digest(0xe3)
            )
        }
    }
}
private final class HelperContinuityProver:
    InvestigationMachineOuterContainmentProving, @unchecked Sendable
{
    enum Behavior: Sendable {
        case exact
        case fixed(InvestigationMachineOuterContainmentProof)
        case uncertain
    }
    private let behavior: Behavior
    private let lock = NSLock()
    private var calls = 0
    var callCount: Int { lock.withLock { calls } }
    init(_ behavior: Behavior) { self.behavior = behavior }
    func proveContainment(
        selection: InvestigationMachineFixedEpochSelection,
        result: InvestigationMachineSingleEpochResult,
        predecessor: InvestigationMachineHelperEpochPredecessor
    ) async -> InvestigationMachineOuterContainmentOutcome {
        lock.withLock { calls += 1 }
        switch behavior {
        case .exact:
            guard let proof = try? InvestigationMachineOuterContainmentProof(
                selection: selection, result: result,
                predecessor: predecessor,
                terminalProofSHA256:
                    HelperContinuityFixture.digest(0xa1)
            ) else { return .terminalUncertain }
            return .contained(proof)
        case let .fixed(proof): return .contained(proof)
        case .uncertain: return .terminalUncertain
        }
    }
}
private actor HelperContinuityProofGate:
    InvestigationMachineOuterContainmentProving {
    private var started = false
    private var outcome: InvestigationMachineOuterContainmentOutcome?
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var outcomeWaiters: [CheckedContinuation<
        InvestigationMachineOuterContainmentOutcome, Never>] = []
    private(set) var callCount = 0
    private(set) var observedCancellation: [Bool] = []
    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { startWaiters.append($0) }
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
        callCount += 1
        observedCancellation.append(Task.isCancelled)
        started = true
        let waiters = startWaiters
        startWaiters.removeAll()
        waiters.forEach { $0.resume() }
        if let outcome { return outcome }
        return await withCheckedContinuation { outcomeWaiters.append($0) }
    }
}
private final class HelperContinuityComposer:
    InvestigationMachineSingleEpochComposing, @unchecked Sendable
{
    private let selection: InvestigationMachineFixedEpochSelection
    private let result: InvestigationMachineSingleEpochResult
    private let lock = NSLock()
    private var calls: [InvestigationMachineProcessIdentity?] = []
    var previousHelpers: [InvestigationMachineProcessIdentity?] {
        lock.withLock { calls }
    }
    init(
        selection: InvestigationMachineFixedEpochSelection,
        result: InvestigationMachineSingleEpochResult
    ) {
        self.selection = selection
        self.result = result
    }
    func isBound(to value: InvestigationMachineFixedEpochSelection) -> Bool {
        value == selection
    }
    func run(
        previousHelperIdentity: InvestigationMachineProcessIdentity?
    ) async throws -> InvestigationMachineSingleEpochResult {
        lock.withLock { calls.append(previousHelperIdentity) }
        return result
    }
}
private struct HelperContinuityFixture {
    let cohort: HelperContinuityCohort
    let selection: InvestigationMachineFixedEpochSelection
    let helperIdentity: InvestigationMachineProcessIdentity
    let ownership: InvestigationMachineSingleEpochOwnershipCandidate
    let localCompletion:
        InvestigationMachineSingleEpochLocalCompletionCandidate
    var localResult: InvestigationMachineSingleEpochResult {
        .localCompletion(localCompletion)
    }
    var transferredResult: InvestigationMachineSingleEpochResult {
        .ownershipTransferred(ownership)
    }
    func predecessor() async throws
        -> InvestigationMachineHelperEpochPredecessor
    {
        if selection.epoch.ordinal == 0 {
            return try InvestigationMachineHelperEpochContinuity
                .genesis(for: selection).consume(for: selection)
        }
        let previous = try HelperContinuityFixture(
            ordinal: selection.epoch.ordinal - 1, cohort: cohort
        )
        let previousResult = previous.selection.epoch.scenario
            == .lifecycleRecovery
            ? previous.transferredResult : previous.localResult
        let continuity = try await InvestigationMachineOuterCompletionJoin(
            prover: HelperContinuityProver(.exact)
        ).seal(
            selection: previous.selection, result: previousResult,
            predecessor: try await previous.predecessor()
        )
        return try continuity.consume(for: selection)
    }
    init(
        ordinal: UInt32,
        cohort: HelperContinuityCohort? = nil,
        helperIdentity requestedHelperIdentity:
            InvestigationMachineProcessIdentity? = nil,
        driverSHACharacter: Character = "c"
    ) throws {
        let scenario = try #require(InvestigationHandoffScenario(
            rawValue: ordinal + 1
        ))
        self.cohort = try cohort ?? .init(
            outerAttemptUUID: Self.uuid(0x01),
            capsuleSHA256: Self.digest(0x02),
            inputSHA256: Self.digest(0x03)
        )
        let configuration = Data("configuration-\(ordinal)".utf8)
        let epoch = try InvestigationCohortEpoch(
            ordinal: ordinal, epochUUID: Self.uuid(UInt8(0x10 + ordinal)),
            scenario: scenario,
            configurationNonce: Self.uuid(UInt8(0x20 + ordinal)),
            configuration: configuration,
            configurationSHA256: .hashing(configuration),
            signedRuntimeBindingSHA256: Self.digest(UInt8(0x30 + ordinal))
        )
        let driverSigning = try Self.signing(
            "com.eriklee.stornaut.investigation.machine-driver", 0x43, true
        )
        let projection = try InvestigationInstalledL2IdentityProjection(
            epochUUID: epoch.epochUUID,
            configurationNonce: epoch.configurationNonce,
            configurationValidBefore: .init(rawValue: 1_000),
            configurationSHA256: epoch.configurationSHA256,
            signedRuntimeBindingSHA256: epoch.signedRuntimeBindingSHA256,
            appExecutableSHA256: Self.digest(0x51),
            appBundleIdentifier: "com.eriklee.stornaut",
            helperExecutableSHA256: Self.digest(0x52),
            helperServiceIdentifier: "com.eriklee.stornaut.lifecycle",
            machineDriverExecutableSHA256: Self.digest(0x53),
            machineDriverSigningIdentifier: driverSigning.signingIdentifier,
            machineDriverDesignatedRequirementSHA256:
                driverSigning.designatedRequirementSHA256,
            machineDriverCodeDirectoryHash: driverSigning.codeDirectoryHash,
            machineClaimServiceIdentifier:
                "com.eriklee.stornaut.lifecycle.machine-claim"
        )
        selection = .init(
            outerAttemptUUID: self.cohort.outerAttemptUUID,
            wholeCapsuleSHA256: self.cohort.capsuleSHA256,
            wholeInputSHA256: self.cohort.inputSHA256,
            epoch: epoch, projection: projection
        )
        let appIdentity = try Self.identity(
            role: .app, pid: 701 + ordinal, version: 11 + ordinal,
            asid: 44_001 + ordinal, euid: 501
        )
        helperIdentity = try requestedHelperIdentity ?? Self.identity(
            role: .helper, pid: 801 + ordinal, version: 21 + ordinal,
            asid: 55_001 + ordinal, euid: 0
        )
        let claim = try InvestigationMachineClaimEvidence(
            requestBindingSHA256: Self.digest(0x61),
            originalClaimChallenge: Self.uuid(0x62),
            claimConnectionEpoch: Self.uuid(0x63),
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
        let appSigning = try Self.signing(
            "com.eriklee.stornaut", 0x71, false
        )
        let helperSigning = try Self.signing(
            "com.eriklee.stornaut.lifecycle.helper", 0x72, false
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
        let installedProof = try
            InvestigationMachineSingleEpochInstalledL2Join.prove(
                projection: projection, claimEvidence: claim,
                semanticObservation: semantic,
                repeatedAppIdentity: appIdentity, epochUUID: epoch.epochUUID,
                deadlineNanoseconds: 500
            )
        ownership = try .init(
            commitment: try .init(selection: selection),
            appIdentity: appIdentity,
            claimEvidence: claim, semanticObservation: semantic,
            repeatedAppIdentity: appIdentity,
            installedL2Proof: installedProof,
            epochDeadlineNanoseconds: 500
        )
        let released = try InvestigationMachineClaimReleased(
            requestBindingSHA256: claim.requestBindingSHA256,
            releaseChallenge: Self.uuid(0x64),
            claimedHelperIdentitySHA256:
                helperIdentity.helperIdentitySHA256(),
            claimConnectionEpoch: claim.claimConnectionEpoch,
            exitScheduled: true, postReplyExitDeadlineNanoseconds: 450
        )
        let driver = InvestigationMachineSingleEpochDriverObservation(
            .helperContinuityFixture(shaCharacter: driverSHACharacter)
        )
        localCompletion = try .init(
            ownership: ownership, claimRelease: released,
            retirement: .init(), initialDriverObservation: driver,
            finalDriverObservation: driver
        )
    }
    static func digest(_ byte: UInt8) throws -> InvestigationHandoffSHA256 {
        try .init(rawBytes: Data(repeating: byte, count: 32))
    }
    static func uuid(_ byte: UInt8) -> UUID {
        UUID(uuid: (byte, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    }
    fileprivate static func identity(
        role: InvestigationMachineProcessRole, pid: UInt32, version: UInt32,
        asid: UInt32, euid: UInt32
    ) throws -> InvestigationMachineProcessIdentity {
        try .init(
            role: role, processID: pid, processIDVersion: version,
            auditSessionID: asid, effectiveUserID: euid,
            auditTokenWords: [euid, euid, 20, euid, 20, pid, asid, version]
        )
    }
    private static func signing(_ identifier: String, _ byte: UInt8,
                                _ adHoc: Bool) throws
        -> InvestigationInstalledL2SigningIdentity {
        try .init(
            signingIdentifier: identifier,
            designatedRequirementSHA256: digest(byte),
            codeDirectoryHash: Data(repeating: byte, count: 20),
            isAdHoc: adHoc
        )
    }
}
private extension InvestigationMachineInstalledDriverObservation {
    static func helperContinuityFixture(shaCharacter: Character) -> Self {
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
            executableSHA256: String(repeating: shaCharacter, count: 64),
            signing: signing, manifest: manifest
        )
    }
}
