import Foundation
import Testing
@testable import StornautCore
@testable import StornautInvestigation
@testable import StornautInvestigationMachine
import StornautLifecycle

final class InvestigationMachineScenarioCohortFixture:
    @unchecked Sendable
{
    let now = Date(timeIntervalSince1970: 1_900_000_000)
    let attempts: [InvestigationMachineScenarioAttempt]
    let runners: [InvestigationFixedScenarioRunner]

    init(caseAliased: Bool = false) throws {
        var attempts: [InvestigationMachineScenarioAttempt] = []
        var runners: [InvestigationFixedScenarioRunner] = []
        var scenarios =
            SignedInvestigationRuntimeDiagnosticScenario.allCases
        if caseAliased {
            let successNonce = UUID()
            let successTopology = try LifecycleTopologyCollectorFixture(
                investigationID: LifecycleInvestigationID(
                    rawValue: successNonce
                )
            )
            let successConfiguration = try successTopology.configuration(
                nonce: successNonce,
                scenario: .success
            )
            let success = try InvestigationMachineScenarioAttemptFixture(
                topology: successTopology,
                configuration: successConfiguration,
                now: now,
                materializeOutputs: false
            )
            let aliasRoot = URL(
                filePath: successConfiguration.diagnosticRootPath
                    .lowercased(),
                directoryHint: .isDirectory
            )
            guard aliasRoot.path
                != successConfiguration.diagnosticRootPath
            else {
                throw ScenarioCoordinatorError.unexpectedFlow
            }
            let cancellationNonce = UUID()
            let cancellationTopology =
                try LifecycleTopologyCollectorFixture(
                    investigationID: LifecycleInvestigationID(
                        rawValue: cancellationNonce
                    )
                )
            let cancellationConfiguration =
                try cancellationTopology.configuration(
                    nonce: cancellationNonce,
                    scenario: .cancellation,
                    rootOverride: aliasRoot
                )
            let cancellation =
                try InvestigationMachineScenarioAttemptFixture(
                    topology: cancellationTopology,
                    configuration: cancellationConfiguration,
                    now: now,
                    materializeOutputs: false
                )
            try InvestigationMachineScenarioAttemptFixture
                .materializeOutputFiles(
                    configuration: successConfiguration
                )
            attempts.append(contentsOf: [
                success.attempt,
                cancellation.attempt,
            ])
            runners.append(contentsOf: [
                success.runner,
                cancellation.runner,
            ])
            scenarios.removeAll {
                $0 == .success || $0 == .cancellation
            }
        }
        for scenario in scenarios {
            let fixture = try InvestigationMachineScenarioAttemptFixture(
                scenario: scenario,
                now: now
            )
            attempts.append(fixture.attempt)
            runners.append(fixture.runner)
        }
        self.attempts = attempts
        self.runners = runners
    }
}

func machineScenarioTestVolumeIsCaseInsensitive(
    at url: URL
) -> Bool {
    let values = try? url.resourceValues(
        forKeys: [.volumeSupportsCaseSensitiveNamesKey]
    )
    return values?.volumeSupportsCaseSensitiveNames == false
}

