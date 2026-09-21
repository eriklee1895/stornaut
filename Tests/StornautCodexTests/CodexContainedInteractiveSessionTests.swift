import Darwin
import Foundation
import StornautProcessSupport
import Testing
@testable import StornautCodex

@Suite("Codex contained interactive session", .serialized)
struct CodexContainedInteractiveSessionTests {
    @Test
    func nativeLauncherRequiresExactInitialStopAndMappedImageIdentity()
        throws
    {
        #expect(
            CodexContainedInteractiveNativeLauncher
                .initialStopIsAccepted(
                    result: 41, initialStopStatus: 0x7f,
                    expectedProcessID: 41
                )
        )
        #expect(
            !CodexContainedInteractiveNativeLauncher
                .initialStopIsAccepted(
                    result: 42, initialStopStatus: 0x7f,
                    expectedProcessID: 41
                )
        )
        #expect(
            !CodexContainedInteractiveNativeLauncher
                .initialStopIsAccepted(
                    result: 41, initialStopStatus: 0x117f,
                    expectedProcessID: 41
                )
        )

        let expected = CodexContainedInteractiveNativeLeaseSnapshot(
            path: "/tmp/codex", device: 7, inode: 11,
            generation: 13, size: 17
        )
        let matching = CodexContainedInteractiveMappedImageIdentity(
            path: expected.path, device: expected.device,
            inode: expected.inode, generation: expected.generation,
            size: expected.size
        )
        let other = CodexContainedInteractiveMappedImageIdentity(
            path: "/usr/lib/dyld", device: 1, inode: 2,
            generation: 3, size: 4
        )
        let conflicting = CodexContainedInteractiveMappedImageIdentity(
            path: expected.path, device: expected.device,
            inode: expected.inode &+ 1, generation: expected.generation,
            size: expected.size
        )
        let launcher = CodexContainedInteractiveNativeLauncher()
        #expect(launcher.mappedImagesMatchLease(
            [matching, matching, other], expected: expected
        ))
        #expect(!launcher.mappedImagesMatchLease([], expected: expected))
        #expect(!launcher.mappedImagesMatchLease(
            [other, matching], expected: expected
        ))
        #expect(!launcher.mappedImagesMatchLease(
            [matching, conflicting], expected: expected
        ))
    }

    @Test
    func nativeLauncherRunsOnlyAfterSuspendedImageChecks() throws {
        let fixture = try NativeInteractiveLauncherFixture()
        defer { fixture.remove() }
        let events = LockedNativeLaunchEvents()
        let launcher = CodexContainedInteractiveNativeLauncher { phase in
            events.append(phase)
        }

        let receipt: CodexContainedInteractiveNativeLaunchReceipt
        do {
            receipt = try launcher.launch(
                plan: fixture.plan,
                deadline: .now() + .seconds(2)
            )
        } catch {
            Issue.record("launch failed after phases: \(events.values)")
            throw error
        }
        defer {
            forceCleanupDiagnosticProcess(receipt.process)
            Darwin.close(receipt.process.standardInput)
            Darwin.close(receipt.process.standardOutput)
            Darwin.close(receipt.process.standardError)
        }

        #expect(receipt.codexExecutableSHA256 == fixture.lease.sha256)
        let phases = events.values
        #expect(phases.count == 6)
        #expect(phases.first == .beforeSpawn)
        #expect(phases.last == .beforeResume(receipt.process.pid))
        #expect(
            phases.firstIndex(of: .afterImageObservation(receipt.process.pid))!
                < phases.firstIndex(of: .beforeResume(receipt.process.pid))!
        )
        #expect(getpgid(receipt.process.pid) == receipt.process.pid)
    }

    @Test
    func nativeLauncherFailureBeforeResumeKillsAndExactlyReapsChild() throws {
        let fixture = try NativeInteractiveLauncherFixture()
        defer { fixture.remove() }
        let observedPID = LockedNativeProcessID()
        let launcher = CodexContainedInteractiveNativeLauncher { phase in
            if case let .afterSpawn(processID) = phase {
                observedPID.set(processID)
            }
            if case .beforeResume = phase {
                throw ContainedInteractiveSessionFixtureError.unexpected
            }
        }

        #expect(throws: ContainedInteractiveSessionFixtureError.self) {
            _ = try launcher.launch(
                plan: fixture.plan, deadline: .now() + .seconds(2)
            )
        }
        let processID = try #require(observedPID.value)
        #expect(kill(processID, 0) == -1)
        #expect(errno == ESRCH)
        var status: Int32 = 0
        #expect(waitpid(processID, &status, WNOHANG) == -1)
        #expect(errno == ECHILD)
    }

    @Test
    func nativeLauncherDetectsNamedIdentityDriftBeforeResume() throws {
        let fixture = try NativeInteractiveLauncherFixture()
        defer { fixture.remove() }
        let observedPID = LockedNativeProcessID()
        let originalURL = fixture.executableURL.appendingPathExtension(
            "original"
        )
        let launcher = CodexContainedInteractiveNativeLauncher { phase in
            if case let .afterSpawn(processID) = phase {
                observedPID.set(processID)
            }
            if case .beforeFinalLeaseRevalidation = phase {
                try FileManager.default.moveItem(
                    at: fixture.executableURL, to: originalURL
                )
                try Data(contentsOf: originalURL)
                    .write(to: fixture.executableURL)
                #expect(chmod(fixture.executableURL.path, 0o700) == 0)
            }
        }

        #expect(throws: CodexNativeExecutableIdentityError.identityChanged) {
            _ = try launcher.launch(
                plan: fixture.plan, deadline: .now() + .seconds(2)
            )
        }
        let processID = try #require(observedPID.value)
        #expect(kill(processID, 0) == -1)
        #expect(errno == ESRCH)
        var status: Int32 = 0
        #expect(waitpid(processID, &status, WNOHANG) == -1)
        #expect(errno == ECHILD)
    }

    @Test
    func sessionReturnsTheLauncherObservedDigest() async throws {
        let fixture = try ContainedInteractiveSessionFixture(mode: "echo")
        defer { fixture.remove() }
        let observed = String(repeating: "c", count: 64)
        let session = CodexContainedInteractiveSession(
            now: { fixture.now },
            planBuilder: { _ in fixture.plan },
            nativeLauncher: { plan, _, _ in
                var process: SpawnedDiagnosticProcess?
                do {
                    process = try spawnDiagnosticProcess(
                        executableURL: plan.executableURL,
                        arguments: plan.arguments,
                        environment: plan.environment.values,
                        currentDirectoryURL: plan.currentDirectoryURL
                    )
                    return CodexContainedInteractiveNativeLaunchReceipt(
                        process: process!,
                        codexExecutableSHA256: observed,
                        nativeIdentityLease: plan.nativeIdentityLease
                    )
                } catch {
                    if let process { forceCleanupDiagnosticProcess(process) }
                    throw error
                }
            }
        )

        let observation = try await session.start(fixture.configuration)
        #expect(observation.codexExecutableSHA256 == observed)
        _ = try await session.retire()
    }

    @Test
    func cancellationBeforeResumeCannotMintStartAndLeavesNoChild() async throws {
        let fixture = try NativeInteractiveLauncherFixture()
        defer { fixture.remove() }
        let hook = SuspendedNativeLaunchHook()
        let startedAt = Date()
        let validBefore = startedAt.addingTimeInterval(30)
        let clock = LockedContainedClock(now: startedAt)
        let session = CodexContainedInteractiveSession(
            now: { clock.read() },
            planBuilder: { _ in fixture.plan },
            nativeLauncher: { plan, deadline, gate in
                try CodexContainedInteractiveNativeLauncher { phase in
                    try hook.observe(phase)
                }.launch(plan: plan, deadline: deadline, gate: gate)
            }
        )
        let start = Task {
            try await session.start(
                CodexContainedInteractiveSessionConfiguration(
                    investigationID: UUID(),
                    expectedCodexExecutableSHA256: fixture.lease.sha256,
                    validBefore: validBefore,
                    maximumLineBytes: 1_024,
                    maximumSessionBytes: 8_192
                )
            )
        }
        let processID = try hook.waitUntilBeforeResume()
        let retirement = Task { try await session.retire() }

        await #expect(throws: CodexContainedInteractiveSessionError.self) {
            _ = try await start.value
        }
        #expect(kill(processID, 0) == -1)
        #expect(errno == ESRCH)
        #expect(
            try await retirement.value == .retiredPreparedWorkspace
        )
    }

    @Test
    func cancellationWhilePlanningPreventsNativeResume() async throws {
        let fixture = try NativeInteractiveLauncherFixture()
        defer { fixture.remove() }
        let builder = SuspendedContainedPlanBuilder(plan: fixture.plan)
        let events = LockedNativeLaunchEvents()
        let clock = LockedContainedClock(now: Date())
        let session = CodexContainedInteractiveSession(
            now: { clock.read() },
            planBuilder: { _ in try await builder.build() },
            nativeLauncher: { plan, deadline, gate in
                try CodexContainedInteractiveNativeLauncher {
                    events.append($0)
                }.launch(plan: plan, deadline: deadline, gate: gate)
            }
        )
        let start = Task {
            try await session.start(.init(
                investigationID: UUID(),
                expectedCodexExecutableSHA256: fixture.lease.sha256,
                validBefore: clock.read().addingTimeInterval(30),
                maximumLineBytes: 1_024,
                maximumSessionBytes: 8_192
            ))
        }
        await builder.waitUntilEntered()
        start.cancel()
        await builder.resume()

        await #expect(throws: CodexContainedInteractiveSessionError.self) {
            _ = try await start.value
        }
        #expect(!events.values.contains { phase in
            if case .beforeResume = phase { true } else { false }
        })
        #expect(
            try await session.retire() == .retiredPreparedWorkspace
        )
    }

    @Test
    func startsFixedContainedAppServerAndRelaysLines() async throws {
        let fixture = try ContainedInteractiveSessionFixture(
            mode: "echo"
        )
        defer { fixture.remove() }
        let session = fixture.session { _ in fixture.plan }

        try await session.start(fixture.configuration)
        try await session.writeLine(Data("{\"id\":1}\n".utf8))
        let line = try await session.readLine()
        #expect(line == Data("{\"id\":1}\n".utf8))
        let retirement = try await session.retire()
        #expect(retirement.resourceOwnership == .owned)
        #expect(retirement.processGroupTerminated)
        #expect(retirement.standardErrorContained)
        #expect(retirement.workspaceRemoved)
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
            },
            nativeLauncher: { _, _, _ in
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
                    expectedCodexExecutableSHA256:
                        String(repeating: "a", count: 64),
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
                    expectedCodexExecutableSHA256:
                        String(repeating: "a", count: 64),
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
        let session = fixture.session { _ in fixture.plan }

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
        #expect(try await session.retire() == .retiredOwnedResources)
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
        let session = fixture.session { _ in fixture.plan }
        try await session.start(fixture.configuration)
        let childPID = try fixture.waitForRecordedPID()

        let firstRetirement = try await session.retire()
        #expect(waitForContainedProcessExit(childPID))
        let repeatedRetirement = try await session.retire()
        #expect(firstRetirement == .retiredOwnedResources)
        #expect(repeatedRetirement == firstRetirement)
        #expect(
            !ProcessTreeTerminator.processGroupHasMembers(
                ProcessGroupID(
                    rawValue: try fixture.waitForRecordedPGID()
                ),
                excluding: 0
            )
        )
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
            fixture.killRecordedProcess("escaped-cleanup.pid")
            fixture.remove()
        }
        let session = fixture.session { _ in fixture.plan }
        try await session.start(fixture.configuration)
        let (_, start) = try fixture.waitForEscapedPID()
        #expect(try await session.retire() == .retiredOwnedResources)
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
        let session = fixture.session { _ in fixture.plan }
        try await session.start(fixture.configuration)
        let read = Task {
            try await session.readLine()
        }
        try fixture.waitForMarker("read-ready")

        let firstRetirement = try await session.retire()
        await #expect(
            throws:
                CodexContainedInteractiveSessionError
                    .sessionUnavailable
        ) {
            _ = try await read.value
        }
        #expect(
            try await session.retire() == firstRetirement
        )
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
        let session = fixture.session { _ in fixture.plan }
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
        #expect(try await session.retire() == .retiredOwnedResources)
    }

    @Test
    func concurrentRetirementSharesOneDrain() async throws {
        let fixture = try ContainedInteractiveSessionFixture(
            mode: "descendant"
        )
        defer { fixture.remove() }
        let session = fixture.session { _ in fixture.plan }
        try await session.start(fixture.configuration)
        let childPID = try fixture.waitForRecordedPID()

        async let first = session.retire()
        async let second = session.retire()
        let results = try await [first, second]

        #expect(
            results == [
                .retiredOwnedResources,
                .retiredOwnedResources,
            ]
        )
        #expect(waitForContainedProcessExit(childPID))
        #expect(
            !FileManager.default.fileExists(
                atPath: fixture.workspace.paths.rootURL.path
            )
        )
    }

    @Test
    func failedRetirementNeverMintsAnOwnerObservation() async throws {
        let fixture = try ContainedInteractiveSessionFixture(
            mode: "stderr-overflow"
        )
        defer { fixture.remove() }
        let session = fixture.session { _ in fixture.plan }
        try await session.start(
            fixture.configuration(
                maximumLineBytes: 64,
                maximumSessionBytes: 64
            )
        )
        try fixture.waitForMarker("stderr-ready")

        await #expect(
            throws: CodexContainedInteractiveSessionError.retirementFailed
        ) {
            _ = try await session.retire()
        }
        await #expect(
            throws: CodexContainedInteractiveSessionError.retirementFailed
        ) {
            _ = try await session.retire()
        }
        #expect(
            !FileManager.default.fileExists(
                atPath: fixture.workspace.paths.rootURL.path
            )
        )
    }

    @Test
    func postReapNativeLeaseDriftFailsAfterCompleteCleanup() async throws {
        let fixture = try ContainedInteractiveSessionFixture(mode: "echo")
        defer { fixture.remove() }
        let session = fixture.session { _ in fixture.plan }
        _ = try await session.start(fixture.configuration)
        let originalURL = fixture.executableURL.appendingPathExtension(
            "original"
        )
        try FileManager.default.moveItem(
            at: fixture.executableURL, to: originalURL
        )
        try Data(contentsOf: originalURL).write(to: fixture.executableURL)
        #expect(chmod(fixture.executableURL.path, 0o700) == 0)

        await #expect(
            throws: CodexContainedInteractiveSessionError.retirementFailed
        ) {
            _ = try await session.retire()
        }
        #expect(!FileManager.default.fileExists(
            atPath: fixture.workspace.paths.rootURL.path
        ))
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
            nativeIdentityLease: plan.nativeIdentityLease,
            arguments: plan.arguments,
            environment: plan.environment,
            currentDirectoryURL: plan.currentDirectoryURL,
            workspace: plan.workspace,
            projectedAuthSourceURL: plan.projectedAuthSourceURL,
            containmentConfiguration:
                plan.containmentConfiguration
        )
        let session = fixture.session { _ in invalidPlan }

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
    func retirementBeforeStartDistinguishesNoOwnedResources() async throws {
        let counter = LockedContainedPlanCounter()
        let session = CodexContainedInteractiveSession(
            planBuilder: { _ in
                counter.increment()
                throw ContainedInteractiveSessionFixtureError.unexpected
            },
            nativeLauncher: { _, _, _ in
                throw ContainedInteractiveSessionFixtureError.unexpected
            }
        )

        let first = try await session.retire()
        let repeated = try await session.retire()

        #expect(first == .noOwnedResources)
        #expect(repeated == first)
        #expect(first.resourceOwnership == .none)
        #expect(!first.processGroupTerminated)
        #expect(!first.standardErrorContained)
        #expect(!first.workspaceRemoved)
        #expect(counter.value == 0)
    }

    @Test
    func retirementWaitsForAStartingPlanAndRetiresItsWorkspace()
        async throws
    {
        let fixture = try ContainedInteractiveSessionFixture(mode: "echo")
        defer { fixture.remove() }
        let builder = SuspendedContainedPlanBuilder(plan: fixture.plan)
        let completion = RetirementCompletionProbe()
        let session = fixture.session { _ in try await builder.build() }
        let start = Task { try await session.start(fixture.configuration) }
        await builder.waitUntilEntered()
        let retirement = Task {
            let observation = try await session.retire()
            await completion.record(observation)
            return observation
        }
        for _ in 0..<10 {
            await Task.yield()
        }
        #expect(await completion.value == nil)

        await builder.resume()

        #expect(
            try await retirement.value == .retiredPreparedWorkspace
        )
        await #expect(
            throws: CodexContainedInteractiveSessionError
                .sessionUnavailable
        ) {
            try await start.value
        }
        #expect(
            !FileManager.default.fileExists(
                atPath: fixture.workspace.paths.rootURL.path
            )
        )
    }

    @Test
    func startingPlanCleanupFailureCannotMintRetirementEvidence()
        async throws
    {
        let fixture = try ContainedInteractiveSessionFixture(mode: "echo")
        defer { fixture.remove() }
        let builder = SuspendedContainedPlanBuilder(plan: fixture.plan)
        let session = fixture.session { _ in try await builder.build() }
        let start = Task { try await session.start(fixture.configuration) }
        await builder.waitUntilEntered()
        let retirement = Task { try await session.retire() }
        try FileManager.default.removeItem(at: fixture.workspace.markerURL)
        await builder.resume()

        await #expect(
            throws: CodexContainedInteractiveSessionError
                .retirementFailed
        ) {
            _ = try await retirement.value
        }
        await #expect(
            throws: CodexContainedInteractiveSessionError
                .sessionUnavailable
        ) {
            try await start.value
        }
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
            nativeIdentityLease: plan.nativeIdentityLease,
            arguments: plan.arguments,
            environment: plan.environment,
            currentDirectoryURL: plan.currentDirectoryURL,
            workspace: plan.workspace,
            projectedAuthSourceURL:
                fixture.root.appending(path: "other-auth.json"),
            containmentConfiguration:
                plan.containmentConfiguration
        )
        let session = fixture.session { _ in tampered }

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
    let nativeIdentityLease: CodexNativeExecutableIdentityLease
    let recordURL: URL
    let plan: CodexContainedInteractiveLaunchPlan
    let now = Date(timeIntervalSince1970: 2_000_000_000)

    init(mode: String) throws {
        root = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: ".build", directoryHint: .isDirectory)
            .appending(
            path: "StornautContainedInteractive-\(UUID().uuidString)",
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
        let packageRoot = root.appending(
            path: "lib/node_modules/@openai/codex",
            directoryHint: .isDirectory
        )
        let wrapperURL = packageRoot.appending(path: "bin/codex.js")
        executableURL = packageRoot.appending(
            path: "node_modules/@openai/codex-darwin-arm64/vendor/"
                + "aarch64-apple-darwin/bin/codex"
        )
        recordURL = root.appending(
            path: "record",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: wrapperURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try Data("#!/usr/bin/env node\n".utf8).write(to: wrapperURL)
        #expect(chmod(wrapperURL.path, 0o700) == 0)
        try FileManager.default.createDirectory(
            at: recordURL, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.createDirectory(
            at: executableURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(
            containedInteractiveScript(
                mode: mode,
                recordURL: recordURL
            ).utf8
        ).write(to: executableURL)
        chmod(executableURL.path, 0o700)
        nativeIdentityLease = try CodexNativeExecutableIdentitySource()
            .resolve(
                installation: CodexInstallation(
                    executableURL: wrapperURL, source: .configured
                ),
                expectedUserID: geteuid()
            )
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
            nativeIdentityLease: nativeIdentityLease,
            arguments: arguments,
            environment: environment,
            currentDirectoryURL: workspace.paths.workURL,
            workspace: workspace,
            projectedAuthSourceURL: authSourceURL,
            containmentConfiguration: containment
        )
    }

    func session(
        planBuilder: @escaping CodexContainedInteractiveSession.PlanBuilder
    ) -> CodexContainedInteractiveSession {
        CodexContainedInteractiveSession(
            now: { now },
            planBuilder: planBuilder,
            nativeLauncher: launch
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
            expectedCodexExecutableSHA256: nativeIdentityLease.sha256,
            validBefore: now.addingTimeInterval(60),
            maximumLineBytes: maximumLineBytes,
            maximumSessionBytes: maximumSessionBytes
        )
    }

    func launch(
        _ plan: CodexContainedInteractiveLaunchPlan,
        deadline _: DispatchTime,
        gate _: CodexContainedInteractiveLaunchGate
    ) throws -> CodexContainedInteractiveNativeLaunchReceipt {
        let process = try spawnDiagnosticProcess(
            executableURL: plan.executableURL,
            arguments: plan.arguments,
            environment: plan.environment.values,
            currentDirectoryURL: plan.currentDirectoryURL
        )
        return CodexContainedInteractiveNativeLaunchReceipt(
            process: process,
            codexExecutableSHA256: plan.nativeIdentityLease.sha256,
            nativeIdentityLease: plan.nativeIdentityLease
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

    func waitForEscapedPID() throws -> (pid_t, ContinuousClock.Instant) {
        try Data().write(to: recordURL.appending(path: "escaped.publish"))
        let pid = try waitForRecordedPID(
            name: "escaped.pid", timeout: .seconds(5))
        let start = ContinuousClock.now
        try Data().write(to: recordURL.appending(path: "escaped.hold"))
        return (pid, start)
    }

    func waitForRecordedPID(
        name: String, timeout: Duration = .seconds(2)
    ) throws -> pid_t {
        let url = recordURL.appending(path: name)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
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

    func waitForRecordedPGID() throws -> pid_t {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if
                let value = try? String(
                    contentsOf: recordURL.appending(path: "pgid.txt"),
                    encoding: .utf8
                ).trimmingCharacters(in: .whitespacesAndNewlines),
                let processGroupID = pid_t(value)
            {
                return processGroupID
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

private actor SuspendedContainedPlanBuilder {
    private let plan: CodexContainedInteractiveLaunchPlan
    private var continuation: CheckedContinuation<Void, Never>?
    private var waiter: CheckedContinuation<Void, Never>?

    init(plan: CodexContainedInteractiveLaunchPlan) {
        self.plan = plan
    }

    func build() async throws -> CodexContainedInteractiveLaunchPlan {
        await withCheckedContinuation {
            continuation = $0
            waiter?.resume()
            waiter = nil
        }
        return plan
    }

    func waitUntilEntered() async {
        if continuation != nil {
            return
        }
        await withCheckedContinuation { waiter = $0 }
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}

private actor RetirementCompletionProbe {
    private(set) var value:
        CodexContainedInteractiveOwnerRetirementObservation?

    func record(
        _ observation:
            CodexContainedInteractiveOwnerRetirementObservation
    ) {
        value = observation
    }
}

private enum ContainedInteractiveSessionFixtureError: Error {
    case missingMarker
    case missingPID
    case unexpected
}

private struct NativeInteractiveLauncherFixture {
    let root: URL
    let executableURL: URL
    let lease: CodexNativeExecutableIdentityLease
    let plan: CodexContainedInteractiveLaunchPlan

    init() throws {
        root = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: ".build", directoryHint: .isDirectory)
            .appending(
            path: "StornautNativeLauncher-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        let packageRoot = root.appending(
            path: "lib/node_modules/@openai/codex",
            directoryHint: .isDirectory
        )
        let wrapperURL = packageRoot.appending(path: "bin/codex.js")
        executableURL = packageRoot.appending(
            path: "node_modules/@openai/codex-darwin-arm64/vendor/"
                + "aarch64-apple-darwin/bin/codex"
        )
        try FileManager.default.createDirectory(
            at: wrapperURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("#!/usr/bin/env node\n".utf8).write(to: wrapperURL)
        #expect(chmod(wrapperURL.path, 0o700) == 0)
        try FileManager.default.createDirectory(
            at: executableURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(contentsOf: Self.hostExecutableURL())
            .write(to: executableURL)
        #expect(chmod(executableURL.path, 0o700) == 0)
        #expect(chflags(executableURL.path, 0) == 0)
        lease = try CodexNativeExecutableIdentitySource().resolve(
            installation: CodexInstallation(
                executableURL: wrapperURL, source: .configured
            ),
            expectedUserID: geteuid()
        )
        let workspace = try CodexRuntimeWorkspace.create(
            under: root, forbiddenRoots: []
        )
        let authSourceURL = URL(
            filePath: "/Users/example/.codex/auth.json"
        )
        let policy = CodexContainmentPolicy()
        let containment = try policy.configuration(
            workspace: workspace.paths,
            projectedAuthSourceURL: authSourceURL
        )
        _ = try policy.install(containment, in: workspace.paths)
        plan = CodexContainedInteractiveLaunchPlan(
            executableURL: executableURL,
            nativeIdentityLease: lease,
            arguments: try policy.launchArguments(
                codexExecutableURL: executableURL,
                workspace: workspace.paths
            ),
            environment: try CodexRuntimeEnvironmentPolicy().project(
                inherited: ["PATH": "/usr/bin:/bin"],
                workspace: workspace.paths
            ),
            currentDirectoryURL: workspace.paths.workURL,
            workspace: workspace,
            projectedAuthSourceURL: authSourceURL,
            containmentConfiguration: containment
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }

    private static func hostExecutableURL() throws -> URL {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        for path in [
            ".build/arm64-apple-macosx/debug/stornaut-lifecycle-spike",
            ".build/debug/stornaut-lifecycle-spike",
        ] {
            let candidate = repositoryRoot.appending(path: path)
                .resolvingSymlinksInPath().standardizedFileURL
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        throw ContainedInteractiveSessionFixtureError.unexpected
    }
}

private final class LockedNativeLaunchEvents: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [CodexContainedInteractiveNativeLaunchPhase] = []

    var values: [CodexContainedInteractiveNativeLaunchPhase] {
        lock.withLock { storage }
    }

    func append(_ value: CodexContainedInteractiveNativeLaunchPhase) {
        lock.withLock { storage.append(value) }
    }
}

private final class LockedNativeProcessID: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: pid_t?

    var value: pid_t? { lock.withLock { storage } }

    func set(_ value: pid_t) {
        lock.withLock { storage = value }
    }
}

private final class LockedContainedClock: @unchecked Sendable {
    private let lock = NSLock()
    private var now: Date

    init(now: Date) { self.now = now }

    func read() -> Date { lock.withLock { now } }
}

private final class SuspendedNativeLaunchHook: @unchecked Sendable {
    private let condition = NSCondition()
    private var processID: pid_t?
    private var released = false

    func observe(_ phase: CodexContainedInteractiveNativeLaunchPhase) throws {
        guard case let .beforeResume(processID) = phase else { return }
        condition.lock()
        self.processID = processID
        condition.broadcast()
        while !released, !Task.isCancelled {
            condition.wait(until: Date().addingTimeInterval(0.005))
        }
        condition.unlock()
    }

    func waitUntilBeforeResume() throws -> pid_t {
        let deadline = Date().addingTimeInterval(2)
        condition.lock()
        defer { condition.unlock() }
        while processID == nil, condition.wait(until: deadline) {}
        return try #require(processID)
    }

    func release() {
        condition.lock()
        released = true
        condition.broadcast()
        condition.unlock()
    }
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
    ps -o pgid= -p $$ | tr -d ' ' > "$record_root/pgid.txt"

    if [[ "$mode" == "descendant" ]]; then
        /bin/zsh -c 'trap "" INT TERM; /bin/sleep 30' &
        print -r -- "$!" > "$record_root/child.pid"
    fi
    if [[ "$mode" == "escaped-stderr" ]]; then
        /usr/bin/python3 - "$record_root/escaped.pid" "$record_root/escaped.publish" "$record_root/escaped.hold" <<'PY'
    import os
    import sys
    import time

    pid = os.fork()
    if pid > 0:
        os.waitpid(pid, 0)
        raise SystemExit(0)
    os.setsid()
    if os.fork() > 0: raise SystemExit(0)
    with open(os.path.join(os.path.dirname(sys.argv[1]), "escaped-cleanup.pid"), "w") as handle:
        handle.write(str(os.getpid()))
    while not os.path.exists(sys.argv[2]):
        time.sleep(0.005)
    time.sleep(2.25)
    with open(sys.argv[1], "w", encoding="utf-8") as handle:
        handle.write(str(os.getpid()))
    while not os.path.exists(sys.argv[3]):
        time.sleep(0.005)
    time.sleep(6); os.close(2); time.sleep(24)
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
    if [[ "$mode" == "stderr-overflow" ]]; then
        /usr/bin/python3 - <<'PY'
    import sys
    sys.stderr.write("x" * 256)
    sys.stderr.flush()
    PY
        : > "$record_root/stderr-ready"
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
