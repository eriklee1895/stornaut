import Darwin
import Foundation
import Testing
@testable import StornautLifecycle

@Suite("Darwin root topology support", .serialized)
struct DarwinRootTopologySupportTests {
    @Test
    func onlyInitialENOENTIsClassifiedAsAbsent() throws {
        let fixture = try DarwinRootTopologyFixture()
        defer { fixture.remove() }
        let missing = fixture.root.appending(path: "missing")
        let expectation = fixture.fileExpectation(url: missing)

        #expect(
            DarwinRootTopologyNodeReader().observe(expectation)
                == .absent
        )

        let unavailable = DarwinRootTopologyNodeReader(
            fileSystem: ScriptedRootTopologyFileSystem(
                pathResults: [
                    .failure(
                        LifecycleRootTopologySystemCallError(
                            errno: EACCES
                        )
                    ),
                ]
            )
        ).observe(expectation)
        #expect(
            unavailable == .unavailable(
                reasonKey: "runtime.topology.lstat-unavailable"
            )
        )
    }

    @Test
    func symlinkHardlinkWrongModeAndWrongOwnerAreInvalid() throws {
        let fixture = try DarwinRootTopologyFixture()
        defer { fixture.remove() }
        let file = try fixture.makeFile(name: "artifact", data: "payload")
        let symlink = fixture.root.appending(path: "artifact-link")
        let hardlink = fixture.root.appending(path: "artifact-hardlink")
        try FileManager.default.createSymbolicLink(
            at: symlink,
            withDestinationURL: file
        )
        try FileManager.default.linkItem(at: file, to: hardlink)

        let reader = DarwinRootTopologyNodeReader()
        #expect(reader.observe(fixture.fileExpectation(url: symlink)).isInvalid)
        #expect(reader.observe(fixture.fileExpectation(url: file)).isInvalid)

        try FileManager.default.removeItem(at: hardlink)
        chmod(file.path, 0o644)
        #expect(reader.observe(fixture.fileExpectation(url: file)).isInvalid)

        let wrongOwner = LifecycleRootTopologyNodeExpectation(
            url: file,
            kind: .regularFile,
            ownerUserID: geteuid() + 1,
            ownerGroupID: getegid(),
            mode: 0o600,
            requiresSingleLink: true,
            expectedSHA256: nil,
            maximumSize: 1_024
        )
        #expect(reader.observe(wrongOwner).isInvalid)
    }

    @Test
    func exactDescriptorAndHashAreRequiredForPresentValid() throws {
        let fixture = try DarwinRootTopologyFixture()
        defer { fixture.remove() }
        let file = try fixture.makeFile(name: "artifact", data: "payload")
        let expected = DarwinRootTopologyNodeReader.sha256(
            Data("payload".utf8)
        )
        let valid = LifecycleRootTopologyNodeExpectation(
            url: file,
            kind: .regularFile,
            ownerUserID: geteuid(),
            ownerGroupID: getegid(),
            mode: 0o600,
            requiresSingleLink: true,
            expectedSHA256: expected,
            maximumSize: 1_024
        )
        let mismatched = LifecycleRootTopologyNodeExpectation(
            url: file,
            kind: .regularFile,
            ownerUserID: geteuid(),
            ownerGroupID: getegid(),
            mode: 0o600,
            requiresSingleLink: true,
            expectedSHA256: String(repeating: "0", count: 64),
            maximumSize: 1_024
        )

        #expect(DarwinRootTopologyNodeReader().observe(valid) == .presentValid)
        #expect(DarwinRootTopologyNodeReader().observe(mismatched).isInvalid)
    }

    @Test
    func identityChangeBetweenPathAndDescriptorReadFailsClosed() throws {
        let fixture = try DarwinRootTopologyFixture()
        defer { fixture.remove() }
        let file = try fixture.makeFile(name: "artifact", data: "payload")
        let first = try fixture.metadata(for: file)
        var changed = first
        changed.inode &+= 1
        let fileSystem = ScriptedRootTopologyFileSystem(
            pathResults: [.success(first)],
            openResult: .success(99),
            descriptorResults: [.success(changed)]
        )

        let observation = DarwinRootTopologyNodeReader(
            fileSystem: fileSystem
        ).observe(fixture.fileExpectation(url: file))

        #expect(
            observation == .invalid(
                reasonKey: "runtime.topology.node-identity-changed"
            )
        )
    }

    @Test
    func vanishAfterInitialLstatIsUnavailableRatherThanAbsent() throws {
        let fixture = try DarwinRootTopologyFixture()
        defer { fixture.remove() }
        let file = try fixture.makeFile(name: "artifact", data: "payload")
        let first = try fixture.metadata(for: file)
        let fileSystem = ScriptedRootTopologyFileSystem(
            pathResults: [.success(first)],
            openResult: .failure(
                LifecycleRootTopologySystemCallError(errno: ENOENT)
            )
        )

        let observation = DarwinRootTopologyNodeReader(
            fileSystem: fileSystem
        ).observe(fixture.fileExpectation(url: file))

        #expect(
            observation == .unavailable(
                reasonKey: "runtime.topology.open-unavailable"
            )
        )
    }

    @Test
    func finalPathMetadataDriftFailsClosed() throws {
        let fixture = try DarwinRootTopologyFixture()
        defer { fixture.remove() }
        let file = try fixture.makeFile(name: "artifact", data: "payload")
        let first = try fixture.metadata(for: file)
        var changed = first
        changed.mode = (changed.mode & mode_t(S_IFMT)) | 0o644
        let fileSystem = ScriptedRootTopologyFileSystem(
            pathResults: [.success(first), .success(changed)],
            openResult: .success(99),
            descriptorResults: [.success(first)]
        )

        let observation = DarwinRootTopologyNodeReader(
            fileSystem: fileSystem
        ).observe(fixture.fileExpectation(url: file))

        #expect(
            observation == .invalid(
                reasonKey: "runtime.topology.node-metadata-changed"
            )
        )
    }

    @Test
    func processReaderClassifiesIdentityReuseAfterPathAndSigning() throws {
        let expected = topologyProcessIdentity(
            processID: 701,
            version: 11,
            auditSessionID: 44_001,
            effectiveUserID: 501,
            tokenSeed: 1
        )
        let reused = topologyProcessIdentity(
            processID: 701,
            version: 12,
            auditSessionID: 44_001,
            effectiveUserID: 501,
            tokenSeed: 21
        )
        let reader = DarwinRootTopologyProcessReader(
            identityReader: ScriptedProcessIdentityReader(
                results: [.success(expected), .success(reused)]
            ),
            executableReader: FixedProcessExecutableReader(
                result: .success(URL(filePath: "/fixed/app"))
            ),
            signingVerifier: FixedProcessSigningVerifier(
                result: .verified(
                    processID: 701,
                    effectiveUserID: 501,
                    signingIdentifier: "com.eriklee.stornaut",
                    designatedRequirementSHA256: topologySupportDigest("a"),
                    codeDirectoryHash: String(repeating: "1", count: 40)
                )
            )
        )

        #expect(
            reader.read(processID: 701) == .identityReused
        )
    }

    @Test
    func processReaderUsesTheFullRootHelperAuditTokenForSigning() throws {
        let rootHelper = topologyProcessIdentity(
            processID: 702,
            version: 12,
            auditSessionID: 33_001,
            effectiveUserID: 0,
            tokenSeed: 11
        )
        let signingIdentity = try LifecycleSigningIdentity(
            signingIdentifier: "com.eriklee.stornaut.lifecycle.helper",
            designatedRequirementSHA256: topologySupportDigest("a"),
            codeDirectoryHash: String(repeating: "1", count: 40)
        )
        let signing = RecordingProcessAuditTokenSigningVerifier(
            result: .verified(
                processID: rootHelper.processID,
                effectiveUserID: 0,
                signingIdentifier: signingIdentity.signingIdentifier,
                designatedRequirementSHA256:
                    signingIdentity.designatedRequirementSHA256,
                codeDirectoryHash: signingIdentity.codeDirectoryHash
            )
        )
        let executableURL = URL(filePath: "/fixed/root-helper")
        let reader = DarwinRootTopologyProcessReader(
            identityReader: ScriptedProcessIdentityReader(
                results: [.success(rootHelper), .success(rootHelper)]
            ),
            executableReader: FixedProcessExecutableReader(
                result: .success(executableURL)
            ),
            signingVerifier: signing
        )

        #expect(
            reader.read(processID: rootHelper.processID) == .observed(
                LifecycleRootTopologyProcessSnapshot(
                    identity: rootHelper,
                    executableURL: executableURL,
                    signingIdentity: signingIdentity
                )
            )
        )
        #expect(signing.auditTokens == [rootHelper.auditToken])
    }

    @Test
    func rootSigningEvidenceDoesNotAuthorizeARootAppCaller() {
        let verifier = RecordingProcessAuditTokenSigningVerifier(
            result: .verified(
                processID: 702,
                effectiveUserID: 0,
                signingIdentifier: "com.eriklee.stornaut",
                designatedRequirementSHA256: topologySupportDigest("a"),
                codeDirectoryHash: String(repeating: "1", count: 40)
            )
        )
        let policy = LifecycleAppAuthorizationPolicy(
            expectedSigningIdentifier: "com.eriklee.stornaut",
            expectedDesignatedRequirementSHA256: topologySupportDigest("a"),
            expectedCodeDirectoryHash: String(repeating: "1", count: 40),
            verifier: verifier
        )

        #expect(!policy.authorize(
            LifecycleCallerIdentity(
                processID: 702,
                effectiveUserID: 0,
                signingIdentifier: "com.eriklee.stornaut"
            ),
            auditToken: topologyProcessIdentity(
                processID: 702,
                version: 12,
                auditSessionID: 33_001,
                effectiveUserID: 0,
                tokenSeed: 11
            ).auditToken
        ))
        #expect(verifier.auditTokens.isEmpty)
    }

    @Test
    func initialESRCHIsAbsentButMidObservationESRCHIsUnresolved() throws {
        let expected = topologyProcessIdentity(
            processID: 701,
            version: 11,
            auditSessionID: 44_001,
            effectiveUserID: 501,
            tokenSeed: 1
        )
        let initial = DarwinRootTopologyProcessReader(
            identityReader: ScriptedProcessIdentityReader(
                results: [.failure(.identityUnavailable(errno: ESRCH))]
            ),
            executableReader: FixedProcessExecutableReader(
                result: .failure(.unavailable)
            ),
            signingVerifier: FixedProcessSigningVerifier(result: .unresolved)
        )
        let vanished = DarwinRootTopologyProcessReader(
            identityReader: ScriptedProcessIdentityReader(
                results: [
                    .success(expected),
                    .failure(.identityUnavailable(errno: ESRCH)),
                ]
            ),
            executableReader: FixedProcessExecutableReader(
                result: .success(URL(filePath: "/fixed/app"))
            ),
            signingVerifier: FixedProcessSigningVerifier(
                result: .verified(
                    processID: 701,
                    effectiveUserID: 501,
                    signingIdentifier: "com.eriklee.stornaut",
                    designatedRequirementSHA256: topologySupportDigest("a"),
                    codeDirectoryHash: String(repeating: "1", count: 40)
                )
            )
        )

        #expect(initial.read(processID: 701) == .absent)
        #expect(
            vanished.read(processID: 701) == .unresolved(
                reasonKey: "runtime.topology.process-vanished"
            )
        )
    }

    @Test
    func artifactReaderMapsEveryRoleToTheExactFixedExpectation() throws {
        let contract = try LifecycleLocalInstallationContract()
        let binding = try topologySupportBinding()
        let nodes = RecordingRootTopologyNodeObserver(
            results: Array(
                repeating: .presentValid,
                count: 8
            )
        )
        let signing = RecordingRootTopologySigningReader(
            results: [
                contract.installedAppURL:
                    .observed(binding.appSigningEvidence),
                contract.helperExecutableURL:
                    .observed(binding.helperSigningEvidence),
            ]
        )
        let manifest = RecordingRootTopologyManifestReader(
            result: .presentValid
        )
        let reader = DarwinRootTopologyArtifactReader(
            nodeObserver: nodes,
            signingReader: signing,
            manifestReader: manifest
        )

        for role in LifecycleRootTopologyArtifactRole.allCases {
            #expect(
                reader.observe(
                    role,
                    contract: contract,
                    binding: binding
                ) == .presentValid
            )
        }

        #expect(nodes.expectations == [
            topologyNodeExpectation(
                url: contract.installedRootURL,
                kind: .directory,
                mode: 0o755
            ),
            topologyNodeExpectation(
                url: contract.installedAppURL,
                kind: .directory,
                mode: 0o755
            ),
            topologyNodeExpectation(
                url: contract.installedAppURL,
                kind: .directory,
                mode: 0o755
            ),
            topologyNodeExpectation(
                url: contract.appExecutableURL,
                kind: .regularFile,
                mode: 0o755,
                expectedSHA256: binding.appSigningEvidence.executableSHA256,
                maximumSize: DarwinRootTopologyArtifactReader
                    .maximumExecutableBytes
            ),
            topologyNodeExpectation(
                url: contract.helperExecutableURL,
                kind: .regularFile,
                mode: 0o755,
                expectedSHA256:
                    binding.helperSigningEvidence.executableSHA256,
                maximumSize: DarwinRootTopologyArtifactReader
                    .maximumExecutableBytes
            ),
            topologyNodeExpectation(
                url: contract.helperExecutableURL,
                kind: .regularFile,
                mode: 0o755,
                expectedSHA256:
                    binding.helperSigningEvidence.executableSHA256,
                maximumSize: DarwinRootTopologyArtifactReader
                    .maximumExecutableBytes
            ),
            topologyNodeExpectation(
                url: contract.runtimeRootURL,
                kind: .directory,
                mode: 0o711
            ),
            topologyNodeExpectation(
                url: contract.leaseRootURL,
                kind: .directory,
                mode: 0o700
            ),
        ])
        #expect(signing.urls == [
            contract.installedAppURL,
            contract.helperExecutableURL,
        ])
        #expect(manifest.expectations == [
            topologyNodeExpectation(
                url: contract.launchDaemonPlistURL,
                kind: .regularFile,
                mode: 0o644,
                maximumSize: DarwinRootTopologyArtifactReader
                    .maximumLaunchDaemonPlistBytes
            ),
        ])
    }

    @Test
    func artifactReaderRejectsSigningAndManifestDrift() throws {
        let contract = try LifecycleLocalInstallationContract()
        let binding = try topologySupportBinding()
        let foreignIdentity = try LifecycleSigningIdentity(
            signingIdentifier: "com.eriklee.stornaut.foreign",
            designatedRequirementSHA256: topologySupportDigest("e"),
            codeDirectoryHash: String(repeating: "3", count: 40)
        )
        let foreignEvidence = try LifecycleBundleSigningEvidence(
            identity: foreignIdentity,
            executableSHA256: binding.appSigningEvidence.executableSHA256,
            isAdHoc: true
        )
        let reader = DarwinRootTopologyArtifactReader(
            nodeObserver: RecordingRootTopologyNodeObserver(
                results: [
                    .presentValid,
                    .presentValid,
                    .presentValid,
                    .presentValid,
                ]
            ),
            signingReader: RecordingRootTopologySigningReader(
                results: [
                    contract.installedAppURL: .observed(foreignEvidence),
                    contract.helperExecutableURL: .unavailable(
                        reasonKey: "runtime.topology.signing-unavailable"
                    ),
                ]
            ),
            manifestReader: RecordingRootTopologyManifestReader(
                result: .invalid(
                    reasonKey: "runtime.topology.plist-mismatch"
                )
            )
        )

        #expect(
            reader.observe(
                .installedApp,
                contract: contract,
                binding: binding
            ) == .invalid(
                reasonKey: "runtime.topology.signing-mismatch"
            )
        )
        #expect(
            reader.observe(
                .helperExecutable,
                contract: contract,
                binding: binding
            ) == .unavailable(
                reasonKey: "runtime.topology.signing-unavailable"
            )
        )
        #expect(
            reader.observe(
                .launchDaemonPlist,
                contract: contract,
                binding: binding
            ) == .invalid(
                reasonKey: "runtime.topology.plist-mismatch"
            )
        )
    }

    @Test
    func artifactReaderRevalidatesTheFixedNodeAfterSigning() throws {
        let contract = try LifecycleLocalInstallationContract()
        let binding = try topologySupportBinding()
        let reader = DarwinRootTopologyArtifactReader(
            nodeObserver: RecordingRootTopologyNodeObserver(
                results: [
                    .presentValid,
                    .invalid(
                        reasonKey: "runtime.topology.node-identity-changed"
                    ),
                ]
            ),
            signingReader: RecordingRootTopologySigningReader(
                results: [
                    contract.installedAppURL:
                        .observed(binding.appSigningEvidence),
                ]
            ),
            manifestReader: RecordingRootTopologyManifestReader(
                result: .presentValid
            )
        )

        #expect(
            reader.observe(
                .installedApp,
                contract: contract,
                binding: binding
            ) == .invalid(
                reasonKey: "runtime.topology.node-identity-changed"
            )
        )
    }

    @Test
    func absentSignedArtifactsDoNotInvokeTheSigningReader() throws {
        let contract = try LifecycleLocalInstallationContract()
        let binding = try topologySupportBinding()
        let signing = RecordingRootTopologySigningReader(results: [:])
        let reader = DarwinRootTopologyArtifactReader(
            nodeObserver: RecordingRootTopologyNodeObserver(
                results: [.absent, .absent]
            ),
            signingReader: signing,
            manifestReader: RecordingRootTopologyManifestReader(
                result: .absent
            )
        )

        #expect(
            reader.observe(
                .installedApp,
                contract: contract,
                binding: binding
            ) == .absent
        )
        #expect(
            reader.observe(
                .helperExecutable,
                contract: contract,
                binding: binding
            ) == .absent
        )
        #expect(signing.urls.isEmpty)
    }

    @Test
    func manifestReaderRequiresExactDescriptorAndClosedManifest() throws {
        let fixture = try DarwinRootTopologyFixture()
        defer { fixture.remove() }
        let contract = try LifecycleLocalInstallationContract()
        let validData = try PropertyListSerialization.data(
            fromPropertyList: contract.launchDaemonManifest(),
            format: .xml,
            options: 0
        )
        let plist = try fixture.makeFile(
            name: "lifecycle.plist",
            data: validData
        )
        let expectation = LifecycleRootTopologyNodeExpectation(
            url: plist,
            kind: .regularFile,
            ownerUserID: geteuid(),
            ownerGroupID: getegid(),
            mode: 0o600,
            requiresSingleLink: true,
            expectedSHA256: nil,
            maximumSize: 64 * 1_024
        )
        let reader = DarwinRootTopologyManifestReader()

        #expect(
            reader.observe(
                expectation: expectation,
                contract: contract
            ) == .presentValid
        )

        var unknown = contract.launchDaemonManifest()
        unknown["StandardOutPath"] = "/tmp/forbidden"
        let unknownData = try PropertyListSerialization.data(
            fromPropertyList: unknown,
            format: .xml,
            options: 0
        )
        try unknownData.write(to: plist, options: .atomic)
        chmod(plist.path, 0o600)
        #expect(
            reader.observe(
                expectation: expectation,
                contract: contract
            ) == .invalid(
                reasonKey: "runtime.topology.plist-mismatch"
            )
        )

        let symlink = fixture.root.appending(path: "lifecycle-link.plist")
        try FileManager.default.createSymbolicLink(
            at: symlink,
            withDestinationURL: plist
        )
        let symlinkExpectation = LifecycleRootTopologyNodeExpectation(
            url: symlink,
            kind: .regularFile,
            ownerUserID: geteuid(),
            ownerGroupID: getegid(),
            mode: 0o600,
            requiresSingleLink: true,
            expectedSHA256: nil,
            maximumSize: 64 * 1_024
        )
        #expect(
            reader.observe(
                expectation: symlinkExpectation,
                contract: contract
            ).isInvalid
        )
    }
}

