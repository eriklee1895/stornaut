import Darwin
import Foundation
import Synchronization

public final class SurveyorObservationStream:
    AsyncSequence,
    @unchecked Sendable
{
    public typealias Element = SurveyorObservation

    public final class AsyncIterator: AsyncIteratorProtocol {
        private let stream: SurveyorObservationStream

        fileprivate init(stream: SurveyorObservationStream) {
            self.stream = stream
        }

        deinit {
            stream.channel.cancelConsumption()
        }

        public func next() async throws -> SurveyorObservation? {
            try await stream.channel.next()
        }
    }

    fileprivate let channel: SurveyorObservationChannel

    fileprivate init(channel: SurveyorObservationChannel) {
        self.channel = channel
    }

    deinit {
        channel.cancelConsumption()
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(stream: self)
    }
}

public struct Surveyor: Sendable {
    public init() {}

    public func scan(
        _ request: ScanRequest
    ) -> SurveyorObservationStream {
        let state = SurveyState(request: request)
        let capacity = request.streamBufferCapacity > 0
            && request.streamBufferCapacity
                <= ScanRequest.maximumStreamBufferCapacity
            ? request.streamBufferCapacity
            : 1
        let channel = SurveyorObservationChannel(
            capacity: capacity,
            onCancel: state.cancel,
            isProducerCancelled: { state.isCancelled }
        )
        Task.detached(priority: .utility) {
            defer { request.onCompletion() }
            do {
                try await runSurvey(
                    request,
                    state: state,
                    channel: channel
                )
                channel.finish()
            } catch {
                state.cancel()
                channel.finish(throwing: error)
            }
        }
        return SurveyorObservationStream(channel: channel)
    }
}

private func runSurvey(
    _ request: ScanRequest,
    state: SurveyState,
    channel: SurveyorObservationChannel
) async throws {
    let root = request.rootURL.standardizedFileURL
    guard root.isFileURL,
          root.path.hasPrefix("/"),
          let rootMetadata = metadata(at: root),
          rootMetadata.kind == .directory
    else {
        throw SurveyorError.invalidRoot
    }
    guard request.maximumWorkers > 0,
          request.maximumWorkers <= ScanRequest.maximumWorkersLimit
    else {
        throw SurveyorError.invalidWorkerCount
    }
    guard request.maximumPendingDirectories > 0,
          request.maximumPendingDirectories
            <= ScanRequest.maximumPendingDirectoriesLimit
    else {
        throw SurveyorError.invalidQueueCapacity
    }
    guard request.streamBufferCapacity > 0,
          request.streamBufferCapacity
            <= ScanRequest.maximumStreamBufferCapacity
    else {
        throw SurveyorError.invalidStreamBufferCapacity
    }
    let rootIsCaseSensitive = (
        try? root.resourceValues(
            forKeys: [.volumeSupportsCaseSensitiveNamesKey]
        ).volumeSupportsCaseSensitiveNames
    ) ?? true

    try emit(
        metadataSnapshot(
            request: request,
            url: root,
            relativePath: ".",
            metadata: rootMetadata,
            issue: nil,
            progress: state.record(rootMetadata.kind, metadata: rootMetadata, issue: nil)
        ),
        state: state,
        channel: channel
    )
    guard state.tryEnqueue(
        DirectoryJob(
            url: root,
            relativePath: ".",
            expectedDevice: rootMetadata.device,
            expectedInode: rootMetadata.inode,
            rootIsCaseSensitive: rootIsCaseSensitive
        )
    ) else {
        throw SurveyorError.internalInvariant
    }

    let workers = DispatchGroup()
    for _ in 0..<request.maximumWorkers {
        workers.enter()
        DispatchQueue.global(qos: .utility).async {
            defer { workers.leave() }
            do {
                request.testHooks.workerDidStart()
                defer { request.testHooks.workerDidFinish() }

                while let job = try state.dequeue() {
                    do {
                        var localStack = [job]
                        while let localJob = localStack.popLast() {
                            try Task.checkCancellation()
                            try state.checkCancellation()
                            try processDirectory(
                                localJob,
                                rootDevice: rootMetadata.device,
                                request: request,
                                state: state,
                                channel: channel,
                                scheduleDirectory: { child in
                                    if !state.tryEnqueue(child) {
                                        localStack.append(child)
                                    }
                                }
                            )
                        }
                        state.completeJob()
                    } catch {
                        state.completeJob()
                        throw error
                    }
                }
            } catch {
                state.recordFailure(error)
            }
        }
    }

    await withTaskCancellationHandler {
        await withCheckedContinuation { continuation in
            workers.notify(queue: .global(qos: .utility)) {
                continuation.resume()
            }
        }
    } onCancel: {
        state.cancel()
    }

    if let failure = state.failure {
        if failure as? SurveyorError == .cancelled {
            state.cancel()
            throw SurveyorError.cancelled
        }
        throw failure
    }
    if Task.isCancelled {
        state.cancel()
        throw SurveyorError.cancelled
    }
}

