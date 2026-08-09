import Foundation
import Testing
@testable import StornautCodex

@Test(
    .enabled(
        if: ProcessInfo.processInfo.environment[
            "STORNAUT_RUN_INSTALLED_CODEX_DIAGNOSTIC"
        ] == "1",
        "Opt in to probing only `codex --version` and `codex exec --help`"
    )
)
func installedCodexCapabilityDiagnostic() async throws {
    let environment = ProcessInfo.processInfo.environment
    let availability = await CodexLocator().locate(
        configuredURL: nil,
        environment: environment
    )
    let installation = try #require(availability.installation)
    let report = try await CodexCapabilityDetector().report(
        executableURL: installation.executableURL,
        environment: environment
    )

    print("Codex executable: \(report.executableURL.path)")
    print("Codex version: \(report.version)")
    for option in CodexExecOption.allCases {
        print("Option \(option.rawValue): \(String(describing: report.optionSupport[option]))")
        #expect(report.optionSupport[option] == .supported)
    }
    for behavior in CodexBehavior.allCases {
        print(
            "Behavior \(behavior.rawValue): "
                + "\(String(describing: report.behaviorVerdicts[behavior]))"
        )
        #expect(report.behaviorVerdicts[behavior]?.isUnverified == true)
    }
}
