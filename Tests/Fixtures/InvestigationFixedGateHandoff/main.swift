import CryptoKit
import Darwin
import Foundation
import StornautInvestigationHandoffContract
import StornautInvestigationMachineGateSupport
import StornautInvestigationMachineLaunchSupport
private enum FixtureMode: String {
    case success
    case earlyExit
    case malformedPrepared
    case overflowPrepared
    case forwardedSignal
    case stubbornDescendant
    case cleanupTimeout
}
private struct FixtureReport: Codable {
    let version: Int
    let mode: String
    let succeeded: Bool
    let error: String?
    let outerAttemptUUID: String
    let gateProcessID: Int32?
    let gateProcessGroupID: Int32?
    let exactGateExited: Bool
    let gateProcessAbsent: Bool
    let processGroupEmpty: Bool
    let capsuleRemoved: Bool
    let foregroundRestored: Bool
}
private enum FixtureError: Error {
    case invalid(String)
    case posix(String, Int32)
    case timeout(String)
}
@main
private struct Main {
    static func main() {
        do {
            if CommandLine.arguments.count == 4,
               CommandLine.arguments[1] == "--coordinator",
               let mode = FixtureMode(rawValue: CommandLine.arguments[2]),
               let attempt = UUID(uuidString: CommandLine.arguments[3])
            {
                try coordinator(mode: mode, outerAttemptUUID: attempt)
            } else if CommandLine.arguments.count == 1 {
                try gate()
            } else if CommandLine.arguments.count == 3,
                      CommandLine.arguments[1] == "--child",
                      let mode = FixtureMode(rawValue: CommandLine.arguments[2])
            {
                try child(mode: mode)
            } else {
                throw FixtureError.invalid("arguments")
            }
        } catch {
            try? writeReportData(
                Data("fixture-error:\(error)".utf8),
                descriptor: STDOUT_FILENO
            )
            _exit(70)
        }
    }
    private static func coordinator(
        mode: FixtureMode, outerAttemptUUID: UUID
    ) throws {
        guard setsid() == getpid() else { throw posix("setsid") }
        var master: Int32 = -1
        var slave: Int32 = -1
        guard openpty(&master, &slave, nil, nil, nil) == 0 else {
            throw posix("openpty")
        }
        defer { closeIfOpen(&master); closeIfOpen(&slave) }
        try setCloseOnExec(master)
        try setCloseOnExec(slave)
        var zero: Int32 = 0
        guard ioctl(slave, TIOCSCTTY, &zero) == 0 else {
            throw posix("TIOCSCTTY")
        }
        guard dup2(slave, STDERR_FILENO) == STDERR_FILENO else {
            throw posix("dup2 stderr")
        }
        try blockSignals(
            InvestigationMachineFixedGateContract.forwardedSignals
                + [SIGTTIN, SIGTTOU, SIGTSTP]
        )
        guard tcsetpgrp(STDERR_FILENO, getpid()) == 0 else {
            throw posix("coordinator foreground")
        }
        try Data(mode.rawValue.utf8).write(
            to: fixtureModeURL(), options: .atomic
        )
        try? FileManager.default.removeItem(at: fixtureGatePIDURL())
        let canonicalInput = try projectedInput(
            outerAttemptUUID: outerAttemptUUID
        ).encoded()
        let attemptURL = attemptDirectoryURL(outerAttemptUUID)
        var report: FixtureReport
        do {
            let receipt = try InvestigationFixedGateHandoff().run(
                canonicalProjectedInput: canonicalInput
            )
            report = FixtureReport(
                version: 1, mode: mode.rawValue, succeeded: true, error: nil,
                outerAttemptUUID: outerAttemptUUID.uuidString.lowercased(),
                gateProcessID: receipt.gateProcessID,
                gateProcessGroupID: receipt.gateProcessGroupID,
                exactGateExited: receipt.exactGateWaitClassification
                    == .exited(status: 0),
                gateProcessAbsent: processAbsent(receipt.gateProcessID),
                processGroupEmpty: groupMembers(
                    receipt.gateProcessGroupID
                ).isEmpty,
                capsuleRemoved: isAbsent(attemptURL),
                foregroundRestored: tcgetpgrp(STDERR_FILENO) == getpid()
            )
        } catch {
            let observedGatePID = try? recordedGatePID()
            report = FixtureReport(
                version: 1, mode: mode.rawValue, succeeded: false,
                error: handoffErrorName(error),
                outerAttemptUUID: outerAttemptUUID.uuidString.lowercased(),
                gateProcessID: observedGatePID,
                gateProcessGroupID: observedGatePID,
                exactGateExited: false,
                gateProcessAbsent: observedGatePID.map(processAbsent) ?? false,
                processGroupEmpty: observedGatePID.map {
                    groupMembers($0).isEmpty
                } ?? false, capsuleRemoved: isAbsent(attemptURL),
                foregroundRestored: tcgetpgrp(STDERR_FILENO) == getpid()
            )
        }
        try writeReportData(
            try JSONEncoder().encode(report), descriptor: STDOUT_FILENO
        )
    }
    private static func gate() throws {
        let mode = try FixtureMode(
            rawValue: String(contentsOf: fixtureModeURL(), encoding: .utf8)
        ).required("mode")
        let gatePID = getpid()
        let recoveryGroup = getpgrp()
        let coordinator = getppid()
        let session = getsid(0)
        let initialTerminal = try terminalObservation()
        guard gatePID == recoveryGroup, coordinator == session,
              initialTerminal.foregroundProcessGroupID == coordinator
        else { throw FixtureError.invalid("gate topology") }
        try Data(String(gatePID).utf8).write(
            to: fixtureGatePIDURL(), options: .atomic
        )
        guard try descriptorInventory() == [0, 1, 2] else {
            throw FixtureError.invalid("gate descriptor inventory")
        }

        // Leave an observation window for the parent to bind the original G.
        usleep(150_000)
        if mode == .earlyExit { _exit(70) }

        let capsule = try nodeObservation(STDIN_FILENO)
        let inputBytes = try preadAll(STDIN_FILENO, count: capsule.size)
        let input = try InvestigationProjectedCohortInput.decode(inputBytes)
        guard try input.encoded() == inputBytes else {
            throw FixtureError.invalid("capsule encoding")
        }
        var outputPipe = try makePipe()
        defer { closeIfOpen(&outputPipe.read); closeIfOpen(&outputPipe.write) }
        let childPID = try spawnChild(
            mode: mode, outputRead: outputPipe.read,
            outputWrite: outputPipe.write,
            processGroup: mode == .cleanupTimeout ? coordinator : nil
        )
        closeIfOpen(&outputPipe.write)
        let childIdentity = try processIdentity(childPID)
        let expectedChildGroup = mode == .cleanupTimeout
            ? coordinator : recoveryGroup
        guard childIdentity.parentProcessID == gatePID,
              childIdentity.processGroupID == expectedChildGroup,
              childIdentity.sessionID == session
        else { throw FixtureError.invalid("child topology") }
        if mode == .cleanupTimeout {
            guard setpgid(0, coordinator) == 0, getpgrp() == coordinator else {
                throw posix("join cleanup coordinator group")
            }
        }

        if mode == .stubbornDescendant {
            guard kill(-recoveryGroup, SIGCONT) == 0 else {
                throw posix("continue stubborn child")
            }
            let ready = try readExactly(outputPipe.read, count: 1)
            guard ready == Data([0x53]) else {
                throw FixtureError.invalid("stubborn child readiness")
            }
            _exit(70)
        }
        if mode == .cleanupTimeout {
            guard kill(childPID, SIGCONT) == 0 else {
                throw posix("continue cleanup fixture child")
            }
            guard raise(SIGSTOP) == 0 else {
                throw posix("freeze cleanup fixture gate")
            }
            try waitForever()
        }
        guard setpgid(0, coordinator) == 0, getpgrp() == coordinator else {
            throw posix("join coordinator group")
        }
        let started = monotonicNanoseconds()
        let prepared = try InvestigationMachineGatePreparedFrame(
            gateProcessID: gatePID, coordinatorProcessID: coordinator,
            sessionID: session, childProcessID: childPID,
            recoveryProcessGroupID: recoveryGroup,
            savedForegroundProcessGroupID: coordinator,
            childParentProcessID: childIdentity.parentProcessID,
            childSessionID: childIdentity.sessionID,
            childStartSeconds: childIdentity.startSeconds,
            childStartMicroseconds: childIdentity.startMicroseconds,
            initialStopStatus: 0x7f, outerAttemptUUID: input.capsule.outerAttemptUUID,
            wholeInputSHA256: input.wholeInputSHA256, capsule: capsule,
            terminal: initialTerminal,
            absoluteDeadlineNanoseconds: started
                + InvestigationMachineFixedGateContract.deadlineNanoseconds
        )
        let preparedBytes = try prepared.encoded()
        switch mode {
        case .malformedPrepared:
            try writeAll(STDOUT_FILENO, Data(repeating: 0, count: preparedBytes.count))
            try waitForever()
        case .overflowPrepared:
            try writeAll(
                STDOUT_FILENO,
                preparedBytes + Data(
                    repeating: 0x7f,
                    count: InvestigationMachineGatePreparedFrame
                        .maximumByteCount + 1 - preparedBytes.count
                )
            )
            try waitForever()
        default:
            try writeAll(STDOUT_FILENO, preparedBytes)
        }
        guard raise(SIGSTOP) == 0 else { throw posix("gate stop") }
        guard tcsetpgrp(STDERR_FILENO, recoveryGroup) == 0 else {
            throw posix("child foreground")
        }
        guard kill(-recoveryGroup, SIGCONT) == 0 else {
            throw posix("continue child")
        }
        let childTerminal = try terminalObservation()
        var forwarded: Int32?
        if mode == .forwardedSignal {
            guard kill(-coordinator, SIGTERM) == 0 else {
                throw posix("forward coordinator signal")
            }
            forwarded = SIGTERM
            guard kill(-recoveryGroup, SIGTERM) == 0 else {
                throw posix("forward child signal")
            }
        }
        let output = try readToEOF(outputPipe.read, maximum: 513)
        closeIfOpen(&outputPipe.read)
        let childWait = try waitProcess(childPID)
        guard tcsetpgrp(STDERR_FILENO, coordinator) == 0 else {
            throw posix("restore foreground")
        }
        let finalTerminal = try terminalObservation()
        guard groupMembers(recoveryGroup).isEmpty else {
            throw FixtureError.invalid("child group residue")
        }
        let finalOffset = lseek(STDIN_FILENO, 0, SEEK_CUR)
        guard finalOffset == capsule.size else {
            throw FixtureError.invalid("input offset")
        }
        guard close(STDIN_FILENO) == 0 else { throw posix("close input") }
        let completed = monotonicNanoseconds()
        let receipt = try InvestigationMachineGateTransportReceipt(
            launcherExecutableSHA256: .hashing(try Data(
                contentsOf: URL(filePath: CommandLine.arguments[0])
            )),
            outerAttemptUUID: input.capsule.outerAttemptUUID,
            wholeInputSHA256: input.wholeInputSHA256,
            preparedFrameSHA256: .hashing(preparedBytes), capsule: capsule,
            gateProcessID: gatePID, coordinatorProcessID: coordinator,
            sessionID: session, recoveryProcessGroupID: recoveryGroup,
            savedForegroundProcessGroupID: coordinator,
            childIdentity: childIdentity,
            input: .init(
                node: capsule, initialOffset: 0, finalOffset: finalOffset,
                reachedEOF: true, sha256: input.wholeInputSHA256
            ),
            initialTerminal: initialTerminal, childTerminal: childTerminal,
            finalTerminal: finalTerminal,
            output: .init(
                byteCount: min(output.count, 512), sha256: .hashing(output),
                overflowObserved: output.count > 512, reachedEOF: true
            ),
            waitClassification: childWait, forwardedSignal: forwarded,
            monotonicStartedNanoseconds: started,
            monotonicCompletedNanoseconds: completed,
            terminationProgression: .natural, childProcessGroupEmpty: true,
            exactChildReaped: true, savedForegroundProcessGroupRestored: true,
            borrowedDescriptorOutcome: .closed
        )
        try writeAll(STDOUT_FILENO, try receipt.encoded())
        _exit(forwarded == nil
            ? InvestigationMachineGateSupport.completedExitStatus
            : InvestigationMachineGateSupport.forwardedSignalExitStatus)
    }
    private static func child(mode: FixtureMode) throws -> Never {
        if mode == .cleanupTimeout { try waitForever() }
        if mode == .stubbornDescendant {
            _ = signal(SIGTERM, SIG_IGN)
            try unblockSignals([SIGTERM])
            try writeAll(STDOUT_FILENO, Data([0x53]))
            try waitForever()
        }
        let input = try readToEOF(STDIN_FILENO, maximum: 1_100_000)
        guard !input.isEmpty else { throw FixtureError.invalid("child input") }
        if mode == .forwardedSignal {
            try unblockSignals([SIGTERM])
            try waitForever()
        }
        try writeAll(STDOUT_FILENO, Data("physical-fixture-output".utf8))
        _exit(0)
    }
}
private func projectedInput(
    outerAttemptUUID: UUID
) throws -> InvestigationProjectedCohortInput {
    let epochs = try (0..<8).map { ordinal in
        let configuration = Data("physical-configuration-\(ordinal)".utf8)
        return try InvestigationCohortEpoch(
            ordinal: UInt32(ordinal), epochUUID: UUID(),
            scenario: InvestigationHandoffScenario(
                rawValue: UInt32(ordinal + 1)
            )!, configurationNonce: UUID(), configuration: configuration,
            configurationSHA256: .hashing(configuration),
            signedRuntimeBindingSHA256: digest(UInt8(0x40 + ordinal))
        )
    }
    let capsule = try InvestigationCohortCapsule(
        outerAttemptUUID: outerAttemptUUID, epochs: epochs
    )
    return try InvestigationProjectedCohortInput(
        capsule: capsule,
        projections: try epochs.map { epoch in
            try InvestigationInstalledL2IdentityProjection(
                epochUUID: epoch.epochUUID,
                configurationNonce: epoch.configurationNonce,
                configurationValidBefore: .init(
                    rawValue: 2_000_000_000_000_000 + Int64(epoch.ordinal)
                ), configurationSHA256: epoch.configurationSHA256,
                signedRuntimeBindingSHA256: epoch.signedRuntimeBindingSHA256,
                appExecutableSHA256: digest(0x51),
                appBundleIdentifier: InvestigationInstalledL2IdentityProjection
                    .fixedAppBundleIdentifier,
                helperExecutableSHA256: digest(0x52),
                helperServiceIdentifier: InvestigationInstalledL2IdentityProjection
                    .fixedHelperServiceIdentifier,
                machineDriverExecutableSHA256: digest(0x53),
                machineDriverSigningIdentifier:
                    InvestigationInstalledL2IdentityProjection
                        .fixedMachineDriverSigningIdentifier,
                machineDriverDesignatedRequirementSHA256: digest(0x54),
                machineDriverCodeDirectoryHash: Data(repeating: 0x55, count: 20),
                machineClaimServiceIdentifier:
                    InvestigationInstalledL2IdentityProjection
                        .fixedMachineClaimServiceIdentifier
            )
        }
    )
}
private func fixtureModeURL() -> URL {
    URL(filePath: CommandLine.arguments[0]).deletingLastPathComponent()
        .appending(path: "fixture-mode")
}
private func fixtureGatePIDURL() -> URL {
    URL(filePath: CommandLine.arguments[0]).deletingLastPathComponent()
        .appending(path: "fixture-gate-pid")
}
private func recordedGatePID() throws -> pid_t {
    let value = try String(
        contentsOf: fixtureGatePIDURL(), encoding: .utf8
    )
    guard let pid = pid_t(value), pid > 1 else {
        throw FixtureError.invalid("recorded gate PID")
    }
    return pid
}
private func attemptDirectoryURL(_ uuid: UUID) -> URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Caches/com.eriklee.stornaut.task39-machine-gate")
        .appending(path: "attempt-" + uuid.uuidString.lowercased())
}
private func handoffErrorName(_ error: Error) -> String {
    guard let value = error as? InvestigationFixedGateHandoffError else {
        return "unexpected"
    }
    switch value {
    case .invalidCanonicalInput: return "invalidCanonicalInput"
    case .publicationFailed: return "publicationFailed"
    case .spawnFailedBeforeTransfer: return "spawnFailedBeforeTransfer"
    case .spawnUncertain: return "spawnUncertain"
    case .invalidPreparedFrame: return "invalidPreparedFrame"
    case .invalidTransportReceipt: return "invalidTransportReceipt"
    case .identityMismatch: return "identityMismatch"
    case .gateTerminated: return "gateTerminated"
    case .forwardedSignal: return "forwardedSignal"
    case .deadlineExceeded: return "deadlineExceeded"
    case .exactReapUncertain: return "exactReapUncertain"
    case .transportCloseUncertain: return "transportCloseUncertain"
    case .settlementResidue: return "settlementResidue"
    case .settlementFailed: return "settlementFailed"
    case .proofRejected: return "proofRejected"
    case .unexpectedResponse: return "unexpectedResponse"
    case .alreadyConsumed: return "alreadyConsumed"
    }
}
private func spawnChild(
    mode: FixtureMode, outputRead: Int32, outputWrite: Int32,
    processGroup: pid_t?
) throws -> pid_t {
    var actions: posix_spawn_file_actions_t?
    guard posix_spawn_file_actions_init(&actions) == 0 else {
        throw FixtureError.invalid("child actions")
    }
    defer { posix_spawn_file_actions_destroy(&actions) }
    guard posix_spawn_file_actions_addinherit_np(&actions, STDIN_FILENO) == 0,
          posix_spawn_file_actions_adddup2(&actions, outputWrite, STDOUT_FILENO) == 0,
          posix_spawn_file_actions_addinherit_np(&actions, STDERR_FILENO) == 0,
          posix_spawn_file_actions_addclose(&actions, outputRead) == 0,
          posix_spawn_file_actions_addclose(&actions, outputWrite) == 0
    else { throw FixtureError.invalid("child file actions") }
    var attributes: posix_spawnattr_t?
    guard posix_spawnattr_init(&attributes) == 0 else {
        throw FixtureError.invalid("child attributes")
    }
    defer { posix_spawnattr_destroy(&attributes) }
    var mask = try signalSet(
        InvestigationMachineFixedGateContract.forwardedSignals
    )
    var defaults = try signalSet(
        InvestigationMachineFixedGateContract.forwardedSignals
            + [SIGPIPE, SIGTTIN, SIGTTOU, SIGTSTP]
    )
    var flags = Int16(
        POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_START_SUSPENDED
            | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF
    )
    if let processGroup {
        flags |= Int16(POSIX_SPAWN_SETPGROUP)
        guard posix_spawnattr_setpgroup(&attributes, processGroup) == 0 else {
            throw FixtureError.invalid("child process group")
        }
    }
    guard posix_spawnattr_setflags(&attributes, flags) == 0,
          posix_spawnattr_setsigmask(&attributes, &mask) == 0,
          posix_spawnattr_setsigdefault(&attributes, &defaults) == 0
    else { throw FixtureError.invalid("child spawn policy") }
    let executable = CommandLine.arguments[0]
    var pid: pid_t = 0
    let result = try cStrings([executable, "--child", mode.rawValue]) { argv in
        try cStrings([]) { envp in
            executable.withCString {
                posix_spawn(&pid, $0, &actions, &attributes, argv, envp)
            }
        }
    }
    guard result == 0, pid > 1 else {
        throw FixtureError.posix("spawn child", result)
    }
    return pid
}
private func processIdentity(_ pid: pid_t) throws
    -> InvestigationMachineGateChildIdentity
{
    var value = proc_bsdinfo()
    let count = proc_pidinfo(
        pid, PROC_PIDTBSDINFO, 0, &value,
        Int32(MemoryLayout<proc_bsdinfo>.size)
    )
    guard count == MemoryLayout<proc_bsdinfo>.size,
          value.pbi_pid == UInt32(pid), value.pbi_ppid > 1,
          value.pbi_pgid > 1, value.pbi_start_tvsec > 0,
          value.pbi_start_tvusec < 1_000_000
    else { throw FixtureError.invalid("child identity") }
    return .init(
        processID: pid, parentProcessID: pid_t(value.pbi_ppid),
        processGroupID: pid_t(value.pbi_pgid), sessionID: getsid(pid),
        startSeconds: value.pbi_start_tvsec,
        startMicroseconds: value.pbi_start_tvusec
    )
}
private func nodeObservation(_ descriptor: Int32) throws
    -> InvestigationMachineGateNodeObservation
{
    var value = stat()
    guard fstat(descriptor, &value) == 0, value.st_mode & S_IFMT == S_IFREG,
          value.st_size > 0
    else { throw FixtureError.invalid("capsule node") }
    return .init(
        device: UInt64(bitPattern: Int64(value.st_dev)),
        inode: UInt64(value.st_ino), generation: UInt64(value.st_gen),
        size: value.st_size
    )
}
private func terminalObservation() throws
    -> InvestigationMachineGateTerminalObservation
{
    var value = stat()
    guard fstat(STDERR_FILENO, &value) == 0,
          value.st_mode & S_IFMT == S_IFCHR else {
        throw FixtureError.invalid("terminal node")
    }
    let foreground = tcgetpgrp(STDERR_FILENO)
    guard foreground > 1 else { throw posix("terminal foreground") }
    return .init(
        device: UInt64(bitPattern: Int64(value.st_dev)),
        inode: UInt64(value.st_ino),
        foregroundProcessGroupID: foreground
    )
}
private func makePipe() throws -> (read: Int32, write: Int32) {
    var values: [Int32] = [-1, -1]
    guard pipe(&values) == 0 else { throw posix("pipe") }
    try setCloseOnExec(values[0])
    try setCloseOnExec(values[1])
    return (values[0], values[1])
}
private func preadAll(_ descriptor: Int32, count: Int64) throws -> Data {
    guard count > 0, count <= 1_100_000 else {
        throw FixtureError.invalid("input size")
    }
    var result = Data()
    while result.count < Int(count) {
        var bytes = [UInt8](repeating: 0, count: min(16_384, Int(count) - result.count))
        let amount = pread(descriptor, &bytes, bytes.count, off_t(result.count))
        if amount < 0, errno == EINTR { continue }
        guard amount > 0 else { throw posix("pread") }
        result.append(contentsOf: bytes.prefix(amount))
    }
    return result
}
private func readToEOF(_ descriptor: Int32, maximum: Int) throws -> Data {
    var result = Data()
    while result.count <= maximum {
        var bytes = [UInt8](repeating: 0, count: min(512, maximum + 1 - result.count))
        let amount = read(descriptor, &bytes, bytes.count)
        if amount < 0, errno == EINTR { continue }
        if amount == 0 { return result }
        guard amount > 0 else { throw posix("read") }
        result.append(contentsOf: bytes.prefix(amount))
    }
    return result
}
private func readExactly(_ descriptor: Int32, count: Int) throws -> Data {
    var result = Data()
    while result.count < count {
        var bytes = [UInt8](repeating: 0, count: count - result.count)
        let amount = read(descriptor, &bytes, bytes.count)
        if amount < 0, errno == EINTR { continue }
        guard amount > 0 else { throw posix("read exact") }
        result.append(contentsOf: bytes.prefix(amount))
    }
    return result
}
private func waitProcess(_ pid: pid_t) throws
    -> InvestigationMachineGateWaitClassification
{
    let deadline = monotonicNanoseconds() + 10_000_000_000
    var status: Int32 = 0
    while monotonicNanoseconds() < deadline {
        let value = waitpid(pid, &status, WNOHANG)
        if value == pid {
            let low = status & 0x7f
            if low == 0 { return .exited(status: status >> 8 & 0xff) }
            if low > 0 && low < 0x7f { return .signaled(signal: low) }
            throw FixtureError.invalid("child wait status")
        }
        if value < 0, errno != EINTR { throw posix("waitpid") }
        usleep(10_000)
    }
    throw FixtureError.timeout("child")
}
private func groupMembers(_ group: pid_t) -> [pid_t] {
    var values = [pid_t](repeating: 0, count: 256)
    let bytes = values.withUnsafeMutableBytes {
        proc_listpids(
            UInt32(PROC_PGRP_ONLY), UInt32(bitPattern: group),
            $0.baseAddress, Int32($0.count)
        )
    }
    guard bytes >= 0 else { return [-1] }
    return values.prefix(Int(bytes) / MemoryLayout<pid_t>.stride)
        .filter { $0 > 1 }.sorted()
}
private func processAbsent(_ pid: pid_t) -> Bool {
    errno = 0
    return kill(pid, 0) == -1 && errno == ESRCH
}
private func descriptorInventory() throws -> [Int32] {
    var values = [proc_fdinfo](
        repeating: proc_fdinfo(), count: 128
    )
    let bytes = values.withUnsafeMutableBytes { buffer in
        proc_pidinfo(
            getpid(), PROC_PIDLISTFDS, 0, buffer.baseAddress,
            Int32(buffer.count)
        )
    }
    guard bytes >= 0,
          Int(bytes).isMultiple(of: MemoryLayout<proc_fdinfo>.stride),
          Int(bytes) < MemoryLayout<proc_fdinfo>.stride * values.count
    else { throw posix("descriptor inventory") }
    return values.prefix(Int(bytes) / MemoryLayout<proc_fdinfo>.stride)
        .map(\.proc_fd).sorted()
}
private func writeReportData(_ data: Data, descriptor: Int32) throws {
    var prefix = UInt32(data.count).bigEndian
    try withUnsafeBytes(of: &prefix) { try writeAll(descriptor, Data($0)) }
    try writeAll(descriptor, data)
}
private func writeAll(_ descriptor: Int32, _ data: Data) throws {
    var offset = 0
    while offset < data.count {
        let count = data.withUnsafeBytes { bytes in
            write(descriptor, bytes.baseAddress! + offset, data.count - offset)
        }
        if count < 0, errno == EINTR { continue }
        guard count > 0 else { throw posix("write") }
        offset += count
    }
}
private func setCloseOnExec(_ descriptor: Int32) throws {
    let flags = fcntl(descriptor, F_GETFD)
    guard flags >= 0, fcntl(descriptor, F_SETFD, flags | FD_CLOEXEC) == 0 else {
        throw posix("cloexec")
    }
}
private func blockSignals(_ signals: [Int32]) throws {
    var set = try signalSet(signals)
    let result = pthread_sigmask(SIG_BLOCK, &set, nil)
    guard result == 0 else { throw FixtureError.posix("signal block", result) }
}
private func unblockSignals(_ signals: [Int32]) throws {
    var set = try signalSet(signals)
    let result = pthread_sigmask(SIG_UNBLOCK, &set, nil)
    guard result == 0 else { throw FixtureError.posix("signal unblock", result) }
}
private func signalSet(_ signals: [Int32]) throws -> sigset_t {
    var set = sigset_t()
    guard sigemptyset(&set) == 0 else { throw posix("sigemptyset") }
    for signal in Set(signals) {
        guard sigaddset(&set, signal) == 0 else { throw posix("sigaddset") }
    }
    return set
}
private func waitForever() throws -> Never {
    while true { pause() }
}
private func closeIfOpen(_ descriptor: inout Int32) {
    if descriptor >= 0 { _ = close(descriptor); descriptor = -1 }
}
private func monotonicNanoseconds() -> UInt64 {
    DispatchTime.now().uptimeNanoseconds
}
private func digest(_ byte: UInt8) throws -> InvestigationHandoffSHA256 {
    try InvestigationHandoffSHA256(rawBytes: Data(repeating: byte, count: 32))
}
private func isAbsent(_ url: URL) -> Bool {
    var value = stat()
    errno = 0
    return lstat(url.path, &value) == -1 && errno == ENOENT
}
private func posix(_ operation: String) -> FixtureError {
    .posix(operation, errno)
}
private extension Optional {
    func required(_ name: String) throws -> Wrapped {
        guard let self else { throw FixtureError.invalid(name) }
        return self
    }
}

private func cStrings<Result>(
    _ strings: [String],
    body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws -> Result
) throws -> Result {
    var values: [UnsafeMutablePointer<CChar>?] = strings.map {
        strdup($0)
    }
    guard values.allSatisfy({ $0 != nil }) else {
        throw FixtureError.invalid("strdup")
    }
    defer {
        for value in values {
            if let value { free(value) }
        }
    }
    values.append(nil)
    return try values.withUnsafeMutableBufferPointer {
        try body($0.baseAddress!)
    }
}
