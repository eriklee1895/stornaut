import Darwin
import Foundation

private let sudoArguments = [
    "/usr/bin/sudo", "-N", "-p",
    "Stornaut Task 39 ii-c administrator authorization: ",
    "--",
    "/Library/Application Support/Stornaut/"
        + "Stornaut-R5-Diagnostic.app/Contents/MacOS/"
        + "StornautInvestigationMachineDriver",
]
private let forwardedSignals: [Int32] = [SIGHUP, SIGINT, SIGQUIT, SIGTERM]
private let probeNanoseconds: UInt64 = 2_000_000_000

private struct Identity: Codable, Equatable {
    let processID: pid_t
    let parentProcessID: pid_t
    let processGroupID: pid_t
    let sessionID: pid_t
    let startSeconds: UInt64
    let startMicroseconds: UInt64
    let status: UInt32
}

private struct Report: Codable {
    let coordinatorProcessID: pid_t
    let coordinatorProcessGroupID: pid_t
    let coordinatorSessionID: pid_t
    let gateProcessID: pid_t
    let recoveryProcessGroupID: pid_t
    let foregroundProcessGroupID: pid_t
    let spawnStatus: Int32
    let childProcessID: pid_t
    let firstIdentity: Identity?
    let firstIdentityErrno: Int32
    let secondIdentity: Identity?
    let secondIdentityErrno: Int32
    let firstKernelIdentity: Identity?
    let firstKernelIdentityErrno: Int32
    let secondKernelIdentity: Identity?
    let secondKernelIdentityErrno: Int32
    let initialWaitProcessID: pid_t
    let rawInitialWaitStatus: Int32?
    let thirdIdentity: Identity?
    let thirdIdentityErrno: Int32
    let thirdKernelIdentity: Identity?
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
}

private enum ProbeError: Error, CustomStringConvertible {
    case invalid(String)
    case posix(String, Int32)
    case timeout(String)

    var description: String {
        switch self {
        case .invalid(let reason): reason
        case .posix(let operation, let code):
            "\(operation) failed with errno/status \(code)"
        case .timeout(let operation): "\(operation) timed out"
        }
    }
}

@main
private struct Main {
    static func main() {
        do {
            if CommandLine.arguments == [CommandLine.arguments[0], "--gate"] {
                try runGate()
            } else if CommandLine.arguments.count == 1 {
                try runCoordinator()
            } else {
                throw ProbeError.invalid("unexpected arguments")
            }
        } catch {
            FileHandle.standardError.write(Data("probe-error: \(error)\n".utf8))
            _exit(70)
        }
    }

