import Foundation
import Testing
@testable import StornautCore

@Test(arguments: [
    ScanTerminalState.completed,
    .partial,
    .cancelled,
])
func investigationCandidatePlannerAcceptsUsableTerminalScanStates(
    terminalState: ScanTerminalState
) throws {
    let fixture = try InvestigationPlannerFixture()
    let source = try fixture.source(terminalState: terminalState)

    #expect(
        InvestigationCandidatePlanner().evaluateEligibility(
            source: .available(source),
            planningAt: fixture.planningAt
        ) == .eligible
    )
}

@Test(arguments: [
    ScanScopeCompletionReason.interrupted,
    .cancelled,
    .permissionDenied,
    .mountBoundary,
    .userExcluded,
    .metadataChanged,
    .storeFailure,
    .scannerFailure,
])
func investigationCandidatePlannerRejectsEveryUnfinishedReason(
    reason: ScanScopeCompletionReason
) throws {
    let fixture = try InvestigationPlannerFixture()
    let source = try fixture.source(
        unfinishedScopes: [
            UnfinishedScanScope(
                id: fixture.scopeID,
                rootPath: PersistedPath(rawValue: "/fixture")!,
                reason: reason
            ),
        ]
    )

    #expect(
        InvestigationCandidatePlanner().evaluateEligibility(
            source: .available(source),
            planningAt: fixture.planningAt
        ) == .primaryScopeUnfinished(reason: reason)
    )
}

@Test
func investigationCandidatePlannerMapsClosedSourceEligibilityReasons() throws {
    let fixture = try InvestigationPlannerFixture()
    let planner = InvestigationCandidatePlanner()
    let failed = try fixture.source(terminalState: .failed)
    #expect(
        planner.evaluateEligibility(
            source: .available(failed),
            planningAt: fixture.planningAt
        ) == .terminalStateIneligible
    )

    let missingScope = try fixture.source(completedScopes: [])
    #expect(
        planner.evaluateEligibility(
            source: .available(missingScope),
            planningAt: fixture.planningAt
        ) == .primaryScopeMissingOrDuplicate
    )

    let gapSnapshot = SnapshotID(rawValue: "snapshot-gap")!
    let gap = try SpaceLedgerCoverageGap(
        snapshotID: gapSnapshot,
        relativePath: PersistedPath(rawValue: "limited")!,
        status: .permissionDenied,
        observedAt: fixture.planningAt,
        includedInUnknownResidual: true
    )
    let limited = try fixture.source(coverageGaps: [gap])
    #expect(
        planner.evaluateEligibility(
            source: .available(limited),
            planningAt: fixture.planningAt
        ) == .permissionOrBoundaryLimited(snapshotIDs: [gapSnapshot])
    )

    let expired = try fixture.source(
        expiresAt: fixture.planningAt
    )
    #expect(
        planner.evaluateEligibility(
            source: .available(expired),
            planningAt: fixture.planningAt
        ) == .sourceExpired
    )
    #expect(
        planner.evaluateEligibility(
            source: .missing,
            planningAt: fixture.planningAt
        ) == .sourceMissing
    )
    #expect(
        planner.evaluateEligibility(
            source: .corrupt,
            planningAt: fixture.planningAt
        ) == .sourceCorrupt
    )
    #expect(
        planner.evaluateEligibility(
            source: .stale,
            planningAt: fixture.planningAt
        ) == .sourceStale
    )
}

@Test
func investigationCandidatePlannerRejectsProjectionSummaryDrift() throws {
    let fixture = try InvestigationPlannerFixture()
    let source = try fixture.source()
    let summary = source.summary
    let drifted = InvestigationSourceProjection(
        summary: InvestigationSourceProjectionSummary(
            scanSessionID: summary.scanSessionID,
            primaryScopeID: summary.primaryScopeID,
            sourceRowCount: summary.sourceRowCount + 1,
            pathSnapshotCount: summary.pathSnapshotCount,
            classificationCount: summary.classificationCount,
            evidenceCount: summary.evidenceCount,
            exactPayloadBytes:
                InvestigationSourceProjectionAccounting
                    .maximumExactPayloadBytes + 1,
            completeCanonicalBytes:
                InvestigationSourceProjectionAccounting
                    .maximumCanonicalBytes + 1,
            relevanceTokens: summary.relevanceTokens,
            sourceFingerprint: summary.sourceFingerprint
        ),
        policyIndex: source.policyIndex
    )

    #expect(
        InvestigationCandidatePlanner().evaluateEligibility(
            source: .available(drifted),
            planningAt: fixture.planningAt
        ) == .sourceCorrupt
    )
}

