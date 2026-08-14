#if DEBUG
import AppKit
import Darwin
import Foundation
import StornautCore
import SwiftUI

enum DebugAppFixture:
    String,
    CaseIterable,
    Sendable
{
    case empty
    case loading
    case partial
    case cancelled
    case success
    case limitedPermission = "limited-permission"
    case stale
    case error

    @MainActor
    func makeState() throws -> AppPageState {
        let now = DebugProjectionFactory.now
        switch self {
        case .empty:
            return .empty
        case .loading:
            return try AppPageState(
                phase: .loading,
                projection: DebugProjectionFactory.success(slug: rawValue),
                reasonKey: nil,
                recoveryIntent: nil,
                refreshedAt: now
            )
        case .partial:
            return try AppPageState(
                phase: .partial,
                projection: DebugProjectionFactory.partial(slug: rawValue),
                reasonKey: DomainToken(rawValue: "app.state.partial"),
                recoveryIntent: .retryLatestSnapshot,
                refreshedAt: now
            )
        case .cancelled:
            return try AppPageState(
                phase: .cancelled,
                projection: DebugProjectionFactory.cancelled(slug: rawValue),
                reasonKey: DomainToken(rawValue: "app.state.cancelled"),
                recoveryIntent: .retryLatestSnapshot,
                refreshedAt: now
            )
        case .success:
            return try .success(
                projection: DebugProjectionFactory.success(slug: rawValue),
                refreshedAt: now
            )
        case .limitedPermission:
            return try AppPageState(
                phase: .limitedPermission,
                projection: DebugProjectionFactory.limitedPermission(
                    slug: rawValue
                ),
                reasonKey: DomainToken(
                    rawValue: "app.state.permission-limited"
                ),
                recoveryIntent: .reviewPermissions,
                refreshedAt: now
            )
        case .stale:
            return try AppPageState(
                phase: .stale,
                projection: DebugProjectionFactory.success(slug: rawValue),
                reasonKey: DomainToken(rawValue: "app.state.snapshot-stale"),
                recoveryIntent: .refreshLatestSnapshot,
                refreshedAt: now
            )
        case .error:
            return try AppPageState(
                phase: .error,
                projection: DebugProjectionFactory.success(slug: rawValue),
                reasonKey: DomainToken(
                    rawValue: "app.state.store-unavailable"
                ),
                recoveryIntent: .retryLatestSnapshot,
                refreshedAt: now
            )
        }
    }
}

struct DebugAppFixtureSelection: Sendable, Equatable {
    let fixture: DebugAppFixture

    init?(arguments: [String]) {
        let prefix = "--stornaut-debug-fixture="
        let matches = arguments.filter { $0.hasPrefix(prefix) }
        guard matches.count == 1,
              matches[0].count > prefix.count,
              let fixture = DebugAppFixture(
                  rawValue: String(matches[0].dropFirst(prefix.count))
              )
        else {
            return nil
        }
        self.fixture = fixture
    }
}

enum DebugHistoryFixture: String, CaseIterable, Sendable {
    case empty
    case populated
    case expired
    case corrupt
    case trend
}

enum DebugSettingsFixture: String, CaseIterable, Sendable {
    case populated
    case empty
    case corrupt
    case codexMissing = "codex-missing"
    case syntaxUnsupported = "syntax-unsupported"
    case runtimeStale = "runtime-stale"
    case runtimeFailed = "runtime-failed"
    case runtimeUnverified = "runtime-unverified"
}

enum DebugReviewFixture: String, CaseIterable, Sendable {
    case `default`
    case inspector
    case stale
    case limited
    case empty
    case overlapConflict = "overlap-conflict"
    case preflightFailure = "preflight-failure"
    case executing
}

enum DebugCleanupFixture: String, CaseIterable, Sendable {
    case completed
    case partial
    case failed
    case stopped
    case auditPending = "audit-pending"
    case outcomeUnknown = "outcome-unknown"
    case observationUnavailable = "observation-unavailable"
    case evidenceExpired = "evidence-expired"
    case trashUnavailable = "trash-unavailable"
    case corrupt
}

struct DebugReviewFixtureSelection: Sendable, Equatable {
    let fixture: DebugReviewFixture

    init?(arguments: [String]) {
        let prefix = "--stornaut-debug-review="
        let matches = arguments.filter { $0.hasPrefix(prefix) }
        guard matches.count == 1,
              let fixture = DebugReviewFixture(
                  rawValue: String(matches[0].dropFirst(prefix.count))
              )
        else {
            return nil
        }
        self.fixture = fixture
    }
}

struct DebugCleanupFixtureSelection: Sendable, Equatable {
    let fixture: DebugCleanupFixture

    init?(arguments: [String]) {
        let prefix = "--stornaut-debug-cleanup="
        let matches = arguments.filter { $0.hasPrefix(prefix) }
        guard matches.count == 1,
              let fixture = DebugCleanupFixture(
                  rawValue: String(matches[0].dropFirst(prefix.count))
              )
        else {
            return nil
        }
        self.fixture = fixture
    }
}

struct DebugCleanupAutoRun: Sendable, Equatable {
    static func enabled(arguments: [String]) -> Bool {
        let matches = arguments.filter {
            $0 == "--stornaut-debug-auto-cleanup-terminal"
        }
        let malformed = arguments.contains {
            $0.hasPrefix("--stornaut-debug-auto-cleanup-terminal")
                && $0 != "--stornaut-debug-auto-cleanup-terminal"
        }
        return matches.count == 1 && !malformed
    }
}

struct DebugSettingsFixtureSelection: Sendable, Equatable {
    let fixture: DebugSettingsFixture

    init?(arguments: [String]) {
        let prefix = "--stornaut-debug-settings="
        let matches = arguments.filter { $0.hasPrefix(prefix) }
        guard matches.count == 1,
              let fixture = DebugSettingsFixture(
                  rawValue: String(matches[0].dropFirst(prefix.count))
              )
        else {
            return nil
        }
        self.fixture = fixture
    }
}

enum DebugSettingsInitialSection {
    static func selection(arguments: [String]) -> SettingsSection {
        let prefix = "--stornaut-debug-settings-section="
        let matches = arguments.filter { $0.hasPrefix(prefix) }
        guard matches.count == 1,
              let section = SettingsSection(
                  rawValue: String(matches[0].dropFirst(prefix.count))
              )
        else {
            return .general
        }
        return section
    }
}

enum DebugSettingsLanguage {
    static func selection(arguments: [String]) -> SettingsLanguage {
        guard let index = arguments.firstIndex(of: "-AppleLanguages"),
              arguments.indices.contains(index + 1)
        else {
            return .english
        }
        return arguments[index + 1].contains("zh-Hans")
            ? .simplifiedChinese
            : .english
    }
}

struct DebugHistoryFixtureSelection: Sendable, Equatable {
    let fixture: DebugHistoryFixture

    init?(arguments: [String]) {
        let prefix = "--stornaut-debug-history="
        let matches = arguments.filter { $0.hasPrefix(prefix) }
        guard matches.count == 1,
              matches[0].count > prefix.count,
              let fixture = DebugHistoryFixture(
                  rawValue: String(matches[0].dropFirst(prefix.count))
              )
        else {
            return nil
        }
        self.fixture = fixture
    }
}

enum DebugInitialDestination {
    static func selection(
        arguments: [String]
    ) -> AppDestination {
        let prefix = "--stornaut-debug-destination="
        let matches = arguments.filter { $0.hasPrefix(prefix) }
        guard matches.count == 1,
              let destination = AppDestination(
                  rawValue: String(matches[0].dropFirst(prefix.count))
              )
        else {
            return .overview
        }
        return destination
    }
}

enum DebugHistoryInitialPresentation: String {
    case detail
    case trend

    static func selection(
        arguments: [String]
    ) -> DebugHistoryInitialPresentation {
        let prefix = "--stornaut-debug-history-presentation="
        let matches = arguments.filter { $0.hasPrefix(prefix) }
        guard matches.count == 1,
              let presentation = DebugHistoryInitialPresentation(
                  rawValue: String(matches[0].dropFirst(prefix.count))
              )
        else {
            return .detail
        }
        return presentation
    }
}

extension AppComposition {
    static func debugFixture(
        arguments: [String]
    ) throws -> AppComposition? {
        guard let selection = DebugAppFixtureSelection(
            arguments: arguments
        ) else {
            return nil
        }
        return try debugFixture(
            selection: selection,
            historySelection: DebugHistoryFixtureSelection(
                arguments: arguments
            ),
            reviewSelection: DebugReviewFixtureSelection(
                arguments: arguments
            ),
            cleanupSelection: DebugCleanupFixtureSelection(
                arguments: arguments
            ),
            autoRunsCleanupTerminal:
                DebugCleanupAutoRun.enabled(arguments: arguments),
            settingsSelection: DebugSettingsFixtureSelection(
                arguments: arguments
            ),
            settingsLanguage: DebugSettingsLanguage.selection(
                arguments: arguments
            )
        )
    }

