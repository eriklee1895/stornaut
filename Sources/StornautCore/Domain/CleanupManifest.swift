import Foundation

public enum ManifestActionResult: String, Codable, Sendable, CaseIterable {
    case succeeded
    case failed
    case partiallyFailed
    case cancelled
    case outcomeUnknown
}

public enum CleanupRecoveryState: String, Codable, Sendable, CaseIterable {
    case notStarted
    case originalConfirmed
    case movedToTrash
    case outcomeUnknown
}

public enum CleanupFailureStage: String, Codable, Sendable, CaseIterable {
    case policyPreflight
    case finalRevalidation
    case moveToTrash
    case postflight
    case persistence
    case crashRecovery
}

public struct CleanupManifestError: Codable, Sendable, Equatable {
    public let stage: CleanupFailureStage
    public let code: DomainToken

    public init(stage: CleanupFailureStage, code: DomainToken) {
        self.stage = stage
        self.code = code
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stage = try container.decode(CleanupFailureStage.self, forKey: .stage)
        code = try container.decode(DomainToken.self, forKey: .code)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case stage
        case code
    }
}

public struct CleanupManifestMeasures: Codable, Sendable, Equatable {
    public let candidateLogicalBytes: ByteCount
    public let candidateAllocatedBytes: ByteCount
    public let processedLogicalBytes: ByteCount
    public let processedAllocatedBytes: ByteCount
    public let movedToTrashLogicalBytes: ByteCount
    public let movedToTrashAllocatedBytes: ByteCount
    public let permanentlyReleasedLogicalBytes: ByteCount
    public let permanentlyReleasedAllocatedBytes: ByteCount

    public static let zero = try! CleanupManifestMeasures(
        candidateLogicalBytes: ByteCount(0)!,
        candidateAllocatedBytes: ByteCount(0)!,
        processedLogicalBytes: ByteCount(0)!,
        processedAllocatedBytes: ByteCount(0)!,
        movedToTrashLogicalBytes: ByteCount(0)!,
        movedToTrashAllocatedBytes: ByteCount(0)!,
        permanentlyReleasedLogicalBytes: ByteCount(0)!,
        permanentlyReleasedAllocatedBytes: ByteCount(0)!
    )

    public init(
        candidateLogicalBytes: ByteCount,
        candidateAllocatedBytes: ByteCount,
        processedLogicalBytes: ByteCount,
        processedAllocatedBytes: ByteCount,
        movedToTrashLogicalBytes: ByteCount,
        movedToTrashAllocatedBytes: ByteCount,
        permanentlyReleasedLogicalBytes: ByteCount,
        permanentlyReleasedAllocatedBytes: ByteCount
    ) throws {
        guard processedLogicalBytes <= candidateLogicalBytes,
              processedAllocatedBytes <= candidateAllocatedBytes,
              movedToTrashLogicalBytes <= processedLogicalBytes,
              movedToTrashAllocatedBytes <= processedAllocatedBytes,
              permanentlyReleasedLogicalBytes == ByteCount(0),
              permanentlyReleasedAllocatedBytes == ByteCount(0)
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.candidateLogicalBytes = candidateLogicalBytes
        self.candidateAllocatedBytes = candidateAllocatedBytes
        self.processedLogicalBytes = processedLogicalBytes
        self.processedAllocatedBytes = processedAllocatedBytes
        self.movedToTrashLogicalBytes = movedToTrashLogicalBytes
        self.movedToTrashAllocatedBytes = movedToTrashAllocatedBytes
        self.permanentlyReleasedLogicalBytes =
            permanentlyReleasedLogicalBytes
        self.permanentlyReleasedAllocatedBytes =
            permanentlyReleasedAllocatedBytes
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            candidateLogicalBytes: container.decode(
                ByteCount.self,
                forKey: .candidateLogicalBytes
            ),
            candidateAllocatedBytes: container.decode(
                ByteCount.self,
                forKey: .candidateAllocatedBytes
            ),
            processedLogicalBytes: container.decode(
                ByteCount.self,
                forKey: .processedLogicalBytes
            ),
            processedAllocatedBytes: container.decode(
                ByteCount.self,
                forKey: .processedAllocatedBytes
            ),
            movedToTrashLogicalBytes: container.decode(
                ByteCount.self,
                forKey: .movedToTrashLogicalBytes
            ),
            movedToTrashAllocatedBytes: container.decode(
                ByteCount.self,
                forKey: .movedToTrashAllocatedBytes
            ),
            permanentlyReleasedLogicalBytes: container.decode(
                ByteCount.self,
                forKey: .permanentlyReleasedLogicalBytes
            ),
            permanentlyReleasedAllocatedBytes: container.decode(
                ByteCount.self,
                forKey: .permanentlyReleasedAllocatedBytes
            )
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case candidateLogicalBytes
        case candidateAllocatedBytes
        case processedLogicalBytes
        case processedAllocatedBytes
        case movedToTrashLogicalBytes
        case movedToTrashAllocatedBytes
        case permanentlyReleasedLogicalBytes
        case permanentlyReleasedAllocatedBytes
    }
}

