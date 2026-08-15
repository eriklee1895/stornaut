import Foundation

public enum InvestigationPersistenceError:
    Error,
    Sendable,
    Equatable
{
    case noEligibleTargets
    case conflictingReplay
    case sourceMissing
    case sourceCorrupt
    case sourceStale
    case sourceExpired
    case invalidCommand
    case invalidStoredRecord
    case conflictingTerminalReplay
    case quotaExceeded
}

public enum InvestigationStoreProgressPhase:
    String,
    Sendable,
    Equatable,
    CaseIterable
{
    case lockAcquisition
    case sourceProjection
    case planning
    case persistence
    case verification
    case rollback
}

public struct InvestigationStoreProgress: Sendable, Equatable {
    public let phase: InvestigationStoreProgressPhase
    public let checkedRows: UInt64
    public let checkedBytes: UInt64

    public init(
        phase: InvestigationStoreProgressPhase,
        checkedRows: UInt64,
        checkedBytes: UInt64
    ) {
        self.phase = phase
        self.checkedRows = checkedRows
        self.checkedBytes = checkedBytes
    }
}

public enum InvestigationSessionState:
    String,
    Codable,
    Sendable,
    Equatable,
    CaseIterable
{
    case planned
    case awaitingDisclosure
    case ready
    case running
    case pauseRequested
    case stopRequested
    case terminalBarrier
    case paused
    case completed
    case partial
    case blocked
    case failed
}

public enum InvestigationRunState:
    String,
    Codable,
    Sendable,
    Equatable,
    CaseIterable
{
    case planned
    case awaitingDisclosure
    case ready
    case running
    case pauseRequested
    case stopRequested
    case terminalBarrier
    case completed
    case partial
    case blocked
    case failed
}

public enum InvestigationRejoinBarrier:
    String,
    Sendable,
    Equatable,
    CaseIterable
{
    case insertion
    case runtimeAdmission
    case activeRunRefresh
    case terminalNormalization
    case recoveryPromotion
    case continuationCreation
    case reviewProjection
    case cleanupPlanJoin
}

public enum InvestigationRejoinResult: Sendable, Equatable {
    case matching
    case stale
    case corrupt
    case expired
    case missing
}

public struct InvestigationCreateCommand: Sendable, Equatable {
    public let investigationID: InvestigationID
    public let initialRunID: InvestigationRunID
    public let scanSessionID: ScanSessionID
    public let scanScopeID: ScanScopeID
    public let budgetPreset: InvestigationBudgetPreset
    public let planningAt: Date
    public let relevanceTokens: [DomainToken]

    public init(
        investigationID: InvestigationID,
        initialRunID: InvestigationRunID,
        scanSessionID: ScanSessionID,
        scanScopeID: ScanScopeID,
        budgetPreset: InvestigationBudgetPreset,
        planningAt: Date,
        relevanceTokens: [DomainToken]
    ) {
        self.investigationID = investigationID
        self.initialRunID = initialRunID
        self.scanSessionID = scanSessionID
        self.scanScopeID = scanScopeID
        self.budgetPreset = budgetPreset
        self.planningAt = planningAt
        self.relevanceTokens = relevanceTokens
    }
}

public struct InvestigationStoredSession: Sendable, Equatable {
    public let id: InvestigationID
    public let runID: InvestigationRunID
    public let plan: InvestigationPlan
    public let state: InvestigationSessionState
    public let stage: InvestigationStage
    public let sourceRowCount: UInt64
    public let relevanceTokenCount: UInt64
    public let createdAt: Date
    public let updatedAt: Date
    public let expiresAt: Date

    public init(
        id: InvestigationID,
        runID: InvestigationRunID,
        plan: InvestigationPlan,
        state: InvestigationSessionState,
        stage: InvestigationStage,
        sourceRowCount: UInt64,
        relevanceTokenCount: UInt64,
        createdAt: Date,
        updatedAt: Date,
        expiresAt: Date
    ) {
        self.id = id
        self.runID = runID
        self.plan = plan
        self.state = state
        self.stage = stage
        self.sourceRowCount = sourceRowCount
        self.relevanceTokenCount = relevanceTokenCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.expiresAt = expiresAt
    }

    public var initialRunID: InvestigationRunID {
        runID
    }
}

public struct InvestigationStoreRowCounts: Sendable, Equatable {
    public let sessions: Int
    public let sourceRows: Int
    public let relevanceTokens: Int
    public let targets: Int
    public let runs: Int
    public let runTargets: Int
    public let reports: Int
    public let evidence: Int
    public let degradations: Int
    public let budgetEvents: Int

