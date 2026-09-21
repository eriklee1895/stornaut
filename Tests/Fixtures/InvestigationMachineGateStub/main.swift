import CommonCrypto
import Darwin
import Foundation

@_silgen_name("_NSGetEnviron")
private func environmentPointer()
    -> UnsafeMutablePointer<UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?>

private enum Contract {
    static let operationNanoseconds: UInt64 = 5_000_000_000
    static let recoveryNanoseconds: UInt64 = 2_000_000_000
    static let graceNanoseconds: UInt64 = 500_000_000
    static let preparedByteCount = 512
    static let forwardedSignals: [Int32] = [SIGHUP, SIGINT, SIGQUIT, SIGTERM]
    static let arguments = [
        "/usr/bin/sudo", "-N", "-p",
        "Stornaut Task 39 ii-c administrator authorization: ", "--",
        "/Library/Application Support/Stornaut/"
            + "Stornaut-R5-Diagnostic.app/Contents/MacOS/"
            + "StornautInvestigationMachineDriver",
    ]
    static let postDeathPrefix = Data("stornaut-post-frame-death-v2".utf8)
    static let preDeathPrefix = Data("stornaut-pre-frame-death-v2".utf8)

    static func signalPrefix(_ signal: Int32) -> Data {
        Data(String(format: "stornaut-forwarded-signal-v2-%02d", signal).utf8)
    }

    static func forwardedSignal(in data: Data) -> Int32? {
        forwardedSignals.first { data.starts(with: signalPrefix($0)) }
    }
}

private enum Mode: String {
    case normal = "--coordinator-normal"
    case forwarded = "--coordinator-forwarded"
    case preFrameDeath = "--coordinator-pre-frame-death"
    case postFrameDeath = "--coordinator-post-frame-death"
    case invalidTopology = "--coordinator-invalid-topology"
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

private struct ChildObservation: Codable, Equatable {
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

private struct Prepared: Codable, Equatable {
    let version: Int
    let gateProcessID: pid_t
    let recoveryProcessGroupID: pid_t
    let coordinatorProcessGroupID: pid_t
    let childIdentity: Identity
    let capsule: Node
    let terminal: TTY
    let childInitialStopStatus: Int32
}

private struct Handoff: Codable {
    let childIdentity: Identity
    let foregroundProcessGroupID: pid_t
    let readyByte: UInt8
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

private enum FixtureError: Error, CustomStringConvertible {
    case posix(String, Int32)
    case invalid(String)
    case timeout(String)

    var description: String {
        switch self {
        case let .posix(operation, code):
            "\(operation) failed with errno/status \(code)"
        case let .invalid(reason):
            "invalid fixture state: \(reason)"
        case let .timeout(operation):
            "bounded fixture timeout: \(operation)"
        }
    }
}

@main
private struct Main {
    static func main() {
        do {
            if CommandLine.arguments.count == 3,
                let mode = Mode(rawValue: CommandLine.arguments[1])
            {
                try coordinator(mode: mode, capsulePath: CommandLine.arguments[2])
            } else if CommandLine.arguments.count == 1 {
                try gate()
            } else {
                try child()
            }
        } catch {
            let coordinator = CommandLine.arguments.count == 3
                && Mode(rawValue: CommandLine.arguments[1]) != nil
            try? writeFrame(
                coordinator ? 3 : STDOUT_FILENO,
                Data("stub-error: \(error)".utf8)
            )
            _exit(70)
        }
    }

    private static func child() throws -> Never {
        let deadline = try operationDeadline()
        let inputNode = try regularNode(STDIN_FILENO)
        let initialOffset = lseek(STDIN_FILENO, 0, SEEK_CUR)
        guard initialOffset == 0 else { throw invalid("child initial offset") }
        let input = try readEOF(STDIN_FILENO, 1_100_000, deadline)
        let finalOffset = lseek(STDIN_FILENO, 0, SEEK_CUR)
        guard finalOffset == inputNode.size else { throw invalid("child final offset") }
        if input.starts(with: Contract.preDeathPrefix) {
            try idle("pre-frame child")
        }
        if input.starts(with: Contract.postDeathPrefix) {
            for ignored in [SIGHUP, SIGTERM] {
                let previous = signal(ignored, SIG_IGN)
                guard unsafeBitCast(previous, to: UInt.self)
                        != unsafeBitCast(SIG_ERR, to: UInt.self)
                else { throw posix("ignore recovery signal") }
            }
            try unblock(Contract.forwardedSignals)
            try writeAll(STDOUT_FILENO, Data([0x53]))
            try idle("post-frame child")
        }
        if Contract.forwardedSignal(in: input) != nil {
            try unblock(Contract.forwardedSignals)
            try writeAll(STDOUT_FILENO, Data([0x53]))
            try idle("signal child")
        }
        try unblock(Contract.forwardedSignals)
        let value = ChildObservation(
            version: 2, argumentCount: CommandLine.arguments.count,
            argumentsSHA256: digest(argumentTranscript(CommandLine.arguments)),
            environmentCount: explicitEnvironmentCount(),
            identity: try identity(getpid()), inputNode: inputNode,
            initialInputOffset: initialOffset, finalInputOffset: finalOffset,
            reachedEOF: true, inputSHA256: digest(input),
            terminal: try tty(STDERR_FILENO),
            descriptor7Errno: closedErrno(7), descriptor8Errno: closedErrno(8),
            descriptor9Errno: closedErrno(9)
        )
        let encoded = try encode(value)
        guard encoded.count <= 512 else { throw invalid("child report size") }
        try writeAll(STDOUT_FILENO, encoded)
        _exit(0)
    }

