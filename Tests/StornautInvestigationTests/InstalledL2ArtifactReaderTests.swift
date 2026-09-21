import Darwin
import Foundation
import Testing
@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationInstalledL2

@Suite("Installed L2 fixed artifact reader", .serialized)
struct InstalledL2ArtifactReaderTests {
    @Test
    func nodeReaderRequiresStableDescriptorPathAndExactHash() throws {
        let fixture = try InstalledL2ArtifactFixture()
        defer { fixture.remove() }
        let file = try fixture.makeFile(name: "artifact", data: Data("payload".utf8))
        let expectation = try fixture.expectation(
            url: file,
            expectedSHA256: InvestigationHandoffSHA256.hashing(Data("payload".utf8))
        )

        #expect(
            InvestigationInstalledL2NodeReader().observe(expectation)
                == .presentValid
        )
        let wrongHash = try fixture.expectation(
            url: file, expectedSHA256: fixture.digest(0x91)
        )
        #expect(
            InvestigationInstalledL2NodeReader().observe(wrongHash) == .invalid
        )
    }

    @Test
    func onlyInitialMissingIsAbsentAndLaterVanishIsUnavailable() throws {
        let fixture = try InstalledL2ArtifactFixture()
        defer { fixture.remove() }
        let missing = fixture.root.appending(path: "missing")
        let expectation = try fixture.expectation(url: missing)
        #expect(
            InvestigationInstalledL2NodeReader().observe(expectation) == .absent
        )

        let metadata = fixture.metadataTemplate()
        let system = ScriptedInstalledL2FileSystem(
            pathResults: [.success(metadata)],
            openResult: .failure(.init(errno: ENOENT))
        )
        #expect(
            InvestigationInstalledL2NodeReader(system: system).observe(expectation)
                == .unavailable
        )
        #expect(system.closedDescriptors.isEmpty)
    }

    @Test
    func symlinkHardlinkModeOwnerAndTypeDriftAreInvalid() throws {
        let fixture = try InstalledL2ArtifactFixture()
        defer { fixture.remove() }
        let file = try fixture.makeFile(name: "artifact", data: Data("x".utf8))
        let link = fixture.root.appending(path: "link")
        let hard = fixture.root.appending(path: "hard")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        try FileManager.default.linkItem(at: file, to: hard)
        #expect(
            InvestigationInstalledL2NodeReader().observe(
                try fixture.expectation(url: link)
            ) == .invalid
        )
        #expect(
            InvestigationInstalledL2NodeReader().observe(
                try fixture.expectation(url: file)
            ) == .invalid
        )
        try FileManager.default.removeItem(at: hard)
        chmod(file.path, 0o644)
        #expect(
            InvestigationInstalledL2NodeReader().observe(
                try fixture.expectation(url: file)
            ) == .invalid
        )
        var wrongOwner = fixture.metadataTemplate()
        wrongOwner.ownerUserID = geteuid() + 1
        let scripted = ScriptedInstalledL2FileSystem(
            pathResults: [.success(wrongOwner)]
        )
        #expect(
            InvestigationInstalledL2NodeReader(system: scripted).observe(
                try fixture.expectation(url: file)
            ) == .invalid
        )
    }

    @Test(arguments: InstalledL2ArtifactRaceMutation.allCases)
    fileprivate func everyPathDescriptorAndPostReadRaceFailsClosed(
        _ mutation: InstalledL2ArtifactRaceMutation
    ) throws {
        let fixture = try InstalledL2ArtifactFixture()
        defer { fixture.remove() }
        let file = try fixture.makeFile(name: "artifact", data: Data("x".utf8))
        let first = try fixture.metadata(for: file)
        var changed = first
        switch mutation {
        case .pathToDescriptor: changed.inode &+= 1
        case .postReadDescriptor: changed.modificationNanoseconds &+= 1
        case .finalPath: changed.changeNanoseconds &+= 1
        }
        let descriptorResults: [
            Result<InvestigationInstalledL2NodeMetadata, InvestigationInstalledL2SystemCallError>
        ] = mutation == .pathToDescriptor
            ? [.success(changed)]
            : [.success(first), .success(mutation == .postReadDescriptor ? changed : first)]
        let pathResults: [
            Result<InvestigationInstalledL2NodeMetadata, InvestigationInstalledL2SystemCallError>
        ] = [.success(first), .success(mutation == .finalPath ? changed : first)]
        let system = ScriptedInstalledL2FileSystem(
            pathResults: pathResults,
            openResult: .success(91),
            descriptorResults: descriptorResults,
            readResult: .success(Data("x".utf8))
        )
        #expect(
            InvestigationInstalledL2NodeReader(system: system).observe(
                try fixture.expectation(
                    url: file,
                    expectedSHA256: InvestigationHandoffSHA256.hashing(Data("x".utf8))
                )
            ) == .invalid
        )
        expectInstalledL2DescriptorClosed(system)
    }

    @Test(arguments: InstalledL2ArtifactFailure.allCases)
    fileprivate func syscallVanishAndSizeFailuresNeverBecomeValid(
        _ failure: InstalledL2ArtifactFailure
    ) throws {
        let fixture = try InstalledL2ArtifactFixture()
        defer { fixture.remove() }
        let file = try fixture.makeFile(name: "artifact", data: Data("x".utf8))
        let metadata = try fixture.metadata(for: file)
        let error = InvestigationInstalledL2SystemCallError(errno: EIO)

        let system: ScriptedInstalledL2FileSystem
        let expected: InvestigationInstalledL2ArtifactObservation
        switch failure {
        case .initialDescriptorFailure:
            system = .init(
                pathResults: [.success(metadata)],
                openResult: .success(91),
                descriptorResults: [.failure(error)]
            )
            expected = .unavailable
        case .postReadDescriptorFailure:
            system = .init(
                pathResults: [.success(metadata)],
                openResult: .success(91),
                descriptorResults: [.success(metadata), .failure(error)],
                readResult: .success(Data("x".utf8))
            )
            expected = .unavailable
        case .readFailure:
            system = .init(
                pathResults: [.success(metadata)],
                openResult: .success(91),
                descriptorResults: [.success(metadata)],
                readResult: .failure(error)
            )
            expected = .unavailable
        case .finalPathMissing:
            system = .init(
                pathResults: [
                    .success(metadata),
                    .failure(.init(errno: ENOENT)),
                ],
                openResult: .success(91),
                descriptorResults: [.success(metadata), .success(metadata)],
                readResult: .success(Data("x".utf8))
            )
            expected = .unavailable
        case .readLengthMismatch:
            system = .init(
                pathResults: [.success(metadata)],
                openResult: .success(91),
                descriptorResults: [.success(metadata)],
                readResult: .success(Data(repeating: 0x78, count: 1_025))
            )
            expected = .invalid
        }

        #expect(
            InvestigationInstalledL2NodeReader(system: system).observe(
                try fixture.expectation(
                    url: file,
                    expectedSHA256:
                        InvestigationHandoffSHA256.hashing(Data("x".utf8))
                )
            ) == expected
        )
        expectInstalledL2DescriptorClosed(system)
    }

    @Test
    func manifestReaderRequiresExactClosedFixedManifest() throws {
        let fixture = try InstalledL2ArtifactFixture()
        defer { fixture.remove() }
        let valid = try fixture.manifestData()
        let plist = try fixture.makeFile(name: "lifecycle.plist", data: valid)
        let reader = InvestigationInstalledL2ManifestReader()
        #expect(
            reader.observe(
                try fixture.expectation(url: plist, mode: 0o600),
                expectedManifest: fixture.manifest
            ) == .presentValid
        )
        var unknown = fixture.manifest
        unknown["StandardOutPath"] = "/tmp/forbidden"
        let unknownData = try PropertyListSerialization.data(
            fromPropertyList: unknown, format: .xml, options: 0
        )
        try unknownData.write(to: plist, options: .atomic)
        chmod(plist.path, 0o600)
        #expect(
            reader.observe(
                try fixture.expectation(url: plist, mode: 0o600),
                expectedManifest: fixture.manifest
            ) == .invalid
        )

        var missing = fixture.manifest
        missing.removeValue(forKey: "SessionCreate")
        try fixture.writeManifest(missing, to: plist)
        #expect(
            reader.observe(
                try fixture.expectation(url: plist, mode: 0o600),
                expectedManifest: fixture.manifest
            ) == .invalid
        )

        var wrongType = fixture.manifest
        wrongType["ThrottleInterval"] = true
        try fixture.writeManifest(wrongType, to: plist)
        #expect(
            reader.observe(
                try fixture.expectation(url: plist, mode: 0o600),
                expectedManifest: fixture.manifest
            ) == .invalid
        )

        try Data("not-a-plist".utf8).write(to: plist, options: .atomic)
        chmod(plist.path, 0o600)
        #expect(
            reader.observe(
                try fixture.expectation(url: plist, mode: 0o600),
                expectedManifest: fixture.manifest
            ) == .invalid
        )
    }

    @Test
    func staticSigningReaderObservesSignedCodeAndRejectsUnsignedFile() throws {
        let reader = InvestigationInstalledL2StaticSigningReader()
        switch reader.read(at: URL(fileURLWithPath: "/bin/ls")) {
        case .observed(let identity):
            #expect(identity.signingIdentifier == "com.apple.ls")
            #expect(identity.designatedRequirementSHA256.rawBytes.count == 32)
            #expect([20, 32].contains(identity.codeDirectoryHash.count))
            #expect(!identity.isAdHoc)
        case .invalid, .unavailable:
            Issue.record("expected /bin/ls to provide strict static signing evidence")
        }

        let fixture = try InstalledL2ArtifactFixture()
        defer { fixture.remove() }
        let unsigned = try fixture.makeFile(
            name: "unsigned", data: Data("not-mach-o".utf8)
        )
        switch reader.read(at: unsigned) {
        case .observed:
            Issue.record("unsigned fixture unexpectedly produced signing evidence")
        case .invalid, .unavailable:
            break
        }
    }

    @Test
    func artifactReaderMapsAllFixedRolesAndRechecksAfterSigning() throws {
        let fixture = try InstalledL2ArtifactFixture()
        defer { fixture.remove() }
        let nodes = RecordingInstalledL2NodeObserver(
            results: Array(repeating: .presentValid, count: 10)
        )
        let signing = RecordingInstalledL2StaticSigningReader(
            results: [
                fixture.paths.installedApp: .observed(fixture.appSigning),
                fixture.paths.helperExecutable: .observed(fixture.helperSigning),
                fixture.paths.machineDriverExecutable: .observed(fixture.driverSigning),
            ]
        )
        let manifest = RecordingInstalledL2ManifestReader(result: .presentValid)
        let reader = InvestigationInstalledL2ArtifactReader(
            nodeObserver: nodes, signingReader: signing, manifestReader: manifest
        )
        let facts = try reader.observe(projection: fixture.projection)

        #expect(facts.artifacts.count == 8)
        #expect(facts.artifacts.values.allSatisfy { $0 == .presentValid })
        #expect(facts.appStaticSigning == fixture.appSigning)
        #expect(facts.helperStaticSigning == fixture.helperSigning)
        #expect(facts.machineDriverStaticSigning == fixture.driverSigning)
        let expectedNodeExpectations = try fixture.expectedNodeExpectations()
        #expect(nodes.expectations == expectedNodeExpectations)
        #expect(signing.urls == [
            fixture.paths.installedApp, fixture.paths.helperExecutable,
            fixture.paths.machineDriverExecutable,
        ])
        #expect(manifest.expectations.count == 1)
        let expectedManifestExpectation =
            try fixture.expectedManifestExpectation()
        #expect(manifest.expectations.first == expectedManifestExpectation)
        let expectedManifest = try #require(manifest.expectedManifests.first)
        #expect(fixture.isExactManifest(expectedManifest))
    }

    @Test(arguments: InstalledL2SignedArtifactRole.allCases)
    fileprivate func everySignedNodeDriftAfterSigningFailsClosed(
        _ role: InstalledL2SignedArtifactRole
    ) throws {
        let fixture = try InstalledL2ArtifactFixture()
        defer { fixture.remove() }
        var results = Array(
            repeating: InvestigationInstalledL2ArtifactObservation.presentValid,
            count: 10
        )
        results[role.secondObservationIndex] = .invalid
        let nodes = RecordingInstalledL2NodeObserver(results: results)
        let reader = InvestigationInstalledL2ArtifactReader(
            nodeObserver: nodes,
            signingReader: RecordingInstalledL2StaticSigningReader(results: [
                fixture.paths.installedApp: .observed(fixture.appSigning),
                fixture.paths.helperExecutable: .observed(fixture.helperSigning),
                fixture.paths.machineDriverExecutable: .observed(fixture.driverSigning),
            ]),
            manifestReader: RecordingInstalledL2ManifestReader(result: .presentValid)
        )

        #expect(throws: (any Error).self) {
            _ = try reader.observe(projection: fixture.projection)
        }
        let sameNodeObservations = nodes.expectations.filter {
            $0.url == role.url(in: fixture.paths)
        }
        #expect(sameNodeObservations.count == 2)
        #expect(sameNodeObservations.first == sameNodeObservations.last)
    }

    @Test
    func signingAndManifestDriftNeverProduceFacts() throws {
        let fixture = try InstalledL2ArtifactFixture()
        defer { fixture.remove() }
        let foreign = try fixture.signing(identifier: "foreign.app", byte: 0x88)
        let reader = InvestigationInstalledL2ArtifactReader(
            nodeObserver: RecordingInstalledL2NodeObserver(
                results: Array(repeating: .presentValid, count: 10)
            ),
            signingReader: RecordingInstalledL2StaticSigningReader(results: [
                fixture.paths.installedApp: .observed(foreign),
                fixture.paths.helperExecutable: .observed(fixture.helperSigning),
                fixture.paths.machineDriverExecutable: .observed(fixture.driverSigning),
            ]),
            manifestReader: RecordingInstalledL2ManifestReader(result: .presentValid)
        )
        #expect(throws: (any Error).self) {
            _ = try reader.observe(projection: fixture.projection)
        }

        let manifestFailure = InvestigationInstalledL2ArtifactReader(
            nodeObserver: RecordingInstalledL2NodeObserver(
                results: Array(repeating: .presentValid, count: 10)
            ),
            signingReader: RecordingInstalledL2StaticSigningReader(results: [
                fixture.paths.installedApp: .observed(fixture.appSigning),
                fixture.paths.helperExecutable: .observed(fixture.helperSigning),
                fixture.paths.machineDriverExecutable: .observed(fixture.driverSigning),
            ]),
            manifestReader: RecordingInstalledL2ManifestReader(result: .invalid)
        )
        #expect(throws: (any Error).self) {
            _ = try manifestFailure.observe(projection: fixture.projection)
        }
    }

    @Test
    func absentSignedArtifactDoesNotInvokeSigningReader() throws {
        let fixture = try InstalledL2ArtifactFixture()
        defer { fixture.remove() }
        let signing = RecordingInstalledL2StaticSigningReader(results: [:])
        let nodes = RecordingInstalledL2NodeObserver(
            results: [.presentValid, .absent]
        )
        let reader = InvestigationInstalledL2ArtifactReader(
            nodeObserver: nodes,
            signingReader: signing,
            manifestReader: RecordingInstalledL2ManifestReader(result: .presentValid)
        )
        #expect(throws: (any Error).self) {
            _ = try reader.observe(projection: fixture.projection)
        }
        #expect(signing.urls.isEmpty)
        #expect(nodes.expectations.map(\.url) == [
            fixture.paths.installedRoot,
            fixture.paths.installedApp,
        ])
    }
}

