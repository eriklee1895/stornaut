import Darwin
import Foundation
import StornautInvestigationHandoffContract

#if DEBUG
package enum InvestigationOwnerOnlyCapsuleResidue: Equatable, Sendable {
    case none
    case attemptDirectory(String)
    case pending(attempt: String, file: String)
    case published(attempt: String, file: String)
    case collision(
        attempt: String, pending: String?, final: String?,
        observed: [String], observationComplete: Bool
    )
}

package enum InvestigationOwnerOnlyCapsuleFailureStage: Equatable, Sendable {
    case inventory
    case createAttempt
    case openAttempt
    case validateAttempt
    case syncBase
    case createPending
    case writePending
    case validatePending
    case syncPending
    case publish
    case closePendingWriter
    case syncLeaf
    case reopenFinal
    case validateFinal
    case initialOffset
    case readFinal
    case endOfFile
    case contentDigest
    case finalOffset
    case closeAttemptDirectory
}

package enum InvestigationOwnerOnlyCapsuleCloseRole: Equatable, Sendable {
    case pendingWriter
    case finalReader
    case attemptDirectory
}

package enum InvestigationOwnerOnlyCapsuleError: Error, Equatable, Sendable {
    case invalidCapsule
    case activeAttempt
    case ownershipUncertain(InvestigationOwnerOnlyCapsuleResidue)
    case staleInventory([String])
    case attemptRootLimitExceeded
    case publicationFailed(
        stage: InvestigationOwnerOnlyCapsuleFailureStage,
        residue: InvestigationOwnerOnlyCapsuleResidue,
        closeFailures: [InvestigationOwnerOnlyCapsuleCloseRole]
    )
    case alreadyTerminal(InvestigationOwnerOnlyCapsuleResidue)
    case alreadyHandedOff(InvestigationOwnerOnlyCapsuleResidue)
    case fixedHandoffUnavailable(InvestigationOwnerOnlyCapsuleResidue)
    case handoffFailed(InvestigationOwnerOnlyCapsuleResidue)
    case capsuleCloseUncertain(
        InvestigationOwnerOnlyCapsuleResidue,
        ownershipReleaseUncertain: Bool
    )
    case ownershipReleaseUncertain(InvestigationOwnerOnlyCapsuleResidue)
}

enum InvestigationOwnerOnlyCapsuleSystemError: Error, Equatable, Sendable {
    case errno(Int32)
}

struct InvestigationOwnerOnlyCapsuleInventory: Equatable, Sendable {
    let entries: [String]
    let reachedEnd: Bool
}

package struct InvestigationOwnerOnlyCapsuleNodeIdentity: Equatable, Sendable {
    package let device: UInt64
    package let inode: UInt64
    package let generation: UInt64
    package let size: Int64
}

protocol InvestigationOwnerOnlyCapsuleSystem: AnyObject, Sendable {
    func inventory(
        baseDescriptor: Int32, maximumEntryCount: Int
    ) throws -> InvestigationOwnerOnlyCapsuleInventory
    func createDirectory(
        parentDescriptor: Int32, name: String, mode: mode_t
    ) throws
    func openComponent(
        parentDescriptor: Int32, name: String, flags: Int32, mode: mode_t?
    ) throws -> Int32
    func metadata(
        descriptor: Int32
    ) throws -> InvestigationMachineGateMetadataSnapshot
    func namedMetadata(
        parentDescriptor: Int32, name: String, flags: Int32
    ) throws -> InvestigationMachineGateMetadataSnapshot
    func descriptorFlags(_ descriptor: Int32) throws -> Int32
    func descriptorStatusFlags(_ descriptor: Int32) throws -> Int32
    func setPermissions(descriptor: Int32, mode: mode_t) throws
    func extendedACLIsEmpty(descriptor: Int32) throws -> Bool
    func extendedAttributeNames(descriptor: Int32) throws -> [String]
    func synchronize(descriptor: Int32) throws
    func write(
        descriptor: Int32, bytes: Data, offset: Int64
    ) throws -> Int
    func rename(
        parentDescriptor: Int32, oldName: String, newName: String,
        flags: Int32
    ) throws
    func offset(descriptor: Int32) throws -> Int64
    func read(
        descriptor: Int32, maximumByteCount: Int, offset: Int64
    ) throws -> Data
    func close(descriptor: Int32) throws
}

protocol InvestigationOwnerOnlyCapsuleBorrowing: AnyObject, Sendable {
    func handoffToFixedGate(
        descriptor: Int32, outerAttemptUUID: UUID,
        identity: InvestigationOwnerOnlyCapsuleNodeIdentity,
        digest: InvestigationHandoffSHA256
    ) throws -> InvestigationOwnerOnlyCapsuleExactGateReapedProof
}

package struct InvestigationOwnerOnlyCapsulePublisher: Sendable {
    private let acquirer: InvestigationMachineGateOwnershipAcquirer
    private let borrower: (any InvestigationOwnerOnlyCapsuleBorrowing)?

    package init() {
        acquirer = InvestigationMachineGateOwnershipAcquirer()
        borrower = nil
    }

    init(borrower: any InvestigationOwnerOnlyCapsuleBorrowing) {
        acquirer = InvestigationMachineGateOwnershipAcquirer()
        self.borrower = borrower
    }

    init(
        ownershipSystem: any InvestigationMachineGateOwnershipSystem,
        capsuleSystem: any InvestigationOwnerOnlyCapsuleSystem,
        borrower: (any InvestigationOwnerOnlyCapsuleBorrowing)? = nil
    ) {
        acquirer = InvestigationMachineGateOwnershipAcquirer(
            ownershipSystem: ownershipSystem, capsuleSystem: capsuleSystem
        )
        self.borrower = borrower
    }

    package func publish(_ bytes: Data) throws
        -> InvestigationOwnerOnlyCapsuleLease
    {
        let request = try InvestigationOwnerOnlyCapsulePublicationRequest(
            canonicalBytes: bytes
        )
        let owner: InvestigationMachineGateOwnership
        do {
            owner = try acquirer.acquire()
        } catch InvestigationMachineGateOwnershipError.activeAttempt {
            throw InvestigationOwnerOnlyCapsuleError.activeAttempt
        } catch {
            throw InvestigationOwnerOnlyCapsuleError.ownershipUncertain(.none)
        }
        return try owner.publishCanonicalCapsule(request, borrower: borrower)
    }
}

