import Foundation
import StornautCore

public enum InvestigationCollaborationSchemaV1:
    String,
    Sendable,
    Equatable,
    CaseIterable
{
    case collabToolCallV1 = "collab-tool-call-v1"
    case collabAgentToolCallV1 = "collab-agent-tool-call-v1"

    package var itemType: String {
        switch self {
        case .collabToolCallV1:
            "collabToolCall"
        case .collabAgentToolCallV1:
            "collabAgentToolCall"
        }
    }

    package var spawnTool: String {
        switch self {
        case .collabToolCallV1:
            "spawn_agent"
        case .collabAgentToolCallV1:
            "spawnAgent"
        }
    }
}

public struct InvestigationRuntimeReceiptV1: Sendable, Equatable {
    public let id: DomainToken
    public let schema: InvestigationCollaborationSchemaV1
    public let capabilityTokens: [StornautCore.InvestigationCapability]

    package init(
        id: DomainToken,
        schema: InvestigationCollaborationSchemaV1,
        capabilityTokens: [StornautCore.InvestigationCapability]
    ) {
        self.id = id
        self.schema = schema
        self.capabilityTokens = capabilityTokens
    }
}

public struct InvestigationStartAdmissionV1: Sendable {
    public let id: DomainToken
    public let investigationID: InvestigationID
    public let runID: InvestigationRunID
    public let sourceFingerprint: InvestigationFingerprint
    public let planFingerprint: InvestigationFingerprint
    public let targetSetFingerprint: InvestigationFingerprint
    public let runtimeReceipt: InvestigationRuntimeReceiptV1
    public let disclosureReceiptID: DomainToken
    public let workflowReservationID: DomainToken
    public let finalAdmissionID: DomainToken
    public let validBeforeNanoseconds: UInt64

    private let consumption: InvestigationAdmissionConsumption

    package init(
        id: DomainToken,
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        sourceFingerprint: InvestigationFingerprint,
        planFingerprint: InvestigationFingerprint,
        targetSetFingerprint: InvestigationFingerprint,
        runtimeReceipt: InvestigationRuntimeReceiptV1,
        disclosureReceiptID: DomainToken,
        workflowReservationID: DomainToken,
        finalAdmissionID: DomainToken,
        validBeforeNanoseconds: UInt64
    ) {
        self.id = id
        self.investigationID = investigationID
        self.runID = runID
        self.sourceFingerprint = sourceFingerprint
        self.planFingerprint = planFingerprint
        self.targetSetFingerprint = targetSetFingerprint
        self.runtimeReceipt = runtimeReceipt
        self.disclosureReceiptID = disclosureReceiptID
        self.workflowReservationID = workflowReservationID
        self.finalAdmissionID = finalAdmissionID
        self.validBeforeNanoseconds = validBeforeNanoseconds
        consumption = InvestigationAdmissionConsumption()
    }

    package func consume(at nanoseconds: UInt64) throws {
        guard consumption.consume() else {
            throw InvestigationCoordinatorError.admissionConsumed
        }
        guard nanoseconds < validBeforeNanoseconds else {
            throw InvestigationCoordinatorError.admissionExpired
        }
    }

    package func storeRequest(
        startedAt: Date
    ) -> InvestigationRuntimeAdmissionRequestV1 {
        InvestigationRuntimeAdmissionRequestV1(
            admissionID: id,
            investigationID: investigationID,
            runID: runID,
            sourceFingerprint: sourceFingerprint,
            planFingerprint: planFingerprint,
            targetSetFingerprint: targetSetFingerprint,
            runtimeReceiptID: runtimeReceipt.id,
            runtimeReceiptSchema: DomainToken(
                rawValue: runtimeReceipt.schema.rawValue
            )!,
            disclosureReceiptID: disclosureReceiptID,
            workflowReservationID: workflowReservationID,
            finalAdmissionID: finalAdmissionID,
            startedAt: startedAt
        )
    }
}

