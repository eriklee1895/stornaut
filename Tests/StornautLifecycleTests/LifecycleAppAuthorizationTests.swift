import Darwin
import Foundation
import Testing
@testable import StornautLifecycle

@Suite("R5 lifecycle App authorization")
struct LifecycleAppAuthorizationTests {
    @Test
    func exactAuditTokenIdentityAndRequirementAreAuthorized() {
        let verifier = RecordingLifecycleCodeSigningVerifier(
            result: .verified(
                processID: 701,
                effectiveUserID: 501,
                signingIdentifier: "com.eriklee.stornaut",
                designatedRequirementSHA256: digest("a"),
                codeDirectoryHash: cdhash("1")
            )
        )
        let policy = LifecycleAppAuthorizationPolicy(
            expectedSigningIdentifier: "com.eriklee.stornaut",
            expectedDesignatedRequirementSHA256: digest("a"),
            expectedCodeDirectoryHash: cdhash("1"),
            verifier: verifier
        )
        let caller = LifecycleCallerIdentity(
            processID: 701,
            effectiveUserID: 501,
            signingIdentifier: "com.eriklee.stornaut"
        )

        #expect(policy.authorize(caller, auditToken: auditToken()))
        #expect(verifier.auditTokens == [auditToken()])
    }

    @Test(arguments: [
        (
            LifecycleCodeSigningVerification.verified(
                processID: 701,
                effectiveUserID: 501,
                signingIdentifier: "untrusted.codex",
                designatedRequirementSHA256: digest("a"),
                codeDirectoryHash: cdhash("1")
            ),
            "com.eriklee.stornaut",
            digest("a"),
            cdhash("1")
        ),
        (
            LifecycleCodeSigningVerification.verified(
                processID: 701,
                effectiveUserID: 501,
                signingIdentifier: "com.eriklee.stornaut",
                designatedRequirementSHA256: digest("b"),
                codeDirectoryHash: cdhash("1")
            ),
            "com.eriklee.stornaut",
            digest("a"),
            cdhash("1")
        ),
        (
            LifecycleCodeSigningVerification.verified(
                processID: 701,
                effectiveUserID: 501,
                signingIdentifier: "com.eriklee.stornaut",
                designatedRequirementSHA256: digest("a"),
                codeDirectoryHash: cdhash("2")
            ),
            "com.eriklee.stornaut",
            digest("a"),
            cdhash("1")
        ),
        (
            LifecycleCodeSigningVerification.unresolved,
            "com.eriklee.stornaut",
            digest("a"),
            cdhash("1")
        ),
    ])
    func rejectsForeignUnresolvedAndRequirementMismatchedCallers(
        verification: LifecycleCodeSigningVerification,
        expectedIdentifier: String,
        expectedRequirement: String,
        expectedCodeDirectoryHash: String
    ) {
        let policy = LifecycleAppAuthorizationPolicy(
            expectedSigningIdentifier: expectedIdentifier,
            expectedDesignatedRequirementSHA256: expectedRequirement,
            expectedCodeDirectoryHash: expectedCodeDirectoryHash,
            verifier: RecordingLifecycleCodeSigningVerifier(
                result: verification
            )
        )
        let caller = LifecycleCallerIdentity(
            processID: 701,
            effectiveUserID: 501,
            signingIdentifier: "com.eriklee.stornaut"
        )

        #expect(!policy.authorize(caller, auditToken: auditToken()))
    }

    @Test
    func callerSuppliedSigningIdentifierCannotOverrideAuditTokenEvidence() {
        let policy = LifecycleAppAuthorizationPolicy(
            expectedSigningIdentifier: "com.eriklee.stornaut",
            expectedDesignatedRequirementSHA256: digest("a"),
            expectedCodeDirectoryHash: cdhash("1"),
            verifier: RecordingLifecycleCodeSigningVerifier(
                result: .verified(
                    processID: 701,
                    effectiveUserID: 501,
                    signingIdentifier: "untrusted.codex",
                    designatedRequirementSHA256: digest("a"),
                    codeDirectoryHash: cdhash("1")
                )
            )
        )
        let caller = LifecycleCallerIdentity(
            processID: 701,
            effectiveUserID: 501,
            signingIdentifier: "com.eriklee.stornaut"
        )

        #expect(!policy.authorize(caller, auditToken: auditToken()))
    }

