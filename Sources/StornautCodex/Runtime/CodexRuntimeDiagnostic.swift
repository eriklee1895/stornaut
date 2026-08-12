import Darwin
import Foundation
import StornautProcessSupport

struct CodexRuntimeDiagnosticRequest: Sendable, Equatable {
    let profile: CodexRuntimeProfile
    let executableURL: URL
    let runtimeHomeURL: URL
    let userHomeURL: URL
    let workingDirectoryURL: URL
    let environment: [String: String]
    let forbiddenPathFragments: [String]

    init(
        profile: CodexRuntimeProfile,
        executableURL: URL,
        runtimeHomeURL: URL,
        userHomeURL: URL,
        workingDirectoryURL: URL,
        environment: [String: String],
        forbiddenPathFragments: [String]
    ) {
        self.profile = profile
        self.executableURL = executableURL
        self.runtimeHomeURL = runtimeHomeURL
        self.userHomeURL = userHomeURL
        self.workingDirectoryURL = workingDirectoryURL
        self.environment = environment
        self.forbiddenPathFragments = forbiddenPathFragments
    }
}

protocol CodexRuntimeDiagnosticRunning: Sendable {
    func run(
        _ request: CodexRuntimeDiagnosticRequest
    ) async throws -> CodexRuntimeDiagnosticEvidence
}

public enum CodexRuntimeDiagnosticError: Error, Sendable, Equatable {
    case invalidExecutable
    case invalidDirectory
    case overlappingDirectories
    case unsafeWorkingDirectory
    case globalInstructionsPresent
    case profileDigestMismatch
    case processFailed(reasonKey: String)
    case outputLimitExceeded
    case invalidUTF8
    case invalidProtocol
    case outputReadFailed(stream: String)
    case timedOut
}

struct CodexRuntimeDiagnostic: Sendable {
    private let runner: any CodexRuntimeDiagnosticRunning

    init(
        runner: any CodexRuntimeDiagnosticRunning =
            FoundationCodexRuntimeDiagnosticRunner()
    ) {
        self.runner = runner
    }

