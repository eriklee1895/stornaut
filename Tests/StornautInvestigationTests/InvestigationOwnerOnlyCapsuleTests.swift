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

    @Test
    func filesystemFlagsPinTheIndependentDarwinSafetyContract() {
        #expect(InvestigationOwnerOnlyCapsulePublication.attemptDirectoryFlags
            == Int32(
                O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NONBLOCK
                    | O_NOFOLLOW_ANY | O_RESOLVE_BENEATH | O_UNIQUE
            ))
        #expect(InvestigationOwnerOnlyCapsulePublication.pendingWriterFlags
            == Int32(
                O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NONBLOCK
                    | O_NOFOLLOW_ANY | O_RESOLVE_BENEATH | O_UNIQUE
            ))
        #expect(InvestigationOwnerOnlyCapsulePublication.finalReaderFlags
            == Int32(
                O_RDONLY | O_CLOEXEC | O_NONBLOCK | O_NOFOLLOW_ANY
                    | O_RESOLVE_BENEATH | O_UNIQUE
            ))
        #expect(InvestigationOwnerOnlyCapsulePublication.namedFlags
            == Int32(
                AT_SYMLINK_NOFOLLOW_ANY | AT_RESOLVE_BENEATH | AT_UNIQUE
            ))
        #expect(InvestigationOwnerOnlyCapsuleSettlement.fileUnlinkFlags
            == Int32(
                AT_NODELETEBUSY | AT_UNIQUE | AT_SYMLINK_NOFOLLOW_ANY
                    | AT_RESOLVE_BENEATH
            ))
        #expect(InvestigationOwnerOnlyCapsuleSettlement.directoryUnlinkFlags
            == Int32(
                AT_NODELETEBUSY | AT_UNIQUE | AT_SYMLINK_NOFOLLOW_ANY
                    | AT_RESOLVE_BENEATH | AT_REMOVEDIR
            ))
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
            error: .staleRecoveryFailed(
                stage: .inventory,
                residue: .stale(
                    entries: [fixedLockName], observationComplete: false
                ),
                closeFailures: [])),
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
    func exactGateReapedProofSettlesPublishedNodeOnce() throws {
        let bytes = try canonicalProjectedInput().encoded()
        let request = try InvestigationOwnerOnlyCapsulePublicationRequest(
            canonicalBytes: bytes
        )
        let ownership = CapsuleOwnershipSystem()
        let system = CapsuleSemanticSystem(bytes: bytes)
        let borrower = CapsuleFixedBorrower()
        let lease = try InvestigationOwnerOnlyCapsulePublisher(
            ownershipSystem: ownership, capsuleSystem: system, borrower: borrower
        ).publish(bytes)
        let proof = try lease.handoffOnce()

        #expect(try lease.settle(exactGateReaped: proof) == .removed)
        #expect(system.unlinkCalls.count == 1)
        #expect(system.removeDirectoryCalls.count == 1)
        #expect(system.entries == [fixedLockName])
        #expect(ownership.closeRoles.suffix(2) == [.base, .lock])
        #expect(throws: InvestigationOwnerOnlyCapsuleError.alreadyTerminal(
            .published(attempt: request.attemptName, file: request.finalName)
        )) {
            _ = try lease.settle(exactGateReaped: proof)
        }
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

    @Test
    func neverHandedOffProofSettlesPublishedNodeOnce() throws {
        let fixture = try CapsuleSettlementFixture()
        let proof = try fixture.lease.finishWithoutHandoff()
        fixture.system.staleLeaves[fixture.request.attemptName] = .final(
            fixture.request.finalName
        )

        let result = try fixture.lease.settle(neverHandedOff: proof)

        #expect(result == .removed)
        #expect(fixture.system.unlinkCalls.count == 1)
        #expect(fixture.system.removeDirectoryCalls.count == 1)
        #expect(fixture.system.entries == [fixedLockName])
        #expect(fixture.ownership.closeRoles.suffix(2) == [.base, .lock])
        #expect(throws: InvestigationOwnerOnlyCapsuleError.alreadyTerminal(
            fixture.publishedResidue
        )) {
            _ = try fixture.lease.settle(neverHandedOff: proof)
        }
    }

    @Test
    func validEmptyStaleLeafRecoversBeforeFreshPublication() throws {
        let bytes = try canonicalProjectedInput().encoded()
        let stale = "attempt-00000000-0000-0000-0000-0000000000fe"
        let ownership = CapsuleOwnershipSystem()
        let system = CapsuleSemanticSystem(
            bytes: bytes,
            inventory: .init(entries: [fixedLockName, stale], reachedEnd: true)
        )
        system.staleLeaves[stale] = .empty

        let lease = try InvestigationOwnerOnlyCapsulePublisher(
            ownershipSystem: ownership, capsuleSystem: system
        ).publish(bytes)

        #expect(system.recoveredAttemptNames == [stale])
        #expect(system.events.firstIndex(of: .unlink(15, stale,
            InvestigationOwnerOnlyCapsuleSettlement.directoryUnlinkFlags))
            != nil)
        _ = try lease.finishWithoutHandoff()
    }

    @Test(arguments: CapsuleRecoverableStaleLeaf.allCases)
    fileprivate func validStalePayloadRecoversBeforeFreshPublication(
        _ value: CapsuleRecoverableStaleLeaf
    ) throws {
        let bytes = try canonicalProjectedInput().encoded()
        let request = try InvestigationOwnerOnlyCapsulePublicationRequest(
            canonicalBytes: bytes
        )
        let stale = request.attemptName
        let ownership = CapsuleOwnershipSystem()
        let system = CapsuleSemanticSystem(
            bytes: bytes,
            inventory: .init(entries: [fixedLockName, stale], reachedEnd: true)
        )
        let expectedFile = value.install(
            in: system, attempt: stale, canonicalFinalName: request.finalName
        )

        let lease = try InvestigationOwnerOnlyCapsulePublisher(
            ownershipSystem: ownership, capsuleSystem: system
        ).publish(bytes)

        #expect(system.unlinkCalls.contains {
            $0.name == expectedFile
                && $0.flags == InvestigationOwnerOnlyCapsuleSettlement.fileUnlinkFlags
        })
        #expect(system.removeDirectoryCalls.contains(.init(
            parent: 15, name: stale,
            flags: InvestigationOwnerOnlyCapsuleSettlement.directoryUnlinkFlags
        )))
        #expect(system.recoveredAttemptNames == [stale])
        _ = try lease.finishWithoutHandoff()
    }

    @Test(arguments: CapsuleRecoverableStaleLeaf.allCases)
    fileprivate func stalePayloadMustMatchAttemptDirectoryUUID(
        _ value: CapsuleRecoverableStaleLeaf
    ) throws {
        let bytes = try canonicalProjectedInput().encoded()
        let request = try InvestigationOwnerOnlyCapsulePublicationRequest(
            canonicalBytes: bytes
        )
        let stale = "attempt-00000000-0000-0000-0000-0000000000fe"
        let ownership = CapsuleOwnershipSystem()
        let system = CapsuleSemanticSystem(
            bytes: bytes,
            inventory: .init(entries: [fixedLockName, stale], reachedEnd: true)
        )
        _ = value.install(
            in: system, attempt: stale, canonicalFinalName: request.finalName
        )

        #expect(throws: InvestigationOwnerOnlyCapsuleError.staleRecoveryFailed(
            stage: .classifyStale,
            residue: .stale(entries: [stale], observationComplete: true),
            closeFailures: []
        )) {
            _ = try InvestigationOwnerOnlyCapsulePublisher(
                ownershipSystem: ownership, capsuleSystem: system
            ).publish(bytes)
        }
        #expect(system.unlinkCalls.isEmpty)
        #expect(system.removeDirectoryCalls.isEmpty)
        #expect(system.everyOpenedDescriptorClosedOnce)
        #expect(system.createCalls.isEmpty)
    }

    @Test
    func allStaleRootsAreClassifiedBeforeMalformedSecondBlocksMutation() throws {
        let bytes = try canonicalProjectedInput().encoded()
        let request = try InvestigationOwnerOnlyCapsulePublicationRequest(
            canonicalBytes: bytes
        )
        let first = request.attemptName
        let second = "attempt-00000000-0000-0000-0000-0000000000fb"
        let ownership = CapsuleOwnershipSystem()
        let originalEntries = [fixedLockName, second, first]
        let system = CapsuleSemanticSystem(
            bytes: bytes,
            inventory: .init(entries: originalEntries, reachedEnd: true)
        )
        system.staleLeaves[first] = .final(request.finalName)
        system.staleLeaves[second] = .other("unexpected")

        #expect(throws: InvestigationOwnerOnlyCapsuleError.staleRecoveryFailed(
            stage: .classifyStale,
            residue: .stale(
                entries: [first, second], observationComplete: true
            ),
            closeFailures: []
        )) {
            _ = try InvestigationOwnerOnlyCapsulePublisher(
                ownershipSystem: ownership, capsuleSystem: system
            ).publish(bytes)
        }

        #expect(system.unlinkCalls.isEmpty)
        #expect(system.removeDirectoryCalls.isEmpty)
        #expect(system.everyOpenedDescriptorClosedOnce)
        #expect(system.createCalls.isEmpty)
        #expect(system.entries == originalEntries)
        let firstClassified = try #require(
            system.events.firstIndex(of: .close(30))
        )
        let secondInspected = try #require(
            system.events.firstIndex(of: .inventory(32, 2))
        )
        #expect(firstClassified < secondInspected)
    }

    @Test
    func transientBusyWaitsThenFullyRevalidatesBeforeOneRetry() throws {
        let fixture = try CapsuleSettlementFixture()
        let proof = try fixture.lease.finishWithoutHandoff()
        fixture.system.unlinkScript = [.failure(EBUSY)]
        let eventStart = fixture.system.events.count

        let result = try fixture.lease.settle(neverHandedOff: proof)

        #expect(result == .removed)
        let events = Array(fixture.system.events[eventStart...])
        let fileUnlinks = events.indices.filter { index in
            if case .unlink(
                _, fixture.request.finalName,
                InvestigationOwnerOnlyCapsuleSettlement.fileUnlinkFlags
            ) = events[index] { return true }
            return false
        }
        #expect(fileUnlinks.count == 2)
        let first = try #require(fileUnlinks.first)
        let second = try #require(fileUnlinks.last)
        let retryValidation = Array(events[(first + 1)..<second])
        #expect(retryValidation.contains(.wait(1_000_000)))
        #expect(retryValidation.contains { event in
            if case .open(
                _, fixture.request.finalName,
                InvestigationOwnerOnlyCapsulePublication.finalReaderFlags, nil
            ) = event { return true }
            return false
        })
        #expect(retryValidation.contains {
            if case .metadata = $0 { return true }; return false
        })
        #expect(retryValidation.contains { event in
            if case .named(
                _, fixture.request.finalName,
                InvestigationOwnerOnlyCapsulePublication.namedFlags
            ) = event { return true }
            return false
        })
        #expect(retryValidation.contains {
            if case .descriptorFlags = $0 { return true }; return false
        })
        #expect(retryValidation.contains {
            if case .statusFlags = $0 { return true }; return false
        })
        #expect(retryValidation.contains {
            if case .acl = $0 { return true }; return false
        })
        #expect(retryValidation.contains {
            if case .xattr = $0 { return true }; return false
        })
        #expect(retryValidation.contains {
            if case .read = $0 { return true }; return false
        })
        #expect(retryValidation.contains {
            if case .close = $0 { return true }; return false
        })
    }

    @Test
    func directoryBusyRetryReopensAndFullyRevalidatesEmptyLeaf() throws {
        let fixture = try CapsuleSettlementFixture()
        let proof = try fixture.lease.finishWithoutHandoff()
        fixture.system.unlinkScript = [.success, .failure(EBUSY), .success]
        let eventStart = fixture.system.events.count

        #expect(try fixture.lease.settle(neverHandedOff: proof) == .removed)

        let events = Array(fixture.system.events[eventStart...])
        let directoryUnlinks = events.indices.filter { index in
            if case .unlink(
                15, fixture.request.attemptName,
                InvestigationOwnerOnlyCapsuleSettlement.directoryUnlinkFlags
            ) = events[index] { return true }
            return false
        }
        #expect(directoryUnlinks.count == 2)
        let first = try #require(directoryUnlinks.first)
        let second = try #require(directoryUnlinks.last)
        let retryValidation = Array(events[(first + 1)..<second])
        #expect(retryValidation.contains(.wait(1_000_000)))
        #expect(retryValidation.contains { event in
            if case .open(
                15, fixture.request.attemptName,
                InvestigationOwnerOnlyCapsulePublication.attemptDirectoryFlags, nil
            ) = event { return true }
            return false
        })
        #expect(retryValidation.contains {
            if case .metadata = $0 { return true }; return false
        })
        #expect(retryValidation.contains(.named(
            15, fixture.request.attemptName,
            InvestigationOwnerOnlyCapsulePublication.namedFlags
        )))
        #expect(retryValidation.contains {
            if case .descriptorFlags = $0 { return true }; return false
        })
        #expect(retryValidation.contains {
            if case .statusFlags = $0 { return true }; return false
        })
        #expect(retryValidation.contains {
            if case .acl = $0 { return true }; return false
        })
        #expect(retryValidation.contains {
            if case .xattr = $0 { return true }; return false
        })
        #expect(retryValidation.contains { event in
            if case .inventory(_, 1) = event { return true }; return false
        })
        #expect(retryValidation.contains {
            if case .close = $0 { return true }; return false
        })
    }

    @Test(arguments: CapsuleDirectoryRetryDrift.allCases)
    fileprivate func directoryBusyRetryRejectsMetadataOrContentDrift(
        _ drift: CapsuleDirectoryRetryDrift
    ) throws {
        let fixture = try CapsuleSettlementFixture()
        let proof = try fixture.lease.finishWithoutHandoff()
        fixture.system.directoryRetryDrift = drift
        fixture.system.unlinkScript = [.success, .failure(EBUSY), .success]

        let result = try fixture.lease.settle(neverHandedOff: proof)

        #expect(result == .settledResidue(
            stage: .removeDirectory,
            residue: .stale(
                entries: [fixture.request.attemptName], observationComplete: true
            ),
            closeFailures: [], ownershipReleaseUncertain: false
        ))
        #expect(fixture.system.removeDirectoryCalls.count == 1)
        #expect(fixture.ownership.closeRoles.suffix(2) == [.base, .lock])
    }

    @Test
    func staleRemovalOpenFailurePreservesLiveResidue() throws {
        let bytes = try canonicalProjectedInput().encoded()
        let request = try InvestigationOwnerOnlyCapsulePublicationRequest(
            canonicalBytes: bytes
        )
        let ownership = CapsuleOwnershipSystem()
        let system = CapsuleSemanticSystem(
            bytes: bytes,
            inventory: .init(
                entries: [fixedLockName, request.attemptName], reachedEnd: true
            )
        )
        system.staleLeaves[request.attemptName] = .final(request.finalName)
        system.failAttemptOpenAtCount[request.attemptName] = 2

        #expect(throws: InvestigationOwnerOnlyCapsuleError.staleRecoveryFailed(
            stage: .classifyStale,
            residue: .stale(
                entries: [request.attemptName], observationComplete: true
            ),
            closeFailures: []
        )) {
            _ = try InvestigationOwnerOnlyCapsulePublisher(
                ownershipSystem: ownership, capsuleSystem: system
            ).publish(bytes)
        }
        #expect(system.unlinkCalls.isEmpty)
        #expect(system.removeDirectoryCalls.isEmpty)
        #expect(system.everyOpenedDescriptorClosedOnce)
    }

    @Test(arguments: [
        CapsuleStaleCloseFailureCase(
            descriptor: 31, stage: .closeStaleReader, role: .staleReader
        ),
        CapsuleStaleCloseFailureCase(
            descriptor: 30, stage: .closeStaleDirectory, role: .staleDirectory
        ),
    ])
    fileprivate func staleClassificationReportsExactCloseFailure(
        _ value: CapsuleStaleCloseFailureCase
    ) throws {
        let bytes = try canonicalProjectedInput().encoded()
        let request = try InvestigationOwnerOnlyCapsulePublicationRequest(
            canonicalBytes: bytes
        )
        let ownership = CapsuleOwnershipSystem()
        let system = CapsuleSemanticSystem(
            bytes: bytes,
            inventory: .init(
                entries: [fixedLockName, request.attemptName], reachedEnd: true
            )
        )
        system.staleLeaves[request.attemptName] = .final(request.finalName)
        system.closeErrorDescriptors = [value.descriptor]

        #expect(throws: InvestigationOwnerOnlyCapsuleError.staleRecoveryFailed(
            stage: value.stage,
            residue: .stale(
                entries: [request.attemptName], observationComplete: true
            ),
            closeFailures: [value.role]
        )) {
            _ = try InvestigationOwnerOnlyCapsulePublisher(
                ownershipSystem: ownership, capsuleSystem: system
            ).publish(bytes)
        }
        #expect(system.closeDescriptors == [31, 30])
        #expect(system.everyOpenedDescriptorClosedOnce)
        #expect(system.unlinkCalls.isEmpty)
        #expect(system.removeDirectoryCalls.isEmpty)
    }

    @Test(arguments: CapsuleSettlementClockCase.allCases)
    fileprivate func clockFailuresPreserveStagePriorityResidueAndCleanup(
        _ value: CapsuleSettlementClockCase
    ) throws {
        let fixture = try CapsuleSettlementFixture()
        let proof = try fixture.lease.finishWithoutHandoff()
        value.configure(
            fixture.system, attempt: fixture.request.attemptName
        )
        let eventStart = fixture.system.events.count

        let result = try fixture.lease.settle(neverHandedOff: proof)

        #expect(result == .settledResidue(
            stage: value.expectedStage,
            residue: .stale(
                entries: [fixture.request.attemptName], observationComplete: true
            ),
            closeFailures: [], ownershipReleaseUncertain: false
        ))
        let events = Array(fixture.system.events[eventStart...])
        #expect(events.filter { if case .clock = $0 { return true }; return false }
            .count == value.expectedClockCount)
        #expect(!events.contains { if case .wait = $0 { return true }; return false })
        #expect(fixture.system.unlinkCalls.count == value.expectedFileUnlinkCount)
        #expect(fixture.system.removeDirectoryCalls.count
            == value.expectedDirectoryUnlinkCount)
        #expect(fixture.system.closeDescriptors == value.expectedCloseDescriptors)
        #expect(fixture.system.everyOpenedDescriptorClosedOnce)
        #expect(fixture.ownership.closeRoles.suffix(2) == [.base, .lock])
        #expect(fixture.ownership.everyOpenedDescriptorClosedOnce)

        if let lastUnlink = events.lastIndex(where: {
            if case .unlink = $0 { return true }; return false
        }) {
            let afterBusy = events[(lastUnlink + 1)...]
            #expect(!afterBusy.contains { event in
                if case .open = event { return true }; return false
            })
        } else {
            #expect(!events.contains { event in
                if case .open = event { return true }; return false
            })
        }
    }

    @Test
    func deadlineEqualityReturnsResidueBeforeAnyUnlinkAttempt() throws {
        let fixture = try CapsuleSettlementFixture()
        let proof = try fixture.lease.finishWithoutHandoff()
        let start: UInt64 = 10_000
        fixture.system.monotonicValues = [start, start + 5_000_000_000]

        let result = try fixture.lease.settle(neverHandedOff: proof)

        #expect(result == .settledResidue(
            stage: .unlinkFile,
            residue: .stale(
                entries: [fixture.request.attemptName], observationComplete: true
            ),
            closeFailures: [], ownershipReleaseUncertain: false
        ))
        #expect(fixture.system.unlinkCalls.isEmpty)
        #expect(fixture.system.removeDirectoryCalls.isEmpty)
        #expect(!fixture.system.events.contains {
            if case .wait = $0 { return true }; return false
        })
    }

    @Test
    func deadlineEqualityAfterBusyWaitStopsBeforeRevalidation() throws {
        let fixture = try CapsuleSettlementFixture()
        let proof = try fixture.lease.finishWithoutHandoff()
        let start: UInt64 = 10_000
        fixture.system.monotonicValues = [
            start, start + 1,
            start + 2,
            start + 5_000_000_000,
        ]
        fixture.system.unlinkScript = [.failure(EBUSY)]
        let eventStart = fixture.system.events.count

        let result = try fixture.lease.settle(neverHandedOff: proof)

        #expect(result == .settledResidue(
            stage: .unlinkFile,
            residue: .stale(
                entries: [fixture.request.attemptName], observationComplete: true
            ),
            closeFailures: [], ownershipReleaseUncertain: false
        ))
        let events = Array(fixture.system.events[eventStart...])
        #expect(fixture.system.unlinkCalls.count == 1)
        #expect(events.filter {
            if case .wait = $0 { return true }; return false
        }.count == 1)
        let firstUnlink = try #require(events.firstIndex { event in
            if case .unlink(
                _, fixture.request.finalName,
                InvestigationOwnerOnlyCapsuleSettlement.fileUnlinkFlags
            ) = event { return true }
            return false
        })
        let afterBusy = Array(events[(firstUnlink + 1)...])
        #expect(!afterBusy.contains { event in
            if case .open(
                _, fixture.request.finalName,
                InvestigationOwnerOnlyCapsulePublication.finalReaderFlags, nil
            ) = event { return true }
            return false
        })
        #expect(InvestigationOwnerOnlyCapsuleSettlement.deadlineNanoseconds
            == 5_000_000_000)
    }

    @Test
    func busyRetryBeyondFormerCountSucceedsBeforeDeadlineAndRevalidatesEveryTime() throws {
        let fixture = try CapsuleSettlementFixture()
        let proof = try fixture.lease.finishWithoutHandoff()
        let start: UInt64 = 10_000
        let busyCount = 65
        fixture.system.monotonicValues = (0..<(busyCount * 2 + 4)).map {
            start + UInt64($0)
        }
        fixture.system.unlinkScript = Array(
            repeating: .failure(EBUSY),
            count: busyCount
        )
        let eventStart = fixture.system.events.count

        let result = try fixture.lease.settle(neverHandedOff: proof)

        #expect(result == .removed)
        let events = Array(fixture.system.events[eventStart...])
        let fileUnlinks = events.indices.filter { index in
            if case .unlink(
                _, fixture.request.finalName,
                InvestigationOwnerOnlyCapsuleSettlement.fileUnlinkFlags
            ) = events[index] { return true }
            return false
        }
        #expect(fileUnlinks.count == busyCount + 1)
        #expect(events.filter {
            if case .wait = $0 { return true }; return false
        }.count == busyCount)
        guard fileUnlinks.count == busyCount + 1 else { return }
        for retry in 0..<busyCount {
            let validation = events[(fileUnlinks[retry] + 1)..<fileUnlinks[retry + 1]]
            #expect(fileRetryPerformedFullRevalidation(
                validation, finalName: fixture.request.finalName
            ))
        }
    }

    @Test
    func persistentBusyFailsOnlyWhenAbsoluteDeadlineIsReached() throws {
        let fixture = try CapsuleSettlementFixture()
        let proof = try fixture.lease.finishWithoutHandoff()
        let start: UInt64 = 10_000
        let busyCount = 66
        fixture.system.monotonicValues = [start]
            + (1..<(busyCount * 3)).map { start + UInt64($0) }
            + [start + InvestigationOwnerOnlyCapsuleSettlement.deadlineNanoseconds]
        fixture.system.unlinkScript = Array(
            repeating: .failure(EBUSY), count: busyCount
        )
        let eventStart = fixture.system.events.count

        let result = try fixture.lease.settle(neverHandedOff: proof)

        #expect(result == .settledResidue(
            stage: .unlinkFile,
            residue: .stale(
                entries: [fixture.request.attemptName], observationComplete: true
            ),
            closeFailures: [], ownershipReleaseUncertain: false
        ))
        let events = Array(fixture.system.events[eventStart...])
        let fileUnlinks = events.indices.filter { index in
            if case .unlink(
                _, fixture.request.finalName,
                InvestigationOwnerOnlyCapsuleSettlement.fileUnlinkFlags
            ) = events[index] { return true }
            return false
        }
        #expect(fileUnlinks.count == busyCount)
        #expect(events.filter {
            if case .wait = $0 { return true }; return false
        }.count == busyCount)
        guard fileUnlinks.count == busyCount else { return }
        for retry in 0..<(busyCount - 1) {
            let validation = events[(fileUnlinks[retry] + 1)..<fileUnlinks[retry + 1]]
            #expect(fileRetryPerformedFullRevalidation(
                validation, finalName: fixture.request.finalName
            ))
        }
        let afterLastBusy = events[(fileUnlinks[busyCount - 1] + 1)...]
        #expect(!afterLastBusy.contains { event in
            if case .open(
                _, fixture.request.finalName,
                InvestigationOwnerOnlyCapsulePublication.finalReaderFlags, nil
            ) = event { return true }
            return false
        })
        #expect(fixture.system.removeDirectoryCalls.isEmpty)
    }

    @Test
    func proofCannotCrossLeasesAndSuccessfulProofCannotBeReused() throws {
        let first = try CapsuleSettlementFixture()
        let second = try CapsuleSettlementFixture()
        _ = try first.lease.finishWithoutHandoff()
        let secondProof = try second.lease.finishWithoutHandoff()

        #expect(throws: InvestigationOwnerOnlyCapsuleError.proofRejected(
            first.publishedResidue, ownershipReleaseUncertain: false
        )) {
            _ = try first.lease.settle(neverHandedOff: secondProof)
        }
        #expect(first.system.unlinkCalls.isEmpty)
        #expect(first.system.removeDirectoryCalls.isEmpty)
        #expect(first.ownership.closeRoles.suffix(2) == [.base, .lock])

        #expect(try second.lease.settle(neverHandedOff: secondProof) == .removed)
        let mutationCount = second.system.unlinkCalls.count
            + second.system.removeDirectoryCalls.count
        #expect(throws: InvestigationOwnerOnlyCapsuleError.alreadyTerminal(
            second.publishedResidue
        )) {
            _ = try second.lease.settle(neverHandedOff: secondProof)
        }
        #expect(second.system.unlinkCalls.count
            + second.system.removeDirectoryCalls.count == mutationCount)
    }

    @Test(arguments: CapsuleSettlementFailureCase.allCases)
    fileprivate func settlementFailureMatrixPreservesExactResidueAndFlags(
        _ value: CapsuleSettlementFailureCase
    ) throws {
        let fixture = try CapsuleSettlementFixture()
        let proof = try fixture.lease.finishWithoutHandoff()
        value.configure(fixture.system, attempt: fixture.request.attemptName)

        let result = try fixture.lease.settle(neverHandedOff: proof)

        guard case .settledResidue(
            let stage, _, let closeFailures, let ownershipReleaseUncertain
        ) = result else {
            Issue.record("settlement unexpectedly removed all residue")
            return
        }
        #expect(stage == value.expectedStage)
        #expect(result == .settledResidue(
            stage: value.expectedStage,
            residue: value.expectedResidue(attempt: fixture.request.attemptName),
            closeFailures: [], ownershipReleaseUncertain: false
        ))
        #expect(closeFailures.isEmpty)
        #expect(!ownershipReleaseUncertain)
        #expect(fixture.system.unlinkCalls.allSatisfy {
            $0.flags == Int32(
                AT_NODELETEBUSY | AT_UNIQUE | AT_SYMLINK_NOFOLLOW_ANY
                    | AT_RESOLVE_BENEATH
            )
        })
        #expect(fixture.system.removeDirectoryCalls.allSatisfy {
            $0.flags == Int32(
                AT_NODELETEBUSY | AT_UNIQUE | AT_SYMLINK_NOFOLLOW_ANY
                    | AT_RESOLVE_BENEATH | AT_REMOVEDIR
            )
        })
        #expect(fixture.system.unlinkCalls.count == 1)
        #expect(fixture.system.removeDirectoryCalls.count
            == (value == .baseSyncFailure ? 1 : 0))
        #expect(fixture.ownership.closeRoles.suffix(2) == [.base, .lock])
    }

    @Test
    func successfulSettlementHasExactObservableCleanupOrder() throws {
        let fixture = try CapsuleSettlementFixture()
        let eventStart = fixture.system.events.count
        let proof = try fixture.lease.finishWithoutHandoff()

        #expect(try fixture.lease.settle(neverHandedOff: proof) == .removed)

        let events = Array(fixture.system.events[eventStart...])
        let capsuleClose = try #require(events.firstIndex(of: .close(32)))
        let classifiedReaderClose = try #require(
            events.firstIndex(of: .close(34))
        )
        let classifiedDirectoryClose = try #require(
            events.firstIndex(of: .close(33))
        )
        let revalidationReaderClose = try #require(
            events.firstIndex(of: .close(36))
        )
        let fileUnlink = try #require(events.firstIndex(of: .unlink(
            35, fixture.request.finalName,
            InvestigationOwnerOnlyCapsuleSettlement.fileUnlinkFlags
        )))
        let fileAbsent = try #require(events[(fileUnlink + 1)...].firstIndex(
            of: .named(
                35, fixture.request.finalName,
                InvestigationOwnerOnlyCapsulePublication.namedFlags
            )
        ))
        let leafSync = try #require(events.firstIndex(of: .sync(35)))
        let staleDirectoryClose = try #require(
            events.firstIndex(of: .close(35))
        )
        let directoryUnlink = try #require(events.firstIndex(of: .unlink(
            15, fixture.request.attemptName,
            InvestigationOwnerOnlyCapsuleSettlement.directoryUnlinkFlags
        )))
        let directoryAbsent = try #require(
            events[(directoryUnlink + 1)...].firstIndex(of: .named(
                15, fixture.request.attemptName,
                InvestigationOwnerOnlyCapsulePublication.namedFlags
            ))
        )
        let baseSync = try #require(events.lastIndex(of: .sync(15)))

        #expect(capsuleClose < classifiedReaderClose)
        #expect(classifiedReaderClose < classifiedDirectoryClose)
        #expect(classifiedDirectoryClose < revalidationReaderClose)
        #expect(revalidationReaderClose < fileUnlink)
        #expect(fileUnlink < fileAbsent)
        #expect(fileAbsent < leafSync)
        #expect(leafSync < staleDirectoryClose)
        #expect(staleDirectoryClose < directoryUnlink)
        #expect(directoryUnlink < directoryAbsent)
        #expect(directoryAbsent < baseSync)
        #expect(
            fixture.system.closeDescriptors.suffix(6)
                == [32, 34, 33, 36, 35, 37]
        )
        #expect(fixture.ownership.closeRoles.suffix(2) == [.base, .lock])
    }
}

