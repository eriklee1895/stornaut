import Foundation

struct SpaceLedgerOwnerInput: Sendable {
    let snapshot: PathSnapshot
    let classification: Classification
}

struct IncrementalSpaceLedger {
    private struct OwnerAccumulator {
        let classification: Classification
        let snapshot: PathSnapshot
        var logical: UInt64 = 0
        var allocated: UInt64 = 0
        var latestObservedAt: Date
        var hasMeasuredEntry = false
    }

    private struct FileLedgerIdentity: Hashable {
        let device: UInt64
        let inode: UInt64
    }

    private enum OwnerBucket: Hashable {
        case owner(SnapshotID)
        case unclassified
    }

    private struct HardLinkGroup {
        let logical: UInt64
        let allocated: UInt64
        var latestObservedAt: Date
        var buckets: Set<OwnerBucket>
        var pathCount: Int
    }

    private let startBaseline: VolumeBaseline
    private let endBaseline: VolumeBaseline
    private let groupAllRegularFiles: Bool
    private let ownerIDByPath: [String: SnapshotID]
    private var owners: [SnapshotID: OwnerAccumulator]
    private var gaps: [SpaceLedgerCoverageGap] = []
    private var hardLinks: [FileLedgerIdentity: HardLinkGroup] = [:]
    private var observedUnclassified: UInt64 = 0
    private var observedUnclassifiedLogical: UInt64 = 0
    private var latestObservedAt: Date?
    private var sparseObserved = false
    private var hardLinkDeduplicated = false
    private var hardLinkOwnershipAmbiguous = false
    private var lastRelativePath: String?

    init(
        startBaseline: VolumeBaseline,
        endBaseline: VolumeBaseline,
        ownerInputs: [SpaceLedgerOwnerInput],
        groupAllRegularFiles: Bool = false
    ) throws {
        try Self.validateBaselines(
            start: startBaseline,
            end: endBaseline
        )
        var classificationIDs = Set<ClassificationID>()
        var snapshotIDs = Set<SnapshotID>()
        var ownerPaths: [String: SnapshotID] = [:]
        var accumulators: [SnapshotID: OwnerAccumulator] = [:]
        for input in ownerInputs {
            let snapshot = input.snapshot
            let classification = input.classification
            guard snapshot.sessionID == endBaseline.sessionID,
                  snapshot.scopeID == endBaseline.scopeID,
                  classification.snapshotID == snapshot.id,
                  classificationIDs.insert(classification.id).inserted,
                  snapshotIDs.insert(snapshot.id).inserted,
                  ownerPaths.updateValue(
                      snapshot.id,
                      forKey: snapshot.relativePath
                  ) == nil
            else {
                throw SpaceLedgerError.duplicateClassification
            }
            accumulators[snapshot.id] = OwnerAccumulator(
                classification: classification,
                snapshot: snapshot,
                latestObservedAt: snapshot.observedAt
            )
        }
        self.startBaseline = startBaseline
        self.endBaseline = endBaseline
        self.groupAllRegularFiles = groupAllRegularFiles
        ownerIDByPath = ownerPaths
        owners = accumulators
    }

    mutating func consume(_ snapshots: [PathSnapshot]) throws {
        for snapshot in snapshots {
            guard snapshot.sessionID == endBaseline.sessionID,
                  snapshot.scopeID == endBaseline.scopeID
            else {
                throw SpaceLedgerError.snapshotScopeMismatch
            }
            if let lastRelativePath {
                guard lastRelativePath < snapshot.relativePath else {
                    throw lastRelativePath == snapshot.relativePath
                        ? SpaceLedgerError.duplicatePath
                        : SpaceLedgerError.snapshotScopeMismatch
                }
            }
            lastRelativePath = snapshot.relativePath
            latestObservedAt = max(
                latestObservedAt ?? snapshot.observedAt,
                snapshot.observedAt
            )
            if snapshot.measurementStatus != .measured {
                gaps.append(
                    try SpaceLedgerCoverageGap(
                        snapshotID: snapshot.id,
                        relativePath: try PersistedPath(
                            validating: snapshot.relativePath
                        ),
                        status: snapshot.measurementStatus,
                        observedAt: snapshot.observedAt,
                        includedInUnknownResidual:
                            snapshot.measurementStatus != .mountBoundary
                    )
                )
                continue
            }
            guard let logical = snapshot.logicalByteCount?.value,
                  let allocated = snapshot.allocatedByteCount?.value
            else {
                continue
            }
            if let identity = snapshot.fileIdentity,
               identity.device != endBaseline.rootIdentity.device
            {
                throw SpaceLedgerError.snapshotScopeMismatch
            }
            let ownerID = nearestOwner(for: snapshot.relativePath)
            if snapshot.kind == .regularFile {
                if logical > allocated {
                    sparseObserved = true
                }
                if let identity = snapshot.fileIdentity,
                   groupAllRegularFiles
                    || identity.linkCount == 0
                    || identity.linkCount > 1
                {
                    try recordHardLink(
                        identity: identity,
                        logical: logical,
                        allocated: allocated,
                        observedAt: snapshot.observedAt,
                        ownerID: ownerID
                    )
                    continue
                }
            }
            try accumulate(
                logical: logical,
                allocated: allocated,
                observedAt: snapshot.observedAt,
                ownerID: ownerID
            )
        }
    }

