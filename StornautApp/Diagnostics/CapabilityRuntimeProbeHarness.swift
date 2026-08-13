#if DEBUG
import AppKit
import Darwin
import Foundation
import StornautCodex
import StornautLifecycle

enum CapabilityRuntimeProbeHarness {
    private static let argumentPrefix =
        "--stornaut-capability-runtime-config="
    private static let cancellationFixtureID = LifecycleInvestigationID(
        rawValue: UUID(
            uuidString: "33333333-3333-3333-3333-333333333333"
        )!
    )
    private static let timeoutFixtureID = LifecycleInvestigationID(
        rawValue: UUID(
            uuidString: "44444444-4444-4444-4444-444444444444"
        )!
    )
    private static let crashFixtureID = LifecycleInvestigationID(
        rawValue: UUID(
            uuidString: "55555555-5555-5555-5555-555555555555"
        )!
    )

    @MainActor
    static func startIfRequested() {
        let matching = CommandLine.arguments.filter {
            $0.hasPrefix(argumentPrefix)
        }
        guard matching.count == 1 else {
            return
        }
        let path = String(
            matching[0].dropFirst(argumentPrefix.count)
        )
        guard path.hasPrefix("/") else {
            return
        }
        let configURL = URL(filePath: path).standardizedFileURL
        Task {
            await Task.yield()
            let response = await run(configURL: configURL)
            write(response, configURL: configURL)
            NSApplication.shared.terminate(nil)
        }
    }

    private static func run(
        configURL: URL
    ) async -> CapabilityRuntimeHarnessResponse {
        guard
            let config = readConfiguration(configURL),
            config.reportPath.hasPrefix("/")
        else {
            return .failed("runtime.harness.invalid-config")
        }
        switch config.action {
        case .fullDiagnostic:
            guard let investigationID = UUID(
                uuidString: config.investigationID
            ) else {
                return .failed(
                    "runtime.harness.invalid-investigation-id"
                )
            }
            return await fullDiagnostic(
                LifecycleInvestigationID(
                    rawValue: investigationID
                )
            )
        case .start:
            guard let investigationID = UUID(
                uuidString: config.investigationID
            ) else {
                return .failed(
                    "runtime.harness.invalid-investigation-id"
                )
            }
            return await send(
                .start(
                    LifecycleInvestigationID(
                        rawValue: investigationID
                    )
                )
            )
        case .cancelFixture:
            guard let investigationID = UUID(
                uuidString: config.investigationID
            ) else {
                return .failed(
                    "runtime.harness.invalid-investigation-id"
                )
            }
            return await cancelFixture(
                LifecycleInvestigationID(
                    rawValue: investigationID
                )
            )
        case .cancel:
            guard let investigationID = UUID(
                uuidString: config.investigationID
            ) else {
                return .failed(
                    "runtime.harness.invalid-investigation-id"
                )
            }
            return await send(
                .cancel(
                    LifecycleInvestigationID(
                        rawValue: investigationID
                    )
                )
            )
        }
    }