final class InvestigationMachineScenarioAttemptFixture:
    @unchecked Sendable
{
    let topology: LifecycleTopologyCollectorFixture
    let configuration: SignedInvestigationRuntimeDiagnosticConfiguration
    let plan: InvestigationPlan
    let runner: InvestigationFixedScenarioRunner
    let host: InvestigationMachineDriverHost
    let attempt: InvestigationMachineScenarioAttempt
    let eventLog: ScenarioEventLog
    private let scenarioOperation: ScenarioCoordinatorOperation

    convenience init(
        scenario: SignedInvestigationRuntimeDiagnosticScenario,
        now: Date,
        targetSetVariant: String = "primary",
        nonce: UUID = UUID(),
        binding: SignedInvestigationRuntimeBinding? = nil
    ) throws {
        let topology = try LifecycleTopologyCollectorFixture(
            investigationID: LifecycleInvestigationID(rawValue: nonce)
        )
        let configuration = try topology.configuration(
            nonce: nonce,
            binding: binding,
            scenario: scenario
        )
        try self.init(
            topology: topology,
            configuration: configuration,
            now: now,
            targetSetVariant: targetSetVariant,
            materializeOutputs: true
        )
    }

    init(
        topology: LifecycleTopologyCollectorFixture,
        configuration: SignedInvestigationRuntimeDiagnosticConfiguration,
        now: Date,
        targetSetVariant: String = "primary",
        materializeOutputs: Bool
    ) throws {
        self.topology = topology
        self.configuration = configuration
        plan = try Self.plan(
            configuration: configuration,
            now: now,
            targetSetVariant: targetSetVariant
        )
        eventLog = ScenarioEventLog()
        let operation = try ScenarioCoordinatorOperation(
            scenario: configuration.scenario,
            configuration: configuration,
            plan: plan,
            now: now,
            eventLog: eventLog
        )
        scenarioOperation = operation
        runner = try InvestigationFixedScenarioRunner(
            configuration: configuration,
            plan: plan,
            now: now,
            operation: { try await operation.run() }
        )
        host = try Self.makeHost(
            topology: topology,
            configuration: configuration,
            runner: runner,
            eventLog: eventLog
        )
        if materializeOutputs {
            try Self.materializeOutputFiles(
                configuration: configuration
            )
        }
        let syntheticSuccess: InvestigationMachineSyntheticSuccessEvidence?
        if configuration.scenario == .success {
            syntheticSuccess = InvestigationMachineSyntheticSuccessEvidence(
                capabilityEvidenceSHA256: String(repeating: "e", count: 64),
                denials: try Self.denials()
            )
        } else {
            syntheticSuccess = nil
        }
        attempt = try InvestigationMachineScenarioAttempt(
            configuration: configuration,
            plan: plan,
            host: host,
            runner: runner,
            syntheticSuccessEvidence: syntheticSuccess
        )
    }

    func runnerTrace() async throws -> InvestigationFixedScenarioTrace {
        try await scenarioOperation.run()
    }

    static func plan(
        configuration: SignedInvestigationRuntimeDiagnosticConfiguration,
        now: Date,
        targetSetVariant: String
    ) throws -> InvestigationPlan {
        let scanSessionID = ScanSessionID(
            rawValue: "scan-task39-machine-scenarios"
        )!
        let scanScopeID = ScanScopeID(
            rawValue: "scope-task39-machine-scenarios"
        )!
        let target = try InvestigationTarget(
            scanSessionID: scanSessionID,
            scanScopeID: scanScopeID,
            sourceBinding: .snapshot(
                SnapshotID(
                    rawValue: "snapshot-task39-machine-"
                        + targetSetVariant
                )!
            ),
            kind: .unknownLargeConsumer,
            reasonKeys: [
                DomainToken(rawValue: "reason.task39.machine")!,
            ],
            expectedAllocatedBytes: ByteCount(2_147_483_648),
            uncertaintyPermille: 900,
            relevancePermille: 800,
            investigationCostPermille: 500,
            createdAt: now
        )
        return try InvestigationPlan(
            id: InvestigationID(
                rawValue: "investigation-"
                    + configuration.nonce.uuidString.lowercased()
            )!,
            scanSessionID: scanSessionID,
            scanScopeID: scanScopeID,
            sourceFingerprint: InvestigationFingerprint(
                validatingHex:
                    configuration.binding.sourceFingerprintSHA256
            ),
            budgetPreset: .focused,
            targets: [target],
            createdAt: now,
            expiresAt: now.addingTimeInterval(3_600),
            requestedCoveragePermille:
                InvestigationPlan.policyRequestedCoveragePermille,
            remainingUnknownByteThreshold:
                InvestigationPlan.policyRemainingUnknownByteThreshold,
            requiredCapabilities: InvestigationCapability.required
        )
    }

    static func alternateBinding(
        _ binding: SignedInvestigationRuntimeBinding
    ) -> SignedInvestigationRuntimeBinding {
        SignedInvestigationRuntimeBinding(
            repositoryHEAD: binding.repositoryHEAD,
            sourceFingerprintSHA256: binding.sourceFingerprintSHA256,
            appExecutableSHA256: binding.appExecutableSHA256,
            helperExecutableSHA256: binding.helperExecutableSHA256,
            runtimeReceiptSHA256: binding.runtimeReceiptSHA256,
            promptSHA256: String(repeating: "9", count: 64),
            envelopeSchemaSHA256: binding.envelopeSchemaSHA256,
            facadeSHA256: binding.facadeSHA256,
            codexExecutableSHA256: binding.codexExecutableSHA256,
            appBundleIdentifier: binding.appBundleIdentifier,
            helperServiceIdentifier: binding.helperServiceIdentifier
        )
    }

    private static func makeHost(
        topology: LifecycleTopologyCollectorFixture,
        configuration: SignedInvestigationRuntimeDiagnosticConfiguration,
        runner: InvestigationFixedScenarioRunner,
        eventLog: ScenarioEventLog
    ) throws -> InvestigationMachineDriverHost {
        let claim = try retirementClaim(
            topology: topology,
            configuration: configuration
        )
        return InvestigationMachineDriverHost(
            configuration: configuration,
            appProcessIdentity: topology.appIdentity,
            userID: topology.userID,
            handoff: ScenarioHandleHandoff(
                handle: claim.request.handle
            ),
            claimant: ScenarioClaimant(claim: claim),
            collectorFactory: { _ in
                InvestigationLifecycleTopologyCollector(
                    topologyObserver: ScenarioTopologyObserver(
                        installed: try! topology.installedObservation(),
                        postTeardown:
                            try! topology.postTeardownObservation(),
                        eventLog: eventLog
                    ),
                    bindingReader: ScenarioBindingReader(
                        binding: topology.binding
                    ),
                    effectiveUserID: { 0 },
                    now: topology.clock.read
                )
            },
            transition: runner,
            effectiveUserID: { 0 },
            now: topology.clock.read
        )
    }

    private static func retirementClaim(
        topology: LifecycleTopologyCollectorFixture,
        configuration: SignedInvestigationRuntimeDiagnosticConfiguration
    ) throws -> InvestigationMachineRetirementClaim {
        let now = topology.clock.read()
        let handle = try LifecycleMachineRetirementHandle(
            token: UUID(),
            investigationID: LifecycleInvestigationID(
                rawValue: configuration.nonce
            ),
            retireOperationID: UUID(),
            configurationSHA256:
                configuration.machineConfigurationSHA256(),
            validBefore: now.addingTimeInterval(15)
        )
        let request = try LifecycleMachineRetirementClaimRequest(
            handle: handle,
            challengeNonce: UUID(),
            issuedAt: now.addingTimeInterval(-2),
            validBefore: now.addingTimeInterval(13)
        )
        let response = try LifecycleMachineRetirementClaimResponse(
            request: request,
            appIdentity: try machineRecord(topology.appIdentity),
            helperIdentity: try machineRecord(topology.helperIdentity),
            userID: topology.userID,
            recordedAt: now.addingTimeInterval(-3),
            claimedAt: now.addingTimeInterval(-1),
            ownerRetirementObservation: .retiredOwnedResources,
            residueObservation: try LifecycleInvestigationResidueObservation(
                investigationID: LifecycleInvestigationID(
                    rawValue: configuration.nonce
                ),
                auditSessionID: topology.helperIdentity.auditSessionID,
                userID: topology.userID,
                observedAt: now.addingTimeInterval(-4),
                remainingAuditSessionMemberCount: 0,
                matchingLeaseCount: 0,
                leaseRootEntryCount: 0,
                investigationArtifactCount: 0
            )
        )
        return InvestigationMachineRetirementClaim(
            response: response,
            helperPeerIdentity: topology.helperIdentity,
            helperPeerAttestedAt: now.addingTimeInterval(-1)
        )
    }

    private static func machineRecord(
        _ identity: LifecycleProcessIdentity
    ) throws -> LifecycleMachineProcessIdentityRecord {
        try LifecycleMachineProcessIdentityRecord(
            processID: identity.processID,
            processIDVersion: identity.processIDVersion,
            auditSessionID: identity.auditSessionID,
            effectiveUserID: identity.effectiveUserID,
            auditTokenWords: identity.auditToken.words
        )
    }

    static func materializeOutputFiles(
        configuration: SignedInvestigationRuntimeDiagnosticConfiguration
    ) throws {
        for (path, contents) in [
            (configuration.reportPath, Data("scenario-report".utf8)),
            (configuration.storePath, Data("scenario-store".utf8)),
        ] {
            #expect(FileManager.default.createFile(
                atPath: path,
                contents: contents,
                attributes: [.posixPermissions: 0o600]
            ))
        }
    }

    private static func denials() throws
        -> [SignedInvestigationRuntimeDenialEvidence]
    {
        try SignedInvestigationRuntimeDenialKind.allCases.map { kind in
            try SignedInvestigationRuntimeDenialEvidence(
                kind: kind,
                attempted: true,
                contained: true,
                controlReasonKey:
                    "runtime.machine.contained.\(kind.rawValue)",
                failureReasonKey: nil
            )
        }
    }
}

