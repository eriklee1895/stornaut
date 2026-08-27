import Darwin
import Foundation
import Testing

@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationMachineLaunchSupport

@Suite("Investigation owner-only capsule", .serialized)
struct InvestigationOwnerOnlyCapsuleTests {
    @Test
    func malformedAndOversizedPayloadFailBeforeOwnership() throws {
        let ownership = CapsuleOwnershipSystem()
        let capsule = CapsuleSemanticSystem(bytes: Data())
        let publisher = InvestigationOwnerOnlyCapsulePublisher(
            ownershipSystem: ownership, capsuleSystem: capsule
        )

        #expect(throws: InvestigationOwnerOnlyCapsuleError.invalidCapsule) {
            _ = try publisher.publish(Data([0xff]))
        }
        #expect(throws: InvestigationOwnerOnlyCapsuleError.invalidCapsule) {
            _ = try publisher.publish(Data(
                repeating: 0,
                count: InvestigationProjectedCohortInput.maximumByteCount + 1
            ))
        }
        #expect(ownership.identityCalls == 0)
        #expect(capsule.events.isEmpty)
    }

    @Test
    func canonicalPublicationUsesExactSequenceAndRetainsOnlyReader() throws {
        let bytes = try canonicalProjectedInput().encoded()
        let request = try InvestigationOwnerOnlyCapsulePublicationRequest(
            canonicalBytes: bytes
        )
        let ownership = CapsuleOwnershipSystem()
        let system = CapsuleSemanticSystem(bytes: bytes)
        var state: InvestigationOwnerOnlyCapsuleLease? = try
            InvestigationOwnerOnlyCapsulePublisher(
                ownershipSystem: ownership, capsuleSystem: system
            ).publish(bytes)

        #expect(state?.digest == request.wholeInputSHA256)
        #expect(state?.outerAttemptUUID == request.outerAttemptUUID)
        #expect(state?.identity == .init(
            device: 1, inode: 12, generation: 0, size: Int64(bytes.count)
        ))
        #expect(system.createCalls == [
            .init(parent: 15, name: request.attemptName, mode: 0o700),
        ])
        #expect(system.openCalls == [
            .init(
                parent: 15, name: request.attemptName,
                flags: InvestigationOwnerOnlyCapsulePublication.attemptDirectoryFlags,
                mode: nil),
            .init(
                parent: 30,
                name: InvestigationOwnerOnlyCapsulePublication.pendingName,
                flags: InvestigationOwnerOnlyCapsulePublication.pendingWriterFlags,
                mode: 0o600),
            .init(
                parent: 30, name: request.finalName,
                flags: InvestigationOwnerOnlyCapsulePublication.finalReaderFlags,
                mode: nil),
        ])
        #expect(system.renameCalls == [.init(
            parent: 30,
            oldName: InvestigationOwnerOnlyCapsulePublication.pendingName,
            newName: request.finalName,
            flags: InvestigationOwnerOnlyCapsulePublication.renameFlags
        )])
        #expect(system.syncDescriptors == [15, 31, 30])
        #expect(system.writeOffsets.first == 0)
        #expect(system.writeMaximumCounts.allSatisfy {
            $0 <= InvestigationOwnerOnlyCapsulePublication.maximumIOByteCount
        })
        #expect(system.readOffsets.first == 0)
        #expect(system.readOffsets.last == Int64(bytes.count))
        #expect(system.offsetDescriptors == [32, 32])
        #expect(system.finalMetadataCount == 2)
        #expect(system.finalNamedCount == 2)
        #expect(system.closeDescriptors == [31, 30])
        #expect(system.entries == [
            fixedLockName, request.attemptName, request.finalName,
        ])
        let proof = try state!.finishWithoutHandoff()
        #expect(proof.outerAttemptUUID == request.outerAttemptUUID)
        #expect(proof.digest == request.wholeInputSHA256)
        #expect(throws: InvestigationOwnerOnlyCapsuleError.alreadyTerminal(
            .published(attempt: request.attemptName, file: request.finalName)
        )) {
            _ = try state!.finishWithoutHandoff()
        }
        #expect(system.closeDescriptors == [31, 30, 32])
        #expect(!ownership.closeRoles.contains(.base))
        #expect(!ownership.everyOpenedDescriptorClosedOnce)
        state = nil
        #expect(ownership.closeRoles.suffix(2) == [.base, .lock])
        #expect(ownership.everyOpenedDescriptorClosedOnce)
    }

    @Test(arguments: [
        CapsuleInventoryCase(
            entries: [fixedLockName, "unrelated"], reachedEnd: true,
            error: .staleInventory(["unrelated"])),
        CapsuleInventoryCase(
            entries: [fixedLockName] + (0...64).map {
                "attempt-" + capsuleUUID(UInt8(($0 % 254) + 1)).uuidString.lowercased()
            }, reachedEnd: true, error: .attemptRootLimitExceeded),
        CapsuleInventoryCase(
            entries: [fixedLockName], reachedEnd: false,
            error: .publicationFailed(
                stage: .inventory, residue: .none, closeFailures: [])),
    ])
    fileprivate func inventoryCompletesBeforeMutation(
        _ value: CapsuleInventoryCase
    ) throws {
        let bytes = try canonicalProjectedInput().encoded()
        let ownership = CapsuleOwnershipSystem()
        let system = CapsuleSemanticSystem(
            bytes: bytes, inventory: .init(
                entries: value.entries, reachedEnd: value.reachedEnd
            )
        )

        #expect(throws: value.error) {
            _ = try InvestigationOwnerOnlyCapsulePublisher(
                ownershipSystem: ownership, capsuleSystem: system
            ).publish(bytes)
        }
        #expect(system.createCalls.isEmpty)
        #expect(system.entries == value.entries)
        #expect(ownership.closeRoles.suffix(2) == [.base, .lock])
    }

    @Test(arguments: CapsuleFailureCase.allCases)
    fileprivate func publicationFailuresHaveExactStageResidueAndCloseCardinality(
        _ value: CapsuleFailureCase
    ) throws {
        let bytes = try canonicalProjectedInput().encoded()
        let request = try InvestigationOwnerOnlyCapsulePublicationRequest(
            canonicalBytes: bytes
        )
        let ownership = CapsuleOwnershipSystem()
        let system = CapsuleSemanticSystem(bytes: bytes, failure: value)
        let expectedResidue = value.expectedResidue(request: request)

        do {
            _ = try InvestigationOwnerOnlyCapsulePublisher(
                ownershipSystem: ownership, capsuleSystem: system
            ).publish(bytes)
            Issue.record("publication unexpectedly succeeded")
        } catch let error as InvestigationOwnerOnlyCapsuleError {
            guard case .publicationFailed(
                let stage, let residue, let closeFailures
            ) = error else {
                Issue.record("unexpected error: \(error)")
                return
            }
            #expect(stage == value.stage)
            #expect(residue == expectedResidue)
            #expect(closeFailures == value.expectedCloseFailures)
        }
        #expect(system.closeDescriptors == value.expectedCloseDescriptors)
        #expect(system.entries == value.expectedEntries(request: request))
        #expect(system.unlinkCount == 0)
        #expect(ownership.closeRoles.suffix(2) == [.base, .lock])
        #expect(ownership.everyOpenedDescriptorClosedOnce)
        if [.attemptCollision, .pendingCollision, .renameCollision].contains(value) {
            if value == .renameCollision {
                #expect(system.renameCalls.count == 1)
            } else {
                #expect(system.renameCalls.isEmpty)
            }
        } else if value == .renameFailure {
            #expect(system.renameCalls.count == 1)
        }
        if value == .interruptedWriteLimit {
            #expect(system.writeOffsets.count == 65)
        }
        if value == .interruptedReadLimit {
            #expect(system.readOffsets.count == 65)
        }
    }

    @Test
    func interruptedPartialWriteAndReadAreBoundedAndOffsetPreserving() throws {
        let bytes = try canonicalProjectedInput().encoded()
        let ownership = CapsuleOwnershipSystem()
        let system = CapsuleSemanticSystem(bytes: bytes)
        system.writeScript = [.eintr, .count(7)]
        system.readScript = [.eintr, .count(9)]
        let state: InvestigationOwnerOnlyCapsuleLease = try
            InvestigationOwnerOnlyCapsulePublisher(
                ownershipSystem: ownership, capsuleSystem: system
            ).publish(bytes)

        #expect(system.writeOffsets.prefix(3) == [0, 0, 7])
        #expect(system.readOffsets.prefix(3) == [0, 0, 9])
        #expect(system.offsetDescriptors == [32, 32])
        _ = try state.finishWithoutHandoff()
    }

    @Test
    func generationZeroDoesNotRejectAnOtherwiseIdenticalNode() throws {
        let bytes = try canonicalProjectedInput().encoded()
        let ownership = CapsuleOwnershipSystem()
        let system = CapsuleSemanticSystem(bytes: bytes)
        system.generation = 0
        let state: InvestigationOwnerOnlyCapsuleLease = try
            InvestigationOwnerOnlyCapsulePublisher(
                ownershipSystem: ownership, capsuleSystem: system
            ).publish(bytes)
        #expect(state.identity.generation == 0)
        _ = try state.finishWithoutHandoff()
    }

    @Test
    func fixedHandoffIsOneShotAndRetainsOwnershipForSettlement() throws {
        let bytes = try canonicalProjectedInput().encoded()
        let request = try InvestigationOwnerOnlyCapsulePublicationRequest(
            canonicalBytes: bytes
        )
        let ownership = CapsuleOwnershipSystem()
        let system = CapsuleSemanticSystem(bytes: bytes)
        let borrower = CapsuleFixedBorrower()
        var lease: InvestigationOwnerOnlyCapsuleLease? = try
            InvestigationOwnerOnlyCapsulePublisher(
                ownershipSystem: ownership, capsuleSystem: system,
                borrower: borrower
            ).publish(bytes)

        let proof = try lease!.handoffOnce()
        #expect(borrower.descriptors == [32])
        #expect(borrower.outerAttemptUUIDs == [request.outerAttemptUUID])
        #expect(proof.outerAttemptUUID == request.outerAttemptUUID)
        #expect(proof.digest == request.wholeInputSHA256)
        #expect(system.closeDescriptors == [31, 30, 32])
        #expect(!ownership.closeRoles.contains(.base))
        #expect(throws: InvestigationOwnerOnlyCapsuleError.alreadyHandedOff(
            .published(attempt: request.attemptName, file: request.finalName)
        )) {
            _ = try lease!.handoffOnce()
        }

        lease = nil
        #expect(ownership.closeRoles.suffix(2) == [.base, .lock])
        #expect(system.closeDescriptors == [31, 30, 32])
        #expect(ownership.everyOpenedDescriptorClosedOnce)
    }

    @Test
    func throwingHandoffClosesCapsuleThenReleasesOwnership() throws {
        let bytes = try canonicalProjectedInput().encoded()
        let request = try InvestigationOwnerOnlyCapsulePublicationRequest(
            canonicalBytes: bytes
        )
        let ownership = CapsuleOwnershipSystem()
        let system = CapsuleSemanticSystem(bytes: bytes)
        let borrower = CapsuleFixedBorrower(throwsOnHandoff: true)
        let lease = try InvestigationOwnerOnlyCapsulePublisher(
            ownershipSystem: ownership, capsuleSystem: system, borrower: borrower
        ).publish(bytes)

        #expect(throws: InvestigationOwnerOnlyCapsuleError.handoffFailed(
            .published(attempt: request.attemptName, file: request.finalName)
        )) {
            _ = try lease.handoffOnce()
        }
        #expect(system.closeDescriptors == [31, 30, 32])
        #expect(ownership.closeRoles.suffix(2) == [.base, .lock])
        #expect(ownership.everyOpenedDescriptorClosedOnce)
        #expect(throws: InvestigationOwnerOnlyCapsuleError.alreadyTerminal(
            .published(attempt: request.attemptName, file: request.finalName)
        )) {
            _ = try lease.handoffOnce()
        }
    }

    @Test
    func capsuleCloseFailureStillReleasesOwnershipExactlyOnce() throws {
        let bytes = try canonicalProjectedInput().encoded()
        let request = try InvestigationOwnerOnlyCapsulePublicationRequest(
            canonicalBytes: bytes
        )
        let ownership = CapsuleOwnershipSystem()
        let system = CapsuleSemanticSystem(bytes: bytes)
        system.closeErrorDescriptors = [32]
        let lease = try InvestigationOwnerOnlyCapsulePublisher(
            ownershipSystem: ownership, capsuleSystem: system,
            borrower: CapsuleFixedBorrower()
        ).publish(bytes)

        #expect(throws: InvestigationOwnerOnlyCapsuleError.capsuleCloseUncertain(
            .published(attempt: request.attemptName, file: request.finalName),
            ownershipReleaseUncertain: false
        )) {
            _ = try lease.handoffOnce()
        }
        #expect(system.closeDescriptors == [31, 30, 32])
        #expect(ownership.closeRoles.suffix(2) == [.base, .lock])
        #expect(ownership.everyOpenedDescriptorClosedOnce)
    }

    @Test
    func ownershipReleaseFailureDoesNotForgeNeverHandedOffProof() throws {
        let bytes = try canonicalProjectedInput().encoded()
        let request = try InvestigationOwnerOnlyCapsulePublicationRequest(
            canonicalBytes: bytes
        )
        let ownership = CapsuleOwnershipSystem()
        ownership.closeErrorRoles = [.base]
        let system = CapsuleSemanticSystem(bytes: bytes)
        system.closeErrorDescriptors = [32]
        let lease = try InvestigationOwnerOnlyCapsulePublisher(
            ownershipSystem: ownership, capsuleSystem: system
        ).publish(bytes)

        #expect(throws: InvestigationOwnerOnlyCapsuleError.capsuleCloseUncertain(
            .published(attempt: request.attemptName, file: request.finalName),
            ownershipReleaseUncertain: true
        )) {
            _ = try lease.finishWithoutHandoff()
        }
        #expect(system.closeDescriptors == [31, 30, 32])
        #expect(ownership.closeRoles.suffix(2) == [.base, .lock])
        #expect(ownership.everyOpenedDescriptorClosedOnce)
    }

    @Test
    func handoffFailureAndOwnershipReleaseFailureRemainUncertain() throws {
        let bytes = try canonicalProjectedInput().encoded()
        let request = try InvestigationOwnerOnlyCapsulePublicationRequest(
            canonicalBytes: bytes
        )
        let ownership = CapsuleOwnershipSystem()
        ownership.closeErrorRoles = [.base]
        let system = CapsuleSemanticSystem(bytes: bytes)
        let lease = try InvestigationOwnerOnlyCapsulePublisher(
            ownershipSystem: ownership, capsuleSystem: system,
            borrower: CapsuleFixedBorrower(throwsOnHandoff: true)
        ).publish(bytes)

        #expect(throws: InvestigationOwnerOnlyCapsuleError
            .ownershipReleaseUncertain(
                .published(attempt: request.attemptName, file: request.finalName)
            )) {
            _ = try lease.handoffOnce()
        }
        #expect(system.closeDescriptors == [31, 30, 32])
        #expect(ownership.closeRoles.suffix(2) == [.base, .lock])
        #expect(ownership.everyOpenedDescriptorClosedOnce)
    }

    @Test
    func missingFixedBorrowerDoesNotConsumeLease() throws {
        let bytes = try canonicalProjectedInput().encoded()
        let request = try InvestigationOwnerOnlyCapsulePublicationRequest(
            canonicalBytes: bytes
        )
        let ownership = CapsuleOwnershipSystem()
        let system = CapsuleSemanticSystem(bytes: bytes)
        let lease = try InvestigationOwnerOnlyCapsulePublisher(
            ownershipSystem: ownership, capsuleSystem: system
        ).publish(bytes)

        #expect(throws: InvestigationOwnerOnlyCapsuleError.fixedHandoffUnavailable(
            .published(attempt: request.attemptName, file: request.finalName)
        )) {
            _ = try lease.handoffOnce()
        }
        _ = try lease.finishWithoutHandoff()
        #expect(system.closeDescriptors == [31, 30, 32])
    }

    @Test
    func mismatchedGateProofFailsClosedAndTerminatesLease() throws {
        let bytes = try canonicalProjectedInput().encoded()
        let request = try InvestigationOwnerOnlyCapsulePublicationRequest(
            canonicalBytes: bytes
        )
        let ownership = CapsuleOwnershipSystem()
        let system = CapsuleSemanticSystem(bytes: bytes)
        let lease = try InvestigationOwnerOnlyCapsulePublisher(
            ownershipSystem: ownership, capsuleSystem: system,
            borrower: CapsuleFixedBorrower(mismatchesProof: true)
        ).publish(bytes)

        #expect(throws: InvestigationOwnerOnlyCapsuleError.handoffFailed(
            .published(attempt: request.attemptName, file: request.finalName)
        )) {
            _ = try lease.handoffOnce()
        }
        #expect(system.closeDescriptors == [31, 30, 32])
        #expect(ownership.closeRoles.suffix(2) == [.base, .lock])
        #expect(ownership.everyOpenedDescriptorClosedOnce)
    }

    @Test
    func abandonedAvailableLeaseClosesReaderThenReleasesOwnership() throws {
        let bytes = try canonicalProjectedInput().encoded()
        let ownership = CapsuleOwnershipSystem()
        let system = CapsuleSemanticSystem(bytes: bytes)
        var lease: InvestigationOwnerOnlyCapsuleLease? = try
            InvestigationOwnerOnlyCapsulePublisher(
                ownershipSystem: ownership, capsuleSystem: system
            ).publish(bytes)

        #expect(lease != nil)
        lease = nil
        #expect(system.closeDescriptors == [31, 30, 32])
        #expect(ownership.closeRoles.suffix(2) == [.base, .lock])
        #expect(ownership.everyOpenedDescriptorClosedOnce)
    }
}

