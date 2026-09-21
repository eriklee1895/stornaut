import Foundation
import Testing
@testable import StornautCore

@Test
func spaceLedgerFixturesReconcileWithoutOverlapOrHiddenZero() throws {
    let fixture = try loadAccountingFixture()

    for scenario in fixture.scenarios {
        let input = try scenario.makeInput()
        let ledger = try SpaceLedgerReconciler().reconcile(input)

        #expect(ledger.status.rawValue == scenario.expected.status)
        #expect(ledger.known.bytes?.value == scenario.expected.knownAllocated)
        #expect(ledger.knownLogical.bytes?.value == scenario.expected.knownLogical)
        #expect(ledger.unknown.bytes?.value == scenario.expected.unknown)
        #expect(ledger.free.bytes?.value == scenario.expected.free)
        #expect(
            ledger.observedUnclassified.bytes?.value
                == scenario.expected.observedUnclassified
        )
        #expect(
            ledger.freeSpaceDelta?.value
                == scenario.expected.freeDelta
        )
        #expect(ledger.owners.count == scenario.expected.ownerCount)
        #expect(ledger.coverageGaps.count == scenario.expected.gapCount)
        #expect(
            ledger.volumeCapacity.sources.allSatisfy {
                $0.sampledAt == input.endBaseline.source.sampledAt
            }
        )
        if scenario.expected.gapCount > 0 {
            #expect(ledger.unmeasurable.status == .unmeasurable)
            #expect(ledger.unmeasurable.bytes == nil)
            #expect(ledger.unknownIncludesUnmeasurable)
        } else {
            #expect(ledger.unmeasurable.status == .measured)
            #expect(ledger.unmeasurable.bytes?.value == 0)
        }
    }
}

@Test
func reclaimDispositionDoesNotChangeOccupancy() throws {
    let fixture = try loadAccountingFixture()
    let ready = try #require(
        fixture.scenarios.first { $0.name == "disposition-independent-ready" }
    )
    let review = try #require(
        fixture.scenarios.first { $0.name == "disposition-independent-review" }
    )

    let readyLedger = try SpaceLedgerReconciler().reconcile(
        ready.makeInput()
    )
    let reviewLedger = try SpaceLedgerReconciler().reconcile(
        review.makeInput()
    )

    #expect(readyLedger.known.bytes == reviewLedger.known.bytes)
    #expect(readyLedger.unknown.bytes == reviewLedger.unknown.bytes)
    #expect(readyLedger.free.bytes == reviewLedger.free.bytes)
    #expect(readyLedger.owners.map(\.allocatedBytes) == reviewLedger.owners.map(\.allocatedBytes))
}

@Test
func unknownConsumerClassificationRemainsInUnknownOccupancy() throws {
    let scenario = try #require(
        loadAccountingFixture().scenarios.first {
            $0.name == "disposition-independent-review"
        }
    )
    let input = try scenario.makeInput()
    let original = try #require(input.classifications.first)
    let unknownClassification = try Classification(
        id: original.id,
        snapshotID: original.snapshotID,
        ruleID: nil,
        producer: nil,
        category: .unknownLargeConsumers,
        disposition: .unknown,
        risk: .high,
        confidence: .low,
        recovery: nil,
        requiredEvidenceKeys: [
            try DomainToken(validating: "producer.identity"),
        ],
        missingEvidenceKeys: [
            try DomainToken(validating: "producer.identity"),
        ],
        catalogVersion: original.catalogVersion,
        classifiedAt: original.classifiedAt
    )

    let ledger = try SpaceLedgerReconciler().reconcile(
        SpaceLedgerInput(
            startBaseline: input.startBaseline,
            endBaseline: input.endBaseline,
            snapshots: input.snapshots,
            classifications: [unknownClassification]
        )
    )

    #expect(ledger.known.bytes?.value == 0)
    #expect(ledger.knownLogical.bytes?.value == 0)
    #expect(ledger.unknown.bytes?.value == 600)
    #expect(
        ledger.owners.first?.category == .unknownLargeConsumers
    )
}

