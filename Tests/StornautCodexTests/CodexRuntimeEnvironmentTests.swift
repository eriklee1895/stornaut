import Foundation
import Testing
@testable import StornautCodex

@Suite("Codex runtime environment")
struct CodexRuntimeEnvironmentTests {
    @Test
    func projectsOnlyClosedUsefulVariables() throws {
        let trustFile = URL(filePath: "/private/etc/ssl/cert.pem")
        let trustDirectory = URL(
            filePath: "/private/etc/ssl",
            directoryHint: .isDirectory
        )
        let policy = CodexRuntimeEnvironmentPolicy()
        let projected = try policy.project(
            inherited: [
                "PATH": "/usr/bin:/bin:/opt/homebrew/bin:/usr/bin",
                "LANG": "en_US.UTF-8",
                "LC_CTYPE": "UTF-8",
                "TERM": "xterm-256color",
                "SSL_CERT_FILE": trustFile.path,
                "SSL_CERT_DIR": trustDirectory.path,
                "OPENAI_API_KEY": "secret",
                "GITHUB_TOKEN": "secret",
                "SSH_AUTH_SOCK": "/private/tmp/ssh.sock",
                "HTTP_PROXY": "http://127.0.0.1:8080",
                "DYLD_INSERT_LIBRARIES": "/private/tmp/inject.dylib",
                "NODE_OPTIONS": "--require evil",
                "CODEX_THREAD_ID": "private",
                "UNRELATED": "private",
            ],
            workspace: fixtureWorkspace()
        )

        #expect(projected.values == [
            "CODEX_HOME": "/private/tmp/stornaut/runtime",
            "HOME": "/private/tmp/stornaut/home",
            "LANG": "en_US.UTF-8",
            "LC_CTYPE": "UTF-8",
            "PATH": "/usr/bin:/bin:/opt/homebrew/bin",
            "SSL_CERT_DIR": trustDirectory.resolvingSymlinksInPath().path,
            "SSL_CERT_FILE": trustFile.resolvingSymlinksInPath().path,
            "TERM": "xterm-256color",
            "TMPDIR": "/private/tmp/stornaut/runtime/tmp",
        ])
        #expect(!projected.description.contains("secret"))
        #expect(!projected.description.contains("OPENAI_API_KEY"))
    }

    @Test
    func rejectsRelativePathEntriesAndBounds() {
        let policy = CodexRuntimeEnvironmentPolicy(
            maximumPATHEntries: 2,
            maximumPATHBytes: 32
        )
        #expect(throws: CodexRuntimeEnvironmentError.invalidPATH) {
            _ = try policy.project(
                inherited: ["PATH": "/usr/bin:relative:/bin"],
                workspace: fixtureWorkspace()
            )
        }
        #expect(throws: CodexRuntimeEnvironmentError.pathLimitExceeded) {
            _ = try policy.project(
                inherited: ["PATH": "/usr/bin:/bin:/usr/sbin"],
                workspace: fixtureWorkspace()
            )
        }
        #expect(throws: CodexRuntimeEnvironmentError.pathLimitExceeded) {
            _ = try CodexRuntimeEnvironmentPolicy(
                maximumPATHEntries: 8,
                maximumPATHBytes: 7
            ).project(
                inherited: ["PATH": "/usr/bin"],
                workspace: fixtureWorkspace()
            )
        }
    }

    @Test
    func rejectsInvalidLocaleTerminalAndTrustPaths() {
        let trust = try! RuntimeTrustFixture()
        defer { trust.remove() }
        let symlink = trust.root.appending(path: "cert-link.pem")
        try! FileManager.default.createSymbolicLink(
            at: symlink,
            withDestinationURL: trust.fileURL
        )
        let policy = CodexRuntimeEnvironmentPolicy()
        for inherited in [
            ["LANG": "en_US.UTF-8\nTOKEN=secret"],
            ["TERM": String(repeating: "x", count: 129)],
            ["SSL_CERT_FILE": "relative.pem"],
            ["SSL_CERT_DIR": "/Users/example/private-certs"],
            ["SSL_CERT_FILE": trust.root.appending(path: "missing.pem").path],
            ["SSL_CERT_FILE": trust.directoryURL.path],
            ["SSL_CERT_DIR": trust.fileURL.path],
            ["SSL_CERT_FILE": symlink.path],
            ["SSL_CERT_FILE": trust.fileURL.path],
            ["SSL_CERT_DIR": trust.directoryURL.path],
        ] {
            #expect(throws: CodexRuntimeEnvironmentError.self) {
                _ = try policy.project(
                    inherited: inherited,
                    workspace: fixtureWorkspace(),
                    forbiddenHomeURL: URL(filePath: "/Users/example")
                )
            }
        }
    }

    @Test
    func trustPathRequiresAnImmutableRootOwnedParentChain() {
        let fileURL = URL(filePath: "/Users/Shared/cert.pem")
        let metadata: [String: CodexRuntimeTrustPathMetadata] = [
            "/": .init(fileType: S_IFDIR, owner: 0, mode: 0o755),
            "/Users": .init(fileType: S_IFDIR, owner: 0, mode: 0o755),
            "/Users/Shared": .init(
                fileType: S_IFDIR,
                owner: 0,
                mode: 0o1777
            ),
        ]

        #expect(
            !codexRuntimeTrustParentChainIsSecure(fileURL) {
                metadata[$0.path]
            }
        )
        let secureMetadata = metadata.merging([
            "/Users/Shared": .init(
                fileType: S_IFDIR,
                owner: 0,
                mode: 0o755
            ),
        ]) { _, replacement in replacement }
        #expect(
            codexRuntimeTrustParentChainIsSecure(fileURL) {
                secureMetadata[$0.path]
            }
        )
    }

    @Test
    func requiresDisjointAbsoluteWorkspacePaths() {
        let invalid = CodexRuntimeWorkspacePaths(
            rootURL: URL(filePath: "/private/tmp/stornaut"),
            homeURL: URL(filePath: "/private/tmp/stornaut/home"),
            runtimeURL: URL(filePath: "/private/tmp/stornaut/home/runtime"),
            workURL: URL(filePath: "/private/tmp/stornaut/work"),
            schemaURL: URL(filePath: "/private/tmp/stornaut/schema"),
            fixturesURL: URL(filePath: "/private/tmp/stornaut/fixtures")
        )
        #expect(throws: CodexRuntimeEnvironmentError.invalidWorkspace) {
            _ = try CodexRuntimeEnvironmentPolicy().project(
                inherited: [:],
                workspace: invalid
            )
        }
    }
}

private struct RuntimeTrustFixture {
    let root: URL
    let fileURL: URL
    let directoryURL: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-trust-tests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        fileURL = root.appending(path: "cert.pem")
        directoryURL = root.appending(
            path: "certs",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try Data("synthetic certificate".utf8).write(to: fileURL)
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

private func fixtureWorkspace() -> CodexRuntimeWorkspacePaths {
    CodexRuntimeWorkspacePaths(
        rootURL: URL(filePath: "/private/tmp/stornaut"),
        homeURL: URL(filePath: "/private/tmp/stornaut/home"),
        runtimeURL: URL(filePath: "/private/tmp/stornaut/runtime"),
        workURL: URL(filePath: "/private/tmp/stornaut/work"),
        schemaURL: URL(filePath: "/private/tmp/stornaut/schema"),
        fixturesURL: URL(filePath: "/private/tmp/stornaut/fixtures")
    )
}
