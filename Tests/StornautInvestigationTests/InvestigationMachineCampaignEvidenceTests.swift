import Darwin
import Foundation
import Testing

@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationMachineCampaignSupport
@testable import StornautInvestigationMachineGateCoordinatorSupport
@testable import StornautInvestigationMachineGateSupport

@Suite("Investigation machine campaign evidence", .serialized)
struct InvestigationMachineCampaignEvidenceTests {
    @Test
    func phasesAndRolesRemainClosedAndOrdered() {
        #expect(InvestigationMachineEvidencePhase.allCases.map(\.directoryName) == [
            "01-preflight",
            "02-install",
            "03-authorization",
            "04-driver-epochs",
            "05-uninstall",
            "06-verifier",
        ])
        #expect(Set(InvestigationMachineEvidenceRole.allCases) == Set([
            .sourceBuildIdentity,
            .builtStagingInstalledIdentity,
            .policyProbe,
            .humanPromptAttestation,
            .noAuthModelNetworkCounters,
            .protocolReceipt,
            .diagnosticOutput,
            .epochL2Projection,
            .epochResidueProjection,
            .uninstallEvidence,
            .globalPostTeardown,
            .verifierInput,
            .attemptEvent,
        ]))
        #expect(InvestigationMachineEvidenceRole.protocolReceipt.requiredEncoding
            == .framedCanonicalBinary)
        #expect(InvestigationMachineEvidenceRole.diagnosticOutput.requiredEncoding
            == .opaqueBytes)
        #expect(InvestigationMachineEvidenceRole.policyProbe.requiredEncoding
            == .strictJSON)
        #expect(!InvestigationMachineEvidenceRole.protocolReceipt.allowsMultiple)
        #expect(InvestigationMachineEvidenceRole.attemptEvent.allowsMultiple)
    }

    @Test(arguments: [
        "", ".", "..", "/absolute", "upper.JSON", "two/parts",
        "two\\parts", "trailing-", ".hidden", "manifest.bin",
        "pending-record", "record.pending", "nul\0byte",
        String(repeating: "a", count: 97), "évidence.json",
    ])
    func relativePathRejectsNonCanonicalLeaf(_ leaf: String) {
        #expect(throws: InvestigationMachineEvidenceContractError.invalidPath) {
            _ = try InvestigationMachineEvidenceRelativePath(
                phase: .preflight, leafName: leaf
            )
        }
    }

    @Test
    func relativePathProjectsOneCanonicalPhaseAndLeaf() throws {
        let path = try InvestigationMachineEvidenceRelativePath(
            phase: .driverEpochs, leafName: "epoch-01-receipt.bin"
        )
        #expect(path.relativeValue
            == "04-driver-epochs/epoch-01-receipt.bin")
        #expect(path.phase == .driverEpochs)
        #expect(path.leafName == "epoch-01-receipt.bin")
    }

    @Test
    func artifactRejectsRolePhaseEncodingAndSizeDrift() throws {
        let path = try InvestigationMachineEvidenceRelativePath(
            phase: .authorization, leafName: "policy-probe.json"
        )
        let digest = Self.digest(0x11)
        _ = try InvestigationMachineEvidenceArtifact(
            path: path, role: .policyProbe, encoding: .strictJSON,
            byteCount: 2, sha256: digest
        )
        #expect(throws: InvestigationMachineEvidenceContractError.invalidRole) {
            _ = try InvestigationMachineEvidenceArtifact(
                path: path, role: .uninstallEvidence, encoding: .strictJSON,
                byteCount: 2, sha256: digest
            )
        }
        #expect(throws: InvestigationMachineEvidenceContractError.invalidRole) {
            _ = try InvestigationMachineEvidenceArtifact(
                path: .init(phase: .authorization, leafName: "other.json"),
                role: .policyProbe, encoding: .strictJSON,
                byteCount: 2, sha256: digest
            )
        }
        #expect(throws: InvestigationMachineEvidenceContractError.invalidEncoding) {
            _ = try InvestigationMachineEvidenceArtifact(
                path: path, role: .policyProbe, encoding: .canonicalBinary,
                byteCount: 2, sha256: digest
            )
        }
        #expect(throws: InvestigationMachineEvidenceContractError.sizeLimitExceeded) {
            _ = try InvestigationMachineEvidenceArtifact(
                path: path, role: .policyProbe, encoding: .strictJSON,
                byteCount: 0, sha256: digest
            )
        }
    }

    @Test
    func manifestCanonicalizesCallerOrderAndRoundTripsExactly() throws {
        let fixture = try CampaignEvidenceFixture.make()
        let ascending = try InvestigationMachineEvidenceManifestV1(
            campaignUUID: fixture.campaignUUID,
            attemptUUID: fixture.attemptUUID,
            sourceBinding: fixture.sourceBinding,
            artifacts: fixture.artifacts,
            attemptSummary: fixture.attemptSummary
        )
        let descending = try InvestigationMachineEvidenceManifestV1(
            campaignUUID: fixture.campaignUUID,
            attemptUUID: fixture.attemptUUID,
            sourceBinding: fixture.sourceBinding,
            artifacts: fixture.artifacts.reversed(),
            attemptSummary: fixture.attemptSummary
        )
        let encoded = try ascending.encoded()
        let descendingEncoded = try descending.encoded()
        #expect(encoded == descendingEncoded)
        #expect(ascending.artifacts.map { $0.path.relativeValue }
            == ascending.artifacts.map { $0.path.relativeValue }.sorted())
        #expect(ascending.contentRootSHA256.rawBytes.contains { $0 != 0 })
        #expect(InvestigationHandoffSHA256.hashing(encoded)
            == ascending.manifestSHA256)
        #expect(ascending.attemptSummary == fixture.attemptSummary)
        #expect(ascending.attemptSummary.mode == .privileged)
        #expect(ascending.attemptSummary.consumed)
        #expect(try InvestigationMachineEvidenceManifestV1.decode(encoded)
            == ascending)
    }

    @Test
    func manifestRejectsMissingAndDuplicateRolesAndPaths() throws {
        let fixture = try CampaignEvidenceFixture.make()
        #expect(throws: InvestigationMachineEvidenceContractError.missingRole) {
            _ = try InvestigationMachineEvidenceManifestV1(
                campaignUUID: fixture.campaignUUID,
                attemptUUID: fixture.attemptUUID,
                sourceBinding: fixture.sourceBinding,
                artifacts: fixture.artifacts.filter {
                    $0.role != .globalPostTeardown
                }, attemptSummary: fixture.attemptSummary
            )
        }
        let eventArtifacts = fixture.artifacts.filter { $0.role == .attemptEvent }
        let cancelled = try InvestigationMachineAttemptSummary(
            attemptUUID: fixture.attemptUUID, mode: .dryRun,
            outcome: .cancelledBeforeArm, consumed: false, eventCount: 2,
            finalEventSHA256: eventArtifacts[1].sha256
        )
        #expect(throws: InvestigationMachineEvidenceContractError
            .invalidTransition) {
            _ = try InvestigationMachineEvidenceManifestV1(
                campaignUUID: fixture.campaignUUID,
                attemptUUID: fixture.attemptUUID,
                sourceBinding: fixture.sourceBinding,
                artifacts: fixture.artifacts, attemptSummary: cancelled
            )
        }
        #expect(throws: InvestigationMachineEvidenceContractError.duplicateArtifact) {
            _ = try InvestigationMachineEvidenceManifestV1(
                campaignUUID: fixture.campaignUUID,
                attemptUUID: fixture.attemptUUID,
                sourceBinding: fixture.sourceBinding,
                artifacts: fixture.artifacts + [fixture.artifacts[0]],
                attemptSummary: fixture.attemptSummary
            )
        }
    }

    @Test
    func manifestDecoderRejectsWireMutations() throws {
        let fixture = try CampaignEvidenceFixture.make()
        let manifest = try InvestigationMachineEvidenceManifestV1(
            campaignUUID: fixture.campaignUUID,
            attemptUUID: fixture.attemptUUID,
            sourceBinding: fixture.sourceBinding,
            artifacts: fixture.artifacts,
            attemptSummary: fixture.attemptSummary
        )
        let encoded = try manifest.encoded()
        var magic = encoded
        magic[magic.startIndex] ^= 0xff
        for mutation in [
            Data(), Data(encoded.dropLast()), encoded + Data([0]), magic,
        ] {
            #expect(throws: (any Error).self) {
                _ = try InvestigationMachineEvidenceManifestV1.decode(mutation)
            }
        }
    }

    @Test
    func coordinatorReceiptCodecMatchesCanonicalProducerBytes() throws {
        let fixture = try CampaignCoordinatorReceiptFixture.make()
        let producerBytes = try fixture.producer.encoded()
        let consumerBytes = try fixture.consumer.encoded()
        #expect(consumerBytes == producerBytes)
        #expect(try InvestigationMachineCoordinatorRawReceiptV1.decode(
            producerBytes) == fixture.consumer)

        let frame = Self.lengthPrefixed(producerBytes)
        #expect(try InvestigationMachineCoordinatorRawReceiptV1.decodeFrame(
            frame, reachedEOF: true) == fixture.consumer)
    }

    @Test
    func coordinatorReceiptCodecRejectsFramingAndCanonicalMutations() throws {
        let payload = try CampaignCoordinatorReceiptFixture.make()
            .producer.encoded()
        let frame = Self.lengthPrefixed(payload)
        var wrongLength = frame
        wrongLength[3] &-= 1
        var selfHash = frame
        selfHash[selfHash.index(before: selfHash.endIndex)] ^= 0x01
        for mutation in [
            Data(), Data(frame.prefix(3)), Data(frame.dropLast()),
            frame + Data([0]), wrongLength, selfHash,
        ] {
            #expect(throws: (any Error).self) {
                _ = try InvestigationMachineCoordinatorRawReceiptV1
                    .decodeFrame(mutation, reachedEOF: true)
            }
        }
        #expect(throws: InvestigationMachineEvidenceContractError
            .incompleteInput) {
            _ = try InvestigationMachineCoordinatorRawReceiptV1
                .decodeFrame(frame, reachedEOF: false)
        }
    }

    @Test
    func coordinatorReceiptCapsuleSizeMatchesProducerBoundary() throws {
        let maximum = Int64(InvestigationProjectedCohortInput.maximumByteCount)
        _ = try CampaignCoordinatorReceiptFixture.make(capsuleSize: maximum)
        #expect(throws: InvestigationMachineEvidenceContractError.invalidEncoding) {
            _ = try CampaignCoordinatorReceiptFixture.makeConsumer(
                capsuleSize: maximum + 1
            )
        }
    }

    @Test
    func eventChainsAcceptOnlyTheTwoFrozenTerminalShapes() throws {
        let attempt = CampaignEvidenceFixture.uuid(0x42)
        let prepared = try Self.event(
            sequence: 1, attempt: attempt, kind: .prepared,
            previous: try Self.zeroDigest()
        )
        let cancelled = try Self.event(
            sequence: 2, attempt: attempt, kind: .cancelledBeforeArm,
            previous: .hashing(try prepared.encoded())
        )
        try InvestigationMachineAttemptEventChain.validateComplete(
            [prepared, cancelled], mode: .dryRun
        )

        let armed = try Self.event(
            sequence: 2, attempt: attempt, kind: .armedConsumed,
            previous: .hashing(try prepared.encoded())
        )
        let spawned = try Self.event(
            sequence: 3, attempt: attempt, kind: .spawnObserved,
            previous: .hashing(try armed.encoded())
        )
        let terminal = try Self.event(
            sequence: 4, attempt: attempt, kind: .terminal,
            previous: .hashing(try spawned.encoded())
        )
        try InvestigationMachineAttemptEventChain.validateComplete(
            [prepared, armed, spawned, terminal], mode: .privileged
        )
        #expect(try InvestigationMachineAttemptEventV1.decode(
            terminal.encoded()) == terminal)
    }

    @Test
    func eventChainsRejectGapsBrokenHashesAndIllegalTransitions() throws {
        let attempt = CampaignEvidenceFixture.uuid(0x43)
        let prepared = try Self.event(
            sequence: 1, attempt: attempt, kind: .prepared,
            previous: try Self.zeroDigest()
        )
        let invalidValues: [[InvestigationMachineAttemptEventV1]] = [
            [try Self.event(
            sequence: 2, attempt: attempt, kind: .prepared,
                previous: try Self.zeroDigest()
            )],
            [prepared, try Self.event(
                sequence: 3, attempt: attempt, kind: .cancelledBeforeArm,
                previous: .hashing(try prepared.encoded())
            )],
            [prepared, try Self.event(
                sequence: 2, attempt: attempt, kind: .terminal,
                previous: .hashing(try prepared.encoded())
            )],
            [prepared, try Self.event(
                sequence: 2, attempt: attempt, kind: .cancelledBeforeArm,
                previous: Self.digest(0xee)
            )],
        ]
        for events in invalidValues {
            #expect(throws: InvestigationMachineEvidenceContractError
                .invalidTransition) {
                try InvestigationMachineAttemptEventChain.validateComplete(
                    events, mode: .dryRun
                )
            }
        }
        #expect(throws: InvestigationMachineEvidenceContractError.invalidEncoding) {
            _ = try InvestigationMachineAttemptEventV1(
                sequence: 1, attemptUUID: attempt, kind: .prepared,
                previousEventSHA256: try Self.zeroDigest(),
                observedAt: try .init(rawValue: 1),
                payload: Data("{ \"value\" : \"not-canonical\" }".utf8)
            )
        }
    }

    @Test
    func writerPublishesOwnerPrivateTreeAndManifestLast() throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let writer = try fixture.makeWriter()
        try fixture.populate(writer)
        let seal = try writer.finalize()

        #expect(seal.attemptUUID == fixture.attemptUUID)
        #expect(seal.campaignUUID == fixture.campaignUUID)
        #expect(seal.artifactCount == fixture.expectedArtifactCount)
        #expect(seal.totalByteCount > 0)
        #expect(seal.contentRootSHA256.rawBytes.contains { $0 != 0 })
        #expect(seal.manifestSHA256.rawBytes.contains { $0 != 0 })

        let root = fixture.evidenceRoot
        try Self.requireMetadata(root, type: S_IFDIR, permissions: 0o700)
        let rootNames = try FileManager.default.contentsOfDirectory(
            atPath: root.path
        ).sorted()
        #expect(rootNames == InvestigationMachineEvidencePhase.allCases
            .map(\.directoryName).sorted() + ["manifest.bin"])
        for phase in InvestigationMachineEvidencePhase.allCases {
            try Self.requireMetadata(
                root.appending(path: phase.directoryName),
                type: S_IFDIR, permissions: 0o700
            )
        }
        let manifestBytes = try Data(contentsOf:
            root.appending(path: "manifest.bin"))
        let manifest = try InvestigationMachineEvidenceManifestV1.decode(
            manifestBytes
        )
        #expect(manifest.contentRootSHA256 == seal.contentRootSHA256)
        #expect(manifest.manifestSHA256 == seal.manifestSHA256)
        #expect(manifest.attemptSummary == seal.attemptSummary)
        #expect(seal.attemptSummary.mode == .dryRun)
        #expect(seal.attemptSummary.outcome == .cancelledBeforeArm)
        #expect(!seal.attemptSummary.consumed)
        #expect(!rootNames.contains { $0.contains("pending") })
        #expect(throws: InvestigationMachineRawEvidenceError.alreadyTerminal) {
            _ = try writer.finalize()
        }
    }

    @Test
    func writerRejectsExistingRootBeforePublishing() throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        try FileManager.default.createDirectory(
            at: fixture.evidenceRoot, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        #expect(throws: InvestigationMachineRawEvidenceError.rootCollision) {
            _ = try fixture.makeWriter()
        }
    }

    @Test(arguments: [
        CampaignReceiptBindingMutation.attempt, .build, .signedRuntime,
    ])
    func writerRejectsForeignCoordinatorReceipt(
        _ mutation: CampaignReceiptBindingMutation
    ) throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let writer = try fixture.makeWriter()
        let frame = try CampaignCoordinatorReceiptFixture.frame(
            attemptUUID: mutation == .attempt
                ? CampaignEvidenceFixture.uuid(0xee) : fixture.attemptUUID,
            buildProvenanceSHA256: mutation == .build
                ? Self.digest(0xee).lowercaseHex
                : fixture.sourceBinding.buildProvenanceSHA256.lowercaseHex,
            signedBindingSHA256: mutation == .signedRuntime
                ? Self.digest(0xef)
                : fixture.sourceBinding.signedRuntimeBindingSHA256
        )
        #expect(throws: InvestigationMachineEvidenceContractError.invalidEncoding) {
            _ = try writer.writeArtifact(
                path: .init(
                    phase: .driverEpochs, leafName: "coordinator-receipt.bin"),
                role: .protocolReceipt, encoding: .framedCanonicalBinary,
                bytes: frame
            )
        }
    }

    @Test
    func writerRejectsInvalidIdentifiersBeforeCreatingRoot() throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let zero = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        let parent = try fixture.system.metadata(
            descriptor: fixture.parentDescriptor
        )
        #expect(throws: InvestigationMachineEvidenceContractError.invalidEncoding) {
            _ = try InvestigationMachineRawEvidenceWriter(
                system: fixture.system, parentDescriptor: fixture.parentDescriptor,
                expectedParentIdentity: parent.identity, campaignUUID: zero,
                attemptUUID: fixture.attemptUUID,
                sourceBinding: fixture.sourceBinding
            )
        }
        #expect(!FileManager.default.fileExists(atPath: fixture.parent.appending(
            path: InvestigationMachineRawEvidenceWriter.rootName(
                campaignUUID: zero)).path))
    }

    @Test
    func initializationFailureClosesEveryOpenedDescriptor() throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let system = CampaignFaultingEvidenceSystem(base: fixture.system)
        system.failDirectoryCreationCall = 3
        let parent = try system.metadata(descriptor: fixture.parentDescriptor)
        #expect(throws: InvestigationMachineRawEvidenceError
            .uncertain(stage: .createPhase)) {
            _ = try InvestigationMachineRawEvidenceWriter(
                system: system, parentDescriptor: fixture.parentDescriptor,
                expectedParentIdentity: parent.identity,
                campaignUUID: fixture.campaignUUID,
                attemptUUID: fixture.attemptUUID,
                sourceBinding: fixture.sourceBinding
            )
        }
        #expect(!system.openedDescriptors.isEmpty)
        #expect(Set(system.openedDescriptors).isSubset(
            of: Set(system.closedDescriptors)))
        #expect(!FileManager.default.fileExists(atPath:
            fixture.evidenceRoot.appending(path: "manifest.bin").path))
    }

    @Test
    func initializationRejectsReservedOrAliasedDescriptor() throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let system = CampaignFaultingEvidenceSystem(base: fixture.system)
        system.nextOpenedDescriptor = fixture.parentDescriptor
        let parent = try system.metadata(descriptor: fixture.parentDescriptor)
        #expect(throws: InvestigationMachineRawEvidenceError
            .uncertain(stage: .openRoot)) {
            _ = try InvestigationMachineRawEvidenceWriter(
                system: system, parentDescriptor: fixture.parentDescriptor,
                expectedParentIdentity: parent.identity,
                campaignUUID: fixture.campaignUUID,
                attemptUUID: fixture.attemptUUID,
                sourceBinding: fixture.sourceBinding
            )
        }
        var metadata = stat()
        #expect(fstat(fixture.parentDescriptor, &metadata) == 0)
        #expect(!system.closedDescriptors.contains(fixture.parentDescriptor))
    }

    @Test(arguments: CampaignInitializationFault.allCases)
    func initializationMapsObservationFailuresToExactStage(
        _ fault: CampaignInitializationFault
    ) throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let system = CampaignFaultingEvidenceSystem(base: fixture.system)
        let parent = try system.metadata(descriptor: fixture.parentDescriptor)
        system.armInitialization(fault)
        #expect(throws: InvestigationMachineRawEvidenceError
            .uncertain(stage: fault.expectedStage)) {
            _ = try InvestigationMachineRawEvidenceWriter(
                system: system, parentDescriptor: fixture.parentDescriptor,
                expectedParentIdentity: parent.identity,
                campaignUUID: fixture.campaignUUID,
                attemptUUID: fixture.attemptUUID,
                sourceBinding: fixture.sourceBinding
            )
        }
    }

    @Test
    func finalizationRejectsParentIdentityDrift() throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let system = CampaignFaultingEvidenceSystem(base: fixture.system)
        let writer = try fixture.makeWriter(system: system)
        try fixture.populate(writer)
        system.driftDescriptor = fixture.parentDescriptor
        #expect(throws: InvestigationMachineRawEvidenceError
            .uncertain(stage: .validateParent)) {
            _ = try writer.finalize()
        }
    }

    @Test(arguments: [-1, 0, 1, 3])
    func finalizationRejectsReservedOrHeldDescriptor(_ index: Int) throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let system = CampaignFaultingEvidenceSystem(base: fixture.system)
        let writer = try fixture.makeWriter(system: system)
        try fixture.populate(writer)
        let held = index < 0 ? STDIN_FILENO
            : ([fixture.parentDescriptor] + system.openedDescriptors)[index]
        system.protectedDescriptor = held
        defer { system.protectedDescriptor = nil }
        system.nextOpenedDescriptor = held
        #expect(throws: InvestigationMachineRawEvidenceError
            .uncertain(stage: .reopenFinal)) { _ = try writer.finalize() }
        #expect(system.closeAttempts.contains(held) == (index < 0))
    }

    @Test
    func publicationRejectsCrossPhaseDescriptorAliasBeforeMutation() throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let system = CampaignFaultingEvidenceSystem(base: fixture.system)
        let writer = try fixture.makeWriter(system: system)
        let held = system.openedDescriptors[2]
        system.protectedDescriptor = held
        defer { system.protectedDescriptor = nil }
        system.arm(.validatePending)
        system.nextOpenedDescriptor = held
        #expect(throws: InvestigationMachineRawEvidenceError
            .uncertain(stage: .createPending)) {
            _ = try writer.writeArtifact(
                path: .init(phase: .preflight, leafName: "source-build.json"),
                role: .sourceBuildIdentity, encoding: .strictJSON,
                bytes: Self.json("source"))
        }
        #expect(!system.closeAttempts.contains(held))
    }

    @Test(arguments: CampaignFinalObservationFault.allCases)
    func finalizationMapsObservationFailuresToExactStage(
        _ fault: CampaignFinalObservationFault) throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let system = CampaignFaultingEvidenceSystem(base: fixture.system)
        let writer = try fixture.makeWriter(system: system)
        try fixture.populate(writer)
        system.failNamedMetadataName = fault.name(campaignUUID: fixture.campaignUUID)
        #expect(throws: InvestigationMachineRawEvidenceError
            .uncertain(stage: fault.expectedStage)) { _ = try writer.finalize() }
    }

    @Test
    func dryRunWriterCannotRecordArmOrSpawn() throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let writer = try fixture.makeWriter()
        _ = try writer.appendAttemptEvent(
            kind: .prepared, payload: Self.json("prepared"),
            observedAt: try .init(rawValue: 1)
        )
        for kind in [
            InvestigationMachineAttemptEventKind.armedConsumed,
            .spawnObserved, .spawnUncertain, .terminal,
        ] {
            #expect(throws: InvestigationMachineRawEvidenceError
                .dryRunAuthorityViolation) {
                _ = try writer.appendAttemptEvent(
                    kind: kind, payload: Self.json("forbidden"),
                    observedAt: try .init(rawValue: 2)
                )
            }
        }
        _ = try writer.appendAttemptEvent(
            kind: .cancelledBeforeArm, payload: Self.json("cancelled"),
            observedAt: try .init(rawValue: 2)
        )
        try fixture.populateDryRunArtifacts(writer)
        _ = try writer.finalize()
    }

    @Test(arguments: [
        InvestigationMachineAttemptEventKind.spawnObserved, .spawnUncertain,
    ])
    func privilegedWriterPublishesOnlyCompleteIrreversibleHistory(
        _ spawn: InvestigationMachineAttemptEventKind
    ) throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let writer = try fixture.makeWriter(mode: .privileged)
        for (index, kind) in [
            InvestigationMachineAttemptEventKind.prepared, .armedConsumed,
            spawn, .terminal,
        ].enumerated() {
            _ = try writer.appendAttemptEvent(
                kind: kind, payload: Self.json("event-\(index + 1)"),
                observedAt: try .init(rawValue: Int64(index + 1))
            )
        }
        try fixture.populatePrivilegedArtifacts(writer)
        let seal = try writer.finalize()
        #expect(seal.artifactCount == fixture.privilegedArtifactCount)
        #expect(seal.attemptSummary.mode == .privileged)
        #expect(seal.attemptSummary.outcome == (spawn == .spawnObserved
            ? .spawnObservedTerminal : .spawnUncertainTerminal))
        #expect(seal.attemptSummary.consumed)
        #expect(seal.attemptSummary.eventCount == 4)
    }

    @Test
    func privilegedWriterRejectsCancellationOrRearmAfterArm() throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let writer = try fixture.makeWriter(mode: .privileged)
        _ = try writer.appendAttemptEvent(
            kind: .prepared, payload: Self.json("prepared"),
            observedAt: try .init(rawValue: 1)
        )
        _ = try writer.appendAttemptEvent(
            kind: .armedConsumed, payload: Self.json("armed"),
            observedAt: try .init(rawValue: 2)
        )
        for kind in [
            InvestigationMachineAttemptEventKind.cancelledBeforeArm,
            .armedConsumed, .terminal,
        ] {
            #expect(throws: InvestigationMachineEvidenceContractError
                .invalidTransition) {
                _ = try writer.appendAttemptEvent(
                    kind: kind, payload: Self.json("invalid"),
                    observedAt: try .init(rawValue: 3)
                )
            }
        }
    }

    @Test(arguments: [CampaignTreeMutation.extraSymlink, .hardLink, .wrongMode])
    func finalizationRejectsTreeMutation(_ mutation: CampaignTreeMutation) throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let writer = try fixture.makeWriter()
        try fixture.populate(writer)
        try fixture.apply(mutation)
        #expect(throws: (any Error).self) { _ = try writer.finalize() }
        #expect(throws: InvestigationMachineRawEvidenceError.alreadyTerminal) {
            _ = try writer.finalize()
        }
        #expect(!FileManager.default.fileExists(
            atPath: fixture.evidenceRoot.appending(path: "manifest.bin").path
        ))
    }

    @Test
    func writeFailurePoisonsWriterWithoutPublishingManifest() throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let base = DarwinInvestigationMachineRawEvidenceSystem()
        let system = CampaignFaultingEvidenceSystem(base: base)
        let writer = try fixture.makeWriter(system: system)
        system.failNextWrite = true
        let path = try InvestigationMachineEvidenceRelativePath(
            phase: .preflight, leafName: "source-build.json"
        )
        #expect(throws: InvestigationMachineRawEvidenceError
            .uncertain(stage: .writePending)) {
            _ = try writer.writeArtifact(
                path: path, role: .sourceBuildIdentity,
                encoding: .strictJSON, bytes: Self.json("source")
            )
        }
        #expect(throws: InvestigationMachineRawEvidenceError.alreadyTerminal) {
            _ = try writer.writeArtifact(
                path: path, role: .sourceBuildIdentity,
                encoding: .strictJSON, bytes: Self.json("source")
            )
        }
        #expect(!FileManager.default.fileExists(
            atPath: fixture.evidenceRoot.appending(path: "manifest.bin").path
        ))
    }

    @Test(arguments: CampaignEvidenceFault.allCases)
    func artifactPublicationMapsEveryFailureStage(
        _ fault: CampaignEvidenceFault
    ) throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let system = CampaignFaultingEvidenceSystem(base: fixture.system)
        let writer = try fixture.makeWriter(system: system)
        system.arm(fault)
        let path = try InvestigationMachineEvidenceRelativePath(
            phase: .preflight, leafName: "source-build.json"
        )
        #expect(throws: InvestigationMachineRawEvidenceError
            .uncertain(stage: fault.expectedStage)) {
            _ = try writer.writeArtifact(
                path: path, role: .sourceBuildIdentity,
                encoding: .strictJSON, bytes: Self.json("source")
            )
        }
        #expect(throws: InvestigationMachineRawEvidenceError.alreadyTerminal) {
            _ = try writer.writeArtifact(
                path: path, role: .sourceBuildIdentity,
                encoding: .strictJSON, bytes: Self.json("source")
            )
        }
    }

    @Test(arguments: [
        CampaignManifestFault.substituteCanonicalManifest,
        .postReadIdentityDrift,
    ])
    func finalManifestMustRemainIdenticalToReturnedSeal(
        _ fault: CampaignManifestFault
    ) throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let system = CampaignFaultingEvidenceSystem(base: fixture.system)
        let writer = try fixture.makeWriter(system: system)
        try fixture.populate(writer)
        system.manifestFault = fault
        #expect(throws: InvestigationMachineRawEvidenceError
            .uncertain(stage: .validateFinal)) {
            _ = try writer.finalize()
        }
        #expect(throws: InvestigationMachineRawEvidenceError.alreadyTerminal) {
            _ = try writer.finalize()
        }
    }

    @Test
    func postManifestSyncFailureCannotReturnASeal() throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let system = CampaignFaultingEvidenceSystem(base: fixture.system)
        let writer = try fixture.makeWriter(system: system)
        try fixture.populate(writer)
        system.failPostManifestSynchronize = true
        #expect(throws: InvestigationMachineRawEvidenceError
            .uncertain(stage: .synchronizeDirectory)) {
            _ = try writer.finalize()
        }
        #expect(FileManager.default.fileExists(
            atPath: fixture.evidenceRoot.appending(path: "manifest.bin").path
        ))
        #expect(throws: InvestigationMachineRawEvidenceError.alreadyTerminal) {
            _ = try writer.finalize()
        }
    }

    fileprivate static func event(
        sequence: UInt32, attempt: UUID, kind: InvestigationMachineAttemptEventKind,
        previous: InvestigationHandoffSHA256
    ) throws -> InvestigationMachineAttemptEventV1 {
        try .init(
            sequence: sequence, attemptUUID: attempt, kind: kind,
            previousEventSHA256: previous,
            observedAt: .init(rawValue: Int64(sequence)),
            payload: json("event-\(sequence)")
        )
    }

    fileprivate static func zeroDigest() throws -> InvestigationHandoffSHA256 {
        try .init(rawBytes: Data(repeating: 0, count: 32))
    }

    fileprivate static func digest(_ marker: UInt8) -> InvestigationHandoffSHA256 {
        .hashing(Data(repeating: marker, count: 32))
    }

    fileprivate static func json(_ value: String) -> Data {
        Data("{\"value\":\"\(value)\"}".utf8)
    }

    private static func lengthPrefixed(_ payload: Data) -> Data {
        let count = UInt32(payload.count)
        return Data([
            UInt8(count >> 24), UInt8(truncatingIfNeeded: count >> 16),
            UInt8(truncatingIfNeeded: count >> 8),
            UInt8(truncatingIfNeeded: count),
        ]) + payload
    }

    private static func requireMetadata(
        _ url: URL, type: mode_t, permissions: mode_t
    ) throws {
        var value = stat()
        try #require(lstat(url.path, &value) == 0)
        #expect(value.st_mode & S_IFMT == type)
        #expect(value.st_mode & 0o7777 == permissions)
        #expect(value.st_uid == geteuid())
        #expect(value.st_gid == getegid())
        if type == S_IFREG { #expect(value.st_nlink == 1) }
    }
}

