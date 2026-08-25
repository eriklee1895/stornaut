import Foundation
import Testing

@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationMachineDriverSupport

@Suite("Investigation machine Darwin outer-inner composition", .serialized)
struct InvestigationMachineDarwinOuterInnerCompositionTests {
    @Test(arguments: [
        InvestigationHandoffScenario.success,
        InvestigationHandoffScenario.lifecycleRecovery,
    ])
    func exactOuterExchangeAdmitsNormalAndParentCrashOnce(
        _ scenario: InvestigationHandoffScenario
    ) async throws {
        let fixture = try OuterInnerFixture(scenario: scenario)
        let trace = CompositionTrace()
        let session = try ScriptedCompositionSession(
            fixture: fixture, trace: trace
        )
        let terminal = try ScriptedCompositionTerminalObserver(
            fixture: fixture, trace: trace
        )
        let components = try outerComponents(
            fixture: fixture, session: session, trace: trace,
            terminalObserver: terminal
        )

        let result = try await components.composer.run(
            invocation: fixture.invocation
        )
        guard case .admittedPhysical = result else {
            Issue.record("expected sole admitted physical result")
            return
        }
        #expect(trace.events == expectedTrace(for: scenario))
        let successfulRetirementCalls = await session.retirementCalls
        #expect(successfulRetirementCalls == 1)
        await #expect(throws:
            InvestigationMachineDarwinOuterInnerCompositionError.alreadyConsumed
        ) {
            _ = try await components.composer.run(invocation: fixture.invocation)
        }