    private static func runCoordinator() throws {
        guard setsid() == getpid() else { throw posix("setsid") }
        var master: Int32 = -1
        var slave: Int32 = -1
        guard openpty(&master, &slave, nil, nil, nil) == 0 else {
            throw posix("openpty")
        }
        defer {
            if master >= 0 { _ = close(master) }
            if slave >= 0 { _ = close(slave) }
        }
        try setCloseOnExec(master)
        try setCloseOnExec(slave)
        var value: Int32 = 0
        guard ioctl(slave, TIOCSCTTY, &value) == 0 else {
            throw posix("TIOCSCTTY")
        }
        let coordinator = getpid()
        guard getpgrp() == coordinator, getsid(0) == coordinator else {
            throw ProbeError.invalid("invalid coordinator topology")
        }
        try setForeground(coordinator, descriptor: slave)

        var channel = try makePipe()
        defer {
            closeDescriptor(&channel.read)
            closeDescriptor(&channel.write)
        }
        let gate = try spawnGate(
            executable: CommandLine.arguments[0], outputRead: channel.read,
            outputWrite: channel.write, terminal: slave
        )
        var gateReaped = false
        defer {
            if !gateReaped {
                _ = kill(-gate, SIGKILL)
                _ = kill(gate, SIGKILL)
                while waitpid(gate, nil, 0) < 0, errno == EINTR {}
            }
        }
        closeDescriptor(&channel.write)
        let deadline = try adding(probeNanoseconds * 2, to: try now())
        let report = try readToEOF(channel.read, deadline: deadline)
        closeDescriptor(&channel.read)
        let gateStatus = try waitProcess(gate, options: 0, deadline: deadline)
        gateReaped = true
        guard exited(gateStatus) == 0 else {
            throw ProbeError.invalid("gate exited with raw status \(gateStatus)")
        }
        let terminal = try readAvailable(master, deadline: deadline)
        let decoded = try JSONDecoder().decode(Report.self, from: report)
        let complete = Report(
            coordinatorProcessID: decoded.coordinatorProcessID,
            coordinatorProcessGroupID: decoded.coordinatorProcessGroupID,
            coordinatorSessionID: decoded.coordinatorSessionID,
            gateProcessID: decoded.gateProcessID,
            recoveryProcessGroupID: decoded.recoveryProcessGroupID,
            foregroundProcessGroupID: decoded.foregroundProcessGroupID,
            spawnStatus: decoded.spawnStatus,
            childProcessID: decoded.childProcessID,
            firstIdentity: decoded.firstIdentity,
            firstIdentityErrno: decoded.firstIdentityErrno,
            secondIdentity: decoded.secondIdentity,
            secondIdentityErrno: decoded.secondIdentityErrno,
            firstKernelIdentity: decoded.firstKernelIdentity,
            firstKernelIdentityErrno: decoded.firstKernelIdentityErrno,
            secondKernelIdentity: decoded.secondKernelIdentity,
            secondKernelIdentityErrno: decoded.secondKernelIdentityErrno,
            initialWaitProcessID: decoded.initialWaitProcessID,
            rawInitialWaitStatus: decoded.rawInitialWaitStatus,
            thirdIdentity: decoded.thirdIdentity,
            thirdIdentityErrno: decoded.thirdIdentityErrno,
            thirdKernelIdentity: decoded.thirdKernelIdentity,
            thirdKernelIdentityErrno: decoded.thirdKernelIdentityErrno,
            gateJoinStatus: decoded.gateJoinStatus,
            gateJoinErrno: decoded.gateJoinErrno,
            gateProcessGroupAfterJoin: decoded.gateProcessGroupAfterJoin,
            childProcessGroupAfterJoin: decoded.childProcessGroupAfterJoin,
            childSessionAfterJoin: decoded.childSessionAfterJoin,
            exactKillStatus: decoded.exactKillStatus,
            exactKillErrno: decoded.exactKillErrno,
            exactReapProcessID: decoded.exactReapProcessID,
            exactReapStatus: decoded.exactReapStatus,
            recoveryGroupMembersAfterReap: decoded.recoveryGroupMembersAfterReap,
            capturedOutputByteCount: decoded.capturedOutputByteCount,
            capturedTerminalByteCount: terminal.count
        )
        try writeAll(STDOUT_FILENO, try JSONEncoder().encode(complete))
    }

