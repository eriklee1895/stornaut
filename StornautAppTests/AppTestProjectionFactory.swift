import Darwin
import Foundation
import StornautCore

enum AppTestProjectionFactory {
    static let now = Date(timeIntervalSince1970: 1_786_320_000)

    static func success() throws -> QuickScanProjection {
        try projection(terminalState: .completed)
    }

    static func partial() throws -> QuickScanProjection {
        try projection(
            terminalState: .partial,
            unfinishedReason: .metadataChanged
        )
    }

    static func cancelled() throws -> QuickScanProjection {
        try projection(
            terminalState: .cancelled,
            unfinishedReason: .cancelled,
            includesClassification: false,
            includesLedger: false
        )
    }

    static func failed() throws -> QuickScanProjection {
        try projection(
            terminalState: .failed,
            unfinishedReason: .storeFailure,
            includesClassification: false,
            includesLedger: false
        )
    }

    static func limitedPermission() throws -> QuickScanProjection {
        try projection(
            terminalState: .partial,
            unfinishedReason: .permissionDenied,
            includesPermissionGap: true
        )
    }

    private static func projection(
        terminalState: ScanTerminalState,
        unfinishedReason: ScanScopeCompletionReason? = nil,
        includesClassification: Bool = true,
        includesLedger: Bool = true,
        includesPermissionGap: Bool = false
    ) throws -> QuickScanProjection {
        let sessionID = ScanSessionID(
            rawValue: "scan-app-test-\(terminalState.rawValue)"
        )!
        let scopeID = ScanScopeID(
            rawValue: "scope-app-test-\(terminalState.rawValue)"
        )!
        let rootPath = PersistedPath(rawValue: "/tmp/stornaut-app-test")!
        let rootIdentity = try identity(
            inode: 1,
            mode: UInt16(S_IFDIR | 0o755)
        )
        let root = try PathSnapshot(
            id: SnapshotID(
                rawValue: "snapshot-app-test-\(terminalState.rawValue)-root"
            )!,
            sessionID: sessionID,
            scopeID: scopeID,
            relativePath: ".",
            kind: .directory,
            logicalByteCount: ByteCount(0),
            allocatedByteCount: ByteCount(0),
            modifiedAt: now,
            fileIdentity: rootIdentity,
            symlinkTarget: nil,
            measurementStatus: .measured,
            observedAt: now
        )
        var snapshots = [root]
        if includesPermissionGap {
            snapshots.append(
                try PathSnapshot(
                    id: SnapshotID(
                        rawValue:
                            "snapshot-app-test-\(terminalState.rawValue)-gap"
                    )!,
                    sessionID: sessionID,
                    scopeID: scopeID,
                    relativePath: "restricted",
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
        let classification = try Classification(
            id: ClassificationID(
                rawValue:
                    "classification-app-test-\(terminalState.rawValue)"
            )!,
            snapshotID: root.id,
            ruleID: nil,
            producer: nil,
            category: .unknownLargeConsumers,
            disposition: .unknown,
            risk: .high,
            confidence: .low,
            recovery: nil,
            requiredEvidenceKeys: [],
            missingEvidenceKeys: [],
            catalogVersion: DomainToken(rawValue: "app-test-catalog-v1")!,
            classifiedAt: now
        )
        let classifications = includesClassification ? [classification] : []
        let session = try ScanSession(
            id: sessionID,
            startedAt: now.addingTimeInterval(-10),
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
                        reason: unfinishedReason ?? .interrupted
                    ),
                ]
        )
        let ledger = includesLedger
            ? try makeLedger(
                sessionID: sessionID,
                scopeID: scopeID,
                rootPath: rootPath,
                rootIdentity: rootIdentity,
                snapshots: snapshots,
                classifications: classifications
            )
            : nil
        return try QuickScanProjection(
            session: session,
            snapshots: snapshots,
            classifications: classifications,
            evidence: [],
            ledger: ledger,
            issues: [],
            corruptRecordIDs: []
        )
    }

    private static func makeLedger(
        sessionID: ScanSessionID,
        scopeID: ScanScopeID,
        rootPath: PersistedPath,
        rootIdentity: FileIdentity,
        snapshots: [PathSnapshot],
        classifications: [Classification]
    ) throws -> SpaceLedger {
        let start = try baseline(
            sessionID: sessionID,
            scopeID: scopeID,
            rootPath: rootPath,
            rootIdentity: rootIdentity,
            available: 600_000,
            sampledAt: now.addingTimeInterval(-10)
        )
        let end = try baseline(
            sessionID: sessionID,
            scopeID: scopeID,
            rootPath: rootPath,
            rootIdentity: rootIdentity,
            available: 590_000,
            sampledAt: now
        )
        return try SpaceLedgerReconciler().reconcile(
            SpaceLedgerInput(
                startBaseline: start,
                endBaseline: end,
                snapshots: snapshots,
                classifications: classifications
            )
        )
    }

    private static func baseline(
        sessionID: ScanSessionID,
        scopeID: ScanScopeID,
        rootPath: PersistedPath,
        rootIdentity: FileIdentity,
        available: UInt64,
        sampledAt: Date
    ) throws -> VolumeBaseline {
        try VolumeBaseline(
            sessionID: sessionID,
            scopeID: scopeID,
            rootPath: rootPath,
            rootIdentity: rootIdentity,
            totalCapacity: ByteCount(1_000_000),
            availableCapacity: ByteCount(available),
            availableCapacityForImportantUsage: nil,
            availableCapacityForOpportunisticUsage: nil,
            volumeIsReadOnly: false,
            source: AccountingSource(
                kind: .volumeResourceValues,
                identifier: DomainToken(rawValue: "app-test.volume")!,
                sampledAt: sampledAt
            )
        )
    }

    private static func identity(
        inode: UInt64,
        mode: UInt16
    ) throws -> FileIdentity {
        try FileIdentity(
            device: 1,
            inode: inode,
            mode: mode,
            ownerUserID: getuid(),
            ownerGroupID: getgid(),
            size: 0,
            allocatedBytes: 0,
            modificationSeconds: Int64(now.timeIntervalSince1970),
            modificationNanoseconds: 0
        )
    }
}
