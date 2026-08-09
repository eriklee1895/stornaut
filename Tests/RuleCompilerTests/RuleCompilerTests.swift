import CryptoKit
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

@Test
func compilerMergesVersionedSourcesWithoutMutatingProtectedV1() throws {
    let protectedSource = try builtInRuleFixture("protected-v1")
    var projectSource = try catalogObject()
    projectSource["catalogVersion"] = "project-artifacts-v1"
    let projectData = try JSONSerialization.data(
        withJSONObject: projectSource,
        options: [.sortedKeys]
    )

    let first = try RuleSourceCompiler().compile(
        catalogSources: [protectedSource, projectData],
        catalogVersion: try DomainToken(
            validating: "builtin-project-artifacts-v1"
        )
    )
    let reordered = try RuleSourceCompiler().compile(
        catalogSources: [projectData, protectedSource],
        catalogVersion: try DomainToken(
            validating: "builtin-project-artifacts-v1"
        )
    )

    #expect(first.data == reordered.data)
    #expect(first.sha256 == reordered.sha256)
    #expect(first.manifest.sourceCatalogVersions == [
        "project-artifacts-v1",
        "protected-v1",
    ])
    #expect(first.manifest.ruleCount == 30)
    #expect(
        SHA256.hash(data: protectedSource).map {
            String(format: "%02x", $0)
        }.joined()
            == "8ad3074f568959ea3b6ae65f90dbe389275a61c71cd68b4c84f2cce3b3a72033"
    )
}

@Test
func compilerRejectsDuplicateRulesAndUnboundedSourceSets() throws {
    let source = try builtInRuleFixture("protected-v1")

    #expect(throws: RuleCompilerError.self) {
        _ = try RuleSourceCompiler().compile(
            catalogSources: [source, source],
            catalogVersion: try DomainToken(
                validating: "duplicate-source-v1"
            )
        )
    }
    #expect(throws: RuleCompilerError.self) {
        _ = try RuleSourceCompiler().compile(
            catalogSources: Array(repeating: source, count: 17),
            catalogVersion: try DomainToken(
                validating: "too-many-sources-v1"
            )
        )
    }
    let padded = source + Data(
        repeating: 0x20,
        count: RuleSourceCompiler.maximumInputBytes / 2
    )
    #expect(throws: RuleCompilerError.self) {
        _ = try RuleSourceCompiler().compile(
            catalogSources: [padded, padded],
            catalogVersion: try DomainToken(
                validating: "oversized-sources-v1"
            )
        )
    }
}

@Test
func projectArtifactCatalogCoversApprovedFamiliesConservatively() throws {
    let artifact = try RuleSourceCompiler().compile(
        catalogSources: [
            try builtInRuleFixture("protected-v1"),
            try builtInRuleFixture("project-artifacts-v1"),
        ],
        catalogVersion: try DomainToken(
            validating: "builtin-project-artifacts-v1"
        )
    )
    let projectRules = artifact.catalog.rules.filter {
        $0.category == .rebuildableProjectArtifacts
    }
    let expectedIDs = [
        "project-flutter-build",
        "project-go-vendor",
        "project-java-gradle-build",
        "project-java-maven-target",
        "project-node-modules",
        "project-php-composer-vendor",
        "project-python-venv",
        "project-ruby-bundle-vendor",
        "project-rust-target",
        "project-xcode-derived-data",
    ]

    #expect(projectRules.map(\.id.rawValue) == expectedIDs)
    #expect(artifact.catalog.rules.count == 38)
    #expect(artifact.manifest.sourceCatalogVersions == [
        "project-artifacts-v1",
        "protected-v1",
    ])
    for rule in projectRules {
        #expect(rule.disposition == .reviewRecommended)
        #expect(rule.confidenceRequirement == .high)
        #expect(!rule.veto)
        #expect(rule.recommendedAction == .moveToTrash)
        #expect(rule.recovery != nil)
        #expect(!rule.requiredEvidenceKeys.isEmpty)
        #expect(!rule.requiredActivityKeys.isEmpty)
        #expect(
            rule.requiredEvidenceKeys.map(\.rawValue).contains(
                "evidence.artifact.not-versioned"
            )
        )
        #expect(
            rule.requiredEvidenceKeys.map(\.rawValue).contains(
                "evidence.recovery.inputs-present"
            )
        )
        #expect(
            rule.requiredActivityKeys.map(\.rawValue).contains(
                "activity.git.clean"
            )
        )
        #expect(
            rule.requiredActivityKeys.map(\.rawValue).contains(
                "activity.git.upstream-synced"
            )
        )
        #expect(
            rule.requiredActivityKeys.map(\.rawValue).contains(
                "activity.process.inactive"
            )
        )
        #expect(rule.provenance.sources.count >= 2)
    }
}

