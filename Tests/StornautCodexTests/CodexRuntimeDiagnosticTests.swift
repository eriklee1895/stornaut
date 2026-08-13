import Foundation
import Testing
@testable import StornautCodex

@Suite("Capability-first runtime diagnostic")
struct CodexRuntimeDiagnosticTests {
    private let profile = CodexRuntimeProfile.capabilityFirstV1Codex0147

    @Test
    func diagnosticRunsOnlyTheClosedProbeSequence() async throws {
        let root = try DiagnosticFixture()
        defer { root.remove() }
        let runner = RecordingRuntimeDiagnosticRunner(
            result: .passingFixture(profileDigest: profile.profileDigest)
        )
        let diagnostic = CodexRuntimeDiagnostic(runner: runner)

        let evidence = try await diagnostic.validate(
            profile: profile,
            executableURL: root.executableURL,
            isolatedRuntimeHomeURL: root.runtimeHomeURL,
            isolatedUserHomeURL: root.userHomeURL,
            isolatedWorkingDirectoryURL: root.workingDirectoryURL,
            inheritedEnvironment: [
                "PATH": ":relative:/usr/bin:/usr/bin:/bin",
                "LANG": "en_US.UTF-8",
                "OPENAI_API_KEY": "must-not-leak",
                "GITHUB_TOKEN": "must-not-leak",
            ]
        )

        #expect(evidence.profileDigest == profile.profileDigest)
        let request = try #require(await runner.requests.first)
        #expect(await runner.requests.count == 1)
        #expect(request.profile == profile)
        #expect(request.executableURL == root.executableURL)
        #expect(request.runtimeHomeURL == root.runtimeHomeURL)
        #expect(request.userHomeURL == root.userHomeURL)
        #expect(request.workingDirectoryURL == root.workingDirectoryURL)
        #expect(request.environment["PATH"] == "/usr/bin:/bin")
        #expect(request.environment["LANG"] == "en_US.UTF-8")
        #expect(request.environment["CODEX_HOME"] == root.runtimeHomeURL.path)
        #expect(request.environment["HOME"] == root.userHomeURL.path)
        #expect(
            request.environment["TMPDIR"]
                == root.runtimeHomeURL.appending(path: "tmp").path
        )
        #expect(request.environment["OPENAI_API_KEY"] == nil)
        #expect(request.environment["GITHUB_TOKEN"] == nil)
    }

    @Test
    func diagnosticRejectsUnsafeTopologyBeforeRunner() async throws {
        let root = try DiagnosticFixture()
        defer { root.remove() }
        let runner = RecordingRuntimeDiagnosticRunner(
            result: .passingFixture(profileDigest: profile.profileDigest)
        )
        let diagnostic = CodexRuntimeDiagnostic(runner: runner)

        await #expect(throws: CodexRuntimeDiagnosticError.self) {
            _ = try await diagnostic.validate(
                profile: profile,
                executableURL: root.executableURL,
                isolatedRuntimeHomeURL: root.workingDirectoryURL,
                isolatedUserHomeURL: root.userHomeURL,
                isolatedWorkingDirectoryURL: root.workingDirectoryURL,
                inheritedEnvironment: [:]
            )
        }
        #expect(await runner.requests.isEmpty)
    }

    @Test
    func diagnosticRejectsWrongProfileDigest() async throws {
        let root = try DiagnosticFixture()
        defer { root.remove() }
        let runner = RecordingRuntimeDiagnosticRunner(
            result: .passingFixture(
                profileDigest: String(repeating: "0", count: 64)
            )
        )
        let diagnostic = CodexRuntimeDiagnostic(runner: runner)

        await #expect(throws: CodexRuntimeDiagnosticError.self) {
            _ = try await diagnostic.validate(
                profile: profile,
                executableURL: root.executableURL,
                isolatedRuntimeHomeURL: root.runtimeHomeURL,
                isolatedUserHomeURL: root.userHomeURL,
                isolatedWorkingDirectoryURL: root.workingDirectoryURL,
                inheritedEnvironment: ["PATH": "/usr/bin:/bin"]
            )
        }
    }

    @Test
    func profileBuildsFixedDiagnosticArguments() {
        let appServer = profile.appServerDiagnosticArguments
        let features = profile.featureDiagnosticArguments
        let prompt = profile.promptInputDiagnosticArguments

        #expect(appServer.last == "--stdio")
        #expect(appServer.contains("app-server"))
        #expect(appServer.contains("--strict-config"))
        #expect(features.suffix(2) == ["features", "list"])
        #expect(!features.contains("--strict-config"))
        #expect(prompt.suffix(2) == ["debug", "prompt-input"])
        #expect(!prompt.contains("--strict-config"))
        #expect(!appServer.contains("mcp-server"))
    }

    @Test
    func diagnosticProcessTimeoutKillsDescendantsAndReturnsBoundedly()
        throws
    {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "StornautDiagnosticProcessTimeout-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        let executableURL = root.appending(path: "descendant-holder.sh")
        let childPIDURL = root.appending(path: "child.pid")
        let script = """
        #!/bin/sh
        /bin/sh -c 'trap "" INT TERM; sleep 30' &
        printf '%s' "$!" > "\(childPIDURL.path)"
        sleep 30
        """
        try Data(script.utf8).write(to: executableURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: executableURL.path
        )

        let started = ContinuousClock.now
        #expect(throws: CodexRuntimeDiagnosticError.timedOut) {
            _ = try FoundationCodexRuntimeDiagnosticProcessRunner().run(
                executableURL: executableURL,
                arguments: [],
                environment: ["PATH": "/usr/bin:/bin"],
                currentDirectoryURL: root,
                standardInput: nil,
                standardOutputLimit: 1_024,
                standardErrorLimit: 1_024,
                timeout: .seconds(3)
            )
        }
        #expect(started.duration(to: .now) < .seconds(8))

        let childPID = try waitForDiagnosticPID(at: childPIDURL)
        #expect(waitForDiagnosticProcessExit(childPID))
    }

    @Test
    func diagnosticProcessNormalExitCannotLeavePipeHoldingDescendant()
        throws
    {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "StornautDiagnosticProcessExit-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        let executableURL = root.appending(path: "exiting-leader.sh")
        let childPIDURL = root.appending(path: "child.pid")
        let script = """
        #!/bin/sh
        /bin/sh -c 'trap "" INT TERM; sleep 30' &
        printf '%s' "$!" > "\(childPIDURL.path)"
        exit 0
        """
        try Data(script.utf8).write(to: executableURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: executableURL.path
        )

        let started = ContinuousClock.now
        let output = try FoundationCodexRuntimeDiagnosticProcessRunner().run(
            executableURL: executableURL,
            arguments: [],
            environment: ["PATH": "/usr/bin:/bin"],
            currentDirectoryURL: root,
            standardInput: nil,
            standardOutputLimit: 1_024,
            standardErrorLimit: 1_024,
            timeout: .seconds(5)
        )
        #expect(output.exitStatus == 0)
        #expect(started.duration(to: .now) < .seconds(8))

        let childPID = try waitForDiagnosticPID(at: childPIDURL)
        #expect(waitForDiagnosticProcessExit(childPID))
    }
}