    func validate(
        profile: CodexRuntimeProfile,
        executableURL: URL,
        isolatedRuntimeHomeURL: URL,
        isolatedUserHomeURL: URL,
        isolatedWorkingDirectoryURL: URL,
        inheritedEnvironment: [String: String]
    ) async throws -> CodexRuntimeDiagnosticEvidence {
        let executable = executableURL.resolvingSymlinksInPath()
            .standardizedFileURL
        let runtimeHome = isolatedRuntimeHomeURL.resolvingSymlinksInPath()
            .standardizedFileURL
        let userHome = isolatedUserHomeURL.resolvingSymlinksInPath()
            .standardizedFileURL
        let work = isolatedWorkingDirectoryURL.resolvingSymlinksInPath()
            .standardizedFileURL

        guard
            executable.isFileURL,
            executable.path.hasPrefix("/"),
            FileManager.default.isExecutableFile(atPath: executable.path),
            isRegularFile(executable)
        else {
            throw CodexRuntimeDiagnosticError.invalidExecutable
        }
        guard [runtimeHome, userHome, work].allSatisfy({
            $0.isFileURL
                && $0.path.hasPrefix("/")
                && isOwnerOnlyDirectory($0)
        }) else {
            throw CodexRuntimeDiagnosticError.invalidDirectory
        }
        guard directoriesAreDisjoint([runtimeHome, userHome, work]) else {
            throw CodexRuntimeDiagnosticError.overlappingDirectories
        }
        guard
            !FileManager.default.fileExists(
                atPath: work.appending(path: ".git").path
            ),
            !FileManager.default.fileExists(
                atPath: work.appending(path: ".codex").path
            )
        else {
            throw CodexRuntimeDiagnosticError.unsafeWorkingDirectory
        }
        guard [runtimeHome, userHome, work].allSatisfy({
            directoryIsEmpty($0)
        }) else {
            throw CodexRuntimeDiagnosticError.unsafeWorkingDirectory
        }
        guard globalInstructionsAreAbsent(in: runtimeHome) else {
            throw CodexRuntimeDiagnosticError.globalInstructionsPresent
        }

        let forbidden = [
            inheritedEnvironment["HOME"],
            inheritedEnvironment["CODEX_HOME"],
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .filter {
            $0 != runtimeHome.path
                && $0 != userHome.path
                && $0 != work.path
        }
        var environment = sanitizedEnvironment(inheritedEnvironment)
        environment["CODEX_HOME"] = runtimeHome.path
        environment["HOME"] = userHome.path
        let runtimeTemporaryDirectory = runtimeHome.appending(
            path: "tmp",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: runtimeTemporaryDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        environment["TMPDIR"] = runtimeTemporaryDirectory.path

        let evidence = try await runner.run(
            CodexRuntimeDiagnosticRequest(
                profile: profile,
                executableURL: executable,
                runtimeHomeURL: runtimeHome,
                userHomeURL: userHome,
                workingDirectoryURL: work,
                environment: environment,
                forbiddenPathFragments: forbidden
            )
        )
        guard evidence.profileDigest == profile.profileDigest else {
            throw CodexRuntimeDiagnosticError.profileDigestMismatch
        }
        return evidence
    }
}

struct FoundationCodexRuntimeDiagnosticRunner:
    CodexRuntimeDiagnosticRunning
{
    private static let outputLimit = 128 * 1_024
    private static let errorLimit = 32 * 1_024
    private static let timeout: Duration = .seconds(15)
    private static let skillName = "stornaut-runtime-diagnostic"
    private static let skillMarker = "STORNAUT_RUNTIME_SKILL_CANARY"
    private static let instructionMarker =
        "STORNAUT_PROJECT_INSTRUCTION_CANARY"

    init() {}

    func run(
        _ request: CodexRuntimeDiagnosticRequest
    ) async throws -> CodexRuntimeDiagnosticEvidence {
        try await Task.detached(priority: .utility) {
            try runSynchronously(request)
        }.value
    }

    private func runSynchronously(
        _ request: CodexRuntimeDiagnosticRequest
    ) throws -> CodexRuntimeDiagnosticEvidence {
        try stageCanaries(request)
        defer { removeCanaries(request) }

        try runStage(
            reasonKey: "runtime.strictConfig.protocolInvalid"
        ) {
            try runStrictNegativeCanaries(request)
        }
        try runStage(
            reasonKey: "runtime.appServer.protocolInvalid"
        ) {
            try runAppServerCanary(request)
        }
        let featureStates = try runStage(
            reasonKey: "runtime.features.protocolInvalid"
        ) {
            try runFeatureCanary(request)
        }
        let promptResult = try runStage(
            reasonKey: "runtime.promptInput.protocolInvalid"
        ) {
            try runPromptInputCanary(request)
        }
        try runStage(
            reasonKey: "runtime.ignoreUserConfig.protocolInvalid"
        ) {
            try runIgnoreUserConfigCanary(request)
        }

        return CodexRuntimeDiagnosticEvidence(
            profileDigest: request.profile.profileDigest,
            strictConfigurationPassed: true,
            ignoredUserConfiguration: true,
            ignoredExecRules: true,
            hookInventoryEmpty: true,
            instructionIsolationPassed: promptResult.instructionsIsolated,
            runtimeSkillIsolationPassed: promptResult.skillsIsolated,
            featureStates: featureStates
        )
    }

    private func runStage<Result>(
        reasonKey: String,
        operation: () throws -> Result
    ) throws -> Result {
        do {
            return try operation()
        } catch CodexRuntimeDiagnosticError.invalidProtocol {
            throw CodexRuntimeDiagnosticError.processFailed(
                reasonKey: reasonKey
            )
        }
    }

    private func stageCanaries(
        _ request: CodexRuntimeDiagnosticRequest
    ) throws {
        let skillDirectory = request.runtimeHomeURL
            .appending(path: "skills", directoryHint: .isDirectory)
            .appending(
                path: Self.skillName,
                directoryHint: .isDirectory
            )
        try FileManager.default.createDirectory(
            at: skillDirectory,
            withIntermediateDirectories: true
        )
        let skill = """
        ---
        name: \(Self.skillName)
        description: \(Self.skillMarker)
        ---
        Synthetic runtime diagnostic skill.
        """
        try Data(skill.utf8).write(
            to: skillDirectory.appending(path: "SKILL.md"),
            options: .atomic
        )
        try Data(Self.instructionMarker.utf8).write(
            to: request.workingDirectoryURL.appending(path: "AGENTS.md"),
            options: .atomic
        )
    }

    private func removeCanaries(
        _ request: CodexRuntimeDiagnosticRequest
    ) {
        try? FileManager.default.removeItem(
            at: request.runtimeHomeURL
                .appending(path: "skills", directoryHint: .isDirectory)
                .appending(
                    path: Self.skillName,
                    directoryHint: .isDirectory
                )
        )
        try? FileManager.default.removeItem(
            at: request.workingDirectoryURL.appending(path: "AGENTS.md")
        )
        try? FileManager.default.removeItem(
            at: request.runtimeHomeURL.appending(path: "config.toml")
        )
        try? FileManager.default.removeItem(
            at: request.runtimeHomeURL.appending(
                path: "stornaut-invalid-schema.json"
            )
        )
    }

    private func runStrictNegativeCanaries(
        _ request: CodexRuntimeDiagnosticRequest
    ) throws {
        for invalidOverride in [
            "stornaut_unknown_config_key=true",
            "features.stornaut_unknown_feature=true",
        ] {
            var arguments = request.profile.appServerDiagnosticArguments
            let insertion = arguments.firstIndex(of: "app-server")
                ?? arguments.endIndex
            arguments.insert(
                contentsOf: ["-c", invalidOverride],
                at: insertion
            )
            let output = try runProcess(
                executableURL: request.executableURL,
                arguments: arguments,
                environment: request.environment,
                currentDirectoryURL: request.workingDirectoryURL,
                standardInput: Data()
            )
            guard
                output.exitStatus != 0,
                output.stderrText.contains(
                    "unknown configuration field"
                )
            else {
                throw CodexRuntimeDiagnosticError.processFailed(
                    reasonKey: "runtime.strictConfig.negativeCanaryFailed"
                )
            }
        }
    }

    private func runAppServerCanary(
        _ request: CodexRuntimeDiagnosticRequest
    ) throws {
        let process = try spawnDiagnosticProcess(
            executableURL: request.executableURL,
            arguments: request.profile.appServerDiagnosticArguments,
            environment: request.environment,
            currentDirectoryURL: request.workingDirectoryURL
        )
        let writer = FileHandle(
            fileDescriptor: process.standardInput,
            closeOnDealloc: true
        )
        let stdoutHandle = FileHandle(
            fileDescriptor: process.standardOutput,
            closeOnDealloc: true
        )
        let stderrHandle = FileHandle(
            fileDescriptor: process.standardError,
            closeOnDealloc: true
        )
        let stderr = LockedDiagnosticOutput(limit: Self.errorLimit)
        var reaped = false

        let stderrGroup = DispatchGroup()
        stderrGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            stderr.drain(stderrHandle)
            stderrGroup.leave()
        }
        defer {
            try? writer.close()
            if !reaped {
                forceCleanupDiagnosticProcess(process)
            }
            try? stdoutHandle.close()
            stderrGroup.wait()
        }

        let reader = BoundedJSONLineReader(
            descriptor: stdoutHandle.fileDescriptor,
            byteLimit: Self.outputLimit
        )

        try writeJSONLine(
            [
                "id": 1,
                "method": "initialize",
                "params": [
                    "clientInfo": [
                        "name": "stornaut-r2-diagnostic",
                        "title": "Stornaut R2 Diagnostic",
                        "version": "1",
                    ],
                    "capabilities": ["experimentalApi": true],
                ],
            ],
            to: writer
        )

        var initialized = false
        var requestedHooks = false
        var hookInventoryPassed = false
        let deadline = Date().addingTimeInterval(15)
        while !hookInventoryPassed {
            let object = try reader.nextObject(deadline: deadline)
            if let method = object["method"] as? String {
                guard method == "remoteControl/status/changed" else {
                    throw CodexRuntimeDiagnosticError.processFailed(
                        reasonKey: "runtime.appServer.unexpectedNotification"
                    )
                }
                continue
            }
            guard let identifier = object["id"] as? Int else {
                throw CodexRuntimeDiagnosticError.processFailed(
                    reasonKey: "runtime.appServer.missingResponseID"
                )
            }
            switch identifier {
            case 1:
                guard !initialized, !requestedHooks else {
                    throw CodexRuntimeDiagnosticError.processFailed(
                        reasonKey: "runtime.appServer.duplicateInitialize"
                    )
                }
                guard
                    object["error"] == nil,
                    let result = object["result"] as? [String: Any],
                    let codexHome = result["codexHome"] as? String,
                    URL(filePath: codexHome)
                        .resolvingSymlinksInPath()
                        .standardizedFileURL
                        .path == request.runtimeHomeURL.path
                else {
                    throw CodexRuntimeDiagnosticError.processFailed(
                        reasonKey: "runtime.appServer.invalidInitializeResponse"
                    )
                }
                initialized = true
                try writeJSONLine(["method": "initialized"], to: writer)
                try writeJSONLine(
                    [
                        "id": 2,
                        "method": "hooks/list",
                        "params": [
                            "cwds": [
                                request.workingDirectoryURL.path,
                            ],
                        ],
                    ],
                    to: writer
                )
                requestedHooks = true
            case 2:
                guard initialized, requestedHooks else {
                    throw CodexRuntimeDiagnosticError.processFailed(
                        reasonKey: "runtime.appServer.hooksBeforeInitialize"
                    )
                }
                guard
                    object["error"] == nil,
                    let result = object["result"] as? [String: Any],
                    let data = result["data"] as? [[String: Any]],
                    data.count == 1,
                    let hooks = data[0]["hooks"] as? [Any],
                    let warnings = data[0]["warnings"] as? [Any],
                    let errors = data[0]["errors"] as? [Any],
                    hooks.isEmpty,
                    warnings.isEmpty,
                    errors.isEmpty
                else {
                    throw CodexRuntimeDiagnosticError.processFailed(
                        reasonKey: "runtime.hooks.inventoryNotEmpty"
                    )
                }
                hookInventoryPassed = true
            default:
                throw CodexRuntimeDiagnosticError.processFailed(
                    reasonKey: "runtime.appServer.unexpectedResponseID"
                )
            }
        }

        try writer.close()
        guard try waitForDiagnosticProcessExit(
            process.pid,
            timeout: Self.timeout
        ) else {
            throw CodexRuntimeDiagnosticError.timedOut
        }
        if ProcessTreeTerminator.processGroupHasMembers(
            process.processGroup,
            excluding: process.pid
        ) {
            usleep(50_000)
        }
        if ProcessTreeTerminator.processGroupHasMembers(
            process.processGroup,
            excluding: process.pid
        ) {
            try terminateDiagnosticProcessGroup(process.processGroup)
        }
        let waitStatus = try reapDiagnosticProcess(process.pid)
        reaped = true
        stderrGroup.wait()
        guard
            normalizedDiagnosticExitStatus(waitStatus) == 0,
            !stderr.wasTruncated,
            stderr.data.isEmpty
        else {
            throw CodexRuntimeDiagnosticError.processFailed(
                reasonKey: "runtime.appServer.nonzeroExit"
            )
        }
    }

    private func runFeatureCanary(
        _ request: CodexRuntimeDiagnosticRequest
    ) throws -> [String: Bool] {
        let output = try runProcess(
            executableURL: request.executableURL,
            arguments: request.profile.featureDiagnosticArguments,
            environment: request.environment,
            currentDirectoryURL: request.workingDirectoryURL,
            standardInput: nil
        )
        guard output.exitStatus == 0 else {
            throw CodexRuntimeDiagnosticError.processFailed(
                reasonKey: "runtime.features.nonzeroExit"
            )
        }
        let parsed = try parseFeatureStates(output.stdoutText)
        for (name, expected) in
            CodexRuntimeCapabilityParser.expectedFeatureStates
        {
            guard parsed[name] == expected else {
                throw CodexRuntimeDiagnosticError.processFailed(
                    reasonKey: "runtime.featureState.mismatch"
                )
            }
        }
        for advertised in [
            "browser_use",
            "browser_use_external",
            "browser_use_full_cdp_access",
            "view_image",
            "hooks",
        ] {
            guard parsed[advertised] == true else {
                throw CodexRuntimeDiagnosticError.processFailed(
                    reasonKey: "runtime.featureState.missingDeclaration"
                )
            }
        }
        return parsed
    }

    private struct PromptResult {
        let instructionsIsolated: Bool
        let skillsIsolated: Bool
    }

    private func runPromptInputCanary(
        _ request: CodexRuntimeDiagnosticRequest
    ) throws -> PromptResult {
        var arguments = ["-C", request.workingDirectoryURL.path]
        arguments.append(
            contentsOf: request.profile.promptInputDiagnosticArguments
        )
        let output = try runProcess(
            executableURL: request.executableURL,
            arguments: arguments,
            environment: request.environment,
            currentDirectoryURL: request.workingDirectoryURL,
            standardInput: nil
        )
        guard output.exitStatus == 0 else {
            throw CodexRuntimeDiagnosticError.processFailed(
                reasonKey: "runtime.promptInput.nonzeroExit"
            )
        }
        let text = output.stdoutText
        let instructionsIsolated =
            !text.contains(Self.instructionMarker)
            && request.forbiddenPathFragments.allSatisfy {
                !text.contains($0)
            }
        let bundledMarkers = [
            "imagegen:",
            "openai-docs:",
            "skill-creator:",
            "skill-installer:",
        ]
        let skillsIsolated =
            text.components(separatedBy: Self.skillMarker).count == 2
            && bundledMarkers.allSatisfy { !text.contains($0) }
        guard instructionsIsolated, skillsIsolated else {
            throw CodexRuntimeDiagnosticError.processFailed(
                reasonKey: "runtime.promptInput.notIsolated"
            )
        }
        return PromptResult(
            instructionsIsolated: instructionsIsolated,
            skillsIsolated: skillsIsolated
        )
    }

    private func runIgnoreUserConfigCanary(
        _ request: CodexRuntimeDiagnosticRequest
    ) throws {
        let configURL = request.runtimeHomeURL.appending(
            path: "config.toml"
        )
        let schemaURL = request.runtimeHomeURL.appending(
            path: "stornaut-invalid-schema.json"
        )
        try Data("this is not valid toml = [\n".utf8).write(
            to: configURL,
            options: .atomic
        )
        try Data("{invalid json\n".utf8).write(
            to: schemaURL,
            options: .atomic
        )

        let prompt = Data("synthetic no-model failpoint\n".utf8)
        let ignored = try runProcess(
            executableURL: request.executableURL,
            arguments: try request.profile
                .ignoreUserConfigDiagnosticArguments(
                    schemaURL: schemaURL,
                    workingDirectoryURL: request.workingDirectoryURL,
                    ignoresUserConfig: true
                ),
            environment: request.environment,
            currentDirectoryURL: request.workingDirectoryURL,
            standardInput: prompt
        )
        guard
            ignored.exitStatus != 0,
            ignored.stderrText.contains("Output schema file"),
            ignored.stderrText.contains("is not valid JSON"),
            !ignored.stderrText.contains("Error loading config.toml")
        else {
            throw CodexRuntimeDiagnosticError.processFailed(
                reasonKey: "runtime.ignoreUserConfig.positiveFailed"
            )
        }

        let loaded = try runProcess(
            executableURL: request.executableURL,
            arguments: try request.profile
                .ignoreUserConfigDiagnosticArguments(
                    schemaURL: schemaURL,
                    workingDirectoryURL: request.workingDirectoryURL,
                    ignoresUserConfig: false
                ),
            environment: request.environment,
            currentDirectoryURL: request.workingDirectoryURL,
            standardInput: prompt
        )
        guard
            loaded.exitStatus != 0,
            loaded.stderrText.contains("Error loading config.toml")
        else {
            throw CodexRuntimeDiagnosticError.processFailed(
                reasonKey: "runtime.ignoreUserConfig.negativeFailed"
            )
        }
    }

    private func runProcess(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        currentDirectoryURL: URL,
        standardInput: Data?
    ) throws -> CodexRuntimeDiagnosticProcessOutput {
        try FoundationCodexRuntimeDiagnosticProcessRunner().run(
            executableURL: executableURL,
            arguments: arguments,
            environment: environment,
            currentDirectoryURL: currentDirectoryURL,
            standardInput: standardInput,
            standardOutputLimit: Self.outputLimit,
            standardErrorLimit: Self.errorLimit,
            timeout: Self.timeout
        )
    }

    private func parseFeatureStates(
        _ output: String
    ) throws -> [String: Bool] {
        var states: [String: Bool] = [:]
        for rawLine in output.split(separator: "\n") {
            let columns = rawLine.split(
                whereSeparator: \.isWhitespace
            )
            guard
                columns.count >= 3,
                let enabled = Bool(String(columns.last!))
            else {
                throw CodexRuntimeDiagnosticError.invalidProtocol
            }
            let name = String(columns[0])
            guard states[name] == nil else {
                throw CodexRuntimeDiagnosticError.invalidProtocol
            }
            states[name] = enabled
        }
        return states
    }

    private func writeJSONLine(
        _ object: [String: Any],
        to handle: FileHandle
    ) throws {
        guard JSONSerialization.isValidJSONObject(object) else {
            throw CodexRuntimeDiagnosticError.invalidProtocol
        }
        var data = try JSONSerialization.data(withJSONObject: object)
        data.append(0x0A)
        do {
            try handle.write(contentsOf: data)
        } catch {
            throw CodexRuntimeDiagnosticError.invalidProtocol
        }
    }
}

struct CodexRuntimeDiagnosticProcessOutput: Sendable, Equatable {
    let exitStatus: Int32
    let stdout: Data
    let stderr: Data
    let stdoutWasTruncated: Bool
    let stderrWasTruncated: Bool

