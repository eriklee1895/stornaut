import Foundation
import Testing
@testable import RuleCompilerKit
@testable import StornautCore

@Test
func executionProfileCompilerProducesClosedDeterministicArtifact() throws {
    let catalog = try phaseCRuleCatalog()
    let source = try executionProfileSource()
    let first = try ExecutionProfileCompiler().compile(
        profileData: source,
        ruleCatalog: catalog
    )
    var object = try #require(
        JSONSerialization.jsonObject(with: source) as? [String: Any]
    )
    object["profiles"] = Array(try #require(
        object["profiles"] as? [[String: Any]]
    ).reversed())
    let reordered = try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys]
    )
    let second = try ExecutionProfileCompiler().compile(
        profileData: reordered,
        ruleCatalog: catalog
    )

    #expect(first.data == second.data)
    #expect(first.sha256 == second.sha256)
    #expect(first.sha256.utf8.count == 64)
    #expect(first.catalog.catalogVersion.rawValue == "safe-execution-v1")
    #expect(
        first.catalog.ruleCatalogVersion.rawValue
            == "builtin-runtime-tool-residue-v2"
    )
    #expect(first.catalog.profiles.map(\.id.rawValue) == [
        "phase-c.go-build-cache-v1",
        "phase-c.npm-cacache-v1",
        "phase-c.pip-cache-v1",
    ])
    #expect(first.catalog.profiles.map(\.ruleID.rawValue) == [
        "cache-go-build",
        "cache-npm-content",
        "cache-pip",
    ])
    #expect(
        first.catalog.profiles.filter {
            $0.defaultSuggestion == .readyWhenEligible
        }.map(\.ruleID.rawValue) == [
            "cache-npm-content",
            "cache-pip",
        ]
    )
    #expect(first.manifest.profileCount == 3)
    #expect(first.manifest.ruleCatalogVersion
        == "builtin-runtime-tool-residue-v2")

    let output = String(decoding: first.data, as: UTF8.self).lowercased()
    for forbidden in [
        "command",
        "executable",
        "arguments",
        "registeredaction",
        "cache-uv",
        "/users/",
    ] {
        #expect(!output.contains(forbidden))
    }
}

@Test
func executionProfileCompilerRejectsUnapprovedOrUnsafeProfileShape()
    throws
{
    let catalog = try phaseCRuleCatalog(includeUV: true)
    let source = try executionProfileObject()

    for path in [
        ".npm/*",
        "../.npm/_cacache",
        "/Users/example/.npm/_cacache",
        ".npm/_cacache/file",
    ] {
        var changed = source
        var profiles = try profileEntries(&changed)
        profiles[1]["relativePath"] = path
        changed["profiles"] = profiles
        #expect(throws: RuleCompilerError.self) {
            _ = try compileExecutionProfiles(changed, catalog: catalog)
        }
    }

    #expect(throws: RuleCompilerError.self) {
        var changed = source
        var profiles = try profileEntries(&changed)
        profiles[1]["ruleID"] = "cache-uv"
        changed["profiles"] = profiles
        _ = try compileExecutionProfiles(changed, catalog: catalog)
    }
    #expect(throws: RuleCompilerError.self) {
        var changed = source
        var profiles = try profileEntries(&changed)
        profiles[0]["defaultSuggestion"] = "readyWhenEligible"
        changed["profiles"] = profiles
        _ = try compileExecutionProfiles(changed, catalog: catalog)
    }
    #expect(throws: RuleCompilerError.self) {
        var changed = source
        var profiles = try profileEntries(&changed)
        profiles[2]["expectedKind"] = "regularFile"
        changed["profiles"] = profiles
        _ = try compileExecutionProfiles(changed, catalog: catalog)
    }
}