private struct CapsuleSettlementFixture {
    let bytes: Data
    let request: InvestigationOwnerOnlyCapsulePublicationRequest
    let ownership: CapsuleOwnershipSystem
    let system: CapsuleSemanticSystem
    let lease: InvestigationOwnerOnlyCapsuleLease

    init() throws {
        bytes = try canonicalProjectedInput().encoded()
        request = try InvestigationOwnerOnlyCapsulePublicationRequest(
            canonicalBytes: bytes
        )
        ownership = CapsuleOwnershipSystem()
        system = CapsuleSemanticSystem(bytes: bytes)
        lease = try InvestigationOwnerOnlyCapsulePublisher(
            ownershipSystem: ownership, capsuleSystem: system
        ).publish(bytes)
    }

    var publishedResidue: InvestigationOwnerOnlyCapsuleResidue {
        .published(attempt: request.attemptName, file: request.finalName)
    }
}

private struct CapsuleInventoryCase: Sendable {
    let entries: [String]
    let reachedEnd: Bool
    let error: InvestigationOwnerOnlyCapsuleError
}

private enum CapsuleRecoverableStaleLeaf: CaseIterable, Sendable {
    case pending, canonicalFinal

    func install(
        in system: CapsuleSemanticSystem, attempt: String,
        canonicalFinalName: String
    ) -> String {
        switch self {
        case .pending:
            system.staleLeaves[attempt] = .pending
            return InvestigationOwnerOnlyCapsulePublication.pendingName
        case .canonicalFinal:
            system.staleLeaves[attempt] = .final(canonicalFinalName)
            return canonicalFinalName
        }
    }
}

