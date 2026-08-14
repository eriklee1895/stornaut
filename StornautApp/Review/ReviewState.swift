import Foundation
import StornautCore

enum ScanWorkspaceRoute:
    String,
    CaseIterable,
    Sendable,
    Equatable
{
    case results
    case review
    case cleanupResult
}

struct ReviewRouteReducer: Sendable {
    func openReview(
        from route: ScanWorkspaceRoute
    ) -> ScanWorkspaceRoute {
        route == .results ? .review : route
    }

    func closeReview(
        from route: ScanWorkspaceRoute
    ) -> ScanWorkspaceRoute {
        route == .review ? .results : route
    }

    func openCleanupResult(
        from route: ScanWorkspaceRoute,
        terminalWasAccepted: Bool
    ) -> ScanWorkspaceRoute {
        route == .review && terminalWasAccepted
            ? .cleanupResult
            : route
    }

    func openCleanupResult(
        from route: ScanWorkspaceRoute
    ) -> ScanWorkspaceRoute {
        openCleanupResult(
            from: route,
            terminalWasAccepted: false
        )
    }

    func closeCleanupResult(
        from route: ScanWorkspaceRoute
    ) -> ScanWorkspaceRoute {
        route == .cleanupResult ? .results : route
    }
}

enum ReviewExecutionAvailability:
    String,
    Sendable,
    Equatable
{
    case writeDisabled
    case debugFake
}

enum ReviewExecutionBlockReason:
    String,
    Sendable,
    Equatable
{
    case writeDisabled
    case invalidSelection
    case missingTerminal
}

enum ReviewExecutionProgress: Sendable, Equatable {
    case queued(total: Int)
    case current(
        index: Int,
        total: Int,
        itemID: CleanupPlanItemID
    )
    case stopRequested(completed: Int, total: Int)
}

enum ReviewExecutionEvent: Sendable, Equatable {
    case progress(ReviewExecutionProgress)
    case terminal(CleanupExecutionState)
}

enum ReviewAppContractError: Error, Sendable, Equatable {
    case inconsistentProjection
    case nonSelectableRow
    case byteOverflow
}

struct ReviewSnapshot: Sendable, Equatable {
    let plan: CleanupPlan
    let projection: ReviewProjection
    let generation: UInt64
    let selectedItemIDs: [CleanupPlanItemID]
    let selectedOrigins:
        [CleanupPlanItemID: CleanupSelectionOrigin]
    let focusedClassificationID: ClassificationID?
    let executionAvailability: ReviewExecutionAvailability
    let selectedAllocatedBytes: ByteCount

    init(
        plan: CleanupPlan,
        projection: ReviewProjection,
        generation: UInt64,
        executionAvailability: ReviewExecutionAvailability
    ) throws {
        guard projection.planID == plan.id,
              projection.sessionID == plan.scanSessionID
        else {
            throw ReviewAppContractError.inconsistentProjection
        }
        let itemsByClassification = Dictionary(
            uniqueKeysWithValues: plan.items.map {
                ($0.classificationID, $0)
            }
        )
        let executableRows = projection.rows.filter {
            $0.eligibility == .executable
        }
        guard executableRows.count == plan.items.count,
              executableRows.allSatisfy({ row in
                  guard let item = itemsByClassification[
                      row.classificationID
                  ] else {
                      return false
                  }
                  return item.snapshotID == row.snapshotID
                      && item.ruleID == row.ruleID
                      && (
                          row.currentDisposition == .readyToReclaim
                              || row.currentDisposition
                                == .reviewRecommended
                      )
              })
        else {
            throw ReviewAppContractError.inconsistentProjection
        }
        var selected: [CleanupPlanItemID] = []
        var origins:
            [CleanupPlanItemID: CleanupSelectionOrigin] = [:]
        for row in projection.rows where row.suggestedDefault {
            guard row.eligibility == .executable,
                  row.currentDisposition == .readyToReclaim,
                  let item = itemsByClassification[
                      row.classificationID
                  ]
            else {
                throw ReviewAppContractError.inconsistentProjection
            }
            selected.append(item.id)
            origins[item.id] = .defaultReady
        }
        try self.init(
            plan: plan,
            projection: projection,
            generation: generation,
            selectedItemIDs: selected,
            selectedOrigins: origins,
            focusedClassificationID: nil,
            executionAvailability: executionAvailability
        )
    }

