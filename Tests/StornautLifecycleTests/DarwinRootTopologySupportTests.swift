import Darwin
import Foundation
import Testing
@testable import StornautLifecycle

@Suite("Darwin root topology support", .serialized)
struct DarwinRootTopologySupportTests {
    @Test
    func sourceDeclaresAbsenceOnlyArtifactAndProcessReaders() throws {
        let source = try darwinTopologySupportSource()
        for required in [
            "struct DarwinRootTopologyArtifactAbsenceReader:",
            "struct DarwinRootTopologyProcessAbsenceReader:",
            "func observeAbsence(",
            "case .failure(let error) where error.errno == ENOENT:",
            "case .failure(.identityUnavailable(let code)) where code == ESRCH:",
            "case .success(let identity) where identity == expectedIdentity:",
        ] {
            #expect(source.contains(required))
        }
        for forbidden in [
            "import CryptoKit",
            "DarwinRootTopologyArtifactReader",
            "DarwinRootTopologyNodeReader",
            "LifecycleRootTopologyNodeExpectation",
            "LifecycleRootTopologyProcessSnapshot",
            "LifecycleRootTopologySigningEvidenceReading",
            "LifecycleRootTopologyManifestReading",
            "LifecycleRootTopologyProcessExecutableReading",
            "proc_pidpath",
            "signingVerifier",
            "binding:",
        ] {
            #expect(!source.contains(forbidden))
        }
    }

