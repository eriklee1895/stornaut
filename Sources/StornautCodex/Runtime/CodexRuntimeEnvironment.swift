import Darwin
import Foundation

struct CodexRuntimeEnvironment: Sendable, Equatable, CustomStringConvertible {
    let values: [String: String]

    var description: String {
        "<CodexRuntimeEnvironment:keys=\(values.keys.sorted().joined(separator: ","))>"
    }
}

enum CodexRuntimeEnvironmentError: Error, Sendable, Equatable {
    case invalidWorkspace
    case invalidPATH
    case pathLimitExceeded
    case invalidValue
    case invalidTrustPath
}

struct CodexRuntimeEnvironmentPolicy: Sendable {
    let maximumPATHEntries: Int
    let maximumPATHBytes: Int
    let maximumValueBytes: Int

    init(
        maximumPATHEntries: Int = 64,
        maximumPATHBytes: Int = 8_192,
        maximumValueBytes: Int = 1_024
    ) {
        self.maximumPATHEntries = max(1, maximumPATHEntries)
        self.maximumPATHBytes = max(1, maximumPATHBytes)
        self.maximumValueBytes = max(1, maximumValueBytes)
    }

    func project(
        inherited: [String: String],
        workspace: CodexRuntimeWorkspacePaths,
        forbiddenHomeURL: URL? = nil
    ) throws -> CodexRuntimeEnvironment {
        guard workspacePathsAreValid(workspace) else {
            throw CodexRuntimeEnvironmentError.invalidWorkspace
        }

        var values = [
            "CODEX_HOME": workspace.runtimeURL.path,
            "HOME": workspace.homeURL.path,
            "TMPDIR": workspace.runtimeURL.appending(
                path: "tmp",
                directoryHint: .isDirectory
            ).path,
        ]
        if let path = inherited["PATH"] {
            values["PATH"] = try sanitizePATH(path)
        }
        for key in ["LANG", "LC_ALL", "LC_CTYPE"] {
            if let value = inherited[key] {
                values[key] = try sanitizeBoundedText(value)
            }
        }
        if let terminal = inherited["TERM"] {
            guard terminal.utf8.count <= 128 else {
                throw CodexRuntimeEnvironmentError.invalidValue
            }
            values["TERM"] = try sanitizeBoundedText(terminal)
        }
        for key in ["SSL_CERT_FILE", "SSL_CERT_DIR"] {
            if let value = inherited[key] {
                values[key] = try sanitizeTrustPath(
                    value,
                    expectsDirectory: key == "SSL_CERT_DIR",
                    forbiddenHomeURL: forbiddenHomeURL
                )
            }
        }
        return CodexRuntimeEnvironment(values: values)
    }

    private func sanitizePATH(_ path: String) throws -> String {
        let entries = path.split(
            separator: ":",
            omittingEmptySubsequences: false
        ).map(String.init)
        guard
            !entries.isEmpty,
            entries.allSatisfy({
                $0.hasPrefix("/")
                    && !$0.contains("\n")
                    && !$0.contains("\r")
                    && !$0.utf8.contains(0)
            })
        else {
            throw CodexRuntimeEnvironmentError.invalidPATH
        }
        var seen = Set<String>()
        let unique = try entries.compactMap { entry -> String? in
            let url = URL(
                filePath: entry,
                directoryHint: .isDirectory
            ).standardizedFileURL
            var information = stat()
            guard
                lstat(url.path, &information) == 0,
                information.st_mode & S_IFMT == S_IFDIR
                    || information.st_mode & S_IFMT == S_IFLNK
            else {
                throw CodexRuntimeEnvironmentError.invalidPATH
            }
            let canonical = url.resolvingSymlinksInPath()
                .standardizedFileURL
            guard
                lstat(canonical.path, &information) == 0,
                information.st_mode & S_IFMT == S_IFDIR
            else {
                throw CodexRuntimeEnvironmentError.invalidPATH
            }
            return seen.insert(canonical.path).inserted
                ? canonical.path
                : nil
        }
        guard unique.count <= maximumPATHEntries else {
            throw CodexRuntimeEnvironmentError.pathLimitExceeded
        }
        let result = unique.joined(separator: ":")
        guard result.utf8.count <= maximumPATHBytes else {
            throw CodexRuntimeEnvironmentError.pathLimitExceeded
        }
        return result
    }

