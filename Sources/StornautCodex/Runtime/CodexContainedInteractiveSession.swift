import Darwin
import Foundation
import StornautProcessSupport

public struct CodexContainedInteractiveSessionConfiguration:
    Sendable,
    Equatable
{
    public let investigationID: UUID
    public let expectedCodexExecutableSHA256: String
    public let validBefore: Date
    public let maximumLineBytes: Int
    public let maximumSessionBytes: Int

    public init(
        investigationID: UUID,
        expectedCodexExecutableSHA256: String,
        validBefore: Date,
        maximumLineBytes: Int,
        maximumSessionBytes: Int
    ) {
        self.investigationID = investigationID
        self.expectedCodexExecutableSHA256 = expectedCodexExecutableSHA256
        self.validBefore = validBefore
        self.maximumLineBytes = maximumLineBytes
        self.maximumSessionBytes = maximumSessionBytes
    }
}

public enum CodexContainedInteractiveSessionError:
    Error,
    Sendable,
    Equatable
{
    case invalidConfiguration
    case sessionUnavailable
    case launchFailed
    case writeFailed
    case readFailed
    case lineLimitExceeded
    case sessionLimitExceeded
    case retirementFailed
}

public struct CodexContainedInteractiveStartObservation:
    Sendable,
    Equatable
{
    public let codexExecutableSHA256: String

    fileprivate init(codexExecutableSHA256: String) {
        self.codexExecutableSHA256 = codexExecutableSHA256
    }
}

public struct CodexContainedInteractiveOwnerRetirementObservation:
    Sendable,
    Equatable
{
    public enum ResourceOwnership: Sendable, Equatable {
        case none
        case preparedWorkspace
        case owned
    }

    public let resourceOwnership: ResourceOwnership
    public let processGroupTerminated: Bool
    public let standardErrorContained: Bool
    public let workspaceRemoved: Bool

    fileprivate init(
        resourceOwnership: ResourceOwnership,
        processGroupTerminated: Bool,
        standardErrorContained: Bool,
        workspaceRemoved: Bool
    ) {
        self.resourceOwnership = resourceOwnership
        self.processGroupTerminated = processGroupTerminated
        self.standardErrorContained = standardErrorContained
        self.workspaceRemoved = workspaceRemoved
    }

    static let noOwnedResources = Self(
        resourceOwnership: .none,
        processGroupTerminated: false,
        standardErrorContained: false,
        workspaceRemoved: false
    )

    static let retiredOwnedResources = Self(
        resourceOwnership: .owned,
        processGroupTerminated: true,
        standardErrorContained: true,
        workspaceRemoved: true
    )

    static let retiredPreparedWorkspace = Self(
        resourceOwnership: .preparedWorkspace,
        processGroupTerminated: false,
        standardErrorContained: false,
        workspaceRemoved: true
    )
}

struct CodexContainedInteractiveLaunchPlan: Sendable {
    let executableURL: URL
    let nativeIdentityLease: CodexNativeExecutableIdentityLease
    let arguments: [String]
    let environment: CodexRuntimeEnvironment
    let currentDirectoryURL: URL
    let workspace: CodexRuntimeWorkspace
    let projectedAuthSourceURL: URL
    let containmentConfiguration: CodexContainmentConfiguration

    init(
        executableURL: URL,
        nativeIdentityLease: CodexNativeExecutableIdentityLease,
        arguments: [String],
        environment: CodexRuntimeEnvironment,
        currentDirectoryURL: URL,
        workspace: CodexRuntimeWorkspace,
        projectedAuthSourceURL: URL,
        containmentConfiguration: CodexContainmentConfiguration
    ) {
        self.executableURL = executableURL
        self.nativeIdentityLease = nativeIdentityLease
        self.arguments = arguments
        self.environment = environment
        self.currentDirectoryURL = currentDirectoryURL
        self.workspace = workspace
        self.projectedAuthSourceURL = projectedAuthSourceURL
        self.containmentConfiguration = containmentConfiguration
    }
}

struct CodexContainedInteractiveNativeLaunchReceipt: Sendable {
    let process: SpawnedDiagnosticProcess
    let codexExecutableSHA256: String
    let nativeIdentityLease: CodexNativeExecutableIdentityLease
}

struct CodexContainedInteractiveNativeLeaseSnapshot: Sendable, Equatable {
    let path: String
    let device: UInt64
    let inode: UInt64
    let generation: UInt32
    let size: Int64
}

final class CodexContainedInteractiveLaunchGate: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var resumed = false

    func cancel() {
        lock.withLock {
            if !resumed { cancelled = true }
        }
    }

    func resume(_ processID: pid_t, before deadline: DispatchTime) throws {
        try lock.withLock {
            guard
                !cancelled,
                !Task.isCancelled,
                DispatchTime.now().uptimeNanoseconds
                    < deadline.uptimeNanoseconds,
                kill(processID, SIGCONT) == 0
            else {
                throw CodexContainedInteractiveSessionError.launchFailed
            }
            resumed = true
        }
    }
}

struct CodexContainedInteractiveMappedImageIdentity: Sendable, Equatable {
    let path: String
    let device: UInt64
    let inode: UInt64
    let generation: UInt32
    let size: Int64
}

enum CodexContainedInteractiveNativeLaunchPhase: Sendable, Equatable {
    case beforeSpawn
    case afterSpawn(pid_t)
    case afterInitialStop(pid_t)
    case afterImageObservation(pid_t)
    case beforeFinalLeaseRevalidation(pid_t)
    case beforeResume(pid_t)
}

struct CodexContainedInteractiveNativeLauncher: Sendable {
    let observationHook:
        @Sendable (CodexContainedInteractiveNativeLaunchPhase) throws -> Void

    init(
        observationHook: @escaping @Sendable (
            CodexContainedInteractiveNativeLaunchPhase
        ) throws -> Void = { _ in }
    ) {
        self.observationHook = observationHook
    }

