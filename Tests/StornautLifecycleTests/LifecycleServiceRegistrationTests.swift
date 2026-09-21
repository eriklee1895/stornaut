import Foundation
import Testing
@testable import StornautLifecycle

@Suite("R5 lifecycle service registration")
struct LifecycleServiceRegistrationTests {
    @Test
    func fixedDirectoryURLDoesNotChangeWhenSymlinkedLeafAppears() throws {
        let fileManager = FileManager.default
        let leaf = URL(
            filePath: "/private/var/tmp/stornaut-fixed-path-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? fileManager.removeItem(at: leaf) }

        let before = try LifecycleLocalInstallationContract
            .lexicallyStableDirectoryURL(filePath: leaf.path)
        try fileManager.createDirectory(
            at: leaf,
            withIntermediateDirectories: false
        )
        let after = try LifecycleLocalInstallationContract
            .lexicallyStableDirectoryURL(filePath: leaf.path)

        #expect(before.path == leaf.path)
        #expect(after.path == leaf.path)
        #expect(before == after)
        #expect(leaf.standardizedFileURL.path != leaf.path)
    }

    @Test
    func localOnlyContractDerivesOnlyTheFixedDiagnosticTopology() throws {
        let contract = try LifecycleLocalInstallationContract()

        #expect(
            contract.installedRootURL.path
                == "/Library/Application Support/Stornaut"
        )
        #expect(
            contract.installedAppURL.path
                == "/Library/Application Support/Stornaut/Stornaut-R5-Diagnostic.app"
        )
        #expect(
            contract.helperExecutableURL.path
                == "/Library/Application Support/Stornaut/Stornaut-R5-Diagnostic.app/Contents/MacOS/StornautLifecycleHelper"
        )
        #expect(
            contract.launchDaemonPlistURL.path
                == "/Library/LaunchDaemons/com.eriklee.stornaut.lifecycle.plist"
        )
        #expect(contract.label == "com.eriklee.stornaut.lifecycle")
        #expect(contract.machServiceName == contract.label)
        #expect(
            contract.machineClaimMachServiceName
                == "com.eriklee.stornaut.lifecycle.machine-claim"
        )
        #expect(
            contract.machineDriverExecutableURL.path
                == "/Library/Application Support/Stornaut/Stornaut-R5-Diagnostic.app/Contents/MacOS/StornautInvestigationMachineDriver"
        )
        #expect(
            contract.machineDriverSigningIdentifier
                == "com.eriklee.stornaut.investigation.machine-driver"
        )
        #expect(contract.appBundleIdentifier == "com.eriklee.stornaut")
        #expect(contract.appOwnerUserID == 0)
        #expect(contract.appOwnerGroupID == 0)
        #expect(contract.appMode == 0o755)
        #expect(contract.plistMode == 0o644)

        let investigationID = LifecycleInvestigationID(
            rawValue: UUID(
                uuidString: "11111111-2222-3333-4444-555555555555"
            )!
        )
        let paths = try contract.diagnosticPaths(
            userID: 501,
            investigationID: investigationID
        )
        #expect(
            paths.userRootURL.path
                == "/Library/Application Support/Stornaut/R5Runtime/501"
        )
        #expect(
            paths.rootURL.path
                == "/Library/Application Support/Stornaut/R5Runtime/501/11111111-2222-3333-4444-555555555555"
        )
        #expect(
            paths.rootURL.deletingLastPathComponent()
                == paths.userRootURL
        )
        #expect(paths.workerEvidenceURL.lastPathComponent == "worker.json")
        #expect(paths.reportURL.lastPathComponent == "report.json")
        #expect(paths.recoveryURL.lastPathComponent == "recovery.json")
    }

    @Test
    func localOnlyManifestHasNoCallerControlledPathOrArguments() throws {
        let manifest = try LifecycleLocalInstallationContract()
            .launchDaemonManifest()
        let data = try PropertyListSerialization.data(
            fromPropertyList: manifest,
            format: .xml,
            options: 0
        )
        let text = String(decoding: data, as: UTF8.self)

        #expect(Set(manifest.keys) == [
            "AbandonProcessGroup",
            "AssociatedBundleIdentifiers",
            "KeepAlive",
            "Label",
            "MachServices",
            "ProcessType",
            "Program",
            "RunAtLoad",
            "SessionCreate",
            "ThrottleInterval",
        ])
        #expect(
            manifest["Program"] as? String
                == "/Library/Application Support/Stornaut/Stornaut-R5-Diagnostic.app/Contents/MacOS/StornautLifecycleHelper"
        )
        #expect(manifest["ProgramArguments"] == nil)
        #expect(!text.contains("BundleProgram"))
        #expect(
            manifest["KeepAlive"] as? [String: Bool]
                == ["SuccessfulExit": false]
        )
        #expect(
            manifest["MachServices"] as? [String: Bool]
                == [
                    "com.eriklee.stornaut.lifecycle": true,
                    "com.eriklee.stornaut.lifecycle.machine-claim": true,
                ]
        )
        #expect(manifest["ThrottleInterval"] as? Int == 1)
        for forbidden in [
            "/bin/sh",
            "/bin/zsh",
            "arguments",
            "argv",
            "auditSessionID",
            "pid",
            "signal",
            "trash",
            "executor",
            "policy",
        ] {
            #expect(
                !text.localizedCaseInsensitiveContains(forbidden)
            )
        }
    }

    @Test
    func localOnlyManifestValidationRejectsEveryUnknownOrChangedField()
        throws
    {
        let contract = try LifecycleLocalInstallationContract()
        let expected = contract.launchDaemonManifest()

        #expect(try contract.validateLaunchDaemonManifest(expected))

        var unknown = expected
        unknown["StandardOutPath"] = "/tmp/stornaut-root-output"
        #expect(
            throws: LifecycleLocalInstallationContractError.self
        ) {
            _ = try contract.validateLaunchDaemonManifest(unknown)
        }

        var changedProgram = expected
        changedProgram["Program"] = "/tmp/untrusted-helper"
        #expect(
            throws: LifecycleLocalInstallationContractError.self
        ) {
            _ = try contract.validateLaunchDaemonManifest(
                changedProgram
            )
        }
    }

    @Test
    func workerEvidenceReceiptBindsTheOriginalInodeAndSize() throws {
        let original = LifecycleWorkerEvidenceFileIdentity(
            deviceID: 1,
            inode: 2,
            ownerUserID: 501,
            mode: 0o600,
            linkCount: 1,
            size: 128
        )
        let replacement = LifecycleWorkerEvidenceFileIdentity(
            deviceID: 1,
            inode: 3,
            ownerUserID: 501,
            mode: 0o600,
            linkCount: 1,
            size: 128
        )

        #expect(
            original.matches(
                original,
                expectedOwnerUserID: 501,
                maximumSize: 1_024
            )
        )
        #expect(
            !original.matches(
                replacement,
                expectedOwnerUserID: 501,
                maximumSize: 1_024
            )
        )
        #expect(
            !original.matches(
                original,
                expectedOwnerUserID: 502,
                maximumSize: 1_024
            )
        )

        let evidence = Data("synthetic-evidence".utf8)
        let receipt = try LifecycleWorkerEvidenceReceipt(
            fileIdentity: original,
            data: evidence
        )
        #expect(
            try LifecycleWorkerEvidenceReceipt.decodeLine(
                receipt.encodedLine()
            ) == receipt
        )
        #expect(
            receipt.matches(
                data: evidence,
                currentIdentity: original,
                expectedOwnerUserID: 501
            )
        )
        #expect(
            !receipt.matches(
                data: Data("forged-evidence".utf8),
                currentIdentity: original,
                expectedOwnerUserID: 501
            )
        )
        #expect(
            !receipt.matches(
                data: evidence,
                currentIdentity: replacement,
                expectedOwnerUserID: 501
            )
        )
    }

    @Test
    func recoveredInvestigationCanOnlyConfirmRecoveryAndCannotRestart() {
        let investigationID = LifecycleInvestigationID(
            rawValue: UUID(
                uuidString: "55555555-5555-5555-5555-555555555555"
            )!
        )
        let recovered: Set<LifecycleInvestigationID> = [
            investigationID,
        ]
        let policy = LifecycleRecoveredInvestigationPolicy()

        #expect(
            !policy.permitsStart(
                investigationID,
                recovered: recovered
            )
        )
        #expect(
            policy.confirmsRecovery(
                investigationID,
                recovered: recovered,
                activeInvestigationID: nil
            )
        )
        #expect(
            !policy.confirmsRecovery(
                investigationID,
                recovered: recovered,
                activeInvestigationID: LifecycleInvestigationID()
            )
        )
        #expect(
            policy.permitsStart(
                LifecycleInvestigationID(),
                recovered: recovered
            )
        )
    }

    @Test(arguments: [
        LifecycleLocalInstallationObservation(
            app: .absent,
            plist: .absent,
            service: .absent
        ),
        LifecycleLocalInstallationObservation(
            app: .valid,
            plist: .absent,
            service: .absent
        ),
    ])
    func localOnlyPlannerRequiresAdministratorInstallUntilFullyPresent(
        observation: LifecycleLocalInstallationObservation
    ) throws {
        #expect(
            LifecycleLocalInstallationPlanner().state(for: observation)
                == .administratorInstallRequired
        )
    }

    @Test
    func localOnlyPlannerAcceptsOnlyMatchingRootOwnedInstalledState() {
        let observation = LifecycleLocalInstallationObservation(
            app: .valid,
            plist: .valid,
            service: .loaded
        )

        #expect(
            LifecycleLocalInstallationPlanner().state(for: observation)
                == .installed
        )
    }

    @Test(arguments: [
        LifecycleLocalInstallationObservation(
            app: .invalid(reasonKey: "runtime.lifecycle.app-symlink"),
            plist: .valid,
            service: .loaded
        ),
        LifecycleLocalInstallationObservation(
            app: .valid,
            plist: .invalid(
                reasonKey: "runtime.lifecycle.plist-owner-invalid"
            ),
            service: .loaded
        ),
        LifecycleLocalInstallationObservation(
            app: .valid,
            plist: .valid,
            service: .mismatched
        ),
    ])
    func localOnlyPlannerFailsClosedOnInconsistentInstallation(
        observation: LifecycleLocalInstallationObservation
    ) {
        #expect(
            LifecycleLocalInstallationPlanner().state(for: observation)
                == .inconsistentInstallation
        )
    }

    @Test
    func localOnlyPlannerRequiresCleanupForOrphanedInstalledArtifacts() {
        for observation in [
            LifecycleLocalInstallationObservation(
                app: .absent,
                plist: .valid,
                service: .absent
            ),
            LifecycleLocalInstallationObservation(
                app: .absent,
                plist: .absent,
                service: .loaded
            ),
        ] {
            #expect(
                LifecycleLocalInstallationPlanner().state(
                    for: observation
                ) == .administratorCleanupRequired
            )
        }
    }

    @Test
    func localOnlyDiagnosticPathsRejectRootIdentity() throws {
        let contract = try LifecycleLocalInstallationContract()

        #expect(
            throws: LifecycleLocalInstallationContractError
                .invalidDiagnosticIdentity
        ) {
            _ = try contract.diagnosticPaths(
                userID: 0,
                investigationID: LifecycleInvestigationID()
            )
        }
    }

    @Test
    func xpcResponseExposesOnlyPrivacySafeLifecycleState() throws {
        let response = LifecycleSupervisorXPCResponse(
            callerAuthenticated: true,
            freshAuditSession: true,
            workerEvidence: Data("synthetic".utf8),
            drained: true,
            staleRecoveryObserved: true
        )
        let data = try JSONEncoder().encode(response)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let text = String(decoding: data, as: UTF8.self)

        #expect(Set(object.keys) == [
            "callerAuthenticated",
            "drained",
            "freshAuditSession",
            "protocolVersion",
            "staleRecoveryObserved",
            "status",
            "workerEvidence",
            "workerEvidenceReady",
        ])
        #expect(object["workerEvidenceReady"] as? Bool == true)
        for forbidden in [
            "auditSessionID",
            "pid",
            "port",
            "path",
            "executable",
            "argument",
            "auth",
        ] {
            #expect(
                !text.localizedCaseInsensitiveContains(forbidden)
                    || forbidden == "auth"
                        && text.contains("callerAuthenticated")
            )
        }
    }

    @Test
    func xpcResponseExplicitlyEncodesAbsentWorkerEvidence() throws {
        let response = LifecycleSupervisorXPCResponse(
            callerAuthenticated: true,
            freshAuditSession: true,
            drained: true
        )
        let data = try JSONEncoder().encode(response)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(Set(object.keys) == [
            "callerAuthenticated",
            "drained",
            "freshAuditSession",
            "protocolVersion",
            "staleRecoveryObserved",
            "status",
            "workerEvidence",
            "workerEvidenceReady",
        ])
        #expect(object["workerEvidence"] is NSNull)
        #expect(
            try JSONDecoder().decode(
                LifecycleSupervisorXPCResponse.self,
                from: data
            ) == response
        )
    }

    @Test
    func xpcReplyResolverCompletesExactlyOnce() async throws {
        let response = LifecycleSupervisorXPCResponse(
            callerAuthenticated: true,
            freshAuditSession: true,
            drained: true
        )
        let encoded = try JSONEncoder().encode(response)

        let value: LifecycleSupervisorXPCResponse =
            try await withCheckedThrowingContinuation {
            continuation in
            let resolver = LifecycleSupervisorXPCReplyResolver(
                continuation
            )
            resolver.resolve(
                response: encoded,
                reasonKey: nil
            )
            resolver.failConnection()
            resolver.resolve(
                response: encoded,
                reasonKey: nil
            )
        }

        #expect(value == response)
    }

    @Test
    func xpcReplyResolverMakesConnectionFailureOneShot() async {
        await #expect(
            throws: LifecycleSupervisorXPCError.connectionFailed
        ) {
            _ = try await withCheckedThrowingContinuation {
                continuation in
                let resolver = LifecycleSupervisorXPCReplyResolver(
                    continuation
                )
                resolver.failConnection()
                resolver.failConnection()
                resolver.resolve(
                    response: Data("late".utf8),
                    reasonKey: nil
                )
            }
        }
    }

}
