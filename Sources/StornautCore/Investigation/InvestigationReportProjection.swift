import Foundation

public enum InvestigationEvidenceDisplaySource:
    String,
    Sendable,
    Equatable,
    CaseIterable
{
    case surveyorQuickScan = "surveyor-quick-scan"
    case ruleCatalog = "rule-catalog"
    case currentActivity = "current-activity"
    case probeBroker = "probe-broker"
    case directRead = "direct-read"
    case shell = "shell-unified-exec"
    case liveSearch = "live-search"
    case browserOrDirectFetch = "browser-direct-fetch"
    case image = "image-inspection"
    case skill = "skill"
    case subagent = "subagent"
    case systemRuntime = "system-runtime"
    case unresolved = "unresolved"
}

public struct InvestigationDisplayText: Sendable, Equatable {
    public let value: String
    public let wasTruncated: Bool

    init(value: String, wasTruncated: Bool) {
        self.value = value
        self.wasTruncated = wasTruncated
    }
}

public struct InvestigationEvidenceSummary: Sendable, Equatable {
    public let id: InvestigationEvidenceID
    public let targetID: InvestigationTargetID
    public let advisoryID: DomainToken?
    public let summary: InvestigationDisplayText
    public let uncertainty: InvestigationDisplayText
    public let confidence: DomainToken
    public let sources: [InvestigationEvidenceDisplaySource]
    public let webOrigin: String?
    public let webProvenanceReason: PersistedWebProvenanceReason?
}

public struct InvestigationFindingProjection: Sendable, Equatable {
    public let evidence: InvestigationEvidenceSummary
}

public struct InvestigationProposalProjection: Sendable, Equatable {
    public let evidence: InvestigationEvidenceSummary
}

public struct InvestigationContinuationProjection: Sendable, Equatable {
    public let targetID: InvestigationTargetID
    public let reason: InvestigationDisplayText
    public let source: InvestigationEvidenceDisplaySource
}

public struct InvestigationDegradationProjection: Sendable, Equatable {
    public let id: InvestigationDegradationID
    public let kind: InvestigationPersistedDegradationKind
    public let reasonKey: DomainToken
    public let summary: InvestigationDisplayText
}

public struct InvestigationCoverageProjection: Sendable, Equatable {
    public let totalTargets: Int
    public let resolvedTargets: Int
    public let unresolvedTargets: Int
}

public struct InvestigationBudgetProjection: Sendable, Equatable {
    public let eventCount: Int
    public let terminalDimension: DomainToken?
    public let terminalAmount: UInt64?
    public let terminalQuality: DomainToken?
}

public struct InvestigationReportProjectionResult: Sendable, Equatable {
    public let projection: InvestigationReportProjection?
    public let isolatedRecordIDs: [String]
    public let reviewEligible: Bool
}

public struct InvestigationReportProjection: Sendable, Equatable {
    public let investigationID: InvestigationID
    public let runID: InvestigationRunID
    public let scanSessionID: ScanSessionID
    public let scanScopeID: ScanScopeID
    public let id: InvestigationReportID
    public let kind: InvestigationReportKind
    public let createdAt: Date
    public let summary: InvestigationDisplayText
    public let findings: [InvestigationFindingProjection]
    public let proposals: [InvestigationProposalProjection]
    public let counterEvidence: [InvestigationEvidenceSummary]
    public let continuations: [InvestigationContinuationProjection]
    public let degradations: [InvestigationDegradationProjection]
    public let coverage: InvestigationCoverageProjection
    public let budget: InvestigationBudgetProjection
    public let stopCause: InvestigationTerminalCause
    public let targetBindings: [InvestigationReportTargetBinding]