        if let predecessor = fixture.predecessor {
            let continuity = try await InvestigationMachineOuterCompletionJoin(
                prover: components.prover
            ).seal(
                selection: fixture.selection, result: result,
                predecessor: predecessor
            )
            #expect(!(type(of: continuity) is any Codable.Type))
        }
    }

    @Test
    func executionFactoryUsesTheSameAdmissionForComposerAndContinuity() async throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let trace = CompositionTrace()
        let session = try ScriptedCompositionSession(
            fixture: fixture, trace: trace
        )
        let factory = InvestigationMachineDarwinOuterInnerExecutionFactory { _ in
            .init(
                outerProcessID: fixture.outerProcessID,
                sessionFactory: ScriptedCompositionSessionFactory(
                    session: session, trace: trace
                ),
                ownershipObserver: ScriptedCompositionOwnershipObserver(
                    fixture: fixture, trace: trace
                ),
                terminalObserver: try ScriptedCompositionTerminalObserver(
                    fixture: fixture, trace: trace
                ),
                clock: ScriptedCompositionClock(
                    now: fixture.observedAt, trace: trace
                )
            )
        }
        let components = try factory.components(
            for: fixture.selection, mode: .normal
        )
        let predecessor = try InvestigationMachineHelperEpochContinuity
            .genesis(for: fixture.selection)
        let composition = InvestigationMachineSingleEpochComposition(
            selection: fixture.selection, predecessor: predecessor,
            composer: components.composer,
            outerJoin: InvestigationMachineOuterCompletionJoin(
                prover: components.prover
            )
        )

        let successor = try await composition.run()
        #expect(!(type(of: successor) is any Codable.Type))
        #expect(trace.events == expectedTrace(for: .success))

        await #expect(throws:
            InvestigationMachineDarwinOuterInnerCompositionError.invalidSelection
        ) {
            _ = try await factory.makeExecution(
                for: fixture.selection, mode: .parentCrash
            )
        }
    }

    @Test
    func runningStateIsSetBeforeFirstAwaitAndCancellationIsTerminal() async throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let trace = CompositionTrace()
        let gate = CompositionGate()
        let session = try ScriptedCompositionSession(
            fixture: fixture, trace: trace
        )
        let components = try outerComponents(
            fixture: fixture, session: session, trace: trace,
            terminalObserver: try ScriptedCompositionTerminalObserver(
                fixture: fixture, trace: trace, initialGate: gate
            )
        )

        let first = Task {
            try await components.composer.run(invocation: fixture.invocation)
        }
        await gate.waitUntilEntered()
        await #expect(throws:
            InvestigationMachineDarwinOuterInnerCompositionError.alreadyConsumed
        ) {
            _ = try await components.composer.run(invocation: fixture.invocation)
        }
        first.cancel()
        await gate.open()
        await #expect(throws:
            InvestigationMachineDarwinOuterInnerCompositionError.cancelled
        ) {
            _ = try await first.value
        }
        let cancelledRetirementCalls = await session.retirementCalls
        #expect(cancelledRetirementCalls == 0)
        await #expect(throws:
            InvestigationMachineDarwinOuterInnerCompositionError.alreadyConsumed
        ) {
            _ = try await components.composer.run(invocation: fixture.invocation)
        }
    }

    @Test(arguments: [false, true])
    func cancellationAfterSessionStartJoinsCleanupAndCleanupFailureWins(
        _ retirementFails: Bool
    ) async throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let trace = CompositionTrace()
        let gate = CompositionGate()
        let session = try ScriptedCompositionSession(
            fixture: fixture, trace: trace, receiveGate: gate,
            retirementFails: retirementFails
        )
        let components = try outerComponents(
            fixture: fixture, session: session, trace: trace,
            terminalObserver: try ScriptedCompositionTerminalObserver(
                fixture: fixture, trace: trace
            )
        )
        let operation = Task {
            try await components.composer.run(invocation: fixture.invocation)
        }
        await gate.waitUntilEntered()
        operation.cancel()
        await gate.open()

        do {
            _ = try await operation.value
            Issue.record("cancelled composition unexpectedly completed")
        } catch {
            let expected: InvestigationMachineDarwinOuterInnerCompositionError =
                retirementFails ? .terminalUncertain : .cancelled
            #expect(
                error as? InvestigationMachineDarwinOuterInnerCompositionError
                    == expected
            )
        }
        #expect(await session.retirementCalls == 1)
        #expect(trace.events.suffix(2) == ["receive-ownership", "retire"])
    }

    @Test
    func realSessionCancellationRetiresOnceAndRemainsCancellation() async throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let trace = CompositionTrace()
        let gate = CompositionGate()
        let retirementOwner = CountingCompositionRetirementOwner()
        let session = InvestigationMachineDarwinOuterInnerSession(
            driverChildIdentity: fixture.driverChild,
            descriptors: .init(
                outerControlDescriptor: 10, innerControlSourceDescriptor: 11,
                outerResultDescriptor: 12, innerResultSourceDescriptor: 13
            ),
            retirementOwner: retirementOwner,
            messageSystem: .init(
                readExactly: { _, _, _ in
                    await gate.block()
                    try Task.checkCancellation()
                    throw CompositionSessionFailure.receiveOwnership
                },
                readUpToOne: { _, _ in
                    throw CompositionSessionFailure.receiveOwnership
                },
                writeExactly: { _, _, _ in }
            )
        )
        let components = try outerComponents(
            fixture: fixture, session: session, trace: trace,
            terminalObserver: try ScriptedCompositionTerminalObserver(
                fixture: fixture, trace: trace
            )
        )
        let operation = Task {
            try await components.composer.run(invocation: fixture.invocation)
        }
        await gate.waitUntilEntered()
        operation.cancel()
        await gate.open()

        await #expect(throws:
            InvestigationMachineDarwinOuterInnerCompositionError.cancelled
        ) {
            _ = try await operation.value
        }
        #expect(retirementOwner.ownedCalls == 1)
    }

    @Test
    func transportFailureRetiresOnceAndCannotBeRetried() async throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let trace = CompositionTrace()
        let session = try ScriptedCompositionSession(
            fixture: fixture, trace: trace, failure: .receiveOwnership
        )
        let components = try outerComponents(
            fixture: fixture, session: session, trace: trace,
            terminalObserver: try ScriptedCompositionTerminalObserver(
                fixture: fixture, trace: trace
            )
        )

        await #expect(throws:
            InvestigationMachineDarwinOuterInnerCompositionError
                .terminalUncertain
        ) {
            _ = try await components.composer.run(invocation: fixture.invocation)
        }
        let failedRetirementCalls = await session.retirementCalls
        #expect(failedRetirementCalls == 1)
        #expect(trace.events.suffix(2) == ["receive-ownership", "retire"])
        await #expect(throws:
            InvestigationMachineDarwinOuterInnerCompositionError.alreadyConsumed
        ) {
            _ = try await components.composer.run(invocation: fixture.invocation)
        }
    }

    @Test(arguments: [
        CompositionExitMismatch(
            scenario: .success, rawStatus:
                InvestigationMachineDarwinDirectChildExitClassification
                    .deliberateParentCrashExitStatus << 8
        ),
        CompositionExitMismatch(
            scenario: .lifecycleRecovery, rawStatus: 7 << 8
        ),
        CompositionExitMismatch(
            scenario: .lifecycleRecovery, rawStatus: SIGTERM
        ),
        CompositionExitMismatch(
            scenario: .lifecycleRecovery, rawStatus: SIGKILL
        ),
    ])
    fileprivate func exitClassificationMustMatchTheClosedMode(
        _ mismatch: CompositionExitMismatch
    ) async throws {
        let fixture = try OuterInnerFixture(scenario: mismatch.scenario)
        let trace = CompositionTrace()
        let session = try ScriptedCompositionSession(
            fixture: fixture, trace: trace, rawExitStatus: mismatch.rawStatus
        )
        let components = try outerComponents(
            fixture: fixture, session: session, trace: trace,
            terminalObserver: try ScriptedCompositionTerminalObserver(
                fixture: fixture, trace: trace
            )
        )

        await #expect(throws:
            InvestigationMachineDarwinOuterInnerCompositionError
                .terminalUncertain
        ) {
            _ = try await components.composer.run(invocation: fixture.invocation)
        }
        #expect(!trace.events.contains("terminal"))
        #expect(await session.retirementCalls == 1)
    }

    @Test
    func foreignInvocationConsumesTheCompositionBeforeAnyExternalEffect() async throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let foreign = try OuterInnerFixture(scenario: .cancellation)
        let trace = CompositionTrace()
        let session = try ScriptedCompositionSession(
            fixture: fixture, trace: trace
        )
        let components = try outerComponents(
            fixture: fixture, session: session, trace: trace,
            terminalObserver: try ScriptedCompositionTerminalObserver(
                fixture: fixture, trace: trace
            )
        )

        await #expect(throws:
            InvestigationMachineDarwinOuterInnerCompositionError.invalidSelection
        ) {
            _ = try await components.composer.run(invocation: foreign.invocation)
        }
        #expect(trace.events.isEmpty)
        await #expect(throws:
            InvestigationMachineDarwinOuterInnerCompositionError.alreadyConsumed
        ) {
            _ = try await components.composer.run(invocation: fixture.invocation)
        }
    }

    @Test(arguments: [
        InvestigationHandoffScenario.success,
        InvestigationHandoffScenario.lifecycleRecovery,
    ])
    func innerRoleSendsOwnershipBeforeDecisionAndOnlyNormalWritesResult(
        _ scenario: InvestigationHandoffScenario
    ) async throws {
        let fixture = try OuterInnerFixture(scenario: scenario)
        let trace = CompositionTrace()
        let channel = ScriptedInnerChannel(fixture: fixture, trace: trace)
        let crash = ScriptedInnerCrash(trace: trace)
        let composition = InvestigationMachineDarwinOuterInnerComposition(
            innerRoleValidator: ScriptedInnerRoleValidator(
                fixture: fixture, trace: trace
            ),
            innerChannel: channel,
            innerPhysicalRunner: ScriptedInnerPhysicalRunner(
                fixture: fixture, trace: trace
            ),
            innerCrash: crash,
            clock: ScriptedCompositionClock(
                now: fixture.observedAt, trace: trace
            )
        )

        if scenario == .lifecycleRecovery {
            await #expect(throws: ScriptedInnerCrash.Exit.self) {
                _ = try await composition.runInner()
            }
            #expect(channel.resultWrites.isEmpty)
            #expect(crash.calls == 1)
        } else {
            #expect(try await composition.runInner() == .normal)
            #expect(channel.resultWrites.count == 1)
            #expect(crash.calls == 0)
        }
        #expect(trace.events == expectedInnerTrace(for: scenario))
        await #expect(throws:
            InvestigationMachineDarwinOuterInnerCompositionError.alreadyConsumed
        ) {
            _ = try await composition.runInner()
        }
    }

    @Test(arguments: [
        InvestigationHandoffScenario.success,
        InvestigationHandoffScenario.lifecycleRecovery,
    ])
    func innerCancellationAfterDecisionNeverWritesResultOrCrashes(
        _ scenario: InvestigationHandoffScenario
    ) async throws {
        let fixture = try OuterInnerFixture(scenario: scenario)
        let trace = CompositionTrace()
        let gate = CompositionGate()
        let channel = ScriptedInnerChannel(fixture: fixture, trace: trace)
        let crash = ScriptedInnerCrash(trace: trace)
        let composition = InvestigationMachineDarwinOuterInnerComposition(
            innerRoleValidator: ScriptedInnerRoleValidator(
                fixture: fixture, trace: trace
            ),
            innerChannel: channel,
            innerPhysicalRunner: ScriptedInnerPhysicalRunner(
                fixture: fixture, trace: trace, completionGate: gate
            ),
            innerCrash: crash,
            clock: ScriptedCompositionClock(
                now: fixture.observedAt, trace: trace
            )
        )
        let operation = Task { try await composition.runInner() }
        await gate.waitUntilEntered()
        operation.cancel()
        await gate.open()

        await #expect(throws:
            InvestigationMachineDarwinOuterInnerCompositionError.cancelled
        ) {
            _ = try await operation.value
        }
        #expect(channel.resultWrites.isEmpty)
        #expect(crash.calls == 0)
        #expect(trace.events.last == "physical-ready")
        await #expect(throws:
            InvestigationMachineDarwinOuterInnerCompositionError.alreadyConsumed
        ) {
            _ = try await composition.runInner()
        }
    }

    @Test
    func innerRejectsARequestThatExpiresWhileItIsBeingRead() async throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let trace = CompositionTrace()
        let channel = ScriptedInnerChannel(fixture: fixture, trace: trace)
        let crash = ScriptedInnerCrash(trace: trace)
        let composition = InvestigationMachineDarwinOuterInnerComposition(
            innerRoleValidator: ScriptedInnerRoleValidator(
                fixture: fixture, trace: trace
            ),
            innerChannel: channel,
            innerPhysicalRunner: ScriptedInnerPhysicalRunner(
                fixture: fixture, trace: trace
            ),
            innerCrash: crash,
            clock: ScriptedSequenceCompositionClock(
                values: [
                    fixture.observedAt,
                    fixture.request.epochDeadlineNanoseconds,
                ], trace: trace
            )
        )

        await #expect(throws:
            InvestigationMachineDarwinOuterInnerCompositionError.deadlineInvalid
        ) {
            _ = try await composition.runInner()
        }
        #expect(trace.events == [
            "validate-inner", "clock", "receive-request", "clock",
        ])
        #expect(channel.resultWrites.isEmpty)
        #expect(crash.calls == 0)
    }
}

