import CryptoKit
import Darwin
import Foundation
import Testing

@testable import StornautInvestigationMachineGateSupport

@Suite("Investigation machine gate physical evidence", .serialized)
struct InvestigationMachineGatePhysicalTests {
    @Test
    func realSudoSuspendedChildRemainsContainedBeforeAnyCredentialPrompt() throws {
        try #require(geteuid() != 0)
        let report = try SuspendedSudoProbe.run()

        #expect(report.spawnStatus == 0)
        #expect(report.childProcessID > 1)
        #expect(report.firstIdentity == report.secondIdentity)
        #expect(report.firstIdentity == report.thirdIdentity)
        #expect(report.firstIdentity == nil)
        #expect(report.firstIdentityErrno == EPERM)
        #expect(report.secondIdentityErrno == EPERM)
        #expect(report.thirdIdentityErrno == EPERM)
        #expect(report.firstKernelIdentity == report.secondKernelIdentity)
        #expect(report.firstKernelIdentity == report.thirdKernelIdentity)
        #expect(report.firstKernelIdentity?.parentProcessID == report.gateProcessID)
        #expect(report.firstKernelIdentity?.processGroupID == report.recoveryProcessGroupID)
        #expect(report.firstKernelIdentity?.sessionID == report.coordinatorSessionID)
        #expect(report.initialWaitProcessID == report.childProcessID)
        #expect(report.rawInitialWaitStatus == 0x7f)
        #expect(report.gateJoinStatus == 0)
        #expect(report.gateJoinErrno == 0)
        #expect(report.gateProcessGroupAfterJoin == report.coordinatorProcessGroupID)
        #expect(report.childProcessGroupAfterJoin == report.recoveryProcessGroupID)
        #expect(report.childSessionAfterJoin == report.coordinatorSessionID)
        #expect(report.exactKillStatus == 0)
        #expect(report.exactKillErrno == 0)
        #expect(report.exactReapProcessID == report.childProcessID)
        #expect(report.exactReapStatus.map(PhysicalFixture.signaled) == SIGKILL)
        #expect(report.recoveryGroupMembersAfterReap.isEmpty)
        #expect(report.capturedOutputByteCount == 0)
        #expect(report.capturedTerminalByteCount == 0)
    }

