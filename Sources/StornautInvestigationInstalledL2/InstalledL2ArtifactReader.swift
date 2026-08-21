import Darwin
import Foundation
import Security
import StornautInvestigationHandoffContract

private let investigationInstalledL2AdHocSignatureFlag: UInt32 = 0x0002

package struct InvestigationInstalledL2SystemCallError:
    Error,
    Sendable,
    Equatable
{
    package let errno: Int32

    package init(errno: Int32) {
        self.errno = errno
    }
}

package enum InvestigationInstalledL2NodeKind: Sendable, Equatable {
    case regularFile
    case directory
}

package struct InvestigationInstalledL2NodeMetadata: Sendable, Equatable {
    package var deviceID: dev_t
    package var inode: ino_t
    package var generation: UInt32
    package var mode: mode_t
    package var linkCount: nlink_t
    package var ownerUserID: uid_t
    package var ownerGroupID: gid_t
    package var size: off_t
    package var modificationSeconds: Int
    package var modificationNanoseconds: Int
    package var changeSeconds: Int
    package var changeNanoseconds: Int

    package init(
        deviceID: dev_t,
        inode: ino_t,
        generation: UInt32,
        mode: mode_t,
        linkCount: nlink_t,
        ownerUserID: uid_t,
        ownerGroupID: gid_t,
        size: off_t,
        modificationSeconds: Int,
        modificationNanoseconds: Int,
        changeSeconds: Int,
        changeNanoseconds: Int
    ) {
        self.deviceID = deviceID
        self.inode = inode
        self.generation = generation
        self.mode = mode
        self.linkCount = linkCount
        self.ownerUserID = ownerUserID
        self.ownerGroupID = ownerGroupID
        self.size = size
        self.modificationSeconds = modificationSeconds
        self.modificationNanoseconds = modificationNanoseconds
        self.changeSeconds = changeSeconds
        self.changeNanoseconds = changeNanoseconds
    }

    package init(_ value: stat) {
        self.init(
            deviceID: value.st_dev,
            inode: value.st_ino,
            generation: value.st_gen,
            mode: value.st_mode,
            linkCount: value.st_nlink,
            ownerUserID: value.st_uid,
            ownerGroupID: value.st_gid,
            size: value.st_size,
            modificationSeconds: value.st_mtimespec.tv_sec,
            modificationNanoseconds: value.st_mtimespec.tv_nsec,
            changeSeconds: value.st_ctimespec.tv_sec,
            changeNanoseconds: value.st_ctimespec.tv_nsec
        )
    }
}

package struct InvestigationInstalledL2NodeExpectation: Sendable, Equatable {
    package let url: URL
    package let kind: InvestigationInstalledL2NodeKind
    package let ownerUserID: uid_t
    package let ownerGroupID: gid_t
    package let mode: mode_t
    package let requiresSingleLink: Bool
    package let expectedSHA256: InvestigationHandoffSHA256?
    package let maximumSize: Int

    package init(
        url: URL,
        kind: InvestigationInstalledL2NodeKind,
        ownerUserID: uid_t,
        ownerGroupID: gid_t,
        mode: mode_t,
        requiresSingleLink: Bool,
        expectedSHA256: InvestigationHandoffSHA256?,
        maximumSize: Int
    ) throws {
        guard
            investigationInstalledL2AbsoluteFileURL(url),
            mode & ~mode_t(0o7777) == 0,
            maximumSize >= 0,
            kind == .regularFile || expectedSHA256 == nil
        else {
            throw InvestigationInstalledL2SemanticError.invalidValue
        }
        self.url = url
        self.kind = kind
        self.ownerUserID = ownerUserID
        self.ownerGroupID = ownerGroupID
        self.mode = mode
        self.requiresSingleLink = requiresSingleLink
        self.expectedSHA256 = expectedSHA256
        self.maximumSize = maximumSize
    }
}

