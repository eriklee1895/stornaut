import Foundation

public enum CodexRuntimeCapability: String, CaseIterable, Sendable {
    case structuredJSONL
    case outputSchema
    case ephemeralSession
    case strictConfiguration
    case isolatedUserConfiguration
    case ignoredExecRules
    case isolatedHookInventory
    case directRead
    case shell
    case unifiedExec
    case liveSearch
    case highContextSearch
    case publicCommandNetwork
    case managedNetworkProxy
    case browserOrDirectFetch
    case imageInspection
    case runtimeSkills
    case subagents
    case optionalProbeBroker
    case userDataWriteDenial
    case privateNetworkDenial
    case unixSocketDenial
    case noExecutorReachability
}

public enum CodexRuntimeCapabilityOutcome: Sendable, Equatable {
    case supported
    case unsupported(reasonKey: String)
    case degraded(reasonKey: String)
    case failed(reasonKey: String)
    case unverified(reasonKey: String)

    public var isUnsupported: Bool {
        guard case .unsupported = self else { return false }
        return true
    }

    public var isUnverified: Bool {
        guard case .unverified = self else { return false }
        return true
    }

    public var isDegraded: Bool {
        guard case .degraded = self else { return false }
        return true
    }
}

public struct CodexRuntimeCapabilityEntry: Sendable, Equatable {
    public let capability: CodexRuntimeCapability
    public let advertised: Bool
    public let configured: Bool
    public let observed: Bool
    public let contained: Bool
    public let outcome: CodexRuntimeCapabilityOutcome

    public init(
        capability: CodexRuntimeCapability,
        advertised: Bool,
        configured: Bool,
        observed: Bool,
        contained: Bool,
        outcome: CodexRuntimeCapabilityOutcome
    ) {
        self.capability = capability
        self.advertised = advertised
        self.configured = configured
        self.observed = observed
        self.contained = contained
        self.outcome = outcome
    }
}

public enum CodexRuntimeConfigurationValidation: Sendable, Equatable {
    case unverified
    case passed
    case failed(reasonKey: String)

    public var isFailed: Bool {
        guard case .failed = self else { return false }
        return true
    }
}

public enum CodexRuntimeGateReadiness: String, Sendable, Equatable {
    case configurationReady
    case configurationBlocked
}

struct CodexRuntimeDiagnosticEvidence: Sendable, Equatable {
    let profileDigest: String
    let strictConfigurationPassed: Bool
    let ignoredUserConfiguration: Bool
    let ignoredExecRules: Bool
    let hookInventoryEmpty: Bool
    let instructionIsolationPassed: Bool
    let runtimeSkillIsolationPassed: Bool
    let featureStates: [String: Bool]

    init(
        profileDigest: String,
        strictConfigurationPassed: Bool,
        ignoredUserConfiguration: Bool,
        ignoredExecRules: Bool,
        hookInventoryEmpty: Bool,
        instructionIsolationPassed: Bool,
        runtimeSkillIsolationPassed: Bool,
        featureStates: [String: Bool]
    ) {
        self.profileDigest = profileDigest
        self.strictConfigurationPassed = strictConfigurationPassed
        self.ignoredUserConfiguration = ignoredUserConfiguration
        self.ignoredExecRules = ignoredExecRules
        self.hookInventoryEmpty = hookInventoryEmpty
        self.instructionIsolationPassed = instructionIsolationPassed
        self.runtimeSkillIsolationPassed = runtimeSkillIsolationPassed
        self.featureStates = featureStates
    }

    static func passingFixture(
        profileDigest: String
    ) -> CodexRuntimeDiagnosticEvidence {
        CodexRuntimeDiagnosticEvidence(
            profileDigest: profileDigest,
            strictConfigurationPassed: true,
            ignoredUserConfiguration: true,
            ignoredExecRules: true,
            hookInventoryEmpty: true,
            instructionIsolationPassed: true,
            runtimeSkillIsolationPassed: true,
            featureStates: CodexRuntimeCapabilityParser.expectedFeatureStates
        )
    }