private enum CompositionSessionFailure: Error {
    case receiveOwnership
}

private struct CompositionExitMismatch: Sendable, CustomTestStringConvertible {
    let scenario: InvestigationHandoffScenario
    let rawStatus: Int32

    var testDescription: String {
        "\(scenario)-status-\(rawStatus)"
    }
}

private func outerComponents(
    fixture: OuterInnerFixture,
    session: any InvestigationMachineDarwinOuterInnerCompositionSession,
    trace: CompositionTrace,
    terminalObserver: ScriptedCompositionTerminalObserver
) throws -> InvestigationMachineDarwinOuterExecutionComponents {
    try InvestigationMachineDarwinOuterInnerExecutionFactory { _ in
        .init(
            outerProcessID: fixture.outerProcessID,
            sessionFactory: ScriptedCompositionSessionFactory(
                session: session, trace: trace
            ),
            ownershipObserver: ScriptedCompositionOwnershipObserver(
                fixture: fixture, trace: trace
            ),
            terminalObserver: terminalObserver,
            clock: ScriptedCompositionClock(
                now: fixture.observedAt, trace: trace
            )
        )
    }.components(
        for: fixture.selection, mode: fixture.request.mode
    )
}

private final class CompositionTrace: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    var events: [String] { lock.withLock { storage } }

    func record(_ value: String) {
        lock.withLock { storage.append(value) }
    }
}

