import Foundation

public enum InvestigationSourceAvailability: Sendable, Equatable {
    case available(InvestigationSourceProjection)
    case missing
    case corrupt
    case stale
}

public enum InvestigationSourceEligibilityV1: Sendable, Equatable {
    case eligible
    case terminalStateIneligible
    case primaryScopeMissingOrDuplicate
    case primaryScopeUnfinished(reason: ScanScopeCompletionReason)
    case permissionOrBoundaryLimited(snapshotIDs: [SnapshotID])
    case sourceExpired
    case sourceMissing
    case sourceCorrupt
    case sourceStale
}

public enum InvestigationPlanningError: Error, Sendable, Equatable {
    case sourceIneligible(InvestigationSourceEligibilityV1)
    case invalidRelevanceToken
    case candidateReasonMissing
    case candidateReasonLimitExceeded
    case duplicateCandidate
    case integerOverflow
}

public enum InvestigationPlanningOutcome: Sendable, Equatable {
    case planned
    case noEligibleTargets
}

public struct InvestigationPlanningDiagnostics: Sendable, Equatable {
    public let outcome: InvestigationPlanningOutcome
    public let consideredCount: UInt64
    public let admittedCount: UInt64
    public let omittedCount: UInt64
    public let measurableAdmittedBytes: UInt64
    public let measurableOmittedBytes: UInt64
    public let targetKindCounts: [InvestigationTargetKind: UInt64]

    public init(
        outcome: InvestigationPlanningOutcome,
        consideredCount: UInt64,
        admittedCount: UInt64,
        omittedCount: UInt64,
        measurableAdmittedBytes: UInt64,
        measurableOmittedBytes: UInt64,
        targetKindCounts: [InvestigationTargetKind: UInt64]
    ) {
        self.outcome = outcome
        self.consideredCount = consideredCount
        self.admittedCount = admittedCount
        self.omittedCount = omittedCount
        self.measurableAdmittedBytes = measurableAdmittedBytes
        self.measurableOmittedBytes = measurableOmittedBytes
        self.targetKindCounts = targetKindCounts
    }
}

public struct InvestigationPlanningResult: Sendable, Equatable {
    public let eligibility: InvestigationSourceEligibilityV1
    public let plan: InvestigationPlan
    public let diagnostics: InvestigationPlanningDiagnostics

    public init(
        eligibility: InvestigationSourceEligibilityV1,
        plan: InvestigationPlan,
        diagnostics: InvestigationPlanningDiagnostics
    ) {
        self.eligibility = eligibility
        self.plan = plan
        self.diagnostics = diagnostics
    }
}

public struct InvestigationCandidatePlanner: Sendable {
    public static let largeMeasuredAllocationThreshold =
        ByteCount(1_073_741_824)!
    public static let requestedCoveragePermille: UInt64 = 900
    public static let remainingUnknownByteThreshold =
        ByteCount(1_073_741_824)!

    public init() {}

    public func evaluateEligibility(
        source: InvestigationSourceAvailability,
        planningAt: Date
    ) -> InvestigationSourceEligibilityV1 {
        switch source {
        case .missing:
            return .sourceMissing
        case .corrupt:
            return .sourceCorrupt
        case .stale:
            return .sourceStale
        case let .available(projection):
            return evaluateAvailableSource(
                projection,
                planningAt: planningAt
            )
        }
    }

