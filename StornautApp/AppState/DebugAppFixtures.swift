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

enum DebugHistoryFixture: String, CaseIterable, Sendable {
    case empty
    case populated
    case expired
    case corrupt
    case trend
}

enum DebugSettingsFixture: String, CaseIterable, Sendable {
    case populated
    case empty
    case corrupt
    case codexMissing = "codex-missing"
    case syntaxUnsupported = "syntax-unsupported"
    case runtimeStale = "runtime-stale"
    case runtimeFailed = "runtime-failed"
    case runtimeUnverified = "runtime-unverified"
}

struct DebugSettingsFixtureSelection: Sendable, Equatable {
    let fixture: DebugSettingsFixture

    init?(arguments: [String]) {
        let prefix = "--stornaut-debug-settings="
        let matches = arguments.filter { $0.hasPrefix(prefix) }
        guard matches.count == 1,
              let fixture = DebugSettingsFixture(
                  rawValue: String(matches[0].dropFirst(prefix.count))
              )
        else {
            return nil
        }
        self.fixture = fixture
    }
}

enum DebugSettingsInitialSection {
    static func selection(arguments: [String]) -> SettingsSection {
        let prefix = "--stornaut-debug-settings-section="
        let matches = arguments.filter { $0.hasPrefix(prefix) }
        guard matches.count == 1,
              let section = SettingsSection(
                  rawValue: String(matches[0].dropFirst(prefix.count))
              )
        else {
            return .general
        }
        return section
    }
}

enum DebugSettingsLanguage {
    static func selection(arguments: [String]) -> SettingsLanguage {
        guard let index = arguments.firstIndex(of: "-AppleLanguages"),
              arguments.indices.contains(index + 1)
        else {
            return .english
        }
        return arguments[index + 1].contains("zh-Hans")
            ? .simplifiedChinese
            : .english
    }
}

struct DebugHistoryFixtureSelection: Sendable, Equatable {
    let fixture: DebugHistoryFixture

    init?(arguments: [String]) {
        let prefix = "--stornaut-debug-history="
        let matches = arguments.filter { $0.hasPrefix(prefix) }
        guard matches.count == 1,
              matches[0].count > prefix.count,
              let fixture = DebugHistoryFixture(
                  rawValue: String(matches[0].dropFirst(prefix.count))
              )
        else {
            return nil
        }
        self.fixture = fixture
    }
}

enum DebugInitialDestination {
    static func selection(
        arguments: [String]
    ) -> AppDestination {
        let prefix = "--stornaut-debug-destination="
        let matches = arguments.filter { $0.hasPrefix(prefix) }
        guard matches.count == 1,
              let destination = AppDestination(
                  rawValue: String(matches[0].dropFirst(prefix.count))
              )
        else {
            return .overview
        }
        return destination
    }
}

enum DebugHistoryInitialPresentation: String {
    case detail
    case trend

    static func selection(
        arguments: [String]
    ) -> DebugHistoryInitialPresentation {
        let prefix = "--stornaut-debug-history-presentation="
        let matches = arguments.filter { $0.hasPrefix(prefix) }
        guard matches.count == 1,
              let presentation = DebugHistoryInitialPresentation(
                  rawValue: String(matches[0].dropFirst(prefix.count))
              )
        else {
            return .detail
        }
        return presentation
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
        return try debugFixture(
            selection: selection,
            historySelection: DebugHistoryFixtureSelection(
                arguments: arguments
            ),
            settingsSelection: DebugSettingsFixtureSelection(
                arguments: arguments
            ),
            settingsLanguage: DebugSettingsLanguage.selection(
                arguments: arguments
            )
        )
    }

    static func debugFixture(
        selection: DebugAppFixtureSelection,
        historySelection: DebugHistoryFixtureSelection? = nil,
        settingsSelection: DebugSettingsFixtureSelection? = nil,
        settingsLanguage: SettingsLanguage = .english,
        makeState: @MainActor (DebugAppFixture) throws -> AppPageState = {
            try $0.makeState()
        }
    ) throws -> AppComposition {
        let state = try makeState(selection.fixture)
        let scanState = try selection.fixture.makeScanState(
            pageState: state
        )
        let initialHistory = try historySelection?.fixture.makeState()
            ?? .idle
        let historyStore = DebugHistoryStore(
            page: initialHistory.page ?? .empty
        )
        let initialSettings = try (
            settingsSelection?.fixture ?? .populated
        ).makeSnapshot(language: settingsLanguage)
        let settingsStore = DebugSettingsStore(snapshot: initialSettings)
        return AppComposition(
            model: StornautAppModel(
                dependencies: AppDependencies(
                    loadLatestQuickScan: { nil },
                    loadScanHistory: {
                        await historyStore.load()
                    },
                    deleteScanHistory: {
                        await historyStore.delete($0)
                    },
                    loadSettings: {
                        await settingsStore.load()
                    },
                    saveSettingsPreferences: {
                        await settingsStore.save($0)
                    },
                    clearSettingsEvidence: {
                        await settingsStore.clearEvidence()
                    },
                    clearSettingsManifests: {
                        await settingsStore.clearManifests()
                    },
                    forgetSettingsKnowledge: {
                        await settingsStore.forget($0)
                    },
                    forgetAllSettingsKnowledge: {
                        await settingsStore.forgetAll()
                    }
                ),
                initialState: state,
                initialScanActivity: scanState.isActive
                    ? .active
                    : .idle,
                initialScanState: scanState,
                initialHistoryState: initialHistory,
                initialSettingsState: .loaded(initialSettings),
                now: { DebugProjectionFactory.now },
                refreshesServices: false
            )
        )
    }
}