@Test
func accountingCaveatsRepresentSparseClonePurgeableHardlinkAndDrift() throws {
    let scenario = try #require(
        loadAccountingFixture().scenarios.first {
            $0.name == "overlap-hardlink-sparse-gap-and-volume-drift"
        }
    )

    let ledger = try SpaceLedgerReconciler().reconcile(scenario.makeInput())

    #expect(ledger.caveats.contains(.sparseFileObserved))
    #expect(ledger.caveats.contains(.hardLinkDeduplicated))
    #expect(ledger.caveats.contains(.cloneAndCompressionNotAttributed))
    #expect(ledger.caveats.contains(.purgeableNotEstimated))
    #expect(ledger.caveats.contains(.volumeChangedDuringScan))
    #expect(!ledger.caveats.contains(.knownExceedsVolumeUsed))
}

@Test
func hardLinkAcrossKnownAndUnknownOwnersIsNotArbitrarilyKnown() throws {
    let scenario = try #require(
        loadAccountingFixture().scenarios.first {
            $0.name == "disposition-independent-ready"
        }
    )
    let input = try scenario.makeInput()
    let original = try #require(
        input.snapshots.first { $0.kind == .regularFile }
    )
    let link = try copyingSnapshot(
        original,
        id: SnapshotID(validating: "snapshot-accounting-ambiguous-link"),
        relativePath: "unknown/link.bin"
    )
    let unknownOwner = try replacingBytes(
        original,
        id: SnapshotID(validating: "snapshot-accounting-unknown-owner"),
        relativePath: "unknown",
        allocated: 10,
        inode: 200
    )
    let unknownClassification = try classification(
        id: "classification-accounting-unknown-owner",
        snapshotID: unknownOwner.id,
        category: .unknownLargeConsumers,
        disposition: .unknown
    )

    let ledger = try SpaceLedgerReconciler().reconcile(
        SpaceLedgerInput(
            startBaseline: input.startBaseline,
            endBaseline: input.endBaseline,
            snapshots: input.snapshots + [unknownOwner, link],
            classifications: input.classifications + [unknownClassification]
        )
    )

    #expect(ledger.known.bytes?.value == 0)
    #expect(ledger.observedUnclassified.bytes?.value == 110)
    #expect(ledger.caveats.contains(.hardLinkDeduplicated))
    #expect(ledger.caveats.contains(.hardLinkOwnershipAmbiguous))
}

@Test
func accountingKnownAboveVolumeUsedFailsOpenAsInconsistentNotNegative() throws {
    let scenario = try #require(
        loadAccountingFixture().scenarios.first {
            $0.name == "known-exceeds-volume-used"
        }
    )

    let ledger = try SpaceLedgerReconciler().reconcile(scenario.makeInput())

    #expect(ledger.status == .inconsistent)
    #expect(ledger.unknown.status == .unknown)
    #expect(ledger.unknown.bytes == nil)
    #expect(ledger.caveats.contains(.knownExceedsVolumeUsed))
}

@Test
func accountingRejectsIntegerOverflowDuplicateAndDanglingInputs() throws {
    let fixture = try loadAccountingFixture()
    let scenario = try #require(
        fixture.scenarios.first { $0.name == "disposition-independent-ready" }
    )
    let base = try scenario.makeInput()
    let first = try #require(base.snapshots.first { $0.kind == .regularFile })
    let overflowA = try replacingBytes(
        first,
        id: SnapshotID(validating: "snapshot-accounting-overflow-a"),
        relativePath: "overflow-a.bin",
        allocated: Int64.max,
        inode: 100
    )
    let overflowB = try replacingBytes(
        first,
        id: SnapshotID(validating: "snapshot-accounting-overflow-b"),
        relativePath: "overflow-b.bin",
        allocated: Int64.max,
        inode: 101
    )
    let overflowClassifications = [
        try classification(
            id: "classification-accounting-overflow-a",
            snapshotID: overflowA.id,
            category: .packageAndBuildCaches,
            disposition: .readyToReclaim
        ),
        try classification(
            id: "classification-accounting-overflow-b",
            snapshotID: overflowB.id,
            category: .packageAndBuildCaches,
            disposition: .reviewRecommended
        ),
    ]
    #expect(throws: SpaceLedgerError.integerOverflow) {
        _ = try SpaceLedgerReconciler().reconcile(
            SpaceLedgerInput(
                startBaseline: base.startBaseline,
                endBaseline: base.endBaseline,
                snapshots: [overflowA, overflowB],
                classifications: overflowClassifications
            )
        )
    }

    #expect(throws: SpaceLedgerError.duplicateSnapshot) {
        _ = try SpaceLedgerReconciler().reconcile(
            SpaceLedgerInput(
                startBaseline: base.startBaseline,
                endBaseline: base.endBaseline,
                snapshots: [first, first],
                classifications: []
            )
        )
    }
    #expect(throws: SpaceLedgerError.classificationTargetMissing) {
        _ = try SpaceLedgerReconciler().reconcile(
            SpaceLedgerInput(
                startBaseline: base.startBaseline,
                endBaseline: base.endBaseline,
                snapshots: base.snapshots,
                classifications: [
                    try classification(
                        id: "classification-accounting-dangling",
                        snapshotID: SnapshotID(
                            validating: "snapshot-accounting-missing"
                        ),
                        category: .packageAndBuildCaches,
                        disposition: .readyToReclaim
                    ),
                ]
            )
        )
    }
}