private enum CapsuleSettlementFailureCase: CaseIterable, Equatable, Sendable {
    case postUnlinkAbsence
    case directoryNonempty
    case directoryReplacement
    case leafSyncFailure
    case baseSyncFailure

    var expectedStage: InvestigationOwnerOnlyCapsuleFailureStage {
        switch self {
        case .postUnlinkAbsence: .proveFileAbsent
        case .directoryNonempty: .verifyLeafEmpty
        case .directoryReplacement: .removeDirectory
        case .leafSyncFailure: .syncLeafAfterUnlink
        case .baseSyncFailure: .syncBaseAfterRemoval
        }
    }

    func expectedResidue(
        attempt: String
    ) -> InvestigationOwnerOnlyCapsuleResidue {
        .stale(
            entries: self == .baseSyncFailure ? [] : [attempt],
            observationComplete: true
        )
    }

    func configure(_ system: CapsuleSemanticSystem, attempt: String) {
        switch self {
        case .postUnlinkAbsence:
            system.unlinkScript = [.successKeepingNode]
        case .directoryNonempty:
            system.nonemptyAfterFileUnlinkAttempts.insert(attempt)
        case .directoryReplacement:
            system.replaceDirectoryAfterFileUnlinkAttempts.insert(attempt)
        case .leafSyncFailure:
            system.failNextStaleDirectorySync = true
        case .baseSyncFailure:
            system.armBaseSyncFailureAfterDirectoryRemoval = true
        }
    }
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
    case clock
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
    case unlink(Int32, String, Int32)
    case wait(UInt64)
}

