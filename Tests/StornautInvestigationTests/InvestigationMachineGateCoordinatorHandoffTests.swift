import Darwin
import Foundation
import Testing

@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationMachineGateSupport
@testable import StornautInvestigationMachineLaunchSupport

@Suite("Investigation fixed gate coordinator handoff", .serialized)
struct InvestigationMachineGateCoordinatorHandoffTests {
    @Test
    func successUsesPreparedStopContinueTerminalReapSettlementOrder() throws {
        let fixture = try FixedGateHandoffFixture()
        let system = ScriptedFixedGateHandoffSystem(fixture: fixture)
        let handoff = InvestigationFixedGateHandoff(system: system)

        let receipt = try handoff.run(
            canonicalProjectedInput: fixture.canonicalProjectedInput
        )

        #expect(system.events == [
            .publish,
            .spawn,
            .readPrepared,
            .observePreparedStop,
            .continueGate,
            .readTerminal,
            .waitExactGate,
            .observeGateGroupEmpty,
            .closeTransport,
            .settleExactGateReaped,
        ])
        #expect(receipt.outerAttemptUUID == fixture.outerAttemptUUID)
        #expect(receipt.wholeInputSHA256 == fixture.wholeInputSHA256)
        #expect(receipt.preparedFrameSHA256 == fixture.preparedFrameSHA256)
        #expect(receipt.gateTransportReceipt == fixture.transportReceipt)
        #expect(
            receipt.gateTransportReceiptSHA256
                == InvestigationHandoffSHA256.hashing(
                    try fixture.transportReceipt.encoded()
                )
        )
        #expect(receipt.settlement == .removed)
        #expect(!(receipt as Any is any Encodable))
        #expect(!(receipt as Any is any Decodable))
        let labels = Mirror(reflecting: receipt).children.compactMap(\.label)
        for forbidden in ["descriptor", "path", "token", "proof"] {
            #expect(!labels.contains { $0.localizedCaseInsensitiveContains(forbidden) })
        }
    }

    @Test
    func definitePreSpawnFailureSettlesAsNeverHandedOff() throws {
        let fixture = try FixedGateHandoffFixture()
        let system = ScriptedFixedGateHandoffSystem(
            fixture: fixture,
            scenario: .preSpawnNoTransfer
        )
        let handoff = InvestigationFixedGateHandoff(system: system)

        #expect(
            throws: InvestigationFixedGateHandoffError
                .spawnFailedBeforeTransfer
        ) {
            _ = try handoff.run(
                canonicalProjectedInput: fixture.canonicalProjectedInput
            )
        }
        #expect(system.events == [
            .publish, .spawn, .settleNeverHandedOff,
        ])
        #expect(system.neverHandedOffSettlementCount == 1)
        #expect(system.exactGateSettlementCount == 0)
    }

    @Test
    func publicationFailureDoesNotInventASettlementProof() throws {
        let fixture = try FixedGateHandoffFixture()
        let system = ScriptedFixedGateHandoffSystem(
            fixture: fixture,
            scenario: .publicationFailure
        )

        #expect(
            throws: InvestigationFixedGateHandoffError.publicationFailed
        ) {
            _ = try InvestigationFixedGateHandoff(system: system).run(
                canonicalProjectedInput: fixture.canonicalProjectedInput
            )
        }
        #expect(system.events == [.publish])
        #expect(system.neverHandedOffSettlementCount == 0)
        #expect(system.exactGateSettlementCount == 0)
    }

    @Test
    func uncertainSpawnWithExistingPIDNeverUsesNeverHandedOff() throws {
        let fixture = try FixedGateHandoffFixture()
        let system = ScriptedFixedGateHandoffSystem(
            fixture: fixture,
            scenario: .spawnUncertainPIDExists
        )

        #expect(
            throws: InvestigationFixedGateHandoffError.spawnUncertain(
                processID: fixture.gateProcessID
            )
        ) {
            _ = try InvestigationFixedGateHandoff(system: system).run(
                canonicalProjectedInput: fixture.canonicalProjectedInput
            )
        }
        #expect(system.events == [
            .publish,
            .spawn,
            .observeSpawnedProcess,
            .waitExactGate,
            .observeGateGroupEmpty,
            .closeTransport,
        ])
        #expect(!system.events.contains(.settleNeverHandedOff))
        #expect(system.neverHandedOffSettlementCount == 0)
        #expect(system.exactGateSettlementCount == 0)
    }

    @Test(arguments: HandoffWireStage.allCases, HandoffWireMutation.allCases)
    func malformedPreparedAndTerminalFramesFailClosed(
        _ stage: HandoffWireStage,
        _ mutation: HandoffWireMutation
    ) throws {
        let fixture = try FixedGateHandoffFixture()
        let system = ScriptedFixedGateHandoffSystem(
            fixture: fixture,
            scenario: .wireMutation(stage: stage, mutation: mutation)
        )
        let expected: InvestigationFixedGateHandoffError = switch (stage, mutation) {
        case (_, .mismatched): .identityMismatch
        case (.prepared, _): .invalidPreparedFrame
        case (.terminal, _): .invalidTransportReceipt
        }

        #expect(throws: expected) {
            _ = try InvestigationFixedGateHandoff(system: system).run(
                canonicalProjectedInput: fixture.canonicalProjectedInput
            )
        }
        #expect(system.settlementCount == 0)
        #expect(system.neverHandedOffSettlementCount == 0)
    }

    @Test(arguments: HandoffIdentityMutation.allCases)
    func gateProcessTTYAndCapsuleIdentityDriftFailClosed(
        _ mutation: HandoffIdentityMutation
    ) throws {
        let fixture = try FixedGateHandoffFixture()
        let system = ScriptedFixedGateHandoffSystem(
            fixture: fixture,
            scenario: .identityMutation(mutation)
        )

        #expect(
            throws: InvestigationFixedGateHandoffError.identityMismatch
        ) {
            _ = try InvestigationFixedGateHandoff(system: system).run(
                canonicalProjectedInput: fixture.canonicalProjectedInput
            )
        }
        #expect(system.settlementCount == 0)
        #expect(system.neverHandedOffSettlementCount == 0)
    }

    @Test(arguments: HandoffGateDeathStage.allCases)
    func gateDeathBeforeOrAfterPreparedCannotProduceAReceipt(
        _ stage: HandoffGateDeathStage
    ) throws {
        let fixture = try FixedGateHandoffFixture()
        let system = ScriptedFixedGateHandoffSystem(
            fixture: fixture,
            scenario: .gateDeath(stage)
        )

        #expect(
            throws: InvestigationFixedGateHandoffError.gateTerminated(
                .exited(status: 70)
            )
        ) {
            _ = try InvestigationFixedGateHandoff(system: system).run(
                canonicalProjectedInput: fixture.canonicalProjectedInput
            )
        }
        #expect(system.settlementCount == 0)
        #expect(system.neverHandedOffSettlementCount == 0)
    }

    @Test(arguments: HandoffContainmentUncertainty.allCases)
    func waitReapGroupEmptyAndCloseUncertaintyDominate(
        _ uncertainty: HandoffContainmentUncertainty
    ) throws {
        let fixture = try FixedGateHandoffFixture()
        let system = ScriptedFixedGateHandoffSystem(
            fixture: fixture,
            scenario: .containmentUncertainty(uncertainty)
        )
        let expected: InvestigationFixedGateHandoffError = switch uncertainty {
        case .wait, .reap, .groupEmpty: .exactReapUncertain
        case .close: .transportCloseUncertain
        }

        #expect(throws: expected) {
            _ = try InvestigationFixedGateHandoff(system: system).run(
                canonicalProjectedInput: fixture.canonicalProjectedInput
            )
        }
        #expect(system.neverHandedOffSettlementCount == 0)
        #expect(system.exactGateSettlementCount == 0)
    }

    @Test(arguments: HandoffSettlementFailure.allCases)
    func settlementResidueFailureAndProofRejectionRemainTerminal(
        _ failure: HandoffSettlementFailure
    ) throws {
        let fixture = try FixedGateHandoffFixture()
        let system = ScriptedFixedGateHandoffSystem(
            fixture: fixture,
            scenario: .settlementFailure(failure)
        )
        let expected: InvestigationFixedGateHandoffError = switch failure {
        case .residue: .settlementResidue
        case .failure: .settlementFailed
        case .proofRejected: .proofRejected
        }

        #expect(throws: expected) {
            _ = try InvestigationFixedGateHandoff(system: system).run(
                canonicalProjectedInput: fixture.canonicalProjectedInput
            )
        }
        #expect(system.exactGateSettlementCount == 1)
        #expect(system.neverHandedOffSettlementCount == 0)
    }

    @Test
    func forwardedSignalTakesPrecedenceOverDeadline() throws {
        let fixture = try FixedGateHandoffFixture()
        let signalAndDeadline = ScriptedFixedGateHandoffSystem(
            fixture: fixture,
            scenario: .terminalStatus(signal: SIGTERM, deadlineExpired: true)
        )
        #expect(
            throws: InvestigationFixedGateHandoffError.forwardedSignal(SIGTERM)
        ) {
            _ = try InvestigationFixedGateHandoff(
                system: signalAndDeadline
            ).run(canonicalProjectedInput: fixture.canonicalProjectedInput)
        }

        let deadlineOnly = ScriptedFixedGateHandoffSystem(
            fixture: fixture,
            scenario: .terminalStatus(signal: nil, deadlineExpired: true)
        )
        #expect(
            throws: InvestigationFixedGateHandoffError.deadlineExceeded
        ) {
            _ = try InvestigationFixedGateHandoff(system: deadlineOnly).run(
                canonicalProjectedInput: fixture.canonicalProjectedInput
            )
        }
        #expect(signalAndDeadline.settlementCount == 0)
        #expect(deadlineOnly.settlementCount == 0)
    }

    @Test
    func transportFailureReceiptCannotBecomeSuccessfulHandoff() throws {
        let fixture = try FixedGateHandoffFixture()
        let system = ScriptedFixedGateHandoffSystem(
            fixture: fixture, scenario: .transportFailure
        )

        #expect(
            throws: InvestigationFixedGateHandoffError.gateTerminated(
                .exited(
                    status:
                        InvestigationMachineGateSupport
                            .transportFailureExitStatus
                )
            )
        ) {
            _ = try InvestigationFixedGateHandoff(system: system).run(
                canonicalProjectedInput: fixture.canonicalProjectedInput
            )
        }
        #expect(system.exactGateSettlementCount == 0)
        #expect(system.neverHandedOffSettlementCount == 0)
    }

    @Test
    func exactReapProofAndHandoffAreOneShot() throws {
        let fixture = try FixedGateHandoffFixture()
        let system = ScriptedFixedGateHandoffSystem(fixture: fixture)
        let handoff = InvestigationFixedGateHandoff(system: system)

        _ = try handoff.run(
            canonicalProjectedInput: fixture.canonicalProjectedInput
        )
        #expect(
            throws: InvestigationFixedGateHandoffError.alreadyConsumed
        ) {
            _ = try handoff.run(
                canonicalProjectedInput: fixture.canonicalProjectedInput
            )
        }
        #expect(system.exactGateSettlementCount == 1)
        #expect(system.events.filter { $0 == .waitExactGate }.count == 1)
        #expect(system.events.filter { $0 == .settleExactGateReaped }.count == 1)
    }
}

