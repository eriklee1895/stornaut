import Darwin
import Foundation
import StornautInvestigationHandoffContract
import StornautInvestigationMachineGateSupport

#if DEBUG
extension InvestigationFixedGateHandoff {
    package convenience init() { self.init(system: DarwinInvestigationFixedGateHandoffSystem()) }
}

enum InvestigationFixedGateDarwinProjectionStage: Sendable {
    case initial, published, spawned, prepared, stopped, continued
    case terminal, reaped, empty, closed, settled

    var allowsExactGateReplay: Bool {
        switch self {
        case .spawned, .prepared, .stopped, .continued, .terminal: true
        case .initial, .published, .reaped, .empty, .closed, .settled: false
        }
    }
}

private final class DarwinInvestigationFixedGateHandoffSystem: @unchecked Sendable, InvestigationFixedGateHandoffSystem {
    private typealias Stage = InvestigationFixedGateDarwinProjectionStage
    private let publisher = InvestigationOwnerOnlyCapsulePublisher()
    private let lifecycle = InvestigationFixedGateDarwinLifecycle(system: DarwinInvestigationFixedGateLifecycleSystem())
    private var stage = Stage.initial
    private var lease: InvestigationOwnerOnlyCapsuleLease?
    private var replay: InvestigationFixedGateDarwinLifecycleReplay?
    private var exactProof: InvestigationOwnerOnlyCapsuleExactGateReapedProof?
    private var neverProof: InvestigationOwnerOnlyCapsuleNeverHandedOffProof?

    func perform(_ operation: InvestigationFixedGateHandoffOperation) throws -> InvestigationFixedGateHandoffResponse {
        switch operation {
        case .publishCanonicalCapsule(let bytes):
            guard stage == .initial else { throw unexpected() }
            do { lease = try publisher.publish(bytes) } catch { throw InvestigationFixedGateHandoffSystemError.publicationFailed }
            guard let lease else { throw unexpected() }; stage = .published
            return .publishedCapsule(outerAttemptUUID: lease.outerAttemptUUID, wholeInputSHA256: lease.digest, node: .init(device: lease.identity.device, inode: lease.identity.inode, generation: lease.identity.generation, size: lease.identity.size))
        case .spawnFixedGate:
            guard stage == .published, let lease else { throw unexpected() }
            switch try lease.handoffOutcomeOnce(using: lifecycle) {
            case .definitelyNotSpawned(let proof): neverProof = proof; throw InvestigationFixedGateHandoffSystemError.preSpawnNoTransfer
            case .spawnOrTransferUncertain:
                let value = lifecycle.replay
                throw InvestigationFixedGateHandoffSystemError.spawnUncertain(processID: value?.gateProcessID ?? 0, processGroupID: value?.gateProcessGroupID ?? 0)
            case .exactGateReaped(let proof):
                exactProof = proof; replay = lifecycle.replay
                guard let replay, replay.gateProcessID > 1 else { throw unexpected() }
                stage = .spawned
                return .spawnedGate(processID: replay.gateProcessID, processGroupID: replay.gateProcessGroupID, executableSHA256: replay.executableSHA256)
            }
        case .observeSpawnedProcess:
            // The lifecycle already attempted bounded cleanup; a stale PID is not liveness proof.
            return .processExists(false)
        case .readPreparedFrame(let maximum):
            guard stage == .spawned, maximum == InvestigationMachineGatePreparedFrame.maximumByteCount, let replay else { throw unexpected() }
            stage = .prepared; let value = try replay.requiredFrame(
                replay.prepared,
                observedTermination: replay.preparedReadTermination
            )
            return .frame(bytes: value.bytes, reachedEOF: value.reachedEOF, overflowObserved: value.overflowObserved)
        case .observePreparedStop(let pid):
            guard stage == .prepared, pid == replay?.gateProcessID, let value = replay?.preparedStop else { throw unexpected() }
            stage = .stopped; return .waitClassification(value)
        case .continueFixedGate(let pid):
            guard stage == .stopped, pid == replay?.gateProcessID else { throw unexpected() }
            stage = .continued; return .completed
        case .readTerminalReceipt(let maximum):
            guard stage == .continued, maximum == InvestigationMachineGateTransportReceipt.maximumByteCount, let replay else { throw unexpected() }
            stage = .terminal
            let value = try replay.projectedTerminalFrame()
            return .frame(bytes: value.bytes, reachedEOF: value.reachedEOF, overflowObserved: value.overflowObserved)
        case .waitForExactGate(let pid):
            guard stage.allowsExactGateReplay, pid == replay?.gateProcessID, let replay, let wait = replay.terminalWait else { throw unexpected() }
            stage = .reaped; return .exactGateReap(waitClassification: wait, exactChildReaped: replay.exactGateReaped)
        case .observeGateProcessGroupEmpty(let group):
            guard stage == .reaped, group == replay?.gateProcessGroupID, let replay else { throw unexpected() }
            stage = .empty; return .processGroupEmpty(replay.processGroupEmpty)
        case .closeTransport:
            guard stage == .empty || stage == .published else { throw unexpected() }
            guard stage == .published || replay?.transportCloseCertain == true else { throw InvestigationFixedGateHandoffSystemError.closeUncertain }
            stage = .closed; return .completed
        case .settleExactGateReaped:
            guard stage == .closed, let lease, let exactProof else { throw unexpected() }
            return try settle { try lease.settle(exactGateReaped: exactProof) }
        case .settleNeverHandedOff:
            guard let lease else { throw unexpected() }
            let proof = try neverProof ?? lease.finishWithoutHandoff(); neverProof = proof
            return try settle { try lease.settle(neverHandedOff: proof) }
        }
    }

