import Foundation
import Testing
@testable import StornautCore

@Test
func actionPolicyGateAllowsAStableInactivePath() throws {
    let fixture = try ActionPolicyFixture()
    defer { fixture.remove() }
    let targetURL = fixture.rootURL.appending(path: "cache")
    try fixture.write(Data("cache".utf8), to: targetURL)
    let identity = try #require(ActionFileIdentity.read(at: targetURL))
    let gate = fixture.makeGate()
    let action = CleanupAction.moveToTrash(
        PathAction(targetURL: targetURL, expectedIdentity: identity)
    )

    let token = try gate.preflight(
        action,
        context: ActionPolicyContext(
            allowedRoots: [fixture.rootURL],
            activeURLs: []
        )
    )

    #expect(token.action == action)
    #expect(try gate.revalidate(
        token,
        context: ActionPolicyContext(
            allowedRoots: [fixture.rootURL],
            activeURLs: []
        )
    ) == action)
}

@Test
func actionPolicyGateRejectsRootHomeMountSymlinkDenylistAndActivePaths() throws {
    let fixture = try ActionPolicyFixture()
    defer { fixture.remove() }
    let ordinaryURL = fixture.rootURL.appending(path: "ordinary")
    let mountURL = fixture.rootURL.appending(path: "mount")
    let secretURL = fixture.rootURL.appending(path: ".env")
    let linkURL = fixture.rootURL.appending(path: "link")
    try fixture.write(Data("ordinary".utf8), to: ordinaryURL)
    try fixture.write(Data("mount".utf8), to: mountURL)
    try fixture.write(Data("secret".utf8), to: secretURL)
    try FileManager.default.createSymbolicLink(
        at: linkURL,
        withDestinationURL: ordinaryURL
    )
    let gate = fixture.makeGate(isMountRoot: {
        $0.standardizedFileURL == mountURL.standardizedFileURL
    })

    #expect(throws: ActionPolicyError.filesystemRoot) {
        _ = try gate.preflight(
            .moveToTrash(
                PathAction(
                    targetURL: URL(filePath: "/"),
                    expectedIdentity: .placeholder
                )
            ),
            context: ActionPolicyContext(
                allowedRoots: [URL(filePath: "/")],
                activeURLs: []
            )
        )
    }
    #expect(throws: ActionPolicyError.homeDirectory) {
        _ = try gate.preflight(
            .moveToTrash(
                PathAction(
                    targetURL: fixture.fakeHomeURL,
                    expectedIdentity: .placeholder
                )
            ),
            context: ActionPolicyContext(
                allowedRoots: [fixture.fakeHomeURL],
                activeURLs: []
            )
        )
    }
    #expect(throws: ActionPolicyError.mountRoot) {
        _ = try gate.preflight(
            .moveToTrash(
                PathAction(
                    targetURL: mountURL,
                    expectedIdentity: try #require(
                        ActionFileIdentity.read(at: mountURL)
                    )
                )
            ),
            context: ActionPolicyContext(
                allowedRoots: [fixture.rootURL],
                activeURLs: []
            )
        )
    }
    #expect(throws: ActionPolicyError.symbolicLink) {
        _ = try gate.preflight(
            .moveToTrash(
                PathAction(
                    targetURL: linkURL,
                    expectedIdentity: try #require(
                        ActionFileIdentity.read(at: linkURL)
                    )
                )
            ),
            context: ActionPolicyContext(
                allowedRoots: [fixture.rootURL],
                activeURLs: []
            )
        )
    }
    #expect(throws: ActionPolicyError.sensitivePath) {
        _ = try gate.preflight(
            .moveToTrash(
                PathAction(
                    targetURL: secretURL,
                    expectedIdentity: try #require(
                        ActionFileIdentity.read(at: secretURL)
                    )
                )
            ),
            context: ActionPolicyContext(
                allowedRoots: [fixture.rootURL],
                activeURLs: []
            )
        )
    }
    #expect(throws: ActionPolicyError.activePath) {
        _ = try gate.preflight(
            .moveToTrash(
                PathAction(
                    targetURL: ordinaryURL,
                    expectedIdentity: try #require(
                        ActionFileIdentity.read(at: ordinaryURL)
                    )
                )
            ),
            context: ActionPolicyContext(
                allowedRoots: [fixture.rootURL],
                activeURLs: [ordinaryURL]
            )
        )
    }
}

