import CryptoKit
import Foundation

public struct CodexRuntimeProfileID: RawRepresentable, Sendable, Equatable, Hashable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public enum CodexRuntimeModel: String, Sendable, Equatable {
    case gpt56Luna = "gpt-5.6-luna"
}

public enum CodexRuntimeProfileError: Error, Sendable, Equatable {
    case invalidSchemaURL
    case invalidWorkingDirectoryURL
}

public struct CodexRuntimeProfile: Sendable, Equatable {
    public static let capabilityFirstV1Codex0147 = CodexRuntimeProfile(
        identifier: CodexRuntimeProfileID(
            rawValue: "capability-first-v1-codex-0.147"
        ),
        schemaVersion: 1,
        compatibleMajorVersion: 0,
        compatibleMinorVersion: 147,
        compatiblePatchVersion: 0,
        orderedConfigOverrides: [
            "default_permissions=\"stornaut-capability-first-v1\"",
            "permissions.stornaut-capability-first-v1.extends=\":read-only\"",
            "permissions.stornaut-capability-first-v1.network.enabled=true",
            "permissions.stornaut-capability-first-v1.network.mode=\"full\"",
            "permissions.stornaut-capability-first-v1.network.allow_local_binding=false",
            "permissions.stornaut-capability-first-v1.network.dangerously_allow_non_loopback_proxy=false",
            "permissions.stornaut-capability-first-v1.network.dangerously_allow_all_unix_sockets=false",
            "features.network_proxy.enabled=true",
            "features.network_proxy.mode=\"full\"",
            "features.network_proxy.allow_local_binding=false",
            "features.network_proxy.dangerously_allow_non_loopback_proxy=false",
            "features.network_proxy.dangerously_allow_all_unix_sockets=false",
            "features.network_proxy.domains={ \"*\" = \"allow\" }",
            "tools.web_search.context_size=\"high\"",
            "project_doc_max_bytes=0",
            "skills.include_instructions=true",
            "skills.bundled.enabled=false",
            "features.shell_tool=true",
            "features.unified_exec=true",
            "features.multi_agent=true",
            "features.image_generation=false",
            "features.apps=false",
            "features.plugins=false",
            "features.remote_plugin=false",
            "features.plugin_sharing=false",
            "features.computer_use=false",
            "orchestrator.skills.enabled=false",
            "orchestrator.mcp.enabled=false",
            "analytics.enabled=false",
            "otel.metrics_exporter=\"none\"",
        ]
    )

    public let identifier: CodexRuntimeProfileID
    public let schemaVersion: Int
    public let compatibleMajorVersion: Int
    public let compatibleMinorVersion: Int
    public let compatiblePatchVersion: Int
    public let orderedConfigOverrides: [String]
    public let profileDigest: String

    private init(
        identifier: CodexRuntimeProfileID,
        schemaVersion: Int,
        compatibleMajorVersion: Int,
        compatibleMinorVersion: Int,
        compatiblePatchVersion: Int,
        orderedConfigOverrides: [String]
    ) {
        self.identifier = identifier
        self.schemaVersion = schemaVersion
        self.compatibleMajorVersion = compatibleMajorVersion
        self.compatibleMinorVersion = compatibleMinorVersion
        self.compatiblePatchVersion = compatiblePatchVersion
        self.orderedConfigOverrides = orderedConfigOverrides
        profileDigest = Self.digest(
            identifier: identifier,
            schemaVersion: schemaVersion,
            compatibleMajorVersion: compatibleMajorVersion,
            compatibleMinorVersion: compatibleMinorVersion,
            compatiblePatchVersion: compatiblePatchVersion,
            orderedConfigOverrides: orderedConfigOverrides
        )
    }

    public var diagnosticSummary: String {
        [
            "id=\(identifier.rawValue)",
            "schema=\(schemaVersion)",
            """
            codex=\(compatibleMajorVersion).\(compatibleMinorVersion).\
            \(compatiblePatchVersion)
            """,
            "digest=\(profileDigest)",
        ].joined(separator: ";")
    }