    func replacingFeatureState(
        name: String,
        enabled: Bool
    ) -> CodexRuntimeDiagnosticEvidence {
        var states = featureStates
        states[name] = enabled
        return CodexRuntimeDiagnosticEvidence(
            profileDigest: profileDigest,
            strictConfigurationPassed: strictConfigurationPassed,
            ignoredUserConfiguration: ignoredUserConfiguration,
            ignoredExecRules: ignoredExecRules,
            hookInventoryEmpty: hookInventoryEmpty,
            instructionIsolationPassed: instructionIsolationPassed,
            runtimeSkillIsolationPassed: runtimeSkillIsolationPassed,
            featureStates: states
        )
    }
}

public struct CodexRuntimeCapabilityReport: Sendable, Equatable {
    public let executableURL: URL
    public let version: String
    public let profileIdentifier: CodexRuntimeProfileID
    public let profileSchemaVersion: Int
    public let profileDigest: String
    public let entries: [
        CodexRuntimeCapability: CodexRuntimeCapabilityEntry
    ]
    public let configurationValidation: CodexRuntimeConfigurationValidation
    public let requiredMissingCapabilities: [CodexRuntimeCapability]
    public let degradedCapabilities: [CodexRuntimeCapability]
    public let readiness: CodexRuntimeGateReadiness

    public var isSyntaxCompatible: Bool {
        readiness == .configurationReady
    }

    func recordingObservedSuccessfulItemTypes(
        _ itemTypes: Set<String>
    ) -> CodexRuntimeCapabilityReport {
        var capabilities = Set<CodexRuntimeCapability>()
        if itemTypes.contains("command_execution") {
            capabilities.insert(.shell)
        }
        if itemTypes.contains("web_search") {
            capabilities.insert(.liveSearch)
        }
        if itemTypes.contains("collab_tool_call") {
            capabilities.insert(.subagents)
        }
        var updated = entries
        for capability in capabilities {
            guard let entry = updated[capability] else { continue }
            updated[capability] = CodexRuntimeCapabilityEntry(
                capability: capability,
                advertised: entry.advertised,
                configured: entry.configured,
                observed: true,
                contained: entry.contained,
                outcome: .supported
            )
        }
        return CodexRuntimeCapabilityReport(
            executableURL: executableURL,
            version: version,
            profileIdentifier: profileIdentifier,
            profileSchemaVersion: profileSchemaVersion,
            profileDigest: profileDigest,
            entries: updated,
            configurationValidation: configurationValidation,
            requiredMissingCapabilities: requiredMissingCapabilities,
            degradedCapabilities: degradedCapabilities,
            readiness: readiness
        )
    }
}

enum CodexRuntimeCapabilityParser {
    static let expectedFeatureStates: [String: Bool] = [
        "network_proxy": true,
        "shell_tool": true,
        "unified_exec": true,
        "multi_agent": true,
        "image_generation": false,
        "apps": false,
        "plugins": false,
        "remote_plugin": false,
        "plugin_sharing": false,
        "computer_use": false,
    ]

    private static let requiredConfiguredCapabilities: [
        CodexRuntimeCapability
    ] = [
        .structuredJSONL,
        .outputSchema,
        .ephemeralSession,
        .strictConfiguration,
        .isolatedUserConfiguration,
        .ignoredExecRules,
        .isolatedHookInventory,
        .directRead,
        .shell,
        .unifiedExec,
        .liveSearch,
        .highContextSearch,
        .publicCommandNetwork,
        .managedNetworkProxy,
        .runtimeSkills,
        .subagents,
    ]

