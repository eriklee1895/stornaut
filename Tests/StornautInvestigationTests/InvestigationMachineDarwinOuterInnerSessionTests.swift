import Darwin
import Foundation
import Testing

@testable import StornautInvestigationMachineDriverSupport

@Suite("Investigation machine Darwin outer-inner session", .serialized)
struct InvestigationMachineDarwinOuterInnerSessionTests {
    @Test
    func fixedSelfSpawnRequestTargetsInstalledDriverWithClosedInputs() async throws {
        let fixture = OuterInnerSessionFixture()
        let factory = fixture.makeFactory()
        let outcome = await factory.start(
            deadlineNanoseconds: fixture.deadline
        )
        let session = try #require(outcome.startedSession)
        let request = try #require(fixture.system.spawnRequest)

        #expect(
            request.executablePath
                == InvestigationMachineInstalledDriverObservation
                    .fixedExecutablePath
        )
        #expect(request.arguments == [request.executablePath])
        #expect(request.environment.isEmpty)
        #expect(
            request.flags
                == Int16(
                    POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT
                )
        )
        #expect(request.inheritedDescriptor == STDERR_FILENO)
        #expect(request.controlTargetDescriptor == 8)
        #expect(request.resultTargetDescriptor == 9)
        #expect(request.closedFixedDescriptors == [0, 1, 7])
        #expect(session.driverChildIdentity == fixture.driverIdentity)
        #expect(fixture.observer.calls.count == 1)
        #expect(fixture.observer.calls.first?.0 == 42)
        #expect(fixture.observer.calls.first?.1 == 21)
        #expect(fixture.system.standardErrorObservations.count == 2)
        #expect(fixture.system.noSigpipe == [10, 11, 12, 13])
        _ = try await session.retireOwnedProcessGroup()
        #expect(fixture.retirement.ownedCalls == 1)
        #expect(
            await factory.start(
                deadlineNanoseconds: fixture.deadline
            ) == .terminalUncertain
        )
        #expect(fixture.system.spawnCount == 1)

        let expired = OuterInnerSessionFixture()
        #expect(
            await expired.makeFactory().start(deadlineNanoseconds: 1)
                == .terminalUncertain
        )
        #expect(expired.system.spawnCount == 0)
        let overWindow = OuterInnerSessionFixture()
        #expect(
            await overWindow.makeFactory().start(
                deadlineNanoseconds: 140_000_000_002
            ) == .terminalUncertain
        )
        #expect(overWindow.system.spawnCount == 0)
    }

    @Test
    func fixedDescriptorCollisionsRelocateEveryEndpointAtLeastTen() async throws {
        let fixture = OuterInnerSessionFixture(
            control: .init(firstDescriptor: 7, secondDescriptor: 8),
            result: .init(firstDescriptor: 9, secondDescriptor: 3),
            duplicates: [10, 11, 12, 13]
        )
        let outcome = await fixture.makeFactory().start(
            deadlineNanoseconds: fixture.deadline
        )
        let session = try #require(outcome.startedSession)
        let descriptors = session.descriptors

        #expect(descriptors.outerControlDescriptor == 10)
        #expect(descriptors.innerControlSourceDescriptor == 11)
        #expect(descriptors.outerResultDescriptor == 12)
        #expect(descriptors.innerResultSourceDescriptor == 13)
        #expect(Set(descriptors.allDescriptors).count == 4)
        #expect(descriptors.allDescriptors.allSatisfy { $0 >= 10 })
        #expect(fixture.system.duplicates.map(\.old) == [7, 8, 9, 3])
        #expect(Set(fixture.system.closed).isSuperset(of: [7, 8, 9, 3, 11, 13]))
        #expect(fixture.system.closeOnExec == [10, 11, 12, 13])
    }

    @Test
    func relocationOrSpawnFailureClosesOwnedEndpointsAndRetiresAtMostOnce() async {
        let preSpawn = OuterInnerSessionFixture(duplicateFailureAt: 2)
        let first = await preSpawn.makeFactory().start(
            deadlineNanoseconds: preSpawn.deadline
        )
        #expect(first == .terminalUncertain)
        #expect(preSpawn.system.spawnCount == 0)
        #expect(preSpawn.system.closed.count == Set(preSpawn.system.closed).count)
        #expect(preSpawn.retirement.spawnedCalls == 0)

        let postSpawn = OuterInnerSessionFixture(observerFails: true)
        let second = await postSpawn.makeFactory().start(
            deadlineNanoseconds: postSpawn.deadline
        )
        #expect(second == .terminalUncertain)
        #expect(postSpawn.system.spawnCount == 1)
        #expect(postSpawn.retirement.spawnedCalls == 1)
        #expect(postSpawn.retirement.ownedCalls == 0)
        #expect(postSpawn.retirement.spawned?.processID == 42)
        #expect(postSpawn.retirement.spawned?.descriptors == [10, 12])
    }

    @Test
    func driverChildObserverBindsStableIdentityParentAndProcessGroup() throws {
        let fixture = DriverChildObservationFixture()
        let identity = try InvestigationMachineDarwinDriverChildObserver(
            system: fixture.system()
        ).observe(processID: 42, expectedParentProcessID: 21)

        #expect(identity == fixture.expectedIdentity)
        #expect(fixture.calls == [
            "narrow:42", "snapshot:42", "snapshot:42", "narrow:42",
        ])
        #expect(!(type(of: identity) is any Codable.Type))
    }

    @Test(arguments: DriverChildObservationMutation.allCases)
    fileprivate func driverChildIdentityDriftFailsBeforeTransport(
        _ mutation: DriverChildObservationMutation
    ) throws {
        let fixture = DriverChildObservationFixture(mutation: mutation)
        #expect(
            throws: InvestigationMachineDarwinDriverChildObservationError.self
        ) {
            _ = try InvestigationMachineDarwinDriverChildObserver(
                system: fixture.system()
            ).observe(processID: 42, expectedParentProcessID: 21)
        }
    }

    @Test(arguments: InnerRoleMutation.allCases)
    fileprivate func innerRoleRequiresExactProcessAndFixedDescriptorProvenance(
        _ mutation: InnerRoleMutation
    ) throws {
        let fixture = InnerRoleFixture(mutation: mutation)
        let validator = InvestigationMachineDarwinInnerRoleValidator(
            observer: fixture.observer, system: fixture.system()
        )
        if mutation == .valid {
            let observed = try validator.validate()
            #expect(observed.driverChildIdentity == fixture.identity)
            #expect(observed.standardError == fixture.standardError)
            #expect(!(type(of: observed) is any Codable.Type))
        } else {
            #expect(
                throws: InvestigationMachineDarwinOuterInnerSessionError.self
            ) {
                _ = try validator.validate()
            }
        }
    }

    @Test
    func boundedControlTransportHandlesFragmentsAndRejectsInvalidLengths() async throws {
        let payload = Data([0x11, 0x22, 0x33])
        let writer = MessageIORecorder()
        try await InvestigationMachineDarwinBoundedMessageIO.write(
            payload, descriptor: 10, maximumByteCount: 128 * 1_024,
            deadlineNanoseconds: 100, system: writer.system()
        )
        #expect(writer.writes == [Data([0, 0, 0, 3]) + payload])

        let reader = MessageIORecorder(reads: [
            Data([0, 0, 0, 3]), Data([0x11, 0x22, 0x33]),
        ])
        #expect(
            try await InvestigationMachineDarwinBoundedMessageIO.read(
                descriptor: 10, maximumByteCount: 128 * 1_024,
                deadlineNanoseconds: 100, system: reader.system()
            ) == payload
        )

        for header in [Data([0, 0, 0, 0]), Data([0, 2, 0, 1])] {
            let invalid = MessageIORecorder(reads: [header])
            await #expect(
                throws: InvestigationMachineDarwinOuterInnerSessionError.self
            ) {
                _ = try await InvestigationMachineDarwinBoundedMessageIO.read(
                    descriptor: 10, maximumByteCount: 128 * 1_024,
                    deadlineNanoseconds: 100, system: invalid.system()
                )
            }
        }
    }

    @Test
    func resultTransportDistinguishesOneResultFromZeroByteEOF() async throws {
        let eof = MessageIORecorder(upToOne: [Data()])
        #expect(
            try await InvestigationMachineDarwinBoundedMessageIO.readOrEOF(
                descriptor: 12, maximumByteCount: 16 * 1_024,
                deadlineNanoseconds: 100, system: eof.system()
            ) == nil
        )

        let result = Data([0xaa, 0xbb])
        let framed = MessageIORecorder(
            reads: [Data([0, 0, 2]), result],
            upToOne: [Data([0]), Data([0])]
        )
        #expect(
            try await InvestigationMachineDarwinBoundedMessageIO.readOrEOF(
                descriptor: 12, maximumByteCount: 16 * 1_024,
                deadlineNanoseconds: 100, system: framed.system()
            ) == result
        )
        await #expect(
            throws: InvestigationMachineDarwinOuterInnerSessionError.self
        ) {
            try await InvestigationMachineDarwinBoundedMessageIO.proveEOF(
                descriptor: 12, deadlineNanoseconds: 100,
                system: framed.system()
            )
        }

        let gate = MessageIOGate()
        let concurrentIO = MessageIORecorder(
            reads: [Data([0, 0, 0]), Data([0xcc])],
            upToOne: [Data([0])], gate: gate
        )
        let owner = RecordingOuterInnerRetirementOwner()
        let identity = DriverChildObservationFixture().expectedIdentity
        let session = InvestigationMachineDarwinOuterInnerSession(
            driverChildIdentity: identity,
            descriptors: .init(
                outerControlDescriptor: 10, innerControlSourceDescriptor: 11,
                outerResultDescriptor: 12, innerResultSourceDescriptor: 13
            ),
            retirementOwner: owner, messageSystem: concurrentIO.system()
        )
        let first = Task {
            try await session.receiveResult(deadlineNanoseconds: 100)
        }
        await gate.waitUntilEntered()
        await #expect(throws: (any Error).self) {
            _ = try await session.receiveResult(deadlineNanoseconds: 100)
        }
        #expect(owner.ownedCalls == 0)
        await gate.open()
        await #expect(throws: (any Error).self) { _ = try await first.value }
        #expect(owner.ownedCalls == 1)
    }

    @Test
    func physicalChildReceivesOnlyStderrControlAndResultAndLeadsGroup() async throws {
        let fixture = try compileOuterInnerPhysicalChildFixture()
        defer { try? FileManager.default.removeItem(
            at: fixture.deletingLastPathComponent()
        ) }
        let descriptors = try physicalDescriptorSet()
        let productionNodes = InvestigationMachineDarwinInnerRoleSystem.system
        let controlNode = try productionNodes.descriptorNode(
            descriptors.outerControlDescriptor
        ).get()
        let resultNode = try productionNodes.descriptorNode(
            descriptors.outerResultDescriptor
        ).get()
        let controlEndpoints = try productionNodes.socketEndpoints(
            descriptors.outerControlDescriptor
        ).get()
        #expect(controlNode.fileType == mode_t(S_IFSOCK))
        #expect(resultNode.fileType == mode_t(S_IFIFO))
        #expect(controlNode != resultNode)
        #expect(controlEndpoints.localFamily == sa_family_t(AF_UNIX))
        #expect(controlEndpoints.peerFamily == sa_family_t(AF_UNIX))
        var openDescriptors = Set(descriptors.allDescriptors)
        var childPID: Int32 = -1
        defer {
            for descriptor in openDescriptors {
                _ = Darwin.close(descriptor)
            }
            if childPID > 1 {
                _ = Darwin.kill(childPID, SIGKILL)
                while waitpid(childPID, nil, 0) < 0 {
                    if errno != EINTR { break }
                }
            }
        }
        childPID = try InvestigationMachineDarwinOuterInnerSpawnPrimitive.spawn(
            .init(
                executablePath: fixture.path, arguments: [fixture.path],
                environment: [], inheritedDescriptor: STDERR_FILENO,
                controlOuterDescriptor: descriptors.outerControlDescriptor,
                controlChildSourceDescriptor:
                    descriptors.innerControlSourceDescriptor,
                resultOuterDescriptor: descriptors.outerResultDescriptor,
                resultChildSourceDescriptor:
                    descriptors.innerResultSourceDescriptor,
                controlTargetDescriptor: 8, resultTargetDescriptor: 9,
                closedFixedDescriptors: [0, 1, 7],
                flags: Int16(
                    POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT
                )
            )
        )
        try #require(childPID > 1)
        #expect(getpgid(childPID) == childPID)
        #expect(childPID != getpgrp())
        let rawIdentitySystem =
            InvestigationMachineDarwinDriverChildIdentitySystem.system
        let firstSnapshot = try InvestigationMachineDarwinDriverChildTopologyReader
            .observe(processID: UInt32(childPID))
        let secondSnapshot = try InvestigationMachineDarwinDriverChildTopologyReader
            .observe(processID: UInt32(childPID))
        #expect(firstSnapshot == secondSnapshot)
        #expect(firstSnapshot.parentProcessID == UInt32(getpid()))
        #expect(firstSnapshot.processGroupID == UInt32(childPID))
        #expect(firstSnapshot.effectiveUserID == UInt32(geteuid()))
        if geteuid() != 0 {
            let firstNarrow = try rawIdentitySystem.narrowIdentity(
                UInt32(childPID)
            )
            let secondNarrow = try rawIdentitySystem.narrowIdentity(
                UInt32(childPID)
            )
            #expect(firstNarrow == secondNarrow)
            #expect(firstNarrow.effectiveUserID == UInt32(geteuid()))
            #expect(
                throws:
                    InvestigationMachineDarwinDriverChildObservationError.self
            ) {
                _ = try InvestigationMachineDarwinDriverChildObserver(
                    system: rawIdentitySystem
                ).observe(
                    processID: UInt32(childPID),
                    expectedParentProcessID: UInt32(getpid())
                )
            }
        } else {
            let observed = try InvestigationMachineDarwinDriverChildObserver(
                system: rawIdentitySystem
            ).observe(
                processID: UInt32(childPID),
                expectedParentProcessID: UInt32(getpid())
            )
            #expect(observed.processID == UInt32(childPID))
        }
        _ = Darwin.close(descriptors.innerControlSourceDescriptor)
        _ = Darwin.close(descriptors.innerResultSourceDescriptor)
        openDescriptors.remove(descriptors.innerControlSourceDescriptor)
        openDescriptors.remove(descriptors.innerResultSourceDescriptor)

        let io = InvestigationMachineDarwinBoundedMessageSystem.system
        try await InvestigationMachineDarwinBoundedMessageIO.write(
            Data("PING".utf8), descriptor: descriptors.outerControlDescriptor,
            maximumByteCount: 128 * 1_024, deadlineNanoseconds: UInt64.max,
            system: io
        )
        #expect(
            try await InvestigationMachineDarwinBoundedMessageIO.read(
                descriptor: descriptors.outerControlDescriptor,
                maximumByteCount: 128 * 1_024,
                deadlineNanoseconds: UInt64.max, system: io
            ) == Data("PONG".utf8)
        )
        #expect(
            try await InvestigationMachineDarwinBoundedMessageIO.readOrEOF(
                descriptor: descriptors.outerResultDescriptor,
                maximumByteCount: 16 * 1_024,
                deadlineNanoseconds: UInt64.max, system: io
            ) == Data("RESULT".utf8)
        )
        try await InvestigationMachineDarwinBoundedMessageIO.proveEOF(
            descriptor: descriptors.outerResultDescriptor,
            deadlineNanoseconds: UInt64.max, system: io
        )
        try await InvestigationMachineDarwinBoundedMessageIO.proveEOF(
            descriptor: descriptors.outerControlDescriptor,
            deadlineNanoseconds: UInt64.max, system: io
        )
        var status: Int32 = 0
        while waitpid(childPID, &status, 0) < 0 {
            if errno != EINTR { throw OuterInnerSessionTestFailure.io }
        }
        childPID = -1
        #expect(status == 0)
    }
}

