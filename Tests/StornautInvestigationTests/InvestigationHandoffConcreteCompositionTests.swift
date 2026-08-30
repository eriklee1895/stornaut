import Foundation
import StornautInvestigation
import Testing
@testable import StornautInvestigationDiagnostic
@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationRuntime
@testable import StornautLifecycle

@Suite("Investigation concrete inherited-FD composition", .serialized)
struct InvestigationHandoffConcreteCompositionTests {
    @Test
    func interactiveRuntimeBindsSignedNativeToSuspendedChildImage()
        throws
    {
        let root = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source: (String) throws -> String = { path in
            try String(
                contentsOf: root.appending(path: path),
                encoding: .utf8
            )
        }
        let lifecycle = try source(
            "Sources/StornautLifecycle/LifecycleInteractiveSessionContract.swift"
        )
        let broker = try source(
            "Sources/StornautLifecycle/LifecycleInteractiveSessionBroker.swift"
        )
        let helper = try source("StornautLifecycleHelper/main.swift")
        let contained = try source(
            "Sources/StornautCodex/Runtime/CodexContainedInteractiveSession.swift"
        )

        #expect(lifecycle.contains("public static let protocolVersion = 3"))
        #expect(lifecycle.contains("public let codexExecutableSHA256: String?"))
        #expect(broker.contains("codexExecutableSHA256:"))
        let composition = try source(
            "Sources/StornautInvestigationDiagnostic/InvestigationRuntimeDiagnosticComposition.swift"
        )
        #expect(composition.contains("codexExecutableSHA256:"))
        #expect(composition.contains(
            "configuration.binding.codexExecutableSHA256"
        ))
        #expect(helper.contains("expectedCodexExecutableSHA256:"))
        #expect(helper.contains("configuration.codexExecutableSHA256"))
        #expect(contained.contains("CodexNativeExecutableIdentitySource()"))
        #expect(contained.contains("POSIX_SPAWN_START_SUSPENDED"))
        #expect(contained.contains("WUNTRACED | WNOHANG"))
        #expect(contained.contains("PROC_PIDREGIONPATHINFO"))
        #expect(contained.contains("initialStopStatus == 0x7f"))
        #expect(!contained.contains(
            "executableURL: installation.executableURL"
        ))
    }

    @Test
    func concreteOperationsDriveTheExactLeafAndRetirementSequence()
        async throws
    {
        let fixture = try ConcreteHandoffFixture()
        defer { fixture.remove() }
        let adapter = ConcreteFakeHandoffAdapter(fixture: fixture)
        let retirement = ConcreteRetirementProbe(handle: fixture.handle)
        let operations = try InvestigationHandoffConcreteAppLeafOperations(
            adapter: adapter,
            peer: fixture.peer,
            now: { fixture.now },
            retirementHandle: { projection in
                await retirement.record(projection)
                return fixture.handle
            }
        )
        let leaf = InvestigationHandoffAppLeaf(
            bootstrap: fixture.bootstrap,
            driverClaim: fixture.driverClaim,
            operations: operations
        )

        #expect(try await leaf.run() == .completed)
        #expect(await adapter.writtenKinds() == [
            .preDropReady,
            .dropEvidence,
            .configurationAcknowledgement,
            .hello,
            .handle,
            .alive,
        ])
        #expect(await adapter.didHalfClose)
        #expect(await retirement.callCount == 1)
        #expect(
            await retirement.projection?.configuration
                == fixture.configuration
        )
        #expect(
            await retirement.projection?.configurationSHA256
                == fixture.configurationSHA256.lowercaseHex
        )
        #expect(
            await retirement.projection?.runtimeReceipt
                == fixture.runtimeReceipt
        )
        #expect(
            fixture.configuration.binding.runtimeReceiptSHA256
                == (try InvestigationRuntimeReceiptCanonicalV1.sha256(
                    fixture.runtimeReceipt
                ))
        )
        await #expect(throws: InvestigationHandoffAppLeafError.alreadyConsumed) {
            _ = try await leaf.run()
        }
    }

    @Test
    func acknowledgementRequiresCanonicalBytesAndExactPeerBinding() async throws {
        let fixture = try ConcreteHandoffFixture()
        defer { fixture.remove() }

        let accepted = try InvestigationHandoffConcreteAppLeafOperations(
            adapter: ConcreteFakeHandoffAdapter(fixture: fixture),
            peer: fixture.peer,
            now: { fixture.now },
            retirementHandle: { _ in fixture.handle }
        )
        let acknowledgement = try await accepted
            .acknowledgeConfiguration(fixture.configurationData)
        #expect(acknowledgement.epochUUID == fixture.bootstrap.epochUUID)
        #expect(acknowledgement.ordinal == 0)
        #expect(acknowledgement.scenario == .success)
        #expect(
            acknowledgement.configurationSHA256
                == fixture.configurationSHA256
        )
        #expect(
            acknowledgement.signedRuntimeBindingSHA256
                == fixture.bindingSHA256
        )

        let object = try #require(
            JSONSerialization.jsonObject(with: fixture.configurationData)
                as? [String: Any]
        )
        let noncanonical = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted]
        )
        let rejectsNoncanonical = try InvestigationHandoffConcreteAppLeafOperations(
            adapter: ConcreteFakeHandoffAdapter(fixture: fixture),
            peer: fixture.peer,
            now: { fixture.now },
            retirementHandle: { _ in fixture.handle }
        )
        await #expect(throws: InvestigationHandoffConcreteAppLeafError.self) {
            _ = try await rejectsNoncanonical
                .acknowledgeConfiguration(noncanonical)
        }

        let foreign = try fixture.peer(
            executableSHA256: String(repeating: "7", count: 64)
        )
        let rejectsForeignPeer = try InvestigationHandoffConcreteAppLeafOperations(
            adapter: ConcreteFakeHandoffAdapter(fixture: fixture),
            peer: foreign,
            now: { fixture.now },
            retirementHandle: { _ in fixture.handle }
        )
        await #expect(throws: InvestigationHandoffConcreteAppLeafError.self) {
            _ = try await rejectsForeignPeer
                .acknowledgeConfiguration(fixture.configurationData)
        }
    }

    @Test
    func acknowledgementAcceptsPresealedMachineCohortValidity() async throws {
        let fixture = try ConcreteHandoffFixture(machineCohortWindow: 1_200)
        defer { fixture.remove() }
        let operations = try InvestigationHandoffConcreteAppLeafOperations(
            adapter: ConcreteFakeHandoffAdapter(fixture: fixture),
            peer: fixture.peer, now: { fixture.now },
            retirementHandle: { _ in fixture.handle }
        )

        let acknowledgement = try await operations.acknowledgeConfiguration(
            fixture.configurationData
        )

        #expect(acknowledgement.configurationSHA256
            == .hashing(fixture.configurationData))
        #expect(acknowledgement.configurationNonce == fixture.configuration.nonce)
    }

    @Test(arguments: [
        ConcreteBindingMutation.repositoryHEAD,
        ConcreteBindingMutation.sourceFingerprintSHA256,
        ConcreteBindingMutation.runtimeReceiptSHA256,
    ])
    func acknowledgementRejectsRuntimeReceiptDependencyDrift(
        mutation: ConcreteBindingMutation
    ) async throws {
        let fixture = try ConcreteHandoffFixture()
        defer { fixture.remove() }
        let retirement = ConcreteRetirementProbe(handle: fixture.handle)
        let operations = try InvestigationHandoffConcreteAppLeafOperations(
            adapter: ConcreteFakeHandoffAdapter(fixture: fixture),
            peer: fixture.peer,
            now: { fixture.now },
            retirementHandle: { projection in
                await retirement.record(projection)
                return fixture.handle
            }
        )
        let foreignConfiguration = try fixture.configuration(
            mutatingBinding: mutation
        )

        await #expect(
            throws: InvestigationHandoffConcreteAppLeafError.invalidConfiguration
        ) {
            _ = try await operations.acknowledgeConfiguration(
                foreignConfiguration.canonicalJSONData()
            )
        }
        await #expect(
            throws: InvestigationHandoffConcreteAppLeafError.invalidState
        ) {
            _ = try await operations.retirementHandle()
        }
        #expect(await retirement.callCount == 0)
    }

    @Test
    func acknowledgementMapsAllScenariosAndRejectsEveryPeerFieldDrift()
        async throws
    {
        for (index, scenario) in
            SignedInvestigationRuntimeDiagnosticScenario.allCases.enumerated()
        {
            let fixture = try ConcreteHandoffFixture(scenario: scenario)
            defer { fixture.remove() }
            let operations = try InvestigationHandoffConcreteAppLeafOperations(
                adapter: ConcreteFakeHandoffAdapter(fixture: fixture),
                peer: fixture.peer,
                now: { fixture.now },
                retirementHandle: { _ in fixture.handle }
            )
            let acknowledgement = try await operations
                .acknowledgeConfiguration(fixture.configurationData)
            #expect(acknowledgement.ordinal == UInt32(index))
            #expect(acknowledgement.scenario.rawValue == UInt32(index + 1))
            #expect(
                acknowledgement.signedRuntimeBindingSHA256
                    == fixture.bindingSHA256
            )
        }

        let fixture = try ConcreteHandoffFixture()
        defer { fixture.remove() }
        for mutation in ConcretePeerMutation.allCases {
            let operations = try InvestigationHandoffConcreteAppLeafOperations(
                adapter: ConcreteFakeHandoffAdapter(fixture: fixture),
                peer: try fixture.peer(mutation: mutation),
                now: { fixture.now },
                retirementHandle: { _ in fixture.handle }
            )
            await #expect(throws: InvestigationHandoffConcreteAppLeafError.self) {
                _ = try await operations
                    .acknowledgeConfiguration(fixture.configurationData)
            }
            await #expect(throws: InvestigationHandoffConcreteAppLeafError.self) {
                _ = try await operations.receiveDropRelease()
            }
        }
    }

    @Test
    func everyMutableBindingFieldChangesBothCommitments() throws {
        let fixture = try ConcreteHandoffFixture()
        defer { fixture.remove() }
        let baselineCapability =
            try fixture.configuration.capabilityEvidenceBindingSHA256()
        let baselineConfiguration =
            try fixture.configuration.machineConfigurationSHA256()

        for mutation in ConcreteBindingMutation.allCases {
            let mutated = try fixture.configuration(
                mutatingBinding: mutation
            )
            #expect(
                try mutated.capabilityEvidenceBindingSHA256()
                    != baselineCapability,
                "Capability commitment omitted \(mutation)"
            )
            #expect(
                try mutated.machineConfigurationSHA256()
                    != baselineConfiguration,
                "Configuration commitment omitted \(mutation)"
            )
        }
    }

    @Test
    func concreteOperationsRejectContradictoryPeerObservationAtConstruction()
        throws
    {
        let fixture = try ConcreteHandoffFixture()
        defer { fixture.remove() }
        for mutation in ConcretePeerObservationMutation.allCases {
            let contradictory = try fixture.peer(
                observationMutation: mutation
            )
            #expect(
                throws:
                    InvestigationHandoffConcreteAppLeafError.bindingMismatch,
                "Contradictory peer accepted: \(mutation)"
            ) {
                _ = try InvestigationHandoffConcreteAppLeafOperations(
                    adapter: ConcreteFakeHandoffAdapter(fixture: fixture),
                    peer: contradictory,
                    now: { fixture.now },
                    retirementHandle: { _ in fixture.handle }
                )
            }
        }
    }

    @Test
    func retirementHandleRequiresAcceptedConfigurationAndIsOneShot() async throws {
        let fixture = try ConcreteHandoffFixture()
        defer { fixture.remove() }
        let beforeAcknowledgement = try InvestigationHandoffConcreteAppLeafOperations(
            adapter: ConcreteFakeHandoffAdapter(fixture: fixture),
            peer: fixture.peer,
            now: { fixture.now },
            retirementHandle: { _ in fixture.handle }
        )

        await #expect(throws: InvestigationHandoffConcreteAppLeafError.self) {
            _ = try await beforeAcknowledgement.retirementHandle()
        }
        let operations = try InvestigationHandoffConcreteAppLeafOperations(
            adapter: ConcreteFakeHandoffAdapter(fixture: fixture),
            peer: fixture.peer,
            now: { fixture.now },
            retirementHandle: { _ in fixture.handle }
        )
        _ = try await operations
            .acknowledgeConfiguration(fixture.configurationData)
        #expect(try await operations.retirementHandle() == fixture.handle)
        await #expect(throws: InvestigationHandoffConcreteAppLeafError.self) {
            _ = try await operations.retirementHandle()
        }
    }

    @Test
    func retirementHandleEnforcesCompletionConfigurationAndThirtySecondBounds()
        async throws
    {
        for (offset, accepted) in [
            (10.0, true),
            (30.0, true),
            (31.0, false),
            (0.0, false),
        ] {
            let fixture = try ConcreteHandoffFixture()
            defer { fixture.remove() }
            let handle = try fixture.handle(
                operationID: try ConcreteHandoffFixture.uuid(0x62),
                validBefore: fixture.now.addingTimeInterval(offset)
            )
            let operations = try InvestigationHandoffConcreteAppLeafOperations(
                adapter: ConcreteFakeHandoffAdapter(fixture: fixture),
                peer: fixture.peer,
                now: { fixture.now },
                retirementHandle: { _ in handle }
            )
            _ = try await operations
                .acknowledgeConfiguration(fixture.configurationData)
            if accepted {
                #expect(try await operations.retirementHandle() == handle)
            } else {
                await #expect(
                    throws: InvestigationHandoffConcreteAppLeafError.self
                ) {
                    _ = try await operations.retirementHandle()
                }
            }
        }

        let shortConfiguration = try ConcreteHandoffFixture(
            configurationWindow: 20
        )
        defer { shortConfiguration.remove() }
        let tooLate = try shortConfiguration.handle(
            operationID: try ConcreteHandoffFixture.uuid(0x62),
            validBefore: shortConfiguration.now.addingTimeInterval(21)
        )
        let operations = try InvestigationHandoffConcreteAppLeafOperations(
            adapter: ConcreteFakeHandoffAdapter(fixture: shortConfiguration),
            peer: shortConfiguration.peer,
            now: { shortConfiguration.now },
            retirementHandle: { _ in tooLate }
        )
        _ = try await operations
            .acknowledgeConfiguration(shortConfiguration.configurationData)
        await #expect(throws: InvestigationHandoffConcreteAppLeafError.self) {
            _ = try await operations.retirementHandle()
        }

        let advancing = try ConcreteHandoffFixture()
        defer { advancing.remove() }
        let clock = SequenceConcreteClock([
            advancing.now,
            advancing.now,
            advancing.now,
            advancing.now.addingTimeInterval(2),
        ])
        let completionRelativeHandle = try advancing.handle(
            operationID: try ConcreteHandoffFixture.uuid(0x62),
            validBefore: advancing.now.addingTimeInterval(32)
        )
        let acceptsHelperCompletionRelativeDeadline =
            try InvestigationHandoffConcreteAppLeafOperations(
                adapter: ConcreteFakeHandoffAdapter(fixture: advancing),
                peer: advancing.peer,
                now: { advancing.now },
                continuousNow: { clock.nextNanoseconds(relativeTo: advancing) },
                retirementHandle: { _ in completionRelativeHandle }
            )
        _ = try await acceptsHelperCompletionRelativeDeadline
            .acknowledgeConfiguration(advancing.configurationData)
        #expect(
            try await acceptsHelperCompletionRelativeDeadline
                .retirementHandle() == completionRelativeHandle
        )

        for (completedOffset, deadlineOffset) in [
            (2.0, 1.0),
            (2.0, 2.0),
            (-1.0, 10.0),
        ] {
            let fixture = try ConcreteHandoffFixture()
            defer { fixture.remove() }
            let startOffset = completedOffset < 0 ? 2.0 : 0.0
            let clock = SequenceConcreteClock([
                fixture.now,
                fixture.now,
                fixture.now.addingTimeInterval(startOffset),
                fixture.now.addingTimeInterval(completedOffset < 0
                    ? 1.0 : completedOffset),
            ])
            let handle = try fixture.handle(
                operationID: try ConcreteHandoffFixture.uuid(0x62),
                validBefore: fixture.now.addingTimeInterval(deadlineOffset)
            )
            let rejectsInvalidCompletionEdge =
                try InvestigationHandoffConcreteAppLeafOperations(
                    adapter: ConcreteFakeHandoffAdapter(fixture: fixture),
                    peer: fixture.peer,
                    now: { fixture.now },
                    continuousNow: { clock.nextNanoseconds(relativeTo: fixture) },
                    retirementHandle: { _ in handle }
                )
            _ = try await rejectsInvalidCompletionEdge
                .acknowledgeConfiguration(fixture.configurationData)
            await #expect(
                throws: InvestigationHandoffConcreteAppLeafError.self
            ) {
                _ = try await rejectsInvalidCompletionEdge
                    .retirementHandle()
            }
        }
    }

    @Test(arguments: [false, true])
    func suspendedRetirementCannotCommitAfterConcurrentUseOrCancellation(
        cancel: Bool
    ) async throws {
        let fixture = try ConcreteHandoffFixture()
        defer { fixture.remove() }
        let gate = SuspendedConcreteRetirementFactory(handle: fixture.handle)
        let operations = try InvestigationHandoffConcreteAppLeafOperations(
            adapter: ConcreteFakeHandoffAdapter(fixture: fixture),
            peer: fixture.peer,
            now: { fixture.now },
            retirementHandle: { _ in try await gate.run() }
        )
        _ = try await operations
            .acknowledgeConfiguration(fixture.configurationData)
        let retirement = Task { try await operations.retirementHandle() }
        await gate.waitUntilEntered()
        if cancel {
            retirement.cancel()
        } else {
            await #expect(throws: InvestigationHandoffConcreteAppLeafError.self) {
                _ = try await operations.receiveRelease()
            }
        }
        await gate.resume()
        await #expect(throws: InvestigationHandoffConcreteAppLeafError.self) {
            _ = try await retirement.value
        }
        await #expect(throws: InvestigationHandoffConcreteAppLeafError.self) {
            _ = try await operations.receiveRelease()
        }
    }

    @Test
    func adapterAndRetirementFailuresMakeTheConcreteEpochTerminal() async throws {
        let fixture = try ConcreteHandoffFixture()
        defer { fixture.remove() }
        let failedAdapter = ConcreteFakeHandoffAdapter(
            fixture: fixture,
            failPreDrop: true
        )
        let adapterFailure = try InvestigationHandoffConcreteAppLeafOperations(
            adapter: failedAdapter,
            peer: fixture.peer,
            now: { fixture.now },
            retirementHandle: { _ in fixture.handle }
        )
        await #expect(throws: InvestigationHandoffConcreteAppLeafError.self) {
            _ = try await adapterFailure.preDropClaim()
        }
        await #expect(throws: InvestigationHandoffConcreteAppLeafError.self) {
            _ = try await adapterFailure.receiveDropRelease()
        }

        let retirementFailure = try InvestigationHandoffConcreteAppLeafOperations(
            adapter: ConcreteFakeHandoffAdapter(fixture: fixture),
            peer: fixture.peer,
            now: { fixture.now },
            retirementHandle: { _ in
                throw InvestigationHandoffConcreteAppLeafError.bindingMismatch
            }
        )
        _ = try await retirementFailure
            .acknowledgeConfiguration(fixture.configurationData)
        await #expect(throws: InvestigationHandoffConcreteAppLeafError.self) {
            _ = try await retirementFailure.retirementHandle()
        }
        await #expect(throws: InvestigationHandoffConcreteAppLeafError.self) {
            _ = try await retirementFailure.receiveRelease()
        }
    }

    @Test
    func noAuthRetirementUsesOnlyStartRetireAndConvertsTheExactHandle()
        async throws
    {
        let fixture = try ConcreteHandoffFixture()
        defer { fixture.remove() }
        let operationIDs = [
            try ConcreteHandoffFixture.uuid(0x61),
            try ConcreteHandoffFixture.uuid(0x62),
        ]
        let provider = ConcreteOperationIDProvider(operationIDs)
        let session = ConcreteLifecycleSession(
            fixture: fixture,
            operationIDs: operationIDs
        )

        let handle = try await InvestigationHandoffNoAuthRetirement.run(
            projection: try fixture.acceptedProjection(),
            session: session,
            now: { fixture.now },
            operationID: { try provider.next() }
        )

        #expect(await session.requests.map(\.kind) == [.start, .retire])
        #expect(await session.requests.allSatisfy { $0.line == nil })
        let expected = try fixture.handle(operationID: operationIDs[1])
        #expect(handle == expected)

        let wrongDigest = String(repeating: "0", count: 64)
        await #expect(throws: InvestigationHandoffConcreteAppLeafError.self) {
            _ = try await InvestigationHandoffNoAuthRetirement.run(
                projection: try fixture.acceptedProjection(
                    configurationSHA256: wrongDigest
                ),
                session: ConcreteLifecycleSession(
                    fixture: fixture,
                    operationIDs: operationIDs
                ),
                now: { fixture.now }
            )
        }

        let foreignReceipt = try InvestigationRuntimeReceiptCanonicalV1.receipt(
            repositoryHEAD: String(repeating: "9", count: 40),
            sourceFingerprintSHA256:
                fixture.configuration.binding.sourceFingerprintSHA256
        )
        #expect(throws: InvestigationHandoffConcreteAppLeafError.self) {
            _ = try fixture.acceptedProjection(runtimeReceipt: foreignReceipt)
        }
    }

    @Test
    func noAuthRetirementClampsTheSessionToTheEpochWallClockWindow() async throws {
        for (window, expected) in [(1_200.0, 140.0), (100.0, 100.0)] {
            let fixture = try ConcreteHandoffFixture(
                machineCohortWindow: window
            )
            defer { fixture.remove() }
            let operationIDs = [
                try ConcreteHandoffFixture.uuid(0x61),
                try ConcreteHandoffFixture.uuid(0x62),
            ]
            let session = ConcreteLifecycleSession(
                fixture: fixture, operationIDs: operationIDs
            )
            let bytes = try fixture.configuration.canonicalJSONData()
            let digest = try fixture.configuration.machineConfigurationSHA256()

            _ = try await InvestigationHandoffNoAuthRetirement.run(
                projection: try fixture.acceptedProjection(),
                session: session, now: { fixture.now },
                operationID: ConcreteOperationIDProvider(operationIDs).next
            )

            let requests = await session.requests
            #expect(try #require(requests.first?.validBefore)
                == fixture.now.addingTimeInterval(expected))
            #expect(try fixture.configuration.canonicalJSONData() == bytes)
            #expect(try fixture.configuration.machineConfigurationSHA256()
                == digest)
        }
    }

    @Test
    func appLeafHandshakeCannotExtendTheCapturedEpochDeadline() async throws {
        let continuousAnchor: UInt64 = 10_000_000_000
        let fixture = try ConcreteHandoffFixture(
            machineCohortWindow: 1_200, remainingEpochSeconds: 40,
            bootstrapStartedAtNanoseconds: continuousAnchor
        )
        defer { fixture.remove() }
        let clock = SequenceConcreteClock([fixture.now])
        let continuousClock = SequenceConcreteContinuousClock([
            continuousAnchor, continuousAnchor + 1_000_000_000,
            continuousAnchor + 39_000_000_000,
            continuousAnchor + 41_000_000_000,
        ])
        let handle = try fixture.handle(
            operationID: try ConcreteHandoffFixture.uuid(0x62),
            validBefore: fixture.now.addingTimeInterval(-80)
        )
        let retirement = ConcreteRetirementProbe(handle: handle)
        let operations = try InvestigationHandoffConcreteAppLeafOperations(
            adapter: ConcreteFakeHandoffAdapter(fixture: fixture),
            peer: fixture.peer, now: { clock.next() },
            continuousNow: { try continuousClock.next() },
            retirementHandle: { projection in
                await retirement.record(projection)
                return handle
            }
        )

        _ = try await operations.acknowledgeConfiguration(
            fixture.configurationData
        )
        await #expect(throws: InvestigationHandoffConcreteAppLeafError.self) {
            _ = try await operations.retirementHandle()
        }

        let deadline = try #require(
            await retirement.projection?.epochValidBefore
        )
        #expect(deadline == fixture.now.addingTimeInterval(40))
    }

    @Test(arguments: [false, true])
    func appLeafMonotonicFailureOrRegressionExpiresTheEpoch(
        throwsOnRead: Bool
    ) async throws {
        let anchor: UInt64 = 10_000_000_000
        let fixture = try ConcreteHandoffFixture(
            machineCohortWindow: 1_200, remainingEpochSeconds: 40,
            bootstrapStartedAtNanoseconds: anchor
        )
        defer { fixture.remove() }
        let continuousClock = SequenceConcreteContinuousClock([
            anchor, throwsOnRead ? nil : anchor - 1,
        ])
        let operations = try InvestigationHandoffConcreteAppLeafOperations(
            adapter: ConcreteFakeHandoffAdapter(fixture: fixture),
            peer: fixture.peer, now: { fixture.now },
            continuousNow: { try continuousClock.next() },
            retirementHandle: { _ in fixture.handle }
        )

        await #expect(throws: InvestigationHandoffConcreteAppLeafError.self) {
            _ = try await operations.acknowledgeConfiguration(
                fixture.configurationData
            )
        }
        await #expect(throws: InvestigationHandoffConcreteAppLeafError.self) {
            _ = try await operations.preDropClaim()
        }
    }
}