private func processDirectory(
    _ job: DirectoryJob,
    rootDevice: UInt64,
    request: ScanRequest,
    state: SurveyState,
    channel: SurveyorObservationChannel,
    scheduleDirectory: (DirectoryJob) -> Void
) throws {
    request.testHooks.beforeDirectoryRead(job.url)
    try state.checkCancellation()

    if let injectedIssue = request.testHooks.issueBeforeDirectoryRead(job.url) {
        if job.relativePath == "." {
            throw SurveyorError.invalidRoot
        }
        if job.relativePath != "." {
            try emit(
                observation(
                    request: request,
                    relativePath: job.relativePath,
                    kind: .inaccessible,
                    logicalBytes: nil,
                    allocatedBytes: nil,
                    observedAt: Date(),
                    issue: injectedIssue,
                    progress: state.record(
                        .inaccessible,
                        metadata: nil,
                        issue: injectedIssue
                    )
                ),
                state: state,
                channel: channel
            )
        }
        return
    }

    let descriptor = open(
        job.url.path,
        O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
    )
    guard descriptor >= 0 else {
        if job.relativePath == "." {
            throw SurveyorError.invalidRoot
        }
        if job.relativePath != "." {
            let issue: ScanIssue = errno == EACCES || errno == EPERM
                ? .permissionDenied
                : .directoryReadFailed
            try emit(
                observation(
                    request: request,
                    relativePath: job.relativePath,
                    kind: .inaccessible,
                    logicalBytes: nil,
                    allocatedBytes: nil,
                    observedAt: Date(),
                    issue: issue,
                    progress: state.record(
                        .inaccessible,
                        metadata: nil,
                        issue: issue
                    )
                ),
                state: state,
                channel: channel
            )
        }
        return
    }

    var directoryMetadata = stat()
    guard fstat(descriptor, &directoryMetadata) == 0,
          UInt64(bitPattern: Int64(directoryMetadata.st_dev))
              == job.expectedDevice,
          UInt64(directoryMetadata.st_ino) == job.expectedInode
    else {
        close(descriptor)
        if job.relativePath == "." {
            throw SurveyorError.rootIdentityChanged
        }
        try emitInaccessibleDirectory(
            job,
            issue: .metadataUnavailable,
            state: state,
            channel: channel
        )
        return
    }

    if job.relativePath != "." {
        let metadata = FileMetadata(directoryMetadata)
        try emit(
            metadataSnapshot(
                request: request,
                url: job.url,
                relativePath: job.relativePath,
                metadata: metadata,
                issue: nil,
                progress: state.record(
                    .directory,
                    metadata: metadata,
                    issue: nil
                )
            ),
            state: state,
            channel: channel
        )
    }

    guard let directory = fdopendir(descriptor) else {
        close(descriptor)
        throw SurveyorError.internalInvariant
    }
    defer { closedir(directory) }

    let directoryDescriptor = dirfd(directory)
    var directoryReadCount = 0
    while true {
        try state.checkCancellation()
        errno = 0
        let entry: UnsafeMutablePointer<dirent>?
        if let injectedError = request.testHooks.directoryReadError(
            job.url,
            directoryReadCount
        ) {
            errno = injectedError
            entry = nil
        } else {
            entry = readdir(directory)
        }
        guard let entry else {
            guard errno == 0 else {
                throw SurveyorError.directoryReadFailed
            }
            break
        }
        directoryReadCount += 1
        let name: String
        do {
            name = try decodeDirectoryEntryName(entry)
        } catch {
            throw SurveyorError.directoryReadFailed
        }
        if name == "." || name == ".." {
            continue
        }
        let relativePath = job.relativePath == "."
            ? name
            : "\(job.relativePath)/\(name)"
        let childURL = job.url.appending(path: name)
        var info = stat()
        let result = name.withCString {
            fstatat(
                directoryDescriptor,
                $0,
                &info,
                AT_SYMLINK_NOFOLLOW
            )
        }
        guard result == 0 else {
            let issue: ScanIssue = errno == EACCES || errno == EPERM
                ? .permissionDenied
                : .metadataUnavailable
            try emit(
                observation(
                    request: request,
                    relativePath: relativePath,
                    kind: .inaccessible,
                    logicalBytes: nil,
                    allocatedBytes: nil,
                    observedAt: Date(),
                    issue: issue,
                    progress: state.record(
                        .inaccessible,
                        metadata: nil,
                        issue: issue
                    )
                ),
                state: state,
                channel: channel
            )
            continue
        }

        let metadata = FileMetadata(info)
        let isExcluded = metadata.kind == .directory
            && request.exclusions.contains {
                $0.contains(
                    relativePath,
                    caseSensitive: job.rootIsCaseSensitive
                )
            }
        let isBoundary = metadata.kind == .directory
            && (
                request.testHooks.isMountBoundary(childURL)
                    || (
                        request.stayOnRootDevice
                            && metadata.device != rootDevice
                    )
            )
        let issue: ScanIssue? = isExcluded
            ? .userExcluded
            : isBoundary ? .mountBoundary : nil
        if metadata.kind == .directory, !isBoundary, !isExcluded {
            scheduleDirectory(
                DirectoryJob(
                    url: childURL,
                    relativePath: relativePath,
                    expectedDevice: metadata.device,
                    expectedInode: metadata.inode,
                    rootIsCaseSensitive: job.rootIsCaseSensitive
                )
            )
        } else {
            try emit(
                metadataSnapshot(
                    request: request,
                    url: childURL,
                    relativePath: relativePath,
                    metadata: metadata,
                    issue: issue,
                    progress: state.record(
                        metadata.kind,
                        metadata: metadata,
                        issue: issue
                    )
                ),
                state: state,
                channel: channel
            )
        }
    }
}

