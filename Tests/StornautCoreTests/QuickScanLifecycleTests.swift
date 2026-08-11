import Foundation
import Testing
@testable import StornautCore

@Test
func quickScanEmitsMonotonicStagesAndPersistsBoundedBatches() async throws {
    let fixture = try QuickScanFixture(fileCount: 12)
    defer { fixture.remove() }
    let producerCompletion = CompletionFlag()
    let store = RecordingScanStore(
        onFirstSnapshotBatch: {
            producerCompletion.recordFirstFact()
        }
    )
    let writer = ScanSessionWriter(
        store: store,
        volumeSampler: StaticVolumeSampler(),
        now: IncrementingDateSource().now
    )
    let request = ScanRequest(
        rootURL: fixture.rootURL,
        maximumWorkers: 2,
        persistenceBatchSize: 3,
        onCompletion: { producerCompletion.markComplete() }
    )

    let events = try await collectQuickScanEvents(
        try await writer.run(request)
    )

    #expect(
        events.compactMap(\.stage)
            == QuickScanStage.allCases
    )
    let facts = events.compactMap(\.fact)
    #expect(facts.first?.volumeBaseline != nil)
    #expect(
        facts.compactMap(\.pathSnapshot).contains {
            $0.relativePath == "files/0.bin"
        }
    )
    let terminal = try #require(events.compactMap(\.terminalSession).last)
    #expect(terminal.terminalState == .completed)
    #expect(terminal.completedScopes.map(\.id) == [request.scopeID])
    #expect(terminal.unfinishedScopes.isEmpty)
    #expect(await store.savedSession(id: request.sessionID) == terminal)
    #expect(await store.maximumSnapshotBatchSize <= 3)
    #expect(await store.maximumSnapshotBatchSize > 0)
    #expect(await store.savedSnapshotCount == facts.compactMap(\.pathSnapshot).count)
    #expect(await store.savedBaselines.count == 1)
    #expect(
        events.contains {
            guard case let .progress(progress) = $0 else {
                return false
            }
            return progress.scopeID == request.scopeID
                && progress.currentRelativePath.rawValue == "files/0.bin"
                && progress.counters.completedEntries > 0
        }
    )

    let firstPathIndex = try #require(
        events.firstIndex { $0.fact?.pathSnapshot != nil }
    )
    let terminalIndex = try #require(
        events.firstIndex { $0.terminalSession != nil }
    )
    #expect(firstPathIndex < terminalIndex)
    #expect(producerCompletion.wasCompleteWhenFirstFactObserved == false)
}

@Test
func quickScanDefaultBatchKeepsFirstFactDurableThenUsesBoundedBulkWrites()
    async throws
{
    let fixture = try QuickScanFixture(fileCount: 4_200)
    defer { fixture.remove() }
    let store = RecordingScanStore()
    let writer = ScanSessionWriter(
        store: store,
        volumeSampler: StaticVolumeSampler(),
        now: IncrementingDateSource().now,
        defersProductFinalization: true
    )
    let request = ScanRequest(
        rootURL: fixture.rootURL,
        maximumWorkers: 2
    )

    _ = try await collectQuickScanEvents(
        try await writer.run(request)
    )

    #expect(await store.snapshotBatchSizes.first == 1)
    #expect(
        await store.snapshotBatchSizes.dropFirst().contains {
            $0 > 100
        }
    )
    #expect(
        await store.maximumSnapshotBatchSize
            <= ScanRequest.maximumPersistenceBatchSize
    )
    #expect(await store.savedSnapshotCount == 4_202)
}

