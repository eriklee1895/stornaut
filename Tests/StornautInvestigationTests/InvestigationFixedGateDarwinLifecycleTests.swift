import Darwin
import Foundation
import Testing

@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationMachineGateSupport
@testable import StornautInvestigationMachineLaunchSupport

@Suite("Investigation fixed gate Darwin lifecycle", .serialized)
struct InvestigationFixedGateDarwinLifecycleTests {
    @Test
    func everyPostSpawnProjectionStageCanExposeExactReapEvidence() {
        for stage in [
            InvestigationFixedGateDarwinProjectionStage.spawned,
            .prepared, .stopped, .continued, .terminal,
        ] {
            #expect(stage.allowsExactGateReplay)
        }
        for stage in [
            InvestigationFixedGateDarwinProjectionStage.initial,
            .published, .reaped, .empty, .closed, .settled,
        ] {
            #expect(!stage.allowsExactGateReplay)
        }
    }

    @Test
    func missingReplayFramesPreserveExactGateTermination() throws {
        let wait = InvestigationMachineGateWaitClassification.exited(status: 70)
        let preparedDeath = makeReplay(
            terminalWait: wait, preparedReadTermination: wait
        )

        #expect(throws: InvestigationFixedGateHandoffSystemError
            .gateTerminated(wait)) {
            _ = try preparedDeath.requiredFrame(
                preparedDeath.prepared,
                observedTermination: preparedDeath.preparedReadTermination
            )
        }
        let terminalDeath = makeReplay(
            terminalWait: wait, terminalReadTermination: wait
        )
        #expect(throws: InvestigationFixedGateHandoffSystemError
            .gateTerminated(wait)) {
            _ = try terminalDeath.projectedTerminalFrame()
        }

        let cleanupOnly = makeReplay(terminalWait: wait)
        #expect(throws: InvestigationFixedGateHandoffSystemError
            .unexpectedResponse) {
            _ = try cleanupOnly.requiredFrame(
                cleanupOnly.prepared, observedTermination: nil
            )
        }
        #expect(throws: InvestigationFixedGateHandoffSystemError
            .unexpectedResponse) {
            _ = try cleanupOnly.projectedTerminalFrame()
        }
    }

    @Test
    func malformedTerminalPrecedesCoordinatorSignal() throws {
        let malformed = InvestigationFixedGateDarwinFrameObservation(
            bytes: Data([0xff]), reachedEOF: true, overflowObserved: false
        )
        let replay = makeReplay(terminal: malformed, coordinatorSignal: SIGTERM)

        #expect(try replay.projectedTerminalFrame() == malformed)
    }

    @Test
    func canonicalTerminalMustAgreeWithCoordinatorSignal() throws {
        let signal = SIGTERM
        let matching = makeReplay(
            terminal: .init(
                bytes: try terminalReceiptBytes(forwardedSignal: signal),
                reachedEOF: true, overflowObserved: false
            ),
            coordinatorSignal: signal
        )
        let matchingFrame = try matching.projectedTerminalFrame()
        #expect(
            try InvestigationMachineGateTransportReceipt
                .decode(matchingFrame.bytes).forwardedSignal == signal
        )

        let mismatched = makeReplay(
            terminal: .init(
                bytes: try terminalReceiptBytes(forwardedSignal: SIGINT),
                reachedEOF: true, overflowObserved: false
            ),
            coordinatorSignal: signal
        )
        #expect(throws: InvestigationFixedGateHandoffError.identityMismatch) {
            _ = try mismatched.projectedTerminalFrame()
        }

        let gateOnly = makeReplay(
            terminal: .init(
                bytes: try terminalReceiptBytes(forwardedSignal: signal),
                reachedEOF: true, overflowObserved: false
            )
        )
        #expect(throws: InvestigationFixedGateHandoffError.identityMismatch) {
            _ = try gateOnly.projectedTerminalFrame()
        }
    }

    @Test
    func outerSpawnUsesExactUnsuspendedDescriptorAndSignalContract() throws {
        let system = DarwinLifecycleRecorder()
        _ = try makeLifecycle(system).run(makeInput())
        let request = try #require(system.spawnRequest)

        #expect(request.executablePath == system.executablePath)
        #expect(request.arguments == [system.executablePath])
        #expect(request.environment.isEmpty)
        #expect(request.processGroupID == 0)
        #expect(request.flags == Int16(
            POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETPGROUP
                | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF
        ))
        #expect(request.flags & Int16(POSIX_SPAWN_START_SUSPENDED) == 0)
        #expect(request.fileActions == [
            .duplicate(source: inputDescriptor, destination: STDIN_FILENO),
            .duplicate(source: system.pipeWrite, destination: STDOUT_FILENO),
            .inherit(STDERR_FILENO),
            .close(system.pipeRead),
            .close(system.pipeWrite),
        ])
        #expect(request.signalMask.sorted() == expectedBlockedSignals.sorted())
        #expect(request.signalDefaults.sorted() == expectedDefaultSignals.sorted())
    }

    @Test
    func typedSpawnResultSeparatesDefiniteNoSpawnFromTransferUncertainty() throws {
        for (scenario, expected) in [
            (DarwinLifecycleScenario.spawnDefinitelyNotCreated,
             InvestigationFixedGateDarwinLifecycleDisposition.definitelyNotSpawned),
            (.spawnOrTransferUncertain, .spawnOrTransferUncertain),
        ] {
            let system = DarwinLifecycleRecorder(scenario: scenario)
            let result = try makeLifecycle(system).run(makeInput())
            #expect(result == expected)
            #expect(system.events.filter(\.isSpawn).count == 1)
            if scenario == .spawnDefinitelyNotCreated {
                #expect(!system.events.contains { $0.isReap })
            } else {
                #expect(system.events.contains(.signalProcess(SIGKILL)))
                #expect(system.events.filter(\.isReap).count == 1)
            }
        }
    }

    @Test(arguments: DarwinExecutableMutation.allCases)
    func executableMetadataACLXattrReplacementAndHashDriftFailBeforeSpawn(
        _ mutation: DarwinExecutableMutation
    ) throws {
        let system = DarwinLifecycleRecorder(scenario: .executable(mutation))
        let result = try makeLifecycle(system).run(makeInput())

        #expect(result == .definitelyNotSpawned)
        #expect(system.events.contains(.acquireExecutable))
        #expect(system.events.contains(.revalidateExecutable))
        #expect(!system.events.contains { $0.isSpawn })
    }

    @Test
    func oneImmutableDeadlineSurvivesEINTRAcrossAllTimedOperations() throws {
        let system = DarwinLifecycleRecorder(scenario: .interruptPreparedReadOnce)
        #expect(try makeLifecycle(system).run(makeInput()) == .exactGateReaped)

        #expect(system.events.filter(\.isDeadlineCreation).count == 1)
        #expect(system.events.filter(\.isPreparedRead).count == 2)
        #expect(system.events.compactMap(\.businessDeadline)
            .allSatisfy { $0 == system.operationDeadline })
        #expect(system.events.compactMap(\.cleanupDeadline)
            .allSatisfy { $0 == system.absoluteDeadline })
        #expect(system.events.contains(.waitID(
            Int32(WEXITED | WNOHANG | WNOWAIT), system.operationDeadline
        )))
    }

    @Test
    func descriptorCloseIsAttemptedOnceAndAnyUncertaintyDominates() throws {
        let system = DarwinLifecycleRecorder(scenario: .closeUncertain)
        let result = try makeLifecycle(system).run(makeInput())

        #expect(result == .spawnOrTransferUncertain)
        #expect(system.closeCounts[system.executableDescriptor] == 1)
        #expect(system.closeCounts[system.pipeWrite] == 1)
        #expect(system.closeCounts.values.allSatisfy { $0 == 1 })
        #expect(!system.events.contains { $0.isPreparedRead })
        #expect(system.events.contains(.signalProcess(SIGKILL)))
        #expect(system.events.filter(\.isReap).count == 1)
    }

    @Test
    func postSpawnExecutableRevalidationFailureStillReapsTheGate() throws {
        let system = DarwinLifecycleRecorder(
            scenario: .postSpawnRevalidationThrows
        )

        #expect(
            try makeLifecycle(system).run(makeInput())
                == .spawnOrTransferUncertain
        )
        let revalidations = system.events.indices.filter {
            system.events[$0] == .revalidateExecutable
        }
        #expect(revalidations.count == 2)
        let secondRevalidation = try #require(revalidations.last)
        let kill = try index(.signalProcess(SIGKILL), in: system.events)
        let resumed = try index(
            .signalProcess(SIGCONT), in: system.events, after: kill
        )
        let pinned = try index(
            .waitID(
                Int32(WEXITED | WNOHANG | WNOWAIT), system.absoluteDeadline
            ),
            in: system.events
        )
        let reaped = try index(
            .reap(Int32(WNOHANG), system.absoluteDeadline), in: system.events
        )
        #expect(secondRevalidation < kill)
        #expect(kill < resumed && resumed < pinned && pinned < reaped)
    }

    @Test
    func failedInitialContinueUsesTheBoundedCleanupPath() throws {
        let system = DarwinLifecycleRecorder(scenario: .continueFailure)

        #expect(
            try makeLifecycle(system).run(makeInput())
                == .spawnOrTransferUncertain
        )
        #expect(
            system.events.compactMap(\.processSignal)
                == [SIGCONT, SIGKILL, SIGCONT]
        )
        #expect(!system.events.contains { $0.isTerminalRead })
        #expect(system.events.contains(.waitID(
            Int32(WEXITED | WNOHANG | WNOWAIT), system.absoluteDeadline
        )))
        #expect(system.events.filter(\.isReap).count == 1)
    }

    @Test
    func terminalReadTimeoutKillsAndPinsBeforeGroupCleanupAndReap() throws {
        let system = DarwinLifecycleRecorder(scenario: .terminalReadTimeout)

        #expect(
            try makeLifecycle(system).run(makeInput())
                == .spawnOrTransferUncertain
        )
        let terminalRead = try index(
            .readTerminal(system.operationDeadline), in: system.events
        )
        let kill = try index(.signalProcess(SIGKILL), in: system.events)
        let resumed = try index(
            .signalProcess(SIGCONT), in: system.events, after: kill
        )
        let pinned = try index(
            .waitID(
                Int32(WEXITED | WNOHANG | WNOWAIT), system.absoluteDeadline
            ),
            in: system.events
        )
        let firstGroupSignal = system.events.firstIndex { $0.groupSignal != nil }
        #expect(terminalRead < kill && kill < resumed && resumed < pinned)
        if let firstGroupSignal { #expect(pinned < firstGroupSignal) }
        #expect(system.events.filter(\.isReap).count == 1)
    }

    @Test
    func invalidLowPipeDescriptorsAreClosedBeforeDefiniteFailure() throws {
        let system = DarwinLifecycleRecorder(scenario: .invalidLowPipe)

        #expect(try makeLifecycle(system).run(makeInput()) == .definitelyNotSpawned)
        #expect(system.closeCounts[STDIN_FILENO] == 1)
        #expect(system.closeCounts[STDOUT_FILENO] == 1)
        #expect(!system.events.contains { $0.isSpawn })
    }

    @Test(arguments: [
        DarwinLifecycleScenario.acquireCleanupUncertain,
        .pipeCleanupUncertain,
    ])
    func preSpawnCloseUncertaintyCannotMintNeverHandedOffProof(
        _ scenario: DarwinLifecycleScenario
    ) throws {
        let system = DarwinLifecycleRecorder(scenario: scenario)

        #expect(
            try makeLifecycle(system).run(makeInput())
                == .spawnOrTransferUncertain
        )
        #expect(!system.events.contains { $0.isSpawn })
    }

    @Test
    func preparedStopTopologyTTYAndContinueHaveExactOrder() throws {
        let system = DarwinLifecycleRecorder()
        #expect(try makeLifecycle(system).run(makeInput()) == .exactGateReaped)
        let events = system.events

        #expect(try index(.readPrepared(system.operationDeadline), in: events)
            < index(.waitPreparedStop(system.operationDeadline), in: events))
        let topologyIndices = events.indices.filter {
            events[$0] == .observeTopology
        }
        #expect(topologyIndices.count == 2)
        #expect(try #require(topologyIndices.first)
            < index(.readPrepared(system.operationDeadline), in: events))
        let stoppedTopology = try #require(topologyIndices.last)
        #expect(try index(.waitPreparedStop(system.operationDeadline), in: events)
            < stoppedTopology)
        #expect(try stoppedTopology < index(.observeTTY, in: events))
        #expect(try index(.observeTTY, in: events)
            < index(.signalProcess(SIGCONT), in: events))
        #expect(try index(.signalProcess(SIGCONT), in: events)
            < index(.readTerminal(system.operationDeadline), in: events))
    }

    @Test
    func successUsesWNOWAITRestoresCoordinatorDrainsReapsLastAndProvesEmpty() throws {
        let system = DarwinLifecycleRecorder()
        let lifecycle = makeLifecycle(system)
        let borrower: any InvestigationOwnerOnlyCapsuleOutcomeBorrowing = lifecycle
        _ = borrower

        #expect(try lifecycle.run(makeInput()) == .exactGateReaped)
        let events = system.events
        let waitable = try index(
            .waitID(Int32(WEXITED | WNOHANG | WNOWAIT), system.operationDeadline),
            in: events
        )
        let restored = try index(.restoreForeground(system.coordinatorPGID), in: events)
        let firstInventory = try index(.inventory(system.absoluteDeadline), in: events)
        let reap = try index(.reap(Int32(WNOHANG), system.absoluteDeadline), in: events)
        let postReap = try #require(events.lastIndex(of: .inventory(system.absoluteDeadline)))
        #expect(waitable < restored)
        #expect(restored < firstInventory)
        #expect(firstInventory < reap)
        #expect(reap < postReap)
        #expect(events.filter(\.isReap).count == 1)
        #expect(system.inventoryResponses.last?.processIDs.isEmpty == true)
    }

    @Test(arguments: DarwinGateDeathStage.allCases)
    func gateDeathBeforeOrAfterPreparedDrainsDescendantsBeforeExactReap(
        _ stage: DarwinGateDeathStage
    ) throws {
        let system = DarwinLifecycleRecorder(scenario: .gateDeath(stage))
        #expect(try makeLifecycle(system).run(makeInput()) == .exactGateReaped)

        let signals = system.events.compactMap(\.groupSignal)
        #expect(signals == [SIGTERM, SIGCONT, SIGKILL])
        let reap = try index(.reap(Int32(WNOHANG), system.absoluteDeadline),
                             in: system.events)
        #expect(try index(.signalGroup(SIGKILL), in: system.events) < reap)
        let postReap = try #require(
            system.events.lastIndex(of: .inventory(system.absoluteDeadline))
        )
        #expect(reap < postReap)
        let kill = try index(.signalGroup(SIGKILL), in: system.events)
        let betweenKillAndReap = system.events[(kill + 1)..<reap].filter {
            $0 == .inventory(system.absoluteDeadline)
        }
        #expect(betweenKillAndReap.count >= 2)
        #expect(system.events.compactMap(\.inventoryDeadline)
            .allSatisfy { $0 == system.absoluteDeadline })
    }

    @Test(arguments: DarwinContainmentFailure.allCases)
    func invalidInventoryReusedGroupAndWaitMismatchWithholdProof(
        _ failure: DarwinContainmentFailure
    ) throws {
        let system = DarwinLifecycleRecorder(scenario: .containment(failure))
        #expect(
            try makeLifecycle(system).run(makeInput())
                == .spawnOrTransferUncertain
        )
        #expect(system.events.filter(\.isSpawn).count == 1)
        if failure == .waitMismatch || failure == .nonWaitableTerminalPin {
            #expect(system.events.contains(.signalProcess(SIGKILL)))
            #expect(system.events.contains(.inventory(system.absoluteDeadline)))
            #expect(system.events.filter(\.isReap).count == 1)
        }
    }

    @Test(arguments: [SIGHUP, SIGINT, SIGQUIT, SIGTERM])
    func consumesForwardedSignalAfterTerminalWithoutDuplicateForwarding(
        _ signal: Int32
    ) throws {
        let system = DarwinLifecycleRecorder(scenario: .forwardedSignal(signal))
        let lifecycle = makeLifecycle(system)
        #expect(try lifecycle.run(makeInput()) == .exactGateReaped)
        #expect(lifecycle.replay?.coordinatorForwardedSignal == signal)
        #expect(
            system.events.filter {
                $0 == .consumeSignal(system.absoluteDeadline)
            }.count == 1
        )
        #expect(try index(
            .waitID(
                Int32(WEXITED | WNOHANG | WNOWAIT), system.operationDeadline
            ),
            in: system.events
        ) < index(.consumeSignal(system.absoluteDeadline), in: system.events))
        #expect(try index(
            .consumeSignal(system.absoluteDeadline), in: system.events
        ) < index(.restoreForeground(system.coordinatorPGID), in: system.events))
        #expect(!system.events.contains {
            if case .signalProcess(let observed) = $0 { observed == signal }
            else { false }
        })
        #expect(expectedForwardedSignals.contains(signal))
    }

    @Test
    func malformedPreparedBytesStillProduceExactPhysicalReapEvidence() throws {
        let system = DarwinLifecycleRecorder(scenario: .malformedPrepared)

        #expect(try makeLifecycle(system).run(makeInput()) == .exactGateReaped)
        #expect(system.events.filter(\.isReap).count == 1)
        #expect(system.inventoryResponses.last?.processIDs.isEmpty == true)
    }

    @Test
    func recoveryDrainUsesTheAbsoluteDeadlineBeyondTheLegacyObservationCap()
        throws
    {
        let system = DarwinLifecycleRecorder(scenario: .delayedDrain)

        #expect(try makeLifecycle(system).run(makeInput()) == .exactGateReaped)
        #expect(system.inventoryResponses.count > 512)
        #expect(system.events.compactMap(\.inventoryDeadline)
            .allSatisfy { $0 == system.absoluteDeadline })
        #expect(system.events.compactMap(\.groupSignal)
            == [SIGTERM, SIGCONT, SIGKILL])
        #expect(system.events.filter(\.isReap).count == 1)
        #expect(system.inventoryResponses.last?.processIDs.isEmpty == true)
    }

    @Test
    func recoveryDrainDeadlineFailureWithholdsReapAndEmptyProof() throws {
        let system = DarwinLifecycleRecorder(scenario: .drainDeadlineExpired)
        let lifecycle = makeLifecycle(system)

        #expect(try lifecycle.run(makeInput()) == .spawnOrTransferUncertain)
        #expect(system.events.contains(.inventory(system.absoluteDeadline)))
        #expect(!system.events.contains { $0.isReap })
        #expect(lifecycle.replay?.exactGateReaped == false)
        #expect(lifecycle.replay?.processGroupEmpty == false)
    }

    @Test
    func terminalDriftRestoresSavedForegroundButWithholdsProof() throws {
        let system = DarwinLifecycleRecorder(scenario: .ttyDrift)
        #expect(try makeLifecycle(system).run(makeInput()) == .spawnOrTransferUncertain)
        #expect(system.events.contains(.restoreForeground(system.coordinatorPGID)))
        #expect(system.events.contains(.inventory(system.absoluteDeadline)))
        #expect(system.events.filter(\.isReap).count == 1)
    }
}

