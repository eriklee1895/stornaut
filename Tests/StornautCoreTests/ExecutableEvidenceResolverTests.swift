import Darwin
import Foundation
import Testing
@testable import StornautCore

@Test
func executionProcessSubjectsMatchOnlyClosedExactAndVersionedNames() throws {
    let npm = try executionProfileFixture(ruleID: "cache-npm-content")
        .processSubjects
    let pip = try executionProfileFixture(ruleID: "cache-pip")
        .processSubjects

    for name in ["node", "Node", "npm", "npx", "corepack"] {
        #expect(npm.matches(processName: name))
    }
    for name in ["nodejs", "npm-cli", "my-node", "node20"] {
        #expect(!npm.matches(processName: name))
    }
    for name in [
        "python",
        "python3",
        "python3.12",
        "python3.12.1",
        "Python3.12",
        "pip",
        "Pip3",
        "pip3",
        "pip3.12",
    ] {
        #expect(pip.matches(processName: name))
    }
    for name in [
        "python.",
        "python3.",
        "python3.1234",
        "python3.12.1.4",
        "python-worker",
        "mypip3",
        "pipx",
        "pip3rc1",
        "pip٣",
    ] {
        #expect(!pip.matches(processName: name))
    }
}

@Test
func runningActivityProviderCapturesOnceAndEvaluatesManyProfiles()
    async throws
{
    let source = CountingExecutionActivitySource(
        snapshot: RunningActivitySnapshot(
            applications: [],
            processes: [
                try RunningProcessRecord(
                    name: DomainLabel(validating: "python3.12"),
                    processIdentifier: 71
                ),
            ],
            observedAt: Date(timeIntervalSince1970: 100)
        )
    )
    let provider = RunningActivityProvider(source: source)
    let context = await provider.capture(
        observedAt: Date(timeIntervalSince1970: 101)
    )
    let npm = provider.evaluate(
        subjects: try executionProfileFixture(
            ruleID: "cache-npm-content"
        ).processSubjects,
        context: context
    )
    let pip = provider.evaluate(
        subjects: try executionProfileFixture(
            ruleID: "cache-pip"
        ).processSubjects,
        context: context
    )

    #expect(await source.callCount == 1)
    #expect(npm.status == .available)
    #expect(npm.observation.state == .satisfied)
    #expect(pip.status == .available)
    #expect(pip.observation.state == .contradicted)
    #expect(pip.matchedProcessNames.map(\.rawValue) == ["python3.12"])
}

@Test
func runningActivityProviderKeepsObservedActiveWhenEnumerationIsIncomplete()
    async throws
{
    let source = CountingExecutionActivitySource(
        snapshot: RunningActivitySnapshot(
            applications: [],
            processes: [
                try RunningProcessRecord(
                    name: DomainLabel(validating: "node"),
                    processIdentifier: 72
                ),
            ],
            processStatus: .unavailable(.permissionDenied),
            observedAt: Date(timeIntervalSince1970: 110)
        )
    )
    let provider = RunningActivityProvider(source: source)
    let context = await provider.capture(
        observedAt: Date(timeIntervalSince1970: 111)
    )
    let active = provider.evaluate(
        subjects: try executionProfileFixture(
            ruleID: "cache-npm-content"
        ).processSubjects,
        context: context
    )
    let unknown = provider.evaluate(
        subjects: try executionProfileFixture(
            ruleID: "cache-pip"
        ).processSubjects,
        context: context
    )

    #expect(active.observation.state == .contradicted)
    #expect(active.matchedProcessNames.map(\.rawValue) == ["node"])
    #expect(unknown.status == .unavailable(.permissionDenied))
    #expect(unknown.observation.state == .unavailable)
}