@Test
func quickScanPersistsLocalizedIssuesAsPartialTruth() async throws {
    let fixture = try QuickScanFixture(fileCount: 1)
    defer { fixture.remove() }
    let blockedURL = fixture.rootURL.appending(path: "blocked")
    try FileManager.default.createDirectory(
        at: blockedURL,
        withIntermediateDirectories: true
    )
    try Data("hidden".utf8).write(
        to: blockedURL.appending(path: "hidden.txt")
    )
    let store = RecordingScanStore()
    let request = ScanRequest(
        rootURL: fixture.rootURL,
        maximumWorkers: 1,
        persistenceBatchSize: 2,
        testHooks: SurveyorTestHooks(
            issueBeforeDirectoryRead: { url in
                url.standardizedFileURL == blockedURL.standardizedFileURL
                    ? .permissionDenied
                    : nil
            }
        )
    )
    let writer = ScanSessionWriter(
        store: store,
        volumeSampler: StaticVolumeSampler(),
        now: IncrementingDateSource().now
    )

    let events = try await collectQuickScanEvents(
        try await writer.run(request)
    )

    #expect(
        events.contains {
            $0.issue?.issue == .permissionDenied
                && $0.issue?.relativePath.rawValue == "blocked"
        }
    )
    let terminal = try #require(events.compactMap(\.terminalSession).last)
    #expect(terminal.terminalState == .partial)
    #expect(terminal.completedScopes.isEmpty)
    #expect(
        terminal.unfinishedScopes
            == [
                UnfinishedScanScope(
                    id: request.scopeID,
                    rootPath: try PersistedPath(
                        validating: fixture.rootURL.path
                    ),
                    reason: .permissionDenied
                ),
            ]
    )
    #expect(
        await store.savedSnapshots.contains {
            $0.relativePath == "blocked"
                && $0.measurementStatus == .permissionDenied
        }
    )
}

@Test
func quickScanDirectoryReadFailureCannotPersistCompleted() async throws {
    let fixture = try QuickScanFixture(fileCount: 1)
    defer { fixture.remove() }
    let store = RecordingScanStore()
    let request = ScanRequest(
        rootURL: fixture.rootURL,
        maximumWorkers: 1,
        testHooks: SurveyorTestHooks(
            directoryReadError: { url, readCount in
                url.standardizedFileURL == fixture.rootURL.standardizedFileURL
                    && readCount == 1
                    ? EIO
                    : nil
            }
        )
    )
    let writer = ScanSessionWriter(
        store: store,
        volumeSampler: StaticVolumeSampler(),
        now: IncrementingDateSource().now
    )

    let events = try await collectQuickScanEvents(
        try await writer.run(request)
    )
    let terminal = try #require(events.compactMap(\.terminalSession).last)

    #expect(terminal.terminalState == .failed)
    #expect(terminal.unfinishedScopes.map(\.reason) == [.scannerFailure])
    #expect(await store.savedSessions.allSatisfy {
        $0.terminalState != .completed
    })
}

@Test
func quickScanCancellationKeepsCommittedFactsAndUnfinishedScope() async throws {
    let fixture = try QuickScanFixture(fileCount: 120, deep: true)
    defer { fixture.remove() }
    let store = RecordingScanStore()
    let request = ScanRequest(
        rootURL: fixture.rootURL,
        maximumWorkers: 2,
        persistenceBatchSize: 1,
        testHooks: SurveyorTestHooks(
            beforeDirectoryRead: { _ in usleep(5_000) }
        )
    )
    let writer = ScanSessionWriter(
        store: store,
        volumeSampler: StaticVolumeSampler(),
        now: IncrementingDateSource().now
    )
    let stream = try await writer.run(request)
    let collector = Task {
        try await collectQuickScanEvents(stream)
    }
    try await waitForSavedSnapshots(store, minimum: 2)

    await writer.cancelActiveScan()
    let events = try await collector.value
    let terminal = try #require(events.compactMap(\.terminalSession).last)

    #expect(terminal.terminalState == .cancelled)
    #expect(terminal.completedScopes.isEmpty)
    #expect(terminal.unfinishedScopes.map(\.reason) == [.cancelled])
    #expect(await store.savedSnapshotCount >= 2)
    #expect(await writer.hasActiveScan == false)
}

