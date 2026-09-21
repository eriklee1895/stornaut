import Foundation

public enum CleanupWorkflowConflict:
    String,
    Sendable,
    Hashable,
    CaseIterable
{
    case quickScan
    case settingsMutation
    case historyMutation
    case cleanupExecution
    case lifecycleReset
}

public struct CleanupWorkflowAvailabilitySnapshot:
    Sendable,
    Equatable
{
    public let rootLeaseAvailable: Bool
    public let activeConflicts: Set<CleanupWorkflowConflict>

    public init(
        rootLeaseAvailable: Bool,
        activeConflicts: Set<CleanupWorkflowConflict>
    ) {
        self.rootLeaseAvailable = rootLeaseAvailable
        self.activeConflicts = activeConflicts
    }

    public static let available = CleanupWorkflowAvailabilitySnapshot(
        rootLeaseAvailable: true,
        activeConflicts: []
    )

    public var isAvailable: Bool {
        rootLeaseAvailable && activeConflicts.isEmpty
    }
}

public struct CleanupPathPolicyFacts: Sendable, Equatable {
    public let isRoot: Bool
    public let isHome: Bool
    public let isMountRoot: Bool
    public let isSymbolicLink: Bool
    public let isSensitive: Bool
    public let isInsideRoot: Bool
    public let ownerMatches: Bool
    public let volumeMatches: Bool

    public init(
        isRoot: Bool,
        isHome: Bool,
        isMountRoot: Bool,
        isSymbolicLink: Bool,
        isSensitive: Bool,
        isInsideRoot: Bool,
        ownerMatches: Bool,
        volumeMatches: Bool
    ) {
        self.isRoot = isRoot
        self.isHome = isHome
        self.isMountRoot = isMountRoot
        self.isSymbolicLink = isSymbolicLink
        self.isSensitive = isSensitive
        self.isInsideRoot = isInsideRoot
        self.ownerMatches = ownerMatches
        self.volumeMatches = volumeMatches
    }

    public static let allowed = CleanupPathPolicyFacts(
        isRoot: false,
        isHome: false,
        isMountRoot: false,
        isSymbolicLink: false,
        isSensitive: false,
        isInsideRoot: true,
        ownerMatches: true,
        volumeMatches: true
    )
}

public enum CleanupEvidencePolicyFacts: Sendable, Equatable {
    case current
    case missing
    case stale
    case expired
    case contradicted
    case unavailable
}

public enum CleanupActivityPolicyFacts: Sendable, Equatable {
    case inactive
    case active
    case unavailable
    case contradicted
}

public struct CleanupPolicyItemContext: Sendable, Equatable {
    public let itemID: CleanupPlanItemID
    public let snapshotID: SnapshotID
    public let classificationID: ClassificationID
    public let ruleID: DomainToken
    public let executionProfileID: DomainToken
    public let proposedAction: ProposedCleanupAction
    public let persistedDisposition: ReclaimDisposition
    public let currentDisposition: ReclaimDisposition
    public let expectedRelativePath: PersistedPath
    public let currentRelativePath: PersistedPath
    public let expectedIdentity: FileIdentity
    public let currentIdentity: FileIdentity?
    public let evidenceFingerprint: DomainToken
    public let currentEvidenceFingerprint: DomainToken
    public let activityFingerprint: DomainToken
    public let currentActivityFingerprint: DomainToken
    public let pathFacts: CleanupPathPolicyFacts
    public let evidenceFacts: CleanupEvidencePolicyFacts
    public let activityFacts: CleanupActivityPolicyFacts

