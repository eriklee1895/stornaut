import Darwin
import Foundation
import Testing
@testable import StornautCore

@Test
func directoryEntryDecoderReadsOnlyTheVariableLengthRecord() throws {
    let name = "line\nCafé.txt"
    try withDirectoryEntryRecord(nameBytes: Array(name.utf8)) { entry in
        let decoded = try decodeDirectoryEntryName(entry)
        #expect(decoded == name)
    }

    let maximumName = String(repeating: "a", count: 1_023)
    try withDirectoryEntryRecord(
        nameBytes: Array(maximumName.utf8)
    ) { entry in
        let decoded = try decodeDirectoryEntryName(entry)
        #expect(decoded == maximumName)
    }
}

@Test
func directoryEntryDecoderRejectsMalformedRecordBoundsAndTermination() throws {
    try withDirectoryEntryRecord(nameBytes: Array("bounded".utf8)) { entry in
        let raw = UnsafeMutableRawPointer(entry)
        let nameLengthOffset = try #require(
            MemoryLayout<dirent>.offset(of: \.d_namlen)
        )
        let recordLengthOffset = try #require(
            MemoryLayout<dirent>.offset(of: \.d_reclen)
        )
        raw.storeBytes(
            of: raw.load(
                fromByteOffset: recordLengthOffset,
                as: UInt16.self
            ),
            toByteOffset: nameLengthOffset,
            as: UInt16.self
        )
        #expect(throws: DirectoryEntryDecodingError.invalidRecord) {
            _ = try decodeDirectoryEntryName(entry)
        }
    }

    try withDirectoryEntryRecord(
        nameBytes: Array("unterminated".utf8)
    ) { entry in
        let raw = UnsafeMutableRawPointer(entry)
        let nameOffset = try #require(
            MemoryLayout<dirent>.offset(of: \.d_name)
        )
        let nameLengthOffset = try #require(
            MemoryLayout<dirent>.offset(of: \.d_namlen)
        )
        let nameLength = Int(
            raw.load(
                fromByteOffset: nameLengthOffset,
                as: UInt16.self
            )
        )
        raw.storeBytes(
            of: UInt8(ascii: "x"),
            toByteOffset: nameOffset + nameLength,
            as: UInt8.self
        )
        #expect(throws: DirectoryEntryDecodingError.invalidRecord) {
            _ = try decodeDirectoryEntryName(entry)
        }
    }

    try withDirectoryEntryRecord(nameBytes: [0xFF]) { entry in
        #expect(throws: DirectoryEntryDecodingError.invalidRecord) {
            _ = try decodeDirectoryEntryName(entry)
        }
    }
}

@Test
func surveyorStreamsFilesDirectoriesSparseFilesAndSymlinksWithoutFollowingLinks() async throws {
    let fixture = try SurveyorFixture()
    defer { fixture.remove() }
    let regularURL = fixture.rootURL.appending(path: "regular.bin")
    let sparseURL = fixture.rootURL.appending(path: "sparse.bin")
    let packageURL = fixture.rootURL.appending(path: "Example.bundle")
    let packageFileURL = packageURL.appending(path: "Contents/data.bin")
    let outsideURL = fixture.parentURL.appending(path: "outside")
    let outsideFileURL = outsideURL.appending(path: "secret.bin")
    let linkURL = fixture.rootURL.appending(path: "outside-link")
    try fixture.write(Data(repeating: 0x41, count: 4_096), to: regularURL)
    try fixture.createSparseFile(at: sparseURL, logicalBytes: 16 * 1_024 * 1_024)
    try fixture.write(Data(repeating: 0x42, count: 2_048), to: packageFileURL)
    try fixture.write(Data("outside".utf8), to: outsideFileURL)
    try FileManager.default.createSymbolicLink(
        at: linkURL,
        withDestinationURL: outsideURL
    )

    let snapshots = try await collectSnapshots(
        Surveyor().scan(
            ScanRequest(rootURL: fixture.rootURL, maximumWorkers: 3)
        )
    )
    let byPath = Dictionary(
        uniqueKeysWithValues: snapshots.map { ($0.relativePath, $0) }
    )

    #expect(byPath["."]?.kind == .directory)
    #expect(byPath["regular.bin"]?.kind == .regularFile)
    #expect(byPath["regular.bin"]?.logicalBytes == 4_096)
    #expect(byPath["regular.bin"]?.allocatedBytes ?? 0 > 0)
    #expect(
        byPath["regular.bin"]?.snapshot.fileIdentity?.ownerUserID == getuid()
    )
    let sparseSnapshot = try #require(byPath["sparse.bin"])
    #expect(sparseSnapshot.logicalBytes == Int64(16 * 1_024 * 1_024))
    #expect(
        (sparseSnapshot.allocatedBytes ?? .max)
            < (sparseSnapshot.logicalBytes ?? 0)
    )
    #expect(byPath["Example.bundle"]?.kind == .directory)
    #expect(byPath["Example.bundle/Contents/data.bin"]?.kind == .regularFile)
    #expect(byPath["outside-link"]?.kind == .symbolicLink)
    #expect(byPath["outside-link"]?.snapshot.symlinkTarget == outsideURL.path)
    #expect(!byPath.keys.contains(where: { $0.contains("secret.bin") }))
    #expect(snapshots.last?.progress.completedEntries == snapshots.count)
}

