import Darwin
import Foundation
import Testing
@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationMachineDriverSupport

@Suite("Investigation machine Darwin epoch session", .serialized)
struct InvestigationMachineDarwinEpochSessionTests {
    @Test func fixedFDAndSpawnContractAreExact() async throws {
        let recorder = StartRecorder()
        let owner = TestRetirementOwner()
        let factory = TestFixture.factory(recorder: recorder, owner: owner)
        let outcome = await factory.start(bootstrap: TestFixture.bootstrap)
        guard case .started = outcome else { Issue.record("not started"); return }
        let request = try #require(recorder.spawnRequest)
        #expect(request.childTargetDescriptor == 7)
        #expect(request.parentDescriptor == 3)
        #expect(request.childDescriptor == 4)
        #expect(request.parentDescriptor != request.childDescriptor)
        #expect(
            request.executablePath
                == "/Library/Application Support/Stornaut/"
                    + "Stornaut-R5-Diagnostic.app/Contents/MacOS/"
                    + "StornautInvestigationDiagnostic"
        )
        #expect(request.arguments == [request.executablePath])
        #expect(request.environment.isEmpty)
        #expect(request.flags == InvestigationMachineDarwinEpochSessionFactory.spawnFlags)
        #expect(recorder.closed.contains(7) == false)
    }

    @Test func reservedDescriptorsRelocateAndCloseOriginals() async throws {
        let recorder = StartRecorder()
        let factory = TestFixture.factory(recorder: recorder, channels: .init(parentDescriptor: 7, childDescriptor: 3))
        _ = await factory.start(bootstrap: TestFixture.bootstrap)
        #expect(recorder.duplicated == [7])
        #expect(Set(recorder.closed).isSuperset(of: [7, 3]))
    }

    @Test func preSpawnCloseFailureIsUncertain() async throws {
        let recorder = StartRecorder(closeFailure: [7])
        let factory = TestFixture.factory(recorder: recorder, channels: .init(parentDescriptor: 7, childDescriptor: 8))
        let outcome = await factory.start(bootstrap: TestFixture.bootstrap)
        guard case .terminalUncertain = outcome else { Issue.record("expected uncertain"); return }
        #expect(recorder.spawnRequest == nil)
    }

    @Test func invalidProcessGroupRetiresExactlyOnceAndIsUncertainOnRetirementFailure() async throws {
        let recorder = StartRecorder(processGroup: 99)
        let owner = TestRetirementOwner(shouldFail: true)
        let factory = TestFixture.factory(recorder: recorder, owner: owner)
        let outcome = await factory.start(bootstrap: TestFixture.bootstrap)
        guard case .terminalUncertain = outcome else { Issue.record("expected uncertain"); return }
        #expect(owner.calls == 1)
        #expect(owner.spawned?.processID == 42)
        #expect(owner.owned == nil)
    }

    @Test func invalidProcessGroupRetiresExactlyOnceWhenRetirementSucceeds() async throws {
        let recorder = StartRecorder(processGroup: 99)
        let owner = TestRetirementOwner()
        let factory = TestFixture.factory(recorder: recorder, owner: owner)
        let outcome = await factory.start(bootstrap: TestFixture.bootstrap)
        guard case .terminal = outcome else { Issue.record("expected terminal"); return }
        #expect(owner.calls == 1)
    }

    @Test func bootstrapWriteFailureRetiresOnce() async throws {
        let recorder = StartRecorder(writeFailure: true)
        let owner = TestRetirementOwner()
        let factory = TestFixture.factory(recorder: recorder, owner: owner)
        let outcome = await factory.start(bootstrap: TestFixture.bootstrap)
        guard case .terminal = outcome else { Issue.record("expected terminal"); return }
        #expect(owner.calls == 1)
    }

    @Test func invalidSpawnPIDClosesChannelsAndRemainsUncertain() async throws {
        let recorder = StartRecorder(spawnProcessID: 0)
        let outcome = await TestFixture.factory(recorder: recorder)
            .start(bootstrap: TestFixture.bootstrap)
        guard case .terminalUncertain = outcome else {
            Issue.record("expected terminal uncertainty")
            return
        }
        #expect(Set(recorder.closed).isSuperset(of: [3, 4]))
    }

    @Test func factoryIsConsumedAfterFirstStart() async throws {
        let recorder = StartRecorder()
        let factory = TestFixture.factory(recorder: recorder)
        _ = await factory.start(bootstrap: TestFixture.bootstrap)
        let second = await factory.start(bootstrap: TestFixture.bootstrap)
        guard case .terminalUncertain = second else { Issue.record("expected terminal uncertain"); return }
        #expect(recorder.spawnCount == 1)
    }

    @Test func physicalSocketPairEmptyEOFAndTrailingByteAreDistinguished() async throws {
        var fds: [Int32] = [-1, -1]
        #expect(socketpair(AF_UNIX, SOCK_STREAM, 0, &fds) == 0)
        defer { close(fds[0]); close(fds[1]) }
        shutdown(fds[1], SHUT_WR)
        let empty = try await InvestigationMachineDarwinEpochSessionSystem.system.readUpToOne(fds[0], UInt64.max)
        #expect(empty.isEmpty)

        var second: [Int32] = [-1, -1]
        #expect(socketpair(AF_UNIX, SOCK_STREAM, 0, &second) == 0)
        defer { close(second[0]); close(second[1]) }
        var byte: UInt8 = 0x7f
        #expect(send(second[1], &byte, 1, 0) == 1)
        let trailing = try await InvestigationMachineDarwinEpochSessionSystem.system.readUpToOne(second[0], UInt64.max)
        #expect(trailing == Data([0x7f]))
    }

    @Test func physicalIOHandlesFragmentsAndCancellation() async throws {
        var fds: [Int32] = [-1, -1]
        #expect(socketpair(AF_UNIX, SOCK_STREAM, 0, &fds) == 0)
        let readDescriptor = fds[0]
        let writeDescriptor = fds[1]
        defer { close(readDescriptor); close(writeDescriptor) }
        let now = try InvestigationMachineDarwinEpochSessionSystem.system
            .continuousNanoseconds()
        let deadlineResult = now.addingReportingOverflow(5_000_000_000)
        try #require(!deadlineResult.overflow)
        let deadline = deadlineResult.partialValue
        let reader = Task {
            try await InvestigationMachineDarwinEpochSessionSystem.system
                .readExactly(readDescriptor, 4, deadline)
        }
        var first = [UInt8](arrayLiteral: 1, 2)
        var second = [UInt8](arrayLiteral: 3, 4)
        #expect(send(writeDescriptor, &first, first.count, 0) == first.count)
        #expect(send(writeDescriptor, &second, second.count, 0) == second.count)
        #expect(try await reader.value == Data([1, 2, 3, 4]))

        try await InvestigationMachineDarwinEpochSessionSystem.system
            .writeExactly(readDescriptor, Data([5, 6, 7]), deadline)
        var received = [UInt8](repeating: 0, count: 3)
        #expect(
            recv(writeDescriptor, &received, received.count, 0)
                == received.count
        )
        #expect(received == [5, 6, 7])

        var cancelled: [Int32] = [-1, -1]
        #expect(socketpair(AF_UNIX, SOCK_STREAM, 0, &cancelled) == 0)
        let cancelledRead = cancelled[0]
        let cancelledWrite = cancelled[1]
        defer { close(cancelledRead); close(cancelledWrite) }
        let blocked = Task {
            try await InvestigationMachineDarwinEpochSessionSystem.system
                .readExactly(cancelledRead, 1, deadline)
        }
        await Task.yield()
        blocked.cancel()
        await #expect(throws: CancellationError.self) {
            _ = try await blocked.value
        }
    }

    @Test func physicalIORechecksDeadlineAfterCompletion() async throws {
        let zeroClock = TestClock([10])
        await #expect(
            throws: InvestigationMachineDarwinEpochSessionError.deadlineExceeded
        ) {
            _ = try await InvestigationMachineDarwinEpochPhysicalIO.readExactly(
                descriptor: -1, count: 0, deadlineNanoseconds: 10,
                clock: zeroClock.next
            )
        }

        var readPair: [Int32] = [-1, -1]
        try #require(socketpair(AF_UNIX, SOCK_STREAM, 0, &readPair) == 0)
        defer { close(readPair[0]); close(readPair[1]) }
        var byte: UInt8 = 1
        #expect(send(readPair[1], &byte, 1, 0) == 1)
        let readClock = TestClock([1, 2, 10])
        await #expect(
            throws: InvestigationMachineDarwinEpochSessionError.deadlineExceeded
        ) {
            _ = try await InvestigationMachineDarwinEpochPhysicalIO.readExactly(
                descriptor: readPair[0], count: 1, deadlineNanoseconds: 10,
                clock: readClock.next
            )
        }

        var writePair: [Int32] = [-1, -1]
        try #require(socketpair(AF_UNIX, SOCK_STREAM, 0, &writePair) == 0)
        defer { close(writePair[0]); close(writePair[1]) }
        let writeClock = TestClock([1, 2, 10])
        await #expect(
            throws: InvestigationMachineDarwinEpochSessionError.deadlineExceeded
        ) {
            try await InvestigationMachineDarwinEpochPhysicalIO.writeExactly(
                descriptor: writePair[0], data: Data([1]),
                deadlineNanoseconds: 10, clock: writeClock.next
            )
        }
    }

    @Test func fixedDescriptorSurfaceRemainsSeven() {
        #expect(InvestigationMachineDarwinEpochSessionFactory.fixedDescriptor == 7)
        #expect(InvestigationMachineDarwinEpochSessionFactory.minimumRelocatedDescriptor == 8)
    }

    @Test func productionSpawnPrimitiveMapsOnlyFDSeven() async throws {
        let fixtureURL = try compilePhysicalChildFixture()
        defer { try? FileManager.default.removeItem(
            at: fixtureURL.deletingLastPathComponent()
        ) }
        var descriptors: [Int32] = [-1, -1]
        try #require(socketpair(AF_UNIX, SOCK_STREAM, 0, &descriptors) == 0)
        let parent = descriptors[0]
        let child = descriptors[1]
        var childIsOpen = true
        defer {
            close(parent)
            if childIsOpen { close(child) }
        }
        let flags = Int16(
            POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT
        )
        let processID = try InvestigationMachineDarwinEpochSpawnPrimitive.spawn(
            .init(
                executablePath: fixtureURL.path,
                arguments: [fixtureURL.path], environment: [],
                parentDescriptor: parent, childDescriptor: child,
                childTargetDescriptor: 7, flags: flags
            )
        )
        #expect(getpgid(processID) == processID)
        #expect(processID != getpgrp())
        var reaped = false
        defer {
            if !reaped {
                _ = Darwin.kill(processID, SIGKILL)
                _ = waitpid(processID, nil, 0)
            }
        }
        try #require(close(child) == 0)
        childIsOpen = false
        let deadline = UInt64.max
        try await InvestigationMachineDarwinEpochSessionSystem.system
            .writeExactly(
                parent, Data(repeating: 0xa5, count: 32), deadline
            )
        let marker = try await InvestigationMachineDarwinEpochSessionSystem
            .system.readExactly(parent, 2, deadline)
        #expect(marker == Data("OK".utf8))
        let observedArgument = try await InvestigationMachineDarwinEpochSessionSystem
            .system.readExactly(
                parent, fixtureURL.path.utf8.count, deadline
            )
        #expect(observedArgument == Data(fixtureURL.path.utf8))
        #expect(
            try await InvestigationMachineDarwinEpochSessionSystem.system
                .readUpToOne(parent, deadline).isEmpty
        )
        try await InvestigationMachineDarwinEpochSessionSystem.system
            .writeExactly(parent, Data([0x7e]), deadline)
        var status: Int32 = 0
        while waitpid(processID, &status, 0) < 0 {
            if errno != EINTR { throw TestFailure.io }
        }
        reaped = true
        #expect(status == 0)
    }

    @Test func sessionRejectsPreDropReadyFromWrongSpawnedPID() async throws {
        let recorder = StartRecorder()
        let encoded = try TestFixture.frame(.preDropReady, sender: TestFixture.claim(99, 1, 0, 2))
        recorder.readChunks = [encoded.prefix(56), encoded.dropFirst(56)]
        let outcome = await TestFixture.factory(recorder: recorder)
            .start(bootstrap: TestFixture.bootstrap)
        guard case let .started(session) = outcome else { Issue.record("not started"); return }
        await #expect(throws: InvestigationMachineSingleEpochSessionError.identityMismatch) {
            _ = try await session.receive()
        }
    }

    @Test func kindSpecificPayloadBoundRejectsBeforePayloadRead() async throws {
        let recorder = StartRecorder()
        var encoded = try TestFixture.frame(
            .preDropReady, sender: TestFixture.preDropClaim
        )
        encoded.replaceSubrange(8..<12, with: [0, 0, 0, 1])
        recorder.readChunks = [Data(encoded.prefix(56))]
        let outcome = await TestFixture.factory(recorder: recorder)
            .start(bootstrap: TestFixture.bootstrap)
        let session = try #require(outcome.startedSession)
        await #expect(
            throws: InvestigationMachineDarwinEpochSessionError
                .transportUnavailable
        ) { _ = try await session.receive() }
        #expect(recorder.readRequests == [56])
    }

    @Test func wrongPhaseKindRejectsBeforeItsLargePayloadRead() async throws {
        let recorder = StartRecorder()
        var header = try TestFixture.outgoing(
            .configuration, .configuration(Data(repeating: 1, count: 65_536))
        ).encoded().prefix(56)
        header.replaceSubrange(32..<36, with: [0, 0, 0, 42])
        header.replaceSubrange(36..<40, with: [0, 0, 0, 7])
        header.replaceSubrange(40..<44, with: [0, 0, 0x01, 0xf5])
        header.replaceSubrange(44..<48, with: [0, 0, 0, 9])
        recorder.readChunks = [Data(header)]
        let outcome = await TestFixture.factory(recorder: recorder)
            .start(bootstrap: TestFixture.bootstrap)
        let session = try #require(outcome.startedSession)
        await #expect(
            throws: InvestigationMachineDarwinEpochSessionError
                .transportUnavailable
        ) { _ = try await session.receive() }
        #expect(recorder.readRequests == [56])
    }

    @Test func duplicateAndOutOfOrderOperationsBecomeTerminal() async throws {
        let recorder = StartRecorder()
        let outcome = await TestFixture.factory(recorder: recorder)
            .start(bootstrap: TestFixture.bootstrap)
        guard case let .started(session) = outcome else { Issue.record("not started"); return }
        await #expect(throws: InvestigationMachineDarwinEpochSessionError.self) {
            try await session.send(try TestFixture.handoffFrame(.dropRelease, sender: TestFixture.driverClaim))
        }
        await #expect(throws: InvestigationMachineDarwinEpochSessionError.self) {
            _ = try await session.receive()
        }
    }

    @Test func concurrentReceivePermanentlyConsumesTheSession() async throws {
        let gate = TestAsyncGate()
        let recorder = StartRecorder(readGate: gate)
        let encoded = try TestFixture.frame(
            .preDropReady, sender: TestFixture.preDropClaim
        )
        recorder.readChunks = [
            Data(encoded.prefix(56)), Data(encoded.dropFirst(56)),
        ]
        let outcome = await TestFixture.factory(recorder: recorder)
            .start(bootstrap: TestFixture.bootstrap)
        let session = try #require(outcome.startedSession)
        let first = Task { try await session.receive() }
        await gate.waitUntilEntered()
        await #expect(
            throws: InvestigationMachineDarwinEpochSessionError.invalidState
        ) { _ = try await session.receive() }
        await gate.open()
        await #expect(
            throws: InvestigationMachineDarwinEpochSessionError.invalidState
        ) { _ = try await first.value }
        _ = try await session.retireAndReap()
    }

    @Test
    func concurrentInvalidCallCannotRetireBeforeInFlightIOCompletes() async throws {
        let gate = TestAsyncGate()
        let recorder = StartRecorder(readGate: gate)
        let owner = TestRetirementOwner()
        let encoded = try TestFixture.frame(
            .preDropReady, sender: TestFixture.preDropClaim
        )
        recorder.readChunks = [
            Data(encoded.prefix(56)), Data(encoded.dropFirst(56)),
        ]
        let outcome = await TestFixture.factory(
            recorder: recorder, owner: owner
        ).start(bootstrap: TestFixture.bootstrap)
        let session = try #require(outcome.startedSession)
        let first = Task { try await session.receive() }
        await gate.waitUntilEntered()

        await #expect(
            throws: InvestigationMachineDarwinEpochSessionError.invalidState
        ) { _ = try await session.receive() }
        await #expect(
            throws: InvestigationMachineDarwinEpochSessionError.alreadyConsumed
        ) { _ = try await session.retireAndReap() }
        #expect(owner.calls == 0)

        await gate.open()
        await #expect(
            throws: InvestigationMachineDarwinEpochSessionError.invalidState
        ) { _ = try await first.value }
        _ = try await session.retireAndReap()
        #expect(owner.calls == 1)
    }

    @Test func retirementIsExactlyOnceAndSecondCallIsRejected() async throws {
        let owner = TestRetirementOwner()
        let outcome = await TestFixture.factory(recorder: StartRecorder(), owner: owner)
            .start(bootstrap: TestFixture.bootstrap)
        guard case let .started(session) = outcome else { Issue.record("not started"); return }
        _ = try await session.retireAndReap()
        await #expect(throws: InvestigationMachineDarwinEpochSessionError.alreadyConsumed) {
            _ = try await session.retireAndReap()
        }
        #expect(owner.calls == 1)
    }

    @Test func canonicalSessionUsesCachedThenFreshIdentityAndRetires() async throws {
        let recorder = StartRecorder()
        let owner = TestRetirementOwner()
        let identity = SessionIdentityObserver()
        recorder.readChunks = try TestFixture.incomingFrames.flatMap { frame in
            let bytes = try frame.encoded()
            return [Data(bytes.prefix(56)), Data(bytes.dropFirst(56))]
        }
        let outcome = await TestFixture.factory(
            recorder: recorder, owner: owner, identity: identity
        ).start(bootstrap: TestFixture.bootstrap)
        let session = try #require(outcome.startedSession)

        #expect(try await session.receive().kind == .preDropReady)
        try await session.send(try TestFixture.outgoing(.dropRelease))
        #expect(try await session.receive().kind == .dropEvidence)
        let first = try await session.observeCompletePostDropAppIdentity()
        #expect(identity.prepareCount == 1)
        #expect(identity.observeCount == 1)
        #expect(first == identity.appObservation)

        try await session.send(
            try TestFixture.outgoing(
                .configuration, .configuration(Data([0x01]))
            )
        )
        #expect(
            try await session.receive().kind
                == .configurationAcknowledgement
        )
        #expect(try await session.receive().kind == .hello)
        #expect(try await session.receive().kind == .handle)
        try await session.send(
            try TestFixture.outgoing(
                .acknowledgement,
                .retirementHandleAcknowledgement(
                    .init(handleSHA256: TestFixture.digest(8))
                )
            )
        )
        try await session.send(try TestFixture.outgoing(.release))
        #expect(try await session.receive().kind == .alive)
        try await session.provePeerWriteEOF()
        let repeated = try await session.observeCompletePostDropAppIdentity()
        #expect(repeated == first)
        #expect(identity.observeCount == 2)
        try await session.send(try TestFixture.outgoing(.exit))
        _ = try await session.retireAndReap()

        #expect(owner.calls == 1)
        #expect(recorder.readChunks.isEmpty)
        let expectedWrites = try TestFixture.outgoingFrames.map {
            try $0.encoded()
        }
        #expect(Array(recorder.writes.dropFirst()) == expectedWrites)
    }

    @Test func trailingByteAtPeerEOFFailsAndStillRetiresOnce() async throws {
        let recorder = StartRecorder(eof: Data([0x7f]))
        let owner = TestRetirementOwner()
        let identity = SessionIdentityObserver()
        recorder.readChunks = try TestFixture.incomingFrames.flatMap { frame in
            let bytes = try frame.encoded()
            return [Data(bytes.prefix(56)), Data(bytes.dropFirst(56))]
        }
        let outcome = await TestFixture.factory(
            recorder: recorder, owner: owner, identity: identity
        ).start(bootstrap: TestFixture.bootstrap)
        let session = try #require(outcome.startedSession)
        _ = try await session.receive()
        try await session.send(try TestFixture.outgoing(.dropRelease))
        _ = try await session.receive()
        _ = try await session.observeCompletePostDropAppIdentity()
        try await session.send(
            try TestFixture.outgoing(
                .configuration, .configuration(Data([0x01]))
            )
        )
        _ = try await session.receive()
        _ = try await session.receive()
        _ = try await session.receive()
        try await session.send(
            try TestFixture.outgoing(
                .acknowledgement,
                .retirementHandleAcknowledgement(
                    .init(handleSHA256: TestFixture.digest(8))
                )
            )
        )
        try await session.send(try TestFixture.outgoing(.release))
        _ = try await session.receive()
        await #expect(
            throws: InvestigationMachineDarwinEpochSessionError.invalidState
        ) { try await session.provePeerWriteEOF() }
        _ = try await session.retireAndReap()
        #expect(owner.calls == 1)
        #expect(identity.observeCount == 1)
    }
}