    func launch(
        plan: CodexContainedInteractiveLaunchPlan,
        deadline: DispatchTime,
        gate: CodexContainedInteractiveLaunchGate = .init()
    ) throws -> CodexContainedInteractiveNativeLaunchReceipt {
        let lease = plan.nativeIdentityLease
        try Task.checkCancellation()
        guard plan.executableURL == lease.canonicalURL else {
            throw CodexContainedInteractiveSessionError.launchFailed
        }
        try lease.revalidate()

        var ownedDescriptors = Set<Int32>()
        var childPID: pid_t = 0
        var transferred = false
        defer {
            if childPID > 0, !transferred {
                killAndExactlyReap(childPID)
            }
            for descriptor in ownedDescriptors {
                Darwin.close(descriptor)
            }
        }

        let stdinPipe = try makePipe()
        ownedDescriptors.formUnion([stdinPipe.read, stdinPipe.write])
        let stdoutPipe = try makePipe()
        ownedDescriptors.formUnion([stdoutPipe.read, stdoutPipe.write])
        let stderrPipe = try makePipe()
        ownedDescriptors.formUnion([stderrPipe.read, stderrPipe.write])

        var fileActions: posix_spawn_file_actions_t?
        guard posix_spawn_file_actions_init(&fileActions) == 0 else {
            throw CodexContainedInteractiveSessionError.launchFailed
        }
        defer { posix_spawn_file_actions_destroy(&fileActions) }
        try addDup(stdinPipe.read, to: STDIN_FILENO, actions: &fileActions)
        try addDup(stdoutPipe.write, to: STDOUT_FILENO, actions: &fileActions)
        try addDup(stderrPipe.write, to: STDERR_FILENO, actions: &fileActions)
        for descriptor in ownedDescriptors {
            try addClose(descriptor, actions: &fileActions)
        }
        guard plan.currentDirectoryURL.path.withCString({
            posix_spawn_file_actions_addchdir(&fileActions, $0)
        }) == 0 else {
            throw CodexContainedInteractiveSessionError.launchFailed
        }

        var attributes: posix_spawnattr_t?
        guard posix_spawnattr_init(&attributes) == 0 else {
            throw CodexContainedInteractiveSessionError.launchFailed
        }
        defer { posix_spawnattr_destroy(&attributes) }
        let flags = Int16(
            POSIX_SPAWN_START_SUSPENDED
                | POSIX_SPAWN_SETPGROUP
                | POSIX_SPAWN_CLOEXEC_DEFAULT
        )
        guard
            posix_spawnattr_setflags(&attributes, flags) == 0,
            posix_spawnattr_setpgroup(&attributes, 0) == 0
        else {
            throw CodexContainedInteractiveSessionError.launchFailed
        }

        let argv = [plan.executableURL.path] + plan.arguments
        let envp = plan.environment.values
            .map { "\($0.key)=\($0.value)" }.sorted()
        try observationHook(.beforeSpawn)
        let spawnResult = try withCStringArray(argv) { arguments in
            try withCStringArray(envp) { environment in
                plan.executableURL.path.withCString { executable in
                    posix_spawn(
                        &childPID, executable, &fileActions, &attributes,
                        arguments, environment
                    )
                }
            }
        }
        guard spawnResult == 0, childPID > 0 else {
            childPID = 0
            throw CodexContainedInteractiveSessionError.launchFailed
        }
        try observationHook(.afterSpawn(childPID))
        try Task.checkCancellation()

        closeOwned(stdinPipe.read, descriptors: &ownedDescriptors)
        closeOwned(stdoutPipe.write, descriptors: &ownedDescriptors)
        closeOwned(stderrPipe.write, descriptors: &ownedDescriptors)
        try waitForInitialStop(childPID, deadline: deadline)
        try observationHook(.afterInitialStop(childPID))
        try requireLoadedMainImage(childPID, lease: lease)
        try observationHook(.beforeFinalLeaseRevalidation(childPID))
        try Task.checkCancellation()
        try lease.revalidate()
        guard
            getpgid(childPID) == childPID,
            childPID != getpgrp(),
            fcntl(stdinPipe.write, F_SETNOSIGPIPE, 1) == 0
        else {
            throw CodexContainedInteractiveSessionError.launchFailed
        }
        try observationHook(.beforeResume(childPID))
        try gate.resume(childPID, before: deadline)

        let process = SpawnedDiagnosticProcess(
            pid: childPID,
            processGroup: ProcessGroupID(rawValue: childPID),
            standardInput: stdinPipe.write,
            standardOutput: stdoutPipe.read,
            standardError: stderrPipe.read
        )
        ownedDescriptors.subtract([
            stdinPipe.write, stdoutPipe.read, stderrPipe.read,
        ])
        transferred = true
        return CodexContainedInteractiveNativeLaunchReceipt(
            process: process,
            codexExecutableSHA256: lease.sha256,
            nativeIdentityLease: lease
        )
    }

    private func waitForInitialStop(
        _ processID: pid_t,
        deadline: DispatchTime
    ) throws {
        while DispatchTime.now().uptimeNanoseconds
            < deadline.uptimeNanoseconds
        {
            var initialStopStatus: Int32 = 0
            let result = waitpid(
                processID, &initialStopStatus, WUNTRACED | WNOHANG
            )
            if result == processID {
                guard Self.initialStopIsAccepted(
                    result: result,
                    initialStopStatus: initialStopStatus,
                    expectedProcessID: processID
                ) else {
                    throw CodexContainedInteractiveSessionError.launchFailed
                }
                return
            }
            if result < 0, errno != EINTR {
                throw CodexContainedInteractiveSessionError.launchFailed
            }
            try Task.checkCancellation()
            usleep(5_000)
        }
        throw CodexContainedInteractiveSessionError.launchFailed
    }

