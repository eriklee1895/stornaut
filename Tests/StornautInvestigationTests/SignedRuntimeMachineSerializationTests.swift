import Foundation
import Testing
import StornautCore
import StornautInvestigation
@testable import StornautInvestigationMachine

@Suite("Task 39 machine report serialization", .serialized)
struct SignedRuntimeMachineSerializationTests {
    @Test
    func machineReportRoundTripsAndRejectsCaseOrFingerprintTamper()
        throws
    {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configurations = try fixture.machineConfigurations()
        fixture.materializeOutputs()
        let artifacts = try configurations.map {
            try fixture.caseEvidence(configuration: $0)
        }
        let success = try #require(
            configurations.first { $0.scenario == .success }
        )
        let report = try SignedInvestigationRuntimeMachineAssembler()
            .assemble(
                configurations: configurations,
                artifacts: artifacts,
                capabilityMetadata: fixture.capabilityMetadata(),
                capabilityWorker: fixture.capabilityWorker(
                    investigationID: success.nonce,
                    evidenceBindingSHA256:
                        success.capabilityEvidenceBindingSHA256()
                ),
                capabilityLifecycleIntegrity:
                    fixture.capabilityLifecycleIntegrity(),
                capabilityRepository:
                    fixture.capabilityRepositoryEvidence(),
                now: artifacts.map(\.completedAt).max()!
            )
        let encoded = try report.canonicalJSONData()
        let decoded = try JSONDecoder().decode(
            SignedInvestigationRuntimeMachineReport.self,
            from: encoded
        )