    var stdoutText: String {
        String(decoding: stdout, as: UTF8.self)
    }

    var stderrText: String {
        String(decoding: stderr, as: UTF8.self)
    }
}

struct FoundationCodexRuntimeDiagnosticProcessRunner: Sendable {
    func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        currentDirectoryURL: URL,
        standardInput: Data?,
        standardOutputLimit: Int,
        standardErrorLimit: Int,
        timeout: Duration,
        rejectTruncatedOutput: Bool = true,
        requireUTF8: Bool = true
    ) throws -> CodexRuntimeDiagnosticProcessOutput {
        guard
            standardOutputLimit >= 0,
            standardErrorLimit >= 0,
            timeout > .zero
        else {
            throw CodexRuntimeDiagnosticError.invalidProtocol
        }

        let process = try spawnDiagnosticProcess(
            executableURL: executableURL,
            arguments: arguments,
            environment: environment,
            currentDirectoryURL: currentDirectoryURL
        )
        let stdout = LockedDiagnosticOutput(limit: standardOutputLimit)
        let stderr = LockedDiagnosticOutput(limit: standardErrorLimit)
        let readers = DispatchGroup()
        var reaped = false
        let stdoutHandle = FileHandle(
            fileDescriptor: process.standardOutput,
            closeOnDealloc: true
        )
        let stderrHandle = FileHandle(
            fileDescriptor: process.standardError,
            closeOnDealloc: true
        )

        readers.enter()
        DispatchQueue.global(qos: .utility).async {
            stdout.drain(stdoutHandle)
            readers.leave()
        }
        readers.enter()
        DispatchQueue.global(qos: .utility).async {
            stderr.drain(stderrHandle)
            readers.leave()
        }
        defer {
            if !reaped {
                forceCleanupDiagnosticProcess(process)
            }
            readers.wait()
        }

        let inputHandle = FileHandle(
            fileDescriptor: process.standardInput,
            closeOnDealloc: true
        )
        do {
            if let standardInput {
                try inputHandle.write(contentsOf: standardInput)
            }
            try inputHandle.close()
        } catch {
            throw CodexRuntimeDiagnosticError.processFailed(
                reasonKey: "runtime.process.inputFailed"
            )
        }

        let didExit = try waitForDiagnosticProcessExit(
            process.pid,
            timeout: timeout
        )
        if !didExit {
            try terminateDiagnosticProcessGroup(process.processGroup)
            _ = try reapDiagnosticProcess(process.pid)
            reaped = true
            throw CodexRuntimeDiagnosticError.timedOut
        }

        if ProcessTreeTerminator.processGroupHasMembers(
            process.processGroup,
            excluding: process.pid
        ) {
            usleep(50_000)
        }
        if ProcessTreeTerminator.processGroupHasMembers(
            process.processGroup,
            excluding: process.pid
        ) {
            try terminateDiagnosticProcessGroup(process.processGroup)
        }
        let waitStatus = try reapDiagnosticProcess(process.pid)
        reaped = true
        readers.wait()

        if stdout.readFailed {
            throw CodexRuntimeDiagnosticError.outputReadFailed(
                stream: "stdout"
            )
        }
        if stderr.readFailed {
            throw CodexRuntimeDiagnosticError.outputReadFailed(
                stream: "stderr"
            )
        }
        if
            rejectTruncatedOutput,
            stdout.wasTruncated || stderr.wasTruncated
        {
            throw CodexRuntimeDiagnosticError.outputLimitExceeded
        }
        if requireUTF8 {
            guard
                String(data: stdout.data, encoding: .utf8) != nil,
                String(data: stderr.data, encoding: .utf8) != nil
            else {
                throw CodexRuntimeDiagnosticError.invalidUTF8
            }
        }
        return CodexRuntimeDiagnosticProcessOutput(
            exitStatus: normalizedDiagnosticExitStatus(waitStatus),
            stdout: stdout.data,
            stderr: stderr.data,
            stdoutWasTruncated: stdout.wasTruncated,
            stderrWasTruncated: stderr.wasTruncated
        )
    }
}