    public init(
        itemID: CleanupPlanItemID,
        snapshotID: SnapshotID,
        classificationID: ClassificationID,
        ruleID: DomainToken,
        executionProfileID: DomainToken,
        proposedAction: ProposedCleanupAction,
        persistedDisposition: ReclaimDisposition,
        currentDisposition: ReclaimDisposition,
        expectedRelativePath: PersistedPath,
        currentRelativePath: PersistedPath,
        expectedIdentity: FileIdentity,
        currentIdentity: FileIdentity?,
        evidenceFingerprint: DomainToken,
        currentEvidenceFingerprint: DomainToken,
        activityFingerprint: DomainToken,
        currentActivityFingerprint: DomainToken,
        pathFacts: CleanupPathPolicyFacts,
        evidenceFacts: CleanupEvidencePolicyFacts,
        activityFacts: CleanupActivityPolicyFacts
    ) throws {
        self.itemID = itemID
        self.snapshotID = snapshotID
        self.classificationID = classificationID
        self.ruleID = ruleID
        self.executionProfileID = executionProfileID
        self.proposedAction = proposedAction
        self.persistedDisposition = persistedDisposition
        self.currentDisposition = currentDisposition
        self.expectedRelativePath = expectedRelativePath
        self.currentRelativePath = currentRelativePath
        self.expectedIdentity = expectedIdentity
        self.currentIdentity = currentIdentity
        self.evidenceFingerprint = evidenceFingerprint
        self.currentEvidenceFingerprint = currentEvidenceFingerprint
        self.activityFingerprint = activityFingerprint
        self.currentActivityFingerprint = currentActivityFingerprint
        self.pathFacts = pathFacts
        self.evidenceFacts = evidenceFacts
        self.activityFacts = activityFacts
    }

    func with(
        currentIdentity: FileIdentity? = nil,
        pathFacts: CleanupPathPolicyFacts? = nil,
        evidenceFacts: CleanupEvidencePolicyFacts? = nil,
        activityFacts: CleanupActivityPolicyFacts? = nil
    ) -> CleanupPolicyItemContext {
        try! CleanupPolicyItemContext(
            itemID: itemID,
            snapshotID: snapshotID,
            classificationID: classificationID,
            ruleID: ruleID,
            executionProfileID: executionProfileID,
            proposedAction: proposedAction,
            persistedDisposition: persistedDisposition,
            currentDisposition: currentDisposition,
            expectedRelativePath: expectedRelativePath,
            currentRelativePath: currentRelativePath,
            expectedIdentity: expectedIdentity,
            currentIdentity: currentIdentity ?? self.currentIdentity,
            evidenceFingerprint: evidenceFingerprint,
            currentEvidenceFingerprint: currentEvidenceFingerprint,
            activityFingerprint: activityFingerprint,
            currentActivityFingerprint: currentActivityFingerprint,
            pathFacts: pathFacts ?? self.pathFacts,
            evidenceFacts: evidenceFacts ?? self.evidenceFacts,
            activityFacts: activityFacts ?? self.activityFacts
        )
    }
}

public struct CleanupPolicyContext: Sendable, Equatable {
    public static let maximumAge: TimeInterval = 30

    public let capturedAt: Date
    public let planID: CleanupPlanID
    public let scanSessionID: ScanSessionID
    public let scanScopeID: ScanScopeID
    public let scanIsTerminal: Bool
    public let planFingerprint: DomainToken
    public let selectionGeneration: UInt64
    public let selectionFingerprint: DomainToken
    public let rootIdentity: FileIdentity?
    public let catalogVersion: DomainToken?
    public let executionProfileVersion: DomainToken?
    public let workflow: CleanupWorkflowAvailabilitySnapshot
    public let items: [CleanupPolicyItemContext]
    public let contextFingerprint: DomainToken

