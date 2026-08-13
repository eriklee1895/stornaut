import Foundation
import Testing
@testable import StornautCodex

@Test
func executionTimeFixtureReportsSyntacticFlagSupportIndependently() throws {
    let versionOutput = try codexFixture(named: "codex-version-0.147.0.txt")
    let helpOutput = try codexFixture(named: "codex-exec-help-0.147.0.txt")
    let executableURL = URL(filePath: "/opt/stornaut-fixtures/codex")

    let report = CodexCapabilityParser.parse(
        executableURL: executableURL,
        versionOutput: versionOutput,
        execHelpOutput: helpOutput
    )

    #expect(report.executableURL == executableURL)
    #expect(report.version == "codex-cli 0.147.0")
    for option in CodexExecOption.allCases {
        #expect(
            report.optionSupport[option] == .supported,
            "Expected fixture to advertise \(option)"
        )
    }
}

@Test
func historicalFixtureIsParsedAsEvidenceRatherThanVersionPolicy() throws {
    let historicalHelp = try codexFixture(named: "codex-exec-help-0.146.0.txt")
    let report = CodexCapabilityParser.parse(
        executableURL: URL(filePath: "/opt/stornaut-fixtures/codex"),
        versionOutput: "codex-cli 99.0.0\n",
        execHelpOutput: historicalHelp
    )

    #expect(report.version == "codex-cli 99.0.0")
    #expect(report.optionSupport[.structuredJSONL] == .supported)
    #expect(report.optionSupport[.outputSchema] == .supported)
    #expect(report.optionSupport[.readOnlySandbox] == .supported)
    #expect(report.optionSupport[.strictConfig] == .supported)
}

@Test
func optionsAreParsedIndependentlyFromTheSameVersion() throws {
    let help = try codexFixture(named: "codex-exec-help-0.147.0.txt")
        .replacingOccurrences(of: "--output-schema", with: "--removed-output-schema")
        .replacingOccurrences(of: "--ignore-rules", with: "--removed-ignore-rules")

    let report = CodexCapabilityParser.parse(
        executableURL: URL(filePath: "/opt/stornaut-fixtures/codex"),
        versionOutput: "codex-cli 0.147.0\n",
        execHelpOutput: help
    )

    #expect(report.optionSupport[.structuredJSONL] == .supported)
    #expect(report.optionSupport[.outputSchema]?.isUnsupported == true)
    #expect(report.optionSupport[.ignoreRules]?.isUnsupported == true)
    #expect(report.optionSupport[.ephemeral] == .supported)
}

@Test
func optionNamesMentionedOnlyInProseAreNotSupported() throws {
    let help = try codexFixture(named: "codex-exec-help-0.147.0.txt")
        .replacingOccurrences(
            of: "      --json\n",
            with: "          This prose mentions --json\n"
        )

    let report = CodexCapabilityParser.parse(
        executableURL: URL(filePath: "/opt/stornaut-fixtures/codex"),
        versionOutput: "codex-cli 0.147.0\n",
        execHelpOutput: help
    )

    #expect(report.optionSupport[.structuredJSONL]?.isUnsupported == true)
}

@Test
func taskThreeNeverPromotesBehavioralIsolationFromHelpText() throws {
    let report = CodexCapabilityParser.parse(
        executableURL: URL(filePath: "/opt/stornaut-fixtures/codex"),
        versionOutput: try codexFixture(named: "codex-version-0.147.0.txt"),
        execHelpOutput: try codexFixture(named: "codex-exec-help-0.147.0.txt")
    )

    for behavior in CodexBehavior.allCases {
        #expect(
            report.behaviorVerdicts[behavior]?.isUnverified == true,
            "\(behavior) requires behavioral evidence from Tasks 4–5"
        )
    }
}

@Test
func missingSyntacticPrerequisiteMakesTheRelatedBehaviorUnsupported() throws {
    let help = try codexFixture(named: "codex-exec-help-0.147.0.txt")
        .replacingOccurrences(of: "--json", with: "--removed-json")
        .replacingOccurrences(of: "--ignore-rules", with: "--removed-ignore-rules")

    let report = CodexCapabilityParser.parse(
        executableURL: URL(filePath: "/opt/stornaut-fixtures/codex"),
        versionOutput: "codex-cli 0.147.0\n",
        execHelpOutput: help
    )

    #expect(report.behaviorVerdicts[.structuredJSONL]?.isUnsupported == true)
    #expect(report.behaviorVerdicts[.ruleAndInstructionIsolation]?.isUnsupported == true)
}