private struct CampaignEvidenceFixture {
    let campaignUUID: UUID
    let attemptUUID: UUID
    let sourceBinding: InvestigationMachineCampaignSourceBinding
    let artifacts: [InvestigationMachineEvidenceArtifact]
    let attemptSummary: InvestigationMachineAttemptSummary

    static func make() throws -> Self {
        let sourceBinding = try InvestigationMachineCampaignSourceBinding(
            repositoryHEAD: String(repeating: "1", count: 40),
            repositoryTree: String(repeating: "2", count: 40),
            canonicalSourceManifestSHA256:
                InvestigationMachineCampaignEvidenceTests.digest(0x31),
            buildProvenanceSHA256:
                InvestigationMachineCampaignEvidenceTests.digest(0x32),
            signedRuntimeBindingSHA256:
                InvestigationMachineCampaignEvidenceTests.digest(0x33)
        )
        let attempt = uuid(0x22)
        let events = try privilegedEvents(attempt: attempt)
        return try Self(
            campaignUUID: uuid(0x21), attemptUUID: attempt,
            sourceBinding: sourceBinding, artifacts: makeArtifacts(events: events),
            attemptSummary: InvestigationMachineAttemptEventChain.summary(
                events, mode: .privileged)
        )
    }

    func artifact(
        phase: InvestigationMachineEvidencePhase, leaf: String,
        role: InvestigationMachineEvidenceRole,
        encoding: InvestigationMachineEvidenceEncoding, marker: UInt8
    ) throws -> InvestigationMachineEvidenceArtifact {
        try .init(
            path: .init(phase: phase, leafName: leaf), role: role,
            encoding: encoding, byteCount: 16,
            sha256: InvestigationMachineCampaignEvidenceTests.digest(marker)
        )
    }

