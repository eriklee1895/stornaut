import Darwin
import Foundation

#if DEBUG
enum InvestigationMachineGateOwnershipError: Error, Equatable, Sendable {
    case activeAttempt
    case identityUnavailable
    case ownershipUncertain
    case alreadyReleased
}

enum InvestigationMachineGateSystemError: Error, Equatable, Sendable {
    case errno(Int32)
}

enum InvestigationMachineGateFileType: Equatable, Sendable {
    case directory
    case regularFile
    case other
}

protocol InvestigationMachineGateOwnershipMutex: AnyObject, Sendable {
    func lock(); func unlock()
}

struct InvestigationMachineGateIdentitySnapshot: Equatable, Sendable {
    let realUID: uid_t
    let effectiveUID: uid_t
    let accountUID: uid_t
    let realGID: gid_t
    let effectiveGID: gid_t
    let accountGID: gid_t
    let homePath: String
}

struct InvestigationMachineGateMetadataSnapshot: Equatable, Sendable {
    let device: UInt64
    let inode: UInt64
    let generation: UInt64
    let fileType: InvestigationMachineGateFileType
    let ownerUID: uid_t
    let ownerGID: gid_t
    let permissions: mode_t
    let linkCount: UInt64
    let size: Int64
    let flags: UInt32
}

protocol InvestigationMachineGateOwnershipSystem: AnyObject, Sendable {
    func identitySnapshot(bufferByteCount: Int) throws
        -> InvestigationMachineGateIdentitySnapshot
    func createDirectory(
        parentDescriptor: Int32, name: String, mode: mode_t
    ) throws
    func openComponent(
        parentDescriptor: Int32?,
        name: String,
        flags: Int32,
        mode: mode_t?
    ) throws -> Int32
    func metadata(descriptor: Int32) throws
        -> InvestigationMachineGateMetadataSnapshot
    func namedMetadata(
        parentDescriptor: Int32,
        name: String,
        flags: Int32
    ) throws -> InvestigationMachineGateMetadataSnapshot
    func descriptorFlags(_ descriptor: Int32) throws -> Int32
    func descriptorStatusFlags(_ descriptor: Int32) throws -> Int32
    func setPermissions(descriptor: Int32, mode: mode_t) throws
    func extendedACLIsEmpty(descriptor: Int32) throws -> Bool
    func extendedAttributeNames(descriptor: Int32) throws -> [String]
    func acquireExclusiveNonblockingLock(descriptor: Int32) throws
    func close(descriptor: Int32) throws
    func makeOwnershipMutex() -> any InvestigationMachineGateOwnershipMutex
}

struct InvestigationMachineGateOwnershipAcquirer: Sendable {
    static let targetUID: uid_t = 501
    static let targetGID: gid_t = 20
    static let baseName = "com.eriklee.stornaut.task39-machine-gate"
    static let lockName = ".owner-lock-v1"
    private static let identityBufferByteCounts = [
        1_024, 2_048, 4_096, 8_192, 16_384, 32_768, 65_536,
    ]
    private static let directoryFlags = Int32(
        O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NONBLOCK | O_NOFOLLOW_ANY
    )
    private static let relativeDirectoryFlags = Int32(
        directoryFlags | O_RESOLVE_BENEATH
    )
    private static let lockFlags = Int32(
        O_RDWR | O_CLOEXEC | O_NONBLOCK | O_NOFOLLOW_ANY
            | O_RESOLVE_BENEATH | O_UNIQUE
    )
    private static let directoryNamedFlags = Int32(
        AT_SYMLINK_NOFOLLOW_ANY | AT_RESOLVE_BENEATH | AT_UNIQUE
    )
    private static let lockNamedFlags = Int32(
        directoryNamedFlags | AT_UNIQUE
    )

    private let system: any InvestigationMachineGateOwnershipSystem

    init() {
        system = DarwinInvestigationMachineGateOwnershipSystem()
    }

    init(system: any InvestigationMachineGateOwnershipSystem) {
        self.system = system
    }

