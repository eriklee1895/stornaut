import Darwin
import Foundation
import StornautInvestigationHandoffContract

package enum InvestigationMachineFixedCapsuleIntakeError:
    Error,
    Sendable,
    Equatable
{
    case invalidStandardInput
    case invalidCapsule
    case exhausted
}

struct InvestigationMachineFixedCapsuleSystemError:
    Error,
    Sendable,
    Equatable
{
    let errno: Int32
}

struct InvestigationMachineFixedCapsuleDescriptorSnapshot:
    Sendable,
    Equatable
{
    let deviceID: UInt64
    let inode: UInt64
    let generation: UInt32
    let isRegularFile: Bool
    let ownerUserID: uid_t
    let ownerGroupID: gid_t
    let mode: mode_t
    let linkCount: UInt64
    let size: Int64
    let flags: UInt32
    let modificationSeconds: Int64
    let modificationNanoseconds: Int64
    let statusChangeSeconds: Int64
    let statusChangeNanoseconds: Int64
}

protocol InvestigationMachineFixedCapsuleSystem: Sendable {
    func descriptorFlags(_ descriptor: Int32)
        -> Result<Int32, InvestigationMachineFixedCapsuleSystemError>
    func descriptorStatusFlags(_ descriptor: Int32)
        -> Result<Int32, InvestigationMachineFixedCapsuleSystemError>
    func setDescriptorFlags(_ descriptor: Int32, flags: Int32)
        -> Result<Void, InvestigationMachineFixedCapsuleSystemError>
    func offset(_ descriptor: Int32)
        -> Result<Int64, InvestigationMachineFixedCapsuleSystemError>
    func snapshot(_ descriptor: Int32)
        -> Result<
            InvestigationMachineFixedCapsuleDescriptorSnapshot,
            InvestigationMachineFixedCapsuleSystemError
        >
    func hasExtendedACL(_ descriptor: Int32)
        -> Result<Bool, InvestigationMachineFixedCapsuleSystemError>
    func hasExtendedAttributes(_ descriptor: Int32)
        -> Result<Bool, InvestigationMachineFixedCapsuleSystemError>
    func read(_ descriptor: Int32, maximumByteCount: Int)
        -> Result<Data, InvestigationMachineFixedCapsuleSystemError>
}

package struct InvestigationMachineFixedEpochSelection:
    Sendable,
    Equatable
{
    package let outerAttemptUUID: UUID
    package let wholeCapsuleSHA256: InvestigationHandoffSHA256
    package let epoch: InvestigationCohortEpoch
}

package actor InvestigationMachineFixedEpochPlan {
    private let outerAttemptUUID: UUID
    private let wholeCapsuleSHA256: InvestigationHandoffSHA256
    private let epochs: [InvestigationCohortEpoch]
    private var nextIndex = 0

    init(capsule: InvestigationCohortCapsule) {
        outerAttemptUUID = capsule.outerAttemptUUID
        wholeCapsuleSHA256 = capsule.wholeCapsuleSHA256
        epochs = capsule.epochs
    }

    package func takeNext() throws
        -> InvestigationMachineFixedEpochSelection
    {
        guard nextIndex < epochs.count else {
            throw InvestigationMachineFixedCapsuleIntakeError.exhausted
        }
        let epoch = epochs[nextIndex]
        guard
            epoch.ordinal == UInt32(nextIndex),
            epoch.scenario.rawValue == epoch.ordinal + 1
        else {
            throw InvestigationMachineFixedCapsuleIntakeError.invalidCapsule
        }
        nextIndex += 1
        return InvestigationMachineFixedEpochSelection(
            outerAttemptUUID: outerAttemptUUID,
            wholeCapsuleSHA256: wholeCapsuleSHA256,
            epoch: epoch
        )
    }
}