enum ConcreteBindingMutation: CaseIterable, Sendable {
    case repositoryHEAD
    case sourceFingerprintSHA256
    case appExecutableSHA256
    case helperExecutableSHA256
    case runtimeReceiptSHA256
    case promptSHA256
    case envelopeSchemaSHA256
    case facadeSHA256
    case codexExecutableSHA256
    case machineExecutableSHA256
    case machineDesignatedRequirementSHA256
    case machineCodeDirectoryHash
}

private enum ConcretePeerMutation: CaseIterable {
    case executableSHA256
    case signingIdentifier
    case designatedRequirementSHA256
    case codeDirectoryHash
}

private enum ConcretePeerObservationMutation: CaseIterable {
    case claimProcessID
    case claimProcessIDVersion
    case claimEffectiveUserID
    case claimAuditSessionID
    case identityNotRoot
    case tokenEffectiveUserID
    case tokenProcessID
    case tokenAuditSessionID
    case tokenProcessIDVersion
    case signingNotAdHoc
}

private struct ConcreteHandoffFixture: Sendable {
    let root: URL
    let now = Date(timeIntervalSince1970: 1_900_000_000)
    let bootstrap: InvestigationHandoffEpochBootstrap
    let driverClaim: InvestigationHandoffProcessClaim
    let preDropClaim: InvestigationHandoffProcessClaim
    let postDropClaim: InvestigationHandoffProcessClaim
    let dropEvidence: InvestigationHandoffDropEvidence
    let runtimeReceipt: InvestigationRuntimeReceiptV1
    let configuration: SignedInvestigationRuntimeDiagnosticConfiguration
    let configurationData: Data
    let configurationSHA256: InvestigationHandoffSHA256
    let bindingSHA256: InvestigationHandoffSHA256
    let peer: InvestigationHandoffAppLeafPeerObservation
    let handle: InvestigationHandoffRetirementHandle

