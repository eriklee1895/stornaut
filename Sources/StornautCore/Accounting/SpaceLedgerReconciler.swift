import Foundation

public struct SpaceLedgerReconciler: Sendable {
    public init() {}

    public func reconcile(_ input: SpaceLedgerInput) throws -> SpaceLedger {
        try validateBaselines(input)
        let snapshotByID = try validateSnapshots(input)
        let classificationBySnapshot = try validateClassifications(
            input.classifications,
            snapshots: snapshotByID
        )
        let projection = try projectOwners(
            snapshots: input.snapshots,
            classifications: classificationBySnapshot,
            rootDevice: input.endBaseline.rootIdentity.device
        )
        let endSource = input.endBaseline.source
        let startSource = input.startBaseline.source
        let knownOwners = projection.owners.filter {
            $0.category != .unknownLargeConsumers
        }
        let knownSources = knownOwners.isEmpty
            ? [try surveyorSource(input.snapshots, fallback: endSource)]
            : uniqueSources(knownOwners.flatMap(\.sources))
        let surveyor = try surveyorSource(
            input.snapshots,
            fallback: endSource
        )

        let volumeCapacityAtStart = try measure(
            value: input.startBaseline.totalCapacity,
            unknownStatus: .unknown,
            sources: [startSource],
            formula: "accounting.formula.volumeCapacityAtStart",
            explanation: "accounting.volume.startCapacity"
        )
        let volumeCapacity = try measure(
            value: input.endBaseline.totalCapacity,
            unknownStatus: .unknown,
            sources: [endSource],
            formula: "accounting.formula.volumeCapacity",
            explanation: "accounting.volume.capacity"
        )
        let freeAtStart = try measure(
            value: input.startBaseline.availableCapacity,
            unknownStatus: .unknown,
            sources: [startSource],
            formula: "accounting.formula.freeAtStart",
            explanation: "accounting.free.startSystemObservation"
        )
        let free = try measure(
            value: input.endBaseline.availableCapacity,
            unknownStatus: .unknown,
            sources: [endSource],
            formula: "accounting.formula.free",
            explanation: "accounting.free.systemObservation"
        )
        let knownBytes = try byteCount(projection.knownAllocated)
        let known = try SpaceLedgerMeasure(
            status: .measured,
            bytes: knownBytes,
            sources: knownSources,
            formulaKey: try token("accounting.formula.knownOwners"),
            explanationKey: try token("accounting.known.classifiedOwners")
        )
        let knownLogical = try SpaceLedgerMeasure(
            status: .measured,
            bytes: try byteCount(projection.knownLogical),
            sources: knownSources,
            formulaKey: try token("accounting.formula.knownLogicalOwners"),
            explanationKey: try token("accounting.known.logicalOwners")
        )
        let observedUnclassified = try SpaceLedgerMeasure(
            status: .measured,
            bytes: try byteCount(projection.observedUnclassified),
            sources: [surveyor],
            formulaKey: try token(
                "accounting.formula.observedUnclassified"
            ),
            explanationKey: try token(
                "accounting.unknown.observedUnclassified"
            )
        )
        let observedUnclassifiedLogical = try SpaceLedgerMeasure(
            status: .measured,
            bytes: try byteCount(projection.observedUnclassifiedLogical),
            sources: [surveyor],
            formulaKey: try token(
                "accounting.formula.observedUnclassifiedLogical"
            ),
            explanationKey: try token(
                "accounting.unknown.observedUnclassifiedLogical"
            )
        )
        let unmeasurable: SpaceLedgerMeasure
        if projection.gaps.isEmpty {
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
                sources: [try permissionSource(projection.gaps)],
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
        if projection.sparseObserved {
            caveats.append(.sparseFileObserved)
        }
        if projection.hardLinkDeduplicated {
            caveats.append(.hardLinkDeduplicated)
        }
        let freeDelta = signedDelta(
            from: input.startBaseline.availableCapacity,
            to: input.endBaseline.availableCapacity
        )
        if freeDelta?.value != 0
            || input.startBaseline.totalCapacity
                != input.endBaseline.totalCapacity
        {
            caveats.append(.volumeChangedDuringScan)
        }
        if projection.hardLinkOwnershipAmbiguous {
            caveats.append(.hardLinkOwnershipAmbiguous)
        }

        let unknown: SpaceLedgerMeasure
        let residualGapExists = projection.gaps.contains {
            $0.includedInUnknownResidual
        }
        var status: SpaceLedgerStatus = projection.gaps.isEmpty
            ? .reconciled
            : .partial
        if let total = input.endBaseline.totalCapacity,
           let freeBytes = input.endBaseline.availableCapacity
        {
            let used = total.value - freeBytes.value
            if projection.knownAllocated > used {
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
                    bytes: ByteCount(used - projection.knownAllocated),
                    sources: uniqueSources([endSource] + knownSources),
                    formulaKey: try token(
                        "accounting.formula.usedMinusKnown"
                    ),
                    explanationKey: try token(
                        !residualGapExists
                            ? "accounting.unknown.volumeResidual"
                            : "accounting.unknown.includesUnmeasurable"
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
            sessionID: input.endBaseline.sessionID,
            status: status,
            volumeCapacityAtStart: volumeCapacityAtStart,
            volumeCapacity: volumeCapacity,
            known: known,
            knownLogical: knownLogical,
            unknown: unknown,
            unmeasurable: unmeasurable,
            freeAtStart: freeAtStart,
            free: free,
            observedUnclassified: observedUnclassified,
            observedUnclassifiedLogical: observedUnclassifiedLogical,
            owners: projection.owners,
            coverageGaps: projection.gaps,
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
}

private struct OwnerProjection {
    let owners: [SpaceLedgerOwner]
    let gaps: [SpaceLedgerCoverageGap]
    let knownAllocated: UInt64
    let knownLogical: UInt64
    let observedUnclassified: UInt64
    let observedUnclassifiedLogical: UInt64
    let sparseObserved: Bool
    let hardLinkDeduplicated: Bool
    let hardLinkOwnershipAmbiguous: Bool
}

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

private extension SpaceLedgerReconciler {
    func validateBaselines(_ input: SpaceLedgerInput) throws {
        let start = input.startBaseline
        let end = input.endBaseline
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

    func validateSnapshots(
        _ input: SpaceLedgerInput
    ) throws -> [SnapshotID: PathSnapshot] {
        var byID: [SnapshotID: PathSnapshot] = [:]
        var paths = Set<String>()
        for snapshot in input.snapshots {
            guard snapshot.sessionID == input.endBaseline.sessionID,
                  snapshot.scopeID == input.endBaseline.scopeID
            else {
                throw SpaceLedgerError.snapshotScopeMismatch
            }
            guard byID.updateValue(snapshot, forKey: snapshot.id) == nil else {
                throw SpaceLedgerError.duplicateSnapshot
            }
            guard paths.insert(snapshot.relativePath).inserted else {
                throw SpaceLedgerError.duplicatePath
            }
        }
        return byID
    }

    func validateClassifications(
        _ classifications: [Classification],
        snapshots: [SnapshotID: PathSnapshot]
    ) throws -> [SnapshotID: Classification] {
        var ids = Set<ClassificationID>()
        var bySnapshot: [SnapshotID: Classification] = [:]
        for classification in classifications {
            guard ids.insert(classification.id).inserted,
                  bySnapshot.updateValue(
                      classification,
                      forKey: classification.snapshotID
                  ) == nil
            else {
                throw SpaceLedgerError.duplicateClassification
            }
            guard snapshots[classification.snapshotID] != nil else {
                throw SpaceLedgerError.classificationTargetMissing
            }
        }
        return bySnapshot
    }

    func projectOwners(
        snapshots: [PathSnapshot],
        classifications: [SnapshotID: Classification],
        rootDevice: UInt64
    ) throws -> OwnerProjection {
        let byID = Dictionary(
            uniqueKeysWithValues: snapshots.map { ($0.id, $0) }
        )
        let byPath = Dictionary(
            uniqueKeysWithValues: snapshots.map { ($0.relativePath, $0) }
        )
        var accumulators: [SnapshotID: OwnerAccumulator] = [:]
        for (snapshotID, classification) in classifications {
            guard let snapshot = byID[snapshotID] else {
                throw SpaceLedgerError.classificationTargetMissing
            }
            accumulators[snapshotID] = OwnerAccumulator(
                classification: classification,
                snapshot: snapshot,
                latestObservedAt: snapshot.observedAt
            )
        }

        var gaps: [SpaceLedgerCoverageGap] = []
        var observedUnclassified: UInt64 = 0
        var observedUnclassifiedLogical: UInt64 = 0
        var hardLinkDeduplicated = false
        var hardLinkOwnershipAmbiguous = false
        var sparseObserved = false
        var regularGroups: [
            FileLedgerIdentity: [(PathSnapshot, SnapshotID?)]
        ] = [:]

        for snapshot in snapshots.sorted(by: {
            $0.relativePath < $1.relativePath
        }) {
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
               identity.device != rootDevice
            {
                throw SpaceLedgerError.snapshotScopeMismatch
            }
            let ownerID = nearestOwner(
                for: snapshot.relativePath,
                snapshotsByPath: byPath,
                classifications: classifications
            )
            if snapshot.kind == .regularFile,
               let identity = snapshot.fileIdentity
            {
                let key = FileLedgerIdentity(
                    device: identity.device,
                    inode: identity.inode
                )
                regularGroups[key, default: []].append((snapshot, ownerID))
                continue
            }
            try accumulate(
                logical: logical,
                allocated: allocated,
                observedAt: snapshot.observedAt,
                ownerID: ownerID,
                owners: &accumulators,
                observedUnclassified: &observedUnclassified,
                observedUnclassifiedLogical: &observedUnclassifiedLogical
            )
        }

        for group in regularGroups.values {
            let ordered = group.sorted {
                $0.0.relativePath < $1.0.relativePath
            }
            guard let first = ordered.first,
                  let logical = first.0.logicalByteCount?.value,
                  let allocated = first.0.allocatedByteCount?.value
            else {
                continue
            }
            guard ordered.allSatisfy({
                $0.0.logicalByteCount?.value == logical
                    && $0.0.allocatedByteCount?.value == allocated
            }) else {
                throw SpaceLedgerError.hardLinkMetadataMismatch
            }
            if logical > allocated {
                sparseObserved = true
            }
            if ordered.count > 1 {
                hardLinkDeduplicated = true
            }
            let buckets = Set(ordered.map {
                $0.1.map(OwnerBucket.owner) ?? .unclassified
            })
            let ownerID: SnapshotID?
            if buckets.count > 1 {
                hardLinkOwnershipAmbiguous = true
                ownerID = nil
            } else {
                ownerID = first.1
            }
            try accumulate(
                logical: logical,
                allocated: allocated,
                observedAt: ordered.map { $0.0.observedAt }.max()
                    ?? first.0.observedAt,
                ownerID: ownerID,
                owners: &accumulators,
                observedUnclassified: &observedUnclassified,
                observedUnclassifiedLogical: &observedUnclassifiedLogical
            )
        }

        let owners = try accumulators.values.sorted {
            $0.snapshot.relativePath < $1.snapshot.relativePath
        }.map { owner in
            return try SpaceLedgerOwner(
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
        let knownAllocated = try owners.reduce(UInt64(0)) {
            guard $1.category != .unknownLargeConsumers else {
                return $0
            }
            return try checkedAdd($0, $1.allocatedBytes?.value ?? 0)
        }
        let knownLogical = try owners.reduce(UInt64(0)) {
            guard $1.category != .unknownLargeConsumers else {
                return $0
            }
            return try checkedAdd($0, $1.logicalBytes?.value ?? 0)
        }
        return OwnerProjection(
            owners: owners,
            gaps: gaps,
            knownAllocated: knownAllocated,
            knownLogical: knownLogical,
            observedUnclassified: observedUnclassified,
            observedUnclassifiedLogical: observedUnclassifiedLogical,
            sparseObserved: sparseObserved,
            hardLinkDeduplicated: hardLinkDeduplicated,
            hardLinkOwnershipAmbiguous: hardLinkOwnershipAmbiguous
        )
    }

    func accumulate(
        logical: UInt64,
        allocated: UInt64,
        observedAt: Date,
        ownerID: SnapshotID?,
        owners: inout [SnapshotID: OwnerAccumulator],
        observedUnclassified: inout UInt64,
        observedUnclassifiedLogical: inout UInt64
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

    func nearestOwner(
        for relativePath: String,
        snapshotsByPath: [String: PathSnapshot],
        classifications: [SnapshotID: Classification]
    ) -> SnapshotID? {
        var path: String? = relativePath
        while let current = path {
            if let snapshot = snapshotsByPath[current],
               classifications[snapshot.id] != nil
            {
                return snapshot.id
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

    func checkedAdd(_ lhs: UInt64, _ rhs: UInt64) throws -> UInt64 {
        let result = lhs.addingReportingOverflow(rhs)
        guard !result.overflow,
              result.partialValue <= UInt64(Int64.max)
        else {
            throw SpaceLedgerError.integerOverflow
        }
        return result.partialValue
    }

    func byteCount(_ value: UInt64) throws -> ByteCount {
        guard let bytes = ByteCount(value) else {
            throw SpaceLedgerError.integerOverflow
        }
        return bytes
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

    func surveyorSource(
        _ snapshots: [PathSnapshot],
        fallback: AccountingSource
    ) throws -> AccountingSource {
        guard let latest = snapshots.map(\.observedAt).max() else {
            return fallback
        }
        return AccountingSource(
            kind: .surveyor,
            identifier: try token("space-ledger.surveyor"),
            sampledAt: latest
        )
    }

    func permissionSource(
        _ gaps: [SpaceLedgerCoverageGap]
    ) throws -> AccountingSource {
        AccountingSource(
            kind: .permissionGap,
            identifier: try token("space-ledger.coverage-gaps"),
            sampledAt: gaps.map(\.observedAt).max() ?? .distantPast
        )
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
