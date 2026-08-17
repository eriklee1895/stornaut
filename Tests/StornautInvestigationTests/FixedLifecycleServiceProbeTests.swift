import Darwin
import Foundation
import Testing
@testable import StornautInvestigationMachine
import StornautLifecycle

@Suite("Fixed lifecycle service probe")
struct FixedLifecycleServiceProbeTests {
    @Test
    func fixedRegistryLookupBindsTheExactExpectedHelper() throws {
        let fixture = try LifecycleTopologyCollectorFixture()
        let registry = ScriptedFixedServiceRegistry(
            results: [.registered(
                processID: fixture.helperIdentity.processID
            )]
        )
        let probe = DarwinFixedLifecycleServiceProbe(
            registry: registry,
            identityReader: FixedServiceIdentityReader(
                result: .success(fixture.helperIdentity)
            ),
            expectedIdentity: fixture.helperIdentity
        )

        #expect(
            probe.observeFixedService(
                label: fixture.contract.label
            ) == .loaded(identity: fixture.helperIdentity)
        )
        #expect(registry.labels == [fixture.contract.label])
    }

    @Test
    func onlyTheStructuredUnknownServiceResultProvesAbsence() throws {
        let fixture = try LifecycleTopologyCollectorFixture()

        #expect(
            DarwinFixedLifecycleServiceProbe(
                registry: ScriptedFixedServiceRegistry(
                    results: [.absent]
                ),
                identityReader: FixedServiceIdentityReader(
                    result: .failure(.invalidIdentity)
                ),
                expectedIdentity: fixture.helperIdentity
            ).observeFixedService(label: fixture.contract.label)
                == .absent
        )
        #expect(
            DarwinFixedLifecycleServiceProbe(
                registry: ScriptedFixedServiceRegistry(
                    results: [.unavailable(reasonKey: "probe.denied")]
                ),
                identityReader: FixedServiceIdentityReader(
                    result: .success(fixture.helperIdentity)
                ),
                expectedIdentity: fixture.helperIdentity
            ).observeFixedService(label: fixture.contract.label)
                == .unavailable(reasonKey: "probe.denied")
        )
    }

    @Test
    func foreignLabelIdentityReuseAndLookupFailureStayUnavailable() throws {
        let fixture = try LifecycleTopologyCollectorFixture()
        let reused = fixture.processIdentity(
            processID: fixture.helperIdentity.processID,
            processIDVersion: fixture.helperIdentity.processIDVersion + 1,
            auditSessionID: fixture.helperIdentity.auditSessionID,
            effectiveUserID: 0
        )
        let probe = DarwinFixedLifecycleServiceProbe(
            registry: ScriptedFixedServiceRegistry(
                results: [
                    .registered(processID: reused.processID + 100),
                    .registered(processID: reused.processID),
                    .registered(
                        processID: fixture.helperIdentity.processID
                    ),
                ]
            ),
            identityReader: FixedServiceIdentityReader(
                results: [
                    .success(reused),
                    .failure(.invalidIdentity),
                ]
            ),
            expectedIdentity: fixture.helperIdentity
        )

        #expect(
            probe.observeFixedService(label: "foreign.service")
                == .unavailable(
                    reasonKey: "runtime.topology.service-label-mismatch"
                )
        )
        #expect(
            probe.observeFixedService(label: fixture.contract.label)
                == .unavailable(
                    reasonKey: "runtime.topology.service-identity-mismatch"
                )
        )
        #expect(
            probe.observeFixedService(label: fixture.contract.label)
                == .unavailable(
                    reasonKey: "runtime.topology.service-identity-mismatch"
                )
        )
        #expect(
            probe.observeFixedService(label: fixture.contract.label)
                == .unavailable(
                    reasonKey: "runtime.topology.service-identity-unavailable"
                )
        )
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

private final class FixedServiceIdentityReader:
    LifecycleFixedServiceIdentityReading,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var results: [
        Result<LifecycleProcessIdentity, DarwinLifecycleSupportError>
    ]

    init(
        result: Result<
            LifecycleProcessIdentity,
            DarwinLifecycleSupportError
        >
    ) {
        results = [result]
    }

    init(
        results: [
            Result<
                LifecycleProcessIdentity,
                DarwinLifecycleSupportError
            >
        ]
    ) {
        self.results = results
    }

    func readExpectedIdentity()
        -> Result<LifecycleProcessIdentity, DarwinLifecycleSupportError>
    {
        readIdentity(processID: 2)
    }

    func readIdentity(
        processID _: pid_t
    )
        -> Result<LifecycleProcessIdentity, DarwinLifecycleSupportError>
    {
        lock.withLock {
            guard !results.isEmpty else {
                return .failure(.invalidIdentity)
            }
            return results.removeFirst()
        }
    }
}
