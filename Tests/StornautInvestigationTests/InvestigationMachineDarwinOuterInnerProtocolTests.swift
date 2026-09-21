import Foundation
import Testing

@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationInstalledL2
@testable import StornautInvestigationMachineDriverSupport

@Suite("Investigation machine Darwin outer-inner protocol", .serialized)
struct InvestigationMachineDarwinOuterInnerProtocolTests {
    @Test(arguments: InvestigationHandoffScenario.allCases)
    func canonicalMessagesRoundTripAllEightScenariosAndRejectWireMutation(
        _ scenario: InvestigationHandoffScenario
    ) throws {
        let fixture = try OuterInnerFixture(scenario: scenario)
        let selfDecoded = try InvestigationMachineDarwinEpochRequest
            .decodeUntrusted(fixture.request.encoded())
        #expect(selfDecoded == fixture.request)
        #expect(selfDecoded.invocation.selection == fixture.selection)
        #expect(try selfDecoded.encoded() == fixture.request.encoded())
        let foreign = try OuterInnerFixture(
            scenario: scenario,
            configuration: Data("foreign-\(scenario.rawValue)".utf8)
        )
        let foreignBytes = try foreign.request.encoded()
        #expect(
            try InvestigationMachineDarwinEpochRequest.decodeUntrusted(
                foreignBytes
            ) == foreign.request
        )
        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineDarwinEpochRequest.decode(
                foreignBytes, expectedSelection: fixture.selection
            )
        }
        for mutation in try strictUntrustedRequestMutations(
            fixture.request.encoded()
        ) {
            #expect(throws: (any Error).self) {
                _ = try InvestigationMachineDarwinEpochRequest
                    .decodeUntrusted(mutation)
            }
        }
        var values: [(Data, (Data) throws -> Void)] = [
            (try fixture.request.encoded(), {
                _ = try InvestigationMachineDarwinEpochRequest.decode(
                    $0, expectedSelection: fixture.selection
                )
            }),
            (try fixture.physicalOwnership.encoded(), {
                _ = try InvestigationMachineSingleEpochPhysicalOwnership.decode(
                    $0, expectedSelection: fixture.selection
                )
            }),
            (try fixture.ownershipRecord.encoded(), {
                _ = try InvestigationMachineDarwinEpochOwnershipRecord.decode($0)
            }),
            (try fixture.acknowledgement.encoded(), {
                _ = try InvestigationMachineDarwinEpochAcknowledgement.decode($0)
            }),
            (try fixture.decision.encoded(), {
                _ = try InvestigationMachineDarwinEpochDecision.decode($0)
            }),
        ]
        if scenario != .lifecycleRecovery {
            let normalResult = try InvestigationMachineDarwinEpochNormalResult(
                request: fixture.request, ownership: fixture.ownershipRecord,
                acknowledgement: fixture.acknowledgement,
                decision: fixture.decision,
                physicalResult: fixture.physicalResult()
            )
            values.append((try normalResult.encoded(), {
                _ = try InvestigationMachineDarwinEpochNormalResult.decode(
                    $0, expectedSelection: fixture.selection
                )
            }))
        }

        for (encoded, decode) in values {
            try decode(encoded)
            for mutation in strictProtocolMutations(encoded) {
                #expect(throws: (any Error).self) { try decode(mutation) }
            }
        }
        #expect(
            fixture.request.mode
                == (scenario == .lifecycleRecovery ? .parentCrash : .normal)
        )
        #expect(!(InvestigationMachineDarwinEpochRequest.self is any Codable.Type))
        #expect(!(InvestigationMachineSingleEpochPhysicalOwnership.self
            is any Codable.Type))
        #expect(!(InvestigationMachineDarwinEpochOwnershipRecord.self
            is any Codable.Type))
        #expect(!(InvestigationMachineDarwinEpochAcknowledgement.self
            is any Codable.Type))
        #expect(!(InvestigationMachineDarwinEpochDecision.self
            is any Codable.Type))
        #expect(!(InvestigationMachineDarwinEpochNormalResult.self
            is any Codable.Type))
        #expect(!(InvestigationMachineSingleEpochAdmittedPhysicalResult.self
            is any Codable.Type))
        #expect(!(InvestigationMachineDarwinEpochTerminalEvidence.self
            is any Codable.Type))
    }

    @Test
    func innerAndOuterStateRequireOwnershipAcknowledgementDecisionOrderAndRejectReplay() async throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let invalidInner = InvestigationMachineDarwinInnerProtocolState(
            selection: fixture.selection
        )
        await #expect(throws: (any Error).self) {
            try await invalidInner.accept(fixture.acknowledgement)
        }
        await #expect(throws: (any Error).self) {
            try await invalidInner.accept(
                fixture.request, observedAtNanoseconds: fixture.observedAt
            )
        }

        let invalidOuter = fixture.makeOuterAdmission()
        await #expect(throws: (any Error).self) {
            _ = try await invalidOuter.acceptOwnership(
                fixture.ownershipRecord,
                observedDriverChild: fixture.driverChild,
                observedAppChild: fixture.appChild
            )
        }
        await #expect(throws: (any Error).self) {
            try await invalidOuter.accept(fixture.request)
        }

        let concurrentOuter = fixture.makeOuterAdmission()
        async let first = acceptsRequest(concurrentOuter, fixture.request)
        async let second = acceptsRequest(concurrentOuter, fixture.request)
        #expect(await [first, second].filter { $0 }.count == 1)
        await #expect(throws: (any Error).self) {
            _ = try await concurrentOuter.acceptOwnership(
                fixture.ownershipRecord,
                observedDriverChild: fixture.driverChild,
                observedAppChild: fixture.appChild
            )
        }

        let inner = InvestigationMachineDarwinInnerProtocolState(
            selection: fixture.selection
        )
        try await inner.accept(
            fixture.request, observedAtNanoseconds: fixture.observedAt
        )
        #expect(try await inner.emit(fixture.ownershipRecord)
            == fixture.ownershipRecord)
        try await inner.accept(fixture.acknowledgement)
        try await inner.accept(fixture.decision)
        #expect(try await inner.finish(fixture.physicalResult()).physicalResult
            == fixture.physicalResult())
    }

    @Test
    func outerAdmissionRequiresIndependentDriverAndAppTopology() async throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let valid = fixture.makeOuterAdmission()
        try await valid.accept(fixture.request)
        #expect(try await valid.acceptOwnership(
            fixture.ownershipRecord,
            observedDriverChild: fixture.driverChild,
            observedAppChild: fixture.appChild
        ) == fixture.acknowledgement)

        let invalid = fixture.makeOuterAdmission()
        try await invalid.accept(fixture.request)
        await #expect(throws: (any Error).self) {
            _ = try await invalid.acceptOwnership(
                fixture.ownershipRecord,
                observedDriverChild: try fixture.driverChild(
                    parentProcessID: fixture.outerProcessID + 1
                ),
                observedAppChild: try fixture.appChild(
                    processGroupID: fixture.driverChild.processGroupID + 1
                )
            )
        }
        await #expect(throws: (any Error).self) {
            _ = try await invalid.acceptOwnership(
                fixture.ownershipRecord,
                observedDriverChild: fixture.driverChild,
                observedAppChild: fixture.appChild
            )
        }
    }

    @Test
    func normalAndParentCrashTerminalEvidenceMintOpaqueResultAndProveOnce() async throws {
        let normal = try OuterInnerFixture(scenario: .success)
        let normalOuter = normal.makeOuterAdmission()
        let normalExchange = try await completeExchange(normal, normalOuter)
        let normalResult = try InvestigationMachineDarwinEpochNormalResult(
            request: normal.request, ownership: normal.ownershipRecord,
            acknowledgement: normalExchange.acknowledgement,
            decision: normalExchange.decision,
            physicalResult: normal.physicalResult())
        let admitted = try await normalOuter.admit(
            resultBytes: normalResult.encoded(),
            terminalEvidence: try normal.terminalEvidence(successfulExit: true))
        guard case .admittedPhysical = admitted else {
            Issue.record("expected opaque admitted physical result")
            return
        }
        let predecessor = try #require(normal.predecessor)
        let prover: any InvestigationMachineOuterContainmentProving = normalOuter
        guard case .contained = await prover.proveContainment(
            selection: normal.selection, result: admitted,
            predecessor: predecessor
        ) else {
            Issue.record("expected one containment proof")
            return
        }
        #expect(await prover.proveContainment(
            selection: normal.selection, result: admitted,
            predecessor: predecessor
        ) == .terminalUncertain)

        let joined = try OuterInnerFixture(scenario: .success)
        let joinedOuter = joined.makeOuterAdmission()
        let joinedExchange = try await completeExchange(joined, joinedOuter)
        let joinedWire = try InvestigationMachineDarwinEpochNormalResult(
            request: joined.request, ownership: joined.ownershipRecord,
            acknowledgement: joinedExchange.acknowledgement,
            decision: joinedExchange.decision,
            physicalResult: joined.physicalResult()
        )
        let joinedResult = try await joinedOuter.admit(
            resultBytes: joinedWire.encoded(),
            terminalEvidence: try joined.terminalEvidence(
                successfulExit: true
            )
        )
        let joinedPredecessor = try #require(joined.predecessor)
        let continuity = try await InvestigationMachineOuterCompletionJoin(
            prover: joinedOuter
        ).seal(
            selection: joined.selection, result: joinedResult,
            predecessor: joinedPredecessor
        )
        let successor = try OuterInnerFixture(scenario: .cancellation)
        #expect(try continuity.consume(for: successor.selection)
            .previousHelperIdentity == joined.physicalOwnership.helperIdentity)

        let crash = try OuterInnerFixture(scenario: .lifecycleRecovery)
        let crashOuter = crash.makeOuterAdmission()
        _ = try await completeExchange(crash, crashOuter)
        let crashResult = try await crashOuter.admit(
            resultBytes: Data(),
            terminalEvidence: try crash.terminalEvidence(successfulExit: false))
        guard case .admittedPhysical = crashResult else {
            Issue.record("expected opaque parent-crash result")
            return
        }

        let invalidCrash = crash.makeOuterAdmission()
        _ = try await completeExchange(crash, invalidCrash)
        await #expect(throws: (any Error).self) {
            _ = try await invalidCrash.admit(
                resultBytes: Data([0x01]),
                terminalEvidence: try crash.terminalEvidence(
                    successfulExit: false))
        }
    }

    @Test
    func failedContainmentProofConsumesAdmissionBeforeCorrectReplay() async throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let admission = fixture.makeOuterAdmission()
        let exchange = try await completeExchange(fixture, admission)
        let wire = try InvestigationMachineDarwinEpochNormalResult(
            request: fixture.request, ownership: fixture.ownershipRecord,
            acknowledgement: exchange.acknowledgement,
            decision: exchange.decision, physicalResult: fixture.physicalResult())
        let result = try await admission.admit(
            resultBytes: wire.encoded(),
            terminalEvidence: fixture.terminalEvidence(successfulExit: true))
        let predecessor = try #require(fixture.predecessor)
        let wrong = try OuterInnerFixture(scenario: .cancellation)
        #expect(await admission.proveContainment(selection: wrong.selection,
            result: result, predecessor: predecessor) == .terminalUncertain)
        #expect(await admission.proveContainment(selection: fixture.selection,
            result: result, predecessor: predecessor) == .terminalUncertain)
    }

    @Test
    func innerDeadlineValidationPreservesExactRequestDeadlineAndRejectsBounds() async throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let exact = InvestigationMachineDarwinInnerProtocolState(
            selection: fixture.selection
        )
        try await exact.accept(
            fixture.request, observedAtNanoseconds: fixture.observedAt
        )
        _ = try await exact.emit(fixture.ownershipRecord)
        #expect(fixture.physicalOwnership.epochDeadlineNanoseconds
            == fixture.request.epochDeadlineNanoseconds)

        for deadline in [
            fixture.observedAt,
            fixture.observedAt + 140_000_000_001,
        ] {
            let state = InvestigationMachineDarwinInnerProtocolState(
                selection: fixture.selection
            )
            let request = try InvestigationMachineDarwinEpochRequest(
                invocation: fixture.invocation,
                epochDeadlineNanoseconds: deadline)
            await #expect(throws: (any Error).self) {
                try await state.accept(
                    request, observedAtNanoseconds: fixture.observedAt
                )
            }
        }
    }

    @Test
    func physicalComposerUsesTheExactOuterDeadline() async throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let composer = DeadlineCapturingPhysicalComposer(
            selection: fixture.selection
        )
        let state = InvestigationMachineDarwinInnerProtocolState(
            selection: fixture.selection
        )

        _ = try? await state.run(
            composer: composer, request: fixture.request,
            observedAtNanoseconds: fixture.observedAt
        )

        #expect(composer.deadlines == [fixture.request.epochDeadlineNanoseconds])
        #expect(composer.invocations == [fixture.invocation])
        await #expect(throws: (any Error).self) {
            try await state.accept(
                fixture.request, observedAtNanoseconds: fixture.observedAt
            )
        }
    }

    @Test(arguments: TerminalEvidenceMutation.allCases)
    fileprivate func terminalEvidenceMustBindEveryExternalObservation(
        _ mutation: TerminalEvidenceMutation
    ) async throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let admission = fixture.makeOuterAdmission()
        let exchange = try await completeExchange(fixture, admission)
        let normal = try InvestigationMachineDarwinEpochNormalResult(
            request: fixture.request, ownership: fixture.ownershipRecord,
            acknowledgement: exchange.acknowledgement,
            decision: exchange.decision,
            physicalResult: fixture.physicalResult()
        )
        await #expect(throws: (any Error).self) {
            _ = try await admission.admit(
                resultBytes: normal.encoded(),
                terminalEvidence: try fixture.terminalEvidence(
                    successfulExit: true, mutation: mutation
                )
            )
        }
    }

    @Test
    func outerAdmissionSamplesDeadlineInsideTheMintingCriticalSection() async throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let rejectedClock = FixedOuterInnerProtocolClock(
            now: fixture.request.epochDeadlineNanoseconds
        )
        let admission = fixture.makeOuterAdmission(clock: rejectedClock)
        let exchange = try await completeExchange(fixture, admission)
        let normal = try InvestigationMachineDarwinEpochNormalResult(
            request: fixture.request, ownership: fixture.ownershipRecord,
            acknowledgement: exchange.acknowledgement,
            decision: exchange.decision, physicalResult: fixture.physicalResult()
        )
        await #expect(throws:
            InvestigationMachineDarwinOuterInnerProtocolError
                .terminalEvidenceInvalid
        ) {
            _ = try await admission.admit(
                resultBytes: normal.encoded(),
                terminalEvidence: try fixture.terminalEvidence(
                    successfulExit: true
                )
            )
        }
        #expect(rejectedClock.calls == 1)

        let invalidClock = FixedOuterInnerProtocolClock(
            now: fixture.observedAt + 2
        )
        let invalidAdmission = fixture.makeOuterAdmission(clock: invalidClock)
        _ = try await completeExchange(fixture, invalidAdmission)
        await #expect(throws:
            InvestigationMachineDarwinOuterInnerProtocolError.invalidValue
        ) {
            _ = try await invalidAdmission.admit(
                resultBytes: Data([0x00]),
                terminalEvidence: try fixture.terminalEvidence(
                    successfulExit: true
                )
            )
        }
        #expect(invalidClock.calls == 0)

        let cancellationClock = CancellingOuterInnerProtocolClock(
            now: fixture.observedAt + 2
        )
        let cancelledAdmission = InvestigationMachineDarwinOuterAdmission(
            selection: fixture.selection,
            outerProcessID: fixture.outerProcessID,
            clock: cancellationClock
        )
        let cancelledExchange = try await completeExchange(
            fixture, cancelledAdmission
        )
        let cancelledNormal = try InvestigationMachineDarwinEpochNormalResult(
            request: fixture.request, ownership: fixture.ownershipRecord,
            acknowledgement: cancelledExchange.acknowledgement,
            decision: cancelledExchange.decision,
            physicalResult: fixture.physicalResult()
        )
        let cancelled = Task {
            try await cancelledAdmission.admit(
                resultBytes: cancelledNormal.encoded(),
                terminalEvidence: try fixture.terminalEvidence(
                    successfulExit: true
                )
            )
        }
        await #expect(throws:
            InvestigationMachineDarwinOuterInnerProtocolError
                .terminalEvidenceInvalid
        ) {
            _ = try await cancelled.value
        }
    }

    @Test(arguments: [
        TerminalEvidenceMutation.controlEOF,
        .resultEOF, .appPresent, .leaderNotLast, .groupNotEmpty,
        .helperPresent, .l1Residue, .driverDrift, .expired,
    ])
    fileprivate func parentCrashAlsoRequiresEveryAbsenceAndEOFProof(
        _ mutation: TerminalEvidenceMutation
    ) async throws {
        let fixture = try OuterInnerFixture(scenario: .lifecycleRecovery)
        let admission = fixture.makeOuterAdmission()
        _ = try await completeExchange(fixture, admission)
        await #expect(throws: (any Error).self) {
            _ = try await admission.admit(
                resultBytes: Data(),
                terminalEvidence: try fixture.terminalEvidence(
                    successfulExit: false, mutation: mutation
                )
            )
        }
    }

    @Test
    func normalResultWireIsBoundToTheExactOwnershipRecord() async throws {
        let first = try OuterInnerFixture(scenario: .success)
        let firstAdmission = first.makeOuterAdmission()
        let firstExchange = try await completeExchange(first, firstAdmission)
        let mismatched = try InvestigationMachineDarwinEpochNormalResult(
            request: first.request, ownership: first.ownershipRecord,
            acknowledgement: firstExchange.acknowledgement,
            decision: firstExchange.decision,
            physicalResult: first.physicalResult()
        )
        let secondDriver = try first.driverChild(
            processID: first.driverChild.processID + 10,
            processIDVersion: first.driverChild.processIDVersion + 10
        )
        let secondApp = try first.appChild(
            parentProcessID: secondDriver.processID,
            processGroupID: secondDriver.processGroupID
        )
        let secondOwnership = try InvestigationMachineDarwinEpochOwnershipRecord(
            request: first.request, driverChild: secondDriver,
            appChild: secondApp, physicalOwnership: first.physicalOwnership
        )
        let secondAdmission = first.makeOuterAdmission()
        try await secondAdmission.accept(first.request)
        let secondAcknowledgement = try await secondAdmission.acceptOwnership(
            secondOwnership, observedDriverChild: secondDriver,
            observedAppChild: secondApp
        )
        _ = try await secondAdmission.issueDecision(secondAcknowledgement)
        await #expect(throws: (any Error).self) {
            _ = try await secondAdmission.admit(
                resultBytes: mismatched.encoded(),
                terminalEvidence: try first.terminalEvidence(
                    successfulExit: true, driverChild: secondDriver,
                    appChild: secondApp
                )
            )
        }
    }

    @Test
    func maximumConfigurationAdmitsOnceWithoutTranscriptOverflow() async throws {
        let fixture = try OuterInnerFixture(
            scenario: .success,
            configuration: Data(
                repeating: 0xab,
                count: InvestigationCohortEpoch.maximumConfigurationByteCount
            )
        )
        let admission = fixture.makeOuterAdmission()
        let exchange = try await completeExchange(fixture, admission)
        let wire = try InvestigationMachineDarwinEpochNormalResult(
            request: fixture.request, ownership: fixture.ownershipRecord,
            acknowledgement: exchange.acknowledgement,
            decision: exchange.decision,
            physicalResult: fixture.physicalResult()
        )

        let result = try await admission.admit(
            resultBytes: wire.encoded(),
            terminalEvidence: try fixture.terminalEvidence(successfulExit: true)
        )
        guard case .admittedPhysical = result else {
            Issue.record("expected maximum configuration admission")
            return
        }
        await #expect(throws: (any Error).self) {
            _ = try await admission.admit(
                resultBytes: wire.encoded(),
                terminalEvidence: try fixture.terminalEvidence(
                    successfulExit: true
                )
            )
        }
    }

    @Test
    func concurrentInvalidTransitionRevokesSuspendedInnerRun() async throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let admission = fixture.makeOuterAdmission()
        let exchange = try await completeExchange(fixture, admission)
        let wire = try InvestigationMachineDarwinEpochNormalResult(
            request: fixture.request, ownership: fixture.ownershipRecord,
            acknowledgement: exchange.acknowledgement,
            decision: exchange.decision,
            physicalResult: fixture.physicalResult()
        )
        let result = try await admission.admit(
            resultBytes: wire.encoded(),
            terminalEvidence: try fixture.terminalEvidence(successfulExit: true)
        )
        let validComposer = SuspendedPhysicalComposer(
            selection: fixture.selection, result: result
        )
        let validInner = InvestigationMachineDarwinInnerProtocolState(
            selection: fixture.selection
        )
        let validRun = Task {
            try await validInner.run(
                composer: validComposer, request: fixture.request,
                observedAtNanoseconds: fixture.observedAt
            )
        }
        await validComposer.waitUntilStarted()
        _ = try await validInner.emit(fixture.ownershipRecord)
        try await validInner.accept(fixture.acknowledgement)
        try await validInner.accept(fixture.decision)
        await validComposer.release()
        #expect(try await validRun.value == result)

        let invalidComposer = SuspendedPhysicalComposer(
            selection: fixture.selection, result: result
        )
        let invalidInner = InvestigationMachineDarwinInnerProtocolState(
            selection: fixture.selection
        )
        let run = Task {
            try await invalidInner.run(
                composer: invalidComposer, request: fixture.request,
                observedAtNanoseconds: fixture.observedAt
            )
        }
        await invalidComposer.waitUntilStarted()
        _ = try await invalidInner.emit(fixture.ownershipRecord)
        try await invalidInner.accept(fixture.acknowledgement)
        try await invalidInner.accept(fixture.decision)
        await #expect(throws: (any Error).self) {
            try await invalidInner.accept(fixture.decision)
        }
        await invalidComposer.release()
        await #expect(throws: (any Error).self) { _ = try await run.value }
    }

    @Test
    func admittedResultRejectsForeignGenericContainmentProver() async throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let admission = fixture.makeOuterAdmission()
        let exchange = try await completeExchange(fixture, admission)
        let wire = try InvestigationMachineDarwinEpochNormalResult(
            request: fixture.request, ownership: fixture.ownershipRecord,
            acknowledgement: exchange.acknowledgement,
            decision: exchange.decision,
            physicalResult: fixture.physicalResult()
        )
        let result = try await admission.admit(
            resultBytes: wire.encoded(),
            terminalEvidence: try fixture.terminalEvidence(successfulExit: true)
        )
        let predecessor = try #require(fixture.predecessor)
        await #expect(throws:
            InvestigationMachineHelperEpochContinuityError.containmentUncertain
        ) {
            _ = try await InvestigationMachineOuterCompletionJoin(
                prover: ForeignAdmittedResultProver()
            ).seal(
                selection: fixture.selection, result: result,
                predecessor: predecessor
            )
        }
    }

    @Test(arguments: [InvestigationHandoffScenario.success, .lifecycleRecovery])
    func validEpochEvidenceRoundTripsWithIndependentlyRecomputedAdmission(
        _ scenario: InvestigationHandoffScenario) throws {
        let fixture = try OuterInnerFixture(scenario: scenario)
        let wire = try makeEpochEvidence(fixture: fixture)
        let epoch = try OuterInnerWireTranscript(wire)
        let physical = try OuterInnerWireTranscript(epoch.fields[5])
        let ownership = try InvestigationMachineSingleEpochPhysicalOwnership
            .decodeEvidence(physical.fields[0], expectedSelection: fixture.selection)
        #expect(try InvestigationMachineDarwinEpochTerminalEvidence.decode(
            epoch.fields[6]) == fixture.terminalEvidence(successfulExit:
                scenario != .lifecycleRecovery))
        if scenario == .lifecycleRecovery {
            #expect(physical.fields.count == 1)
        } else {
            #expect(try InvestigationMachineDarwinEpochNormalResult.decode(
                physical.fields[1], expectedSelection: fixture.selection)
                .physicalResult.physicalOwnership == ownership)
        }
        #expect(InvestigationHandoffSHA256.hashing(
            try independentlyRecomputedAdmissionTranscript(
                requestBytes: epoch.fields[4],
                resultBytes: scenario == .lifecycleRecovery ? Data() : physical.fields[1],
                terminalEvidenceBytes: epoch.fields[6],
                admissionMaterialBytes: epoch.fields[7])).rawBytes == epoch.fields[8])
        let decoded = try InvestigationMachineEpochEvidence.decode(wire)
        #expect(decoded.ordinal == fixture.selection.epoch.ordinal)
        #expect(decoded.scenario == fixture.selection.epoch.scenario)
        #expect(try decoded.encoded() == wire)
    }

    @Test
    func epochEvidenceRejectsZeroClaimRequestBinding() throws {
        let fixture = try OuterInnerFixture(
            scenario: .success, claimRequestBindingSHA256:
                .init(rawBytes: Data(repeating: 0, count: 32)))
        let wire = try makeEpochEvidence(fixture: fixture)
        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineEpochEvidence.decode(wire)
        }
    }

    @Test(arguments: EpochEvidenceMutation.allCases)
    fileprivate func epochEvidenceRejectsSemanticallyRewrappedMutation(
        _ mutation: EpochEvidenceMutation) throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let wire = try makeEpochEvidence(fixture: fixture, mutation: mutation)
        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineEpochEvidence.decode(wire)
        }
    }

    @Test
    func failedDeadlineAdmissionDoesNotCommitEpochEvidence() async throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        try InvestigationMachineEpochEvidenceCollection.begin(attemptUUID:
            fixture.selection.outerAttemptUUID)
        defer { InvestigationMachineEpochEvidenceCollection.abort() }
        let admission = fixture.makeOuterAdmission(clock: FixedOuterInnerProtocolClock(
            now: fixture.request.epochDeadlineNanoseconds))
        let exchange = try await completeExchange(fixture, admission)
        let normal = try InvestigationMachineDarwinEpochNormalResult(
            request: fixture.request, ownership: fixture.ownershipRecord,
            acknowledgement: exchange.acknowledgement,
            decision: exchange.decision, physicalResult: fixture.physicalResult())
        await #expect(throws:
            InvestigationMachineDarwinOuterInnerProtocolError.terminalEvidenceInvalid) {
            _ = try await admission.admit(
                resultBytes: normal.encoded(),
                terminalEvidence: fixture.terminalEvidence(successfulExit: true))
        }
        let retry = fixture.makeOuterAdmission()
        let retryExchange = try await completeExchange(fixture, retry)
        let retryNormal = try InvestigationMachineDarwinEpochNormalResult(
            request: fixture.request, ownership: fixture.ownershipRecord,
            acknowledgement: retryExchange.acknowledgement,
            decision: retryExchange.decision, physicalResult: fixture.physicalResult())
        let result = try await retry.admit(
            resultBytes: retryNormal.encoded(),
            terminalEvidence: fixture.terminalEvidence(successfulExit: true))
        guard case .admittedPhysical = result else {
            Issue.record("expected retry to commit the first epoch")
            return
        }
    }

    @Test
    func validEightEpochEvidenceBundleRoundTrips() async throws {
        let bundle = try await makeEpochEvidenceBundle()
        #expect(try InvestigationMachineEpochEvidenceBundle.decode(bundle).encoded() == bundle)
    }

    @Test(arguments: EpochBundleMutation.allCases)
    fileprivate func bundleRejectsCanonicalCohortOrContinuityRewrap(
        _ mutation: EpochBundleMutation) async throws {
        let bundle = try await makeEpochEvidenceBundle(mutation: mutation)
        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineEpochEvidenceBundle.decode(bundle)
        }
    }
}