@Test
func quickScanContinuesWhenEventConsumerNavigatesAway() async throws {
    let fixture = try QuickScanFixture(fileCount: 80, deep: true)
    defer { fixture.remove() }
    let store = RecordingScanStore()
    let request = ScanRequest(
        rootURL: fixture.rootURL,
        maximumWorkers: 2,
        persistenceBatchSize: 2,
        testHooks: SurveyorTestHooks(
            beforeDirectoryRead: { _ in usleep(2_000) }
        )
    )
    let writer = ScanSessionWriter(
        store: store,
        volumeSampler: StaticVolumeSampler(),
        now: IncrementingDateSource().now
    )
    let consumer = Task {
        let stream = try await writer.run(request)
        for try await event in stream {
            if event.fact?.pathSnapshot != nil {
                break
            }
        }
    }

    try await consumer.value
    #expect(await writer.hasActiveScan)
    let terminal = try await waitForTerminalSession(
        store,
        id: request.sessionID,
        state: .completed
    )

    #expect(terminal.completedScopes.map(\.id) == [request.scopeID])
    #expect(await store.savedSnapshotCount > 1)
    #expect(await writer.hasActiveScan == false)
}

@Test
func quickScanConsumerBackpressureFailsWithoutSilentSuccess() async throws {
    let fixture = try QuickScanFixture(fileCount: 24)
    defer { fixture.remove() }
    let store = RecordingScanStore()
    let request = ScanRequest(
        rootURL: fixture.rootURL,
        maximumWorkers: 2,
        streamBufferCapacity: 32,
        lifecycleEventBufferCapacity: 1,
        persistenceBatchSize: 2
    )
    let writer = ScanSessionWriter(
        store: store,
        volumeSampler: StaticVolumeSampler(),
        now: IncrementingDateSource().now
    )
    let stream = try await writer.run(request)

    let failed = try await waitForTerminalSession(
        store,
        id: request.sessionID,
        state: .failed
    )
    #expect(failed.unfinishedScopes.map(\.reason) == [.scannerFailure])
    await #expect(
        throws: QuickScanLifecycleError.eventBufferExceeded(
            limit: request.lifecycleEventBufferCapacity
        )
    ) {
        _ = try await collectQuickScanEvents(stream)
    }
    #expect(
        await store.savedSession(id: request.sessionID)?
            .terminalState != .completed
    )
}

@Test
func quickScanStoreFailureStopsProducerAndNeverWritesSuccess() async throws {
    let fixture = try QuickScanFixture(fileCount: 8)
    defer { fixture.remove() }
    let store = RecordingScanStore(failSnapshotBatch: 1)
    let request = ScanRequest(
        rootURL: fixture.rootURL,
        maximumWorkers: 1,
        persistenceBatchSize: 2
    )
    let writer = ScanSessionWriter(
        store: store,
        volumeSampler: StaticVolumeSampler(),
        now: IncrementingDateSource().now
    )

    let events = try await collectQuickScanEvents(
        try await writer.run(request)
    )

    let terminal = try #require(events.compactMap(\.terminalSession).last)
    #expect(terminal.terminalState == .failed)
    #expect(terminal.unfinishedScopes.map(\.reason) == [.storeFailure])
    #expect(await store.savedSession(id: request.sessionID) == terminal)
    #expect(await store.savedSessions.allSatisfy {
        $0.terminalState != .completed
    })
    #expect(await writer.hasActiveScan == false)
}

@Test
func quickScanTreatsStoreCancellationAsCancellation() async throws {
    let fixture = try QuickScanFixture(fileCount: 4)
    defer { fixture.remove() }
    let store = RecordingScanStore(cancelSnapshotBatch: 1)
    let request = ScanRequest(
        rootURL: fixture.rootURL,
        maximumWorkers: 1,
        persistenceBatchSize: 2
    )
    let writer = ScanSessionWriter(
        store: store,
        volumeSampler: StaticVolumeSampler(),
        now: IncrementingDateSource().now
    )

    let events = try await collectQuickScanEvents(
        try await writer.run(request)
    )

    let terminal = try #require(events.compactMap(\.terminalSession).last)
    #expect(terminal.terminalState == .cancelled)
    #expect(terminal.unfinishedScopes.map(\.reason) == [.cancelled])
    #expect(await store.savedSessions.allSatisfy {
        $0.terminalState != .failed
    })
}