    private func settle(_ body: () throws -> InvestigationOwnerOnlyCapsuleSettlementResult) throws -> InvestigationFixedGateHandoffResponse {
        do { let value = try body(); stage = .settled; return .settlement(value) }
        catch let error as InvestigationOwnerOnlyCapsuleError {
            if case .proofRejected = error { throw InvestigationFixedGateHandoffSystemError.proofRejected }
            throw InvestigationFixedGateHandoffSystemError.settlementFailed
        } catch { throw InvestigationFixedGateHandoffSystemError.settlementFailed }
    }
    private func unexpected() -> InvestigationFixedGateHandoffSystemError { .unexpectedResponse }
}

private final class DarwinInvestigationFixedGateLifecycleSystem: @unchecked Sendable, InvestigationFixedGateDarwinLifecycleSystem {
    private let pollMilliseconds: Int32 = 10
    private var gatePath: String?
    private var gatePID: pid_t = 0

    func perform(_ operation: InvestigationFixedGateDarwinLifecycleOperation) throws -> InvestigationFixedGateDarwinLifecycleResponse {
        switch operation {
        case .observeCoordinator:
            let pid = getpid(), group = getpgrp(), session = getsid(0); try verifySignalMask()
            return .coordinator(.init(processID: pid, processGroupID: group, sessionID: session, terminal: try terminal()))
        case .makeAbsoluteDeadline(let duration): return .absoluteDeadline(try adding(duration, to: monotonic()))
        case .acquireSiblingExecutable(let name, let maximum): return .gateExecutable(try acquire(name, maximum))
        case .makeTransportPipe: return .descriptorPair(try makePipe())
        case .revalidateGateExecutable(let fd):
            guard let path = gatePath else { throw uncertain() }; return .gateExecutable(try executable(fd, path, 64 << 20))
        case .spawnGate(let request): return .spawn(try spawn(request))
        case .closeDescriptor(let fd): guard Darwin.close(fd) == 0 else { throw posix() }; return .completed
        case .readPrepared(let fd, let maximum, let deadline): return try readFrame(fd, maximum, InvestigationMachineGatePreparedFrame.encodedByteCount, deadline, false)
        case .waitPreparedStop(let pid, let deadline): return .wait(try waitStop(pid, deadline))
        case .observeGateTopology: return .topology(try topology())
        case .observeTTY: return .terminal(try terminal())
        case .consumeForwardedSignal(let deadline): return .signal(try consumeSignal(deadline))
        case .signalProcess(let pid, let signal): guard Darwin.kill(pid, signal) == 0 else { throw posix() }; return .completed
        case .readTerminal(let fd, let maximum, let deadline): return try readFrame(fd, maximum, InvestigationMachineGateTransportReceipt.encodedByteCount, deadline, true)
        case .waitID(let pid, let options, let deadline): return .wait(try waitID(pid, options, deadline))
        case .restoreForeground(let group):
            guard tcsetpgrp(STDERR_FILENO, group) == 0 else { throw posix() }
            guard tcgetpgrp(STDERR_FILENO) == group else { throw uncertain() }; return .completed
        case .inventoryProcessGroup(let group, let maximum, let deadline): return .inventory(try inventory(group, maximum, deadline))
        case .signalProcessGroup(let group, let signal):
            guard group > 1, group != getpgrp() else { throw uncertain() }
            if Darwin.kill(-group, signal) != 0, errno != ESRCH { throw posix() }; return .completed
        case .waitPID(let pid, let options, let deadline): return .wait(try waitPID(pid, options, deadline))
        }
    }