private func emitInaccessibleDirectory(
    _ job: DirectoryJob,
    issue: ScanIssue,
    state: SurveyState,
    channel: SurveyorObservationChannel
) throws {
    try emit(
        observation(
            request: state.request,
            relativePath: job.relativePath,
            kind: .inaccessible,
            logicalBytes: nil,
            allocatedBytes: nil,
            observedAt: Date(),
            issue: issue,
            progress: state.record(
                .inaccessible,
                metadata: nil,
                issue: issue
            )
        ),
        state: state,
        channel: channel
    )
}

private struct DirectoryJob: Sendable {
    let url: URL
    let relativePath: String
    let expectedDevice: UInt64
    let expectedInode: UInt64
    let rootIsCaseSensitive: Bool
}

struct FileMetadata {
    let kind: SnapshotKind
    let mode: UInt16
    let ownerUserID: UInt32
    let ownerGroupID: UInt32
    let logicalBytes: Int64
    let allocatedBytes: Int64
    let device: UInt64
    let inode: UInt64
    let linkCount: UInt64
    let modificationSeconds: Int64
    let modificationNanoseconds: Int64

    init(_ info: stat) {
        switch info.st_mode & S_IFMT {
        case S_IFREG:
            kind = .regularFile
        case S_IFDIR:
            kind = .directory
        case S_IFLNK:
            kind = .symbolicLink
        default:
            kind = .other
        }
        mode = UInt16(info.st_mode)
        ownerUserID = info.st_uid
        ownerGroupID = info.st_gid
        logicalBytes = max(0, Int64(info.st_size))
        let allocated = Int64(info.st_blocks).multipliedReportingOverflow(
            by: 512
        )
        allocatedBytes = allocated.overflow
            ? .max
            : max(0, allocated.partialValue)
        device = UInt64(bitPattern: Int64(info.st_dev))
        inode = UInt64(info.st_ino)
        linkCount = UInt64(info.st_nlink)
        modificationSeconds = Int64(info.st_mtimespec.tv_sec)
        modificationNanoseconds = Int64(info.st_mtimespec.tv_nsec)
    }