@Test
func quickScanRejectsConcurrentRunAndRootReplacement() async throws {
    let fixture = try QuickScanFixture(fileCount: 32, deep: true)
    defer { fixture.remove() }
    let store = RecordingScanStore()
    let replacement = QuickScanRootReplacement(rootURL: fixture.rootURL)
    let request = ScanRequest(
        rootURL: fixture.rootURL,
        maximumWorkers: 1,
        persistenceBatchSize: 2,
        testHooks: SurveyorTestHooks(
            beforeDirectoryRead: { url in
                if url.standardizedFileURL
                    == fixture.rootURL.standardizedFileURL
                {
                    replacement.replaceOnce()
                }
            }
        )
    )
    let writer = ScanSessionWriter(
        store: store,
        volumeSampler: StaticVolumeSampler(),
        now: IncrementingDateSource().now
    )
    let stream = try await writer.run(request)

    await #expect(throws: QuickScanLifecycleError.scanAlreadyRunning) {
        _ = try await writer.run(
            ScanRequest(rootURL: fixture.rootURL)
        )
    }
    let events = try await collectQuickScanEvents(stream)
    let terminal = try #require(events.compactMap(\.terminalSession).last)
    #expect(terminal.terminalState == .failed)
    #expect(terminal.unfinishedScopes.map(\.reason) == [.scannerFailure])
    #expect(await store.savedSnapshots.map(\.relativePath) == ["."])
}

@Test
func quickScanPersistsBaselineAndTerminalSessionAcrossStoreReopen() async throws {
    let fixture = try QuickScanFixture(fileCount: 3)
    defer { fixture.remove() }
    let storeRoot = FileManager.default.temporaryDirectory.appending(
        path: "stornaut-quick-scan-store-\(UUID().uuidString)"
    )
    defer { try? FileManager.default.removeItem(at: storeRoot) }
    try FileManager.default.createDirectory(
        at: storeRoot,
        withIntermediateDirectories: true
    )
    let configuration = try LocalStoreConfiguration(
        applicationSupportBaseURL: storeRoot.appending(
            path: "Application Support"
        ),
        cachesBaseURL: storeRoot.appending(path: "Caches")
    )
    let request = ScanRequest(
        rootURL: fixture.rootURL,
        maximumWorkers: 1,
        persistenceBatchSize: 2
    )
    let firstStore = try EvidenceStore(configuration: configuration)
    let writer = ScanSessionWriter(
        store: firstStore,
        volumeSampler: StaticVolumeSampler(),
        now: IncrementingDateSource().now
    )

    _ = try await collectQuickScanEvents(try await writer.run(request))

    let reopened = try EvidenceStore(configuration: configuration)
    let session = try await reopened.scanSession(id: request.sessionID)
    let baseline = try await reopened.volumeBaseline(
        sessionID: request.sessionID,
        scopeID: request.scopeID
    )
    let snapshots = try await reopened.pathSnapshots(
        sessionID: request.sessionID,
        limit: 100,
        offset: 0
    )
    #expect(session?.terminalState == .completed)
    #expect(baseline?.rootPath.rawValue == fixture.rootURL.path)
    #expect(baseline?.source.kind == .volumeResourceValues)
    #expect(!snapshots.records.isEmpty)
}

@Test
func quickScanRejectsInvalidLifecycleBoundsBeforeStarting() async throws {
    let fixture = try QuickScanFixture(fileCount: 1)
    defer { fixture.remove() }
    let store = RecordingScanStore()
    let writer = ScanSessionWriter(
        store: store,
        volumeSampler: StaticVolumeSampler()
    )

    await #expect(
        throws: QuickScanLifecycleError.invalidPersistenceBatchSize
    ) {
        _ = try await writer.run(
            ScanRequest(
                rootURL: fixture.rootURL,
                persistenceBatchSize: 0
            )
        )
    }
    await #expect(
        throws: QuickScanLifecycleError.invalidPersistenceBatchSize
    ) {
        _ = try await writer.run(
            ScanRequest(
                rootURL: fixture.rootURL,
                    persistenceBatchSize:
                        ScanRequest.maximumPersistenceBatchSize + 1
            )
        )
    }
    await #expect(
        throws: QuickScanLifecycleError.invalidEventBufferCapacity
    ) {
        _ = try await writer.run(
            ScanRequest(
                rootURL: fixture.rootURL,
                lifecycleEventBufferCapacity: 0
            )
        )
    }
    await #expect(
        throws: QuickScanLifecycleError.invalidEventBufferCapacity
    ) {
        _ = try await writer.run(
            ScanRequest(
                rootURL: fixture.rootURL,
                lifecycleEventBufferCapacity:
                    ScanRequest.maximumLifecycleEventBufferCapacity + 1
            )
        )
    }
    #expect(await writer.hasActiveScan == false)
    #expect(await store.savedSessions.isEmpty)
}

