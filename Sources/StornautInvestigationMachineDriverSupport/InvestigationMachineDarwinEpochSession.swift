import CInvestigationIdentitySupport
import Darwin
import Dispatch
import Foundation
import StornautInvestigationHandoffContract
import StornautInvestigationInstalledL2

enum InvestigationMachineDarwinEpochSessionError:
    Error, Sendable, Equatable
{
    case alreadyConsumed
    case invalidState
    case transportUnavailable
    case spawnFailed
    case processGroupInvalid
    case identityInvalid
    case deadlineExceeded
    case retirementUncertain
}

struct InvestigationMachineDarwinEpochChannel: Sendable, Equatable {
    var parentDescriptor: Int32
    var childDescriptor: Int32
}

struct InvestigationMachineDarwinEpochSpawnRequest: Sendable, Equatable {
    let executablePath: String
    let arguments: [String]
    let environment: [String]
    let parentDescriptor: Int32
    let childDescriptor: Int32
    let childTargetDescriptor: Int32
    let flags: Int16
}

struct InvestigationMachineDarwinOwnedEpoch: Sendable, Equatable {
    let processID: Int32
    let processGroupID: Int32
    let descriptors: [Int32]
}

struct InvestigationMachineDarwinSpawnedEpoch: Sendable, Equatable {
    let processID: Int32
    let descriptors: [Int32]
}

enum InvestigationMachineDarwinEpochTopologyPolicy: Sendable, Equatable {
    case appOwnedProcessGroup
    case inheritedInnerProcessGroup
}

private enum InvestigationMachineDarwinEpochRetirementAuthority:
    Sendable, Equatable
{
    case ownedProcessGroup(InvestigationMachineDarwinOwnedEpoch)
    case directChild(InvestigationMachineDarwinSpawnedEpoch)

    var processID: Int32 {
        switch self {
        case .ownedProcessGroup(let epoch): epoch.processID
        case .directChild(let epoch): epoch.processID
        }
    }

    var descriptors: [Int32] {
        switch self {
        case .ownedProcessGroup(let epoch): epoch.descriptors
        case .directChild(let epoch): epoch.descriptors
        }
    }
}

protocol InvestigationMachineDarwinEpochRetirementOwning: Sendable {
    func retireSpawnedProcess(
        _ spawnedEpoch: InvestigationMachineDarwinSpawnedEpoch
    ) async throws

    func retireOwnedProcessGroup(
        _ ownedEpoch: InvestigationMachineDarwinOwnedEpoch
    ) async throws -> InvestigationMachineSingleEpochRetirementProof

    func reapSuccessfulDirectChild(
        _ spawnedEpoch: InvestigationMachineDarwinSpawnedEpoch
    ) async throws -> InvestigationMachineSingleEpochRetirementProof
}

extension InvestigationMachineDarwinEpochRetirementOwning {
    func reapSuccessfulDirectChild(
        _ spawnedEpoch: InvestigationMachineDarwinSpawnedEpoch
    ) async throws -> InvestigationMachineSingleEpochRetirementProof {
        throw InvestigationMachineDarwinEpochSessionError.retirementUncertain
    }
}

struct InvestigationMachineDarwinEpochPreparedAppIdentity: Sendable
{
    typealias Observe = @Sendable (
        InvestigationHandoffProcessClaim,
        InvestigationHandoffDropEvidence,
        InvestigationInstalledL2IdentityProjection
    ) throws -> InvestigationMachineSingleEpochAppObservation

    private let observeOperation: Observe

    init(observe: @escaping Observe) {
        observeOperation = observe
    }

    func observe(
        processClaim: InvestigationHandoffProcessClaim,
        dropEvidence: InvestigationHandoffDropEvidence,
        projection: InvestigationInstalledL2IdentityProjection
    ) throws -> InvestigationMachineSingleEpochAppObservation {
        try observeOperation(processClaim, dropEvidence, projection)
    }
}

protocol InvestigationMachineDarwinAppIdentityObserving: Sendable {
    func prepareEpoch(
        processClaim: InvestigationHandoffProcessClaim,
        projection: InvestigationInstalledL2IdentityProjection,
        expectedParentProcessID: UInt32,
        expectedProcessGroupID: UInt32
    ) throws -> InvestigationMachineDarwinEpochPreparedAppIdentity
}

extension InvestigationMachineDarwinAppIdentityObserver:
    InvestigationMachineDarwinAppIdentityObserving
{
    func prepareEpoch(
        processClaim: InvestigationHandoffProcessClaim,
        projection: InvestigationInstalledL2IdentityProjection,
        expectedParentProcessID: UInt32,
        expectedProcessGroupID: UInt32
    ) throws -> InvestigationMachineDarwinEpochPreparedAppIdentity {
        let prepared = try prepare(
            processClaim: processClaim, projection: projection,
            expectedParentProcessID: expectedParentProcessID,
            expectedProcessGroupID: expectedProcessGroupID
        )
        return .init { processClaim, dropEvidence, projection in
            try observe(
                preDrop: prepared, processClaim: processClaim,
                dropEvidence: dropEvidence, projection: projection
            )
        }
    }
}

struct InvestigationMachineDarwinEpochSessionSystem: Sendable {
    let currentDriverClaim:
        @Sendable () throws -> InvestigationHandoffProcessClaim
    let socketPair:
        @Sendable () throws -> InvestigationMachineDarwinEpochChannel
    let duplicateCloseOnExec: @Sendable (Int32, Int32) throws -> Int32
    let setCloseOnExec: @Sendable (Int32) throws -> Void
    let closeDescriptor: @Sendable (Int32) throws -> Void
    let spawn: @Sendable (InvestigationMachineDarwinEpochSpawnRequest) throws
        -> Int32
    let processGroup: @Sendable (Int32) throws -> Int32
    let currentProcessGroup: @Sendable () -> Int32
    let continuousNanoseconds: @Sendable () throws -> UInt64
    let readExactly: @Sendable (Int32, Int, UInt64) async throws -> Data
    let readUpToOne: @Sendable (Int32, UInt64) async throws -> Data
    let writeExactly: @Sendable (Int32, Data, UInt64) async throws -> Void

