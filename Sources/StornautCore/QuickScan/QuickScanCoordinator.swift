import Foundation

protocol QuickScanProductPersisting: ScanSessionPersisting {
    func scanSession(id: ScanSessionID) async throws -> ScanSession?
    func scanSessions(
        limit: Int,
        offset: Int
    ) async throws -> StorePage<ScanSession>
    func pathSnapshots(
        sessionID: ScanSessionID,
        limit: Int,
        offset: Int
    ) async throws -> StorePage<PathSnapshot>
    func pathSnapshots(
        sessionID: ScanSessionID,
        after cursor: PathSnapshotCursor?,
        limit: Int
    ) async throws -> PathSnapshotCursorPage
    func saveClassifications(
        _ classifications: [Classification]
    ) async throws
    func classifications(
        sessionID: ScanSessionID,
        limit: Int,
        offset: Int,
        disposition: ReclaimDisposition?
    ) async throws -> StorePage<Classification>
    func saveEvidence(_ evidence: [EvidenceRecord]) async throws
    func evidence(
        sessionID: ScanSessionID,
        limit: Int,
        offset: Int
    ) async throws -> StorePage<EvidenceRecord>
    func saveSpaceLedger(_ ledger: SpaceLedger) async throws
    func volumeBaseline(
        sessionID: ScanSessionID,
        scopeID: ScanScopeID
    ) async throws -> VolumeBaseline?
    func spaceLedger(sessionID: ScanSessionID) async throws -> SpaceLedger?
    func quickScanSummary(
        sessionID: ScanSessionID
    ) async throws -> QuickScanStoreSummary
}

extension EvidenceStore: QuickScanProductPersisting {}

protocol QuickScanHistoryPersisting: Sendable {
    func expireRecords(now: Date) async throws
    func recordCounts() async throws -> EvidenceRecordCounts
    func clearEvidence() async throws
    func clearManifests() async throws
    func scanHistory(
        limit: Int,
        offset: Int
    ) async throws -> ScanHistoryPage
    func cleanupManifestHistory(
        limit: Int,
        offset: Int,
        now: Date
    ) async throws -> CleanupManifestHistoryPage
    func deleteScanSession(id: ScanSessionID) async throws
    func deleteCleanupManifest(id: CleanupManifestID) async throws -> Bool
}

extension EvidenceStore: QuickScanHistoryPersisting {}

protocol QuickScanActivityProviding: Sendable {
    func observations(
        for snapshot: PathSnapshot,
        rule: CompiledRule,
        rootURL: URL,
        observedAt: Date
    ) async throws -> [ActivityObservation]
}

protocol QuickScanGitActivityCollecting: Sendable {
    func collect(
        repositoryURL: URL,
        observedAt: Date
    ) async -> GitActivitySnapshot
}

extension GitActivityProvider: QuickScanGitActivityCollecting {}

struct ConservativeQuickScanActivityProvider:
    QuickScanActivityProviding
{
    init() {}

    func observations(
        for snapshot: PathSnapshot,
        rule: CompiledRule,
        rootURL: URL,
        observedAt: Date
    ) async throws -> [ActivityObservation] {
        try rule.requiredActivityKeys.map { key in
            let activityKey = try ActivityKey(validating: key.rawValue)
            return try ActivityObservation(
                key: activityKey,
                state: .unavailable,
                source: activityKey == .processInactive
                    ? .runningProcess
                    : .git,
                origin: .external,
                observedAt: observedAt,
                reason: try DomainToken(
                    validating: "activity.quick-scan.unavailable"
                )
            )
        }
    }
}

struct NativeQuickScanActivityProvider:
    QuickScanActivityProviding
{
    private let gitProvider: any QuickScanGitActivityCollecting

    init(
        gitProvider: any QuickScanGitActivityCollecting =
            GitActivityProvider()
    ) {
        self.gitProvider = gitProvider
    }

    func observations(
        for snapshot: PathSnapshot,
        rule: CompiledRule,
        rootURL: URL,
        observedAt: Date
    ) async throws -> [ActivityObservation] {
        var observations: [ActivityObservation] = []
        let requiredKeys = try rule.requiredActivityKeys.map {
            try ActivityKey(validating: $0.rawValue)
        }
        let requiresGit = requiredKeys.contains {
            $0 == .gitClean || $0 == .gitUpstreamSynchronized
        }
        let gitObservations: [ActivityObservation]
        if requiresGit {
            let candidateURL = rootURL.appending(
                path: snapshot.relativePath
            )
            gitObservations = await gitProvider.collect(
                repositoryURL: candidateURL.deletingLastPathComponent(),
                observedAt: observedAt
            ).observations
        } else {
            gitObservations = []
        }
        for activityKey in requiredKeys {
            switch activityKey {
            case .gitClean, .gitUpstreamSynchronized:
                observations.append(
                    gitObservations.first {
                        $0.key == activityKey
                    } ?? unavailableObservation(
                        key: activityKey,
                        source: .git,
                        observedAt: observedAt,
                        reason: "activity.quick-scan.git-unavailable"
                    )
                )
            case .processInactive:
                observations.append(
                    unavailableObservation(
                        key: activityKey,
                        source: .runningProcess,
                        observedAt: observedAt,
                        reason:
                            "activity.quick-scan.process-association-unavailable"
                    )
                )
            default:
                observations.append(
                    unavailableObservation(
                        key: activityKey,
                        source: .runningProcess,
                        observedAt: observedAt,
                        reason: "activity.quick-scan.unsupported"
                    )
                )
            }
        }
        return observations
    }
}