    public init(
        capturedAt: Date,
        planID: CleanupPlanID,
        scanSessionID: ScanSessionID,
        scanScopeID: ScanScopeID,
        scanIsTerminal: Bool,
        planFingerprint: DomainToken,
        selectionGeneration: UInt64,
        selectionFingerprint: DomainToken,
        rootIdentity: FileIdentity?,
        catalogVersion: DomainToken?,
        executionProfileVersion: DomainToken?,
        workflow: CleanupWorkflowAvailabilitySnapshot,
        items: [CleanupPolicyItemContext]
    ) throws {
        guard capturedAt.timeIntervalSince1970.isFinite,
              !items.isEmpty,
              items.count <= ReviewSelection.maximumItemCount,
              Set(items.map(\.itemID)).count == items.count
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.capturedAt = capturedAt
        self.planID = planID
        self.scanSessionID = scanSessionID
        self.scanScopeID = scanScopeID
        self.scanIsTerminal = scanIsTerminal
        self.planFingerprint = planFingerprint
        self.selectionGeneration = selectionGeneration
        self.selectionFingerprint = selectionFingerprint
        self.rootIdentity = rootIdentity
        self.catalogVersion = catalogVersion
        self.executionProfileVersion = executionProfileVersion
        self.workflow = workflow
        self.items = items
        contextFingerprint = cleanupFingerprint(
            prefix: "policy-context",
            lines: [
                "stornaut.cleanup-policy-context.v1",
                String(capturedAt.timeIntervalSince1970.bitPattern),
                planID.rawValue,
                scanSessionID.rawValue,
                scanScopeID.rawValue,
                scanIsTerminal.description,
                planFingerprint.rawValue,
                String(selectionGeneration),
                selectionFingerprint.rawValue,
                cleanupIdentityFingerprintLine(rootIdentity),
                catalogVersion?.rawValue ?? "catalog.unavailable",
                executionProfileVersion?.rawValue
                    ?? "profile-catalog.unavailable",
                workflow.rootLeaseAvailable.description,
                workflow.activeConflicts.map(\.rawValue)
                    .sorted().joined(separator: ","),
            ] + items.map(cleanupPolicyItemFingerprintLine)
        )
    }
}

public enum CleanupStaleReasonGroup:
    String,
    Sendable,
    Hashable,
    CaseIterable
{
    case plan
    case selection
    case root
    case catalog
    case item
    case identity
    case evidence
    case activity
    case path
    case workflow
    case confirmation
}

public enum CleanupStaleAction: String, Sendable, Equatable {
    case refreshAffectedItems
    case cancel
}

public struct CleanupStaleResult: Sendable, Equatable {
    public let affectedItemIDs: Set<CleanupPlanItemID>
    public let reasonGroups: Set<CleanupStaleReasonGroup>
    public let availableActions: [CleanupStaleAction]

    public init(
        affectedItemIDs: Set<CleanupPlanItemID>,
        reasonGroups: Set<CleanupStaleReasonGroup>
    ) {
        self.affectedItemIDs = affectedItemIDs
        self.reasonGroups = reasonGroups
        availableActions = [.refreshAffectedItems, .cancel]
    }
}

public struct CleanupConfirmation: Sendable, Equatable {
    public let planID: CleanupPlanID
    public let selectionGeneration: UInt64
    public let orderedItemIDs: [CleanupPlanItemID]
    public let itemCount: Int
    public let reviewItemCount: Int
    public let logicalBytes: ByteCount
    public let allocatedBytes: ByteCount
    public let action: ProposedCleanupAction
    public let planFingerprint: DomainToken
    public let selectionFingerprint: DomainToken
    public let contextFingerprint: DomainToken
    public let decisionFingerprint: DomainToken
    public let admissionNotAfter: Date
    public let recoveryCaveatKey: DomainToken

    init(
        planID: CleanupPlanID,
        selectionGeneration: UInt64,
        orderedItemIDs: [CleanupPlanItemID],
        reviewItemCount: Int,
        logicalBytes: ByteCount,
        allocatedBytes: ByteCount,
        action: ProposedCleanupAction,
        planFingerprint: DomainToken,
        selectionFingerprint: DomainToken,
        contextFingerprint: DomainToken,
        decisionFingerprint: DomainToken,
        admissionNotAfter: Date
    ) {
        self.planID = planID
        self.selectionGeneration = selectionGeneration
        self.orderedItemIDs = orderedItemIDs
        itemCount = orderedItemIDs.count
        self.reviewItemCount = reviewItemCount
        self.logicalBytes = logicalBytes
        self.allocatedBytes = allocatedBytes
        self.action = action
        self.planFingerprint = planFingerprint
        self.selectionFingerprint = selectionFingerprint
        self.contextFingerprint = contextFingerprint
        self.decisionFingerprint = decisionFingerprint
        self.admissionNotAfter = admissionNotAfter
        recoveryCaveatKey = cleanupPolicyToken(
            "policy.confirmation.trash-recovery-caveat"
        )
    }

