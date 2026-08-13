import Darwin
import Foundation
import Testing
@testable import StornautCodex

@Suite("Codex App Server session runner", .serialized)
struct CodexAppServerSessionRunnerTests {
    @Test
    func runsProviderCatalogPreflightWithoutAuthOrTurn() async throws {
        let fixture = try AppServerSessionFixture(
            mode: "provider-preflight"
        )
        defer { fixture.remove() }
        let request = try fixture.providerCatalogRequest()

        let result = try await CodexAppServerSessionRunner()
            .runProviderCatalogPreflight(request)

        #expect(
            result.report
                == CodexProviderCatalogPreflightReport(
                    effectiveProviderID: "openai",
                    providerSelectionSource: .explicitConfiguration,
                    configuredModelID: nil,
                    targetModelID: "gpt-5.6-luna",
                    targetModelAdvertised: false,
                    catalogModelCount: 2,
                    defaultModelID: "gpt-5.4",
                    capabilities:
                        CodexProviderCatalogCapabilities(
                            namespaceTools: false,
                            imageGeneration: false,
                            webSearch: true
                        )
                )
        )
        #expect(result.standardErrorByteCount == 0)
        let protocolLines = try fixture.recordedString(
            named: "provider-protocol.jsonl"
        )
        #expect(
            try fixture.recordedMethods(
                named: "provider-protocol.jsonl"
            ) == [
                "config/read",
                "modelProvider/capabilities/read",
                "model/list",
            ]
        )
        #expect(!protocolLines.contains("account/login"))
        #expect(!protocolLines.contains("thread/start"))
        #expect(!protocolLines.contains("turn/start"))
        #expect(!protocolLines.contains("accessToken"))
        #expect(!protocolLines.contains("apiKey"))
    }

    @Test
    func runsNestedOuterSandboxSessionToCompletion() async throws {
        let fixture = try AppServerSessionFixture(mode: "success")
        defer { fixture.remove() }

        let result = try await CodexAppServerSessionRunner().run(
            fixture.request()
        )

        #expect(result.observation.itemTypes == ["agentMessage"])
        #expect(
            result.observation.finalAgentMessage
                == #"{"verdict":"passed"}"#
        )
        #expect(result.standardErrorByteCount == 0)
        #expect(
            try fixture.recordedLines(named: "outer-arguments.txt") == [
                "sandbox",
                "-P",
                "stornaut-outer-v1",
                "-C",
                fixture.workspace.paths.workURL.path,
                "--",
                "/usr/bin/env",
                "-u",
                "CODEX_SANDBOX",
                fixture.executableURL.path,
                "--strict-config",
                "--disable",
                "network_proxy",
                "app-server",
                "--stdio",
            ]
        )
        #expect(
            try fixture.recordedLines(named: "inner-arguments.txt") == [
                "--strict-config",
                "--disable",
                "network_proxy",
                "app-server",
                "--stdio",
            ]
        )
        #expect(
            !FileManager.default.fileExists(
                atPath: fixture.workspace.paths.runtimeURL
                    .appending(path: "auth.json").path
            )
        )
    }

    @Test
    func terminatesDaemonAfterProtocolCompletion() async throws {
        let fixture = try AppServerSessionFixture(
            mode: "success-daemon"
        )
        defer { fixture.remove() }
        let started = ContinuousClock.now

        let result = try await CodexAppServerSessionRunner().run(
            fixture.request(timeout: .seconds(3))
        )

        #expect(started.duration(to: .now) < .seconds(2))
        #expect(
            result.observation.finalAgentMessage
                == #"{"verdict":"passed"}"#
        )
        let parentPID = try fixture.recordedPID(named: "parent.pid")
        let childPID = try fixture.recordedPID(named: "child.pid")
        #expect(waitForSessionProcessExit(parentPID))
        #expect(waitForSessionProcessExit(childPID))
    }

    @Test
    func malformedProtocolFailsWithoutReturningSecretBearingOutput()
        async throws
    {
        let fixture = try AppServerSessionFixture(mode: "malformed")
        defer { fixture.remove() }

        await #expect(
            throws: CodexAppServerSessionError.protocolFailure(
                .identityMismatch(
                    reasonKey: "appServer.initialize.codexHome"
                )
            )
        ) {
            _ = try await CodexAppServerSessionRunner().run(
                fixture.request()
            )
        }
    }

    @Test
    func lineAndErrorLimitsFailClosed() async throws {
        let lineFixture = try AppServerSessionFixture(mode: "large-line")
        defer { lineFixture.remove() }
        await #expect(
            throws: CodexAppServerSessionError.outputLimitExceeded
        ) {
            _ = try await CodexAppServerSessionRunner().run(
                lineFixture.request(lineByteLimit: 256)
            )
        }

        let errorFixture = try AppServerSessionFixture(mode: "large-stderr")
        defer { errorFixture.remove() }
        await #expect(
            throws: CodexAppServerSessionError.errorLimitExceeded
        ) {
            _ = try await CodexAppServerSessionRunner().run(
                errorFixture.request(standardErrorByteLimit: 128)
            )
        }
    }

    @Test
    func timeoutKillsGrandchildHoldingPipes() async throws {
        let fixture = try AppServerSessionFixture(mode: "timeout")
        defer { fixture.remove() }
        let started = ContinuousClock.now

        await #expect(throws: CodexAppServerSessionError.timedOut) {
            _ = try await CodexAppServerSessionRunner().run(
                fixture.request(timeout: .seconds(3))
            )
        }
        #expect(started.duration(to: .now) < .seconds(5))

        let parentPID = try fixture.recordedPID(named: "parent.pid")
        let childPID = try fixture.recordedPID(named: "child.pid")
        #expect(waitForSessionProcessExit(parentPID))
        #expect(waitForSessionProcessExit(childPID))
    }

    @Test
    func timeoutInterruptsBlockedInputWrite() async throws {
        let fixture = try AppServerSessionFixture(
            mode: "blocked-input",
            prompt: String(repeating: "p", count: 220 * 1_024)
        )
        defer { fixture.remove() }
        let started = ContinuousClock.now

        await #expect(throws: CodexAppServerSessionError.timedOut) {
            _ = try await CodexAppServerSessionRunner().run(
                fixture.request(timeout: .seconds(1))
            )
        }
        #expect(started.duration(to: .now) < .seconds(3))

        let parentPID = try fixture.recordedPID(named: "parent.pid")
        let childPID = try fixture.recordedPID(named: "child.pid")
        #expect(waitForSessionProcessExit(parentPID))
        #expect(waitForSessionProcessExit(childPID))
    }

    @Test
    func callerCancellationInterruptsBlockedInputWrite() async throws {
        let fixture = try AppServerSessionFixture(
            mode: "blocked-input",
            prompt: String(repeating: "p", count: 220 * 1_024)
        )
        defer { fixture.remove() }
        let task = Task {
            try await CodexAppServerSessionRunner().run(
                fixture.request(timeout: .seconds(30))
            )
        }
        _ = try fixture.waitForRecord(named: "child.pid")
        let started = ContinuousClock.now

        task.cancel()

        await #expect(throws: CodexAppServerSessionError.cancelled) {
            _ = try await task.value
        }
        #expect(started.duration(to: .now) < .seconds(2))
        let parentPID = try fixture.recordedPID(named: "parent.pid")
        let childPID = try fixture.recordedPID(named: "child.pid")
        #expect(waitForSessionProcessExit(parentPID))
        #expect(waitForSessionProcessExit(childPID))
    }

    @Test
    func callerCancellationKillsGrandchildHoldingPipes() async throws {
        let fixture = try AppServerSessionFixture(mode: "timeout")
        defer { fixture.remove() }
        let task = Task {
            try await CodexAppServerSessionRunner().run(
                fixture.request(timeout: .seconds(30))
            )
        }
        _ = try fixture.waitForRecord(named: "child.pid")

        task.cancel()

        await #expect(throws: CodexAppServerSessionError.cancelled) {
            _ = try await task.value
        }
        let parentPID = try fixture.recordedPID(named: "parent.pid")
        let childPID = try fixture.recordedPID(named: "child.pid")
        #expect(waitForSessionProcessExit(parentPID))
        #expect(waitForSessionProcessExit(childPID))
    }

    @Test
    func spawnDoesNotInheritUnmappedWritableDescriptor() async throws {
        let fixture = try AppServerSessionFixture(mode: "descriptor")
        defer { fixture.remove() }
        let descriptorTarget = fixture.root.appending(path: "descriptor.txt")
        try Data("original\n".utf8).write(to: descriptorTarget)
        let descriptor = open(descriptorTarget.path, O_RDWR)
        guard descriptor >= 0 else {
            throw AppServerSessionFixtureError.openFailed
        }
        defer { close(descriptor) }
        try Data("\(descriptor)\n".utf8).write(
            to: fixture.recordURL.appending(path: "descriptor-number.txt")
        )

        _ = try await CodexAppServerSessionRunner().run(
            fixture.request()
        )

        #expect(
            try fixture.recordedString(named: "descriptor-state.txt")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                == "closed"
        )
        #expect(
            try String(contentsOf: descriptorTarget, encoding: .utf8)
                == "original\n"
        )
    }

    @Test
    func eightConcurrentSessionsKeepPipesAndRuntimeHomesDisjoint()
        async throws
    {
        let fixtures = try (0..<8).map { _ in
            try AppServerSessionFixture(mode: "success")
        }
        defer {
            for fixture in fixtures {
                fixture.remove()
            }
        }

        let results = try await withThrowingTaskGroup(
            of: CodexAppServerSessionResult.self
        ) { group in
            for fixture in fixtures {
                group.addTask {
                    try await CodexAppServerSessionRunner().run(
                        fixture.request(timeout: .seconds(10))
                    )
                }
            }
            var collected: [CodexAppServerSessionResult] = []
            for try await result in group {
                collected.append(result)
            }
            return collected
        }

        #expect(results.count == fixtures.count)
        #expect(results.allSatisfy {
            $0.observation.finalAgentMessage
                == #"{"verdict":"passed"}"#
        })
        for fixture in fixtures {
            #expect(
                try fixture.recordedLines(named: "inner-arguments.txt")
                    == [
                        "--strict-config",
                        "--disable",
                        "network_proxy",
                        "app-server",
                        "--stdio",
                    ]
            )
        }
    }

    @Test
    func rejectsRuntimeConfigThatDriftsAfterValidation() async throws {
        let fixture = try AppServerSessionFixture(mode: "success")
        defer { fixture.remove() }
        try fixture.tamperConfiguration()

        await #expect(throws: CodexAppServerSessionError.invalidRequest) {
            _ = try await CodexAppServerSessionRunner().run(
                fixture.request()
            )
        }
        #expect(
            !FileManager.default.fileExists(
                atPath: fixture.recordURL.appending(
                    path: "parent.pid"
                ).path
            )
        )
    }
}