package protocol InvestigationInstalledL2FileSystem: Sendable {
    func metadata(
        at url: URL
    ) -> Result<
        InvestigationInstalledL2NodeMetadata,
        InvestigationInstalledL2SystemCallError
    >

    func openReadOnly(
        _ url: URL,
        kind: InvestigationInstalledL2NodeKind
    ) -> Result<Int32, InvestigationInstalledL2SystemCallError>

    func metadata(
        for descriptor: Int32
    ) -> Result<
        InvestigationInstalledL2NodeMetadata,
        InvestigationInstalledL2SystemCallError
    >

    func read(
        from descriptor: Int32,
        maximumBytes: Int
    ) -> Result<Data, InvestigationInstalledL2SystemCallError>

    func close(_ descriptor: Int32)
}

package struct InvestigationInstalledL2DarwinFileSystem:
    InvestigationInstalledL2FileSystem,
    Sendable
{
    package init() {}

    package func metadata(
        at url: URL
    ) -> Result<
        InvestigationInstalledL2NodeMetadata,
        InvestigationInstalledL2SystemCallError
    > {
        guard investigationInstalledL2AbsoluteFileURL(url) else {
            return .failure(.init(errno: EINVAL))
        }
        var value = stat()
        guard lstat(url.path, &value) == 0 else {
            return .failure(.init(errno: Darwin.errno))
        }
        return .success(.init(value))
    }

    package func openReadOnly(
        _ url: URL,
        kind: InvestigationInstalledL2NodeKind
    ) -> Result<Int32, InvestigationInstalledL2SystemCallError> {
        guard investigationInstalledL2AbsoluteFileURL(url) else {
            return .failure(.init(errno: EINVAL))
        }
        var flags = O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK
        if kind == .directory {
            flags |= O_DIRECTORY
        }
        let descriptor = Darwin.open(url.path, flags)
        guard descriptor >= 0 else {
            return .failure(.init(errno: Darwin.errno))
        }
        return .success(descriptor)
    }

    package func metadata(
        for descriptor: Int32
    ) -> Result<
        InvestigationInstalledL2NodeMetadata,
        InvestigationInstalledL2SystemCallError
    > {
        guard descriptor >= 0 else {
            return .failure(.init(errno: EBADF))
        }
        var value = stat()
        guard fstat(descriptor, &value) == 0 else {
            return .failure(.init(errno: Darwin.errno))
        }
        return .success(.init(value))
    }

    package func read(
        from descriptor: Int32,
        maximumBytes: Int
    ) -> Result<Data, InvestigationInstalledL2SystemCallError> {
        guard descriptor >= 0, maximumBytes >= 0 else {
            return .failure(.init(errno: EINVAL))
        }
        var result = Data()
        let chunkCapacity = 64 * 1_024
        var buffer = [UInt8](
            repeating: 0,
            count: min(chunkCapacity, max(1, maximumBytes))
        )
        while result.count < maximumBytes {
            let requested = min(buffer.count, maximumBytes - result.count)
            let count = buffer.withUnsafeMutableBytes { bytes in
                Darwin.read(descriptor, bytes.baseAddress, requested)
            }
            if count > 0 {
                result.append(buffer, count: count)
                continue
            }
            if count == 0 {
                return .success(result)
            }
            let code = Darwin.errno
            if code == EINTR {
                continue
            }
            return .failure(.init(errno: code))
        }
        return .success(result)
    }

    package func close(_ descriptor: Int32) {
        guard descriptor >= 0 else { return }
        _ = Darwin.close(descriptor)
    }
}

package protocol InvestigationInstalledL2NodeObserving: Sendable {
    func observe(
        _ expectation: InvestigationInstalledL2NodeExpectation
    ) -> InvestigationInstalledL2ArtifactObservation
}

private enum InvestigationInstalledL2NodeInspection {
    case absent
    case presentValid(data: Data?)
    case invalid
    case unavailable

    var observation: InvestigationInstalledL2ArtifactObservation {
        switch self {
        case .absent: .absent
        case .presentValid: .presentValid
        case .invalid: .invalid
        case .unavailable: .unavailable
        }
    }
}