    private static func runGate() throws {
        let gate = getpid()
        let recoveryGroup = getpgrp()
        let coordinator = getppid()
        let session = getsid(0)
        let foreground = tcgetpgrp(STDERR_FILENO)
        guard
            gate == recoveryGroup, coordinator > 1, session == coordinator,
            getpgid(coordinator) == coordinator, foreground == coordinator
        else { throw ProbeError.invalid("invalid gate topology") }

        var output = try makePipe()
        defer {
            closeDescriptor(&output.read)
            closeDescriptor(&output.write)
        }
        var child: pid_t = 0
        let spawnStatus = try spawnSuspendedSudo(
            processID: &child, outputRead: output.read, outputWrite: output.write
        )
        closeDescriptor(&output.write)

        var first: Identity?
        var firstErrno: Int32 = 0
        var second: Identity?
        var secondErrno: Int32 = 0
        var firstKernel: Identity?
        var firstKernelErrno: Int32 = 0
        var secondKernel: Identity?
        var secondKernelErrno: Int32 = 0
        var waitPID: pid_t = 0
        var waitStatus: Int32?
        var third: Identity?
        var thirdErrno: Int32 = 0
        var thirdKernel: Identity?
        var thirdKernelErrno: Int32 = 0
        var joinStatus: Int32 = -1
        var joinErrno: Int32 = 0
        var gateGroupAfter = getpgrp()
        var childGroupAfter: pid_t = -1
        var childSessionAfter: pid_t = -1
        var killStatus: Int32 = -1
        var killErrno: Int32 = 0
        var reapPID: pid_t = 0
        var reapStatus: Int32?
        var childReaped = false
        defer {
            if child > 1, !childReaped {
                _ = kill(child, SIGKILL)
                while waitpid(child, nil, 0) < 0, errno == EINTR {}
            }
        }

        if spawnStatus == 0, child > 1 {
            (first, firstErrno) = try optionalIdentity(child)
            (second, secondErrno) = try optionalIdentity(child)
            (firstKernel, firstKernelErrno) = try optionalKernelIdentity(child)
            (secondKernel, secondKernelErrno) = try optionalKernelIdentity(child)
            let observed = try waitInitialState(
                child, deadline: try adding(probeNanoseconds, to: try now())
            )
            waitPID = observed.processID
            waitStatus = observed.status

            errno = 0
            joinStatus = setpgid(0, coordinator)
            joinErrno = joinStatus == 0 ? 0 : errno
            gateGroupAfter = getpgrp()
            childGroupAfter = getpgid(child)
            childSessionAfter = getsid(child)
            (third, thirdErrno) = try optionalIdentity(child)
            (thirdKernel, thirdKernelErrno) = try optionalKernelIdentity(child)

            errno = 0
            killStatus = kill(child, SIGKILL)
            killErrno = killStatus == 0 ? 0 : errno
            var terminalStatus: Int32 = 0
            while true {
                let value = waitpid(child, &terminalStatus, 0)
                if value == child {
                    reapPID = value
                    reapStatus = terminalStatus
                    childReaped = true
                    break
                }
                if value < 0, errno == EINTR { continue }
                break
            }
        }

        let captured = try readToEOF(
            output.read, deadline: try adding(probeNanoseconds, to: try now())
        )
        closeDescriptor(&output.read)
        let report = Report(
            coordinatorProcessID: coordinator,
            coordinatorProcessGroupID: getpgid(coordinator),
            coordinatorSessionID: session, gateProcessID: gate,
            recoveryProcessGroupID: recoveryGroup,
            foregroundProcessGroupID: foreground, spawnStatus: spawnStatus,
            childProcessID: child, firstIdentity: first,
            firstIdentityErrno: firstErrno, secondIdentity: second,
            secondIdentityErrno: secondErrno,
            firstKernelIdentity: firstKernel,
            firstKernelIdentityErrno: firstKernelErrno,
            secondKernelIdentity: secondKernel,
            secondKernelIdentityErrno: secondKernelErrno,
            initialWaitProcessID: waitPID, rawInitialWaitStatus: waitStatus,
            thirdIdentity: third, thirdIdentityErrno: thirdErrno,
            thirdKernelIdentity: thirdKernel,
            thirdKernelIdentityErrno: thirdKernelErrno,
            gateJoinStatus: joinStatus,
            gateJoinErrno: joinErrno, gateProcessGroupAfterJoin: gateGroupAfter,
            childProcessGroupAfterJoin: childGroupAfter,
            childSessionAfterJoin: childSessionAfter,
            exactKillStatus: killStatus, exactKillErrno: killErrno,
            exactReapProcessID: reapPID, exactReapStatus: reapStatus,
            recoveryGroupMembersAfterReap: try processGroupMembers(recoveryGroup),
            capturedOutputByteCount: captured.count, capturedTerminalByteCount: 0
        )
        try writeAll(STDOUT_FILENO, try JSONEncoder().encode(report))
    }
}

