import Darwin
import Foundation
import StornautInvestigationInstalledL2

#if DEBUG
package enum InvestigationMachineDarwinOuterInnerSessionError:
    Error, Sendable, Equatable
{
    case alreadyConsumed
    case operationInFlight
    case deadlineInvalid
    case descriptorInvalid
    case spawnFailed
    case identityInvalid
    case transportUnavailable
    case retirementUncertain
}

struct InvestigationMachineDarwinOuterInnerDescriptorPair:
    Sendable, Equatable
{
    var firstDescriptor: Int32
    var secondDescriptor: Int32
}

struct InvestigationMachineDarwinOuterInnerDescriptorSet:
    Sendable, Equatable
{
    let outerControlDescriptor: Int32
    let innerControlSourceDescriptor: Int32
    let outerResultDescriptor: Int32
    let innerResultSourceDescriptor: Int32

    var allDescriptors: [Int32] {
        [
            outerControlDescriptor, innerControlSourceDescriptor,
            outerResultDescriptor, innerResultSourceDescriptor,
        ]
    }

    var outerDescriptors: [Int32] {
        [outerControlDescriptor, outerResultDescriptor]
    }

    var innerSourceDescriptors: [Int32] {
        [innerControlSourceDescriptor, innerResultSourceDescriptor]
    }
}

struct InvestigationMachineDarwinOuterInnerSpawnRequest:
    Sendable, Equatable
{
    let executablePath: String
    let arguments: [String]
    let environment: [String]
    let inheritedDescriptor: Int32
    let controlOuterDescriptor: Int32
    let controlChildSourceDescriptor: Int32
    let resultOuterDescriptor: Int32
    let resultChildSourceDescriptor: Int32
    let controlTargetDescriptor: Int32
    let resultTargetDescriptor: Int32
    let closedFixedDescriptors: [Int32]
    let flags: Int16
}

package struct InvestigationMachineDarwinStandardErrorObservation:
    Sendable, Equatable
{
    let deviceID: UInt64
    let inode: UInt64
    let mode: mode_t
    let statusFlags: Int32
    let isTTY: Bool
    let foregroundProcessGroup: Int32?
}

struct InvestigationMachineDarwinInnerRoleSystemError:
    Error, Sendable, Equatable
{
    let errno: Int32
}

struct InvestigationMachineDarwinDescriptorNodeObservation:
    Sendable, Equatable, Hashable
{
    let deviceID: UInt64
    let inode: UInt64
    let fileType: mode_t
}

struct InvestigationMachineDarwinSocketEndpointObservation:
    Sendable, Equatable
{
    let localFamily: sa_family_t
    let peerFamily: sa_family_t
}

struct InvestigationMachineDarwinInnerRoleSystem: Sendable {
    let argumentCount: @Sendable () -> Int32
    let currentProcessID: @Sendable () -> UInt32
    let parentProcessID: @Sendable () -> UInt32
    let currentProcessGroup: @Sendable () -> Int32
    let descriptorFlags: @Sendable (Int32)
        -> Result<Int32, InvestigationMachineDarwinInnerRoleSystemError>
    let descriptorStatusFlags: @Sendable (Int32)
        -> Result<Int32, InvestigationMachineDarwinInnerRoleSystemError>
    let noSigpipe: @Sendable (Int32) -> Int32
    let socketType: @Sendable (Int32)
        -> Result<Int32, InvestigationMachineDarwinInnerRoleSystemError>
    let socketEndpoints: @Sendable (Int32)
        -> Result<
            InvestigationMachineDarwinSocketEndpointObservation,
            InvestigationMachineDarwinInnerRoleSystemError
        >
    let descriptorNode: @Sendable (Int32)
        -> Result<
            InvestigationMachineDarwinDescriptorNodeObservation,
            InvestigationMachineDarwinInnerRoleSystemError
        >
    let standardErrorObservation:
        @Sendable () throws -> InvestigationMachineDarwinStandardErrorObservation

    static let system = Self(
        argumentCount: { Int32(CommandLine.argc) },
        currentProcessID: { UInt32(getpid()) },
        parentProcessID: { UInt32(getppid()) },
        currentProcessGroup: Darwin.getpgrp,
        descriptorFlags: innerRoleDescriptorFlags,
        descriptorStatusFlags: innerRoleDescriptorStatusFlags,
        noSigpipe: { fcntl($0, F_GETNOSIGPIPE) },
        socketType: innerRoleSocketType,
        socketEndpoints: innerRoleSocketEndpoints,
        descriptorNode: innerRoleDescriptorNode,
        standardErrorObservation: outerInnerStandardErrorObservation
    )
}

package struct InvestigationMachineDarwinInnerRoleObservation:
    Sendable, Equatable
{
    package let driverChildIdentity:
        InvestigationMachineDarwinDriverChildIdentity
    package let standardError: InvestigationMachineDarwinStandardErrorObservation
}

package struct InvestigationMachineDarwinInnerRoleValidator: Sendable {
    private let observer: any InvestigationMachineDarwinDriverChildObserving
    private let system: InvestigationMachineDarwinInnerRoleSystem

    package init() {
        observer = InvestigationMachineDarwinDriverChildObserver()
        system = .system
    }

    init(
        observer: any InvestigationMachineDarwinDriverChildObserving,
        system: InvestigationMachineDarwinInnerRoleSystem
    ) {
        self.observer = observer
        self.system = system
    }

    package func validate() throws
        -> InvestigationMachineDarwinInnerRoleObservation
    {
        let processID = system.currentProcessID()
        let parentProcessID = system.parentProcessID()
        let processGroupID = system.currentProcessGroup()
        guard
            system.argumentCount() == 1, processID > 1,
            parentProcessID > 1, processGroupID > 1,
            UInt32(processGroupID) == processID
        else { throw sessionInvalid() }

        let initialStandardError = try innerRoleStandardError(system)
        guard validInnerStandardError(initialStandardError) else {
            throw sessionInvalid()
        }
        for descriptor in Int32(0)...Int32(9) {
            let result = system.descriptorFlags(descriptor)
            if descriptor == STDERR_FILENO || descriptor == 8
                || descriptor == 9
            {
                guard case .success = result else { throw sessionInvalid() }
            } else {
                guard case let .failure(error) = result, error.errno == EBADF
                else { throw sessionInvalid() }
            }
        }
        guard
            try innerRoleDescriptor(system, STDERR_FILENO) & FD_CLOEXEC == 0,
            try innerRoleDescriptor(system, 8) & FD_CLOEXEC == 0,
            try innerRoleDescriptor(system, 9) & FD_CLOEXEC == 0,
            try innerRoleStatus(system, STDERR_FILENO) & O_ACCMODE
                == initialStandardError.statusFlags & O_ACCMODE,
            try innerRoleStatus(system, 8) & O_ACCMODE == O_RDWR,
            try innerRoleStatus(system, 9) & O_ACCMODE == O_WRONLY,
            try innerRoleSocket(system, 8) == SOCK_STREAM,
            try innerRoleSocketEndpoints(system, 8) == .init(
                localFamily: sa_family_t(AF_UNIX),
                peerFamily: sa_family_t(AF_UNIX)
            ),
            system.noSigpipe(8) == 1, system.noSigpipe(9) == 1
        else { throw sessionInvalid() }
        let descriptorNodes = try [
            innerRoleNode(system, STDERR_FILENO),
            innerRoleNode(system, 8),
            innerRoleNode(system, 9),
        ]
        guard
            descriptorNodes[0].deviceID == initialStandardError.deviceID,
            descriptorNodes[0].inode == initialStandardError.inode,
            descriptorNodes[0].fileType
                == initialStandardError.mode & mode_t(S_IFMT),
            descriptorNodes[1].fileType == mode_t(S_IFSOCK),
            descriptorNodes[2].fileType == mode_t(S_IFIFO),
            Set(descriptorNodes).count == descriptorNodes.count
        else { throw sessionInvalid() }

        let identity: InvestigationMachineDarwinDriverChildIdentity
        do {
            identity = try observer.observe(
                processID: processID, expectedParentProcessID: parentProcessID
            )
        } catch {
            throw InvestigationMachineDarwinOuterInnerSessionError
                .identityInvalid
        }
        guard
            identity.processID == processID,
            identity.parentProcessID == parentProcessID,
            identity.processGroupID == processID,
            identity.effectiveUserID == 0
        else { throw sessionInvalid() }
        let finalStandardError = try innerRoleStandardError(system)
        guard
            initialStandardError == finalStandardError,
            validInnerStandardError(finalStandardError)
        else { throw sessionInvalid() }
        return .init(
            driverChildIdentity: identity,
            standardError: finalStandardError
        )
    }
}