public struct CleanupManifestSummary: Codable, Sendable, Equatable {
    public let selectedLogicalBytes: ByteCount
    public let selectedAllocatedBytes: ByteCount
    public let processedLogicalBytes: ByteCount
    public let processedAllocatedBytes: ByteCount
    public let movedToTrashLogicalBytes: ByteCount
    public let movedToTrashAllocatedBytes: ByteCount
    public let permanentlyReleasedLogicalBytes: ByteCount
    public let permanentlyReleasedAllocatedBytes: ByteCount
    public let succeededCount: Int
    public let failedCount: Int
    public let cancelledCount: Int
    public let unknownCount: Int

    public init(
        selectedLogicalBytes: ByteCount,
        selectedAllocatedBytes: ByteCount,
        processedLogicalBytes: ByteCount,
        processedAllocatedBytes: ByteCount,
        movedToTrashLogicalBytes: ByteCount,
        movedToTrashAllocatedBytes: ByteCount,
        permanentlyReleasedLogicalBytes: ByteCount,
        permanentlyReleasedAllocatedBytes: ByteCount,
        succeededCount: Int,
        failedCount: Int,
        cancelledCount: Int,
        unknownCount: Int
    ) throws {
        guard succeededCount >= 0,
              failedCount >= 0,
              cancelledCount >= 0,
              unknownCount >= 0
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.selectedLogicalBytes = selectedLogicalBytes
        self.selectedAllocatedBytes = selectedAllocatedBytes
        self.processedLogicalBytes = processedLogicalBytes
        self.processedAllocatedBytes = processedAllocatedBytes
        self.movedToTrashLogicalBytes = movedToTrashLogicalBytes
        self.movedToTrashAllocatedBytes = movedToTrashAllocatedBytes
        self.permanentlyReleasedLogicalBytes =
            permanentlyReleasedLogicalBytes
        self.permanentlyReleasedAllocatedBytes =
            permanentlyReleasedAllocatedBytes
        self.succeededCount = succeededCount
        self.failedCount = failedCount
        self.cancelledCount = cancelledCount
        self.unknownCount = unknownCount
    }

