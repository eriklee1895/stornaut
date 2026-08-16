import Foundation

public struct InvestigationRuntimeAdmissionRequestV1:
    Sendable,
    Equatable
{
    public let admissionID: DomainToken
    public let investigationID: InvestigationID
    public let runID: InvestigationRunID
    public let sourceFingerprint: InvestigationFingerprint
    public let planFingerprint: InvestigationFingerprint
    public let targetSetFingerprint: InvestigationFingerprint
    public let runtimeReceiptID: DomainToken
    public let runtimeReceiptSchema: DomainToken
    public let disclosureReceiptID: DomainToken
    public let workflowReservationID: DomainToken
    public let finalAdmissionID: DomainToken
    public let startedAt: Date

    package init(
        admissionID: DomainToken,
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        sourceFingerprint: InvestigationFingerprint,
        planFingerprint: InvestigationFingerprint,
        targetSetFingerprint: InvestigationFingerprint,
        runtimeReceiptID: DomainToken,
        runtimeReceiptSchema: DomainToken,
        disclosureReceiptID: DomainToken,
        workflowReservationID: DomainToken,
        finalAdmissionID: DomainToken,
        startedAt: Date
    ) {
        self.admissionID = admissionID
        self.investigationID = investigationID
        self.runID = runID
        self.sourceFingerprint = sourceFingerprint
        self.planFingerprint = planFingerprint
        self.targetSetFingerprint = targetSetFingerprint
        self.runtimeReceiptID = runtimeReceiptID
        self.runtimeReceiptSchema = runtimeReceiptSchema
        self.disclosureReceiptID = disclosureReceiptID
        self.workflowReservationID = workflowReservationID
        self.finalAdmissionID = finalAdmissionID
        self.startedAt = startedAt
    }
}

public struct InvestigationRuntimeAdmissionContextV1: Sendable {
    public let plan: InvestigationPlan
    public let runID: InvestigationRunID
    public let runtimeReceiptID: DomainToken
    public let runtimeReceiptSchema: DomainToken

    public var targetIDs: [InvestigationTargetID] {
        plan.targets.map(\.id)
    }

    package init(
        plan: InvestigationPlan,
        runID: InvestigationRunID,
        runtimeReceiptID: DomainToken,
        runtimeReceiptSchema: DomainToken
    ) {
        self.plan = plan
        self.runID = runID
        self.runtimeReceiptID = runtimeReceiptID
        self.runtimeReceiptSchema = runtimeReceiptSchema
    }
}

public enum InvestigationRuntimeAdmissionClosureResultV1:
    Sendable,
    Equatable
{
    case started(rootSessionID: DomainToken)

    public var rootSessionID: DomainToken {
        switch self {
        case let .started(rootSessionID):
            rootSessionID
        }
    }
}

public struct InvestigationRuntimeAdmissionResultV1:
    Sendable,
    Equatable
{
    public let investigation: InvestigationStoredSession
    public let rootSessionID: DomainToken

    public var state: InvestigationSessionState {
        investigation.state
    }

    public var stage: InvestigationStage {
        investigation.stage
    }

    public init(
        investigation: InvestigationStoredSession,
        rootSessionID: DomainToken
    ) {
        self.investigation = investigation
        self.rootSessionID = rootSessionID
    }
}
