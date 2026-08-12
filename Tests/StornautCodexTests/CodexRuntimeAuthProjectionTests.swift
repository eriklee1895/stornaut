import Darwin
import Foundation
import Testing
@testable import StornautCodex

@Suite("Codex runtime auth projection")
struct CodexRuntimeAuthProjectionTests {
    @Test
    func acceptsOnlyClosedChatGPTShapeAndRedactsDescription() throws {
        let fixture = try AuthFixture(
            object: [
                "auth_mode": "chatgpt",
                "OPENAI_API_KEY": "must-not-project",
                "tokens": [
                    "access_token": jwt("access"),
                    "account_id": "account-synthetic",
                    "id_token": jwt("id"),
                    "refresh_token": "refresh-secret",
                ],
            ]
        )
        defer { fixture.remove() }

        let projection = try CodexRuntimeAuthProjector().read(
            from: fixture.url
        )
        var observedToken = ""
        projection.withCredentials { credentials in
            observedToken = credentials.accessToken
            #expect(credentials.accountID == "account-synthetic")
            #expect(credentials.planType == nil)
        }
        #expect(observedToken == jwt("access"))
        #expect(!projection.description.contains("access"))
        #expect(!projection.description.contains("refresh"))
        #expect(!projection.description.contains("account-synthetic"))
        #expect(projection.description == "<CodexRuntimeAuthProjection:redacted>")
    }

    @Test
    func rejectsUnsupportedOrMalformedShapes() throws {
        let objects: [[String: Any]] = [
            ["auth_mode": "apikey", "tokens": [:]],
            ["auth_mode": "chatgpt", "tokens": ["access_token": "bad"]],
            [
                "auth_mode": "chatgpt",
                "tokens": ["access_token": jwt("a"), "account_id": ""],
            ],
            ["auth_mode": "chatgpt"],
        ]
        for object in objects {
            let fixture = try AuthFixture(object: object)
            defer { fixture.remove() }
            #expect(throws: CodexRuntimeAuthProjectionError.self) {
                _ = try CodexRuntimeAuthProjector().read(from: fixture.url)
            }
        }
    }

    @Test
    func rejectsSymlinkWrongModeOwnerAndOversize() throws {
        let fixture = try AuthFixture(
            object: validObject()
        )
        defer { fixture.remove() }

        chmod(fixture.url.path, 0o644)
        #expect(throws: CodexRuntimeAuthProjectionError.invalidMode) {
            _ = try CodexRuntimeAuthProjector().read(from: fixture.url)
        }
        chmod(fixture.url.path, 0o600)

        let link = fixture.root.appending(path: "auth-link.json")
        try FileManager.default.createSymbolicLink(
            at: link,
            withDestinationURL: fixture.url
        )
        #expect(throws: CodexRuntimeAuthProjectionError.invalidFile) {
            _ = try CodexRuntimeAuthProjector().read(from: link)
        }

        let oversized = fixture.root.appending(path: "oversized.json")
        try Data(repeating: 0x41, count: 1_025).write(to: oversized)
        chmod(oversized.path, 0o600)
        #expect(throws: CodexRuntimeAuthProjectionError.fileTooLarge) {
            _ = try CodexRuntimeAuthProjector(
                maximumBytes: 1_024
            ).read(from: oversized)
        }
    }

    @Test
    func sourceIdentityChangeIsDetected() throws {
        let fixture = try AuthFixture(object: validObject())
        defer { fixture.remove() }
        let projector = CodexRuntimeAuthProjector()
        let first = try projector.read(from: fixture.url)

        try Data(
            try JSONSerialization.data(withJSONObject: validObject())
        ).write(to: fixture.url, options: .atomic)
        chmod(fixture.url.path, 0o600)

        #expect(throws: CodexRuntimeAuthProjectionError.identityChanged) {
            _ = try projector.refresh(
                from: fixture.url,
                matching: first.sourceIdentity
            )
        }
    }

    @Test
    func rejectsHardLinkedAuthSource() throws {
        let fixture = try AuthFixture(object: validObject())
        defer { fixture.remove() }
        let alias = fixture.root.appending(path: "auth-alias.json")
        guard link(fixture.url.path, alias.path) == 0 else {
            throw AuthFixtureError.hardlinkFailed
        }

        #expect(throws: CodexRuntimeAuthProjectionError.multipleLinks) {
            _ = try CodexRuntimeAuthProjector().read(from: fixture.url)
        }
    }
}

private func validObject() -> [String: Any] {
    [
        "auth_mode": "chatgpt",
        "tokens": [
            "access_token": jwt("access"),
            "account_id": "synthetic-account",
        ],
    ]
}

private func jwt(_ payload: String) -> String {
    "header.\(Data(payload.utf8).base64EncodedString()).signature"
}

private struct AuthFixture {
    let root: URL
    let url: URL

    init(object: [String: Any]) throws {
        root = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-auth-tests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        url = root.appending(path: "auth.json")
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        try JSONSerialization.data(withJSONObject: object).write(to: url)
        chmod(url.path, 0o600)
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

private enum AuthFixtureError: Error {
    case hardlinkFailed
}