    @Test
    func kernelProcessIdentityReadsSuspendedSetuidChildWhenProcPidinfoCannot()
        throws
    {
        try #require(geteuid() != 0)
        let observation = try ProductionKernelChildIdentityProbe.run()
        #expect(observation.procPIDInfoErrno == EPERM)
        #expect(observation.first == observation.second)
        #expect(observation.first.processID == observation.childProcessID)
        #expect(observation.first.parentProcessID == getpid())
        #expect(observation.first.processGroupID == getpgrp())
        #expect(observation.first.sessionID == getsid(0))
        #expect(observation.first.status == UInt32(SSTOP))
        #expect(observation.rawInitialWaitStatus == 0x7f)
        #expect(observation.exactReapStatus.map(PhysicalFixture.signaled) == SIGKILL)

        // If the numeric PID was immediately reused, the lifetime tuple must
        // differ; otherwise the reader must report that the child is absent.
        do {
            let replacement = try InvestigationMachineKernelChildIdentityReader
                .read(processID: observation.childProcessID)
            #expect(replacement.processID == observation.childProcessID)
            #expect(
                replacement.startSeconds != observation.first.startSeconds
                    || replacement.startMicroseconds
                        != observation.first.startMicroseconds
            )
        } catch let error as InvestigationMachineGateError {
            #expect(error == .invalidObservation)
        }
    }

    @Test
    func normalRecoveryGroupHandoffBindsDescriptorsAndRestoresTTY() throws {
        try #require(geteuid() != 0)
        let fixture = try PhysicalFixture.make()
        defer { fixture.remove() }
        let report: CoordinatorReport = try fixture.run(.normal)
        let gate = report.gate
        let child = gate.childObservation

        #expect(report.coordinatorProcessID == report.coordinatorProcessGroupID)
        #expect(report.coordinatorSessionID == report.coordinatorProcessID)
        #expect(report.recoveryProcessGroupID == report.gateProcessID)
        #expect(report.gateStoppedAfterPrepared)
        #expect(PhysicalFixture.exited(report.gateWaitStatus) == 0)
        #expect(report.foregroundAfterCompletion == report.coordinatorProcessID)
        #expect(gate.gateProcessID == report.gateProcessID)
        #expect(gate.gateCoordinatorProcessGroupID == report.coordinatorProcessID)
        #expect(gate.recoveryProcessGroupID == report.gateProcessID)
        #expect(gate.childIdentity.processID != gate.recoveryProcessGroupID)
        #expect(gate.childIdentity.parentProcessID == gate.gateProcessID)
        #expect(gate.childIdentity.processGroupID == gate.recoveryProcessGroupID)
        #expect(gate.childInitialStopStatus == 0x7f)
        #expect(child.identity == gate.childIdentity)
        let expectedArguments = InvestigationMachineFixedGateContract.arguments
        let expectedArgumentsSHA256 = PhysicalFixture.digest(
            PhysicalFixture.argumentTranscript(expectedArguments)
        )
        #expect(child.argumentCount == expectedArguments.count)
        #expect(child.argumentsSHA256 == expectedArgumentsSHA256)
        #expect(child.environmentCount == 0)
        #expect(child.inputNode == fixture.capsuleNode)
        #expect(child.initialInputOffset == 0)
        #expect(child.finalInputOffset == Int64(fixture.capsuleBytes.count))
        #expect(child.reachedEOF)
        #expect(child.inputSHA256 == PhysicalFixture.digest(fixture.capsuleBytes))
        #expect(child.descriptor7Errno == EBADF)
        #expect(child.descriptor8Errno == EBADF)
        #expect(child.descriptor9Errno == EBADF)
        #expect(
            try Data(contentsOf: fixture.childSpawnAttemptMarker)
                == PhysicalFixture.childSpawnAttemptMarkerBytes
        )
        #expect(
            report.coordinatorInitialTerminal.foregroundProcessGroupID
                == report.coordinatorProcessID
        )
        #expect(gate.initialTerminal.foregroundProcessGroupID == report.coordinatorProcessID)
        #expect(gate.childTerminal.foregroundProcessGroupID == gate.recoveryProcessGroupID)
        #expect(gate.finalTerminal.foregroundProcessGroupID == report.coordinatorProcessID)
        #expect(gate.initialTerminal.device == report.coordinatorInitialTerminal.device)
        #expect(gate.initialTerminal.inode == report.coordinatorInitialTerminal.inode)
        #expect(gate.childTerminal.device == report.coordinatorInitialTerminal.device)
        #expect(gate.childTerminal.inode == report.coordinatorInitialTerminal.inode)
        #expect(gate.finalTerminal.device == report.coordinatorInitialTerminal.device)
        #expect(gate.finalTerminal.inode == report.coordinatorInitialTerminal.inode)
        #expect(gate.outputByteCount > 0 && gate.outputByteCount <= 512)
        #expect(PhysicalFixture.exited(gate.childWaitStatus) == 0)
        #expect(gate.exactChildReaped)
        #expect(gate.recoveryGroupEmpty)
        #expect(gate.foregroundRestored)
        #expect(gate.inputClosed)
        #expect(InvestigationMachineFixedGateContract.environment.isEmpty)
    }

    @Test
    func invalidForegroundRecoveryTopologyRejectsBeforeChildSpawn() throws {
        try #require(geteuid() != 0)
        let fixture = try PhysicalFixture.make()
        defer { fixture.remove() }
        let report: TopologyRejectionReport = try fixture.run(.invalidTopology)

        #expect(report.coordinatorProcessID == report.coordinatorProcessGroupID)
        #expect(report.coordinatorSessionID == report.coordinatorProcessID)
        #expect(report.recoveryProcessGroupID == report.gateProcessID)
        #expect(report.gateInitialStopStatus == 0x7f)
        #expect(report.gatePinnedWaitable)
        let expectedRejection = Data(
            "stub-error: invalid fixture state: background gate invocation".utf8
        )
        #expect(report.firstObservedFrameByteCount == expectedRejection.count)
        #expect(
            report.firstObservedFrameSHA256
                == PhysicalFixture.digest(expectedRejection)
        )
        #expect(report.trailingByteCount == 0)
        #expect(report.trailingSHA256 == PhysicalFixture.digest(Data()))
        #expect(report.initialTerminal.foregroundProcessGroupID == report.coordinatorProcessID)
        #expect(
            report.invalidTerminal.foregroundProcessGroupID
                == report.recoveryProcessGroupID
        )
        #expect(report.finalTerminal.foregroundProcessGroupID == report.coordinatorProcessID)
        #expect(report.invalidTerminal.device == report.initialTerminal.device)
        #expect(report.invalidTerminal.inode == report.initialTerminal.inode)
        #expect(report.finalTerminal.device == report.initialTerminal.device)
        #expect(report.finalTerminal.inode == report.initialTerminal.inode)
        #expect(report.recoveryGroupMembersBeforeReap == [report.gateProcessID])
        #expect(PhysicalFixture.exited(report.gateWaitStatus) == 70)
        #expect(report.recoveryGroupMembersAfterReap.isEmpty)
        #expect(try PhysicalFixture.isAbsent(fixture.childSpawnAttemptMarker))
        #expect(!(try sessionExists(report.coordinatorSessionID)))
    }

    @Test(arguments: [SIGHUP, SIGINT, SIGQUIT, SIGTERM])
    func everyForwardedGroupSignalHasOneForwarderAndCoordinatorSurvives(
        _ signal: Int32
    ) throws {
        try #require(geteuid() != 0)
        let fixture = try PhysicalFixture.make(signal: signal)
        defer { fixture.remove() }
        let report: SignalCoordinatorReport = try fixture.run(.forwarded)
        let gate = report.gate

        #expect(report.deliveredSignal == signal)
        #expect(report.coordinatorConsumedSignal == signal)
        #expect(report.coordinatorSurvivedUntilGateReport)
        #expect(PhysicalFixture.exited(report.gateWaitStatus) == 0)
        #expect(report.recoveryProcessGroupID == report.gateProcessID)
        #expect(gate.forwardedSignal == signal)
        #expect(PhysicalFixture.signaled(gate.childWaitStatus) == signal)
        #expect(gate.childIdentity.processID != gate.recoveryProcessGroupID)
        #expect(gate.childIdentity.processGroupID == gate.recoveryProcessGroupID)
        #expect(gate.childIdentity.parentProcessID == gate.gateProcessID)
        #expect(gate.readyByte == 0x53)
        #expect(gate.exactChildReaped)
        #expect(gate.recoveryGroupEmpty)
        #expect(gate.foregroundRestored)
        #expect(gate.inputClosed)
        #expect(report.foregroundAfterCompletion == report.coordinatorProcessGroupID)
    }

    @Test
    func preFrameGateDeathUsesKnownRecoveryGroupAndReapsGateLast() throws {
        try #require(geteuid() != 0)
        let fixture = try PhysicalFixture.make(preFrameDeath: true)
        defer { fixture.remove() }
        let report: RecoveryReport = try fixture.run(.preFrameDeath)

        #expect(report.phase == "pre-frame")
        #expect(report.recoveryProcessGroupID == report.gateProcessID)
        #expect(report.childIdentity == nil)
        #expect(report.gatePinnedWaitable)
        #expect(!report.identityRevalidatedBeforeSignal)
        #expect(report.initialGroupMembers.contains(report.gateProcessID))
        #expect(report.initialGroupMembers.count >= 2)
        #expect(report.termSent)
        #expect(report.continueSent)
        #expect(report.gateReapedLast)
        #expect(report.recoveryGroupEmpty)
        #expect(report.foregroundRestored)
        #expect(report.foregroundAfterCompletion == report.coordinatorProcessGroupID)
    }

    @Test
    func postFrameGateDeathRevalidatesIdentityBeforeExactGroupSignals() throws {
        try #require(geteuid() != 0)
        let fixture = try PhysicalFixture.make(postFrameDeath: true)
        defer { fixture.remove() }
        let report: RecoveryReport = try fixture.run(.postFrameDeath)
        let child = try #require(report.childIdentity)

        #expect(report.phase == "post-frame")
        #expect(report.recoveryProcessGroupID == report.gateProcessID)
        #expect(child.parentProcessID == report.gateProcessID)
        #expect(child.processGroupID == report.recoveryProcessGroupID)
        #expect(child.processID != report.recoveryProcessGroupID)
        #expect(report.gatePinnedWaitable)
        #expect(report.identityRevalidatedBeforeSignal)
        #expect(report.termSent)
        #expect(report.continueSent)
        #expect(report.killSent)
        #expect(report.childDirectReapUnavailable)
        #expect(report.childDisappeared)
        #expect(report.gateReapedLast)
        #expect(report.recoveryGroupEmpty)
        #expect(report.foregroundRestored)
        #expect(report.foregroundAfterCompletion == report.coordinatorProcessGroupID)
    }
}

