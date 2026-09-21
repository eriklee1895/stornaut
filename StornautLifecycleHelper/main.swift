import Darwin
import Foundation
import StornautCodex
import StornautInvestigationHandoffContract
import StornautInvestigationMachineClaimServer
import StornautLifecycle

private let serviceName = LifecycleSupervisorXPCClient.serviceName
private let machineClaimServiceName =
    "com.eriklee.stornaut.lifecycle.machine-claim"

#if DEBUG
private let workerMode = "--stornaut-r5-worker"
private let interactiveWorkerMode =
    "--stornaut-investigation-worker"
private let crashMode = "--stornaut-r5-crash-fixture"
private let networkProbeMode =
    "--stornaut-r5-network-denial-probe"
private let workerReadyLine = Data(
    "stornaut-r5-worker-ready\n".utf8
)
private let crashDescendantReadyLine = Data(
    "stornaut-r5-crash-descendant-ready\n".utf8
)
private let cancelInvestigationID = UUID(
    uuidString: "33333333-3333-3333-3333-333333333333"
)!
private let timeoutInvestigationID = UUID(
    uuidString: "44444444-4444-4444-4444-444444444444"
)!
private let crashInvestigationID = UUID(
    uuidString: "55555555-5555-5555-5555-555555555555"
)!
#endif
private let leaseRootURL = URL(
    filePath: "/private/var/db/com.eriklee.stornaut.r5",
    directoryHint: .isDirectory
)
private let diagnosticBaseURL = URL(
    filePath:
        "/Library/Application Support/Stornaut/R5Runtime",
    directoryHint: .isDirectory
)

private enum LifecycleHelperFailure: Error {
    case invalidInvocation
    case invalidIdentity
    case invalidFilesystemState
    case spawnFailed
    case workerFailed
    case evidenceFailed
    case drainFailed(reasonKey: String)
}

private func writeAll(
    _ data: Data,
    to descriptor: Int32
) throws {
    let didWrite = data.withUnsafeBytes { bytes in
        guard let base = bytes.baseAddress else { return true }
        var offset = 0
        while offset < bytes.count {
            let count = Darwin.write(
                descriptor,
                base.advanced(by: offset),
                bytes.count - offset
            )
            if count < 0 {
                if errno == EINTR { continue }
                return false
            }
            offset += count
        }
        return true
    }
    guard didWrite else {
        throw LifecycleHelperFailure.evidenceFailed
    }
}

private func writeFramedData(
    _ data: Data,
    to descriptor: Int32
) throws {
    guard
        !data.isEmpty,
        data.count <= LifecycleInteractiveSessionRequest
            .maximumEncodedEnvelopeBytes,
        data.count <= Int(UInt32.max)
    else {
        throw LifecycleHelperFailure.invalidInvocation
    }
    var length = UInt32(data.count).bigEndian
    try withUnsafeBytes(of: &length) {
        try writeAll(Data($0), to: descriptor)
    }
    try writeAll(data, to: descriptor)
}

private func readFramedData(
    from descriptor: Int32,
    maximumBytes: Int,
    timeoutMilliseconds: Int32
) throws -> Data {
    var lengthBytes = Data()
    try readExactly(
        into: &lengthBytes,
        byteCount: MemoryLayout<UInt32>.size,
        from: descriptor,
        timeoutMilliseconds: timeoutMilliseconds
    )
    let encodedLength = lengthBytes.withUnsafeBytes {
        $0.loadUnaligned(as: UInt32.self)
    }
    let length = Int(UInt32(bigEndian: encodedLength))
    guard length > 0, length <= maximumBytes else {
        throw LifecycleHelperFailure.invalidInvocation
    }
    var data = Data()
    try readExactly(
        into: &data,
        byteCount: length,
        from: descriptor,
        timeoutMilliseconds: timeoutMilliseconds
    )
    return data
}

private func readExactly(
    into data: inout Data,
    byteCount: Int,
    from descriptor: Int32,
    timeoutMilliseconds: Int32
) throws {
    guard
        descriptor >= 0,
        byteCount > 0,
        timeoutMilliseconds > 0
    else {
        throw LifecycleHelperFailure.invalidInvocation
    }
    let deadline = ContinuousClock.now
        + .milliseconds(Int64(timeoutMilliseconds))
    var buffer = [UInt8](repeating: 0, count: min(byteCount, 4_096))
    while data.count < byteCount {
        let remaining = ContinuousClock.now.duration(to: deadline)
        guard remaining > .zero else {
            throw LifecycleHelperFailure.workerFailed
        }
        let components = remaining.components
        let milliseconds = max(
            1,
            min(
                Int64(Int32.max),
                components.seconds * 1_000
                    + components.attoseconds
                        / 1_000_000_000_000_000
            )
        )
        var pollDescriptor = pollfd(
            fd: descriptor,
            events: Int16(POLLIN | POLLHUP),
            revents: 0
        )
        let pollResult = poll(
            &pollDescriptor,
            1,
            Int32(milliseconds)
        )
        if pollResult < 0 {
            if errno == EINTR { continue }
            throw LifecycleHelperFailure.workerFailed
        }
        guard pollResult > 0 else {
            throw LifecycleHelperFailure.workerFailed
        }
        let requested = min(buffer.count, byteCount - data.count)
        let count = Darwin.read(descriptor, &buffer, requested)
        if count < 0 {
            if errno == EINTR { continue }
            throw LifecycleHelperFailure.workerFailed
        }
        guard count > 0 else {
            throw LifecycleHelperFailure.workerFailed
        }
        data.append(contentsOf: buffer.prefix(count))
    }
}

private func readBoundedLine(
    from descriptor: Int32,
    maximumBytes: Int,
    timeoutMilliseconds: Int32
) throws -> Data {
    guard
        descriptor >= 0,
        maximumBytes > 0,
        timeoutMilliseconds > 0
    else {
        throw LifecycleHelperFailure.evidenceFailed
    }
    let deadline = ContinuousClock.now
        + .milliseconds(Int64(timeoutMilliseconds))
    var data = Data()
    var byte: UInt8 = 0
    while data.count < maximumBytes {
        let remaining = ContinuousClock.now.duration(to: deadline)
        guard remaining > .zero else {
            throw LifecycleHelperFailure.evidenceFailed
        }
        let components = remaining.components
        let milliseconds = max(
            1,
            min(
                Int64(Int32.max),
                components.seconds * 1_000
                    + components.attoseconds / 1_000_000_000_000_000
            )
        )
        var pollDescriptor = pollfd(
            fd: descriptor,
            events: Int16(POLLIN | POLLHUP),
            revents: 0
        )
        let pollResult = poll(
            &pollDescriptor,
            1,
            Int32(milliseconds)
        )
        if pollResult < 0 {
            if errno == EINTR { continue }
            throw LifecycleHelperFailure.evidenceFailed
        }
        guard pollResult > 0 else {
            throw LifecycleHelperFailure.evidenceFailed
        }
        let count = Darwin.read(descriptor, &byte, 1)
        if count < 0 {
            if errno == EINTR { continue }
            throw LifecycleHelperFailure.evidenceFailed
        }
        guard count == 1 else {
            throw LifecycleHelperFailure.evidenceFailed
        }
        data.append(byte)
        if byte == 0x0A {
            return data
        }
    }
    throw LifecycleHelperFailure.evidenceFailed
}

private func waitForProcessExit(
    _ process: Process,
    timeoutMilliseconds: Int
) throws {
    guard timeoutMilliseconds > 0 else {
        throw LifecycleHelperFailure.drainFailed(
            reasonKey: "runtime.lifecycle.drain.process-wait-invalid"
        )
    }
    let deadline = ContinuousClock.now
        + .milliseconds(Int64(timeoutMilliseconds))
    while process.isRunning, ContinuousClock.now < deadline {
        usleep(10_000)
    }
    guard !process.isRunning else {
        throw LifecycleHelperFailure.drainFailed(
            reasonKey: "runtime.lifecycle.drain.process-wait-timeout"
        )
    }
}

private func lstatExists(_ url: URL) -> Bool {
    var information = stat()
    return lstat(url.path, &information) == 0
}

private struct LifecycleUserIdentity {
    let userID: uid_t
    let groupID: gid_t
    let username: String

    static func read(userID: uid_t) throws -> Self {
        guard
            userID > 0,
            let entry = getpwuid(userID),
            let name = entry.pointee.pw_name,
            entry.pointee.pw_uid == userID,
            entry.pointee.pw_gid > 0
        else {
            throw LifecycleHelperFailure.invalidIdentity
        }
        let username = String(cString: name)
        guard
            !username.isEmpty,
            username.utf8.count <= 256,
            username.unicodeScalars.allSatisfy({
                $0.value >= 0x21 && $0.value != 0x7F
            })
        else {
            throw LifecycleHelperFailure.invalidIdentity
        }
        return Self(
            userID: userID,
            groupID: entry.pointee.pw_gid,
            username: username
        )
    }
}

#if DEBUG
private func runWorkerMode(
    mode: String,
    investigationID: UUID,
    evidenceBindingSHA256: String,
    userID: uid_t
) -> Never {
    guard geteuid() == 0 else {
        exit(78)
    }
    do {
        let identity = try LifecycleUserIdentity.read(userID: userID)
        guard
            identity.groupID <= gid_t(Int32.max),
            initgroups(
                identity.username,
                Int32(identity.groupID)
            ) == 0,
            setgid(identity.groupID) == 0,
            setuid(identity.userID) == 0,
            geteuid() == identity.userID,
            getegid() == identity.groupID
        else {
            throw LifecycleHelperFailure.invalidIdentity
        }
        try writeAll(workerReadyLine, to: STDOUT_FILENO)
        var release: UInt8 = 0
        guard
            Darwin.read(STDIN_FILENO, &release, 1) == 1,
            release == 0x01
        else {
            throw LifecycleHelperFailure.invalidInvocation
        }
        close(STDIN_FILENO)
        if mode == crashMode {
            runCrashFixture()
        }
        Task {
            do {
                let evidence = try await CapabilityRuntimeWorker
                    .runLocalDiagnostic(
                        investigationID: investigationID,
                        evidenceBindingSHA256:
                            evidenceBindingSHA256
                    )
                let data = try JSONEncoder().encode(evidence)
                let paths = try LifecycleLocalInstallationContract()
                    .diagnosticPaths(
                        userID: identity.userID,
                        investigationID: LifecycleInvestigationID(
                            rawValue: investigationID
                        )
                    )
                let fileIdentity = try writeExclusiveData(
                    data,
                    to: paths.workerEvidenceURL,
                    ownerUserID: identity.userID,
                    mode: 0o600
                )
                try writeAll(
                    try LifecycleWorkerEvidenceReceipt(
                        fileIdentity: fileIdentity,
                        data: data
                    ).encodedLine(),
                    to: STDOUT_FILENO
                )
                close(STDOUT_FILENO)
                exit(0)
            } catch let error as CapabilityRuntimeWorkerError {
                if
                    let receipt =
                        try? CapabilityRuntimeWorkerFailureReceipt(
                            error: error
                        )
                {
                    try? writeAll(
                        receipt.encodedLine(),
                        to: STDOUT_FILENO
                    )
                }
                close(STDOUT_FILENO)
                exit(70)
            } catch {
                if
                    let receipt =
                        try? CapabilityRuntimeWorkerFailureReceipt(
                            reasonKey:
                                "runtime.worker.unexpected-failure"
                        )
                {
                    try? writeAll(
                        receipt.encodedLine(),
                        to: STDOUT_FILENO
                    )
                }
                close(STDOUT_FILENO)
                exit(70)
            }
        }
        dispatchMain()
    } catch {
        exit(78)
    }
}
#endif