private struct CapsuleInventoryCase: Sendable {
    let entries: [String]
    let reachedEnd: Bool
    let error: InvestigationOwnerOnlyCapsuleError
}

private enum CapsuleFailureCase: String, CaseIterable, Sendable {
    case createAttempt, attemptCollision, openAttempt, validateAttempt, syncBase
    case createPending, pendingCollision, zeroWrite, interruptedWriteLimit, syncPending
    case renameFailure, renameCollision
    case syncLeaf, reopenFinal, validateFinal, initialOffset
    case shortRead, interruptedReadLimit, trailingByte, digestMismatch, finalOffset
    case finalSymlink, finalHardLink, reopenEscape
    case namedIdentityDrift, postReadMetadataDrift
    case closePendingWriter, closeAttemptDirectory

    var stage: InvestigationOwnerOnlyCapsuleFailureStage {
        switch self {
        case .createAttempt, .attemptCollision: .createAttempt
        case .openAttempt: .openAttempt
        case .validateAttempt: .validateAttempt
        case .syncBase: .syncBase
        case .createPending, .pendingCollision: .createPending
        case .zeroWrite, .interruptedWriteLimit: .writePending
        case .syncPending: .syncPending
        case .renameFailure, .renameCollision: .publish
        case .syncLeaf: .syncLeaf
        case .reopenFinal, .reopenEscape: .reopenFinal
        case .validateFinal, .finalSymlink, .finalHardLink: .validateFinal
        case .initialOffset: .initialOffset
        case .shortRead, .interruptedReadLimit: .readFinal
        case .trailingByte: .endOfFile
        case .digestMismatch: .contentDigest
        case .finalOffset: .finalOffset
        case .namedIdentityDrift, .postReadMetadataDrift: .validateFinal
        case .closePendingWriter: .closePendingWriter
        case .closeAttemptDirectory: .closeAttemptDirectory
        }
    }

