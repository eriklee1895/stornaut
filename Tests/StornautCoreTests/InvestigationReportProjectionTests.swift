import Foundation
import Testing
@testable import StornautCore

@Suite("Investigation report projection")
struct InvestigationReportProjectionTests {
    @Test
    func projectionPreservesSourcesAndRedactsExecutableText_BitsUT() throws {
        let fixture = try InvestigationReportProjectionFixture()
        let report = fixture.report(summary:
            "Found /cores/private.dump and /Users/example/Library/Caches from https://docs.example.com/private?q=secret <script>hidden</script>")
        let evidence = [
            try fixture.evidence(
                suffix: "finding",
                target: fixture.plan.targets[0],
                kind: .finding,
                advisoryID: "finding-a",
                sourceLabel: "source.liveSearch.probeBroker",
                summary: "Inspect /Users/example/Library/Caches safely",
                web: PersistedWebProvenance(
                    sanitizing: "https://docs.example.com/private?q=secret",
                    transport: .publicInternet
                )
            ),
            try fixture.evidence(
                suffix: "proposal",
                target: fixture.plan.targets[0],
                kind: .proposal,
                advisoryID: "candidate-a",
                sourceLabel: "source.shell",
                summary: "Review the retained deterministic target"
            ),
            try fixture.evidence(
                suffix: "counter",
                target: fixture.plan.targets[0],
                kind: .counterEvidence,
                advisoryID: "counter-a",
                sourceLabel: "source.activity",
                summary: "A matching process is currently active"
            ),
            try fixture.evidence(
                suffix: "unresolved",
                target: fixture.plan.targets[1],
                kind: .unresolved,
                advisoryID: fixture.plan.targets[1].id.rawValue,
                sourceLabel: "source.unresolved",
                summary: "More evidence is required"
            ),
        ]

        let result = InvestigationReportProjection.make(
            report: report,
            plan: fixture.plan,
            terminalCause: .paused,
            evidence: evidence,
            degradations: [fixture.degradation()],
            budgetEvents: [fixture.budgetEvent()]
        )

        let projection = try #require(result.projection)
        #expect(result.isolatedRecordIDs.isEmpty)
        #expect(projection.summary.value == "[sensitive content redacted]")
        #expect(projection.findings[0].evidence.summary.value
            == "[sensitive content redacted]")
        #expect(projection.findings.count == 1)
        #expect(projection.proposals.count == 1)
        #expect(projection.counterEvidence.count == 1)
        #expect(projection.continuations.count == 1)
        #expect(projection.findings[0].evidence.sources == [
            .liveSearch, .probeBroker,
        ])
        #expect(projection.findings[0].evidence.webOrigin
            == "https://docs.example.com/")
        #expect(projection.coverage.totalTargets == 2)
        #expect(projection.coverage.resolvedTargets == 1)
        #expect(projection.coverage.unresolvedTargets == 1)
        #expect(projection.stopCause == .paused)
        #expect(projection.degradations.count == 1)
        #expect(projection.budget.eventCount == 1)
    }

    @Test
    func projectionTruncatesTextAndIsolatesOnlyMalformedRows_BitsUT() throws {
        let fixture = try InvestigationReportProjectionFixture()
        let valid = try fixture.evidence(
            suffix: "valid",
            target: fixture.plan.targets[0],
            kind: .finding,
            advisoryID: "finding-valid",
            sourceLabel: "source.directFile",
            summary: String(repeating: "evidence ", count: 400)
        )
        let malformedSource = try fixture.evidence(
            suffix: "bad-source",
            target: fixture.plan.targets[0],
            kind: .finding,
            advisoryID: "finding-bad",
            sourceLabel: "source.unrecognized-tool",
            summary: "Unknown source"
        )
        let foreignTarget = try fixture.evidence(
            suffix: "foreign",
            targetID: InvestigationTargetID(rawValue: "target-foreign")!,
            kind: .proposal,
            advisoryID: "candidate-foreign",
            sourceLabel: "source.probeBroker",
            summary: "Foreign target"
        )

        let result = InvestigationReportProjection.make(
            report: fixture.report(summary: "Retained report"),
            plan: fixture.plan,
            terminalCause: .paused,
            evidence: [valid, malformedSource, foreignTarget],
            degradations: [],
            budgetEvents: []
        )

        let projection = try #require(result.projection)
        #expect(projection.findings.count == 1)
        #expect(projection.findings[0].evidence.summary.wasTruncated)
        #expect(projection.findings[0].evidence.summary.value.hasSuffix("…"))
        #expect(Set(result.isolatedRecordIDs) == [
            malformedSource.id.rawValue, foreignTarget.id.rawValue,
            fixture.reportID.rawValue,
        ])
        #expect(!result.reviewEligible)
    }

    @Test
    func duplicateProposalIdentifiersAreIsolated_BitsUT() throws {
        let fixture = try InvestigationReportProjectionFixture()
        let proposals = try ["first", "second"].map { suffix in
            try fixture.evidence(
                suffix: suffix,
                target: fixture.plan.targets[0],
                kind: .proposal,
                advisoryID: "candidate-duplicate",
                sourceLabel: "source.probeBroker",
                summary: "Candidate proposal"
            )
        }

        let result = InvestigationReportProjection.make(
            report: fixture.report(summary: "Retained report"),
            plan: fixture.plan,
            terminalCause: .coverageReached,
            evidence: proposals,
            degradations: [],
            budgetEvents: []
        )

        let projection = try #require(result.projection)
        #expect(projection.proposals.isEmpty)
        #expect(Set(result.isolatedRecordIDs)
            == Set(proposals.map(\.id.rawValue) + [fixture.reportID.rawValue]))
        #expect(!result.reviewEligible)
    }

    @Test
    func webProvenanceRequiresAWebSourceAndCounterEvidenceDoesNotResolve_BitsUT() throws {
        let fixture = try InvestigationReportProjectionFixture()
        let invalid = try fixture.evidence(
            suffix: "shell-web",
            target: fixture.plan.targets[0],
            kind: .finding,
            advisoryID: "finding-shell-web",
            sourceLabel: "source.shell",
            summary: "Shell observation",
            web: PersistedWebProvenance(
                sanitizing: "https://docs.example.com/private",
                transport: .publicInternet
            )
        )
        let counter = try fixture.evidence(
            suffix: "counter-only",
            target: fixture.plan.targets[1],
            kind: .counterEvidence,
            advisoryID: "counter-only",
            sourceLabel: "source.activity",
            summary: "Counter evidence only"
        )

        let result = InvestigationReportProjection.make(
            report: fixture.report(summary: "Retained report"),
            plan: fixture.plan,
            terminalCause: .paused,
            evidence: [invalid, counter],
            degradations: [],
            budgetEvents: []
        )

        let projection = try #require(result.projection)
        #expect(Set(result.isolatedRecordIDs) == [
            invalid.id.rawValue, fixture.reportID.rawValue,
        ])
        #expect(projection.findings.isEmpty)
        #expect(projection.counterEvidence.count == 1)
        #expect(projection.coverage.resolvedTargets == 0)
        #expect(!result.reviewEligible)
    }

    @Test(arguments: [
        "mailto:private@example.com",
        "data:text/plain,SECRET",
        "x:private-secret",
        "a:/Users/alice/private",
        "a11111111111111111111111111111111:private-secret",
        "file:/Users/alice/private.txt",
        "/Users/alice/Library/Application Support/private.db",
        "~alice/Library/private.db",
        "rm -rf *",
        "find . -delete",
        "$(whoami)",
        "`whoami`",
        "<very-long-tag-" + String(repeating: "x", count: 256) + ">hidden",
    ])
    func sensitiveDisplayFormsAreFullyRedacted_BitsUT(_ text: String) throws {
        let fixture = try InvestigationReportProjectionFixture()
        let result = InvestigationReportProjection.make(
            report: fixture.report(summary: text),
            plan: fixture.plan,
            terminalCause: .paused,
            evidence: [],
            degradations: [],
            budgetEvents: []
        )

        #expect(result.projection?.summary.value
            == "[sensitive content redacted]")
    }

    @Test
    func omittedPlanTargetPreservesReportButBlocksReview_BitsUT() throws {
        let fixture = try InvestigationReportProjectionFixture()
        let finding = try fixture.evidence(
            suffix: "only-finding",
            target: fixture.plan.targets[0],
            kind: .finding,
            advisoryID: "finding-only",
            sourceLabel: "source.probeBroker",
            summary: "Only one target was resolved"
        )

        let result = InvestigationReportProjection.make(
            report: fixture.report(summary: "Incomplete retained report"),
            plan: fixture.plan,
            terminalCause: .paused,
            evidence: [finding],
            degradations: [],
            budgetEvents: []
        )

        let projection = try #require(result.projection)
        #expect(projection.coverage.totalTargets == 2)
        #expect(projection.coverage.resolvedTargets == 1)
        #expect(projection.coverage.unresolvedTargets == 0)
        #expect(result.isolatedRecordIDs == [fixture.reportID.rawValue])
        #expect(!result.reviewEligible)
    }

    @Test
    func conflictingResolvedAndUnresolvedTargetBlocksReview_BitsUT() throws {
        let fixture = try InvestigationReportProjectionFixture()
        let target = fixture.plan.targets[0]
        let finding = try fixture.evidence(
            suffix: "conflict-finding", target: target, kind: .finding,
            advisoryID: "finding-conflict",
            sourceLabel: "source.probeBroker", summary: "Resolved"
        )
        let unresolved = try fixture.evidence(
            suffix: "conflict-unresolved", target: target, kind: .unresolved,
            advisoryID: target.id.rawValue,
            sourceLabel: "source.unresolved", summary: "Unresolved"
        )
        let other = try fixture.evidence(
            suffix: "other-unresolved", target: fixture.plan.targets[1],
            kind: .unresolved, advisoryID: fixture.plan.targets[1].id.rawValue,
            sourceLabel: "source.unresolved", summary: "Unresolved"
        )

        let result = InvestigationReportProjection.make(
            report: fixture.report(summary: "Conflicting report"),
            plan: fixture.plan, terminalCause: .paused,
            evidence: [finding, unresolved, other],
            degradations: [], budgetEvents: []
        )

        #expect(result.projection != nil)
        #expect(result.isolatedRecordIDs == [fixture.reportID.rawValue])
        #expect(!result.reviewEligible)
    }

    @Test
    func duplicateUnresolvedTargetRowsAreIsolated_BitsUT() throws {
        let fixture = try InvestigationReportProjectionFixture()
        let finding = try fixture.evidence(
            suffix: "resolved-for-duplicate", target: fixture.plan.targets[0],
            kind: .finding, advisoryID: "finding-resolved",
            sourceLabel: "source.probeBroker", summary: "Resolved"
        )
        let target = fixture.plan.targets[1]
        let unresolved = try ["first", "second"].map { suffix in
            try fixture.evidence(
                suffix: "duplicate-unresolved-\(suffix)", target: target,
                kind: .unresolved, advisoryID: target.id.rawValue,
                sourceLabel: "source.unresolved", summary: "Unresolved"
            )
        }

        let result = InvestigationReportProjection.make(
            report: fixture.report(summary: "Duplicate unresolved report"),
            plan: fixture.plan, terminalCause: .paused,
            evidence: [finding] + unresolved, degradations: [], budgetEvents: []
        )

        let projection = try #require(result.projection)
        #expect(projection.continuations.isEmpty)
        #expect(Set(result.isolatedRecordIDs)
            == Set(unresolved.map(\.id.rawValue) + [fixture.reportID.rawValue]))
        #expect(!result.reviewEligible)
    }

    @Test
    func finalReportAndEverySourceLabelProjectExactly_BitsUT() throws {
        let fixture = try InvestigationReportProjectionFixture()
        let labels: [(String, [InvestigationEvidenceDisplaySource])] = [
            ("source.surveyor", [.surveyorQuickScan]),
            ("source.rule", [.ruleCatalog]),
            ("source.activity", [.currentActivity]),
            ("source.probeBroker", [.probeBroker]),
            ("source.directFile", [.directRead]),
            ("source.shell", [.shell]),
            ("source.unifiedExec", [.shell]),
            ("source.liveSearch", [.liveSearch]),
            ("source.browserOrDirectFetch", [.browserOrDirectFetch]),
            ("source.image", [.image]),
            ("source.skill", [.skill]),
            ("source.subagent", [.subagent]),
            ("source.system", [.systemRuntime]),
        ]
        let evidence = try labels.enumerated().map { index, entry in
            try fixture.evidence(
                suffix: "source-\(index)",
                target: fixture.plan.targets[0],
                kind: .counterEvidence,
                advisoryID: "counter-\(index)",
                sourceLabel: entry.0,
                summary: "Bounded evidence source"
            )
        } + [
            try fixture.evidence(
                suffix: "resolved", target: fixture.plan.targets[0],
                kind: .finding, advisoryID: "finding-final",
                sourceLabel: "source.probeBroker", summary: "Resolved"
            ),
            try fixture.evidence(
                suffix: "unresolved-final", target: fixture.plan.targets[1],
                kind: .unresolved, advisoryID: fixture.plan.targets[1].id.rawValue,
                sourceLabel: "source.unresolved", summary: "Unresolved"
            ),
        ]

        let result = InvestigationReportProjection.make(
            report: fixture.report(summary: "Final retained report", kind: .final),
            plan: fixture.plan, terminalCause: .coverageReached,
            evidence: evidence, degradations: [], budgetEvents: []
        )

        let projection = try #require(result.projection)
        #expect(projection.kind == .final)
        #expect(projection.counterEvidence.flatMap(\.sources)
            .map(\.rawValue).sorted()
            == labels.flatMap(\.1).map(\.rawValue).sorted())
        #expect(result.reviewEligible)
    }
}

