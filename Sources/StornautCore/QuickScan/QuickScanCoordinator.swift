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
}

extension EvidenceStore: QuickScanProductPersisting {}

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
    public typealias SnapshotIDSource = @Sendable (String) -> SnapshotID
    public typealias ClassificationIDSource = @Sendable (
        SnapshotID
    ) -> ClassificationID
    public typealias EvidenceIDSource = @Sendable (
        SnapshotID,
        ActivityObservation
    ) -> EvidenceID

    private let store: any QuickScanProductPersisting
    private let catalog: RuleCatalog
    private let matcher: RuleCatalogMatcher
    private let activityProvider: any QuickScanActivityProviding
    private let volumeSampler: any VolumeBaselineSampling
    private let now: @Sendable () -> Date
    private let snapshotID: SnapshotIDSource
    private let classificationID: ClassificationIDSource
    private let evidenceID: EvidenceIDSource
    private var activeControl: QuickScanProductRunControl?
    private var activeWriter: ScanSessionWriter?
    private var scanIsActive = false

    private struct ProcessingFailure: Error {
        let issue: QuickScanProductIssue
        let underlying: any Error
    }

    init(
        store: any QuickScanProductPersisting,
        catalog: RuleCatalog,
        activityProvider: any QuickScanActivityProviding =
            NativeQuickScanActivityProvider(),
        volumeSampler: any VolumeBaselineSampling =
            FoundationVolumeBaselineSampler(),
        now: @escaping @Sendable () -> Date = Date.init,
        snapshotID: @escaping SnapshotIDSource = { _ in SnapshotID() },
        classificationID: @escaping ClassificationIDSource = {
            _ in ClassificationID()
        },
        evidenceID: @escaping EvidenceIDSource = {
            _, _ in EvidenceID()
        }
    ) {
        self.store = store
        self.catalog = catalog
        matcher = RuleCatalogMatcher(catalog: catalog)
        self.activityProvider = activityProvider
        self.volumeSampler = volumeSampler
        self.now = now
        self.snapshotID = snapshotID
        self.classificationID = classificationID
        self.evidenceID = evidenceID
    }

    public init(
        store: EvidenceStore
    ) throws {
        try self.init(
            store: store,
            catalog: BuiltInRuleCatalog.load()
        )
    }

    public var hasActiveScan: Bool {
        scanIsActive
    }

    public func start(
        _ request: ScanRequest
    ) throws -> AsyncThrowingStream<QuickScanProductEvent, Error> {
        guard !scanIsActive else {
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
        guard let session = try await loadLatestValidSession() else {
            return nil
        }
        let snapshots = try await loadAllSnapshots(sessionID: session.id)
        let classifications = try await loadAllClassifications(
            sessionID: session.id
        )
        let evidence = try await loadAllEvidence(sessionID: session.id)
        let ledger = try await store.spaceLedger(sessionID: session.id)
        var corrupt = snapshots.corruptRecordIDs
            + classifications.corruptRecordIDs
            + evidence.corruptRecordIDs
        corrupt = Array(Set(corrupt)).sorted()
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
            contentsOf: recoveredActivityIssues(from: evidence.records)
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
        let expectedClassificationTargets = try classificationTargetIDs(
            snapshots: snapshots.records
        )
        let classificationIsComplete =
            Set(classifications.records.map(\.snapshotID))
                == expectedClassificationTargets
                && classifications.records.count
                    == expectedClassificationTargets.count
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
            snapshots: snapshots.records,
            classifications: classifications.records,
            evidence: evidence.records,
            ledger: ledgerIsUsable ? ledger : nil,
            issues: issues,
            corruptRecordIDs: corrupt
        )
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
        let writer = ScanSessionWriter(
            store: store,
            volumeSampler: volumeSampler,
            now: now,
            snapshotID: snapshotID,
            snapshotObservedAt: { _ in observationTime },
            defersProductFinalization: true
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
            let snapshotPage = try await loadAllSnapshots(
                sessionID: request.sessionID
            )
            var issues: [QuickScanProductIssue] = []
            if !snapshotPage.corruptRecordIDs.isEmpty {
                issues.append(
                    productIssue(
                        .corruptRecords,
                        snapshotID: nil,
                        reason: "quick-scan.snapshot.corrupt"
                    )
                )
            }
            let candidates: [SnapshotID: [CompiledRule]]
            do {
                candidates = try candidateMap(
                    snapshots: snapshotPage.records
                )
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
            try emit(
                .stageChanged(.checkActivity),
                to: continuation,
                limit: request.lifecycleEventBufferCapacity
            )
            let classifiedAt = now()
            var classifications: [Classification] = []
            var evidenceRecords: [EvidenceRecord] = []
            let targetIDs = classificationTargetIDs(
                snapshots: snapshotPage.records,
                candidates: candidates
            )
            for snapshot in snapshotPage.records {
                try checkProductCancellation()
                let rules = candidates[snapshot.id, default: []]
                guard targetIDs.contains(snapshot.id) else {
                    continue
                }
                var observations: [ActivityObservation] = []
                if rules.count == 1,
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
                        evidenceRecords.append(
                            contentsOf: observations.map {
                                evidenceRecord(
                                    snapshotID: snapshot.id,
                                    observation: $0
                                )
                            }
                        )
                    } catch {
                        do {
                            observations = try providerFailureObservations(
                                for: rule,
                                observedAt: classifiedAt
                            )
                            evidenceRecords.append(
                                contentsOf: observations.map {
                                    evidenceRecord(
                                        snapshotID: snapshot.id,
                                        observation: $0
                                    )
                                }
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
                        issues.append(
                            productIssue(
                                .activityUnavailable,
                                snapshotID: snapshot.id,
                                reason:
                                    "quick-scan.activity.provider-failure"
                            )
                        )
                    }
                }
                let classification: Classification
                do {
                    classification = try DeterministicClassifier().classify(
                        snapshot: snapshot,
                        candidates: rules,
                        satisfiedEvidenceKeys: satisfiedEvidence(for: snapshot),
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
                classifications.append(classification)
                try emit(
                    .classifiedSnapshotObserved(
                        snapshot,
                        classification
                    ),
                    to: continuation,
                    limit: request.lifecycleEventBufferCapacity
                )
            }
            try checkProductCancellation()
            do {
                try await store.saveEvidence(evidenceRecords)
            } catch {
                throw ProcessingFailure(
                    issue: productIssue(
                        .persistenceUnavailable,
                        snapshotID: nil,
                        reason:
                            "quick-scan.evidence.persistence-unavailable"
                    ),
                    underlying: error
                )
            }
            for evidence in evidenceRecords {
                try emit(
                    .evidenceObserved(evidence),
                    to: continuation,
                    limit: request.lifecycleEventBufferCapacity
                )
            }
            try checkProductCancellation()
            do {
                try await store.saveClassifications(classifications)
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
                ledger = try SpaceLedgerReconciler().reconcile(
                    SpaceLedgerInput(
                        startBaseline: startBaseline,
                        endBaseline: endBaseline,
                        snapshots: snapshotPage.records,
                        classifications: classifications
                    )
                )
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
            for issue in issues {
                try emit(
                    .productIssueObserved(issue),
                    to: continuation,
                    limit: request.lifecycleEventBufferCapacity
                )
            }
            let terminal = try finalSession(
                scanTerminal: scanTerminal,
                request: request,
                issues: issues
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
                snapshots: snapshotPage.records,
                classifications: classifications,
                evidence: evidenceRecords,
                ledger: ledger,
                issues: issues,
                corruptRecordIDs: snapshotPage.corruptRecordIDs
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
                ]
            )
            do {
                try await store.saveScanSession(partial)
            } catch {
                continuation.finish(throwing: error)
                return
            }
            let snapshots = try await loadAllSnapshots(
                sessionID: request.sessionID
            )
            var projectionIssues = [issue]
            let classifications: StorePage<Classification>
            do {
                classifications = try await loadAllClassifications(
                    sessionID: request.sessionID
                )
            } catch {
                classifications = StorePage(
                    records: [],
                    corruptRecordIDs: []
                )
                projectionIssues.append(
                    productIssue(
                        .persistenceUnavailable,
                        snapshotID: nil,
                        reason:
                            "quick-scan.classification.reload-unavailable"
                    )
                )
            }
            let evidence: StorePage<EvidenceRecord>
            do {
                evidence = try await loadAllEvidence(
                    sessionID: request.sessionID
                )
            } catch {
                evidence = StorePage(records: [], corruptRecordIDs: [])
                projectionIssues.append(
                    productIssue(
                        .persistenceUnavailable,
                        snapshotID: nil,
                        reason: "quick-scan.evidence.reload-unavailable"
                    )
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
            let expectedTargets: Set<SnapshotID>
            do {
                expectedTargets = try classificationTargetIDs(
                    snapshots: snapshots.records
                )
            } catch {
                expectedTargets = []
                projectionIssues.append(
                    productIssue(
                        .classificationUnavailable,
                        snapshotID: nil,
                        reason:
                            "quick-scan.classification.reload-unavailable"
                    )
                )
            }
            let classificationTargets = Set(
                classifications.records.map(\.snapshotID)
            )
            let ledgerIsUsable = storedLedger != nil
                && expectedTargets == classificationTargets
                && classifications.records.count == expectedTargets.count
                && snapshots.corruptRecordIDs.isEmpty
                && classifications.corruptRecordIDs.isEmpty
                && evidence.corruptRecordIDs.isEmpty
            let projection = try QuickScanProjection(
                session: partial,
                snapshots: snapshots.records,
                classifications: classifications.records,
                evidence: evidence.records,
                ledger: ledgerIsUsable ? storedLedger : nil,
                issues: projectionIssues,
                corruptRecordIDs: Array(Set(
                    snapshots.corruptRecordIDs
                        + classifications.corruptRecordIDs
                        + evidence.corruptRecordIDs
                ))
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
                    ]
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
        let snapshots = try await loadAllSnapshots(sessionID: session.id)
        return try QuickScanProjection(
            session: session,
            snapshots: snapshots.records,
            classifications: [],
            evidence: [],
            ledger: nil,
            issues: [],
            corruptRecordIDs: snapshots.corruptRecordIDs
        )
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
            guard snapshot.relativePath != ".",
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
        for snapshot: PathSnapshot
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
        return keys
    }

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
                unfinishedScopes: []
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
            ]
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
            ]
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