extension InvestigationMachineScenarioAttempt {
    func replacingPlan(
        _ plan: InvestigationPlan
    ) throws -> InvestigationMachineScenarioAttempt {
        try InvestigationMachineScenarioAttempt(
            configuration: configuration,
            plan: plan,
            host: host,
            runner: runner,
            syntheticSuccessEvidence: syntheticSuccessEvidence
        )
    }

    func replacingHostAndRunner(
        host: InvestigationMachineDriverHost,
        runner: InvestigationFixedScenarioRunner
    ) throws -> InvestigationMachineScenarioAttempt {
        try InvestigationMachineScenarioAttempt(
            configuration: configuration,
            plan: plan,
            host: host,
            runner: runner,
            syntheticSuccessEvidence: syntheticSuccessEvidence
        )
    }

}

private final class ScenarioCoordinatorOperation: @unchecked Sendable {
    private let scenario: SignedInvestigationRuntimeDiagnosticScenario
    private let configuration:
        SignedInvestigationRuntimeDiagnosticConfiguration
    private let plan: InvestigationPlan
    private let now: Date
    private let runID: InvestigationRunID
    private let root: InvestigationRuntimeRootV1
    private let turnID: DomainToken
    private let secondTurnID: DomainToken
    private let clock = ScenarioCoordinatorClock()
    private let store: ScenarioCoordinatorStore
    private let runtime: ScenarioCoordinatorRuntime
    private let lifecycle = ScenarioCoordinatorLifecycle()
    private let probe = ScenarioCoordinatorProbe()
    private let coordinator: InvestigationCoordinator
    private let eventLog: ScenarioEventLog