    var appServerDiagnosticArguments: [String] {
        rootConfigArguments(strict: true) + ["app-server", "--stdio"]
    }

    var featureDiagnosticArguments: [String] {
        rootConfigArguments(strict: false) + ["features", "list"]
    }

    var promptInputDiagnosticArguments: [String] {
        rootConfigArguments(strict: false) + ["debug", "prompt-input"]
    }

    public func isCompatible(versionOutput: String) -> Bool {
        let normalized = versionOutput.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let components = normalized.split(whereSeparator: \.isWhitespace)
        guard
            components.count == 2,
            components[0] == "codex-cli"
        else {
            return false
        }
        let version = components[1].split(separator: ".", omittingEmptySubsequences: false)
        guard
            version.count == 3,
            let major = Int(version[0]),
            let minor = Int(version[1]),
            let patch = Int(version[2])
        else {
            return false
        }
        return major == compatibleMajorVersion
            && minor == compatibleMinorVersion
            && patch == compatiblePatchVersion
    }

    public func execArguments(
        schemaURL: URL,
        workingDirectoryURL: URL,
        model: CodexRuntimeModel? = nil
    ) throws -> [String] {
        guard Self.isSafeAbsoluteFileURL(schemaURL) else {
            throw CodexRuntimeProfileError.invalidSchemaURL
        }
        guard Self.isSafeAbsoluteFileURL(workingDirectoryURL) else {
            throw CodexRuntimeProfileError.invalidWorkingDirectoryURL
        }

        var arguments = [
            "--strict-config",
            "--ask-for-approval",
            "never",
            "--search",
        ]
        if let model {
            arguments.append(contentsOf: ["--model", model.rawValue])
        }
        for override in orderedConfigOverrides {
            arguments.append(contentsOf: ["-c", override])
        }
        arguments.append(contentsOf: [
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
        return arguments
    }

    func ignoreUserConfigDiagnosticArguments(
        schemaURL: URL,
        workingDirectoryURL: URL,
        ignoresUserConfig: Bool
    ) throws -> [String] {
        guard Self.isSafeAbsoluteFileURL(schemaURL) else {
            throw CodexRuntimeProfileError.invalidSchemaURL
        }
        guard Self.isSafeAbsoluteFileURL(workingDirectoryURL) else {
            throw CodexRuntimeProfileError.invalidWorkingDirectoryURL
        }
        var arguments = [
            "--strict-config",
            "--ask-for-approval",
            "never",
            "--search",
        ]
        for override in orderedConfigOverrides {
            arguments.append(contentsOf: ["-c", override])
        }
        arguments.append(contentsOf: [
            "exec",
            "--ephemeral",
            "--json",
            "--output-schema",
            schemaURL.path,
        ])
        if ignoresUserConfig {
            arguments.append("--ignore-user-config")
        }
        arguments.append(contentsOf: [
            "--ignore-rules",
            "--skip-git-repo-check",
            "-C",
            workingDirectoryURL.path,
            "-",
        ])
        return arguments
    }

    private static func isSafeAbsoluteFileURL(_ url: URL) -> Bool {
        guard url.isFileURL, url.path.hasPrefix("/") else {
            return false
        }
        return !url.path.unicodeScalars.contains {
            $0.value == 0 || $0.value == 10 || $0.value == 13
        }
    }

    private func rootConfigArguments(strict: Bool) -> [String] {
        var arguments = strict ? ["--strict-config"] : []
        for override in orderedConfigOverrides {
            arguments.append(contentsOf: ["-c", override])
        }
        return arguments
    }

    private static func digest(
        identifier: CodexRuntimeProfileID,
        schemaVersion: Int,
        compatibleMajorVersion: Int,
        compatibleMinorVersion: Int,
        compatiblePatchVersion: Int,
        orderedConfigOverrides: [String]
    ) -> String {
        let canonical = (
            [
                identifier.rawValue,
                String(schemaVersion),
                """
                \(compatibleMajorVersion).\(compatibleMinorVersion).\
                \(compatiblePatchVersion)
                """,
            ] + orderedConfigOverrides
        ).joined(separator: "\n")
        return SHA256.hash(data: Data(canonical.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