    static func debugFixture(
        selection: DebugAppFixtureSelection,
        historySelection: DebugHistoryFixtureSelection? = nil,
        reviewSelection: DebugReviewFixtureSelection? = nil,
        cleanupSelection: DebugCleanupFixtureSelection? = nil,
        autoRunsCleanupTerminal: Bool = false,
        settingsSelection: DebugSettingsFixtureSelection? = nil,
        settingsLanguage: SettingsLanguage = .english,
        makeState: @MainActor (DebugAppFixture) throws -> AppPageState = {
            try $0.makeState()
        }
    ) throws -> AppComposition {
        let baseState = try makeState(selection.fixture)
        let reviewSource: QuickScanProjection?
        if let cleanupSelection {
            reviewSource = try DebugProjectionFactory.review(
                slug: "cleanup-\(cleanupSelection.fixture.rawValue)"
            )
        } else if let reviewSelection {
            reviewSource = try DebugProjectionFactory.review(
                slug: "review-\(reviewSelection.fixture.rawValue)"
            )
        } else {
            reviewSource = nil
        }
        let state = try reviewSource.map {
            try AppPageState.success(
                projection: $0,
                refreshedAt: DebugProjectionFactory.now
            )
        } ?? baseState
        let scanState = try selection.fixture.makeScanState(
            pageState: state
        )
        let initialHistory = try historySelection?.fixture.makeState()
            ?? .idle
        let historyStore = DebugHistoryStore(
            page: initialHistory.page ?? .empty
        )
        let initialSettings = try (
            settingsSelection?.fixture ?? .populated
        ).makeSnapshot(language: settingsLanguage)
        let settingsStore = DebugSettingsStore(snapshot: initialSettings)
        let reviewFixture = try reviewSelection.map { selection in
            guard let projection = state.projection else {
                throw DebugReviewFixtureError.unavailable
            }
            return try selection.fixture.makeFixture(
                source: projection
            )
        }
        let cleanupReviewFixture = try cleanupSelection.map { _ in
            guard let projection = state.projection else {
                throw DebugReviewFixtureError.unavailable
            }
            return try DebugReviewFixture.default.makeFixture(
                source: projection
            )
        }
        let cleanupFixture = try cleanupSelection.map {
            guard let cleanupReviewFixture else {
                throw DebugReviewFixtureError.unavailable
            }
            return try $0.fixture.makeFixture(
                review: cleanupReviewFixture
            )
        }
        let composition = AppComposition(
            model: StornautAppModel(
                dependencies: AppDependencies(
                    loadLatestQuickScan: { nil },
                    loadScanHistory: {
                        await historyStore.load()
                    },
                    deleteScanHistory: {
                        await historyStore.delete($0)
                    },
                    loadSettings: {
                        await settingsStore.load()
                    },
                    saveSettingsPreferences: {
                        await settingsStore.save($0)
                    },
                    clearSettingsEvidence: {
                        await settingsStore.clearEvidence()
                    },
                    clearSettingsManifests: {
                        await settingsStore.clearManifests()
                    },
                    forgetSettingsKnowledge: {
                        await settingsStore.forget($0)
                    },
                    forgetAllSettingsKnowledge: {
                        await settingsStore.forgetAll()
                    },
                    buildReview: {
                        (reviewFixture ?? cleanupReviewFixture)?.buildOutcome
                            ?? .unavailable([
                                DomainToken(
                                    rawValue:
                                        "review.unavailable.fixture-not-selected"
                                )!,
                            ])
                    },
                    preflightReview: { plan, selection in
                        guard let activeReviewFixture =
                            reviewFixture ?? cleanupReviewFixture
                        else {
                            throw DebugReviewFixtureError.unavailable
                        }
                        if activeReviewFixture.fixture
                            == .preflightFailure
                        {
                            throw DebugReviewFixtureError.preflight
                        }
                        return try activeReviewFixture.evaluation(
                            plan: plan,
                            selection: selection
                        )
                    },
                    reviewExecutionAvailability:
                        (
                            reviewFixture ?? cleanupReviewFixture
                        )?.executionAvailability
                            ?? .writeDisabled,
                    startReviewExecution: { plan, selection, confirmation in
                        let activeReviewFixture =
                            reviewFixture ?? cleanupReviewFixture
                        guard let activeReviewFixture,
                              activeReviewFixture.executionAvailability
                                == .debugFake,
                              plan == activeReviewFixture.plan,
                              confirmation.planID == plan.id
                        else {
                            throw DebugReviewFixtureError.executionDisabled
                        }
                        return AsyncStream { continuation in
                            continuation.yield(
                                .progress(
                                    .queued(
                                        total: selection.items.count
                                    )
                                )
                            )
                            if let first = selection.items.first {
                                continuation.yield(
                                    .progress(
                                        .current(
                                            index: 1,
                                            total: selection.items.count,
                                            itemID: first.itemID
                                        )
                                    )
                                )
                            }
                            if let cleanupFixture,
                               let executionState =
                                cleanupFixture.result.map({
                                    debugCleanupExecutionState(
                                        fixture: cleanupFixture.fixture,
                                        result: $0
                                    )
                                })
                            {
                                continuation.yield(
                                    .terminal(executionState)
                                )
                            }
                            continuation.finish()
                        }
                    },
                    cleanupResultEnrichment: { _ in
                        CleanupResultEnrichment(
                            itemFacts: cleanupFixture?.itemFacts ?? [],
                            evidenceAvailability:
                                cleanupFixture?.evidenceAvailability
                                    ?? .expired
                        )
                    },
                    openTrash: {
                        cleanupFixture?.openTrashSucceeds ?? false
                    },
                    retryCleanupAudit: { result in
                        guard result == cleanupFixture?.result else {
                            return nil
                        }
                        return cleanupFixture?.auditRetryState
                    }
                ),
                initialState: state,
                initialScanActivity: scanState.isActive
                    ? .active
                    : .idle,
                initialScanState: scanState,
                initialHistoryState: initialHistory,
                initialSettingsState: .loaded(initialSettings),
                initialScanWorkspaceRoute:
                    cleanupFixture?.fixture == .corrupt
                        ? .cleanupResult
                        : (
                            reviewFixture == nil
                                && cleanupFixture == nil
                                    ? .results
                                    : .review
                        ),
                initialReviewState:
                    reviewFixture?.initialState
                        ?? cleanupReviewFixture?.initialState
                        ?? .idle,
                initialCleanupResultState:
                    cleanupFixture?.fixture == .corrupt
                        ? cleanupFixture?.initialState ?? .idle
                        : .idle,
                now: { DebugProjectionFactory.now },
                refreshesServices: false
            )
        )
        if autoRunsCleanupTerminal,
           cleanupFixture?.fixture != .corrupt,
           cleanupFixture != nil
        {
            composition.model.preflightReview()
            Task { @MainActor in
                for _ in 0..<1_000 {
                    if composition.model.reviewState.phase
                        == .confirming
                    {
                        composition.model.confirmReviewExecution()
                        return
                    }
                    await Task.yield()
                }
            }
        }
        return composition
    }
}

private enum DebugReviewFixtureError: Error {
    case unavailable
    case preflight
    case executionDisabled
}

private struct DebugReviewFixtureValue: Sendable {
    let fixture: DebugReviewFixture
    let plan: CleanupPlan
    let projection: ReviewProjection
    let initialState: ReviewState
    let executionAvailability: ReviewExecutionAvailability

    var buildOutcome: CleanupPlanBuildOutcome {
        switch fixture {
        case .empty:
            .empty(projection)
        case .limited:
            .scanAgain([
                DomainToken(rawValue: "review.scan-again.incomplete-scan")!,
            ])
        case .overlapConflict:
            .unavailable([
                DomainToken(rawValue: "review.unavailable.selection-conflict")!,
            ])
        case .default, .inspector, .stale,
             .preflightFailure, .executing:
            .planReady(plan, projection)
        }
    }

    func evaluation(
        plan suppliedPlan: CleanupPlan,
        selection: ReviewSelection
    ) throws -> CleanupPolicyEvaluation {
        guard suppliedPlan == plan else {
            throw DebugReviewFixtureError.unavailable
        }
        let dispositions = Dictionary(
            uniqueKeysWithValues: projection.rows.compactMap { row in
                plan.items.first(where: {
                    $0.classificationID == row.classificationID
                }).map { ($0.id, row.currentDisposition) }
            }
        )
        let contexts = try selection.items.map { selected in
            let item = plan.items.first { $0.id == selected.itemID }!
            let disposition = dispositions[item.id] ?? .unknown
            return try CleanupPolicyItemContext(
                itemID: item.id,
                snapshotID: item.snapshotID,
                classificationID: item.classificationID,
                ruleID: item.ruleID!,
                executionProfileID: item.executionProfileID!,
                proposedAction: item.proposedAction,
                persistedDisposition: disposition,
                currentDisposition: disposition,
                expectedRelativePath: item.expectedRelativePath!,
                currentRelativePath: item.expectedRelativePath!,
                expectedIdentity: item.expectedIdentity!,
                currentIdentity: item.expectedIdentity,
                evidenceFingerprint: item.evidenceFingerprint!,
                currentEvidenceFingerprint: item.evidenceFingerprint!,
                activityFingerprint: item.activityFingerprint!,
                currentActivityFingerprint: item.activityFingerprint!,
                pathFacts: .allowed,
                evidenceFacts: .current,
                activityFacts: .inactive
            )
        }
        let context = try CleanupPolicyContext(
            capturedAt: DebugProjectionFactory.now,
            planID: plan.id,
            scanSessionID: plan.scanSessionID,
            scanScopeID: plan.scanScopeID!,
            scanIsTerminal: true,
            planFingerprint: plan.planFingerprint!,
            selectionGeneration: selection.generation,
            selectionFingerprint: selection.fingerprint,
            rootIdentity: plan.primaryRootIdentity,
            catalogVersion: plan.catalogVersion,
            executionProfileVersion: plan.executionProfileVersion,
            workflow: .available,
            items: contexts
        )
        return try CleanupPolicyGate().evaluate(
            plan: plan,
            selection: selection,
            context: context,
            evaluatedAt: DebugProjectionFactory.now
        )
    }
}

