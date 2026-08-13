import Foundation
import StornautCore

struct RuleDispositionPromotionResult {
    let sourceVersion: DomainToken
    let baseCatalogVersion: DomainToken
    let rules: [CompiledRule]
}

struct RuleDispositionPromotionCompiler {
    private static let approvedPromotions: [String: ReclaimDisposition] = [
        "cache-npm-content": .readyToReclaim,
        "cache-pip": .readyToReclaim,
    ]

    func apply(
        promotionData: Data,
        rules: [CompiledRule]
    ) throws -> RuleDispositionPromotionResult {
        guard promotionData.count <= RuleSourceCompiler.maximumInputBytes else {
            throw RuleCompilerError.inputTooLarge(
                limit: RuleSourceCompiler.maximumInputBytes
            )
        }
        var auditor = StrictJSONAuditor(data: promotionData)
        try auditor.validate()
        let root: [String: Any]
        do {
            guard let value = try JSONSerialization.jsonObject(
                with: promotionData
            ) as? [String: Any] else {
                throw RuleCompilerError.invalidJSON
            }
            root = value
        } catch let error as RuleCompilerError {
            throw error
        } catch {
            throw RuleCompilerError.invalidJSON
        }
        try exactKeys(
            root,
            allowed: [
                "schemaVersion",
                "catalogVersion",
                "baseCatalogVersion",
                "promotions",
            ],
            context: "promotionCatalog"
        )
        guard try integer(root, key: "schemaVersion") == 1,
              let sourceVersion = DomainToken(
                  rawValue: try string(root, key: "catalogVersion")
              ),
              sourceVersion.rawValue == "package-build-caches-v2",
              let baseVersion = DomainToken(
                  rawValue: try string(root, key: "baseCatalogVersion")
              ),
              baseVersion.rawValue == "package-build-caches-v1",
              let entries = root["promotions"] as? [[String: Any]],
              entries.count == Self.approvedPromotions.count
        else {
            throw RuleCompilerError.invalidValue("promotionCatalog")
        }
        var promotions: [RuleID: ReclaimDisposition] = [:]
        for (index, entry) in entries.enumerated() {
            try exactKeys(
                entry,
                allowed: ["ruleID", "from", "to"],
                context: "promotionCatalog.promotions[\(index)]"
            )
            guard let ruleID = RuleID(
                rawValue: try string(entry, key: "ruleID")
            ),
            let from = ReclaimDisposition(
                rawValue: try string(entry, key: "from")
            ),
            let to = ReclaimDisposition(
                rawValue: try string(entry, key: "to")
            ),
            from == .reviewRecommended,
            Self.approvedPromotions[ruleID.rawValue] == to,
            promotions.updateValue(to, forKey: ruleID) == nil
            else {
                throw RuleCompilerError.invalidValue(
                    "promotionCatalog.promotions"
                )
            }
        }
        guard Set(promotions.keys.map(\.rawValue))
                == Set(Self.approvedPromotions.keys)
        else {
            throw RuleCompilerError.invalidValue(
                "promotionCatalog.promotions"
            )
        }
        let promoted = try rules.map { rule -> CompiledRule in
            guard let disposition = promotions[rule.id] else {
                return rule
            }
            guard rule.disposition == .reviewRecommended else {
                throw RuleCompilerError.invalidValue(
                    "promotionCatalog.baseDisposition"
                )
            }
            return try CompiledRule(
                id: rule.id,
                match: rule.match,
                excludedPatterns: rule.excludedPatterns,
                producer: rule.producer,
                rationaleKey: rule.rationaleKey,
                category: rule.category,
                disposition: disposition,
                risk: rule.risk,
                confidenceRequirement: rule.confidenceRequirement,
                veto: rule.veto,
                requiredEvidenceKeys: rule.requiredEvidenceKeys,
                requiredActivityKeys: rule.requiredActivityKeys,
                recovery: rule.recovery,
                recommendedAction: rule.recommendedAction,
                provenance: rule.provenance,
                fixtureIDs: rule.fixtureIDs,
                appliedOverlayIDs: rule.appliedOverlayIDs
            )
        }
        return RuleDispositionPromotionResult(
            sourceVersion: sourceVersion,
            baseCatalogVersion: baseVersion,
            rules: promoted
        )
    }

    private func exactKeys(
        _ object: [String: Any],
        allowed: Set<String>,
        context: String
    ) throws {
        guard Set(object.keys) == allowed else {
            throw RuleCompilerError.invalidValue(context)
        }
    }

    private func string(
        _ object: [String: Any],
        key: String
    ) throws -> String {
        guard let value = object[key] as? String, !value.isEmpty else {
            throw RuleCompilerError.invalidValue(key)
        }
        return value
    }

    private func integer(
        _ object: [String: Any],
        key: String
    ) throws -> Int {
        guard let number = object[key] as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.rounded() == number.doubleValue
        else {
            throw RuleCompilerError.invalidValue(key)
        }
        return number.intValue
    }
}
