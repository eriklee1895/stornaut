import Foundation

package protocol CleanupExecutionStore: Sendable {
    func scanSession(id: ScanSessionID) async throws -> ScanSession?
    func savePolicyDecision(_ decision: PolicyDecision) async throws
    func saveCleanupRunJournal(_ journal: CleanupRunJournal) async throws
    func cleanupRunJournal(
        id: CleanupRunID
    ) async throws -> CleanupRunJournal?
    func cleanupRunJournals(
        limit: Int,
        offset: Int
    ) async throws -> StorePage<CleanupRunJournal>
    func saveCleanupManifest(_ manifest: CleanupManifest) async throws
    func cleanupManifest(
        id: CleanupManifestID
    ) async throws -> CleanupManifest?
    func cleanupPlan(id: CleanupPlanID) async throws -> CleanupPlan?
}

extension EvidenceStore: CleanupExecutionStore {}

package protocol CleanupVolumeSampling: Sendable {
    func sample(rootURL: URL, sampledAt: Date) throws -> CleanupVolumeSample
}

struct CleanupExecutionJournalBuilder: Sendable {
    typealias ActionIDSource = @Sendable (
        CleanupPlanItemID
    ) -> CleanupActionID

    private let actionID: ActionIDSource

    init(
        actionID: @escaping ActionIDSource = { _ in CleanupActionID() }
    ) {
        self.actionID = actionID
    }

    func preparedJournal(
        plan: CleanupPlan,
        selection: ReviewSelection,
        decisions: [PolicyDecision],
        runID: CleanupRunID,
        manifestID: CleanupManifestID,
        createdAt: Date
    ) throws -> CleanupRunJournal {
        guard plan.compatibility == .current,
              selection.planID == plan.id,
              createdAt <= plan.expiresAt,
              selection.items.map(\.itemID)
                == decisions.map(\.itemID),
              decisions.count == selection.items.count
        else {
            throw DomainContractError.invalidMeasurement
        }
        let planItems = Dictionary(
            uniqueKeysWithValues: plan.items.map { ($0.id, $0) }
        )
        let entries = try zip(selection.items, decisions).map {
            selected, decision in
            guard let item = planItems[selected.itemID],
                  decision.compatibility == .current,
                  decision.planID == plan.id,
                  decision.itemID == item.id,
                  decision.outcome == .allowed,
                  decision.selectionGeneration == selection.generation,
                  decision.selectionOrigin == selected.origin,
                  decision.planFingerprint == plan.planFingerprint,
                  item.proposedAction == .moveToTrash,
                  let identity = item.expectedIdentity
            else {
                throw DomainContractError.invalidMeasurement
            }
            let fingerprint = cleanupFingerprint(
                prefix: "action",
                lines: [
                    "stornaut.cleanup-action.v1",
                    plan.id.rawValue,
                    item.id.rawValue,
                    selection.fingerprint.rawValue,
                    decision.decisionFingerprint?.rawValue ?? "",
                    cleanupIdentityFingerprintLine(identity),
                    "move-to-trash",
                ]
            )
            return try CleanupRunJournalEntry(
                actionID: actionID(item.id),
                planItemID: item.id,
                policyDecisionID: decision.id,
                policyDisposition: decision.disposition,
                policyReasonKeys: decision.reasonKeys,
                action: item.proposedAction,
                expectedIdentity: identity,
                actionFingerprint: fingerprint,
                state: .prepared,
                startedAt: nil,
                outcome: nil
            )
        }
        let journal = try CleanupRunJournal(
            id: runID,
            planID: plan.id,
            manifestID: manifestID,
            selectionGeneration: selection.generation,
            selectionFingerprint: selection.fingerprint,
            stage: .prepared,
            retentionClass: .evidenceLinked,
            stopAfterCurrentRequested: false,
            entries: entries,
            createdAt: createdAt,
            updatedAt: createdAt,
            expiresAt: min(
                plan.expiresAt,
                createdAt.addingTimeInterval(7 * 86_400)
            )
        )
        return try DomainJSON.decode(
            CleanupRunJournal.self,
            from: DomainJSON.encode(journal)
        )
    }
}

