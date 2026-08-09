import Foundation

public struct InvestigationFinding: Codable, Sendable, Equatable {
    public let targetID: String
    public let summary: String

    public init(targetID: String, summary: String) {
        self.targetID = targetID
        self.summary = summary
    }
}

public struct InvestigationEnvelope: Codable, Sendable, Equatable {
    public static let summaryByteLimit = 4_096
    public static let maximumFindingCount = 256
    public static let findingTargetIDByteLimit = 512
    public static let findingSummaryByteLimit = 4_096
    public static let maximumUnresolvedTargetCount = 256

    public let summary: String
    public let findings: [InvestigationFinding]
    public let unresolvedTargetIDs: [String]

    public init(
        summary: String,
        findings: [InvestigationFinding],
        unresolvedTargetIDs: [String]
    ) {
        self.summary = summary
        self.findings = findings
        self.unresolvedTargetIDs = unresolvedTargetIDs
    }

    public static func decodeValidated(from data: Data) throws -> Self {
        let object: [String: Any]
        do {
            guard let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw InvestigationEnvelopeError.invalidStructure
            }
            object = decoded
        } catch let error as InvestigationEnvelopeError {
            throw error
        } catch {
            throw InvestigationEnvelopeError.invalidJSON
        }

        let allowedKeys: Set<String> = [
            "summary",
            "findings",
            "unresolvedTargetIDs",
        ]
        if let unexpectedKey = object.keys.sorted().first(where: {
            !allowedKeys.contains($0)
        }) {
            throw InvestigationEnvelopeError.unexpectedField(unexpectedKey)
        }
        guard Set(object.keys) == allowedKeys else {
            throw InvestigationEnvelopeError.invalidStructure
        }
        guard
            let findingObjects = object["findings"] as? [[String: Any]],
            let unresolvedTargetIDs = object["unresolvedTargetIDs"] as? [String],
            object["summary"] is String
        else {
            throw InvestigationEnvelopeError.invalidStructure
        }
        let findingKeys: Set<String> = ["targetID", "summary"]
        guard findingObjects.allSatisfy({ Set($0.keys) == findingKeys }) else {
            throw InvestigationEnvelopeError.invalidFinding
        }
        _ = unresolvedTargetIDs

        let envelope: Self
        do {
            envelope = try JSONDecoder().decode(Self.self, from: data)
        } catch {
            throw InvestigationEnvelopeError.invalidStructure
        }
        try envelope.validate()
        return envelope
    }

    private func validate() throws {
        guard summary.utf8.count <= Self.summaryByteLimit else {
            throw InvestigationEnvelopeError.summaryByteLimitExceeded(
                limit: Self.summaryByteLimit
            )
        }
        guard findings.count <= Self.maximumFindingCount else {
            throw InvestigationEnvelopeError.findingCountLimitExceeded(
                limit: Self.maximumFindingCount
            )
        }
        guard unresolvedTargetIDs.count <= Self.maximumUnresolvedTargetCount else {
            throw InvestigationEnvelopeError.unresolvedTargetCountLimitExceeded(
                limit: Self.maximumUnresolvedTargetCount
            )
        }

        for finding in findings {
            guard
                !finding.targetID.isEmpty,
                finding.targetID.utf8.count <= Self.findingTargetIDByteLimit,
                finding.summary.utf8.count <= Self.findingSummaryByteLimit
            else {
                throw InvestigationEnvelopeError.invalidFinding
            }
        }
        for targetID in unresolvedTargetIDs {
            guard
                !targetID.isEmpty,
                targetID.utf8.count <= Self.findingTargetIDByteLimit
            else {
                throw InvestigationEnvelopeError.invalidUnresolvedTargetID
            }
        }
    }
}

public enum InvestigationEnvelopeError: Error, Sendable, Equatable {
    case invalidJSON
    case invalidStructure
    case unexpectedField(String)
    case summaryByteLimitExceeded(limit: Int)
    case findingCountLimitExceeded(limit: Int)
    case unresolvedTargetCountLimitExceeded(limit: Int)
    case invalidFinding
    case invalidUnresolvedTargetID
}
