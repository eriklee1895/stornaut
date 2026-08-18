import Foundation
import Testing
import StornautInvestigation
@testable import StornautInvestigationMachine

@Suite("Investigation fixed machine scenarios")
struct InvestigationMachineScenarioDriverTests {
    @Test
    func fixedRunnerDerivesEveryExpectedOutcomeFromTask38Flow() async throws {
        let fixture = try InvestigationMachineScenarioCohortFixture()

        var observations: [InvestigationFixedScenarioObservation] = []
        for runner in fixture.runners {
            try await runner.transition()
            observations.append(try await runner.consumeObservation())
        }

        #expect(
            Set(observations.map(\.scenario))
                == Set(SignedInvestigationRuntimeDiagnosticScenario.allCases)
        )
        #expect(observations.allSatisfy { $0.isExpectedOutcome })
        #expect(observations.allSatisfy { $0.artifactsRetired })
        #expect(observations.allSatisfy { $0.localRuntimeDrained })
        #expect(
            observations.filter(\.recoveryAttempted).map(\.scenario)
                .sorted { $0.rawValue < $1.rawValue }
                == [.artifactCleanupFailure, .lifecycleRecovery]
        )
    }

    @Test
    func driverBuildsOneFreshBoundEightScenarioMatrix() async throws {
        let fixture = try InvestigationMachineScenarioCohortFixture()
        let driver = InvestigationMachineScenarioDriver()

        let matrix = try await driver.run(attempts: fixture.attempts)

        #expect(matrix.cases.count == 8)
        #expect(Set(matrix.cases.map(\.nonce)).count == 8)
        #expect(Set(matrix.cases.map(\.planFingerprint)).count == 8)
        #expect(Set(matrix.cases.map(\.targetSetFingerprint)).count == 1)
        #expect(matrix.cases.allSatisfy { $0.isExpectedOutcome })
        #expect(
            matrix.success.capabilityEvidenceSHA256
                == String(repeating: "e", count: 64)
        )
        #expect(
            Set(matrix.success.denials.map(\.kind))
                == SignedInvestigationRuntimeDenialKind.required
        )
        await #expect(throws: InvestigationMachineScenarioDriverError.consumed) {
            _ = try await driver.run(attempts: fixture.attempts)
        }
    }

    @Test
    func missingDuplicateAndForeignAttemptsFailBeforeAnyRunnerStarts()
        async throws
    {
        let missing = try InvestigationMachineScenarioCohortFixture()
        let missingDriver = InvestigationMachineScenarioDriver()
        await #expect(
            throws: InvestigationMachineScenarioDriverError.invalidCohort
        ) {
            _ = try await missingDriver.run(
                attempts: Array(missing.attempts.dropLast())
            )
        }
        await #expect(
            throws: InvestigationMachineScenarioDriverError.consumed
        ) {
            _ = try await missingDriver.run(attempts: missing.attempts)
        }
        for runner in missing.runners {
            #expect(await runner.invocationCount == 0)
        }

        let duplicate = try InvestigationMachineScenarioCohortFixture()
        var duplicateAttempts = duplicate.attempts
        duplicateAttempts[1] = duplicateAttempts[0]
        await #expect(
            throws: InvestigationMachineScenarioDriverError.invalidCohort
        ) {
            _ = try await InvestigationMachineScenarioDriver().run(
                attempts: duplicateAttempts
            )
        }
        for runner in duplicate.runners {
            #expect(await runner.invocationCount == 0)
        }

        let foreign = try InvestigationMachineScenarioCohortFixture()
        let foreignReplacement =
            try InvestigationMachineScenarioAttemptFixture(
                scenario: foreign.attempts[1].configuration.scenario,
                now: foreign.now,
                targetSetVariant: "foreign"
            )
        var foreignAttempts = foreign.attempts
        foreignAttempts[1] = foreignReplacement.attempt
        await #expect(
            throws: InvestigationMachineScenarioDriverError.invalidCohort
        ) {
            _ = try await InvestigationMachineScenarioDriver().run(
                attempts: foreignAttempts
            )
        }
        for runner in foreign.runners {
            #expect(await runner.invocationCount == 0)
        }
        #expect(await foreignReplacement.runner.invocationCount == 0)

        let duplicateNonce = try InvestigationMachineScenarioCohortFixture()
        let replacement = try InvestigationMachineScenarioAttemptFixture(
            scenario: duplicateNonce.attempts[1].configuration.scenario,
            now: duplicateNonce.now,
            nonce: duplicateNonce.attempts[0].configuration.nonce
        )
        var duplicateNonceAttempts = duplicateNonce.attempts
        duplicateNonceAttempts[1] = replacement.attempt
        await #expect(
            throws: InvestigationMachineScenarioDriverError.invalidCohort
        ) {
            _ = try await InvestigationMachineScenarioDriver().run(
                attempts: duplicateNonceAttempts
            )
        }
        for runner in duplicateNonce.runners {
            #expect(await runner.invocationCount == 0)
        }

        let mixedBinding = try InvestigationMachineScenarioCohortFixture()
        let mixed = try InvestigationMachineScenarioAttemptFixture(
            scenario: mixedBinding.attempts[1].configuration.scenario,
            now: mixedBinding.now,
            binding:
                InvestigationMachineScenarioAttemptFixture
                    .alternateBinding(
                        mixedBinding.attempts[1].configuration.binding
                    )
        )
        var mixedAttempts = mixedBinding.attempts
        mixedAttempts[1] = mixed.attempt
        await #expect(
            throws: InvestigationMachineScenarioDriverError.invalidCohort
        ) {
            _ = try await InvestigationMachineScenarioDriver().run(
                attempts: mixedAttempts
            )
        }
        for runner in mixedBinding.runners {
            #expect(await runner.invocationCount == 0)
        }

        let foreignWiring = try InvestigationMachineScenarioCohortFixture()
        var foreignWiringAttempts = foreignWiring.attempts
        #expect(
            throws: InvestigationMachineScenarioDriverError.invalidCohort
        ) {
            foreignWiringAttempts[0] = try foreignWiringAttempts[0]
                .replacingHostAndRunner(
                    host: foreignWiringAttempts[1].host,
                    runner: foreignWiringAttempts[1].runner
                )
        }
        for runner in foreignWiring.runners {
            #expect(await runner.invocationCount == 0)
        }

        let sameBinding = try InvestigationMachineScenarioAttemptFixture(
            scenario: .transportLoss,
            now: foreignWiring.now
        )
        let alternateRunner = try InvestigationFixedScenarioRunner(
            configuration: sameBinding.configuration,
            plan: sameBinding.plan,
            now: sameBinding.topology.clock.read(),
            operation: { try await sameBinding.runnerTrace() }
        )
        #expect(
            throws: InvestigationMachineScenarioDriverError.invalidCohort
        ) {
            _ = try InvestigationMachineScenarioAttempt(
                configuration: sameBinding.configuration,
                plan: sameBinding.plan,
                host: sameBinding.host,
                runner: alternateRunner,
                syntheticSuccessEvidence: nil
            )
        }
        #expect(await sameBinding.runner.invocationCount == 0)
        #expect(await alternateRunner.invocationCount == 0)
    }

    @Test
    func emptyArtifactFailsBeforeAnyRunnerStarts() async throws {
        let fixture = try InvestigationMachineScenarioCohortFixture()
        let path = fixture.attempts[3].configuration.reportPath
        #expect(FileManager.default.createFile(
            atPath: path,
            contents: Data(),
            attributes: [.posixPermissions: 0o600]
        ))

        await #expect(
            throws: InvestigationMachineScenarioDriverError.invalidCohort
        ) {
            _ = try await InvestigationMachineScenarioDriver().run(
                attempts: fixture.attempts
            )
        }
        for runner in fixture.runners {
            #expect(await runner.invocationCount == 0)
        }
    }

    @Test
    func runnerAndObservationAreTerminalAndNonCodable() async throws {
        let fixture = try InvestigationMachineScenarioAttemptFixture(
            scenario: .transportLoss,
            now: Date(timeIntervalSince1970: 1_900_000_000)
        )

        try await fixture.runner.transition()
        let observation = try await fixture.runner.consumeObservation()

        #expect(
            !(InvestigationFixedScenarioObservation.self is any Codable.Type)
        )
        #expect(
            !(InvestigationFixedScenarioTrace.self is any Codable.Type)
        )
        #expect(
            !(InvestigationMachineScenarioAttempt.self is any Codable.Type)
        )
        #expect(
            !(InvestigationMachineSyntheticSuccessEvidence.self
                is any Codable.Type)
        )
        #expect(
            !(InvestigationMachineScenarioDriver.self is any Codable.Type)
        )
        #expect(observation.scenario == .transportLoss)
        await #expect(throws: InvestigationFixedScenarioRunnerError.consumed) {
            try await fixture.runner.transition()
        }
        await #expect(throws: InvestigationFixedScenarioRunnerError.consumed) {
            _ = try await fixture.runner.consumeObservation()
        }
    }

    @Test
    func consumingWhileTransitionIsSuspendedCannotReviveTheRunner()
        async throws
    {
        let fixture = try InvestigationMachineScenarioAttemptFixture(
            scenario: .success,
            now: Date(timeIntervalSince1970: 1_900_000_000)
        )
        let gate = ScenarioOperationGate()
        let bound = try InvestigationFixedScenarioRunner(
            configuration: fixture.configuration,
            plan: fixture.plan,
            now: fixture.topology.clock.read(),
            operation: {
                await gate.arriveAndWait()
                return try await fixture.runnerTrace()
            }
        )
        let transition = Task { try await bound.transition() }
        await gate.waitUntilStarted()

        await #expect(throws: InvestigationFixedScenarioRunnerError.consumed) {
            _ = try await bound.consumeObservation()
        }
        await gate.release()
        try await transition.value
        _ = try await bound.consumeObservation()
        await #expect(throws: InvestigationFixedScenarioRunnerError.consumed) {
            _ = try await bound.consumeObservation()
        }
    }

    @Test
    func hostOrdersInstalledTopologyBeforeOneTransitionAndPostTeardown()
        async throws
    {
        let fixture = try InvestigationMachineScenarioAttemptFixture(
            scenario: .success,
            now: Date(timeIntervalSince1970: 1_900_000_000)
        )

        _ = try await fixture.host.run()
        fixture.eventLog.append("hostReturn")
        _ = try await fixture.runner.consumeObservation()
        fixture.eventLog.append("consume")

        #expect(
            fixture.eventLog.snapshot()
                == [
                    "installed",
                    "transition",
                    "postTeardown",
                    "hostReturn",
                    "consume",
                ]
        )
        #expect(await fixture.runner.invocationCount == 1)
    }

    @Test(
        .enabled(
            if: machineScenarioTestVolumeIsCaseInsensitive(
                at: FileManager.default.temporaryDirectory
            ),
            "Requires a case-insensitive test volume"
        )
    )
    func caseAliasedAttemptObjectsFailBeforeAnyRunnerStarts() async throws {
        let fixture = try InvestigationMachineScenarioCohortFixture(
            caseAliased: true
        )
        let success = fixture.attempts.first {
            $0.configuration.scenario == .success
        }!.configuration
        let cancellation = fixture.attempts.first {
            $0.configuration.scenario == .cancellation
        }!.configuration
        var left = stat()
        var right = stat()
        #expect(lstat(success.diagnosticRootPath, &left) == 0)
        #expect(lstat(cancellation.diagnosticRootPath, &right) == 0)
        #expect(left.st_dev == right.st_dev)
        #expect(left.st_ino == right.st_ino)

        await #expect(
            throws: InvestigationMachineScenarioDriverError.invalidCohort
        ) {
            _ = try await InvestigationMachineScenarioDriver().run(
                attempts: fixture.attempts
            )
        }
        for runner in fixture.runners {
            #expect(await runner.invocationCount == 0)
        }
    }
}

private actor ScenarioOperationGate {
    private var started = false
    private var released = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func arriveAndWait() async {
        started = true
        startWaiters.forEach { $0.resume() }
        startWaiters.removeAll()
        if released { return }
        await withCheckedContinuation { releaseWaiters.append($0) }
    }

    func release() {
        released = true
        releaseWaiters.forEach { $0.resume() }
        releaseWaiters.removeAll()
    }
}