enum DarwinExecutableMutation: CaseIterable, Sendable {
    case owner, mode, flags, linkCount, acl, xattr, replacement, hash
}

enum DarwinGateDeathStage: CaseIterable, Sendable {
    case beforePrepared, afterPrepared, duringTerminal
}

enum DarwinContainmentFailure: CaseIterable, Sendable {
    case incompleteInventory, duplicateInventory, invalidPID, reusedGroup
    case waitMismatch, nonWaitableTerminalPin
}

enum DarwinLifecycleScenario: Equatable, Sendable {
    case success
    case spawnDefinitelyNotCreated
    case spawnOrTransferUncertain
    case interruptPreparedReadOnce
    case invalidLowPipe
    case acquireCleanupUncertain
    case pipeCleanupUncertain
    case malformedPrepared
    case delayedDrain
    case drainDeadlineExpired
    case postSpawnRevalidationThrows
    case continueFailure
    case terminalReadTimeout
    case executable(DarwinExecutableMutation)
    case closeUncertain
    case gateDeath(DarwinGateDeathStage)
    case containment(DarwinContainmentFailure)
    case forwardedSignal(Int32)
    case ttyDrift
}

private enum DarwinLifecycleEvent: Equatable, Sendable {
    case observeCoordinator, createDeadline, acquireExecutable, makePipe
    case revalidateExecutable, spawn, close(Int32)
    case readPrepared(UInt64), waitPreparedStop(UInt64)
    case observeTopology, observeTTY, consumeSignal(UInt64)
    case signalProcess(Int32), readTerminal(UInt64)
    case waitID(Int32, UInt64), restoreForeground(pid_t)
    case inventory(UInt64), signalGroup(Int32), reap(Int32, UInt64)