        #expect(decoded == report)
        #expect(
            decoded.schemaVersion
                == SignedInvestigationRuntimeMachineReport.schemaVersion
        )
        #expect(
            decoded.failureMatrix.schemaVersion
                == SignedInvestigationRuntimeFailureMatrix.schemaVersion
        )
        #expect(
            decoded.failureMatrix.cases.allSatisfy {
                $0.schemaVersion
                    == SignedInvestigationRuntimeMachineCaseEvidence
                        .schemaVersion
            }
        )
        #expect(
            report.verdict
                == .evidenceContractValidatedMachineAdmissionPending
        )
        #expect(
            String(decoding: encoded, as: UTF8.self)
                .contains("signedInvestigationRuntimeReady") == false
        )
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try SignedInvestigationRuntimeAdmissionReceipt(
                report: report.successReport
            )
        }
        #expect(
            Set(report.nonClaims)
                == Set(SignedInvestigationRuntimeNonClaim.allCases)
        )
        #expect(
            try SignedInvestigationRuntimeMachineVerifier()
                .verifyCandidate(
                    report,
                    configurations: configurations,
                    artifacts: artifacts,
                    capabilityMetadata: fixture.capabilityMetadata(),
                    capabilityWorker: fixture.capabilityWorker(
                        investigationID: success.nonce,
                        evidenceBindingSHA256:
                            success.capabilityEvidenceBindingSHA256()
                    ),
                    capabilityLifecycleIntegrity:
                        fixture.capabilityLifecycleIntegrity(),
                    capabilityRepository:
                        fixture.capabilityRepositoryEvidence(),
                    now: artifacts.map(\.completedAt).max()!
                ) == report
        )

        var object = try #require(
            JSONSerialization.jsonObject(with: encoded)
                as? [String: Any]
        )
        var legacyReport = object
        legacyReport["schemaVersion"] = 1
        let legacyReportData = try JSONSerialization.data(
            withJSONObject: legacyReport,
            options: [.sortedKeys]
        )
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try JSONDecoder().decode(
                SignedInvestigationRuntimeMachineReport.self,
                from: legacyReportData
            )
        }

        var legacyMatrix = object
        var matrix = try #require(
            legacyMatrix["failureMatrix"] as? [String: Any]
        )
        matrix["schemaVersion"] = 1
        legacyMatrix["failureMatrix"] = matrix
        let legacyMatrixData = try JSONSerialization.data(
            withJSONObject: legacyMatrix,
            options: [.sortedKeys]
        )
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try JSONDecoder().decode(
                SignedInvestigationRuntimeMachineReport.self,
                from: legacyMatrixData
            )
        }

        object["matrixSHA256"] = String(repeating: "0", count: 64)
        let tampered = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try JSONDecoder().decode(
                SignedInvestigationRuntimeMachineReport.self,
                from: tampered
            )
        }

        var promotedObject = try #require(
            JSONSerialization.jsonObject(with: encoded)
                as? [String: Any]
        )
        var promotedSuccess = try #require(
            promotedObject["successReport"] as? [String: Any]
        )
        promotedSuccess["verdict"] = [
            "signedInvestigationRuntimeReady": [:],
        ]
        promotedObject["successReport"] = promotedSuccess
        promotedObject["reportSHA256"] = String(repeating: "0", count: 64)
        let promoted = try JSONSerialization.data(
            withJSONObject: promotedObject,
            options: [.sortedKeys]
        )
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try JSONDecoder().decode(
                SignedInvestigationRuntimeMachineReport.self,
                from: promoted
            )
        }
    }

    @Test
    func machineReportRejectsSuccessReportFromDifferentObservation()
        throws
    {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configurations = try fixture.machineConfigurations()
        fixture.materializeOutputs()
        let artifacts = try configurations.map {
            try fixture.caseEvidence(configuration: $0)
        }
        let success = try #require(
            configurations.first { $0.scenario == .success }
        )
        let assembler = SignedInvestigationRuntimeMachineAssembler()
        let report = try assembler.assemble(
            configurations: configurations,
            artifacts: artifacts,
            capabilityMetadata: fixture.capabilityMetadata(),
            capabilityWorker: fixture.capabilityWorker(
                investigationID: success.nonce,
                evidenceBindingSHA256:
                    success.capabilityEvidenceBindingSHA256(),
                completedAt: fixture.now.addingTimeInterval(-1)
            ),
            capabilityLifecycleIntegrity:
                fixture.capabilityLifecycleIntegrity(),
            capabilityRepository:
                fixture.capabilityRepositoryEvidence(),
            now: fixture.now.addingTimeInterval(30)
        )
        let alternateArtifacts = try configurations.map {
            try fixture.caseEvidence(
                configuration: $0,
                capabilityCompletedAt:
                    fixture.now.addingTimeInterval(-2)
            )
        }
        let alternate = try assembler.assemble(
            configurations: configurations,
            artifacts: alternateArtifacts,
            capabilityMetadata: fixture.capabilityMetadata(),
            capabilityWorker: fixture.capabilityWorker(
                investigationID: success.nonce,
                evidenceBindingSHA256:
                    success.capabilityEvidenceBindingSHA256(),
                completedAt: fixture.now.addingTimeInterval(-2)
            ),
            capabilityLifecycleIntegrity:
                fixture.capabilityLifecycleIntegrity(),
            capabilityRepository:
                fixture.capabilityRepositoryEvidence(),
            now: fixture.now.addingTimeInterval(30)
        )
        var object = try #require(
            JSONSerialization.jsonObject(
                with: report.canonicalJSONData()
            ) as? [String: Any]
        )
        let alternateObject = try #require(
            JSONSerialization.jsonObject(
                with: alternate.canonicalJSONData()
            ) as? [String: Any]
        )
        object["successReport"] = alternateObject["successReport"]
        object["reportSHA256"] = alternateObject["reportSHA256"]
        let mixed = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )

        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try JSONDecoder().decode(
                SignedInvestigationRuntimeMachineReport.self,
                from: mixed
            )
        }
    }

    @Test
    func machineEvidenceBundleStrictlyRoundTripsAndRebuildsReport()
        throws
    {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configurations = try fixture.machineConfigurations()
        fixture.materializeOutputs()
        let artifacts = try configurations.map {
            try fixture.caseEvidence(configuration: $0)
        }
        let success = try #require(
            configurations.first { $0.scenario == .success }
        )
        let bundle = try SignedInvestigationRuntimeMachineEvidenceBundle(
            configurations: configurations,
            artifacts: artifacts,
            lifecycleResidueRecords:
                fixture.lifecycleResidueRecords(
                    artifacts: artifacts
                ),
            capabilityMetadata: fixture.capabilityMetadata(),
            capabilityWorker: fixture.capabilityWorker(
                investigationID: success.nonce,
                evidenceBindingSHA256:
                    success.capabilityEvidenceBindingSHA256()
            ),
            capabilityLifecycleIntegrity:
                fixture.capabilityLifecycleIntegrity(),
            capabilityRepository:
                fixture.capabilityRepositoryEvidence()
        )
        let data = try bundle.canonicalJSONData()
        let decoded = try JSONDecoder().decode(
            SignedInvestigationRuntimeMachineEvidenceBundle.self,
            from: data
        )
        let report = try SignedInvestigationRuntimeMachineAssembler()
            .assemble(
                evidence: decoded,
                now: artifacts.map(\.completedAt).max()!
            )

        #expect(decoded == bundle)
        #expect(
            decoded.schemaVersion
                == SignedInvestigationRuntimeMachineEvidenceBundle
                    .schemaVersion
        )
        #expect(
            decoded.capabilityWorker.completedAt
                == fixture.now.addingTimeInterval(-1)
        )
        #expect(
            try SignedInvestigationRuntimeMachineVerifier()
                .verifyCandidate(
                    report,
                    evidence: decoded,
                    now: artifacts.map(\.completedAt).max()!
                ) == report
        )

        let alternateArtifacts = try configurations.map {
            try fixture.caseEvidence(
                configuration: $0,
                startedAt: fixture.now.addingTimeInterval(1),
                completedAt: fixture.now.addingTimeInterval(31)
            )
        }
        let alternateReport =
            try SignedInvestigationRuntimeMachineAssembler()
            .assemble(
                configurations: configurations,
                artifacts: alternateArtifacts,
                capabilityMetadata: fixture.capabilityMetadata(),
                capabilityWorker: fixture.capabilityWorker(
                    investigationID: success.nonce,
                    evidenceBindingSHA256:
                        success.capabilityEvidenceBindingSHA256()
                ),
                capabilityLifecycleIntegrity:
                    fixture.capabilityLifecycleIntegrity(),
                capabilityRepository:
                    fixture.capabilityRepositoryEvidence(),
                now: alternateArtifacts.map(\.completedAt).max()!
            )
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try SignedInvestigationRuntimeMachineVerifier()
                .verifyCandidate(
                    alternateReport,
                    evidence: decoded,
                    now: alternateArtifacts.map(\.completedAt).max()!
                )
        }

        var object = try #require(
            JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
        object["unexpected"] = true
        let unknown = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try JSONDecoder().decode(
                SignedInvestigationRuntimeMachineEvidenceBundle.self,
                from: unknown
            )
        }

        object.removeValue(forKey: "unexpected")
        var legacyBundle = object
        legacyBundle["schemaVersion"] = 5
        let legacyBundleData = try JSONSerialization.data(
            withJSONObject: legacyBundle,
            options: [.sortedKeys]
        )
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try JSONDecoder().decode(
                SignedInvestigationRuntimeMachineEvidenceBundle.self,
                from: legacyBundleData
            )
        }

        var missingTargetSet = object
        var cases = try #require(
            missingTargetSet["artifacts"] as? [[String: Any]]
        )
        cases[0].removeValue(forKey: "targetSetFingerprint")
        missingTargetSet["artifacts"] = cases
        let missingTargetSetData = try JSONSerialization.data(
            withJSONObject: missingTargetSet,
            options: [.sortedKeys]
        )
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try JSONDecoder().decode(
                SignedInvestigationRuntimeMachineEvidenceBundle.self,
                from: missingTargetSetData
            )
        }

        var legacyCase = object
        var legacyCases = try #require(
            legacyCase["artifacts"] as? [[String: Any]]
        )
        legacyCases[0]["schemaVersion"] = 1
        legacyCase["artifacts"] = legacyCases
        let legacyCaseData = try JSONSerialization.data(
            withJSONObject: legacyCase,
            options: [.sortedKeys]
        )
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try JSONDecoder().decode(
                SignedInvestigationRuntimeMachineEvidenceBundle.self,
                from: legacyCaseData
            )
        }

        var foreignTargetSet = object
        var foreignCases = try #require(
            foreignTargetSet["artifacts"] as? [[String: Any]]
        )
        foreignCases[0]["targetSetFingerprint"] =
            String(repeating: "d", count: 64)
        foreignTargetSet["artifacts"] = foreignCases
        let foreignTargetSetData = try JSONSerialization.data(
            withJSONObject: foreignTargetSet,
            options: [.sortedKeys]
        )
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try JSONDecoder().decode(
                SignedInvestigationRuntimeMachineEvidenceBundle.self,
                from: foreignTargetSetData
            )
        }

        var worker = try #require(
            object["capabilityWorker"] as? [String: Any]
        )
        worker.removeValue(forKey: "completedAt")
        object["capabilityWorker"] = worker
        let missingTimestamp = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try JSONDecoder().decode(
                SignedInvestigationRuntimeMachineEvidenceBundle.self,
                from: missingTimestamp
            )
        }

        for target in MachineEvidenceBundleTamperTarget.allCases {
            #expect(
                throws:
                    SignedInvestigationRuntimeContractError.invalidReport,
                "target=\(target)"
            ) {
                _ = try JSONDecoder().decode(
                    SignedInvestigationRuntimeMachineEvidenceBundle.self,
                    from: try addingMachineBundleUnknownField(
                        to: data,
                        target: target
                    )
                )
            }
        }
    }
}