    private func acquire(_ name: String, _ maximum: Int) throws -> InvestigationFixedGateDarwinExecutableObservation {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let count = proc_pidpath(getpid(), &buffer, UInt32(buffer.count))
        guard count > 0, count < buffer.count, let path = String(validating: buffer.prefix(Int(count)).map(UInt8.init(bitPattern:)), as: UTF8.self) else { throw uncertain() }
        let sibling = URL(fileURLWithPath: path).deletingLastPathComponent().appendingPathComponent(name, isDirectory: false).path
        let fd = Darwin.open(sibling, O_RDONLY | O_CLOEXEC | O_NONBLOCK | O_NOFOLLOW_ANY | O_UNIQUE)
        guard fd >= 0 else { throw posix() }
        do {
            guard fd >= 3 else { throw uncertain() }
            let value = try executable(fd, sibling, maximum); gatePath = sibling; return value
        } catch {
            let saved = error
            guard closeOwned([fd]) else { throw InvestigationFixedGateDarwinLifecycleSystemError.preSpawnCleanupUncertain }
            throw saved
        }
    }

    private func makePipe() throws -> InvestigationFixedGateDarwinDescriptorPair {
        var pair = [Int32](repeating: -1, count: 2); guard pipe(&pair) == 0 else { throw posix() }
        do {
            guard pair[0] >= 3, pair[1] >= 3, pair[0] != pair[1] else { throw uncertain() }
            try closeOnExec(pair[0]); try closeOnExec(pair[1]); let flags = fcntl(pair[0], F_GETFL)
            guard flags >= 0, fcntl(pair[0], F_SETFL, flags | O_NONBLOCK) == 0, fcntl(pair[1], F_SETNOSIGPIPE, 1) == 0 else { throw posix() }
            return .init(read: pair[0], write: pair[1])
        } catch {
            let saved = error
            guard closeOwned(pair) else { throw InvestigationFixedGateDarwinLifecycleSystemError.preSpawnCleanupUncertain }
            throw saved
        }
    }

    private func spawn(_ request: InvestigationFixedGateDarwinSpawnRequest) throws -> InvestigationFixedGateDarwinSpawnOutcome {
        guard request.flags & Int16(POSIX_SPAWN_START_SUSPENDED) == 0 else { return .definitelyNotSpawned }
        var actions: posix_spawn_file_actions_t?, attributes: posix_spawnattr_t?
        guard posix_spawn_file_actions_init(&actions) == 0 else { return .definitelyNotSpawned }; defer { posix_spawn_file_actions_destroy(&actions) }
        for action in request.fileActions {
            let result: Int32 = switch action {
            case .duplicate(let source, let destination): posix_spawn_file_actions_adddup2(&actions, source, destination)
            case .inherit(let fd): posix_spawn_file_actions_addinherit_np(&actions, fd)
            case .close(let fd): posix_spawn_file_actions_addclose(&actions, fd)
            }; guard result == 0 else { return .definitelyNotSpawned }
        }
        guard posix_spawnattr_init(&attributes) == 0 else { return .definitelyNotSpawned }; defer { posix_spawnattr_destroy(&attributes) }
        var mask = sigset_t(), defaults = sigset_t()
        guard sigemptyset(&mask) == 0, sigemptyset(&defaults) == 0, request.signalMask.allSatisfy({ sigaddset(&mask, $0) == 0 }), request.signalDefaults.allSatisfy({ sigaddset(&defaults, $0) == 0 }), posix_spawnattr_setpgroup(&attributes, request.processGroupID) == 0, posix_spawnattr_setsigmask(&attributes, &mask) == 0, posix_spawnattr_setsigdefault(&attributes, &defaults) == 0, posix_spawnattr_setflags(&attributes, request.flags) == 0 else { return .definitelyNotSpawned }
        var pid: pid_t = 0
        let result = try cStrings(request.arguments) { argv in try cStrings(request.environment) { env in request.executablePath.withCString { posix_spawn(&pid, $0, &actions, &attributes, argv, env) } } }
        guard result == 0 else { return .definitelyNotSpawned }; gatePID = pid
        return pid > 1 ? .spawned(processID: pid, processGroupID: pid) : .spawnOrTransferUncertain(processID: pid, processGroupID: pid)
    }