private enum InstalledL2ArtifactRaceMutation: CaseIterable {
    case pathToDescriptor, postReadDescriptor, finalPath
}

private enum InstalledL2ArtifactFailure: CaseIterable {
    case initialDescriptorFailure
    case postReadDescriptorFailure
    case readFailure
    case finalPathMissing
    case readLengthMismatch
}

private enum InstalledL2SignedArtifactRole: CaseIterable {
    case installedApp, helper, machineDriver

    var secondObservationIndex: Int {
        switch self {
        case .installedApp: 2
        case .helper: 5
        case .machineDriver: 7
        }
    }

    func url(in paths: InvestigationInstalledL2FixedPaths) -> URL {
        switch self {
        case .installedApp: paths.installedApp
        case .helper: paths.helperExecutable
        case .machineDriver: paths.machineDriverExecutable
        }
    }
}

private struct InstalledL2ArtifactFixture {
    let paths = InvestigationInstalledL2FixedPaths()
    let appSigning: InvestigationInstalledL2SigningIdentity
    let helperSigning: InvestigationInstalledL2SigningIdentity
    let driverSigning: InvestigationInstalledL2SigningIdentity
    let projection: InvestigationInstalledL2IdentityProjection
    let root: URL

    init() throws {
        appSigning = try Self.signing(
            identifier: "com.eriklee.stornaut", byte: 0x41, adHoc: false
        )
        helperSigning = try Self.signing(
            identifier: "com.eriklee.stornaut.lifecycle.helper", byte: 0x42, adHoc: false
        )
        driverSigning = try Self.signing(
            identifier: "com.eriklee.stornaut.investigation.machine-driver",
            byte: 0x43, adHoc: true
        )
        projection = try .init(
            epochUUID: Self.uuid(0x11), configurationNonce: Self.uuid(0x12),
            configurationValidBefore: .init(rawValue: 1_000),
            configurationSHA256: Self.digest(0x21),
            signedRuntimeBindingSHA256: Self.digest(0x22),
            appExecutableSHA256: Self.digest(0x31),
            appBundleIdentifier: "com.eriklee.stornaut",
            helperExecutableSHA256: Self.digest(0x32),
            helperServiceIdentifier: "com.eriklee.stornaut.lifecycle",
            machineDriverExecutableSHA256: Self.digest(0x33),
            machineDriverSigningIdentifier: driverSigning.signingIdentifier,
            machineDriverDesignatedRequirementSHA256:
                driverSigning.designatedRequirementSHA256,
            machineDriverCodeDirectoryHash: driverSigning.codeDirectoryHash,
            machineClaimServiceIdentifier:
                "com.eriklee.stornaut.lifecycle.machine-claim"
        )
        root = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-iib2a-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
    }