@Test
func executableEvidenceResolverAttestsClosedFactsAndStableFingerprints()
    async throws
{
    let profile = try executionProfileFixture(
        ruleID: "cache-npm-content"
    )
    let rule = try executionRuleFixture(
        ruleID: "cache-npm-content",
        disposition: .readyToReclaim
    )
    let snapshot = try executionSnapshotFixture(
        relativePath: ".npm/_cacache"
    )
    let source = CountingExecutionActivitySource(
        snapshot: RunningActivitySnapshot(
            applications: [],
            processes: [],
            observedAt: Date(timeIntervalSince1970: 120)
        )
    )
    let resolver = ExecutableEvidenceResolver(
        activityProvider: RunningActivityProvider(source: source)
    )
    let context = await resolver.captureActivity(
        observedAt: Date(timeIntervalSince1970: 121)
    )
    let first = try resolver.resolveQuickScan(
        snapshot: snapshot,
        rule: rule,
        profile: profile,
        profileCatalogVersion: DomainToken(
            rawValue: "safe-execution-v1"
        )!,
        activityContext: context,
        evidenceID: executionEvidenceID
    )
    let second = try resolver.resolveQuickScan(
        snapshot: snapshot,
        rule: rule,
        profile: profile,
        profileCatalogVersion: DomainToken(
            rawValue: "safe-execution-v1"
        )!,
        activityContext: context,
        evidenceID: executionEvidenceID
    )

    #expect(await source.callCount == 1)
    #expect(first.satisfiedEvidenceKeys.map(\.rawValue) == [
        "activity.process.inactive",
        "evidence.cache.layout",
        "evidence.cache.reclaimable",
        "evidence.cache.tool-owned",
        "evidence.scope.user-owned",
    ])
    #expect(first.activityObservations.count == 1)
    #expect(first.activityObservations[0].state == .satisfied)
    #expect(first.evidenceRecords.count == 5)
    #expect(Set(first.evidenceRecords.map(\.source.identifier)).count == 5)
    #expect(
        first.evidenceRecords.filter {
            $0.source.kind != .activityProvider
        }.allSatisfy {
            $0.observedAt == snapshot.observedAt
        }
    )
    #expect(
        first.evidenceRecords.first {
            $0.source.kind == .activityProvider
        }?.observedAt == Date(timeIntervalSince1970: 120)
    )
    #expect(
        first.evidenceRecords.first {
            $0.source.identifier.rawValue
                == "execution.ah.nopii.currentFilesystem.evidence.scope.user-owned"
        }?.source.kind == .surveyor
    )
    #expect(first.evidenceFingerprint == second.evidenceFingerprint)
    #expect(first.activityFingerprint == second.activityFingerprint)
    #expect(first == second)

    let changedSubjects = try ExecutionProfile(
        id: profile.id,
        ruleID: profile.ruleID,
        relativePath: profile.relativePath,
        expectedKind: profile.expectedKind,
        resolverBindings: profile.resolverBindings,
        processSubjects: ExecutionProcessSubjects(
            bundleIdentifiers: [],
            exactNames: [
                DomainLabel(rawValue: "node")!,
            ],
            versionedFamilies: []
        ),
        defaultSuggestion: profile.defaultSuggestion,
        fixtureIDs: profile.fixtureIDs
    )
    let changed = try resolver.resolveQuickScan(
        snapshot: snapshot,
        rule: rule,
        profile: changedSubjects,
        profileCatalogVersion: DomainToken(
            rawValue: "safe-execution-v1"
        )!,
        activityContext: context,
        evidenceID: executionEvidenceID
    )
    #expect(changed.activityFingerprint != first.activityFingerprint)
}

@Test
func executableEvidenceResolverFailsClosedForOwnerActivityAndIdentityDrift()
    async throws
{
    let profile = try executionProfileFixture(ruleID: "cache-pip")
    let rule = try executionRuleFixture(
        ruleID: "cache-pip",
        disposition: .readyToReclaim
    )
    let snapshot = try executionSnapshotFixture(
        relativePath: "Library/Caches/pip",
        ownerUserID: getuid() + 1
    )
    let source = CountingExecutionActivitySource(
        snapshot: RunningActivitySnapshot(
            applications: [],
            processes: [
                try RunningProcessRecord(
                    name: DomainLabel(validating: "pip3.12"),
                    processIdentifier: 73
                ),
            ],
            observedAt: Date(timeIntervalSince1970: 130)
        )
    )
    let resolver = ExecutableEvidenceResolver(
        activityProvider: RunningActivityProvider(source: source),
        identityReader: { _ in
            try? executionIdentityFixture(
                inode: 999,
                ownerUserID: getuid()
            )
        }
    )
    let context = await resolver.captureActivity(
        observedAt: Date(timeIntervalSince1970: 131)
    )
    let scan = try resolver.resolveQuickScan(
        snapshot: snapshot,
        rule: rule,
        profile: profile,
        profileCatalogVersion: DomainToken(
            rawValue: "safe-execution-v1"
        )!,
        activityContext: context,
        evidenceID: executionEvidenceID
    )
    let review = try resolver.resolveReview(
        snapshot: snapshot,
        rootURL: URL(filePath: "/Users/fixture"),
        rootIdentity: try executionIdentityFixture(
            inode: 1,
            ownerUserID: getuid()
        ),
        rule: rule,
        profile: profile,
        profileCatalogVersion: DomainToken(
            rawValue: "safe-execution-v1"
        )!,
        activityContext: context,
        evidenceID: executionEvidenceID
    )

    #expect(
        !scan.satisfiedEvidenceKeys.contains {
            $0.rawValue == "evidence.scope.user-owned"
        }
    )
    #expect(
        !scan.satisfiedEvidenceKeys.contains {
            $0.rawValue == "activity.process.inactive"
        }
    )
    #expect(scan.activityObservations[0].state == .contradicted)
    #expect(review.isCurrentIdentity == false)
    #expect(review.isEligible == false)
}