    public func plan(
        investigationID: InvestigationID,
        source: InvestigationSourceProjection,
        budgetPreset: InvestigationBudgetPreset,
        planningAt: Date
    ) throws -> InvestigationPlanningResult {
        let eligibility = evaluateEligibility(
            source: .available(source),
            planningAt: planningAt
        )
        guard eligibility == .eligible else {
            throw InvestigationPlanningError.sourceIneligible(eligibility)
        }

        let relevanceTokens = try validatedRelevanceTokens(
            source.summary.relevanceTokens
        )
        var candidates = try classificationCandidates(
            source: source,
            relevanceTokens: relevanceTokens,
            planningAt: planningAt
        )
        try candidates.append(contentsOf: missingClassificationCandidates(
            source: source,
            relevanceTokens: relevanceTokens,
            planningAt: planningAt
        ))
        if let ledgerCandidate = try ledgerCandidate(
            source: source,
            relevanceTokens: relevanceTokens,
            planningAt: planningAt
        ) {
            candidates.append(ledgerCandidate)
        }

        try validateCandidateUniqueness(candidates)
        candidates = try InvestigationTargetPlannerOrder.sorted(candidates)

        let admitted = Array(
            candidates.prefix(InvestigationPlan.maximumTargetCount)
        )
        let omitted = candidates.dropFirst(admitted.count)
        let limits = InvestigationBudgetLimits.forPreset(budgetPreset)
        let wallClockSeconds = limits.wallClockNanoseconds / 1_000_000_000
        let budgetExpiry = planningAt.addingTimeInterval(
            TimeInterval(wallClockSeconds)
        )
        let expiresAt = min(
            source.policyIndex.session.expiresAt,
            budgetExpiry
        )
        let plan = try InvestigationPlan(
            id: investigationID,
            scanSessionID: source.summary.scanSessionID,
            scanScopeID: source.summary.primaryScopeID,
            sourceFingerprint: source.summary.sourceFingerprint,
            budgetPreset: budgetPreset,
            targets: admitted,
            createdAt: planningAt,
            expiresAt: expiresAt,
            requestedCoveragePermille: Self.requestedCoveragePermille,
            remainingUnknownByteThreshold:
                Self.remainingUnknownByteThreshold,
            requiredCapabilities: InvestigationCapability.required
        )

        let admittedBytes = try measurableByteTotal(admitted)
        let omittedBytes = try measurableByteTotal(omitted)
        var kindCounts: [InvestigationTargetKind: UInt64] = [:]
        for candidate in candidates {
            let count = kindCounts[candidate.kind, default: 0]
                .addingReportingOverflow(1)
            guard !count.overflow else {
                throw InvestigationPlanningError.integerOverflow
            }
            kindCounts[candidate.kind] = count.partialValue
        }

        return InvestigationPlanningResult(
            eligibility: eligibility,
            plan: plan,
            diagnostics: InvestigationPlanningDiagnostics(
                outcome: admitted.isEmpty ? .noEligibleTargets : .planned,
                consideredCount: UInt64(candidates.count),
                admittedCount: UInt64(admitted.count),
                omittedCount: UInt64(omitted.count),
                measurableAdmittedBytes: admittedBytes,
                measurableOmittedBytes: omittedBytes,
                targetKindCounts: kindCounts
            )
        )
    }

    private func evaluateAvailableSource(
        _ source: InvestigationSourceProjection,
        planningAt: Date
    ) -> InvestigationSourceEligibilityV1 {
        let summary = source.summary
        let index = source.policyIndex
        let pathSnapshotCount = UInt64(index.snapshots.count)
        let classificationCount = UInt64(index.classifications.count)
        let evidenceCount = UInt64(index.evidence.count)
        let expectedSourceRowCount = 2
            + pathSnapshotCount
            + classificationCount
            + evidenceCount
        var evidenceCountsBySnapshot: [SnapshotID: UInt64] = [:]
        for evidence in index.evidence.values {
            let current = evidenceCountsBySnapshot[
                evidence.snapshotID,
                default: 0
            ]
            let addition = current.addingReportingOverflow(1)
            guard !addition.overflow,
                  addition.partialValue
                    <= InvestigationSourceProjectionAccounting
                        .maximumEvidencePerSnapshot
            else {
                return .sourceCorrupt
            }
            evidenceCountsBySnapshot[evidence.snapshotID] =
                addition.partialValue
        }
        guard summary.scanSessionID == index.session.id,
              summary.scanSessionID == index.ledger.sessionID,
              pathSnapshotCount
                <= InvestigationSourceProjectionAccounting
                    .maximumPathSnapshots,
              classificationCount
                <= InvestigationSourceProjectionAccounting
                    .maximumClassifications,
              evidenceCount
                <= InvestigationSourceProjectionAccounting.maximumEvidence,
              expectedSourceRowCount
                <= InvestigationSourceProjectionAccounting.maximumSourceRows,
              summary.sourceRowCount == expectedSourceRowCount,
              summary.pathSnapshotCount == pathSnapshotCount,
              summary.classificationCount == classificationCount,
              summary.evidenceCount == evidenceCount,
              summary.exactPayloadBytes
                <= InvestigationSourceProjectionAccounting
                    .maximumExactPayloadBytes,
              summary.completeCanonicalBytes
                <= InvestigationSourceProjectionAccounting
                    .maximumCanonicalBytes,
              summary.relevanceTokens.count <= 256,
              index.snapshots.allSatisfy({
                  $0.key == $0.value.id
                      && $0.value.scopeID == summary.primaryScopeID
                      && (($0.value.measurementStatus == .measured)
                          == ($0.value.expectedAllocatedBytes != nil))
              }),
              index.classifications.allSatisfy({
                  $0.key == $0.value.id
                      && index.snapshots[$0.value.snapshotID] != nil
                      && Set($0.value.requiredEvidenceKeys).count
                          == $0.value.requiredEvidenceKeys.count
                      && Set($0.value.missingEvidenceKeys).count
                          == $0.value.missingEvidenceKeys.count
                      && Set($0.value.missingEvidenceKeys).isSubset(
                          of: Set($0.value.requiredEvidenceKeys)
                      )
              }),
              index.evidence.allSatisfy({
                  $0.key == $0.value.id
                      && index.snapshots[$0.value.snapshotID] != nil
              })
        else {
            return .sourceCorrupt
        }

        guard index.session.terminalState != .failed else {
            return .terminalStateIneligible
        }

        let matchingCompleted = index.session.completedScopes.filter {
            $0.id == summary.primaryScopeID
        }
        guard matchingCompleted.count == 1 else {
            return .primaryScopeMissingOrDuplicate
        }

        if let unfinished = index.session.unfinishedScopes.sorted(
            by: unfinishedScopePrecedes
        ).first {
            return .primaryScopeUnfinished(reason: unfinished.reason)
        }

        if !index.ledger.coverageGaps.isEmpty {
            let snapshotIDs = Array(
                Set(index.ledger.coverageGaps.map(\.snapshotID))
            ).sorted { $0.rawValue < $1.rawValue }
            return .permissionOrBoundaryLimited(snapshotIDs: snapshotIDs)
        }

        guard index.ledger.status == .reconciled,
              index.ledger.unknownIncludesUnmeasurable == false,
              index.ledger.unmeasurable.status == .measured,
              index.ledger.unmeasurable.bytes == ByteCount(0)
        else {
            return .sourceCorrupt
        }

        guard index.session.expiresAt > planningAt else {
            return .sourceExpired
        }
        return .eligible
    }