    public init(
        sessions: Int,
        sourceRows: Int,
        relevanceTokens: Int,
        targets: Int,
        runs: Int,
        runTargets: Int,
        reports: Int,
        evidence: Int,
        degradations: Int,
        budgetEvents: Int
    ) {
        self.sessions = sessions
        self.sourceRows = sourceRows
        self.relevanceTokens = relevanceTokens
        self.targets = targets
        self.runs = runs
        self.runTargets = runTargets
        self.reports = reports
        self.evidence = evidence
        self.degradations = degradations
        self.budgetEvents = budgetEvents
    }

    public static let zero = InvestigationStoreRowCounts(
        sessions: 0,
        sourceRows: 0,
        relevanceTokens: 0,
        targets: 0,
        runs: 0,
        runTargets: 0,
        reports: 0,
        evidence: 0,
        degradations: 0,
        budgetEvents: 0
    )
}

public enum InvestigationTerminalCause:
    String,
    Codable,
    Sendable,
    Equatable,
    CaseIterable
{
    case coverageReached = "coverage-reached-v1"
    case remainingUnknownBelowThreshold =
        "remaining-unknown-below-threshold-v1"
    case budgetExhausted = "budget-exhausted-v1"
    case noEvidenceGain = "no-evidence-gain-v1"
    case userStopped = "user-stopped-v1"
    case userCancelled = "user-cancelled-v1"
    case paused = "paused-v1"
    case containmentLost = "containment-lost-v1"
    case lifecycleLost = "lifecycle-lost-v1"
    case runtimeIdentityLost = "runtime-identity-lost-v1"
    case protocolLost = "protocol-lost-v1"
    case runtimeTerminalUnobserved = "runtime-terminal-unobserved-v1"
    case lifecycleDrainUnconfirmed = "lifecycle-drain-unconfirmed-v1"
    case terminalPersistenceFailed = "terminal-persistence-failed-v1"
}

public enum InvestigationReportKind:
    String,
    Codable,
    Sendable,
    Equatable
{
    case final
    case partial
}

public enum InvestigationPersistedEvidenceKind:
    String,
    Codable,
    Sendable,
    Equatable,
    CaseIterable
{
    case finding
    case proposal
    case counterEvidence = "counter-evidence"
    case unresolved
}

public enum InvestigationPersistedDegradationKind:
    String,
    Codable,
    Sendable,
    Equatable,
    CaseIterable
{
    case usageUnavailable = "usage-unavailable"
    case capabilityUnavailable = "capability-unavailable"
    case sourceLimited = "source-limited"
    case runtimeLimited = "runtime-limited"
}

public enum InvestigationPersistedBudgetEventKind:
    String,
    Codable,
    Sendable,
    Equatable,
    CaseIterable
{
    case reservation
    case commit
    case release
    case directToolObservation = "direct-tool-observation"
    case tokenObservation = "token-observation"
    case usageUnavailable = "usage-unavailable"
    case evidenceGain = "evidence-gain"
    case noEvidenceGain = "no-evidence-gain"
    case stopEvaluation = "stop-evaluation"
    case terminalSummary = "terminal-summary"
}

public enum InvestigationPersistenceDomainError:
    Error,
    Sendable,
    Equatable
{
    case invalidText
    case invalidTerminalCommand
}