struct InvestigationOwnerOnlyCapsulePublicationRequest: Sendable {
    let canonicalBytes: Data
    let outerAttemptUUID: UUID
    let attemptName: String
    let finalName: String
    let wholeInputSHA256: InvestigationHandoffSHA256

    init(canonicalBytes: Data) throws {
        guard canonicalBytes.count <= InvestigationProjectedCohortInput.maximumByteCount
        else {
            throw InvestigationOwnerOnlyCapsuleError.invalidCapsule
        }
        do {
            let input = try InvestigationProjectedCohortInput.decode(
                canonicalBytes
            )
            guard try input.encoded() == canonicalBytes else {
                throw InvestigationOwnerOnlyCapsuleError.invalidCapsule
            }
            self.canonicalBytes = canonicalBytes
            outerAttemptUUID = input.capsule.outerAttemptUUID
            attemptName = "attempt-"
                + input.capsule.outerAttemptUUID.uuidString.lowercased()
            wholeInputSHA256 = input.wholeInputSHA256
            finalName = "projected-cohort-"
                + input.wholeInputSHA256.lowercaseHex + ".bin"
        } catch let error as InvestigationOwnerOnlyCapsuleError {
            throw error
        } catch {
            throw InvestigationOwnerOnlyCapsuleError.invalidCapsule
        }
    }
}

extension InvestigationOwnerOnlyCapsuleError {
    var residue: InvestigationOwnerOnlyCapsuleResidue {
        switch self {
        case .ownershipUncertain(let residue),
             .publicationFailed(_, let residue, _):
            residue
        case .invalidCapsule, .activeAttempt, .staleInventory,
             .attemptRootLimitExceeded:
            .none
        case .alreadyTerminal(let residue),
             .alreadyHandedOff(let residue),
             .fixedHandoffUnavailable(let residue),
             .handoffFailed(let residue),
             .ownershipReleaseUncertain(let residue):
            residue
        case .capsuleCloseUncertain(let residue, _):
            residue
        }
    }
}

enum InvestigationOwnerOnlyCapsulePublication {
    static let pendingName = "capsule.pending"
    static let maximumAttemptRootCount = 64
    static let maximumIOByteCount = 16 * 1_024
    static let maximumInterruptCount = 64
    static let attemptDirectoryFlags = Int32(
        O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NONBLOCK | O_NOFOLLOW_ANY
            | O_RESOLVE_BENEATH | O_UNIQUE
    )
    static let pendingWriterFlags = Int32(
        O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NONBLOCK
            | O_NOFOLLOW_ANY | O_RESOLVE_BENEATH | O_UNIQUE
    )
    static let finalReaderFlags = Int32(
        O_RDONLY | O_CLOEXEC | O_NONBLOCK | O_NOFOLLOW_ANY
            | O_RESOLVE_BENEATH | O_UNIQUE
    )
    static let namedFlags = Int32(
        AT_SYMLINK_NOFOLLOW_ANY | AT_RESOLVE_BENEATH | AT_UNIQUE
    )
    static let renameFlags = Int32(
        RENAME_EXCL | RENAME_NOFOLLOW_ANY | RENAME_RESOLVE_BENEATH
    )