@Test
func projectArtifactFixturesBindPatternsMarkersAndSafetyBlocks() throws {
    let projectArtifact = try RuleSourceCompiler().compile(
        catalogData: try builtInRuleFixture("project-artifacts-v1")
    )
    let fixture = try projectArtifactFixture()
    let casesByRule = Dictionary(grouping: fixture.cases, by: \.ruleID)

    for rule in projectArtifact.catalog.rules {
        let cases = try #require(casesByRule[rule.id.rawValue])
        let positive = try #require(
            cases.first { $0.kind == "positive" }
        )
        let safety = try #require(
            cases.first { $0.kind == "safety" }
        )
        let projectRoot = try #require(
            cases.first { $0.kind == "projectRoot" }
        )
        let sourceDirectory = try #require(
            cases.first { $0.kind == "sourceDirectory" }
        )
        let requirements = Set(
            rule.requiredEvidenceKeys.map(\.rawValue)
                + rule.requiredActivityKeys.map(\.rawValue)
        )
        let positivePresent = Set(positive.presentKeys)
        let safetyPresent = Set(safety.presentKeys)
        let safetyMissing = Set(safety.missingKeys)

        #expect(rulePattern(rule.match, protects: positive.path))
        #expect(rulePattern(rule.match, protects: safety.path))
        #expect(!rulePattern(rule.match, protects: projectRoot.path))
        #expect(!rulePattern(rule.match, protects: sourceDirectory.path))
        #expect(positivePresent == requirements)
        #expect(positive.missingKeys.isEmpty)
        #expect(safetyPresent.union(safetyMissing) == requirements)
        #expect(safetyPresent.isDisjoint(with: safetyMissing))
        #expect(!safetyMissing.isEmpty)
    }
}