#if DEBUG
private func runInteractiveWorkerMode(
    investigationID: UUID,
    userID: uid_t
) -> Never {
    guard geteuid() == 0 else {
        exit(78)
    }
    do {
        let identity = try LifecycleUserIdentity.read(userID: userID)
        guard
            identity.groupID <= gid_t(Int32.max),
            initgroups(
                identity.username,
                Int32(identity.groupID)
            ) == 0,
            setgid(identity.groupID) == 0,
            setuid(identity.userID) == 0,
            geteuid() == identity.userID,
            getegid() == identity.groupID
        else {
            throw LifecycleHelperFailure.invalidIdentity
        }
        try writeAll(workerReadyLine, to: STDOUT_FILENO)
        let session = CodexContainedInteractiveSession()
        let worker = LifecycleContainedInteractiveWorker(session: session)
        let broker = LifecycleInteractiveSessionBroker(worker: worker)
        let replyWriter = LifecycleInteractiveWorkerReplyWriter(
            descriptor: STDOUT_FILENO
        )
        while true {
            let requestData = try readFramedData(
                from: STDIN_FILENO,
                maximumBytes: LifecycleInteractiveSessionRequest
                    .maximumEncodedEnvelopeBytes,
                timeoutMilliseconds: 900_000
            )
            let request = try JSONDecoder().decode(
                LifecycleInteractiveSessionRequest.self,
                from: requestData
            )
            guard
                request.investigationID.rawValue == investigationID
            else {
                throw LifecycleHelperFailure.invalidInvocation
            }
            Task {
                let reply: LifecycleInteractiveWorkerReply
                do {
                    let response =
                    try await broker.handle(request)
                    reply = LifecycleInteractiveWorkerReply(
                        operationID: request.operationID,
                        response: response
                    )
                } catch let error
                    as LifecycleInteractiveSessionBrokerError
                {
                    reply = try LifecycleInteractiveWorkerReply(
                        operationID: request.operationID,
                        reasonKey: lifecycleInteractiveReasonKey(error)
                    )
                } catch {
                    reply = try LifecycleInteractiveWorkerReply(
                        operationID: request.operationID,
                        reasonKey:
                            "runtime.lifecycle.interactive.remote-rejected"
                    )
                }
                do {
                    try replyWriter.write(reply)
                } catch {
                    exit(70)
                }
                if request.kind == .retire {
                    close(STDIN_FILENO)
                    close(STDOUT_FILENO)
                    exit(reply.response == nil ? 70 : 0)
                }
            }
        }
    } catch {
        exit(78)
    }
}

private final class LifecycleInteractiveWorkerReplyWriter:
    @unchecked Sendable
{
    private let lock = NSLock()
    private let descriptor: Int32

    init(descriptor: Int32) {
        self.descriptor = descriptor
    }

    func write(_ reply: LifecycleInteractiveWorkerReply) throws {
        try lock.withLock {
            try writeFramedData(
                try JSONEncoder().encode(reply),
                to: descriptor
            )
        }
    }
}

private struct LifecycleContainedInteractiveWorker:
    LifecycleInteractiveWorkerDriving,
    Sendable
{
    let session: CodexContainedInteractiveSession

    func start(
        _ configuration: LifecycleInteractiveWorkerConfiguration
    ) async throws -> LifecycleInteractiveWorkerStartObservation {
        do {
            let observation = try await session.start(
                CodexContainedInteractiveSessionConfiguration(
                    investigationID:
                        configuration.investigationID.rawValue,
                    expectedCodexExecutableSHA256:
                        configuration.codexExecutableSHA256,
                    validBefore: configuration.validBefore,
                    maximumLineBytes: configuration.maximumLineBytes,
                    maximumSessionBytes:
                        configuration.maximumSessionBytes
                )
            )
            return try LifecycleInteractiveWorkerStartObservation(
                codexExecutableSHA256:
                    observation.codexExecutableSHA256
            )
        } catch let error as CodexContainedInteractiveSessionError {
            if let mapped = lifecycleInteractiveWorkerError(error) {
                throw mapped
            }
            throw error
        }
    }

    func writeLine(_ line: Data) async throws {
        do {
            try await session.writeLine(line)
        } catch let error as CodexContainedInteractiveSessionError {
            if let mapped = lifecycleInteractiveWorkerError(error) {
                throw mapped
            }
            throw error
        }
    }

    func readLine(maximumBytes: Int) async throws -> Data? {
        let line: Data
        do {
            line = try await session.readLine()
        } catch let error as CodexContainedInteractiveSessionError {
            if let mapped = lifecycleInteractiveWorkerError(error) {
                throw mapped
            }
            throw error
        }
        guard line.count <= maximumBytes else {
            throw LifecycleInteractiveWorkerError
                .lineLimitExceeded
        }
        return line
    }

    func retire() async throws
        -> LifecycleInteractiveWorkerRetirementObservation
    {
        do {
            let observation = try await session.retire()
            switch observation.resourceOwnership {
            case .none:
                guard
                    !observation.processGroupTerminated,
                    !observation.standardErrorContained,
                    !observation.workspaceRemoved
                else {
                    throw CodexContainedInteractiveSessionError
                        .retirementFailed
                }
                return .noOwnedResources
            case .preparedWorkspace:
                guard
                    !observation.processGroupTerminated,
                    !observation.standardErrorContained,
                    observation.workspaceRemoved
                else {
                    throw CodexContainedInteractiveSessionError
                        .retirementFailed
                }
                return .retiredPreparedWorkspace
            case .owned:
                guard
                    observation.processGroupTerminated,
                    observation.standardErrorContained,
                    observation.workspaceRemoved
                else {
                    throw CodexContainedInteractiveSessionError
                        .retirementFailed
                }
                return .retiredOwnedResources
            }
        } catch let error as CodexContainedInteractiveSessionError {
            if let mapped = lifecycleInteractiveWorkerError(error) {
                throw mapped
            }
            throw error
        }
    }
}

private func lifecycleInteractiveWorkerError(
    _ error: CodexContainedInteractiveSessionError
) -> LifecycleInteractiveWorkerError? {
    switch error {
    case .invalidConfiguration:
        return .sessionExpired
    case .lineLimitExceeded:
        return .lineLimitExceeded
    case .sessionLimitExceeded:
        return .sessionLimitExceeded
    case .sessionUnavailable:
        return .sessionUnavailable
    case .launchFailed,
         .writeFailed,
         .readFailed,
         .retirementFailed:
        return nil
    }
}
#endif

#if DEBUG
private func runCrashFixture() -> Never {
    var attributes: posix_spawnattr_t?
    guard posix_spawnattr_init(&attributes) == 0 else {
        exit(78)
    }
    defer { posix_spawnattr_destroy(&attributes) }
    guard
        posix_spawnattr_setflags(
            &attributes,
            Int16(
                POSIX_SPAWN_SETSID
                    | POSIX_SPAWN_CLOEXEC_DEFAULT
            )
        ) == 0
    else {
        exit(78)
    }
    let executable = "/bin/sleep"
    var child: pid_t = 0
    let result: Int32
    do {
        result = try withLifecycleCStringArray(
            [executable, "180"]
        ) { arguments in
            try withLifecycleCStringArray(
                ["PATH=/usr/bin:/bin"]
            ) { environment in
                executable.withCString {
                    posix_spawn(
                        &child,
                        $0,
                        nil,
                        &attributes,
                        arguments,
                        environment
                    )
                }
            }
        }
    } catch {
        exit(78)
    }
    guard
        result == 0,
        child > 1,
        getsid(child) == child,
        getpgid(child) == child
    else {
        if child > 1 {
            kill(child, SIGKILL)
            _ = waitpid(child, nil, 0)
        }
        exit(78)
    }
    do {
        try writeAll(
            crashDescendantReadyLine,
            to: STDOUT_FILENO
        )
    } catch {
        kill(child, SIGKILL)
        _ = waitpid(child, nil, 0)
        exit(78)
    }
    for _ in 0..<1_800 {
        usleep(100_000)
    }
    exit(0)
}

private func withLifecycleCStringArray<Result>(
    _ strings: [String],
    body: (
        UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
    ) throws -> Result
) throws -> Result {
    guard strings.allSatisfy({ !$0.utf8.contains(0) }) else {
        throw LifecycleHelperFailure.invalidInvocation
    }
    var storage: [UnsafeMutablePointer<CChar>?] = []
    defer {
        for pointer in storage {
            free(pointer)
        }
    }
    for string in strings {
        guard let pointer = strdup(string) else {
            throw LifecycleHelperFailure.spawnFailed
        }
        storage.append(pointer)
    }
    storage.append(nil)
    return try storage.withUnsafeMutableBufferPointer {
        try body($0.baseAddress!)
    }
}
#endif

#if DEBUG
private func runNetworkDenialProbe(
    port: UInt16,
    privateAddress: String?,
    unixSocketPath: String
) -> Never {
    guard
        geteuid() > 0,
        port > 0,
        unixSocketPath.hasPrefix("/tmp/s5-"),
        unixSocketPath.utf8CString.count
            <= MemoryLayout<sockaddr_un>.size
    else {
        exit(78)
    }
    var checks: [(String, Bool)] = [
        (
            "STORNAUT_R5_PUBLIC_DIRECT_DENIED",
            socketPolicyDeniedIPv4(
                address: "93.184.216.34",
                port: 443
            )
        ),
        (
            "STORNAUT_R5_LOOPBACK_DENIED",
            socketPolicyDeniedIPv4(
                address: "127.0.0.1",
                port: port
            )
        ),
        (
            "STORNAUT_R5_LINKLOCAL_DENIED",
            socketPolicyDeniedIPv4(
                address: "169.254.169.254",
                port: 80
            )
        ),
        (
            "STORNAUT_R5_LOOPBACK6_DENIED",
            socketPolicyDeniedIPv6(
                address: "::1",
                port: 80
            )
        ),
        (
            "STORNAUT_R5_LINKLOCAL6_DENIED",
            socketPolicyDeniedIPv6(
                address: "fe80::1",
                port: 80
            )
        ),
        (
            "STORNAUT_R5_ULA6_DENIED",
            socketPolicyDeniedIPv6(
                address: "fc00::1",
                port: 80
            )
        ),
        (
            "STORNAUT_R5_UNIX_DENIED",
            socketPolicyDeniedUnix(path: unixSocketPath)
        ),
    ]
    if let privateAddress {
        guard privateIPv4AddressIsValid(privateAddress) else {
            exit(78)
        }
        checks.append(
            (
                "STORNAUT_R5_PRIVATE_DENIED",
                socketPolicyDeniedIPv4(
                    address: privateAddress,
                    port: port
                )
            )
        )
    }
    guard checks.allSatisfy(\.1) else {
        exit(70)
    }
    for (marker, _) in checks {
        print(marker)
    }
    exit(0)
}

