import Darwin
import Foundation
import Testing
@testable import StornautCore
@testable import StornautCodex
import StornautExecution

@Test
func successfulFakeProcessUsesFixedProtocolArgumentsAndSeparatesStderr() async throws {
    let fixture = try CodexProcessFixture(mode: "success")
    defer { fixture.remove() }

    let request = fixture.makeRequest(
        prompt: Data("Return only the static envelope.".utf8),
        timeout: .seconds(10),
        environment: [
            "HOME": "/Users/example",
            "PATH": "/usr/bin:/bin",
            "TMPDIR": fixture.root.path,
            "LANG": "en_US.UTF-8",
            "OPENAI_API_KEY": "must-not-leak",
            "GITHUB_TOKEN": "must-not-leak",
        ]
    )

    let events = try await collectEvents(from: CodexProcess().run(request))

    #expect(events.contains(.started))
    #expect(events.contains { event in
        guard case .stderr(.received(byteCount: 16)) = event else {
            return false
        }
        return true
    })
    #expect(events.contains(.unknown(type: "future.event", metadata: [
        "phase": "fake",
        "sequence": "7",
    ])))
    #expect(events.contains(.completed(
        InvestigationEnvelope(
            summary: "Static fake result",
            findings: [],
            unresolvedTargetIDs: []
        )
    )))
    #expect(events.allSatisfy { event in
        guard case let .protocolEvent(.itemCompleted(item)) = event else {
            return true
        }
        return item.agentMessageText == nil
    })

    let arguments = try fixture.recordedLines(named: "arguments.txt")
    let expectedArguments = try CodexRuntimeProfile
        .capabilityFirstV1Codex0147
        .execArguments(
            schemaURL: fixture.schemaURL,
            workingDirectoryURL: fixture.workingDirectoryURL
        )
    #expect(arguments == expectedArguments)
    #expect(arguments.first == "--strict-config")
    let searchIndex = try #require(arguments.firstIndex(of: "--search"))
    let execIndex = try #require(arguments.firstIndex(of: "exec"))
    #expect(searchIndex < execIndex)
    #expect(!arguments.contains("--sandbox"))
    #expect(!arguments.contains("read-only"))
    #expect(!arguments.contains("features.shell_tool=false"))
    #expect(!arguments.contains("features.unified_exec=false"))
    #expect(!arguments.contains("features.browser_use=false"))
    #expect(!arguments.contains("features.hooks=false"))
    #expect(try fixture.recordedString(named: "stdin.txt") == "Return only the static envelope.")
    let recordedWorkingDirectory = URL(
        filePath: try fixture.recordedString(named: "cwd.txt")
            .trimmingCharacters(in: .whitespacesAndNewlines),
        directoryHint: .isDirectory
    )
    #expect(
        recordedWorkingDirectory.resolvingSymlinksInPath()
            == fixture.workingDirectoryURL.resolvingSymlinksInPath()
    )

    let environment = try fixture.recordedLines(named: "environment.txt")
    #expect(environment.contains("HOME=/Users/example"))
    #expect(environment.contains("PATH=/usr/bin:/bin"))
    #expect(environment.contains("LANG=en_US.UTF-8"))
    #expect(!environment.contains(where: { $0.hasPrefix("OPENAI_API_KEY=") }))
    #expect(!environment.contains(where: { $0.hasPrefix("GITHUB_TOKEN=") }))
}