private extension DebugSettingsFixture {
    func makeSnapshot(
        language: SettingsLanguage
    ) throws -> SettingsSnapshot {
        let knowledge: [LocalKnowledgeFact]
        let corrupt: [String]
        switch self {
        case .populated:
            knowledge = try [
                DebugSettingsFactory.fact(
                    slug: "keep-derived-data",
                    scope: "/tmp/stornaut-settings-fixture/Projects/App/DerivedData",
                    payload: .keepDecision,
                    updatedOffset: -600
                ),
                DebugSettingsFactory.fact(
                    slug: "producer-cache",
                    scope: "/tmp/stornaut-settings-fixture/Library/Caches/build",
                    payload: .producerMapping(
                        ProducerMappingKnowledge(
                            producer: DomainLabel(rawValue: "Fixture Builder")!
                        )
                    ),
                    updatedOffset: -1_200
                ),
            ]
            corrupt = []
        case .empty,
             .codexMissing,
             .syntaxUnsupported,
             .runtimeStale,
             .runtimeFailed,
             .runtimeUnverified:
            knowledge = []
            corrupt = []
        case .corrupt:
            knowledge = try [
                DebugSettingsFactory.fact(
                    slug: "healthy",
                    scope: "/tmp/stornaut-settings-fixture/Cache",
                    payload: .keepDecision,
                    updatedOffset: -600
                ),
            ]
            corrupt = ["knowledge-fixture-unreadable"]
        }
        let exclusions = try [
            ScanExclusion(validating: "Library/Caches/npm"),
            ScanExclusion(validating: "Projects/Archived"),
        ]
        let codex: SettingsCodexStatus = switch self {
        case .codexMissing:
            .unavailable
        case .syntaxUnsupported:
            SettingsCodexStatus(
                availability: .installed,
                executablePath: PersistedPath(
                    rawValue: "/tmp/stornaut-settings-fixture/bin/codex"
                ),
                version: "codex-cli fixture",
                syntaxStatus: .unsupported
            )
        default:
            SettingsCodexStatus(
                availability: .installed,
                executablePath: PersistedPath(
                    rawValue: "/tmp/stornaut-settings-fixture/bin/codex"
                ),
                version: "codex-cli fixture",
                syntaxStatus: .supported
            )
        }
        let runtimeEvidence: SettingsRuntimeEvidence = switch self {
        case .runtimeStale:
            .staleR5
        case .runtimeFailed:
            .failed
        case .runtimeUnverified:
            .unverified
        default:
            .admittedR5
        }
        return SettingsSnapshot(
            preferences: try SettingsPreferences(
                language: language,
                exclusions: exclusions,
                investigationBudget: .balanced
            ),
            primaryRoot: SettingsPrimaryRootStatus(
                path: PersistedPath(
                    rawValue: "/tmp/stornaut-settings-fixture"
                )!,
                availability: .available
            ),
            diskAccess: .limited,
            codex: codex,
            runtimeEvidence: runtimeEvidence,
            counts: SettingsRecordCounts(
                evidence: 4,
                manifests: 2,
                localKnowledge: knowledge.count
            ),
            knowledge: knowledge,
            corruptKnowledgeIDs: corrupt,
            currentCatalogVersion: DomainToken(
                rawValue: "builtin-runtime-tool-residue-v1"
            )!,
            refreshedAt: DebugProjectionFactory.now
        )
    }
}