@Test
func accountingRejectsMismatchedBaselinesAndUnmeasurableByteGuess() throws {
    let scenario = try #require(loadAccountingFixture().scenarios.first)
    let base = try scenario.makeInput()
    let mismatched = try VolumeBaseline(
        sessionID: ScanSessionID(validating: "scan-accounting-other"),
        scopeID: base.endBaseline.scopeID,
        rootPath: base.endBaseline.rootPath,
        rootIdentity: base.endBaseline.rootIdentity,
        totalCapacity: base.endBaseline.totalCapacity,
        availableCapacity: base.endBaseline.availableCapacity,
        availableCapacityForImportantUsage:
            base.endBaseline.availableCapacityForImportantUsage,
        availableCapacityForOpportunisticUsage:
            base.endBaseline.availableCapacityForOpportunisticUsage,
        volumeIsReadOnly: base.endBaseline.volumeIsReadOnly,
        source: base.endBaseline.source
    )
    #expect(throws: SpaceLedgerError.baselineMismatch) {
        _ = try SpaceLedgerReconciler().reconcile(
            SpaceLedgerInput(
                startBaseline: base.startBaseline,
                endBaseline: mismatched,
                snapshots: base.snapshots,
                classifications: base.classifications
            )
        )
    }

    #expect(throws: DomainContractError.invalidMeasurement) {
        _ = try AccountingMeasure(
            status: .unmeasurable,
            bytes: ByteCount(1),
            source: base.endBaseline.source,
            explanationKey: DomainToken(
                validating: "accounting.invalid.unmeasurable"
            )
        )
    }
}

@Test
func mountBoundaryGapIsNotClaimedInsideRootUnknownResidual() throws {
    let scenario = try #require(
        loadAccountingFixture().scenarios.first {
            $0.name == "disposition-independent-ready"
        }
    )
    let input = try scenario.makeInput()
    let directory = try #require(
        input.snapshots.first { $0.relativePath == "." }
    )
    let identity = try FileIdentity(
        device: directory.fileIdentity?.device ?? 1,
        inode: 300,
        mode: UInt16(S_IFDIR),
        ownerUserID: 501,
        ownerGroupID: 20,
        size: 10,
        allocatedBytes: 10,
        modificationSeconds: 1_786_240_000,
        modificationNanoseconds: 0
    )
    let boundary = try PathSnapshot(
        id: SnapshotID(validating: "snapshot-accounting-boundary"),
        sessionID: directory.sessionID,
        scopeID: directory.scopeID,
        relativePath: "mounted",
        kind: .directory,
        logicalByteCount: ByteCount(10),
        allocatedByteCount: ByteCount(10),
        modifiedAt: Date(timeIntervalSince1970: 1_786_240_000),
        fileIdentity: identity,
        symlinkTarget: nil,
        measurementStatus: .mountBoundary,
        observedAt: directory.observedAt
    )

    let ledger = try SpaceLedgerReconciler().reconcile(
        SpaceLedgerInput(
            startBaseline: input.startBaseline,
            endBaseline: input.endBaseline,
            snapshots: input.snapshots + [boundary],
            classifications: input.classifications
        )
    )

    #expect(ledger.status == .partial)
    #expect(ledger.unknownIncludesUnmeasurable == false)
    #expect(
        ledger.coverageGaps.first {
            $0.snapshotID == boundary.id
        }?.includedInUnknownResidual == false
    )
    #expect(ledger.observedUnclassified.bytes?.value == 10)
}

