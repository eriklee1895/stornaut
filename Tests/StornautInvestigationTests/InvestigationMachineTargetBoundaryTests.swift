import Foundation
import Testing

@Suite("Task 39 trusted machine target boundary")
struct InvestigationMachineTargetBoundaryTests {
    @Test
    func driverRuntimeIsAuthorityClosedBeforeNativePackaging() throws {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let packageSource = try String(
            contentsOf: repositoryRoot.appending(path: "Package.swift"),
            encoding: .utf8
        )
        let supportURL = repositoryRoot.appending(
            path: "Sources/StornautInvestigationMachineDriverSupport/"
                + "InvestigationMachineDriverSupport.swift"
        )
        #expect(FileManager.default.fileExists(atPath: supportURL.path))
        let supportSource = try String(
            contentsOf: supportURL,
            encoding: .utf8
        )
        for marker in [
            "import Darwin",
            "public enum InvestigationMachineDriverSupport",
            "package static let rootAuthorityRequiredExitStatus: Int32 = 77",
            "package static let handoffUnavailableExitStatus: Int32 = 78",
            "public static func run() async -> Int32",
            "static func status(effectiveUserID: uid_t) -> Int32",
        ] {
            #expect(supportSource.contains(marker))
        }
        for forbidden in [
            "StornautCore",
            "StornautInvestigation",
            "StornautLifecycle",
            "StornautExecution",
            "Cleanup",
            "Policy",
            "RegisteredAction",
            "Process(",
            "posix_spawn",
            "CommandLine",
            "ProcessInfo.processInfo.environment",
            "NSXPC",
            "URLSession",
            "readLine(",
            "FileManager.default.",
            "FileHandle(forWritingTo:",
            "O_WRONLY",
            "O_RDWR",
            "O_CREAT",
            "Darwin.write(",
            "unlink(",
            "rename(",
            "mkdir(",
            "chmod(",
            "chown(",
            "socket",
            "connect",
            "send(",
            "recv(",
            "kill(",
        ] {
            #expect(!supportSource.contains(forbidden))
        }
        #expect(!supportSource.contains("package static func status"))
        #expect(!supportSource.contains("public static func status"))
        #expect(
            supportSource.components(separatedBy: "public static " ).count
                == 2
        )

