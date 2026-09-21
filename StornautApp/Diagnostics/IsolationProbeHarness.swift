#if DEBUG
import AppKit
import Darwin
import Foundation
import StornautCodex

enum IsolationProbeHarness {
    private static let argumentPrefix = "--stornaut-isolation-probe-config="

    @MainActor
    static func startIfRequested() {
        guard let argument = CommandLine.arguments.first(where: {
            $0.hasPrefix(argumentPrefix)
        }) else {
            return
        }
        let path = String(argument.dropFirst(argumentPrefix.count))
        let configURL = URL(filePath: path).standardizedFileURL

        Task {
            await Task.yield()
            let report = await run(configURL: configURL)
            write(report, configURL: configURL)
            NSApplication.shared.terminate(nil)
        }
    }

    private static func run(configURL: URL) async -> IsolationProbeReport {
        do {
            let data = try Data(contentsOf: configURL)
            let config = try JSONDecoder().decode(
                IsolationProbeConfiguration.self,
                from: data
            )
            let appReads = config.canaries.map { canary in
                IsolationReadResult(
                    id: canary.id,
                    outcome: readToken(
                        at: URL(filePath: canary.path),
                        expectedToken: canary.expectedToken
                    )
                )
            }
            let tccRead = config.tccCanary.map { canary in
                IsolationReadResult(
                    id: canary.id,
                    outcome: readToken(
                        at: URL(filePath: canary.path),
                        expectedToken: canary.expectedToken
                    )
                )
            }
            let protectedDirectoryAccess = config.protectedDirectoryPath.map {
                probeDirectoryAccess(at: URL(filePath: $0))
            }

            let request = CodexRunRequest(
                executableURL: URL(filePath: config.codexExecutablePath),
                isolatedWorkingDirectoryURL: URL(
                    filePath: config.workspacePath,
                    directoryHint: .isDirectory
                ),
                schemaURL: URL(filePath: config.schemaPath),
                prompt: Data(config.prompt.utf8),
                timeout: .seconds(90),
                terminationGracePeriod: .milliseconds(500),
                stdoutByteLimit: 256 * 1_024,
                stderrByteLimit: 64 * 1_024,
                jsonLineByteLimit: 128 * 1_024,
                unknownMetadataByteLimit: 1_024,
                environment: config.environment
            )

            var categories: [String] = []
            var envelope: InvestigationEnvelope?
            do {
                for try await event in CodexProcess().run(request) {
                    categories.append(event.isolationCategory)
                    if case let .completed(value) = event {
                        envelope = value
                    }
                }
                return IsolationProbeReport(
                    bundleIdentifier: Bundle.main.bundleIdentifier,
                    appReads: appReads,
                    tccRead: tccRead,
                    protectedDirectoryAccess: protectedDirectoryAccess,
                    codexEventCategories: categories,
                    codexEnvelope: envelope,
                    codexError: nil
                )
            } catch {
                return IsolationProbeReport(
                    bundleIdentifier: Bundle.main.bundleIdentifier,
                    appReads: appReads,
                    tccRead: tccRead,
                    protectedDirectoryAccess: protectedDirectoryAccess,
                    codexEventCategories: categories,
                    codexEnvelope: nil,
                    codexError: String(reflecting: type(of: error))
                )
            }
        } catch {
            return IsolationProbeReport(
                bundleIdentifier: Bundle.main.bundleIdentifier,
                appReads: [],
                tccRead: nil,
                protectedDirectoryAccess: nil,
                codexEventCategories: [],
                codexEnvelope: nil,
                codexError: "HarnessConfigurationError"
            )
        }
    }

    private static func write(
        _ report: IsolationProbeReport,
        configURL: URL
    ) {
        guard let data = try? JSONEncoder.pretty.encode(report),
              let configData = try? Data(contentsOf: configURL),
              let config = try? JSONDecoder().decode(
                  IsolationProbeConfiguration.self,
                  from: configData
              )
        else {
            return
        }
        try? data.write(
            to: URL(filePath: config.reportPath),
            options: .atomic
        )
    }

    private static func readToken(
        at url: URL,
        expectedToken: String
    ) -> IsolationReadOutcome {
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard data.count <= 4_096 else {
                return .unexpectedContent
            }
            return String(decoding: data, as: UTF8.self) == expectedToken
                ? .matched
                : .unexpectedContent
        } catch {
            return .deniedOrUnavailable
        }
    }

    private static func probeDirectoryAccess(
        at url: URL
    ) -> IsolationProtectedDirectoryAccess {
        let descriptor = open(url.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard descriptor >= 0 else {
            return .deniedOrUnavailable
        }
        close(descriptor)
        return .openedWithoutEnumeration
    }
}

private struct IsolationProbeConfiguration: Codable {
    let reportPath: String
    let codexExecutablePath: String
    let workspacePath: String
    let schemaPath: String
    let prompt: String
    let environment: [String: String]
    let canaries: [IsolationCanary]
    let tccCanary: IsolationCanary?
    let protectedDirectoryPath: String?
}

private struct IsolationCanary: Codable {
    let id: String
    let path: String
    let expectedToken: String
}

private struct IsolationProbeReport: Codable {
    let bundleIdentifier: String?
    let appReads: [IsolationReadResult]
    let tccRead: IsolationReadResult?
    let protectedDirectoryAccess: IsolationProtectedDirectoryAccess?
    let codexEventCategories: [String]
    let codexEnvelope: InvestigationEnvelope?
    let codexError: String?
}

private struct IsolationReadResult: Codable {
    let id: String
    let outcome: IsolationReadOutcome
}

private enum IsolationReadOutcome: String, Codable {
    case matched
    case deniedOrUnavailable
    case unexpectedContent
}

private enum IsolationProtectedDirectoryAccess: String, Codable {
    case openedWithoutEnumeration
    case deniedOrUnavailable
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension CodexProcessEvent {
    var isolationCategory: String {
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
            case let .itemStarted(item):
                "protocol.item.started.\(item.type)"
            case let .itemCompleted(item):
                "protocol.item.completed.\(item.type)"
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
#endif