    func acquire() throws -> InvestigationMachineGateOwnership {
        let identity = try resolvedIdentity()
        let homeComponents = try canonicalHomeComponents(identity.homePath)
        var ledger = InvestigationMachineGateDescriptorLedger()
        var transferredLock: Int32?
        do {
            let root = try opened(
                parent: nil, name: "/", flags: Self.directoryFlags,
                mode: nil, accessMode: O_RDONLY, ledger: &ledger
            )
            try requireDirectory(try system.metadata(descriptor: root))
            var parent = root
            for component in homeComponents + ["Library", "Caches"] {
                parent = try opened(
                    parent: parent, name: component,
                    flags: Self.relativeDirectoryFlags, mode: nil,
                    accessMode: O_RDONLY, ledger: &ledger
                )
                try requireDirectory(try system.metadata(descriptor: parent))
            }
            let caches = parent
            let baseRelativePath = (
                homeComponents + ["Library", "Caches", Self.baseName]
            ).joined(separator: "/")
            let base = try openBase(parent: caches, ledger: &ledger)
            let initialBase = try baseSnapshot(
                base, root: root, relativePath: baseRelativePath
            )
            let lock = try openLock(parent: base, ledger: &ledger)
            let initialLock = try lockSnapshot(
                lock, parent: base, baseDevice: initialBase.device
            )
            do {
                try system.acquireExclusiveNonblockingLock(descriptor: lock)
            } catch InvestigationMachineGateSystemError.errno(let value)
                where value == EWOULDBLOCK || value == EAGAIN
            {
                throw InvestigationMachineGateOwnershipError.activeAttempt
            } catch {
                throw InvestigationMachineGateOwnershipError.ownershipUncertain
            }
            guard
                try baseSnapshot(
                    base, root: root, relativePath: baseRelativePath
                ) == initialBase,
                try lockSnapshot(
                    lock, parent: base, baseDevice: initialBase.device
                ) == initialLock
            else {
                throw InvestigationMachineGateOwnershipError.ownershipUncertain
            }
            try requireDescriptorState(base, accessMode: O_RDONLY)
            try requireDescriptorState(lock, accessMode: O_RDWR)
            guard ledger.transfer(lock) else {
                throw InvestigationMachineGateOwnershipError.ownershipUncertain
            }
            transferredLock = lock
            guard ledger.closeAll(using: system) else {
                throw InvestigationMachineGateOwnershipError.ownershipUncertain
            }
            return InvestigationMachineGateOwnership(system: system, descriptor: lock,
                mutex: system.makeOwnershipMutex())
        } catch {
            let cleanupSucceeded = ledger.closeAll(using: system)
            if let transferredLock { try? system.close(descriptor: transferredLock) }
            guard cleanupSucceeded else {
                throw InvestigationMachineGateOwnershipError.ownershipUncertain
            }
            if let error = error as? InvestigationMachineGateOwnershipError {
                throw error
            }
            throw InvestigationMachineGateOwnershipError.ownershipUncertain
        }
    }

    private func resolvedIdentity() throws
        -> InvestigationMachineGateIdentitySnapshot
    {
        for byteCount in Self.identityBufferByteCounts {
            do {
                let value = try system.identitySnapshot(
                    bufferByteCount: byteCount
                )
                guard
                    value.realUID == Self.targetUID,
                    value.effectiveUID == Self.targetUID,
                    value.accountUID == Self.targetUID,
                    value.realGID == Self.targetGID,
                    value.effectiveGID == Self.targetGID,
                    value.accountGID == Self.targetGID
                else {
                    throw InvestigationMachineGateOwnershipError
                        .identityUnavailable
                }
                return value
            } catch InvestigationMachineGateSystemError.errno(let value)
                where value == ERANGE
            {
                continue
            } catch let error as InvestigationMachineGateOwnershipError {
                throw error
            } catch {
                throw InvestigationMachineGateOwnershipError.identityUnavailable
            }
        }
        throw InvestigationMachineGateOwnershipError.identityUnavailable
    }

    private func canonicalHomeComponents(_ path: String) throws -> [String] {
        guard
            path.first == "/", path.count > 1,
            !path.hasSuffix("/"), !path.contains("\0"),
            path.utf8.count < Int(MAXPATHLEN)
        else {
            throw InvestigationMachineGateOwnershipError.identityUnavailable
        }
        let components = path.split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        guard
            !components.isEmpty,
            components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
            "/" + components.joined(separator: "/") == path
        else {
            throw InvestigationMachineGateOwnershipError.identityUnavailable
        }
        return components
    }

    private func opened(
        parent: Int32?, name: String, flags: Int32, mode: mode_t?,
        accessMode: Int32, ledger: inout InvestigationMachineGateDescriptorLedger
    ) throws -> Int32 {
        let descriptor = try system.openComponent(
            parentDescriptor: parent, name: name, flags: flags, mode: mode
        )
        guard descriptor >= 0, ledger.register(descriptor) else {
            throw InvestigationMachineGateOwnershipError.ownershipUncertain
        }
        try requireDescriptorState(descriptor, accessMode: accessMode)
        return descriptor
    }

