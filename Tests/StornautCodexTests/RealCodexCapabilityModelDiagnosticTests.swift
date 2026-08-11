import Foundation
import Testing
@testable import StornautCodex

@Test(
    .enabled(
        if: ProcessInfo.processInfo.environment[
            "STORNAUT_RUN_REAL_CODEX_CAPABILITY_MODEL_DIAGNOSTIC"
        ] == "1" && realCapabilityProbeCodexHomeHasNoGlobalInstructions(),
        """
        Opt in to a synthetic real-model capability probe using \
        gpt-5.6-luna; it records observed evidence only
        """
    )
)
func realCodexCapabilityModelDiagnostic() async throws {
    let environment = ProcessInfo.processInfo.environment
    let availability = await CodexLocator().locate(
        configuredURL: nil,
        environment: environment
    )
    let installation = try #require(availability.installation)
    let root = FileManager.default.temporaryDirectory.appending(
        path: "StornautRealCapabilityModelProbe-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: root) }
    let workspace = root.appending(
        path: "workspace",
        directoryHint: .isDirectory
    )
    let schemaURL = root.appending(path: "investigation-envelope.schema.json")
    let markerURL = workspace.appending(path: "read-marker.txt")
    let codexHome = realCapabilityProbeCodexHomeURL()
    try FileManager.default.createDirectory(
        at: workspace,
        withIntermediateDirectories: true
    )
    try Data("STORNAUT_SYNTHETIC_READ_MARKER\n".utf8).write(
        to: markerURL,
        options: .atomic
    )
    let schemaSourceURL = try #require(
        Bundle.module.url(
            forResource: "investigation-envelope.schema",
            withExtension: "json",
            subdirectory: "Schemas"
        )
    )
    try FileManager.default.copyItem(at: schemaSourceURL, to: schemaURL)
    let stateBefore = try capabilityProbeStateSnapshot(codexHome: codexHome)

    let prompt = """
    This is a synthetic Stornaut R2 capability observation.
    1. Use shell or unified exec to read ./read-marker.txt.
    2. Use live web search for the public title of https://example.com/.
    3. Return only JSON matching the supplied schema with:
       summary = "STORNAUT_SYNTHETIC_READ_MARKER | Example Domain",
       findings = [],
       unresolvedTargetIDs = [].
    Do not modify any file, invoke subagents, access localhost/private network,
    use Unix sockets, or inspect anything outside this synthetic workspace.
    """
    let request = CodexRunRequest(
        executableURL: installation.executableURL,
        isolatedWorkingDirectoryURL: workspace,
        schemaURL: schemaURL,
        prompt: Data(prompt.utf8),
        timeout: .seconds(120),
        terminationGracePeriod: .milliseconds(500),
        stdoutByteLimit: 512 * 1_024,
        stderrByteLimit: 64 * 1_024,
        jsonLineByteLimit: 256 * 1_024,
        unknownMetadataByteLimit: 2 * 1_024,
        environment: [
            "CODEX_HOME": codexHome.path,
            "HOME": environment["HOME"] ?? NSHomeDirectory(),
            "LANG": environment["LANG"] ?? "en_US.UTF-8",
            "LC_ALL": environment["LC_ALL"] ?? "",
            "LC_CTYPE": environment["LC_CTYPE"] ?? "",
            "PATH": environment["PATH"] ?? "/usr/bin:/bin",
            "TERM": environment["TERM"] ?? "dumb",
            "TMPDIR": root.path,
        ],
        model: .gpt56Luna
    )

    let events = try await collectCapabilityProbeEvents(
        from: CodexProcess().run(request)
    )
    let envelope = try #require(events.compactMap(\.capabilityEnvelope).last)
    let observedItemTypes = Set(events.compactMap(\.successfulItemType))

    #expect(envelope.summary.contains("STORNAUT_SYNTHETIC_READ_MARKER"))
    #expect(
        envelope.summary.localizedCaseInsensitiveContains("example domain")
    )
    #expect(observedItemTypes.contains("command_execution"))
    #expect(observedItemTypes.contains("web_search"))

    let configuration = try await CodexRuntimeCapabilityDetector()
        .report(
            executableURL: installation.executableURL,
            environment: environment
        )
    let report = configuration.recordingObservedSuccessfulItemTypes(
        observedItemTypes
    )
    let stateAfter = try capabilityProbeStateSnapshot(codexHome: codexHome)
    let observed = CodexRuntimeCapability.allCases.filter {
        report.entries[$0]?.observed == true
    }
    print("Observed capabilities: \(observed.map(\.rawValue).sorted())")
    #expect(report.entries[.shell]?.observed == true)
    #expect(report.entries[.unifiedExec]?.observed == false)
    #expect(report.entries[.liveSearch]?.observed == true)
    print("Readiness remains: \(report.readiness.rawValue)")
    print("Contained flags remain false")
    #expect(report.readiness == .configurationReady)
    #expect(report.entries[.userDataWriteDenial]?.contained == false)
    #expect(report.entries[.privateNetworkDenial]?.contained == false)
    #expect(report.entries[.unixSocketDenial]?.contained == false)
    #expect(report.entries[.noExecutorReachability]?.contained == false)
    #expect(stateBefore == stateAfter)
}

