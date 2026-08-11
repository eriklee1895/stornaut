import Foundation
import Testing
@testable import StornautCodex

@Test(
    .enabled(
        if: ProcessInfo.processInfo.environment[
            "STORNAUT_RUN_INSTALLED_CODEX_DIAGNOSTIC"
        ] == "1",
        "Opt in to the no-model capability-first configuration diagnostic"
    )
)
func installedCodexCapabilityDiagnostic() async throws {
    let environment = ProcessInfo.processInfo.environment
    let availability = await CodexLocator().locate(
        configuredURL: nil,
        environment: environment
    )
    let installation = try #require(availability.installation)
    let report = try await CodexRuntimeCapabilityDetector().report(
        executableURL: installation.executableURL,
        environment: environment
    )

    print("Codex executable: \(report.executableURL.path)")
    print("Codex version: \(report.version)")
    print("Runtime profile: \(report.profileIdentifier.rawValue)")
    print("Runtime profile digest: \(report.profileDigest)")
    print("Configuration readiness: \(report.readiness.rawValue)")
    for capability in CodexRuntimeCapability.allCases {
        let entry = report.entries[capability]
        print(
            "Capability \(capability.rawValue): "
                + "\(String(describing: entry))"
        )
    }
    #expect(report.readiness == .configurationReady)
    #expect(report.configurationValidation == .passed)
    #expect(report.requiredMissingCapabilities.isEmpty)
    #expect(report.entries[.browserOrDirectFetch]?.observed == false)
    #expect(report.entries[.userDataWriteDenial]?.contained == false)
    #expect(report.entries[.noExecutorReachability]?.contained == false)
}