private struct ScriptedInnerRoleValidator:
    InvestigationMachineDarwinInnerRoleValidating
{
    let fixture: OuterInnerFixture
    let trace: CompositionTrace

    func validate() throws -> InvestigationMachineDarwinInnerRoleObservation {
        trace.record("validate-inner")
        return .init(
            driverChildIdentity: fixture.driverChild,
            standardError: .init(
                deviceID: 1, inode: 2, mode: 0o020000,
                statusFlags: 1, isTTY: true, foregroundProcessGroup: 901
            )
        )
    }
}

private final class ScriptedInnerChannel:
    @unchecked Sendable, InvestigationMachineDarwinInnerChanneling
{
    private let lock = NSLock()
    private let fixture: OuterInnerFixture
    private let trace: CompositionTrace
    private var reads = 0
    private var storedResults: [Data] = []

    var resultWrites: [Data] { lock.withLock { storedResults } }

    init(fixture: OuterInnerFixture, trace: CompositionTrace) {
        self.fixture = fixture
        self.trace = trace
    }

    func receiveControl(deadlineNanoseconds: UInt64) async throws -> Data {
        _ = deadlineNanoseconds
        let index = lock.withLock { () -> Int in
            defer { reads += 1 }
            return reads
        }
        switch index {
        case 0:
            trace.record("receive-request")
            return try fixture.request.encoded()
        case 1:
            trace.record("receive-ack")
            return try fixture.acknowledgement.encoded()
        case 2:
            trace.record("receive-decision")
            return try fixture.decision.encoded()
        default:
            throw CompositionSessionFailure.receiveOwnership
        }
    }

    func sendControl(
        _ payload: Data, deadlineNanoseconds: UInt64
    ) async throws {
        _ = deadlineNanoseconds
        let expected = try fixture.ownershipRecord.encoded()
        #expect(payload == expected)
        trace.record("send-ownership")
    }

    func sendResult(
        _ payload: Data, deadlineNanoseconds: UInt64
    ) async throws {
        _ = deadlineNanoseconds
        let expected = try InvestigationMachineDarwinEpochNormalResult(
            request: fixture.request, ownership: fixture.ownershipRecord,
            acknowledgement: fixture.acknowledgement,
            decision: fixture.decision,
            physicalResult: fixture.physicalResult()
        ).encoded()
        #expect(payload == expected)
        lock.withLock { storedResults.append(payload) }
        trace.record("send-result")
    }
}