    private static func fullDiagnostic(
        _ investigationID: LifecycleInvestigationID
    ) async -> CapabilityRuntimeHarnessResponse {
        let helperURL = Bundle.main.bundleURL.appending(
            path: "Contents/MacOS/StornautLifecycleHelper"
        )
        let cancellation: LifecycleSupervisorXPCResponse
        do {
            cancellation = try await cancellationEvidence(
                helperURL: helperURL
            )
        } catch {
            return .failed(
                fullDiagnosticFailureReasonKey(
                    error,
                    stage: "cancellation"
                )
            )
        }
        do {
            try await waitForHelperExit(helperURL: helperURL)
        } catch {
            return .failed(
                "runtime.harness.full.cancellation.helper-exit"
            )
        }
        let timeout: LifecycleSupervisorXPCResponse
        do {
            timeout = try await timeoutEvidence(
                helperURL: helperURL
            )
        } catch {
            return .failed(
                fullDiagnosticFailureReasonKey(
                    error,
                    stage: "timeout"
                )
            )
        }
        do {
            try await waitForHelperExit(helperURL: helperURL)
        } catch {
            return .failed(
                "runtime.harness.full.timeout.helper-exit"
            )
        }
        let crashRecovery: LifecycleSupervisorXPCResponse
        do {
            crashRecovery = try await crashRecoveryEvidence(
                helperURL: helperURL
            )
        } catch {
            return .failed(
                fullDiagnosticFailureReasonKey(
                    error,
                    stage: "crash-recovery"
                )
            )
        }
        do {
            try await waitForHelperExit(helperURL: helperURL)
        } catch {
            return .failed(
                "runtime.harness.full.crash-recovery.helper-exit"
            )
        }
        guard
            cancellation.drained,
            timeout.drained,
            crashRecovery.drained,
            crashRecovery.staleRecoveryObserved
        else {
            return .failed(
                "runtime.harness.lifecycle-fixture-failed"
            )
        }
        let response: LifecycleSupervisorXPCResponse
        let client = LifecycleSupervisorXPCClient(
            helperBundleURL: helperURL
        )
        do {
            response = try await client.send(.start(investigationID))
            await client.invalidate()
        } catch {
            await client.invalidate()
            return .failed(
                fullDiagnosticFailureReasonKey(
                    error,
                    stage: "worker"
                )
            )
        }
        guard
            response.callerAuthenticated,
            response.freshAuditSession,
            response.drained,
            let workerEvidenceData = response.workerEvidence,
            let worker = try? JSONDecoder().decode(
                CapabilityRuntimeWorkerEvidence.self,
                from: workerEvidenceData
            ),
            let signing = try? LifecycleBundleSigningIdentityReader()
                .evidence(bundleURL: Bundle.main.bundleURL),
            signing.isAdHoc
        else {
            return .failed("runtime.harness.incomplete-evidence")
        }
        do {
            let metadata = try CapabilityRuntimeDiagnosticMetadata(
                appBundleIdentifier:
                    signing.identity.signingIdentifier,
                appExecutableSHA256: signing.executableSHA256,
                appDesignatedRequirementSHA256:
                    signing.identity.designatedRequirementSHA256,
                signatureKind: .adHoc,
                codexVersion: worker.codexVersion,
                codexExecutableSHA256:
                    worker.codexExecutableSHA256,
                model: .gpt56Luna,
                provider: worker.provider,
                publicEndpointHosts: worker.publicEndpointHosts,
                syntheticFixtureSHA256s:
                    worker.syntheticFixtureSHA256s,
                sanitizedEventCategories:
                    worker.sanitizedEventCategories,
                durationMilliseconds: worker.durationMilliseconds
            )
            return .diagnosticEvidence(
                metadata: metadata,
                worker: worker,
                lifecycleIntegrity: [
                    try contained(.signedAppIdentity),
                    try contained(.helperCallerAuthentication),
                    try contained(.perInvestigationAuditSession),
                    try contained(.timeoutCancellationCleanup),
                    try contained(.helperCrashRecovery),
                ]
            )
        } catch {
            return .failed("runtime.harness.full.assembly-failed")
        }
    }

    private static func fullDiagnosticFailureReasonKey(
        _ error: Error,
        stage: String
    ) -> String {
        guard [
            "cancellation",
            "timeout",
            "crash-recovery",
            "worker",
        ].contains(stage) else {
            return "runtime.harness.full.unknown-stage"
        }
        switch error {
        case LifecycleSupervisorXPCError.connectionFailed:
            return "runtime.harness.full.\(stage).connection-failed"
        case LifecycleSupervisorXPCError.invalidResponse:
            return "runtime.harness.full.\(stage).invalid-response"
        case LifecycleSupervisorXPCError.invalidPeer:
            return "runtime.harness.full.\(stage).invalid-peer"
        case let LifecycleSupervisorXPCError.remoteRejected(reasonKey):
            if
                (1...512).contains(reasonKey.utf8.count),
                [
                    "runtime.worker.",
                    "runtime.integrity.",
                    "runtime.cleanup.",
                ].contains(where: reasonKey.hasPrefix),
                reasonKey.unicodeScalars.allSatisfy({
                    (0x30...0x39).contains($0.value)
                        || (0x41...0x5A).contains($0.value)
                        || (0x61...0x7A).contains($0.value)
                        || $0.value == 0x2D
                        || $0.value == 0x2E
                })
            {
                return reasonKey
            }
            return "runtime.harness.full.\(stage).remote-rejected"
        case CapabilityRuntimeHarnessError.crashDidNotInterrupt:
            return "runtime.harness.full.\(stage).crash-not-interrupted"
        case CapabilityRuntimeHarnessError.recoveryUnavailable:
            return "runtime.harness.full.\(stage).recovery-unavailable"
        case CapabilityRuntimeHarnessError.helperExitTimedOut:
            return "runtime.harness.full.\(stage).helper-exit-timeout"
        case CapabilityRuntimeHarnessError.invalidFileState:
            return "runtime.harness.full.\(stage).invalid-file-state"
        default:
            return "runtime.harness.full.\(stage).failed"
        }
    }

