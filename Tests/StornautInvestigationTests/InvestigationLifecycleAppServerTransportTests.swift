import Foundation
@testable import StornautLifecycle
import Testing
@testable import StornautCodex
@testable import StornautInvestigationRuntime

@Suite("Investigation lifecycle App Server transport")
struct InvestigationLifecycleAppServerTransportTests {
    @Test
    func lazilyStartsThenForwardsBoundedLinesAndDrainsOnRetire()
        async throws
    {
        let fixture = InvestigationLifecycleTransportFixture()
        let session = FakeLifecycleInteractiveSession(
            responses: [
                try .started(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[0],
                    codexExecutableSHA256:
                        fixture.codexExecutableSHA256
                ),
                .writeAccepted(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[1]
                ),
                try .line(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[2],
                    line: fixture.responseLine
                ),
                try fixture.retiredResponse(
                    operationID: fixture.operationIDs[3]
                ),
            ]
        )
        let transport = try fixture.transport(session: session)

        try await transport.writeLine(fixture.requestLine)
        #expect(try await transport.readLine() == fixture.responseLine)
        try await transport.retire()

        let requests = await session.requests
        #expect(requests.map(\.kind) == [
            .start,
            .write,
            .read,
            .retire,
        ])
        #expect(requests.map(\.operationID) == fixture.operationIDs)
        #expect(requests[0].validBefore == fixture.validBefore)
        #expect(
            requests[0].codexExecutableSHA256
                == fixture.codexExecutableSHA256
        )
        #expect(
            requests.dropFirst().allSatisfy {
                $0.codexExecutableSHA256 == nil
            }
        )
        #expect(requests[0].maximumLineBytes == 1_024)
        #expect(requests[0].maximumSessionBytes == 8_192)
        #expect(requests[1].line == fixture.requestLine)
    }

    @Test
    func rejectsUseAfterRetireAndMultipleRetirement() async throws {
        let fixture = InvestigationLifecycleTransportFixture()
        let session = FakeLifecycleInteractiveSession(
            responses: [
                try fixture.retiredResponse(
                    operationID: fixture.operationIDs[0]
                ),
            ]
        )
        let transport = try fixture.transport(
            session: session,
            operationIDs: Array(fixture.operationIDs.prefix(1))
        )

        try await transport.retire()
        #expect(await session.requests.map(\.kind) == [.retire])
        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .invalidState
        ) {
            try await transport.writeLine(fixture.requestLine)
        }
        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .invalidState
        ) {
            _ = try await transport.readLine()
        }
        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .invalidState
        ) {
            try await transport.retire()
        }
    }

    @Test
    func foreignResponsePermanentlyFailsClosed() async throws {
        let fixture = InvestigationLifecycleTransportFixture()
        let session = FakeLifecycleInteractiveSession(
            responses: [
                try .started(
                    investigationID: LifecycleInvestigationID(),
                    operationID: fixture.operationIDs[0],
                    codexExecutableSHA256:
                        fixture.codexExecutableSHA256
                ),
            ]
        )
        let transport = try fixture.transport(session: session)

        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .identityMismatch
        ) {
            try await transport.writeLine(fixture.requestLine)
        }
        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .invalidState
        ) {
            _ = try await transport.readLine()
        }
    }

    @Test
    func foreignObservedNativeDigestFailsBeforeActiveState() async throws {
        let fixture = InvestigationLifecycleTransportFixture()
        let session = FakeLifecycleInteractiveSession(responses: [
            try .started(
                investigationID: fixture.investigationID,
                operationID: fixture.operationIDs[0],
                codexExecutableSHA256: String(repeating: "c", count: 64)
            ),
        ])
        let transport = try fixture.transport(session: session)

        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .identityMismatch
        ) {
            try await transport.writeLine(fixture.requestLine)
        }
        #expect(await session.requests.map(\.kind) == [.start])
    }

    @Test
    func endOfStreamAndUndrainedRetireFailClosed() async throws {
        let fixture = InvestigationLifecycleTransportFixture()
        let eofSession = FakeLifecycleInteractiveSession(
            responses: [
                try .started(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[0],
                    codexExecutableSHA256:
                        fixture.codexExecutableSHA256
                ),
                .endOfStream(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[1]
                ),
            ]
        )
        let eofTransport = try fixture.transport(
            session: eofSession,
            operationIDs: Array(fixture.operationIDs.prefix(2))
        )
        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .unexpectedEndOfStream
        ) {
            _ = try await eofTransport.readLine()
        }

        let undrainedSession = FakeLifecycleInteractiveSession(
            responses: [
                .retired(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[0],
                    drained: false,
                    ownerRetirementObservation: .retiredOwnedResources
                ),
            ]
        )
        let undrainedTransport = try fixture.transport(
            session: undrainedSession,
            operationIDs: Array(fixture.operationIDs.prefix(1))
        )
        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .identityMismatch
        ) {
            try await undrainedTransport.retire()
        }
    }

    @Test
    func retireRequiresFreshExactZeroResidueObservation() async throws {
        let fixture = InvestigationLifecycleTransportFixture()
        let valid = try fixture.residueObservation()
        let acceptedSession = FakeLifecycleInteractiveSession(
            responses: [
                .retired(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[0],
                    drained: true,
                    ownerRetirementObservation: .retiredOwnedResources,
                    machineRetirementHandle: try fixture.handle(
                        operationID: fixture.operationIDs[0]
                    ),
                    residueObservation: valid
                ),
            ]
        )
        let accepted = try fixture.transport(
            session: acceptedSession,
            operationIDs: Array(fixture.operationIDs.prefix(1))
        )
        try await accepted.retire()
        #expect(try await accepted.acceptedResidueObservation() == valid)

        let missing = try fixture.transport(
            session: FakeLifecycleInteractiveSession(responses: [
                .retired(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[0],
                    drained: true,
                    ownerRetirementObservation: .retiredOwnedResources
                ),
            ]),
            operationIDs: Array(fixture.operationIDs.prefix(1))
        )
        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .identityMismatch
        ) {
            try await missing.retire()
        }

        let foreignObservation = try fixture.residueObservation(
            investigationID: LifecycleInvestigationID()
        )
        let foreign = try fixture.transport(
            session: FakeLifecycleInteractiveSession(responses: [
                .retired(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[0],
                    drained: true,
                    ownerRetirementObservation: .retiredOwnedResources,
                    machineRetirementHandle: try fixture.handle(
                        operationID: fixture.operationIDs[0]
                    ),
                    residueObservation: foreignObservation
                ),
            ]),
            operationIDs: Array(fixture.operationIDs.prefix(1))
        )
        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .identityMismatch
        ) {
            try await foreign.retire()
        }

        let foreignUserObservation = try fixture.residueObservation(
            userID: 502
        )
        let foreignUser = try fixture.transport(
            session: FakeLifecycleInteractiveSession(responses: [
                .retired(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[0],
                    drained: true,
                    ownerRetirementObservation: .retiredOwnedResources,
                    machineRetirementHandle: try fixture.handle(
                        operationID: fixture.operationIDs[0]
                    ),
                    residueObservation: foreignUserObservation
                ),
            ]),
            operationIDs: Array(fixture.operationIDs.prefix(1))
        )
        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .identityMismatch
        ) {
            try await foreignUser.retire()
        }

        let nonzero = try fixture.residueObservation(
            remainingAuditSessionMemberCount: 1
        )
        let undrained = try fixture.transport(
            session: FakeLifecycleInteractiveSession(responses: [
                .retired(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[0],
                    drained: true,
                    ownerRetirementObservation: .retiredOwnedResources,
                    machineRetirementHandle: try fixture.handle(
                        operationID: fixture.operationIDs[0]
                    ),
                    residueObservation: nonzero
                ),
            ]),
            operationIDs: Array(fixture.operationIDs.prefix(1))
        )
        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .drainUnconfirmed
        ) {
            try await undrained.retire()
        }

        for observedAt in [
            fixture.now.addingTimeInterval(-1),
            fixture.now.addingTimeInterval(-61),
            fixture.now.addingTimeInterval(1),
        ] {
            let staleOrFuture = try fixture.transport(
                session: FakeLifecycleInteractiveSession(responses: [
                    try fixture.retiredResponse(
                        operationID: fixture.operationIDs[0],
                        observedAt: observedAt
                    ),
                ]),
                operationIDs: Array(fixture.operationIDs.prefix(1))
            )
            await #expect(
                throws: InvestigationLifecycleAppServerTransportError
                    .drainUnconfirmed
            ) {
                try await staleOrFuture.retire()
            }
        }
    }

    @Test
    func retireRejectsEveryForeignOpaqueHandleBinding() async throws {
        let fixture = InvestigationLifecycleTransportFixture()
        let operationID = fixture.operationIDs[0]
        let handles = [
            try fixture.handle(
                operationID: operationID,
                investigationID: LifecycleInvestigationID()
            ),
            try fixture.handle(operationID: UUID()),
            try fixture.handle(
                operationID: operationID,
                configurationSHA256: String(repeating: "b", count: 64)
            ),
        ]

        for handle in handles {
            let session = FakeLifecycleInteractiveSession(responses: [
                .retired(
                    investigationID: fixture.investigationID,
                    operationID: operationID,
                    drained: true,
                    ownerRetirementObservation: .retiredOwnedResources,
                    machineRetirementHandle: handle,
                    residueObservation: try fixture.residueObservation()
                ),
            ])
            let transport = try fixture.transport(
                session: session,
                operationIDs: [operationID]
            )

            await #expect(
                throws: InvestigationLifecycleAppServerTransportError
                    .identityMismatch
            ) {
                try await transport.retire()
            }
            await #expect(
                throws: InvestigationLifecycleAppServerTransportError
                    .drainUnconfirmed
            ) {
                _ = try await transport.acceptedRetirementEvidence()
            }
        }
    }

    @Test
    func retireReturnsOpaqueResidueAndExactHelperIdentity() async throws {
        let fixture = InvestigationLifecycleTransportFixture()
        let helperIdentity = try fixture.helperIdentity()
        let residue = try fixture.residueObservation()
        let session = FakeLifecycleInteractiveSession(
            responses: [
                .retired(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[0],
                    drained: true,
                    ownerRetirementObservation: .retiredOwnedResources,
                    machineRetirementHandle: try fixture.handle(
                        operationID: fixture.operationIDs[0]
                    ),
                    residueObservation: residue
                ),
            ],
            helperIdentityResult: .success(helperIdentity)
        )
        let transport = try fixture.transport(
            session: session,
            operationIDs: Array(fixture.operationIDs.prefix(1))
        )

        let evidence = try await transport.retireWithEvidence()

        #expect(
            evidence.machineRetirementHandle.investigationID
                == fixture.investigationID
        )
        #expect(
            evidence.machineRetirementHandle.retireOperationID
                == fixture.operationIDs[0]
        )
        let handleJSON = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(
                    evidence.machineRetirementHandle
                )
            ) as? [String: Any]
        )
        #expect(handleJSON["protocolVersion"] as? Int == 3)
        #expect(handleJSON["validBefore"] == nil)
        #expect(
            (handleJSON["validBeforeUTCMicroseconds"] as? NSNumber)?
                .int64Value == 1_900_000_120_000_000
        )
        #expect(evidence.residueObservation == residue)
        #expect(evidence.helperProcessIdentity == helperIdentity)
        #expect(
            try await transport.acceptedRetirementEvidence()
                == evidence
        )
        #expect(await session.helperIdentityRequestCount == 1)
        #expect(await session.requests.map(\.kind) == [.retire])
    }

    @Test
    func retirementEvidenceStoreIsOneShotAndRejectsDuplicateRecord()
        async throws
    {
        let fixture = InvestigationLifecycleTransportFixture()
        let helperIdentity = try fixture.helperIdentity()
        let store = InvestigationLifecycleRetirementEvidenceStore()
        let session = FakeLifecycleInteractiveSession(
            responses: [
                try fixture.retiredResponse(
                    operationID: fixture.operationIDs[0]
                ),
            ],
            helperIdentityResult: .success(helperIdentity)
        )
        let provider = SequentialOperationIDProvider(
            values: Array(fixture.operationIDs.prefix(1))
        )
        let transport = try InvestigationLifecycleAppServerTransport(
            investigationID: fixture.investigationID,
            configurationSHA256: fixture.configurationSHA256,
            codexExecutableSHA256: fixture.codexExecutableSHA256,
            validBefore: fixture.validBefore,
            maximumLineBytes: 1_024,
            maximumSessionBytes: 8_192,
            expectedUserID: 501,
            now: { fixture.now },
            operationID: { try provider.next() },
            session: session,
            retirementEvidenceStore: store
        )

        let expected = try await transport.retireWithEvidence()
        #expect(await store.consume() == expected)
        #expect(await store.consume() == nil)
        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .invalidState
        ) {
            try await store.record(expected)
        }
    }

    @Test
    func missingOrForeignHelperAttestationFailsClosedBeforeRetire()
        async throws
    {
        let fixture = InvestigationLifecycleTransportFixture()
        let session = FakeLifecycleInteractiveSession(
            responses: [
                try fixture.retiredResponse(
                    operationID: fixture.operationIDs[0]
                ),
            ],
            helperIdentityResult: .failure(
                LifecycleInteractiveSessionXPCError.invalidPeer
            )
        )
        let transport = try fixture.transport(
            session: session,
            operationIDs: Array(fixture.operationIDs.prefix(1))
        )

        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .identityMismatch
        ) {
            _ = try await transport.retireWithEvidence()
        }
        #expect(await session.helperIdentityRequestCount == 1)
        #expect(await session.requests.isEmpty)
        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .drainUnconfirmed
        ) {
            _ = try await transport.acceptedRetirementEvidence()
        }
    }

    @Test
    func helperIdentityMustBeSealedIntoTheExactRetireResponse()
        async throws
    {
        let fixture = InvestigationLifecycleTransportFixture()
        let nonEvidenceSession = NonEvidenceLifecycleInteractiveSession(
            responses: [
                try fixture.retiredResponse(
                    operationID: fixture.operationIDs[0]
                ),
            ]
        )
        let provider = SequentialOperationIDProvider(
            values: Array(fixture.operationIDs.prefix(1))
        )
        #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .invalidConfiguration
        ) {
            _ = try InvestigationLifecycleAppServerTransport(
                investigationID: fixture.investigationID,
                configurationSHA256: fixture.configurationSHA256,
                codexExecutableSHA256:
                    fixture.codexExecutableSHA256,
                validBefore: fixture.validBefore,
                maximumLineBytes: 1_024,
                maximumSessionBytes: 8_192,
                expectedUserID: 501,
                now: { fixture.now },
                operationID: { try provider.next() },
                session: nonEvidenceSession
            )
        }
        #expect(await nonEvidenceSession.requests.isEmpty)
    }

    @Test
    func rejectsExpiredOrOverbroadConfiguration() {
        let fixture = InvestigationLifecycleTransportFixture()
        let session = FakeLifecycleInteractiveSession(responses: [])

        #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .invalidConfiguration
        ) {
            _ = try InvestigationLifecycleAppServerTransport(
                investigationID: fixture.investigationID,
                configurationSHA256: fixture.configurationSHA256,
                codexExecutableSHA256:
                    fixture.codexExecutableSHA256,
                validBefore: fixture.now,
                maximumLineBytes: 1_024,
                maximumSessionBytes: 8_192,
                now: { fixture.now },
                operationID: UUID.init,
                session: session
            )
        }
        #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .invalidConfiguration
        ) {
            _ = try InvestigationLifecycleAppServerTransport(
                investigationID: fixture.investigationID,
                configurationSHA256: fixture.configurationSHA256,
                codexExecutableSHA256:
                    fixture.codexExecutableSHA256,
                validBefore: fixture.now.addingTimeInterval(901),
                maximumLineBytes: 1_024,
                maximumSessionBytes: 8_192,
                now: { fixture.now },
                operationID: UUID.init,
                session: session
            )
        }
    }

    @Test
    func concurrentOperationsCannotResurrectOrSkipRetirement()
        async throws
    {
        let fixture = InvestigationLifecycleTransportFixture()
        let session = SuspendedLifecycleInteractiveSession(
            investigationID: fixture.investigationID,
            operationIDs: fixture.operationIDs
        )
        let transport = try fixture.transport(session: session)

        let write = Task {
            try await transport.writeLine(fixture.requestLine)
        }
        await session.waitUntilStartIsSuspended()
        let retire = Task {
            try await transport.retire()
        }
        await session.resumeStart()

        try await write.value
        try await retire.value
        #expect(await session.requests.map(\.kind) == [
            .start,
            .write,
            .retire,
        ])
        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .invalidState
        ) {
            _ = try await transport.readLine()
        }
    }

    @Test
    func expiryAfterStartFailsClosedBeforeLaterIO() async throws {
        let fixture = InvestigationLifecycleTransportFixture()
        let clock = MutableTransportClock(now: fixture.now)
        let session = FakeLifecycleInteractiveSession(
            responses: [
                try .started(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[0],
                    codexExecutableSHA256:
                        fixture.codexExecutableSHA256
                ),
                .writeAccepted(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[1]
                ),
            ]
        )
        let transport = try fixture.transport(
            session: session,
            now: { clock.read() }
        )

        try await transport.writeLine(fixture.requestLine)
        clock.set(fixture.validBefore)
        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .invalidConfiguration
        ) {
            _ = try await transport.readLine()
        }
        #expect(await session.requests.map(\.kind) == [.start, .write])
    }

    @Test
    func responsesArrivingAfterDeadlineFailClosedAndRemainRetirable()
        async throws
    {
        let fixture = InvestigationLifecycleTransportFixture()
        let startClock = MutableTransportClock(now: fixture.now)
        let startSession = FakeLifecycleInteractiveSession(
            responses: [
                try .started(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[0],
                    codexExecutableSHA256:
                        fixture.codexExecutableSHA256
                ),
                try fixture.retiredResponse(
                    operationID: fixture.operationIDs[1],
                    observedAt: fixture.validBefore
                ),
            ],
            helperAttestedAt: { startClock.read() },
            beforeResponse: { request in
                if request.kind == .start {
                    startClock.set(fixture.validBefore)
                }
            }
        )
        let startTransport = try fixture.transport(
            session: startSession,
            operationIDs: Array(fixture.operationIDs.prefix(2)),
            now: { startClock.read() }
        )

        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .invalidConfiguration
        ) {
            try await startTransport.writeLine(fixture.requestLine)
        }
        try await startTransport.retire()
        #expect(await startSession.requests.map(\.kind) == [
            .start,
            .retire,
        ])

        let writeClock = MutableTransportClock(now: fixture.now)
        let writeSession = FakeLifecycleInteractiveSession(
            responses: [
                try .started(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[0],
                    codexExecutableSHA256:
                        fixture.codexExecutableSHA256
                ),
                .writeAccepted(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[1]
                ),
                try fixture.retiredResponse(
                    operationID: fixture.operationIDs[2],
                    observedAt: fixture.validBefore
                ),
            ],
            helperAttestedAt: { writeClock.read() },
            beforeResponse: { request in
                if request.kind == .write {
                    writeClock.set(fixture.validBefore)
                }
            }
        )
        let writeTransport = try fixture.transport(
            session: writeSession,
            operationIDs: Array(fixture.operationIDs.prefix(3)),
            now: { writeClock.read() }
        )

        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .invalidConfiguration
        ) {
            try await writeTransport.writeLine(fixture.requestLine)
        }
        try await writeTransport.retire()
        #expect(await writeSession.requests.map(\.kind) == [
            .start,
            .write,
            .retire,
        ])

        let readClock = MutableTransportClock(now: fixture.now)
        let readSession = FakeLifecycleInteractiveSession(
            responses: [
                try .started(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[0],
                    codexExecutableSHA256:
                        fixture.codexExecutableSHA256
                ),
                try .line(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[1],
                    line: fixture.responseLine
                ),
                try fixture.retiredResponse(
                    operationID: fixture.operationIDs[2],
                    observedAt: fixture.validBefore
                ),
            ],
            helperAttestedAt: { readClock.read() },
            beforeResponse: { request in
                if request.kind == .read {
                    readClock.set(fixture.validBefore)
                }
            }
        )
        let readTransport = try fixture.transport(
            session: readSession,
            operationIDs: Array(fixture.operationIDs.prefix(3)),
            now: { readClock.read() }
        )

        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .invalidConfiguration
        ) {
            _ = try await readTransport.readLine()
        }
        try await readTransport.retire()
        #expect(await readSession.requests.map(\.kind) == [
            .start,
            .read,
            .retire,
        ])
    }

    @Test
    func ambiguousStartFailureRemainsRetirableByTheCleanupOwner()
        async throws
    {
        let fixture = InvestigationLifecycleTransportFixture()
        let session = AmbiguousStartLifecycleInteractiveSession(
            investigationID: fixture.investigationID,
            retireOperationID: fixture.operationIDs[1]
        )
        let transport = try fixture.transport(
            session: session,
            operationIDs: Array(fixture.operationIDs.prefix(2))
        )

        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .transportFailed
        ) {
            try await transport.writeLine(fixture.requestLine)
        }
        try await transport.retire()
        #expect(await session.requests.map(\.kind) == [.start, .retire])
    }

    @Test
    func cancelledQueuedOperationNeverDispatchesStaleIO() async throws {
        let fixture = InvestigationLifecycleTransportFixture()
        let session = SuspendedLifecycleInteractiveSession(
            investigationID: fixture.investigationID,
            operationIDs: fixture.operationIDs
        )
        let transport = try fixture.transport(session: session)

        let write = Task {
            try await transport.writeLine(fixture.requestLine)
        }
        await session.waitUntilStartIsSuspended()
        let read = Task {
            try await transport.readLine()
        }
        await Task.yield()
        read.cancel()
        await session.resumeStart()

        try await write.value
        await #expect(throws: CancellationError.self) {
            _ = try await read.value
        }
        try await transport.retire()
        #expect(await session.requests.map(\.kind) == [
            .start,
            .write,
            .retire,
        ])
    }

    @Test
    func cancellationDuringStartNeverDispatchesThePendingWrite()
        async throws
    {
        let fixture = InvestigationLifecycleTransportFixture()
        let session = SuspendedLifecycleInteractiveSession(
            investigationID: fixture.investigationID,
            operationIDs: fixture.operationIDs
        )
        let transport = try fixture.transport(session: session)

        let write = Task {
            try await transport.writeLine(fixture.requestLine)
        }
        await session.waitUntilStartIsSuspended()
        write.cancel()
        await session.resumeStart()

        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .transportFailed
        ) {
            try await write.value
        }
        try await transport.retire()
        #expect(await session.requests.map(\.kind) == [
            .start,
            .retire,
        ])
    }

    @Test
    func startAndRetireUsesOnlyControlRequestsAndStoresEvidence()
        async throws
    {
        let fixture = InvestigationLifecycleTransportFixture()
        let store = InvestigationLifecycleRetirementEvidenceStore()
        let session = FakeLifecycleInteractiveSession(responses: [
            try .started(
                investigationID: fixture.investigationID,
                operationID: fixture.operationIDs[0],
                codexExecutableSHA256: fixture.codexExecutableSHA256
            ),
            try fixture.retiredResponse(
                operationID: fixture.operationIDs[1]
            ),
        ])
        let transport = try fixture.transport(
            session: session,
            operationIDs: Array(fixture.operationIDs.prefix(2)),
            retirementEvidenceStore: store
        )

        let evidence = try await transport.startAndRetireWithEvidence()

        let requests = await session.requests
        #expect(requests.map(\.kind) == [.start, .retire])
        #expect(requests.allSatisfy { $0.line == nil })
        #expect(requests[0].validBefore == fixture.validBefore)
        #expect(requests[1].validBefore == nil)
        #expect(
            evidence.codexExecutableSHA256
                == fixture.codexExecutableSHA256
        )
        #expect(await store.consume() == evidence)
        #expect(try await transport.acceptedRetirementEvidence() == evidence)
    }

    @Test
    func dispatchedStartFailureStillRetiresAndPreservesFailure() async throws {
        let fixture = InvestigationLifecycleTransportFixture()
        let session = FakeLifecycleInteractiveSession(responses: [
            try .started(
                investigationID: fixture.investigationID,
                operationID: UUID(),
                codexExecutableSHA256: fixture.codexExecutableSHA256
            ),
            try fixture.retiredResponse(
                operationID: fixture.operationIDs[1]
            ),
        ])
        let transport = try fixture.transport(
            session: session,
            operationIDs: Array(fixture.operationIDs.prefix(2))
        )

        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .identityMismatch
        ) {
            _ = try await transport.startAndRetireWithEvidence()
        }
        #expect(await session.requests.map(\.kind) == [.start, .retire])
        #expect(
            try await transport.acceptedRetirementEvidence()
                .codexExecutableSHA256 == nil
        )
    }

    @Test
    func unprovedRetirementReplacesDispatchedStartFailure() async throws {
        let fixture = InvestigationLifecycleTransportFixture()
        let session = FakeLifecycleInteractiveSession(responses: [
            try .started(
                investigationID: fixture.investigationID,
                operationID: UUID(),
                codexExecutableSHA256: fixture.codexExecutableSHA256
            ),
            .retired(
                investigationID: fixture.investigationID,
                operationID: fixture.operationIDs[1],
                drained: true,
                ownerRetirementObservation: .noOwnedResources
            ),
        ])
        let transport = try fixture.transport(
            session: session,
            operationIDs: Array(fixture.operationIDs.prefix(2))
        )

        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .drainUnconfirmed
        ) {
            _ = try await transport.startAndRetireWithEvidence()
        }
        #expect(await session.requests.map(\.kind) == [.start, .retire])
    }

    @Test
    func expiryAfterStartStillRetiresBeforeReturningFailure() async throws {
        let fixture = InvestigationLifecycleTransportFixture()
        let clock = MutableTransportClock(now: fixture.now)
        let session = FakeLifecycleInteractiveSession(
            responses: [
                try .started(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[0],
                    codexExecutableSHA256:
                        fixture.codexExecutableSHA256
                ),
                try fixture.retiredResponse(
                    operationID: fixture.operationIDs[1],
                    observedAt: fixture.validBefore
                ),
            ],
            helperAttestedAt: { clock.read() },
            beforeResponse: { request in
                if request.kind == .start {
                    clock.set(fixture.validBefore)
                }
            }
        )
        let transport = try fixture.transport(
            session: session,
            operationIDs: Array(fixture.operationIDs.prefix(2)),
            now: { clock.read() }
        )

        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .invalidConfiguration
        ) {
            _ = try await transport.startAndRetireWithEvidence()
        }
        #expect(await session.requests.map(\.kind) == [.start, .retire])
        _ = try await transport.acceptedRetirementEvidence()
    }

    @Test
    func expiryBeforeStartDispatchesNothingAndIsTerminal() async throws {
        let fixture = InvestigationLifecycleTransportFixture()
        let clock = MutableTransportClock(now: fixture.now)
        let session = FakeLifecycleInteractiveSession(responses: [])
        let transport = try fixture.transport(
            session: session,
            now: { clock.read() }
        )
        clock.set(fixture.validBefore)

        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .invalidConfiguration
        ) {
            _ = try await transport.startAndRetireWithEvidence()
        }
        #expect(await session.requests.isEmpty)
        await #expect(
            throws: InvestigationLifecycleAppServerTransportError.invalidState
        ) {
            _ = try await transport.startAndRetireWithEvidence()
        }
    }

    @Test
    func successfulStartWithFailedRetirementNeverBecomesSuccess() async throws {
        let fixture = InvestigationLifecycleTransportFixture()
        let session = FakeLifecycleInteractiveSession(responses: [
            try .started(
                investigationID: fixture.investigationID,
                operationID: fixture.operationIDs[0],
                codexExecutableSHA256: fixture.codexExecutableSHA256
            ),
            .retired(
                investigationID: fixture.investigationID,
                operationID: fixture.operationIDs[1],
                drained: true,
                ownerRetirementObservation: .noOwnedResources
            ),
        ])
        let transport = try fixture.transport(
            session: session,
            operationIDs: Array(fixture.operationIDs.prefix(2))
        )

        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .drainUnconfirmed
        ) {
            _ = try await transport.startAndRetireWithEvidence()
        }
        #expect(await session.requests.map(\.kind) == [.start, .retire])
        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .drainUnconfirmed
        ) {
            _ = try await transport.acceptedRetirementEvidence()
        }
    }

    @Test
    func occupiedEvidenceStoreMakesTheWholeSeamFail() async throws {
        let fixture = InvestigationLifecycleTransportFixture()
        let store = InvestigationLifecycleRetirementEvidenceStore()
        let seedSession = FakeLifecycleInteractiveSession(responses: [
            try fixture.retiredResponse(
                operationID: fixture.operationIDs[0]
            ),
        ])
        let seed = try InvestigationLifecycleAppServerTransport(
            investigationID: fixture.investigationID,
            configurationSHA256: fixture.configurationSHA256,
            codexExecutableSHA256: fixture.codexExecutableSHA256,
            validBefore: fixture.validBefore,
            maximumLineBytes: 1_024,
            maximumSessionBytes: 8_192,
            expectedUserID: 501,
            now: { fixture.now },
            operationID: { fixture.operationIDs[0] },
            session: seedSession,
            retirementEvidenceStore: store
        )
        _ = try await seed.retireWithEvidence()
        let session = FakeLifecycleInteractiveSession(responses: [
            try .started(
                investigationID: fixture.investigationID,
                operationID: fixture.operationIDs[0],
                codexExecutableSHA256: fixture.codexExecutableSHA256
            ),
            try fixture.retiredResponse(
                operationID: fixture.operationIDs[1]
            ),
        ])
        let transport = try fixture.transport(
            session: session,
            operationIDs: Array(fixture.operationIDs.prefix(2)),
            retirementEvidenceStore: store
        )

        await #expect(
            throws: InvestigationLifecycleAppServerTransportError.invalidState
        ) {
            _ = try await transport.startAndRetireWithEvidence()
        }
        #expect(await session.requests.map(\.kind) == [.start, .retire])
        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .drainUnconfirmed
        ) {
            _ = try await transport.acceptedRetirementEvidence()
        }
    }

    @Test(arguments: [false, true])
    func cancellationAfterDispatchStillCompletesRetirement(
        duringRetire: Bool
    ) async throws {
        let fixture = InvestigationLifecycleTransportFixture()
        let ids = [
            fixture.operationIDs[0],
            fixture.operationIDs[1],
            fixture.operationIDs[1],
        ]
        let session = SuspendedLifecycleInteractiveSession(
            investigationID: fixture.investigationID,
            operationIDs: ids,
            suspendRetire: duringRetire,
            checkRetireCancellation: true
        )
        let transport = try fixture.transport(
            session: session,
            operationIDs: Array(ids.prefix(2))
        )
        let operation = Task {
            try await transport.startAndRetireWithEvidence()
        }
        await session.waitUntilStartIsSuspended()
        if duringRetire {
            await session.resumeStart()
            await session.waitUntilRetireIsSuspended()
        }
        operation.cancel()
        if duringRetire {
            await session.resumeRetire()
        } else {
            await session.resumeStart()
        }

        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .transportFailed
        ) {
            _ = try await operation.value
        }
        #expect(await session.requests.map(\.kind) == [.start, .retire])
        _ = try await transport.acceptedRetirementEvidence()
    }

    @Test
    func cancellationBeforeStartIsTerminalAndDispatchesNothing() async throws {
        let fixture = InvestigationLifecycleTransportFixture()
        let session = FakeLifecycleInteractiveSession(responses: [])
        let transport = try fixture.transport(session: session)
        let operation = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await transport.startAndRetireWithEvidence()
        }

        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .transportFailed
        ) {
            _ = try await operation.value
        }
        #expect(await session.requests.isEmpty)
        await #expect(
            throws: InvestigationLifecycleAppServerTransportError.invalidState
        ) {
            _ = try await transport.startAndRetireWithEvidence()
        }
    }

    @Test
    func concurrentAndRepeatedStartRetireCallsHaveOneWinner() async throws {
        let fixture = InvestigationLifecycleTransportFixture()
        let ids = [
            fixture.operationIDs[0],
            fixture.operationIDs[1],
            fixture.operationIDs[1],
        ]
        let session = SuspendedLifecycleInteractiveSession(
            investigationID: fixture.investigationID,
            operationIDs: ids
        )
        let transport = try fixture.transport(
            session: session,
            operationIDs: Array(ids.prefix(2))
        )
        let first = Task {
            try await transport.startAndRetireWithEvidence()
        }
        await session.waitUntilStartIsSuspended()
        let second = Task {
            try await transport.startAndRetireWithEvidence()
        }
        await Task.yield()
        await session.resumeStart()

        _ = try await first.value
        await #expect(
            throws: InvestigationLifecycleAppServerTransportError.invalidState
        ) {
            _ = try await second.value
        }
        await #expect(
            throws: InvestigationLifecycleAppServerTransportError.invalidState
        ) {
            _ = try await transport.startAndRetireWithEvidence()
        }
        #expect(await session.requests.map(\.kind) == [.start, .retire])
    }
}