package struct InvestigationInstalledL2NodeReader:
    InvestigationInstalledL2NodeObserving,
    Sendable
{
    private let system: any InvestigationInstalledL2FileSystem

    package init(
        system: any InvestigationInstalledL2FileSystem
            = InvestigationInstalledL2DarwinFileSystem()
    ) {
        self.system = system
    }

    package func observe(
        _ expectation: InvestigationInstalledL2NodeExpectation
    ) -> InvestigationInstalledL2ArtifactObservation {
        inspect(
            expectation,
            readContents: expectation.expectedSHA256 != nil
        ).observation
    }

    fileprivate func inspect(
        _ expectation: InvestigationInstalledL2NodeExpectation,
        readContents: Bool
    ) -> InvestigationInstalledL2NodeInspection {
        let pathMetadata: InvestigationInstalledL2NodeMetadata
        switch system.metadata(at: expectation.url) {
        case .success(let metadata):
            pathMetadata = metadata
        case .failure(let error) where error.errno == ENOENT:
            return .absent
        case .failure:
            return .unavailable
        }
        guard validate(pathMetadata, against: expectation) else {
            return .invalid
        }

        let descriptor: Int32
        switch system.openReadOnly(expectation.url, kind: expectation.kind) {
        case .success(let value) where value >= 0:
            descriptor = value
        case .success, .failure:
            return .unavailable
        }
        defer { system.close(descriptor) }

        let initialDescriptorMetadata: InvestigationInstalledL2NodeMetadata
        switch system.metadata(for: descriptor) {
        case .success(let metadata):
            initialDescriptorMetadata = metadata
        case .failure:
            return .unavailable
        }
        guard
            pathMetadata == initialDescriptorMetadata,
            validate(initialDescriptorMetadata, against: expectation)
        else {
            return .invalid
        }

        var data: Data?
        if expectation.kind == .regularFile,
           readContents || expectation.expectedSHA256 != nil
        {
            let readLimit = expectation.maximumSize == Int.max
                ? Int.max
                : expectation.maximumSize + 1
            let value: Data
            switch system.read(from: descriptor, maximumBytes: readLimit) {
            case .success(let bytes):
                value = bytes
            case .failure:
                return .unavailable
            }
            guard
                value.count == Int(initialDescriptorMetadata.size),
                value.count <= expectation.maximumSize
            else {
                return .invalid
            }
            if let expectedSHA256 = expectation.expectedSHA256,
               InvestigationHandoffSHA256.hashing(value) != expectedSHA256
            {
                return .invalid
            }
            if readContents {
                data = value
            }
        }

        let finalDescriptorMetadata: InvestigationInstalledL2NodeMetadata
        switch system.metadata(for: descriptor) {
        case .success(let metadata):
            finalDescriptorMetadata = metadata
        case .failure:
            return .unavailable
        }
        guard initialDescriptorMetadata == finalDescriptorMetadata else {
            return .invalid
        }

        switch system.metadata(at: expectation.url) {
        case .success(let finalPathMetadata):
            guard finalPathMetadata == finalDescriptorMetadata else {
                return .invalid
            }
        case .failure:
            return .unavailable
        }
        return .presentValid(data: data)
    }

    private func validate(
        _ metadata: InvestigationInstalledL2NodeMetadata,
        against expectation: InvestigationInstalledL2NodeExpectation
    ) -> Bool {
        let expectedType = expectation.kind == .regularFile
            ? mode_t(S_IFREG)
            : mode_t(S_IFDIR)
        guard
            metadata.mode & mode_t(S_IFMT) == expectedType,
            metadata.ownerUserID == expectation.ownerUserID,
            metadata.ownerGroupID == expectation.ownerGroupID,
            metadata.mode & mode_t(0o7777) == expectation.mode,
            !expectation.requiresSingleLink || metadata.linkCount == 1
        else {
            return false
        }
        if expectation.kind == .regularFile {
            guard
                metadata.size >= 0,
                UInt64(metadata.size) <= UInt64(expectation.maximumSize)
            else {
                return false
            }
        }
        return true
    }
}

package enum InvestigationInstalledL2StaticSigningResult: Sendable, Equatable {
    case observed(InvestigationInstalledL2SigningIdentity)
    case invalid
    case unavailable
}

