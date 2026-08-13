import AppKit
import Foundation
import StornautCore
import StornautCodex

struct AppDependencies: Sendable {
    typealias QuickScanStream = AsyncThrowingStream<
        QuickScanProductEvent,
        Error
    >
    typealias ReviewExecutionStream = AsyncStream<
        ReviewExecutionProgress
    >
    typealias CoordinatorFactory = @Sendable (
        EvidenceStore
    ) async throws -> QuickScanCoordinator
    struct QuickScanConfiguration: Sendable, Equatable {
        let rootPath: PersistedPath
        let exclusions: [ScanExclusion]
    }

    let loadLatestQuickScan: @Sendable () async throws
        -> QuickScanProjection?
    let startQuickScan: @Sendable () async throws -> QuickScanStream
    let cancelQuickScan: @Sendable () async -> Bool
    let quickScanRootPath: PersistedPath?
    let loadQuickScanConfiguration: @Sendable () async throws
        -> QuickScanConfiguration?
    let loadScanHistory: @Sendable () async throws -> HistoryPage
    let deleteScanHistory: @Sendable (ScanSessionID) async throws -> Void
    let loadSettings: @Sendable () async throws -> SettingsSnapshot
    let saveSettingsPreferences: @Sendable (
        SettingsPreferences
    ) async throws -> Void
    let clearSettingsEvidence: @Sendable () async throws -> Void
    let clearSettingsManifests: @Sendable () async throws -> Void
    let forgetSettingsKnowledge: @Sendable (
        LocalKnowledgeID
    ) async throws -> Void
    let forgetAllSettingsKnowledge: @Sendable () async throws -> Void
    let chooseSettingsPrimaryRoot: @Sendable () async throws
        -> SettingsPreferences?
    let chooseSettingsExclusion: @Sendable () async throws
        -> SettingsPreferences?
    let openFullDiskAccessSettings: @Sendable () async -> Bool
    let buildReview: @Sendable () async -> CleanupPlanBuildOutcome
    let preflightReview: @Sendable (
        CleanupPlan,
        ReviewSelection
    ) async throws -> CleanupPolicyEvaluation
    let reviewExecutionAvailability:
        ReviewExecutionAvailability
    let startReviewExecution: @Sendable (
        CleanupPlan,
        ReviewSelection,
        CleanupConfirmation
    ) async throws -> ReviewExecutionStream
    let stopReviewAfterCurrent: @Sendable () async -> Void