struct InvestigationReportProjectionFixture {
    let plan: InvestigationPlan
    let runID = InvestigationRunID(rawValue: "investigation-run-report-view")!
    let reportID = InvestigationReportID(rawValue: "investigation-report-view")!
    let createdAt = Date(timeIntervalSince1970: 1_800_100_000)

    init() throws {
        let sessionID = ScanSessionID(rawValue: "scan-report-view")!
        let scopeID = ScanScopeID(rawValue: "scope-report-view")!
        let targets = try [
            InvestigationTarget(
                scanSessionID: sessionID,
                scanScopeID: scopeID,
                sourceBinding: .classification(
                    classificationID: ClassificationID(
                        rawValue: "classification-report-view-a"
                    )!,
                    snapshotID: SnapshotID(
                        rawValue: "snapshot-report-view-a"
                    )!
                ),
                kind: .unknownLargeConsumer,
                reasonKeys: [DomainToken(rawValue: "reason.unknown")!],
                expectedAllocatedBytes: ByteCount(4_096),
                uncertaintyPermille: 900,
                relevancePermille: 900,
                investigationCostPermille: 100,
                createdAt: createdAt
            ),
            InvestigationTarget(
                scanSessionID: sessionID,
                scanScopeID: scopeID,
                sourceBinding: .spaceLedger(.unknownResidual),
                kind: .unexplainedSpaceGap,
                reasonKeys: [DomainToken(rawValue: "reason.gap")!],
                expectedAllocatedBytes: nil,
                uncertaintyPermille: 800,
                relevancePermille: 800,
                investigationCostPermille: 200,
                createdAt: createdAt
            ),
        ]
        plan = try InvestigationPlan(
            id: InvestigationID(rawValue: "investigation-report-view")!,
            scanSessionID: sessionID,
            scanScopeID: scopeID,
            sourceFingerprint: InvestigationFingerprint(
                validating: Data(repeating: 0x41, count: 32)
            ),
            budgetPreset: .focused,
            targets: InvestigationTargetPlannerOrder.sorted(targets),
            createdAt: createdAt,
            expiresAt: createdAt.addingTimeInterval(600),
            requestedCoveragePermille:
                InvestigationPlan.policyRequestedCoveragePermille,
            remainingUnknownByteThreshold:
                InvestigationPlan.policyRemainingUnknownByteThreshold,
            requiredCapabilities: InvestigationCapability.required
        )
    }