    init(
        scenario: SignedInvestigationRuntimeDiagnosticScenario = .success,
        configurationWindow: TimeInterval = 120,
        machineCohortWindow: TimeInterval? = nil,
        remainingEpochSeconds: UInt64 = 140,
        bootstrapStartedAtNanoseconds: UInt64? = nil
    ) throws {
        let temporaryPath = FileManager.default.temporaryDirectory.path
        guard let resolvedTemporaryPath = realpath(temporaryPath, nil) else {
            throw InvestigationHandoffConcreteAppLeafError.invalidState
        }
        defer { free(resolvedTemporaryPath) }
        root = URL(
            filePath: String(cString: resolvedTemporaryPath),
            directoryHint: .isDirectory
        ).appending(
            path: "stornaut-b3c-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        let source = root.appending(path: "source", directoryHint: .isDirectory)
        let support = root.appending(path: "support", directoryHint: .isDirectory)
        let runtime = root.appending(path: "runtime", directoryHint: .isDirectory)
        let report = root.appending(path: "report.json")
        let store = support.appending(
            path: "com.eriklee.stornaut/Evidence.sqlite"
        )
        for directory in [
            root, source, support, runtime, store.deletingLastPathComponent(),
        ] {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        }
        let bootstrapStartedAtNanoseconds = bootstrapStartedAtNanoseconds
            ?? investigationHandoffTestContinuousNanoseconds()
        bootstrap = try InvestigationHandoffEpochBootstrap(
            epochUUID: Self.uuid(0x11),
            epochDeadlineNanoseconds: bootstrapStartedAtNanoseconds
                + remainingEpochSeconds * 1_000_000_000
        )
        driverClaim = try Self.claim(pid: 84, version: 8, uid: 0, asid: 10)
        preDropClaim = try Self.claim(pid: 42, version: 7, uid: 0, asid: 9)
        postDropClaim = try Self.claim(pid: 42, version: 7, uid: 501, asid: 9)
        dropEvidence = try InvestigationHandoffDropEvidence(
            realUserID: 501, effectiveUserID: 501, savedUserID: 501,
            realGroupID: 20, effectiveGroupID: 20, savedGroupID: 20,
            supplementaryGroups: Array(UInt32(1)...UInt32(15)) + [20],
            auditTokenWords: [501, 501, 20, 501, 20, 42, 9, 7],
            setuidRootErrno: UInt32(EPERM),
            seteuidRootErrno: UInt32(EPERM),
            setgidRootErrno: UInt32(EPERM)
        )
        let machine = try SignedInvestigationRuntimeMachineDriverBinding(
            executableSHA256: String(repeating: "4", count: 64),
            signingIdentifier:
                SignedInvestigationRuntimeMachineDriverBinding
                .requiredSigningIdentifier,
            designatedRequirementSHA256: String(repeating: "5", count: 64),
            codeDirectoryHash: String(repeating: "6", count: 64),
            machineClaimServiceIdentifier:
                SignedInvestigationRuntimeMachineDriverBinding
                .requiredMachineClaimServiceIdentifier
        )
        let repositoryHEAD = String(repeating: "a", count: 40)
        let sourceFingerprintSHA256 = String(repeating: "b", count: 64)
        let receipt = try InvestigationRuntimeReceiptCanonicalV1.receipt(
            repositoryHEAD: repositoryHEAD,
            sourceFingerprintSHA256: sourceFingerprintSHA256
        )
        runtimeReceipt = receipt
        let binding = SignedInvestigationRuntimeBinding(
            repositoryHEAD: repositoryHEAD,
            sourceFingerprintSHA256: sourceFingerprintSHA256,
            appExecutableSHA256: String(repeating: "c", count: 64),
            helperExecutableSHA256: String(repeating: "d", count: 64),
            runtimeReceiptSHA256:
                try InvestigationRuntimeReceiptCanonicalV1.sha256(
                    receipt
                ),
            promptSHA256: String(repeating: "f", count: 64),
            envelopeSchemaSHA256: String(repeating: "1", count: 64),
            facadeSHA256: String(repeating: "2", count: 64),
            codexExecutableSHA256: String(repeating: "3", count: 64),
            appBundleIdentifier: "com.eriklee.stornaut",
            helperServiceIdentifier: "com.eriklee.stornaut.lifecycle",
            machineDriver: machine
        )
        let configurationArguments = (
            nonce: try Self.uuid(0x21),
            scenario: scenario,
            diagnosticRootPath: root.path, sourceRootPath: source.path,
            supportRootPath: support.path, runtimeRootPath: runtime.path,
            reportPath: report.path, storePath: store.path, binding: binding,
            validBefore: now.addingTimeInterval(
                machineCohortWindow ?? configurationWindow
            )
        )
        if machineCohortWindow != nil {
            configuration = try SignedInvestigationRuntimeDiagnosticConfiguration
                .machineCohort(
            nonce: configurationArguments.nonce,
            scenario: configurationArguments.scenario,
            optIn: SignedInvestigationRuntimeDiagnosticConfiguration.requiredOptIn,
            diagnosticRootPath: configurationArguments.diagnosticRootPath,
            sourceRootPath: configurationArguments.sourceRootPath,
            supportRootPath: configurationArguments.supportRootPath,
            runtimeRootPath: configurationArguments.runtimeRootPath,
            reportPath: configurationArguments.reportPath,
            storePath: configurationArguments.storePath,
            binding: configurationArguments.binding,
            expectedModel: .gpt56Luna, expectedProvider: .openAI,
            validBefore: configurationArguments.validBefore,
            maximumWallClockSeconds: 140, maximumTurns: 3,
            maximumProbeCalls: 16, maximumContextBytes: 1_048_576, now: now
          )
        } else {
          configuration = try SignedInvestigationRuntimeDiagnosticConfiguration(
            nonce: configurationArguments.nonce,
            scenario: configurationArguments.scenario,
            optIn: SignedInvestigationRuntimeDiagnosticConfiguration.requiredOptIn,
            diagnosticRootPath: configurationArguments.diagnosticRootPath,
            sourceRootPath: configurationArguments.sourceRootPath,
            supportRootPath: configurationArguments.supportRootPath,
            runtimeRootPath: configurationArguments.runtimeRootPath,
            reportPath: configurationArguments.reportPath,
            storePath: configurationArguments.storePath,
            binding: configurationArguments.binding,
            expectedModel: .gpt56Luna,
            expectedProvider: .openAI,
            validBefore: configurationArguments.validBefore,
            maximumWallClockSeconds: 140,
            maximumTurns: 3,
            maximumProbeCalls: 16,
            maximumContextBytes: 1_048_576,
            now: now
        )
        }
        configurationData = try configuration.canonicalJSONData()
        configurationSHA256 = .hashing(configurationData)
        bindingSHA256 = try InvestigationHandoffSHA256(
            lowercaseHex: configuration.capabilityEvidenceBindingSHA256()
        )
        peer = try Self.peer(
            bootstrap: bootstrap,
            driverClaim: driverClaim,
            executableSHA256: machine.executableSHA256,
            designatedRequirementSHA256: machine.designatedRequirementSHA256,
            codeDirectoryHash: machine.codeDirectoryHash
        )
        handle = try Self.handle(
            configuration: configuration,
            configurationSHA256: configurationSHA256,
            operationID: Self.uuid(0x62),
            validBefore: now.addingTimeInterval(30)
        )
    }

    func peer(
        executableSHA256: String
    ) throws -> InvestigationHandoffAppLeafPeerObservation {
        try Self.peer(
            bootstrap: bootstrap,
            driverClaim: driverClaim,
            executableSHA256: executableSHA256,
            designatedRequirementSHA256:
                configuration.binding.machineDriver.designatedRequirementSHA256,
            codeDirectoryHash:
                configuration.binding.machineDriver.codeDirectoryHash
        )
    }

    func peer(
        mutation: ConcretePeerMutation
    ) throws -> InvestigationHandoffAppLeafPeerObservation {
        let machine = configuration.binding.machineDriver
        let executable = mutation == .executableSHA256
            ? String(repeating: "7", count: 64)
            : machine.executableSHA256
        let signing = mutation == .signingIdentifier
            ? "com.eriklee.stornaut.investigation.machine-driver.foreign"
            : machine.signingIdentifier
        let requirement = mutation == .designatedRequirementSHA256
            ? String(repeating: "8", count: 64)
            : machine.designatedRequirementSHA256
        let codeDirectory = mutation == .codeDirectoryHash
            ? String(repeating: "9", count: 64)
            : machine.codeDirectoryHash
        return try Self.peer(
            bootstrap: bootstrap,
            driverClaim: driverClaim,
            executableSHA256: executable,
            signingIdentifier: signing,
            designatedRequirementSHA256: requirement,
            codeDirectoryHash: codeDirectory
        )
    }

    func peer(
        observationMutation mutation: ConcretePeerObservationMutation
    ) throws -> InvestigationHandoffAppLeafPeerObservation {
        let baseClaim = driverClaim
        let claim = try InvestigationHandoffProcessClaim(
            processID: mutation == .claimProcessID
                ? baseClaim.processID + 1 : baseClaim.processID,
            processIDVersion: mutation == .claimProcessIDVersion
                ? baseClaim.processIDVersion + 1
                : baseClaim.processIDVersion,
            effectiveUserID: mutation == .claimEffectiveUserID
                ? baseClaim.effectiveUserID + 1
                : baseClaim.effectiveUserID,
            auditSessionID: mutation == .claimAuditSessionID
                ? baseClaim.auditSessionID + 1
                : baseClaim.auditSessionID
        )
        var words = peer.driverIdentity.auditToken.words
        switch mutation {
        case .tokenEffectiveUserID: words[1] += 1
        case .tokenProcessID: words[5] += 1
        case .tokenAuditSessionID: words[6] += 1
        case .tokenProcessIDVersion: words[7] += 1
        default: break
        }
        let identity = LifecycleProcessIdentity(
            processID: peer.driverIdentity.processID,
            processIDVersion: peer.driverIdentity.processIDVersion,
            auditSessionID: peer.driverIdentity.auditSessionID,
            effectiveUserID: mutation == .identityNotRoot
                ? 1 : peer.driverIdentity.effectiveUserID,
            auditToken: try LifecycleAuditToken(words: words)
        )
        let signing = try LifecycleBundleSigningEvidence(
            identity: peer.signingEvidence.identity,
            executableSHA256: peer.signingEvidence.executableSHA256,
            isAdHoc: mutation != .signingNotAdHoc
        )
        return InvestigationHandoffAppLeafPeerObservation(
            bootstrap: bootstrap,
            driverIdentity: identity,
            driverClaim: claim,
            signingEvidence: signing
        )
    }

    func configuration(
        mutatingBinding mutation: ConcreteBindingMutation
    ) throws -> SignedInvestigationRuntimeDiagnosticConfiguration {
        let source = configuration.binding
        let machineSource = source.machineDriver
        let machine = try SignedInvestigationRuntimeMachineDriverBinding(
            executableSHA256: mutation == .machineExecutableSHA256
                ? Self.hex(0x91, count: 64)
                : machineSource.executableSHA256,
            signingIdentifier: machineSource.signingIdentifier,
            designatedRequirementSHA256:
                mutation == .machineDesignatedRequirementSHA256
                    ? Self.hex(0x92, count: 64)
                    : machineSource.designatedRequirementSHA256,
            codeDirectoryHash: mutation == .machineCodeDirectoryHash
                ? Self.hex(0x93, count: 64)
                : machineSource.codeDirectoryHash,
            machineClaimServiceIdentifier:
                machineSource.machineClaimServiceIdentifier
        )
        func changed(
            _ field: ConcreteBindingMutation,
            original: String,
            byte: UInt8,
            count: Int = 64
        ) -> String {
            mutation == field ? Self.hex(byte, count: count) : original
        }
        let binding = SignedInvestigationRuntimeBinding(
            repositoryHEAD: changed(
                .repositoryHEAD, original: source.repositoryHEAD,
                byte: 0x81, count: 40
            ),
            sourceFingerprintSHA256: changed(
                .sourceFingerprintSHA256,
                original: source.sourceFingerprintSHA256, byte: 0x82
            ),
            appExecutableSHA256: changed(
                .appExecutableSHA256,
                original: source.appExecutableSHA256, byte: 0x83
            ),
            helperExecutableSHA256: changed(
                .helperExecutableSHA256,
                original: source.helperExecutableSHA256, byte: 0x84
            ),
            runtimeReceiptSHA256: changed(
                .runtimeReceiptSHA256,
                original: source.runtimeReceiptSHA256, byte: 0x85
            ),
            promptSHA256: changed(
                .promptSHA256, original: source.promptSHA256, byte: 0x86
            ),
            envelopeSchemaSHA256: changed(
                .envelopeSchemaSHA256,
                original: source.envelopeSchemaSHA256, byte: 0x87
            ),
            facadeSHA256: changed(
                .facadeSHA256, original: source.facadeSHA256, byte: 0x88
            ),
            codexExecutableSHA256: changed(
                .codexExecutableSHA256,
                original: source.codexExecutableSHA256, byte: 0x89
            ),
            appBundleIdentifier: source.appBundleIdentifier,
            helperServiceIdentifier: source.helperServiceIdentifier,
            machineDriver: machine
        )
        return try SignedInvestigationRuntimeDiagnosticConfiguration(
            nonce: configuration.nonce,
            scenario: configuration.scenario,
            optIn: configuration.optIn,
            diagnosticRootPath: configuration.diagnosticRootPath,
            sourceRootPath: configuration.sourceRootPath,
            supportRootPath: configuration.supportRootPath,
            runtimeRootPath: configuration.runtimeRootPath,
            reportPath: configuration.reportPath,
            storePath: configuration.storePath,
            binding: binding,
            expectedModel: configuration.expectedModel,
            expectedProvider: configuration.expectedProvider,
            validBefore: configuration.validBefore,
            maximumWallClockSeconds: configuration.maximumWallClockSeconds,
            maximumTurns: configuration.maximumTurns,
            maximumProbeCalls: configuration.maximumProbeCalls,
            maximumContextBytes: configuration.maximumContextBytes,
            now: now
        )
    }

    func handle(
        operationID: UUID,
        validBefore: Date? = nil
    ) throws -> InvestigationHandoffRetirementHandle {
        try Self.handle(
            configuration: configuration,
            configurationSHA256: configurationSHA256,
            operationID: operationID,
            validBefore: validBefore ?? now.addingTimeInterval(30)
        )
    }

    func acceptedProjection(
        configurationSHA256: String? = nil,
        runtimeReceipt: InvestigationRuntimeReceiptV1? = nil,
        epochStartedAt: Date? = nil,
        observedAt: Date? = nil
    ) throws -> InvestigationHandoffAcceptedRuntimeProjection {
        let startedAt = epochStartedAt ?? now
        return try InvestigationHandoffAcceptedRuntimeProjection(
            configuration: configuration,
            configurationSHA256: configurationSHA256
                ?? self.configurationSHA256.lowercaseHex,
            runtimeReceipt: runtimeReceipt ?? self.runtimeReceipt,
            epochValidBefore: min(
                configuration.validBefore,
                startedAt.addingTimeInterval(
                    TimeInterval(configuration.maximumWallClockSeconds)
                )
            ),
            observedAt: observedAt ?? now
        )
    }

    func incoming(
        kind: InvestigationHandoffFrameKind,
        payload: InvestigationHandoffFramePayload = .empty
    ) throws -> InvestigationHandoffFrame {
        try InvestigationHandoffFrame(
            kind: kind,
            epochUUID: bootstrap.epochUUID,
            epochDeadlineNanoseconds: bootstrap.epochDeadlineNanoseconds,
            sender: driverClaim,
            payload: payload
        )
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    static func uuid(_ byte: UInt8) throws -> UUID {
        try #require(UUID(
            uuidString: "00000000-0000-0000-0000-0000000000"
                + String(format: "%02x", byte)
        ))
    }