    public init(records: [CleanupManifestRecord]) throws {
        var selectedLogical: UInt64 = 0
        var selectedAllocated: UInt64 = 0
        var processedLogical: UInt64 = 0
        var processedAllocated: UInt64 = 0
        var movedLogical: UInt64 = 0
        var movedAllocated: UInt64 = 0
        var permanentLogical: UInt64 = 0
        var permanentAllocated: UInt64 = 0
        var succeeded = 0
        var failed = 0
        var cancelled = 0
        var unknown = 0
        for record in records {
            selectedLogical = try Self.add(
                selectedLogical,
                record.measures.candidateLogicalBytes.value
            )
            selectedAllocated = try Self.add(
                selectedAllocated,
                record.measures.candidateAllocatedBytes.value
            )
            processedLogical = try Self.add(
                processedLogical,
                record.measures.processedLogicalBytes.value
            )
            processedAllocated = try Self.add(
                processedAllocated,
                record.measures.processedAllocatedBytes.value
            )
            movedLogical = try Self.add(
                movedLogical,
                record.measures.movedToTrashLogicalBytes.value
            )
            movedAllocated = try Self.add(
                movedAllocated,
                record.measures.movedToTrashAllocatedBytes.value
            )
            permanentLogical = try Self.add(
                permanentLogical,
                record.measures.permanentlyReleasedLogicalBytes.value
            )
            permanentAllocated = try Self.add(
                permanentAllocated,
                record.measures.permanentlyReleasedAllocatedBytes.value
            )
            switch record.result {
            case .succeeded:
                succeeded += 1
            case .failed, .partiallyFailed:
                failed += 1
            case .cancelled:
                cancelled += 1
            case .outcomeUnknown:
                unknown += 1
            }
        }
        try self.init(
            selectedLogicalBytes: Self.byteCount(selectedLogical),
            selectedAllocatedBytes: Self.byteCount(selectedAllocated),
            processedLogicalBytes: Self.byteCount(processedLogical),
            processedAllocatedBytes: Self.byteCount(processedAllocated),
            movedToTrashLogicalBytes: Self.byteCount(movedLogical),
            movedToTrashAllocatedBytes: Self.byteCount(movedAllocated),
            permanentlyReleasedLogicalBytes: Self.byteCount(permanentLogical),
            permanentlyReleasedAllocatedBytes: Self.byteCount(permanentAllocated),
            succeededCount: succeeded,
            failedCount: failed,
            cancelledCount: cancelled,
            unknownCount: unknown
        )
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            selectedLogicalBytes: container.decode(
                ByteCount.self,
                forKey: .selectedLogicalBytes
            ),
            selectedAllocatedBytes: container.decode(
                ByteCount.self,
                forKey: .selectedAllocatedBytes
            ),
            processedLogicalBytes: container.decode(
                ByteCount.self,
                forKey: .processedLogicalBytes
            ),
            processedAllocatedBytes: container.decode(
                ByteCount.self,
                forKey: .processedAllocatedBytes
            ),
            movedToTrashLogicalBytes: container.decode(
                ByteCount.self,
                forKey: .movedToTrashLogicalBytes
            ),
            movedToTrashAllocatedBytes: container.decode(
                ByteCount.self,
                forKey: .movedToTrashAllocatedBytes
            ),
            permanentlyReleasedLogicalBytes: container.decode(
                ByteCount.self,
                forKey: .permanentlyReleasedLogicalBytes
            ),
            permanentlyReleasedAllocatedBytes: container.decode(
                ByteCount.self,
                forKey: .permanentlyReleasedAllocatedBytes
            ),
            succeededCount: container.decode(
                Int.self,
                forKey: .succeededCount
            ),
            failedCount: container.decode(Int.self, forKey: .failedCount),
            cancelledCount: container.decode(
                Int.self,
                forKey: .cancelledCount
            ),
            unknownCount: container.decode(Int.self, forKey: .unknownCount)
        )
    }

    private static func add(_ first: UInt64, _ second: UInt64) throws -> UInt64 {
        let result = first.addingReportingOverflow(second)
        guard !result.overflow,
              result.partialValue <= UInt64(Int64.max)
        else {
            throw DomainContractError.invalidMeasurement
        }
        return result.partialValue
    }

    private static func byteCount(_ value: UInt64) throws -> ByteCount {
        guard let value = ByteCount(value) else {
            throw DomainContractError.invalidMeasurement
        }
        return value
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case selectedLogicalBytes
        case selectedAllocatedBytes
        case processedLogicalBytes
        case processedAllocatedBytes
        case movedToTrashLogicalBytes
        case movedToTrashAllocatedBytes
        case permanentlyReleasedLogicalBytes
        case permanentlyReleasedAllocatedBytes
        case succeededCount
        case failedCount
        case cancelledCount
        case unknownCount
    }
}