    static let system = Self(
        currentDriverClaim: investigationMachineDarwinCurrentDriverClaim,
        socketPair: investigationMachineDarwinSocketPair,
        duplicateCloseOnExec: investigationMachineDarwinDuplicateCloseOnExec,
        setCloseOnExec: investigationMachineDarwinSetCloseOnExec,
        closeDescriptor: investigationMachineDarwinClose,
        spawn: investigationMachineDarwinSpawn,
        processGroup: investigationMachineDarwinProcessGroup,
        currentProcessGroup: Darwin.getpgrp,
        continuousNanoseconds: investigationMachineDarwinContinuousNanoseconds,
        readExactly: { descriptor, count, deadline in
            try await InvestigationMachineDarwinEpochPhysicalIO.readExactly(
                descriptor: descriptor, count: count,
                deadlineNanoseconds: deadline
            )
        },
        readUpToOne: { descriptor, deadline in
            try await InvestigationMachineDarwinEpochPhysicalIO.readUpToOne(
                descriptor: descriptor, deadlineNanoseconds: deadline
            )
        },
        writeExactly: { descriptor, data, deadline in
            try await InvestigationMachineDarwinEpochPhysicalIO.writeExactly(
                descriptor: descriptor, data: data,
                deadlineNanoseconds: deadline
            )
        }
    )
}