private enum DriverChildObservationMutation: CaseIterable {
    case firstNarrow, finalNarrow, firstSnapshot, finalSnapshot
    case processID, parentProcessID, processGroupID, effectiveUserID
    case realUserID, savedUserID, realGroupID, effectiveGroupID, savedGroupID
    case snapshotAuditSession, zeroStartTime, invalidStartMicroseconds
    case zeroProcessIDVersion, zeroAuditSession, invalidAuditToken
    case auditUserID, supplementaryGroups
}

private enum InnerRoleMutation: CaseIterable {
    case valid, argumentCount, processID, parentProcessID, processGroupID
    case identity, fd0Open, fd1Open, fd7Open, fd2Closed
    case fd2CloseOnExec, fd8CloseOnExec, fd9CloseOnExec
    case fd2ReadOnly, fd8Closed, fd8NotDuplex, fd8NotSocket
    case fd8SocketEndpointsUnavailable, fd8NotUnix, fd8NotConnected
    case fd9Closed, fd9NotWriteOnly, noSigpipe8, noSigpipe9
    case descriptorNodeUnavailable, fd2NodeMismatch, fd8NotSocketNode
    case fd8AliasesStandardError, fd9NotPipe, fd9AliasesStandardError
    case fd9AliasesControl
    case standardErrorUnavailable, standardErrorDrift, invalidTTYForeground
}