struct SpawnedDiagnosticProcess {
    let pid: pid_t
    let processGroup: ProcessGroupID
    let standardInput: Int32
    let standardOutput: Int32
    let standardError: Int32
}

func spawnDiagnosticProcess(
    executableURL: URL,
    arguments: [String],
    environment: [String: String],
    currentDirectoryURL: URL
) throws -> SpawnedDiagnosticProcess {
    let stdinPipe = try createDiagnosticPipe()
    let stdoutPipe = try createDiagnosticPipe()
    let stderrPipe = try createDiagnosticPipe()
    var parentDescriptors = [
        stdinPipe.read,
        stdinPipe.write,
        stdoutPipe.read,
        stdoutPipe.write,
        stderrPipe.read,
        stderrPipe.write,
    ]

    do {
        var fileActions: posix_spawn_file_actions_t?
        guard posix_spawn_file_actions_init(&fileActions) == 0 else {
            throw CodexRuntimeDiagnosticError.processFailed(
                reasonKey: "runtime.process.launchFailed"
            )
        }
        defer { posix_spawn_file_actions_destroy(&fileActions) }

        try addDiagnosticDup(
            stdinPipe.read,
            to: STDIN_FILENO,
            actions: &fileActions
        )
        try addDiagnosticDup(
            stdoutPipe.write,
            to: STDOUT_FILENO,
            actions: &fileActions
        )
        try addDiagnosticDup(
            stderrPipe.write,
            to: STDERR_FILENO,
            actions: &fileActions
        )
        for descriptor in parentDescriptors {
            try addDiagnosticClose(descriptor, actions: &fileActions)
        }
        let changeDirectoryResult = currentDirectoryURL.path.withCString {
            posix_spawn_file_actions_addchdir(&fileActions, $0)
        }
        guard changeDirectoryResult == 0 else {
            throw CodexRuntimeDiagnosticError.processFailed(
                reasonKey: "runtime.process.launchFailed"
            )
        }

        var attributes: posix_spawnattr_t?
        guard posix_spawnattr_init(&attributes) == 0 else {
            throw CodexRuntimeDiagnosticError.processFailed(
                reasonKey: "runtime.process.launchFailed"
            )
        }
        defer { posix_spawnattr_destroy(&attributes) }
        guard
            posix_spawnattr_setflags(
                &attributes,
                Int16(
                    POSIX_SPAWN_SETPGROUP
                        | POSIX_SPAWN_CLOEXEC_DEFAULT
                )
            ) == 0,
            posix_spawnattr_setpgroup(&attributes, 0) == 0
        else {
            throw CodexRuntimeDiagnosticError.processFailed(
                reasonKey: "runtime.process.launchFailed"
            )
        }

        let argv = [executableURL.path] + arguments
        let envp = environment.map { "\($0.key)=\($0.value)" }.sorted()
        var pid: pid_t = 0
        let result = try withDiagnosticCStringArray(argv) { arguments in
            try withDiagnosticCStringArray(envp) { environment in
                executableURL.path.withCString { executable in
                    posix_spawn(
                        &pid,
                        executable,
                        &fileActions,
                        &attributes,
                        arguments,
                        environment
                    )
                }
            }
        }
        guard result == 0 else {
            throw CodexRuntimeDiagnosticError.processFailed(
                reasonKey: "runtime.process.launchFailed"
            )
        }

        close(stdinPipe.read)
        close(stdoutPipe.write)
        close(stderrPipe.write)
        parentDescriptors.removeAll()
        guard fcntl(stdinPipe.write, F_SETNOSIGPIPE, 1) == 0 else {
            let processGroup = ProcessGroupID(rawValue: pid)
            try? terminateDiagnosticProcessGroup(processGroup)
            _ = waitpid(pid, nil, 0)
            close(stdinPipe.write)
            close(stdoutPipe.read)
            close(stderrPipe.read)
            throw CodexRuntimeDiagnosticError.processFailed(
                reasonKey: "runtime.process.launchFailed"
            )
        }

        let processGroup = getpgid(pid)
        guard processGroup == pid, processGroup != getpgrp() else {
            kill(pid, SIGKILL)
            _ = waitpid(pid, nil, 0)
            close(stdinPipe.write)
            close(stdoutPipe.read)
            close(stderrPipe.read)
            throw CodexRuntimeDiagnosticError.processFailed(
                reasonKey: "runtime.process.groupIsolationFailed"
            )
        }
        return SpawnedDiagnosticProcess(
            pid: pid,
            processGroup: ProcessGroupID(rawValue: processGroup),
            standardInput: stdinPipe.write,
            standardOutput: stdoutPipe.read,
            standardError: stderrPipe.read
        )
    } catch {
        for descriptor in parentDescriptors {
            close(descriptor)
        }
        throw error
    }
}