    private func openBase(
        parent: Int32, ledger: inout InvestigationMachineGateDescriptorLedger
    ) throws -> Int32 {
        do {
            try system.createDirectory(
                parentDescriptor: parent, name: Self.baseName, mode: 0o700
            )
        } catch InvestigationMachineGateSystemError.errno(let value)
            where value == EEXIST
        {} catch {
            throw InvestigationMachineGateOwnershipError.ownershipUncertain
        }
        return try opened(
            parent: parent, name: Self.baseName,
            flags: Self.relativeDirectoryFlags, mode: nil,
            accessMode: O_RDONLY, ledger: &ledger
        )
    }

    private func openLock(
        parent: Int32, ledger: inout InvestigationMachineGateDescriptorLedger
    ) throws -> Int32 {
        let descriptor: Int32
        do {
            descriptor = try system.openComponent(
                parentDescriptor: parent, name: Self.lockName,
                flags: Self.lockFlags | O_CREAT | O_EXCL, mode: 0o600
            )
        } catch InvestigationMachineGateSystemError.errno(let value)
            where value == EEXIST
        {
            return try opened(
                parent: parent, name: Self.lockName, flags: Self.lockFlags,
                mode: nil, accessMode: O_RDWR, ledger: &ledger
            )
        } catch {
            throw InvestigationMachineGateOwnershipError.ownershipUncertain
        }
        guard descriptor >= 0, ledger.register(descriptor) else {
            throw InvestigationMachineGateOwnershipError.ownershipUncertain
        }
        do { try system.setPermissions(descriptor: descriptor, mode: 0o600) }
        catch { throw InvestigationMachineGateOwnershipError.ownershipUncertain }
        try requireDescriptorState(descriptor, accessMode: O_RDWR)
        return descriptor
    }

    private func requireDescriptorState(
        _ descriptor: Int32, accessMode: Int32
    ) throws {
        let descriptorFlags = try system.descriptorFlags(descriptor)
        let statusFlags = try system.descriptorStatusFlags(descriptor)
        guard
            descriptorFlags & FD_CLOEXEC == FD_CLOEXEC,
            statusFlags & O_NONBLOCK == O_NONBLOCK,
            statusFlags & O_ACCMODE == accessMode
        else {
            throw InvestigationMachineGateOwnershipError.ownershipUncertain
        }
    }

    private func requireDirectory(
        _ value: InvestigationMachineGateMetadataSnapshot
    ) throws {
        guard value.device > 0, value.inode > 0, value.fileType == .directory
        else {
            throw InvestigationMachineGateOwnershipError.ownershipUncertain
        }
    }

    private func baseSnapshot(
        _ descriptor: Int32, root: Int32, relativePath: String
    ) throws -> InvestigationMachineGateMetadataSnapshot {
        let held = try system.metadata(descriptor: descriptor)
        let named = try system.namedMetadata(
            parentDescriptor: root, name: relativePath,
            flags: Self.directoryNamedFlags
        )
        guard
            held == named, held.device > 0, held.inode > 0,
            held.fileType == .directory, held.ownerUID == Self.targetUID,
            held.ownerGID == Self.targetGID, held.permissions == 0o700,
            held.flags == 0, try system.extendedACLIsEmpty(descriptor: descriptor),
            try system.extendedAttributeNames(descriptor: descriptor).isEmpty
        else {
            throw InvestigationMachineGateOwnershipError.ownershipUncertain
        }
        return held
    }

    private func lockSnapshot(
        _ descriptor: Int32, parent: Int32, baseDevice: UInt64
    ) throws -> InvestigationMachineGateMetadataSnapshot {
        let held = try system.metadata(descriptor: descriptor)
        let named = try system.namedMetadata(
            parentDescriptor: parent, name: Self.lockName,
            flags: Self.lockNamedFlags
        )
        guard
            held == named, held.device == baseDevice, held.inode > 0,
            held.fileType == .regularFile, held.ownerUID == Self.targetUID,
            held.ownerGID == Self.targetGID, held.permissions == 0o600,
            held.linkCount == 1, held.size == 0, held.flags == 0,
            try system.extendedACLIsEmpty(descriptor: descriptor),
            try system.extendedAttributeNames(descriptor: descriptor).isEmpty
        else {
            throw InvestigationMachineGateOwnershipError.ownershipUncertain
        }
        return held
    }
}

