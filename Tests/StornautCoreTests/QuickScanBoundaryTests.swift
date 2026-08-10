import Foundation
import Testing
@testable import StornautCore

@Test
func quickScanBoundarySourceHasNoCodexAdapterActionOrMutationSurface() throws {
    let root = EvidenceStoreTestSupport.repositoryRoot
    let quickScanDirectory = root.appending(
        path: "Sources/StornautCore/QuickScan"
    )
    let sourceFiles = try FileManager.default.contentsOfDirectory(
        at: quickScanDirectory,
        includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "swift" }
    let source = try sourceFiles.map {
        try String(contentsOf: $0, encoding: .utf8)
    }.joined(separator: "\n")

    for prohibited in [
        "StornautCodex",
        "CodexProcess",
        "ProbeBridge",
        "Adapter",
        "ActionExecutor",
        "ActionPolicyGate",
        "TrashMoving",
        "RegisteredAction",
        "Process(",
        "posix_spawn",
        "removeItem",
        "moveItem",
        "createFile",
        "forWritingTo",
    ] {
        #expect(
            source.contains(prohibited) == false,
            "Quick Scan source contains prohibited surface: \(prohibited)"
        )
    }
}

@Test
func quickScanPackageGraphKeepsCoreIndependentFromCodexAndCompiler() throws {
    let package = try String(
        contentsOf: EvidenceStoreTestSupport.repositoryRoot.appending(
            path: "Package.swift"
        ),
        encoding: .utf8
    )
    let coreTarget = try #require(
        package.range(of: ".target(\n            name: \"StornautCore\"")
    )
    let remaining = package[coreTarget.lowerBound...]
    let nextTarget = try #require(
        remaining.dropFirst().range(of: "\n        .target(")
    )
    let coreBlock = String(
        remaining[..<nextTarget.lowerBound]
    )

    #expect(coreBlock.contains("StornautCodex") == false)
    #expect(coreBlock.contains("RuleCompilerKit") == false)
    #expect(coreBlock.contains("resources:"))
    #expect(
        coreBlock.contains(
            ".copy(\"Resources/BuiltInRuleCatalog.json\")"
        )
    )
}

@Test
func builtInRuntimeCatalogMatchesDeterministicCompiledArtifact() throws {
    let catalog = try BuiltInRuleCatalog.load()

    #expect(
        catalog.catalogVersion.rawValue
            == "builtin-runtime-tool-residue-v1"
    )
    #expect(catalog.rules.count == 67)
    #expect(catalog.rules.first?.id.rawValue == "cache-bun-install")
    #expect(
        catalog.rules.last?.id.rawValue
            == "runtime-xcode-simulator-devices"
    )
}

@Test
func quickScanStateRejectsFalseCompletedProjection() throws {
    let session = try ScanSession(
        id: ScanSessionID(validating: "scan-task20-invalid"),
        startedAt: Date(timeIntervalSince1970: 1),
        finishedAt: Date(timeIntervalSince1970: 2),
        terminalState: .completed,
        completedScopes: [
            ScanScope(
                id: ScanScopeID(rawValue: "scope-task20-invalid")!,
                rootPath: PersistedPath(rawValue: "/tmp/task20")!,
                completedAt: Date(timeIntervalSince1970: 2)
            ),
        ],
        unfinishedScopes: []
    )

    #expect(throws: DomainContractError.invalidMeasurement) {
        _ = try QuickScanProjection(
            session: session,
            snapshots: [],
            classifications: [],
            evidence: [],
            ledger: nil,
            issues: [],
            corruptRecordIDs: []
        )
    }

    let snapshot = try task20BoundarySnapshot(
        relativePath: "fixture",
        kind: .directory
    )
    let first = try task20BoundaryClassification(
        id: "classification-task20-first",
        snapshotID: snapshot.id
    )
    let second = try task20BoundaryClassification(
        id: "classification-task20-second",
        snapshotID: snapshot.id
    )
    #expect(throws: DomainContractError.invalidMeasurement) {
        _ = try QuickScanProjection(
            session: try ScanSession(
                id: snapshot.sessionID,
                startedAt: Date(timeIntervalSince1970: 1),
                finishedAt: Date(timeIntervalSince1970: 2),
                terminalState: .partial,
                completedScopes: [],
                unfinishedScopes: [
                    UnfinishedScanScope(
                        id: snapshot.scopeID,
                        rootPath: PersistedPath(rawValue: "/tmp/task20")!,
                        reason: .metadataChanged
                    ),
                ]
            ),
            snapshots: [snapshot],
            classifications: [first, second],
            evidence: [],
            ledger: nil,
            issues: [],
            corruptRecordIDs: []
        )
    }
}