private struct DebugCleanupFixtureValue: Sendable {
    let fixture: DebugCleanupFixture
    let result: CleanupExecutionResult?
    let initialState: CleanupResultState
    let itemFacts: [CleanupResultItemFacts]
    let evidenceAvailability: CleanupResultEvidenceAvailability
    let openTrashSucceeds: Bool
    let auditRetryState: CleanupExecutionState?
}

private extension DebugCleanupFixture {
    func makeFixture(
        review: DebugReviewFixtureValue
    ) throws -> DebugCleanupFixtureValue {
        if self == .corrupt {
            return DebugCleanupFixtureValue(
                fixture: self,
                result: nil,
                initialState: .corrupt("manifest-debug-corrupt"),
                itemFacts: [],
                evidenceAvailability: .expired,
                openTrashSucceeds: false,
                auditRetryState: nil
            )
        }

        guard let snapshot = review.initialState.snapshot else {
            throw DebugReviewFixtureError.unavailable
        }
        guard let selection = snapshot.reviewSelection else {
            throw DebugReviewFixtureError.unavailable
        }
        let policyEvaluation = try review.evaluation(
            plan: review.plan,
            selection: selection
        )
        guard let policyDecisions =
            policyEvaluation.allowed?.decisions
        else {
            throw DebugReviewFixtureError.unavailable
        }
        let specifications = debugCleanupSpecifications(
            fixture: self,
            plan: review.plan,
            selection: selection
        )
        let records = try specifications.enumerated().map {
            try debugCleanupRecord(
                specification: $0.element,
                index: $0.offset,
                decision: policyDecisions[$0.offset]
            )
        }
        let observation = try self == .observationUnavailable
            ? nil
            : debugCleanupObservation()
        let manifest = try CleanupManifest(
            id: CleanupManifestID(
                rawValue: "manifest-debug-cleanup-\(rawValue)"
            )!,
            planID: review.plan.id,
            createdAt: DebugProjectionFactory.now.addingTimeInterval(20),
            expiresAt: DebugProjectionFactory.now
                .addingTimeInterval(90 * 86_400),
            records: records,
            summary: CleanupManifestSummary(records: records),
            systemObservation: observation
        )
        let stage: CleanupRunJournalStage =
            self == .auditPending ? .auditPending : .finalized
        let journal = try debugCleanupJournal(
            slug: rawValue,
            stage: stage,
            stopAfterCurrentRequested: self == .stopped,
            plan: review.plan,
            selection: selection,
            manifest: manifest,
            specifications: specifications,
            records: records,
            observation: observation,
            updatedOffset: 21
        )
        let result = try CleanupExecutionResult(
            journal: journal,
            manifest: manifest
        )
        let executionState = debugCleanupExecutionState(
            fixture: self,
            result: result
        )
        let evidenceAvailability:
            CleanupResultEvidenceAvailability =
                self == .evidenceExpired ? .expired : .retained
        let facts = debugCleanupItemFacts(
            plan: review.plan,
            selection: selection
        )
        let initial = CleanupResultReducer().receivedTerminal(
            executionState,
            itemFacts: facts,
            evidenceAvailability: evidenceAvailability,
            state: .idle
        )
        let initialState = self == .trashUnavailable
            ? initial.snapshot.map(CleanupResultState.trashUnavailable)
                ?? initial
            : initial

        let auditRetryState: CleanupExecutionState?
        if self == .auditPending {
            let finalized = try debugCleanupJournal(
                slug: rawValue,
                stage: .finalized,
                stopAfterCurrentRequested: false,
                plan: review.plan,
                selection: selection,
                manifest: manifest,
                specifications: specifications,
                records: records,
                observation: observation,
                updatedOffset: 22
            )
            auditRetryState = .completed(
                try CleanupExecutionResult(
                    journal: finalized,
                    manifest: manifest
                )
            )
        } else {
            auditRetryState = nil
        }

        return DebugCleanupFixtureValue(
            fixture: self,
            result: result,
            initialState: initialState,
            itemFacts: facts,
            evidenceAvailability: evidenceAvailability,
            openTrashSucceeds: self != .trashUnavailable,
            auditRetryState: auditRetryState
        )
    }
}

private struct DebugCleanupRecordSpecification {
    let item: CleanupPlanItem
    let result: ManifestActionResult
    let recovery: CleanupRecoveryState
    let startedAt: Date?
    let finishedAt: Date?
    let error: CleanupManifestError?
}

private func debugCleanupSpecifications(
    fixture: DebugCleanupFixture,
    plan: CleanupPlan,
    selection: ReviewSelection
) -> [DebugCleanupRecordSpecification] {
    selection.items.enumerated().compactMap { index, selected in
        guard let item = plan.items.first(where: {
            $0.id == selected.itemID
        }) else {
            return nil
        }
        let started = DebugProjectionFactory.now
            .addingTimeInterval(10 + Double(index * 2))
        let finished = started.addingTimeInterval(1)
        switch fixture {
        case .completed, .auditPending, .observationUnavailable,
             .evidenceExpired, .trashUnavailable:
            return DebugCleanupRecordSpecification(
                item: item,
                result: .succeeded,
                recovery: .movedToTrash,
                startedAt: started,
                finishedAt: finished,
                error: nil
            )
        case .partial:
            return index == 0
                ? DebugCleanupRecordSpecification(
                    item: item,
                    result: .succeeded,
                    recovery: .movedToTrash,
                    startedAt: started,
                    finishedAt: finished,
                    error: nil
                )
                : DebugCleanupRecordSpecification(
                    item: item,
                    result: .failed,
                    recovery: .originalConfirmed,
                    startedAt: started,
                    finishedAt: finished,
                    error: CleanupManifestError(
                        stage: .moveToTrash,
                        code: DomainToken(
                            rawValue: "trash.destination.unavailable"
                        )!
                    )
                )
        case .failed:
            return DebugCleanupRecordSpecification(
                item: item,
                result: .failed,
                recovery: .originalConfirmed,
                startedAt: started,
                finishedAt: finished,
                error: CleanupManifestError(
                    stage: .moveToTrash,
                    code: DomainToken(
                        rawValue: "trash.destination.unavailable"
                    )!
                )
            )
        case .stopped:
            return index == 0
                ? DebugCleanupRecordSpecification(
                    item: item,
                    result: .succeeded,
                    recovery: .movedToTrash,
                    startedAt: started,
                    finishedAt: finished,
                    error: nil
                )
                : DebugCleanupRecordSpecification(
                    item: item,
                    result: .cancelled,
                    recovery: .notStarted,
                    startedAt: nil,
                    finishedAt: nil,
                    error: nil
                )
        case .outcomeUnknown:
            return index == 0
                ? DebugCleanupRecordSpecification(
                    item: item,
                    result: .outcomeUnknown,
                    recovery: .outcomeUnknown,
                    startedAt: started,
                    finishedAt: finished,
                    error: CleanupManifestError(
                        stage: .crashRecovery,
                        code: DomainToken(
                            rawValue: "cleanup.recovery.unknown"
                        )!
                    )
                )
                : DebugCleanupRecordSpecification(
                    item: item,
                    result: .cancelled,
                    recovery: .notStarted,
                    startedAt: nil,
                    finishedAt: nil,
                    error: nil
                )
        case .corrupt:
            return nil
        }
    }
}

private func debugCleanupRecord(
    specification: DebugCleanupRecordSpecification,
    index: Int,
    decision: PolicyDecision
) throws -> CleanupManifestRecord {
    try CleanupManifestRecord(
        actionID: CleanupActionID(
            rawValue: "action-debug-cleanup-\(index)"
        )!,
        planItemID: specification.item.id,
        policyDecisionID: decision.id,
        policyDisposition: decision.disposition,
        policyReasonKeys: decision.reasonKeys,
        action: .moveToTrash,
        result: specification.result,
        recovery: specification.recovery,
        measures: try debugCleanupMeasures(specification),
        startedAt: specification.startedAt,
        finishedAt: specification.finishedAt,
        error: specification.error
    )
}

private func debugCleanupMeasures(
    _ specification: DebugCleanupRecordSpecification
) throws -> CleanupManifestMeasures {
    let item = specification.item
    let processed = specification.result == .succeeded
        || specification.result == .partiallyFailed
    let moved = specification.recovery == .movedToTrash
    return try CleanupManifestMeasures(
        candidateLogicalBytes: item.logicalBytes!,
        candidateAllocatedBytes: item.allocatedBytes!,
        processedLogicalBytes:
            processed ? item.logicalBytes! : ByteCount(0)!,
        processedAllocatedBytes:
            processed ? item.allocatedBytes! : ByteCount(0)!,
        movedToTrashLogicalBytes:
            moved ? item.logicalBytes! : ByteCount(0)!,
        movedToTrashAllocatedBytes:
            moved ? item.allocatedBytes! : ByteCount(0)!,
        permanentlyReleasedLogicalBytes: ByteCount(0)!,
        permanentlyReleasedAllocatedBytes: ByteCount(0)!
    )
}

