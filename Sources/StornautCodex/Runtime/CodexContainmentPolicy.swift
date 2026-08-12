import CryptoKit
import Darwin
import Foundation

enum CodexContainmentPolicyError: Error, Sendable, Equatable {
    case invalidWorkspace
    case invalidAuthSource
    case overlappingAuthSource
    case invalidExecutable
    case configurationInstallFailed
}

struct CodexContainmentConfiguration:
    Sendable,
    Equatable,
    CustomStringConvertible
{
    let data: Data
    let digest: String

    var description: String {
        "<CodexContainmentConfiguration:digest=\(digest)>"
    }
}

struct CodexContainmentPolicy: Sendable {
    static let profileName = "stornaut-outer-v1"

    func configuration(
        workspace: CodexRuntimeWorkspacePaths,
        projectedAuthSourceURL: URL
    ) throws -> CodexContainmentConfiguration {
        guard workspacePathsAreValid(workspace) else {
            throw CodexContainmentPolicyError.invalidWorkspace
        }
        guard
            let authPath = safeAbsoluteTOMLPath(projectedAuthSourceURL)
        else {
            throw CodexContainmentPolicyError.invalidAuthSource
        }
        guard !contains(workspace.rootURL, projectedAuthSourceURL) else {
            throw CodexContainmentPolicyError.overlappingAuthSource
        }
        let runtimePath = try quotedTOMLPath(workspace.runtimeURL)
        let lines = [
            #"default_permissions = "stornaut-outer-v1""#,
            #"cli_auth_credentials_store = "ephemeral""#,
            #"permissions.stornaut-outer-v1.extends = ":read-only""#,
            """
            permissions.stornaut-outer-v1.filesystem.\(authPath) = "deny"
            """,
            """
            permissions.stornaut-outer-v1.filesystem.\(runtimePath) = "write"
            """,
            "permissions.stornaut-outer-v1.network.enabled = true",
            #"permissions.stornaut-outer-v1.network.mode = "full""#,
            "permissions.stornaut-outer-v1.network.enable_socks5 = false",
            "permissions.stornaut-outer-v1.network.allow_local_binding = false",
            """
            permissions.stornaut-outer-v1.network.\
            dangerously_allow_non_loopback_proxy = false
            """,
            """
            permissions.stornaut-outer-v1.network.\
            dangerously_allow_all_unix_sockets = false
            """,
            """
            permissions.stornaut-outer-v1.network.domains = \
            { "*" = "allow" }
            """,
            "features.network_proxy.enabled = true",
            #"features.network_proxy.mode = "full""#,
            "features.network_proxy.enable_socks5 = false",
            "features.network_proxy.allow_local_binding = false",
            """
            features.network_proxy.\
            dangerously_allow_non_loopback_proxy = false
            """,
            """
            features.network_proxy.\
            dangerously_allow_all_unix_sockets = false
            """,
            #"features.network_proxy.domains = { "*" = "allow" }"#,
            #"tools.web_search.context_size = "high""#,
            "project_doc_max_bytes = 0",
            "skills.include_instructions = true",
            "skills.bundled.enabled = false",
            "features.shell_tool = true",
            "features.unified_exec = true",
            "features.multi_agent = true",
            "features.image_generation = false",
            "features.apps = false",
            "features.plugins = false",
            "features.remote_plugin = false",
            "features.plugin_sharing = false",
            "features.computer_use = false",
            "orchestrator.skills.enabled = false",
            "orchestrator.mcp.enabled = false",
            "analytics.enabled = false",
            #"otel.metrics_exporter = "none""#,
        ]
        let data = Data((lines.joined(separator: "\n") + "\n").utf8)
        return CodexContainmentConfiguration(
            data: data,
            digest: SHA256.hash(data: data)
                .map { String(format: "%02x", $0) }
                .joined()
        )
    }

    func launchArguments(
        codexExecutableURL: URL,
        workspace: CodexRuntimeWorkspacePaths
    ) throws -> [String] {
        guard workspacePathsAreValid(workspace) else {
            throw CodexContainmentPolicyError.invalidWorkspace
        }
        guard
            codexExecutableURL.isFileURL,
            codexExecutableURL.path.hasPrefix("/"),
            pathContainsNoControlCharacters(codexExecutableURL.path)
        else {
            throw CodexContainmentPolicyError.invalidExecutable
        }
        return [
            "sandbox",
            "-P",
            Self.profileName,
            "-C",
            workspace.workURL.path,
            "--",
            codexExecutableURL.path,
            "--strict-config",
            "--disable",
            "network_proxy",
            "app-server",
            "--stdio",
        ]
    }