@Test
func spaceLedgerRoundTripRevalidatesNestedContracts() throws {
    let scenario = try #require(loadAccountingFixture().scenarios.first)
    let ledger = try SpaceLedgerReconciler().reconcile(scenario.makeInput())
    let encoded = try DomainJSON.encode(ledger)

    #expect(
        try DomainJSON.decode(SpaceLedger.self, from: encoded) == ledger
    )
    var object = try #require(
        JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    )
    var unmeasurable = try #require(
        object["unmeasurable"] as? [String: Any]
    )
    unmeasurable["bytes"] = 1
    object["unmeasurable"] = unmeasurable
    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(
            SpaceLedger.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
    }

    var gap = try #require(
        (object["coverageGaps"] as? [[String: Any]])?.first
    )
    gap["status"] = "measured"
    object["coverageGaps"] = [gap]
    object["unmeasurable"] = try JSONSerialization.jsonObject(
        with: DomainJSON.encode(ledger.unmeasurable)
    )
    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(
            SpaceLedger.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
    }

    object = try #require(
        JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    )
    var known = try #require(object["known"] as? [String: Any])
    known["bytes"] = 1
    object["known"] = known
    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(
            SpaceLedger.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
    }

    object = try #require(
        JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    )
    var deltaSources = try #require(
        object["freeSpaceDeltaSources"] as? [[String: Any]]
    )
    deltaSources[0]["kind"] = "classifier"
    object["freeSpaceDeltaSources"] = deltaSources
    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(
            SpaceLedger.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
    }

    object = try #require(
        JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    )
    object["caveats"] = []
    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(
            SpaceLedger.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
    }

    object = try #require(
        JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    )
    object["status"] = "reconciled"
    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(
            SpaceLedger.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
    }

    object = try #require(
        JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    )
    var knownFormula = try #require(
        object["known"] as? [String: Any]
    )
    knownFormula["formulaKey"] = "accounting.formula.free"
    object["known"] = knownFormula
    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(
            SpaceLedger.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
    }

    object = try #require(
        JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    )
    var unknown = try #require(object["unknown"] as? [String: Any])
    unknown["bytes"] = 1
    object["unknown"] = unknown
    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(
            SpaceLedger.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
    }

    object = try #require(
        JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    )
    var startFree = try #require(
        object["freeAtStart"] as? [String: Any]
    )
    startFree["bytes"] = 299
    object["freeAtStart"] = startFree
    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(
            SpaceLedger.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
    }
}

@Test
func spaceLedgerPersistsAsClosedPayloadAcrossStoreReopen() async throws {
    let scenario = try #require(loadAccountingFixture().scenarios.first)
    let input = try scenario.makeInput()
    let ledger = try SpaceLedgerReconciler().reconcile(input)
    let root = FileManager.default.temporaryDirectory.appending(
        path: "stornaut-space-ledger-\(UUID().uuidString)"
    )
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: root) }
    let configuration = try LocalStoreConfiguration(
        applicationSupportBaseURL: root.appending(path: "Application Support"),
        cachesBaseURL: root.appending(path: "Caches")
    )
    let store = try EvidenceStore(configuration: configuration)
    let session = try ScanSession(
        id: ledger.sessionID,
        startedAt: input.startBaseline.source.sampledAt,
        finishedAt: input.endBaseline.source.sampledAt,
        terminalState: .completed,
        completedScopes: [
            ScanScope(
                id: input.endBaseline.scopeID,
                rootPath: input.endBaseline.rootPath,
                completedAt: input.endBaseline.source.sampledAt
            ),
        ],
        unfinishedScopes: []
    )
    try await store.saveScanSession(session)
    try await store.saveSpaceLedger(ledger)

    let reopened = try EvidenceStore(configuration: configuration)
    #expect(
        try await reopened.spaceLedger(sessionID: ledger.sessionID) == ledger
    )
}

private struct AccountingFixture: Decodable {
    let fixtureVersion: Int
    let scenarios: [AccountingScenario]
}