    private func classificationCandidates(
        source: InvestigationSourceProjection,
        relevanceTokens: Set<String>,
        planningAt: Date
    ) throws -> [InvestigationTarget] {
        let index = source.policyIndex
        var freshnessBySnapshot:
            [SnapshotID: InvestigationEvidenceFreshnessSummary] = [:]
        for evidence in index.evidence.values {
            switch evidence.freshness {
            case .current:
                break
            case .stale:
                freshnessBySnapshot[evidence.snapshotID, default: .init()]
                    .hasStale = true
            case .expired:
                freshnessBySnapshot[evidence.snapshotID, default: .init()]
                    .hasExpired = true
            }
        }
        var candidates: [InvestigationTarget] = []
        candidates.reserveCapacity(index.classifications.count)

        for classification in index.classifications.values {
            guard classification.category != .protected,
                  classification.disposition != .protected
            else {
                continue
            }
            guard let snapshot = index.snapshots[classification.snapshotID]
            else {
                throw InvestigationPlanningError.sourceIneligible(
                    .sourceCorrupt
                )
            }

            let freshness = freshnessBySnapshot[snapshot.id] ?? .init()
            let hasStale = freshness.hasStale
            let hasExpired = freshness.hasExpired
            let highRisk = classification.risk == .high
                || classification.risk == .critical
            let lowConfidence = classification.confidence != .high
            let conflict = classification.disposition == .readyToReclaim
                && (highRisk || lowConfidence)
            let measuredLarge = snapshot.measurementStatus == .measured
                && snapshot.expectedAllocatedBytes.map {
                    $0.value >= Self.largeMeasuredAllocationThreshold.value
                } == true
            let unknownLarge =
                classification.disposition == .unknown && measuredLarge
            let unknownOrReview =
                classification.disposition == .unknown
                    || classification.disposition == .reviewRecommended
            let unknownProducer = unknownOrReview
                && classification.producer == nil
            let staleOrInsufficient = unknownOrReview
                && (!classification.missingEvidenceKeys.isEmpty
                    || hasStale
                    || hasExpired)

            let kind: InvestigationTargetKind?
            if conflict {
                kind = .classificationConflict
            } else if unknownLarge {
                kind = .unknownLargeConsumer
            } else if unknownProducer {
                kind = .unknownProducer
            } else if staleOrInsufficient {
                kind = .staleOrInsufficientEvidence
            } else {
                kind = nil
            }
            guard let kind else {
                continue
            }

            var reasons = classification.missingEvidenceKeys
            if highRisk {
                reasons.append(Self.reasonClassificationHighRisk)
            }
            if lowConfidence {
                reasons.append(Self.reasonClassificationLowConfidence)
            }
            if classification.producer == nil {
                reasons.append(Self.reasonUnknownProducer)
            }
            if !classification.missingEvidenceKeys.isEmpty {
                reasons.append(Self.reasonRequiredEvidenceMissing)
            }
            if classification.ruleID == nil {
                reasons.append(Self.reasonRuleMiss)
            }
            if hasStale {
                reasons.append(Self.reasonEvidenceStale)
            }
            if hasExpired {
                reasons.append(Self.reasonEvidenceExpired)
            }

            let canonicalReasons = try canonicalReasons(reasons)
            let relevance = relevancePermille(
                expectedAllocatedBytes: snapshot.expectedAllocatedBytes,
                category: classification.category,
                tokens: relevanceTokens
            )
            candidates.append(
                try makeTarget(
                    source: source,
                    binding: .classification(
                        classificationID: classification.id,
                        snapshotID: snapshot.id
                    ),
                    kind: kind,
                    reasons: canonicalReasons,
                    expectedAllocatedBytes:
                        snapshot.expectedAllocatedBytes,
                    relevancePermille: relevance,
                    planningAt: planningAt
                )
            )
        }
        return candidates
    }

