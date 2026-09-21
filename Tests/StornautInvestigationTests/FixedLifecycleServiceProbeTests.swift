import Darwin
import Foundation
import Testing
@testable import StornautInvestigationMachine
import StornautLifecycle

@Suite("Fixed lifecycle service probe")
struct FixedLifecycleServiceProbeTests {
    @Test
    func onlyTheStructuredMissingStateProvesPostTeardownAbsence() throws {
        let fixture = try LifecycleTopologyCollectorFixture()
        let registry = ScriptedFixedServiceRegistry(
            results: [.absent]
        )
        let probe = DarwinPostTeardownLifecycleServiceProbe(
            registry: registry
        )

        #expect(
            probe.observeFixedService(
                label: fixture.contract.label
            ) == .absent
        )
        #expect(registry.labels == [fixture.contract.label])
    }

    @Test
    func registeredOrUnavailableServiceNeverProvesPostTeardown() throws {
        let fixture = try LifecycleTopologyCollectorFixture()
        let registry = ScriptedFixedServiceRegistry(results: [
            .registered(processID: nil),
            .registered(processID: fixture.helperIdentity.processID),
            .unavailable(reasonKey: "probe.denied"),
        ])
        let probe = DarwinPostTeardownLifecycleServiceProbe(
            registry: registry
        )

        #expect(
            probe.observeFixedService(label: fixture.contract.label)
                == .unavailable(
                    reasonKey: "runtime.topology.service-still-registered"
                )
        )
        #expect(
            probe.observeFixedService(label: fixture.contract.label)
                == .unavailable(
                    reasonKey: "runtime.topology.service-still-registered"
                )
        )
        #expect(
            probe.observeFixedService(label: fixture.contract.label)
                == .unavailable(reasonKey: "probe.denied")
        )
    }

    @Test
    func foreignLabelFailsBeforeRegistryLookup() throws {
        let registry = ScriptedFixedServiceRegistry(results: [.absent])
        let probe = DarwinPostTeardownLifecycleServiceProbe(
            registry: registry
        )

        #expect(
            probe.observeFixedService(label: "foreign.service")
                == .unavailable(
                    reasonKey: "runtime.topology.service-label-mismatch"
                )
        )
        #expect(registry.labels.isEmpty)
    }
}

private final class ScriptedFixedServiceRegistry:
    LifecycleFixedServiceRegistryReading,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var results: [LifecycleFixedServiceRegistryResult]
    private(set) var labels: [String] = []

    init(results: [LifecycleFixedServiceRegistryResult]) {
        self.results = results
    }

    func lookupFixedService(
        label: String
    ) -> LifecycleFixedServiceRegistryResult {
        lock.withLock {
            labels.append(label)
            guard !results.isEmpty else {
                return .unavailable(
                    reasonKey: "runtime.topology.service-registry-unavailable"
                )
            }
            return results.removeFirst()
        }
    }
}