    private typealias Security = (fdACL: Bool, fdXattrs: [String], pathACL: Bool, pathXattrs: [String])
    private func executable(_ fd: Int32, _ path: String, _ maximum: Int) throws -> InvestigationFixedGateDarwinExecutableObservation {
        var held = stat(), named = stat()
        guard fstat(fd, &held) == 0, lstat(path, &named) == 0, held.st_mode & S_IFMT == S_IFREG, named.st_mode & S_IFMT == S_IFREG, same(held, named), held.st_size > 0, held.st_size <= maximum else { throw uncertain() }
        let first = try security(fd, path), bytes = try readExactly(fd, held.st_size); try requireEOF(fd, held.st_size)
        let last = try security(fd, path); var finalHeld = stat(), finalNamed = stat()
        guard fstat(fd, &finalHeld) == 0, lstat(path, &finalNamed) == 0, same(held, finalHeld), same(named, finalNamed), same(finalHeld, finalNamed), first.fdACL == last.fdACL, first.pathACL == last.pathACL, first.fdXattrs == last.fdXattrs, first.pathXattrs == last.pathXattrs, last.fdACL == last.pathACL, last.fdXattrs == last.pathXattrs else { throw uncertain() }
        let digest = InvestigationHandoffSHA256.hashing(bytes)
        return .init(descriptor: fd, path: path, descriptorIdentity: identity(finalHeld), namedIdentity: identity(finalNamed), ownerUserID: finalHeld.st_uid, ownerGroupID: finalHeld.st_gid, permissions: finalHeld.st_mode & 0o7777, linkCount: UInt64(finalHeld.st_nlink), flags: finalHeld.st_flags, extendedACLIsEmpty: last.fdACL, extendedAttributeNames: last.fdXattrs, sha256: digest, bytesSHA256: digest)
    }

    private func readFrame(_ fd: Int32, _ maximum: Int, _ exact: Int, _ deadline: UInt64, _ requireEOF: Bool) throws -> InvestigationFixedGateDarwinLifecycleResponse {
        guard maximum >= exact, exact > 0 else { throw uncertain() }; var data = Data(), eof = false
        while monotonic() < deadline, data.count <= maximum, !requireEOF || !eof {
            let capacity = min(513, maximum + 1 - data.count)
            var bytes = [UInt8](repeating: 0, count: capacity); let count = Darwin.read(fd, &bytes, bytes.count)
            if count > 0 { data.append(contentsOf: bytes.prefix(count)); if !requireEOF, data.count >= exact { break }; continue }
            if count == 0 { eof = true; break }; if errno == EINTR { continue }
            guard errno == EAGAIN || errno == EWOULDBLOCK else { throw posix() }
            if let wait = try waitable(gatePID, deadline: deadline), terminalWait(wait.classification) { return .gateTerminated(wait) }
            try pollReadable(fd, deadline)
        }
        return .frame(.init(bytes: data, reachedEOF: eof, overflowObserved: data.count > maximum))
    }