@Test
func malformedHelpFailsClosed() {
    let report = CodexCapabilityParser.parse(
        executableURL: URL(filePath: "/opt/stornaut-fixtures/codex"),
        versionOutput: "codex-cli 0.147.0\n",
        execHelpOutput: "--json --ephemeral --sandbox read-only"
    )

    for option in CodexExecOption.allCases {
        #expect(report.optionSupport[option]?.isUnsupported == true)
    }
    for behavior in CodexBehavior.allCases {
        #expect(report.behaviorVerdicts[behavior]?.isUnsupported == true)
    }
}

@Test
func contradictoryDuplicateHelpOptionFailsClosed() throws {
    let help = try codexFixture(named: "codex-exec-help-0.147.0.txt")
        + "\n      --json\n          Contradictory duplicate option declaration\n"

    let report = CodexCapabilityParser.parse(
        executableURL: URL(filePath: "/opt/stornaut-fixtures/codex"),
        versionOutput: "codex-cli 0.147.0\n",
        execHelpOutput: help
    )

    for option in CodexExecOption.allCases {
        #expect(report.optionSupport[option]?.isUnsupported == true)
    }
    for behavior in CodexBehavior.allCases {
        #expect(report.behaviorVerdicts[behavior]?.isUnsupported == true)
    }
}

@Test
func readOnlySandboxRequiresTheDocumentedSelectorValue() throws {
    let help = try codexFixture(named: "codex-exec-help-0.147.0.txt")
        .replacingOccurrences(
            of: "[possible values: read-only, workspace-write, danger-full-access]",
            with: "[possible values: workspace-write, danger-full-access]"
        )

    let report = CodexCapabilityParser.parse(
        executableURL: URL(filePath: "/opt/stornaut-fixtures/codex"),
        versionOutput: "codex-cli 0.147.0\n",
        execHelpOutput: help
    )

    #expect(report.optionSupport[.readOnlySandbox]?.isUnsupported == true)
    #expect(report.optionSupport[.structuredJSONL] == .supported)
}

@Test
func readOnlyMentionOutsidePossibleValuesDoesNotEstablishSupport() throws {
    let help = try codexFixture(named: "codex-exec-help-0.147.0.txt")
        .replacingOccurrences(
            of: "[possible values: read-only, workspace-write, danger-full-access]",
            with: "read-only is discussed here but no selector values are declared"
        )

    let report = CodexCapabilityParser.parse(
        executableURL: URL(filePath: "/opt/stornaut-fixtures/codex"),
        versionOutput: "codex-cli 0.147.0\n",
        execHelpOutput: help
    )

    #expect(report.optionSupport[.readOnlySandbox]?.isUnsupported == true)
}

@Test
func detectorUsesOnlyFixedProbeCommandsAndSanitizesEnvironment() async throws {
    let executableURL = try makeCapabilityExecutable()
    defer { try? FileManager.default.removeItem(at: executableURL.deletingLastPathComponent()) }
    let runner = RecordingProcessRunner(
        outputs: [
            ProcessOutput(exitStatus: 0, stdout: Data("codex-cli 0.147.0\n".utf8)),
            ProcessOutput(
                exitStatus: 0,
                stdout: Data(try codexFixture(named: "codex-exec-help-0.147.0.txt").utf8)
            ),
        ]
    )
    let detector = CodexCapabilityDetector(processRunner: runner)

    let report = try await detector.report(
        executableURL: executableURL,
        environment: [
            "PATH": ":relative:/usr/bin:/usr/bin:/bin",
            "HOME": "/Users/example",
            "TMPDIR": "/tmp/example",
            "LANG": "en_US.UTF-8",
            "OPENAI_API_KEY": "must-not-leak",
            "GITHUB_TOKEN": "must-not-leak",
        ]
    )

    let requests = await runner.requests
    #expect(requests.count == 2)
    #expect(requests[0].executableURL == executableURL)
    #expect(requests[0].arguments == ["--version"])
    #expect(requests[1].arguments == ["exec", "--help"])
    #expect(requests.allSatisfy { $0.standardInput.isEmpty })
    #expect(requests.allSatisfy { $0.environment["PATH"] == "/usr/bin:/bin" })
    #expect(requests.allSatisfy { $0.environment["HOME"] == "/Users/example" })
    #expect(requests.allSatisfy { $0.environment["OPENAI_API_KEY"] == nil })
    #expect(requests.allSatisfy { $0.environment["GITHUB_TOKEN"] == nil })
    #expect(report.version == "codex-cli 0.147.0")
}

