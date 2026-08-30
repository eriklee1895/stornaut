import Foundation
import Testing
@testable import StornautLifecycle

@Suite("Lifecycle Interactive Session Broker")
struct LifecycleInteractiveSessionBrokerTests {
    @Test
    func brokerDrivesOneStrictSessionAndAccountsEveryLine() async throws {
        let fixture = LifecycleInteractiveBrokerFixture()
        let worker = RecordingLifecycleInteractiveWorker(
            reads: [Data("{\"id\":1,\"result\":{}}\n".utf8)]
        )
        let broker = LifecycleInteractiveSessionBroker(
            worker: worker,
            now: { fixture.now }
        )

        let started = try await broker.handle(
            try fixture.startRequest()
        )
        #expect(started.kind == .started)

        let write = try fixture.writeRequest(
            line: Data("{\"id\":1,\"method\":\"initialize\"}\n".utf8)
        )
        #expect(
            try await broker.handle(write).kind == .writeAccepted
        )

        let read = fixture.readRequest()
        let line = try await broker.handle(read)
        #expect(line.kind == .line)
        #expect(line.line == Data("{\"id\":1,\"result\":{}}\n".utf8))

        let retired = try await broker.handle(
            fixture.retireRequest()
        )
        #expect(retired.kind == .retired)
        #expect(retired.drained == true)
        #expect(
            retired.ownerRetirementObservation
                == .retiredOwnedResources
        )
        #expect(await worker.startCount == 1)
        #expect(await worker.writes == [write.line!])
        #expect(await worker.readCount == 1)
        #expect(await worker.retireCount == 1)
    }

    @Test
    func brokerRejectsExpiredAndOverlongStartsBeforeWorkerDispatch()
        async
    {
        let fixture = LifecycleInteractiveBrokerFixture()
        let worker = RecordingLifecycleInteractiveWorker()
        let broker = LifecycleInteractiveSessionBroker(
            worker: worker,
            now: { fixture.now }
        )

        await #expect(
            throws:
                LifecycleInteractiveSessionBrokerError.invalidRequest
        ) {
            _ = try await broker.handle(
                try LifecycleInteractiveSessionRequest.start(
                    investigationID: fixture.investigationID,
                    operationID: UUID(),
                    configurationSHA256: fixture.configurationSHA256,
                    codexExecutableSHA256:
                        fixture.codexExecutableSHA256,
                    validBefore: fixture.now,
                    maximumLineBytes: 1_024,
                    maximumSessionBytes: 8_192
                )
            )
        }
        await #expect(
            throws:
                LifecycleInteractiveSessionBrokerError.invalidRequest
        ) {
            _ = try await broker.handle(
                try LifecycleInteractiveSessionRequest.start(
                    investigationID: fixture.investigationID,
                    operationID: UUID(),
                    configurationSHA256: fixture.configurationSHA256,
                    codexExecutableSHA256:
                        fixture.codexExecutableSHA256,
                    validBefore:
                        fixture.now.addingTimeInterval(901),
                    maximumLineBytes: 1_024,
                    maximumSessionBytes: 8_192
                )
            )
        }
        #expect(await worker.startCount == 0)
    }

    @Test
    func brokerRejectsForeignSessionAndOperationReplay() async throws {
        let fixture = LifecycleInteractiveBrokerFixture()
        let worker = RecordingLifecycleInteractiveWorker()
        let broker = LifecycleInteractiveSessionBroker(
            worker: worker,
            now: { fixture.now }
        )
        _ = try await broker.handle(try fixture.startRequest())

        await #expect(
            throws:
                LifecycleInteractiveSessionBrokerError.sessionMismatch
        ) {
            _ = try await broker.handle(
                try LifecycleInteractiveSessionRequest.read(
                    investigationID: LifecycleInvestigationID(
                        rawValue: UUID()
                    ),
                    operationID: UUID(),
                    configurationSHA256: fixture.configurationSHA256
                )
            )
        }

        let replayedOperationID = UUID()
        let first = try LifecycleInteractiveSessionRequest.read(
            investigationID: fixture.investigationID,
            operationID: replayedOperationID,
            configurationSHA256: fixture.configurationSHA256
        )
        await worker.appendRead(Data("{\"first\":true}\n".utf8))
        _ = try await broker.handle(first)
        await #expect(
            throws:
                LifecycleInteractiveSessionBrokerError.invalidRequest
        ) {
            _ = try await broker.handle(first)
        }
    }

    @Test
    func brokerRejectsConfigurationDriftAcrossTheSession() async throws {
        let fixture = LifecycleInteractiveBrokerFixture()
        let broker = LifecycleInteractiveSessionBroker(
            worker: RecordingLifecycleInteractiveWorker(),
            now: { fixture.now }
        )
        _ = try await broker.handle(try fixture.startRequest())
        let foreignHash = String(repeating: "b", count: 64)

        await #expect(
            throws: LifecycleInteractiveSessionBrokerError.sessionMismatch
        ) {
            _ = try await broker.handle(
                try LifecycleInteractiveSessionRequest.read(
                    investigationID: fixture.investigationID,
                    operationID: UUID(),
                    configurationSHA256: foreignHash
                )
            )
        }
        await #expect(
            throws: LifecycleInteractiveSessionBrokerError.sessionMismatch
        ) {
            _ = try await broker.handle(
                try LifecycleInteractiveSessionRequest.retire(
                    investigationID: fixture.investigationID,
                    operationID: UUID(),
                    configurationSHA256: foreignHash
                )
            )
        }
    }

    @Test
    func brokerRejectsWorkerObservedNativeDigestMismatch() async throws {
        let fixture = LifecycleInteractiveBrokerFixture()
        let worker = RecordingLifecycleInteractiveWorker(
            observedCodexExecutableSHA256:
                String(repeating: "c", count: 64)
        )
        let broker = LifecycleInteractiveSessionBroker(
            worker: worker, now: { fixture.now }
        )

        await #expect(
            throws: LifecycleInteractiveSessionBrokerError.sessionMismatch
        ) {
            _ = try await broker.handle(try fixture.startRequest())
        }
        #expect(await worker.startCount == 1)
        #expect(await broker.invalidateAndRetire())
    }

    @Test
    func brokerEnforcesNegotiatedLineAndSessionLimits() async throws {
        let fixture = LifecycleInteractiveBrokerFixture()
        let worker = RecordingLifecycleInteractiveWorker(
            reads: [Data("12345678\n".utf8)]
        )
        let broker = LifecycleInteractiveSessionBroker(
            worker: worker,
            now: { fixture.now }
        )
        _ = try await broker.handle(
            try fixture.startRequest(
                maximumLineBytes: 16,
                maximumSessionBytes: 19
            )
        )
        _ = try await broker.handle(
            try fixture.writeRequest(line: Data("1234567890\n".utf8))
        )

        await #expect(
            throws:
                LifecycleInteractiveSessionBrokerError.sessionLimitExceeded
        ) {
            _ = try await broker.handle(fixture.readRequest())
        }

        let secondWorker = RecordingLifecycleInteractiveWorker()
        let secondBroker = LifecycleInteractiveSessionBroker(
            worker: secondWorker,
            now: { fixture.now }
        )
        _ = try await secondBroker.handle(
            try fixture.startRequest(
                maximumLineBytes: 8,
                maximumSessionBytes: 16
            )
        )
        await #expect(
            throws:
                LifecycleInteractiveSessionBrokerError.lineLimitExceeded
        ) {
            _ = try await secondBroker.handle(
                try fixture.writeRequest(
                    line: Data("12345678\n".utf8)
                )
            )
        }
        #expect(await secondWorker.writes.isEmpty)
    }

    @Test
    func brokerDoesNotAcceptAnOperationThatCompletesAfterExpiry()
        async throws
    {
        let fixture = LifecycleInteractiveBrokerFixture()
        let clock = MutableInteractiveBrokerClock(now: fixture.now)
        let worker = RecordingLifecycleInteractiveWorker(
            beforeWrite: {
                clock.set(
                    fixture.now.addingTimeInterval(61)
                )
            }
        )
        let broker = LifecycleInteractiveSessionBroker(
            worker: worker,
            now: { clock.read() }
        )
        _ = try await broker.handle(try fixture.startRequest())

        await #expect(
            throws:
                LifecycleInteractiveSessionBrokerError.sessionExpired
        ) {
            _ = try await broker.handle(
                try fixture.writeRequest(line: Data("{}\n".utf8))
            )
        }
    }

    @Test
    func brokerPreservesClosedWorkerFailureCategories() async throws {
        let fixture = LifecycleInteractiveBrokerFixture()
        let writeWorker = RecordingLifecycleInteractiveWorker(
            writeError:
                LifecycleInteractiveWorkerError.sessionLimitExceeded
        )
        let writeBroker = LifecycleInteractiveSessionBroker(
            worker: writeWorker,
            now: { fixture.now }
        )
        _ = try await writeBroker.handle(try fixture.startRequest())

        await #expect(
            throws:
                LifecycleInteractiveSessionBrokerError
                    .sessionLimitExceeded
        ) {
            _ = try await writeBroker.handle(
                try fixture.writeRequest(line: Data("{}\n".utf8))
            )
        }

        let readWorker = RecordingLifecycleInteractiveWorker(
            readError: LifecycleInteractiveWorkerError.lineLimitExceeded
        )
        let readBroker = LifecycleInteractiveSessionBroker(
            worker: readWorker,
            now: { fixture.now }
        )
        _ = try await readBroker.handle(try fixture.startRequest())

        await #expect(
            throws:
                LifecycleInteractiveSessionBrokerError.lineLimitExceeded
        ) {
            _ = try await readBroker.handle(fixture.readRequest())
        }
    }

    @Test
    func brokerRejectsConcurrentIOWhileACommittedOperationIsSuspended()
        async throws
    {
        let fixture = LifecycleInteractiveBrokerFixture()
        let worker = SuspendedFirstWriteLifecycleInteractiveWorker()
        let broker = LifecycleInteractiveSessionBroker(
            worker: worker,
            now: { fixture.now }
        )
        _ = try await broker.handle(try fixture.startRequest())

        let firstWrite = Task {
            try await broker.handle(
                try fixture.writeRequest(line: Data("{\"first\":1}\n".utf8))
            )
        }
        await worker.waitUntilFirstWriteIsSuspended()

        await #expect(
            throws:
                LifecycleInteractiveSessionBrokerError.sessionUnavailable
        ) {
            _ = try await broker.handle(
                try fixture.writeRequest(
                    line: Data("{\"second\":2}\n".utf8)
                )
            )
        }

        await worker.resumeFirstWrite()
        #expect(try await firstWrite.value.kind == .writeAccepted)
        #expect(await worker.writeCount == 1)
        #expect(await broker.invalidateAndRetire())
    }

    @Test
    func retireCanDrainACommittedSuspendedRead() async throws {
        let fixture = LifecycleInteractiveBrokerFixture()
        let worker = SuspendedLifecycleInteractiveWorker()
        let broker = LifecycleInteractiveSessionBroker(
            worker: worker,
            now: { fixture.now }
        )
        _ = try await broker.handle(try fixture.startRequest())

        let readTask = Task {
            try await broker.handle(fixture.readRequest())
        }
        await worker.waitUntilReadIsSuspended()

        let retired = try await broker.handle(
            fixture.retireRequest()
        )
        #expect(retired.kind == .retired)
        #expect(retired.drained == true)
        await #expect(
            throws:
                LifecycleInteractiveSessionBrokerError.sessionUnavailable
        ) {
            _ = try await readTask.value
        }
        #expect(await worker.retireCount == 1)
    }

    @Test
    func concurrentRetireAndInvalidationShareOneDrain() async throws {
        let fixture = LifecycleInteractiveBrokerFixture()
        let worker = SuspendedRetirementLifecycleInteractiveWorker()
        let broker = LifecycleInteractiveSessionBroker(
            worker: worker,
            now: { fixture.now }
        )
        _ = try await broker.handle(try fixture.startRequest())

        let retireTask = Task {
            try await broker.handle(fixture.retireRequest())
        }
        await worker.waitUntilRetireIsSuspended()
        let invalidateTask = Task {
            await broker.invalidateAndRetire()
        }
        await Task.yield()
        await worker.resumeRetire(
            observation: .retiredOwnedResources
        )

        #expect(
            try await retireTask.value.ownerRetirementObservation
                == .retiredOwnedResources
        )
        #expect(await invalidateTask.value)
        #expect(await worker.retireCount == 1)
    }

    @Test
    func freshRetirementDoesNotStartTheWorker() async throws {
        let fixture = LifecycleInteractiveBrokerFixture()
        let worker = RecordingLifecycleInteractiveWorker()
        let broker = LifecycleInteractiveSessionBroker(
            worker: worker,
            now: { fixture.now }
        )

        let response = try await broker.handle(
            fixture.retireRequest()
        )
        #expect(response.kind == .retired)
        #expect(response.drained == true)
        #expect(
            response.ownerRetirementObservation == .noOwnedResources
        )
        #expect(await worker.startCount == 0)
        #expect(await worker.retireCount == 1)
    }

    @Test
    func failedStartRemainsRetirableByTheCleanupOwner() async throws {
        let fixture = LifecycleInteractiveBrokerFixture()
        let worker = RecordingLifecycleInteractiveWorker(
            startError: LifecycleInteractiveWorkerTestError.failed
        )
        let broker = LifecycleInteractiveSessionBroker(
            worker: worker,
            now: { fixture.now }
        )

        await #expect(
            throws:
                LifecycleInteractiveSessionBrokerError.startFailed
        ) {
            _ = try await broker.handle(try fixture.startRequest())
        }
        let retired = try await broker.handle(
            fixture.retireRequest()
        )
        #expect(retired.kind == .retired)
        #expect(retired.drained == true)
        #expect(await worker.retireCount == 1)
    }

    @Test
    func unconfirmedDrainNeverProducesARetiredResponse() async throws {
        let fixture = LifecycleInteractiveBrokerFixture()
        let worker = RecordingLifecycleInteractiveWorker(
            retirementObservation: nil
        )
        let broker = LifecycleInteractiveSessionBroker(
            worker: worker,
            now: { fixture.now }
        )
        _ = try await broker.handle(try fixture.startRequest())

        await #expect(
            throws:
                LifecycleInteractiveSessionBrokerError.retireFailed
        ) {
            _ = try await broker.handle(fixture.retireRequest())
        }
        #expect(!(await broker.invalidateAndRetire()))
        #expect(await worker.retireCount == 1)
    }
}