struct InvestigationMachineDarwinBoundedMessageSystem: Sendable {
    let readExactly: @Sendable (Int32, Int, UInt64) async throws -> Data
    let readUpToOne: @Sendable (Int32, UInt64) async throws -> Data
    let writeExactly: @Sendable (Int32, Data, UInt64) async throws -> Void

    static let system = Self(
        readExactly: { descriptor, count, deadline in
            try await InvestigationMachineDarwinOuterInnerRawIO.readExactly(
                descriptor: descriptor, count: count,
                deadlineNanoseconds: deadline
            )
        },
        readUpToOne: { descriptor, deadline in
            try await InvestigationMachineDarwinOuterInnerRawIO.readUpToOne(
                descriptor: descriptor, deadlineNanoseconds: deadline
            )
        },
        writeExactly: { descriptor, data, deadline in
            try await InvestigationMachineDarwinOuterInnerRawIO.writeExactly(
                descriptor: descriptor, data: data,
                deadlineNanoseconds: deadline
            )
        }
    )
}

enum InvestigationMachineDarwinBoundedMessageIO {
    private static let headerByteCount = 4
    private static let absoluteMaximumByteCount = 128 * 1_024

    static func write(
        _ payload: Data,
        descriptor: Int32,
        maximumByteCount: Int,
        deadlineNanoseconds: UInt64,
        system: InvestigationMachineDarwinBoundedMessageSystem = .system
    ) async throws {
        guard
            descriptor >= 0,
            maximumByteCount > 0,
            maximumByteCount <= absoluteMaximumByteCount,
            !payload.isEmpty,
            payload.count <= maximumByteCount,
            let count = UInt32(exactly: payload.count)
        else {
            throw InvestigationMachineDarwinOuterInnerSessionError
                .descriptorInvalid
        }
        var framed = Data()
        framed.reserveCapacity(headerByteCount + payload.count)
        framed.append(messageData(count))
        framed.append(payload)
        do {
            try await system.writeExactly(
                descriptor, framed, deadlineNanoseconds
            )
        } catch {
            throw normalizedTransportError(error)
        }
    }

    static func read(
        descriptor: Int32,
        maximumByteCount: Int,
        deadlineNanoseconds: UInt64,
        system: InvestigationMachineDarwinBoundedMessageSystem = .system
    ) async throws -> Data {
        guard descriptor >= 0, maximumByteCount > 0,
            maximumByteCount <= absoluteMaximumByteCount else {
            throw InvestigationMachineDarwinOuterInnerSessionError
                .descriptorInvalid
        }
        let header: Data
        do {
            header = try await system.readExactly(
                descriptor, headerByteCount, deadlineNanoseconds
            )
        } catch {
            throw normalizedTransportError(error)
        }
        return try await readPayload(
            firstHeaderByte: nil, remainingHeader: header,
            descriptor: descriptor, maximumByteCount: maximumByteCount,
            deadlineNanoseconds: deadlineNanoseconds, system: system
        )
    }

    static func readOrEOF(
        descriptor: Int32,
        maximumByteCount: Int,
        deadlineNanoseconds: UInt64,
        system: InvestigationMachineDarwinBoundedMessageSystem = .system
    ) async throws -> Data? {
        guard descriptor >= 0, maximumByteCount > 0,
            maximumByteCount <= absoluteMaximumByteCount else {
            throw InvestigationMachineDarwinOuterInnerSessionError
                .descriptorInvalid
        }
        let first: Data
        do {
            first = try await system.readUpToOne(
                descriptor, deadlineNanoseconds
            )
        } catch {
            throw normalizedTransportError(error)
        }
        guard !first.isEmpty else { return nil }
        guard first.count == 1 else {
            throw InvestigationMachineDarwinOuterInnerSessionError
                .transportUnavailable
        }
        let tail: Data
        do {
            tail = try await system.readExactly(
                descriptor, headerByteCount - 1, deadlineNanoseconds
            )
        } catch {
            throw normalizedTransportError(error)
        }
        return try await readPayload(
            firstHeaderByte: first[0], remainingHeader: tail,
            descriptor: descriptor, maximumByteCount: maximumByteCount,
            deadlineNanoseconds: deadlineNanoseconds, system: system
        )
    }

    static func proveEOF(
        descriptor: Int32,
        deadlineNanoseconds: UInt64,
        system: InvestigationMachineDarwinBoundedMessageSystem = .system
    ) async throws {
        guard descriptor >= 0 else {
            throw InvestigationMachineDarwinOuterInnerSessionError
                .descriptorInvalid
        }
        let trailing: Data
        do {
            trailing = try await system.readUpToOne(
                descriptor, deadlineNanoseconds
            )
        } catch {
            throw normalizedTransportError(error)
        }
        guard trailing.isEmpty else {
            throw InvestigationMachineDarwinOuterInnerSessionError
                .transportUnavailable
        }
    }

