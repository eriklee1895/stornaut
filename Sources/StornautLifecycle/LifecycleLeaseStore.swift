import Darwin
import Foundation

public struct LifecycleBootSessionID:
    RawRepresentable,
    Codable,
    Sendable,
    Hashable
{
    public let rawValue: UUID

    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard let identifier = UUID(uuidString: value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid lifecycle boot session identifier"
            )
        }
        rawValue = identifier
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue.uuidString.lowercased())
    }
}

public enum LifecycleBootSessionError: Error, Sendable, Equatable {
    case unavailable(errno: Int32)
    case invalidValue
}

public func currentLifecycleBootSessionID() throws
    -> LifecycleBootSessionID
{
    var byteCount = 0
    guard
        sysctlbyname(
            "kern.bootsessionuuid",
            nil,
            &byteCount,
            nil,
            0
        ) == 0,
        byteCount > 1,
        byteCount <= 128
    else {
        throw LifecycleBootSessionError.unavailable(errno: errno)
    }
    var bytes = [CChar](repeating: 0, count: byteCount)
    guard sysctlbyname(
        "kern.bootsessionuuid",
        &bytes,
        &byteCount,
        nil,
        0
    ) == 0 else {
        throw LifecycleBootSessionError.unavailable(errno: errno)
    }
    let valueBytes = bytes.prefix { $0 != 0 }.map {
        UInt8(bitPattern: $0)
    }
    let value = String(decoding: valueBytes, as: UTF8.self)
    guard let identifier = UUID(uuidString: value) else {
        throw LifecycleBootSessionError.invalidValue
    }
    return LifecycleBootSessionID(rawValue: identifier)
}

public struct LifecycleInvestigationLease:
    Codable,
    Sendable,
    Equatable
{
    public let investigationID: LifecycleInvestigationID
    public let bootSessionID: LifecycleBootSessionID
    public let auditSessionID: Int32
    public let userID: uid_t

    private enum CodingKeys: String {
        case protocolVersion
        case investigationID
        case bootSessionID
        case auditSessionID
        case userID
    }

    public init(
        investigationID: LifecycleInvestigationID,
        bootSessionID: LifecycleBootSessionID,
        auditSessionID: Int32,
        userID: uid_t
    ) throws {
        guard auditSessionID > 0, userID > 0 else {
            throw LifecycleLeaseStoreError.invalidLease
        }
        self.investigationID = investigationID
        self.bootSessionID = bootSessionID
        self.auditSessionID = auditSessionID
        self.userID = userID
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(
            decoder: decoder,
            expectedKeys: Set([
                CodingKeys.protocolVersion.rawValue,
                CodingKeys.investigationID.rawValue,
                CodingKeys.bootSessionID.rawValue,
                CodingKeys.auditSessionID.rawValue,
                CodingKeys.userID.rawValue,
            ])
        )
        guard
            try container.decode(
                Int.self,
                forKey: AnyLifecycleCodingKey(
                    CodingKeys.protocolVersion.rawValue
                )
            ) == 1
        else {
            throw DecodingError.dataCorruptedError(
                forKey: AnyLifecycleCodingKey(
                    CodingKeys.protocolVersion.rawValue
                ),
                in: container,
                debugDescription: "Unsupported lifecycle lease version"
            )
        }
        let investigationID = try container.decode(
            LifecycleInvestigationID.self,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.investigationID.rawValue
            )
        )
        let bootSessionID = try container.decode(
            LifecycleBootSessionID.self,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.bootSessionID.rawValue
            )
        )
        let auditSessionID = try container.decode(
            Int32.self,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.auditSessionID.rawValue
            )
        )
        let userID = try container.decode(
            uid_t.self,
            forKey: AnyLifecycleCodingKey(CodingKeys.userID.rawValue)
        )
        guard auditSessionID > 0, userID > 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: AnyLifecycleCodingKey(
                    CodingKeys.auditSessionID.rawValue
                ),
                in: container,
                debugDescription: "Unsafe lifecycle lease identity"
            )
        }
        try self.init(
            investigationID: investigationID,
            bootSessionID: bootSessionID,
            auditSessionID: auditSessionID,
            userID: userID
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(
            keyedBy: AnyLifecycleCodingKey.self
        )
        try container.encode(
            1,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.protocolVersion.rawValue
            )
        )
        try container.encode(
            investigationID,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.investigationID.rawValue
            )
        )
        try container.encode(
            bootSessionID,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.bootSessionID.rawValue
            )
        )
        try container.encode(
            auditSessionID,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.auditSessionID.rawValue
            )
        )
        try container.encode(
            userID,
            forKey: AnyLifecycleCodingKey(CodingKeys.userID.rawValue)
        )
    }
}