private func waitForDiagnosticProcessExit(
    _ pid: pid_t,
    timeout: Duration
) throws -> Bool {
    let deadline = timeout.dispatchDeadline
    while deadline.uptimeNanoseconds > DispatchTime.now().uptimeNanoseconds {
        var information = siginfo_t()
        let result = waitid(
            P_PID,
            UInt32(pid),
            &information,
            WEXITED | WNOHANG | WNOWAIT
        )
        guard result == 0 else {
            throw CodexRuntimeDiagnosticError.invalidProtocol
        }
        if information.si_pid == pid {
            return true
        }
        usleep(5_000)
    }
    return false
}

private final class DiagnosticTerminationResult: @unchecked Sendable {
    private let lock = NSLock()
    private var failure: ProcessTreeTerminationError?

    func store(_ error: ProcessTreeTerminationError?) {
        lock.withLock { failure = error }
    }

    var error: ProcessTreeTerminationError? {
        lock.withLock { failure }
    }
}

func terminateDiagnosticProcessGroup(
    _ processGroup: ProcessGroupID
) throws {
    let completed = DispatchSemaphore(value: 0)
    let result = DiagnosticTerminationResult()
    Task.detached(priority: .utility) {
        do {
            _ = try await ProcessTreeTerminator().terminateProcessGroup(
                processGroup,
                gracePeriod: .milliseconds(250)
            )
            result.store(nil)
        } catch let error as ProcessTreeTerminationError {
            result.store(error)
        } catch {
            result.store(.unexpected)
        }
        completed.signal()
    }
    guard completed.wait(timeout: .now() + .seconds(2)) == .success else {
        kill(-processGroup.rawValue, SIGKILL)
        throw CodexRuntimeDiagnosticError.processFailed(
            reasonKey: "runtime.process.terminationTimedOut"
        )
    }
    if result.error != nil {
        throw CodexRuntimeDiagnosticError.processFailed(
            reasonKey: "runtime.process.terminationFailed"
        )
    }
}

