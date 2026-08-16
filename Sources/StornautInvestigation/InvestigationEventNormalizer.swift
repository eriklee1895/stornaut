import CryptoKit
import Foundation
import StornautCore

package enum InvestigationEventError: Error, Sendable, Equatable {
    case rootIdentityMismatch
    case unknownThread
    case unverifiedChild
    case orphanChild
    case duplicateChild
    case lineageCycle
    case turnIdentityMismatch
    case conflictingReplay
    case nonSelectedSchema
    case invalidCollaborationIdentity
    case writeCapableItem
    case unknownToolItem
    case counterDecreased
    case invalidUsage
    case postTerminalEvent
    case unclassifiedDescendant
    case liveDescendant
}

package struct InvestigationRuntimeItemEventV1:
    Sendable,
    Equatable
{
    public let threadID: DomainToken
    public let turnID: DomainToken
    public let itemID: DomainToken
    public let type: String
    public let tool: String?
    public let senderThreadID: DomainToken?
    public let childThreadIDs: [DomainToken]
    public let mcpReadOnly: Bool?
    public let payload: Data

    package init(
        threadID: DomainToken,
        turnID: DomainToken,
        itemID: DomainToken,
        type: String,
        tool: String?,
        senderThreadID: DomainToken?,
        childThreadIDs: [DomainToken],
        mcpReadOnly: Bool?,
        payload: Data
    ) {
        self.threadID = threadID
        self.turnID = turnID
        self.itemID = itemID
        self.type = type
        self.tool = tool
        self.senderThreadID = senderThreadID
        self.childThreadIDs = childThreadIDs
        self.mcpReadOnly = mcpReadOnly
        self.payload = payload
    }
}

package struct InvestigationRuntimeTokenUsageEventV1:
    Sendable,
    Equatable
{
    public let threadID: DomainToken
    public let turnID: DomainToken
    public let total: InvestigationTokenUsage
    public let last: InvestigationTokenUsage
    public let payload: Data

    package init(
        threadID: DomainToken,
        turnID: DomainToken,
        total: InvestigationTokenUsage,
        last: InvestigationTokenUsage,
        payload: Data
    ) {
        self.threadID = threadID
        self.turnID = turnID
        self.total = total
        self.last = last
        self.payload = payload
    }
}

package struct InvestigationItemNormalizationV1:
    Sendable,
    Equatable
{
    public let directToolObservation: InvestigationRuntimeObservation?
    public let observedDirectToolStarts: UInt64
    public let admittedChildThreadIDs: [DomainToken]

    package init(
        directToolObservation: InvestigationRuntimeObservation?,
        observedDirectToolStarts: UInt64,
        admittedChildThreadIDs: [DomainToken]
    ) {
        self.directToolObservation = directToolObservation
        self.observedDirectToolStarts = observedDirectToolStarts
        self.admittedChildThreadIDs = admittedChildThreadIDs
    }
}

package struct InvestigationTokenNormalizationV1:
    Sendable,
    Equatable
{
    public let totalTokens: UInt64?
    public let quality: InvestigationTokenUsageQuality
    public let acceptedObservation: Bool

    package init(
        totalTokens: UInt64?,
        quality: InvestigationTokenUsageQuality,
        acceptedObservation: Bool
    ) {
        self.totalTokens = totalTokens
        self.quality = quality
        self.acceptedObservation = acceptedObservation
    }
}

package struct InvestigationTreeFinalizationV1:
    Sendable,
    Equatable
{
    public let allTurnsTerminal: Bool
    public let totalTokens: UInt64?
    public let usageQuality: InvestigationTokenUsageQuality
    public let usageUnavailableThreadIDs: [DomainToken]

    package init(
        allTurnsTerminal: Bool,
        totalTokens: UInt64?,
        usageQuality: InvestigationTokenUsageQuality,
        usageUnavailableThreadIDs: [DomainToken]
    ) {
        self.allTurnsTerminal = allTurnsTerminal
        self.totalTokens = totalTokens
        self.usageQuality = usageQuality
        self.usageUnavailableThreadIDs = usageUnavailableThreadIDs
    }
}

