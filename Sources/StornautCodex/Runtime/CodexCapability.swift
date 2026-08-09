import Foundation

public enum CodexEvidenceVerdict: Sendable, Equatable {
    case supported
    case unsupported(reason: String)
    case unverified(reason: String)

    public var isUnsupported: Bool {
        guard case .unsupported = self else {
            return false
        }
        return true
    }

    public var isUnverified: Bool {
        guard case .unverified = self else {
            return false
        }
        return true
    }
}

public enum CodexExecOption: String, CaseIterable, Sendable {
    case structuredJSONL
    case outputSchema
    case ephemeral
    case readOnlySandbox
    case strictConfig
    case ignoreUserConfig
    case ignoreRules
    case skipGitRepositoryCheck
}

public enum CodexBehavior: String, CaseIterable, Sendable {
    case structuredJSONL
    case outputSchemaCompliance
    case ephemeralSession
    case readOnlySandboxEnforcement
    case strictConfiguration
    case ignoredUserConfiguration
    case ruleAndInstructionIsolation
    case localProbeTransport
    case brokerOnlyToolSurface
}

public struct CodexCapabilityReport: Sendable, Equatable {
    public let executableURL: URL
    public let version: String
    public let optionSupport: [CodexExecOption: CodexEvidenceVerdict]
    public let behaviorVerdicts: [CodexBehavior: CodexEvidenceVerdict]

    public init(
        executableURL: URL,
        version: String,
        optionSupport: [CodexExecOption: CodexEvidenceVerdict],
        behaviorVerdicts: [CodexBehavior: CodexEvidenceVerdict]
    ) {
        self.executableURL = executableURL
        self.version = version
        self.optionSupport = optionSupport
        self.behaviorVerdicts = behaviorVerdicts
    }
}

public enum CodexCapabilityParser {
    public static func parse(
        executableURL: URL,
        versionOutput: String,
        execHelpOutput: String
    ) -> CodexCapabilityReport {
        let version = versionOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let helpIsWellFormed = execHelpOutput.contains("Run Codex non-interactively")
            && execHelpOutput.contains("Usage: codex exec")
            && execHelpOutput.contains("Options:")
        let versionIsWellFormed = version.hasPrefix("codex-cli ")
            && version.split(whereSeparator: \.isWhitespace).count == 2
        let optionDeclarationsAreUnique = expectedOptionNames.allSatisfy {
            optionBlockCount($0, in: execHelpOutput) <= 1
        }

        guard
            helpIsWellFormed,
            versionIsWellFormed,
            optionDeclarationsAreUnique
        else {
            let reason = "Codex version or exec help output is malformed or contradictory"
            return CodexCapabilityReport(
                executableURL: executableURL,
                version: version,
                optionSupport: unsupportedOptions(reason: reason),
                behaviorVerdicts: unsupportedBehaviors(reason: reason)
            )
        }

        var options: [CodexExecOption: CodexEvidenceVerdict] = [:]
        options[.structuredJSONL] = verdict(
            hasOption("--json", in: execHelpOutput),
            missing: "--json is not advertised by codex exec --help"
        )
        options[.outputSchema] = verdict(
            hasOption("--output-schema", in: execHelpOutput),
            missing: "--output-schema is not advertised by codex exec --help"
        )
        options[.ephemeral] = verdict(
            hasOption("--ephemeral", in: execHelpOutput),
            missing: "--ephemeral is not advertised by codex exec --help"
        )
        let sandboxBlock = optionBlock("--sandbox", in: execHelpOutput)
        options[.readOnlySandbox] = verdict(
            sandboxBlock?
                .components(separatedBy: .newlines)
                .contains(where: { line in
                    let normalized = line.trimmingCharacters(in: .whitespaces)
                    return normalized.hasPrefix("[possible values:")
                        && normalized
                            .dropFirst("[possible values:".count)
                            .dropLast(normalized.hasSuffix("]") ? 1 : 0)
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .contains("read-only")
                }) == true,
            missing: "--sandbox does not advertise the read-only selector"
        )
        options[.strictConfig] = verdict(
            hasOption("--strict-config", in: execHelpOutput),
            missing: "--strict-config is not advertised by codex exec --help"
        )
        options[.ignoreUserConfig] = verdict(
            hasOption("--ignore-user-config", in: execHelpOutput),
            missing: "--ignore-user-config is not advertised by codex exec --help"
        )
        options[.ignoreRules] = verdict(
            hasOption("--ignore-rules", in: execHelpOutput),
            missing: "--ignore-rules is not advertised by codex exec --help"
        )
        options[.skipGitRepositoryCheck] = verdict(
            hasOption("--skip-git-repo-check", in: execHelpOutput),
            missing: "--skip-git-repo-check is not advertised by codex exec --help"
        )

        return CodexCapabilityReport(
            executableURL: executableURL,
            version: version,
            optionSupport: options,
            behaviorVerdicts: behaviorVerdicts(optionSupport: options)
        )
    }

