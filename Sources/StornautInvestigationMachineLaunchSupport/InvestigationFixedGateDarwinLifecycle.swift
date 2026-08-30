import Darwin
import Foundation
import StornautInvestigationHandoffContract
import StornautInvestigationMachineGateSupport

#if DEBUG
enum InvestigationFixedGateDarwinLifecycleSystemError: Error, Equatable, Sendable {
    case errno(Int32)
    case preSpawnCleanupUncertain
    case uncertain
}

struct InvestigationFixedGateDarwinNodeIdentity: Equatable, Sendable {
    let device, inode, generation: UInt64
    let size: Int64
}

struct InvestigationFixedGateDarwinExecutableObservation: Equatable, Sendable {
    let descriptor: Int32
    let path: String
    let descriptorIdentity: InvestigationFixedGateDarwinNodeIdentity
    let namedIdentity: InvestigationFixedGateDarwinNodeIdentity
    let ownerUserID: uid_t
    let ownerGroupID: gid_t
    let permissions: mode_t
    let linkCount: UInt64
    let flags: UInt32
    let extendedACLIsEmpty: Bool
    let extendedAttributeNames: [String]
    let sha256: InvestigationHandoffSHA256
    let bytesSHA256: InvestigationHandoffSHA256
}

struct InvestigationFixedGateDarwinCoordinatorObservation: Equatable, Sendable {
    let processID: pid_t
    let processGroupID: pid_t
    let sessionID: pid_t
    let terminal: InvestigationMachineGateTerminalObservation

    init(
        processID: pid_t, processGroupID: pid_t, sessionID: pid_t? = nil,
        terminal: InvestigationMachineGateTerminalObservation
    ) {
        self.processID = processID
        self.processGroupID = processGroupID
        self.sessionID = sessionID ?? processID
        self.terminal = terminal
    }
}

struct InvestigationFixedGateDarwinDescriptorPair: Equatable, Sendable {
    let read, write: Int32
}

enum InvestigationFixedGateDarwinFileAction: Equatable, Sendable {
    case duplicate(source: Int32, destination: Int32)
    case inherit(Int32)
    case close(Int32)
}

struct InvestigationFixedGateDarwinSpawnRequest: Equatable, Sendable {
    let executablePath: String
    let arguments: [String]
    let environment: [String]
    let processGroupID: pid_t
    let flags: Int16
    let fileActions: [InvestigationFixedGateDarwinFileAction]
    let signalMask: [Int32]
    let signalDefaults: [Int32]
}

enum InvestigationFixedGateDarwinSpawnOutcome: Equatable, Sendable {
    case definitelyNotSpawned
    case spawned(processID: pid_t, processGroupID: pid_t)
    case spawnOrTransferUncertain(processID: pid_t, processGroupID: pid_t)
}

struct InvestigationFixedGateDarwinFrameObservation: Equatable, Sendable {
    let bytes: Data
    let reachedEOF: Bool
    let overflowObserved: Bool
}

struct InvestigationFixedGateDarwinWaitObservation: Equatable, Sendable {
    let processID: pid_t
    let classification: InvestigationMachineGateWaitClassification
    let waitableWithoutReap: Bool
}

struct InvestigationFixedGateDarwinTopologyObservation: Equatable, Sendable {
    let gateProcessID, parentProcessID, gateProcessGroupID, gateSessionID: pid_t
    let gateStartSeconds, gateStartMicroseconds: UInt64
    let coordinatorProcessGroupID: pid_t
}

struct InvestigationFixedGateDarwinInventoryObservation: Equatable, Sendable {
    let processIDs: [pid_t]
    let complete: Bool
}

enum InvestigationFixedGateDarwinLifecycleOperation: Equatable, Sendable {
    case observeCoordinator
    case makeAbsoluteDeadline(durationNanoseconds: UInt64)
    case acquireSiblingExecutable(name: String, maximumByteCount: Int)
    case makeTransportPipe
    case revalidateGateExecutable(descriptor: Int32)
    case spawnGate(InvestigationFixedGateDarwinSpawnRequest)
    case closeDescriptor(Int32)
    case readPrepared(descriptor: Int32, maximumByteCount: Int, deadline: UInt64)
    case waitPreparedStop(processID: pid_t, deadline: UInt64)
    case observeGateTopology
    case observeTTY
    case consumeForwardedSignal(deadline: UInt64)
    case signalProcess(processID: pid_t, signal: Int32)
    case readTerminal(descriptor: Int32, maximumByteCount: Int, deadline: UInt64)
    case waitID(processID: pid_t, options: Int32, deadline: UInt64)
    case restoreForeground(processGroupID: pid_t)
    case inventoryProcessGroup(processGroupID: pid_t, maximumCount: Int, deadline: UInt64)
    case signalProcessGroup(processGroupID: pid_t, signal: Int32)
    case waitPID(processID: pid_t, options: Int32, deadline: UInt64)
}

