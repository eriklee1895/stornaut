import Foundation
import Testing
import StornautCodex
import StornautCore
@testable import StornautInvestigation
@testable import StornautInvestigationDiagnostic

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
            serviceIdentifier: expected.serviceIdentifier
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
    }

    @Test
    func diagnosticCompositionUsesLiveRuntimeClock() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configuration = try fixture.configuration()

        #expect(
            throws:
                InvestigationRuntimeDiagnosticCompositionError
                .compositionUnavailable
        ) {
            _ = try InvestigationRuntimeDiagnosticComposition.prepare(
                configurationData: try configuration.canonicalJSONData(),
                now: fixture.now,
                installation: fixture.installationObservation(),
                runtimeNow: { configuration.validBefore }
            )
        }
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
            configuration.diagnosticRootPath
                == fixture.diagnosticRoot.path
        )
        #expect(
            try configuration.canonicalJSONData()
                == configuration.canonicalJSONData()
        )

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

private struct SignedRuntimeContractFixture {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
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

    init() throws {
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
        _ = FileManager.default.createFile(
            atPath: reportURL.path,
            contents: Data("report".utf8),
            attributes: [.posixPermissions: 0o600]
        )
        _ = FileManager.default.createFile(
            atPath: storeURL.path,
            contents: Data("store".utf8),
            attributes: [.posixPermissions: 0o600]
        )
    }

    func configurationData() throws -> Data {
        try JSONEncoder().encode(configuration())
    }

    func configuration(
        nonce: UUID? = nil,
        sourceRootPath: String? = nil,
        supportRootPath: String? = nil,
        storePath: String? = nil,
        binding: SignedInvestigationRuntimeBinding? = nil
    ) throws -> SignedInvestigationRuntimeDiagnosticConfiguration {
        try SignedInvestigationRuntimeDiagnosticConfiguration(
            nonce: nonce ?? self.nonce,
            optIn:
                SignedInvestigationRuntimeDiagnosticConfiguration
                    .requiredOptIn,
            diagnosticRootPath: diagnosticRoot.path,
            sourceRootPath: sourceRootPath ?? sourceRoot.path,
            supportRootPath: supportRootPath ?? supportRoot.path,
            runtimeRootPath: runtimeRoot.path,
            reportPath: reportURL.path,
            storePath: storePath ?? storeURL.path,
            binding: binding ?? self.binding(),
            expectedModel: .gpt56Luna,
            expectedProvider: .openAI,
            validBefore: now.addingTimeInterval(300),
            maximumWallClockSeconds: 140,
            maximumTurns: 3,
            maximumProbeCalls: 16,
            maximumContextBytes: 1_048_576,
            now: now
        )
    }

    func binding(
        sourceFingerprintSHA256: String? = nil,
        runtimeReceiptSHA256: String? = nil
    ) -> SignedInvestigationRuntimeBinding {
        SignedInvestigationRuntimeBinding(
            repositoryHEAD: String(repeating: "1", count: 40),
            sourceFingerprintSHA256:
                sourceFingerprintSHA256
                ?? String(repeating: "2", count: 64),
            appExecutableSHA256: String(repeating: "a", count: 64),
            helperExecutableSHA256: String(repeating: "4", count: 64),
            runtimeReceiptSHA256:
                runtimeReceiptSHA256
                ?? String(repeating: "5", count: 64),
            promptSHA256: String(repeating: "6", count: 64),
            envelopeSchemaSHA256: String(repeating: "7", count: 64),
            facadeSHA256: String(repeating: "8", count: 64),
            codexExecutableSHA256: String(repeating: "a", count: 64),
            appBundleIdentifier: "com.eriklee.stornaut",
            helperServiceIdentifier:
                "com.eriklee.stornaut.lifecycle"
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
            serviceIdentifier: binding().helperServiceIdentifier
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
                    rawValue: "investigation-task39"
                )!,
                runID: InvestigationRunID(
                    rawValue: "investigation-run-task39"
                )!,
                reportID: InvestigationReportID(
                    rawValue: "investigation-report-task39"
                )!,
                sourceFingerprint:
                    try InvestigationFingerprint(
                        validatingHex:
                            String(repeating: "a", count: 64)
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
        missing: CapabilityRuntimeCapability? = nil
    ) throws -> SignedInvestigationCapabilityEvidenceReceipt {
        try SignedInvestigationCapabilityEvidenceReceipt(
            configuration: configuration,
            metadata: capabilityMetadata(),
            worker: capabilityWorker(
                investigationID: configuration.nonce,
                evidenceBindingSHA256:
                    configuration.capabilityEvidenceBindingSHA256(),
                missing: missing
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
        missing: CapabilityRuntimeCapability? = nil
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
