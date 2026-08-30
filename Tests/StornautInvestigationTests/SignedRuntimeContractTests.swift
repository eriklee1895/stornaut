import CryptoKit
import Darwin
import Foundation
import Testing
import StornautCodex
import StornautCore
import StornautInvestigation
@testable import StornautInvestigationDiagnostic
@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationMachine

@Suite("Task 39 signed Investigation runtime contract", .serialized)
struct SignedRuntimeContractTests {
    @Test
    func diagnosticCompositionPreparesOpaqueProductionChain()
        async throws
    {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configuration = try fixture.configuration()
        let installation = fixture.installationObservation()

        let composition =
            try InvestigationRuntimeDiagnosticComposition.prepare(
                configurationData: try configuration.canonicalJSONData(),
                now: fixture.now,
                installation: installation,
                runtimeNow: { fixture.now }
            )

        #expect(composition.nonce == configuration.nonce)
        #expect(
            composition.investigationID
                == "investigation-"
                    + configuration.nonce.uuidString.lowercased()
        )
        #expect(composition.storePath == configuration.storePath)
        let configurationSHA256 =
            try configuration.machineConfigurationSHA256()
        #expect(composition.configurationSHA256 == configurationSHA256)
        #expect(
            composition.lifecycleValidBefore
                == fixture.now.addingTimeInterval(140)
        )
        #expect(
            composition.helperExecutablePath
                == "/Library/Application Support/Stornaut/"
                    + "Stornaut-R5-Diagnostic.app/Contents/MacOS/"
                    + "StornautLifecycleHelper"
        )
        #expect(composition.hasRuntimeFacade)
        #expect(
            await composition.retirePreparedComposition()
                == .retiredWithoutStarting
        )
        let publicRetirement = String(
            describing: InvestigationRuntimeDiagnosticCompositionRetirement
                .retiredAfterUse
        )
        #expect(!publicRetirement.contains("processID"))
        #expect(!publicRetirement.contains("auditSessionID"))
        #expect(!publicRetirement.contains("residueObservation"))
        #expect(
            try await composition.retirePreparedCompositionWithEvidence()
                == nil
        )
    }

    @Test
    func diagnosticCompositionRejectsBindingDrift() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configuration = try fixture.configuration()
        let expected = fixture.installationObservation()
        let drifted = InvestigationRuntimeDiagnosticBindingObservation(
            installedAppURL: expected.installedAppURL,
            helperExecutableURL: expected.helperExecutableURL,
            appExecutableName: expected.appExecutableName,
            appExecutableSHA256: expected.appExecutableSHA256,
            helperExecutableSHA256: String(repeating: "0", count: 64),
            appBundleIdentifier: expected.appBundleIdentifier,
            helperSigningIdentifier: expected.helperSigningIdentifier,
            serviceIdentifier: expected.serviceIdentifier,
            machineDriverExecutableURL:
                expected.machineDriverExecutableURL,
            machineDriverExecutableSHA256:
                expected.machineDriverExecutableSHA256,
            machineDriverSigningIdentifier:
                expected.machineDriverSigningIdentifier,
            machineDriverDesignatedRequirementSHA256:
                expected.machineDriverDesignatedRequirementSHA256,
            machineDriverCodeDirectoryHash:
                expected.machineDriverCodeDirectoryHash,
            machineClaimServiceIdentifier:
                expected.machineClaimServiceIdentifier
        )

        #expect(
            throws:
                InvestigationRuntimeDiagnosticCompositionError
                .bindingMismatch
        ) {
            _ = try InvestigationRuntimeDiagnosticComposition.prepare(
                configurationData: try configuration.canonicalJSONData(),
                now: fixture.now,
                installation: drifted
            )
        }

        for mutation in 0..<6 {
            let driver = configuration.binding.machineDriver
            let driftedDriver =
                InvestigationRuntimeDiagnosticBindingObservation(
                    installedAppURL: expected.installedAppURL,
                    helperExecutableURL:
                        expected.helperExecutableURL,
                    appExecutableName: expected.appExecutableName,
                    appExecutableSHA256:
                        expected.appExecutableSHA256,
                    helperExecutableSHA256:
                        expected.helperExecutableSHA256,
                    appBundleIdentifier: expected.appBundleIdentifier,
                    helperSigningIdentifier:
                        expected.helperSigningIdentifier,
                    serviceIdentifier: expected.serviceIdentifier,
                    machineDriverExecutableURL: mutation == 0
                        ? expected.installedAppURL.appending(
                            path: "Contents/MacOS/ForeignDriver"
                        )
                        : expected.machineDriverExecutableURL,
                    machineDriverExecutableSHA256: mutation == 1
                        ? String(repeating: "0", count: 64)
                        : driver.executableSHA256,
                    machineDriverSigningIdentifier: mutation == 2
                        ? "foreign.driver"
                        : driver.signingIdentifier,
                    machineDriverDesignatedRequirementSHA256:
                        mutation == 3
                            ? String(repeating: "0", count: 64)
                            : driver.designatedRequirementSHA256,
                    machineDriverCodeDirectoryHash: mutation == 4
                        ? String(repeating: "0", count: 40)
                        : driver.codeDirectoryHash,
                    machineClaimServiceIdentifier: mutation == 5
                        ? "com.eriklee.stornaut.lifecycle"
                        : driver.machineClaimServiceIdentifier
                )
            #expect(
                throws:
                    InvestigationRuntimeDiagnosticCompositionError
                    .bindingMismatch
            ) {
                _ = try InvestigationRuntimeDiagnosticComposition.prepare(
                    configurationData:
                        try configuration.canonicalJSONData(),
                    now: fixture.now,
                    installation: driftedDriver
                )
            }
        }
    }

    @Test
    func diagnosticCompositionUsesLiveRuntimeClock() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configuration = try fixture.configuration()
        let anchor: UInt64 = 10_000_000_000
        let wall = SequenceConcreteClock([fixture.now])
        let continuous = SequenceConcreteContinuousClock([
            anchor, anchor + 141_000_000_000,
        ])

        #expect(
            throws:
                InvestigationRuntimeDiagnosticCompositionError
                .compositionUnavailable
        ) {
            _ = try InvestigationRuntimeDiagnosticComposition.prepare(
                configurationData: try configuration.canonicalJSONData(),
                now: fixture.now,
                installation: fixture.installationObservation(),
                runtimeNow: { wall.next() },
                continuousNow: { try continuous.next() }
            )
        }
    }

    @Test
    func diagnosticCompositionUsesEarlierConfigurationDeadline() async throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configuration = try fixture.configuration(
            validBefore: fixture.now.addingTimeInterval(100)
        )
        let bytes = try configuration.canonicalJSONData()
        let digest = try configuration.machineConfigurationSHA256()
        let composition = try InvestigationRuntimeDiagnosticComposition.prepare(
            configurationData: bytes, now: fixture.now,
            installation: fixture.installationObservation(),
            runtimeNow: { fixture.now }
        )

        #expect(composition.lifecycleValidBefore == configuration.validBefore)
        #expect(try configuration.canonicalJSONData() == bytes)
        #expect(try configuration.machineConfigurationSHA256() == digest)
        _ = await composition.retirePreparedComposition()
    }

    @Test
    func strictConfigurationRoundTripsAndRejectsUnknownFields() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let data = try fixture.configurationData()

        let configuration =
            try SignedInvestigationRuntimeDiagnosticConfiguration
                .decodeValidated(
                    from: data,
                    now: fixture.now
                )

        #expect(configuration.nonce == fixture.nonce)
        #expect(
            configuration.binding.machineDriver
                == fixture.machineDriverBinding()
        )
        #expect(
            SignedInvestigationRuntimeDiagnosticConfiguration
                .schemaVersion == 3
        )
        #expect(
            configuration.diagnosticRootPath
                == fixture.diagnosticRoot.path
        )
        #expect(
            try configuration.canonicalJSONData()
                == configuration.canonicalJSONData()
        )

        var overbroad = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        overbroad["validBefore"] = fixture.now
            .addingTimeInterval(901).timeIntervalSinceReferenceDate
        let overbroadData = try JSONSerialization.data(
            withJSONObject: overbroad,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        #expect(throws: SignedInvestigationRuntimeContractError
            .invalidConfiguration) {
            _ = try SignedInvestigationRuntimeDiagnosticConfiguration
                .decodeValidated(from: overbroadData, now: fixture.now)
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
                SignedInvestigationRuntimeContractError.invalidConfiguration
        ) {
            _ = try SignedInvestigationRuntimeDiagnosticConfiguration
                .decodeValidated(
                    from: unknown,
                    now: fixture.now
                )
        }

        var missingDriver = try #require(
            JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
        var missingBinding = try #require(
            missingDriver["binding"] as? [String: Any]
        )
        missingBinding.removeValue(forKey: "machineDriver")
        missingDriver["binding"] = missingBinding
        let missingDriverData = try JSONSerialization.data(
            withJSONObject: missingDriver,
            options: [.sortedKeys]
        )
        #expect(
            throws:
                SignedInvestigationRuntimeContractError
                .invalidConfiguration
        ) {
            _ = try SignedInvestigationRuntimeDiagnosticConfiguration
                .decodeValidated(
                    from: missingDriverData,
                    now: fixture.now
                )
        }

        var unknownDriver = try #require(
            JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
        var unknownBinding = try #require(
            unknownDriver["binding"] as? [String: Any]
        )
        var driver = try #require(
            unknownBinding["machineDriver"] as? [String: Any]
        )
        driver["unexpected"] = true
        unknownBinding["machineDriver"] = driver
        unknownDriver["binding"] = unknownBinding
        let unknownDriverData = try JSONSerialization.data(
            withJSONObject: unknownDriver,
            options: [.sortedKeys]
        )
        #expect(
            throws:
                SignedInvestigationRuntimeContractError
                .invalidConfiguration
        ) {
            _ = try SignedInvestigationRuntimeDiagnosticConfiguration
                .decodeValidated(
                    from: unknownDriverData,
                    now: fixture.now
                )
        }

        var nulPaths = try #require(
            JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
        for key in [
            "sourceRootPath",
            "supportRootPath",
            "runtimeRootPath",
            "reportPath",
            "storePath",
        ] {
            nulPaths[key] = try #require(nulPaths[key] as? String)
                + "\0ignored"
        }
        let nulPathData = try JSONSerialization.data(
            withJSONObject: nulPaths,
            options: [.sortedKeys]
        )
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidConfiguration
        ) {
            _ = try SignedInvestigationRuntimeDiagnosticConfiguration
                .decodeValidated(
                    from: nulPathData,
                    now: fixture.now
                )
        }
    }

    @Test
    func machineCohortValidityIsExactAndDoesNotWidenGeneralDecoding() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configuration = try fixture.configuration(
            machineCohortWindow: 1_200
        )
        let data = try configuration.canonicalJSONData()

        #expect(throws: SignedInvestigationRuntimeContractError
            .invalidConfiguration) {
            _ = try SignedInvestigationRuntimeDiagnosticConfiguration
                .decodeValidated(from: data, now: fixture.now)
        }
        let configurations = try fixture.machineConfigurations(
            machineCohortWindow: 1_200
        )
        let binding = fixture.binding()
        let installed = try InvestigationProjectedCohortInstalledBinding(
            appExecutableSHA256: binding.appExecutableSHA256,
            appBundleIdentifier: binding.appBundleIdentifier,
            helperExecutableSHA256: binding.helperExecutableSHA256,
            helperServiceIdentifier: binding.helperServiceIdentifier,
            machineDriverExecutableSHA256:
                binding.machineDriver.executableSHA256,
            machineDriverSigningIdentifier:
                binding.machineDriver.signingIdentifier,
            machineDriverDesignatedRequirementSHA256:
                binding.machineDriver.designatedRequirementSHA256,
            machineDriverCodeDirectoryHash:
                binding.machineDriver.codeDirectoryHash,
            machineClaimServiceIdentifier:
                binding.machineDriver.machineClaimServiceIdentifier
        )
        let canonicalConfigurations = try configurations.map {
            try $0.canonicalJSONData()
        }
        let projected = try InvestigationProjectedCohortAuthor(
            now: { fixture.now },
            identifiers: {
                InvestigationProjectedCohortGeneratedIdentifiers(
                    outerAttemptUUID: UUID(),
                    epochUUIDs: (0..<8).map { _ in UUID() }
                )
            }
        ).author(
            configurationData: canonicalConfigurations,
            installedBinding: installed
        )
        #expect(projected.capsule.epochs.map(\.configuration)
            == canonicalConfigurations)
        #expect(Set(projected.projections.map(
            \.configurationValidBefore
        )).count == 1)
        #expect(
            try SignedInvestigationRuntimeDiagnosticConfiguration
                .decodeMachineCohortValidated(from: data, now: fixture.now)
                == configuration
        )
        #expect(throws: SignedInvestigationRuntimeContractError
            .invalidConfiguration) {
            _ = try fixture.configuration(machineCohortWindow: 1_200.001)
        }
        #expect(throws: SignedInvestigationRuntimeContractError
            .invalidConfiguration) {
            _ = try fixture.configuration(
                validBefore: fixture.now.addingTimeInterval(901)
            )
        }
        var overlong = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        overlong["validBefore"] = fixture.now.addingTimeInterval(1_200.001)
            .timeIntervalSinceReferenceDate
        let overlongData = try JSONSerialization.data(
            withJSONObject: overlong,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        #expect(throws: SignedInvestigationRuntimeContractError
            .invalidConfiguration) {
            _ = try SignedInvestigationRuntimeDiagnosticConfiguration
                .decodeMachineCohortValidated(
                    from: overlongData, now: fixture.now
                )
        }
        overlong["maximumWallClockSeconds"] = 139
        overlong["validBefore"] = configuration.validBefore
            .timeIntervalSinceReferenceDate
        #expect(throws: SignedInvestigationRuntimeContractError
            .invalidConfiguration) {
            _ = try SignedInvestigationRuntimeDiagnosticConfiguration
                .decodeMachineCohortValidated(
                    from: JSONSerialization.data(
                        withJSONObject: overlong,
                        options: [.sortedKeys, .withoutEscapingSlashes]
                    ),
                    now: fixture.now
                )
        }
        #expect(throws: SignedInvestigationRuntimeContractError
            .invalidConfiguration) {
            _ = try fixture.configuration(machineCohortWindow: .infinity)
        }
        #expect(throws: SignedInvestigationRuntimeContractError
            .invalidConfiguration) {
            _ = try SignedInvestigationRuntimeDiagnosticConfiguration
                .decodeMachineCohortValidated(
                    from: data, now: Date(timeIntervalSince1970: .infinity)
                )
        }
        #expect(throws: SignedInvestigationRuntimeContractError
            .invalidConfiguration) {
            _ = try SignedInvestigationRuntimeDiagnosticConfiguration
                .decodeMachineCohortValidated(
                    from: data, now: configuration.validBefore
                )
        }
        fixture.materializeOutputs()
        #expect(
            try SignedInvestigationRuntimeDiagnosticConfiguration
                .decodeMachineCohortValidated(
                    from: data, now: fixture.now,
                    outputs: .ownerRegularFile
                ) == configuration
        )
        #expect(throws: SignedInvestigationRuntimeContractError
            .invalidConfiguration) {
            _ = try SignedInvestigationRuntimeDiagnosticConfiguration
                .decodeMachineCohortValidated(
                    from: data, now: fixture.now
                )
        }
    }

    @Test
    func fixedRunnerAcceptsThePresealedMachineCohortWindow() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configuration = try fixture.configuration(
            machineCohortWindow: 1_200
        )

        #expect(throws: Never.self) {
            _ = try InvestigationFixedScenarioRunner(
                configuration: configuration,
                plan: fixture.machinePlan(configuration: configuration),
                now: fixture.now,
                operation: { throw CancellationError() }
            )
        }
        var object = try #require(JSONSerialization.jsonObject(
            with: configuration.canonicalJSONData()
        ) as? [String: Any])
        object["maximumTurns"] = 2
        let wrongProfile = try JSONDecoder().decode(
            SignedInvestigationRuntimeDiagnosticConfiguration.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        #expect(throws: InvestigationFixedScenarioRunnerError.invalidInput) {
            _ = try InvestigationFixedScenarioRunner(
                configuration: wrongProfile,
                plan: fixture.machinePlan(configuration: wrongProfile),
                now: fixture.now, operation: { throw CancellationError() }
            )
        }
    }

    @Test
    func machineDriverBindingAcceptsEveryLifecycleCodeDirectoryHashLength()
        throws
    {
        for hashLength in [40, 64] {
            let binding =
                try SignedInvestigationRuntimeMachineDriverBinding(
                    executableSHA256:
                        String(repeating: "b", count: 64),
                    signingIdentifier:
                        "com.eriklee.stornaut.investigation.machine-driver",
                    designatedRequirementSHA256:
                        String(repeating: "c", count: 64),
                    codeDirectoryHash:
                        String(repeating: "d", count: hashLength),
                    machineClaimServiceIdentifier:
                        "com.eriklee.stornaut.lifecycle.machine-claim"
                )
            let decoded = try JSONDecoder().decode(
                SignedInvestigationRuntimeMachineDriverBinding.self,
                from: JSONEncoder().encode(binding)
            )
            #expect(decoded == binding)
        }
        for invalidHash in [
            String(repeating: "d", count: 39),
            String(repeating: "d", count: 41),
            String(repeating: "d", count: 63),
            String(repeating: "d", count: 65),
            String(repeating: "D", count: 40),
            String(repeating: "g", count: 64),
        ] {
            #expect(
                throws:
                    SignedInvestigationRuntimeContractError
                    .invalidReport
            ) {
                _ = try SignedInvestigationRuntimeMachineDriverBinding(
                    executableSHA256:
                        String(repeating: "b", count: 64),
                    signingIdentifier:
                        "com.eriklee.stornaut.investigation.machine-driver",
                    designatedRequirementSHA256:
                        String(repeating: "c", count: 64),
                    codeDirectoryHash: invalidHash,
                    machineClaimServiceIdentifier:
                        "com.eriklee.stornaut.lifecycle.machine-claim"
                )
            }
        }
    }

    @Test
    func directConfigurationDecodingRejectsReusedOutputPaths() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let data = try fixture.configurationData()
        for (url, contents) in [
            (fixture.reportURL, Data("report".utf8)),
            (fixture.storeURL, Data("store".utf8)),
        ] {
            try contents.write(to: url, options: .withoutOverwriting)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: url.path
            )
        }

        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidConfiguration
        ) {
            _ = try JSONDecoder().decode(
                SignedInvestigationRuntimeDiagnosticConfiguration.self,
                from: data
            )
        }
    }

    @Test
    func configurationRejectsRelativeOverlappingAndSymlinkedPaths()
        throws
    {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }

        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidConfiguration
        ) {
            _ = try fixture.configuration(
                sourceRootPath: "relative/source"
            )
        }
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidConfiguration
        ) {
            _ = try fixture.configuration(
                sourceRootPath: fixture.sourceRoot.path + "\0ignored"
            )
        }
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidConfiguration
        ) {
            _ = try fixture.configuration(
                supportRootPath: fixture.sourceRoot.path
            )
        }

        let symlink = fixture.diagnosticRoot.appending(
            path: "symlink-source",
            directoryHint: .isDirectory
        )
        try FileManager.default.createSymbolicLink(
            at: symlink,
            withDestinationURL: fixture.sourceRoot
        )
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidConfiguration
        ) {
            _ = try fixture.configuration(
                sourceRootPath: symlink.path
            )
        }
    }

    @Test
    func configurationBindsTheExactEvidenceStoreV4Path() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let storeConfiguration = try LocalStoreConfiguration(
            applicationSupportBaseURL: fixture.supportRoot,
            cachesBaseURL: fixture.runtimeRoot
        )
        let configuration = try fixture.configuration()

        #expect(
            configuration.storePath
                == storeConfiguration.evidenceDatabaseURL.path
        )
        _ = try EvidenceStore(configuration: storeConfiguration)
        #expect(
            FileManager.default.fileExists(
                atPath: storeConfiguration.evidenceDatabaseURL.path
            )
        )
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidConfiguration
        ) {
            _ = try fixture.configuration(
                storePath: fixture.diagnosticRoot
                    .appending(path: "alternate.sqlite")
                    .path
            )
        }
    }

    @Test
    func completeIndependentEvidenceProducesReadyVerdict() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configuration = try fixture.configuration()
        let report = try fixture.report(
            configuration: configuration
        )

        #expect(
            report.verdict
                == .signedInvestigationRuntimeReady
        )
        #expect(report.capabilityReport.outcome == .signedRuntimeReady)
        #expect(
            Set(report.denials.map(\.kind))
                == SignedInvestigationRuntimeDenialKind.required
        )
        #expect(report.denials.allSatisfy { $0.contained })
        #expect(
            report.denials.allSatisfy {
                $0.controlReasonKey != nil
                    && $0.failureReasonKey == nil
            }
        )
        #expect(report.residue.isZero)
        let admission = try SignedInvestigationRuntimeAdmissionReceipt(
            report: report
        )
        fixture.materializeOutputs()
        #expect(
            try fixture.verifyReady(
                report,
                configuration: configuration,
                admission: admission,
                now: report.completedAt
            ) == report
        )
    }

    @Test
    func containedDenialPreservesEnforcedControlAttribution() throws {
        let controlReasonKey =
            "runtime.control.outer-seatbelt.write-denied"
        let evidence = try SignedInvestigationRuntimeDenialEvidence(
            kind: .userDataWrite,
            attempted: true,
            contained: true,
            controlReasonKey: controlReasonKey,
            failureReasonKey: nil
        )
        let data = try JSONEncoder().encode(evidence)
        let decoded = try JSONDecoder().decode(
            SignedInvestigationRuntimeDenialEvidence.self,
            from: data
        )

        #expect(decoded == evidence)
        #expect(decoded.attempted)
        #expect(decoded.contained)
        #expect(decoded.controlReasonKey == controlReasonKey)
    }

    @Test
    func missingCapabilityOrUnverifiedDenialCannotProduceReady()
        throws
    {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configuration = try fixture.configuration()

        let blockedCapabilityEvidence =
            try fixture.capabilityEvidence(
                configuration: configuration,
                missing: .subagents
            )
        let capabilityBlocked = try fixture.report(
            configuration: configuration,
            capabilityEvidence: blockedCapabilityEvidence
        )
        #expect(
            capabilityBlocked.verdict
                == .signedInvestigationRuntimeBlocked(
                    reasonKeys: [
                        "runtime.capability.subagents.not-observed",
                    ]
                )
        )

        var denials = try fixture.denials()
        denials.removeLast()
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try fixture.report(
                configuration: configuration,
                denials: denials
            )
        }

        denials = try fixture.denials()
        denials[0] = try SignedInvestigationRuntimeDenialEvidence(
            kind: denials[0].kind,
            attempted: true,
            contained: false,
            controlReasonKey: nil,
            failureReasonKey:
                "runtime.denial.user-write.not-contained"
        )
        let denialBlocked = try fixture.report(
            configuration: configuration,
            denials: denials
        )
        #expect(
            denialBlocked.verdict
                == .signedInvestigationRuntimeBlocked(
                    reasonKeys: [
                        "runtime.denial.user-write.not-contained",
                    ]
                )
        )
    }

    @Test
    func nonSuccessScenarioCanReportFailureButCannotBeAdmitted()
        throws
    {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configuration = try fixture.configuration(
            scenario: .cancellation
        )
        let blockedEvidence = try fixture.capabilityEvidence(
            configuration: configuration,
            missing: .subagents
        )

        let blockedReport = try fixture.report(
            configuration: configuration,
            capabilityEvidence: blockedEvidence
        )
        #expect(
            blockedReport.verdict
                == .signedInvestigationRuntimeBlocked(
                    reasonKeys: [
                        "runtime.capability.subagents.not-observed",
                    ]
                )
        )
        #expect(blockedReport.capabilityEvidence.scenario == .cancellation)
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try SignedInvestigationRuntimeAdmissionReceipt(
                report: blockedReport
            )
        }
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try fixture.report(configuration: configuration)
        }
    }

    @Test
    func foreignNonceAndBindingTamperAreRejected() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configuration = try fixture.configuration()
        let report = try fixture.report(
            configuration: configuration
        )
        let foreign = try fixture.configuration(
            nonce: UUID()
        )
        fixture.materializeOutputs()

        #expect(
            throws:
                SignedInvestigationRuntimeContractError.bindingMismatch
        ) {
            let admission =
                try SignedInvestigationRuntimeAdmissionReceipt(
                    report: report
                )
            _ = try fixture.verifyReady(
                report,
                configuration: foreign,
                admission: admission,
                now: report.completedAt
            )
        }

        let encoded = try JSONEncoder().encode(report)
        var object = try #require(
            JSONSerialization.jsonObject(with: encoded)
                as? [String: Any]
        )
        var binding = try #require(
            object["binding"] as? [String: Any]
        )
        binding["facadeSHA256"] = String(repeating: "b", count: 64)
        object["binding"] = binding
        let tampered = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try JSONDecoder().decode(
                SignedInvestigationRuntimeReport.self,
                from: tampered
            )
        }
    }

    @Test
    func capabilityEvidenceCannotBeRewrappedAcrossRunBindings() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let sourceConfiguration = try fixture.configuration()
        let sourceReceipt =
            try SignedInvestigationCapabilityEvidenceReceipt(
                configuration: sourceConfiguration,
                metadata: fixture.capabilityMetadata(),
                worker: fixture.capabilityWorker(
                    investigationID: sourceConfiguration.nonce,
                    evidenceBindingSHA256:
                        sourceConfiguration
                        .capabilityEvidenceBindingSHA256()
                ),
                lifecycleIntegrity: fixture.capabilityLifecycleIntegrity(),
                repository: fixture.capabilityRepositoryEvidence()
            )
        let sourceReport = try fixture.report(
            configuration: sourceConfiguration,
            capabilityEvidence: sourceReceipt
        )
        #expect(sourceReport.capabilityEvidence == sourceReceipt)
        let foreignNonceConfiguration = try fixture.configuration(
            nonce: UUID()
        )
        let foreignBindingConfiguration = try fixture.configuration(
            binding: fixture.binding(
                sourceFingerprintSHA256: String(repeating: "3", count: 64),
                runtimeReceiptSHA256: String(repeating: "9", count: 64)
            )
        )

        for configuration in [
            foreignNonceConfiguration,
            foreignBindingConfiguration,
        ] {
            #expect(
                throws:
                    SignedInvestigationRuntimeContractError.invalidReport
            ) {
                _ = try fixture.report(
                    configuration: configuration,
                    capabilityEvidence: sourceReceipt
                )
            }
        }
    }

    @Test
    func capabilityEvidenceBindsTheCompleteSignedAttempt() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let sourceConfiguration = try fixture.configuration()
        let sourceBinding =
            try sourceConfiguration.capabilityEvidenceBindingSHA256()
        let foreignConfiguration = try fixture.configuration(
            binding: fixture.binding(
                sourceFingerprintSHA256: String(repeating: "3", count: 64),
                runtimeReceiptSHA256: String(repeating: "9", count: 64)
            )
        )
        let foreignBinding =
            try foreignConfiguration.capabilityEvidenceBindingSHA256()

        #expect(sourceBinding != foreignBinding)
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.bindingMismatch
        ) {
            _ = try SignedInvestigationCapabilityEvidenceReceipt(
                configuration: foreignConfiguration,
                metadata: fixture.capabilityMetadata(),
                worker: fixture.capabilityWorker(
                    investigationID: foreignConfiguration.nonce,
                    evidenceBindingSHA256: sourceBinding
                ),
                lifecycleIntegrity:
                    fixture.capabilityLifecycleIntegrity(),
                repository: fixture.capabilityRepositoryEvidence()
            )
        }
    }

    @Test
    func capabilityEvidenceRejectsTamperedComponentHashesOnDecode()
        throws
    {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configuration = try fixture.configuration()
        let report = try fixture.report(configuration: configuration)
        let encoded = try JSONEncoder().encode(report)

        for key in [
            "metadataSHA256",
            "workerSHA256",
            "lifecycleSHA256",
            "repositorySHA256",
        ] {
            var object = try #require(
                JSONSerialization.jsonObject(with: encoded)
                    as? [String: Any]
            )
            var capabilityEvidence = try #require(
                object["capabilityEvidence"] as? [String: Any]
            )
            let existing = try #require(
                capabilityEvidence[key] as? String
            )
            capabilityEvidence[key] =
                existing == String(repeating: "b", count: 64)
                ? String(repeating: "c", count: 64)
                : String(repeating: "b", count: 64)
            object["capabilityEvidence"] = capabilityEvidence
            let tampered = try JSONSerialization.data(
                withJSONObject: object,
                options: [.sortedKeys]
            )

            #expect(
                throws:
                    SignedInvestigationRuntimeContractError.invalidReport,
                "accepted tampered \(key)"
            ) {
                _ = try JSONDecoder().decode(
                    SignedInvestigationRuntimeReport.self,
                    from: tampered
                )
            }
        }
    }

    @Test
    func capabilityEvidenceReceiptOwnsItsCompletionTimestamp() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configuration = try fixture.configuration()
        let receipt = try fixture.capabilityEvidence(
            configuration: configuration
        )
        var object = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(receipt)
            ) as? [String: Any]
        )

        #expect(object["completedAt"] != nil)
        object["completedAt"] =
            receipt.completedAt.timeIntervalSinceReferenceDate + 1
        let tampered = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try JSONDecoder().decode(
                SignedInvestigationCapabilityEvidenceReceipt.self,
                from: tampered
            )
        }
    }

    @Test
    func readyVerifierRejectsStaleOrFutureCapabilityReceipt()
        throws
    {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configuration = try fixture.configuration()
        fixture.materializeOutputs()

        for completedAt in [
            fixture.now.addingTimeInterval(-4_000),
            fixture.now.addingTimeInterval(31),
        ] {
            let report = try fixture.report(
                configuration: configuration,
                capabilityEvidence: fixture.capabilityEvidence(
                    configuration: configuration,
                    completedAt: completedAt
                )
            )
            let admission =
                try SignedInvestigationRuntimeAdmissionReceipt(
                    report: report
                )

            #expect(
                throws:
                    SignedInvestigationRuntimeContractError.invalidReport
            ) {
                _ = try SignedInvestigationRuntimeReportVerifier()
                    .verifyReady(
                    report,
                    configuration: configuration,
                    capabilityMetadata: fixture.capabilityMetadata(),
                    capabilityWorker: fixture.capabilityWorker(
                        investigationID: configuration.nonce,
                        evidenceBindingSHA256:
                            configuration
                            .capabilityEvidenceBindingSHA256(),
                        completedAt: completedAt
                    ),
                    capabilityLifecycleIntegrity:
                        fixture.capabilityLifecycleIntegrity(),
                    capabilityRepository:
                        fixture.capabilityRepositoryEvidence(),
                    admission: admission,
                    now: report.completedAt
                )
            }
        }
    }

    @Test
    func verifierRejectsForeignRawCapabilityAttempt() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configuration = try fixture.configuration()
        let report = try fixture.report(configuration: configuration)
        let admission = try SignedInvestigationRuntimeAdmissionReceipt(
            report: report
        )
        fixture.materializeOutputs()

        #expect(
            throws:
                SignedInvestigationRuntimeContractError.bindingMismatch
        ) {
            _ = try SignedInvestigationRuntimeReportVerifier()
                .verifyReady(
                    report,
                    configuration: configuration,
                    capabilityMetadata: fixture.capabilityMetadata(),
                    capabilityWorker: fixture.capabilityWorker(
                        investigationID: UUID()
                    ),
                    capabilityLifecycleIntegrity:
                        fixture.capabilityLifecycleIntegrity(),
                    capabilityRepository:
                        fixture.capabilityRepositoryEvidence(),
                    admission: admission,
                    now: report.completedAt
                )
        }
    }

    @Test
    func admissionRejectsRewrappedAndExpiredReadyReports() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configuration = try fixture.configuration()
        let report = try fixture.report(
            configuration: configuration
        )
        let admission = try SignedInvestigationRuntimeAdmissionReceipt(
            report: report
        )
        let rewrapped = try fixture.report(
            configuration: configuration,
            completedAt: report.completedAt.addingTimeInterval(1)
        )
        fixture.materializeOutputs()

        #expect(
            throws:
                SignedInvestigationRuntimeContractError.bindingMismatch
        ) {
            _ = try fixture.verifyReady(
                rewrapped,
                configuration: configuration,
                admission: admission,
                now: rewrapped.completedAt
            )
        }
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidConfiguration
        ) {
            _ = try fixture.verifyReady(
                report,
                configuration: configuration,
                admission: admission,
                now: configuration.validBefore
            )
        }
    }

    @Test
    func verifierAcceptsFreshReportAfterBoundOutputPathsExist()
        throws
    {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configuration = try fixture.configuration()
        let report = try fixture.report(
            configuration: configuration
        )
        let admission = try SignedInvestigationRuntimeAdmissionReceipt(
            report: report
        )
        _ = FileManager.default.createFile(
            atPath: fixture.reportURL.path,
            contents: Data("report".utf8),
            attributes: [.posixPermissions: 0o600]
        )
        _ = FileManager.default.createFile(
            atPath: fixture.storeURL.path,
            contents: Data("store".utf8),
            attributes: [.posixPermissions: 0o600]
        )

        #expect(
            try fixture.verifyReady(
                report,
                configuration: configuration,
                admission: admission,
                now: report.completedAt
            ) == report
        )
    }

    @Test
    func configurationRejectsSymlinkedAncestorDirectory() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let child = fixture.sourceRoot.appending(
            path: "child",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: child,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        let alias = fixture.diagnosticRoot.appending(
            path: "source-alias",
            directoryHint: .isDirectory
        )
        try FileManager.default.createSymbolicLink(
            at: alias,
            withDestinationURL: fixture.sourceRoot
        )

        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidConfiguration
        ) {
            _ = try fixture.configuration(
                sourceRootPath: alias.appending(
                    path: "child",
                    directoryHint: .isDirectory
                ).path
            )
        }
    }

    @Test
    func reportRejectsUnknownFieldsInNestedSignedContracts() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configuration = try fixture.configuration()
        let report = try fixture.report(
            configuration: configuration
        )
        let encoded = try JSONEncoder().encode(report)

        for target in NestedSignedRuntimeTarget.allCases {
            let data = try addingUnknownField(
                to: encoded,
                target: target
            )
            #expect(
                throws:
                    SignedInvestigationRuntimeContractError.invalidReport,
                "accepted unknown field in \(target)"
            ) {
                _ = try JSONDecoder().decode(
                    SignedInvestigationRuntimeReport.self,
                    from: data
                )
            }
        }
    }

    @Test
    func reportRejectsUnknownFieldsInNestedCapabilityReceipt() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configuration = try fixture.configuration()
        let report = try fixture.report(
            configuration: configuration
        )
        let encoded = try JSONEncoder().encode(report)

        for target in NestedCapabilityRuntimeTarget.allCases {
            let data = try addingCapabilityUnknownField(
                to: encoded,
                target: target
            )
            #expect(
                throws:
                    SignedInvestigationRuntimeContractError.invalidReport,
                "accepted capability receipt unknown field in \(target)"
            ) {
                _ = try JSONDecoder().decode(
                    SignedInvestigationRuntimeReport.self,
                    from: data
                )
            }
        }
    }

    @Test
    func reportRejectsUnknownFieldsInVerdictPayloads() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configuration = try fixture.configuration()
        let report = try fixture.report(
            configuration: configuration
        )
        let encoded = try JSONEncoder().encode(report)

        for path in VerdictPayloadPath.allCases {
            let data = try addingVerdictPayloadUnknownField(
                to: encoded,
                path: path
            )
            #expect(
                throws:
                    SignedInvestigationRuntimeContractError.invalidReport,
                "accepted verdict unknown field in \(path)"
            ) {
                _ = try JSONDecoder().decode(
                    SignedInvestigationRuntimeReport.self,
                    from: data
                )
            }
        }
    }

    @Test
    func pendingMachineVerdictCannotOverrideBlockedEvidence() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configuration = try fixture.configuration()
        let blocked = try fixture.report(
            configuration: configuration,
            capabilityEvidence: fixture.capabilityEvidence(
                configuration: configuration,
                missing: .subagents
            )
        )
        var object = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(blocked)
            ) as? [String: Any]
        )
        object["verdict"] = [
            "evidenceContractValidatedMachineAdmissionPending": [:],
        ]
        let forgedPending = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )

        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try JSONDecoder().decode(
                SignedInvestigationRuntimeReport.self,
                from: forgedPending
            )
        }
    }

    @Test
    func machineScenarioIsPartOfTheExactCapabilityAttemptBinding()
        throws
    {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let success = try fixture.configuration(scenario: .success)
        let cancellation = try fixture.configuration(
            scenario: .cancellation
        )

        #expect(success.scenario == .success)
        #expect(cancellation.scenario == .cancellation)
        #expect(
            try success.capabilityEvidenceBindingSHA256()
                != cancellation.capabilityEvidenceBindingSHA256()
        )
        #expect(
            try success.machineConfigurationSHA256()
                != cancellation.machineConfigurationSHA256()
        )
    }

    @Test
    func exactMachineCaseMatrixAcceptsOnlyFreshBoundExpectedOutcomes()
        throws
    {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let cases = try SignedInvestigationRuntimeDiagnosticScenario
            .allCases
            .map { scenario in
                let configuration = try fixture.configuration(
                    nonce: UUID(),
                    scenario: scenario
                )
                return try fixture.caseEvidence(
                    configuration: configuration
                )
            }
        let matrix = try SignedInvestigationRuntimeFailureMatrix(
            cases: cases
        )

        #expect(
            Set(matrix.cases.map(\.scenario))
                == Set(
                    SignedInvestigationRuntimeDiagnosticScenario.allCases
                )
        )
        #expect(Set(matrix.cases.map(\.nonce)).count == cases.count)
        #expect(
            matrix.cases.allSatisfy { $0.isExpectedOutcome }
        )

        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try SignedInvestigationRuntimeFailureMatrix(
                cases: Array(cases.dropLast())
            )
        }
        var replayed = cases
        replayed[1] = try fixture.caseEvidence(
            configuration: try fixture.configuration(
                nonce: cases[0].nonce,
                scenario: replayed[1].scenario
            )
        )
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try SignedInvestigationRuntimeFailureMatrix(
                cases: replayed
            )
        }
    }

    @Test
    func machineMatrixAcceptsFreshPlansForOneExactTargetSet() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configurations = try fixture.machineConfigurations()
        let plans = try configurations.map {
            try fixture.machinePlan(configuration: $0)
        }
        let cases = try zip(configurations, plans).map {
            configuration, plan in
            try fixture.caseEvidence(
                configuration: configuration,
                planFingerprint: plan.fingerprint,
                targetSetFingerprint: plan.targetSetFingerprint
            )
        }

        #expect(Set(plans.map(\.fingerprint)).count == plans.count)
        #expect(
            Set(plans.map(\.targetSetFingerprint)).count == 1
        )

        let matrix = try SignedInvestigationRuntimeFailureMatrix(
            cases: cases
        )
        #expect(matrix.cases.count == configurations.count)

        var replayedPlan = cases
        replayedPlan[1] = try fixture.caseEvidence(
            configuration: configurations[1],
            planFingerprint: plans[0].fingerprint,
            targetSetFingerprint: plans[1].targetSetFingerprint
        )
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try SignedInvestigationRuntimeFailureMatrix(
                cases: replayedPlan
            )
        }
    }

    @Test
    func machineCaseEvidenceRejectsForeignReportIdentity() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configuration = try fixture.configuration(
            scenario: .success
        )
        let evidence = try fixture.caseEvidence(
            configuration: configuration
        )
        var object = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(evidence)
            ) as? [String: Any]
        )
        object["reportID"] =
            "investigation-report-foreign-attempt"
        let foreign = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )

        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try JSONDecoder().decode(
                SignedInvestigationRuntimeMachineCaseEvidence.self,
                from: foreign
            )
        }
    }

    @Test
    func lifecycleAndArtifactFailuresRequireObservedRecoveryAndZeroResidue()
        throws
    {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }

        for scenario in [
            SignedInvestigationRuntimeDiagnosticScenario.lifecycleRecovery,
            .artifactCleanupFailure,
        ] {
            let configuration = try fixture.configuration(
                nonce: UUID(),
                scenario: scenario
            )
            let valid = try fixture.caseEvidence(
                configuration: configuration
            )
            #expect(valid.recoveryAttempted)
            #expect(valid.recoveryCompleted)
            #expect(valid.finalResidue.isZero)

            #expect(
                throws:
                    SignedInvestigationRuntimeContractError.invalidReport
            ) {
                _ = try fixture.caseEvidence(
                    configuration: configuration,
                    recoveryCompleted: false
                )
            }
            #expect(
                throws:
                    SignedInvestigationRuntimeContractError.invalidReport
            ) {
                _ = try fixture.caseEvidence(
                    configuration: configuration,
                    finalResidue:
                        SignedInvestigationRuntimeResidue(
                            appProcessCount: 0,
                            helperProcessCount: 0,
                            workerProcessCount: 1,
                            proxyProcessCount: 0,
                            leaseCount: 0,
                            runtimeArtifactCount: 0
                        )
                )
            }
        }
    }

    @Test
    func machineCaseEvidenceRejectsSuccessOrNonObservationAsContainment()
        throws
    {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configuration = try fixture.configuration(
            scenario: .success
        )
        var denials = try fixture.denials()
        denials[0] = try SignedInvestigationRuntimeDenialEvidence(
            kind: denials[0].kind,
            attempted: false,
            contained: false,
            controlReasonKey: nil,
            failureReasonKey:
                "runtime.denial.not-attempted"
        )

        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try fixture.caseEvidence(
                configuration: configuration,
                denials: denials
            )
        }
    }

    @Test
    func machineAssemblerRejectsIncompleteCapabilityPlane() throws {
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

        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try SignedInvestigationRuntimeMachineAssembler()
                .assemble(
                    configurations: configurations,
                    artifacts: artifacts,
                    capabilityMetadata: fixture.capabilityMetadata(),
                    capabilityWorker: fixture.capabilityWorker(
                        investigationID: success.nonce,
                        evidenceBindingSHA256:
                            success.capabilityEvidenceBindingSHA256(),
                        missing: .directRead
                    ),
                    capabilityLifecycleIntegrity:
                        fixture.capabilityLifecycleIntegrity(),
                    capabilityRepository:
                        fixture.capabilityRepositoryEvidence(),
                    now: artifacts.map(\.completedAt).max()!
                )
        }
    }

    @Test
    func machineAssemblerAcceptsPresealedCohortValidity() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configurations = try fixture.machineConfigurations(
            machineCohortWindow: 1_200
        )
        fixture.materializeOutputs()
        let artifacts = try configurations.map {
            try fixture.caseEvidence(configuration: $0)
        }
        let success = try #require(
            configurations.first { $0.scenario == .success }
        )

        let report = try SignedInvestigationRuntimeMachineAssembler().assemble(
            configurations: configurations, artifacts: artifacts,
            capabilityMetadata: fixture.capabilityMetadata(),
            capabilityWorker: fixture.capabilityWorker(
                investigationID: success.nonce,
                evidenceBindingSHA256: success.capabilityEvidenceBindingSHA256()
            ),
            capabilityLifecycleIntegrity: fixture.capabilityLifecycleIntegrity(),
            capabilityRepository: fixture.capabilityRepositoryEvidence(),
            now: artifacts.map(\.completedAt).max()!
        )

        #expect(report.verdict
            == .evidenceContractValidatedMachineAdmissionPending)
    }

    @Test
    func machineAssemblerRejectsExpiredOrFutureCaseEvidence()
        throws
    {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configurations = try fixture.machineConfigurations()
        fixture.materializeOutputs()
        let validArtifacts = try configurations.map {
            try fixture.caseEvidence(configuration: $0)
        }
        let successConfiguration = try #require(
            configurations.first { $0.scenario == .success }
        )
        let capabilityWorker = try fixture.capabilityWorker(
            investigationID: successConfiguration.nonce,
            evidenceBindingSHA256:
                successConfiguration.capabilityEvidenceBindingSHA256()
        )
        let assembler = SignedInvestigationRuntimeMachineAssembler()

        var expiredArtifacts = validArtifacts
        let expiredIndex = try #require(
            expiredArtifacts.firstIndex {
                $0.scenario == .cancellation
            }
        )
        let expiredConfiguration = configurations[expiredIndex]
        expiredArtifacts[expiredIndex] = try fixture.caseEvidence(
            configuration: expiredConfiguration,
            startedAt:
                expiredConfiguration.validBefore.addingTimeInterval(1),
            completedAt:
                expiredConfiguration.validBefore.addingTimeInterval(2)
        )
        #expect(throws: (any Error).self) {
            _ = try assembler.assemble(
                configurations: configurations,
                artifacts: expiredArtifacts,
                capabilityMetadata: fixture.capabilityMetadata(),
                capabilityWorker: capabilityWorker,
                capabilityLifecycleIntegrity:
                    fixture.capabilityLifecycleIntegrity(),
                capabilityRepository:
                    fixture.capabilityRepositoryEvidence(),
                now: expiredArtifacts.map(\.completedAt).max()!
            )
        }

        var futureArtifacts = validArtifacts
        let futureIndex = try #require(
            futureArtifacts.firstIndex {
                $0.scenario == .transportLoss
            }
        )
        futureArtifacts[futureIndex] = try fixture.caseEvidence(
            configuration: configurations[futureIndex],
            startedAt: fixture.now.addingTimeInterval(60),
            completedAt: fixture.now.addingTimeInterval(61)
        )
        #expect(throws: (any Error).self) {
            _ = try assembler.assemble(
                configurations: configurations,
                artifacts: futureArtifacts,
                capabilityMetadata: fixture.capabilityMetadata(),
                capabilityWorker: capabilityWorker,
                capabilityLifecycleIntegrity:
                    fixture.capabilityLifecycleIntegrity(),
                capabilityRepository:
                    fixture.capabilityRepositoryEvidence(),
                now: fixture.now.addingTimeInterval(30)
            )
        }

        var overlongArtifacts = validArtifacts
        overlongArtifacts[expiredIndex] = try fixture.caseEvidence(
            configuration: expiredConfiguration,
            startedAt: fixture.now,
            completedAt: fixture.now.addingTimeInterval(141)
        )
        #expect(throws: (any Error).self) {
            _ = try assembler.assemble(
                configurations: configurations, artifacts: overlongArtifacts,
                capabilityMetadata: fixture.capabilityMetadata(),
                capabilityWorker: capabilityWorker,
                capabilityLifecycleIntegrity:
                    fixture.capabilityLifecycleIntegrity(),
                capabilityRepository: fixture.capabilityRepositoryEvidence(),
                now: fixture.now.addingTimeInterval(141)
            )
        }
    }

    @Test
    func machineAssemblerRejectsConfigurationExpiredAtVerification()
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

        #expect(throws: (any Error).self) {
            _ = try SignedInvestigationRuntimeMachineAssembler()
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
                    now: success.validBefore.addingTimeInterval(1)
                )
        }
    }

    @Test
    func machineAssemblerRejectsStaleCapabilityObservation()
        throws
    {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configurations = try fixture.machineConfigurations()
        fixture.materializeOutputs()
        let success = try #require(
            configurations.first { $0.scenario == .success }
        )

        for completedAt in [
            fixture.now.addingTimeInterval(-4_000),
            fixture.now.addingTimeInterval(0.5),
            fixture.now.addingTimeInterval(31),
        ] {
            let timestampedArtifacts = try configurations.map {
                try fixture.caseEvidence(
                    configuration: $0,
                    capabilityCompletedAt: completedAt
                )
            }
            #expect(
                throws:
                    SignedInvestigationRuntimeContractError.invalidReport
            ) {
                _ = try SignedInvestigationRuntimeMachineAssembler()
                    .assemble(
                        configurations: configurations,
                        artifacts: timestampedArtifacts,
                        capabilityMetadata: fixture.capabilityMetadata(),
                        capabilityWorker: fixture.capabilityWorker(
                            investigationID: success.nonce,
                            evidenceBindingSHA256:
                                success.capabilityEvidenceBindingSHA256(),
                            completedAt: completedAt
                        ),
                        capabilityLifecycleIntegrity:
                            fixture.capabilityLifecycleIntegrity(),
                        capabilityRepository:
                            fixture.capabilityRepositoryEvidence(),
                        now: fixture.now.addingTimeInterval(30)
                    )
            }
        }
    }

    @Test
    func machineAssemblerAcceptsFreshCapabilityPreflightBeforeProduction()
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
                        success.capabilityEvidenceBindingSHA256(),
                    completedAt: fixture.now.addingTimeInterval(-1)
                ),
                capabilityLifecycleIntegrity:
                    fixture.capabilityLifecycleIntegrity(),
                capabilityRepository:
                    fixture.capabilityRepositoryEvidence(),
                now: fixture.now.addingTimeInterval(30)
            )

        #expect(
            report.verdict
                == .evidenceContractValidatedMachineAdmissionPending
        )
    }

    @Test
    func machineAssemblerRejectsMixedBuildOrPlanEvidence()
        throws
    {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configurations = try fixture.machineConfigurations()
        var mixedConfigurations = configurations
        let mixedIndex = try #require(
            mixedConfigurations.firstIndex {
                $0.scenario == .timeout
            }
        )
        func replaced(
            _ source: SignedInvestigationRuntimeDiagnosticConfiguration,
            binding: SignedInvestigationRuntimeBinding? = nil,
            validBefore: Date? = nil
        ) throws -> SignedInvestigationRuntimeDiagnosticConfiguration {
            var object = try #require(JSONSerialization.jsonObject(
                with: source.canonicalJSONData()
            ) as? [String: Any])
            if let binding {
                object["binding"] = try JSONSerialization.jsonObject(
                    with: JSONEncoder().encode(binding)
                )
            }
            if let validBefore {
                object["validBefore"] = validBefore
                    .timeIntervalSinceReferenceDate
            }
            return try JSONDecoder().decode(
                SignedInvestigationRuntimeDiagnosticConfiguration.self,
                from: JSONSerialization.data(withJSONObject: object)
            )
        }
        mixedConfigurations[mixedIndex] = try replaced(
            configurations[mixedIndex],
            binding: fixture.binding(runtimeReceiptSHA256:
                String(repeating: "c", count: 64))
        )
        var mixedDeadlines = configurations
        mixedDeadlines[mixedIndex] = try replaced(
            configurations[mixedIndex],
            validBefore: fixture.now.addingTimeInterval(299)
        )
        fixture.materializeOutputs()
        let validArtifacts = try configurations.map {
            try fixture.caseEvidence(configuration: $0)
        }
        let successConfiguration = try #require(
            configurations.first { $0.scenario == .success }
        )
        let capabilityWorker = try fixture.capabilityWorker(
            investigationID: successConfiguration.nonce,
            evidenceBindingSHA256:
                successConfiguration.capabilityEvidenceBindingSHA256()
        )
        let assembler = SignedInvestigationRuntimeMachineAssembler()
        var mixedDeadlineArtifacts = validArtifacts
        mixedDeadlineArtifacts[mixedIndex] = try fixture.caseEvidence(
            configuration: mixedDeadlines[mixedIndex]
        )
        #expect(throws: (any Error).self) {
            _ = try assembler.assemble(
                configurations: mixedDeadlines,
                artifacts: mixedDeadlineArtifacts,
                capabilityMetadata: fixture.capabilityMetadata(),
                capabilityWorker: capabilityWorker,
                capabilityLifecycleIntegrity:
                    fixture.capabilityLifecycleIntegrity(),
                capabilityRepository: fixture.capabilityRepositoryEvidence(),
                now: fixture.now.addingTimeInterval(30)
            )
        }

        var mixedArtifacts = validArtifacts
        mixedArtifacts[mixedIndex] = try fixture.caseEvidence(
            configuration: mixedConfigurations[mixedIndex]
        )
        #expect(throws: (any Error).self) {
            _ = try assembler.assemble(
                configurations: mixedConfigurations,
                artifacts: mixedArtifacts,
                capabilityMetadata: fixture.capabilityMetadata(),
                capabilityWorker: capabilityWorker,
                capabilityLifecycleIntegrity:
                    fixture.capabilityLifecycleIntegrity(),
                capabilityRepository:
                    fixture.capabilityRepositoryEvidence(),
                now: fixture.now.addingTimeInterval(30)
            )
        }

        var mixedPlans = validArtifacts
        let planIndex = try #require(
            mixedPlans.firstIndex {
                $0.scenario == .transportLoss
            }
        )
        mixedPlans[planIndex] = try fixture.caseEvidence(
            configuration: configurations[planIndex],
            targetSetFingerprint: try InvestigationFingerprint(
                validatingHex: String(repeating: "d", count: 64)
            )
        )
        #expect(throws: (any Error).self) {
            _ = try assembler.assemble(
                configurations: configurations,
                artifacts: mixedPlans,
                capabilityMetadata: fixture.capabilityMetadata(),
                capabilityWorker: capabilityWorker,
                capabilityLifecycleIntegrity:
                    fixture.capabilityLifecycleIntegrity(),
                capabilityRepository:
                    fixture.capabilityRepositoryEvidence(),
                now: fixture.now.addingTimeInterval(30)
            )
        }
    }

    @Test
    func machineAssemblerRejectsReusedAttemptPathsOrStaleCohort()
        throws
    {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let reusedConfigurations =
            try SignedInvestigationRuntimeDiagnosticScenario
                .allCases
                .map {
                    try fixture.configuration(
                        nonce: UUID(),
                        scenario: $0,
                        reuseDefaultPaths: true
                    )
                }
        fixture.materializeOutputs()
        let reusedArtifacts = try reusedConfigurations.map {
            try fixture.caseEvidence(configuration: $0)
        }
        let reusedSuccess = try #require(
            reusedConfigurations.first { $0.scenario == .success }
        )
        #expect(throws: (any Error).self) {
            _ = try SignedInvestigationRuntimeMachineAssembler()
                .assemble(
                    configurations: reusedConfigurations,
                    artifacts: reusedArtifacts,
                    capabilityMetadata: fixture.capabilityMetadata(),
                    capabilityWorker: fixture.capabilityWorker(
                        investigationID: reusedSuccess.nonce,
                        evidenceBindingSHA256:
                            reusedSuccess
                            .capabilityEvidenceBindingSHA256()
                    ),
                    capabilityLifecycleIntegrity:
                        fixture.capabilityLifecycleIntegrity(),
                    capabilityRepository:
                        fixture.capabilityRepositoryEvidence(),
                    now: fixture.now.addingTimeInterval(30)
                )
        }

        try FileManager.default.removeItem(at: fixture.reportURL)
        try FileManager.default.removeItem(at: fixture.storeURL)
        var freshConfigurations = try fixture.machineConfigurations()
        let staleIndex = try #require(
            freshConfigurations.firstIndex {
                $0.scenario == .cancellation
            }
        )
        freshConfigurations[staleIndex] = try fixture.configuration(
            nonce: freshConfigurations[staleIndex].nonce,
            scenario: .cancellation,
            configurationNow:
                fixture.now.addingTimeInterval(-4_100),
            validBefore:
                fixture.now.addingTimeInterval(-3_900)
        )
        fixture.materializeOutputs()
        var staleArtifacts = try freshConfigurations.map {
            try fixture.caseEvidence(configuration: $0)
        }
        staleArtifacts[staleIndex] = try fixture.caseEvidence(
            configuration: freshConfigurations[staleIndex],
            startedAt: fixture.now.addingTimeInterval(-4_000),
            completedAt: fixture.now.addingTimeInterval(-3_970)
        )
        let freshSuccess = try #require(
            freshConfigurations.first { $0.scenario == .success }
        )
        #expect(throws: (any Error).self) {
            _ = try SignedInvestigationRuntimeMachineAssembler()
                .assemble(
                    configurations: freshConfigurations,
                    artifacts: staleArtifacts,
                    capabilityMetadata: fixture.capabilityMetadata(),
                    capabilityWorker: fixture.capabilityWorker(
                        investigationID: freshSuccess.nonce,
                        evidenceBindingSHA256:
                            freshSuccess
                            .capabilityEvidenceBindingSHA256()
                    ),
                    capabilityLifecycleIntegrity:
                        fixture.capabilityLifecycleIntegrity(),
                    capabilityRepository:
                        fixture.capabilityRepositoryEvidence(),
                    now: fixture.now.addingTimeInterval(30)
                )
        }
    }

    @Test
    func machineAssemblerRejectsUndeclaredDiagnosticResidue()
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
        let residueURLs = [
            URL(filePath: success.sourceRootPath)
                .appending(path: "stale-source-fixture.txt"),
            URL(filePath: success.runtimeRootPath)
                .appending(path: "stale-runtime.json"),
            URL(filePath: success.supportRootPath)
                .appending(path: "stale-auth-projection.json"),
            URL(filePath: success.diagnosticRootPath)
                .appending(path: "unexpected-machine-artifact.json"),
        ]

        for residueURL in residueURLs {
            try writeOwnerOnly(
                Data("undeclared-runtime-residue".utf8),
                to: residueURL
            )
            #expect(
                throws:
                    SignedInvestigationRuntimeContractError.invalidReport,
                "residue=\(residueURL.lastPathComponent)"
            ) {
                _ = try SignedInvestigationRuntimeMachineAssembler()
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
                        now: fixture.now.addingTimeInterval(30)
                    )
            }
            try FileManager.default.removeItem(at: residueURL)
        }
    }

    @Test
    func machineAssemblerRejectsUndeclaredCohortAttempt()
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
        let cohortRoot = URL(filePath: success.diagnosticRootPath)
            .deletingLastPathComponent()
        let undeclaredAttempt = cohortRoot.appending(
            path: "undeclared-attempt",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: undeclaredAttempt,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        try writeOwnerOnly(
            Data("undeclared-cohort-residue".utf8),
            to: undeclaredAttempt.appending(path: "runtime.json")
        )

        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try SignedInvestigationRuntimeMachineAssembler()
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
                    now: fixture.now.addingTimeInterval(30)
                )
        }
    }

    @Test
    func machineAssemblerRejectsMissingOrForgedLifecycleObservation()
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
        let evidence = try SignedInvestigationRuntimeMachineEvidenceBundle(
            configurations: configurations,
            artifacts: artifacts,
            lifecycleResidueRecords: [],
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

        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try SignedInvestigationRuntimeMachineAssembler()
                .assemble(
                    evidence: evidence,
                    now: fixture.now.addingTimeInterval(30)
                )
        }

        let authoritativeRecords =
            try fixture.lifecycleResidueRecords(
                artifacts: artifacts
            )
        let forgedRecords = try artifacts.map {
            let residue =
                $0.scenario == .success
                ? SignedInvestigationRuntimeResidue(
                    appProcessCount: 0,
                    helperProcessCount: 0,
                    workerProcessCount: 1,
                    proxyProcessCount: 0,
                    leaseCount: 0,
                    runtimeArtifactCount: 0
                )
                : $0.finalResidue
            return try SignedInvestigationRuntimeLifecycleResidueRecord(
                scenario: $0.scenario,
                nonce: $0.nonce,
                binding: $0.binding,
                observedAt: $0.completedAt,
                residue: residue
            )
        }
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try SignedInvestigationRuntimeMachineAssembler()
                .assemble(
                    configurations: configurations,
                    artifacts: artifacts,
                    lifecycleResidueRecords: forgedRecords,
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
                    sealedCohortAuthority:
                        TestSignedInvestigationRuntimeSealedCohortAuthority(
                            lifecycleRecords: authoritativeRecords
                        ),
                    now: fixture.now.addingTimeInterval(30)
                )
        }
    }

    @Test
    func machineAssemblerRejectsMutationBeforeFinalRevalidation()
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
        let assembler = SignedInvestigationRuntimeMachineAssembler {
            phase in
            guard phase == .beforeFinalRevalidation else { return }
            try writeOwnerOnly(
                Data("late-runtime-residue".utf8),
                to: URL(filePath: success.runtimeRootPath)
                    .appending(path: "late-residue.json")
            )
        }

        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try assembler.assemble(
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
                    fixture.capabilityRepositoryEvidence(),
                sealedCohortAuthority:
                    TestSignedInvestigationRuntimeSealedCohortAuthority(
                        lifecycleRecords:
                            fixture.lifecycleResidueRecords(
                                artifacts: artifacts
                            )
                    ),
                now: fixture.now.addingTimeInterval(30)
            )
        }
    }

    @Test
    func machineAssemblerRejectsMutationAfterEarlierFinalRevalidation()
        throws
    {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configurations = try fixture.machineConfigurations()
        fixture.materializeOutputs()
        let artifacts = try configurations.map {
            try fixture.caseEvidence(configuration: $0)
        }
        let firstArtifact = try #require(
            SignedInvestigationRuntimeFailureMatrix(cases: artifacts)
                .cases.first
        )
        let firstConfiguration = try #require(
            configurations.first {
                $0.scenario == firstArtifact.scenario
            }
        )
        let successConfiguration = try #require(
            configurations.first { $0.scenario == .success }
        )
        let assembler = SignedInvestigationRuntimeMachineAssembler {
            phase in
            guard
                phase
                    == .afterFinalRevalidation(firstArtifact.scenario)
            else {
                return
            }
            try writeOwnerOnly(
                Data("post-revalidation-residue".utf8),
                to: URL(filePath: firstConfiguration.runtimeRootPath)
                    .appending(path: "post-revalidation.json")
            )
        }

        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try assembler.assemble(
                configurations: configurations,
                artifacts: artifacts,
                lifecycleResidueRecords:
                    fixture.lifecycleResidueRecords(
                        artifacts: artifacts
                    ),
                capabilityMetadata: fixture.capabilityMetadata(),
                capabilityWorker: fixture.capabilityWorker(
                    investigationID: successConfiguration.nonce,
                    evidenceBindingSHA256:
                        successConfiguration
                        .capabilityEvidenceBindingSHA256()
                ),
                capabilityLifecycleIntegrity:
                    fixture.capabilityLifecycleIntegrity(),
                capabilityRepository:
                    fixture.capabilityRepositoryEvidence(),
                sealedCohortAuthority:
                    TestSignedInvestigationRuntimeSealedCohortAuthority(
                        lifecycleRecords:
                            fixture.lifecycleResidueRecords(
                                artifacts: artifacts
                            )
                    ),
                now: fixture.now.addingTimeInterval(30)
            )
        }
    }

    @Test
    func machineLifecycleObservationCannotBeDecodedAsTrustedEvidence()
        throws
    {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configurations = try fixture.machineConfigurations()
        fixture.materializeOutputs()
        let artifacts = try configurations.map {
            try fixture.caseEvidence(configuration: $0)
        }
        let records = try fixture.lifecycleResidueRecords(
            artifacts: artifacts
        )
        let successConfiguration = try #require(
            configurations.first { $0.scenario == .success }
        )
        let bundle = try SignedInvestigationRuntimeMachineEvidenceBundle(
            configurations: configurations,
            artifacts: artifacts,
            lifecycleResidueRecords: records,
            capabilityMetadata: fixture.capabilityMetadata(),
            capabilityWorker: fixture.capabilityWorker(
                investigationID: successConfiguration.nonce,
                evidenceBindingSHA256:
                    successConfiguration
                    .capabilityEvidenceBindingSHA256()
            ),
            capabilityLifecycleIntegrity:
                fixture.capabilityLifecycleIntegrity(),
            capabilityRepository:
                fixture.capabilityRepositoryEvidence()
        )
        let bundleData = try bundle.canonicalJSONData()

        #expect(
            !((SignedInvestigationRuntimeLifecycleResidueObservation.self
                as Any.Type) is any Decodable.Type)
        )
        let decoded = try JSONDecoder().decode(
            SignedInvestigationRuntimeMachineEvidenceBundle.self,
            from: bundleData
        )
        #expect(
            decoded.lifecycleResidueRecords
                == records.sorted {
                    $0.scenario.rawValue < $1.scenario.rawValue
                }
        )
        #expect(decoded == bundle)

        var wrongProfile = try #require(
            JSONSerialization.jsonObject(with: bundleData) as? [String: Any]
        )
        var encodedConfigurations = try #require(
            wrongProfile["configurations"] as? [[String: Any]]
        )
        encodedConfigurations[0]["maximumTurns"] = 2
        wrongProfile["configurations"] = encodedConfigurations
        #expect(throws: SignedInvestigationRuntimeContractError.invalidReport) {
            _ = try JSONDecoder().decode(
                SignedInvestigationRuntimeMachineEvidenceBundle.self,
                from: JSONSerialization.data(withJSONObject: wrongProfile)
            )
        }
    }

    @Test
    func machineUpstreamErrorsAreSanitizedAndStrict()
        throws
    {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configuration = try fixture.configuration(
            scenario: .cancellation
        )
        let upstreamError = try SignedInvestigationRuntimeUpstreamError(
            category: .usageLimit,
            code: "provider.rate_limit",
            willRetry: true
        )
        let evidence = try fixture.caseEvidence(
            configuration: configuration,
            upstreamError: upstreamError
        )
        #expect(evidence.upstreamError == upstreamError)

        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try SignedInvestigationRuntimeUpstreamError(
                category: .runtime,
                code: "secret/path\nunsafe",
                willRetry: false
            )
        }

        var object = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(evidence)
            ) as? [String: Any]
        )
        var errorObject = try #require(
            object["upstreamError"] as? [String: Any]
        )
        errorObject["details"] = "must-not-survive"
        object["upstreamError"] = errorObject
        let tampered = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try JSONDecoder().decode(
                SignedInvestigationRuntimeMachineCaseEvidence.self,
                from: tampered
            )
        }
    }

}