    private static func cancellationEvidence(
        helperURL: URL
    ) async throws -> LifecycleSupervisorXPCResponse {
        let client = LifecycleSupervisorXPCClient(
            helperBundleURL: helperURL
        )
        let startTask = Task {
            try await client.send(.start(cancellationFixtureID))
        }
        try await Task.sleep(for: .milliseconds(500))
        let response = try await client.send(
            .cancel(cancellationFixtureID)
        )
        startTask.cancel()
        await client.invalidate()
        return response
    }

    private static func timeoutEvidence(
        helperURL: URL
    ) async throws -> LifecycleSupervisorXPCResponse {
        let client = LifecycleSupervisorXPCClient(
            helperBundleURL: helperURL
        )
        let response = try await client.send(
            .start(timeoutFixtureID)
        )
        await client.invalidate()
        return response
    }

    private static func crashRecoveryEvidence(
        helperURL: URL
    ) async throws -> LifecycleSupervisorXPCResponse {
        let crashingClient = LifecycleSupervisorXPCClient(
            helperBundleURL: helperURL
        )
        do {
            _ = try await crashingClient.send(.start(crashFixtureID))
            throw CapabilityRuntimeHarnessError.crashDidNotInterrupt
        } catch LifecycleSupervisorXPCError.connectionFailed {
        } catch LifecycleSupervisorXPCError.invalidResponse {
        }
        await crashingClient.invalidate()

        for _ in 0..<100 {
            try await Task.sleep(for: .milliseconds(100))
            let recoveryClient = LifecycleSupervisorXPCClient(
                helperBundleURL: helperURL
            )
            do {
                let response = try await recoveryClient.send(
                    .cancel(crashFixtureID)
                )
                await recoveryClient.invalidate()
                return response
            } catch {
                await recoveryClient.invalidate()
            }
        }
        throw CapabilityRuntimeHarnessError.recoveryUnavailable
    }