    private static func readPayload(
        firstHeaderByte: UInt8?,
        remainingHeader: Data,
        descriptor: Int32,
        maximumByteCount: Int,
        deadlineNanoseconds: UInt64,
        system: InvestigationMachineDarwinBoundedMessageSystem
    ) async throws -> Data {
        let header: Data
        if let firstHeaderByte {
            guard remainingHeader.count == headerByteCount - 1 else {
                throw InvestigationMachineDarwinOuterInnerSessionError
                    .transportUnavailable
            }
            header = Data([firstHeaderByte]) + remainingHeader
        } else {
            guard remainingHeader.count == headerByteCount else {
                throw InvestigationMachineDarwinOuterInnerSessionError
                    .transportUnavailable
            }
            header = remainingHeader
        }
        let declared = header.withUnsafeBytes { bytes in
            bytes.loadUnaligned(as: UInt32.self).bigEndian
        }
        guard
            declared > 0,
            let count = Int(exactly: declared),
            count <= maximumByteCount
        else {
            throw InvestigationMachineDarwinOuterInnerSessionError
                .transportUnavailable
        }
        do {
            return try await system.readExactly(
                descriptor, count, deadlineNanoseconds
            )
        } catch {
            throw normalizedTransportError(error)
        }
    }
}

package enum InvestigationMachineDarwinOuterInnerStartOutcome:
    Sendable, Equatable
{
    case started(InvestigationMachineDarwinOuterInnerSession)
    case terminal
    case terminalUncertain

    var startedSession: InvestigationMachineDarwinOuterInnerSession? {
        guard case let .started(session) = self else { return nil }
        return session
    }

    package static func == (
        lhs: InvestigationMachineDarwinOuterInnerStartOutcome,
        rhs: InvestigationMachineDarwinOuterInnerStartOutcome
    ) -> Bool {
        switch (lhs, rhs) {
        case let (.started(left), .started(right)):
            ObjectIdentifier(left) == ObjectIdentifier(right)
        case (.terminal, .terminal), (.terminalUncertain, .terminalUncertain):
            true
        default:
            false
        }
    }
}

struct InvestigationMachineDarwinOuterInnerSessionSystem: Sendable {
    let currentProcessID: @Sendable () -> UInt32
    let currentProcessGroup: @Sendable () -> Int32
    let continuousNanoseconds: @Sendable () throws -> UInt64
    let standardErrorObservation:
        @Sendable () throws -> InvestigationMachineDarwinStandardErrorObservation
    let socketPair:
        @Sendable () throws -> InvestigationMachineDarwinOuterInnerDescriptorPair
    let pipe:
        @Sendable () throws -> InvestigationMachineDarwinOuterInnerDescriptorPair
    let duplicateCloseOnExec: @Sendable (Int32, Int32) throws -> Int32
    let setCloseOnExec: @Sendable (Int32) throws -> Void
    let setNoSigpipe: @Sendable (Int32) throws -> Void
    let descriptorFlags: @Sendable (Int32) throws -> Int32
    let noSigpipe: @Sendable (Int32) throws -> Int32
    let descriptorStatusFlags: @Sendable (Int32) throws -> Int32
    let socketType: @Sendable (Int32) throws -> Int32
    let closeDescriptor: @Sendable (Int32) throws -> Void
    let spawn:
        @Sendable (InvestigationMachineDarwinOuterInnerSpawnRequest) throws
            -> Int32
    let messageSystem: InvestigationMachineDarwinBoundedMessageSystem

    static let system = Self(
        currentProcessID: { UInt32(getpid()) },
        currentProcessGroup: Darwin.getpgrp,
        continuousNanoseconds: outerInnerContinuousNanoseconds,
        standardErrorObservation: outerInnerStandardErrorObservation,
        socketPair: outerInnerSocketPair,
        pipe: outerInnerPipe,
        duplicateCloseOnExec: outerInnerDuplicateCloseOnExec,
        setCloseOnExec: outerInnerSetCloseOnExec,
        setNoSigpipe: outerInnerSetNoSigpipe,
        descriptorFlags: outerInnerDescriptorFlags,
        noSigpipe: outerInnerNoSigpipe,
        descriptorStatusFlags: outerInnerDescriptorStatusFlags,
        socketType: outerInnerSocketType,
        closeDescriptor: outerInnerClose,
        spawn: outerInnerSpawn,
        messageSystem: .system
    )
}

