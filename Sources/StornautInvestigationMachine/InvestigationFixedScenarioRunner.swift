import Foundation
import StornautCore
import StornautInvestigation

enum InvestigationFixedScenarioRunnerError:
    Error,
    Sendable,
    Equatable
{
    case invalidInput
    case invalidObservation
    case consumed
}

struct InvestigationFixedScenarioTrace: Sendable {
    let scenario: SignedInvestigationRuntimeDiagnosticScenario
    let nonce: UUID
    let investigationID: InvestigationID
    let runID: InvestigationRunID
    let finalReportID: InvestigationReportID?
    let sourceFingerprint: InvestigationFingerprint
    let planFingerprint: InvestigationFingerprint
    let targetSetFingerprint: InvestigationFingerprint
    let outcome: SignedInvestigationRuntimeMachineCaseOutcome
    let runStarted: Bool
    let turnAdmitted: Bool
    let finalEnvelopeAccepted: Bool
    let terminalBarrierSettled: Bool
    let artifactsRetired: Bool
    let localRuntimeDrained: Bool
    let recoveryAttempted: Bool
    let recoveryCompleted: Bool
    let observationReasonKey: String?
    let upstreamError: SignedInvestigationRuntimeUpstreamError?
    let startedAt: Date
    let completedAt: Date
}

struct InvestigationFixedScenarioObservation: Sendable, Equatable {
    let scenario: SignedInvestigationRuntimeDiagnosticScenario
    let nonce: UUID
    let investigationID: InvestigationID
    let runID: InvestigationRunID
    let finalReportID: InvestigationReportID?
    let sourceFingerprint: InvestigationFingerprint
    let planFingerprint: InvestigationFingerprint
    let targetSetFingerprint: InvestigationFingerprint
    let outcome: SignedInvestigationRuntimeMachineCaseOutcome
    let runStarted: Bool
    let turnAdmitted: Bool
    let finalEnvelopeAccepted: Bool
    let terminalBarrierSettled: Bool
    let artifactsRetired: Bool
    let localRuntimeDrained: Bool
    let recoveryAttempted: Bool
    let recoveryCompleted: Bool
    let observationReasonKey: String?
    let upstreamError: SignedInvestigationRuntimeUpstreamError?
    let startedAt: Date
    let completedAt: Date

    var isExpectedOutcome: Bool {
        observedControls == expectedControls
            && outcome == expectedOutcome
            && (scenario == .success) == (finalReportID != nil)
            && (scenario == .success) == (observationReasonKey == nil)
    }

    fileprivate init(trace: InvestigationFixedScenarioTrace) throws {
        scenario = trace.scenario
        nonce = trace.nonce
        investigationID = trace.investigationID
        runID = trace.runID
        finalReportID = trace.finalReportID
        sourceFingerprint = trace.sourceFingerprint
        planFingerprint = trace.planFingerprint
        targetSetFingerprint = trace.targetSetFingerprint
        outcome = trace.outcome
        runStarted = trace.runStarted
        turnAdmitted = trace.turnAdmitted
        finalEnvelopeAccepted = trace.finalEnvelopeAccepted
        terminalBarrierSettled = trace.terminalBarrierSettled
        artifactsRetired = trace.artifactsRetired
        localRuntimeDrained = trace.localRuntimeDrained
        recoveryAttempted = trace.recoveryAttempted
        recoveryCompleted = trace.recoveryCompleted
        observationReasonKey = trace.observationReasonKey
        upstreamError = trace.upstreamError
        startedAt = trace.startedAt
        completedAt = trace.completedAt
        guard isExpectedOutcome else {
            throw InvestigationFixedScenarioRunnerError
                .invalidObservation
        }
    }

    private var observedControls: FixedScenarioControls {
        FixedScenarioControls(
            runStarted: runStarted,
            turnAdmitted: turnAdmitted,
            finalEnvelopeAccepted: finalEnvelopeAccepted,
            terminalBarrierSettled: terminalBarrierSettled,
            artifactsRetired: artifactsRetired,
            localRuntimeDrained: localRuntimeDrained,
            recoveryAttempted: recoveryAttempted,
            recoveryCompleted: recoveryCompleted
        )
    }

    private var expectedControls: FixedScenarioControls {
        scenario.fixedScenarioControls
    }

    private var expectedOutcome:
        SignedInvestigationRuntimeMachineCaseOutcome
    {
        scenario.machineOutcome
    }
}

