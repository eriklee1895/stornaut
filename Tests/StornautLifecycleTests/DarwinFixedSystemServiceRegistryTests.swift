import Foundation
import Testing
@testable import StornautLifecycle

@Suite("Darwin fixed system service registry")
struct DarwinFixedSystemServiceRegistryTests {
    @Test
    func consistentRegistrationAndJobStatesAreAccepted() throws {
        let contract = try LifecycleLocalInstallationContract()

        #expect(registry(
            status: .notRegistered,
            job: .missing
        ).lookup() == .absent)
        #expect(registry(
            status: .notFound,
            job: .missing
        ).lookup() == .absent)
        #expect(registry(
            status: .enabled,
            job: .present(
                label: contract.label,
                processID: 702,
                fieldCount: 9
            )
        ).lookup() == .registered(processID: 702))
        #expect(registry(
            status: .enabled,
            job: .present(
                label: contract.label,
                processID: nil,
                fieldCount: 8
            )
        ).lookup() == .registered(processID: nil))
    }

    @Test
    func contradictoryOrMalformedStatesRemainUnavailable() throws {
        let contract = try LifecycleLocalInstallationContract()
        let unavailable = LifecycleFixedSystemServiceState.unavailable(
            reasonKey: "runtime.topology.service-registry-unavailable"
        )

        for candidate in [
            registry(status: .enabled, job: .missing).lookup(),
            registry(
                status: .notRegistered,
                job: .present(
                    label: contract.label,
                    processID: 702,
                    fieldCount: 9
                )
            ).lookup(),
            registry(
                status: .requiresApproval,
                job: .missing
            ).lookup(),
            registry(status: .unknown, job: .missing).lookup(),
            registry(
                status: .enabled,
                job: .present(
                    label: "foreign.service",
                    processID: 702,
                    fieldCount: 9
                )
            ).lookup(),
            registry(
                status: .enabled,
                job: .present(
                    label: contract.label,
                    processID: 1,
                    fieldCount: 9
                )
            ).lookup(),
            registry(
                status: .enabled,
                job: .present(
                    label: contract.label,
                    processID: Int64(Int32.max) + 1,
                    fieldCount: 9
                )
            ).lookup(),
            registry(
                status: .enabled,
                job: .present(
                    label: contract.label,
                    processID: 702,
                    fieldCount: 129
                )
            ).lookup(),
            registry(status: .enabled, job: .unavailable).lookup(),
        ] {
            #expect(candidate == unavailable)
        }
    }
}

private func registry(
    status: LifecycleFixedSystemServiceRegistrationStatus,
    job: LifecycleFixedSystemServiceJobLookup
) -> DarwinLifecycleFixedSystemServiceRegistry {
    DarwinLifecycleFixedSystemServiceRegistry(
        inspector: FixedSystemServiceInspector(
            status: status,
            job: job
        )
    )
}

private struct FixedSystemServiceInspector:
    LifecycleFixedSystemServiceInspecting
{
    let status: LifecycleFixedSystemServiceRegistrationStatus
    let job: LifecycleFixedSystemServiceJobLookup

    func registrationStatus(
        plistURL _: URL
    ) -> LifecycleFixedSystemServiceRegistrationStatus {
        status
    }

    func job(
        label _: String
    ) -> LifecycleFixedSystemServiceJobLookup {
        job
    }
}