enum HandoffWireStage: CaseIterable, Sendable {
    case prepared
    case terminal
}

enum HandoffWireMutation: CaseIterable, Sendable {
    case empty
    case truncated
    case oversized
    case noncanonical
    case trailing
    case mismatched
}

enum HandoffIdentityMutation: CaseIterable, Sendable {
    case gateExecutable
    case gateProcess
    case childProcess
    case terminal
    case capsule
}

enum HandoffGateDeathStage: CaseIterable, Sendable {
    case beforePrepared
    case afterPrepared
}

enum HandoffContainmentUncertainty: CaseIterable, Sendable {
    case wait
    case reap
    case groupEmpty
    case close
}

enum HandoffSettlementFailure: CaseIterable, Sendable {
    case residue
    case failure
    case proofRejected
}

private enum FixedGateHandoffScenario: Sendable {
    case success
    case publicationFailure
    case preSpawnNoTransfer
    case spawnUncertainPIDExists
    case wireMutation(stage: HandoffWireStage, mutation: HandoffWireMutation)
    case identityMutation(HandoffIdentityMutation)
    case gateDeath(HandoffGateDeathStage)
    case containmentUncertainty(HandoffContainmentUncertainty)
    case settlementFailure(HandoffSettlementFailure)
    case terminalStatus(signal: Int32?, deadlineExpired: Bool)
    case transportFailure
}

