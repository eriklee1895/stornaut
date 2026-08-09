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

private func ruleFixture(_ name: String) throws -> Data {
    try Data(
        contentsOf: repositoryRoot.appending(
            path: "Tests/Fixtures/Rules/\(name).json"
        )
    )
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