private actor CountingExecutionActivitySource:
    RunningActivitySnapshotting
{
    private let snapshotValue: RunningActivitySnapshot
    private(set) var callCount = 0

    init(snapshot: RunningActivitySnapshot) {
        snapshotValue = snapshot
    }

    func snapshot() async throws -> RunningActivitySnapshot {
        callCount += 1
        return snapshotValue
    }
}

private func executionProfileFixture(
    ruleID: String
) throws -> ExecutionProfile {
    switch ruleID {
    case "cache-npm-content":
        return try ExecutionProfile(
            id: DomainToken(rawValue: "phase-c.npm-cacache-v1")!,
            ruleID: RuleID(rawValue: ruleID)!,
            relativePath: RulePathPattern(rawValue: ".npm/_cacache")!,
            expectedKind: .directory,
            resolverBindings: executionResolverBindings(),
            processSubjects: ExecutionProcessSubjects(
                bundleIdentifiers: [],
                exactNames: try ["node", "npm", "npx", "corepack"].map {
                    try DomainLabel(validating: $0)
                },
                versionedFamilies: []
            ),
            defaultSuggestion: .readyWhenEligible,
            fixtureIDs: try [
                "cache-npm-content-positive",
                "cache-npm-content-active",
                "cache-npm-content-config",
                "cache-npm-content-other",
            ].map(DomainToken.init(validating:))
        )
    case "cache-pip":
        return try ExecutionProfile(
            id: DomainToken(rawValue: "phase-c.pip-cache-v1")!,
            ruleID: RuleID(rawValue: ruleID)!,
            relativePath: RulePathPattern(rawValue: "Library/Caches/pip")!,
            expectedKind: .directory,
            resolverBindings: executionResolverBindings(),
            processSubjects: ExecutionProcessSubjects(
                bundleIdentifiers: [],
                exactNames: try ["python", "pip"].map {
                    try DomainLabel(validating: $0)
                },
                versionedFamilies: [.python, .pip]
            ),
            defaultSuggestion: .readyWhenEligible,
            fixtureIDs: try [
                "cache-pip-positive",
                "cache-pip-active",
                "cache-pip-config",
                "cache-pip-other",
            ].map(DomainToken.init(validating:))
        )
    default:
        return try ExecutionProfile(
            id: DomainToken(rawValue: "phase-c.go-build-cache-v1")!,
            ruleID: RuleID(rawValue: ruleID)!,
            relativePath: RulePathPattern(
                rawValue: "Library/Caches/go-build"
            )!,
            expectedKind: .directory,
            resolverBindings: executionResolverBindings(),
            processSubjects: ExecutionProcessSubjects(
                bundleIdentifiers: [],
                exactNames: try ["go", "compile", "link", "asm", "cgo"].map {
                    try DomainLabel(validating: $0)
                },
                versionedFamilies: []
            ),
            defaultSuggestion: .never,
            fixtureIDs: try [
                "cache-go-build-positive",
                "cache-go-build-active",
                "cache-go-build-config",
                "cache-go-build-other",
            ].map(DomainToken.init(validating:))
        )
    }
}