private struct InvestigationLifecycleTransportFixture {
    let investigationID = LifecycleInvestigationID(
        rawValue: UUID(
            uuidString: "93939393-9393-4393-8393-939393939393"
        )!
    )
    let now = Date(timeIntervalSince1970: 1_900_000_000)
    let validBefore = Date(timeIntervalSince1970: 1_900_000_120)
    let operationIDs = [
        UUID(uuidString: "94111111-1111-4111-8111-111111111111")!,
        UUID(uuidString: "94222222-2222-4222-8222-222222222222")!,
        UUID(uuidString: "94333333-3333-4333-8333-333333333333")!,
        UUID(uuidString: "94444444-4444-4444-8444-444444444444")!,
    ]
    let requestLine = Data("{\"method\":\"initialize\"}\n".utf8)
    let responseLine = Data("{\"id\":1,\"result\":{}}\n".utf8)
    let configurationSHA256 = String(repeating: "a", count: 64)
    let codexExecutableSHA256 = String(repeating: "b", count: 64)

    func helperIdentity() throws -> LifecycleProcessIdentity {
        LifecycleProcessIdentity(
            processID: 702,
            processIDVersion: 12,
            auditSessionID: 33_001,
            effectiveUserID: 0,
            auditToken: try LifecycleAuditToken(words: [
                0, 0, 0, 0, 0, 702, 33_001, 12,
            ])
        )
    }