private struct LifecycleInteractiveBrokerFixture {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let investigationID = LifecycleInvestigationID(
        rawValue: UUID(
            uuidString: "93939393-9393-4393-8393-939393939393"
        )!
    )
    let configurationSHA256 = String(repeating: "a", count: 64)
    let codexExecutableSHA256 = String(repeating: "b", count: 64)

    func startRequest(
        maximumLineBytes: Int = 1_024,
        maximumSessionBytes: Int = 8_192
    ) throws -> LifecycleInteractiveSessionRequest {
        try .start(
            investigationID: investigationID,
            operationID: UUID(),
            configurationSHA256: configurationSHA256,
            codexExecutableSHA256: codexExecutableSHA256,
            validBefore: now.addingTimeInterval(60),
            maximumLineBytes: maximumLineBytes,
            maximumSessionBytes: maximumSessionBytes
        )
    }

    func writeRequest(
        line: Data
    ) throws -> LifecycleInteractiveSessionRequest {
        try .write(
            investigationID: investigationID,
            operationID: UUID(),
            configurationSHA256: configurationSHA256,
            line: line
        )
    }

    func readRequest() -> LifecycleInteractiveSessionRequest {
        try! .read(
            investigationID: investigationID,
            operationID: UUID(),
            configurationSHA256: configurationSHA256
        )
    }