    mutating func finish() throws -> SpaceLedger {
        for group in hardLinks.values {
            if group.pathCount > 1 {
                hardLinkDeduplicated = true
            }
            let ownerID: SnapshotID?
            if group.buckets.count > 1 {
                hardLinkOwnershipAmbiguous = true
                ownerID = nil
            } else {
                ownerID = group.buckets.first.flatMap {
                    if case let .owner(value) = $0 {
                        return value
                    }
                    return nil
                }
            }
            try accumulate(
                logical: group.logical,
                allocated: group.allocated,
                observedAt: group.latestObservedAt,
                ownerID: ownerID
            )
        }
        let projectedOwners = try owners.values.sorted {
            $0.snapshot.relativePath < $1.snapshot.relativePath
        }.map { owner in
            try SpaceLedgerOwner(
                classificationID: owner.classification.id,
                snapshotID: owner.snapshot.id,
                relativePath: try PersistedPath(
                    validating: owner.snapshot.relativePath
                ),
                category: owner.classification.category,
                disposition: owner.classification.disposition,
                logicalBytes: owner.hasMeasuredEntry
                    ? ByteCount(owner.logical)
                    : nil,
                allocatedBytes: owner.hasMeasuredEntry
                    ? ByteCount(owner.allocated)
                    : nil,
                sources: [
                    AccountingSource(
                        kind: .surveyor,
                        identifier: try token("space-ledger.surveyor"),
                        sampledAt: owner.latestObservedAt
                    ),
                    AccountingSource(
                        kind: .classifier,
                        identifier: owner.classification.catalogVersion,
                        sampledAt: owner.classification.classifiedAt
                    ),
                ]
            )
        }
        let knownOwners = projectedOwners.filter {
            $0.category != .unknownLargeConsumers
        }
        let knownAllocated = try sum(
            knownOwners.compactMap { $0.allocatedBytes?.value }
        )
        let knownLogical = try sum(
            knownOwners.compactMap { $0.logicalBytes?.value }
        )
        return try makeLedger(
            owners: projectedOwners,
            knownOwners: knownOwners,
            knownAllocated: knownAllocated,
            knownLogical: knownLogical
        )
    }

    mutating func consumePreaggregated(
        ownerID: SnapshotID?,
        logical: UInt64,
        allocated: UInt64,
        observedAt: Date
    ) throws {
        latestObservedAt = max(
            latestObservedAt ?? observedAt,
            observedAt
        )
        try accumulate(
            logical: logical,
            allocated: allocated,
            observedAt: observedAt,
            ownerID: ownerID
        )
    }

    mutating func consumePreaggregatedGap(
        _ snapshot: PathSnapshot
    ) throws {
        guard snapshot.measurementStatus != .measured else {
            throw DomainContractError.invalidMeasurement
        }
        latestObservedAt = max(
            latestObservedAt ?? snapshot.observedAt,
            snapshot.observedAt
        )
        gaps.append(
            try SpaceLedgerCoverageGap(
                snapshotID: snapshot.id,
                relativePath: try PersistedPath(
                    validating: snapshot.relativePath
                ),
                status: snapshot.measurementStatus,
                observedAt: snapshot.observedAt,
                includedInUnknownResidual:
                    snapshot.measurementStatus != .mountBoundary
            )
        )
    }