@Test
func quickScanDuplicateSessionIDDoesNotOverwriteExistingHistory() async throws {
    let fixture = try QuickScanFixture(fileCount: 1)
    defer { fixture.remove() }
    let storeRoot = FileManager.default.temporaryDirectory.appending(
        path: "stornaut-quick-scan-duplicate-\(UUID().uuidString)"
    )
    try FileManager.default.createDirectory(
        at: storeRoot,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: storeRoot) }
    let configuration = try LocalStoreConfiguration(
        applicationSupportBaseURL: storeRoot.appending(
            path: "Application Support"
        ),
        cachesBaseURL: storeRoot.appending(path: "Caches")
    )
    let store = try EvidenceStore(configuration: configuration)
    let request = ScanRequest(rootURL: fixture.rootURL, maximumWorkers: 1)
    let writer = ScanSessionWriter(
        store: store,
        volumeSampler: StaticVolumeSampler(),
        now: IncrementingDateSource().now
    )
    _ = try await collectQuickScanEvents(try await writer.run(request))
    let existing = try #require(
        try await store.scanSession(id: request.sessionID)
    )

    let secondWriter = ScanSessionWriter(
        store: store,
        volumeSampler: StaticVolumeSampler(),
        now: IncrementingDateSource().now
    )
    await #expect(throws: QuickScanLifecycleError.terminalPersistenceFailed) {
        _ = try await collectQuickScanEvents(
            try await secondWriter.run(request)
        )
    }

    #expect(try await store.scanSession(id: request.sessionID) == existing)
}

@Test
func volumeBaselineRejectsImpossibleCapacityAndNonDirectoryRoot() throws {
    let fixture = try QuickScanFixture(fileCount: 1)
    defer { fixture.remove() }
    let request = ScanRequest(rootURL: fixture.rootURL)
    let valid = try StaticVolumeSampler().sample(
        request: request,
        sampledAt: Date(timeIntervalSince1970: 1)
    )

    #expect(throws: DomainContractError.invalidMeasurement) {
        _ = try VolumeBaseline(
            sessionID: valid.sessionID,
            scopeID: valid.scopeID,
            rootPath: valid.rootPath,
            rootIdentity: valid.rootIdentity,
            totalCapacity: ByteCount(1),
            availableCapacity: ByteCount(2),
            availableCapacityForImportantUsage: nil,
            availableCapacityForOpportunisticUsage: nil,
            volumeIsReadOnly: false,
            source: valid.source
        )
    }
    #expect(throws: DomainContractError.invalidMeasurement) {
        _ = try VolumeBaseline(
            sessionID: valid.sessionID,
            scopeID: valid.scopeID,
            rootPath: valid.rootPath,
            rootIdentity: valid.rootIdentity,
            totalCapacity: nil,
            availableCapacity: nil,
            availableCapacityForImportantUsage: nil,
            availableCapacityForOpportunisticUsage: nil,
            volumeIsReadOnly: nil,
            source: AccountingSource(
                kind: .classifier,
                identifier: try DomainToken(validating: "invalid.source"),
                sampledAt: valid.source.sampledAt
            )
        )
    }
    let fileIdentity = try FileIdentity(
        device: valid.rootIdentity.device,
        inode: valid.rootIdentity.inode,
        mode: UInt16(S_IFREG),
        ownerUserID: valid.rootIdentity.ownerUserID,
        ownerGroupID: valid.rootIdentity.ownerGroupID,
        size: 0,
        allocatedBytes: 0,
        modificationSeconds: 0,
        modificationNanoseconds: 0
    )
    #expect(throws: DomainContractError.invalidMeasurement) {
        _ = try VolumeBaseline(
            sessionID: valid.sessionID,
            scopeID: valid.scopeID,
            rootPath: valid.rootPath,
            rootIdentity: fileIdentity,
            totalCapacity: nil,
            availableCapacity: nil,
            availableCapacityForImportantUsage: nil,
            availableCapacityForOpportunisticUsage: nil,
            volumeIsReadOnly: nil,
            source: valid.source
        )
    }
}

