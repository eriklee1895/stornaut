import Foundation

public enum BuiltInExecutionProfileCatalogError:
    Error,
    Sendable,
    Equatable
{
    case missingResource
    case invalidCatalog
}

public enum BuiltInExecutionProfileCatalog {
    public static func load(
        ruleCatalog: RuleCatalog
    ) throws -> ExecutionProfileCatalog {
        guard let url = Bundle.module.url(
            forResource: "BuiltInExecutionProfileCatalog",
            withExtension: "json"
        ) else {
            throw BuiltInExecutionProfileCatalogError.missingResource
        }
        do {
            let catalog = try DomainJSON.decode(
                ExecutionProfileCatalog.self,
                from: Data(contentsOf: url)
            )
            guard catalog.catalogVersion.rawValue == "safe-execution-v1",
                  catalog.ruleCatalogVersion == ruleCatalog.catalogVersion,
                  catalog.profiles.count == 3,
                  catalog.profiles.map(\.id.rawValue) == [
                      "phase-c.go-build-cache-v1",
                      "phase-c.npm-cacache-v1",
                      "phase-c.pip-cache-v1",
                  ],
                  isApprovedPhaseCCatalog(
                      catalog,
                      ruleCatalog: ruleCatalog
                  )
            else {
                throw BuiltInExecutionProfileCatalogError.invalidCatalog
            }
            return catalog
        } catch let error as BuiltInExecutionProfileCatalogError {
            throw error
        } catch {
            throw BuiltInExecutionProfileCatalogError.invalidCatalog
        }
    }

    static func isApprovedPhaseCCatalog(
        _ catalog: ExecutionProfileCatalog,
        ruleCatalog: RuleCatalog
    ) -> Bool {
        let expected = [
            ExpectedProfile(
                id: "phase-c.go-build-cache-v1",
                ruleID: "cache-go-build",
                relativePath: "Library/Caches/go-build",
                disposition: .reviewRecommended,
                suggestion: .never,
                exactNames: ["asm", "cgo", "compile", "go", "link"],
                versionedFamilies: [],
                fixtureIDs: [
                    "cache-go-build-active",
                    "cache-go-build-config",
                    "cache-go-build-other",
                    "cache-go-build-positive",
                ]
            ),
            ExpectedProfile(
                id: "phase-c.npm-cacache-v1",
                ruleID: "cache-npm-content",
                relativePath: ".npm/_cacache",
                disposition: .readyToReclaim,
                suggestion: .readyWhenEligible,
                exactNames: ["corepack", "node", "npm", "npx"],
                versionedFamilies: [],
                fixtureIDs: [
                    "cache-npm-content-active",
                    "cache-npm-content-config",
                    "cache-npm-content-other",
                    "cache-npm-content-positive",
                ]
            ),
            ExpectedProfile(
                id: "phase-c.pip-cache-v1",
                ruleID: "cache-pip",
                relativePath: "Library/Caches/pip",
                disposition: .readyToReclaim,
                suggestion: .readyWhenEligible,
                exactNames: ["pip", "python"],
                versionedFamilies: [.pip, .python],
                fixtureIDs: [
                    "cache-pip-active",
                    "cache-pip-config",
                    "cache-pip-other",
                    "cache-pip-positive",
                ]
            ),
        ]
        guard catalog.profiles.count == expected.count else {
            return false
        }
        for (profile, expectedProfile) in zip(
            catalog.profiles,
            expected
        ) {
            guard profile.id.rawValue == expectedProfile.id,
                  profile.ruleID.rawValue == expectedProfile.ruleID,
                  profile.relativePath.rawValue
                    == expectedProfile.relativePath,
                  profile.expectedKind == .directory,
                  profile.defaultSuggestion
                    == expectedProfile.suggestion,
                  profile.processSubjects.bundleIdentifiers.isEmpty,
                  profile.processSubjects.exactNames.map(\.rawValue)
                    == expectedProfile.exactNames,
                  profile.processSubjects.versionedFamilies
                    == expectedProfile.versionedFamilies,
                  profile.fixtureIDs.map(\.rawValue)
                    == expectedProfile.fixtureIDs,
                  Dictionary(
                      uniqueKeysWithValues:
                        profile.resolverBindings.map {
                            ($0.key.rawValue, $0.resolver)
                        }
                  ) == approvedResolverBindings,
                  let rule = ruleCatalog.rules.first(where: {
                      $0.id == profile.ruleID
                  }),
                  rule.match.pathPattern == profile.relativePath,
                  rule.match.expectedKind == profile.expectedKind,
                  rule.disposition == expectedProfile.disposition,
                  rule.confidenceRequirement == .high,
                  !rule.veto,
                  rule.recovery != nil,
                  rule.recommendedAction == .moveToTrash,
                  Set(
                      rule.requiredEvidenceKeys.map(\.rawValue)
                          + rule.requiredActivityKeys.map(\.rawValue)
                  ) == Set(approvedResolverBindings.keys),
                  rule.fixtureIDs == profile.fixtureIDs
            else {
                return false
            }
        }
        return true
    }

    private static let approvedResolverBindings:
        [String: ExecutionEvidenceResolver] = [
            "activity.process.inactive": .currentActivity,
            "evidence.cache.layout": .compilerAttested,
            "evidence.cache.reclaimable": .compilerAttested,
            "evidence.cache.tool-owned": .compilerAttested,
            "evidence.scope.user-owned": .currentFilesystem,
        ]
}

private struct ExpectedProfile {
    let id: String
    let ruleID: String
    let relativePath: String
    let disposition: ReclaimDisposition
    let suggestion: ExecutionDefaultSuggestion
    let exactNames: [String]
    let versionedFamilies: [VersionedProcessFamily]
    let fixtureIDs: [String]
}