    func with(
        selectionGeneration: UInt64
    ) -> CleanupConfirmation {
        CleanupConfirmation(
            planID: planID,
            selectionGeneration: selectionGeneration,
            orderedItemIDs: orderedItemIDs,
            reviewItemCount: reviewItemCount,
            logicalBytes: logicalBytes,
            allocatedBytes: allocatedBytes,
            action: action,
            planFingerprint: planFingerprint,
            selectionFingerprint: selectionFingerprint,
            contextFingerprint: contextFingerprint,
            decisionFingerprint: decisionFingerprint,
            admissionNotAfter: admissionNotAfter
        )
    }
}

public struct CleanupPolicyAllowed: Sendable, Equatable {
    public let decisions: [PolicyDecision]
    public let confirmation: CleanupConfirmation
}

public struct CleanupPolicyBlocked: Sendable, Equatable {
    public let decisions: [PolicyDecision]
    public let stale: CleanupStaleResult
}

struct CleanupPolicyItemEvaluation: Sendable, Equatable {
    let decision: PolicyDecision
    let stale: CleanupStaleResult?
}

public enum CleanupPolicyEvaluation: Sendable, Equatable {
    case allowed(CleanupPolicyAllowed)
    case blocked(CleanupPolicyBlocked)

    public var allowed: CleanupPolicyAllowed? {
        guard case let .allowed(value) = self else {
            return nil
        }
        return value
    }

    public var blocked: CleanupPolicyBlocked? {
        guard case let .blocked(value) = self else {
            return nil
        }
        return value
    }
}

public struct CleanupPolicyGate: Sendable {
    public init() {}

    public func evaluate(
        plan: CleanupPlan,
        selection: ReviewSelection,
        context: CleanupPolicyContext,
        evaluatedAt: Date
    ) throws -> CleanupPolicyEvaluation {
        let globalReasons = globalReasons(
            plan: plan,
            selection: selection,
            context: context,
            evaluatedAt: evaluatedAt,
            expectedItemIDs: selection.items.map(\.itemID)
        )
        let planItems = Dictionary(
            uniqueKeysWithValues: plan.items.map { ($0.id, $0) }
        )
        let contexts = Dictionary(
            uniqueKeysWithValues: context.items.map { ($0.itemID, $0) }
        )
        var decisions: [PolicyDecision] = []
        for selected in selection.items {
            guard let item = planItems[selected.itemID] else {
                throw ReviewSelectionError.unknownItem
            }
            decisions.append(
                try makeDecision(
                    plan: plan,
                    selection: selection,
                    selected: selected,
                    item: item,
                    context: contexts[selected.itemID],
                    contextFingerprint: context.contextFingerprint,
                    globalReasons: globalReasons,
                    evaluatedAt: evaluatedAt
                )
            )
        }

        guard decisions.allSatisfy({ $0.outcome == .allowed }) else {
            let denied = decisions.filter { $0.outcome == .denied }
            let reasonGroups = Set(
                denied.flatMap(\.reasonKeys).compactMap(staleReasonGroup)
            )
            return .blocked(
                CleanupPolicyBlocked(
                    decisions: decisions,
                    stale: CleanupStaleResult(
                        affectedItemIDs: Set(denied.map(\.itemID)),
                        reasonGroups: reasonGroups
                    )
                )
            )
        }

        let confirmation = try makeConfirmation(
            plan: plan,
            selection: selection,
            context: context,
            decisions: decisions
        )
        return .allowed(
            CleanupPolicyAllowed(
                decisions: decisions,
                confirmation: confirmation
            )
        )
    }

