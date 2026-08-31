import CInvestigationIdentitySupport
import CInvestigationMachineCampaignSupport
import Darwin
import Dispatch
import Foundation

#if DEBUG
import StornautInvestigationMachineCampaignSupport

package enum InvestigationMachineCampaignExecutable {
    private static let coordinatorName =
        "StornautInvestigationMachineCampaignCoordinator"
    private static let deadlineWindowNanoseconds: UInt64 = 5_000_000_000
    private static let completedExitStatus: Int32 = 0
    private static let failedExitStatus: Int32 = 70

    package static func run() async -> Int32 {
        let system = CampaignDarwinSystem()
        if system.isBootstrapInvocation { return system.runBootstrap() }
        guard CommandLine.argc == 1 else {
            return failedExitStatus
        }
        let outcome = await InvestigationMachineCampaignHarness(
            system: system).run(expected: expectedBinding())
        switch outcome {
        case .completed(let result):
            writeReport(
                completed: true, identity: result.outerIdentity,
                diagnostic: result.diagnosticBytes, residue: result.residue,
                failure: nil, cleanup: [])
            return completedExitStatus
        case .failed(let failure):
            let projection = await system.reportProjection()
            writeReport(
                completed: false, identity: projection.identity,
                diagnostic: Data(), residue: projection.residue,
                failure: String(describing: failure.primary),
                cleanup: failure.cleanupIssues.map(String.init(describing:)))
            return failedExitStatus
        }
    }

    private static func expectedBinding()
        -> InvestigationMachineCampaignExpectedBinding
    {
        try! .init(
            attemptUUID: UUID(uuid: (0x41, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 1)),
            buildProvenanceSHA256: String(repeating: "a", count: 64),
            signedRuntimeBindingSHA256: .hashing(
                Data(repeating: 0x42, count: 32)),
            wholeProjectedInputSHA256: .hashing(
                Data(repeating: 0x43, count: 32)))
    }

    private static func writeReport(
        completed: Bool, identity: InvestigationMachineCampaignOuterIdentity?,
        diagnostic: Data,
        residue: InvestigationMachineCampaignResidueObservation?,
        failure: String?, cleanup: [String]
    ) {
        let object: [String: Any] = [
            "completed": completed, "processID": identity?.processID ?? 0,
            "processGroupID": identity?.processGroupID ?? 0,
            "sessionID": identity?.sessionID ?? 0,
            "foregroundProcessGroupID":
                identity?.foregroundProcessGroupID ?? 0,
            "diagnostic": String(decoding: diagnostic, as: UTF8.self),
            "residueComplete": residue?.complete ?? false,
            "processGroupResidueCount":
                residue?.processGroupMembers.count ?? -1,
            "sessionResidueCount": residue?.sessionMembers.count ?? -1,
            "failure": failure ?? "", "cleanup": cleanup,
        ]
        guard let data = try? JSONSerialization.data(
            withJSONObject: object, options: [.sortedKeys])
        else { return }
        var offset = 0
        while offset < data.count {
            let count = data.withUnsafeBytes { bytes in
                Darwin.write(
                    STDOUT_FILENO, bytes.baseAddress! + offset,
                    data.count - offset)
            }
            if count > 0 { offset += count; continue }
            if count < 0, errno == EINTR { continue }
            return
        }
    }

    private actor CampaignDarwinSystem:
        InvestigationMachineCampaignHarnessSystem
    {
        private enum Failure: Error { case invalid, deadline, posix(Int32) }
        private var spawned: InvestigationMachineCampaignSpawnedProcess?
        private var deadline: UInt64?
        private var channelsClosed = false
        private var bootstrapVerified = false
        private var lastIdentity: InvestigationMachineCampaignOuterIdentity?
        private var lastResidue: InvestigationMachineCampaignResidueObservation?

        func reportProjection() -> (
            identity: InvestigationMachineCampaignOuterIdentity?,
            residue: InvestigationMachineCampaignResidueObservation?
        ) { (lastIdentity, lastResidue) }

        nonisolated var isBootstrapInvocation: Bool {
            CommandLine.argc == 1 && getpid() > 1 && getsid(0) == getpid()
                && getpgrp() == getpid()
                && Self.validDescriptor(3, type: S_IFIFO, access: O_WRONLY)
                && Self.validDescriptor(4, type: S_IFCHR, access: O_RDWR)
                && Self.validDescriptor(5, type: S_IFIFO, access: O_WRONLY)
        }

        nonisolated func runBootstrap() -> Int32 {
            guard let executable = try? Self.executablePath() else { return 70 }
            let sibling = URL(filePath: executable).deletingLastPathComponent()
                .appending(path: coordinatorName).path
            return sibling.withCString {
                stornaut_investigation_campaign_bootstrap_fixed($0)
            }
        }

        func perform(_ operation: InvestigationMachineCampaignHarnessOperation)
            async throws -> InvestigationMachineCampaignHarnessResponse
        {
            switch operation {
            case .makeAbsoluteDeadline:
                guard deadline == nil else { throw Failure.invalid }
                let value = DispatchTime.now().uptimeNanoseconds
                    .addingReportingOverflow(deadlineWindowNanoseconds)
                guard !value.overflow else { throw Failure.deadline }
                deadline = value.partialValue
                return .absoluteDeadline(value.partialValue)
            case .observeHarness(let value):
                try check(value, reservingCleanup: true)
                return .harnessIdentity(
                    processID: getpid(), effectiveUserID: geteuid())
            case .spawnFixedSibling(let value):
                try check(value, reservingCleanup: true)
                guard spawned == nil else { throw Failure.invalid }
                var raw = stornaut_investigation_campaign_spawn()
                let executable = try Self.executablePath()
                let status = executable.withCString {
                    stornaut_investigation_campaign_spawn_fixed($0, &raw)
                }
                guard status == 0, raw.process_id > 1 else {
                    throw Failure.posix(status)
                }
                let result = InvestigationMachineCampaignSpawnedProcess(
                    processID: raw.process_id,
                    terminalDescriptor: raw.terminal_master_descriptor,
                    receiptDescriptor: raw.receipt_read_descriptor,
                    bootstrapDescriptor: raw.bootstrap_read_descriptor,
                    parentTransferCloseError:
                        raw.parent_transfer_close_error == 0
                            ? nil : raw.parent_transfer_close_error)
                spawned = result
                return .spawned(result)
            case .readBootstrap(let descriptor, let maximum, let value):
                try check(value, reservingCleanup: true)
                guard descriptor == spawned?.bootstrapDescriptor else {
                    throw Failure.invalid
                }
                let result = try readToEOF(
                    descriptor, maximum: maximum,
                    deadline: try operationDeadline(value))
                bootstrapVerified = result.data == Data([
                    UInt8(STORNAUT_INVESTIGATION_CAMPAIGN_BOOTSTRAP_READY)
                ]) && result.eof
                return .bootstrap(bytes: result.data, reachedEOF: result.eof)
            case .observeOuterIdentity(let processID, let value):
                try check(value, reservingCleanup: true)
                guard bootstrapVerified, processID == spawned?.processID,
                      let spawned else { throw Failure.invalid }
                let identity = try Self.identity(
                    processID, terminal: spawned.terminalDescriptor,
                    initial: lastIdentity)
                lastIdentity = identity
                return .outerIdentity(identity)
            case .pollReadable(let channels, let value):
                try check(value, reservingCleanup: true)
                let operationDeadline = try operationDeadline(value)
                var events = try channels.map {
                    pollfd(fd: try descriptor(for: $0),
                        events: Int16(POLLIN | POLLHUP), revents: 0)
                }
                while true {
                    let count = events.withUnsafeMutableBufferPointer {
                        poll($0.baseAddress, nfds_t($0.count),
                            Self.timeout(operationDeadline))
                    }
                    if count < 0, errno == EINTR { continue }
                    if count == 0 {
                        guard DispatchTime.now().uptimeNanoseconds
                                < operationDeadline
                        else { throw Failure.deadline }
                        continue
                    }
                    guard count > 0, events.allSatisfy({
                        $0.revents & Int16(POLLERR | POLLNVAL) == 0
                    }) else { throw Failure.invalid }
                    return .readable(zip(channels, events).compactMap {
                        $1.revents & Int16(POLLIN | POLLHUP) != 0 ? $0 : nil
                    })
                }
            case .read(let channel, let maximum, let value):
                try check(value, reservingCleanup: true)
                guard (1...16_384).contains(maximum) else {
                    throw Failure.invalid
                }
                let fd = try descriptor(for: channel)
                var bytes = [UInt8](repeating: 0, count: maximum)
                while true {
                    let count = Darwin.read(fd, &bytes, bytes.count)
                    if count > 0 {
                        return .read(.bytes(Data(bytes.prefix(count))))
                    }
                    if count == 0 || channel == .terminal && errno == EIO {
                        return .read(.eof)
                    }
                    if errno == EINTR { continue }
                    throw Failure.posix(errno)
                }
            case .terminateOwnedGroup(
                let processID, let groupID, let value):
                try check(value)
                guard processID == spawned?.processID, groupID == processID
                else { throw Failure.invalid }
                if kill(-groupID, SIGKILL) != 0, errno != ESRCH {
                    throw Failure.posix(errno)
                }
                return .completed
            case .waitExact(let processID, let value):
                try check(value)
                guard processID == spawned?.processID else {
                    throw Failure.invalid
                }
                return .wait(try wait(processID, deadline: value))
            case .closeParentChannels(
                let terminal, let receipt, let bootstrap, let value):
                try check(value)
                guard !channelsClosed, let expected = spawned,
                      terminal == expected.terminalDescriptor,
                      receipt == expected.receiptDescriptor,
                      bootstrap == expected.bootstrapDescriptor
                else { throw Failure.invalid }
                channelsClosed = true
                var failed = false
                for fd in Set([terminal, receipt, bootstrap]) where fd >= 0 {
                    if close(fd) != 0, errno != EBADF { failed = true }
                }
                if failed { throw Failure.posix(errno) }
                return .completed
            case .observeResidue(let groupID, let sessionID, let value):
                try check(value)
                guard groupID == spawned?.processID, sessionID == groupID
                else { throw Failure.invalid }
                let result = try Self.residue(
                    groupID: groupID, sessionID: sessionID)
                lastResidue = result
                spawned = nil
                return .residue(result)
            }
        }

        private func check(
            _ value: UInt64, reservingCleanup: Bool = false
        ) throws {
            let effective = reservingCleanup ? try operationDeadline(value) : value
            guard value == deadline,
                  DispatchTime.now().uptimeNanoseconds < effective
            else { throw Failure.deadline }
        }

        private func operationDeadline(_ value: UInt64) throws -> UInt64 {
            guard value == deadline, value > 1_000_000_000 else {
                throw Failure.deadline
            }
            return value - 1_000_000_000
        }

        private func descriptor(
            for channel: InvestigationMachineCampaignChannel
        ) throws -> Int32 {
            guard !channelsClosed, let spawned else { throw Failure.invalid }
            return channel == .terminal
                ? spawned.terminalDescriptor : spawned.receiptDescriptor
        }

        private func readToEOF(
            _ descriptor: Int32, maximum: Int, deadline: UInt64
        ) throws -> (data: Data, eof: Bool) {
            var result = Data()
            while result.count <= maximum {
                var event = pollfd(fd: descriptor,
                    events: Int16(POLLIN | POLLHUP), revents: 0)
                let ready = poll(&event, 1, Self.timeout(deadline))
                if ready < 0, errno == EINTR { continue }
                if ready == 0 {
                    guard DispatchTime.now().uptimeNanoseconds < deadline
                    else { throw Failure.deadline }
                    continue
                }
                guard ready > 0,
                      event.revents & Int16(POLLERR | POLLNVAL) == 0
                else { throw Failure.invalid }
                var bytes = [UInt8](repeating: 0,
                    count: max(1, maximum + 1 - result.count))
                let count = Darwin.read(descriptor, &bytes, bytes.count)
                if count > 0 {
                    result.append(contentsOf: bytes.prefix(count)); continue
                }
                if count == 0 { return (result, true) }
                if errno == EINTR { continue }
                throw Failure.posix(errno)
            }
            return (result, false)
        }

        private func wait(_ processID: pid_t, deadline: UInt64) throws
            -> InvestigationMachineCampaignExactWait
        {
            while true {
                try check(deadline)
                var status: Int32 = 0
                let value = waitpid(processID, &status, WNOHANG | WUNTRACED)
                if value == processID {
                    let low = status & 0x7f
                    if low == 0 {
                        return .exited(status: status >> 8 & 0xff)
                    }
                    if low == 0x7f {
                        return .stopped(signal: status >> 8 & 0xff)
                    }
                    guard low > 0 && low < NSIG else { throw Failure.invalid }
                    return .signaled(signal: low)
                }
                if value < 0, errno != EINTR { throw Failure.posix(errno) }
                _ = poll(nil, 0, 10)
            }
        }

        private static func identity(
            _ processID: pid_t, terminal: Int32,
            initial: InvestigationMachineCampaignOuterIdentity?
        ) throws -> InvestigationMachineCampaignOuterIdentity {
            var narrow = stornaut_investigation_identity()
            var process = proc_bsdinfo()
            let narrowStatus = stornaut_investigation_identity_for_pid(
                processID, &narrow)
            let processBytes = proc_pidinfo(
                processID, PROC_PIDTBSDINFO, 0, &process,
                Int32(MemoryLayout<proc_bsdinfo>.size))
            guard narrowStatus == 0,
                  processBytes == MemoryLayout<proc_bsdinfo>.size,
                  narrow.process_id == processID,
                  process.pbi_pid == processID, process.pbi_pgid == processID,
                  narrow.process_id_version > 0, process.pbi_ppid > 1,
                  process.pbi_start_tvsec > 0,
                  process.pbi_start_tvusec < 1_000_000,
                  getsid(processID) == processID,
                  Self.validDescriptor(terminal, type: S_IFCHR, access: O_RDWR)
            else { throw Failure.invalid }
            let observed = InvestigationMachineCampaignOuterIdentity(
                processID: processID,
                processIDVersion: UInt32(narrow.process_id_version),
                parentProcessID: pid_t(process.pbi_ppid),
                processGroupID: pid_t(process.pbi_pgid), sessionID: processID,
                foregroundProcessGroupID: initial?.foregroundProcessGroupID
                    ?? pid_t(process.e_tpgid),
                effectiveUserID: uid_t(process.pbi_uid),
                startTimeSeconds: process.pbi_start_tvsec,
                startTimeMicroseconds: process.pbi_start_tvusec)
            if let initial {
                guard observed == initial else { throw Failure.invalid }
            } else {
                guard process.pbi_flags & UInt32(PROC_FLAG_CONTROLT) != 0,
                      process.e_tpgid == UInt32(processID)
                else { throw Failure.invalid }
            }
            return observed
        }

        private static func residue(
            groupID: pid_t, sessionID: pid_t
        ) throws -> InvestigationMachineCampaignResidueObservation {
            var capacity = 4_096
            while capacity <= 131_072 {
                var pids = [pid_t](repeating: 0, count: capacity)
                let count = pids.withUnsafeMutableBytes {
                    proc_listallpids($0.baseAddress, Int32($0.count))
                }
                guard count >= 0 else { throw Failure.posix(errno) }
                if count < capacity {
                    var groups: [pid_t] = [], sessions: [pid_t] = []
                    for pid in pids.prefix(Int(count)) where pid > 1 {
                        errno = 0; let group = getpgid(pid)
                        if group == groupID { groups.append(pid) }
                        else if group < 0, errno != ESRCH {
                            throw Failure.posix(errno)
                        }
                        errno = 0; let session = getsid(pid)
                        if session == sessionID { sessions.append(pid) }
                        else if session < 0, errno != ESRCH {
                            throw Failure.posix(errno)
                        }
                    }
                    return .init(
                        processGroupMembers: groups.sorted(),
                        sessionMembers: sessions.sorted(), complete: true)
                }
                capacity *= 2
            }
            return .init(
                processGroupMembers: [], sessionMembers: [], complete: false)
        }

        private static func validDescriptor(
            _ descriptor: Int32, type: mode_t, access: Int32
        ) -> Bool {
            var value = stat(); let flags = fcntl(descriptor, F_GETFL)
            return fstat(descriptor, &value) == 0
                && value.st_mode & S_IFMT == type && flags >= 0
                && flags & O_ACCMODE == access
        }

        private static func executablePath() throws -> String {
            var bytes = [CChar](repeating: 0, count: Int(MAXPATHLEN))
            let count = proc_pidpath(getpid(), &bytes, UInt32(bytes.count))
            guard count > 1, count < bytes.count, let value = String(
                bytes: bytes.prefix(Int(count)).map(UInt8.init(bitPattern:)),
                encoding: .utf8), value.first == "/"
            else { throw Failure.invalid }
            return value
        }

        private static func timeout(_ deadline: UInt64) -> Int32 {
            let now = DispatchTime.now().uptimeNanoseconds
            guard now < deadline else { return 0 }
            return Int32(min(
                UInt64(50), max(1, (deadline - now) / 1_000_000)))
        }
    }
}


@main
struct StornautInvestigationMachineCampaignCommand {
    static func main() async {
        exit(await InvestigationMachineCampaignExecutable.run())
    }
}
#else
@main
struct StornautInvestigationMachineCampaignCommand {
    static func main() { exit(78) }
}
#endif
