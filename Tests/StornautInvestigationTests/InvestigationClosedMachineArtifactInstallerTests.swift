import Foundation
import Testing

@Suite("Task 39 ii-c-a closed machine artifact packaging")
struct InvestigationClosedMachineArtifactInstallerTests {
    private let machineTools = [
        (
            target: "StornautInvestigationMachineDriverNative",
            product: "StornautInvestigationMachineDriver",
            support: "StornautInvestigationMachineDriverSupport",
            identifier: "com.eriklee.stornaut.investigation.machine-driver"
        ),
        (
            target: "StornautInvestigationMachineGateNative",
            product: "StornautInvestigationMachineGate",
            support: "StornautInvestigationMachineGateSupport",
            identifier: "com.eriklee.stornaut.investigation.machine-gate"
        ),
        (
            target: "StornautInvestigationMachineGateCoordinatorNative",
            product: "StornautInvestigationMachineGateCoordinator",
            support: "StornautInvestigationMachineGateCoordinatorSupport",
            identifier:
                "com.eriklee.stornaut.investigation.machine-gate-coordinator"
        ),
    ]

    @Test
    func packageExportsNativeMachineToolSupportProducts() throws {
        let package = try source("Package.swift")
        for tool in machineTools.dropFirst() {
            #expect(package.contains(
                ".library(\n            name: \"\(tool.support)\","
            ))
            #expect(package.contains(
                "type: .static,\n            targets: [\"\(tool.support)\"]"
            ))
        }
        #expect(package.contains(
            "path: \"tools/StornautInvestigationMachineGate\""
        ))
        #expect(package.contains(
            "name: \"StornautInvestigationBuildReceiptGenerator\""
        ))
        #expect(package.contains(
            "swiftSettings: [.unsafeFlags([\"-parse-as-library\"])]"
        ))

        let gate = try source(
            "Sources/StornautInvestigationMachineGateSupport/"
                + "InvestigationMachineFixedGateLauncher.swift"
        )
        let coordinator = try source(
            "Sources/StornautInvestigationMachineGateCoordinatorSupport/"
                + "InvestigationMachineGateCoordinatorComposition.swift"
        )
        #expect(gate.contains(
            "public enum InvestigationMachineGateSupport"
        ))
        #expect(gate.contains("public static func run() -> Int32"))
        #expect(coordinator.contains(
            "public enum InvestigationMachineGateCoordinatorSupport"
        ))
        #expect(coordinator.contains("public static func run() async -> Int32"))
        #expect(gate.components(
            separatedBy: "public "
        ).count == 3)
        #expect(coordinator.components(
            separatedBy: "public "
        ).count == 3)
    }

    @Test
    func diagnosticProjectPackagesThreeSignedMachineTools() throws {
        let project = try source("Stornaut.xcodeproj/project.pbxproj")
        let scheme = try source(
            "Stornaut.xcodeproj/xcshareddata/xcschemes/"
                + "StornautInvestigationDiagnosticApp.xcscheme"
        )
        let ordinaryScheme = try source(
            "Stornaut.xcodeproj/xcshareddata/xcschemes/Stornaut.xcscheme"
        )

        #expect(
            project.components(separatedBy: "isa = PBXNativeTarget;").count
                == 11
        )
        for tool in machineTools {
            #expect(project.components(
                separatedBy: "name = \(tool.target);"
            ).count == 2)
            #expect(project.contains("productName = \(tool.product);"))
            #expect(project.contains("productName = \(tool.support);"))
            #expect(project.contains(
                "PRODUCT_BUNDLE_IDENTIFIER = \(tool.identifier);"
            ))
            #expect(project.contains(
                "\(tool.product) in Copy Investigation Machine Tools"
            ))
            #expect(scheme.components(
                separatedBy: "BlueprintName = \"\(tool.target)\""
            ).count == 2)
            #expect(scheme.contains(
                "BuildableName = \"\(tool.product)\""
            ))
            #expect(!ordinaryScheme.contains(tool.target))
            #expect(!ordinaryScheme.contains(tool.product))
        }
        #expect(project.components(
            separatedBy: "name = \"Copy Investigation Machine Tools\";"
        ).count == 2)
        let copyPhase = try projectBlock(
            id: "B00000000000000000000042",
            comment: "Copy Investigation Machine Tools",
            in: project
        )
        #expect(copyPhase.components(
            separatedBy: " in Copy Investigation Machine Tools */"
        ).count == 4)
        #expect(project.components(
            separatedBy: "settings = {ATTRIBUTES = (CodeSignOnCopy, ); };"
        ).count >= 3)
        let coordinatorSchemeEntry = try schemeBuildEntry(
            blueprintID: "A0000000000000000000000A",
            in: scheme
        )
        #expect(coordinatorSchemeEntry.contains(
            "buildForTesting = \"NO\""
        ))
        #expect(coordinatorSchemeEntry.contains(
            "buildForRunning = \"YES\""
        ))
        for id in [
            "A00000000000000000000190",
            "A00000000000000000000191",
        ] {
            let configuration = try projectBlock(
                id: id,
                comment: id.hasSuffix("90") ? "Debug" : "Release",
                in: project
            )
            #expect(configuration.contains(
                #"CONFIGURATION_BUILD_DIR = "$(BUILD_DIR)/$(CONFIGURATION)/StornautInvestigationMachineGateCoordinatorNative";"#
            ))
            #expect(configuration.contains(
                #"SWIFT_INCLUDE_PATHS = "$(inherited) $(BUILD_DIR)/$(CONFIGURATION)";"#
            ))
            #expect(configuration.contains(
                #"LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks";"#
            ))
        }

        let ordinaryTarget = try projectBlock(
            id: "A00000000000000000000001",
            comment: "StornautApp",
            in: project
        )
        let releaseShellTarget = try projectBlock(
            id: "A00000000000000000000008",
            comment: "StornautInvestigationDiagnosticReleaseShell",
            in: project
        )
        for target in [ordinaryTarget, releaseShellTarget] {
            #expect(!target.contains("Copy Investigation Machine Tools"))
            for tool in machineTools {
                #expect(!target.contains(tool.target))
                #expect(!target.contains(tool.product))
                #expect(!target.contains(tool.support))
            }
        }
    }

    @Test
    func lifecycleHelperEmbedsStableSigningIdentifierMetadata() throws {
        let project = try source("Stornaut.xcodeproj/project.pbxproj")
        for configuration in [
            (id: "A00000000000000000000140", comment: "Debug"),
            (id: "A00000000000000000000141", comment: "Release"),
        ] {
            let helper = try projectBlock(
                id: configuration.id,
                comment: configuration.comment,
                in: project
            )
            #expect(helper.contains(
                "CREATE_INFOPLIST_SECTION_IN_BINARY = YES;"
            ))
            #expect(helper.contains(
                "CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO;"
            ))
            #expect(helper.contains(
                "PRODUCT_BUNDLE_IDENTIFIER = "
                    + "com.eriklee.stornaut.lifecycle.helper;"
            ))
        }
    }

    @Test
    func installerAdmitsClosedMachineToolsAcrossAllPlanes() throws {
        let installer = try source("scripts/stornaut-r5-local-lifecycle")
        for marker in [
            "validate_closed_executable_identity",
            "validate_closed_executable_artifact",
            "validate_closed_app_artifacts",
            "machine_gate_max_bytes",
            "machine_coordinator_max_bytes",
            "com.eriklee.stornaut.investigation.machine-gate",
            "com.eriklee.stornaut.investigation.machine-gate-coordinator",
        ] {
            #expect(installer.contains(marker))
        }
        for tool in machineTools {
            #expect(installer.contains(
                "Contents/MacOS/\(tool.product)"
            ))
            #expect(installer.contains(tool.identifier))
        }
        #expect(installer.components(
            separatedBy: "validate_closed_app_artifacts"
        ).count >= 5)
        #expect(installer.contains(
            "machineClaimServiceIdentifier=$machine_claim_service"
        ))
    }

    @Test
    func installerBindsEachRoleToItsOwnIdentity() throws {
        let installer = try source("scripts/stornaut-r5-local-lifecycle")
        let identity = try shellFunction(
            named: "validate_closed_executable_identity",
            in: installer
        )
        let artifact = try shellFunction(
            named: "validate_closed_executable_artifact",
            in: installer
        )
        let app = try shellFunction(
            named: "validate_closed_app_artifacts",
            in: installer
        )

        let flatIdentity = flattened(identity)
        let flatApp = flattened(app)
        #expect(flatIdentity.contains("case \"$expected_signing_identifier\" in"))
        #expect(flatIdentity.contains(
            "machine-driver) [[ \"$claim_service_identifier\" == \"$machine_claim_service\" ]]"
        ))
        #expect(identity.contains(
            "com.eriklee.stornaut.investigation.machine-gate|"
                + "com.eriklee.stornaut.investigation.machine-gate-coordinator)"
        ))
        #expect(flatIdentity.contains("[[ -z \"$claim_service_identifier\" ]]"))
        #expect(identity.components(
            separatedBy: "machineClaimServiceIdentifier=$machine_claim_service"
        ).count == 2)
        #expect(artifact.contains("executable_size <= max_bytes"))
        #expect(artifact.contains("$expected_signing_identifier"))
        #expect(app.contains("$app_max_bytes"))
        #expect(app.contains("$helper_max_bytes"))
        #expect(app.components(
            separatedBy: "validate_closed_executable_artifact"
        ).count == 6)
        for executable in [
            (
                product: "StornautInvestigationDiagnostic",
                identifier: "com.eriklee.stornaut"
            ),
            (
                product: "StornautLifecycleHelper",
                identifier: "com.eriklee.stornaut.lifecycle.helper"
            ),
        ] {
            #expect(app.contains("Contents/MacOS/\(executable.product)"))
            #expect(app.contains(executable.identifier))
        }
        for tool in machineTools {
            #expect(app.contains("Contents/MacOS/\(tool.product)"))
            #expect(app.contains(tool.identifier))
        }
        #expect(app.components(
            separatedBy: "$machine_claim_service"
        ).count == 2)
        #expect(flatApp.contains("\"$machine_gate_max_bytes\" \"\""))
        #expect(flatApp.contains(
            "\"$machine_coordinator_max_bytes\" \"\""
        ))
        for role in [
            "appIdentity",
            "helperIdentity",
            "machineDriverIdentity",
            "machineGateIdentity",
            "machineCoordinatorIdentity",
        ] {
            #expect(app.contains("\(role)={"))
        }
    }

    @Test
    func installerRevalidatesClosedArtifactsBeforeStateChanges() throws {
        let installer = try source("scripts/stornaut-r5-local-lifecycle")
        let install = try shellFunction(named: "install", in: installer)
        let rollback = try shellFunction(
            named: "rollback_failed_lifecycle",
            in: installer
        )
        let uninstall = try shellFunction(
            named: "uninstall",
            in: installer
        )

        try requireOrder([
            "built_closed_artifact_identity=$(validate_built_app)",
            "staging_app_created=1",
            "/bin/mkdir -m 0755 \"$staging_app\"",
            "staging_app_node=$(",
            "exact_directory_metadata \"$staging_app\" root wheel 0755",
            "/usr/bin/ditto --noqtn",
            "validate_closed_app_artifacts",
            "[[ \"$(/usr/bin/stat -f '%d:%i' \"$staging_app\")\" ==",
            "installed_app_node=$staging_app_node",
            "/bin/mv -n \"$staging_app\" \"$installed_app\"",
            "validate_closed_app_artifacts",
            "validate_installed_artifacts \"$built_closed_artifact_identity\"",
            "/bin/launchctl bootstrap system",
        ], in: install)
        #expect(rollback.contains(
            "validate_closed_app_artifacts \"$installed_app\" root wheel"
        ))
        #expect(rollback.contains("${installed_app_node:-}"))
        #expect(rollback.contains("${staging_app_node:-}"))
        #expect(rollback.contains("[[ -z ${staging_app_node:-} ||"))
        #expect(uninstall.contains(
            "uninstall_closed_artifact_identity=$("
        ))
        try requireOrder([
            "uninstall_closed_artifact_identity=$(",
            "recover_runtime_roots_after_bootout",
            "validate_closed_app_artifacts",
            "$uninstall_closed_artifact_identity",
            "/bin/rm -rf -- \"$installed_app\"",
        ], in: uninstall)
    }

    @Test
    func validationActionKeepsMachineToolChecksReadOnly() throws {
        let installer = try source("scripts/stornaut-r5-local-lifecycle")
        let action = try #require(installer.range(
            of: "\n    validate-machine-driver)"
        ))
        let actionEnd = try #require(installer.range(
            of: "\n        ;;",
            range: action.upperBound..<installer.endIndex
        ))
        let validationClosure = try [
            "exact_file_metadata",
            "exact_directory_metadata",
            "validate_closed_executable_identity",
            "validate_closed_executable_artifact",
            "validate_closed_app_artifacts",
            "validate_closed_artifact_fixtures",
        ].map { try shellFunction(named: $0, in: installer) }.joined()
            + String(installer[action.lowerBound..<actionEnd.upperBound])
        for forbidden in [
            "launchctl", "mkdir", "chown", "chmod", "ditto",
            "/bin/mv", "/bin/rm", "/usr/bin/install", "/Library/",
            "/private/var/", "posix_spawn", "exec ", "eval ", "xargs",
        ] {
            #expect(!validationClosure.contains(forbidden))
        }
        #expect(validationClosure.components(
            separatedBy: "validate_closed_app_artifacts"
        ).count == 5)
    }

    private func source(_ path: String) throws -> String {
        let root = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: root.appending(path: path),
            encoding: .utf8
        )
    }

    private func projectBlock(
        id: String,
        comment: String,
        in source: String
    ) throws -> String {
        let marker = "\(id) /* \(comment) */ = {"
        let start = try #require(source.range(of: marker))
        let suffix = source[start.lowerBound...]
        let end = try #require(suffix.range(of: "\n\t\t};"))
        return String(suffix[..<end.upperBound])
    }

    private func shellFunction(named name: String, in source: String) throws -> String {
        let start = try #require(source.range(of: "\n\(name)() {"))
        let suffix = source[start.upperBound...]
        let end = try #require(suffix.range(of: "\n}\n\n"))
        return String(source[start.lowerBound..<end.upperBound])
    }

    private func schemeBuildEntry(
        blueprintID: String,
        in source: String
    ) throws -> String {
        let identity = try #require(source.range(
            of: "BlueprintIdentifier = \"\(blueprintID)\""
        ))
        let start = try #require(source.range(
            of: "         <BuildActionEntry",
            options: .backwards,
            range: source.startIndex..<identity.lowerBound
        ))
        let end = try #require(source.range(
            of: "         </BuildActionEntry>",
            range: identity.upperBound..<source.endIndex
        ))
        return String(source[start.lowerBound..<end.upperBound])
    }

    private func flattened(_ source: String) -> String {
        source.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private func requireOrder(_ markers: [String], in source: String) throws {
        var lowerBound = source.startIndex
        for marker in markers {
            let range = try #require(source.range(
                of: marker,
                range: lowerBound..<source.endIndex
            ))
            lowerBound = range.upperBound
        }
    }
}