@Test
func investigationCandidatePlannerEnforcesEvidencePerSnapshotLimit() throws {
    let fixture = try InvestigationPlannerFixture()
    let snapshot = fixture.snapshot(
        "snapshot-evidence-limit",
        bytes: nil
    )
    let evidence = (0..<101).map { index in
        fixture.evidence(
            "evidence-limit-\(index)",
            snapshotID: snapshot.id,
            freshness: .current
        )
    }
    let accepted = try fixture.source(
        snapshots: [snapshot],
        evidence: evidence.prefix(100)
    )
    let rejected = try fixture.source(
        snapshots: [snapshot],
        evidence: evidence
    )
    let planner = InvestigationCandidatePlanner()

    #expect(
        planner.evaluateEligibility(
            source: .available(accepted),
            planningAt: fixture.planningAt
        ) == .eligible
    )
    #expect(
        planner.evaluateEligibility(
            source: .available(rejected),
            planningAt: fixture.planningAt
        ) == .sourceCorrupt
    )
}

@Test
func investigationCandidatePlannerRejectsParentSessionAndScopeMismatch()
    throws
{
    let fixture = try InvestigationPlannerFixture()
    let snapshot = fixture.snapshot(
        "snapshot-membership",
        bytes: 1_073_741_824
    )
    let classification = fixture.classification(
        "classification-membership",
        snapshotID: snapshot.id,
        ruleID: nil,
        producer: nil,
        category: .unknownLargeConsumers,
        disposition: .unknown,
        risk: .medium,
        confidence: .high
    )
    let evidence = fixture.evidence(
        "evidence-membership",
        snapshotID: snapshot.id,
        freshness: .current
    )
    let source = try fixture.source(
        snapshots: [snapshot],
        classifications: [classification],
        evidence: [evidence]
    )
    let otherSessionID = ScanSessionID(rawValue: "scan-other")!
    let otherScopeID = ScanScopeID(rawValue: "scope-other")!
    let orphanSnapshotID = SnapshotID(rawValue: "snapshot-orphan")!
    let mismatchedSession = replacingProjection(
        source,
        session: InvestigationSourceSessionIndex(
            id: otherSessionID,
            terminalState: source.policyIndex.session.terminalState,
            completedScopes: source.policyIndex.session.completedScopes,
            unfinishedScopes: source.policyIndex.session.unfinishedScopes,
            expiresAt: source.policyIndex.session.expiresAt
        )
    )
    let mismatchedLedgerSession = replacingProjection(
        source,
        ledger: InvestigationSourceLedgerIndex(
            sessionID: otherSessionID,
            status: source.policyIndex.ledger.status,
            unknown: source.policyIndex.ledger.unknown,
            unmeasurable: source.policyIndex.ledger.unmeasurable,
            coverageGaps: source.policyIndex.ledger.coverageGaps,
            unknownIncludesUnmeasurable:
                source.policyIndex.ledger.unknownIncludesUnmeasurable
        )
    )
    let mismatchedScopeSnapshot = InvestigationSourceSnapshotIndex(
        id: snapshot.id,
        scopeID: otherScopeID,
        expectedAllocatedBytes: snapshot.expectedAllocatedBytes,
        measurementStatus: snapshot.measurementStatus,
        observedAt: snapshot.observedAt,
        isRoot: snapshot.isRoot
    )
    let mismatchedScope = replacingProjection(
        source,
        snapshots: [snapshot.id: mismatchedScopeSnapshot]
    )
    let orphanClassification = InvestigationSourceClassificationIndex(
        id: classification.id,
        snapshotID: orphanSnapshotID,
        ruleID: classification.ruleID,
        producer: classification.producer,
        category: classification.category,
        disposition: classification.disposition,
        risk: classification.risk,
        confidence: classification.confidence,
        requiredEvidenceKeys: classification.requiredEvidenceKeys,
        missingEvidenceKeys: classification.missingEvidenceKeys,
        classifiedAt: classification.classifiedAt
    )
    let classificationParentMismatch = replacingProjection(
        source,
        classifications: [classification.id: orphanClassification]
    )
    let orphanEvidence = InvestigationSourceEvidenceIndex(
        id: evidence.id,
        snapshotID: orphanSnapshotID,
        kind: evidence.kind,
        freshness: evidence.freshness,
        observedAt: evidence.observedAt
    )
    let evidenceParentMismatch = replacingProjection(
        source,
        evidence: [evidence.id: orphanEvidence]
    )
    let planner = InvestigationCandidatePlanner()

    for invalid in [
        mismatchedSession,
        mismatchedLedgerSession,
        mismatchedScope,
        classificationParentMismatch,
        evidenceParentMismatch,
    ] {
        #expect(
            planner.evaluateEligibility(
                source: .available(invalid),
                planningAt: fixture.planningAt
            ) == .sourceCorrupt
        )
    }
}