    func retireRequest() -> LifecycleInteractiveSessionRequest {
        try! .retire(
            investigationID: investigationID,
            operationID: UUID(),
            configurationSHA256: configurationSHA256
        )
    }
}

private enum LifecycleInteractiveWorkerTestError: Error {
    case failed
}

private actor RecordingLifecycleInteractiveWorker:
    LifecycleInteractiveWorkerDriving
{
    private(set) var startCount = 0
    private(set) var writes: [Data] = []
    private(set) var readCount = 0
    private(set) var retireCount = 0
    private var reads: [Data]
    private let startError: (any Error)?
    private let writeError: (any Error)?
    private let readError: (any Error)?
    private let retirementObservation:
        LifecycleInteractiveWorkerRetirementObservation?
    private let observedCodexExecutableSHA256: String?
    private let beforeWrite: @Sendable () -> Void

    init(
        reads: [Data] = [],
        startError: (any Error)? = nil,
        writeError: (any Error)? = nil,
        readError: (any Error)? = nil,
        retirementObservation:
            LifecycleInteractiveWorkerRetirementObservation? =
                .retiredOwnedResources,
        observedCodexExecutableSHA256: String? = nil,
        beforeWrite: @escaping @Sendable () -> Void = {}
    ) {
        self.reads = reads
        self.startError = startError
        self.writeError = writeError
        self.readError = readError
        self.retirementObservation = retirementObservation
        self.observedCodexExecutableSHA256 =
            observedCodexExecutableSHA256
        self.beforeWrite = beforeWrite
    }

    func start(
        _ configuration: LifecycleInteractiveWorkerConfiguration
    ) async throws -> LifecycleInteractiveWorkerStartObservation {
        startCount += 1
        if let startError {
            throw startError
        }
        return try LifecycleInteractiveWorkerStartObservation(
            codexExecutableSHA256:
                observedCodexExecutableSHA256
                    ?? configuration.codexExecutableSHA256
        )
    }

    func writeLine(_ line: Data) async throws {
        beforeWrite()
        if let writeError {
            throw writeError
        }
        writes.append(line)
    }

    func readLine(maximumBytes: Int) async throws -> Data? {
        readCount += 1
        if let readError {
            throw readError
        }
        guard !reads.isEmpty else {
            return nil
        }
        let line = reads.removeFirst()
        #expect(line.count <= maximumBytes)
        return line
    }

    func retire() async throws
        -> LifecycleInteractiveWorkerRetirementObservation
    {
        retireCount += 1
        guard let retirementObservation else {
            throw LifecycleInteractiveWorkerTestError.failed
        }
        if startCount == 0 {
            return .noOwnedResources
        }
        return retirementObservation
    }

    func appendRead(_ line: Data) {
        reads.append(line)
    }
}

