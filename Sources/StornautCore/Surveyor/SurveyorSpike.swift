import Darwin
import Foundation
import Synchronization

public struct SurveyorSpike: Sendable {
    public init() {}

    public func scan(
        _ request: ScanRequest
    ) -> AsyncThrowingStream<SurveyorObservation, Error> {
        let state = SurveyState(request: request)
        let stream = AsyncThrowingStream<SurveyorObservation, Error>(
            bufferingPolicy: .bufferingOldest(
                max(1, request.streamBufferCapacity)
            )
        ) { continuation in
            continuation.onTermination = { @Sendable termination in
                if case .cancelled = termination {
                    state.cancel()
                }
            }
            Task.detached(priority: .utility) {
                defer { request.onCompletion() }
                do {
                    try await runSurvey(request, state: state, continuation: continuation)
                    continuation.finish()
                } catch {
                    state.cancel()
                    continuation.finish(throwing: error)
                }
            }
        }
        return stream
    }
}

private func runSurvey(
    _ request: ScanRequest,
    state: SurveyState,
    continuation: AsyncThrowingStream<SurveyorObservation, Error>.Continuation
) async throws {
    let root = request.rootURL.standardizedFileURL
    guard root.isFileURL,
          root.path.hasPrefix("/"),
          let rootMetadata = metadata(at: root),
          rootMetadata.kind == .directory
    else {
        throw SurveyorError.invalidRoot
    }
    guard request.maximumWorkers > 0, request.maximumWorkers <= 64 else {
        throw SurveyorError.invalidWorkerCount
    }
    guard request.maximumPendingDirectories > 0 else {
        throw SurveyorError.invalidQueueCapacity
    }
    guard request.streamBufferCapacity > 0 else {
        throw SurveyorError.invalidStreamBufferCapacity
    }

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
        continuation: continuation
    )
    guard state.tryEnqueue(
        DirectoryJob(
            url: root,
            relativePath: ".",
            expectedDevice: rootMetadata.device,
            expectedInode: rootMetadata.inode
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
                                continuation: continuation,
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
    continuation: AsyncThrowingStream<SurveyorObservation, Error>.Continuation,
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
                continuation: continuation
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
                continuation: continuation
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
            throw SurveyorError.invalidRoot
        }
        try emitInaccessibleDirectory(
            job,
            issue: .metadataUnavailable,
            state: state,
            continuation: continuation
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
            continuation: continuation
        )
    }

    guard let directory = fdopendir(descriptor) else {
        close(descriptor)
        throw SurveyorError.internalInvariant
    }
    defer { closedir(directory) }

    let directoryDescriptor = dirfd(directory)
    while let entry = readdir(directory) {
        try state.checkCancellation()
        let name = directoryEntryName(entry)
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
                continuation: continuation
            )
            continue
        }

        let metadata = FileMetadata(info)
        let isBoundary = metadata.kind == .directory
            && (
                request.testHooks.isMountBoundary(childURL)
                    || (
                        request.stayOnRootDevice
                            && metadata.device != rootDevice
                    )
            )
        let issue: ScanIssue? = isBoundary ? .mountBoundary : nil
        if metadata.kind == .directory, !isBoundary {
            scheduleDirectory(
                DirectoryJob(
                    url: childURL,
                    relativePath: relativePath,
                    expectedDevice: metadata.device,
                    expectedInode: metadata.inode
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
                continuation: continuation
            )
        }
    }
}

private func emitInaccessibleDirectory(
    _ job: DirectoryJob,
    issue: ScanIssue,
    state: SurveyState,
    continuation: AsyncThrowingStream<SurveyorObservation, Error>.Continuation
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
        continuation: continuation
    )
}

private struct DirectoryJob: Sendable {
    let url: URL
    let relativePath: String
    let expectedDevice: UInt64
    let expectedInode: UInt64
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

private func directoryEntryName(_ entry: UnsafeMutablePointer<dirent>) -> String {
    withUnsafePointer(to: entry.pointee.d_name) {
        $0.withMemoryRebound(
            to: CChar.self,
            capacity: Int(MAXNAMLEN) + 1
        ) {
            String(cString: $0)
        }
    }
}

private func emit(
    _ snapshot: SurveyorObservation,
    state: SurveyState,
    continuation: AsyncThrowingStream<SurveyorObservation, Error>.Continuation
) throws {
    try state.checkCancellation()
    switch continuation.yield(snapshot) {
    case .enqueued:
        break
    case .dropped:
        throw SurveyorError.streamBufferExceeded
    case .terminated:
        state.cancel()
        throw SurveyorError.cancelled
    @unknown default:
        throw SurveyorError.internalInvariant
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
                        logicalBytes += metadata.logicalBytes
                        allocatedBytes += metadata.allocatedBytes
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
