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
        let releaseBoundary = try String(
            contentsOf: repositoryRoot.appending(
                path: "scripts/verify-app-release-boundaries"
            ),
            encoding: .utf8
        )
        let driverLoopStart = try #require(releaseBoundary.range(
            of: "for app_without_machine_driver in \\\n"
        ))
        let driverLoopSuffix = releaseBoundary[driverLoopStart.lowerBound...]
        let driverLoopEnd = try #require(
            driverLoopSuffix.range(of: "\ndone")
        )
        let driverLoop = String(
            driverLoopSuffix[..<driverLoopEnd.upperBound]
        )
        for appVariable in [
            "\"$debug_app\"",
            "\"$release_app\"",
            "\"$diagnostic_debug_app\"",
        ] {
            #expect(
                driverLoop.components(separatedBy: appVariable).count
                    == 2
            )
        }
        let exactDriverPath =
            "$app_without_machine_driver/Contents/MacOS/StornautInvestigationMachineDriver"
        #expect(
            driverLoop.components(separatedBy: exactDriverPath).count
                == 3
        )
        #expect(driverLoop.contains("test ! -e"))
        #expect(driverLoop.contains("test ! -L"))
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
        let claimSource = repositoryRoot.appending(
            path: "Sources/StornautInvestigationMachine/"
                + "InvestigationMachineRetirementClaim.swift"
        )
        #expect(FileManager.default.fileExists(atPath: claimSource.path))
        let claimText = try String(
            contentsOf: claimSource,
            encoding: .utf8
        )
        for marker in [
            "protocol InvestigationMachineRetirementClaimSource",
            "struct InvestigationMachineRetirementClaim",
            "actor InvestigationMachineRetirementClaimStore",
        ] {
            #expect(claimText.contains(marker))
            #expect(!claimText.contains("public \(marker)"))
            #expect(!claimText.contains("package \(marker)"))
        }
        for forbidden in [
            "Codable",
            "JSONDecoder",
            "JSONEncoder",
            "PropertyListDecoder",
            "PropertyListEncoder",
            "NSXPCConnection",
            "LifecycleSupervisorXPCWire",
            "LifecycleInteractiveSessionXPCWire",
        ] {
            #expect(!claimText.contains(forbidden))
        }
        let xpcSource = try String(
            contentsOf: repositoryRoot.appending(
                path: "Sources/StornautLifecycle/LifecycleSupervisorXPC.swift"
            ),
            encoding: .utf8
        )
        #expect(xpcSource.contains("LifecycleMachineRetirementClaimRequest"))
        #expect(xpcSource.contains("LifecycleMachineRetirementClaimResponse"))
        #expect(
            xpcSource.contains(
                "@objc public protocol LifecycleMachineClaimXPCWire"
            )
        )
        for method in [
            "func attestHelper(",
            "func handle(",
            "func handleInteractive(",
            "func claimMachineRetirement(",
        ] {
            #expect(xpcSource.components(separatedBy: method).count == 2)
        }
        let exportedMethodCount = xpcSource
            .components(separatedBy: "@objc public protocol")
            .dropFirst()
            .map { protocolSource in
                protocolSource
                    .prefix { $0 != "}" }
                    .components(separatedBy: "func " )
                    .count - 1
            }
            .reduce(0, +)
        #expect(exportedMethodCount == 4)
        let escrowSource = try String(
            contentsOf: repositoryRoot.appending(
                path: "Sources/StornautLifecycle/"
                    + "LifecycleMachineRetirementEscrow.swift"
            ),
            encoding: .utf8
        )
        #expect(
            escrowSource.contains(
                "machineDriverIdentity: LifecycleProcessIdentity"
            )
        )
        #expect(
            escrowSource.contains(
                "admission: any LifecycleMachineDriverClaimAdmitting"
            )
        )
        #expect(!escrowSource.contains("public func claim(\n        _ request: LifecycleMachineRetirementClaimRequest,\n        authorized: Bool"))
        #expect(!escrowSource.contains("package func claim(\n        _ request: LifecycleMachineRetirementClaimRequest,\n        authorized: Bool"))
        #expect(escrowSource.contains("let tokenSHA256: Data"))
        let entryStart = try #require(
            escrowSource.range(of: "fileprivate struct Entry {")
        )
        let entrySuffix = escrowSource[entryStart.lowerBound...]
        let entryEnd = try #require(entrySuffix.range(of: "\n    }"))
        let entrySource = String(entrySuffix[..<entryEnd.upperBound])
        #expect(!entrySource.contains("LifecycleMachineRetirementHandle"))
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
