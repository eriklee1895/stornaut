import Darwin
import Foundation
import StornautCore

enum OverviewTestProjectionFactory {
    static let now = Date(timeIntervalSince1970: 1_786_320_000)

    static func projection(
        slug: String = "overview",
        terminalState: ScanTerminalState = .completed,
        permissionGap: Bool = false,
        permissionGapIsReady: Bool = false,
        totalCapacity: UInt64 = 20_000,
        firstEvidenceFreshness: EvidenceFreshness = .current,
        firstEvidenceSummary: String = "activity.process.inactive"
    ) throws -> QuickScanProjection {
        let sessionID = ScanSessionID(rawValue: "scan-\(slug)")!
        let scopeID = ScanScopeID(rawValue: "scope-\(slug)")!
        let rootPath = PersistedPath(
            rawValue: "/tmp/stornaut-\(slug)"
        )!
        let rootIdentity = try identity(inode: 1)
        var snapshots = try [
            snapshot(
                slug: slug,
                sessionID: sessionID,
                scopeID: scopeID,
                relativePath: ".",
                allocatedBytes: 0,
                inode: 1
            ),
            snapshot(
                slug: slug,
                sessionID: sessionID,
                scopeID: scopeID,
                relativePath: "Library/Caches/build",
                allocatedBytes: 3_000,
                inode: 2
            ),
            snapshot(
                slug: slug,
                sessionID: sessionID,
                scopeID: scopeID,
                relativePath: "Projects/App/DerivedData",
                allocatedBytes: 2_000,
                inode: 3
            ),
            snapshot(
                slug: slug,
                sessionID: sessionID,
                scopeID: scopeID,
                relativePath: "Library/Caches/updater",
                allocatedBytes: 1_500,
                inode: 4
            ),
            snapshot(
                slug: slug,
                sessionID: sessionID,
                scopeID: scopeID,
                relativePath: "Projects/archive/.git",
                allocatedBytes: 1_000,
                inode: 5
            ),
            snapshot(
                slug: slug,
                sessionID: sessionID,
                scopeID: scopeID,
                relativePath: ".ssh",
                allocatedBytes: 500,
                inode: 6
            ),
            snapshot(
                slug: slug,
                sessionID: sessionID,
                scopeID: scopeID,
                relativePath: "Mystery",
                allocatedBytes: 700,
                inode: 7
            ),
        ]
        if permissionGap {
            snapshots.append(
                try PathSnapshot(
                    id: SnapshotID(rawValue: "snapshot-\(slug)-gap")!,
                    sessionID: sessionID,
                    scopeID: scopeID,
                    relativePath: "Restricted",
                    kind: .inaccessible,
                    logicalByteCount: nil,
                    allocatedByteCount: nil,
                    modifiedAt: nil,
                    fileIdentity: nil,
                    symlinkTarget: nil,
                    measurementStatus: .permissionDenied,
                    observedAt: now
                )
            )
        }

        var classifications = try [
            classification(
                slug: slug,
                suffix: "build",
                snapshot: snapshots[1],
                producer: "Build cache",
                category: .packageAndBuildCaches,
                disposition: .readyToReclaim,
                recoveryCost: .low,
                missingActivity: false
            ),
            classification(
                slug: slug,
                suffix: "derived",
                snapshot: snapshots[2],
                producer: "Xcode",
                category: .rebuildableProjectArtifacts,
                disposition: .readyToReclaim,
                recoveryCost: .medium,
                missingActivity: false
            ),
            classification(
                slug: slug,
                suffix: "updater",
                snapshot: snapshots[3],
                producer: "Updater",
                category: .updatesAndTemporaryFiles,
                disposition: .reviewRecommended,
                recoveryCost: .medium,
                missingActivity: true
            ),
            classification(
                slug: slug,
                suffix: "repository",
                snapshot: snapshots[4],
                producer: "Git",
                category: .largeRepositoriesAndHistory,
                disposition: .reviewRecommended,
                recoveryCost: .high,
                missingActivity: false
            ),
            classification(
                slug: slug,
                suffix: "protected",
                snapshot: snapshots[5],
                producer: "Developer credentials",
                category: .protected,
                disposition: .protected,
                recoveryCost: nil,
                missingActivity: false
            ),
            classification(
                slug: slug,
                suffix: "unknown",
                snapshot: snapshots[6],
                producer: nil,
                category: .unknownLargeConsumers,
                disposition: .unknown,
                recoveryCost: nil,
                missingActivity: false
            ),
        ]
        if permissionGapIsReady {
            let gap = snapshots[snapshots.count - 1]
            classifications.append(
                try classification(
                    slug: slug,
                    suffix: "gap-ready",
                    snapshot: gap,
                    producer: "Restricted cache",
                    category: .packageAndBuildCaches,
                    disposition: .readyToReclaim,
                    recoveryCost: .low,
                    missingActivity: false
                )
            )
        }

        let session = try ScanSession(
            id: sessionID,
            startedAt: now.addingTimeInterval(-60),
            finishedAt: now,
            terminalState: terminalState,
            completedScopes: terminalState == .completed
                ? [
                    ScanScope(
                        id: scopeID,
                        rootPath: rootPath,
                        completedAt: now
                    ),
                ]
                : [],
            unfinishedScopes: terminalState == .completed
                ? []
                : [
                    UnfinishedScanScope(
                        id: scopeID,
                        rootPath: rootPath,
                        reason: permissionGap
                            ? .permissionDenied
                            : terminalState == .cancelled
                                ? .cancelled
                                : terminalState == .failed
                                    ? .storeFailure
                                    : .metadataChanged
                    ),
                ]
        )
        let ledger = try SpaceLedgerReconciler().reconcile(
            SpaceLedgerInput(
                startBaseline: baseline(
                    sessionID: sessionID,
                    scopeID: scopeID,
                    rootPath: rootPath,
                    rootIdentity: rootIdentity,
                    totalCapacity: totalCapacity,
                    freeBytes: 8_500,
                    sampledAt: now.addingTimeInterval(-60)
                ),
                endBaseline: baseline(
                    sessionID: sessionID,
                    scopeID: scopeID,
                    rootPath: rootPath,
                    rootIdentity: rootIdentity,
                    totalCapacity: totalCapacity,
                    freeBytes: 8_000,
                    sampledAt: now
                ),
                snapshots: snapshots,
                classifications: classifications
            )
        )

        return try QuickScanProjection(
            session: session,
            snapshots: snapshots,
            classifications: classifications,
            evidence: [
                evidence(
                    slug: slug,
                    suffix: "build",
                    snapshot: snapshots[1],
                    kind: .activity,
                    summary: firstEvidenceSummary,
                    freshness: firstEvidenceFreshness
                ),
                evidence(
                    slug: slug,
                    suffix: "derived",
                    snapshot: snapshots[2],
                    kind: .git,
                    summary: "activity.git.clean"
                ),
            ],
            ledger: ledger,
            issues: [],
            corruptRecordIDs: []
        )
    }

