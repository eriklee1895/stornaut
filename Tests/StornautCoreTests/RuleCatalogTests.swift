import Foundation
import Testing
@testable import StornautCore

@Test
func protectedRuleRequiresCriticalRisk() throws {
    #expect(throws: RuleCatalogError.invalidRule) {
        _ = try makeProtectedRule(risk: .high)
    }
}

@Test
func protectedRuleRoundTripsItsRationale() throws {
    let rule = try makeProtectedRule(risk: .critical)
    let catalog = try RuleCatalog(
        catalogVersion: try #require(DomainToken(rawValue: "protected-v1")),
        rules: [rule]
    )

    let decoded = try DomainJSON.decode(
        RuleCatalog.self,
        from: DomainJSON.encode(catalog)
    )

    #expect(decoded == catalog)
    #expect(
        decoded.rules.first?.rationaleKey.rawValue
            == "rationale.protected.credentials"
    )
}

@Test
func permanentDenylistProtectsCatalogFixtureCasesIndependently() throws {
    let fixture = try protectedPathFixture()
    let homeURL = URL(
        filePath: "/Users/stornaut-fixture",
        directoryHint: .isDirectory
    )
    let denylist = SensitivePathDenylist(homeDirectoryURL: homeURL)

    for fixtureCase in fixture.cases {
        let url = fixtureCase.scope == .absolute
            ? URL(filePath: fixtureCase.path)
            : homeURL.appending(path: fixtureCase.path)
        #expect(
            denylist.evaluate(url) == fixtureCase.expected.decision,
            "Unexpected denylist result for \(fixtureCase.id)"
        )
    }
}

@Test
func permanentDenylistResolvesSymlinkIntoSensitiveDirectory() throws {
    let rootURL = FileManager.default.temporaryDirectory.appending(
        path: "stornaut-protected-rule-\(UUID().uuidString)"
    )
    let homeURL = rootURL.appending(path: "home")
    let mailURL = homeURL.appending(path: "Library/Mail")
    let linkURL = homeURL.appending(path: "Projects/mail-link")
    let messageURL = mailURL.appending(path: "message.emlx")
    defer { try? FileManager.default.removeItem(at: rootURL) }
    try FileManager.default.createDirectory(
        at: mailURL,
        withIntermediateDirectories: true
    )
    try Data("fixture".utf8).write(to: messageURL)
    try FileManager.default.createDirectory(
        at: linkURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try FileManager.default.createSymbolicLink(
        at: linkURL,
        withDestinationURL: mailURL
    )

    let decision = SensitivePathDenylist(
        homeDirectoryURL: homeURL
    ).evaluate(linkURL.appending(path: messageURL.lastPathComponent))

    #expect(decision == .denied(.sensitiveDirectory))
}

@Test
func canonicalPolicyRejectsRootBoundariesWithoutRuleCatalog() {
    let homeURL = URL(
        filePath: "/Users/stornaut-fixture",
        directoryHint: .isDirectory
    )
    let mountURL = URL(
        filePath: "/Volumes/StornautFixture",
        directoryHint: .isDirectory
    )
    let policy = CanonicalPathPolicy(
        homeDirectoryURL: homeURL,
        isMountRoot: { $0.standardizedFileURL == mountURL.standardizedFileURL }
    )

    #expect(
        policy.evaluate(
            requestedURL: URL(filePath: "/"),
            allowedRoots: [URL(filePath: "/")]
        ) == .denied(.filesystemRoot)
    )
    #expect(
        policy.evaluate(
            requestedURL: homeURL,
            allowedRoots: [homeURL]
        ) == .denied(.homeDirectory)
    )
    #expect(
        policy.evaluate(
            requestedURL: mountURL,
            allowedRoots: [mountURL]
        ) == .denied(.mountRoot)
    )
}

@Test
func reclaimRecommendationRequiresRecoveryEvidenceAndActivity() throws {
    let base = try makeReviewRule()

    for missing in ["recovery", "evidence", "activity"] {
        #expect(throws: RuleCatalogError.invalidRule) {
            _ = try CompiledRule(
                id: base.id,
                match: base.match,
                producer: base.producer,
                rationaleKey: base.rationaleKey,
                category: base.category,
                disposition: base.disposition,
                risk: base.risk,
                confidenceRequirement: base.confidenceRequirement,
                veto: base.veto,
                requiredEvidenceKeys: missing == "evidence"
                    ? []
                    : base.requiredEvidenceKeys,
                requiredActivityKeys: missing == "activity"
                    ? []
                    : base.requiredActivityKeys,
                recovery: missing == "recovery" ? nil : base.recovery,
                recommendedAction: .moveToTrash,
                provenance: base.provenance,
                fixtureIDs: base.fixtureIDs
            )
        }
    }
}