@Test
func detectorCachesHelpOnlyForTheSameExecutableIdentityAndVersion() async throws {
    let executableURL = try makeCapabilityExecutable()
    defer { try? FileManager.default.removeItem(at: executableURL.deletingLastPathComponent()) }
    let help = try codexFixture(named: "codex-exec-help-0.147.0.txt")
    let runner = RecordingProcessRunner(
        outputs: [
            ProcessOutput(exitStatus: 0, stdout: Data("codex-cli 0.147.0\n".utf8)),
            ProcessOutput(exitStatus: 0, stdout: Data(help.utf8)),
            ProcessOutput(exitStatus: 0, stdout: Data("codex-cli 0.147.0\n".utf8)),
        ]
    )
    let detector = CodexCapabilityDetector(processRunner: runner)

    let first = try await detector.report(executableURL: executableURL, environment: [:])
    let second = try await detector.report(executableURL: executableURL, environment: [:])

    #expect(first == second)
    let requests = await runner.requests
    #expect(requests.map(\.arguments) == [["--version"], ["exec", "--help"], ["--version"]])
}

@Test
func detectorReprobesHelpWhenTheVersionChanges() async throws {
    let executableURL = try makeCapabilityExecutable()
    defer { try? FileManager.default.removeItem(at: executableURL.deletingLastPathComponent()) }
    let help = try codexFixture(named: "codex-exec-help-0.147.0.txt")
    let runner = RecordingProcessRunner(
        outputs: [
            ProcessOutput(exitStatus: 0, stdout: Data("codex-cli 0.146.0\n".utf8)),
            ProcessOutput(exitStatus: 0, stdout: Data(help.utf8)),
            ProcessOutput(exitStatus: 0, stdout: Data("codex-cli 0.147.0\n".utf8)),
            ProcessOutput(exitStatus: 0, stdout: Data(help.utf8)),
        ]
    )
    let detector = CodexCapabilityDetector(processRunner: runner)

    let first = try await detector.report(executableURL: executableURL, environment: [:])
    let second = try await detector.report(executableURL: executableURL, environment: [:])

    #expect(first.version == "codex-cli 0.146.0")
    #expect(second.version == "codex-cli 0.147.0")
    let requests = await runner.requests
    #expect(
        requests.map(\.arguments) == [
            ["--version"],
            ["exec", "--help"],
            ["--version"],
            ["exec", "--help"],
        ]
    )
}

@Test
func detectorRejectsNonzeroProbeExit() async throws {
    let executableURL = try makeCapabilityExecutable()
    defer { try? FileManager.default.removeItem(at: executableURL.deletingLastPathComponent()) }
    let runner = RecordingProcessRunner(
        outputs: [
            ProcessOutput(
                exitStatus: 2,
                stdout: Data(),
                stderr: Data("probe failed".utf8)
            ),
        ]
    )
    let detector = CodexCapabilityDetector(processRunner: runner)

    await #expect(throws: CodexCapabilityProbeError.self) {
        _ = try await detector.report(executableURL: executableURL, environment: [:])
    }
}

@Test
func detectorRejectsTruncatedProbeOutput() async throws {
    let executableURL = try makeCapabilityExecutable()
    defer { try? FileManager.default.removeItem(at: executableURL.deletingLastPathComponent()) }
    let runner = RecordingProcessRunner(
        outputs: [
            ProcessOutput(
                exitStatus: 0,
                stdout: Data("codex-cli 0.147.0".utf8),
                stdoutWasTruncated: true
            ),
        ]
    )
    let detector = CodexCapabilityDetector(processRunner: runner)

    await #expect(throws: CodexCapabilityProbeError.self) {
        _ = try await detector.report(executableURL: executableURL, environment: [:])
    }
}

@Test
func foundationProcessRunnerCapsOutputWithoutUsingAShell() async throws {
    let request = ProcessRequest(
        executableURL: URL(filePath: "/usr/bin/printf"),
        arguments: ["1234567890"],
        environment: ["PATH": "/usr/bin:/bin"],
        standardOutputLimit: 4,
        standardErrorLimit: 4,
        timeout: .seconds(2)
    )

    let output = try await FoundationProcessRunner().run(request)

    #expect(output.exitStatus == 0)
    #expect(String(decoding: output.stdout, as: UTF8.self) == "1234")
    #expect(output.stdoutWasTruncated)
    #expect(output.stderr.isEmpty)
    #expect(!output.stderrWasTruncated)
}

@Test
func foundationProcessRunnerRejectsStandardInputUntilTaskFour() async {
    let request = ProcessRequest(
        executableURL: URL(filePath: "/bin/cat"),
        arguments: [],
        environment: ["PATH": "/usr/bin:/bin"],
        standardInput: Data("probe-input".utf8),
        standardOutputLimit: 32,
        standardErrorLimit: 32,
        timeout: .seconds(2)
    )

    await #expect(throws: ProcessRunningError.standardInputUnsupported) {
        _ = try await FoundationProcessRunner().run(request)
    }
}

