import Foundation
import Testing
@testable import RuleCompilerKit
@testable import StornautCore

@Test
func compilerProducesDeterministicSortedImmutableCatalog() throws {
    let source = try ruleFixture("minimal-catalog")
    let first = try RuleSourceCompiler().compile(catalogData: source)
    let second = try RuleSourceCompiler().compile(catalogData: source)

    #expect(first.catalog.rules.map(\.id.rawValue) == [
        "fixture-cache",
        "fixture-review",
    ])
    #expect(first.data == second.data)
    #expect(first.sha256 == second.sha256)
    #expect(first.sha256.utf8.count == 64)
    #expect(first.manifest.ruleCount == 2)
    #expect(first.manifest.ruleIDs == first.catalog.rules.map(\.id))
    #expect(
        try DomainJSON.decode(RuleCatalog.self, from: first.data)
            == first.catalog
    )
    let output = String(decoding: first.data, as: UTF8.self)
    #expect(!output.contains("command"))
    #expect(!output.contains("executable"))
    #expect(!output.contains("arguments"))
}

@Test
func compilerRejectsUnknownDuplicateAndUnstableSchema() throws {
    let source = try catalogObject()

    #expect(throws: RuleCompilerError.self) {
        var changed = source
        changed["unexpected"] = true
        _ = try compile(changed)
    }
    #expect(throws: RuleCompilerError.self) {
        var changed = source
        changed["schemaVersion"] = 99
        _ = try compile(changed)
    }
    #expect(throws: RuleCompilerError.self) {
        var changed = source
        var rules = try rules(&changed)
        rules.append(rules[0])
        changed["rules"] = rules
        _ = try compile(changed)
    }
    #expect(throws: RuleCompilerError.self) {
        var changed = source
        var entries = try rules(&changed)
        entries[0]["id"] = "Fixture-Cache"
        changed["rules"] = entries
        _ = try compile(changed)
    }
    #expect(throws: RuleCompilerError.self) {
        var changed = source
        var entries = try rules(&changed)
        entries[1]["fixtureIDs"] = entries[0]["fixtureIDs"]
        changed["rules"] = entries
        _ = try compile(changed)
    }
    #expect(throws: RuleCompilerError.self) {
        var changed = source
        changed["catalogVersion"] = String(repeating: "v", count: 128)
        var overlay = try overlayTestObject()
        overlay["catalogVersion"] = String(repeating: "o", count: 128)
        _ = try RuleSourceCompiler().compile(
            catalogData: JSONSerialization.data(
                withJSONObject: changed,
                options: [.sortedKeys]
            ),
            overlayData: JSONSerialization.data(
                withJSONObject: overlay,
                options: [.sortedKeys]
            )
        )
    }
    #expect(throws: RuleCompilerError.self) {
        let duplicate = Data(
            """
            {"schemaVersion":1,"schemaVersion":1,"catalogVersion":"fixture-v1","rules":[]}
            """.utf8
        )
        _ = try RuleSourceCompiler().compile(catalogData: duplicate)
    }
}

@Test
func compilerRejectsUnsafePathsAndUnboundedInput() throws {
    let source = try catalogObject()
    for pattern in [
        "/",
        ".",
        "~",
        "*",
        "**",
        "../cache",
        "cache//nested",
        "cache/**suffix",
        "Library/[Cc]aches",
        "/Users/example/cache",
    ] {
        #expect(throws: RuleCompilerError.self) {
            var changed = source
            var entries = try rules(&changed)
            var match = try #require(
                entries[0]["match"] as? [String: Any]
            )
            match["pathPattern"] = pattern
            entries[0]["match"] = match
            changed["rules"] = entries
            _ = try compile(changed)
        }
    }
    #expect(throws: RuleCompilerError.self) {
        let oversized = Data(
            repeating: 0x20,
            count: RuleSourceCompiler.maximumInputBytes + 1
        )
        _ = try RuleSourceCompiler().compile(catalogData: oversized)
    }
    for sensitivePattern in [
        ".ssh",
        "**/.env",
        "Library/**/Mail",
        "**/Library/Mail",
        "Library/Mail",
        "Library/Application Support/Google/Chrome",
    ] {
        #expect(throws: RuleCompilerError.self) {
            var changed = source
            var entries = try rules(&changed)
            var match = try #require(
                entries[0]["match"] as? [String: Any]
            )
            match["pathPattern"] = sensitivePattern
            entries[0]["match"] = match
            changed["rules"] = entries
            _ = try compile(changed)
        }
    }
    #expect(throws: RuleCompilerError.self) {
        var changed = source
        var entries = try rules(&changed)
        entries[0]["requiredEvidenceKeys"] = (0...64).map {
            "evidence.\($0)"
        }
        changed["rules"] = entries
        _ = try compile(changed)
    }
    #expect(throws: RuleCompilerError.invalidJSON) {
        _ = try RuleSourceCompiler().compile(
            catalogData: Data(
                """
                {"schemaVersion":1,"catalogVersion":"fixture-v1","rules":[],"n":1e}
                """.utf8
            )
        )
    }
}

