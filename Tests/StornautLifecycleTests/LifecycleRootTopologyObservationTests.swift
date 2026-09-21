import Darwin
import Foundation
import Testing
@testable import StornautLifecycle

@Suite("Lifecycle root topology observation")
struct LifecycleRootTopologyObservationTests {
    @Test
    func exactAbsenceOnlyObservationProvesPostTeardown() throws {
        let fixture = RootTopologyFixture()
        let observation = try fixture.observe(
            artifacts: .all(.absent),
            app: .identityReused,
            helper: .absent,
            service: .absent
        )

        #expect(LifecycleRootTopologyArtifactRole.allCases.count == 8)
        #expect(observation.appProcessIdentity == fixture.appIdentity)
        #expect(observation.helperProcessIdentity == fixture.helperIdentity)
        #expect(observation.artifacts.count == 8)
        #expect(observation.appProcess == .identityReused)
        #expect(observation.helperProcess == .absent)
        #expect(observation.service == .absent)
        #expect(observation.startedAt == RootTopologyFixture.observedAt)
        #expect(observation.observedAt == RootTopologyFixture.observedAt)
        #expect(observation.provesPostTeardownTopology)
        #expect(!(LifecycleRootTopologyObservationRequest.self is any Codable.Type))
        #expect(!(LifecycleRootTopologyObservation.self is any Codable.Type))
    }

    @Test(arguments: LifecycleRootTopologyArtifactRole.allCases)
    func everyArtifactRoleMustBeAbsent(
        role: LifecycleRootTopologyArtifactRole
    ) throws {
        let fixture = RootTopologyFixture()
        for state in [
            LifecycleRootTopologyArtifactObservation.present,
            .unavailable(reasonKey: "runtime.topology.fixture-unavailable"),
        ] {
            var artifacts = RootTopologyArtifacts.all(.absent)
            artifacts[role] = state
            let observation = try fixture.observe(
                artifacts: artifacts,
                app: .absent,
                helper: .identityReused,
                service: .absent
            )
            #expect(observation.artifacts[role] == state)
            #expect(!observation.provesPostTeardownTopology)
        }
    }

    @Test
    func processAndServiceUncertaintyFailsClosed() throws {
        let fixture = RootTopologyFixture()
        for state in [
            LifecycleRootTopologyProcessObservation.sameIdentityAlive,
            .unresolved(reasonKey: "runtime.topology.process-unavailable"),
        ] {
            let observation = try fixture.observe(
                artifacts: .all(.absent),
                app: state,
                helper: .absent,
                service: .absent
            )
            #expect(!observation.provesPostTeardownTopology)
        }
        let service = try fixture.observe(
            artifacts: .all(.absent),
            app: .absent,
            helper: .identityReused,
            service: .unavailable(
                reasonKey: "runtime.topology.service-still-registered"
            )
        )
        #expect(!service.provesPostTeardownTopology)
    }

    @Test
    func observationWindowIsCheckedAtStartAndFinish() throws {
        let fixture = RootTopologyFixture()
        let request = try fixture.request(
            openedAt: RootTopologyFixture.observedAt.addingTimeInterval(-1),
            validBefore: RootTopologyFixture.observedAt.addingTimeInterval(30)
        )
        let dependencies = fixture.dependencies()
        let early = LifecycleRootTopologyObserver(
            artifactReader: dependencies.0,
            processReader: dependencies.1,
            serviceProbe: dependencies.2,
            now: { RootTopologyFixture.observedAt.addingTimeInterval(-2) }
        )
        #expect(throws: LifecycleRootTopologyObservationError.observationOutsideWindow) {
            _ = try early.observe(request)
        }

        let clock = ScriptedTopologyClock([
            RootTopologyFixture.observedAt,
            RootTopologyFixture.observedAt.addingTimeInterval(31),
        ])
        let late = LifecycleRootTopologyObserver(
            artifactReader: dependencies.0,
            processReader: dependencies.1,
            serviceProbe: dependencies.2,
            now: clock.next
        )
        #expect(throws: LifecycleRootTopologyObservationError.observationOutsideWindow) {
            _ = try late.observe(request)
        }
    }

    @Test
    func invalidWindowAndProcessRolesAreRejected() throws {
        let fixture = RootTopologyFixture()
        let now = RootTopologyFixture.observedAt
        #expect(throws: LifecycleRootTopologyObservationError.invalidRequest) {
            _ = try LifecycleRootTopologyObservationWindow(
                openedAt: now,
                validBefore: now.addingTimeInterval(61)
            )
        }

        let invalidPairs = [
            (fixture.appIdentity, fixture.appIdentity),
            (topologyIdentity(effectiveUserID: 0), fixture.helperIdentity),
            (fixture.appIdentity, topologyIdentity(processID: 702)),
            (topologyIdentity(processID: 1), fixture.helperIdentity),
        ]
        for pair in invalidPairs {
            #expect(throws: LifecycleRootTopologyObservationError.invalidRequest) {
                _ = try LifecycleRootTopologyObservationRequest(
                    appProcessIdentity: pair.0,
                    helperProcessIdentity: pair.1,
                    window: LifecycleRootTopologyObservationWindow(
                        openedAt: now.addingTimeInterval(-1),
                        validBefore: now.addingTimeInterval(10)
                    )
                )
            }
        }
    }
}