@Test
func concurrentSpawnsDoNotInheritSiblingPipes() async throws {
    let fixtures = try (0..<7).map { _ in
        try CodexProcessFixture(mode: "success")
    }
    defer {
        for fixture in fixtures {
            fixture.remove()
        }
    }

    let actionURL = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Tests/Fixtures/Actions/fake-cleaner.sh")
    let invocation = RegisteredActionInvocation(
        id: "fixture.fake-cleaner",
        mode: .success,
        executableURL: actionURL,
        arguments: ["success"],
        environment: [
            "LANG": "C",
            "LC_ALL": "C",
            "PATH": "/usr/bin:/bin",
        ],
        timeout: .seconds(2),
        standardOutputLimit: 16_384,
        standardErrorLimit: 4_096
    )

    async let codexResults = withThrowingTaskGroup(
        of: [CodexProcessEvent].self
    ) { group in
        for fixture in fixtures {
            group.addTask {
                try await collectEvents(
                    from: CodexProcess().run(
                        fixture.makeRequest(timeout: .seconds(10))
                    )
                )
            }
        }

        var collected: [[CodexProcessEvent]] = []
        for try await events in group {
            collected.append(events)
        }
        return collected
    }
    async let actionOutput = FoundationRegisteredActionRunner().run(invocation)

    let (results, output) = try await (codexResults, actionOutput)
    #expect(results.count == fixtures.count)
    #expect(results.allSatisfy {
        $0.contains(.completed(
            InvestigationEnvelope(
                summary: "Static fake result",
                findings: [],
                unresolvedTargetIDs: []
            )
        ))
    })
    #expect(output.exitStatus == 0)
}

@Test
func invalidFinalEnvelopeFailsClosed() async throws {
    let fixture = try CodexProcessFixture(mode: "invalid-envelope")
    defer { fixture.remove() }

    let stream = CodexProcess().run(
        fixture.makeRequest(timeout: .seconds(10))
    )

    await #expect(throws: CodexProcessError.invalidFinalEnvelope) {
        _ = try await collectEvents(from: stream)
    }
}

@Test
func malformedProcessJSONLFailsBeforeTheOverallTimeout() async throws {
    let fixture = try CodexProcessFixture(mode: "malformed")
    defer { fixture.remove() }
    let stream = CodexProcess().run(
        fixture.makeRequest(
            timeout: .seconds(5),
            terminationGracePeriod: .milliseconds(75)
        )
    )

    await #expect(throws: CodexProcessError.protocolViolation) {
        _ = try await collectEvents(from: stream)
    }
    let pid = try fixture.recordedPID(named: "pid.txt")
    try await waitForProcessExit(pid)
    #expect(!processExists(pid))
}

@Test
func processOutputLimitsFailClosed() async throws {
    let stdoutFixture = try CodexProcessFixture(mode: "large-stdout")
    defer { stdoutFixture.remove() }
    var stdoutRequest = stdoutFixture.makeRequest()
    stdoutRequest = CodexRunRequest(
        executableURL: stdoutRequest.executableURL,
        isolatedWorkingDirectoryURL: stdoutRequest.isolatedWorkingDirectoryURL,
        schemaURL: stdoutRequest.schemaURL,
        prompt: stdoutRequest.prompt,
        timeout: .seconds(10),
        terminationGracePeriod: stdoutRequest.terminationGracePeriod,
        stdoutByteLimit: 1_024,
        stderrByteLimit: stdoutRequest.stderrByteLimit,
        jsonLineByteLimit: 1_024,
        unknownMetadataByteLimit: stdoutRequest.unknownMetadataByteLimit,
        environment: stdoutRequest.environment
    )
    await #expect(throws: CodexProcessError.stdoutByteLimitExceeded(limit: 1_024)) {
        _ = try await collectEvents(from: CodexProcess().run(stdoutRequest))
    }

    let stderrFixture = try CodexProcessFixture(mode: "large-stderr")
    defer { stderrFixture.remove() }
    var stderrRequest = stderrFixture.makeRequest()
    stderrRequest = CodexRunRequest(
        executableURL: stderrRequest.executableURL,
        isolatedWorkingDirectoryURL: stderrRequest.isolatedWorkingDirectoryURL,
        schemaURL: stderrRequest.schemaURL,
        prompt: stderrRequest.prompt,
        timeout: .seconds(10),
        terminationGracePeriod: stderrRequest.terminationGracePeriod,
        stdoutByteLimit: stderrRequest.stdoutByteLimit,
        stderrByteLimit: 1_024,
        jsonLineByteLimit: stderrRequest.jsonLineByteLimit,
        unknownMetadataByteLimit: stderrRequest.unknownMetadataByteLimit,
        environment: stderrRequest.environment
    )
    await #expect(throws: CodexProcessError.stderrByteLimitExceeded(limit: 1_024)) {
        _ = try await collectEvents(from: CodexProcess().run(stderrRequest))
    }
}