public enum LifecycleLeaseRecoveryDecision: Sendable, Equatable {
    case drain(auditSessionID: Int32, userID: uid_t)
    case retireAfterReboot
}

public struct LifecycleLeaseRecoveryPlanner: Sendable {
    public let currentBootSessionID: LifecycleBootSessionID

    public init(currentBootSessionID: LifecycleBootSessionID) {
        self.currentBootSessionID = currentBootSessionID
    }

    public func decision(
        for lease: LifecycleInvestigationLease
    ) -> LifecycleLeaseRecoveryDecision {
        guard lease.bootSessionID == currentBootSessionID else {
            return .retireAfterReboot
        }
        return .drain(
            auditSessionID: lease.auditSessionID,
            userID: lease.userID
        )
    }
}

public enum LifecycleLeaseStoreError:
    Error,
    Sendable,
    Equatable
{
    case invalidRoot
    case invalidFile
    case invalidMode
    case invalidOwner
    case invalidLease
    case unknownEntry
    case alreadyExists
    case writeFailed
    case removeFailed
}

public struct LifecycleLeaseStore: Sendable {
    private let rootURL: URL
    private let requiredOwnerUserID: uid_t

    public init(
        rootURL: URL,
        requiredOwnerUserID: uid_t = 0
    ) throws {
        guard
            rootURL.isFileURL,
            rootURL.path.hasPrefix("/"),
            let canonicalRoot = canonicalDirectory(rootURL),
            canonicalRoot.path == rootURL.standardizedFileURL.path,
            validDirectory(
                canonicalRoot,
                ownerUserID: requiredOwnerUserID,
                mode: 0o700
            )
        else {
            throw LifecycleLeaseStoreError.invalidRoot
        }
        self.rootURL = canonicalRoot
        self.requiredOwnerUserID = requiredOwnerUserID
    }

    public func create(
        _ lease: LifecycleInvestigationLease
    ) throws -> URL {
        guard lease.auditSessionID > 0, lease.userID > 0 else {
            throw LifecycleLeaseStoreError.invalidLease
        }
        try validateRoot()
        let destination = leaseURL(for: lease.investigationID)
        let descriptor = open(
            destination.path,
            O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
            0o600
        )
        guard descriptor >= 0 else {
            if errno == EEXIST {
                throw LifecycleLeaseStoreError.alreadyExists
            }
            throw LifecycleLeaseStoreError.writeFailed
        }
        var shouldRemove = true
        defer {
            close(descriptor)
            if shouldRemove {
                unlink(destination.path)
            }
        }
        let data: Data
        do {
            data = try JSONEncoder().encode(lease)
        } catch {
            throw LifecycleLeaseStoreError.invalidLease
        }
        guard writeAll(data, to: descriptor), fsync(descriptor) == 0 else {
            throw LifecycleLeaseStoreError.writeFailed
        }
        var information = stat()
        guard
            fstat(descriptor, &information) == 0,
            information.st_mode & S_IFMT == S_IFREG,
            information.st_uid == requiredOwnerUserID,
            information.st_mode & 0o777 == 0o600,
            information.st_nlink == 1,
            information.st_size == data.count
        else {
            throw LifecycleLeaseStoreError.writeFailed
        }
        shouldRemove = false
        do {
            try synchronizeRootDirectory()
        } catch {
            shouldRemove = true
            throw error
        }
        return destination
    }