    static func publish(
        _ request: InvestigationOwnerOnlyCapsulePublicationRequest,
        baseDescriptor: Int32,
        baseMetadata: InvestigationMachineGateMetadataSnapshot,
        system: any InvestigationOwnerOnlyCapsuleSystem
    ) throws -> InvestigationOwnerOnlyCapsuleVerifiedReader {
        var ledger = InvestigationOwnerOnlyCapsuleDescriptorLedger()
        var residue = InvestigationOwnerOnlyCapsuleResidue.none
        do {
            let inventory = try at(.inventory, residue: residue) {
                try system.inventory(
                    baseDescriptor: baseDescriptor,
                    maximumEntryCount: maximumAttemptRootCount + 2
                )
            }
            try validateInventory(inventory)

            do {
                try system.createDirectory(
                    parentDescriptor: baseDescriptor, name: request.attemptName,
                    mode: 0o700
                )
            } catch InvestigationOwnerOnlyCapsuleSystemError.errno(let value)
                where value == EEXIST
            {
                throw Failure(
                    stage: .createAttempt,
                    residue: collisionResidue(
                        parentDescriptor: baseDescriptor,
                        attempt: request.attemptName, pending: nil, final: nil,
                        candidateNames: [request.attemptName], system: system
                    )
                )
            } catch {
                throw Failure(stage: .createAttempt, residue: residue)
            }
            residue = .attemptDirectory(request.attemptName)
            let attempt = try at(.openAttempt, residue: residue) {
                try registeredOpen(
                    parent: baseDescriptor, name: request.attemptName,
                    flags: attemptDirectoryFlags, mode: nil,
                    role: .attemptDirectory, ledger: &ledger, system: system,
                    stage: .openAttempt, residue: residue
                )
            }
            try at(.validateAttempt, residue: residue) {
                try validateDirectory(
                    descriptor: attempt, parent: baseDescriptor,
                    name: request.attemptName, baseDevice: baseMetadata.device,
                    system: system
                )
            }
            try at(.syncBase, residue: residue) {
                try system.synchronize(descriptor: baseDescriptor)
            }

            let writer: Int32
            do {
                writer = try registeredOpen(
                    parent: attempt, name: pendingName,
                    flags: pendingWriterFlags, mode: 0o600,
                    role: .pendingWriter, ledger: &ledger, system: system,
                    stage: .createPending, residue: residue
                )
            } catch InvestigationOwnerOnlyCapsuleSystemError.errno(let value)
                where value == EEXIST
            {
                throw Failure(
                    stage: .createPending,
                    residue: collisionResidue(
                        parentDescriptor: attempt,
                        attempt: request.attemptName, pending: pendingName,
                        final: nil, candidateNames: [pendingName], system: system
                    )
                )
            } catch let failure as Failure {
                throw failure
            } catch {
                throw Failure(stage: .createPending, residue: residue)
            }
            residue = .pending(
                attempt: request.attemptName, file: pendingName
            )
            try at(.validatePending, residue: residue) {
                try system.setPermissions(descriptor: writer, mode: 0o600)
            }
            try at(.writePending, residue: residue) {
                try writeAll(
                    request.canonicalBytes, descriptor: writer, system: system
                )
            }
            let pendingMetadata = try at(.validatePending, residue: residue) {
                try validateFile(
                    descriptor: writer, parent: attempt, name: pendingName,
                    baseDevice: baseMetadata.device,
                    expectedSize: Int64(request.canonicalBytes.count),
                    accessMode: O_WRONLY, stage: .validatePending,
                    residue: residue, system: system
                )
            }
            try at(.syncPending, residue: residue) {
                try system.synchronize(descriptor: writer)
            }
            do {
                try system.rename(
                    parentDescriptor: attempt, oldName: pendingName,
                    newName: request.finalName, flags: renameFlags
                )
            } catch InvestigationOwnerOnlyCapsuleSystemError.errno(let value)
                where value == EEXIST
            {
                throw Failure(
                    stage: .publish,
                    residue: collisionResidue(
                        parentDescriptor: attempt,
                        attempt: request.attemptName, pending: pendingName,
                        final: request.finalName,
                        candidateNames: [pendingName, request.finalName],
                        system: system
                    )
                )
            } catch {
                throw Failure(stage: .publish, residue: residue)
            }
            residue = .published(
                attempt: request.attemptName, file: request.finalName
            )
            try at(.validateAttempt, residue: residue) {
                try validateDirectory(
                    descriptor: attempt, parent: baseDescriptor,
                    name: request.attemptName, baseDevice: baseMetadata.device,
                    system: system
                )
            }
            try at(.syncLeaf, residue: residue) {
                try system.synchronize(descriptor: attempt)
            }
            let reader = try at(.reopenFinal, residue: residue) {
                try registeredOpen(
                    parent: attempt, name: request.finalName,
                    flags: finalReaderFlags, mode: nil, role: .finalReader,
                    ledger: &ledger, system: system, stage: .reopenFinal,
                    residue: residue
                )
            }
            let finalMetadata = try at(.validateFinal, residue: residue) {
                try validateFile(
                    descriptor: reader, parent: attempt, name: request.finalName,
                    baseDevice: baseMetadata.device,
                    expectedSize: Int64(request.canonicalBytes.count),
                    accessMode: O_RDONLY, stage: .validateFinal,
                    residue: residue, system: system
                )
            }
            guard finalMetadata == pendingMetadata else {
                throw Failure(stage: .validateFinal, residue: residue)
            }
            guard try at(.initialOffset, residue: residue, {
                try system.offset(descriptor: reader)
            }) == 0 else {
                throw Failure(stage: .initialOffset, residue: residue)
            }
            let verifiedBytes = try at(.readFinal, residue: residue) {
                try readExactly(
                    descriptor: reader, count: request.canonicalBytes.count,
                    system: system
                )
            }
            let eof = try at(.endOfFile, residue: residue) {
                try readWithInterruptBound(
                    descriptor: reader, maximumByteCount: 1,
                    offset: Int64(request.canonicalBytes.count), system: system
                )
            }
            guard eof.isEmpty else {
                throw Failure(stage: .endOfFile, residue: residue)
            }
            guard verifiedBytes == request.canonicalBytes else {
                throw Failure(stage: .contentDigest, residue: residue)
            }
            do {
                let decoded = try InvestigationProjectedCohortInput.decode(
                    verifiedBytes
                )
                guard
                    try decoded.encoded() == verifiedBytes,
                    decoded.wholeInputSHA256 == request.wholeInputSHA256
                else {
                    throw Failure(stage: .contentDigest, residue: residue)
                }
            } catch let failure as Failure {
                throw failure
            } catch {
                throw Failure(stage: .contentDigest, residue: residue)
            }
            guard try at(.finalOffset, residue: residue, {
                try system.offset(descriptor: reader)
            }) == 0 else {
                throw Failure(stage: .finalOffset, residue: residue)
            }
            let postReadMetadata = try at(.validateFinal, residue: residue) {
                try validateFile(
                    descriptor: reader, parent: attempt, name: request.finalName,
                    baseDevice: baseMetadata.device,
                    expectedSize: Int64(request.canonicalBytes.count),
                    accessMode: O_RDONLY, stage: .validateFinal,
                    residue: residue, system: system
                )
            }
            guard postReadMetadata == finalMetadata else {
                throw Failure(stage: .validateFinal, residue: residue)
            }
            let writerCloseFailures = ledger.close(
                role: .pendingWriter, using: system
            )
            guard writerCloseFailures.isEmpty else {
                throw Failure(
                    stage: .closePendingWriter, residue: residue,
                    closeFailures: writerCloseFailures
                )
            }
            let leafCloseFailures = ledger.close(
                role: .attemptDirectory, using: system
            )
            guard leafCloseFailures.isEmpty else {
                throw Failure(
                    stage: .closeAttemptDirectory, residue: residue,
                    closeFailures: leafCloseFailures
                )
            }
            guard ledger.transfer(reader) else {
                throw Failure(stage: .validateFinal, residue: residue)
            }
            return InvestigationOwnerOnlyCapsuleVerifiedReader(
                descriptor: reader,
                identity: InvestigationOwnerOnlyCapsuleNodeIdentity(
                    device: finalMetadata.device, inode: finalMetadata.inode,
                    generation: finalMetadata.generation,
                    size: finalMetadata.size
                ),
                digest: request.wholeInputSHA256
            )
        } catch let failure as Failure {
            let closes = failure.closeFailures + ledger.closeAll(using: system)
            throw InvestigationOwnerOnlyCapsuleError.publicationFailed(
                stage: failure.stage, residue: failure.residue,
                closeFailures: closes
            )
        } catch let error as InvestigationOwnerOnlyCapsuleError {
            let closes = ledger.closeAll(using: system)
            guard closes.isEmpty else {
                throw InvestigationOwnerOnlyCapsuleError.publicationFailed(
                    stage: .inventory, residue: residue, closeFailures: closes
                )
            }
            throw error
        } catch {
            let stage = stageForCurrentResidue(residue)
            let closes = ledger.closeAll(using: system)
            throw InvestigationOwnerOnlyCapsuleError.publicationFailed(
                stage: stage, residue: residue, closeFailures: closes
            )
        }
    }