private enum FixedGateHandoffEvent: Equatable, Sendable {
    case publish
    case spawn
    case observeSpawnedProcess
    case readPrepared
    case observePreparedStop
    case continueGate
    case readTerminal
    case waitExactGate
    case observeGateGroupEmpty
    case closeTransport
    case settleExactGateReaped
    case settleNeverHandedOff
}

private final class ScriptedFixedGateHandoffSystem:
    InvestigationFixedGateHandoffSystem,
    @unchecked Sendable
{
    private let fixture: FixedGateHandoffFixture
    private let scenario: FixedGateHandoffScenario

    private(set) var events: [FixedGateHandoffEvent] = []
    private(set) var exactGateSettlementCount = 0
    private(set) var neverHandedOffSettlementCount = 0

    var settlementCount: Int {
        exactGateSettlementCount + neverHandedOffSettlementCount
    }

    init(
        fixture: FixedGateHandoffFixture,
        scenario: FixedGateHandoffScenario = .success
    ) {
        self.fixture = fixture
        self.scenario = scenario
    }

    func perform(
        _ operation: InvestigationFixedGateHandoffOperation
    ) throws -> InvestigationFixedGateHandoffResponse {
        switch operation {
        case .publishCanonicalCapsule(let bytes):
            events.append(.publish)
            guard bytes == fixture.canonicalProjectedInput else {
                throw InvestigationFixedGateHandoffSystemError.publicationFailed
            }
            if case .publicationFailure = scenario {
                throw InvestigationFixedGateHandoffSystemError.publicationFailed
            }
            return .publishedCapsule(
                outerAttemptUUID: fixture.outerAttemptUUID,
                wholeInputSHA256: fixture.wholeInputSHA256,
                node: fixture.capsuleNode
            )

        case .spawnFixedGate:
            events.append(.spawn)
            switch scenario {
            case .preSpawnNoTransfer:
                throw InvestigationFixedGateHandoffSystemError.preSpawnNoTransfer
            case .spawnUncertainPIDExists:
                throw InvestigationFixedGateHandoffSystemError.spawnUncertain(
                    processID: fixture.gateProcessID,
                    processGroupID: fixture.gateProcessGroupID
                )
            default:
                return .spawnedGate(
                    processID: fixture.gateProcessID,
                    processGroupID: fixture.gateProcessGroupID,
                    executableSHA256: fixture.gateExecutableSHA256
                )
            }

        case .observeSpawnedProcess(let processID):
            events.append(.observeSpawnedProcess)
            #expect(processID == fixture.gateProcessID)
            return .processExists(true)

        case .readPreparedFrame(let maximumByteCount):
            events.append(.readPrepared)
            #expect(
                maximumByteCount
                    == InvestigationMachineGatePreparedFrame.maximumByteCount
            )
            if case .gateDeath(.beforePrepared) = scenario {
                throw InvestigationFixedGateHandoffSystemError.gateTerminated(
                    .exited(status: 70)
                )
            }
            return .frame(
                bytes: try preparedBytes(),
                reachedEOF: false,
                overflowObserved: wireOverflow(stage: .prepared)
            )

        case .observePreparedStop(let processID):
            events.append(.observePreparedStop)
            #expect(processID == fixture.gateProcessID)
            if case .gateDeath(.afterPrepared) = scenario {
                return .waitClassification(.exited(status: 70))
            }
            return .waitClassification(.stopped(signal: SIGSTOP))

        case .continueFixedGate(let processID):
            events.append(.continueGate)
            #expect(processID == fixture.gateProcessID)
            return .completed

        case .readTerminalReceipt(let maximumByteCount):
            events.append(.readTerminal)
            #expect(
                maximumByteCount
                    == InvestigationMachineGateTransportReceipt.maximumByteCount
            )
            return .frame(
                bytes: try terminalBytes(),
                reachedEOF: terminalReachedEOF,
                overflowObserved: wireOverflow(stage: .terminal)
            )

        case .waitForExactGate(let processID):
            events.append(.waitExactGate)
            #expect(processID == fixture.gateProcessID)
            if case .containmentUncertainty(.wait) = scenario {
                throw InvestigationFixedGateHandoffSystemError.waitUncertain
            }
            if case .containmentUncertainty(.reap) = scenario {
                return .exactGateReap(
                    waitClassification: .exited(status: 0),
                    exactChildReaped: false
                )
            }
            if case .terminalStatus(let signal, let deadlineExpired) = scenario {
                let receipt = try fixture.transportReceipt(
                    forwardedSignal: signal,
                    deadlineExpired: deadlineExpired
                )
                return .exactGateReap(
                    waitClassification: .exited(
                        status: InvestigationMachineGateSupport.status(
                            for: receipt
                        )
                    ),
                    exactChildReaped: true
                )
            }
            if case .transportFailure = scenario {
                return .exactGateReap(
                    waitClassification: .exited(
                        status:
                            InvestigationMachineGateSupport
                                .transportFailureExitStatus
                    ),
                    exactChildReaped: true
                )
            }
            return .exactGateReap(
                waitClassification: .exited(status: 0),
                exactChildReaped: true
            )

        case .observeGateProcessGroupEmpty(let processGroupID):
            events.append(.observeGateGroupEmpty)
            #expect(processGroupID == fixture.gateProcessGroupID)
            if case .containmentUncertainty(.groupEmpty) = scenario {
                return .processGroupEmpty(false)
            }
            return .processGroupEmpty(true)

        case .closeTransport:
            events.append(.closeTransport)
            if case .containmentUncertainty(.close) = scenario {
                throw InvestigationFixedGateHandoffSystemError.closeUncertain
            }
            return .completed

        case .settleExactGateReaped:
            events.append(.settleExactGateReaped)
            exactGateSettlementCount += 1
            if case .settlementFailure(let failure) = scenario {
                switch failure {
                case .residue:
                    return .settlement(.settledResidue(
                        stage: .unlinkFile,
                        residue: .stale(
                            entries: ["attempt-iv-b1"],
                            observationComplete: true
                        ),
                        closeFailures: [],
                        ownershipReleaseUncertain: false
                    ))
                case .failure:
                    throw InvestigationFixedGateHandoffSystemError
                        .settlementFailed
                case .proofRejected:
                    throw InvestigationFixedGateHandoffSystemError
                        .proofRejected
                }
            }
            return .settlement(.removed)

        case .settleNeverHandedOff:
            events.append(.settleNeverHandedOff)
            neverHandedOffSettlementCount += 1
            return .settlement(.removed)
        }
    }

    private var terminalReachedEOF: Bool {
        if case .wireMutation(stage: .terminal, mutation: .truncated) = scenario {
            return true
        }
        return true
    }

    private func wireOverflow(stage: HandoffWireStage) -> Bool {
        if case .wireMutation(let selected, mutation: .oversized) = scenario {
            return selected == stage
        }
        return false
    }

    private func preparedBytes() throws -> Data {
        guard case .wireMutation(stage: .prepared, let mutation) = scenario else {
            if case .identityMutation(let mutation) = scenario {
                return try fixture.preparedFrame(
                    gateProcessID: mutation == .gateProcess
                        ? fixture.foreignGateProcessID
                        : fixture.gateProcessID,
                    capsule: mutation == .capsule
                        ? fixture.foreignCapsuleNode
                        : fixture.capsuleNode,
                    terminal: mutation == .terminal
                        ? fixture.foreignInitialTerminal
                        : fixture.initialTerminal,
                    childStartSeconds: fixture.childStartSeconds
                ).encoded()
            }
            return fixture.preparedFrameBytes
        }
        return try mutate(
            fixture.preparedFrameBytes,
            mutation: mutation,
            maximumByteCount:
                InvestigationMachineGatePreparedFrame.maximumByteCount,
            mismatch: fixture.foreignPreparedFrameBytes
        )
    }

    private func terminalBytes() throws -> Data {
        if case .wireMutation(stage: .terminal, let mutation) = scenario {
            return try mutate(
                try fixture.transportReceipt.encoded(),
                mutation: mutation,
                maximumByteCount:
                    InvestigationMachineGateTransportReceipt.maximumByteCount,
                mismatch: try fixture.foreignTransportReceipt.encoded()
            )
        }
        if case .identityMutation(let mutation) = scenario {
            return try fixture.transportReceipt(
                launcherExecutableSHA256: mutation == .gateExecutable
                    ? fixture.foreignGateExecutableSHA256
                    : fixture.gateExecutableSHA256,
                gateProcessID: mutation == .gateProcess
                    ? fixture.foreignGateProcessID
                    : fixture.gateProcessID,
                capsule: mutation == .capsule
                    ? fixture.foreignCapsuleNode
                    : fixture.capsuleNode,
                initialTerminal: mutation == .terminal
                    ? fixture.foreignInitialTerminal
                    : fixture.initialTerminal,
                childStartSeconds: mutation == .childProcess
                    ? fixture.childStartSeconds + 1
                    : fixture.childStartSeconds
            ).encoded()
        }
        if case .terminalStatus(let signal, let deadlineExpired) = scenario {
            return try fixture.transportReceipt(
                forwardedSignal: signal,
                deadlineExpired: deadlineExpired
            ).encoded()
        }
        if case .transportFailure = scenario {
            return try fixture.transportReceipt(
                waitClassification: .exited(status: 71)
            ).encoded()
        }
        return try fixture.transportReceipt.encoded()
    }

    private func mutate(
        _ bytes: Data,
        mutation: HandoffWireMutation,
        maximumByteCount: Int,
        mismatch: Data
    ) throws -> Data {
        switch mutation {
        case .empty:
            Data()
        case .truncated:
            Data(bytes.dropLast())
        case .oversized:
            Data(repeating: 0, count: maximumByteCount + 1)
        case .noncanonical:
            Data(repeating: 0x20, count: bytes.count)
        case .trailing:
            bytes + Data([0xff])
        case .mismatched:
            mismatch
        }
    }
}

