import Darwin
import Foundation
import Testing
@testable import StornautCodex

@Suite("Codex runtime workspace")
struct CodexRuntimeWorkspaceTests {
    @Test
    func createsOwnerOnlyClosedTopologyAndCleansIt() throws {
        let parent = try TemporaryWorkspaceParent()
        defer { parent.remove() }
        let workspace = try CodexRuntimeWorkspace.create(
            under: parent.url,
            forbiddenRoots: [
                URL(filePath: "/Users/example"),
                URL(filePath: "/Users/example/.codex"),
                URL(filePath: "/private/tmp/investigation"),
            ]
        )

        #expect(workspace.paths.rootURL.deletingLastPathComponent() == parent.url)
        for url in workspace.paths.directories {
            #expect(directoryMode(url) == 0o700)
            #expect(!isSymbolicLink(url))
        }
        #expect(fileMode(workspace.markerURL) == 0o600)
        #expect(try Data(contentsOf: workspace.markerURL) ==
            Data(CodexRuntimeWorkspace.markerContents.utf8))

        try workspace.remove()
        #expect(!FileManager.default.fileExists(
            atPath: workspace.paths.rootURL.path
        ))
    }

    @Test
    func rejectsForbiddenOverlapAndSymlinkParent() throws {
        let parent = try TemporaryWorkspaceParent()
        defer { parent.remove() }
        #expect(throws: CodexRuntimeWorkspaceError.overlappingRoot) {
            _ = try CodexRuntimeWorkspace.create(
                under: parent.url,
                forbiddenRoots: [parent.url]
            )
        }

        let link = parent.url.appending(path: "link")
        try FileManager.default.createSymbolicLink(
            at: link,
            withDestinationURL: parent.url
        )
        #expect(throws: CodexRuntimeWorkspaceError.unsafeParent) {
            _ = try CodexRuntimeWorkspace.create(
                under: link,
                forbiddenRoots: []
            )
        }
    }

    @Test
    func cleanupRefusesMarkerAndModeTampering() throws {
        let parent = try TemporaryWorkspaceParent()
        defer { parent.remove() }

        let markerWorkspace = try CodexRuntimeWorkspace.create(
            under: parent.url,
            forbiddenRoots: []
        )
        try Data("tampered".utf8).write(to: markerWorkspace.markerURL)
        #expect(throws: CodexRuntimeWorkspaceError.invalidMarker) {
            try markerWorkspace.remove()
        }
        try FileManager.default.removeItem(
            at: markerWorkspace.paths.rootURL
        )

        let modeWorkspace = try CodexRuntimeWorkspace.create(
            under: parent.url,
            forbiddenRoots: []
        )
        chmod(modeWorkspace.paths.rootURL.path, 0o755)
        #expect(throws: CodexRuntimeWorkspaceError.invalidMode) {
            try modeWorkspace.remove()
        }
        try FileManager.default.removeItem(at: modeWorkspace.paths.rootURL)
    }

    @Test
    func activeCleanupUnlinksRuntimeSymlinksWithoutFollowingThem() throws {
        let parent = try TemporaryWorkspaceParent()
        defer { parent.remove() }
        let externalDirectory = parent.url.appending(
            path: "external",
            directoryHint: .isDirectory
        )
        let externalFile = externalDirectory.appending(path: "retained.txt")
        try FileManager.default.createDirectory(
            at: externalDirectory,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        try Data("retained".utf8).write(to: externalFile)

        let symlinkWorkspace = try CodexRuntimeWorkspace.create(
            under: parent.url,
            forbiddenRoots: []
        )
        try FileManager.default.createSymbolicLink(
            at: symlinkWorkspace.paths.runtimeURL.appending(path: "escape"),
            withDestinationURL: externalDirectory
        )

        try symlinkWorkspace.remove()

        #expect(!FileManager.default.fileExists(
            atPath: symlinkWorkspace.paths.rootURL.path
        ))
        #expect(
            try String(contentsOf: externalFile, encoding: .utf8)
                == "retained"
        )
    }

    @Test
    func staleCleanupRemovesOnlyValidOldWorkspaces() throws {
        let parent = try TemporaryWorkspaceParent()
        defer { parent.remove() }
        let old = try CodexRuntimeWorkspace.create(
            under: parent.url,
            forbiddenRoots: []
        )
        let fresh = try CodexRuntimeWorkspace.create(
            under: parent.url,
            forbiddenRoots: []
        )
        let oldDate = Date(timeIntervalSinceNow: -3_600)
        try FileManager.default.setAttributes(
            [.modificationDate: oldDate],
            ofItemAtPath: old.paths.rootURL.path
        )

        let removed = try CodexRuntimeWorkspace.removeStale(
            under: parent.url,
            olderThan: Date(timeIntervalSinceNow: -60)
        )

        #expect(removed.count == 1)
        #expect(
            removed.first?.lastPathComponent
                == old.paths.rootURL.lastPathComponent
        )
        #expect(!FileManager.default.fileExists(
            atPath: old.paths.rootURL.path
        ))
        #expect(FileManager.default.fileExists(
            atPath: fresh.paths.rootURL.path
        ))
        try fresh.remove()
    }

    @Test
    func staleCleanupRefusesSymlinkedWorkspace() throws {
        let parent = try TemporaryWorkspaceParent()
        defer { parent.remove() }
        let workspace = try CodexRuntimeWorkspace.create(
            under: parent.url,
            forbiddenRoots: []
        )
        try FileManager.default.createSymbolicLink(
            at: workspace.paths.runtimeURL.appending(path: "escape"),
            withDestinationURL: parent.url
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -3_600)],
            ofItemAtPath: workspace.paths.rootURL.path
        )

        #expect(throws: CodexRuntimeWorkspaceError.symlinkDetected) {
            _ = try CodexRuntimeWorkspace.removeStale(
                under: parent.url,
                olderThan: Date(timeIntervalSinceNow: -60)
            )
        }
        #expect(FileManager.default.fileExists(
            atPath: workspace.paths.rootURL.path
        ))
        try FileManager.default.removeItem(at: workspace.paths.rootURL)
    }
}

private struct TemporaryWorkspaceParent {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-workspace-tests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}

private func directoryMode(_ url: URL) -> mode_t {
    var information = stat()
    guard lstat(url.path, &information) == 0 else { return 0 }
    return information.st_mode & 0o777
}

private func fileMode(_ url: URL) -> mode_t {
    directoryMode(url)
}

private func isSymbolicLink(_ url: URL) -> Bool {
    var information = stat()
    guard lstat(url.path, &information) == 0 else { return true }
    return information.st_mode & S_IFMT == S_IFLNK
}
