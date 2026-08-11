import Foundation
import Testing
@testable import StornautCodex

@Suite("Capability-first runtime capability report")
struct CodexRuntimeCapabilityTests {
    private let executableURL = URL(
        filePath: "/opt/stornaut-fixtures/codex"
    )
    private let profile = CodexRuntimeProfile.capabilityFirstV1Codex0147

    @Test
    func advertisedEvidenceDoesNotClaimConfigurationOrBehavior() throws {
        let report = try fixtureReport()

        #expect(report.readiness == .configurationBlocked)
        #expect(report.configurationValidation == .unverified)
        #expect(report.entries[.shell]?.advertised == true)
        #expect(report.entries[.shell]?.configured == false)
        #expect(report.entries[.shell]?.observed == false)
        #expect(report.entries[.shell]?.contained == false)
        #expect(report.entries[.shell]?.outcome.isUnverified == true)
        #expect(report.entries[.browserOrDirectFetch]?.advertised == true)
        #expect(
            report.entries[.browserOrDirectFetch]?.outcome.isUnverified
                == true
        )
        #expect(report.entries[.userDataWriteDenial]?.contained == false)
        #expect(report.entries[.userDataWriteDenial]?.advertised == false)
        #expect(
            report.entries[.userDataWriteDenial]?.outcome.isUnverified
                == true
        )
    }

    @Test
    func strictDiagnosticEvidenceMakesOnlyConfigurationReady() throws {
        let report = try fixtureReport(
            evidence: .passingFixture(profileDigest: profile.profileDigest)
        )

        #expect(report.readiness == .configurationReady)
        #expect(report.configurationValidation == .passed)
        #expect(report.requiredMissingCapabilities.isEmpty)
        #expect(
            report.degradedCapabilities == [
                .managedNetworkProxy,
                .publicCommandNetwork,
            ]
        )
        #expect(report.entries[.shell]?.advertised == true)
        #expect(report.entries[.shell]?.configured == true)
        #expect(report.entries[.shell]?.observed == false)
        #expect(report.entries[.managedNetworkProxy]?.configured == true)
        #expect(
            report.entries[.managedNetworkProxy]?.outcome.isDegraded
                == true
        )
        #expect(report.entries[.runtimeSkills]?.configured == true)
        #expect(report.entries[.isolatedHookInventory]?.configured == true)
        #expect(report.entries[.browserOrDirectFetch]?.configured == false)
        #expect(report.entries[.imageInspection]?.configured == false)
        #expect(report.entries[.userDataWriteDenial]?.contained == false)
        #expect(report.entries[.privateNetworkDenial]?.contained == false)
        #expect(report.entries[.unixSocketDenial]?.contained == false)
        #expect(report.entries[.noExecutorReachability]?.contained == false)
    }

    @Test
    func observedModelEvidenceDoesNotBecomeContainment() throws {
        let base = try fixtureReport(
            evidence: .passingFixture(profileDigest: profile.profileDigest)
        )
        let report = base.recordingObservedSuccessfulItemTypes([
            "command_execution",
            "web_search",
            "collab_tool_call",
            "mcp_tool_call",
        ])

        #expect(report.readiness == .configurationReady)
        #expect(report.entries[.shell]?.observed == true)
        #expect(report.entries[.shell]?.contained == false)
        #expect(report.entries[.unifiedExec]?.observed == false)
        #expect(report.entries[.runtimeSkills]?.observed == false)
        #expect(report.entries[.subagents]?.observed == true)
        #expect(report.entries[.subagents]?.contained == false)
        #expect(report.entries[.userDataWriteDenial]?.contained == false)
        #expect(report.entries[.noExecutorReachability]?.contained == false)
    }

    @Test
    func diagnosticProfileDigestMismatchBlocksConfiguration() throws {
        let evidence = CodexRuntimeDiagnosticEvidence.passingFixture(
            profileDigest: String(repeating: "0", count: 64)
        )
        let report = try fixtureReport(evidence: evidence)

        #expect(report.readiness == .configurationBlocked)
        #expect(report.configurationValidation.isFailed)
        #expect(
            report.requiredMissingCapabilities.contains(
                .strictConfiguration
            )
        )
    }

    @Test
    func missingRequiredFeatureBlocksWithoutPromotingBrowser() throws {
        var evidence = CodexRuntimeDiagnosticEvidence.passingFixture(
            profileDigest: profile.profileDigest
        )
        evidence = evidence.replacingFeatureState(
            name: "unified_exec",
            enabled: false
        )
        let report = try fixtureReport(evidence: evidence)

        #expect(report.readiness == .configurationBlocked)
        #expect(report.entries[.unifiedExec]?.outcome.isUnsupported == true)
        #expect(
            report.requiredMissingCapabilities.contains(.unifiedExec)
        )
        #expect(
            report.entries[.browserOrDirectFetch]?.outcome.isUnverified
                == true
        )
    }

    @Test
    func effectiveFeatureOutputMustMatchDiagnosticEvidence() throws {
        let root = try codexFixture(named: "codex-root-help-0.147.0.txt")
        let exec = try codexFixture(named: "codex-exec-help-0.147.0.txt")
        let features = try codexFixture(named: "codex-features-0.147.0.txt")
            .replacingOccurrences(
                of: "unified_exec                         stable             true",
                with: "unified_exec                         stable             false"
            )

        let report = CodexRuntimeCapabilityParser.parse(
            executableURL: executableURL,
            versionOutput: "codex-cli 0.147.0\n",
            rootHelpOutput: root,
            execHelpOutput: exec,
            featureOutput: features,
            profile: profile,
            diagnosticEvidence: .passingFixture(
                profileDigest: profile.profileDigest
            )
        )

        #expect(report.readiness == .configurationBlocked)
        #expect(report.configurationValidation.isFailed)
        #expect(
            report.requiredMissingCapabilities.contains(.unifiedExec)
        )
    }

    @Test
    func featureParserFailsClosedOnDuplicateOrMalformedRows() throws {
        let root = try codexFixture(named: "codex-root-help-0.147.0.txt")
        let exec = try codexFixture(named: "codex-exec-help-0.147.0.txt")
        let features = try codexFixture(named: "codex-features-0.147.0.txt")

        let duplicate = CodexRuntimeCapabilityParser.parse(
            executableURL: executableURL,
            versionOutput: "codex-cli 0.147.0\n",
            rootHelpOutput: root,
            execHelpOutput: exec,
            featureOutput: features
                + "\nshell_tool                          stable             false\n",
            profile: profile
        )
        let malformed = CodexRuntimeCapabilityParser.parse(
            executableURL: executableURL,
            versionOutput: "codex-cli 0.147.0\n",
            rootHelpOutput: root,
            execHelpOutput: exec,
            featureOutput: features
                + "\nmalformed feature row\n",
            profile: profile
        )

        #expect(duplicate.readiness == .configurationBlocked)
        #expect(duplicate.entries[.shell]?.outcome.isUnsupported == true)
        #expect(malformed.readiness == .configurationBlocked)
        #expect(malformed.configurationValidation.isFailed)
    }

    @Test
    func reportContainsNoBrokerOnlyCapability() {
        #expect(
            !CodexRuntimeCapability.allCases.contains {
                $0.rawValue.localizedCaseInsensitiveContains("brokerOnly")
            }
        )
    }

    @Test
    func detectorRunsFixedProbesAndSanitizesEnvironment() async throws {
        let executableURL = try makeRuntimeCapabilityExecutable()
        defer {
            try? FileManager.default.removeItem(
                at: executableURL.deletingLastPathComponent()
            )
        }
        let runner = RecordingRuntimeProcessRunner(
            outputs: try detectorProbeOutputs()
        )
        let diagnosticRunner = RecordingCapabilityDiagnosticRunner(
            evidence: .passingFixture(
                profileDigest: profile.profileDigest
            )
        )
        let detector = CodexRuntimeCapabilityDetector(
            processRunner: runner,
            diagnosticRunner: diagnosticRunner
        )

        let report = try await detector.report(
            executableURL: executableURL,
            environment: [
                "PATH": ":relative:/usr/bin:/usr/bin:/bin",
                "HOME": "/Users/example",
                "LANG": "en_US.UTF-8",
                "OPENAI_API_KEY": "must-not-leak",
                "GITHUB_TOKEN": "must-not-leak",
            ],
            profile: profile
        )

        let requests = await runner.requests
        #expect(requests.count == 4)
        #expect(requests.map(\.arguments) == [
            ["--version"],
            ["--help"],
            ["exec", "--help"],
            profile.featureDiagnosticArguments,
        ])
        #expect(requests.allSatisfy {
            $0.currentDirectoryURL?.path.hasSuffix(
                "/static-probes/work"
            ) == true
        })
        #expect(requests.allSatisfy {
            $0.environment["PATH"] == "/usr/bin:/bin"
        })
        #expect(requests.allSatisfy {
            $0.environment["HOME"]?.hasSuffix("/user-home") == true
        })
        #expect(requests.allSatisfy {
            $0.environment["CODEX_HOME"]?.hasSuffix("/runtime-home") == true
        })
        #expect(requests.allSatisfy {
            $0.environment["OPENAI_API_KEY"] == nil
                && $0.environment["GITHUB_TOKEN"] == nil
        })
        #expect(await diagnosticRunner.requests.count == 1)
        #expect(report.readiness == .configurationReady)
    }

    @Test
    func detectorCachesOnlyAfterRevalidatingAllProbeOutputs() async throws {
        let executableURL = try makeRuntimeCapabilityExecutable()
        defer {
            try? FileManager.default.removeItem(
                at: executableURL.deletingLastPathComponent()
            )
        }
        let probeOutputs = try detectorProbeOutputs()
        let runner = RecordingRuntimeProcessRunner(
            outputs: probeOutputs + probeOutputs
        )
        let diagnosticRunner = RecordingCapabilityDiagnosticRunner(
            evidence: .passingFixture(
                profileDigest: profile.profileDigest
            )
        )
        let detector = CodexRuntimeCapabilityDetector(
            processRunner: runner,
            diagnosticRunner: diagnosticRunner
        )

        let first = try await detector.report(
            executableURL: executableURL,
            environment: [:],
            profile: profile
        )
        let second = try await detector.report(
            executableURL: executableURL,
            environment: [:],
            profile: profile
        )

        #expect(first == second)
        #expect(await runner.requests.count == 8)
        #expect(await diagnosticRunner.requests.count == 2)
    }

    private func fixtureReport(
        evidence: CodexRuntimeDiagnosticEvidence? = nil
    ) throws -> CodexRuntimeCapabilityReport {
        CodexRuntimeCapabilityParser.parse(
            executableURL: executableURL,
            versionOutput: try codexFixture(
                named: "codex-version-0.147.0.txt"
            ),
            rootHelpOutput: try codexFixture(
                named: "codex-root-help-0.147.0.txt"
            ),
            execHelpOutput: try codexFixture(
                named: "codex-exec-help-0.147.0.txt"
            ),
            featureOutput: try codexFixture(
                named: "codex-features-0.147.0.txt"
            ),
            profile: profile,
            diagnosticEvidence: evidence
        )
    }

    private func codexFixture(named name: String) throws -> String {
        let fixtureURL = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Fixtures/Codex/\(name)")
        return try String(contentsOf: fixtureURL, encoding: .utf8)
    }

    private func detectorProbeOutputs() throws -> [ProcessOutput] {
        [
            ProcessOutput(
                exitStatus: 0,
                stdout: Data(
                    try codexFixture(
                        named: "codex-version-0.147.0.txt"
                    ).utf8
                )
            ),
            ProcessOutput(
                exitStatus: 0,
                stdout: Data(
                    try codexFixture(
                        named: "codex-root-help-0.147.0.txt"
                    ).utf8
                )
            ),
            ProcessOutput(
                exitStatus: 0,
                stdout: Data(
                    try codexFixture(
                        named: "codex-exec-help-0.147.0.txt"
                    ).utf8
                )
            ),
            ProcessOutput(
                exitStatus: 0,
                stdout: Data(
                    try codexFixture(
                        named: "codex-features-0.147.0.txt"
                    ).utf8
                )
            ),
        ]
    }
}

