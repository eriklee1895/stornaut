import Darwin
import Foundation
import Testing
@testable import StornautCore

@Test
func investigationStoreV4CreatesAndReplaysOneStoreOwnedPlan() async throws {
    let store = try EvidenceStore(configuration: .memory)
    let fixture = try InvestigationStoreV4Fixture()
    try await fixture.seed(store)
    let command = fixture.command(
        investigationID: "investigation-store-v4-create",
        runID: "investigation-run-store-v4-create"
    )

    let first = try await store.createInvestigation(command)
    let replay = try await store.createInvestigation(command)

    #expect(first == replay)
    #expect(first.plan.id == command.investigationID)
    #expect(first.runID == command.initialRunID)
    #expect(first.plan.targets.count == 2)
    #expect(first.sourceRowCount == 5)
    #expect(first.relevanceTokenCount == 2)
    #expect(
        try await store._testInvestigationRowCounts(
            id: command.investigationID
        ) == InvestigationStoreRowCounts(
            sessions: 1,
            sourceRows: 5,
            relevanceTokens: 2,
            targets: 2,
            runs: 1,
            runTargets: 2,
            reports: 0,
            evidence: 0,
            degradations: 0,
            budgetEvents: 0
        )
    )
}

@Test
func investigationStoreV4RejectsConflictingReplayAndEmptyPlanning() async throws {
    let store = try EvidenceStore(configuration: .memory)
    let fixture = try InvestigationStoreV4Fixture()
    try await fixture.seed(store)
    let original = fixture.command(
        investigationID: "investigation-store-v4-conflict",
        runID: "investigation-run-store-v4-conflict"
    )
    _ = try await store.createInvestigation(original)

    let conflicting = InvestigationCreateCommand(
        investigationID: original.investigationID,
        initialRunID: InvestigationRunID(
            rawValue: "investigation-run-store-v4-alternate"
        )!,
        scanSessionID: original.scanSessionID,
        scanScopeID: original.scanScopeID,
        budgetPreset: original.budgetPreset,
        planningAt: original.planningAt,
        relevanceTokens: original.relevanceTokens
    )
    await #expect(throws: InvestigationPersistenceError.conflictingReplay) {
        _ = try await store.createInvestigation(conflicting)
    }

    let emptyStore = try EvidenceStore(configuration: .memory)
    let empty = try InvestigationStoreV4Fixture(hasCandidate: false)
    try await empty.seed(emptyStore)
    let emptyCommand = empty.command(
        investigationID: "investigation-store-v4-empty",
        runID: "investigation-run-store-v4-empty"
    )
    await #expect(throws: InvestigationPersistenceError.noEligibleTargets) {
        _ = try await emptyStore.createInvestigation(emptyCommand)
    }
    #expect(
        try await emptyStore._testInvestigationRowCounts(
            id: emptyCommand.investigationID
        ) == .zero
    )
}

@Test
func investigationStoreV4RejoinsAtEveryBarrierAndDetectsDrift() async throws {
    let store = try EvidenceStore(configuration: .memory)
    let fixture = try InvestigationStoreV4Fixture()
    try await fixture.seed(store)
    let command = fixture.command(
        investigationID: "investigation-store-v4-rejoin",
        runID: "investigation-run-store-v4-rejoin"
    )
    _ = try await store.createInvestigation(command)

    for barrier in InvestigationRejoinBarrier.allCases {
        #expect(
            try await store.rejoinInvestigation(
                id: command.investigationID,
                barrier: barrier
            ) == .matching
        )
    }

    try await store._testReplaceClassificationPayload(
        id: fixture.classification.id,
        payload: String(
            decoding: try DomainJSON.encode(
                fixture.changedClassification()
            ),
            as: UTF8.self
        )
    )
    #expect(
        try await store.rejoinInvestigation(
            id: command.investigationID,
            barrier: .activeRunRefresh
        ) == .stale
    )
}

struct InvestigationStoreV4Fixture {
    let planningAt = Date(timeIntervalSince1970: 1_800_000_120)
    let session: ScanSession
    let scopeID: ScanScopeID
    let snapshots: [PathSnapshot]
    let classification: Classification
    let ledger: SpaceLedger