    @Test
    func callerProcessAndUserMustMatchAuditTokenEvidence() {
        let policy = LifecycleAppAuthorizationPolicy(
            expectedSigningIdentifier: "com.eriklee.stornaut",
            expectedDesignatedRequirementSHA256: digest("a"),
            expectedCodeDirectoryHash: cdhash("1"),
            verifier: RecordingLifecycleCodeSigningVerifier(
                result: .verified(
                    processID: 702,
                    effectiveUserID: 502,
                    signingIdentifier: "com.eriklee.stornaut",
                    designatedRequirementSHA256: digest("a"),
                    codeDirectoryHash: cdhash("1")
                )
            )
        )

        #expect(!policy.authorize(
            LifecycleCallerIdentity(
                processID: 701,
                effectiveUserID: 501,
                signingIdentifier: "com.eriklee.stornaut"
            ),
            auditToken: auditToken()
        ))
    }

    @Test
    func peerRequirementBindsIdentifierAndExactCodeDirectoryHash() throws {
        let identity = try LifecycleSigningIdentity(
            signingIdentifier: "com.eriklee.stornaut",
            designatedRequirementSHA256: digest("a"),
            codeDirectoryHash: cdhash("1")
        )

        #expect(
            LifecyclePeerCodeSigningRequirement.exact(identity: identity)
                == """
                identifier "com.eriklee.stornaut" and \
                cdhash H"1111111111111111111111111111111111111111"
                """
        )
    }

    @Test
    func signingExecutableResolverAcceptsMachOShapeAndRejectsSymlink()
        throws
    {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-signing-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let executable = root.appending(path: "helper")
        let symlink = root.appending(path: "helper-link")
        try Data("synthetic".utf8).write(to: executable)
        chmod(executable.path, 0o755)
        try FileManager.default.createSymbolicLink(
            at: symlink,
            withDestinationURL: executable
        )

        #expect(
            lifecycleSigningExecutableURL(for: executable)
                == executable.standardizedFileURL
        )
        #expect(lifecycleSigningExecutableURL(for: symlink) == nil)
        #expect(lifecycleSigningExecutableURL(for: root) == nil)
    }

    @Test
    func signingEvidenceRejectsSymlinkAndHardLinkExecutablePaths() throws {
        let root = URL(
            filePath: "/private/tmp", directoryHint: .isDirectory
        ).appending(
            path: "stornaut-signing-links-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let original = root.appending(path: "signed-tool")
        let symlink = root.appending(path: "signed-tool-symlink")
        let hardLink = root.appending(path: "signed-tool-hardlink")
        try FileManager.default.copyItem(
            at: currentTestExecutableURL(),
            to: original
        )
        try FileManager.default.createSymbolicLink(
            at: symlink, withDestinationURL: original
        )
        let reader = LifecycleBundleSigningIdentityReader()

        #expect(throws: LifecycleSigningIdentityError.unavailable) {
            _ = try reader.evidence(bundleURL: symlink)
        }

        try FileManager.default.linkItem(at: original, to: hardLink)
        #expect(throws: LifecycleSigningIdentityError.unavailable) {
            _ = try reader.evidence(bundleURL: hardLink)
        }
    }

    @Test
    func signingEvidenceRejectsInPlaceMutationAcrossItsReadWindow() throws {
        let root = URL(
            filePath: "/private/tmp", directoryHint: .isDirectory
        ).appending(
            path: "stornaut-signing-race-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let executable = root.appending(path: "signed-tool")
        try FileManager.default.copyItem(
            at: URL(filePath: CommandLine.arguments[0]),
            to: executable
        )
        let originalSize = try FileManager.default.attributesOfItem(
            atPath: executable.path
        )[.size] as! NSNumber
        let reader = LifecycleBundleSigningIdentityReader(
            hooks: LifecycleSigningEvidenceReadHooks(
                afterSigningInformation: {
                    guard let handle = try? FileHandle(
                        forWritingTo: executable
                    ) else { return }
                    try? handle.write(contentsOf: Data([0xff]))
                    try? handle.truncate(
                        atOffset: originalSize.uint64Value
                    )
                    try? handle.close()
                }
            )
        )

        #expect(throws: LifecycleSigningIdentityError.unavailable) {
            _ = try reader.evidence(bundleURL: executable)
        }
    }

    @Test
    func signingEvidenceRejectsOuterToInnerExecutableABA() throws {
        let root = URL(
            filePath: "/private/tmp", directoryHint: .isDirectory
        ).appending(
            path: "stornaut-signing-aba-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let executable = root.appending(path: "signed-tool")
        let original = root.appending(path: "signed-tool-original")
        let replacement = root.appending(path: "signed-tool-replacement")
        try FileManager.default.copyItem(
            at: currentTestExecutableURL(), to: executable
        )
        try FileManager.default.copyItem(
            at: currentTestExecutableURL(), to: replacement
        )
        try adHocSign(
            replacement, identifier: "com.eriklee.stornaut.aba-replacement"
        )
        let reader = LifecycleBundleSigningIdentityReader(
            hooks: LifecycleSigningEvidenceReadHooks(
                afterDescriptorOpened: {
                    try FileManager.default.moveItem(
                        at: executable, to: original
                    )
                    try FileManager.default.moveItem(
                        at: replacement, to: executable
                    )
                },
                afterFinalSigningInformation: {
                    try FileManager.default.moveItem(
                        at: executable, to: replacement
                    )
                    try FileManager.default.moveItem(
                        at: original, to: executable
                    )
                }
            )
        )

        #expect(throws: LifecycleSigningIdentityError.unavailable) {
            _ = try reader.evidence(bundleURL: executable)
        }
    }

    @Test
    func signedBundleObservationKeepsMetadataAllOrNothingWithoutChangingEvidence()
        throws
    {
        let identity = try LifecycleSigningIdentity(
            signingIdentifier: "com.eriklee.stornaut",
            designatedRequirementSHA256: digest("a"),
            codeDirectoryHash: cdhash("1")
        )
        let executable = URL(
            filePath:
                "/Applications/Stornaut-R5-Diagnostic.app/Contents/MacOS/"
                    + "StornautInvestigationDiagnostic"
        )

        let evidence = try LifecycleBundleSigningEvidence(
            identity: identity, executableSHA256: digest("b"),
            isAdHoc: true
        )
        #expect(
            Set(Mirror(reflecting: evidence).children.compactMap(\.label))
                == ["identity", "executableSHA256", "isAdHoc"]
        )
        #expect(throws: LifecycleSignedBundleObservationError
            .signedMetadataUnavailable) {
            _ = try LifecycleSignedBundleObservation(
                signingEvidence: evidence,
                mainExecutableURL: URL(string: "relative")!,
                bundleIdentifier: "com.eriklee.stornaut"
            )
        }
        #expect(throws: LifecycleSignedBundleObservationError
            .signedMetadataUnavailable) {
            _ = try LifecycleSignedBundleObservation(
                signingEvidence: evidence, mainExecutableURL: executable,
                bundleIdentifier: "invalid identifier"
            )
        }
        #expect(throws: LifecycleSignedBundleObservationError
            .signedMetadataUnavailable) {
            _ = try LifecycleSignedBundleObservation(
                signingEvidence: evidence, mainExecutableURL: executable,
                bundleIdentifier: "com.eriklee.foreign"
            )
        }
        let observation = try LifecycleSignedBundleObservation(
            signingEvidence: evidence, mainExecutableURL: executable,
            bundleIdentifier: "com.eriklee.stornaut"
        )
        #expect(observation.signingEvidence == evidence)
        #expect(observation.mainExecutableURL == executable.standardizedFileURL)
        #expect(observation.bundleIdentifier == "com.eriklee.stornaut")
    }

    @Test
    func signedBundleReaderUsesSignatureBoundExecutableAndPropertyList()
        throws
    {
        let root = URL(
            filePath: "/private/tmp", directoryHint: .isDirectory
        ).appending(
            path: "stornaut-signed-bundle-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        let bundle = root.appending(
            path: "Fixture.app", directoryHint: .isDirectory
        )
        let contents = bundle.appending(
            path: "Contents", directoryHint: .isDirectory
        )
        let executableDirectory = contents.appending(
            path: "MacOS", directoryHint: .isDirectory
        )
        let executableName = "SignedBundleFixture"
        let executable = executableDirectory.appending(
            path: executableName
        )
        try FileManager.default.createDirectory(
            at: executableDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let currentExecutable = URL(
            filePath: currentTestExecutableURL().path
        )
        try FileManager.default.copyItem(
            at: currentExecutable, to: executable
        )
        let propertyList: [String: Any] = [
            "CFBundleExecutable": executableName,
            "CFBundleIdentifier": "com.eriklee.stornaut.fixture",
            "CFBundlePackageType": "APPL",
            "CFBundleVersion": "1",
        ]
        try PropertyListSerialization.data(
            fromPropertyList: propertyList,
            format: .binary,
            options: 0
        ).write(to: contents.appending(path: "Info.plist"))
        let signer = Process()
        signer.executableURL = URL(filePath: "/usr/bin/codesign")
        signer.arguments = [
            "--force", "--sign", "-", "--timestamp=none",
            "--identifier", "com.eriklee.stornaut.fixture",
            bundle.path,
        ]
        signer.standardInput = FileHandle.nullDevice
        signer.standardOutput = FileHandle.nullDevice
        signer.standardError = FileHandle.nullDevice
        try signer.run()
        signer.waitUntilExit()
        try #require(signer.terminationStatus == 0)

        let reader = LifecycleBundleSigningIdentityReader()
        let observation = try reader.signedBundleObservation(
            bundleURL: bundle
        )

        #expect(observation.mainExecutableURL == executable.standardizedFileURL)
        #expect(observation.bundleIdentifier == "com.eriklee.stornaut.fixture")
        #expect(observation.signingEvidence == (
            try reader.evidence(bundleURL: bundle)
        ))
    }

    @Test
    func peerAdmissionRequiresExactProcessUserAndSigningIdentity()
        throws
    {
        let expected = try LifecycleSigningIdentity(
            signingIdentifier: "com.eriklee.stornaut",
            designatedRequirementSHA256: digest("a"),
            codeDirectoryHash: cdhash("1")
        )
        let verifier = RecordingLifecycleProcessCodeSigningVerifier(
            result: .verified(
                processID: 701,
                effectiveUserID: 501,
                signingIdentifier: "com.eriklee.stornaut",
                designatedRequirementSHA256: digest("a"),
                codeDirectoryHash: cdhash("1")
            )
        )
        let policy = LifecyclePeerAdmissionPolicy(
            expectedIdentity: expected,
            verifier: verifier
        )

        #expect(
            policy.authorize(
                processID: 701,
                effectiveUserID: 501
            )
        )
        #expect(
            verifier.requests == [
                ProcessVerificationRequest(
                    processID: 701,
                    effectiveUserID: 501
                ),
            ]
        )
        #expect(
            !policy.authorize(
                processID: 702,
                effectiveUserID: 501
            )
        )
    }

    @Test
    func machineDriverAdmissionRequiresFreshRootIdentityPathAndSigning()
        throws
    {
        let contract = try LifecycleLocalInstallationContract()
        let identity = try machineDriverIdentity()
        let signingIdentity = try LifecycleSigningIdentity(
            signingIdentifier:
                contract.machineDriverSigningIdentifier,
            designatedRequirementSHA256: digest("d"),
            codeDirectoryHash: cdhash("4")
        )
        let verifier = RecordingLifecycleCodeSigningVerifier(
            result: .verified(
                processID: identity.processID,
                effectiveUserID: 0,
                signingIdentifier: signingIdentity.signingIdentifier,
                designatedRequirementSHA256:
                    signingIdentity.designatedRequirementSHA256,
                codeDirectoryHash: signingIdentity.codeDirectoryHash
            )
        )
        let observation = RecordingMachineDriverObservation(
            identity: identity,
            executableURL: contract.machineDriverExecutableURL,
            signingEvidence: try LifecycleBundleSigningEvidence(
                identity: signingIdentity,
                executableSHA256: digest("e"),
                isAdHoc: true
            )
        )
        let policy = LifecycleMachineDriverAdmissionPolicy(
            processIdentity: observation.processIdentity,
            processExecutableURL: observation.processExecutableURL,
            signingEvidence: observation.signingEvidence,
            codeSigningVerifier: verifier
        )

        let admitted = policy.authorizeAndObserveStableEvidence(identity)
        #expect(admitted?.processIdentity == identity)
        #expect(admitted?.signingEvidence == observation.evidence)
        #expect(
            observation.identityRequests
                == [identity.processID, identity.processID]
        )
        #expect(
            observation.executableRequests
                == [identity.processID, identity.processID]
        )
        #expect(
            observation.signingRequests
                == [
                    contract.machineDriverExecutableURL,
                    contract.machineDriverExecutableURL,
                ]
        )
        #expect(
            verifier.auditTokens
                == [identity.auditToken, identity.auditToken]
        )

        #expect(policy.authorize(identity))
        #expect(
            observation.identityRequests
                == Array(repeating: identity.processID, count: 4)
        )
        #expect(
            observation.executableRequests
                == Array(repeating: identity.processID, count: 4)
        )
        #expect(
            observation.signingRequests
                == Array(
                    repeating: contract.machineDriverExecutableURL,
                    count: 4
                )
        )
        #expect(
            verifier.auditTokens
                == Array(repeating: identity.auditToken, count: 4)
        )
    }

    @Test
    func machineDriverAdmissionRejectsEveryRootIdentityAndPathDrift()
        throws
    {
        let contract = try LifecycleLocalInstallationContract()
        let identity = try machineDriverIdentity()
        let signingIdentity = try LifecycleSigningIdentity(
            signingIdentifier:
                contract.machineDriverSigningIdentifier,
            designatedRequirementSHA256: digest("d"),
            codeDirectoryHash: cdhash("4")
        )
        let evidence = try LifecycleBundleSigningEvidence(
            identity: signingIdentity,
            executableSHA256: digest("e"),
            isAdHoc: true
        )
        let validVerification = LifecycleCodeSigningVerification.verified(
            processID: identity.processID,
            effectiveUserID: 0,
            signingIdentifier: signingIdentity.signingIdentifier,
            designatedRequirementSHA256:
                signingIdentity.designatedRequirementSHA256,
            codeDirectoryHash: signingIdentity.codeDirectoryHash
        )

        for observation in [
            RecordingMachineDriverObservation(
                identity: try machineDriverIdentity(processIDVersion: 99),
                executableURL: contract.machineDriverExecutableURL,
                signingEvidence: evidence
            ),
            RecordingMachineDriverObservation(
                identity: identity,
                executableURL: URL(filePath: "/tmp/foreign-driver"),
                signingEvidence: evidence
            ),
            RecordingMachineDriverObservation(
                identity: identity,
                executableURL: contract.machineDriverExecutableURL,
                signingEvidence: try LifecycleBundleSigningEvidence(
                    identity: LifecycleSigningIdentity(
                        signingIdentifier: "foreign.machine-driver",
                        designatedRequirementSHA256: digest("d"),
                        codeDirectoryHash: cdhash("4")
                    ),
                    executableSHA256: digest("e"),
                    isAdHoc: true
                )
            ),
        ] {
            let policy = LifecycleMachineDriverAdmissionPolicy(
                processIdentity: observation.processIdentity,
                processExecutableURL: observation.processExecutableURL,
                signingEvidence: observation.signingEvidence,
                codeSigningVerifier:
                    RecordingLifecycleCodeSigningVerifier(
                        result: validVerification
                    )
            )
            #expect(!policy.authorize(identity))
        }
    }

    @Test
    func machineDriverAdmissionRejectsEverySecondObservationDrift()
        throws
    {
        let contract = try LifecycleLocalInstallationContract()
        let identity = try machineDriverIdentity()
        let signingIdentity = try LifecycleSigningIdentity(
            signingIdentifier: contract.machineDriverSigningIdentifier,
            designatedRequirementSHA256: digest("d"),
            codeDirectoryHash: cdhash("4")
        )
        let evidence = try LifecycleBundleSigningEvidence(
            identity: signingIdentity,
            executableSHA256: digest("e"),
            isAdHoc: true
        )
        let driftedEvidence = try LifecycleBundleSigningEvidence(
            identity: signingIdentity,
            executableSHA256: digest("f"),
            isAdHoc: true
        )
        let validVerification = LifecycleCodeSigningVerification.verified(
            processID: identity.processID,
            effectiveUserID: 0,
            signingIdentifier: signingIdentity.signingIdentifier,
            designatedRequirementSHA256:
                signingIdentity.designatedRequirementSHA256,
            codeDirectoryHash: signingIdentity.codeDirectoryHash
        )
        let driftedIdentity = try machineDriverIdentity(processIDVersion: 99)
        let foreignURL = URL(filePath: "/tmp/foreign-driver")
        let fixtures = [
            SequencedMachineDriverAdmissionFixture(
                identities: [identity, driftedIdentity],
                executableURLs: Array(
                    repeating: contract.machineDriverExecutableURL,
                    count: 2
                ),
                signingEvidence: Array(repeating: evidence, count: 2),
                verifications: Array(repeating: validVerification, count: 2)
            ),
            SequencedMachineDriverAdmissionFixture(
                identities: Array(repeating: identity, count: 2),
                executableURLs: [
                    contract.machineDriverExecutableURL,
                    foreignURL,
                ],
                signingEvidence: Array(repeating: evidence, count: 2),
                verifications: Array(repeating: validVerification, count: 2)
            ),
            SequencedMachineDriverAdmissionFixture(
                identities: Array(repeating: identity, count: 2),
                executableURLs: Array(
                    repeating: contract.machineDriverExecutableURL,
                    count: 2
                ),
                signingEvidence: [evidence, driftedEvidence],
                verifications: Array(repeating: validVerification, count: 2)
            ),
            SequencedMachineDriverAdmissionFixture(
                identities: Array(repeating: identity, count: 2),
                executableURLs: Array(
                    repeating: contract.machineDriverExecutableURL,
                    count: 2
                ),
                signingEvidence: Array(repeating: evidence, count: 2),
                verifications: [validVerification, .unresolved]
            ),
        ]
        for fixture in fixtures {
            #expect(
                fixture.policy.authorizeAndObserveStableEvidence(identity)
                    == nil
            )
        }
    }
}