    init(testingDevice: Int32, inode: UInt64 = 1) {
        kind = .regularFile
        mode = UInt16(S_IFREG)
        ownerUserID = 0
        ownerGroupID = 0
        logicalBytes = 0
        allocatedBytes = 0
        device = UInt64(bitPattern: Int64(testingDevice))
        self.inode = inode
        linkCount = 1
        modificationSeconds = 0
        modificationNanoseconds = 0
    }
}

private func metadata(at url: URL) -> FileMetadata? {
    var info = stat()
    guard lstat(url.path, &info) == 0 else {
        return nil
    }
    return FileMetadata(info)
}

private func metadataSnapshot(
    request: ScanRequest,
    url: URL,
    relativePath: String,
    metadata: FileMetadata,
    issue: ScanIssue?,
    progress: ScanProgress
) throws -> SurveyorObservation {
    let identity = try FileIdentity(
        device: metadata.device,
        inode: metadata.inode,
        mode: metadata.mode,
        ownerUserID: metadata.ownerUserID,
        ownerGroupID: metadata.ownerGroupID,
        linkCount: metadata.linkCount,
        size: metadata.logicalBytes,
        allocatedBytes: metadata.allocatedBytes,
        modificationSeconds: metadata.modificationSeconds,
        modificationNanoseconds: metadata.modificationNanoseconds
    )
    return SurveyorObservation(
        snapshot: try PathSnapshot(
            id: SnapshotID(),
            sessionID: request.sessionID,
            scopeID: request.scopeID,
            relativePath: relativePath,
            kind: metadata.kind,
            logicalByteCount: ByteCount(exactly: metadata.logicalBytes),
            allocatedByteCount: ByteCount(exactly: metadata.allocatedBytes),
            modifiedAt: Date(
                timeIntervalSince1970: TimeInterval(
                    metadata.modificationSeconds
                ) + TimeInterval(metadata.modificationNanoseconds) / 1_000_000_000
            ),
            fileIdentity: identity,
            symlinkTarget: metadata.kind == .symbolicLink
                ? try? FileManager.default.destinationOfSymbolicLink(
                    atPath: url.path
                )
                : nil,
            measurementStatus: MeasurementStatus(issue: issue),
            observedAt: Date()
        ),
        progress: progress
    )
}

private func observation(
    request: ScanRequest,
    relativePath: String,
    kind: PathKind,
    logicalBytes: Int64?,
    allocatedBytes: Int64?,
    observedAt: Date,
    issue: ScanIssue?,
    progress: ScanProgress
) throws -> SurveyorObservation {
    SurveyorObservation(
        snapshot: try PathSnapshot(
            id: SnapshotID(),
            sessionID: request.sessionID,
            scopeID: request.scopeID,
            relativePath: relativePath,
            kind: kind,
            logicalByteCount: logicalBytes.flatMap(ByteCount.init(exactly:)),
            allocatedByteCount: allocatedBytes.flatMap(ByteCount.init(exactly:)),
            modifiedAt: nil,
            fileIdentity: nil,
            symlinkTarget: nil,
            measurementStatus: MeasurementStatus(issue: issue),
            observedAt: observedAt
        ),
        progress: progress
    )
}

private func emit(
    _ snapshot: SurveyorObservation,
    state: SurveyState,
    channel: SurveyorObservationChannel
) throws {
    try state.checkCancellation()
    try channel.send(snapshot)
}

private final class SurveyorObservationChannel: @unchecked Sendable {
    private enum State {
        case open
        case finished
        case failed(Error)
    }

    private let condition = NSCondition()
    private let capacity: Int
    private let onCancel: @Sendable () -> Void
    private let isProducerCancelled: @Sendable () -> Bool
    private var state: State = .open
    private var queuedObservations: [SurveyorObservation] = []
    private var queueOffset = 0
    private var waitingConsumer:
        CheckedContinuation<SurveyorObservation?, Error>?
    private var consumerCancelled = false