private struct FixedGateHandoffFixture: Sendable {
    let canonicalProjectedInput: Data
    let outerAttemptUUID: UUID
    let wholeInputSHA256: InvestigationHandoffSHA256
    let capsuleNode: InvestigationMachineGateNodeObservation
    let foreignCapsuleNode: InvestigationMachineGateNodeObservation
    let initialTerminal: InvestigationMachineGateTerminalObservation
    let foreignInitialTerminal: InvestigationMachineGateTerminalObservation
    let gateExecutableSHA256: InvestigationHandoffSHA256
    let foreignGateExecutableSHA256: InvestigationHandoffSHA256
    let gateProcessID: pid_t = 4_101
    let foreignGateProcessID: pid_t = 4_301
    let gateProcessGroupID: pid_t = 4_101
    let coordinatorProcessID: pid_t = 4_001
    let childProcessID: pid_t = 4_201
    let childStartSeconds: UInt64 = 20
    let childStartMicroseconds: UInt64 = 30
    let startedNanoseconds: UInt64 = 10_000
    let completedNanoseconds: UInt64 = 20_000

    let preparedFrameBytes: Data
    let foreignPreparedFrameBytes: Data
    let preparedFrameSHA256: InvestigationHandoffSHA256
    let transportReceipt: InvestigationMachineGateTransportReceipt
    let foreignTransportReceipt: InvestigationMachineGateTransportReceipt