public struct ManifestSystemObservation: Codable, Sendable, Equatable {
    public let source: DomainToken
    public let freeBytesBefore: ByteCount
    public let sampledBeforeAt: Date
    public let freeBytesAfter: ByteCount
    public let sampledAfterAt: Date
    public let freeSpaceDelta: SignedByteDelta
    public let unexplainedDelta: SignedByteDelta?

    public init(
        source: DomainToken,
        freeBytesBefore: ByteCount,
        sampledBeforeAt: Date,
        freeBytesAfter: ByteCount,
        sampledAfterAt: Date,
        freeSpaceDelta: SignedByteDelta,
        unexplainedDelta: SignedByteDelta?
    ) throws {
        let expectedDelta = Int64(freeBytesAfter.value)
            - Int64(freeBytesBefore.value)
        guard sampledAfterAt >= sampledBeforeAt,
              freeSpaceDelta.value == expectedDelta,
              unexplainedDelta == nil
                || unexplainedDelta == freeSpaceDelta
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.source = source
        self.freeBytesBefore = freeBytesBefore
        self.sampledBeforeAt = sampledBeforeAt
        self.freeBytesAfter = freeBytesAfter
        self.sampledAfterAt = sampledAfterAt
        self.freeSpaceDelta = freeSpaceDelta
        self.unexplainedDelta = unexplainedDelta
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            source: container.decode(DomainToken.self, forKey: .source),
            freeBytesBefore: container.decode(
                ByteCount.self,
                forKey: .freeBytesBefore
            ),
            sampledBeforeAt: container.decode(
                Date.self,
                forKey: .sampledBeforeAt
            ),
            freeBytesAfter: container.decode(
                ByteCount.self,
                forKey: .freeBytesAfter
            ),
            sampledAfterAt: container.decode(
                Date.self,
                forKey: .sampledAfterAt
            ),
            freeSpaceDelta: container.decode(
                SignedByteDelta.self,
                forKey: .freeSpaceDelta
            ),
            unexplainedDelta: container.decodeIfPresent(
                SignedByteDelta.self,
                forKey: .unexplainedDelta
            )
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case source
        case freeBytesBefore
        case sampledBeforeAt
        case freeBytesAfter
        case sampledAfterAt
        case freeSpaceDelta
        case unexplainedDelta
    }
}

public struct CleanupManifestRecord: Codable, Sendable, Equatable {
    public let actionID: CleanupActionID
    public let planItemID: CleanupPlanItemID
    public let policyDecisionID: PolicyDecisionID?
    public let policyDisposition: ReclaimDisposition
    public let policyReasonKeys: [DomainToken]
    public let action: ProposedCleanupAction
    public let result: ManifestActionResult
    public let recovery: CleanupRecoveryState
    public let measures: CleanupManifestMeasures
    public let startedAt: Date?
    public let finishedAt: Date?
    public let error: CleanupManifestError?

    public var logicalBytesBefore: ByteCount {
        measures.candidateLogicalBytes
    }

    public var allocatedBytesBefore: ByteCount {
        measures.candidateAllocatedBytes
    }

    public var logicalBytesAfter: ByteCount? {
        recovery == .movedToTrash ? ByteCount(0) : nil
    }

    public var allocatedBytesAfter: ByteCount? {
        recovery == .movedToTrash ? ByteCount(0) : nil
    }

    public var logicalBytesProcessed: ByteCount {
        measures.processedLogicalBytes
    }

    public var allocatedBytesProcessed: ByteCount {
        measures.processedAllocatedBytes
    }

    public var errorCode: DomainToken? {
        error?.code
    }