private func debugCleanupJournal(
    slug: String,
    stage: CleanupRunJournalStage,
    stopAfterCurrentRequested: Bool,
    plan: CleanupPlan,
    selection: ReviewSelection,
    manifest: CleanupManifest,
    specifications: [DebugCleanupRecordSpecification],
    records: [CleanupManifestRecord],
    observation: ManifestSystemObservation?,
    updatedOffset: TimeInterval
) throws -> CleanupRunJournal {
    let entries = try zip(specifications, records).map {
        specification, record in
        try CleanupRunJournalEntry(
            actionID: record.actionID,
            planItemID: record.planItemID,
            policyDecisionID: record.policyDecisionID!,
            policyDisposition: record.policyDisposition,
            policyReasonKeys: record.policyReasonKeys,
            action: record.action,
            expectedIdentity: specification.item.expectedIdentity!,
            actionFingerprint: DomainToken(
                rawValue: "action.debug-cleanup.fingerprint"
            )!,
            state: record.result == .cancelled
                ? .cancelled
                : .outcomeRecorded,
            startedAt: record.startedAt,
            outcome: CleanupJournalOutcome(
                result: record.result,
                recovery: record.recovery,
                measures: record.measures,
                destinationIdentity:
                    record.recovery == .movedToTrash
                        ? specification.item.expectedIdentity
                        : nil,
                error: record.error,
                finishedAt:
                    record.finishedAt
                        ?? DebugProjectionFactory.now
                            .addingTimeInterval(19)
            )
        )
    }
    return try CleanupRunJournal(
        id: CleanupRunID(
            rawValue: "run-debug-cleanup-\(slug)"
        )!,
        planID: plan.id,
        manifestID: manifest.id,
        selectionGeneration: selection.generation,
        selectionFingerprint: selection.fingerprint,
        stage: stage,
        retentionClass: .audit,
        stopAfterCurrentRequested: stopAfterCurrentRequested,
        entries: entries,
        createdAt: DebugProjectionFactory.now,
        updatedAt: DebugProjectionFactory.now
            .addingTimeInterval(updatedOffset),
        expiresAt: DebugProjectionFactory.now
            .addingTimeInterval(90 * 86_400),
        manifestCreatedAt: manifest.createdAt,
        systemObservation: observation
    )
}

private func debugCleanupExecutionState(
    fixture: DebugCleanupFixture,
    result: CleanupExecutionResult
) -> CleanupExecutionState {
    switch fixture {
    case .completed, .observationUnavailable, .evidenceExpired,
         .trashUnavailable:
        .completed(result)
    case .partial, .failed:
        .partiallyFailed(result)
    case .stopped:
        .stopped(result)
    case .auditPending:
        .auditPending(result)
    case .outcomeUnknown:
        .recoveryRequired(result)
    case .corrupt:
        .recoveryCorrupt(1)
    }
}

private func debugCleanupItemFacts(
    plan: CleanupPlan,
    selection: ReviewSelection
) -> [CleanupResultItemFacts] {
    selection.items.compactMap { selected in
        guard let item = plan.items.first(where: {
            $0.id == selected.itemID
        }) else {
            return nil
        }
        let path = item.expectedRelativePath!.rawValue
        let name = URL(fileURLWithPath: path).lastPathComponent
        let producer = path.contains("pip") ? "pip" : "npm"
        return CleanupResultItemFacts(
            planItemID: item.id,
            itemName: name,
            exactOriginalPath:
                "/tmp/stornaut-review-fixture/\(path)",
            expectedIdentity: item.expectedIdentity!,
            evidenceFingerprint: item.evidenceFingerprint!,
            producer: DomainLabel(rawValue: producer),
            recoveryDetailKey: DomainToken(
                rawValue: "cleanup.recovery.trash"
            )!,
            evidenceLineage: [
                DomainToken(rawValue: "cleanup.evidence.rule")!,
                DomainToken(rawValue: "cleanup.evidence.activity")!,
            ]
        )
    }
}

private func debugCleanupObservation()
    throws -> ManifestSystemObservation
{
    try ManifestSystemObservation(
        source: DomainToken(rawValue: "system.volume.home")!,
        freeBytesBefore: ByteCount(20_000_000)!,
        sampledBeforeAt: DebugProjectionFactory.now
            .addingTimeInterval(1),
        freeBytesAfter: ByteCount(20_210_000)!,
        sampledAfterAt: DebugProjectionFactory.now
            .addingTimeInterval(19),
        freeSpaceDelta: SignedByteDelta(210_000),
        unexplainedDelta: SignedByteDelta(210_000)
    )
}

private extension DebugReviewFixture {
    func makeFixture(
        source: QuickScanProjection
    ) throws -> DebugReviewFixtureValue {
        guard source.session.terminalState == .completed,
              let scope = source.session.completedScopes.first,
              source.session.completedScopes.count == 1,
              let root = source.snapshots.first(where: {
                  $0.relativePath == "."
              }),
              let npm = source.snapshots.first(where: {
                  $0.relativePath == ".npm/_cacache"
              }),
              let pip = source.snapshots.first(where: {
                  $0.relativePath == "Library/Caches/pip"
              }),
              let goBuild = source.snapshots.first(where: {
                  $0.relativePath == "Library/Caches/go-build"
              }),
              let uv = source.snapshots.first(where: {
                  $0.relativePath == ".cache/uv"
              }),
              let protected = source.snapshots.first(where: {
                  $0.relativePath == ".ssh"
              }),
              let npmClassification = source.classifications.first(
                  where: { $0.snapshotID == npm.id }
              ),
              let pipClassification = source.classifications.first(
                  where: { $0.snapshotID == pip.id }
              ),
              let goBuildClassification = source.classifications.first(
                  where: { $0.snapshotID == goBuild.id }
              ),
              let uvClassification = source.classifications.first(
                  where: { $0.snapshotID == uv.id }
              ),
              let protectedClassification = source.classifications.first(
                  where: { $0.snapshotID == protected.id }
              ),
              let rootClassification = source.classifications.first(
                  where: { $0.snapshotID == root.id }
              ),
              let rootIdentity = root.fileIdentity
        else {
            throw DebugReviewFixtureError.unavailable
        }

        let readyNPM = try debugReviewPlanItem(
            slug: "npm",
            snapshot: npm,
            classification: npmClassification,
            relativePath: npm.relativePath
        )
        let readyPIP = try debugReviewPlanItem(
            slug: "pip",
            snapshot: pip,
            classification: pipClassification,
            relativePath: pip.relativePath
        )
        let review = try debugReviewPlanItem(
            slug: "go-build",
            snapshot: goBuild,
            classification: goBuildClassification,
            relativePath: goBuild.relativePath
        )
        let plan = try CleanupPlan(
            id: CleanupPlanID(
                rawValue: "plan-review-fixture-\(rawValue)"
            )!,
            scanSessionID: source.session.id,
            scanScopeID: scope.id,
            primaryRootIdentity: rootIdentity,
            catalogVersion: DomainToken(
                rawValue: "catalog-review-fixture"
            )!,
            executionProfileVersion: DomainToken(
                rawValue: "profiles-review-fixture"
            )!,
            planFingerprint: DomainToken(
                rawValue: "plan.review-fixture.fingerprint"
            )!,
            createdAt: DebugProjectionFactory.now,
            expiresAt: DebugProjectionFactory.now.addingTimeInterval(600),
            items: [readyNPM, readyPIP, review]
        )
        let rows = [
            debugReviewRow(
                snapshot: npm,
                classification: npmClassification,
                relativePath: readyNPM.expectedRelativePath!.rawValue,
                disposition: .readyToReclaim,
                eligibility: .executable,
                suggestedDefault: true
            ),
            debugReviewRow(
                snapshot: pip,
                classification: pipClassification,
                relativePath: readyPIP.expectedRelativePath!.rawValue,
                disposition: .readyToReclaim,
                eligibility: .executable,
                suggestedDefault: true
            ),
            debugReviewRow(
                snapshot: goBuild,
                classification: goBuildClassification,
                relativePath: review.expectedRelativePath!.rawValue,
                disposition: .reviewRecommended,
                eligibility: .executable,
                suggestedDefault: false
            ),
            ReviewProjectionRow(
                snapshotID: uv.id,
                classificationID: uvClassification.id,
                relativePath: uv.relativePath,
                ruleID: uvClassification.ruleID,
                persistedDisposition: .reviewRecommended,
                currentDisposition: .reviewRecommended,
                eligibility: .noExecutionProfile,
                suggestedDefault: false,
                reasonKeys: [
                    DomainToken(
                        rawValue: "review.non-executable.no-profile"
                    )!,
                ]
            ),
            debugReviewRow(
                snapshot: protected,
                classification: protectedClassification,
                relativePath: ".ssh",
                disposition: .protected,
                eligibility: .persistedDispositionBlocked,
                suggestedDefault: false
            ),
            debugReviewRow(
                snapshot: root,
                classification: rootClassification,
                relativePath: root.relativePath,
                disposition: .unknown,
                eligibility: .persistedDispositionBlocked,
                suggestedDefault: false
            ),
        ].sorted { $0.relativePath < $1.relativePath }
        let projection = try ReviewProjection(
            sessionID: source.session.id,
            planID: plan.id,
            rows: rows,
            totalRowCount: rows.count,
            counts: ReviewProjectionCounts(
                executableReady: 2,
                executableReview: 1,
                noExecutionProfile: 1,
                persistedDispositionBlocked: 2,
                currentEvidenceBlocked: 0
            )
        )
        let availability: ReviewExecutionAvailability = .debugFake
        var snapshot = try ReviewSnapshot(
            plan: plan,
            projection: projection,
            generation: 1,
            executionAvailability: availability
        )
        let initialState: ReviewState
        switch self {
        case .default:
            initialState = .ready(snapshot)
        case .inspector:
            snapshot = snapshot.focusing(
                rows.first {
                    $0.currentDisposition == .reviewRecommended
                        && $0.eligibility == .executable
                }!.classificationID
            )
            initialState = .ready(snapshot)
        case .stale:
            initialState = .stale(
                snapshot,
                CleanupStaleResult(
                    affectedItemIDs: [readyNPM.id],
                    reasonGroups: [.activity, .identity]
                )
            )
        case .limited:
            initialState = .scanAgain([
                DomainToken(rawValue: "review.scan-again.incomplete-scan")!,
            ])
        case .empty:
            initialState = .empty(
                try ReviewProjection(
                    sessionID: source.session.id,
                    planID: nil,
                    rows: [],
                    totalRowCount: 0,
                    counts: ReviewProjectionCounts(
                        executableReady: 0,
                        executableReview: 0,
                        noExecutionProfile: 0,
                        persistedDispositionBlocked: 0,
                        currentEvidenceBlocked: 0
                    )
                )
            )
        case .overlapConflict:
            initialState = .unavailable([
                DomainToken(rawValue: "review.unavailable.selection-conflict")!,
            ])
        case .preflightFailure:
            initialState = .ready(snapshot)
        case .executing:
            initialState = .executing(
                snapshot,
                .current(
                    index: 1,
                    total: snapshot.selectedCount,
                    itemID: readyNPM.id
                )
            )
        }
        return DebugReviewFixtureValue(
            fixture: self,
            plan: plan,
            projection: projection,
            initialState: initialState,
            executionAvailability: availability
        )
    }
}