@Test
func investigationCandidatePlannerPreservesUnknownLedgerMeasurementSemantics()
    throws
{
    let fixture = try InvestigationPlannerFixture()
    let source = try fixture.source(
        unknownBytes: ByteCount(0)!
    )
    let accountingSource = source.policyIndex.ledger.unknown.sources
    let unavailableUnknown = try SpaceLedgerMeasure(
        status: .unknown,
        bytes: nil,
        sources: accountingSource,
        formulaKey: DomainToken(rawValue: "accounting.unknown")!,
        explanationKey: DomainToken(rawValue: "accounting.unknown")!
    )
    let unavailableSource = replacingProjection(
        source,
        ledger: InvestigationSourceLedgerIndex(
            sessionID: source.policyIndex.ledger.sessionID,
            status: source.policyIndex.ledger.status,
            unknown: unavailableUnknown,
            unmeasurable: source.policyIndex.ledger.unmeasurable,
            coverageGaps: source.policyIndex.ledger.coverageGaps,
            unknownIncludesUnmeasurable: false
        )
    )
    let unavailableUnmeasurable = try SpaceLedgerMeasure(
        status: .unmeasurable,
        bytes: nil,
        sources: accountingSource,
        formulaKey: DomainToken(rawValue: "accounting.unmeasurable")!,
        explanationKey: DomainToken(rawValue: "accounting.unmeasurable")!
    )
    let corruptUnmeasurableSource = replacingProjection(
        source,
        ledger: InvestigationSourceLedgerIndex(
            sessionID: source.policyIndex.ledger.sessionID,
            status: source.policyIndex.ledger.status,
            unknown: source.policyIndex.ledger.unknown,
            unmeasurable: unavailableUnmeasurable,
            coverageGaps: source.policyIndex.ledger.coverageGaps,
            unknownIncludesUnmeasurable: false
        )
    )
    let planner = InvestigationCandidatePlanner()

    let measuredZero = try planner.plan(
        investigationID: InvestigationID(
            rawValue: "investigation-ledger-zero"
        )!,
        source: source,
        budgetPreset: .focused,
        planningAt: fixture.planningAt
    )
    let unavailable = try planner.plan(
        investigationID: InvestigationID(
            rawValue: "investigation-ledger-unavailable"
        )!,
        source: unavailableSource,
        budgetPreset: .focused,
        planningAt: fixture.planningAt
    )

    #expect(measuredZero.plan.targets.isEmpty)
    #expect(unavailable.plan.targets.isEmpty)
    #expect(
        !measuredZero.plan.targets.contains {
            if case .spaceLedger = $0.sourceBinding {
                return true
            }
            return false
        }
    )
    #expect(
        !unavailable.plan.targets.contains {
            if case .spaceLedger = $0.sourceBinding {
                return true
            }
            return false
        }
    )
    #expect(
        planner.evaluateEligibility(
            source: .available(corruptUnmeasurableSource),
            planningAt: fixture.planningAt
        ) == .sourceCorrupt
    )
}