private enum NestedSignedRuntimeTarget:
    String,
    CaseIterable,
    CustomStringConvertible
{
    case binding
    case production
    case denial
    case residue

    var description: String {
        rawValue
    }
}

private enum NestedCapabilityRuntimeTarget:
    String,
    CaseIterable,
    CustomStringConvertible
{
    case report
    case metadata
    case capability
    case integrity

    var description: String {
        rawValue
    }
}

private enum VerdictPayloadPath:
    String,
    CaseIterable,
    CustomStringConvertible
{
    case reportVerdict
    case capabilityOutcome

    var description: String {
        rawValue
    }
}

private func addingUnknownField(
    to data: Data,
    target: NestedSignedRuntimeTarget
) throws -> Data {
    var object = try #require(
        JSONSerialization.jsonObject(with: data)
            as? [String: Any]
    )
    switch target {
    case .binding, .production, .residue:
        var nested = try #require(
            object[target.rawValue] as? [String: Any]
        )
        nested["unexpected"] = true
        object[target.rawValue] = nested
    case .denial:
        var denials = try #require(
            object["denials"] as? [[String: Any]]
        )
        denials[0]["unexpected"] = true
        object["denials"] = denials
    }
    return try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys]
    )
}

private func addingCapabilityUnknownField(
    to data: Data,
    target: NestedCapabilityRuntimeTarget
) throws -> Data {
    var object = try #require(
        JSONSerialization.jsonObject(with: data)
            as? [String: Any]
    )
    var capabilityEvidence = try #require(
        object["capabilityEvidence"] as? [String: Any]
    )
    var capabilityReport = try #require(
        capabilityEvidence["report"] as? [String: Any]
    )
    switch target {
    case .report:
        capabilityReport["unexpected"] = true
    case .metadata:
        var metadata = try #require(
            capabilityReport["metadata"] as? [String: Any]
        )
        metadata["unexpected"] = true
        capabilityReport["metadata"] = metadata
    case .capability:
        var capabilities = try #require(
            capabilityReport["capabilities"] as? [[String: Any]]
        )
        capabilities[0]["unexpected"] = true
        capabilityReport["capabilities"] = capabilities
    case .integrity:
        var integrity = try #require(
            capabilityReport["integrity"] as? [[String: Any]]
        )
        integrity[0]["unexpected"] = true
        capabilityReport["integrity"] = integrity
    }
    capabilityEvidence["report"] = capabilityReport
    object["capabilityEvidence"] = capabilityEvidence
    return try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys]
    )
}