    func residueObservation(
        investigationID: LifecycleInvestigationID? = nil,
        userID: UInt32 = 501,
        observedAt: Date? = nil,
        remainingAuditSessionMemberCount: Int = 0,
        matchingLeaseCount: Int = 0,
        leaseRootEntryCount: Int = 0,
        investigationArtifactCount: Int = 0
    ) throws -> LifecycleInvestigationResidueObservation {
        try LifecycleInvestigationResidueObservation(
            investigationID: investigationID ?? self.investigationID,
            auditSessionID: 44_001,
            userID: userID,
            observedAt: observedAt ?? now,
            remainingAuditSessionMemberCount:
                remainingAuditSessionMemberCount,
            matchingLeaseCount: matchingLeaseCount,
            leaseRootEntryCount: leaseRootEntryCount,
            investigationArtifactCount: investigationArtifactCount
        )
    }

    func retiredResponse(
        operationID: UUID,
        observedAt: Date? = nil
    ) throws -> LifecycleInteractiveSessionResponse {
        .retired(
            investigationID: investigationID,
            operationID: operationID,
            drained: true,
            ownerRetirementObservation: .retiredOwnedResources,
            machineRetirementHandle: try handle(
                operationID: operationID
            ),
            residueObservation: try residueObservation(
                observedAt: observedAt
            )
        )
    }