private func makeProtectedRule(risk: RiskLevel) throws -> CompiledRule {
    let source = try RuleProvenanceSource(
        project: try #require(DomainLabel(rawValue: "Stornaut observation")),
        url: try #require(
            URL(string: "https://example.invalid/protected-credentials")
        ),
        revision: try #require(DomainToken(rawValue: "fixture-v1")),
        license: try #require(DomainToken(rawValue: "MIT")),
        usage: .independentObservation
    )
    let provenance = try RuleProvenance(
        sources: [source],
        independentlyVerified: true,
        verifiedAt: try RuleVerificationDate(
            validating: "2026-08-09"
        )
    )
    return try CompiledRule(
        id: try RuleID(validating: "protected-credentials"),
        match: RuleMatch(
            pathPattern: try RulePathPattern(validating: ".ssh"),
            expectedKind: .directory
        ),
        producer: try #require(DomainLabel(rawValue: "Credential stores")),
        rationaleKey: try DomainToken(
            validating: "rationale.protected.credentials"
        ),
        category: .protected,
        disposition: .protected,
        risk: risk,
        confidenceRequirement: .high,
        veto: true,
        requiredEvidenceKeys: [],
        requiredActivityKeys: [],
        recovery: nil,
        recommendedAction: .none,
        provenance: provenance,
        fixtureIDs: [
            try #require(
                DomainToken(rawValue: "protected-credentials-positive")
            ),
            try #require(
                DomainToken(rawValue: "protected-credentials-lookalike")
            ),
        ]
    )
}

private func makeReviewRule() throws -> CompiledRule {
    let protected = try makeProtectedRule(risk: .critical)
    return try CompiledRule(
        id: try RuleID(validating: "project-node-modules"),
        match: RuleMatch(
            pathPattern: try RulePathPattern(
                validating: "**/node_modules"
            ),
            expectedKind: .directory
        ),
        producer: try DomainLabel(validating: "Node package managers"),
        rationaleKey: try DomainToken(
            validating: "rationale.project.node-dependencies"
        ),
        category: .rebuildableProjectArtifacts,
        disposition: .reviewRecommended,
        risk: .medium,
        confidenceRequirement: .high,
        veto: false,
        requiredEvidenceKeys: [
            try DomainToken(validating: "evidence.project.manifest"),
        ],
        requiredActivityKeys: [
            try DomainToken(validating: "activity.git.clean"),
        ],
        recovery: RecoveryGuidance(
            methodKey: try DomainToken(
                validating: "recovery.project.package-install"
            ),
            cost: .medium
        ),
        recommendedAction: .moveToTrash,
        provenance: protected.provenance,
        fixtureIDs: [
            try DomainToken(validating: "project-node-positive"),
            try DomainToken(validating: "project-node-active"),
        ]
    )
}

private struct ProtectedPathFixture: Decodable {
    let schemaVersion: Int
    let cases: [ProtectedPathFixtureCase]
}

private struct ProtectedPathFixtureCase: Decodable {
    let id: String
    let scope: ProtectedPathFixtureScope
    let path: String
    let expected: ProtectedPathFixtureExpectation
}

private enum ProtectedPathFixtureScope: String, Decodable {
    case absolute
    case homeRelative
}

private enum ProtectedPathFixtureExpectation: String, Decodable {
    case allowed
    case secretFile
    case sensitiveDirectory

    var decision: SensitivePathDecision {
        switch self {
        case .allowed:
            .allowed
        case .secretFile:
            .denied(.secretFile)
        case .sensitiveDirectory:
            .denied(.sensitiveDirectory)
        }
    }
}

private func protectedPathFixture() throws -> ProtectedPathFixture {
    let root = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let data = try Data(
        contentsOf: root.appending(
            path: "Tests/Fixtures/Rules/protected-path-cases.json"
        )
    )
    let fixture = try JSONDecoder().decode(
        ProtectedPathFixture.self,
        from: data
    )
    #expect(fixture.schemaVersion == 1)
    #expect(Set(fixture.cases.map(\.id)).count == fixture.cases.count)
    return fixture
}
