import Darwin
import Foundation
import Testing
@testable import StornautCodex

@Test(
    .enabled(
        if: ProcessInfo.processInfo.environment[
            "STORNAUT_RUN_PROVIDER_CATALOG_PREFLIGHT"
        ] == "1",
        """
        Opt in to the no-auth, no-thread, no-model provider/catalog preflight
        """
    )
)
func installedCodexProviderCatalogPreflight() async throws {
    let processEnvironment = ProcessInfo.processInfo.environment
    let normalHome = FileManager.default.homeDirectoryForCurrentUser
    var inherited = [
        "HOME": normalHome.path,
        "PATH":
            "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
        "TERM": processEnvironment["TERM"] ?? "dumb",
    ]
    for key in ["LANG", "LC_ALL", "LC_CTYPE"] {
        if let value = processEnvironment[key], !value.isEmpty {
            inherited[key] = value
        }
    }
    for key in ["SSL_CERT_FILE", "SSL_CERT_DIR"] {
        if let value = processEnvironment[key], !value.isEmpty {
            inherited[key] = value
        }
    }
    let installation = try #require(
        await CodexLocator().locate(
            configuredURL: nil,
            environment: inherited
        ).installation
    )
    let installedPackage =
        try syntheticDiagnosticCodexPackage(
            installation: installation
        )
    let parent = URL(
        filePath: "/Library/Caches",
        directoryHint: .isDirectory
    ).appending(
        path: "stornaut-provider-preflight-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: parent,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    defer { try? FileManager.default.removeItem(at: parent) }

    let authSourceURL = normalHome.appending(
        path: ".codex/auth.json"
    )
    let workspace = try CodexRuntimeWorkspace.create(
        under: parent,
        forbiddenRoots: [normalHome]
    )
    let stagedPackage =
        try stageSyntheticDiagnosticCodexPackage(
            source: installedPackage,
            workspace: workspace.paths
        )
    let stagedCodexExecutableURL = stagedPackage.executableURL
    let policy = CodexContainmentPolicy()
    let readCanaryURL = workspace.paths.workURL.appending(
        path: "synthetic-read-canary.txt"
    )
    let deniedReadCanaryURL = workspace.paths.fixturesURL.appending(
        path: "synthetic-denied-read-canary.txt"
    )
    try Data("synthetic-read-canary\n".utf8).write(to: readCanaryURL)
    try Data("synthetic-denied-read-canary\n".utf8).write(
        to: deniedReadCanaryURL
    )
    chmod(readCanaryURL.path, 0o400)
    chmod(deniedReadCanaryURL.path, 0o400)
    let readScope = try syntheticDiagnosticReadScope(
        privateRootURL: normalHome,
        syntheticDeniedReadURL: deniedReadCanaryURL
    )
    let configuration = try policy.configuration(
        workspace: workspace.paths,
        projectedAuthSourceURL: authSourceURL,
        readScope: readScope
    )
    _ = try policy.install(configuration, in: workspace.paths)
    let environment = try CodexRuntimeEnvironmentPolicy().project(
        inherited: inherited,
        workspace: workspace.paths,
        forbiddenHomeURL: normalHome
    )
    try await runSyntheticDiagnosticPrivacyProbe(
        outerExecutableURL: installation.executableURL,
        probeExecutableURL: stagedCodexExecutableURL,
        workspace: workspace.paths,
        deniedURL: deniedReadCanaryURL,
        readableURL: readCanaryURL,
        configuration: configuration,
        environment: environment
    )
    let runtime = try CodexProviderCatalogPreflightRuntime(
        request: CodexProviderCatalogPreflightRequest(
            runtimeHomeURL: workspace.paths.runtimeURL,
            workingDirectoryURL: workspace.paths.workURL,
            targetModel: .gpt56Luna
        )
    )

    let result = try await CodexAppServerSessionRunner()
        .runProviderCatalogPreflight(
            CodexProviderCatalogPreflightSessionRequest(
                executableURL: installation.executableURL,
                appServerExecutableURL: stagedCodexExecutableURL,
                workspace: workspace.paths,
                deniedAuthSourceURL: authSourceURL,
                containmentConfiguration: configuration,
                environment: environment,
                runtime: runtime,
                timeout: .seconds(30),
                standardOutputByteLimit: 2 * 1_024 * 1_024,
                standardErrorByteLimit: 256 * 1_024,
                lineByteLimit: 512 * 1_024
            )
        )

    #expect(!result.report.effectiveProviderID.isEmpty)
    #expect(result.report.targetModelID == "gpt-5.6-luna")
    #expect(result.report.catalogModelCount <= 1_000)
    #expect(result.standardErrorByteCount <= 256 * 1_024)
    #expect(
        !FileManager.default.fileExists(
            atPath: workspace.paths.runtimeURL.appending(
                path: "auth.json"
            ).path
        )
    )

    print(
        "provider_preflight.effective_provider="
            + result.report.effectiveProviderID
    )
    print(
        "provider_preflight.provider_selection="
            + result.report.providerSelectionSource.rawValue
    )
    print(
        "provider_preflight.configured_model="
            + (result.report.configuredModelID ?? "none")
    )
    print(
        "provider_preflight.target_model="
            + result.report.targetModelID
    )
    print(
        "provider_preflight.target_advertised="
            + String(result.report.targetModelAdvertised)
    )
    print(
        "provider_preflight.catalog_count="
            + String(result.report.catalogModelCount)
    )
    print(
        "provider_preflight.default_model="
            + (result.report.defaultModelID ?? "none")
    )
    print(
        "provider_preflight.web_search="
            + String(result.report.capabilities.webSearch)
    )
    print(
        "provider_preflight.image_generation="
            + String(result.report.capabilities.imageGeneration)
    )
    print(
        "provider_preflight.namespace_tools="
            + String(result.report.capabilities.namespaceTools)
    )
    print("provider_preflight.auth_file=absent")
    print("provider_preflight.private_home=denied")
    print("provider_preflight.synthetic_read=allowed")
    print("provider_preflight.login=not-invoked")
    print("provider_preflight.thread=not-started")
    print("provider_preflight.turn=not-started")

    try workspace.remove()
}
