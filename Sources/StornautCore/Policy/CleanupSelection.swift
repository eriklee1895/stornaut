import CryptoKit
import Foundation

public struct ReviewSelectionItem: Sendable, Equatable {
    public let itemID: CleanupPlanItemID
    public let origin: CleanupSelectionOrigin

    public init(
        itemID: CleanupPlanItemID,
        origin: CleanupSelectionOrigin
    ) {
        self.itemID = itemID
        self.origin = origin
    }
}

public enum ReviewSelectionError: Error, Sendable, Equatable {
    case incompatiblePlan
    case emptySelection
    case tooManyItems
    case duplicateItem
    case unknownItem
    case missingDisposition
    case nonExecutableDisposition
    case readyDefaultRequired
    case reviewRequiresExplicitSelection
    case overlap
}

public struct ReviewSelection: Sendable, Equatable {
    public static let maximumItemCount = 100

    public let planID: CleanupPlanID
    public let generation: UInt64
    public let items: [ReviewSelectionItem]
    public let fingerprint: DomainToken

    public init(
        plan: CleanupPlan,
        generation: UInt64,
        items: [ReviewSelectionItem],
        dispositions: [CleanupPlanItemID: ReclaimDisposition]
    ) throws {
        guard plan.compatibility == .current,
              plan.planFingerprint != nil
        else {
            throw ReviewSelectionError.incompatiblePlan
        }
        guard !items.isEmpty else {
            throw ReviewSelectionError.emptySelection
        }
        guard items.count <= Self.maximumItemCount else {
            throw ReviewSelectionError.tooManyItems
        }
        let selectedIDs = items.map(\.itemID)
        guard Set(selectedIDs).count == selectedIDs.count else {
            throw ReviewSelectionError.duplicateItem
        }
        let planItems = Dictionary(
            uniqueKeysWithValues: plan.items.map { ($0.id, $0) }
        )
        guard selectedIDs.allSatisfy({ planItems[$0] != nil }) else {
            throw ReviewSelectionError.unknownItem
        }
        guard selectedIDs.allSatisfy({ dispositions[$0] != nil }) else {
            throw ReviewSelectionError.missingDisposition
        }

        for item in items {
            switch dispositions[item.itemID] {
            case .readyToReclaim:
                break
            case .reviewRecommended:
                guard item.origin == .explicitUser else {
                    throw ReviewSelectionError
                        .reviewRequiresExplicitSelection
                }
            case .protected, .unknown:
                throw ReviewSelectionError.nonExecutableDisposition
            case nil:
                throw ReviewSelectionError.missingDisposition
            }
            guard let planItem = planItems[item.itemID],
                  planItem.executionProfileID != nil,
                  planItem.proposedAction == .moveToTrash
            else {
                throw ReviewSelectionError.nonExecutableDisposition
            }
        }

        let ordered = plan.items.compactMap { planItem in
            items.first { $0.itemID == planItem.id }
        }
        guard ordered.count == items.count,
              !Self.hasOverlap(
                  ordered.compactMap {
                      planItems[$0.itemID]?.expectedRelativePath
                  }
              )
        else {
            throw ReviewSelectionError.overlap
        }
        self.planID = plan.id
        self.generation = generation
        self.items = ordered
        fingerprint = selectionFingerprint(
            plan: plan,
            generation: generation,
            items: ordered,
            planItems: planItems
        )
    }

    public func origin(
        for itemID: CleanupPlanItemID
    ) -> CleanupSelectionOrigin? {
        items.first { $0.itemID == itemID }?.origin
    }

    private static func hasOverlap(_ paths: [PersistedPath]) -> Bool {
        for firstIndex in paths.indices {
            for secondIndex in paths.indices where secondIndex > firstIndex {
                if pathOverlaps(paths[firstIndex], paths[secondIndex]) {
                    return true
                }
            }
        }
        return false
    }
}

private func selectionFingerprint(
    plan: CleanupPlan,
    generation: UInt64,
    items: [ReviewSelectionItem],
    planItems: [CleanupPlanItemID: CleanupPlanItem]
) -> DomainToken {
    var lines = [
        "stornaut.cleanup-selection.v1",
        plan.id.rawValue,
        plan.planFingerprint?.rawValue ?? "",
        String(generation),
    ]
    lines.append(contentsOf: items.map { item in
        [
            item.itemID.rawValue,
            item.origin.rawValue,
            planItems[item.itemID]?.expectedRelativePath?.rawValue ?? "",
        ].joined(separator: "|")
    })
    return cleanupFingerprint(
        prefix: "selection",
        lines: lines
    )
}

func cleanupFingerprint(
    prefix: String,
    lines: [String]
) -> DomainToken {
    let hash = SHA256.hash(
        data: Data(lines.joined(separator: "\n").utf8)
    ).map { String(format: "%02x", $0) }.joined()
    return DomainToken(rawValue: "\(prefix).\(hash)")!
}

func cleanupIdentityFingerprintLine(
    _ identity: FileIdentity?
) -> String {
    guard let identity else {
        return "identity.unavailable"
    }
    return [
        String(identity.device),
        String(identity.inode),
        String(identity.mode),
        String(identity.ownerUserID),
        String(identity.ownerGroupID),
        String(identity.linkCount),
        String(identity.size),
        String(identity.allocatedBytes),
        String(identity.modificationSeconds),
        String(identity.modificationNanoseconds),
    ].joined(separator: ":")
}

private func pathOverlaps(
    _ first: PersistedPath,
    _ second: PersistedPath
) -> Bool {
    let firstComponents = first.rawValue.split(separator: "/")
    let secondComponents = second.rawValue.split(separator: "/")
    let count = min(firstComponents.count, secondComponents.count)
    return Array(firstComponents.prefix(count))
        == Array(secondComponents.prefix(count))
}