@Test
func catalogMatcherReturnsStableExactCandidatesForCollidingPatterns() throws {
    let artifact = try RuleSourceCompiler().compile(
        catalogSources: [
            try builtInRuleFixture("protected-v1"),
            try builtInRuleFixture("project-artifacts-v1"),
        ],
        catalogVersion: try DomainToken(
            validating: "builtin-project-artifacts-v1"
        )
    )
    let matcher = RuleCatalogMatcher(catalog: artifact.catalog)

    #expect(
        try matcher.matchingRules(
            relativePath: "projects/sample/build",
            kind: .directory
        ).map(\.id.rawValue) == [
            "project-flutter-build",
            "project-java-gradle-build",
        ]
    )
    #expect(
        try matcher.matchingRules(
            relativePath: "projects/sample/target",
            kind: .directory
        ).map(\.id.rawValue) == [
            "project-java-maven-target",
            "project-rust-target",
        ]
    )
    #expect(
        try matcher.matchingRules(
            relativePath: "projects/sample/vendor",
            kind: .directory
        ).map(\.id.rawValue) == [
            "project-go-vendor",
            "project-php-composer-vendor",
        ]
    )
    #expect(try matcher.matchingRules(
        relativePath: "projects/sample",
        kind: .directory
    ).isEmpty)
    #expect(try matcher.matchingRules(
        relativePath: "projects/sample/src",
        kind: .directory
    ).isEmpty)
    #expect(try matcher.matchingRules(
        relativePath: "projects/sample/Target",
        kind: .directory
    ).isEmpty)
    #expect(try matcher.matchingRules(
        relativePath: "projects/sample/Vendor",
        kind: .directory
    ).isEmpty)
    #expect(try matcher.matchingRules(
        relativePath: "projects/sample/Target",
        kind: .directory,
        caseSensitive: false
    ).map(\.id.rawValue) == [
        "project-java-maven-target",
        "project-rust-target",
    ])
    #expect(throws: RuleCatalogError.invalidPattern) {
        _ = try matcher.matchingRules(
            relativePath: "../sample/target",
            kind: .directory
        )
    }
    #expect(throws: RuleCatalogError.invalidPattern) {
        _ = try matcher.matchingRules(
            relativePath: Array(repeating: "segment", count: 257)
                .joined(separator: "/"),
            kind: .directory
        )
    }

    var exclusionSource = try catalogObject()
    var exclusionRules = try rules(&exclusionSource)
    var exclusionMatch = try #require(
        exclusionRules[0]["match"] as? [String: Any]
    )
    exclusionMatch["pathPattern"] = "workspace/**"
    exclusionRules[0]["match"] = exclusionMatch
    exclusionSource["rules"] = exclusionRules
    var exclusionOverlay = try overlayTestObject()
    var exclusionEntries = try #require(
        exclusionOverlay["overlays"] as? [[String: Any]]
    )
    exclusionEntries[0]["addExclusions"] = ["workspace/keep/**"]
    exclusionOverlay["overlays"] = exclusionEntries
    let overlaid = try RuleSourceCompiler().compile(
        catalogData: JSONSerialization.data(
            withJSONObject: exclusionSource,
            options: [.sortedKeys]
        ),
        overlayData: JSONSerialization.data(
            withJSONObject: exclusionOverlay,
            options: [.sortedKeys]
        )
    )
    let overlaidMatcher = RuleCatalogMatcher(catalog: overlaid.catalog)
    #expect(try overlaidMatcher.matchingRules(
        relativePath: "workspace/cache",
        kind: .directory
    ).map(\.id.rawValue) == ["fixture-cache"])
    #expect(try overlaidMatcher.matchingRules(
        relativePath: "workspace/keep/cache",
        kind: .directory
    ).isEmpty)
}

@Test
func cumulativeCatalogMatchingBenchmarkStaysBounded() throws {
    let artifact = try RuleSourceCompiler().compile(
        catalogSources: [
            try builtInRuleFixture("protected-v1"),
            try builtInRuleFixture("project-artifacts-v1"),
        ],
        catalogVersion: try DomainToken(
            validating: "builtin-project-artifacts-v1"
        )
    )
    let matcher = RuleCatalogMatcher(catalog: artifact.catalog)
    let projectPaths = try projectArtifactFixture().cases.map(\.path)
    let anonymousPaths = try anonymousDeveloperTreePaths()
    let paths = projectPaths + anonymousPaths
    let clock = ContinuousClock()
    var matchCount = 0

    let duration = try clock.measure {
        for _ in 0..<250 {
            for path in paths {
                matchCount += try matcher.matchingRules(
                    relativePath: path,
                    kind: .directory
                ).count
            }
        }
    }

    #expect(matchCount > 0)
    #expect(duration < .seconds(2))
}