package actor InvestigationMachineDarwinOuterInnerSessionFactory {
    static let maximumSessionWindowNanoseconds: UInt64 = 140_000_000_000
    static let controlTargetDescriptor: Int32 = 8
    static let resultTargetDescriptor: Int32 = 9
    static let minimumRelocatedDescriptor: Int32 = 10
    static let spawnFlags = Int16(
        POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT
    )

    private enum State { case idle, starting, started, terminal }

    private let observer: any InvestigationMachineDarwinDriverChildObserving
    private let retirementOwner: any InvestigationMachineDarwinEpochRetirementOwning
    private let system: InvestigationMachineDarwinOuterInnerSessionSystem
    private var state = State.idle

    package init() {
        observer = InvestigationMachineDarwinDriverChildObserver()
        retirementOwner = InvestigationMachineDarwinEpochRetirementOwner()
        system = .system
    }

    init(
        observer: any InvestigationMachineDarwinDriverChildObserving,
        retirementOwner: any InvestigationMachineDarwinEpochRetirementOwning,
        system: InvestigationMachineDarwinOuterInnerSessionSystem
    ) {
        self.observer = observer
        self.retirementOwner = retirementOwner
        self.system = system
    }

    package func start(
        deadlineNanoseconds: UInt64
    ) async -> InvestigationMachineDarwinOuterInnerStartOutcome {
        guard case .idle = state else { return .terminalUncertain }
        state = .starting
        guard !Task.isCancelled else { return terminal(.terminal) }

        let outerProcessID = system.currentProcessID()
        let outerProcessGroup = system.currentProcessGroup()
        let now: UInt64
        let initialStandardError: InvestigationMachineDarwinStandardErrorObservation
        do {
            now = try system.continuousNanoseconds()
            initialStandardError = try system.standardErrorObservation()
            let maximum = now.addingReportingOverflow(
                Self.maximumSessionWindowNanoseconds
            )
            guard
                outerProcessID > 1, outerProcessGroup > 1,
                !maximum.overflow, deadlineNanoseconds > now,
                deadlineNanoseconds <= maximum.partialValue,
                Self.validStandardError(initialStandardError)
            else { return terminal(.terminalUncertain) }
        } catch {
            return terminal(.terminalUncertain)
        }

        var ledger = OuterInnerDescriptorLedger(system: system)
        let descriptors: InvestigationMachineDarwinOuterInnerDescriptorSet
        do {
            let control = try system.socketPair()
            try ledger.register(control)
            let result = try system.pipe()
            try ledger.register(result)
            descriptors = try relocate(
                control: control, result: result, ledger: &ledger
            )
            try validate(descriptors)
        } catch {
            ledger.closeAll()
            return terminal(.terminalUncertain)
        }

        let request = InvestigationMachineDarwinOuterInnerSpawnRequest(
            executablePath: InvestigationMachineInstalledDriverObservation
                .fixedExecutablePath,
            arguments: [
                InvestigationMachineInstalledDriverObservation
                    .fixedExecutablePath
            ],
            environment: [], inheritedDescriptor: STDERR_FILENO,
            controlOuterDescriptor: descriptors.outerControlDescriptor,
            controlChildSourceDescriptor:
                descriptors.innerControlSourceDescriptor,
            resultOuterDescriptor: descriptors.outerResultDescriptor,
            resultChildSourceDescriptor:
                descriptors.innerResultSourceDescriptor,
            controlTargetDescriptor: Self.controlTargetDescriptor,
            resultTargetDescriptor: Self.resultTargetDescriptor,
            closedFixedDescriptors: [STDIN_FILENO, STDOUT_FILENO, 7],
            flags: Self.spawnFlags
        )
        let processID: Int32
        do {
            processID = try system.spawn(request)
            guard processID > 1 else { throw sessionInvalid() }
        } catch {
            ledger.closeAll()
            return terminal(.terminalUncertain)
        }

        var childCloseFailed = false
        for descriptor in descriptors.innerSourceDescriptors {
            do { try ledger.close(descriptor) } catch { childCloseFailed = true }
        }
        guard !childCloseFailed else {
            return await retireSpawned(
                processID: processID, descriptors: descriptors.outerDescriptors,
                ledger: &ledger
            )
        }

        let identity: InvestigationMachineDarwinDriverChildIdentity
        do {
            identity = try observer.observe(
                processID: UInt32(processID),
                expectedParentProcessID: outerProcessID
            )
            let finalStandardError = try system.standardErrorObservation()
            guard
                identity.processID == UInt32(processID),
                identity.parentProcessID == outerProcessID,
                identity.processGroupID == identity.processID,
                Int32(identity.processGroupID) != outerProcessGroup,
                initialStandardError == finalStandardError,
                try system.continuousNanoseconds() < deadlineNanoseconds
            else { throw sessionInvalid() }
        } catch {
            return await retireSpawned(
                processID: processID, descriptors: descriptors.outerDescriptors,
                ledger: &ledger
            )
        }

        ledger.transfer(descriptors.outerDescriptors)
        let session = InvestigationMachineDarwinOuterInnerSession(
            driverChildIdentity: identity, descriptors: descriptors,
            retirementOwner: retirementOwner, messageSystem: system.messageSystem
        )
        state = .started
        return .started(session)
    }

    private func relocate(
        control: InvestigationMachineDarwinOuterInnerDescriptorPair,
        result: InvestigationMachineDarwinOuterInnerDescriptorPair,
        ledger: inout OuterInnerDescriptorLedger
    ) throws -> InvestigationMachineDarwinOuterInnerDescriptorSet {
        let outerControl = try ledger.relocate(control.firstDescriptor)
        let innerControl = try ledger.relocate(control.secondDescriptor)
        let outerResult = try ledger.relocate(result.firstDescriptor)
        let innerResult = try ledger.relocate(result.secondDescriptor)
        return .init(
            outerControlDescriptor: outerControl,
            innerControlSourceDescriptor: innerControl,
            outerResultDescriptor: outerResult,
            innerResultSourceDescriptor: innerResult
        )
    }

    private func validate(
        _ descriptors: InvestigationMachineDarwinOuterInnerDescriptorSet
    ) throws {
        guard
            Set(descriptors.allDescriptors).count == 4,
            descriptors.allDescriptors.allSatisfy({
                $0 >= Self.minimumRelocatedDescriptor
            })
        else { throw sessionInvalid() }
        for descriptor in descriptors.allDescriptors {
            try system.setCloseOnExec(descriptor)
            try system.setNoSigpipe(descriptor)
            guard
                try system.descriptorFlags(descriptor) & FD_CLOEXEC != 0,
                try system.noSigpipe(descriptor) == 1
            else {
                throw sessionInvalid()
            }
        }
        guard
            try system.descriptorStatusFlags(
                descriptors.outerControlDescriptor
            ) & O_ACCMODE == O_RDWR,
            try system.descriptorStatusFlags(
                descriptors.innerControlSourceDescriptor
            ) & O_ACCMODE == O_RDWR,
            try system.socketType(descriptors.outerControlDescriptor)
                == SOCK_STREAM,
            try system.socketType(descriptors.innerControlSourceDescriptor)
                == SOCK_STREAM,
            try system.descriptorStatusFlags(
                descriptors.outerResultDescriptor
            ) & O_ACCMODE == O_RDONLY,
            try system.descriptorStatusFlags(
                descriptors.innerResultSourceDescriptor
            ) & O_ACCMODE == O_WRONLY
        else { throw sessionInvalid() }
    }

    private func retireSpawned(
        processID: Int32,
        descriptors: [Int32],
        ledger: inout OuterInnerDescriptorLedger
    ) async -> InvestigationMachineDarwinOuterInnerStartOutcome {
        ledger.transfer(descriptors)
        do {
            try await retirementOwner.retireSpawnedProcess(.init(
                processID: processID, descriptors: descriptors
            ))
        } catch {}
        ledger.closeAll()
        return terminal(.terminalUncertain)
    }

    private func terminal(
        _ outcome: InvestigationMachineDarwinOuterInnerStartOutcome
    ) -> InvestigationMachineDarwinOuterInnerStartOutcome {
        state = .terminal
        return outcome
    }

    private static func validStandardError(
        _ observation: InvestigationMachineDarwinStandardErrorObservation
    ) -> Bool {
        validInnerStandardError(observation)
    }
}