private func spawnGate(
    executable: String, outputRead: Int32, outputWrite: Int32, terminal: Int32
) throws -> pid_t {
    var actions: posix_spawn_file_actions_t?
    guard posix_spawn_file_actions_init(&actions) == 0 else {
        throw ProbeError.invalid("gate actions init")
    }
    defer { posix_spawn_file_actions_destroy(&actions) }
    let null = open("/dev/null", O_RDONLY | O_CLOEXEC)
    guard null >= 0 else { throw posix("open /dev/null") }
    defer { _ = close(null) }
    guard
        posix_spawn_file_actions_adddup2(&actions, null, STDIN_FILENO) == 0,
        posix_spawn_file_actions_adddup2(&actions, outputWrite, STDOUT_FILENO) == 0,
        posix_spawn_file_actions_adddup2(&actions, terminal, STDERR_FILENO) == 0,
        posix_spawn_file_actions_addclose(&actions, outputRead) == 0,
        posix_spawn_file_actions_addclose(&actions, outputWrite) == 0
    else { throw ProbeError.invalid("gate actions") }
    var attributes: posix_spawnattr_t?
    guard posix_spawnattr_init(&attributes) == 0 else {
        throw ProbeError.invalid("gate attributes init")
    }
    defer { posix_spawnattr_destroy(&attributes) }
    var mask = try signalSet(forwardedSignals + [SIGTTIN, SIGTTOU, SIGTSTP])
    var defaults = try signalSet(
        forwardedSignals + [SIGTTIN, SIGTTOU, SIGTSTP, SIGPIPE]
    )
    let flags = Int16(
        POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETPGROUP
            | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF
    )
    guard
        posix_spawnattr_setflags(&attributes, flags) == 0,
        posix_spawnattr_setpgroup(&attributes, 0) == 0,
        posix_spawnattr_setsigmask(&attributes, &mask) == 0,
        posix_spawnattr_setsigdefault(&attributes, &defaults) == 0
    else { throw ProbeError.invalid("gate attributes") }
    var processID: pid_t = 0
    let status = try cStrings([executable, "--gate"]) { arguments in
        try cStrings([]) { environment in
            executable.withCString { path in
                posix_spawn(
                    &processID, path, &actions, &attributes, arguments, environment
                )
            }
        }
    }
    guard status == 0, processID > 1 else {
        throw ProbeError.posix("spawn gate", status)
    }
    return processID
}

private func spawnSuspendedSudo(
    processID: inout pid_t, outputRead: Int32, outputWrite: Int32
) throws -> Int32 {
    var actions: posix_spawn_file_actions_t?
    guard posix_spawn_file_actions_init(&actions) == 0 else {
        throw ProbeError.invalid("sudo actions init")
    }
    defer { posix_spawn_file_actions_destroy(&actions) }
    guard
        posix_spawn_file_actions_addinherit_np(&actions, STDIN_FILENO) == 0,
        posix_spawn_file_actions_adddup2(&actions, outputWrite, STDOUT_FILENO) == 0,
        posix_spawn_file_actions_addinherit_np(&actions, STDERR_FILENO) == 0,
        posix_spawn_file_actions_addclose(&actions, outputRead) == 0,
        posix_spawn_file_actions_addclose(&actions, outputWrite) == 0
    else { throw ProbeError.invalid("sudo actions") }
    var attributes: posix_spawnattr_t?
    guard posix_spawnattr_init(&attributes) == 0 else {
        throw ProbeError.invalid("sudo attributes init")
    }
    defer { posix_spawnattr_destroy(&attributes) }
    var mask = try signalSet([])
    var defaults = try signalSet(
        forwardedSignals + [SIGTTOU, SIGTTIN, SIGTSTP, SIGPIPE]
    )
    let flags = Int16(
        POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_START_SUSPENDED
            | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF
    )
    guard
        posix_spawnattr_setflags(&attributes, flags) == 0,
        posix_spawnattr_setsigmask(&attributes, &mask) == 0,
        posix_spawnattr_setsigdefault(&attributes, &defaults) == 0
    else { throw ProbeError.invalid("sudo attributes") }
    return try cStrings(sudoArguments) { arguments in
        try cStrings([]) { environment in
            "/usr/bin/sudo".withCString { path in
                posix_spawn(
                    &processID, path, &actions, &attributes, arguments, environment
                )
            }
        }
    }
}

private func optionalIdentity(
    _ processID: pid_t
) throws -> (Identity?, Int32) {
    var value = proc_bsdinfo()
    let count = proc_pidinfo(
        processID, PROC_PIDTBSDINFO, 0, &value,
        Int32(MemoryLayout<proc_bsdinfo>.size)
    )
    if count == 0 { return (nil, errno) }
    guard
        count == MemoryLayout<proc_bsdinfo>.size,
        value.pbi_pid == UInt32(processID), value.pbi_ppid > 0,
        value.pbi_pgid > 1, value.pbi_start_tvsec > 0,
        value.pbi_start_tvusec < 1_000_000
    else { throw ProbeError.invalid("invalid child identity") }
    return (Identity(
        processID: processID, parentProcessID: pid_t(value.pbi_ppid),
        processGroupID: pid_t(value.pbi_pgid), sessionID: getsid(processID),
        startSeconds: value.pbi_start_tvsec,
        startMicroseconds: value.pbi_start_tvusec, status: value.pbi_status
    ), 0)
}

