import Darwin
import Foundation
import Testing
@Suite("Investigation fixed gate handoff physical evidence", .serialized)
struct InvestigationFixedGateHandoffPhysicalTests {
    @Test
    func userOwnedTemporaryGateFailsClosedBeforeSpawn() throws {
        try #require(geteuid() == 501)
        try #require(getegid() == 20)
        let fixture = try HandoffPhysicalFixture.make()
        defer { fixture.remove() }

        var gateStatus = stat()
        try #require(lstat(fixture.gate.path, &gateStatus) == 0)
        #expect(gateStatus.st_mode & S_IFMT == S_IFREG)
        #expect(gateStatus.st_mode & S_IFMT != S_IFLNK)
        #expect(gateStatus.st_uid == geteuid())
        #expect(gateStatus.st_gid == getegid())
        #expect(gateStatus.st_uid != 0)
        #expect(gateStatus.st_gid != 0)
        #expect(gateStatus.st_mode & 0o777 == 0o755)

        let evidence = try fixture.run(.success)
        let report = evidence.report

        #expect(evidence.coordinator.userID == 501)
        #expect(evidence.coordinator.groupID == 20)
        #expect(evidence.coordinatorAbsentAfterReap)
        #expect(evidence.gatePIDRecordAbsent)
        #expect(!report.succeeded)
        #expect(report.error == "spawnFailedBeforeTransfer")
        #expect(report.gateProcessID == nil)
        #expect(report.gateProcessGroupID == nil)
        #expect(!report.exactGateExited)
        #expect(report.capsuleRemoved)
        #expect(report.foregroundRestored)
        #expect(try fixture.machineGateAttemptNames().isEmpty)
    }
}

private enum HandoffPhysicalMode: String {
    case success
    case earlyExit
    case malformedPrepared
    case overflowPrepared
    case forwardedSignal
    case stubbornDescendant
    case cleanupTimeout
}
private struct HandoffPhysicalReport: Decodable {
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
private struct HandoffPhysicalExecutionEvidence {
    let report: HandoffPhysicalReport
    let coordinator: PhysicalProcessObservation
    let coordinatorAbsentAfterReap: Bool
    let gatePIDRecordAbsent: Bool
}
private enum HandoffPhysicalTestError: Error, CustomStringConvertible {
    case compile(Int32, String)
    case invalid(String)
    case posix(String, Int32)
    case timeout(String)

