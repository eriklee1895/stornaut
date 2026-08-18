import CryptoKit
import Darwin
import Foundation

struct LifecycleRootTopologySystemCallError:
    Error,
    Sendable,
    Equatable
{
    let errno: Int32

    init(errno: Int32) {
        self.errno = errno
    }
}

enum LifecycleRootTopologyNodeKind: Sendable, Equatable {
    case regularFile
    case directory
}

struct LifecycleRootTopologyNodeMetadata: Sendable, Equatable {
    var deviceID: dev_t
    var inode: ino_t
    var generation: UInt32
    var mode: mode_t
    var linkCount: nlink_t
    var ownerUserID: uid_t
    var ownerGroupID: gid_t
    var size: off_t
    var modificationSeconds: Int
    var modificationNanoseconds: Int
    var changeSeconds: Int
    var changeNanoseconds: Int

    init(_ value: stat) {
        deviceID = value.st_dev
        inode = value.st_ino
        generation = value.st_gen
        mode = value.st_mode
        linkCount = value.st_nlink
        ownerUserID = value.st_uid
        ownerGroupID = value.st_gid
        size = value.st_size
        modificationSeconds = value.st_mtimespec.tv_sec
        modificationNanoseconds = value.st_mtimespec.tv_nsec
        changeSeconds = value.st_ctimespec.tv_sec
        changeNanoseconds = value.st_ctimespec.tv_nsec
    }

    func hasSameIdentity(
        as other: LifecycleRootTopologyNodeMetadata
    ) -> Bool {
        deviceID == other.deviceID
            && inode == other.inode
            && generation == other.generation
    }
}

struct LifecycleRootTopologyNodeExpectation: Sendable, Equatable {
    let url: URL
    let kind: LifecycleRootTopologyNodeKind
    let ownerUserID: uid_t
    let ownerGroupID: gid_t
    let mode: mode_t
    let requiresSingleLink: Bool
    let expectedSHA256: String?
    let maximumSize: Int