private final class InnerRoleFixture: @unchecked Sendable {
    let identity: InvestigationMachineDarwinDriverChildIdentity
    let standardError = InvestigationMachineDarwinStandardErrorObservation(
        deviceID: 0, inode: 2, mode: mode_t(S_IFIFO) | 0o600,
        statusFlags: O_WRONLY,
        isTTY: false, foregroundProcessGroup: nil
    )
    let observer: RecordingDriverChildObserver
    let systemRecorder: InnerRoleSystemRecorder

    init(mutation: InnerRoleMutation) {
        identity = try! .init(
            processID: 42, processIDVersion: 7, parentProcessID: 21,
            processGroupID: 42, auditSessionID: 9, effectiveUserID: 0,
            auditTokenWords: [0, 0, 0, 0, 0, 42, 9, 7]
        )
        observer = RecordingDriverChildObserver(
            result: mutation == .identity
                ? .failure(.identityInvalid) : .success(identity)
        )
        systemRecorder = InnerRoleSystemRecorder(
            mutation: mutation, standardError: standardError
        )
    }

    func system() -> InvestigationMachineDarwinInnerRoleSystem {
        systemRecorder.system()
    }
}

private final class InnerRoleSystemRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private let mutation: InnerRoleMutation
    private let expectedStandardError:
        InvestigationMachineDarwinStandardErrorObservation
    private var standardErrorReads = 0

    init(
        mutation: InnerRoleMutation,
        standardError: InvestigationMachineDarwinStandardErrorObservation
    ) {
        self.mutation = mutation
        expectedStandardError = standardError
    }

    func system() -> InvestigationMachineDarwinInnerRoleSystem {
        .init(
            argumentCount: { self.mutation == .argumentCount ? 2 : 1 },
            currentProcessID: { self.mutation == .processID ? 43 : 42 },
            parentProcessID: {
                self.mutation == .parentProcessID ? 22 : 21
            },
            currentProcessGroup: {
                self.mutation == .processGroupID ? 43 : 42
            },
            descriptorFlags: { descriptor in
                let open: Bool
                switch descriptor {
                case 0: open = self.mutation == .fd0Open
                case 1: open = self.mutation == .fd1Open
                case 2: open = self.mutation != .fd2Closed
                case 7: open = self.mutation == .fd7Open
                case 8: open = self.mutation != .fd8Closed
                case 9: open = self.mutation != .fd9Closed
                default: open = false
                }
                guard open else { return .failure(.init(errno: EBADF)) }
                if descriptor == 2, self.mutation == .fd2CloseOnExec {
                    return .success(FD_CLOEXEC)
                }
                if descriptor == 8, self.mutation == .fd8CloseOnExec {
                    return .success(FD_CLOEXEC)
                }
                if descriptor == 9, self.mutation == .fd9CloseOnExec {
                    return .success(FD_CLOEXEC)
                }
                return .success(0)
            },
            descriptorStatusFlags: { descriptor in
                switch descriptor {
                case 2:
                    return .success(
                        self.mutation == .fd2ReadOnly ? O_RDONLY : O_WRONLY
                    )
                case 8:
                    return .success(
                        self.mutation == .fd8NotDuplex ? O_RDONLY : O_RDWR
                    )
                case 9:
                    return .success(
                        self.mutation == .fd9NotWriteOnly ? O_RDWR : O_WRONLY
                    )
                default:
                    return .failure(.init(errno: EBADF))
                }
            },
            noSigpipe: { descriptor in
                if descriptor == 8, self.mutation == .noSigpipe8 { return 0 }
                if descriptor == 9, self.mutation == .noSigpipe9 { return 0 }
                return 1
            },
            socketType: { descriptor in
                guard descriptor == 8 else {
                    return .failure(.init(errno: ENOTSOCK))
                }
                return .success(
                    self.mutation == .fd8NotSocket ? SOCK_DGRAM : SOCK_STREAM
                )
            },
            socketEndpoints: { descriptor in
                guard descriptor == 8,
                    self.mutation != .fd8SocketEndpointsUnavailable,
                    self.mutation != .fd8NotConnected
                else { return .failure(.init(errno: ENOTCONN)) }
                return .success(.init(
                    localFamily: self.mutation == .fd8NotUnix
                        ? sa_family_t(AF_INET) : sa_family_t(AF_UNIX),
                    peerFamily: sa_family_t(AF_UNIX)
                ))
            },
            descriptorNode: { descriptor in
                if self.mutation == .descriptorNodeUnavailable, descriptor == 8 {
                    return .failure(.init(errno: EIO))
                }
                let standardError =
                    InvestigationMachineDarwinDescriptorNodeObservation(
                        deviceID: 0, inode: 2, fileType: mode_t(S_IFIFO)
                    )
                switch descriptor {
                case 2:
                    return .success(
                        self.mutation == .fd2NodeMismatch
                            ? .init(
                                deviceID: 1, inode: 3,
                                fileType: mode_t(S_IFIFO)
                            )
                            : standardError
                    )
                case 8:
                    if self.mutation == .fd8AliasesStandardError {
                        return .success(standardError)
                    }
                    return .success(.init(
                        deviceID: 2, inode: 8,
                        fileType: self.mutation == .fd8NotSocketNode
                            ? mode_t(S_IFIFO) : mode_t(S_IFSOCK)
                    ))
                case 9:
                    if self.mutation == .fd9AliasesStandardError {
                        return .success(standardError)
                    }
                    if self.mutation == .fd9AliasesControl {
                        return .success(.init(
                            deviceID: 2, inode: 8, fileType: mode_t(S_IFSOCK)
                        ))
                    }
                    return .success(.init(
                        deviceID: 3, inode: 9,
                        fileType: self.mutation == .fd9NotPipe
                            ? mode_t(S_IFREG) : mode_t(S_IFIFO)
                    ))
                default:
                    return .failure(.init(errno: EBADF))
                }
            },
            standardErrorObservation: {
                try self.lock.withLock {
                    self.standardErrorReads += 1
                    if self.mutation == .standardErrorUnavailable {
                        throw OuterInnerSessionTestFailure.io
                    }
                    var value = self.expectedStandardError
                    if self.mutation == .standardErrorDrift,
                        self.standardErrorReads == 2
                    {
                        value = .init(
                            deviceID: value.deviceID, inode: value.inode + 1,
                            mode: value.mode, statusFlags: value.statusFlags,
                            isTTY: value.isTTY,
                            foregroundProcessGroup: value.foregroundProcessGroup
                        )
                    }
                    if self.mutation == .invalidTTYForeground {
                        value = .init(
                            deviceID: value.deviceID, inode: value.inode,
                            mode: value.mode, statusFlags: value.statusFlags,
                            isTTY: true, foregroundProcessGroup: nil
                        )
                    }
                    return value
                }
            }
        )
    }
}