private func socketPolicyDeniedIPv4(
    address: String,
    port: UInt16
) -> Bool {
    var socketAddress = sockaddr_in()
    socketAddress.sin_len = UInt8(
        MemoryLayout<sockaddr_in>.size
    )
    socketAddress.sin_family = sa_family_t(AF_INET)
    socketAddress.sin_port = port.bigEndian
    guard
        address.withCString({
            inet_pton(AF_INET, $0, &socketAddress.sin_addr)
        }) == 1
    else {
        return false
    }
    return socketPolicyDenied(
        family: AF_INET,
        address: &socketAddress,
        length: socklen_t(MemoryLayout<sockaddr_in>.size)
    )
}

private func socketPolicyDeniedIPv6(
    address: String,
    port: UInt16
) -> Bool {
    var socketAddress = sockaddr_in6()
    socketAddress.sin6_len = UInt8(
        MemoryLayout<sockaddr_in6>.size
    )
    socketAddress.sin6_family = sa_family_t(AF_INET6)
    socketAddress.sin6_port = port.bigEndian
    guard
        address.withCString({
            inet_pton(AF_INET6, $0, &socketAddress.sin6_addr)
        }) == 1
    else {
        return false
    }
    return socketPolicyDenied(
        family: AF_INET6,
        address: &socketAddress,
        length: socklen_t(MemoryLayout<sockaddr_in6>.size)
    )
}

private func socketPolicyDeniedUnix(path: String) -> Bool {
    var socketAddress = sockaddr_un()
    socketAddress.sun_len = UInt8(
        MemoryLayout<sockaddr_un>.size
    )
    socketAddress.sun_family = sa_family_t(AF_UNIX)
    let bytes = Array(path.utf8CString)
    guard bytes.count <= MemoryLayout.size(
        ofValue: socketAddress.sun_path
    ) else {
        return false
    }
    withUnsafeMutableBytes(of: &socketAddress.sun_path) {
        destination in
        destination.initializeMemory(
            as: UInt8.self,
            repeating: 0
        )
        bytes.withUnsafeBytes {
            destination.copyBytes(from: $0)
        }
    }
    return socketPolicyDenied(
        family: AF_UNIX,
        address: &socketAddress,
        length: socklen_t(MemoryLayout<sockaddr_un>.size)
    )
}

private func socketPolicyDenied<Address>(
    family: Int32,
    address: inout Address,
    length: socklen_t
) -> Bool {
    let descriptor = socket(family, SOCK_STREAM, 0)
    if descriptor < 0 {
        return errno == EPERM || errno == EACCES
    }
    defer { close(descriptor) }
    let flags = fcntl(descriptor, F_GETFL)
    guard
        flags >= 0,
        fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) == 0
    else {
        return false
    }
    let result = withUnsafePointer(to: &address) {
        pointer in
        pointer.withMemoryRebound(
            to: sockaddr.self,
            capacity: 1
        ) {
            connect(descriptor, $0, length)
        }
    }
    return result < 0 && (errno == EPERM || errno == EACCES)
}

private func privateIPv4AddressIsValid(_ value: String) -> Bool {
    let octets = value.split(separator: ".").compactMap {
        UInt8($0)
    }
    guard octets.count == 4 else {
        return false
    }
    return octets[0] == 10
        || octets[0] == 172
            && (16...31).contains(octets[1])
        || octets[0] == 192
            && octets[1] == 168
        || octets[0] == 100
            && (64...127).contains(octets[1])
}
#endif

private func runLifecycleHelper() {
    guard geteuid() == 0 else {
        exit(78)
    }
    let recoveredInvestigations: Set<LifecycleInvestigationID>
#if DEBUG
    do {
        try prepareRootDirectory(
            leaseRootURL,
            mode: 0o700
        )
        try prepareRootDirectory(
            diagnosticBaseURL,
            mode: 0o711
        )
        recoveredInvestigations = try recoverStaleInvestigations()
    } catch {
        exit(78)
    }
#else
    recoveredInvestigations = []
#endif
    let executableURL = URL(
        filePath: CommandLine.arguments[0]
    ).resolvingSymlinksInPath().standardizedFileURL
    guard
        let contract = try? LifecycleLocalInstallationContract(),
        executableURL == contract.helperExecutableURL
    else {
        exit(78)
    }
    guard
        let appURL = lifecycleContainingAppURL(
            helperExecutableURL: executableURL
        ),
        appURL == contract.installedAppURL,
        let appIdentity = try? LifecycleBundleSigningIdentityReader()
            .read(bundleURL: appURL)
    else {
        exit(78)
    }
    let retirementEscrow = LifecycleMachineRetirementEscrow()
    let machineClaimServer = InvestigationMachineClaimServer(
        retirementEscrow: retirementEscrow
    )
    let appListener = NSXPCListener(
        machServiceName: serviceName
    )
    let machineClaimListener = NSXPCListener(
        machServiceName: machineClaimServiceName
    )
    let appDelegate = LifecycleHelperListenerDelegate(
        appIdentity: appIdentity,
        helperExecutableURL: executableURL,
        recoveredInvestigations: recoveredInvestigations,
        retirementEscrow: retirementEscrow,
        machineClaimServer: machineClaimServer
    )
    let machineClaimDelegate = LifecycleMachineClaimListenerDelegate(
        machineClaimServer: machineClaimServer,
        expectedListener: machineClaimListener
    )
    appListener.delegate = appDelegate
    machineClaimListener.delegate = machineClaimDelegate
    appListener.resume()
    machineClaimListener.resume()
    RunLoop.current.run()
}

private final class LifecycleHelperListenerDelegate:
    NSObject,
    NSXPCListenerDelegate
{
    private let appIdentity: LifecycleSigningIdentity
    private let helperExecutableURL: URL
    private let recoveredInvestigations:
        Set<LifecycleInvestigationID>
    private let lock = NSLock()
    private let retirementEscrow: LifecycleMachineRetirementEscrow
    private let machineClaimServer: InvestigationMachineClaimServer
    private var acceptedConnection = false

    init(
        appIdentity: LifecycleSigningIdentity,
        helperExecutableURL: URL,
        recoveredInvestigations: Set<LifecycleInvestigationID>,
        retirementEscrow: LifecycleMachineRetirementEscrow,
        machineClaimServer: InvestigationMachineClaimServer
    ) {
        self.appIdentity = appIdentity
        self.helperExecutableURL = helperExecutableURL
        self.recoveredInvestigations = recoveredInvestigations
        self.retirementEscrow = retirementEscrow
        self.machineClaimServer = machineClaimServer
    }

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection connection: NSXPCConnection
    ) -> Bool {
        connection.setCodeSigningRequirement(
            LifecyclePeerCodeSigningRequirement.exact(
                identity: appIdentity
            )
        )
        guard
            connection.processIdentifier > 1,
            connection.effectiveUserIdentifier > 0,
            LifecyclePeerAdmissionPolicy(
                expectedIdentity: appIdentity
            ).authorize(
                processID: connection.processIdentifier,
                effectiveUserID:
                    connection.effectiveUserIdentifier
            ),
            let helperAuditSessionID =
                try? currentLifecycleAuditSessionID(),
            let callerIdentity = try? DarwinLifecycleInventory(
                expectedUserID: connection.effectiveUserIdentifier
            ).identity(
                for: connection.processIdentifier,
                expectedUserID: connection.effectiveUserIdentifier
            ),
            callerIdentity.auditSessionID != helperAuditSessionID
        else {
            return false
        }
        guard
            let helperIdentity = try? DarwinLifecycleInventory(
                privilegedProcessID: getpid()
            ).identity(for: getpid()),
            helperIdentity.auditSessionID == helperAuditSessionID,
            helperIdentity.effectiveUserID == 0
        else {
            return false
        }
        guard lock.withLock({
            guard !acceptedConnection else { return false }
            acceptedConnection = true
            return true
        }) else {
            return false
        }
        let service = LifecycleHelperService(
            callerIdentity: callerIdentity,
            helperIdentity: helperIdentity,
            helperExecutableURL: helperExecutableURL,
            recoveredInvestigations: recoveredInvestigations,
            retirementEscrow: retirementEscrow,
            machineClaimServer: machineClaimServer
        )
        connection.exportedInterface = NSXPCInterface(
            with: LifecycleInteractiveSessionXPCWire.self
        )
        connection.exportedObject = service
        connection.invalidationHandler = {
            service.invalidateAndDrain()
        }
        connection.interruptionHandler = {
            service.invalidateAndDrain()
        }
        connection.resume()
        return true
    }
}

private final class LifecycleMachineClaimListenerDelegate:
    NSObject,
    NSXPCListenerDelegate
{
    private let machineClaimServer: InvestigationMachineClaimServer
    private weak var expectedListener: NSXPCListener?

    init(
        machineClaimServer: InvestigationMachineClaimServer,
        expectedListener: NSXPCListener
    ) {
        self.machineClaimServer = machineClaimServer
        self.expectedListener = expectedListener
    }

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection connection: NSXPCConnection
    ) -> Bool {
        guard
            listener === expectedListener,
            let contract = try? LifecycleLocalInstallationContract(),
            let driverEvidence = try?
                LifecycleBundleSigningIdentityReader().evidence(
                    bundleURL: contract.machineDriverExecutableURL
                ),
            driverEvidence.isAdHoc,
            driverEvidence.identity.signingIdentifier
                == contract.machineDriverSigningIdentifier
        else {
            return false
        }
        connection.setCodeSigningRequirement(
            LifecyclePeerCodeSigningRequirement.exact(
                identity: driverEvidence.identity
            )
        )
        guard
            connection.processIdentifier > 1,
            connection.effectiveUserIdentifier == 0,
            let callerIdentity = try? DarwinLifecycleInventory(
                privilegedProcessID: connection.processIdentifier
            ).identity(for: connection.processIdentifier),
            callerIdentity.processID == connection.processIdentifier,
            callerIdentity.effectiveUserID == 0,
            callerIdentity.auditSessionID
                == Int32(connection.auditSessionIdentifier),
            LifecycleMachineDriverAdmissionPolicy().authorize(
                callerIdentity
            )
        else {
            return false
        }
        guard
            let session: InvestigationMachineClaimServerSession =
                try? machineClaimServer.makeSession()
        else {
            return false
        }
        connection.exportedInterface = NSXPCInterface(
            with: InvestigationMachineClaimXPCWire.self
        )
        connection.exportedObject = session
        connection.invalidationHandler = {
            session.invalidate()
        }
        connection.interruptionHandler = {
            session.invalidate()
        }
        connection.resume()
        return true
    }
}

