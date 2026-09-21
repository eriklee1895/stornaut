import Foundation
import Testing
@testable import StornautCodex

@Test(
    .enabled(
        if: ProcessInfo.processInfo.environment[
            "STORNAUT_RUN_R3_APP_SERVER_DIAGNOSTIC"
        ] == "1",
        """
        Opt in to the R3 external-auth App Server diagnostic using \
        gpt-5.6-luna and synthetic input only
        """
    )
)
func realCodexR3ExternalAuthAppServerDiagnostic() async throws {
    let inherited = ProcessInfo.processInfo.environment
    let normalHome = FileManager.default.homeDirectoryForCurrentUser
    var processEnvironment = [
        "HOME": normalHome.path,
        "PATH":
            "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
        "TERM": inherited["TERM"] ?? "dumb",
    ]
    for key in ["LANG", "LC_ALL", "LC_CTYPE"] {
        if let value = inherited[key], !value.isEmpty {
            processEnvironment[key] = value
        }
    }
    for key in ["SSL_CERT_FILE", "SSL_CERT_DIR"] {
        if let value = inherited[key], !value.isEmpty {
            processEnvironment[key] = value
        }
    }
    let installation = try #require(
        await CodexLocator().locate(
            configuredURL: nil,
            environment: processEnvironment
        ).installation
    )
    #expect(
        CodexRuntimeProfile.capabilityFirstV1Codex0147.isCompatible(
            versionOutput: try codexVersion(
                executableURL: installation.executableURL
            )
        )
    )

    let parent = FileManager.default.temporaryDirectory.appending(
        path: "stornaut-r3-app-server-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: parent,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    defer { try? FileManager.default.removeItem(at: parent) }

    let normalCodexHome = normalHome.appending(
        path: ".codex",
        directoryHint: .isDirectory
    )
    let authSourceURL = normalCodexHome.appending(
        path: "auth.json"
    )
    let workspace = try CodexRuntimeWorkspace.create(
        under: parent,
        forbiddenRoots: [
            normalHome,
            normalCodexHome,
        ]
    )
    let policy = CodexContainmentPolicy()
    let configuration = try policy.configuration(
        workspace: workspace.paths,
        projectedAuthSourceURL: authSourceURL
    )
    _ = try policy.install(configuration, in: workspace.paths)
    let environment = try CodexRuntimeEnvironmentPolicy().project(
        inherited: processEnvironment,
        workspace: workspace.paths,
        forbiddenHomeURL: normalHome
    )
    let projector = CodexRuntimeAuthProjector()
    let projection = try projector.read(from: authSourceURL)
    let outputSchema: JSONValue = .object([
        "additionalProperties": .bool(false),
        "properties": .object([
            "verdict": .object([
                "enum": .array([.string("passed")]),
                "type": .string("string"),
            ]),
        ]),
        "required": .array([.string("verdict")]),
        "type": .string("object"),
    ])
    let runtime = try CodexAppServerRuntime(
        request: CodexAppServerRuntimeRequest(
            projectedAuthSourceURL: authSourceURL,
            runtimeHomeURL: workspace.paths.runtimeURL,
            workingDirectoryURL: workspace.paths.workURL,
            prompt: """
            This is a synthetic Stornaut R3 external-auth protocol diagnostic.
            Do not inspect files, run tools, access localhost/private services,
            or change any local or remote state.
            Return exactly {"verdict":"passed"}.
            """,
            outputSchema: outputSchema
        ),
        authProjection: projection,
        refreshProvider: CodexRuntimeFileAuthRefreshProvider(
            sourceURL: authSourceURL,
            sourceIdentity: projection.sourceIdentity,
            projector: projector
        )
    )
    let result = try await CodexAppServerSessionRunner().run(
        CodexAppServerSessionRequest(
            executableURL: installation.executableURL,
            workspace: workspace.paths,
            projectedAuthSourceURL: authSourceURL,
            containmentConfiguration: configuration,
            environment: environment,
            runtime: runtime,
            timeout: .seconds(120),
            standardOutputByteLimit: 2 * 1_024 * 1_024,
            standardErrorByteLimit: 256 * 1_024,
            lineByteLimit: 512 * 1_024
        )
    )

    let finalMessage = try #require(
        result.observation.finalAgentMessage
    )
    #expect(
        try JSONDecoder().decode(
            JSONValue.self,
            from: Data(finalMessage.utf8)
        ) == .object(["verdict": .string("passed")])
    )
    #expect(result.observation.itemTypes.contains("agentMessage"))
    #expect(
        result.observation.notificationMethods.contains(
            "turn/completed"
        )
    )
    #expect(
        !FileManager.default.fileExists(
            atPath: workspace.paths.runtimeURL.appending(
                path: "auth.json"
            ).path
        )
    )
    let runtimeContents = try FileManager.default.contentsOfDirectory(
        atPath: workspace.paths.runtimeURL.path
    )
    #expect(!runtimeContents.contains("auth.json"))
    print("r3.app_server.external_auth=observed")
    print("r3.app_server.model=gpt-5.6-luna")
    print("r3.app_server.profile_digest=\(configuration.digest)")
    print(
        "r3.app_server.notification_categories="
            + result.observation.notificationMethods.joined(separator: ",")
    )
    print(
        "r3.app_server.item_types="
            + result.observation.itemTypes.joined(separator: ",")
    )
    print("r3.app_server.runtime_auth_file=absent")
    print("r3.app_server.verdict=behaviorReadyCandidate")
    try workspace.remove()
}

private func codexVersion(executableURL: URL) throws -> String {
    let process = Process()
    let output = Pipe()
    process.executableURL = executableURL
    process.arguments = ["--version"]
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw R3AppServerDiagnosticError.versionFailed
    }
    return String(
        decoding: output.fileHandleForReading.readDataToEndOfFile(),
        as: UTF8.self
    )
}

private enum R3AppServerDiagnosticError: Error {
    case versionFailed
}
