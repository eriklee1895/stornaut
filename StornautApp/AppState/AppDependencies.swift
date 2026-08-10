import Foundation
import StornautCore

struct AppDependencies: Sendable {
    typealias CoordinatorFactory = @Sendable (
        LocalStoreConfiguration
    ) async throws -> QuickScanCoordinator

    let loadLatestQuickScan: @Sendable () async throws
        -> QuickScanProjection?

    init(
        loadLatestQuickScan: @escaping @Sendable () async throws
            -> QuickScanProjection?
    ) {
        self.loadLatestQuickScan = loadLatestQuickScan
    }

    static func live(
        configuration: LocalStoreConfiguration,
        makeCoordinator: @escaping CoordinatorFactory = {
            configuration in
            try await Task.detached(priority: .userInitiated) {
                let store = try EvidenceStore(configuration: configuration)
                return try QuickScanCoordinator(store: store)
            }.value
        }
    ) -> AppDependencies {
        let loader = AppQuickScanLoader {
            try await makeCoordinator(configuration)
        }
        return AppDependencies {
            try await loader.loadLatest()
        }
    }

    static func production() -> AppDependencies {
        let loader = AppQuickScanLoader {
            try await Task.detached(priority: .userInitiated) {
                let configuration = try LocalStoreConfiguration.production()
                let store = try EvidenceStore(configuration: configuration)
                return try QuickScanCoordinator(store: store)
            }.value
        }
        return AppDependencies {
            try await loader.loadLatest()
        }
    }
}

private actor AppQuickScanLoader {
    private struct CoordinatorFlight {
        let id: UInt64
        let task: Task<QuickScanCoordinator, Error>
    }

    private let makeCoordinator: @Sendable () async throws
        -> QuickScanCoordinator
    private var coordinator: QuickScanCoordinator?
    private var coordinatorFlight: CoordinatorFlight?
    private var nextFlightID: UInt64 = 0

    init(
        makeCoordinator: @escaping @Sendable () async throws
            -> QuickScanCoordinator
    ) {
        self.makeCoordinator = makeCoordinator
    }

    func loadLatest() async throws -> QuickScanProjection? {
        let coordinator = try await resolvedCoordinator()
        return try await coordinator.loadLatest()
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