@Test
func investigationCandidatePlannerRejectsInvalidRelevanceAndReasonOverflow()
    throws
{
    let fixture = try InvestigationPlannerFixture()
    let snapshot = fixture.snapshot(
        "snapshot-reason-overflow",
        bytes: 1_073_741_824
    )
    let sixteenReasons = (0..<16).map {
        DomainToken(rawValue: "evidence.required-\($0)")!
    }
    let classification = fixture.classification(
        "classification-reason-overflow",
        snapshotID: snapshot.id,
        ruleID: nil,
        producer: nil,
        category: .unknownLargeConsumers,
        disposition: .unknown,
        risk: .medium,
        confidence: .high,
        requiredEvidenceKeys: sixteenReasons,
        missingEvidenceKeys: sixteenReasons
    )
    let overflowing = try fixture.source(
        snapshots: [snapshot],
        classifications: [classification]
    )
    #expect(
        throws: InvestigationPlanningError.candidateReasonLimitExceeded
    ) {
        _ = try InvestigationCandidatePlanner().plan(
            investigationID: InvestigationID(
                rawValue: "investigation-reason-overflow"
            )!,
            source: overflowing,
            budgetPreset: .focused,
            planningAt: fixture.planningAt
        )
    }

    for relevanceTokens in [
        [DomainToken(rawValue: "relevance.unknown")!],
        [
            DomainToken(rawValue: "relevance.large")!,
            DomainToken(rawValue: "relevance.large")!,
        ],
    ] {
        let invalid = try fixture.source(
            relevanceTokens: relevanceTokens
        )
        #expect(throws: InvestigationPlanningError.invalidRelevanceToken) {
            _ = try InvestigationCandidatePlanner().plan(
                investigationID: InvestigationID(
                    rawValue: "investigation-invalid-relevance"
                )!,
                source: invalid,
                budgetPreset: .focused,
                planningAt: fixture.planningAt
            )
        }
    }
}