    static func initialStopIsAccepted(
        result: pid_t, initialStopStatus: Int32, expectedProcessID: pid_t
    ) -> Bool {
        result == expectedProcessID && initialStopStatus == 0x7f
    }

    private func requireLoadedMainImage(
        _ processID: pid_t,
        lease: CodexNativeExecutableIdentityLease
    ) throws {
        var address: UInt64 = 0
        var images: [CodexContainedInteractiveMappedImageIdentity] = []
        var inspectedRegionCount = 0
        while inspectedRegionCount < 4_096 {
            errno = 0
            var information = proc_regionwithpathinfo()
            let byteCount = proc_pidinfo(
                processID, PROC_PIDREGIONPATHINFO, address, &information,
                Int32(MemoryLayout<proc_regionwithpathinfo>.size)
            )
            if byteCount == 0, !images.isEmpty { break }
            guard
                byteCount == MemoryLayout<proc_regionwithpathinfo>.size,
                let observed = mappedIdentity(information)
            else {
                throw CodexContainedInteractiveSessionError.launchFailed
            }
            images.append(observed)
            let next = information.prp_prinfo.pri_address
                .addingReportingOverflow(information.prp_prinfo.pri_size)
            guard
                information.prp_prinfo.pri_size > 0,
                !next.overflow, next.partialValue > address
            else {
                throw CodexContainedInteractiveSessionError.launchFailed
            }
            address = next.partialValue
            inspectedRegionCount += 1
        }
        try observationHook(.afterImageObservation(processID))
        guard
            inspectedRegionCount < 4_096,
            mappedImagesMatchLease(
                images,
                expected: Self.snapshot(lease)
            )
        else {
            throw CodexContainedInteractiveSessionError.launchFailed
        }
    }

    func mappedImagesMatchLease(
        _ images: [CodexContainedInteractiveMappedImageIdentity],
        expected: CodexContainedInteractiveNativeLeaseSnapshot
    ) -> Bool {
        guard
            let first = images.first,
            matches(first, expected: expected)
        else {
            return false
        }
        return !images.dropFirst().contains {
            $0.path == expected.path && !matches($0, expected: expected)
        }
    }

    private func mappedIdentity(
        _ value: proc_regionwithpathinfo
    ) -> CodexContainedInteractiveMappedImageIdentity? {
        var pathStorage = value.prp_vip.vip_path
        let pathBytes = withUnsafeBytes(of: &pathStorage) { Array($0) }
        guard
            let terminator = pathBytes.firstIndex(of: 0),
            let path = String(
                bytes: pathBytes[..<terminator], encoding: .utf8
            ),
            path.utf8.count == terminator
        else {
            return nil
        }
        let node = value.prp_vip.vip_vi.vi_stat
        return CodexContainedInteractiveMappedImageIdentity(
            path: path,
            device: UInt64(node.vst_dev),
            inode: UInt64(node.vst_ino),
            generation: node.vst_gen,
            size: Int64(node.vst_size)
        )
    }

    private func matches(
        _ observed: CodexContainedInteractiveMappedImageIdentity,
        expected: CodexContainedInteractiveNativeLeaseSnapshot
    ) -> Bool {
        observed.path == expected.path
            && observed.device == expected.device
            && observed.inode == expected.inode
            && observed.generation == expected.generation
            && observed.size == expected.size
    }

    private static func snapshot(
        _ lease: CodexNativeExecutableIdentityLease
    ) -> CodexContainedInteractiveNativeLeaseSnapshot {
        CodexContainedInteractiveNativeLeaseSnapshot(
            path: lease.canonicalURL.path,
            device: lease.device,
            inode: lease.inode,
            generation: lease.generation,
            size: lease.size
        )
    }

    private func killAndExactlyReap(_ processID: pid_t) {
        kill(-processID, SIGKILL)
        kill(processID, SIGKILL)
        var status: Int32 = 0
        while waitpid(processID, &status, 0) < 0 {
            if errno == EINTR { continue }
            break
        }
    }

    private func makePipe() throws -> (read: Int32, write: Int32) {
        var descriptors = [Int32](repeating: -1, count: 2)
        guard pipe(&descriptors) == 0 else {
            throw CodexContainedInteractiveSessionError.launchFailed
        }
        var result = (read: descriptors[0], write: descriptors[1])
        do {
            result.read = try descriptorAboveStandardIO(result.read)
            result.write = try descriptorAboveStandardIO(result.write)
            return result
        } catch {
            Darwin.close(result.read)
            Darwin.close(result.write)
            throw error
        }
    }

    private func descriptorAboveStandardIO(_ descriptor: Int32) throws
        -> Int32
    {
        if descriptor > STDERR_FILENO {
            guard fcntl(descriptor, F_SETFD, FD_CLOEXEC) == 0 else {
                throw CodexContainedInteractiveSessionError.launchFailed
            }
            return descriptor
        }
        let moved = fcntl(
            descriptor, F_DUPFD_CLOEXEC, STDERR_FILENO + 1
        )
        guard moved >= 0 else {
            throw CodexContainedInteractiveSessionError.launchFailed
        }
        Darwin.close(descriptor)
        return moved
    }

    private func addDup(
        _ descriptor: Int32,
        to target: Int32,
        actions: inout posix_spawn_file_actions_t?
    ) throws {
        guard posix_spawn_file_actions_adddup2(
            &actions, descriptor, target
        ) == 0 else {
            throw CodexContainedInteractiveSessionError.launchFailed
        }
    }

    private func addClose(
        _ descriptor: Int32,
        actions: inout posix_spawn_file_actions_t?
    ) throws {
        guard posix_spawn_file_actions_addclose(
            &actions, descriptor
        ) == 0 else {
            throw CodexContainedInteractiveSessionError.launchFailed
        }
    }

    private func closeOwned(
        _ descriptor: Int32,
        descriptors: inout Set<Int32>
    ) {
        guard descriptors.remove(descriptor) != nil else { return }
        Darwin.close(descriptor)
    }

