import Foundation

struct ProductOwnerByteAggregate: Sendable {
    let snapshotID: SnapshotID?
    let logicalBytes: UInt64
    let allocatedBytes: UInt64
    let observedAt: Date
}

struct ProductScanReduction: Sendable {
    let aggregate: ScanAggregate
    let ownerBytes: [ProductOwnerByteAggregate]
    let gaps: [PathSnapshot]
    let sparseObserved: Bool
    let hardLinkDeduplicated: Bool
    let hardLinkOwnershipAmbiguous: Bool
    let retainedSnapshotCount: Int
}

final class ProductScanAccumulator: @unchecked Sendable {
    private struct HardLinkIdentity: Hashable {
        let device: UInt64
        let inode: UInt64
    }

    private enum OwnerBucket: Hashable {
        case owner(SnapshotID)
        case unclassified
    }

    private struct Bytes {
        var logical: UInt64 = 0
        var allocated: UInt64 = 0
        var observedAt = Date.distantPast
    }

    private struct HardLink {
        let logical: UInt64
        let allocated: UInt64
        var observedAt: Date
        var buckets: Set<OwnerBucket>
        var paths: Int
    }

    private let lock = NSLock()
    private let matcher: RuleCatalogMatcher
    private let displayFactLimit: Int
    private var ownerIDByPath: [String: SnapshotID] = [:]
    private var ownerBytes: [SnapshotID: Bytes] = [:]
    private var unclassified = Bytes()
    private var gaps: [PathSnapshot] = []
    private var hardLinks: [HardLinkIdentity: HardLink] = [:]
    private var retainedIDs = Set<SnapshotID>()
    private var displayFactCount = 0
    private var entryCounts: [PathKind: Int] = [:]
    private var issueCounts: [ScanIssue: Int] = [:]
    private var logicalFileBytes: Int64 = 0
    private var allocatedFileBytes: Int64 = 0
    private var sparseObserved = false

    init(
        matcher: RuleCatalogMatcher,
        displayFactLimit: Int = 100
    ) {
        self.matcher = matcher
        self.displayFactLimit = displayFactLimit
    }

    func consume(_ observation: SurveyorObservation) throws -> Bool {
        try lock.withLock {
            let snapshot = observation.snapshot
            entryCounts[snapshot.kind, default: 0] += 1
            if let issue = observation.issue {
                issueCounts[issue, default: 0] += 1
            }
            logicalFileBytes = max(
                logicalFileBytes,
                observation.progress.logicalFileBytes
            )
            allocatedFileBytes = max(
                allocatedFileBytes,
                observation.progress.allocatedFileBytes
            )

            let rules = try matchingRules(for: snapshot)
            let isRootOrTopLevelDirectory =
                snapshot.measurementStatus == .measured
                && snapshot.kind == .directory
                && (
                    snapshot.relativePath == "."
                        || !snapshot.relativePath.contains("/")
                )
            let isOwner = !rules.isEmpty || isRootOrTopLevelDirectory
            if isOwner {
                ownerIDByPath[snapshot.relativePath] = snapshot.id
                ownerBytes[snapshot.id, default: Bytes()].observedAt = max(
                    ownerBytes[snapshot.id]?.observedAt ?? .distantPast,
                    snapshot.observedAt
                )
            }

            if snapshot.measurementStatus != .measured {
                gaps.append(snapshot)
            } else if let logical = snapshot.logicalByteCount?.value,
                      let allocated = snapshot.allocatedByteCount?.value
            {
                let ownerID = nearestOwner(for: snapshot.relativePath)
                if snapshot.kind == .regularFile {
                    if logical > allocated {
                        sparseObserved = true
                    }
                    if let identity = snapshot.fileIdentity,
                       identity.linkCount > 1
                    {
                        try recordHardLink(
                            identity: identity,
                            logical: logical,
                            allocated: allocated,
                            observedAt: snapshot.observedAt,
                            ownerID: ownerID
                        )
                    } else {
                        try add(
                            logical: logical,
                            allocated: allocated,
                            observedAt: snapshot.observedAt,
                            ownerID: ownerID
                        )
                    }
                } else {
                    try add(
                        logical: logical,
                        allocated: allocated,
                        observedAt: snapshot.observedAt,
                        ownerID: ownerID
                    )
                }
            }

            let retainForDisplay = displayFactCount < displayFactLimit
            let retain = retainForDisplay
                || isOwner
                || snapshot.measurementStatus != .measured
            if retain, retainedIDs.insert(snapshot.id).inserted,
               retainForDisplay
            {
                displayFactCount += 1
            }
            return retain
        }
    }