private func addingVerdictPayloadUnknownField(
    to data: Data,
    path: VerdictPayloadPath
) throws -> Data {
    var object = try #require(
        JSONSerialization.jsonObject(with: data)
            as? [String: Any]
    )
    switch path {
    case .reportVerdict:
        object["verdict"] = try verdictWithUnknownField(
            object["verdict"]
        )
    case .capabilityOutcome:
        var capabilityEvidence = try #require(
            object["capabilityEvidence"] as? [String: Any]
        )
        var capabilityReport = try #require(
            capabilityEvidence["report"] as? [String: Any]
        )
        capabilityReport["outcome"] = try verdictWithUnknownField(
            capabilityReport["outcome"]
        )
        capabilityEvidence["report"] = capabilityReport
        object["capabilityEvidence"] = capabilityEvidence
    }
    return try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys]
    )
}

private func verdictWithUnknownField(_ value: Any?) throws -> Any {
    var verdict = try #require(value as? [String: Any])
    let caseKey = try #require(verdict.keys.first)
    var payload = try #require(verdict[caseKey] as? [String: Any])
    payload["unexpected"] = true
    verdict[caseKey] = payload
    return verdict
}

func writeOwnerOnly(_ data: Data, to url: URL) throws {
    try data.write(to: url, options: .withoutOverwriting)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o600],
        ofItemAtPath: url.path
    )
}