    init() throws {
        let input = try Self.projectedInput()
        canonicalProjectedInput = try input.encoded()
        outerAttemptUUID = input.capsule.outerAttemptUUID
        wholeInputSHA256 = input.wholeInputSHA256
        capsuleNode = .init(
            device: 11, inode: 12, generation: 13,
            size: Int64(canonicalProjectedInput.count)
        )
        foreignCapsuleNode = .init(
            device: 11, inode: 99, generation: 13,
            size: Int64(canonicalProjectedInput.count)
        )
        initialTerminal = .init(
            device: 21, inode: 22,
            foregroundProcessGroupID: coordinatorProcessID
        )
        foreignInitialTerminal = .init(
            device: 21, inode: 98,
            foregroundProcessGroupID: coordinatorProcessID
        )
        gateExecutableSHA256 = .hashing(Data("fixed-gate".utf8))
        foreignGateExecutableSHA256 = .hashing(
            Data("foreign-gate".utf8)
        )
        preparedFrameBytes = try Self.makePreparedFrame(
            gateProcessID: gateProcessID,
            coordinatorProcessID: coordinatorProcessID,
            childProcessID: childProcessID,
            childStartSeconds: childStartSeconds,
            childStartMicroseconds: childStartMicroseconds,
            outerAttemptUUID: outerAttemptUUID,
            wholeInputSHA256: wholeInputSHA256,
            capsule: capsuleNode,
            terminal: initialTerminal,
            startedNanoseconds: startedNanoseconds
        ).encoded()
        preparedFrameSHA256 = .hashing(preparedFrameBytes)
        foreignPreparedFrameBytes = try Self.makePreparedFrame(
            gateProcessID: foreignGateProcessID,
            coordinatorProcessID: coordinatorProcessID,
            childProcessID: childProcessID,
            childStartSeconds: childStartSeconds,
            childStartMicroseconds: childStartMicroseconds,
            outerAttemptUUID: outerAttemptUUID,
            wholeInputSHA256: wholeInputSHA256,
            capsule: capsuleNode,
            terminal: initialTerminal,
            startedNanoseconds: startedNanoseconds
        ).encoded()
        transportReceipt = try Self.makeTransportReceipt(
            launcherExecutableSHA256: gateExecutableSHA256,
            gateProcessID: gateProcessID,
            coordinatorProcessID: coordinatorProcessID,
            childProcessID: childProcessID,
            childStartSeconds: childStartSeconds,
            childStartMicroseconds: childStartMicroseconds,
            outerAttemptUUID: outerAttemptUUID,
            wholeInputSHA256: wholeInputSHA256,
            preparedFrameSHA256: preparedFrameSHA256,
            capsule: capsuleNode,
            initialTerminal: initialTerminal,
            startedNanoseconds: startedNanoseconds,
            completedNanoseconds: completedNanoseconds
        )
        foreignTransportReceipt = try Self.makeTransportReceipt(
            launcherExecutableSHA256: gateExecutableSHA256,
            gateProcessID: gateProcessID,
            coordinatorProcessID: coordinatorProcessID,
            childProcessID: childProcessID,
            childStartSeconds: childStartSeconds,
            childStartMicroseconds: childStartMicroseconds,
            outerAttemptUUID: Self.uuid(0xee),
            wholeInputSHA256: wholeInputSHA256,
            preparedFrameSHA256: preparedFrameSHA256,
            capsule: capsuleNode,
            initialTerminal: initialTerminal,
            startedNanoseconds: startedNanoseconds,
            completedNanoseconds: completedNanoseconds
        )
    }