    private static func snapshot(
        slug: String,
        sessionID: ScanSessionID,
        scopeID: ScanScopeID,
        relativePath: String,
        allocatedBytes: UInt64,
        inode: UInt64
    ) throws -> PathSnapshot {
        let suffix = relativePath
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ".", with: "root")
            .lowercased()
        return try PathSnapshot(
            id: SnapshotID(rawValue: "snapshot-\(slug)-\(suffix)")!,
            sessionID: sessionID,
            scopeID: scopeID,
            relativePath: relativePath,
            kind: .directory,
            logicalByteCount: ByteCount(allocatedBytes),
            allocatedByteCount: ByteCount(allocatedBytes),
            modifiedAt: now,
            fileIdentity: identity(
                inode: inode,
                allocatedBytes: Int64(allocatedBytes)
            ),
            symlinkTarget: nil,
            measurementStatus: .measured,
            observedAt: now
        )
    }

    private static func classification(
        slug: String,
        suffix: String,
        snapshot: PathSnapshot,
        producer: String?,
        category: ArtifactCategory,
        disposition: ReclaimDisposition,
        recoveryCost: RebuildCost?,
        missingActivity: Bool
    ) throws -> Classification {
        let activity = DomainToken(rawValue: "activity.process.inactive")!
        return try Classification(
            id: ClassificationID(
                rawValue: "classification-\(slug)-\(suffix)"
            )!,
            snapshotID: snapshot.id,
            ruleID: disposition == .unknown ? nil
                : DomainToken(rawValue: "rule-\(slug)-\(suffix)"),
            producer: producer.flatMap(DomainLabel.init(rawValue:)),
            category: category,
            disposition: disposition,
            risk: disposition == .protected ? .critical : .medium,
            confidence: disposition == .unknown ? .low : .high,
            recovery: recoveryCost.map {
                RecoveryGuidance(
                    methodKey: DomainToken(
                        rawValue: "recovery-\(slug)-\(suffix)"
                    )!,
                    cost: $0
                )
            },
            requiredEvidenceKeys: recoveryCost == nil ? [] : [activity],
            missingEvidenceKeys: missingActivity ? [activity] : [],
            catalogVersion: DomainToken(rawValue: "catalog-\(slug)")!,
            classifiedAt: now
        )
    }

    private static func evidence(
        slug: String,
        suffix: String,
        snapshot: PathSnapshot,
        kind: EvidenceKind,
        summary: String,
        freshness: EvidenceFreshness = .current
    ) -> EvidenceRecord {
        EvidenceRecord(
            id: EvidenceID(rawValue: "evidence-\(slug)-\(suffix)")!,
            targetID: snapshot.id,
            kind: kind,
            source: EvidenceSource(
                kind: .activityProvider,
                identifier: DomainToken(
                    rawValue: "activity-provider-\(suffix)"
                )!
            ),
            summaryKey: DomainToken(rawValue: summary)!,
            observedAt: now,
            freshness: freshness
        )
    }

    private static func baseline(
        sessionID: ScanSessionID,
        scopeID: ScanScopeID,
        rootPath: PersistedPath,
        rootIdentity: FileIdentity,
        totalCapacity: UInt64,
        freeBytes: UInt64,
        sampledAt: Date
    ) throws -> VolumeBaseline {
        try VolumeBaseline(
            sessionID: sessionID,
            scopeID: scopeID,
            rootPath: rootPath,
            rootIdentity: rootIdentity,
            totalCapacity: ByteCount(totalCapacity),
            availableCapacity: ByteCount(freeBytes),
            availableCapacityForImportantUsage: nil,
            availableCapacityForOpportunisticUsage: nil,
            volumeIsReadOnly: false,
            source: AccountingSource(
                kind: .volumeResourceValues,
                identifier: DomainToken(rawValue: "fixture-volume")!,
                sampledAt: sampledAt
            )
        )
    }

    private static func identity(
        inode: UInt64,
        allocatedBytes: Int64 = 0
    ) throws -> FileIdentity {
        try FileIdentity(
            device: 1,
            inode: inode,
            mode: UInt16(S_IFDIR | 0o755),
            ownerUserID: getuid(),
            ownerGroupID: getgid(),
            size: allocatedBytes,
            allocatedBytes: allocatedBytes,
            modificationSeconds: Int64(now.timeIntervalSince1970),
            modificationNanoseconds: 0
        )
    }
}