private enum DebugSettingsFactory {
    static func fact(
        slug: String,
        scope: String,
        payload: LocalKnowledgePayload,
        updatedOffset: TimeInterval
    ) throws -> LocalKnowledgeFact {
        let updatedAt = DebugProjectionFactory.now.addingTimeInterval(
            updatedOffset
        )
        return try LocalKnowledgeFact(
            id: LocalKnowledgeID(
                rawValue: "knowledge-settings-\(slug)"
            )!,
            payload: payload,
            binding: LocalKnowledgeBinding(
                scope: PersistedPath(rawValue: scope)!,
                fileIdentity: FileIdentity(
                    device: 1,
                    inode: UInt64(
                        slug.utf8.reduce(1) {
                            ($0 &* 31) &+ UInt64($1)
                        }
                    ),
                    mode: UInt16(S_IFDIR | 0o755),
                    ownerUserID: getuid(),
                    ownerGroupID: getgid(),
                    size: 0,
                    allocatedBytes: 0,
                    modificationSeconds: Int64(updatedAt.timeIntervalSince1970),
                    modificationNanoseconds: 0
                ),
                activityFingerprint: DomainToken(
                    rawValue: "activity.settings-fixture"
                )!,
                catalogVersion: DomainToken(
                    rawValue: "builtin-runtime-tool-residue-v1"
                )!
            ),
            provenance: .userConfirmed,
            observedAt: updatedAt,
            updatedAt: updatedAt
        )
    }
}

private actor DebugSettingsStore {
    private var snapshot: SettingsSnapshot

    init(snapshot: SettingsSnapshot) {
        self.snapshot = snapshot
    }

    func load() -> SettingsSnapshot {
        snapshot
    }

    func save(_ preferences: SettingsPreferences) {
        snapshot = snapshot.replacing(preferences: preferences)
    }

    func clearEvidence() {
        snapshot = snapshot.replacing(
            counts: SettingsRecordCounts(
                evidence: 0,
                manifests: snapshot.counts.manifests,
                localKnowledge: snapshot.counts.localKnowledge
            )
        )
    }

    func clearManifests() {
        snapshot = snapshot.replacing(
            counts: SettingsRecordCounts(
                evidence: snapshot.counts.evidence,
                manifests: 0,
                localKnowledge: snapshot.counts.localKnowledge
            )
        )
    }

    func forget(_ id: LocalKnowledgeID) {
        let knowledge = snapshot.knowledge.filter { $0.id != id }
        snapshot = snapshot.replacing(
            counts: SettingsRecordCounts(
                evidence: snapshot.counts.evidence,
                manifests: snapshot.counts.manifests,
                localKnowledge: knowledge.count
            ),
            knowledge: knowledge
        )
    }

    func forgetAll() {
        snapshot = snapshot.replacing(
            counts: SettingsRecordCounts(
                evidence: snapshot.counts.evidence,
                manifests: snapshot.counts.manifests,
                localKnowledge: 0
            ),
            knowledge: [],
            corruptKnowledgeIDs: []
        )
    }
}

private extension DebugHistoryFixture {
    func makeState() throws -> HistoryState {
        switch self {
        case .empty:
            return .loaded(.empty)
        case .populated:
            return .loaded(
                try DebugHistoryFactory.page(
                    slugs: ["current", "yesterday", "partial"]
                )
            )
        case .expired:
            return .loaded(
                try DebugHistoryFactory.page(
                    slugs: ["expired"],
                    expired: true
                )
            )
        case .corrupt:
            var page = try DebugHistoryFactory.page(
                slugs: ["healthy", "ledger-corrupt"]
            )
            page = HistoryPage(
                records: page.records,
                corruptSessionIDs: ["scan-fixture-unreadable"],
                corruptLedgerSessionIDs: [
                    page.records[1].session.id.rawValue,
                ]
            )
            return .loaded(page)
        case .trend:
            return .loaded(
                try DebugHistoryFactory.page(
                    slugs: ["trend-0", "trend-1", "trend-2", "trend-3"]
                )
            )
        }
    }
}

private enum DebugHistoryFactory {
    static func page(
        slugs: [String],
        expired: Bool = false
    ) throws -> HistoryPage {
        let records = try slugs.enumerated().map { index, slug in
            let terminal: ScanTerminalState = slug == "partial"
                ? .partial
                : .completed
            let projection = terminal == .partial
                ? try DebugProjectionFactory.partial(
                    slug: "history-\(slug)"
                )
                : try DebugProjectionFactory.success(
                    slug: "history-\(slug)"
                )
            let offset: TimeInterval
            if expired {
                offset = -8 * 86_400
            } else if slug == "yesterday" {
                offset = -26 * 3_600
            } else {
                offset = -TimeInterval(index) * 86_400
            }
            let finishedAt = DebugProjectionFactory.now
                .addingTimeInterval(offset)
            let session = try ScanSession(
                id: projection.session.id,
                startedAt: finishedAt.addingTimeInterval(-10),
                finishedAt: finishedAt,
                terminalState: terminal,
                completedScopes: terminal == .completed
                    ? projection.session.completedScopes.map {
                        ScanScope(
                            id: $0.id,
                            rootPath: $0.rootPath,
                            completedAt: finishedAt
                        )
                    }
                    : [],
                unfinishedScopes: terminal == .completed
                    ? []
                    : projection.session.unfinishedScopes
            )
            let ledger = try projection.ledger.map {
                try relabel($0, sessionID: session.id)
            }
            return HistoryRecord(session: session, ledger: ledger)
        }
        return HistoryPage(records: records)
    }