    private static func hasOption(_ option: String, in help: String) -> Bool {
        optionBlock(option, in: help) != nil
    }

    private static let expectedOptionNames = [
        "--json",
        "--output-schema",
        "--ephemeral",
        "--sandbox",
        "--strict-config",
        "--ignore-user-config",
        "--ignore-rules",
        "--skip-git-repo-check",
    ]

    private static func optionBlock(_ option: String, in help: String) -> String? {
        let lines = help.components(separatedBy: .newlines)
        guard let optionIndex = lines.firstIndex(where: {
            isOptionHeader($0) && optionTokens(in: $0).contains(option)
        }) else {
            return nil
        }

        var block = lines[optionIndex]
        for line in lines.dropFirst(optionIndex + 1) {
            if isOptionHeader(line) {
                break
            }
            block.append("\n")
            block.append(line)
        }
        return block
    }

    private static func optionBlockCount(_ option: String, in help: String) -> Int {
        help.components(separatedBy: .newlines).count {
            isOptionHeader($0) && optionTokens(in: $0).contains(option)
        }
    }

    private static func optionTokens(in line: String) -> [String] {
        line
            .trimmingCharacters(in: .whitespaces)
            .split(whereSeparator: \.isWhitespace)
            .map {
                String($0).trimmingCharacters(
                    in: CharacterSet(charactersIn: ",")
                )
            }
    }

    private static func isOptionHeader(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("--") || trimmed.hasPrefix("-")
    }

    private static func verdict(_ supported: Bool, missing reason: String) -> CodexEvidenceVerdict {
        supported ? .supported : .unsupported(reason: reason)
    }

    private static func unsupportedOptions(
        reason: String
    ) -> [CodexExecOption: CodexEvidenceVerdict] {
        Dictionary(uniqueKeysWithValues: CodexExecOption.allCases.map {
            ($0, .unsupported(reason: reason))
        })
    }

    private static func unsupportedBehaviors(
        reason: String
    ) -> [CodexBehavior: CodexEvidenceVerdict] {
        Dictionary(uniqueKeysWithValues: CodexBehavior.allCases.map {
            ($0, .unsupported(reason: reason))
        })
    }

    private static func behaviorVerdicts(
        optionSupport: [CodexExecOption: CodexEvidenceVerdict]
    ) -> [CodexBehavior: CodexEvidenceVerdict] {
        Dictionary(uniqueKeysWithValues: CodexBehavior.allCases.map { behavior in
            guard let requiredOptions = requiredOptions(for: behavior) else {
                return (
                    behavior,
                    .unverified(reason: unverifiedReason(for: behavior))
                )
            }

            let missingOptions = requiredOptions.filter {
                optionSupport[$0] != .supported
            }
            guard missingOptions.isEmpty else {
                let names = missingOptions.map(\.rawValue).joined(separator: ", ")
                return (
                    behavior,
                    .unsupported(reason: "Required CLI option is unavailable: \(names)")
                )
            }

            return (
                behavior,
                .unverified(reason: unverifiedReason(for: behavior))
            )
        })
    }

    private static func requiredOptions(
        for behavior: CodexBehavior
    ) -> [CodexExecOption]? {
        switch behavior {
        case .structuredJSONL:
            [.structuredJSONL]
        case .outputSchemaCompliance:
            [.outputSchema]
        case .ephemeralSession:
            [.ephemeral]
        case .readOnlySandboxEnforcement:
            [.readOnlySandbox]
        case .strictConfiguration:
            [.strictConfig]
        case .ignoredUserConfiguration:
            [.ignoreUserConfig]
        case .ruleAndInstructionIsolation:
            [.ignoreUserConfig, .ignoreRules]
        case .localProbeTransport, .brokerOnlyToolSurface:
            nil
        }
    }

    private static func unverifiedReason(for behavior: CodexBehavior) -> String {
        switch behavior {
        case .structuredJSONL:
            "Flag presence does not prove JSONL event behavior; Task 4 must verify it"
        case .outputSchemaCompliance:
            "Flag presence does not prove provider or model schema compliance"
        case .ephemeralSession:
            "Flag presence does not prove the absence of session residue"
        case .readOnlySandboxEnforcement:
            "Selector presence does not prove effective write denial or read isolation"
        case .strictConfiguration:
            "Task 4 must validate all isolation keys on an actual strict exec startup"
        case .ignoredUserConfiguration:
            "The flag omits one config layer but does not prove complete instruction isolation"
        case .ruleAndInstructionIsolation:
            "Rules, global instructions, project docs, Skills, Plugins and Hooks are separate sources"
        case .localProbeTransport:
            "Task 5 must prove a bounded local Probe Broker transport"
        case .brokerOnlyToolSurface:
            "Task 5 must prove Shell, direct filesystem and unrelated tools are unavailable"
        }
    }
}

public enum CodexCapabilityProbeError: Error, Sendable, Equatable {
    case invalidExecutable(URL)
    case executableChangedDuringProbe(URL)
    case nonzeroExit(arguments: [String], status: Int32)
    case outputTruncated(arguments: [String])
    case invalidUTF8(arguments: [String])
}