private struct SuspendedSudoProbeIdentity: Codable, Equatable {
    let processID: pid_t
    let parentProcessID: pid_t
    let processGroupID: pid_t
    let sessionID: pid_t
    let startSeconds: UInt64
    let startMicroseconds: UInt64
    let status: UInt32
}

private struct SuspendedSudoProbeReport: Codable {
    let coordinatorProcessID: pid_t
    let coordinatorProcessGroupID: pid_t
    let coordinatorSessionID: pid_t
    let gateProcessID: pid_t
    let recoveryProcessGroupID: pid_t
    let foregroundProcessGroupID: pid_t
    let spawnStatus: Int32
    let childProcessID: pid_t
    let firstIdentity: SuspendedSudoProbeIdentity?
    let firstIdentityErrno: Int32
    let secondIdentity: SuspendedSudoProbeIdentity?
    let secondIdentityErrno: Int32
    let firstKernelIdentity: SuspendedSudoProbeIdentity?
    let firstKernelIdentityErrno: Int32
    let secondKernelIdentity: SuspendedSudoProbeIdentity?
    let secondKernelIdentityErrno: Int32
    let initialWaitProcessID: pid_t
    let rawInitialWaitStatus: Int32?
    let thirdIdentity: SuspendedSudoProbeIdentity?
    let thirdIdentityErrno: Int32
    let thirdKernelIdentity: SuspendedSudoProbeIdentity?
    let thirdKernelIdentityErrno: Int32
    let gateJoinStatus: Int32
    let gateJoinErrno: Int32
    let gateProcessGroupAfterJoin: pid_t
    let childProcessGroupAfterJoin: pid_t
    let childSessionAfterJoin: pid_t
    let exactKillStatus: Int32
    let exactKillErrno: Int32
    let exactReapProcessID: pid_t
    let exactReapStatus: Int32?
    let recoveryGroupMembersAfterReap: [pid_t]
    let capturedOutputByteCount: Int
    let capturedTerminalByteCount: Int
    enum CodingKeys: String, CodingKey {
        case coordinatorProcessID, coordinatorProcessGroupID
        case coordinatorSessionID, gateProcessID, recoveryProcessGroupID
        case foregroundProcessGroupID, spawnStatus, childProcessID
        case firstIdentity, firstIdentityErrno, secondIdentity
        case secondIdentityErrno, firstKernelIdentity
        case firstKernelIdentityErrno, secondKernelIdentity
        case secondKernelIdentityErrno, initialWaitProcessID
        case rawInitialWaitStatus, thirdIdentity, thirdIdentityErrno
        case thirdKernelIdentity, thirdKernelIdentityErrno
        case gateJoinStatus, gateJoinErrno
        case gateProcessGroupAfterJoin, childProcessGroupAfterJoin
        case childSessionAfterJoin, exactKillStatus, exactKillErrno
        case exactReapProcessID, exactReapStatus
        case recoveryGroupMembersAfterReap, capturedOutputByteCount
        case capturedTerminalByteCount
    }
}

