import Foundation
import Testing
@testable import StornautCore

@Test
func gitActivityProviderUsesOnlyFixedReadOnlyRequests() async throws {
    let runner = RecordingGitCommandRunner(outputs: [
        .success(
            GitCommandOutput(
                exitStatus: 0,
                stdout: Data(
                    """
                    # branch.oid 1111111111111111111111111111111111111111
                    # branch.head main
                    # branch.upstream origin/main
                    # branch.ab +0 -0

                    """.utf8
                )
            )
        ),
        .success(
            GitCommandOutput(
                exitStatus: 0,
                stdout: Data("1786310000\n".utf8)
            )
        ),
    ])
    let provider = GitActivityProvider(runner: runner)
    let repositoryURL = URL(
        filePath: "/tmp/stornaut activity fixture",
        directoryHint: .isDirectory
    )

    let snapshot = await provider.collect(
        repositoryURL: repositoryURL,
        observedAt: Date(timeIntervalSince1970: 1_786_310_100)
    )
    let requests = await runner.recordedRequests()

    #expect(snapshot.status == .available)
    #expect(snapshot.isClean == true)
    #expect(snapshot.isUpstreamSynchronized == true)
    #expect(requests.count == 2)
    #expect(requests.allSatisfy {
        $0.executableURL == URL(filePath: "/usr/bin/git")
    })
    #expect(requests.allSatisfy {
        $0.environment == GitActivityProvider.fixedEnvironment
    })
    #expect(requests.allSatisfy {
        $0.standardOutputLimit > 0
            && $0.standardErrorLimit > 0
            && $0.timeout == .seconds(2)
    })
    #expect(
        requests[0].arguments
            == GitActivityProvider.fixedPrefix(for: repositoryURL) + [
                "status",
                "--porcelain=v2",
                "--branch",
                "--untracked-files=normal",
                "--no-renames",
            ]
    )
    #expect(
        requests[1].arguments
            == GitActivityProvider.fixedPrefix(for: repositoryURL) + [
                "log",
                "-1",
                "--format=%ct",
            ]
    )
    #expect(!requests.flatMap(\.arguments).contains(where: {
        ["sh", "bash", "commit", "reset", "checkout"].contains($0)
    }))
}

@Test
func gitActivityFixtureCoversDirtyUntrackedAheadAndMalformedStates() async throws {
    let fixture = try loadGitActivityFixture()

    for fixtureCase in fixture.cases {
        let runner = RecordingGitCommandRunner(outputs: [
            .success(
                GitCommandOutput(
                    exitStatus: 0,
                    stdout: Data(fixtureCase.status.utf8)
                )
            ),
            .success(
                GitCommandOutput(
                    exitStatus: 0,
                    stdout: Data(fixtureCase.lastCommit.utf8)
                )
            ),
        ])
        let snapshot = await GitActivityProvider(runner: runner).collect(
            repositoryURL: URL(
                filePath: "/tmp/\(fixtureCase.id)",
                directoryHint: .isDirectory
            ),
            observedAt: Date(timeIntervalSince1970: 1_786_310_500)
        )

        #expect(
            snapshot.status == (
                fixtureCase.expected.valid
                    ? .available
                    : .unavailable(.malformedOutput)
            ),
            "Unexpected provider status for \(fixtureCase.id)"
        )
        if fixtureCase.expected.valid {
            #expect(
                snapshot.hasStagedChanges == fixtureCase.expected.staged,
                "Unexpected staged state for \(fixtureCase.id)"
            )
            #expect(
                snapshot.hasModifiedFiles == fixtureCase.expected.modified,
                "Unexpected modified state for \(fixtureCase.id)"
            )
            #expect(
                snapshot.hasUntrackedFiles == fixtureCase.expected.untracked,
                "Unexpected untracked state for \(fixtureCase.id)"
            )
            #expect(
                (snapshot.upstream != nil) == fixtureCase.expected.upstream,
                "Unexpected upstream state for \(fixtureCase.id)"
            )
            #expect(snapshot.aheadCount == fixtureCase.expected.ahead)
            #expect(snapshot.behindCount == fixtureCase.expected.behind)
        }
    }
}