package struct InvestigationMachineFixedCapsuleIntake: Sendable {
    static let requiredOwnerUserID: uid_t = 501
    private static let readChunkByteCount = 16 * 1_024
    fileprivate static let maximumExtendedAttributeListBytes = 4 * 1_024

    private let system: any InvestigationMachineFixedCapsuleSystem

    package init() {
        system = DarwinInvestigationMachineFixedCapsuleSystem()
    }

    init(system: any InvestigationMachineFixedCapsuleSystem) {
        self.system = system
    }

    package func read() throws -> InvestigationMachineFixedEpochPlan {
        let descriptor = STDIN_FILENO
        guard try value(system.offset(descriptor)) == 0 else {
            throw InvestigationMachineFixedCapsuleIntakeError
                .invalidStandardInput
        }
        let initialFlags = try value(system.descriptorFlags(descriptor))
        try success(system.setDescriptorFlags(
            descriptor,
            flags: initialFlags | FD_CLOEXEC
        ))
        guard
            try value(system.descriptorFlags(descriptor)) & FD_CLOEXEC
                == FD_CLOEXEC,
            try value(system.descriptorStatusFlags(descriptor)) & O_ACCMODE
                == O_RDONLY
        else {
            throw InvestigationMachineFixedCapsuleIntakeError
                .invalidStandardInput
        }

        let initial = try value(system.snapshot(descriptor))
        guard Self.valid(initial) else {
            throw InvestigationMachineFixedCapsuleIntakeError
                .invalidStandardInput
        }
        guard
            try !value(system.hasExtendedACL(descriptor)),
            try !value(system.hasExtendedAttributes(descriptor)),
            let expectedByteCount = Int(exactly: initial.size)
        else {
            throw InvestigationMachineFixedCapsuleIntakeError
                .invalidStandardInput
        }

        var encoded = Data()
        encoded.reserveCapacity(expectedByteCount)
        while encoded.count < expectedByteCount {
            let requested = min(
                Self.readChunkByteCount,
                expectedByteCount - encoded.count
            )
            let chunk: Data
            switch system.read(
                descriptor,
                maximumByteCount: requested
            ) {
            case .failure(let error) where error.errno == EINTR:
                continue
            case .failure:
                throw InvestigationMachineFixedCapsuleIntakeError
                    .invalidStandardInput
            case .success(let value):
                chunk = value
            }
            guard !chunk.isEmpty, chunk.count <= requested else {
                throw InvestigationMachineFixedCapsuleIntakeError
                    .invalidStandardInput
            }
            encoded.append(chunk)
        }
        let trailing = try readTrailingByte(descriptor)
        guard trailing.isEmpty else {
            throw InvestigationMachineFixedCapsuleIntakeError
                .invalidStandardInput
        }
        return try finish(
            descriptor: descriptor,
            encoded: encoded,
            initial: initial
        )
    }

    private func readTrailingByte(_ descriptor: Int32) throws -> Data {
        while true {
            switch system.read(descriptor, maximumByteCount: 1) {
            case .failure(let error) where error.errno == EINTR:
                continue
            case .failure:
                throw InvestigationMachineFixedCapsuleIntakeError
                    .invalidStandardInput
            case .success(let trailing):
                return trailing
            }
        }
    }

    private func finish(
        descriptor: Int32,
        encoded: Data,
        initial: InvestigationMachineFixedCapsuleDescriptorSnapshot
    ) throws -> InvestigationMachineFixedEpochPlan {
        guard
            try value(system.offset(descriptor)) == Int64(encoded.count),
            try value(system.descriptorFlags(descriptor)) & FD_CLOEXEC
                == FD_CLOEXEC,
            try value(system.descriptorStatusFlags(descriptor)) & O_ACCMODE
                == O_RDONLY,
            try value(system.snapshot(descriptor)) == initial,
            try !value(system.hasExtendedACL(descriptor)),
            try !value(system.hasExtendedAttributes(descriptor))
        else {
            throw InvestigationMachineFixedCapsuleIntakeError
                .invalidStandardInput
        }
        do {
            return InvestigationMachineFixedEpochPlan(
                capsule: try InvestigationCohortCapsule.decode(encoded)
            )
        } catch {
            throw InvestigationMachineFixedCapsuleIntakeError.invalidCapsule
        }
    }

    private static func valid(
        _ snapshot: InvestigationMachineFixedCapsuleDescriptorSnapshot
    ) -> Bool {
        snapshot.deviceID > 0
            && snapshot.inode > 0
            && snapshot.isRegularFile
            && snapshot.ownerUserID == requiredOwnerUserID
            && snapshot.mode == 0o600
            && snapshot.linkCount == 1
            && snapshot.size > 0
            && snapshot.size <= InvestigationCohortCapsule.maximumByteCount
            && snapshot.flags == 0
    }

    private func value<Value>(
        _ result: Result<
            Value,
            InvestigationMachineFixedCapsuleSystemError
        >
    ) throws -> Value {
        do {
            return try result.get()
        } catch {
            throw InvestigationMachineFixedCapsuleIntakeError
                .invalidStandardInput
        }
    }

    private func success(
        _ result: Result<
            Void,
            InvestigationMachineFixedCapsuleSystemError
        >
    ) throws {
        _ = try value(result)
    }
}