private final class DarwinRootTopologyFixture: @unchecked Sendable {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-root-topology-(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
    }

    func makeFile(name: String, data: String) throws -> URL {
        try makeFile(name: name, data: Data(data.utf8))
    }

    func makeFile(name: String, data: Data) throws -> URL {
        let url = root.appending(path: name)
        try data.write(to: url, options: .withoutOverwriting)
        chmod(url.path, 0o600)
        return url
    }

    func fileExpectation(
        url: URL
    ) -> LifecycleRootTopologyNodeExpectation {
        LifecycleRootTopologyNodeExpectation(
            url: url,
            kind: .regularFile,
            ownerUserID: geteuid(),
            ownerGroupID: getegid(),
            mode: 0o600,
            requiresSingleLink: true,
            expectedSHA256: nil,
            maximumSize: 1_024
        )
    }

    func metadata(for url: URL) throws -> LifecycleRootTopologyNodeMetadata {
        var value = stat()
        guard lstat(url.path, &value) == 0 else {
            throw CocoaError(.fileReadUnknown)
        }
        return LifecycleRootTopologyNodeMetadata(value)
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

private final class ScriptedRootTopologyFileSystem:
    LifecycleRootTopologyFileSystem,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var pathResults: [
        Result<
            LifecycleRootTopologyNodeMetadata,
            LifecycleRootTopologySystemCallError
        >
    ]
    private let openResult: Result<
        Int32,
        LifecycleRootTopologySystemCallError
    >
    private var descriptorResults: [
        Result<
            LifecycleRootTopologyNodeMetadata,
            LifecycleRootTopologySystemCallError
        >
    ]

    init(
        pathResults: [
            Result<
                LifecycleRootTopologyNodeMetadata,
                LifecycleRootTopologySystemCallError
            >
        ],
        openResult: Result<
            Int32,
            LifecycleRootTopologySystemCallError
        > = .failure(
            LifecycleRootTopologySystemCallError(errno: EACCES)
        ),
        descriptorResults: [
            Result<
                LifecycleRootTopologyNodeMetadata,
                LifecycleRootTopologySystemCallError
            >
        ] = []
    ) {
        self.pathResults = pathResults
        self.openResult = openResult
        self.descriptorResults = descriptorResults
    }

    func metadata(
        at _: URL
    ) -> Result<
        LifecycleRootTopologyNodeMetadata,
        LifecycleRootTopologySystemCallError
    > {
        lock.withLock { pathResults.removeFirst() }
    }

    func openReadOnly(
        _: URL,
        kind _: LifecycleRootTopologyNodeKind
    ) -> Result<Int32, LifecycleRootTopologySystemCallError> {
        openResult
    }

    func metadata(
        for _: Int32
    ) -> Result<
        LifecycleRootTopologyNodeMetadata,
        LifecycleRootTopologySystemCallError
    > {
        lock.withLock { descriptorResults.removeFirst() }
    }

    func read(
        from _: Int32,
        maximumBytes _: Int
    ) -> Result<Data, LifecycleRootTopologySystemCallError> {
        .failure(LifecycleRootTopologySystemCallError(errno: EIO))
    }

    func close(_: Int32) {}
}

private final class ScriptedProcessIdentityReader:
    LifecycleRootTopologyProcessIdentityReading,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var results: [
        Result<LifecycleProcessIdentity, DarwinLifecycleSupportError>
    ]