private enum SuspendedSudoProbe {
    static func run() throws -> SuspendedSudoProbeReport {
        let root = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = root.appending(
            path: "Tests/Fixtures/InvestigationMachineSuspendedSudoProbe/main.swift"
        )
        let directory = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-suspended-sudo-probe-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: false
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appending(path: "suspended-sudo-probe")
        let compiler = Process()
        compiler.executableURL = URL(filePath: "/usr/bin/xcrun")
        compiler.arguments = [
            "swiftc", "-parse-as-library", source.path, "-o", executable.path,
        ]
        compiler.environment = [:]
        let compilerError = Pipe()
        compiler.standardOutput = FileHandle.nullDevice
        compiler.standardError = compilerError
        try compiler.run()
        compiler.waitUntilExit()
        guard compiler.terminationStatus == 0 else {
            throw TestError.invalid(
                "suspended sudo probe compile failed: "
                    + String(
                        decoding: compilerError.fileHandleForReading.readDataToEndOfFile(),
                        as: UTF8.self
                    )
            )
        }

        var pipeFD: [Int32] = [-1, -1]
        guard pipe(&pipeFD) == 0 else { throw posix("probe result pipe") }
        defer {
            if pipeFD[0] >= 0 { _ = close(pipeFD[0]) }
            if pipeFD[1] >= 0 { _ = close(pipeFD[1]) }
        }
        try cloexec(pipeFD[0])
        try cloexec(pipeFD[1])
        var actions: posix_spawn_file_actions_t?
        guard posix_spawn_file_actions_init(&actions) == 0 else {
            throw TestError.invalid("probe actions init")
        }
        defer { posix_spawn_file_actions_destroy(&actions) }
        guard
            posix_spawn_file_actions_addinherit_np(&actions, STDIN_FILENO) == 0,
            posix_spawn_file_actions_adddup2(
                &actions, pipeFD[1], STDOUT_FILENO
            ) == 0,
            posix_spawn_file_actions_adddup2(
                &actions, pipeFD[1], STDERR_FILENO
            ) == 0,
            posix_spawn_file_actions_addclose(&actions, pipeFD[0]) == 0,
            posix_spawn_file_actions_addclose(&actions, pipeFD[1]) == 0
        else { throw TestError.invalid("probe actions") }
        var attributes: posix_spawnattr_t?
        guard posix_spawnattr_init(&attributes) == 0 else {
            throw TestError.invalid("probe attributes init")
        }
        defer { posix_spawnattr_destroy(&attributes) }
        guard posix_spawnattr_setflags(
            &attributes, Int16(POSIX_SPAWN_CLOEXEC_DEFAULT)
        ) == 0 else { throw TestError.invalid("probe attributes") }
        var processID: pid_t = 0
        let spawnStatus = try cStrings([executable.path]) { arguments in
            try cStrings([]) { environment in
                executable.path.withCString { path in
                    posix_spawn(
                        &processID, path, &actions, &attributes,
                        arguments, environment
                    )
                }
            }
        }
        guard spawnStatus == 0, processID > 1 else {
            throw TestError.posix("spawn suspended sudo probe", spawnStatus)
        }
        _ = close(pipeFD[1])
        pipeFD[1] = -1
        let deadline = try add(try now(), 8_000_000_000)
        var reaped = false
        defer {
            if !reaped {
                _ = kill(processID, SIGKILL)
            }
        }
        do {
            let data = try readExactProcessOutput(
                pipeFD[0], processID: processID, deadline: deadline
            )
            _ = close(pipeFD[0])
            pipeFD[0] = -1
            let status = try waitProcess(processID, deadline)
            reaped = true
            guard !(try sessionExists(processID)) else {
                throw TestError.invalid("suspended sudo probe session survived")
            }
            guard PhysicalFixture.exited(status) == 0 else {
                throw TestError.invalid(
                    "suspended sudo probe failed: "
                        + String(decoding: data, as: UTF8.self)
                )
            }
            return try JSONDecoder().decode(
                SuspendedSudoProbeReport.self, from: data
            )
        } catch {
            try killProbeSession(
                processID, try add(try now(), 2_000_000_000)
            )
            reaped = true
            throw error
        }
    }
}

private struct ProductionKernelChildIdentityObservation {
    let childProcessID: pid_t
    let procPIDInfoErrno: Int32
    let first: InvestigationMachineKernelChildIdentity
    let second: InvestigationMachineKernelChildIdentity
    let rawInitialWaitStatus: Int32
    let exactReapStatus: Int32?
}