private actor RecordingRuntimeDiagnosticRunner:
    CodexRuntimeDiagnosticRunning
{
    private(set) var requests: [CodexRuntimeDiagnosticRequest] = []
    private let result: CodexRuntimeDiagnosticEvidence

    init(result: CodexRuntimeDiagnosticEvidence) {
        self.result = result
    }

    func run(
        _ request: CodexRuntimeDiagnosticRequest
    ) async throws -> CodexRuntimeDiagnosticEvidence {
        requests.append(request)
        return result
    }
}

private struct DiagnosticFixture {
    let root: URL
    let executableURL: URL
    let runtimeHomeURL: URL
    let userHomeURL: URL
    let workingDirectoryURL: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(
            path: "StornautRuntimeDiagnosticTests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        executableURL = root.appending(path: "codex")
        runtimeHomeURL = root.appending(
            path: "runtime-home",
            directoryHint: .isDirectory
        )
        userHomeURL = root.appending(
            path: "user-home",
            directoryHint: .isDirectory
        )
        workingDirectoryURL = root.appending(
            path: "work",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: runtimeHomeURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.createDirectory(
            at: userHomeURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.createDirectory(
            at: workingDirectoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executableURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: executableURL.path
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

private func waitForDiagnosticPID(at url: URL) throws -> pid_t {
    let deadline = Date().addingTimeInterval(1)
    while Date() < deadline {
        if
            let text = try? String(contentsOf: url, encoding: .utf8),
            let pid = pid_t(text)
        {
            return pid
        }
        usleep(5_000)
    }
    throw DiagnosticProcessTestError.missingChildPID
}

private func waitForDiagnosticProcessExit(_ pid: pid_t) -> Bool {
    let deadline = Date().addingTimeInterval(1)
    while Date() < deadline {
        if kill(pid, 0) != 0, errno == ESRCH {
            return true
        }
        usleep(5_000)
    }
    return false
}

private enum DiagnosticProcessTestError: Error {
    case missingChildPID
}
