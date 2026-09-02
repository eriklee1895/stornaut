import Darwin
import Foundation
import Testing

@testable import StornautInvestigationMachineCampaign
@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationMachineCampaignSupport
@testable import StornautInvestigationMachineDriverSupport
@testable import StornautInvestigationMachineGateCoordinatorSupport
@testable import StornautInvestigationMachineGateSupport
@testable import StornautInvestigationInstalledL2

@Suite("Investigation machine campaign evidence", .serialized)
struct InvestigationMachineCampaignEvidenceTests {
    @Test(arguments: CampaignLifecycleFinalizerFault.allCases)
    func lifecycleFinalizerMapsEveryUnprovedUninstallToUncertainty(
        _ fault: CampaignLifecycleFinalizerFault
    ) throws {
        var uninstallCount = 0, reportCount = 0
        #expect(throws:
            InvestigationMachineCampaignLifecycleFinalizer.Error
                .installedStateUncertain
        ) {
            _ = try InvestigationMachineCampaignLifecycleFinalizer.run(
                uninstall: {
                    uninstallCount += 1
                    if fault == .runner { throw CampaignEvidenceFixtureError.fault }
                    return .init(status: fault == .status ? 1 : 0,
                        output: Data([0x2a]))
                },
                decode: { data in
                    if fault == .decode { throw CampaignEvidenceFixtureError.fault }
                    return data
                },
                validate: { _ in
                    if fault == .validate { throw CampaignEvidenceFixtureError.fault }
                },
                reportUncertainty: { reportCount += 1 }) as Data
        }
        #expect(uninstallCount == 1)
        #expect(reportCount == 1)
    }

    @Test
    func lifecycleFinalizerReturnsOneVerifiedReceiptWithoutReporting() throws {
        var uninstallCount = 0, reportCount = 0, validateCount = 0
        let receipt: Data = try InvestigationMachineCampaignLifecycleFinalizer.run(
            uninstall: { uninstallCount += 1; return .init(
                status: 0, output: Data([0x2a])) },
            decode: { $0 },
            validate: { _ in validateCount += 1 },
            reportUncertainty: { reportCount += 1 })
        #expect(receipt == Data([0x2a]))
        #expect(uninstallCount == 1 && validateCount == 1 && reportCount == 0)
    }

    @Test
    func independentVerifierRejectsSemanticallyForgedCanonicalCorpus() throws {
        let result = try privilegedVerifierResult(
            semanticForgery: true, sealName: "semantic-seal.json")
        #expect(result.status != 0)
    }

    @Test
    func productionEpochCorpusRoundTripsThroughAllIndependentDecoders() async throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let projectedInput = try fixture.projectedInput()
        let bundle = try await CampaignEpochCorpus.productionBundle(projectedInput: projectedInput)
        let transport = try fixture.privilegedTransport(productionBundle: bundle)

        let decoded = try InvestigationMachineEpochEvidenceBundle.decode(transport.bundle)
        let gate = try InvestigationMachineCampaignRawGateReceiptValidator
            .validate(transport.rawGateReceipt,
                expectedAttemptUUID: transport.preArm.outerAttemptUUID,
                expectedWholeInputSHA256: transport.preArm.wholeProjectedInputSHA256,
                expectedOuterIdentity: fixture.outerIdentity,
                finalReceipt: transport.finalReceipt)
        let validated = try InvestigationMachineCampaignEpochEvidenceValidator
            .validate(bundle: transport.bundle, projectedInput: transport.projectedInput)

        #expect(decoded.epochs.count == 8)
        #expect(try decoded.encoded() == transport.bundle)
        #expect(validated.bytes == transport.bundle)
        #expect(gate.preparedFrameSHA256.rawBytes.contains { $0 != 0 })
        #expect(validated.epochs.count == 8)
        #expect(validated.completionBytes == transport.completion)
        #expect(validated.epochs.map(\.claimEvidenceSHA256) == transport.epochs.map(\.claimEvidenceSHA256))
        #expect(validated.epochs.map(\.helperIdentitySHA256) == transport.epochs.map(\.helperIdentitySHA256))
        #expect(validated.epochs.map(\.completionBindingSHA256) == transport.epochs.map(\.completionBindingSHA256))
        let verifier = try privilegedVerifierResult(fixture: fixture, transport: transport)
        #expect(verifier.status == 0, Comment(rawValue: verifier.stderr))
    }

    @Test(arguments: CampaignEpochSemanticMutation.allCases)
    fileprivate func campaignEpochValidatorRejectsCanonicalSemanticRewrap(
        _ mutation: CampaignEpochSemanticMutation) throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let transport = try fixture.privilegedTransport(semanticMutation: mutation)

        if mutation == .claimZeroRequestBinding || mutation == .installedL2ZeroContinuousClocks
            || mutation == .installedL2ObservedAfterTerminal {
            #expect(throws: (any Error).self) {
                _ = try InvestigationMachineEpochEvidenceBundle.decode(transport.bundle)
            }
        }
        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineCampaignEpochEvidenceValidator.validate(
                bundle: transport.bundle, projectedInput: transport.projectedInput)
        }
    }

    @Test(arguments: CampaignRawGateMutation.allCases)
    func rawGateValidatorRejectsTransportRewrap(_ mutation: CampaignRawGateMutation) throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let transport = try fixture.privilegedTransport(rawGateMutation: mutation)

        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineCampaignRawGateReceiptValidator.validate(
                transport.rawGateReceipt,
                expectedAttemptUUID: transport.preArm.outerAttemptUUID,
                expectedWholeInputSHA256: transport.preArm.wholeProjectedInputSHA256,
                expectedOuterIdentity: fixture.outerIdentity,
                finalReceipt: transport.finalReceipt)
        }
    }

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
        #expect(InvestigationHandoffSHA256.hashing(producerBytes).lowercaseHex
            == "92418d3ce5be398d842763863f001a39340ba2c1d80407a95ca4719c90ebdf2d")
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
        let uncertain = try Self.event(
            sequence: 3, attempt: attempt, kind: .spawnUncertain,
            previous: .hashing(try armed.encoded()))
        try InvestigationMachineAttemptEventChain.validateComplete(
            [prepared, armed, uncertain], mode: .privileged)
        #expect(try InvestigationMachineAttemptEventChain.summary(
            [prepared, armed, uncertain], mode: .privileged).outcome
            == .transportLoss)
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
            kind: .prepared, payload: try Self.eventPayload(
                kind: .prepared, attempt: fixture.attemptUUID),
            observedAt: try .init(rawValue: 1)
        )
        for kind in [
            InvestigationMachineAttemptEventKind.armedConsumed,
            .spawnObserved, .spawnUncertain, .terminal,
        ] {
            #expect(throws: InvestigationMachineRawEvidenceError
                .dryRunAuthorityViolation) {
                _ = try writer.appendAttemptEvent(
                    kind: kind, payload: try Self.eventPayload(
                        kind: kind, attempt: fixture.attemptUUID),
                    observedAt: try .init(rawValue: 2)
                )
            }
        }
        _ = try writer.appendAttemptEvent(
            kind: .cancelledBeforeArm, payload: try Self.eventPayload(
                kind: .cancelledBeforeArm, attempt: fixture.attemptUUID),
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
                kind: kind, payload: try Self.eventPayload(
                    kind: kind, attempt: fixture.attemptUUID),
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
            kind: .prepared, payload: try Self.eventPayload(
                kind: .prepared, attempt: fixture.attemptUUID),
            observedAt: try .init(rawValue: 1)
        )
        _ = try writer.appendAttemptEvent(
            kind: .armedConsumed, payload: try Self.eventPayload(
                kind: .armedConsumed, attempt: fixture.attemptUUID),
            observedAt: try .init(rawValue: 2)
        )
        for kind in [
            InvestigationMachineAttemptEventKind.cancelledBeforeArm,
            .armedConsumed, .terminal,
        ] {
            #expect(throws: InvestigationMachineEvidenceContractError
                .invalidTransition) {
                _ = try writer.appendAttemptEvent(
                    kind: kind, payload: try Self.eventPayload(
                        kind: kind, attempt: fixture.attemptUUID),
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
        let missingSeal = fixture.parent.appending(path: "missing-seal.json")
        #expect(try Self.runVerifier(fixture.evidenceRoot, missingSeal).status != 0)
        #expect(throws: InvestigationMachineRawEvidenceError.alreadyTerminal) {
            _ = try writer.finalize()
        }
    }

    @Test
    func independentVerifierRequiresExactSealAndLeavesTreeUnchanged() throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let writer = try fixture.makeWriter()
        try fixture.populate(writer)
        let seal = try writer.finalize()
        let sealURL = fixture.parent.appending(path: "seal.json")
        try Self.writeSeal(seal, to: sealURL)
        let before = try Self.treeSnapshot(fixture.evidenceRoot)

        let first = try Self.runVerifier(fixture.evidenceRoot, sealURL)
        let second = try Self.runVerifier(fixture.evidenceRoot, sealURL)
        #expect(first.status == 0)
        #expect(first.stderr.isEmpty)
        #expect(first.stdout == "stornaut ii-c machine evidence verified\n")
        #expect(second == first)
        #expect(try Self.treeSnapshot(fixture.evidenceRoot) == before)

        let missing = try Self.runVerifier(
            fixture.evidenceRoot, fixture.parent.appending(path: "missing.json"))
        #expect(missing.status != 0)
        var forged = try #require(JSONSerialization.jsonObject(
            with: Data(contentsOf: sealURL)) as? [String: Any])
        forged["manifestSHA256"] = String(repeating: "0", count: 64)
        try Self.writeCanonicalJSON(forged, to: sealURL)
        #expect(try Self.runVerifier(fixture.evidenceRoot, sealURL).status != 0)
    }

    @Test(.serialized, arguments: [0, 1, 3, 7, 8])
    func independentVerifierAdmitsOnlyCompletePairedPrefix(
        _ epochCount: Int
    ) throws {
        let result = try privilegedVerifierResult(epochCount: epochCount)
        if epochCount == 8 {
            #expect(result.status == 0, Comment(rawValue: result.stderr))
        } else {
            #expect(result.status != 0)
            #expect(result.stderr.contains("non-admitting"))
        }
    }

    @Test
    func independentVerifierRejectsPromptVerifierCombinationForgery() throws {
        let result = try privilegedVerifierResult(
            promptVerifierForgery: true, sealName: "prompt-seal.json")
        #expect(result.status != 0)
    }

    @Test(arguments: CampaignDiagnosticMutation.allCases)
    func independentVerifierRejectsNoncanonicalDiagnosticEnvelope(
        _ mutation: CampaignDiagnosticMutation) throws {
        let result = try privilegedVerifierResult(
            diagnosticMutation: mutation, sealName: "diagnostic-seal.json")
        #expect(result.status != 0)
    }

    @Test(arguments: CampaignEpochSemanticMutation.allCases)
    func independentVerifierRejectsCanonicalEpochSemanticRewrap(
        _ mutation: CampaignEpochSemanticMutation) throws {
        let result = try privilegedVerifierResult(
            epochSemanticMutation: mutation, sealName: "epoch-semantic-seal.json")
        #expect(result.status != 0)
    }

    @Test(arguments: CampaignVerifierJoinMutation.allCases)
    func independentVerifierRejectsCrossArtifactJoinDrift(
        _ mutation: CampaignVerifierJoinMutation) throws {
        let result = try privilegedVerifierResult(
            joinMutation: mutation, sealName: "join-seal.json")
        #expect(result.status != 0)
    }

    private func privilegedVerifierResult(epochCount: Int = 8,
        semanticForgery: Bool = false, promptVerifierForgery: Bool = false,
        epochSemanticMutation: CampaignEpochSemanticMutation? = nil,
        joinMutation: CampaignVerifierJoinMutation? = nil,
        diagnosticMutation: CampaignDiagnosticMutation? = nil,
        sealName: String = "seal.json") throws -> CampaignVerifierResult {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let transport = try fixture.privilegedTransport(joinMutation: joinMutation,
            semanticMutation: epochSemanticMutation,
            diagnosticMutation: diagnosticMutation)
        return try privilegedVerifierResult(
            fixture: fixture, transport: transport, epochCount: epochCount,
            semanticForgery: semanticForgery, promptVerifierForgery: promptVerifierForgery,
            joinMutation: joinMutation, sealName: sealName)
    }

    private func privilegedVerifierResult(fixture: CampaignEvidenceDiskFixture,
        transport: CampaignPrivilegedTransport, epochCount: Int = 8,
        semanticForgery: Bool = false, promptVerifierForgery: Bool = false,
        joinMutation: CampaignVerifierJoinMutation? = nil,
        sealName: String = "seal.json") throws -> CampaignVerifierResult {
        let writer = try fixture.makeWriter(mode: .privileged)
        for (index, kind) in [
            InvestigationMachineAttemptEventKind.prepared, .armedConsumed,
            .spawnObserved, .terminal,
        ].enumerated() {
            _ = try writer.appendAttemptEvent(kind: kind,
                payload: try Self.eventPayload(kind: kind, attempt: fixture.attemptUUID),
                observedAt: try .init(rawValue: Int64(index + 1)))
        }
        try fixture.populatePrivilegedArtifacts(
            writer, epochCount: epochCount, semanticForgery: semanticForgery,
            promptVerifierForgery: promptVerifierForgery,
            joinMutation: joinMutation, transport: transport)
        var seal = try writer.finalize()
        if epochCount == 8 {
            seal = try fixture.completePrivilegedCorpus(
                seal, joinMutation: joinMutation, transport: transport)
        }
        let sealURL = fixture.parent.appending(path: sealName)
        try Self.writeSeal(seal, to: sealURL)
        return try Self.runVerifier(fixture.evidenceRoot, sealURL)
    }

    @Test(arguments: CampaignEpochPrefixMutation.allCases)
    func manifestRejectsMismatchedOrGappedEpochPairs(
        _ mutation: CampaignEpochPrefixMutation
    ) throws {
        let fixture = try CampaignEvidenceFixture.make()
        var artifacts = fixture.artifacts
        artifacts.removeAll { mutation.removes($0) }
        #expect(throws: InvestigationMachineEvidenceContractError.invalidOrdering) {
            _ = try InvestigationMachineEvidenceManifestV1(
                campaignUUID: fixture.campaignUUID,
                attemptUUID: fixture.attemptUUID,
                sourceBinding: fixture.sourceBinding, artifacts: artifacts,
                attemptSummary: fixture.attemptSummary)
        }
    }

    @Test
    func independentVerifierRejectsCanonicalButUntypedJSON() throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let writer = try fixture.makeWriter()
        _ = try writer.appendAttemptEvent(
            kind: .prepared, payload: try Self.eventPayload(
                kind: .prepared, attempt: fixture.attemptUUID),
            observedAt: try .init(rawValue: 1))
        _ = try writer.appendAttemptEvent(
            kind: .cancelledBeforeArm, payload: try Self.eventPayload(
                kind: .cancelledBeforeArm, attempt: fixture.attemptUUID),
            observedAt: try .init(rawValue: 2))
        let edgeJSON = try JSONSerialization.data(withJSONObject: [
            "bmp": ["\u{10000}": 2, "\u{e000}": 1],
            "nums": [0, 1.0, 1e-7, 1e20, 1.2345678901234567,
                Int64(9_007_199_254_740_993)],
            "slash": "a/b",
        ], options: [.sortedKeys, .withoutEscapingSlashes])
        try fixture.populateDryRunArtifacts(writer, sourceBuild: edgeJSON)
        let seal = try writer.finalize()
        let sealURL = fixture.parent.appending(path: "seal.json")
        try Self.writeSeal(seal, to: sealURL)
        #expect(try Self.runVerifier(fixture.evidenceRoot, sealURL).status != 0)
    }

    @Test
    func independentVerifierRejectsNoncanonicalAndParentSymlinkPaths() throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let writer = try fixture.makeWriter()
        try fixture.populate(writer)
        let seal = try writer.finalize()
        let sealURL = fixture.parent.appending(path: "seal.json")
        try Self.writeSeal(seal, to: sealURL)
        let rootName = fixture.evidenceRoot.lastPathComponent
        let traversalRoot = fixture.parent.path + "/unused/../" + rootName
        #expect(try Self.runVerifier(
            traversalRoot, sealURL.path).status != 0)

        let alias = fixture.parent.deletingLastPathComponent().appending(
            path: "stornaut-campaign-alias-" + UUID().uuidString)
        try #require(symlink(fixture.parent.path, alias.path) == 0)
        defer { _ = unlink(alias.path) }
        #expect(try Self.runVerifier(
            alias.appending(path: rootName).path, sealURL.path).status != 0)
        #expect(try Self.runVerifier(
            fixture.evidenceRoot.path, alias.appending(path: "seal.json").path
        ).status != 0)
        let caseAliasedRoot = "/PRIVATE" + String(
            fixture.evidenceRoot.path.dropFirst("/private".count))
        #expect(try Self.runVerifier(
            caseAliasedRoot, sealURL.path).status != 0)
    }

    @Test
    func independentVerifierRejectsNoncanonicalJSONBytes() throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let writer = try fixture.makeWriter()
        #expect(throws: InvestigationMachineEvidenceContractError.invalidEncoding) {
            try fixture.populateDryRunArtifacts(
                writer, sourceBuild: Data(#"{"value":"a\/b"}"#.utf8))
        }
    }

    @Test
    func independentVerifierRejectsMutatedArtifact() throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let writer = try fixture.makeWriter()
        try fixture.populate(writer)
        let seal = try writer.finalize()
        let sealURL = fixture.parent.appending(path: "seal.json")
        try Self.writeSeal(seal, to: sealURL)
        try Data("mutated".utf8).write(to: fixture.evidenceRoot.appending(
            path: "01-preflight/source-build.json"))
        #expect(try Self.runVerifier(fixture.evidenceRoot, sealURL).status != 0)
    }

    @Test(arguments: CampaignTreeMutation.allCases)
    func independentVerifierRejectsPhysicalTreeMutation(
        _ mutation: CampaignTreeMutation
    ) throws {
        let fixture = try CampaignEvidenceDiskFixture.make()
        defer { fixture.remove() }
        let writer = try fixture.makeWriter()
        try fixture.populate(writer)
        let seal = try writer.finalize()
        let sealURL = fixture.parent.appending(path: "seal.json")
        try Self.writeSeal(seal, to: sealURL)
        try fixture.apply(mutation)
        #expect(try Self.runVerifier(fixture.evidenceRoot, sealURL).status != 0)
    }

    fileprivate static func event(
        sequence: UInt32, attempt: UUID, kind: InvestigationMachineAttemptEventKind,
        previous: InvestigationHandoffSHA256
    ) throws -> InvestigationMachineAttemptEventV1 {
        try .init(
            sequence: sequence, attemptUUID: attempt, kind: kind,
            previousEventSHA256: previous,
            observedAt: .init(rawValue: Int64(sequence)),
            payload: try eventPayload(kind: kind, attempt: attempt)
        )
    }

    fileprivate static func zeroDigest() throws -> InvestigationHandoffSHA256 {
        try .init(rawBytes: Data(repeating: 0, count: 32))
    }

    private static func runVerifier(
        _ evidenceRoot: URL, _ sealURL: URL
    ) throws -> CampaignVerifierResult {
        try runVerifier(evidenceRoot.path, sealURL.path)
    }

    private static func runVerifier(
        _ evidenceRootPath: String, _ sealPath: String
    ) throws -> CampaignVerifierResult {
        let repository = URL(filePath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let process = Process(), output = Pipe(), errors = Pipe()
        process.executableURL = repository.appending(
            path: "scripts/verify-investigation-runtime-machine-report")
        process.arguments = [evidenceRootPath, sealPath]
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        return .init(
            status: process.terminationStatus,
            stdout: String(decoding: output.fileHandleForReading.readDataToEndOfFile(),
                as: UTF8.self),
            stderr: String(decoding: errors.fileHandleForReading.readDataToEndOfFile(),
                as: UTF8.self))
    }

    private static func writeSeal(
        _ seal: InvestigationMachineRawEvidenceSeal, to url: URL
    ) throws {
        try writeCanonicalJSON([
            "schemaVersion": 1,
            "campaignUUID": seal.campaignUUID.uuidString.lowercased(),
            "attemptUUID": seal.attemptUUID.uuidString.lowercased(),
            "rootIdentity": [
                "device": String(seal.rootIdentity.device),
                "inode": String(seal.rootIdentity.inode),
                "generation": String(seal.rootIdentity.generation),
                "size": String(seal.rootIdentity.size),
            ],
            "manifestSHA256": seal.manifestSHA256.lowercaseHex,
            "contentRootSHA256": seal.contentRootSHA256.lowercaseHex,
            "artifactCount": seal.artifactCount,
            "totalByteCount": String(seal.totalByteCount),
            "attemptSummary": [
                "attemptUUID": seal.attemptSummary.attemptUUID.uuidString.lowercased(),
                "mode": Int(seal.attemptSummary.mode.rawValue),
                "outcome": Int(seal.attemptSummary.outcome.rawValue),
                "consumed": seal.attemptSummary.consumed,
                "eventCount": Int(seal.attemptSummary.eventCount),
                "finalEventSHA256": seal.attemptSummary.finalEventSHA256.lowercaseHex,
            ],
        ], to: url)
    }

    private static func writeCanonicalJSON(_ object: Any, to url: URL) throws {
        try JSONSerialization.data(
            withJSONObject: object, options: [.sortedKeys]
        ).write(to: url)
        try #require(chmod(url.path, 0o600) == 0)
    }

    private static func treeSnapshot(_ root: URL) throws -> [String] {
        let enumerator = try #require(FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: nil))
        var values: [String] = []
        for case let url as URL in enumerator {
            var info = stat()
            try #require(lstat(url.path, &info) == 0)
            let relative = url.path.replacingOccurrences(
                of: root.path + "/", with: "")
            let digest = (info.st_mode & S_IFMT) == S_IFREG
                ? InvestigationHandoffSHA256.hashing(
                    try Data(contentsOf: url)).lowercaseHex : "-"
            values.append([relative, String(info.st_dev), String(info.st_ino),
                String(info.st_mode), String(info.st_nlink), String(info.st_size),
                String(info.st_mtimespec.tv_sec), String(info.st_mtimespec.tv_nsec),
                digest].joined(separator: "|"))
        }
        return values.sorted()
    }

    fileprivate static func digest(_ marker: UInt8) -> InvestigationHandoffSHA256 {
        .hashing(Data(repeating: marker, count: 32))
    }

    fileprivate static func json(_ value: String) -> Data {
        Data("{\"value\":\"\(value)\"}".utf8)
    }

    fileprivate static func eventPayload(
        kind: InvestigationMachineAttemptEventKind, attempt: UUID
    ) throws -> Data {
        let name: String = switch kind {
        case .prepared: "prepared"
        case .cancelledBeforeArm: "cancelledBeforeArm"
        case .armedConsumed: "armedConsumed"
        case .spawnObserved: "spawnObserved"
        case .spawnUncertain: "spawnUncertain"
        case .terminal: "terminal"
        }
        var value: [String: Any] = [
            "schemaVersion": 1, "kind": name,
            "attemptUUID": attempt.uuidString.lowercased(),
            "evidenceSetSHA256": digest(0xd1).lowercaseHex,
        ]
        if kind == .cancelledBeforeArm || kind == .spawnUncertain {
            value["reason"] = "fixture"
        } else if kind == .spawnObserved {
            value["processID"] = 3_901
            value["processGroupID"] = 3_901
            value["sessionID"] = 3_901
        }
        return try InvestigationMachineEvidenceJSON.canonicalData(value)
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

private struct CampaignVerifierResult: Equatable {
    let status: Int32
    let stdout: String
    let stderr: String
}

enum CampaignEpochPrefixMutation: CaseIterable {
    case mismatchedPair, gap

    func removes(_ artifact: InvestigationMachineEvidenceArtifact) -> Bool {
        switch self {
        case .mismatchedPair:
            artifact.role == .epochResidueProjection
                && artifact.path.leafName == "epoch-08-residue.json"
        case .gap:
            (artifact.role == .epochL2Projection
                || artifact.role == .epochResidueProjection)
                && artifact.path.leafName.contains("epoch-04-")
        }
    }
}

enum CampaignVerifierJoinMutation: CaseIterable {
    case sourcePreArm, epochWholeInput, ownershipEncoding, claimEvidence, helperIdentity, completionBinding, rawPreparedFrame
    case rawGateStartEnvelope, rawGateCompletionEnvelope, rawCoordinatorIdentity
}
enum CampaignRawGateMutation: CaseIterable { case preparedFrameDigest, enclosingStart, enclosingCompletion, coordinatorIdentity }
enum CampaignDiagnosticMutation: CaseIterable { case leadingBytes, trailingBytes, missingNewline, carriageReturnLineFeed }
enum CampaignEpochSemanticMutation: CaseIterable {
    case driverChildNonRoot, driverChildNonRootGroup, driverChildNonRootRealUser
    case driverChildNonRootRealGroup, driverChildAuditTokenMismatch
    case claimZeroRequestBinding, driverChildParentDriftAcrossEpochs
    case appChildHelperRole, appChildWrongParentAndProcessGroup
    case parentCrashZeroObservationDigests, parentCrashZeroObservedAt
    case installedL2ZeroContinuousClocks, installedL2ObservedAfterTerminal

    var targetIndex: Int {
        switch self {
        case .parentCrashZeroObservationDigests, .parentCrashZeroObservedAt: 6
        default: 7
        }
    }
}

private struct CampaignPrivilegedTransport {
    let finalFrame, receiptStream, diagnostic: Data
    let preArm: InvestigationMachineCampaignPreArmFrame
    let finalReceipt: InvestigationMachineCoordinatorRawReceiptV1
    let rawGateReceipt: Data
    let projectedInput: InvestigationProjectedCohortInput
    let bundle, completion: Data
    let epochs: [CampaignEpochArtifactRow]

    var preArmFrameSHA256: InvestigationHandoffSHA256 { preArm.frameSHA256 }
    var wholeProjectedInputSHA256: InvestigationHandoffSHA256 { projectedInput.wholeInputSHA256 }
}

private struct CampaignEpochArtifactRow {
    let installedL2ProofBytes, terminalEvidenceBytes: Data
    let claimEvidenceSHA256, physicalOwnershipSHA256: InvestigationHandoffSHA256
    let helperIdentitySHA256, completionBindingSHA256: InvestigationHandoffSHA256
    init(_ row: CampaignEpochFixtureRow) {
        installedL2ProofBytes = row.installedL2ProofBytes; terminalEvidenceBytes = row.terminalEvidenceBytes
        claimEvidenceSHA256 = row.claimEvidenceSHA256; physicalOwnershipSHA256 = row.physicalOwnershipSHA256
        helperIdentitySHA256 = row.helperIdentitySHA256; completionBindingSHA256 = row.completionBindingSHA256
    }

    init(_ row: InvestigationMachineCampaignVerifiedEpoch) {
        installedL2ProofBytes = row.installedL2ProofBytes; terminalEvidenceBytes = row.terminalEvidenceBytes
        claimEvidenceSHA256 = row.claimEvidenceSHA256; physicalOwnershipSHA256 = row.physicalOwnershipSHA256
        helperIdentitySHA256 = row.helperIdentitySHA256; completionBindingSHA256 = row.completionBindingSHA256
    }
}

private struct CampaignEpochFixtureRow {
    let encoded, installedL2ProofBytes, terminalEvidenceBytes: Data
    let claimEvidenceSHA256, physicalOwnershipSHA256: InvestigationHandoffSHA256
    let helperIdentitySHA256, completionBindingSHA256: InvestigationHandoffSHA256
    let helperIdentity: InvestigationMachineProcessIdentity
    let requestPredecessorSHA256, admissionSHA256: InvestigationHandoffSHA256
}

private struct CampaignProductionClock: InvestigationMachineDarwinOuterInnerCompositionClocking {
    func continuousNanoseconds() throws -> UInt64 { 1_000_000_000 }
}

private struct CampaignEpochCorpus {
    let projectedInput: InvestigationProjectedCohortInput
    let bundle: Data
    let epochs: [CampaignEpochFixtureRow]
    static func make(projectedInput: InvestigationProjectedCohortInput,
        semanticMutation: CampaignEpochSemanticMutation?) throws -> Self {
        var rows: [CampaignEpochFixtureRow] = []
        for index in 0..<InvestigationCohortCapsule.epochCount {
            let selected = try projectedInput.selection(at: index)
            let selection = InvestigationMachineFixedEpochSelection(
                outerAttemptUUID: projectedInput.capsule.outerAttemptUUID, wholeCapsuleSHA256: projectedInput.capsule.wholeCapsuleSHA256,
                wholeInputSHA256: projectedInput.wholeInputSHA256, epoch: selected.epoch, projection: selected.projection)
            rows.append(try makeEpoch(selection: selection, previous: rows.last, index: index))
        }

        if let semanticMutation {
            let target = semanticMutation.targetIndex
            rows[target] = try rewrap(rows[target], mutation: semanticMutation)
            if target + 1 < rows.count {
                rows[target + 1] = try rebindSuccessor(rows[target + 1], previous: rows[target])
            }
        }
        return try make(projectedInput: projectedInput, epochs: rows)
    }

    static func productionBundle(projectedInput: InvestigationProjectedCohortInput) async throws -> Data {
        let attempt = projectedInput.capsule.outerAttemptUUID
        try InvestigationMachineEpochEvidenceCollection.begin(attemptUUID: attempt)
        defer { InvestigationMachineEpochEvidenceCollection.abort() }
        var continuity: InvestigationMachineHelperEpochContinuity?
        var finalSelection: InvestigationMachineFixedEpochSelection?
        for index in 0..<InvestigationCohortCapsule.epochCount {
            let projected = try projectedInput.selection(at: index)
            let selection = InvestigationMachineFixedEpochSelection(
                outerAttemptUUID: attempt, wholeCapsuleSHA256: projectedInput.capsule.wholeCapsuleSHA256,
                wholeInputSHA256: projectedInput.wholeInputSHA256, epoch: projected.epoch, projection: projected.projection)
            let active = try continuity ?? InvestigationMachineHelperEpochContinuity.genesis(for: selection)
            let predecessor = try active.consume(for: selection)
            let invocation = try predecessor.invocation(for: selection)
            let row = try makeEpoch(selection: selection, previous: nil, index: index, invocation: invocation)
            let fields = try CampaignWireTranscript(row.encoded).fields
            let physical = try CampaignWireTranscript(fields[5]).fields
            let material = try CampaignWireTranscript(fields[7]).fields
            let request = try InvestigationMachineDarwinEpochRequest.decodeUntrusted(fields[4])
            let ownership = try InvestigationMachineDarwinEpochOwnershipRecord.decode(material[0])
            let admission = InvestigationMachineDarwinOuterAdmission(
                selection: selection, outerProcessID: 4_101,
                clock: CampaignProductionClock())
            try await admission.accept(request)
            let acknowledgement = try await admission.acceptOwnership(ownership,
                observedDriverChild: ownership.driverChild, observedAppChild: ownership.appChild)
            _ = try await admission.issueDecision(acknowledgement)
            let result = try await admission.admit(resultBytes: physical.count == 2 ? physical[1] : Data(),
                terminalEvidence: InvestigationMachineDarwinEpochTerminalEvidence.decode(fields[6]))
            continuity = try await InvestigationMachineOuterCompletionJoin(prover: admission)
                .seal(selection: selection, result: result, predecessor: predecessor)
            finalSelection = selection
        }
        try #require(continuity).destroyAfterFinal(selection: try #require(finalSelection))
        return try InvestigationMachineEpochEvidenceCollection.finish(summary: .init(
            outerAttemptUUID: attempt, wholeCapsuleSHA256: projectedInput.capsule.wholeCapsuleSHA256,
            wholeInputSHA256: projectedInput.wholeInputSHA256,
            completedEpochCount: 8))
    }

    func replacingFirstOwnership(with bytes: Data) throws -> Self {
        var rows = epochs
        var row = try CampaignWireTranscript(rows[0].encoded); var physical = try CampaignWireTranscript(row.fields[5])
        physical.fields[0] = bytes
        row.fields[5] = try physical.encoded(maximumByteCount: 64 * 1_024)
        rows[0] = CampaignEpochFixtureRow(
            encoded: try row.encoded(maximumByteCount: InvestigationMachineEpochEvidence.maximumByteCount),
            installedL2ProofBytes: rows[0].installedL2ProofBytes, terminalEvidenceBytes: rows[0].terminalEvidenceBytes,
            claimEvidenceSHA256: rows[0].claimEvidenceSHA256,
            physicalOwnershipSHA256: .hashing(bytes), helperIdentitySHA256: rows[0].helperIdentitySHA256,
            completionBindingSHA256: rows[0].completionBindingSHA256,
            helperIdentity: rows[0].helperIdentity, requestPredecessorSHA256: rows[0].requestPredecessorSHA256,
            admissionSHA256: rows[0].admissionSHA256)
        return try Self.make(projectedInput: projectedInput, epochs: rows)
    }

    private static func make(projectedInput: InvestigationProjectedCohortInput,
        epochs: [CampaignEpochFixtureRow]) throws -> Self {
        let fields = [
            campaignData(projectedInput.capsule.outerAttemptUUID), projectedInput.capsule.wholeCapsuleSHA256.rawBytes,
            projectedInput.wholeInputSHA256.rawBytes, handoffData(UInt32(epochs.count)),
        ] + epochs.map(\.encoded)
        let bundle = try HandoffBinaryTranscript.encode(
            domain: "stornaut.task39.machine.driver-evidence-bundle.v1", businessFields: fields,
            maximumByteCount: InvestigationMachineEpochEvidenceBundle.maximumByteCount)
        return .init(projectedInput: projectedInput, bundle: bundle, epochs: epochs)
    }

    private static func makeEpoch(selection: InvestigationMachineFixedEpochSelection,
        previous: CampaignEpochFixtureRow?, index: Int,
        invocation suppliedInvocation: InvestigationMachineSingleEpochInvocation? = nil) throws -> CampaignEpochFixtureRow {
        let invocation: InvestigationMachineSingleEpochInvocation
        if let suppliedInvocation {
            invocation = suppliedInvocation
        } else if let previous {
            let predecessor = try HandoffBinaryTranscript.encode(
                domain: "stornaut.task39.machine.helper-continuity.successor",
                businessFields: [campaignData(selection.outerAttemptUUID), selection.wholeCapsuleSHA256.rawBytes,
                    selection.wholeInputSHA256.rawBytes, handoffData(UInt32(index - 1)),
                    campaignData(CampaignEvidenceFixture.uuid(UInt8(0x30 + index))), try previous.helperIdentity.encoded(),
                    previous.requestPredecessorSHA256.rawBytes, previous.completionBindingSHA256.rawBytes,
                    previous.admissionSHA256.rawBytes, Data([index - 1 == 6 ? 2 : 1]),
                ], maximumByteCount: 4_096)
            invocation = try .init(selection: selection,
                previousHelperIdentity: previous.helperIdentity, predecessorSHA256: .hashing(predecessor),
                predecessorTranscript: predecessor)
        } else {
            let predecessor = try HandoffBinaryTranscript.encode(
                domain: "stornaut.task39.machine.helper-continuity.genesis",
                businessFields: [campaignData(selection.outerAttemptUUID), selection.wholeCapsuleSHA256.rawBytes,
                    selection.wholeInputSHA256.rawBytes, handoffData(UInt32(0)),
                    campaignData(selection.epoch.epochUUID)], maximumByteCount: 512)
            invocation = try .init(selection: selection, previousHelperIdentity: nil, predecessorSHA256: .hashing(predecessor),
                predecessorTranscript: predecessor)
        }
        let deadline: UInt64 = 2_000_000_000
        let request = try InvestigationMachineDarwinEpochRequest(
            invocation: invocation, epochDeadlineNanoseconds: deadline)
        let app = try identity(role: .app, pid: UInt32(2_000 + index), version: UInt32(20 + index), asid: UInt32(200 + index))
        let helper = try identity(role: .helper, pid: UInt32(3_000 + index), version: UInt32(30 + index), asid: UInt32(300 + index))
        let claim = try InvestigationMachineClaimEvidence(
            requestBindingSHA256: digest(UInt8(0x51 + index)),
            originalClaimChallenge: CampaignEvidenceFixture.uuid(UInt8(0x61 + index)),
            claimConnectionEpoch: CampaignEvidenceFixture.uuid(UInt8(0x71 + index)),
            appIdentity: app, helperIdentity: helper, appUserID: 501,
            recordedAt: .init(rawValue: 200), claimedAt: .init(rawValue: 300),
            ownerRetirement: .init(), l1Residue: try .init(
                investigationUUID: selection.epoch.configurationNonce, auditSessionID: helper.auditSessionID, userID: 501,
                observedAt: .init(rawValue: 100),
                remainingAuditSessionMembers: 0, matchingLeases: 0, leaseRootEntries: 0, investigationArtifacts: 0),
            releaseDeadlineNanoseconds: 1_000_000_000)
        let semantic = try installedL2(selection: selection, app: app, helper: helper)
        let proof = try InvestigationMachineSingleEpochInstalledL2Join.prove(
            projection: selection.projection, claimEvidence: claim,
            semanticObservation: semantic, repeatedAppIdentity: app, epochUUID: selection.epoch.epochUUID,
            deadlineNanoseconds: deadline)
        let candidate = try InvestigationMachineSingleEpochOwnershipCandidate(
            commitment: .init(selection: selection), appIdentity: app,
            claimEvidence: claim, semanticObservation: semantic, repeatedAppIdentity: app, installedL2Proof: proof,
            epochDeadlineNanoseconds: deadline)
        let ownership = try InvestigationMachineSingleEpochPhysicalOwnership(projecting: candidate)
        let driver = try InvestigationMachineDarwinDriverChildIdentity(
            processID: UInt32(4_000 + index), processIDVersion: UInt32(40 + index), parentProcessID: 4_101,
            processGroupID: UInt32(4_000 + index),
            auditSessionID: UInt32(400 + index), effectiveUserID: 0,
            auditTokenWords: [0, 0, 0, 0, 0, UInt32(4_000 + index), UInt32(400 + index), UInt32(40 + index)])
        let appChild = try InvestigationMachineDarwinAppChildIdentity(
            identity: app, parentProcessID: driver.processID, processGroupID: driver.processGroupID)
        let record = try InvestigationMachineDarwinEpochOwnershipRecord(
            request: request, driverChild: driver, appChild: appChild, physicalOwnership: ownership)
        let acknowledgement = try InvestigationMachineDarwinEpochAcknowledgement(request: request, ownership: record)
        let decision = try InvestigationMachineDarwinEpochDecision(
            request: request, ownership: record,
            acknowledgement: acknowledgement)
        let resultBytes: Data
        let completionBinding: InvestigationHandoffSHA256
        let observation = digest(UInt8(0x91 + index))
        if selection.epoch.scenario == .lifecycleRecovery {
            resultBytes = Data()
            completionBinding = ownership.bindingSHA256
        } else {
            let physical = try InvestigationMachineSingleEpochPhysicalResult(
                completing: ownership, claimReleaseSHA256: digest(UInt8(0x81 + index)),
                driverObservationSHA256: observation)
            resultBytes = try InvestigationMachineDarwinEpochNormalResult(
                request: request, ownership: record, acknowledgement: acknowledgement, decision: decision,
                physicalResult: physical).encoded()
            completionBinding = physical.bindingSHA256
        }
        let terminal = try InvestigationMachineDarwinEpochTerminalEvidence(
            controlEOFObserved: true, resultEOFObserved: true,
            driverChild: driver, appChild: appChild, helperIdentity: helper,
            innerExitedSuccessfully: selection.epoch.scenario != .lifecycleRecovery,
            appAbsent: true, groupLeaderReapedLast: true,
            postReapGroupEmpty: true, helperAbsent: true, l1ResidueAbsent: true,
            initialDriverObservationSHA256: observation, finalDriverObservationSHA256: observation,
            observedAtNanoseconds: 1_000_000_000)
        let requestBytes = try request.encoded()
        let ownershipBytes = try ownership.evidenceEncoded()
        let physicalBytes = try HandoffBinaryTranscript.encode(
            domain: "stornaut.task39.machine.epoch-physical-evidence.v1",
            businessFields: resultBytes.isEmpty ? [ownershipBytes] : [ownershipBytes, resultBytes],
            maximumByteCount: 64 * 1_024)
        let terminalBytes = try terminal.encoded()
        let material = try InvestigationMachineEpochAdmissionMaterial(
            request: request, ownership: record, acknowledgement: acknowledgement, decision: decision,
            owner: CampaignEvidenceFixture.uuid(UInt8(0xa1 + index)))
        let materialBytes = try material.encoded()
        let admission = try admissionSHA256(request: requestBytes, physical: physicalBytes,
            terminal: terminalBytes, material: materialBytes)
        let encoded = try HandoffBinaryTranscript.encode(
            domain: "stornaut.task39.machine.epoch-evidence.v1",
            businessFields: [
                handoffData(UInt32(index)), handoffData(selection.epoch.scenario.rawValue), campaignData(selection.epoch.epochUUID),
                campaignData(selection.epoch.configurationNonce), requestBytes,
                physicalBytes, terminalBytes, materialBytes, admission.rawBytes,
            ], maximumByteCount: InvestigationMachineEpochEvidence.maximumByteCount)
        return .init(encoded: encoded,
            installedL2ProofBytes: candidate.installedL2ProofBytes, terminalEvidenceBytes: terminalBytes,
            claimEvidenceSHA256: candidate.claimEvidenceSHA256,
            physicalOwnershipSHA256: .hashing(ownershipBytes), helperIdentitySHA256: try helper.helperIdentitySHA256(),
            completionBindingSHA256: completionBinding,
            helperIdentity: helper,
            requestPredecessorSHA256: invocation.predecessorSHA256,
            admissionSHA256: admission)
    }

    private static func rebindSuccessor(_ row: CampaignEpochFixtureRow,
        previous: CampaignEpochFixtureRow) throws -> CampaignEpochFixtureRow {
        var epoch = try CampaignWireTranscript(row.encoded); var request = try CampaignWireTranscript(epoch.fields[4])
        var invocation = try CampaignWireTranscript(request.fields[0])
        var predecessor = try CampaignWireTranscript(invocation.fields[5])
        predecessor.fields[6] = previous.requestPredecessorSHA256.rawBytes
        predecessor.fields[7] = previous.completionBindingSHA256.rawBytes
        predecessor.fields[8] = previous.admissionSHA256.rawBytes
        let predecessorBytes = try predecessor.encoded(maximumByteCount: 4_096)
        invocation.fields[5] = predecessorBytes
        invocation.fields[6] = InvestigationHandoffSHA256.hashing(predecessorBytes).rawBytes
        let invocationBytes = try invocation.encoded(maximumByteCount: 96 * 1_024)
        request.fields[0] = invocationBytes
        request.fields[1] = InvestigationHandoffSHA256.hashing(invocationBytes).rawBytes
        epoch.fields[4] = try request.encoded(maximumByteCount: 128 * 1_024)
        return try rebuild(epoch, mutation: nil)
    }

    private static func rewrap(_ row: CampaignEpochFixtureRow,
        mutation: CampaignEpochSemanticMutation) throws -> CampaignEpochFixtureRow {
        try rebuild(CampaignWireTranscript(row.encoded), mutation: mutation)
    }

    private static func rebuild(_ source: CampaignWireTranscript,
        mutation: CampaignEpochSemanticMutation?) throws -> CampaignEpochFixtureRow {
        var epoch = source
        let requestBytes = epoch.fields[4]
        let request = try InvestigationMachineDarwinEpochRequest.decodeUntrusted(requestBytes)
        var physical = try CampaignWireTranscript(epoch.fields[5]); var ownership = try CampaignWireTranscript(physical.fields[0])
        var material = try CampaignWireTranscript(epoch.fields[7]); var record = try CampaignWireTranscript(material.fields[0])
        var terminal = try CampaignWireTranscript(epoch.fields[6])

        switch mutation {
        case .driverChildNonRoot:
            var driver = try CampaignWireTranscript(record.fields[1]); driver.fields[5] = handoffData(UInt32(501))
            driver.fields[6].replaceSubrange(4..<8, with: handoffData(UInt32(501)))
            record.fields[1] = try driver.encoded(maximumByteCount: 1_024)
        case .driverChildNonRootGroup:
            var driver = try CampaignWireTranscript(record.fields[1]); driver.fields[6].replaceSubrange(8..<12, with: handoffData(UInt32(20)))
            record.fields[1] = try driver.encoded(maximumByteCount: 1_024)
        case .driverChildNonRootRealUser:
            var driver = try CampaignWireTranscript(record.fields[1]); driver.fields[6].replaceSubrange(12..<16, with: handoffData(UInt32(501)))
            record.fields[1] = try driver.encoded(maximumByteCount: 1_024)
        case .driverChildNonRootRealGroup:
            var driver = try CampaignWireTranscript(record.fields[1]); driver.fields[6].replaceSubrange(16..<20, with: handoffData(UInt32(20)))
            record.fields[1] = try driver.encoded(maximumByteCount: 1_024)
        case .driverChildAuditTokenMismatch:
            var driver = try CampaignWireTranscript(record.fields[1]); driver.fields[6].replaceSubrange(20..<24, with: handoffData(UInt32(8_104)))
            record.fields[1] = try driver.encoded(maximumByteCount: 1_024)
        case .claimZeroRequestBinding:
            var claim = try CampaignWireTranscript(ownership.fields[9]); claim.fields[0] = Data(repeating: 0, count: 32)
            ownership.fields[9] = try claim.encoded(maximumByteCount: 4_096)
            ownership.fields[10] = InvestigationHandoffSHA256.hashing(ownership.fields[9]).rawBytes
            var proof = try CampaignWireTranscript(ownership.fields[12])
            proof.fields[1] = ownership.fields[10]; ownership.fields[12] = try proof.encoded(maximumByteCount: 16_384)
            ownership.fields[11] = InvestigationHandoffSHA256.hashing(ownership.fields[12]).rawBytes
        case .driverChildParentDriftAcrossEpochs:
            var driver = try CampaignWireTranscript(record.fields[1]); driver.fields[2] = handoffData(UInt32(8_103))
            record.fields[1] = try driver.encoded(maximumByteCount: 1_024)
        case .appChildHelperRole:
            var appChild = try CampaignWireTranscript(record.fields[2]); appChild.fields[0] = try identity(role: .helper, pid: 8_001, version: 81, asid: 801).encoded()
            record.fields[2] = try appChild.encoded(maximumByteCount: 2_048)
        case .appChildWrongParentAndProcessGroup:
            var appChild = try CampaignWireTranscript(record.fields[2]); appChild.fields[1] = handoffData(UInt32(8_101))
            appChild.fields[2] = handoffData(UInt32(8_102))
            record.fields[2] = try appChild.encoded(maximumByteCount: 2_048)
        case .parentCrashZeroObservationDigests:
            terminal.fields[11] = Data(repeating: 0, count: 32); terminal.fields[12] = Data(repeating: 0, count: 32)
        case .parentCrashZeroObservedAt:
            terminal.fields[13] = handoffData(UInt64(0))
        case .installedL2ZeroContinuousClocks:
            var proof = try CampaignWireTranscript(ownership.fields[12])
            proof.fields[18] = handoffData(UInt64(0)); proof.fields[20] = handoffData(UInt64(0))
            ownership.fields[12] = try proof.encoded(maximumByteCount: 16_384)
            ownership.fields[11] = InvestigationHandoffSHA256.hashing(ownership.fields[12]).rawBytes
        case .installedL2ObservedAfterTerminal:
            var proof = try CampaignWireTranscript(ownership.fields[12])
            proof.fields[20] = handoffData(UInt64(1_500_000_000)); ownership.fields[12] = try proof.encoded(maximumByteCount: 16_384)
            ownership.fields[11] = InvestigationHandoffSHA256.hashing(ownership.fields[12]).rawBytes
        case nil:
            break
        }

        let selection = request.invocation.selection
        let bindingFields = Array(ownership.fields[0...5]) + [
            campaignData(selection.epoch.configurationNonce), selection.epoch.configurationSHA256.rawBytes,
            selection.epoch.signedRuntimeBindingSHA256.rawBytes, ownership.fields[6],
        ] + Array(ownership.fields[7...11]) + Array(ownership.fields[13...14])
        ownership.fields[15] = InvestigationHandoffSHA256.hashing(
            try HandoffBinaryTranscript.encode(
                domain: "stornaut.task39.machine.single-epoch.ownership",
                businessFields: bindingFields, maximumByteCount: 8_192)
        ).rawBytes
        let ownershipBytes = try ownership.encoded(maximumByteCount: 32 * 1_024)

        let requestSHA256 = InvestigationHandoffSHA256.hashing(requestBytes)
        record.fields[0] = requestSHA256.rawBytes; record.fields[3] = ownershipBytes
        let ownershipSHA256 = InvestigationHandoffSHA256.hashing(ownershipBytes)
        record.fields[4] = ownershipSHA256.rawBytes
        let recordBytes = try record.encoded(maximumByteCount: 48 * 1_024)
        let acknowledgementBytes = try HandoffBinaryTranscript.encode(
            domain: "stornaut.task39.machine.outer-inner.acknowledgement",
            businessFields: [requestSHA256.rawBytes, InvestigationHandoffSHA256.hashing(recordBytes).rawBytes,
                ownershipSHA256.rawBytes], maximumByteCount: 512)
        let decisionBytes = try HandoffBinaryTranscript.encode(
            domain: "stornaut.task39.machine.outer-inner.decision",
            businessFields: [requestSHA256.rawBytes, InvestigationHandoffSHA256.hashing(recordBytes).rawBytes,
                InvestigationHandoffSHA256.hashing(acknowledgementBytes).rawBytes,
                Data([request.mode == .normal ? 1 : 2]),
            ], maximumByteCount: 512)
        material.fields[0] = recordBytes; material.fields[1] = acknowledgementBytes; material.fields[2] = decisionBytes
        let materialBytes = try material.encoded(maximumByteCount: 50 * 1_024)

        let resultBytes: Data
        let completionBinding: InvestigationHandoffSHA256
        if request.mode == .normal {
            var result = try CampaignWireTranscript(physical.fields[1])
            var completion = try CampaignWireTranscript(result.fields[4])
            completion.fields[0] = ownershipBytes
            completion.fields[3] = InvestigationHandoffSHA256.hashing(
                try HandoffBinaryTranscript.encode(
                    domain: "stornaut.task39.machine.single-epoch.local-completion",
                    businessFields: [ownership.fields[15], completion.fields[1], completion.fields[2], Data([1])],
                    maximumByteCount: 2_048)
            ).rawBytes
            let completionBytes = try completion.encoded(maximumByteCount: 48 * 1_024)
            result.fields[0] = requestSHA256.rawBytes; result.fields[1] = InvestigationHandoffSHA256.hashing(recordBytes).rawBytes
            result.fields[2] = InvestigationHandoffSHA256.hashing(acknowledgementBytes).rawBytes; result.fields[3] = InvestigationHandoffSHA256.hashing(decisionBytes).rawBytes
            result.fields[4] = completionBytes
            result.fields[5] = InvestigationHandoffSHA256.hashing(completionBytes).rawBytes
            resultBytes = try result.encoded(maximumByteCount: 48 * 1_024)
            physical.fields[1] = resultBytes
            completionBinding = try InvestigationHandoffSHA256(rawBytes: completion.fields[3])
        } else {
            resultBytes = Data()
            completionBinding = try InvestigationHandoffSHA256(rawBytes: ownership.fields[15])
        }
        physical.fields[0] = ownershipBytes
        let physicalBytes = try physical.encoded(maximumByteCount: 64 * 1_024)

        terminal.fields[2] = record.fields[1]; terminal.fields[3] = record.fields[2]
        let terminalBytes = try terminal.encoded(maximumByteCount: 2_048)
        let admission = try admissionSHA256(request: requestBytes, physical: physicalBytes,
            terminal: terminalBytes, material: materialBytes)
        epoch.fields[5] = physicalBytes; epoch.fields[6] = terminalBytes
        epoch.fields[7] = materialBytes; epoch.fields[8] = admission.rawBytes
        let helper = try InvestigationMachineProcessIdentity.decode(ownership.fields[8])
        return .init(
            encoded: try epoch.encoded(maximumByteCount: InvestigationMachineEpochEvidence.maximumByteCount),
            installedL2ProofBytes: ownership.fields[12], terminalEvidenceBytes: terminalBytes,
            claimEvidenceSHA256: .hashing(ownership.fields[9]),
            physicalOwnershipSHA256: ownershipSHA256, helperIdentitySHA256: try helper.helperIdentitySHA256(),
            completionBindingSHA256: completionBinding,
            helperIdentity: helper,
            requestPredecessorSHA256: request.invocation.predecessorSHA256,
            admissionSHA256: admission)
    }

    private static func admissionSHA256(request: Data, physical: Data,
        terminal: Data, material: Data) throws -> InvestigationHandoffSHA256 {
        let physicalFields = try CampaignWireTranscript(physical).fields, materialFields = try CampaignWireTranscript(material).fields
        return .hashing(try HandoffBinaryTranscript.encode(
            domain: "stornaut.task39.machine.outer-inner.admission",
            businessFields: [
                request, materialFields[0], materialFields[1], materialFields[2],
                InvestigationHandoffSHA256.hashing(physicalFields.count == 2 ? physicalFields[1] : Data()).rawBytes,
                InvestigationHandoffSHA256.hashing(terminal).rawBytes, materialFields[3],
            ], maximumByteCount: 192 * 1_024))
    }

    private static func installedL2(selection: InvestigationMachineFixedEpochSelection,
        app: InvestigationMachineProcessIdentity, helper: InvestigationMachineProcessIdentity) throws -> InvestigationInstalledL2SemanticObservation {
        func signing(_ identifier: String, _ marker: UInt8, adHoc: Bool) throws -> InvestigationInstalledL2SigningIdentity {
            try .init(signingIdentifier: identifier,
                designatedRequirementSHA256: digest(marker), codeDirectoryHash: Data(repeating: marker &+ 1, count: 20),
                isAdHoc: adHoc)
        }
        let projection = selection.projection
        let appSigning = try signing(projection.appBundleIdentifier, 0xc1, adHoc: false)
        let helperSigning = try signing(projection.helperServiceIdentifier + ".helper", 0xc3, adHoc: false)
        let driverSigning = try InvestigationInstalledL2SigningIdentity(
            signingIdentifier: projection.machineDriverSigningIdentifier, designatedRequirementSHA256: projection.machineDriverDesignatedRequirementSHA256,
            codeDirectoryHash: projection.machineDriverCodeDirectoryHash,
            isAdHoc: true)
        return try InvestigationInstalledL2SemanticContract.evaluate(
            projection: projection, artifacts: Dictionary(uniqueKeysWithValues: InvestigationInstalledL2ArtifactRole.allCases.map {
                ($0, InvestigationInstalledL2ArtifactObservation.presentValid) }),
            app: try .init(identity: app,
                executableSHA256: projection.appExecutableSHA256, staticSigning: appSigning, liveSigning: appSigning),
            helper: try .init(identity: helper,
                executableSHA256: projection.helperExecutableSHA256, staticSigning: helperSigning, liveSigning: helperSigning),
            machineDriver: try .init(executableSHA256: projection.machineDriverExecutableSHA256,
                staticSigning: driverSigning, liveSigning: driverSigning),
            service: .loaded(identity: helper),
            started: try .init(wallUTC: .init(rawValue: 400), continuousNanoseconds: 400),
            observed: try .init(wallUTC: .init(rawValue: 500), continuousNanoseconds: 500))
    }

    private static func identity(role: InvestigationMachineProcessRole, pid: UInt32,
        version: UInt32, asid: UInt32) throws -> InvestigationMachineProcessIdentity {
        let user: UInt32 = role == .app ? 501 : 0
        return try .init(role: role, processID: pid, processIDVersion: version,
            auditSessionID: asid, effectiveUserID: user,
            auditTokenWords: [user, user, 20, user, 20, pid, asid, version])
    }

    private static func digest(_ marker: UInt8) -> InvestigationHandoffSHA256 {
        InvestigationMachineCampaignEvidenceTests.digest(marker) }
}

private struct CampaignWireTranscript {
    let domain: String
    var fields: [Data]
    init(_ encoded: Data) throws {
        var cursor = HandoffBinaryCursor(data: encoded)
        guard try cursor.readUInt32() == HandoffBinaryTranscript.magic else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        let domainBytes = try cursor.readTaggedField(expectedTag: 0,
            admittedByteCounts: 1...HandoffBinaryTranscript.maximumDomainByteCount)
        guard let domain = String(data: domainBytes, encoding: .utf8) else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        let version = try cursor.readTaggedField(expectedTag: 1, admittedByteCounts: 4...4)
        var versionCursor = HandoffBinaryCursor(data: version)
        guard try versionCursor.readUInt32() == HandoffBinaryTranscript.version,
            versionCursor.isAtEnd else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        var values: [Data] = []
        var tag: UInt16 = 2
        while !cursor.isAtEnd {
            values.append(try cursor.readTaggedField(expectedTag: tag, admittedByteCounts: 1...encoded.count))
            tag += 1
        }
        self.domain = domain
        fields = values
    }

    func encoded(maximumByteCount: Int) throws -> Data {
        try HandoffBinaryTranscript.encode(domain: domain, businessFields: fields, maximumByteCount: maximumByteCount)
    }
}

private func campaignData(_ value: UUID) -> Data {
    var bytes = value.uuid
    return withUnsafeBytes(of: &bytes) { Data($0) }
}

private func campaignUInt32(_ value: Data) throws -> UInt32 {
    guard value.count == 4 else {
        throw InvestigationHandoffContractError.invalidEncoding
    }
    return value.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
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
    case missingFile
    case extraFile
    case extraDirectory
    case replacementSymlink
    case replacementHardLink
    case wrongDirectoryMode
    case missingDirectory
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
    let outerIdentity = InvestigationMachineCampaignOuterIdentity(
        processID: 3_901, processIDVersion: 1, parentProcessID: 3_900,
        processGroupID: 3_901, sessionID: 3_901,
        foregroundProcessGroupID: 3_901, effectiveUserID: 501,
        startTimeSeconds: 1, startTimeMicroseconds: 2)

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
            parent: canonicalParent, parentDescriptor: descriptor
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
            kind: .prepared,
            payload: try InvestigationMachineCampaignEvidenceTests.eventPayload(
                kind: .prepared, attempt: attemptUUID),
            observedAt: try .init(rawValue: 1)
        )
        _ = try writer.appendAttemptEvent(
            kind: .cancelledBeforeArm,
            payload: try InvestigationMachineCampaignEvidenceTests.eventPayload(
                kind: .cancelledBeforeArm, attempt: attemptUUID),
            observedAt: try .init(rawValue: 2)
        )
        try populateDryRunArtifacts(writer)
    }

    func populateDryRunArtifacts(
        _ writer: InvestigationMachineRawEvidenceWriter,
        sourceBuild: Data? = nil
    ) throws {
        var values = try commonArtifacts(
            expectedConsumed: false, epochCount: 0, cancellationAttestation: true)
        if let sourceBuild { values[0].4 = sourceBuild }
        try write(values, to: writer)
    }

    func populatePrivilegedArtifacts(
        _ writer: InvestigationMachineRawEvidenceWriter,
        epochCount: Int = 8, semanticForgery: Bool = false,
        promptVerifierForgery: Bool = false,
        epochSemanticMutation: CampaignEpochSemanticMutation? = nil,
        joinMutation: CampaignVerifierJoinMutation? = nil,
        transport suppliedTransport: CampaignPrivilegedTransport? = nil
    ) throws {
        let transport = try suppliedTransport ?? privilegedTransport(
            joinMutation: joinMutation,
            semanticMutation: epochSemanticMutation,
            rawGateMutation: rawGateMutation(for: joinMutation))
        var values = try commonArtifacts(
            expectedConsumed: true, epochCount: epochCount,
            cancellationAttestation: promptVerifierForgery,
            preArmFrameSHA256: joinMutation == .sourcePreArm
                ? InvestigationMachineCampaignEvidenceTests.digest(0xee)
                : transport.preArmFrameSHA256)
        if epochCount == 8 {
            values.insert(contentsOf: [
                (.driverEpochs, "coordinator-receipt.bin", .protocolReceipt,
                    .framedCanonicalBinary, transport.finalFrame),
                (.driverEpochs, "diagnostic-output.bin", .diagnosticOutput,
                    .opaqueBytes, transport.diagnostic),
            ], at: 5)
        }
        for index in (1...8).prefix(epochCount) {
            let epoch = transport.epochs[index - 1]
            let l2 = try typed(
                .epochL2Projection, ordinal: index,
                wholeProjectedInputSHA256: joinMutation == .epochWholeInput
                    ? InvestigationMachineCampaignEvidenceTests.digest(0xef)
                    : transport.wholeProjectedInputSHA256,
                installedL2Proof: epoch.installedL2ProofBytes,
                claimEvidenceSHA256: joinMutation == .claimEvidence && index == 1
                    ? InvestigationMachineCampaignEvidenceTests.digest(0xef)
                    : epoch.claimEvidenceSHA256,
                physicalOwnershipSHA256: epoch.physicalOwnershipSHA256)
            values.append((
                .driverEpochs, String(format: "epoch-%02d-l2.json", index),
                .epochL2Projection, .strictJSON, l2
            ))
            values.append((
                .driverEpochs, String(format: "epoch-%02d-residue.json", index),
                .epochResidueProjection, .strictJSON,
                try typed(
                    .epochResidueProjection, ordinal: index,
                    l2ArtifactSHA256: semanticForgery && index == epochCount
                        ? InvestigationMachineCampaignEvidenceTests.digest(0xfe)
                        : .hashing(l2),
                    terminalEvidence: epoch.terminalEvidenceBytes,
                    helperIdentitySHA256:
                        joinMutation == .helperIdentity && index == 1
                            ? InvestigationMachineCampaignEvidenceTests.digest(0xef)
                            : epoch.helperIdentitySHA256,
                    completionBindingSHA256:
                        joinMutation == .completionBinding && index == 1
                            ? InvestigationMachineCampaignEvidenceTests.digest(0xef)
                            : epoch.completionBindingSHA256
                )
            ))
        }
        try write(values, to: writer)
    }

    private typealias Artifact = (InvestigationMachineEvidencePhase, String, InvestigationMachineEvidenceRole, InvestigationMachineEvidenceEncoding, Data)

    private func commonArtifacts(expectedConsumed: Bool, epochCount: Int, cancellationAttestation: Bool, preArmFrameSHA256: InvestigationHandoffSHA256? = nil) throws -> [Artifact] {
        try [
            (.preflight, "source-build.json", .sourceBuildIdentity, .strictJSON, typed(.sourceBuildIdentity, preArmFrameSHA256: preArmFrameSHA256)),
            (.install, "installed.json", .builtStagingInstalledIdentity, .strictJSON, typed(.builtStagingInstalledIdentity)),
            (.authorization, "policy-probe.json", .policyProbe, .strictJSON, typed(.policyProbe)),
            (.authorization, "human-attestation.json", .humanPromptAttestation, .strictJSON, typed(.humanPromptAttestation, cancellationAttestation: cancellationAttestation)),
            (.authorization, "capability-counts.json", .noAuthModelNetworkCounters, .strictJSON, typed(.noAuthModelNetworkCounters)),
            (.uninstall, "uninstall.json", .uninstallEvidence, .strictJSON, typed(.uninstallEvidence)),
            (.verifier, "global-post-teardown.json", .globalPostTeardown, .strictJSON, typed(.globalPostTeardown)),
            (.verifier, "verification-input.json", .verifierInput, .strictJSON, typed(.verifierInput, ordinal: epochCount, expectedConsumed: expectedConsumed)),
        ]
    }

    func completePrivilegedCorpus(
        _ seal: InvestigationMachineRawEvidenceSeal,
        joinMutation: CampaignVerifierJoinMutation? = nil,
        epochSemanticMutation: CampaignEpochSemanticMutation? = nil,
        transport suppliedTransport: CampaignPrivilegedTransport? = nil
    ) throws -> InvestigationMachineRawEvidenceSeal {
        let transport = try suppliedTransport ?? privilegedTransport(
            joinMutation: joinMutation,
            semanticMutation: epochSemanticMutation,
            rawGateMutation: rawGateMutation(for: joinMutation))
        let receiptURL = evidenceRoot.appending(path: "04-driver-epochs/coordinator-receipt.bin")
        try transport.receiptStream.write(to: receiptURL); try #require(chmod(receiptURL.path, 0o600) == 0)
        let manifestURL = evidenceRoot.appending(path: "manifest.bin")
        let old = try InvestigationMachineEvidenceManifestV1.decode(Data(contentsOf: manifestURL))
        let artifacts = try old.artifacts.map { artifact in
            guard artifact.role == .protocolReceipt else { return artifact }
            return try InvestigationMachineEvidenceArtifact(path: artifact.path, role: artifact.role, encoding: artifact.encoding, byteCount: UInt64(transport.receiptStream.count), sha256: .hashing(transport.receiptStream))
        }
        let manifest = try InvestigationMachineEvidenceManifestV1(campaignUUID: campaignUUID, attemptUUID: attemptUUID, sourceBinding: sourceBinding, artifacts: artifacts, attemptSummary: seal.attemptSummary)
        try manifest.encoded().write(to: manifestURL); try #require(chmod(manifestURL.path, 0o600) == 0)
        return InvestigationMachineRawEvidenceSeal(campaignUUID: campaignUUID, attemptUUID: attemptUUID, rootIdentity: seal.rootIdentity, manifestSHA256: manifest.manifestSHA256, contentRootSHA256: manifest.contentRootSHA256, artifactCount: manifest.artifacts.count, totalByteCount: manifest.totalByteCount, attemptSummary: seal.attemptSummary)
    }

    fileprivate func privilegedTransport(
        joinMutation: CampaignVerifierJoinMutation? = nil,
        semanticMutation: CampaignEpochSemanticMutation? = nil,
        rawGateMutation: CampaignRawGateMutation? = nil,
        diagnosticMutation: CampaignDiagnosticMutation? = nil,
        productionBundle: Data? = nil
    ) throws -> CampaignPrivilegedTransport {
        let rawGateMutation = rawGateMutation ?? self.rawGateMutation(for: joinMutation)
        let projected = try projectedInput(), projectedBytes = try projected.encoded()
        let digest = InvestigationMachineCampaignEvidenceTests.digest
        let fixed = [handoffData(attemptUUID), projected.capsule.wholeCapsuleSHA256.rawBytes, projected.wholeInputSHA256.rawBytes]
        let preArm = try selfBoundTranscript("stornaut.task39.iic.coordinator-prearm.v1", [Data(sourceBinding.repositoryHEAD.utf8), Data(sourceBinding.repositoryTree.utf8), sourceBinding.canonicalSourceManifestSHA256.rawBytes, sourceBinding.buildProvenanceSHA256.rawBytes, sourceBinding.signedRuntimeBindingSHA256.rawBytes] + fixed + [projectedBytes], maximum: InvestigationMachineCampaignPreArmFrame.maximumByteCount)
        let preArmValue = try InvestigationMachineCampaignPreArmFrame.decode(preArm)
        var corpus = try CampaignEpochCorpus.make(
            projectedInput: projected, semanticMutation: semanticMutation)
        if joinMutation == .ownershipEncoding {
            corpus = try corpus.replacingFirstOwnership(
                with: Data("not-canonical-ownership".utf8))
        }
        let bundle = productionBundle ?? corpus.bundle
        let epochs = try productionBundle.map { bundle in
            try InvestigationMachineCampaignEpochEvidenceValidator.validate(
                bundle: bundle, projectedInput: projected).epochs.map(
                    CampaignEpochArtifactRow.init)
        } ?? corpus.epochs.map(CampaignEpochArtifactRow.init)
        let completion = try selfBoundTranscript("stornaut.task39.machine.driver-completion-v2", fixed + [handoffData(UInt32(8)), InvestigationHandoffSHA256.hashing(bundle).rawBytes], maximum: 512)
        let node = InvestigationMachineGateNodeObservation(device: 101, inode: 102, generation: 103, size: Int64(projectedBytes.count))
        let tty = { (foreground: pid_t) in InvestigationMachineGateTerminalObservation(device: 9, inode: 10, foregroundProcessGroupID: foreground) }
        let gateStarted: UInt64 = 20
        let gateCompleted: UInt64 = 30
        let outerPID: pid_t = rawGateMutation == .coordinatorIdentity ? 3_902 : 3_901
        let gatePrepared = try InvestigationMachineGatePreparedFrame(
            gateProcessID: 4_001, coordinatorProcessID: outerPID,
            sessionID: outerPID, childProcessID: 4_101,
            recoveryProcessGroupID: 4_001,
            savedForegroundProcessGroupID: outerPID,
            childParentProcessID: 4_001, childSessionID: outerPID,
            childStartSeconds: 1, childStartMicroseconds: 2,
            initialStopStatus: 0x7f, outerAttemptUUID: attemptUUID,
            wholeInputSHA256: projected.wholeInputSHA256, capsule: node,
            terminal: tty(outerPID), absoluteDeadlineNanoseconds:
                gateStarted + 1_200_000_000_000).encoded()
        let raw = try InvestigationMachineGateTransportReceipt(
            launcherExecutableSHA256: digest(0x74), outerAttemptUUID: attemptUUID, wholeInputSHA256: projected.wholeInputSHA256, preparedFrameSHA256: rawGateMutation == .preparedFrameDigest ? digest(0x75) : .hashing(gatePrepared),
            capsule: node, gateProcessID: 4_001, coordinatorProcessID: outerPID, sessionID: outerPID, recoveryProcessGroupID: 4_001, savedForegroundProcessGroupID: outerPID,
            childIdentity: .init(processID: 4_101, parentProcessID: 4_001, processGroupID: 4_001, sessionID: outerPID, startSeconds: 1, startMicroseconds: 2),
            input: .init(node: node, initialOffset: 0, finalOffset: Int64(projectedBytes.count), reachedEOF: true, sha256: projected.wholeInputSHA256),
            initialTerminal: tty(outerPID), childTerminal: tty(4_001), finalTerminal: tty(outerPID), output: .init(byteCount: completion.count, sha256: .hashing(completion), overflowObserved: false),
            waitClassification: .exited(status: 0), forwardedSignal: nil, monotonicStartedNanoseconds: gateStarted, monotonicCompletedNanoseconds: gateCompleted, terminationProgression: .natural, childProcessGroupEmpty: true, exactChildReaped: true, savedForegroundProcessGroupRestored: true, borrowedDescriptorOutcome: .closed).encoded()
        let final = try CampaignCoordinatorReceiptFixture.frame(attemptUUID: attemptUUID, capsuleSize: Int64(projectedBytes.count), buildProvenanceSHA256: sourceBinding.buildProvenanceSHA256.lowercaseHex, signedBindingSHA256: sourceBinding.signedRuntimeBindingSHA256, wholeInputSHA256: projected.wholeInputSHA256, gateTransportReceiptSHA256: .hashing(raw), gateSessionID: outerPID, monotonicStartedNanoseconds: rawGateMutation == .enclosingStart ? gateStarted : 10, monotonicCompletedNanoseconds: rawGateMutation == .enclosingCompletion ? gateCompleted : 40)
        let canonicalDiagnostic = Data(("STORNAUT_TASK39_IIC_EPOCH_BUNDLE_V1 "
            + bundle.base64EncodedString() + "\n").utf8)
        let diagnostic = switch diagnosticMutation {
        case .leadingBytes: Data("noise\n".utf8) + canonicalDiagnostic
        case .trailingBytes: canonicalDiagnostic + Data("noise\n".utf8)
        case .missingNewline: Data(canonicalDiagnostic.dropLast())
        case .carriageReturnLineFeed:
            Data(canonicalDiagnostic.dropLast()) + Data("\r\n".utf8)
        case nil: canonicalDiagnostic
        }
        return .init(
            finalFrame: final, receiptStream: framed(preArm) + framed(raw) + final,
            diagnostic: diagnostic,
            preArm: preArmValue,
            finalReceipt: try InvestigationMachineCoordinatorRawReceiptV1
                .decodeFrame(final, reachedEOF: true),
            rawGateReceipt: raw, projectedInput: projected, bundle: bundle,
            completion: completion, epochs: epochs)
    }

    private func rawGateMutation(
        for mutation: CampaignVerifierJoinMutation?
    ) -> CampaignRawGateMutation? {
        switch mutation {
        case .rawPreparedFrame: .preparedFrameDigest
        case .rawGateStartEnvelope: .enclosingStart
        case .rawGateCompletionEnvelope: .enclosingCompletion
        case .rawCoordinatorIdentity: .coordinatorIdentity
        default: nil
        }
    }

    fileprivate func projectedInput() throws -> InvestigationProjectedCohortInput {
        let projections = try (1...8).map(projection)
        let epochs = try projections.enumerated().map { offset, projection in
            let index = offset + 1, bytes = Data([UInt8(index)])
            return try InvestigationCohortEpoch(ordinal: UInt32(offset), epochUUID: CampaignEvidenceFixture.uuid(UInt8(0x30 + index)), scenario: InvestigationHandoffScenario.allCases[offset], configurationNonce: CampaignEvidenceFixture.uuid(UInt8(0x40 + index)), configuration: bytes, configurationSHA256: projection.configurationSHA256, signedRuntimeBindingSHA256: sourceBinding.signedRuntimeBindingSHA256)
        }
        return try InvestigationProjectedCohortInput(capsule: .init(outerAttemptUUID: attemptUUID, epochs: epochs), projections: projections)
    }

    private func transcript(_ domain: String, _ fields: [Data], maximum: Int) throws -> Data {
        try HandoffBinaryTranscript.encode(domain: domain, businessFields: fields, maximumByteCount: maximum)
    }
    private func selfBoundTranscript(_ domain: String, _ fields: [Data], maximum: Int) throws -> Data {
        let zero = try transcript(domain, fields + [Data(repeating: 0, count: 32)], maximum: maximum)
        return try transcript(domain, fields + [InvestigationHandoffSHA256.hashing(zero).rawBytes], maximum: maximum)
    }
    private func framed(_ bytes: Data) -> Data { handoffData(UInt32(bytes.count)) + bytes }

    private func typed(_ role: InvestigationMachineEvidenceRole, ordinal: Int = 0, l2ArtifactSHA256: InvestigationHandoffSHA256? = nil, cancellationAttestation: Bool = false, expectedConsumed: Bool = true, preArmFrameSHA256: InvestigationHandoffSHA256? = nil, wholeProjectedInputSHA256: InvestigationHandoffSHA256? = nil, installedL2Proof: Data? = nil, claimEvidenceSHA256: InvestigationHandoffSHA256? = nil, physicalOwnershipSHA256: InvestigationHandoffSHA256? = nil, terminalEvidence: Data? = nil, helperIdentitySHA256: InvestigationHandoffSHA256? = nil, completionBindingSHA256: InvestigationHandoffSHA256? = nil) throws -> Data {
        let digest = InvestigationMachineCampaignEvidenceTests.digest
        let hex: (UInt8) -> String = { digest($0).lowercaseHex }
        var value: [String: Any] = ["schemaVersion": 1, "role": roleName(role), "campaignUUID": campaignUUID.uuidString.lowercased(), "attemptUUID": attemptUUID.uuidString.lowercased()]
        let fields: [String: Any]
        switch role {
        case .sourceBuildIdentity:
            fields = ["repositoryHEAD": sourceBinding.repositoryHEAD, "repositoryTree": sourceBinding.repositoryTree, "canonicalSourceManifestSHA256": sourceBinding.canonicalSourceManifestSHA256.lowercaseHex, "buildProvenanceSHA256": sourceBinding.buildProvenanceSHA256.lowercaseHex, "signedRuntimeBindingSHA256": sourceBinding.signedRuntimeBindingSHA256.lowercaseHex, "preArmFrameSHA256": preArmFrameSHA256?.lowercaseHex ?? hex(0x64)]
        case .builtStagingInstalledIdentity:
            let identity = hex(0x65)
            fields = ["buildProvenanceSHA256": sourceBinding.buildProvenanceSHA256.lowercaseHex, "signedRuntimeBindingSHA256": sourceBinding.signedRuntimeBindingSHA256.lowercaseHex, "transactionReceiptSHA256": hex(0x66), "builtIdentitySHA256": identity, "stagingIdentitySHA256": identity, "installedIdentitySHA256": identity, "plistSHA256": hex(0x67), "serviceLoaded": true, "appExecutableSHA256": hex(0x71), "helperExecutableSHA256": hex(0x72), "machineDriverExecutableSHA256": hex(0x73), "gateExecutableSHA256": hex(0x74), "coordinatorExecutableSHA256": hex(0xe5)]
        case .policyProbe:
            fields = ["command": "/usr/bin/sudo -knv", "exitStatus": 1, "stdoutByteCount": 0, "stdoutSHA256": hex(0x68), "stderrByteCount": 1, "stderrSHA256": hex(0x69)]
        case .humanPromptAttestation:
            fields = ["prompt": InvestigationMachineEvidenceJSON.prompt, "machinePromptObserved": !cancellationAttestation, "attestationKind": cancellationAttestation ? "operatorCancellationBeforeCredential" : "trustedOperatorInteractiveAction", "humanActionObserved": !cancellationAttestation, "credentialRetainedByteCount": 0]
        case .noAuthModelNetworkCounters:
            fields = ["authInvocationCount": 0, "modelInvocationCount": 0, "networkInvocationCount": 0, "credentialTranscriptByteCount": 0]
        case .epochL2Projection:
            let projection = try projection(ordinal: ordinal), bytes = try projection.encoded(), proof = installedL2Proof ?? Data([UInt8(ordinal)])
            fields = ["ordinal": ordinal, "scenario": InvestigationMachineEvidenceJSON.scenarios[ordinal - 1], "epochUUID": projection.epochUUID.uuidString.lowercased(), "configurationNonce": projection.configurationNonce.uuidString.lowercased(), "configurationSHA256": projection.configurationSHA256.lowercaseHex, "signedRuntimeBindingSHA256": projection.signedRuntimeBindingSHA256.lowercaseHex, "wholeProjectedInputSHA256": wholeProjectedInputSHA256?.lowercaseHex ?? hex(0x73), "projectionBase64": bytes.base64EncodedString(), "projectionSHA256": projection.projectionSHA256.lowercaseHex, "installedL2ProofBase64": proof.base64EncodedString(), "installedL2ProofSHA256": InvestigationHandoffSHA256.hashing(proof).lowercaseHex, "claimEvidenceSHA256": claimEvidenceSHA256?.lowercaseHex ?? hex(UInt8(0x80 + ordinal)), "physicalOwnershipSHA256": physicalOwnershipSHA256?.lowercaseHex ?? hex(UInt8(0x90 + ordinal))]
        case .epochResidueProjection:
            let terminal = terminalEvidence ?? Data([UInt8(0xc0 + ordinal)])
            fields = ["ordinal": ordinal, "scenario": InvestigationMachineEvidenceJSON.scenarios[ordinal - 1], "epochUUID": CampaignEvidenceFixture.uuid(UInt8(0x30 + ordinal)).uuidString.lowercased(), "l2ArtifactSHA256": try #require(l2ArtifactSHA256).lowercaseHex, "helperIdentitySHA256": helperIdentitySHA256?.lowercaseHex ?? hex(UInt8(0xa0 + ordinal)), "completionBindingSHA256": completionBindingSHA256?.lowercaseHex ?? hex(UInt8(0xb0 + ordinal)), "terminalEvidenceBase64": terminal.base64EncodedString(), "terminalEvidenceSHA256": InvestigationHandoffSHA256.hashing(terminal).lowercaseHex, "childCount": 0, "descendantCount": 0, "openChannelCount": 0, "ownedProcessGroupMemberCount": 0, "helperExitObserved": true, "artifactsRetired": true]
        case .uninstallEvidence:
            fields = ["transactionReceiptSHA256": hex(0xd2), "installedIdentitySHA256": hex(0x65), "plistSHA256": hex(0x67), "appExecutableSHA256": hex(0x71), "helperExecutableSHA256": hex(0x72), "machineDriverExecutableSHA256": hex(0x73), "gateExecutableSHA256": hex(0x74), "coordinatorExecutableSHA256": hex(0xe5), "bootoutCompleted": true, "installedRootRemoved": true, "installedAppRemoved": true, "plistRemoved": true, "runtimeRootRemoved": true, "leaseRootRemoved": true]
        case .globalPostTeardown:
            fields = ["observationReceiptSHA256": hex(0xd3), "appProcessCount": 0, "helperProcessCount": 0, "driverProcessCount": 0, "gateProcessCount": 0, "coordinatorProcessCount": 0, "childCount": 0, "descendantCount": 0, "openChannelCount": 0, "ownedProcessGroupMemberCount": 0, "serviceAbsent": true, "gateOwnerLockRevalidated": true, "gateAttemptEntryCount": 0, "gateCapsuleEntryCount": 0]
        case .verifierInput:
            let verifier = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appending(path: "scripts/verify-investigation-runtime-machine-report")
            fields = ["expectedConsumed": expectedConsumed, "expectedEpochCount": ordinal, "evidenceSetSHA256": hex(0xd1), "verifierExecutableSHA256": InvestigationHandoffSHA256.hashing(try Data(contentsOf: verifier)).lowercaseHex]
        case .protocolReceipt, .diagnosticOutput, .attemptEvent: throw CampaignEvidenceFixtureError.unsupportedRole
        }
        value.merge(fields) { $1 }
        return try InvestigationMachineEvidenceJSON.canonicalData(value)
    }

    private func projection(ordinal: Int) throws -> InvestigationInstalledL2IdentityProjection {
        let digest = InvestigationMachineCampaignEvidenceTests.digest
        return try .init(epochUUID: CampaignEvidenceFixture.uuid(UInt8(0x30 + ordinal)), configurationNonce: CampaignEvidenceFixture.uuid(UInt8(0x40 + ordinal)), configurationValidBefore: .init(rawValue: 2_000_000_000_000_000), configurationSHA256: .hashing(Data([UInt8(ordinal)])), signedRuntimeBindingSHA256: sourceBinding.signedRuntimeBindingSHA256, appExecutableSHA256: digest(0x71), appBundleIdentifier: InvestigationInstalledL2IdentityProjection.fixedAppBundleIdentifier, helperExecutableSHA256: digest(0x72), helperServiceIdentifier: InvestigationInstalledL2IdentityProjection.fixedHelperServiceIdentifier, machineDriverExecutableSHA256: digest(0x73), machineDriverSigningIdentifier: InvestigationInstalledL2IdentityProjection.fixedMachineDriverSigningIdentifier, machineDriverDesignatedRequirementSHA256: digest(0x74), machineDriverCodeDirectoryHash: Data(repeating: 0x75, count: 20), machineClaimServiceIdentifier: InvestigationInstalledL2IdentityProjection.fixedMachineClaimServiceIdentifier)
    }

    private func roleName(_ role: InvestigationMachineEvidenceRole) -> String {
        switch role {
        case .sourceBuildIdentity: "sourceBuildIdentity"; case .builtStagingInstalledIdentity: "builtStagingInstalledIdentity"
        case .policyProbe: "policyProbe"; case .humanPromptAttestation: "humanPromptAttestation"
        case .noAuthModelNetworkCounters: "noAuthModelNetworkCounters"; case .epochL2Projection: "epochL2Projection"
        case .epochResidueProjection: "epochResidueProjection"; case .uninstallEvidence: "uninstallEvidence"
        case .globalPostTeardown: "globalPostTeardown"; case .verifierInput: "verifierInput"
        case .protocolReceipt: "protocolReceipt"; case .diagnosticOutput: "diagnosticOutput"; case .attemptEvent: "attemptEvent"
        }
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
        case .missingFile:
            try FileManager.default.removeItem(at: source)
        case .extraFile:
            let extra = phase.appending(path: "extra.json")
            try Data("{}".utf8).write(to: extra)
            try #require(chmod(extra.path, 0o600) == 0)
        case .extraDirectory:
            try FileManager.default.createDirectory(
                at: evidenceRoot.appending(path: "extra"),
                withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700])
        case .replacementSymlink:
            try FileManager.default.removeItem(at: source)
            try #require(symlink(
                "../02-install/installed.json", source.path) == 0)
        case .replacementHardLink:
            try FileManager.default.removeItem(at: source)
            try #require(link(evidenceRoot.appending(
                path: "02-install/installed.json").path, source.path) == 0)
        case .wrongDirectoryMode:
            try #require(chmod(phase.path, 0o755) == 0)
        case .missingDirectory:
            try FileManager.default.removeItem(at: evidenceRoot.appending(
                path: "04-driver-epochs"))
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
    case fault
    case realpath(Int32)
    case unsupportedRole
}

