import Darwin
import Foundation
import StornautProcessSupport

public struct CodexContainedInteractiveSessionConfiguration:
    Sendable,
    Equatable
{
    public let investigationID: UUID
    public let validBefore: Date
    public let maximumLineBytes: Int
    public let maximumSessionBytes: Int

    public init(
        investigationID: UUID,
        validBefore: Date,
        maximumLineBytes: Int,
        maximumSessionBytes: Int
    ) {
        self.investigationID = investigationID
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

struct CodexContainedInteractiveLaunchPlan: Sendable {
    let executableURL: URL
    let arguments: [String]
    let environment: CodexRuntimeEnvironment
    let currentDirectoryURL: URL
    let workspace: CodexRuntimeWorkspace
    let projectedAuthSourceURL: URL
    let containmentConfiguration: CodexContainmentConfiguration

    init(
        executableURL: URL,
        arguments: [String],
        environment: CodexRuntimeEnvironment,
        currentDirectoryURL: URL,
        workspace: CodexRuntimeWorkspace,
        projectedAuthSourceURL: URL,
        containmentConfiguration: CodexContainmentConfiguration
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.environment = environment
        self.currentDirectoryURL = currentDirectoryURL
        self.workspace = workspace
        self.projectedAuthSourceURL = projectedAuthSourceURL
        self.containmentConfiguration = containmentConfiguration
    }
}

public actor CodexContainedInteractiveSession {
    typealias PlanBuilder = @Sendable (
        CodexContainedInteractiveSessionConfiguration
    ) async throws -> CodexContainedInteractiveLaunchPlan

    private enum State {
        case ready
        case starting
        case active
        case failed
        case retiring
        case retired
    }

    private static let maximumAllowedLineBytes = 2 * 1_024 * 1_024
    private static let maximumAllowedSessionBytes = 16 * 1_024 * 1_024

    private let now: @Sendable () -> Date
    private let planBuilder: PlanBuilder
    private var state = State.ready
    private var configuration:
        CodexContainedInteractiveSessionConfiguration?
    private var resources: CodexContainedInteractiveResources?
    private var transferredBytes = 0
    private var operationInProgress = false
    private var retirementTask: Task<Bool, Never>?

    public init() {
        now = Date.init
        planBuilder = {
            try await CodexContainedInteractivePlanBuilder().build($0)
        }
    }

    init(
        now: @escaping @Sendable () -> Date = Date.init,
        planBuilder: @escaping PlanBuilder
    ) {
        self.now = now
        self.planBuilder = planBuilder
    }

    public func start(
        _ configuration: CodexContainedInteractiveSessionConfiguration
    ) async throws {
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

        let plan: CodexContainedInteractiveLaunchPlan
        do {
            plan = try await planBuilder(configuration)
        } catch {
            if state == .starting {
                state = .failed
            }
            throw CodexContainedInteractiveSessionError.launchFailed
        }
        guard state == .starting else {
            try? plan.workspace.remove()
            throw CodexContainedInteractiveSessionError
                .sessionUnavailable
        }
        guard valid(configuration, at: now()) else {
            state = .failed
            try? plan.workspace.remove()
            throw CodexContainedInteractiveSessionError
                .invalidConfiguration
        }
        guard valid(plan) else {
            state = .failed
            try? plan.workspace.remove()
            throw CodexContainedInteractiveSessionError.launchFailed
        }

        do {
            resources = try CodexContainedInteractiveResources(
                plan: plan,
                maximumLineBytes: configuration.maximumLineBytes,
                maximumSessionBytes: configuration.maximumSessionBytes
            )
        } catch {
            state = .failed
            try? plan.workspace.remove()
            throw CodexContainedInteractiveSessionError.launchFailed
        }
        state = .active
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

    public func retire() async throws -> Bool {
        if state == .retired {
            return true
        }
        if let retirementTask {
            let drained = await retirementTask.value
            if !drained {
                throw CodexContainedInteractiveSessionError
                    .retirementFailed
            }
            return true
        }
        state = .retiring
        guard let resources else {
            state = .retired
            return true
        }
        resources.cancellation.cancel()
        let task = Task<Bool, Never> {
            while operationInProgress {
                await Task.yield()
            }
            return await Task.detached(priority: .utility) {
                resources.retire()
            }.value
        }
        retirementTask = task
        let drained = await task.value
        self.resources = nil
        state = drained ? .retired : .failed
        guard drained else {
            throw CodexContainedInteractiveSessionError.retirementFailed
        }
        return true
    }

    private func valid(
        _ configuration: CodexContainedInteractiveSessionConfiguration,
        at current: Date
    ) -> Bool {
        configuration.validBefore.timeIntervalSince1970.isFinite
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
        _ plan: CodexContainedInteractiveLaunchPlan
    ) -> Bool {
        guard
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
                executableURL: installation.executableURL,
                arguments: try policy.launchArguments(
                    codexExecutableURL: installation.executableURL,
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
    let cancellation = AppServerSessionCancellation()
    private let standardError: BoundedAppServerErrorOutput
    private let standardErrorGroup: DispatchGroup
    private let workspace: CodexRuntimeWorkspace

    init(
        plan: CodexContainedInteractiveLaunchPlan,
        maximumLineBytes: Int,
        maximumSessionBytes: Int
    ) throws {
        workspace = plan.workspace
        process = try spawnDiagnosticProcess(
            executableURL: plan.executableURL,
            arguments: plan.arguments,
            environment: plan.environment.values,
            currentDirectoryURL: plan.currentDirectoryURL
        )
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

    func retire() -> Bool {
        cancellation.cancel()
        writer.close()
        var terminated = true
        do {
            try terminateDiagnosticProcessGroup(process.processGroup)
            _ = try reapDiagnosticProcess(process.pid)
        } catch {
            terminated = false
            forceCleanupDiagnosticProcess(process)
        }
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
        return terminated && stderrContained && workspaceRemoved
    }
}