actor InvestigationMachineDarwinEpochSessionFactory:
    InvestigationMachineSingleEpochSessionFactory
{
    static let fixedDescriptor: Int32 = 7
    static let minimumRelocatedDescriptor: Int32 = 8
    static let spawnFlags = Int16(
        POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT
    )
    static let inheritedProcessGroupSpawnFlags = Int16(
        POSIX_SPAWN_CLOEXEC_DEFAULT
    )
    static let bootstrapWindowNanoseconds: UInt64 = 5_000_000_000

    private enum State {
        case idle, starting, started, terminalProven, terminalUncertain
    }

    private let projection: InvestigationInstalledL2IdentityProjection
    private let identityObserver: any InvestigationMachineDarwinAppIdentityObserving
    private let retirementOwner: any InvestigationMachineDarwinEpochRetirementOwning
    private let system: InvestigationMachineDarwinEpochSessionSystem
    private let topologyPolicy: InvestigationMachineDarwinEpochTopologyPolicy
    private var state = State.idle

    init(
        projection: InvestigationInstalledL2IdentityProjection,
        identityObserver: any InvestigationMachineDarwinAppIdentityObserving,
        retirementOwner: any InvestigationMachineDarwinEpochRetirementOwning,
        system: InvestigationMachineDarwinEpochSessionSystem,
        topologyPolicy: InvestigationMachineDarwinEpochTopologyPolicy =
            .appOwnedProcessGroup
    ) {
        self.projection = projection
        self.identityObserver = identityObserver
        self.retirementOwner = retirementOwner
        self.system = system
        self.topologyPolicy = topologyPolicy
    }

    func start(
        bootstrap: InvestigationHandoffEpochBootstrap
    ) async -> InvestigationMachineSingleEpochStartOutcome {
        guard state == .idle else {
            return state == .terminalProven
                ? .terminal(.init()) : .terminalUncertain
        }
        state = .starting
        guard !Task.isCancelled else {
            state = .terminalProven
            return .terminal(.init())
        }

        let driverClaim: InvestigationHandoffProcessClaim
        do {
            driverClaim = try system.currentDriverClaim()
            guard driverClaim.effectiveUserID == 0 else {
                return terminal(.terminal(.init()))
            }
        } catch {
            return terminal(.terminal(.init()))
        }

        let inheritedProcessGroup: Int32?
        if topologyPolicy == .inheritedInnerProcessGroup {
            let processGroup = system.currentProcessGroup()
            guard
                processGroup > 1,
                UInt32(exactly: processGroup) == driverClaim.processID
            else {
                return terminal(.terminal(.init()))
            }
            inheritedProcessGroup = processGroup
        } else {
            inheritedProcessGroup = nil
        }

        var channel: InvestigationMachineDarwinEpochChannel
        do {
            channel = try system.socketPair()
        } catch {
            return terminal(.terminal(.init()))
        }
        var openDescriptors = Set([
            channel.parentDescriptor, channel.childDescriptor,
        ])

        do {
            channel = try relocate(channel, openDescriptors: &openDescriptors)
            try system.setCloseOnExec(channel.parentDescriptor)
            try system.setCloseOnExec(channel.childDescriptor)
        } catch {
            return closePreSpawn(openDescriptors)
        }

        let request = InvestigationMachineDarwinEpochSpawnRequest(
            executablePath: InvestigationInstalledL2FixedPaths()
                .appExecutable.path,
            arguments: [
                InvestigationInstalledL2FixedPaths().appExecutable.path
            ],
            environment: [],
            parentDescriptor: channel.parentDescriptor,
            childDescriptor: channel.childDescriptor,
            childTargetDescriptor: Self.fixedDescriptor,
            flags: topologyPolicy == .appOwnedProcessGroup
                ? Self.spawnFlags : Self.inheritedProcessGroupSpawnFlags
        )
        let processID: Int32
        do {
            processID = try system.spawn(request)
            guard processID > 1 else {
                return closeUnknownSpawn(openDescriptors)
            }
        } catch {
            return closePreSpawn(openDescriptors)
        }

        var spawned = InvestigationMachineDarwinSpawnedEpoch(
            processID: processID,
            descriptors: openDescriptors.sorted()
        )
        let retirementAuthority:
            InvestigationMachineDarwinEpochRetirementAuthority
        let expectedProcessGroupID: UInt32
        do {
            openDescriptors.remove(channel.childDescriptor)
            spawned = .init(
                processID: processID,
                descriptors: openDescriptors.sorted()
            )
            try system.closeDescriptor(channel.childDescriptor)
            let processGroup = try system.processGroup(processID)
            switch topologyPolicy {
            case .appOwnedProcessGroup:
                let currentProcessGroup = system.currentProcessGroup()
                guard
                    processGroup == processID,
                    processGroup != currentProcessGroup,
                    let group = UInt32(exactly: processGroup)
                else {
                    return await retireUntrustedGroup(spawned)
                }
                expectedProcessGroupID = group
                retirementAuthority = .ownedProcessGroup(.init(
                    processID: processID, processGroupID: processGroup,
                    descriptors: openDescriptors.sorted()
                ))
            case .inheritedInnerProcessGroup:
                guard
                    let inheritedProcessGroup,
                    system.currentProcessGroup() == inheritedProcessGroup,
                    processGroup == inheritedProcessGroup,
                    processID != processGroup,
                    let group = UInt32(exactly: processGroup)
                else {
                    return await retireUntrustedGroup(spawned)
                }
                expectedProcessGroupID = group
                retirementAuthority = .directChild(spawned)
            }
        } catch {
            return await retireUntrustedGroup(spawned)
        }
        do {
            let bootstrapStarted = try system.continuousNanoseconds()
            let bootstrapLimit = bootstrapStarted.addingReportingOverflow(
                Self.bootstrapWindowNanoseconds
            )
            guard !bootstrapLimit.overflow else {
                return await retireStartedEpoch(retirementAuthority)
            }
            let bootstrapDeadline = min(
                bootstrap.epochDeadlineNanoseconds,
                bootstrapLimit.partialValue
            )
            try Task.checkCancellation()
            try await system.writeExactly(
                channel.parentDescriptor,
                bootstrap.encoded(),
                bootstrapDeadline
            )
            try Task.checkCancellation()
        } catch {
            return await retireStartedEpoch(retirementAuthority)
        }

        state = .started
        return .started(InvestigationMachineDarwinEpochSession(
            bootstrap: bootstrap,
            driverClaim: driverClaim,
            projection: projection,
            identityObserver: identityObserver,
            retirementOwner: retirementOwner,
            system: system,
            retirementAuthority: retirementAuthority,
            expectedParentProcessID: driverClaim.processID,
            expectedProcessGroupID: expectedProcessGroupID
        ))
    }

    private func relocate(
        _ initial: InvestigationMachineDarwinEpochChannel,
        openDescriptors: inout Set<Int32>
    ) throws -> InvestigationMachineDarwinEpochChannel {
        var channel = initial
        if Self.reserved(channel.parentDescriptor) {
            let old = channel.parentDescriptor
            let replacement = try system.duplicateCloseOnExec(
                old, Self.minimumRelocatedDescriptor
            )
            openDescriptors.insert(replacement)
            try system.closeDescriptor(old)
            openDescriptors.remove(old)
            channel.parentDescriptor = replacement
        }
        if Self.reserved(channel.childDescriptor) {
            let old = channel.childDescriptor
            let replacement = try system.duplicateCloseOnExec(
                old, Self.minimumRelocatedDescriptor
            )
            openDescriptors.insert(replacement)
            try system.closeDescriptor(old)
            openDescriptors.remove(old)
            channel.childDescriptor = replacement
        }
        guard
            channel.parentDescriptor >= 0,
            channel.childDescriptor >= 0,
            !Self.reserved(channel.parentDescriptor),
            !Self.reserved(channel.childDescriptor),
            channel.parentDescriptor != channel.childDescriptor
        else {
            throw InvestigationMachineDarwinEpochSessionError
                .transportUnavailable
        }
        return channel
    }

    private static func reserved(_ descriptor: Int32) -> Bool {
        descriptor >= STDIN_FILENO && descriptor <= STDERR_FILENO
            || descriptor == fixedDescriptor
    }

    private func closePreSpawn(
        _ descriptors: Set<Int32>
    ) -> InvestigationMachineSingleEpochStartOutcome {
        var failed = false
        for descriptor in descriptors where descriptor >= 0 {
            do { try system.closeDescriptor(descriptor) }
            catch { failed = true }
        }
        return terminal(failed ? .terminalUncertain : .terminal(.init()))
    }

    private func closeUnknownSpawn(
        _ descriptors: Set<Int32>
    ) -> InvestigationMachineSingleEpochStartOutcome {
        for descriptor in descriptors where descriptor >= 0 {
            try? system.closeDescriptor(descriptor)
        }
        return terminal(.terminalUncertain)
    }

    private func retireUntrustedGroup(
        _ spawned: InvestigationMachineDarwinSpawnedEpoch
    ) async -> InvestigationMachineSingleEpochStartOutcome {
        do {
            try await retirementOwner.retireSpawnedProcess(spawned)
        } catch {}
        return terminal(.terminalUncertain)
    }

    private func retireStartedEpoch(
        _ authority: InvestigationMachineDarwinEpochRetirementAuthority
    ) async -> InvestigationMachineSingleEpochStartOutcome {
        do {
            switch authority {
            case .ownedProcessGroup(let owned):
                _ = try await retirementOwner.retireOwnedProcessGroup(owned)
            case .directChild(let spawned):
                try await retirementOwner.retireSpawnedProcess(spawned)
            }
            return terminal(.terminal(.init()))
        } catch {
            return terminal(.terminalUncertain)
        }
    }

    private func terminal(
        _ outcome: InvestigationMachineSingleEpochStartOutcome
    ) -> InvestigationMachineSingleEpochStartOutcome {
        switch outcome {
        case .terminal: state = .terminalProven
        case .terminalUncertain: state = .terminalUncertain
        case .started: state = .started
        }
        return outcome
    }
}

