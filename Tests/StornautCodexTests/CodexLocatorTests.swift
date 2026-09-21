import Foundation
import Testing
@testable import StornautCodex

@Test
func configuredExecutableWinsAndIsCanonicalized() async throws {
    let fixture = try CodexLocatorFixture()
    defer { fixture.remove() }

    let configuredTarget = try fixture.makeExecutable(at: "configured/codex-runtime")
    let configuredLink = try fixture.makeSymlink(at: "configured/codex", to: configuredTarget)
    _ = try fixture.makeExecutable(at: "path/codex")
    let knownCandidate = try fixture.makeExecutable(at: "known/codex")
    let locator = CodexLocator(knownCandidateURLs: [knownCandidate])

    let availability = await locator.locate(
        configuredURL: configuredLink,
        environment: ["PATH": fixture.url.appending(path: "path").path]
    )

    let installation = try #require(availability.installation)
    #expect(installation.executableURL == configuredTarget.resolvingSymlinksInPath().standardizedFileURL)
    #expect(installation.source == .configured)
}

@Test
func pathExecutableWinsOverKnownCandidateAndIsCanonicalized() async throws {
    let fixture = try CodexLocatorFixture()
    defer { fixture.remove() }

    let runtime = try fixture.makeExecutable(at: "runtime/codex")
    let pathLink = try fixture.makeSymlink(at: "path/codex", to: runtime)
    let knownCandidate = try fixture.makeExecutable(at: "known/codex")
    let locator = CodexLocator(knownCandidateURLs: [knownCandidate])

    let availability = await locator.locate(
        configuredURL: nil,
        environment: ["PATH": pathLink.deletingLastPathComponent().path]
    )

    let installation = try #require(availability.installation)
    #expect(installation.executableURL == runtime.resolvingSymlinksInPath().standardizedFileURL)
    #expect(installation.source == .environmentPATH)
}

@Test
func configuredFinderAliasIsResolvedBeforeExecutableValidation() async throws {
    let fixture = try CodexLocatorFixture()
    defer { fixture.remove() }

    let target = try fixture.makeExecutable(at: "runtime/codex")
    let alias = try fixture.makeAlias(at: "configured/Codex alias", to: target)
    let locator = CodexLocator(knownCandidateURLs: [])

    let availability = await locator.locate(
        configuredURL: alias,
        environment: [:]
    )

    let installation = try #require(availability.installation)
    #expect(installation.executableURL == target.standardizedFileURL)
    #expect(installation.source == .configured)
}

@Test
func knownCandidateIsUsedAfterConfiguredAndPathCandidatesAreAbsent() async throws {
    let fixture = try CodexLocatorFixture()
    defer { fixture.remove() }

    let knownCandidate = try fixture.makeExecutable(at: "known/codex")
    let locator = CodexLocator(knownCandidateURLs: [knownCandidate])

    let availability = await locator.locate(
        configuredURL: nil,
        environment: ["PATH": fixture.url.appending(path: "missing").path]
    )

    let installation = try #require(availability.installation)
    #expect(installation.executableURL == knownCandidate.standardizedFileURL)
    #expect(installation.source == .knownCandidate)
}

@Test
func defaultKnownCandidatesAreDerivedFromTheProvidedHomeOnly() async throws {
    let fixture = try CodexLocatorFixture()
    defer { fixture.remove() }

    let home = fixture.url.appending(path: "home", directoryHint: .isDirectory)
    let expected = try fixture.makeExecutable(at: "home/.npm-global/bin/codex")
    let locator = CodexLocator()

    let availability = await locator.locate(
        configuredURL: nil,
        environment: [
            "HOME": home.path,
            "PATH": "",
        ]
    )

    let installation = try #require(availability.installation)
    #expect(installation.executableURL == expected.standardizedFileURL)
    #expect(installation.source == .knownCandidate)
}

@Test
func invalidConfiguredExecutableFailsClosedWithoutFallingBack() async throws {
    let fixture = try CodexLocatorFixture()
    defer { fixture.remove() }

    let configuredDirectory = try fixture.makeDirectory(at: "configured/codex")
    let pathExecutable = try fixture.makeExecutable(at: "path/codex")
    let locator = CodexLocator(knownCandidateURLs: [])

    let availability = await locator.locate(
        configuredURL: configuredDirectory,
        environment: ["PATH": pathExecutable.deletingLastPathComponent().path]
    )

    guard case let .unavailable(reason) = availability else {
        Issue.record("An invalid explicit configuration must fail closed")
        return
    }
    #expect(reason == .invalidConfiguredExecutable(configuredDirectory.standardizedFileURL))
}

