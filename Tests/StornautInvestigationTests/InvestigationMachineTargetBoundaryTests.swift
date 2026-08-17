import Foundation
import Testing

@Suite("Task 39 trusted machine target boundary")
struct InvestigationMachineTargetBoundaryTests {
    @Test
    func trustedMachineImplementationLivesOnlyInTheNonProductTarget()
        throws
    {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let packageSource = try String(
            contentsOf: repositoryRoot.appending(path: "Package.swift"),
            encoding: .utf8
        )
        let investigationSource = repositoryRoot.appending(
            path: "Sources/StornautInvestigation/"
                + "SignedInvestigationRuntimeMachineContract.swift"
        )
        let machineSource = repositoryRoot.appending(
            path: "Sources/StornautInvestigationMachine/"
                + "SignedInvestigationRuntimeMachineContract.swift"
        )

        #expect(!FileManager.default.fileExists(
            atPath: investigationSource.path
        ))
        #expect(FileManager.default.fileExists(atPath: machineSource.path))

        let targetStart = try #require(packageSource.range(
            of: ".target(\n            name: \"StornautInvestigationMachine\""
        ))
        let targetSuffix = packageSource[targetStart.lowerBound...]
        let targetEnd = try #require(targetSuffix.range(of: "\n        ),"))
        let targetSource = String(targetSuffix[..<targetEnd.upperBound])
        for dependency in [
            "\"StornautCodex\"",
            "\"StornautCore\"",
            "\"StornautInvestigation\"",
            "\"StornautInvestigationRuntime\"",
            "\"StornautLifecycle\"",
        ] {
            #expect(targetSource.contains(dependency))
        }
        for forbidden in [
            "StornautExecution",
            "StornautInvestigationDiagnostic",
        ] {
            #expect(!targetSource.contains(forbidden))
        }

        #expect(!packageSource.contains(
            ".library(\n            name: \"StornautInvestigationMachine\""
        ))
        #expect(!packageSource.contains(
            ".executable(\n            name: \"StornautInvestigationMachine\""
        ))

        let machineText = try String(
            contentsOf: machineSource,
            encoding: .utf8
        )
        let collectorSource = try String(
            contentsOf: repositoryRoot.appending(
                path: "Sources/StornautInvestigationMachine/"
                    + "InvestigationLifecycleTopologyCollector.swift"
            ),
            encoding: .utf8
        )
        let serviceSource = try String(
            contentsOf: repositoryRoot.appending(
                path: "Sources/StornautInvestigationMachine/"
                    + "FixedLifecycleServiceProbe.swift"
            ),
            encoding: .utf8
        )
        for trustedDeclaration in [
            "protocol SignedInvestigationRuntimeSealedCohortAuthority",
            "struct SignedInvestigationRuntimeMachineAssembler",
            "struct SignedInvestigationRuntimeMachineVerifier",
        ] {
            #expect(machineText.contains(trustedDeclaration))
            #expect(!machineText.contains("public \(trustedDeclaration)"))
            #expect(!machineText.contains("package \(trustedDeclaration)"))
        }
        for forbidden in [
            "import StornautExecution",
            "import StornautLifecycle",
            "ActionExecutor",
            "TrashMoving",
            "FileManagerTrashAdapter",
            "signedInvestigationRuntimeReady",
        ] {
            #expect(!machineText.contains(forbidden))
        }
        for source in [collectorSource, serviceSource] {
            for forbidden in [
                "StornautExecution",
                "StornautInvestigationDiagnostic",
                "ActionExecutor",
                "TrashMoving",
                "RegisteredAction",
                "SignedInvestigationRuntimeMachineAssembler",
                "SignedInvestigationRuntimeMachineVerifier",
                "signedInvestigationRuntimeReady",
                "Codable",
                "JSONEncoder",
                "JSONDecoder",
                "bootout",
                "bootstrap system",
                "FileManager.default.remove",
            ] {
                #expect(!source.contains(forbidden))
            }
        }
    }
}
