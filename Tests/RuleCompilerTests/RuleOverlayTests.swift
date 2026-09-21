import Foundation
import Testing
@testable import RuleCompilerKit
@testable import StornautCore

@Test
func overlayOnlyMakesRulesMoreConservative() throws {
    let artifact = try RuleSourceCompiler().compile(
        catalogData: try ruleOverlayFixture("minimal-catalog"),
        overlayData: try ruleOverlayFixture("conservative-overlay")
    )
    let cache = try #require(
        artifact.catalog.rules.first { $0.id.rawValue == "fixture-cache" }
    )
    #expect(cache.risk == .high)
    #expect(cache.disposition == .reviewRecommended)
    #expect(cache.veto == false)
    #expect(cache.requiredEvidenceKeys.map(\.rawValue) == [
        "metadata.allocated",
        "user.confirmed.scope",
    ])
    #expect(cache.requiredActivityKeys.map(\.rawValue) == [
        "activity.git.clean",
        "activity.process.inactive",
    ])
    #expect(cache.excludedPatterns.map(\.rawValue) == [
        "**/.fixture-cache/keep",
    ])
    #expect(cache.appliedOverlayIDs.map(\.rawValue) == [
        "overlay-fixture-strict",
    ])

    let protected = try #require(
        artifact.catalog.rules.first { $0.id.rawValue == "fixture-review" }
    )
    #expect(protected.category == .protected)
    #expect(protected.disposition == .protected)
    #expect(protected.risk == .critical)
    #expect(protected.veto)
    #expect(protected.recommendedAction == .none)
}

@Test
func overlayRejectsDowngradePromotionUnknownFieldsAndMissingTargets() throws {
    let catalog = try ruleOverlayFixture("minimal-catalog")
    let overlay = try overlayObject()

    for mutation in ["risk", "ready", "target", "forceFalse"] {
        #expect(throws: RuleCompilerError.self) {
            var changed = overlay
            var entries = try overlayEntries(&changed)
            switch mutation {
            case "risk":
                entries[1]["riskOverride"] = "low"
                entries[1]["dispositionOverride"] = "reviewRecommended"
                entries[1]["forceProtected"] = false
            case "ready":
                entries[0]["dispositionOverride"] = "readyToReclaim"
            case "target":
                entries[0]["ruleID"] = "missing-rule"
            default:
                entries[1]["forceProtected"] = false
                entries[1]["dispositionOverride"] = "protected"
            }
            changed["overlays"] = entries
            _ = try compileOverlay(catalog: catalog, overlay: changed)
        }
    }

    #expect(throws: RuleCompilerError.self) {
        var changed = overlay
        var entries = try overlayEntries(&changed)
        entries[0]["recommendedAction"] = "moveToTrash"
        changed["overlays"] = entries
        _ = try compileOverlay(catalog: catalog, overlay: changed)
    }
    #expect(throws: RuleCompilerError.self) {
        var protectedCatalog = try overlayCatalogObject()
        var protectedRules = try #require(
            protectedCatalog["rules"] as? [[String: Any]]
        )
        protectedRules[1]["category"] = "protected"
        protectedRules[1]["disposition"] = "protected"
        protectedRules[1]["risk"] = "critical"
        protectedRules[1]["veto"] = true
        protectedRules[1]["recovery"] = NSNull()
        protectedRules[1]["recommendedAction"] = "none"
        protectedCatalog["rules"] = protectedRules
        var changed = overlay
        let entries: [[String: Any]] = [
            [
                "id": "overlay-protected-weaken",
                "ruleID": "fixture-review",
                "addExclusions": [],
                "addRequiredEvidenceKeys": [],
                "addRequiredActivityKeys": [],
                "riskOverride": "high",
                "dispositionOverride": "reviewRecommended",
                "forceProtected": false,
            ],
        ]
        changed["catalogVersion"] = "fixture-overlay-v2"
        changed["overlays"] = entries
        _ = try compileOverlay(
            catalog: JSONSerialization.data(
                withJSONObject: protectedCatalog,
                options: [.sortedKeys]
            ),
            overlay: changed
        )
    }
    #expect(throws: RuleCompilerError.self) {
        var changed = overlay
        var entries = try overlayEntries(&changed)
        entries.append(entries[0])
        changed["overlays"] = entries
        _ = try compileOverlay(catalog: catalog, overlay: changed)
    }
}

