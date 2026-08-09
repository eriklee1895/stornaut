import Darwin
import Foundation
import Testing
@testable import StornautCore

@Test
func registeredActionRegistryResolvesOnlyFixedModeArguments() throws {
    let fixtureURL = try fakeCleanerFixtureURL()
    let definition = RegisteredActionDefinition.fakeCleaner(
        executableURL: fixtureURL
    )
    let registry = ActionRegistry(definitions: [definition])

    let expectations: [(RegisteredActionMode, [String])] = [
        (.success, ["success"]),
        (.dryRun, ["dry-run"]),
        (.timeout, ["timeout"]),
        (.partialFailure, ["partial-failure"]),
    ]
    for (mode, arguments) in expectations {
        let invocation = try registry.resolve(
            RegisteredActionRequest(id: definition.id, mode: mode)
        )
        #expect(invocation.executableURL == fixtureURL)
        #expect(invocation.arguments == arguments)
        #expect(invocation.environment == [
            "LANG": "C",
            "LC_ALL": "C",
            "PATH": "/usr/bin:/bin",
        ])
    }

    #expect(throws: ActionRegistryError.unregisteredAction) {
        _ = try registry.resolve(
            RegisteredActionRequest(id: "rm", mode: .success)
        )
    }
}

@Test
func registeredActionDryRunDoesNotLaunchTheExecutable() async throws {
    let harness = try RegisteredActionHarness()
    let runner = RegisteredActionRunnerSpy()
    let executor = ActionExecutor(
        policyGate: harness.gate,
        registeredActionRunner: runner
    )
    let token = try executor.preflight(
        .runRegisteredAction(
            RegisteredActionRequest(
                id: harness.definition.id,
                mode: .dryRun
            )
        ),
        context: .init(allowedRoots: [], activeURLs: [])
    )

    let execution = try await executor.execute(
        token,
        context: .init(allowedRoots: [], activeURLs: [])
    )
    let result = try executor.postflight(execution)

    #expect(runner.callCount == 0)
    #expect(result.status == .dryRun)
    #expect(result.logicalBytesAffected == 0)
    #expect(result.allocatedBytesAffected == 0)
    #expect(result.completedItems == 0)
    #expect(result.failedItems == 0)
}

@Test
func registeredActionSuccessRunsFixtureAndReportsMeasuredEffects() async throws {
    let harness = try RegisteredActionHarness()
    let executor = ActionExecutor(policyGate: harness.gate)
    let token = try executor.preflight(
        .runRegisteredAction(
            RegisteredActionRequest(
                id: harness.definition.id,
                mode: .success
            )
        ),
        context: .init(allowedRoots: [], activeURLs: [])
    )

    let execution = try await executor.execute(
        token,
        context: .init(allowedRoots: [], activeURLs: [])
    )
    let result = try executor.postflight(execution)

    #expect(result.status == .succeeded)
    #expect(result.logicalBytesAffected == 4_096)
    #expect(result.allocatedBytesAffected == 8_192)
    #expect(result.completedItems == 2)
    #expect(result.failedItems == 0)
    #expect(result.startedAt <= result.finishedAt)
}

@Test
func registeredActionNormalExitTerminatesSurvivingChild() async throws {
    let fixtureURL = try fakeCleanerFixtureURL()
    let pidFileURL = FileManager.default.temporaryDirectory.appending(
        path: "stornaut-fake-cleaner-normal-exit-\(UUID().uuidString).pid"
    )
    defer { try? FileManager.default.removeItem(at: pidFileURL) }
    let definition = RegisteredActionDefinition(
        id: "fixture.fake-cleaner-normal-exit",
        executableURL: fixtureURL,
        environment: [
            "LANG": "C",
            "LC_ALL": "C",
            "PATH": "/usr/bin:/bin",
            "STORNAUT_FAKE_CLEANER_PID_FILE": pidFileURL.path,
        ],
        timeout: .seconds(2),
        standardOutputLimit: 16_384,
        standardErrorLimit: 4_096
    ) { mode in
        mode == .success ? ["success-with-child"] : nil
    }
    let gate = ActionPolicyGate(
        registry: ActionRegistry(definitions: [definition])
    )
    let executor = ActionExecutor(policyGate: gate)
    let token = try executor.preflight(
        .runRegisteredAction(
            RegisteredActionRequest(id: definition.id, mode: .success)
        ),
        context: .init(allowedRoots: [], activeURLs: [])
    )

    let execution = try await executor.execute(
        token,
        context: .init(allowedRoots: [], activeURLs: [])
    )
    let result = try executor.postflight(execution)

    #expect(result.status == .succeeded)
    let childPID = try #require(
        pid_t(
            String(contentsOf: pidFileURL, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        )
    )
    try await waitUntilProcessExits(childPID)
}

