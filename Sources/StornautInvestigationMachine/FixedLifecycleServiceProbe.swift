import Darwin
import StornautLifecycle

enum LifecycleFixedServiceRegistryResult: Sendable, Equatable {
    case absent
    case registered(processID: pid_t?)
    case unavailable(reasonKey: String)
}

protocol LifecycleFixedServiceRegistryReading: Sendable {
    func lookupFixedService(
        label: String
    ) -> LifecycleFixedServiceRegistryResult
}

struct DarwinFixedLifecycleServiceRegistry:
    LifecycleFixedServiceRegistryReading,
    Sendable
{
    func lookupFixedService(
        label: String
    ) -> LifecycleFixedServiceRegistryResult {
        guard let contract = try? LifecycleLocalInstallationContract(),
              label == contract.label
        else {
            return .unavailable(
                reasonKey: "runtime.topology.service-label-mismatch"
            )
        }
        switch DarwinLifecycleFixedSystemServiceRegistry().lookup() {
        case .absent:
            return .absent
        case let .registered(processID):
            return .registered(processID: processID)
        case let .unavailable(reasonKey):
            return .unavailable(reasonKey: reasonKey)
        }
    }
}

struct DarwinPostTeardownLifecycleServiceProbe:
    LifecycleRootTopologyServiceProbing,
    Sendable
{
    private let registry: any LifecycleFixedServiceRegistryReading

    init(
        registry: any LifecycleFixedServiceRegistryReading
    ) {
        self.registry = registry
    }

    init() {
        self.init(
            registry: DarwinFixedLifecycleServiceRegistry()
        )
    }

    func observeFixedService(
        label: String
    ) -> LifecycleRootTopologyServiceProbeResult {
        guard let contract = try? LifecycleLocalInstallationContract(),
              label == contract.label
        else {
            return .unavailable(
                reasonKey: "runtime.topology.service-label-mismatch"
            )
        }
        switch registry.lookupFixedService(label: label) {
        case .absent:
            return .absent
        case let .unavailable(reasonKey):
            return .unavailable(reasonKey: reasonKey)
        case .registered:
            return .unavailable(
                reasonKey: "runtime.topology.service-still-registered"
            )
        }
    }
}