@Test
func deterministicClassifierNeverPromotesPathOnlyCandidate() throws {
    let catalog = try DomainJSON.decode(
        RuleCatalog.self,
        from: EvidenceStoreTestSupport.fixtureData(
            directory: "QuickScan",
            name: "task20-compiled-catalog"
        )
    )
    let snapshot = try task20BoundarySnapshot(
        relativePath: ".fixture-cache",
        kind: .directory
    )
    let rule = try #require(
        RuleCatalogMatcher(catalog: catalog).matchingRules(
            relativePath: snapshot.relativePath,
            kind: .directory
        ).first
    )

    let result = try DeterministicClassifier().classify(
        snapshot: snapshot,
        candidates: [rule],
        satisfiedEvidenceKeys: [],
        activityObservations: [],
        classifiedAt: Date(timeIntervalSince1970: 2),
        classificationID: ClassificationID(
            rawValue: "classification-task20-boundary"
        )!
    )

    #expect(result.disposition == .unknown)
    #expect(
        Set(result.missingEvidenceKeys.map(\.rawValue))
            == Set(
                rule.requiredEvidenceKeys.map(\.rawValue)
                    + rule.requiredActivityKeys.map(\.rawValue)
            )
    )
}

private func task20BoundarySnapshot(
    relativePath: String,
    kind: PathKind
) throws -> PathSnapshot {
    let mode: UInt16 = kind == .directory
        ? UInt16(S_IFDIR | 0o755)
        : UInt16(S_IFREG | 0o600)
    let identity = try FileIdentity(
        device: 1,
        inode: 2,
        mode: mode,
        ownerUserID: 501,
        ownerGroupID: 20,
        size: 0,
        allocatedBytes: 0,
        modificationSeconds: 1,
        modificationNanoseconds: 0
    )
    return try PathSnapshot(
        id: SnapshotID(rawValue: "snapshot-task20-boundary")!,
        sessionID: ScanSessionID(rawValue: "scan-task20-boundary")!,
        scopeID: ScanScopeID(rawValue: "scope-task20-boundary")!,
        relativePath: relativePath,
        kind: kind,
        logicalByteCount: ByteCount(0),
        allocatedByteCount: ByteCount(0),
        modifiedAt: Date(timeIntervalSince1970: 1),
        fileIdentity: identity,
        symlinkTarget: nil,
        measurementStatus: .measured,
        observedAt: Date(timeIntervalSince1970: 1)
    )
}

private func task20BoundaryClassification(
    id: String,
    snapshotID: SnapshotID
) throws -> Classification {
    try Classification(
        id: ClassificationID(rawValue: id)!,
        snapshotID: snapshotID,
        ruleID: nil,
        producer: nil,
        category: .unknownLargeConsumers,
        disposition: .unknown,
        risk: .high,
        confidence: .low,
        recovery: nil,
        requiredEvidenceKeys: [],
        missingEvidenceKeys: [],
        catalogVersion: DomainToken(rawValue: "task20-boundary-v1")!,
        classifiedAt: Date(timeIntervalSince1970: 2)
    )
}