actor InvestigationFixedScenarioRunner:
    InvestigationLifecycleTopologyTransitioning
{
    nonisolated let bindingToken = UUID()

    typealias Operation = @Sendable () async throws
        -> InvestigationFixedScenarioTrace

    private enum State {
        case ready
        case running
        case observed(InvestigationFixedScenarioObservation)
        case consumed
    }

    nonisolated let configuration:
        SignedInvestigationRuntimeDiagnosticConfiguration
    nonisolated let plan: InvestigationPlan
    private let operation: Operation
    private var state = State.ready
    private(set) var invocationCount = 0

    init(
        configuration: SignedInvestigationRuntimeDiagnosticConfiguration,
        plan: InvestigationPlan,
        now: Date,
        operation: @escaping Operation
    ) throws {
        let machineConfigurationValid =
            (try? configuration.validateMachineCohort(now: now)) != nil
            || (try? configuration.validateMachineCohort(
                now: now, outputs: .ownerRegularFile
            )) != nil
        guard
            plan.id.rawValue
                == "investigation-"
                    + configuration.nonce.uuidString.lowercased(),
            plan.sourceFingerprint.hex
                == configuration.binding.sourceFingerprintSHA256,
            machineConfigurationValid
        else {
            throw InvestigationFixedScenarioRunnerError.invalidInput
        }
        self.configuration = configuration
        self.plan = plan
        self.operation = operation
    }

    func transition() async throws {
        guard case .ready = state else {
            throw InvestigationFixedScenarioRunnerError.consumed
        }
        state = .running
        invocationCount += 1
        do {
            let trace = try await operation()
            try validate(trace)
            guard case .running = state else {
                throw InvestigationFixedScenarioRunnerError.consumed
            }
            state = .observed(
                try InvestigationFixedScenarioObservation(trace: trace)
            )
        } catch {
            state = .consumed
            throw error
        }
    }

    func consumeObservation() throws
        -> InvestigationFixedScenarioObservation
    {
        guard case let .observed(observation) = state else {
            throw InvestigationFixedScenarioRunnerError.consumed
        }
        state = .consumed
        return observation
    }

    private func validate(
        _ trace: InvestigationFixedScenarioTrace
    ) throws {
        guard
            trace.scenario == configuration.scenario,
            trace.nonce == configuration.nonce,
            trace.investigationID == plan.id,
            trace.runID.rawValue
                == "investigation-run-"
                    + configuration.nonce.uuidString.lowercased(),
            trace.sourceFingerprint == plan.sourceFingerprint,
            trace.planFingerprint == plan.fingerprint,
            trace.targetSetFingerprint == plan.targetSetFingerprint,
            trace.startedAt.timeIntervalSince1970.isFinite,
            trace.completedAt.timeIntervalSince1970.isFinite,
            trace.completedAt >= trace.startedAt,
            trace.completedAt <= configuration.validBefore,
            trace.completedAt.timeIntervalSince(trace.startedAt)
                <= Double(configuration.maximumWallClockSeconds)
        else {
            throw InvestigationFixedScenarioRunnerError
                .invalidObservation
        }
    }
}

private struct FixedScenarioControls: Equatable {
    let runStarted: Bool
    let turnAdmitted: Bool
    let finalEnvelopeAccepted: Bool
    let terminalBarrierSettled: Bool
    let artifactsRetired: Bool
    let localRuntimeDrained: Bool
    let recoveryAttempted: Bool
    let recoveryCompleted: Bool
}

private extension SignedInvestigationRuntimeDiagnosticScenario {
    var machineOutcome: SignedInvestigationRuntimeMachineCaseOutcome {
        switch self {
        case .success: .succeeded
        case .cancellation: .cancelled
        case .timeout: .timedOut
        case .invalidEnvelope: .invalidEnvelopeBlocked
        case .identityMismatch: .identityMismatchBlocked
        case .transportLoss: .transportLossBlocked
        case .lifecycleRecovery: .lifecycleRecovered
        case .artifactCleanupFailure: .artifactCleanupRecovered
        }
    }

    var fixedScenarioControls: FixedScenarioControls {
        switch self {
        case .success:
            FixedScenarioControls(
                runStarted: true,
                turnAdmitted: true,
                finalEnvelopeAccepted: true,
                terminalBarrierSettled: true,
                artifactsRetired: true,
                localRuntimeDrained: true,
                recoveryAttempted: false,
                recoveryCompleted: false
            )
        case .cancellation, .timeout, .invalidEnvelope:
            FixedScenarioControls(
                runStarted: true,
                turnAdmitted: true,
                finalEnvelopeAccepted: false,
                terminalBarrierSettled: true,
                artifactsRetired: true,
                localRuntimeDrained: true,
                recoveryAttempted: false,
                recoveryCompleted: false
            )
        case .identityMismatch:
            FixedScenarioControls(
                runStarted: false,
                turnAdmitted: false,
                finalEnvelopeAccepted: false,
                terminalBarrierSettled: false,
                artifactsRetired: true,
                localRuntimeDrained: true,
                recoveryAttempted: false,
                recoveryCompleted: false
            )
        case .transportLoss:
            FixedScenarioControls(
                runStarted: true,
                turnAdmitted: true,
                finalEnvelopeAccepted: false,
                terminalBarrierSettled: false,
                artifactsRetired: true,
                localRuntimeDrained: true,
                recoveryAttempted: false,
                recoveryCompleted: false
            )
        case .lifecycleRecovery, .artifactCleanupFailure:
            FixedScenarioControls(
                runStarted: true,
                turnAdmitted: true,
                finalEnvelopeAccepted: false,
                terminalBarrierSettled: true,
                artifactsRetired: true,
                localRuntimeDrained: true,
                recoveryAttempted: true,
                recoveryCompleted: true
            )
        }
    }
}