@Test
func nonFileConfiguredURLFailsClosed() async {
    let configuredURL = URL(string: "https://example.com/codex")!
    let locator = CodexLocator(knownCandidateURLs: [])

    let availability = await locator.locate(
        configuredURL: configuredURL,
        environment: [:]
    )

    #expect(
        availability == .unavailable(
            .invalidConfiguredExecutable(configuredURL.standardizedFileURL)
        )
    )
}

@Test
func pathSearchRejectsDirectoryNonExecutableAndBrokenSymlinkCandidates() async throws {
    let fixture = try CodexLocatorFixture()
    defer { fixture.remove() }

    let directoryCandidate = try fixture.makeDirectory(at: "directory/codex")
    let nonExecutable = try fixture.makeFile(at: "non-executable/codex", permissions: 0o644)
    let brokenTarget = fixture.url.appending(path: "missing/codex-runtime")
    let brokenLink = try fixture.makeSymlink(at: "broken/codex", to: brokenTarget)
    let valid = try fixture.makeExecutable(at: "valid/codex")
    let path = [
        directoryCandidate.deletingLastPathComponent().path,
        nonExecutable.deletingLastPathComponent().path,
        brokenLink.deletingLastPathComponent().path,
        valid.deletingLastPathComponent().path,
    ].joined(separator: ":")

    let availability = await CodexLocator(knownCandidateURLs: []).locate(
        configuredURL: nil,
        environment: ["PATH": path]
    )

    let installation = try #require(availability.installation)
    #expect(installation.executableURL == valid.standardizedFileURL)
    #expect(installation.source == .environmentPATH)
}

@Test
func pathSearchIsBoundedAndIgnoresEmptyEntries() async throws {
    let fixture = try CodexLocatorFixture()
    defer { fixture.remove() }

    let valid = try fixture.makeExecutable(at: "third/codex")
    let path = [
        "",
        fixture.url.appending(path: "first").path,
        fixture.url.appending(path: "second").path,
        valid.deletingLastPathComponent().path,
    ].joined(separator: ":")
    let locator = CodexLocator(
        knownCandidateURLs: [],
        maximumPATHEntries: 2
    )

    let availability = await locator.locate(
        configuredURL: nil,
        environment: ["PATH": path]
    )

    #expect(availability == .unavailable(.notFound))
}

@Test
func pathSearchIgnoresRelativeDirectories() async throws {
    let fixture = try CodexLocatorFixture()
    defer { fixture.remove() }

    _ = try fixture.makeExecutable(at: "relative/codex")
    let locator = CodexLocator(knownCandidateURLs: [])

    let availability = await locator.locate(
        configuredURL: nil,
        environment: ["PATH": "relative"]
    )

    #expect(availability == .unavailable(.notFound))
}

@Test
func knownCandidateSearchIsBounded() async throws {
    let fixture = try CodexLocatorFixture()
    defer { fixture.remove() }

    let valid = try fixture.makeExecutable(at: "third/codex")
    let locator = CodexLocator(
        knownCandidateURLs: [
            fixture.url.appending(path: "first/codex"),
            fixture.url.appending(path: "second/codex"),
            valid,
        ],
        maximumKnownCandidates: 2
    )

    let availability = await locator.locate(
        configuredURL: nil,
        environment: [:]
    )

    #expect(availability == .unavailable(.notFound))
}

private final class CodexLocatorFixture {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appending(path: "StornautCodexLocatorTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func makeExecutable(at relativePath: String) throws -> URL {
        try makeFile(at: relativePath, permissions: 0o755)
    }

    func makeFile(at relativePath: String, permissions: Int) throws -> URL {
        let fileURL = url.appending(path: relativePath)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("#!/bin/false\n".utf8).write(to: fileURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: permissions],
            ofItemAtPath: fileURL.path
        )
        return fileURL
    }

    func makeDirectory(at relativePath: String) throws -> URL {
        let directoryURL = url.appending(path: relativePath, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    func makeSymlink(at relativePath: String, to destinationURL: URL) throws -> URL {
        let linkURL = url.appending(path: relativePath)
        try FileManager.default.createDirectory(
            at: linkURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(
            atPath: linkURL.path,
            withDestinationPath: destinationURL.path
        )
        return linkURL
    }

    func makeAlias(at relativePath: String, to destinationURL: URL) throws -> URL {
        let aliasURL = url.appending(path: relativePath)
        try FileManager.default.createDirectory(
            at: aliasURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let bookmark = try destinationURL.bookmarkData(
            options: .suitableForBookmarkFile,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        try URL.writeBookmarkData(bookmark, to: aliasURL)
        return aliasURL
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}