    @Test(arguments: LifecycleRootTopologyArtifactRole.allCases)
    func artifactReaderMapsEveryRoleToItsFixedContractPath(
        role: LifecycleRootTopologyArtifactRole
    ) throws {
        let contract = try LifecycleLocalInstallationContract()
        let fileSystem = RecordingTopologyFileSystem()
        let reader = DarwinRootTopologyArtifactAbsenceReader(
            fileSystem: fileSystem
        )

        #expect(
            reader.observeAbsence(role, contract: contract) == .present
        )
        #expect(
            fileSystem.recordedURLs == [
                expectedURL(for: role, contract: contract)
            ]
        )
    }

    @Test
    func artifactReaderTreatsOnlyInitialENOENTAsAbsent() throws {
        let contract = try LifecycleLocalInstallationContract()
        let role = LifecycleRootTopologyArtifactRole.runtimeRoot
        let absentFileSystem = RecordingTopologyFileSystem(
            results: [.failure(.init(errno: ENOENT))]
        )
        let presentFileSystem = RecordingTopologyFileSystem(
            results: [.success(())]
        )

        #expect(
            DarwinRootTopologyArtifactAbsenceReader(
                fileSystem: absentFileSystem
            ).observeAbsence(role, contract: contract) == .absent
        )
        #expect(absentFileSystem.invocationCount == 1)
        #expect(
            DarwinRootTopologyArtifactAbsenceReader(
                fileSystem: presentFileSystem
            ).observeAbsence(role, contract: contract) == .present
        )
        #expect(presentFileSystem.invocationCount == 1)
    }

    @Test(arguments: [EACCES, EPERM, EIO, EINVAL])
    func artifactReaderTreatsEveryOtherErrorAsUnavailable(
        code: Int32
    ) throws {
        let contract = try LifecycleLocalInstallationContract()
        let fileSystem = RecordingTopologyFileSystem(
            results: [.failure(.init(errno: code))]
        )
        let observation = DarwinRootTopologyArtifactAbsenceReader(
            fileSystem: fileSystem
        ).observeAbsence(.runtimeRoot, contract: contract)

        #expect(observation == .unavailable(
            reasonKey: "runtime.topology.lstat-unavailable"
        ))
        #expect(fileSystem.invocationCount == 1)
    }

    @Test
    func fileSystemUsesNonFollowingLstatForDanglingSymlinks() throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-topology-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let link = root.appending(path: "link")
        try FileManager.default.createSymbolicLink(
            at: link,
            withDestinationURL: root.appending(path: "missing-target")
        )

        switch DarwinRootTopologyFileSystem().metadata(at: link) {
        case .success:
            break
        case let .failure(error):
            Issue.record("lstat failed with errno \(error.errno)")
        }
    }

    @Test
    func processReaderTreatsOnlyESRCHAsAbsent() {
        let expected = topologySupportIdentity()
        let absent = RecordingProcessIdentityReader(
            results: [.failure(.identityUnavailable(errno: ESRCH))]
        )
        let unavailable = RecordingProcessIdentityReader(
            results: [.failure(.identityUnavailable(errno: EPERM))]
        )

        #expect(
            DarwinRootTopologyProcessAbsenceReader(
                identityReader: absent
            ).observeAbsence(of: expected) == .absent
        )
        #expect(absent.invocationCount == 1)
        #expect(
            DarwinRootTopologyProcessAbsenceReader(
                identityReader: unavailable
            ).observeAbsence(of: expected) == .unresolved(
                reasonKey: "runtime.topology.process-identity-unavailable"
            )
        )
        #expect(unavailable.invocationCount == 1)
    }

    @Test
    func processReaderKeepsExactIdentityAlive() {
        let expected = topologySupportIdentity()
        let identityReader = RecordingProcessIdentityReader(
            results: [.success(expected)]
        )

        #expect(
            DarwinRootTopologyProcessAbsenceReader(
                identityReader: identityReader
            ).observeAbsence(of: expected) == .sameIdentityAlive
        )
        #expect(identityReader.processIDs == [expected.processID])
    }

    @Test
    func processReaderRejectsAResultForAnotherProcessID() {
        let expected = topologySupportIdentity()
        let identityReader = RecordingProcessIdentityReader(results: [
            .success(topologySupportIdentity(processID: 702)),
        ])

        #expect(
            DarwinRootTopologyProcessAbsenceReader(
                identityReader: identityReader
            ).observeAbsence(of: expected) == .unresolved(
                reasonKey: "runtime.topology.process-identity-mismatch"
            )
        )
    }

    @Test(arguments: IdentityReuseMutation.allCases)
    func processReaderTreatsEveryIdentityAxisDriftAsReuse(
        mutation: IdentityReuseMutation
    ) {
        let expected = topologySupportIdentity()
        let identityReader = RecordingProcessIdentityReader(
            results: [.success(mutation.apply(to: expected))]
        )

        #expect(
            DarwinRootTopologyProcessAbsenceReader(
                identityReader: identityReader
            ).observeAbsence(of: expected) == .identityReused
        )
        #expect(identityReader.invocationCount == 1)
    }

    @Test
    func processReaderTreatsOtherFailuresAsUnresolved() {
        let expected = topologySupportIdentity()
        for failure in [
            DarwinLifecycleSupportError.identityUnavailable(errno: EIO),
            .invalidIdentity,
        ] {
            let identityReader = RecordingProcessIdentityReader(
                results: [.failure(failure)]
            )
            #expect(
                DarwinRootTopologyProcessAbsenceReader(
                    identityReader: identityReader
                ).observeAbsence(of: expected) == .unresolved(
                    reasonKey: "runtime.topology.process-identity-unavailable"
                )
            )
        }
    }

    @Test
    func invalidProcessIdentifierFailsBeforeIdentityLookup() {
        let invalid = topologySupportIdentity(processID: 1)
        let identityReader = RecordingProcessIdentityReader(results: [])

        #expect(
            DarwinRootTopologyProcessAbsenceReader(
                identityReader: identityReader
            ).observeAbsence(of: invalid) == .unresolved(
                reasonKey: "runtime.topology.invalid-process-id"
            )
        )
        #expect(identityReader.invocationCount == 0)
    }
}

private final class RecordingTopologyFileSystem:
    LifecycleRootTopologyFileSystem,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var results: [Result<Void, LifecycleRootTopologySystemCallError>]
    private var urls: [URL] = []

    init(
        results: [Result<Void, LifecycleRootTopologySystemCallError>] = [
            .success(()),
        ]
    ) {
        self.results = results
    }

    var recordedURLs: [URL] { lock.withLock { urls } }
    var invocationCount: Int { lock.withLock { urls.count } }

    func metadata(
        at url: URL
    ) -> Result<Void, LifecycleRootTopologySystemCallError> {
        lock.withLock {
            urls.append(url)
            guard !results.isEmpty else {
                return .failure(.init(errno: EIO))
            }
            return results.removeFirst()
        }
    }
}