private final class StartRecorder: @unchecked Sendable {
    private let lock = NSLock()
    var channels: InvestigationMachineDarwinEpochChannel
    var closeFailure: Set<Int32>
    var processGroupValue: Int32
    var writeFailure: Bool
    var spawnProcessID: Int32
    var readChunks: [Data] = []
    var eof: Data
    let readGate: TestAsyncGate?
    private(set) var writes: [Data] = []
    private(set) var spawnRequest: InvestigationMachineDarwinEpochSpawnRequest?
    private(set) var spawnCount = 0
    private(set) var duplicated: [Int32] = []
    private(set) var closed: [Int32] = []
    private(set) var readRequests: [Int] = []
    init(channels: InvestigationMachineDarwinEpochChannel = .init(parentDescriptor: 3, childDescriptor: 4), closeFailure: Set<Int32> = [], processGroup: Int32 = 42, writeFailure: Bool = false, spawnProcessID: Int32 = 42, eof: Data = Data(), readGate: TestAsyncGate? = nil) {
        self.channels = channels; self.closeFailure = closeFailure; processGroupValue = processGroup; self.writeFailure = writeFailure; self.spawnProcessID = spawnProcessID; self.eof = eof; self.readGate = readGate
    }
    func system() -> InvestigationMachineDarwinEpochSessionSystem {
        .init(
            currentDriverClaim: { TestFixture.driverClaim },
            socketPair: { self.channels },
            duplicateCloseOnExec: { old, _ in self.lock.withLock { self.duplicated.append(old) }; return old == 7 ? 8 : 9 },
            setCloseOnExec: { _ in },
            closeDescriptor: { fd in try self.close(fd) },
            spawn: { request in self.lock.withLock { self.spawnRequest = request; self.spawnCount += 1 }; return self.spawnProcessID },
            processGroup: { _ in self.processGroupValue },
            currentProcessGroup: { 21 },
            continuousNanoseconds: { DispatchTime.now().uptimeNanoseconds },
            readExactly: { _, count, _ in
                if let gate = self.readGate { await gate.blockOnce() }
                return try self.lock.withLock {
                    self.readRequests.append(count)
                    guard !self.readChunks.isEmpty else { throw TestFailure.io }
                    let data = self.readChunks.removeFirst()
                    guard data.count == count else { throw TestFailure.io }
                    return data
                }
            },
            readUpToOne: { _, _ in self.eof },
            writeExactly: { _, data, _ in
                try self.lock.withLock {
                    if self.writeFailure { throw TestFailure.io }
                    self.writes.append(data)
                }
            }
        )
    }
    private func close(_ fd: Int32) throws { lock.withLock { closed.append(fd) }; if closeFailure.contains(fd) { throw TestFailure.io } }
}