private struct AccountingScenario: Decodable {
    struct Volume: Decodable {
        let total: UInt64
        let startFree: UInt64
        let endFree: UInt64
    }

    struct Entry: Decodable {
        struct ClassificationFixture: Decodable {
            let id: String
            let category: ArtifactCategory
            let disposition: ReclaimDisposition
        }

        let id: String
        let path: String
        let kind: PathKind
        let logical: Int64?
        let allocated: Int64?
        let device: UInt64?
        let inode: UInt64?
        let status: MeasurementStatus?
        let classification: ClassificationFixture?
    }

    struct Expected: Decodable {
        let knownAllocated: UInt64
        let knownLogical: UInt64
        let unknown: UInt64?
        let free: UInt64
        let observedUnclassified: UInt64
        let freeDelta: Int64
        let ownerCount: Int
        let gapCount: Int
        let status: String
    }

    let name: String
    let sessionID: String
    let scopeID: String
    let rootPath: String
    let volume: Volume
    let entries: [Entry]
    let expected: Expected

    func makeInput() throws -> SpaceLedgerInput {
        let sessionID = try ScanSessionID(validating: sessionID)
        let scopeID = try ScanScopeID(validating: scopeID)
        let rootPath = try PersistedPath(validating: rootPath)
        let rootIdentity = try FileIdentity(
            device: entries.compactMap(\.device).first ?? 1,
            inode: 999,
            mode: UInt16(S_IFDIR),
            ownerUserID: 501,
            ownerGroupID: 20,
            size: 0,
            allocatedBytes: 0,
            modificationSeconds: 1_786_240_000,
            modificationNanoseconds: 0
        )
        let start = try baseline(
            sessionID: sessionID,
            scopeID: scopeID,
            rootPath: rootPath,
            rootIdentity: rootIdentity,
            total: volume.total,
            free: volume.startFree,
            sampledAt: Date(timeIntervalSince1970: 1_786_240_000)
        )
        let end = try baseline(
            sessionID: sessionID,
            scopeID: scopeID,
            rootPath: rootPath,
            rootIdentity: rootIdentity,
            total: volume.total,
            free: volume.endFree,
            sampledAt: Date(timeIntervalSince1970: 1_786_240_010)
        )
        let snapshots = try entries.map {
            try snapshot(
                $0,
                sessionID: sessionID,
                scopeID: scopeID
            )
        }
        let classifications = try entries.compactMap { entry in
            try entry.classification.map {
                try classification(
                    id: $0.id,
                    snapshotID: SnapshotID(validating: entry.id),
                    category: $0.category,
                    disposition: $0.disposition
                )
            }
        }
        return SpaceLedgerInput(
            startBaseline: start,
            endBaseline: end,
            snapshots: snapshots,
            classifications: classifications
        )
    }
}

private func loadAccountingFixture() throws -> AccountingFixture {
    let url = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Tests/Fixtures/QuickScan/accounting-scenarios.json")
    return try JSONDecoder().decode(
        AccountingFixture.self,
        from: Data(contentsOf: url)
    )
}

private func baseline(
    sessionID: ScanSessionID,
    scopeID: ScanScopeID,
    rootPath: PersistedPath,
    rootIdentity: FileIdentity,
    total: UInt64,
    free: UInt64,
    sampledAt: Date
) throws -> VolumeBaseline {
    try VolumeBaseline(
        sessionID: sessionID,
        scopeID: scopeID,
        rootPath: rootPath,
        rootIdentity: rootIdentity,
        totalCapacity: ByteCount(total),
        availableCapacity: ByteCount(free),
        availableCapacityForImportantUsage: nil,
        availableCapacityForOpportunisticUsage: nil,
        volumeIsReadOnly: false,
        source: AccountingSource(
            kind: .volumeResourceValues,
            identifier: DomainToken(validating: "fixture.volume"),
            sampledAt: sampledAt
        )
    )
}