private final class InvestigationAdmissionConsumption:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var consumed = false

    func consume() -> Bool {
        lock.withLock {
            guard !consumed else {
                return false
            }
            consumed = true
            return true
        }
    }
}

package struct InvestigationRuntimeRootV1: Sendable, Equatable {
    package let id: DomainToken
    package let sessionID: DomainToken

    package init(id: DomainToken, sessionID: DomainToken) {
        self.id = id
        self.sessionID = sessionID
    }
}

package struct InvestigationRuntimeThreadMetadataV1:
    Sendable,
    Equatable
{
    package let id: DomainToken
    package let parentThreadID: DomainToken?
    package let sessionID: DomainToken

    package init(
        id: DomainToken,
        parentThreadID: DomainToken?,
        sessionID: DomainToken
    ) {
        self.id = id
        self.parentThreadID = parentThreadID
        self.sessionID = sessionID
    }
}

package struct InvestigationRuntimeStartContextV1:
    Sendable,
    Equatable
{
    package let promptText: String
    package let contextBytes: Data
    package let targetIDs: [InvestigationTargetID]

    package init(
        promptText: String,
        contextBytes: Data,
        targetIDs: [InvestigationTargetID]
    ) {
        self.promptText = promptText
        self.contextBytes = contextBytes
        self.targetIDs = targetIDs
    }
}

package struct InvestigationRuntimeStartRequestV1:
    Sendable,
    Equatable
{
    package let investigationID: InvestigationID
    package let runID: InvestigationRunID
    package let receiptID: DomainToken
    package let schema: InvestigationCollaborationSchemaV1
    package let ephemeral: Bool
    package let context: InvestigationRuntimeStartContextV1

    package init(
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        receiptID: DomainToken,
        schema: InvestigationCollaborationSchemaV1,
        ephemeral: Bool,
        context: InvestigationRuntimeStartContextV1
    ) {
        self.investigationID = investigationID
        self.runID = runID
        self.receiptID = receiptID
        self.schema = schema
        self.ephemeral = ephemeral
        self.context = context
    }
}

package struct InvestigationRuntimeTurnStartRequestV1:
    Sendable,
    Equatable
{
    package let identity: InvestigationRuntimeTurnIdentityV1
    package let contextBytes: Data
    package let reservedTurnCount: UInt64
    package let reservedContextBytes: UInt64

    package init(
        identity: InvestigationRuntimeTurnIdentityV1,
        contextBytes: Data,
        reservedTurnCount: UInt64,
        reservedContextBytes: UInt64
    ) {
        self.identity = identity
        self.contextBytes = contextBytes
        self.reservedTurnCount = reservedTurnCount
        self.reservedContextBytes = reservedContextBytes
    }
}

package struct InvestigationRuntimeTurnIdentityV1:
    Sendable,
    Hashable
{
    package let investigationID: InvestigationID
    package let runID: InvestigationRunID
    package let threadID: DomainToken
    package let turnID: DomainToken

    package init(
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        threadID: DomainToken,
        turnID: DomainToken
    ) {
        self.investigationID = investigationID
        self.runID = runID
        self.threadID = threadID
        self.turnID = turnID
    }
}

package protocol InvestigationRuntimeOwning: Sendable {
    func start(
        _ request: InvestigationRuntimeStartRequestV1
    ) throws -> InvestigationRuntimeRootV1

    func startTurn(
        _ request: InvestigationRuntimeTurnStartRequestV1
    ) throws

    func readThreadMetadata(
        threadID: DomainToken,
        rootSessionID: DomainToken
    ) throws -> InvestigationRuntimeThreadMetadataV1

    func interrupt(
        _ turn: InvestigationRuntimeTurnIdentityV1
    ) throws

    func retireArtifacts(
        investigationID: InvestigationID,
        runID: InvestigationRunID
    ) throws
}