enum CampaignLifecycleFinalizerFault: CaseIterable {
    case runner, status, decode, validate
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
        capsuleSize: Int64 = 104,
        buildProvenanceSHA256: String = String(repeating: "a", count: 64),
        signedBindingSHA256: InvestigationHandoffSHA256 =
            InvestigationMachineCampaignEvidenceTests.digest(0x71),
        wholeInputSHA256: InvestigationHandoffSHA256 =
            InvestigationMachineCampaignEvidenceTests.digest(0x73),
        gateTransportReceiptSHA256: InvestigationHandoffSHA256 =
            InvestigationMachineCampaignEvidenceTests.digest(0x75),
        gateSessionID: pid_t = 3_901,
        monotonicStartedNanoseconds: UInt64 = 10,
        monotonicCompletedNanoseconds: UInt64 = 20
    ) throws -> Data {
        let payload = try InvestigationMachineGateCoordinatorReceiptV1(
            buildProvenanceSHA256: buildProvenanceSHA256,
            signedBindingSHA256: signedBindingSHA256,
            outerAttemptUUID: attemptUUID,
            wholeProjectedInputSHA256: wholeInputSHA256,
            capsule: .init(
                device: 101, inode: 102, generation: 103, size: capsuleSize),
            gateExecutableSHA256:
                InvestigationMachineCampaignEvidenceTests.digest(0x74),
            gateTransportReceiptSHA256: gateTransportReceiptSHA256,
            gateProcessID: 4_001, gateProcessGroupID: 4_001,
            gateSessionID: gateSessionID, exactGateWaitClassification: .exited(status: 0),
            receiptReachedEOF: true, receiptOverflowObserved: false,
            receiptDeadlineExpired: false, capsuleSettlementRemoved: true,
            attemptBaseRetired: true, runtimeArtifactsRetired: true,
            monotonicStartedNanoseconds: monotonicStartedNanoseconds,
            monotonicCompletedNanoseconds: monotonicCompletedNanoseconds).encoded()
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