private enum MachineEvidenceBundleTamperTarget:
    String,
    CaseIterable,
    CustomStringConvertible
{
    case metadata
    case worker
    case workerCapability
    case lifecycleIntegrity
    case repository

    var description: String {
        rawValue
    }
}

private func addingMachineBundleUnknownField(
    to data: Data,
    target: MachineEvidenceBundleTamperTarget
) throws -> Data {
    var object = try #require(
        JSONSerialization.jsonObject(with: data)
            as? [String: Any]
    )
    switch target {
    case .metadata:
        var metadata = try #require(
            object["capabilityMetadata"] as? [String: Any]
        )
        metadata["unexpected"] = true
        object["capabilityMetadata"] = metadata
    case .worker:
        var worker = try #require(
            object["capabilityWorker"] as? [String: Any]
        )
        worker["unexpected"] = true
        object["capabilityWorker"] = worker
    case .workerCapability:
        var worker = try #require(
            object["capabilityWorker"] as? [String: Any]
        )
        var capabilities = try #require(
            worker["capabilities"] as? [[String: Any]]
        )
        capabilities[0]["unexpected"] = true
        worker["capabilities"] = capabilities
        object["capabilityWorker"] = worker
    case .lifecycleIntegrity:
        var integrity = try #require(
            object["capabilityLifecycleIntegrity"]
                as? [[String: Any]]
        )
        integrity[0]["unexpected"] = true
        object["capabilityLifecycleIntegrity"] = integrity
    case .repository:
        var repository = try #require(
            object["capabilityRepository"] as? [String: Any]
        )
        repository["unexpected"] = true
        object["capabilityRepository"] = repository
    }
    return try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys]
    )
}