    private static func gate() throws {
        let deadline = try operationDeadline()
        let gatePID = getpid()
        let recoveryPGID = getpgrp()
        let initialTTY = try tty(STDERR_FILENO)
        let coordinatorPGID = initialTTY.foregroundProcessGroupID
        guard
            CommandLine.arguments.count == 1, explicitEnvironmentCount() == 0,
            gatePID == recoveryPGID, coordinatorPGID > 1,
            coordinatorPGID != recoveryPGID, getppid() == coordinatorPGID,
            getpgid(getppid()) == coordinatorPGID,
            try descriptorInventory() == [0, 1, 2]
        else { throw invalid("background gate invocation") }
        try block([SIGTTOU] + Contract.forwardedSignals)
        let capsule = try regularNode(STDIN_FILENO)
        let bytes = try preadAll(STDIN_FILENO, capsule.size)
        guard lseek(STDIN_FILENO, 0, SEEK_CUR) == 0 else { throw invalid("gate input offset") }

        var output = try makePipe()
        var childPID: pid_t = 0
        var childReaped = false
        var restored = false
        defer {
            if !restored { _ = tcsetpgrp(STDERR_FILENO, coordinatorPGID) }
            if childPID > 1, !childReaped {
                _ = kill(-recoveryPGID, SIGKILL)
                _ = try? waitProcess(childPID, 0, try! recoveryDeadline(), "gate defer reap")
            }
            closeFD(&output.read)
            closeFD(&output.write)
        }

        childPID = try spawnObservedChild(
            executablePath(), output.read, output.write
        )
        closeFD(&output.write)
        let stopStatus = try waitInitialStop(childPID, deadline)
        let childIdentity = try identity(childPID)
        guard
            childPID != recoveryPGID, childIdentity.parentProcessID == gatePID,
            childIdentity.processGroupID == recoveryPGID
        else { throw invalid("child recovery group") }

        if bytes.starts(with: Contract.preDeathPrefix) {
            try idle("pre-frame gate")
        }

        guard
            setpgid(0, coordinatorPGID) == 0, getpgrp() == coordinatorPGID,
            try identity(childPID) == childIdentity,
            tcgetpgrp(STDERR_FILENO) == coordinatorPGID
        else { throw invalid("gate join coordinator group") }
        let prepared = Prepared(
            version: 2, gateProcessID: gatePID,
            recoveryProcessGroupID: recoveryPGID,
            coordinatorProcessGroupID: coordinatorPGID,
            childIdentity: childIdentity, capsule: capsule, terminal: initialTTY,
            childInitialStopStatus: stopStatus
        )
        try writeAtomic(STDOUT_FILENO, try preparedBytes(prepared))
        guard raise(SIGSTOP) == 0 else { throw posix("stop gate") }
        guard
            getpgrp() == coordinatorPGID, try identity(childPID) == childIdentity,
            tcgetpgrp(STDERR_FILENO) == coordinatorPGID
        else { throw invalid("gate resume revalidation") }
        try setForeground(recoveryPGID, STDERR_FILENO)
        guard kill(-recoveryPGID, SIGCONT) == 0 else { throw posix("continue recovery group") }

        if bytes.starts(with: Contract.postDeathPrefix) {
            let ready = try readExact(output.read, 1, deadline)
            try writeFrame(STDOUT_FILENO, try encode(Handoff(
                childIdentity: childIdentity,
                foregroundProcessGroupID: tcgetpgrp(STDERR_FILENO),
                readyByte: ready[0]
            )))
            try idle("post-frame gate")
        }
        if let forwarded = Contract.forwardedSignal(in: bytes) {
            let ready = try readExact(output.read, 1, deadline)
            let childTTY = try tty(STDERR_FILENO)
            guard try identity(childPID) == childIdentity else { throw invalid("signal identity drift") }
            let consumed = try consume(forwarded, deadline)
            guard consumed == forwarded, kill(-recoveryPGID, forwarded) == 0 else {
                throw posix("forward signal")
            }
            let childStatus = try waitProcess(childPID, 0, deadline, "signal child exit")
            childReaped = true
            _ = try readEOF(output.read, 512, deadline)
            closeFD(&output.read)
            try setForeground(coordinatorPGID, STDERR_FILENO)
            restored = tcgetpgrp(STDERR_FILENO) == coordinatorPGID
            let finalTTY = try tty(STDERR_FILENO)
            guard
                signaled(childStatus) == forwarded, groupEmpty(recoveryPGID),
                restored, childTTY.foregroundProcessGroupID == recoveryPGID
            else { throw invalid("signal completion") }
            guard close(STDIN_FILENO) == 0 else { throw posix("close gate input") }
            try writeFrame(STDOUT_FILENO, try encode(SignalGateReport(
                gateProcessID: gatePID, gateCoordinatorProcessGroupID: coordinatorPGID,
                recoveryProcessGroupID: recoveryPGID, childIdentity: childIdentity,
                childInitialStopStatus: stopStatus, capsule: capsule,
                initialTerminal: initialTTY, childTerminal: childTTY,
                finalTerminal: finalTTY, readyByte: ready[0],
                childWaitStatus: childStatus, forwardedSignal: forwarded,
                exactChildReaped: true, recoveryGroupEmpty: true,
                foregroundRestored: true, inputClosed: true
            )))
            return
        }

        let childBytes = try readEOF(output.read, 513, deadline)
        closeFD(&output.read)
        let observation = try JSONDecoder().decode(ChildObservation.self, from: childBytes)
        let childStatus = try waitProcess(childPID, 0, deadline, "normal child exit")
        childReaped = true
        try setForeground(coordinatorPGID, STDERR_FILENO)
        restored = tcgetpgrp(STDERR_FILENO) == coordinatorPGID
        let finalTTY = try tty(STDERR_FILENO)
        guard
            observation.identity == childIdentity, observation.inputNode == capsule,
            observation.finalInputOffset == capsule.size,
            observation.inputSHA256 == digest(bytes), exited(childStatus) == 0,
            groupEmpty(recoveryPGID), restored
        else { throw invalid("normal completion") }
        guard close(STDIN_FILENO) == 0 else { throw posix("close gate input") }
        try writeFrame(STDOUT_FILENO, try encode(GateReport(
            gateProcessID: gatePID, gateCoordinatorProcessGroupID: coordinatorPGID,
            recoveryProcessGroupID: recoveryPGID, childIdentity: childIdentity,
            childInitialStopStatus: stopStatus, capsule: capsule,
            initialTerminal: initialTTY, childTerminal: observation.terminal,
            finalTerminal: finalTTY, childObservation: observation,
            outputByteCount: childBytes.count, outputSHA256: digest(childBytes),
            childWaitStatus: childStatus, exactChildReaped: true,
            recoveryGroupEmpty: true, foregroundRestored: true, inputClosed: true
        )))
    }