    var manifest: [String: Any] {
        [
            "AbandonProcessGroup": false,
            "AssociatedBundleIdentifiers": ["com.eriklee.stornaut"],
            "KeepAlive": ["SuccessfulExit": false],
            "Label": "com.eriklee.stornaut.lifecycle",
            "MachServices": [
                "com.eriklee.stornaut.lifecycle": true,
                "com.eriklee.stornaut.lifecycle.machine-claim": true,
            ],
            "ProcessType": "Interactive",
            "Program": "/Library/Application Support/Stornaut/"
                + "Stornaut-R5-Diagnostic.app/Contents/MacOS/"
                + "StornautLifecycleHelper",
            "RunAtLoad": false,
            "SessionCreate": true,
            "ThrottleInterval": 1,
        ]
    }

    func manifestData() throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: manifest, format: .xml, options: 0
        )
    }

    func writeManifest(_ manifest: [String: Any], to url: URL) throws {
        let data = try PropertyListSerialization.data(
            fromPropertyList: manifest, format: .xml, options: 0
        )
        try data.write(to: url, options: .atomic)
        chmod(url.path, 0o600)
    }

    func isExactManifest(_ value: [String: Any]) -> Bool {
        Set(value.keys) == Set(manifest.keys)
            && value["AbandonProcessGroup"] as? Bool == false
            && value["AssociatedBundleIdentifiers"] as? [String]
                == ["com.eriklee.stornaut"]
            && value["KeepAlive"] as? [String: Bool]
                == ["SuccessfulExit": false]
            && value["Label"] as? String
                == "com.eriklee.stornaut.lifecycle"
            && value["MachServices"] as? [String: Bool] == [
                "com.eriklee.stornaut.lifecycle": true,
                "com.eriklee.stornaut.lifecycle.machine-claim": true,
            ]
            && value["ProcessType"] as? String == "Interactive"
            && value["Program"] as? String
                == "/Library/Application Support/Stornaut/"
                    + "Stornaut-R5-Diagnostic.app/Contents/MacOS/"
                    + "StornautLifecycleHelper"
            && value["RunAtLoad"] as? Bool == false
            && value["SessionCreate"] as? Bool == true
            && value["ThrottleInterval"] as? Int == 1
    }

    func makeFile(name: String, data: Data) throws -> URL {
        let url = root.appending(path: name)
        try data.write(to: url, options: .withoutOverwriting)
        chmod(url.path, 0o600)
        return url
    }

    func expectation(
        url: URL,
        mode: mode_t = 0o600,
        expectedSHA256: InvestigationHandoffSHA256? = nil
    ) throws -> InvestigationInstalledL2NodeExpectation {
        try .init(
            url: url, kind: .regularFile, ownerUserID: geteuid(),
            ownerGroupID: getegid(), mode: mode, requiresSingleLink: true,
            expectedSHA256: expectedSHA256, maximumSize: 1_024
        )
    }

    func expectedNodeExpectations() throws
        -> [InvestigationInstalledL2NodeExpectation]
    {
        let root = URL(fileURLWithPath: "/Library/Application Support/Stornaut")
        let app = root.appendingPathComponent("Stornaut-R5-Diagnostic.app")
        let macOS = app.appendingPathComponent("Contents/MacOS")
        let appExecutable = macOS.appendingPathComponent(
            "StornautInvestigationDiagnostic"
        )
        let helperExecutable = macOS.appendingPathComponent(
            "StornautLifecycleHelper"
        )
        let driverExecutable = macOS.appendingPathComponent(
            "StornautInvestigationMachineDriver"
        )
        let runtime = root.appendingPathComponent("R5Runtime")
        let lease = URL(fileURLWithPath: "/private/var/db/com.eriklee.stornaut.r5")

        #expect(paths.installedRoot.path == root.path)
        #expect(paths.installedApp.path == app.path)
        #expect(paths.appExecutable.path == appExecutable.path)
        #expect(paths.helperExecutable.path == helperExecutable.path)
        #expect(paths.machineDriverExecutable.path == driverExecutable.path)
        #expect(
            paths.launchDaemonPlist.path
                == "/Library/LaunchDaemons/com.eriklee.stornaut.lifecycle.plist"
        )
        #expect(paths.runtimeRoot.path == runtime.path)
        #expect(paths.leaseRoot.path == lease.path)

        let installedRoot = try fixedExpectation(
            url: root, kind: .directory, mode: 0o755
        )
        let installedApp = try fixedExpectation(
            url: app, kind: .directory, mode: 0o755
        )
        let appNode = try fixedExpectation(
            url: appExecutable, kind: .regularFile, mode: 0o755,
            expectedSHA256: projection.appExecutableSHA256,
            maximumSize: 256 * 1_024 * 1_024
        )
        let helperNode = try fixedExpectation(
            url: helperExecutable, kind: .regularFile, mode: 0o755,
            expectedSHA256: projection.helperExecutableSHA256,
            maximumSize: 256 * 1_024 * 1_024
        )
        let driverNode = try fixedExpectation(
            url: driverExecutable, kind: .regularFile, mode: 0o755,
            expectedSHA256: projection.machineDriverExecutableSHA256,
            maximumSize: 16 * 1_024 * 1_024
        )
        return [
            installedRoot,
            installedApp, installedApp,
            appNode,
            helperNode, helperNode,
            driverNode, driverNode,
            try fixedExpectation(url: runtime, kind: .directory, mode: 0o711),
            try fixedExpectation(url: lease, kind: .directory, mode: 0o700),
        ]
    }

    func expectedManifestExpectation() throws
        -> InvestigationInstalledL2NodeExpectation
    {
        try fixedExpectation(
            url: URL(
                fileURLWithPath:
                    "/Library/LaunchDaemons/com.eriklee.stornaut.lifecycle.plist"
            ),
            kind: .regularFile,
            mode: 0o644,
            maximumSize: 64 * 1_024
        )
    }

    private func fixedExpectation(
        url: URL,
        kind: InvestigationInstalledL2NodeKind,
        mode: mode_t,
        expectedSHA256: InvestigationHandoffSHA256? = nil,
        maximumSize: Int = 0
    ) throws -> InvestigationInstalledL2NodeExpectation {
        try .init(
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

    func metadata(for url: URL) throws -> InvestigationInstalledL2NodeMetadata {
        var value = stat()
        guard lstat(url.path, &value) == 0 else { throw CocoaError(.fileReadUnknown) }
        return .init(value)
    }

    func metadataTemplate() -> InvestigationInstalledL2NodeMetadata {
        .init(
            deviceID: 1, inode: 2, generation: 3, mode: mode_t(S_IFREG) | 0o600,
            linkCount: 1, ownerUserID: geteuid(), ownerGroupID: getegid(),
            size: 1, modificationSeconds: 4, modificationNanoseconds: 5,
            changeSeconds: 6, changeNanoseconds: 7
        )
    }

    func digest(_ byte: UInt8) throws -> InvestigationHandoffSHA256 {
        try Self.digest(byte)
    }

    func signing(
        identifier: String, byte: UInt8
    ) throws -> InvestigationInstalledL2SigningIdentity {
        try Self.signing(identifier: identifier, byte: byte, adHoc: false)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    private static func signing(
        identifier: String, byte: UInt8, adHoc: Bool
    ) throws -> InvestigationInstalledL2SigningIdentity {
        try .init(
            signingIdentifier: identifier,
            designatedRequirementSHA256: digest(byte),
            codeDirectoryHash: Data(repeating: byte, count: 20), isAdHoc: adHoc
        )
    }

    private static func digest(_ byte: UInt8) throws -> InvestigationHandoffSHA256 {
        try .init(rawBytes: Data(repeating: byte, count: 32))
    }

    private static func uuid(_ byte: UInt8) throws -> UUID {
        guard let value = UUID(uuidString: String(
            format: "00000000-0000-4000-8000-0000000000%02x", byte
        )) else { throw InstalledL2ArtifactFixtureError.invalidUUID }
        return value
    }
}

private enum InstalledL2ArtifactFixtureError: Error { case invalidUUID }

private func expectInstalledL2DescriptorClosed(
    _ system: ScriptedInstalledL2FileSystem
) {
    #expect(system.closedDescriptors == [91])
}

private final class ScriptedInstalledL2FileSystem:
    InvestigationInstalledL2FileSystem,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var pathResults: [
        Result<InvestigationInstalledL2NodeMetadata, InvestigationInstalledL2SystemCallError>
    ]
    private let openResult: Result<Int32, InvestigationInstalledL2SystemCallError>
    private var descriptorResults: [
        Result<InvestigationInstalledL2NodeMetadata, InvestigationInstalledL2SystemCallError>
    ]
    private let readResult: Result<Data, InvestigationInstalledL2SystemCallError>
    private var closed: [Int32] = []

    var closedDescriptors: [Int32] {
        lock.withLock { closed }
    }

    init(
        pathResults: [Result<InvestigationInstalledL2NodeMetadata, InvestigationInstalledL2SystemCallError>],
        openResult: Result<Int32, InvestigationInstalledL2SystemCallError> =
            .failure(.init(errno: EACCES)),
        descriptorResults: [Result<InvestigationInstalledL2NodeMetadata, InvestigationInstalledL2SystemCallError>] = [],
        readResult: Result<Data, InvestigationInstalledL2SystemCallError> =
            .failure(.init(errno: EIO))
    ) {
        self.pathResults = pathResults
        self.openResult = openResult
        self.descriptorResults = descriptorResults
        self.readResult = readResult
    }

    func metadata(at _: URL) -> Result<InvestigationInstalledL2NodeMetadata, InvestigationInstalledL2SystemCallError> {
        lock.withLock { pathResults.removeFirst() }
    }
    func openReadOnly(_: URL, kind _: InvestigationInstalledL2NodeKind)
        -> Result<Int32, InvestigationInstalledL2SystemCallError> { openResult }
    func metadata(for _: Int32) -> Result<InvestigationInstalledL2NodeMetadata, InvestigationInstalledL2SystemCallError> {
        lock.withLock { descriptorResults.removeFirst() }
    }
    func read(from _: Int32, maximumBytes _: Int)
        -> Result<Data, InvestigationInstalledL2SystemCallError> { readResult }
    func close(_ descriptor: Int32) {
        lock.withLock { closed.append(descriptor) }
    }
}

private final class RecordingInstalledL2NodeObserver:
    InvestigationInstalledL2NodeObserving,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var results: [InvestigationInstalledL2ArtifactObservation]
    private(set) var expectations: [InvestigationInstalledL2NodeExpectation] = []
    init(results: [InvestigationInstalledL2ArtifactObservation]) { self.results = results }
    func observe(_ expectation: InvestigationInstalledL2NodeExpectation)
        -> InvestigationInstalledL2ArtifactObservation {
        lock.withLock { expectations.append(expectation); return results.removeFirst() }
    }
}