    var afterAttempt: Bool { ![.createAttempt, .attemptCollision].contains(self) }
    var afterPending: Bool {
        ![.createAttempt, .attemptCollision, .openAttempt, .validateAttempt,
          .syncBase, .createPending, .pendingCollision]
            .contains(self)
    }
    var afterRename: Bool {
        [.syncLeaf, .reopenFinal, .reopenEscape, .validateFinal, .finalSymlink,
         .finalHardLink, .initialOffset, .shortRead,
         .interruptedReadLimit, .trailingByte, .digestMismatch, .finalOffset]
            .contains(self)
            || [.namedIdentityDrift, .postReadMetadataDrift,
                .closePendingWriter, .closeAttemptDirectory].contains(self)
    }

    var expectedCloseFailures: [InvestigationOwnerOnlyCapsuleCloseRole] {
        switch self {
        case .closePendingWriter: [.pendingWriter]
        case .closeAttemptDirectory: [.attemptDirectory]
        default: []
        }
    }

    var expectedCloseDescriptors: [Int32] {
        switch self {
        case .createAttempt, .attemptCollision, .openAttempt: []
        case .validateAttempt, .syncBase, .createPending, .pendingCollision: [30]
        case .zeroWrite, .interruptedWriteLimit, .syncPending, .renameFailure,
             .renameCollision,
             .syncLeaf, .reopenFinal, .reopenEscape:
            [31, 30]
        case .validateFinal, .finalSymlink, .finalHardLink, .initialOffset,
             .shortRead, .interruptedReadLimit, .trailingByte, .digestMismatch,
             .finalOffset, .namedIdentityDrift, .postReadMetadataDrift:
            [32, 31, 30]
        case .closePendingWriter: [31, 32, 30]
        case .closeAttemptDirectory: [31, 30, 32]
        }
    }