    func revalidateItem(
        itemID: CleanupPlanItemID,
        plan: CleanupPlan,
        selection: ReviewSelection,
        context: CleanupPolicyContext,
        evaluatedAt: Date
    ) throws -> CleanupPolicyItemEvaluation {
        guard let selected = selection.items.first(where: {
            $0.itemID == itemID
        }), let item = plan.items.first(where: {
            $0.id == itemID
        }) else {
            throw ReviewSelectionError.unknownItem
        }
        let globalReasons = globalReasons(
            plan: plan,
            selection: selection,
            context: context,
            evaluatedAt: evaluatedAt,
            expectedItemIDs: [itemID]
        )
        let decision = try makeDecision(
            plan: plan,
            selection: selection,
            selected: selected,
            item: item,
            context: context.items.first { $0.itemID == itemID },
            contextFingerprint: context.contextFingerprint,
            globalReasons: globalReasons,
            evaluatedAt: evaluatedAt
        )
        let stale = decision.outcome == .denied
            ? CleanupStaleResult(
                affectedItemIDs: [itemID],
                reasonGroups: Set(
                    decision.reasonKeys.compactMap(staleReasonGroup)
                )
            )
            : nil
        return CleanupPolicyItemEvaluation(
            decision: decision,
            stale: stale
        )
    }

    private func globalReasons(
        plan: CleanupPlan,
        selection: ReviewSelection,
        context: CleanupPolicyContext,
        evaluatedAt: Date,
        expectedItemIDs: [CleanupPlanItemID]
    ) -> [DomainToken] {
        var reasons: [DomainToken] = []
        if plan.compatibility != .current {
            reasons.append(cleanupPolicyToken("policy.plan.legacy"))
        }
        if evaluatedAt > plan.expiresAt {
            reasons.append(cleanupPolicyToken("policy.plan.expired"))
        }
        if selection.planID != plan.id
            || context.planID != plan.id
            || context.scanSessionID != plan.scanSessionID
            || context.scanScopeID != plan.scanScopeID
            || context.planFingerprint != plan.planFingerprint
        {
            reasons.append(cleanupPolicyToken("policy.plan.binding-changed"))
        }
        if !context.scanIsTerminal {
            reasons.append(cleanupPolicyToken("policy.plan.scan-incomplete"))
        }
        if context.selectionGeneration != selection.generation
            || context.selectionFingerprint != selection.fingerprint
            || context.items.map(\.itemID) != expectedItemIDs
        {
            reasons.append(
                cleanupPolicyToken("policy.selection.generation-changed")
            )
        }
        if context.rootIdentity != plan.primaryRootIdentity {
            reasons.append(cleanupPolicyToken("policy.root.changed"))
        }
        if context.catalogVersion != plan.catalogVersion
            || context.executionProfileVersion
                != plan.executionProfileVersion
        {
            reasons.append(cleanupPolicyToken("policy.catalog.changed"))
        }
        let contextAge = evaluatedAt.timeIntervalSince(context.capturedAt)
        if !contextAge.isFinite
            || contextAge < 0
            || contextAge > CleanupPolicyContext.maximumAge
        {
            reasons.append(cleanupPolicyToken("policy.context.expired"))
        }
        if !context.workflow.rootLeaseAvailable {
            reasons.append(cleanupPolicyToken("policy.root.lease-lost"))
        }
        for conflict in context.workflow.activeConflicts {
            reasons.append(workflowReason(conflict))
        }
        return reasons
    }

    private func makeDecision(
        plan: CleanupPlan,
        selection: ReviewSelection,
        selected: ReviewSelectionItem,
        item: CleanupPlanItem,
        context: CleanupPolicyItemContext?,
        contextFingerprint: DomainToken,
        globalReasons: [DomainToken],
        evaluatedAt: Date
    ) throws -> PolicyDecision {
        var reasons = globalReasons
        reasons.append(contentsOf: itemReasons(
            item: item,
            selected: selected,
            context: context
        ))
        reasons = Array(Set(reasons)).sorted {
            $0.rawValue < $1.rawValue
        }
        let disposition = context?.currentDisposition ?? .unknown
        let outcome: PolicyDecisionOutcome =
            reasons.isEmpty ? .allowed : .denied
        let effectiveReasons = reasons.isEmpty
            ? [cleanupPolicyToken("policy.item.allowed")]
            : reasons
        let decisionFingerprint = cleanupFingerprint(
            prefix: "policy-decision",
            lines: [
                "stornaut.cleanup-policy-decision.v1",
                plan.id.rawValue,
                item.id.rawValue,
                selection.fingerprint.rawValue,
                contextFingerprint.rawValue,
                disposition.rawValue,
                selected.origin.rawValue,
                outcome.rawValue,
                String(evaluatedAt.timeIntervalSince1970.bitPattern),
                effectiveReasons.map(\.rawValue)
                    .joined(separator: ","),
            ]
        )
        return try PolicyDecision(
            id: PolicyDecisionID(
                rawValue: "decision-\(decisionFingerprint.rawValue)"
            )!,
            planID: plan.id,
            itemID: item.id,
            outcome: outcome,
            disposition: disposition,
            selectionGeneration: selection.generation,
            selectionOrigin: selected.origin,
            planFingerprint: plan.planFingerprint!,
            decisionFingerprint: decisionFingerprint,
            reasonKeys: effectiveReasons,
            evaluatedAt: evaluatedAt
        )
    }