private struct ScriptedInnerPhysicalRunner:
    InvestigationMachineDarwinInnerPhysicalRunning
{
    let fixture: OuterInnerFixture
    let trace: CompositionTrace
    var completionGate: CompositionGate? = nil

    func run(
        request: InvestigationMachineDarwinEpochRequest,
        ownershipExchange: InvestigationMachineDarwinInnerOwnershipExchange
    ) async throws -> InvestigationMachineDarwinInnerPhysicalOutcome {
        trace.record("run-physical")
        let mode = try await ownershipExchange.exchange(
            fixture.physicalOwnership
        )
        let outcome: InvestigationMachineDarwinInnerPhysicalOutcome = switch mode {
        case .normal:
            .normal(try fixture.physicalResult())
        case .parentCrash:
            .parentCrash
        }
        trace.record("physical-ready")
        if let completionGate { await completionGate.block() }
        return outcome
    }
}

private final class ScriptedInnerCrash:
    @unchecked Sendable, InvestigationMachineDarwinInnerCrashing
{
    struct Exit: Error {}

    private let lock = NSLock()
    private let trace: CompositionTrace
    private var storedCalls = 0

    var calls: Int { lock.withLock { storedCalls } }

    init(trace: CompositionTrace) {
        self.trace = trace
    }

    func crashNow() throws -> Never {
        lock.withLock { storedCalls += 1 }
        trace.record("crash-now")
        throw Exit()
    }
}

