import Foundation

public enum InvestigationReviewRowClass:
    String,
    Sendable,
    Equatable
{
    case deterministicExecutableCandidate
    case agentAssistedReviewRecommended
    case unresolvedNeedsAnotherInvestigation
    case protected
    case currentEvidenceBlocked
    case noExecutionProfile
}

public enum InvestigationReviewProjectionState:
    String,
    Sendable,
    Equatable
{
    case ready
    case reportBlocked
    case sourceBlocked
    case cleanupUnavailable
}

public struct InvestigationReviewRow: Sendable, Equatable {
    public let targetID: InvestigationTargetID
    public let snapshotID: SnapshotID?
    public let rowClass: InvestigationReviewRowClass
    public let displayDisposition: ReclaimDisposition
    public let suggestedDefault: Bool
    public let isExecutable: Bool
    public let evidence: [InvestigationEvidenceSummary]
}

public struct InvestigationReviewProjectionOutcome: Sendable, Equatable {
    public let state: InvestigationReviewProjectionState
    public let sourceStatus: InvestigationRejoinResult
    public let report: InvestigationReportProjection?
    public let cleanupPlanID: CleanupPlanID?
    public let rows: [InvestigationReviewRow]
}

public struct InvestigationReviewProjector: Sendable {
    typealias ReportSource = @Sendable (
        InvestigationID, InvestigationRunID, InvestigationReportID
    ) async -> InvestigationReportReconciliation
    typealias JoinSource = @Sendable (
        InvestigationID, InvestigationRunID, InvestigationReportID, CleanupPlan?
    ) async throws -> InvestigationRejoinResult
    typealias CleanupSource = @Sendable (
        ScanSessionID, [InvestigationReportTargetBinding]
    ) async -> CleanupPlanBuildOutcome

    private let reportSource: ReportSource
    private let joinSource: JoinSource
    private let cleanupSource: CleanupSource

    init(
        reportSource: @escaping ReportSource,
        joinSource: @escaping JoinSource,
        cleanupSource: @escaping CleanupSource
    ) {
        self.reportSource = reportSource
        self.joinSource = joinSource
        self.cleanupSource = cleanupSource
    }

    public init(store: EvidenceStore) throws {
        let reconciler = InvestigationReportReconciler(store: store)
        let builder = try CleanupPlanBuilder(store: store)
        self.init(
            reportSource: { investigationID, runID, reportID in
                await reconciler.reconcile(
                    investigationID: investigationID,
                    runID: runID,
                    reportID: reportID
                )
            },
            joinSource: { investigationID, runID, reportID, plan in
                try await store.commitCleanupPlanForInvestigation(
                    investigationID: investigationID,
                    runID: runID,
                    reportID: reportID,
                    plan: plan
                )
            },
            cleanupSource: { sessionID, targetBindings in
                await builder.buildForInvestigation(
                    sessionID: sessionID,
                    targetBindings: targetBindings
                )
            }
        )
    }

    public func project(
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        reportID: InvestigationReportID
    ) async -> InvestigationReviewProjectionOutcome {
        let reportResult = await reportSource(
            investigationID, runID, reportID
        )
        guard reportResult.sourceStatus == .matching,
              reportResult.reviewEligible,
              let report = reportResult.report
        else {
            return blockedOutcome(
                state: reportResult.sourceStatus == .matching
                    ? .reportBlocked : .sourceBlocked,
                sourceStatus: reportResult.sourceStatus,
                report: reportResult.report
            )
        }
        do {
            let cleanup = await cleanupSource(
                report.scanSessionID, report.targetBindings
            )
            let plan: CleanupPlan?
            switch cleanup {
            case let .planReady(value, _): plan = value
            case .empty: plan = nil
            case .scanAgain, .unavailable:
                return blockedOutcome(
                    state: .cleanupUnavailable, sourceStatus: .matching,
                    report: report
                )
            }
            guard cleanupIsConsistent(
                cleanup, report: report
            ) else {
                return blockedOutcome(
                    state: .cleanupUnavailable, sourceStatus: .matching,
                    report: report
                )
            }
            let finalSourceStatus = try await joinSource(
                investigationID, runID, reportID, plan
            )
            guard finalSourceStatus == .matching else {
                return blockedOutcome(
                    state: .sourceBlocked, sourceStatus: finalSourceStatus,
                    report: report
                )
            }
            switch cleanup {
            case let .planReady(plan, projection):
                return projectReady(
                    report: report, plan: plan, projection: projection
                )
            case let .empty(projection):
                return projectReady(
                    report: report, plan: nil, projection: projection
                )
            case .scanAgain, .unavailable:
                preconditionFailure("handled before cleanup join")
            }
        } catch {
            return blockedOutcome(
                state: .sourceBlocked, sourceStatus: .corrupt, report: report
            )
        }
    }