@Test
func executionProfileCompilerRejectsOpenResolverAndProcessMatching()
    throws
{
    let catalog = try phaseCRuleCatalog()
    let source = try executionProfileObject()

    #expect(throws: RuleCompilerError.self) {
        var changed = source
        var profiles = try profileEntries(&changed)
        var bindings = try #require(
            profiles[1]["resolverBindings"] as? [[String: Any]]
        )
        bindings[0]["resolver"] = "pathNameGuess"
        profiles[1]["resolverBindings"] = bindings
        changed["profiles"] = profiles
        _ = try compileExecutionProfiles(changed, catalog: catalog)
    }
    #expect(throws: RuleCompilerError.self) {
        var changed = source
        var profiles = try profileEntries(&changed)
        var subjects = try #require(
            profiles[2]["processSubjects"] as? [String: Any]
        )
        subjects["versionedFamilies"] = ["arbitraryRegex"]
        profiles[2]["processSubjects"] = subjects
        changed["profiles"] = profiles
        _ = try compileExecutionProfiles(changed, catalog: catalog)
    }
    #expect(throws: RuleCompilerError.self) {
        var changed = source
        var profiles = try profileEntries(&changed)
        var subjects = try #require(
            profiles[1]["processSubjects"] as? [String: Any]
        )
        subjects["bundleIdentifiers"] = ["com.example.Any"]
        profiles[1]["processSubjects"] = subjects
        changed["profiles"] = profiles
        _ = try compileExecutionProfiles(changed, catalog: catalog)
    }
    #expect(throws: RuleCompilerError.self) {
        var changed = source
        var profiles = try profileEntries(&changed)
        var subjects = try #require(
            profiles[1]["processSubjects"] as? [String: Any]
        )
        subjects["regex"] = "node.*"
        profiles[1]["processSubjects"] = subjects
        changed["profiles"] = profiles
        _ = try compileExecutionProfiles(changed, catalog: catalog)
    }
}

@Test
func executionProfileCompilerRejectsCrossCatalogAndFixtureDrift() throws {
    let catalog = try phaseCRuleCatalog()
    let source = try executionProfileObject()

    #expect(throws: RuleCompilerError.self) {
        var changed = source
        changed["ruleCatalogVersion"] = "builtin-runtime-tool-residue-v1"
        _ = try compileExecutionProfiles(changed, catalog: catalog)
    }
    #expect(throws: RuleCompilerError.self) {
        var changed = source
        var profiles = try profileEntries(&changed)
        profiles[1]["relativePath"] = "Library/Caches/pip"
        changed["profiles"] = profiles
        _ = try compileExecutionProfiles(changed, catalog: catalog)
    }
    #expect(throws: RuleCompilerError.self) {
        var changed = source
        var profiles = try profileEntries(&changed)
        profiles[1]["fixtureIDs"] = ["cache-npm-content-positive"]
        changed["profiles"] = profiles
        _ = try compileExecutionProfiles(changed, catalog: catalog)
    }
    #expect(throws: RuleCompilerError.self) {
        var changed = source
        var profiles = try profileEntries(&changed)
        profiles.append(profiles[1])
        changed["profiles"] = profiles
        _ = try compileExecutionProfiles(changed, catalog: catalog)
    }
    #expect(throws: RuleCompilerError.self) {
        var changed = source
        changed["unexpected"] = true
        _ = try compileExecutionProfiles(changed, catalog: catalog)
    }
}

@Test
func phaseCTwoRulePromotionPreservesCompleteCoverageMapping() throws {
    let catalog = try phaseCCompleteCatalog()
    let coverageData = try Data(
        contentsOf: executionRepositoryRoot.appending(
            path: "Tests/Fixtures/Rules/fr2-coverage-v1.json"
        )
    )

    let manifest = try RuleCoverageCompiler().compile(
        coverageData: coverageData,
        catalog: catalog
    )

    #expect(
        manifest.catalogVersion == "builtin-runtime-tool-residue-v2"
    )
    #expect(
        Set(manifest.families.flatMap(\.ruleIDs))
            == Set(catalog.rules.map(\.id))
    )
    #expect(
        Set(catalog.rules.filter {
            $0.disposition == .readyToReclaim
        }.map(\.id.rawValue)) == [
            "cache-npm-content",
            "cache-pip",
        ]
    )
}

private func compileExecutionProfiles(
    _ object: [String: Any],
    catalog: RuleCatalog
) throws -> CompiledExecutionProfileArtifact {
    try ExecutionProfileCompiler().compile(
        profileData: JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        ),
        ruleCatalog: catalog
    )
}

private func executionProfileSource() throws -> Data {
    try JSONSerialization.data(
        withJSONObject: executionProfileObject(),
        options: [.sortedKeys]
    )
}