    static func parse(
        executableURL: URL,
        versionOutput: String,
        rootHelpOutput: String,
        execHelpOutput: String,
        featureOutput: String,
        profile: CodexRuntimeProfile,
        diagnosticEvidence: CodexRuntimeDiagnosticEvidence? = nil
    ) -> CodexRuntimeCapabilityReport {
        let version = versionOutput.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let featureResult = parseFeatures(featureOutput)
        let syntax = advertisedCapabilities(
            rootHelpOutput: rootHelpOutput,
            execHelpOutput: execHelpOutput,
            featureResult: featureResult
        )
        let validation = configurationValidation(
            version: versionOutput,
            profile: profile,
            diagnosticEvidence: diagnosticEvidence,
            featureResult: featureResult
        )
        let mismatchedFeatures = featureMismatches(
            evidence: diagnosticEvidence
        )
        let configured = configuredCapabilities(
            profile: profile,
            evidence: diagnosticEvidence,
            validation: validation,
            featureResult: featureResult
        )
        let entries = Dictionary(
            uniqueKeysWithValues: CodexRuntimeCapability.allCases.map {
                capability in
                let advertised = syntax[capability] ?? false
                let isConfigured = configured.contains(capability)
                let outcome: CodexRuntimeCapabilityOutcome
                if featureResult.errorCapabilities.contains(capability) {
                    outcome = .unsupported(
                        reasonKey: "runtime.featureOutput.invalid"
                    )
                } else if mismatchedFeatures.contains(capability) {
                    outcome = .unsupported(
                        reasonKey: "runtime.featureState.mismatch"
                    )
                } else if syntaxRequired(capability), !advertised {
                    outcome = .unsupported(
                        reasonKey: "runtime.capability.notAdvertised"
                    )
                } else if experimentalNetworkCapability(capability) {
                    outcome = .degraded(
                        reasonKey: "runtime.networkProxy.experimental"
                    )
                } else {
                    outcome = .unverified(
                        reasonKey: reasonKey(for: capability)
                    )
                }
                return (
                    capability,
                    CodexRuntimeCapabilityEntry(
                        capability: capability,
                        advertised: advertised,
                        configured: isConfigured,
                        observed: false,
                        contained: false,
                        outcome: outcome
                    )
                )
            }
        )

        var missing = requiredConfiguredCapabilities.filter {
            capability in
            guard let entry = entries[capability] else { return true }
            return entry.outcome.isUnsupported || !entry.configured
        }
        if validation.isFailed,
           !missing.contains(.strictConfiguration)
        {
            missing.append(.strictConfiguration)
        }
        missing.sort { $0.rawValue < $1.rawValue }
        let degraded = entries.values
            .filter { $0.outcome.isDegraded }
            .map(\.capability)
            .sorted { $0.rawValue < $1.rawValue }

        return CodexRuntimeCapabilityReport(
            executableURL: executableURL,
            version: version,
            profileIdentifier: profile.identifier,
            profileSchemaVersion: profile.schemaVersion,
            profileDigest: profile.profileDigest,
            entries: entries,
            configurationValidation: validation,
            requiredMissingCapabilities: missing,
            degradedCapabilities: degraded,
            readiness: validation == .passed && missing.isEmpty
                ? .configurationReady
                : .configurationBlocked
        )
    }

    private struct FeatureParseResult {
        var states: [String: Bool] = [:]
        var stages: [String: String] = [:]
        var malformed = false
        var duplicateNames = Set<String>()
        var errorCapabilities = Set<CodexRuntimeCapability>()
    }

    private static func parseFeatures(
        _ output: String
    ) -> FeatureParseResult {
        var result = FeatureParseResult()
        for rawLine in output.split(
            separator: "\n",
            omittingEmptySubsequences: false
        ) {
            let line = String(rawLine)
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else {
                continue
            }
            let columns = line
                .components(separatedBy: twoOrMoreSpaces)
                .filter { !$0.isEmpty }
            guard
                columns.count == 3,
                !columns[0].contains(where: \.isWhitespace),
                let enabled = Bool(columns[2])
            else {
                result.malformed = true
                continue
            }
            let name = columns[0]
            if result.states[name] != nil {
                result.duplicateNames.insert(name)
            }
            result.states[name] = enabled
            result.stages[name] = columns[1]
        }
        for name in result.duplicateNames {
            if let capability = featureCapability(name) {
                result.errorCapabilities.insert(capability)
            }
        }
        return result
    }

    private static let twoOrMoreSpaces = try! NSRegularExpression(
        pattern: #"\s{2,}"#
    )