    private static func makeArtifacts(
        events: [InvestigationMachineAttemptEventV1]
    ) throws
        -> [InvestigationMachineEvidenceArtifact]
    {
        func artifact(
            _ phase: InvestigationMachineEvidencePhase, _ leaf: String,
            _ role: InvestigationMachineEvidenceRole,
            _ encoding: InvestigationMachineEvidenceEncoding, _ marker: UInt8
        ) throws -> InvestigationMachineEvidenceArtifact {
            try .init(
                path: .init(phase: phase, leafName: leaf), role: role,
                encoding: encoding, byteCount: 16,
                sha256: InvestigationMachineCampaignEvidenceTests.digest(marker)
            )
        }
        let fixed = try [
            artifact(.preflight, "source-build.json", .sourceBuildIdentity, .strictJSON, 1),
            artifact(.install, "installed.json", .builtStagingInstalledIdentity, .strictJSON, 2),
            artifact(.authorization, "policy-probe.json", .policyProbe, .strictJSON, 3),
            artifact(.authorization, "human-attestation.json", .humanPromptAttestation, .strictJSON, 4),
            artifact(.authorization, "capability-counts.json", .noAuthModelNetworkCounters, .strictJSON, 5),
            artifact(.driverEpochs, "coordinator-receipt.bin", .protocolReceipt, .framedCanonicalBinary, 6),
            artifact(.driverEpochs, "diagnostic-output.bin", .diagnosticOutput, .opaqueBytes, 7),
            artifact(.uninstall, "uninstall.json", .uninstallEvidence, .strictJSON, 10),
            artifact(.verifier, "global-post-teardown.json", .globalPostTeardown, .strictJSON, 11),
            artifact(.verifier, "verification-input.json", .verifierInput, .strictJSON, 12),
        ]
        let l2 = try (1...8).map { index in
            try artifact(
                .driverEpochs, String(format: "epoch-%02d-l2.json", index),
                .epochL2Projection, .strictJSON, UInt8(20 + index)
            )
        }
        let residue = try (1...8).map { index in
            try artifact(
                .driverEpochs,
                String(format: "epoch-%02d-residue.json", index),
                .epochResidueProjection, .strictJSON, UInt8(40 + index)
            )
        }
        let eventArtifacts = try events.enumerated().map { index, event in
            let bytes = try event.encoded()
            return try InvestigationMachineEvidenceArtifact(
                path: .init(
                    phase: .authorization,
                    leafName: String(format: "attempt-event-%04d.bin", index + 1)
                ), role: .attemptEvent, encoding: .canonicalBinary,
                byteCount: UInt64(bytes.count), sha256: .hashing(bytes)
            )
        }
        return fixed + l2 + residue + eventArtifacts
    }

