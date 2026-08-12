import Foundation
import Testing
@testable import StornautCodex

@Suite("R4 investigation protocol boundary")
struct R4ProtocolBoundaryTests {
    @Test
    func versionTwoSchemaIsClosedAdvisoryAndAuthorityFree() throws {
        let schemaURL = repositoryRoot.appending(
            path: "Sources/StornautCodex/Schemas/"
                + "investigation-envelope-v2.schema.json"
        )
        let data = try Data(contentsOf: schemaURL)
        let schema = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let properties = try #require(
            schema["properties"] as? [String: Any]
        )

        #expect(schema["additionalProperties"] as? Bool == false)
        #expect(Set(properties.keys) == [
            "protocolVersion",
            "investigationID",
            "runID",
            "summary",
            "coverage",
            "evidence",
            "findings",
            "candidateProposals",
            "capabilityDegradations",
        ])
        #expect(
            schemaPropertyNames(schema).isDisjoint(with: [
                "action",
                "arguments",
                "authorization",
                "cleanupAction",
                "cleanupPlan",
                "command",
                "executable",
                "executor",
                "journal",
                "moveToTrash",
                "policyDecision",
                "registeredAction",
                "trash",
            ])
        )
    }

    @Test
    func codexTargetHasNoExecutorBearingDependency() throws {
        let packageManifest = try String(
            contentsOf: repositoryRoot.appending(path: "Package.swift"),
            encoding: .utf8
        )

        #expect(
            packageManifest.contains(
                """
                name: "StornautCodex",
                            dependencies: ["StornautProcessSupport"]
                """
            )
        )
        #expect(
            packageManifest.contains(
                """
                name: "StornautProbeBridge",
                            dependencies: ["StornautCodex", "StornautCore"]
                """
            )
        )
        #expect(
            !packageManifest.contains(
                """
                name: "StornautCodex",
                            dependencies: ["StornautCore"]
                """
            )
        )
    }

    @Test
    func historicalVersionOneEnvelopeRemainsDecodable() throws {
        let data = Data(
            """
            {
              "summary": "Historical result",
              "findings": [
                {
                  "targetID": "target-v1",
                  "summary": "Advisory only"
                }
              ],
              "unresolvedTargetIDs": []
            }
            """.utf8
        )

        let envelope = try InvestigationEnvelope.decodeValidated(from: data)

        #expect(envelope.summary == "Historical result")
        #expect(envelope.findings.map(\.targetID) == ["target-v1"])
        #expect(envelope.unresolvedTargetIDs.isEmpty)
    }
}

private var repositoryRoot: URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func schemaPropertyNames(_ value: Any) -> Set<String> {
    if let dictionary = value as? [String: Any] {
        var names = Set<String>()
        if let properties = dictionary["properties"] as? [String: Any] {
            names.formUnion(properties.keys)
        }
        for nested in dictionary.values {
            names.formUnion(schemaPropertyNames(nested))
        }
        return names
    }
    if let array = value as? [Any] {
        return array.reduce(into: Set<String>()) {
            $0.formUnion(schemaPropertyNames($1))
        }
    }
    return []
}