private func snapshot(
    _ entry: AccountingScenario.Entry,
    sessionID: ScanSessionID,
    scopeID: ScanScopeID
) throws -> PathSnapshot {
    let status = entry.status ?? .measured
    if entry.kind == .inaccessible {
        return try PathSnapshot(
            id: SnapshotID(validating: entry.id),
            sessionID: sessionID,
            scopeID: scopeID,
            relativePath: entry.path,
            kind: .inaccessible,
            logicalByteCount: nil,
            allocatedByteCount: nil,
            modifiedAt: nil,
            fileIdentity: nil,
            symlinkTarget: nil,
            measurementStatus: status,
            observedAt: Date(timeIntervalSince1970: 1_786_240_005)
        )
    }
    let mode: UInt16 = entry.kind == .directory
        ? UInt16(S_IFDIR)
        : UInt16(S_IFREG)
    let identity = try FileIdentity(
        device: try #require(entry.device),
        inode: try #require(entry.inode),
        mode: mode,
        ownerUserID: 501,
        ownerGroupID: 20,
        size: try #require(entry.logical),
        allocatedBytes: try #require(entry.allocated),
        modificationSeconds: 1_786_240_000,
        modificationNanoseconds: 0
    )
    return try PathSnapshot(
        id: SnapshotID(validating: entry.id),
        sessionID: sessionID,
        scopeID: scopeID,
        relativePath: entry.path,
        kind: entry.kind,
        logicalByteCount: ByteCount(exactly: identity.size),
        allocatedByteCount: ByteCount(exactly: identity.allocatedBytes),
        modifiedAt: Date(timeIntervalSince1970: 1_786_240_000),
        fileIdentity: identity,
        symlinkTarget: nil,
        measurementStatus: status,
        observedAt: Date(timeIntervalSince1970: 1_786_240_005)
    )
}

private func classification(
    id: String,
    snapshotID: SnapshotID,
    category: ArtifactCategory,
    disposition: ReclaimDisposition
) throws -> Classification {
    try Classification(
        id: ClassificationID(validating: id),
        snapshotID: snapshotID,
        ruleID: DomainToken(validating: "fixture.accounting.rule"),
        producer: DomainLabel(validating: "Fixture producer"),
        category: category,
        disposition: disposition,
        risk: .low,
        confidence: .high,
        recovery: disposition == .protected
            ? nil
            : RecoveryGuidance(
                methodKey: DomainToken(
                    validating: "recovery.fixture.accounting"
                ),
                cost: .low
            ),
        requiredEvidenceKeys: [],
        missingEvidenceKeys: [],
        catalogVersion: DomainToken(validating: "fixture-accounting-v1"),
        classifiedAt: Date(timeIntervalSince1970: 1_786_240_006)
    )
}

private func replacingBytes(
    _ snapshot: PathSnapshot,
    id: SnapshotID,
    relativePath: String,
    allocated: Int64,
    inode: UInt64
) throws -> PathSnapshot {
    let identity = try FileIdentity(
        device: try #require(snapshot.fileIdentity?.device),
        inode: inode,
        mode: UInt16(S_IFREG),
        ownerUserID: 501,
        ownerGroupID: 20,
        size: allocated,
        allocatedBytes: allocated,
        modificationSeconds: 1_786_240_000,
        modificationNanoseconds: 0
    )
    return try PathSnapshot(
        id: id,
        sessionID: snapshot.sessionID,
        scopeID: snapshot.scopeID,
        relativePath: relativePath,
        kind: .regularFile,
        logicalByteCount: ByteCount(exactly: allocated),
        allocatedByteCount: ByteCount(exactly: allocated),
        modifiedAt: Date(timeIntervalSince1970: 1_786_240_000),
        fileIdentity: identity,
        symlinkTarget: nil,
        measurementStatus: .measured,
        observedAt: snapshot.observedAt
    )
}

private func copyingSnapshot(
    _ snapshot: PathSnapshot,
    id: SnapshotID,
    relativePath: String
) throws -> PathSnapshot {
    try PathSnapshot(
        id: id,
        sessionID: snapshot.sessionID,
        scopeID: snapshot.scopeID,
        relativePath: relativePath,
        kind: snapshot.kind,
        logicalByteCount: snapshot.logicalByteCount,
        allocatedByteCount: snapshot.allocatedByteCount,
        modifiedAt: snapshot.modifiedAt,
        fileIdentity: snapshot.fileIdentity,
        symlinkTarget: snapshot.symlinkTarget,
        measurementStatus: snapshot.measurementStatus,
        observedAt: snapshot.observedAt
    )
}