    init(
        scenario: SignedInvestigationRuntimeDiagnosticScenario,
        configuration:
            SignedInvestigationRuntimeDiagnosticConfiguration,
        plan: InvestigationPlan,
        now: Date,
        eventLog: ScenarioEventLog
    ) throws {
        let nonce = configuration.nonce.uuidString.lowercased()
        self.scenario = scenario
        self.configuration = configuration
        self.plan = plan
        self.now = now
        self.eventLog = eventLog
        runID = InvestigationRunID(
            rawValue: "investigation-run-" + nonce
        )!
        let rootID = DomainToken(rawValue: "thread-" + nonce)!
        root = InvestigationRuntimeRootV1(
            id: rootID,
            sessionID: rootID
        )
        turnID = DomainToken(rawValue: "turn-" + nonce)!
        secondTurnID = DomainToken(
            rawValue: "turn-second-" + nonce
        )!
        let session = InvestigationStoredSession(
            id: plan.id,
            runID: runID,
            plan: plan,
            state: .ready,
            stage: .prioritize,
            sourceRowCount: 1,
            relevanceTokenCount: 1,
            createdAt: now,
            updatedAt: now,
            expiresAt: plan.expiresAt
        )
        store = ScenarioCoordinatorStore(session: session)
        runtime = ScenarioCoordinatorRuntime(root: root)
        coordinator = InvestigationCoordinator(
            store: store,
            runtime: runtime,
            lifecycle: lifecycle,
            probe: probe,
            idProvider: ScenarioCoordinatorIDProvider(
                reportID: InvestigationReportID(
                    rawValue: "investigation-report-" + nonce
                )!
            ),
            monotonicNow: clock.read,
            wallNow: { now }
        )
    }