final class InvestigationMachineGateOwnership: @unchecked Sendable {
    private enum State { case active(Int32); case terminal }
    private let system: any InvestigationMachineGateOwnershipSystem
    private let lock: any InvestigationMachineGateOwnershipMutex
    private var state: State

    fileprivate init(
        system: any InvestigationMachineGateOwnershipSystem, descriptor: Int32,
        mutex: any InvestigationMachineGateOwnershipMutex
    ) {
        self.system = system
        lock = mutex
        state = .active(descriptor)
    }

    func release() throws {
        lock.lock()
        guard case .active(let descriptor) = state else {
            lock.unlock()
            throw InvestigationMachineGateOwnershipError.alreadyReleased
        }
        state = .terminal
        lock.unlock()
        do {
            try system.close(descriptor: descriptor)
        } catch {
            throw InvestigationMachineGateOwnershipError.ownershipUncertain
        }
    }

    func withExclusiveOwnership<T>(_ operation: () throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        guard case .active = state else {
            throw InvestigationMachineGateOwnershipError.alreadyReleased
        }
        return try operation()
    }

    deinit {
        lock.lock()
        let descriptor: Int32?
        if case .active(let value) = state {
            descriptor = value
            state = .terminal
        } else {
            descriptor = nil
        }
        lock.unlock()
        if let descriptor { try? system.close(descriptor: descriptor) }
    }
}

private struct InvestigationMachineGateDescriptorLedger {
    private var descriptors: [Int32] = []

    mutating func register(_ descriptor: Int32) -> Bool {
        guard !descriptors.contains(descriptor) else { return false }
        descriptors.append(descriptor)
        return true
    }

    mutating func transfer(_ descriptor: Int32) -> Bool {
        guard let index = descriptors.firstIndex(of: descriptor) else {
            return false
        }
        descriptors.remove(at: index)
        return true
    }

    mutating func closeAll(
        using system: any InvestigationMachineGateOwnershipSystem
    ) -> Bool {
        var succeeded = true
        while let descriptor = descriptors.popLast() {
            do { try system.close(descriptor: descriptor) }
            catch { succeeded = false }
        }
        return succeeded
    }
}