private extension CodexProcessEvent {
    var capabilityEnvelope: InvestigationEnvelope? {
        guard case let .completed(envelope) = self else {
            return nil
        }
        return envelope
    }

    var successfulItemType: String? {
        guard
            case let .protocolEvent(.itemCompleted(item)) = self,
            item.succeeded == true
        else {
            return nil
        }
        return item.type
    }
}

private func collectCapabilityProbeEvents(
    from stream: AsyncThrowingStream<CodexProcessEvent, Error>
) async throws -> [CodexProcessEvent] {
    var events: [CodexProcessEvent] = []
    for try await event in stream {
        events.append(event)
    }
    return events
}

private func realCapabilityProbeCodexHomeURL() -> URL {
    if
        let configured = ProcessInfo.processInfo.environment[
            "STORNAUT_REAL_CODEX_HOME"
        ],
        !configured.isEmpty
    {
        return URL(filePath: configured, directoryHint: .isDirectory)
    }
    return FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".codex", directoryHint: .isDirectory)
}

private func realCapabilityProbeCodexHomeHasNoGlobalInstructions() -> Bool {
    let home = realCapabilityProbeCodexHomeURL()
    for name in ["AGENTS.override.md", "AGENTS.md"] {
        let url = home.appending(path: name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            continue
        }
        guard
            let attributes = try? FileManager.default.attributesOfItem(
                atPath: url.path
            ),
            let size = attributes[.size] as? NSNumber,
            size.intValue == 0
        else {
            return false
        }
    }
    return true
}

private func capabilityProbeStateSnapshot(
    codexHome: URL
) throws -> Set<String> {
    let fileManager = FileManager.default
    let relativePaths = [
        "history.jsonl",
        "session_index.jsonl",
        "sessions",
        "archived_sessions",
    ]
    var result = Set<String>()
    for relativePath in relativePaths {
        let root = codexHome.appending(path: relativePath)
        guard fileManager.fileExists(atPath: root.path) else {
            continue
        }
        let values = try root.resourceValues(forKeys: [.isDirectoryKey])
        let urls: [URL]
        if values.isDirectory == true {
            let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            urls = (enumerator?.allObjects as? [URL]) ?? []
        } else {
            urls = [root]
        }
        for url in urls.sorted(by: { $0.path < $1.path }) {
            let itemValues = try url.resourceValues(
                forKeys: [.isRegularFileKey]
            )
            guard itemValues.isRegularFile == true else {
                continue
            }
            result.insert(
                String(url.path.dropFirst(codexHome.path.count))
            )
        }
    }
    return result
}