private actor SuspendedLifecycleInteractiveWorker:
    LifecycleInteractiveWorkerDriving
{
    private(set) var retireCount = 0
    private var readContinuation:
        CheckedContinuation<Data?, any Error>?
    private var readWaiter: CheckedContinuation<Void, Never>?

    func start(
        _ configuration: LifecycleInteractiveWorkerConfiguration
    ) async throws -> LifecycleInteractiveWorkerStartObservation {
        try LifecycleInteractiveWorkerStartObservation(
            codexExecutableSHA256: configuration.codexExecutableSHA256
        )
    }

    func writeLine(_ line: Data) async throws {
        _ = line
    }

    func readLine(maximumBytes: Int) async throws -> Data? {
        _ = maximumBytes
        return try await withCheckedThrowingContinuation {
            readContinuation = $0
            readWaiter?.resume()
            readWaiter = nil
        }
    }

    func retire() async throws
        -> LifecycleInteractiveWorkerRetirementObservation
    {
        retireCount += 1
        readContinuation?.resume(
            throwing: LifecycleInteractiveWorkerTestError.failed
        )
        readContinuation = nil
        return .retiredOwnedResources
    }

    func waitUntilReadIsSuspended() async {
        if readContinuation != nil {
            return
        }
        await withCheckedContinuation {
            readWaiter = $0
        }
    }
}

