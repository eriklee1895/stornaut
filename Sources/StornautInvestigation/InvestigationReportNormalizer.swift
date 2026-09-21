import CryptoKit
import Foundation
import StornautCodex
import StornautCore

public enum InvestigationReportNormalizationError:
    Error,
    Sendable,
    Equatable
{
    case invalidEnvelope
    case invalidIdentifier
    case quotaExceeded
}

enum InvestigationReportNormalizer {
    static func normalize(
        data: Data,
        context: InvestigationProtocolContext,
        reportID: InvestigationReportID,
        kind: InvestigationReportKind,
        usage: InvestigationTreeFinalizationV1?
    ) throws -> InvestigationTerminalReportInput {
        let envelope: InvestigationEnvelopeV2
        do {
            envelope = try InvestigationEnvelopeV2.decodeValidated(
                from: data,
                context: context
            )
        } catch {
            throw InvestigationReportNormalizationError.invalidEnvelope
        }
        let advisory = InvestigationAdvisoryNormalizer().normalize(envelope)
        let evidenceByID = Dictionary(
            uniqueKeysWithValues: advisory.evidence.map { ($0.id, $0) }
        )
        var rows: [InvestigationEvidenceInput] = []
        rows.reserveCapacity(
            advisory.findings.count
                + advisory.candidateProposals.count
                + advisory.coverage.unresolvedTargets.count
        )
        for finding in advisory.findings {
            rows.append(
                try evidenceInput(
                    externalID: finding.id,
                    targetID: finding.targetID,
                    kind: .finding,
                    summary: finding.summary,
                    confidence: finding.confidence,
                    uncertainty: finding.uncertainty,
                    evidenceIDs: finding.evidenceIDs,
                    evidenceByID: evidenceByID
                )
            )
        }
        for proposal in advisory.candidateProposals {
            rows.append(
                try evidenceInput(
                    externalID: proposal.candidateID,
                    targetID: proposal.targetID,
                    kind: .proposal,
                    summary: proposal.summary,
                    confidence: proposal.confidence,
                    uncertainty: proposal.uncertainty,
                    evidenceIDs: proposal.evidenceIDs,
                    evidenceByID: evidenceByID
                )
            )
        }
        for unresolved in advisory.coverage.unresolvedTargets {
            guard let targetID = InvestigationTargetID(
                rawValue: unresolved.targetID
            ) else {
                throw InvestigationReportNormalizationError.invalidIdentifier
            }
            rows.append(
                InvestigationEvidenceInput(
                    id: evidenceID(
                        kind: "unresolved",
                        externalID: unresolved.targetID
                    ),
                    targetID: targetID,
                    kind: .unresolved,
                    payload: try InvestigationEvidencePayload(
                        summary: unresolved.reason,
                        advisoryID: DomainToken(
                            rawValue: unresolved.targetID
                        ),
                        sourceLabel: DomainToken(
                            rawValue: "source.unresolved"
                        )!,
                        confidence: DomainToken(
                            rawValue: "confidence.low"
                        )!,
                        uncertainty:
                            "No verified finding resolved this admitted target."
                    )
                )
            )
        }
        guard rows.count <= 512 else {
            throw InvestigationReportNormalizationError.quotaExceeded
        }

        var degradations = try advisory.capabilityDegradations.map {
            try degradation(
                capability: $0.capability.rawValue,
                reasonKey: $0.reasonKey,
                summary: $0.summary
            )
        }
        if usage?.usageQuality == .unavailable {
            degradations.append(try usageUnavailable())
        }
        guard degradations.count <= 64 else {
            throw InvestigationReportNormalizationError.quotaExceeded
        }
        return InvestigationTerminalReportInput(
            id: reportID,
            kind: kind,
            payload: try InvestigationReportPayload(
                summary: advisory.summary
            ),
            evidence: rows,
            degradations: degradations
        )
    }

    package static func usageUnavailable(
    ) throws -> InvestigationDegradationInput {
        InvestigationDegradationInput(
            id: degradationID(
                kind: "usage",
                externalID: "unavailable"
            ),
            kind: .usageUnavailable,
            payload: try InvestigationDegradationPayload(
                reasonKey: DomainToken(rawValue: "usage.unavailable")!,
                summary:
                    "Matching cumulative token usage was unavailable for at least one terminal turn."
            )
        )
    }

    private static func evidenceInput(
        externalID: String,
        targetID: String,
        kind: InvestigationPersistedEvidenceKind,
        summary: String,
        confidence: InvestigationConfidence,
        uncertainty: String,
        evidenceIDs: [String],
        evidenceByID: [String: InvestigationEvidenceV2]
    ) throws -> InvestigationEvidenceInput {
        guard let storedTargetID = InvestigationTargetID(
            rawValue: targetID
        ) else {
            throw InvestigationReportNormalizationError.invalidIdentifier
        }
        let referenced = evidenceIDs.compactMap { evidenceByID[$0] }
        guard referenced.count == evidenceIDs.count else {
            throw InvestigationReportNormalizationError.invalidEnvelope
        }
        let sourceNames = Set(referenced.map(\.source.rawValue))
            .sorted()
        guard let sourceLabel = DomainToken(
            rawValue: "source." + sourceNames.joined(separator: ".")
        ) else {
            throw InvestigationReportNormalizationError.invalidIdentifier
        }
        let publicURLs = Set(
            referenced.compactMap { $0.publicURL?.absoluteString }
        )
        let provenance = publicURLs.count == 1
            ? PersistedWebProvenance(
                sanitizing: publicURLs.first!,
                transport: .publicInternet
            )
            : nil
        return InvestigationEvidenceInput(
            id: evidenceID(
                kind: kind.rawValue,
                externalID: externalID
            ),
            targetID: storedTargetID,
            kind: kind,
            payload: try InvestigationEvidencePayload(
                summary: summary,
                advisoryID: DomainToken(rawValue: externalID),
                sourceLabel: sourceLabel,
                confidence: DomainToken(
                    rawValue: "confidence.\(confidence.rawValue)"
                )!,
                uncertainty: uncertainty,
                webProvenance: provenance
            )
        )
    }

    private static func degradation(
        capability: String,
        reasonKey: String,
        summary: String
    ) throws -> InvestigationDegradationInput {
        guard let reason = DomainToken(rawValue: reasonKey) else {
            throw InvestigationReportNormalizationError.invalidIdentifier
        }
        return InvestigationDegradationInput(
            id: degradationID(
                kind: capability,
                externalID: reasonKey
            ),
            kind: .capabilityUnavailable,
            payload: try InvestigationDegradationPayload(
                reasonKey: reason,
                summary: summary
            )
        )
    }

    private static func evidenceID(
        kind: String,
        externalID: String
    ) -> InvestigationEvidenceID {
        InvestigationEvidenceID(
            rawValue: "investigation-evidence-"
                + digest("\(kind):\(externalID)")
        )!
    }

    private static func degradationID(
        kind: String,
        externalID: String
    ) -> InvestigationDegradationID {
        InvestigationDegradationID(
            rawValue: "investigation-degradation-"
                + digest("\(kind):\(externalID)")
        )!
    }

    private static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