    init(
        capacity: Int,
        onCancel: @escaping @Sendable () -> Void,
        isProducerCancelled: @escaping @Sendable () -> Bool = { false }
    ) {
        self.capacity = max(1, capacity)
        self.onCancel = onCancel
        self.isProducerCancelled = isProducerCancelled
    }

    func send(_ observation: SurveyorObservation) throws {
        condition.lock()
        while true {
            if consumerCancelled || isProducerCancelled() {
                condition.unlock()
                throw SurveyorError.cancelled
            }
            guard case .open = state else {
                condition.unlock()
                throw SurveyorError.cancelled
            }
            if let consumer = waitingConsumer {
                waitingConsumer = nil
                condition.unlock()
                consumer.resume(returning: observation)
                return
            }
            if queuedCount < capacity {
                queuedObservations.append(observation)
                condition.unlock()
                return
            }
            condition.wait(until: Date(timeIntervalSinceNow: 0.01))
        }
    }

    func finish(throwing error: Error? = nil) {
        condition.lock()
        guard case .open = state else {
            condition.unlock()
            return
        }
        state = error.map(State.failed) ?? .finished
        let consumer = waitingConsumer
        waitingConsumer = nil
        condition.broadcast()
        condition.unlock()
        if let error {
            consumer?.resume(throwing: error)
        } else {
            consumer?.resume(returning: nil)
        }
    }

    func next() async throws -> SurveyorObservation? {
        try await withTaskCancellationHandler {
            if Task.isCancelled {
                cancelConsumption()
            }
            return try await withCheckedThrowingContinuation {
                continuation in
                let immediate: (
                    observation: SurveyorObservation?,
                    error: Error?,
                    shouldResume: Bool
                )
                condition.lock()
                if consumerCancelled {
                    immediate = (nil, SurveyorError.cancelled, true)
                } else if queuedCount > 0 {
                    let observation = queuedObservations[queueOffset]
                    queueOffset += 1
                    compactQueueIfNeeded()
                    condition.broadcast()
                    immediate = (observation, nil, true)
                } else {
                    switch state {
                    case .open where waitingConsumer == nil:
                        waitingConsumer = continuation
                        immediate = (nil, nil, false)
                    case .open:
                        immediate = (
                            nil,
                            SurveyorError.internalInvariant,
                            true
                        )
                    case .finished:
                        immediate = (nil, nil, true)
                    case let .failed(error):
                        immediate = (nil, error, true)
                    }
                }
                condition.unlock()
                guard immediate.shouldResume else {
                    return
                }
                if let error = immediate.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(
                        returning: immediate.observation
                    )
                }
            }
        } onCancel: {
            cancelConsumption()
        }
    }

    func cancelConsumption() {
        condition.lock()
        guard case .open = state, !consumerCancelled else {
            condition.unlock()
            return
        }
        consumerCancelled = true
        state = .failed(SurveyorError.cancelled)
        queuedObservations.removeAll()
        queueOffset = 0
        let consumer = waitingConsumer
        waitingConsumer = nil
        condition.broadcast()
        condition.unlock()
        onCancel()
        consumer?.resume(throwing: SurveyorError.cancelled)
    }

    private var queuedCount: Int {
        queuedObservations.count - queueOffset
    }

    private func compactQueueIfNeeded() {
        if queueOffset >= 1_024,
           queueOffset * 2 >= queuedObservations.count
        {
            queuedObservations.removeFirst(queueOffset)
            queueOffset = 0
        }
    }
}

private final class SurveyState: @unchecked Sendable {
    private struct State {
        var queue: [DirectoryJob] = []
        var queueOffset = 0
        var pendingJobs = 0
        var cancelled = false
        var progress = ScanProgress(
            completedEntries: 0,
            regularFileCount: 0,
            directoryCount: 0,
            symlinkCount: 0,
            errorCount: 0,
            logicalFileBytes: 0,
            allocatedFileBytes: 0
        )
        var countedHardLinks = Set<HardLinkIdentity>()
    }

    private let condition = NSCondition()
    private var state = State()
    private var recordedFailure: Error?
    private let maximumPendingDirectories: Int
    private let queueDepthDidChange: @Sendable (Int) -> Void
    let request: ScanRequest

    init(request: ScanRequest) {
        self.request = request
        maximumPendingDirectories = request.maximumPendingDirectories
        queueDepthDidChange = request.testHooks.queueDepthDidChange
    }