    func run() async throws -> InvestigationFixedScenarioTrace {
        eventLog.append("transition")
        let startedAt = now
        var runStarted = false
        var turnAdmitted = false
        var finalEnvelopeAccepted = false
        var terminalBarrierSettled = false
        var recoveryAttempted = false
        var recoveryCompleted = false
        var finalReportID: InvestigationReportID?
        var outcome: SignedInvestigationRuntimeMachineCaseOutcome

        if scenario == .identityMismatch {
            runtime.setRoot(
                InvestigationRuntimeRootV1(
                    id: root.id,
                    sessionID: DomainToken(
                        rawValue: "thread-foreign-"
                            + configuration.nonce.uuidString.lowercased()
                    )!
                )
            )
            do {
                _ = try await coordinator.start(admission())
                throw ScenarioCoordinatorError.unexpectedFlow
            } catch InvestigationCoordinatorError.runtimeIdentityLost {}
            outcome = .identityMismatchBlocked
        } else {
            _ = try await coordinator.start(admission())
            runStarted = true
            try await coordinator.acceptRootStartedNotification(
                investigationID: plan.id,
                runID: runID,
                root: root,
                payload: payload("root-started")
            )
            _ = try await coordinator.startTurn(
                investigationID: plan.id,
                runID: runID,
                threadID: root.id,
                turnID: turnID,
                contextBytes: Data("scenario-context".utf8)
            )
            turnAdmitted = true
            try await coordinator.acceptTurnStarted(
                investigationID: plan.id,
                runID: runID,
                threadID: root.id,
                turnID: turnID,
                payload: payload("turn-started")
            )

            switch scenario {
            case .success:
                try await retainEnvelope(valid: true)
                try await finishTurn()
                _ = try await admitCoverageStop()
                let result = try await coordinator.settle(
                    investigationID: plan.id,
                    runID: runID
                )
                guard result.investigation.state == .completed,
                      result.report?.kind == .final,
                      store.lastTerminalCause == .coverageReached
                else {
                    throw ScenarioCoordinatorError.unexpectedFlow
                }
                finalEnvelopeAccepted = true
                terminalBarrierSettled = true
                finalReportID = result.report?.id
                outcome = .succeeded
            case .cancellation:
                _ = try await coordinator.cancel(
                    investigationID: plan.id,
                    runID: runID
                )
                try await finishTurn()
                let result = try await coordinator.settle(
                    investigationID: plan.id,
                    runID: runID
                )
                guard result.investigation.state == .partial,
                      store.lastTerminalCause == .userCancelled
                else {
                    throw ScenarioCoordinatorError.unexpectedFlow
                }
                terminalBarrierSettled = true
                outcome = .cancelled
            case .timeout:
                try await finishTurn()
                clock.advance(seconds: 600)
                do {
                    _ = try await coordinator.startTurn(
                        investigationID: plan.id,
                        runID: runID,
                        threadID: root.id,
                        turnID: secondTurnID,
                        contextBytes: Data("timeout-context".utf8)
                    )
                    throw ScenarioCoordinatorError.unexpectedFlow
                } catch InvestigationCoordinatorError
                    .scientificAdmissionClosed {}
                let closing = try await coordinator.requestStop(
                    investigationID: plan.id,
                    runID: runID
                )
                let result = try await coordinator.settle(
                    investigationID: plan.id,
                    runID: runID
                )
                guard result.investigation.state == .blocked,
                      result.report == nil,
                      closing.primaryCause == .budgetExhausted,
                      store.lastTerminalCause == .protocolLost
                else {
                    throw ScenarioCoordinatorError.unexpectedFlow
                }
                terminalBarrierSettled = true
                outcome = .timedOut
            case .invalidEnvelope:
                try await retainEnvelope(valid: false)
                try await finishTurn()
                let progress = try await admitCoverageStop()
                let result = try await coordinator.settle(
                    investigationID: plan.id,
                    runID: runID
                )
                guard result.investigation.state == .blocked,
                      result.report == nil,
                      progress.stopEvaluation == .stop(.coverageReached),
                      store.lastTerminalCause == .protocolLost
                else {
                    throw ScenarioCoordinatorError.unexpectedFlow
                }
                terminalBarrierSettled = true
                outcome = .invalidEnvelopeBlocked
            case .transportLoss:
                try await coordinator.failClosedTransport(
                    investigationID: plan.id,
                    runID: runID
                )
                guard store.lastTransitionCause == .protocolLost else {
                    throw ScenarioCoordinatorError.unexpectedFlow
                }
                outcome = .transportLossBlocked
            case .lifecycleRecovery:
                try await finishTurn()
                _ = try await coordinator.cancel(
                    investigationID: plan.id,
                    runID: runID
                )
                store.setRecoveryCandidateFromCurrentSession()
                lifecycle.setProvedEmpty(false)
                do {
                    _ = try await coordinator.settle(
                        investigationID: plan.id,
                        runID: runID
                    )
                    throw ScenarioCoordinatorError.unexpectedFlow
                } catch InvestigationCoordinatorError.terminalNotReady {}
                guard !lifecycle.confirmedEmpty(runID: runID),
                      store.lastTerminalCause == nil
                else {
                    throw ScenarioCoordinatorError.unexpectedFlow
                }
                store.setRecoveryCandidateFromCurrentSession()
                lifecycle.setProvedEmpty(true)
                recoveryAttempted = true
                recoveryCompleted = try await recoveryCompletedForRun()
                terminalBarrierSettled = recoveryCompleted
                guard store.lastTerminalCause
                    == .runtimeTerminalUnobserved
                else {
                    throw ScenarioCoordinatorError.unexpectedFlow
                }
                outcome = .lifecycleRecovered
            case .artifactCleanupFailure:
                try await finishTurn()
                _ = try await coordinator.cancel(
                    investigationID: plan.id,
                    runID: runID
                )
                runtime.setArtifactRetirementFailure(true)
                do {
                    _ = try await coordinator.settle(
                        investigationID: plan.id,
                        runID: runID
                    )
                    throw ScenarioCoordinatorError.unexpectedFlow
                } catch InvestigationCoordinatorError.terminalNotReady {}
                guard !runtime.retired(runID: runID),
                      runtime.retirementFailureCount == 1,
                      store.lastTerminalCause == nil
                else {
                    throw ScenarioCoordinatorError.unexpectedFlow
                }
                store.setRecoveryCandidateFromCurrentSession()
                recoveryAttempted = true
                runtime.setArtifactRetirementFailure(false)
                recoveryCompleted = try await recoveryCompletedForRun()
                terminalBarrierSettled = recoveryCompleted
                guard store.lastTerminalCause
                    == .runtimeTerminalUnobserved
                else {
                    throw ScenarioCoordinatorError.unexpectedFlow
                }
                outcome = .artifactCleanupRecovered
            case .identityMismatch:
                throw ScenarioCoordinatorError.unexpectedFlow
            }
        }

        let completedAt = now
        return InvestigationFixedScenarioTrace(
            scenario: scenario,
            nonce: configuration.nonce,
            investigationID: plan.id,
            runID: runID,
            finalReportID: finalReportID,
            sourceFingerprint: plan.sourceFingerprint,
            planFingerprint: plan.fingerprint,
            targetSetFingerprint: plan.targetSetFingerprint,
            outcome: outcome,
            runStarted: runStarted,
            turnAdmitted: turnAdmitted,
            finalEnvelopeAccepted: finalEnvelopeAccepted,
            terminalBarrierSettled: terminalBarrierSettled,
            artifactsRetired: runtime.retired(runID: runID),
            localRuntimeDrained:
                lifecycle.confirmedEmpty(runID: runID),
            recoveryAttempted: recoveryAttempted,
            recoveryCompleted: recoveryCompleted,
            observationReasonKey: scenario == .success
                ? nil
                : "runtime.machine.scenario." + scenario.rawValue,
            upstreamError: nil,
            startedAt: startedAt,
            completedAt: completedAt
        )
    }

    private func admission() -> InvestigationStartAdmissionV1 {
        let nonce = configuration.nonce.uuidString.lowercased()
        return InvestigationStartAdmissionV1(
            id: DomainToken(rawValue: "admission-" + nonce)!,
            investigationID: plan.id,
            runID: runID,
            sourceFingerprint: plan.sourceFingerprint,
            planFingerprint: plan.fingerprint,
            targetSetFingerprint: plan.targetSetFingerprint,
            runtimeReceipt: InvestigationRuntimeReceiptV1(
                id: DomainToken(rawValue: "receipt-" + nonce)!,
                schema: .collabToolCallV1,
                capabilityTokens: InvestigationCapability.required
            ),
            disclosureReceiptID:
                DomainToken(rawValue: "disclosure-" + nonce)!,
            workflowReservationID:
                DomainToken(rawValue: "workflow-" + nonce)!,
            finalAdmissionID:
                DomainToken(rawValue: "final-admission-" + nonce)!,
            validBeforeNanoseconds:
                clock.read() + 1_000_000_000
        )
    }

