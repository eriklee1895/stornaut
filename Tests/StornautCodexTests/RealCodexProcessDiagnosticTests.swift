import Darwin
import Foundation
import Testing
@testable import StornautCodex

@Test(
    .enabled(
        if: ProcessInfo.processInfo.environment[
            "STORNAUT_RUN_REAL_CODEX_PROCESS_PROBE"
        ] == "1" && realProbeCodexHomeHasNoGlobalInstructions(),
        "Requires opt-in and a logged-in Codex home without global AGENTS instructions"
    )
)
func realCodexStaticEnvelopeProcessProbe() async throws {
    let environment = ProcessInfo.processInfo.environment
    let availability = await CodexLocator().locate(
        configuredURL: nil,
        environment: environment
    )
    let installation = try #require(availability.installation)
    let root = FileManager.default.temporaryDirectory
        .appending(
            path: "StornautRealCodexProcessProbe-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
    defer { try? FileManager.default.removeItem(at: root) }
    let workspace = root.appending(path: "workspace", directoryHint: .isDirectory)
    let codexHome = realProbeCodexHomeURL()
    let schemaURL = root.appending(path: "investigation-envelope.schema.json")
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    let stateBefore = try realProbeStateSnapshot(codexHome: codexHome)

    let schemaSourceURL = try #require(
        Bundle.module.url(
            forResource: "investigation-envelope.schema",
            withExtension: "json",
            subdirectory: "Schemas"
        )
    )
    try FileManager.default.copyItem(at: schemaSourceURL, to: schemaURL)

    let prompt = """
    Return exactly this JSON object as the final response:
    {"summary":"Static protocol probe","findings":[],"unresolvedTargetIDs":[]}
    Do not inspect files, run tools, or add any other text.
    """
    let request = CodexRunRequest(
        executableURL: installation.executableURL,
        isolatedWorkingDirectoryURL: workspace,
        schemaURL: schemaURL,
        prompt: Data(prompt.utf8),
        timeout: .seconds(90),
        terminationGracePeriod: .milliseconds(500),
        stdoutByteLimit: 256 * 1_024,
        stderrByteLimit: 64 * 1_024,
        jsonLineByteLimit: 128 * 1_024,
        unknownMetadataByteLimit: 1_024,
        environment: [
            "CODEX_HOME": codexHome.path,
            "HOME": environment["HOME"] ?? NSHomeDirectory(),
            "LANG": environment["LANG"] ?? "en_US.UTF-8",
            "LC_ALL": environment["LC_ALL"] ?? "",
            "LC_CTYPE": environment["LC_CTYPE"] ?? "",
            "PATH": environment["PATH"] ?? "/usr/bin:/bin",
            "TERM": environment["TERM"] ?? "dumb",
            "TMPDIR": root.path,
        ]
    )

    let events = try await collectRealProbeEvents(
        from: CodexProcess().run(request)
    )
    let envelope = try #require(events.compactMap(\.completedEnvelope).last)

    #expect(envelope == InvestigationEnvelope(
        summary: "Static protocol probe",
        findings: [],
        unresolvedTargetIDs: []
    ))
    #expect(!events.contains { $0.exposesRawAgentText })

    let workspaceContents = try FileManager.default.contentsOfDirectory(
        atPath: workspace.path
    )
    let stateAfter = try realProbeStateSnapshot(codexHome: codexHome)
    print("Real probe typed event categories: \(events.map(\.category))")
    print("Real probe workspace residue count: \(workspaceContents.count)")
    print("Real probe new session-state paths: \(stateAfter.subtracting(stateBefore).count)")
    #expect(stateBefore == stateAfter)
}

private extension CodexProcessEvent {
    var completedEnvelope: InvestigationEnvelope? {
        guard case let .completed(envelope) = self else {
            return nil
        }
        return envelope
    }

    var exposesRawAgentText: Bool {
        guard case let .protocolEvent(.itemCompleted(item)) = self else {
            return false
        }
        return item.agentMessageText != nil
    }

    var category: String {
        switch self {
        case .started:
            "started"
        case let .protocolEvent(event):
            switch event {
            case .threadStarted:
                "protocol.thread.started"
            case .turnStarted:
                "protocol.turn.started"
            case .turnCompleted:
                "protocol.turn.completed"
            case .turnFailed:
                "protocol.turn.failed"
            case .itemStarted:
                "protocol.item.started"
            case .itemCompleted:
                "protocol.item.completed"
            case .error:
                "protocol.error"
            case .unknown:
                "protocol.unknown"
            }
        case .unknown:
            "unknown"
        case .stderr:
            "stderr"
        case .lifecycle(.processGroupCreated):
            "lifecycle.process-group-created"
        case .lifecycle(.interruptSent):
            "lifecycle.interrupt-sent"
        case .lifecycle(.terminateSent):
            "lifecycle.terminate-sent"
        case .lifecycle(.killSent):
            "lifecycle.kill-sent"
        case .completed:
            "completed"
        }
    }
}

private func collectRealProbeEvents(
    from stream: AsyncThrowingStream<CodexProcessEvent, Error>
) async throws -> [CodexProcessEvent] {
    var events: [CodexProcessEvent] = []
    for try await event in stream {
        events.append(event)
    }
    return events
}

private func realProbeCodexHomeURL() -> URL {
    let environment = ProcessInfo.processInfo.environment
    let path = environment["CODEX_HOME"]
        ?? URL(filePath: environment["HOME"] ?? NSHomeDirectory())
            .appending(path: ".codex", directoryHint: .isDirectory)
            .path
    return URL(filePath: path, directoryHint: .isDirectory)
        .standardizedFileURL
}

private func realProbeCodexHomeHasNoGlobalInstructions() -> Bool {
    let codexHome = realProbeCodexHomeURL()
    for name in ["AGENTS.override.md", "AGENTS.md"] {
        let url = codexHome.appending(path: name)
        var information = stat()
        let result = url.withUnsafeFileSystemRepresentation { path in
            guard let path else {
                return Int32(EINVAL)
            }
            return lstat(path, &information)
        }
        if result != 0 {
            if errno == ENOENT {
                continue
            }
            return false
        }
        guard
            information.st_mode & S_IFMT == S_IFREG,
            information.st_size == 0
        else {
            return false
        }
    }
    return true
}

private func realProbeStateSnapshot(
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
        let urls: [URL]
        if (try? root.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [
                    .isRegularFileKey,
                    .fileSizeKey,
                    .contentModificationDateKey,
                ],
                options: [.skipsHiddenFiles]
            )
            urls = (enumerator?.allObjects as? [URL]) ?? []
        } else {
            urls = [root]
        }

        for url in urls.sorted(by: { $0.path < $1.path }) {
            let values = try url.resourceValues(
                forKeys: [
                    .isRegularFileKey,
                ]
            )
            guard values.isRegularFile == true else {
                continue
            }
            result.insert(
                String(url.path.dropFirst(codexHome.path.count))
            )
        }
    }
    return result
}
