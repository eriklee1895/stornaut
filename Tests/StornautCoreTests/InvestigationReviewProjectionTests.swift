import Foundation
import Testing
@testable import StornautCore

@Suite("Investigation conservative Review projection")
struct InvestigationReviewProjectionTests {
    @Test
    func agentOnlyRuleMissIsReviewRecommendedAndNeverExecutable_BitsUT() async throws {
        let fixture = try InvestigationReportProjectionFixture()
        let report = try completeReportProjection(fixture: fixture)
        let snapshotID = try #require(fixture.snapshotTargetID)
        let classificationID = try #require(
            fixture.snapshotTargetClassificationID
        )
        let deterministic = try ReviewProjection(
            sessionID: fixture.plan.scanSessionID,
            planID: nil,
            rows: [
                ReviewProjectionRow(
                    snapshotID: snapshotID,
                    classificationID: classificationID,
                    relativePath: "Library/Caches/unknown",
                    ruleID: nil,
                    persistedDisposition: .unknown,
                    currentDisposition: .unknown,
                    eligibility: .persistedDispositionBlocked,
                    suggestedDefault: false,
                    reasonKeys: [DomainToken(rawValue: "review.unknown")!]
                ),
            ],
            totalRowCount: 1,
            counts: try ReviewProjectionCounts(
                executableReady: 0, executableReview: 0,
                noExecutionProfile: 0, persistedDispositionBlocked: 1,
                currentEvidenceBlocked: 0
            )
        )
        let calls = InvestigationReviewCallLog()
        let projector = InvestigationReviewProjector(
            reportSource: { _, _, _ in
                calls.record("report")
                return InvestigationReportReconciliation(
                    sourceStatus: .matching, report: report,
                    isolatedRecordIDs: [], reviewEligible: true
                )
            },
            joinSource: { _, _, _, _ in
                calls.record("join")
                return .matching
            },
            cleanupSource: { _, _ in
                calls.record("builder")
                return .empty(deterministic)
            }
        )

        let outcome = await projector.project(
            investigationID: fixture.plan.id, runID: fixture.runID,
            reportID: fixture.reportID
        )