    private static func coordinator(mode: Mode, capsulePath: String) throws {
        try block([SIGTTOU] + Contract.forwardedSignals)
        guard setsid() == getpid() else { throw posix("setsid") }
        let operation = try operationDeadline()
        var master: Int32 = -1
        var slave: Int32 = -1
        guard openpty(&master, &slave, nil, nil, nil) == 0 else { throw posix("openpty") }
        defer { closeFD(&master); closeFD(&slave) }
        try cloexec(master); try cloexec(slave)
        var value: Int32 = 0
        guard ioctl(slave, TIOCSCTTY, &value) == 0 else { throw posix("TIOCSCTTY") }
        let coordinatorPID = getpid()
        guard getpgrp() == coordinatorPID, getsid(0) == coordinatorPID else {
            throw invalid("coordinator identity")
        }
        try setForeground(coordinatorPID, slave)
        let coordinatorInitialTTY = try tty(slave)
        try writeFrame(3, try encode(CoordinatorReady(
            version: 2, processID: coordinatorPID,
            processGroupID: getpgrp(), sessionID: getsid(0),
            foregroundProcessGroupID: tcgetpgrp(slave)
        )))
        let capsuleFD = open(capsulePath, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard capsuleFD >= 0 else { throw posix("open capsule") }
        defer { _ = close(capsuleFD) }
        let capsuleNode = try regularNode(capsuleFD)
        let capsuleBytes = try preadAll(capsuleFD, capsuleNode.size)

        var channel = try makePipe()
        defer { closeFD(&channel.read); closeFD(&channel.write) }
        let gatePID = try spawnGate(
            executablePath(), capsuleFD, channel.read, channel.write, slave,
            startSuspended: mode == .invalidTopology
        )
        let recoveryPGID = gatePID
        closeFD(&channel.write)
        var gateReaped = false
        defer {
            if !gateReaped {
                _ = try? recoverOuterGroup(
                    gatePID: gatePID, recoveryPGID: recoveryPGID,
                    coordinatorPGID: coordinatorPID, slave: slave,
                    childIdentity: nil, deadline: try! recoveryDeadline()
                )
            }
        }

        if mode == .invalidTopology {
            let gateInitialStop = try waitInitialStop(gatePID, operation)
            guard try processGroupMembers(recoveryPGID) == [gatePID] else {
                throw invalid("invalid-topology initial recovery group")
            }
            try setForeground(recoveryPGID, slave)
            let invalidTTY = try tty(slave)
            guard
                invalidTTY.device == coordinatorInitialTTY.device,
                invalidTTY.inode == coordinatorInitialTTY.inode,
                invalidTTY.foregroundProcessGroupID == recoveryPGID
            else {
                throw invalid("invalid-topology foreground setup")
            }
            guard kill(gatePID, SIGCONT) == 0 else {
                throw posix("continue invalid-topology gate")
            }
            let rejection = try readFrame(channel.read, operation)
            let expectedRejection = Data(
                "stub-error: invalid fixture state: background gate invocation".utf8
            )
            let trailing = try readEOF(channel.read, 1, operation)
            let pinned = try waitable(gatePID, operation)
            let membersBeforeReap = try processGroupMembers(recoveryPGID)
            guard
                rejection == expectedRejection, trailing.isEmpty, pinned,
                membersBeforeReap == [gatePID]
            else { throw invalid("invalid-topology rejection evidence") }
            try setForeground(coordinatorPID, slave)
            let finalTTY = try tty(slave)
            let gateStatus = try waitProcess(
                gatePID, 0, operation, "invalid-topology gate reap"
            )
            gateReaped = true
            let membersAfterReap = try waitGroupMembers(
                recoveryPGID, equalTo: [], deadline: operation
            )
            guard
                exited(gateStatus) == 70,
                finalTTY.device == coordinatorInitialTTY.device,
                finalTTY.inode == coordinatorInitialTTY.inode,
                finalTTY.foregroundProcessGroupID == coordinatorPID
            else { throw invalid("invalid-topology cleanup") }
            try writeFrame(3, try encode(TopologyRejectionReport(
                coordinatorProcessID: coordinatorPID,
                coordinatorProcessGroupID: getpgrp(),
                coordinatorSessionID: getsid(0), gateProcessID: gatePID,
                recoveryProcessGroupID: recoveryPGID,
                gateInitialStopStatus: gateInitialStop, gatePinnedWaitable: pinned,
                firstObservedFrameByteCount: rejection.count,
                firstObservedFrameSHA256: digest(rejection),
                trailingByteCount: trailing.count, trailingSHA256: digest(trailing),
                initialTerminal: coordinatorInitialTTY,
                invalidTerminal: invalidTTY, finalTerminal: finalTTY,
                recoveryGroupMembersBeforeReap: membersBeforeReap,
                gateWaitStatus: gateStatus,
                recoveryGroupMembersAfterReap: membersAfterReap
            )))
            return
        }

        if mode == .preFrameDeath {
            let report = try recoverPreFrame(
                gatePID: gatePID, recoveryPGID: recoveryPGID,
                coordinatorPGID: coordinatorPID, slave: slave,
                deadline: operation
            )
            gateReaped = true
            try writeFrame(3, try encode(report))
            return
        }

        let preparedData = try readExact(
            channel.read, Contract.preparedByteCount, operation
        )
        let prepared = try decodePrepared(preparedData)
        let gateStop = try waitStopped(gatePID, operation)
        guard
            prepared.gateProcessID == gatePID,
            prepared.recoveryProcessGroupID == recoveryPGID,
            prepared.coordinatorProcessGroupID == coordinatorPID,
            prepared.childIdentity.parentProcessID == gatePID,
            prepared.childIdentity.processGroupID == recoveryPGID,
            prepared.childIdentity.processID != recoveryPGID,
            try identity(prepared.childIdentity.processID) == prepared.childIdentity,
            getpgid(gatePID) == coordinatorPID, stopSignal(gateStop) == SIGSTOP,
            tcgetpgrp(slave) == coordinatorPID
        else { throw invalid("prepared join") }

        if mode == .postFrameDeath {
            guard kill(gatePID, SIGCONT) == 0 else { throw posix("continue post gate") }
            let handoff = try JSONDecoder().decode(
                Handoff.self, from: readFrame(channel.read, operation)
            )
            guard handoff.childIdentity == prepared.childIdentity,
                  handoff.foregroundProcessGroupID == recoveryPGID,
                  handoff.readyByte == 0x53
            else { throw invalid("post handoff") }
            let report = try recoverPostFrame(
                gatePID: gatePID, prepared: prepared,
                coordinatorPGID: coordinatorPID, slave: slave,
                deadline: try recoveryDeadline()
            )
            gateReaped = true
            try writeFrame(3, try encode(report))
            return
        }

        let forwarded = mode == .forwarded
            ? Contract.forwardedSignal(in: capsuleBytes) : nil
        if mode == .forwarded, forwarded == nil { throw invalid("signal capsule") }
        if let forwarded {
            guard kill(-coordinatorPID, forwarded) == 0 else { throw posix("group signal") }
        }
        guard kill(gatePID, SIGCONT) == 0 else { throw posix("continue gate") }
        let reportData = try readFrame(channel.read, operation)
        let gateStatus = try waitProcess(gatePID, 0, operation, "gate exit")
        gateReaped = true
        let finalForeground = tcgetpgrp(slave)
        guard exited(gateStatus) == 0 else {
            throw invalid(
                "gate terminal status raw=\(gateStatus) "
                    + "exit=\(String(describing: exited(gateStatus))) "
                    + "payload=\(String(decoding: reportData, as: UTF8.self))"
            )
        }
        guard finalForeground == coordinatorPID else {
            throw invalid(
                "gate terminal foreground=\(finalForeground) "
                    + "expected=\(coordinatorPID)"
            )
        }
        if let forwarded {
            let gate = try JSONDecoder().decode(SignalGateReport.self, from: reportData)
            let consumed = try consume(forwarded, operation)
            try writeFrame(3, try encode(SignalCoordinatorReport(
                coordinatorProcessGroupID: coordinatorPID,
                recoveryProcessGroupID: recoveryPGID, gateProcessID: gatePID,
                deliveredSignal: forwarded, coordinatorConsumedSignal: consumed,
                coordinatorSurvivedUntilGateReport: true, gateWaitStatus: gateStatus,
                foregroundAfterCompletion: tcgetpgrp(slave), gate: gate
            )))
        } else {
            let gate = try JSONDecoder().decode(GateReport.self, from: reportData)
            try writeFrame(3, try encode(CoordinatorReport(
                coordinatorProcessID: coordinatorPID,
                coordinatorProcessGroupID: coordinatorPID,
                coordinatorSessionID: coordinatorPID,
                recoveryProcessGroupID: recoveryPGID, gateProcessID: gatePID,
                gateStoppedAfterPrepared: true, gateWaitStatus: gateStatus,
                foregroundAfterCompletion: tcgetpgrp(slave),
                coordinatorInitialTerminal: coordinatorInitialTTY, gate: gate
            )))
        }
    }
}

private func spawnGate(
    _ executable: String, _ capsule: Int32, _ pipeRead: Int32,
    _ pipeWrite: Int32, _ terminal: Int32, startSuspended: Bool
) throws -> pid_t {
    var actions: posix_spawn_file_actions_t?
    guard posix_spawn_file_actions_init(&actions) == 0 else { throw invalid("gate actions init") }
    defer { posix_spawn_file_actions_destroy(&actions) }
    guard
        posix_spawn_file_actions_adddup2(&actions, capsule, 0) == 0,
        posix_spawn_file_actions_adddup2(&actions, pipeWrite, 1) == 0,
        posix_spawn_file_actions_adddup2(&actions, terminal, 2) == 0,
        posix_spawn_file_actions_addclose(&actions, pipeRead) == 0,
        posix_spawn_file_actions_addclose(&actions, pipeWrite) == 0
    else { throw invalid("gate actions") }
    var attributes: posix_spawnattr_t?
    guard posix_spawnattr_init(&attributes) == 0 else { throw invalid("gate attrs init") }
    defer { posix_spawnattr_destroy(&attributes) }
    var mask = try signalSet([SIGTTOU] + Contract.forwardedSignals)
    var defaults = try signalSet([SIGTTOU, SIGTTIN, SIGTSTP, SIGPIPE] + Contract.forwardedSignals)
    var flags = Int16(POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETPGROUP
        | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF)
    if startSuspended { flags |= Int16(POSIX_SPAWN_START_SUSPENDED) }
    guard
        posix_spawnattr_setflags(&attributes, flags) == 0,
        posix_spawnattr_setpgroup(&attributes, 0) == 0,
        posix_spawnattr_setsigmask(&attributes, &mask) == 0,
        posix_spawnattr_setsigdefault(&attributes, &defaults) == 0
    else { throw invalid("gate attrs") }
    var pid: pid_t = 0
    let result = try cStrings([executable]) { argv in
        try cStrings([]) { envp in
            executable.withCString { posix_spawn(&pid, $0, &actions, &attributes, argv, envp) }
        }
    }
    guard result == 0, pid > 1 else { throw FixtureError.posix("spawn gate", result) }
    return pid
}

private func executablePath() -> String { CommandLine.arguments[0] }

private func spawnObservedChild(
    _ executable: String, _ pipeRead: Int32, _ pipeWrite: Int32
) throws -> pid_t {
    var actions: posix_spawn_file_actions_t?
    guard posix_spawn_file_actions_init(&actions) == 0 else { throw invalid("child actions init") }
    defer { posix_spawn_file_actions_destroy(&actions) }
    guard
        posix_spawn_file_actions_addinherit_np(&actions, 0) == 0,
        posix_spawn_file_actions_adddup2(&actions, pipeWrite, 1) == 0,
        posix_spawn_file_actions_addinherit_np(&actions, 2) == 0,
        posix_spawn_file_actions_addclose(&actions, pipeRead) == 0,
        posix_spawn_file_actions_addclose(&actions, pipeWrite) == 0
    else { throw invalid("child actions") }
    var attributes: posix_spawnattr_t?
    guard posix_spawnattr_init(&attributes) == 0 else { throw invalid("child attrs init") }
    defer { posix_spawnattr_destroy(&attributes) }
    var mask = try signalSet(Contract.forwardedSignals)
    var defaults = try signalSet([SIGTTOU, SIGTTIN, SIGTSTP, SIGPIPE] + Contract.forwardedSignals)
    let flags = Int16(POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_START_SUSPENDED
        | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF)
    guard
        posix_spawnattr_setflags(&attributes, flags) == 0,
        posix_spawnattr_setsigmask(&attributes, &mask) == 0,
        posix_spawnattr_setsigdefault(&attributes, &defaults) == 0
    else { throw invalid("child attrs") }
    var pid: pid_t = 0
    try writeChildSpawnAttemptMarker()
    let result = try cStrings(Contract.arguments) { argv in
        try cStrings([]) { envp in
            executable.withCString { posix_spawn(&pid, $0, &actions, &attributes, argv, envp) }
        }
    }
    guard result == 0, pid > 1 else { throw FixtureError.posix("spawn child", result) }
    return pid
}

private func recoverPreFrame(
    gatePID: pid_t, recoveryPGID: pid_t, coordinatorPGID: pid_t,
    slave: Int32, deadline: UInt64
) throws -> RecoveryReport {
    let initial = try waitGroupCount(recoveryPGID, 2, deadline)
    guard initial.contains(gatePID) else { throw invalid("pre-frame members") }
    guard kill(gatePID, SIGKILL) == 0 else { throw posix("kill pre-frame gate") }
    let pinned = try waitable(gatePID, deadline)
    try setForeground(coordinatorPGID, slave)
    let term = signalGroup(recoveryPGID, SIGTERM)
    let continued = signalGroup(recoveryPGID, SIGCONT)
    let grace = min(deadline, try add(try now(), Contract.graceNanoseconds))
    var leaderOnly = try waitGroupSubset(recoveryPGID, [gatePID], grace)
    var killed = false
    if !leaderOnly {
        killed = signalGroup(recoveryPGID, SIGKILL)
        leaderOnly = try waitGroupSubset(recoveryPGID, [gatePID], deadline)
    }
    guard pinned, leaderOnly else { throw invalid("pre-frame recovery members") }
    let status = try waitProcess(gatePID, 0, deadline, "pre-frame gate reap")
    let empty = try waitGroupEmpty(recoveryPGID, deadline)
    return RecoveryReport(
        phase: "pre-frame", coordinatorProcessGroupID: coordinatorPGID,
        recoveryProcessGroupID: recoveryPGID, gateProcessID: gatePID,
        childIdentity: nil, gatePinnedWaitable: true,
        identityRevalidatedBeforeSignal: false, initialGroupMembers: initial,
        termSent: term, continueSent: continued, killSent: killed,
        childDirectReapUnavailable: true, childDisappeared: true,
        gateWaitStatus: status, gateReapedLast: true, recoveryGroupEmpty: empty,
        foregroundRestored: tcgetpgrp(slave) == coordinatorPGID,
        foregroundAfterCompletion: tcgetpgrp(slave)
    )
}

private func recoverPostFrame(
    gatePID: pid_t, prepared: Prepared, coordinatorPGID: pid_t,
    slave: Int32, deadline: UInt64
) throws -> RecoveryReport {
    let beforeDeath = try optionalIdentity(prepared.childIdentity.processID)
    let exactBeforeDeath = beforeDeath == prepared.childIdentity
    guard exactBeforeDeath else {
        throw invalid("post-frame full identity mismatch before gate death")
    }
    guard kill(gatePID, SIGKILL) == 0 else { throw posix("kill post-frame gate") }
    let pinned = try waitable(gatePID, deadline)
    try setForeground(coordinatorPGID, slave)
    let current = try optionalIdentity(prepared.childIdentity.processID)
    let exactLifetime = current.map { sameLifetime($0, prepared.childIdentity) }
        ?? false
    var term = false
    var continued = false
    var killed = false
    if exactLifetime {
        term = signalGroup(prepared.recoveryProcessGroupID, SIGTERM)
        continued = signalGroup(prepared.recoveryProcessGroupID, SIGCONT)
        let grace = min(deadline, try add(try now(), Contract.graceNanoseconds))
        if !(try waitGroupEmpty(prepared.recoveryProcessGroupID, grace)) {
            guard let current = try optionalIdentity(
                prepared.childIdentity.processID
            ), sameLifetime(current, prepared.childIdentity)
            else { throw invalid("post-frame identity drift before KILL") }
            killed = signalGroup(prepared.recoveryProcessGroupID, SIGKILL)
        }
    } else if current != nil {
        throw invalid("post-frame identity mismatch")
    }
    let directUnavailable = notDirectChild(prepared.childIdentity.processID)
    let disappeared = try waitDisappeared(prepared.childIdentity.processID, deadline)
    let empty = try waitGroupEmpty(prepared.recoveryProcessGroupID, deadline)
    let status = try waitProcess(gatePID, 0, deadline, "post-frame gate reap")
    return RecoveryReport(
        phase: "post-frame", coordinatorProcessGroupID: coordinatorPGID,
        recoveryProcessGroupID: prepared.recoveryProcessGroupID,
        gateProcessID: gatePID, childIdentity: prepared.childIdentity,
        gatePinnedWaitable: pinned,
        identityRevalidatedBeforeSignal: exactBeforeDeath && exactLifetime,
        initialGroupMembers: [prepared.childIdentity.processID],
        termSent: term, continueSent: continued, killSent: killed,
        childDirectReapUnavailable: directUnavailable,
        childDisappeared: disappeared, gateWaitStatus: status,
        gateReapedLast: true, recoveryGroupEmpty: empty,
        foregroundRestored: tcgetpgrp(slave) == coordinatorPGID,
        foregroundAfterCompletion: tcgetpgrp(slave)
    )
}

private func recoverOuterGroup(
    gatePID: pid_t, recoveryPGID: pid_t, coordinatorPGID: pid_t,
    slave: Int32, childIdentity: Identity?, deadline: UInt64
) throws -> RecoveryReport {
    try setForeground(coordinatorPGID, slave)
    var exact = false
    if let childIdentity {
        exact = try optionalIdentity(childIdentity.processID) == childIdentity
        if !exact, try optionalIdentity(childIdentity.processID) != nil {
            throw invalid("outer recovery identity mismatch")
        }
    }
    let canSignal = childIdentity == nil || exact
    let term = canSignal ? signalGroup(recoveryPGID, SIGTERM) : false
    let continued = canSignal ? signalGroup(recoveryPGID, SIGCONT) : false
    let grace = min(deadline, try add(try now(), Contract.graceNanoseconds))
    var empty = try waitGroupEmpty(recoveryPGID, grace)
    var killed = false
    if !empty, canSignal { killed = signalGroup(recoveryPGID, SIGKILL) }
    _ = kill(gatePID, SIGKILL)
    let status = try waitProcess(gatePID, 0, deadline, "outer gate reap")
    empty = try waitGroupEmpty(recoveryPGID, deadline)
    return RecoveryReport(
        phase: "outer", coordinatorProcessGroupID: coordinatorPGID,
        recoveryProcessGroupID: recoveryPGID, gateProcessID: gatePID,
        childIdentity: childIdentity, gatePinnedWaitable: true,
        identityRevalidatedBeforeSignal: exact, initialGroupMembers: [],
        termSent: term, continueSent: continued, killSent: killed,
        childDirectReapUnavailable: true, childDisappeared: empty,
        gateWaitStatus: status, gateReapedLast: true, recoveryGroupEmpty: empty,
        foregroundRestored: tcgetpgrp(slave) == coordinatorPGID,
        foregroundAfterCompletion: tcgetpgrp(slave)
    )
}

private func preparedBytes(_ value: Prepared) throws -> Data {
    let raw = try encode(value)
    guard raw.count <= Contract.preparedByteCount else { throw invalid("prepared size") }
    return raw + Data(repeating: 0x20, count: Contract.preparedByteCount - raw.count)
}

private func decodePrepared(_ data: Data) throws -> Prepared {
    guard data.count == Contract.preparedByteCount else { throw invalid("prepared length") }
    let value = try JSONDecoder().decode(Prepared.self, from: data)
    guard try preparedBytes(value) == data else { throw invalid("prepared canonical") }
    return value
}

private func writeAtomic(_ fd: Int32, _ data: Data) throws {
    guard data.count == Contract.preparedByteCount, data.count <= Int(PIPE_BUF) else {
        throw invalid("atomic record size")
    }
    let count = data.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
    guard count == data.count else { throw posix("atomic prepared write") }
}

private func identity(_ pid: pid_t) throws -> Identity {
    guard let value = try optionalIdentity(pid) else { throw invalid("identity unavailable") }
    return value
}

private func optionalIdentity(_ pid: pid_t) throws -> Identity? {
    var value = proc_bsdinfo()
    let count = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &value,
        Int32(MemoryLayout<proc_bsdinfo>.size))
    if count == 0 { return nil }
    guard count == MemoryLayout<proc_bsdinfo>.size, value.pbi_pid == UInt32(pid),
          value.pbi_ppid > 0, value.pbi_pgid > 1, value.pbi_start_tvsec > 0,
          value.pbi_start_tvusec < 1_000_000
    else { throw invalid("identity shape") }
    return Identity(
        processID: pid, parentProcessID: pid_t(value.pbi_ppid),
        processGroupID: pid_t(value.pbi_pgid),
        startSeconds: value.pbi_start_tvsec,
        startMicroseconds: value.pbi_start_tvusec
    )
}

private func sameLifetime(_ lhs: Identity, _ rhs: Identity) -> Bool {
    lhs.processID == rhs.processID
        && lhs.processGroupID == rhs.processGroupID
        && lhs.startSeconds == rhs.startSeconds
        && lhs.startMicroseconds == rhs.startMicroseconds
}

private func processGroupMembers(_ group: pid_t) throws -> [pid_t] {
    var values = [pid_t](repeating: 0, count: 64)
    let count = values.withUnsafeMutableBytes {
        proc_listpids(UInt32(PROC_PGRP_ONLY), UInt32(bitPattern: group),
            $0.baseAddress, Int32($0.count))
    }
    guard
        count >= 0,
        Int(count) < values.count * MemoryLayout<pid_t>.stride,
        Int(count).isMultiple(of: MemoryLayout<pid_t>.stride)
    else {
        throw posix("group inventory")
    }
    let result = values.prefix(Int(count) / MemoryLayout<pid_t>.stride)
        .filter { $0 > 1 }.sorted()
    guard Set(result).count == result.count else {
        throw invalid("duplicate group member")
    }
    return result
}

private func waitGroupCount(_ group: pid_t, _ count: Int, _ deadline: UInt64) throws -> [pid_t] {
    while try now() < deadline {
        let values = try processGroupMembers(group)
        if values.count >= count { return values }
        try pause(deadline)
    }
    throw FixtureError.timeout("group member count")
}

private func waitGroupSubset(_ group: pid_t, _ allowed: Set<pid_t>, _ deadline: UInt64) throws -> Bool {
    while try now() < deadline {
        if Set(try processGroupMembers(group)).isSubset(of: allowed) { return true }
        try pause(deadline)
    }
    return Set(try processGroupMembers(group)).isSubset(of: allowed)
}

private func waitGroupEmpty(_ group: pid_t, _ deadline: UInt64) throws -> Bool {
    try waitGroupSubset(group, [], deadline)
}

private func waitGroupMembers(
    _ group: pid_t, equalTo expected: [pid_t], deadline: UInt64
) throws -> [pid_t] {
    while try now() < deadline {
        let values = try processGroupMembers(group)
        if values == expected { return values }
        try pause(deadline)
    }
    return try processGroupMembers(group)
}

private func waitable(_ pid: pid_t, _ deadline: UInt64) throws -> Bool {
    while try now() < deadline {
        var info = siginfo_t()
        errno = 0
        let result = waitid(
            P_PID, UInt32(pid), &info, WEXITED | WNOHANG | WNOWAIT
        )
        if result == 0, info.si_pid == pid { return true }
        if result != 0, errno != EINTR { throw posix("waitid pin") }
        try pause(deadline)
    }
    throw FixtureError.timeout("waitid pin")
}

private func signalGroup(_ group: pid_t, _ signal: Int32) -> Bool {
    errno = 0
    return kill(-group, signal) == 0 || errno == ESRCH
}

private func notDirectChild(_ pid: pid_t) -> Bool {
    var status: Int32 = 0
    errno = 0
    return waitpid(pid, &status, WNOHANG) == -1 && errno == ECHILD
}

private func waitDisappeared(_ pid: pid_t, _ deadline: UInt64) throws -> Bool {
    while try now() < deadline {
        errno = 0
        if kill(pid, 0) == -1, errno == ESRCH { return true }
        try pause(deadline)
    }
    return false
}

private func waitInitialStop(_ pid: pid_t, _ deadline: UInt64) throws -> Int32 {
    let status = try waitProcess(
        pid, WUNTRACED, deadline, "initial suspended process stop"
    )
    guard status == 0x7f else { throw invalid("initial suspended status") }
    return status
}

private func waitStopped(_ pid: pid_t, _ deadline: UInt64) throws -> Int32 {
    let status = try waitProcess(pid, WUNTRACED, deadline, "gate stop")
    guard stopSignal(status) == SIGSTOP else { throw invalid("gate stop status") }
    return status
}

private func waitProcess(_ pid: pid_t, _ options: Int32, _ deadline: UInt64, _ operation: String) throws -> Int32 {
    var status: Int32 = 0
    while try now() < deadline {
        let result = waitpid(pid, &status, options | WNOHANG)
        if result == pid { return status }
        if result == 0 || result < 0 && errno == EINTR { try pause(deadline); continue }
        throw posix(operation)
    }
    throw FixtureError.timeout(operation)
}

private func readFrame(_ fd: Int32, _ deadline: UInt64) throws -> Data {
    let prefix = try readExact(fd, 4, deadline)
    let count = prefix.withUnsafeBytes { UInt32(bigEndian: $0.loadUnaligned(as: UInt32.self)) }
    guard count > 0, count <= 65_536 else { throw invalid("frame size") }
    return try readExact(fd, Int(count), deadline)
}

private func writeFrame(_ fd: Int32, _ data: Data) throws {
    guard let count = UInt32(exactly: data.count), count <= 65_536 else { throw invalid("frame size") }
    var value = count.bigEndian
    try withUnsafeBytes(of: &value) { try writeAll(fd, Data($0)) }
    try writeAll(fd, data)
}

private func readExact(_ fd: Int32, _ count: Int, _ deadline: UInt64) throws -> Data {
    var result = Data()
    while result.count < count {
        try readable(fd, deadline)
        var bytes = [UInt8](repeating: 0, count: min(4096, count - result.count))
        let amount = read(fd, &bytes, bytes.count)
        if amount > 0 { result.append(contentsOf: bytes.prefix(amount)); continue }
        if amount == 0 { throw invalid("unexpected EOF") }
        if errno == EINTR { continue }
        throw posix("read exact")
    }
    return result
}

private func readEOF(_ fd: Int32, _ maximum: Int, _ deadline: UInt64) throws -> Data {
    var result = Data()
    while try now() < deadline {
        try readable(fd, deadline)
        var bytes = [UInt8](repeating: 0, count: 4096)
        let amount = read(fd, &bytes, bytes.count)
        if amount > 0 {
            guard result.count + amount <= maximum else { throw invalid("read bound") }
            result.append(contentsOf: bytes.prefix(amount)); continue
        }
        if amount == 0 { return result }
        if errno == EINTR { continue }
        throw posix("read EOF")
    }
    throw FixtureError.timeout("EOF drain")
}

private func readable(_ fd: Int32, _ deadline: UInt64) throws {
    while try now() < deadline {
        var item = pollfd(fd: fd, events: Int16(POLLIN | POLLHUP), revents: 0)
        let result = poll(&item, 1, 50)
        if result > 0 {
            guard item.revents & Int16(POLLERR | POLLNVAL) == 0 else { throw invalid("poll flags") }
            return
        }
        if result == 0 || result < 0 && errno == EINTR { continue }
        throw posix("poll")
    }
    throw FixtureError.timeout("readable")
}

private func consume(_ signal: Int32, _ deadline: UInt64) throws -> Int32 {
    var one = try signalSet([signal])
    while try now() < deadline {
        var pending = sigset_t()
        guard sigpending(&pending) == 0 else { throw posix("sigpending") }
        if sigismember(&pending, signal) == 1 {
            var observed: Int32 = 0
            guard sigwait(&one, &observed) == 0 else { throw posix("sigwait") }
            return observed
        }
        try pause(deadline)
    }
    throw FixtureError.timeout("signal consumption")
}

private func block(_ signals: [Int32]) throws {
    var value = try signalSet(signals)
    guard pthread_sigmask(SIG_BLOCK, &value, nil) == 0 else { throw posix("block signals") }
}

private func unblock(_ signals: [Int32]) throws {
    var value = try signalSet(signals)
    guard pthread_sigmask(SIG_UNBLOCK, &value, nil) == 0 else {
        throw posix("unblock signals")
    }
}

private func signalSet(_ signals: [Int32]) throws -> sigset_t {
    var value = sigset_t()
    guard sigemptyset(&value) == 0 else { throw posix("sigemptyset") }
    for signal in signals { guard sigaddset(&value, signal) == 0 else { throw posix("sigaddset") } }
    return value
}

private func regularNode(_ fd: Int32) throws -> Node {
    var value = stat()
    guard fstat(fd, &value) == 0, value.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else {
        throw invalid("regular descriptor")
    }
    return Node(device: UInt64(bitPattern: Int64(value.st_dev)),
        inode: UInt64(value.st_ino), generation: UInt64(value.st_gen), size: value.st_size)
}

private func tty(_ fd: Int32) throws -> TTY {
    var value = stat()
    guard fstat(fd, &value) == 0, isatty(fd) == 1 else { throw invalid("TTY") }
    let foreground = tcgetpgrp(fd)
    guard foreground > 1 else { throw posix("tcgetpgrp") }
    return TTY(device: UInt64(bitPattern: Int64(value.st_dev)),
        inode: UInt64(value.st_ino), foregroundProcessGroupID: foreground)
}

private func preadAll(_ fd: Int32, _ size: Int64) throws -> Data {
    guard let count = Int(exactly: size), count > 0 else { throw invalid("pread size") }
    var result = Data(count: count)
    var offset = 0
    while offset < count {
        let amount = result.withUnsafeMutableBytes {
            pread(fd, $0.baseAddress?.advanced(by: offset), count - offset, off_t(offset))
        }
        if amount > 0 { offset += amount; continue }
        if amount < 0, errno == EINTR { continue }
        throw posix("pread")
    }
    return result
}

private func descriptorInventory() throws -> [Int32] {
    var values = [proc_fdinfo](repeating: proc_fdinfo(), count: 64)
    let count = values.withUnsafeMutableBytes {
        proc_pidinfo(getpid(), PROC_PIDLISTFDS, 0, $0.baseAddress, Int32($0.count))
    }
    guard count >= 0, Int(count).isMultiple(of: MemoryLayout<proc_fdinfo>.stride) else {
        throw posix("descriptor inventory")
    }
    return values.prefix(Int(count) / MemoryLayout<proc_fdinfo>.stride).map(\.proc_fd).sorted()
}

private func explicitEnvironmentCount() -> Int {
    guard let environment = environmentPointer().pointee else { return -1 }
    var count = 0
    var index = 0
    while let item = environment[index] {
        if !String(cString: item).hasPrefix("__CF_USER_TEXT_ENCODING=") { count += 1 }
        index += 1
    }
    return count
}

private func closedErrno(_ fd: Int32) -> Int32 {
    errno = 0
    return fcntl(fd, F_GETFD) == -1 ? errno : 0
}

private func setForeground(_ group: pid_t, _ fd: Int32) throws {
    while tcsetpgrp(fd, group) != 0 { if errno != EINTR { throw posix("tcsetpgrp") } }
}

private func makePipe() throws -> (read: Int32, write: Int32) {
    var values: [Int32] = [-1, -1]
    guard pipe(&values) == 0 else { throw posix("pipe") }
    try cloexec(values[0]); try cloexec(values[1])
    return (values[0], values[1])
}

private func cloexec(_ fd: Int32) throws {
    let flags = fcntl(fd, F_GETFD)
    guard flags >= 0, fcntl(fd, F_SETFD, flags | FD_CLOEXEC) == 0 else { throw posix("cloexec") }
}

private func closeFD(_ fd: inout Int32) { if fd >= 0 { _ = close(fd); fd = -1 } }

private func writeAll(_ fd: Int32, _ data: Data) throws {
    try data.withUnsafeBytes { bytes in
        var offset = 0
        while offset < bytes.count {
            let amount = write(fd, bytes.baseAddress?.advanced(by: offset), bytes.count - offset)
            if amount > 0 { offset += amount; continue }
            if amount < 0, errno == EINTR { continue }
            throw posix("write")
        }
    }
}

private func encode<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(value)
}

private func digest(_ data: Data) -> String {
    var bytes = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    data.withUnsafeBytes { _ = CC_SHA256($0.baseAddress, CC_LONG($0.count), &bytes) }
    let digits = Array("0123456789abcdef".utf8)
    return String(decoding: bytes.flatMap { [digits[Int($0 >> 4)], digits[Int($0 & 15)]] }, as: UTF8.self)
}

private func argumentTranscript(_ values: [String]) -> Data {
    var result = Data()
    for value in values { result.append(Data(value.utf8)); result.append(0) }
    return result
}

private func writeChildSpawnAttemptMarker() throws {
    var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
    let count = proc_pidpath(getpid(), &buffer, UInt32(buffer.count))
    guard
        count > 0, count < buffer.count,
        let executable = String(
            validating: buffer.prefix(Int(count)).map(UInt8.init(bitPattern:)),
            as: UTF8.self
        )
    else { throw invalid("child executable path") }
    let path = executable + ".child-spawn-attempted"
    let descriptor = open(
        path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0o600
    )
    guard descriptor >= 0 else { throw posix("create child spawn-attempt marker") }
    defer { _ = close(descriptor) }
    try writeAll(descriptor, Data("stornaut-child-spawn-attempt-v1".utf8))
}

private func cStrings<T>(_ values: [String], _ body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws -> T) throws -> T {
    var storage = values.map { strdup($0) }
    guard storage.allSatisfy({ $0 != nil }) else { throw invalid("strdup") }
    defer { storage.compactMap { $0 }.forEach { free($0) } }
    storage.append(nil)
    return try storage.withUnsafeMutableBufferPointer { try body($0.baseAddress!) }
}

private func idle(_ operation: String) throws -> Never {
    let deadline = try operationDeadline()
    while try now() < deadline { try pause(deadline) }
    throw FixtureError.timeout(operation)
}

private func pause(_ deadline: UInt64) throws {
    guard try now() < deadline else { return }
    var request = timespec(tv_sec: 0, tv_nsec: 10_000_000)
    var remaining = timespec()
    while nanosleep(&request, &remaining) != 0 {
        if errno != EINTR { throw posix("nanosleep") }
        request = remaining
    }
}

private func now() throws -> UInt64 {
    var info = mach_timebase_info_data_t()
    guard mach_timebase_info(&info) == KERN_SUCCESS, info.denom > 0 else { throw invalid("timebase") }
    let product = mach_continuous_time().multipliedFullWidth(by: UInt64(info.numer))
    guard product.high < UInt64(info.denom) else { throw invalid("time overflow") }
    return UInt64(info.denom).dividingFullWidth(product).quotient
}

private func add(_ value: UInt64, _ delta: UInt64) throws -> UInt64 {
    let result = value.addingReportingOverflow(delta)
    guard !result.overflow else { throw invalid("deadline overflow") }
    return result.partialValue
}

private func operationDeadline() throws -> UInt64 { try add(now(), Contract.operationNanoseconds) }
private func recoveryDeadline() throws -> UInt64 { try add(now(), Contract.recoveryNanoseconds) }
private func stopSignal(_ status: Int32) -> Int32 { status & 0x7f == 0x7f ? (status >> 8) & 0xff : 0 }
private func exited(_ status: Int32) -> Int32? { status & 0x7f == 0 ? (status >> 8) & 0xff : nil }
private func signaled(_ status: Int32) -> Int32? { let s = status & 0x7f; return s > 0 && s < 0x7f ? s : nil }
private func groupEmpty(_ group: pid_t) -> Bool { errno = 0; return kill(-group, 0) == -1 && errno == ESRCH }
private func posix(_ operation: String) -> FixtureError { .posix(operation, errno) }
private func invalid(_ reason: String) -> FixtureError { .invalid(reason) }