    private static func waitForHelperExit(
        helperURL: URL
    ) async throws {
        for _ in 0..<100 {
            if !helperProcessIsRunning(helperURL: helperURL) {
                return
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw CapabilityRuntimeHarnessError.helperExitTimedOut
    }

    private static func helperProcessIsRunning(
        helperURL: URL
    ) -> Bool {
        var capacity = 256
        while capacity <= 8_192 {
            var processIDs = [pid_t](repeating: 0, count: capacity)
            let byteCount = processIDs.withUnsafeMutableBytes { buffer in
                proc_listpids(
                    UInt32(PROC_ALL_PIDS),
                    0,
                    buffer.baseAddress,
                    Int32(buffer.count)
                )
            }
            guard byteCount >= 0 else {
                return true
            }
            let count = Int(byteCount) / MemoryLayout<pid_t>.size
            if count == capacity {
                capacity *= 2
                continue
            }
            return processIDs.prefix(count).contains { processID in
                guard processID > 1 else { return false }
                var path = [CChar](
                    repeating: 0,
                    count: 4_096
                )
                let length = proc_pidpath(
                    processID,
                    &path,
                    UInt32(path.count)
                )
                guard length > 0 else { return false }
                let bytes = path.prefix { $0 != 0 }.map {
                    UInt8(bitPattern: $0)
                }
                return URL(
                    filePath: String(decoding: bytes, as: UTF8.self)
                ).standardizedFileURL == helperURL.standardizedFileURL
            }
        }
        return true
    }

    private static func contained(
        _ property: CapabilityRuntimeIntegrityProperty
    ) throws -> CapabilityRuntimeIntegrityEvidence {
        try CapabilityRuntimeIntegrityEvidence(
            property: property,
            verdict: .contained,
            reasonKey: nil
        )
    }

    private static func send(
        _ request: LifecycleSupervisorRequest
    ) async -> CapabilityRuntimeHarnessResponse {
        let helperURL = Bundle.main.bundleURL.appending(
            path: "Contents/MacOS/StornautLifecycleHelper"
        )
        do {
            let response = try await LifecycleSupervisorXPCClient(
                helperBundleURL: helperURL
            ).send(request)
            return .helper(response)
        } catch {
            return .failed("runtime.harness.helper-request-failed")
        }
    }

    private static func cancelFixture(
        _ investigationID: LifecycleInvestigationID
    ) async -> CapabilityRuntimeHarnessResponse {
        let helperURL = Bundle.main.bundleURL.appending(
            path: "Contents/MacOS/StornautLifecycleHelper"
        )
        let client = LifecycleSupervisorXPCClient(
            helperBundleURL: helperURL
        )
        let startTask = Task {
            try await client.send(.start(investigationID))
        }
        try? await Task.sleep(for: .milliseconds(500))
        do {
            let response = try await client.send(
                .cancel(investigationID)
            )
            startTask.cancel()
            await client.invalidate()
            return .helper(response)
        } catch let LifecycleSupervisorXPCError.remoteRejected(
            reasonKey
        ) {
            startTask.cancel()
            await client.invalidate()
            return .failed(
                cancellationFailureReasonKey(reasonKey)
            )
        } catch LifecycleSupervisorXPCError.connectionFailed {
            startTask.cancel()
            await client.invalidate()
            return .failed(
                "runtime.harness.cancel.connection-failed"
            )
        } catch LifecycleSupervisorXPCError.invalidResponse {
            startTask.cancel()
            await client.invalidate()
            return .failed(
                "runtime.harness.cancel.invalid-response"
            )
        } catch LifecycleSupervisorXPCError.invalidPeer {
            startTask.cancel()
            await client.invalidate()
            return .failed(
                "runtime.harness.cancel.invalid-peer"
            )
        } catch {
            startTask.cancel()
            await client.invalidate()
            return .failed("runtime.harness.helper-cancel-failed")
        }
    }

    private static func cancellationFailureReasonKey(
        _ reasonKey: String
    ) -> String {
        switch reasonKey {
        case "runtime.lifecycle.investigation-not-active":
            "runtime.harness.cancel.investigation-not-active"
        case "runtime.lifecycle.another-investigation-active":
            "runtime.harness.cancel.another-investigation-active"
        case "runtime.lifecycle.drain-failed":
            "runtime.harness.cancel.drain-failed"
        case "runtime.lifecycle.drain.unsafe-audit-session":
            "runtime.harness.cancel.drain.unsafe-audit-session"
        case "runtime.lifecycle.drain.identity-mismatch":
            "runtime.harness.cancel.drain.identity-mismatch"
        case "runtime.lifecycle.drain.duplicate-identity":
            "runtime.harness.cancel.drain.duplicate-identity"
        case "runtime.lifecycle.drain.member-limit":
            "runtime.harness.cancel.drain.member-limit"
        case "runtime.lifecycle.drain.freeze-not-converged":
            "runtime.harness.cancel.drain.freeze-not-converged"
        case "runtime.lifecycle.drain.kill-not-converged":
            "runtime.harness.cancel.drain.kill-not-converged"
        case "runtime.lifecycle.drain.privilege-required":
            "runtime.harness.cancel.drain.privilege-required"
        case "runtime.lifecycle.drain.enumeration-failed":
            "runtime.harness.cancel.drain.enumeration-failed"
        case "runtime.lifecycle.drain.audit-session-unavailable":
            "runtime.harness.cancel.drain.audit-session-unavailable"
        case "runtime.lifecycle.drain.audit-session-missing":
            "runtime.harness.cancel.drain.audit-session-missing"
        case "runtime.lifecycle.drain.identity-unavailable":
            "runtime.harness.cancel.drain.identity-unavailable"
        case "runtime.lifecycle.drain.identity-vanished":
            "runtime.harness.cancel.drain.identity-vanished"
        case "runtime.lifecycle.drain.identity-permission-denied":
            "runtime.harness.cancel.drain.identity-permission-denied"
        case "runtime.lifecycle.drain.identity-io-failed":
            "runtime.harness.cancel.drain.identity-io-failed"
        case "runtime.lifecycle.drain.identity-pipe-failed":
            "runtime.harness.cancel.drain.identity-pipe-failed"
        case "runtime.lifecycle.drain.invalid-identity":
            "runtime.harness.cancel.drain.invalid-identity"
        case "runtime.lifecycle.drain.signal-failed":
            "runtime.harness.cancel.drain.signal-failed"
        case "runtime.lifecycle.drain.current-audit-session-unavailable":
            "runtime.harness.cancel.drain.current-audit-session-unavailable"
        case "runtime.lifecycle.drain.process-wait-invalid":
            "runtime.harness.cancel.drain.process-wait-invalid"
        case "runtime.lifecycle.drain.process-wait-timeout":
            "runtime.harness.cancel.drain.process-wait-timeout"
        case "runtime.lifecycle.drain.unknown":
            "runtime.harness.cancel.drain.unknown"
        case "runtime.lifecycle.worker-failed":
            "runtime.harness.cancel.worker-failed"
        default:
            "runtime.harness.cancel.remote-rejected"
        }
    }

    private static func readConfiguration(
        _ url: URL
    ) -> CapabilityRuntimeHarnessConfiguration? {
        let descriptor = open(
            url.path,
            O_RDONLY | O_CLOEXEC | O_NOFOLLOW
        )
        guard
            descriptor >= 0
        else {
            return nil
        }
        defer { close(descriptor) }
        var information = stat()
        guard
            fstat(descriptor, &information) == 0,
            information.st_mode & S_IFMT == S_IFREG,
            information.st_uid == getuid(),
            information.st_mode & 0o777 == 0o600,
            information.st_nlink == 1,
            information.st_size > 0,
            information.st_size <= 4_096,
            let data = try? readConfigurationData(
                descriptor: descriptor,
                maximumBytes: 4_096
            ),
            let config = try? JSONDecoder().decode(
                CapabilityRuntimeHarnessConfiguration.self,
                from: data
            ),
            validReportURL(
                URL(filePath: config.reportPath),
                configURL: url
            )
        else {
            return nil
        }
        return config
    }

    private static func write(
        _ response: CapabilityRuntimeHarnessResponse,
        configURL: URL
    ) {
        guard
            let config = readConfiguration(configURL),
            let data = try? JSONEncoder.pretty.encode(response)
        else {
            return
        }
        try? writeExclusiveReport(
            data,
            to: URL(filePath: config.reportPath),
            configURL: configURL
        )
    }
}

private func validReportURL(
    _ reportURL: URL,
    configURL: URL
) -> Bool {
    guard
        reportURL.isFileURL,
        reportURL.path.hasPrefix("/"),
        reportURL.deletingLastPathComponent().standardizedFileURL
            == configURL.deletingLastPathComponent().standardizedFileURL,
        !FileManager.default.fileExists(atPath: reportURL.path)
    else {
        return false
    }
    var parent = stat()
    let parentURL = reportURL.deletingLastPathComponent()
    return lstat(parentURL.path, &parent) == 0
        && parent.st_mode & S_IFMT == S_IFDIR
        && parent.st_uid == getuid()
        && parent.st_mode & 0o777 == 0o700
}

private func readConfigurationData(
    descriptor: Int32,
    maximumBytes: Int
) throws -> Data {
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1_024)
    while true {
        let count = Darwin.read(descriptor, &buffer, buffer.count)
        if count == 0 {
            return data
        }
        if count < 0 {
            if errno == EINTR {
                continue
            }
            throw CapabilityRuntimeHarnessError.invalidFileState
        }
        guard data.count + count <= maximumBytes else {
            throw CapabilityRuntimeHarnessError.invalidFileState
        }
        data.append(contentsOf: buffer.prefix(count))
    }
}

private func writeExclusiveReport(
    _ data: Data,
    to reportURL: URL,
    configURL: URL
) throws {
    guard validReportURL(reportURL, configURL: configURL) else {
        throw CapabilityRuntimeHarnessError.invalidFileState
    }
    let descriptor = open(
        reportURL.path,
        O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
        0o600
    )
    guard descriptor >= 0 else {
        throw CapabilityRuntimeHarnessError.invalidFileState
    }
    var shouldRemove = true
    defer {
        close(descriptor)
        if shouldRemove {
            unlink(reportURL.path)
        }
    }
    let didWrite = data.withUnsafeBytes { bytes in
        guard let base = bytes.baseAddress else {
            return true
        }
        var offset = 0
        while offset < bytes.count {
            let count = Darwin.write(
                descriptor,
                base.advanced(by: offset),
                bytes.count - offset
            )
            if count < 0 {
                if errno == EINTR {
                    continue
                }
                return false
            }
            offset += count
        }
        return true
    }
    guard didWrite, fsync(descriptor) == 0 else {
        throw CapabilityRuntimeHarnessError.invalidFileState
    }
    shouldRemove = false
}

private enum CapabilityRuntimeHarnessError: Error {
    case crashDidNotInterrupt
    case recoveryUnavailable
    case helperExitTimedOut
    case invalidFileState
}

private struct CapabilityRuntimeHarnessConfiguration: Codable {
    let action: CapabilityRuntimeHarnessAction
    let reportPath: String
    let investigationID: String
}

private enum CapabilityRuntimeHarnessAction: String, Codable {
    case fullDiagnostic
    case start
    case cancel
    case cancelFixture
}

private struct CapabilityRuntimeHarnessResponse: Codable {
    let schemaVersion: Int
    let callerAuthenticated: Bool?
    let freshAuditSession: Bool?
    let workerEvidenceReady: Bool?
    let drained: Bool?
    let staleRecoveryObserved: Bool?
    let workerEvidence: Data?
    let diagnosticMetadata: CapabilityRuntimeDiagnosticMetadata?
    let diagnosticWorkerEvidence: CapabilityRuntimeWorkerEvidence?
    let lifecycleIntegrity:
        [CapabilityRuntimeIntegrityEvidence]?
    let reasonKey: String?