private final class TestRetirementOwner: @unchecked Sendable, InvestigationMachineDarwinEpochRetirementOwning {
    private let lock = NSLock()
    let shouldFail: Bool
    private(set) var calls = 0
    private(set) var spawned: InvestigationMachineDarwinSpawnedEpoch?
    private(set) var owned: InvestigationMachineDarwinOwnedEpoch?
    init(shouldFail: Bool = false) { self.shouldFail = shouldFail }
    func retireSpawnedProcess(
        _ spawnedEpoch: InvestigationMachineDarwinSpawnedEpoch
    ) async throws -> InvestigationMachineSingleEpochRetirementProof {
        lock.withLock {
            calls += 1
            spawned = spawnedEpoch
        }
        if shouldFail { throw TestFailure.retirement }
        return .init()
    }
    func retireOwnedProcessGroup(_ ownedEpoch: InvestigationMachineDarwinOwnedEpoch) async throws -> InvestigationMachineSingleEpochRetirementProof {
        lock.withLock { calls += 1; owned = ownedEpoch }
        if shouldFail { throw TestFailure.retirement }
        return .init()
    }
}

private enum TestFailure: Error { case io, retirement }

private enum TestFixture {
    static let bootstrap = try! InvestigationHandoffEpochBootstrap(epochUUID: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!, epochDeadlineNanoseconds: DispatchTime.now().uptimeNanoseconds + 10_000_000_000)
    static let driverClaim = try! InvestigationHandoffProcessClaim(processID: 21, processIDVersion: 1, effectiveUserID: 0, auditSessionID: 1)
    static let projection: InvestigationInstalledL2IdentityProjection = {
        try! .init(epochUUID: bootstrap.epochUUID, configurationNonce: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!, configurationValidBefore: .init(rawValue: 2_000_000_000_000_000), configurationSHA256: digest(1), signedRuntimeBindingSHA256: digest(2), appExecutableSHA256: digest(3), appBundleIdentifier: "com.eriklee.stornaut", helperExecutableSHA256: digest(4), helperServiceIdentifier: "com.eriklee.stornaut.lifecycle", machineDriverExecutableSHA256: digest(5), machineDriverSigningIdentifier: "com.eriklee.stornaut.investigation.machine-driver", machineDriverDesignatedRequirementSHA256: digest(6), machineDriverCodeDirectoryHash: Data(repeating: 7, count: 20), machineClaimServiceIdentifier: "com.eriklee.stornaut.lifecycle.machine-claim")
    }()
    static func digest(_ value: UInt8) -> InvestigationHandoffSHA256 { try! .init(rawBytes: Data(repeating: value, count: 32)) }
    static func claim(_ pid: UInt32, _ version: UInt32, _ uid: UInt32, _ asid: UInt32) throws -> InvestigationHandoffProcessClaim { try .init(processID: pid, processIDVersion: version, effectiveUserID: uid, auditSessionID: asid) }
    static func frame(_ kind: InvestigationHandoffFrameKind, sender: InvestigationHandoffProcessClaim) throws -> Data { try InvestigationHandoffFrame(kind: kind, epochUUID: bootstrap.epochUUID, epochDeadlineNanoseconds: bootstrap.epochDeadlineNanoseconds, sender: sender, payload: .empty).encoded() }
    static func handoffFrame(_ kind: InvestigationHandoffFrameKind, sender: InvestigationHandoffProcessClaim) throws -> InvestigationHandoffFrame { try .init(kind: kind, epochUUID: bootstrap.epochUUID, epochDeadlineNanoseconds: bootstrap.epochDeadlineNanoseconds, sender: sender, payload: .empty) }
    static let preDropClaim = try! claim(42, 7, 0, 9)
    static let postDropClaim = try! claim(42, 7, 501, 9)
    static let dropEvidence = try! InvestigationHandoffDropEvidence(
        realUserID: 501, effectiveUserID: 501, savedUserID: 501,
        realGroupID: 20, effectiveGroupID: 20, savedGroupID: 20,
        supplementaryGroups: Array(UInt32(1)...UInt32(15)) + [20],
        auditTokenWords: [501, 501, 20, 501, 20, 42, 9, 7],
        setuidRootErrno: 1, seteuidRootErrno: 1, setgidRootErrno: 1
    )
    static let acknowledgement = try! InvestigationHandoffConfigurationAcknowledgement(
        epochUUID: bootstrap.epochUUID, ordinal: 0,
        configurationNonce: projection.configurationNonce, scenario: .success,
        configurationSHA256: projection.configurationSHA256,
        signedRuntimeBindingSHA256: projection.signedRuntimeBindingSHA256
    )
    static let handle = try! InvestigationHandoffRetirementHandle(
        token: UUID(uuidString: "33333333-3333-4333-8333-333333333333")!,
        investigationUUID: projection.configurationNonce,
        retireOperationUUID: UUID(uuidString: "44444444-4444-4444-8444-444444444444")!,
        configurationSHA256: projection.configurationSHA256,
        validBefore: .init(rawValue: 2_000_000_000_000_000)
    )
    static let incomingFrames = [
        try! frameValue(.preDropReady, sender: preDropClaim),
        try! frameValue(.dropEvidence, sender: postDropClaim, payload: .dropEvidence(dropEvidence)),
        try! frameValue(.configurationAcknowledgement, sender: postDropClaim, payload: .configurationAcknowledgement(acknowledgement)),
        try! frameValue(.hello, sender: postDropClaim),
        try! frameValue(.handle, sender: postDropClaim, payload: .retirementHandle(handle)),
        try! frameValue(.alive, sender: postDropClaim),
    ]
    static let outgoingFrames = [
        try! outgoing(.dropRelease),
        try! outgoing(.configuration, .configuration(Data([0x01]))),
        try! outgoing(.acknowledgement, .retirementHandleAcknowledgement(.init(handleSHA256: digest(8)))),
        try! outgoing(.release),
        try! outgoing(.exit),
    ]
    static func frameValue(_ kind: InvestigationHandoffFrameKind, sender: InvestigationHandoffProcessClaim, payload: InvestigationHandoffFramePayload = .empty) throws -> InvestigationHandoffFrame {
        try .init(kind: kind, epochUUID: bootstrap.epochUUID, epochDeadlineNanoseconds: bootstrap.epochDeadlineNanoseconds, sender: sender, payload: payload)
    }
    static func outgoing(_ kind: InvestigationHandoffFrameKind, _ payload: InvestigationHandoffFramePayload = .empty) throws -> InvestigationHandoffFrame {
        try frameValue(kind, sender: driverClaim, payload: payload)
    }
    static func factory(recorder: StartRecorder, owner: TestRetirementOwner = TestRetirementOwner(), channels: InvestigationMachineDarwinEpochChannel? = nil, identity: any InvestigationMachineDarwinAppIdentityObserving = TestIdentityObserver()) -> InvestigationMachineDarwinEpochSessionFactory {
        if let channels { recorder.channels = channels }
        return .init(projection: projection, identityObserver: identity, retirementOwner: owner, system: recorder.system())
    }
}