private func withDirectoryEntryRecord(
    nameBytes: [UInt8],
    operation: (UnsafeMutablePointer<dirent>) throws -> Void
) throws {
    let recordLengthOffset = try #require(
        MemoryLayout<dirent>.offset(of: \.d_reclen)
    )
    let nameLengthOffset = try #require(
        MemoryLayout<dirent>.offset(of: \.d_namlen)
    )
    let nameOffset = try #require(
        MemoryLayout<dirent>.offset(of: \.d_name)
    )
    let unalignedLength = nameOffset + nameBytes.count + 1
    let recordLength = (unalignedLength + 3) & ~3
    let raw = UnsafeMutableRawPointer.allocate(
        byteCount: recordLength,
        alignment: MemoryLayout<UInt64>.alignment
    )
    defer { raw.deallocate() }
    raw.initializeMemory(as: UInt8.self, repeating: 0, count: recordLength)
    raw.storeBytes(
        of: UInt16(recordLength),
        toByteOffset: recordLengthOffset,
        as: UInt16.self
    )
    raw.storeBytes(
        of: UInt16(nameBytes.count),
        toByteOffset: nameLengthOffset,
        as: UInt16.self
    )
    nameBytes.withUnsafeBytes {
        raw.advanced(by: nameOffset).copyMemory(
            from: $0.baseAddress!,
            byteCount: nameBytes.count
        )
    }
    try operation(raw.assumingMemoryBound(to: dirent.self))
}

@Test
func surveyorPrunesInjectedMountBoundariesAndKeepsTheBoundarySnapshot() async throws {
    let fixture = try SurveyorFixture()
    defer { fixture.remove() }
    let boundaryURL = fixture.rootURL.appending(path: "mounted")
    try fixture.write(
        Data("must-not-be-read".utf8),
        to: boundaryURL.appending(path: "nested/file.txt")
    )
    try fixture.write(
        Data("visible".utf8),
        to: fixture.rootURL.appending(path: "visible.txt")
    )
    let request = ScanRequest(
        rootURL: fixture.rootURL,
        maximumWorkers: 2,
        testHooks: SurveyorTestHooks(
            isMountBoundary: { $0.standardizedFileURL == boundaryURL.standardizedFileURL }
        )
    )

    let snapshots = try await collectSnapshots(Surveyor().scan(request))
    let byPath = Dictionary(
        uniqueKeysWithValues: snapshots.map { ($0.relativePath, $0) }
    )

    #expect(byPath["mounted"]?.kind == .directory)
    #expect(byPath["mounted"]?.issue == .mountBoundary)
    #expect(byPath["visible.txt"]?.kind == .regularFile)
    #expect(!byPath.keys.contains("mounted/nested"))
    #expect(!byPath.keys.contains("mounted/nested/file.txt"))
    #expect(snapshots.map(\.progress.errorCount).max() == 0)
}