    mutating func recordPreaggregatedCaveats(
        sparse: Bool,
        hardLinkDeduplicated: Bool,
        hardLinkOwnershipAmbiguous: Bool
    ) {
        sparseObserved = sparseObserved || sparse
        self.hardLinkDeduplicated =
            self.hardLinkDeduplicated || hardLinkDeduplicated
        self.hardLinkOwnershipAmbiguous =
            self.hardLinkOwnershipAmbiguous
                || hardLinkOwnershipAmbiguous
    }
}

private extension IncrementalSpaceLedger {
    static func validateBaselines(
        start: VolumeBaseline,
        end: VolumeBaseline
    ) throws {
        guard start.sessionID == end.sessionID,
              start.scopeID == end.scopeID,
              start.rootPath == end.rootPath,
              start.rootIdentity.device == end.rootIdentity.device,
              start.rootIdentity.inode == end.rootIdentity.inode,
              start.rootIdentity.isDirectory,
              end.rootIdentity.isDirectory,
              start.source.sampledAt <= end.source.sampledAt
        else {
            throw SpaceLedgerError.baselineMismatch
        }
    }

    mutating func recordHardLink(
        identity: FileIdentity,
        logical: UInt64,
        allocated: UInt64,
        observedAt: Date,
        ownerID: SnapshotID?
    ) throws {
        let key = FileLedgerIdentity(
            device: identity.device,
            inode: identity.inode
        )
        let bucket = ownerID.map(OwnerBucket.owner) ?? .unclassified
        if var existing = hardLinks[key] {
            guard existing.logical == logical,
                  existing.allocated == allocated
            else {
                throw SpaceLedgerError.hardLinkMetadataMismatch
            }
            existing.latestObservedAt = max(
                existing.latestObservedAt,
                observedAt
            )
            existing.buckets.insert(bucket)
            existing.pathCount += 1
            hardLinks[key] = existing
        } else {
            hardLinks[key] = HardLinkGroup(
                logical: logical,
                allocated: allocated,
                latestObservedAt: observedAt,
                buckets: [bucket],
                pathCount: 1
            )
        }
    }

    mutating func accumulate(
        logical: UInt64,
        allocated: UInt64,
        observedAt: Date,
        ownerID: SnapshotID?
    ) throws {
        if let ownerID {
            guard var owner = owners[ownerID] else {
                throw SpaceLedgerError.classificationTargetMissing
            }
            owner.logical = try checkedAdd(owner.logical, logical)
            owner.allocated = try checkedAdd(owner.allocated, allocated)
            owner.latestObservedAt = max(
                owner.latestObservedAt,
                observedAt
            )
            owner.hasMeasuredEntry = true
            owners[ownerID] = owner
        } else {
            observedUnclassified = try checkedAdd(
                observedUnclassified,
                allocated
            )
            observedUnclassifiedLogical = try checkedAdd(
                observedUnclassifiedLogical,
                logical
            )
        }
    }

    func nearestOwner(for relativePath: String) -> SnapshotID? {
        var path: String? = relativePath
        while let current = path {
            if let owner = ownerIDByPath[current] {
                return owner
            }
            path = parentPath(current)
        }
        return nil
    }

    func parentPath(_ path: String) -> String? {
        guard path != "." else {
            return nil
        }
        guard let slash = path.lastIndex(of: "/") else {
            return "."
        }
        return String(path[..<slash])
    }