    var businessDeadline: UInt64? {
        switch self {
        case .readPrepared(let value), .waitPreparedStop(let value),
             .readTerminal(let value): value
        default: nil
        }
    }
    var cleanupDeadline: UInt64? {
        switch self {
        case .consumeSignal(let value), .inventory(let value),
             .reap(_, let value): value
        default: nil
        }
    }
    var inventoryDeadline: UInt64? {
        if case .inventory(let value) = self { value } else { nil }
    }
    var processSignal: Int32? {
        if case .signalProcess(let value) = self { value } else { nil }
    }
    var groupSignal: Int32? { if case .signalGroup(let value) = self { value } else { nil } }
    var isSpawn: Bool { self == .spawn }
    var isDeadlineCreation: Bool { self == .createDeadline }
    var isPreparedRead: Bool { if case .readPrepared = self { true } else { false } }
    var isTerminalRead: Bool { if case .readTerminal = self { true } else { false } }
    var isReap: Bool { if case .reap = self { true } else { false } }
}

private final class DarwinLifecycleRecorder:
    InvestigationFixedGateDarwinLifecycleSystem, @unchecked Sendable
{
    let executablePath = "/Applications/Stornaut.app/Contents/MacOS/"
        + "StornautInvestigationMachineGate"
    let executableDescriptor: Int32 = 40
    let pipeRead: Int32 = 41
    let pipeWrite: Int32 = 42
    let gatePID: pid_t = 5_001
    let coordinatorPGID: pid_t = 4_001
    let absoluteDeadline: UInt64 = 1_300_000_000_000
    var operationDeadline: UInt64 { absoluteDeadline - 5_000_000_000 }
    private let scenario: DarwinLifecycleScenario
    private var preparedReads = 0
    private var signalConsumed = false
    private var inventoryCalls = 0
    private var topologyCalls = 0
    private var waitIDCalls = 0
    private var revalidationCalls = 0
    private var signalProcessCalls = 0
    private(set) var events: [DarwinLifecycleEvent] = []
    private(set) var spawnRequest: InvestigationFixedGateDarwinSpawnRequest?
    private(set) var closeCounts: [Int32: Int] = [:]
    private(set) var inventoryResponses: [InvestigationFixedGateDarwinInventoryObservation] = []

    init(scenario: DarwinLifecycleScenario = .success) { self.scenario = scenario }

    func perform(_ operation: InvestigationFixedGateDarwinLifecycleOperation) throws
        -> InvestigationFixedGateDarwinLifecycleResponse
    {
        switch operation {
        case .observeCoordinator:
            events.append(.observeCoordinator)
            return .coordinator(.init(
                processID: coordinatorPGID, processGroupID: coordinatorPGID,
                terminal: terminal(foreground: coordinatorPGID)))
        case .makeAbsoluteDeadline(let duration):
            events.append(.createDeadline)
            #expect(duration == InvestigationMachineFixedGateContract.deadlineNanoseconds)
            return .absoluteDeadline(absoluteDeadline)
        case .acquireSiblingExecutable(let name, let maximum):
            events.append(.acquireExecutable)
            #expect(name == "StornautInvestigationMachineGate")
            #expect(maximum == 64 << 20)
            if case .acquireCleanupUncertain = scenario {
                throw InvestigationFixedGateDarwinLifecycleSystemError
                    .preSpawnCleanupUncertain
            }
            return .gateExecutable(executable(mutation: initialMutation))
        case .makeTransportPipe:
            events.append(.makePipe)
            if case .pipeCleanupUncertain = scenario {
                throw InvestigationFixedGateDarwinLifecycleSystemError
                    .preSpawnCleanupUncertain
            }
            if case .invalidLowPipe = scenario {
                return .descriptorPair(.init(
                    read: STDIN_FILENO, write: STDOUT_FILENO
                ))
            }
            return .descriptorPair(.init(read: pipeRead, write: pipeWrite))
        case .revalidateGateExecutable(let descriptor):
            events.append(.revalidateExecutable)
            #expect(descriptor == executableDescriptor)
            revalidationCalls += 1
            if case .postSpawnRevalidationThrows = scenario,
               revalidationCalls == 2
            { throw InvestigationFixedGateDarwinLifecycleSystemError.uncertain }
            return .gateExecutable(executable(mutation: revalidationMutation))
        case .spawnGate(let request):
            events.append(.spawn); spawnRequest = request
            switch scenario {
            case .spawnDefinitelyNotCreated: return .spawn(.definitelyNotSpawned)
            case .spawnOrTransferUncertain:
                return .spawn(.spawnOrTransferUncertain(
                    processID: gatePID, processGroupID: gatePID))
            default:
                return .spawn(.spawned(processID: gatePID, processGroupID: gatePID))
            }
        case .closeDescriptor(let descriptor):
            events.append(.close(descriptor)); closeCounts[descriptor, default: 0] += 1
            if case .closeUncertain = scenario, descriptor == pipeWrite {
                throw InvestigationFixedGateDarwinLifecycleSystemError.errno(EIO)
            }
            return .completed
        case .readPrepared(let descriptor, let maximum, let deadline):
            events.append(.readPrepared(deadline)); preparedReads += 1
            #expect(descriptor == pipeRead)
            #expect(maximum == InvestigationMachineGatePreparedFrame.maximumByteCount)
            if case .interruptPreparedReadOnce = scenario, preparedReads == 1 {
                throw InvestigationFixedGateDarwinLifecycleSystemError.errno(EINTR)
            }
            if case .gateDeath(.beforePrepared) = scenario {
                return .gateTerminated(wait(processID: gatePID))
            }
            if case .malformedPrepared = scenario {
                return .frame(.init(
                    bytes: Data([0xff]), reachedEOF: false,
                    overflowObserved: false
                ))
            }
            return .frame(.init(
                bytes: try preparedFrameBytes(), reachedEOF: false,
                overflowObserved: false))
        case .waitPreparedStop(let processID, let deadline):
            events.append(.waitPreparedStop(deadline)); #expect(processID == gatePID)
            if case .gateDeath(.afterPrepared) = scenario {
                return .wait(wait(processID: gatePID))
            }
            return .wait(.init(
                processID: gatePID, classification: .stopped(signal: SIGSTOP),
                waitableWithoutReap: true))
        case .observeGateTopology:
            events.append(.observeTopology)
            defer { topologyCalls += 1 }
            return .topology(.init(
                gateProcessID: gatePID, parentProcessID: coordinatorPGID,
                gateProcessGroupID:
                    topologyCalls == 0 ? gatePID : coordinatorPGID,
                gateSessionID: coordinatorPGID,
                gateStartSeconds: 101, gateStartMicroseconds: 202,
                coordinatorProcessGroupID: coordinatorPGID))
        case .observeTTY:
            events.append(.observeTTY)
            return .terminal(terminal(foreground: ttyForeground))
        case .consumeForwardedSignal(let deadline):
            events.append(.consumeSignal(deadline))
            defer { signalConsumed = true }
            if case .forwardedSignal(let signal) = scenario, !signalConsumed {
                return .signal(signal)
            }
            return .signal(nil)
        case .signalProcess(let processID, let signal):
            events.append(.signalProcess(signal)); signalProcessCalls += 1
            #expect(processID == gatePID)
            if case .continueFailure = scenario, signal == SIGCONT,
               signalProcessCalls == 1
            { throw InvestigationFixedGateDarwinLifecycleSystemError.errno(EIO) }
            return .completed
        case .readTerminal(let descriptor, let maximum, let deadline):
            events.append(.readTerminal(deadline)); #expect(descriptor == pipeRead)
            #expect(maximum == InvestigationMachineGateTransportReceipt.maximumByteCount)
            if case .gateDeath(.duringTerminal) = scenario {
                return .gateTerminated(wait(processID: gatePID))
            }
            if case .terminalReadTimeout = scenario {
                throw InvestigationFixedGateDarwinLifecycleSystemError.uncertain
            }
            return .frame(.init(bytes: Data([2]), reachedEOF: true, overflowObserved: false))
        case .waitID(let processID, let options, let deadline):
            events.append(.waitID(options, deadline)); #expect(processID == gatePID)
            waitIDCalls += 1
            if case .containment(.waitMismatch) = scenario, waitIDCalls == 1 {
                return .wait(wait(processID: gatePID + 1))
            }
            if case .containment(.nonWaitableTerminalPin) = scenario,
               waitIDCalls == 1
            { return .wait(wait(processID: gatePID, waitableWithoutReap: false)) }
            return .wait(wait(processID: gatePID))
        case .restoreForeground(let processGroupID):
            events.append(.restoreForeground(processGroupID)); return .completed
        case .inventoryProcessGroup(let processGroupID, _, let deadline):
            events.append(.inventory(deadline)); #expect(processGroupID == gatePID)
            if case .drainDeadlineExpired = scenario {
                throw InvestigationFixedGateDarwinLifecycleSystemError.uncertain
            }
            let observation = inventory(); inventoryCalls += 1
            inventoryResponses.append(observation); return .inventory(observation)
        case .signalProcessGroup(let processGroupID, let signal):
            events.append(.signalGroup(signal)); #expect(processGroupID == gatePID)
            return .completed
        case .waitPID(let processID, let options, let deadline):
            events.append(.reap(options, deadline)); #expect(processID == gatePID)
            return .wait(wait(
                processID: gatePID, waitableWithoutReap: false
            ))
        }
    }

    private var initialMutation: DarwinExecutableMutation? { nil }
    private var revalidationMutation: DarwinExecutableMutation? {
        if case .executable(let value) = scenario { value } else { nil }
    }
    private var ttyForeground: pid_t {
        if case .ttyDrift = scenario { coordinatorPGID + 9 } else { coordinatorPGID }
    }

    private func executable(mutation: DarwinExecutableMutation?)
        -> InvestigationFixedGateDarwinExecutableObservation
    {
        let original = node(inode: 90)
        return .init(
            descriptor: executableDescriptor, path: executablePath,
            descriptorIdentity: original,
            namedIdentity: mutation == .replacement ? node(inode: 91) : original,
            ownerUserID: mutation == .owner ? uid_t(502) : getuid(),
            ownerGroupID: getgid(), permissions: mutation == .mode ? 0o777 : 0o755,
            linkCount: mutation == .linkCount ? 2 : 1,
            flags: mutation == .flags ? UInt32(UF_IMMUTABLE) : 0,
            extendedACLIsEmpty: mutation != .acl,
            extendedAttributeNames: mutation == .xattr ? ["fixture"] : [],
            sha256: digest(mutation == .hash ? 0x92 : 0x91),
            bytesSHA256: digest(0x91))
    }

    private func preparedFrameBytes() throws -> Data {
        try InvestigationMachineGatePreparedFrame(
            gateProcessID: gatePID, coordinatorProcessID: coordinatorPGID,
            sessionID: coordinatorPGID, childProcessID: gatePID + 1,
            recoveryProcessGroupID: gatePID,
            savedForegroundProcessGroupID: coordinatorPGID,
            childParentProcessID: gatePID, childSessionID: coordinatorPGID,
            childStartSeconds: 101, childStartMicroseconds: 202,
            initialStopStatus: 0x7f, outerAttemptUUID: outerAttemptUUID,
            wholeInputSHA256: capsuleDigest, capsule: capsuleNode,
            terminal: terminal(foreground: coordinatorPGID),
            absoluteDeadlineNanoseconds: absoluteDeadline - 1_000_000_000
        ).encoded()
    }

    private func inventory() -> InvestigationFixedGateDarwinInventoryObservation {
        if case .containment(.incompleteInventory) = scenario {
            return .init(processIDs: [gatePID], complete: false)
        }
        if case .containment(.duplicateInventory) = scenario {
            return .init(processIDs: [gatePID, gatePID], complete: true)
        }
        if case .containment(.invalidPID) = scenario {
            return .init(processIDs: [0], complete: true)
        }
        if case .containment(.reusedGroup) = scenario, inventoryCalls > 0 {
            return .init(processIDs: [gatePID + 10], complete: true)
        }
        if case .gateDeath = scenario {
            switch inventoryCalls {
            case 0, 1: return .init(processIDs: [gatePID, gatePID + 1], complete: true)
            case 2: return .init(processIDs: [gatePID], complete: true)
            default: return .init(processIDs: [], complete: true)
            }
        }
        if case .malformedPrepared = scenario {
            return .init(
                processIDs: inventoryCalls == 0 ? [gatePID] : [],
                complete: true
            )
        }
        if case .delayedDrain = scenario {
            if inventoryCalls < 513 {
                return .init(
                    processIDs: [gatePID, gatePID + 1], complete: true
                )
            }
            return .init(
                processIDs: inventoryCalls < 515 ? [gatePID] : [],
                complete: true
            )
        }
        return .init(processIDs: [], complete: true)
    }
}