    init(
        loadLatestQuickScan: @escaping @Sendable () async throws
            -> QuickScanProjection?,
        startQuickScan: @escaping @Sendable () async throws
            -> QuickScanStream = {
                throw AppDependencyError.quickScanUnavailable
            },
        cancelQuickScan: @escaping @Sendable () async -> Bool = {
            false
        },
        quickScanRootPath: PersistedPath? = nil,
        loadQuickScanConfiguration: @escaping @Sendable () async throws
            -> QuickScanConfiguration? = {
                nil
            },
        loadScanHistory: @escaping @Sendable () async throws
            -> HistoryPage = {
                throw AppDependencyError.historyUnavailable
            },
        deleteScanHistory: @escaping @Sendable (
            ScanSessionID
        ) async throws -> Void = { _ in
            throw AppDependencyError.historyUnavailable
        },
        loadSettings: @escaping @Sendable () async throws
            -> SettingsSnapshot = {
                throw AppDependencyError.settingsUnavailable
            },
        saveSettingsPreferences: @escaping @Sendable (
            SettingsPreferences
        ) async throws -> Void = { _ in
            throw AppDependencyError.settingsUnavailable
        },
        clearSettingsEvidence: @escaping @Sendable () async throws
            -> Void = {
                throw AppDependencyError.settingsUnavailable
            },
        clearSettingsManifests: @escaping @Sendable () async throws
            -> Void = {
                throw AppDependencyError.settingsUnavailable
            },
        forgetSettingsKnowledge: @escaping @Sendable (
            LocalKnowledgeID
        ) async throws -> Void = { _ in
            throw AppDependencyError.settingsUnavailable
        },
        forgetAllSettingsKnowledge: @escaping @Sendable () async throws
            -> Void = {
                throw AppDependencyError.settingsUnavailable
            },
        chooseSettingsPrimaryRoot: @escaping @Sendable () async throws
            -> SettingsPreferences? = {
                throw AppDependencyError.settingsUnavailable
            },
        chooseSettingsExclusion: @escaping @Sendable () async throws
            -> SettingsPreferences? = {
                throw AppDependencyError.settingsUnavailable
            },
        openFullDiskAccessSettings: @escaping @Sendable () async
            -> Bool = {
                false
        },
        buildReview: @escaping @Sendable () async
            -> CleanupPlanBuildOutcome = {
            .unavailable([
                DomainToken(
                    rawValue: "review.unavailable.service"
                )!,
            ])
        },
        preflightReview: @escaping @Sendable (
            CleanupPlan,
            ReviewSelection
        ) async throws -> CleanupPolicyEvaluation = { _, _ in
            throw AppDependencyError.reviewUnavailable
        },
        reviewExecutionAvailability:
            ReviewExecutionAvailability = .writeDisabled,
        startReviewExecution: @escaping @Sendable (
            CleanupPlan,
            ReviewSelection,
            CleanupConfirmation
        ) async throws -> ReviewExecutionStream = { _, _, _ in
            throw AppDependencyError.reviewExecutionDisabled
        },
        stopReviewAfterCurrent: @escaping @Sendable () async -> Void = {}
    ) {
        self.loadLatestQuickScan = loadLatestQuickScan
        self.startQuickScan = startQuickScan
        self.cancelQuickScan = cancelQuickScan
        self.quickScanRootPath = quickScanRootPath
        self.loadQuickScanConfiguration = loadQuickScanConfiguration
        self.loadScanHistory = loadScanHistory
        self.deleteScanHistory = deleteScanHistory
        self.loadSettings = loadSettings
        self.saveSettingsPreferences = saveSettingsPreferences
        self.clearSettingsEvidence = clearSettingsEvidence
        self.clearSettingsManifests = clearSettingsManifests
        self.forgetSettingsKnowledge = forgetSettingsKnowledge
        self.forgetAllSettingsKnowledge = forgetAllSettingsKnowledge
        self.chooseSettingsPrimaryRoot = chooseSettingsPrimaryRoot
        self.chooseSettingsExclusion = chooseSettingsExclusion
        self.openFullDiskAccessSettings = openFullDiskAccessSettings
        self.buildReview = buildReview
        self.preflightReview = preflightReview
        self.reviewExecutionAvailability =
            reviewExecutionAvailability
        self.startReviewExecution = startReviewExecution
        self.stopReviewAfterCurrent = stopReviewAfterCurrent
    }

    static func live(
        configuration: LocalStoreConfiguration,
        rootURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        makeCoordinator: @escaping CoordinatorFactory = { store in
            try QuickScanCoordinator(store: store)
        }
    ) -> AppDependencies {
        let standardizedRoot = rootURL.standardizedFileURL
        let runtime = AppQuickScanRuntime(rootURL: standardizedRoot) {
            store in
            try await makeCoordinator(store)
        } makeEvidenceStore: {
            try EvidenceStore(configuration: configuration)
        } makePreferencesStore: {
            try SettingsPreferencesStore(configuration: configuration)
        } makeKnowledgeStore: {
            try LocalKnowledgeStore(configuration: configuration)
        }
        return AppDependencies(
            loadLatestQuickScan: {
                try await runtime.loadLatest()
            },
            startQuickScan: {
                try await runtime.start()
            },
            cancelQuickScan: {
                await runtime.cancel()
            },
            quickScanRootPath: PersistedPath(
                rawValue: standardizedRoot.path
            ),
            loadQuickScanConfiguration: {
                try await runtime.quickScanConfiguration()
            },
            loadScanHistory: {
                try await runtime.loadHistory()
            },
            deleteScanHistory: {
                try await runtime.deleteHistory(id: $0)
            },
            loadSettings: {
                try await runtime.loadSettings()
            },
            saveSettingsPreferences: {
                try await runtime.saveSettingsPreferences($0)
            },
            clearSettingsEvidence: {
                try await runtime.clearEvidence()
            },
            clearSettingsManifests: {
                try await runtime.clearManifests()
            },
            forgetSettingsKnowledge: {
                try await runtime.forgetKnowledge(id: $0)
            },
            forgetAllSettingsKnowledge: {
                try await runtime.forgetAllKnowledge()
            },
            chooseSettingsPrimaryRoot: {
                try await choosePrimaryRoot(using: runtime)
            },
            chooseSettingsExclusion: {
                try await chooseExclusion(using: runtime)
            },
            openFullDiskAccessSettings: {
                await openFullDiskAccessPane()
            },
            buildReview: {
                await runtime.buildReview()
            },
            preflightReview: {
                try await runtime.preflightReview(
                    plan: $0,
                    selection: $1
                )
            }
        )
    }