private final class DarwinInvestigationMachineGateOwnershipSystem:
    InvestigationMachineGateOwnershipSystem, @unchecked Sendable
{
    private static let maximumXattrBytes = 4 * 1_024

    func identitySnapshot(bufferByteCount: Int) throws
        -> InvestigationMachineGateIdentitySnapshot {
        var record = passwd()
        var result: UnsafeMutablePointer<passwd>?
        var buffer = [CChar](repeating: 0, count: bufferByteCount)
        let status = getpwuid_r(
            InvestigationMachineGateOwnershipAcquirer.targetUID, &record,
            &buffer, buffer.count, &result
        )
        guard status == 0 else {
            throw InvestigationMachineGateSystemError.errno(Int32(status))
        }
        guard
            result != nil,
            record.pw_uid == InvestigationMachineGateOwnershipAcquirer.targetUID,
            record.pw_gid == InvestigationMachineGateOwnershipAcquirer.targetGID,
            let home = record.pw_dir
        else {
            throw InvestigationMachineGateSystemError.errno(EINVAL)
        }
        return InvestigationMachineGateIdentitySnapshot(
            realUID: getuid(), effectiveUID: geteuid(),
            accountUID: record.pw_uid, realGID: getgid(),
            effectiveGID: getegid(), accountGID: record.pw_gid,
            homePath: String(cString: home)
        )
    }

    func openComponent(
        parentDescriptor: Int32?, name: String, flags: Int32, mode: mode_t?
    ) throws -> Int32 {
        let descriptor: Int32
        if let parentDescriptor {
            descriptor = mode.map { openat(parentDescriptor, name, flags, $0) }
                ?? openat(parentDescriptor, name, flags)
        } else {
            descriptor = mode.map { Darwin.open(name, flags, $0) }
                ?? Darwin.open(name, flags)
        }
        guard descriptor >= 0 else {
            throw InvestigationMachineGateSystemError.errno(Darwin.errno)
        }
        return descriptor
    }

    func createDirectory(
        parentDescriptor: Int32, name: String, mode: mode_t
    ) throws {
        guard mkdirat(parentDescriptor, name, mode) == 0 else {
            throw InvestigationMachineGateSystemError.errno(Darwin.errno)
        }
    }

    func metadata(descriptor: Int32) throws
        -> InvestigationMachineGateMetadataSnapshot {
        var value = stat()
        guard fstat(descriptor, &value) == 0 else {
            throw InvestigationMachineGateSystemError.errno(Darwin.errno)
        }
        return Self.snapshot(value)
    }

    func namedMetadata(
        parentDescriptor: Int32, name: String, flags: Int32
    ) throws -> InvestigationMachineGateMetadataSnapshot {
        var value = stat()
        guard fstatat(parentDescriptor, name, &value, flags) == 0 else {
            throw InvestigationMachineGateSystemError.errno(Darwin.errno)
        }
        return Self.snapshot(value)
    }

    func descriptorFlags(_ descriptor: Int32) throws -> Int32 {
        let value = fcntl(descriptor, F_GETFD)
        guard value >= 0 else {
            throw InvestigationMachineGateSystemError.errno(Darwin.errno)
        }
        return value
    }

    func descriptorStatusFlags(_ descriptor: Int32) throws -> Int32 {
        let value = fcntl(descriptor, F_GETFL)
        guard value >= 0 else {
            throw InvestigationMachineGateSystemError.errno(Darwin.errno)
        }
        return value
    }

    func setPermissions(descriptor: Int32, mode: mode_t) throws {
        guard fchmod(descriptor, mode) == 0 else {
            throw InvestigationMachineGateSystemError.errno(Darwin.errno)
        }
    }

    func extendedACLIsEmpty(descriptor: Int32) throws -> Bool {
        Darwin.errno = 0
        guard let acl = acl_get_fd_np(descriptor, ACL_TYPE_EXTENDED) else {
            if Darwin.errno == ENOENT { return true }
            throw InvestigationMachineGateSystemError.errno(Darwin.errno)
        }
        var entry: acl_entry_t?
        let result = acl_get_entry(
            acl, Int32(ACL_FIRST_ENTRY.rawValue), &entry
        )
        let entryError = Darwin.errno
        guard acl_free(UnsafeMutableRawPointer(acl)) == 0 else {
            throw InvestigationMachineGateSystemError.errno(Darwin.errno)
        }
        guard result >= 0 else {
            throw InvestigationMachineGateSystemError.errno(entryError)
        }
        return result != 0
    }

    func extendedAttributeNames(descriptor: Int32) throws -> [String] {
        let capacity = flistxattr(descriptor, nil, 0, 0)
        guard capacity >= 0, capacity <= Self.maximumXattrBytes else {
            throw InvestigationMachineGateSystemError.errno(
                capacity < 0 ? Darwin.errno : EOVERFLOW
            )
        }
        guard capacity > 0 else { return [] }
        var bytes = [UInt8](repeating: 0, count: capacity)
        let count = bytes.withUnsafeMutableBytes { buffer in
            flistxattr(
                descriptor,
                buffer.baseAddress?.assumingMemoryBound(to: CChar.self),
                buffer.count, 0
            )
        }
        guard count == capacity, bytes.last == 0 else {
            throw InvestigationMachineGateSystemError.errno(EIO)
        }
        return try bytes.split(separator: 0).map { raw in
            guard let value = String(bytes: raw, encoding: .utf8), !value.isEmpty
            else { throw InvestigationMachineGateSystemError.errno(EILSEQ) }
            return value
        }
    }

    func acquireExclusiveNonblockingLock(descriptor: Int32) throws {
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            throw InvestigationMachineGateSystemError.errno(Darwin.errno)
        }
    }

    func close(descriptor: Int32) throws {
        guard Darwin.close(descriptor) == 0 else {
            throw InvestigationMachineGateSystemError.errno(Darwin.errno)
        }
    }

    func makeOwnershipMutex() -> any InvestigationMachineGateOwnershipMutex { NSLock() }

    private static func snapshot(_ value: stat)
        -> InvestigationMachineGateMetadataSnapshot {
        let fileType: InvestigationMachineGateFileType = switch value.st_mode & S_IFMT {
        case S_IFDIR: .directory
        case S_IFREG: .regularFile
        default: .other
        }
        return InvestigationMachineGateMetadataSnapshot(
            device: UInt64(value.st_dev), inode: UInt64(value.st_ino),
            generation: UInt64(value.st_gen), fileType: fileType,
            ownerUID: value.st_uid, ownerGID: value.st_gid,
            permissions: value.st_mode & 0o7777,
            linkCount: UInt64(value.st_nlink), size: value.st_size,
            flags: value.st_flags
        )
    }
}
extension NSLock: InvestigationMachineGateOwnershipMutex {}
#endif