        #expect(outcome.state == .ready)
        #expect(outcome.cleanupPlanID == nil)
        let row = try #require(outcome.rows.first {
            $0.targetID == fixture.snapshotTarget.id
        })
        #expect(row.rowClass == .agentAssistedReviewRecommended)
        #expect(row.displayDisposition == .reviewRecommended)
        #expect(!row.suggestedDefault)
        #expect(!row.isExecutable)
        #expect(calls.values == [
            "report", "builder", "join",
        ])
    }

    @Test
    func deterministicPlanAndSelectionRemainBuilderOwned_BitsUT() async throws {
        let fixture = try InvestigationReportProjectionFixture()
        let report = try completeReportProjection(fixture: fixture)
        let snapshotID = try #require(fixture.snapshotTargetID)
        let classificationID = try #require(
            fixture.snapshotTargetClassificationID
        )
        let identity = try FileIdentity(
            device: 7, inode: 11, mode: UInt16(S_IFDIR | 0o700),
            ownerUserID: getuid(), ownerGroupID: getgid(),
            size: 4_096, allocatedBytes: 4_096,
            modificationSeconds: 1_800_100_000, modificationNanoseconds: 0
        )
        let plan = try CleanupPlan(
            id: CleanupPlanID(rawValue: "plan-investigation-review")!,
            scanSessionID: fixture.plan.scanSessionID,
            scanScopeID: fixture.plan.scanScopeID,
            primaryRootIdentity: identity,
            catalogVersion: DomainToken(rawValue: "catalog-current")!,
            executionProfileVersion: DomainToken(rawValue: "profile-current")!,
            planFingerprint: DomainToken(rawValue: "plan-fingerprint-current")!,
            createdAt: fixture.createdAt,
            expiresAt: fixture.createdAt.addingTimeInterval(300),
            items: [
                try CleanupPlanItem(
                    id: CleanupPlanItemID(
                        rawValue: "plan-item-investigation-review"
                    )!,
                    snapshotID: snapshotID,
                    classificationID: classificationID,
                    ruleID: DomainToken(rawValue: "rule.current")!,
                    executionProfileID: DomainToken(
                        rawValue: "profile.current"
                    )!,
                    proposedAction: .moveToTrash,
                    expectedRelativePath: PersistedPath(
                        rawValue: "Library/Caches/known"
                    )!,
                    expectedIdentity: identity,
                    logicalBytes: ByteCount(4_096)!,
                    allocatedBytes: ByteCount(4_096)!,
                    evidenceFingerprint: DomainToken(
                        rawValue: "evidence.current"
                    )!,
                    activityFingerprint: DomainToken(
                        rawValue: "activity.current"
                    )!
                ),
            ]
        )
        let deterministic = try ReviewProjection(
            sessionID: fixture.plan.scanSessionID, planID: plan.id,
            rows: [
                ReviewProjectionRow(
                    snapshotID: snapshotID, classificationID: classificationID,
                    relativePath: "Library/Caches/known",
                    ruleID: DomainToken(rawValue: "rule.current"),
                    persistedDisposition: .readyToReclaim,
                    currentDisposition: .readyToReclaim,
                    eligibility: .executable, suggestedDefault: true,
                    reasonKeys: [DomainToken(rawValue: "review.current.executable")!]
                ),
            ], totalRowCount: 1,
            counts: try ReviewProjectionCounts(
                executableReady: 1, executableReview: 0,
                noExecutionProfile: 0, persistedDispositionBlocked: 0,
                currentEvidenceBlocked: 0
            )
        )
        let projector = InvestigationReviewProjector(
            reportSource: { _, _, _ in
                InvestigationReportReconciliation(
                    sourceStatus: .matching, report: report,
                    isolatedRecordIDs: [], reviewEligible: true
                )
            },
            joinSource: { _, _, _, _ in .matching },
            cleanupSource: { _, _ in .planReady(plan, deterministic) }
        )

        let outcome = await projector.project(
            investigationID: fixture.plan.id, runID: fixture.runID,
            reportID: fixture.reportID
        )

        #expect(outcome.state == .ready)
        #expect(outcome.cleanupPlanID == plan.id)
        let row = try #require(outcome.rows.first { $0.snapshotID == snapshotID })
        #expect(row.rowClass == .deterministicExecutableCandidate)
        #expect(row.displayDisposition == .readyToReclaim)
        #expect(row.suggestedDefault)
        #expect(row.isExecutable)
    }

    @Test(arguments: [
        InvestigationRejoinResult.stale, .expired, .corrupt, .missing,
    ])
    func cleanupJoinFailureDiscardsBuilderOutput_BitsUT(
        _ failure: InvestigationRejoinResult
    ) async throws {
        let fixture = try InvestigationReportProjectionFixture()
        let report = try completeReportProjection(fixture: fixture)
        let calls = InvestigationReviewCallLog()
        let projector = InvestigationReviewProjector(
            reportSource: { _, _, _ in
                InvestigationReportReconciliation(
                    sourceStatus: .matching, report: report,
                    isolatedRecordIDs: [], reviewEligible: true
                )
            },
            joinSource: { _, _, _, _ in
                calls.record("join")
                return failure
            },
            cleanupSource: { _, _ in
                calls.record("builder")
                return .empty(try! emptyReviewProjection(sessionID:
                    fixture.plan.scanSessionID))
            }
        )

        let outcome = await projector.project(
            investigationID: fixture.plan.id, runID: fixture.runID,
            reportID: fixture.reportID
        )

        #expect(outcome.state == .sourceBlocked)
        #expect(outcome.sourceStatus == failure)
        #expect(outcome.cleanupPlanID == nil)
        #expect(outcome.rows.isEmpty)
        #expect(calls.values == ["builder", "join"])
    }

    @Test
    func currentEvidenceBlockCannotBePromotedByAgentProposal_BitsUT() async throws {
        let fixture = try InvestigationReportProjectionFixture()
        let report = try completeReportProjection(fixture: fixture)
        let snapshotID = try #require(fixture.snapshotTargetID)
        let projection = try ReviewProjection(
            sessionID: fixture.plan.scanSessionID, planID: nil,
            rows: [
                ReviewProjectionRow(
                    snapshotID: snapshotID,
                    classificationID: try #require(
                        fixture.snapshotTargetClassificationID
                    ),
                    relativePath: "Library/Caches/unknown", ruleID: nil,
                    persistedDisposition: .reviewRecommended,
                    currentDisposition: .unknown,
                    eligibility: .currentEvidenceBlocked,
                    suggestedDefault: false,
                    reasonKeys: [DomainToken(
                        rawValue: "review.current.evidence-blocked"
                    )!]
                ),
            ], totalRowCount: 1,
            counts: try ReviewProjectionCounts(
                executableReady: 0, executableReview: 0,
                noExecutionProfile: 0, persistedDispositionBlocked: 0,
                currentEvidenceBlocked: 1
            )
        )
        let projector = InvestigationReviewProjector(
            reportSource: { _, _, _ in
                InvestigationReportReconciliation(
                    sourceStatus: .matching, report: report,
                    isolatedRecordIDs: [], reviewEligible: true
                )
            },
            joinSource: { _, _, _, _ in .matching },
            cleanupSource: { _, _ in .empty(projection) }
        )

        let outcome = await projector.project(
            investigationID: fixture.plan.id, runID: fixture.runID,
            reportID: fixture.reportID
        )
        let row = try #require(outcome.rows.first { $0.snapshotID == snapshotID })
        #expect(row.rowClass == .currentEvidenceBlocked)
        #expect(row.displayDisposition == .unknown)
        #expect(!row.isExecutable)
        #expect(!row.suggestedDefault)
    }

    @Test
    func inconsistentBuilderProjectionFailsClosedWithoutJoining_BitsUT() async throws {
        let fixture = try InvestigationReportProjectionFixture()
        let report = try completeReportProjection(fixture: fixture)
        let snapshotID = try #require(fixture.snapshotTargetID)
        let rows = ["a", "b"].map { suffix in
            ReviewProjectionRow(
                snapshotID: snapshotID,
                classificationID: ClassificationID(
                    rawValue: "classification-duplicate-\(suffix)"
                )!,
                relativePath: "Library/Caches/unknown/\(suffix)",
                ruleID: nil, persistedDisposition: .unknown,
                currentDisposition: .unknown,
                eligibility: .persistedDispositionBlocked,
                suggestedDefault: false,
                reasonKeys: [DomainToken(rawValue: "review.unknown")!]
            )
        }
        let projection = try ReviewProjection(
            sessionID: fixture.plan.scanSessionID, planID: nil,
            rows: rows, totalRowCount: 2,
            counts: try ReviewProjectionCounts(
                executableReady: 0, executableReview: 0,
                noExecutionProfile: 0, persistedDispositionBlocked: 2,
                currentEvidenceBlocked: 0
            )
        )
        let calls = InvestigationReviewCallLog()
        let projector = InvestigationReviewProjector(
            reportSource: { _, _, _ in
                InvestigationReportReconciliation(
                    sourceStatus: .matching, report: report,
                    isolatedRecordIDs: [], reviewEligible: true
                )
            },
            joinSource: { _, _, _, _ in
                calls.record("join")
                return .matching
            },
            cleanupSource: { _, _ in .empty(projection) }
        )

        let outcome = await projector.project(
            investigationID: fixture.plan.id, runID: fixture.runID,
            reportID: fixture.reportID
        )

        #expect(outcome.state == .cleanupUnavailable)
        #expect(outcome.cleanupPlanID == nil)
        #expect(calls.values.isEmpty)
    }

    @Test
    func builderRowsOutsideInvestigationTargetsFailClosed_BitsUT() async throws {
        let fixture = try InvestigationReportProjectionFixture()
        let report = try completeReportProjection(fixture: fixture)
        let projection = try ReviewProjection(
            sessionID: fixture.plan.scanSessionID, planID: nil,
            rows: [
                ReviewProjectionRow(
                    snapshotID: SnapshotID(rawValue: "snapshot-review-foreign")!,
                    classificationID: ClassificationID(
                        rawValue: "classification-review-foreign"
                    )!,
                    relativePath: "Library/Caches/foreign", ruleID: nil,
                    persistedDisposition: .unknown,
                    currentDisposition: .unknown,
                    eligibility: .persistedDispositionBlocked,
                    suggestedDefault: false,
                    reasonKeys: [DomainToken(rawValue: "review.unknown")!]
                ),
            ], totalRowCount: 1,
            counts: try ReviewProjectionCounts(
                executableReady: 0, executableReview: 0,
                noExecutionProfile: 0, persistedDispositionBlocked: 1,
                currentEvidenceBlocked: 0
            )
        )
        let calls = InvestigationReviewCallLog()
        let projector = InvestigationReviewProjector(
            reportSource: { _, _, _ in
                InvestigationReportReconciliation(
                    sourceStatus: .matching, report: report,
                    isolatedRecordIDs: [], reviewEligible: true
                )
            }, joinSource: { _, _, _, _ in
                calls.record("join")
                return .matching
            }, cleanupSource: { _, _ in .empty(projection) }
        )

        let outcome = await projector.project(
            investigationID: fixture.plan.id, runID: fixture.runID,
            reportID: fixture.reportID
        )

        #expect(outcome.state == .cleanupUnavailable)
        #expect(outcome.cleanupPlanID == nil)
        #expect(outcome.rows.isEmpty)
        #expect(calls.values.isEmpty)
    }

    @Test
    func classificationMismatchAndUnresolvedExecutableFailClosed_BitsUT() async throws {
        let fixture = try InvestigationReportProjectionFixture()
        let complete = try completeReportProjection(fixture: fixture)
        let snapshotID = try #require(fixture.snapshotTargetID)
        let wrongClassification = ClassificationID(
            rawValue: "classification-review-foreign"
        )!
        let row = ReviewProjectionRow(
            snapshotID: snapshotID, classificationID: wrongClassification,
            relativePath: "Library/Caches/known",
            ruleID: DomainToken(rawValue: "rule.current"),
            persistedDisposition: .readyToReclaim,
            currentDisposition: .readyToReclaim, eligibility: .executable,
            suggestedDefault: true,
            reasonKeys: [DomainToken(rawValue: "review.current.executable")!]
        )
        let projection = try ReviewProjection(
            sessionID: fixture.plan.scanSessionID, planID: nil,
            rows: [row], totalRowCount: 1,
            counts: try ReviewProjectionCounts(
                executableReady: 1, executableReview: 0,
                noExecutionProfile: 0, persistedDispositionBlocked: 0,
                currentEvidenceBlocked: 0
            )
        )
        let mismatchProjector = InvestigationReviewProjector(
            reportSource: { _, _, _ in
                InvestigationReportReconciliation(
                    sourceStatus: .matching, report: complete,
                    isolatedRecordIDs: [], reviewEligible: true
                )
            }, joinSource: { _, _, _, _ in .matching },
            cleanupSource: { _, _ in .empty(projection) }
        )
        let mismatch = await mismatchProjector.project(
            investigationID: fixture.plan.id, runID: fixture.runID,
            reportID: fixture.reportID
        )
        #expect(mismatch.state == .cleanupUnavailable)
        #expect(mismatch.rows.isEmpty)

        let unresolvedEvidence = try fixture.plan.targets.map { target in
            try fixture.evidence(
                suffix: "all-unresolved-\(target.id.rawValue.suffix(12))",
                target: target, kind: .unresolved,
                advisoryID: target.id.rawValue,
                sourceLabel: "source.unresolved", summary: "Unresolved"
            )
        }
        let unresolvedReport = try #require(
            InvestigationReportProjection.make(
                report: fixture.report(summary: "Unresolved report"),
                plan: fixture.plan, terminalCause: .paused,
                evidence: unresolvedEvidence, degradations: [], budgetEvents: []
            ).projection
        )
        let unresolvedProjector = InvestigationReviewProjector(
            reportSource: { _, _, _ in
                InvestigationReportReconciliation(
                    sourceStatus: .matching, report: unresolvedReport,
                    isolatedRecordIDs: [], reviewEligible: true
                )
            }, joinSource: { _, _, _, _ in .matching },
            cleanupSource: { _, _ in .empty(projection) }
        )
        let unresolved = await unresolvedProjector.project(
            investigationID: fixture.plan.id, runID: fixture.runID,
            reportID: fixture.reportID
        )
        #expect(unresolved.state == .cleanupUnavailable)
        #expect(unresolved.rows.isEmpty)
    }

    @Test(arguments: [
        (ReviewEligibility.persistedDispositionBlocked,
         ReclaimDisposition.protected, InvestigationReviewRowClass.protected),
        (ReviewEligibility.currentEvidenceBlocked,
         ReclaimDisposition.unknown,
         InvestigationReviewRowClass.currentEvidenceBlocked),
    ])
    func currentDeterministicBlockPrecedesHistoricalUnresolved_BitsUT(
        eligibility: ReviewEligibility,
        disposition: ReclaimDisposition,
        expectedClass: InvestigationReviewRowClass
    ) async throws {
        let fixture = try InvestigationReportProjectionFixture()
        let unresolvedEvidence = try fixture.plan.targets.map { target in
            try fixture.evidence(
                suffix: "precedence-\(target.id.rawValue.suffix(12))",
                target: target, kind: .unresolved,
                advisoryID: target.id.rawValue, sourceLabel: "source.unresolved",
                summary: "Unresolved"
            )
        }
        let report = try #require(InvestigationReportProjection.make(
            report: fixture.report(summary: "Unresolved report"),
            plan: fixture.plan, terminalCause: .paused,
            evidence: unresolvedEvidence, degradations: [], budgetEvents: []
        ).projection)
        let snapshotID = try #require(fixture.snapshotTargetID)
        let projection = try ReviewProjection(
            sessionID: fixture.plan.scanSessionID, planID: nil,
            rows: [
                ReviewProjectionRow(
                    snapshotID: snapshotID,
                    classificationID: try #require(
                        fixture.snapshotTargetClassificationID
                    ),
                    relativePath: "Library/Caches/unknown", ruleID: nil,
                    persistedDisposition: disposition,
                    currentDisposition: disposition, eligibility: eligibility,
                    suggestedDefault: false,
                    reasonKeys: [DomainToken(rawValue: "review.current.blocked")!]
                ),
            ], totalRowCount: 1,
            counts: try ReviewProjectionCounts(
                executableReady: 0, executableReview: 0, noExecutionProfile: 0,
                persistedDispositionBlocked:
                    eligibility == .persistedDispositionBlocked ? 1 : 0,
                currentEvidenceBlocked:
                    eligibility == .currentEvidenceBlocked ? 1 : 0
            )
        )
        let projector = InvestigationReviewProjector(
            reportSource: { _, _, _ in
                InvestigationReportReconciliation(
                    sourceStatus: .matching, report: report,
                    isolatedRecordIDs: [], reviewEligible: true
                )
            }, joinSource: { _, _, _, _ in .matching },
            cleanupSource: { _, _ in .empty(projection) }
        )

        let outcome = await projector.project(
            investigationID: fixture.plan.id, runID: fixture.runID,
            reportID: fixture.reportID
        )
        let row = try #require(outcome.rows.first {
            $0.targetID == fixture.snapshotTarget.id
        })
        #expect(row.rowClass == expectedClass)
        #expect(row.displayDisposition == disposition)
        #expect(!row.isExecutable)
        #expect(!row.suggestedDefault)
    }
}