    private static func advertisedCapabilities(
        rootHelpOutput: String,
        execHelpOutput: String,
        featureResult: FeatureParseResult
    ) -> [CodexRuntimeCapability: Bool] {
        let rootIsValid = rootHelpOutput.contains("Usage: codex [OPTIONS]")
            && rootHelpOutput.contains("Options:")
        let execIsValid = execHelpOutput.contains(
            "Run Codex non-interactively"
        ) && execHelpOutput.contains("Usage: codex exec")
            && execHelpOutput.contains("Options:")
        let rootSearch = rootIsValid
            && hasUniqueOption("--search", in: rootHelpOutput)
        let rootApproval = rootIsValid
            && optionBlock(
                "--ask-for-approval",
                in: rootHelpOutput
            )?.contains("never") == true
        let execOptions: [String: Bool] = [
            "--json": execIsValid
                && hasUniqueOption("--json", in: execHelpOutput),
            "--output-schema": execIsValid
                && hasUniqueOption("--output-schema", in: execHelpOutput),
            "--ephemeral": execIsValid
                && hasUniqueOption("--ephemeral", in: execHelpOutput),
            "--strict-config": (
                rootIsValid
                    && hasUniqueOption(
                        "--strict-config",
                        in: rootHelpOutput
                    )
            ) || (
                execIsValid
                    && hasUniqueOption(
                        "--strict-config",
                        in: execHelpOutput
                    )
            ),
            "--ignore-user-config": execIsValid
                && hasUniqueOption(
                    "--ignore-user-config",
                    in: execHelpOutput
                ),
            "--ignore-rules": execIsValid
                && hasUniqueOption(
                    "--ignore-rules",
                    in: execHelpOutput
                ),
        ]
        func feature(
            _ name: String,
            stage: String? = nil,
            requiresEnabled: Bool = false
        ) -> Bool {
            guard
                featureResult.duplicateNames.contains(name) == false,
                let enabled = featureResult.states[name]
            else {
                return false
            }
            if let stage, featureResult.stages[name] != stage {
                return false
            }
            return !requiresEnabled || enabled
        }

        return [
            .structuredJSONL: execOptions["--json"] == true,
            .outputSchema: execOptions["--output-schema"] == true,
            .ephemeralSession: execOptions["--ephemeral"] == true,
            .strictConfiguration: execOptions["--strict-config"] == true,
            .isolatedUserConfiguration:
                execOptions["--ignore-user-config"] == true,
            .ignoredExecRules: execOptions["--ignore-rules"] == true,
            .isolatedHookInventory: feature(
                "hooks",
                stage: "stable",
                requiresEnabled: true
            ),
            .directRead: false,
            .shell: feature(
                "shell_tool",
                stage: "stable",
                requiresEnabled: true
            ),
            .unifiedExec: feature(
                "unified_exec",
                stage: "stable",
                requiresEnabled: true
            ),
            .liveSearch: rootSearch && rootApproval,
            .highContextSearch: false,
            .publicCommandNetwork: feature(
                "network_proxy",
                stage: "experimental"
            ),
            .managedNetworkProxy: feature(
                "network_proxy",
                stage: "experimental"
            ),
            .browserOrDirectFetch: feature(
                "browser_use",
                stage: "stable",
                requiresEnabled: true
            ) && feature(
                "browser_use_external",
                stage: "stable",
                requiresEnabled: true
            ) && feature(
                "browser_use_full_cdp_access",
                stage: "stable",
                requiresEnabled: true
            ),
            .imageInspection: feature(
                "view_image",
                stage: "stable",
                requiresEnabled: true
            ),
            .runtimeSkills: false,
            .subagents: feature(
                "multi_agent",
                stage: "stable",
                requiresEnabled: true
            ),
            .optionalProbeBroker: false,
            .userDataWriteDenial: false,
            .privateNetworkDenial: false,
            .unixSocketDenial: false,
            .noExecutorReachability: false,
        ]
    }