@Test
func surveyorEmitsPartialErrorsWithoutErasingValidResults() async throws {
    let fixture = try SurveyorFixture()
    defer { fixture.remove() }
    let blockedURL = fixture.rootURL.appending(path: "blocked")
    try fixture.write(
        Data("hidden".utf8),
        to: blockedURL.appending(path: "nested.txt")
    )
    try fixture.write(
        Data("visible".utf8),
        to: fixture.rootURL.appending(path: "visible.txt")
    )
    let request = ScanRequest(
        rootURL: fixture.rootURL,
        maximumWorkers: 2,
        testHooks: SurveyorTestHooks(
            issueBeforeDirectoryRead: { url in
                url.standardizedFileURL == blockedURL.standardizedFileURL
                    ? .permissionDenied
                    : nil
            }
        )
    )

    let snapshots = try await collectSnapshots(Surveyor().scan(request))
    let byPath = Dictionary(
        uniqueKeysWithValues: snapshots.map { ($0.relativePath, $0) }
    )

    #expect(byPath["blocked"]?.kind == .inaccessible)
    #expect(byPath["blocked"]?.issue == .permissionDenied)
    #expect(byPath["blocked"]?.logicalBytes == nil)
    #expect(byPath["blocked"]?.allocatedBytes == nil)
    #expect(byPath["visible.txt"]?.kind == .regularFile)
    #expect(!byPath.keys.contains("blocked/nested.txt"))
    #expect(snapshots.last?.progress.errorCount == 1)
}

@Test
func surveyorDoesNotTreatDirectoryReadFailureAsEndOfDirectory() async throws {
    let fixture = try SurveyorFixture()
    defer { fixture.remove() }
    try fixture.write(
        Data("visible".utf8),
        to: fixture.rootURL.appending(path: "visible.txt")
    )
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

    await #expect(throws: SurveyorError.directoryReadFailed) {
        _ = try await collectSnapshots(Surveyor().scan(request))
    }
}

@Test
func surveyorTreatsDirectoryReplacementAsAPartialError() async throws {
    let fixture = try SurveyorFixture()
    defer { fixture.remove() }
    let replacedURL = fixture.rootURL.appending(path: "replaced")
    try fixture.write(
        Data("nested".utf8),
        to: replacedURL.appending(path: "nested.txt")
    )
    try fixture.write(
        Data("visible".utf8),
        to: fixture.rootURL.appending(path: "visible.txt")
    )
    let replacement = DirectoryReplacementHook(targetURL: replacedURL)
    let request = ScanRequest(
        rootURL: fixture.rootURL,
        maximumWorkers: 1,
        testHooks: SurveyorTestHooks(
            beforeDirectoryRead: { url in
                if url.standardizedFileURL == replacedURL.standardizedFileURL {
                    replacement.replaceOnce()
                }
            }
        )
    )

    let snapshots = try await collectSnapshots(Surveyor().scan(request))
    let byPath = Dictionary(
        uniqueKeysWithValues: snapshots.map { ($0.relativePath, $0) }
    )

    #expect(byPath["replaced"]?.kind == .inaccessible)
    #expect(byPath["replaced"]?.issue == .metadataUnavailable)
    #expect(byPath["visible.txt"]?.kind == .regularFile)
    #expect(!byPath.keys.contains("replaced/nested.txt"))
}

@Test
func surveyorNeverExceedsTheConfiguredWorkerCount() async throws {
    let fixture = try SurveyorFixture()
    defer { fixture.remove() }
    for index in 0..<48 {
        try fixture.write(
            Data(repeating: UInt8(index % 255), count: 128),
            to: fixture.rootURL.appending(path: "fanout/\(index)/file.bin")
        )
    }
    let tracker = WorkerTracker()
    let request = ScanRequest(
        rootURL: fixture.rootURL,
        maximumWorkers: 3,
        testHooks: SurveyorTestHooks(
            workerDidStart: { tracker.started() },
            workerDidFinish: { tracker.finished() },
            beforeDirectoryRead: { _ in usleep(10_000) }
        )
    )

    _ = try await collectSnapshots(Surveyor().scan(request))

    #expect(tracker.maximumActive <= 3)
    #expect(tracker.maximumActive >= 1)
    #expect(tracker.active == 0)
}

