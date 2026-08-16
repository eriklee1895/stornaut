import Darwin
import Foundation
import Testing
@testable import StornautCodex

@Suite("Codex contained interactive session", .serialized)
struct CodexContainedInteractiveSessionTests {
    @Test
    func startsFixedContainedAppServerAndRelaysLines() async throws {
        let fixture = try ContainedInteractiveSessionFixture(
            mode: "echo"
        )
        defer { fixture.remove() }
        let session = CodexContainedInteractiveSession(
            now: { fixture.now },
            planBuilder: { _ in fixture.plan }
        )

        try await session.start(fixture.configuration)
        try await session.writeLine(Data("{\"id\":1}\n".utf8))
        let line = try await session.readLine()
        #expect(line == Data("{\"id\":1}\n".utf8))
        #expect(try await session.retire())
        #expect(
            try fixture.recordedArguments() == [
                "sandbox",
                "-P",
                "stornaut-outer-v1",
                "-C",
                fixture.workspace.paths.workURL.path,
                "--",
                "/usr/bin/env",
                "-u",
                "CODEX_SANDBOX",
                fixture.executableURL.path,
                "--strict-config",
                "--disable",
                "network_proxy",
                "app-server",
                "--stdio",
            ]
        )
        #expect(
            !FileManager.default.fileExists(
                atPath: fixture.workspace.paths.rootURL.path
            )
        )
    }

    @Test
    func rejectsExpiredAndOverlongConfigurationsBeforePlanning()
        async
    {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let counter = LockedContainedPlanCounter()
        let session = CodexContainedInteractiveSession(
            now: { now },
            planBuilder: { _ in
                counter.increment()
                throw ContainedInteractiveSessionFixtureError.unexpected
            }
        )

        await #expect(
            throws:
                CodexContainedInteractiveSessionError
                    .invalidConfiguration
        ) {
            try await session.start(
                CodexContainedInteractiveSessionConfiguration(
                    investigationID: UUID(),
                    validBefore: now,
                    maximumLineBytes: 1_024,
                    maximumSessionBytes: 8_192
                )
            )
        }
        await #expect(
            throws:
                CodexContainedInteractiveSessionError
                    .invalidConfiguration
        ) {
            try await session.start(
                CodexContainedInteractiveSessionConfiguration(
                    investigationID: UUID(),
                    validBefore: now.addingTimeInterval(901),
                    maximumLineBytes: 1_024,
                    maximumSessionBytes: 8_192
                )
            )
        }
        #expect(counter.value == 0)
    }

    @Test
    func outputLimitFailureStillRetiresTheProcessAndWorkspace()
        async throws
    {
        let fixture = try ContainedInteractiveSessionFixture(
            mode: "large-line"
        )
        defer { fixture.remove() }
        let session = CodexContainedInteractiveSession(
            now: { fixture.now },
            planBuilder: { _ in fixture.plan }
        )

        try await session.start(
            fixture.configuration(maximumLineBytes: 32)
        )
        await #expect(
            throws:
                CodexContainedInteractiveSessionError
                    .lineLimitExceeded
        ) {
            _ = try await session.readLine()
        }
        #expect(try await session.retire())
        #expect(
            !FileManager.default.fileExists(
                atPath: fixture.workspace.paths.rootURL.path
            )
        )
    }

    @Test
    func retirementKillsDescendantsAndIsOneShot() async throws {
        let fixture = try ContainedInteractiveSessionFixture(
            mode: "descendant"
        )
        defer { fixture.remove() }
        let session = CodexContainedInteractiveSession(
            now: { fixture.now },
            planBuilder: { _ in fixture.plan }
        )
        try await session.start(fixture.configuration)
        let childPID = try fixture.waitForRecordedPID()

        #expect(try await session.retire())
        #expect(waitForContainedProcessExit(childPID))
        #expect(try await session.retire())
        await #expect(
            throws:
                CodexContainedInteractiveSessionError.sessionUnavailable
        ) {
            try await session.writeLine(Data("{}\n".utf8))
        }
    }

    @Test
    func retirementDoesNotWaitForEscapedStandardErrorOwner()
        async throws
    {
        let fixture = try ContainedInteractiveSessionFixture(
            mode: "escaped-stderr"
        )
        defer {
            fixture.killRecordedProcess("escaped.pid")
            fixture.remove()
        }
        let session = CodexContainedInteractiveSession(
            now: { fixture.now },
            planBuilder: { _ in fixture.plan }
        )
        try await session.start(fixture.configuration)
        _ = try fixture.waitForRecordedPID(name: "escaped.pid")

        let start = ContinuousClock.now
        #expect(try await session.retire())
        let duration = start.duration(to: .now)

        #expect(duration < .seconds(2))
    }

    @Test
    func cancelledErrorDrainAccountsAlreadyBufferedBytesWithoutWaiting()
        throws
    {
        var descriptors = [Int32](repeating: -1, count: 2)
        guard pipe(&descriptors) == 0 else {
            throw ContainedInteractiveSessionFixtureError.unexpected
        }
        let readDescriptor = descriptors[0]
        let writeDescriptor = descriptors[1]
        defer {
            Darwin.close(readDescriptor)
            Darwin.close(writeDescriptor)
        }
        let bytes = Data(repeating: 0x78, count: 2_048)
        let written = bytes.withUnsafeBytes {
            Darwin.write(
                writeDescriptor,
                $0.baseAddress,
                $0.count
            )
        }
        #expect(written == bytes.count)
        let cancellation = AppServerSessionCancellation()
        cancellation.cancel()
        let output = BoundedAppServerErrorOutput(limit: 128)
        let start = ContinuousClock.now

        output.drain(
            descriptor: readDescriptor,
            cancellation: cancellation
        )

        #expect(start.duration(to: .now) < .seconds(1))
        #expect(output.byteCount == 128)
        #expect(output.wasTruncated)
        #expect(!output.readFailed)
    }

    @Test
    func retirementUnblocksACommittedReadAndDrainsExactlyOnce()
        async throws
    {
        let fixture = try ContainedInteractiveSessionFixture(
            mode: "blocked-read"
        )
        defer { fixture.remove() }
        let session = CodexContainedInteractiveSession(
            now: { fixture.now },
            planBuilder: { _ in fixture.plan }
        )
        try await session.start(fixture.configuration)
        let read = Task {
            try await session.readLine()
        }
        try fixture.waitForMarker("read-ready")

        #expect(try await session.retire())
        await #expect(
            throws:
                CodexContainedInteractiveSessionError
                    .sessionUnavailable
        ) {
            _ = try await read.value
        }
        #expect(try await session.retire())
        #expect(
            !FileManager.default.fileExists(
                atPath: fixture.workspace.paths.rootURL.path
            )
        )
    }

    @Test
    func combinedInputAndOutputCannotExceedSessionBudget()
        async throws
    {
        let fixture = try ContainedInteractiveSessionFixture(
            mode: "echo"
        )
        defer { fixture.remove() }
        let session = CodexContainedInteractiveSession(
            now: { fixture.now },
            planBuilder: { _ in fixture.plan }
        )
        try await session.start(
            fixture.configuration(
                maximumLineBytes: 10,
                maximumSessionBytes: 15
            )
        )
        try await session.writeLine(Data("12345678\n".utf8))
        await #expect(
            throws:
                CodexContainedInteractiveSessionError
                    .sessionLimitExceeded
        ) {
            _ = try await session.readLine()
        }
        #expect(try await session.retire())
    }

    @Test
    func concurrentRetirementSharesOneDrain() async throws {
        let fixture = try ContainedInteractiveSessionFixture(
            mode: "descendant"
        )
        defer { fixture.remove() }
        let session = CodexContainedInteractiveSession(
            now: { fixture.now },
            planBuilder: { _ in fixture.plan }
        )
        try await session.start(fixture.configuration)
        let childPID = try fixture.waitForRecordedPID()

        async let first = session.retire()
        async let second = session.retire()
        let results = try await [first, second]

        #expect(results == [true, true])
        #expect(waitForContainedProcessExit(childPID))
        #expect(
            !FileManager.default.fileExists(
                atPath: fixture.workspace.paths.rootURL.path
            )
        )
    }

    @Test
    func failedLaunchRemovesOwnedWorkspace() async throws {
        let fixture = try ContainedInteractiveSessionFixture(
            mode: "echo"
        )
        defer { fixture.remove() }
        let plan = fixture.plan
        let invalidPlan = CodexContainedInteractiveLaunchPlan(
            executableURL: fixture.root.appending(path: "missing"),
            arguments: plan.arguments,
            environment: plan.environment,
            currentDirectoryURL: plan.currentDirectoryURL,
            workspace: plan.workspace,
            projectedAuthSourceURL: plan.projectedAuthSourceURL,
            containmentConfiguration:
                plan.containmentConfiguration
        )
        let session = CodexContainedInteractiveSession(
            now: { fixture.now },
            planBuilder: { _ in invalidPlan }
        )

        await #expect(
            throws:
                CodexContainedInteractiveSessionError.launchFailed
        ) {
            try await session.start(fixture.configuration)
        }
        #expect(
            !FileManager.default.fileExists(
                atPath: fixture.workspace.paths.rootURL.path
            )
        )
    }

    @Test
    func tamperedContainmentPlanIsRejectedBeforeSpawn() async throws {
        let fixture = try ContainedInteractiveSessionFixture(
            mode: "echo"
        )
        defer { fixture.remove() }
        let plan = fixture.plan
        let tampered = CodexContainedInteractiveLaunchPlan(
            executableURL: plan.executableURL,
            arguments: plan.arguments,
            environment: plan.environment,
            currentDirectoryURL: plan.currentDirectoryURL,
            workspace: plan.workspace,
            projectedAuthSourceURL:
                fixture.root.appending(path: "other-auth.json"),
            containmentConfiguration:
                plan.containmentConfiguration
        )
        let session = CodexContainedInteractiveSession(
            now: { fixture.now },
            planBuilder: { _ in tampered }
        )

        await #expect(
            throws:
                CodexContainedInteractiveSessionError.launchFailed
        ) {
            try await session.start(fixture.configuration)
        }
        #expect(
            !FileManager.default.fileExists(
                atPath: fixture.workspace.paths.rootURL.path
            )
        )
        #expect(!FileManager.default.fileExists(atPath: fixture.recordURL
            .appending(path: "arguments.txt").path))
    }
}