private let inputDescriptor: Int32 = 17
private let outerAttemptUUID = UUID(
    uuidString: "00000000-0000-0000-0000-000000000039"
)!
private let capsuleDigest = digest(0x39)
private let capsuleNode = InvestigationMachineGateNodeObservation(
    device: 1, inode: 2, generation: 3, size: 4
)
private let expectedForwardedSignals: [Int32] = [SIGHUP, SIGINT, SIGQUIT, SIGTERM]
private let expectedBlockedSignals = expectedForwardedSignals + [SIGTTIN, SIGTTOU, SIGTSTP]
private let expectedDefaultSignals = expectedBlockedSignals + [SIGPIPE]

private func makeLifecycle(_ system: DarwinLifecycleRecorder)
    -> InvestigationFixedGateDarwinLifecycle
{ InvestigationFixedGateDarwinLifecycle(system: system) }

private func makeInput() -> InvestigationFixedGateDarwinLifecycleInput {
    .init(
        capsuleDescriptor: inputDescriptor,
        outerAttemptUUID: outerAttemptUUID,
        capsuleIdentity: .init(device: 1, inode: 2, generation: 3, size: 4),
        capsuleDigest: capsuleDigest)
}

private func node(inode: UInt64) -> InvestigationFixedGateDarwinNodeIdentity {
    .init(device: 8, inode: inode, generation: 1, size: 4_096)
}