private func fileRetryPerformedFullRevalidation(
    _ events: ArraySlice<CapsuleEvent>, finalName: String
) -> Bool {
    events.contains(.wait(1_000_000))
        && events.contains { event in
            if case .open(
                _, finalName,
                InvestigationOwnerOnlyCapsulePublication.finalReaderFlags, nil
            ) = event { return true }
            return false
        }
        && events.contains { if case .metadata = $0 { return true }; return false }
        && events.contains { event in
            if case .named(
                _, finalName,
                InvestigationOwnerOnlyCapsulePublication.namedFlags
            ) = event { return true }
            return false
        }
        && events.contains {
            if case .descriptorFlags = $0 { return true }; return false
        }
        && events.contains {
            if case .statusFlags = $0 { return true }; return false
        }
        && events.contains { if case .acl = $0 { return true }; return false }
        && events.contains { if case .xattr = $0 { return true }; return false }
        && events.contains { if case .read = $0 { return true }; return false }
        && events.contains { if case .close = $0 { return true }; return false }
}

private struct CapsuleUnlinkCall: Equatable {
    let parent: Int32
    let name: String
    let flags: Int32
}

private enum CapsuleStaleLeaf {
    case empty
    case pending
    case final(String)
    case other(String)
}

private enum CapsuleDirectoryRetryDrift: CaseIterable, Sendable {
    case acl
    case xattr
    case content
}