    private func withCStringArray<Result>(
        _ strings: [String],
        body: (
            UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
        ) throws -> Result
    ) throws -> Result {
        guard strings.allSatisfy({ !$0.utf8.contains(0) }) else {
            throw CodexContainedInteractiveSessionError.launchFailed
        }
        var storage: [UnsafeMutablePointer<CChar>?] = []
        defer { storage.forEach { free($0) } }
        for string in strings {
            guard let pointer = strdup(string) else {
                throw CodexContainedInteractiveSessionError.launchFailed
            }
            storage.append(pointer)
        }
        storage.append(nil)
        return try storage.withUnsafeMutableBufferPointer { buffer in
            try body(buffer.baseAddress!)
        }
    }
}

public actor CodexContainedInteractiveSession {
    typealias PlanBuilder = @Sendable (
        CodexContainedInteractiveSessionConfiguration
    ) async throws -> CodexContainedInteractiveLaunchPlan
    typealias NativeLauncher = @Sendable (
        CodexContainedInteractiveLaunchPlan,
        DispatchTime,
        CodexContainedInteractiveLaunchGate
    ) throws -> CodexContainedInteractiveNativeLaunchReceipt

    private enum State {
        case ready
        case starting
        case active
        case failed
        case retiring
        case retired
    }

    private enum PrelaunchRetirementOutcome {
        case absent
        case observed(
            CodexContainedInteractiveOwnerRetirementObservation
        )
        case failed
    }

    private static let maximumAllowedLineBytes = 2 * 1_024 * 1_024
    private static let maximumAllowedSessionBytes = 16 * 1_024 * 1_024

    private let now: @Sendable () -> Date
    private let planBuilder: PlanBuilder
    private let nativeLauncher: NativeLauncher
    private var state = State.ready
    private var configuration:
        CodexContainedInteractiveSessionConfiguration?
    private var resources: CodexContainedInteractiveResources?
    private var startingTask: Task<
        CodexContainedInteractiveLaunchPlan,
        any Error
    >?
    private var nativeLaunchTask: Task<
        CodexContainedInteractiveNativeLaunchReceipt,
        any Error
    >?
    private var nativeLaunchGate: CodexContainedInteractiveLaunchGate?
    private var pendingLaunchPlan: CodexContainedInteractiveLaunchPlan?
    private var prelaunchRetirementOutcome =
        PrelaunchRetirementOutcome.absent
    private var transferredBytes = 0
    private var operationInProgress = false
    private var retirementTask: Task<
        CodexContainedInteractiveOwnerRetirementObservation?,
        Never
    >?
    private var retirementObservation:
        CodexContainedInteractiveOwnerRetirementObservation?

    public init() {
        now = Date.init
        planBuilder = {
            try await CodexContainedInteractivePlanBuilder().build($0)
        }
        nativeLauncher = { plan, deadline, gate in
            try CodexContainedInteractiveNativeLauncher().launch(
                plan: plan,
                deadline: deadline,
                gate: gate
            )
        }
    }

    init(
        now: @escaping @Sendable () -> Date = Date.init,
        planBuilder: @escaping PlanBuilder,
        nativeLauncher: @escaping NativeLauncher
    ) {
        self.now = now
        self.planBuilder = planBuilder
        self.nativeLauncher = nativeLauncher
    }

    @discardableResult
    public func start(
        _ configuration: CodexContainedInteractiveSessionConfiguration
    ) async throws -> CodexContainedInteractiveStartObservation {
        guard
            state == .ready,
            self.configuration == nil,
            valid(configuration, at: now())
        else {
            throw CodexContainedInteractiveSessionError
                .invalidConfiguration
        }
        self.configuration = configuration
        state = .starting

        let task = Task {
            try await planBuilder(configuration)
        }
        startingTask = task
        let result = await withTaskCancellationHandler {
            await task.result
        } onCancel: {
            task.cancel()
        }
        let plan: CodexContainedInteractiveLaunchPlan
        switch result {
        case let .success(value):
            plan = value
        case .failure:
            if state == .starting {
                startingTask = nil
                prelaunchRetirementOutcome = .failed
                state = .failed
                throw CodexContainedInteractiveSessionError.launchFailed
            }
            throw CodexContainedInteractiveSessionError
                .sessionUnavailable
        }
        guard state == .starting else {
            throw CodexContainedInteractiveSessionError
                .sessionUnavailable
        }
        startingTask = nil
        guard valid(configuration, at: now()) else {
            recordPreparedWorkspaceRetirement(plan)
            state = .failed
            throw CodexContainedInteractiveSessionError
                .invalidConfiguration
        }
        guard valid(
            plan,
            expectedCodexExecutableSHA256:
                configuration.expectedCodexExecutableSHA256
        ) else {
            recordPreparedWorkspaceRetirement(plan)
            state = .failed
            throw CodexContainedInteractiveSessionError.launchFailed
        }

        let launchGate = CodexContainedInteractiveLaunchGate()
        nativeLaunchGate = launchGate
        let launchDeadline: DispatchTime
        do {
            try Task.checkCancellation()
            launchDeadline = try operationDeadline(configuration)
        } catch {
            launchGate.cancel()
            nativeLaunchGate = nil
            recordPreparedWorkspaceRetirement(plan)
            state = .failed
            throw Task.isCancelled
                ? CodexContainedInteractiveSessionError.sessionUnavailable
                : error
        }
        let nativeLauncher = self.nativeLauncher
        pendingLaunchPlan = plan
        let launchResult = await withTaskCancellationHandler {
            if Task.isCancelled {
                launchGate.cancel()
            }
            let launchTask = Task.detached(priority: .utility) {
                try nativeLauncher(plan, launchDeadline, launchGate)
            }
            nativeLaunchTask = launchTask
            return await launchTask.result
        } onCancel: {
            launchGate.cancel()
        }
        let launchReceipt: CodexContainedInteractiveNativeLaunchReceipt
        switch launchResult {
        case let .success(value):
            launchReceipt = value
        case .failure:
            if state == .starting {
                nativeLaunchTask = nil
                nativeLaunchGate = nil
                pendingLaunchPlan = nil
                recordPreparedWorkspaceRetirement(plan)
                state = .failed
                throw CodexContainedInteractiveSessionError.launchFailed
            }
            throw CodexContainedInteractiveSessionError.sessionUnavailable
        }
        guard state == .starting else {
            throw CodexContainedInteractiveSessionError.sessionUnavailable
        }
        nativeLaunchTask = nil
        nativeLaunchGate = nil
        pendingLaunchPlan = nil
        if Task.isCancelled || !valid(configuration, at: now()) {
            if
                let cleanup = try? CodexContainedInteractiveResources(
                    plan: plan,
                    launchReceipt: launchReceipt,
                    maximumLineBytes: configuration.maximumLineBytes,
                    maximumSessionBytes: configuration.maximumSessionBytes
                ),
                let observation = cleanup.retire()
            {
                prelaunchRetirementOutcome = .observed(observation)
            } else {
                prelaunchRetirementOutcome = .failed
                try? plan.workspace.remove()
            }
            state = .failed
            throw Task.isCancelled
                ? CodexContainedInteractiveSessionError.sessionUnavailable
                : CodexContainedInteractiveSessionError.invalidConfiguration
        }
        do {
            resources = try CodexContainedInteractiveResources(
                plan: plan,
                launchReceipt: launchReceipt,
                maximumLineBytes: configuration.maximumLineBytes,
                maximumSessionBytes: configuration.maximumSessionBytes
            )
        } catch {
            prelaunchRetirementOutcome = .failed
            state = .failed
            try? plan.workspace.remove()
            throw CodexContainedInteractiveSessionError.launchFailed
        }
        state = .active
        return CodexContainedInteractiveStartObservation(
            codexExecutableSHA256: resources!.codexExecutableSHA256
        )
    }

    public func writeLine(_ line: Data) async throws {
        let admitted = try admitOperation()
        defer { operationInProgress = false }
        do {
            try account(line, configuration: admitted.configuration)
            let deadline = try operationDeadline(admitted.configuration)
            try await Task.detached(priority: .utility) {
                try admitted.resources.writer.write(
                    line,
                    deadline: deadline,
                    cancellation: admitted.resources.cancellation
                )
            }.value
            try acceptOperation(admitted.configuration)
        } catch let error as CodexContainedInteractiveSessionError {
            failUnlessRetiring()
            throw error
        } catch {
            let wasRetiring = state == .retiring || state == .retired
            failUnlessRetiring()
            throw wasRetiring
                ? CodexContainedInteractiveSessionError.sessionUnavailable
                : CodexContainedInteractiveSessionError.writeFailed
        }
    }

    public func readLine() async throws -> Data {
        let admitted = try admitOperation()
        defer { operationInProgress = false }
        do {
            let deadline = try operationDeadline(admitted.configuration)
            let line = try await Task.detached(priority: .utility) {
                try admitted.resources.reader.nextLine(
                    deadline: deadline,
                    cancellation: admitted.resources.cancellation
                )
            }.value
            try account(line, configuration: admitted.configuration)
            try acceptOperation(admitted.configuration)
            return line
        } catch let error as BoundedAppServerLineReader.Error {
            failUnlessRetiring()
            switch error {
            case .lineLimitExceeded:
                throw CodexContainedInteractiveSessionError
                    .lineLimitExceeded
            case .sessionLimitExceeded:
                throw CodexContainedInteractiveSessionError
                    .sessionLimitExceeded
            case .cancelled:
                throw CodexContainedInteractiveSessionError
                    .sessionUnavailable
            case .timedOut, .readFailed, .unexpectedEOF:
                throw CodexContainedInteractiveSessionError.readFailed
            }
        } catch let error as CodexContainedInteractiveSessionError {
            failUnlessRetiring()
            throw error
        } catch {
            failUnlessRetiring()
            throw CodexContainedInteractiveSessionError.readFailed
        }
    }

    public func retire() async throws
        -> CodexContainedInteractiveOwnerRetirementObservation
    {
        if state == .retired, let retirementObservation {
            return retirementObservation
        }
        if let retirementTask {
            guard let observation = await retirementTask.value else {
                throw CodexContainedInteractiveSessionError
                    .retirementFailed
            }
            return observation
        }
        if state == .starting {
            if
                let nativeLaunchTask,
                let pendingLaunchPlan,
                let configuration
            {
                nativeLaunchGate?.cancel()
                state = .retiring
                nativeLaunchTask.cancel()
                let task = Task<
                    CodexContainedInteractiveOwnerRetirementObservation?,
                    Never
                > {
                    switch await nativeLaunchTask.result {
                    case let .success(receipt):
                        do {
                            let resources = try
                                CodexContainedInteractiveResources(
                                    plan: pendingLaunchPlan,
                                    launchReceipt: receipt,
                                    maximumLineBytes:
                                        configuration.maximumLineBytes,
                                    maximumSessionBytes:
                                        configuration.maximumSessionBytes
                                )
                            return resources.retire()
                        } catch {
                            try? pendingLaunchPlan.workspace.remove()
                            return nil
                        }
                    case .failure:
                        do {
                            try pendingLaunchPlan.workspace.remove()
                            return .retiredPreparedWorkspace
                        } catch {
                            return nil
                        }
                    }
                }
                retirementTask = task
                return try await acceptRetirementTask(task)
            }
            guard let startingTask else {
                state = .failed
                throw CodexContainedInteractiveSessionError
                    .retirementFailed
            }
            state = .retiring
            let task = Task<
                CodexContainedInteractiveOwnerRetirementObservation?,
                Never
            > {
                switch await startingTask.result {
                case let .success(plan):
                    do {
                        try plan.workspace.remove()
                        return .retiredPreparedWorkspace
                    } catch {
                        return nil
                    }
                case .failure:
                    return nil
                }
            }
            retirementTask = task
            return try await acceptRetirementTask(task)
        }
        if resources == nil {
            switch prelaunchRetirementOutcome {
            case .absent where state == .ready:
                let observation =
                    CodexContainedInteractiveOwnerRetirementObservation
                        .noOwnedResources
                retirementObservation = observation
                state = .retired
                return observation
            case let .observed(observation):
                retirementObservation = observation
                state = .retired
                return observation
            case .absent, .failed:
                throw CodexContainedInteractiveSessionError
                    .retirementFailed
            }
        }
        state = .retiring
        guard let resources else {
            throw CodexContainedInteractiveSessionError.retirementFailed
        }
        resources.cancellation.cancel()
        let task = Task<
            CodexContainedInteractiveOwnerRetirementObservation?,
            Never
        > {
            while operationInProgress {
                await Task.yield()
            }
            return await Task.detached(priority: .utility) {
                resources.retire()
            }.value
        }
        retirementTask = task
        return try await acceptRetirementTask(task)
    }

    private func acceptRetirementTask(
        _ task: Task<
            CodexContainedInteractiveOwnerRetirementObservation?,
            Never
        >
    ) async throws
        -> CodexContainedInteractiveOwnerRetirementObservation
    {
        let observation = await task.value
        startingTask = nil
        nativeLaunchTask = nil
        nativeLaunchGate = nil
        pendingLaunchPlan = nil
        self.resources = nil
        retirementObservation = observation
        state = observation == nil ? .failed : .retired
        guard let observation else {
            throw CodexContainedInteractiveSessionError.retirementFailed
        }
        return observation
    }

    private func recordPreparedWorkspaceRetirement(
        _ plan: CodexContainedInteractiveLaunchPlan
    ) {
        var information = stat()
        if lstat(plan.workspace.paths.rootURL.path, &information) != 0,
           errno == ENOENT
        {
            prelaunchRetirementOutcome = .observed(
                .retiredPreparedWorkspace
            )
            return
        }
        do {
            try plan.workspace.remove()
            prelaunchRetirementOutcome = .observed(
                .retiredPreparedWorkspace
            )
        } catch {
            prelaunchRetirementOutcome = .failed
        }
    }

    private func valid(
        _ configuration: CodexContainedInteractiveSessionConfiguration,
        at current: Date
    ) -> Bool {
        configuration.validBefore.timeIntervalSince1970.isFinite
            && configuration.expectedCodexExecutableSHA256.count == 64
            && configuration.expectedCodexExecutableSHA256.unicodeScalars
                .allSatisfy {
                    (0x30...0x39).contains($0.value)
                        || (0x61...0x66).contains($0.value)
                }
            && current.timeIntervalSince1970.isFinite
            && configuration.validBefore > current
            && configuration.validBefore.timeIntervalSince(current) <= 900
            && (1...Self.maximumAllowedLineBytes).contains(
                configuration.maximumLineBytes
            )
            && configuration.maximumSessionBytes
                >= configuration.maximumLineBytes
            && configuration.maximumSessionBytes
                <= Self.maximumAllowedSessionBytes
    }

    private func valid(
        _ plan: CodexContainedInteractiveLaunchPlan,
        expectedCodexExecutableSHA256: String
    ) -> Bool {
        do {
            try plan.nativeIdentityLease.revalidate()
        } catch {
            return false
        }
        guard
            plan.nativeIdentityLease.sha256
                == expectedCodexExecutableSHA256,
            plan.executableURL == plan.nativeIdentityLease.canonicalURL,
            plan.executableURL.isFileURL,
            plan.executableURL.path.hasPrefix("/"),
            plan.executableURL.standardizedFileURL.path
                == plan.executableURL.path,
            plan.executableURL.resolvingSymlinksInPath()
                .standardizedFileURL.path == plan.executableURL.path,
            FileManager.default.isExecutableFile(
                atPath: plan.executableURL.path
            ),
            plan.currentDirectoryURL.standardizedFileURL
                == plan.workspace.paths.workURL.standardizedFileURL,
            plan.environment.values["CODEX_HOME"]
                == plan.workspace.paths.runtimeURL.path,
            plan.environment.values["HOME"]
                == plan.workspace.paths.homeURL.path,
            plan.environment.values["TMPDIR"]
                == plan.workspace.paths.runtimeURL.appending(
                    path: "tmp",
                    directoryHint: .isDirectory
                ).path,
            Set(plan.environment.values.keys).isSubset(
                of: CodexRuntimeEnvironment.allowedKeys
            ),
            plan.environment.values.values.allSatisfy({
                !$0.isEmpty
                    && $0.unicodeScalars.allSatisfy {
                        $0.value >= 0x20 && $0.value != 0x7F
                    }
            }),
            let expectedConfiguration = try? CodexContainmentPolicy()
                .configuration(
                    workspace: plan.workspace.paths,
                    projectedAuthSourceURL:
                        plan.projectedAuthSourceURL
                ),
            expectedConfiguration == plan.containmentConfiguration,
            (try? CodexContainmentPolicy().validateInstalled(
                plan.containmentConfiguration,
                in: plan.workspace.paths
            )) != nil,
            let expectedArguments = try? CodexContainmentPolicy()
                .launchArguments(
                    codexExecutableURL: plan.executableURL,
                    workspace: plan.workspace.paths
                ),
            plan.arguments == expectedArguments
        else {
            return false
        }
        var executableInformation = stat()
        guard
            lstat(
                plan.executableURL.path,
                &executableInformation
            ) == 0,
            executableInformation.st_mode & S_IFMT == S_IFREG
        else {
            return false
        }
        return plan.workspace.paths.directories.allSatisfy {
            var information = stat()
            return lstat($0.path, &information) == 0
                && information.st_mode & S_IFMT == S_IFDIR
                && information.st_uid == geteuid()
                && information.st_mode & 0o777 == 0o700
        }
    }

    private func admitOperation() throws -> (
        configuration: CodexContainedInteractiveSessionConfiguration,
        resources: CodexContainedInteractiveResources
    ) {
        guard
            state == .active,
            !operationInProgress,
            let configuration,
            let resources
        else {
            throw CodexContainedInteractiveSessionError
                .sessionUnavailable
        }
        guard valid(configuration, at: now()) else {
            state = .failed
            throw CodexContainedInteractiveSessionError
                .invalidConfiguration
        }
        operationInProgress = true
        return (configuration, resources)
    }

    private func acceptOperation(
        _ admitted: CodexContainedInteractiveSessionConfiguration
    ) throws {
        guard
            state == .active,
            configuration == admitted
        else {
            throw CodexContainedInteractiveSessionError
                .sessionUnavailable
        }
        guard valid(admitted, at: now()) else {
            state = .failed
            throw CodexContainedInteractiveSessionError
                .invalidConfiguration
        }
    }

    private func account(
        _ line: Data,
        configuration: CodexContainedInteractiveSessionConfiguration
    ) throws {
        guard
            !line.isEmpty,
            line.count <= configuration.maximumLineBytes,
            line.last == 0x0A,
            !line.dropLast().contains(0x00)
        else {
            throw CodexContainedInteractiveSessionError
                .lineLimitExceeded
        }
        let next = transferredBytes.addingReportingOverflow(line.count)
        guard
            !next.overflow,
            next.partialValue <= configuration.maximumSessionBytes
        else {
            throw CodexContainedInteractiveSessionError
                .sessionLimitExceeded
        }
        transferredBytes = next.partialValue
    }

    private func operationDeadline(
        _ configuration: CodexContainedInteractiveSessionConfiguration
    ) throws -> DispatchTime {
        let seconds = configuration.validBefore.timeIntervalSince(now())
        guard seconds > 0, seconds.isFinite else {
            throw CodexContainedInteractiveSessionError
                .invalidConfiguration
        }
        return .now() + .nanoseconds(
            Int(
                clamping: Int64(
                    min(
                        seconds * 1_000_000_000,
                        Double(Int64.max)
                    )
                )
            )
        )
    }

    private func failUnlessRetiring() {
        if state != .retiring, state != .retired {
            state = .failed
        }
    }
}