    private func finishTurn() async throws {
        _ = try await coordinator.acceptTokenUsage(
            InvestigationRuntimeTokenUsageEventV1(
                threadID: root.id,
                turnID: turnID,
                total: InvestigationTokenUsage(
                    totalTokens: 100,
                    inputTokens: 50,
                    cachedInputTokens: 25,
                    outputTokens: 50
                ),
                last: InvestigationTokenUsage(
                    totalTokens: 10,
                    inputTokens: 5,
                    cachedInputTokens: 2,
                    outputTokens: 5
                ),
                payload: payload("token-usage")
            )
        )
        try await coordinator.acceptTurnTerminal(
            investigationID: plan.id,
            runID: runID,
            threadID: root.id,
            turnID: turnID,
            payload: payload("turn-terminal")
        )
    }

    private func retainEnvelope(valid: Bool) async throws {
        let data: Data
        if valid {
            let targetID = plan.targets[0].id.rawValue
            data = try JSONSerialization.data(withJSONObject: [
                "protocolVersion": 2,
                "investigationID": plan.id.rawValue,
                "runID": runID.rawValue,
                "summary": "Verified bounded advisory.",
                "coverage": [
                    "investigatedTargetIDs": [targetID],
                    "unresolvedTargets": [],
                ],
                "evidence": [[
                    "id": "evidence-scenario",
                    "targetID": targetID,
                    "source": "probeBroker",
                    "summary": "Structured evidence.",
                    "publicURL": NSNull(),
                ]],
                "findings": [[
                    "id": "finding-scenario",
                    "targetID": targetID,
                    "summary": "The target was investigated.",
                    "evidenceIDs": ["evidence-scenario"],
                    "confidence": "high",
                    "uncertainty": "Current facts remain advisory.",
                ]],
                "candidateProposals": [],
                "capabilityDegradations": [],
            ], options: [.sortedKeys])
        } else {
            data = Data("{\"protocolVersion\":999}".utf8)
        }
        try await coordinator.retainFinalEnvelope(
            investigationID: plan.id,
            runID: runID,
            threadID: root.id,
            turnID: turnID,
            data: data
        )
    }

    private func admitCoverageStop() async throws
        -> InvestigationScientificProgressV1
    {
        try await coordinator.acceptScientificDelta(
            investigationID: plan.id,
            runID: runID,
            delta: InvestigationScientificDeltaV1(
                id: DomainToken(
                    rawValue: "delta-"
                        + configuration.nonce.uuidString.lowercased()
                )!,
                sourceThreadID: root.id,
                sourceTurnID: turnID,
                resolvedTargetIDs: plan.targets.map(\.id),
                remainingUnknown: .measured(ByteCount(0)!),
                stepResult: .verifiedGain
            )
        )
    }

    private func recoveryCoordinator() -> InvestigationCoordinator {
        InvestigationCoordinator(
            store: store,
            runtime: runtime,
            lifecycle: lifecycle,
            probe: probe,
            idProvider: ScenarioCoordinatorIDProvider(
                reportID: InvestigationReportID(
                    rawValue: "investigation-report-"
                        + configuration.nonce.uuidString.lowercased()
                )!
            ),
            monotonicNow: clock.read,
            wallNow: { [now] in now }
        )
    }

    private func recoveryCompletedForRun() async throws -> Bool {
        let recovered = try await recoveryCoordinator().recover(
            now: now,
            limit: 1
        )
        return recovered.count == 1
            && recovered[0].investigation.id == plan.id
            && recovered[0].investigation.runID == runID
            && runtime.retired(runID: runID)
            && lifecycle.confirmedEmpty(runID: runID)
    }

    private func payload(_ value: String) -> Data {
        Data("{\"fixture\":\"\(value)\"}".utf8)
    }
}

private enum ScenarioCoordinatorError: Error {
    case unexpectedFlow
}

private final class ScenarioCoordinatorClock: @unchecked Sendable {
    private let lock = NSLock()
    private var nanoseconds: UInt64 = 1_000_000_000

    func read() -> UInt64 {
        lock.withLock { nanoseconds }
    }

    func advance(seconds: UInt64) {
        lock.withLock { nanoseconds += seconds * 1_000_000_000 }
    }
}