    private func missingClassificationCandidates(
        source: InvestigationSourceProjection,
        relevanceTokens: Set<String>,
        planningAt: Date
    ) throws -> [InvestigationTarget] {
        let classifiedSnapshots = Set(
            source.policyIndex.classifications.values.map(\.snapshotID)
        )
        var candidates: [InvestigationTarget] = []

        for snapshot in source.policyIndex.snapshots.values {
            guard !classifiedSnapshots.contains(snapshot.id),
                  !snapshot.isRoot,
                  snapshot.measurementStatus == .measured,
                  let bytes = snapshot.expectedAllocatedBytes,
                  bytes.value
                    >= Self.largeMeasuredAllocationThreshold.value
            else {
                continue
            }
            candidates.append(
                try makeTarget(
                    source: source,
                    binding: .snapshot(snapshot.id),
                    kind: .staleOrInsufficientEvidence,
                    reasons: try canonicalReasons([
                        Self.reasonClassificationMissing,
                    ]),
                    expectedAllocatedBytes: bytes,
                    relevancePermille: relevancePermille(
                        expectedAllocatedBytes: bytes,
                        category: nil,
                        tokens: relevanceTokens
                    ),
                    planningAt: planningAt
                )
            )
        }
        return candidates
    }

    private func ledgerCandidate(
        source: InvestigationSourceProjection,
        relevanceTokens: Set<String>,
        planningAt: Date
    ) throws -> InvestigationTarget? {
        let unknown = source.policyIndex.ledger.unknown
        guard unknown.status == .measured,
              let bytes = unknown.bytes,
              bytes.value > 0
        else {
            return nil
        }
        return try makeTarget(
            source: source,
            binding: .spaceLedger(.unknownResidual),
            kind: .unexplainedSpaceGap,
            reasons: try canonicalReasons([
                Self.reasonSpaceUnknownResidual,
            ]),
            expectedAllocatedBytes: bytes,
            relevancePermille: relevancePermille(
                expectedAllocatedBytes: bytes,
                category: nil,
                tokens: relevanceTokens
            ),
            planningAt: planningAt
        )
    }

    private func makeTarget(
        source: InvestigationSourceProjection,
        binding: InvestigationSourceBinding,
        kind: InvestigationTargetKind,
        reasons: [DomainToken],
        expectedAllocatedBytes: ByteCount?,
        relevancePermille: UInt64,
        planningAt: Date
    ) throws -> InvestigationTarget {
        let factors = factors(for: kind)
        return try InvestigationTarget(
            scanSessionID: source.summary.scanSessionID,
            scanScopeID: source.summary.primaryScopeID,
            sourceBinding: binding,
            kind: kind,
            reasonKeys: reasons,
            expectedAllocatedBytes: expectedAllocatedBytes,
            uncertaintyPermille: factors.uncertainty,
            relevancePermille: relevancePermille,
            investigationCostPermille: factors.cost,
            createdAt: planningAt
        )
    }

    private func factors(
        for kind: InvestigationTargetKind
    ) -> (uncertainty: UInt64, cost: UInt64) {
        switch kind {
        case .unknownLargeConsumer:
            (750, 250)
        case .unexplainedSpaceGap:
            (1_000, 800)
        case .classificationConflict:
            (1_000, 350)
        case .unknownProducer:
            (850, 400)
        case .staleOrInsufficientEvidence:
            (700, 300)
        }
    }

    private func validatedRelevanceTokens(
        _ tokens: [DomainToken]
    ) throws -> Set<String> {
        let allowed = Set([
            Self.relevanceLarge.rawValue,
            Self.relevanceDeveloper.rawValue,
        ])
        let values = tokens.map(\.rawValue)
        guard Set(values).count == values.count,
              values.allSatisfy(allowed.contains)
        else {
            throw InvestigationPlanningError.invalidRelevanceToken
        }
        return Set(values)
    }

