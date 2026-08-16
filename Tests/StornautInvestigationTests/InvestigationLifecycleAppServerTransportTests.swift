import Foundation
import StornautLifecycle
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
                .started(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[0]
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
                .retired(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[3],
                    drained: true
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
        #expect(requests[0].maximumLineBytes == 1_024)
        #expect(requests[0].maximumSessionBytes == 8_192)
        #expect(requests[1].line == fixture.requestLine)
    }

    @Test
    func rejectsUseAfterRetireAndMultipleRetirement() async throws {
        let fixture = InvestigationLifecycleTransportFixture()
        let session = FakeLifecycleInteractiveSession(
            responses: [
                .retired(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[0],
                    drained: true
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
                .started(
                    investigationID: LifecycleInvestigationID(),
                    operationID: fixture.operationIDs[0]
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
    func endOfStreamAndUndrainedRetireFailClosed() async throws {
        let fixture = InvestigationLifecycleTransportFixture()
        let eofSession = FakeLifecycleInteractiveSession(
            responses: [
                .started(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[0]
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
                    drained: false
                ),
            ]
        )
        let undrainedTransport = try fixture.transport(
            session: undrainedSession,
            operationIDs: Array(fixture.operationIDs.prefix(1))
        )
        await #expect(
            throws: InvestigationLifecycleAppServerTransportError
                .drainUnconfirmed
        ) {
            try await undrainedTransport.retire()
        }
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
                .started(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[0]
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
                .started(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[0]
                ),
                .retired(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[1],
                    drained: true
                ),
            ],
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
                .started(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[0]
                ),
                .writeAccepted(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[1]
                ),
                .retired(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[2],
                    drained: true
                ),
            ],
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
                .started(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[0]
                ),
                try .line(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[1],
                    line: fixture.responseLine
                ),
                .retired(
                    investigationID: fixture.investigationID,
                    operationID: fixture.operationIDs[2],
                    drained: true
                ),
            ],
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

    func transport(
        session: any LifecycleInteractiveSessionSending,
        operationIDs: [UUID]? = nil,
        now: (@Sendable () -> Date)? = nil
    ) throws -> InvestigationLifecycleAppServerTransport {
        let provider = SequentialOperationIDProvider(
            values: operationIDs ?? self.operationIDs
        )
        return try InvestigationLifecycleAppServerTransport(
            investigationID: investigationID,
            validBefore: validBefore,
            maximumLineBytes: 1_024,
            maximumSessionBytes: 8_192,
            now: now ?? { self.now },
            operationID: { try provider.next() },
            session: session
        )
    }
}

private actor SuspendedLifecycleInteractiveSession:
    LifecycleInteractiveSessionSending
{
    private(set) var requests: [LifecycleInteractiveSessionRequest] = []
    private let investigationID: LifecycleInvestigationID
    private let operationIDs: [UUID]
    private var startContinuation: CheckedContinuation<Void, Never>?
    private var startWaiter: CheckedContinuation<Void, Never>?

    init(
        investigationID: LifecycleInvestigationID,
        operationIDs: [UUID]
    ) {
        self.investigationID = investigationID
        self.operationIDs = operationIDs
    }

    func send(
        _ request: LifecycleInteractiveSessionRequest
    ) async throws -> LifecycleInteractiveSessionResponse {
        requests.append(request)
        switch request.kind {
        case .start:
            startWaiter?.resume()
            startWaiter = nil
            await withCheckedContinuation {
                startContinuation = $0
            }
            return .started(
                investigationID: investigationID,
                operationID: operationIDs[0]
            )
        case .write:
            return .writeAccepted(
                investigationID: investigationID,
                operationID: operationIDs[1]
            )
        case .retire:
            return .retired(
                investigationID: investigationID,
                operationID: operationIDs[2],
                drained: true
            )
        case .read:
            throw InvestigationLifecycleAppServerTransportError
                .transportFailed
        }
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
    LifecycleInteractiveSessionSending
{
    private(set) var requests: [LifecycleInteractiveSessionRequest] = []
    private var responses: [LifecycleInteractiveSessionResponse]
    private let beforeResponse:
        @Sendable (LifecycleInteractiveSessionRequest) -> Void

    init(
        responses: [LifecycleInteractiveSessionResponse],
        beforeResponse:
            @escaping @Sendable (
                LifecycleInteractiveSessionRequest
            ) -> Void = { _ in }
    ) {
        self.responses = responses
        self.beforeResponse = beforeResponse
    }

    func send(
        _ request: LifecycleInteractiveSessionRequest
    ) async throws -> LifecycleInteractiveSessionResponse {
        requests.append(request)
        beforeResponse(request)
        guard !responses.isEmpty else {
            throw InvestigationLifecycleAppServerTransportError
                .transportFailed
        }
        return responses.removeFirst()
    }
}

private actor AmbiguousStartLifecycleInteractiveSession:
    LifecycleInteractiveSessionSending
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
        requests.append(request)
        switch request.kind {
        case .start:
            throw LifecycleInteractiveSessionXPCError.timedOut
        case .retire:
            return .retired(
                investigationID: investigationID,
                operationID: retireOperationID,
                drained: true
            )
        case .write, .read:
            throw InvestigationLifecycleAppServerTransportError
                .transportFailed
        }
    }
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