@Test
func projectArtifactBehaviorComparisonRemainsConservativeAndCleanRoom() throws {
    let artifact = try RuleSourceCompiler().compile(
        catalogData: try builtInRuleFixture("project-artifacts-v1")
    )
    let data = try ruleFixture("project-artifact-behavior-comparison")
    let root = try #require(
        JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
    #expect(try #require(root["schemaVersion"] as? Int) == 1)
    let sources = try #require(root["sources"] as? [[String: Any]])
    let cases = try #require(root["cases"] as? [[String: Any]])
    let sourceProjects = Set(try sources.map {
        try #require($0["project"] as? String)
    })
    let rulesByID = Dictionary(
        uniqueKeysWithValues: artifact.catalog.rules.map {
            ($0.id.rawValue, $0)
        }
    )

    #expect(sourceProjects == ["ClearDisk", "Mole", "kondo"])
    #expect(try sources.allSatisfy {
        try #require($0["usage"] as? String) == "behaviorReferenceOnly"
            && !(try #require($0["revision"] as? String)).isEmpty
            && !(try #require($0["license"] as? String)).isEmpty
    })
    for comparison in cases {
        let sourceProject = try #require(
            comparison["sourceProject"] as? String
        )
        let ruleID = try #require(comparison["ruleID"] as? String)
        let outcome = try #require(
            comparison["stornautOutcome"] as? String
        )
        let difference = try #require(
            comparison["relativeDifference"] as? String
        )
        let missingKeys = Set(try #require(
            comparison["missingKeys"] as? [String]
        ))
        let rule = try #require(rulesByID[ruleID])
        let requirements = Set(
            rule.requiredEvidenceKeys.map(\.rawValue)
                + rule.requiredActivityKeys.map(\.rawValue)
        )

        #expect(sourceProjects.contains(sourceProject))
        #expect(["noCandidate", "reviewBlocked"].contains(outcome))
        #expect(!difference.isEmpty)
        #expect(missingKeys.isSubset(of: requirements))
        #expect(outcome == "noCandidate" || !missingKeys.isEmpty)
    }
}

@Test
func packageCacheCatalogCoversApprovedFamiliesWithOwnershipGates() throws {
    let artifact = try RuleSourceCompiler().compile(
        catalogSources: [
            try builtInRuleFixture("protected-v1"),
            try builtInRuleFixture("project-artifacts-v1"),
            try builtInRuleFixture("package-build-caches-v1"),
        ],
        catalogVersion: try DomainToken(
            validating: "builtin-package-build-caches-v1"
        )
    )
    let cacheRules = artifact.catalog.rules.filter {
        $0.category == .packageAndBuildCaches
    }
    let expectedIDs = [
        "cache-bun-install",
        "cache-cargo-registry",
        "cache-conda-anaconda-packages",
        "cache-conda-miniconda-packages",
        "cache-conda-packages",
        "cache-go-build",
        "cache-go-modules",
        "cache-gradle-modules",
        "cache-homebrew-downloads",
        "cache-maven-local-repository",
        "cache-npm-content",
        "cache-pip",
        "cache-pnpm-home-store",
        "cache-pnpm-store",
        "cache-pnpm-xdg-store",
        "cache-uv",
        "cache-yarn-global",
    ]

    #expect(cacheRules.map(\.id.rawValue) == expectedIDs)
    #expect(artifact.catalog.rules.count == 55)
    #expect(artifact.manifest.sourceCatalogVersions == [
        "package-build-caches-v1",
        "project-artifacts-v1",
        "protected-v1",
    ])
    for rule in cacheRules {
        let evidence = Set(rule.requiredEvidenceKeys.map(\.rawValue))
        #expect(rule.disposition == .reviewRecommended)
        #expect(rule.confidenceRequirement == .high)
        #expect(rule.recommendedAction == .moveToTrash)
        #expect(rule.recovery != nil)
        #expect(evidence.contains("evidence.cache.layout"))
        #expect(evidence.contains("evidence.cache.reclaimable"))
        #expect(evidence.contains("evidence.cache.tool-owned"))
        #expect(evidence.contains("evidence.scope.user-owned"))
        #expect(
            rule.requiredActivityKeys.map(\.rawValue).contains(
                "activity.process.inactive"
            )
        )
        #expect(rule.fixtureIDs.count == 4)
        #expect(rule.provenance.sources.count >= 2)
    }
}

