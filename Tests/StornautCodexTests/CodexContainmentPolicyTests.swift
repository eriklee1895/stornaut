import CryptoKit
import Darwin
import Foundation
import Testing
@testable import StornautCodex

@Suite("Codex outer containment policy")
struct CodexContainmentPolicyTests {
    private let policy = CodexContainmentPolicy()
    private let workspace = CodexRuntimeWorkspacePaths(
        rootURL: URL(filePath: "/private/tmp/stornaut"),
        homeURL: URL(filePath: "/private/tmp/stornaut/home"),
        runtimeURL: URL(filePath: "/private/tmp/stornaut/runtime"),
        workURL: URL(filePath: "/private/tmp/stornaut/work"),
        schemaURL: URL(filePath: "/private/tmp/stornaut/schema"),
        fixturesURL: URL(filePath: "/private/tmp/stornaut/fixtures")
    )

    @Test
    func rendersExactSecretFreeConfigurationAndDigest() throws {
        let configuration = try policy.configuration(
            workspace: workspace,
            projectedAuthSourceURL: URL(
                filePath: "/Users/example/.codex/auth.json"
            )
        )
        let expected = """
        default_permissions = "stornaut-outer-v1"
        cli_auth_credentials_store = "ephemeral"
        permissions.stornaut-outer-v1.extends = ":read-only"
        permissions.stornaut-outer-v1.filesystem."/Users/example/.codex/auth.json" = "deny"
        permissions.stornaut-outer-v1.filesystem."/private/tmp/stornaut/runtime" = "write"
        permissions.stornaut-outer-v1.network.enabled = true
        permissions.stornaut-outer-v1.network.mode = "full"
        permissions.stornaut-outer-v1.network.enable_socks5 = false
        permissions.stornaut-outer-v1.network.allow_local_binding = false
        permissions.stornaut-outer-v1.network.dangerously_allow_non_loopback_proxy = false
        permissions.stornaut-outer-v1.network.dangerously_allow_all_unix_sockets = false
        permissions.stornaut-outer-v1.network.domains = { "*" = "allow" }
        features.network_proxy.enabled = true
        features.network_proxy.mode = "full"
        features.network_proxy.enable_socks5 = false
        features.network_proxy.allow_local_binding = false
        features.network_proxy.dangerously_allow_non_loopback_proxy = false
        features.network_proxy.dangerously_allow_all_unix_sockets = false
        features.network_proxy.domains = { "*" = "allow" }
        tools.web_search.context_size = "high"
        project_doc_max_bytes = 0
        skills.include_instructions = true
        skills.bundled.enabled = false
        features.shell_tool = true
        features.unified_exec = true
        features.multi_agent = true
        features.image_generation = false
        features.apps = false
        features.plugins = false
        features.remote_plugin = false
        features.plugin_sharing = false
        features.computer_use = false
        orchestrator.skills.enabled = false
        orchestrator.mcp.enabled = false
        analytics.enabled = false
        otel.metrics_exporter = "none"

        """
        let expectedData = Data(expected.utf8)
        let expectedDigest = SHA256.hash(data: expectedData)
            .map { String(format: "%02x", $0) }
            .joined()

        #expect(configuration.data == expectedData)
        #expect(configuration.digest == expectedDigest)
        #expect(
            try policy.configuration(
                workspace: workspace,
                projectedAuthSourceURL: URL(
                    filePath: "/Users/example/.codex/auth.json"
                )
            ) == configuration
        )
        #expect(!configuration.description.contains("/Users/example"))
    }

    @Test
    func launchArgumentsAreClosedToOuterSandboxAndAppServer() throws {
        let arguments = try policy.launchArguments(
            codexExecutableURL: URL(filePath: "/opt/stornaut/codex"),
            workspace: workspace
        )

        #expect(arguments == [
            "sandbox",
            "-P",
            "stornaut-outer-v1",
            "-C",
            "/private/tmp/stornaut/work",
            "--",
            "/opt/stornaut/codex",
            "--strict-config",
            "--disable",
            "network_proxy",
            "app-server",
            "--stdio",
        ])
        #expect(!arguments.contains("exec"))
        #expect(!arguments.contains("mcp-server"))
        #expect(!arguments.contains("danger-full-access"))
    }

    @Test
    func installsConfigurationExclusivelyWithOwnerOnlyMode() throws {
        let parent = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-policy-tests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: parent,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? FileManager.default.removeItem(at: parent) }
        let liveWorkspace = try CodexRuntimeWorkspace.create(
            under: parent,
            forbiddenRoots: []
        )
        let configuration = try policy.configuration(
            workspace: liveWorkspace.paths,
            projectedAuthSourceURL: URL(
                filePath: "/Users/example/.codex/auth.json"
            )
        )

        let installedURL = try policy.install(
            configuration,
            in: liveWorkspace.paths
        )

        #expect(installedURL == liveWorkspace.paths.runtimeURL.appending(
            path: "config.toml"
        ))
        #expect(containmentFileMode(installedURL) == 0o600)
        #expect(try Data(contentsOf: installedURL) == configuration.data)
        #expect(throws: CodexContainmentPolicyError.self) {
            _ = try policy.install(
                configuration,
                in: liveWorkspace.paths
            )
        }
        try liveWorkspace.remove()
    }

    @Test
    func configurationContainsNoForbiddenAuthoritySurface() throws {
        let configuration = try policy.configuration(
            workspace: workspace,
            projectedAuthSourceURL: URL(
                filePath: "/Users/example/.codex/auth.json"
            )
        )
        let text = String(decoding: configuration.data, as: UTF8.self)

        for required in [
            "extends = \":read-only\"",
            "enable_socks5 = false",
            "allow_local_binding = false",
            "dangerously_allow_non_loopback_proxy = false",
            "dangerously_allow_all_unix_sockets = false",
            "domains = { \"*\" = \"allow\" }",
        ] {
            #expect(text.contains(required))
        }
        for forbidden in [
            "danger-full-access",
            "proxy_url",
            "http_headers",
            ".network.unix_sockets =",
            ".network.unix_sockets.",
            "allowed_domains",
            "OPENAI_API_KEY",
            "GITHUB_TOKEN",
            "MoveToTrash",
            "RegisteredAction",
            "Executor",
        ] {
            #expect(!text.contains(forbidden))
        }
        #expect(
            text.components(
                separatedBy: "enable_socks5 = false"
            ).count == 3
        )
    }

    @Test
    func rejectsOverlapsUnsafePathsAndExecutableInjection() {
        #expect(throws: CodexContainmentPolicyError.self) {
            _ = try policy.configuration(
                workspace: workspace,
                projectedAuthSourceURL: workspace.runtimeURL.appending(
                    path: "auth.json"
                )
            )
        }
        #expect(throws: CodexContainmentPolicyError.self) {
            _ = try policy.configuration(
                workspace: workspace,
                projectedAuthSourceURL: URL(
                    filePath: "/Users/example/.codex/auth\"\n.json"
                )
            )
        }
        #expect(throws: CodexContainmentPolicyError.self) {
            _ = try policy.launchArguments(
                codexExecutableURL: URL(string: "codex")!,
                workspace: workspace
            )
        }
    }
}

private func containmentFileMode(_ url: URL) -> mode_t {
    var information = stat()
    guard lstat(url.path, &information) == 0 else { return 0 }
    return information.st_mode & 0o777
}