    public init(
        actionID: CleanupActionID,
        planItemID: CleanupPlanItemID,
        policyDecisionID: PolicyDecisionID,
        policyDisposition: ReclaimDisposition,
        policyReasonKeys: [DomainToken],
        action: ProposedCleanupAction,
        result: ManifestActionResult,
        recovery: CleanupRecoveryState,
        measures: CleanupManifestMeasures,
        startedAt: Date?,
        finishedAt: Date?,
        error: CleanupManifestError?
    ) throws {
        let executableDisposition =
            policyDisposition == .readyToReclaim
                || policyDisposition == .reviewRecommended
        let knownDeniedBeforeWrite = result == .failed
            && recovery == .notStarted
            && startedAt == nil
        guard executableDisposition || knownDeniedBeforeWrite,
              !policyReasonKeys.isEmpty,
              policyReasonKeys.count <= 32,
              Set(policyReasonKeys).count == policyReasonKeys.count,
              action == .moveToTrash,
              Self.validResult(
                  result,
                  recovery: recovery,
                  measures: measures,
                  startedAt: startedAt,
                  finishedAt: finishedAt,
                  error: error
              )
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.actionID = actionID
        self.planItemID = planItemID
        self.policyDecisionID = policyDecisionID
        self.policyDisposition = policyDisposition
        self.policyReasonKeys = policyReasonKeys
        self.action = action
        self.result = result
        self.recovery = recovery
        self.measures = measures
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.error = error
    }