    private static func configurationValidation(
        version: String,
        profile: CodexRuntimeProfile,
        diagnosticEvidence: CodexRuntimeDiagnosticEvidence?,
        featureResult: FeatureParseResult
    ) -> CodexRuntimeConfigurationValidation {
        guard !featureResult.malformed else {
            return .failed(reasonKey: "runtime.featureOutput.malformed")
        }
        guard featureResult.duplicateNames.isEmpty else {
            return .failed(reasonKey: "runtime.featureOutput.duplicate")
        }
        guard profile.isCompatible(versionOutput: version) else {
            return .failed(reasonKey: "runtime.profile.versionMismatch")
        }
        guard let evidence = diagnosticEvidence else {
            return .unverified
        }
        guard evidence.profileDigest == profile.profileDigest else {
            return .failed(reasonKey: "runtime.profile.digestMismatch")
        }
        guard evidence.strictConfigurationPassed else {
            return .failed(reasonKey: "runtime.strictConfiguration.failed")
        }
        guard evidence.ignoredUserConfiguration else {
            return .failed(reasonKey: "runtime.userConfiguration.notIgnored")
        }
        guard evidence.ignoredExecRules else {
            return .failed(reasonKey: "runtime.execRules.notIgnored")
        }
        guard evidence.hookInventoryEmpty else {
            return .failed(reasonKey: "runtime.hooks.notIsolated")
        }
        guard evidence.instructionIsolationPassed else {
            return .failed(reasonKey: "runtime.instructions.notIsolated")
        }
        guard evidence.runtimeSkillIsolationPassed else {
            return .failed(reasonKey: "runtime.skills.notIsolated")
        }
        guard featureMismatches(evidence: evidence).isEmpty else {
            return .failed(reasonKey: "runtime.featureState.mismatch")
        }
        for (name, expected) in expectedFeatureStates
        where featureResult.states[name] != expected {
            return .failed(reasonKey: "runtime.featureState.mismatch")
        }
        return .passed
    }

    private static func configuredCapabilities(
        profile: CodexRuntimeProfile,
        evidence: CodexRuntimeDiagnosticEvidence?,
        validation: CodexRuntimeConfigurationValidation,
        featureResult: FeatureParseResult
    ) -> Set<CodexRuntimeCapability> {
        guard validation == .passed, let evidence else { return [] }
        guard evidence.profileDigest == profile.profileDigest else { return [] }
        for (name, expected) in expectedFeatureStates {
            guard
                evidence.featureStates[name] == expected,
                featureResult.states[name] == expected
            else {
                return []
            }
        }
        return Set(requiredConfiguredCapabilities)
    }

    private static func featureMismatches(
        evidence: CodexRuntimeDiagnosticEvidence?
    ) -> Set<CodexRuntimeCapability> {
        guard let evidence else { return [] }
        var capabilities = Set<CodexRuntimeCapability>()
        for (name, expected) in expectedFeatureStates
        where evidence.featureStates[name] != expected {
            if let capability = featureCapability(name) {
                capabilities.insert(capability)
            } else {
                capabilities.insert(.strictConfiguration)
            }
        }
        return capabilities
    }

    private static func syntaxRequired(
        _ capability: CodexRuntimeCapability
    ) -> Bool {
        switch capability {
        case .structuredJSONL,
             .outputSchema,
             .ephemeralSession,
             .strictConfiguration,
             .isolatedUserConfiguration,
             .ignoredExecRules,
             .isolatedHookInventory,
             .shell,
             .unifiedExec,
             .liveSearch,
             .publicCommandNetwork,
             .managedNetworkProxy,
             .browserOrDirectFetch,
             .imageInspection,
             .subagents:
            true
        case .directRead,
             .highContextSearch,
             .runtimeSkills,
             .optionalProbeBroker,
             .userDataWriteDenial,
             .privateNetworkDenial,
             .unixSocketDenial,
             .noExecutorReachability:
            false
        }
    }

    private static func experimentalNetworkCapability(
        _ capability: CodexRuntimeCapability
    ) -> Bool {
        capability == .publicCommandNetwork
            || capability == .managedNetworkProxy
    }

    private static func featureCapability(
        _ name: String
    ) -> CodexRuntimeCapability? {
        switch name {
        case "shell_tool": .shell
        case "unified_exec": .unifiedExec
        case "multi_agent": .subagents
        case "network_proxy": .managedNetworkProxy
        case "browser_use",
             "browser_use_external",
             "browser_use_full_cdp_access":
            .browserOrDirectFetch
        case "view_image": .imageInspection
        case "hooks": .isolatedHookInventory
        default: nil
        }
    }