    init(
        results: [Result<LifecycleProcessIdentity, DarwinLifecycleSupportError>]
    ) {
        self.results = results
    }

    func identity(
        for _: pid_t
    ) -> Result<LifecycleProcessIdentity, DarwinLifecycleSupportError> {
        lock.withLock { results.removeFirst() }
    }
}

private struct FixedProcessExecutableReader:
    LifecycleRootTopologyProcessExecutableReading
{
    let result: Result<URL, LifecycleRootTopologyProcessExecutableError>

    func executableURL(
        for _: pid_t
    ) -> Result<URL, LifecycleRootTopologyProcessExecutableError> {
        result
    }
}

private struct FixedProcessSigningVerifier:
    LifecycleCodeSigningVerifying
{
    let result: LifecycleCodeSigningVerification

    func verify(
        auditToken _: LifecycleAuditToken
    ) -> LifecycleCodeSigningVerification {
        result
    }
}

private final class RecordingProcessAuditTokenSigningVerifier:
    LifecycleCodeSigningVerifying,
    @unchecked Sendable
{
    let result: LifecycleCodeSigningVerification
    private let lock = NSLock()
    private(set) var auditTokens: [LifecycleAuditToken] = []

    init(result: LifecycleCodeSigningVerification) {
        self.result = result
    }

    func verify(
        auditToken: LifecycleAuditToken
    ) -> LifecycleCodeSigningVerification {
        lock.withLock { auditTokens.append(auditToken) }
        return result
    }
}