func forceCleanupDiagnosticProcess(
    _ process: SpawnedDiagnosticProcess
) {
    kill(-process.processGroup.rawValue, SIGKILL)
    kill(process.pid, SIGKILL)
    var status: Int32 = 0
    while waitpid(process.pid, &status, 0) < 0 {
        if errno == EINTR {
            continue
        }
        break
    }
}

func reapDiagnosticProcess(_ pid: pid_t) throws -> Int32 {
    var status: Int32 = 0
    while waitpid(pid, &status, 0) < 0 {
        if errno != EINTR {
            throw CodexRuntimeDiagnosticError.invalidProtocol
        }
    }
    return status
}

func normalizedDiagnosticExitStatus(_ waitStatus: Int32) -> Int32 {
    if waitStatus & 0x7F == 0 {
        return (waitStatus >> 8) & 0xFF
    }
    return 128 + (waitStatus & 0x7F)
}

private func createDiagnosticPipe() throws -> (read: Int32, write: Int32) {
    var descriptors = [Int32](repeating: -1, count: 2)
    guard pipe(&descriptors) == 0 else {
        throw CodexRuntimeDiagnosticError.processFailed(
            reasonKey: "runtime.process.launchFailed"
        )
    }
    var readDescriptor = descriptors[0]
    var writeDescriptor = descriptors[1]
    do {
        readDescriptor = try diagnosticDescriptorAboveStandardIO(
            readDescriptor
        )
        writeDescriptor = try diagnosticDescriptorAboveStandardIO(
            writeDescriptor
        )
        return (readDescriptor, writeDescriptor)
    } catch {
        close(readDescriptor)
        close(writeDescriptor)
        throw error
    }
}