private final class RecordingProcessIdentityReader:
    LifecycleRootTopologyProcessIdentityReading,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var results: [
        Result<LifecycleProcessIdentity, DarwinLifecycleSupportError>
    ]
    private var identifiers: [pid_t] = []

    init(
        results: [Result<LifecycleProcessIdentity, DarwinLifecycleSupportError>]
    ) {
        self.results = results
    }

    var processIDs: [pid_t] { lock.withLock { identifiers } }
    var invocationCount: Int { lock.withLock { identifiers.count } }

    func processIdentity(
        for processID: pid_t
    ) -> Result<LifecycleProcessIdentity, DarwinLifecycleSupportError> {
        lock.withLock {
            identifiers.append(processID)
            guard !results.isEmpty else {
                return .failure(.identityUnavailable(errno: EIO))
            }
            return results.removeFirst()
        }
    }
}

enum IdentityReuseMutation: CaseIterable {
    case processIDVersion
    case auditSessionID
    case effectiveUserID
    case auditToken

    func apply(
        to identity: LifecycleProcessIdentity
    ) -> LifecycleProcessIdentity {
        switch self {
        case .processIDVersion:
            topologySupportIdentity(
                processID: identity.processID,
                version: identity.processIDVersion + 1,
                auditSessionID: identity.auditSessionID,
                effectiveUserID: identity.effectiveUserID,
                tokenSeed: identity.auditToken.words[0]
            )
        case .auditSessionID:
            topologySupportIdentity(
                processID: identity.processID,
                version: identity.processIDVersion,
                auditSessionID: identity.auditSessionID + 1,
                effectiveUserID: identity.effectiveUserID,
                tokenSeed: identity.auditToken.words[0]
            )
        case .effectiveUserID:
            topologySupportIdentity(
                processID: identity.processID,
                version: identity.processIDVersion,
                auditSessionID: identity.auditSessionID,
                effectiveUserID: identity.effectiveUserID + 1,
                tokenSeed: identity.auditToken.words[0]
            )
        case .auditToken:
            topologySupportIdentity(
                processID: identity.processID,
                version: identity.processIDVersion,
                auditSessionID: identity.auditSessionID,
                effectiveUserID: identity.effectiveUserID,
                tokenSeed: identity.auditToken.words[0] + 100
            )
        }
    }
}

private func expectedURL(
    for role: LifecycleRootTopologyArtifactRole,
    contract: LifecycleLocalInstallationContract
) -> URL {
    switch role {
    case .installedRoot:
        contract.installedRootURL
    case .installedApp:
        contract.installedAppURL
    case .appExecutable:
        contract.appExecutableURL
    case .helperExecutable:
        contract.helperExecutableURL
    case .machineDriverExecutable:
        contract.machineDriverExecutableURL
    case .launchDaemonPlist:
        contract.launchDaemonPlistURL
    case .runtimeRoot:
        contract.runtimeRootURL
    case .leaseRoot:
        contract.leaseRootURL
    }
}

private func topologySupportIdentity(
    processID: pid_t = 701,
    version: Int32 = 11,
    auditSessionID: Int32 = 44_001,
    effectiveUserID: uid_t = 501,
    tokenSeed: UInt32 = 1
) -> LifecycleProcessIdentity {
    LifecycleProcessIdentity(
        processID: processID,
        processIDVersion: version,
        auditSessionID: auditSessionID,
        effectiveUserID: effectiveUserID,
        auditToken: try! LifecycleAuditToken(
            words: (0..<LifecycleAuditToken.wordCount).map {
                tokenSeed + UInt32($0)
            }
        )
    )
}

private func darwinTopologySupportSource() throws -> String {
    let repositoryRoot = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(
        contentsOf: repositoryRoot.appending(
            path: "Sources/StornautLifecycle/DarwinRootTopologySupport.swift"
        ),
        encoding: .utf8
    )
}