package actor InvestigationMachineDarwinOuterInnerSession {
    nonisolated package let driverChildIdentity:
        InvestigationMachineDarwinDriverChildIdentity
    nonisolated let descriptors:
        InvestigationMachineDarwinOuterInnerDescriptorSet

    private enum State {
        case active
        case operation(UUID, poisoned: Bool)
        case retiring(UUID, poisoned: Bool)
        case terminal
    }
    private let retirementOwner: any InvestigationMachineDarwinEpochRetirementOwning
    private let messageSystem: InvestigationMachineDarwinBoundedMessageSystem
    private var state = State.active
    private var resultConsumed = false
    private var retirementTask: Task<
        InvestigationMachineSingleEpochRetirementProof?, Never
    >?

    init(
        driverChildIdentity: InvestigationMachineDarwinDriverChildIdentity,
        descriptors: InvestigationMachineDarwinOuterInnerDescriptorSet,
        retirementOwner: any InvestigationMachineDarwinEpochRetirementOwning,
        messageSystem: InvestigationMachineDarwinBoundedMessageSystem
    ) {
        self.driverChildIdentity = driverChildIdentity
        self.descriptors = descriptors
        self.retirementOwner = retirementOwner
        self.messageSystem = messageSystem
    }

    func sendControl(
        _ payload: Data, deadlineNanoseconds: UInt64
    ) async throws {
        let ticket = try await beginOperationOrRetire(consumesResult: false)
        do {
            try await InvestigationMachineDarwinBoundedMessageIO.write(
                payload, descriptor: descriptors.outerControlDescriptor,
                maximumByteCount: 128 * 1_024,
                deadlineNanoseconds: deadlineNanoseconds, system: messageSystem
            )
            try finishOperation(ticket)
        } catch {
            poison(ticket)
            try await retireAfterFailure()
            throw normalizedTransportError(error)
        }
    }

    func receiveControl(deadlineNanoseconds: UInt64) async throws -> Data {
        let ticket = try await beginOperationOrRetire(consumesResult: false)
        do {
            let value = try await InvestigationMachineDarwinBoundedMessageIO.read(
                descriptor: descriptors.outerControlDescriptor,
                maximumByteCount: 128 * 1_024,
                deadlineNanoseconds: deadlineNanoseconds, system: messageSystem
            )
            try finishOperation(ticket)
            return value
        } catch {
            poison(ticket)
            try await retireAfterFailure()
            throw normalizedTransportError(error)
        }
    }

    func receiveResult(deadlineNanoseconds: UInt64) async throws -> Data? {
        let ticket = try await beginOperationOrRetire(consumesResult: true)
        do {
            let value = try await InvestigationMachineDarwinBoundedMessageIO
                .readOrEOF(
                    descriptor: descriptors.outerResultDescriptor,
                    maximumByteCount: 16 * 1_024,
                    deadlineNanoseconds: deadlineNanoseconds,
                    system: messageSystem
                )
            try finishOperation(ticket)
            return value
        } catch {
            poison(ticket)
            try await retireAfterFailure()
            throw normalizedTransportError(error)
        }
    }

    func proveControlEOF(deadlineNanoseconds: UInt64) async throws {
        let ticket = try await beginOperationOrRetire(consumesResult: false)
        do {
            try await InvestigationMachineDarwinBoundedMessageIO.proveEOF(
                descriptor: descriptors.outerControlDescriptor,
                deadlineNanoseconds: deadlineNanoseconds, system: messageSystem
            )
            try finishOperation(ticket)
        } catch {
            poison(ticket)
            try await retireAfterFailure()
            throw normalizedTransportError(error)
        }
    }

    func proveResultEOF(deadlineNanoseconds: UInt64) async throws {
        let ticket = try await beginOperationOrRetire(consumesResult: false)
        do {
            try await InvestigationMachineDarwinBoundedMessageIO.proveEOF(
                descriptor: descriptors.outerResultDescriptor,
                deadlineNanoseconds: deadlineNanoseconds, system: messageSystem
            )
            try finishOperation(ticket)
        } catch {
            poison(ticket)
            try await retireAfterFailure()
            throw normalizedTransportError(error)
        }
    }

    func retireOwnedProcessGroup() async throws
        -> InvestigationMachineSingleEpochRetirementProof
    {
        _ = try beginRetirement()
        return try await awaitRetirement()
    }

    private func beginOperation(consumesResult: Bool) throws -> UUID {
        if Task.isCancelled {
            switch state {
            case .operation, .retiring:
                poisonCurrentState()
                throw InvestigationMachineDarwinOuterInnerSessionError
                    .operationInFlight
            case .active:
                state = .terminal
                throw InvestigationMachineDarwinOuterInnerSessionError
                    .transportUnavailable
            case .terminal:
                throw sessionConsumed()
            }
        }
        guard case .active = state else {
            switch state {
            case .operation, .retiring:
                poisonCurrentState()
                throw InvestigationMachineDarwinOuterInnerSessionError
                    .operationInFlight
            case .active:
                preconditionFailure("unreachable state")
            case .terminal:
                throw sessionConsumed()
            }
        }
        guard !consumesResult || !resultConsumed else {
            state = .terminal
            throw InvestigationMachineDarwinOuterInnerSessionError
                .alreadyConsumed
        }
        if consumesResult { resultConsumed = true }
        let ticket = UUID()
        state = .operation(ticket, poisoned: false)
        return ticket
    }

    private func beginOperationOrRetire(
        consumesResult: Bool
    ) async throws -> UUID {
        do { return try beginOperation(consumesResult: consumesResult) }
        catch let error as InvestigationMachineDarwinOuterInnerSessionError
        where error == .operationInFlight {
            throw error
        } catch {
            try await retireAfterFailure()
            throw normalizedTransportError(error)
        }
    }

    private func finishOperation(_ ticket: UUID) throws {
        guard case let .operation(active, poisoned) = state,
            active == ticket, !poisoned, !Task.isCancelled
        else {
            state = .terminal
            throw sessionConsumed()
        }
        state = .active
    }

    private func beginRetirement() throws -> UUID {
        guard case .active = state, !Task.isCancelled else {
            poisonCurrentState()
            throw sessionConsumed()
        }
        let ticket = UUID()
        state = .retiring(ticket, poisoned: false)
        return ticket
    }

    private func poisonCurrentState() {
        switch state {
        case let .operation(ticket, _):
            state = .operation(ticket, poisoned: true)
        case let .retiring(ticket, _):
            state = .retiring(ticket, poisoned: true)
        case .active, .terminal:
            state = .terminal
        }
    }

    private func poison(_ ticket: UUID) {
        if case let .operation(active, _) = state, active == ticket {
            state = .operation(ticket, poisoned: true)
        } else {
            poisonCurrentState()
        }
    }

    private func retireAfterFailure() async throws {
        do { _ = try await awaitRetirement() }
        catch {
            throw InvestigationMachineDarwinOuterInnerSessionError
                .retirementUncertain
        }
    }

    private func awaitRetirement() async throws
        -> InvestigationMachineSingleEpochRetirementProof
    {
        let task: Task<InvestigationMachineSingleEpochRetirementProof?, Never>
        if let existing = retirementTask {
            task = existing
        } else {
            state = .terminal
            let owner = retirementOwner
            let epoch = InvestigationMachineDarwinOwnedEpoch(
                processID: Int32(driverChildIdentity.processID),
                processGroupID: Int32(driverChildIdentity.processGroupID),
                descriptors: descriptors.outerDescriptors
            )
            let created = Task.detached {
                try? await owner.retireOwnedProcessGroup(epoch)
            }
            retirementTask = created
            task = created
        }
        guard let proof = await task.value else {
            throw InvestigationMachineDarwinOuterInnerSessionError
                .retirementUncertain
        }
        return proof
    }
}