private func diagnosticDescriptorAboveStandardIO(
    _ descriptor: Int32
) throws -> Int32 {
    if descriptor > STDERR_FILENO {
        guard fcntl(descriptor, F_SETFD, FD_CLOEXEC) == 0 else {
            throw CodexRuntimeDiagnosticError.processFailed(
                reasonKey: "runtime.process.launchFailed"
            )
        }
        return descriptor
    }
    let moved = fcntl(
        descriptor,
        F_DUPFD_CLOEXEC,
        STDERR_FILENO + 1
    )
    guard moved >= 0 else {
        throw CodexRuntimeDiagnosticError.processFailed(
            reasonKey: "runtime.process.launchFailed"
        )
    }
    close(descriptor)
    return moved
}

private func addDiagnosticDup(
    _ descriptor: Int32,
    to target: Int32,
    actions: inout posix_spawn_file_actions_t?
) throws {
    guard
        posix_spawn_file_actions_adddup2(
            &actions,
            descriptor,
            target
        ) == 0
    else {
        throw CodexRuntimeDiagnosticError.processFailed(
            reasonKey: "runtime.process.launchFailed"
        )
    }
}

private func addDiagnosticClose(
    _ descriptor: Int32,
    actions: inout posix_spawn_file_actions_t?
) throws {
    guard posix_spawn_file_actions_addclose(&actions, descriptor) == 0 else {
        throw CodexRuntimeDiagnosticError.processFailed(
            reasonKey: "runtime.process.launchFailed"
        )
    }
}

private func withDiagnosticCStringArray<Result>(
    _ strings: [String],
    body: (
        UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
    ) throws -> Result
) throws -> Result {
    guard strings.allSatisfy({ !$0.utf8.contains(0) }) else {
        throw CodexRuntimeDiagnosticError.invalidProtocol
    }
    var storage: [UnsafeMutablePointer<CChar>?] = []
    defer {
        for pointer in storage {
            free(pointer)
        }
    }
    for string in strings {
        guard let pointer = strdup(string) else {
            throw CodexRuntimeDiagnosticError.processFailed(
                reasonKey: "runtime.process.launchFailed"
            )
        }
        storage.append(pointer)
    }
    storage.append(nil)
    return try storage.withUnsafeMutableBufferPointer { buffer in
        try body(buffer.baseAddress!)
    }
}

private final class LockedDiagnosticOutput: @unchecked Sendable {
    private let lock = NSLock()
    private let limit: Int
    private var storage = Data()
    private var truncated = false
    private var failed = false

    init(limit: Int) {
        self.limit = limit
    }

    var data: Data {
        lock.withLock { storage }
    }