private struct ContainedInteractiveSessionFixture {
    let root: URL
    let workspace: CodexRuntimeWorkspace
    let executableURL: URL
    let recordURL: URL
    let plan: CodexContainedInteractiveLaunchPlan
    let now = Date(timeIntervalSince1970: 2_000_000_000)

    init(mode: String) throws {
        root = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-contained-interactive-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        workspace = try CodexRuntimeWorkspace.create(
            under: root,
            forbiddenRoots: []
        )
        executableURL = root.appending(path: "fake-codex")
        recordURL = root.appending(
            path: "record",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: recordURL,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        try Data(
            containedInteractiveScript(
                mode: mode,
                recordURL: recordURL
            ).utf8
        ).write(to: executableURL)
        chmod(executableURL.path, 0o700)
        let authSourceURL = URL(
            filePath: "/Users/example/.codex/auth.json"
        )
        let policy = CodexContainmentPolicy()
        let containment = try policy.configuration(
            workspace: workspace.paths,
            projectedAuthSourceURL: authSourceURL
        )
        _ = try policy.install(containment, in: workspace.paths)
        let arguments = try policy.launchArguments(
            codexExecutableURL: executableURL,
            workspace: workspace.paths
        )
        let environment = try CodexRuntimeEnvironmentPolicy().project(
            inherited: [
                "LANG": "en_US.UTF-8",
                "PATH": "/usr/bin:/bin",
            ],
            workspace: workspace.paths
        )
        plan = CodexContainedInteractiveLaunchPlan(
            executableURL: executableURL,
            arguments: arguments,
            environment: environment,
            currentDirectoryURL: workspace.paths.workURL,
            workspace: workspace,
            projectedAuthSourceURL: authSourceURL,
            containmentConfiguration: containment
        )
    }

    var configuration: CodexContainedInteractiveSessionConfiguration {
        configuration()
    }

    func configuration(
        maximumLineBytes: Int = 64 * 1_024,
        maximumSessionBytes: Int = 256 * 1_024
    ) -> CodexContainedInteractiveSessionConfiguration {
        CodexContainedInteractiveSessionConfiguration(
            investigationID: UUID(),
            validBefore: now.addingTimeInterval(60),
            maximumLineBytes: maximumLineBytes,
            maximumSessionBytes: maximumSessionBytes
        )
    }

    func recordedArguments() throws -> [String] {
        try String(
            contentsOf: recordURL.appending(path: "arguments.txt"),
            encoding: .utf8
        )
        .split(separator: "\n")
        .map(String.init)
    }

    func waitForRecordedPID() throws -> pid_t {
        try waitForRecordedPID(name: "child.pid")
    }

    func waitForRecordedPID(name: String) throws -> pid_t {
        let url = recordURL.appending(path: name)
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if
                let value = try? String(
                    contentsOf: url,
                    encoding: .utf8
                ).trimmingCharacters(in: .whitespacesAndNewlines),
                let processID = pid_t(value)
            {
                return processID
            }
            usleep(5_000)
        }
        throw ContainedInteractiveSessionFixtureError.missingPID
    }