@Test
func surveyorBoundsTheSharedDirectoryQueueWithoutDroppingWork() async throws {
    let fixture = try SurveyorFixture()
    defer { fixture.remove() }
    for index in 0..<96 {
        try fixture.write(
            Data(repeating: 0x44, count: 32),
            to: fixture.rootURL.appending(path: "fanout/\(index)/nested/file.bin")
        )
    }
    let tracker = QueueTracker()
    let request = ScanRequest(
        rootURL: fixture.rootURL,
        maximumWorkers: 2,
        maximumPendingDirectories: 4,
        testHooks: SurveyorTestHooks(
            queueDepthDidChange: { tracker.record($0) }
        )
    )

    let snapshots = try await collectSnapshots(Surveyor().scan(request))

    #expect(tracker.maximumDepth <= 4)
    #expect(
        snapshots.filter { $0.kind == .regularFile }.count == 96
    )
}

@Test
func surveyorBackpressuresWithoutDroppingWhenTheStreamBufferIsFull() async throws {
    let fixture = try SurveyorFixture()
    defer { fixture.remove() }
    for index in 0..<32 {
        try fixture.write(
            Data([UInt8(index)]),
            to: fixture.rootURL.appending(path: "files/\(index).bin")
        )
    }
    let completion = ScanCompletionTracker()
    let stream = Surveyor().scan(
        ScanRequest(
            rootURL: fixture.rootURL,
            maximumWorkers: 2,
            streamBufferCapacity: 1,
            onCompletion: { completion.complete() }
        )
    )
    try await Task.sleep(for: .milliseconds(50))

    #expect(!completion.isComplete)
    let snapshots = try await collectSnapshots(stream)

    #expect(snapshots.count == 34)
    #expect(Set(snapshots.map(\.relativePath)).count == 34)
    try await completion.wait(timeout: .seconds(10))
}

@Test
func surveyorAbandonedBackpressuredStreamStopsWorkers() async throws {
    let fixture = try SurveyorFixture()
    defer { fixture.remove() }
    for index in 0..<64 {
        try fixture.write(
            Data([UInt8(index)]),
            to: fixture.rootURL.appending(path: "files/\(index).bin")
        )
    }
    let completion = ScanCompletionTracker()
    let workers = WorkerTracker()
    var stream: SurveyorObservationStream? = Surveyor().scan(
        ScanRequest(
            rootURL: fixture.rootURL,
            maximumWorkers: 2,
            streamBufferCapacity: 1,
            onCompletion: { completion.complete() },
            testHooks: SurveyorTestHooks(
                workerDidStart: { workers.started() },
                workerDidFinish: { workers.finished() }
            )
        )
    )
    try await Task.sleep(for: .milliseconds(50))

    #expect(!completion.isComplete)
    stream = nil
    try await completion.wait(timeout: .seconds(1))

    #expect(stream == nil)
    #expect(workers.active == 0)
}

@Test
func surveyorCancellationStopsSyntheticTraversalWithinOneSecond() async throws {
    let fixture = try SurveyorFixture()
    defer { fixture.remove() }
    for index in 0..<160 {
        try fixture.write(
            Data(repeating: 0x43, count: 64),
            to: fixture.rootURL.appending(path: "deep/\(index)/a/b/c/file.bin")
        )
    }
    let tracker = WorkerTracker()
    let stream = Surveyor().scan(
        ScanRequest(
            rootURL: fixture.rootURL,
            maximumWorkers: 4,
            testHooks: SurveyorTestHooks(
                workerDidStart: { tracker.started() },
                workerDidFinish: { tracker.finished() },
                beforeDirectoryRead: { _ in usleep(5_000) }
            )
        )
    )
    let clock = ContinuousClock()
    let task = Task {
        do {
            for try await _ in stream {}
            return Task.isCancelled
        } catch {
            return error is CancellationError
                || error as? SurveyorError == .cancelled
        }
    }
    try await Task.sleep(for: .milliseconds(40))
    let cancellationStart = clock.now

    task.cancel()
    let reportedCancellation = await task.value
    while tracker.active > 0,
          cancellationStart.duration(to: clock.now) < .seconds(1)
    {
        try await Task.sleep(for: .milliseconds(10))
    }

    #expect(reportedCancellation)
    #expect(cancellationStart.duration(to: clock.now) < .seconds(1))
    #expect(tracker.active == 0)
}