private func executionResolverBindings() -> [ExecutionEvidenceBinding] {
    [
        ExecutionEvidenceBinding(
            key: DomainToken(rawValue: "evidence.cache.layout")!,
            resolver: .compilerAttested
        ),
        ExecutionEvidenceBinding(
            key: DomainToken(rawValue: "evidence.cache.reclaimable")!,
            resolver: .compilerAttested
        ),
        ExecutionEvidenceBinding(
            key: DomainToken(rawValue: "evidence.cache.tool-owned")!,
            resolver: .compilerAttested
        ),
        ExecutionEvidenceBinding(
            key: DomainToken(rawValue: "evidence.scope.user-owned")!,
            resolver: .currentFilesystem
        ),
        ExecutionEvidenceBinding(
            key: DomainToken(rawValue: "activity.process.inactive")!,
            resolver: .currentActivity
        ),
    ]
}

private func executionRuleFixture(
    ruleID: String,
    disposition: ReclaimDisposition
) throws -> CompiledRule {
    let profile = try executionProfileFixture(ruleID: ruleID)
    return try CompiledRule(
        id: profile.ruleID,
        match: RuleMatch(
            pathPattern: profile.relativePath,
            expectedKind: .directory
        ),
        producer: DomainLabel(rawValue: ruleID)!,
        rationaleKey: DomainToken(rawValue: "rationale.\(ruleID)")!,
        category: .packageAndBuildCaches,
        disposition: disposition,
        risk: .medium,
        confidenceRequirement: .high,
        veto: false,
        requiredEvidenceKeys: profile.resolverBindings.compactMap {
            $0.resolver == .currentActivity ? nil : $0.key
        },
        requiredActivityKeys: [
            DomainToken(rawValue: "activity.process.inactive")!,
        ],
        recovery: RecoveryGuidance(
            methodKey: DomainToken(rawValue: "recovery.\(ruleID)")!,
            cost: .low
        ),
        recommendedAction: .moveToTrash,
        provenance: try RuleProvenance(
            sources: [
                RuleProvenanceSource(
                    project: DomainLabel(rawValue: "Fixture")!,
                    url: URL(string: "https://example.com/\(ruleID)")!,
                    revision: DomainToken(rawValue: "fixture-v1")!,
                    license: DomainToken(rawValue: "MIT")!,
                    usage: .independentObservation
                ),
            ],
            independentlyVerified: true,
            verifiedAt: RuleVerificationDate(rawValue: "2026-08-13")!
        ),
        fixtureIDs: profile.fixtureIDs
    )
}

private func executionSnapshotFixture(
    relativePath: String,
    ownerUserID: UInt32 = getuid()
) throws -> PathSnapshot {
    let identity = try executionIdentityFixture(
        inode: 42,
        ownerUserID: ownerUserID
    )
    return try PathSnapshot(
        id: SnapshotID(rawValue: "snapshot-execution-fixture")!,
        sessionID: ScanSessionID(rawValue: "scan-execution-fixture")!,
        scopeID: ScanScopeID(rawValue: "scope-execution-fixture")!,
        relativePath: relativePath,
        kind: .directory,
        logicalByteCount: ByteCount(UInt64(identity.size))!,
        allocatedByteCount: ByteCount(UInt64(identity.allocatedBytes))!,
        modifiedAt: Date(
            timeIntervalSince1970:
                TimeInterval(identity.modificationSeconds)
        ),
        fileIdentity: identity,
        symlinkTarget: nil,
        measurementStatus: .measured,
        observedAt: Date(timeIntervalSince1970: 125)
    )
}

private func executionIdentityFixture(
    inode: UInt64,
    ownerUserID: UInt32
) throws -> FileIdentity {
    try FileIdentity(
        device: 9,
        inode: inode,
        mode: UInt16(S_IFDIR | 0o700),
        ownerUserID: ownerUserID,
        ownerGroupID: getgid(),
        size: 4_096,
        allocatedBytes: 8_192,
        modificationSeconds: 120,
        modificationNanoseconds: 0
    )
}

private func executionEvidenceID(
    snapshotID: SnapshotID,
    key: DomainToken
) -> EvidenceID {
    EvidenceID(
        rawValue: "evidence-\(snapshotID.rawValue)-\(key.rawValue)"
    )!
}
