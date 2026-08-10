import Foundation

public protocol ScanSessionPersisting: Sendable {
    func beginScanSession(_ session: ScanSession) async throws
    func saveScanSession(_ session: ScanSession) async throws
    func savePathSnapshots(_ snapshots: [PathSnapshot]) async throws
    func saveVolumeBaseline(_ baseline: VolumeBaseline) async throws
}

extension EvidenceStore: ScanSessionPersisting {}

public actor ScanSessionWriter {
    private let store: any ScanSessionPersisting
    private let volumeSampler: any VolumeBaselineSampling
    private let now: @Sendable () -> Date
    private let snapshotID: @Sendable (String) -> SnapshotID
    private let snapshotObservedAt: (@Sendable (String) -> Date)?
    private let defersProductFinalization: Bool
    private var scanIsActive = false
    private var activeControl: QuickScanRunControl?

    public init(
        store: any ScanSessionPersisting,
        volumeSampler: any VolumeBaselineSampling =
            FoundationVolumeBaselineSampler(),
        now: @escaping @Sendable () -> Date = Date.init,
        snapshotID: @escaping @Sendable (String) -> SnapshotID = {
            _ in SnapshotID()
        },
        snapshotObservedAt: (@Sendable (String) -> Date)? = nil,
        defersProductFinalization: Bool = false
    ) {
        self.store = store
        self.volumeSampler = volumeSampler
        self.now = now
        self.snapshotID = snapshotID
        self.snapshotObservedAt = snapshotObservedAt
        self.defersProductFinalization = defersProductFinalization
    }

    public var hasActiveScan: Bool {
        scanIsActive
    }

    public func run(
        _ request: ScanRequest
    ) throws -> AsyncThrowingStream<QuickScanEvent, Error> {
        guard !scanIsActive else {
            throw QuickScanLifecycleError.scanAlreadyRunning
        }
        guard request.persistenceBatchSize > 0,
              request.persistenceBatchSize
                <= ScanRequest.maximumPersistenceBatchSize
        else {
            throw QuickScanLifecycleError.invalidPersistenceBatchSize
        }
        guard request.lifecycleEventBufferCapacity > 0,
              request.lifecycleEventBufferCapacity
                <= ScanRequest.maximumLifecycleEventBufferCapacity
        else {
            throw QuickScanLifecycleError.invalidEventBufferCapacity
        }
        scanIsActive = true

        let control = QuickScanRunControl()
        activeControl = control
        let stream = AsyncThrowingStream<QuickScanEvent, Error>(
            bufferingPolicy: .bufferingOldest(
                request.lifecycleEventBufferCapacity
            )
        ) { continuation in
            let task = Task {
                await self.execute(
                    request,
                    continuation: continuation
                )
            }
            control.install(task)
        }
        return stream
    }

    public func cancelActiveScan() {
        activeControl?.cancel()
    }

    private func execute(
        _ request: ScanRequest,
        continuation: AsyncThrowingStream<QuickScanEvent, Error>.Continuation
    ) async {
        defer {
            scanIsActive = false
            activeControl = nil
        }
        let startedAt = now()
        let rootPath: PersistedPath
        do {
            rootPath = try PersistedPath(
                validating: request.rootURL.standardizedFileURL.path
            )
        } catch {
            continuation.finish(throwing: SurveyorError.invalidRoot)
            return
        }

        do {
            try await store.beginScanSession(
                try makeTerminalSession(
                    request: request,
                    rootPath: rootPath,
                    startedAt: startedAt,
                    terminalState: .partial,
                    reason: .interrupted
                )
            )
        } catch {
            continuation.finish(
                throwing: QuickScanLifecycleError.terminalPersistenceFailed
            )
            return
        }

        do {
            try yield(
                .stageChanged(.indexVolumes),
                continuation: continuation,
                request: request
            )
            let baseline = try volumeSampler.sample(
                request: request,
                sampledAt: now()
            )
            guard baseline.sessionID == request.sessionID,
                  baseline.scopeID == request.scopeID,
                  baseline.rootPath == rootPath
            else {
                throw SurveyorError.rootIdentityChanged
            }
            do {
                try await store.saveVolumeBaseline(baseline)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw QuickScanPersistenceError.store
            }
            try yield(
                .factObserved(.volumeBaseline(baseline)),
                continuation: continuation,
                request: request
            )
            try Task.checkCancellation()

            try yield(
                .stageChanged(.mapProjects),
                continuation: continuation,
                request: request
            )
            let summary = try await consumeSurveyor(
                request,
                expectedRootIdentity: baseline.rootIdentity,
                continuation: continuation
            )
            try Task.checkCancellation()

            if !defersProductFinalization {
                for stage in [
                    QuickScanStage.classifyArtifacts,
                    .checkActivity,
                    .finalizeSnapshot,
                ] {
                    try yield(
                        .stageChanged(stage),
                        continuation: continuation,
                        request: request
                    )
                }
            }

            let finishedAt = now()
            let session: ScanSession
            let scopeResult: QuickScanScopeResult
            if defersProductFinalization {
                session = try ScanSession(
                    id: request.sessionID,
                    startedAt: startedAt,
                    finishedAt: finishedAt,
                    terminalState: .partial,
                    completedScopes: [],
                    unfinishedScopes: [
                        UnfinishedScanScope(
                            id: request.scopeID,
                            rootPath: rootPath,
                            reason: summary.partialReason ?? .interrupted
                        ),
                    ]
                )
                scopeResult = .unfinished(session.unfinishedScopes[0])
            } else if let reason = summary.partialReason {
                session = try ScanSession(
                    id: request.sessionID,
                    startedAt: startedAt,
                    finishedAt: finishedAt,
                    terminalState: .partial,
                    completedScopes: [],
                    unfinishedScopes: [
                        UnfinishedScanScope(
                            id: request.scopeID,
                            rootPath: rootPath,
                            reason: reason
                        ),
                    ]
                )
                scopeResult = .unfinished(session.unfinishedScopes[0])
            } else {
                let scope = ScanScope(
                    id: request.scopeID,
                    rootPath: rootPath,
                    completedAt: finishedAt
                )
                session = try ScanSession(
                    id: request.sessionID,
                    startedAt: startedAt,
                    finishedAt: finishedAt,
                    terminalState: .completed,
                    completedScopes: [scope],
                    unfinishedScopes: []
                )
                scopeResult = .completed(scope)
            }
            do {
                try await store.saveScanSession(session)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw QuickScanPersistenceError.store
            }
            try yield(
                .scopeFinished(scopeResult),
                continuation: continuation,
                request: request
            )
            try yield(
                .terminal(session),
                continuation: continuation,
                request: request
            )
            continuation.finish()
        } catch is CancellationError {
            await finishAbnormally(
                request: request,
                rootPath: rootPath,
                startedAt: startedAt,
                state: .cancelled,
                reason: .cancelled,
                streamError: nil,
                continuation: continuation
            )
        } catch SurveyorError.cancelled {
            await finishAbnormally(
                request: request,
                rootPath: rootPath,
                startedAt: startedAt,
                state: .cancelled,
                reason: .cancelled,
                streamError: nil,
                continuation: continuation
            )
        } catch let error as QuickScanLifecycleError {
            await finishAbnormally(
                request: request,
                rootPath: rootPath,
                startedAt: startedAt,
                state: .failed,
                reason: .scannerFailure,
                streamError: error,
                continuation: continuation
            )
        } catch is QuickScanPersistenceError {
            await finishAbnormally(
                request: request,
                rootPath: rootPath,
                startedAt: startedAt,
                state: .failed,
                reason: .storeFailure,
                streamError: nil,
                continuation: continuation
            )
        } catch {
            await finishAbnormally(
                request: request,
                rootPath: rootPath,
                startedAt: startedAt,
                state: .failed,
                reason: .scannerFailure,
                streamError: nil,
                continuation: continuation
            )
        }
    }

    private func consumeSurveyor(
        _ request: ScanRequest,
        expectedRootIdentity: FileIdentity,
        continuation: AsyncThrowingStream<QuickScanEvent, Error>.Continuation
    ) async throws -> QuickScanSummary {
        var batch: [SurveyorObservation] = []
        var summary = QuickScanSummary()
        var emittedFirstFact = false
        do {
            for try await observation in Surveyor().scan(request) {
                try Task.checkCancellation()
                let observation = try normalizedObservation(observation)
                if observation.relativePath == ".",
                   !stableIdentity(
                       observation.snapshot.fileIdentity,
                       matches: expectedRootIdentity
                   )
                {
                    throw SurveyorError.rootIdentityChanged
                }
                batch.append(observation)
                summary.record(observation)
                let batchLimit = emittedFirstFact
                    ? request.persistenceBatchSize
                    : 1
                if batch.count >= batchLimit {
                    try await persistAndEmit(
                        batch,
                        request: request,
                        continuation: continuation
                    )
                    emittedFirstFact = true
                    batch.removeAll(keepingCapacity: true)
                }
            }
            if !batch.isEmpty {
                try await persistAndEmit(
                    batch,
                    request: request,
                    continuation: continuation
                )
            }
            return summary
        } catch is CancellationError {
            throw CancellationError()
        } catch SurveyorError.cancelled {
            throw SurveyorError.cancelled
        } catch {
            throw error
        }
    }

    private func normalizedObservation(
        _ observation: SurveyorObservation
    ) throws -> SurveyorObservation {
        let source = observation.snapshot
        return SurveyorObservation(
            snapshot: try PathSnapshot(
                id: snapshotID(source.relativePath),
                sessionID: source.sessionID,
                scopeID: source.scopeID,
                relativePath: source.relativePath,
                kind: source.kind,
                logicalByteCount: source.logicalByteCount,
                allocatedByteCount: source.allocatedByteCount,
                modifiedAt: source.modifiedAt,
                fileIdentity: source.fileIdentity,
                symlinkTarget: source.symlinkTarget,
                measurementStatus: source.measurementStatus,
                observedAt: snapshotObservedAt?(source.relativePath)
                    ?? source.observedAt
            ),
            progress: observation.progress
        )
    }

    private func persistAndEmit(
        _ observations: [SurveyorObservation],
        request: ScanRequest,
        continuation: AsyncThrowingStream<QuickScanEvent, Error>.Continuation
    ) async throws {
        do {
            try await store.savePathSnapshots(
                observations.map(\.snapshot)
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw QuickScanPersistenceError.store
        }
        for observation in observations {
            try yield(
                .factObserved(.pathSnapshot(observation.snapshot)),
                continuation: continuation,
                request: request
            )
            try yield(
                .progress(
                    QuickScanProgress(
                        scopeID: request.scopeID,
                        currentRelativePath: try PersistedPath(
                            validating: observation.relativePath
                        ),
                        counters: observation.progress
                    )
                ),
                continuation: continuation,
                request: request
            )
            if let issue = observation.issue {
                try yield(
                    .issueObserved(
                        QuickScanIssueObservation(
                            scopeID: request.scopeID,
                            relativePath: try PersistedPath(
                                validating: observation.relativePath
                            ),
                            issue: issue,
                            observedAt: observation.observedAt
                        )
                    ),
                    continuation: continuation,
                    request: request
                )
            }
        }
    }

    private func finishAbnormally(
        request: ScanRequest,
        rootPath: PersistedPath,
        startedAt: Date,
        state: ScanTerminalState,
        reason: ScanScopeCompletionReason,
        streamError: Error?,
        continuation: AsyncThrowingStream<QuickScanEvent, Error>.Continuation
    ) async {
        do {
            let session = try makeTerminalSession(
                request: request,
                rootPath: rootPath,
                startedAt: startedAt,
                terminalState: state,
                reason: reason
            )
            try await store.saveScanSession(session)
            if streamError == nil {
                do {
                    try yield(
                        .scopeFinished(
                            .unfinished(session.unfinishedScopes[0])
                        ),
                        continuation: continuation,
                        request: request
                    )
                    try yield(
                        .terminal(session),
                        continuation: continuation,
                        request: request
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            } else {
                continuation.finish(throwing: streamError)
            }
        } catch {
            continuation.finish(
                throwing: QuickScanLifecycleError.terminalPersistenceFailed
            )
        }
    }

    private func makeTerminalSession(
        request: ScanRequest,
        rootPath: PersistedPath,
        startedAt: Date,
        terminalState: ScanTerminalState,
        reason: ScanScopeCompletionReason
    ) throws -> ScanSession {
        try ScanSession(
            id: request.sessionID,
            startedAt: startedAt,
            finishedAt: max(now(), startedAt),
            terminalState: terminalState,
            completedScopes: [],
            unfinishedScopes: [
                UnfinishedScanScope(
                    id: request.scopeID,
                    rootPath: rootPath,
                    reason: reason
                ),
            ]
        )
    }

    private func yield(
        _ event: QuickScanEvent,
        continuation: AsyncThrowingStream<QuickScanEvent, Error>.Continuation,
        request: ScanRequest
    ) throws {
        switch continuation.yield(event) {
        case .enqueued:
            break
        case .dropped:
            throw QuickScanLifecycleError.eventBufferExceeded(
                limit: request.lifecycleEventBufferCapacity
            )
        case .terminated:
            break
        @unknown default:
            throw QuickScanLifecycleError.eventBufferExceeded(
                limit: request.lifecycleEventBufferCapacity
            )
        }
    }
}

private func stableIdentity(
    _ actual: FileIdentity?,
    matches expected: FileIdentity
) -> Bool {
    guard let actual else {
        return false
    }
    return actual.device == expected.device
        && actual.inode == expected.inode
        && actual.mode & UInt16(S_IFMT) == expected.mode & UInt16(S_IFMT)
}

private struct QuickScanSummary {
    private(set) var partialReason: ScanScopeCompletionReason?

    mutating func record(_ observation: SurveyorObservation) {
        guard let issue = observation.issue else {
            return
        }
        let reason: ScanScopeCompletionReason
        switch issue {
        case .permissionDenied:
            reason = .permissionDenied
        case .mountBoundary:
            reason = .mountBoundary
        case .userExcluded:
            reason = .userExcluded
        case .metadataUnavailable, .directoryReadFailed:
            reason = .metadataChanged
        }
        if partialReason == nil || reason == .permissionDenied {
            partialReason = reason
        }
    }
}

private enum QuickScanPersistenceError: Error {
    case store
}

private final class QuickScanRunControl: @unchecked Sendable {
    private let lock = NSLock()
    private var task: Task<Void, Never>?
    private var cancelled = false

    func install(_ task: Task<Void, Never>) {
        let shouldCancel = lock.withLock {
            self.task = task
            return cancelled
        }
        if shouldCancel {
            task.cancel()
        }
    }

    func cancel() {
        let task = lock.withLock {
            cancelled = true
            return self.task
        }
        task?.cancel()
    }
}