    func preparedFrame(
        gateProcessID: pid_t,
        capsule: InvestigationMachineGateNodeObservation,
        terminal: InvestigationMachineGateTerminalObservation,
        childStartSeconds: UInt64
    ) throws -> InvestigationMachineGatePreparedFrame {
        try Self.makePreparedFrame(
            gateProcessID: gateProcessID,
            coordinatorProcessID: coordinatorProcessID,
            childProcessID: childProcessID,
            childStartSeconds: childStartSeconds,
            childStartMicroseconds: childStartMicroseconds,
            outerAttemptUUID: outerAttemptUUID,
            wholeInputSHA256: wholeInputSHA256,
            capsule: capsule,
            terminal: terminal,
            startedNanoseconds: startedNanoseconds
        )
    }

    func transportReceipt(
        launcherExecutableSHA256: InvestigationHandoffSHA256? = nil,
        gateProcessID: pid_t? = nil,
        capsule: InvestigationMachineGateNodeObservation? = nil,
        initialTerminal: InvestigationMachineGateTerminalObservation? = nil,
        childStartSeconds: UInt64? = nil,
        forwardedSignal: Int32? = nil,
        deadlineExpired: Bool = false,
        waitClassification: InvestigationMachineGateWaitClassification =
            .exited(status: 0)
    ) throws -> InvestigationMachineGateTransportReceipt {
        try Self.makeTransportReceipt(
            launcherExecutableSHA256:
                launcherExecutableSHA256 ?? self.gateExecutableSHA256,
            gateProcessID: gateProcessID ?? self.gateProcessID,
            coordinatorProcessID: coordinatorProcessID,
            childProcessID: childProcessID,
            childStartSeconds: childStartSeconds ?? self.childStartSeconds,
            childStartMicroseconds: childStartMicroseconds,
            outerAttemptUUID: outerAttemptUUID,
            wholeInputSHA256: wholeInputSHA256,
            preparedFrameSHA256: preparedFrameSHA256,
            capsule: capsule ?? capsuleNode,
            initialTerminal: initialTerminal ?? self.initialTerminal,
            startedNanoseconds: startedNanoseconds,
            completedNanoseconds: completedNanoseconds,
            forwardedSignal: forwardedSignal,
            deadlineExpired: deadlineExpired,
            waitClassification: waitClassification
        )
    }