    init(
        url: URL,
        kind: LifecycleRootTopologyNodeKind,
        ownerUserID: uid_t,
        ownerGroupID: gid_t,
        mode: mode_t,
        requiresSingleLink: Bool,
        expectedSHA256: String?,
        maximumSize: Int
    ) {
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

protocol LifecycleRootTopologyNodeObserving: Sendable {
    func observe(
        _ expectation: LifecycleRootTopologyNodeExpectation
    ) -> LifecycleRootTopologyArtifactObservation
}

private enum LifecycleRootTopologyNodeInspection {
    case absent
    case presentValid(data: Data?)
    case invalid(reasonKey: String)
    case unavailable(reasonKey: String)

    var observation: LifecycleRootTopologyArtifactObservation {
        switch self {
        case .absent:
            .absent
        case .presentValid:
            .presentValid
        case .invalid(let reasonKey):
            .invalid(reasonKey: reasonKey)
        case .unavailable(let reasonKey):
            .unavailable(reasonKey: reasonKey)
        }
    }
}

protocol LifecycleRootTopologyFileSystem: Sendable {
    func metadata(
        at url: URL
    ) -> Result<
        LifecycleRootTopologyNodeMetadata,
        LifecycleRootTopologySystemCallError
    >

    func openReadOnly(
        _ url: URL,
        kind: LifecycleRootTopologyNodeKind
    ) -> Result<Int32, LifecycleRootTopologySystemCallError>

    func metadata(
        for descriptor: Int32
    ) -> Result<
        LifecycleRootTopologyNodeMetadata,
        LifecycleRootTopologySystemCallError
    >

    func read(
        from descriptor: Int32,
        maximumBytes: Int
    ) -> Result<Data, LifecycleRootTopologySystemCallError>

    func close(_ descriptor: Int32)
}

struct DarwinRootTopologyFileSystem:
    LifecycleRootTopologyFileSystem,
    Sendable
{
    func metadata(
        at url: URL
    ) -> Result<
        LifecycleRootTopologyNodeMetadata,
        LifecycleRootTopologySystemCallError
    > {
        guard rootTopologyAbsoluteFileURL(url) else {
            return .failure(
                LifecycleRootTopologySystemCallError(errno: EINVAL)
            )
        }
        var value = stat()
        guard lstat(url.path, &value) == 0 else {
            return .failure(
                LifecycleRootTopologySystemCallError(errno: Darwin.errno)
            )
        }
        return .success(LifecycleRootTopologyNodeMetadata(value))
    }

    func openReadOnly(
        _ url: URL,
        kind: LifecycleRootTopologyNodeKind
    ) -> Result<Int32, LifecycleRootTopologySystemCallError> {
        guard rootTopologyAbsoluteFileURL(url) else {
            return .failure(
                LifecycleRootTopologySystemCallError(errno: EINVAL)
            )
        }
        var flags = O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK
        if kind == .directory {
            flags |= O_DIRECTORY
        }
        let descriptor = Darwin.open(url.path, flags)
        guard descriptor >= 0 else {
            return .failure(
                LifecycleRootTopologySystemCallError(errno: Darwin.errno)
            )
        }
        return .success(descriptor)
    }

    func metadata(
        for descriptor: Int32
    ) -> Result<
        LifecycleRootTopologyNodeMetadata,
        LifecycleRootTopologySystemCallError
    > {
        guard descriptor >= 0 else {
            return .failure(
                LifecycleRootTopologySystemCallError(errno: EBADF)
            )
        }
        var value = stat()
        guard fstat(descriptor, &value) == 0 else {
            return .failure(
                LifecycleRootTopologySystemCallError(errno: Darwin.errno)
            )
        }
        return .success(LifecycleRootTopologyNodeMetadata(value))
    }

    func read(
        from descriptor: Int32,
        maximumBytes: Int
    ) -> Result<Data, LifecycleRootTopologySystemCallError> {
        guard descriptor >= 0, maximumBytes >= 0 else {
            return .failure(
                LifecycleRootTopologySystemCallError(errno: EINVAL)
            )
        }
        var result = Data()
        let chunkCapacity = 64 * 1_024
        var buffer = [UInt8](
            repeating: 0,
            count: min(chunkCapacity, max(1, maximumBytes))
        )

        while result.count < maximumBytes {
            let requested = min(
                buffer.count,
                maximumBytes - result.count
            )
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
            return .failure(
                LifecycleRootTopologySystemCallError(errno: code)
            )
        }
        return .success(result)
    }

    func close(_ descriptor: Int32) {
        guard descriptor >= 0 else {
            return
        }
        _ = Darwin.close(descriptor)
    }
}

struct DarwinRootTopologyNodeReader:
    LifecycleRootTopologyNodeObserving,
    Sendable
{
    private let fileSystem: any LifecycleRootTopologyFileSystem

    init(
        fileSystem: any LifecycleRootTopologyFileSystem
            = DarwinRootTopologyFileSystem()
    ) {
        self.fileSystem = fileSystem
    }

    func observe(
        _ expectation: LifecycleRootTopologyNodeExpectation
    ) -> LifecycleRootTopologyArtifactObservation {
        inspect(
            expectation,
            readContents: expectation.expectedSHA256 != nil
        ).observation
    }

    fileprivate func inspect(
        _ expectation: LifecycleRootTopologyNodeExpectation,
        readContents: Bool
    ) -> LifecycleRootTopologyNodeInspection {
        guard valid(expectation) else {
            return .invalid(
                reasonKey: "runtime.topology.invalid-node-expectation"
            )
        }

        let pathMetadata: LifecycleRootTopologyNodeMetadata
        switch fileSystem.metadata(at: expectation.url) {
        case .success(let metadata):
            pathMetadata = metadata
        case .failure(let error) where error.errno == ENOENT:
            return .absent
        case .failure:
            return .unavailable(
                reasonKey: "runtime.topology.lstat-unavailable"
            )
        }

        if let invalid = validate(
            pathMetadata,
            against: expectation
        ) {
            return invalid
        }

        let descriptor: Int32
        switch fileSystem.openReadOnly(
            expectation.url,
            kind: expectation.kind
        ) {
        case .success(let openedDescriptor) where openedDescriptor >= 0:
            descriptor = openedDescriptor
        case .success, .failure:
            return .unavailable(
                reasonKey: "runtime.topology.open-unavailable"
            )
        }
        defer { fileSystem.close(descriptor) }

        let descriptorMetadata: LifecycleRootTopologyNodeMetadata
        switch fileSystem.metadata(for: descriptor) {
        case .success(let metadata):
            descriptorMetadata = metadata
        case .failure:
            return .unavailable(
                reasonKey: "runtime.topology.fstat-unavailable"
            )
        }

        guard pathMetadata.hasSameIdentity(as: descriptorMetadata) else {
            return .invalid(
                reasonKey: "runtime.topology.node-identity-changed"
            )
        }
        if let invalid = validate(
            descriptorMetadata,
            against: expectation
        ) {
            return invalid
        }

        var data: Data?
        if expectation.kind == .regularFile,
           readContents || expectation.expectedSHA256 != nil
        {
            let readLimit = expectation.maximumSize == Int.max
                ? Int.max
                : expectation.maximumSize + 1
            let value: Data
            switch fileSystem.read(
                from: descriptor,
                maximumBytes: readLimit
            ) {
            case .success(let readData):
                value = readData
            case .failure:
                return .unavailable(
                    reasonKey: "runtime.topology.read-unavailable"
                )
            }
            guard
                value.count == Int(descriptorMetadata.size),
                value.count <= expectation.maximumSize
            else {
                return .invalid(
                    reasonKey: "runtime.topology.file-size-changed"
                )
            }
            if let expectedSHA256 = expectation.expectedSHA256,
               Self.sha256(value) != expectedSHA256
            {
                return .invalid(
                    reasonKey: "runtime.topology.file-hash-mismatch"
                )
            }
            if readContents {
                data = value
            }
        }

        switch fileSystem.metadata(at: expectation.url) {
        case .success(let finalMetadata):
            guard pathMetadata.hasSameIdentity(as: finalMetadata) else {
                return .invalid(
                    reasonKey: "runtime.topology.node-identity-changed"
                )
            }
            guard finalMetadata == descriptorMetadata else {
                return .invalid(
                    reasonKey: "runtime.topology.node-metadata-changed"
                )
            }
        case .failure(let error) where error.errno == ENOENT:
            return .unavailable(
                reasonKey: "runtime.topology.node-vanished"
            )
        case .failure:
            return .unavailable(
                reasonKey: "runtime.topology.final-lstat-unavailable"
            )
        }
        return .presentValid(data: data)
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { byte in
            String(format: "%02x", byte)
        }.joined()
    }

    private func valid(
        _ expectation: LifecycleRootTopologyNodeExpectation
    ) -> Bool {
        guard
            rootTopologyAbsoluteFileURL(expectation.url),
            expectation.mode & ~mode_t(0o7777) == 0,
            expectation.maximumSize >= 0
        else {
            return false
        }
        switch expectation.kind {
        case .regularFile:
            return expectation.expectedSHA256.map(
                rootTopologyValidSHA256
            ) ?? true
        case .directory:
            return expectation.expectedSHA256 == nil
        }
    }

    private func validate(
        _ metadata: LifecycleRootTopologyNodeMetadata,
        against expectation: LifecycleRootTopologyNodeExpectation
    ) -> LifecycleRootTopologyNodeInspection? {
        let type = metadata.mode & mode_t(S_IFMT)
        let expectedType = expectation.kind == .regularFile
            ? mode_t(S_IFREG)
            : mode_t(S_IFDIR)
        guard type == expectedType else {
            return .invalid(
                reasonKey: "runtime.topology.node-type-mismatch"
            )
        }
        guard metadata.ownerUserID == expectation.ownerUserID else {
            return .invalid(
                reasonKey: "runtime.topology.node-owner-mismatch"
            )
        }
        guard metadata.ownerGroupID == expectation.ownerGroupID else {
            return .invalid(
                reasonKey: "runtime.topology.node-group-mismatch"
            )
        }
        guard
            metadata.mode & mode_t(0o7777) == expectation.mode
        else {
            return .invalid(
                reasonKey: "runtime.topology.node-mode-mismatch"
            )
        }
        if expectation.requiresSingleLink, metadata.linkCount != 1 {
            return .invalid(
                reasonKey: "runtime.topology.node-link-count-mismatch"
            )
        }
        if expectation.kind == .regularFile {
            guard
                metadata.size >= 0,
                UInt64(metadata.size)
                    <= UInt64(expectation.maximumSize)
            else {
                return .invalid(
                    reasonKey: "runtime.topology.file-size-invalid"
                )
            }
        }
        return nil
    }
}

enum LifecycleRootTopologySigningEvidenceResult: Sendable, Equatable {
    case observed(LifecycleBundleSigningEvidence)
    case invalid(reasonKey: String)
    case unavailable(reasonKey: String)
}

protocol LifecycleRootTopologySigningEvidenceReading: Sendable {
    func read(
        at url: URL
    ) -> LifecycleRootTopologySigningEvidenceResult
}

struct DarwinRootTopologySigningEvidenceReader:
    LifecycleRootTopologySigningEvidenceReading,
    Sendable
{
    private let reader: LifecycleBundleSigningIdentityReader

    init(reader: LifecycleBundleSigningIdentityReader = .init()) {
        self.reader = reader
    }

    func read(
        at url: URL
    ) -> LifecycleRootTopologySigningEvidenceResult {
        do {
            return .observed(try reader.evidence(bundleURL: url))
        } catch LifecycleSigningIdentityError.invalidIdentity {
            return .invalid(
                reasonKey: "runtime.topology.signing-invalid"
            )
        } catch {
            return .unavailable(
                reasonKey: "runtime.topology.signing-unavailable"
            )
        }
    }
}

protocol LifecycleRootTopologyManifestReading: Sendable {
    func observe(
        expectation: LifecycleRootTopologyNodeExpectation,
        contract: LifecycleLocalInstallationContract
    ) -> LifecycleRootTopologyArtifactObservation
}

struct DarwinRootTopologyManifestReader:
    LifecycleRootTopologyManifestReading,
    Sendable
{
    private let nodeReader: DarwinRootTopologyNodeReader

    init(
        fileSystem: any LifecycleRootTopologyFileSystem
            = DarwinRootTopologyFileSystem()
    ) {
        nodeReader = DarwinRootTopologyNodeReader(fileSystem: fileSystem)
    }

    func observe(
        expectation: LifecycleRootTopologyNodeExpectation,
        contract: LifecycleLocalInstallationContract
    ) -> LifecycleRootTopologyArtifactObservation {
        switch nodeReader.inspect(expectation, readContents: true) {
        case .absent:
            return .absent
        case .invalid(let reasonKey):
            return .invalid(reasonKey: reasonKey)
        case .unavailable(let reasonKey):
            return .unavailable(reasonKey: reasonKey)
        case .presentValid(let data):
            guard let data else {
                return .unavailable(
                    reasonKey: "runtime.topology.plist-read-unavailable"
                )
            }
            do {
                var format = PropertyListSerialization.PropertyListFormat.xml
                guard
                    let manifest = try PropertyListSerialization.propertyList(
                        from: data,
                        options: [],
                        format: &format
                    ) as? [String: Any],
                    try contract.validateLaunchDaemonManifest(manifest)
                else {
                    return .invalid(
                        reasonKey: "runtime.topology.plist-mismatch"
                    )
                }
                return .presentValid
            } catch {
                return .invalid(
                    reasonKey: "runtime.topology.plist-mismatch"
                )
            }
        }
    }
}

struct DarwinRootTopologyArtifactReader:
    LifecycleRootTopologyArtifactReading,
    Sendable
{
    static let maximumExecutableBytes = 256 * 1_024 * 1_024
    static let maximumMachineDriverExecutableBytes = 16 * 1_024 * 1_024
    static let maximumLaunchDaemonPlistBytes = 64 * 1_024

    private let nodeObserver: any LifecycleRootTopologyNodeObserving
    private let signingReader:
        any LifecycleRootTopologySigningEvidenceReading
    private let manifestReader: any LifecycleRootTopologyManifestReading

    init(
        nodeObserver: any LifecycleRootTopologyNodeObserving
            = DarwinRootTopologyNodeReader(),
        signingReader: any LifecycleRootTopologySigningEvidenceReading
            = DarwinRootTopologySigningEvidenceReader(),
        manifestReader: any LifecycleRootTopologyManifestReading
            = DarwinRootTopologyManifestReader()
    ) {
        self.nodeObserver = nodeObserver
        self.signingReader = signingReader
        self.manifestReader = manifestReader
    }

    func observe(
        _ role: LifecycleRootTopologyArtifactRole,
        contract: LifecycleLocalInstallationContract,
        binding: LifecycleRootTopologyBinding
    ) -> LifecycleRootTopologyArtifactObservation {
        switch role {
        case .installedRoot:
            return observeNode(
                url: contract.installedRootURL,
                kind: .directory,
                mode: 0o755
            )
        case .installedApp:
            let expectation = expectation(
                url: contract.installedAppURL,
                kind: .directory,
                mode: 0o755
            )
            let node = nodeObserver.observe(expectation)
            guard node == .presentValid else {
                return node
            }
            let signing = observeSigning(
                at: contract.installedAppURL,
                expected: binding.appSigningEvidence
            )
            guard signing == .presentValid else {
                return signing
            }
            return nodeObserver.observe(expectation)
        case .appExecutable:
            return observeNode(
                url: contract.appExecutableURL,
                kind: .regularFile,
                mode: 0o755,
                expectedSHA256:
                    binding.appSigningEvidence.executableSHA256,
                maximumSize: Self.maximumExecutableBytes
            )
        case .helperExecutable:
            let expectation = expectation(
                url: contract.helperExecutableURL,
                kind: .regularFile,
                mode: 0o755,
                expectedSHA256:
                    binding.helperSigningEvidence.executableSHA256,
                maximumSize: Self.maximumExecutableBytes
            )
            let node = nodeObserver.observe(expectation)
            guard node == .presentValid else {
                return node
            }
            let signing = observeSigning(
                at: contract.helperExecutableURL,
                expected: binding.helperSigningEvidence
            )
            guard signing == .presentValid else {
                return signing
            }
            return nodeObserver.observe(expectation)
        case .machineDriverExecutable:
            let expectation = expectation(
                url: contract.machineDriverExecutableURL,
                kind: .regularFile,
                mode: 0o755,
                expectedSHA256:
                    binding.machineDriverSigningEvidence.executableSHA256,
                maximumSize: Self.maximumMachineDriverExecutableBytes
            )
            let node = nodeObserver.observe(expectation)
            guard node == .presentValid else {
                return node
            }
            let signing = observeSigning(
                at: contract.machineDriverExecutableURL,
                expected: binding.machineDriverSigningEvidence
            )
            guard signing == .presentValid else {
                return signing
            }
            return nodeObserver.observe(expectation)
        case .launchDaemonPlist:
            return manifestReader.observe(
                expectation: expectation(
                    url: contract.launchDaemonPlistURL,
                    kind: .regularFile,
                    mode: 0o644,
                    maximumSize: Self.maximumLaunchDaemonPlistBytes
                ),
                contract: contract
            )
        case .runtimeRoot:
            return observeNode(
                url: contract.runtimeRootURL,
                kind: .directory,
                mode: 0o711
            )
        case .leaseRoot:
            return observeNode(
                url: contract.leaseRootURL,
                kind: .directory,
                mode: 0o700
            )
        }
    }

    private func observeNode(
        url: URL,
        kind: LifecycleRootTopologyNodeKind,
        mode: mode_t,
        expectedSHA256: String? = nil,
        maximumSize: Int = 0
    ) -> LifecycleRootTopologyArtifactObservation {
        nodeObserver.observe(
            expectation(
                url: url,
                kind: kind,
                mode: mode,
                expectedSHA256: expectedSHA256,
                maximumSize: maximumSize
            )
        )
    }

    private func expectation(
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

    private func observeSigning(
        at url: URL,
        expected: LifecycleBundleSigningEvidence
    ) -> LifecycleRootTopologyArtifactObservation {
        switch signingReader.read(at: url) {
        case .observed(let evidence):
            evidence == expected
                ? .presentValid
                : .invalid(
                    reasonKey: "runtime.topology.signing-mismatch"
                )
        case .invalid(let reasonKey):
            .invalid(reasonKey: reasonKey)
        case .unavailable(let reasonKey):
            .unavailable(reasonKey: reasonKey)
        }
    }
}

protocol LifecycleRootTopologyProcessIdentityReading: Sendable {
    func identity(
        for processID: pid_t
    ) -> Result<LifecycleProcessIdentity, DarwinLifecycleSupportError>
}

struct DarwinRootTopologyProcessIdentityReader:
    LifecycleRootTopologyProcessIdentityReading,
    Sendable
{
    private let inventory: DarwinLifecycleInventory

    init(inventory: DarwinLifecycleInventory = .init()) {
        self.inventory = inventory
    }

    func identity(
        for processID: pid_t
    ) -> Result<LifecycleProcessIdentity, DarwinLifecycleSupportError> {
        do {
            return .success(try inventory.identity(for: processID))
        } catch let error as DarwinLifecycleSupportError {
            return .failure(error)
        } catch {
            return .failure(.invalidIdentity)
        }
    }
}

enum LifecycleRootTopologyProcessExecutableError:
    Error,
    Sendable,
    Equatable
{
    case unavailable
    case systemCall(errno: Int32)
}

protocol LifecycleRootTopologyProcessExecutableReading: Sendable {
    func executableURL(
        for processID: pid_t
    ) -> Result<URL, LifecycleRootTopologyProcessExecutableError>
}

struct DarwinRootTopologyProcessExecutableReader:
    LifecycleRootTopologyProcessExecutableReading,
    Sendable
{
    func executableURL(
        for processID: pid_t
    ) -> Result<URL, LifecycleRootTopologyProcessExecutableError> {
        guard processID > 1 else {
            return .failure(.unavailable)
        }
        var buffer = [CChar](
            repeating: 0,
            count: 4 * Int(MAXPATHLEN)
        )
        Darwin.errno = 0
        let count = buffer.withUnsafeMutableBytes { bytes in
            proc_pidpath(
                processID,
                bytes.baseAddress,
                UInt32(bytes.count)
            )
        }
        guard count > 0 else {
            let code = Darwin.errno
            return .failure(
                .systemCall(errno: code == 0 ? EIO : code)
            )
        }
        let returnedBytes = buffer.prefix(Int(count))
        let pathBytes: ArraySlice<CChar>
        if let terminator = returnedBytes.firstIndex(of: 0) {
            guard returnedBytes[terminator...].allSatisfy({ $0 == 0 }) else {
                return .failure(.unavailable)
            }
            pathBytes = returnedBytes[..<terminator]
        } else {
            pathBytes = returnedBytes
        }
        let utf8 = pathBytes.map { UInt8(bitPattern: $0) }
        guard
            let path = String(bytes: utf8, encoding: .utf8),
            path.utf8.count == utf8.count,
            path.hasPrefix("/")
        else {
            return .failure(.unavailable)
        }
        let url = URL(filePath: path).standardizedFileURL
        guard rootTopologyAbsoluteFileURL(url) else {
            return .failure(.unavailable)
        }
        return .success(url)
    }
}

struct DarwinRootTopologyProcessReader:
    LifecycleRootTopologyProcessReading,
    Sendable
{
    private let identityReader:
        any LifecycleRootTopologyProcessIdentityReading
    private let executableReader:
        any LifecycleRootTopologyProcessExecutableReading
    private let signingVerifier: any LifecycleCodeSigningVerifying

    init(
        identityReader: any LifecycleRootTopologyProcessIdentityReading
            = DarwinRootTopologyProcessIdentityReader(),
        executableReader: any LifecycleRootTopologyProcessExecutableReading
            = DarwinRootTopologyProcessExecutableReader(),
        signingVerifier: any LifecycleCodeSigningVerifying
            = SecurityLifecycleCodeSigningVerifier()
    ) {
        self.identityReader = identityReader
        self.executableReader = executableReader
        self.signingVerifier = signingVerifier
    }

    func read(
        processID: pid_t
    ) -> LifecycleRootTopologyProcessReadResult {
        guard processID > 1 else {
            return .unresolved(
                reasonKey: "runtime.topology.invalid-process-id"
            )
        }

        let initialIdentity: LifecycleProcessIdentity
        switch identityReader.identity(for: processID) {
        case .success(let identity):
            initialIdentity = identity
        case .failure(.identityUnavailable(let code)) where code == ESRCH:
            return .absent
        case .failure:
            return .unresolved(
                reasonKey: "runtime.topology.process-identity-unavailable"
            )
        }
        guard initialIdentity.processID == processID else {
            return .unresolved(
                reasonKey: "runtime.topology.process-identity-mismatch"
            )
        }

        let executableURL: URL
        switch executableReader.executableURL(for: processID) {
        case .success(let url) where rootTopologyAbsoluteFileURL(url):
            executableURL = url.standardizedFileURL
        case .failure(.systemCall(let code)) where code == ESRCH:
            return .unresolved(
                reasonKey: "runtime.topology.process-vanished"
            )
        case .success, .failure:
            return .unresolved(
                reasonKey: "runtime.topology.process-path-unavailable"
            )
        }

        let signingIdentity: LifecycleSigningIdentity
        switch signingVerifier.verify(
            auditToken: initialIdentity.auditToken
        ) {
        case let .verified(
            verifiedProcessID,
            verifiedUserID,
            signingIdentifier,
            designatedRequirementSHA256,
            codeDirectoryHash
        ) where verifiedProcessID == processID
            && verifiedUserID == initialIdentity.effectiveUserID:
            do {
                signingIdentity = try LifecycleSigningIdentity(
                    signingIdentifier: signingIdentifier,
                    designatedRequirementSHA256:
                        designatedRequirementSHA256,
                    codeDirectoryHash: codeDirectoryHash
                )
            } catch {
                return .unresolved(
                    reasonKey: "runtime.topology.process-signing-invalid"
                )
            }
        case .verified:
            return .unresolved(
                reasonKey: "runtime.topology.process-signing-mismatch"
            )
        case .unresolved:
            return .unresolved(
                reasonKey: "runtime.topology.process-signing-unavailable"
            )
        }

        let finalIdentity: LifecycleProcessIdentity
        switch identityReader.identity(for: processID) {
        case .success(let identity):
            finalIdentity = identity
        case .failure(.identityUnavailable(let code)) where code == ESRCH:
            return .unresolved(
                reasonKey: "runtime.topology.process-vanished"
            )
        case .failure:
            return .unresolved(
                reasonKey: "runtime.topology.process-identity-unavailable"
            )
        }
        guard finalIdentity == initialIdentity else {
            return .identityReused
        }

        return .observed(
            LifecycleRootTopologyProcessSnapshot(
                identity: finalIdentity,
                executableURL: executableURL,
                signingIdentity: signingIdentity
            )
        )
    }
}

private func rootTopologyAbsoluteFileURL(_ url: URL) -> Bool {
    url.isFileURL
        && url.path.hasPrefix("/")
        && !url.path.isEmpty
}

private func rootTopologyValidSHA256(_ value: String) -> Bool {
    value.utf8.count == 64
        && value.utf8.allSatisfy { byte in
            (0x30...0x39).contains(byte)
                || (0x61...0x66).contains(byte)
        }
}