    func handle(
        operationID: UUID,
        investigationID: LifecycleInvestigationID? = nil,
        configurationSHA256: String? = nil
    ) throws -> LifecycleMachineRetirementHandle {
        try LifecycleMachineRetirementHandle(
            token: UUID(),
            investigationID: investigationID ?? self.investigationID,
            retireOperationID: operationID,
            configurationSHA256:
                configurationSHA256 ?? self.configurationSHA256,
            validBefore: validBefore
        )
    }

    func transport(
        session: any LifecycleInteractiveSessionSending,
        operationIDs: [UUID]? = nil,
        now: (@Sendable () -> Date)? = nil,
        retirementEvidenceStore:
            InvestigationLifecycleRetirementEvidenceStore? = nil
    ) throws -> InvestigationLifecycleAppServerTransport {
        let provider = SequentialOperationIDProvider(
            values: operationIDs ?? self.operationIDs
        )
        return try InvestigationLifecycleAppServerTransport(
            investigationID: investigationID,
            configurationSHA256: configurationSHA256,
            codexExecutableSHA256: codexExecutableSHA256,
            validBefore: validBefore,
            maximumLineBytes: 1_024,
            maximumSessionBytes: 8_192,
            expectedUserID: 501,
            now: now ?? { self.now },
            operationID: { try provider.next() },
            session: session,
            retirementEvidenceStore: retirementEvidenceStore
        )
    }
}

