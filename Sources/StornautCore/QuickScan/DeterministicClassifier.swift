import Foundation

public struct DeterministicClassifier: Sendable {
    public init() {}

    public func classify(
        snapshot: PathSnapshot,
        candidates: [CompiledRule],
        satisfiedEvidenceKeys: [DomainToken],
        activityObservations: [ActivityObservation],
        classifiedAt: Date,
        classificationID: ClassificationID,
        catalogVersion: DomainToken = DomainToken(
            rawValue: "quick-scan-unknown-v1"
        )!
    ) throws -> Classification {
        let ordered = candidates.sorted { $0.id < $1.id }
        if let protected = ordered.first(where: { $0.veto }) {
            return try classification(
                snapshot: snapshot,
                rule: protected,
                disposition: .protected,
                risk: .critical,
                confidence: .high,
                missing: [],
                classifiedAt: classifiedAt,
                classificationID: classificationID,
                catalogVersion: catalogVersion
            )
        }
        guard ordered.count == 1, let rule = ordered.first else {
            let required = Set(
                ordered.flatMap {
                    $0.requiredEvidenceKeys + $0.requiredActivityKeys
                }
            ).sorted { $0.rawValue < $1.rawValue }
            return try Classification(
                id: classificationID,
                snapshotID: snapshot.id,
                ruleID: nil,
                producer: nil,
                category: .unknownLargeConsumers,
                disposition: .unknown,
                risk: ordered.map(\.risk).max(by: riskIsLower) ?? .high,
                confidence: .low,
                recovery: nil,
                requiredEvidenceKeys: required,
                missingEvidenceKeys: required,
                catalogVersion: catalogVersion,
                classifiedAt: classifiedAt
            )
        }

        let satisfied = Set(satisfiedEvidenceKeys)
        let missingEvidence = rule.requiredEvidenceKeys.filter {
            !satisfied.contains($0)
        }
        let activityKeys = try rule.requiredActivityKeys.map {
            try ActivityKey(validating: $0.rawValue)
        }
        let baseDisposition: ReclaimDisposition = missingEvidence.isEmpty
            ? rule.disposition
            : .unknown
        let reduction = ActivityReducer().reduce(
            ActivityReductionInput(
                baseDisposition: baseDisposition,
                baseRisk: rule.risk,
                requiredKeys: activityKeys,
                observations: activityObservations,
                timestamps: [],
                recentActivityCutoff: classifiedAt
            )
        )
        let missing = Set(
            missingEvidence
                + reduction.missingKeys.map {
                    DomainToken(rawValue: $0.rawValue)!
                }
        ).sorted { $0.rawValue < $1.rawValue }
        return try classification(
            snapshot: snapshot,
            rule: rule,
            disposition: reduction.disposition,
            risk: reduction.risk,
            confidence: missing.isEmpty
                ? rule.confidenceRequirement
                : .low,
            missing: missing,
            classifiedAt: classifiedAt,
            classificationID: classificationID,
            catalogVersion: catalogVersion
        )
    }

    private func classification(
        snapshot: PathSnapshot,
        rule: CompiledRule,
        disposition: ReclaimDisposition,
        risk: RiskLevel,
        confidence: EvidenceConfidence,
        missing: [DomainToken],
        classifiedAt: Date,
        classificationID: ClassificationID,
        catalogVersion: DomainToken
    ) throws -> Classification {
        try Classification(
            id: classificationID,
            snapshotID: snapshot.id,
            ruleID: DomainToken(rawValue: rule.id.rawValue),
            producer: rule.producer,
            category: rule.category,
            disposition: disposition,
            risk: risk,
            confidence: confidence,
            recovery: rule.recovery,
            requiredEvidenceKeys: Array(Set(
                rule.requiredEvidenceKeys + rule.requiredActivityKeys
            )).sorted { $0.rawValue < $1.rawValue },
            missingEvidenceKeys: missing,
            catalogVersion: catalogVersion,
            classifiedAt: classifiedAt
        )
    }
}

private func riskIsLower(_ lhs: RiskLevel, _ rhs: RiskLevel) -> Bool {
    riskRank(lhs) < riskRank(rhs)
}

private func riskRank(_ risk: RiskLevel) -> Int {
    switch risk {
    case .low:
        0
    case .medium:
        1
    case .high:
        2
    case .critical:
        3
    }
}