enum InvestigationFixedGateDarwinLifecycleResponse: Equatable, Sendable {
    case coordinator(InvestigationFixedGateDarwinCoordinatorObservation)
    case absoluteDeadline(UInt64)
    case gateExecutable(InvestigationFixedGateDarwinExecutableObservation)
    case descriptorPair(InvestigationFixedGateDarwinDescriptorPair)
    case spawn(InvestigationFixedGateDarwinSpawnOutcome)
    case frame(InvestigationFixedGateDarwinFrameObservation)
    case gateTerminated(InvestigationFixedGateDarwinWaitObservation)
    case wait(InvestigationFixedGateDarwinWaitObservation)
    case topology(InvestigationFixedGateDarwinTopologyObservation)
    case terminal(InvestigationMachineGateTerminalObservation)
    case inventory(InvestigationFixedGateDarwinInventoryObservation)
    case signal(Int32?)
    case completed
}

protocol InvestigationFixedGateDarwinLifecycleSystem: AnyObject, Sendable {
    func perform(
        _ operation: InvestigationFixedGateDarwinLifecycleOperation
    ) throws -> InvestigationFixedGateDarwinLifecycleResponse
}

struct InvestigationFixedGateDarwinLifecycleInput: Sendable {
    let capsuleDescriptor: Int32
    let outerAttemptUUID: UUID
    let capsuleIdentity: InvestigationOwnerOnlyCapsuleNodeIdentity
    let capsuleDigest: InvestigationHandoffSHA256
}

enum InvestigationFixedGateDarwinLifecycleDisposition: Equatable, Sendable {
    case definitelyNotSpawned
    case exactGateReaped
    case spawnOrTransferUncertain
}

struct InvestigationFixedGateDarwinLifecycleReplay: Sendable {
    let gateProcessID: pid_t
    let gateProcessGroupID: pid_t
    let executableSHA256: InvestigationHandoffSHA256
    let prepared: InvestigationFixedGateDarwinFrameObservation?
    let preparedStop: InvestigationMachineGateWaitClassification?
    let terminal: InvestigationFixedGateDarwinFrameObservation?
    let terminalWait: InvestigationMachineGateWaitClassification?
    let preparedReadTermination: InvestigationMachineGateWaitClassification?
    let terminalReadTermination: InvestigationMachineGateWaitClassification?
    let coordinatorForwardedSignal: Int32?
    let exactGateReaped: Bool
    let processGroupEmpty: Bool
    let transportCloseCertain: Bool

    func requiredFrame(
        _ value: InvestigationFixedGateDarwinFrameObservation?,
        observedTermination: InvestigationMachineGateWaitClassification?
    ) throws -> InvestigationFixedGateDarwinFrameObservation {
        if let value { return value }
        if let observedTermination, isTerminal(observedTermination) {
            throw InvestigationFixedGateHandoffSystemError
                .gateTerminated(observedTermination)
        }
        throw InvestigationFixedGateHandoffSystemError.unexpectedResponse
    }

    func projectedTerminalFrame() throws
        -> InvestigationFixedGateDarwinFrameObservation
    {
        let value = try requiredFrame(
            terminal, observedTermination: terminalReadTermination
        )
        guard value.reachedEOF, !value.overflowObserved,
              value.bytes.count
                == InvestigationMachineGateTransportReceipt.encodedByteCount,
              let receipt = try? InvestigationMachineGateTransportReceipt
                .decode(value.bytes),
              (try? receipt.encoded()) == value.bytes
        else { return value }
        guard receipt.forwardedSignal == coordinatorForwardedSignal else {
            throw InvestigationFixedGateHandoffError.identityMismatch
        }
        return value
    }
}