private enum CapsuleSettlementClockCase: CaseIterable, Equatable, Sendable {
    case initialClockFailure
    case fileBusyCrossesDeadline
    case directoryBusyCrossesDeadline
    case busyFreshClockFailure

    var expectedStage: InvestigationOwnerOnlyCapsuleFailureStage {
        switch self {
        case .initialClockFailure, .busyFreshClockFailure: .clock
        case .fileBusyCrossesDeadline: .unlinkFile
        case .directoryBusyCrossesDeadline: .removeDirectory
        }
    }

    var expectedClockCount: Int {
        switch self {
        case .initialClockFailure: 1
        case .fileBusyCrossesDeadline, .busyFreshClockFailure: 3
        case .directoryBusyCrossesDeadline: 4
        }
    }

    var expectedFileUnlinkCount: Int {
        self == .initialClockFailure ? 0 : 1
    }

    var expectedDirectoryUnlinkCount: Int {
        self == .directoryBusyCrossesDeadline ? 1 : 0
    }

    var expectedCloseDescriptors: [Int32] {
        switch self {
        case .initialClockFailure:
            [31, 30, 32]
        case .fileBusyCrossesDeadline, .busyFreshClockFailure:
            [31, 30, 32, 34, 33, 36, 35]
        case .directoryBusyCrossesDeadline:
            [31, 30, 32, 34, 33, 36, 35, 37]
        }
    }