    static func production() -> AppDependencies {
        let rootURL = FileManager.default.homeDirectoryForCurrentUser
            .standardizedFileURL
        let runtime = AppQuickScanRuntime(
            rootURL: rootURL
        ) { store in
            try await Task.detached(priority: .userInitiated) {
                return try QuickScanCoordinator(store: store)
            }.value
        } makeEvidenceStore: {
            try await Task.detached(priority: .userInitiated) {
                try EvidenceStore(
                    configuration: LocalStoreConfiguration.production()
                )
            }.value
        } makePreferencesStore: {
            try await Task.detached(priority: .userInitiated) {
                try SettingsPreferencesStore(
                    configuration: LocalStoreConfiguration.production()
                )
            }.value
        } makeKnowledgeStore: {
            try await Task.detached(priority: .userInitiated) {
                try LocalKnowledgeStore(
                    configuration: LocalStoreConfiguration.production()
                )
            }.value
        }
        return AppDependencies(
            loadLatestQuickScan: {
                try await runtime.loadLatest()
            },
            startQuickScan: {
                try await runtime.start()
            },
            cancelQuickScan: {
                await runtime.cancel()
            },
            quickScanRootPath: PersistedPath(rawValue: rootURL.path),
            loadQuickScanConfiguration: {
                try await runtime.quickScanConfiguration()
            },
            loadScanHistory: {
                try await runtime.loadHistory()
            },
            deleteScanHistory: {
                try await runtime.deleteHistory(id: $0)
            },
            loadSettings: {
                try await runtime.loadSettings()
            },
            saveSettingsPreferences: {
                try await runtime.saveSettingsPreferences($0)
            },
            clearSettingsEvidence: {
                try await runtime.clearEvidence()
            },
            clearSettingsManifests: {
                try await runtime.clearManifests()
            },
            forgetSettingsKnowledge: {
                try await runtime.forgetKnowledge(id: $0)
            },
            forgetAllSettingsKnowledge: {
                try await runtime.forgetAllKnowledge()
            },
            chooseSettingsPrimaryRoot: {
                try await choosePrimaryRoot(using: runtime)
            },
            chooseSettingsExclusion: {
                try await chooseExclusion(using: runtime)
            },
            openFullDiskAccessSettings: {
                await openFullDiskAccessPane()
            },
            buildReview: {
                await runtime.buildReview()
            },
            preflightReview: {
                try await runtime.preflightReview(
                    plan: $0,
                    selection: $1
                )
            }
        )
    }
}