private func completeReportProjection(
    fixture: InvestigationReportProjectionFixture
) throws -> InvestigationReportProjection {
    let evidence = [
        try fixture.evidence(
            suffix: "review-finding", target: fixture.snapshotTarget,
            kind: .finding, advisoryID: "finding-review",
            sourceLabel: "source.probeBroker", summary: "Advisory finding"
        ),
        try fixture.evidence(
            suffix: "review-proposal", target: fixture.snapshotTarget,
            kind: .proposal, advisoryID: "candidate-review",
            sourceLabel: "source.probeBroker", summary: "Advisory proposal"
        ),
        try fixture.evidence(
            suffix: "review-unresolved", target: fixture.otherTarget,
            kind: .unresolved, advisoryID: fixture.otherTarget.id.rawValue,
            sourceLabel: "source.unresolved", summary: "Unresolved target"
        ),
    ]
    return try #require(InvestigationReportProjection.make(
        report: fixture.report(summary: "Review projection"),
        plan: fixture.plan, terminalCause: .paused,
        evidence: evidence, degradations: [], budgetEvents: []
    ).projection)
}

private extension InvestigationReportProjectionFixture {
    var snapshotTarget: InvestigationTarget {
        plan.targets.first {
            switch $0.sourceBinding {
            case .snapshot, .classification:
                return true
            case .spaceLedger:
                return false
            }
        }!
    }

    var snapshotTargetID: SnapshotID? {
        switch snapshotTarget.sourceBinding {
        case let .snapshot(id), let .classification(_, id):
            return id
        case .spaceLedger:
            return nil
        }
    }

    var snapshotTargetClassificationID: ClassificationID? {
        if case let .classification(id, _) = snapshotTarget.sourceBinding {
            return id
        }
        return nil
    }

    var otherTarget: InvestigationTarget {
        plan.targets.first { $0.id != snapshotTarget.id }!
    }
}

private func emptyReviewProjection(
    sessionID: ScanSessionID
) throws -> ReviewProjection {
    try ReviewProjection(
        sessionID: sessionID, planID: nil, rows: [], totalRowCount: 0,
        counts: ReviewProjectionCounts(
            executableReady: 0, executableReview: 0,
            noExecutionProfile: 0, persistedDispositionBlocked: 0,
            currentEvidenceBlocked: 0
        )
    )
}

private final class InvestigationReviewCallLog: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    var values: [String] { lock.withLock { storage } }
    func record(_ value: String) { lock.withLock { storage.append(value) } }
}