        let supportTargetStart = try #require(packageSource.range(
            of: ".target(\n            name: \"StornautInvestigationMachineDriverSupport\""
        ))
        let supportTargetSuffix = packageSource[
            supportTargetStart.lowerBound...
        ]
        let supportTargetEnd = try #require(
            supportTargetSuffix.range(of: "\n        ),")
        )
        let supportTarget = String(
            supportTargetSuffix[..<supportTargetEnd.upperBound]
        )
        #expect(supportTarget.contains("dependencies: []"))

        let driverTargetStart = try #require(packageSource.range(
            of: ".executableTarget(\n            name: \"StornautInvestigationMachineDriver\""
        ))
        let driverTargetSuffix = packageSource[driverTargetStart.lowerBound...]
        let driverTargetEnd = try #require(
            driverTargetSuffix.range(of: "\n        ),")
        )
        let driverTarget = String(
            driverTargetSuffix[..<driverTargetEnd.upperBound]
        )
        #expect(driverTarget.contains(
            "\"StornautInvestigationMachineDriverSupport\""
        ))
        #expect(!driverTarget.contains("\"StornautInvestigationMachine\""))

        let projectSource = try String(
            contentsOf: repositoryRoot.appending(
                path: "Stornaut.xcodeproj/project.pbxproj"
            ),
            encoding: .utf8
        )
        #expect(!projectSource.contains(
            "StornautInvestigationMachineDriverNative"
        ))
    }

    @Test
    func l3c3aAddsOnlyStrictDriverBindingWithoutAdvancingTopology()
        throws
    {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        func source(_ path: String) throws -> String {
            try String(
                contentsOf: repositoryRoot.appending(path: path),
                encoding: .utf8
            )
        }

        func block(
            _ text: String,
            from startMarker: String,
            until endMarker: String
        ) throws -> String {
            let start = try #require(text.range(of: startMarker))
            let suffix = text[start.lowerBound...]
            let end = try #require(suffix.range(of: endMarker))
            return String(suffix[..<end.lowerBound])
        }

        func requireSchema(
            _ version: Int,
            declaration: String,
            in text: String,
            until endMarker: String
        ) throws {
            let declarationSource = try block(
                text,
                from: "public struct \(declaration):",
                until: endMarker
            )
            #expect(declarationSource.contains(
                "public static let schemaVersion = \(version)"
            ))
        }

        let signedContract = try source(
            "Sources/StornautInvestigation/"
                + "SignedInvestigationRuntimeContract.swift"
        )
        let machineContract = try source(
            "Sources/StornautInvestigationMachine/"
                + "SignedInvestigationRuntimeMachineContract.swift"
        )
        let appLeaf = try source(
            "Sources/StornautInvestigationDiagnostic/"
                + "InvestigationRuntimeDiagnosticAppLeaf.swift"
        )
        let composition = try source(
            "Sources/StornautInvestigationDiagnostic/"
                + "InvestigationRuntimeDiagnosticComposition.swift"
        )
        let lifecycleRegistration = try source(
            "Sources/StornautLifecycle/"
                + "LifecycleServiceRegistration.swift"
        )
        let xcodeProject = try source(
            "Stornaut.xcodeproj/project.pbxproj"
        )

        let driverBinding = try block(
            signedContract,
            from:
                "public struct "
                + "SignedInvestigationRuntimeMachineDriverBinding:",
            until: "public struct SignedInvestigationRuntimeBinding:"
        )
        for marker in [
            "public static let schemaVersion = 1",
            "strictSignedRuntimeContainer(",
            #"keys: Set(CodingKeys.allCases.map(\.rawValue))"#,
            "public let executableSHA256: String",
            "public let signingIdentifier: String",
            "public let designatedRequirementSHA256: String",
            "public let codeDirectoryHash: String",
            "public let machineClaimServiceIdentifier: String",
            "lowercaseHex(codeDirectoryHash, count: 40)",
            "lowercaseHex(codeDirectoryHash, count: 64)",
            "case schemaVersion",
            "case executableSHA256",
            "case signingIdentifier",
            "case designatedRequirementSHA256",
            "case codeDirectoryHash",
            "case machineClaimServiceIdentifier",
            "lowercaseHex(codeDirectoryHash, count: 40)",
            "lowercaseHex(codeDirectoryHash, count: 64)",
        ] {
            #expect(driverBinding.contains(marker))
        }
        #expect(
            driverBinding.components(separatedBy: "        case " ).count
                == 7
        )

        let runtimeBinding = try block(
            signedContract,
            from: "public struct SignedInvestigationRuntimeBinding:",
            until:
                "public struct "
                + "SignedInvestigationRuntimeDiagnosticConfiguration:"
        )
        for marker in [
            "public static let schemaVersion = 2",
            "public let machineDriver:",
            "SignedInvestigationRuntimeMachineDriverBinding",
            "case machineDriver",
            "machineDriver: try container.decode(",
        ] {
            #expect(runtimeBinding.contains(marker))
        }
        #expect(!runtimeBinding.contains(
            "machineDriver:\n"
                + "        SignedInvestigationRuntimeMachineDriverBinding?"
        ))
        #expect(!runtimeBinding.contains(
            "machineDriver: container.decodeIfPresent"
        ))

        try requireSchema(
            3,
            declaration: "SignedInvestigationRuntimeDiagnosticConfiguration",
            in: signedContract,
            until: "public enum SignedInvestigationRuntimeDenialKind:"
        )
        try requireSchema(
            4,
            declaration: "SignedInvestigationCapabilityEvidenceReceipt",
            in: signedContract,
            until: "public struct SignedInvestigationRuntimeReport:"
        )
        try requireSchema(
            4,
            declaration: "SignedInvestigationRuntimeReport",
            in: signedContract,
            until: "public struct SignedInvestigationRuntimeAdmissionReceipt:"
        )
        for (declaration, version, nextDeclaration) in [
            (
                "SignedInvestigationRuntimeMachineCaseEvidence",
                3,
                "SignedInvestigationRuntimeFailureMatrix"
            ),
            (
                "SignedInvestigationRuntimeFailureMatrix",
                3,
                "SignedInvestigationRuntimeMachineReport"
            ),
            (
                "SignedInvestigationRuntimeMachineReport",
                3,
                "SignedInvestigationRuntimeLifecycleResidueRecord"
            ),
            (
                "SignedInvestigationRuntimeLifecycleResidueRecord",
                2,
                "SignedInvestigationRuntimeMachineEvidenceBundle"
            ),
        ] {
            try requireSchema(
                version,
                declaration: declaration,
                in: machineContract,
                until: "public struct \(nextDeclaration):"
            )
        }
        let evidenceBundle = try block(
            machineContract,
            from:
                "public struct "
                + "SignedInvestigationRuntimeMachineEvidenceBundle:",
            until:
                "private struct "
                + "CompletedMachineConfiguration: Decodable"
        )
        #expect(evidenceBundle.contains(
            "public static let schemaVersion = 7"
        ))

        let leafConfiguration = try block(
            appLeaf,
            from: "private struct Configuration: Decodable",
            until: "private enum Scenario:"
        )
        let leafBinding = try block(
            appLeaf,
            from: "private struct Binding: Decodable",
            until: "private struct MachineDriverBinding: Decodable"
        )
        let leafDriverBinding = try block(
            appLeaf,
            from: "private struct MachineDriverBinding: Decodable",
            until: "private struct DynamicCodingKey:"
        )
        #expect(leafConfiguration.contains("schemaVersion == 3"))
        #expect(leafBinding.contains("schemaVersion == 2"))
        #expect(leafBinding.contains("case machineDriver"))
        #expect(leafDriverBinding.contains("schemaVersion == 1"))
        for marker in [
            "strictContainer(",
            #"keys: Set(CodingKeys.allCases.map(\.rawValue))"#,
            "case schemaVersion",
            "case executableSHA256",
            "case signingIdentifier",
            "case designatedRequirementSHA256",
            "case codeDirectoryHash",
            "case machineClaimServiceIdentifier",
        ] {
            #expect(leafDriverBinding.contains(marker))
        }
        #expect(
            leafDriverBinding.components(
                separatedBy: "        case "
            ).count == 7
        )

        let observation = try block(
            composition,
            from:
                "package struct "
                + "InvestigationRuntimeDiagnosticBindingObservation:",
            until:
                "private actor "
                + "InvestigationRuntimeDiagnosticTransportOwner:"
        )
        for marker in [
            "LifecycleBundleSigningIdentityReader()",
            "contract.machineDriverExecutableURL",
            "Contents/MacOS/",
            "StornautInvestigationMachineDriver",
            "machineDriverEvidence.executableSHA256",
            "machineDriverEvidence.identity.signingIdentifier",
            "machineDriverDesignatedRequirementSHA256",
            "machineDriverCodeDirectoryHash",
            "machineClaimServiceIdentifier",
            "binding.machineDriver",
        ] {
            #expect(observation.contains(marker))
        }

        let signingIdentifier =
            "com.eriklee.stornaut.investigation.machine-driver"
        let claimServiceIdentifier =
            "com.eriklee.stornaut.lifecycle.machine-claim"
        for text in [driverBinding, leafDriverBinding, lifecycleRegistration] {
            #expect(text.contains(signingIdentifier))
            #expect(text.contains(claimServiceIdentifier))
        }

        let l3c3aSources = [driverBinding, leafDriverBinding, observation]
        for text in l3c3aSources {
            for forbidden in [
                "StornautExecution",
                "ActionExecutor",
                "TrashMoving",
                "RegisteredAction",
                "MoveToTrash",
                "posix_spawn",
                "Process(",
                "CommandLine",
                "ProcessInfo.processInfo.environment",
                "NSXPCListener",
                "NSXPCConnection",
                "LifecycleMachineRetirementHandle",
                "Launcher",
                "launcher",
                "signedInvestigationRuntimeReady",
                "signedRuntimeReady",
                "Readiness",
                "readiness",
                "arguments:",
                "environment:",
                "fileDescriptor:",
            ] {
                #expect(!text.contains(forbidden))
            }
        }

        // Temporary L3c3a checkpoint contract. L3c3b must replace this
        // assertion with exact diagnostic-only native driver packaging.
        #expect(!xcodeProject.contains(
            "StornautInvestigationMachineDriver"
        ))
    }

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
        let driverTargetStart = try #require(packageSource.range(
            of: ".executableTarget(\n            name: \"StornautInvestigationMachineDriver\""
        ))
        let driverTargetSuffix = packageSource[
            driverTargetStart.lowerBound...
        ]
        let driverTargetEnd = try #require(
            driverTargetSuffix.range(of: "\n        ),")
        )
        let driverTargetSource = String(
            driverTargetSuffix[..<driverTargetEnd.upperBound]
        )
        #expect(driverTargetSource.contains(
            "dependencies: [\n                "
                + "\"StornautInvestigationMachineDriverSupport\",\n"
                + "            ]"
        ))
        #expect(driverTargetSource.contains(
            "path: \"Tools/StornautInvestigationMachineDriver\""
        ))
        for forbidden in [
            "StornautLifecycle",
            "StornautInvestigationRuntime",
            "StornautInvestigationDiagnostic",
            "StornautExecution",
            "StornautCore",
            "StornautCodex",
        ] {
            #expect(!driverTargetSource.contains(forbidden))
        }
        #expect(!packageSource.contains(
            ".executable(\n            name: \"StornautInvestigationMachineDriver\""
        ))

        let driverHostURL = repositoryRoot.appending(
            path: "Sources/StornautInvestigationMachine/"
                + "InvestigationMachineDriverHost.swift"
        )
        let driverMainURL = repositoryRoot.appending(
            path: "Tools/StornautInvestigationMachineDriver/main.swift"
        )
        let scenarioRunnerURL = repositoryRoot.appending(
            path: "Sources/StornautInvestigationMachine/"
                + "InvestigationFixedScenarioRunner.swift"
        )
        let scenarioDriverURL = repositoryRoot.appending(
            path: "Sources/StornautInvestigationMachine/"
                + "InvestigationMachineScenarioDriver.swift"
        )
        #expect(FileManager.default.fileExists(atPath: driverHostURL.path))
        #expect(FileManager.default.fileExists(atPath: driverMainURL.path))
        #expect(FileManager.default.fileExists(atPath: scenarioRunnerURL.path))
        #expect(FileManager.default.fileExists(atPath: scenarioDriverURL.path))
        let driverHost = try String(
            contentsOf: driverHostURL,
            encoding: .utf8
        )
        let driverMain = try String(
            contentsOf: driverMainURL,
            encoding: .utf8
        )
        let scenarioRunner = try String(
            contentsOf: scenarioRunnerURL,
            encoding: .utf8
        )
        let scenarioDriver = try String(
            contentsOf: scenarioDriverURL,
            encoding: .utf8
        )
        for marker in [
            "package enum InvestigationMachineDriverEntryPoint",
            "package static func run() async -> Int32",
            "actor InvestigationMachineDriverHost",
            "struct StrictMachineRetirementClaimSource",
            "LifecycleMachineClaimXPCClient()",
            "struct InstalledMachineRetirementHelperSigningVerifier",
            "InvestigationMachineRetirementClaimStore()",
            "InvestigationLifecycleTopologyCollectionRequest(",
            "DarwinInvestigationLifecycleTopologyObserver(",
        ] {
            #expect(driverHost.contains(marker))
        }
        #expect(
            driverHost.components(separatedBy: "package " ).count == 3
        )
        for internalDeclaration in [
            "protocol InvestigationMachineRetirementHandleHandoff",
            "protocol InvestigationMachineRetirementClaiming",
            "struct InvestigationMachineTopologyAuthority",
            "actor InvestigationMachineDriverHost",
        ] {
            #expect(driverHost.contains(internalDeclaration))
            #expect(!driverHost.contains("public \(internalDeclaration)"))
            #expect(!driverHost.contains("package \(internalDeclaration)"))
        }
        #expect(driverMain.contains(
            "import StornautInvestigationMachineDriverSupport"
        ))
        #expect(driverMain.contains(
            "await InvestigationMachineDriverSupport.run()"
        ))
        #expect(!driverMain.contains("CommandLine"))
        #expect(!driverMain.contains("ProcessInfo"))
        for source in [driverHost, driverMain] {
            for forbidden in [
                "StornautExecution",
                "StornautInvestigationDiagnostic",
                "ActionExecutor",
                "TrashMoving",
                "RegisteredAction",
                "SignedInvestigationRuntimeMachineAssembler",
                "SignedInvestigationRuntimeMachineVerifier",
                "signedInvestigationRuntimeReady",
                "JSONEncoder",
                "JSONDecoder",
                "PropertyListEncoder",
                "PropertyListDecoder",
                "NSXPCConnection",
                "URLSession",
                "posix_spawn",
                "removeItem",
                "moveItem",
                "copyItem",
                "CommandLine.arguments",
                "ProcessInfo.processInfo.environment",
                "readLine(",
                "kill(",
            ] {
                #expect(!source.contains(forbidden))
            }
        }
        for marker in [
            "actor InvestigationFixedScenarioRunner",
            "typealias Operation = @Sendable () async throws",
            "InvestigationFixedScenarioObservation",
            "InvestigationFixedScenarioTrace",
        ] {
            #expect(scenarioRunner.contains(marker))
        }
        for marker in [
            "actor InvestigationMachineScenarioDriver",
            "struct InvestigationMachineScenarioAttempt",
            "struct InvestigationMachineSyntheticSuccessEvidence",
            "async throws -> SignedInvestigationRuntimeFailureMatrix",
            "let authority = try await attempt.host.run()",
            "try await attempt.runner.consumeObservation()",
        ] {
            #expect(scenarioDriver.contains(marker))
        }
        let scenarioSources = scenarioRunner + "\n" + scenarioDriver
        let accessDeclaration = try NSRegularExpression(
            pattern: #"(?m)^\s*(?:(?:@[A-Za-z_][A-Za-z0-9_.]*(?:\([^)]*\))?|final|indirect|nonisolated|override|required|static|class|mutating|nonmutating|convenience|distributed)\s+)*(?:public|package)(?:\(set\))?\s+"#
        )
        #expect(accessDeclaration.firstMatch(
            in: scenarioSources,
            range: NSRange(
                scenarioSources.startIndex...,
                in: scenarioSources
            )
        ) == nil)
        for source in [scenarioRunner, scenarioDriver] {
            for forbidden in [
                "import StornautExecution",
                "import StornautInvestigationDiagnostic",
                "import StornautCodex",
                "ActionExecutor",
                "TrashMoving",
                "RegisteredAction",
                "FileManagerTrashAdapter",
                "CleanupExecutionRuntime",
                "CleanupExecutionCoordinator",
                "CleanupActionExecuting",
                "CleanupAuthorizationController",
                "ExecutionAuthorization",
                "ActionPolicyGate",
                "CleanupPolicyGate",
                "MoveToTrash",
                "ProposedCleanupAction",
                "CleanupAction",
                "SignedInvestigationCapabilityEvidenceReceipt",
                "SignedInvestigationRuntimeMachineAssembler",
                "SignedInvestigationRuntimeMachineVerifier",
                "SignedInvestigationRuntimeMachineReport",
                "signedInvestigationRuntimeReady",
                "signedRuntimeReady",
                "readiness",
                "Readiness",
                "Codable",
                "JSONEncoder",
                "JSONDecoder",
                "PropertyListEncoder",
                "PropertyListDecoder",
                "FileManager.default",
                "NSXPCConnection",
                "URLSession",
                "NWConnection",
                "WebSocket",
                "CFStream",
                "socket",
                "connect",
                "send",
                "recv",
                "posix_spawn",
                "removeItem",
                "moveItem",
                "copyItem",
                "createDirectory",
                "createFile",
                "CommandLine.arguments",
                "ProcessInfo.processInfo.environment",
                "readLine(",
                "kill(",
            ] {
                #expect(!source.contains(forbidden))
            }
        }

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