    func expectedEntries(
        request: InvestigationOwnerOnlyCapsulePublicationRequest
    ) -> [String] {
        if self == .attemptCollision {
            return [fixedLockName, request.attemptName]
        }
        if self == .pendingCollision {
            return [fixedLockName, request.attemptName,
                    InvestigationOwnerOnlyCapsulePublication.pendingName]
        }
        if self == .renameCollision {
            return [fixedLockName, request.attemptName,
                    InvestigationOwnerOnlyCapsulePublication.pendingName,
                    request.finalName]
        }
        if !afterAttempt { return [fixedLockName] }
        if afterRename { return [fixedLockName, request.attemptName, request.finalName] }
        if afterPending {
            return [fixedLockName, request.attemptName,
                    InvestigationOwnerOnlyCapsulePublication.pendingName]
        }
        return [fixedLockName, request.attemptName]
    }

    func expectedResidue(
        request: InvestigationOwnerOnlyCapsulePublicationRequest
    ) -> InvestigationOwnerOnlyCapsuleResidue {
        switch self {
        case .attemptCollision:
            return .collision(
                attempt: request.attemptName, pending: nil, final: nil,
                observed: [request.attemptName], observationComplete: true
            )
        case .pendingCollision:
            return .collision(
                attempt: request.attemptName,
                pending: InvestigationOwnerOnlyCapsulePublication.pendingName,
                final: nil,
                observed: [InvestigationOwnerOnlyCapsulePublication.pendingName],
                observationComplete: true
            )
        case .renameCollision:
            return .collision(
                attempt: request.attemptName,
                pending: InvestigationOwnerOnlyCapsulePublication.pendingName,
                final: request.finalName,
                observed: [
                    InvestigationOwnerOnlyCapsulePublication.pendingName,
                    request.finalName,
                ],
                observationComplete: true
            )
        default:
            return afterRename
                ? .published(attempt: request.attemptName, file: request.finalName)
                : afterPending
                    ? .pending(
                        attempt: request.attemptName,
                        file: InvestigationOwnerOnlyCapsulePublication.pendingName
                    )
                    : afterAttempt ? .attemptDirectory(request.attemptName) : .none
        }
    }
}

