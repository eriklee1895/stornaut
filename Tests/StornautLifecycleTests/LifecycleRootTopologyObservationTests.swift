import Darwin
import Foundation
import Testing
@testable import StornautLifecycle

@Suite("Lifecycle root topology observation")
struct LifecycleRootTopologyObservationTests {
    @Test
    func canonicalLayoutBindsEveryFixedRootTopologyObject() throws {
        let contract = try LifecycleLocalInstallationContract()

        #expect(
            contract.appExecutableURL.path
                == "/Library/Application Support/Stornaut/"
                    + "Stornaut-R5-Diagnostic.app/Contents/MacOS/"
                    + "StornautInvestigationDiagnostic"
        )
        #expect(
            contract.runtimeRootURL.path
                == "/Library/Application Support/Stornaut/R5Runtime"
        )
        #expect(
            contract.leaseRootURL.path
                == "/private/var/db/com.eriklee.stornaut.r5"
        )
        #expect(
            contract.helperSigningIdentifier
                == "com.eriklee.stornaut.lifecycle.helper"
        )
    }

    @Test
    func exactInstalledObservationProvesOnlyInstalledPhase() throws {
        let fixture = try RootTopologyFixture(phase: .installed)
        let observation = try fixture.observe(
            artifactStates: .all(.presentValid),
            serviceResult: .loaded(identity: fixture.helperIdentity),
            processResults: fixture.liveProcessResults
        )

        #expect(observation.phase == .installed)
        #expect(observation.binding == fixture.binding)
        #expect(observation.appProcessIdentity == fixture.appIdentity)
        #expect(observation.helperProcessIdentity == fixture.helperIdentity)
        #expect(observation.startedAt == RootTopologyFixture.observedAt)
        #expect(observation.observedAt == RootTopologyFixture.observedAt)
        #expect(observation.satisfiesPhaseContract)
        #expect(observation.provesInstalledTopology)
        #expect(!observation.provesPostTeardownTopology)
        #expect(observation.appProcess == .sameIdentityAlive)
        #expect(observation.helperProcess == .sameIdentityAlive)
        #expect(observation.service == .loadedValid)
    }

    @Test
    func exactAbsentObservationProvesOnlyPostTeardownPhase() throws {
        let fixture = try RootTopologyFixture(phase: .postTeardown)
        let observation = try fixture.observe(
            artifactStates: .all(.absent),
            serviceResult: .absent,
            processResults: [
                fixture.appIdentity.processID: .absent,
                fixture.helperIdentity.processID: .absent,
            ]
        )

        #expect(observation.phase == .postTeardown)
        #expect(observation.satisfiesPhaseContract)
        #expect(!observation.provesInstalledTopology)
        #expect(observation.provesPostTeardownTopology)
        #expect(observation.appProcess == .absent)
        #expect(observation.helperProcess == .absent)
        #expect(observation.service == .absent)
    }

    @Test
    func installedPhaseAllowsOnlyValidOrAbsentRuntimeRoots() throws {
        let fixture = try RootTopologyFixture(phase: .installed)
        var states = RootTopologyArtifactStates.all(.presentValid)
        states[.runtimeRoot] = .absent
        states[.leaseRoot] = .absent

        let observation = try fixture.observe(
            artifactStates: states,
            serviceResult: .loaded(identity: fixture.helperIdentity),
            processResults: fixture.liveProcessResults
        )

        #expect(observation.provesInstalledTopology)
        #expect(observation.satisfiesPhaseContract)
    }

    @Test(arguments: [
        LifecycleRootTopologyArtifactObservation.invalid(
            reasonKey: "runtime.topology.symlink"
        ),
        LifecycleRootTopologyArtifactObservation.unavailable(
            reasonKey: "runtime.topology.permission-denied"
        ),
    ])
    func invalidAndUnavailableArtifactsNeverProveEitherPhase(
        state: LifecycleRootTopologyArtifactObservation
    ) throws {
        for phase in LifecycleRootTopologyPhase.allCases {
            let fixture = try RootTopologyFixture(phase: phase)
            var states = RootTopologyArtifactStates.all(
                phase == .installed ? .presentValid : .absent
            )
            states[.installedRoot] = state
            let observation = try fixture.observe(
                artifactStates: states,
                serviceResult: phase == .installed
                    ? .loaded(identity: fixture.helperIdentity)
                    : .absent,
                processResults: phase == .installed
                    ? fixture.liveProcessResults
                    : [
                        fixture.appIdentity.processID: .absent,
                        fixture.helperIdentity.processID: .absent,
                    ]
            )

            #expect(!observation.satisfiesPhaseContract)
            #expect(!observation.provesInstalledTopology)
            #expect(!observation.provesPostTeardownTopology)
        }
    }

    @Test
    func loadedForeignHelperAndUnavailableServiceFailClosed() throws {
        let fixture = try RootTopologyFixture(phase: .installed)
        let foreignHelper = processIdentity(
            processID: fixture.helperIdentity.processID,
            processIDVersion: fixture.helperIdentity.processIDVersion + 1,
            auditSessionID: fixture.helperIdentity.auditSessionID,
            effectiveUserID: fixture.helperIdentity.effectiveUserID,
            tokenSeed: 90
        )

        let mismatched = try fixture.observe(
            artifactStates: .all(.presentValid),
            serviceResult: .loaded(identity: foreignHelper),
            processResults: fixture.liveProcessResults
        )
        let unavailable = try fixture.observe(
            artifactStates: .all(.presentValid),
            serviceResult: .unavailable(
                reasonKey: "runtime.topology.service-lookup-failed"
            ),
            processResults: fixture.liveProcessResults
        )

        #expect(mismatched.service == .invalid(
            reasonKey: "runtime.topology.service-identity-mismatch"
        ))
        #expect(!mismatched.satisfiesPhaseContract)
        #expect(unavailable.service == .unavailable(
            reasonKey: "runtime.topology.service-lookup-failed"
        ))
        #expect(!unavailable.satisfiesPhaseContract)
    }

    @Test
    func processClassificationDistinguishesReuseAndUnresolvedEvidence()
        throws
    {
        let fixture = try RootTopologyFixture(phase: .postTeardown)
        let reused = processIdentity(
            processID: fixture.appIdentity.processID,
            processIDVersion: fixture.appIdentity.processIDVersion + 1,
            auditSessionID: fixture.appIdentity.auditSessionID,
            effectiveUserID: fixture.appIdentity.effectiveUserID,
            tokenSeed: 71
        )
        let foreignPath = LifecycleRootTopologyProcessSnapshot(
            identity: fixture.helperIdentity,
            executableURL: URL(filePath: "/tmp/foreign-helper"),
            signingIdentity: fixture.binding.helperSigningEvidence.identity
        )

        let observation = try fixture.observe(
            artifactStates: .all(.absent),
            serviceResult: .absent,
            processResults: [
                fixture.appIdentity.processID: .observed(
                    LifecycleRootTopologyProcessSnapshot(
                        identity: reused,
                        executableURL: fixture.contract.appExecutableURL,
                        signingIdentity:
                            fixture.binding.appSigningEvidence.identity
                    )
                ),
                fixture.helperIdentity.processID: .observed(foreignPath),
            ]
        )

        #expect(observation.appProcess == .identityReused)
        #expect(observation.helperProcess == .unresolved(
            reasonKey: "runtime.topology.process-binding-mismatch"
        ))
        #expect(!observation.provesPostTeardownTopology)
    }

    @Test
    func vanishedMidObservationIsUnresolvedRatherThanAbsent() throws {
        let fixture = try RootTopologyFixture(phase: .postTeardown)
        let observation = try fixture.observe(
            artifactStates: .all(.absent),
            serviceResult: .absent,
            processResults: [
                fixture.appIdentity.processID: .unresolved(
                    reasonKey: "runtime.topology.process-vanished"
                ),
                fixture.helperIdentity.processID: .absent,
            ]
        )

        #expect(observation.appProcess == .unresolved(
            reasonKey: "runtime.topology.process-vanished"
        ))
        #expect(!observation.provesPostTeardownTopology)
    }

    @Test
    func staleFutureAndPreTeardownWindowsAreRejected() throws {
        let now = RootTopologyFixture.observedAt
        let binding = try rootTopologyBinding()
        let app = processIdentity(
            processID: 701,
            processIDVersion: 11,
            auditSessionID: 44_001,
            effectiveUserID: 501,
            tokenSeed: 1
        )
        let helper = processIdentity(
            processID: 702,
            processIDVersion: 12,
            auditSessionID: 33_001,
            effectiveUserID: 0,
            tokenSeed: 11
        )

        for window in [
            try LifecycleRootTopologyObservationWindow(
                openedAt: now.addingTimeInterval(-61),
                validBefore: now.addingTimeInterval(-1)
            ),
            try LifecycleRootTopologyObservationWindow(
                openedAt: now.addingTimeInterval(1),
                validBefore: now.addingTimeInterval(30)
            ),
        ] {
            let request = try LifecycleRootTopologyObservationRequest(
                phase: .postTeardown,
                binding: binding,
                appProcessIdentity: app,
                helperProcessIdentity: helper,
                window: window
            )
            let observer = LifecycleRootTopologyObserver(
                artifactReader: FakeRootTopologyArtifactReader(
                    states: .all(.absent)
                ),
                processReader: FakeRootTopologyProcessReader(results: [:]),
                serviceProbe: FakeRootTopologyServiceProbe(result: .absent),
                now: { now }
            )

            #expect(
                throws: LifecycleRootTopologyObservationError
                    .observationOutsideWindow
            ) {
                _ = try observer.observe(request)
            }
        }
    }

    @Test
    func collectionThatFinishesAfterTheWindowFailsClosed() throws {
        let fixture = try RootTopologyFixture(phase: .postTeardown)
        let clock = ScriptedRootTopologyClock([
            RootTopologyFixture.observedAt,
            RootTopologyFixture.observedAt.addingTimeInterval(31),
        ])
        let request = try LifecycleRootTopologyObservationRequest(
            phase: .postTeardown,
            binding: fixture.binding,
            appProcessIdentity: fixture.appIdentity,
            helperProcessIdentity: fixture.helperIdentity,
            window: LifecycleRootTopologyObservationWindow(
                openedAt: RootTopologyFixture.observedAt
                    .addingTimeInterval(-1),
                validBefore: RootTopologyFixture.observedAt
                    .addingTimeInterval(30)
            )
        )
        let observer = LifecycleRootTopologyObserver(
            artifactReader: FakeRootTopologyArtifactReader(
                states: .all(.absent)
            ),
            processReader: FakeRootTopologyProcessReader(results: [
                fixture.appIdentity.processID: .absent,
                fixture.helperIdentity.processID: .absent,
            ]),
            serviceProbe: FakeRootTopologyServiceProbe(result: .absent),
            now: { clock.next() }
        )

        #expect(
            throws: LifecycleRootTopologyObservationError
                .observationOutsideWindow
        ) {
            _ = try observer.observe(request)
        }
    }

    @Test
    func invalidObservationRequestsAreRejectedBeforeAnyProbe() throws {
        let now = RootTopologyFixture.observedAt
        let app = processIdentity(
            processID: 701,
            processIDVersion: 11,
            auditSessionID: 44_001,
            effectiveUserID: 501,
            tokenSeed: 1
        )

        #expect(throws: LifecycleRootTopologyObservationError.invalidRequest) {
            _ = try LifecycleRootTopologyObservationRequest(
                phase: .installed,
                binding: rootTopologyBinding(),
                appProcessIdentity: app,
                helperProcessIdentity: app,
                window: LifecycleRootTopologyObservationWindow(
                    openedAt: now.addingTimeInterval(-1),
                    validBefore: now.addingTimeInterval(10)
                )
            )
        }
        #expect(throws: LifecycleRootTopologyObservationError.invalidRequest) {
            _ = try LifecycleRootTopologyObservationWindow(
                openedAt: now,
                validBefore: now.addingTimeInterval(61)
            )
        }

        let invalidRoles: [(LifecycleProcessIdentity, LifecycleProcessIdentity)] = [
            (
                processIdentity(
                    processID: 701,
                    processIDVersion: 11,
                    auditSessionID: 44_001,
                    effectiveUserID: 0,
                    tokenSeed: 1
                ),
                processIdentity(
                    processID: 702,
                    processIDVersion: 12,
                    auditSessionID: 33_001,
                    effectiveUserID: 0,
                    tokenSeed: 11
                )
            ),
            (
                app,
                processIdentity(
                    processID: 702,
                    processIDVersion: 12,
                    auditSessionID: 33_001,
                    effectiveUserID: 501,
                    tokenSeed: 11
                )
            ),
            (
                processIdentity(
                    processID: 701,
                    processIDVersion: 0,
                    auditSessionID: 44_001,
                    effectiveUserID: 501,
                    tokenSeed: 1
                ),
                processIdentity(
                    processID: 702,
                    processIDVersion: 12,
                    auditSessionID: 33_001,
                    effectiveUserID: 0,
                    tokenSeed: 11
                )
            ),
        ]
        for (invalidApp, invalidHelper) in invalidRoles {
            #expect(
                throws: LifecycleRootTopologyObservationError.invalidRequest
            ) {
                _ = try LifecycleRootTopologyObservationRequest(
                    phase: .installed,
                    binding: rootTopologyBinding(),
                    appProcessIdentity: invalidApp,
                    helperProcessIdentity: invalidHelper,
                    window: LifecycleRootTopologyObservationWindow(
                        openedAt: now.addingTimeInterval(-1),
                        validBefore: now.addingTimeInterval(10)
                    )
                )
            }
        }
    }

    @Test
    func topologyAuthorityIsPackageClosedOpaqueAndReadOnly() throws {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURLs = [
            repositoryRoot.appending(
                path: "Sources/StornautLifecycle/"
                    + "LifecycleRootTopologyObservation.swift"
            ),
            repositoryRoot.appending(
                path: "Sources/StornautLifecycle/"
                    + "DarwinRootTopologySupport.swift"
            ),
        ]
        let forbidden = [
            "public ",
            "Codable",
            "JSONEncoder",
            "JSONDecoder",
            "removeItem",
            "createDirectory",
            "write(to:",
            "unlink(",
            "rename(",
            "mkdir(",
            "chmod(",
            "chown(",
            "posix_spawn",
            "Process(",
            "launchctl",
            "bootstrap",
            "bootout",
            "kickstart",
            "readiness",
            "signedInvestigationRuntimeReady",
            "StornautInvestigation",
        ]

        for sourceURL in sourceURLs {
            let source = try String(contentsOf: sourceURL, encoding: .utf8)
            for token in forbidden {
                #expect(!source.contains(token))
            }
        }

        let contractSource = try String(
            contentsOf: sourceURLs[0],
            encoding: .utf8
        )
        #expect(contractSource.contains(
            "package struct LifecycleRootTopologyObservation"
        ))
        #expect(contractSource.contains(
            "package init(\n        serviceProbe:"
        ))
        let observationStart = try #require(contractSource.range(
            of: "package struct LifecycleRootTopologyObservation: "
        ))
        let observerStart = try #require(contractSource.range(
            of: "package struct LifecycleRootTopologyObserver: "
        ))
        let observationSource = contractSource[
            observationStart.lowerBound..<observerStart.lowerBound
        ]
        #expect(observationSource.contains(
            "fileprivate init(\n        phase: LifecycleRootTopologyPhase"
        ))
        #expect(!observationSource.contains("package init("))
        #expect(!contractSource.contains(
            "package protocol LifecycleRootTopologyArtifactReading"
        ))
        #expect(!contractSource.contains(
            "package protocol LifecycleRootTopologyProcessReading"
        ))
    }
}