@Test
func overlayCompilationIsDeterministic() throws {
    let catalog = try ruleOverlayFixture("minimal-catalog")
    let overlay = try ruleOverlayFixture("conservative-overlay")

    let first = try RuleSourceCompiler().compile(
        catalogData: catalog,
        overlayData: overlay
    )
    let second = try RuleSourceCompiler().compile(
        catalogData: catalog,
        overlayData: overlay
    )

    #expect(first.data == second.data)
    #expect(first.sha256 == second.sha256)
}

@Test
func multipleOverlaysForOneRuleApplyInStableIDOrder() throws {
    let catalog = try ruleOverlayFixture("minimal-catalog")
    var overlay = try overlayObject()
    var entries = try overlayEntries(&overlay)
    entries.append(
        [
            "id": "overlay-fixture-extra",
            "ruleID": "fixture-cache",
            "addExclusions": ["**/.fixture-cache/extra"],
            "addRequiredEvidenceKeys": ["evidence.extra"],
            "addRequiredActivityKeys": [],
            "riskOverride": NSNull(),
            "dispositionOverride": NSNull(),
            "forceProtected": false,
        ]
    )
    overlay["overlays"] = Array(entries.reversed())

    let artifact = try compileOverlay(catalog: catalog, overlay: overlay)
    let rule = try #require(
        artifact.catalog.rules.first { $0.id.rawValue == "fixture-cache" }
    )

    #expect(rule.appliedOverlayIDs.map(\.rawValue) == [
        "overlay-fixture-extra",
        "overlay-fixture-strict",
    ])
    #expect(rule.requiredEvidenceKeys.map(\.rawValue) == [
        "evidence.extra",
        "metadata.allocated",
        "user.confirmed.scope",
    ])
}

@Test
func addOnlyOverlayCanExtendAnAlreadyProtectedRule() throws {
    let catalog = try ruleOverlayFixture("minimal-catalog")
    var overlay = try overlayObject()
    var entries = try overlayEntries(&overlay)
    entries.append(
        [
            "id": "overlay-fixture-protected-extra",
            "ruleID": "fixture-review",
            "addExclusions": ["projects/*/derived/keep"],
            "addRequiredEvidenceKeys": ["user.confirmed.keep"],
            "addRequiredActivityKeys": [],
            "riskOverride": NSNull(),
            "dispositionOverride": NSNull(),
            "forceProtected": false,
        ]
    )
    overlay["overlays"] = entries

    let artifact = try compileOverlay(catalog: catalog, overlay: overlay)
    let rule = try #require(
        artifact.catalog.rules.first { $0.id.rawValue == "fixture-review" }
    )

    #expect(rule.veto)
    #expect(rule.disposition == .protected)
    #expect(rule.excludedPatterns.map(\.rawValue) == [
        "projects/*/derived/keep",
    ])
    #expect(rule.requiredEvidenceKeys.map(\.rawValue) == [
        "metadata.allocated",
        "user.confirmed.keep",
        "user.keep-decision",
    ])
}

private func ruleOverlayFixture(_ name: String) throws -> Data {
    try Data(
        contentsOf: ruleOverlayRepositoryRoot.appending(
            path: "Tests/Fixtures/Rules/\(name).json"
        )
    )
}

private func overlayObject() throws -> [String: Any] {
    try #require(
        JSONSerialization.jsonObject(
            with: try ruleOverlayFixture("conservative-overlay")
        ) as? [String: Any]
    )
}

private func overlayCatalogObject() throws -> [String: Any] {
    try #require(
        JSONSerialization.jsonObject(
            with: ruleOverlayFixture("minimal-catalog")
        ) as? [String: Any]
    )
}

private func overlayEntries(
    _ object: inout [String: Any]
) throws -> [[String: Any]] {
    try #require(object["overlays"] as? [[String: Any]])
}

private func compileOverlay(
    catalog: Data,
    overlay: [String: Any]
) throws -> CompiledRuleArtifact {
    try RuleSourceCompiler().compile(
        catalogData: catalog,
        overlayData: JSONSerialization.data(
            withJSONObject: overlay,
            options: [.sortedKeys]
        )
    )
}

private var ruleOverlayRepositoryRoot: URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