    private static func makePreparedFrame(
        gateProcessID: pid_t,
        coordinatorProcessID: pid_t,
        childProcessID: pid_t,
        childStartSeconds: UInt64,
        childStartMicroseconds: UInt64,
        outerAttemptUUID: UUID,
        wholeInputSHA256: InvestigationHandoffSHA256,
        capsule: InvestigationMachineGateNodeObservation,
        terminal: InvestigationMachineGateTerminalObservation,
        startedNanoseconds: UInt64
    ) throws -> InvestigationMachineGatePreparedFrame {
        try InvestigationMachineGatePreparedFrame(
            gateProcessID: gateProcessID,
            coordinatorProcessID: coordinatorProcessID,
            sessionID: coordinatorProcessID,
            childProcessID: childProcessID,
            recoveryProcessGroupID: gateProcessID,
            savedForegroundProcessGroupID: coordinatorProcessID,
            childParentProcessID: gateProcessID,
            childSessionID: coordinatorProcessID,
            childStartSeconds: childStartSeconds,
            childStartMicroseconds: childStartMicroseconds,
            initialStopStatus: 0x7f,
            outerAttemptUUID: outerAttemptUUID,
            wholeInputSHA256: wholeInputSHA256,
            capsule: capsule,
            terminal: terminal,
            absoluteDeadlineNanoseconds:
                startedNanoseconds
                + InvestigationMachineFixedGateContract.deadlineNanoseconds
        )
    }