    private func sanitizeBoundedText(_ value: String) throws -> String {
        guard
            !value.isEmpty,
            value.utf8.count <= maximumValueBytes,
            value.unicodeScalars.allSatisfy({
                $0.value >= 0x20 && $0.value != 0x7F
            })
        else {
            throw CodexRuntimeEnvironmentError.invalidValue
        }
        return value
    }

    private func sanitizeTrustPath(
        _ value: String,
        expectsDirectory: Bool,
        forbiddenHomeURL: URL?
    ) throws -> String {
        guard
            value.hasPrefix("/"),
            !value.contains("\n"),
            !value.contains("\r"),
            value.utf8.count <= maximumValueBytes
        else {
            throw CodexRuntimeEnvironmentError.invalidTrustPath
        }
        let url = URL(
            filePath: value,
            directoryHint: expectsDirectory ? .isDirectory : .notDirectory
        ).standardizedFileURL
        if let forbiddenHomeURL,
           contains(
               forbiddenHomeURL.standardizedFileURL,
               url
           )
        {
            throw CodexRuntimeEnvironmentError.invalidTrustPath
        }
        var information = stat()
        guard
            lstat(url.path, &information) == 0,
            information.st_mode & S_IFMT
                == (expectsDirectory ? S_IFDIR : S_IFREG),
            information.st_uid == 0,
            information.st_mode & 0o022 == 0,
            codexRuntimeTrustParentChainIsSecure(
                url,
                allowsRootOwnedSymlink: true
            ),
            let resolved = canonicalRuntimeTrustPath(url),
            codexRuntimeTrustParentChainIsSecure(resolved)
        else {
            throw CodexRuntimeEnvironmentError.invalidTrustPath
        }
        return url.path
    }

    private func workspacePathsAreValid(
        _ workspace: CodexRuntimeWorkspacePaths
    ) -> Bool {
        guard workspace.directories.allSatisfy({
            $0.isFileURL && $0.path.hasPrefix("/")
        }) else {
            return false
        }
        let components = workspace.componentDirectories
        guard Set(components.map(\.path)).count == components.count else {
            return false
        }
        for (index, first) in components.enumerated() {
            for second in components.dropFirst(index + 1) {
                if pathsOverlap(first, second) {
                    return false
                }
            }
            guard contains(workspace.rootURL, first) else {
                return false
            }
        }
        return true
    }
}

struct CodexRuntimeTrustPathMetadata: Sendable, Equatable {
    let fileType: mode_t
    let owner: uid_t
    let mode: mode_t
}

func codexRuntimeTrustParentChainIsSecure(
    _ url: URL,
    allowsRootOwnedSymlink: Bool = false,
    metadata: (URL) -> CodexRuntimeTrustPathMetadata? = {
        var information = stat()
        guard lstat($0.path, &information) == 0 else {
            return nil
        }
        return CodexRuntimeTrustPathMetadata(
            fileType: information.st_mode & S_IFMT,
            owner: information.st_uid,
            mode: information.st_mode & 0o7777
        )
    }
) -> Bool {
    let canonical = url
    guard canonical.path.hasPrefix("/") else { return false }
    var directory = canonical.deletingLastPathComponent()
    while true {
        guard
            let information = metadata(directory),
            information.fileType == S_IFDIR
                || (
                    allowsRootOwnedSymlink
                        && information.fileType == S_IFLNK
                ),
            information.owner == 0,
            information.mode & 0o022 == 0
        else {
            return false
        }
        let parent = directory.deletingLastPathComponent()
        if parent.path == directory.path {
            return true
        }
        directory = parent
    }
}

private func canonicalRuntimeTrustPath(_ url: URL) -> URL? {
    guard let pointer = realpath(url.path, nil) else { return nil }
    defer { free(pointer) }
    return URL(
        filePath: String(cString: pointer),
        directoryHint: .inferFromPath
    )
}