    private static func validateInventory(
        _ inventory: InvestigationOwnerOnlyCapsuleInventory
    ) throws {
        guard inventory.reachedEnd else {
            throw Failure(stage: .inventory, residue: .none)
        }
        var lockCount = 0
        var attempts: [String] = []
        var unexpected: [String] = []
        for entry in inventory.entries {
            if entry == InvestigationMachineGateOwnershipAcquirer.lockName {
                lockCount += 1
            } else if isAttemptName(entry) {
                attempts.append(entry)
            } else {
                unexpected.append(entry)
            }
        }
        guard attempts.count <= maximumAttemptRootCount else {
            throw InvestigationOwnerOnlyCapsuleError.attemptRootLimitExceeded
        }
        guard lockCount == 1 else {
            throw Failure(stage: .inventory, residue: .none)
        }
        let residue = attempts + unexpected
        guard residue.isEmpty else {
            throw InvestigationOwnerOnlyCapsuleError.staleInventory(
                residue.sorted()
            )
        }
    }

    private static func isAttemptName(_ value: String) -> Bool {
        let prefix = "attempt-"
        guard value.hasPrefix(prefix) else { return false }
        let suffix = String(value.dropFirst(prefix.count))
        return suffix == suffix.lowercased() && UUID(uuidString: suffix) != nil
    }

    private static func collisionResidue(
        parentDescriptor: Int32, attempt: String, pending: String?,
        final: String?, candidateNames: [String],
        system: any InvestigationOwnerOnlyCapsuleSystem
    ) -> InvestigationOwnerOnlyCapsuleResidue {
        var observed: [String] = []
        var complete = true
        for name in candidateNames {
            do {
                _ = try system.namedMetadata(
                    parentDescriptor: parentDescriptor, name: name,
                    flags: namedFlags
                )
                observed.append(name)
            } catch InvestigationOwnerOnlyCapsuleSystemError.errno(let value)
                where value == ENOENT
            {} catch {
                complete = false
                break
            }
        }
        return .collision(
            attempt: attempt, pending: pending, final: final,
            observed: observed, observationComplete: complete
        )
    }

    private static func registeredOpen(
        parent: Int32, name: String, flags: Int32, mode: mode_t?,
        role: InvestigationOwnerOnlyCapsuleCloseRole,
        ledger: inout InvestigationOwnerOnlyCapsuleDescriptorLedger,
        system: any InvestigationOwnerOnlyCapsuleSystem,
        stage: InvestigationOwnerOnlyCapsuleFailureStage,
        residue: InvestigationOwnerOnlyCapsuleResidue
    ) throws -> Int32 {
        let descriptor = try system.openComponent(
            parentDescriptor: parent, name: name, flags: flags, mode: mode
        )
        guard descriptor >= 0, ledger.register(descriptor, role: role) else {
            throw Failure(stage: stage, residue: residue)
        }
        return descriptor
    }

    private static func validateDirectory(
        descriptor: Int32, parent: Int32, name: String, baseDevice: UInt64,
        system: any InvestigationOwnerOnlyCapsuleSystem
    ) throws {
        let held = try system.metadata(descriptor: descriptor)
        let named = try system.namedMetadata(
            parentDescriptor: parent, name: name, flags: namedFlags
        )
        guard
            held == named, held.device == baseDevice, held.inode > 0,
            held.fileType == .directory,
            held.ownerUID == InvestigationMachineGateOwnershipAcquirer.targetUID,
            held.ownerGID == InvestigationMachineGateOwnershipAcquirer.targetGID,
            held.permissions == 0o700, held.linkCount > 0, held.size >= 0,
            held.flags == 0,
            try system.descriptorFlags(descriptor) & FD_CLOEXEC == FD_CLOEXEC,
            try system.descriptorStatusFlags(descriptor) & O_ACCMODE == O_RDONLY,
            try system.descriptorStatusFlags(descriptor) & O_NONBLOCK == O_NONBLOCK,
            try system.extendedACLIsEmpty(descriptor: descriptor),
            try system.extendedAttributeNames(descriptor: descriptor).isEmpty
        else {
            throw Failure(
                stage: .validateAttempt,
                residue: .attemptDirectory(name)
            )
        }
    }

    @discardableResult
    private static func validateFile(
        descriptor: Int32, parent: Int32, name: String, baseDevice: UInt64,
        expectedSize: Int64, accessMode: Int32,
        stage: InvestigationOwnerOnlyCapsuleFailureStage,
        residue: InvestigationOwnerOnlyCapsuleResidue,
        system: any InvestigationOwnerOnlyCapsuleSystem
    ) throws -> InvestigationMachineGateMetadataSnapshot {
        let held = try system.metadata(descriptor: descriptor)
        let named = try system.namedMetadata(
            parentDescriptor: parent, name: name, flags: namedFlags
        )
        guard
            held == named, held.device == baseDevice, held.inode > 0,
            held.fileType == .regularFile,
            held.ownerUID == InvestigationMachineGateOwnershipAcquirer.targetUID,
            held.ownerGID == InvestigationMachineGateOwnershipAcquirer.targetGID,
            held.permissions == 0o600, held.linkCount == 1,
            held.size == expectedSize, held.flags == 0,
            try system.descriptorFlags(descriptor) & FD_CLOEXEC == FD_CLOEXEC,
            try system.descriptorStatusFlags(descriptor) & O_ACCMODE == accessMode,
            try system.descriptorStatusFlags(descriptor) & O_NONBLOCK == O_NONBLOCK,
            try system.extendedACLIsEmpty(descriptor: descriptor),
            try system.extendedAttributeNames(descriptor: descriptor).isEmpty
        else {
            throw Failure(stage: stage, residue: residue)
        }
        return held
    }