private final class RecordingRootTopologyNodeObserver:
    LifecycleRootTopologyNodeObserving,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var results: [LifecycleRootTopologyArtifactObservation]
    private(set) var expectations: [LifecycleRootTopologyNodeExpectation] = []

    init(results: [LifecycleRootTopologyArtifactObservation]) {
        self.results = results
    }

    func observe(
        _ expectation: LifecycleRootTopologyNodeExpectation
    ) -> LifecycleRootTopologyArtifactObservation {
        lock.withLock {
            expectations.append(expectation)
            return results.removeFirst()
        }
    }
}

private final class RecordingRootTopologySigningReader:
    LifecycleRootTopologySigningEvidenceReading,
    @unchecked Sendable
{
    let results: [URL: LifecycleRootTopologySigningEvidenceResult]
    private let lock = NSLock()
    private(set) var urls: [URL] = []

    init(results: [URL: LifecycleRootTopologySigningEvidenceResult]) {
        self.results = results
    }

    func read(
        at url: URL
    ) -> LifecycleRootTopologySigningEvidenceResult {
        lock.withLock { urls.append(url) }
        return results[url] ?? .unavailable(
            reasonKey: "runtime.topology.fixture-missing"
        )
    }
}

private final class RecordingRootTopologyManifestReader:
    LifecycleRootTopologyManifestReading,
    @unchecked Sendable
{
    let result: LifecycleRootTopologyArtifactObservation
    private let lock = NSLock()
    private(set) var expectations: [LifecycleRootTopologyNodeExpectation] = []

    init(result: LifecycleRootTopologyArtifactObservation) {
        self.result = result
    }

    func observe(
        expectation: LifecycleRootTopologyNodeExpectation,
        contract _: LifecycleLocalInstallationContract
    ) -> LifecycleRootTopologyArtifactObservation {
        lock.withLock { expectations.append(expectation) }
        return result
    }
}