@Test
func packageCacheFixturesExcludeRuntimeEnvironmentSourceAndConfiguration() throws {
    let artifact = try RuleSourceCompiler().compile(
        catalogData: try builtInRuleFixture("package-build-caches-v1")
    )
    let fixture = try packageCacheFixture()
    let casesByRule = Dictionary(grouping: fixture.cases, by: \.ruleID)

    for rule in artifact.catalog.rules {
        let cases = try #require(casesByRule[rule.id.rawValue])
        let positive = try #require(cases.first { $0.kind == "positive" })
        let active = try #require(cases.first { $0.kind == "active" })
        let lookalikes = cases.filter { $0.kind == "lookalike" }
        let requirements = Set(
            rule.requiredEvidenceKeys.map(\.rawValue)
                + rule.requiredActivityKeys.map(\.rawValue)
        )

        #expect(lookalikes.count == 2)
        #expect(rulePattern(rule.match, protects: positive.path))
        #expect(rulePattern(rule.match, protects: active.path))
        #expect(Set(positive.presentKeys) == requirements)
        #expect(positive.missingKeys.isEmpty)
        #expect(
            Set(active.presentKeys).union(active.missingKeys) == requirements
        )
        #expect(Set(active.missingKeys) == ["activity.process.inactive"])
        #expect(lookalikes.allSatisfy {
            !rulePattern(rule.match, protects: $0.path)
        })
        #expect(
            Set(lookalikes.map(\.lookalikeType)) == [
                "configuration",
                "runtimeEnvironmentOrSource",
            ]
        )
    }
}

@Test
func generatedManifestMakesEveryRuleProvenanceAndFixtureReviewable() throws {
    let artifact = try RuleSourceCompiler().compile(
        catalogSources: [
            try builtInRuleFixture("protected-v1"),
            try builtInRuleFixture("project-artifacts-v1"),
            try builtInRuleFixture("package-build-caches-v1"),
        ],
        catalogVersion: try DomainToken(
            validating: "builtin-package-build-caches-v1"
        )
    )

    #expect(artifact.manifest.schemaVersion == 2)
    #expect(artifact.manifest.rules.count == artifact.catalog.rules.count)
    #expect(
        artifact.manifest.rules.map(\.ruleID)
            == artifact.catalog.rules.map(\.id)
    )
    #expect(
        artifact.manifest.provenanceSourceCount
            == artifact.manifest.rules.reduce(0) {
                $0 + $1.provenance.sources.count
            }
    )
    #expect(
        artifact.manifest.fixtureCount
            == Set(artifact.manifest.rules.flatMap(\.fixtureIDs)).count
    )
    for entry in artifact.manifest.rules {
        #expect(!entry.provenance.sources.isEmpty)
        #expect(entry.provenance.independentlyVerified)
        #expect(entry.provenance.sources.allSatisfy {
            $0.url.scheme == "https"
                && !$0.revision.rawValue.isEmpty
                && !$0.license.rawValue.isEmpty
        })
        #expect(!entry.fixtureIDs.isEmpty)
        #expect(!entry.rationaleKey.rawValue.isEmpty)
    }
}