private enum ProductionKernelChildIdentityProbe {
    static func run() throws -> ProductionKernelChildIdentityObservation {
        var output: [Int32] = [-1, -1]
        guard pipe(&output) == 0 else { throw posix("production probe pipe") }
        defer {
            if output[0] >= 0 { _ = close(output[0]) }
            if output[1] >= 0 { _ = close(output[1]) }
        }
        try cloexec(output[0])
        try cloexec(output[1])

        var actions: posix_spawn_file_actions_t?
        guard posix_spawn_file_actions_init(&actions) == 0 else {
            throw TestError.invalid("production probe actions init")
        }
        defer { posix_spawn_file_actions_destroy(&actions) }
        guard
            posix_spawn_file_actions_addinherit_np(
                &actions, STDIN_FILENO
            ) == 0,
            posix_spawn_file_actions_adddup2(
                &actions, output[1], STDOUT_FILENO
            ) == 0,
            posix_spawn_file_actions_addinherit_np(
                &actions, STDERR_FILENO
            ) == 0,
            posix_spawn_file_actions_addclose(&actions, output[0]) == 0,
            posix_spawn_file_actions_addclose(&actions, output[1]) == 0
        else { throw TestError.invalid("production probe actions") }

        var attributes: posix_spawnattr_t?
        guard posix_spawnattr_init(&attributes) == 0 else {
            throw TestError.invalid("production probe attributes init")
        }
        defer { posix_spawnattr_destroy(&attributes) }
        var childMask = sigset_t()
        var childDefaults = sigset_t()
        guard
            sigemptyset(&childMask) == 0,
            sigemptyset(&childDefaults) == 0,
            (InvestigationMachineFixedGateContract.forwardedSignals
                + [SIGTTOU, SIGTTIN, SIGTSTP, SIGPIPE]).allSatisfy({ signal in
                    sigaddset(&childDefaults, signal) == 0
                }),
            posix_spawnattr_setflags(
                &attributes,
                InvestigationMachineFixedGateContract.childSpawnFlags
            ) == 0,
            posix_spawnattr_setsigmask(&attributes, &childMask) == 0,
            posix_spawnattr_setsigdefault(&attributes, &childDefaults) == 0
        else { throw TestError.invalid("production probe attributes") }

        var child: pid_t = 0
        let spawnStatus = try cStrings(
            InvestigationMachineFixedGateContract.arguments
        ) { arguments in
            try cStrings(
                InvestigationMachineFixedGateContract.environment
            ) { environment in
                InvestigationMachineFixedGateContract.launcherPath.withCString {
                    posix_spawn(
                        &child, $0, &actions, &attributes, arguments, environment
                    )
                }
            }
        }
        guard spawnStatus == 0, child > 1 else {
            throw TestError.posix("production suspended sudo spawn", spawnStatus)
        }
        _ = close(output[1])
        output[1] = -1
        var reaped = false
        defer {
            if !reaped {
                _ = kill(child, SIGKILL)
                while waitpid(child, nil, 0) < 0, errno == EINTR {}
            }
        }

        var restricted = proc_bsdinfo()
        errno = 0
        let restrictedBytes = proc_pidinfo(
            child, PROC_PIDTBSDINFO, 0, &restricted,
            Int32(MemoryLayout<proc_bsdinfo>.size)
        )
        let restrictedErrno = restrictedBytes == 0 ? errno : 0
        let first = try InvestigationMachineKernelChildIdentityReader.read(
            processID: child
        )
        let second = try InvestigationMachineKernelChildIdentityReader.read(
            processID: child
        )
        let deadline = try add(try now(), 2_000_000_000)
        var initialStatus: Int32 = 0
        while true {
            let result = waitpid(child, &initialStatus, WUNTRACED | WNOHANG)
            if result == child { break }
            if result < 0, errno != EINTR { throw posix("production initial stop") }
            guard try now() < deadline else {
                throw TestError.timeout("production initial stop")
            }
            usleep(10_000)
        }
        guard kill(child, SIGKILL) == 0 else {
            throw posix("production exact child kill")
        }
        var terminalStatus: Int32 = 0
        while waitpid(child, &terminalStatus, 0) < 0 {
            if errno != EINTR { throw posix("production exact child reap") }
        }
        reaped = true
        return .init(
            childProcessID: child, procPIDInfoErrno: restrictedErrno,
            first: first, second: second,
            rawInitialWaitStatus: initialStatus,
            exactReapStatus: terminalStatus
        )
    }
}

private struct Node: Codable, Equatable {
    let device: UInt64
    let inode: UInt64
    let generation: UInt64
    let size: Int64

    enum CodingKeys: String, CodingKey {
        case device = "d"
        case inode = "i"
        case generation = "g"
        case size = "s"
    }
}

private struct TTY: Codable, Equatable {
    let device: UInt64
    let inode: UInt64
    let foregroundProcessGroupID: pid_t

    enum CodingKeys: String, CodingKey {
        case device = "d"
        case inode = "i"
        case foregroundProcessGroupID = "f"
    }
}

private struct Identity: Codable, Equatable {
    let processID: pid_t
    let parentProcessID: pid_t
    let processGroupID: pid_t
    let startSeconds: UInt64
    let startMicroseconds: UInt64

    enum CodingKeys: String, CodingKey {
        case processID = "p"
        case parentProcessID = "pp"
        case processGroupID = "pg"
        case startSeconds = "ss"
        case startMicroseconds = "su"
    }
}

private struct ChildObservation: Codable {
    let version: Int
    let argumentCount: Int
    let argumentsSHA256: String
    let environmentCount: Int
    let identity: Identity
    let inputNode: Node
    let initialInputOffset: Int64
    let finalInputOffset: Int64
    let reachedEOF: Bool
    let inputSHA256: String
    let terminal: TTY
    let descriptor7Errno: Int32
    let descriptor8Errno: Int32
    let descriptor9Errno: Int32

    enum CodingKeys: String, CodingKey {
        case version = "v"
        case argumentCount = "ac"
        case argumentsSHA256 = "ah"
        case environmentCount = "ec"
        case identity = "id"
        case inputNode = "in"
        case initialInputOffset = "io"
        case finalInputOffset = "fo"
        case reachedEOF = "e"
        case inputSHA256 = "ih"
        case terminal = "t"
        case descriptor7Errno = "e7"
        case descriptor8Errno = "e8"
        case descriptor9Errno = "e9"
    }
}

private struct GateReport: Codable {
    let gateProcessID: pid_t
    let gateCoordinatorProcessGroupID: pid_t
    let recoveryProcessGroupID: pid_t
    let childIdentity: Identity
    let childInitialStopStatus: Int32
    let capsule: Node
    let initialTerminal: TTY
    let childTerminal: TTY
    let finalTerminal: TTY
    let childObservation: ChildObservation
    let outputByteCount: Int
    let outputSHA256: String
    let childWaitStatus: Int32
    let exactChildReaped: Bool
    let recoveryGroupEmpty: Bool
    let foregroundRestored: Bool
    let inputClosed: Bool
}

private struct SignalGateReport: Codable {
    let gateProcessID: pid_t
    let gateCoordinatorProcessGroupID: pid_t
    let recoveryProcessGroupID: pid_t
    let childIdentity: Identity
    let childInitialStopStatus: Int32
    let capsule: Node
    let initialTerminal: TTY
    let childTerminal: TTY
    let finalTerminal: TTY
    let readyByte: UInt8
    let childWaitStatus: Int32
    let forwardedSignal: Int32
    let exactChildReaped: Bool
    let recoveryGroupEmpty: Bool
    let foregroundRestored: Bool
    let inputClosed: Bool
}