@Test
func surveyorRejectsInvalidRequestsBeforeTraversal() async throws {
    let fixture = try SurveyorFixture()
    defer { fixture.remove() }
    let fileURL = fixture.rootURL.appending(path: "file.txt")
    try fixture.write(Data("file".utf8), to: fileURL)

    await #expect(throws: SurveyorError.invalidWorkerCount) {
        _ = try await collectSnapshots(
            Surveyor().scan(
                ScanRequest(rootURL: fixture.rootURL, maximumWorkers: 0)
            )
        )
    }
    await #expect(throws: SurveyorError.invalidRoot) {
        _ = try await collectSnapshots(
            Surveyor().scan(
                ScanRequest(rootURL: fileURL, maximumWorkers: 1)
            )
        )
    }
    await #expect(throws: SurveyorError.invalidQueueCapacity) {
        _ = try await collectSnapshots(
            Surveyor().scan(
                ScanRequest(
                    rootURL: fixture.rootURL,
                    maximumWorkers: 1,
                    maximumPendingDirectories: 0
                )
            )
        )
    }
    await #expect(throws: SurveyorError.invalidQueueCapacity) {
        _ = try await collectSnapshots(
            Surveyor().scan(
                ScanRequest(
                    rootURL: fixture.rootURL,
                    maximumPendingDirectories:
                        ScanRequest.maximumPendingDirectoriesLimit + 1
                )
            )
        )
    }
    await #expect(throws: SurveyorError.invalidStreamBufferCapacity) {
        _ = try await collectSnapshots(
            Surveyor().scan(
                ScanRequest(
                    rootURL: fixture.rootURL,
                    maximumWorkers: 1,
                    streamBufferCapacity: 0
                )
            )
        )
    }
    await #expect(throws: SurveyorError.invalidStreamBufferCapacity) {
        _ = try await collectSnapshots(
            Surveyor().scan(
                ScanRequest(
                    rootURL: fixture.rootURL,
                    streamBufferCapacity:
                        ScanRequest.maximumStreamBufferCapacity + 1
                )
            )
        )
    }
    await #expect(throws: SurveyorError.invalidRoot) {
        _ = try await collectSnapshots(
            Surveyor().scan(
                ScanRequest(
                    rootURL: fixture.rootURL,
                    maximumWorkers: 1,
                    testHooks: SurveyorTestHooks(
                        issueBeforeDirectoryRead: { _ in .permissionDenied }
                    )
                )
            )
        )
    }
    await #expect(throws: SurveyorError.invalidRoot) {
        _ = try await collectSnapshots(
            Surveyor().scan(
                ScanRequest(
                    rootURL: URL(string: "../relative")!,
                    maximumWorkers: 1
                )
            )
        )
    }
}

@Test
func surveyorPreservesSignedDeviceBitPatternsFromDarwinMetadata() {
    let metadata = FileMetadata(testingDevice: -1)

    #expect(metadata.device == UInt64.max)
}

@Test
func surveyorCountsHardLinkedFileBytesOnlyOnceInProgress() async throws {
    let fixture = try SurveyorFixture()
    defer { fixture.remove() }
    let originalURL = fixture.rootURL.appending(path: "original.bin")
    let linkedURL = fixture.rootURL.appending(path: "linked.bin")
    try fixture.write(Data(repeating: 0x45, count: 8_192), to: originalURL)
    try FileManager.default.linkItem(at: originalURL, to: linkedURL)

    let snapshots = try await collectSnapshots(
        Surveyor().scan(
            ScanRequest(rootURL: fixture.rootURL, maximumWorkers: 2)
        )
    )
    let finalProgress = try #require(
        snapshots.max {
            $0.progress.completedEntries < $1.progress.completedEntries
        }?.progress
    )
    let original = try #require(
        snapshots.first { $0.relativePath == "original.bin" }
    )

    #expect(finalProgress.regularFileCount == 2)
    #expect(finalProgress.logicalFileBytes == original.logicalBytes)
    #expect(finalProgress.allocatedFileBytes == original.allocatedBytes)
}

