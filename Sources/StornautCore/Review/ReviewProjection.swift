import Foundation

public enum ReviewEligibility:
    String,
    Sendable,
    Equatable
{
    case executable
    case noExecutionProfile
    case persistedDispositionBlocked
    case currentEvidenceBlocked
}

public struct ReviewProjectionRow: Sendable, Equatable {
    public let snapshotID: SnapshotID
    public let classificationID: ClassificationID
    public let relativePath: String
    public let ruleID: DomainToken?
    public let persistedDisposition: ReclaimDisposition
    public let currentDisposition: ReclaimDisposition
    public let eligibility: ReviewEligibility
    public let suggestedDefault: Bool
    public let reasonKeys: [DomainToken]

    public init(
        snapshotID: SnapshotID,
        classificationID: ClassificationID,
        relativePath: String,
        ruleID: DomainToken?,
        persistedDisposition: ReclaimDisposition,
        currentDisposition: ReclaimDisposition,
        eligibility: ReviewEligibility,
        suggestedDefault: Bool,
        reasonKeys: [DomainToken]
    ) {
        self.snapshotID = snapshotID
        self.classificationID = classificationID
        self.relativePath = relativePath
        self.ruleID = ruleID
        self.persistedDisposition = persistedDisposition
        self.currentDisposition = currentDisposition
        self.eligibility = eligibility
        self.suggestedDefault = suggestedDefault
        self.reasonKeys = reasonKeys
    }
}

public struct ReviewProjectionCounts: Sendable, Equatable {
    public let executableReady: Int
    public let executableReview: Int
    public let noExecutionProfile: Int
    public let persistedDispositionBlocked: Int
    public let currentEvidenceBlocked: Int

    public init(
        executableReady: Int,
        executableReview: Int,
        noExecutionProfile: Int,
        persistedDispositionBlocked: Int,
        currentEvidenceBlocked: Int
    ) throws {
        let values = [
            executableReady,
            executableReview,
            noExecutionProfile,
            persistedDispositionBlocked,
            currentEvidenceBlocked,
        ]
        let total = Self.checkedSum(values)
        guard values.allSatisfy({ $0 >= 0 }),
              total != nil
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.executableReady = executableReady
        self.executableReview = executableReview
        self.noExecutionProfile = noExecutionProfile
        self.persistedDispositionBlocked = persistedDispositionBlocked
        self.currentEvidenceBlocked = currentEvidenceBlocked
    }

    public var total: Int {
        Self.checkedSum([
            executableReady,
            executableReview,
            noExecutionProfile,
            persistedDispositionBlocked,
            currentEvidenceBlocked,
        ])!
    }

    public var executable: Int {
        Self.checkedSum([
            executableReady,
            executableReview,
        ])!
    }

    private static func checkedSum(_ values: [Int]) -> Int? {
        values.reduce(Optional(0)) { partial, value in
            guard let partial else {
                return nil
            }
            let result = partial.addingReportingOverflow(value)
            return result.overflow ? nil : result.partialValue
        }
    }
}

public struct ReviewProjection: Sendable, Equatable {
    public static let maximumRows = 100

    public let sessionID: ScanSessionID
    public let planID: CleanupPlanID?
    public let rows: [ReviewProjectionRow]
    public let totalRowCount: Int
    public let counts: ReviewProjectionCounts

    public init(
        sessionID: ScanSessionID,
        planID: CleanupPlanID?,
        rows: [ReviewProjectionRow],
        totalRowCount: Int,
        counts: ReviewProjectionCounts
    ) throws {
        guard rows.count <= Self.maximumRows,
              totalRowCount >= rows.count,
              counts.total == totalRowCount,
              rows == rows.sorted(by: reviewRowOrder)
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.sessionID = sessionID
        self.planID = planID
        self.rows = rows
        self.totalRowCount = totalRowCount
        self.counts = counts
    }

    public var executableCount: Int {
        counts.executable
    }
}

private func reviewRowOrder(
    _ lhs: ReviewProjectionRow,
    _ rhs: ReviewProjectionRow
) -> Bool {
    if lhs.relativePath != rhs.relativePath {
        return lhs.relativePath < rhs.relativePath
    }
    return lhs.classificationID.rawValue < rhs.classificationID.rawValue
}