@Test
func eventBufferLimitFailsClosedWhenTheConsumerDoesNotDrain() async throws {
    let fixture = try CodexProcessFixture(mode: "many-events")
    defer { fixture.remove() }
    let stream = CodexProcess(eventBufferCapacity: 2).run(
        fixture.makeRequest(timeout: .seconds(5))
    )

    try await Task.sleep(for: .seconds(2))

    await #expect(throws: CodexProcessError.eventBufferLimitExceeded(limit: 2)) {
        _ = try await collectEvents(from: stream)
    }
    let pid = try fixture.recordedPID(named: "pid.txt")
    try await waitForProcessExit(pid)
    #expect(!processExists(pid))
}

@Test
func nonzeroExitDoesNotExposeRawStderrAsTheError() async throws {
    let fixture = try CodexProcessFixture(mode: "nonzero")
    defer { fixture.remove() }

    let stream = CodexProcess().run(
        fixture.makeRequest(timeout: .seconds(5))
    )

    await #expect(throws: CodexProcessError.nonzeroExit(status: 7)) {
        _ = try await collectEvents(from: stream)
    }
}

@Test
func earlyExitWhileWritingPromptDoesNotTerminateTheHost() async throws {
    let fixture = try CodexProcessFixture(mode: "early-exit")
    defer { fixture.remove() }
    let request = fixture.makeRequest(
        prompt: Data(repeating: 0x61, count: 4 * 1_024 * 1_024),
        timeout: .seconds(5)
    )
    let stream = CodexProcess().run(request)

    do {
        _ = try await collectEvents(from: stream)
        Issue.record("Expected early process exit")
    } catch let error as CodexProcessError {
        #expect(
            error == .nonzeroExit(status: 9)
                || error == .inputWriteFailed
        )
    }
}

@Test
func normallyExitingLeaderCannotLeaveAChildHoldingThePipes() async throws {
    let fixture = try CodexProcessFixture(mode: "orphan")
    defer { fixture.remove() }
    let stream = CodexProcess().run(
        fixture.makeRequest(
            timeout: .seconds(5),
            terminationGracePeriod: .milliseconds(75)
        )
    )

    let events = try await collectEvents(from: stream)

    #expect(events.contains(.completed(
        InvestigationEnvelope(
            summary: "Static fake result",
            findings: [],
            unresolvedTargetIDs: []
        )
    )))
    let childPID = try fixture.recordedPID(named: "child-pid.txt")
    try await waitForProcessExit(childPID)
    #expect(!processExists(childPID))
}

@Test
func timeoutEscalatesWithinTheIsolatedProcessGroup() async throws {
    let fixture = try CodexProcessFixture(mode: "timeout")
    defer { fixture.remove() }
    let request = fixture.makeRequest(
        timeout: .seconds(5),
        terminationGracePeriod: .milliseconds(75)
    )

    let stream = CodexProcess().run(request)
    var events: [CodexProcessEvent] = []
    do {
        for try await event in stream {
            events.append(event)
        }
        Issue.record("Expected the process to time out")
    } catch {
        #expect(error as? CodexProcessError == .timedOut)
    }

    let pid = try fixture.recordedPID(named: "pid.txt")
    let pgid = try fixture.recordedPID(named: "pgid.txt")
    #expect(pid == pgid)
    #expect(pgid != getpgrp())
    #expect(!processExists(pid))
    #expect(events.contains(.lifecycle(.interruptSent)))
}

@Test
func timeoutKillsIgnoringDescendantAndLeavesNoOrphan() async throws {
    let fixture = try CodexProcessFixture(mode: "child")
    defer { fixture.remove() }
    let request = fixture.makeRequest(
        timeout: .seconds(5),
        terminationGracePeriod: .milliseconds(75)
    )

    let stream = CodexProcess().run(request)

    await #expect(throws: CodexProcessError.timedOut) {
        _ = try await collectEvents(from: stream)
    }

    let parentPID = try fixture.recordedPID(named: "pid.txt")
    let childPID = try fixture.recordedPID(named: "child-pid.txt")
    let pgid = try fixture.recordedPID(named: "pgid.txt")
    #expect(parentPID == pgid)
    #expect(!processExists(parentPID))
    #expect(!processExists(childPID))
}