private struct CodexContainedInteractivePlanBuilder: Sendable {
    func build(
        _ configuration: CodexContainedInteractiveSessionConfiguration
    ) async throws -> CodexContainedInteractiveLaunchPlan {
        let identity = try CodexContainedInteractiveWorkerIdentity.current()
        let runRoot = try fixedRunRoot(
            identity: identity,
            investigationID: configuration.investigationID
        )
        let authSourceURL = identity.homeURL.appending(
            path: ".codex/auth.json"
        )
        let environment = closedEnvironment(identity: identity)
        guard
            let installation = await CodexLocator().locate(
                configuredURL: nil,
                environment: environment
            ).installation
        else {
            throw CodexContainedInteractiveSessionError.launchFailed
        }
        let nativeIdentityLease = try CodexNativeExecutableIdentitySource()
            .resolve(
                installation: installation,
                expectedUserID: identity.userID
            )
        guard nativeIdentityLease.sha256
                == configuration.expectedCodexExecutableSHA256
        else {
            throw CodexContainedInteractiveSessionError.launchFailed
        }
        let workspace = try CodexRuntimeWorkspace.create(
            under: runRoot,
            forbiddenRoots: [
                identity.homeURL,
                authSourceURL.deletingLastPathComponent(),
            ]
        )
        do {
            let policy = CodexContainmentPolicy()
            let containment = try policy.configuration(
                workspace: workspace.paths,
                projectedAuthSourceURL: authSourceURL
            )
            _ = try policy.install(containment, in: workspace.paths)
            let projectedEnvironment = try CodexRuntimeEnvironmentPolicy()
                .project(
                    inherited: environment,
                    workspace: workspace.paths,
                    forbiddenHomeURL: identity.homeURL
                )
            return CodexContainedInteractiveLaunchPlan(
                executableURL: nativeIdentityLease.canonicalURL,
                nativeIdentityLease: nativeIdentityLease,
                arguments: try policy.launchArguments(
                    codexExecutableURL: nativeIdentityLease.canonicalURL,
                    workspace: workspace.paths
                ),
                environment: projectedEnvironment,
                currentDirectoryURL: workspace.paths.workURL,
                workspace: workspace,
                projectedAuthSourceURL: authSourceURL,
                containmentConfiguration: containment
            )
        } catch {
            try? workspace.remove()
            throw error
        }
    }