private func executionProfileObject() throws -> [String: Any] {
    [
        "schemaVersion": 1,
        "catalogVersion": "safe-execution-v1",
        "ruleCatalogVersion": "builtin-runtime-tool-residue-v2",
        "profiles": [
            profileObject(
                id: "phase-c.go-build-cache-v1",
                ruleID: "cache-go-build",
                relativePath: "Library/Caches/go-build",
                exactNames: ["go", "compile", "link", "asm", "cgo"],
                versionedFamilies: [],
                defaultSuggestion: "never",
                fixtureIDs: [
                    "cache-go-build-positive",
                    "cache-go-build-active",
                    "cache-go-build-config",
                    "cache-go-build-other",
                ]
            ),
            profileObject(
                id: "phase-c.npm-cacache-v1",
                ruleID: "cache-npm-content",
                relativePath: ".npm/_cacache",
                exactNames: ["node", "npm", "npx", "corepack"],
                versionedFamilies: [],
                defaultSuggestion: "readyWhenEligible",
                fixtureIDs: [
                    "cache-npm-content-positive",
                    "cache-npm-content-active",
                    "cache-npm-content-config",
                    "cache-npm-content-other",
                ]
            ),
            profileObject(
                id: "phase-c.pip-cache-v1",
                ruleID: "cache-pip",
                relativePath: "Library/Caches/pip",
                exactNames: ["python", "pip"],
                versionedFamilies: ["python", "pip"],
                defaultSuggestion: "readyWhenEligible",
                fixtureIDs: [
                    "cache-pip-positive",
                    "cache-pip-active",
                    "cache-pip-config",
                    "cache-pip-other",
                ]
            ),
        ],
    ]
}

private func profileObject(
    id: String,
    ruleID: String,
    relativePath: String,
    exactNames: [String],
    versionedFamilies: [String],
    defaultSuggestion: String,
    fixtureIDs: [String]
) -> [String: Any] {
    [
        "id": id,
        "ruleID": ruleID,
        "relativePath": relativePath,
        "expectedKind": "directory",
        "resolverBindings": [
            [
                "key": "evidence.cache.layout",
                "resolver": "compilerAttested",
            ],
            [
                "key": "evidence.cache.reclaimable",
                "resolver": "compilerAttested",
            ],
            [
                "key": "evidence.cache.tool-owned",
                "resolver": "compilerAttested",
            ],
            [
                "key": "evidence.scope.user-owned",
                "resolver": "currentFilesystem",
            ],
            [
                "key": "activity.process.inactive",
                "resolver": "currentActivity",
            ],
        ],
        "processSubjects": [
            "bundleIdentifiers": [],
            "exactNames": exactNames,
            "versionedFamilies": versionedFamilies,
        ],
        "defaultSuggestion": defaultSuggestion,
        "fixtureIDs": fixtureIDs,
    ]
}

private func profileEntries(
    _ object: inout [String: Any]
) throws -> [[String: Any]] {
    try #require(object["profiles"] as? [[String: Any]])
}

private func phaseCRuleCatalog(includeUV: Bool = false) throws -> RuleCatalog {
    let builtIn = try BuiltInRuleCatalog.load()
    let selected = try [
        phaseCRule(
            try #require(
                builtIn.rules.first {
                    $0.id.rawValue == "cache-go-build"
                }
            ),
            disposition: .reviewRecommended
        ),
        phaseCRule(
            try #require(
                builtIn.rules.first {
                    $0.id.rawValue == "cache-npm-content"
                }
            ),
            disposition: .readyToReclaim
        ),
        phaseCRule(
            try #require(
                builtIn.rules.first {
                    $0.id.rawValue == "cache-pip"
                }
            ),
            disposition: .readyToReclaim
        ),
    ] + (includeUV
        ? [
            try #require(
                builtIn.rules.first {
                    $0.id.rawValue == "cache-uv"
                }
            ),
        ]
        : [])
    return try RuleCatalog(
        catalogVersion: DomainToken(
            rawValue: "builtin-runtime-tool-residue-v2"
        )!,
        rules: selected.sorted { $0.id < $1.id }
    )
}

private func phaseCCompleteCatalog() throws -> RuleCatalog {
    let compiler = RuleSourceCompiler()
    let sources = try [
        "protected-v1",
        "project-artifacts-v1",
        "package-build-caches-v1",
        "runtime-tool-residue-v1",
    ].map {
        try Data(
            contentsOf: executionRepositoryRoot.appending(
                path: "Rules/BuiltIn/\($0).json"
            )
        )
    }
    let promotion = try Data(
        contentsOf: executionRepositoryRoot.appending(
            path: "Rules/BuiltIn/package-build-caches-v2.json"
        )
    )
    return try compiler.compile(
        catalogSources: sources,
        catalogVersion: "builtin-runtime-tool-residue-v2",
        promotionData: promotion
    ).catalog
}

private func phaseCRule(
    _ rule: CompiledRule,
    disposition: ReclaimDisposition
) throws -> CompiledRule {
    try CompiledRule(
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

private var executionRepositoryRoot: URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
