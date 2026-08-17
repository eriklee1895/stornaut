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

protocol LifecycleFixedServiceIdentityReading: Sendable {
    func readIdentity(
        processID: pid_t
    ) -> Result<LifecycleProcessIdentity, DarwinLifecycleSupportError>
}

struct DarwinFixedServiceIdentityReader:
    LifecycleFixedServiceIdentityReading,
    Sendable
{
    func readIdentity(
        processID: pid_t
    ) -> Result<LifecycleProcessIdentity, DarwinLifecycleSupportError> {
        do {
            return .success(
                try DarwinLifecycleInventory(
                    privilegedProcessID: getpid()
                ).identity(for: processID)
            )
        } catch let error as DarwinLifecycleSupportError {
            return .failure(error)
        } catch {
            return .failure(.invalidIdentity)
        }
    }
}

struct DarwinFixedLifecycleServiceProbe:
    LifecycleRootTopologyServiceProbing,
    Sendable
{
    private let registry: any LifecycleFixedServiceRegistryReading
    private let identityReader: any LifecycleFixedServiceIdentityReading
    private let expectedIdentity: LifecycleProcessIdentity

    init(
        registry: any LifecycleFixedServiceRegistryReading,
        identityReader: any LifecycleFixedServiceIdentityReading,
        expectedIdentity: LifecycleProcessIdentity
    ) {
        self.registry = registry
        self.identityReader = identityReader
        self.expectedIdentity = expectedIdentity
    }

    init(expectedIdentity: LifecycleProcessIdentity) {
        self.init(
            registry: DarwinFixedLifecycleServiceRegistry(),
            identityReader: DarwinFixedServiceIdentityReader(),
            expectedIdentity: expectedIdentity
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
        case let .registered(processID):
            guard let processID else {
                return .unavailable(
                    reasonKey: "runtime.topology.service-not-running"
                )
            }
            guard processID == expectedIdentity.processID else {
                return .unavailable(
                    reasonKey:
                        "runtime.topology.service-identity-mismatch"
                )
            }
            switch identityReader.readIdentity(
                processID: processID
            ) {
            case let .success(identity) where identity == expectedIdentity:
                return .loaded(identity: identity)
            case .success:
                return .unavailable(
                    reasonKey:
                        "runtime.topology.service-identity-mismatch"
                )
            case .failure:
                return .unavailable(
                    reasonKey:
                        "runtime.topology.service-identity-unavailable"
                )
            }
        }
    }
}