    private static func writeAll(
        _ bytes: Data, descriptor: Int32,
        system: any InvestigationOwnerOnlyCapsuleSystem
    ) throws {
        var offset = 0
        var interrupts = 0
        while offset < bytes.count {
            let end = min(offset + maximumIOByteCount, bytes.count)
            do {
                let count = try system.write(
                    descriptor: descriptor, bytes: bytes[offset..<end],
                    offset: Int64(offset)
                )
                guard count > 0, count <= end - offset else {
                    throw Failure(stage: .writePending, residue: .none)
                }
                offset += count
            } catch InvestigationOwnerOnlyCapsuleSystemError.errno(let value)
                where value == EINTR
            {
                interrupts += 1
                guard interrupts <= maximumInterruptCount else {
                    throw Failure(stage: .writePending, residue: .none)
                }
            }
        }
    }

    private static func readExactly(
        descriptor: Int32, count: Int,
        system: any InvestigationOwnerOnlyCapsuleSystem
    ) throws -> Data {
        var result = Data()
        result.reserveCapacity(count)
        while result.count < count {
            let bytes = try readWithInterruptBound(
                descriptor: descriptor,
                maximumByteCount: min(maximumIOByteCount, count - result.count),
                offset: Int64(result.count), system: system
            )
            guard !bytes.isEmpty, bytes.count <= count - result.count else {
                throw Failure(stage: .readFinal, residue: .none)
            }
            result.append(bytes)
        }
        return result
    }

    private static func readWithInterruptBound(
        descriptor: Int32, maximumByteCount: Int, offset: Int64,
        system: any InvestigationOwnerOnlyCapsuleSystem
    ) throws -> Data {
        var interrupts = 0
        while true {
            do {
                let result = try system.read(
                    descriptor: descriptor, maximumByteCount: maximumByteCount,
                    offset: offset
                )
                guard result.count <= maximumByteCount else {
                    throw Failure(stage: .readFinal, residue: .none)
                }
                return result
            } catch InvestigationOwnerOnlyCapsuleSystemError.errno(let value)
                where value == EINTR
            {
                interrupts += 1
                guard interrupts <= maximumInterruptCount else {
                    throw Failure(stage: .readFinal, residue: .none)
                }
            }
        }
    }

    private static func stageForCurrentResidue(
        _ residue: InvestigationOwnerOnlyCapsuleResidue
    ) -> InvestigationOwnerOnlyCapsuleFailureStage {
        switch residue {
        case .none: .inventory
        case .attemptDirectory: .openAttempt
        case .pending: .writePending
        case .published: .syncLeaf
        case .collision: .inventory
        }
    }

    private static func at<T>(
        _ stage: InvestigationOwnerOnlyCapsuleFailureStage,
        residue: InvestigationOwnerOnlyCapsuleResidue,
        _ operation: () throws -> T
    ) throws -> T {
        do { return try operation() }
        catch let failure as Failure {
            throw Failure(
                stage: failure.stage, residue: residue,
                closeFailures: failure.closeFailures
            )
        }
        catch { throw Failure(stage: stage, residue: residue) }
    }

    private struct Failure: Error {
        let stage: InvestigationOwnerOnlyCapsuleFailureStage
        let residue: InvestigationOwnerOnlyCapsuleResidue
        let closeFailures: [InvestigationOwnerOnlyCapsuleCloseRole]

        init(
            stage: InvestigationOwnerOnlyCapsuleFailureStage,
            residue: InvestigationOwnerOnlyCapsuleResidue,
            closeFailures: [InvestigationOwnerOnlyCapsuleCloseRole] = []
        ) {
            self.stage = stage
            self.residue = residue
            self.closeFailures = closeFailures
        }
    }
}

struct InvestigationOwnerOnlyCapsuleVerifiedReader: Sendable {
    fileprivate let descriptor: Int32
    let identity: InvestigationOwnerOnlyCapsuleNodeIdentity
    let digest: InvestigationHandoffSHA256
}