extension SignedInvestigationRuntimeMachineAssembler {
    func assemble(
        evidence: SignedInvestigationRuntimeMachineEvidenceBundle,
        now: Date
    ) throws -> SignedInvestigationRuntimeMachineReport {
        return try assemble(
            evidence: evidence,
            sealedCohortAuthority:
                TestSignedInvestigationRuntimeSealedCohortAuthority(
                    lifecycleRecords:
                        evidence.lifecycleResidueRecords
                ),
            now: now
        )
    }

    func assemble(
        configurations:
            [SignedInvestigationRuntimeDiagnosticConfiguration],
        artifacts: [SignedInvestigationRuntimeMachineCaseEvidence],
        lifecycleResidueRecords:
            [SignedInvestigationRuntimeLifecycleResidueRecord],
        capabilityMetadata: CapabilityRuntimeDiagnosticMetadata,
        capabilityWorker: CapabilityRuntimeWorkerEvidence,
        capabilityLifecycleIntegrity:
            [CapabilityRuntimeIntegrityEvidence],
        capabilityRepository: CapabilityRuntimeRepositoryEvidence,
        now: Date
    ) throws -> SignedInvestigationRuntimeMachineReport {
        return try assemble(
            configurations: configurations,
            artifacts: artifacts,
            lifecycleResidueRecords: lifecycleResidueRecords,
            capabilityMetadata: capabilityMetadata,
            capabilityWorker: capabilityWorker,
            capabilityLifecycleIntegrity:
                capabilityLifecycleIntegrity,
            capabilityRepository: capabilityRepository,
            sealedCohortAuthority:
                TestSignedInvestigationRuntimeSealedCohortAuthority(
                    lifecycleRecords: lifecycleResidueRecords
                ),
            now: now
        )
    }