@Test
func compilerRejectsMissingProvenanceAndUnsafeReadyRules() throws {
    let source = try catalogObject()

    for mutation in [
        "sources",
        "verified",
        "url",
        "revision",
        "license",
    ] {
        #expect(throws: RuleCompilerError.self) {
            var changed = source
            var entries = try rules(&changed)
            var provenance = try #require(
                entries[0]["provenance"] as? [String: Any]
            )
            switch mutation {
            case "sources":
                provenance["sources"] = []
            case "verified":
                provenance["independentlyVerified"] = false
            default:
                var sources = try #require(
                    provenance["sources"] as? [[String: Any]]
                )
                if mutation == "url" {
                    sources[0]["url"] = "http://example.invalid/source"
                } else {
                    sources[0][mutation] = ""
                }
                provenance["sources"] = sources
            }
            entries[0]["provenance"] = provenance
            changed["rules"] = entries
            _ = try compile(changed)
        }
    }
    #expect(throws: RuleCompilerError.self) {
        var changed = source
        var entries = try rules(&changed)
        var provenance = try #require(
            entries[0]["provenance"] as? [String: Any]
        )
        provenance["verifiedAt"] = "2999-01-01"
        entries[0]["provenance"] = provenance
        changed["rules"] = entries
        _ = try compile(changed)
    }

    for key in [
        "recovery",
        "requiredActivityKeys",
        "requiredEvidenceKeys",
    ] {
        #expect(throws: RuleCompilerError.self) {
            var changed = source
            var entries = try rules(&changed)
            entries[0][key] = key == "recovery" ? NSNull() : []
            changed["rules"] = entries
            _ = try compile(changed)
        }
    }
    for action in ["none", "shell", "permanentDelete", "registeredAction"] {
        #expect(throws: RuleCompilerError.self) {
            var changed = source
            var entries = try rules(&changed)
            entries[0]["recommendedAction"] = action
            changed["rules"] = entries
            _ = try compile(changed)
        }
    }
    #expect(throws: RuleCompilerError.self) {
        var changed = source
        var entries = try rules(&changed)
        entries[0]["confidenceRequirement"] = "medium"
        changed["rules"] = entries
        _ = try compile(changed)
    }
    #expect(throws: RuleCompilerError.self) {
        var changed = source
        var entries = try rules(&changed)
        entries[1]["category"] = "unknownLargeConsumers"
        entries[1]["disposition"] = "unknown"
        entries[1]["recommendedAction"] = "moveToTrash"
        changed["rules"] = entries
        _ = try compile(changed)
    }
}

@Test
func protectedRuleMayMatchSensitiveLiteralButCannotProposeAction() throws {
    var source = try catalogObject()
    var entries = try rules(&source)
    var match = try #require(entries[1]["match"] as? [String: Any])
    match["pathPattern"] = "Library/Mail"
    entries[1]["match"] = match
    entries[1]["rationaleKey"] = "rationale.protected.mail"
    entries[1]["category"] = "protected"
    entries[1]["disposition"] = "protected"
    entries[1]["risk"] = "critical"
    entries[1]["veto"] = true
    entries[1]["recovery"] = NSNull()
    entries[1]["recommendedAction"] = "none"
    source["rules"] = entries

    let artifact = try compile(source)

    let rule = try #require(
        artifact.catalog.rules.first { $0.id.rawValue == "fixture-review" }
    )
    #expect(rule.veto)
    #expect(rule.recommendedAction == .none)
}