enum InvestigationMachineDarwinOuterInnerSpawnPrimitive {
    static func spawn(
        _ request: InvestigationMachineDarwinOuterInnerSpawnRequest
    ) throws -> Int32 {
        guard
            request.arguments == [request.executablePath],
            !request.executablePath.isEmpty,
            request.environment.isEmpty,
            request.inheritedDescriptor == STDERR_FILENO,
            request.controlTargetDescriptor == 8,
            request.resultTargetDescriptor == 9,
            request.closedFixedDescriptors == [0, 1, 7],
            request.controlOuterDescriptor >= 10,
            request.controlChildSourceDescriptor >= 10,
            request.resultOuterDescriptor >= 10,
            request.resultChildSourceDescriptor >= 10,
            Set([
                request.controlOuterDescriptor,
                request.controlChildSourceDescriptor,
                request.resultOuterDescriptor,
                request.resultChildSourceDescriptor,
            ]).count == 4,
            request.flags == Int16(
                POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT
            )
        else { throw sessionSpawnFailed() }

        var actions: posix_spawn_file_actions_t?
        guard posix_spawn_file_actions_init(&actions) == 0 else {
            throw sessionSpawnFailed()
        }
        defer { posix_spawn_file_actions_destroy(&actions) }
        guard
            posix_spawn_file_actions_addinherit_np(
                &actions, request.inheritedDescriptor
            ) == 0,
            posix_spawn_file_actions_adddup2(
                &actions, request.controlChildSourceDescriptor,
                request.controlTargetDescriptor
            ) == 0,
            posix_spawn_file_actions_adddup2(
                &actions, request.resultChildSourceDescriptor,
                request.resultTargetDescriptor
            ) == 0,
            posix_spawn_file_actions_addclose(
                &actions, request.controlOuterDescriptor
            ) == 0,
            posix_spawn_file_actions_addclose(
                &actions, request.controlChildSourceDescriptor
            ) == 0,
            posix_spawn_file_actions_addclose(
                &actions, request.resultOuterDescriptor
            ) == 0,
            posix_spawn_file_actions_addclose(
                &actions, request.resultChildSourceDescriptor
            ) == 0
        else { throw sessionSpawnFailed() }

        var attributes: posix_spawnattr_t?
        guard posix_spawnattr_init(&attributes) == 0 else {
            throw sessionSpawnFailed()
        }
        defer { posix_spawnattr_destroy(&attributes) }
        guard
            posix_spawnattr_setflags(&attributes, request.flags) == 0,
            posix_spawnattr_setpgroup(&attributes, 0) == 0
        else { throw sessionSpawnFailed() }

        var processID: pid_t = 0
        let status = try outerInnerWithCStringArray(request.arguments) { argv in
            try outerInnerWithCStringArray(request.environment) { environment in
                request.executablePath.withCString { executable in
                    posix_spawn(
                        &processID, executable, &actions, &attributes,
                        argv, environment
                    )
                }
            }
        }
        guard status == 0, processID > 1 else { throw sessionSpawnFailed() }
        return processID
    }
}

private func outerInnerSpawn(
    _ request: InvestigationMachineDarwinOuterInnerSpawnRequest
) throws -> Int32 {
    guard
        request.executablePath
            == InvestigationMachineInstalledDriverObservation.fixedExecutablePath
    else { throw sessionSpawnFailed() }
    return try InvestigationMachineDarwinOuterInnerSpawnPrimitive.spawn(request)
}

private enum InvestigationMachineDarwinOuterInnerRawIO {
    private static let queue = DispatchQueue(
        label: "com.eriklee.stornaut.machine-outer-inner-io",
        attributes: .concurrent
    )

    static func readExactly(
        descriptor: Int32, count: Int, deadlineNanoseconds: UInt64
    ) async throws -> Data {
        try await perform { cancellation in
            try blockingRead(
                descriptor: descriptor, count: count,
                deadlineNanoseconds: deadlineNanoseconds, allowsEOF: false,
                cancellation: cancellation
            )
        }
    }

    static func readUpToOne(
        descriptor: Int32, deadlineNanoseconds: UInt64
    ) async throws -> Data {
        try await perform { cancellation in
            try blockingRead(
                descriptor: descriptor, count: 1,
                deadlineNanoseconds: deadlineNanoseconds, allowsEOF: true,
                cancellation: cancellation
            )
        }
    }

    static func writeExactly(
        descriptor: Int32, data: Data, deadlineNanoseconds: UInt64
    ) async throws {
        try await perform { cancellation in
            try setNonblocking(descriptor)
            var offset = 0
            try data.withUnsafeBytes { bytes in
                while offset < bytes.count {
                    try wait(
                        descriptor: descriptor, events: Int16(POLLOUT),
                        deadlineNanoseconds: deadlineNanoseconds,
                        cancellation: cancellation
                    )
                    let result = Darwin.write(
                        descriptor, bytes.baseAddress?.advanced(by: offset),
                        bytes.count - offset
                    )
                    if result > 0 { offset += result; continue }
                    if result < 0,
                        errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK
                    {
                        continue
                    }
                    throw sessionTransportUnavailable()
                }
            }
            try requireActive(
                deadlineNanoseconds, cancellation: cancellation
            )
        }
    }

    private static func blockingRead(
        descriptor: Int32, count: Int, deadlineNanoseconds: UInt64,
        allowsEOF: Bool, cancellation: OuterInnerIOCancellation
    ) throws -> Data {
        guard descriptor >= 0, count >= 0 else { throw sessionInvalid() }
        try setNonblocking(descriptor)
        if count == 0 {
            try requireActive(deadlineNanoseconds, cancellation: cancellation)
            return Data()
        }
        var data = Data(count: count)
        var offset = 0
        while offset < count {
            try wait(
                descriptor: descriptor, events: Int16(POLLIN | POLLHUP),
                deadlineNanoseconds: deadlineNanoseconds,
                cancellation: cancellation
            )
            let result = data.withUnsafeMutableBytes { bytes in
                Darwin.read(
                    descriptor, bytes.baseAddress?.advanced(by: offset),
                    count - offset
                )
            }
            if result > 0 { offset += result; continue }
            if result == 0, allowsEOF, offset == 0 {
                try requireActive(
                    deadlineNanoseconds, cancellation: cancellation
                )
                return Data()
            }
            if result < 0,
                errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK
            {
                continue
            }
            throw sessionTransportUnavailable()
        }
        try requireActive(deadlineNanoseconds, cancellation: cancellation)
        return data
    }

    private static func setNonblocking(_ descriptor: Int32) throws {
        let flags = fcntl(descriptor, F_GETFL)
        guard
            flags >= 0,
            fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) == 0
        else { throw sessionTransportUnavailable() }
    }

    private static func wait(
        descriptor: Int32, events: Int16, deadlineNanoseconds: UInt64,
        cancellation: OuterInnerIOCancellation
    ) throws {
        while true {
            let now = try requireActive(
                deadlineNanoseconds, cancellation: cancellation
            )
            let remaining = deadlineNanoseconds - now
            let milliseconds = Int32(
                min(max(1, min(remaining / 1_000_000, 50)), UInt64(Int32.max))
            )
            var descriptorEvent = pollfd(
                fd: descriptor, events: events, revents: 0
            )
            let result = poll(&descriptorEvent, 1, milliseconds)
            if result == 0 { continue }
            if result < 0 {
                if errno == EINTR { continue }
                throw sessionTransportUnavailable()
            }
            guard descriptorEvent.revents & events != 0 else {
                throw sessionTransportUnavailable()
            }
            _ = try requireActive(
                deadlineNanoseconds, cancellation: cancellation
            )
            return
        }
    }

    @discardableResult
    private static func requireActive(
        _ deadlineNanoseconds: UInt64,
        cancellation: OuterInnerIOCancellation
    ) throws -> UInt64 {
        if cancellation.isRequested { throw CancellationError() }
        let now = try outerInnerContinuousNanoseconds()
        guard now < deadlineNanoseconds else {
            throw InvestigationMachineDarwinOuterInnerSessionError
                .deadlineInvalid
        }
        return now
    }

    private static func perform<Value: Sendable>(
        _ operation: @escaping @Sendable (OuterInnerIOCancellation) throws
            -> Value
    ) async throws -> Value {
        let cancellation = OuterInnerIOCancellation()
        let resolution = OuterInnerIOResolution<Value>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                resolution.install(continuation)
                queue.async {
                    resolution.finish(Result { try operation(cancellation) })
                }
                if Task.isCancelled {
                    cancellation.request()
                    resolution.requestCancellation()
                }
            }
        } onCancel: {
            cancellation.request()
            resolution.requestCancellation()
        }
    }
}

