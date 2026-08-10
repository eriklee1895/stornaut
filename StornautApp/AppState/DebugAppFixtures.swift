#if DEBUG
import AppKit
import Darwin
import Foundation
import StornautCore
import SwiftUI

enum DebugAppFixture:
    String,
    CaseIterable,
    Sendable
{
    case empty
    case loading
    case partial
    case cancelled
    case success
    case limitedPermission = "limited-permission"
    case stale
    case error

    @MainActor
    func makeState() throws -> AppPageState {
        let now = DebugProjectionFactory.now
        switch self {
        case .empty:
            return .empty
        case .loading:
            return try AppPageState(
                phase: .loading,
                projection: DebugProjectionFactory.success(slug: rawValue),
                reasonKey: nil,
                recoveryIntent: nil,
                refreshedAt: now
            )
        case .partial:
            return try AppPageState(
                phase: .partial,
                projection: DebugProjectionFactory.partial(slug: rawValue),
                reasonKey: DomainToken(rawValue: "app.state.partial"),
                recoveryIntent: .retryLatestSnapshot,
                refreshedAt: now
            )
        case .cancelled:
            return try AppPageState(
                phase: .cancelled,
                projection: DebugProjectionFactory.cancelled(slug: rawValue),
                reasonKey: DomainToken(rawValue: "app.state.cancelled"),
                recoveryIntent: .retryLatestSnapshot,
                refreshedAt: now
            )
        case .success:
            return try .success(
                projection: DebugProjectionFactory.success(slug: rawValue),
                refreshedAt: now
            )
        case .limitedPermission:
            return try AppPageState(
                phase: .limitedPermission,
                projection: DebugProjectionFactory.limitedPermission(
                    slug: rawValue
                ),
                reasonKey: DomainToken(
                    rawValue: "app.state.permission-limited"
                ),
                recoveryIntent: .reviewPermissions,
                refreshedAt: now
            )
        case .stale:
            return try AppPageState(
                phase: .stale,
                projection: DebugProjectionFactory.success(slug: rawValue),
                reasonKey: DomainToken(rawValue: "app.state.snapshot-stale"),
                recoveryIntent: .refreshLatestSnapshot,
                refreshedAt: now
            )
        case .error:
            return try AppPageState(
                phase: .error,
                projection: DebugProjectionFactory.success(slug: rawValue),
                reasonKey: DomainToken(
                    rawValue: "app.state.store-unavailable"
                ),
                recoveryIntent: .retryLatestSnapshot,
                refreshedAt: now
            )
        }
    }
}

struct DebugAppFixtureSelection: Sendable, Equatable {
    let fixture: DebugAppFixture

    init?(arguments: [String]) {
        let prefix = "--stornaut-debug-fixture="
        let matches = arguments.filter { $0.hasPrefix(prefix) }
        guard matches.count == 1,
              matches[0].count > prefix.count,
              let fixture = DebugAppFixture(
                  rawValue: String(matches[0].dropFirst(prefix.count))
              )
        else {
            return nil
        }
        self.fixture = fixture
    }
}

extension AppComposition {
    static func debugFixture(
        arguments: [String]
    ) throws -> AppComposition? {
        guard let selection = DebugAppFixtureSelection(
            arguments: arguments
        ) else {
            return nil
        }
        return try debugFixture(selection: selection)
    }

    static func debugFixture(
        selection: DebugAppFixtureSelection,
        makeState: @MainActor (DebugAppFixture) throws -> AppPageState = {
            try $0.makeState()
        }
    ) throws -> AppComposition {
        let state = try makeState(selection.fixture)
        return AppComposition(
            model: StornautAppModel(
                dependencies: AppDependencies { nil },
                initialState: state,
                initialScanActivity: selection.fixture == .loading
                    ? .active
                    : .idle,
                now: { DebugProjectionFactory.now },
                refreshesServices: false
            )
        )
    }
}

struct DebugAppStateProbe: NSViewRepresentable {
    let phase: AppPagePhase

    func makeNSView(context: Context) -> DebugAppStateProbeView {
        DebugAppStateProbeView(phase: phase)
    }