    private func fixedRunRoot(
        identity: CodexContainedInteractiveWorkerIdentity,
        investigationID: UUID
    ) throws -> URL {
        let root = URL(
            filePath:
                "/Library/Application Support/Stornaut/R5Runtime",
            directoryHint: .isDirectory
        )
        .appending(
            path: String(identity.userID),
            directoryHint: .isDirectory
        )
        .appending(
            path: investigationID.uuidString.lowercased(),
            directoryHint: .isDirectory
        )
        .standardizedFileURL
        let userRoot = root.deletingLastPathComponent()
        let diagnosticRoot = userRoot.deletingLastPathComponent()
        let installedRoot = diagnosticRoot.deletingLastPathComponent()
        var installedInformation = stat()
        var diagnosticInformation = stat()
        var userRootInformation = stat()
        var information = stat()
        guard
            lstat(
                installedRoot.path,
                &installedInformation
            ) == 0,
            installedInformation.st_mode & S_IFMT == S_IFDIR,
            installedInformation.st_uid == 0,
            installedInformation.st_gid == 0,
            installedInformation.st_mode & 0o777 == 0o755,
            lstat(
                diagnosticRoot.path,
                &diagnosticInformation
            ) == 0,
            diagnosticInformation.st_mode & S_IFMT == S_IFDIR,
            diagnosticInformation.st_uid == 0,
            diagnosticInformation.st_gid == 0,
            diagnosticInformation.st_mode & 0o777 == 0o711,
            lstat(
                userRoot.path,
                &userRootInformation
            ) == 0,
            userRootInformation.st_mode & S_IFMT == S_IFDIR,
            userRootInformation.st_uid == 0,
            userRootInformation.st_gid == 0,
            userRootInformation.st_mode & 0o777 == 0o711,
            lstat(root.path, &information) == 0,
            information.st_mode & S_IFMT == S_IFDIR,
            information.st_uid == identity.userID,
            information.st_mode & 0o777 == 0o700
        else {
            throw CodexContainedInteractiveSessionError.launchFailed
        }
        return root
    }