private struct ScriptedCompositionClock:
    InvestigationMachineDarwinOuterInnerCompositionClocking
{
    let now: UInt64
    let trace: CompositionTrace

    func continuousNanoseconds() throws -> UInt64 {
        trace.record("clock")
        return now
    }
}

private final class ScriptedSequenceCompositionClock:
    @unchecked Sendable,
    InvestigationMachineDarwinOuterInnerCompositionClocking
{
    private let lock = NSLock()
    private var values: [UInt64]
    private let trace: CompositionTrace

    init(values: [UInt64], trace: CompositionTrace) {
        self.values = values
        self.trace = trace
    }

    func continuousNanoseconds() throws -> UInt64 {
        trace.record("clock")
        return try lock.withLock {
            guard !values.isEmpty else {
                throw CompositionSessionFailure.receiveOwnership
            }
            return values.removeFirst()
        }
    }
}

private final class ScriptedCompositionSessionFactory:
    @unchecked Sendable,
    InvestigationMachineDarwinOuterInnerCompositionSessionStarting
{
    let session: any InvestigationMachineDarwinOuterInnerCompositionSession
    let trace: CompositionTrace

    init(
        session: any InvestigationMachineDarwinOuterInnerCompositionSession,
        trace: CompositionTrace
    ) {
        self.session = session
        self.trace = trace
    }

    func startSession(deadlineNanoseconds: UInt64) async throws
        -> any InvestigationMachineDarwinOuterInnerCompositionSession
    {
        _ = deadlineNanoseconds
        trace.record("start")
        return session
    }
}

private final class CountingCompositionRetirementOwner:
    @unchecked Sendable, InvestigationMachineDarwinOuterRetirementOwning
{
    private let lock = NSLock()
    private var storedOwnedCalls = 0

    var ownedCalls: Int { lock.withLock { storedOwnedCalls } }

    func retireSpawnedProcess(
        _ spawnedEpoch: InvestigationMachineDarwinSpawnedEpoch
    ) async throws {
        _ = spawnedEpoch
    }

    func retireOwnedProcessGroup(
        _ ownedEpoch: InvestigationMachineDarwinOwnedEpoch
    ) async throws -> InvestigationMachineSingleEpochRetirementProof {
        _ = ownedEpoch
        lock.withLock { storedOwnedCalls += 1 }
        return .init()
    }

    func retireOwnedProcessGroupWithOutcome(
        _ ownedEpoch: InvestigationMachineDarwinOwnedEpoch
    ) async throws -> InvestigationMachineDarwinOuterRetirementOutcome {
        _ = ownedEpoch
        lock.withLock { storedOwnedCalls += 1 }
        return try await ScriptedCompositionRetirement.ordinaryZero.outcome()
    }
}