private struct RootTopologyFixture {
    static let observedAt = Date(timeIntervalSince1970: 1_800_000_000)

    let phase: LifecycleRootTopologyPhase
    let contract: LifecycleLocalInstallationContract
    let binding: LifecycleRootTopologyBinding
    let appIdentity: LifecycleProcessIdentity
    let helperIdentity: LifecycleProcessIdentity

    init(phase: LifecycleRootTopologyPhase) throws {
        self.phase = phase
        contract = try LifecycleLocalInstallationContract()
        binding = try rootTopologyBinding()
        appIdentity = processIdentity(
            processID: 701,
            processIDVersion: 11,
            auditSessionID: 44_001,
            effectiveUserID: 501,
            tokenSeed: 1
        )
        helperIdentity = processIdentity(
            processID: 702,
            processIDVersion: 12,
            auditSessionID: 33_001,
            effectiveUserID: 0,
            tokenSeed: 11
        )
    }

    var liveProcessResults: [
        pid_t: LifecycleRootTopologyProcessReadResult
    ] {
        [
            appIdentity.processID: .observed(
                LifecycleRootTopologyProcessSnapshot(
                    identity: appIdentity,
                    executableURL: contract.appExecutableURL,
                    signingIdentity: binding.appSigningEvidence.identity
                )
            ),
            helperIdentity.processID: .observed(
                LifecycleRootTopologyProcessSnapshot(
                    identity: helperIdentity,
                    executableURL: contract.helperExecutableURL,
                    signingIdentity: binding.helperSigningEvidence.identity
                )
            ),
        ]
    }