package protocol InvestigationInstalledL2StaticSigningReading: Sendable {
    func read(at url: URL) -> InvestigationInstalledL2StaticSigningResult
}

package struct InvestigationInstalledL2StaticSigningReader:
    InvestigationInstalledL2StaticSigningReading,
    Sendable
{
    package init() {}

    package func read(
        at url: URL
    ) -> InvestigationInstalledL2StaticSigningResult {
        guard investigationInstalledL2AbsoluteFileURL(url) else {
            return .invalid
        }
        var staticCode: SecStaticCode?
        guard
            SecStaticCodeCreateWithPath(
                url as CFURL,
                SecCSFlags(),
                &staticCode
            ) == errSecSuccess,
            let staticCode
        else {
            return .unavailable
        }
        guard
            SecStaticCodeCheckValidity(
                staticCode,
                SecCSFlags(rawValue: kSecCSStrictValidate),
                nil
            ) == errSecSuccess
        else {
            return .invalid
        }

        var information: CFDictionary?
        let flags = SecCSFlags(
            rawValue:
                kSecCSSigningInformation
                | kSecCSRequirementInformation
        )
        guard
            SecCodeCopySigningInformation(
                staticCode,
                flags,
                &information
            ) == errSecSuccess,
            let dictionary = information as? [CFString: Any],
            let signingIdentifier =
                dictionary[kSecCodeInfoIdentifier] as? String,
            let codeDirectoryHash =
                dictionary[kSecCodeInfoUnique] as? Data,
            let signatureFlags =
                dictionary[kSecCodeInfoFlags] as? NSNumber,
            let requirement = investigationInstalledL2Requirement(
                dictionary[kSecCodeInfoDesignatedRequirement]
            ),
            let requirementData = investigationInstalledL2RequirementData(
                requirement
            )
        else {
            return .invalid
        }
        do {
            return .observed(
                try InvestigationInstalledL2SigningIdentity(
                    signingIdentifier: signingIdentifier,
                    designatedRequirementSHA256:
                        InvestigationHandoffSHA256.hashing(requirementData),
                    codeDirectoryHash: codeDirectoryHash,
                    isAdHoc:
                        signatureFlags.uint32Value
                            & investigationInstalledL2AdHocSignatureFlag != 0
                )
            )
        } catch {
            return .invalid
        }
    }
}

package protocol InvestigationInstalledL2ManifestReading: Sendable {
    func observe(
        _ expectation: InvestigationInstalledL2NodeExpectation,
        expectedManifest: [String: Any]
    ) -> InvestigationInstalledL2ArtifactObservation
}

package struct InvestigationInstalledL2ManifestReader:
    InvestigationInstalledL2ManifestReading,
    Sendable
{
    private let nodeReader: InvestigationInstalledL2NodeReader

    package init(
        system: any InvestigationInstalledL2FileSystem
            = InvestigationInstalledL2DarwinFileSystem()
    ) {
        nodeReader = InvestigationInstalledL2NodeReader(system: system)
    }

    package func observe(
        _ expectation: InvestigationInstalledL2NodeExpectation,
        expectedManifest: [String: Any]
    ) -> InvestigationInstalledL2ArtifactObservation {
        switch nodeReader.inspect(expectation, readContents: true) {
        case .absent:
            return .absent
        case .invalid:
            return .invalid
        case .unavailable:
            return .unavailable
        case .presentValid(let data):
            guard
                let data,
                investigationInstalledL2ManifestIsExact(expectedManifest)
            else {
                return .invalid
            }
            do {
                var format = PropertyListSerialization.PropertyListFormat.xml
                guard
                    let manifest = try PropertyListSerialization.propertyList(
                        from: data,
                        options: [],
                        format: &format
                    ) as? [String: Any],
                    investigationInstalledL2ManifestIsExact(manifest)
                else {
                    return .invalid
                }
                return .presentValid
            } catch {
                return .invalid
            }
        }
    }
}