public struct InvestigationReportPayload:
    Codable,
    Sendable,
    Equatable
{
    public let summary: String

    public init(summary: String) throws {
        guard investigationPersistedTextIsValid(
            summary,
            maximumBytes: 8 * 1_024
        ) else {
            throw InvestigationPersistenceDomainError.invalidText
        }
        self.summary = summary
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        try self.init(
            summary: decoder.container(keyedBy: CodingKeys.self).decode(
                String.self,
                forKey: .summary
            )
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case summary
    }
}

public struct InvestigationEvidencePayload:
    Codable,
    Sendable,
    Equatable
{
    public let summary: String
    public let confidence: DomainToken
    public let uncertainty: String
    public let webProvenance: PersistedWebProvenance?

    public init(
        summary: String,
        confidence: DomainToken,
        uncertainty: String,
        webProvenance: PersistedWebProvenance? = nil
    ) throws {
        guard investigationPersistedTextIsValid(
            summary,
            maximumBytes: 8 * 1_024
        ), investigationPersistedTextIsValid(
            uncertainty,
            maximumBytes: 2 * 1_024
        ) else {
            throw InvestigationPersistenceDomainError.invalidText
        }
        self.summary = summary
        self.confidence = confidence
        self.uncertainty = uncertainty
        self.webProvenance = webProvenance
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            summary: container.decode(String.self, forKey: .summary),
            confidence: container.decode(
                DomainToken.self,
                forKey: .confidence
            ),
            uncertainty: container.decode(
                String.self,
                forKey: .uncertainty
            ),
            webProvenance: container.decodeIfPresent(
                PersistedWebProvenance.self,
                forKey: .webProvenance
            )
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case summary
        case confidence
        case uncertainty
        case webProvenance
    }
}

public struct InvestigationDegradationPayload:
    Codable,
    Sendable,
    Equatable
{
    public let reasonKey: DomainToken
    public let summary: String

    public init(reasonKey: DomainToken, summary: String) throws {
        guard investigationPersistedTextIsValid(
            summary,
            maximumBytes: 8 * 1_024
        ) else {
            throw InvestigationPersistenceDomainError.invalidText
        }
        self.reasonKey = reasonKey
        self.summary = summary
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            reasonKey: container.decode(
                DomainToken.self,
                forKey: .reasonKey
            ),
            summary: container.decode(String.self, forKey: .summary)
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case reasonKey
        case summary
    }
}

public struct InvestigationBudgetEventPayload:
    Codable,
    Sendable,
    Equatable
{
    public let dimension: DomainToken?
    public let amount: UInt64?
    public let quality: DomainToken?

    public init(
        dimension: DomainToken? = nil,
        amount: UInt64? = nil,
        quality: DomainToken? = nil
    ) {
        self.dimension = dimension
        self.amount = amount
        self.quality = quality
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dimension = try container.decodeIfPresent(
            DomainToken.self,
            forKey: .dimension
        )
        amount = try container.decodeIfPresent(
            UInt64.self,
            forKey: .amount
        )
        quality = try container.decodeIfPresent(
            DomainToken.self,
            forKey: .quality
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case dimension
        case amount
        case quality
    }
}

public enum InvestigationEvidenceIDTag: DomainIDTag {
    public static let prefix = "investigation-evidence-"
}

public enum InvestigationDegradationIDTag: DomainIDTag {
    public static let prefix = "investigation-degradation-"
}

public enum InvestigationBudgetEventIDTag: DomainIDTag {
    public static let prefix = "investigation-budget-event-"
}

public typealias InvestigationEvidenceID =
    DomainID<InvestigationEvidenceIDTag>
public typealias InvestigationDegradationID =
    DomainID<InvestigationDegradationIDTag>
public typealias InvestigationBudgetEventID =
    DomainID<InvestigationBudgetEventIDTag>

public struct InvestigationEvidenceInput: Sendable, Equatable {
    public let id: InvestigationEvidenceID
    public let targetID: InvestigationTargetID
    public let kind: InvestigationPersistedEvidenceKind
    public let payload: InvestigationEvidencePayload

    public init(
        id: InvestigationEvidenceID,
        targetID: InvestigationTargetID,
        kind: InvestigationPersistedEvidenceKind,
        payload: InvestigationEvidencePayload
    ) {
        self.id = id
        self.targetID = targetID
        self.kind = kind
        self.payload = payload
    }
}

public struct InvestigationDegradationInput: Sendable, Equatable {
    public let id: InvestigationDegradationID
    public let kind: InvestigationPersistedDegradationKind
    public let payload: InvestigationDegradationPayload

    public init(
        id: InvestigationDegradationID,
        kind: InvestigationPersistedDegradationKind,
        payload: InvestigationDegradationPayload
    ) {
        self.id = id
        self.kind = kind
        self.payload = payload
    }
}

public struct InvestigationBudgetEventInput: Sendable, Equatable {
    public let id: InvestigationBudgetEventID
    public let ordinal: UInt64
    public let kind: InvestigationPersistedBudgetEventKind
    public let payload: InvestigationBudgetEventPayload

    public init(
        id: InvestigationBudgetEventID,
        ordinal: UInt64,
        kind: InvestigationPersistedBudgetEventKind,
        payload: InvestigationBudgetEventPayload
    ) {
        self.id = id
        self.ordinal = ordinal
        self.kind = kind
        self.payload = payload
    }
}

public struct InvestigationTerminalReportInput: Sendable, Equatable {
    public let id: InvestigationReportID
    public let kind: InvestigationReportKind
    public let payload: InvestigationReportPayload
    public let evidence: [InvestigationEvidenceInput]
    public let degradations: [InvestigationDegradationInput]

    public init(
        id: InvestigationReportID,
        kind: InvestigationReportKind,
        payload: InvestigationReportPayload,
        evidence: [InvestigationEvidenceInput],
        degradations: [InvestigationDegradationInput]
    ) {
        self.id = id
        self.kind = kind
        self.payload = payload
        self.evidence = evidence
        self.degradations = degradations
    }
}

public struct InvestigationTerminalCommand: Sendable, Equatable {
    public let investigationID: InvestigationID
    public let runID: InvestigationRunID
    public let runState: InvestigationRunState
    public let sessionState: InvestigationSessionState
    public let stage: InvestigationStage
    public let cause: InvestigationTerminalCause
    public let report: InvestigationTerminalReportInput?
    public let budgetEvents: [InvestigationBudgetEventInput]
    public let terminalAt: Date

    public init(
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        runState: InvestigationRunState,
        sessionState: InvestigationSessionState,
        stage: InvestigationStage,
        cause: InvestigationTerminalCause,
        report: InvestigationTerminalReportInput?,
        budgetEvents: [InvestigationBudgetEventInput],
        terminalAt: Date
    ) throws {
        let expectedKind: InvestigationReportKind?
        switch runState {
        case .completed:
            expectedKind = .final
            guard sessionState == .completed else {
                throw InvestigationPersistenceDomainError
                    .invalidTerminalCommand
            }
        case .partial:
            expectedKind = .partial
            guard sessionState == .partial || sessionState == .paused else {
                throw InvestigationPersistenceDomainError
                    .invalidTerminalCommand
            }
        case .blocked:
            expectedKind = nil
            guard sessionState == .blocked else {
                throw InvestigationPersistenceDomainError
                    .invalidTerminalCommand
            }
        case .failed:
            expectedKind = nil
            guard sessionState == .failed else {
                throw InvestigationPersistenceDomainError
                    .invalidTerminalCommand
            }
        case .planned,
             .awaitingDisclosure,
             .ready,
             .running,
             .pauseRequested,
             .stopRequested,
             .terminalBarrier:
            throw InvestigationPersistenceDomainError.invalidTerminalCommand
        }
        guard report?.kind == expectedKind,
              budgetEvents.contains(where: {
                  $0.kind == .terminalSummary
              })
        else {
            throw InvestigationPersistenceDomainError.invalidTerminalCommand
        }
        self.investigationID = investigationID
        self.runID = runID
        self.runState = runState
        self.sessionState = sessionState
        self.stage = stage
        self.cause = cause
        self.report = report
        self.budgetEvents = budgetEvents
        self.terminalAt = terminalAt
    }
}

public struct InvestigationRunTransitionCommand: Sendable, Equatable {
    public let investigationID: InvestigationID
    public let runID: InvestigationRunID
    public let expectedRunState: InvestigationRunState
    public let runState: InvestigationRunState
    public let sessionState: InvestigationSessionState
    public let stage: InvestigationStage
    public let terminalCause: InvestigationTerminalCause?
    public let updatedAt: Date

    public init(
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        expectedRunState: InvestigationRunState,
        runState: InvestigationRunState,
        sessionState: InvestigationSessionState,
        stage: InvestigationStage,
        terminalCause: InvestigationTerminalCause? = nil,
        updatedAt: Date
    ) throws {
        guard Self.isLegal(
            from: expectedRunState,
            to: runState
        ), sessionState.rawValue == runState.rawValue,
              (runState == .terminalBarrier) == (terminalCause != nil)
        else {
            throw InvestigationPersistenceDomainError
                .invalidTerminalCommand
        }
        self.investigationID = investigationID
        self.runID = runID
        self.expectedRunState = expectedRunState
        self.runState = runState
        self.sessionState = sessionState
        self.stage = stage
        self.terminalCause = terminalCause
        self.updatedAt = updatedAt
    }

    private static func isLegal(
        from: InvestigationRunState,
        to: InvestigationRunState
    ) -> Bool {
        switch (from, to) {
        case (.planned, .awaitingDisclosure),
             (.planned, .ready),
             (.awaitingDisclosure, .ready),
             (.ready, .running),
             (.running, .pauseRequested),
             (.running, .stopRequested),
             (.running, .terminalBarrier),
             (.pauseRequested, .terminalBarrier),
             (.stopRequested, .terminalBarrier):
            true
        default:
            false
        }
    }
}

public struct InvestigationContinuationCommand: Sendable, Equatable {
    public let investigationID: InvestigationID
    public let parentRunID: InvestigationRunID
    public let parentReportID: InvestigationReportID
    public let newRunID: InvestigationRunID
    public let budgetPreset: InvestigationBudgetPreset
    public let planningAt: Date

    public init(
        investigationID: InvestigationID,
        parentRunID: InvestigationRunID,
        parentReportID: InvestigationReportID,
        newRunID: InvestigationRunID,
        budgetPreset: InvestigationBudgetPreset,
        planningAt: Date
    ) throws {
        guard parentRunID != newRunID else {
            throw InvestigationPersistenceDomainError.invalidTerminalCommand
        }
        self.investigationID = investigationID
        self.parentRunID = parentRunID
        self.parentReportID = parentReportID
        self.newRunID = newRunID
        self.budgetPreset = budgetPreset
        self.planningAt = planningAt
    }
}

public struct InvestigationRecoveryCandidate: Sendable, Equatable {
    public let investigationID: InvestigationID
    public let runID: InvestigationRunID
    public let state: InvestigationRunState
    public let stage: InvestigationStage
    public let terminalCause: InvestigationTerminalCause?
    public let plan: InvestigationPlan
    public let updatedAt: Date
    public let expiresAt: Date
}

public struct InvestigationStoredReport: Sendable, Equatable {
    public let investigationID: InvestigationID
    public let runID: InvestigationRunID
    public let id: InvestigationReportID
    public let kind: InvestigationReportKind
    public let createdAt: Date
    public let payload: InvestigationReportPayload
}

public struct InvestigationStoredEvidence: Sendable, Equatable {
    public let investigationID: InvestigationID
    public let reportID: InvestigationReportID
    public let runID: InvestigationRunID
    public let targetID: InvestigationTargetID
    public let id: InvestigationEvidenceID
    public let ordinal: UInt64
    public let kind: InvestigationPersistedEvidenceKind
    public let payload: InvestigationEvidencePayload
}

public struct InvestigationStoredDegradation: Sendable, Equatable {
    public let investigationID: InvestigationID
    public let reportID: InvestigationReportID
    public let runID: InvestigationRunID
    public let id: InvestigationDegradationID
    public let ordinal: UInt64
    public let kind: InvestigationPersistedDegradationKind
    public let payload: InvestigationDegradationPayload
}

public struct InvestigationStoredBudgetEvent: Sendable, Equatable {
    public let investigationID: InvestigationID
    public let runID: InvestigationRunID
    public let id: InvestigationBudgetEventID
    public let ordinal: UInt64
    public let kind: InvestigationPersistedBudgetEventKind
    public let payload: InvestigationBudgetEventPayload
}

public struct InvestigationTerminalResult: Sendable, Equatable {
    public let investigation: InvestigationStoredSession
    public let report: InvestigationStoredReport?
}

struct InvestigationRunStoragePayload: Codable, Sendable, Equatable {
    let investigationID: InvestigationID
    let runID: InvestigationRunID

    init(
        investigationID: InvestigationID,
        runID: InvestigationRunID
    ) {
        self.investigationID = investigationID
        self.runID = runID
    }

    init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        investigationID = try container.decode(
            InvestigationID.self,
            forKey: .investigationID
        )
        runID = try container.decode(
            InvestigationRunID.self,
            forKey: .runID
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case investigationID
        case runID
    }
}

struct InvestigationSourceStorageIdentity: Sendable, Equatable {
    let scanSessionID: ScanSessionID
    let scanScopeID: ScanScopeID
    let sourceFingerprint: InvestigationFingerprint
    let sourceRowCount: UInt64
    let relevanceTokens: [DomainToken]
    let sourcePayloadByteCount: UInt64
    let sourceCanonicalByteCount: UInt64
    let expiresAtMilliseconds: Int64
}

private func investigationPersistedTextIsValid(
    _ value: String,
    maximumBytes: Int
) -> Bool {
    !value.isEmpty
        && value.utf8.count <= maximumBytes
        && !value.unicodeScalars.contains {
            CharacterSet.controlCharacters.contains($0)
        }
}

extension InvestigationBudgetEventPayload: StrictIntegerDomainJSON {}