private final class RecordingLifecycleCodeSigningVerifier:
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

private struct ProcessVerificationRequest: Equatable {
    let processID: pid_t
    let effectiveUserID: uid_t
}

private final class RecordingLifecycleProcessCodeSigningVerifier:
    LifecycleProcessCodeSigningVerifying,
    @unchecked Sendable
{
    let result: LifecycleCodeSigningVerification
    private let lock = NSLock()
    private(set) var requests: [ProcessVerificationRequest] = []

    init(result: LifecycleCodeSigningVerification) {
        self.result = result
    }

    func verify(
        processID: pid_t,
        effectiveUserID: uid_t
    ) -> LifecycleCodeSigningVerification {
        lock.withLock {
            requests.append(
                ProcessVerificationRequest(
                    processID: processID,
                    effectiveUserID: effectiveUserID
                )
            )
        }
        return result
    }
}

private final class RecordingMachineDriverObservation:
    @unchecked Sendable
{
    private let lock = NSLock()
    private let identity: LifecycleProcessIdentity
    private let executableURL: URL
    let evidence: LifecycleBundleSigningEvidence
    private(set) var identityRequests: [pid_t] = []
    private(set) var executableRequests: [pid_t] = []
    private(set) var signingRequests: [URL] = []

    init(
        identity: LifecycleProcessIdentity,
        executableURL: URL,
        signingEvidence: LifecycleBundleSigningEvidence
    ) {
        self.identity = identity
        self.executableURL = executableURL
        evidence = signingEvidence
    }

    func processIdentity(_ processID: pid_t) -> LifecycleProcessIdentity? {
        lock.withLock { identityRequests.append(processID) }
        return identity
    }

    func processExecutableURL(_ processID: pid_t) -> URL? {
        lock.withLock { executableRequests.append(processID) }
        return executableURL
    }

    func signingEvidence(_ url: URL) -> LifecycleBundleSigningEvidence? {
        lock.withLock { signingRequests.append(url) }
        return evidence
    }
}