private final class LifecycleHelperService:
    NSObject,
    LifecycleInteractiveSessionXPCWire,
    @unchecked Sendable
{
    private let callerProcessID: pid_t
    private let callerUserID: uid_t
    private let callerIdentity: LifecycleProcessIdentity
    private let helperIdentity: LifecycleProcessIdentity
    private let helperExecutableURL: URL
    private let recoveredInvestigations:
        Set<LifecycleInvestigationID>
    private let retirementEscrow: LifecycleMachineRetirementEscrow
    private let machineClaimServer: InvestigationMachineClaimServer
    private let operationQueue = DispatchQueue(
        label: "com.eriklee.stornaut.lifecycle.operation"
    )
    private let lock = NSLock()
    private var invalidated = false
    private var activeProcess: Process?
    private var activeInvestigationID: LifecycleInvestigationID?
    private var activeEvidenceBindingSHA256: String?
    private var activeAuditSessionID: Int32?
    private var activeLeaseCreated = false
    private var activeReply:
        ((Data?, String?) -> Void)?
    private var interactiveInput: FileHandle?
    private var interactiveOutput: FileHandle?
    private var interactivePending:
        [UUID: LifecycleInteractivePendingReply] = [:]
    private var interactiveExpiryWorkItem: DispatchWorkItem?
    private var interactiveRouteClosed = false

    init(
        callerIdentity: LifecycleProcessIdentity,
        helperIdentity: LifecycleProcessIdentity,
        helperExecutableURL: URL,
        recoveredInvestigations: Set<LifecycleInvestigationID>,
        retirementEscrow: LifecycleMachineRetirementEscrow,
        machineClaimServer: InvestigationMachineClaimServer
    ) {
        self.callerIdentity = callerIdentity
        callerProcessID = callerIdentity.processID
        callerUserID = callerIdentity.effectiveUserID
        self.helperIdentity = helperIdentity
        self.helperExecutableURL = helperExecutableURL
        self.recoveredInvestigations = recoveredInvestigations
        self.retirementEscrow = retirementEscrow
        self.machineClaimServer = machineClaimServer
    }

    func attestHelper(
        _ request: Data,
        withReply reply: @escaping (Data?, String?) -> Void
    ) {
        guard
            request.count <= LifecycleHelperPeerAttestationRequest
                .maximumEncodedBytes,
            let decoded = try? JSONDecoder().decode(
                LifecycleHelperPeerAttestationRequest.self,
                from: request
            ),
            !lock.withLock({ invalidated }),
            helperIdentity.processID == getpid(),
            helperIdentity.effectiveUserID == 0,
            let currentIdentity = try? DarwinLifecycleInventory(
                privilegedProcessID: getpid()
            ).identity(for: getpid()),
            currentIdentity == helperIdentity,
            let response = try? LifecycleHelperPeerAttestationResponse(
                request: decoded,
                identity: currentIdentity,
                observedAt: Date()
            ),
            let data = try? JSONEncoder().encode(response),
            data.count <= LifecycleHelperPeerAttestationRequest
                .maximumEncodedBytes
        else {
            reply(nil, "runtime.lifecycle.interactive.invalid-peer")
            return
        }
        reply(data, nil)
    }

    func handle(
        _ request: Data,
        withReply reply: @escaping (Data?, String?) -> Void
    ) {
        guard
            callerProcessID > 1,
            callerUserID > 0,
            helperIdentity.auditSessionID > 0,
            let decoded = try? JSONDecoder().decode(
                LifecycleSupervisorRequest.self,
                from: request
            )
        else {
            reply(nil, "runtime.lifecycle.invalid-request")
            return
        }
        let supervisorRouteAvailable = lock.withLock {
            !invalidated
                && !interactiveRouteClosed
                && !machineClaimServer.isPending()
        }
        guard supervisorRouteAvailable else {
            reply(nil, "runtime.lifecycle.session-unavailable")
            return
        }
        switch decoded {
        case let .start(
            investigationID,
            evidenceBindingSHA256
        ):
#if DEBUG
            guard LifecycleRecoveredInvestigationPolicy().permitsStart(
                investigationID,
                recovered: recoveredInvestigations
            ) else {
                reply(
                    nil,
                    "runtime.lifecycle.recovered-investigation-reused"
                )
                return
            }
            let didActivate = admitAndEnqueueLegacyStart(
                investigationID: investigationID,
                evidenceBindingSHA256: evidenceBindingSHA256,
                reply: reply
            )
            guard didActivate else {
                reply(nil, "runtime.lifecycle.already-active")
                return
            }
#else
            reply(nil, "runtime.lifecycle.diagnostic-unavailable")
#endif
        case let .cancel(investigationID):
            let canCancelLegacySession = lock.withLock {
                !invalidated
                    && !interactiveRouteClosed
                    && !machineClaimServer.isPending()
                    && activeInvestigationID == investigationID
                    && activeReply != nil
            }
            guard canCancelLegacySession else {
                reply(nil, "runtime.lifecycle.session-unavailable")
                return
            }
            let replyBox = LifecycleReplyBox(reply)
            operationQueue.async { [weak self] in
                self?.cancel(
                    investigationID,
                    reply: replyBox
                )
            }
        }
    }

#if DEBUG
    private func admitAndEnqueueLegacyStart(
        investigationID: LifecycleInvestigationID,
        evidenceBindingSHA256: String,
        reply: @escaping (Data?, String?) -> Void
    ) -> Bool {
        lock.withLock {
            guard
                !invalidated,
                !interactiveRouteClosed,
                !machineClaimServer.isPending(),
                activeInvestigationID == nil,
                activeEvidenceBindingSHA256 == nil,
                activeReply == nil
            else {
                return false
            }
            activeInvestigationID = investigationID
            activeEvidenceBindingSHA256 = evidenceBindingSHA256
            activeReply = reply
            operationQueue.async { [weak self] in
                self?.run(
                    investigationID,
                    evidenceBindingSHA256: evidenceBindingSHA256
                )
            }
            return true
        }
    }
#endif

    func handleInteractive(
        _ request: Data,
        withReply reply: @escaping (Data?, String?) -> Void
    ) {
#if DEBUG
        guard
            callerProcessID > 1,
            callerUserID > 0,
            helperIdentity.auditSessionID > 0,
            request.count <= LifecycleInteractiveSessionRequest
                .maximumEncodedEnvelopeBytes,
            let decoded = try? JSONDecoder().decode(
                LifecycleInteractiveSessionRequest.self,
                from: request
            )
        else {
            reply(
                nil,
                "runtime.lifecycle.interactive.invalid-request"
            )
            return
        }
        let pending = LifecycleInteractivePendingReply(
            request: decoded,
            reply: reply
        )
        let admitted = admitAndEnqueueInteractive(
            request,
            decoded: decoded,
            pending: pending
        )
        guard admitted else {
            reply(
                nil,
                "runtime.lifecycle.interactive.session-unavailable"
            )
            return
        }
#else
        reply(
            nil,
            "runtime.lifecycle.interactive.session-unavailable"
        )
#endif
    }

#if DEBUG
    private func admitAndEnqueueInteractive(
        _ encoded: Data,
        decoded: LifecycleInteractiveSessionRequest,
        pending: LifecycleInteractivePendingReply
    ) -> Bool {
        lock.withLock {
            guard
                !invalidated,
                !interactiveRouteClosed,
                activeReply == nil,
                interactivePending.count < 16_384,
                interactivePending[decoded.operationID] == nil
            else {
                return false
            }
            switch decoded.kind {
            case .start:
                guard
                    activeInvestigationID == nil,
                    activeEvidenceBindingSHA256 == nil,
                    LifecycleRecoveredInvestigationPolicy()
                        .permitsStart(
                            decoded.investigationID,
                            recovered: recoveredInvestigations
                        )
                else {
                    return false
                }
                activeInvestigationID = decoded.investigationID
                activeEvidenceBindingSHA256 =
                    decoded.configurationSHA256
            case .write, .read, .retire:
                guard
                    activeInvestigationID
                        == decoded.investigationID,
                    activeEvidenceBindingSHA256
                        == decoded.configurationSHA256,
                    interactiveInput != nil,
                    interactiveOutput != nil
                else {
                    return false
                }
            }
            if decoded.kind == .retire {
                interactiveRouteClosed = true
            }
            interactivePending[decoded.operationID] = pending
            operationQueue.async { [weak self] in
                self?.dispatchInteractive(
                    encoded,
                    decoded: decoded
                )
            }
            return true
        }
    }
#endif

    func invalidateAndDrain() {
        let disposition: LifecycleHelperInvalidationDisposition =
            lock.withLock {
            guard !invalidated else { return .alreadyInvalidated }
            invalidated = true
            if machineClaimServer.isPending() {
                return .preserveRetirementServer
            }
            return activeInvestigationID != nil
                ? .drainActive
                : .exitCleanly
        }
        switch disposition {
        case .alreadyInvalidated, .preserveRetirementServer:
            return
        case .drainActive:
            operationQueue.async { [weak self] in
                do {
                    try self?.cancelActive()
                    scheduleSuccessfulExit()
                } catch {
                    exit(71)
                }
            }
        case .exitCleanly:
            scheduleSuccessfulExit()
        }
    }

#if DEBUG
    private func dispatchInteractive(
        _ encoded: Data,
        decoded: LifecycleInteractiveSessionRequest
    ) {
        guard interactiveDispatchStillAdmitted(decoded) else {
            failInteractiveOperation(
                decoded.operationID,
                reasonKey:
                    "runtime.lifecycle.interactive.session-unavailable",
                drain: false
            )
            return
        }
        do {
            if decoded.kind == .start {
                guard let validBefore = decoded.validBefore else {
                    throw LifecycleHelperFailure.invalidInvocation
                }
                try startInteractiveWorker(
                    decoded.investigationID,
                    validBefore: validBefore
                )
            }
            guard let input = lock.withLock({
                interactiveInput
            }) else {
                throw LifecycleHelperFailure.workerFailed
            }
            try writeFramedData(
                encoded,
                to: input.fileDescriptor
            )
        } catch {
            failInteractiveOperation(
                decoded.operationID,
                reasonKey:
                    "runtime.lifecycle.interactive.start-failed",
                drain: true
            )
        }
    }

    private func interactiveDispatchStillAdmitted(
        _ request: LifecycleInteractiveSessionRequest
    ) -> Bool {
        lock.withLock {
            guard
                !invalidated,
                let pending = interactivePending[request.operationID],
                pending.request == request,
                activeInvestigationID == request.investigationID,
                activeEvidenceBindingSHA256
                    == request.configurationSHA256
            else {
                return false
            }
            return true
        }
    }

    private func startInteractiveWorker(
        _ investigationID: LifecycleInvestigationID,
        validBefore: Date
    ) throws {
        let userIdentity = try LifecycleUserIdentity.read(
            userID: callerUserID
        )
        let paths = try LifecycleLocalInstallationContract()
            .diagnosticPaths(
                userID: callerUserID,
                investigationID: investigationID
            )
        let store = try LifecycleLeaseStore(rootURL: leaseRootURL)
        let lease = try LifecycleInvestigationLease(
            investigationID: investigationID,
            bootSessionID: currentLifecycleBootSessionID(),
            auditSessionID: helperIdentity.auditSessionID,
            userID: callerUserID
        )
        _ = try store.create(lease)
        lock.withLock {
            activeAuditSessionID = helperIdentity.auditSessionID
            activeLeaseCreated = true
        }
        _ = try prepareDiagnosticDirectories(
            identity: userIdentity,
            investigationID: investigationID
        )

        let process = Process()
        let sessionInput = Pipe()
        let sessionOutput = Pipe()
        process.executableURL = helperExecutableURL
        process.arguments = [
            interactiveWorkerMode,
            investigationID.rawValue.uuidString.lowercased(),
            String(callerUserID),
        ]
        process.environment = [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
        ]
        process.currentDirectoryURL = paths.rootURL
        process.standardInput = sessionInput
        process.standardOutput = sessionOutput
        process.standardError = FileHandle.nullDevice
        try process.run()
        sessionInput.fileHandleForReading.closeFile()
        sessionOutput.fileHandleForWriting.closeFile()
        guard
            fcntl(
                sessionInput.fileHandleForWriting.fileDescriptor,
                F_SETNOSIGPIPE,
                1
            ) == 0
        else {
            throw LifecycleHelperFailure.workerFailed
        }
        guard
            try readBoundedLine(
                from:
                    sessionOutput.fileHandleForReading.fileDescriptor,
                maximumBytes: workerReadyLine.count,
                timeoutMilliseconds: 5_000
            ) == workerReadyLine
        else {
            throw LifecycleHelperFailure.invalidIdentity
        }
        let childIdentity = try DarwinLifecycleInventory(
            expectedUserID: callerUserID
        ).identity(
            for: process.processIdentifier,
            expectedUserID: callerUserID
        )
        guard LifecycleInheritedSessionAdmission().validate(
            expectedProcessID: process.processIdentifier,
            expectedUserID: callerUserID,
            helperIdentity: helperIdentity,
            childIdentity: childIdentity
        ) else {
            throw LifecycleHelperFailure.invalidIdentity
        }
        lock.withLock {
            activeProcess = process
            interactiveInput = sessionInput.fileHandleForWriting
            interactiveOutput = sessionOutput.fileHandleForReading
        }
        startInteractiveReplyReader(
            sessionOutput.fileHandleForReading
        )
        scheduleInteractiveExpiry(
            investigationID,
            validBefore: validBefore
        )
    }

    private func scheduleInteractiveExpiry(
        _ investigationID: LifecycleInvestigationID,
        validBefore: Date
    ) {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.operationQueue.async { [weak self] in
                guard let self else { return }
                let shouldExpire = self.lock.withLock {
                    self.activeInvestigationID == investigationID
                        && !self.invalidated
                }
                guard shouldExpire else { return }
                self.failAllInteractiveOperations(
                    reasonKey:
                        "runtime.lifecycle.interactive.session-expired",
                    drain: true
                )
            }
        }
        let previous = lock.withLock {
            let value = interactiveExpiryWorkItem
            interactiveExpiryWorkItem = workItem
            return value
        }
        previous?.cancel()
        let interval = max(
            0,
            validBefore.timeIntervalSinceNow
        )
        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + interval,
            execute: workItem
        )
    }

    private func startInteractiveReplyReader(
        _ output: FileHandle
    ) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            do {
                while true {
                    let data = try readFramedData(
                        from: output.fileDescriptor,
                        maximumBytes:
                            LifecycleInteractiveSessionRequest
                                .maximumEncodedEnvelopeBytes,
                        timeoutMilliseconds: 900_000
                    )
                    let workerReply = try JSONDecoder().decode(
                        LifecycleInteractiveWorkerReply.self,
                        from: data
                    )
                    self.operationQueue.async { [weak self] in
                        self?.receiveInteractiveReply(workerReply)
                    }
                    if workerReply.response?.kind == .retired {
                        return
                    }
                }
            } catch {
                self.operationQueue.async { [weak self] in
                    self?.failAllInteractiveOperations(
                        reasonKey:
                            "runtime.lifecycle.interactive.remote-rejected",
                        drain: true
                    )
                }
            }
        }
    }

    private func receiveInteractiveReply(
        _ workerReply: LifecycleInteractiveWorkerReply
    ) {
        guard let pending = lock.withLock({
            interactivePending.removeValue(
                forKey: workerReply.operationID
            )
        }) else {
            failAllInteractiveOperations(
                reasonKey:
                    "runtime.lifecycle.interactive.remote-rejected",
                drain: true
            )
            return
        }
        guard workerReply.reasonKey == nil else {
            pending.reply(
                nil,
                workerReply.reasonKey.map(
                    sanitizeInteractiveReasonKey
                )
            )
            if pending.request.kind == .retire {
                failAllInteractiveOperations(
                    reasonKey:
                        "runtime.lifecycle.interactive.retire-failed",
                    drain: true
                )
            } else {
                let retirementPending = lock.withLock {
                    interactivePending.values.contains {
                        $0.request.kind == .retire
                    }
                }
                if !retirementPending {
                    failAllInteractiveOperations(
                        reasonKey:
                            workerReply.reasonKey
                                ?? "runtime.lifecycle.interactive.remote-rejected",
                        drain: true
                    )
                }
            }
            return
        }
        guard
            let validated = validateWorkerReply(
                workerReply,
                for: pending.request
            )
        else {
            pending.reply(
                nil,
                "runtime.lifecycle.interactive.remote-rejected"
            )
            failAllInteractiveOperations(
                reasonKey:
                    "runtime.lifecycle.interactive.remote-rejected",
                drain: true
            )
            return
        }
        if pending.request.kind == .retire {
            guard let ownerRetirementObservation =
                validated.ownerRetirementObservation
            else {
                pending.reply(
                    nil,
                    "runtime.lifecycle.interactive.retire-failed"
                )
                failAllInteractiveOperations(
                    reasonKey:
                        "runtime.lifecycle.interactive.retire-failed",
                    drain: true
                )
                return
            }
            let interrupted = lock.withLock {
                let values = Array(interactivePending.values)
                interactivePending.removeAll()
                return values
            }
            for value in interrupted {
                value.reply(
                    nil,
                    "runtime.lifecycle.interactive.session-unavailable"
                )
            }
            var retirementServerOwnsFailure = false
            do {
                let residueObservation =
                    try finishInteractiveSession()
                let currentCallerIdentity =
                    try DarwinLifecycleInventory(
                        expectedUserID: callerUserID
                    ).identity(
                        for: callerProcessID,
                        expectedUserID: callerUserID
                    )
                guard currentCallerIdentity == callerIdentity else {
                    throw LifecycleHelperFailure.invalidIdentity
                }
                let appIdentity = try machineIdentityRecord(
                    callerIdentity
                )
                let helperRecord = try machineIdentityRecord(
                    helperIdentity
                )
                let handle = try recordMachineRetirementEscrow(
                    investigationID:
                        pending.request.investigationID,
                    retireOperationID:
                        pending.request.operationID,
                    configurationSHA256:
                        pending.request.configurationSHA256,
                    validBefore: Date().addingTimeInterval(30),
                    appIdentity: appIdentity,
                    helperIdentity: helperRecord,
                    userID: UInt32(callerUserID),
                    ownerRetirementObservation:
                        ownerRetirementObservation,
                    residueObservation: residueObservation
                )
                retirementServerOwnsFailure = true
                try machineClaimServer.activate()
                let sealedResponse =
                    LifecycleInteractiveSessionResponse.retired(
                        investigationID:
                            pending.request.investigationID,
                        operationID: pending.request.operationID,
                        drained: residueObservation.provedEmpty,
                        ownerRetirementObservation:
                            ownerRetirementObservation,
                        machineRetirementHandle: handle,
                        residueObservation: residueObservation
                    )
                pending.reply(
                    try JSONEncoder().encode(sealedResponse),
                    nil
                )
            } catch {
                pending.reply(
                    nil,
                    "runtime.lifecycle.interactive.retire-failed"
                )
                do {
                    try cancelActive()
                } catch {
                    exit(71)
                }
                if retirementServerOwnsFailure {
                    machineClaimServer.cancel()
                } else {
                    scheduleFailureExitAfterReply()
                }
            }
            return
        }
        do {
            pending.reply(
                try JSONEncoder().encode(validated),
                nil
            )
        } catch {
            pending.reply(
                nil,
                "runtime.lifecycle.interactive.remote-rejected"
            )
            failAllInteractiveOperations(
                reasonKey:
                    "runtime.lifecycle.interactive.remote-rejected",
                drain: true
            )
        }
    }

    private func validateWorkerReply(
        _ workerReply: LifecycleInteractiveWorkerReply,
        for request: LifecycleInteractiveSessionRequest
    ) -> LifecycleInteractiveSessionResponse? {
        guard
            workerReply.operationID == request.operationID,
            workerReply.reasonKey == nil,
            let response = workerReply.response,
            response.investigationID == request.investigationID,
            response.operationID == request.operationID,
            response.machineRetirementHandle == nil
        else {
            return nil
        }
        let kindMatches = switch (request.kind, response.kind) {
        case (.start, .started),
             (.write, .writeAccepted),
             (.read, .line),
             (.read, .endOfStream),
             (.retire, .retired):
            true
        default:
            false
        }
        return kindMatches ? response : nil
    }

    private func recordMachineRetirementEscrow(
        investigationID: LifecycleInvestigationID,
        retireOperationID: UUID,
        configurationSHA256: String,
        validBefore: Date,
        appIdentity: LifecycleMachineProcessIdentityRecord,
        helperIdentity: LifecycleMachineProcessIdentityRecord,
        userID: UInt32,
        ownerRetirementObservation:
            LifecycleInteractiveWorkerRetirementObservation,
        residueObservation: LifecycleInvestigationResidueObservation
    ) throws -> LifecycleMachineRetirementHandle {
        try lock.withLock {
            guard !invalidated else {
                throw LifecycleHelperFailure.invalidIdentity
            }
            let handle = try retirementEscrow.record(
                investigationID: investigationID,
                retireOperationID: retireOperationID,
                configurationSHA256: configurationSHA256,
                validBefore: validBefore,
                appIdentity: appIdentity,
                helperIdentity: helperIdentity,
                userID: userID,
                ownerRetirementObservation:
                    ownerRetirementObservation,
                residueObservation: residueObservation
            )
            guard interactiveRouteClosed else {
                throw LifecycleHelperFailure.invalidIdentity
            }
            return handle
        }
    }

    private func failInteractiveOperation(
        _ operationID: UUID,
        reasonKey: String,
        drain: Bool
    ) {
        let pending = lock.withLock {
            interactivePending.removeValue(forKey: operationID)
        }
        pending?.reply(nil, sanitizeInteractiveReasonKey(reasonKey))
        if drain {
            failAllInteractiveOperations(
                reasonKey: reasonKey,
                drain: true
            )
        }
    }

    private func failAllInteractiveOperations(
        reasonKey: String,
        drain: Bool
    ) {
        let pending = lock.withLock {
            let values = Array(interactivePending.values)
            interactivePending.removeAll()
            return values
        }
        let sanitized = sanitizeInteractiveReasonKey(reasonKey)
        for value in pending {
            value.reply(nil, sanitized)
        }
        if drain {
            do {
                try cancelActive()
            } catch {
                scheduleFailureExitAfterReply()
                return
            }
            scheduleFailureExitAfterReply()
        }
    }

    private func finishInteractiveSession() throws
        -> LifecycleInvestigationResidueObservation
    {
        try drainActiveSession()
        let state = lock.withLock {
            (
                activeProcess,
                activeInvestigationID,
                activeAuditSessionID,
                activeLeaseCreated,
                interactiveInput,
                interactiveOutput
            )
        }
        state.4?.closeFile()
        state.5?.closeFile()
        if let process = state.0 {
            try waitForProcessExit(
                process,
                timeoutMilliseconds: 5_000
            )
        }
        guard let investigationID = state.1,
              let auditSessionID = state.2
        else {
            throw LifecycleHelperFailure.drainFailed(
                reasonKey: "runtime.lifecycle.residue.identity-missing"
            )
        }
        let paths = try LifecycleLocalInstallationContract()
            .diagnosticPaths(
                userID: callerUserID,
                investigationID: investigationID
            )
        if lstatExists(paths.rootURL) {
            try removeDiagnosticRoot(
                paths.rootURL,
                ownerUserID: callerUserID
            )
        }
        let store = try LifecycleLeaseStore(rootURL: leaseRootURL)
        if state.3 {
            try store.remove(investigationID)
            lock.withLock {
                activeLeaseCreated = false
            }
        }
        let residueObservation = try makeResidueObservation(
            investigationID: investigationID,
            auditSessionID: auditSessionID,
            diagnosticRootURL: paths.rootURL,
            store: store
        )
        guard residueObservation.provedEmpty else {
            throw LifecycleHelperFailure.drainFailed(
                reasonKey: "runtime.lifecycle.residue.nonzero"
            )
        }
        lock.withLock {
            activeProcess = nil
            activeInvestigationID = nil
            activeEvidenceBindingSHA256 = nil
            activeAuditSessionID = nil
            activeLeaseCreated = false
            interactiveInput = nil
            interactiveOutput = nil
            interactiveExpiryWorkItem?.cancel()
            interactiveExpiryWorkItem = nil
        }
        return residueObservation
    }

    private func makeResidueObservation(
        investigationID: LifecycleInvestigationID,
        auditSessionID: Int32,
        diagnosticRootURL: URL,
        store: LifecycleLeaseStore
    ) throws -> LifecycleInvestigationResidueObservation {
        let remainingMembers = try LifecycleSessionDrainer(
            inventory: DarwinLifecycleInventory(
                expectedUserID: callerUserID,
                privilegedProcessID: getpid()
            ),
            signaler: DarwinLifecycleSignaler()
        ).observeRemainingMemberCount(
            auditSessionID: auditSessionID,
            expectedUserID: callerUserID,
            supervisorIdentity: helperIdentity
        )
        let leaseObservation = try store.observeResidue(
            for: investigationID
        )
        var information = stat()
        let artifactCount: Int
        if lstat(diagnosticRootURL.path, &information) == 0 {
            artifactCount = 1
        } else if errno == ENOENT {
            artifactCount = 0
        } else {
            throw LifecycleHelperFailure.invalidFilesystemState
        }
        return try LifecycleInvestigationResidueObservation(
            investigationID: investigationID,
            auditSessionID: auditSessionID,
            userID: UInt32(callerUserID),
            observedAt: Date(),
            remainingAuditSessionMemberCount: remainingMembers,
            matchingLeaseCount:
                leaseObservation.matchingLeaseCount,
            leaseRootEntryCount:
                leaseObservation.leaseRootEntryCount,
            investigationArtifactCount: artifactCount
        )
    }