private struct InvestigationMachineDarwinInnerRoleSystemError:
    Error, Sendable, Equatable
{
    let errno: Int32
}

private final class DriverChildObservationFixture: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var calls: [String] = []
    private var narrows: [InvestigationMachineDarwinDriverChildNarrowIdentity]
    private var snapshots: [InvestigationMachineDarwinDriverChildProcessSnapshot]

    let narrow = InvestigationMachineDarwinDriverChildNarrowIdentity(
        processID: 42, processIDVersion: 7, auditSessionID: 9,
        effectiveUserID: 0, auditTokenWords: [0, 0, 0, 0, 0, 42, 9, 7]
    )
    let snapshot = InvestigationMachineDarwinDriverChildProcessSnapshot(
        processID: 42, parentProcessID: 21, processGroupID: 42,
        effectiveUserID: 0, auditSessionID: 9,
        startTimeSeconds: 10, startTimeMicroseconds: 20
    )
    var expectedIdentity: InvestigationMachineDarwinDriverChildIdentity {
        try! .init(
            processID: 42, processIDVersion: 7, parentProcessID: 21,
            processGroupID: 42, auditSessionID: 9, effectiveUserID: 0,
            auditTokenWords: [0, 0, 0, 0, 0, 42, 9, 7]
        )
    }

    init(mutation: DriverChildObservationMutation? = nil) {
        var firstNarrow = narrow
        var finalNarrow = narrow
        var firstSnapshot = snapshot
        var finalSnapshot = snapshot
        switch mutation {
        case .firstNarrow:
            firstNarrow.processIDVersion += 1
        case .finalNarrow:
            finalNarrow.processIDVersion += 1
        case .firstSnapshot:
            firstSnapshot.startTimeMicroseconds += 1
        case .finalSnapshot:
            finalSnapshot.startTimeMicroseconds += 1
        case .processID:
            finalSnapshot.processID += 1
        case .parentProcessID:
            finalSnapshot.parentProcessID += 1
        case .processGroupID:
            finalSnapshot.processGroupID += 1
        case .effectiveUserID:
            finalSnapshot.effectiveUserID = 501
        case .realUserID:
            firstSnapshot.realUserID = 501
            finalSnapshot.realUserID = 501
        case .savedUserID:
            firstSnapshot.savedUserID = 501
            finalSnapshot.savedUserID = 501
        case .realGroupID:
            firstSnapshot.realGroupID = 20
            finalSnapshot.realGroupID = 20
        case .effectiveGroupID:
            firstSnapshot.effectiveGroupID = 20
            finalSnapshot.effectiveGroupID = 20
        case .savedGroupID:
            firstSnapshot.savedGroupID = 20
            finalSnapshot.savedGroupID = 20
        case .snapshotAuditSession:
            firstSnapshot.auditSessionID = 8
            finalSnapshot.auditSessionID = 8
        case .zeroStartTime:
            firstSnapshot.startTimeSeconds = 0
            finalSnapshot.startTimeSeconds = 0
        case .invalidStartMicroseconds:
            firstSnapshot.startTimeMicroseconds = 1_000_000
            finalSnapshot.startTimeMicroseconds = 1_000_000
        case .zeroProcessIDVersion:
            firstNarrow.processIDVersion = 0
            finalNarrow.processIDVersion = 0
        case .zeroAuditSession:
            firstNarrow.auditSessionID = 0
            finalNarrow.auditSessionID = 0
        case .invalidAuditToken:
            firstNarrow.auditTokenWords[5] = 41
            finalNarrow.auditTokenWords[5] = 41
        case .auditUserID:
            firstSnapshot.auditUserID = 501
            finalSnapshot.auditUserID = 501
        case .supplementaryGroups:
            firstSnapshot.supplementaryGroups = [1]
            finalSnapshot.supplementaryGroups = [1]
        case nil:
            break
        }
        narrows = [firstNarrow, finalNarrow]
        snapshots = [firstSnapshot, finalSnapshot]
    }

    func system() -> InvestigationMachineDarwinDriverChildIdentitySystem {
        .init(
            narrowIdentity: { processID in
                try self.lock.withLock {
                    self.calls.append("narrow:\(processID)")
                    guard !self.narrows.isEmpty else {
                        throw OuterInnerSessionTestFailure.io
                    }
                    return self.narrows.removeFirst()
                }
            },
            processSnapshot: { processID in
                try self.lock.withLock {
                    self.calls.append("snapshot:\(processID)")
                    guard !self.snapshots.isEmpty else {
                        throw OuterInnerSessionTestFailure.io
                    }
                    return self.snapshots.removeFirst()
                }
            }
        )
    }
}