actor InvestigationMachineDarwinEpochSession:
    InvestigationMachineSingleEpochSession
{
    nonisolated let driverClaim: InvestigationHandoffProcessClaim

    private enum StablePhase: Sendable, Equatable {
        case preDropReady, dropRelease, dropEvidence, firstIdentity
        case configuration, configurationAcknowledgement, hello, handle
        case acknowledgement, release, alive, peerWriteEOF
        case repeatedIdentity, exit, retirement
    }

    private enum Phase: Sendable, Equatable {
        case stable(StablePhase)
        case operation(UUID, poisoned: Bool)
        case failed
        case retiring
        case terminal
    }

    private let bootstrap: InvestigationHandoffEpochBootstrap
    private let projection: InvestigationInstalledL2IdentityProjection
    private let identityObserver: any InvestigationMachineDarwinAppIdentityObserving
    private let retirementOwner: any InvestigationMachineDarwinEpochRetirementOwning
    private let system: InvestigationMachineDarwinEpochSessionSystem
    private let retirementAuthority:
        InvestigationMachineDarwinEpochRetirementAuthority
    private let expectedParentProcessID: UInt32
    private let expectedProcessGroupID: UInt32
    private var phase: Phase = .stable(.preDropReady)
    private var preparedIdentity:
        InvestigationMachineDarwinEpochPreparedAppIdentity?
    private var postDropClaim: InvestigationHandoffProcessClaim?
    private var dropEvidence: InvestigationHandoffDropEvidence?
    private var firstIdentity: InvestigationMachineSingleEpochAppObservation?

    fileprivate init(
        bootstrap: InvestigationHandoffEpochBootstrap,
        driverClaim: InvestigationHandoffProcessClaim,
        projection: InvestigationInstalledL2IdentityProjection,
        identityObserver: any InvestigationMachineDarwinAppIdentityObserving,
        retirementOwner: any InvestigationMachineDarwinEpochRetirementOwning,
        system: InvestigationMachineDarwinEpochSessionSystem,
        retirementAuthority: InvestigationMachineDarwinEpochRetirementAuthority,
        expectedParentProcessID: UInt32,
        expectedProcessGroupID: UInt32
    ) {
        self.bootstrap = bootstrap
        self.driverClaim = driverClaim
        self.projection = projection
        self.identityObserver = identityObserver
        self.retirementOwner = retirementOwner
        self.system = system
        self.retirementAuthority = retirementAuthority
        self.expectedParentProcessID = expectedParentProcessID
        self.expectedProcessGroupID = expectedProcessGroupID
    }

    func receive() async throws -> InvestigationHandoffFrame {
        let expected: StablePhase
        switch phase {
        case .stable(.preDropReady): expected = .preDropReady
        case .stable(.dropEvidence): expected = .dropEvidence
        case .stable(.configurationAcknowledgement):
            expected = .configurationAcknowledgement
        case .stable(.hello): expected = .hello
        case .stable(.handle): expected = .handle
        case .stable(.alive): expected = .alive
        default: return try fail(.invalidState)
        }
        let ticket = try begin(expected)
        do {
            let frame = try await readFrame(expectedKind: kind(for: expected))
            try validateCommon(frame)
            switch expected {
            case .preDropReady:
                guard
                    frame.kind == .preDropReady,
                    frame.sender.processID
                        == UInt32(retirementAuthority.processID)
                else { throw InvestigationMachineDarwinEpochSessionError.identityInvalid }
                preparedIdentity = try identityObserver.prepareEpoch(
                    processClaim: frame.sender, projection: projection,
                    expectedParentProcessID: expectedParentProcessID,
                    expectedProcessGroupID: expectedProcessGroupID
                )
                try finish(ticket, next: .dropRelease)
            case .dropEvidence:
                guard
                    frame.kind == .dropEvidence,
                    let preparedIdentity,
                    case let .dropEvidence(evidence) = frame.payload
                else { throw InvestigationMachineDarwinEpochSessionError.identityInvalid }
                firstIdentity = try preparedIdentity.observe(
                    processClaim: frame.sender,
                    dropEvidence: evidence,
                    projection: projection
                )
                postDropClaim = frame.sender
                dropEvidence = evidence
                try finish(ticket, next: .firstIdentity)
            case .configurationAcknowledgement:
                try requirePostDropSender(frame)
                guard frame.kind == .configurationAcknowledgement else {
                    throw InvestigationMachineDarwinEpochSessionError.invalidState
                }
                try finish(ticket, next: .hello)
            case .hello:
                try requirePostDropSender(frame)
                guard frame.kind == .hello else {
                    throw InvestigationMachineDarwinEpochSessionError.invalidState
                }
                try finish(ticket, next: .handle)
            case .handle:
                try requirePostDropSender(frame)
                guard frame.kind == .handle else {
                    throw InvestigationMachineDarwinEpochSessionError.invalidState
                }
                try finish(ticket, next: .acknowledgement)
            case .alive:
                try requirePostDropSender(frame)
                guard frame.kind == .alive else {
                    throw InvestigationMachineDarwinEpochSessionError.invalidState
                }
                try finish(ticket, next: .peerWriteEOF)
            default:
                throw InvestigationMachineDarwinEpochSessionError.invalidState
            }
            return frame
        } catch {
            fail(ticket)
            if error is CancellationError { throw CancellationError() }
            if error is InvestigationMachineDarwinAppIdentityObservationError {
                throw InvestigationMachineSingleEpochSessionError
                    .identityMismatch
            }
            if error as? InvestigationMachineDarwinEpochSessionError
                == .identityInvalid
            {
                throw InvestigationMachineSingleEpochSessionError
                    .identityMismatch
            }
            throw normalized(error)
        }
    }

    func send(_ frame: InvestigationHandoffFrame) async throws {
        let expected: StablePhase
        let next: StablePhase
        let kind: InvestigationHandoffFrameKind
        switch phase {
        case .stable(.dropRelease):
            (expected, kind, next) = (.dropRelease, .dropRelease, .dropEvidence)
        case .stable(.configuration):
            (expected, kind, next) = (
                .configuration, .configuration, .configurationAcknowledgement
            )
        case .stable(.acknowledgement):
            (expected, kind, next) = (
                .acknowledgement, .acknowledgement, .release
            )
        case .stable(.release):
            (expected, kind, next) = (.release, .release, .alive)
        case .stable(.exit):
            (expected, kind, next) = (.exit, .exit, .retirement)
        default:
            return try fail(.invalidState)
        }
        let ticket = try begin(expected)
        do {
            guard
                frame.kind == kind,
                frame.kind.direction == .driverToApp,
                frame.epochUUID == bootstrap.epochUUID,
                frame.epochDeadlineNanoseconds
                    == bootstrap.epochDeadlineNanoseconds,
                frame.sender == driverClaim
            else {
                throw InvestigationMachineDarwinEpochSessionError.invalidState
            }
            try await system.writeExactly(
                retirementAuthority.descriptors[0],
                frame.encoded(),
                bootstrap.epochDeadlineNanoseconds
            )
            try finish(ticket, next: next)
        } catch {
            fail(ticket)
            if error is CancellationError { throw CancellationError() }
            throw normalized(error)
        }
    }

    func provePeerWriteEOF() async throws {
        let ticket = try begin(.peerWriteEOF)
        do {
            let trailing = try await system.readUpToOne(
                retirementAuthority.descriptors[0],
                bootstrap.epochDeadlineNanoseconds
            )
            guard trailing.isEmpty else {
                throw InvestigationMachineDarwinEpochSessionError.invalidState
            }
            try finish(ticket, next: .repeatedIdentity)
        } catch {
            fail(ticket)
            if error is CancellationError { throw CancellationError() }
            throw normalized(error)
        }
    }

    func observeCompletePostDropAppIdentity() async throws
        -> InvestigationMachineSingleEpochAppObservation
    {
        switch phase {
        case .stable(.firstIdentity):
            guard let firstIdentity else { return try fail(.identityInvalid) }
            phase = .stable(.configuration)
            return firstIdentity
        case .stable(.repeatedIdentity):
            guard let preparedIdentity, let postDropClaim, let dropEvidence else {
                return try fail(.identityInvalid)
            }
            do {
                let observed = try preparedIdentity.observe(
                    processClaim: postDropClaim,
                    dropEvidence: dropEvidence, projection: projection
                )
                phase = .stable(.exit)
                return observed
            } catch {
                return try fail(.identityInvalid)
            }
        default:
            return try fail(.invalidState)
        }
    }

    func retireAndReap() async throws
        -> InvestigationMachineSingleEpochRetirementProof
    {
        let expectsSuccessfulExit: Bool
        switch phase {
        case .terminal, .retiring, .operation:
            return try fail(.alreadyConsumed)
        case .stable(.retirement):
            expectsSuccessfulExit = true
            phase = .retiring
        case .stable, .failed:
            expectsSuccessfulExit = false
            phase = .retiring
        }
        do {
            let proof: InvestigationMachineSingleEpochRetirementProof
            switch retirementAuthority {
            case .ownedProcessGroup(let owned):
                proof = try await retirementOwner.retireOwnedProcessGroup(owned)
            case .directChild(let spawned):
                if expectsSuccessfulExit {
                    proof = try await retirementOwner
                        .reapSuccessfulDirectChild(spawned)
                } else {
                    try await retirementOwner.retireSpawnedProcess(spawned)
                    proof = .init()
                }
            }
            phase = .terminal
            return proof
        } catch {
            phase = .terminal
            throw InvestigationMachineDarwinEpochSessionError
                .retirementUncertain
        }
    }

    private func readFrame(
        expectedKind: InvestigationHandoffFrameKind
    ) async throws -> InvestigationHandoffFrame {
        let descriptor = retirementAuthority.descriptors[0]
        let header = try await system.readExactly(
            descriptor, InvestigationHandoffFrame.headerByteCount,
            bootstrap.epochDeadlineNanoseconds
        )
        guard header.count == InvestigationHandoffFrame.headerByteCount else {
            throw InvestigationMachineDarwinEpochSessionError.transportUnavailable
        }
        let headerFields = header.withUnsafeBytes { bytes in
            (
                bytes.loadUnaligned(as: UInt32.self).bigEndian,
                bytes.loadUnaligned(fromByteOffset: 4, as: UInt16.self)
                    .bigEndian,
                bytes.loadUnaligned(fromByteOffset: 6, as: UInt16.self)
                    .bigEndian,
                bytes.loadUnaligned(fromByteOffset: 8, as: UInt32.self)
                    .bigEndian,
                bytes.loadUnaligned(fromByteOffset: 12, as: UInt32.self)
                    .bigEndian
            )
        }
        guard
            headerFields.0 == InvestigationHandoffFrame.magic,
            headerFields.1 == InvestigationHandoffFrame.version,
            let kind = InvestigationHandoffFrameKind(rawValue: headerFields.2),
            kind == expectedKind,
            let payloadCount = Int(exactly: headerFields.3),
            kind.admitsPayloadByteCount(payloadCount),
            headerFields.4 == kind.sequence
        else {
            throw InvestigationMachineDarwinEpochSessionError.transportUnavailable
        }
        let payload = try await system.readExactly(
            descriptor, payloadCount,
            bootstrap.epochDeadlineNanoseconds
        )
        do { return try InvestigationHandoffFrame.decode(header + payload) }
        catch {
            throw InvestigationMachineDarwinEpochSessionError.transportUnavailable
        }
    }

    private func kind(
        for phase: StablePhase
    ) -> InvestigationHandoffFrameKind {
        switch phase {
        case .preDropReady: .preDropReady
        case .dropEvidence: .dropEvidence
        case .configurationAcknowledgement: .configurationAcknowledgement
        case .hello: .hello
        case .handle: .handle
        case .alive: .alive
        default: preconditionFailure("invalid receive phase")
        }
    }

    private func validateCommon(_ frame: InvestigationHandoffFrame) throws {
        guard
            frame.kind.direction == .appToDriver,
            frame.epochUUID == bootstrap.epochUUID,
            frame.epochDeadlineNanoseconds
                == bootstrap.epochDeadlineNanoseconds
        else {
            throw InvestigationMachineDarwinEpochSessionError.invalidState
        }
    }

    private func requirePostDropSender(
        _ frame: InvestigationHandoffFrame
    ) throws {
        guard let postDropClaim, frame.sender == postDropClaim else {
            throw InvestigationMachineDarwinEpochSessionError.identityInvalid
        }
    }

    private func begin(_ expected: StablePhase) throws -> UUID {
        guard phase == .stable(expected) else { return try fail(.invalidState) }
        let ticket = UUID()
        phase = .operation(ticket, poisoned: false)
        return ticket
    }

    private func finish(_ ticket: UUID, next: StablePhase) throws {
        guard case let .operation(activeTicket, poisoned) = phase,
            activeTicket == ticket
        else { return try fail(.invalidState) }
        guard !poisoned else {
            phase = .failed
            throw InvestigationMachineDarwinEpochSessionError.invalidState
        }
        phase = .stable(next)
    }

    private func fail<T>(
        _ error: InvestigationMachineDarwinEpochSessionError
    ) throws -> T {
        switch phase {
        case let .operation(ticket, _):
            phase = .operation(ticket, poisoned: true)
        case .retiring, .terminal: break
        default: phase = .failed
        }
        throw error
    }

    private func fail(_ ticket: UUID) {
        if case let .operation(activeTicket, _) = phase, activeTicket == ticket {
            phase = .failed
        }
    }

    private func normalized(_ error: any Error)
        -> InvestigationMachineDarwinEpochSessionError
    {
        return error as? InvestigationMachineDarwinEpochSessionError
            ?? .transportUnavailable
    }
}