@Test
func packageCacheBehaviorComparisonRemainsConservativeAndCleanRoom() throws {
    let artifact = try RuleSourceCompiler().compile(
        catalogData: try builtInRuleFixture("package-build-caches-v1")
    )
    let data = try ruleFixture("package-cache-behavior-comparison")
    let root = try #require(
        JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
    #expect(try #require(root["schemaVersion"] as? Int) == 1)
    let sources = try #require(root["sources"] as? [[String: Any]])
    let cases = try #require(root["cases"] as? [[String: Any]])
    let sourceProjects = Set(try sources.map {
        try #require($0["project"] as? String)
    })
    let rulesByID = Dictionary(
        uniqueKeysWithValues: artifact.catalog.rules.map {
            ($0.id.rawValue, $0)
        }
    )

    #expect(sourceProjects == ["ClearDisk", "Mole", "kondo"])
    for comparison in cases {
        let ruleID = try #require(comparison["ruleID"] as? String)
        let outcome = try #require(
            comparison["stornautOutcome"] as? String
        )
        let missing = Set(try #require(
            comparison["missingKeys"] as? [String]
        ))
        let rule = try #require(rulesByID[ruleID])
        let requirements = Set(
            rule.requiredEvidenceKeys.map(\.rawValue)
                + rule.requiredActivityKeys.map(\.rawValue)
        )

        #expect(["noCandidate", "reviewBlocked"].contains(outcome))
        #expect(missing.isSubset(of: requirements))
        #expect(outcome == "noCandidate" || !missing.isEmpty)
    }
}

@Test
func completeCacheCatalogMatchingBenchmarkStaysBounded() throws {
    let artifact = try RuleSourceCompiler().compile(
        catalogSources: [
            try builtInRuleFixture("protected-v1"),
            try builtInRuleFixture("project-artifacts-v1"),
            try builtInRuleFixture("package-build-caches-v1"),
        ],
        catalogVersion: try DomainToken(
            validating: "builtin-package-build-caches-v1"
        )
    )
    let matcher = RuleCatalogMatcher(catalog: artifact.catalog)
    let paths = try packageCacheFixture().cases.map(\.path)
        + projectArtifactFixture().cases.map(\.path)
        + anonymousDeveloperTreePaths()
    let clock = ContinuousClock()
    var matchCount = 0

    let duration = try clock.measure {
        for _ in 0..<200 {
            for path in paths {
                matchCount += try matcher.matchingRules(
                    relativePath: path,
                    kind: .directory
                ).count
            }
        }
    }

    #expect(matchCount > 0)
    #expect(duration < .seconds(2))
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

private struct ProjectArtifactFixture: Decodable {
    let schemaVersion: Int
    let cases: [ProjectArtifactFixtureCase]
}

private struct ProjectArtifactFixtureCase: Decodable {
    let id: String
    let ruleID: String
    let kind: String
    let path: String
    let presentKeys: [String]
    let missingKeys: [String]
}

private struct PackageCacheFixture: Decodable {
    let schemaVersion: Int
    let cases: [PackageCacheFixtureCase]
}

private struct PackageCacheFixtureCase: Decodable {
    let id: String
    let ruleID: String
    let kind: String
    let lookalikeType: String?
    let path: String
    let presentKeys: [String]
    let missingKeys: [String]
}

private func packageCacheFixture() throws -> PackageCacheFixture {
    let fixture = try JSONDecoder().decode(
        PackageCacheFixture.self,
        from: ruleFixture("package-cache-cases")
    )
    #expect(fixture.schemaVersion == 1)
    #expect(Set(fixture.cases.map(\.id)).count == fixture.cases.count)
    return fixture
}

private func projectArtifactFixture() throws -> ProjectArtifactFixture {
    let fixture = try JSONDecoder().decode(
        ProjectArtifactFixture.self,
        from: ruleFixture("project-artifact-cases")
    )
    #expect(fixture.schemaVersion == 1)
    #expect(Set(fixture.cases.map(\.id)).count == fixture.cases.count)
    return fixture
}

private func anonymousDeveloperTreePaths() throws -> [String] {
    let data = try Data(
        contentsOf: repositoryRoot.appending(
            path: "Tests/Fixtures/QuickScan/anonymous-developer-tree.json"
        )
    )
    let root = try #require(
        JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
    let snapshots = try #require(root["snapshots"] as? [[String: Any]])
    return try snapshots.map {
        try #require($0["relativePath"] as? String)
    }
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