private struct RootTopologyFixture {
    static let observedAt = Date(timeIntervalSince1970: 1_800_000_000)
    let appIdentity = topologyIdentity()
    let helperIdentity = topologyIdentity(
        processID: 702, processIDVersion: 12, auditSessionID: 33_001,
        effectiveUserID: 0, tokenSeed: 11
    )

    func request(
        openedAt: Date = Self.observedAt.addingTimeInterval(-1),
        validBefore: Date = Self.observedAt.addingTimeInterval(30)
    ) throws -> LifecycleRootTopologyObservationRequest {
        try LifecycleRootTopologyObservationRequest(
            appProcessIdentity: appIdentity,
            helperProcessIdentity: helperIdentity,
            window: LifecycleRootTopologyObservationWindow(
                openedAt: openedAt, validBefore: validBefore
            )
        )
    }

    func dependencies() -> (
        FixedArtifactAbsenceReader,
        FixedProcessAbsenceReader,
        FixedServiceProbe
    ) {
        (
            FixedArtifactAbsenceReader(states: .all(.absent)),
            FixedProcessAbsenceReader(results: [
                appIdentity.processID: .absent,
                helperIdentity.processID: .identityReused,
            ]),
            FixedServiceProbe(result: .absent)
        )
    }

    func observe(
        artifacts: RootTopologyArtifacts,
        app: LifecycleRootTopologyProcessObservation,
        helper: LifecycleRootTopologyProcessObservation,
        service: LifecycleRootTopologyServiceProbeResult
    ) throws -> LifecycleRootTopologyObservation {
        try LifecycleRootTopologyObserver(
            artifactReader: FixedArtifactAbsenceReader(states: artifacts),
            processReader: FixedProcessAbsenceReader(results: [
                appIdentity.processID: app, helperIdentity.processID: helper,
            ]),
            serviceProbe: FixedServiceProbe(result: service),
            now: { Self.observedAt }
        ).observe(try request())
    }
}

private typealias RootTopologyArtifacts = [
    LifecycleRootTopologyArtifactRole: LifecycleRootTopologyArtifactObservation
]

private extension Dictionary
where Key == LifecycleRootTopologyArtifactRole,
      Value == LifecycleRootTopologyArtifactObservation
{
    static func all(_ state: Value) -> Self {
        Dictionary(uniqueKeysWithValues:
            LifecycleRootTopologyArtifactRole.allCases.map { ($0, state) })
    }
}

private struct FixedArtifactAbsenceReader:
    LifecycleRootTopologyArtifactAbsenceReading
{
    let states: RootTopologyArtifacts
    func observeAbsence(
        _ role: LifecycleRootTopologyArtifactRole,
        contract _: LifecycleLocalInstallationContract
    ) -> LifecycleRootTopologyArtifactObservation {
        states[role] ?? .unavailable(reasonKey: "runtime.topology.fixture-missing")
    }
}

private struct FixedProcessAbsenceReader:
    LifecycleRootTopologyProcessAbsenceReading
{
    let results: [pid_t: LifecycleRootTopologyProcessObservation]
    func observeAbsence(
        of expectedIdentity: LifecycleProcessIdentity
    ) -> LifecycleRootTopologyProcessObservation {
        results[expectedIdentity.processID]
            ?? .unresolved(reasonKey: "runtime.topology.fixture-missing")
    }
}

private struct FixedServiceProbe: LifecycleRootTopologyServiceProbing {
    let result: LifecycleRootTopologyServiceProbeResult
    func observeFixedService(
        label _: String
    ) -> LifecycleRootTopologyServiceProbeResult { result }
}

private final class ScriptedTopologyClock: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Date]
    init(_ values: [Date]) { self.values = values }
    func next() -> Date {
        lock.withLock { values.count > 1 ? values.removeFirst() : values[0] }
    }
}

private func topologyIdentity(
    processID: pid_t = 701,
    processIDVersion: Int32 = 11,
    auditSessionID: Int32 = 44_001,
    effectiveUserID: uid_t = 501,
    tokenSeed: UInt32 = 1
) -> LifecycleProcessIdentity {
    LifecycleProcessIdentity(
        processID: processID, processIDVersion: processIDVersion,
        auditSessionID: auditSessionID, effectiveUserID: effectiveUserID,
        auditToken: try! LifecycleAuditToken(
            words: (0..<LifecycleAuditToken.wordCount).map {
                tokenSeed + UInt32($0)
            }
        )
    )
}