package struct InvestigationInstalledL2FixedPaths: Sendable {
    package let installedRoot: URL
    package let installedApp: URL
    package let appExecutable: URL
    package let helperExecutable: URL
    package let machineDriverExecutable: URL
    package let launchDaemonPlist: URL
    package let runtimeRoot: URL
    package let leaseRoot: URL

    package init() {
        let root = URL(
            fileURLWithPath: "/Library/Application Support/Stornaut"
        )
        let app = root.appendingPathComponent(
            "Stornaut-R5-Diagnostic.app"
        )
        let executables = app
            .appendingPathComponent("Contents")
            .appendingPathComponent("MacOS")
        installedRoot = root
        installedApp = app
        appExecutable = executables.appendingPathComponent(
            "StornautInvestigationDiagnostic"
        )
        helperExecutable = executables.appendingPathComponent(
            "StornautLifecycleHelper"
        )
        machineDriverExecutable = executables.appendingPathComponent(
            "StornautInvestigationMachineDriver"
        )
        launchDaemonPlist = URL(
            fileURLWithPath:
                "/Library/LaunchDaemons/com.eriklee.stornaut.lifecycle.plist"
        )
        runtimeRoot = root.appendingPathComponent(
            "R5Runtime"
        )
        leaseRoot = URL(
            fileURLWithPath: "/private/var/db/com.eriklee.stornaut.r5"
        )
    }

    package var launchDaemonManifest: [String: Any] {
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
            "Program": helperExecutable.path,
            "RunAtLoad": false,
            "SessionCreate": true,
            "ThrottleInterval": 1,
        ]
    }
}

package struct InvestigationInstalledL2ArtifactFacts: Sendable, Equatable {
    package let artifacts: [
        InvestigationInstalledL2ArtifactRole:
            InvestigationInstalledL2ArtifactObservation
    ]
    package let appStaticSigning: InvestigationInstalledL2SigningIdentity
    package let helperStaticSigning: InvestigationInstalledL2SigningIdentity
    package let machineDriverStaticSigning:
        InvestigationInstalledL2SigningIdentity
}

