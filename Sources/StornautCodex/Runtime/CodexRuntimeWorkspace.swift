import Darwin
import Foundation

struct CodexRuntimeWorkspacePaths: Sendable, Equatable {
    let rootURL: URL
    let homeURL: URL
    let runtimeURL: URL
    let workURL: URL
    let schemaURL: URL
    let fixturesURL: URL

    var directories: [URL] {
        [
            rootURL,
            homeURL,
            runtimeURL,
            workURL,
            schemaURL,
            fixturesURL,
        ]
    }

    var componentDirectories: [URL] {
        Array(directories.dropFirst())
    }
}

enum CodexRuntimeWorkspaceError: Error, Sendable, Equatable {
    case unsafeParent
    case overlappingRoot
    case creationFailed
    case invalidMarker
    case invalidMode
    case invalidOwner
    case symlinkDetected
    case removalFailed
}

struct CodexRuntimeWorkspace: Sendable, Equatable {
    static let markerContents = "stornaut-runtime-workspace-v1\n"
    private static let namePrefix = "stornaut-runtime-v1-"

    let paths: CodexRuntimeWorkspacePaths
    let markerURL: URL
    let ownerUserID: uid_t

    static func create(
        under parentURL: URL,
        forbiddenRoots: [URL]
    ) throws -> CodexRuntimeWorkspace {
        guard
            parentURL.isFileURL,
            parentURL.path.hasPrefix("/"),
            existingDirectoryMetadata(parentURL)?.isSafeDirectory == true,
            let parent = canonicalExistingDirectory(parentURL)
        else {
            throw CodexRuntimeWorkspaceError.unsafeParent
        }

        let rootURL = parent.appending(
            path: "\(namePrefix)\(UUID().uuidString.lowercased())",
            directoryHint: .isDirectory
        )
        let canonicalRoot = rootURL.standardizedFileURL
        for forbidden in forbiddenRoots {
            let canonicalForbidden = forbidden.standardizedFileURL
                .resolvingSymlinksInPath()
            if pathsOverlap(canonicalRoot, canonicalForbidden) {
                throw CodexRuntimeWorkspaceError.overlappingRoot
            }
        }

        let creationResult = canonicalRoot.path.withCString {
            mkdir($0, 0o700)
        }
        guard creationResult == 0 else {
            throw CodexRuntimeWorkspaceError.creationFailed
        }

        let paths = CodexRuntimeWorkspacePaths(
            rootURL: canonicalRoot,
            homeURL: canonicalRoot.appending(
                path: "home",
                directoryHint: .isDirectory
            ),
            runtimeURL: canonicalRoot.appending(
                path: "runtime",
                directoryHint: .isDirectory
            ),
            workURL: canonicalRoot.appending(
                path: "work",
                directoryHint: .isDirectory
            ),
            schemaURL: canonicalRoot.appending(
                path: "schema",
                directoryHint: .isDirectory
            ),
            fixturesURL: canonicalRoot.appending(
                path: "fixtures",
                directoryHint: .isDirectory
            )
        )
        do {
            for directory in paths.componentDirectories {
                guard directory.path.withCString({
                    mkdir($0, 0o700)
                }) == 0 else {
                    throw CodexRuntimeWorkspaceError.creationFailed
                }
            }
            let temporaryURL = paths.runtimeURL.appending(
                path: "tmp",
                directoryHint: .isDirectory
            )
            guard temporaryURL.path.withCString({
                mkdir($0, 0o700)
            }) == 0 else {
                throw CodexRuntimeWorkspaceError.creationFailed
            }
            let markerURL = canonicalRoot.appending(
                path: ".stornaut-runtime-v1"
            )
            try writeExclusiveFile(
                Data(markerContents.utf8),
                to: markerURL
            )
            return CodexRuntimeWorkspace(
                paths: paths,
                markerURL: markerURL,
                ownerUserID: geteuid()
            )
        } catch {
            try? FileManager.default.removeItem(at: canonicalRoot)
            throw error
        }
    }

    func remove() throws {
        try remove(allowRuntimeSymlinks: true)
    }

    private func remove(
        allowRuntimeSymlinks: Bool
    ) throws {
        try validateForRemoval(
            allowRuntimeSymlinks: allowRuntimeSymlinks
        )
        do {
            try FileManager.default.removeItem(at: paths.rootURL)
        } catch {
            throw CodexRuntimeWorkspaceError.removalFailed
        }
    }