    private init(
        plan: CleanupPlan,
        projection: ReviewProjection,
        generation: UInt64,
        selectedItemIDs: [CleanupPlanItemID],
        selectedOrigins:
            [CleanupPlanItemID: CleanupSelectionOrigin],
        focusedClassificationID: ClassificationID?,
        executionAvailability: ReviewExecutionAvailability
    ) throws {
        let canonicalSelected = plan.items.compactMap { item in
            selectedItemIDs.contains(item.id) ? item.id : nil
        }
        self.plan = plan
        self.projection = projection
        self.generation = generation
        self.selectedItemIDs = canonicalSelected
        self.selectedOrigins = selectedOrigins
        self.focusedClassificationID = focusedClassificationID
        self.executionAvailability = executionAvailability
        selectedAllocatedBytes = try Self.allocatedBytes(
            plan: plan,
            selectedItemIDs: canonicalSelected
        )
    }

    private init(
        plan: CleanupPlan,
        projection: ReviewProjection,
        generation: UInt64,
        selectedItemIDs: [CleanupPlanItemID],
        selectedOrigins:
            [CleanupPlanItemID: CleanupSelectionOrigin],
        focusedClassificationID: ClassificationID?,
        executionAvailability: ReviewExecutionAvailability,
        selectedAllocatedBytes: ByteCount
    ) {
        self.plan = plan
        self.projection = projection
        self.generation = generation
        self.selectedItemIDs = selectedItemIDs
        self.selectedOrigins = selectedOrigins
        self.focusedClassificationID = focusedClassificationID
        self.executionAvailability = executionAvailability
        self.selectedAllocatedBytes = selectedAllocatedBytes
    }

    var selectedCount: Int {
        selectedItemIDs.count
    }

    var selectedReviewCount: Int {
        selectedItemIDs.count { itemID in
            disposition(for: itemID) == .reviewRecommended
        }
    }

    var reviewSelection: ReviewSelection? {
        guard !selectedItemIDs.isEmpty else {
            return nil
        }
        let dispositions = Dictionary(
            uniqueKeysWithValues: plan.items.compactMap { item in
                disposition(for: item.id).map {
                    (item.id, $0)
                }
            }
        )
        let items = selectedItemIDs.compactMap { itemID in
            selectedOrigins[itemID].map {
                ReviewSelectionItem(itemID: itemID, origin: $0)
            }
        }
        return try? ReviewSelection(
            plan: plan,
            generation: generation,
            items: items,
            dispositions: dispositions
        )
    }

    var canPreflight: Bool {
        reviewSelection != nil
    }

    var canExecute: Bool {
        canPreflight && executionAvailability == .debugFake
    }

    func focusing(
        _ classificationID: ClassificationID?
    ) -> ReviewSnapshot {
        ReviewSnapshot(
            plan: plan,
            projection: projection,
            generation: generation,
            selectedItemIDs: selectedItemIDs,
            selectedOrigins: selectedOrigins,
            focusedClassificationID: classificationID,
            executionAvailability: executionAvailability,
            selectedAllocatedBytes: selectedAllocatedBytes
        )
    }

    func settingSelection(
        classificationID: ClassificationID,
        isSelected: Bool
    ) throws -> ReviewSnapshot {
        guard let row = projection.rows.first(where: {
            $0.classificationID == classificationID
        }), row.eligibility == .executable,
              row.currentDisposition == .readyToReclaim
                || row.currentDisposition == .reviewRecommended,
              let item = plan.items.first(where: {
                  $0.classificationID == classificationID
              })
        else {
            throw ReviewAppContractError.nonSelectableRow
        }
        var selected = selectedItemIDs
        var origins = selectedOrigins
        if isSelected {
            if !selected.contains(item.id) {
                selected.append(item.id)
            }
            origins[item.id] = row.currentDisposition
                == .reviewRecommended ? .explicitUser : .defaultReady
        } else {
            selected.removeAll { $0 == item.id }
            origins[item.id] = nil
        }
        return try ReviewSnapshot(
            plan: plan,
            projection: projection,
            generation: generation &+ 1,
            selectedItemIDs: selected,
            selectedOrigins: origins,
            focusedClassificationID: focusedClassificationID,
            executionAvailability: executionAvailability
        )
    }

    private static func allocatedBytes(
        plan: CleanupPlan,
        selectedItemIDs: [CleanupPlanItemID]
    ) throws -> ByteCount {
        var total: UInt64 = 0
        for itemID in selectedItemIDs {
            guard let value = plan.items.first(where: {
                $0.id == itemID
            })?.allocatedBytes?.value else {
                throw ReviewAppContractError.inconsistentProjection
            }
            let sum = total.addingReportingOverflow(value)
            guard !sum.overflow else {
                throw ReviewAppContractError.byteOverflow
            }
            total = sum.partialValue
        }
        guard let bytes = ByteCount(total) else {
            throw ReviewAppContractError.byteOverflow
        }
        return bytes
    }