private enum CapsuleEvent: Equatable {
    case inventory(Int32, Int)
    case create(Int32, String, mode_t)
    case open(Int32, String, Int32, mode_t?)
    case metadata(Int32)
    case named(Int32, String, Int32)
    case descriptorFlags(Int32)
    case statusFlags(Int32)
    case permissions(Int32, mode_t)
    case acl(Int32), xattr(Int32), sync(Int32)
    case write(Int32, Int, Int64)
    case rename(Int32, String, String, Int32)
    case offset(Int32), read(Int32, Int, Int64), close(Int32)
}

private struct CapsuleModeCall: Equatable {
    let parent: Int32
    let name: String
    let mode: mode_t
}

private struct CapsuleOpenCall: Equatable {
    let parent: Int32
    let name: String
    let flags: Int32
    let mode: mode_t?
}

private struct CapsuleRenameCall: Equatable {
    let parent: Int32
    let oldName: String
    let newName: String
    let flags: Int32
}

private enum CapsuleIOResult: Sendable { case eintr, count(Int) }

private final class CapsuleSemanticSystem:
    InvestigationOwnerOnlyCapsuleSystem, @unchecked Sendable
{
    let bytes: Data
    let inventoryResult: InvestigationOwnerOnlyCapsuleInventory
    let failure: CapsuleFailureCase?
    var generation: UInt64 = 0
    var events: [CapsuleEvent] = []
    var entries: [String]
    var createCalls: [CapsuleModeCall] = []
    var openCalls: [CapsuleOpenCall] = []
    var renameCalls: [CapsuleRenameCall] = []
    var syncDescriptors: [Int32] = []
    var writeOffsets: [Int64] = []
    var writeMaximumCounts: [Int] = []
    var readOffsets: [Int64] = []
    var offsetDescriptors: [Int32] = []
    var closeDescriptors: [Int32] = []
    var writeScript: [CapsuleIOResult] = []
    var readScript: [CapsuleIOResult] = []
    var written = Data()
    var unlinkCount = 0
    var closeErrorDescriptors: Set<Int32> = []
    private var nextDescriptor: Int32 = 30
    private var roles: [Int32: Int] = [15: 0]
    private var offsetCallCount = 0
    private(set) var finalMetadataCount = 0
    private(set) var finalNamedCount = 0

    init(
        bytes: Data,
        inventory: InvestigationOwnerOnlyCapsuleInventory = .init(
            entries: [fixedLockName], reachedEnd: true),
        failure: CapsuleFailureCase? = nil
    ) {
        self.bytes = bytes
        inventoryResult = inventory
        entries = inventory.entries
        self.failure = failure
    }

    func inventory(baseDescriptor: Int32, maximumEntryCount: Int) throws
        -> InvestigationOwnerOnlyCapsuleInventory
    {
        events.append(.inventory(baseDescriptor, maximumEntryCount))
        return inventoryResult
    }

    func createDirectory(
        parentDescriptor: Int32, name: String, mode: mode_t
    ) throws {
        let call = CapsuleModeCall(parent: parentDescriptor, name: name, mode: mode)
        events.append(.create(parentDescriptor, name, mode)); createCalls.append(call)
        if failure == .createAttempt { throw systemError }
        if failure == .attemptCollision {
            entries.append(name)
            throw InvestigationOwnerOnlyCapsuleSystemError.errno(EEXIST)
        }
        entries.append(name)
    }

    func openComponent(
        parentDescriptor: Int32, name: String, flags: Int32, mode: mode_t?
    ) throws -> Int32 {
        let call = CapsuleOpenCall(
            parent: parentDescriptor, name: name, flags: flags, mode: mode)
        events.append(.open(parentDescriptor, name, flags, mode)); openCalls.append(call)
        if failure == .openAttempt && name.hasPrefix("attempt-") { throw systemError }
        if failure == .createPending && name == "capsule.pending" { throw systemError }
        if failure == .pendingCollision && name == "capsule.pending" {
            entries.append(name)
            throw InvestigationOwnerOnlyCapsuleSystemError.errno(EEXIST)
        }
        if name == "capsule.pending" { entries.append(name) }
        if (failure == .reopenFinal || failure == .reopenEscape),
           name.hasPrefix("projected-cohort-")
        {
            throw InvestigationOwnerOnlyCapsuleSystemError.errno(
                failure == .reopenEscape ? ENOTCAPABLE : EIO
            )
        }
        let value = nextDescriptor; nextDescriptor += 1
        roles[value] = name == "capsule.pending" ? 2
            : name.hasPrefix("projected-cohort-") ? 3 : 1
        return value
    }

    func metadata(descriptor: Int32) throws -> InvestigationMachineGateMetadataSnapshot {
        events.append(.metadata(descriptor))
        let role = roles[descriptor] ?? 0
        if failure == .validateAttempt && role == 1 { return directory(mode: 0o755) }
        if failure == .validateFinal && role == 3 { return file(inode: 99) }
        if failure == .finalSymlink && role == 3 { return file(type: .other) }
        if failure == .finalHardLink && role == 3 { return file(linkCount: 2) }
        if role == 3 {
            finalMetadataCount += 1
            if failure == .postReadMetadataDrift && finalMetadataCount == 2 {
                return file(inode: 99)
            }
        }
        return role == 1 ? directory() : file()
    }

    func namedMetadata(
        parentDescriptor: Int32, name: String, flags: Int32
    ) throws -> InvestigationMachineGateMetadataSnapshot {
        events.append(.named(parentDescriptor, name, flags))
        if name.hasPrefix("projected-cohort-") {
            finalNamedCount += 1
            if failure == .namedIdentityDrift && finalNamedCount == 2 {
                return file(inode: 99)
            }
            if failure == .finalSymlink { return file(type: .other) }
            if failure == .finalHardLink { return file(linkCount: 2) }
        }
        return name.hasPrefix("attempt-") ? directory() : file()
    }

    func descriptorFlags(_ descriptor: Int32) throws -> Int32 {
        events.append(.descriptorFlags(descriptor)); return FD_CLOEXEC
    }
    func descriptorStatusFlags(_ descriptor: Int32) throws -> Int32 {
        events.append(.statusFlags(descriptor))
        return O_NONBLOCK | ((roles[descriptor] ?? 0) == 2 ? O_WRONLY : O_RDONLY)
    }
    func setPermissions(descriptor: Int32, mode: mode_t) throws {
        events.append(.permissions(descriptor, mode))
    }
    func extendedACLIsEmpty(descriptor: Int32) throws -> Bool {
        events.append(.acl(descriptor)); return true
    }
    func extendedAttributeNames(descriptor: Int32) throws -> [String] {
        events.append(.xattr(descriptor)); return []
    }
    func synchronize(descriptor: Int32) throws {
        events.append(.sync(descriptor)); syncDescriptors.append(descriptor)
        if failure == .syncBase && descriptor == 15 { throw systemError }
        if failure == .syncPending && descriptor == 31 { throw systemError }
        if failure == .syncLeaf && descriptor == 30 { throw systemError }
    }
    func write(descriptor: Int32, bytes: Data, offset: Int64) throws -> Int {
        events.append(.write(descriptor, bytes.count, offset))
        writeOffsets.append(offset); writeMaximumCounts.append(bytes.count)
        let result = writeScript.isEmpty ? nil : writeScript.removeFirst()
        if case .eintr = result { throw InvestigationOwnerOnlyCapsuleSystemError.errno(EINTR) }
        if failure == .zeroWrite { return 0 }
        if failure == .interruptedWriteLimit {
            throw InvestigationOwnerOnlyCapsuleSystemError.errno(EINTR)
        }
        let count: Int = if case .count(let count) = result { min(count, bytes.count) }
            else { bytes.count }
        written.append(bytes.prefix(count)); return count
    }
    func rename(
        parentDescriptor: Int32, oldName: String, newName: String, flags: Int32
    ) throws {
        events.append(.rename(parentDescriptor, oldName, newName, flags))
        renameCalls.append(.init(
            parent: parentDescriptor, oldName: oldName, newName: newName, flags: flags))
        if failure == .renameFailure { throw systemError }
        if failure == .renameCollision {
            entries.append(newName)
            throw InvestigationOwnerOnlyCapsuleSystemError.errno(EEXIST)
        }
        entries.removeAll { $0 == oldName }; entries.append(newName)
    }
    func offset(descriptor: Int32) throws -> Int64 {
        events.append(.offset(descriptor)); offsetDescriptors.append(descriptor)
        offsetCallCount += 1
        if failure == .initialOffset && offsetCallCount == 1 { return 1 }
        if failure == .finalOffset && offsetCallCount == 2 { return 1 }
        return 0
    }
    func read(descriptor: Int32, maximumByteCount: Int, offset: Int64) throws -> Data {
        events.append(.read(descriptor, maximumByteCount, offset)); readOffsets.append(offset)
        let result = readScript.isEmpty ? nil : readScript.removeFirst()
        if case .eintr = result { throw InvestigationOwnerOnlyCapsuleSystemError.errno(EINTR) }
        if failure == .interruptedReadLimit {
            throw InvestigationOwnerOnlyCapsuleSystemError.errno(EINTR)
        }
        if offset == Int64(bytes.count) {
            return failure == .trailingByte ? Data([0xff]) : Data()
        }
        if failure == .shortRead { return Data() }
        let start = Int(offset)
        let scripted: Int? = if case .count(let count) = result { count } else { nil }
        let count = min(scripted ?? maximumByteCount, maximumByteCount, bytes.count - start)
        var output = Data(bytes[start..<(start + count)])
        if failure == .digestMismatch && start == 0 { output[0] ^= 0xff }
        return output
    }
    func close(descriptor: Int32) throws {
        events.append(.close(descriptor)); closeDescriptors.append(descriptor)
        if closeErrorDescriptors.contains(descriptor) { throw systemError }
        if failure == .closePendingWriter && descriptor == 31 { throw systemError }
        if failure == .closeAttemptDirectory && descriptor == 30 { throw systemError }
    }

    private func directory(mode: mode_t = 0o700)
        -> InvestigationMachineGateMetadataSnapshot
    {
        .init(
            device: 1, inode: 11, generation: generation, fileType: .directory,
            ownerUID: 501, ownerGID: 20, permissions: mode, linkCount: 1,
            size: 0, flags: 0)
    }
    private func file(
        inode: UInt64 = 12,
        type: InvestigationMachineGateFileType = .regularFile,
        linkCount: UInt64 = 1
    )
        -> InvestigationMachineGateMetadataSnapshot
    {
        .init(
            device: 1, inode: inode, generation: generation, fileType: type,
            ownerUID: 501, ownerGID: 20, permissions: 0o600,
            linkCount: linkCount,
            size: Int64(bytes.count), flags: 0)
    }
    private var systemError: InvestigationOwnerOnlyCapsuleSystemError { .errno(EIO) }
}