@Test
func surveyorFixtureScriptRefusesUnsafeTargetsAndCleansOnlyMarkedFixtures() throws {
    let repositoryRoot = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let scriptURL = repositoryRoot
        .appending(path: "Tests/Fixtures/Surveyor/generate-fixture.sh")
    let parentURL = FileManager.default.temporaryDirectory
        .appending(path: "stornaut-surveyor-script-\(UUID().uuidString)")
    let fixtureURL = parentURL.appending(path: "fixture")
    let nonfixtureURL = parentURL.appending(path: "nonfixture")
    try FileManager.default.createDirectory(
        at: nonfixtureURL,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: parentURL) }

    #expect(
        try runFixtureScript(scriptURL, arguments: ["generate", "/"]) != 0
    )
    #expect(
        try runFixtureScript(
            scriptURL,
            arguments: [
                "generate",
                FileManager.default.homeDirectoryForCurrentUser.path,
            ]
        ) != 0
    )
    #expect(
        try runFixtureScript(
            scriptURL,
            arguments: ["generate", repositoryRoot.path]
        ) != 0
    )
    #expect(
        try runFixtureScript(
            scriptURL,
            arguments: ["clean", nonfixtureURL.path]
        ) != 0
    )

    #expect(
        try runFixtureScript(
            scriptURL,
            arguments: ["generate", fixtureURL.path]
        ) == 0
    )
    #expect(
        FileManager.default.fileExists(
            atPath: fixtureURL
                .appending(path: ".stornaut-surveyor-fixture-v1").path
        )
    )
    #expect(
        try runFixtureScript(
            scriptURL,
            arguments: ["clean", fixtureURL.path]
        ) == 0
    )
    #expect(!FileManager.default.fileExists(atPath: fixtureURL.path))
}

private func collectSnapshots(
    _ stream: SurveyorObservationStream
) async throws -> [SurveyorObservation] {
    var snapshots: [SurveyorObservation] = []
    for try await observation in stream {
        snapshots.append(observation)
    }
    return snapshots
}

private struct SurveyorFixture {
    let parentURL: URL
    let rootURL: URL

    init() throws {
        parentURL = FileManager.default.temporaryDirectory
            .appending(path: "stornaut-surveyor-\(UUID().uuidString)")
        rootURL = parentURL.appending(path: "root")
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
    }

    func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url)
    }

    func createSparseFile(at url: URL, logicalBytes: Int64) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let descriptor = open(url.path, O_CREAT | O_RDWR | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else {
            throw CocoaError(.fileWriteUnknown)
        }
        defer { close(descriptor) }
        guard ftruncate(descriptor, logicalBytes) == 0 else {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: parentURL)
    }
}

private final class WorkerTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var storedActive = 0
    private var storedMaximumActive = 0

    var active: Int {
        lock.withLock { storedActive }
    }

    var maximumActive: Int {
        lock.withLock { storedMaximumActive }
    }

    func started() {
        lock.withLock {
            storedActive += 1
            storedMaximumActive = max(storedMaximumActive, storedActive)
        }
    }

    func finished() {
        lock.withLock {
            storedActive -= 1
        }
    }
}

private final class QueueTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var storedMaximumDepth = 0

    var maximumDepth: Int {
        lock.withLock { storedMaximumDepth }
    }

    func record(_ depth: Int) {
        lock.withLock {
            storedMaximumDepth = max(storedMaximumDepth, depth)
        }
    }
}

private final class DirectoryReplacementHook: @unchecked Sendable {
    private let lock = NSLock()
    private let targetURL: URL
    private var didReplace = false

    init(targetURL: URL) {
        self.targetURL = targetURL
    }

    func replaceOnce() {
        lock.withLock {
            guard !didReplace else {
                return
            }
            didReplace = true
            try? FileManager.default.removeItem(at: targetURL)
            try? FileManager.default.createDirectory(
                at: targetURL,
                withIntermediateDirectories: true
            )
        }
    }
}

private final class ScanCompletionTracker: @unchecked Sendable {
    private let condition = NSCondition()
    private var completed = false

    var isComplete: Bool {
        condition.withLock { completed }
    }

    func complete() {
        condition.withLock {
            completed = true
            condition.broadcast()
        }
    }

    func wait(timeout: Duration) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if condition.withLock({ completed }) {
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw SurveyorTestError.completionTimedOut
    }
}

private func runFixtureScript(
    _ scriptURL: URL,
    arguments: [String]
) throws -> Int32 {
    let process = Process()
    process.executableURL = scriptURL
    process.arguments = arguments
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    return process.terminationStatus
}

private enum SurveyorTestError: Error {
    case completionTimedOut
}