private actor ScriptedCompositionSession:
    InvestigationMachineDarwinOuterInnerCompositionSession
{
    nonisolated let driverChildIdentity:
        InvestigationMachineDarwinDriverChildIdentity
    private let requestBytes: Data
    private let acknowledgementBytes: Data
    private let decisionBytes: Data
    private let ownershipBytes: Data
    private let resultBytes: Data?
    private let retirement: ScriptedCompositionRetirement
    private let trace: CompositionTrace
    private let failure: CompositionSessionFailure?
    private let receiveGate: CompositionGate?
    private let retirementFails: Bool
    private var sentCount = 0
    private(set) var retirementCalls = 0

    init(
        fixture: OuterInnerFixture, trace: CompositionTrace,
        failure: CompositionSessionFailure? = nil,
        rawExitStatus: Int32? = nil, receiveGate: CompositionGate? = nil,
        retirementFails: Bool = false
    ) throws {
        driverChildIdentity = fixture.driverChild
        requestBytes = try fixture.request.encoded()
        acknowledgementBytes = try fixture.acknowledgement.encoded()
        decisionBytes = try fixture.decision.encoded()
        ownershipBytes = try fixture.ownershipRecord.encoded()
        let defaultRetirement: ScriptedCompositionRetirement
        if fixture.request.mode == .normal {
            resultBytes = try InvestigationMachineDarwinEpochNormalResult(
                request: fixture.request, ownership: fixture.ownershipRecord,
                acknowledgement: fixture.acknowledgement,
                decision: fixture.decision,
                physicalResult: fixture.physicalResult()
            ).encoded()
            defaultRetirement = .ordinaryZero
        } else {
            resultBytes = nil
            defaultRetirement = .deliberateParentCrash
        }
        self.trace = trace
        self.failure = failure
        self.receiveGate = receiveGate
        self.retirementFails = retirementFails
        retirement = rawExitStatus.map(ScriptedCompositionRetirement.rawStatus)
            ?? defaultRetirement
    }

    func sendControl(
        _ payload: Data, deadlineNanoseconds: UInt64
    ) async throws {
        _ = deadlineNanoseconds
        let expected: Data
        let event: String
        switch sentCount {
        case 0: (expected, event) = (requestBytes, "send-request")
        case 1: (expected, event) = (acknowledgementBytes, "send-ack")
        case 2: (expected, event) = (decisionBytes, "send-decision")
        default: throw CompositionSessionFailure.receiveOwnership
        }
        guard payload == expected else {
            throw CompositionSessionFailure.receiveOwnership
        }
        sentCount += 1
        trace.record(event)
    }

    func receiveControl(deadlineNanoseconds: UInt64) async throws -> Data {
        _ = deadlineNanoseconds
        trace.record("receive-ownership")
        if let receiveGate { await receiveGate.block() }
        if failure == .receiveOwnership {
            throw CompositionSessionFailure.receiveOwnership
        }
        return ownershipBytes
    }

    func receiveResult(deadlineNanoseconds: UInt64) async throws -> Data? {
        _ = deadlineNanoseconds
        trace.record("receive-result")
        return resultBytes
    }

    func proveControlEOF(deadlineNanoseconds: UInt64) async throws {
        _ = deadlineNanoseconds
        trace.record("control-eof")
    }

    func proveResultEOF(deadlineNanoseconds: UInt64) async throws {
        _ = deadlineNanoseconds
        trace.record("result-eof")
    }

    func retireOwnedProcessGroupWithOutcome() async throws
        -> InvestigationMachineDarwinOuterRetirementOutcome
    {
        retirementCalls += 1
        trace.record("retire")
        if retirementFails { throw CompositionSessionFailure.receiveOwnership }
        return try await retirement.outcome()
    }
}

private enum ScriptedCompositionRetirement {
    case ordinaryZero
    case deliberateParentCrash
    case rawStatus(Int32)

    func outcome() async throws
        -> InvestigationMachineDarwinOuterRetirementOutcome
    {
        let rawStatus: Int32 = switch self {
        case .ordinaryZero: 0
        case .deliberateParentCrash:
            InvestigationMachineDarwinDirectChildExitClassification
                .deliberateParentCrashExitStatus << 8
        case let .rawStatus(value): value
        }
        let processID: Int32 = 901
        let recorder = CompositionRetirementSystem(rawStatus: rawStatus)
        return try await InvestigationMachineDarwinEpochRetirementOwner(
            system: recorder.system()
        ).retireOwnedProcessGroupWithOutcome(.init(
            processID: processID, processGroupID: processID, descriptors: []
        ))
    }
}

private final class CompositionRetirementSystem: @unchecked Sendable {
    private let lock = NSLock()
    private let rawStatus: Int32
    private var inventoryCalls = 0

    init(rawStatus: Int32) { self.rawStatus = rawStatus }

    func system() -> InvestigationMachineDarwinEpochRetirementSystem {
        .init(
            currentProcessGroup: { 88 },
            continuousNanoseconds: { 1 },
            closeDescriptor: { _ in },
            processGroupInventory: { _, processID, _ in
                self.lock.withLock {
                    defer { self.inventoryCalls += 1 }
                    guard self.inventoryCalls == 0 else { return Data() }
                    var value = processID
                    return withUnsafeBytes(of: &value) { Data($0) }
                }
            },
            waitID: { processID, _ in processID },
            sendSignal: { _, _ in },
            waitPID: { processID, _ in processID },
            waitPIDStatus: { processID, _ in
                .init(processID: processID, rawStatus: self.rawStatus)
            },
            pauseNanoseconds: { _ in }
        )
    }
}