private let fixedLockName = InvestigationMachineGateOwnershipAcquirer.lockName

private func canonicalProjectedInput() throws -> InvestigationProjectedCohortInput {
    let capsule = try InvestigationCohortCapsule(
        outerAttemptUUID: capsuleUUID(1),
        epochs: try (0..<8).map { value in
            let configuration = Data("configuration-\(value)".utf8)
            return try InvestigationCohortEpoch(
                ordinal: UInt32(value), epochUUID: capsuleUUID(UInt8(0x10 + value)),
                scenario: InvestigationHandoffScenario(rawValue: UInt32(value + 1))!,
                configurationNonce: capsuleUUID(UInt8(0x20 + value)),
                configuration: configuration,
                configurationSHA256: .hashing(configuration),
                signedRuntimeBindingSHA256: try .init(
                    rawBytes: Data(repeating: UInt8(0x40 + value), count: 32))
            )
        }
    )
    return try InvestigationProjectedCohortInput(
        capsule: capsule, projections: try capsule.epochs.map { epoch in
            let byte = UInt8(epoch.ordinal)
            func digest(_ value: UInt8) throws -> InvestigationHandoffSHA256 {
                try .init(rawBytes: Data(repeating: value, count: 32))
            }
            return try InvestigationInstalledL2IdentityProjection(
                epochUUID: epoch.epochUUID,
                configurationNonce: epoch.configurationNonce,
                configurationValidBefore: .init(rawValue: 2_000_000_000_000_000 + Int64(byte)),
                configurationSHA256: epoch.configurationSHA256,
                signedRuntimeBindingSHA256: epoch.signedRuntimeBindingSHA256,
                appExecutableSHA256: digest(0x51),
                appBundleIdentifier: InvestigationInstalledL2IdentityProjection.fixedAppBundleIdentifier,
                helperExecutableSHA256: digest(0x52),
                helperServiceIdentifier: InvestigationInstalledL2IdentityProjection.fixedHelperServiceIdentifier,
                machineDriverExecutableSHA256: digest(0x53),
                machineDriverSigningIdentifier: InvestigationInstalledL2IdentityProjection.fixedMachineDriverSigningIdentifier,
                machineDriverDesignatedRequirementSHA256: digest(0x54),
                machineDriverCodeDirectoryHash: Data(repeating: 0x55, count: 20),
                machineClaimServiceIdentifier: InvestigationInstalledL2IdentityProjection.fixedMachineClaimServiceIdentifier)
        })
}