private enum TerminalEvidenceMutation: CaseIterable {
    case controlEOF, resultEOF, driverIdentity, appIdentity, helperIdentity
    case appPresent, leaderNotLast, groupNotEmpty, helperPresent, l1Residue
    case driverDrift, driverResultMismatch, expired
}

private enum EpochEvidenceMutation: CaseIterable {
    case admissionDigest, admissionSubchain, terminalHelper, residueFalse, driverObservationDrift, normalResultObservation
}
private enum EpochBundleMutation: CaseIterable {
    case requestWholeCapsule, requestWholeInput, successorPredecessorDigest, repeatedHelper
}
private func makeEpochEvidence(fixture: OuterInnerFixture,
    mutation: EpochEvidenceMutation? = nil) throws -> Data {
    let requestBytes = try fixture.request.encoded()
    let resultBytes: Data
    if fixture.request.mode == .normal {
        let physicalResult = try fixture.physicalResult(
            driverObservationSHA256: mutation == .normalResultObservation
                ? OuterInnerFixture.digest(0x71) : nil)
        resultBytes = try InvestigationMachineDarwinEpochNormalResult(
            request: fixture.request, ownership: fixture.ownershipRecord,
            acknowledgement: fixture.acknowledgement, decision: fixture.decision,
            physicalResult: physicalResult).encoded()
    } else {
        resultBytes = Data()
    }
    let terminalMutation: TerminalEvidenceMutation? = switch mutation {
    case .terminalHelper: .helperIdentity
    case .residueFalse: .l1Residue
    case .driverObservationDrift: .driverDrift
    default: nil
    }
    let terminalBytes = try fixture.terminalEvidence(
        successfulExit: fixture.request.mode == .normal,
        mutation: terminalMutation).encoded()
    let owner = UUID(uuid: (0xa1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    var materialBytes = try InvestigationMachineEpochAdmissionMaterial(
        request: fixture.request, ownership: fixture.ownershipRecord,
        acknowledgement: fixture.acknowledgement, decision: fixture.decision,
        owner: owner).encoded()
    if mutation == .admissionSubchain {
        var material = try OuterInnerWireTranscript(materialBytes)
        let driver = try fixture.driverChild(
            processID: fixture.driverChild.processID + 10,
            processIDVersion: fixture.driverChild.processIDVersion + 10)
        let app = try fixture.appChild(
            parentProcessID: driver.processID,
            processGroupID: driver.processGroupID)
        let ownership = try InvestigationMachineDarwinEpochOwnershipRecord(
            request: fixture.request, driverChild: driver, appChild: app,
            physicalOwnership: fixture.physicalOwnership)
        material.fields[0] = try ownership.encoded()
        materialBytes = try material.encoded(
            maximumByteCount:
                InvestigationMachineEpochAdmissionMaterial.maximumByteCount)
    }
    let ownershipBytes = try fixture.physicalOwnership.evidenceEncoded()
    let physicalBytes = try HandoffBinaryTranscript.encode(
        domain: "stornaut.task39.machine.epoch-physical-evidence.v1",
        businessFields: fixture.request.mode == .normal
            ? [ownershipBytes, resultBytes] : [ownershipBytes],
        maximumByteCount: 64 * 1_024)
    var admissionSHA256 = try independentlyRecomputedAdmissionSHA256(
        requestBytes: requestBytes, resultBytes: resultBytes,
        terminalEvidenceBytes: terminalBytes,
        admissionMaterialBytes: materialBytes)
    if mutation == .admissionDigest {
        var changed = admissionSHA256.rawBytes
        changed[changed.startIndex] ^= 0x01
        admissionSHA256 = try InvestigationHandoffSHA256(rawBytes: changed)
    }
    return try HandoffBinaryTranscript.encode(
        domain: "stornaut.task39.machine.epoch-evidence.v1",
        businessFields: [
            outerInnerData(fixture.selection.epoch.ordinal),
            outerInnerData(fixture.selection.epoch.scenario.rawValue),
            outerInnerData(fixture.selection.epoch.epochUUID),
            outerInnerData(fixture.selection.epoch.configurationNonce),
            requestBytes, physicalBytes, terminalBytes, materialBytes,
            admissionSHA256.rawBytes,
        ], maximumByteCount: InvestigationMachineEpochEvidence.maximumByteCount)
}
private func makeEpochEvidenceBundle(
    mutation: EpochBundleMutation? = nil) async throws -> Data {
    let attempt = UUID(uuid: (0xb1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    let templates = try InvestigationHandoffScenario.allCases.map {
        try OuterInnerFixture(scenario: $0) }
    let capsule = try InvestigationCohortCapsule(
        outerAttemptUUID: attempt, epochs: templates.map { $0.selection.epoch })
    let projected = try InvestigationProjectedCohortInput(
        capsule: capsule,
        projections: templates.map { $0.selection.projection })
    try InvestigationMachineEpochEvidenceCollection.begin(attemptUUID: attempt)
    defer { InvestigationMachineEpochEvidenceCollection.abort() }
    var continuity: InvestigationMachineHelperEpochContinuity?
    for index in templates.indices {
        let projectedSelection = try projected.selection(at: index)
        let selection = InvestigationMachineFixedEpochSelection(
            outerAttemptUUID: attempt,
            wholeCapsuleSHA256: capsule.wholeCapsuleSHA256,
            wholeInputSHA256: projected.wholeInputSHA256,
            epoch: projectedSelection.epoch,
            projection: projectedSelection.projection)
        let current = try continuity
            ?? InvestigationMachineHelperEpochContinuity.genesis(for: selection)
        let predecessor = try current.consume(for: selection)
        let invocation = try predecessor.invocation(for: selection)
        let fixture = try OuterInnerFixture(
            selection: selection, invocation: invocation,
            predecessor: predecessor, identityIndex: UInt32(index))
        let admission = fixture.makeOuterAdmission()
        let exchange = try await completeExchange(fixture, admission)
        let resultBytes: Data
        if fixture.request.mode == .normal {
            resultBytes = try InvestigationMachineDarwinEpochNormalResult(
                request: fixture.request, ownership: fixture.ownershipRecord,
                acknowledgement: exchange.acknowledgement,
                decision: exchange.decision,
                physicalResult: fixture.physicalResult()).encoded()
        } else {
            resultBytes = Data()
        }
        let result = try await admission.admit(
            resultBytes: resultBytes, terminalEvidence: fixture.terminalEvidence(
                successfulExit: fixture.request.mode == .normal))
        continuity = try await InvestigationMachineOuterCompletionJoin(
            prover: admission).seal(
                selection: selection, result: result, predecessor: predecessor)
    }
    let bundle = try InvestigationMachineEpochEvidenceCollection.finish(summary: .init(
        outerAttemptUUID: attempt, wholeCapsuleSHA256: capsule.wholeCapsuleSHA256,
        wholeInputSHA256: projected.wholeInputSHA256, completedEpochCount: 8))
    guard let mutation else { return bundle }
    return try rewrapEpochBundle(bundle, mutation: mutation)
}
private func rewrapEpochBundle(
    _ bundle: Data, mutation: EpochBundleMutation) throws -> Data {
    var outer = try OuterInnerWireTranscript(bundle)
    let target = mutation == .successorPredecessorDigest ||
        mutation == .repeatedHelper ? 1 : 0
    let request = try InvestigationMachineDarwinEpochRequest.decodeUntrusted(
        OuterInnerWireTranscript(outer.fields[target + 4]).fields[4])
    let invocation: InvestigationMachineSingleEpochInvocation
    let selection: InvestigationMachineFixedEpochSelection
    let identityIndex: UInt32
    switch mutation {
    case .requestWholeCapsule:
        selection = .init(
            outerAttemptUUID: request.invocation.selection.outerAttemptUUID,
            wholeCapsuleSHA256: try OuterInnerFixture.digest(0xc1),
            wholeInputSHA256: request.invocation.selection.wholeInputSHA256,
            epoch: request.invocation.selection.epoch,
            projection: request.invocation.selection.projection)
        let genesis = try InvestigationMachineHelperEpochContinuity
            .genesis(for: selection)
        let predecessor = try genesis.consume(for: selection)
        invocation = try predecessor.invocation(for: selection)
        identityIndex = 0
    case .requestWholeInput:
        selection = .init(
            outerAttemptUUID: request.invocation.selection.outerAttemptUUID,
            wholeCapsuleSHA256:
                request.invocation.selection.wholeCapsuleSHA256,
            wholeInputSHA256: try OuterInnerFixture.digest(0xc2),
            epoch: request.invocation.selection.epoch,
            projection: request.invocation.selection.projection)
        let genesis = try InvestigationMachineHelperEpochContinuity
            .genesis(for: selection)
        let predecessor = try genesis.consume(for: selection)
        invocation = try predecessor.invocation(for: selection)
        identityIndex = 0
    case .successorPredecessorDigest:
        selection = request.invocation.selection
        let rawInvocation = try OuterInnerWireTranscript(try request.invocation.encoded())
        var predecessor = try OuterInnerWireTranscript(rawInvocation.fields[5])
        predecessor.fields[6] = try OuterInnerFixture.digest(0xc3).rawBytes
        let predecessorBytes = try predecessor.encoded(maximumByteCount: 4_096)
        invocation = try .init(
            selection: selection,
            previousHelperIdentity: request.invocation.previousHelperIdentity,
            predecessorSHA256: .hashing(predecessorBytes),
            predecessorTranscript: predecessorBytes)
        identityIndex = 1
    case .repeatedHelper:
        selection = request.invocation.selection
        invocation = request.invocation
        identityIndex = 0
    }
    let replacement = try OuterInnerFixture(
        selection: selection, invocation: invocation, predecessor: nil,
        identityIndex: identityIndex)
    outer.fields[target + 4] = try makeEpochEvidence(fixture: replacement)
    return try outer.encoded(maximumByteCount:
        InvestigationMachineEpochEvidenceBundle.maximumByteCount)
}
private func independentlyRecomputedAdmissionSHA256(
    requestBytes: Data, resultBytes: Data, terminalEvidenceBytes: Data,
    admissionMaterialBytes: Data
) throws -> InvestigationHandoffSHA256 {
    .hashing(try independentlyRecomputedAdmissionTranscript(
        requestBytes: requestBytes, resultBytes: resultBytes,
        terminalEvidenceBytes: terminalEvidenceBytes,
        admissionMaterialBytes: admissionMaterialBytes))
}

private func independentlyRecomputedAdmissionTranscript(
    requestBytes: Data, resultBytes: Data, terminalEvidenceBytes: Data,
    admissionMaterialBytes: Data
) throws -> Data {
    let material = try OuterInnerWireTranscript(admissionMaterialBytes)
    guard material.domain
            == "stornaut.task39.machine.outer-inner.admission-material",
        material.fields.count == 4
    else { throw InvestigationHandoffContractError.invalidEncoding }
    return try HandoffBinaryTranscript.encode(
        domain: "stornaut.task39.machine.outer-inner.admission",
        businessFields: [
            requestBytes, material.fields[0], material.fields[1],
            material.fields[2],
            InvestigationHandoffSHA256.hashing(resultBytes).rawBytes,
            InvestigationHandoffSHA256.hashing(terminalEvidenceBytes).rawBytes,
            material.fields[3],
        ], maximumByteCount: 192 * 1_024)
}

private func outerInnerData(_ value: UInt32) -> Data {
    Data([
        UInt8(truncatingIfNeeded: value >> 24),
        UInt8(truncatingIfNeeded: value >> 16),
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value),
    ])
}

private func outerInnerData(_ value: UUID) -> Data {
    var bytes = value.uuid
    return withUnsafeBytes(of: &bytes) { Data($0) }
}

private final class DeadlineCapturingPhysicalComposer:
    InvestigationMachinePhysicalSingleEpochComposing, @unchecked Sendable
{
    private let selection: InvestigationMachineFixedEpochSelection
    private let lock = NSLock()
    private var capturedDeadlines: [UInt64] = []
    private var capturedInvocations: [InvestigationMachineSingleEpochInvocation] = []
    var deadlines: [UInt64] { lock.withLock { capturedDeadlines } }
    var invocations: [InvestigationMachineSingleEpochInvocation] {
        lock.withLock { capturedInvocations }
    }
    init(selection: InvestigationMachineFixedEpochSelection) {
        self.selection = selection
    }
    func isBound(to value: InvestigationMachineFixedEpochSelection) -> Bool {
        value == selection
    }
    func run(
        previousHelperIdentity: InvestigationMachineProcessIdentity?
    ) async throws -> InvestigationMachineSingleEpochResult {
        throw InvestigationMachineDarwinOuterInnerProtocolError.invalidState
    }
    func run(
        invocation: InvestigationMachineSingleEpochInvocation
    ) async throws -> InvestigationMachineSingleEpochResult {
        throw InvestigationMachineDarwinOuterInnerProtocolError.invalidState
    }
    func run(
        invocation: InvestigationMachineSingleEpochInvocation,
        epochDeadlineNanoseconds: UInt64
    ) async throws -> InvestigationMachineSingleEpochResult {
        lock.withLock {
            capturedInvocations.append(invocation)
            capturedDeadlines.append(epochDeadlineNanoseconds)
        }
        return .admittedPhysical(try await placeholderAdmittedResult())
    }
    private func placeholderAdmittedResult() async throws
        -> InvestigationMachineSingleEpochAdmittedPhysicalResult
    {
        throw InvestigationMachineDarwinOuterInnerProtocolError.invalidState
    }
}

private actor SuspendedPhysicalComposer:
    InvestigationMachinePhysicalSingleEpochComposing
{
    nonisolated let selection: InvestigationMachineFixedEpochSelection
    private let result: InvestigationMachineSingleEpochResult
    private var started = false
    private var released = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    init(
        selection: InvestigationMachineFixedEpochSelection,
        result: InvestigationMachineSingleEpochResult
    ) {
        self.selection = selection
        self.result = result
    }
    nonisolated func isBound(
        to value: InvestigationMachineFixedEpochSelection
    ) -> Bool { value == selection }
    func run(
        previousHelperIdentity: InvestigationMachineProcessIdentity?
    ) async throws -> InvestigationMachineSingleEpochResult {
        throw InvestigationMachineDarwinOuterInnerProtocolError.invalidState
    }
    func run(
        invocation: InvestigationMachineSingleEpochInvocation,
        epochDeadlineNanoseconds: UInt64
    ) async throws -> InvestigationMachineSingleEpochResult {
        _ = invocation
        _ = epochDeadlineNanoseconds
        started = true
        let waiting = startWaiters
        startWaiters.removeAll()
        waiting.forEach { $0.resume() }
        if !released {
            await withCheckedContinuation { releaseWaiters.append($0) }
        }
        return result
    }
    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }
    func release() {
        released = true
        let waiting = releaseWaiters
        releaseWaiters.removeAll()
        waiting.forEach { $0.resume() }
    }
}

private struct ForeignAdmittedResultProver:
    InvestigationMachineOuterContainmentProving
{
    func proveContainment(
        selection: InvestigationMachineFixedEpochSelection,
        result: InvestigationMachineSingleEpochResult,
        predecessor: InvestigationMachineHelperEpochPredecessor
    ) async -> InvestigationMachineOuterContainmentOutcome {
        guard let proof = try? InvestigationMachineOuterContainmentProof(
            selection: selection, result: result, predecessor: predecessor,
            terminalProofSHA256: try OuterInnerFixture.digest(0xdd)
        ) else { return .terminalUncertain }
        return .contained(proof)
    }
}

private func acceptsRequest(
    _ admission: InvestigationMachineDarwinOuterAdmission,
    _ request: InvestigationMachineDarwinEpochRequest
) async -> Bool {
    do { try await admission.accept(request); return true } catch { return false }
}

private func completeExchange(
    _ fixture: OuterInnerFixture,
    _ admission: InvestigationMachineDarwinOuterAdmission
) async throws -> (acknowledgement: InvestigationMachineDarwinEpochAcknowledgement,
                   decision: InvestigationMachineDarwinEpochDecision) {
    try await admission.accept(fixture.request)
    let acknowledgement = try await admission.acceptOwnership(
        fixture.ownershipRecord, observedDriverChild: fixture.driverChild,
        observedAppChild: fixture.appChild
    )
    let decision = try await admission.issueDecision(acknowledgement)
    return (acknowledgement, decision)
}

struct OuterInnerFixture {
    let outerProcessID: UInt32 = 88
    let observedAt: UInt64 = 1_000_000_000
    let selection: InvestigationMachineFixedEpochSelection
    let invocation: InvestigationMachineSingleEpochInvocation
    let predecessor: InvestigationMachineHelperEpochPredecessor?
    let request: InvestigationMachineDarwinEpochRequest
    let claimEvidence: InvestigationMachineClaimEvidence
    let physicalOwnership: InvestigationMachineSingleEpochPhysicalOwnership
    let driverChild: InvestigationMachineDarwinDriverChildIdentity
    let appChild: InvestigationMachineDarwinAppChildIdentity
    let ownershipRecord: InvestigationMachineDarwinEpochOwnershipRecord
    let acknowledgement: InvestigationMachineDarwinEpochAcknowledgement
    let decision: InvestigationMachineDarwinEpochDecision

    init(
        scenario: InvestigationHandoffScenario, configuration: Data? = nil,
        outerAttemptUUID: UUID? = nil,
        wholeCapsuleSHA256: InvestigationHandoffSHA256? = nil,
        wholeInputSHA256: InvestigationHandoffSHA256? = nil,
        claimRequestBindingSHA256: InvestigationHandoffSHA256? = nil) throws {
        let ordinal = scenario.rawValue - 1
        let configuration = configuration
            ?? Data("outer-inner-\(ordinal)".utf8)
        let epoch = try InvestigationCohortEpoch(
            ordinal: ordinal, epochUUID: Self.uuid(UInt8(0x10 + ordinal)),
            scenario: scenario,
            configurationNonce: Self.uuid(UInt8(0x20 + ordinal)),
            configuration: configuration,
            configurationSHA256: .hashing(configuration),
            signedRuntimeBindingSHA256: Self.digest(UInt8(0x30 + ordinal))
        )
        let signing = try InvestigationInstalledL2SigningIdentity(
            signingIdentifier:
                "com.eriklee.stornaut.investigation.machine-driver",
            designatedRequirementSHA256: Self.digest(0x40),
            codeDirectoryHash: Data(repeating: 0x41, count: 20), isAdHoc: true
        )
        let projection = try InvestigationInstalledL2IdentityProjection(
            epochUUID: epoch.epochUUID,
            configurationNonce: epoch.configurationNonce,
            configurationValidBefore: .init(rawValue: 2_000_000_000),
            configurationSHA256: epoch.configurationSHA256,
            signedRuntimeBindingSHA256: epoch.signedRuntimeBindingSHA256,
            appExecutableSHA256: Self.digest(0x42),
            appBundleIdentifier: "com.eriklee.stornaut",
            helperExecutableSHA256: Self.digest(0x43),
            helperServiceIdentifier: "com.eriklee.stornaut.lifecycle",
            machineDriverExecutableSHA256: Self.digest(0x44),
            machineDriverSigningIdentifier: signing.signingIdentifier,
            machineDriverDesignatedRequirementSHA256:
                signing.designatedRequirementSHA256,
            machineDriverCodeDirectoryHash: signing.codeDirectoryHash,
            machineClaimServiceIdentifier:
                "com.eriklee.stornaut.lifecycle.machine-claim"
        )
        selection = .init(
            outerAttemptUUID: outerAttemptUUID ?? Self.uuid(0x01),
            wholeCapsuleSHA256: try wholeCapsuleSHA256 ?? Self.digest(0x02),
            wholeInputSHA256: try wholeInputSHA256 ?? Self.digest(0x03),
            epoch: epoch, projection: projection)
        if ordinal == 0 {
            let continuity = try InvestigationMachineHelperEpochContinuity
                .genesis(for: selection)
            let predecessor = try continuity.consume(for: selection)
            self.predecessor = predecessor
            invocation = try predecessor.invocation(for: selection)
        } else {
            self.predecessor = nil
            let previous = try Self.identity(
                role: .helper, pid: 700, version: 7, asid: 70
            )
            let transcript = try Self.predecessorTranscript(
                selection: selection, helper: previous
            )
            invocation = try .init(
                selection: selection, previousHelperIdentity: previous,
                predecessorSHA256: .hashing(transcript),
                predecessorTranscript: transcript
            )
        }
        request = try .init(
            invocation: invocation,
            epochDeadlineNanoseconds: observedAt + 140_000_000_000
        )
        let app = try Self.identity(
            role: .app, pid: 902, version: 12, asid: 92
        )
        let helper = try Self.identity(
            role: .helper, pid: 903, version: 13, asid: 93
        )
        claimEvidence = try .init(requestBindingSHA256:
            claimRequestBindingSHA256 ?? Self.digest(0x51),
            originalClaimChallenge: Self.uuid(0x52),
            claimConnectionEpoch: Self.uuid(0x53),
            appIdentity: app, helperIdentity: helper, appUserID: 501,
            recordedAt: .init(rawValue: 200),
            claimedAt: .init(rawValue: 300), ownerRetirement: .init(),
            l1Residue: .init(
                investigationUUID: epoch.configurationNonce,
                auditSessionID: helper.auditSessionID, userID: 501,
                observedAt: .init(rawValue: 100),
                remainingAuditSessionMembers: 0, matchingLeases: 0,
                leaseRootEntries: 0, investigationArtifacts: 0
            ),
            releaseDeadlineNanoseconds: observedAt + 100_000_000_000
        )
        physicalOwnership = try Self.physicalOwnership(
            selection: selection, claimEvidence: claimEvidence)
        driverChild = try .init(
            processID: 901, processIDVersion: 11,
            parentProcessID: outerProcessID, processGroupID: 901,
            auditSessionID: 91, effectiveUserID: 0,
            auditTokenWords: [0, 0, 0, 0, 0, 901, 91, 11]
        )
        appChild = try .init(
            identity: app, parentProcessID: driverChild.processID,
            processGroupID: driverChild.processGroupID
        )
        ownershipRecord = try .init(
            request: request, driverChild: driverChild, appChild: appChild,
            physicalOwnership: physicalOwnership
        )
        acknowledgement = try .init(
            request: request, ownership: ownershipRecord
        )
        decision = try .init(
            request: request, ownership: ownershipRecord,
            acknowledgement: acknowledgement
        )
    }

    init(
        selection: InvestigationMachineFixedEpochSelection,
        invocation: InvestigationMachineSingleEpochInvocation,
        predecessor: InvestigationMachineHelperEpochPredecessor?,
        identityIndex: UInt32) throws {
        self.selection = selection
        self.invocation = invocation
        self.predecessor = predecessor
        request = try .init(
            invocation: invocation,
            epochDeadlineNanoseconds: observedAt + 140_000_000_000)
        let app = try Self.identity(
            role: .app, pid: 902 + identityIndex,
            version: 12 + identityIndex, asid: 92 + identityIndex)
        let helper = try Self.identity(
            role: .helper, pid: 912 + identityIndex,
            version: 22 + identityIndex, asid: 102 + identityIndex)
        claimEvidence = try .init(
            requestBindingSHA256: Self.digest(0x51),
            originalClaimChallenge: Self.uuid(UInt8(0x52 + identityIndex)),
            claimConnectionEpoch: Self.uuid(UInt8(0x62 + identityIndex)),
            appIdentity: app, helperIdentity: helper, appUserID: 501,
            recordedAt: .init(rawValue: 200),
            claimedAt: .init(rawValue: 300), ownerRetirement: .init(),
            l1Residue: .init(
                investigationUUID: selection.epoch.configurationNonce,
                auditSessionID: helper.auditSessionID, userID: 501,
                observedAt: .init(rawValue: 100),
                remainingAuditSessionMembers: 0, matchingLeases: 0,
                leaseRootEntries: 0, investigationArtifacts: 0),
            releaseDeadlineNanoseconds: observedAt + 100_000_000_000)
        physicalOwnership = try Self.physicalOwnership(
            selection: selection, claimEvidence: claimEvidence)
        driverChild = try .init(
            processID: 1_001 + identityIndex,
            processIDVersion: 31 + identityIndex,
            parentProcessID: outerProcessID, processGroupID: 1_001 + identityIndex,
            auditSessionID: 131 + identityIndex, effectiveUserID: 0,
            auditTokenWords: [0, 0, 0, 0, 0, 1_001 + identityIndex,
                131 + identityIndex, 31 + identityIndex])
        appChild = try .init(
            identity: app, parentProcessID: driverChild.processID,
            processGroupID: driverChild.processGroupID)
        ownershipRecord = try .init(
            request: request, driverChild: driverChild, appChild: appChild,
            physicalOwnership: physicalOwnership)
        acknowledgement = try .init(
            request: request, ownership: ownershipRecord)
        decision = try .init(
            request: request, ownership: ownershipRecord,
            acknowledgement: acknowledgement)
    }

    fileprivate func makeOuterAdmission(
        clock: FixedOuterInnerProtocolClock? = nil
    ) -> InvestigationMachineDarwinOuterAdmission {
        .init(
            selection: selection, outerProcessID: outerProcessID,
            clock: clock ?? FixedOuterInnerProtocolClock(now: observedAt + 2)
        )
    }

    func physicalResult(driverObservationSHA256:
        InvestigationHandoffSHA256? = nil
    ) throws -> InvestigationMachineSingleEpochPhysicalResult {
        try .init(
            completing: physicalOwnership,
            claimReleaseSHA256: Self.digest(0x61),
            driverObservationSHA256:
                driverObservationSHA256 ?? Self.digest(0x62)
        )
    }

    fileprivate func terminalEvidence(
        successfulExit: Bool, mutation: TerminalEvidenceMutation? = nil,
        driverChild requestedDriverChild:
            InvestigationMachineDarwinDriverChildIdentity? = nil,
        appChild requestedAppChild:
            InvestigationMachineDarwinAppChildIdentity? = nil
    ) throws
        -> InvestigationMachineDarwinEpochTerminalEvidence {
        let foreignDriver = try self.driverChild(
            parentProcessID: outerProcessID + 1
        )
        let foreignApp = try self.appChild(
            processGroupID: appChild.processGroupID + 1
        )
        let foreignHelper = try Self.identity(
            role: .helper, pid: 999, version: 99, asid: 999
        )
        return try InvestigationMachineDarwinEpochTerminalEvidence(
            controlEOFObserved: mutation != .controlEOF,
            resultEOFObserved: mutation != .resultEOF,
            driverChild: mutation == .driverIdentity
                ? foreignDriver : (requestedDriverChild ?? driverChild),
            appChild: mutation == .appIdentity
                ? foreignApp : (requestedAppChild ?? appChild),
            helperIdentity: mutation == .helperIdentity
                ? foreignHelper : physicalOwnership.helperIdentity,
            innerExitedSuccessfully: successfulExit,
            appAbsent: mutation != .appPresent,
            groupLeaderReapedLast: mutation != .leaderNotLast,
            postReapGroupEmpty: mutation != .groupNotEmpty,
            helperAbsent: mutation != .helperPresent,
            l1ResidueAbsent: mutation != .l1Residue,
            initialDriverObservationSHA256: Self.digest(
                mutation == .driverResultMismatch ? 0x71 : 0x62
            ),
            finalDriverObservationSHA256: Self.digest(
                mutation == .driverDrift ? 0x72
                    : (mutation == .driverResultMismatch ? 0x71 : 0x62)
            ),
            observedAtNanoseconds: mutation == .expired
                ? request.epochDeadlineNanoseconds : observedAt + 1
        )
    }

    func driverChild(parentProcessID: UInt32) throws
        -> InvestigationMachineDarwinDriverChildIdentity {
        try .init(
            processID: driverChild.processID,
            processIDVersion: driverChild.processIDVersion,
            parentProcessID: parentProcessID,
            processGroupID: driverChild.processGroupID,
            auditSessionID: driverChild.auditSessionID,
            effectiveUserID: driverChild.effectiveUserID,
            auditTokenWords: driverChild.auditTokenWords)
    }

    func driverChild(
        processID: UInt32, processIDVersion: UInt32
    ) throws -> InvestigationMachineDarwinDriverChildIdentity {
        try .init(
            processID: processID, processIDVersion: processIDVersion,
            parentProcessID: outerProcessID, processGroupID: processID,
            auditSessionID: driverChild.auditSessionID, effectiveUserID: 0,
            auditTokenWords: [
                0, 0, 0, 0, 0, processID, driverChild.auditSessionID,
                processIDVersion,
            ]
        )
    }

    func appChild(processGroupID: UInt32) throws
        -> InvestigationMachineDarwinAppChildIdentity {
        try .init(
            identity: appChild.identity, parentProcessID: appChild.parentProcessID,
            processGroupID: processGroupID)
    }

    func appChild(
        parentProcessID: UInt32, processGroupID: UInt32
    ) throws -> InvestigationMachineDarwinAppChildIdentity {
        try .init(
            identity: appChild.identity, parentProcessID: parentProcessID,
            processGroupID: processGroupID
        )
    }

    private static func predecessorTranscript(
        selection: InvestigationMachineFixedEpochSelection,
        helper: InvestigationMachineProcessIdentity
    ) throws -> Data {
        let completed = selection.epoch.ordinal - 1
        let mode: InvestigationMachineOuterContainmentMode =
            completed == 6 ? .parentCrash : .normal
        return try HandoffBinaryTranscript.encode(
            domain: "stornaut.task39.machine.helper-continuity.successor",
            businessFields: [
                data(selection.outerAttemptUUID),
                selection.wholeCapsuleSHA256.rawBytes,
                selection.wholeInputSHA256.rawBytes, data(completed),
                data(uuid(UInt8(0x80 + completed))), try helper.encoded(),
                try digest(0x81).rawBytes, try digest(0x82).rawBytes,
                try digest(0x83).rawBytes, Data([mode.rawValue]),
            ], maximumByteCount: 4_096
        )
    }

    private static func identity(
        role: InvestigationMachineProcessRole, pid: UInt32, version: UInt32,
        asid: UInt32
    ) throws -> InvestigationMachineProcessIdentity {
        let euid: UInt32 = role == .app ? 501 : 0
        return try .init(
            role: role, processID: pid, processIDVersion: version,
            auditSessionID: asid, effectiveUserID: euid,
            auditTokenWords: [euid, euid, 20, euid, 20, pid, asid, version]
        )
    }

    fileprivate static func digest(_ byte: UInt8) throws
        -> InvestigationHandoffSHA256 {
        try .init(rawBytes: Data(repeating: byte, count: 32))
    }

    private static func physicalOwnership(
        selection: InvestigationMachineFixedEpochSelection, claimEvidence:
            InvestigationMachineClaimEvidence
    ) throws -> InvestigationMachineSingleEpochPhysicalOwnership {
        func signing(_ identifier: String, _ marker: UInt8, _ adHoc: Bool) throws -> InvestigationInstalledL2SigningIdentity {
            try .init(signingIdentifier: identifier, designatedRequirementSHA256:
                digest(marker), codeDirectoryHash: Data(repeating: marker &+ 1, count: 20), isAdHoc: adHoc)
        }
        let projection = selection.projection
        let appSigning = try signing(projection.appBundleIdentifier, 0xd0, false)
        let helperSigning = try signing(projection.helperServiceIdentifier + ".helper", 0xd2, false)
        let driverSigning = try InvestigationInstalledL2SigningIdentity(
            signingIdentifier: projection.machineDriverSigningIdentifier,
            designatedRequirementSHA256: projection.machineDriverDesignatedRequirementSHA256,
            codeDirectoryHash: projection.machineDriverCodeDirectoryHash,
            isAdHoc: true)
        let semantic = try InvestigationInstalledL2SemanticContract.evaluate(
            projection: projection, artifacts: Dictionary(uniqueKeysWithValues:
                InvestigationInstalledL2ArtifactRole.allCases.map {
                    ($0, InvestigationInstalledL2ArtifactObservation.presentValid) }),
            app: try .init(identity: claimEvidence.appIdentity, executableSHA256: projection.appExecutableSHA256,
                staticSigning: appSigning, liveSigning: appSigning),
            helper: try .init(identity: claimEvidence.helperIdentity, executableSHA256: projection.helperExecutableSHA256,
                staticSigning: helperSigning, liveSigning: helperSigning),
            machineDriver: try .init(executableSHA256: projection.machineDriverExecutableSHA256,
                staticSigning: driverSigning, liveSigning: driverSigning),
            service: .loaded(identity: claimEvidence.helperIdentity),
            started: try .init(wallUTC: .init(rawValue: 400), continuousNanoseconds: 400),
            observed: try .init(wallUTC: .init(rawValue: 500), continuousNanoseconds: 500))
        let proof = try InvestigationMachineSingleEpochInstalledL2Join.prove(
            projection: projection, claimEvidence: claimEvidence, semanticObservation: semantic,
            repeatedAppIdentity: claimEvidence.appIdentity,
            epochUUID: selection.epoch.epochUUID, deadlineNanoseconds:
                1_000_000_000 + 140_000_000_000)
        let candidate = try InvestigationMachineSingleEpochOwnershipCandidate(
            commitment: .init(selection: selection), appIdentity: claimEvidence.appIdentity,
            claimEvidence: claimEvidence, semanticObservation: semantic,
            repeatedAppIdentity: claimEvidence.appIdentity,
            installedL2Proof: proof, epochDeadlineNanoseconds: 1_000_000_000 + 140_000_000_000)
        return try .init(projecting: candidate)
    }

    private static func uuid(_ byte: UInt8) -> UUID {
        UUID(uuid: (byte, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    }

    private static func data(_ value: UInt32) -> Data {
        Data([
            UInt8(truncatingIfNeeded: value >> 24),
            UInt8(truncatingIfNeeded: value >> 16),
            UInt8(truncatingIfNeeded: value >> 8),
            UInt8(truncatingIfNeeded: value),
        ])
    }

    private static func data(_ value: UUID) -> Data {
        var bytes = value.uuid
        return withUnsafeBytes(of: &bytes) { Data($0) }
    }
}

private final class FixedOuterInnerProtocolClock:
    InvestigationMachineDarwinOuterInnerCompositionClocking, @unchecked Sendable
{
    let now: UInt64
    private let lock = NSLock()
    private var storedCalls = 0

    init(now: UInt64) { self.now = now }

    var calls: Int { lock.withLock { storedCalls } }

    func continuousNanoseconds() throws -> UInt64 {
        lock.withLock { storedCalls += 1 }
        return now
    }
}

private struct CancellingOuterInnerProtocolClock:
    InvestigationMachineDarwinOuterInnerCompositionClocking
{
    let now: UInt64
    func continuousNanoseconds() throws -> UInt64 {
        withUnsafeCurrentTask { $0?.cancel() }
        return now
    }
}

private func strictProtocolMutations(_ encoded: Data) -> [Data] {
    var changed = encoded
    changed[changed.startIndex] ^= 0x01
    var trailing = encoded
    trailing.append(0x7f)
    return [changed, trailing, Data(encoded.dropLast())]
}

private struct OuterInnerWireTranscript {
    let domain: String
    var fields: [Data]

    init(_ encoded: Data) throws {
        var cursor = HandoffBinaryCursor(data: encoded)
        guard try cursor.readUInt32() == HandoffBinaryTranscript.magic else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        let domainBytes = try cursor.readTaggedField(
            expectedTag: 0,
            admittedByteCounts: 1...HandoffBinaryTranscript.maximumDomainByteCount
        )
        guard let domain = String(data: domainBytes, encoding: .utf8) else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        let version = try cursor.readTaggedField(
            expectedTag: 1, admittedByteCounts: 4...4
        )
        var versionCursor = HandoffBinaryCursor(data: version)
        guard
            try versionCursor.readUInt32() == HandoffBinaryTranscript.version,
            versionCursor.isAtEnd
        else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        var fields: [Data] = []
        var tag: UInt16 = 2
        while !cursor.isAtEnd {
            fields.append(try cursor.readTaggedField(
                expectedTag: tag, admittedByteCounts: 1...encoded.count
            ))
            tag += 1
        }
        self.domain = domain
        self.fields = fields
    }

    func encoded(
        domain requestedDomain: String? = nil,
        maximumByteCount: Int = 128 * 1_024) throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: requestedDomain ?? domain, businessFields: fields,
            maximumByteCount: maximumByteCount
        )
    }
}

private func strictUntrustedRequestMutations(_ encoded: Data) throws
    -> [Data]
{
    let source = try OuterInnerWireTranscript(encoded)
    guard source.fields.count == 4 else {
        throw InvestigationHandoffContractError.invalidEncoding
    }
    var nested = source
    nested.fields[0][nested.fields[0].startIndex] ^= 0x01
    nested.fields[1] = InvestigationHandoffSHA256.hashing(
        nested.fields[0]
    ).rawBytes
    var digest = source
    digest.fields[1][digest.fields[1].startIndex] ^= 0x01
    var zeroDeadline = source
    zeroDeadline.fields[2] = Data(repeating: 0, count: 8)
    var mode = source
    mode.fields[3] = Data([
        source.fields[3][source.fields[3].startIndex] == 0x01 ? 0x02 : 0x01
    ])
    var missing = source
    missing.fields.removeLast()
    var duplicate = source
    duplicate.fields.append(source.fields.last!)
    return try [
        source.encoded(domain: source.domain + ".drift"),
        nested.encoded(), digest.encoded(), zeroDeadline.encoded(),
        mode.encoded(), missing.encoded(), duplicate.encoded(),
    ] + strictProtocolMutations(encoded)
}