    private func itemReasons(
        item: CleanupPlanItem,
        selected: ReviewSelectionItem,
        context: CleanupPolicyItemContext?
    ) -> [DomainToken] {
        guard let context else {
            return [cleanupPolicyToken("policy.item.missing")]
        }
        var reasons: [DomainToken] = []
        if context.snapshotID != item.snapshotID
            || context.classificationID != item.classificationID
            || context.ruleID != item.ruleID
            || context.executionProfileID != item.executionProfileID
            || context.expectedRelativePath != item.expectedRelativePath
            || context.persistedDisposition == .protected
            || context.persistedDisposition == .unknown
        {
            reasons.append(cleanupPolicyToken("policy.item.mismatch"))
        }
        if context.proposedAction != .moveToTrash
            || item.proposedAction != .moveToTrash
        {
            reasons.append(cleanupPolicyToken("policy.item.action-mismatch"))
        }
        if context.currentDisposition == .protected
            || context.currentDisposition == .unknown
        {
            reasons.append(
                cleanupPolicyToken("policy.item.disposition-blocked")
            )
        }
        if context.persistedDisposition == .reviewRecommended
            && context.currentDisposition == .readyToReclaim
        {
            reasons.append(cleanupPolicyToken("policy.item.promotion-blocked"))
        }
        if context.currentDisposition == .reviewRecommended
            && selected.origin != .explicitUser
        {
            reasons.append(
                cleanupPolicyToken("policy.selection.review-explicit-required")
            )
        }
        if context.expectedIdentity != item.expectedIdentity
            || context.currentIdentity != item.expectedIdentity
            || context.currentRelativePath != item.expectedRelativePath
        {
            reasons.append(cleanupPolicyToken("policy.identity.changed"))
        }
        if context.evidenceFingerprint != item.evidenceFingerprint
            || context.currentEvidenceFingerprint
                != item.evidenceFingerprint
        {
            reasons.append(
                cleanupPolicyToken("policy.evidence.fingerprint-changed")
            )
        }
        if context.activityFingerprint != item.activityFingerprint
            || context.currentActivityFingerprint
                != item.activityFingerprint
        {
            reasons.append(
                cleanupPolicyToken("policy.activity.fingerprint-changed")
            )
        }
        reasons.append(contentsOf: pathReasons(context.pathFacts))
        if let reason = evidenceReason(context.evidenceFacts) {
            reasons.append(reason)
        }
        if let reason = activityReason(context.activityFacts) {
            reasons.append(reason)
        }
        return reasons
    }

