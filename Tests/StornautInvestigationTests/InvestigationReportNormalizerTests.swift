import Foundation
import Testing
import StornautCodex
import StornautCore
@testable import StornautInvestigation

@Suite("Investigation strict report normalization")
struct InvestigationReportNormalizerTests {
    @Test
    func strictEnvelopeProducesTargetBoundSourceLabeledReport() throws {
        let context = try InvestigationProtocolContext(
            investigationID: "investigation-report-fixture",
            runID: "investigation-run-report-fixture",
            targetIDs: ["target-a", "target-b"],
            candidateTargetIDs: ["candidate-a": "target-a"],
            requiredCapabilities: [.liveSearch, .shell]
        )
        let report = try InvestigationReportNormalizer.normalize(
            data: fixtureData(),
            context: context,
            reportID: InvestigationReportID(
                rawValue: "investigation-report-normalized"
            )!,
            kind: .partial,
            usage: InvestigationTreeFinalizationV1(
                allTurnsTerminal: true,
                totalTokens: nil,
                usageQuality: .unavailable,
                usageUnavailableThreadIDs: [
                    DomainToken(rawValue: "thread-report-fixture")!,
                ]
            )
        )

        #expect(report.kind == .partial)
        #expect(report.evidence.map(\.kind) == [
            .finding,
            .proposal,
            .unresolved,
        ])
        #expect(report.evidence.map(\.targetID.rawValue) == [
            "target-a",
            "target-a",
            "target-b",
        ])
        #expect(
            report.evidence[0].payload.sourceLabel?.rawValue
                == "source.liveSearch.probeBroker"
        )
        #expect(
            report.evidence[0].payload.webProvenance?.origin
                == "https://example.com/"
        )
        #expect(
            report.evidence[1].payload.sourceLabel?.rawValue
                == "source.probeBroker"
        )
        #expect(
            report.degradations.map(\.kind) == [
                .capabilityUnavailable,
                .usageUnavailable,
            ]
        )
    }

    @Test
    func forgedEnvelopeIdentityFailsBeforeReportAllocation() throws {
        let context = try InvestigationProtocolContext(
            investigationID: "investigation-report-fixture",
            runID: "investigation-run-report-fixture",
            targetIDs: ["target-a", "target-b"],
            candidateTargetIDs: ["candidate-a": "target-a"],
            requiredCapabilities: [.liveSearch, .shell]
        )
        var object = try #require(
            JSONSerialization.jsonObject(with: fixtureData())
                as? [String: Any]
        )
        object["runID"] = "investigation-run-forged"
        let forged = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )

        #expect(
            throws: InvestigationReportNormalizationError.invalidEnvelope
        ) {
            _ = try InvestigationReportNormalizer.normalize(
                data: forged,
                context: context,
                reportID: InvestigationReportID(
                    rawValue: "investigation-report-forged"
                )!,
                kind: .partial,
                usage: nil
            )
        }
    }

    private func fixtureData() -> Data {
        Data(
            """
            {
              "protocolVersion": 2,
              "investigationID": "investigation-report-fixture",
              "runID": "investigation-run-report-fixture",
              "summary": "Verified bounded advisory.",
              "coverage": {
                "investigatedTargetIDs": ["target-a"],
                "unresolvedTargets": [
                  {
                    "targetID": "target-b",
                    "reason": "runtime.capability.liveSearchUnavailable"
                  }
                ]
              },
              "evidence": [
                {
                  "id": "evidence-probe",
                  "targetID": "target-a",
                  "source": "probeBroker",
                  "summary": "Structured evidence.",
                  "publicURL": null
                },
                {
                  "id": "evidence-web",
                  "targetID": "target-a",
                  "source": "liveSearch",
                  "summary": "Public evidence.",
                  "publicURL": "https://example.com/private?secret=1"
                }
              ],
              "findings": [
                {
                  "id": "finding-a",
                  "targetID": "target-a",
                  "summary": "The target remains advisory.",
                  "evidenceIDs": ["evidence-probe", "evidence-web"],
                  "confidence": "high",
                  "uncertainty": "Swift must revalidate current facts."
                }
              ],
              "candidateProposals": [
                {
                  "candidateID": "candidate-a",
                  "targetID": "target-a",
                  "summary": "Future deterministic review candidate.",
                  "evidenceIDs": ["evidence-probe"],
                  "confidence": "medium",
                  "uncertainty": "No cleanup authority is granted."
                }
              ],
              "capabilityDegradations": [
                {
                  "capability": "liveSearch",
                  "reasonKey": "runtime.capability.liveSearchUnavailable",
                  "summary": "Live search was unavailable."
                }
              ]
            }
            """.utf8
        )
    }
}
