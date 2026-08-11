import Foundation
import Testing
@testable import StornautCodex

@Suite("Capability-first runtime profile")
struct CodexRuntimeProfileTests {
    private let profile = CodexRuntimeProfile.capabilityFirstV1Codex0147

    @Test
    func execArgumentsMatchTheClosedProfile() throws {
        let schemaURL = URL(filePath: "/private/tmp/stornaut/schema.json")
        let workingDirectoryURL = URL(
            filePath: "/private/tmp/stornaut/work",
            directoryHint: .isDirectory
        )

        let arguments = try profile.execArguments(
            schemaURL: schemaURL,
            workingDirectoryURL: workingDirectoryURL
        )

        #expect(arguments == [
            "--strict-config",
            "--ask-for-approval",
            "never",
            "--search",
            "-c",
            "default_permissions=\"stornaut-capability-first-v1\"",
            "-c",
            "permissions.stornaut-capability-first-v1.extends=\":read-only\"",
            "-c",
            "permissions.stornaut-capability-first-v1.network.enabled=true",
            "-c",
            "permissions.stornaut-capability-first-v1.network.mode=\"full\"",
            "-c",
            "permissions.stornaut-capability-first-v1.network.allow_local_binding=false",
            "-c",
            "permissions.stornaut-capability-first-v1.network.dangerously_allow_non_loopback_proxy=false",
            "-c",
            "permissions.stornaut-capability-first-v1.network.dangerously_allow_all_unix_sockets=false",
            "-c",
            "features.network_proxy.enabled=true",
            "-c",
            "features.network_proxy.mode=\"full\"",
            "-c",
            "features.network_proxy.allow_local_binding=false",
            "-c",
            "features.network_proxy.dangerously_allow_non_loopback_proxy=false",
            "-c",
            "features.network_proxy.dangerously_allow_all_unix_sockets=false",
            "-c",
            "features.network_proxy.domains={ \"*\" = \"allow\" }",
            "-c",
            "tools.web_search.context_size=\"high\"",
            "-c",
            "project_doc_max_bytes=0",
            "-c",
            "skills.include_instructions=true",
            "-c",
            "skills.bundled.enabled=false",
            "-c",
            "features.shell_tool=true",
            "-c",
            "features.unified_exec=true",
            "-c",
            "features.multi_agent=true",
            "-c",
            "features.image_generation=false",
            "-c",
            "features.apps=false",
            "-c",
            "features.plugins=false",
            "-c",
            "features.remote_plugin=false",
            "-c",
            "features.plugin_sharing=false",
            "-c",
            "features.computer_use=false",
            "-c",
            "orchestrator.skills.enabled=false",
            "-c",
            "orchestrator.mcp.enabled=false",
            "-c",
            "analytics.enabled=false",
            "-c",
            "otel.metrics_exporter=\"none\"",
            "exec",
            "--ephemeral",
            "--json",
            "--output-schema",
            schemaURL.path,
            "--ignore-user-config",
            "--ignore-rules",
            "--skip-git-repo-check",
            "-C",
            workingDirectoryURL.path,
            "-",
        ])
    }

    @Test
    func preferredModelIsAClosedRootOption() throws {
        let arguments = try profile.execArguments(
            schemaURL: URL(filePath: "/private/tmp/schema.json"),
            workingDirectoryURL: URL(
                filePath: "/private/tmp/work",
                directoryHint: .isDirectory
            ),
            model: .gpt56Luna
        )

        let execIndex = try #require(arguments.firstIndex(of: "exec"))
        let modelIndex = try #require(arguments.firstIndex(of: "--model"))

        #expect(arguments[modelIndex + 1] == "gpt-5.6-luna")
        #expect(modelIndex < execIndex)
        #expect(arguments.filter { $0 == "--model" }.count == 1)
    }

    @Test
    func profileKeepsRequiredAndDisabledSurfacesClosed() {
        let overrides = profile.orderedConfigOverrides

        #expect(overrides.contains("features.shell_tool=true"))
        #expect(overrides.contains("features.unified_exec=true"))
        #expect(overrides.contains("features.multi_agent=true"))
        #expect(overrides.contains("features.network_proxy.enabled=true"))
        #expect(overrides.contains("features.network_proxy.domains={ \"*\" = \"allow\" }"))
        #expect(overrides.contains("features.plugins=false"))
        #expect(overrides.contains("features.remote_plugin=false"))
        #expect(overrides.contains("features.plugin_sharing=false"))
        #expect(overrides.contains("features.apps=false"))
        #expect(overrides.contains("features.computer_use=false"))
        #expect(overrides.contains("orchestrator.skills.enabled=false"))
        #expect(overrides.contains("orchestrator.mcp.enabled=false"))
        #expect(!overrides.contains("features.hooks=false"))
        #expect(!overrides.contains(where: { $0.contains("allowed_domains") }))
        #expect(!overrides.contains(where: { $0.contains("proxy_url") }))
        #expect(!overrides.contains(where: {
            $0.contains(".network.unix_sockets=")
                || $0.contains(".network.unix_sockets.")
        }))
    }

    @Test
    func profileHasOneStableSecretFreeDigest() {
        #expect(profile.identifier.rawValue == "capability-first-v1-codex-0.147")
        #expect(profile.schemaVersion == 1)
        #expect(profile.profileDigest.count == 64)
        #expect(profile.profileDigest == CodexRuntimeProfile.capabilityFirstV1Codex0147.profileDigest)
        #expect(!profile.diagnosticSummary.contains("/Users/"))
        #expect(!profile.diagnosticSummary.localizedCaseInsensitiveContains("token"))
    }

    @Test
    func compatibilityIsPinnedToCodex0147() {
        #expect(profile.isCompatible(versionOutput: "codex-cli 0.147.0\n"))
        #expect(!profile.isCompatible(versionOutput: "codex-cli 0.147.9"))
        #expect(!profile.isCompatible(versionOutput: "codex-cli 0.146.0"))
        #expect(!profile.isCompatible(versionOutput: "codex-cli 0.148.0"))
        #expect(!profile.isCompatible(versionOutput: "unexpected"))
    }

    @Test
    func argumentsRejectRelativeAndInjectedPaths() {
        #expect(throws: CodexRuntimeProfileError.self) {
            _ = try profile.execArguments(
                schemaURL: URL(string: "schema.json")!,
                workingDirectoryURL: URL(
                    filePath: "/private/tmp/work",
                    directoryHint: .isDirectory
                )
            )
        }
        #expect(throws: CodexRuntimeProfileError.self) {
            _ = try profile.execArguments(
                schemaURL: URL(filePath: "/private/tmp/schema.json"),
                workingDirectoryURL: URL(string: "work")!
            )
        }
        #expect(throws: CodexRuntimeProfileError.self) {
            _ = try profile.execArguments(
                schemaURL: URL(filePath: "/private/tmp/schema\n.json"),
                workingDirectoryURL: URL(
                    filePath: "/private/tmp/work",
                    directoryHint: .isDirectory
                )
            )
        }
    }
}