    static func make(
        report: InvestigationStoredReport,
        plan: InvestigationPlan,
        terminalCause: InvestigationTerminalCause,
        evidence: [InvestigationStoredEvidence],
        degradations: [InvestigationStoredDegradation],
        budgetEvents: [InvestigationStoredBudgetEvent]
    ) -> InvestigationReportProjectionResult {
        guard report.investigationID == plan.id else {
            return InvestigationReportProjectionResult(
                projection: nil,
                isolatedRecordIDs: [report.id.rawValue],
                reviewEligible: false
            )
        }

        let targetIDs = Set(plan.targets.map(\.id))
        let duplicateEvidenceIDs = duplicateValues(evidence.map(\.id))
        let duplicateProposalIDs = duplicateValues(
            evidence.filter { $0.kind == .proposal }
                .compactMap(\.payload.advisoryID)
        )
        let duplicateUnresolvedTargetIDs = duplicateValues(
            evidence.filter { $0.kind == .unresolved }.map(\.targetID)
        )
        var isolated = Set<String>()
        var findings: [InvestigationFindingProjection] = []
        var proposals: [InvestigationProposalProjection] = []
        var counterEvidence: [InvestigationEvidenceSummary] = []
        var continuations: [InvestigationContinuationProjection] = []

        for record in evidence.sorted(by: evidenceOrder) {
            guard record.investigationID == report.investigationID,
                  record.runID == report.runID,
                  record.reportID == report.id,
                  targetIDs.contains(record.targetID),
                  !duplicateEvidenceIDs.contains(record.id),
                  record.kind != .proposal
                    || record.payload.advisoryID.map({
                        !duplicateProposalIDs.contains($0)
                    }) == true,
                  record.kind != .unresolved
                    || (
                        !duplicateUnresolvedTargetIDs.contains(record.targetID)
                            && record.payload.advisoryID?.rawValue
                                == record.targetID.rawValue
                    ),
                  let sources = displaySources(
                    label: record.payload.sourceLabel
                  ),
                  record.payload.webProvenance == nil
                    || sources.contains(.liveSearch)
                    || sources.contains(.browserOrDirectFetch)
            else {
                isolated.insert(record.id.rawValue)
                continue
            }
            let summary = InvestigationEvidenceSummary(
                id: record.id,
                targetID: record.targetID,
                advisoryID: record.payload.advisoryID,
                summary: displayText(
                    record.payload.summary,
                    maximumBytes: 1_024,
                    forceRedaction: sources.contains(.shell)
                ),
                uncertainty: displayText(
                    record.payload.uncertainty,
                    maximumBytes: 512,
                    forceRedaction: sources.contains(.shell)
                ),
                confidence: record.payload.confidence,
                sources: sources,
                webOrigin: record.payload.webProvenance?.origin,
                webProvenanceReason: record.payload.webProvenance?.reason
            )
            switch record.kind {
            case .finding:
                guard record.payload.advisoryID != nil else {
                    isolated.insert(record.id.rawValue)
                    continue
                }
                findings.append(InvestigationFindingProjection(evidence: summary))
            case .proposal:
                guard record.payload.advisoryID != nil else {
                    isolated.insert(record.id.rawValue)
                    continue
                }
                proposals.append(InvestigationProposalProjection(evidence: summary))
            case .counterEvidence:
                counterEvidence.append(summary)
            case .unresolved:
                continuations.append(
                    InvestigationContinuationProjection(
                        targetID: record.targetID,
                        reason: summary.summary,
                        source: sources.first ?? .unresolved
                    )
                )
            }
        }

        let duplicateDegradationIDs = duplicateValues(degradations.map(\.id))
        let projectedDegradations = degradations.sorted(by: degradationOrder)
            .compactMap { record -> InvestigationDegradationProjection? in
                guard record.investigationID == report.investigationID,
                      record.runID == report.runID,
                      record.reportID == report.id,
                      !duplicateDegradationIDs.contains(record.id)
                else {
                    isolated.insert(record.id.rawValue)
                    return nil
                }
                return InvestigationDegradationProjection(
                    id: record.id,
                    kind: record.kind,
                    reasonKey: record.payload.reasonKey,
                    summary: displayText(
                        record.payload.summary, maximumBytes: 1_024
                    )
                )
            }

        let duplicateBudgetIDs = duplicateValues(budgetEvents.map(\.id))
        let validBudget = budgetEvents.sorted(by: budgetOrder).filter { record in
            let valid = record.investigationID == report.investigationID
                && record.runID == report.runID
                && !duplicateBudgetIDs.contains(record.id)
            if !valid { isolated.insert(record.id.rawValue) }
            return valid
        }
        let terminalBudget = validBudget.last { $0.kind == .terminalSummary }
        let unresolvedTargetIDs = Set(continuations.map(\.targetID))
        let findingTargetIDs = Set(findings.map(\.evidence.targetID))
        let resolvedTargetIDs = findingTargetIDs.subtracting(unresolvedTargetIDs)
        if !findingTargetIDs.intersection(unresolvedTargetIDs).isEmpty {
            isolated.insert(report.id.rawValue)
        }
        if resolvedTargetIDs.count + unresolvedTargetIDs.count
            != plan.targets.count
        {
            isolated.insert(report.id.rawValue)
        }
        let projection = InvestigationReportProjection(
            investigationID: report.investigationID,
            runID: report.runID,
            scanSessionID: plan.scanSessionID,
            scanScopeID: plan.scanScopeID,
            id: report.id,
            kind: report.kind,
            createdAt: report.createdAt,
            summary: displayText(report.payload.summary, maximumBytes: 2_048),
            findings: findings,
            proposals: proposals,
            counterEvidence: counterEvidence,
            continuations: continuations,
            degradations: projectedDegradations,
            coverage: InvestigationCoverageProjection(
                totalTargets: plan.targets.count,
                resolvedTargets: resolvedTargetIDs.count,
                unresolvedTargets: unresolvedTargetIDs.count
            ),
            budget: InvestigationBudgetProjection(
                eventCount: validBudget.count,
                terminalDimension: terminalBudget?.payload.dimension,
                terminalAmount: terminalBudget?.payload.amount,
                terminalQuality: terminalBudget?.payload.quality
            ),
            stopCause: terminalCause,
            targetBindings: plan.targets.map(InvestigationReportTargetBinding.init)
        )
        return InvestigationReportProjectionResult(
            projection: projection,
            isolatedRecordIDs: isolated.sorted(),
            reviewEligible: isolated.isEmpty
        )
    }
}