    func configure(_ system: CapsuleSemanticSystem, attempt: String) {
        let start: UInt64 = 10_000
        switch self {
        case .initialClockFailure:
            system.failNextMonotonic = true
            system.failAttemptOpenAtCount[attempt] = 2
        case .fileBusyCrossesDeadline:
            system.monotonicValues = [start, start + 1]
            system.monotonicValueAfterBusyUnlink = start
                + InvestigationOwnerOnlyCapsuleSettlement.deadlineNanoseconds
            system.failNextRetryWait = true
            system.unlinkScript = [.failure(EBUSY)]
        case .directoryBusyCrossesDeadline:
            system.monotonicValues = [start, start + 1, start + 2]
            system.monotonicValueAfterBusyUnlink = start
                + InvestigationOwnerOnlyCapsuleSettlement.deadlineNanoseconds
            system.failNextRetryWait = true
            system.unlinkScript = [.success, .failure(EBUSY)]
        case .busyFreshClockFailure:
            system.monotonicValues = [start, start + 1]
            system.failMonotonicAfterBusyUnlink = true
            system.failNextRetryWait = true
            system.unlinkScript = [.failure(EBUSY)]
        }
    }
}

private struct CapsuleStaleCloseFailureCase: Sendable {
    let descriptor: Int32
    let stage: InvestigationOwnerOnlyCapsuleFailureStage
    let role: InvestigationOwnerOnlyCapsuleCloseRole
}