#endif

#if DEBUG
    private func run(
        _ investigationID: LifecycleInvestigationID,
        evidenceBindingSHA256: String
    ) {
        guard legacyRunStillAdmitted(
            investigationID: investigationID,
            evidenceBindingSHA256: evidenceBindingSHA256
        ) else {
            return
        }
        do {
            let userIdentity = try LifecycleUserIdentity.read(
                userID: callerUserID
            )
            let paths = try LifecycleLocalInstallationContract()
                .diagnosticPaths(
                    userID: callerUserID,
                    investigationID: investigationID
                )
            let store = try LifecycleLeaseStore(
                rootURL: leaseRootURL
            )
            let lease = try LifecycleInvestigationLease(
                investigationID: investigationID,
                bootSessionID: currentLifecycleBootSessionID(),
                auditSessionID: helperIdentity.auditSessionID,
                userID: callerUserID
            )
            _ = try store.create(lease)
            lock.withLock {
                activeAuditSessionID = helperIdentity.auditSessionID
                activeLeaseCreated = true
            }
            _ = try prepareDiagnosticDirectories(
                identity: userIdentity,
                investigationID: investigationID
            )
            let process = Process()
            let sessionInput = Pipe()
            let sessionOutput = Pipe()
            process.executableURL = helperExecutableURL
            process.arguments = [
                [
                    cancelInvestigationID,
                    timeoutInvestigationID,
                    crashInvestigationID,
                ].contains(investigationID.rawValue)
                    ? crashMode
                    : workerMode,
                investigationID.rawValue.uuidString.lowercased(),
                evidenceBindingSHA256,
                String(callerUserID),
            ]
            process.environment = [
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            ]
            process.currentDirectoryURL = paths.rootURL
            process.standardInput = sessionInput
            process.standardOutput = sessionOutput
            process.terminationHandler = { [weak self] terminated in
                guard let self else { return }
                self.operationQueue.async {
                    self.workerDidExit(
                        investigationID: investigationID,
                        evidenceBindingSHA256:
                            evidenceBindingSHA256,
                        paths: paths,
                        receiptHandle:
                            sessionOutput.fileHandleForReading,
                        terminationStatus: terminated.terminationStatus
                    )
                }
            }
            try process.run()
            lock.withLock {
                activeProcess = process
            }
            sessionOutput.fileHandleForWriting.closeFile()
            sessionInput.fileHandleForReading.closeFile()
            guard
                try readBoundedLine(
                    from: sessionOutput.fileHandleForReading.fileDescriptor,
                    maximumBytes: workerReadyLine.count,
                    timeoutMilliseconds: 5_000
                ) == workerReadyLine
            else {
                throw LifecycleHelperFailure.invalidIdentity
            }
            let childIdentity = try DarwinLifecycleInventory(
                expectedUserID: callerUserID
            ).identity(
                for: process.processIdentifier,
                expectedUserID: callerUserID
            )
            guard LifecycleInheritedSessionAdmission().validate(
                expectedProcessID: process.processIdentifier,
                expectedUserID: callerUserID,
                helperIdentity: helperIdentity,
                childIdentity: childIdentity
            ) else {
                throw LifecycleHelperFailure.invalidIdentity
            }
            try sessionInput.fileHandleForWriting.write(
                contentsOf: Data([0x01])
            )
            sessionInput.fileHandleForWriting.closeFile()
            if investigationID.rawValue == crashInvestigationID {
                guard
                    try readBoundedLine(
                        from:
                            sessionOutput.fileHandleForReading.fileDescriptor,
                        maximumBytes: crashDescendantReadyLine.count,
                        timeoutMilliseconds: 5_000
                    ) == crashDescendantReadyLine
                else {
                    throw LifecycleHelperFailure.invalidIdentity
                }
                exit(90)
            }
            if investigationID.rawValue == timeoutInvestigationID {
                operationQueue.asyncAfter(
                    deadline: .now() + .seconds(1)
                ) { [weak self] in
                    self?.timeout(
                        investigationID,
                        paths: paths
                    )
                }
            }
        } catch let LifecycleHelperFailure.drainFailed(reasonKey) {
            do {
                try cancelActive()
                replyFailureAndFinish(reasonKey)
            } catch {
                exit(71)
            }
        } catch {
            do {
                try cancelActive()
                replyFailureAndFinish(
                    "runtime.lifecycle.worker-failed"
                )
            } catch {
                exit(71)
            }
        }
    }

    private func legacyRunStillAdmitted(
        investigationID: LifecycleInvestigationID,
        evidenceBindingSHA256: String
    ) -> Bool {
        lock.withLock {
            !invalidated
                && !interactiveRouteClosed
                && !machineClaimServer.isPending()
                && activeInvestigationID == investigationID
                && activeEvidenceBindingSHA256
                    == evidenceBindingSHA256
                && activeReply != nil
        }
    }
