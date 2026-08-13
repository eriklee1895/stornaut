import Foundation
import StornautCore

public struct RuleCoverageEntry: Codable, Sendable, Equatable {
    public let ruleID: RuleID
    public let category: ArtifactCategory
    public let disposition: ReclaimDisposition
    public let risk: RiskLevel
    public let recommendedAction: RuleRecommendedAction
    public let rationaleKey: DomainToken
    public let provenance: RuleProvenance
    public let fixtureIDs: [DomainToken]

    public init(rule: CompiledRule) {
        ruleID = rule.id
        category = rule.category
        disposition = rule.disposition
        risk = rule.risk
        recommendedAction = rule.recommendedAction
        rationaleKey = rule.rationaleKey
        provenance = rule.provenance
        fixtureIDs = rule.fixtureIDs
    }
}

public struct RuleFamilyCoverage: Codable, Sendable, Equatable {
    public let familyID: DomainToken
    public let requirementIDs: [DomainToken]
    public let policyKeys: [DomainToken]
    public let ruleIDs: [RuleID]
    public let rules: [RuleCoverageEntry]

    public init(
        familyID: DomainToken,
        requirementIDs: [DomainToken],
        policyKeys: [DomainToken],
        rules: [CompiledRule]
    ) {
        self.familyID = familyID
        self.requirementIDs = requirementIDs
        self.policyKeys = policyKeys
        self.rules = rules.map(RuleCoverageEntry.init)
        ruleIDs = rules.map(\.id)
    }
}

public struct RuleCoverageManifest: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let catalogVersion: String
    public let families: [RuleFamilyCoverage]

    public init(
        catalogVersion: String,
        families: [RuleFamilyCoverage]
    ) {
        schemaVersion = 1
        self.catalogVersion = catalogVersion
        self.families = families
    }
}

public struct RuleCoverageCompiler: Sendable {
    public init() {}

    public func compile(
        coverageData: Data,
        catalog: RuleCatalog
    ) throws -> RuleCoverageManifest {
        guard coverageData.count <= RuleSourceCompiler.maximumInputBytes else {
            throw RuleCompilerError.inputTooLarge(
                limit: RuleSourceCompiler.maximumInputBytes
            )
        }
        var auditor = StrictJSONAuditor(data: coverageData)
        try auditor.validate()
        let value: Any
        do {
            value = try JSONSerialization.jsonObject(with: coverageData)
        } catch {
            throw RuleCompilerError.invalidJSON
        }
        guard let root = value as? [String: Any],
              Set(root.keys) == [
                "schemaVersion",
                "catalogVersion",
                "families",
              ],
              let schemaVersion = root["schemaVersion"] as? NSNumber,
              CFGetTypeID(schemaVersion) != CFBooleanGetTypeID(),
              schemaVersion.doubleValue.rounded() == schemaVersion.doubleValue,
              schemaVersion.intValue == 1,
              let catalogVersion = root["catalogVersion"] as? String,
              Self.isCompatibleCoverageSource(
                  catalogVersion,
                  catalog: catalog
              ),
              let familyValues = root["families"] as? [[String: Any]],
              familyValues.count == Self.requiredFamilyIDs.count
        else {
            throw RuleCatalogError.invalidCatalog
        }

        let rulesByID = Dictionary(
            uniqueKeysWithValues: catalog.rules.map { ($0.id, $0) }
        )
        var familyIDs = Set<DomainToken>()
        var assignedRuleIDs = Set<RuleID>()
        var families: [RuleFamilyCoverage] = []
        for family in familyValues {
            guard Set(family.keys) == [
                "familyID",
                "policyKeys",
                "requirementIDs",
                "ruleIDs",
              ],
                  let rawFamilyID = family["familyID"] as? String,
                  let familyID = DomainToken(rawValue: rawFamilyID),
                  Self.requiredFamilyIDs.contains(familyID),
                  familyIDs.insert(familyID).inserted,
                  let rawRequirementIDs = family["requirementIDs"] as? [String],
                  !rawRequirementIDs.isEmpty,
                  let rawPolicyKeys = family["policyKeys"] as? [String],
                  let rawRuleIDs = family["ruleIDs"] as? [String],
                  !rawRuleIDs.isEmpty
            else {
                throw RuleCatalogError.invalidCatalog
            }
            var rules: [CompiledRule] = []
            let requirementIDs = try rawRequirementIDs.map {
                guard let value = DomainToken(rawValue: $0) else {
                    throw RuleCatalogError.invalidCatalog
                }
                return value
            }
            guard Set(requirementIDs).count == requirementIDs.count else {
                throw RuleCatalogError.invalidCatalog
            }
            let policyKeys = try rawPolicyKeys.map {
                guard let value = DomainToken(rawValue: $0) else {
                    throw RuleCatalogError.invalidCatalog
                }
                return value
            }
            guard Set(policyKeys).count == policyKeys.count,
                  Set(policyKeys).isSubset(of: Self.requiredPolicyKeys)
            else {
                throw RuleCatalogError.invalidCatalog
            }
            for rawRuleID in rawRuleIDs {
                guard let ruleID = RuleID(rawValue: rawRuleID),
                      assignedRuleIDs.insert(ruleID).inserted,
                      let rule = rulesByID[ruleID]
                else {
                    throw RuleCatalogError.invalidCatalog
                }
                rules.append(rule)
            }
            rules.sort { $0.id < $1.id }
            families.append(
                RuleFamilyCoverage(
                    familyID: familyID,
                    requirementIDs: requirementIDs.sorted {
                        $0.rawValue < $1.rawValue
                    },
                    policyKeys: policyKeys.sorted {
                        $0.rawValue < $1.rawValue
                    },
                    rules: rules
                )
            )
        }
        guard familyIDs == Self.requiredFamilyIDs,
              assignedRuleIDs == Set(catalog.rules.map(\.id)),
              Set(families.flatMap(\.requirementIDs))
                == Self.requiredRequirementIDs,
              families.flatMap(\.requirementIDs).count
                == Self.requiredRequirementIDs.count,
              Set(families.flatMap(\.policyKeys)) == Self.requiredPolicyKeys,
              families.flatMap(\.policyKeys).count
                == Self.requiredPolicyKeys.count
        else {
            throw RuleCatalogError.invalidCatalog
        }
        return RuleCoverageManifest(
            catalogVersion: catalog.catalogVersion.rawValue,
            families: families.sorted {
                $0.familyID.rawValue < $1.familyID.rawValue
            }
        )
    }