private func topologyNodeExpectation(
    url: URL,
    kind: LifecycleRootTopologyNodeKind,
    mode: mode_t,
    expectedSHA256: String? = nil,
    maximumSize: Int = 0
) -> LifecycleRootTopologyNodeExpectation {
    LifecycleRootTopologyNodeExpectation(
        url: url,
        kind: kind,
        ownerUserID: 0,
        ownerGroupID: 0,
        mode: mode,
        requiresSingleLink: kind == .regularFile,
        expectedSHA256: expectedSHA256,
        maximumSize: maximumSize
    )
}

private func topologySupportBinding() throws -> LifecycleRootTopologyBinding {
    let appIdentity = try LifecycleSigningIdentity(
        signingIdentifier: "com.eriklee.stornaut",
        designatedRequirementSHA256: topologySupportDigest("a"),
        codeDirectoryHash: String(repeating: "1", count: 40)
    )
    let helperIdentity = try LifecycleSigningIdentity(
        signingIdentifier: "com.eriklee.stornaut.lifecycle.helper",
        designatedRequirementSHA256: topologySupportDigest("b"),
        codeDirectoryHash: String(repeating: "2", count: 40)
    )
    return try LifecycleRootTopologyBinding(
        appSigningEvidence: LifecycleBundleSigningEvidence(
            identity: appIdentity,
            executableSHA256: topologySupportDigest("c"),
            isAdHoc: true
        ),
        helperSigningEvidence: LifecycleBundleSigningEvidence(
            identity: helperIdentity,
            executableSHA256: topologySupportDigest("d"),
            isAdHoc: true
        ),
        appBundleIdentifier: "com.eriklee.stornaut",
        helperServiceIdentifier: "com.eriklee.stornaut.lifecycle"
    )
}

private func topologyProcessIdentity(
    processID: pid_t,
    version: Int32,
    auditSessionID: Int32,
    effectiveUserID: uid_t,
    tokenSeed: UInt32
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

private func topologySupportDigest(_ character: Character) -> String {
    String(repeating: character, count: 64)
}

private extension LifecycleRootTopologyArtifactObservation {
    var isInvalid: Bool {
        if case .invalid = self {
            return true
        }
        return false
    }
}