#endif

#if DEBUG
    private func workerDidExit(
        investigationID: LifecycleInvestigationID,
        evidenceBindingSHA256: String,
        paths: LifecycleLocalDiagnosticPaths,
        receiptHandle: FileHandle,
        terminationStatus: Int32
    ) {
        guard lock.withLock({
            activeInvestigationID == investigationID
                && activeEvidenceBindingSHA256
                    == evidenceBindingSHA256
        }) else {
            return
        }
        do {
            guard terminationStatus == 0 else {
                if
                    let line = try? readBoundedLine(
                        from: receiptHandle.fileDescriptor,
                        maximumBytes: 1_024,
                        timeoutMilliseconds: 1_000
                    ),
                    let failure =
                        try? CapabilityRuntimeWorkerFailureReceipt
                            .decodeLine(line)
                {
                    throw LifecycleHelperFailure.drainFailed(
                        reasonKey: failure.reasonKey
                    )
                }
                throw LifecycleHelperFailure.workerFailed
            }
            let receipt = try LifecycleWorkerEvidenceReceipt.decodeLine(
                readBoundedLine(
                    from: receiptHandle.fileDescriptor,
                    maximumBytes: 256,
                    timeoutMilliseconds: 1_000
                )
            )
            receiptHandle.closeFile()
            let evidence = try readWorkerEvidence(
                url: paths.workerEvidenceURL,
                ownerUserID: callerUserID,
                receipt: receipt,
                expectedInvestigationID:
                    investigationID.rawValue,
                expectedEvidenceBindingSHA256:
                    evidenceBindingSHA256
            )
            try drainActiveSession()
            try removeDiagnosticRoot(
                paths.rootURL,
                ownerUserID: callerUserID
            )
            let store = try LifecycleLeaseStore(
                rootURL: leaseRootURL
            )
            try store.remove(investigationID)
            replyAndFinish(
                LifecycleSupervisorXPCResponse(
                    callerAuthenticated: true,
                    freshAuditSession: true,
                    workerEvidence: evidence,
                    drained: true,
                    staleRecoveryObserved:
                        recoveredInvestigations.contains(investigationID)
                )
            )
        } catch let LifecycleHelperFailure.drainFailed(reasonKey) {
            do {
                try cancelActive()
                replyFailureAndFinish(reasonKey)
            } catch {
                exit(71)
            }
        } catch {
            do {
                try cancelActive()
                replyFailureAndFinish(
                    "runtime.lifecycle.worker-failed"
                )
            } catch {
                exit(71)
            }
        }
    }

    private func timeout(
        _ investigationID: LifecycleInvestigationID,
        paths: LifecycleLocalDiagnosticPaths
    ) {
        guard lock.withLock({
            activeInvestigationID == investigationID
        }) else {
            return
        }
        do {
            try cancelActive()
            replyAndFinish(
                LifecycleSupervisorXPCResponse(
                    callerAuthenticated: true,
                    freshAuditSession: true,
                    drained: true,
                    staleRecoveryObserved: false
                )
            )
        } catch {
            exit(71)
        }
        _ = paths
    }