    private static func privilegedEvents(
        attempt: UUID
    ) throws -> [InvestigationMachineAttemptEventV1] {
        var events: [InvestigationMachineAttemptEventV1] = []
        for (index, kind) in [
            InvestigationMachineAttemptEventKind.prepared, .armedConsumed,
            .spawnObserved, .terminal,
        ].enumerated() {
            let previous = try events.last.map {
                InvestigationHandoffSHA256.hashing(try $0.encoded())
            } ?? InvestigationMachineCampaignEvidenceTests.zeroDigest()
            events.append(try InvestigationMachineCampaignEvidenceTests.event(
                sequence: UInt32(index + 1), attempt: attempt, kind: kind,
                previous: previous
            ))
        }
        return events
    }

    static func uuid(_ marker: UInt8) -> UUID {
        UUID(uuid: (marker, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    }
}

enum CampaignTreeMutation: CaseIterable {
    case extraSymlink
    case hardLink
    case wrongMode
}

enum CampaignEvidenceFault: CaseIterable {
    case validatePending
    case writePending
    case synchronizeFile
    case publish
    case synchronizeDirectory
    case reopenFinal
    case readFinal
    case closeDescriptor

    var expectedStage: InvestigationMachineRawEvidenceFailureStage {
        switch self {
        case .validatePending: .validatePending
        case .writePending: .writePending
        case .synchronizeFile: .synchronizeFile
        case .publish: .publish
        case .synchronizeDirectory: .synchronizeDirectory
        case .reopenFinal: .reopenFinal
        case .readFinal: .readFinal
        case .closeDescriptor: .closeDescriptor
        }
    }
}

enum CampaignManifestFault: CaseIterable {
    case substituteCanonicalManifest
    case postReadIdentityDrift
}

enum CampaignReceiptBindingMutation: CaseIterable {
    case attempt
    case build
    case signedRuntime
}

enum CampaignInitializationFault: CaseIterable {
    case parentMetadata
    case rootNamedMetadata
    case phaseNamedMetadata

    var expectedStage: InvestigationMachineRawEvidenceFailureStage {
        switch self {
        case .parentMetadata: .validateParent
        case .rootNamedMetadata, .phaseNamedMetadata: .validateDirectory
        }
    }
}

enum CampaignFinalObservationFault: CaseIterable {
    case directory, root, file
    func name(campaignUUID: UUID) -> String { self == .root
        ? InvestigationMachineRawEvidenceWriter.rootName(campaignUUID: campaignUUID)
        : (self == .directory ? "01-preflight" : "source-build.json") }
    var expectedStage: InvestigationMachineRawEvidenceFailureStage { self == .file
        ? .validateFinal : .validateDirectory }
}

private final class CampaignEvidenceDiskFixture {
    let parent: URL
    let parentDescriptor: Int32
    let campaignUUID = CampaignEvidenceFixture.uuid(0x51)
    let attemptUUID = CampaignEvidenceFixture.uuid(0x52)
    let sourceBinding: InvestigationMachineCampaignSourceBinding
    let system = DarwinInvestigationMachineRawEvidenceSystem()
    let expectedArtifactCount = 10
    let privilegedArtifactCount = 30

    var evidenceRoot: URL {
        parent.appending(path:
            InvestigationMachineRawEvidenceWriter.rootName(
                campaignUUID: campaignUUID))
    }

    private init(parent: URL, parentDescriptor: Int32) throws {
        self.parent = parent
        self.parentDescriptor = parentDescriptor
        sourceBinding = try .init(
            repositoryHEAD: String(repeating: "a", count: 40),
            repositoryTree: String(repeating: "b", count: 40),
            canonicalSourceManifestSHA256:
                InvestigationMachineCampaignEvidenceTests.digest(0x61),
            buildProvenanceSHA256:
                InvestigationMachineCampaignEvidenceTests.digest(0x62),
            signedRuntimeBindingSHA256:
                InvestigationMachineCampaignEvidenceTests.digest(0x63)
        )
    }

    static func make() throws -> CampaignEvidenceDiskFixture {
        let parent = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-campaign-evidence-parent-" + UUID().uuidString,
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: parent, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        try #require(chmod(parent.path, 0o700) == 0)
        guard let resolved = realpath(parent.path, nil) else {
            throw CampaignEvidenceFixtureError.realpath(errno)
        }
        defer { free(resolved) }
        let canonicalParent = URL(filePath: String(cString: resolved))
        let descriptor = open(
            canonicalParent.path,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW_ANY
                | O_UNIQUE | O_NONBLOCK
        )
        try #require(descriptor >= 3)
        return try CampaignEvidenceDiskFixture(
            parent: parent, parentDescriptor: descriptor
        )
    }

    func makeWriter(
        system selectedSystem: (any InvestigationMachineRawEvidenceSystem)? = nil,
        mode: InvestigationMachineAttemptMode = .dryRun
    ) throws -> InvestigationMachineRawEvidenceWriter {
        let selectedSystem = selectedSystem ?? system
        let parentMetadata = try selectedSystem.metadata(
            descriptor: parentDescriptor
        )
        return try InvestigationMachineRawEvidenceWriter(
            system: selectedSystem, parentDescriptor: parentDescriptor,
            expectedParentIdentity: parentMetadata.identity,
            campaignUUID: campaignUUID, attemptUUID: attemptUUID,
            mode: mode,
            sourceBinding: sourceBinding
        )
    }

    func populate(_ writer: InvestigationMachineRawEvidenceWriter) throws {
        _ = try writer.appendAttemptEvent(
            kind: .prepared, payload: Self.json("prepared"),
            observedAt: try .init(rawValue: 1)
        )
        _ = try writer.appendAttemptEvent(
            kind: .cancelledBeforeArm, payload: Self.json("cancelled"),
            observedAt: try .init(rawValue: 2)
        )
        try populateDryRunArtifacts(writer)
    }

    func populateDryRunArtifacts(
        _ writer: InvestigationMachineRawEvidenceWriter
    ) throws {
        try write([
            (.preflight, "source-build.json", .sourceBuildIdentity, .strictJSON, Self.json("source")),
            (.install, "installed.json", .builtStagingInstalledIdentity, .strictJSON, Self.json("installed")),
            (.authorization, "policy-probe.json", .policyProbe, .strictJSON, Self.json("policy")),
            (.authorization, "human-attestation.json", .humanPromptAttestation, .strictJSON, Self.json("human")),
            (.authorization, "capability-counts.json", .noAuthModelNetworkCounters, .strictJSON, Self.json("counts")),
            (.uninstall, "uninstall.json", .uninstallEvidence, .strictJSON, Self.json("uninstall")),
            (.verifier, "global-post-teardown.json", .globalPostTeardown, .strictJSON, Self.json("zero")),
            (.verifier, "verification-input.json", .verifierInput, .strictJSON, Self.json("verify")),
        ], to: writer)
    }

    func populatePrivilegedArtifacts(
        _ writer: InvestigationMachineRawEvidenceWriter
    ) throws {
        var values: [(InvestigationMachineEvidencePhase, String, InvestigationMachineEvidenceRole, InvestigationMachineEvidenceEncoding, Data)] = [
            (.preflight, "source-build.json", .sourceBuildIdentity, .strictJSON, Self.json("source")),
            (.install, "installed.json", .builtStagingInstalledIdentity, .strictJSON, Self.json("installed")),
            (.authorization, "policy-probe.json", .policyProbe, .strictJSON, Self.json("policy")),
            (.authorization, "human-attestation.json", .humanPromptAttestation, .strictJSON, Self.json("human")),
            (.authorization, "capability-counts.json", .noAuthModelNetworkCounters, .strictJSON, Self.json("counts")),
            (.driverEpochs, "coordinator-receipt.bin", .protocolReceipt, .framedCanonicalBinary, try CampaignCoordinatorReceiptFixture.frame(
                attemptUUID: attemptUUID,
                buildProvenanceSHA256: sourceBinding.buildProvenanceSHA256.lowercaseHex,
                signedBindingSHA256: sourceBinding.signedRuntimeBindingSHA256)),
            (.driverEpochs, "diagnostic-output.bin", .diagnosticOutput, .opaqueBytes, Data()),
            (.uninstall, "uninstall.json", .uninstallEvidence, .strictJSON, Self.json("uninstall")),
            (.verifier, "global-post-teardown.json", .globalPostTeardown, .strictJSON, Self.json("zero")),
            (.verifier, "verification-input.json", .verifierInput, .strictJSON, Self.json("verify")),
        ]
        for index in 1...8 {
            values.append((
                .driverEpochs, String(format: "epoch-%02d-l2.json", index),
                .epochL2Projection, .strictJSON, Self.json("l2-\(index)")
            ))
            values.append((
                .driverEpochs, String(format: "epoch-%02d-residue.json", index),
                .epochResidueProjection, .strictJSON, Self.json("residue-\(index)")
            ))
        }
        try write(values, to: writer)
    }

    private func write(
        _ values: [(InvestigationMachineEvidencePhase, String,
            InvestigationMachineEvidenceRole, InvestigationMachineEvidenceEncoding, Data)],
        to writer: InvestigationMachineRawEvidenceWriter
    ) throws {
        for value in values {
            _ = try writer.writeArtifact(
                path: .init(phase: value.0, leafName: value.1),
                role: value.2, encoding: value.3, bytes: value.4
            )
        }
    }

    func apply(_ mutation: CampaignTreeMutation) throws {
        let phase = evidenceRoot.appending(path: "01-preflight")
        let source = phase.appending(path: "source-build.json")
        switch mutation {
        case .extraSymlink:
            try #require(symlink("source-build.json",
                phase.appending(path: "extra-link").path) == 0)
        case .hardLink:
            try #require(link(source.path,
                phase.appending(path: "extra-hardlink").path) == 0)
        case .wrongMode:
            try #require(chmod(source.path, 0o644) == 0)
        }
    }

    func remove() {
        _ = Darwin.close(parentDescriptor)
        try? FileManager.default.removeItem(at: parent)
    }

    private static func json(_ value: String) -> Data {
        InvestigationMachineCampaignEvidenceTests.json(value)
    }
}