private func optionalKernelIdentity(
    _ processID: pid_t
) throws -> (Identity?, Int32) {
    var value = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.size
    var mib = [CTL_KERN, KERN_PROC, KERN_PROC_PID, processID]
    errno = 0
    let result = mib.withUnsafeMutableBufferPointer { pointer in
        sysctl(
            pointer.baseAddress, u_int(pointer.count), &value, &size, nil, 0
        )
    }
    if result != 0 { return (nil, errno) }
    if size == 0 { return (nil, ESRCH) }
    guard
        size == MemoryLayout<kinfo_proc>.size,
        value.kp_proc.p_pid == processID, value.kp_eproc.e_ppid > 0,
        value.kp_eproc.e_pgid > 1, value.kp_proc.p_starttime.tv_sec > 0,
        value.kp_proc.p_starttime.tv_usec >= 0,
        value.kp_proc.p_starttime.tv_usec < 1_000_000
    else { throw ProbeError.invalid("invalid kernel child identity") }
    return (Identity(
        processID: processID, parentProcessID: value.kp_eproc.e_ppid,
        processGroupID: value.kp_eproc.e_pgid, sessionID: getsid(processID),
        startSeconds: UInt64(value.kp_proc.p_starttime.tv_sec),
        startMicroseconds: UInt64(value.kp_proc.p_starttime.tv_usec),
        status: UInt32(value.kp_proc.p_stat)
    ), 0)
}

private func waitInitialState(
    _ processID: pid_t, deadline: UInt64
) throws -> (processID: pid_t, status: Int32?) {
    while try now() < deadline {
        var status: Int32 = 0
        let result = waitpid(processID, &status, WUNTRACED | WNOHANG)
        if result == processID { return (result, status) }
        if result < 0, errno != EINTR { throw posix("wait initial state") }
        try pause(deadline)
    }
    return (0, nil)
}

private func processGroupMembers(_ group: pid_t) throws -> [pid_t] {
    var values = [pid_t](repeating: 0, count: 64)
    let count = values.withUnsafeMutableBytes { buffer in
        proc_listpids(
            UInt32(PROC_PGRP_ONLY), UInt32(bitPattern: group),
            buffer.baseAddress, Int32(buffer.count)
        )
    }
    guard
        count >= 0, Int(count) < values.count * MemoryLayout<pid_t>.stride,
        Int(count).isMultiple(of: MemoryLayout<pid_t>.stride)
    else { throw posix("group inventory") }
    return values.prefix(Int(count) / MemoryLayout<pid_t>.stride)
        .filter { $0 > 1 }.sorted()
}

private func makePipe() throws -> (read: Int32, write: Int32) {
    var values: [Int32] = [-1, -1]
    guard pipe(&values) == 0 else { throw posix("pipe") }
    do {
        try setCloseOnExec(values[0])
        try setCloseOnExec(values[1])
        return (values[0], values[1])
    } catch {
        _ = close(values[0])
        _ = close(values[1])
        throw error
    }
}

private func setCloseOnExec(_ descriptor: Int32) throws {
    let flags = fcntl(descriptor, F_GETFD)
    guard
        flags >= 0, fcntl(descriptor, F_SETFD, flags | FD_CLOEXEC) == 0
    else { throw posix("set close-on-exec") }
}

private func closeDescriptor(_ descriptor: inout Int32) {
    if descriptor >= 0 {
        _ = close(descriptor)
        descriptor = -1
    }
}

private func setForeground(_ group: pid_t, descriptor: Int32) throws {
    while tcsetpgrp(descriptor, group) != 0 {
        if errno != EINTR { throw posix("tcsetpgrp") }
    }
}