package struct InvestigationInstalledL2ArtifactReader: Sendable {
    package static let maximumExecutableBytes = 256 * 1_024 * 1_024
    package static let maximumMachineDriverExecutableBytes = 16 * 1_024 * 1_024
    package static let maximumLaunchDaemonPlistBytes = 64 * 1_024

    private let paths: InvestigationInstalledL2FixedPaths
    private let nodeObserver: any InvestigationInstalledL2NodeObserving
    private let signingReader: any InvestigationInstalledL2StaticSigningReading
    private let manifestReader: any InvestigationInstalledL2ManifestReading

    package init(
        nodeObserver: any InvestigationInstalledL2NodeObserving
            = InvestigationInstalledL2NodeReader(),
        signingReader: any InvestigationInstalledL2StaticSigningReading
            = InvestigationInstalledL2StaticSigningReader(),
        manifestReader: any InvestigationInstalledL2ManifestReading
            = InvestigationInstalledL2ManifestReader()
    ) {
        paths = InvestigationInstalledL2FixedPaths()
        self.nodeObserver = nodeObserver
        self.signingReader = signingReader
        self.manifestReader = manifestReader
    }

    package func observe(
        projection: InvestigationInstalledL2IdentityProjection
    ) throws -> InvestigationInstalledL2ArtifactFacts {
        var artifacts: [
            InvestigationInstalledL2ArtifactRole:
                InvestigationInstalledL2ArtifactObservation
        ] = [:]

        let installedRoot = nodeObserver.observe(
            try expectation(
                url: paths.installedRoot,
                kind: .directory,
                mode: 0o755
            )
        )
        guard installedRoot == .presentValid else {
            throw InvestigationInstalledL2SemanticError.installedContractUnproved
        }
        artifacts[.installedRoot] = installedRoot

        let appStaticSigning = try observeSignedNode(
            expectation: expectation(
                url: paths.installedApp,
                kind: .directory,
                mode: 0o755
            ),
            expected: { identity in
                identity.signingIdentifier == projection.appBundleIdentifier
            }
        )
        artifacts[.installedApp] = .presentValid

        let appExecutable = nodeObserver.observe(
            try expectation(
                url: paths.appExecutable,
                kind: .regularFile,
                mode: 0o755,
                expectedSHA256: projection.appExecutableSHA256,
                maximumSize: Self.maximumExecutableBytes
            )
        )
        guard appExecutable == .presentValid else {
            throw InvestigationInstalledL2SemanticError.installedContractUnproved
        }
        artifacts[.appExecutable] = appExecutable

        let helperStaticSigning = try observeSignedNode(
            expectation: expectation(
                url: paths.helperExecutable,
                kind: .regularFile,
                mode: 0o755,
                expectedSHA256: projection.helperExecutableSHA256,
                maximumSize: Self.maximumExecutableBytes
            ),
            expected: { identity in
                identity.signingIdentifier
                    == projection.helperServiceIdentifier + ".helper"
            }
        )
        artifacts[.helperExecutable] = .presentValid

        let machineDriverStaticSigning = try observeSignedNode(
            expectation: expectation(
                url: paths.machineDriverExecutable,
                kind: .regularFile,
                mode: 0o755,
                expectedSHA256: projection.machineDriverExecutableSHA256,
                maximumSize: Self.maximumMachineDriverExecutableBytes
            ),
            expected: { identity in
                identity.signingIdentifier
                    == projection.machineDriverSigningIdentifier
                    && identity.designatedRequirementSHA256
                        == projection.machineDriverDesignatedRequirementSHA256
                    && identity.codeDirectoryHash
                        == projection.machineDriverCodeDirectoryHash
                    && identity.isAdHoc
            }
        )
        artifacts[.machineDriverExecutable] = .presentValid

        let manifest = manifestReader.observe(
            try expectation(
                url: paths.launchDaemonPlist,
                kind: .regularFile,
                mode: 0o644,
                maximumSize: Self.maximumLaunchDaemonPlistBytes
            ),
            expectedManifest: paths.launchDaemonManifest
        )
        guard manifest == .presentValid else {
            throw InvestigationInstalledL2SemanticError.installedContractUnproved
        }
        artifacts[.launchDaemonPlist] = manifest

        let runtimeRoot = nodeObserver.observe(
            try expectation(
                url: paths.runtimeRoot,
                kind: .directory,
                mode: 0o711
            )
        )
        guard runtimeRoot == .presentValid || runtimeRoot == .absent else {
            throw InvestigationInstalledL2SemanticError.installedContractUnproved
        }
        artifacts[.runtimeRoot] = runtimeRoot

        let leaseRoot = nodeObserver.observe(
            try expectation(
                url: paths.leaseRoot,
                kind: .directory,
                mode: 0o700
            )
        )
        guard leaseRoot == .presentValid || leaseRoot == .absent else {
            throw InvestigationInstalledL2SemanticError.installedContractUnproved
        }
        artifacts[.leaseRoot] = leaseRoot

        return InvestigationInstalledL2ArtifactFacts(
            artifacts: artifacts,
            appStaticSigning: appStaticSigning,
            helperStaticSigning: helperStaticSigning,
            machineDriverStaticSigning: machineDriverStaticSigning
        )
    }

    private func observeSignedNode(
        expectation: InvestigationInstalledL2NodeExpectation,
        expected: (InvestigationInstalledL2SigningIdentity) -> Bool
    ) throws -> InvestigationInstalledL2SigningIdentity {
        guard nodeObserver.observe(expectation) == .presentValid else {
            throw InvestigationInstalledL2SemanticError.installedContractUnproved
        }
        let identity: InvestigationInstalledL2SigningIdentity
        switch signingReader.read(at: expectation.url) {
        case .observed(let value):
            identity = value
        case .invalid, .unavailable:
            throw InvestigationInstalledL2SemanticError.installedContractUnproved
        }
        guard
            expected(identity),
            nodeObserver.observe(expectation) == .presentValid
        else {
            throw InvestigationInstalledL2SemanticError.installedContractUnproved
        }
        return identity
    }

    private func expectation(
        url: URL,
        kind: InvestigationInstalledL2NodeKind,
        mode: mode_t,
        expectedSHA256: InvestigationHandoffSHA256? = nil,
        maximumSize: Int = 0
    ) throws -> InvestigationInstalledL2NodeExpectation {
        try InvestigationInstalledL2NodeExpectation(
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
}

private func investigationInstalledL2AbsoluteFileURL(_ url: URL) -> Bool {
    url.isFileURL && url.path.hasPrefix("/") && !url.path.isEmpty
}

private func investigationInstalledL2Requirement(
    _ value: Any?
) -> SecRequirement? {
    guard let value else { return nil }
    let object = value as AnyObject
    guard CFGetTypeID(object) == SecRequirementGetTypeID() else {
        return nil
    }
    return unsafeDowncast(object, to: SecRequirement.self)
}

private func investigationInstalledL2RequirementData(
    _ requirement: SecRequirement
) -> Data? {
    var data: CFData?
    guard
        SecRequirementCopyData(
            requirement,
            SecCSFlags(),
            &data
        ) == errSecSuccess,
        let data
    else {
        return nil
    }
    return data as Data
}

private func investigationInstalledL2ManifestIsExact(
    _ manifest: [String: Any]
) -> Bool {
    let expectedKeys: Set<String> = [
        "AbandonProcessGroup",
        "AssociatedBundleIdentifiers",
        "KeepAlive",
        "Label",
        "MachServices",
        "ProcessType",
        "Program",
        "RunAtLoad",
        "SessionCreate",
        "ThrottleInterval",
    ]
    guard
        Set(manifest.keys) == expectedKeys,
        investigationInstalledL2Boolean(
            manifest["AbandonProcessGroup"], equals: false
        ),
        manifest["AssociatedBundleIdentifiers"] as? [String]
            == ["com.eriklee.stornaut"],
        let keepAlive = manifest["KeepAlive"] as? [String: Any],
        Set(keepAlive.keys) == ["SuccessfulExit"],
        investigationInstalledL2Boolean(
            keepAlive["SuccessfulExit"], equals: false
        ),
        manifest["Label"] as? String == "com.eriklee.stornaut.lifecycle",
        let machServices = manifest["MachServices"] as? [String: Any],
        Set(machServices.keys) == [
            "com.eriklee.stornaut.lifecycle",
            "com.eriklee.stornaut.lifecycle.machine-claim",
        ],
        investigationInstalledL2Boolean(
            machServices["com.eriklee.stornaut.lifecycle"], equals: true
        ),
        investigationInstalledL2Boolean(
            machServices["com.eriklee.stornaut.lifecycle.machine-claim"],
            equals: true
        ),
        manifest["ProcessType"] as? String == "Interactive",
        manifest["Program"] as? String
            == "/Library/Application Support/Stornaut/"
                + "Stornaut-R5-Diagnostic.app/Contents/MacOS/"
                + "StornautLifecycleHelper",
        investigationInstalledL2Boolean(
            manifest["RunAtLoad"], equals: false
        ),
        investigationInstalledL2Boolean(
            manifest["SessionCreate"], equals: true
        ),
        investigationInstalledL2Integer(
            manifest["ThrottleInterval"], equals: 1
        )
    else {
        return false
    }
    return true
}

private func investigationInstalledL2Boolean(
    _ value: Any?,
    equals expected: Bool
) -> Bool {
    guard let value else { return false }
    let object = value as AnyObject
    guard CFGetTypeID(object) == CFBooleanGetTypeID() else {
        return false
    }
    return (object as? NSNumber)?.boolValue == expected
}

private func investigationInstalledL2Integer(
    _ value: Any?,
    equals expected: Int
) -> Bool {
    guard let value else { return false }
    let object = value as AnyObject
    guard CFGetTypeID(object) == CFNumberGetTypeID() else {
        return false
    }
    let number = unsafeDowncast(object, to: CFNumber.self)
    guard !CFNumberIsFloatType(number) else { return false }
    return (object as? NSNumber)?.intValue == expected
}