    private func closedEnvironment(
        identity: CodexContainedInteractiveWorkerIdentity
    ) -> [String: String] {
        let inherited = ProcessInfo.processInfo.environment
        let fixedPATH = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
        ]
        .filter {
            var information = stat()
            return lstat($0, &information) == 0
                && information.st_mode & S_IFMT == S_IFDIR
        }
        .joined(separator: ":")
        var environment = [
            "HOME": identity.homeURL.path,
            "PATH": fixedPATH,
            "TERM": inherited["TERM"] ?? "dumb",
        ]
        for key in ["LANG", "LC_ALL", "LC_CTYPE"] {
            if let value = inherited[key], !value.isEmpty {
                environment[key] = value
            }
        }
        for key in ["SSL_CERT_FILE", "SSL_CERT_DIR"] {
            if let value = inherited[key], !value.isEmpty {
                environment[key] = value
            }
        }
        return environment
    }
}

private struct CodexContainedInteractiveWorkerIdentity: Sendable {
    let userID: uid_t
    let homeURL: URL

    static func current() throws -> Self {
        let userID = geteuid()
        guard
            userID > 0,
            let entry = getpwuid(userID),
            entry.pointee.pw_uid == userID,
            let home = entry.pointee.pw_dir
        else {
            throw CodexContainedInteractiveSessionError.launchFailed
        }
        let homeURL = URL(
            filePath: String(cString: home),
            directoryHint: .isDirectory
        )
        .resolvingSymlinksInPath()
        .standardizedFileURL
        var information = stat()
        guard
            homeURL.path.hasPrefix("/"),
            lstat(homeURL.path, &information) == 0,
            information.st_mode & S_IFMT == S_IFDIR,
            information.st_uid == userID
        else {
            throw CodexContainedInteractiveSessionError.launchFailed
        }
        return Self(userID: userID, homeURL: homeURL)
    }
}