private final class ScenarioCoordinatorStore:
    InvestigationStoreOwning,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var session: InvestigationStoredSession
    private var recoveryCandidate: InvestigationRecoveryCandidate?
    private var terminalCauses: [InvestigationTerminalCause] = []
    private var transitionCauses: [InvestigationTerminalCause] = []

    init(session: InvestigationStoredSession) {
        self.session = session
    }

    var lastTerminalCause: InvestigationTerminalCause? {
        lock.withLock { terminalCauses.last }
    }

    var lastTransitionCause: InvestigationTerminalCause? {
        lock.withLock { transitionCauses.last }
    }

    func setRecoveryCandidateFromCurrentSession() {
        lock.withLock {
            guard ![
                InvestigationSessionState.completed,
                .partial,
                .blocked,
                .failed,
            ].contains(session.state),
            let state = InvestigationRunState(
                rawValue: session.state.rawValue
            )
            else {
                recoveryCandidate = nil
                return
            }
            recoveryCandidate = InvestigationRecoveryCandidate(
                investigationID: session.id,
                runID: session.runID,
                state: state,
                stage: session.stage,
                terminalCause: transitionCauses.last,
                plan: session.plan,
                updatedAt: session.updatedAt,
                expiresAt: session.expiresAt
            )
        }
    }

    func admitRuntimeStart(
        _ request: InvestigationRuntimeAdmissionRequestV1,
        operation: @Sendable (
            InvestigationRuntimeAdmissionContextV1
        ) throws -> InvestigationRuntimeAdmissionClosureResultV1
    ) async throws -> InvestigationRuntimeAdmissionResultV1 {
        let current = lock.withLock { session }
        guard
            request.investigationID == current.id,
            request.runID == current.runID,
            request.sourceFingerprint == current.plan.sourceFingerprint,
            request.planFingerprint == current.plan.fingerprint,
            request.targetSetFingerprint
                == current.plan.targetSetFingerprint
        else {
            throw InvestigationPersistenceError.conflictingReplay
        }
        let result = try operation(
            InvestigationRuntimeAdmissionContextV1(
                plan: current.plan,
                runID: current.runID,
                runtimeReceiptID: request.runtimeReceiptID,
                runtimeReceiptSchema: request.runtimeReceiptSchema
            )
        )
        let running = lock.withLock {
            session = replacing(
                current,
                state: .running,
                stage: current.stage,
                updatedAt: request.startedAt
            )
            return session
        }
        return InvestigationRuntimeAdmissionResultV1(
            investigation: running,
            rootSessionID: result.rootSessionID
        )
    }

    func transition(
        _ command: InvestigationRunTransitionCommand
    ) async throws -> InvestigationStoredSession {
        try lock.withLock {
            guard
                session.id == command.investigationID,
                session.runID == command.runID,
                session.state.rawValue
                    == command.expectedRunState.rawValue
            else {
                throw InvestigationPersistenceError.conflictingReplay
            }
            session = replacing(
                session,
                state: command.sessionState,
                stage: command.stage,
                updatedAt: command.updatedAt
            )
            if let cause = command.terminalCause {
                transitionCauses.append(cause)
            }
            return session
        }
    }

    func settleTerminal(
        _ command: InvestigationTerminalCommand,
        expectedRunState: InvestigationRunState,
        maximumDurationNanoseconds _: UInt64
    ) async throws -> InvestigationTerminalResult {
        try lock.withLock {
            try settle(
                command,
                expectedRunState: expectedRunState
            )
        }
    }

    func recoveryCandidates(
        now: Date,
        limit: Int
    ) async throws -> [InvestigationRecoveryCandidate] {
        lock.withLock {
            guard limit > 0,
                  let recoveryCandidate,
                  recoveryCandidate.expiresAt > now,
                  ![
                    InvestigationRunState.completed,
                    .partial,
                    .blocked,
                    .failed,
                  ].contains(recoveryCandidate.state)
            else {
                return []
            }
            return [recoveryCandidate]
        }
    }

    func settleRecovery(
        _ command: InvestigationTerminalCommand,
        expectedRunState: InvestigationRunState,
        maximumDurationNanoseconds _: UInt64
    ) async throws -> InvestigationTerminalResult {
        try lock.withLock {
            try settle(
                command,
                expectedRunState: expectedRunState
            )
        }
    }

    private func settle(
        _ command: InvestigationTerminalCommand,
        expectedRunState: InvestigationRunState
    ) throws -> InvestigationTerminalResult {
        guard
            session.id == command.investigationID,
            session.runID == command.runID,
            session.state.rawValue == expectedRunState.rawValue
        else {
            throw InvestigationPersistenceError.conflictingReplay
        }
        session = replacing(
            session,
            state: command.sessionState,
            stage: command.stage,
            updatedAt: command.terminalAt
        )
        terminalCauses.append(command.cause)
        recoveryCandidate = nil
        return InvestigationTerminalResult(
            investigation: session,
            report: command.report.map { report in
                InvestigationStoredReport(
                    investigationID: command.investigationID,
                    runID: command.runID,
                    id: report.id,
                    kind: report.kind,
                    createdAt: command.terminalAt,
                    payload: report.payload
                )
            }
        )
    }

    private func replacing(
        _ value: InvestigationStoredSession,
        state: InvestigationSessionState,
        stage: InvestigationStage,
        updatedAt: Date
    ) -> InvestigationStoredSession {
        InvestigationStoredSession(
            id: value.id,
            runID: value.runID,
            plan: value.plan,
            state: state,
            stage: stage,
            sourceRowCount: value.sourceRowCount,
            relevanceTokenCount: value.relevanceTokenCount,
            createdAt: value.createdAt,
            updatedAt: updatedAt,
            expiresAt: value.expiresAt
        )
    }
}