    func observe(
        artifactStates: RootTopologyArtifactStates,
        serviceResult: LifecycleRootTopologyServiceProbeResult,
        processResults: [pid_t: LifecycleRootTopologyProcessReadResult]
    ) throws -> LifecycleRootTopologyObservation {
        let request = try LifecycleRootTopologyObservationRequest(
            phase: phase,
            binding: binding,
            appProcessIdentity: appIdentity,
            helperProcessIdentity: helperIdentity,
            window: LifecycleRootTopologyObservationWindow(
                openedAt: Self.observedAt.addingTimeInterval(-1),
                validBefore: Self.observedAt.addingTimeInterval(30)
            )
        )
        return try LifecycleRootTopologyObserver(
            artifactReader: FakeRootTopologyArtifactReader(
                states: artifactStates
            ),
            processReader: FakeRootTopologyProcessReader(
                results: processResults
            ),
            serviceProbe: FakeRootTopologyServiceProbe(
                result: serviceResult
            ),
            now: { Self.observedAt }
        ).observe(request)
    }
}

private typealias RootTopologyArtifactStates = [
    LifecycleRootTopologyArtifactRole:
        LifecycleRootTopologyArtifactObservation
]

private extension Dictionary
where
    Key == LifecycleRootTopologyArtifactRole,
    Value == LifecycleRootTopologyArtifactObservation
{
    static func all(
        _ state: LifecycleRootTopologyArtifactObservation
    ) -> Self {
        Dictionary(
            uniqueKeysWithValues:
                LifecycleRootTopologyArtifactRole.allCases.map {
                    ($0, state)
                }
        )
    }
}