    var wasTruncated: Bool {
        lock.withLock { truncated }
    }

    var readFailed: Bool {
        lock.withLock { failed }
    }

    func drain(_ handle: FileHandle) {
        while true {
            do {
                guard
                    let chunk = try handle.read(upToCount: 4_096),
                    !chunk.isEmpty
                else {
                    return
                }
                lock.withLock {
                    let remaining = max(0, limit - storage.count)
                    if remaining > 0 {
                        storage.append(chunk.prefix(remaining))
                    }
                    if chunk.count > remaining {
                        truncated = true
                    }
                }
            } catch {
                lock.withLock { failed = true }
                return
            }
        }
    }
}

private final class BoundedJSONLineReader {
    private let descriptor: Int32
    private let byteLimit: Int
    private var buffer = Data()
    private var totalBytes = 0

    init(descriptor: Int32, byteLimit: Int) {
        self.descriptor = descriptor
        self.byteLimit = byteLimit
    }

    func nextObject(
        deadline: Date
    ) throws -> [String: Any] {
        while true {
            if let newline = buffer.firstIndex(of: 0x0A) {
                let line = buffer[..<newline]
                buffer.removeSubrange(...newline)
                guard
                    !line.isEmpty,
                    let object = try JSONSerialization.jsonObject(
                        with: Data(line)
                    ) as? [String: Any]
                else {
                    throw CodexRuntimeDiagnosticError.invalidProtocol
                }
                return object
            }
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else {
                throw CodexRuntimeDiagnosticError.timedOut
            }
            var pollDescriptor = pollfd(
                fd: descriptor,
                events: Int16(POLLIN),
                revents: 0
            )
            let timeout = Int32(
                min(
                    max(1, Int(remaining * 1_000)),
                    Int(Int32.max)
                )
            )
            let result = poll(&pollDescriptor, 1, timeout)
            if result == 0 {
                throw CodexRuntimeDiagnosticError.timedOut
            }
            if result < 0 {
                if errno == EINTR { continue }
                throw CodexRuntimeDiagnosticError.invalidProtocol
            }
            var bytes = [UInt8](repeating: 0, count: 4_096)
            let count = read(descriptor, &bytes, bytes.count)
            guard count > 0 else {
                throw CodexRuntimeDiagnosticError.invalidProtocol
            }
            totalBytes += count
            guard totalBytes <= byteLimit else {
                throw CodexRuntimeDiagnosticError.outputLimitExceeded
            }
            buffer.append(contentsOf: bytes.prefix(count))
        }
    }
}

private func sanitizedEnvironment(
    _ environment: [String: String]
) -> [String: String] {
    let allowedKeys = Set([
        "LANG",
        "LC_ALL",
        "LC_CTYPE",
        "PATH",
        "TERM",
    ])
    var sanitized = environment.filter {
        allowedKeys.contains($0.key)
    }
    if let path = sanitized["PATH"] {
        var seen = Set<String>()
        let entries = path
            .split(separator: ":", omittingEmptySubsequences: true)
            .prefix(CodexLocator.defaultMaximumPATHEntries)
            .map(String.init)
            .filter { $0.hasPrefix("/") }
            .filter { seen.insert($0).inserted }
        sanitized["PATH"] = entries.joined(separator: ":")
    }
    return sanitized
}

private func isRegularFile(_ url: URL) -> Bool {
    (try? url.resourceValues(
        forKeys: [.isRegularFileKey]
    ).isRegularFile) == true
}

private func isOwnerOnlyDirectory(_ url: URL) -> Bool {
    var information = stat()
    let result = url.withUnsafeFileSystemRepresentation { path in
        guard let path else { return Int32(EINVAL) }
        return lstat(path, &information)
    }
    guard result == 0 else { return false }
    return information.st_mode & S_IFMT == S_IFDIR
        && information.st_uid == geteuid()
        && information.st_mode & 0o077 == 0
}

private func directoryIsEmpty(_ url: URL) -> Bool {
    guard
        let contents = try? FileManager.default.contentsOfDirectory(
            atPath: url.path
        )
    else {
        return false
    }
    return contents.isEmpty
}

private func directoriesAreDisjoint(_ urls: [URL]) -> Bool {
    for index in urls.indices {
        for otherIndex in urls.indices where index < otherIndex {
            let left = urls[index].pathComponents
            let right = urls[otherIndex].pathComponents
            let common = zip(left, right).prefix {
                $0.0 == $0.1
            }.count
            if common == left.count || common == right.count {
                return false
            }
        }
    }
    return true
}

private func globalInstructionsAreAbsent(in home: URL) -> Bool {
    ["AGENTS.override.md", "AGENTS.md"].allSatisfy {
        !FileManager.default.fileExists(
            atPath: home.appending(path: $0).path
        )
    }
}

extension Duration {
    var dispatchDeadline: DispatchTime {
        guard self > .zero else { return .now() }
        let components = self.components
        let seconds = components.seconds.multipliedReportingOverflow(
            by: 1_000_000_000
        )
        guard !seconds.overflow else {
            return .distantFuture
        }
        let fractional = components.attoseconds / 1_000_000_000
        let total = seconds.partialValue.addingReportingOverflow(
            fractional
        )
        guard !total.overflow else {
            return .distantFuture
        }
        return .now() + .nanoseconds(Int(clamping: total.partialValue))
    }
}