public struct InvestigationReportTargetBinding: Sendable, Equatable {
    public let id: InvestigationTargetID
    public let snapshotID: SnapshotID?
    public let classificationID: ClassificationID?

    init(_ target: InvestigationTarget) {
        id = target.id
        switch target.sourceBinding {
        case let .snapshot(value):
            snapshotID = value
            classificationID = nil
        case let .classification(classification, snapshot):
            snapshotID = snapshot
            classificationID = classification
        case .spaceLedger:
            snapshotID = nil
            classificationID = nil
        }
    }
}

private func duplicateValues<Value: Hashable>(_ values: [Value]) -> Set<Value> {
    var seen = Set<Value>()
    var duplicates = Set<Value>()
    for value in values where !seen.insert(value).inserted {
        duplicates.insert(value)
    }
    return duplicates
}

private func evidenceOrder(
    _ lhs: InvestigationStoredEvidence,
    _ rhs: InvestigationStoredEvidence
) -> Bool {
    if lhs.ordinal != rhs.ordinal { return lhs.ordinal < rhs.ordinal }
    return lhs.id.rawValue < rhs.id.rawValue
}

private func degradationOrder(
    _ lhs: InvestigationStoredDegradation,
    _ rhs: InvestigationStoredDegradation
) -> Bool {
    if lhs.ordinal != rhs.ordinal { return lhs.ordinal < rhs.ordinal }
    return lhs.id.rawValue < rhs.id.rawValue
}

private func budgetOrder(
    _ lhs: InvestigationStoredBudgetEvent,
    _ rhs: InvestigationStoredBudgetEvent
) -> Bool {
    if lhs.ordinal != rhs.ordinal { return lhs.ordinal < rhs.ordinal }
    return lhs.id.rawValue < rhs.id.rawValue
}

private func displaySources(
    label: DomainToken?
) -> [InvestigationEvidenceDisplaySource]? {
    guard let raw = label?.rawValue, raw.hasPrefix("source.") else {
        return nil
    }
    let values = raw.dropFirst("source.".count).split(separator: ".")
    guard !values.isEmpty else { return nil }
    var sources: [InvestigationEvidenceDisplaySource] = []
    for value in values {
        let source: InvestigationEvidenceDisplaySource
        switch value {
        case "surveyor", "quickScan": source = .surveyorQuickScan
        case "rule", "ruleCatalog": source = .ruleCatalog
        case "activity", "currentActivity": source = .currentActivity
        case "probeBroker": source = .probeBroker
        case "directFile", "directRead": source = .directRead
        case "shell", "unifiedExec": source = .shell
        case "liveSearch": source = .liveSearch
        case "browserOrDirectFetch": source = .browserOrDirectFetch
        case "image", "imageInspection": source = .image
        case "skill", "skills": source = .skill
        case "subagent", "subagents": source = .subagent
        case "system", "runtime", "runtime-unavailable":
            source = .systemRuntime
        case "unresolved": source = .unresolved
        default: return nil
        }
        if !sources.contains(source) { sources.append(source) }
    }
    return sources.sorted { $0.rawValue < $1.rawValue }
}

private func displayText(
    _ input: String,
    maximumBytes: Int,
    forceRedaction: Bool = false
) -> InvestigationDisplayText {
    let redacted = forceRedaction || containsSensitiveDisplayContent(input)
        ? "[sensitive content redacted]"
        : input
    guard redacted.utf8.count > maximumBytes else {
        return InvestigationDisplayText(value: redacted, wasTruncated: false)
    }
    let marker = "…"
    let prefixLimit = max(0, maximumBytes - marker.utf8.count)
    var value = ""
    value.reserveCapacity(prefixLimit)
    for character in redacted {
        let next = String(character)
        guard value.utf8.count + next.utf8.count <= prefixLimit else { break }
        value.append(character)
    }
    return InvestigationDisplayText(value: value + marker, wasTruncated: true)
}

private func containsSensitiveDisplayContent(_ input: String) -> Bool {
    if input.contains("<") || input.contains(">") { return true }
    if input.unicodeScalars.contains(where: {
        switch $0.properties.generalCategory {
        case .control, .format, .privateUse, .surrogate, .unassigned:
            true
        default:
            false
        }
    }) {
        return true
    }
    let patterns = [
        #"(?i)[a-z][a-z0-9+.-]*:[^[:space:]]"#,
        #"(?:^|[^A-Za-z0-9:])(?:/|~[A-Za-z0-9._-]{0,64}/)[^[:space:]]"#,
        #"(?:^|[[:space:]])-[A-Za-z0-9-]+(?:[[:space:]]|$)"#,
        #"(?:\$\(|`|&&|\|\||[;|<>*])"#,
    ]
    return patterns.contains { pattern in
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return true
        }
        return expression.firstMatch(
            in: input,
            range: NSRange(input.startIndex..., in: input)
        ) != nil
    }
}
