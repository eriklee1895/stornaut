import Foundation
import Testing
@testable import StornautCodex

@Test(
    .enabled(
        if: ProcessInfo.processInfo.environment[
            "STORNAUT_RUN_R5_WORKER_DIAGNOSTIC"
        ] == "1",
        """
        Opt in to the synthetic R5 worker diagnostic using gpt-5.6-luna
        """
    )
)
func realCapabilityRuntimeWorkerDiagnostic() async throws {
    let helperPath = try #require(
        ProcessInfo.processInfo.environment[
            "STORNAUT_R5_NETWORK_PROBE_EXECUTABLE"
        ]
    )
    let baseRoot = URL(
        filePath: "/Library/Caches/Stornaut-R5-WorkerTests",
        directoryHint: .isDirectory
    )
    let root = baseRoot.appending(
        path: String(geteuid()),
        directoryHint: .isDirectory
    )
    if !FileManager.default.fileExists(atPath: root.path) {
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }
    let investigationID = UUID(
        uuidString: "22222222-2222-2222-2222-222222222222"
    )!
    let investigationRoot = root.appending(
        path: investigationID.uuidString.lowercased(),
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: investigationRoot,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    defer {
        try? FileManager.default.removeItem(at: investigationRoot)
        let contents = try? FileManager.default.contentsOfDirectory(
            atPath: root.path
        )
        if contents?.isEmpty == true {
            try? FileManager.default.removeItem(at: root)
        }
        let baseContents = try? FileManager.default.contentsOfDirectory(
            atPath: baseRoot.path
        )
        if baseContents?.isEmpty == true {
            try? FileManager.default.removeItem(at: baseRoot)
        }
    }

    let evidence = try await CapabilityRuntimeWorker
        .runSyntheticDiagnosticForTesting(
            investigationID: investigationID,
            evidenceBindingSHA256: String(repeating: "9", count: 64),
            networkProbeExecutableURL: URL(filePath: helperPath),
            runRootURL: investigationRoot,
            primaryTimeout: diagnosticTimeout()
        )

    for capability in evidence.capabilities {
        print(
            "r5.worker.capability.\(capability.capability.rawValue)="
                + "advertised:\(capability.advertised),"
                + "configured:\(capability.configured),"
                + "invoked:\(capability.invoked),"
                + "observed:\(capability.observed),"
                + "reason:\(capability.reasonKey ?? "none")"
        )
    }
    for integrity in evidence.integrity {
        print(
            "r5.worker.integrity.\(integrity.property.rawValue)="
                + "\(integrity.verdict.rawValue),"
                + "reason:\(integrity.reasonKey ?? "none")"
        )
    }
    print(
        "r5.worker.event_categories="
            + evidence.sanitizedEventCategories.joined(separator: ",")
    )
    print("r5.worker.provider=\(evidence.provider.rawValue)")
    #expect(evidence.capabilities.allSatisfy { $0.observed })
    #expect(evidence.integrity.allSatisfy {
        $0.verdict == .contained
    })
    #expect(evidence.codexVersion == "codex-cli 0.147.0")
    #expect(evidence.provider == .openAI)
}

private func diagnosticTimeout() -> Duration {
    guard
        let raw = ProcessInfo.processInfo.environment[
            "STORNAUT_R5_PRIMARY_TIMEOUT_SECONDS"
        ],
        let seconds = Int64(raw),
        (30...300).contains(seconds)
    else {
        return CapabilityRuntimeWorker.primaryDiagnosticTimeout
    }
    return .seconds(seconds)
}
