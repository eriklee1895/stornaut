import Foundation
import Testing
@testable import StornautCore

@Test
func canonicalPathPolicyAllowsExistingItemsOnlyInsideCanonicalRoots() throws {
    let fixture = try PathPolicyFixture()
    defer { fixture.remove() }
    let policy = CanonicalPathPolicy(homeDirectoryURL: fixture.fakeHomeURL)
    let fileURL = fixture.rootURL.appending(path: "project/README.md")
    try fixture.createFile(at: fileURL)

    let decision = policy.evaluate(
        requestedURL: fileURL,
        allowedRoots: [fixture.rootURL]
    )

    guard case let .allowed(path) = decision else {
        Issue.record("Expected the fixture file to be allowed")
        return
    }
    #expect(path.url.lastPathComponent == "README.md")
    #expect(path.identity.isRegularFile)
}

@Test
func canonicalPathPolicyRejectsTraversalAndSiblingPrefixConfusion() throws {
    let fixture = try PathPolicyFixture()
    defer { fixture.remove() }
    let policy = CanonicalPathPolicy(homeDirectoryURL: fixture.fakeHomeURL)
    let siblingURL = fixture.rootURL
        .deletingLastPathComponent()
        .appending(path: "\(fixture.rootURL.lastPathComponent)-outside/secret.txt")
    try fixture.createFile(at: siblingURL)

    let traversalURL = fixture.rootURL
        .appending(path: "../\(siblingURL.deletingLastPathComponent().lastPathComponent)/secret.txt")

    #expect(policy.evaluate(
        requestedURL: siblingURL,
        allowedRoots: [fixture.rootURL]
    ) == .denied(.outsideAllowedRoots))
    #expect(policy.evaluate(
        requestedURL: traversalURL,
        allowedRoots: [fixture.rootURL]
    ) == .denied(.outsideAllowedRoots))
    #expect(policy.evaluate(
        requestedURL: URL(string: "../relative")!,
        allowedRoots: [fixture.rootURL]
    ) == .denied(.relativePath))
}

@Test
func canonicalPathPolicyResolvesSafeSymlinksAndRejectsEscapingSymlinks() throws {
    let fixture = try PathPolicyFixture()
    defer { fixture.remove() }
    let policy = CanonicalPathPolicy(homeDirectoryURL: fixture.fakeHomeURL)
    let insideURL = fixture.rootURL.appending(path: "inside.txt")
    let outsideURL = fixture.rootURL
        .deletingLastPathComponent()
        .appending(path: "outside.txt")
    let safeLinkURL = fixture.rootURL.appending(path: "safe-link")
    let escapingLinkURL = fixture.rootURL.appending(path: "escaping-link")
    try fixture.createFile(at: insideURL)
    try fixture.createFile(at: outsideURL)
    try FileManager.default.createSymbolicLink(
        at: safeLinkURL,
        withDestinationURL: insideURL
    )
    try FileManager.default.createSymbolicLink(
        at: escapingLinkURL,
        withDestinationURL: outsideURL
    )

    guard case let .allowed(path) = policy.evaluate(
        requestedURL: safeLinkURL,
        allowedRoots: [fixture.rootURL]
    ) else {
        Issue.record("Expected an in-root symlink to resolve safely")
        return
    }
    #expect(path.url == insideURL.resolvingSymlinksInPath())
    #expect(policy.evaluate(
        requestedURL: escapingLinkURL,
        allowedRoots: [fixture.rootURL]
    ) == .denied(.outsideAllowedRoots))
}

@Test
func canonicalPathPolicyFailsClosedForMissingOrProtectedRoots() throws {
    let fixture = try PathPolicyFixture()
    defer { fixture.remove() }
    let mountURL = fixture.rootURL.appending(path: "mounted")
    try FileManager.default.createDirectory(
        at: mountURL,
        withIntermediateDirectories: true
    )
    let policy = CanonicalPathPolicy(
        homeDirectoryURL: fixture.fakeHomeURL,
        isMountRoot: { $0.resolvingSymlinksInPath() == mountURL.resolvingSymlinksInPath() }
    )

    #expect(policy.evaluate(
        requestedURL: fixture.rootURL.appending(path: "missing/child"),
        allowedRoots: [fixture.rootURL]
    ) == .unknown(.pathDoesNotExist))
    #expect(policy.evaluate(
        requestedURL: URL(filePath: "/"),
        allowedRoots: [URL(filePath: "/")]
    ) == .denied(.filesystemRoot))
    #expect(policy.evaluate(
        requestedURL: fixture.fakeHomeURL,
        allowedRoots: [fixture.fakeHomeURL]
    ) == .denied(.homeDirectory))
    #expect(policy.evaluate(
        requestedURL: mountURL,
        allowedRoots: [fixture.rootURL]
    ) == .denied(.mountRoot))
}

@Test
func canonicalPathPolicyHandlesUnicodeAndCaseAccordingToTheVolume() throws {
    let fixture = try PathPolicyFixture()
    defer { fixture.remove() }
    let policy = CanonicalPathPolicy(homeDirectoryURL: fixture.fakeHomeURL)
    let composedName = "Caf\u{00E9}.txt"
    let decomposedName = "Cafe\u{0301}.txt"
    let composedURL = fixture.rootURL.appending(path: composedName)
    let decomposedURL = fixture.rootURL.appending(path: decomposedName)
    try fixture.createFile(at: composedURL)

    guard case .allowed = policy.evaluate(
        requestedURL: decomposedURL,
        allowedRoots: [fixture.rootURL]
    ) else {
        Issue.record("Expected canonically equivalent Unicode to resolve")
        return
    }

    let mixedCaseURL = fixture.rootURL.appending(path: composedName.uppercased())
    let mixedCaseDecision = policy.evaluate(
        requestedURL: mixedCaseURL,
        allowedRoots: [fixture.rootURL]
    )
    if FileManager.default.fileExists(atPath: mixedCaseURL.path) {
        guard case .allowed = mixedCaseDecision else {
            Issue.record("Expected the case-insensitive volume lookup to resolve")
            return
        }
    } else {
        #expect(mixedCaseDecision == .unknown(.pathDoesNotExist))
    }
}

@Test
func canonicalPathPolicyDoesNotTreatFilesystemOrHomeAsBroadAllowedRoots() throws {
    let fixture = try PathPolicyFixture()
    defer { fixture.remove() }
    let policy = CanonicalPathPolicy(homeDirectoryURL: fixture.fakeHomeURL)
    let homeChildURL = fixture.fakeHomeURL.appending(path: "project.txt")
    try fixture.createFile(at: homeChildURL)

    #expect(policy.evaluate(
        requestedURL: fixture.rootURL,
        allowedRoots: [URL(filePath: "/")]
    ) == .denied(.protectedAllowedRoot))
    #expect(policy.evaluate(
        requestedURL: homeChildURL,
        allowedRoots: [fixture.fakeHomeURL]
    ) == .denied(.protectedAllowedRoot))
}

private struct PathPolicyFixture {
    let rootURL: URL
    let fakeHomeURL: URL

    init() throws {
        let parentURL = FileManager.default.temporaryDirectory
            .appending(path: "stornaut-path-policy-\(UUID().uuidString)")
        rootURL = parentURL.appending(path: "allowed")
        fakeHomeURL = parentURL.appending(path: "home")
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: fakeHomeURL,
            withIntermediateDirectories: true
        )
    }

    func createFile(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("fixture".utf8).write(to: url)
    }

    func remove() {
        try? FileManager.default.removeItem(
            at: rootURL.deletingLastPathComponent()
        )
    }
}