private actor AppQuickScanRuntime {
    enum RuntimeError: Error {
        case configuredRootUnavailable
    }

    private struct CoordinatorFlight {
        let id: UInt64
        let task: Task<QuickScanCoordinator, Error>
    }

    private struct EvidenceStoreFlight {
        let id: UInt64
        let task: Task<EvidenceStore, Error>
    }

    private let makeCoordinator: @Sendable (EvidenceStore) async throws
        -> QuickScanCoordinator
    private let makeEvidenceStore: @Sendable () async throws
        -> EvidenceStore
    private let makePreferencesStore: @Sendable () async throws
        -> SettingsPreferencesStore
    private let makeKnowledgeStore: @Sendable () async throws
        -> LocalKnowledgeStore
    private let rootURL: URL
    private var coordinator: QuickScanCoordinator?
    private var coordinatorFlight: CoordinatorFlight?
    private var nextFlightID: UInt64 = 0
    private var evidenceStoreFlight: EvidenceStoreFlight?
    private var nextEvidenceStoreFlightID: UInt64 = 0
    private var preferencesStore: SettingsPreferencesStore?
    private var knowledgeStore: LocalKnowledgeStore?
    private var evidenceStore: EvidenceStore?
    private let workflowCoordinator = CleanupWorkflowCoordinator()
    private let codexDetector = CodexRuntimeCapabilityDetector()

    init(
        rootURL: URL,
        makeCoordinator: @escaping @Sendable (
            EvidenceStore
        ) async throws
            -> QuickScanCoordinator,
        makeEvidenceStore: @escaping @Sendable () async throws
            -> EvidenceStore,
        makePreferencesStore: @escaping @Sendable () async throws
            -> SettingsPreferencesStore,
        makeKnowledgeStore: @escaping @Sendable () async throws
            -> LocalKnowledgeStore
    ) {
        self.rootURL = rootURL.standardizedFileURL
        self.makeCoordinator = makeCoordinator
        self.makeEvidenceStore = makeEvidenceStore
        self.makePreferencesStore = makePreferencesStore
        self.makeKnowledgeStore = makeKnowledgeStore
    }

    func loadLatest() async throws -> QuickScanProjection? {
        let coordinator = try await resolvedCoordinator()
        return try await coordinator.loadLatest()
    }

    func start() async throws -> AppDependencies.QuickScanStream {
        let workflowLease = try await workflowCoordinator.acquire(
            .quickScan
        )
        do {
            let coordinator = try await resolvedCoordinator()
            let preferences = try await resolvedPreferencesStore().load()
            let resolvedRoot = SettingsPrimaryRoot.resolve(
                preferences.primaryRoot,
                fallbackURL: rootURL
            )
            if preferences.primaryRoot != nil,
               resolvedRoot.status != .available
            {
                throw RuntimeError.configuredRootUnavailable
            }
            let stream = try await coordinator.start(
                ScanRequest(
                    rootURL: resolvedRoot.rootURL,
                    exclusions: preferences.exclusions
                )
            )
            return retaining(
                stream,
                lease: resolvedRoot.accessLease,
                workflowCoordinator: workflowCoordinator,
                workflowLease: workflowLease
            )
        } catch {
            await workflowCoordinator.release(workflowLease)
            throw error
        }
    }

    func quickScanConfiguration() async throws
        -> AppDependencies.QuickScanConfiguration
    {
        let preferences = try await resolvedPreferencesStore().load()
        let resolvedRoot = SettingsPrimaryRoot.resolve(
            preferences.primaryRoot,
            fallbackURL: rootURL,
            acquireAccess: false
        )
        return AppDependencies.QuickScanConfiguration(
            rootPath: preferences.primaryRoot?.displayPath
                ?? PersistedPath(rawValue: resolvedRoot.rootURL.path)!,
            exclusions: preferences.exclusions
        )
    }

    func cancel() async -> Bool {
        guard let coordinator else {
            return false
        }
        return await coordinator.cancel()
    }

    func loadHistory() async throws -> HistoryPage {
        let coordinator = try await resolvedCoordinator()
        let page = try await coordinator.loadHistory()
        return HistoryPage(
            records: page.sessions.map {
                HistoryRecord(
                    session: $0,
                    ledger: page.ledgersBySessionID[$0.id]
                )
            },
            corruptSessionIDs: page.corruptSessionIDs,
            corruptLedgerSessionIDs: page.corruptLedgerSessionIDs
        )
    }

    func deleteHistory(id: ScanSessionID) async throws {
        try await withWorkflowLease(.historyMutation) {
            let coordinator = try await resolvedCoordinator()
            try await coordinator.deleteHistorySession(id: id)
        }
    }

    func buildReview() async -> CleanupPlanBuildOutcome {
        do {
            let preferences = try await resolvedPreferencesStore().load()
            let resolvedRoot = SettingsPrimaryRoot.resolve(
                preferences.primaryRoot,
                fallbackURL: rootURL
            )
            guard resolvedRoot.status == .available
                    || resolvedRoot.status == .fallbackHome
            else {
                return .unavailable([
                    DomainToken(
                        rawValue: "review.unavailable.root"
                    )!,
                ])
            }
            let store = try await resolvedEvidenceStore()
            guard let sessionID = try await resolvedCoordinator()
                .loadLatest()?.session.id
            else {
                return .unavailable([
                    DomainToken(
                        rawValue: "review.unavailable.no-snapshot"
                    )!,
                ])
            }
            let builder = try CleanupPlanBuilder(store: store)
            let result = await builder.build(
                sessionID: sessionID,
                rootURL: resolvedRoot.rootURL
            )
            withExtendedLifetime(resolvedRoot.accessLease) {}
            return result
        } catch {
            return .unavailable([
                DomainToken(
                    rawValue: "review.unavailable.persisted-truth"
                )!,
            ])
        }
    }

    func preflightReview(
        plan: CleanupPlan,
        selection: ReviewSelection
    ) async throws -> CleanupPolicyEvaluation {
        let preferences = try await resolvedPreferencesStore().load()
        let resolvedRoot = SettingsPrimaryRoot.resolve(
            preferences.primaryRoot,
            fallbackURL: rootURL
        )
        guard resolvedRoot.status == .available
                || resolvedRoot.status == .fallbackHome
        else {
            throw AppDependencyError.reviewUnavailable
        }
        let store = try await resolvedEvidenceStore()
        let observer = AppCleanupPolicyRootObserver(
            observation: CleanupPolicyRootObservation(
                rootURL: resolvedRoot.rootURL,
                access: resolvedRoot.accessLease.map {
                    .securityScoped($0)
                } ?? .direct
            )
        )
        let collector = try CleanupPolicyContextCollector(
            store: store,
            rootObserver: observer,
            workflowObserver: workflowCoordinator
        )
        let outcome = await collector.collect(
            plan: plan,
            selection: selection
        )
        guard let context = outcome.context else {
            throw AppDependencyError.reviewUnavailable
        }
        return try CleanupPolicyGate().evaluate(
            plan: plan,
            selection: selection,
            context: context,
            evaluatedAt: Date()
        )
    }

    func loadSettings() async throws -> SettingsSnapshot {
        let preferences = try await resolvedPreferencesStore().load()
        let root = SettingsPrimaryRoot.resolve(
            preferences.primaryRoot,
            fallbackURL: rootURL,
            acquireAccess: false
        )
        let counts = try await resolvedCoordinator().loadRecordCounts()
        let knowledge = try await resolvedKnowledgeStore().facts(
            limit: 100,
            offset: 0
        )
        let knowledgeCount = try await resolvedKnowledgeStore().recordCount()
        let codex = await codexStatus()
        let catalog = try BuiltInRuleCatalog.load()
        return SettingsSnapshot(
            preferences: preferences,
            primaryRoot: SettingsPrimaryRootStatus(
                path: preferences.primaryRoot?.displayPath
                    ?? PersistedPath(rawValue: root.rootURL.path)!,
                availability: root.status
            ),
            diskAccess: .limited,
            codex: codex,
            runtimeEvidence: .admittedR5,
            counts: SettingsRecordCounts(
                evidence: counts.evidenceSessions,
                manifests: counts.manifests,
                localKnowledge: knowledgeCount
            ),
            knowledge: knowledge.records,
            corruptKnowledgeIDs: knowledge.corruptRecordIDs,
            currentCatalogVersion: catalog.catalogVersion,
            refreshedAt: Date()
        )
    }

    func saveSettingsPreferences(
        _ preferences: SettingsPreferences
    ) async throws {
        try await withWorkflowLease(.settingsMutation) {
            try await resolvedPreferencesStore().save(preferences)
        }
    }

    func loadSettingsPreferences() async throws -> SettingsPreferences {
        try await resolvedPreferencesStore().load()
    }

    func resolvedSettingsRoot(
        preferences: SettingsPreferences
    ) -> ResolvedSettingsPrimaryRoot {
        SettingsPrimaryRoot.resolve(
            preferences.primaryRoot,
            fallbackURL: rootURL,
            acquireAccess: false
        )
    }

    func clearEvidence() async throws {
        try await withWorkflowLease(.settingsMutation) {
            try await resolvedCoordinator().clearEvidenceRecords()
        }
    }

    func clearManifests() async throws {
        try await withWorkflowLease(.settingsMutation) {
            try await resolvedCoordinator().clearManifestRecords()
        }
    }

    func forgetKnowledge(id: LocalKnowledgeID) async throws {
        try await withWorkflowLease(.settingsMutation) {
            try await resolvedKnowledgeStore().forget(id: id)
        }
    }

    func forgetAllKnowledge() async throws {
        try await withWorkflowLease(.settingsMutation) {
            try await resolvedKnowledgeStore().forgetAll()
        }
    }

    private func resolvedPreferencesStore() async throws
        -> SettingsPreferencesStore
    {
        if let preferencesStore {
            return preferencesStore
        }
        let created = try await makePreferencesStore()
        preferencesStore = created
        return created
    }

    private func resolvedEvidenceStore() async throws -> EvidenceStore {
        if let evidenceStore {
            return evidenceStore
        }
        let flight = evidenceStoreTask()
        do {
            let created = try await flight.task.value
            evidenceStore = created
            if evidenceStoreFlight?.id == flight.id {
                evidenceStoreFlight = nil
            }
            return created
        } catch {
            if evidenceStoreFlight?.id == flight.id {
                evidenceStoreFlight = nil
            }
            throw error
        }
    }

    private func resolvedKnowledgeStore() async throws
        -> LocalKnowledgeStore
    {
        if let knowledgeStore {
            return knowledgeStore
        }
        let created = try await makeKnowledgeStore()
        knowledgeStore = created
        return created
    }

    private func codexStatus() async -> SettingsCodexStatus {
        let environment = ProcessInfo.processInfo.environment
        let availability = await CodexLocator().locate(
            configuredURL: nil,
            environment: environment
        )
        guard let installation = availability.installation else {
            return .unavailable
        }
        do {
            let report = try await codexDetector.report(
                executableURL: installation.executableURL,
                environment: environment
            )
            let syntax: SettingsCodexSyntaxStatus =
                report.isSyntaxCompatible
                    ? .supported
                    : .unsupported
            return SettingsCodexStatus(
                availability: .installed,
                executablePath: PersistedPath(
                    rawValue: report.executableURL.path
                ),
                version: report.version,
                syntaxStatus: syntax
            )
        } catch {
            return SettingsCodexStatus(
                availability: .checkFailed,
                executablePath: PersistedPath(
                    rawValue: installation.executableURL.path
                ),
                version: nil,
                syntaxStatus: .unverified
            )
        }
    }

    private func resolvedCoordinator() async throws -> QuickScanCoordinator {
        if let coordinator {
            return coordinator
        }
        let flight: CoordinatorFlight
        if let coordinatorFlight {
            flight = coordinatorFlight
        } else {
            let makeCoordinator = self.makeCoordinator
            let storeFlight = evidenceStoreTask()
            let createdTask = Task {
                let store = try await storeFlight.task.value
                return try await makeCoordinator(store)
            }
            flight = CoordinatorFlight(
                id: nextFlightID,
                task: createdTask
            )
            nextFlightID &+= 1
            coordinatorFlight = flight
        }
        do {
            let created = try await flight.task.value
            if evidenceStore == nil,
               let storeFlight = evidenceStoreFlight
            {
                let store = try await storeFlight.task.value
                evidenceStore = store
                if evidenceStoreFlight?.id == storeFlight.id {
                    evidenceStoreFlight = nil
                }
            }
            coordinator = created
            if coordinatorFlight?.id == flight.id {
                coordinatorFlight = nil
            }
            return created
        } catch {
            if coordinatorFlight?.id == flight.id {
                coordinatorFlight = nil
            }
            if evidenceStore == nil {
                evidenceStoreFlight = nil
            }
            throw error
        }
    }

    private func evidenceStoreTask() -> EvidenceStoreFlight {
        if let evidenceStoreFlight {
            return evidenceStoreFlight
        }
        if let evidenceStore {
            return EvidenceStoreFlight(
                id: nextEvidenceStoreFlightID,
                task: Task { evidenceStore }
            )
        }
        let makeEvidenceStore = self.makeEvidenceStore
        let flight = EvidenceStoreFlight(
            id: nextEvidenceStoreFlightID,
            task: Task {
                try await makeEvidenceStore()
            }
        )
        nextEvidenceStoreFlightID &+= 1
        evidenceStoreFlight = flight
        return flight
    }

    private func withWorkflowLease<Result: Sendable>(
        _ conflict: CleanupWorkflowConflict,
        operation: () async throws -> Result
    ) async throws -> Result {
        let lease = try await workflowCoordinator.acquire(conflict)
        do {
            let result = try await operation()
            await workflowCoordinator.release(lease)
            return result
        } catch {
            await workflowCoordinator.release(lease)
            throw error
        }
    }
}