private struct CoordinatorReport: Codable {
    let coordinatorProcessID: pid_t
    let coordinatorProcessGroupID: pid_t
    let coordinatorSessionID: pid_t
    let recoveryProcessGroupID: pid_t
    let gateProcessID: pid_t
    let gateStoppedAfterPrepared: Bool
    let gateWaitStatus: Int32
    let foregroundAfterCompletion: pid_t
    let coordinatorInitialTerminal: TTY
    let gate: GateReport
}

private struct CoordinatorReady: Codable {
    let version: Int
    let processID: pid_t
    let processGroupID: pid_t
    let sessionID: pid_t
    let foregroundProcessGroupID: pid_t
}

private struct SignalCoordinatorReport: Codable {
    let coordinatorProcessGroupID: pid_t
    let recoveryProcessGroupID: pid_t
    let gateProcessID: pid_t
    let deliveredSignal: Int32
    let coordinatorConsumedSignal: Int32
    let coordinatorSurvivedUntilGateReport: Bool
    let gateWaitStatus: Int32
    let foregroundAfterCompletion: pid_t
    let gate: SignalGateReport
}

private struct RecoveryReport: Codable {
    let phase: String
    let coordinatorProcessGroupID: pid_t
    let recoveryProcessGroupID: pid_t
    let gateProcessID: pid_t
    let childIdentity: Identity?
    let gatePinnedWaitable: Bool
    let identityRevalidatedBeforeSignal: Bool
    let initialGroupMembers: [pid_t]
    let termSent: Bool
    let continueSent: Bool
    let killSent: Bool
    let childDirectReapUnavailable: Bool
    let childDisappeared: Bool
    let gateWaitStatus: Int32
    let gateReapedLast: Bool
    let recoveryGroupEmpty: Bool
    let foregroundRestored: Bool
    let foregroundAfterCompletion: pid_t
}

private struct TopologyRejectionReport: Codable {
    let coordinatorProcessID: pid_t
    let coordinatorProcessGroupID: pid_t
    let coordinatorSessionID: pid_t
    let gateProcessID: pid_t
    let recoveryProcessGroupID: pid_t
    let gateInitialStopStatus: Int32
    let gatePinnedWaitable: Bool
    let firstObservedFrameByteCount: Int
    let firstObservedFrameSHA256: String
    let trailingByteCount: Int
    let trailingSHA256: String
    let initialTerminal: TTY
    let invalidTerminal: TTY
    let finalTerminal: TTY
    let recoveryGroupMembersBeforeReap: [pid_t]
    let gateWaitStatus: Int32
    let recoveryGroupMembersAfterReap: [pid_t]
}

private enum Mode: String {
    case normal = "--coordinator-normal"
    case forwarded = "--coordinator-forwarded"
    case preFrameDeath = "--coordinator-pre-frame-death"
    case postFrameDeath = "--coordinator-post-frame-death"
    case invalidTopology = "--coordinator-invalid-topology"
}

private final class PhysicalFixture {
    private static let operationNanoseconds: UInt64 = 5_000_000_000
    private static let reserveNanoseconds: UInt64 = 2_000_000_000

    let directory: URL
    let executable: URL
    let capsule: URL
    let capsuleBytes: Data
    let capsuleNode: Node
    let childSpawnAttemptMarker: URL

    static let childSpawnAttemptMarkerBytes = Data(
        "stornaut-child-spawn-attempt-v1".utf8
    )

    private init(
        directory: URL, executable: URL, capsule: URL,
        capsuleBytes: Data, capsuleNode: Node, childSpawnAttemptMarker: URL
    ) {
        self.directory = directory
        self.executable = executable
        self.capsule = capsule
        self.capsuleBytes = capsuleBytes
        self.capsuleNode = capsuleNode
        self.childSpawnAttemptMarker = childSpawnAttemptMarker
    }