@Test
func investigationCandidatePlannerBuildsClosedCandidateKindsAndReasons()
    throws
{
    let fixture = try InvestigationPlannerFixture()
    let unknownLarge = fixture.snapshot(
        "snapshot-unknown-large",
        bytes: 2 * 1_073_741_824
    )
    let conflict = fixture.snapshot(
        "snapshot-conflict",
        bytes: 512 * 1_048_576
    )
    let unknownProducer = fixture.snapshot(
        "snapshot-unknown-producer",
        bytes: 256 * 1_048_576
    )
    let stale = fixture.snapshot(
        "snapshot-stale",
        bytes: 128 * 1_048_576
    )
    let missingClassification = fixture.snapshot(
        "snapshot-missing-classification",
        bytes: 1_073_741_824
    )
    let rootWithoutClassification = fixture.snapshot(
        "snapshot-root-without-classification",
        bytes: 4 * 1_073_741_824,
        isRoot: true
    )
    let ordinaryReady = fixture.snapshot(
        "snapshot-ordinary-ready",
        bytes: 2 * 1_073_741_824
    )
    let protected = fixture.snapshot(
        "snapshot-protected",
        bytes: 2 * 1_073_741_824
    )

    let classifications = [
        fixture.classification(
            "classification-unknown-large",
            snapshotID: unknownLarge.id,
            ruleID: nil,
            producer: nil,
            category: .packageAndBuildCaches,
            disposition: .unknown,
            risk: .medium,
            confidence: .high
        ),
        fixture.classification(
            "classification-conflict",
            snapshotID: conflict.id,
            ruleID: DomainToken(rawValue: "rule.conflict")!,
            producer: DomainLabel(rawValue: "Conflict Tool")!,
            category: .rebuildableProjectArtifacts,
            disposition: .readyToReclaim,
            risk: .high,
            confidence: .high
        ),
        fixture.classification(
            "classification-unknown-producer",
            snapshotID: unknownProducer.id,
            ruleID: nil,
            producer: nil,
            category: .updatesAndTemporaryFiles,
            disposition: .reviewRecommended,
            risk: .medium,
            confidence: .high
        ),
        fixture.classification(
            "classification-stale",
            snapshotID: stale.id,
            ruleID: DomainToken(rawValue: "rule.stale")!,
            producer: DomainLabel(rawValue: "Stale Tool")!,
            category: .largeRepositoriesAndHistory,
            disposition: .reviewRecommended,
            risk: .medium,
            confidence: .high,
            requiredEvidenceKeys: [
                DomainToken(rawValue: "evidence.activity")!,
            ],
            missingEvidenceKeys: [
                DomainToken(rawValue: "evidence.activity")!,
            ]
        ),
        fixture.classification(
            "classification-ordinary-ready",
            snapshotID: ordinaryReady.id,
            ruleID: DomainToken(rawValue: "rule.ready")!,
            producer: DomainLabel(rawValue: "Ready Tool")!,
            category: .packageAndBuildCaches,
            disposition: .readyToReclaim,
            risk: .low,
            confidence: .high
        ),
        fixture.classification(
            "classification-protected",
            snapshotID: protected.id,
            ruleID: DomainToken(rawValue: "rule.protected")!,
            producer: DomainLabel(rawValue: "Protected Tool")!,
            category: .protected,
            disposition: .protected,
            risk: .critical,
            confidence: .high
        ),
    ]
    let evidence = [
        fixture.evidence(
            "evidence-stale",
            snapshotID: stale.id,
            freshness: .stale
        ),
        fixture.evidence(
            "evidence-expired",
            snapshotID: stale.id,
            freshness: .expired
        ),
    ]
    let source = try fixture.source(
        relevanceTokens: [
            DomainToken(rawValue: "relevance.large")!,
            DomainToken(rawValue: "relevance.developer")!,
        ],
        snapshots: [
            unknownLarge,
            conflict,
            unknownProducer,
            stale,
            missingClassification,
            rootWithoutClassification,
            ordinaryReady,
            protected,
        ],
        classifications: classifications,
        evidence: evidence,
        unknownBytes: ByteCount(3 * 1_073_741_824)!
    )

    let result = try InvestigationCandidatePlanner().plan(
        investigationID: InvestigationID(
            rawValue: "investigation-planner-kinds"
        )!,
        source: source,
        budgetPreset: .focused,
        planningAt: fixture.planningAt
    )

    #expect(result.eligibility == .eligible)
    #expect(result.diagnostics.outcome == .planned)
    #expect(result.diagnostics.consideredCount == 6)
    #expect(result.diagnostics.admittedCount == 6)
    #expect(result.diagnostics.omittedCount == 0)
    #expect(Set(result.plan.targets.map(\.kind)) == Set([
        .unknownLargeConsumer,
        .classificationConflict,
        .unknownProducer,
        .staleOrInsufficientEvidence,
        .unexplainedSpaceGap,
    ]))
    #expect(
        result.plan.targets.contains {
            $0.sourceBinding
                == .spaceLedger(.unknownResidual)
                && $0.kind == .unexplainedSpaceGap
        }
    )
    #expect(
        !result.plan.targets.contains {
            $0.sourceBinding == .snapshot(rootWithoutClassification.id)
        }
    )
    #expect(
        !result.plan.targets.contains {
            $0.sourceBinding == .classification(
                classificationID: classifications[4].id,
                snapshotID: ordinaryReady.id
            )
        }
    )
    #expect(
        !result.plan.targets.contains {
            $0.sourceBinding == .classification(
                classificationID: classifications[5].id,
                snapshotID: protected.id
            )
        }
    )

    let largeTarget = try #require(
        result.plan.targets.first {
            $0.kind == .unknownLargeConsumer
        }
    )
    #expect(largeTarget.relevancePermille == 900)
    #expect(largeTarget.reasonKeys.map(\.rawValue).contains("reason.rule-miss"))
    #expect(
        largeTarget.reasonKeys.map(\.rawValue)
            .contains("reason.unknown-producer")
    )

    let staleTarget = try #require(
        result.plan.targets.first {
            $0.sourceBinding == .classification(
                classificationID: classifications[3].id,
                snapshotID: stale.id
            )
        }
    )
    #expect(staleTarget.kind == .staleOrInsufficientEvidence)
    #expect(Set(staleTarget.reasonKeys.map(\.rawValue)).isSuperset(of: [
        "evidence.activity",
        "reason.evidence-expired",
        "reason.evidence-stale",
        "reason.required-evidence-missing",
    ]))
    #expect(
        result.plan.expiresAt
            == fixture.planningAt.addingTimeInterval(600)
    )
    #expect(result.plan.requestedCoveragePermille == 900)
    #expect(
        result.plan.remainingUnknownByteThreshold
            == ByteCount(1_073_741_824)
    )
}