    private static func hex(_ byte: UInt8, count: Int) -> String {
        String(repeating: String(format: "%02x", byte), count: count / 2)
    }

    private static func claim(
        pid: UInt32, version: UInt32, uid: UInt32, asid: UInt32
    ) throws -> InvestigationHandoffProcessClaim {
        try InvestigationHandoffProcessClaim(
            processID: pid, processIDVersion: version,
            effectiveUserID: uid, auditSessionID: asid
        )
    }

    private static func peer(
        bootstrap: InvestigationHandoffEpochBootstrap,
        driverClaim: InvestigationHandoffProcessClaim,
        executableSHA256: String,
        signingIdentifier: String =
            SignedInvestigationRuntimeMachineDriverBinding
            .requiredSigningIdentifier,
        designatedRequirementSHA256: String,
        codeDirectoryHash: String
    ) throws -> InvestigationHandoffAppLeafPeerObservation {
        let identity = LifecycleProcessIdentity(
            processID: pid_t(driverClaim.processID),
            processIDVersion: Int32(driverClaim.processIDVersion),
            auditSessionID: Int32(driverClaim.auditSessionID),
            effectiveUserID: uid_t(driverClaim.effectiveUserID),
            auditToken: try LifecycleAuditToken(words: [
                0, 0, 0, 0, 0, driverClaim.processID,
                driverClaim.auditSessionID, driverClaim.processIDVersion,
            ])
        )
        let signing = try LifecycleBundleSigningEvidence(
            identity: LifecycleSigningIdentity(
                signingIdentifier: signingIdentifier,
                designatedRequirementSHA256: designatedRequirementSHA256,
                codeDirectoryHash: codeDirectoryHash
            ),
            executableSHA256: executableSHA256,
            isAdHoc: true
        )
        return InvestigationHandoffAppLeafPeerObservation(
            bootstrap: bootstrap,
            driverIdentity: identity,
            driverClaim: driverClaim,
            signingEvidence: signing
        )
    }