private final class RecordingInstalledL2StaticSigningReader:
    InvestigationInstalledL2StaticSigningReading,
    @unchecked Sendable
{
    let results: [URL: InvestigationInstalledL2StaticSigningResult]
    private let lock = NSLock()
    private(set) var urls: [URL] = []
    init(results: [URL: InvestigationInstalledL2StaticSigningResult]) { self.results = results }
    func read(at url: URL) -> InvestigationInstalledL2StaticSigningResult {
        lock.withLock { urls.append(url) }
        return results[url] ?? .unavailable
    }
}

private final class RecordingInstalledL2ManifestReader:
    InvestigationInstalledL2ManifestReading,
    @unchecked Sendable
{
    let result: InvestigationInstalledL2ArtifactObservation
    private let lock = NSLock()
    private(set) var expectations: [InvestigationInstalledL2NodeExpectation] = []
    private(set) var expectedManifests: [[String: Any]] = []
    init(result: InvestigationInstalledL2ArtifactObservation) { self.result = result }
    func observe(
        _ expectation: InvestigationInstalledL2NodeExpectation,
        expectedManifest: [String: Any]
    ) -> InvestigationInstalledL2ArtifactObservation {
        lock.withLock {
            expectations.append(expectation)
            expectedManifests.append(expectedManifest)
        }
        return result
    }
}