public actor QuickScanCoordinator {
    private static let pageSize = 100
    private static let snapshotPageSize = 4_096
    private static let projectionRecordLimit = 100

    public typealias SnapshotIDSource = @Sendable (String) -> SnapshotID
    public typealias ClassificationIDSource = @Sendable (
        SnapshotID
    ) -> ClassificationID
    public typealias EvidenceIDSource = @Sendable (
        SnapshotID,
        ActivityObservation
    ) -> EvidenceID
    public typealias ExecutionEvidenceIDSource = @Sendable (
        SnapshotID,
        DomainToken
    ) -> EvidenceID

    private let store: any QuickScanProductPersisting
    private let historyStore: (any QuickScanHistoryPersisting)?
    private let catalog: RuleCatalog
    private let matcher: RuleCatalogMatcher
    private let activityProvider: any QuickScanActivityProviding
    private let executionProfileCatalog: ExecutionProfileCatalog?
    private let executableEvidenceResolver: ExecutableEvidenceResolver?
    private let volumeSampler: any VolumeBaselineSampling
    private let now: @Sendable () -> Date
    private let snapshotID: SnapshotIDSource
    private let classificationID: ClassificationIDSource
    private let evidenceID: EvidenceIDSource
    private let executionEvidenceID: ExecutionEvidenceIDSource
    private var activeControl: QuickScanProductRunControl?
    private var activeWriter: ScanSessionWriter?
    private var scanIsActive = false
    private var scanStartIsPending = false
    private var historyReadCount = 0
    private var historyMutationIsActive = false

    private struct ProcessingFailure: Error {
        let issue: QuickScanProductIssue
        let underlying: any Error
    }

    private struct ProductClassificationResult {
        var snapshotCount = 0
        var classificationCount = 0
        var candidateCount = 0
        var evidenceCount = 0
        var dispositionCounts: [ReclaimDisposition: Int] =
            Dictionary(
                uniqueKeysWithValues: ReclaimDisposition.allCases.map {
                    ($0, 0)
                }
            )
        var ownerInputs: [SpaceLedgerOwnerInput] = []
        var projectedSnapshots: [PathSnapshot] = []
        var projectedSnapshotIDs = Set<SnapshotID>()
        var fallbackProjectedSnapshots: [PathSnapshot] = []
        var projectedClassifications: [Classification] = []
        var projectedEvidence: [EvidenceRecord] = []
        var issues: [QuickScanProductIssue] = []
        var corruptRecordIDs: [String] = []

        var closedDispositionCounts: QuickScanDispositionCounts {
            get throws {
                try QuickScanDispositionCounts(
                    readyToReclaim:
                        dispositionCounts[.readyToReclaim, default: 0],
                    reviewRecommended:
                        dispositionCounts[.reviewRecommended, default: 0],
                    protected: dispositionCounts[.protected, default: 0],
                    unknown: dispositionCounts[.unknown, default: 0]
                )
            }
        }
    }

    private struct BoundedProjectionLoad {
        var snapshots: [PathSnapshot] = []
        var classifications: [Classification] = []
        var evidence: [EvidenceRecord] = []
        var corruptRecordIDs: [String] = []
        var expectedClassificationCount = 0
        var observedClassificationCount = 0
        var candidateCount = 0
        var recoveredActivityIssues: [QuickScanProductIssue] = []
        var fallbackSnapshots: [PathSnapshot] = []
    }

    init(
        store: any QuickScanProductPersisting,
        historyStore: (any QuickScanHistoryPersisting)? = nil,
        catalog: RuleCatalog,
        activityProvider: any QuickScanActivityProviding =
            NativeQuickScanActivityProvider(),
        executionProfileCatalog: ExecutionProfileCatalog? = nil,
        executableEvidenceResolver: ExecutableEvidenceResolver? = nil,
        volumeSampler: any VolumeBaselineSampling =
            FoundationVolumeBaselineSampler(),
        now: @escaping @Sendable () -> Date = Date.init,
        snapshotID: @escaping SnapshotIDSource = { _ in SnapshotID() },
        classificationID: @escaping ClassificationIDSource = {
            _ in ClassificationID()
        },
        evidenceID: @escaping EvidenceIDSource = {
            _, _ in EvidenceID()
        },
        executionEvidenceID: @escaping ExecutionEvidenceIDSource = {
            _, _ in EvidenceID()
        }
    ) {
        self.store = store
        self.historyStore = historyStore
        self.catalog = catalog
        matcher = RuleCatalogMatcher(catalog: catalog)
        self.activityProvider = activityProvider
        self.executionProfileCatalog = executionProfileCatalog
        self.executableEvidenceResolver = executableEvidenceResolver
        self.volumeSampler = volumeSampler
        self.now = now
        self.snapshotID = snapshotID
        self.classificationID = classificationID
        self.evidenceID = evidenceID
        self.executionEvidenceID = executionEvidenceID
    }

    public init(
        store: EvidenceStore
    ) throws {
        let catalog = try BuiltInRuleCatalog.load()
        try self.init(
            store: store,
            historyStore: store,
            catalog: catalog,
            executionProfileCatalog:
                BuiltInExecutionProfileCatalog.load(
                    ruleCatalog: catalog
                ),
            executableEvidenceResolver: ExecutableEvidenceResolver()
        )
    }

#if DEBUG
    public static func phaseCTrashDiagnostic(
        store: EvidenceStore,
        resolver: ExecutableEvidenceResolver
    ) throws -> QuickScanCoordinator {
        let catalog = try BuiltInRuleCatalog.load()
        return try QuickScanCoordinator(
            store: store,
            historyStore: store,
            catalog: catalog,
            executionProfileCatalog:
                BuiltInExecutionProfileCatalog.load(
                    ruleCatalog: catalog
                ),
            executableEvidenceResolver: resolver
        )
    }
#endif

    public var hasActiveScan: Bool {
        scanIsActive
    }

    public func start(
        _ request: ScanRequest
    ) async throws -> AsyncThrowingStream<QuickScanProductEvent, Error> {
        guard !scanIsActive,
              !scanStartIsPending,
              !historyMutationIsActive
        else {
            throw QuickScanLifecycleError.scanAlreadyRunning
        }
        scanStartIsPending = true
        defer { scanStartIsPending = false }
        while historyReadCount > 0 {
            try await Task.sleep(for: .milliseconds(1))
        }
        guard !scanIsActive, !historyMutationIsActive else {
            throw QuickScanLifecycleError.scanAlreadyRunning
        }
        scanIsActive = true
        let control = QuickScanProductRunControl()
        activeControl = control
        return AsyncThrowingStream(
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
    }

    @discardableResult
    public func cancel() async -> Bool {
        guard activeControl?.requestCancellation() == true else {
            return false
        }
        await activeWriter?.cancelActiveScan()
        return true
    }

    public func loadLatest() async throws -> QuickScanProjection? {
        try beginHistoryRead()
        defer { historyReadCount -= 1 }
        try await historyStore?.expireRecords(now: now())
        guard let session = try await loadLatestValidSession() else {
            return nil
        }
        let summary = try await store.quickScanSummary(sessionID: session.id)
        let bounded = try await loadBoundedProjection(
            sessionID: session.id
        )
        let ledger = try await store.spaceLedger(sessionID: session.id)
        let corrupt = bounded.corruptRecordIDs
        var issues: [QuickScanProductIssue] = []
        if !corrupt.isEmpty {
            issues.append(
                QuickScanProductIssue(
                    kind: .corruptRecords,
                    affectedSnapshotID: nil,
                    reasonKey: DomainToken(
                        rawValue: "quick-scan.corrupt-records"
                    )!
                )
            )
        }
        issues.append(
            contentsOf: bounded.recoveredActivityIssues
        )
        let hasStoreFailure = session.unfinishedScopes.contains {
            $0.reason == .storeFailure
        }
        if hasStoreFailure {
            issues.append(
                productIssue(
                    .persistenceUnavailable,
                    snapshotID: nil,
                    reason: "quick-scan.persistence.recovered"
                )
            )
        }
        let classificationIsComplete =
            bounded.expectedClassificationCount
                == summary.classificationCount
                && bounded.observedClassificationCount
                    == summary.classificationCount
        let hasProductPartial = session.terminalState == .partial
            && !session.unfinishedScopes.contains {
                $0.reason == .interrupted
            }
        if (session.terminalState == .completed || hasProductPartial),
           !classificationIsComplete,
           !hasStoreFailure
        {
            issues.append(
                productIssue(
                    .classificationUnavailable,
                    snapshotID: nil,
                    reason: "quick-scan.classification.incomplete"
                )
            )
        }
        let hasMetadataFailure = session.unfinishedScopes.contains {
            $0.reason == .metadataChanged
        }
        if (session.terminalState == .completed
            || (hasMetadataFailure && classificationIsComplete)),
           ledger == nil
        {
            issues.append(
                productIssue(
                    .ledgerUnavailable,
                    snapshotID: nil,
                    reason: "quick-scan.ledger.unavailable"
                )
            )
        }
        issues = normalizedProductIssues(issues)
        let ledgerIsUsable = sessionHasCommittedProductTerminal(session)
            && classificationIsComplete
            && corrupt.isEmpty
            && ledger != nil
        let projectedSession = try projectionSession(
            session,
            hasCompleteFacts: ledgerIsUsable && issues.isEmpty
        )
        return try QuickScanProjection(
            session: projectedSession,
            snapshots: bounded.snapshots,
            classifications: bounded.classifications,
            evidence: bounded.evidence,
            ledger: ledgerIsUsable ? ledger : nil,
            issues: issues,
            corruptRecordIDs: corrupt,
            snapshotCount: summary.snapshotCount,
            classificationCount: summary.classificationCount,
            candidateCount: bounded.candidateCount,
            evidenceCount: summary.evidenceCount,
            dispositionCounts: summary.dispositionCounts
        )
    }

    public func loadHistory(
        limit: Int = 100,
        offset: Int = 0
    ) async throws -> ScanHistoryPage {
        try beginHistoryRead()
        defer { historyReadCount -= 1 }
        guard let historyStore else {
            throw EvidenceStoreError.schemaMismatch
        }
        try await historyStore.expireRecords(now: now())
        return try await historyStore.scanHistory(
            limit: limit,
            offset: offset
        )
    }

    public func loadHistorySnapshot(
        pageSize: Int = 50
    ) async throws -> EvidenceHistorySnapshot {
        guard pageSize > 0 else {
            throw EvidenceStoreError.invalidPage
        }
        try beginHistoryRead()
        defer { historyReadCount -= 1 }
        guard let historyStore else {
            throw EvidenceStoreError.schemaMismatch
        }
        let historyNow = now()
        try await historyStore.expireRecords(now: historyNow)
        var scanOffset = 0
        var sessions: [ScanSession] = []
        var ledgersBySessionID: [ScanSessionID: SpaceLedger] = [:]
        var corruptSessionIDs: [String] = []
        var corruptLedgerSessionIDs: [String] = []
        while true {
            let page = try await historyStore.scanHistory(
                limit: pageSize,
                offset: scanOffset
            )
            sessions.append(contentsOf: page.sessions)
            ledgersBySessionID.merge(
                page.ledgersBySessionID,
                uniquingKeysWith: { current, _ in current }
            )
            corruptSessionIDs.append(contentsOf: page.corruptSessionIDs)
            corruptLedgerSessionIDs.append(
                contentsOf: page.corruptLedgerSessionIDs
            )
            let rowCount = page.sessions.count
                + page.corruptSessionIDs.count
            guard rowCount == pageSize else {
                break
            }
            scanOffset += rowCount
        }
        var manifestOffset = 0
        var manifests: [CleanupManifestHistoryRecord] = []
        var corruptManifestIDs: [String] = []
        while true {
            let page = try await historyStore.cleanupManifestHistory(
                limit: pageSize,
                offset: manifestOffset,
                now: historyNow
            )
            manifests.append(contentsOf: page.records)
            corruptManifestIDs.append(
                contentsOf: page.corruptManifestIDs
            )
            let rowCount = page.records.count
                + page.corruptManifestIDs.count
            guard rowCount == pageSize else {
                break
            }
            manifestOffset += rowCount
        }
        return EvidenceHistorySnapshot(
            scans: ScanHistoryPage(
                sessions: sessions,
                ledgersBySessionID: ledgersBySessionID,
                corruptSessionIDs:
                    Array(Set(corruptSessionIDs)).sorted(),
                corruptLedgerSessionIDs:
                    Array(Set(corruptLedgerSessionIDs)).sorted()
            ),
            manifests: CleanupManifestHistoryPage(
                records: manifests,
                corruptManifestIDs: corruptManifestIDs
            )
        )
    }

    public func deleteHistorySession(
        id: ScanSessionID
    ) async throws {
        try beginHistoryMutation()
        defer { historyMutationIsActive = false }
        guard let historyStore else {
            throw EvidenceStoreError.schemaMismatch
        }
        try await historyStore.deleteScanSession(id: id)
    }

    @discardableResult
    public func deleteHistoryManifest(
        id: CleanupManifestID
    ) async throws -> Bool {
        try beginHistoryMutation()
        defer { historyMutationIsActive = false }
        guard let historyStore else {
            throw EvidenceStoreError.schemaMismatch
        }
        return try await historyStore.deleteCleanupManifest(id: id)
    }

    public func loadRecordCounts() async throws -> EvidenceRecordCounts {
        try beginHistoryRead()
        defer { historyReadCount -= 1 }
        guard let historyStore else {
            throw EvidenceStoreError.schemaMismatch
        }
        try await historyStore.expireRecords(now: now())
        return try await historyStore.recordCounts()
    }

    public func clearEvidenceRecords() async throws {
        try beginHistoryMutation()
        defer { historyMutationIsActive = false }
        guard let historyStore else {
            throw EvidenceStoreError.schemaMismatch
        }
        try await historyStore.clearEvidence()
    }

    public func clearManifestRecords() async throws {
        try beginHistoryMutation()
        defer { historyMutationIsActive = false }
        guard let historyStore else {
            throw EvidenceStoreError.schemaMismatch
        }
        try await historyStore.clearManifests()
    }

    private func beginHistoryRead() throws {
        guard !scanIsActive,
              !scanStartIsPending,
              !historyMutationIsActive
        else {
            throw QuickScanLifecycleError.scanAlreadyRunning
        }
        historyReadCount += 1
    }

    private func beginHistoryMutation() throws {
        guard !scanIsActive,
              !scanStartIsPending,
              historyReadCount == 0,
              !historyMutationIsActive
        else {
            throw QuickScanLifecycleError.scanAlreadyRunning
        }
        historyMutationIsActive = true
    }

    private func execute(
        _ request: ScanRequest,
        continuation: AsyncThrowingStream<
            QuickScanProductEvent,
            Error
        >.Continuation
    ) async {
        defer {
            scanIsActive = false
            activeWriter = nil
            activeControl = nil
        }
        let observationTime = now()
        let productAccumulator = ProductScanAccumulator(
            matcher: matcher,
            displayFactLimit: Self.projectionRecordLimit
        )
        let writer = ScanSessionWriter(
            store: store,
            volumeSampler: volumeSampler,
            now: now,
            sessionStartedAt: observationTime,
            snapshotID: snapshotID,
            snapshotObservedAt: { _ in observationTime },
            defersProductFinalization: true,
            productAccumulator: productAccumulator
        )
        activeWriter = writer
        do {
            let stream = try await writer.run(request)
            if activeControl?.isCancellationRequested == true {
                await writer.cancelActiveScan()
            }
            var scanTerminal: ScanSession?
            for try await event in stream {
                switch event {
                case let .stageChanged(stage)
                    where stage == .indexVolumes || stage == .mapProjects:
                    try emit(
                        .stageChanged(stage),
                        to: continuation,
                        limit: request.lifecycleEventBufferCapacity
                    )
                case let .progress(progress):
                    try emit(
                        .progress(progress),
                        to: continuation,
                        limit: request.lifecycleEventBufferCapacity
                    )
                case .factObserved(.pathSnapshot):
                    break
                case let .issueObserved(issue):
                    try emit(
                        .issueObserved(issue),
                        to: continuation,
                        limit: request.lifecycleEventBufferCapacity
                    )
                case let .terminal(session):
                    scanTerminal = session
                default:
                    break
                }
            }
            guard let scanTerminal else {
                throw QuickScanProductError.missingScanTerminal
            }
            if scanTerminal.terminalState == .cancelled
                || scanTerminal.terminalState == .failed
            {
                let projection = try await incompleteProjection(
                    session: scanTerminal
                )
                try emit(
                    .terminal(projection),
                    to: continuation,
                    limit: request.lifecycleEventBufferCapacity
                )
                continuation.finish()
                return
            }
            try checkProductCancellation()
            try emit(
                .stageChanged(.classifyArtifacts),
                to: continuation,
                limit: request.lifecycleEventBufferCapacity
            )
            try emit(
                .stageChanged(.checkActivity),
                to: continuation,
                limit: request.lifecycleEventBufferCapacity
            )
            let classifiedAt = now()
            var product = try await classifyPersistedSnapshots(
                request: request,
                classifiedAt: classifiedAt,
                continuation: continuation
            )
            let scanReduction = try productAccumulator.reduction()
            product.snapshotCount = scanReduction.aggregate.entries.total
            if !product.corruptRecordIDs.isEmpty {
                product.issues.append(
                    productIssue(
                        .corruptRecords,
                        snapshotID: nil,
                        reason: "quick-scan.snapshot.corrupt"
                    )
                )
            }
            try checkProductCancellation()
            try emit(
                .stageChanged(.finalizeSnapshot),
                to: continuation,
                limit: request.lifecycleEventBufferCapacity
            )
            let startBaseline: VolumeBaseline
            do {
                guard let baseline = try await store.volumeBaseline(
                    sessionID: request.sessionID,
                    scopeID: request.scopeID
                ) else {
                    throw QuickScanProductError.missingBaseline
                }
                startBaseline = baseline
            } catch {
                throw ProcessingFailure(
                    issue: productIssue(
                        .ledgerUnavailable,
                        snapshotID: nil,
                        reason: "quick-scan.ledger.baseline-unavailable"
                    ),
                    underlying: error
                )
            }
            let endBaseline: VolumeBaseline
            do {
                endBaseline = try volumeSampler.sample(
                    request: request,
                    sampledAt: now()
                )
            } catch {
                throw ProcessingFailure(
                    issue: productIssue(
                        .ledgerUnavailable,
                        snapshotID: nil,
                        reason:
                            "quick-scan.ledger.end-baseline-unavailable"
                    ),
                    underlying: error
                )
            }
            let ledger: SpaceLedger
            do {
                ledger = try reconcileScanReduction(
                    scanReduction,
                    startBaseline: startBaseline,
                    endBaseline: endBaseline,
                    ownerInputs: product.ownerInputs
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw ProcessingFailure(
                    issue: productIssue(
                        .ledgerUnavailable,
                        snapshotID: nil,
                        reason: "quick-scan.ledger.unavailable"
                    ),
                    underlying: error
                )
            }
            try checkProductCancellation()
            try commitProductFinalization()
            do {
                try await store.saveSpaceLedger(ledger)
            } catch {
                throw ProcessingFailure(
                    issue: productIssue(
                        .persistenceUnavailable,
                        snapshotID: nil,
                        reason: "quick-scan.ledger.persistence-unavailable"
                    ),
                    underlying: error
                )
            }
            try checkProductCancellation()
            try emit(
                .ledgerUpdated(ledger),
                to: continuation,
                limit: request.lifecycleEventBufferCapacity
            )
            for issue in product.issues {
                try emit(
                    .productIssueObserved(issue),
                    to: continuation,
                    limit: request.lifecycleEventBufferCapacity
                )
            }
            let terminal = try finalSession(
                scanTerminal: scanTerminal,
                request: request,
                issues: product.issues
            )
            do {
                try await store.saveScanSession(terminal)
            } catch {
                throw ProcessingFailure(
                    issue: productIssue(
                        .persistenceUnavailable,
                        snapshotID: nil,
                        reason:
                            "quick-scan.terminal.persistence-unavailable"
                    ),
                    underlying: error
                )
            }
            let projection = try QuickScanProjection(
                session: terminal,
                snapshots: product.projectedSnapshots,
                classifications: product.projectedClassifications,
                evidence: product.projectedEvidence,
                ledger: ledger,
                issues: product.issues,
                corruptRecordIDs: product.corruptRecordIDs,
                snapshotCount: product.snapshotCount,
                classificationCount: product.classificationCount,
                candidateCount: product.candidateCount,
                evidenceCount: product.evidenceCount,
                dispositionCounts: try product.closedDispositionCounts
            )
            try emit(
                .terminal(projection),
                to: continuation,
                limit: request.lifecycleEventBufferCapacity
            )
            continuation.finish()
        } catch is CancellationError {
            await writer.cancelActiveScan()
            await finishCancelled(
                request: request,
                continuation: continuation
            )
            await waitForWriterToStop(writer)
        } catch let failure as ProcessingFailure {
            await writer.cancelActiveScan()
            await waitForWriterToStop(writer)
            await finishPartially(
                request: request,
                issue: failure.issue,
                continuation: continuation
            )
        } catch let error as QuickScanLifecycleError {
            await writer.cancelActiveScan()
            await waitForWriterToStop(writer)
            if case let .eventBufferExceeded(limit) = error {
                continuation.finish(
                    throwing: QuickScanProductError.eventBufferExceeded(
                        limit: limit
                    )
                )
            } else {
                continuation.finish(throwing: error)
            }
        } catch {
            await writer.cancelActiveScan()
            await waitForWriterToStop(writer)
            continuation.finish(throwing: error)
        }
    }

    private func finishPartially(
        request: ScanRequest,
        issue: QuickScanProductIssue,
        continuation: AsyncThrowingStream<
            QuickScanProductEvent,
            Error
        >.Continuation
    ) async {
        do {
            guard let current = try await store.scanSession(
                id: request.sessionID
            ) else {
                throw QuickScanProductError.missingScanTerminal
            }
            let rootPath = try PersistedPath(
                validating: request.rootURL.standardizedFileURL.path
            )
            let partial = try ScanSession(
                id: current.id,
                startedAt: current.startedAt,
                finishedAt: max(now(), current.finishedAt),
                terminalState: .partial,
                completedScopes: [],
                unfinishedScopes: [
                    UnfinishedScanScope(
                        id: request.scopeID,
                        rootPath: rootPath,
                        reason: partialReason(for: issue)
                    ),
                ],
                aggregate: current.aggregate
            )
            do {
                try await store.saveScanSession(partial)
            } catch {
                continuation.finish(throwing: error)
                return
            }
            var projectionIssues = [issue]
            let summary: QuickScanStoreSummary
            do {
                summary = try await store.quickScanSummary(
                    sessionID: request.sessionID
                )
            } catch {
                continuation.finish(throwing: error)
                return
            }
            let bounded: BoundedProjectionLoad
            do {
                bounded = try await loadBoundedProjection(
                    sessionID: request.sessionID
                )
            } catch {
                projectionIssues.append(
                    productIssue(
                        .persistenceUnavailable,
                        snapshotID: nil,
                        reason:
                            "quick-scan.classification.reload-unavailable"
                    )
                )
                let snapshots = try await store.pathSnapshots(
                    sessionID: request.sessionID,
                    limit: Self.projectionRecordLimit,
                    offset: 0
                )
                bounded = BoundedProjectionLoad(
                    snapshots: snapshots.records,
                    classifications: [],
                    evidence: [],
                    corruptRecordIDs: snapshots.corruptRecordIDs,
                    expectedClassificationCount: 0,
                    observedClassificationCount: 0,
                    candidateCount: 0,
                    recoveredActivityIssues: []
                )
            }
            let storedLedger: SpaceLedger?
            do {
                storedLedger = try await store.spaceLedger(
                    sessionID: request.sessionID
                )
            } catch {
                storedLedger = nil
                projectionIssues.append(
                    productIssue(
                        .persistenceUnavailable,
                        snapshotID: nil,
                        reason: "quick-scan.ledger.reload-unavailable"
                    )
                )
            }
            let ledgerIsUsable = storedLedger != nil
                && bounded.expectedClassificationCount
                    == summary.classificationCount
                && bounded.observedClassificationCount
                    == summary.classificationCount
                && bounded.corruptRecordIDs.isEmpty
            let projection = try QuickScanProjection(
                session: partial,
                snapshots: bounded.snapshots,
                classifications: bounded.classifications,
                evidence: bounded.evidence,
                ledger: ledgerIsUsable ? storedLedger : nil,
                issues: projectionIssues,
                corruptRecordIDs: bounded.corruptRecordIDs,
                snapshotCount: summary.snapshotCount,
                classificationCount: summary.classificationCount,
                candidateCount: bounded.candidateCount,
                evidenceCount: summary.evidenceCount,
                dispositionCounts: summary.dispositionCounts
            )
            for issue in projectionIssues {
                try emit(
                    .productIssueObserved(issue),
                    to: continuation,
                    limit: request.lifecycleEventBufferCapacity
                )
            }
            try emit(
                .terminal(projection),
                to: continuation,
                limit: request.lifecycleEventBufferCapacity
            )
            continuation.finish()
        } catch {
            continuation.finish(throwing: error)
        }
    }

    private func partialReason(
        for issue: QuickScanProductIssue
    ) -> ScanScopeCompletionReason {
        switch issue.kind {
        case .persistenceUnavailable:
            .storeFailure
        case .activityUnavailable,
             .classificationUnavailable,
             .ledgerUnavailable,
             .corruptRecords:
            .metadataChanged
        }
    }

    private func finishCancelled(
        request: ScanRequest,
        continuation: AsyncThrowingStream<
            QuickScanProductEvent,
            Error
        >.Continuation
    ) async {
        do {
            let deadline = ContinuousClock().now.advanced(
                by: .seconds(2)
            )
            var persistedSession: ScanSession?
            while ContinuousClock().now < deadline {
                persistedSession = try await store.scanSession(
                    id: request.sessionID
                )
                if persistedSession?.terminalState == .cancelled {
                    break
                }
                try await Task.sleep(for: .milliseconds(10))
            }
            guard let observed = persistedSession else {
                throw QuickScanProductError.missingScanTerminal
            }
            let session: ScanSession
            if observed.terminalState == .cancelled {
                session = observed
            } else {
                let rootPath = try PersistedPath(
                    validating: request.rootURL.standardizedFileURL.path
                )
                session = try ScanSession(
                    id: request.sessionID,
                    startedAt: observed.startedAt,
                    finishedAt: max(now(), observed.finishedAt),
                    terminalState: .cancelled,
                    completedScopes: [],
                    unfinishedScopes: [
                        UnfinishedScanScope(
                            id: request.scopeID,
                            rootPath: rootPath,
                            reason: .cancelled
                        ),
                    ],
                    aggregate: observed.aggregate
                )
                try await store.saveScanSession(session)
            }
            try emit(
                .terminal(
                    try await incompleteProjection(session: session)
                ),
                to: continuation,
                limit: request.lifecycleEventBufferCapacity
            )
            continuation.finish()
        } catch {
            continuation.finish(throwing: error)
        }
    }

    private func checkProductCancellation() throws {
        if activeControl?.isCancellationRequested == true {
            throw CancellationError()
        }
    }

    private func commitProductFinalization() throws {
        guard activeControl?.commitFinalization() == true else {
            throw CancellationError()
        }
    }

    private func waitForWriterToStop(
        _ writer: ScanSessionWriter
    ) async {
        while await writer.hasActiveScan {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    private func incompleteProjection(
        session: ScanSession
    ) async throws -> QuickScanProjection {
        let summary = try await store.quickScanSummary(
            sessionID: session.id
        )
        let snapshots = try await store.pathSnapshots(
            sessionID: session.id,
            limit: Self.projectionRecordLimit,
            offset: 0
        )
        return try QuickScanProjection(
            session: session,
            snapshots: snapshots.records,
            classifications: [],
            evidence: [],
            ledger: nil,
            issues: [],
            corruptRecordIDs: snapshots.corruptRecordIDs,
            snapshotCount: summary.snapshotCount,
            classificationCount: summary.classificationCount,
            candidateCount: 0,
            evidenceCount: summary.evidenceCount,
            dispositionCounts: summary.dispositionCounts
        )
    }

    private func classifyPersistedSnapshots(
        request: ScanRequest,
        classifiedAt: Date,
        continuation: AsyncThrowingStream<
            QuickScanProductEvent,
            Error
        >.Continuation
    ) async throws -> ProductClassificationResult {
        var result = ProductClassificationResult()
        var cursor: PathSnapshotCursor?
        let executionActivityContext: RunningActivityContext?
        if let executableEvidenceResolver,
           executionProfileCatalog != nil
        {
            executionActivityContext =
                await executableEvidenceResolver.captureActivity(
                    observedAt: classifiedAt
                )
        } else {
            executionActivityContext = nil
        }
        while true {
            try checkProductCancellation()
            let cursorPage = try await store.pathSnapshots(
                sessionID: request.sessionID,
                after: cursor,
                limit: Self.snapshotPageSize
            )
            let page = cursorPage.page
            result.snapshotCount += page.records.count
            result.corruptRecordIDs.append(
                contentsOf: page.corruptRecordIDs
            )
            let candidates: [SnapshotID: [CompiledRule]]
            do {
                candidates = try candidateMap(snapshots: page.records)
            } catch {
                throw ProcessingFailure(
                    issue: productIssue(
                        .classificationUnavailable,
                        snapshotID: nil,
                        reason: "quick-scan.classification.unavailable"
                    ),
                    underlying: error
                )
            }
            let targetIDs = classificationTargetIDs(
                snapshots: page.records,
                candidates: candidates
            )
            if result.fallbackProjectedSnapshots.count
                < Self.projectionRecordLimit
            {
                for snapshot in page.records
                where !targetIDs.contains(snapshot.id)
                    && result.fallbackProjectedSnapshots.count
                        < Self.projectionRecordLimit
                {
                    result.fallbackProjectedSnapshots.append(snapshot)
                }
            }
            var classificationBatch: [Classification] = []
            var evidenceBatch: [EvidenceRecord] = []
            var projectedPairs: [(PathSnapshot, Classification)] = []
            for snapshot in page.records where targetIDs.contains(snapshot.id) {
                try checkProductCancellation()
                let rules = candidates[snapshot.id, default: []]
                if result.projectedSnapshots.count
                    < Self.projectionRecordLimit
                {
                    result.projectedSnapshots.append(snapshot)
                    result.projectedSnapshotIDs.insert(snapshot.id)
                }
                var observations: [ActivityObservation] = []
                var satisfiedEvidence = satisfiedEvidence(
                    for: snapshot,
                    rules: rules
                )
                var evidence: [EvidenceRecord] = []
                if rules.count == 1,
                   let rule = rules.first,
                   let profile = executionProfileCatalog?.profile(
                       ruleID: rule.id
                   ),
                   let executableEvidenceResolver,
                   let executionActivityContext,
                   executionProfileCatalog?.ruleCatalogVersion
                    == catalog.catalogVersion
                {
                    do {
                        let resolution =
                            try executableEvidenceResolver.resolveQuickScan(
                            snapshot: snapshot,
                            rule: rule,
                            profile: profile,
                            profileCatalogVersion:
                                executionProfileCatalog!.catalogVersion,
                            activityContext: executionActivityContext,
                            evidenceID: executionEvidenceID
                        )
                        observations = resolution.activityObservations
                        satisfiedEvidence =
                            resolution.satisfiedEvidenceKeys
                        evidence = resolution.evidenceRecords
                    } catch {
                        do {
                            observations = try providerFailureObservations(
                                for: rule,
                                observedAt: classifiedAt
                            )
                        } catch {
                            throw ProcessingFailure(
                                issue: productIssue(
                                    .activityUnavailable,
                                    snapshotID: snapshot.id,
                                    reason:
                                        "quick-scan.activity.provider-failure"
                                ),
                                underlying: error
                            )
                        }
                        result.issues.append(
                            productIssue(
                                .activityUnavailable,
                                snapshotID: snapshot.id,
                                reason:
                                    "quick-scan.activity.provider-failure"
                            )
                        )
                    }
                } else if rules.count == 1,
                          let rule = rules.first,
                          rule.id.rawValue == "cache-uv",
                          let executableEvidenceResolver,
                          let executionActivityContext
                {
                    observations = [
                        executableEvidenceResolver.evaluateActivity(
                            subjects: Self.uvReadOnlyProcessSubjects,
                            context: executionActivityContext
                        ),
                    ]
                } else if rules.count == 1,
                          let rule = rules.first,
                          !rule.veto,
                          !rule.requiredActivityKeys.isEmpty
                {
                    do {
                        observations = try await activityProvider.observations(
                            for: snapshot,
                            rule: rule,
                            rootURL: request.rootURL,
                            observedAt: classifiedAt
                        )
                    } catch {
                        do {
                            observations = try providerFailureObservations(
                                for: rule,
                                observedAt: classifiedAt
                            )
                        } catch {
                            throw ProcessingFailure(
                                issue: productIssue(
                                    .activityUnavailable,
                                    snapshotID: snapshot.id,
                                    reason:
                                        "quick-scan.activity.provider-failure"
                                ),
                                underlying: error
                            )
                        }
                        result.issues.append(
                            productIssue(
                                .activityUnavailable,
                                snapshotID: snapshot.id,
                                reason:
                                    "quick-scan.activity.provider-failure"
                            )
                        )
                    }
                }
                if evidence.isEmpty {
                    evidence = observations.map {
                        evidenceRecord(
                            snapshotID: snapshot.id,
                            observation: $0
                        )
                    }
                }
                let classification: Classification
                do {
                    classification = try DeterministicClassifier().classify(
                        snapshot: snapshot,
                        candidates: rules,
                        satisfiedEvidenceKeys: satisfiedEvidence,
                        activityObservations: observations,
                        classifiedAt: classifiedAt,
                        classificationID: classificationID(snapshot.id),
                        catalogVersion: catalog.catalogVersion
                    )
                } catch {
                    throw ProcessingFailure(
                        issue: productIssue(
                            .classificationUnavailable,
                            snapshotID: snapshot.id,
                            reason: "quick-scan.classification.unavailable"
                        ),
                        underlying: error
                    )
                }
                result.classificationCount += 1
                if snapshot.relativePath != "." {
                    result.candidateCount += 1
                }
                result.evidenceCount += evidence.count
                result.dispositionCounts[
                    classification.disposition,
                    default: 0
                ] += 1
                result.ownerInputs.append(
                    SpaceLedgerOwnerInput(
                        snapshot: snapshot,
                        classification: classification
                    )
                )
                classificationBatch.append(classification)
                evidenceBatch.append(contentsOf: evidence)
                if result.projectedSnapshotIDs.contains(snapshot.id) {
                    result.projectedClassifications.append(classification)
                    result.projectedEvidence.append(contentsOf: evidence)
                    projectedPairs.append((snapshot, classification))
                }
            }
            try checkProductCancellation()
            do {
                try await store.saveEvidence(evidenceBatch)
                try await store.saveClassifications(classificationBatch)
            } catch {
                throw ProcessingFailure(
                    issue: productIssue(
                        .persistenceUnavailable,
                        snapshotID: nil,
                        reason:
                            "quick-scan.classification.persistence-unavailable"
                    ),
                    underlying: error
                )
            }
            for (snapshot, classification) in projectedPairs {
                try emit(
                    .classifiedSnapshotObserved(
                        snapshot,
                        classification
                    ),
                    to: continuation,
                    limit: request.lifecycleEventBufferCapacity
                )
            }
            let projectedIDs = Set(
                projectedPairs.map { $0.0.id }
            )
            for evidence in evidenceBatch
            where projectedIDs.contains(evidence.targetID)
            {
                try emit(
                    .evidenceObserved(evidence),
                    to: continuation,
                    limit: request.lifecycleEventBufferCapacity
                )
            }
            if cursorPage.rowCount < Self.snapshotPageSize {
                break
            }
            guard let next = cursorPage.nextCursor, next != cursor else {
                throw DomainContractError.invalidMeasurement
            }
            cursor = next
        }
        for snapshot in result.fallbackProjectedSnapshots
        where result.projectedSnapshots.count < Self.projectionRecordLimit
        {
            result.projectedSnapshots.append(snapshot)
            result.projectedSnapshotIDs.insert(snapshot.id)
        }
        result.issues = normalizedProductIssues(result.issues)
        result.corruptRecordIDs = Array(
            Set(result.corruptRecordIDs)
        ).sorted()
        return result
    }

    private func reconcileScanReduction(
        _ reduction: ProductScanReduction,
        startBaseline: VolumeBaseline,
        endBaseline: VolumeBaseline,
        ownerInputs: [SpaceLedgerOwnerInput]
    ) throws -> SpaceLedger {
        var accumulator = try IncrementalSpaceLedger(
            startBaseline: startBaseline,
            endBaseline: endBaseline,
            ownerInputs: ownerInputs
        )
        for owner in reduction.ownerBytes {
            try accumulator.consumePreaggregated(
                ownerID: owner.snapshotID,
                logical: owner.logicalBytes,
                allocated: owner.allocatedBytes,
                observedAt: owner.observedAt
            )
        }
        for gap in reduction.gaps {
            try accumulator.consumePreaggregatedGap(gap)
        }
        accumulator.recordPreaggregatedCaveats(
            sparse: reduction.sparseObserved,
            hardLinkDeduplicated: reduction.hardLinkDeduplicated,
            hardLinkOwnershipAmbiguous:
                reduction.hardLinkOwnershipAmbiguous
        )
        return try accumulator.finish()
    }

    private func loadBoundedProjection(
        sessionID: ScanSessionID
    ) async throws -> BoundedProjectionLoad {
        var result = BoundedProjectionLoad()
        var projectedIDs = Set<SnapshotID>()
        var snapshotCursor: PathSnapshotCursor?
        while true {
            let cursorPage = try await store.pathSnapshots(
                sessionID: sessionID,
                after: snapshotCursor,
                limit: Self.snapshotPageSize
            )
            let page = cursorPage.page
            result.corruptRecordIDs.append(
                contentsOf: page.corruptRecordIDs
            )
            let pageTargetIDs = try classificationTargetIDs(
                snapshots: page.records
            )
            result.expectedClassificationCount += pageTargetIDs.count
            if result.fallbackSnapshots.count < Self.projectionRecordLimit {
                for snapshot in page.records
                where !pageTargetIDs.contains(snapshot.id)
                    && result.fallbackSnapshots.count
                        < Self.projectionRecordLimit
                {
                    result.fallbackSnapshots.append(snapshot)
                }
            }
            if result.snapshots.count < Self.projectionRecordLimit {
                for snapshot in page.records
                where pageTargetIDs.contains(snapshot.id)
                    && result.snapshots.count
                        < Self.projectionRecordLimit
                {
                    result.snapshots.append(snapshot)
                    projectedIDs.insert(snapshot.id)
                }
            }
            if cursorPage.rowCount < Self.snapshotPageSize {
                break
            }
            guard let next = cursorPage.nextCursor,
                  next != snapshotCursor
            else {
                throw DomainContractError.invalidMeasurement
            }
            snapshotCursor = next
        }
        for snapshot in result.fallbackSnapshots
        where result.snapshots.count < Self.projectionRecordLimit
        {
            result.snapshots.append(snapshot)
            projectedIDs.insert(snapshot.id)
        }

        var classificationOffset = 0
        while true {
            let page = try await store.classifications(
                sessionID: sessionID,
                limit: Self.pageSize,
                offset: classificationOffset,
                disposition: nil
            )
            result.observedClassificationCount += page.records.count
            result.corruptRecordIDs.append(
                contentsOf: page.corruptRecordIDs
            )
            result.classifications.append(
                contentsOf: page.records.filter {
                    projectedIDs.contains($0.snapshotID)
                }
            )
            let consumed = page.records.count
                + page.corruptRecordIDs.count
            if consumed < Self.pageSize {
                break
            }
            classificationOffset += consumed
        }
        let projectedPathByID = Dictionary(
            uniqueKeysWithValues: result.snapshots.map {
                ($0.id, $0.relativePath)
            }
        )
        let rootClassificationCount = result.classifications.count {
            projectedPathByID[$0.snapshotID] == "."
        }
        result.candidateCount = max(
            0,
            result.observedClassificationCount - rootClassificationCount
        )

        var evidenceOffset = 0
        var allActivityFailures: [EvidenceRecord] = []
        while true {
            let page = try await store.evidence(
                sessionID: sessionID,
                limit: Self.pageSize,
                offset: evidenceOffset
            )
            result.corruptRecordIDs.append(
                contentsOf: page.corruptRecordIDs
            )
            for record in page.records {
                if projectedIDs.contains(record.targetID) {
                    result.evidence.append(record)
                }
                if record.source.kind == .activityProvider,
                   record.summaryKey.rawValue
                    == "quick-scan.activity.provider-failure"
                {
                    allActivityFailures.append(record)
                }
            }
            let consumed = page.records.count
                + page.corruptRecordIDs.count
            if consumed < Self.pageSize {
                break
            }
            evidenceOffset += consumed
        }
        result.recoveredActivityIssues = recoveredActivityIssues(
            from: allActivityFailures
        )
        result.corruptRecordIDs = Array(
            Set(result.corruptRecordIDs)
        ).sorted()
        return result
    }

    private func loadAllSnapshots(
        sessionID: ScanSessionID
    ) async throws -> StorePage<PathSnapshot> {
        var records: [PathSnapshot] = []
        var corrupt: [String] = []
        var offset = 0
        while true {
            let page = try await store.pathSnapshots(
                sessionID: sessionID,
                limit: 100,
                offset: offset
            )
            records.append(contentsOf: page.records)
            corrupt.append(contentsOf: page.corruptRecordIDs)
            let consumed = page.records.count + page.corruptRecordIDs.count
            if consumed < 100 {
                break
            }
            offset += consumed
        }
        return StorePage(records: records, corruptRecordIDs: corrupt)
    }

    private func loadLatestValidSession() async throws -> ScanSession? {
        var offset = 0
        while true {
            let page = try await store.scanSessions(
                limit: 100,
                offset: offset
            )
            if let session = page.records.first {
                return session
            }
            let consumed = page.records.count + page.corruptRecordIDs.count
            if consumed < 100 {
                return nil
            }
            offset += consumed
        }
    }

    private func loadAllClassifications(
        sessionID: ScanSessionID
    ) async throws -> StorePage<Classification> {
        var records: [Classification] = []
        var corrupt: [String] = []
        var offset = 0
        while true {
            let page = try await store.classifications(
                sessionID: sessionID,
                limit: 100,
                offset: offset,
                disposition: nil
            )
            records.append(contentsOf: page.records)
            corrupt.append(contentsOf: page.corruptRecordIDs)
            let consumed = page.records.count + page.corruptRecordIDs.count
            if consumed < 100 {
                break
            }
            offset += consumed
        }
        return StorePage(records: records, corruptRecordIDs: corrupt)
    }

    private func loadAllEvidence(
        sessionID: ScanSessionID
    ) async throws -> StorePage<EvidenceRecord> {
        var records: [EvidenceRecord] = []
        var corrupt: [String] = []
        var offset = 0
        while true {
            let page = try await store.evidence(
                sessionID: sessionID,
                limit: 100,
                offset: offset
            )
            records.append(contentsOf: page.records)
            corrupt.append(contentsOf: page.corruptRecordIDs)
            let consumed = page.records.count + page.corruptRecordIDs.count
            if consumed < 100 {
                break
            }
            offset += consumed
        }
        return StorePage(records: records, corruptRecordIDs: corrupt)
    }

    private func candidateMap(
        snapshots: [PathSnapshot]
    ) throws -> [SnapshotID: [CompiledRule]] {
        var result: [SnapshotID: [CompiledRule]] = [:]
        for snapshot in snapshots {
            guard snapshot.measurementStatus == .measured,
                  snapshot.relativePath != ".",
                  let kind = ruleKind(snapshot.kind)
            else {
                result[snapshot.id] = []
                continue
            }
            do {
                result[snapshot.id] = try matcher.matchingRules(
                    relativePath: snapshot.relativePath,
                    kind: kind
                )
            } catch RuleCatalogError.invalidPattern {
                result[snapshot.id] = []
            }
        }
        return result
    }

    private func classificationTargetIDs(
        snapshots: [PathSnapshot]
    ) throws -> Set<SnapshotID> {
        let candidates = try candidateMap(snapshots: snapshots)
        return classificationTargetIDs(
            snapshots: snapshots,
            candidates: candidates
        )
    }

    private func classificationTargetIDs(
        snapshots: [PathSnapshot],
        candidates: [SnapshotID: [CompiledRule]]
    ) -> Set<SnapshotID> {
        return Set(snapshots.compactMap { snapshot in
            guard snapshot.measurementStatus == .measured else {
                return nil
            }
            let rules = candidates[snapshot.id, default: []]
            let isRootOrTopLevelDirectory = snapshot.kind == .directory
                && (
                    snapshot.relativePath == "."
                        || !snapshot.relativePath.contains("/")
                )
            return !rules.isEmpty || isRootOrTopLevelDirectory
                ? snapshot.id
                : nil
        })
    }

    private func satisfiedEvidence(
        for snapshot: PathSnapshot,
        rules: [CompiledRule]
    ) -> [DomainToken] {
        var keys: [DomainToken] = []
        if snapshot.allocatedByteCount != nil {
            keys.append(DomainToken(rawValue: "metadata.allocated")!)
        }
        if snapshot.fileIdentity?.ownerUserID == getuid() {
            keys.append(
                DomainToken(rawValue: "evidence.scope.user-owned")!
            )
        }
        if rules.count == 1,
           let rule = rules.first,
           rule.id.rawValue == "cache-uv",
           rule.match.pathPattern.rawValue == ".cache/uv",
           rule.match.expectedKind == .directory,
           snapshot.relativePath == ".cache/uv",
           snapshot.kind == .directory,
           rule.disposition == .reviewRecommended,
           rule.recommendedAction == .moveToTrash
        {
            let approvedStaticKeys: Set<String> = [
                "evidence.cache.layout",
                "evidence.cache.reclaimable",
                "evidence.cache.tool-owned",
            ]
            keys.append(contentsOf: rule.requiredEvidenceKeys.filter {
                approvedStaticKeys.contains($0.rawValue)
            })
        }
        return keys
    }

    private static let uvReadOnlyProcessSubjects: ExecutionProcessSubjects = {
        try! ExecutionProcessSubjects(
            bundleIdentifiers: [],
            exactNames: [
                DomainLabel(rawValue: "uv")!,
            ],
            versionedFamilies: []
        )
    }()

    private func evidenceRecord(
        snapshotID: SnapshotID,
        observation: ActivityObservation
    ) -> EvidenceRecord {
        EvidenceRecord(
            id: evidenceID(snapshotID, observation),
            targetID: snapshotID,
            kind: observation.source == .git ? .git : .activity,
            source: EvidenceSource(
                kind: .activityProvider,
                identifier: DomainToken(
                    rawValue:
                        "quick-scan.activity.\(observation.source.rawValue)"
                )!
            ),
            summaryKey: observation.reason,
            observedAt: observation.observedAt,
            freshness: .current
        )
    }

    private func providerFailureObservations(
        for rule: CompiledRule,
        observedAt: Date
    ) throws -> [ActivityObservation] {
        try rule.requiredActivityKeys.map {
            unavailableObservation(
                key: try ActivityKey(validating: $0.rawValue),
                source: $0.rawValue == ActivityKey.processInactive.rawValue
                    ? .runningProcess
                    : .git,
                observedAt: observedAt,
                reason: "quick-scan.activity.provider-failure"
            )
        }
    }

    private func recoveredActivityIssues(
        from evidence: [EvidenceRecord]
    ) -> [QuickScanProductIssue] {
        let targets = Set(evidence.compactMap { record in
            record.source.kind == .activityProvider
                && record.summaryKey.rawValue
                    == "quick-scan.activity.provider-failure"
                ? record.targetID
                : nil
        })
        return targets.map {
            productIssue(
                .activityUnavailable,
                snapshotID: $0,
                reason: "quick-scan.activity.provider-failure"
            )
        }
    }

    private func normalizedProductIssues(
        _ issues: [QuickScanProductIssue]
    ) -> [QuickScanProductIssue] {
        var seen: Set<String> = []
        return issues.sorted {
            let lhs = productIssueSortKey($0)
            let rhs = productIssueSortKey($1)
            return lhs < rhs
        }.filter {
            seen.insert(productIssueSortKey($0)).inserted
        }
    }

    private func finalSession(
        scanTerminal: ScanSession,
        request: ScanRequest,
        issues: [QuickScanProductIssue]
    ) throws -> ScanSession {
        let finishedAt = max(now(), scanTerminal.finishedAt)
        let rootPath = try PersistedPath(
            validating: request.rootURL.standardizedFileURL.path
        )
        let scanReason = scanTerminal.unfinishedScopes.first?.reason
        if issues.isEmpty,
           scanReason == .interrupted
        {
            return try ScanSession(
                id: request.sessionID,
                startedAt: scanTerminal.startedAt,
                finishedAt: finishedAt,
                terminalState: .completed,
                completedScopes: [
                    ScanScope(
                        id: request.scopeID,
                        rootPath: rootPath,
                        completedAt: finishedAt
                    ),
                ],
                unfinishedScopes: [],
                aggregate: scanTerminal.aggregate
            )
        }
        return try ScanSession(
            id: request.sessionID,
            startedAt: scanTerminal.startedAt,
            finishedAt: finishedAt,
            terminalState: .partial,
            completedScopes: [],
            unfinishedScopes: [
                UnfinishedScanScope(
                    id: request.scopeID,
                    rootPath: rootPath,
                    reason: scanReason == .interrupted
                        ? .metadataChanged
                        : scanReason ?? .interrupted
                ),
            ],
            aggregate: scanTerminal.aggregate
        )
    }

    private func projectionSession(
        _ session: ScanSession,
        hasCompleteFacts: Bool
    ) throws -> ScanSession {
        guard session.terminalState == .completed,
              !hasCompleteFacts,
              let scope = session.completedScopes.first
        else {
            return session
        }
        return try ScanSession(
            id: session.id,
            startedAt: session.startedAt,
            finishedAt: session.finishedAt,
            terminalState: .partial,
            completedScopes: [],
            unfinishedScopes: [
                UnfinishedScanScope(
                    id: scope.id,
                    rootPath: scope.rootPath,
                    reason: .metadataChanged
                ),
            ],
            aggregate: session.aggregate
        )
    }

    private func sessionHasCommittedProductTerminal(
        _ session: ScanSession
    ) -> Bool {
        switch session.terminalState {
        case .completed:
            true
        case .partial:
            !session.unfinishedScopes.contains {
                $0.reason == .interrupted
            }
        case .cancelled, .failed:
            false
        }
    }
}

private func ruleKind(_ kind: PathKind) -> RuleExpectedKind? {
    switch kind {
    case .regularFile:
        .regularFile
    case .directory:
        .directory
    case .symbolicLink:
        .symbolicLink
    case .other:
        .other
    case .inaccessible:
        nil
    }
}

private func emit(
    _ event: QuickScanProductEvent,
    to continuation: AsyncThrowingStream<
        QuickScanProductEvent,
        Error
    >.Continuation,
    limit: Int
) throws {
    switch continuation.yield(event) {
    case .enqueued:
        break
    case .dropped:
        throw QuickScanProductError.eventBufferExceeded(limit: limit)
    case .terminated:
        break
    @unknown default:
        throw QuickScanProductError.eventBufferExceeded(limit: limit)
    }
}

private func productIssue(
    _ kind: QuickScanProductIssueKind,
    snapshotID: SnapshotID?,
    reason: String
) -> QuickScanProductIssue {
    QuickScanProductIssue(
        kind: kind,
        affectedSnapshotID: snapshotID,
        reasonKey: DomainToken(rawValue: reason)!
    )
}

private func productIssueSortKey(_ issue: QuickScanProductIssue) -> String {
    [
        issue.kind.rawValue,
        issue.affectedSnapshotID?.rawValue ?? "",
        issue.reasonKey.rawValue,
    ].joined(separator: "|")
}

private func unavailableObservation(
    key: ActivityKey,
    source: ActivityEvidenceSource,
    observedAt: Date,
    reason: String
) -> ActivityObservation {
    try! ActivityObservation(
        key: key,
        state: .unavailable,
        source: source,
        origin: .external,
        observedAt: safeActivityObservationDate(observedAt),
        reason: DomainToken(rawValue: reason)!
    )
}

private final class QuickScanProductRunControl: @unchecked Sendable {
    private enum State {
        case running
        case cancellationRequested
        case finalizationCommitted
    }

    private let lock = NSLock()
    private var task: Task<Void, Never>?
    private var state = State.running

    func install(_ task: Task<Void, Never>) {
        lock.withLock {
            self.task = task
        }
    }

    var isCancellationRequested: Bool {
        lock.withLock { state == .cancellationRequested }
    }

    func requestCancellation() -> Bool {
        lock.withLock {
            switch state {
            case .running:
                state = .cancellationRequested
                return true
            case .cancellationRequested:
                return true
            case .finalizationCommitted:
                return false
            }
        }
    }

    func commitFinalization() -> Bool {
        lock.withLock {
            guard state == .running else {
                return false
            }
            state = .finalizationCommitted
            return true
        }
    }
}