final class InvestigationFixedGateDarwinLifecycle:
    @unchecked Sendable, InvestigationOwnerOnlyCapsuleOutcomeBorrowing {
    private static let gateName = "StornautInvestigationMachineGate"
    private static let maximumExecutableBytes = 64 << 20
    private static let cleanupReserveNanoseconds: UInt64 = 5_000_000_000
    private static let maximumProcessGroupMembers = 4_096

    private let system: any InvestigationFixedGateDarwinLifecycleSystem
    private let lock = NSLock()
    private var consumed = false
    private var storedReplay: InvestigationFixedGateDarwinLifecycleReplay?

    init(system: any InvestigationFixedGateDarwinLifecycleSystem) { self.system = system }
    var replay: InvestigationFixedGateDarwinLifecycleReplay? { lock.withLock { storedReplay } }

    func handoffToFixedGate(
        descriptor: Int32, outerAttemptUUID: UUID,
        identity: InvestigationOwnerOnlyCapsuleNodeIdentity,
        digest: InvestigationHandoffSHA256,
        settlementToken: InvestigationOwnerOnlyCapsuleSettlementToken
    ) throws -> InvestigationOwnerOnlyCapsuleBorrowingOutcome {
        switch try run(.init(
            capsuleDescriptor: descriptor,
            outerAttemptUUID: outerAttemptUUID,
            capsuleIdentity: identity, capsuleDigest: digest
        )) {
        case .definitelyNotSpawned:
            return .definitelyNotSpawned
        case .spawnOrTransferUncertain:
            return .spawnOrTransferUncertain
        case .exactGateReaped:
            return .exactGateReaped(.makeForFixedLauncher(
                outerAttemptUUID: outerAttemptUUID, digest: digest,
                identity: identity, settlementToken: settlementToken
            ))
        }
    }

    func run(
        _ input: InvestigationFixedGateDarwinLifecycleInput
    ) throws -> InvestigationFixedGateDarwinLifecycleDisposition {
        guard lock.withLock({ () -> Bool in
            guard !consumed else { return false }; consumed = true; return true
        }) else { throw InvestigationFixedGateDarwinLifecycleSystemError.uncertain }

        var ledger = DescriptorLedger()
        var spawned: (pid: pid_t, group: pid_t)?
        var executable: InvestigationFixedGateDarwinExecutableObservation?
        var prepared: InvestigationFixedGateDarwinFrameObservation?
        var preparedStop: InvestigationMachineGateWaitClassification?
        var terminal: InvestigationFixedGateDarwinFrameObservation?
        var terminalWait: InvestigationFixedGateDarwinWaitObservation?
        var preparedReadTermination: InvestigationMachineGateWaitClassification?
        var terminalReadTermination: InvestigationMachineGateWaitClassification?
        var coordinatorForwardedSignal: Int32?
        var physicalUncertain = false
        var forceTermination = false
        var spawnAttempted = false
        var groupAuthority = false
        var groupEmpty = false
        var exactReaped = false
        var postSpawnTopology: InvestigationFixedGateDarwinTopologyObservation?

        var coordinator: InvestigationFixedGateDarwinCoordinatorObservation?
        var absoluteDeadline: UInt64 = 0
        var operationDeadline: UInt64 = 0
        do {
            let initialCoordinator = try responseCoordinator(
                system.perform(.observeCoordinator))
            coordinator = initialCoordinator
            guard initialCoordinator.processID > 1,
                  initialCoordinator.processGroupID == initialCoordinator.processID,
                  initialCoordinator.sessionID == initialCoordinator.processID,
                  initialCoordinator.terminal.foregroundProcessGroupID
                    == initialCoordinator.processGroupID
            else { throw InvestigationFixedGateDarwinLifecycleSystemError.uncertain }
            absoluteDeadline = try responseDeadline(system.perform(
                .makeAbsoluteDeadline(durationNanoseconds:
                    InvestigationMachineFixedGateContract.deadlineNanoseconds)
            ))
            guard absoluteDeadline > Self.cleanupReserveNanoseconds else {
                throw InvestigationFixedGateDarwinLifecycleSystemError.uncertain
            }
            operationDeadline = absoluteDeadline - Self.cleanupReserveNanoseconds
            let acquired = try responseExecutable(system.perform(
                .acquireSiblingExecutable(
                    name: Self.gateName,
                    maximumByteCount: Self.maximumExecutableBytes)
            ))
            guard validateExecutable(acquired) else {
                ledger.register(acquired.descriptor)
                return finishBeforeSpawn(ledger: &ledger)
            }
            executable = acquired
            ledger.register(acquired.descriptor)
            let pair = try responsePair(system.perform(.makeTransportPipe))
            ledger.register(pair.read); ledger.register(pair.write)
            guard pair.read >= 3, pair.write >= 3, pair.read != pair.write else {
                return finishBeforeSpawn(ledger: &ledger)
            }
            let beforeSpawn = try responseExecutable(system.perform(
                .revalidateGateExecutable(descriptor: acquired.descriptor)
            ))
            guard beforeSpawn == acquired, validateExecutable(beforeSpawn) else {
                return finishBeforeSpawn(ledger: &ledger)
            }

            let blocked = InvestigationMachineFixedGateContract.forwardedSignals
                + [SIGTTIN, SIGTTOU, SIGTSTP]
            let request = InvestigationFixedGateDarwinSpawnRequest(
                executablePath: acquired.path, arguments: [acquired.path],
                environment: [], processGroupID: 0,
                flags: Int16(POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETPGROUP
                    | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF),
                fileActions: [
                    .duplicate(source: input.capsuleDescriptor, destination: STDIN_FILENO),
                    .duplicate(source: pair.write, destination: STDOUT_FILENO),
                    .inherit(STDERR_FILENO), .close(pair.read), .close(pair.write),
                ],
                signalMask: blocked, signalDefaults: blocked + [SIGPIPE]
            )
            spawnAttempted = true
            switch try responseSpawn(system.perform(.spawnGate(request))) {
            case .definitelyNotSpawned:
                return finishBeforeSpawn(ledger: &ledger)
            case .spawnOrTransferUncertain(let pid, let group):
                spawned = (pid, group); physicalUncertain = true; forceTermination = true
            case .spawned(let pid, let group): spawned = (pid, group)
            }
            guard let spawned else { throw ContinueCleanup() }
            let safeSpawnIdentity = spawned.pid > 1 && spawned.group == spawned.pid
                && spawned.group != initialCoordinator.processGroupID
            if !safeSpawnIdentity {
                physicalUncertain = true
                forceTermination = true
            } else {
                do {
                    let topology = try responseTopology(
                        system.perform(.observeGateTopology))
                    postSpawnTopology = topology
                    groupAuthority = validatePostSpawnTopology(
                        topology, spawned: spawned, coordinator: initialCoordinator)
                    if !groupAuthority { physicalUncertain = true; forceTermination = true }
                } catch {
                    physicalUncertain = true; forceTermination = true
                }
            }
            do {
                let afterSpawn = try responseExecutable(system.perform(
                    .revalidateGateExecutable(descriptor: acquired.descriptor)))
                if afterSpawn != acquired || !validateExecutable(afterSpawn) {
                    physicalUncertain = true; forceTermination = true
                }
            } catch {
                physicalUncertain = true; forceTermination = true
            }

            let executableCloseCertain = close(
                acquired.descriptor, ledger: &ledger)
            let writeCloseCertain = close(pair.write, ledger: &ledger)
            if !executableCloseCertain || !writeCloseCertain {
                physicalUncertain = true; forceTermination = true
            }
            if !forceTermination {
                prepared = try retryingEINTR {
                    try responseFrameOrTermination(system.perform(.readPrepared(
                        descriptor: pair.read,
                        maximumByteCount: InvestigationMachineGatePreparedFrame.maximumByteCount,
                        deadline: operationDeadline
                    )), terminal: &terminalWait)
                }
                preparedReadTermination = terminalWait?.classification
                guard let prepared,
                      validatePrepared(
                        prepared, input: input, spawned: spawned,
                        coordinator: initialCoordinator)
                else {
                    forceTermination = terminalWait == nil
                    throw ContinueCleanup()
                }

                let stop = try retryingEINTR {
                    try responseWait(system.perform(.waitPreparedStop(
                        processID: spawned.pid, deadline: operationDeadline)))
                }
                preparedStop = stop.classification
                if isAdmittedTerminalPin(stop, processID: spawned.pid) {
                    terminalWait = stop
                    throw ContinueCleanup()
                }
                guard stop.processID == spawned.pid, stop.waitableWithoutReap,
                      stop.classification == .stopped(signal: SIGSTOP),
                      let postSpawnTopology
                else {
                    physicalUncertain = true; forceTermination = true
                    groupAuthority = false
                    throw ContinueCleanup()
                }
                let stoppedTopology = try responseTopology(
                    system.perform(.observeGateTopology))
                guard validatePreparedStopTopology(
                    stoppedTopology, initial: postSpawnTopology,
                    spawned: spawned, coordinator: initialCoordinator)
                else {
                    physicalUncertain = true; forceTermination = true
                    groupAuthority = false
                    throw ContinueCleanup()
                }
                guard try responseTerminal(system.perform(.observeTTY))
                        == initialCoordinator.terminal
                else {
                    physicalUncertain = true; forceTermination = true
                    throw ContinueCleanup()
                }
                try requireCompleted(system.perform(.signalProcess(
                    processID: spawned.pid, signal: SIGCONT)))
                terminal = try retryingEINTR {
                    try responseFrameOrTermination(system.perform(.readTerminal(
                        descriptor: pair.read,
                        maximumByteCount:
                            InvestigationMachineGateTransportReceipt.maximumByteCount,
                        deadline: operationDeadline
                    )), terminal: &terminalWait)
                }
                terminalReadTermination = terminalWait?.classification
                if terminal?.reachedEOF != true || terminal?.overflowObserved == true {
                    forceTermination = terminalWait == nil
                }
            }
        } catch InvestigationFixedGateDarwinLifecycleSystemError
            .preSpawnCleanupUncertain
        {
            _ = closeAll(&ledger)
            return .spawnOrTransferUncertain
        } catch is ContinueCleanup {
            // Semantic rejection still preserves any independently exact reap proof.
        } catch {
            guard spawned != nil else {
                let closeCertain = closeAll(&ledger)
                if spawnAttempted {
                    storeReplay(makeReplay(
                        spawned: nil, executable: executable, prepared: prepared,
                        preparedStop: preparedStop, terminal: terminal,
                        terminalWait: terminalWait, exactReaped: false,
                        groupEmpty: false, closeCertain: closeCertain))
                    return .spawnOrTransferUncertain
                }
                return closeCertain ? .definitelyNotSpawned
                    : .spawnOrTransferUncertain
            }
            physicalUncertain = true; forceTermination = true
        }

        guard let spawned, let coordinator else {
            let closeCertain = closeAll(&ledger)
            storeReplay(makeReplay(
                spawned: spawned, executable: executable, prepared: prepared,
                preparedStop: preparedStop, terminal: terminal,
                terminalWait: terminalWait, exactReaped: false,
                groupEmpty: false, closeCertain: closeCertain))
            return .spawnOrTransferUncertain
        }

        if let observed = terminalWait,
           !isAdmittedTerminalPin(observed, processID: spawned.pid) {
            physicalUncertain = true
            terminalWait = nil; forceTermination = true
        }
        if terminalWait == nil && !forceTermination {
            do {
                let observed = try observeTerminalPin(
                    processID: spawned.pid, deadline: operationDeadline)
                terminalWait = observed
            } catch {
                physicalUncertain = true
                forceTermination = true
            }
        }
        if terminalWait == nil && forceTermination {
            if spawned.pid > 1 {
                do {
                    try requireCompleted(system.perform(.signalProcess(
                        processID: spawned.pid, signal: SIGKILL)))
                } catch { physicalUncertain = true }
                do {
                    try requireCompleted(system.perform(.signalProcess(
                        processID: spawned.pid, signal: SIGCONT)))
                } catch { physicalUncertain = true }
                do {
                    terminalWait = try observeTerminalPin(
                        processID: spawned.pid, deadline: absoluteDeadline)
                } catch { physicalUncertain = true }
            } else {
                physicalUncertain = true
            }
        }
        if terminalWait == nil { physicalUncertain = true }

        if terminalWait != nil { do {
            if let signal = try responseSignal(system.perform(
                .consumeForwardedSignal(deadline: absoluteDeadline)))
            {
                guard InvestigationMachineFixedGateContract.forwardedSignals
                    .contains(signal)
                else { throw InvestigationFixedGateDarwinLifecycleSystemError.uncertain }
                coordinatorForwardedSignal = signal
                // The gate is the sole forwarder. Consumption records semantic
                // interruption but does not weaken an exact physical reap.
            }
        } catch { physicalUncertain = true } }

        do {
            try requireCompleted(system.perform(
                .restoreForeground(processGroupID: coordinator.processGroupID)))
            guard try responseTerminal(system.perform(.observeTTY))
                    == coordinator.terminal else { throw ContinueCleanup() }
        } catch { physicalUncertain = true }

        var beforeReapValid = false
        if terminalWait != nil && groupAuthority {
            do {
                beforeReapValid = try drainRecoveryGroup(
                    spawned: spawned, deadline: absoluteDeadline)
            } catch { physicalUncertain = true }
        } else if terminalWait != nil {
            // A pinned direct child can still be reaped safely, but without a
            // joined topology snapshot we have no authority over its PGID.
            beforeReapValid = true
            physicalUncertain = true
        } else { physicalUncertain = true }

        if beforeReapValid, let terminalWait {
            do {
                let reaped = try retryingEINTR {
                    try responseWait(system.perform(.waitPID(
                        processID: spawned.pid, options: Int32(WNOHANG),
                        deadline: absoluteDeadline)))
                }
                exactReaped = reaped.processID == spawned.pid
                    && isTerminal(reaped.classification)
                    && !reaped.waitableWithoutReap
                    && terminalWait.classification == reaped.classification
                if !exactReaped { physicalUncertain = true }
            } catch { physicalUncertain = true }
        }
        if exactReaped && groupAuthority { do {
            let post = try responseInventory(system.perform(
                .inventoryProcessGroup(
                    processGroupID: spawned.group,
                    maximumCount: Self.maximumProcessGroupMembers,
                    deadline: absoluteDeadline)))
            try validateInventory(post)
            groupEmpty = post.processIDs.isEmpty
            if !groupEmpty { physicalUncertain = true }
        } catch { physicalUncertain = true } }
        do {
            guard try responseTerminal(system.perform(.observeTTY))
                    == coordinator.terminal else { throw ContinueCleanup() }
        } catch { physicalUncertain = true }

        let closeCertain = closeAll(&ledger)
        if !closeCertain { physicalUncertain = true }
        storeReplay(makeReplay(
            spawned: spawned, executable: executable, prepared: prepared,
            preparedStop: preparedStop, terminal: terminal,
            terminalWait: terminalWait,
            preparedReadTermination: preparedReadTermination,
            terminalReadTermination: terminalReadTermination,
            coordinatorForwardedSignal: coordinatorForwardedSignal,
            exactReaped: exactReaped,
            groupEmpty: groupEmpty, closeCertain: closeCertain
        ))
        return !physicalUncertain && exactReaped && groupEmpty && closeCertain
            ? .exactGateReaped : .spawnOrTransferUncertain
    }

    private func observeTerminalPin(processID: pid_t, deadline: UInt64) throws
        -> InvestigationFixedGateDarwinWaitObservation
    {
        let value = try retryingEINTR {
            try responseWait(system.perform(.waitID(
                processID: processID,
                options: Int32(WEXITED | WNOHANG | WNOWAIT),
                deadline: deadline)))
        }
        guard isAdmittedTerminalPin(value, processID: processID) else {
            throw InvestigationFixedGateDarwinLifecycleSystemError.uncertain
        }
        return value
    }

    private func drainRecoveryGroup(
        spawned: (pid: pid_t, group: pid_t), deadline: UInt64
    ) throws -> Bool {
        func observe() throws -> Set<pid_t> {
            let value = try responseInventory(system.perform(
                .inventoryProcessGroup(
                    processGroupID: spawned.group,
                    maximumCount: Self.maximumProcessGroupMembers,
                    deadline: deadline)))
            try validateInventory(value)
            return Set(value.processIDs)
        }
        var current = try observe()
        let admitted = current
        let gateOnly = Set([spawned.pid])
        if !current.subtracting(gateOnly).isEmpty {
            try requireCompleted(system.perform(.signalProcessGroup(
                processGroupID: spawned.group, signal: SIGTERM)))
            try requireCompleted(system.perform(.signalProcessGroup(
                processGroupID: spawned.group, signal: SIGCONT)))
            current = try observe()
            guard current.isSubset(of: admitted) else { throw ContinueCleanup() }
            if !current.subtracting(gateOnly).isEmpty {
                try requireCompleted(system.perform(.signalProcessGroup(
                    processGroupID: spawned.group, signal: SIGKILL)))
            }
        }
        while true {
            guard current.isSubset(of: admitted) else { throw ContinueCleanup() }
            if current.subtracting(gateOnly).isEmpty {
                let stable = try observe()
                guard stable.isSubset(of: admitted) else { throw ContinueCleanup() }
                if stable.subtracting(gateOnly).isEmpty { return true }
                current = stable
            } else { current = try observe() }
        }
    }

    private func validatePostSpawnTopology(
        _ value: InvestigationFixedGateDarwinTopologyObservation,
        spawned: (pid: pid_t, group: pid_t),
        coordinator: InvestigationFixedGateDarwinCoordinatorObservation
    ) -> Bool {
        value.gateProcessID == spawned.pid
            && value.parentProcessID == coordinator.processID
            && value.gateProcessGroupID == spawned.group
            && value.gateSessionID == coordinator.sessionID
            && (value.gateStartSeconds > 0 || value.gateStartMicroseconds > 0)
            && value.gateStartMicroseconds < 1_000_000
            && value.coordinatorProcessGroupID == coordinator.processGroupID
    }

    private func validatePreparedStopTopology(
        _ value: InvestigationFixedGateDarwinTopologyObservation,
        initial: InvestigationFixedGateDarwinTopologyObservation,
        spawned: (pid: pid_t, group: pid_t),
        coordinator: InvestigationFixedGateDarwinCoordinatorObservation
    ) -> Bool {
        validatePostSpawnTopology(initial, spawned: spawned, coordinator: coordinator)
            && value.gateProcessID == initial.gateProcessID
            && value.parentProcessID == initial.parentProcessID
            && value.gateProcessGroupID == coordinator.processGroupID
            && value.gateSessionID == initial.gateSessionID
            && value.gateStartSeconds == initial.gateStartSeconds
            && value.gateStartMicroseconds == initial.gateStartMicroseconds
            && value.coordinatorProcessGroupID == initial.coordinatorProcessGroupID
    }

    private func finishBeforeSpawn(
        ledger: inout DescriptorLedger
    ) -> InvestigationFixedGateDarwinLifecycleDisposition {
        closeAll(&ledger) ? .definitelyNotSpawned : .spawnOrTransferUncertain
    }

    private func validateExecutable(
        _ value: InvestigationFixedGateDarwinExecutableObservation
    ) -> Bool {
        value.descriptor >= 3 && value.path.hasSuffix("/" + Self.gateName)
            && value.descriptorIdentity == value.namedIdentity
            && value.descriptorIdentity.device > 0
            && value.descriptorIdentity.inode > 0
            && (1...Int64(Self.maximumExecutableBytes))
                .contains(value.descriptorIdentity.size)
            && value.ownerUserID == getuid() && value.ownerGroupID == getgid()
            && value.permissions == 0o755 && value.linkCount == 1
            && value.flags == 0 && value.extendedACLIsEmpty
            && Set(value.extendedAttributeNames).count
                == value.extendedAttributeNames.count
            && value.extendedAttributeNames.allSatisfy {
                $0 == "com.apple.provenance"
            }
            && value.sha256 == value.bytesSHA256
            && value.sha256.rawBytes.contains(where: { $0 != 0 })
    }

    private func validatePrepared(
        _ value: InvestigationFixedGateDarwinFrameObservation,
        input: InvestigationFixedGateDarwinLifecycleInput,
        spawned: (pid: pid_t, group: pid_t),
        coordinator: InvestigationFixedGateDarwinCoordinatorObservation
    ) -> Bool {
        guard !value.reachedEOF, !value.overflowObserved,
              value.bytes.count == InvestigationMachineGatePreparedFrame.encodedByteCount,
              let frame = try? InvestigationMachineGatePreparedFrame.decode(value.bytes),
              (try? frame.encoded()) == value.bytes
        else { return false }
        return frame.gateProcessID == spawned.pid
            && frame.recoveryProcessGroupID == spawned.group
            && frame.coordinatorProcessID == coordinator.processID
            && frame.sessionID == coordinator.sessionID
            && frame.savedForegroundProcessGroupID == coordinator.processGroupID
            && frame.outerAttemptUUID == input.outerAttemptUUID
            && frame.wholeInputSHA256 == input.capsuleDigest
            && frame.capsule == .init(
                device: input.capsuleIdentity.device,
                inode: input.capsuleIdentity.inode,
                generation: input.capsuleIdentity.generation,
                size: input.capsuleIdentity.size)
            && frame.terminal == coordinator.terminal
    }

    private func validateInventory(
        _ value: InvestigationFixedGateDarwinInventoryObservation
    ) throws {
        guard value.complete, value.processIDs.count <= Self.maximumProcessGroupMembers,
              value.processIDs.allSatisfy({ $0 > 1 }),
              Set(value.processIDs).count == value.processIDs.count
        else { throw InvestigationFixedGateDarwinLifecycleSystemError.uncertain }
    }

    private func close(_ descriptor: Int32, ledger: inout DescriptorLedger) -> Bool {
        guard ledger.take(descriptor) else { return true }
        do { try requireCompleted(system.perform(.closeDescriptor(descriptor))); return true }
        catch { return false }
    }

    private func closeAll(_ ledger: inout DescriptorLedger) -> Bool {
        ledger.remaining.reduce(true) { certain, descriptor in
            close(descriptor, ledger: &ledger) && certain
        }
    }

    private func storeReplay(_ value: InvestigationFixedGateDarwinLifecycleReplay) {
        lock.withLock { storedReplay = value }
    }

    private func makeReplay(
        spawned: (pid: pid_t, group: pid_t)?,
        executable: InvestigationFixedGateDarwinExecutableObservation?,
        prepared: InvestigationFixedGateDarwinFrameObservation?,
        preparedStop: InvestigationMachineGateWaitClassification?,
        terminal: InvestigationFixedGateDarwinFrameObservation?,
        terminalWait: InvestigationFixedGateDarwinWaitObservation?,
        preparedReadTermination: InvestigationMachineGateWaitClassification? = nil,
        terminalReadTermination: InvestigationMachineGateWaitClassification? = nil,
        coordinatorForwardedSignal: Int32? = nil,
        exactReaped: Bool, groupEmpty: Bool, closeCertain: Bool
    ) -> InvestigationFixedGateDarwinLifecycleReplay {
        .init(
            gateProcessID: spawned?.pid ?? 0,
            gateProcessGroupID: spawned?.group ?? 0,
            executableSHA256: executable?.sha256 ?? .hashing(Data()),
            prepared: prepared, preparedStop: preparedStop, terminal: terminal,
            terminalWait: terminalWait?.classification,
            preparedReadTermination: preparedReadTermination,
            terminalReadTermination: terminalReadTermination,
            coordinatorForwardedSignal: coordinatorForwardedSignal,
            exactGateReaped: exactReaped,
            processGroupEmpty: groupEmpty, transportCloseCertain: closeCertain)
    }
}