    private static func reasonKey(
        for capability: CodexRuntimeCapability
    ) -> String {
        switch capability {
        case .browserOrDirectFetch:
            "runtime.browser.signedAppEvidenceRequired"
        case .imageInspection:
            "runtime.image.signedAppEvidenceRequired"
        case .userDataWriteDenial,
             .privateNetworkDenial,
             .unixSocketDenial,
             .noExecutorReachability:
            "runtime.containment.r5EvidenceRequired"
        default:
            "runtime.capability.behaviorUnverified"
        }
    }

    private static func hasUniqueOption(
        _ option: String,
        in help: String
    ) -> Bool {
        optionBlocks(option, in: help).count == 1
    }

    private static func optionBlock(
        _ option: String,
        in help: String
    ) -> String? {
        optionBlocks(option, in: help).first
    }

    private static func optionBlocks(
        _ option: String,
        in help: String
    ) -> [String] {
        let lines = help.components(separatedBy: .newlines)
        let indices = lines.indices.filter {
            isOptionHeader(lines[$0])
                && optionTokens(in: lines[$0]).contains(option)
        }
        return indices.map { index in
            var block = lines[index]
            for line in lines.dropFirst(index + 1) {
                if isOptionHeader(line) { break }
                block.append("\n")
                block.append(line)
            }
            return block
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
        if trimmed.hasPrefix("--") {
            return true
        }
        guard trimmed.hasPrefix("-"), trimmed.count > 1 else {
            return false
        }
        let second = trimmed[trimmed.index(after: trimmed.startIndex)]
        return !second.isWhitespace
    }
}

private extension String {
    func components(
        separatedBy expression: NSRegularExpression
    ) -> [String] {
        let range = NSRange(startIndex..<endIndex, in: self)
        var parts: [String] = []
        var location = startIndex
        for match in expression.matches(in: self, range: range) {
            guard
                let separatorRange = Range(match.range, in: self)
            else {
                continue
            }
            parts.append(String(self[location..<separatorRange.lowerBound]))
            location = separatorRange.upperBound
        }
        parts.append(String(self[location..<endIndex]))
        return parts
    }
}

public enum CodexRuntimeCapabilityProbeError:
    Error,
    Sendable,
    Equatable
{
    case invalidExecutable(URL)
    case executableChangedDuringProbe(URL)
    case nonzeroExit(arguments: [String], status: Int32)
    case outputTruncated(arguments: [String])
    case invalidUTF8(arguments: [String])
}

public actor CodexRuntimeCapabilityDetector {
    public static let outputLimit = 128 * 1_024
    public static let probeTimeout: Duration = .seconds(10)

    private let processRunner: any ProcessRunning
    private let runtimeDiagnostic: CodexRuntimeDiagnostic
    private var cached: RuntimeCacheEntry?

    public init() {
        processRunner = FoundationProcessRunner()
        runtimeDiagnostic = CodexRuntimeDiagnostic(
            runner: FoundationCodexRuntimeDiagnosticRunner()
        )
    }

    init(
        processRunner: any ProcessRunning = FoundationProcessRunner(),
        diagnosticRunner: any CodexRuntimeDiagnosticRunning =
            FoundationCodexRuntimeDiagnosticRunner()
    ) {
        self.processRunner = processRunner
        runtimeDiagnostic = CodexRuntimeDiagnostic(
            runner: diagnosticRunner
        )
    }

    public func report(
        executableURL: URL,
        environment: [String: String],
        profile: CodexRuntimeProfile =
            .capabilityFirstV1Codex0147
    ) async throws -> CodexRuntimeCapabilityReport {
        let canonicalURL = executableURL.resolvingSymlinksInPath()
            .standardizedFileURL
        let initialIdentity = try executableIdentity(for: canonicalURL)
        let diagnosticRoot = FileManager.default.temporaryDirectory
            .appending(
                path: "StornautCodexRuntimeDiagnostic-\(UUID().uuidString)",
                directoryHint: .isDirectory
            )
        let probeRoot = diagnosticRoot.appending(
            path: "static-probes",
            directoryHint: .isDirectory
        )
        let probeRuntimeHome = probeRoot.appending(
            path: "runtime-home",
            directoryHint: .isDirectory
        )
        let probeUserHome = probeRoot.appending(
            path: "user-home",
            directoryHint: .isDirectory
        )
        let probeWork = probeRoot.appending(
            path: "work",
            directoryHint: .isDirectory
        )
        let closedRoot = diagnosticRoot.appending(
            path: "closed-diagnostic",
            directoryHint: .isDirectory
        )
        let closedRuntimeHome = closedRoot.appending(
            path: "runtime-home",
            directoryHint: .isDirectory
        )
        let closedUserHome = closedRoot.appending(
            path: "user-home",
            directoryHint: .isDirectory
        )
        let closedWork = closedRoot.appending(
            path: "work",
            directoryHint: .isDirectory
        )
        let probeTemporaryDirectory = probeRuntimeHome.appending(
            path: "tmp",
            directoryHint: .isDirectory
        )
        try createDiagnosticDirectories([
            diagnosticRoot,
            probeRoot,
            probeRuntimeHome,
            probeUserHome,
            probeWork,
            probeTemporaryDirectory,
            closedRoot,
            closedRuntimeHome,
            closedUserHome,
            closedWork,
        ])
        defer { try? FileManager.default.removeItem(at: diagnosticRoot) }

        let probeEnvironment = sanitizedRuntimeProbeEnvironment(
            environment,
            runtimeHomeURL: probeRuntimeHome,
            userHomeURL: probeUserHome,
            temporaryDirectoryURL: probeTemporaryDirectory
        )
        let versionOutput = try await runProbe(
            executableURL: canonicalURL,
            arguments: ["--version"],
            environment: probeEnvironment,
            currentDirectoryURL: probeWork
        )
        try verifyIdentity(
            initialIdentity,
            executableURL: canonicalURL
        )
        let rootHelpOutput = try await runProbe(
            executableURL: canonicalURL,
            arguments: ["--help"],
            environment: probeEnvironment,
            currentDirectoryURL: probeWork
        )
        try verifyIdentity(
            initialIdentity,
            executableURL: canonicalURL
        )
        let execHelpOutput = try await runProbe(
            executableURL: canonicalURL,
            arguments: ["exec", "--help"],
            environment: probeEnvironment,
            currentDirectoryURL: probeWork
        )
        try verifyIdentity(
            initialIdentity,
            executableURL: canonicalURL
        )
        let featureOutput = try await runProbe(
            executableURL: canonicalURL,
            arguments: profile.featureDiagnosticArguments,
            environment: probeEnvironment,
            currentDirectoryURL: probeWork
        )
        try verifyIdentity(
            initialIdentity,
            executableURL: canonicalURL
        )

        let diagnosticEvidence = try await runtimeDiagnostic.validate(
            profile: profile,
            executableURL: canonicalURL,
            isolatedRuntimeHomeURL: closedRuntimeHome,
            isolatedUserHomeURL: closedUserHome,
            isolatedWorkingDirectoryURL: closedWork,
            inheritedEnvironment: environment
        )
        try verifyIdentity(
            initialIdentity,
            executableURL: canonicalURL
        )
        if
            let cached,
            cached.identity == initialIdentity,
            cached.versionOutput == versionOutput,
            cached.rootHelpOutput == rootHelpOutput,
            cached.execHelpOutput == execHelpOutput,
            cached.featureOutput == featureOutput,
            cached.profileDigest == profile.profileDigest,
            cached.diagnosticEvidence == diagnosticEvidence
        {
            return cached.report
        }
        let report = CodexRuntimeCapabilityParser.parse(
            executableURL: canonicalURL,
            versionOutput: versionOutput,
            rootHelpOutput: rootHelpOutput,
            execHelpOutput: execHelpOutput,
            featureOutput: featureOutput,
            profile: profile,
            diagnosticEvidence: diagnosticEvidence
        )
        cached = RuntimeCacheEntry(
            identity: initialIdentity,
            versionOutput: versionOutput,
            rootHelpOutput: rootHelpOutput,
            execHelpOutput: execHelpOutput,
            featureOutput: featureOutput,
            profileDigest: profile.profileDigest,
            diagnosticEvidence: diagnosticEvidence,
            report: report
        )
        return report
    }

    private func runProbe(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        currentDirectoryURL: URL
    ) async throws -> String {
        let output = try await processRunner.run(
            ProcessRequest(
                executableURL: executableURL,
                arguments: arguments,
                environment: environment,
                currentDirectoryURL: currentDirectoryURL,
                standardOutputLimit: Self.outputLimit,
                standardErrorLimit: Self.outputLimit,
                timeout: Self.probeTimeout
            )
        )
        guard output.exitStatus == 0 else {
            throw CodexRuntimeCapabilityProbeError.nonzeroExit(
                arguments: arguments,
                status: output.exitStatus
            )
        }
        guard
            !output.stdoutWasTruncated,
            !output.stderrWasTruncated
        else {
            throw CodexRuntimeCapabilityProbeError.outputTruncated(
                arguments: arguments
            )
        }
        guard let text = String(data: output.stdout, encoding: .utf8) else {
            throw CodexRuntimeCapabilityProbeError.invalidUTF8(
                arguments: arguments
            )
        }
        return text
    }

    private func verifyIdentity(
        _ expected: RuntimeExecutableIdentity,
        executableURL: URL
    ) throws {
        guard try executableIdentity(for: executableURL) == expected else {
            throw CodexRuntimeCapabilityProbeError
                .executableChangedDuringProbe(executableURL)
        }
    }

    private func executableIdentity(
        for executableURL: URL
    ) throws -> RuntimeExecutableIdentity {
        guard
            FileManager.default.isExecutableFile(
                atPath: executableURL.path
            )
        else {
            throw CodexRuntimeCapabilityProbeError.invalidExecutable(
                executableURL
            )
        }
        let attributes = try FileManager.default.attributesOfItem(
            atPath: executableURL.path
        )
        guard
            let fileType = attributes[.type] as? FileAttributeType,
            fileType == .typeRegular
        else {
            throw CodexRuntimeCapabilityProbeError.invalidExecutable(
                executableURL
            )
        }
        return RuntimeExecutableIdentity(
            url: executableURL,
            systemNumber: (
                attributes[.systemNumber] as? NSNumber
            )?.uint64Value,
            fileNumber: (
                attributes[.systemFileNumber] as? NSNumber
            )?.uint64Value,
            size: (attributes[.size] as? NSNumber)?.uint64Value,
            modificationDate: attributes[.modificationDate] as? Date
        )
    }

    private func createDiagnosticDirectories(
        _ directories: [URL]
    ) throws {
        for directory in directories {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        }
    }
}

private struct RuntimeExecutableIdentity: Sendable, Equatable {
    let url: URL
    let systemNumber: UInt64?
    let fileNumber: UInt64?
    let size: UInt64?
    let modificationDate: Date?
}

private struct RuntimeCacheEntry: Sendable {
    let identity: RuntimeExecutableIdentity
    let versionOutput: String
    let rootHelpOutput: String
    let execHelpOutput: String
    let featureOutput: String
    let profileDigest: String
    let diagnosticEvidence: CodexRuntimeDiagnosticEvidence
    let report: CodexRuntimeCapabilityReport
}

private func sanitizedRuntimeProbeEnvironment(
    _ environment: [String: String],
    runtimeHomeURL: URL,
    userHomeURL: URL,
    temporaryDirectoryURL: URL
) -> [String: String] {
    let allowedKeys = Set([
        "LANG",
        "LC_ALL",
        "LC_CTYPE",
        "PATH",
        "TERM",
    ])
    var sanitized = environment.filter {
        allowedKeys.contains($0.key)
    }
    if let path = sanitized["PATH"] {
        var seen = Set<String>()
        sanitized["PATH"] = path
            .split(separator: ":", omittingEmptySubsequences: true)
            .prefix(CodexLocator.defaultMaximumPATHEntries)
            .map(String.init)
            .filter { $0.hasPrefix("/") }
            .filter { seen.insert($0).inserted }
            .joined(separator: ":")
    }
    sanitized["CODEX_HOME"] = runtimeHomeURL.path
    sanitized["HOME"] = userHomeURL.path
    sanitized["TMPDIR"] = temporaryDirectoryURL.path
    return sanitized
}