    private static let requiredFamilyIDs: Set<DomainToken> = [
        DomainToken(rawValue: "fr2.package-build-caches")!,
        DomainToken(rawValue: "fr2.project-artifacts")!,
        DomainToken(rawValue: "fr2.protected-veto")!,
        DomainToken(rawValue: "fr2.tool-runtimes-images")!,
        DomainToken(rawValue: "fr2.updates-temporary-residue")!,
    ]

    private static let requiredRequirementIDs: Set<DomainToken> = Set([
        "fr2.cache.bun",
        "fr2.cache.cargo",
        "fr2.cache.conda",
        "fr2.cache.go",
        "fr2.cache.gradle",
        "fr2.cache.homebrew",
        "fr2.cache.maven",
        "fr2.cache.npm",
        "fr2.cache.pip",
        "fr2.cache.pnpm",
        "fr2.cache.uv",
        "fr2.cache.yarn",
        "fr2.project.flutter",
        "fr2.project.go",
        "fr2.project.java",
        "fr2.project.node",
        "fr2.project.php",
        "fr2.project.python",
        "fr2.project.ruby",
        "fr2.project.rust",
        "fr2.project.xcode",
        "fr2.protected.browser",
        "fr2.protected.credentials",
        "fr2.protected.personal-data",
        "fr2.protected.system",
        "fr2.runtime.ai",
        "fr2.runtime.colima",
        "fr2.runtime.cursor",
        "fr2.runtime.docker",
        "fr2.runtime.jetbrains",
        "fr2.runtime.lima",
        "fr2.runtime.vscode",
        "fr2.runtime.xcode",
        "fr2.residue.shipit",
        "fr2.residue.temporary",
        "fr2.residue.update",
    ].map { DomainToken(rawValue: $0)! })

    private static let requiredPolicyKeys: Set<DomainToken> = Set([
        "policy.canonical.filesystem-root",
        "policy.canonical.home",
        "policy.canonical.mount-root",
        "policy.sensitive.system-locations",
    ].map { DomainToken(rawValue: $0)! })

    private static func isCompatibleCoverageSource(
        _ sourceVersion: String,
        catalog: RuleCatalog
    ) -> Bool {
        sourceVersion == catalog.catalogVersion.rawValue
            || (
                sourceVersion == "builtin-runtime-tool-residue-v1"
                    && catalog.catalogVersion.rawValue
                        == "builtin-runtime-tool-residue-v2"
                    && Set(catalog.rules.filter {
                        $0.disposition == .readyToReclaim
                    }.map(\.id.rawValue)) == [
                        "cache-npm-content",
                        "cache-pip",
                    ]
            )
    }
}