private actor RecordingRuntimeProcessRunner: ProcessRunning {
    private(set) var requests: [ProcessRequest] = []
    private var outputs: [ProcessOutput]

    init(outputs: [ProcessOutput]) {
        self.outputs = outputs
    }

    func run(_ request: ProcessRequest) async throws -> ProcessOutput {
        requests.append(request)
        guard !outputs.isEmpty else {
            throw RuntimeCapabilityTestError.missingOutput
        }
        return outputs.removeFirst()
    }
}

private actor RecordingCapabilityDiagnosticRunner:
    CodexRuntimeDiagnosticRunning
{
    private(set) var requests: [CodexRuntimeDiagnosticRequest] = []
    private let evidence: CodexRuntimeDiagnosticEvidence

    init(evidence: CodexRuntimeDiagnosticEvidence) {
        self.evidence = evidence
    }

    func run(
        _ request: CodexRuntimeDiagnosticRequest
    ) async throws -> CodexRuntimeDiagnosticEvidence {
        requests.append(request)
        return evidence
    }
}

private enum RuntimeCapabilityTestError: Error {
    case missingOutput
}

private func makeRuntimeCapabilityExecutable() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "StornautRuntimeCapabilityTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    let executable = root.appending(path: "codex")
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o700],
        ofItemAtPath: executable.path
    )
    return executable
}