private final class OuterInnerSessionFixture: @unchecked Sendable {
    let deadline: UInt64 = 10_000
    let system: OuterInnerSessionSystemRecorder
    let observer: RecordingDriverChildObserver
    let retirement = RecordingOuterInnerRetirementOwner()
    let driverIdentity: InvestigationMachineDarwinDriverChildIdentity

    init(
        control: InvestigationMachineDarwinOuterInnerDescriptorPair = .init(
            firstDescriptor: 3, secondDescriptor: 4
        ),
        result: InvestigationMachineDarwinOuterInnerDescriptorPair = .init(
            firstDescriptor: 5, secondDescriptor: 6
        ),
        duplicates: [Int32] = [10, 11, 12, 13],
        duplicateFailureAt: Int? = nil,
        observerFails: Bool = false
    ) {
        driverIdentity = try! .init(
            processID: 42, processIDVersion: 7, parentProcessID: 21,
            processGroupID: 42, auditSessionID: 9, effectiveUserID: 0,
            auditTokenWords: [0, 0, 0, 0, 0, 42, 9, 7]
        )
        system = OuterInnerSessionSystemRecorder(
            control: control, result: result, duplicates: duplicates,
            duplicateFailureAt: duplicateFailureAt
        )
        observer = RecordingDriverChildObserver(
            result: observerFails
                ? .failure(.identityInvalid) : .success(driverIdentity)
        )
    }