private func terminal(foreground: pid_t)
    -> InvestigationMachineGateTerminalObservation
{ .init(device: 10, inode: 11, foregroundProcessGroupID: foreground) }

private func wait(
    processID: pid_t, waitableWithoutReap: Bool = true
) -> InvestigationFixedGateDarwinWaitObservation {
    .init(
        processID: processID, classification: .exited(status: 0),
        waitableWithoutReap: waitableWithoutReap)
}

private func digest(_ byte: UInt8) -> InvestigationHandoffSHA256 {
    try! .init(rawBytes: Data(repeating: byte, count: 32))
}

private func makeReplay(
    prepared: InvestigationFixedGateDarwinFrameObservation? = nil,
    terminal: InvestigationFixedGateDarwinFrameObservation? = nil,
    terminalWait: InvestigationMachineGateWaitClassification? =
        .exited(status: 70),
    preparedReadTermination: InvestigationMachineGateWaitClassification? = nil,
    terminalReadTermination: InvestigationMachineGateWaitClassification? = nil,
    coordinatorSignal: Int32? = nil
) -> InvestigationFixedGateDarwinLifecycleReplay {
    .init(
        gateProcessID: 5_001, gateProcessGroupID: 5_001,
        executableSHA256: digest(0x91), prepared: prepared,
        preparedStop: nil, terminal: terminal, terminalWait: terminalWait,
        preparedReadTermination: preparedReadTermination,
        terminalReadTermination: terminalReadTermination,
        coordinatorForwardedSignal: coordinatorSignal, exactGateReaped: true,
        processGroupEmpty: true, transportCloseCertain: true
    )
}