private actor SuspendedFirstWriteLifecycleInteractiveWorker:
    LifecycleInteractiveWorkerDriving
{
    private(set) var writeCount = 0
    private var firstWriteContinuation:
        CheckedContinuation<Void, Never>?
    private var firstWriteWaiter: CheckedContinuation<Void, Never>?

    func start(
        _ configuration: LifecycleInteractiveWorkerConfiguration
    ) async throws -> LifecycleInteractiveWorkerStartObservation {
        try LifecycleInteractiveWorkerStartObservation(
            codexExecutableSHA256: configuration.codexExecutableSHA256
        )
    }

    func writeLine(_ line: Data) async throws {
        _ = line
        writeCount += 1
        guard writeCount == 1 else {
            throw LifecycleInteractiveWorkerTestError.failed
        }
        await withCheckedContinuation {
            firstWriteContinuation = $0
            firstWriteWaiter?.resume()
            firstWriteWaiter = nil
        }
    }

    func readLine(maximumBytes: Int) async throws -> Data? {
        _ = maximumBytes
        return nil
    }

    func retire() async throws
        -> LifecycleInteractiveWorkerRetirementObservation
    {
        firstWriteContinuation?.resume()
        firstWriteContinuation = nil
        return .retiredOwnedResources
    }

    func waitUntilFirstWriteIsSuspended() async {
        if firstWriteContinuation != nil {
            return
        }
        await withCheckedContinuation {
            firstWriteWaiter = $0
        }
    }

    func resumeFirstWrite() {
        firstWriteContinuation?.resume()
        firstWriteContinuation = nil
    }
}