    func report(
        summary: String,
        kind: InvestigationReportKind = .partial
    ) -> InvestigationStoredReport {
        InvestigationStoredReport(
            investigationID: plan.id,
            runID: runID,
            id: reportID,
            kind: kind,
            createdAt: createdAt,
            payload: try! InvestigationReportPayload(summary: summary)
        )
    }

    func evidence(
        suffix: String,
        target: InvestigationTarget,
        kind: InvestigationPersistedEvidenceKind,
        advisoryID: String,
        sourceLabel: String,
        summary: String,
        web: PersistedWebProvenance? = nil
    ) throws -> InvestigationStoredEvidence {
        try evidence(
            suffix: suffix,
            targetID: target.id,
            kind: kind,
            advisoryID: advisoryID,
            sourceLabel: sourceLabel,
            summary: summary,
            web: web
        )
    }

    func evidence(
        suffix: String,
        targetID: InvestigationTargetID,
        kind: InvestigationPersistedEvidenceKind,
        advisoryID: String,
        sourceLabel: String,
        summary: String,
        web: PersistedWebProvenance? = nil
    ) throws -> InvestigationStoredEvidence {
        InvestigationStoredEvidence(
            investigationID: plan.id,
            reportID: reportID,
            runID: runID,
            targetID: targetID,
            id: InvestigationEvidenceID(
                rawValue: "investigation-evidence-report-view-\(suffix)"
            )!,
            ordinal: 0,
            kind: kind,
            payload: try InvestigationEvidencePayload(
                summary: summary,
                advisoryID: DomainToken(rawValue: advisoryID),
                sourceLabel: DomainToken(rawValue: sourceLabel),
                confidence: DomainToken(rawValue: "confidence.high")!,
                uncertainty: "Bounded uncertainty",
                webProvenance: web
            )
        )
    }

    func degradation() -> InvestigationStoredDegradation {
        InvestigationStoredDegradation(
            investigationID: plan.id,
            reportID: reportID,
            runID: runID,
            id: InvestigationDegradationID(
                rawValue: "investigation-degradation-report-view"
            )!,
            ordinal: 0,
            kind: .capabilityUnavailable,
            payload: try! InvestigationDegradationPayload(
                reasonKey: DomainToken(rawValue: "capability.live-search")!,
                summary: "Live search was unavailable"
            )
        )
    }

    func budgetEvent() -> InvestigationStoredBudgetEvent {
        InvestigationStoredBudgetEvent(
            investigationID: plan.id,
            runID: runID,
            id: InvestigationBudgetEventID(
                rawValue: "investigation-budget-event-report-view"
            )!,
            ordinal: 0,
            kind: .terminalSummary,
            payload: InvestigationBudgetEventPayload(
                dimension: DomainToken(rawValue: "budget.total-tokens"),
                amount: 128,
                quality: DomainToken(rawValue: "quality.observed")
            )
        )
    }
}