private struct FakeRootTopologyArtifactReader:
    LifecycleRootTopologyArtifactReading
{
    let states: RootTopologyArtifactStates

    func observe(
        _ role: LifecycleRootTopologyArtifactRole,
        contract _: LifecycleLocalInstallationContract,
        binding _: LifecycleRootTopologyBinding
    ) -> LifecycleRootTopologyArtifactObservation {
        states[role] ?? .unavailable(
            reasonKey: "runtime.topology.fixture-missing"
        )
    }
}

private struct FakeRootTopologyProcessReader:
    LifecycleRootTopologyProcessReading
{
    let results: [pid_t: LifecycleRootTopologyProcessReadResult]

    func read(
        processID: pid_t
    ) -> LifecycleRootTopologyProcessReadResult {
        results[processID] ?? .unresolved(
            reasonKey: "runtime.topology.fixture-missing"
        )
    }
}

private struct FakeRootTopologyServiceProbe:
    LifecycleRootTopologyServiceProbing
{
    let result: LifecycleRootTopologyServiceProbeResult

    func observeFixedService(
        label: String
    ) -> LifecycleRootTopologyServiceProbeResult {
        guard label == "com.eriklee.stornaut.lifecycle" else {
            return .unavailable(
                reasonKey: "runtime.topology.foreign-service-label"
            )
        }
        return result
    }
}