    private func projectReady(
        report: InvestigationReportProjection,
        plan: CleanupPlan?,
        projection: ReviewProjection
    ) -> InvestigationReviewProjectionOutcome {
        let planBindingIsValid: Bool
        if let plan {
            planBindingIsValid = plan.scanSessionID == report.scanSessionID
                && plan.scanScopeID == report.scanScopeID
                && plan.id == projection.planID
        } else {
            planBindingIsValid = projection.planID == nil
        }
        guard projection.sessionID == report.scanSessionID,
              planBindingIsValid
        else {
            return blockedOutcome(
                state: .cleanupUnavailable, sourceStatus: .matching,
                report: report
            )
        }
        let deterministicBySnapshot = Dictionary(
            uniqueKeysWithValues: projection.rows.map { ($0.snapshotID, $0) }
        )
        let evidenceByTarget = Dictionary(grouping:
            report.findings.map(\.evidence)
                + report.proposals.map(\.evidence)
                + report.counterEvidence,
            by: \.targetID
        )
        let proposalTargets = Set(report.proposals.map(\.evidence.targetID))
        let unresolvedTargets = Set(report.continuations.map(\.targetID))
        let rows = report.targetBindings.map { target in
            let deterministic = target.snapshotID.flatMap {
                deterministicBySnapshot[$0]
            }.flatMap { row in
                target.classificationID == nil
                    || target.classificationID == row.classificationID
                    ? row : nil
            }
            return reviewRow(
                target: target,
                deterministic: deterministic,
                hasProposal: proposalTargets.contains(target.id),
                isUnresolved: unresolvedTargets.contains(target.id),
                evidence: evidenceByTarget[target.id, default: []]
            )
        }
        return InvestigationReviewProjectionOutcome(
            state: .ready,
            sourceStatus: .matching,
            report: report,
            cleanupPlanID: plan?.id,
            rows: rows
        )
    }