    func assemble(
        configurations:
            [SignedInvestigationRuntimeDiagnosticConfiguration],
        artifacts: [SignedInvestigationRuntimeMachineCaseEvidence],
        capabilityMetadata: CapabilityRuntimeDiagnosticMetadata,
        capabilityWorker: CapabilityRuntimeWorkerEvidence,
        capabilityLifecycleIntegrity:
            [CapabilityRuntimeIntegrityEvidence],
        capabilityRepository: CapabilityRuntimeRepositoryEvidence,
        now: Date
    ) throws -> SignedInvestigationRuntimeMachineReport {
        let lifecycleRecords = try artifacts.map {
            try SignedInvestigationRuntimeLifecycleResidueRecord(
                scenario: $0.scenario,
                nonce: $0.nonce,
                binding: $0.binding,
                observedAt: $0.completedAt,
                residue: $0.finalResidue
            )
        }
        return try assemble(
            configurations: configurations,
            artifacts: artifacts,
            lifecycleResidueRecords: lifecycleRecords,
            capabilityMetadata: capabilityMetadata,
            capabilityWorker: capabilityWorker,
            capabilityLifecycleIntegrity:
                capabilityLifecycleIntegrity,
            capabilityRepository: capabilityRepository,
            sealedCohortAuthority:
                TestSignedInvestigationRuntimeSealedCohortAuthority(
                    lifecycleRecords: lifecycleRecords
                ),
            now: now
        )
    }
}