private final class LockedSequence<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private let values: [Value]
    private var index = 0

    init(_ values: [Value]) {
        precondition(!values.isEmpty)
        self.values = values
    }

    func next() -> Value {
        lock.withLock {
            let value = values[min(index, values.count - 1)]
            index += 1
            return value
        }
    }
}

private final class SequencedLifecycleCodeSigningVerifier:
    LifecycleCodeSigningVerifying,
    @unchecked Sendable
{
    private let results: LockedSequence<LifecycleCodeSigningVerification>

    init(_ results: [LifecycleCodeSigningVerification]) {
        self.results = LockedSequence(results)
    }

    func verify(
        auditToken _: LifecycleAuditToken
    ) -> LifecycleCodeSigningVerification {
        results.next()
    }
}

private struct SequencedMachineDriverAdmissionFixture {
    let policy: LifecycleMachineDriverAdmissionPolicy

    init(
        identities: [LifecycleProcessIdentity],
        executableURLs: [URL],
        signingEvidence: [LifecycleBundleSigningEvidence],
        verifications: [LifecycleCodeSigningVerification]
    ) {
        let identitySequence = LockedSequence(identities)
        let executableSequence = LockedSequence(executableURLs)
        let signingSequence = LockedSequence(signingEvidence)
        policy = LifecycleMachineDriverAdmissionPolicy(
            processIdentity: { _ in identitySequence.next() },
            processExecutableURL: { _ in executableSequence.next() },
            signingEvidence: { _ in signingSequence.next() },
            codeSigningVerifier:
                SequencedLifecycleCodeSigningVerifier(verifications)
        )
    }
}