private func debugReviewPlanItem(
    slug: String,
    snapshot: PathSnapshot,
    classification: Classification,
    relativePath: String
) throws -> CleanupPlanItem {
    try CleanupPlanItem(
        id: CleanupPlanItemID(
            rawValue: "plan-item-review-fixture-\(slug)"
        )!,
        snapshotID: snapshot.id,
        classificationID: classification.id,
        ruleID: classification.ruleID!,
        executionProfileID: DomainToken(
            rawValue: "profile-review-fixture-\(slug)"
        )!,
        proposedAction: .moveToTrash,
        expectedRelativePath: PersistedPath(rawValue: relativePath)!,
        expectedIdentity: snapshot.fileIdentity!,
        logicalBytes: snapshot.logicalByteCount!,
        allocatedBytes: snapshot.allocatedByteCount!,
        evidenceFingerprint: DomainToken(
            rawValue: "evidence.review-fixture-\(slug)"
        )!,
        activityFingerprint: DomainToken(
            rawValue: "activity.review-fixture-\(slug)"
        )!
    )
}

private func debugReviewRow(
    snapshot: PathSnapshot,
    classification: Classification,
    relativePath: String,
    disposition: ReclaimDisposition,
    eligibility: ReviewEligibility,
    suggestedDefault: Bool
) -> ReviewProjectionRow {
    ReviewProjectionRow(
        snapshotID: snapshot.id,
        classificationID: classification.id,
        relativePath: relativePath,
        ruleID: classification.ruleID,
        persistedDisposition: disposition,
        currentDisposition: disposition,
        eligibility: eligibility,
        suggestedDefault: suggestedDefault,
        reasonKeys: [
            DomainToken(
                rawValue: eligibility == .executable
                    ? "review.current.executable"
                    : (
                        eligibility == .noExecutionProfile
                            ? "review.non-executable.no-profile"
                            : "review.non-executable.persisted-disposition"
                    )
            )!,
        ]
    )
}

private extension DebugSettingsFixture {
    func makeSnapshot(
        language: SettingsLanguage
    ) throws -> SettingsSnapshot {
        let knowledge: [LocalKnowledgeFact]
        let corrupt: [String]
        switch self {
        case .populated:
            knowledge = try [
                DebugSettingsFactory.fact(
                    slug: "keep-derived-data",
                    scope: "/tmp/stornaut-settings-fixture/Projects/App/DerivedData",
                    payload: .keepDecision,
                    updatedOffset: -600
                ),
                DebugSettingsFactory.fact(
                    slug: "producer-cache",
                    scope: "/tmp/stornaut-settings-fixture/Library/Caches/build",
                    payload: .producerMapping(
                        ProducerMappingKnowledge(
                            producer: DomainLabel(rawValue: "Fixture Builder")!
                        )
                    ),
                    updatedOffset: -1_200
                ),
            ]
            corrupt = []
        case .empty,
             .codexMissing,
             .syntaxUnsupported,
             .runtimeStale,
             .runtimeFailed,
             .runtimeUnverified:
            knowledge = []
            corrupt = []
        case .corrupt:
            knowledge = try [
                DebugSettingsFactory.fact(
                    slug: "healthy",
                    scope: "/tmp/stornaut-settings-fixture/Cache",
                    payload: .keepDecision,
                    updatedOffset: -600
                ),
            ]
            corrupt = ["knowledge-fixture-unreadable"]
        }
        let exclusions = try [
            ScanExclusion(validating: "Library/Caches/npm"),
            ScanExclusion(validating: "Projects/Archived"),
        ]
        let codex: SettingsCodexStatus = switch self {
        case .codexMissing:
            .unavailable
        case .syntaxUnsupported:
            SettingsCodexStatus(
                availability: .installed,
                executablePath: PersistedPath(
                    rawValue: "/tmp/stornaut-settings-fixture/bin/codex"
                ),
                version: "codex-cli fixture",
                syntaxStatus: .unsupported
            )
        default:
            SettingsCodexStatus(
                availability: .installed,
                executablePath: PersistedPath(
                    rawValue: "/tmp/stornaut-settings-fixture/bin/codex"
                ),
                version: "codex-cli fixture",
                syntaxStatus: .supported
            )
        }
        let runtimeEvidence: SettingsRuntimeEvidence = switch self {
        case .runtimeStale:
            .staleR5
        case .runtimeFailed:
            .failed
        case .runtimeUnverified:
            .unverified
        default:
            .admittedR5
        }
        return SettingsSnapshot(
            preferences: try SettingsPreferences(
                language: language,
                exclusions: exclusions,
                investigationBudget: .balanced
            ),
            primaryRoot: SettingsPrimaryRootStatus(
                path: PersistedPath(
                    rawValue: "/tmp/stornaut-settings-fixture"
                )!,
                availability: .available
            ),
            diskAccess: .limited,
            codex: codex,
            runtimeEvidence: runtimeEvidence,
            counts: SettingsRecordCounts(
                evidence: 4,
                manifests: 2,
                localKnowledge: knowledge.count
            ),
            knowledge: knowledge,
            corruptKnowledgeIDs: corrupt,
            currentCatalogVersion: DomainToken(
                rawValue: "builtin-runtime-tool-residue-v2"
            )!,
            refreshedAt: DebugProjectionFactory.now
        )
    }
}

private enum DebugSettingsFactory {
    static func fact(
        slug: String,
        scope: String,
        payload: LocalKnowledgePayload,
        updatedOffset: TimeInterval
    ) throws -> LocalKnowledgeFact {
        let updatedAt = DebugProjectionFactory.now.addingTimeInterval(
            updatedOffset
        )
        return try LocalKnowledgeFact(
            id: LocalKnowledgeID(
                rawValue: "knowledge-settings-\(slug)"
            )!,
            payload: payload,
            binding: LocalKnowledgeBinding(
                scope: PersistedPath(rawValue: scope)!,
                fileIdentity: FileIdentity(
                    device: 1,
                    inode: UInt64(
                        slug.utf8.reduce(1) {
                            ($0 &* 31) &+ UInt64($1)
                        }
                    ),
                    mode: UInt16(S_IFDIR | 0o755),
                    ownerUserID: getuid(),
                    ownerGroupID: getgid(),
                    size: 0,
                    allocatedBytes: 0,
                    modificationSeconds: Int64(updatedAt.timeIntervalSince1970),
                    modificationNanoseconds: 0
                ),
                activityFingerprint: DomainToken(
                    rawValue: "activity.settings-fixture"
                )!,
                catalogVersion: DomainToken(
                    rawValue: "builtin-runtime-tool-residue-v2"
                )!
            ),
            provenance: .userConfirmed,
            observedAt: updatedAt,
            updatedAt: updatedAt
        )
    }
}

private actor DebugSettingsStore {
    private var snapshot: SettingsSnapshot

    init(snapshot: SettingsSnapshot) {
        self.snapshot = snapshot
    }

    func load() -> SettingsSnapshot {
        snapshot
    }

    func save(_ preferences: SettingsPreferences) {
        snapshot = snapshot.replacing(preferences: preferences)
    }

    func clearEvidence() {
        snapshot = snapshot.replacing(
            counts: SettingsRecordCounts(
                evidence: 0,
                manifests: snapshot.counts.manifests,
                localKnowledge: snapshot.counts.localKnowledge
            )
        )
    }

    func clearManifests() {
        snapshot = snapshot.replacing(
            counts: SettingsRecordCounts(
                evidence: snapshot.counts.evidence,
                manifests: 0,
                localKnowledge: snapshot.counts.localKnowledge
            )
        )
    }

    func forget(_ id: LocalKnowledgeID) {
        let knowledge = snapshot.knowledge.filter { $0.id != id }
        snapshot = snapshot.replacing(
            counts: SettingsRecordCounts(
                evidence: snapshot.counts.evidence,
                manifests: snapshot.counts.manifests,
                localKnowledge: knowledge.count
            ),
            knowledge: knowledge
        )
    }

    func forgetAll() {
        snapshot = snapshot.replacing(
            counts: SettingsRecordCounts(
                evidence: snapshot.counts.evidence,
                manifests: snapshot.counts.manifests,
                localKnowledge: 0
            ),
            knowledge: [],
            corruptKnowledgeIDs: []
        )
    }
}