    private func disposition(
        for itemID: CleanupPlanItemID
    ) -> ReclaimDisposition? {
        guard let classificationID = plan.items.first(where: {
            $0.id == itemID
        })?.classificationID else {
            return nil
        }
        return projection.rows.first {
            $0.classificationID == classificationID
        }?.currentDisposition
    }
}

enum ReviewPhase: String, Sendable, Equatable {
    case idle
    case loading
    case ready
    case empty
    case scanAgain
    case unavailable
    case preflighting
    case stale
    case confirming
    case executing
    case executionBlocked
}

enum ReviewState: Sendable, Equatable {
    case idle
    case loading(ReviewSnapshot?)
    case ready(ReviewSnapshot)
    case empty(ReviewProjection)
    case scanAgain([DomainToken])
    case unavailable([DomainToken])
    case preflighting(ReviewSnapshot)
    case stale(ReviewSnapshot, CleanupStaleResult)
    case confirming(ReviewSnapshot, CleanupConfirmation)
    case executing(ReviewSnapshot, ReviewExecutionProgress)
    case executionBlocked(
        ReviewSnapshot,
        ReviewExecutionBlockReason
    )

    var phase: ReviewPhase {
        switch self {
        case .idle:
            .idle
        case .loading:
            .loading
        case .ready:
            .ready
        case .empty:
            .empty
        case .scanAgain:
            .scanAgain
        case .unavailable:
            .unavailable
        case .preflighting:
            .preflighting
        case .stale:
            .stale
        case .confirming:
            .confirming
        case .executing:
            .executing
        case .executionBlocked:
            .executionBlocked
        }
    }

    var snapshot: ReviewSnapshot? {
        switch self {
        case let .loading(snapshot):
            snapshot
        case let .ready(snapshot),
             let .preflighting(snapshot),
             let .stale(snapshot, _),
             let .confirming(snapshot, _),
             let .executing(snapshot, _),
             let .executionBlocked(snapshot, _):
            snapshot
        case .idle, .empty, .scanAgain, .unavailable:
            nil
        }
    }

    var stale: CleanupStaleResult? {
        guard case let .stale(_, stale) = self else {
            return nil
        }
        return stale
    }

    var progress: ReviewExecutionProgress? {
        guard case let .executing(_, progress) = self else {
            return nil
        }
        return progress
    }

    var stopAfterCurrentWasRequested: Bool {
        guard case let .executing(_, progress) = self,
              case .stopRequested = progress
        else {
            return false
        }
        return true
    }
}

struct ReviewReducer: Sendable {
    func beginLoading(previous: ReviewState) -> ReviewState {
        .loading(previous.snapshot)
    }

    func loaded(
        _ outcome: CleanupPlanBuildOutcome,
        previous: ReviewState,
        executionAvailability: ReviewExecutionAvailability
    ) -> ReviewState {
        switch outcome {
        case let .planReady(plan, projection):
            guard let snapshot = try? ReviewSnapshot(
                plan: plan,
                projection: projection,
                generation: (previous.snapshot?.generation ?? 0) &+ 1,
                executionAvailability: executionAvailability
            ) else {
                return .unavailable([
                    DomainToken(
                        rawValue:
                            "review.unavailable.invalid-projection"
                    )!,
                ])
            }
            return .ready(snapshot)
        case let .empty(projection):
            return .empty(projection)
        case let .scanAgain(reasons):
            return .scanAgain(reasons)
        case let .unavailable(reasons):
            return .unavailable(reasons)
        }
    }

    func beginPreflight(state: ReviewState) -> ReviewState {
        guard case let .ready(snapshot) = state,
              snapshot.canPreflight
        else {
            return state
        }
        return .preflighting(snapshot)
    }

    func preflightCompleted(
        _ evaluation: CleanupPolicyEvaluation,
        state: ReviewState
    ) -> ReviewState {
        guard case let .preflighting(snapshot) = state else {
            return state
        }
        switch evaluation {
        case let .allowed(allowed):
            guard ReviewConfirmationModel.isValid(
                snapshot: snapshot,
                confirmation: allowed.confirmation
            ) else {
                return .unavailable([
                    DomainToken(
                        rawValue:
                            "review.unavailable.invalid-confirmation"
                    )!,
                ])
            }
            return .confirming(snapshot, allowed.confirmation)
        case let .blocked(blocked):
            return .stale(snapshot, blocked.stale)
        }
    }

    func confirmExecution(state: ReviewState) -> ReviewState {
        guard case let .confirming(snapshot, _) = state else {
            return state
        }
        guard snapshot.executionAvailability == .debugFake else {
            return .executionBlocked(snapshot, .writeDisabled)
        }
        return .executing(
            snapshot,
            .queued(total: snapshot.selectedCount)
        )
    }
}