private func collectQuickScanEvents(
    _ stream: AsyncThrowingStream<QuickScanEvent, Error>
) async throws -> [QuickScanEvent] {
    var events: [QuickScanEvent] = []
    for try await event in stream {
        events.append(event)
    }
    return events
}

private func waitForSavedSnapshots(
    _ store: RecordingScanStore,
    minimum: Int
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(5))
    while await store.savedSnapshotCount < minimum {
        guard clock.now < deadline else {
            throw QuickScanTestError.timedOut
        }
        try await Task.sleep(for: .milliseconds(10))
    }
}

private func waitForTerminalSession(
    _ store: RecordingScanStore,
    id: ScanSessionID,
    state: ScanTerminalState
) async throws -> ScanSession {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(5))
    while clock.now < deadline {
        if let session = await store.savedSession(id: id),
           session.terminalState == state
        {
            return session
        }
        try await Task.sleep(for: .milliseconds(10))
    }
    throw QuickScanTestError.timedOut
}

private actor RecordingScanStore: ScanSessionPersisting {
    private(set) var savedSessions: [ScanSession] = []
    private(set) var savedSnapshots: [PathSnapshot] = []
    private(set) var savedBaselines: [VolumeBaseline] = []
    private(set) var maximumSnapshotBatchSize = 0
    private(set) var snapshotBatchSizes: [Int] = []
    private var snapshotBatchCount = 0
    private let failSnapshotBatch: Int?
    private let cancelSnapshotBatch: Int?
    private let onFirstSnapshotBatch: @Sendable () -> Void

    init(
        failSnapshotBatch: Int? = nil,
        cancelSnapshotBatch: Int? = nil,
        onFirstSnapshotBatch: @escaping @Sendable () -> Void = {}
    ) {
        self.failSnapshotBatch = failSnapshotBatch
        self.cancelSnapshotBatch = cancelSnapshotBatch
        self.onFirstSnapshotBatch = onFirstSnapshotBatch
    }

    func beginScanSession(_ session: ScanSession) async throws {
        if savedSessions.contains(where: { $0.id == session.id }) {
            throw QuickScanTestError.duplicateSession
        }
        savedSessions.append(session)
    }

    func saveScanSession(_ session: ScanSession) async throws {
        savedSessions.append(session)
    }

    func savePathSnapshots(_ snapshots: [PathSnapshot]) async throws {
        snapshotBatchCount += 1
        if snapshotBatchCount == cancelSnapshotBatch {
            throw CancellationError()
        }
        if snapshotBatchCount == failSnapshotBatch {
            throw QuickScanTestError.injectedStoreFailure
        }
        if savedSnapshots.isEmpty, !snapshots.isEmpty {
            onFirstSnapshotBatch()
        }
        maximumSnapshotBatchSize = max(
            maximumSnapshotBatchSize,
            snapshots.count
        )
        snapshotBatchSizes.append(snapshots.count)
        savedSnapshots.append(contentsOf: snapshots)
    }

    func saveVolumeBaseline(_ baseline: VolumeBaseline) async throws {
        savedBaselines.append(baseline)
    }

    func savedSession(id: ScanSessionID) -> ScanSession? {
        savedSessions.last { $0.id == id }
    }

    var savedSnapshotCount: Int {
        savedSnapshots.count
    }
}