private extension DebugHistoryFixture {
    func makeState() throws -> HistoryState {
        switch self {
        case .empty:
            return .loaded(.empty)
        case .populated:
            return .loaded(
                try DebugHistoryFactory.page(
                    slugs: ["current", "yesterday", "partial"]
                )
            )
        case .expired:
            return .loaded(
                try DebugHistoryFactory.page(
                    slugs: ["expired"],
                    expired: true
                )
            )
        case .corrupt:
            var page = try DebugHistoryFactory.page(
                slugs: ["healthy", "ledger-corrupt"]
            )
            page = HistoryPage(
                records: page.records,
                corruptSessionIDs: ["scan-fixture-unreadable"],
                corruptLedgerSessionIDs: [
                    page.records[1].session.id.rawValue,
                ]
            )
            return .loaded(page)
        case .trend:
            return .loaded(
                try DebugHistoryFactory.page(
                    slugs: ["trend-0", "trend-1", "trend-2", "trend-3"]
                )
            )
        }
    }
}

private enum DebugHistoryFactory {
    static func page(
        slugs: [String],
        expired: Bool = false
    ) throws -> HistoryPage {
        let records = try slugs.enumerated().map { index, slug in
            let terminal: ScanTerminalState = slug == "partial"
                ? .partial
                : .completed
            let projection = terminal == .partial
                ? try DebugProjectionFactory.partial(
                    slug: "history-\(slug)"
                )
                : try DebugProjectionFactory.success(
                    slug: "history-\(slug)"
                )
            let offset: TimeInterval
            if expired {
                offset = -8 * 86_400
            } else if slug == "yesterday" {
                offset = -26 * 3_600
            } else {
                offset = -TimeInterval(index) * 86_400
            }
            let finishedAt = DebugProjectionFactory.now
                .addingTimeInterval(offset)
            let session = try ScanSession(
                id: projection.session.id,
                startedAt: finishedAt.addingTimeInterval(-10),
                finishedAt: finishedAt,
                terminalState: terminal,
                completedScopes: terminal == .completed
                    ? projection.session.completedScopes.map {
                        ScanScope(
                            id: $0.id,
                            rootPath: $0.rootPath,
                            completedAt: finishedAt
                        )
                    }
                    : [],
                unfinishedScopes: terminal == .completed
                    ? []
                    : projection.session.unfinishedScopes
            )
            let ledger = try projection.ledger.map {
                try relabel($0, sessionID: session.id)
            }
            return HistoryRecord(session: session, ledger: ledger)
        }
        return HistoryPage(records: records)
    }

    private static func relabel(
        _ ledger: SpaceLedger,
        sessionID: ScanSessionID
    ) throws -> SpaceLedger {
        var object = try JSONSerialization.jsonObject(
            with: DomainJSON.encode(ledger)
        ) as! [String: Any]
        object["sessionID"] = sessionID.rawValue
        return try DomainJSON.decode(
            SpaceLedger.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
    }
}

private actor DebugHistoryStore {
    private var page: HistoryPage

    init(page: HistoryPage) {
        self.page = page
    }

    func load() -> HistoryPage {
        page
    }

    func delete(_ sessionID: ScanSessionID) {
        page = HistoryPage(
            records: page.records.filter {
                $0.session.id != sessionID
            },
            corruptSessionIDs: page.corruptSessionIDs,
            corruptLedgerSessionIDs:
                page.corruptLedgerSessionIDs.filter {
                    $0 != sessionID.rawValue
                }
        )
    }
}

private extension DebugAppFixture {
    func makeScanState(
        pageState: AppPageState
    ) throws -> ScanFlowState {
        guard self == .loading else {
            return pageState.projection.map(ScanFlowState.retained) ?? .idle
        }
        let projection = try DebugProjectionFactory.success(slug: rawValue)
        let reducer = ScanFlowReducer()
        var state = reducer.started(
            previous: .retained(projection),
            at: DebugProjectionFactory.now.addingTimeInterval(-8)
        )
        state = reducer.reduce(
            .stageChanged(.indexVolumes),
            state: state
        )
        state = reducer.reduce(
            .stageChanged(.mapProjects),
            state: state
        )
        state = reducer.reduce(
            .stageChanged(.classifyArtifacts),
            state: state
        )
        state = reducer.reduce(
            .progress(
                QuickScanProgress(
                    scopeID: projection.snapshots[0].scopeID,
                    currentRelativePath: PersistedPath(
                        rawValue: "Projects/App/DerivedData"
                    )!,
                    counters: ScanProgress(
                        completedEntries: 128,
                        regularFileCount: 83,
                        directoryCount: 41,
                        symlinkCount: 4,
                        errorCount: 0,
                        logicalFileBytes: 350_000,
                        allocatedFileBytes: 300_000
                    )
                )
            ),
            state: state
        )
        for classification in projection.classifications.prefix(3) {
            guard let snapshot = projection.snapshots.first(
                where: { $0.id == classification.snapshotID }
            ) else {
                continue
            }
            state = reducer.reduce(
                .classifiedSnapshotObserved(snapshot, classification),
                state: state
            )
        }
        for evidence in projection.evidence {
            state = reducer.reduce(
                .evidenceObserved(evidence),
                state: state
            )
        }
        return reducer.elapsed(
            state: state,
            at: DebugProjectionFactory.now
        )
    }
}

struct DebugAppStateProbe: NSViewRepresentable {
    let phase: AppPagePhase

    func makeNSView(context: Context) -> DebugAppStateProbeView {
        DebugAppStateProbeView(phase: phase)
    }

    func updateNSView(
        _ nsView: DebugAppStateProbeView,
        context: Context
    ) {
        nsView.phase = phase
    }
}

final class DebugAppStateProbeView: NSView {
    var phase: AppPagePhase {
        didSet { setAccessibilityLabel(phase.rawValue) }
    }