private actor SuspendedLifecycleInteractiveSession:
    LifecycleInteractiveSessionEvidenceSending
{
    private(set) var requests: [LifecycleInteractiveSessionRequest] = []
    private let investigationID: LifecycleInvestigationID
    private let operationIDs: [UUID]
    private let suspendRetire: Bool
    private let checkRetireCancellation: Bool
    private var startContinuation: CheckedContinuation<Void, Never>?
    private var startWaiter: CheckedContinuation<Void, Never>?
    private var retireContinuation: CheckedContinuation<Void, Never>?
    private var retireWaiter: CheckedContinuation<Void, Never>?

    init(
        investigationID: LifecycleInvestigationID,
        operationIDs: [UUID],
        suspendRetire: Bool = false,
        checkRetireCancellation: Bool = false
    ) {
        self.investigationID = investigationID
        self.operationIDs = operationIDs
        self.suspendRetire = suspendRetire
        self.checkRetireCancellation = checkRetireCancellation
    }

    func send(
        _ request: LifecycleInteractiveSessionRequest
    ) async throws -> LifecycleInteractiveSessionResponse {
        if request.kind == .retire {
            _ = try await freshAttestedHelperPeer()
        }
        requests.append(request)
        switch request.kind {
        case .start:
            startWaiter?.resume()
            startWaiter = nil
            await withCheckedContinuation {
                startContinuation = $0
            }
            return try .started(
                investigationID: investigationID,
                operationID: operationIDs[0],
                codexExecutableSHA256:
                    try #require(request.codexExecutableSHA256)
            )
        case .write:
            return .writeAccepted(
                investigationID: investigationID,
                operationID: operationIDs[1]
            )
        case .retire:
            if suspendRetire {
                retireWaiter?.resume()
                retireWaiter = nil
                await withCheckedContinuation {
                    retireContinuation = $0
                }
            }
            if checkRetireCancellation {
                try Task.checkCancellation()
            }
            return .retired(
                investigationID: investigationID,
                operationID: operationIDs[2],
                drained: true,
                ownerRetirementObservation: .retiredOwnedResources,
                machineRetirementHandle:
                    try LifecycleMachineRetirementHandle(
                        token: UUID(),
                        investigationID: investigationID,
                        retireOperationID: operationIDs[2],
                        configurationSHA256: request.configurationSHA256,
                        validBefore: Date(
                            timeIntervalSince1970: 1_900_000_030
                        )
                    ),
                residueObservation:
                    try LifecycleInvestigationResidueObservation(
                        investigationID: investigationID,
                        auditSessionID: 44_001,
                        userID: 501,
                        observedAt: Date(
                            timeIntervalSince1970: 1_900_000_000
                        ),
                        remainingAuditSessionMemberCount: 0,
                        matchingLeaseCount: 0,
                        leaseRootEntryCount: 0,
                        investigationArtifactCount: 0
                    )
            )
        case .read:
            throw InvestigationLifecycleAppServerTransportError
                .transportFailed
        }
    }

    func freshAttestedHelperPeer() async throws
        -> LifecycleConnectedHelperPeer
    {
        try investigationTransportHelperPeer()
    }

    func takeRetirementHelperPeer(
        operationID _: UUID
    ) -> LifecycleConnectedHelperPeer? {
        try? investigationTransportHelperPeer()
    }

    func waitUntilStartIsSuspended() async {
        if startContinuation != nil {
            return
        }
        await withCheckedContinuation {
            startWaiter = $0
        }
    }

    func resumeStart() {
        startContinuation?.resume()
        startContinuation = nil
    }

    func waitUntilRetireIsSuspended() async {
        if retireContinuation != nil {
            return
        }
        await withCheckedContinuation {
            retireWaiter = $0
        }
    }

    func resumeRetire() {
        retireContinuation?.resume()
        retireContinuation = nil
    }
}