@Test
func consumerCancellationTerminatesTheProcessGroup() async throws {
    let fixture = try CodexProcessFixture(mode: "child")
    defer { fixture.remove() }
    let request = fixture.makeRequest(
        timeout: .seconds(30),
        terminationGracePeriod: .milliseconds(75)
    )
    let stream = CodexProcess().run(request)
    let collector = Task {
        try await collectEvents(from: stream)
    }

    try await waitForFile(fixture.recordURL(named: "child-pid.txt"))
    collector.cancel()

    await #expect(throws: CodexProcessError.cancelled) {
        _ = try await collector.value
    }
    let parentPID = try fixture.recordedPID(named: "pid.txt")
    let childPID = try fixture.recordedPID(named: "child-pid.txt")
    let processGroup = ProcessGroupID(
        rawValue: try fixture.recordedPID(named: "pgid.txt")
    )
    try await waitForProcessGroupExit(processGroup)
    #expect(
        !ProcessTreeTerminator.processGroupHasMembers(
            processGroup,
            excluding: 0
        )
    )
    if processExists(parentPID) {
        #expect(getpgid(parentPID) != processGroup.rawValue)
    }
    if processExists(childPID) {
        #expect(getpgid(childPID) != processGroup.rawValue)
    }
}

@Test
func requestValidationRejectsUnsafeTopologyBeforeLaunch() async throws {
    let fixture = try CodexProcessFixture(mode: "success")
    defer { fixture.remove() }

    let relativeWorkingDirectory = CodexRunRequest(
        executableURL: fixture.executableURL,
        isolatedWorkingDirectoryURL: URL(filePath: "relative"),
        schemaURL: fixture.schemaURL,
        prompt: Data(),
        timeout: .seconds(1),
        terminationGracePeriod: .milliseconds(50),
        stdoutByteLimit: 1_024,
        stderrByteLimit: 1_024,
        jsonLineByteLimit: 512,
        unknownMetadataByteLimit: 64,
        environment: [:]
    )
    let stream = CodexProcess().run(relativeWorkingDirectory)
    await #expect(throws: CodexProcessError.invalidWorkingDirectory) {
        _ = try await collectEvents(from: stream)
    }

    #expect(!FileManager.default.fileExists(atPath: fixture.recordURL(named: "pid.txt").path))
}

@Test
func requestValidationRejectsNonemptyGlobalCodexInstructions() async throws {
    let fixture = try CodexProcessFixture(mode: "success")
    defer { fixture.remove() }
    try Data("global instructions".utf8).write(
        to: fixture.codexHomeURL.appending(path: "AGENTS.md")
    )

    let stream = CodexProcess().run(fixture.makeRequest())

    await #expect(throws: CodexProcessError.globalInstructionsNotIsolated) {
        _ = try await collectEvents(from: stream)
    }
    #expect(!FileManager.default.fileExists(atPath: fixture.recordURL(named: "pid.txt").path))
}

@Test
func processTreeTerminatorRefusesTheCurrentProcessGroup() async {
    let terminator = ProcessTreeTerminator()

    await #expect(throws: ProcessTreeTerminationError.unsafeProcessGroup) {
        try await terminator.terminateProcessGroup(
            ProcessGroupID(rawValue: getpgrp()),
            gracePeriod: .milliseconds(10)
        )
    }
}

@Test
func processTreeTerminatorSynchronouslyRefusesTheCurrentProcessGroup() {
    let terminator = ProcessTreeTerminator()

    #expect(throws: ProcessTreeTerminationError.unsafeProcessGroup) {
        try terminator.terminateProcessGroupSynchronously(
            ProcessGroupID(rawValue: getpgrp()),
            gracePeriod: .milliseconds(10)
        )
    }
}

private struct CodexProcessFixture {
    let root: URL
    let workingDirectoryURL: URL
    let codexHomeURL: URL
    let schemaURL: URL
    let executableURL: URL