@Test
func registeredActionTimeoutTerminatesTheFixture() async throws {
    let harness = try RegisteredActionHarness(timeout: .milliseconds(100))
    let executor = ActionExecutor(policyGate: harness.gate)
    let token = try executor.preflight(
        .runRegisteredAction(
            RegisteredActionRequest(
                id: harness.definition.id,
                mode: .timeout
            )
        ),
        context: .init(allowedRoots: [], activeURLs: [])
    )
    let clock = ContinuousClock()
    let started = clock.now

    await #expect(throws: ActionExecutionError.timedOut) {
        _ = try await executor.execute(
            token,
            context: .init(allowedRoots: [], activeURLs: [])
        )
    }

    #expect(started.duration(to: clock.now) < .seconds(2))
}

@Test
func registeredActionTimeoutTerminatesTheFixtureProcessGroup() async throws {
    let fixtureURL = try fakeCleanerFixtureURL()
    let pidFileURL = FileManager.default.temporaryDirectory.appending(
        path: "stornaut-fake-cleaner-\(UUID().uuidString).pid"
    )
    defer { try? FileManager.default.removeItem(at: pidFileURL) }
    let definition = RegisteredActionDefinition(
        id: "fixture.fake-cleaner-process-group",
        executableURL: fixtureURL,
        environment: [
            "LANG": "C",
            "LC_ALL": "C",
            "PATH": "/usr/bin:/bin",
            "STORNAUT_FAKE_CLEANER_PID_FILE": pidFileURL.path,
        ],
        timeout: .milliseconds(250),
        standardOutputLimit: 1_024,
        standardErrorLimit: 1_024
    ) { mode in
        mode == .timeout ? ["timeout"] : nil
    }
    let gate = ActionPolicyGate(
        registry: ActionRegistry(definitions: [definition])
    )
    let executor = ActionExecutor(policyGate: gate)
    let token = try executor.preflight(
        .runRegisteredAction(
            RegisteredActionRequest(id: definition.id, mode: .timeout)
        ),
        context: .init(allowedRoots: [], activeURLs: [])
    )

    await #expect(throws: ActionExecutionError.timedOut) {
        _ = try await executor.execute(
            token,
            context: .init(allowedRoots: [], activeURLs: [])
        )
    }

    let pidText = try String(contentsOf: pidFileURL, encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let pids = pidText.split(separator: ":").compactMap {
        pid_t(String($0))
    }
    try #require(pids.count == 2)
    for pid in pids {
        try await waitUntilProcessExits(pid)
        #expect(kill(pid, 0) == -1)
        #expect(errno == ESRCH)
    }
}

@Test
func registeredActionPostflightPreservesPartialFailure() async throws {
    let harness = try RegisteredActionHarness()
    let executor = ActionExecutor(policyGate: harness.gate)
    let token = try executor.preflight(
        .runRegisteredAction(
            RegisteredActionRequest(
                id: harness.definition.id,
                mode: .partialFailure
            )
        ),
        context: .init(allowedRoots: [], activeURLs: [])
    )

    let execution = try await executor.execute(
        token,
        context: .init(allowedRoots: [], activeURLs: [])
    )
    let result = try executor.postflight(execution)

    #expect(result.status == .partiallyFailed)
    #expect(result.logicalBytesAffected == 2_048)
    #expect(result.allocatedBytesAffected == 4_096)
    #expect(result.completedItems == 1)
    #expect(result.failedItems == 1)
    #expect(result.exitStatus == 3)
}

private struct RegisteredActionHarness {
    let definition: RegisteredActionDefinition
    let gate: ActionPolicyGate

    init(timeout: Duration = .seconds(2)) throws {
        let fixtureURL = try fakeCleanerFixtureURL()
        definition = RegisteredActionDefinition.fakeCleaner(
            executableURL: fixtureURL,
            timeout: timeout
        )
        gate = ActionPolicyGate(
            registry: ActionRegistry(definitions: [definition])
        )
    }
}

private final class RegisteredActionRunnerSpy:
    RegisteredActionRunning,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var storedCallCount = 0

    var callCount: Int {
        lock.withLock { storedCallCount }
    }

    func run(
        _ invocation: RegisteredActionInvocation
    ) async throws -> RegisteredActionProcessOutput {
        lock.withLock { storedCallCount += 1 }
        return RegisteredActionProcessOutput(
            exitStatus: 0,
            stdout: Data(),
            stderr: Data()
        )
    }
}

private func fakeCleanerFixtureURL() throws -> URL {
    let url = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Fixtures/Actions/fake-cleaner.sh")
    guard FileManager.default.isExecutableFile(atPath: url.path) else {
        throw RegisteredActionTestError.fixtureIsNotExecutable
    }
    return url
}

private func waitUntilProcessExits(_ pid: pid_t) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while clock.now < deadline {
        if kill(pid, 0) == -1, errno == ESRCH {
            return
        }
        try await Task.sleep(for: .milliseconds(10))
    }
    throw RegisteredActionTestError.processDidNotExit(pid)
}

private enum RegisteredActionTestError: Error {
    case fixtureIsNotExecutable
    case processDidNotExit(pid_t)
}