    public func readAll() throws -> [LifecycleInvestigationLease] {
        try validateRoot()
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: nil,
                options: []
            )
        } catch {
            throw LifecycleLeaseStoreError.invalidRoot
        }
        var leases: [LifecycleInvestigationLease] = []
        for url in contents.sorted(by: { $0.path < $1.path }) {
            guard
                url.pathExtension == "lease",
                UUID(uuidString: url.deletingPathExtension()
                    .lastPathComponent) != nil
            else {
                throw LifecycleLeaseStoreError.unknownEntry
            }
            leases.append(try readLease(from: url))
        }
        return leases
    }

    @discardableResult
    public func remove(
        _ investigationID: LifecycleInvestigationID
    ) throws -> URL {
        try validateRoot()
        let url = leaseURL(for: investigationID)
        _ = try readLease(from: url)
        guard unlink(url.path) == 0 else {
            throw LifecycleLeaseStoreError.removeFailed
        }
        try synchronizeRootDirectory()
        return url
    }

    private func readLease(
        from url: URL
    ) throws -> LifecycleInvestigationLease {
        let descriptor = open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else {
            throw LifecycleLeaseStoreError.invalidFile
        }
        defer { close(descriptor) }
        var information = stat()
        guard
            fstat(descriptor, &information) == 0,
            information.st_mode & S_IFMT == S_IFREG
        else {
            throw LifecycleLeaseStoreError.invalidFile
        }
        guard information.st_uid == requiredOwnerUserID else {
            throw LifecycleLeaseStoreError.invalidOwner
        }
        guard information.st_mode & 0o777 == 0o600 else {
            throw LifecycleLeaseStoreError.invalidMode
        }
        guard information.st_nlink == 1 else {
            throw LifecycleLeaseStoreError.invalidFile
        }
        guard information.st_size >= 0, information.st_size <= 4_096 else {
            throw LifecycleLeaseStoreError.invalidLease
        }
        let data = readBounded(
            descriptor: descriptor,
            maximumBytes: 4_096
        )
        guard let data else {
            throw LifecycleLeaseStoreError.invalidLease
        }
        var finalInformation = stat()
        guard
            fstat(descriptor, &finalInformation) == 0,
            finalInformation.st_dev == information.st_dev,
            finalInformation.st_ino == information.st_ino,
            finalInformation.st_size == information.st_size,
            finalInformation.st_mtimespec.tv_sec
                == information.st_mtimespec.tv_sec,
            finalInformation.st_mtimespec.tv_nsec
                == information.st_mtimespec.tv_nsec
        else {
            throw LifecycleLeaseStoreError.invalidLease
        }
        let lease: LifecycleInvestigationLease
        do {
            lease = try JSONDecoder().decode(
                LifecycleInvestigationLease.self,
                from: data
            )
        } catch {
            throw LifecycleLeaseStoreError.invalidLease
        }
        guard
            leaseURL(for: lease.investigationID).standardizedFileURL.path
                == url.standardizedFileURL.path
        else {
            throw LifecycleLeaseStoreError.invalidLease
        }
        return lease
    }

    private func validateRoot() throws {
        guard validDirectory(
            rootURL,
            ownerUserID: requiredOwnerUserID,
            mode: 0o700
        ) else {
            throw LifecycleLeaseStoreError.invalidRoot
        }
    }

    private func leaseURL(
        for investigationID: LifecycleInvestigationID
    ) -> URL {
        rootURL.appending(
            path: "\(investigationID.rawValue.uuidString.lowercased()).lease"
        )
    }

    private func synchronizeRootDirectory() throws {
        let descriptor = open(
            rootURL.path,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard descriptor >= 0 else {
            throw LifecycleLeaseStoreError.invalidRoot
        }
        defer { close(descriptor) }
        guard fsync(descriptor) == 0 else {
            throw LifecycleLeaseStoreError.writeFailed
        }
    }
}

private func canonicalDirectory(_ url: URL) -> URL? {
    guard let pointer = realpath(url.path, nil) else { return nil }
    defer { free(pointer) }
    return URL(
        filePath: String(cString: pointer),
        directoryHint: .isDirectory
    ).standardizedFileURL
}

private func validDirectory(
    _ url: URL,
    ownerUserID: uid_t,
    mode: mode_t
) -> Bool {
    var information = stat()
    return lstat(url.path, &information) == 0
        && information.st_mode & S_IFMT == S_IFDIR
        && information.st_uid == ownerUserID
        && information.st_mode & 0o777 == mode
}

private func writeAll(_ data: Data, to descriptor: Int32) -> Bool {
    data.withUnsafeBytes { bytes in
        guard let base = bytes.baseAddress else { return true }
        var offset = 0
        while offset < bytes.count {
            let count = Darwin.write(
                descriptor,
                base.advanced(by: offset),
                bytes.count - offset
            )
            if count < 0 {
                if errno == EINTR { continue }
                return false
            }
            offset += count
        }
        return true
    }
}

private func readBounded(
    descriptor: Int32,
    maximumBytes: Int
) -> Data? {
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1_024)
    while true {
        let count = Darwin.read(descriptor, &buffer, buffer.count)
        if count == 0 { return data }
        if count < 0 {
            if errno == EINTR { continue }
            return nil
        }
        guard data.count + count <= maximumBytes else {
            return nil
        }
        data.append(contentsOf: buffer.prefix(count))
    }
}