@Test
func gitActivityFailureAndTruncationNeverBecomeClean() async {
    for outputs in [
        [
            GitCommandTestResult.failure(.timedOut),
            .success(
                GitCommandOutput(
                    exitStatus: 0,
                    stdout: Data("1786310000\n".utf8)
                )
            ),
        ],
        [
            .success(
                GitCommandOutput(
                    exitStatus: 1,
                    stdout: Data(),
                    stderr: Data("permission denied".utf8)
                )
            ),
            .success(
                GitCommandOutput(
                    exitStatus: 0,
                    stdout: Data("1786310000\n".utf8)
                )
            ),
        ],
        [
            .success(
                GitCommandOutput(
                    exitStatus: 0,
                    stdout: Data("# branch.head main\n".utf8),
                    stdoutWasTruncated: true
                )
            ),
            .success(
                GitCommandOutput(
                    exitStatus: 0,
                    stdout: Data("1786310000\n".utf8)
                )
            ),
        ],
    ] {
        let snapshot = await GitActivityProvider(
            runner: RecordingGitCommandRunner(outputs: outputs)
        ).collect(
            repositoryURL: URL(filePath: "/tmp/git-failure"),
            observedAt: Date(timeIntervalSince1970: 1_786_310_500)
        )

        #expect(snapshot.status != .available)
        #expect(snapshot.isClean == nil)
        #expect(
            snapshot.observations.first {
                $0.key == .gitClean
            }?.state == .unavailable
        )
    }
}

@Test
func gitLastCommitFailurePreservesValidWorkingTreeEvidence() async {
    let runner = RecordingGitCommandRunner(outputs: [
        .success(
            GitCommandOutput(
                exitStatus: 0,
                stdout: Data(
                    """
                    # branch.oid 1111111111111111111111111111111111111111
                    # branch.head main
                    # branch.upstream origin/main
                    # branch.ab +0 -0
                    ? local.txt

                    """.utf8
                )
            )
        ),
        .failure(.timedOut),
    ])

    let snapshot = await GitActivityProvider(runner: runner).collect(
        repositoryURL: URL(filePath: "/tmp/git-partial"),
        observedAt: Date(timeIntervalSince1970: 1_786_310_500)
    )

    #expect(snapshot.status == .available)
    #expect(snapshot.hasUntrackedFiles == true)
    #expect(snapshot.isClean == false)
    #expect(snapshot.lastCommitAt == nil)
    #expect(snapshot.lastCommitStatus == .unavailable(.timedOut))
}

@Test
func gitActivityProviderDoesNotMutateARealRepository() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "stornaut-git-activity-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    try runFixtureGit(["init", "--quiet"], at: root)
    try runFixtureGit(
        ["config", "user.name", "Stornaut Fixture"],
        at: root
    )
    try runFixtureGit(
        ["config", "user.email", "fixture@example.invalid"],
        at: root
    )
    let trackedURL = root.appending(path: "tracked.txt")
    try Data("initial\n".utf8).write(to: trackedURL)
    try runFixtureGit(["add", "tracked.txt"], at: root)
    try runFixtureGit(["commit", "--quiet", "-m", "initial"], at: root)
    try Data("initial\ndirty\n".utf8).write(to: trackedURL)
    try Data("untracked\n".utf8).write(
        to: root.appending(path: "untracked.txt")
    )
    let before = try repositoryState(at: root)

    let snapshot = await GitActivityProvider().collect(
        repositoryURL: root,
        observedAt: Date(timeIntervalSince1970: 1_786_310_500)
    )

    #expect(snapshot.status == .available)
    #expect(snapshot.hasModifiedFiles == true)
    #expect(snapshot.hasUntrackedFiles == true)
    #expect(snapshot.isClean == false)
    #expect(snapshot.lastCommitAt != nil)
    #expect(try repositoryState(at: root) == before)
}