private final class OuterInnerIOCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var requested = false
    var isRequested: Bool { lock.withLock { requested } }
    func request() { lock.withLock { requested = true } }
}

private final class OuterInnerIOResolution<Value: Sendable>:
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

    func requestCancellation() {
        lock.withLock {
            guard !completed else { return }
            cancellationRequested = true
        }
    }
}

private struct OuterInnerDescriptorLedger {
    let system: InvestigationMachineDarwinOuterInnerSessionSystem
    private(set) var open = Set<Int32>()
    private var closeAttempted = Set<Int32>()

    init(system: InvestigationMachineDarwinOuterInnerSessionSystem) {
        self.system = system
    }

    mutating func register(
        _ pair: InvestigationMachineDarwinOuterInnerDescriptorPair
    ) throws {
        guard
            pair.firstDescriptor >= 0, pair.secondDescriptor >= 0,
            pair.firstDescriptor != pair.secondDescriptor,
            !open.contains(pair.firstDescriptor),
            !open.contains(pair.secondDescriptor)
        else { throw sessionInvalid() }
        open.insert(pair.firstDescriptor)
        open.insert(pair.secondDescriptor)
    }

    mutating func relocate(_ descriptor: Int32) throws -> Int32 {
        guard open.contains(descriptor) else { throw sessionInvalid() }
        let replacement = try system.duplicateCloseOnExec(
            descriptor,
            InvestigationMachineDarwinOuterInnerSessionFactory
                .minimumRelocatedDescriptor
        )
        guard
            replacement >= InvestigationMachineDarwinOuterInnerSessionFactory
                .minimumRelocatedDescriptor,
            replacement != descriptor, !open.contains(replacement)
        else {
            if replacement >= 0, replacement != descriptor,
                !open.contains(replacement)
            {
                try? system.closeDescriptor(replacement)
            }
            throw sessionInvalid()
        }
        open.insert(replacement)
        try close(descriptor)
        return replacement
    }

    mutating func close(_ descriptor: Int32) throws {
        guard open.contains(descriptor), closeAttempted.insert(descriptor).inserted
        else { throw sessionInvalid() }
        open.remove(descriptor)
        try system.closeDescriptor(descriptor)
    }

    mutating func transfer(_ descriptors: [Int32]) {
        for descriptor in descriptors { open.remove(descriptor) }
    }

    mutating func closeAll() {
        for descriptor in open.sorted()
        where closeAttempted.insert(descriptor).inserted {
            try? system.closeDescriptor(descriptor)
        }
        open.removeAll()
    }
}

private func outerInnerSocketPair() throws
    -> InvestigationMachineDarwinOuterInnerDescriptorPair
{
    var descriptors = [Int32](repeating: -1, count: 2)
    guard socketpair(AF_UNIX, SOCK_STREAM, 0, &descriptors) == 0 else {
        throw sessionInvalid()
    }
    return .init(
        firstDescriptor: descriptors[0], secondDescriptor: descriptors[1]
    )
}

private func outerInnerPipe() throws
    -> InvestigationMachineDarwinOuterInnerDescriptorPair
{
    var descriptors = [Int32](repeating: -1, count: 2)
    guard pipe(&descriptors) == 0 else { throw sessionInvalid() }
    return .init(
        firstDescriptor: descriptors[0], secondDescriptor: descriptors[1]
    )
}

private func outerInnerDuplicateCloseOnExec(
    _ descriptor: Int32, _ minimum: Int32
) throws -> Int32 {
    let value = fcntl(descriptor, F_DUPFD_CLOEXEC, minimum)
    guard value >= minimum else { throw sessionInvalid() }
    return value
}

private func outerInnerSetCloseOnExec(_ descriptor: Int32) throws {
    let flags = fcntl(descriptor, F_GETFD)
    guard flags >= 0, fcntl(descriptor, F_SETFD, flags | FD_CLOEXEC) == 0 else {
        throw sessionInvalid()
    }
}

private func outerInnerDescriptorFlags(_ descriptor: Int32) throws -> Int32 {
    let value = fcntl(descriptor, F_GETFD)
    guard value >= 0 else { throw sessionInvalid() }
    return value
}

private func outerInnerSetNoSigpipe(_ descriptor: Int32) throws {
    guard fcntl(descriptor, F_SETNOSIGPIPE, 1) == 0 else {
        throw sessionInvalid()
    }
}

private func outerInnerNoSigpipe(_ descriptor: Int32) throws -> Int32 {
    let value = fcntl(descriptor, F_GETNOSIGPIPE)
    guard value >= 0 else { throw sessionInvalid() }
    return value
}

private func outerInnerDescriptorStatusFlags(
    _ descriptor: Int32
) throws -> Int32 {
    let value = fcntl(descriptor, F_GETFL)
    guard value >= 0 else { throw sessionInvalid() }
    return value
}

private func innerRoleDescriptorFlags(
    _ descriptor: Int32
) -> Result<Int32, InvestigationMachineDarwinInnerRoleSystemError> {
    errno = 0
    let value = fcntl(descriptor, F_GETFD)
    guard value >= 0 else {
        return .failure(.init(errno: errno == 0 ? EIO : errno))
    }
    return .success(value)
}

private func innerRoleDescriptorStatusFlags(
    _ descriptor: Int32
) -> Result<Int32, InvestigationMachineDarwinInnerRoleSystemError> {
    errno = 0
    let value = fcntl(descriptor, F_GETFL)
    guard value >= 0 else {
        return .failure(.init(errno: errno == 0 ? EIO : errno))
    }
    return .success(value)
}

private func innerRoleSocketType(
    _ descriptor: Int32
) -> Result<Int32, InvestigationMachineDarwinInnerRoleSystemError> {
    do { return .success(try outerInnerSocketType(descriptor)) }
    catch { return .failure(.init(errno: errno == 0 ? EIO : errno)) }
}

private func innerRoleStatus(
    _ system: InvestigationMachineDarwinInnerRoleSystem, _ descriptor: Int32
) throws -> Int32 {
    do { return try system.descriptorStatusFlags(descriptor).get() }
    catch { throw sessionInvalid() }
}

private func innerRoleDescriptor(
    _ system: InvestigationMachineDarwinInnerRoleSystem, _ descriptor: Int32
) throws -> Int32 {
    do { return try system.descriptorFlags(descriptor).get() }
    catch { throw sessionInvalid() }
}

private func innerRoleSocket(
    _ system: InvestigationMachineDarwinInnerRoleSystem, _ descriptor: Int32
) throws -> Int32 {
    do { return try system.socketType(descriptor).get() }
    catch { throw sessionInvalid() }
}