    private func makeConfirmation(
        plan: CleanupPlan,
        selection: ReviewSelection,
        context: CleanupPolicyContext,
        decisions: [PolicyDecision]
    ) throws -> CleanupConfirmation {
        let planItems = Dictionary(
            uniqueKeysWithValues: plan.items.map { ($0.id, $0) }
        )
        var logical: UInt64 = 0
        var allocated: UInt64 = 0
        for selected in selection.items {
            guard let item = planItems[selected.itemID],
                  let itemLogical = item.logicalBytes?.value,
                  let itemAllocated = item.allocatedBytes?.value
            else {
                throw DomainContractError.invalidMeasurement
            }
            let logicalResult = logical.addingReportingOverflow(
                itemLogical
            )
            let allocatedResult = allocated.addingReportingOverflow(
                itemAllocated
            )
            guard !logicalResult.overflow,
                  !allocatedResult.overflow,
                  let checkedLogical = ByteCount(logicalResult.partialValue),
                  let checkedAllocated = ByteCount(
                      allocatedResult.partialValue
                  )
            else {
                throw DomainContractError.invalidMeasurement
            }
            logical = checkedLogical.value
            allocated = checkedAllocated.value
        }
        let aggregateDecisionFingerprint = cleanupFingerprint(
            prefix: "policy-batch",
            lines: [
                "stornaut.cleanup-policy-batch.v1",
                plan.id.rawValue,
                selection.fingerprint.rawValue,
                context.contextFingerprint.rawValue,
            ] + decisions.compactMap(\.decisionFingerprint?.rawValue)
        )
        return CleanupConfirmation(
            planID: plan.id,
            selectionGeneration: selection.generation,
            orderedItemIDs: selection.items.map(\.itemID),
            reviewItemCount: decisions.filter {
                $0.disposition == .reviewRecommended
                    && $0.selectionOrigin == .explicitUser
            }.count,
            logicalBytes: ByteCount(logical)!,
            allocatedBytes: ByteCount(allocated)!,
            action: .moveToTrash,
                    planFingerprint: plan.planFingerprint
                        ?? cleanupPolicyToken("plan.legacy.unavailable"),
            selectionFingerprint: selection.fingerprint,
            contextFingerprint: context.contextFingerprint,
            decisionFingerprint: aggregateDecisionFingerprint,
            admissionNotAfter: min(
                plan.expiresAt,
                context.capturedAt.addingTimeInterval(
                    CleanupPolicyContext.maximumAge
                )
            )
        )
    }
}

private func cleanupPolicyItemFingerprintLine(
    _ item: CleanupPolicyItemContext
) -> String {
    [
        item.itemID.rawValue,
        item.snapshotID.rawValue,
        item.classificationID.rawValue,
        item.ruleID.rawValue,
        item.executionProfileID.rawValue,
        cleanupActionFingerprintLine(item.proposedAction),
        item.persistedDisposition.rawValue,
        item.currentDisposition.rawValue,
        item.expectedRelativePath.rawValue,
        item.currentRelativePath.rawValue,
        cleanupIdentityFingerprintLine(item.expectedIdentity),
        cleanupIdentityFingerprintLine(item.currentIdentity),
        item.evidenceFingerprint.rawValue,
        item.currentEvidenceFingerprint.rawValue,
        item.activityFingerprint.rawValue,
        item.currentActivityFingerprint.rawValue,
        cleanupPathFactsFingerprintLine(item.pathFacts),
        cleanupEvidenceFactsFingerprintLine(item.evidenceFacts),
        cleanupActivityFactsFingerprintLine(item.activityFacts),
    ].joined(separator: "|")
}

private func cleanupActionFingerprintLine(
    _ action: ProposedCleanupAction
) -> String {
    switch action {
    case .moveToTrash:
        return "move-to-trash"
    case let .registeredAction(id):
        return "registered-action:\(id.rawValue)"
    }
}

private func cleanupPathFactsFingerprintLine(
    _ facts: CleanupPathPolicyFacts
) -> String {
    [
        facts.isRoot,
        facts.isHome,
        facts.isMountRoot,
        facts.isSymbolicLink,
        facts.isSensitive,
        facts.isInsideRoot,
        facts.ownerMatches,
        facts.volumeMatches,
    ].map { $0 ? "1" : "0" }.joined()
}

private func cleanupEvidenceFactsFingerprintLine(
    _ facts: CleanupEvidencePolicyFacts
) -> String {
    switch facts {
    case .current:
        "current"
    case .missing:
        "missing"
    case .stale:
        "stale"
    case .expired:
        "expired"
    case .contradicted:
        "contradicted"
    case .unavailable:
        "unavailable"
    }
}