private func investigationMachineDarwinCurrentDriverClaim() throws
    -> InvestigationHandoffProcessClaim
{
    let processID = getpid()
    guard processID > 1, geteuid() == 0 else {
        throw InvestigationMachineDarwinEpochSessionError.identityInvalid
    }
    var raw = stornaut_investigation_identity()
    guard stornaut_investigation_identity_for_pid(processID, &raw) == 0 else {
        throw InvestigationMachineDarwinEpochSessionError.identityInvalid
    }
    guard
        let observedProcessID = UInt32(exactly: raw.process_id),
        let processIDVersion = UInt32(exactly: raw.process_id_version),
        let auditSessionID = UInt32(exactly: raw.audit_session_id),
        observedProcessID == UInt32(processID),
        processIDVersion > 0,
        auditSessionID > 0,
        raw.effective_user_id == 0
    else {
        throw InvestigationMachineDarwinEpochSessionError.identityInvalid
    }
    return try InvestigationHandoffProcessClaim(
        processID: observedProcessID,
        processIDVersion: processIDVersion,
        effectiveUserID: UInt32(raw.effective_user_id),
        auditSessionID: auditSessionID
    )
}

private func investigationMachineDarwinSocketPair() throws
    -> InvestigationMachineDarwinEpochChannel
{
    var descriptors = [Int32](repeating: -1, count: 2)
    guard socketpair(AF_UNIX, SOCK_STREAM, 0, &descriptors) == 0 else {
        throw InvestigationMachineDarwinEpochSessionError.transportUnavailable
    }
    return .init(
        parentDescriptor: descriptors[0], childDescriptor: descriptors[1]
    )
}