    static func removeStale(
        under parentURL: URL,
        olderThan cutoff: Date
    ) throws -> [URL] {
        guard
            existingDirectoryMetadata(parentURL)?.isSafeDirectory == true,
            let parent = canonicalExistingDirectory(parentURL)
        else {
            throw CodexRuntimeWorkspaceError.unsafeParent
        }
        let contents = try FileManager.default.contentsOfDirectory(
            at: parent,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: []
        )
        var removed: [URL] = []
        for candidate in contents where
            candidate.lastPathComponent.hasPrefix(namePrefix)
        {
            guard
                let modified = try? candidate.resourceValues(
                    forKeys: [.contentModificationDateKey]
                ).contentModificationDate,
                modified < cutoff
            else {
                continue
            }
            let paths = paths(for: candidate)
            let workspace = CodexRuntimeWorkspace(
                paths: paths,
                markerURL: candidate.appending(path: ".stornaut-runtime-v1"),
                ownerUserID: geteuid()
            )
            try workspace.remove(allowRuntimeSymlinks: false)
            removed.append(candidate)
        }
        return removed.sorted { $0.path < $1.path }
    }

    private func validateForRemoval(
        allowRuntimeSymlinks: Bool
    ) throws {
        for directory in paths.directories {
            guard let metadata = existingDirectoryMetadata(directory) else {
                throw CodexRuntimeWorkspaceError.removalFailed
            }
            guard metadata.owner == ownerUserID else {
                throw CodexRuntimeWorkspaceError.invalidOwner
            }
            guard metadata.mode == 0o700 else {
                throw CodexRuntimeWorkspaceError.invalidMode
            }
        }
        guard
            let markerMetadata = lstatMetadata(markerURL),
            markerMetadata.fileType == S_IFREG,
            markerMetadata.owner == ownerUserID,
            markerMetadata.mode == 0o600,
            let markerData = try? Data(contentsOf: markerURL),
            markerData == Data(Self.markerContents.utf8)
        else {
            throw CodexRuntimeWorkspaceError.invalidMarker
        }
        if
            !allowRuntimeSymlinks,
            containsSymlink(in: paths.rootURL)
        {
            throw CodexRuntimeWorkspaceError.symlinkDetected
        }
    }

    private static func paths(
        for rootURL: URL
    ) -> CodexRuntimeWorkspacePaths {
        CodexRuntimeWorkspacePaths(
            rootURL: rootURL,
            homeURL: rootURL.appending(path: "home", directoryHint: .isDirectory),
            runtimeURL: rootURL.appending(path: "runtime", directoryHint: .isDirectory),
            workURL: rootURL.appending(path: "work", directoryHint: .isDirectory),
            schemaURL: rootURL.appending(path: "schema", directoryHint: .isDirectory),
            fixturesURL: rootURL.appending(path: "fixtures", directoryHint: .isDirectory)
        )
    }
}

private struct WorkspaceMetadata {
    let fileType: mode_t
    let mode: mode_t
    let owner: uid_t

    var isSafeDirectory: Bool {
        fileType == S_IFDIR && owner == geteuid() && mode == 0o700
    }
}

private func lstatMetadata(_ url: URL) -> WorkspaceMetadata? {
    var information = stat()
    guard lstat(url.path, &information) == 0 else {
        return nil
    }
    return WorkspaceMetadata(
        fileType: information.st_mode & S_IFMT,
        mode: information.st_mode & 0o777,
        owner: information.st_uid
    )
}

private func existingDirectoryMetadata(_ url: URL) -> WorkspaceMetadata? {
    lstatMetadata(url)
}

private func canonicalExistingDirectory(_ url: URL) -> URL? {
    guard let pointer = realpath(url.path, nil) else {
        return nil
    }
    defer { free(pointer) }
    return URL(
        filePath: String(cString: pointer),
        directoryHint: .isDirectory
    ).standardizedFileURL
}

func pathsOverlap(_ first: URL, _ second: URL) -> Bool {
    contains(first, second) || contains(second, first)
}

func contains(_ root: URL, _ candidate: URL) -> Bool {
    let rootComponents = root.standardizedFileURL.pathComponents
    let candidateComponents = candidate.standardizedFileURL.pathComponents
    guard candidateComponents.count >= rootComponents.count else {
        return false
    }
    return Array(candidateComponents.prefix(rootComponents.count))
        == rootComponents
}

private func writeExclusiveFile(_ data: Data, to url: URL) throws {
    let descriptor = open(
        url.path,
        O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
        0o600
    )
    guard descriptor >= 0 else {
        throw CodexRuntimeWorkspaceError.creationFailed
    }
    defer { close(descriptor) }
    let result = data.withUnsafeBytes { bytes -> Bool in
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
    guard result, fsync(descriptor) == 0 else {
        throw CodexRuntimeWorkspaceError.creationFailed
    }
}

private func containsSymlink(in rootURL: URL) -> Bool {
    guard let enumerator = FileManager.default.enumerator(
        at: rootURL,
        includingPropertiesForKeys: nil,
        options: []
    ) else {
        return true
    }
    while let url = enumerator.nextObject() as? URL {
        if lstatMetadata(url)?.fileType == S_IFLNK {
            return true
        }
    }
    return false
}