    private func waitStop(_ pid: pid_t, _ deadline: UInt64) throws -> InvestigationFixedGateDarwinWaitObservation {
        while monotonic() < deadline {
            if let value = try waitable(pid, deadline: deadline), value.classification == .stopped(signal: SIGSTOP) || terminalWait(value.classification) { return value }
            try pause(deadline)
        }; throw uncertain()
    }
    private func waitID(_ pid: pid_t, _ options: Int32, _ deadline: UInt64) throws -> InvestigationFixedGateDarwinWaitObservation {
        guard options & Int32(WNOHANG) != 0 else { throw uncertain() }
        while monotonic() < deadline { if let value = try waitable(pid, options: options, deadline: deadline) { return value }; try pause(deadline) }; throw uncertain()
    }
    private func waitPID(_ pid: pid_t, _ options: Int32, _ deadline: UInt64) throws -> InvestigationFixedGateDarwinWaitObservation {
        guard pid > 1, options & Int32(WNOHANG) != 0 else { throw uncertain() }
        while monotonic() < deadline {
            var status: Int32 = 0; let result = waitpid(pid, &status, options)
            if result == pid { return .init(processID: pid, classification: try classify(status), waitableWithoutReap: false) }
            if result < 0, errno != EINTR { throw posix() }; if result == 0 { try pause(deadline) }
        }; throw uncertain()
    }
    private func waitable(_ pid: pid_t, options: Int32 = Int32(WEXITED | WSTOPPED | WNOHANG | WNOWAIT), deadline: UInt64) throws -> InvestigationFixedGateDarwinWaitObservation? {
        guard pid > 1, options & Int32(WNOHANG) != 0 else { throw uncertain() }
        while monotonic() < deadline {
            var info = siginfo_t()
            if waitid(P_PID, UInt32(bitPattern: pid), &info, options) == 0 {
                guard info.si_pid != 0 else { return nil }
                let state: InvestigationMachineGateWaitClassification = switch info.si_code { case CLD_EXITED: .exited(status: info.si_status); case CLD_KILLED, CLD_DUMPED: .signaled(signal: info.si_status); case CLD_STOPPED: .stopped(signal: info.si_status); default: throw uncertain() }
                return .init(processID: pid_t(info.si_pid), classification: state, waitableWithoutReap: options & Int32(WNOWAIT) != 0)
            }; if errno != EINTR { throw posix() }
        }; throw uncertain()
    }