    func makeLedger(
        owners: [SpaceLedgerOwner],
        knownOwners: [SpaceLedgerOwner],
        knownAllocated: UInt64,
        knownLogical: UInt64
    ) throws -> SpaceLedger {
        let startSource = startBaseline.source
        let endSource = endBaseline.source
        let surveyor = AccountingSource(
            kind: .surveyor,
            identifier: try token("space-ledger.surveyor"),
            sampledAt: latestObservedAt ?? endSource.sampledAt
        )
        let knownSources = knownOwners.isEmpty
            ? [surveyor]
            : uniqueSources(knownOwners.flatMap(\.sources))
        let volumeCapacityAtStart = try measure(
            value: startBaseline.totalCapacity,
            unknownStatus: .unknown,
            sources: [startSource],
            formula: "accounting.formula.volumeCapacityAtStart",
            explanation: "accounting.volume.startCapacity"
        )
        let volumeCapacity = try measure(
            value: endBaseline.totalCapacity,
            unknownStatus: .unknown,
            sources: [endSource],
            formula: "accounting.formula.volumeCapacity",
            explanation: "accounting.volume.capacity"
        )
        let freeAtStart = try measure(
            value: startBaseline.availableCapacity,
            unknownStatus: .unknown,
            sources: [startSource],
            formula: "accounting.formula.freeAtStart",
            explanation: "accounting.free.startSystemObservation"
        )
        let free = try measure(
            value: endBaseline.availableCapacity,
            unknownStatus: .unknown,
            sources: [endSource],
            formula: "accounting.formula.free",
            explanation: "accounting.free.systemObservation"
        )
        let known = try SpaceLedgerMeasure(
            status: .measured,
            bytes: try byteCount(knownAllocated),
            sources: knownSources,
            formulaKey: try token("accounting.formula.knownOwners"),
            explanationKey: try token("accounting.known.classifiedOwners")
        )
        let knownLogicalMeasure = try SpaceLedgerMeasure(
            status: .measured,
            bytes: try byteCount(knownLogical),
            sources: knownSources,
            formulaKey: try token("accounting.formula.knownLogicalOwners"),
            explanationKey: try token("accounting.known.logicalOwners")
        )
        let unclassified = try SpaceLedgerMeasure(
            status: .measured,
            bytes: try byteCount(observedUnclassified),
            sources: [surveyor],
            formulaKey: try token(
                "accounting.formula.observedUnclassified"
            ),
            explanationKey: try token(
                "accounting.unknown.observedUnclassified"
            )
        )
        let unclassifiedLogical = try SpaceLedgerMeasure(
            status: .measured,
            bytes: try byteCount(observedUnclassifiedLogical),
            sources: [surveyor],
            formulaKey: try token(
                "accounting.formula.observedUnclassifiedLogical"
            ),
            explanationKey: try token(
                "accounting.unknown.observedUnclassifiedLogical"
            )
        )
        let unmeasurable: SpaceLedgerMeasure
        if gaps.isEmpty {
            unmeasurable = try SpaceLedgerMeasure(
                status: .measured,
                bytes: ByteCount(0),
                sources: [surveyor],
                formulaKey: try token("accounting.formula.noCoverageGaps"),
                explanationKey: try token("accounting.unmeasurable.none")
            )
        } else {
            unmeasurable = try SpaceLedgerMeasure(
                status: .unmeasurable,
                bytes: nil,
                sources: [
                    AccountingSource(
                        kind: .permissionGap,
                        identifier: try token("space-ledger.coverage-gaps"),
                        sampledAt: gaps.map(\.observedAt).max()
                            ?? endSource.sampledAt
                    ),
                ],
                formulaKey: try token(
                    "accounting.formula.coverageGapUnavailable"
                ),
                explanationKey: try token(
                    "accounting.unmeasurable.permissionOrBoundary"
                )
            )
        }
        var caveats: [SpaceLedgerCaveat] = [
            .cloneAndCompressionNotAttributed,
            .purgeableNotEstimated,
        ]
        if sparseObserved {
            caveats.append(.sparseFileObserved)
        }
        if hardLinkDeduplicated {
            caveats.append(.hardLinkDeduplicated)
        }
        if hardLinkOwnershipAmbiguous {
            caveats.append(.hardLinkOwnershipAmbiguous)
        }
        let freeDelta = signedDelta(
            from: startBaseline.availableCapacity,
            to: endBaseline.availableCapacity
        )
        if freeDelta?.value != 0
            || startBaseline.totalCapacity != endBaseline.totalCapacity
        {
            caveats.append(.volumeChangedDuringScan)
        }
        let residualGapExists = gaps.contains {
            $0.includedInUnknownResidual
        }
        let unknown: SpaceLedgerMeasure
        var status: SpaceLedgerStatus = gaps.isEmpty ? .reconciled : .partial
        if let total = endBaseline.totalCapacity,
           let available = endBaseline.availableCapacity
        {
            let used = total.value - available.value
            if knownAllocated > used {
                status = .inconsistent
                caveats.append(.knownExceedsVolumeUsed)
                unknown = try SpaceLedgerMeasure(
                    status: .unknown,
                    bytes: nil,
                    sources: [endSource] + knownSources,
                    formulaKey: try token(
                        "accounting.formula.unknownInconsistent"
                    ),
                    explanationKey: try token(
                        "accounting.unknown.knownExceedsUsed"
                    )
                )
            } else {
                unknown = try SpaceLedgerMeasure(
                    status: .measured,
                    bytes: ByteCount(used - knownAllocated),
                    sources: uniqueSources([endSource] + knownSources),
                    formulaKey: try token(
                        "accounting.formula.usedMinusKnown"
                    ),
                    explanationKey: try token(
                        residualGapExists
                            ? "accounting.unknown.includesUnmeasurable"
                            : "accounting.unknown.volumeResidual"
                    )
                )
            }
        } else {
            status = .partial
            unknown = try SpaceLedgerMeasure(
                status: .unknown,
                bytes: nil,
                sources: [endSource] + knownSources,
                formulaKey: try token(
                    "accounting.formula.unknownUnavailable"
                ),
                explanationKey: try token(
                    "accounting.unknown.volumeBaselineUnavailable"
                )
            )
        }
        return try SpaceLedger(
            sessionID: endBaseline.sessionID,
            status: status,
            volumeCapacityAtStart: volumeCapacityAtStart,
            volumeCapacity: volumeCapacity,
            known: known,
            knownLogical: knownLogicalMeasure,
            unknown: unknown,
            unmeasurable: unmeasurable,
            freeAtStart: freeAtStart,
            free: free,
            observedUnclassified: unclassified,
            observedUnclassifiedLogical: unclassifiedLogical,
            owners: owners,
            coverageGaps: gaps,
            unknownIncludesUnmeasurable: residualGapExists,
            freeSpaceDelta: freeDelta,
            freeSpaceDeltaSources: [startSource, endSource],
            freeSpaceDeltaFormulaKey: try token(
                "accounting.formula.freeEndMinusStart"
            ),
            freeSpaceDeltaExplanationKey: try token(
                "accounting.free.deltaNotAttributed"
            ),
            caveats: caveats
        )
    }