private struct ContinueCleanup: Error {}

private struct DescriptorLedger {
    private var descriptors: [Int32] = []
    mutating func register(_ descriptor: Int32) {
        if descriptor >= 0 && !descriptors.contains(descriptor) { descriptors.append(descriptor) }
    }
    mutating func take(_ descriptor: Int32) -> Bool {
        guard let index = descriptors.firstIndex(of: descriptor) else { return false }
        descriptors.remove(at: index); return true
    }
    var remaining: [Int32] { descriptors }
}

private func retryingEINTR<Value>(_ body: () throws -> Value) throws -> Value {
    while true {
        do { return try body() }
        catch InvestigationFixedGateDarwinLifecycleSystemError.errno(let value)
            where value == EINTR { continue }
    }
}

private func isTerminal(_ value: InvestigationMachineGateWaitClassification) -> Bool {
    switch value { case .exited, .signaled: true; case .stopped: false }
}

private func responseCoordinator(_ value: InvestigationFixedGateDarwinLifecycleResponse) throws -> InvestigationFixedGateDarwinCoordinatorObservation
{ guard case .coordinator(let result) = value else { throw InvestigationFixedGateDarwinLifecycleSystemError.uncertain }; return result }
private func responseDeadline(_ value: InvestigationFixedGateDarwinLifecycleResponse) throws -> UInt64
{ guard case .absoluteDeadline(let result) = value else { throw InvestigationFixedGateDarwinLifecycleSystemError.uncertain }; return result }
private func responseExecutable(_ value: InvestigationFixedGateDarwinLifecycleResponse) throws -> InvestigationFixedGateDarwinExecutableObservation
{ guard case .gateExecutable(let result) = value else { throw InvestigationFixedGateDarwinLifecycleSystemError.uncertain }; return result }
private func responsePair(_ value: InvestigationFixedGateDarwinLifecycleResponse) throws -> InvestigationFixedGateDarwinDescriptorPair
{ guard case .descriptorPair(let result) = value else { throw InvestigationFixedGateDarwinLifecycleSystemError.uncertain }; return result }
private func responseSpawn(_ value: InvestigationFixedGateDarwinLifecycleResponse) throws -> InvestigationFixedGateDarwinSpawnOutcome
{ guard case .spawn(let result) = value else { throw InvestigationFixedGateDarwinLifecycleSystemError.uncertain }; return result }
private func responseFrameOrTermination(
    _ value: InvestigationFixedGateDarwinLifecycleResponse,
    terminal: inout InvestigationFixedGateDarwinWaitObservation?
) throws -> InvestigationFixedGateDarwinFrameObservation? {
    switch value {
    case .frame(let result): return result
    case .gateTerminated(let result): terminal = result; return nil
    default: throw InvestigationFixedGateDarwinLifecycleSystemError.uncertain
    }
}
private func responseWait(_ value: InvestigationFixedGateDarwinLifecycleResponse) throws -> InvestigationFixedGateDarwinWaitObservation
{ guard case .wait(let result) = value else { throw InvestigationFixedGateDarwinLifecycleSystemError.uncertain }; return result }
private func responseTopology(_ value: InvestigationFixedGateDarwinLifecycleResponse) throws -> InvestigationFixedGateDarwinTopologyObservation
{ guard case .topology(let result) = value else { throw InvestigationFixedGateDarwinLifecycleSystemError.uncertain }; return result }
private func responseTerminal(_ value: InvestigationFixedGateDarwinLifecycleResponse) throws -> InvestigationMachineGateTerminalObservation
{ guard case .terminal(let result) = value else { throw InvestigationFixedGateDarwinLifecycleSystemError.uncertain }; return result }
private func responseInventory(_ value: InvestigationFixedGateDarwinLifecycleResponse) throws -> InvestigationFixedGateDarwinInventoryObservation
{ guard case .inventory(let result) = value else { throw InvestigationFixedGateDarwinLifecycleSystemError.uncertain }; return result }
private func responseSignal(_ value: InvestigationFixedGateDarwinLifecycleResponse) throws -> Int32?
{ guard case .signal(let result) = value else { throw InvestigationFixedGateDarwinLifecycleSystemError.uncertain }; return result }
private func requireCompleted(_ value: InvestigationFixedGateDarwinLifecycleResponse) throws
{ guard case .completed = value else { throw InvestigationFixedGateDarwinLifecycleSystemError.uncertain } }
private func isAdmittedTerminalPin(
    _ value: InvestigationFixedGateDarwinWaitObservation, processID: pid_t
) -> Bool {
    value.processID == processID && value.waitableWithoutReap
        && isTerminal(value.classification)
}
#endif