    private static func relabel(
        _ ledger: SpaceLedger,
        sessionID: ScanSessionID
    ) throws -> SpaceLedger {
        var object = try JSONSerialization.jsonObject(
            with: DomainJSON.encode(ledger)
        ) as! [String: Any]
        object["sessionID"] = sessionID.rawValue
        return try DomainJSON.decode(
            SpaceLedger.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
    }
}

private actor DebugHistoryStore {
    private var page: HistoryPage

    init(page: HistoryPage) {
        self.page = page
    }

    func load() -> HistoryPage {
        page
    }

    func delete(_ sessionID: ScanSessionID) {
        page = HistoryPage(
            records: page.records.filter {
                $0.session.id != sessionID
            },
            corruptSessionIDs: page.corruptSessionIDs,
            corruptLedgerSessionIDs:
                page.corruptLedgerSessionIDs.filter {
                    $0 != sessionID.rawValue
                }
        )
    }
}

private extension DebugAppFixture {
    func makeScanState(
        pageState: AppPageState
    ) throws -> ScanFlowState {
        guard self == .loading else {
            return pageState.projection.map(ScanFlowState.retained) ?? .idle
        }
        let projection = try DebugProjectionFactory.success(slug: rawValue)
        let reducer = ScanFlowReducer()
        var state = reducer.started(
            previous: .retained(projection),
            at: DebugProjectionFactory.now.addingTimeInterval(-8)
        )
        state = reducer.reduce(
            .stageChanged(.indexVolumes),
            state: state
        )
        state = reducer.reduce(
            .stageChanged(.mapProjects),
            state: state
        )
        state = reducer.reduce(
            .stageChanged(.classifyArtifacts),
            state: state
        )
        state = reducer.reduce(
            .progress(
                QuickScanProgress(
                    scopeID: projection.snapshots[0].scopeID,
                    currentRelativePath: PersistedPath(
                        rawValue: "Projects/App/DerivedData"
                    )!,
                    counters: ScanProgress(
                        completedEntries: 128,
                        regularFileCount: 83,
                        directoryCount: 41,
                        symlinkCount: 4,
                        errorCount: 0,
                        logicalFileBytes: 350_000,
                        allocatedFileBytes: 300_000
                    )
                )
            ),
            state: state
        )
        for classification in projection.classifications.prefix(3) {
            guard let snapshot = projection.snapshots.first(
                where: { $0.id == classification.snapshotID }
            ) else {
                continue
            }
            state = reducer.reduce(
                .classifiedSnapshotObserved(snapshot, classification),
                state: state
            )
        }
        for evidence in projection.evidence {
            state = reducer.reduce(
                .evidenceObserved(evidence),
                state: state
            )
        }
        return reducer.elapsed(
            state: state,
            at: DebugProjectionFactory.now
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

struct DebugScanStateProbe: NSViewRepresentable {
    let phase: ScanFlowPhase

    func makeNSView(context: Context) -> DebugScanStateProbeView {
        DebugScanStateProbeView(phase: phase)
    }

    func updateNSView(
        _ nsView: DebugScanStateProbeView,
        context: Context
    ) {
        nsView.phase = phase
    }
}

final class DebugScanStateProbeView: NSView {
    var phase: ScanFlowPhase {
        didSet { setAccessibilityLabel(phase.rawValue) }
    }

    init(phase: ScanFlowPhase) {
        self.phase = phase
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityIdentifier("scan.state.phase")
        setAccessibilityRole(.staticText)
        setAccessibilityLabel(phase.rawValue)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct DebugHistoryStateProbe: NSViewRepresentable {
    let phase: HistoryPhase

    func makeNSView(context: Context) -> DebugHistoryStateProbeView {
        DebugHistoryStateProbeView(phase: phase)
    }

    func updateNSView(
        _ nsView: DebugHistoryStateProbeView,
        context: Context
    ) {
        nsView.phase = phase
    }
}

final class DebugHistoryStateProbeView: NSView {
    var phase: HistoryPhase {
        didSet { setAccessibilityLabel(phase.rawValue) }
    }

    init(phase: HistoryPhase) {
        self.phase = phase
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityIdentifier("history.state.phase")
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