extension SignedInvestigationRuntimeMachineVerifier {
    func verifyCandidate(
        _ report: SignedInvestigationRuntimeMachineReport,
        evidence: SignedInvestigationRuntimeMachineEvidenceBundle,
        now: Date
    ) throws -> SignedInvestigationRuntimeMachineReport {
        return try verifyCandidate(
            report,
            evidence: evidence,
            sealedCohortAuthority:
                TestSignedInvestigationRuntimeSealedCohortAuthority(
                    lifecycleRecords:
                        evidence.lifecycleResidueRecords
                ),
            now: now
        )
    }

    func verifyCandidate(
        _ report: SignedInvestigationRuntimeMachineReport,
        configurations:
            [SignedInvestigationRuntimeDiagnosticConfiguration],
        artifacts: [SignedInvestigationRuntimeMachineCaseEvidence],
        capabilityMetadata: CapabilityRuntimeDiagnosticMetadata,
        capabilityWorker: CapabilityRuntimeWorkerEvidence,
        capabilityLifecycleIntegrity:
            [CapabilityRuntimeIntegrityEvidence],
        capabilityRepository: CapabilityRuntimeRepositoryEvidence,
        now: Date
    ) throws -> SignedInvestigationRuntimeMachineReport {
        let lifecycleRecords = try artifacts.map {
            try SignedInvestigationRuntimeLifecycleResidueRecord(
                scenario: $0.scenario,
                nonce: $0.nonce,
                binding: $0.binding,
                observedAt: $0.completedAt,
                residue: $0.finalResidue
            )
        }
        return try verifyCandidate(
            report,
            configurations: configurations,
            artifacts: artifacts,
            lifecycleResidueRecords: lifecycleRecords,
            capabilityMetadata: capabilityMetadata,
            capabilityWorker: capabilityWorker,
            capabilityLifecycleIntegrity:
                capabilityLifecycleIntegrity,
            capabilityRepository: capabilityRepository,
            sealedCohortAuthority:
                TestSignedInvestigationRuntimeSealedCohortAuthority(
                    lifecycleRecords: lifecycleRecords
                ),
            now: now
        )
    }
}

private struct TestSignedInvestigationRuntimeSealedCohortAuthority:
    SignedInvestigationRuntimeSealedCohortAuthority
{
    let lifecycleRecords:
        [SignedInvestigationRuntimeLifecycleResidueRecord]

    func withSealedCohort<Result: Sendable>(
        configurations:
            [SignedInvestigationRuntimeDiagnosticConfiguration],
        expectedLifecycleResidueRecords:
            [SignedInvestigationRuntimeLifecycleResidueRecord],
        _ operation:
            @Sendable (
                [
                    SignedInvestigationRuntimeLifecycleResidueObservation
                ]
            ) throws -> Result
    ) throws -> Result {
        guard
            lifecycleRecords.sorted(by: lifecycleRecordOrder)
                == expectedLifecycleResidueRecords.sorted(
                    by: lifecycleRecordOrder
                )
        else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        guard !configurations.isEmpty else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        return try operation(
            lifecycleRecords.map {
                SignedInvestigationRuntimeLifecycleResidueObservation(
                    record: $0
                )
            }
        )
    }

    private func lifecycleRecordOrder(
        _ left: SignedInvestigationRuntimeLifecycleResidueRecord,
        _ right: SignedInvestigationRuntimeLifecycleResidueRecord
    ) -> Bool {
        left.scenario.rawValue < right.scenario.rawValue
    }
}

struct SignedRuntimeContractFixture {
    let now: Date
    let nonce = UUID(
        uuidString: "11111111-2222-4333-8444-555555555555"
    )!
    let root: URL
    let diagnosticRoot: URL
    let sourceRoot: URL
    let supportRoot: URL
    let runtimeRoot: URL
    let reportURL: URL
    let storeURL: URL