    func reduction() throws -> ProductScanReduction {
        try lock.withLock {
            var ownerBytes = ownerBytes
            var unclassified = unclassified
            var hardLinkDeduplicated = false
            var hardLinkOwnershipAmbiguous = false
            for link in hardLinks.values {
                if link.paths > 1 {
                    hardLinkDeduplicated = true
                }
                let ownerID: SnapshotID?
                if link.buckets.count > 1 {
                    hardLinkOwnershipAmbiguous = true
                    ownerID = nil
                } else {
                    ownerID = link.buckets.first.flatMap {
                        if case let .owner(value) = $0 {
                            return value
                        }
                        return nil
                    }
                }
                try Self.add(
                    logical: link.logical,
                    allocated: link.allocated,
                    observedAt: link.observedAt,
                    ownerID: ownerID,
                    ownerBytes: &ownerBytes,
                    unclassified: &unclassified
                )
            }
            let total = entryCounts.values.reduce(0, +)
            let regularFiles = entryCounts[.regularFile, default: 0]
            let directories = entryCounts[.directory, default: 0]
            let symbolicLinks = entryCounts[.symbolicLink, default: 0]
            let inaccessible = entryCounts[.inaccessible, default: 0]
            let other = entryCounts[.other, default: 0]
            let aggregate = try ScanAggregate(
                entries: ScanEntryCounts(
                    total: total,
                    regularFiles: regularFiles,
                    directories: directories,
                    symbolicLinks: symbolicLinks,
                    inaccessible: inaccessible,
                    other: other
                ),
                issues: ScanIssueCounts(
                    permissionDenied:
                        issueCounts[.permissionDenied, default: 0],
                    mountBoundary: issueCounts[.mountBoundary, default: 0],
                    userExcluded: issueCounts[.userExcluded, default: 0],
                    metadataUnavailable:
                        issueCounts[.metadataUnavailable, default: 0],
                    directoryReadFailed:
                        issueCounts[.directoryReadFailed, default: 0]
                ),
                logicalFileBytes: logicalFileBytes,
                allocatedFileBytes: allocatedFileBytes
            )
            var projected = ownerBytes.map {
                ProductOwnerByteAggregate(
                    snapshotID: $0.key,
                    logicalBytes: $0.value.logical,
                    allocatedBytes: $0.value.allocated,
                    observedAt: $0.value.observedAt
                )
            }
            if unclassified.logical > 0 || unclassified.allocated > 0 {
                projected.append(
                    ProductOwnerByteAggregate(
                        snapshotID: nil,
                        logicalBytes: unclassified.logical,
                        allocatedBytes: unclassified.allocated,
                        observedAt: unclassified.observedAt
                    )
                )
            }
            return ProductScanReduction(
                aggregate: aggregate,
                ownerBytes: projected,
                gaps: gaps,
                sparseObserved: sparseObserved,
                hardLinkDeduplicated: hardLinkDeduplicated,
                hardLinkOwnershipAmbiguous: hardLinkOwnershipAmbiguous,
                retainedSnapshotCount: retainedIDs.count
            )
        }
    }
}

private extension ProductScanAccumulator {
    func matchingRules(
        for snapshot: PathSnapshot
    ) throws -> [CompiledRule] {
        guard snapshot.measurementStatus == .measured,
              snapshot.relativePath != ".",
              let kind = ruleKind(snapshot.kind)
        else {
            return []
        }
        do {
            return try matcher.matchingRules(
                relativePath: snapshot.relativePath,
                kind: kind
            )
        } catch RuleCatalogError.invalidPattern {
            return []
        }
    }

    func nearestOwner(for relativePath: String) -> SnapshotID? {
        var path: String? = relativePath
        while let current = path {
            if let ownerID = ownerIDByPath[current] {
                return ownerID
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

    func recordHardLink(
        identity: FileIdentity,
        logical: UInt64,
        allocated: UInt64,
        observedAt: Date,
        ownerID: SnapshotID?
    ) throws {
        let key = HardLinkIdentity(
            device: identity.device,
            inode: identity.inode
        )
        let bucket = ownerID.map(OwnerBucket.owner) ?? .unclassified
        if var link = hardLinks[key] {
            guard link.logical == logical,
                  link.allocated == allocated
            else {
                throw SpaceLedgerError.hardLinkMetadataMismatch
            }
            link.observedAt = max(link.observedAt, observedAt)
            link.buckets.insert(bucket)
            link.paths += 1
            hardLinks[key] = link
        } else {
            hardLinks[key] = HardLink(
                logical: logical,
                allocated: allocated,
                observedAt: observedAt,
                buckets: [bucket],
                paths: 1
            )
        }
    }

    func add(
        logical: UInt64,
        allocated: UInt64,
        observedAt: Date,
        ownerID: SnapshotID?
    ) throws {
        try Self.add(
            logical: logical,
            allocated: allocated,
            observedAt: observedAt,
            ownerID: ownerID,
            ownerBytes: &ownerBytes,
            unclassified: &unclassified
        )
    }

    private static func add(
        logical: UInt64,
        allocated: UInt64,
        observedAt: Date,
        ownerID: SnapshotID?,
        ownerBytes: inout [SnapshotID: Bytes],
        unclassified: inout Bytes
    ) throws {
        if let ownerID {
            var bytes = ownerBytes[ownerID, default: Bytes()]
            bytes.logical = try checkedAdd(bytes.logical, logical)
            bytes.allocated = try checkedAdd(bytes.allocated, allocated)
            bytes.observedAt = max(bytes.observedAt, observedAt)
            ownerBytes[ownerID] = bytes
        } else {
            unclassified.logical = try checkedAdd(
                unclassified.logical,
                logical
            )
            unclassified.allocated = try checkedAdd(
                unclassified.allocated,
                allocated
            )
            unclassified.observedAt = max(
                unclassified.observedAt,
                observedAt
            )
        }
    }

    static func checkedAdd(_ lhs: UInt64, _ rhs: UInt64) throws -> UInt64 {
        let result = lhs.addingReportingOverflow(rhs)
        guard !result.overflow,
              result.partialValue <= UInt64(Int64.max)
        else {
            throw SpaceLedgerError.integerOverflow
        }
        return result.partialValue
    }

    func ruleKind(_ kind: PathKind) -> RuleExpectedKind? {
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
}