    private static func handle(
        configuration: SignedInvestigationRuntimeDiagnosticConfiguration,
        configurationSHA256: InvestigationHandoffSHA256,
        operationID: UUID,
        validBefore: Date
    ) throws -> InvestigationHandoffRetirementHandle {
        try InvestigationHandoffRetirementHandle(
            token: uuid(0x41),
            investigationUUID: configuration.nonce,
            retireOperationUUID: operationID,
            configurationSHA256: configurationSHA256,
            validBefore: InvestigationHandoffUTCMicroseconds(
                timeIntervalSince1970: validBefore.timeIntervalSince1970
            )
        )
    }
}

private actor SuspendedConcreteRetirementFactory {
    private let handle: InvestigationHandoffRetirementHandle
    private var continuation: CheckedContinuation<Void, Never>?
    private var waiter: CheckedContinuation<Void, Never>?

    init(handle: InvestigationHandoffRetirementHandle) { self.handle = handle }

    func run() async throws -> InvestigationHandoffRetirementHandle {
        await withCheckedContinuation {
            continuation = $0
            waiter?.resume()
            waiter = nil
        }
        return handle
    }

    func waitUntilEntered() async {
        if continuation != nil { return }
        await withCheckedContinuation { waiter = $0 }
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}

final class SequenceConcreteClock: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Date]

    init(_ values: [Date]) { self.values = values }

    func next() -> Date {
        lock.withLock {
            precondition(!values.isEmpty)
            return values.removeFirst()
        }
    }
    fileprivate func nextNanoseconds(relativeTo fixture: ConcreteHandoffFixture) -> UInt64 {
        fixture.bootstrap.epochDeadlineNanoseconds - 140_000_000_000 + UInt64(
            next().timeIntervalSince(fixture.now) * 1_000_000_000)
    }
}