private func investigationMachineDarwinDuplicateCloseOnExec(
    _ descriptor: Int32, _ minimum: Int32
) throws -> Int32 {
    let duplicate = fcntl(descriptor, F_DUPFD_CLOEXEC, minimum)
    guard duplicate >= minimum else {
        throw InvestigationMachineDarwinEpochSessionError.transportUnavailable
    }
    return duplicate
}

private func investigationMachineDarwinSetCloseOnExec(
    _ descriptor: Int32
) throws {
    let flags = fcntl(descriptor, F_GETFD)
    guard flags >= 0, fcntl(descriptor, F_SETFD, flags | FD_CLOEXEC) == 0 else {
        throw InvestigationMachineDarwinEpochSessionError.transportUnavailable
    }
}

private func investigationMachineDarwinClose(_ descriptor: Int32) throws {
    guard Darwin.close(descriptor) == 0 else {
        throw InvestigationMachineDarwinEpochSessionError.transportUnavailable
    }
}

private func investigationMachineDarwinProcessGroup(_ processID: Int32) throws
    -> Int32
{
    let group = getpgid(processID)
    guard group > 1 else {
        throw InvestigationMachineDarwinEpochSessionError.processGroupInvalid
    }
    return group
}

private func investigationMachineDarwinSpawn(
    _ request: InvestigationMachineDarwinEpochSpawnRequest
) throws -> Int32 {
    guard
        request.executablePath == InvestigationInstalledL2FixedPaths()
            .appExecutable.path,
        request.arguments == [request.executablePath],
        request.environment.isEmpty,
        request.childTargetDescriptor
            == InvestigationMachineDarwinEpochSessionFactory.fixedDescriptor,
        request.parentDescriptor > STDERR_FILENO,
        request.parentDescriptor
            != InvestigationMachineDarwinEpochSessionFactory.fixedDescriptor,
        request.childDescriptor > STDERR_FILENO,
        request.childDescriptor
            != InvestigationMachineDarwinEpochSessionFactory.fixedDescriptor,
        request.parentDescriptor != request.childDescriptor,
        request.flags == InvestigationMachineDarwinEpochSessionFactory.spawnFlags
            || request.flags
                == InvestigationMachineDarwinEpochSessionFactory
                    .inheritedProcessGroupSpawnFlags
    else {
        throw InvestigationMachineDarwinEpochSessionError.spawnFailed
    }
    return try InvestigationMachineDarwinEpochSpawnPrimitive.spawn(request)
}