    func updateNSView(
        _ nsView: DebugAppStateProbeView,
        context: Context
    ) {
        nsView.phase = phase
    }
}

final class DebugAppStateProbeView: NSView {
    var phase: AppPagePhase {
        didSet { setAccessibilityLabel(phase.rawValue) }
    }

    init(phase: AppPagePhase) {
        self.phase = phase
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityIdentifier("app.state.phase")
        setAccessibilityRole(.staticText)
        setAccessibilityLabel(phase.rawValue)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private enum DebugProjectionFactory {
    static let now = Date(timeIntervalSince1970: 1_786_320_000)

    static func success(slug: String) throws -> QuickScanProjection {
        try projection(slug: slug, terminalState: .completed)
    }

    static func partial(slug: String) throws -> QuickScanProjection {
        try projection(
            slug: slug,
            terminalState: .partial,
            unfinishedReason: .metadataChanged
        )
    }

    static func cancelled(slug: String) throws -> QuickScanProjection {
        try projection(
            slug: slug,
            terminalState: .cancelled,
            unfinishedReason: .cancelled,
            includesClassification: false,
            includesLedger: false
        )
    }

    static func limitedPermission(slug: String) throws -> QuickScanProjection {
        try projection(
            slug: slug,
            terminalState: .partial,
            unfinishedReason: .permissionDenied,
            includesPermissionGap: true
        )
    }

    private static func projection(
        slug: String,
        terminalState: ScanTerminalState,
        unfinishedReason: ScanScopeCompletionReason? = nil,
        includesClassification: Bool = true,
        includesLedger: Bool = true,
        includesPermissionGap: Bool = false
    ) throws -> QuickScanProjection {
        let sessionID = ScanSessionID(
            rawValue: "scan-fixture-\(slug)"
        )!
        let scopeID = ScanScopeID(
            rawValue: "scope-fixture-\(slug)"
        )!
        let rootPath = PersistedPath(rawValue: "/tmp/stornaut-fixture")!
        let rootIdentity = try identity(
            inode: 1,
            mode: UInt16(S_IFDIR | 0o755)
        )
        let root = try measuredSnapshot(
            slug: slug,
            suffix: "root",
            sessionID: sessionID,
            scopeID: scopeID,
            relativePath: ".",
            allocatedBytes: 0,
            inode: 1
        )
        var snapshots = [root]
        if includesClassification {
            snapshots.append(
                contentsOf: try [
                    measuredSnapshot(
                        slug: slug,
                        suffix: "build-cache",
                        sessionID: sessionID,
                        scopeID: scopeID,
                        relativePath: "Library/Caches/build",
                        allocatedBytes: 180_000,
                        inode: 2
                    ),
                    measuredSnapshot(
                        slug: slug,
                        suffix: "derived-data",
                        sessionID: sessionID,
                        scopeID: scopeID,
                        relativePath: "Projects/App/DerivedData",
                        allocatedBytes: 120_000,
                        inode: 3
                    ),
                    measuredSnapshot(
                        slug: slug,
                        suffix: "updater",
                        sessionID: sessionID,
                        scopeID: scopeID,
                        relativePath: "Library/Caches/updater",
                        allocatedBytes: 50_000,
                        inode: 4
                    ),
                    measuredSnapshot(
                        slug: slug,
                        suffix: "protected",
                        sessionID: sessionID,
                        scopeID: scopeID,
                        relativePath: ".ssh",
                        allocatedBytes: 10_000,
                        inode: 5
                    ),
                ]
            )
        }
        if includesPermissionGap {
            snapshots.append(
                try PathSnapshot(
                    id: SnapshotID(
                        rawValue:
                            "snapshot-fixture-\(slug)-gap"
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
        let classifications = includesClassification
            ? try [
                classification(
                    slug: slug,
                    suffix: "root",
                    snapshot: snapshots[0],
                    producer: nil,
                    category: .unknownLargeConsumers,
                    disposition: .unknown,
                    recoveryCost: nil,
                    missingActivity: false
                ),
                classification(
                    slug: slug,
                    suffix: "build-cache",
                    snapshot: snapshots[1],
                    producer: "Build cache",
                    category: .packageAndBuildCaches,
                    disposition: .readyToReclaim,
                    recoveryCost: .low,
                    missingActivity: false
                ),
                classification(
                    slug: slug,
                    suffix: "derived-data",
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
                    suffix: "protected",
                    snapshot: snapshots[4],
                    producer: "Developer credentials",
                    category: .protected,
                    disposition: .protected,
                    recoveryCost: nil,
                    missingActivity: false
                ),
            ]
            : []
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
            evidence: includesClassification
                ? [
                    activityEvidence(
                        slug: slug,
                        suffix: "build-cache",
                        snapshotID: snapshots[1].id
                    ),
                    activityEvidence(
                        slug: slug,
                        suffix: "derived-data",
                        snapshotID: snapshots[2].id
                    ),
                ]
                : [],
            ledger: ledger,
            issues: [],
            corruptRecordIDs: []
        )
    }

    private static func measuredSnapshot(
        slug: String,
        suffix: String,
        sessionID: ScanSessionID,
        scopeID: ScanScopeID,
        relativePath: String,
        allocatedBytes: UInt64,
        inode: UInt64
    ) throws -> PathSnapshot {
        try PathSnapshot(
            id: SnapshotID(
                rawValue: "snapshot-fixture-\(slug)-\(suffix)"
            )!,
            sessionID: sessionID,
            scopeID: scopeID,
            relativePath: relativePath,
            kind: .directory,
            logicalByteCount: ByteCount(allocatedBytes),
            allocatedByteCount: ByteCount(allocatedBytes),
            modifiedAt: now,
            fileIdentity: try identity(
                inode: inode,
                mode: UInt16(S_IFDIR | 0o755),
                bytes: Int64(allocatedBytes)
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
        let activity = DomainToken(
            rawValue: "activity.process.inactive"
        )!
        return try Classification(
            id: ClassificationID(
                rawValue: "classification-fixture-\(slug)-\(suffix)"
            )!,
            snapshotID: snapshot.id,
            ruleID: disposition == .unknown
                ? nil
                : DomainToken(
                    rawValue: "rule-fixture-\(slug)-\(suffix)"
                ),
            producer: producer.flatMap(DomainLabel.init(rawValue:)),
            category: category,
            disposition: disposition,
            risk: disposition == .protected ? .critical : .medium,
            confidence: disposition == .unknown ? .low : .high,
            recovery: recoveryCost.map {
                RecoveryGuidance(
                    methodKey: DomainToken(
                        rawValue: "recovery-fixture-\(slug)-\(suffix)"
                    )!,
                    cost: $0
                )
            },
            requiredEvidenceKeys: recoveryCost == nil ? [] : [activity],
            missingEvidenceKeys: missingActivity ? [activity] : [],
            catalogVersion: DomainToken(rawValue: "fixture-catalog-v1")!,
            classifiedAt: now
        )
    }

    private static func activityEvidence(
        slug: String,
        suffix: String,
        snapshotID: SnapshotID
    ) -> EvidenceRecord {
        EvidenceRecord(
            id: EvidenceID(
                rawValue: "evidence-fixture-\(slug)-\(suffix)"
            )!,
            targetID: snapshotID,
            kind: .activity,
            source: EvidenceSource(
                kind: .activityProvider,
                identifier: DomainToken(
                    rawValue: "fixture-activity-provider"
                )!
            ),
            summaryKey: DomainToken(
                rawValue: "activity.process.inactive"
            )!,
            observedAt: now,
            freshness: .current
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
                identifier: DomainToken(rawValue: "fixture.volume")!,
                sampledAt: sampledAt
            )
        )
    }

    private static func identity(
        inode: UInt64,
        mode: UInt16,
        bytes: Int64 = 0
    ) throws -> FileIdentity {
        try FileIdentity(
            device: 1,
            inode: inode,
            mode: mode,
            ownerUserID: getuid(),
            ownerGroupID: getgid(),
            size: bytes,
            allocatedBytes: bytes,
            modificationSeconds: Int64(now.timeIntervalSince1970),
            modificationNanoseconds: 0
        )
    }
}
#endif