    func checkedAdd(_ lhs: UInt64, _ rhs: UInt64) throws -> UInt64 {
        let result = lhs.addingReportingOverflow(rhs)
        guard !result.overflow,
              result.partialValue <= UInt64(Int64.max)
        else {
            throw SpaceLedgerError.integerOverflow
        }
        return result.partialValue
    }

    func sum(_ values: [UInt64]) throws -> UInt64 {
        try values.reduce(UInt64(0), checkedAdd)
    }

    func byteCount(_ value: UInt64) throws -> ByteCount {
        guard let value = ByteCount(value) else {
            throw SpaceLedgerError.integerOverflow
        }
        return value
    }

    func measure(
        value: ByteCount?,
        unknownStatus: AccountingMeasurementStatus,
        sources: [AccountingSource],
        formula: String,
        explanation: String
    ) throws -> SpaceLedgerMeasure {
        try SpaceLedgerMeasure(
            status: value == nil ? unknownStatus : .measured,
            bytes: value,
            sources: sources,
            formulaKey: try token(formula),
            explanationKey: try token(explanation)
        )
    }

    func signedDelta(
        from start: ByteCount?,
        to end: ByteCount?
    ) -> SignedByteDelta? {
        guard let start, let end,
              let startValue = Int64(exactly: start.value),
              let endValue = Int64(exactly: end.value)
        else {
            return nil
        }
        return SignedByteDelta(endValue - startValue)
    }

    func uniqueSources(_ sources: [AccountingSource]) -> [AccountingSource] {
        var seen = Set<String>()
        return sources.sorted {
            if $0.sampledAt == $1.sampledAt {
                return $0.identifier.rawValue < $1.identifier.rawValue
            }
            return $0.sampledAt < $1.sampledAt
        }.filter {
            seen.insert(
                "\($0.kind.rawValue)|\($0.identifier.rawValue)|\($0.sampledAt)"
            ).inserted
        }
    }

    func token(_ value: String) throws -> DomainToken {
        try DomainToken(validating: value)
    }
}