    private func topology() throws -> InvestigationFixedGateDarwinTopologyObservation {
        let parent = getpid(), coordinatorGroup = getpgrp(), session = getsid(gatePID); var info = proc_bsdinfo()
        let count = proc_pidinfo(gatePID, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout<proc_bsdinfo>.size))
        guard gatePID > 1, parent > 1, coordinatorGroup > 1, session > 1, count == MemoryLayout<proc_bsdinfo>.size, info.pbi_pid == UInt32(gatePID), info.pbi_ppid == UInt32(parent), info.pbi_pgid > 1, info.pbi_start_tvsec > 0, info.pbi_start_tvusec < 1_000_000 else { throw uncertain() }
        return .init(gateProcessID: gatePID, parentProcessID: pid_t(info.pbi_ppid), gateProcessGroupID: pid_t(info.pbi_pgid), gateSessionID: session, gateStartSeconds: info.pbi_start_tvsec, gateStartMicroseconds: info.pbi_start_tvusec, coordinatorProcessGroupID: coordinatorGroup)
    }
    private func inventory(_ group: pid_t, _ maximum: Int, _ deadline: UInt64) throws -> InvestigationFixedGateDarwinInventoryObservation {
        guard group > 1, maximum > 0, monotonic() < deadline else { throw uncertain() }; var values = [pid_t](repeating: 0, count: maximum)
        let count = values.withUnsafeMutableBytes { proc_listpids(UInt32(PROC_PGRP_ONLY), UInt32(bitPattern: group), $0.baseAddress, Int32($0.count)) }
        guard count >= 0, Int(count) <= values.count * MemoryLayout<pid_t>.size, Int(count).isMultiple(of: MemoryLayout<pid_t>.size) else { throw uncertain() }
        let itemCount = Int(count) / MemoryLayout<pid_t>.size, pids = Array(values.prefix(itemCount)).sorted()
        if !pids.isEmpty { try pause(deadline) }; return .init(processIDs: pids, complete: itemCount < maximum)
    }
    private func consumeSignal(_ deadline: UInt64) throws -> Int32? {
        guard monotonic() < deadline else { throw uncertain() }; var pending = sigset_t(); guard sigpending(&pending) == 0 else { throw posix() }
        for signal in InvestigationMachineFixedGateContract.forwardedSignals where sigismember(&pending, signal) == 1 {
            guard monotonic() < deadline else { throw uncertain() }; var one = sigset_t(), observed: Int32 = 0
            guard sigemptyset(&one) == 0, sigaddset(&one, signal) == 0 else { throw posix() }
            let result = sigwait(&one, &observed); guard result == 0 else { throw InvestigationFixedGateDarwinLifecycleSystemError.errno(result) }
            guard observed == signal, monotonic() <= deadline else { throw uncertain() }; return signal
        }; return nil
    }

    private func security(_ fd: Int32, _ path: String) throws -> Security { (try aclEmpty(fd), try xattrs(fd), try aclEmpty(path), try xattrs(path)) }
    private func aclEmpty(_ fd: Int32) throws -> Bool {
        errno = 0; guard let acl = acl_get_fd_np(fd, ACL_TYPE_EXTENDED) else { if errno == ENOENT { return true }; throw posix() }; return try inspectACL(acl)
    }
    private func aclEmpty(_ path: String) throws -> Bool {
        errno = 0; guard let acl = acl_get_link_np(path, ACL_TYPE_EXTENDED) else { if errno == ENOENT { return true }; throw posix() }; return try inspectACL(acl)
    }
    private func inspectACL(_ acl: acl_t) throws -> Bool {
        var entry: acl_entry_t?; errno = 0; let result = acl_get_entry(acl, Int32(ACL_FIRST_ENTRY.rawValue), &entry), entryError = errno
        errno = 0; let freed = acl_free(UnsafeMutableRawPointer(acl)), freeError = errno
        if freed != 0 { throw InvestigationFixedGateDarwinLifecycleSystemError.errno(freeError) }; if result < 0 { throw InvestigationFixedGateDarwinLifecycleSystemError.errno(entryError) }
        guard result != 0 || entry != nil else { throw uncertain() }; return result != 0
    }
    private func xattrs(_ fd: Int32) throws -> [String] {
        let count = flistxattr(fd, nil, 0, 0); guard count >= 0 else { throw posix() }; guard count <= 4_096 else { throw uncertain() }; if count == 0 { return [] }
        var bytes = [CChar](repeating: 0, count: count); guard flistxattr(fd, &bytes, bytes.count, 0) == count else { throw posix() }; return try names(bytes)
    }
    private func xattrs(_ path: String) throws -> [String] {
        let count = listxattr(path, nil, 0, XATTR_NOFOLLOW); guard count >= 0 else { throw posix() }; guard count <= 4_096 else { throw uncertain() }; if count == 0 { return [] }
        var bytes = [CChar](repeating: 0, count: count); guard listxattr(path, &bytes, bytes.count, XATTR_NOFOLLOW) == count else { throw posix() }; return try names(bytes)
    }
    private func names(_ bytes: [CChar]) throws -> [String] {
        guard bytes.last == 0 else { throw uncertain() }; return try bytes.split(separator: 0).map { slice in
            let raw = slice.map(UInt8.init(bitPattern:)); guard !raw.isEmpty, let value = String(bytes: raw, encoding: .utf8), value.utf8.count == raw.count else { throw uncertain() }; return value
        }.sorted()
    }
    private func readExactly(_ fd: Int32, _ size: Int64) throws -> Data {
        guard let count = Int(exactly: size) else { throw uncertain() }; var data = Data(count: count), offset = 0
        while offset < count {
            let value = data.withUnsafeMutableBytes { pread(fd, $0.baseAddress?.advanced(by: offset), count - offset, off_t(offset)) }
            if value > 0, value <= count - offset { offset += value; continue }; if value < 0, errno == EINTR { continue }; if value < 0 { throw posix() }; throw uncertain()
        }; return data
    }
    private func requireEOF(_ fd: Int32, _ offset: Int64) throws {
        var byte: UInt8 = 0
        while true { let value = pread(fd, &byte, 1, off_t(offset)); if value == 0 { return }; if value < 0, errno == EINTR { continue }; if value < 0 { throw posix() }; throw uncertain() }
    }

    private func terminal() throws -> InvestigationMachineGateTerminalObservation {
        var value = stat(); guard fstat(STDERR_FILENO, &value) == 0, value.st_mode & S_IFMT == S_IFCHR else { throw uncertain() }
        let group = tcgetpgrp(STDERR_FILENO); guard group > 1 else { throw uncertain() }; return .init(device: UInt64(bitPattern: Int64(value.st_dev)), inode: UInt64(value.st_ino), foregroundProcessGroupID: group)
    }
    private func identity(_ value: stat) -> InvestigationFixedGateDarwinNodeIdentity { .init(device: UInt64(bitPattern: Int64(value.st_dev)), inode: UInt64(value.st_ino), generation: UInt64(value.st_gen), size: value.st_size) }
    private func same(_ lhs: stat, _ rhs: stat) -> Bool { identity(lhs) == identity(rhs) && lhs.st_mode == rhs.st_mode && lhs.st_uid == rhs.st_uid && lhs.st_gid == rhs.st_gid && lhs.st_nlink == rhs.st_nlink && lhs.st_flags == rhs.st_flags }
    private func verifySignalMask() throws {
        var observed = sigset_t(); guard pthread_sigmask(SIG_BLOCK, nil, &observed) == 0 else { throw posix() }
        let required = InvestigationMachineFixedGateContract.forwardedSignals + [SIGTTIN, SIGTTOU, SIGTSTP]; guard required.allSatisfy({ sigismember(&observed, $0) == 1 }) else { throw uncertain() }
    }
    private func closeOnExec(_ fd: Int32) throws { let value = fcntl(fd, F_GETFD); guard value >= 0, fcntl(fd, F_SETFD, value | FD_CLOEXEC) == 0 else { throw posix() } }
    private func closeOwned(_ descriptors: [Int32]) -> Bool {
        var result = true, seen = Set<Int32>(); for fd in descriptors where fd >= 0 && seen.insert(fd).inserted { if Darwin.close(fd) != 0 { result = false } }; return result
    }
    private func pollReadable(_ fd: Int32, _ deadline: UInt64) throws {
        while true { var item = pollfd(fd: fd, events: Int16(POLLIN | POLLHUP), revents: 0); let result = poll(&item, 1, try timeout(deadline)); if result >= 0 { guard item.revents & Int16(POLLERR | POLLNVAL) == 0 else { throw uncertain() }; return }; if errno != EINTR { throw posix() } }
    }
    private func pause(_ deadline: UInt64) throws { while Darwin.poll(nil, 0, try timeout(deadline)) < 0 { if errno != EINTR { throw posix() } } }
    private func timeout(_ deadline: UInt64) throws -> Int32 { let now = monotonic(); guard now < deadline else { throw uncertain() }; let value = min(UInt64(pollMilliseconds), (deadline - now) / 1_000_000); guard value > 0 else { throw uncertain() }; return Int32(value) }
    private func monotonic() -> UInt64 { DispatchTime.now().uptimeNanoseconds }
    private func adding(_ duration: UInt64, to value: UInt64) throws -> UInt64 { let result = value.addingReportingOverflow(duration); guard !result.overflow else { throw uncertain() }; return result.partialValue }
    private func classify(_ status: Int32) throws -> InvestigationMachineGateWaitClassification { let low = status & 0x7f; if low == 0 { return .exited(status: status >> 8 & 0xff) }; if low == 0x7f { return .stopped(signal: status >> 8 & 0xff) }; guard low > 0 && low < NSIG else { throw uncertain() }; return .signaled(signal: low) }
    private func posix() -> InvestigationFixedGateDarwinLifecycleSystemError { .errno(errno) }
    private func uncertain() -> InvestigationFixedGateDarwinLifecycleSystemError { .uncertain }
    private func cStrings<Result>(_ strings: [String], body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws -> Result) throws -> Result {
        var values: [UnsafeMutablePointer<CChar>?] = []; defer { values.compactMap { $0 }.forEach { free($0) } }
        for string in strings { guard let value = strdup(string) else { throw uncertain() }; values.append(value) }; values.append(nil)
        return try values.withUnsafeMutableBufferPointer { try body($0.baseAddress!) }
    }
}

private func terminalWait(_ value: InvestigationMachineGateWaitClassification) -> Bool { switch value { case .exited, .signaled: true; case .stopped: false } }
#endif