private final class MutableTransportClock: @unchecked Sendable {
    private let lock = NSLock()
    private var now: Date

    init(now: Date) {
        self.now = now
    }

    func read() -> Date {
        lock.withLock { now }
    }

    func set(_ value: Date) {
        lock.withLock { now = value }
    }
}

private actor FakeLifecycleInteractiveSession:
    LifecycleInteractiveSessionEvidenceSending
{
    private(set) var requests: [LifecycleInteractiveSessionRequest] = []
    private(set) var helperIdentityRequestCount = 0
    private var responses: [LifecycleInteractiveSessionResponse]
    private let helperIdentityResult:
        Result<LifecycleProcessIdentity, any Error>
    private let helperAttestedAt:
        @Sendable () -> Date
    private var pendingHelperPeer: LifecycleConnectedHelperPeer?
    private let beforeResponse:
        @Sendable (LifecycleInteractiveSessionRequest) -> Void

    init(
        responses: [LifecycleInteractiveSessionResponse],
        helperIdentityResult:
            Result<LifecycleProcessIdentity, any Error> = .success(
                try! InvestigationLifecycleTransportFixture()
                    .helperIdentity()
            ),
        helperAttestedAt:
            @escaping @Sendable () -> Date = {
                Date(timeIntervalSince1970: 1_900_000_000)
            },
        beforeResponse:
            @escaping @Sendable (
                LifecycleInteractiveSessionRequest
            ) -> Void = { _ in }
    ) {
        self.responses = responses
        self.helperIdentityResult = helperIdentityResult
        self.helperAttestedAt = helperAttestedAt
        self.beforeResponse = beforeResponse
    }

    func freshAttestedHelperPeer() async throws
        -> LifecycleConnectedHelperPeer
    {
        helperIdentityRequestCount += 1
        let peer = LifecycleConnectedHelperPeer(
            identity: try helperIdentityResult.get(),
            attestedAt: helperAttestedAt()
        )
        pendingHelperPeer = peer
        return peer
    }

    func takeRetirementHelperPeer(
        operationID _: UUID
    ) -> LifecycleConnectedHelperPeer? {
        defer { pendingHelperPeer = nil }
        return pendingHelperPeer
    }

    func send(
        _ request: LifecycleInteractiveSessionRequest
    ) async throws -> LifecycleInteractiveSessionResponse {
        if request.kind == .retire {
            _ = try await freshAttestedHelperPeer()
        }
        requests.append(request)
        beforeResponse(request)
        guard !responses.isEmpty else {
            throw InvestigationLifecycleAppServerTransportError
                .transportFailed
        }
        return responses.removeFirst()
    }
}