private func terminalReceiptBytes(forwardedSignal: Int32?) throws -> Data {
    let output = Data("bounded".utf8)
    let prepared = try InvestigationMachineGatePreparedFrame(
        gateProcessID: 5_001, coordinatorProcessID: 4_001, sessionID: 4_001,
        childProcessID: 5_002, recoveryProcessGroupID: 5_001,
        savedForegroundProcessGroupID: 4_001, childParentProcessID: 5_001,
        childSessionID: 4_001, childStartSeconds: 101,
        childStartMicroseconds: 202, initialStopStatus: 0x7f,
        outerAttemptUUID: outerAttemptUUID, wholeInputSHA256: capsuleDigest,
        capsule: capsuleNode, terminal: terminal(foreground: 4_001),
        absoluteDeadlineNanoseconds: 1_300_000_000_000
    )
    return try InvestigationMachineGateTransportReceipt(
        launcherExecutableSHA256: digest(0x91),
        outerAttemptUUID: outerAttemptUUID, wholeInputSHA256: capsuleDigest,
        preparedFrameSHA256: .hashing(try prepared.encoded()),
        capsule: capsuleNode, gateProcessID: 5_001,
        coordinatorProcessID: 4_001, sessionID: 4_001,
        recoveryProcessGroupID: 5_001, savedForegroundProcessGroupID: 4_001,
        childIdentity: .init(
            processID: 5_002, parentProcessID: 5_001, processGroupID: 5_001,
            sessionID: 4_001, startSeconds: 101, startMicroseconds: 202
        ),
        input: .init(
            node: capsuleNode, initialOffset: 0, finalOffset: capsuleNode.size,
            reachedEOF: true, sha256: capsuleDigest
        ),
        initialTerminal: terminal(foreground: 4_001),
        childTerminal: terminal(foreground: 5_001),
        finalTerminal: terminal(foreground: 4_001),
        output: .init(
            byteCount: output.count, sha256: .hashing(output),
            overflowObserved: false
        ),
        waitClassification: .exited(status: forwardedSignal == nil ? 0 : 83),
        forwardedSignal: forwardedSignal, monotonicStartedNanoseconds: 100,
        monotonicCompletedNanoseconds: 200, terminationProgression: .natural,
        childProcessGroupEmpty: true, exactChildReaped: true,
        savedForegroundProcessGroupRestored: true,
        borrowedDescriptorOutcome: .closed
    ).encoded()
}

private func index(_ event: DarwinLifecycleEvent, in events: [DarwinLifecycleEvent])
    throws -> Int
{ try #require(events.firstIndex(of: event)) }

private func index(
    _ event: DarwinLifecycleEvent, in events: [DarwinLifecycleEvent], after: Int
) throws -> Int {
    try #require(events.indices.first { $0 > after && events[$0] == event })
}