struct DarwinInvestigationMachineFixedCapsuleSystem:
    InvestigationMachineFixedCapsuleSystem,
    Sendable
{
    func descriptorFlags(_ descriptor: Int32)
        -> Result<Int32, InvestigationMachineFixedCapsuleSystemError>
    {
        let flags = fcntl(descriptor, F_GETFD)
        guard flags >= 0 else { return .failure(.init(errno: Darwin.errno)) }
        return .success(flags)
    }

    func descriptorStatusFlags(_ descriptor: Int32)
        -> Result<Int32, InvestigationMachineFixedCapsuleSystemError>
    {
        let flags = fcntl(descriptor, F_GETFL)
        guard flags >= 0 else { return .failure(.init(errno: Darwin.errno)) }
        return .success(flags)
    }

    func setDescriptorFlags(_ descriptor: Int32, flags: Int32)
        -> Result<Void, InvestigationMachineFixedCapsuleSystemError>
    {
        guard fcntl(descriptor, F_SETFD, flags) == 0 else {
            return .failure(.init(errno: Darwin.errno))
        }
        return .success(())
    }

    func offset(_ descriptor: Int32)
        -> Result<Int64, InvestigationMachineFixedCapsuleSystemError>
    {
        let value = lseek(descriptor, 0, SEEK_CUR)
        guard value >= 0 else { return .failure(.init(errno: Darwin.errno)) }
        return .success(Int64(value))
    }

    func snapshot(_ descriptor: Int32)
        -> Result<
            InvestigationMachineFixedCapsuleDescriptorSnapshot,
            InvestigationMachineFixedCapsuleSystemError
        >
    {
        var status = stat()
        guard fstat(descriptor, &status) == 0 else {
            return .failure(.init(errno: Darwin.errno))
        }
        return .success(.init(
            deviceID: UInt64(status.st_dev),
            inode: UInt64(status.st_ino),
            generation: status.st_gen,
            isRegularFile: status.st_mode & S_IFMT == S_IFREG,
            ownerUserID: status.st_uid,
            ownerGroupID: status.st_gid,
            mode: status.st_mode & 0o7777,
            linkCount: UInt64(status.st_nlink),
            size: status.st_size,
            flags: status.st_flags,
            modificationSeconds: Int64(status.st_mtimespec.tv_sec),
            modificationNanoseconds: Int64(status.st_mtimespec.tv_nsec),
            statusChangeSeconds: Int64(status.st_ctimespec.tv_sec),
            statusChangeNanoseconds: Int64(status.st_ctimespec.tv_nsec)
        ))
    }

    func hasExtendedACL(_ descriptor: Int32)
        -> Result<Bool, InvestigationMachineFixedCapsuleSystemError>
    {
        Darwin.errno = 0
        guard let acl = acl_get_fd_np(descriptor, ACL_TYPE_EXTENDED) else {
            return Darwin.errno == ENOENT
                ? .success(false)
                : .failure(.init(errno: Darwin.errno))
        }
        defer { acl_free(UnsafeMutableRawPointer(acl)) }
        var entry: acl_entry_t?
        let result = acl_get_entry(
            acl,
            Int32(ACL_FIRST_ENTRY.rawValue),
            &entry
        )
        guard result >= 0 else {
            return .failure(.init(errno: Darwin.errno))
        }
        return .success(result == 0)
    }

    func hasExtendedAttributes(_ descriptor: Int32)
        -> Result<Bool, InvestigationMachineFixedCapsuleSystemError>
    {
        let count = flistxattr(descriptor, nil, 0, 0)
        guard
            count >= 0,
            count <= InvestigationMachineFixedCapsuleIntake
                .maximumExtendedAttributeListBytes
        else {
            return .failure(.init(errno: Darwin.errno))
        }
        return .success(count > 0)
    }

    func read(_ descriptor: Int32, maximumByteCount: Int)
        -> Result<Data, InvestigationMachineFixedCapsuleSystemError>
    {
        guard maximumByteCount > 0 else {
            return .failure(.init(errno: EINVAL))
        }
        var bytes = [UInt8](repeating: 0, count: maximumByteCount)
        let count = bytes.withUnsafeMutableBytes { buffer in
            Darwin.read(descriptor, buffer.baseAddress, buffer.count)
        }
        guard count >= 0 else {
            return .failure(.init(errno: Darwin.errno))
        }
        return .success(Data(bytes.prefix(count)))
    }
}