#endif

    private func cancel(
        _ investigationID: LifecycleInvestigationID,
        reply: LifecycleReplyBox
    ) {
        let activeInvestigationID = lock.withLock {
            self.activeInvestigationID
        }
        if LifecycleRecoveredInvestigationPolicy().confirmsRecovery(
            investigationID,
            recovered: recoveredInvestigations,
            activeInvestigationID: activeInvestigationID
        ) {
            replyEncoded(
                LifecycleSupervisorXPCResponse(
                    callerAuthenticated: true,
                    freshAuditSession: true,
                    drained: true,
                    staleRecoveryObserved: true
                ),
                reply: reply.call
            )
            scheduleSuccessfulExitAfterReply()
            return
        }
        if recoveredInvestigations.contains(investigationID) {
            reply.call(
                nil,
                "runtime.lifecycle.another-investigation-active"
            )
            return
        }
        guard lock.withLock({
            activeInvestigationID == investigationID
        }) else {
            reply.call(
                nil,
                "runtime.lifecycle.investigation-not-active"
            )
            return
        }
        do {
            try cancelActive()
            replyEncoded(
                LifecycleSupervisorXPCResponse(
                    callerAuthenticated: true,
                    freshAuditSession: true,
                    drained: true,
                    staleRecoveryObserved: false
                ),
                reply: reply.call
            )
            scheduleSuccessfulExitAfterReply()
        } catch let LifecycleHelperFailure.drainFailed(reasonKey) {
            reply.call(nil, reasonKey)
            scheduleFailureExitAfterReply()
        } catch {
            reply.call(nil, "runtime.lifecycle.drain-failed")
            scheduleFailureExitAfterReply()
        }
    }

    private func cancelActive() throws {
        let state = lock.withLock {
            (
                activeProcess,
                activeInvestigationID,
                activeAuditSessionID,
                activeLeaseCreated,
                interactiveInput,
                interactiveOutput
            )
        }
        guard let investigationID = state.1 else { return }
        if state.2 != nil {
            try drainActiveSession()
        } else if let process = state.0, process.isRunning {
            let identity = try DarwinLifecycleInventory(
                privilegedProcessID: getpid()
            ).identity(for: process.processIdentifier)
            _ = try DarwinLifecycleSignaler().send(
                .kill,
                to: identity
            )
        }
        if let process = state.0 {
            try waitForProcessExit(
                process,
                timeoutMilliseconds: 5_000
            )
        }
        state.4?.closeFile()
        state.5?.closeFile()
        let paths = try LifecycleLocalInstallationContract()
            .diagnosticPaths(
                userID: callerUserID,
                investigationID: investigationID
            )
        if lstatExists(paths.rootURL) {
            try removeDiagnosticRoot(
                paths.rootURL,
                ownerUserID: callerUserID
            )
        }
        if state.3 {
            let store = try LifecycleLeaseStore(
                rootURL: leaseRootURL
            )
            try store.remove(investigationID)
        }
        lock.withLock {
            activeProcess = nil
            activeInvestigationID = nil
            activeEvidenceBindingSHA256 = nil
            activeAuditSessionID = nil
            activeLeaseCreated = false
            interactiveInput = nil
            interactiveOutput = nil
            interactiveExpiryWorkItem?.cancel()
            interactiveExpiryWorkItem = nil
        }
    }

    private func drainActiveSession() throws {
        guard let auditSessionID = lock.withLock({
            activeAuditSessionID
        }) else {
            throw LifecycleHelperFailure.drainFailed(
                reasonKey:
                    "runtime.lifecycle.drain.audit-session-missing"
            )
        }
        do {
            _ = try LifecycleSessionDrainer(
                inventory: DarwinLifecycleInventory(
                    expectedUserID: callerUserID,
                    privilegedProcessID: getpid()
                ),
                signaler: DarwinLifecycleSignaler()
            ).drain(
                auditSessionID: auditSessionID,
                expectedUserID: callerUserID,
                supervisorIdentity: helperIdentity
            )
        } catch let error as LifecycleDrainError {
            throw LifecycleHelperFailure.drainFailed(
                reasonKey: lifecycleDrainFailureReasonKey(error)
            )
        } catch let error as DarwinLifecycleSupportError {
            throw LifecycleHelperFailure.drainFailed(
                reasonKey: darwinLifecycleFailureReasonKey(error)
            )
        } catch {
            throw LifecycleHelperFailure.drainFailed(
                reasonKey: "runtime.lifecycle.drain.unknown"
            )
        }
    }

    private func replyAndFinish(
        _ response: LifecycleSupervisorXPCResponse
    ) {
        let reply = lock.withLock {
            let value = activeReply
            activeReply = nil
            activeProcess = nil
            activeInvestigationID = nil
            activeEvidenceBindingSHA256 = nil
            activeAuditSessionID = nil
            activeLeaseCreated = false
            return value
        }
        if let reply {
            replyEncoded(response, reply: reply)
        }
        scheduleSuccessfulExitAfterReply()
    }

    private func replyFailureAndFinish(_ reasonKey: String) {
        let reply = lock.withLock {
            let value = activeReply
            activeReply = nil
            activeProcess = nil
            activeInvestigationID = nil
            activeEvidenceBindingSHA256 = nil
            activeAuditSessionID = nil
            activeLeaseCreated = false
            return value
        }
        reply?(nil, reasonKey)
        scheduleSuccessfulExitAfterReply()
    }

    private func replyEncoded(
        _ response: LifecycleSupervisorXPCResponse,
        reply: @escaping (Data?, String?) -> Void
    ) {
        guard let data = try? JSONEncoder().encode(response) else {
            reply(nil, "runtime.lifecycle.response-failed")
            return
        }
        reply(data, nil)
    }
}

private enum LifecycleHelperInvalidationDisposition {
    case alreadyInvalidated
    case preserveRetirementServer
    case drainActive
    case exitCleanly
}

private final class LifecycleReplyBox: @unchecked Sendable {
    let call: (Data?, String?) -> Void

    init(_ call: @escaping (Data?, String?) -> Void) {
        self.call = call
    }
}

private final class LifecycleInteractivePendingReply:
    @unchecked Sendable
{
    let request: LifecycleInteractiveSessionRequest
    let reply: (Data?, String?) -> Void

    init(
        request: LifecycleInteractiveSessionRequest,
        reply: @escaping (Data?, String?) -> Void
    ) {
        self.request = request
        self.reply = reply
    }
}

private func lifecycleInteractiveReasonKey(
    _ error: LifecycleInteractiveSessionBrokerError
) -> String {
    switch error {
    case .invalidRequest:
        "runtime.lifecycle.interactive.invalid-request"
    case .sessionUnavailable:
        "runtime.lifecycle.interactive.session-unavailable"
    case .sessionMismatch:
        "runtime.lifecycle.interactive.session-mismatch"
    case .sessionExpired:
        "runtime.lifecycle.interactive.session-expired"
    case .lineLimitExceeded:
        "runtime.lifecycle.interactive.line-limit-exceeded"
    case .sessionLimitExceeded:
        "runtime.lifecycle.interactive.session-limit-exceeded"
    case .startFailed:
        "runtime.lifecycle.interactive.start-failed"
    case .writeFailed:
        "runtime.lifecycle.interactive.write-failed"
    case .readFailed:
        "runtime.lifecycle.interactive.read-failed"
    case .retireFailed:
        "runtime.lifecycle.interactive.retire-failed"
    }
}

private func sanitizeInteractiveReasonKey(_ value: String) -> String {
    let allowed = Set([
        "runtime.lifecycle.interactive.invalid-request",
        "runtime.lifecycle.interactive.session-unavailable",
        "runtime.lifecycle.interactive.session-mismatch",
        "runtime.lifecycle.interactive.session-expired",
        "runtime.lifecycle.interactive.line-limit-exceeded",
        "runtime.lifecycle.interactive.session-limit-exceeded",
        "runtime.lifecycle.interactive.start-failed",
        "runtime.lifecycle.interactive.write-failed",
        "runtime.lifecycle.interactive.read-failed",
        "runtime.lifecycle.interactive.retire-failed",
        "runtime.lifecycle.interactive.remote-rejected",
    ])
    return allowed.contains(value)
        ? value
        : "runtime.lifecycle.interactive.remote-rejected"
}

#if DEBUG
private func recoverStaleInvestigations() throws
    -> Set<LifecycleInvestigationID>
{
    let store = try LifecycleLeaseStore(rootURL: leaseRootURL)
    let planner = LifecycleLeaseRecoveryPlanner(
        currentBootSessionID: try currentLifecycleBootSessionID()
    )
    var recovered = Set<LifecycleInvestigationID>()
    for lease in try store.readAll() {
        switch planner.decision(for: lease) {
        case let .drain(auditSessionID, userID):
            _ = try LifecycleSessionDrainer(
                inventory: DarwinLifecycleInventory(
                    expectedUserID: userID
                ),
                signaler: DarwinLifecycleSignaler()
            ).drain(
                auditSessionID: auditSessionID,
                expectedUserID: userID,
                supervisorIdentity: nil,
                allowRootMembersDuringRecovery: true
            )
            recovered.insert(lease.investigationID)
        case .retireAfterReboot:
            break
        }
        if
            let paths = try? LifecycleLocalInstallationContract()
                .diagnosticPaths(
                    userID: lease.userID,
                    investigationID: lease.investigationID
                )
        {
            if lstatExists(paths.rootURL) {
                try removeDiagnosticRoot(
                    paths.rootURL,
                    ownerUserID: lease.userID
                )
            }
        }
        _ = try store.remove(lease.investigationID)
    }
    return recovered
}