    func install(
        _ configuration: CodexContainmentConfiguration,
        in workspace: CodexRuntimeWorkspacePaths
    ) throws -> URL {
        guard
            workspacePathsAreValid(workspace),
            isOwnerOnlyDirectory(workspace.runtimeURL)
        else {
            throw CodexContainmentPolicyError.invalidWorkspace
        }
        let destination = workspace.runtimeURL.appending(
            path: "config.toml"
        )
        let descriptor = open(
            destination.path,
            O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
            0o600
        )
        guard descriptor >= 0 else {
            throw CodexContainmentPolicyError.configurationInstallFailed
        }
        defer { close(descriptor) }

        let wroteAll = configuration.data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return true }
            var offset = 0
            while offset < bytes.count {
                let written = Darwin.write(
                    descriptor,
                    baseAddress.advanced(by: offset),
                    bytes.count - offset
                )
                if written < 0 {
                    if errno == EINTR { continue }
                    return false
                }
                offset += written
            }
            return true
        }
        guard wroteAll, fsync(descriptor) == 0 else {
            try? FileManager.default.removeItem(at: destination)
            throw CodexContainmentPolicyError.configurationInstallFailed
        }
        var information = stat()
        guard
            fstat(descriptor, &information) == 0,
            information.st_mode & S_IFMT == S_IFREG,
            information.st_uid == geteuid(),
            information.st_mode & 0o777 == 0o600,
            information.st_size == configuration.data.count
        else {
            try? FileManager.default.removeItem(at: destination)
            throw CodexContainmentPolicyError.configurationInstallFailed
        }
        return destination
    }

    func validateInstalled(
        _ configuration: CodexContainmentConfiguration,
        in workspace: CodexRuntimeWorkspacePaths
    ) throws {
        guard
            workspacePathsAreValid(workspace),
            isOwnerOnlyDirectory(workspace.runtimeURL),
            SHA256.hash(data: configuration.data)
                .map({ String(format: "%02x", $0) })
                .joined() == configuration.digest
        else {
            throw CodexContainmentPolicyError.invalidWorkspace
        }
        let url = workspace.runtimeURL.appending(path: "config.toml")
        let descriptor = open(
            url.path,
            O_RDONLY | O_CLOEXEC | O_NOFOLLOW
        )
        guard descriptor >= 0 else {
            throw CodexContainmentPolicyError.configurationInstallFailed
        }
        defer { close(descriptor) }
        var information = stat()
        guard
            fstat(descriptor, &information) == 0,
            information.st_mode & S_IFMT == S_IFREG,
            information.st_uid == geteuid(),
            information.st_mode & 0o777 == 0o600,
            information.st_nlink == 1,
            information.st_size == configuration.data.count,
            let installed = readExactly(
                descriptor: descriptor,
                byteCount: configuration.data.count
            ),
            installed == configuration.data
        else {
            throw CodexContainmentPolicyError.configurationInstallFailed
        }
        var finalInformation = stat()
        guard
            fstat(descriptor, &finalInformation) == 0,
            finalInformation.st_dev == information.st_dev,
            finalInformation.st_ino == information.st_ino,
            finalInformation.st_size == information.st_size,
            finalInformation.st_mtimespec.tv_sec
                == information.st_mtimespec.tv_sec,
            finalInformation.st_mtimespec.tv_nsec
                == information.st_mtimespec.tv_nsec
        else {
            throw CodexContainmentPolicyError.configurationInstallFailed
        }
    }

    private func workspacePathsAreValid(
        _ workspace: CodexRuntimeWorkspacePaths
    ) -> Bool {
        guard workspace.directories.allSatisfy({
            $0.isFileURL
                && $0.path.hasPrefix("/")
                && pathContainsNoControlCharacters($0.path)
        }) else {
            return false
        }
        let components = workspace.componentDirectories
        guard Set(components.map(\.path)).count == components.count else {
            return false
        }
        for (index, first) in components.enumerated() {
            guard contains(workspace.rootURL, first) else {
                return false
            }
            for second in components.dropFirst(index + 1) {
                if pathsOverlap(first, second) {
                    return false
                }
            }
        }
        return true
    }

    private func safeAbsoluteTOMLPath(_ url: URL) -> String? {
        guard
            url.isFileURL,
            url.path.hasPrefix("/"),
            pathContainsNoControlCharacters(url.path),
            !url.path.contains("\""),
            !url.path.contains("\\")
        else {
            return nil
        }
        return "\"\(url.standardizedFileURL.path)\""
    }

    private func quotedTOMLPath(_ url: URL) throws -> String {
        guard let path = safeAbsoluteTOMLPath(url) else {
            throw CodexContainmentPolicyError.invalidWorkspace
        }
        return path
    }

    private func pathContainsNoControlCharacters(_ value: String) -> Bool {
        value.unicodeScalars.allSatisfy {
            $0.value >= 0x20 && $0.value != 0x7F
        }
    }

    private func isOwnerOnlyDirectory(_ url: URL) -> Bool {
        var information = stat()
        guard lstat(url.path, &information) == 0 else {
            return false
        }
        return information.st_mode & S_IFMT == S_IFDIR
            && information.st_uid == geteuid()
            && information.st_mode & 0o777 == 0o700
    }
}

private func readExactly(
    descriptor: Int32,
    byteCount: Int
) -> Data? {
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4_096)
    while data.count < byteCount {
        let remaining = min(buffer.count, byteCount - data.count)
        let count = Darwin.read(descriptor, &buffer, remaining)
        if count == 0 { return nil }
        if count < 0 {
            if errno == EINTR { continue }
            return nil
        }
        data.append(contentsOf: buffer.prefix(count))
    }
    var extra: UInt8 = 0
    guard Darwin.read(descriptor, &extra, 1) == 0 else {
        return nil
    }
    return data
}