    private static func makeTransportReceipt(
        launcherExecutableSHA256: InvestigationHandoffSHA256,
        gateProcessID: pid_t,
        coordinatorProcessID: pid_t,
        childProcessID: pid_t,
        childStartSeconds: UInt64,
        childStartMicroseconds: UInt64,
        outerAttemptUUID: UUID,
        wholeInputSHA256: InvestigationHandoffSHA256,
        preparedFrameSHA256: InvestigationHandoffSHA256,
        capsule: InvestigationMachineGateNodeObservation,
        initialTerminal: InvestigationMachineGateTerminalObservation,
        startedNanoseconds: UInt64,
        completedNanoseconds: UInt64,
        forwardedSignal: Int32? = nil,
        deadlineExpired: Bool = false,
        waitClassification: InvestigationMachineGateWaitClassification =
            .exited(status: 0)
    ) throws -> InvestigationMachineGateTransportReceipt {
        let output = Data("bounded gate output".utf8)
        return try InvestigationMachineGateTransportReceipt(
            launcherExecutableSHA256: launcherExecutableSHA256,
            outerAttemptUUID: outerAttemptUUID,
            wholeInputSHA256: wholeInputSHA256,
            preparedFrameSHA256: preparedFrameSHA256,
            capsule: capsule,
            gateProcessID: gateProcessID,
            coordinatorProcessID: coordinatorProcessID,
            sessionID: coordinatorProcessID,
            recoveryProcessGroupID: gateProcessID,
            savedForegroundProcessGroupID: coordinatorProcessID,
            childIdentity: .init(
                processID: childProcessID,
                parentProcessID: gateProcessID,
                processGroupID: gateProcessID,
                sessionID: coordinatorProcessID,
                startSeconds: childStartSeconds,
                startMicroseconds: childStartMicroseconds
            ),
            input: .init(
                node: capsule,
                initialOffset: 0,
                finalOffset: capsule.size,
                reachedEOF: true,
                sha256: wholeInputSHA256
            ),
            initialTerminal: initialTerminal,
            childTerminal: .init(
                device: initialTerminal.device,
                inode: initialTerminal.inode,
                foregroundProcessGroupID: gateProcessID
            ),
            finalTerminal: initialTerminal,
            output: .init(
                byteCount: output.count,
                sha256: .hashing(output),
                overflowObserved: false,
                reachedEOF: true,
                deadlineExpired: deadlineExpired
            ),
            waitClassification: waitClassification,
            forwardedSignal: forwardedSignal,
            monotonicStartedNanoseconds: startedNanoseconds,
            monotonicCompletedNanoseconds: completedNanoseconds,
            terminationProgression: .natural,
            childProcessGroupEmpty: true,
            exactChildReaped: true,
            savedForegroundProcessGroupRestored: true,
            borrowedDescriptorOutcome: .closed
        )
    }

    private static func projectedInput() throws
        -> InvestigationProjectedCohortInput
    {
        let capsule = try InvestigationCohortCapsule(
            outerAttemptUUID: uuid(1),
            epochs: try (0..<8).map { ordinal in
                let configuration = Data("configuration-\(ordinal)".utf8)
                return try InvestigationCohortEpoch(
                    ordinal: UInt32(ordinal),
                    epochUUID: uuid(UInt8(0x10 + ordinal)),
                    scenario: InvestigationHandoffScenario(
                        rawValue: UInt32(ordinal + 1)
                    )!,
                    configurationNonce: uuid(UInt8(0x20 + ordinal)),
                    configuration: configuration,
                    configurationSHA256: .hashing(configuration),
                    signedRuntimeBindingSHA256: digest(
                        UInt8(0x40 + ordinal)
                    )
                )
            }
        )
        return try InvestigationProjectedCohortInput(
            capsule: capsule,
            projections: try capsule.epochs.map { epoch in
                let ordinal = UInt8(epoch.ordinal)
                return try InvestigationInstalledL2IdentityProjection(
                    epochUUID: epoch.epochUUID,
                    configurationNonce: epoch.configurationNonce,
                    configurationValidBefore: .init(
                        rawValue:
                            2_000_000_000_000_000 + Int64(ordinal)
                    ),
                    configurationSHA256: epoch.configurationSHA256,
                    signedRuntimeBindingSHA256:
                        epoch.signedRuntimeBindingSHA256,
                    appExecutableSHA256: digest(0x51),
                    appBundleIdentifier:
                        InvestigationInstalledL2IdentityProjection
                            .fixedAppBundleIdentifier,
                    helperExecutableSHA256: digest(0x52),
                    helperServiceIdentifier:
                        InvestigationInstalledL2IdentityProjection
                            .fixedHelperServiceIdentifier,
                    machineDriverExecutableSHA256: digest(0x53),
                    machineDriverSigningIdentifier:
                        InvestigationInstalledL2IdentityProjection
                            .fixedMachineDriverSigningIdentifier,
                    machineDriverDesignatedRequirementSHA256: digest(0x54),
                    machineDriverCodeDirectoryHash:
                        Data(repeating: 0x55, count: 20),
                    machineClaimServiceIdentifier:
                        InvestigationInstalledL2IdentityProjection
                            .fixedMachineClaimServiceIdentifier
                )
            }
        )
    }

    private static func digest(
        _ byte: UInt8
    ) throws -> InvestigationHandoffSHA256 {
        try InvestigationHandoffSHA256(
            rawBytes: Data(repeating: byte, count: 32)
        )
    }

    private static func uuid(_ byte: UInt8) -> UUID {
        UUID(
            uuidString: "00000000-0000-4000-8000-0000000000"
                + String(format: "%02x", byte)
        )!
    }
}