private func capsuleUUID(_ byte: UInt8) -> UUID {
    UUID(uuidString: "00000000-0000-0000-0000-0000000000"
        + String(format: "%02x", byte))!
}

private final class CapsuleOwnershipSystem:
    InvestigationMachineGateOwnershipSystem, @unchecked Sendable
{
    private var nextFD: Int32 = 10
    private var roleByFD: [Int32: GateRole] = [:]
    private var closed: Set<Int32> = []
    var identityCalls = 0
    var closeRoles: [GateRole] = []
    var closeErrorRoles: Set<GateRole> = []
    var everyOpenedDescriptorClosedOnce: Bool {
        Set(roleByFD.keys) == closed
    }

    func identitySnapshot(bufferByteCount: Int) throws -> InvestigationMachineGateIdentitySnapshot {
        identityCalls += 1
        return .init(realUID: 501, effectiveUID: 501, accountUID: 501, realGID: 20, effectiveGID: 20, accountGID: 20, homePath: "/Users/fixture")
    }
    func createDirectory(parentDescriptor: Int32, name: String, mode: mode_t) throws {}
    func openComponent(parentDescriptor: Int32?, name: String, flags: Int32, mode: mode_t?) throws -> Int32 {
        let parent = parentDescriptor.flatMap { roleByFD[$0] }
        let role: GateRole = if parent == nil { .root }
            else if parent == .root { .users }
            else if parent == .users { .home }
            else if parent == .home { .library }
            else if parent == .library { .caches }
            else if parent == .caches { .base }
            else { .lock }
        let fd = nextFD; nextFD += 1; roleByFD[fd] = role; return fd
    }
    func metadata(descriptor: Int32) throws -> InvestigationMachineGateMetadataSnapshot { metadata(roleByFD[descriptor]!) }
    func namedMetadata(parentDescriptor: Int32, name: String, flags: Int32) throws -> InvestigationMachineGateMetadataSnapshot {
        metadata(name == fixedBaseRelativePath ? .base : .lock)
    }
    func descriptorFlags(_ descriptor: Int32) throws -> Int32 { FD_CLOEXEC }
    func descriptorStatusFlags(_ descriptor: Int32) throws -> Int32 {
        O_NONBLOCK | (roleByFD[descriptor] == .lock ? O_RDWR : O_RDONLY)
    }
    func setPermissions(descriptor: Int32, mode: mode_t) throws {}
    func extendedACLIsEmpty(descriptor: Int32) throws -> Bool { true }
    func extendedAttributeNames(descriptor: Int32) throws -> [String] { [] }
    func acquireExclusiveNonblockingLock(descriptor: Int32) throws {}
    func close(descriptor: Int32) throws {
        guard closed.insert(descriptor).inserted else { throw InvestigationMachineGateSystemError.errno(EBADF) }
        let role = roleByFD[descriptor]!
        closeRoles.append(role)
        if closeErrorRoles.contains(role) {
            throw InvestigationMachineGateSystemError.errno(EIO)
        }
    }
    func makeOwnershipMutex() -> any InvestigationMachineGateOwnershipMutex { NSLock() }

    private func metadata(_ role: GateRole) -> InvestigationMachineGateMetadataSnapshot {
        .init(
            device: 1, inode: UInt64(role.rawValue.hashValue.magnitude + 1),
            generation: 0, fileType: role == .lock ? .regularFile : .directory,
            ownerUID: 501, ownerGID: 20, permissions: role == .lock ? 0o600 : 0o700,
            linkCount: 1, size: 0, flags: 0)
    }
}