@Test
func actionPolicyGateRejectsTheAllowedScanRootButAllowsItsDescendant() throws {
    let fixture = try ActionPolicyFixture()
    defer { fixture.remove() }
    let descendantURL = fixture.rootURL.appending(path: "cache")
    try fixture.write(Data("cache".utf8), to: descendantURL)
    let gate = fixture.makeGate()
    let context = ActionPolicyContext(
        allowedRoots: [fixture.rootURL],
        activeURLs: []
    )

    #expect(throws: ActionPolicyError.allowedRoot) {
        _ = try gate.preflight(
            .moveToTrash(
                PathAction(
                    targetURL: fixture.rootURL,
                    expectedIdentity: try #require(
                        ActionFileIdentity.read(at: fixture.rootURL)
                    )
                )
            ),
            context: context
        )
    }
    #expect(throws: Never.self) {
        _ = try gate.preflight(
            .moveToTrash(
                PathAction(
                    targetURL: descendantURL,
                    expectedIdentity: try #require(
                        ActionFileIdentity.read(at: descendantURL)
                    )
                )
            ),
            context: context
        )
    }
    #expect(throws: ActionPolicyError.allowedRoot) {
        _ = try gate.preflight(
            .moveToTrash(
                PathAction(
                    targetURL: fixture.rootURL,
                    expectedIdentity: try #require(
                        ActionFileIdentity.read(at: fixture.rootURL)
                    )
                )
            ),
            context: ActionPolicyContext(
                allowedRoots: [
                    fixture.rootURL.deletingLastPathComponent(),
                    fixture.rootURL,
                ],
                activeURLs: []
            )
        )
    }
}

@Test
func actionPolicyGateAllowsSafeDescendantsWhenHomeIsTheScanRoot() throws {
    let fixture = try ActionPolicyFixture()
    defer { fixture.remove() }
    let targetURL = fixture.fakeHomeURL.appending(
        path: "Library/Caches/pip",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: targetURL,
        withIntermediateDirectories: true
    )
    let gate = fixture.makeGate()

    #expect(throws: Never.self) {
        _ = try gate.preflight(
            .moveToTrash(
                PathAction(
                    targetURL: targetURL,
                    expectedIdentity: try #require(
                        ActionFileIdentity.read(at: targetURL)
                    )
                )
            ),
            context: ActionPolicyContext(
                allowedRoots: [fixture.fakeHomeURL],
                activeURLs: []
            )
        )
    }
}

@Test(arguments: [
    ".aws",
    ".kube",
    "Library/Keychains",
    "private.pem",
])
func actionPolicyGateRejectsPermanentSensitivePaths(
    _ relativePath: String
) throws {
    let fixture = try ActionPolicyFixture()
    defer { fixture.remove() }
    let targetURL = fixture.fakeHomeURL.appending(path: relativePath)
    try fixture.write(Data("sensitive".utf8), to: targetURL)
    let gate = fixture.makeGate()

    #expect(throws: ActionPolicyError.sensitivePath) {
        _ = try gate.preflight(
            .moveToTrash(
                PathAction(
                    targetURL: targetURL,
                    expectedIdentity: try #require(
                        ActionFileIdentity.read(at: targetURL)
                    )
                )
            ),
            context: ActionPolicyContext(
                allowedRoots: [fixture.fakeHomeURL],
                activeURLs: []
            )
        )
    }
}

@Test
func actionPolicyGateRejectsMissingAndChangedIdentityFields() throws {
    let fixture = try ActionPolicyFixture()
    defer { fixture.remove() }
    let targetURL = fixture.rootURL.appending(path: "target")
    try fixture.write(Data("before".utf8), to: targetURL)
    let original = try #require(ActionFileIdentity.read(at: targetURL))
    let gate = fixture.makeGate()
    let context = ActionPolicyContext(
        allowedRoots: [fixture.rootURL],
        activeURLs: []
    )

    #expect(throws: ActionPolicyError.identityChanged) {
        _ = try gate.preflight(
            .moveToTrash(
                PathAction(
                    targetURL: targetURL,
                    expectedIdentity: original.with(size: original.size + 1)
                )
            ),
            context: context
        )
    }
    #expect(throws: ActionPolicyError.missingPath) {
        _ = try gate.preflight(
            .moveToTrash(
                PathAction(
                    targetURL: fixture.rootURL.appending(path: "missing"),
                    expectedIdentity: original
                )
            ),
            context: context
        )
    }

    let token = try gate.preflight(
        .moveToTrash(
            PathAction(targetURL: targetURL, expectedIdentity: original)
        ),
        context: context
    )
    try fixture.write(Data("changed-content".utf8), to: targetURL)
    #expect(throws: ActionPolicyError.identityChanged) {
        _ = try gate.revalidate(token, context: context)
    }
}

@Test
func actionPolicyGateRejectsAdversarialReplacementBeforeExecution() throws {
    let fixture = try ActionPolicyFixture()
    defer { fixture.remove() }
    let targetURL = fixture.rootURL.appending(path: "target")
    let replacementURL = fixture.rootURL.appending(path: "replacement")
    try fixture.write(Data("target".utf8), to: targetURL)
    try fixture.write(Data("replacement".utf8), to: replacementURL)
    let identity = try #require(ActionFileIdentity.read(at: targetURL))
    let gate = fixture.makeGate()
    let token = try gate.preflight(
        .moveToTrash(
            PathAction(targetURL: targetURL, expectedIdentity: identity)
        ),
        context: ActionPolicyContext(
            allowedRoots: [fixture.rootURL],
            activeURLs: []
        )
    )
    try FileManager.default.removeItem(at: targetURL)
    try FileManager.default.createSymbolicLink(
        at: targetURL,
        withDestinationURL: replacementURL
    )

    #expect(throws: ActionPolicyError.symbolicLink) {
        _ = try gate.revalidate(
            token,
            context: ActionPolicyContext(
                allowedRoots: [fixture.rootURL],
                activeURLs: []
            )
        )
    }
    #expect(FileManager.default.fileExists(atPath: replacementURL.path))
}