    func killRecordedProcess(_ name: String) {
        guard let processID = try? waitForRecordedPID(name: name) else {
            return
        }
        kill(processID, SIGKILL)
    }

    func waitForMarker(_ name: String) throws {
        let url = recordURL.appending(path: name)
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: url.path) {
                return
            }
            usleep(5_000)
        }
        throw ContainedInteractiveSessionFixtureError.missingMarker
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

private final class LockedContainedPlanCounter:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.withLock { count }
    }

    func increment() {
        lock.withLock { count += 1 }
    }
}

private enum ContainedInteractiveSessionFixtureError: Error {
    case missingMarker
    case missingPID
    case unexpected
}

private func containedInteractiveScript(
    mode: String,
    recordURL: URL
) -> String {
    """
    #!/bin/zsh
    set -euo pipefail

    record_root=\(containedShellQuote(recordURL.path))
    mode=\(containedShellQuote(mode))
    printf '%s\n' "$@" > "$record_root/arguments.txt"

    if [[ "$mode" == "descendant" ]]; then
        /bin/zsh -c 'trap "" INT TERM; /bin/sleep 30' &
        print -r -- "$!" > "$record_root/child.pid"
    fi
    if [[ "$mode" == "escaped-stderr" ]]; then
        /usr/bin/python3 - "$record_root/escaped.pid" <<'PY'
    import os
    import sys
    import time

    pid = os.fork()
    if pid > 0:
        with open(sys.argv[1], "w", encoding="utf-8") as handle:
            handle.write(str(pid))
        raise SystemExit(0)
    os.setsid()
    time.sleep(4)
    PY
        /bin/sleep 30
        exit 0
    fi
    if [[ "$mode" == "large-line" ]]; then
        /usr/bin/python3 - <<'PY'
    print("x" * 256)
    PY
        /bin/sleep 30
        exit 0
    fi
    if [[ "$mode" == "blocked-read" ]]; then
        : > "$record_root/read-ready"
        /bin/sleep 30
        exit 0
    fi
    while IFS= read -r line; do
        print -r -- "$line"
    done
    """
}

private func containedShellQuote(_ value: String) -> String {
    "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
}

private func waitForContainedProcessExit(_ processID: pid_t) -> Bool {
    let deadline = Date().addingTimeInterval(2)
    while Date() < deadline {
        if kill(processID, 0) != 0, errno == ESRCH {
            return true
        }
        usleep(5_000)
    }
    return false
}