    var description: String {
        switch self {
        case .compile(let status, let output):
            "fixture compile failed (\(status)): \(output)"
        case .invalid(let reason):
            "invalid physical fixture evidence: \(reason)"
        case .posix(let operation, let code):
            "\(operation) failed with errno/status \(code)"
        case .timeout(let operation):
            "bounded timeout: \(operation)"
        }
    }
}
private final class HandoffPhysicalFixture {
    private static let timeoutNanoseconds: UInt64 = 20_000_000_000
    private static let cleanupTimeoutNanoseconds: UInt64 = 1_000_000_000
    private static let moduleSources: [(String, [String])] = [
        (
            "StornautInvestigationHandoffContract",
            [
                "HandoffBinaryTranscript",
                "InvestigationCohortCapsuleContract",
                "InvestigationHandoffEpochBootstrapContract",
                "InvestigationHandoffFrameContract",
                "InvestigationInstalledL2ProjectionContract",
                "InvestigationMachineClaimContract",
                "InvestigationProjectedCohortInput",
            ]
        ),
        (
            "StornautInvestigationMachineGateSupport",
            [
                "DarwinInvestigationMachineFixedGateSystem",
                "InvestigationMachineFixedGateLauncher",
                "InvestigationMachineGateTransport",
            ]
        ),
        (
            "StornautInvestigationMachineLaunchSupport",
            [
                "DarwinInvestigationFixedGateHandoffSystem",
                "InvestigationFixedGateDarwinLifecycle",
                "InvestigationFixedGateHandoff",
                "InvestigationMachineGateHandoffReceipt",
                "InvestigationMachineGateOwnership",
                "InvestigationOwnerOnlyCapsule",
            ]
        ),
    ]
    let directory: URL
    let coordinator: URL
    let gate: URL
    private init(directory: URL, coordinator: URL, gate: URL) {
        self.directory = directory
        self.coordinator = coordinator
        self.gate = gate
    }
    static func make() throws -> HandoffPhysicalFixture {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let directory = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-fixed-handoff-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        do {
            let buildRoot = try resolvedBuildRoot(
                repositoryRoot: repositoryRoot
            )
            let packageName = try resolvedPackageName(
                buildRoot: buildRoot
            )
            let source = repositoryRoot.appending(
                path: "Tests/Fixtures/InvestigationFixedGateHandoff/main.swift"
            )
            let coordinator = directory.appending(path: "handoff-coordinator")
            let gate = directory.appending(
                path: "StornautInvestigationMachineGate"
            )
            let objects = try moduleSources.flatMap { module, sources in
                try sources.map { sourceName in
                    let path = buildRoot.appending(
                        path: "\(module).build/\(sourceName).swift.o"
                    )
                    guard FileManager.default.fileExists(atPath: path.path) else {
                        throw HandoffPhysicalTestError.invalid(
                            "missing current object \(path.path)"
                        )
                    }
                    return path.path
                }
            }
            let output = Pipe()
            let compiler = Process()
            compiler.executableURL = URL(filePath: "/usr/bin/xcrun")
            compiler.currentDirectoryURL = repositoryRoot
            compiler.arguments = [
                "swiftc", "-parse-as-library", "-package-name",
                packageName,
                "-I", buildRoot.appending(path: "Modules").path,
                source.path,
            ] + objects + ["-o", coordinator.path]
            compiler.environment = [
                "HOME": "/var/empty", "LANG": "C",
                "LC_ALL": "C", "PATH": "/usr/bin:/bin",
            ]
            compiler.standardInput = FileHandle.nullDevice
            compiler.standardOutput = output
            compiler.standardError = output
            try compiler.run()
            let diagnostics = output.fileHandleForReading.readDataToEndOfFile()
            compiler.waitUntilExit()
            guard compiler.terminationStatus == 0 else {
                throw HandoffPhysicalTestError.compile(
                    compiler.terminationStatus,
                    String(decoding: diagnostics, as: UTF8.self)
                )
            }
            try FileManager.default.copyItem(at: coordinator, to: gate)
            guard chmod(coordinator.path, 0o755) == 0,
                  chmod(gate.path, 0o755) == 0 else {
                throw physicalPOSIX("chmod fixtures")
            }
            return HandoffPhysicalFixture(
                directory: directory, coordinator: coordinator, gate: gate
            )
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }
    func run(_ mode: HandoffPhysicalMode) throws
        -> HandoffPhysicalExecutionEvidence
    {
        let attempt = UUID()
        let gateRecord = directory.appending(path: "fixture-gate-pid")
        try? FileManager.default.removeItem(at: gateRecord)
        guard !FileManager.default.fileExists(atPath: gateRecord.path) else {
            throw HandoffPhysicalTestError.invalid("stale fixture PID record")
        }
        var pipeDescriptors: [Int32] = [-1, -1]
        guard pipe(&pipeDescriptors) == 0 else { throw physicalPOSIX("pipe") }
        defer {
            if pipeDescriptors[0] >= 0 { _ = close(pipeDescriptors[0]) }
            if pipeDescriptors[1] >= 0 { _ = close(pipeDescriptors[1]) }
        }
        try physicalCloseOnExec(pipeDescriptors[0])
        try physicalCloseOnExec(pipeDescriptors[1])
        var actions: posix_spawn_file_actions_t?
        guard posix_spawn_file_actions_init(&actions) == 0 else {
            throw HandoffPhysicalTestError.invalid("spawn actions")
        }
        defer { posix_spawn_file_actions_destroy(&actions) }
        guard posix_spawn_file_actions_adddup2(
            &actions, pipeDescriptors[1], STDOUT_FILENO
        ) == 0,
        posix_spawn_file_actions_addclose(&actions, pipeDescriptors[0]) == 0,
        posix_spawn_file_actions_addclose(&actions, pipeDescriptors[1]) == 0
        else { throw HandoffPhysicalTestError.invalid("spawn file actions") }
        var attributes: posix_spawnattr_t?
        guard posix_spawnattr_init(&attributes) == 0 else {
            throw HandoffPhysicalTestError.invalid("spawn attributes")
        }
        defer { posix_spawnattr_destroy(&attributes) }
        guard posix_spawnattr_setflags(
            &attributes, Int16(
                POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_START_SUSPENDED
            )
        ) == 0 else {
            throw HandoffPhysicalTestError.invalid("spawn flags")
        }
        var pid: pid_t = 0
        let arguments = [
            coordinator.path, "--coordinator", mode.rawValue,
            attempt.uuidString.lowercased(),
        ]
        let status = try physicalCStrings(arguments) { argv in
            try physicalCStrings([]) { envp in
                coordinator.path.withCString { path in
                    posix_spawn(&pid, path, &actions, &attributes, argv, envp)
                }
            }
        }
        guard status == 0, pid > 1 else {
            throw HandoffPhysicalTestError.posix("spawn coordinator", status)
        }
        let coordinatorObservation: PhysicalProcessObservation
        do { coordinatorObservation = try physicalDirectChildObservation(pid) }
        catch {
            try physicalAbortSuspendedDirectChild(pid)
            throw error
        }
        let coordinatorToken = coordinatorObservation.token
        _ = close(pipeDescriptors[1])
        pipeDescriptors[1] = -1
        let deadline = DispatchTime.now().uptimeNanoseconds
            + Self.timeoutNanoseconds
        var reaped = false
        do {
            guard kill(pid, SIGCONT) == 0 else {
                throw physicalPOSIX("continue fixture coordinator")
            }
            if mode == .cleanupTimeout {
                try physicalAwaitCleanupCohort(
                    coordinatorToken, deadline: deadline
                )
            }
            let reportDeadline = mode == .cleanupTimeout
                ? DispatchTime.now().uptimeNanoseconds
                    + Self.cleanupTimeoutNanoseconds
                : deadline
            let data = try physicalReadFrame(
                pipeDescriptors[0], deadline: reportDeadline
            )
            _ = close(pipeDescriptors[0])
            pipeDescriptors[0] = -1
            let waitable = try physicalWaitable(pid, deadline: deadline)
            guard physicalExitStatus(waitable) == 0 else {
                throw HandoffPhysicalTestError.invalid(
                    String(decoding: data, as: UTF8.self)
                )
            }
            let report = try JSONDecoder().decode(
                HandoffPhysicalReport.self, from: data
            )
            guard report.version == 1, report.mode == mode.rawValue,
                  report.outerAttemptUUID == attempt.uuidString.lowercased() else {
                throw HandoffPhysicalTestError.invalid("report identity")
            }
            let waitStatus = try physicalReap(
                coordinatorToken, deadline: deadline
            )
            reaped = true
            let coordinatorAbsentAfterReap =
                try physicalProcessToken(pid) != coordinatorToken
            guard waitStatus == waitable, coordinatorAbsentAfterReap else {
                throw HandoffPhysicalTestError.invalid(
                    "fixture wait or identity retirement drift"
                )
            }
            return .init(
                report: report, coordinator: coordinatorObservation,
                coordinatorAbsentAfterReap: coordinatorAbsentAfterReap,
                gatePIDRecordAbsent:
                    !FileManager.default.fileExists(atPath: gateRecord.path)
            )
        } catch let original {
            if !reaped {
                do { try physicalCleanupSession(coordinatorToken) }
                catch {
                    throw HandoffPhysicalTestError.invalid(
                        "cleanup after \(original): \(error)"
                    )
                }
            }
            throw original
        }
    }
    func machineGateAttemptNames() throws -> [String] {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Caches/com.eriklee.stornaut.task39-machine-gate")
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(atPath: root.path)
            .filter { $0.hasPrefix("attempt-") }
            .sorted()
    }
    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
    private static func resolvedBuildRoot(repositoryRoot: URL) throws -> URL {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/swift")
        process.currentDirectoryURL = repositoryRoot
        process.arguments = ["build", "--show-bin-path"]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw HandoffPhysicalTestError.invalid("resolve build root")
        }
        let path = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard path.first == "/", !path.isEmpty else {
            throw HandoffPhysicalTestError.invalid("build root path")
        }
        return URL(filePath: path, directoryHint: .isDirectory)
    }
    private static func resolvedPackageName(buildRoot: URL) throws -> String {
        let descriptionURL = buildRoot.appending(path: "description.json")
        let object = try JSONSerialization.jsonObject(
            with: Data(contentsOf: descriptionURL)
        )
        guard let root = object as? [String: Any],
              let commands = root["swiftCommands"] as? [String: Any],
              let command = commands.first(where: {
                  $0.key.contains("StornautInvestigationMachineLaunchSupport")
              })?.value as? [String: Any],
              let arguments = command["otherArguments"] as? [String],
              let marker = arguments.firstIndex(of: "-package-name"),
              arguments.indices.contains(marker + 1)
        else {
            throw HandoffPhysicalTestError.invalid("package name")
        }
        let value = arguments[marker + 1]
        guard !value.isEmpty,
              value.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" })
        else {
            throw HandoffPhysicalTestError.invalid("package name shape")
        }
        return value
    }
}
private func physicalReadFrame(
    _ descriptor: Int32, deadline: UInt64
) throws -> Data {
    let prefix = try physicalReadExactly(
        descriptor, count: 4, deadline: deadline, timeout: "read fixture report prefix"
    )
    let count = prefix.withUnsafeBytes {
        UInt32(bigEndian: $0.loadUnaligned(as: UInt32.self))
    }
    guard count > 0, count <= 65_536 else {
        throw HandoffPhysicalTestError.invalid("report frame size")
    }
    return try physicalReadExactly(
        descriptor, count: Int(count), deadline: deadline,
        timeout: "read fixture report payload"
    )
}
private func physicalReadExactly(
    _ descriptor: Int32, count: Int, deadline: UInt64, timeout: String
) throws -> Data {
    var result = Data()
    while result.count < count {
        guard DispatchTime.now().uptimeNanoseconds < deadline else {
            throw HandoffPhysicalTestError.timeout(timeout)
        }
        var item = pollfd(
            fd: descriptor, events: Int16(POLLIN | POLLHUP), revents: 0
        )
        let polled = poll(&item, 1, 50)
        if polled < 0, errno == EINTR { continue }
        guard polled >= 0, item.revents & Int16(POLLERR | POLLNVAL) == 0 else {
            throw physicalPOSIX("poll fixture report")
        }
        if polled == 0 { continue }
        var bytes = [UInt8](repeating: 0, count: count - result.count)
        let amount = read(descriptor, &bytes, bytes.count)
        if amount < 0, errno == EINTR { continue }
        guard amount > 0 else {
            throw HandoffPhysicalTestError.invalid("fixture report EOF")
        }
        result.append(contentsOf: bytes.prefix(amount))
    }
    return result
}
private func physicalWaitable(_ pid: pid_t, deadline: UInt64) throws -> Int32 {
    while DispatchTime.now().uptimeNanoseconds < deadline {
        var info = siginfo_t()
        let value = waitid(
            P_PID, UInt32(bitPattern: pid), &info,
            WEXITED | WNOHANG | WNOWAIT
        )
        if value == 0, info.si_pid == pid {
            return try physicalWaitStatus(info)
        }
        if value < 0, errno != EINTR { throw physicalPOSIX("waitid fixture") }
        usleep(10_000)
    }
    throw HandoffPhysicalTestError.timeout("wait fixture")
}
private func physicalReap(
    _ token: PhysicalProcessToken, deadline: UInt64
) throws -> Int32 {
    var status: Int32 = 0
    while DispatchTime.now().uptimeNanoseconds < deadline {
        let value = waitpid(token.processID, &status, WNOHANG)
        if value == token.processID { return status }
        if value < 0, errno != EINTR { throw physicalPOSIX("wait fixture") }
        usleep(10_000)
    }
    throw HandoffPhysicalTestError.timeout("wait fixture")
}
private func physicalWaitStatus(_ info: siginfo_t) throws -> Int32 {
    switch info.si_code {
    case CLD_EXITED:
        return info.si_status << 8
    case CLD_KILLED, CLD_DUMPED:
        return info.si_status & 0x7f
    default:
        throw HandoffPhysicalTestError.invalid("fixture wait classification")
    }
}
private func physicalExitStatus(_ status: Int32) -> Int32? {
    status & 0x7f == 0 ? status >> 8 & 0xff : nil
}
private struct PhysicalProcessToken: Hashable {
    let processID: pid_t
    let startSeconds: UInt64
    let startMicroseconds: UInt64
}
private struct PhysicalProcessObservation {
    let token: PhysicalProcessToken
    let parentProcessID: pid_t
    let processGroupID: pid_t
    let userID: uid_t
    let groupID: gid_t
    let status: UInt32
}
private func physicalAbortSuspendedDirectChild(_ processID: pid_t) throws {
    guard kill(processID, SIGKILL) == 0 || errno == ESRCH else {
        throw physicalPOSIX("abort suspended fixture")
    }
    let deadline = DispatchTime.now().uptimeNanoseconds + 5_000_000_000
    var status: Int32 = 0
    while DispatchTime.now().uptimeNanoseconds < deadline {
        let value = waitpid(processID, &status, WNOHANG)
        if value == processID || value < 0 && errno == ECHILD { return }
        if value < 0 && errno != EINTR { throw physicalPOSIX("reap aborted fixture") }
        usleep(10_000)
    }
    throw HandoffPhysicalTestError.timeout("reap aborted fixture")
}
private func physicalCleanupSession(_ coordinator: PhysicalProcessToken) throws {
    let deadline = DispatchTime.now().uptimeNanoseconds + 5_000_000_000
    let sessionID = coordinator.processID
    var discovered = Set([coordinator]), completed = false
    defer { if !completed { physicalFallbackCleanup(coordinator, discovered) } }
    guard try physicalProcessObservation(sessionID)?.token == coordinator else {
        throw HandoffPhysicalTestError.invalid("cleanup fixture leader")
    }
    let frozen = try physicalFreezeCohort(coordinator, deadline: deadline)
    discovered.formUnion(frozen.map(\.token))
    guard frozen.count == 3,
          frozen.contains(where: { $0.token == coordinator }),
          frozen.contains(where: { $0.parentProcessID == sessionID }),
          frozen.contains(where: { member in
              frozen.contains { $0.token.processID == member.parentProcessID
                  && $0.token != coordinator }
          }) else { throw HandoffPhysicalTestError.invalid("cleanup fixture topology") }
    for member in frozen.sorted(by: {
        $0.token == coordinator ? false : $1.token == coordinator
    }) { try physicalSignal(member, SIGKILL) }
    let waitable = try physicalWaitable(sessionID, deadline: deadline)
    while DispatchTime.now().uptimeNanoseconds < deadline {
        if try discovered.filter({ $0 != coordinator }).allSatisfy({
            try physicalProcessToken($0.processID) != $0
        }) { break }
        usleep(10_000)
    }
    guard try discovered.filter({ $0 != coordinator }).allSatisfy({
        try physicalProcessToken($0.processID) != $0
    }) else { throw HandoffPhysicalTestError.timeout("drain fixture cohort") }
    let reaped = try physicalReap(coordinator, deadline: deadline)
    guard reaped == waitable, try physicalProcessToken(sessionID) != coordinator else {
        throw HandoffPhysicalTestError.invalid("fixture final residue")
    }
    completed = true
}
private func physicalAwaitCleanupCohort(
    _ coordinator: PhysicalProcessToken, deadline: UInt64
) throws {
    while DispatchTime.now().uptimeNanoseconds < deadline {
        let cohort = try physicalCohort(coordinator)
        if cohort.count == 3,
           cohort.allSatisfy({ $0.processGroupID == coordinator.processID }) {
            return
        }
        usleep(10_000)
    }
    throw HandoffPhysicalTestError.timeout("wait cleanup fixture readiness")
}
private func physicalDirectChildObservation(
    _ processID: pid_t
) throws -> PhysicalProcessObservation {
    guard let observation = try physicalProcessObservation(processID),
          observation.parentProcessID == getpid() else {
        throw HandoffPhysicalTestError.invalid("fixture direct child identity")
    }
    return observation
}
private func physicalProcessToken(
    _ processID: pid_t
) throws -> PhysicalProcessToken? {
    try physicalProcessObservation(processID)?.token
}
private func physicalProcessObservation(
    _ processID: pid_t
) throws -> PhysicalProcessObservation? {
    var value = proc_bsdinfo()
    errno = 0
    let count = proc_pidinfo(
        processID, PROC_PIDTBSDINFO, 0, &value,
        Int32(MemoryLayout<proc_bsdinfo>.size)
    )
    if count <= 0 {
        if errno == ESRCH { return nil }
        throw physicalPOSIX("observe fixture process")
    }
    guard count == MemoryLayout<proc_bsdinfo>.size,
          value.pbi_pid == UInt32(processID), value.pbi_start_tvsec > 0,
          value.pbi_start_tvusec < 1_000_000 else {
        throw HandoffPhysicalTestError.invalid("fixture process identity")
    }
    return .init(
        token: .init(
            processID: processID, startSeconds: value.pbi_start_tvsec,
            startMicroseconds: value.pbi_start_tvusec
        ), parentProcessID: pid_t(value.pbi_ppid),
        processGroupID: pid_t(value.pbi_pgid),
        userID: uid_t(value.pbi_uid), groupID: gid_t(value.pbi_gid),
        status: value.pbi_status
    )
}
private func physicalCohort(
    _ coordinator: PhysicalProcessToken
) throws -> [PhysicalProcessObservation] {
    let all = try physicalAllObservations(), sessionID = coordinator.processID
    var members = Set([coordinator.processID]), groups = Set([sessionID])
    var changed = true
    while changed {
        changed = false
        for item in all where !members.contains(item.token.processID) {
            errno = 0
            let observedSession = item.status == UInt32(SZOMB)
                ? -1 : getsid(item.token.processID)
            if observedSession < 0, errno != 0, errno != ESRCH {
                throw physicalPOSIX("observe fixture session")
            }
            if observedSession == sessionID
                || members.contains(item.parentProcessID)
                || item.status == UInt32(SZOMB) && groups.contains(item.processGroupID)
            {
                members.insert(item.token.processID)
                groups.insert(item.processGroupID)
                changed = true
            }
        }
    }
    return all.filter { members.contains($0.token.processID) }
}
private func physicalSignal(
    _ observation: PhysicalProcessObservation, _ signal: Int32
) throws {
    guard try physicalProcessToken(observation.token.processID)
        == observation.token else { return }
    guard kill(observation.token.processID, signal) == 0 || errno == ESRCH else {
        throw physicalPOSIX("signal fixture process")
    }
}
private func physicalFreezeCohort(
    _ coordinator: PhysicalProcessToken, deadline: UInt64
) throws -> [PhysicalProcessObservation] {
    var prior: Set<PhysicalProcessToken>?
    while DispatchTime.now().uptimeNanoseconds < deadline {
        let cohort = try physicalCohort(coordinator)
        for item in cohort where item.status != UInt32(SSTOP)
            && item.status != UInt32(SZOMB) { try physicalSignal(item, SIGSTOP) }
        let tokens = Set(cohort.map(\.token))
        if tokens == prior, cohort.allSatisfy({
            $0.status == UInt32(SSTOP) || $0.status == UInt32(SZOMB)
        }) { return cohort }
        prior = tokens
        usleep(10_000)
    }
    throw HandoffPhysicalTestError.timeout("freeze fixture cohort")
}
private func physicalFallbackCleanup(
    _ coordinator: PhysicalProcessToken, _ initial: Set<PhysicalProcessToken>
) {
    var known = initial
    let deadline = DispatchTime.now().uptimeNanoseconds + 2_000_000_000
    while DispatchTime.now().uptimeNanoseconds < deadline {
        for token in known {
            if let observation = try? physicalProcessObservation(token.processID),
               observation.token == token {
                try? physicalSignal(observation, SIGSTOP)
                try? physicalSignal(observation, SIGKILL)
            }
        }
        if let cohort = try? physicalCohort(coordinator) {
            known.formUnion(cohort.map(\.token))
            for item in cohort { try? physicalSignal(item, SIGSTOP) }
            for item in cohort { try? physicalSignal(item, SIGKILL) }
        }
        var status: Int32 = 0
        let value = waitpid(coordinator.processID, &status, WNOHANG)
        if (value == coordinator.processID || value < 0 && errno == ECHILD),
           known.allSatisfy({ (try? physicalProcessToken($0.processID)) != $0 }) {
            return
        }
        usleep(10_000)
    }
}
private func physicalAllObservations() throws -> [PhysicalProcessObservation] {
    var capacity = 4_096
    while capacity <= 131_072 {
        var values = [pid_t](repeating: 0, count: capacity)
        let count = values.withUnsafeMutableBytes {
            proc_listallpids($0.baseAddress, Int32($0.count))
        }
        guard count >= 0 else { throw physicalPOSIX("enumerate fixture PIDs") }
        if count < capacity {
            return values.prefix(Int(count)).filter { $0 > 1 }
                .compactMap { try? physicalProcessObservation($0) }
        }
        capacity *= 2
    }
    throw HandoffPhysicalTestError.invalid("fixture PID inventory overflow")
}
private func physicalCloseOnExec(_ descriptor: Int32) throws {
    let flags = fcntl(descriptor, F_GETFD)
    guard flags >= 0, fcntl(descriptor, F_SETFD, flags | FD_CLOEXEC) == 0 else {
        throw physicalPOSIX("cloexec")
    }
}
private func physicalPOSIX(_ operation: String) -> HandoffPhysicalTestError {
    .posix(operation, errno)
}
private func physicalCStrings<Result>(
    _ strings: [String],
    body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws -> Result
) throws -> Result {
    var values: [UnsafeMutablePointer<CChar>?] = strings.map {
        strdup($0)
    }
    guard values.allSatisfy({ $0 != nil }) else {
        throw HandoffPhysicalTestError.invalid("strdup")
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