@Test
func foundationProcessRunnerCapsStandardError() async throws {
    let missingPath = URL.temporaryDirectory
        .appending(path: "stornaut-missing-\(UUID().uuidString)")
        .path()
    let request = ProcessRequest(
        executableURL: URL(filePath: "/bin/ls"),
        arguments: ["-d", missingPath],
        environment: ["PATH": "/usr/bin:/bin", "LC_ALL": "C"],
        standardOutputLimit: 4,
        standardErrorLimit: 3,
        timeout: .seconds(2)
    )

    let output = try await FoundationProcessRunner().run(request)

    #expect(output.exitStatus != 0)
    #expect(output.stdout.isEmpty)
    #expect(String(decoding: output.stderr, as: UTF8.self) == "ls:")
    #expect(output.stderrWasTruncated)
}

@Test
func foundationProcessRunnerTimesOut() async {
    let request = ProcessRequest(
        executableURL: URL(filePath: "/bin/sleep"),
        arguments: ["2"],
        environment: ["PATH": "/usr/bin:/bin"],
        standardOutputLimit: 32,
        standardErrorLimit: 32,
        timeout: .milliseconds(20)
    )

    await #expect(throws: ProcessRunningError.timedOut) {
        _ = try await FoundationProcessRunner().run(request)
    }
}

@Test
func foundationProcessRunnerTreatsNegativeTimeoutAsImmediate() async {
    let request = ProcessRequest(
        executableURL: URL(filePath: "/bin/sleep"),
        arguments: ["2"],
        environment: ["PATH": "/usr/bin:/bin"],
        standardOutputLimit: 32,
        standardErrorLimit: 32,
        timeout: .milliseconds(-1)
    )

    await #expect(throws: ProcessRunningError.timedOut) {
        _ = try await FoundationProcessRunner().run(request)
    }
}

@Test
func foundationProcessRunnerNormalExitKillsDescendants() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "StornautProcessRunnerTimeout-\(UUID().uuidString)",
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
    exit 0
    """
    try Data(script.utf8).write(to: executableURL)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o700],
        ofItemAtPath: executableURL.path
    )
    let request = ProcessRequest(
        executableURL: executableURL,
        arguments: [],
        environment: ["PATH": "/usr/bin:/bin"],
        currentDirectoryURL: root,
        standardOutputLimit: 32,
        standardErrorLimit: 32,
        timeout: .seconds(5)
    )

    let started = ContinuousClock.now
    let output = try await FoundationProcessRunner().run(request)
    #expect(output.exitStatus == 0)
    #expect(started.duration(to: .now) < .seconds(10))

    let childPID = try waitForProcessRunnerPID(at: childPIDURL)
    defer { kill(childPID, SIGKILL) }
    #expect(waitForProcessRunnerExit(childPID))
}

@Test
func foundationProcessRunnerReturnsNonzeroExitForTheCallerToInterpret() async throws {
    let request = ProcessRequest(
        executableURL: URL(filePath: "/usr/bin/false"),
        arguments: [],
        environment: ["PATH": "/usr/bin:/bin"],
        standardOutputLimit: 32,
        standardErrorLimit: 32,
        timeout: .seconds(2)
    )

    let output = try await FoundationProcessRunner().run(request)

    #expect(output.exitStatus != 0)
}

private func waitForProcessRunnerPID(at url: URL) throws -> pid_t {
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
    throw ProcessRunnerTestError.missingChildPID
}

private func waitForProcessRunnerExit(_ pid: pid_t) -> Bool {
    let deadline = Date().addingTimeInterval(1)
    while Date() < deadline {
        if kill(pid, 0) != 0, errno == ESRCH {
            return true
        }
        usleep(5_000)
    }
    return false
}

private enum ProcessRunnerTestError: Error {
    case missingChildPID
}

private actor RecordingProcessRunner: ProcessRunning {
    private(set) var requests: [ProcessRequest] = []
    private var outputs: [ProcessOutput]

    init(outputs: [ProcessOutput]) {
        self.outputs = outputs
    }

    func run(_ request: ProcessRequest) async throws -> ProcessOutput {
        requests.append(request)
        guard !outputs.isEmpty else {
            throw RecordingProcessRunnerError.missingOutput
        }
        return outputs.removeFirst()
    }
}

private enum RecordingProcessRunnerError: Error {
    case missingOutput
}

private func codexFixture(named name: String) throws -> String {
    let fixtureURL = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Fixtures/Codex")
        .appending(path: name)
    return try String(contentsOf: fixtureURL, encoding: .utf8)
}

private func makeCapabilityExecutable() throws -> URL {
    let directoryURL = FileManager.default.temporaryDirectory
        .appending(path: "StornautCodexCapabilityTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    let executableURL = directoryURL.appending(path: "codex")
    try Data("#!/bin/false\n".utf8).write(to: executableURL)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o755],
        ofItemAtPath: executableURL.path
    )
    return executableURL
}