enum InvestigationMachineDarwinEpochSpawnPrimitive {
    static func spawn(
        _ request: InvestigationMachineDarwinEpochSpawnRequest
    ) throws -> Int32 {
        guard
            request.arguments == [request.executablePath],
            request.environment.isEmpty,
            request.childTargetDescriptor
                == InvestigationMachineDarwinEpochSessionFactory.fixedDescriptor,
            request.parentDescriptor > STDERR_FILENO,
            request.parentDescriptor
                != InvestigationMachineDarwinEpochSessionFactory.fixedDescriptor,
            request.childDescriptor > STDERR_FILENO,
            request.childDescriptor
                != InvestigationMachineDarwinEpochSessionFactory.fixedDescriptor,
            request.parentDescriptor != request.childDescriptor,
            request.flags == InvestigationMachineDarwinEpochSessionFactory.spawnFlags
                || request.flags
                    == InvestigationMachineDarwinEpochSessionFactory
                        .inheritedProcessGroupSpawnFlags
        else {
            throw InvestigationMachineDarwinEpochSessionError.spawnFailed
        }
    var actions: posix_spawn_file_actions_t?
    guard posix_spawn_file_actions_init(&actions) == 0 else {
        throw InvestigationMachineDarwinEpochSessionError.spawnFailed
    }
    defer { posix_spawn_file_actions_destroy(&actions) }
    guard
        posix_spawn_file_actions_adddup2(
            &actions, request.childDescriptor, request.childTargetDescriptor
        ) == 0,
        posix_spawn_file_actions_addclose(
            &actions, request.parentDescriptor
        ) == 0,
        posix_spawn_file_actions_addclose(
            &actions, request.childDescriptor
        ) == 0
    else {
        throw InvestigationMachineDarwinEpochSessionError.spawnFailed
    }

    var attributes: posix_spawnattr_t?
    guard posix_spawnattr_init(&attributes) == 0 else {
        throw InvestigationMachineDarwinEpochSessionError.spawnFailed
    }
    defer { posix_spawnattr_destroy(&attributes) }
    guard posix_spawnattr_setflags(&attributes, request.flags) == 0 else {
        throw InvestigationMachineDarwinEpochSessionError.spawnFailed
    }
    if request.flags == InvestigationMachineDarwinEpochSessionFactory.spawnFlags {
        guard posix_spawnattr_setpgroup(&attributes, 0) == 0 else {
            throw InvestigationMachineDarwinEpochSessionError.spawnFailed
        }
    }

    var processID: pid_t = 0
    let status = try investigationMachineWithCStringArray(
        request.arguments
    ) { arguments in
        try investigationMachineWithCStringArray(
            request.environment
        ) { environment in
            request.executablePath.withCString { executable in
                posix_spawn(
                    &processID, executable, &actions, &attributes,
                    arguments, environment
                )
            }
        }
    }
    guard status == 0, processID > 1 else {
        throw InvestigationMachineDarwinEpochSessionError.spawnFailed
    }
    return processID
    }
}

private func investigationMachineWithCStringArray<Result>(
    _ strings: [String],
    body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws -> Result
) throws -> Result {
    guard strings.allSatisfy({ !$0.utf8.contains(0) }) else {
        throw InvestigationMachineDarwinEpochSessionError.spawnFailed
    }
    var storage: [UnsafeMutablePointer<CChar>?] = strings.map { strdup($0) }
    guard storage.allSatisfy({ $0 != nil }) else {
        storage.compactMap { $0 }.forEach { free($0) }
        throw InvestigationMachineDarwinEpochSessionError.spawnFailed
    }
    defer { storage.compactMap { $0 }.forEach { free($0) } }
    storage.append(nil)
    return try storage.withUnsafeMutableBufferPointer { buffer in
        try body(buffer.baseAddress!)
    }
}

enum InvestigationMachineDarwinEpochPhysicalIO {
    private static let queue = DispatchQueue(
        label: "com.eriklee.stornaut.machine-epoch-io",
        attributes: .concurrent
    )

    static func readExactly(
        descriptor: Int32, count: Int, deadlineNanoseconds: UInt64,
        clock: @escaping @Sendable () throws -> UInt64 =
            investigationMachineDarwinContinuousNanoseconds
    ) async throws -> Data {
        try await perform(descriptor: descriptor) {
            try blockingRead(
                descriptor: descriptor, count: count,
                deadlineNanoseconds: deadlineNanoseconds, allowsEOF: false,
                clock: clock
            )
        }
    }

    static func readUpToOne(
        descriptor: Int32, deadlineNanoseconds: UInt64,
        clock: @escaping @Sendable () throws -> UInt64 =
            investigationMachineDarwinContinuousNanoseconds
    ) async throws -> Data {
        try await perform(descriptor: descriptor) {
            try blockingRead(
                descriptor: descriptor, count: 1,
                deadlineNanoseconds: deadlineNanoseconds, allowsEOF: true,
                clock: clock
            )
        }
    }

    static func writeExactly(
        descriptor: Int32, data: Data, deadlineNanoseconds: UInt64,
        clock: @escaping @Sendable () throws -> UInt64 =
            investigationMachineDarwinContinuousNanoseconds
    ) async throws {
        try await perform(descriptor: descriptor) {
            try blockingWrite(
                descriptor: descriptor, data: data,
                deadlineNanoseconds: deadlineNanoseconds, clock: clock
            )
        }
    }