@Test
func investigationCandidatePlannerIsDeterministicAcrossInputOrder() throws {
    let fixture = try InvestigationPlannerFixture()
    let snapshots = (0..<32).map { index in
        fixture.snapshot(
            "snapshot-deterministic-\(index)",
            bytes: UInt64(index + 1) * 1_073_741_824
        )
    }
    let classifications = snapshots.enumerated().map { index, snapshot in
        fixture.classification(
            "classification-deterministic-\(index)",
            snapshotID: snapshot.id,
            ruleID: nil,
            producer: nil,
            category: .unknownLargeConsumers,
            disposition: .unknown,
            risk: .medium,
            confidence: .high
        )
    }
    let firstSource = try fixture.source(
        snapshots: snapshots,
        classifications: classifications,
        unknownBytes: ByteCount(0)!
    )
    let secondSource = try fixture.source(
        snapshots: snapshots.reversed(),
        classifications: classifications.reversed(),
        unknownBytes: ByteCount(0)!
    )
    let planner = InvestigationCandidatePlanner()
    let investigationID = InvestigationID(
        rawValue: "investigation-deterministic"
    )!

    let first = try planner.plan(
        investigationID: investigationID,
        source: firstSource,
        budgetPreset: .balanced,
        planningAt: fixture.planningAt
    )
    let second = try planner.plan(
        investigationID: investigationID,
        source: secondSource,
        budgetPreset: .balanced,
        planningAt: fixture.planningAt
    )

    #expect(first.plan.targets.map(\.id) == second.plan.targets.map(\.id))
    #expect(first.plan.fingerprint == second.plan.fingerprint)
    #expect(
        first.plan.targets.dropFirst().enumerated().allSatisfy {
            index, target in
            let previous = first.plan.targets[index]
            if previous.priority.tier != target.priority.tier {
                return previous.priority.tier == .measured
            }
            return previous.priority.score >= target.priority.score
        }
    )
}

@Test
func investigationCandidatePlannerCapsAt512WithTruthfulOmissions() throws {
    let fixture = try InvestigationPlannerFixture()
    let snapshots = (0..<513).map { index in
        fixture.snapshot(
            "snapshot-cap-\(index)",
            bytes: UInt64(index + 1) * 1_073_741_824
        )
    }
    let classifications = snapshots.enumerated().map { index, snapshot in
        fixture.classification(
            "classification-cap-\(index)",
            snapshotID: snapshot.id,
            ruleID: nil,
            producer: nil,
            category: .unknownLargeConsumers,
            disposition: .unknown,
            risk: .medium,
            confidence: .high
        )
    }
    let source = try fixture.source(
        snapshots: snapshots,
        classifications: classifications,
        unknownBytes: ByteCount(0)!
    )

    let result = try InvestigationCandidatePlanner().plan(
        investigationID: InvestigationID(rawValue: "investigation-cap")!,
        source: source,
        budgetPreset: .thorough,
        planningAt: fixture.planningAt
    )

    #expect(result.plan.targets.count == 512)
    #expect(result.diagnostics.consideredCount == 513)
    #expect(result.diagnostics.admittedCount == 512)
    #expect(result.diagnostics.omittedCount == 1)
    #expect(result.diagnostics.measurableOmittedBytes == 1_073_741_824)
}