private final class CodexContainedInteractiveResources:
    @unchecked Sendable
{
    let process: SpawnedDiagnosticProcess
    let writer: BoundedAppServerWriter
    let reader: BoundedAppServerLineReader
    let codexExecutableSHA256: String
    let cancellation = AppServerSessionCancellation()
    private let standardError: BoundedAppServerErrorOutput
    private let standardErrorGroup: DispatchGroup
    private let workspace: CodexRuntimeWorkspace
    private let nativeIdentityLease: CodexNativeExecutableIdentityLease

    init(
        plan: CodexContainedInteractiveLaunchPlan,
        launchReceipt: CodexContainedInteractiveNativeLaunchReceipt,
        maximumLineBytes: Int,
        maximumSessionBytes: Int
    ) throws {
        workspace = plan.workspace
        process = launchReceipt.process
        codexExecutableSHA256 = launchReceipt.codexExecutableSHA256
        nativeIdentityLease = launchReceipt.nativeIdentityLease
        do {
            writer = try BoundedAppServerWriter(
                descriptor: process.standardInput
            )
        } catch {
            forceCleanupDiagnosticProcess(process)
            Darwin.close(process.standardOutput)
            Darwin.close(process.standardError)
            try? workspace.remove()
            throw error
        }
        reader = BoundedAppServerLineReader(
            descriptor: process.standardOutput,
            lineByteLimit: maximumLineBytes,
            sessionByteLimit: maximumSessionBytes
        )
        standardError = BoundedAppServerErrorOutput(
            limit: min(maximumSessionBytes, 1_024 * 1_024)
        )
        standardErrorGroup = DispatchGroup()
        standardErrorGroup.enter()
        let output = standardError
        let descriptor = process.standardError
        let group = standardErrorGroup
        DispatchQueue.global(qos: .utility).async {
            output.drain(
                descriptor: descriptor,
                cancellation: self.cancellation
            )
            Darwin.close(descriptor)
            group.leave()
        }
    }

    func retire()
        -> CodexContainedInteractiveOwnerRetirementObservation?
    {
        cancellation.cancel()
        writer.close()
        var terminated = true
        do {
            try terminateDiagnosticProcessGroup(process.processGroup)
            _ = try reapDiagnosticProcess(process.pid)
            guard ProcessTreeTerminator.waitForProcessGroupExit(
                process.processGroup,
                timeout: .seconds(2)
            ) else {
                throw ProcessTreeTerminationError.unexpected
            }
        } catch {
            terminated = false
            forceCleanupDiagnosticProcess(process)
        }
        let postReapLeaseValid =
            terminated && (try? nativeIdentityLease.revalidate()) != nil
        reader.close()
        standardErrorGroup.wait()
        let stderrContained =
            !standardError.readFailed && !standardError.wasTruncated
        let workspaceRemoved: Bool
        do {
            try workspace.remove()
            workspaceRemoved = true
        } catch {
            workspaceRemoved = false
        }
        guard
            terminated, postReapLeaseValid, stderrContained, workspaceRemoved
        else {
            return nil
        }
        return .retiredOwnedResources
    }
}