private enum CampaignEvidenceFixtureError: Error {
    case realpath(Int32)
}

private struct CampaignCoordinatorReceiptFixture {
    let producer: InvestigationMachineGateCoordinatorReceiptV1
    let consumer: InvestigationMachineCoordinatorRawReceiptV1

    static func make(
        attemptUUID: UUID = CampaignEvidenceFixture.uuid(0x72),
        capsuleSize: Int64 = 104,
        buildProvenanceSHA256: String = String(repeating: "a", count: 64),
        signedBindingSHA256: InvestigationHandoffSHA256 =
            InvestigationMachineCampaignEvidenceTests.digest(0x71)
    ) throws -> Self {
        let build = buildProvenanceSHA256
        let binding = signedBindingSHA256
        let attempt = attemptUUID
        let input = InvestigationMachineCampaignEvidenceTests.digest(0x73)
        let capsule = InvestigationMachineGateNodeObservation(
            device: 101, inode: 102, generation: 103, size: capsuleSize
        )
        let gate = InvestigationMachineCampaignEvidenceTests.digest(0x74)
        let transport = InvestigationMachineCampaignEvidenceTests.digest(0x75)
        let producer = try InvestigationMachineGateCoordinatorReceiptV1(
            buildProvenanceSHA256: build, signedBindingSHA256: binding,
            outerAttemptUUID: attempt, wholeProjectedInputSHA256: input,
            capsule: capsule, gateExecutableSHA256: gate,
            gateTransportReceiptSHA256: transport, gateProcessID: 4_001,
            gateProcessGroupID: 4_001, gateSessionID: 3_901,
            exactGateWaitClassification: .exited(status: 0),
            receiptReachedEOF: true, receiptOverflowObserved: false,
            receiptDeadlineExpired: false, capsuleSettlementRemoved: true,
            attemptBaseRetired: true, runtimeArtifactsRetired: true,
            monotonicStartedNanoseconds: 10,
            monotonicCompletedNanoseconds: 20
        )
        let consumer = try InvestigationMachineCoordinatorRawReceiptV1(
            buildProvenanceSHA256: build, signedBindingSHA256: binding,
            outerAttemptUUID: attempt, wholeProjectedInputSHA256: input,
            capsule: .init(
                device: 101, inode: 102, generation: 103, size: capsuleSize),
            gateExecutableSHA256: gate,
            gateTransportReceiptSHA256: transport, gateProcessID: 4_001,
            gateProcessGroupID: 4_001, gateSessionID: 3_901,
            exactGateWaitClassification: .exited(status: 0),
            receiptReachedEOF: true, receiptOverflowObserved: false,
            receiptDeadlineExpired: false, capsuleSettlementRemoved: true,
            attemptBaseRetired: true, runtimeArtifactsRetired: true,
            monotonicStartedNanoseconds: 10,
            monotonicCompletedNanoseconds: 20
        )
        return .init(producer: producer, consumer: consumer)
    }