private struct TestIdentityObserver: InvestigationMachineDarwinAppIdentityObserving {
    func prepareEpoch(processClaim: InvestigationHandoffProcessClaim, projection: InvestigationInstalledL2IdentityProjection) throws -> InvestigationMachineDarwinEpochPreparedAppIdentity {
        .init { _, _, _ in fatalError("not reached in factory tests") }
    }
}

private final class SessionIdentityObserver:
    @unchecked Sendable, InvestigationMachineDarwinAppIdentityObserving
{
    private let lock = NSLock()
    private(set) var prepareCount = 0
    private(set) var observeCount = 0
    let appObservation = InvestigationMachineSingleEpochAppObservation(
        identity: try! InvestigationMachineProcessIdentity(
            role: .app, processID: 42, processIDVersion: 7, auditSessionID: 9,
            effectiveUserID: 501,
            auditTokenWords: [501, 501, 20, 501, 20, 42, 9, 7]
        )
    )

    func prepareEpoch(
        processClaim: InvestigationHandoffProcessClaim,
        projection: InvestigationInstalledL2IdentityProjection
    ) throws -> InvestigationMachineDarwinEpochPreparedAppIdentity {
        lock.withLock { prepareCount += 1 }
        guard processClaim == TestFixture.preDropClaim else {
            throw TestFailure.io
        }
        return .init { claim, evidence, projection in
            self.lock.withLock { self.observeCount += 1 }
            guard
                claim == TestFixture.postDropClaim,
                evidence == TestFixture.dropEvidence,
                projection == TestFixture.projection
            else { throw TestFailure.io }
            return self.appObservation
        }
    }
}