    init(hasCandidate: Bool = true) throws {
        let sessionID = ScanSessionID(rawValue: "scan-store-v4-fixture")!
        scopeID = ScanScopeID(rawValue: "scope-store-v4-fixture")!
        let finishedAt = planningAt.addingTimeInterval(-120)
        let rootPath = PersistedPath(rawValue: "/tmp/store-v4-fixture")!
        let rootIdentity = try Self.identity(
            inode: 1,
            allocatedBytes: 0,
            modifiedAt: finishedAt
        )
        let candidateIdentity = try Self.identity(
            inode: 2,
            allocatedBytes: 2_147_483_648,
            modifiedAt: finishedAt
        )
        let root = try PathSnapshot(
            id: SnapshotID(rawValue: "snapshot-store-v4-root")!,
            sessionID: sessionID,
            scopeID: scopeID,
            relativePath: ".",
            kind: .directory,
            logicalByteCount: ByteCount(0),
            allocatedByteCount: ByteCount(0),
            modifiedAt: finishedAt,
            fileIdentity: rootIdentity,
            symlinkTarget: nil,
            measurementStatus: .measured,
            observedAt: finishedAt
        )
        let candidate = try PathSnapshot(
            id: SnapshotID(rawValue: "snapshot-store-v4-candidate")!,
            sessionID: sessionID,
            scopeID: scopeID,
            relativePath: "Library/Caches/unknown",
            kind: .directory,
            logicalByteCount: ByteCount(2_147_483_648),
            allocatedByteCount: ByteCount(2_147_483_648),
            modifiedAt: finishedAt,
            fileIdentity: candidateIdentity,
            symlinkTarget: nil,
            measurementStatus: .measured,
            observedAt: finishedAt
        )
        snapshots = [root, candidate]
        classification = try Classification(
            id: ClassificationID(
                rawValue: "classification-store-v4-candidate"
            )!,
            snapshotID: candidate.id,
            ruleID: nil,
            producer: nil,
            category: hasCandidate ? .unknownLargeConsumers : .protected,
            disposition: hasCandidate ? .unknown : .protected,
            risk: hasCandidate ? .high : .low,
            confidence: hasCandidate ? .low : .high,
            recovery: nil,
            requiredEvidenceKeys: [],
            missingEvidenceKeys: [],
            catalogVersion: DomainToken(rawValue: "catalog-store-v4")!,
            classifiedAt: finishedAt
        )
        session = try ScanSession(
            id: sessionID,
            startedAt: finishedAt.addingTimeInterval(-60),
            finishedAt: finishedAt,
            terminalState: .completed,
            completedScopes: [
                ScanScope(
                    id: scopeID,
                    rootPath: rootPath,
                    completedAt: finishedAt
                ),
            ],
            unfinishedScopes: []
        )
        let start = try VolumeBaseline(
            sessionID: sessionID,
            scopeID: scopeID,
            rootPath: rootPath,
            rootIdentity: rootIdentity,
            totalCapacity: ByteCount(4_294_967_296),
            availableCapacity: ByteCount(3_221_225_472),
            availableCapacityForImportantUsage: nil,
            availableCapacityForOpportunisticUsage: nil,
            volumeIsReadOnly: false,
            source: AccountingSource(
                kind: .volumeResourceValues,
                identifier: DomainToken(rawValue: "store-v4.start")!,
                sampledAt: finishedAt.addingTimeInterval(-60)
            )
        )
        let end = try VolumeBaseline(
            sessionID: sessionID,
            scopeID: scopeID,
            rootPath: rootPath,
            rootIdentity: rootIdentity,
            totalCapacity: ByteCount(4_294_967_296),
            availableCapacity: ByteCount(
                hasCandidate ? 1_073_741_824 : 2_147_483_648
            ),
            availableCapacityForImportantUsage: nil,
            availableCapacityForOpportunisticUsage: nil,
            volumeIsReadOnly: false,
            source: AccountingSource(
                kind: .volumeResourceValues,
                identifier: DomainToken(rawValue: "store-v4.end")!,
                sampledAt: finishedAt
            )
        )
        ledger = try SpaceLedgerReconciler().reconcile(
            SpaceLedgerInput(
                startBaseline: start,
                endBaseline: end,
                snapshots: snapshots,
                classifications: [classification]
            )
        )
    }

    func seed(_ store: EvidenceStore) async throws {
        try await store.saveScanSession(session)
        try await store.savePathSnapshots(snapshots)
        try await store.saveClassifications([classification])
        try await store.saveSpaceLedger(ledger)
    }

    func command(
        investigationID: String,
        runID: String
    ) -> InvestigationCreateCommand {
        InvestigationCreateCommand(
            investigationID: InvestigationID(rawValue: investigationID)!,
            initialRunID: InvestigationRunID(rawValue: runID)!,
            scanSessionID: session.id,
            scanScopeID: scopeID,
            budgetPreset: .focused,
            planningAt: planningAt,
            relevanceTokens: [
                DomainToken(rawValue: "relevance.large")!,
                DomainToken(rawValue: "relevance.developer")!,
            ]
        )
    }

    func changedClassification() throws -> Classification {
        try Classification(
            id: classification.id,
            snapshotID: classification.snapshotID,
            ruleID: classification.ruleID,
            producer: classification.producer,
            category: classification.category,
            disposition: classification.disposition,
            risk: classification.risk,
            confidence: classification.confidence,
            recovery: classification.recovery,
            requiredEvidenceKeys: classification.requiredEvidenceKeys,
            missingEvidenceKeys: classification.missingEvidenceKeys,
            catalogVersion: DomainToken(rawValue: "catalog-store-v4-changed")!,
            classifiedAt: classification.classifiedAt
        )
    }

    private static func identity(
        inode: UInt64,
        allocatedBytes: Int64,
        modifiedAt: Date
    ) throws -> FileIdentity {
        try FileIdentity(
            device: 1,
            inode: inode,
            mode: UInt16(S_IFDIR | 0o755),
            ownerUserID: getuid(),
            ownerGroupID: getgid(),
            size: allocatedBytes,
            allocatedBytes: allocatedBytes,
            modificationSeconds: Int64(modifiedAt.timeIntervalSince1970),
            modificationNanoseconds: 0
        )
    }
}