package actor CleanupExecutionCoordinator {
    package typealias Clock = @Sendable () -> Date
    package typealias IdentityReader = @Sendable (URL) -> FileIdentity?
    package typealias RunIDSource = @Sendable () -> CleanupRunID
    package typealias ManifestIDSource = @Sendable () -> CleanupManifestID

    private let store: any CleanupExecutionStore
    private let authorizationController: CleanupAuthorizationController
    private let workflowCoordinator: CleanupWorkflowCoordinator
    private let itemCollector: any CleanupItemPolicyContextCollecting
    private let policyGate: CleanupPolicyGate
    private let executor: any CleanupActionExecuting
    private let volumeSampler: (any CleanupVolumeSampling)?
    private let accounting: CleanupAccounting
    private let identityReader: IdentityReader
    private let now: Clock
    private let runID: RunIDSource
    private let manifestID: ManifestIDSource
    private let journalBuilder: CleanupExecutionJournalBuilder

    private var activeJournal: CleanupRunJournal?
    private var stopAfterCurrentRequested = false

    package init(
        store: any CleanupExecutionStore,
        authorizationController: CleanupAuthorizationController,
        workflowCoordinator: CleanupWorkflowCoordinator,
        itemCollector: any CleanupItemPolicyContextCollecting,
        policyGate: CleanupPolicyGate = CleanupPolicyGate(),
        executor: any CleanupActionExecuting,
        volumeSampler: (any CleanupVolumeSampling)? = nil,
        accounting: CleanupAccounting = CleanupAccounting(),
        identityReader: @escaping IdentityReader = FileIdentity.read(at:),
        now: @escaping Clock = Date.init,
        runID: @escaping RunIDSource = CleanupRunID.init,
        manifestID: @escaping ManifestIDSource = CleanupManifestID.init,
        actionID: @escaping @Sendable (
            CleanupPlanItemID
        ) -> CleanupActionID = {
            _ in CleanupActionID()
        }
    ) {
        self.store = store
        self.authorizationController = authorizationController
        self.workflowCoordinator = workflowCoordinator
        self.itemCollector = itemCollector
        self.policyGate = policyGate
        self.executor = executor
        self.volumeSampler = volumeSampler
        self.accounting = accounting
        self.identityReader = identityReader
        self.now = now
        self.runID = runID
        self.manifestID = manifestID
        journalBuilder = CleanupExecutionJournalBuilder(actionID: actionID)
    }

    package func requestStopAfterCurrent() async throws {
        guard let journal = activeJournal else { return }
        stopAfterCurrentRequested = true
        guard journal.stage == .actionStarted,
              !journal.stopAfterCurrentRequested,
              let updated = try? transitionJournal(
                  journal,
                  stage: journal.stage,
                  entries: journal.entries,
                  updatedAt: nextTimestamp(after: journal.updatedAt),
                  stopRequested: true,
                  manifestCreatedAt: journal.manifestCreatedAt,
                  systemObservation: journal.systemObservation
              )
        else {
            return
        }
        try await saveAndVerify(updated)
        acceptPersistedStop(updated)
    }

    package func run(
        _ request: CleanupExecutionRequest
    ) async -> CleanupExecutionState {
        let lease: CleanupWorkflowLease
        do {
            lease = try await workflowCoordinator.acquire(.cleanupExecution)
        } catch {
            let snapshot = await workflowCoordinator.snapshot()
            _ = try? await authorizationController.admit(
                request.authorization,
                confirmation: request.confirmation,
                workflow: snapshot
            )
            return .rejected(.workflowConflict)
        }

        let state: CleanupExecutionState
        do {
            state = try await runAdmitted(request, lease: lease)
        } catch is CleanupAuthorizationError {
            state = .rejected(.authorization)
        } catch is CancellationError {
            if let activeJournal,
               activeJournal.stage == .actionStarted
            {
                state = .recoveryBlocked(activeJournal)
            } else {
                state = await cancelBeforeOrAfterCurrent(
                    request: request,
                    lease: lease
                )
            }
        } catch {
            if let activeJournal,
               activeJournal.retentionClass == .audit
            {
                state = .recoveryBlocked(activeJournal)
            } else {
                state = .rejected(.persistence)
            }
        }
        activeJournal = nil
        stopAfterCurrentRequested = false
        await workflowCoordinator.release(lease)
        return state
    }

    package func retrySavingAudit(
        _ result: CleanupExecutionResult
    ) async -> CleanupExecutionState {
        let lease: CleanupWorkflowLease
        do {
            lease = try await workflowCoordinator.acquire(.cleanupExecution)
        } catch {
            return .rejected(.workflowConflict)
        }
        let state = await retrySavingAuditAdmitted(result)
        await workflowCoordinator.release(lease)
        return state
    }

    private func retrySavingAuditAdmitted(
        _ result: CleanupExecutionResult
    ) async -> CleanupExecutionState {
        guard result.journal.stage == .auditPending
                || result.journal.stage == .manifestPending,
              result.journal.manifestID == result.manifest.id,
              let manifestCreatedAt = result.journal.manifestCreatedAt,
              let expectedManifest = try? accounting.manifest(
                  journal: result.journal,
                  volumeBefore: nil,
                  volumeAfter: nil,
                  createdAt: manifestCreatedAt
              ),
              expectedManifest == result.manifest
        else {
            return .rejected(.programmingError)
        }
        do {
            try await store.saveCleanupManifest(result.manifest)
            guard try await store.cleanupManifest(id: result.manifest.id)
                    == result.manifest
            else {
                return .auditPending(result)
            }
            let finalized = try transitionJournal(
                result.journal,
                stage: .finalized,
                entries: result.journal.entries,
                updatedAt: nextTimestamp(after: result.journal.updatedAt),
                stopRequested:
                    result.journal.stopAfterCurrentRequested,
                manifestCreatedAt: result.manifest.createdAt,
                systemObservation: result.manifest.systemObservation
            )
            try await saveAndVerify(finalized)
            return terminalState(
                try CleanupExecutionResult(
                    journal: finalized,
                    manifest: result.manifest
                )
            )
        } catch EvidenceStoreError.immutableRecordConflict {
            return .recoveryBlocked(result.journal)
        } catch {
            return .auditPending(result)
        }
    }

    package func recover() async -> [CleanupExecutionState] {
        let lease: CleanupWorkflowLease
        do {
            lease = try await workflowCoordinator.acquire(.cleanupExecution)
        } catch {
            return [.rejected(.workflowConflict)]
        }
        let states = await recoverAdmitted()
        await workflowCoordinator.release(lease)
        return states
    }

    private func recoverAdmitted() async -> [CleanupExecutionState] {
        do {
            var offset = 0
            var journals: [CleanupRunJournal] = []
            var corruptCount = 0
            while true {
                let page = try await store.cleanupRunJournals(
                    limit: 100,
                    offset: offset
                )
                journals.append(contentsOf: page.records)
                corruptCount += page.corruptRecordIDs.count
                let rowCount = page.records.count
                    + page.corruptRecordIDs.count
                if rowCount < 100 {
                    break
                }
                offset += rowCount
                guard offset <= 1_000 else {
                    throw EvidenceStoreError.invalidPage
                }
            }
            var states: [CleanupExecutionState] = corruptCount > 0
                ? [.recoveryCorrupt(corruptCount)]
                : []
            for journal in journals
                where journal.stage != .finalized
            {
                states.append(await recover(journal))
            }
            return states
        } catch {
            return [.rejected(.persistence)]
        }
    }

    private func runAdmitted(
        _ request: CleanupExecutionRequest,
        lease: CleanupWorkflowLease
    ) async throws -> CleanupExecutionState {
        let workflow = try await workflowCoordinator.snapshot(
            excluding: lease
        )
        let admission = try await authorizationController.admit(
            request.authorization,
            confirmation: request.confirmation,
            workflow: workflow
        )
        guard let allowed = request.evaluation.allowed,
              allowed.confirmation == request.confirmation,
              allowed.decisions.map(\.itemID)
                == request.selection.items.map(\.itemID),
              admission.planID == request.plan.id,
              admission.selectionGeneration
                == request.selection.generation,
              admission.orderedItemIDs
                == request.selection.items.map(\.itemID),
              admission.decisionFingerprint
                == request.confirmation.decisionFingerprint,
              admission.rootURL
                == request.collectedContext.rootURL,
              request.collectedContext.rootAccess.isAvailable,
              request.collectedContext.policyContext.contextFingerprint
                == request.confirmation.contextFingerprint,
              request.plan.items.allSatisfy({
                  $0.proposedAction == .moveToTrash
              })
        else {
            return .rejected(.planMismatch)
        }

        for decision in allowed.decisions {
            try await store.savePolicyDecision(decision)
        }
        var journal = try journalBuilder.preparedJournal(
            plan: request.plan,
            selection: request.selection,
            decisions: allowed.decisions,
            runID: runID(),
            manifestID: manifestID(),
            createdAt: now()
        )
        try await saveAndVerify(journal)
        activeJournal = journal
        stopAfterCurrentRequested = false

        let volumeBefore = sampleVolume(
            rootURL: admission.rootURL
        )
        let planItems = Dictionary(
            uniqueKeysWithValues: request.plan.items.map { ($0.id, $0) }
        )

        for index in journal.entries.indices {
            try Task.checkCancellation()
            if stopAfterCurrentRequested {
                journal = try await cancelRemaining(
                    journal,
                    from: index
                )
                break
            }
            let itemID = journal.entries[index].planItemID
            guard let item = planItems[itemID],
                  let relativePath = item.expectedRelativePath,
                  let expectedIdentity = item.expectedIdentity
            else {
                return .rejected(.planMismatch)
            }
            let freshWorkflow = try await workflowCoordinator.snapshot(
                excluding: lease
            )
            let collection = await itemCollector.collectItem(
                plan: request.plan,
                selection: request.selection,
                itemID: itemID,
                workflow: freshWorkflow
            )
            guard let freshContext = collection.context else {
                let deniedDecision = try collectionFailureDecision(
                    plan: request.plan,
                    selection: request.selection,
                    itemID: itemID
                )
                journal = try await recordPrewriteFailure(
                    journal,
                    index: index,
                    decision: deniedDecision,
                    code: token("cleanup.policy.collection-failed")
                )
                journal = try await cancelRemaining(
                    journal,
                    from: index + 1
                )
                let result = try await finalizeResult(
                    journal,
                    rootURL: admission.rootURL,
                    volumeBefore: volumeBefore
                )
                return .stale(
                    CleanupStaleResult(
                        affectedItemIDs: [itemID],
                        reasonGroups: [.item]
                    ),
                    result
                )
            }
            let policy = try policyGate.revalidateItem(
                itemID: itemID,
                plan: request.plan,
                selection: request.selection,
                context: freshContext,
                evaluatedAt: now()
            )
            try await store.savePolicyDecision(policy.decision)
            guard policy.decision.outcome == .allowed else {
                journal = try await recordPrewriteFailure(
                    journal,
                    index: index,
                    decision: policy.decision,
                    code: policy.decision.reasonKeys.first
                        ?? token("cleanup.policy.denied")
                )
                journal = try await cancelRemaining(
                    journal,
                    from: index + 1
                )
                guard let stale = policy.stale else {
                    return .rejected(.programmingError)
                }
                let result = try await finalizeResult(
                    journal,
                    rootURL: admission.rootURL,
                    volumeBefore: volumeBefore
                )
                return .stale(stale, result)
            }
            try Task.checkCancellation()
            if stopAfterCurrentRequested {
                journal = try await cancelRemaining(
                    journal,
                    from: index
                )
                break
            }

            let targetURL = admission.rootURL.appending(
                path: relativePath.rawValue,
                directoryHint: .isDirectory
            )
            let action = CleanupAction.moveToTrash(
                PathAction(
                    targetURL: targetURL,
                    expectedIdentity: expectedIdentity
                )
            )
            let actionContext = ActionPolicyContext(
                allowedRoots: [admission.rootURL],
                activeURLs: []
            )
            let preflight: ActionPreflightToken
            do {
                preflight = try executor.preflight(
                    action,
                    context: actionContext
                )
            } catch {
                journal = try await recordPrewriteFailure(
                    journal,
                    index: index,
                    decision: policy.decision,
                    code: token("cleanup.action.preflight-denied")
                )
                journal = try await cancelRemaining(
                    journal,
                    from: index + 1
                )
                let result = try await finalizeResult(
                    journal,
                    rootURL: admission.rootURL,
                    volumeBefore: volumeBefore
                )
                return .stale(
                    CleanupStaleResult(
                        affectedItemIDs: [itemID],
                        reasonGroups: [.path]
                    ),
                    result
                )
            }

            journal = try transitionStarted(
                journal,
                index: index,
                decision: policy.decision,
                startedAt: now()
            )
            try await saveAndVerify(journal)
            activeJournal = journal

            let executionResult = try await execute(
                preflight: preflight,
                context: actionContext,
                expectedIdentity: expectedIdentity,
                targetURL: targetURL,
                startedEntry: journal.entries[index]
            )
            if let latest = activeJournal,
               latest.id == journal.id,
               latest.updatedAt >= journal.updatedAt
            {
                journal = latest
            }
            journal = try transitionOutcome(
                journal,
                index: index,
                outcome: executionResult.outcome
            )
            try await saveAndVerify(journal)
            activeJournal = journal

            if executionResult.mustStop
                || stopAfterCurrentRequested
            {
                journal = try await cancelRemaining(
                    journal,
                    from: index + 1
                )
                break
            }
        }
        return try await finalize(
            journal,
            rootURL: admission.rootURL,
            volumeBefore: volumeBefore,
            recoveryRequired: journal.entries.contains {
                $0.outcome?.result == .outcomeUnknown
            }
        )
    }

    private func execute(
        preflight: ActionPreflightToken,
        context: ActionPolicyContext,
        expectedIdentity: FileIdentity,
        targetURL: URL,
        startedEntry: CleanupRunJournalEntry
    ) async throws -> (
        outcome: CleanupJournalOutcome,
        mustStop: Bool
    ) {
        do {
            let execution = try await executor.execute(
                preflight,
                context: context
            )
            let result = try executor.postflight(execution)
            guard result.status == .succeeded,
                  result.completedItems == 1,
                  result.failedItems == 0,
                  let receipt = result.trashReceipt,
                  receipt.originalIdentity == expectedIdentity,
                  let destinationURL = receipt.resultingTrashURL,
                  let destinationIdentity = identityReader(destinationURL),
                  destinationIdentity == expectedIdentity
            else {
                return (
                    try unknownOutcome(
                        entry: startedEntry,
                        code: token("cleanup.postflight.uncertain")
                    ),
                    true
                )
            }
            return (
                try successOutcome(
                    entry: startedEntry,
                    destinationIdentity: destinationIdentity,
                    finishedAt: result.finishedAt
                ),
                false
            )
        } catch is CancellationError {
            return (
                try unknownOutcome(
                    entry: startedEntry,
                    code: token("cleanup.execution.cancelled-uncertain")
                ),
                true
            )
        } catch is ActionPolicyError {
            return (
                try prewriteOutcome(
                    entry: startedEntry,
                    code: token("cleanup.final-revalidation-denied"),
                    finishedAt: now()
                ),
                true
            )
        } catch let error as CleanupActionExecutionFailure {
            switch error {
            case .permissionDenied, .operationFailed:
                if identityReader(targetURL) == expectedIdentity {
                    return (
                        try failedOutcome(
                            entry: startedEntry,
                            code: trashErrorCode(error),
                            finishedAt: now(),
                            processed: true
                        ),
                        false
                    )
                }
                return (
                    try unknownOutcome(
                        entry: startedEntry,
                        code: token("cleanup.trash.failure-identity-uncertain")
                    ),
                    true
                )
            case .missingItem, .identityChanged:
                return (
                    try prewriteOutcome(
                        entry: startedEntry,
                        code: trashErrorCode(error),
                        finishedAt: now()
                    ),
                    true
                )
            case .postconditionFailed:
                return (
                    try unknownOutcome(
                        entry: startedEntry,
                        code: trashErrorCode(error)
                    ),
                    true
                )
            }
        } catch {
            return (
                try unknownOutcome(
                    entry: startedEntry,
                    code: token("cleanup.execution.unknown")
                ),
                true
            )
        }
    }

    private func finalize(
        _ journal: CleanupRunJournal,
        rootURL: URL,
        volumeBefore: CleanupVolumeSample?,
        recoveryRequired: Bool
    ) async throws -> CleanupExecutionState {
        let result = try await finalizeResult(
            journal,
            rootURL: rootURL,
            volumeBefore: volumeBefore
        )
        if result.journal.stage == .auditPending {
            activeJournal = nil
            return .auditPending(result)
        }
        if result.journal.stage == .manifestPending {
            activeJournal = nil
            return .auditPending(result)
        }
        activeJournal = nil
        if recoveryRequired {
            return .recoveryRequired(result)
        }
        return terminalState(result)
    }

    private func finalizeResult(
        _ source: CleanupRunJournal,
        rootURL: URL,
        volumeBefore: CleanupVolumeSample?
    ) async throws -> CleanupExecutionResult {
        var journal = source
        if journal.entries.contains(where: { $0.state == .prepared }) {
            journal = try await cancelRemaining(journal, from: 0)
        }
        let volumeAfter = volumeBefore == nil
            ? nil
            : sampleVolume(rootURL: rootURL)
        let observation: ManifestSystemObservation?
        if let existing = journal.systemObservation {
            observation = existing
        } else {
            observation = try accounting.systemObservation(
                before: volumeBefore,
                after: volumeAfter
            )
        }
        let proposedManifestCreatedAt = journal.manifestCreatedAt
            ?? max(
                nextTimestamp(after: journal.updatedAt),
                observation?.sampledAfterAt ?? journal.updatedAt
            )
        if journal.stage != .auditPending
            && (
                journal.stage != .manifestPending
                    || journal.manifestCreatedAt == nil
                    || journal.systemObservation != observation
            )
        {
            journal = try transitionJournal(
                journal,
                stage: .manifestPending,
                entries: journal.entries,
                updatedAt: nextTimestamp(after: journal.updatedAt),
                stopRequested:
                    journal.stopAfterCurrentRequested
                        || stopAfterCurrentRequested,
                manifestCreatedAt: proposedManifestCreatedAt,
                systemObservation: observation
            )
            try await saveAndVerify(journal)
            activeJournal = journal
        }
        let manifestCreatedAt = journal.manifestCreatedAt
            ?? proposedManifestCreatedAt
        let persistedObservation = journal.systemObservation
        let manifest = try accounting.manifest(
            journal: journal,
            volumeBefore: nil,
            volumeAfter: nil,
            createdAt: manifestCreatedAt
        )
        do {
            try await store.saveCleanupManifest(manifest)
            guard try await store.cleanupManifest(id: manifest.id)
                    == manifest
            else {
                throw EvidenceStoreError.recordIdentityMismatch
            }
            let finalized = try transitionJournal(
                journal,
                stage: .finalized,
                entries: journal.entries,
                updatedAt: nextTimestamp(after: journal.updatedAt),
                stopRequested: journal.stopAfterCurrentRequested,
                manifestCreatedAt: manifestCreatedAt,
                systemObservation: persistedObservation
            )
            try await saveAndVerify(finalized)
            return try CleanupExecutionResult(
                journal: finalized,
                manifest: manifest
            )
        } catch EvidenceStoreError.immutableRecordConflict {
            activeJournal = journal
            throw EvidenceStoreError.immutableRecordConflict
        } catch {
            let pending = journal.stage == .auditPending
                ? journal
                : try transitionJournal(
                    journal,
                    stage: .auditPending,
                    entries: journal.entries,
                    updatedAt: nextTimestamp(after: journal.updatedAt),
                    stopRequested: journal.stopAfterCurrentRequested,
                    manifestCreatedAt: manifestCreatedAt,
                    systemObservation: persistedObservation
                )
            do {
                try await saveAndVerify(pending)
                activeJournal = pending
            } catch {
                activeJournal = journal
                return try CleanupExecutionResult(
                    journal: journal,
                    manifest: manifest
                )
            }
            return try CleanupExecutionResult(
                journal: pending,
                manifest: manifest
            )
        }
    }

    private func recover(
        _ source: CleanupRunJournal
    ) async -> CleanupExecutionState {
        do {
            if source.stage == .auditPending
                || source.stage == .manifestPending
            {
                let proposedCreatedAt = source.manifestCreatedAt
                    ?? max(
                        nextTimestamp(after: source.updatedAt),
                        source.systemObservation?.sampledAfterAt
                            ?? source.updatedAt
                    )
                let sourceWithMetadata: CleanupRunJournal
                if source.manifestCreatedAt == nil {
                    sourceWithMetadata = try transitionJournal(
                        source,
                        stage: source.stage,
                        entries: source.entries,
                        updatedAt: nextTimestamp(after: source.updatedAt),
                        stopRequested: source.stopAfterCurrentRequested,
                        manifestCreatedAt: proposedCreatedAt,
                        systemObservation: source.systemObservation
                    )
                    try await saveAndVerify(sourceWithMetadata)
                } else {
                    sourceWithMetadata = source
                }
                let createdAt = sourceWithMetadata.manifestCreatedAt
                    ?? proposedCreatedAt
                let manifest = try accounting.manifest(
                    journal: sourceWithMetadata,
                    volumeBefore: nil,
                    volumeAfter: nil,
                    createdAt: createdAt
                )
                let result = try CleanupExecutionResult(
                    journal: sourceWithMetadata,
                    manifest: manifest
                )
                if sourceWithMetadata.stage == .auditPending {
                    return .auditPending(result)
                }
                let pending = try transitionJournal(
                    sourceWithMetadata,
                    stage: .auditPending,
                    entries: sourceWithMetadata.entries,
                    updatedAt: nextTimestamp(
                        after: sourceWithMetadata.updatedAt
                    ),
                    stopRequested:
                        sourceWithMetadata.stopAfterCurrentRequested,
                    manifestCreatedAt: createdAt,
                    systemObservation: sourceWithMetadata.systemObservation
                )
                try await saveAndVerify(pending)
                return await retrySavingAuditAdmitted(
                    try CleanupExecutionResult(
                        journal: pending,
                        manifest: manifest
                    )
                )
            }
            var entries = source.entries
            for index in entries.indices {
                switch entries[index].state {
                case .outcomeRecorded, .cancelled:
                    continue
                case .started:
                    let reason = await recoveryObservationCode(
                        journal: source,
                        entry: entries[index]
                    )
                    entries[index] = try entry(
                        entries[index],
                        state: .outcomeRecorded,
                        startedAt: entries[index].startedAt,
                        outcome: unknownOutcome(
                            entry: entries[index],
                            code: reason
                        )
                    )
                case .prepared:
                    entries[index] = try cancelledEntry(entries[index])
                }
            }
            let recovered = try transitionJournal(
                source,
                stage: .manifestPending,
                entries: entries,
                updatedAt: nextTimestamp(after: source.updatedAt),
                stopRequested: true,
                manifestCreatedAt: nextTimestamp(after: source.updatedAt),
                systemObservation: nil
            )
            try await saveAndVerify(recovered)
            return try await finalize(
                recovered,
                rootURL: URL(filePath: "/"),
                volumeBefore: nil,
                recoveryRequired: entries.contains {
                    $0.outcome?.result == .outcomeUnknown
                }
            )
        } catch {
            return .recoveryBlocked(source)
        }
    }

    private func recordPrewriteFailure(
        _ journal: CleanupRunJournal,
        index: Int,
        decision: PolicyDecision?,
        code: DomainToken
    ) async throws -> CleanupRunJournal {
        var entries = journal.entries
        let original = entries[index]
        let effectiveDecision = decision
        entries[index] = try entry(
            original,
            decision: effectiveDecision,
            state: .outcomeRecorded,
            startedAt: nil,
            outcome: prewriteOutcome(
                entry: original,
                code: code,
                finishedAt: now()
            )
        )
        let updated = try transitionJournal(
            journal,
            stage: .actionOutcomeRecorded,
            entries: entries,
            updatedAt: nextTimestamp(after: journal.updatedAt),
            stopRequested: journal.stopAfterCurrentRequested,
            manifestCreatedAt: nil,
            systemObservation: nil
        )
        if let effectiveDecision {
            try await store.savePolicyDecision(effectiveDecision)
        }
        try await saveAndVerify(updated)
        activeJournal = updated
        return updated
    }

    private func collectionFailureDecision(
        plan: CleanupPlan,
        selection: ReviewSelection,
        itemID: CleanupPlanItemID
    ) throws -> PolicyDecision {
        guard let selected = selection.items.first(where: {
            $0.itemID == itemID
        }) else {
            throw ReviewSelectionError.unknownItem
        }
        let reason = token("policy.item.collection-unavailable")
        let evaluatedAt = now()
        let fingerprint = cleanupFingerprint(
            prefix: "policy-decision",
            lines: [
                "stornaut.cleanup-policy-decision.v1",
                plan.id.rawValue,
                itemID.rawValue,
                selection.fingerprint.rawValue,
                ReclaimDisposition.unknown.rawValue,
                selected.origin.rawValue,
                PolicyDecisionOutcome.denied.rawValue,
                String(evaluatedAt.timeIntervalSince1970.bitPattern),
                reason.rawValue,
            ]
        )
        return try PolicyDecision(
            id: PolicyDecisionID(
                rawValue: "decision-\(fingerprint.rawValue)"
            )!,
            planID: plan.id,
            itemID: itemID,
            outcome: .denied,
            disposition: .unknown,
            selectionGeneration: selection.generation,
            selectionOrigin: selected.origin,
            planFingerprint: plan.planFingerprint!,
            decisionFingerprint: fingerprint,
            reasonKeys: [reason],
            evaluatedAt: evaluatedAt
        )
    }

    private func cancelRemaining(
        _ journal: CleanupRunJournal,
        from start: Int
    ) async throws -> CleanupRunJournal {
        var entries = journal.entries
        if start < entries.count {
            for index in start..<entries.count
                where entries[index].state == .prepared
            {
                entries[index] = try cancelledEntry(entries[index])
            }
        }
        let updated = try transitionJournal(
            journal,
            stage: .manifestPending,
            entries: entries,
            updatedAt: nextTimestamp(after: journal.updatedAt),
            stopRequested: true,
            manifestCreatedAt: journal.manifestCreatedAt,
            systemObservation: journal.systemObservation
        )
        if updated != journal {
            try await saveAndVerify(updated)
            activeJournal = updated
        }
        return updated
    }

    private func transitionStarted(
        _ journal: CleanupRunJournal,
        index: Int,
        decision: PolicyDecision,
        startedAt: Date
    ) throws -> CleanupRunJournal {
        var entries = journal.entries
        entries[index] = try entry(
            entries[index],
            decision: decision,
            state: .started,
            startedAt: startedAt,
            outcome: nil
        )
        return try transitionJournal(
            journal,
            stage: .actionStarted,
            entries: entries,
            updatedAt: max(
                nextTimestamp(after: journal.updatedAt),
                startedAt
            ),
            stopRequested:
                journal.stopAfterCurrentRequested
                    || stopAfterCurrentRequested,
            manifestCreatedAt: nil,
            systemObservation: nil
        )
    }

    private func transitionOutcome(
        _ journal: CleanupRunJournal,
        index: Int,
        outcome: CleanupJournalOutcome
    ) throws -> CleanupRunJournal {
        var entries = journal.entries
        entries[index] = try entry(
            entries[index],
            state: .outcomeRecorded,
            startedAt: entries[index].startedAt,
            outcome: outcome
        )
        return try transitionJournal(
            journal,
            stage: .actionOutcomeRecorded,
            entries: entries,
            updatedAt: max(
                nextTimestamp(after: journal.updatedAt),
                outcome.finishedAt
            ),
            stopRequested:
                journal.stopAfterCurrentRequested
                    || stopAfterCurrentRequested,
            manifestCreatedAt: nil,
            systemObservation: nil
        )
    }

    private func transitionJournal(
        _ journal: CleanupRunJournal,
        stage: CleanupRunJournalStage,
        entries: [CleanupRunJournalEntry],
        updatedAt: Date,
        stopRequested: Bool,
        manifestCreatedAt: Date?,
        systemObservation: ManifestSystemObservation?
    ) throws -> CleanupRunJournal {
        let transitioned = try CleanupRunJournal(
            id: journal.id,
            planID: journal.planID,
            manifestID: journal.manifestID,
            selectionGeneration: journal.selectionGeneration,
            selectionFingerprint: journal.selectionFingerprint,
            stage: stage,
            retentionClass: stage == .prepared
                ? .evidenceLinked
                : .audit,
            stopAfterCurrentRequested: stopRequested,
            entries: entries,
            createdAt: journal.createdAt,
            updatedAt: updatedAt,
            expiresAt: stage == .prepared
                ? journal.expiresAt
                : max(
                    journal.expiresAt,
                    journal.createdAt.addingTimeInterval(90 * 86_400)
                ),
            manifestCreatedAt: manifestCreatedAt,
            systemObservation: systemObservation
        )
        return try DomainJSON.decode(
            CleanupRunJournal.self,
            from: DomainJSON.encode(transitioned)
        )
    }

    private func entry(
        _ source: CleanupRunJournalEntry,
        decision: PolicyDecision? = nil,
        state: CleanupJournalEntryState,
        startedAt: Date?,
        outcome: CleanupJournalOutcome?
    ) throws -> CleanupRunJournalEntry {
        let decision = decision
        return try CleanupRunJournalEntry(
            actionID: source.actionID,
            planItemID: source.planItemID,
            policyDecisionID: decision?.id
                ?? source.policyDecisionID,
            policyDisposition: decision?.disposition
                ?? source.policyDisposition,
            policyReasonKeys: decision?.reasonKeys
                ?? source.policyReasonKeys,
            action: source.action,
            expectedIdentity: source.expectedIdentity,
            actionFingerprint: decision?.decisionFingerprint.map {
                cleanupFingerprint(
                    prefix: "action",
                    lines: [
                        source.actionID.rawValue,
                        source.planItemID.rawValue,
                        $0.rawValue,
                        cleanupIdentityFingerprintLine(
                            source.expectedIdentity
                        ),
                    ]
                )
            } ?? source.actionFingerprint,
            state: state,
            startedAt: startedAt,
            outcome: outcome
        )
    }

    private func cancelledEntry(
        _ source: CleanupRunJournalEntry
    ) throws -> CleanupRunJournalEntry {
        try entry(
            source,
            state: .cancelled,
            startedAt: nil,
            outcome: CleanupJournalOutcome(
                result: .cancelled,
                recovery: .notStarted,
                measures: measures(
                    identity: source.expectedIdentity,
                    processed: false,
                    moved: false
                ),
                destinationIdentity: nil,
                error: nil,
                finishedAt: now()
            )
        )
    }

    private func prewriteOutcome(
        entry: CleanupRunJournalEntry,
        code: DomainToken,
        finishedAt: Date
    ) throws -> CleanupJournalOutcome {
        return try CleanupJournalOutcome(
            result: .failed,
            recovery: .notStarted,
            measures: measures(
                identity: entry.expectedIdentity,
                processed: false,
                moved: false
            ),
            destinationIdentity: nil,
            error: CleanupManifestError(
                stage: .finalRevalidation,
                code: code
            ),
            finishedAt: finishedAt
        )
    }

    private func failedOutcome(
        entry: CleanupRunJournalEntry,
        code: DomainToken,
        finishedAt: Date,
        processed: Bool
    ) throws -> CleanupJournalOutcome {
        try CleanupJournalOutcome(
            result: .failed,
            recovery: .originalConfirmed,
            measures: measures(
                identity: entry.expectedIdentity,
                processed: processed,
                moved: false
            ),
            destinationIdentity: nil,
            error: CleanupManifestError(
                stage: .moveToTrash,
                code: code
            ),
            finishedAt: finishedAt
        )
    }

    private func successOutcome(
        entry: CleanupRunJournalEntry,
        destinationIdentity: FileIdentity,
        finishedAt: Date
    ) throws -> CleanupJournalOutcome {
        try CleanupJournalOutcome(
            result: .succeeded,
            recovery: .movedToTrash,
            measures: measures(
                identity: entry.expectedIdentity,
                processed: true,
                moved: true
            ),
            destinationIdentity: destinationIdentity,
            error: nil,
            finishedAt: finishedAt
        )
    }

    private func unknownOutcome(
        entry: CleanupRunJournalEntry,
        code: DomainToken
    ) throws -> CleanupJournalOutcome {
        let finishedAt = entry.startedAt.map {
            max(now(), $0.addingTimeInterval(0.001))
        } ?? now()
        return try CleanupJournalOutcome(
            result: .outcomeUnknown,
            recovery: .outcomeUnknown,
            measures: measures(
                identity: entry.expectedIdentity,
                processed: true,
                moved: false
            ),
            destinationIdentity: nil,
            error: CleanupManifestError(
                stage: .crashRecovery,
                code: code
            ),
            finishedAt: finishedAt
        )
    }

    private func measures(
        identity: FileIdentity,
        processed: Bool,
        moved: Bool
    ) throws -> CleanupManifestMeasures {
        let logical = ByteCount(exactly: identity.size)!
        let allocated = ByteCount(exactly: identity.allocatedBytes)!
        return try CleanupManifestMeasures(
            candidateLogicalBytes: logical,
            candidateAllocatedBytes: allocated,
            processedLogicalBytes: processed ? logical : ByteCount(0)!,
            processedAllocatedBytes: processed
                ? allocated
                : ByteCount(0)!,
            movedToTrashLogicalBytes: moved ? logical : ByteCount(0)!,
            movedToTrashAllocatedBytes: moved
                ? allocated
                : ByteCount(0)!,
            permanentlyReleasedLogicalBytes: ByteCount(0)!,
            permanentlyReleasedAllocatedBytes: ByteCount(0)!
        )
    }

    private func saveAndVerify(
        _ journal: CleanupRunJournal
    ) async throws {
        try await store.saveCleanupRunJournal(journal)
        guard try await store.cleanupRunJournal(id: journal.id) == journal else {
            throw EvidenceStoreError.recordIdentityMismatch
        }
    }

    private func sampleVolume(rootURL: URL) -> CleanupVolumeSample? {
        guard let volumeSampler else { return nil }
        return try? volumeSampler.sample(
            rootURL: rootURL,
            sampledAt: now()
        )
    }

    private func terminalState(
        _ result: CleanupExecutionResult
    ) -> CleanupExecutionState {
        if result.manifest.summary.unknownCount > 0 {
            return .recoveryRequired(result)
        }
        if result.manifest.summary.failedCount > 0 {
            return .partiallyFailed(result)
        }
        if result.manifest.summary.cancelledCount > 0 {
            return .stopped(result)
        }
        return .completed(result)
    }

    private func cancelBeforeOrAfterCurrent(
        request: CleanupExecutionRequest,
        lease: CleanupWorkflowLease
    ) async -> CleanupExecutionState {
        guard let journal = activeJournal else {
            return .rejected(.authorization)
        }
        do {
            let cancelled = try await cancelRemaining(journal, from: 0)
            return try await finalize(
                cancelled,
                rootURL: request.collectedContext.rootURL,
                volumeBefore: nil,
                recoveryRequired: false
            )
        } catch {
            return .rejected(.persistence)
        }
    }

    private func nextTimestamp(after date: Date) -> Date {
        max(now(), date.addingTimeInterval(0.001))
    }

    private func acceptPersistedStop(
        _ journal: CleanupRunJournal
    ) {
        guard let current = activeJournal,
              current.id == journal.id,
              current.updatedAt < journal.updatedAt
        else {
            return
        }
        activeJournal = journal
    }

    private func recoveryObservationCode(
        journal: CleanupRunJournal,
        entry: CleanupRunJournalEntry
    ) async -> DomainToken {
        guard let plan = try? await store.cleanupPlan(id: journal.planID),
              let session = try? await store.scanSession(
                  id: plan.scanSessionID
              ),
              let scopeID = plan.scanScopeID,
              let scope = session.completedScopes.first(where: {
                  $0.id == scopeID
              }),
              let item = plan.items.first(where: {
                  $0.id == entry.planItemID
              }),
              let relativePath = item.expectedRelativePath
        else {
            return token("cleanup.recovery.started-unknown")
        }
        let targetURL = URL(filePath: scope.rootPath.rawValue).appending(
            path: relativePath.rawValue,
            directoryHint: .isDirectory
        )
        let observed = identityReader(targetURL)
        if observed == entry.expectedIdentity {
            return token("cleanup.recovery.original-observed")
        }
        if observed == nil {
            return token("cleanup.recovery.original-missing")
        }
        return token("cleanup.recovery.original-changed")
    }
}

private func token(_ rawValue: String) -> DomainToken {
    DomainToken(rawValue: rawValue)!
}

private func trashErrorCode(
    _ error: CleanupActionExecutionFailure
) -> DomainToken {
    switch error {
    case .permissionDenied:
        token("cleanup.trash.permission-denied")
    case .missingItem:
        token("cleanup.trash.missing")
    case .identityChanged:
        token("cleanup.trash.identity-changed")
    case .postconditionFailed:
        token("cleanup.trash.postcondition-failed")
    case .operationFailed:
        token("cleanup.trash.operation-failed")
    }
}