public actor CodexCapabilityDetector {
    public static let outputLimit = 64 * 1_024
    public static let probeTimeout: Duration = .seconds(5)

    private let processRunner: any ProcessRunning
    private var cached: CacheEntry?

    public init(processRunner: any ProcessRunning = FoundationProcessRunner()) {
        self.processRunner = processRunner
    }

    public func report(
        executableURL: URL,
        environment: [String: String]
    ) async throws -> CodexCapabilityReport {
        let canonicalURL = executableURL
            .resolvingSymlinksInPath()
            .standardizedFileURL
        let initialIdentity = try executableIdentity(for: canonicalURL)
        let probeEnvironment = sanitizedEnvironment(from: environment)
        let versionArguments = ["--version"]
        let versionOutput = try await runProbe(
            executableURL: canonicalURL,
            arguments: versionArguments,
            environment: probeEnvironment
        )
        let versionIdentity = try executableIdentity(for: canonicalURL)
        guard initialIdentity == versionIdentity else {
            throw CodexCapabilityProbeError.executableChangedDuringProbe(canonicalURL)
        }

        if
            let cached,
            cached.identity == versionIdentity,
            cached.versionOutput == versionOutput
        {
            return cached.report
        }

        let helpOutput = try await runProbe(
            executableURL: canonicalURL,
            arguments: ["exec", "--help"],
            environment: probeEnvironment
        )
        let helpIdentity = try executableIdentity(for: canonicalURL)
        guard versionIdentity == helpIdentity else {
            throw CodexCapabilityProbeError.executableChangedDuringProbe(canonicalURL)
        }
        let report = CodexCapabilityParser.parse(
            executableURL: canonicalURL,
            versionOutput: versionOutput,
            execHelpOutput: helpOutput
        )
        cached = CacheEntry(
            identity: helpIdentity,
            versionOutput: versionOutput,
            report: report
        )
        return report
    }

    private func runProbe(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]
    ) async throws -> String {
        let request = ProcessRequest(
            executableURL: executableURL,
            arguments: arguments,
            environment: environment,
            standardOutputLimit: Self.outputLimit,
            standardErrorLimit: Self.outputLimit,
            timeout: Self.probeTimeout
        )
        let output = try await processRunner.run(request)

        guard output.exitStatus == 0 else {
            throw CodexCapabilityProbeError.nonzeroExit(
                arguments: arguments,
                status: output.exitStatus
            )
        }
        guard !output.stdoutWasTruncated, !output.stderrWasTruncated else {
            throw CodexCapabilityProbeError.outputTruncated(arguments: arguments)
        }
        guard let text = String(data: output.stdout, encoding: .utf8) else {
            throw CodexCapabilityProbeError.invalidUTF8(arguments: arguments)
        }
        return text
    }

    private func sanitizedEnvironment(
        from environment: [String: String]
    ) -> [String: String] {
        let allowedKeys = [
            "HOME",
            "LANG",
            "LC_ALL",
            "LC_CTYPE",
            "PATH",
            "TERM",
            "TMPDIR",
        ]
        var sanitized = environment.filter {
            allowedKeys.contains($0.key) && $0.key != "PATH"
        }
        if let path = sanitizedPATH(environment["PATH"]) {
            sanitized["PATH"] = path
        }
        return sanitized
    }

    private func sanitizedPATH(_ path: String?) -> String? {
        guard let path else {
            return nil
        }

        var seen = Set<String>()
        let directories = path
            .split(separator: ":", omittingEmptySubsequences: true)
            .prefix(CodexLocator.defaultMaximumPATHEntries)
            .compactMap { component -> String? in
                let directory = String(component)
                guard directory.hasPrefix("/"), seen.insert(directory).inserted else {
                    return nil
                }
                return directory
            }
        return directories.isEmpty ? nil : directories.joined(separator: ":")
    }

    private func executableIdentity(for executableURL: URL) throws -> ExecutableIdentity {
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw CodexCapabilityProbeError.invalidExecutable(executableURL)
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: executableURL.path)
        guard let fileType = attributes[.type] as? FileAttributeType, fileType == .typeRegular else {
            throw CodexCapabilityProbeError.invalidExecutable(executableURL)
        }

        return ExecutableIdentity(
            url: executableURL,
            systemNumber: (attributes[.systemNumber] as? NSNumber)?.uint64Value,
            fileNumber: (attributes[.systemFileNumber] as? NSNumber)?.uint64Value,
            size: (attributes[.size] as? NSNumber)?.uint64Value,
            modificationDate: attributes[.modificationDate] as? Date
        )
    }
}

private struct ExecutableIdentity: Sendable, Equatable {
    let url: URL
    let systemNumber: UInt64?
    let fileNumber: UInt64?
    let size: UInt64?
    let modificationDate: Date?
}

private struct CacheEntry: Sendable {
    let identity: ExecutableIdentity
    let versionOutput: String
    let report: CodexCapabilityReport
}
