import Foundation
import StornautCore

struct AppDependencies: Sendable {
    typealias QuickScanStream = AsyncThrowingStream<
        QuickScanProductEvent,
        Error
    >
    typealias CoordinatorFactory = @Sendable (
        LocalStoreConfiguration
    ) async throws -> QuickScanCoordinator

    let loadLatestQuickScan: @Sendable () async throws
        -> QuickScanProjection?
    let startQuickScan: @Sendable () async throws -> QuickScanStream
    let cancelQuickScan: @Sendable () async -> Bool
    let quickScanRootPath: PersistedPath?
    let loadScanHistory: @Sendable () async throws -> HistoryPage
    let deleteScanHistory: @Sendable (ScanSessionID) async throws -> Void

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
        loadScanHistory: @escaping @Sendable () async throws
            -> HistoryPage = {
                throw AppDependencyError.historyUnavailable
            },
        deleteScanHistory: @escaping @Sendable (
            ScanSessionID
        ) async throws -> Void = { _ in
            throw AppDependencyError.historyUnavailable
        }
    ) {
        self.loadLatestQuickScan = loadLatestQuickScan
        self.startQuickScan = startQuickScan
        self.cancelQuickScan = cancelQuickScan
        self.quickScanRootPath = quickScanRootPath
        self.loadScanHistory = loadScanHistory
        self.deleteScanHistory = deleteScanHistory
    }

    static func live(
        configuration: LocalStoreConfiguration,
        rootURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        makeCoordinator: @escaping CoordinatorFactory = {
            configuration in
            try await Task.detached(priority: .userInitiated) {
                let store = try EvidenceStore(configuration: configuration)
                return try QuickScanCoordinator(store: store)
            }.value
        }
    ) -> AppDependencies {
        let standardizedRoot = rootURL.standardizedFileURL
        let runtime = AppQuickScanRuntime(rootURL: standardizedRoot) {
            try await makeCoordinator(configuration)
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
            loadScanHistory: {
                try await runtime.loadHistory()
            },
            deleteScanHistory: {
                try await runtime.deleteHistory(id: $0)
            }
        )
    }

    static func production() -> AppDependencies {
        let rootURL = FileManager.default.homeDirectoryForCurrentUser
            .standardizedFileURL
        let runtime = AppQuickScanRuntime(
            rootURL: rootURL
        ) {
            try await Task.detached(priority: .userInitiated) {
                let configuration = try LocalStoreConfiguration.production()
                let store = try EvidenceStore(configuration: configuration)
                return try QuickScanCoordinator(store: store)
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
            loadScanHistory: {
                try await runtime.loadHistory()
            },
            deleteScanHistory: {
                try await runtime.deleteHistory(id: $0)
            }
        )
    }
}

private actor AppQuickScanRuntime {
    private struct CoordinatorFlight {
        let id: UInt64
        let task: Task<QuickScanCoordinator, Error>
    }

    private let makeCoordinator: @Sendable () async throws
        -> QuickScanCoordinator
    private let rootURL: URL
    private var coordinator: QuickScanCoordinator?
    private var coordinatorFlight: CoordinatorFlight?
    private var nextFlightID: UInt64 = 0

    init(
        rootURL: URL,
        makeCoordinator: @escaping @Sendable () async throws
            -> QuickScanCoordinator
    ) {
        self.rootURL = rootURL.standardizedFileURL
        self.makeCoordinator = makeCoordinator
    }

    func loadLatest() async throws -> QuickScanProjection? {
        let coordinator = try await resolvedCoordinator()
        return try await coordinator.loadLatest()
    }

    func start() async throws -> AppDependencies.QuickScanStream {
        let coordinator = try await resolvedCoordinator()
        return try await coordinator.start(
            ScanRequest(rootURL: rootURL)
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
        let coordinator = try await resolvedCoordinator()
        try await coordinator.deleteHistorySession(id: id)
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
            let createdTask = Task {
                try await makeCoordinator()
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
            coordinator = created
            if coordinatorFlight?.id == flight.id {
                coordinatorFlight = nil
            }
            return created
        } catch {
            if coordinatorFlight?.id == flight.id {
                coordinatorFlight = nil
            }
            throw error
        }
    }
}

private enum AppDependencyError: Error {
    case quickScanUnavailable
    case historyUnavailable
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