private final class ScenarioCoordinatorRuntime:
    InvestigationRuntimeOwning,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var root: InvestigationRuntimeRootV1
    private var artifactRetirementFails = false
    private var retiredRuns: [InvestigationRunID] = []
    private var failedRetirements = 0

    init(root: InvestigationRuntimeRootV1) {
        self.root = root
    }

    func setRoot(_ root: InvestigationRuntimeRootV1) {
        lock.withLock { self.root = root }
    }

    func setArtifactRetirementFailure(_ value: Bool) {
        lock.withLock { artifactRetirementFails = value }
    }

    func retired(runID: InvestigationRunID) -> Bool {
        lock.withLock { retiredRuns.contains(runID) }
    }

    var retirementFailureCount: Int {
        lock.withLock { failedRetirements }
    }

    func prepareRoot(
        _: InvestigationRuntimeRootPreparationRequestV1
    ) async throws {}

    func start(
        _: InvestigationRuntimeStartRequestV1
    ) throws -> InvestigationRuntimeRootV1 {
        lock.withLock { root }
    }

    func startTurn(
        _ request: InvestigationRuntimeTurnStartRequestV1
    ) async throws -> InvestigationRuntimeTurnIdentityV1 {
        request.identity
    }

    func readThreadMetadata(
        threadID _: DomainToken,
        rootSessionID _: DomainToken
    ) async throws -> InvestigationRuntimeThreadMetadataV1 {
        throw ScenarioCoordinatorError.unexpectedFlow
    }

    func interrupt(
        _: InvestigationRuntimeTurnIdentityV1
    ) async throws {}

    func retireArtifacts(
        investigationID _: InvestigationID,
        runID: InvestigationRunID
    ) async throws {
        try lock.withLock {
            if artifactRetirementFails {
                failedRetirements += 1
                throw ScenarioCoordinatorError.unexpectedFlow
            }
            retiredRuns.append(runID)
        }
    }
}

private final class ScenarioCoordinatorLifecycle:
    InvestigationLifecycleOwning,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var provedEmpty = true
    private var observations:
        [(InvestigationRunID, Bool)] = []

    func setProvedEmpty(_ value: Bool) {
        lock.withLock { provedEmpty = value }
    }

    func confirmedEmpty(runID: InvestigationRunID) -> Bool {
        lock.withLock {
            observations.last { $0.0 == runID }?.1 == true
        }
    }

    func drain(
        investigationID _: InvestigationID,
        runID: InvestigationRunID
    ) async throws -> InvestigationLifecycleDrainResultV1 {
        lock.withLock {
            observations.append((runID, provedEmpty))
            return InvestigationLifecycleDrainResultV1(
                auditSessionEmpty: provedEmpty,
                managedProxyOwnerEmpty: provedEmpty,
                probeWorkerEmpty: provedEmpty
            )
        }
    }
}

private struct ScenarioCoordinatorProbe: InvestigationProbeOwning {
    func prepare(
        runID _: InvestigationRunID,
        limits _: InvestigationBudgetLimits
    ) throws {}

    func execute(
        _: ProbeRequest,
        runID _: InvestigationRunID
    ) async -> ProbeResult {
        .failure(.accessFailed)
    }

    func usage(
        runID _: InvestigationRunID
    ) async -> ProbeBudgetUsage? {
        nil
    }
}

private struct ScenarioCoordinatorIDProvider: InvestigationIDProviding {
    let reportID: InvestigationReportID

    func reportID(
        investigationID _: InvestigationID,
        runID _: InvestigationRunID
    ) throws -> InvestigationReportID {
        reportID
    }
}

private struct ScenarioHandleHandoff:
    InvestigationMachineRetirementHandleHandoff
{
    let handle: LifecycleMachineRetirementHandle

    func takeOnce() async throws -> LifecycleMachineRetirementHandle {
        handle
    }
}

private struct ScenarioClaimant: InvestigationMachineRetirementClaiming {
    let claim: InvestigationMachineRetirementClaim

    func claim(
        handle _: LifecycleMachineRetirementHandle
    ) async throws -> InvestigationMachineRetirementClaim {
        claim
    }
}

private struct ScenarioBindingReader:
    InvestigationLifecycleTopologyBindingReading
{
    let binding: LifecycleRootTopologyBinding

    func readBinding(
        signedBinding _: SignedInvestigationRuntimeBinding
    ) throws -> LifecycleRootTopologyBinding {
        binding
    }
}

private actor ScenarioTopologyObserver:
    InvestigationLifecycleTopologyObserving
{
    let installed: LifecycleRootTopologyObservation
    let postTeardown: LifecycleRootTopologyObservation
    let eventLog: ScenarioEventLog

    init(
        installed: LifecycleRootTopologyObservation,
        postTeardown: LifecycleRootTopologyObservation,
        eventLog: ScenarioEventLog
    ) {
        self.installed = installed
        self.postTeardown = postTeardown
        self.eventLog = eventLog
    }

    func observe(
        _ request: LifecycleRootTopologyObservationRequest
    ) async throws -> LifecycleRootTopologyObservation {
        eventLog.append(
            request.phase == .installed
                ? "installed" : "postTeardown"
        )
        return request.phase == .installed ? installed : postTeardown
    }
}

final class ScenarioEventLog: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []

    func append(_ value: String) {
        lock.withLock { values.append(value) }
    }

    func snapshot() -> [String] {
        lock.withLock { values }
    }
}