private func readToEOF(_ descriptor: Int32, deadline: UInt64) throws -> Data {
    var result = Data()
    while try now() < deadline {
        var item = pollfd(
            fd: descriptor, events: Int16(POLLIN | POLLHUP), revents: 0
        )
        let polled = poll(&item, 1, 50)
        if polled == 0 { continue }
        if polled < 0, errno == EINTR { continue }
        guard polled > 0, item.revents & Int16(POLLERR | POLLNVAL) == 0 else {
            throw posix("poll")
        }
        var bytes = [UInt8](repeating: 0, count: 4096)
        let count = read(descriptor, &bytes, bytes.count)
        if count > 0 {
            result.append(contentsOf: bytes.prefix(count))
            continue
        }
        if count == 0 { return result }
        if errno != EINTR { throw posix("read") }
    }
    throw ProbeError.timeout("read EOF")
}

private func readAvailable(_ descriptor: Int32, deadline: UInt64) throws -> Data {
    var result = Data()
    while try now() < deadline {
        var item = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
        let polled = poll(&item, 1, 0)
        if polled == 0 { return result }
        if polled < 0, errno == EINTR { continue }
        guard polled > 0, item.revents & Int16(POLLERR | POLLNVAL) == 0 else {
            throw posix("terminal poll")
        }
        var bytes = [UInt8](repeating: 0, count: 4096)
        let count = read(descriptor, &bytes, bytes.count)
        if count > 0 {
            result.append(contentsOf: bytes.prefix(count))
            continue
        }
        if count == 0 { return result }
        if errno != EINTR { throw posix("terminal read") }
    }
    throw ProbeError.timeout("terminal read")
}

private func writeAll(_ descriptor: Int32, _ data: Data) throws {
    try data.withUnsafeBytes { buffer in
        var offset = 0
        while offset < buffer.count {
            let count = write(
                descriptor, buffer.baseAddress?.advanced(by: offset),
                buffer.count - offset
            )
            if count > 0 { offset += count; continue }
            if count < 0, errno == EINTR { continue }
            throw posix("write")
        }
    }
}

private func waitProcess(
    _ processID: pid_t, options: Int32, deadline: UInt64
) throws -> Int32 {
    while try now() < deadline {
        var status: Int32 = 0
        let result = waitpid(processID, &status, options | WNOHANG)
        if result == processID { return status }
        if result == 0 || (result < 0 && errno == EINTR) {
            try pause(deadline)
            continue
        }
        throw posix("wait process")
    }
    throw ProbeError.timeout("wait process")
}

private func signalSet(_ signals: [Int32]) throws -> sigset_t {
    var value = sigset_t()
    guard sigemptyset(&value) == 0 else { throw posix("sigemptyset") }
    for signal in signals where sigaddset(&value, signal) != 0 {
        throw posix("sigaddset")
    }
    return value
}

private func cStrings<T>(
    _ values: [String],
    _ body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws -> T
) throws -> T {
    var storage = values.map { strdup($0) }
    guard storage.allSatisfy({ $0 != nil }) else {
        throw ProbeError.invalid("strdup failed")
    }
    defer { storage.compactMap { $0 }.forEach { free($0) } }
    storage.append(nil)
    return try storage.withUnsafeMutableBufferPointer { buffer in
        try body(buffer.baseAddress!)
    }
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
    guard mach_timebase_info(&info) == KERN_SUCCESS, info.denom > 0 else {
        throw ProbeError.invalid("invalid timebase")
    }
    let product = mach_continuous_time().multipliedFullWidth(
        by: UInt64(info.numer)
    )
    guard product.high < UInt64(info.denom) else {
        throw ProbeError.invalid("time overflow")
    }
    return UInt64(info.denom).dividingFullWidth(product).quotient
}

private func adding(_ delta: UInt64, to value: UInt64) throws -> UInt64 {
    let result = value.addingReportingOverflow(delta)
    guard !result.overflow else { throw ProbeError.invalid("deadline overflow") }
    return result.partialValue
}

private func exited(_ status: Int32) -> Int32? {
    status & 0x7f == 0 ? (status >> 8) & 0xff : nil
}

private func posix(_ operation: String) -> ProbeError {
    .posix(operation, errno)
}