    init(mode: String) throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "StornautCodexProcessTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        workingDirectoryURL = root.appending(path: "workspace", directoryHint: .isDirectory)
        codexHomeURL = root.appending(path: "codex-home", directoryHint: .isDirectory)
        schemaURL = root.appending(path: "investigation-envelope.schema.json")
        executableURL = root.appending(path: "fake-codex-\(mode).sh")
        try FileManager.default.createDirectory(at: workingDirectoryURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: codexHomeURL, withIntermediateDirectories: true)

        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fixtureScriptURL = repositoryRoot
            .appending(path: "Tests/Fixtures/Codex/fake-codex.sh")
        let schemaSourceURL = repositoryRoot
            .appending(path: "Sources/StornautCodex/Schemas/investigation-envelope.schema.json")
        try FileManager.default.copyItem(at: fixtureScriptURL, to: executableURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executableURL.path
        )
        if FileManager.default.fileExists(atPath: schemaSourceURL.path) {
            try FileManager.default.copyItem(at: schemaSourceURL, to: schemaURL)
        } else {
            try Data(#"{"type":"object"}"#.utf8).write(to: schemaURL)
        }
    }

    func makeRequest(
        prompt: Data = Data("Return the static envelope.".utf8),
        timeout: Duration = .seconds(2),
        terminationGracePeriod: Duration = .milliseconds(100),
        environment: [String: String] = [
            "CODEX_HOME": "",
            "HOME": "/Users/example",
            "PATH": "/usr/bin:/bin",
            "TMPDIR": "/tmp",
            "LANG": "en_US.UTF-8",
        ]
    ) -> CodexRunRequest {
        var runtimeEnvironment = environment
        runtimeEnvironment["CODEX_HOME"] = codexHomeURL.path
        return CodexRunRequest(
            executableURL: executableURL,
            isolatedWorkingDirectoryURL: workingDirectoryURL,
            schemaURL: schemaURL,
            prompt: prompt,
            timeout: timeout,
            terminationGracePeriod: terminationGracePeriod,
            stdoutByteLimit: 16_384,
            stderrByteLimit: 1_024,
            jsonLineByteLimit: 8_192,
            unknownMetadataByteLimit: 256,
            environment: runtimeEnvironment
        )
    }

    func recordURL(named name: String) -> URL {
        workingDirectoryURL
            .appending(path: ".fake-record", directoryHint: .isDirectory)
            .appending(path: name)
    }

    func recordedString(named name: String) throws -> String {
        try String(contentsOf: recordURL(named: name), encoding: .utf8)
    }

    func recordedLines(named name: String) throws -> [String] {
        try recordedString(named: name)
            .split(separator: "\n")
            .map(String.init)
    }

    func recordedPID(named name: String) throws -> pid_t {
        let value = try recordedString(named: name)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return try #require(pid_t(value))
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

private func collectEvents(
    from stream: AsyncThrowingStream<CodexProcessEvent, Error>
) async throws -> [CodexProcessEvent] {
    var events: [CodexProcessEvent] = []
    for try await event in stream {
        events.append(event)
    }
    return events
}

private func waitForFile(_ url: URL) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(15))
    while clock.now < deadline {
        if FileManager.default.fileExists(atPath: url.path) {
            return
        }
        try await Task.sleep(for: .milliseconds(10))
    }
    throw CodexProcessTestError.fileDidNotAppear(url)
}

private func waitForProcessExit(_ pid: pid_t) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(5))
    while clock.now < deadline {
        if !processExists(pid) {
            return
        }
        try await Task.sleep(for: .milliseconds(10))
    }
    throw CodexProcessTestError.processDidNotExit(pid)
}

private func waitForProcessGroupExit(
    _ processGroup: ProcessGroupID
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(5))
    while clock.now < deadline {
        if !ProcessTreeTerminator.processGroupHasMembers(
            processGroup,
            excluding: 0
        ) {
            return
        }
        try await Task.sleep(for: .milliseconds(10))
    }
    throw CodexProcessTestError.processGroupDidNotExit(
        processGroup.rawValue
    )
}

private func processExists(_ pid: pid_t) -> Bool {
    kill(pid, 0) == 0 || errno == EPERM
}

private enum CodexProcessTestError: Error {
    case fileDidNotAppear(URL)
    case processDidNotExit(pid_t)
    case processGroupDidNotExit(pid_t)
}