    static func makeConsumer(
        capsuleSize: Int64
    ) throws -> InvestigationMachineCoordinatorRawReceiptV1 {
        let build = String(repeating: "a", count: 64)
        return try .init(
            buildProvenanceSHA256: build,
            signedBindingSHA256: InvestigationMachineCampaignEvidenceTests.digest(0x71),
            outerAttemptUUID: CampaignEvidenceFixture.uuid(0x72),
            wholeProjectedInputSHA256: InvestigationMachineCampaignEvidenceTests.digest(0x73),
            capsule: .init(
                device: 101, inode: 102, generation: 103, size: capsuleSize),
            gateExecutableSHA256: InvestigationMachineCampaignEvidenceTests.digest(0x74),
            gateTransportReceiptSHA256: InvestigationMachineCampaignEvidenceTests.digest(0x75),
            gateProcessID: 4_001, gateProcessGroupID: 4_001,
            gateSessionID: 3_901, exactGateWaitClassification: .exited(status: 0),
            receiptReachedEOF: true, receiptOverflowObserved: false,
            receiptDeadlineExpired: false, capsuleSettlementRemoved: true,
            attemptBaseRetired: true, runtimeArtifactsRetired: true,
            monotonicStartedNanoseconds: 10, monotonicCompletedNanoseconds: 20
        )
    }