    private func reviewRow(
        target: InvestigationReportTargetBinding,
        deterministic: ReviewProjectionRow?,
        hasProposal: Bool,
        isUnresolved: Bool,
        evidence: [InvestigationEvidenceSummary]
    ) -> InvestigationReviewRow {
        guard let deterministic else {
            if isUnresolved {
                return InvestigationReviewRow(
                    targetID: target.id, snapshotID: target.snapshotID,
                    rowClass: .unresolvedNeedsAnotherInvestigation,
                    displayDisposition: .unknown, suggestedDefault: false,
                    isExecutable: false, evidence: evidence
                )
            }
            return InvestigationReviewRow(
                targetID: target.id, snapshotID: target.snapshotID,
                rowClass: hasProposal
                    ? .agentAssistedReviewRecommended : .noExecutionProfile,
                displayDisposition: hasProposal ? .reviewRecommended : .unknown,
                suggestedDefault: false, isExecutable: false, evidence: evidence
            )
        }
        if deterministic.persistedDisposition == .protected
            || deterministic.currentDisposition == .protected
        {
            return InvestigationReviewRow(
                targetID: target.id, snapshotID: target.snapshotID,
                rowClass: .protected, displayDisposition: .protected,
                suggestedDefault: false, isExecutable: false, evidence: evidence
            )
        }
        if deterministic.eligibility == .currentEvidenceBlocked {
            return InvestigationReviewRow(
                targetID: target.id, snapshotID: target.snapshotID,
                rowClass: .currentEvidenceBlocked,
                displayDisposition: deterministic.currentDisposition,
                suggestedDefault: false, isExecutable: false, evidence: evidence
            )
        }
        if isUnresolved {
            return InvestigationReviewRow(
                targetID: target.id, snapshotID: target.snapshotID,
                rowClass: .unresolvedNeedsAnotherInvestigation,
                displayDisposition: .unknown, suggestedDefault: false,
                isExecutable: false, evidence: evidence
            )
        }
        if deterministic.eligibility == .executable {
            return InvestigationReviewRow(
                targetID: target.id, snapshotID: target.snapshotID,
                rowClass: .deterministicExecutableCandidate,
                displayDisposition: deterministic.currentDisposition,
                suggestedDefault: deterministic.suggestedDefault,
                isExecutable: true, evidence: evidence
            )
        }
        if hasProposal {
            return InvestigationReviewRow(
                targetID: target.id, snapshotID: target.snapshotID,
                rowClass: .agentAssistedReviewRecommended,
                displayDisposition: .reviewRecommended,
                suggestedDefault: false, isExecutable: false, evidence: evidence
            )
        }
        let rowClass: InvestigationReviewRowClass =
            deterministic.eligibility == .noExecutionProfile
                ? .noExecutionProfile : .currentEvidenceBlocked
        return InvestigationReviewRow(
            targetID: target.id, snapshotID: target.snapshotID,
            rowClass: rowClass,
            displayDisposition: deterministic.currentDisposition,
            suggestedDefault: false, isExecutable: false, evidence: evidence
        )
    }

    private func blockedOutcome(
        state: InvestigationReviewProjectionState,
        sourceStatus: InvestigationRejoinResult,
        report: InvestigationReportProjection?
    ) -> InvestigationReviewProjectionOutcome {
        InvestigationReviewProjectionOutcome(
            state: state, sourceStatus: sourceStatus, report: report,
            cleanupPlanID: nil,
            rows: []
        )
    }

    private func cleanupIsConsistent(
        _ cleanup: CleanupPlanBuildOutcome,
        report: InvestigationReportProjection
    ) -> Bool {
        let plan: CleanupPlan?
        let projection: ReviewProjection
        switch cleanup {
        case let .planReady(value, valueProjection):
            plan = value
            projection = valueProjection
        case let .empty(valueProjection):
            plan = nil
            projection = valueProjection
        case .scanAgain, .unavailable:
            return false
        }
        guard projection.sessionID == report.scanSessionID,
              Set(projection.rows.map(\.snapshotID)).count
                == projection.rows.count,
              Set(projection.rows.map(\.classificationID)).count
                == projection.rows.count,
              projection.rows.allSatisfy({ row in
                  report.targetBindings.contains { target in
                      guard target.snapshotID == row.snapshotID else {
                          return false
                      }
                      return target.classificationID == nil
                          || target.classificationID == row.classificationID
                  }
              })
        else {
            return false
        }
        let executablePairs = Set(
            projection.rows.filter { $0.eligibility == .executable }.map {
                "\($0.snapshotID.rawValue):\($0.classificationID.rawValue)"
            }
        )
        let unresolvedTargetIDs = Set(report.continuations.map(\.targetID))
        let unresolvedSnapshotIDs = Set(
            report.targetBindings.filter {
                unresolvedTargetIDs.contains($0.id)
            }.compactMap(\.snapshotID)
        )
        guard projection.rows.allSatisfy({ row in
            row.eligibility != .executable
                || !unresolvedSnapshotIDs.contains(row.snapshotID)
        }) else {
            return false
        }
        if let plan {
            guard plan.scanSessionID == report.scanSessionID,
                  plan.scanScopeID == report.scanScopeID,
                  plan.id == projection.planID
            else {
                return false
            }
            let planPairs = Set(plan.items.map {
                "\($0.snapshotID.rawValue):\($0.classificationID.rawValue)"
            })
            return planPairs == executablePairs
        }
        return projection.planID == nil && executablePairs.isEmpty
    }
}