@Test
func gitActivityInvalidInputFailsWithoutLaunching() async {
    let runner = RecordingGitCommandRunner(outputs: [])
    let result = await GitActivityProvider(runner: runner).collect(
        repositoryURL: URL(string: "https://example.invalid/repository")!,
        observedAt: Date(timeIntervalSince1970: 1)
    )

    #expect(result.status == .unavailable(.invalidInput))
    #expect(result.isClean == nil)
    #expect(await runner.recordedRequests().isEmpty)
}

private actor RecordingGitCommandRunner: GitCommandRunning {
    private var outputs: [GitCommandTestResult]
    private var requests: [GitCommandRequest] = []

    init(outputs: [GitCommandTestResult]) {
        self.outputs = outputs
    }

    func run(_ request: GitCommandRequest) async throws -> GitCommandOutput {
        requests.append(request)
        guard !outputs.isEmpty else {
            throw GitCommandRunnerError.outputReadFailed
        }
        switch outputs.removeFirst() {
        case let .success(output):
            return output
        case let .failure(error):
            throw error
        }
    }

    func recordedRequests() -> [GitCommandRequest] {
        requests
    }
}

private enum GitCommandTestResult: Sendable {
    case success(GitCommandOutput)
    case failure(GitCommandRunnerError)
}

private struct GitActivityFixture: Decodable {
    let schemaVersion: Int
    let cases: [GitActivityFixtureCase]
}

private struct GitActivityFixtureCase: Decodable {
    let id: String
    let status: String
    let lastCommit: String
    let expected: Expected

    struct Expected: Decodable {
        let staged: Bool
        let modified: Bool
        let untracked: Bool
        let upstream: Bool
        let ahead: Int?
        let behind: Int?
        let valid: Bool
    }
}

private func loadGitActivityFixture() throws -> GitActivityFixture {
    let url = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Fixtures/Activity/git-status-cases.json")
    let fixture = try JSONDecoder().decode(
        GitActivityFixture.self,
        from: Data(contentsOf: url)
    )
    #expect(fixture.schemaVersion == 1)
    return fixture
}

private struct GitRepositoryEntry: Equatable {
    let identity: FileIdentity
    let content: Data?
}

private func repositoryState(
    at root: URL
) throws -> [String: GitRepositoryEntry] {
    let keys: [URLResourceKey] = [
        .isDirectoryKey,
        .isRegularFileKey,
    ]
    let enumerator = try #require(
        FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: []
        )
    )
    var result: [String: GitRepositoryEntry] = [:]
    for case let url as URL in enumerator {
        let values = try url.resourceValues(forKeys: Set(keys))
        let relative = String(
            url.path.dropFirst(root.path.count + 1)
        )
        result[relative] = GitRepositoryEntry(
            identity: try #require(FileIdentity.read(at: url)),
            content: values.isRegularFile == true
                ? try Data(contentsOf: url)
                : nil
        )
    }
    return result
}

private func runFixtureGit(
    _ arguments: [String],
    at repositoryURL: URL
) throws {
    let process = Process()
    let errors = Pipe()
    process.executableURL = URL(filePath: "/usr/bin/git")
    process.arguments = ["-C", repositoryURL.path] + arguments
    process.environment = [
        "GIT_CONFIG_GLOBAL": "/dev/null",
        "GIT_CONFIG_NOSYSTEM": "1",
        "GIT_CONFIG_SYSTEM": "/dev/null",
        "HOME": "/var/empty",
        "LANG": "C",
        "LC_ALL": "C",
        "PATH": "/usr/bin:/bin",
    ]
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = errors
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw GitFixtureError.commandFailed(
            String(
                decoding: errors.fileHandleForReading.readDataToEndOfFile(),
                as: UTF8.self
            )
        )
    }
}

private enum GitFixtureError: Error {
    case commandFailed(String)
}