package final class InvestigationOwnerOnlyCapsuleLease: @unchecked Sendable {
    private enum State {
        case available
        case handingOff
        case awaitingSettlement
        case terminal
        case capsuleCloseUncertain
        case ownershipReleaseUncertain
        case abandoned
    }

    package let outerAttemptUUID: UUID
    package let identity: InvestigationOwnerOnlyCapsuleNodeIdentity
    package let digest: InvestigationHandoffSHA256
    private let owner: InvestigationMachineGateOwnership
    private let system: any InvestigationOwnerOnlyCapsuleSystem
    private let borrower: (any InvestigationOwnerOnlyCapsuleBorrowing)?
    private let descriptor: Int32
    private let attemptName: String
    private let finalName: String
    private let terminalLock = NSLock()
    private var state = State.available

    private init(
        owner: InvestigationMachineGateOwnership,
        reader: InvestigationOwnerOnlyCapsuleVerifiedReader,
        request: InvestigationOwnerOnlyCapsulePublicationRequest,
        system: any InvestigationOwnerOnlyCapsuleSystem,
        borrower: (any InvestigationOwnerOnlyCapsuleBorrowing)?
    ) {
        self.owner = owner
        self.system = system
        self.borrower = borrower
        descriptor = reader.descriptor
        outerAttemptUUID = request.outerAttemptUUID
        attemptName = request.attemptName
        finalName = request.finalName
        identity = reader.identity
        digest = reader.digest
    }

    static func make(
        owner: InvestigationMachineGateOwnership,
        reader: InvestigationOwnerOnlyCapsuleVerifiedReader,
        request: InvestigationOwnerOnlyCapsulePublicationRequest,
        system: any InvestigationOwnerOnlyCapsuleSystem,
        borrower: (any InvestigationOwnerOnlyCapsuleBorrowing)?
    ) -> Self {
        Self(
            owner: owner, reader: reader, request: request, system: system,
            borrower: borrower
        )
    }

    package func handoffOnce() throws
        -> InvestigationOwnerOnlyCapsuleExactGateReapedProof
    {
        let residue = publishedResidue
        terminalLock.lock()
        switch state {
        case .available:
            guard let borrower else {
                terminalLock.unlock()
                throw InvestigationOwnerOnlyCapsuleError
                    .fixedHandoffUnavailable(residue)
            }
            state = .handingOff
            terminalLock.unlock()
            let proof: InvestigationOwnerOnlyCapsuleExactGateReapedProof
            do {
                proof = try borrower.handoffToFixedGate(
                    descriptor: descriptor, outerAttemptUUID: outerAttemptUUID,
                    identity: identity, digest: digest
                )
            } catch {
                try terminateAfterHandoffFailure(residue: residue)
                throw InvestigationOwnerOnlyCapsuleError.handoffFailed(residue)
            }
            guard
                proof.outerAttemptUUID == outerAttemptUUID,
                proof.identity == identity, proof.digest == digest
            else {
                try terminateAfterHandoffFailure(residue: residue)
                throw InvestigationOwnerOnlyCapsuleError.handoffFailed(residue)
            }
            try closeReaderForSettlement(residue: residue)
            terminalLock.lock()
            state = .awaitingSettlement
            terminalLock.unlock()
            return proof
        case .handingOff, .awaitingSettlement:
            terminalLock.unlock()
            throw InvestigationOwnerOnlyCapsuleError.alreadyHandedOff(residue)
        case .terminal, .capsuleCloseUncertain,
             .ownershipReleaseUncertain, .abandoned:
            terminalLock.unlock()
            throw InvestigationOwnerOnlyCapsuleError.alreadyTerminal(residue)
        }
    }

    package func finishWithoutHandoff() throws
        -> InvestigationOwnerOnlyCapsuleNeverHandedOffProof
    {
        let residue = publishedResidue
        terminalLock.lock()
        guard case .available = state else {
            terminalLock.unlock()
            throw InvestigationOwnerOnlyCapsuleError.alreadyTerminal(residue)
        }
        state = .capsuleCloseUncertain
        terminalLock.unlock()
        do {
            try system.close(descriptor: descriptor)
        } catch {
            let releaseUncertain = !releaseOwnership()
            terminalLock.lock()
            state = releaseUncertain
                ? .ownershipReleaseUncertain : .capsuleCloseUncertain
            terminalLock.unlock()
            throw InvestigationOwnerOnlyCapsuleError.capsuleCloseUncertain(
                residue, ownershipReleaseUncertain: releaseUncertain
            )
        }
        terminalLock.lock()
        state = .awaitingSettlement
        terminalLock.unlock()
        return InvestigationOwnerOnlyCapsuleNeverHandedOffProof.make(
            outerAttemptUUID: outerAttemptUUID, digest: digest,
            identity: identity
        )
    }

    deinit {
        terminalLock.lock()
        let closeReader: Bool
        let releaseOwner: Bool
        switch state {
        case .available:
            closeReader = true
            releaseOwner = true
        case .awaitingSettlement:
            closeReader = false
            releaseOwner = true
        case .handingOff, .terminal, .capsuleCloseUncertain,
             .ownershipReleaseUncertain, .abandoned:
            closeReader = false
            releaseOwner = false
        }
        guard closeReader || releaseOwner else {
            terminalLock.unlock()
            return
        }
        state = .abandoned
        terminalLock.unlock()
        if closeReader { try? system.close(descriptor: descriptor) }
        if releaseOwner { try? owner.release() }
    }

    private var publishedResidue: InvestigationOwnerOnlyCapsuleResidue {
        .published(attempt: attemptName, file: finalName)
    }

    private func closeReaderForSettlement(
        residue: InvestigationOwnerOnlyCapsuleResidue
    ) throws {
        do {
            try system.close(descriptor: descriptor)
        } catch {
            let releaseUncertain = !releaseOwnership()
            terminalLock.lock()
            state = releaseUncertain
                ? .ownershipReleaseUncertain : .capsuleCloseUncertain
            terminalLock.unlock()
            throw InvestigationOwnerOnlyCapsuleError.capsuleCloseUncertain(
                residue, ownershipReleaseUncertain: releaseUncertain
            )
        }
    }

    private func terminateAfterHandoffFailure(
        residue: InvestigationOwnerOnlyCapsuleResidue
    ) throws {
        var closeUncertain = false
        do { try system.close(descriptor: descriptor) }
        catch { closeUncertain = true }
        let releaseUncertain = !releaseOwnership()
        terminalLock.lock()
        if releaseUncertain { state = .ownershipReleaseUncertain }
        else if closeUncertain { state = .capsuleCloseUncertain }
        else { state = .terminal }
        terminalLock.unlock()
        if closeUncertain {
            throw InvestigationOwnerOnlyCapsuleError.capsuleCloseUncertain(
                residue, ownershipReleaseUncertain: releaseUncertain
            )
        }
        if releaseUncertain {
            throw InvestigationOwnerOnlyCapsuleError
                .ownershipReleaseUncertain(residue)
        }
    }

    private func releaseOwnership() -> Bool {
        do { try owner.release(); return true }
        catch { return false }
    }
}