@Test
func investigationCandidatePlannerReturnsAClosedEmptyPlan() throws {
    let fixture = try InvestigationPlannerFixture()
    let root = fixture.snapshot(
        "snapshot-empty-root",
        bytes: 4 * 1_073_741_824,
        isRoot: true
    )
    let source = try fixture.source(
        snapshots: [root],
        unknownBytes: ByteCount(0)!
    )

    let result = try InvestigationCandidatePlanner().plan(
        investigationID: InvestigationID(rawValue: "investigation-empty")!,
        source: source,
        budgetPreset: .focused,
        planningAt: fixture.planningAt
    )

    #expect(result.plan.targets.isEmpty)
    #expect(result.diagnostics.outcome == .noEligibleTargets)
    #expect(result.diagnostics.consideredCount == 0)
    #expect(result.plan.requiredCapabilities == InvestigationCapability.required)
}

private func replacingProjection(
    _ source: InvestigationSourceProjection,
    session: InvestigationSourceSessionIndex? = nil,
    ledger: InvestigationSourceLedgerIndex? = nil,
    snapshots: [SnapshotID: InvestigationSourceSnapshotIndex]? = nil,
    classifications:
        [ClassificationID: InvestigationSourceClassificationIndex]? = nil,
    evidence: [EvidenceID: InvestigationSourceEvidenceIndex]? = nil
) -> InvestigationSourceProjection {
    InvestigationSourceProjection(
        summary: source.summary,
        policyIndex: InvestigationSourcePolicyIndex(
            session: session ?? source.policyIndex.session,
            ledger: ledger ?? source.policyIndex.ledger,
            snapshots: snapshots ?? source.policyIndex.snapshots,
            classifications:
                classifications ?? source.policyIndex.classifications,
            evidence: evidence ?? source.policyIndex.evidence
        )
    )
}

private struct InvestigationPlannerFixture {
    let sessionID = ScanSessionID(rawValue: "scan-planner")!
    let scopeID = ScanScopeID(rawValue: "scope-planner")!
    let planningAt = Date(timeIntervalSince1970: 1_800_000_000)
    let expiresAt = Date(timeIntervalSince1970: 1_800_604_800)
    let fingerprint: InvestigationFingerprint

    init() throws {
        fingerprint = try InvestigationFingerprint(
            validating: Data(repeating: 7, count: 32)
        )
    }