    static func helper(
        _ response: LifecycleSupervisorXPCResponse
    ) -> Self {
        Self(
            schemaVersion: 1,
            callerAuthenticated: response.callerAuthenticated,
            freshAuditSession: response.freshAuditSession,
            workerEvidenceReady: response.workerEvidenceReady,
            drained: response.drained,
            staleRecoveryObserved: response.staleRecoveryObserved,
            workerEvidence: response.workerEvidence,
            diagnosticMetadata: nil,
            diagnosticWorkerEvidence: nil,
            lifecycleIntegrity: nil,
            reasonKey: nil
        )
    }

    static func diagnosticEvidence(
        metadata: CapabilityRuntimeDiagnosticMetadata,
        worker: CapabilityRuntimeWorkerEvidence,
        lifecycleIntegrity: [CapabilityRuntimeIntegrityEvidence]
    ) -> Self {
        Self(
            schemaVersion: 1,
            callerAuthenticated: true,
            freshAuditSession: true,
            workerEvidenceReady: true,
            drained: true,
            staleRecoveryObserved: true,
            workerEvidence: nil,
            diagnosticMetadata: metadata,
            diagnosticWorkerEvidence: worker,
            lifecycleIntegrity: lifecycleIntegrity,
            reasonKey: nil
        )
    }

    static func failed(_ reasonKey: String) -> Self {
        Self(
            schemaVersion: 1,
            callerAuthenticated: nil,
            freshAuditSession: nil,
            workerEvidenceReady: nil,
            drained: nil,
            staleRecoveryObserved: nil,
            workerEvidence: nil,
            diagnosticMetadata: nil,
            diagnosticWorkerEvidence: nil,
            lifecycleIntegrity: nil,
            reasonKey: reasonKey
        )
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
#endif
