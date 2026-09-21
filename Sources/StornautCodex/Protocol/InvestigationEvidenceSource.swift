import Foundation

public enum InvestigationEvidenceSource:
    String,
    Codable,
    Sendable,
    CaseIterable
{
    case probeBroker
    case directFile
    case shell
    case liveSearch
    case browserOrDirectFetch
    case image
    case skill
    case subagent

    public var displayLabel: String {
        switch self {
        case .probeBroker:
            "Stornaut Probe Broker"
        case .directFile:
            "Direct file evidence"
        case .shell:
            "Shell investigation"
        case .liveSearch:
            "Live search"
        case .browserOrDirectFetch:
            "Browser or direct fetch"
        case .image:
            "Image inspection"
        case .skill:
            "Investigation skill"
        case .subagent:
            "Subagent investigation"
        }
    }

    public var usesBrokerBoundary: Bool {
        self == .probeBroker
    }

    var permitsPublicURL: Bool {
        self == .liveSearch || self == .browserOrDirectFetch
    }
}

public enum InvestigationCapability:
    String,
    Codable,
    Sendable,
    CaseIterable
{
    case directRead
    case shell
    case unifiedExec
    case liveSearch
    case publicNetwork
    case browserOrDirectFetch
    case imageInspection
    case skills
    case subagents
    case probeBroker
}

public enum InvestigationConfidence:
    String,
    Codable,
    Sendable,
    CaseIterable
{
    case low
    case medium
    case high
}

public struct InvestigationProtocolContext: Sendable, Equatable {
    public let investigationID: String
    public let runID: String
    public let targetIDs: Set<String>
    public let candidateTargetIDs: [String: String]
    public let requiredCapabilities: Set<InvestigationCapability>

    public init(
        investigationID: String,
        runID: String,
        targetIDs: [String],
        candidateTargetIDs: [String: String],
        requiredCapabilities: Set<InvestigationCapability>
    ) throws {
        guard
            investigationProtocolIdentifierIsValid(investigationID),
            investigationProtocolIdentifierIsValid(runID),
            !targetIDs.isEmpty,
            targetIDs.count <= 512,
            Set(targetIDs).count == targetIDs.count,
            targetIDs.allSatisfy(investigationProtocolIdentifierIsValid),
            candidateTargetIDs.keys.allSatisfy(
                investigationProtocolIdentifierIsValid
            ),
            candidateTargetIDs.values.allSatisfy(
                investigationProtocolIdentifierIsValid
            ),
            candidateTargetIDs.count <= 256,
            Set(candidateTargetIDs.values).isSubset(of: Set(targetIDs)),
            !requiredCapabilities.isEmpty
        else {
            throw InvestigationEnvelopeV2Error.invalidContext
        }
        self.investigationID = investigationID
        self.runID = runID
        self.targetIDs = Set(targetIDs)
        self.candidateTargetIDs = candidateTargetIDs
        self.requiredCapabilities = requiredCapabilities
    }
}

public struct InvestigationAdvisoryReport: Sendable, Equatable {
    public let investigationID: String
    public let runID: String
    public let summary: String
    public let coverage: InvestigationCoverageV2
    public let evidence: [InvestigationEvidenceV2]
    public let findings: [InvestigationFindingV2]
    public let candidateProposals: [InvestigationCandidateProposalV2]
    public let capabilityDegradations:
        [InvestigationCapabilityDegradationV2]
}

public struct InvestigationAdvisoryNormalizer: Sendable {
    public init() {}

    public func normalize(
        _ envelope: InvestigationEnvelopeV2
    ) -> InvestigationAdvisoryReport {
        InvestigationAdvisoryReport(
            investigationID: envelope.investigationID,
            runID: envelope.runID,
            summary: envelope.summary,
            coverage: envelope.coverage,
            evidence: envelope.evidence,
            findings: envelope.findings,
            candidateProposals: envelope.candidateProposals,
            capabilityDegradations: envelope.capabilityDegradations
        )
    }
}

func investigationProtocolIdentifierIsValid(_ value: String) -> Bool {
    !value.isEmpty
        && value.utf8.count <= 256
        && value.unicodeScalars.allSatisfy {
            (0x30...0x39).contains($0.value)
                || (0x41...0x5A).contains($0.value)
                || (0x61...0x7A).contains($0.value)
                || $0.value == 0x2D
                || $0.value == 0x2E
                || $0.value == 0x3A
                || $0.value == 0x5F
        }
}