@Test
func compilerRequiresRuleRationaleAndPreservesItThroughOverlay() throws {
    var source = try catalogObject()
    var entries = try rules(&source)
    entries[0]["rationaleKey"] = "rationale.fixture.cache"
    entries[1]["rationaleKey"] = "rationale.fixture.review"
    source["rules"] = entries

    let artifact = try RuleSourceCompiler().compile(
        catalogData: JSONSerialization.data(
            withJSONObject: source,
            options: [.sortedKeys]
        ),
        overlayData: try ruleFixture("conservative-overlay")
    )

    #expect(
        artifact.catalog.rules.map(\.rationaleKey.rawValue) == [
            "rationale.fixture.cache",
            "rationale.fixture.review",
        ]
    )
    for invalidValue in [nil, NSNull(), "rationale with spaces"] as [Any?] {
        #expect(throws: RuleCompilerError.self) {
            var changed = source
            var changedRules = try rules(&changed)
            if let invalidValue {
                changedRules[0]["rationaleKey"] = invalidValue
            } else {
                changedRules[0].removeValue(forKey: "rationaleKey")
            }
            changed["rules"] = changedRules
            _ = try compile(changed)
        }
    }
}

@Test
func compilerRejectsProtectedRuleWithoutCriticalRisk() throws {
    var source = try catalogObject()
    var entries = try rules(&source)
    entries[1]["rationaleKey"] = "rationale.protected.fixture"
    entries[1]["category"] = "protected"
    entries[1]["disposition"] = "protected"
    entries[1]["risk"] = "high"
    entries[1]["veto"] = true
    entries[1]["recovery"] = NSNull()
    entries[1]["recommendedAction"] = "none"
    source["rules"] = entries

    #expect(throws: RuleCompilerError.self) {
        _ = try compile(source)
    }
}

@Test
func builtInProtectedCatalogIsCompleteAndDeterministic() throws {
    let source = try builtInRuleFixture("protected-v1")
    let first = try RuleSourceCompiler().compile(catalogData: source)
    let second = try RuleSourceCompiler().compile(catalogData: source)
    let expectedRuleIDs = [
        "protected-browser-arc",
        "protected-browser-brave",
        "protected-browser-chrome",
        "protected-browser-edge",
        "protected-browser-firefox",
        "protected-browser-safari",
        "protected-credential-aws",
        "protected-credential-azure",
        "protected-credential-docker",
        "protected-credential-gcloud",
        "protected-credential-gh",
        "protected-credential-gnupg",
        "protected-credential-keychains",
        "protected-credential-kubernetes",
        "protected-credential-op",
        "protected-credential-ssh",
        "protected-password-1password-config",
        "protected-password-1password-library",
        "protected-password-bitwarden-config",
        "protected-password-bitwarden-library",
        "protected-password-lastpass",
        "protected-personal-mail",
        "protected-personal-messages",
        "protected-personal-photos-container",
        "protected-personal-photos-library",
        "protected-secret-credentials-json",
        "protected-secret-env",
        "protected-secret-private-key",
    ]

    #expect(first.data == second.data)
    #expect(first.sha256 == second.sha256)
    #expect(first.catalog.catalogVersion.rawValue == "protected-v1")
    #expect(first.catalog.rules.map(\.id.rawValue) == expectedRuleIDs)
    #expect(first.manifest.ruleCount == expectedRuleIDs.count)
    #expect(first.manifest.provenanceSourceCount == expectedRuleIDs.count * 2)
    #expect(first.manifest.fixtureCount == expectedRuleIDs.count * 2)
    for rule in first.catalog.rules {
        #expect(rule.category == .protected)
        #expect(rule.disposition == .protected)
        #expect(rule.risk == .critical)
        #expect(rule.veto)
        #expect(rule.recommendedAction == .none)
        #expect(rule.recovery == nil)
        #expect(
            rule.rationaleKey.rawValue.hasPrefix("rationale.protected.")
        )
        #expect(rule.provenance.independentlyVerified)
        #expect(rule.provenance.sources.count == 2)
        #expect(
            Set(rule.provenance.sources.map(\.usage)) == [
                .officialDocumentation,
                .independentObservation,
            ]
        )
        #expect(rule.provenance.sources.allSatisfy {
            $0.url.scheme == "https"
                && $0.revision.rawValue.count == 40
                && $0.license.rawValue == "MIT"
        })
    }
}