private struct StaticVolumeSampler: VolumeBaselineSampling {
    func sample(
        request: ScanRequest,
        sampledAt: Date
    ) throws -> VolumeBaseline {
        var info = stat()
        guard lstat(request.rootURL.path, &info) == 0 else {
            throw QuickScanTestError.invalidFixture
        }
        return try VolumeBaseline(
            sessionID: request.sessionID,
            scopeID: request.scopeID,
            rootPath: PersistedPath(validating: request.rootURL.path),
            rootIdentity: FileIdentity(
                device: UInt64(bitPattern: Int64(info.st_dev)),
                inode: UInt64(info.st_ino),
                mode: UInt16(info.st_mode),
                ownerUserID: info.st_uid,
                ownerGroupID: info.st_gid,
                size: Int64(info.st_size),
                allocatedBytes: Int64(info.st_blocks) * 512,
                modificationSeconds: Int64(info.st_mtimespec.tv_sec),
                modificationNanoseconds: Int64(info.st_mtimespec.tv_nsec)
            ),
            totalCapacity: ByteCount(1_000_000),
            availableCapacity: ByteCount(400_000),
            availableCapacityForImportantUsage: ByteCount(450_000),
            availableCapacityForOpportunisticUsage: ByteCount(350_000),
            volumeIsReadOnly: false,
            source: AccountingSource(
                kind: .volumeResourceValues,
                identifier: try DomainToken(
                    validating: "fixture.volume-resource-values"
                ),
                sampledAt: sampledAt
            )
        )
    }
}

private final class IncrementingDateSource: @unchecked Sendable {
    private let lock = NSLock()
    private var milliseconds: TimeInterval = 1_786_240_000

    func now() -> Date {
        lock.withLock {
            milliseconds += 0.001
            return Date(timeIntervalSince1970: milliseconds)
        }
    }
}

private final class CompletionFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false
    private var firstFactSawCompletion: Bool?

    var wasCompleteWhenFirstFactObserved: Bool? {
        lock.withLock { firstFactSawCompletion }
    }

    func markComplete() {
        lock.withLock {
            completed = true
        }
    }

    func recordFirstFact() {
        lock.withLock {
            if firstFactSawCompletion == nil {
                firstFactSawCompletion = completed
            }
        }
    }
}

private struct QuickScanFixture {
    let parentURL: URL
    let rootURL: URL

    init(fileCount: Int, deep: Bool = false) throws {
        parentURL = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-quick-scan-\(UUID().uuidString)"
        )
        rootURL = parentURL.appending(path: "root")
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
        for index in 0..<fileCount {
            let relative = deep
                ? "files/\(index)/a/b/value.bin"
                : "files/\(index).bin"
            let url = rootURL.appending(path: relative)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data(repeating: UInt8(index % 255), count: 64).write(to: url)
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: parentURL)
    }
}

private final class QuickScanRootReplacement: @unchecked Sendable {
    private let lock = NSLock()
    private let rootURL: URL
    private var replaced = false

    init(rootURL: URL) {
        self.rootURL = rootURL
    }

    func replaceOnce() {
        lock.withLock {
            guard !replaced else {
                return
            }
            replaced = true
            try? FileManager.default.moveItem(
                at: rootURL,
                to: rootURL.appendingPathExtension("old")
            )
            try? FileManager.default.createDirectory(
                at: rootURL,
                withIntermediateDirectories: true
            )
        }
    }
}

private extension QuickScanEvent {
    var stage: QuickScanStage? {
        guard case let .stageChanged(stage) = self else {
            return nil
        }
        return stage
    }

    var fact: QuickScanFact? {
        guard case let .factObserved(fact) = self else {
            return nil
        }
        return fact
    }

    var issue: QuickScanIssueObservation? {
        guard case let .issueObserved(issue) = self else {
            return nil
        }
        return issue
    }

    var terminalSession: ScanSession? {
        guard case let .terminal(session) = self else {
            return nil
        }
        return session
    }
}

private extension QuickScanFact {
    var volumeBaseline: VolumeBaseline? {
        guard case let .volumeBaseline(baseline) = self else {
            return nil
        }
        return baseline
    }

    var pathSnapshot: PathSnapshot? {
        guard case let .pathSnapshot(snapshot) = self else {
            return nil
        }
        return snapshot
    }
}

private enum QuickScanTestError: Error {
    case duplicateSession
    case injectedStoreFailure
    case invalidFixture
    case timedOut
}