private actor NonEvidenceLifecycleInteractiveSession:
    LifecycleInteractiveSessionSending
{
    private(set) var requests: [LifecycleInteractiveSessionRequest] = []
    private var responses: [LifecycleInteractiveSessionResponse]

    init(responses: [LifecycleInteractiveSessionResponse]) {
        self.responses = responses
    }

    func send(
        _ request: LifecycleInteractiveSessionRequest
    ) async throws -> LifecycleInteractiveSessionResponse {
        requests.append(request)
        guard !responses.isEmpty else {
            throw InvestigationLifecycleAppServerTransportError
                .transportFailed
        }
        return responses.removeFirst()
    }
}

private actor AmbiguousStartLifecycleInteractiveSession:
    LifecycleInteractiveSessionEvidenceSending
{
    private(set) var requests: [LifecycleInteractiveSessionRequest] = []
    private let investigationID: LifecycleInvestigationID
    private let retireOperationID: UUID

    init(
        investigationID: LifecycleInvestigationID,
        retireOperationID: UUID
    ) {
        self.investigationID = investigationID
        self.retireOperationID = retireOperationID
    }

    func send(
        _ request: LifecycleInteractiveSessionRequest
    ) async throws -> LifecycleInteractiveSessionResponse {
        if request.kind == .retire {
            _ = try await freshAttestedHelperPeer()
        }
        requests.append(request)
        switch request.kind {
        case .start:
            throw LifecycleInteractiveSessionXPCError.timedOut
        case .retire:
            return .retired(
                investigationID: investigationID,
                operationID: retireOperationID,
                drained: true,
                ownerRetirementObservation: .retiredOwnedResources,
                machineRetirementHandle:
                    try LifecycleMachineRetirementHandle(
                        token: UUID(),
                        investigationID: investigationID,
                        retireOperationID: retireOperationID,
                        configurationSHA256: request.configurationSHA256,
                        validBefore: Date(
                            timeIntervalSince1970: 1_900_000_030
                        )
                    ),
                residueObservation:
                    try LifecycleInvestigationResidueObservation(
                        investigationID: investigationID,
                        auditSessionID: 44_001,
                        userID: 501,
                        observedAt: Date(
                            timeIntervalSince1970: 1_900_000_000
                        ),
                        remainingAuditSessionMemberCount: 0,
                        matchingLeaseCount: 0,
                        leaseRootEntryCount: 0,
                        investigationArtifactCount: 0
                    )
            )
        case .write, .read:
            throw InvestigationLifecycleAppServerTransportError
                .transportFailed
        }
    }

    func freshAttestedHelperPeer() async throws
        -> LifecycleConnectedHelperPeer
    {
        try investigationTransportHelperPeer()
    }

    func takeRetirementHelperPeer(
        operationID _: UUID
    ) -> LifecycleConnectedHelperPeer? {
        try? investigationTransportHelperPeer()
    }
}

private func investigationTransportHelperPeer() throws
    -> LifecycleConnectedHelperPeer
{
    LifecycleConnectedHelperPeer(
        identity: try InvestigationLifecycleTransportFixture()
            .helperIdentity(),
        attestedAt: Date(timeIntervalSince1970: 1_900_000_000)
    )
}

private final class SequentialOperationIDProvider: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [UUID]

    init(values: [UUID]) {
        self.values = values
    }

    func next() throws -> UUID {
        try lock.withLock {
            guard !values.isEmpty else {
                throw InvestigationLifecycleAppServerTransportError
                    .transportFailed
            }
            return values.removeFirst()
        }
    }
}
