import CryptoKit
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

package enum InvestigationRuntimeReceiptCanonicalV1 {
    package static let productionSchema:
        InvestigationCollaborationSchemaV1 = .collabToolCallV1

    private static let receiptDomain =
        "stornaut.investigation.runtime-receipt.v1"
    private static let receiptIDDomain =
        "stornaut.investigation.runtime-receipt-id.v1"
    private static let schemaVersion: UInt64 = 1
    private static let receiptIDPrefix = "runtime-receipt-"

    package static func receiptID(
        repositoryHEAD: String,
        sourceFingerprintSHA256: String
    ) throws -> DomainToken {
        guard isCanonicalLowercaseHex(repositoryHEAD, count: 40) else {
            throw Error.invalidRepositoryHEAD
        }
        guard isCanonicalLowercaseHex(
            sourceFingerprintSHA256,
            count: 64
        ) else {
            throw Error.invalidSourceFingerprintSHA256
        }

        var projection = Data()
        appendFramed(receiptIDDomain, to: &projection)
        appendBigEndian(schemaVersion, to: &projection)
        appendFramed(repositoryHEAD, to: &projection)
        appendFramed(sourceFingerprintSHA256, to: &projection)

        guard let id = DomainToken(
            rawValue: receiptIDPrefix + sha256Hex(projection)
        ) else {
            throw Error.invalidReceiptID
        }
        return id
    }

    package static func receipt(
        repositoryHEAD: String,
        sourceFingerprintSHA256: String
    ) throws -> InvestigationRuntimeReceiptV1 {
        InvestigationRuntimeReceiptV1(
            id: try receiptID(
                repositoryHEAD: repositoryHEAD,
                sourceFingerprintSHA256: sourceFingerprintSHA256
            ),
            schema: productionSchema,
            capabilityTokens: InvestigationCapability.required
        )
    }

    package static func canonicalData(
        _ receipt: InvestigationRuntimeReceiptV1
    ) throws -> Data {
        guard isCanonicalReceiptID(receipt.id) else {
            throw Error.invalidReceiptID
        }
        guard receipt.schema == productionSchema else {
            throw Error.invalidSchema
        }
        guard receipt.capabilityTokens == InvestigationCapability.required,
              Set(receipt.capabilityTokens).count
                  == receipt.capabilityTokens.count
        else {
            throw Error.invalidCapabilities
        }

        var data = Data()
        appendFramed(receiptDomain, to: &data)
        appendBigEndian(schemaVersion, to: &data)
        appendFramed(receipt.id.rawValue, to: &data)
        appendFramed(receipt.schema.rawValue, to: &data)
        appendBigEndian(UInt64(receipt.capabilityTokens.count), to: &data)
        for capability in receipt.capabilityTokens {
            appendFramed(capability.rawValue, to: &data)
        }
        return data
    }

    package static func sha256(
        _ receipt: InvestigationRuntimeReceiptV1
    ) throws -> String {
        sha256Hex(try canonicalData(receipt))
    }

    package enum Error: Swift.Error, Sendable, Equatable {
        case invalidRepositoryHEAD
        case invalidSourceFingerprintSHA256
        case invalidReceiptID
        case invalidSchema
        case invalidCapabilities
    }

    private static func isCanonicalReceiptID(_ id: DomainToken) -> Bool {
        let value = id.rawValue
        guard value.hasPrefix(receiptIDPrefix) else {
            return false
        }
        return isCanonicalLowercaseHex(
            String(value.dropFirst(receiptIDPrefix.count)),
            count: 64
        )
    }

    private static func isCanonicalLowercaseHex(
        _ value: String,
        count: Int
    ) -> Bool {
        value.utf8.count == count
            && value.utf8.allSatisfy { byte in
                (48...57).contains(byte) || (97...102).contains(byte)
            }
    }

    private static func appendFramed(
        _ value: String,
        to data: inout Data
    ) {
        let bytes = Data(value.utf8)
        appendBigEndian(UInt64(bytes.count), to: &data)
        data.append(bytes)
    }

    private static func appendBigEndian(
        _ value: UInt64,
        to data: inout Data
    ) {
        for shift in stride(from: 56, through: 0, by: -8) {
            data.append(
                UInt8(truncatingIfNeeded: value >> UInt64(shift))
            )
        }
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map {
            String(format: "%02x", $0)
        }.joined()
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

package struct InvestigationRuntimeRootPreparationRequestV1:
    Sendable,
    Equatable
{
    package let investigationID: InvestigationID
    package let runID: InvestigationRunID
    package let receiptID: DomainToken
    package let schema: InvestigationCollaborationSchemaV1

    package init(
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        receiptID: DomainToken,
        schema: InvestigationCollaborationSchemaV1
    ) {
        self.investigationID = investigationID
        self.runID = runID
        self.receiptID = receiptID
        self.schema = schema
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
    func prepareRoot(
        _ request: InvestigationRuntimeRootPreparationRequestV1
    ) async throws

    func start(
        _ request: InvestigationRuntimeStartRequestV1
    ) throws -> InvestigationRuntimeRootV1

    func startTurn(
        _ request: InvestigationRuntimeTurnStartRequestV1
    ) async throws -> InvestigationRuntimeTurnIdentityV1

    func readThreadMetadata(
        threadID: DomainToken,
        rootSessionID: DomainToken
    ) async throws -> InvestigationRuntimeThreadMetadataV1

    func interrupt(
        _ turn: InvestigationRuntimeTurnIdentityV1
    ) async throws

    func retireArtifacts(
        investigationID: InvestigationID,
        runID: InvestigationRunID
    ) async throws
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
    ) async throws -> InvestigationLifecycleDrainResultV1
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