private final class CapsuleFixedBorrower:
    InvestigationOwnerOnlyCapsuleBorrowing, @unchecked Sendable
{
    let throwsOnHandoff: Bool
    let mismatchesProof: Bool
    var descriptors: [Int32] = []
    var outerAttemptUUIDs: [UUID] = []

    init(
        throwsOnHandoff: Bool = false, mismatchesProof: Bool = false
    ) {
        self.throwsOnHandoff = throwsOnHandoff
        self.mismatchesProof = mismatchesProof
    }

    func handoffToFixedGate(
        descriptor: Int32, outerAttemptUUID: UUID,
        identity: InvestigationOwnerOnlyCapsuleNodeIdentity,
        digest: InvestigationHandoffSHA256
    ) throws -> InvestigationOwnerOnlyCapsuleExactGateReapedProof {
        descriptors.append(descriptor)
        outerAttemptUUIDs.append(outerAttemptUUID)
        if throwsOnHandoff { throw CapsuleFixedBorrowerError.failed }
        return .makeForFixedLauncher(
            outerAttemptUUID: mismatchesProof ? capsuleUUID(0xfe) : outerAttemptUUID,
            digest: digest,
            identity: identity
        )
    }
}

private enum CapsuleFixedBorrowerError: Error { case failed }

private enum GateRole: String { case root, users, home, library, caches, base, lock }
private let fixedBaseRelativePath = "Users/fixture/Library/Caches/"
    + InvestigationMachineGateOwnershipAcquirer.baseName