    static func make(
        signal: Int32? = nil, preFrameDeath: Bool = false,
        postFrameDeath: Bool = false
    ) throws -> PhysicalFixture {
        let root = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = root.appending(path: "Tests/Fixtures/InvestigationMachineGateStub/main.swift")
        let directory = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-recovery-pgid-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        do {
            let executable = directory.appending(path: "gate-stub")
            let process = Process()
            process.executableURL = URL(filePath: "/usr/bin/xcrun")
            process.arguments = ["swiftc", "-parse-as-library", source.path, "-o", executable.path]
            process.environment = [:]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run(); process.waitUntilExit()
            guard process.terminationStatus == 0 else { throw TestError.compile(process.terminationStatus) }
            var bytes = Data()
            if let signal {
                bytes.append(Data(String(
                    format: "stornaut-forwarded-signal-v2-%02d", signal
                ).utf8))
            } else if preFrameDeath {
                bytes.append(Data("stornaut-pre-frame-death-v2".utf8))
            } else if postFrameDeath {
                bytes.append(Data("stornaut-post-frame-death-v2".utf8))
            }
            bytes.append(contentsOf: (0..<4097).map { UInt8(truncatingIfNeeded: $0 &* 17 &+ 3) })
            let capsule = directory.appending(path: "capsule.bin")
            try bytes.write(to: capsule, options: .withoutOverwriting)
            guard chmod(capsule.path, 0o600) == 0 else { throw posix("chmod") }
            return PhysicalFixture(
                directory: directory, executable: executable, capsule: capsule,
                capsuleBytes: bytes, capsuleNode: try node(capsule),
                childSpawnAttemptMarker: URL(
                    filePath: executable.path + ".child-spawn-attempted"
                )
            )
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    func run<T: Decodable>(_ mode: Mode) throws -> T {
        var pipeFD: [Int32] = [-1, -1]
        guard pipe(&pipeFD) == 0 else { throw posix("pipe") }
        defer { if pipeFD[0] >= 0 { close(pipeFD[0]) }; if pipeFD[1] >= 0 { close(pipeFD[1]) } }
        try cloexec(pipeFD[0]); try cloexec(pipeFD[1])
        var actions: posix_spawn_file_actions_t?
        guard posix_spawn_file_actions_init(&actions) == 0 else { throw TestError.invalid("actions init") }
        defer { posix_spawn_file_actions_destroy(&actions) }
        guard
            posix_spawn_file_actions_addinherit_np(&actions, 0) == 0,
            posix_spawn_file_actions_addinherit_np(&actions, 1) == 0,
            posix_spawn_file_actions_addinherit_np(&actions, 2) == 0,
            posix_spawn_file_actions_addclose(&actions, pipeFD[0]) == 0,
            posix_spawn_file_actions_adddup2(&actions, pipeFD[1], 3) == 0,
            posix_spawn_file_actions_addclose(&actions, pipeFD[1]) == 0
        else { throw TestError.invalid("actions") }
        var attributes: posix_spawnattr_t?
        guard posix_spawnattr_init(&attributes) == 0 else { throw TestError.invalid("attrs init") }
        defer { posix_spawnattr_destroy(&attributes) }
        guard posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_CLOEXEC_DEFAULT)) == 0 else {
            throw TestError.invalid("attrs")
        }
        var coordinator: pid_t = 0
        let result = try cStrings([executable.path, mode.rawValue, capsule.path]) { argv in
            try cStrings([]) { envp in
                executable.path.withCString { posix_spawn(&coordinator, $0, &actions, &attributes, argv, envp) }
            }
        }
        guard result == 0, coordinator > 1 else { throw TestError.posix("spawn coordinator", result) }
        close(pipeFD[1]); pipeFD[1] = -1
        let outerDeadline = try add(try now(), Self.operationNanoseconds + Self.reserveNanoseconds)
        var reaped = false
        defer {
            if !reaped {
                try? cleanupSession(coordinator, try! add(try! now(), Self.reserveNanoseconds))
            }
        }
        let readyData = try readFrame(pipeFD[0], outerDeadline)
        let ready = try JSONDecoder().decode(CoordinatorReady.self, from: readyData)
        guard
            ready.version == 2, ready.processID == coordinator,
            ready.processGroupID == coordinator, ready.sessionID == coordinator,
            ready.foregroundProcessGroupID == coordinator
        else { throw TestError.invalid("coordinator bootstrap identity") }
        let data = try readFrame(pipeFD[0], outerDeadline)
        close(pipeFD[0]); pipeFD[0] = -1
        let status = try waitProcess(coordinator, outerDeadline)
        reaped = true
        guard Self.exited(status) == 0 else {
            throw TestError.invalid(String(decoding: data, as: UTF8.self))
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func remove() { try? FileManager.default.removeItem(at: directory) }
    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    static func argumentTranscript(_ values: [String]) -> Data {
        var result = Data()
        for value in values {
            result.append(Data(value.utf8))
            result.append(0)
        }
        return result
    }
    static func isAbsent(_ url: URL) throws -> Bool {
        var value = stat()
        errno = 0
        return lstat(url.path, &value) == -1 && errno == ENOENT
    }
    static func exited(_ status: Int32) -> Int32? { status & 0x7f == 0 ? (status >> 8) & 255 : nil }
    static func signaled(_ status: Int32) -> Int32? { let s = status & 0x7f; return s > 0 && s < 0x7f ? s : nil }
}

private enum TestError: Error {
    case compile(Int32)
    case invalid(String)
    case posix(String, Int32)
    case timeout(String)
}

private func node(_ url: URL) throws -> Node {
    var value = stat()
    guard lstat(url.path, &value) == 0 else { throw posix("lstat") }
    return Node(device: UInt64(bitPattern: Int64(value.st_dev)), inode: UInt64(value.st_ino),
        generation: UInt64(value.st_gen), size: value.st_size)
}

private func cleanupSession(_ sid: pid_t, _ deadline: UInt64) throws {
    var groups = Set<pid_t>()
    for pid in try allPIDs() where getsid(pid) == sid {
        let group = getpgid(pid)
        if group > 1 { groups.insert(group) }
    }
    for group in groups { _ = kill(-group, SIGTERM); _ = kill(-group, SIGCONT) }
    let grace = min(deadline, try add(try now(), 500_000_000))
    while try now() < grace, try sessionExists(sid) { usleep(10_000) }
    if try sessionExists(sid) {
        for pid in try allPIDs() where getsid(pid) == sid {
            let group = getpgid(pid); if group > 1 { groups.insert(group) }
        }
        for group in groups { _ = kill(-group, SIGKILL) }
    }
    _ = try? waitProcess(sid, deadline)
}

private func killProbeSession(_ sid: pid_t, _ deadline: UInt64) throws {
    var groups = Set<pid_t>()
    for pid in try allPIDs() where getsid(pid) == sid {
        let group = getpgid(pid)
        if group > 1 { groups.insert(group) }
    }
    for group in groups {
        errno = 0
        guard kill(-group, SIGKILL) == 0 || errno == ESRCH else {
            throw posix("kill probe group")
        }
    }
    errno = 0
    guard kill(sid, SIGKILL) == 0 || errno == ESRCH else {
        throw posix("kill probe coordinator")
    }
    var status: Int32 = 0
    while try now() < deadline {
        errno = 0
        let value = waitpid(sid, &status, WNOHANG)
        if value == sid || (value < 0 && errno == ECHILD) { break }
        if value == 0 || (value < 0 && errno == EINTR) {
            usleep(10_000)
            continue
        }
        throw posix("reap probe coordinator")
    }
    while try now() < deadline, try sessionExists(sid) { usleep(10_000) }
    guard !(try sessionExists(sid)) else {
        throw TestError.timeout("probe session cleanup")
    }
}

private func sessionExists(_ sid: pid_t) throws -> Bool {
    try allPIDs().contains { getsid($0) == sid }
}

private func allPIDs() throws -> [pid_t] {
    var capacity = 4_096
    while capacity <= 131_072 {
        var values = [pid_t](repeating: 0, count: capacity)
        let count = values.withUnsafeMutableBytes {
            proc_listallpids($0.baseAddress, Int32($0.count))
        }
        guard count >= 0 else { throw posix("all PIDs") }
        if count < capacity {
            return values.prefix(Int(count)).filter { $0 > 1 }
        }
        capacity *= 2
    }
    throw TestError.invalid("all PIDs overflow")
}

private func readFrame(_ fd: Int32, _ deadline: UInt64) throws -> Data {
    let prefix = try readExact(fd, 4, deadline)
    let count = prefix.withUnsafeBytes { UInt32(bigEndian: $0.loadUnaligned(as: UInt32.self)) }
    guard count > 0, count <= 65_536 else { throw TestError.invalid("frame size") }
    return try readExact(fd, Int(count), deadline)
}

private func readExact(_ fd: Int32, _ count: Int, _ deadline: UInt64) throws -> Data {
    var result = Data()
    while result.count < count {
        var item = pollfd(fd: fd, events: Int16(POLLIN | POLLHUP), revents: 0)
        let polled = poll(&item, 1, 50)
        if polled == 0 { if try now() >= deadline { throw TestError.timeout("frame") }; continue }
        if polled < 0, errno == EINTR { continue }
        guard polled > 0, item.revents & Int16(POLLERR | POLLNVAL) == 0 else { throw posix("poll") }
        var bytes = [UInt8](repeating: 0, count: min(4096, count - result.count))
        let amount = read(fd, &bytes, bytes.count)
        if amount > 0 { result.append(contentsOf: bytes.prefix(amount)); continue }
        if amount == 0 { throw TestError.invalid("unexpected EOF") }
        if errno == EINTR { continue }
        throw posix("read")
    }
    return result
}

private func readExactProcessOutput(
    _ fd: Int32, processID: pid_t, deadline: UInt64
) throws -> Data {
    var result = Data()
    while try now() < deadline {
        var item = pollfd(fd: fd, events: Int16(POLLIN | POLLHUP), revents: 0)
        let polled = poll(&item, 1, 50)
        if polled == 0 { continue }
        if polled < 0, errno == EINTR { continue }
        guard polled > 0, item.revents & Int16(POLLERR | POLLNVAL) == 0 else {
            throw posix("probe result poll")
        }
        var bytes = [UInt8](repeating: 0, count: 4096)
        let amount = read(fd, &bytes, bytes.count)
        if amount > 0 {
            result.append(contentsOf: bytes.prefix(amount))
            continue
        }
        if amount == 0 { return result }
        if errno != EINTR { throw posix("probe result read") }
    }
    _ = kill(processID, SIGKILL)
    throw TestError.timeout("probe result")
}

private func waitProcess(_ pid: pid_t, _ deadline: UInt64) throws -> Int32 {
    var status: Int32 = 0
    while try now() < deadline {
        let value = waitpid(pid, &status, WNOHANG)
        if value == pid { return status }
        if value == 0 || value < 0 && errno == EINTR { usleep(10_000); continue }
        throw posix("wait process")
    }
    throw TestError.timeout("wait process")
}

private func cloexec(_ fd: Int32) throws {
    let flags = fcntl(fd, F_GETFD)
    guard flags >= 0, fcntl(fd, F_SETFD, flags | FD_CLOEXEC) == 0 else { throw posix("cloexec") }
}

private func cStrings<T>(_ values: [String], _ body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws -> T) throws -> T {
    var storage = values.map { strdup($0) }
    guard storage.allSatisfy({ $0 != nil }) else { throw TestError.invalid("strdup") }
    defer { storage.compactMap { $0 }.forEach { free($0) } }
    storage.append(nil)
    return try storage.withUnsafeMutableBufferPointer { try body($0.baseAddress!) }
}

private func now() throws -> UInt64 {
    var info = mach_timebase_info_data_t()
    guard mach_timebase_info(&info) == KERN_SUCCESS, info.denom > 0 else { throw TestError.invalid("timebase") }
    let product = mach_continuous_time().multipliedFullWidth(by: UInt64(info.numer))
    guard product.high < UInt64(info.denom) else { throw TestError.invalid("time overflow") }
    return UInt64(info.denom).dividingFullWidth(product).quotient
}

private func add(_ value: UInt64, _ delta: UInt64) throws -> UInt64 {
    let result = value.addingReportingOverflow(delta)
    guard !result.overflow else { throw TestError.invalid("deadline overflow") }
    return result.partialValue
}

private func exited(_ status: Int32) -> Int32? { status & 0x7f == 0 ? (status >> 8) & 255 : nil }
private func posix(_ operation: String) -> TestError { .posix(operation, errno) }