    func tryEnqueue(_ job: DirectoryJob) -> Bool {
        let depth: Int? = condition.withLock {
            guard !state.cancelled else {
                return nil
            }
            let queuedCount = state.queue.count - state.queueOffset
            guard queuedCount < maximumPendingDirectories else {
                return nil
            }
            state.queue.append(job)
            state.pendingJobs += 1
            condition.signal()
            return queuedCount + 1
        }
        if let depth {
            queueDepthDidChange(depth)
            return true
        }
        return false
    }

    func dequeue() throws -> DirectoryJob? {
        condition.lock()
        defer { condition.unlock() }
        while true {
            if state.cancelled {
                throw SurveyorError.cancelled
            }
            if state.queueOffset < state.queue.count {
                let job = state.queue[state.queueOffset]
                state.queueOffset += 1
                let depth = state.queue.count - state.queueOffset
                compactQueueIfNeeded()
                condition.unlock()
                queueDepthDidChange(depth)
                condition.lock()
                return job
            }
            if state.pendingJobs == 0 {
                return nil
            }
            condition.wait()
        }
    }

    func completeJob() {
        condition.withLock {
            state.pendingJobs -= 1
            precondition(state.pendingJobs >= 0)
            condition.broadcast()
        }
    }

    func record(
        _ kind: SnapshotKind,
        metadata: FileMetadata?,
        issue: ScanIssue?
    ) -> ScanProgress {
        condition.withLock {
            let current = state.progress
            var regularFiles = current.regularFileCount
            var directories = current.directoryCount
            var symlinks = current.symlinkCount
            var errors = current.errorCount
            var logicalBytes = current.logicalFileBytes
            var allocatedBytes = current.allocatedFileBytes
            switch kind {
            case .regularFile:
                regularFiles += 1
                if let metadata {
                    let shouldCount: Bool
                    if metadata.linkCount > 1 {
                        shouldCount = state.countedHardLinks.insert(
                            HardLinkIdentity(
                                device: metadata.device,
                                inode: metadata.inode
                            )
                        ).inserted
                    } else {
                        shouldCount = true
                    }
                    if shouldCount {
                        logicalBytes = saturatingAdd(
                            logicalBytes,
                            metadata.logicalBytes
                        )
                        allocatedBytes = saturatingAdd(
                            allocatedBytes,
                            metadata.allocatedBytes
                        )
                    }
                }
            case .directory:
                directories += 1
            case .symbolicLink:
                symlinks += 1
            case .inaccessible:
                errors += 1
            case .other:
                break
            }
            if issue != nil,
               issue != .mountBoundary,
               kind != .inaccessible
            {
                errors += 1
            }
            state.progress = ScanProgress(
                completedEntries: current.completedEntries + 1,
                regularFileCount: regularFiles,
                directoryCount: directories,
                symlinkCount: symlinks,
                errorCount: errors,
                logicalFileBytes: logicalBytes,
                allocatedFileBytes: allocatedBytes
            )
            return state.progress
        }
    }

    func checkCancellation() throws {
        if Task.isCancelled {
            cancel()
            throw SurveyorError.cancelled
        }
        condition.lock()
        let isCancelled = state.cancelled
        condition.unlock()
        if isCancelled {
            throw SurveyorError.cancelled
        }
    }

    var isCancelled: Bool {
        condition.withLock { state.cancelled }
    }

    func cancel() {
        condition.withLock {
            state.cancelled = true
            condition.broadcast()
        }
    }

    var failure: Error? {
        condition.withLock { recordedFailure }
    }

    func recordFailure(_ error: Error) {
        condition.withLock {
            if recordedFailure == nil {
                recordedFailure = error
            }
            state.cancelled = true
            condition.broadcast()
        }
    }

    private func compactQueueIfNeeded() {
        if state.queueOffset >= 1_024,
           state.queueOffset * 2 >= state.queue.count
        {
            state.queue.removeFirst(state.queueOffset)
            state.queueOffset = 0
        }
    }
}

private struct HardLinkIdentity: Hashable {
    let device: UInt64
    let inode: UInt64
}

private func saturatingAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
    let result = lhs.addingReportingOverflow(rhs)
    return result.overflow ? .max : result.partialValue
}