@Test
func actionPolicyGateRevalidatesAgainstFreshActivityContext() throws {
    let fixture = try ActionPolicyFixture()
    defer { fixture.remove() }
    let targetURL = fixture.rootURL.appending(path: "cache")
    let activeChildURL = targetURL.appending(path: "lock")
    try FileManager.default.createDirectory(
        at: targetURL,
        withIntermediateDirectories: true
    )
    try fixture.write(Data("active".utf8), to: activeChildURL)
    let action = CleanupAction.moveToTrash(
        PathAction(
            targetURL: targetURL,
            expectedIdentity: try #require(
                ActionFileIdentity.read(at: targetURL)
            )
        )
    )
    let gate = fixture.makeGate()
    let initialContext = ActionPolicyContext(
        allowedRoots: [fixture.rootURL],
        activeURLs: []
    )
    let token = try gate.preflight(action, context: initialContext)

    #expect(throws: ActionPolicyError.activePath) {
        _ = try gate.revalidate(
            token,
            context: ActionPolicyContext(
                allowedRoots: [fixture.rootURL],
                activeURLs: [activeChildURL]
            )
        )
    }
}

@Test
func actionPolicyGateAcceptsOnlyRegisteredActionDefinitionsAndModes() throws {
    let fixture = try ActionPolicyFixture()
    defer { fixture.remove() }
    let definition = RegisteredActionDefinition.fakeCleaner(
        executableURL: fixture.executableURL
    )
    let registry = ActionRegistry(definitions: [definition])
    let gate = fixture.makeGate(registry: registry)
    let context = ActionPolicyContext(
        allowedRoots: [fixture.rootURL],
        activeURLs: []
    )

    let token = try gate.preflight(
        .runRegisteredAction(
            RegisteredActionRequest(
                id: definition.id,
                mode: .success
            )
        ),
        context: context
    )
    let invocation = try #require(token.registeredInvocation)
    #expect(invocation.executableURL == fixture.executableURL)
    #expect(invocation.arguments == ["success"])

    #expect(throws: ActionPolicyError.unregisteredAction) {
        _ = try gate.preflight(
            .runRegisteredAction(
                RegisteredActionRequest(
                    id: "agent-supplied-command",
                    mode: .success
                )
            ),
            context: context
        )
    }
}

@Test
func cleanupActionHasNoAgentExecutableOrRawArgumentSurface() throws {
    let action = CleanupAction.runRegisteredAction(
        RegisteredActionRequest(id: "fixture.fake-cleaner", mode: .success)
    )
    let data = try JSONEncoder().encode(action)
    let text = String(decoding: data, as: UTF8.self)

    #expect(!text.contains("executable"))
    #expect(!text.contains("arguments"))
    #expect(!text.contains("rm -rf"))
}

private struct ActionPolicyFixture {
    let parentURL: URL
    let rootURL: URL
    let fakeHomeURL: URL
    let executableURL: URL

    init() throws {
        parentURL = FileManager.default.temporaryDirectory
            .appending(path: "stornaut-action-policy-\(UUID().uuidString)")
        rootURL = parentURL.appending(path: "allowed")
        fakeHomeURL = parentURL.appending(path: "home")
        executableURL = parentURL.appending(path: "fake-cleaner")
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: fakeHomeURL,
            withIntermediateDirectories: true
        )
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executableURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executableURL.path
        )
    }

    func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url)
    }

    func makeGate(
        registry: ActionRegistry = ActionRegistry(definitions: []),
        isMountRoot: @escaping @Sendable (URL) -> Bool = { _ in false }
    ) -> ActionPolicyGate {
        ActionPolicyGate(
            registry: registry,
            homeDirectoryURL: fakeHomeURL,
            isMountRoot: isMountRoot
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: parentURL)
    }
}

private extension ActionFileIdentity {
    static let placeholder = try! ActionFileIdentity(
        device: 0,
        inode: 0,
        mode: 0,
        ownerUserID: 0,
        ownerGroupID: 0,
        size: 0,
        allocatedBytes: 0,
        modificationSeconds: 0,
        modificationNanoseconds: 0
    )

    func with(size: Int64) -> ActionFileIdentity {
        try! ActionFileIdentity(
            device: device,
            inode: inode,
            mode: mode,
            ownerUserID: ownerUserID,
            ownerGroupID: ownerGroupID,
            size: size,
            allocatedBytes: allocatedBytes,
            modificationSeconds: modificationSeconds,
            modificationNanoseconds: modificationNanoseconds
        )
    }
}