    private func relevancePermille(
        expectedAllocatedBytes: ByteCount?,
        category: ArtifactCategory?,
        tokens: Set<String>
    ) -> UInt64 {
        var relevance: UInt64 = 700
        if tokens.contains(Self.relevanceLarge.rawValue),
           expectedAllocatedBytes.map({
               $0.value >= Self.largeMeasuredAllocationThreshold.value
           }) == true
        {
            relevance += 100
        }
        if tokens.contains(Self.relevanceDeveloper.rawValue),
           let category,
           Self.developerCategories.contains(category)
        {
            relevance += 100
        }
        return min(relevance, 1_000)
    }

    private func canonicalReasons(
        _ reasons: [DomainToken]
    ) throws -> [DomainToken] {
        let unique = Set(reasons)
        guard !unique.isEmpty else {
            throw InvestigationPlanningError.candidateReasonMissing
        }
        guard unique.count <= 16 else {
            throw InvestigationPlanningError.candidateReasonLimitExceeded
        }
        return try unique.map {
            ($0, try canonicalTextBytes($0.rawValue))
        }.sorted {
            $0.1.lexicographicallyPrecedes($1.1)
        }.map(\.0)
    }

    private func validateCandidateUniqueness(
        _ candidates: [InvestigationTarget]
    ) throws {
        guard Set(candidates.map(\.id)).count == candidates.count,
              Set(candidates.map(\.sourceBinding)).count
                == candidates.count
        else {
            throw InvestigationPlanningError.duplicateCandidate
        }
        let kindBindings = Set(
            candidates.map {
                CandidateKey(kind: $0.kind, binding: $0.sourceBinding)
            }
        )
        guard kindBindings.count == candidates.count else {
            throw InvestigationPlanningError.duplicateCandidate
        }
    }

    private func canonicalTextBytes(_ text: String) throws -> Data {
        var data = Data()
        try StornautInvestigationCanonicalV1.appendValueForSchema(
            .text(text),
            to: &data
        )
        return data
    }

    private func measurableByteTotal<S: Sequence>(
        _ targets: S
    ) throws -> UInt64 where S.Element == InvestigationTarget {
        var total: UInt64 = 0
        for target in targets {
            guard let bytes = target.expectedAllocatedBytes else {
                continue
            }
            let addition = total.addingReportingOverflow(bytes.value)
            guard !addition.overflow else {
                throw InvestigationPlanningError.integerOverflow
            }
            total = addition.partialValue
        }
        return total
    }

    private func unfinishedScopePrecedes(
        _ lhs: UnfinishedScanScope,
        _ rhs: UnfinishedScanScope
    ) -> Bool {
        if lhs.id.rawValue != rhs.id.rawValue {
            return lhs.id.rawValue < rhs.id.rawValue
        }
        return lhs.reason.rawValue < rhs.reason.rawValue
    }

    private struct CandidateKey: Hashable {
        let kind: InvestigationTargetKind
        let binding: InvestigationSourceBinding
    }

    private static let relevanceLarge =
        DomainToken(rawValue: "relevance.large")!
    private static let relevanceDeveloper =
        DomainToken(rawValue: "relevance.developer")!
    private static let reasonClassificationHighRisk =
        DomainToken(rawValue: "reason.classification-high-risk")!
    private static let reasonClassificationLowConfidence =
        DomainToken(rawValue: "reason.classification-low-confidence")!
    private static let reasonClassificationMissing =
        DomainToken(rawValue: "reason.classification-missing")!
    private static let reasonEvidenceExpired =
        DomainToken(rawValue: "reason.evidence-expired")!
    private static let reasonEvidenceStale =
        DomainToken(rawValue: "reason.evidence-stale")!
    private static let reasonRequiredEvidenceMissing =
        DomainToken(rawValue: "reason.required-evidence-missing")!
    private static let reasonRuleMiss =
        DomainToken(rawValue: "reason.rule-miss")!
    private static let reasonSpaceUnknownResidual =
        DomainToken(rawValue: "reason.space-unknown-residual")!
    private static let reasonUnknownProducer =
        DomainToken(rawValue: "reason.unknown-producer")!

    private static let developerCategories: Set<ArtifactCategory> = [
        .packageAndBuildCaches,
        .rebuildableProjectArtifacts,
        .toolRuntimesAndImages,
        .largeRepositoriesAndHistory,
        .unknownLargeConsumers,
    ]
}

private struct InvestigationEvidenceFreshnessSummary {
    var hasStale = false
    var hasExpired = false
}