private func prepareDiagnosticDirectories(
    identity: LifecycleUserIdentity,
    investigationID: LifecycleInvestigationID
) throws -> LifecycleLocalDiagnosticPaths {
    let contract = try LifecycleLocalInstallationContract()
    let paths = try contract.diagnosticPaths(
        userID: identity.userID,
        investigationID: investigationID
    )
    try prepareDirectory(
        paths.userRootURL,
        ownerUserID: 0,
        ownerGroupID: 0,
        mode: 0o711
    )
    try prepareDirectory(
        paths.rootURL,
        ownerUserID: identity.userID,
        ownerGroupID: identity.groupID,
        mode: 0o700,
        mustCreate: true
    )
    return paths
}

private func prepareRootDirectory(
    _ url: URL,
    mode: mode_t
) throws {
    try prepareDirectory(
        url,
        ownerUserID: 0,
        ownerGroupID: 0,
        mode: mode
    )
}

private func prepareDirectory(
    _ url: URL,
    ownerUserID: uid_t,
    ownerGroupID: gid_t,
    mode: mode_t,
    mustCreate: Bool = false
) throws {
    if lstatExists(url) {
        guard !mustCreate else {
            throw LifecycleHelperFailure.invalidFilesystemState
        }
        try validateDirectory(
            url,
            ownerUserID: ownerUserID,
            ownerGroupID: ownerGroupID,
            mode: mode
        )
        return
    }
    guard mkdir(url.path, mode) == 0 else {
        throw LifecycleHelperFailure.invalidFilesystemState
    }
    guard
        chown(url.path, ownerUserID, ownerGroupID) == 0,
        chmod(url.path, mode) == 0
    else {
        rmdir(url.path)
        throw LifecycleHelperFailure.invalidFilesystemState
    }
    try validateDirectory(
        url,
        ownerUserID: ownerUserID,
        ownerGroupID: ownerGroupID,
        mode: mode
    )
}

private func validateDirectory(
    _ url: URL,
    ownerUserID: uid_t,
    ownerGroupID: gid_t,
    mode: mode_t
) throws {
    var information = stat()
    guard
        lstat(url.path, &information) == 0,
        information.st_mode & S_IFMT == S_IFDIR,
        information.st_uid == ownerUserID,
        information.st_gid == ownerGroupID,
        information.st_mode & 0o777 == mode
    else {
        throw LifecycleHelperFailure.invalidFilesystemState
    }
}

private func readWorkerEvidence(
    url: URL,
    ownerUserID: uid_t,
    receipt: LifecycleWorkerEvidenceReceipt,
    expectedInvestigationID: UUID,
    expectedEvidenceBindingSHA256: String
) throws -> Data {
    let descriptor = open(
        url.path,
        O_RDONLY | O_CLOEXEC | O_NOFOLLOW
    )
    guard descriptor >= 0 else {
        throw LifecycleHelperFailure.evidenceFailed
    }
    defer { close(descriptor) }
    var information = stat()
    guard
        fstat(descriptor, &information) == 0,
        information.st_mode & S_IFMT == S_IFREG,
        information.st_uid == ownerUserID,
        information.st_mode & 0o777 == 0o600,
        information.st_nlink == 1,
        information.st_size > 0,
        information.st_size <= 1_024 * 1_024
    else {
        throw LifecycleHelperFailure.evidenceFailed
    }
    let identity = workerEvidenceIdentity(information)
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4_096)
    while true {
        let count = Darwin.read(descriptor, &buffer, buffer.count)
        if count == 0 { break }
        if count < 0 {
            if errno == EINTR { continue }
            throw LifecycleHelperFailure.evidenceFailed
        }
        guard data.count + count <= 1_024 * 1_024 else {
            throw LifecycleHelperFailure.evidenceFailed
        }
        data.append(contentsOf: buffer.prefix(count))
    }
    var finalInformation = stat()
    let decoded = try? JSONDecoder().decode(
        CapabilityRuntimeWorkerEvidence.self,
        from: data
    )
    guard
        fstat(descriptor, &finalInformation) == 0,
        receipt.matches(
            data: data,
            currentIdentity: workerEvidenceIdentity(finalInformation),
            expectedOwnerUserID: ownerUserID
        ),
        identity == workerEvidenceIdentity(finalInformation),
        decoded?.investigationID == expectedInvestigationID,
        decoded?.evidenceBindingSHA256
            == expectedEvidenceBindingSHA256
    else {
        throw LifecycleHelperFailure.evidenceFailed
    }
    return data
}

private func workerEvidenceIdentity(
    _ information: stat
) -> LifecycleWorkerEvidenceFileIdentity {
    LifecycleWorkerEvidenceFileIdentity(
        deviceID: UInt64(information.st_dev),
        inode: UInt64(information.st_ino),
        ownerUserID: information.st_uid,
        mode: information.st_mode & 0o777,
        linkCount: UInt64(information.st_nlink),
        size: information.st_size
    )
}

@discardableResult
private func writeExclusiveData(
    _ data: Data,
    to url: URL,
    ownerUserID: uid_t,
    mode: mode_t
) throws -> LifecycleWorkerEvidenceFileIdentity {
    guard geteuid() == ownerUserID else {
        throw LifecycleHelperFailure.invalidIdentity
    }
    let descriptor = open(
        url.path,
        O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
        mode
    )
    guard descriptor >= 0 else {
        throw LifecycleHelperFailure.evidenceFailed
    }
    defer { close(descriptor) }
    try writeAll(data, to: descriptor)
    var information = stat()
    guard
        fsync(descriptor) == 0,
        fstat(descriptor, &information) == 0,
        information.st_mode & S_IFMT == S_IFREG,
        information.st_uid == ownerUserID,
        information.st_mode & 0o777 == mode,
        information.st_nlink == 1,
        information.st_size == data.count
    else {
        throw LifecycleHelperFailure.evidenceFailed
    }
    return workerEvidenceIdentity(information)
}
#endif

private func removeDiagnosticRoot(
    _ url: URL,
    ownerUserID: uid_t
) throws {
    let identity = try LifecycleUserIdentity.read(userID: ownerUserID)
    var information = stat()
    guard
        lstat(url.path, &information) == 0,
        information.st_mode & S_IFMT == S_IFDIR,
        information.st_uid == ownerUserID,
        information.st_gid == identity.groupID,
        information.st_mode & 0o777 == 0o700
    else {
        throw LifecycleHelperFailure.invalidFilesystemState
    }
    do {
        try FileManager.default.removeItem(at: url)
    } catch {
        throw LifecycleHelperFailure.invalidFilesystemState
    }
}

private func scheduleSuccessfulExit() {
    DispatchQueue.global().asyncAfter(
        deadline: .now() + .milliseconds(100)
    ) {
        exit(0)
    }
}

private func scheduleSuccessfulExitAfterReply() {
    DispatchQueue.global().asyncAfter(
        deadline: .now() + .seconds(5)
    ) {
        exit(0)
    }
}

private func machineIdentityRecord(
    _ identity: LifecycleProcessIdentity
) throws -> LifecycleMachineProcessIdentityRecord {
    try LifecycleMachineProcessIdentityRecord(
        processID: identity.processID,
        processIDVersion: identity.processIDVersion,
        auditSessionID: identity.auditSessionID,
        effectiveUserID: identity.effectiveUserID,
        auditTokenWords: identity.auditToken.words
    )
}

private func scheduleFailureExitAfterReply() {
    DispatchQueue.global().asyncAfter(
        deadline: .now() + .seconds(5)
    ) {
        exit(71)
    }
}

private func lifecycleDrainFailureReasonKey(
    _ error: LifecycleDrainError
) -> String {
    switch error {
    case .unsafeAuditSession:
        "runtime.lifecycle.drain.unsafe-audit-session"
    case .identityMismatch:
        "runtime.lifecycle.drain.identity-mismatch"
    case .duplicateIdentity:
        "runtime.lifecycle.drain.duplicate-identity"
    case .memberLimitExceeded:
        "runtime.lifecycle.drain.member-limit"
    case .freezeDidNotConverge:
        "runtime.lifecycle.drain.freeze-not-converged"
    case .killDidNotConverge:
        "runtime.lifecycle.drain.kill-not-converged"
    }
}

private func darwinLifecycleFailureReasonKey(
    _ error: DarwinLifecycleSupportError
) -> String {
    switch error {
    case .privilegeRequired:
        "runtime.lifecycle.drain.privilege-required"
    case .enumerationFailed:
        "runtime.lifecycle.drain.enumeration-failed"
    case .auditSessionUnavailable:
        "runtime.lifecycle.drain.audit-session-unavailable"
    case .identityUnavailable:
        switch error {
        case let .identityUnavailable(code):
            switch code {
            case ESRCH, ENOENT:
                "runtime.lifecycle.drain.identity-vanished"
            case EPERM, EACCES:
                "runtime.lifecycle.drain.identity-permission-denied"
            case EIO:
                "runtime.lifecycle.drain.identity-io-failed"
            case EPIPE:
                "runtime.lifecycle.drain.identity-pipe-failed"
            default:
                "runtime.lifecycle.drain.identity-unavailable"
            }
        default:
            "runtime.lifecycle.drain.identity-unavailable"
        }
    case .invalidIdentity:
        "runtime.lifecycle.drain.invalid-identity"
    case .signalFailed:
        "runtime.lifecycle.drain.signal-failed"
    case .currentAuditSessionUnavailable:
        "runtime.lifecycle.drain.current-audit-session-unavailable"
    }
}

#if DEBUG
if
    CommandLine.arguments.count == 5,
    [workerMode, crashMode].contains(CommandLine.arguments[1]),
    let investigationID = UUID(
        uuidString: CommandLine.arguments[2]
    ),
    CommandLine.arguments[3].utf8.count == 64,
    CommandLine.arguments[3].utf8.allSatisfy({
        (0x30...0x39).contains($0)
            || (0x61...0x66).contains($0)
    }),
    let parsedUserID = UInt32(CommandLine.arguments[4]),
    parsedUserID > 0
{
    runWorkerMode(
        mode: CommandLine.arguments[1],
        investigationID: investigationID,
        evidenceBindingSHA256: CommandLine.arguments[3],
        userID: uid_t(parsedUserID)
    )
} else if
    CommandLine.arguments.count == 4,
    CommandLine.arguments[1] == interactiveWorkerMode,
    let investigationID = UUID(
        uuidString: CommandLine.arguments[2]
    ),
    let parsedUserID = UInt32(CommandLine.arguments[3]),
    parsedUserID > 0
{
    runInteractiveWorkerMode(
        investigationID: investigationID,
        userID: uid_t(parsedUserID)
    )
} else if
    CommandLine.arguments.count == 5,
    CommandLine.arguments[1] == networkProbeMode,
    let port = UInt16(CommandLine.arguments[2])
{
    runNetworkDenialProbe(
        port: port,
        privateAddress:
            CommandLine.arguments[3] == "-"
                ? nil
                : CommandLine.arguments[3],
        unixSocketPath: CommandLine.arguments[4]
    )
} else if CommandLine.arguments.count == 1 {
    runLifecycleHelper()
} else {
    exit(64)
}
#else
guard CommandLine.arguments.count == 1 else {
    exit(64)
}
runLifecycleHelper()
#endif