    func makeFactory() -> InvestigationMachineDarwinOuterInnerSessionFactory {
        .init(
            observer: observer, retirementOwner: retirement,
            system: system.system()
        )
    }
}

private final class RecordingDriverChildObserver:
    @unchecked Sendable, InvestigationMachineDarwinDriverChildObserving
{
    private let lock = NSLock()
    private let result: Result<
        InvestigationMachineDarwinDriverChildIdentity,
        InvestigationMachineDarwinDriverChildObservationError
    >
    private(set) var calls: [(UInt32, UInt32)] = []

    init(result: Result<
        InvestigationMachineDarwinDriverChildIdentity,
        InvestigationMachineDarwinDriverChildObservationError
    >) {
        self.result = result
    }

    func observe(
        processID: UInt32, expectedParentProcessID: UInt32
    ) throws -> InvestigationMachineDarwinDriverChildIdentity {
        lock.withLock { calls.append((processID, expectedParentProcessID)) }
        return try result.get()
    }
}

private final class RecordingOuterInnerRetirementOwner:
    @unchecked Sendable, InvestigationMachineDarwinEpochRetirementOwning
{
    private let lock = NSLock()
    private(set) var spawnedCalls = 0
    private(set) var ownedCalls = 0
    private(set) var spawned: InvestigationMachineDarwinSpawnedEpoch?
    private(set) var owned: InvestigationMachineDarwinOwnedEpoch?

    func retireSpawnedProcess(
        _ spawnedEpoch: InvestigationMachineDarwinSpawnedEpoch
    ) async throws {
        lock.withLock {
            spawnedCalls += 1
            spawned = spawnedEpoch
        }
    }

    func retireOwnedProcessGroup(
        _ ownedEpoch: InvestigationMachineDarwinOwnedEpoch
    ) async throws -> InvestigationMachineSingleEpochRetirementProof {
        lock.withLock {
            ownedCalls += 1
            owned = ownedEpoch
        }
        return .init()
    }
}

private final class OuterInnerSessionSystemRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private let control: InvestigationMachineDarwinOuterInnerDescriptorPair
    private let result: InvestigationMachineDarwinOuterInnerDescriptorPair
    private var duplicateValues: [Int32]
    private let duplicateFailureAt: Int?
    private var duplicateIndex = 0
    private(set) var duplicates: [(old: Int32, new: Int32)] = []
    private(set) var closeOnExec: [Int32] = []
    private(set) var noSigpipe: [Int32] = []
    private(set) var closed: [Int32] = []
    private(set) var spawnRequest: InvestigationMachineDarwinOuterInnerSpawnRequest?
    private(set) var spawnCount = 0
    private(set) var standardErrorObservations:
        [InvestigationMachineDarwinStandardErrorObservation] = []

    init(
        control: InvestigationMachineDarwinOuterInnerDescriptorPair,
        result: InvestigationMachineDarwinOuterInnerDescriptorPair,
        duplicates: [Int32], duplicateFailureAt: Int?
    ) {
        self.control = control
        self.result = result
        duplicateValues = duplicates
        self.duplicateFailureAt = duplicateFailureAt
    }

    func system() -> InvestigationMachineDarwinOuterInnerSessionSystem {
        .init(
            currentProcessID: { 21 }, currentProcessGroup: { 20 },
            continuousNanoseconds: { 1 },
            standardErrorObservation: {
                let value = InvestigationMachineDarwinStandardErrorObservation(
                    deviceID: 1, inode: 2, mode: 0o600, statusFlags: O_WRONLY,
                    isTTY: false, foregroundProcessGroup: nil
                )
                self.lock.withLock { self.standardErrorObservations.append(value) }
                return value
            },
            socketPair: { self.control }, pipe: { self.result },
            duplicateCloseOnExec: { old, minimum in
                try self.lock.withLock {
                    let index = self.duplicateIndex
                    self.duplicateIndex += 1
                    if self.duplicateFailureAt == index {
                        throw OuterInnerSessionTestFailure.io
                    }
                    guard !self.duplicateValues.isEmpty else {
                        throw OuterInnerSessionTestFailure.io
                    }
                    let value = self.duplicateValues.removeFirst()
                    self.duplicates.append((old, value))
                    #expect(value >= minimum)
                    return value
                }
            },
            setCloseOnExec: { descriptor in
                self.lock.withLock { self.closeOnExec.append(descriptor) }
            },
            setNoSigpipe: { descriptor in
                self.lock.withLock { self.noSigpipe.append(descriptor) }
            },
            descriptorFlags: { _ in FD_CLOEXEC },
            noSigpipe: { _ in 1 },
            descriptorStatusFlags: { descriptor in
                if descriptor == 12 || descriptor == self.result.firstDescriptor {
                    return O_RDONLY
                }
                if descriptor == 13 || descriptor == self.result.secondDescriptor {
                    return O_WRONLY
                }
                return O_RDWR
            },
            socketType: { _ in SOCK_STREAM },
            closeDescriptor: { descriptor in
                self.lock.withLock { self.closed.append(descriptor) }
            },
            spawn: { request in
                self.lock.withLock {
                    self.spawnCount += 1
                    self.spawnRequest = request
                }
                return 42
            },
            messageSystem: MessageIORecorder().system()
        )
    }
}

private final class MessageIORecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var reads: [Data]
    private var upToOne: [Data]
    private let gate: MessageIOGate?
    private(set) var writes: [Data] = []

    init(
        reads: [Data] = [], upToOne: [Data] = [], gate: MessageIOGate? = nil
    ) {
        self.reads = reads
        self.upToOne = upToOne
        self.gate = gate
    }

    func system() -> InvestigationMachineDarwinBoundedMessageSystem {
        .init(
            readExactly: { _, count, _ in
                try self.lock.withLock {
                    guard !self.reads.isEmpty else {
                        throw OuterInnerSessionTestFailure.io
                    }
                    let value = self.reads.removeFirst()
                    guard value.count == count else {
                        throw OuterInnerSessionTestFailure.io
                    }
                    return value
                }
            },
            readUpToOne: { _, _ in
                if let gate = self.gate { await gate.blockOnce() }
                return try self.lock.withLock {
                    guard !self.upToOne.isEmpty else {
                        throw OuterInnerSessionTestFailure.io
                    }
                    return self.upToOne.removeFirst()
                }
            },
            writeExactly: { _, data, _ in
                self.lock.withLock { self.writes.append(data) }
            }
        )
    }
}

private actor MessageIOGate {
    private var entered = false
    private var opened = false
    private var blocked = false
    private var enteredWaiters: [CheckedContinuation<Void, Never>] = []
    private var openWaiters: [CheckedContinuation<Void, Never>] = []

    func blockOnce() async {
        guard !blocked else { return }
        blocked = true
        entered = true
        enteredWaiters.forEach { $0.resume() }
        enteredWaiters.removeAll()
        guard !opened else { return }
        await withCheckedContinuation { openWaiters.append($0) }
    }

    func waitUntilEntered() async {
        guard !entered else { return }
        await withCheckedContinuation { enteredWaiters.append($0) }
    }

    func open() {
        opened = true
        openWaiters.forEach { $0.resume() }
        openWaiters.removeAll()
    }
}

private enum OuterInnerSessionTestFailure: Error {
    case io
}