final class SequenceConcreteContinuousClock: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [UInt64?]

    init(_ values: [UInt64?]) { self.values = values }

    func next() throws -> UInt64 {
        try lock.withLock {
            guard !values.isEmpty, let value = values.removeFirst() else {
                throw InvestigationHandoffConcreteAppLeafError.invalidState
            }
            return value
        }
    }
}

private func investigationHandoffTestContinuousNanoseconds() -> UInt64 {
    var timebase = mach_timebase_info_data_t()
    precondition(mach_timebase_info(&timebase) == KERN_SUCCESS)
    let product = mach_continuous_time().multipliedFullWidth(
        by: UInt64(timebase.numer)
    )
    return UInt64(timebase.denom).dividingFullWidth(product).quotient
}

private actor ConcreteFakeHandoffAdapter: InvestigationHandoffAppLeafAdapting {
    private let fixture: ConcreteHandoffFixture
    private var reads: [InvestigationHandoffFrame]
    private var writes: [InvestigationHandoffFrame] = []
    private let failPreDrop: Bool
    private(set) var didHalfClose = false

    init(fixture: ConcreteHandoffFixture, failPreDrop: Bool = false) {
        self.fixture = fixture
        self.failPreDrop = failPreDrop
        reads = [
            try! fixture.incoming(kind: .dropRelease),
            try! fixture.incoming(
                kind: .configuration,
                payload: .configuration(fixture.configurationData)
            ),
            try! fixture.incoming(
                kind: .acknowledgement,
                payload: .retirementHandleAcknowledgement(
                    InvestigationHandoffRetirementHandleAcknowledgement(
                        handleSHA256: .hashing(try! fixture.handle.encoded())
                    )
                )
            ),
            try! fixture.incoming(kind: .release),
            try! fixture.incoming(kind: .exit),
        ]
    }

    func preDropClaim() throws -> InvestigationHandoffProcessClaim {
        if failPreDrop {
            throw InvestigationHandoffConcreteAppLeafError.invalidState
        }
        return fixture.preDropClaim
    }

    func readFrame() throws -> InvestigationHandoffFrame {
        guard !reads.isEmpty else {
            throw InvestigationHandoffConcreteAppLeafError.invalidState
        }
        return reads.removeFirst()
    }

    func writeFrame(_ frame: InvestigationHandoffFrame) { writes.append(frame) }

    func performIdentityDrop() throws -> InvestigationHandoffAppLeafDropResult {
        try InvestigationHandoffAppLeafDropResult(
            processClaim: fixture.postDropClaim,
            evidence: fixture.dropEvidence
        )
    }

    func halfCloseWrite() { didHalfClose = true }

    func writtenKinds() -> [InvestigationHandoffFrameKind] { writes.map(\.kind) }
}