private enum CapsuleUnlinkResult: Sendable {
    case success
    case successKeepingNode
    case failure(Int32)
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
    private var baseEntries: [String]
    var createCalls: [CapsuleModeCall] = []
    var openCalls: [CapsuleOpenCall] = []
    var renameCalls: [CapsuleRenameCall] = []
    var syncDescriptors: [Int32] = []
    var writeOffsets: [Int64] = []
    var writeMaximumCounts: [Int] = []
    var readOffsets: [Int64] = []
    var offsetDescriptors: [Int32] = []
    var closeDescriptors: [Int32] = []
    var everyOpenedDescriptorClosedOnce: Bool {
        Set(roles.keys.filter { $0 != 15 }) == closedDescriptors
            && closeDescriptors.count == closedDescriptors.count
    }
    var writeScript: [CapsuleIOResult] = []
    var readScript: [CapsuleIOResult] = []
    var written = Data()
    var unlinkCount = 0
    var closeErrorDescriptors: Set<Int32> = []
    var staleLeaves: [String: CapsuleStaleLeaf] = [:]
    private var additionalLeafNames: [String: Set<String>] = [:]
    var unlinkCalls: [CapsuleUnlinkCall] = []
    var removeDirectoryCalls: [CapsuleUnlinkCall] = []
    var recoveredAttemptNames: [String] = []
    var monotonicValues: [UInt64] = [1_000_000]
    var failNextMonotonic = false
    var monotonicValueAfterBusyUnlink: UInt64?
    var failMonotonicAfterBusyUnlink = false
    var failNextRetryWait = false
    var unlinkScript: [CapsuleUnlinkResult] = []
    var nonemptyAfterFileUnlinkAttempts: Set<String> = []
    var replaceDirectoryAfterFileUnlinkAttempts: Set<String> = []
    var failNextStaleDirectorySync = false
    var failNextBaseSync = false
    var armBaseSyncFailureAfterDirectoryRemoval = false
    var directoryRetryDrift: CapsuleDirectoryRetryDrift?
    var failAttemptOpenAtCount: [String: Int] = [:]
    private var nextDescriptor: Int32 = 30
    private var roles: [Int32: Int] = [15: 0]
    private var attemptByDescriptor: [Int32: String] = [:]
    private var nameByDescriptor: [Int32: String] = [:]
    private var replacementAttempts: Set<String> = []
    private var attemptOpenCounts: [String: Int] = [:]
    private var staleDirectoryHasACL = false
    private var staleDirectoryHasXattr = false
    private var closedDescriptors: Set<Int32> = []
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
        baseEntries = inventory.entries
        self.failure = failure
    }

    func inventory(baseDescriptor: Int32, maximumEntryCount: Int) throws
        -> InvestigationOwnerOnlyCapsuleInventory
    {
        events.append(.inventory(baseDescriptor, maximumEntryCount))
        if baseDescriptor == 15, !staleLeaves.isEmpty {
            return .init(
                entries: baseEntries, reachedEnd: inventoryResult.reachedEnd
            )
        }
        if roles[baseDescriptor] == 1,
           let attempt = attemptByDescriptor[baseDescriptor],
           let stale = staleLeaves[attempt]
        {
            let primary: [String] = switch stale {
            case .empty: []
            case .pending: [InvestigationOwnerOnlyCapsulePublication.pendingName]
            case .final(let name): [name]
            case .other(let name): [name]
            }
            return .init(
                entries: (primary + Array(additionalLeafNames[attempt, default: []]))
                    .sorted(),
                reachedEnd: true
            )
        }
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
            baseEntries.append(name)
            throw InvestigationOwnerOnlyCapsuleSystemError.errno(EEXIST)
        }
        entries.append(name)
        if parentDescriptor == 15 { baseEntries.append(name) }
    }

    func openComponent(
        parentDescriptor: Int32, name: String, flags: Int32, mode: mode_t?
    ) throws -> Int32 {
        let call = CapsuleOpenCall(
            parent: parentDescriptor, name: name, flags: flags, mode: mode)
        events.append(.open(parentDescriptor, name, flags, mode)); openCalls.append(call)
        if name.hasPrefix("attempt-") {
            attemptOpenCounts[name, default: 0] += 1
            if attemptOpenCounts[name] == failAttemptOpenAtCount[name] {
                throw systemError
            }
            guard parentDescriptor == 15, baseEntries.contains(name) else {
                throw InvestigationOwnerOnlyCapsuleSystemError.errno(ENOENT)
            }
        }
        if failure == .openAttempt && name.hasPrefix("attempt-") { throw systemError }
        if failure == .createPending && name == "capsule.pending" { throw systemError }
        if failure == .pendingCollision && name == "capsule.pending" {
            if let attempt = attemptByDescriptor[parentDescriptor] {
                staleLeaves[attempt] = .pending
            }
            if !entries.contains(name) { entries.append(name) }
            throw InvestigationOwnerOnlyCapsuleSystemError.errno(EEXIST)
        }
        if name == InvestigationOwnerOnlyCapsulePublication.pendingName,
           let attempt = attemptByDescriptor[parentDescriptor]
        {
            if mode != nil {
                guard staleLeaves[attempt] == nil else {
                    throw InvestigationOwnerOnlyCapsuleSystemError.errno(EEXIST)
                }
                staleLeaves[attempt] = .pending
                if !entries.contains(name) { entries.append(name) }
            } else {
                guard containsNamedLeaf(attempt: attempt, name: name) else {
                    throw InvestigationOwnerOnlyCapsuleSystemError.errno(ENOENT)
                }
            }
        } else if name.hasPrefix("projected-cohort-"),
                  let attempt = attemptByDescriptor[parentDescriptor],
                  !containsNamedLeaf(attempt: attempt, name: name)
        {
            throw InvestigationOwnerOnlyCapsuleSystemError.errno(ENOENT)
        }
        if (failure == .reopenFinal || failure == .reopenEscape),
           name.hasPrefix("projected-cohort-")
        {
            throw InvestigationOwnerOnlyCapsuleSystemError.errno(
                failure == .reopenEscape ? ENOTCAPABLE : EIO
            )
        }
        let value = nextDescriptor; nextDescriptor += 1
        roles[value] = name == "capsule.pending"
            ? (mode == nil ? 3 : 2)
            : name.hasPrefix("projected-cohort-") ? 3 : 1
        nameByDescriptor[value] = name
        if name.hasPrefix("attempt-") { attemptByDescriptor[value] = name }
        return value
    }

    func metadata(descriptor: Int32) throws -> InvestigationMachineGateMetadataSnapshot {
        events.append(.metadata(descriptor))
        let role = roles[descriptor] ?? 0
        if role == 1,
           let attempt = attemptByDescriptor[descriptor],
           replacementAttempts.contains(attempt)
        {
            return directory(inode: 99, containsLeaf: false)
        }
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
        if role == 1 {
            let containsLeaf = attemptByDescriptor[descriptor]
                .flatMap { staleLeaves[$0] }
                .map(CapsuleSemanticSystem.containsLeaf) ?? false
            return directory(containsLeaf: containsLeaf)
        }
        return file()
    }

    func namedMetadata(
        parentDescriptor: Int32, name: String, flags: Int32
    ) throws -> InvestigationMachineGateMetadataSnapshot {
        events.append(.named(parentDescriptor, name, flags))
        let present: Bool
        if parentDescriptor == 15 {
            present = baseEntries.contains(name) || name == fixedLockName
        } else if let attempt = attemptByDescriptor[parentDescriptor],
                  staleLeaves[attempt] != nil
        {
            present = containsNamedLeaf(attempt: attempt, name: name)
        } else {
            present = entries.contains(name)
        }
        if !present {
            throw InvestigationOwnerOnlyCapsuleSystemError.errno(ENOENT)
        }
        if parentDescriptor == 15, replacementAttempts.contains(name) {
            return directory(inode: 99, containsLeaf: false)
        }
        if name.hasPrefix("projected-cohort-") {
            finalNamedCount += 1
            if failure == .namedIdentityDrift && finalNamedCount == 2 {
                return file(inode: 99)
            }
            if failure == .finalSymlink { return file(type: .other) }
            if failure == .finalHardLink { return file(linkCount: 2) }
        }
        if name.hasPrefix("attempt-") {
            return directory(
                containsLeaf: staleLeaves[name]
                    .map(CapsuleSemanticSystem.containsLeaf) ?? false
            )
        }
        return file()
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
        events.append(.acl(descriptor))
        return !(roles[descriptor] == 1 && staleDirectoryHasACL)
    }
    func extendedAttributeNames(descriptor: Int32) throws -> [String] {
        events.append(.xattr(descriptor))
        return roles[descriptor] == 1 && staleDirectoryHasXattr
            ? ["com.eriklee.stornaut.injected"] : []
    }
    func synchronize(descriptor: Int32) throws {
        events.append(.sync(descriptor)); syncDescriptors.append(descriptor)
        if descriptor == 15, failNextBaseSync {
            failNextBaseSync = false
            throw systemError
        }
        if roles[descriptor] == 1, failNextStaleDirectorySync {
            failNextStaleDirectorySync = false
            throw systemError
        }
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
            if let attempt = attemptByDescriptor[parentDescriptor] {
                additionalLeafNames[attempt, default: []].insert(newName)
            }
            if !entries.contains(newName) { entries.append(newName) }
            throw InvestigationOwnerOnlyCapsuleSystemError.errno(EEXIST)
        }
        entries.removeAll { $0 == oldName }; entries.append(newName)
        if let attempt = attemptByDescriptor[parentDescriptor] {
            staleLeaves[attempt] = .final(newName)
        }
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
        guard closedDescriptors.insert(descriptor).inserted else {
            throw InvestigationOwnerOnlyCapsuleSystemError.errno(EBADF)
        }
        if closeErrorDescriptors.contains(descriptor) { throw systemError }
        if failure == .closePendingWriter && descriptor == 31 { throw systemError }
        if failure == .closeAttemptDirectory && descriptor == 30 { throw systemError }
    }
    func monotonicNanoseconds() throws -> UInt64 {
        events.append(.clock)
        if failNextMonotonic {
            failNextMonotonic = false
            throw systemError
        }
        if monotonicValues.count > 1 { return monotonicValues.removeFirst() }
        return monotonicValues.first ?? 1_000_000
    }
    func unlink(parentDescriptor: Int32, name: String, flags: Int32) throws {
        let call = CapsuleUnlinkCall(parent: parentDescriptor, name: name, flags: flags)
        events.append(.unlink(parentDescriptor, name, flags))
        unlinkCount += 1
        let result = unlinkScript.isEmpty ? .success : unlinkScript.removeFirst()
        if case .failure(let value) = result {
            if value == EBUSY {
                if let monotonicValueAfterBusyUnlink {
                    monotonicValues = [monotonicValueAfterBusyUnlink]
                }
                if failMonotonicAfterBusyUnlink { failNextMonotonic = true }
            }
            if flags & AT_REMOVEDIR != 0 {
                removeDirectoryCalls.append(call)
                if value == EBUSY {
                    applyDirectoryRetryDrift(attempt: name)
                }
            } else {
                unlinkCalls.append(call)
            }
            throw InvestigationOwnerOnlyCapsuleSystemError.errno(value)
        }
        let keepNode: Bool = if case .successKeepingNode = result { true }
            else { false }
        if flags & AT_REMOVEDIR != 0 {
            removeDirectoryCalls.append(call)
            if !keepNode {
                recoveredAttemptNames.append(name)
                staleLeaves.removeValue(forKey: name)
                additionalLeafNames.removeValue(forKey: name)
                entries.removeAll { $0 == name }
                baseEntries.removeAll { $0 == name }
                if armBaseSyncFailureAfterDirectoryRemoval {
                    failNextBaseSync = true
                }
            }
        } else {
            unlinkCalls.append(call)
            if !keepNode { entries.removeAll { $0 == name } }
            if let attempt = attemptByDescriptor[parentDescriptor] {
                if nonemptyAfterFileUnlinkAttempts.contains(attempt) {
                    staleLeaves[attempt] = .other("unexpected")
                } else if !keepNode {
                    staleLeaves[attempt] = .empty
                }
                if replaceDirectoryAfterFileUnlinkAttempts.contains(attempt) {
                    replacementAttempts.insert(attempt)
                }
            } else if !keepNode {
                entries.removeAll { $0 == name }
            }
        }
    }
    func waitForRetry(nanoseconds: UInt64) throws {
        events.append(.wait(nanoseconds))
        if failNextRetryWait {
            failNextRetryWait = false
            throw systemError
        }
    }

    // APFS reports ordinary empty directories with a positive link count and
    // filesystem-defined storage (commonly nlink 2 and size 64).  Keep the
    // fake realistic so settlement cannot accidentally require file semantics.
    private func directory(
        inode: UInt64 = 11, mode: mode_t = 0o700,
        containsLeaf: Bool = false
    )
        -> InvestigationMachineGateMetadataSnapshot
    {
        .init(
            device: 1, inode: inode, generation: generation, fileType: .directory,
            ownerUID: 501, ownerGID: 20, permissions: mode,
            linkCount: containsLeaf ? 3 : 2,
            size: containsLeaf ? 96 : 64, flags: 0)
    }

    private static func containsLeaf(_ leaf: CapsuleStaleLeaf) -> Bool {
        if case .empty = leaf { return false }
        return true
    }

    private func containsNamedLeaf(attempt: String, name: String) -> Bool {
        let primary = staleLeaves[attempt].map { leaf in
            switch leaf {
            case .empty:
                false
            case .pending:
                name == InvestigationOwnerOnlyCapsulePublication.pendingName
            case .final(let existing), .other(let existing):
                name == existing
            }
        } ?? false
        return primary || additionalLeafNames[attempt, default: []].contains(name)
    }

    private func applyDirectoryRetryDrift(attempt: String) {
        switch directoryRetryDrift {
        case .acl:
            staleDirectoryHasACL = true
        case .xattr:
            staleDirectoryHasXattr = true
        case .content:
            staleLeaves[attempt] = .other("injected")
        case nil:
            break
        }
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
        digest: InvestigationHandoffSHA256,
        settlementToken: InvestigationOwnerOnlyCapsuleSettlementToken
    ) throws -> InvestigationOwnerOnlyCapsuleExactGateReapedProof {
        descriptors.append(descriptor)
        outerAttemptUUIDs.append(outerAttemptUUID)
        if throwsOnHandoff { throw CapsuleFixedBorrowerError.failed }
        return .makeForFixedLauncher(
            outerAttemptUUID: mismatchesProof ? capsuleUUID(0xfe) : outerAttemptUUID,
            digest: digest, identity: identity, settlementToken: settlementToken
        )
    }
}

private enum CapsuleFixedBorrowerError: Error { case failed }

private enum GateRole: String { case root, users, home, library, caches, base, lock }
private let fixedBaseRelativePath = "Users/fixture/Library/Caches/"
    + InvestigationMachineGateOwnershipAcquirer.baseName