private actor SuspendedRetirementLifecycleInteractiveWorker:
    LifecycleInteractiveWorkerDriving
{
    private(set) var retireCount = 0
    private var retireContinuation:
        CheckedContinuation<
            LifecycleInteractiveWorkerRetirementObservation,
            Never
        >?
    private var retireWaiter: CheckedContinuation<Void, Never>?

    func start(
        _ configuration: LifecycleInteractiveWorkerConfiguration
    ) async throws -> LifecycleInteractiveWorkerStartObservation {
        try LifecycleInteractiveWorkerStartObservation(
            codexExecutableSHA256: configuration.codexExecutableSHA256
        )
    }

    func writeLine(_ line: Data) async throws {
        _ = line
    }

    func readLine(maximumBytes: Int) async throws -> Data? {
        _ = maximumBytes
        return nil
    }

    func retire() async throws
        -> LifecycleInteractiveWorkerRetirementObservation
    {
        retireCount += 1
        return await withCheckedContinuation {
            retireContinuation = $0
            retireWaiter?.resume()
            retireWaiter = nil
        }
    }

    func waitUntilRetireIsSuspended() async {
        if retireContinuation != nil {
            return
        }
        await withCheckedContinuation {
            retireWaiter = $0
        }
    }

    func resumeRetire(
        observation: LifecycleInteractiveWorkerRetirementObservation
    ) {
        retireContinuation?.resume(returning: observation)
        retireContinuation = nil
    }
}

private final class MutableInteractiveBrokerClock:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var now: Date

    init(now: Date) {
        self.now = now
    }

    func read() -> Date {
        lock.withLock { now }
    }

    func set(_ value: Date) {
        lock.withLock {
            now = value
        }
    }
}