    private static func perform<Value: Sendable>(
        descriptor: Int32,
        operation: @escaping @Sendable () throws -> Value
    ) async throws -> Value {
        let resolution = InvestigationMachineDarwinEpochResolution<Value>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                resolution.install(continuation)
                queue.async {
                    resolution.finish(Result { try operation() })
                }
                if Task.isCancelled, resolution.requestCancellation() {
                    _ = shutdown(descriptor, SHUT_RDWR)
                }
            }
        } onCancel: {
            if resolution.requestCancellation() {
                _ = shutdown(descriptor, SHUT_RDWR)
            }
        }
    }

    private static func blockingRead(
        descriptor: Int32, count: Int, deadlineNanoseconds: UInt64,
        allowsEOF: Bool,
        clock: @escaping @Sendable () throws -> UInt64
    ) throws -> Data {
        guard count >= 0 else {
            throw InvestigationMachineDarwinEpochSessionError.transportUnavailable
        }
        if count == 0 {
            try requireBeforeDeadline(deadlineNanoseconds, clock: clock)
            return Data()
        }
        var data = Data(count: count)
        var offset = 0
        while offset < count {
            try wait(
                descriptor: descriptor, events: Int16(POLLIN | POLLHUP),
                deadlineNanoseconds: deadlineNanoseconds, clock: clock
            )
            let result = data.withUnsafeMutableBytes { bytes in
                Darwin.recv(
                    descriptor, bytes.baseAddress?.advanced(by: offset),
                    count - offset, MSG_DONTWAIT
                )
            }
            if result > 0 { offset += result; continue }
            if result == 0 {
                if allowsEOF && offset == 0 {
                    try requireBeforeDeadline(
                        deadlineNanoseconds, clock: clock
                    )
                    return Data()
                }
                throw InvestigationMachineDarwinEpochSessionError
                    .transportUnavailable
            }
            if errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK {
                continue
            }
            throw InvestigationMachineDarwinEpochSessionError.transportUnavailable
        }
        try requireBeforeDeadline(deadlineNanoseconds, clock: clock)
        return data
    }

    private static func blockingWrite(
        descriptor: Int32, data: Data, deadlineNanoseconds: UInt64,
        clock: @escaping @Sendable () throws -> UInt64
    ) throws {
        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                try wait(
                    descriptor: descriptor, events: Int16(POLLOUT | POLLHUP),
                    deadlineNanoseconds: deadlineNanoseconds, clock: clock
                )
                let result = Darwin.send(
                    descriptor, bytes.baseAddress?.advanced(by: offset),
                    bytes.count - offset, MSG_DONTWAIT | MSG_NOSIGNAL
                )
                if result > 0 { offset += result; continue }
                if result < 0,
                    errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK
                {
                    continue
                }
                throw InvestigationMachineDarwinEpochSessionError
                    .transportUnavailable
            }
        }
        try requireBeforeDeadline(deadlineNanoseconds, clock: clock)
    }

    private static func wait(
        descriptor: Int32, events: Int16, deadlineNanoseconds: UInt64,
        clock: @escaping @Sendable () throws -> UInt64
    ) throws {
        while true {
            let now = try clock()
            guard now < deadlineNanoseconds else {
                throw InvestigationMachineDarwinEpochSessionError.deadlineExceeded
            }
            let remaining = deadlineNanoseconds - now
            let milliseconds = Int32(
                min(max(1, min(remaining / 1_000_000, 50)), UInt64(Int32.max))
            )
            var value = pollfd(fd: descriptor, events: events, revents: 0)
            let result = poll(&value, 1, milliseconds)
            if result == 0 { continue }
            if result < 0 {
                if errno == EINTR { continue }
                throw InvestigationMachineDarwinEpochSessionError
                    .transportUnavailable
            }
            guard value.revents & events != 0 else {
                throw InvestigationMachineDarwinEpochSessionError
                    .transportUnavailable
            }
            try requireBeforeDeadline(deadlineNanoseconds, clock: clock)
            return
        }
    }

    private static func requireBeforeDeadline(
        _ deadlineNanoseconds: UInt64,
        clock: @escaping @Sendable () throws -> UInt64
    ) throws {
        guard try clock() < deadlineNanoseconds else {
            throw InvestigationMachineDarwinEpochSessionError.deadlineExceeded
        }
    }
}

private final class InvestigationMachineDarwinEpochResolution<Value: Sendable>:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, any Error>?
    private var pending: Result<Value, any Error>?
    private var completed = false
    private var cancellationRequested = false

    func install(_ value: CheckedContinuation<Value, any Error>) {
        let result = lock.withLock { () -> Result<Value, any Error>? in
            if completed { return pending }
            continuation = value
            return nil
        }
        if let result { value.resume(with: result) }
    }

    func finish(_ result: Result<Value, any Error>) {
        let state = lock.withLock {
            () -> (Result<Value, any Error>,
                CheckedContinuation<Value, any Error>?)? in
            guard !completed else { return nil }
            completed = true
            let final: Result<Value, any Error> = cancellationRequested
                ? .failure(CancellationError()) : result
            pending = final
            let value = continuation
            continuation = nil
            return (final, value)
        }
        if let state { state.1?.resume(with: state.0) }
    }

    @discardableResult
    func requestCancellation() -> Bool {
        lock.withLock {
            guard !completed, !cancellationRequested else { return false }
            cancellationRequested = true
            return true
        }
    }
}

private func investigationMachineDarwinContinuousNanoseconds() throws -> UInt64 {
    var timebase = mach_timebase_info_data_t()
    guard mach_timebase_info(&timebase) == KERN_SUCCESS, timebase.denom > 0 else {
        throw InvestigationMachineDarwinEpochSessionError.deadlineExceeded
    }
    let product = mach_continuous_time()
        .multipliedFullWidth(by: UInt64(timebase.numer))
    guard product.high < UInt64(timebase.denom) else {
        throw InvestigationMachineDarwinEpochSessionError.deadlineExceeded
    }
    return UInt64(timebase.denom).dividingFullWidth(product).quotient
}