package final class InvestigationOwnerOnlyCapsuleExactGateReapedProof:
    @unchecked Sendable
{
    package let outerAttemptUUID: UUID
    package let digest: InvestigationHandoffSHA256
    package let identity: InvestigationOwnerOnlyCapsuleNodeIdentity
    private let seal = UUID()

    private init(
        outerAttemptUUID: UUID, digest: InvestigationHandoffSHA256,
        identity: InvestigationOwnerOnlyCapsuleNodeIdentity
    ) {
        self.outerAttemptUUID = outerAttemptUUID
        self.digest = digest
        self.identity = identity
    }

    static func makeForFixedLauncher(
        outerAttemptUUID: UUID, digest: InvestigationHandoffSHA256,
        identity: InvestigationOwnerOnlyCapsuleNodeIdentity
    ) -> Self {
        Self(
            outerAttemptUUID: outerAttemptUUID, digest: digest,
            identity: identity
        )
    }
}

package final class InvestigationOwnerOnlyCapsuleNeverHandedOffProof:
    @unchecked Sendable
{
    package let outerAttemptUUID: UUID
    package let digest: InvestigationHandoffSHA256
    package let identity: InvestigationOwnerOnlyCapsuleNodeIdentity
    private let seal = UUID()

    private init(
        outerAttemptUUID: UUID, digest: InvestigationHandoffSHA256,
        identity: InvestigationOwnerOnlyCapsuleNodeIdentity
    ) {
        self.outerAttemptUUID = outerAttemptUUID
        self.digest = digest
        self.identity = identity
    }

    fileprivate static func make(
        outerAttemptUUID: UUID, digest: InvestigationHandoffSHA256,
        identity: InvestigationOwnerOnlyCapsuleNodeIdentity
    ) -> Self {
        Self(
            outerAttemptUUID: outerAttemptUUID, digest: digest,
            identity: identity
        )
    }
}

private struct InvestigationOwnerOnlyCapsuleDescriptorLedger {
    private var values: [(Int32, InvestigationOwnerOnlyCapsuleCloseRole)] = []

    mutating func register(
        _ descriptor: Int32, role: InvestigationOwnerOnlyCapsuleCloseRole
    ) -> Bool {
        guard !values.contains(where: { $0.0 == descriptor }) else {
            return false
        }
        values.append((descriptor, role))
        return true
    }

    mutating func transfer(_ descriptor: Int32) -> Bool {
        guard let index = values.firstIndex(where: { $0.0 == descriptor })
        else { return false }
        values.remove(at: index)
        return true
    }

    mutating func close(
        role: InvestigationOwnerOnlyCapsuleCloseRole,
        using system: any InvestigationOwnerOnlyCapsuleSystem
    ) -> [InvestigationOwnerOnlyCapsuleCloseRole] {
        guard let index = values.lastIndex(where: { $0.1 == role }) else {
            return []
        }
        let value = values.remove(at: index)
        do { try system.close(descriptor: value.0); return [] }
        catch { return [value.1] }
    }

    mutating func closeAll(
        using system: any InvestigationOwnerOnlyCapsuleSystem
    ) -> [InvestigationOwnerOnlyCapsuleCloseRole] {
        var failures: [InvestigationOwnerOnlyCapsuleCloseRole] = []
        while let value = values.popLast() {
            do { try system.close(descriptor: value.0) }
            catch { failures.append(value.1) }
        }
        return failures
    }
}