private func physicalDescriptorSet() throws
    -> InvestigationMachineDarwinOuterInnerDescriptorSet
{
    var control = [Int32](repeating: -1, count: 2)
    var result = [Int32](repeating: -1, count: 2)
    guard
        socketpair(AF_UNIX, SOCK_STREAM, 0, &control) == 0,
        pipe(&result) == 0
    else {
        control.filter { $0 >= 0 }.forEach { _ = Darwin.close($0) }
        result.filter { $0 >= 0 }.forEach { _ = Darwin.close($0) }
        throw OuterInnerSessionTestFailure.io
    }
    var relocated: [Int32] = []
    do {
        for descriptor in control + result {
            let value = fcntl(descriptor, F_DUPFD_CLOEXEC, 10)
            guard value >= 10 else { throw OuterInnerSessionTestFailure.io }
            guard fcntl(value, F_SETNOSIGPIPE, 1) == 0 else {
                _ = Darwin.close(value)
                throw OuterInnerSessionTestFailure.io
            }
            relocated.append(value)
        }
        for descriptor in control + result {
            guard Darwin.close(descriptor) == 0 else {
                throw OuterInnerSessionTestFailure.io
            }
        }
        return .init(
            outerControlDescriptor: relocated[0],
            innerControlSourceDescriptor: relocated[1],
            outerResultDescriptor: relocated[2],
            innerResultSourceDescriptor: relocated[3]
        )
    } catch {
        relocated.forEach { _ = Darwin.close($0) }
        (control + result).forEach { _ = Darwin.close($0) }
        throw error
    }
}

private func compileOuterInnerPhysicalChildFixture() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appending(
        path: "stornaut-outer-inner-session-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: directory, withIntermediateDirectories: false
    )
    let source = directory.appending(path: "child.c")
    let executable = directory.appending(path: "child")
    try Data(
        #"""
        #include <errno.h>
        #include <fcntl.h>
        #include <stdint.h>
        #include <stdlib.h>
        #include <string.h>
        #include <sys/socket.h>
        #include <sys/stat.h>
        #include <unistd.h>
        static int read_exact(int fd, void *buffer, size_t count) {
          size_t offset = 0;
          while (offset < count) {
            ssize_t value = read(fd, (unsigned char *)buffer + offset, count - offset);
            if (value < 0 && errno == EINTR) continue;
            if (value <= 0) return 0;
            offset += (size_t)value;
          }
          return 1;
        }
        static int write_frame(int fd, const char *bytes, uint32_t count) {
          unsigned char header[4] = {
            (unsigned char)(count >> 24), (unsigned char)(count >> 16),
            (unsigned char)(count >> 8), (unsigned char)count
          };
          return write(fd, header, 4) == 4 && write(fd, bytes, count) == count;
        }
        int main(int argc, char **argv, char **envp) {
          if (argc != 1 || argv[0] == NULL || envp[0] != NULL) return 41;
          if (getppid() <= 1 || getpgrp() != getpid()) return 42;
          int type = 0; socklen_t length = sizeof(type);
          int stderr_flags = fcntl(2, F_GETFL);
          if (stderr_flags < 0 ||
              ((stderr_flags & O_ACCMODE) != O_WRONLY &&
               (stderr_flags & O_ACCMODE) != O_RDWR)) return 43;
          if ((fcntl(2, F_GETFD) & FD_CLOEXEC) != 0 ||
              (fcntl(8, F_GETFD) & FD_CLOEXEC) != 0 ||
              (fcntl(9, F_GETFD) & FD_CLOEXEC) != 0) return 56;
          if (getsockopt(8, SOL_SOCKET, SO_TYPE, &type, &length) != 0 ||
              type != SOCK_STREAM ||
              (fcntl(8, F_GETFL) & O_ACCMODE) != O_RDWR) return 44;
          if ((fcntl(9, F_GETFL) & O_ACCMODE) != O_WRONLY) return 45;
          if (fcntl(8, F_GETNOSIGPIPE) != 1 || fcntl(9, F_GETNOSIGPIPE) != 1)
            return 52;
          struct stat stderr_node, control_node, result_node;
          if (fstat(2, &stderr_node) != 0 || fstat(8, &control_node) != 0 ||
              fstat(9, &result_node) != 0) return 53;
          if ((control_node.st_mode & S_IFMT) != S_IFSOCK ||
              (result_node.st_mode & S_IFMT) != S_IFIFO) return 54;
          if ((stderr_node.st_dev == control_node.st_dev &&
               stderr_node.st_ino == control_node.st_ino) ||
              (stderr_node.st_dev == result_node.st_dev &&
               stderr_node.st_ino == result_node.st_ino) ||
              (control_node.st_dev == result_node.st_dev &&
               control_node.st_ino == result_node.st_ino)) return 55;
          for (int fd = 0; fd < 32; fd++) {
            if (fd == 2 || fd == 8 || fd == 9) continue;
            errno = 0;
            if (fcntl(fd, F_GETFD) >= 0 || errno != EBADF) return 46;
          }
          unsigned char header[4];
          if (!read_exact(8, header, sizeof(header))) return 47;
          uint32_t count = ((uint32_t)header[0] << 24) |
            ((uint32_t)header[1] << 16) | ((uint32_t)header[2] << 8) | header[3];
          unsigned char body[4];
          if (count != 4 || !read_exact(8, body, 4) || memcmp(body, "PING", 4))
            return 48;
          if (!write_frame(8, "PONG", 4)) return 49;
          if (!write_frame(9, "RESULT", 6)) return 50;
          if (shutdown(8, SHUT_WR) != 0) return 51;
          close(9);
          return 0;
        }
        """#.utf8
    ).write(to: source, options: .withoutOverwriting)
    let compiler = Process()
    compiler.executableURL = URL(filePath: "/usr/bin/xcrun")
    compiler.arguments = [
        "clang", "-std=c11", "-Wall", "-Wextra", "-Werror",
        source.path, "-o", executable.path,
    ]
    compiler.standardOutput = FileHandle.nullDevice
    compiler.standardError = FileHandle.nullDevice
    try compiler.run()
    compiler.waitUntilExit()
    guard compiler.terminationStatus == 0 else {
        throw OuterInnerSessionTestFailure.io
    }
    return executable
}