private final class ScriptedRootTopologyClock: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Date]

    init(_ values: [Date]) {
        self.values = values
    }

    func next() -> Date {
        lock.withLock { values.removeFirst() }
    }
}

private func rootTopologyBinding() throws -> LifecycleRootTopologyBinding {
    let appIdentity = try LifecycleSigningIdentity(
        signingIdentifier: "com.eriklee.stornaut",
        designatedRequirementSHA256: topologyDigest("a"),
        codeDirectoryHash: String(repeating: "1", count: 40)
    )
    let helperIdentity = try LifecycleSigningIdentity(
        signingIdentifier: "com.eriklee.stornaut.lifecycle.helper",
        designatedRequirementSHA256: topologyDigest("b"),
        codeDirectoryHash: String(repeating: "2", count: 40)
    )
    return try LifecycleRootTopologyBinding(
        appSigningEvidence: LifecycleBundleSigningEvidence(
            identity: appIdentity,
            executableSHA256: topologyDigest("c"),
            isAdHoc: true
        ),
        helperSigningEvidence: LifecycleBundleSigningEvidence(
            identity: helperIdentity,
            executableSHA256: topologyDigest("d"),
            isAdHoc: true
        ),
        appBundleIdentifier: "com.eriklee.stornaut",
        helperServiceIdentifier: "com.eriklee.stornaut.lifecycle"
    )
}

private func processIdentity(
    processID: pid_t,
    processIDVersion: Int32,
    auditSessionID: Int32,
    effectiveUserID: uid_t,
    tokenSeed: UInt32
) -> LifecycleProcessIdentity {
    LifecycleProcessIdentity(
        processID: processID,
        processIDVersion: processIDVersion,
        auditSessionID: auditSessionID,
        effectiveUserID: effectiveUserID,
        auditToken: try! LifecycleAuditToken(
            words: (0..<LifecycleAuditToken.wordCount).map {
                tokenSeed + UInt32($0)
            }
        )
    )
}

private func topologyDigest(_ character: Character) -> String {
    String(repeating: character, count: 64)
}