private func innerRoleSocketEndpoints(
    _ system: InvestigationMachineDarwinInnerRoleSystem, _ descriptor: Int32
) throws -> InvestigationMachineDarwinSocketEndpointObservation {
    do { return try system.socketEndpoints(descriptor).get() }
    catch { throw sessionInvalid() }
}

private func innerRoleNode(
    _ system: InvestigationMachineDarwinInnerRoleSystem, _ descriptor: Int32
) throws -> InvestigationMachineDarwinDescriptorNodeObservation {
    do { return try system.descriptorNode(descriptor).get() }
    catch { throw sessionInvalid() }
}

private func innerRoleStandardError(
    _ system: InvestigationMachineDarwinInnerRoleSystem
) throws -> InvestigationMachineDarwinStandardErrorObservation {
    do { return try system.standardErrorObservation() }
    catch { throw sessionInvalid() }
}

private func innerRoleDescriptorNode(
    _ descriptor: Int32
) -> Result<
    InvestigationMachineDarwinDescriptorNodeObservation,
    InvestigationMachineDarwinInnerRoleSystemError
> {
    errno = 0
    var status = stat()
    guard fstat(descriptor, &status) == 0 else {
        return .failure(.init(errno: errno == 0 ? EIO : errno))
    }
    return .success(.init(
        deviceID: UInt64(bitPattern: Int64(status.st_dev)),
        inode: UInt64(status.st_ino),
        fileType: status.st_mode & mode_t(S_IFMT)
    ))
}

private func innerRoleSocketEndpoints(
    _ descriptor: Int32
) -> Result<
    InvestigationMachineDarwinSocketEndpointObservation,
    InvestigationMachineDarwinInnerRoleSystemError
> {
    func family(
        _ operation: (Int32, UnsafeMutablePointer<sockaddr>,
            UnsafeMutablePointer<socklen_t>) -> Int32
    ) -> Result<sa_family_t, InvestigationMachineDarwinInnerRoleSystemError> {
        var address = sockaddr_storage()
        var length = socklen_t(MemoryLayout<sockaddr_storage>.size)
        errno = 0
        let status = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                operation(descriptor, $0, &length)
            }
        }
        guard
            status == 0,
            length >= socklen_t(MemoryLayout<sockaddr>.size),
            length <= socklen_t(MemoryLayout<sockaddr_storage>.size)
        else {
            return .failure(.init(errno: errno == 0 ? EIO : errno))
        }
        return .success(address.ss_family)
    }
    let localFamily: sa_family_t
    switch family(Darwin.getsockname) {
    case let .success(value): localFamily = value
    case let .failure(error): return .failure(error)
    }
    switch family(Darwin.getpeername) {
    case let .success(peerFamily):
        return .success(.init(
            localFamily: localFamily, peerFamily: peerFamily
        ))
    case let .failure(error):
        return .failure(error)
    }
}

private func validInnerStandardError(
    _ observation: InvestigationMachineDarwinStandardErrorObservation
) -> Bool {
    let access = observation.statusFlags & O_ACCMODE
    return observation.inode > 0
        && (access == O_WRONLY || access == O_RDWR)
        && (!observation.isTTY
            || (observation.foregroundProcessGroup ?? 0) > 1)
}

private func outerInnerSocketType(_ descriptor: Int32) throws -> Int32 {
    var value: Int32 = 0
    var length = socklen_t(MemoryLayout<Int32>.size)
    guard getsockopt(
        descriptor, SOL_SOCKET, SO_TYPE, &value, &length
    ) == 0, length == MemoryLayout<Int32>.size else {
        throw sessionInvalid()
    }
    return value
}

private func outerInnerClose(_ descriptor: Int32) throws {
    guard Darwin.close(descriptor) == 0 else { throw sessionInvalid() }
}

private func outerInnerStandardErrorObservation() throws
    -> InvestigationMachineDarwinStandardErrorObservation
{
    var status = stat()
    guard fstat(STDERR_FILENO, &status) == 0 else { throw sessionInvalid() }
    let flags = try outerInnerDescriptorStatusFlags(STDERR_FILENO)
    let tty = isatty(STDERR_FILENO) == 1
    let foreground: Int32?
    if tty {
        let value = tcgetpgrp(STDERR_FILENO)
        guard value > 1 else { throw sessionInvalid() }
        foreground = value
    } else {
        foreground = nil
    }
    return .init(
        deviceID: UInt64(bitPattern: Int64(status.st_dev)),
        inode: UInt64(status.st_ino),
        mode: status.st_mode, statusFlags: flags, isTTY: tty,
        foregroundProcessGroup: foreground
    )
}

private func outerInnerContinuousNanoseconds() throws -> UInt64 {
    var timebase = mach_timebase_info_data_t()
    guard mach_timebase_info(&timebase) == KERN_SUCCESS, timebase.denom > 0 else {
        throw InvestigationMachineDarwinOuterInnerSessionError.deadlineInvalid
    }
    let product = mach_continuous_time()
        .multipliedFullWidth(by: UInt64(timebase.numer))
    guard product.high < UInt64(timebase.denom) else {
        throw InvestigationMachineDarwinOuterInnerSessionError.deadlineInvalid
    }
    return UInt64(timebase.denom).dividingFullWidth(product).quotient
}

private func outerInnerWithCStringArray<Result>(
    _ strings: [String],
    body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws -> Result
) throws -> Result {
    guard strings.allSatisfy({ !$0.utf8.contains(0) }) else {
        throw sessionSpawnFailed()
    }
    var storage: [UnsafeMutablePointer<CChar>?] = strings.map { strdup($0) }
    guard storage.allSatisfy({ $0 != nil }) else {
        storage.compactMap { $0 }.forEach { free($0) }
        throw sessionSpawnFailed()
    }
    defer { storage.compactMap { $0 }.forEach { free($0) } }
    storage.append(nil)
    return try storage.withUnsafeMutableBufferPointer { buffer in
        try body(buffer.baseAddress!)
    }
}

private func messageData(_ value: UInt32) -> Data {
    Data([
        UInt8(truncatingIfNeeded: value >> 24),
        UInt8(truncatingIfNeeded: value >> 16),
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value),
    ])
}

private func normalizedTransportError(
    _ error: any Error
) -> InvestigationMachineDarwinOuterInnerSessionError {
    if error is CancellationError { return .transportUnavailable }
    return error as? InvestigationMachineDarwinOuterInnerSessionError
        ?? .transportUnavailable
}

private func sessionInvalid()
    -> InvestigationMachineDarwinOuterInnerSessionError
{
    .descriptorInvalid
}

private func sessionSpawnFailed()
    -> InvestigationMachineDarwinOuterInnerSessionError
{
    .spawnFailed
}

private func sessionTransportUnavailable()
    -> InvestigationMachineDarwinOuterInnerSessionError
{
    .transportUnavailable
}

private func sessionConsumed()
    -> InvestigationMachineDarwinOuterInnerSessionError
{
    .alreadyConsumed
}
#endif