private extension InvestigationMachineSingleEpochStartOutcome {
    var startedSession: (any InvestigationMachineSingleEpochSession)? {
        guard case let .started(session) = self else { return nil }
        return session
    }
}

private actor TestAsyncGate {
    private var entered = false
    private var opened = false
    private var didBlock = false
    private var enteredWaiters: [CheckedContinuation<Void, Never>] = []
    private var openWaiters: [CheckedContinuation<Void, Never>] = []

    func blockOnce() async {
        guard !didBlock else { return }
        didBlock = true
        entered = true
        enteredWaiters.forEach { $0.resume() }
        enteredWaiters.removeAll()
        if opened { return }
        await withCheckedContinuation { openWaiters.append($0) }
    }

    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { enteredWaiters.append($0) }
    }

    func open() {
        opened = true
        openWaiters.forEach { $0.resume() }
        openWaiters.removeAll()
    }
}

private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [UInt64]
    init(_ values: [UInt64]) { self.values = values }
    func next() throws -> UInt64 {
        try lock.withLock {
            guard !values.isEmpty else { throw TestFailure.io }
            return values.removeFirst()
        }
    }
}

private func compilePhysicalChildFixture() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appending(
        path: "stornaut-iib5biic-\(UUID().uuidString)",
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
        #include <stdlib.h>
        #include <string.h>
        #include <sys/socket.h>
        #include <unistd.h>
        int main(int argc, char **argv, char **envp) {
          if (argc != 1 || argv[0] == NULL || envp[0] != NULL) return 41;
          int type = 0; socklen_t length = sizeof(type);
          if (getsockopt(7, SOL_SOCKET, SO_TYPE, &type, &length) != 0 ||
              type != SOCK_STREAM) return 42;
          for (int fd = 0; fd < 32; fd++) {
            if (fd == 7) continue;
            errno = 0;
            if (fcntl(fd, F_GETFD) >= 0 || errno != EBADF) return 43;
          }
          unsigned char bootstrap[32]; size_t offset = 0;
          while (offset < sizeof(bootstrap)) {
            ssize_t count = read(7, bootstrap + offset, sizeof(bootstrap) - offset);
            if (count <= 0) return 44;
            offset += (size_t)count;
          }
          if (send(7, "OK", 2, 0) != 2) return 45;
          if (send(7, argv[0], strlen(argv[0]), 0) != (ssize_t)strlen(argv[0]))
            return 48;
          if (shutdown(7, SHUT_WR) != 0) return 46;
          unsigned char exit_byte = 0;
          if (read(7, &exit_byte, 1) != 1 || exit_byte != 0x7e) return 47;
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
    guard compiler.terminationStatus == 0 else { throw TestFailure.io }
    return executable
}