private actor ConcreteRetirementProbe {
    let handle: InvestigationHandoffRetirementHandle
    private(set) var callCount = 0
    private(set) var projection: InvestigationHandoffAcceptedRuntimeProjection?

    init(handle: InvestigationHandoffRetirementHandle) { self.handle = handle }

    func record(_ projection: InvestigationHandoffAcceptedRuntimeProjection) {
        callCount += 1
        self.projection = projection
    }
}

private final class ConcreteOperationIDProvider: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [UUID]

    init(_ values: [UUID]) { self.values = values }

    func next() throws -> UUID {
        try lock.withLock {
            guard !values.isEmpty else {
                throw InvestigationHandoffConcreteAppLeafError.invalidState
            }
            return values.removeFirst()
        }
    }
}

private actor ConcreteLifecycleSession:
    LifecycleInteractiveSessionEvidenceSending
{
    private let fixture: ConcreteHandoffFixture
    private let operationIDs: [UUID]
    private var peer: LifecycleConnectedHelperPeer?
    private(set) var requests: [LifecycleInteractiveSessionRequest] = []

    init(fixture: ConcreteHandoffFixture, operationIDs: [UUID]) {
        self.fixture = fixture
        self.operationIDs = operationIDs
    }

    func freshAttestedHelperPeer() throws -> LifecycleConnectedHelperPeer {
        let identity = LifecycleProcessIdentity(
            processID: 702, processIDVersion: 12, auditSessionID: 33_001,
            effectiveUserID: 0,
            auditToken: try LifecycleAuditToken(words: [
                0, 0, 0, 0, 0, 702, 33_001, 12,
            ])
        )
        let value = LifecycleConnectedHelperPeer(
            identity: identity, attestedAt: fixture.now
        )
        peer = value
        return value
    }

    func takeRetirementHelperPeer(
        operationID _: UUID
    ) -> LifecycleConnectedHelperPeer? {
        defer { peer = nil }
        return peer
    }

    func send(
        _ request: LifecycleInteractiveSessionRequest
    ) throws -> LifecycleInteractiveSessionResponse {
        requests.append(request)
        switch request.kind {
        case .start:
            return try .started(
                investigationID: LifecycleInvestigationID(
                    rawValue: fixture.configuration.nonce
                ),
                operationID: operationIDs[0],
                codexExecutableSHA256: try #require(
                    request.codexExecutableSHA256
                )
            )
        case .retire:
            _ = try freshAttestedHelperPeer()
            let investigationID = LifecycleInvestigationID(
                rawValue: fixture.configuration.nonce
            )
            return .retired(
                investigationID: investigationID,
                operationID: operationIDs[1],
                drained: true,
                ownerRetirementObservation: .retiredOwnedResources,
                machineRetirementHandle: try LifecycleMachineRetirementHandle(
                    token: fixture.handle.token,
                    investigationID: investigationID,
                    retireOperationID: operationIDs[1],
                    configurationSHA256: fixture.configurationSHA256.lowercaseHex,
                    validBefore: fixture.now.addingTimeInterval(30)
                ),
                residueObservation: try LifecycleInvestigationResidueObservation(
                    investigationID: investigationID,
                    auditSessionID: 44_001,
                    userID: 501,
                    observedAt: fixture.now,
                    remainingAuditSessionMemberCount: 0,
                    matchingLeaseCount: 0,
                    leaseRootEntryCount: 0,
                    investigationArtifactCount: 0
                )
            )
        case .write, .read:
            throw InvestigationHandoffConcreteAppLeafError.invalidState
        }
    }
}