@Test
func builtInProtectedCatalogFixturesHaveUniquePositiveAndLookalikeCases() throws {
    let artifact = try RuleSourceCompiler().compile(
        catalogData: try builtInRuleFixture("protected-v1")
    )
    let pathFixture = try JSONSerialization.jsonObject(
        with: ruleFixture("protected-path-cases")
    )
    let fixtureObject = try #require(pathFixture as? [String: Any])
    let fixtureCases = try #require(
        fixtureObject["cases"] as? [[String: Any]]
    )
    let fixturesByID = try Dictionary(
        uniqueKeysWithValues: fixtureCases.map {
            (
                try #require($0["id"] as? String),
                try #require($0["path"] as? String)
            )
        }
    )

    for rule in artifact.catalog.rules {
        let ids = rule.fixtureIDs.map(\.rawValue)
        let positiveID = try #require(
            ids.first { $0.hasSuffix("-positive") }
        )
        let lookalikeID = try #require(
            ids.first { $0.hasSuffix("-lookalike") }
        )
        let positivePath = try #require(fixturesByID[positiveID])
        let lookalikePath = try #require(fixturesByID[lookalikeID])
        #expect(ids.count == 2)
        #expect(ids.allSatisfy { fixturesByID[$0] != nil })
        #expect(rulePattern(rule.match, protects: positivePath))
        #expect(!rulePattern(rule.match, protects: lookalikePath))
    }
}

@Test
func builtInProtectedCatalogRejectsDowngradeOverlay() throws {
    #expect(throws: RuleCompilerError.overlayNotConservative(
        "overlay-protected-mail-downgrade"
    )) {
        _ = try RuleSourceCompiler().compile(
            catalogData: try builtInRuleFixture("protected-v1"),
            overlayData: try ruleFixture("protected-downgrade-overlay")
        )
    }
}

private func ruleFixture(_ name: String) throws -> Data {
    try Data(
        contentsOf: repositoryRoot.appending(
            path: "Tests/Fixtures/Rules/\(name).json"
        )
    )
}

private func builtInRuleFixture(_ name: String) throws -> Data {
    try Data(
        contentsOf: repositoryRoot.appending(
            path: "Rules/BuiltIn/\(name).json"
        )
    )
}

private func rulePattern(
    _ match: RuleMatch,
    protects path: String
) -> Bool {
    let pathComponents = normalizedRuleComponents(path)
    switch match.expectedKind {
    case .directory:
        return (1...pathComponents.count).contains {
            ruleGlob(
                match.pathPattern.rawValue,
                matches: pathComponents.prefix($0).joined(separator: "/")
            )
        }
    case .regularFile, .symbolicLink, .other:
        return ruleGlob(match.pathPattern.rawValue, matches: path)
    }
}

private func ruleGlob(_ pattern: String, matches path: String) -> Bool {
    let patternComponents = normalizedRuleComponents(pattern)
    let pathComponents = normalizedRuleComponents(path)
    var memo: [RuleFixtureGlobState: Bool] = [:]
    func match(_ patternIndex: Int, _ pathIndex: Int) -> Bool {
        let state = RuleFixtureGlobState(
            patternIndex: patternIndex,
            pathIndex: pathIndex
        )
        if let result = memo[state] {
            return result
        }
        let result: Bool
        if patternIndex == patternComponents.count {
            result = pathIndex == pathComponents.count
        } else if patternComponents[patternIndex] == "**" {
            result = match(patternIndex + 1, pathIndex)
                || (
                    pathIndex < pathComponents.count
                        && match(patternIndex, pathIndex + 1)
                )
        } else if pathIndex < pathComponents.count,
                  patternComponents[patternIndex] == "*"
                    || patternComponents[patternIndex]
                        == pathComponents[pathIndex]
        {
            result = match(patternIndex + 1, pathIndex + 1)
        } else {
            result = false
        }
        memo[state] = result
        return result
    }
    return match(0, 0)
}

private func normalizedRuleComponents(_ path: String) -> [String] {
    path.split(separator: "/", omittingEmptySubsequences: false).map {
        String($0).folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }
}

private struct RuleFixtureGlobState: Hashable {
    let patternIndex: Int
    let pathIndex: Int
}

private func catalogObject() throws -> [String: Any] {
    try #require(
        JSONSerialization.jsonObject(
            with: ruleFixture("minimal-catalog")
        ) as? [String: Any]
    )
}

private func compile(_ object: [String: Any]) throws -> CompiledRuleArtifact {
    try RuleSourceCompiler().compile(
        catalogData: JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
    )
}

private func rules(
    _ object: inout [String: Any]
) throws -> [[String: Any]] {
    try #require(object["rules"] as? [[String: Any]])
}

private func overlayTestObject() throws -> [String: Any] {
    try #require(
        JSONSerialization.jsonObject(
            with: ruleFixture("conservative-overlay")
        ) as? [String: Any]
    )
}

private var repositoryRoot: URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
