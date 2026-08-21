import Darwin
import Foundation
import Testing
@testable import StornautLifecycle

@Suite("Lifecycle root topology observation")
struct LifecycleRootTopologyObservationTests {
    @Test
    func closedArtifactRolesRequireMachineDriverAbsenceAfterTeardown() throws {
        #expect(LifecycleRootTopologyArtifactRole.allCases.count == 8)

        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repositoryRoot.appending(
            path: "Sources/StornautLifecycle/"
                + "LifecycleRootTopologyObservation.swift"
        )
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        let roleStart = try #require(source.range(
            of: "package enum LifecycleRootTopologyArtifactRole:"
        ))
        let roleEnd = try #require(source.range(
            of: "package enum LifecycleRootTopologyArtifactObservation:",
            range: roleStart.upperBound..<source.endIndex
        ))
        let roleDeclaration = source[roleStart.lowerBound..<roleEnd.lowerBound]
        #expect(roleDeclaration.contains("case machineDriverExecutable"))

        let bindingStart = try #require(source.range(
            of: "package struct LifecycleRootTopologyBinding:"
        ))
        let bindingEnd = try #require(source.range(
            of: "package struct LifecycleRootTopologyObservationWindow:",
            range: bindingStart.upperBound..<source.endIndex
        ))
        let bindingDeclaration =
            source[bindingStart.lowerBound..<bindingEnd.lowerBound]
        #expect(bindingDeclaration.contains("machineDriverSigningEvidence"))

        let postTeardownStart = try #require(source.range(
            of: "private var postTeardownContractSatisfied: Bool {"
        ))
        let observerStart = try #require(source.range(
            of: "package struct LifecycleRootTopologyObserver:",
            range: postTeardownStart.upperBound..<source.endIndex
        ))
        let postTeardownContract = source[
            postTeardownStart.lowerBound..<observerStart.lowerBound
        ]
        #expect(postTeardownContract.contains(
            "LifecycleRootTopologyArtifactRole.allCases"
        ))
        #expect(postTeardownContract.contains("artifacts[$0] == .absent"))
    }

    @Test
    func bindingRejectsNonAdHocMachineDriverEvidence() throws {
        let valid = try rootTopologyBinding()
        let nonAdHocDriver = try LifecycleBundleSigningEvidence(
            identity: valid.machineDriverSigningEvidence.identity,
            executableSHA256:
                valid.machineDriverSigningEvidence.executableSHA256,
            isAdHoc: false
        )

        #expect(
            throws: LifecycleRootTopologyObservationError.invalidRequest
        ) {
            _ = try LifecycleRootTopologyBinding(
                appSigningEvidence: valid.appSigningEvidence,
                helperSigningEvidence: valid.helperSigningEvidence,
                machineDriverSigningEvidence: nonAdHocDriver,
                appBundleIdentifier: valid.appBundleIdentifier,
                helperServiceIdentifier: valid.helperServiceIdentifier
            )
        }
    }

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
    func exactAbsentObservationProvesPostTeardown() throws {
        let fixture = try RootTopologyFixture()
        let observation = try fixture.observe(
            artifactStates: .all(.absent),
            serviceResult: .absent,
            processResults: [
                fixture.appIdentity.processID: .absent,
                fixture.helperIdentity.processID: .absent,
            ]
        )

        #expect(observation.binding == fixture.binding)
        #expect(observation.appProcessIdentity == fixture.appIdentity)
        #expect(observation.helperProcessIdentity == fixture.helperIdentity)
        #expect(observation.startedAt == RootTopologyFixture.observedAt)
        #expect(observation.observedAt == RootTopologyFixture.observedAt)
        #expect(observation.provesPostTeardownTopology)
        #expect(observation.appProcess == .absent)
        #expect(observation.helperProcess == .absent)
        #expect(observation.service == .absent)
    }

    @Test(arguments: [
        LifecycleRootTopologyArtifactObservation.presentValid,
        LifecycleRootTopologyArtifactObservation.invalid(
            reasonKey: "runtime.topology.symlink"
        ),
        LifecycleRootTopologyArtifactObservation.unavailable(
            reasonKey: "runtime.topology.permission-denied"
        ),
    ])
    func presentInvalidAndUnavailableArtifactsNeverProvePostTeardown(
        state: LifecycleRootTopologyArtifactObservation
    ) throws {
        let fixture = try RootTopologyFixture()
        var states = RootTopologyArtifactStates.all(.absent)
        states[.installedRoot] = state
        let observation = try fixture.observe(
            artifactStates: states,
            serviceResult: .absent,
            processResults: [
                fixture.appIdentity.processID: .absent,
                fixture.helperIdentity.processID: .absent,
            ]
        )

        #expect(!observation.provesPostTeardownTopology)
    }

    @Test
    func survivingProcessesAndUnavailableServiceFailClosed() throws {
        let fixture = try RootTopologyFixture()
        let surviving = try fixture.observe(
            artifactStates: .all(.absent),
            serviceResult: .absent,
            processResults: fixture.liveProcessResults
        )
        let unavailable = try fixture.observe(
            artifactStates: .all(.absent),
            serviceResult: .unavailable(
                reasonKey: "runtime.topology.service-lookup-failed"
            ),
            processResults: [
                fixture.appIdentity.processID: .absent,
                fixture.helperIdentity.processID: .absent,
            ]
        )

        #expect(surviving.appProcess == .sameIdentityAlive)
        #expect(surviving.helperProcess == .sameIdentityAlive)
        #expect(!surviving.provesPostTeardownTopology)
        #expect(unavailable.service == .unavailable(
            reasonKey: "runtime.topology.service-lookup-failed"
        ))
        #expect(!unavailable.provesPostTeardownTopology)
    }

    @Test
    func processClassificationDistinguishesReuseAndUnresolvedEvidence()
        throws
    {
        let fixture = try RootTopologyFixture()
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
        let fixture = try RootTopologyFixture()
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
        let fixture = try RootTopologyFixture()
        let clock = ScriptedRootTopologyClock([
            RootTopologyFixture.observedAt,
            RootTopologyFixture.observedAt.addingTimeInterval(31),
        ])
        let request = try LifecycleRootTopologyObservationRequest(
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
            "fileprivate init(\n        binding: LifecycleRootTopologyBinding"
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

    let contract: LifecycleLocalInstallationContract
    let binding: LifecycleRootTopologyBinding
    let appIdentity: LifecycleProcessIdentity
    let helperIdentity: LifecycleProcessIdentity

    init() throws {
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
    let machineDriverIdentity = try LifecycleSigningIdentity(
        signingIdentifier:
            "com.eriklee.stornaut.investigation.machine-driver",
        designatedRequirementSHA256: topologyDigest("e"),
        codeDirectoryHash: String(repeating: "3", count: 40)
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
        machineDriverSigningEvidence: LifecycleBundleSigningEvidence(
            identity: machineDriverIdentity,
            executableSHA256: topologyDigest("f"),
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