private struct AppServerSessionFixture {
    let root: URL
    let workspace: CodexRuntimeWorkspace
    let executableURL: URL
    let recordURL: URL
    let authSourceURL = URL(
        filePath: "/Users/example/.codex/auth.json"
    )
    let containmentConfiguration: CodexContainmentConfiguration
    let runtime: CodexAppServerRuntime
    let environment: CodexRuntimeEnvironment

    init(
        mode: String,
        prompt: String = "Inspect only synthetic fixtures."
    ) throws {
        root = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-app-server-session-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        workspace = try CodexRuntimeWorkspace.create(
            under: root,
            forbiddenRoots: []
        )
        executableURL = root.appending(path: "fake-codex")
        recordURL = workspace.paths.runtimeURL.appending(
            path: "fake-record",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: recordURL,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        let script = fakeAppServerScript(
            mode: mode,
            recordURL: recordURL
        )
        try Data(script.utf8).write(to: executableURL)
        chmod(executableURL.path, 0o700)

        containmentConfiguration = try CodexContainmentPolicy().configuration(
            workspace: workspace.paths,
            projectedAuthSourceURL: authSourceURL
        )
        _ = try CodexContainmentPolicy().install(
            containmentConfiguration,
            in: workspace.paths
        )
        environment = try CodexRuntimeEnvironmentPolicy().project(
            inherited: [
                "LANG": "en_US.UTF-8",
                "PATH": "/usr/bin:/bin",
            ],
            workspace: workspace.paths
        )
        runtime = try CodexAppServerRuntime(
            request: CodexAppServerRuntimeRequest(
                projectedAuthSourceURL: authSourceURL,
                runtimeHomeURL: workspace.paths.runtimeURL,
                workingDirectoryURL: workspace.paths.workURL,
                prompt: prompt,
                outputSchema: .object([
                    "additionalProperties": .bool(false),
                    "properties": .object([
                        "verdict": .object([
                            "type": .string("string"),
                        ]),
                    ]),
                    "required": .array([.string("verdict")]),
                    "type": .string("object"),
                ])
            ),
            authProjection: CodexRuntimeAuthProjection(
                sourceURL: authSourceURL,
                sourceIdentity: CodexRuntimeAuthSourceIdentity(
                    device: 1,
                    inode: 2,
                    ownerUserID: geteuid(),
                    mode: 0o600
                ),
                credentials: .chatGPT(
                    accessToken: "header.synthetic.signature",
                    accountID: "synthetic-account",
                    planType: nil
                )
            ),
            refreshProvider: nil
        )
    }

    func request(
        standardErrorByteLimit: Int = 4_096,
        lineByteLimit: Int = 64 * 1_024,
        timeout: Duration = .seconds(5)
    ) -> CodexAppServerSessionRequest {
        CodexAppServerSessionRequest(
            executableURL: executableURL,
            workspace: workspace.paths,
            projectedAuthSourceURL: authSourceURL,
            containmentConfiguration: containmentConfiguration,
            environment: environment,
            runtime: runtime,
            timeout: timeout,
            standardOutputByteLimit: 256 * 1_024,
            standardErrorByteLimit: standardErrorByteLimit,
            lineByteLimit: lineByteLimit
        )
    }

    func providerCatalogRequest()
        throws -> CodexProviderCatalogPreflightSessionRequest
    {
        CodexProviderCatalogPreflightSessionRequest(
            executableURL: executableURL,
            workspace: workspace.paths,
            deniedAuthSourceURL: authSourceURL,
            containmentConfiguration: containmentConfiguration,
            environment: environment,
            runtime: try CodexProviderCatalogPreflightRuntime(
                request: CodexProviderCatalogPreflightRequest(
                    runtimeHomeURL: workspace.paths.runtimeURL,
                    workingDirectoryURL: workspace.paths.workURL,
                    targetModel: .gpt56Luna
                )
            ),
            timeout: .seconds(5),
            standardOutputByteLimit: 256 * 1_024,
            standardErrorByteLimit: 4_096,
            lineByteLimit: 64 * 1_024
        )
    }

    func tamperConfiguration() throws {
        try Data("default_permissions = \":danger-full-access\"\n".utf8)
            .write(
                to: workspace.paths.runtimeURL.appending(
                    path: "config.toml"
                )
            )
        chmod(
            workspace.paths.runtimeURL.appending(path: "config.toml").path,
            0o600
        )
    }

    func recordedLines(named name: String) throws -> [String] {
        try recordedString(named: name)
        .split(separator: "\n")
        .map(String.init)
    }

    func recordedString(named name: String) throws -> String {
        try String(
            contentsOf: recordURL.appending(path: name),
            encoding: .utf8
        )
    }

    func recordedPID(named name: String) throws -> pid_t {
        let value = try recordedString(named: name)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let processID = pid_t(value) else {
            throw AppServerSessionFixtureError.invalidPID
        }
        return processID
    }

    func recordedMethods(named name: String) throws -> [String] {
        try recordedString(named: name)
            .split(separator: "\n")
            .map { line in
                let value = try JSONDecoder().decode(
                    JSONValue.self,
                    from: Data(line.utf8)
                )
                guard
                    case let .object(object) = value,
                    case let .string(method) = object["method"]
                else {
                    throw AppServerSessionFixtureError.invalidProtocol
                }
                return method
            }
    }

    func waitForRecord(named name: String) throws -> URL {
        let url = recordURL.appending(path: name)
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
            usleep(5_000)
        }
        throw AppServerSessionFixtureError.missingRecord
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

private func fakeAppServerScript(
    mode: String,
    recordURL: URL
) -> String {
    """
    #!/bin/zsh
    set -euo pipefail

    record_root=\(shellQuote(recordURL.path))
    mode=\(shellQuote(mode))

    if [[ "${1:-}" == "sandbox" ]]; then
        printf '%s\\n' "$@" > "$record_root/outer-arguments.txt"
        while (( $# > 0 )) && [[ "$1" != "--" ]]; do
            shift
        done
        [[ "${1:-}" == "--" ]]
        shift
        exec "$@"
    fi

    printf '%s\\n' "$@" > "$record_root/inner-arguments.txt"
    print -r -- "$$" > "$record_root/parent.pid"
    if [[ "$mode" == "timeout" ]]; then
        /bin/zsh -c 'trap "" INT TERM; /bin/sleep 30' &
        print -r -- "$!" > "$record_root/child.pid"
        /bin/sleep 30
        exit 0
    fi
    if [[ "$mode" == "descriptor" ]]; then
        descriptor=$(/bin/cat "$record_root/descriptor-number.txt")
        if /bin/zsh -c "print inherited >&${descriptor}" 2>/dev/null; then
            print -r -- inherited > "$record_root/descriptor-state.txt"
        else
            print -r -- closed > "$record_root/descriptor-state.txt"
        fi
    fi
    if [[ "$mode" == "large-stderr" ]]; then
        /usr/bin/python3 - <<'PY' >&2
    import sys
    sys.stderr.write("x" * 2048)
    PY
    fi
    IFS= read -r initialize
    if [[ "$mode" == "malformed" ]]; then
        print -r -- '{"id":1,"result":{"codexHome":7}}'
        exit 0
    fi
    if [[ "$mode" == "large-line" ]]; then
        /usr/bin/python3 - <<'PY'
    import json
    print(json.dumps({"method": "configWarning", "params": {"summary": "x" * 2048}}))
    PY
        /bin/sleep 30
        exit 0
    fi
    print -r -- '{"id":1,"result":{"codexHome":"\(workspaceRuntimePlaceholder)","platformFamily":"unix","platformOs":"macos","userAgent":"fake"}}'
    IFS= read -r initialized
    if [[ "$mode" == "provider-preflight" ]]; then
        : > "$record_root/provider-protocol.jsonl"
        IFS= read -r config_read
        print -r -- "$config_read" >> "$record_root/provider-protocol.jsonl"
        print -r -- '{"id":2,"result":{"config":{"model":null,"model_provider":"openai"},"layers":null,"origins":{}}}'
        IFS= read -r capabilities_read
        print -r -- "$capabilities_read" >> "$record_root/provider-protocol.jsonl"
        print -r -- '{"id":3,"result":{"imageGeneration":false,"namespaceTools":false,"webSearch":true}}'
        IFS= read -r model_list
        print -r -- "$model_list" >> "$record_root/provider-protocol.jsonl"
        print -r -- '{"id":4,"result":{"data":[{"id":"gpt-5.4","isDefault":true,"model":"gpt-5.4"},{"id":"gpt-5.3","isDefault":false,"model":"gpt-5.3"}],"nextCursor":null}}'
        while IFS= read -r unexpected; do
            print -r -- "$unexpected" >> "$record_root/provider-protocol.jsonl"
            exit 70
        done
        exit 0
    fi
    IFS= read -r login
    [[ "$login" == *'header.synthetic.signature'* ]]
    print -r -- '{"id":2,"result":{"type":"chatgptAuthTokens"}}'
    IFS= read -r thread
    print -r -- '{"id":3,"result":{"activePermissionProfile":{"id":"stornaut-outer-v1"},"approvalPolicy":"never","cwd":"\(workspaceWorkPlaceholder)","instructionSources":[],"model":"gpt-5.6-luna","modelProvider":"openai","thread":{"id":"thread-synthetic","modelProvider":"openai"}}}'
    if [[ "$mode" == "blocked-input" ]]; then
        /bin/zsh -c 'trap "" INT TERM; /bin/sleep 30' &
        print -r -- "$!" > "$record_root/child.pid"
        /bin/sleep 30
        exit 0
    fi
    IFS= read -r turn
    print -r -- '{"id":4,"result":{"turn":{"id":"turn-synthetic","items":[],"status":"inProgress"}}}'
    print -r -- '{"method":"thread/settings/updated","params":{"threadId":"thread-synthetic","threadSettings":{"approvalPolicy":"never","cwd":"\(workspaceWorkPlaceholder)","model":"gpt-5.6-luna","modelProvider":"openai","sandboxPolicy":{"networkAccess":"enabled","type":"externalSandbox"}}}}'
    print -r -- '{"method":"turn/started","params":{"threadId":"thread-synthetic","turn":{"id":"turn-synthetic","items":[],"status":"inProgress"}}}'
    print -r -- '{"method":"item/completed","params":{"item":{"id":"message-synthetic","text":"{\\"verdict\\":\\"passed\\"}","type":"agentMessage"},"threadId":"thread-synthetic","turnId":"turn-synthetic"}}'
    print -r -- '{"method":"turn/completed","params":{"threadId":"thread-synthetic","turn":{"id":"turn-synthetic","items":[],"status":"completed"}}}'
    if [[ "$mode" == "success-daemon" ]]; then
        /bin/zsh -c 'trap "" INT TERM; /bin/sleep 30' &
        print -r -- "$!" > "$record_root/child.pid"
        trap '' INT TERM
        /bin/sleep 30
        exit 0
    fi
    while IFS= read -r ignored; do
        :
    done
    """
    .replacingOccurrences(
        of: workspaceRuntimePlaceholder,
        with: recordURL.deletingLastPathComponent().path
    )
    .replacingOccurrences(
        of: workspaceWorkPlaceholder,
        with: recordURL.deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "work", directoryHint: .isDirectory).path
    )
}

private let workspaceRuntimePlaceholder = "__RUNTIME__"
private let workspaceWorkPlaceholder = "__WORK__"

private func shellQuote(_ value: String) -> String {
    "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
}

private func waitForSessionProcessExit(_ processID: pid_t) -> Bool {
    let deadline = Date().addingTimeInterval(2)
    while Date() < deadline {
        if kill(processID, 0) != 0, errno == ESRCH {
            return true
        }
        usleep(5_000)
    }
    return false
}

private enum AppServerSessionFixtureError: Error {
    case openFailed
    case invalidPID
    case missingRecord
    case invalidProtocol
}