private func retaining(
    _ stream: AppDependencies.QuickScanStream,
    lease: SettingsPrimaryRootAccessLease?,
    workflowCoordinator: CleanupWorkflowCoordinator,
    workflowLease: CleanupWorkflowLease
) -> AppDependencies.QuickScanStream {
    AsyncThrowingStream { continuation in
        let task = Task {
            do {
                for try await event in stream {
                    continuation.yield(event)
                }
                withExtendedLifetime(lease) {}
                await workflowCoordinator.release(workflowLease)
                continuation.finish()
            } catch {
                withExtendedLifetime(lease) {}
                await workflowCoordinator.release(workflowLease)
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { @Sendable _ in
            task.cancel()
        }
    }
}

@MainActor
private func choosePrimaryRoot(
    using runtime: AppQuickScanRuntime
) async throws -> SettingsPreferences? {
    guard let selected = chooseDirectory(
        prompt: localized("settings.scanning.chooseRootPrompt")
    ) else {
        return nil
    }
    let didStart = selected.startAccessingSecurityScopedResource()
    defer {
        if didStart {
            selected.stopAccessingSecurityScopedResource()
        }
    }
    let bookmark = try SettingsPrimaryRoot.bookmark(for: selected)
    let current = try await runtime.loadSettingsPreferences()
    let updated = try current.replacing(
        primaryRoot: .some(bookmark),
        exclusions: []
    )
    try await runtime.saveSettingsPreferences(updated)
    return updated
}

@MainActor
private func chooseExclusion(
    using runtime: AppQuickScanRuntime
) async throws -> SettingsPreferences? {
    let current = try await runtime.loadSettingsPreferences()
    let resolvedRoot = await runtime.resolvedSettingsRoot(
        preferences: current
    )
    guard resolvedRoot.status == .available
        || resolvedRoot.status == .fallbackHome
    else {
        throw AppQuickScanRuntime.RuntimeError.configuredRootUnavailable
    }
    guard let selected = chooseDirectory(
        prompt: localized("settings.scanning.chooseExclusionPrompt"),
        directory: resolvedRoot.rootURL
    ) else {
        return nil
    }
    let exclusion = try ScanExclusion(
        selectedURL: selected,
        relativeTo: resolvedRoot.rootURL
    )
    let updated = try current.replacing(
        exclusions: current.exclusions + [exclusion]
    )
    try await runtime.saveSettingsPreferences(updated)
    return updated
}

@MainActor
private func chooseDirectory(
    prompt: String,
    directory: URL? = nil
) -> URL? {
    let panel = NSOpenPanel()
    panel.message = prompt
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = false
    panel.resolvesAliases = true
    panel.directoryURL = directory
    return panel.runModal() == .OK
        ? panel.url
        : nil
}

@MainActor
private func openFullDiskAccessPane() -> Bool {
    guard let url = URL(
        string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
    ) else {
        return false
    }
    return NSWorkspace.shared.open(url)
}

private enum AppDependencyError: Error {
    case quickScanUnavailable
    case historyUnavailable
    case settingsUnavailable
    case reviewUnavailable
    case reviewExecutionDisabled
}

private struct AppCleanupPolicyRootObserver:
    CleanupPolicyRootObserving
{
    let observation: CleanupPolicyRootObservation

    func observeRoot() async -> CleanupPolicyRootObservation {
        observation
    }
}

@MainActor
struct AppComposition {
    let model: StornautAppModel

    static func production() -> AppComposition {
        AppComposition(
            model: StornautAppModel(
                dependencies: .production()
            )
        )
    }
}