    static func frame(
        attemptUUID: UUID,
        buildProvenanceSHA256: String = String(repeating: "a", count: 64),
        signedBindingSHA256: InvestigationHandoffSHA256 =
            InvestigationMachineCampaignEvidenceTests.digest(0x71)
    ) throws -> Data {
        let payload = try make(
            attemptUUID: attemptUUID,
            buildProvenanceSHA256: buildProvenanceSHA256,
            signedBindingSHA256: signedBindingSHA256
        ).producer.encoded()
        let count = UInt32(payload.count)
        return Data([
            UInt8(count >> 24), UInt8(truncatingIfNeeded: count >> 16),
            UInt8(truncatingIfNeeded: count >> 8), UInt8(truncatingIfNeeded: count),
        ]) + payload
    }
}

private final class CampaignFaultingEvidenceSystem:
    InvestigationMachineRawEvidenceSystem, @unchecked Sendable
{
    private let base: DarwinInvestigationMachineRawEvidenceSystem
    var failNextWrite = false
    var manifestFault: CampaignManifestFault?
    var failPostManifestSynchronize = false
    private var fault: CampaignEvidenceFault?
    private var openCount = 0
    private var synchronizeCount = 0
    private var manifestDescriptor = Int32(-1)
    private var manifestMetadataCount = 0
    private var manifestWasPublished = false
    var failDirectoryCreationCall: Int?
    var driftDescriptor: Int32?
    var nextOpenedDescriptor: Int32?
    var protectedDescriptor: Int32?
    var failNamedMetadataName: String?
    private var createDirectoryCount = 0
    private(set) var openedDescriptors: [Int32] = []
    private(set) var closedDescriptors: [Int32] = []
    private(set) var closeAttempts: [Int32] = []
    private var initializationFault: CampaignInitializationFault?
    private var metadataCount = 0
    private var namedMetadataCount = 0

    init(base: DarwinInvestigationMachineRawEvidenceSystem) { self.base = base }

    func arm(_ fault: CampaignEvidenceFault) {
        self.fault = fault
        openCount = 0
        synchronizeCount = 0
    }

    func armInitialization(_ fault: CampaignInitializationFault) {
        initializationFault = fault
        metadataCount = 0
        namedMetadataCount = 0
    }

    func effectiveIdentity() -> InvestigationMachineEvidenceOwnerIdentity {
        base.effectiveIdentity()
    }
    func inventory(descriptor: Int32, maximumEntryCount: Int) throws
        -> InvestigationMachineEvidenceInventory
    {
        try base.inventory(
            descriptor: descriptor, maximumEntryCount: maximumEntryCount)
    }
    func createDirectory(
        parentDescriptor: Int32, name: String, mode: mode_t
    ) throws {
        createDirectoryCount += 1
        if createDirectoryCount == failDirectoryCreationCall { throw failure() }
        try base.createDirectory(
            parentDescriptor: parentDescriptor, name: name, mode: mode)
    }
    func openComponent(
        parentDescriptor: Int32, name: String, flags: Int32, mode: mode_t?
    ) throws -> Int32 {
        if let nextOpenedDescriptor {
            self.nextOpenedDescriptor = nil
            return nextOpenedDescriptor
        }
        openCount += 1
        if fault == .reopenFinal && openCount == 2 { throw failure() }
        let descriptor = try base.openComponent(
            parentDescriptor: parentDescriptor, name: name,
            flags: flags, mode: mode)
        openedDescriptors.append(descriptor)
        if name == "manifest.bin" { manifestDescriptor = descriptor }
        return descriptor
    }
    func metadata(descriptor: Int32) throws
        -> InvestigationMachineEvidenceNodeMetadata
    {
        metadataCount += 1
        if initializationFault == .parentMetadata && metadataCount == 1 {
            throw failure()
        }
        let value = try base.metadata(descriptor: descriptor)
        if descriptor == driftDescriptor {
            return .init(
                identity: .init(
                    device: value.identity.device, inode: value.identity.inode + 1,
                    generation: value.identity.generation, size: value.identity.size
                ), fileType: value.fileType, ownerUserID: value.ownerUserID,
                ownerGroupID: value.ownerGroupID, permissions: value.permissions,
                linkCount: value.linkCount, flags: value.flags
            )
        }
        guard descriptor == manifestDescriptor,
              manifestFault == .postReadIdentityDrift else { return value }
        manifestMetadataCount += 1
        guard manifestMetadataCount >= 2 else { return value }
        return .init(
            identity: .init(
                device: value.identity.device, inode: value.identity.inode + 1,
                generation: value.identity.generation, size: value.identity.size
            ), fileType: value.fileType, ownerUserID: value.ownerUserID,
            ownerGroupID: value.ownerGroupID, permissions: value.permissions,
            linkCount: value.linkCount, flags: value.flags
        )
    }
    func namedMetadata(
        parentDescriptor: Int32, name: String, flags: Int32
    ) throws -> InvestigationMachineEvidenceNodeMetadata {
        if name == failNamedMetadataName {
            failNamedMetadataName = nil
            throw failure()
        }
        namedMetadataCount += 1
        if initializationFault == .rootNamedMetadata && namedMetadataCount == 1 {
            throw failure()
        }
        if initializationFault == .phaseNamedMetadata && namedMetadataCount == 2 {
            throw failure()
        }
        return try base.namedMetadata(
            parentDescriptor: parentDescriptor, name: name, flags: flags)
    }
    func descriptorFlags(_ descriptor: Int32) throws -> Int32 {
        try base.descriptorFlags(descriptor)
    }
    func descriptorStatusFlags(_ descriptor: Int32) throws -> Int32 {
        try base.descriptorStatusFlags(descriptor)
    }
    func setPermissions(descriptor: Int32, mode: mode_t) throws {
        if fault == .validatePending { throw failure() }
        try base.setPermissions(descriptor: descriptor, mode: mode)
    }
    func extendedACLIsEmpty(descriptor: Int32) throws -> Bool {
        try base.extendedACLIsEmpty(descriptor: descriptor)
    }
    func extendedAttributeNames(descriptor: Int32) throws -> [String] {
        try base.extendedAttributeNames(descriptor: descriptor)
    }
    func synchronize(descriptor: Int32) throws {
        synchronizeCount += 1
        if fault == .synchronizeFile && synchronizeCount == 1 { throw failure() }
        if fault == .synchronizeDirectory && synchronizeCount == 2 { throw failure() }
        if failPostManifestSynchronize && manifestWasPublished { throw failure() }
        try base.synchronize(descriptor: descriptor)
    }
    func write(descriptor: Int32, bytes: Data, offset: Int64) throws -> Int {
        if failNextWrite || fault == .writePending {
            failNextWrite = false
            fault = nil
            return 0
        }
        return try base.write(
            descriptor: descriptor, bytes: bytes, offset: offset)
    }
    func rename(
        parentDescriptor: Int32, oldName: String, newName: String, flags: Int32
    ) throws {
        if fault == .publish { fault = nil; throw failure() }
        try base.rename(
            parentDescriptor: parentDescriptor, oldName: oldName,
            newName: newName, flags: flags)
        if newName == "manifest.bin" { manifestWasPublished = true }
    }
    func read(
        descriptor: Int32, maximumByteCount: Int, offset: Int64
    ) throws -> Data {
        if fault == .readFinal { fault = nil; throw failure() }
        let bytes = try base.read(
            descriptor: descriptor, maximumByteCount: maximumByteCount,
            offset: offset)
        guard descriptor == manifestDescriptor, offset == 0,
              manifestFault == .substituteCanonicalManifest else { return bytes }
        let manifest = try InvestigationMachineEvidenceManifestV1.decode(bytes)
        return try InvestigationMachineEvidenceManifestV1(
            campaignUUID: CampaignEvidenceFixture.uuid(0xfe),
            attemptUUID: manifest.attemptUUID,
            sourceBinding: manifest.sourceBinding, artifacts: manifest.artifacts,
            attemptSummary: manifest.attemptSummary
        ).encoded()
    }
    func close(descriptor: Int32) throws {
        closeAttempts.append(descriptor)
        if descriptor == protectedDescriptor { return }
        try base.close(descriptor: descriptor)
        closedDescriptors.append(descriptor)
        if fault == .closeDescriptor { fault = nil; throw failure() }
    }

    private func failure() -> InvestigationMachineRawEvidenceSystemError {
        .errno(EIO)
    }
}