    func source(
        terminalState: ScanTerminalState = .completed,
        completedScopes: [ScanScope]? = nil,
        unfinishedScopes: [UnfinishedScanScope] = [],
        expiresAt: Date? = nil,
        coverageGaps: [SpaceLedgerCoverageGap] = [],
        relevanceTokens: [DomainToken] = [],
        snapshots: some Sequence<InvestigationSourceSnapshotIndex> = [],
        classifications:
            some Sequence<InvestigationSourceClassificationIndex> = [],
        evidence: some Sequence<InvestigationSourceEvidenceIndex> = [],
        unknownBytes: ByteCount = ByteCount(0)!
    ) throws -> InvestigationSourceProjection {
        let snapshots = Dictionary(
            uniqueKeysWithValues: snapshots.map { ($0.id, $0) }
        )
        let classifications = Dictionary(
            uniqueKeysWithValues: classifications.map { ($0.id, $0) }
        )
        let evidence = Dictionary(
            uniqueKeysWithValues: evidence.map { ($0.id, $0) }
        )
        let source = accountingSource()
        let unknown = try SpaceLedgerMeasure(
            status: .measured,
            bytes: unknownBytes,
            sources: [source],
            formulaKey: DomainToken(rawValue: "accounting.unknown")!,
            explanationKey: DomainToken(rawValue: "accounting.unknown")!
        )
        let unmeasurable = try SpaceLedgerMeasure(
            status: .measured,
            bytes: ByteCount(0),
            sources: [source],
            formulaKey: DomainToken(rawValue: "accounting.unmeasurable")!,
            explanationKey: DomainToken(rawValue: "accounting.unmeasurable")!
        )
        let session = InvestigationSourceSessionIndex(
            id: sessionID,
            terminalState: terminalState,
            completedScopes: completedScopes ?? [
                ScanScope(
                    id: scopeID,
                    rootPath: PersistedPath(rawValue: "/fixture")!,
                    completedAt: planningAt.addingTimeInterval(-1)
                ),
            ],
            unfinishedScopes: unfinishedScopes,
            expiresAt: expiresAt ?? self.expiresAt
        )
        let ledger = InvestigationSourceLedgerIndex(
            sessionID: sessionID,
            status: .reconciled,
            unknown: unknown,
            unmeasurable: unmeasurable,
            coverageGaps: coverageGaps,
            unknownIncludesUnmeasurable: false
        )
        return InvestigationSourceProjection(
            summary: InvestigationSourceProjectionSummary(
                scanSessionID: sessionID,
                primaryScopeID: scopeID,
                sourceRowCount: UInt64(
                    2 + snapshots.count
                        + classifications.count
                        + evidence.count
                ),
                pathSnapshotCount: UInt64(snapshots.count),
                classificationCount: UInt64(classifications.count),
                evidenceCount: UInt64(evidence.count),
                exactPayloadBytes: 0,
                completeCanonicalBytes: 0,
                relevanceTokens: relevanceTokens,
                sourceFingerprint: fingerprint
            ),
            policyIndex: InvestigationSourcePolicyIndex(
                session: session,
                ledger: ledger,
                snapshots: snapshots,
                classifications: classifications,
                evidence: evidence
            )
        )
    }

    func snapshot(
        _ rawID: String,
        bytes: UInt64?,
        isRoot: Bool = false
    ) -> InvestigationSourceSnapshotIndex {
        InvestigationSourceSnapshotIndex(
            id: SnapshotID(rawValue: rawID)!,
            scopeID: scopeID,
            expectedAllocatedBytes: bytes.flatMap(ByteCount.init),
            measurementStatus: bytes == nil ? .metadataUnavailable : .measured,
            observedAt: planningAt.addingTimeInterval(-1),
            isRoot: isRoot
        )
    }

    func classification(
        _ rawID: String,
        snapshotID: SnapshotID,
        ruleID: DomainToken?,
        producer: DomainLabel?,
        category: ArtifactCategory,
        disposition: ReclaimDisposition,
        risk: RiskLevel,
        confidence: EvidenceConfidence,
        requiredEvidenceKeys: [DomainToken] = [],
        missingEvidenceKeys: [DomainToken] = []
    ) -> InvestigationSourceClassificationIndex {
        InvestigationSourceClassificationIndex(
            id: ClassificationID(rawValue: rawID)!,
            snapshotID: snapshotID,
            ruleID: ruleID,
            producer: producer,
            category: category,
            disposition: disposition,
            risk: risk,
            confidence: confidence,
            requiredEvidenceKeys: requiredEvidenceKeys,
            missingEvidenceKeys: missingEvidenceKeys,
            classifiedAt: planningAt.addingTimeInterval(-1)
        )
    }

    func evidence(
        _ rawID: String,
        snapshotID: SnapshotID,
        freshness: EvidenceFreshness
    ) -> InvestigationSourceEvidenceIndex {
        InvestigationSourceEvidenceIndex(
            id: EvidenceID(rawValue: rawID)!,
            snapshotID: snapshotID,
            kind: .activity,
            freshness: freshness,
            observedAt: planningAt.addingTimeInterval(-1)
        )
    }

    private func accountingSource() -> AccountingSource {
        AccountingSource(
            kind: .volumeResourceValues,
            identifier: DomainToken(rawValue: "planner.fixture")!,
            sampledAt: planningAt.addingTimeInterval(-1)
        )
    }
}