package struct InvestigationLifecycleDrainResultV1:
    Sendable,
    Equatable
{
    package let auditSessionEmpty: Bool
    package let managedProxyOwnerEmpty: Bool
    package let probeWorkerEmpty: Bool

    package var provedEmpty: Bool {
        auditSessionEmpty && managedProxyOwnerEmpty && probeWorkerEmpty
    }

    package init(
        auditSessionEmpty: Bool,
        managedProxyOwnerEmpty: Bool,
        probeWorkerEmpty: Bool = true
    ) {
        self.auditSessionEmpty = auditSessionEmpty
        self.managedProxyOwnerEmpty = managedProxyOwnerEmpty
        self.probeWorkerEmpty = probeWorkerEmpty
    }
}

package protocol InvestigationLifecycleOwning: Sendable {
    func drain(
        investigationID: InvestigationID,
        runID: InvestigationRunID
    ) throws -> InvestigationLifecycleDrainResultV1
}

package protocol InvestigationProbeOwning: Sendable {
    func prepare(
        runID: InvestigationRunID,
        limits: InvestigationBudgetLimits
    ) throws

    func execute(
        _ request: ProbeRequest,
        runID: InvestigationRunID
    ) async -> ProbeResult

    func usage(
        runID: InvestigationRunID
    ) async -> ProbeBudgetUsage?
}

package protocol InvestigationIDProviding: Sendable {
    func reportID(
        investigationID: InvestigationID,
        runID: InvestigationRunID
    ) throws -> InvestigationReportID
}

package protocol InvestigationStoreOwning: Sendable {
    func admitRuntimeStart(
        _ request: InvestigationRuntimeAdmissionRequestV1,
        operation: @Sendable (
            InvestigationRuntimeAdmissionContextV1
        ) throws -> InvestigationRuntimeAdmissionClosureResultV1
    ) async throws -> InvestigationRuntimeAdmissionResultV1

    func transition(
        _ command: InvestigationRunTransitionCommand
    ) async throws -> InvestigationStoredSession

    func settleTerminal(
        _ command: InvestigationTerminalCommand,
        expectedRunState: InvestigationRunState,
        maximumDurationNanoseconds: UInt64
    ) async throws -> InvestigationTerminalResult

    func recoveryCandidates(
        now: Date,
        limit: Int
    ) async throws -> [InvestigationRecoveryCandidate]

    func settleRecovery(
        _ command: InvestigationTerminalCommand,
        expectedRunState: InvestigationRunState,
        maximumDurationNanoseconds: UInt64
    ) async throws -> InvestigationTerminalResult
}

extension EvidenceStore: InvestigationStoreOwning {
    package func admitRuntimeStart(
        _ request: InvestigationRuntimeAdmissionRequestV1,
        operation: @Sendable (
            InvestigationRuntimeAdmissionContextV1
        ) throws -> InvestigationRuntimeAdmissionClosureResultV1
    ) async throws -> InvestigationRuntimeAdmissionResultV1 {
        try withInvestigationRuntimeAdmission(
            request,
            operation: operation
        )
    }

    package func transition(
        _ command: InvestigationRunTransitionCommand
    ) async throws -> InvestigationStoredSession {
        try transitionInvestigationRun(command)
    }

    package func settleTerminal(
        _ command: InvestigationTerminalCommand,
        expectedRunState: InvestigationRunState,
        maximumDurationNanoseconds: UInt64
    ) async throws -> InvestigationTerminalResult {
        try settleInvestigationTerminal(
            command,
            expectedRunState: expectedRunState,
            maximumDurationNanoseconds: maximumDurationNanoseconds
        )
    }

    package func recoveryCandidates(
        now: Date,
        limit: Int
    ) async throws -> [InvestigationRecoveryCandidate] {
        try investigationRecoveryCandidates(
            now: now,
            limit: limit,
            offset: 0
        ).records
    }

    package func settleRecovery(
        _ command: InvestigationTerminalCommand,
        expectedRunState: InvestigationRunState,
        maximumDurationNanoseconds: UInt64
    ) async throws -> InvestigationTerminalResult {
        try settleInvestigationRecovery(
            command,
            expectedRunState: expectedRunState,
            maximumDurationNanoseconds: maximumDurationNanoseconds
        )
    }
}