package struct InvestigationEventNormalizer: Sendable {
    private struct TurnKey: Sendable, Hashable {
        let threadID: DomainToken
        let turnID: DomainToken
    }

    private struct ItemKey: Sendable, Hashable {
        let threadID: DomainToken
        let turnID: DomainToken
        let itemID: DomainToken
    }

    private struct ItemReplay: Sendable, Equatable {
        let type: String
        let fingerprint: InvestigationFingerprint
    }

    private struct PendingChild: Sendable, Equatable {
        let parentThreadID: DomainToken
        let parentTurnID: DomainToken
        let spawnItemID: DomainToken
    }

    private struct TokenReplay: Sendable, Equatable {
        let turnID: DomainToken
        let total: InvestigationTokenUsage
        let fingerprint: InvestigationFingerprint
    }

    private struct RetainedEnvelope: Sendable, Equatable {
        let turn: TurnKey
        let data: Data
        let fingerprint: InvestigationFingerprint
    }

    private let identity: InvestigationBudgetIdentity
    private let receipt: InvestigationRuntimeReceiptV1
    private var ledger: InvestigationBudgetLedger
    private var nextOrdinal: UInt64 = 1
    private var rootAccepted = false
    private var rootNotificationFingerprint: InvestigationFingerprint?
    private var finalized = false
    private var parents: [DomainToken: DomainToken?] = [:]
    private var verifiedThreads = Set<DomainToken>()
    private var pendingChildren: [DomainToken: PendingChild] = [:]
    private var reservedTurns = Set<TurnKey>()
    private var failedTurnStarts = Set<TurnKey>()
    private var activeTurns = Set<TurnKey>()
    private var turnReplays: [TurnKey: InvestigationFingerprint] = [:]
    private var terminalTurnReplays: [TurnKey: InvestigationFingerprint] = [:]
    private var terminalTurns = Set<TurnKey>()
    private var usageObservedTurns = Set<TurnKey>()
    private var itemReplays: [ItemKey: ItemReplay] = [:]
    private var completedItemReplays: [ItemKey: ItemReplay] = [:]
    private var tokenReplays: [DomainToken: TokenReplay] = [:]
    private var retainedEnvelope: RetainedEnvelope?

    package init(
        identity: InvestigationBudgetIdentity,
        receipt: InvestigationRuntimeReceiptV1,
        limits: InvestigationBudgetLimits
    ) {
        self.identity = identity
        self.receipt = receipt
        ledger = InvestigationBudgetLedger(
            identity: identity,
            limits: limits
        )
    }

    package mutating func acceptRoot(
        _ root: InvestigationRuntimeRootV1
    ) throws {
        guard !finalized,
              root.id == root.sessionID,
              root.id == identity.rootSessionID
        else {
            throw InvestigationEventError.rootIdentityMismatch
        }
        if rootAccepted {
            return
        }
        rootAccepted = true
        parents[root.id] = nil
    }

    package mutating func acceptRootStartedNotification(
        _ root: InvestigationRuntimeRootV1,
        payload: Data
    ) throws {
        guard !finalized,
              rootAccepted,
              root.id == root.sessionID,
              root.id == identity.rootSessionID
        else {
            throw InvestigationEventError.rootIdentityMismatch
        }
        let fingerprint = try payloadFingerprint(payload)
        if let prior = rootNotificationFingerprint {
            guard prior == fingerprint else {
                throw InvestigationEventError.conflictingReplay
            }
            return
        }
        rootNotificationFingerprint = fingerprint
        verifiedThreads.insert(root.id)
    }

    package mutating func reserveTurnStart(
        threadID: DomainToken,
        turnID: DomainToken,
        contextByteCount: UInt64
    ) throws -> InvestigationHardBudgetUsage {
        guard !finalized else {
            throw InvestigationEventError.postTerminalEvent
        }
        try requireVerifiedThread(threadID)
        let key = TurnKey(threadID: threadID, turnID: turnID)
        guard !reservedTurns.contains(where: {
                  $0.threadID == threadID
              }),
              !failedTurnStarts.contains(key),
              turnReplays[key] == nil,
              !activeTurns.contains(where: {
                $0.threadID == threadID
              })
        else {
            throw InvestigationEventError.turnIdentityMismatch
        }
        try ledger.reserveTurn(
            contextByteCount: contextByteCount,
            coordinatorOrdinal: consumeOrdinal()
        )
        reservedTurns.insert(key)
        if threadID == identity.rootSessionID {
            retainedEnvelope = nil
        }
        return ledger.hardUsage
    }

    package mutating func abandonTurnStart(
        threadID: DomainToken,
        turnID: DomainToken
    ) throws {
        let key = TurnKey(threadID: threadID, turnID: turnID)
        guard reservedTurns.contains(key),
              turnReplays[key] == nil,
              !activeTurns.contains(key)
        else {
            throw InvestigationEventError.turnIdentityMismatch
        }
        reservedTurns.remove(key)
        failedTurnStarts.insert(key)
    }

    package mutating func bindReservedTurn(
        reservationThreadID: DomainToken,
        reservationTurnID: DomainToken,
        runtimeIdentity: InvestigationRuntimeTurnIdentityV1
    ) throws {
        let reservedKey = TurnKey(
            threadID: reservationThreadID,
            turnID: reservationTurnID
        )
        let runtimeKey = TurnKey(
            threadID: runtimeIdentity.threadID,
            turnID: runtimeIdentity.turnID
        )
        guard !finalized,
              runtimeIdentity.investigationID == identity.investigationID,
              runtimeIdentity.runID == identity.runID,
              runtimeIdentity.threadID == reservationThreadID,
              reservedTurns.contains(reservedKey),
              !activeTurns.contains(reservedKey),
              !failedTurnStarts.contains(runtimeKey),
              turnReplays[runtimeKey] == nil,
              runtimeKey == reservedKey
                || (
                    !reservedTurns.contains(runtimeKey)
                        && !activeTurns.contains(runtimeKey)
                )
        else {
            throw InvestigationEventError.turnIdentityMismatch
        }
        reservedTurns.remove(reservedKey)
        activeTurns.insert(runtimeKey)
    }

    package mutating func acceptTurnStarted(
        threadID: DomainToken,
        turnID: DomainToken,
        payload: Data
    ) throws {
        guard !finalized else {
            throw InvestigationEventError.postTerminalEvent
        }
        try requireVerifiedThread(threadID)
        let key = TurnKey(threadID: threadID, turnID: turnID)
        let fingerprint = try payloadFingerprint(payload)
        if let prior = turnReplays[key] {
            guard prior == fingerprint else {
                throw InvestigationEventError.conflictingReplay
            }
            return
        }
        guard activeTurns.contains(key) else {
            throw InvestigationEventError.turnIdentityMismatch
        }
        turnReplays[key] = fingerprint
    }

    package mutating func acceptItemStarted(
        _ event: InvestigationRuntimeItemEventV1
    ) throws -> InvestigationItemNormalizationV1 {
        guard !finalized else {
            throw InvestigationEventError.postTerminalEvent
        }
        try requireActiveTurn(event.threadID, turnID: event.turnID)
        let classification = try classifyItem(event)
        let key = ItemKey(
            threadID: event.threadID,
            turnID: event.turnID,
            itemID: event.itemID
        )
        let replay = ItemReplay(
            type: event.type,
            fingerprint: try payloadFingerprint(event.payload)
        )
        if let prior = itemReplays[key] {
            guard prior == replay else {
                throw InvestigationEventError.conflictingReplay
            }
            return InvestigationItemNormalizationV1(
                directToolObservation: nil,
                observedDirectToolStarts:
                    ledger.observedUsage.directToolStarts,
                admittedChildThreadIDs: []
            )
        }
        guard classification == .directTool else {
            itemReplays[key] = replay
            return InvestigationItemNormalizationV1(
                directToolObservation: nil,
                observedDirectToolStarts:
                    ledger.observedUsage.directToolStarts,
                admittedChildThreadIDs: []
            )
        }
        let observation = InvestigationRuntimeObservation(
            identity: identity,
            threadID: event.threadID,
            parentThreadID: parents[event.threadID] ?? nil,
            turnID: event.turnID,
            itemID: event.itemID,
            kind: .directToolStarted,
            sourceMethod: DomainToken(
                rawValue: "app-server-item-started"
            )!,
            coordinatorOrdinal: consumeOrdinal(),
            payloadFingerprint: replay.fingerprint
        )
        try ledger.acceptDirectToolStart(observation)
        itemReplays[key] = replay
        return InvestigationItemNormalizationV1(
            directToolObservation: observation,
            observedDirectToolStarts:
                ledger.observedUsage.directToolStarts,
            admittedChildThreadIDs: []
        )
    }

    package mutating func acceptItemCompleted(
        _ event: InvestigationRuntimeItemEventV1
    ) throws -> InvestigationItemNormalizationV1 {
        guard !finalized else {
            throw InvestigationEventError.postTerminalEvent
        }
        try requireActiveTurn(event.threadID, turnID: event.turnID)
        let classification = try classifyItem(event)
        guard event.type == receipt.schema.itemType else {
            _ = classification
            return InvestigationItemNormalizationV1(
                directToolObservation: nil,
                observedDirectToolStarts:
                    ledger.observedUsage.directToolStarts,
                admittedChildThreadIDs: []
            )
        }
        guard event.tool == receipt.schema.spawnTool,
              event.senderThreadID == event.threadID,
              !event.childThreadIDs.isEmpty,
              Set(event.childThreadIDs).count
                == event.childThreadIDs.count
        else {
            throw InvestigationEventError.invalidCollaborationIdentity
        }
        let key = ItemKey(
            threadID: event.threadID,
            turnID: event.turnID,
            itemID: event.itemID
        )
        let replay = ItemReplay(
            type: event.type,
            fingerprint: try payloadFingerprint(event.payload)
        )
        if let prior = completedItemReplays[key] {
            guard prior == replay else {
                throw InvestigationEventError.conflictingReplay
            }
            return InvestigationItemNormalizationV1(
                directToolObservation: nil,
                observedDirectToolStarts:
                    ledger.observedUsage.directToolStarts,
                admittedChildThreadIDs: []
            )
        }
        var admitted: [DomainToken] = []
        for childID in event.childThreadIDs {
            guard childID != identity.rootSessionID,
                  parents[childID] == nil,
                  pendingChildren[childID] == nil
            else {
                throw InvestigationEventError.duplicateChild
            }
            guard !isAncestor(childID, of: event.threadID) else {
                throw InvestigationEventError.lineageCycle
            }
            pendingChildren[childID] = PendingChild(
                parentThreadID: event.threadID,
                parentTurnID: event.turnID,
                spawnItemID: event.itemID
            )
            admitted.append(childID)
        }
        completedItemReplays[key] = replay
        return InvestigationItemNormalizationV1(
            directToolObservation: nil,
            observedDirectToolStarts: ledger.observedUsage.directToolStarts,
            admittedChildThreadIDs: admitted
        )
    }

    package mutating func verifyChild(
        _ metadata: InvestigationRuntimeThreadMetadataV1
    ) throws {
        guard !finalized else {
            throw InvestigationEventError.postTerminalEvent
        }
        guard let pending = pendingChildren[metadata.id] else {
            throw InvestigationEventError.orphanChild
        }
        guard metadata.parentThreadID == pending.parentThreadID,
              metadata.sessionID == identity.rootSessionID,
              verifiedThreads.contains(pending.parentThreadID)
        else {
            throw InvestigationEventError.unverifiedChild
        }
        parents[metadata.id] = pending.parentThreadID
        verifiedThreads.insert(metadata.id)
        pendingChildren.removeValue(forKey: metadata.id)
    }

    package mutating func acceptTokenUsage(
        _ event: InvestigationRuntimeTokenUsageEventV1
    ) throws -> InvestigationTokenNormalizationV1 {
        guard !finalized else {
            throw InvestigationEventError.postTerminalEvent
        }
        try requireKnownTurn(event.threadID, turnID: event.turnID)
        let fingerprint = try payloadFingerprint(event.payload)
        if let prior = tokenReplays[event.threadID] {
            if prior.turnID == event.turnID,
               prior.total == event.total,
               prior.fingerprint == fingerprint
            {
                let usage = ledger.observedUsage
                return InvestigationTokenNormalizationV1(
                    totalTokens: usage.totalTokens,
                    quality: usage.tokenQuality,
                    acceptedObservation: false
                )
            }
            guard event.total != prior.total else {
                throw InvestigationEventError.conflictingReplay
            }
        }
        let observation = InvestigationRuntimeObservation(
            identity: identity,
            threadID: event.threadID,
            parentThreadID: parents[event.threadID] ?? nil,
            turnID: event.turnID,
            itemID: nil,
            kind: .tokenUsageUpdated,
            sourceMethod: DomainToken(
                rawValue: "app-server-token-usage-updated"
            )!,
            coordinatorOrdinal: consumeOrdinal(),
            payloadFingerprint: fingerprint
        )
        do {
            try ledger.acceptTokenUsage(
                InvestigationTokenUsageObservation(
                    observation: observation,
                    total: event.total
                )
            )
        } catch InvestigationBudgetError.counterDecreased {
            throw InvestigationEventError.counterDecreased
        } catch InvestigationBudgetError.conflictingReplay {
            throw InvestigationEventError.conflictingReplay
        } catch {
            throw InvestigationEventError.invalidUsage
        }
        tokenReplays[event.threadID] = TokenReplay(
            turnID: event.turnID,
            total: event.total,
            fingerprint: fingerprint
        )
        usageObservedTurns.insert(
            TurnKey(threadID: event.threadID, turnID: event.turnID)
        )
        let usage = ledger.observedUsage
        return InvestigationTokenNormalizationV1(
            totalTokens: usage.totalTokens,
            quality: usage.tokenQuality,
            acceptedObservation: true
        )
    }

    package mutating func acceptTurnTerminal(
        threadID: DomainToken,
        turnID: DomainToken,
        payload: Data
    ) throws {
        guard !finalized else {
            throw InvestigationEventError.postTerminalEvent
        }
        try requireVerifiedThread(threadID)
        let key = TurnKey(threadID: threadID, turnID: turnID)
        let fingerprint = try payloadFingerprint(payload)
        if let prior = terminalTurnReplays[key] {
            guard prior == fingerprint else {
                throw InvestigationEventError.conflictingReplay
            }
            return
        }
        guard activeTurns.remove(key) != nil else {
            if terminalTurns.contains(key) {
                throw InvestigationEventError.conflictingReplay
            }
            throw InvestigationEventError.turnIdentityMismatch
        }
        terminalTurnReplays[key] = fingerprint
        terminalTurns.insert(key)
    }

    package mutating func retainFinalEnvelope(
        threadID: DomainToken,
        turnID: DomainToken,
        data: Data
    ) throws {
        guard !finalized else {
            throw InvestigationEventError.postTerminalEvent
        }
        try requireActiveTurn(threadID, turnID: turnID)
        guard threadID == identity.rootSessionID else {
            return
        }
        let retained = RetainedEnvelope(
            turn: TurnKey(threadID: threadID, turnID: turnID),
            data: data,
            fingerprint: try payloadFingerprint(data)
        )
        if let prior = retainedEnvelope {
            if prior.turn == retained.turn {
                guard prior == retained else {
                    throw InvestigationEventError.conflictingReplay
                }
                return
            }
            guard terminalTurns.contains(prior.turn) else {
                throw InvestigationEventError.conflictingReplay
            }
        }
        retainedEnvelope = retained
    }

    package mutating func finalizeTree(
    ) throws -> InvestigationTreeFinalizationV1 {
        guard !finalized else {
            throw InvestigationEventError.postTerminalEvent
        }
        guard pendingChildren.isEmpty else {
            throw InvestigationEventError.unclassifiedDescendant
        }
        let threadsWithTerminalTurns = Set(
            terminalTurns.map(\.threadID)
        )
        guard reservedTurns.isEmpty,
              activeTurns.isEmpty,
              verifiedThreads.isSubset(of: threadsWithTerminalTurns)
        else {
            throw InvestigationEventError.liveDescendant
        }
        finalized = true
        let unavailable = Set(
            terminalTurns
                .subtracting(usageObservedTurns)
                .map(\.threadID)
        ).sorted { $0.rawValue < $1.rawValue }
        let usage = ledger.observedUsage
        return InvestigationTreeFinalizationV1(
            allTurnsTerminal: true,
            totalTokens: unavailable.isEmpty ? usage.totalTokens : nil,
            usageQuality: unavailable.isEmpty
                ? usage.tokenQuality : .unavailable,
            usageUnavailableThreadIDs: unavailable
        )
    }

    package var activeTurnIdentities:
        [InvestigationRuntimeTurnIdentityV1]
    {
        activeTurns
            .map {
                InvestigationRuntimeTurnIdentityV1(
                    investigationID: identity.investigationID,
                    runID: identity.runID,
                    threadID: $0.threadID,
                    turnID: $0.turnID
                )
            }
            .sorted {
                if $0.threadID.rawValue == $1.threadID.rawValue {
                    return $0.turnID.rawValue < $1.turnID.rawValue
                }
                return $0.threadID.rawValue < $1.threadID.rawValue
            }
    }

    package var runtimeReadyForScientificWork: Bool {
        rootNotificationFingerprint != nil
    }

    package var hardUsage: InvestigationHardBudgetUsage {
        ledger.hardUsage
    }

    package var observedUsage: InvestigationObservedBudgetUsage {
        ledger.observedUsage
    }

    package var limits: InvestigationBudgetLimits {
        ledger.limits
    }

    package var consecutiveNoGainSteps: UInt64 {
        ledger.consecutiveNoGainSteps
    }

    package var activeProbeLeaseCount: UInt64 {
        ledger.activeProbeLeaseCount
    }

    package var treeReadyForFinalization: Bool {
        pendingChildren.isEmpty
            && reservedTurns.isEmpty
            && activeTurns.isEmpty
            && verifiedThreads.isSubset(
                of: Set(terminalTurns.map(\.threadID))
            )
    }

    package mutating func acquireProbeLease(
    ) throws -> InvestigationProbeLease {
        try ledger.acquireProbeLease(
            coordinatorOrdinal: consumeOrdinal()
        )
    }

    package mutating func releaseProbeLease(
        _ lease: InvestigationProbeLease
    ) throws {
        try ledger.releaseProbeLease(
            lease,
            identity: ledger.identity,
            coordinatorOrdinal: consumeOrdinal()
        )
    }

    package mutating func recordScientificStep(
        _ result: InvestigationScientificStepResult
    ) throws {
        try ledger.recordScientificStep(
            result,
            coordinatorOrdinal: consumeOrdinal()
        )
    }

    package func turnAdmissionExhaustion(
        contextByteCount: UInt64
    ) -> InvestigationBudgetDimension? {
        if ledger.hardAdmission(
            .coordinatorTurns,
            amount: 1
        ) == .wouldExceed {
            return .coordinatorTurns
        }
        if ledger.contextInputAdmission(
            byteCount: contextByteCount
        ) == .wouldExceed {
            return .cumulativeContextBytes
        }
        return nil
    }

    package var terminalEnvelopeData: Data? {
        guard let retainedEnvelope,
              terminalTurns.contains(retainedEnvelope.turn)
        else {
            return nil
        }
        return retainedEnvelope.data
    }

    package func isTerminalTurn(
        threadID: DomainToken,
        turnID: DomainToken
    ) -> Bool {
        terminalTurns.contains(
            TurnKey(threadID: threadID, turnID: turnID)
        )
    }

    package func isActiveTurn(
        threadID: DomainToken,
        turnID: DomainToken
    ) -> Bool {
        activeTurns.contains(
            TurnKey(threadID: threadID, turnID: turnID)
        )
    }

    private mutating func consumeOrdinal() -> UInt64 {
        defer { nextOrdinal += 1 }
        return nextOrdinal
    }

    private func requireVerifiedThread(
        _ threadID: DomainToken
    ) throws {
        guard rootAccepted,
              verifiedThreads.contains(threadID)
        else {
            if pendingChildren[threadID] != nil {
                throw InvestigationEventError.unverifiedChild
            }
            throw InvestigationEventError.unknownThread
        }
    }

    private func requireActiveTurn(
        _ threadID: DomainToken,
        turnID: DomainToken
    ) throws {
        try requireVerifiedThread(threadID)
        guard activeTurns.contains(
            TurnKey(threadID: threadID, turnID: turnID)
        ) else {
            throw InvestigationEventError.turnIdentityMismatch
        }
    }

    private func requireKnownTurn(
        _ threadID: DomainToken,
        turnID: DomainToken
    ) throws {
        try requireVerifiedThread(threadID)
        let key = TurnKey(threadID: threadID, turnID: turnID)
        guard activeTurns.contains(key) || terminalTurns.contains(key) else {
            throw InvestigationEventError.turnIdentityMismatch
        }
    }

    private enum ItemClassification {
        case directTool
        case nonTool
    }

    private func classifyItem(
        _ event: InvestigationRuntimeItemEventV1
    ) throws -> ItemClassification {
        if event.type == "fileChange" {
            throw InvestigationEventError.writeCapableItem
        }
        if Self.collaborationItemTypes.contains(event.type),
           event.type != receipt.schema.itemType
        {
            throw InvestigationEventError.nonSelectedSchema
        }
        if event.type == receipt.schema.itemType,
           event.tool != receipt.schema.spawnTool
        {
            throw InvestigationEventError.nonSelectedSchema
        }
        if Self.nonToolItemTypes.contains(event.type) {
            return .nonTool
        }
        guard Self.directToolItemTypes.contains(event.type)
                || event.type == receipt.schema.itemType
        else {
            throw InvestigationEventError.unknownToolItem
        }
        if event.type == "mcpToolCall",
           event.mcpReadOnly != true
        {
            throw InvestigationEventError.writeCapableItem
        }
        return .directTool
    }

    private func isAncestor(
        _ possibleAncestor: DomainToken,
        of threadID: DomainToken
    ) -> Bool {
        var current: DomainToken? = threadID
        while let node = current {
            if node == possibleAncestor {
                return true
            }
            current = parents[node] ?? nil
        }
        return false
    }

    private func payloadFingerprint(
        _ payload: Data
    ) throws -> InvestigationFingerprint {
        try InvestigationFingerprint(
            validating: Data(SHA256.hash(data: payload))
        )
    }

    private static let collaborationItemTypes: Set<String> = [
        "collabToolCall",
        "collabAgentToolCall",
    ]

    private static let directToolItemTypes: Set<String> = [
        "commandExecution",
        "mcpToolCall",
        "webSearch",
        "imageGeneration",
        "imageView",
    ]

    private static let nonToolItemTypes: Set<String> = [
        "agentMessage",
        "plan",
        "reasoning",
        "sleep",
        "userMessage",
    ]
}