private struct ScriptedCompositionOwnershipObserver:
    InvestigationMachineDarwinOuterOwnershipObserving
{
    let fixture: OuterInnerFixture
    let trace: CompositionTrace

    func observeOwnership(
        request: InvestigationMachineDarwinEpochRequest,
        record: InvestigationMachineDarwinEpochOwnershipRecord,
        sessionDriverChild: InvestigationMachineDarwinDriverChildIdentity
    ) async throws -> InvestigationMachineDarwinOuterOwnershipObservation {
        #expect(request == fixture.request)
        #expect(record == fixture.ownershipRecord)
        #expect(sessionDriverChild == fixture.driverChild)
        trace.record("observe-ownership")
        return .init(
            driverChild: fixture.driverChild, appChild: fixture.appChild
        )
    }
}

private struct ScriptedCompositionTerminalObserver:
    InvestigationMachineDarwinOuterTerminalObserving
{
    let initial: InvestigationHandoffSHA256
    let terminal: InvestigationMachineDarwinOuterTerminalObservation
    let trace: CompositionTrace
    let initialGate: CompositionGate?

    init(
        fixture: OuterInnerFixture, trace: CompositionTrace,
        initialGate: CompositionGate? = nil
    ) throws {
        initial = try InvestigationHandoffSHA256(
            rawBytes: Data(repeating: 0x62, count: 32)
        )
        terminal = try .init(
            appAbsence: .observed, helperAbsence: .observed,
            l1ResidueAbsence: .observed,
            finalDriverObservationSHA256: initial,
            observedAtNanoseconds: fixture.observedAt
        )
        self.trace = trace
        self.initialGate = initialGate
    }

    func observeInitialDriver(
        selection: InvestigationMachineFixedEpochSelection
    ) async throws -> InvestigationHandoffSHA256 {
        _ = selection
        trace.record("initial-driver")
        if let initialGate { await initialGate.block() }
        return initial
    }

    func observeTerminal(
        selection: InvestigationMachineFixedEpochSelection,
        ownership: InvestigationMachineDarwinEpochOwnershipRecord,
        retirement: InvestigationMachineDarwinOuterRetirementOutcome,
        deadlineNanoseconds: UInt64
    ) async throws -> InvestigationMachineDarwinOuterTerminalObservation {
        _ = selection
        _ = ownership
        _ = retirement
        _ = deadlineNanoseconds
        trace.record("terminal")
        return terminal
    }
}

private actor CompositionGate {
    private var entered = false
    private var isOpen = false
    private var entryWaiters: [CheckedContinuation<Void, Never>] = []
    private var openWaiters: [CheckedContinuation<Void, Never>] = []

    func block() async {
        entered = true
        entryWaiters.forEach { $0.resume() }
        entryWaiters.removeAll()
        guard !isOpen else { return }
        await withCheckedContinuation { openWaiters.append($0) }
    }

    func waitUntilEntered() async {
        guard !entered else { return }
        await withCheckedContinuation { entryWaiters.append($0) }
    }

    func open() {
        isOpen = true
        openWaiters.forEach { $0.resume() }
        openWaiters.removeAll()
    }
}

private func expectedTrace(
    for scenario: InvestigationHandoffScenario
) -> [String] {
    _ = scenario
    return [
        "initial-driver", "clock", "start", "send-request",
        "receive-ownership", "observe-ownership", "send-ack",
        "send-decision", "receive-result", "result-eof",
        "control-eof", "retire", "terminal", "clock",
    ]
}

private func expectedInnerTrace(
    for scenario: InvestigationHandoffScenario
) -> [String] {
    var expected = [
        "validate-inner", "clock", "receive-request",
        "clock", "run-physical", "send-ownership", "receive-ack",
        "receive-decision", "physical-ready",
    ]
    expected.append(
        scenario == .lifecycleRecovery ? "crash-now" : "send-result"
    )
    return expected
}