final class DarwinInvestigationOwnerOnlyCapsuleSystem:
    InvestigationOwnerOnlyCapsuleSystem, @unchecked Sendable
{
    private static let maximumXattrBytes = 4 * 1_024

    func inventory(
        baseDescriptor: Int32, maximumEntryCount: Int
    ) throws -> InvestigationOwnerOnlyCapsuleInventory {
        let enumerationDescriptor = openat(
            baseDescriptor, ".",
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NONBLOCK | O_NOFOLLOW_ANY
                | O_RESOLVE_BENEATH
        )
        guard enumerationDescriptor >= 0 else { throw lastError() }
        guard let directory = fdopendir(enumerationDescriptor) else {
            let openError = Darwin.errno
            guard Darwin.close(enumerationDescriptor) == 0 else {
                throw lastError()
            }
            throw InvestigationOwnerOnlyCapsuleSystemError.errno(openError)
        }

        let outcome: Result<
            InvestigationOwnerOnlyCapsuleInventory,
            InvestigationOwnerOnlyCapsuleSystemError
        >
        do {
            outcome = .success(try Self.readInventory(
                directory: directory, maximumEntryCount: maximumEntryCount
            ))
        } catch let error as InvestigationOwnerOnlyCapsuleSystemError {
            outcome = .failure(error)
        } catch {
            outcome = .failure(.errno(EIO))
        }
        guard closedir(directory) == 0 else { throw lastError() }
        return try outcome.get()
    }

    func createDirectory(
        parentDescriptor: Int32, name: String, mode: mode_t
    ) throws {
        guard mkdirat(parentDescriptor, name, mode) == 0 else { throw lastError() }
    }

    func openComponent(
        parentDescriptor: Int32, name: String, flags: Int32, mode: mode_t?
    ) throws -> Int32 {
        let value = mode.map { openat(parentDescriptor, name, flags, $0) }
            ?? openat(parentDescriptor, name, flags)
        guard value >= 0 else { throw lastError() }
        return value
    }

    func metadata(
        descriptor: Int32
    ) throws -> InvestigationMachineGateMetadataSnapshot {
        var value = stat()
        guard fstat(descriptor, &value) == 0 else { throw lastError() }
        return Self.snapshot(value)
    }

    func namedMetadata(
        parentDescriptor: Int32, name: String, flags: Int32
    ) throws -> InvestigationMachineGateMetadataSnapshot {
        var value = stat()
        guard fstatat(parentDescriptor, name, &value, flags) == 0 else {
            throw lastError()
        }
        return Self.snapshot(value)
    }

    func descriptorFlags(_ descriptor: Int32) throws -> Int32 {
        let value = fcntl(descriptor, F_GETFD)
        guard value >= 0 else { throw lastError() }
        return value
    }

    func descriptorStatusFlags(_ descriptor: Int32) throws -> Int32 {
        let value = fcntl(descriptor, F_GETFL)
        guard value >= 0 else { throw lastError() }
        return value
    }

    func setPermissions(descriptor: Int32, mode: mode_t) throws {
        guard fchmod(descriptor, mode) == 0 else { throw lastError() }
    }

    func extendedACLIsEmpty(descriptor: Int32) throws -> Bool {
        Darwin.errno = 0
        guard let acl = acl_get_fd_np(descriptor, ACL_TYPE_EXTENDED) else {
            if Darwin.errno == ENOENT { return true }
            throw lastError()
        }
        var entry: acl_entry_t?
        let result = acl_get_entry(acl, Int32(ACL_FIRST_ENTRY.rawValue), &entry)
        let savedErrno = Darwin.errno
        guard acl_free(UnsafeMutableRawPointer(acl)) == 0 else { throw lastError() }
        guard result >= 0 else {
            throw InvestigationOwnerOnlyCapsuleSystemError.errno(savedErrno)
        }
        return result != 0
    }

    func extendedAttributeNames(descriptor: Int32) throws -> [String] {
        let capacity = flistxattr(descriptor, nil, 0, 0)
        guard capacity >= 0, capacity <= Self.maximumXattrBytes else {
            throw InvestigationOwnerOnlyCapsuleSystemError.errno(
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
            throw InvestigationOwnerOnlyCapsuleSystemError.errno(EIO)
        }
        return try bytes.split(separator: 0).map { value in
            guard let name = String(bytes: value, encoding: .utf8), !name.isEmpty
            else { throw InvestigationOwnerOnlyCapsuleSystemError.errno(EILSEQ) }
            return name
        }
    }

    func synchronize(descriptor: Int32) throws {
        guard fsync(descriptor) == 0 else { throw lastError() }
    }

    func write(
        descriptor: Int32, bytes: Data, offset: Int64
    ) throws -> Int {
        let result = bytes.withUnsafeBytes { buffer in
            pwrite(descriptor, buffer.baseAddress, buffer.count, off_t(offset))
        }
        guard result >= 0 else { throw lastError() }
        return result
    }

    func rename(
        parentDescriptor: Int32, oldName: String, newName: String,
        flags: Int32
    ) throws {
        guard renameatx_np(
            parentDescriptor, oldName, parentDescriptor, newName,
            UInt32(flags)
        ) == 0 else { throw lastError() }
    }

    func offset(descriptor: Int32) throws -> Int64 {
        let value = lseek(descriptor, 0, SEEK_CUR)
        guard value >= 0 else { throw lastError() }
        return Int64(value)
    }

    func read(
        descriptor: Int32, maximumByteCount: Int, offset: Int64
    ) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: maximumByteCount)
        let count = bytes.withUnsafeMutableBytes { buffer in
            pread(descriptor, buffer.baseAddress, buffer.count, off_t(offset))
        }
        guard count >= 0 else { throw lastError() }
        return Data(bytes.prefix(count))
    }

    func close(descriptor: Int32) throws {
        guard Darwin.close(descriptor) == 0 else { throw lastError() }
    }

    private func lastError() -> InvestigationOwnerOnlyCapsuleSystemError {
        .errno(Darwin.errno)
    }

    private static func snapshot(
        _ value: stat
    ) -> InvestigationMachineGateMetadataSnapshot {
        let type: InvestigationMachineGateFileType = switch value.st_mode & S_IFMT {
        case S_IFDIR: .directory
        case S_IFREG: .regularFile
        default: .other
        }
        return .init(
            device: UInt64(value.st_dev), inode: UInt64(value.st_ino),
            generation: UInt64(value.st_gen), fileType: type,
            ownerUID: value.st_uid, ownerGID: value.st_gid,
            permissions: value.st_mode & 0o7777,
            linkCount: UInt64(value.st_nlink), size: value.st_size,
            flags: value.st_flags
        )
    }

    private static func name(_ entry: UnsafePointer<dirent>) throws -> String {
        guard
            let recordOffset = MemoryLayout<dirent>.offset(of: \.d_reclen),
            let lengthOffset = MemoryLayout<dirent>.offset(of: \.d_namlen),
            let nameOffset = MemoryLayout<dirent>.offset(of: \.d_name)
        else { throw InvestigationOwnerOnlyCapsuleSystemError.errno(EIO) }
        let raw = UnsafeRawPointer(entry)
        let recordLength = Int(
            raw.load(fromByteOffset: recordOffset, as: UInt16.self)
        )
        let nameLength = Int(
            raw.load(fromByteOffset: lengthOffset, as: UInt16.self)
        )
        guard
            nameLength > 0,
            nameLength < MemoryLayout.size(ofValue: dirent().d_name),
            recordLength <= MemoryLayout<dirent>.size,
            nameOffset + nameLength + 1 <= recordLength
        else { throw InvestigationOwnerOnlyCapsuleSystemError.errno(EIO) }
        let bytes = UnsafeBufferPointer(
            start: raw.advanced(by: nameOffset)
                .assumingMemoryBound(to: UInt8.self),
            count: nameLength
        )
        guard
            !bytes.contains(0),
            raw.load(fromByteOffset: nameOffset + nameLength, as: UInt8.self) == 0,
            let name = String(validating: bytes, as: UTF8.self)
        else { throw InvestigationOwnerOnlyCapsuleSystemError.errno(EILSEQ) }
        return name
    }

    private static func readInventory(
        directory: UnsafeMutablePointer<DIR>, maximumEntryCount: Int
    ) throws -> InvestigationOwnerOnlyCapsuleInventory {
        var names: [String] = []
        while true {
            Darwin.errno = 0
            guard let entry = readdir(directory) else {
                guard Darwin.errno == 0 else {
                    throw InvestigationOwnerOnlyCapsuleSystemError.errno(
                        Darwin.errno
                    )
                }
                return .init(entries: names, reachedEnd: true)
            }
            let value = try name(entry)
            if value == "." || value == ".." { continue }
            guard names.count < maximumEntryCount else {
                return .init(entries: names, reachedEnd: false)
            }
            names.append(value)
        }
    }
}
#endif