private func auditToken() -> LifecycleAuditToken {
    try! LifecycleAuditToken(
        words: [501, 20, 501, 501, 501, 701, 44_001, 3]
    )
}

private func currentTestExecutableURL() -> URL {
    var path = [CChar](repeating: 0, count: Int(PATH_MAX))
    var size = UInt32(path.count)
    precondition(_NSGetExecutablePath(&path, &size) == 0)
    let end = path.firstIndex(of: 0) ?? path.endIndex
    return URL(
        filePath: String(decoding: path[..<end].map(UInt8.init), as: UTF8.self)
    ).resolvingSymlinksInPath().standardizedFileURL
}

private func adHocSign(_ url: URL, identifier: String) throws {
    let signer = Process()
    signer.executableURL = URL(filePath: "/usr/bin/codesign")
    signer.arguments = [
        "--force", "--sign", "-", "--timestamp=none",
        "--identifier", identifier, url.path,
    ]
    signer.standardInput = FileHandle.nullDevice
    signer.standardOutput = FileHandle.nullDevice
    signer.standardError = FileHandle.nullDevice
    try signer.run()
    signer.waitUntilExit()
    guard signer.terminationStatus == 0 else {
        throw LifecycleSigningIdentityError.unavailable
    }
}

private func machineDriverIdentity(
    processIDVersion: Int32 = 7
) throws -> LifecycleProcessIdentity {
    LifecycleProcessIdentity(
        processID: 801,
        processIDVersion: processIDVersion,
        auditSessionID: 55_001,
        effectiveUserID: 0,
        auditToken: try LifecycleAuditToken(words: [
            0, 0, 0, 0, 0, 801, 55_001,
            UInt32(processIDVersion),
        ])
    )
}

private func digest(_ character: Character) -> String {
    String(repeating: String(character), count: 64)
}

private func cdhash(_ character: Character) -> String {
    String(repeating: String(character), count: 40)
}