    private init(
        legacyActionID actionID: CleanupActionID,
        planItemID: CleanupPlanItemID,
        policyDisposition: ReclaimDisposition,
        action: ProposedCleanupAction,
        result: ManifestActionResult,
        logicalBytesBefore: ByteCount,
        allocatedBytesBefore: ByteCount,
        logicalBytesAfter: ByteCount?,
        allocatedBytesAfter: ByteCount?,
        logicalBytesProcessed: ByteCount,
        allocatedBytesProcessed: ByteCount,
        startedAt: Date,
        finishedAt: Date,
        errorCode: DomainToken?
    ) throws {
        let executableDisposition =
            policyDisposition == .readyToReclaim
                || policyDisposition == .reviewRecommended
        let errorMatchesResult: Bool
        switch result {
        case .succeeded:
            errorMatchesResult = errorCode == nil
        case .failed, .partiallyFailed, .outcomeUnknown:
            errorMatchesResult = errorCode != nil
        case .cancelled:
            errorMatchesResult = true
        }
        guard finishedAt >= startedAt,
              executableDisposition,
              errorMatchesResult,
              (logicalBytesAfter == nil) == (allocatedBytesAfter == nil),
              result != .succeeded || logicalBytesAfter != nil
        else {
            throw DomainContractError.invalidMeasurement
        }
        let movedLogical = result == .succeeded
            ? logicalBytesProcessed
            : ByteCount(0)!
        let movedAllocated = result == .succeeded
            ? allocatedBytesProcessed
            : ByteCount(0)!
        self.actionID = actionID
        self.planItemID = planItemID
        policyDecisionID = nil
        self.policyDisposition = policyDisposition
        policyReasonKeys = []
        self.action = action
        self.result = result
        recovery = result == .succeeded
            ? .movedToTrash
            : (result == .cancelled ? .notStarted : .outcomeUnknown)
        measures = try CleanupManifestMeasures(
            candidateLogicalBytes: logicalBytesBefore,
            candidateAllocatedBytes: allocatedBytesBefore,
            processedLogicalBytes: logicalBytesProcessed,
            processedAllocatedBytes: allocatedBytesProcessed,
            movedToTrashLogicalBytes: movedLogical,
            movedToTrashAllocatedBytes: movedAllocated,
            permanentlyReleasedLogicalBytes: ByteCount(0)!,
            permanentlyReleasedAllocatedBytes: ByteCount(0)!
        )
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        error = errorCode.map {
            CleanupManifestError(stage: .moveToTrash, code: $0)
        }
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.measures) {
            try self.init(
                actionID: container.decode(
                    CleanupActionID.self,
                    forKey: .actionID
                ),
                planItemID: container.decode(
                    CleanupPlanItemID.self,
                    forKey: .planItemID
                ),
                policyDecisionID: container.decode(
                    PolicyDecisionID.self,
                    forKey: .policyDecisionID
                ),
                policyDisposition: container.decode(
                    ReclaimDisposition.self,
                    forKey: .policyDisposition
                ),
                policyReasonKeys: container.decode(
                    [DomainToken].self,
                    forKey: .policyReasonKeys
                ),
                action: container.decode(
                    ProposedCleanupAction.self,
                    forKey: .action
                ),
                result: container.decode(
                    ManifestActionResult.self,
                    forKey: .result
                ),
                recovery: container.decode(
                    CleanupRecoveryState.self,
                    forKey: .recovery
                ),
                measures: container.decode(
                    CleanupManifestMeasures.self,
                    forKey: .measures
                ),
                startedAt: container.decodeIfPresent(
                    Date.self,
                    forKey: .startedAt
                ),
                finishedAt: container.decodeIfPresent(
                    Date.self,
                    forKey: .finishedAt
                ),
                error: container.decodeIfPresent(
                    CleanupManifestError.self,
                    forKey: .error
                )
            )
        } else {
            try self.init(
                legacyActionID: container.decode(
                    CleanupActionID.self,
                    forKey: .actionID
                ),
                planItemID: container.decode(
                    CleanupPlanItemID.self,
                    forKey: .planItemID
                ),
                policyDisposition: container.decode(
                    ReclaimDisposition.self,
                    forKey: .policyDisposition
                ),
                action: container.decode(
                    ProposedCleanupAction.self,
                    forKey: .action
                ),
                result: container.decode(
                    ManifestActionResult.self,
                    forKey: .result
                ),
                logicalBytesBefore: container.decode(
                    ByteCount.self,
                    forKey: .logicalBytesBefore
                ),
                allocatedBytesBefore: container.decode(
                    ByteCount.self,
                    forKey: .allocatedBytesBefore
                ),
                logicalBytesAfter: container.decodeIfPresent(
                    ByteCount.self,
                    forKey: .logicalBytesAfter
                ),
                allocatedBytesAfter: container.decodeIfPresent(
                    ByteCount.self,
                    forKey: .allocatedBytesAfter
                ),
                logicalBytesProcessed: container.decode(
                    ByteCount.self,
                    forKey: .logicalBytesProcessed
                ),
                allocatedBytesProcessed: container.decode(
                    ByteCount.self,
                    forKey: .allocatedBytesProcessed
                ),
                startedAt: container.decode(Date.self, forKey: .startedAt),
                finishedAt: container.decode(Date.self, forKey: .finishedAt),
                errorCode: container.decodeIfPresent(
                    DomainToken.self,
                    forKey: .errorCode
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(actionID, forKey: .actionID)
        try container.encode(planItemID, forKey: .planItemID)
        try container.encode(policyDisposition, forKey: .policyDisposition)
        try container.encode(action, forKey: .action)
        try container.encode(result, forKey: .result)
        if let policyDecisionID {
            try container.encode(policyDecisionID, forKey: .policyDecisionID)
            try container.encode(policyReasonKeys, forKey: .policyReasonKeys)
            try container.encode(recovery, forKey: .recovery)
            try container.encode(measures, forKey: .measures)
            try container.encodeIfPresent(startedAt, forKey: .startedAt)
            try container.encodeIfPresent(finishedAt, forKey: .finishedAt)
            try container.encodeIfPresent(error, forKey: .error)
        } else {
            try container.encode(
                measures.candidateLogicalBytes,
                forKey: .logicalBytesBefore
            )
            try container.encode(
                measures.candidateAllocatedBytes,
                forKey: .allocatedBytesBefore
            )
            try container.encodeIfPresent(
                logicalBytesAfter,
                forKey: .logicalBytesAfter
            )
            try container.encodeIfPresent(
                allocatedBytesAfter,
                forKey: .allocatedBytesAfter
            )
            try container.encode(
                measures.processedLogicalBytes,
                forKey: .logicalBytesProcessed
            )
            try container.encode(
                measures.processedAllocatedBytes,
                forKey: .allocatedBytesProcessed
            )
            try container.encode(startedAt, forKey: .startedAt)
            try container.encode(finishedAt, forKey: .finishedAt)
            try container.encodeIfPresent(error?.code, forKey: .errorCode)
        }
    }

    private static func validResult(
        _ result: ManifestActionResult,
        recovery: CleanupRecoveryState,
        measures: CleanupManifestMeasures,
        startedAt: Date?,
        finishedAt: Date?,
        error: CleanupManifestError?
    ) -> Bool {
        if let startedAt, let finishedAt, finishedAt < startedAt {
            return false
        }
        switch result {
        case .succeeded:
            return recovery == .movedToTrash
                && startedAt != nil
                && finishedAt != nil
                && error == nil
                && measures.processedLogicalBytes
                    == measures.candidateLogicalBytes
                && measures.processedAllocatedBytes
                    == measures.candidateAllocatedBytes
                && measures.movedToTrashLogicalBytes
                    == measures.processedLogicalBytes
                && measures.movedToTrashAllocatedBytes
                    == measures.processedAllocatedBytes
        case .failed:
            return (recovery == .originalConfirmed
                || recovery == .notStarted)
                && finishedAt != nil
                && error != nil
                && measures.movedToTrashLogicalBytes == ByteCount(0)
                && measures.movedToTrashAllocatedBytes == ByteCount(0)
        case .partiallyFailed:
            return recovery == .movedToTrash
                && startedAt != nil
                && finishedAt != nil
                && error != nil
        case .cancelled:
            return recovery == .notStarted
                && startedAt == nil
                && finishedAt == nil
                && error == nil
                && measures.processedLogicalBytes == ByteCount(0)
                && measures.processedAllocatedBytes == ByteCount(0)
        case .outcomeUnknown:
            return recovery == .outcomeUnknown
                && startedAt != nil
                && finishedAt != nil
                && error != nil
                && measures.movedToTrashLogicalBytes == ByteCount(0)
                && measures.movedToTrashAllocatedBytes == ByteCount(0)
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case actionID
        case planItemID
        case policyDecisionID
        case policyDisposition
        case policyReasonKeys
        case action
        case result
        case recovery
        case measures
        case startedAt
        case finishedAt
        case error
        case logicalBytesBefore
        case allocatedBytesBefore
        case logicalBytesAfter
        case allocatedBytesAfter
        case logicalBytesProcessed
        case allocatedBytesProcessed
        case errorCode
    }
}

public struct CleanupManifest: Codable, Sendable, Equatable {
    public let schemaVersion: DomainSchemaVersion
    public let compatibility: CleanupCompatibility
    public let id: CleanupManifestID
    public let planID: CleanupPlanID
    public let createdAt: Date
    public let expiresAt: Date
    public let records: [CleanupManifestRecord]
    public let summary: CleanupManifestSummary
    public let systemObservation: ManifestSystemObservation?

    public init(
        id: CleanupManifestID,
        planID: CleanupPlanID,
        createdAt: Date,
        expiresAt: Date,
        records: [CleanupManifestRecord],
        summary: CleanupManifestSummary,
        systemObservation: ManifestSystemObservation?
    ) throws {
        let expectedSummary = try CleanupManifestSummary(records: records)
        guard expiresAt >= createdAt,
              !records.isEmpty,
              records.count <= 100,
              Set(records.map(\.actionID)).count == records.count,
              Set(records.map(\.planItemID)).count == records.count,
              records.allSatisfy({
                  $0.policyDecisionID != nil
                      && !$0.policyReasonKeys.isEmpty
              }),
              summary == expectedSummary
        else {
            throw DomainContractError.invalidMeasurement
        }
        schemaVersion = .v2
        compatibility = .current
        self.id = id
        self.planID = planID
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.records = records
        self.summary = summary
        self.systemObservation = systemObservation
    }

    private init(
        legacyID id: CleanupManifestID,
        planID: CleanupPlanID,
        createdAt: Date,
        expiresAt: Date,
        records: [CleanupManifestRecord],
        systemObservation: ManifestSystemObservation?
    ) throws {
        guard expiresAt >= createdAt,
              Set(records.map(\.actionID)).count == records.count
        else {
            throw DomainContractError.invalidMeasurement
        }
        schemaVersion = .v2
        compatibility = .legacyV1
        self.id = id
        self.planID = planID
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.records = records
        summary = try CleanupManifestSummary(records: records)
        self.systemObservation = systemObservation
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let persistedVersion = try container.decode(
            DomainSchemaVersion.self,
            forKey: .schemaVersion
        )
        let compatibility = try container.decodeIfPresent(
            CleanupCompatibility.self,
            forKey: .compatibility
        ) ?? (persistedVersion == .v1 ? .legacyV1 : .current)
        switch (persistedVersion, compatibility) {
        case (.v1, .legacyV1), (.v2, .legacyV1):
            let legacyObservation = try container.decodeIfPresent(
                LegacyManifestSystemObservation.self,
                forKey: .systemObservation
            )
            try self.init(
                legacyID: container.decode(
                    CleanupManifestID.self,
                    forKey: .id
                ),
                planID: container.decode(CleanupPlanID.self, forKey: .planID),
                createdAt: container.decode(Date.self, forKey: .createdAt),
                expiresAt: container.decode(Date.self, forKey: .expiresAt),
                records: container.decode(
                    [CleanupManifestRecord].self,
                    forKey: .records
                ),
                systemObservation: try legacyObservation.map {
                    try $0.projection()
                }
            )
        case (.v2, .current):
            try self.init(
                id: container.decode(CleanupManifestID.self, forKey: .id),
                planID: container.decode(CleanupPlanID.self, forKey: .planID),
                createdAt: container.decode(Date.self, forKey: .createdAt),
                expiresAt: container.decode(Date.self, forKey: .expiresAt),
                records: container.decode(
                    [CleanupManifestRecord].self,
                    forKey: .records
                ),
                summary: container.decode(
                    CleanupManifestSummary.self,
                    forKey: .summary
                ),
                systemObservation: container.decodeIfPresent(
                    ManifestSystemObservation.self,
                    forKey: .systemObservation
                )
            )
        case (.v1, .current):
            throw DomainContractError.unsupportedSchemaVersion(
                expected: .v2,
                actual: .v1
            )
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case compatibility
        case id
        case planID
        case createdAt
        case expiresAt
        case records
        case summary
        case systemObservation
    }
}

private struct LegacyManifestSystemObservation: Decodable {
    let source: DomainToken
    let freeBytesBefore: ByteCount
    let sampledBeforeAt: Date
    let freeBytesAfter: ByteCount
    let sampledAfterAt: Date
    let freeSpaceDelta: SignedByteDelta
    let unexplainedDelta: SignedByteDelta?

    init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try container.decode(DomainToken.self, forKey: .source)
        freeBytesBefore = try container.decode(
            ByteCount.self,
            forKey: .freeBytesBefore
        )
        sampledBeforeAt = try container.decode(
            Date.self,
            forKey: .sampledBeforeAt
        )
        freeBytesAfter = try container.decode(
            ByteCount.self,
            forKey: .freeBytesAfter
        )
        sampledAfterAt = try container.decode(
            Date.self,
            forKey: .sampledAfterAt
        )
        freeSpaceDelta = try container.decode(
            SignedByteDelta.self,
            forKey: .freeSpaceDelta
        )
        unexplainedDelta = try container.decodeIfPresent(
            SignedByteDelta.self,
            forKey: .unexplainedDelta
        )
    }

    func projection() throws -> ManifestSystemObservation {
        try ManifestSystemObservation(
            source: source,
            freeBytesBefore: freeBytesBefore,
            sampledBeforeAt: sampledBeforeAt,
            freeBytesAfter: freeBytesAfter,
            sampledAfterAt: sampledAfterAt,
            freeSpaceDelta: freeSpaceDelta,
            unexplainedDelta:
                unexplainedDelta == freeSpaceDelta
                    ? unexplainedDelta
                    : nil
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case source
        case freeBytesBefore
        case sampledBeforeAt
        case freeBytesAfter
        case sampledAfterAt
        case freeSpaceDelta
        case unexplainedDelta
    }
}