    init(
        now: Date = Date(timeIntervalSince1970: 1_800_000_000)
    ) throws {
        self.now = now
        let temporaryPath = FileManager.default.temporaryDirectory.path
        let resolvedTemporaryPath = try #require(
            realpath(temporaryPath, nil)
        )
        defer { free(resolvedTemporaryPath) }
        root = URL(
            filePath: String(cString: resolvedTemporaryPath),
            directoryHint: .isDirectory
        )
            .appending(
            path: "stornaut-task39-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        diagnosticRoot = root.appending(
            path: "diagnostic",
            directoryHint: .isDirectory
        )
        sourceRoot = diagnosticRoot.appending(
            path: "source",
            directoryHint: .isDirectory
        )
        supportRoot = diagnosticRoot.appending(
            path: "support",
            directoryHint: .isDirectory
        )
        runtimeRoot = diagnosticRoot.appending(
            path: "runtime",
            directoryHint: .isDirectory
        )
        reportURL = diagnosticRoot.appending(path: "report.json")
        storeURL = supportRoot
            .appending(
                path: "com.eriklee.stornaut",
                directoryHint: .isDirectory
            )
            .appending(path: "Evidence.sqlite")
        try FileManager.default.createDirectory(
            at: sourceRoot,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.createDirectory(
            at: supportRoot,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.createDirectory(
            at: runtimeRoot,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }

    func materializeOutputs() {
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        let supportURLs = (enumerator?.allObjects as? [URL] ?? [])
            .filter { $0.lastPathComponent == "support" }
        for supportURL in supportURLs {
            let reportURL = supportURL.deletingLastPathComponent()
                .appending(path: "report.json")
            let storeURL = supportURL
                .appending(
                    path: "com.eriklee.stornaut",
                    directoryHint: .isDirectory
                )
                .appending(path: "Evidence.sqlite")
            _ = FileManager.default.createFile(
                atPath: reportURL.path,
                contents: Data(
                    "report:\(reportURL.deletingLastPathComponent().lastPathComponent)"
                        .utf8
                ),
                attributes: [.posixPermissions: 0o600]
            )
            _ = FileManager.default.createFile(
                atPath: storeURL.path,
                contents: Data("store".utf8),
                attributes: [.posixPermissions: 0o600]
            )
        }
    }

    func configurationData() throws -> Data {
        try JSONEncoder().encode(configuration())
    }

    func machineConfigurations(
        machineCohortWindow: TimeInterval? = nil
    ) throws
        -> [SignedInvestigationRuntimeDiagnosticConfiguration]
    {
        try SignedInvestigationRuntimeDiagnosticScenario.allCases.map {
            try configuration(
                nonce: UUID(), scenario: $0,
                machineCohortWindow: machineCohortWindow
            )
        }
    }

    func machinePlan(
        configuration: SignedInvestigationRuntimeDiagnosticConfiguration
    ) throws -> InvestigationPlan {
        let scanSessionID = ScanSessionID(
            rawValue: "scan-task39-machine-cohort"
        )!
        let scanScopeID = ScanScopeID(
            rawValue: "scope-task39-machine-cohort"
        )!
        let target = try InvestigationTarget(
            scanSessionID: scanSessionID,
            scanScopeID: scanScopeID,
            sourceBinding: .snapshot(
                SnapshotID(
                    rawValue: "snapshot-task39-machine-cohort"
                )!
            ),
            kind: .unknownLargeConsumer,
            reasonKeys: [
                DomainToken(rawValue: "reason.task39.machine")!,
            ],
            expectedAllocatedBytes: ByteCount(2_147_483_648),
            uncertaintyPermille: 900,
            relevancePermille: 800,
            investigationCostPermille: 500,
            createdAt: now
        )
        return try InvestigationPlan(
            id: InvestigationID(
                rawValue: "investigation-"
                    + configuration.nonce.uuidString.lowercased()
            )!,
            scanSessionID: scanSessionID,
            scanScopeID: scanScopeID,
            sourceFingerprint: InvestigationFingerprint(
                validatingHex:
                    configuration.binding.sourceFingerprintSHA256
            ),
            budgetPreset: .focused,
            targets: [target],
            createdAt: now,
            expiresAt: now.addingTimeInterval(3_600),
            requestedCoveragePermille:
                InvestigationPlan.policyRequestedCoveragePermille,
            remainingUnknownByteThreshold:
                InvestigationPlan.policyRemainingUnknownByteThreshold,
            requiredCapabilities: InvestigationCapability.required
        )
    }

    func configuration(
        nonce: UUID? = nil,
        scenario: SignedInvestigationRuntimeDiagnosticScenario = .success,
        diagnosticRootPath: String? = nil,
        sourceRootPath: String? = nil,
        supportRootPath: String? = nil,
        storePath: String? = nil,
        binding: SignedInvestigationRuntimeBinding? = nil,
        reuseDefaultPaths: Bool = false,
        configurationNow: Date? = nil,
        validBefore: Date? = nil,
        machineCohortWindow: TimeInterval? = nil
    ) throws -> SignedInvestigationRuntimeDiagnosticConfiguration {
        let selectedNonce = nonce ?? self.nonce
        let paths = try attemptPaths(
            nonce: selectedNonce,
            reuseDefaultPaths: reuseDefaultPaths,
            diagnosticRootPath: diagnosticRootPath
        )
        let deadline = validBefore ?? now.addingTimeInterval(
            machineCohortWindow ?? 300
        )
        if machineCohortWindow != nil {
            return try SignedInvestigationRuntimeDiagnosticConfiguration
                .machineCohort(
                nonce: selectedNonce, scenario: scenario,
                optIn: SignedInvestigationRuntimeDiagnosticConfiguration
                    .requiredOptIn,
                diagnosticRootPath: paths.diagnosticRoot.path,
                sourceRootPath: sourceRootPath ?? paths.sourceRoot.path,
                supportRootPath: supportRootPath ?? paths.supportRoot.path,
                runtimeRootPath: paths.runtimeRoot.path,
                reportPath: paths.reportURL.path,
                storePath: storePath ?? paths.storeURL.path,
                binding: binding ?? self.binding(),
                expectedModel: .gpt56Luna, expectedProvider: .openAI,
                validBefore: deadline, maximumWallClockSeconds: 140,
                maximumTurns: 3, maximumProbeCalls: 16,
                maximumContextBytes: 1_048_576,
                now: configurationNow ?? now
            )
        }
        return try SignedInvestigationRuntimeDiagnosticConfiguration(
            nonce: selectedNonce,
            scenario: scenario,
            optIn:
                SignedInvestigationRuntimeDiagnosticConfiguration
                    .requiredOptIn,
            diagnosticRootPath: paths.diagnosticRoot.path,
            sourceRootPath: sourceRootPath ?? paths.sourceRoot.path,
            supportRootPath: supportRootPath ?? paths.supportRoot.path,
            runtimeRootPath: paths.runtimeRoot.path,
            reportPath: paths.reportURL.path,
            storePath: storePath ?? paths.storeURL.path,
            binding: binding ?? self.binding(),
            expectedModel: .gpt56Luna,
            expectedProvider: .openAI,
            validBefore: deadline,
            maximumWallClockSeconds: 140,
            maximumTurns: 3,
            maximumProbeCalls: 16,
            maximumContextBytes: 1_048_576,
            now: configurationNow ?? now
        )
    }

    private func attemptPaths(
        nonce: UUID,
        reuseDefaultPaths: Bool,
        diagnosticRootPath: String?
    ) throws -> AttemptPaths {
        if diagnosticRootPath == nil,
           nonce == self.nonce || reuseDefaultPaths
        {
            return AttemptPaths(
                diagnosticRoot: diagnosticRoot,
                sourceRoot: sourceRoot,
                supportRoot: supportRoot,
                runtimeRoot: runtimeRoot,
                reportURL: reportURL,
                storeURL: storeURL
            )
        }
        let diagnosticRoot = diagnosticRootPath.map {
            URL(filePath: $0, directoryHint: .isDirectory)
        } ?? root
            .appending(path: "attempts", directoryHint: .isDirectory)
            .appending(
                path: nonce.uuidString.lowercased(),
                directoryHint: .isDirectory
            )
        let sourceRoot = diagnosticRoot.appending(
            path: "source",
            directoryHint: .isDirectory
        )
        let supportRoot = diagnosticRoot.appending(
            path: "support",
            directoryHint: .isDirectory
        )
        let runtimeRoot = diagnosticRoot.appending(
            path: "runtime",
            directoryHint: .isDirectory
        )
        let reportURL = diagnosticRoot.appending(path: "report.json")
        let storeURL = supportRoot
            .appending(
                path: "com.eriklee.stornaut",
                directoryHint: .isDirectory
            )
            .appending(path: "Evidence.sqlite")
        for directory in [
            sourceRoot,
            storeURL.deletingLastPathComponent(),
            runtimeRoot,
        ] {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        }
        return AttemptPaths(
            diagnosticRoot: diagnosticRoot,
            sourceRoot: sourceRoot,
            supportRoot: supportRoot,
            runtimeRoot: runtimeRoot,
            reportURL: reportURL,
            storeURL: storeURL
        )
    }

    private struct AttemptPaths {
        let diagnosticRoot: URL
        let sourceRoot: URL
        let supportRoot: URL
        let runtimeRoot: URL
        let reportURL: URL
        let storeURL: URL
    }

    func binding(
        sourceFingerprintSHA256: String? = nil,
        runtimeReceiptSHA256: String? = nil
    ) -> SignedInvestigationRuntimeBinding {
        let repositoryHEAD = String(repeating: "1", count: 40)
        let sourceFingerprintSHA256 =
            sourceFingerprintSHA256
            ?? String(repeating: "2", count: 64)
        let canonicalRuntimeReceiptSHA256 = try!
            InvestigationRuntimeReceiptCanonicalV1.sha256(
                InvestigationRuntimeReceiptCanonicalV1.receipt(
                    repositoryHEAD: repositoryHEAD,
                    sourceFingerprintSHA256: sourceFingerprintSHA256
                )
            )
        return SignedInvestigationRuntimeBinding(
            repositoryHEAD: repositoryHEAD,
            sourceFingerprintSHA256: sourceFingerprintSHA256,
            appExecutableSHA256: String(repeating: "a", count: 64),
            helperExecutableSHA256: String(repeating: "4", count: 64),
            runtimeReceiptSHA256:
                runtimeReceiptSHA256
                ?? canonicalRuntimeReceiptSHA256,
            promptSHA256: String(repeating: "6", count: 64),
            envelopeSchemaSHA256: String(repeating: "7", count: 64),
            facadeSHA256: String(repeating: "8", count: 64),
            codexExecutableSHA256: String(repeating: "a", count: 64),
            appBundleIdentifier: "com.eriklee.stornaut",
            helperServiceIdentifier:
                "com.eriklee.stornaut.lifecycle",
            machineDriver: machineDriverBinding()
        )
    }

    func machineDriverBinding()
        -> SignedInvestigationRuntimeMachineDriverBinding
    {
        try! SignedInvestigationRuntimeMachineDriverBinding(
            executableSHA256: String(repeating: "b", count: 64),
            signingIdentifier:
                "com.eriklee.stornaut.investigation.machine-driver",
            designatedRequirementSHA256:
                String(repeating: "c", count: 64),
            codeDirectoryHash: String(repeating: "4", count: 64),
            machineClaimServiceIdentifier:
                "com.eriklee.stornaut.lifecycle.machine-claim"
        )
    }

    func installationObservation()
        -> InvestigationRuntimeDiagnosticBindingObservation
    {
        let app = URL(
            filePath:
                "/Library/Application Support/Stornaut/"
                + "Stornaut-R5-Diagnostic.app",
            directoryHint: .isDirectory
        )
        return InvestigationRuntimeDiagnosticBindingObservation(
            installedAppURL: app,
            helperExecutableURL: app.appending(
                path: "Contents/MacOS/StornautLifecycleHelper"
            ),
            appExecutableName: "StornautInvestigationDiagnostic",
            appExecutableSHA256: binding().appExecutableSHA256,
            helperExecutableSHA256:
                binding().helperExecutableSHA256,
            appBundleIdentifier: binding().appBundleIdentifier,
            helperSigningIdentifier:
                "com.eriklee.stornaut.lifecycle.helper",
            serviceIdentifier: binding().helperServiceIdentifier,
            machineDriverExecutableURL: app.appending(
                path: "Contents/MacOS/"
                    + "StornautInvestigationMachineDriver"
            ),
            machineDriverExecutableSHA256:
                binding().machineDriver.executableSHA256,
            machineDriverSigningIdentifier:
                binding().machineDriver.signingIdentifier,
            machineDriverDesignatedRequirementSHA256:
                binding().machineDriver
                    .designatedRequirementSHA256,
            machineDriverCodeDirectoryHash:
                binding().machineDriver.codeDirectoryHash,
            machineClaimServiceIdentifier:
                binding().machineDriver
                    .machineClaimServiceIdentifier
        )
    }

    func report(
        configuration:
            SignedInvestigationRuntimeDiagnosticConfiguration,
        capabilityEvidence:
            SignedInvestigationCapabilityEvidenceReceipt? = nil,
        denials: [SignedInvestigationRuntimeDenialEvidence]? = nil,
        completedAt: Date? = nil
    ) throws -> SignedInvestigationRuntimeReport {
        let evidence =
            try capabilityEvidence
            ?? self.capabilityEvidence(configuration: configuration)
        return try SignedInvestigationRuntimeReport(
            nonce: configuration.nonce,
            binding: configuration.binding,
            model: .gpt56Luna,
            provider: .openAI,
            capabilityEvidence: evidence,
            production: SignedInvestigationProductionEvidence(
                investigationID: InvestigationID(
                    rawValue:
                        "investigation-"
                        + configuration.nonce.uuidString.lowercased()
                )!,
                runID: InvestigationRunID(
                    rawValue:
                        "investigation-run-"
                        + configuration.nonce.uuidString.lowercased()
                )!,
                reportID: InvestigationReportID(
                    rawValue:
                        "investigation-report-"
                        + configuration.nonce.uuidString.lowercased()
                )!,
                sourceFingerprint:
                    try InvestigationFingerprint(
                        validatingHex:
                            configuration.binding
                            .sourceFingerprintSHA256
                    ),
                planFingerprint:
                    try InvestigationFingerprint(
                        validatingHex:
                            String(repeating: "b", count: 64)
                    ),
                finalEnvelopeAccepted: true,
                terminalBarrierSettled: true,
                artifactsRetired: true,
                localRuntimeDrained: true,
                failureReasonKey: nil
            ),
            denials: denials ?? self.denials(),
            residue: SignedInvestigationRuntimeResidue(
                appProcessCount: 0,
                helperProcessCount: 0,
                workerProcessCount: 0,
                proxyProcessCount: 0,
                leaseCount: 0,
                runtimeArtifactCount: 0
            ),
            startedAt: now,
            completedAt: completedAt ?? now.addingTimeInterval(30)
        )
    }

    func caseEvidence(
        configuration:
            SignedInvestigationRuntimeDiagnosticConfiguration,
        recoveryCompleted: Bool? = nil,
        denials: [SignedInvestigationRuntimeDenialEvidence]? = nil,
        finalResidue: SignedInvestigationRuntimeResidue? = nil,
        planFingerprint: InvestigationFingerprint? = nil,
        targetSetFingerprint: InvestigationFingerprint? = nil,
        upstreamError: SignedInvestigationRuntimeUpstreamError? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        capabilityCompletedAt: Date? = nil
    ) throws -> SignedInvestigationRuntimeMachineCaseEvidence {
        let scenario = configuration.scenario
        let controls = machineControls(for: scenario)
        let plan = try machinePlan(configuration: configuration)
        let nonceText = configuration.nonce.uuidString.lowercased()
        let capabilityEvidenceSHA256: String?
        if scenario == .success {
            capabilityEvidenceSHA256 =
                try capabilityEvidence(
                    configuration: configuration,
                    completedAt: capabilityCompletedAt
                ).machineEvidenceSHA256()
        } else {
            capabilityEvidenceSHA256 = nil
        }
        return try SignedInvestigationRuntimeMachineCaseEvidence(
            scenario: scenario,
            nonce: configuration.nonce,
            configurationSHA256:
                configuration.machineConfigurationSHA256(),
            runtimeArtifactSHA256:
                try runtimeArtifactSHA256(configuration.reportPath),
            evidenceStoreSHA256:
                try runtimeArtifactSHA256(configuration.storePath),
            capabilityEvidenceSHA256: capabilityEvidenceSHA256,
            binding: configuration.binding,
            investigationID: InvestigationID(
                rawValue: "investigation-\(nonceText)"
            )!,
            runID: InvestigationRunID(
                rawValue: "investigation-run-\(nonceText)"
            )!,
            reportID: scenario == .success
                ? InvestigationReportID(
                    rawValue: "investigation-report-\(nonceText)"
                )
                : nil,
            sourceFingerprint: try InvestigationFingerprint(
                validatingHex:
                    configuration.binding.sourceFingerprintSHA256
            ),
            planFingerprint: planFingerprint ?? plan.fingerprint,
            targetSetFingerprint:
                targetSetFingerprint ?? plan.targetSetFingerprint,
            outcome: machineOutcome(for: scenario),
            runStarted: controls.runStarted,
            turnAdmitted: controls.turnAdmitted,
            finalEnvelopeAccepted:
                controls.finalEnvelopeAccepted,
            terminalBarrierSettled:
                controls.terminalBarrierSettled,
            artifactsRetired: controls.artifactsRetired,
            localRuntimeDrained: controls.localRuntimeDrained,
            recoveryAttempted: controls.recoveryAttempted,
            recoveryCompleted:
                recoveryCompleted ?? controls.recoveryCompleted,
            denials: denials
                ?? (scenario == .success ? self.denials() : []),
            finalResidue: finalResidue
                ?? SignedInvestigationRuntimeResidue(
                    appProcessCount: 0,
                    helperProcessCount: 0,
                    workerProcessCount: 0,
                    proxyProcessCount: 0,
                    leaseCount: 0,
                    runtimeArtifactCount: 0
                ),
            observationReasonKey: scenario == .success
                ? nil
                : "runtime.machine.\(scenario.rawValue)",
            upstreamError: upstreamError,
            startedAt: startedAt ?? now,
            completedAt: completedAt ?? now.addingTimeInterval(30)
        )
    }

    func lifecycleResidueRecords(
        artifacts: [SignedInvestigationRuntimeMachineCaseEvidence]
    ) throws
        -> [SignedInvestigationRuntimeLifecycleResidueRecord]
    {
        try artifacts.map {
            try SignedInvestigationRuntimeLifecycleResidueRecord(
                scenario: $0.scenario,
                nonce: $0.nonce,
                binding: $0.binding,
                observedAt: $0.completedAt,
                residue: $0.finalResidue
            )
        }
    }

    private func machineOutcome(
        for scenario: SignedInvestigationRuntimeDiagnosticScenario
    ) -> SignedInvestigationRuntimeMachineCaseOutcome {
        switch scenario {
        case .success:
            .succeeded
        case .cancellation:
            .cancelled
        case .timeout:
            .timedOut
        case .invalidEnvelope:
            .invalidEnvelopeBlocked
        case .identityMismatch:
            .identityMismatchBlocked
        case .transportLoss:
            .transportLossBlocked
        case .lifecycleRecovery:
            .lifecycleRecovered
        case .artifactCleanupFailure:
            .artifactCleanupRecovered
        }
    }

    private func runtimeArtifactSHA256(
        _ path: String,
        nonce: UUID? = nil
    ) throws -> String {
        let data: Data
        if FileManager.default.fileExists(atPath: path) {
            data = try Data(contentsOf: URL(filePath: path))
        } else {
            data = Data(
                "synthetic-runtime-artifact-\((nonce ?? self.nonce).uuidString)"
                    .utf8
            )
        }
        return SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func machineControls(
        for scenario: SignedInvestigationRuntimeDiagnosticScenario
    ) -> (
        runStarted: Bool,
        turnAdmitted: Bool,
        finalEnvelopeAccepted: Bool,
        terminalBarrierSettled: Bool,
        artifactsRetired: Bool,
        localRuntimeDrained: Bool,
        recoveryAttempted: Bool,
        recoveryCompleted: Bool
    ) {
        switch scenario {
        case .success:
            (true, true, true, true, true, true, false, false)
        case .cancellation, .timeout, .invalidEnvelope:
            (true, true, false, true, true, true, false, false)
        case .identityMismatch:
            (false, false, false, false, true, true, false, false)
        case .transportLoss:
            (true, true, false, false, true, true, false, false)
        case .lifecycleRecovery, .artifactCleanupFailure:
            (true, true, false, true, true, true, true, true)
        }
    }

    func verifyReady(
        _ report: SignedInvestigationRuntimeReport,
        configuration:
            SignedInvestigationRuntimeDiagnosticConfiguration,
        admission: SignedInvestigationRuntimeAdmissionReceipt,
        now: Date
    ) throws -> SignedInvestigationRuntimeReport {
        try SignedInvestigationRuntimeReportVerifier().verifyReady(
            report,
            configuration: configuration,
            capabilityMetadata: capabilityMetadata(),
            capabilityWorker: capabilityWorker(
                investigationID: configuration.nonce,
                evidenceBindingSHA256:
                    configuration.capabilityEvidenceBindingSHA256()
            ),
            capabilityLifecycleIntegrity:
                capabilityLifecycleIntegrity(),
            capabilityRepository: capabilityRepositoryEvidence(),
            admission: admission,
            now: now
        )
    }

    func capabilityEvidence(
        configuration:
            SignedInvestigationRuntimeDiagnosticConfiguration,
        missing: CapabilityRuntimeCapability? = nil,
        completedAt: Date? = nil
    ) throws -> SignedInvestigationCapabilityEvidenceReceipt {
        try SignedInvestigationCapabilityEvidenceReceipt(
            configuration: configuration,
            metadata: capabilityMetadata(),
            worker: capabilityWorker(
                investigationID: configuration.nonce,
                evidenceBindingSHA256:
                    configuration.capabilityEvidenceBindingSHA256(),
                missing: missing,
                completedAt: completedAt
            ),
            lifecycleIntegrity: capabilityLifecycleIntegrity(),
            repository: capabilityRepositoryEvidence()
        )
    }

    func capabilityMetadata() throws
        -> CapabilityRuntimeDiagnosticMetadata
    {
        let hash = String(repeating: "a", count: 64)
        return try CapabilityRuntimeDiagnosticMetadata(
            appBundleIdentifier: "com.eriklee.stornaut",
            appExecutableSHA256: hash,
            appDesignatedRequirementSHA256: hash,
            signatureKind: .adHoc,
            codexVersion: "codex-cli 0.147.0",
            codexExecutableSHA256: hash,
            model: .gpt56Luna,
            provider: .openAI,
            publicEndpointHosts: ["example.com"],
            syntheticFixtureSHA256s: [hash],
            sanitizedEventCategories: ["item.command"],
            durationMilliseconds: 1_000
        )
    }

    func capabilityWorker(
        investigationID: UUID,
        evidenceBindingSHA256: String? = nil,
        missing: CapabilityRuntimeCapability? = nil,
        completedAt: Date? = nil
    ) throws -> CapabilityRuntimeWorkerEvidence {
        let hash = String(repeating: "a", count: 64)
        let capabilities = try CapabilityRuntimeCapability.required
            .sorted { $0.rawValue < $1.rawValue }
            .map { capability in
                let observed = capability != missing
                return try CapabilityRuntimeCapabilityEvidence(
                    capability: capability,
                    advertised: true,
                    configured: true,
                    invoked: true,
                    observed: observed,
                    reasonKey: observed
                        ? nil
                        : "runtime.capability."
                            + capability.rawValue
                            + ".not-observed"
                )
            }
        let integrity =
            try CapabilityRuntimeWorkerEvidence
            .allowedIntegrityProperties
            .sorted { $0.rawValue < $1.rawValue }
            .map {
                try CapabilityRuntimeIntegrityEvidence(
                    property: $0,
                    verdict: .contained,
                    reasonKey: nil
                )
            }
        return try CapabilityRuntimeWorkerEvidence(
            investigationID: investigationID,
            evidenceBindingSHA256:
                evidenceBindingSHA256
                ?? String(repeating: "9", count: 64),
            codexVersion: "codex-cli 0.147.0",
            codexExecutableSHA256: hash,
            provider: .openAI,
            publicEndpointHosts: ["example.com"],
            syntheticFixtureSHA256s: [hash],
            sanitizedEventCategories: ["item.command"],
            durationMilliseconds: 1_000,
            completedAt:
                completedAt ?? now.addingTimeInterval(-1),
            capabilities: capabilities,
            integrity: integrity
        )
    }

    func capabilityLifecycleIntegrity() throws
        -> [CapabilityRuntimeIntegrityEvidence]
    {
        try CapabilityRuntimeLifecycleEvidence
            .allowedIntegrityProperties
            .sorted { $0.rawValue < $1.rawValue }
            .map {
                try CapabilityRuntimeIntegrityEvidence(
                    property: $0,
                    verdict: .contained,
                    reasonKey: nil
                )
            }
    }

    func capabilityRepositoryEvidence() throws
        -> CapabilityRuntimeRepositoryEvidence
    {
        try CapabilityRuntimeRepositoryEvidence(
            integrity: [
                CapabilityRuntimeIntegrityEvidence(
                    property: .noExecutorReachability,
                    verdict: .contained,
                    reasonKey: nil
                ),
            ]
        )
    }

    func denials() throws
        -> [SignedInvestigationRuntimeDenialEvidence]
    {
        try SignedInvestigationRuntimeDenialKind.required
            .sorted { $0.rawValue < $1.rawValue }
            .map {
                try SignedInvestigationRuntimeDenialEvidence(
                    kind: $0,
                    attempted: true,
                    contained: true,
                    controlReasonKey:
                        "runtime.control.\($0.rawValue).denied",
                    failureReasonKey: nil
                )
            }
    }
}