    init(phase: AppPagePhase) {
        self.phase = phase
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityIdentifier("app.state.phase")
        setAccessibilityRole(.staticText)
        setAccessibilityLabel(phase.rawValue)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct DebugScanStateProbe: NSViewRepresentable {
    let phase: ScanFlowPhase

    func makeNSView(context: Context) -> DebugScanStateProbeView {
        DebugScanStateProbeView(phase: phase)
    }

    func updateNSView(
        _ nsView: DebugScanStateProbeView,
        context: Context
    ) {
        nsView.phase = phase
    }
}

final class DebugScanStateProbeView: NSView {
    var phase: ScanFlowPhase {
        didSet { setAccessibilityLabel(phase.rawValue) }
    }

    init(phase: ScanFlowPhase) {
        self.phase = phase
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityIdentifier("scan.state.phase")
        setAccessibilityRole(.staticText)
        setAccessibilityLabel(phase.rawValue)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct DebugHistoryStateProbe: NSViewRepresentable {
    let phase: HistoryPhase

    func makeNSView(context: Context) -> DebugHistoryStateProbeView {
        DebugHistoryStateProbeView(phase: phase)
    }

    func updateNSView(
        _ nsView: DebugHistoryStateProbeView,
        context: Context
    ) {
        nsView.phase = phase
    }
}

struct DebugReviewStateProbe: NSViewRepresentable {
    let phase: ReviewPhase

    func makeNSView(context: Context) -> DebugReviewStateProbeView {
        DebugReviewStateProbeView(phase: phase)
    }

    func updateNSView(
        _ nsView: DebugReviewStateProbeView,
        context: Context
    ) {
        nsView.phase = phase
    }
}

struct DebugCleanupResultStateProbe: NSViewRepresentable {
    let phase: CleanupResultPhase

    func makeNSView(
        context: Context
    ) -> DebugCleanupResultStateProbeView {
        DebugCleanupResultStateProbeView(phase: phase)
    }

    func updateNSView(
        _ nsView: DebugCleanupResultStateProbeView,
        context: Context
    ) {
        nsView.phase = phase
    }
}

final class DebugCleanupResultStateProbeView: NSView {
    var phase: CleanupResultPhase {
        didSet { setAccessibilityLabel(phase.rawValue) }
    }

    init(phase: CleanupResultPhase) {
        self.phase = phase
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityIdentifier("cleanup.result.state.phase")
        setAccessibilityRole(.staticText)
        setAccessibilityLabel(phase.rawValue)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct DebugCleanupResultOutcomeProbe: NSViewRepresentable {
    let outcome: CleanupResultOutcome?

    func makeNSView(
        context: Context
    ) -> DebugCleanupResultValueProbeView {
        DebugCleanupResultValueProbeView(
            identifier: "cleanup.result.state.outcome",
            value: outcome?.rawValue ?? "none"
        )
    }

    func updateNSView(
        _ nsView: DebugCleanupResultValueProbeView,
        context: Context
    ) {
        nsView.value = outcome?.rawValue ?? "none"
    }
}

struct DebugCleanupResultPersistenceProbe: NSViewRepresentable {
    let persistence: CleanupManifestPersistence?

    func makeNSView(
        context: Context
    ) -> DebugCleanupResultValueProbeView {
        DebugCleanupResultValueProbeView(
            identifier: "cleanup.result.state.persistence",
            value: persistence?.rawValue ?? "none"
        )
    }

    func updateNSView(
        _ nsView: DebugCleanupResultValueProbeView,
        context: Context
    ) {
        nsView.value = persistence?.rawValue ?? "none"
    }
}

struct DebugCleanupResultSummaryProbe: NSViewRepresentable {
    let model: CleanupResultModel

    func makeNSView(
        context: Context
    ) -> DebugCleanupResultValueProbeView {
        DebugCleanupResultValueProbeView(
            identifier: "cleanup.result.state.summary",
            value: summary
        )
    }

    func updateNSView(
        _ nsView: DebugCleanupResultValueProbeView,
        context: Context
    ) {
        nsView.value = summary
    }

    private var summary: String {
        [
            "succeeded=\(model.summary?.succeededCount ?? 0)",
            "failed=\(model.summary?.failedCount ?? 0)",
            "cancelled=\(model.summary?.cancelledCount ?? 0)",
            "unknown=\(model.summary?.unknownCount ?? 0)",
            "trash=\(model.movedToTrashBytes.value)",
            "permanent=\(model.permanentlyReleasedBytes.value)",
        ].joined(separator: ";")
    }
}

final class DebugCleanupResultValueProbeView: NSView {
    var value: String {
        didSet { setAccessibilityLabel(value) }
    }

    init(identifier: String, value: String) {
        self.value = value
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityIdentifier(identifier)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel(value)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class DebugReviewStateProbeView: NSView {
    var phase: ReviewPhase {
        didSet { setAccessibilityLabel(phase.rawValue) }
    }

    init(phase: ReviewPhase) {
        self.phase = phase
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityIdentifier("review.state.phase")
        setAccessibilityRole(.staticText)
        setAccessibilityLabel(phase.rawValue)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class DebugHistoryStateProbeView: NSView {
    var phase: HistoryPhase {
        didSet { setAccessibilityLabel(phase.rawValue) }
    }

    init(phase: HistoryPhase) {
        self.phase = phase
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityIdentifier("history.state.phase")
        setAccessibilityRole(.staticText)
        setAccessibilityLabel(phase.rawValue)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private enum DebugProjectionFactory {
    static let now = Date(timeIntervalSince1970: 1_786_320_000)

    static func success(slug: String) throws -> QuickScanProjection {
        try projection(slug: slug, terminalState: .completed)
    }

    static func review(slug: String) throws -> QuickScanProjection {
        let sessionID = ScanSessionID(
            rawValue: "scan-fixture-\(slug)"
        )!
        let scopeID = ScanScopeID(
            rawValue: "scope-fixture-\(slug)"
        )!
        let rootPath = PersistedPath(
            rawValue: "/tmp/stornaut-review-fixture"
        )!
        let rootIdentity = try identity(
            inode: 101,
            mode: UInt16(S_IFDIR | 0o755)
        )
        let snapshots = try [
            measuredSnapshot(
                slug: slug,
                suffix: "root",
                sessionID: sessionID,
                scopeID: scopeID,
                relativePath: ".",
                allocatedBytes: 0,
                inode: 101
            ),
            measuredSnapshot(
                slug: slug,
                suffix: "npm",
                sessionID: sessionID,
                scopeID: scopeID,
                relativePath: ".npm/_cacache",
                allocatedBytes: 180_000,
                inode: 102
            ),
            measuredSnapshot(
                slug: slug,
                suffix: "pip",
                sessionID: sessionID,
                scopeID: scopeID,
                relativePath: "Library/Caches/pip",
                allocatedBytes: 120_000,
                inode: 103
            ),
            measuredSnapshot(
                slug: slug,
                suffix: "go-build",
                sessionID: sessionID,
                scopeID: scopeID,
                relativePath: "Library/Caches/go-build",
                allocatedBytes: 50_000,
                inode: 104
            ),
            measuredSnapshot(
                slug: slug,
                suffix: "uv",
                sessionID: sessionID,
                scopeID: scopeID,
                relativePath: ".cache/uv",
                allocatedBytes: 40_000,
                inode: 105
            ),
            measuredSnapshot(
                slug: slug,
                suffix: "protected",
                sessionID: sessionID,
                scopeID: scopeID,
                relativePath: ".ssh",
                allocatedBytes: 10_000,
                inode: 106
            ),
        ]
        let classifications = try [
            classification(
                slug: slug,
                suffix: "root",
                snapshot: snapshots[0],
                producer: nil,
                category: .unknownLargeConsumers,
                disposition: .unknown,
                recoveryCost: nil,
                missingActivity: false
            ),
            classification(
                slug: slug,
                suffix: "npm",
                snapshot: snapshots[1],
                producer: "npm",
                category: .packageAndBuildCaches,
                disposition: .readyToReclaim,
                recoveryCost: .low,
                missingActivity: false
            ),
            classification(
                slug: slug,
                suffix: "pip",
                snapshot: snapshots[2],
                producer: "pip",
                category: .packageAndBuildCaches,
                disposition: .readyToReclaim,
                recoveryCost: .low,
                missingActivity: false
            ),
            classification(
                slug: slug,
                suffix: "go-build",
                snapshot: snapshots[3],
                producer: "Go command",
                category: .packageAndBuildCaches,
                disposition: .reviewRecommended,
                recoveryCost: .medium,
                missingActivity: false
            ),
            classification(
                slug: slug,
                suffix: "uv",
                snapshot: snapshots[4],
                producer: "uv",
                category: .packageAndBuildCaches,
                disposition: .reviewRecommended,
                recoveryCost: .medium,
                missingActivity: false
            ),
            classification(
                slug: slug,
                suffix: "protected",
                snapshot: snapshots[5],
                producer: "Developer credentials",
                category: .protected,
                disposition: .protected,
                recoveryCost: nil,
                missingActivity: false
            ),
        ]
        let session = try ScanSession(
            id: sessionID,
            startedAt: now.addingTimeInterval(-10),
            finishedAt: now,
            terminalState: .completed,
            completedScopes: [
                ScanScope(
                    id: scopeID,
                    rootPath: rootPath,
                    completedAt: now
                ),
            ],
            unfinishedScopes: []
        )
        return try QuickScanProjection(
            session: session,
            snapshots: snapshots,
            classifications: classifications,
            evidence: [
                activityEvidence(
                    slug: slug,
                    suffix: "npm",
                    snapshotID: snapshots[1].id
                ),
                activityEvidence(
                    slug: slug,
                    suffix: "pip",
                    snapshotID: snapshots[2].id
                ),
                activityEvidence(
                    slug: slug,
                    suffix: "go-build",
                    snapshotID: snapshots[3].id
                ),
                activityEvidence(
                    slug: slug,
                    suffix: "uv",
                    snapshotID: snapshots[4].id
                ),
            ],
            ledger: try makeLedger(
                sessionID: sessionID,
                scopeID: scopeID,
                rootPath: rootPath,
                rootIdentity: rootIdentity,
                snapshots: snapshots,
                classifications: classifications
            ),
            issues: [],
            corruptRecordIDs: []
        )
    }

    static func partial(slug: String) throws -> QuickScanProjection {
        try projection(
            slug: slug,
            terminalState: .partial,
            unfinishedReason: .metadataChanged
        )
    }

    static func cancelled(slug: String) throws -> QuickScanProjection {
        try projection(
            slug: slug,
            terminalState: .cancelled,
            unfinishedReason: .cancelled,
            includesClassification: false,
            includesLedger: false
        )
    }

    static func limitedPermission(slug: String) throws -> QuickScanProjection {
        try projection(
            slug: slug,
            terminalState: .partial,
            unfinishedReason: .permissionDenied,
            includesPermissionGap: true
        )
    }

    private static func projection(
        slug: String,
        terminalState: ScanTerminalState,
        unfinishedReason: ScanScopeCompletionReason? = nil,
        includesClassification: Bool = true,
        includesLedger: Bool = true,
        includesPermissionGap: Bool = false
    ) throws -> QuickScanProjection {
        let sessionID = ScanSessionID(
            rawValue: "scan-fixture-\(slug)"
        )!
        let scopeID = ScanScopeID(
            rawValue: "scope-fixture-\(slug)"
        )!
        let rootPath = PersistedPath(rawValue: "/tmp/stornaut-fixture")!
        let rootIdentity = try identity(
            inode: 1,
            mode: UInt16(S_IFDIR | 0o755)
        )
        let root = try measuredSnapshot(
            slug: slug,
            suffix: "root",
            sessionID: sessionID,
            scopeID: scopeID,
            relativePath: ".",
            allocatedBytes: 0,
            inode: 1
        )
        var snapshots = [root]
        if includesClassification {
            snapshots.append(
                contentsOf: try [
                    measuredSnapshot(
                        slug: slug,
                        suffix: "build-cache",
                        sessionID: sessionID,
                        scopeID: scopeID,
                        relativePath: "Library/Caches/build",
                        allocatedBytes: 180_000,
                        inode: 2
                    ),
                    measuredSnapshot(
                        slug: slug,
                        suffix: "derived-data",
                        sessionID: sessionID,
                        scopeID: scopeID,
                        relativePath: "Projects/App/DerivedData",
                        allocatedBytes: 120_000,
                        inode: 3
                    ),
                    measuredSnapshot(
                        slug: slug,
                        suffix: "updater",
                        sessionID: sessionID,
                        scopeID: scopeID,
                        relativePath: "Library/Caches/updater",
                        allocatedBytes: 50_000,
                        inode: 4
                    ),
                    measuredSnapshot(
                        slug: slug,
                        suffix: "protected",
                        sessionID: sessionID,
                        scopeID: scopeID,
                        relativePath: ".ssh",
                        allocatedBytes: 10_000,
                        inode: 5
                    ),
                ]
            )
        }
        if includesPermissionGap {
            snapshots.append(
                try PathSnapshot(
                    id: SnapshotID(
                        rawValue:
                            "snapshot-fixture-\(slug)-gap"
                    )!,
                    sessionID: sessionID,
                    scopeID: scopeID,
                    relativePath: "restricted",
                    kind: .inaccessible,
                    logicalByteCount: nil,
                    allocatedByteCount: nil,
                    modifiedAt: nil,
                    fileIdentity: nil,
                    symlinkTarget: nil,
                    measurementStatus: .permissionDenied,
                    observedAt: now
                )
            )
        }
        let classifications = includesClassification
            ? try [
                classification(
                    slug: slug,
                    suffix: "root",
                    snapshot: snapshots[0],
                    producer: nil,
                    category: .unknownLargeConsumers,
                    disposition: .unknown,
                    recoveryCost: nil,
                    missingActivity: false
                ),
                classification(
                    slug: slug,
                    suffix: "build-cache",
                    snapshot: snapshots[1],
                    producer: "Build cache",
                    category: .packageAndBuildCaches,
                    disposition: .readyToReclaim,
                    recoveryCost: .low,
                    missingActivity: false
                ),
                classification(
                    slug: slug,
                    suffix: "derived-data",
                    snapshot: snapshots[2],
                    producer: "Xcode",
                    category: .rebuildableProjectArtifacts,
                    disposition: .readyToReclaim,
                    recoveryCost: .medium,
                    missingActivity: false
                ),
                classification(
                    slug: slug,
                    suffix: "updater",
                    snapshot: snapshots[3],
                    producer: "Updater",
                    category: .updatesAndTemporaryFiles,
                    disposition: .reviewRecommended,
                    recoveryCost: .medium,
                    missingActivity: true
                ),
                classification(
                    slug: slug,
                    suffix: "protected",
                    snapshot: snapshots[4],
                    producer: "Developer credentials",
                    category: .protected,
                    disposition: .protected,
                    recoveryCost: nil,
                    missingActivity: false
                ),
            ]
            : []
        let session = try ScanSession(
            id: sessionID,
            startedAt: now.addingTimeInterval(-10),
            finishedAt: now,
            terminalState: terminalState,
            completedScopes: terminalState == .completed
                ? [
                    ScanScope(
                        id: scopeID,
                        rootPath: rootPath,
                        completedAt: now
                    ),
                ]
                : [],
            unfinishedScopes: terminalState == .completed
                ? []
                : [
                    UnfinishedScanScope(
                        id: scopeID,
                        rootPath: rootPath,
                        reason: unfinishedReason ?? .interrupted
                    ),
                ]
        )
        let ledger = includesLedger
            ? try makeLedger(
                sessionID: sessionID,
                scopeID: scopeID,
                rootPath: rootPath,
                rootIdentity: rootIdentity,
                snapshots: snapshots,
                classifications: classifications
            )
            : nil
        return try QuickScanProjection(
            session: session,
            snapshots: snapshots,
            classifications: classifications,
            evidence: includesClassification
                ? [
                    activityEvidence(
                        slug: slug,
                        suffix: "build-cache",
                        snapshotID: snapshots[1].id
                    ),
                    activityEvidence(
                        slug: slug,
                        suffix: "derived-data",
                        snapshotID: snapshots[2].id
                    ),
                ]
                : [],
            ledger: ledger,
            issues: [],
            corruptRecordIDs: []
        )
    }

    private static func measuredSnapshot(
        slug: String,
        suffix: String,
        sessionID: ScanSessionID,
        scopeID: ScanScopeID,
        relativePath: String,
        allocatedBytes: UInt64,
        inode: UInt64
    ) throws -> PathSnapshot {
        try PathSnapshot(
            id: SnapshotID(
                rawValue: "snapshot-fixture-\(slug)-\(suffix)"
            )!,
            sessionID: sessionID,
            scopeID: scopeID,
            relativePath: relativePath,
            kind: .directory,
            logicalByteCount: ByteCount(allocatedBytes),
            allocatedByteCount: ByteCount(allocatedBytes),
            modifiedAt: now,
            fileIdentity: try identity(
                inode: inode,
                mode: UInt16(S_IFDIR | 0o755),
                bytes: Int64(allocatedBytes)
            ),
            symlinkTarget: nil,
            measurementStatus: .measured,
            observedAt: now
        )
    }

    private static func classification(
        slug: String,
        suffix: String,
        snapshot: PathSnapshot,
        producer: String?,
        category: ArtifactCategory,
        disposition: ReclaimDisposition,
        recoveryCost: RebuildCost?,
        missingActivity: Bool
    ) throws -> Classification {
        let activity = DomainToken(
            rawValue: "activity.process.inactive"
        )!
        return try Classification(
            id: ClassificationID(
                rawValue: "classification-fixture-\(slug)-\(suffix)"
            )!,
            snapshotID: snapshot.id,
            ruleID: disposition == .unknown
                ? nil
                : DomainToken(
                    rawValue: "rule-fixture-\(slug)-\(suffix)"
                ),
            producer: producer.flatMap(DomainLabel.init(rawValue:)),
            category: category,
            disposition: disposition,
            risk: disposition == .protected ? .critical : .medium,
            confidence: disposition == .unknown ? .low : .high,
            recovery: recoveryCost.map {
                RecoveryGuidance(
                    methodKey: DomainToken(
                        rawValue: "recovery-fixture-\(slug)-\(suffix)"
                    )!,
                    cost: $0
                )
            },
            requiredEvidenceKeys: recoveryCost == nil ? [] : [activity],
            missingEvidenceKeys: missingActivity ? [activity] : [],
            catalogVersion: DomainToken(rawValue: "fixture-catalog-v1")!,
            classifiedAt: now
        )
    }

    private static func activityEvidence(
        slug: String,
        suffix: String,
        snapshotID: SnapshotID
    ) -> EvidenceRecord {
        EvidenceRecord(
            id: EvidenceID(
                rawValue: "evidence-fixture-\(slug)-\(suffix)"
            )!,
            targetID: snapshotID,
            kind: .activity,
            source: EvidenceSource(
                kind: .activityProvider,
                identifier: DomainToken(
                    rawValue: "fixture-activity-provider"
                )!
            ),
            summaryKey: DomainToken(
                rawValue: "activity.process.inactive"
            )!,
            observedAt: now,
            freshness: .current
        )
    }

    private static func makeLedger(
        sessionID: ScanSessionID,
        scopeID: ScanScopeID,
        rootPath: PersistedPath,
        rootIdentity: FileIdentity,
        snapshots: [PathSnapshot],
        classifications: [Classification]
    ) throws -> SpaceLedger {
        let start = try baseline(
            sessionID: sessionID,
            scopeID: scopeID,
            rootPath: rootPath,
            rootIdentity: rootIdentity,
            available: 600_000,
            sampledAt: now.addingTimeInterval(-10)
        )
        let end = try baseline(
            sessionID: sessionID,
            scopeID: scopeID,
            rootPath: rootPath,
            rootIdentity: rootIdentity,
            available: 590_000,
            sampledAt: now
        )
        return try SpaceLedgerReconciler().reconcile(
            SpaceLedgerInput(
                startBaseline: start,
                endBaseline: end,
                snapshots: snapshots,
                classifications: classifications
            )
        )
    }

    private static func baseline(
        sessionID: ScanSessionID,
        scopeID: ScanScopeID,
        rootPath: PersistedPath,
        rootIdentity: FileIdentity,
        available: UInt64,
        sampledAt: Date
    ) throws -> VolumeBaseline {
        try VolumeBaseline(
            sessionID: sessionID,
            scopeID: scopeID,
            rootPath: rootPath,
            rootIdentity: rootIdentity,
            totalCapacity: ByteCount(1_000_000),
            availableCapacity: ByteCount(available),
            availableCapacityForImportantUsage: nil,
            availableCapacityForOpportunisticUsage: nil,
            volumeIsReadOnly: false,
            source: AccountingSource(
                kind: .volumeResourceValues,
                identifier: DomainToken(rawValue: "fixture.volume")!,
                sampledAt: sampledAt
            )
        )
    }

    private static func identity(
        inode: UInt64,
        mode: UInt16,
        bytes: Int64 = 0
    ) throws -> FileIdentity {
        try FileIdentity(
            device: 1,
            inode: inode,
            mode: mode,
            ownerUserID: getuid(),
            ownerGroupID: getgid(),
            size: bytes,
            allocatedBytes: bytes,
            modificationSeconds: Int64(now.timeIntervalSince1970),
            modificationNanoseconds: 0
        )
    }
}
#endif