private func cleanupActivityFactsFingerprintLine(
    _ facts: CleanupActivityPolicyFacts
) -> String {
    switch facts {
    case .inactive:
        "inactive"
    case .active:
        "active"
    case .unavailable:
        "unavailable"
    case .contradicted:
        "contradicted"
    }
}

private func pathReasons(
    _ facts: CleanupPathPolicyFacts
) -> [DomainToken] {
    var reasons: [DomainToken] = []
    if facts.isRoot {
        reasons.append(cleanupPolicyToken("policy.path.root"))
    }
    if facts.isHome {
        reasons.append(cleanupPolicyToken("policy.path.home"))
    }
    if facts.isMountRoot {
        reasons.append(cleanupPolicyToken("policy.path.mount-root"))
    }
    if facts.isSymbolicLink {
        reasons.append(cleanupPolicyToken("policy.path.symbolic-link"))
    }
    if facts.isSensitive {
        reasons.append(cleanupPolicyToken("policy.path.sensitive"))
    }
    if !facts.isInsideRoot {
        reasons.append(cleanupPolicyToken("policy.path.outside-root"))
    }
    if !facts.ownerMatches {
        reasons.append(cleanupPolicyToken("policy.path.owner-changed"))
    }
    if !facts.volumeMatches {
        reasons.append(cleanupPolicyToken("policy.path.volume-changed"))
    }
    return reasons
}

private func evidenceReason(
    _ facts: CleanupEvidencePolicyFacts
) -> DomainToken? {
    switch facts {
    case .current:
        nil
    case .missing:
        cleanupPolicyToken("policy.evidence.missing")
    case .stale:
        cleanupPolicyToken("policy.evidence.stale")
    case .expired:
        cleanupPolicyToken("policy.evidence.expired")
    case .contradicted:
        cleanupPolicyToken("policy.evidence.contradicted")
    case .unavailable:
        cleanupPolicyToken("policy.evidence.unavailable")
    }
}

private func activityReason(
    _ facts: CleanupActivityPolicyFacts
) -> DomainToken? {
    switch facts {
    case .inactive:
        nil
    case .active:
        cleanupPolicyToken("policy.activity.active")
    case .unavailable:
        cleanupPolicyToken("policy.activity.unavailable")
    case .contradicted:
        cleanupPolicyToken("policy.activity.contradicted")
    }
}

private func workflowReason(
    _ conflict: CleanupWorkflowConflict
) -> DomainToken {
    switch conflict {
    case .quickScan:
        cleanupPolicyToken("policy.workflow.quick-scan-active")
    case .settingsMutation:
        cleanupPolicyToken("policy.workflow.settings-mutation-active")
    case .historyMutation:
        cleanupPolicyToken("policy.workflow.history-mutation-active")
    case .cleanupExecution:
        cleanupPolicyToken("policy.workflow.cleanup-execution-active")
    case .lifecycleReset:
        cleanupPolicyToken("policy.workflow.lifecycle-reset")
    }
}

private func staleReasonGroup(
    _ reason: DomainToken
) -> CleanupStaleReasonGroup? {
    let value = reason.rawValue
    if value.hasPrefix("policy.plan.")
        || value.hasPrefix("policy.context.")
    {
        return .plan
    }
    if value.hasPrefix("policy.selection.") {
        return .selection
    }
    if value.hasPrefix("policy.root.") {
        return .root
    }
    if value.hasPrefix("policy.catalog.") {
        return .catalog
    }
    if value.hasPrefix("policy.identity.") {
        return .identity
    }
    if value.hasPrefix("policy.evidence.") {
        return .evidence
    }
    if value.hasPrefix("policy.activity.") {
        return .activity
    }
    if value.hasPrefix("policy.path.") {
        return .path
    }
    if value.hasPrefix("policy.workflow.") {
        return .workflow
    }
    if value.hasPrefix("policy.confirmation.") {
        return .confirmation
    }
    return .item
}

func cleanupPolicyToken(_ rawValue: String) -> DomainToken {
    DomainToken(rawValue: rawValue)!
}
