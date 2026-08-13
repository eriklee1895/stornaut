#if DEBUG
import CoreGraphics
import CoreText
import CryptoKit
import Darwin
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum CapabilityRuntimeWorkerError:
    Error,
    Sendable,
    Equatable
{
    case invalidIdentity
    case invalidDiagnosticRoot
    case codexUnavailable
    case incompatibleCodex
    case fixtureStagingFailed
    case executableStagingFailed(stage: String, errno: Int32)
    case canaryServerFailed
    case modelDiagnosticFailed(reasonKey: String)
    case commandNotInvoked(progressKey: String)
    case invalidEnvelope
    case missingCapabilityEvidence
    case containmentFailed(reasonKey: String)
    case cleanupFailed(reasonKey: String)
}

public struct CapabilityRuntimeWorkerFailureReceipt:
    Sendable,
    Equatable
{
    private static let prefix = "stornaut-r5-worker-failure"
    public let reasonKey: String

    public init(reasonKey: String) throws {
        guard
            (1...512).contains(reasonKey.utf8.count),
            reasonKey.hasPrefix("runtime."),
            reasonKey.unicodeScalars.allSatisfy({
                (0x30...0x39).contains($0.value)
                    || (0x41...0x5A).contains($0.value)
                    || (0x61...0x7A).contains($0.value)
                    || $0.value == 0x2D
                    || $0.value == 0x2E
            })
        else {
            throw CapabilityRuntimeWorkerError.invalidIdentity
        }
        self.reasonKey = reasonKey
    }

    public init(error: CapabilityRuntimeWorkerError) throws {
        let reasonKey: String
        switch error {
        case .invalidIdentity:
            reasonKey = "runtime.worker.invalid-identity"
        case .invalidDiagnosticRoot:
            reasonKey = "runtime.worker.invalid-diagnostic-root"
        case .codexUnavailable:
            reasonKey = "runtime.worker.codex-unavailable"
        case .incompatibleCodex:
            reasonKey = "runtime.worker.incompatible-codex"
        case .fixtureStagingFailed:
            reasonKey = "runtime.worker.fixture-staging-failed"
        case .executableStagingFailed:
            reasonKey = "runtime.worker.executable-staging-failed"
        case .canaryServerFailed:
            reasonKey = "runtime.worker.canary-server-failed"
        case let .modelDiagnosticFailed(value):
            reasonKey = value
        case .commandNotInvoked:
            reasonKey = "runtime.worker.command-not-invoked"
        case .invalidEnvelope:
            reasonKey = "runtime.worker.invalid-envelope"
        case .missingCapabilityEvidence:
            reasonKey = "runtime.worker.missing-capability-evidence"
        case let .containmentFailed(value):
            reasonKey = value
        case let .cleanupFailed(value):
            reasonKey = value
        }
        try self.init(reasonKey: reasonKey)
    }

    public func encodedLine() -> Data {
        Data(
            "\(Self.prefix):\(reasonKey)\n".utf8
        )
    }

    public static func decodeLine(_ data: Data) throws -> Self {
        guard
            data.count <= 1_024,
            data.last == 0x0A,
            let line = String(
                data: data.dropLast(),
                encoding: .utf8
            )
        else {
            throw CapabilityRuntimeWorkerError.invalidIdentity
        }
        let prefix = Self.prefix + ":"
        guard line.hasPrefix(prefix) else {
            throw CapabilityRuntimeWorkerError.invalidIdentity
        }
        let receipt = try Self(
            reasonKey: String(line.dropFirst(prefix.count))
        )
        guard receipt.encodedLine() == data else {
            throw CapabilityRuntimeWorkerError.invalidIdentity
        }
        return receipt
    }
}

struct SyntheticDiagnosticCodexPackage: Sendable, Equatable {
    let rootURL: URL
    let executableURL: URL
    let codeModeHostURL: URL
    let ripgrepURL: URL
    let zshURL: URL
}

struct SyntheticCapabilitySessionTopology: Sendable, Equatable {
    let outerExecutableURL: URL
    let appServerExecutableURL: URL
}

func syntheticCapabilitySessionTopology(
    outerExecutableURL: URL,
    appServerExecutableURL: URL
) throws -> SyntheticCapabilitySessionTopology {
    let outer = outerExecutableURL.standardizedFileURL
    let inner = appServerExecutableURL.standardizedFileURL
    guard
        outer.isFileURL,
        inner.isFileURL,
        outer.path.hasPrefix("/"),
        inner.path.hasPrefix("/"),
        outer != inner,
        inner.lastPathComponent == "codex",
        inner.deletingLastPathComponent().lastPathComponent == "bin",
        inner.path.contains("/codex-r5-package/bin/codex"),
        !outer.path.contains("/codex-r5-package/")
    else {
        throw CapabilityRuntimeWorkerError.invalidIdentity
    }
    return SyntheticCapabilitySessionTopology(
        outerExecutableURL: outer,
        appServerExecutableURL: inner
    )
}

struct CapabilityRuntimeContainmentSnapshot: Sendable, Equatable {
    let observedMarkerIDs: Set<String>
    let mutationResidue: Bool
    let requiresPrivateDenial: Bool
    let authUnchanged: Bool
}

func sanitizedCapabilityRuntimeEventCategory(
    prefix: String,
    value: String
) -> String? {
    let validComponent: (Substring) -> Bool = { component in
        !component.isEmpty
            && component.utf8.count <= 128
            && component.unicodeScalars.allSatisfy {
                (0x30...0x39).contains($0.value)
                    || (0x41...0x5A).contains($0.value)
                    || (0x61...0x7A).contains($0.value)
                    || $0.value == 0x2D
                    || $0.value == 0x5F
            }
    }
    let prefixComponents = prefix.split(
        separator: "/",
        omittingEmptySubsequences: false
    )
    let valueComponents = value.split(
        separator: "/",
        omittingEmptySubsequences: false
    )
    guard
        prefixComponents.count == 1,
        prefixComponents.allSatisfy(validComponent),
        valueComponents.allSatisfy(validComponent)
    else {
        return nil
    }
    return ([prefix] + valueComponents.map(String.init))
        .joined(separator: ".")
}

func capabilityRuntimeEnvelopeErrorReason(
    _ error: InvestigationEnvelopeV2Error
) -> String {
    switch error {
    case .invalidContext:
        "invalid-context"
    case .invalidJSON:
        "invalid-json"
    case .invalidStructure:
        "invalid-structure"
    case .inputLimitExceeded:
        "input-limit"
    case .unsupportedVersion:
        "unsupported-version"
    case .identityMismatch:
        "identity-mismatch"
    case .invalidSummary:
        "invalid-summary"
    case .invalidCoverage:
        "invalid-coverage"
    case .invalidEvidence:
        "invalid-evidence"
    case .invalidFinding:
        "invalid-finding"
    case .invalidCandidateProposal:
        "invalid-proposal"
    case .invalidDegradation:
        "invalid-degradation"
    case .invalidPublicURL:
        "invalid-public-url"
    case .collectionLimitExceeded:
        "collection-limit"
    }
}

func imageEvidenceContainsSyntheticToken(
    _ evidence: [InvestigationEvidenceV2],
    token: String
) -> Bool {
    evidence.contains {
        $0.source == .image
            && $0.summary.contains(token)
    }
}

func runtimeDiagnosticToken(_ label: String) -> String {
    let random = UUID().uuidString.replacingOccurrences(
        of: "-",
        with: ""
    )
    return "STORNAUT_R5_\(label)_\(random)"
}

func runtimeNetworkDenialMarkerTranslation(
    denialTokens: [String: String],
    includesPrivateAddress: Bool
) throws -> String {
    let ordered: [(String, String)] = [
        ("public.direct.denied", "STORNAUT_R5_PUBLIC_DIRECT_DENIED"),
        ("loopback.denied", "STORNAUT_R5_LOOPBACK_DENIED"),
        ("linklocal.denied", "STORNAUT_R5_LINKLOCAL_DENIED"),
        ("loopback6.denied", "STORNAUT_R5_LOOPBACK6_DENIED"),
        ("linklocal6.denied", "STORNAUT_R5_LINKLOCAL6_DENIED"),
        ("ula6.denied", "STORNAUT_R5_ULA6_DENIED"),
        ("unix.denied", "STORNAUT_R5_UNIX_DENIED"),
    ] + (
        includesPrivateAddress
            ? [
                ("private.denied", "STORNAUT_R5_PRIVATE_DENIED"),
            ]
            : []
    )
    guard
        Set(denialTokens.keys).isSuperset(of: ordered.map(\.0)),
        ordered.allSatisfy({
            guard let token = denialTokens[$0.0] else {
                return false
            }
            return !token.isEmpty
                && token.utf8.count <= 128
                && token.unicodeScalars.allSatisfy {
                    (0x30...0x39).contains($0.value)
                        || (0x41...0x5A).contains($0.value)
                        || (0x61...0x7A).contains($0.value)
                        || $0.value == 0x5F
                }
        })
    else {
        throw CapabilityRuntimeWorkerError.fixtureStagingFailed
    }
    let fixedOutput = ordered.map(\.1).joined(separator: "\n")
    let randomizedOutput = ordered.map {
        "print -r -- \(denialTokens[$0.0]!)"
    }.joined(separator: "\n")
    return """
    expected_network_probe_output='\(fixedOutput)'
    [[ "$network_probe_output" == "$expected_network_probe_output" ]] ||
        exit 72
    \(randomizedOutput)
    """
}

func syntheticTokenPNG(_ token: String) throws -> Data {
    let width = 1_600
    let height = 320
    guard
        !token.isEmpty,
        token.utf8.count <= 128,
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    else {
        throw CapabilityRuntimeWorkerError.fixtureStagingFailed
    }
    context.setFillColor(
        CGColor(
            red: 0.97,
            green: 0.98,
            blue: 1,
            alpha: 1
        )
    )
    context.fill(
        CGRect(x: 0, y: 0, width: width, height: height)
    )
    let attributes: [CFString: Any] = [
        kCTFontAttributeName:
            CTFontCreateWithName("Menlo-Bold" as CFString, 32, nil),
        kCTForegroundColorAttributeName:
            CGColor(gray: 0.08, alpha: 1),
    ]
    let line = CTLineCreateWithAttributedString(
        CFAttributedStringCreate(
            nil,
            token as CFString,
            attributes as CFDictionary
        )
    )
    context.textPosition = CGPoint(x: 40, y: 140)
    CTLineDraw(line, context)
    guard let image = context.makeImage() else {
        throw CapabilityRuntimeWorkerError.fixtureStagingFailed
    }
    let data = NSMutableData()
    guard
        let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        throw CapabilityRuntimeWorkerError.fixtureStagingFailed
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw CapabilityRuntimeWorkerError.fixtureStagingFailed
    }
    return data as Data
}

func liveSearchCompanionSucceeded(
    _ observation: CodexAppServerObservation
) -> Bool {
    observation.capabilityObservations.contains(.webSearchCompleted)
        && observation.finalAgentMessage == #"{"verdict":"passed"}"#
}

func capabilityRuntimeContainmentFailureReason(
    _ snapshot: CapabilityRuntimeContainmentSnapshot
) -> String? {
    let markers = snapshot.observedMarkerIDs
    if !markers.contains("write.matrix.denied") {
        return "runtime.integrity.user-write-denial.not-observed"
    }
    if snapshot.mutationResidue {
        return "runtime.integrity.user-write-residue"
    }
    if !markers.contains("nested.write.denied") {
        return "runtime.integrity.nested-write-denial.not-observed"
    }
    if !markers.contains("public.direct.denied") {
        return "runtime.integrity.public-direct-bypass.not-denied"
    }
    if !markers.contains("loopback.denied") {
        return "runtime.integrity.loopback-denial.not-observed"
    }
    if !markers.contains("linklocal.denied") {
        return "runtime.integrity.linklocal-denial.not-observed"
    }
    if !markers.contains("loopback6.denied") {
        return "runtime.integrity.loopback6-denial.not-observed"
    }
    if !markers.contains("linklocal6.denied") {
        return "runtime.integrity.linklocal6-denial.not-observed"
    }
    if !markers.contains("ula6.denied") {
        return "runtime.integrity.ula6-denial.not-observed"
    }
    if
        snapshot.requiresPrivateDenial,
        !markers.contains("private.denied")
    {
        return "runtime.integrity.private-denial.not-observed"
    }
    if !markers.contains("unix.denied") {
        return "runtime.integrity.unix-socket-denial.not-observed"
    }
    if !snapshot.authUnchanged {
        return "runtime.integrity.auth-source-changed"
    }
    return nil
}

public enum CapabilityRuntimeWorker {
    static let primaryDiagnosticTimeout: Duration = .seconds(120)
    static let commandDiagnosticMaximumAttempts = 3

    public static func runLocalDiagnostic(
        investigationID: UUID,
        networkProbeExecutableURL: URL? = nil
    ) async throws -> CapabilityRuntimeWorkerEvidence {
        try await runPreparedDiagnostic(
            investigationID: investigationID,
            networkProbeExecutableURL: networkProbeExecutableURL,
            runRootURL: nil
        )
    }

    static func runSyntheticDiagnosticForTesting(
        investigationID: UUID,
        networkProbeExecutableURL: URL,
        runRootURL: URL,
        primaryTimeout: Duration = primaryDiagnosticTimeout
    ) async throws -> CapabilityRuntimeWorkerEvidence {
        let identity = try LocalWorkerIdentity.current()
        let validatedRoot = try standaloneTestRunRoot(
            url: runRootURL,
            userID: identity.userID,
            investigationID: investigationID
        )
        return try await runPreparedDiagnostic(
            investigationID: investigationID,
            networkProbeExecutableURL: networkProbeExecutableURL,
            runRootURL: validatedRoot,
            primaryTimeout: primaryTimeout
        )
    }

    private static func runPreparedDiagnostic(
        investigationID: UUID,
        networkProbeExecutableURL: URL?,
        runRootURL: URL?,
        primaryTimeout: Duration = primaryDiagnosticTimeout
    ) async throws -> CapabilityRuntimeWorkerEvidence {
        guard primaryTimeout > .zero, primaryTimeout <= .seconds(300) else {
            throw CapabilityRuntimeWorkerError.invalidIdentity
        }
        let started = ContinuousClock.now
        let identity = try LocalWorkerIdentity.current()
        let runRoot = try runRootURL ?? localRunRoot(
            userID: identity.userID,
            investigationID: investigationID
        )
        let homeURL = URL(
            filePath: identity.homeDirectory,
            directoryHint: .isDirectory
        ).standardizedFileURL
        let authSourceURL = homeURL.appending(
            path: ".codex/auth.json"
        )
        let initialAuthSnapshot = try StableFileSnapshot.read(
            authSourceURL
        )
        let processEnvironment = closedWorkerEnvironment(
            homeURL: homeURL
        )
        let installation = try await locateCodex(
            environment: processEnvironment
        )
        let installedCodexPackage =
            try syntheticDiagnosticCodexPackage(
                installation: installation
            )
        let version = try await codexVersion(
            executableURL: installation.executableURL,
            environment: processEnvironment,
            workingDirectoryURL: runRoot
        )
        guard
            CodexRuntimeProfile.capabilityFirstV1Codex0147
                .isCompatible(versionOutput: version)
        else {
            throw CapabilityRuntimeWorkerError.incompatibleCodex
        }

        let staticReport = try await CodexRuntimeCapabilityDetector()
            .report(
                executableURL: installation.executableURL,
                environment: processEnvironment
            )
        guard staticReport.readiness == .configurationReady else {
            throw CapabilityRuntimeWorkerError.incompatibleCodex
        }

        let workspace = try CodexRuntimeWorkspace.create(
            under: runRoot,
            forbiddenRoots: [
                homeURL,
                authSourceURL.deletingLastPathComponent(),
            ]
        )
        var didRemoveWorkspace = false
        defer {
            if !didRemoveWorkspace {
                try? workspace.remove()
            }
        }

        do {
        let fixture = try RuntimeDiagnosticFixture.stage(
            workspace: workspace.paths
        )
        let stagedCodexPackage =
            try stageSyntheticDiagnosticCodexPackage(
                source: installedCodexPackage,
                workspace: workspace.paths
            )
        let stagedCodexExecutableURL =
            stagedCodexPackage.executableURL
        let capabilitySessionTopology =
            try syntheticCapabilitySessionTopology(
                outerExecutableURL: installation.executableURL,
                appServerExecutableURL: stagedCodexExecutableURL
            )
        let networkProbeSourceURL = (
            networkProbeExecutableURL
                ?? URL(filePath: CommandLine.arguments[0])
        )
        .resolvingSymlinksInPath()
        .standardizedFileURL
        let networkProbeSourceOwnerUserID =
            try runtimeNetworkProbeSourceOwner(
                sourceURL: networkProbeSourceURL,
                currentExecutableURL: URL(
                    filePath: CommandLine.arguments[0]
                ),
                currentUserID: identity.userID
            )
        let stagedNetworkProbeURL = workspace.paths.fixturesURL.appending(
            path: "stornaut-r5-network-denial-probe"
        )
        try cloneSealedExecutable(
            sourceURL: networkProbeSourceURL,
            destinationURL: stagedNetworkProbeURL,
            expectedSourceOwnerUserID:
                networkProbeSourceOwnerUserID
        )
        let stagedVersion = try await codexVersion(
            executableURL: stagedCodexExecutableURL,
            environment: processEnvironment,
            workingDirectoryURL: workspace.paths.workURL
        )
        guard
            stagedVersion.trimmingCharacters(
                in: .whitespacesAndNewlines
            ) == version.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        else {
            throw CapabilityRuntimeWorkerError.incompatibleCodex
        }
        let canary = try RuntimeCanaryServer.start(
            socketURL: URL(
                filePath:
                    "/tmp/s5-\(UUID().uuidString.lowercased()).sock"
            )
        )
        defer { canary.stop() }

        let policy = CodexContainmentPolicy()
        let readScope = try syntheticDiagnosticReadScope(
            privateRootURL: homeURL,
            syntheticDeniedReadURL: fixture.deniedReadURL
        )
        let configuration = try policy.configuration(
            workspace: workspace.paths,
            projectedAuthSourceURL: authSourceURL,
            readScope: readScope
        )
        _ = try policy.install(configuration, in: workspace.paths)
        let environment = try CodexRuntimeEnvironmentPolicy().project(
            inherited: processEnvironment,
            workspace: workspace.paths,
            forbiddenHomeURL: homeURL
        )
        try await runSyntheticDiagnosticPrivacyProbe(
            outerExecutableURL: installation.executableURL,
            probeExecutableURL: stagedCodexExecutableURL,
            workspace: workspace.paths,
            deniedURL: fixture.deniedReadURL,
            readableURL: fixture.directReadURL,
            configuration: configuration,
            environment: environment
        )
        let projector = CodexRuntimeAuthProjector()
        let authProjection = try projector.read(from: authSourceURL)
        let context = try InvestigationProtocolContext(
            investigationID: investigationID.uuidString.lowercased(),
            runID: "r5-local-run",
            targetIDs: ["synthetic-target"],
            candidateTargetIDs: [:],
            requiredCapabilities: Set(
                InvestigationCapability.allCases.filter {
                    $0 != .probeBroker
                }
            )
        )
        let schema = try InvestigationEnvelopeV2Schema
            .loadStructuredOutputJSONValue()
        let markerTokens = fixture.commandMarkers(
            canary: canary,
            privateAddress: privateIPv4Address()
        )
        let commandRequirements = fixture.commandRequirements(
            markerIDs: Set(markerTokens.keys)
        )
        try fixture.installCommandProbe(
            canary: canary,
            privateAddress: privateIPv4Address(),
            networkProbeExecutableURL: stagedNetworkProbeURL
        )
        let commandPlans = capabilityRuntimeCommandDiagnosticPlans(
            context: context
        )
        authProjection.erase()
        var commandGroups: [CapabilityRuntimeDiagnosticGroup] = []
        for plan in commandPlans {
            var groupMarkers: [String: String] = [:]
            for markerID in plan.markerIDs {
                guard let marker = markerTokens[markerID] else {
                    throw CapabilityRuntimeWorkerError.fixtureStagingFailed
                }
                groupMarkers[markerID] = marker
            }
            let groupRequirements = commandRequirements.filter {
                plan.markerIDs.contains($0.key)
            }
            var admittedGroup: CapabilityRuntimeDiagnosticGroup?
            for attempt in 1...commandDiagnosticMaximumAttempts {
                do {
                    admittedGroup = try await runEnvelopeDiagnosticGroup(
                        topology: capabilitySessionTopology,
                        workspace: workspace.paths,
                        authSourceURL: authSourceURL,
                        configuration: configuration,
                        environment: environment,
                        projector: projector,
                        context: context,
                        probePrompt: plan.probePrompt,
                        finalizationPrompt: plan.finalizationPrompt,
                        schema: try capabilityRuntimeGroupSchema(
                            schema,
                            context: context,
                            expectedEvidenceIDs:
                                Set(plan.expectedEvidenceIDs)
                        ),
                        expectedEvidenceIDs: Set(plan.expectedEvidenceIDs),
                        capabilityOutputMarkers: groupMarkers,
                        capabilityCommandRequirements: groupRequirements,
                        requiredCommandMarkerIDs: Set(plan.markerIDs),
                        timeout: primaryTimeout,
                        reasonPrefix: plan.reasonPrefix
                    )
                } catch let CapabilityRuntimeWorkerError.commandNotInvoked(
                    progressKey
                ) {
                    if attempt == commandDiagnosticMaximumAttempts {
                        throw CapabilityRuntimeWorkerError
                            .modelDiagnosticFailed(
                                reasonKey:
                                    plan.reasonPrefix
                                    + ".runtime.worker.command-not-invoked."
                                    + progressKey
                            )
                    }
                }
                if admittedGroup != nil { break }
            }
            guard let admittedGroup else {
                throw CapabilityRuntimeWorkerError.missingCapabilityEvidence
            }
            commandGroups.append(admittedGroup)
        }
        let imageGroup = try await runEnvelopeDiagnosticGroup(
            topology: capabilitySessionTopology,
            workspace: workspace.paths,
            authSourceURL: authSourceURL,
            configuration: configuration,
            environment: environment,
            projector: projector,
            context: context,
            probePrompt: fixture.imageProbePrompt(),
            finalizationPrompt:
                fixture.imageFinalizationPrompt(context: context),
            schema: try capabilityRuntimeGroupSchema(
                schema,
                context: context,
                expectedEvidenceIDs: ["image-evidence"]
            ),
            expectedEvidenceIDs: ["image-evidence"],
            expectedImageURL: fixture.imageURL,
            timeout: primaryTimeout,
            reasonPrefix: "runtime.worker.image-group"
        )
        let skillGroup = try await runEnvelopeDiagnosticGroup(
            topology: capabilitySessionTopology,
            workspace: workspace.paths,
            authSourceURL: authSourceURL,
            configuration: configuration,
            environment: environment,
            projector: projector,
            context: context,
            probePrompt: fixture.skillProbePrompt(),
            finalizationPrompt:
                fixture.skillFinalizationPrompt(context: context),
            schema: try capabilityRuntimeGroupSchema(
                schema,
                context: context,
                expectedEvidenceIDs: ["skill-evidence"]
            ),
            expectedEvidenceIDs: ["skill-evidence"],
            selectedRuntimeSkill: CodexSelectedRuntimeSkill(
                name: "stornaut-r5-diagnostic",
                path: fixture.skillURL
            ),
            timeout: primaryTimeout,
            reasonPrefix: "runtime.worker.skill-group"
        )
        let subagentGroup = try await runEnvelopeDiagnosticGroup(
            topology: capabilitySessionTopology,
            workspace: workspace.paths,
            authSourceURL: authSourceURL,
            configuration: configuration,
            environment: environment,
            projector: projector,
            context: context,
            probePrompt: fixture.subagentProbePrompt(),
            finalizationPrompt:
                fixture.subagentFinalizationPrompt(context: context),
            schema: try capabilityRuntimeGroupSchema(
                schema,
                context: context,
                expectedEvidenceIDs: ["subagent-evidence"]
            ),
            expectedEvidenceIDs: ["subagent-evidence"],
            childAgentOutputMarkers: [
                "subagent.result": fixture.subagentToken,
            ],
            timeout: primaryTimeout,
            reasonPrefix: "runtime.worker.subagent-group"
        )
        let searchGroup = try await runLiveSearchCompanion(
            topology: capabilitySessionTopology,
            workspace: workspace.paths,
            authSourceURL: authSourceURL,
            configuration: configuration,
            environment: environment,
            projector: projector,
            context: context,
            schema: schema
        )
        guard var capabilityObservation = commandGroups.first?.observation
        else {
            throw CapabilityRuntimeWorkerError.invalidEnvelope
        }
        for group in commandGroups.dropFirst() {
            capabilityObservation = capabilityObservation.mergingEvidence(
                from: group.observation
            )
        }
        capabilityObservation = capabilityObservation
            .mergingEvidence(from: imageGroup.observation)
            .mergingEvidence(from: skillGroup.observation)
            .mergingEvidence(from: subagentGroup.observation)
            .mergingEvidence(from: searchGroup.observation)
        let evidence =
            commandGroups.flatMap(\.envelope.evidence)
            + imageGroup.envelope.evidence
            + skillGroup.envelope.evidence
            + subagentGroup.envelope.evidence
            + searchGroup.envelope.evidence
        guard
            Set(evidence.map(\.id)).count == evidence.count
        else {
            throw CapabilityRuntimeWorkerError.invalidEnvelope
        }

        let capabilities = try capabilityEvidence(
            staticReport: staticReport,
            observation: capabilityObservation,
            evidence: evidence,
            fixture: fixture
        )
        let integrityBeforeCleanup = try integrityEvidence(
            observation: capabilityObservation,
            fixture: fixture,
            authSourceURL: authSourceURL,
            initialAuthSnapshot: initialAuthSnapshot
        )
        let stagedCodexExecutableSHA256 = try sha256File(
            stagedCodexExecutableURL
        )
        canary.stop()
        do {
            try workspace.remove()
            didRemoveWorkspace = true
        } catch {
            throw CapabilityRuntimeWorkerError.cleanupFailed(
                reasonKey: "runtime.cleanup.workspace-remove"
            )
        }
        guard !FileManager.default.fileExists(
            atPath: workspace.paths.rootURL.path
        ) else {
            throw CapabilityRuntimeWorkerError.cleanupFailed(
                reasonKey: "runtime.cleanup.workspace-residue"
            )
        }

        let duration = started.duration(to: .now).boundedMilliseconds
        let eventCategories = try capabilityObservation
            .notificationMethods.map {
                guard
                    let category =
                        sanitizedCapabilityRuntimeEventCategory(
                            prefix: "notification",
                            value: $0
                        )
                else {
                    throw CapabilityRuntimeWorkerError.invalidIdentity
                }
                return category
            }
            + capabilityObservation.capabilityObservations.flatMap {
                observation -> [String] in
                switch observation {
                case let .command(source, succeeded, markerIDs):
                    let prefix = "command.\(source.rawValue)."
                        + (succeeded ? "succeeded" : "failed")
                    if markerIDs.isEmpty {
                        return [prefix + ".no-marker"]
                    }
                    return markerIDs.map {
                        prefix + ".\($0)"
                    }
                case .webSearchStarted:
                    return ["capability.webSearch.started"]
                case .webSearchCompleted:
                    return ["capability.webSearch.completed"]
                case .imageViewStarted:
                    return ["capability.imageView.started"]
                case .imageViewCompleted:
                    return ["capability.imageView.completed"]
                case .runtimeSkillSelected:
                    return ["capability.runtimeSkill.selected"]
                case .subagentSpawnStarted:
                    return ["capability.subagentSpawn.started"]
                case let .subagentSpawnCompleted(receiverCount):
                    return [
                        "capability.subagentSpawn.completed.\(receiverCount)",
                    ]
                case .subagentResultObserved:
                    return ["capability.subagentResult.observed"]
                }
            }
            + capabilityObservation.itemTypes.map {
                guard
                    let category =
                        sanitizedCapabilityRuntimeEventCategory(
                            prefix: "item",
                            value: $0
                        )
                else {
                    throw CapabilityRuntimeWorkerError.invalidIdentity
                }
                return category
            }
            + capabilityObservation.upstreamErrors.map {
                "upstream.\($0.category.rawValue).code-"
                    + ($0.code.map(String.init) ?? "none")
                    + ".retry-\($0.willRetry)"
            }
        let integrity = integrityBeforeCleanup + [
            try CapabilityRuntimeIntegrityEvidence(
                property: .runtimeStateCleanup,
                verdict: .contained,
                reasonKey: nil
            ),
            try CapabilityRuntimeIntegrityEvidence(
                property: .authStateNonPersistence,
                verdict: .contained,
                reasonKey: nil
            ),
        ]
        return try CapabilityRuntimeWorkerEvidence(
            codexVersion: version.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            codexExecutableSHA256: stagedCodexExecutableSHA256,
            provider: .openAI,
            publicEndpointHosts: ["example.com"],
            syntheticFixtureSHA256s: fixture.hashes,
            sanitizedEventCategories: Array(Set(eventCategories)).sorted(),
            durationMilliseconds: duration,
            capabilities: capabilities,
            integrity: integrity
        )
        } catch {
            do {
                try workspace.remove()
                didRemoveWorkspace = true
            } catch {
                throw CapabilityRuntimeWorkerError.cleanupFailed(
                    reasonKey: "runtime.cleanup.recovery-remove"
                )
            }
            throw error
        }
    }
}

func capabilityRuntimeProgressReasonKey(
    _ observation: CodexAppServerObservation,
    phaseKey: String = "unknown"
) -> String {
    var successfulCommands = 0
    var failedCommands = 0
    for capability in observation.capabilityObservations {
        guard case let .command(_, succeeded, _) = capability else {
            continue
        }
        if succeeded {
            successfulCommands += 1
        } else {
            failedCommands += 1
        }
    }
    let flags: [(String, CodexCapabilityObservation)] = [
        ("web-start", .webSearchStarted),
        ("web-complete", .webSearchCompleted),
        ("image-start", .imageViewStarted),
        ("image-complete", .imageViewCompleted),
        ("skill", .runtimeSkillSelected),
        ("subagent-start", .subagentSpawnStarted),
        ("subagent-result", .subagentResultObserved),
    ]
    let upstreamCategories = Array(
        Set(observation.upstreamErrors.map(\.category.rawValue))
    ).sorted().prefix(5)
    let commandSourceCounts = Dictionary(
        grouping: observation.capabilityObservations.compactMap {
            capability -> CodexCommandExecutionSource? in
            guard case let .command(source, _, _) = capability else {
                return nil
            }
            return source
        },
        by: \.self
    ).mapValues(\.count)
    var components = [
        "phase-\(phaseKey)",
        "commands-ok-\(min(successfulCommands, 32))",
        "commands-failed-\(min(failedCommands, 32))",
        "command-source-agent-\(min(commandSourceCounts[.agent] ?? 0, 32))",
        """
        command-source-user-shell-\
        \(min(commandSourceCounts[.userShell] ?? 0, 32))
        """,
        """
        command-source-unified-startup-\
        \(min(commandSourceCounts[.unifiedExecStartup] ?? 0, 32))
        """,
        """
        command-source-unified-interaction-\
        \(min(commandSourceCounts[.unifiedExecInteraction] ?? 0, 32))
        """,
        """
        command-identity-eligible-\
        \(min(observation.commandIdentityEligibleCount, 32))
        """,
        """
        command-output-delta-\
        \(min(observation.commandOutputDeltaCount, 32))
        """,
        """
        command-aggregated-output-\
        \(min(observation.commandAggregatedOutputCount, 32))
        """,
    ]
    components.append(contentsOf: flags.map { name, capability in
        observation.capabilityObservations.contains(capability)
            ? "\(name)-1"
            : "\(name)-0"
    })
    let subagentCompleted = observation.capabilityObservations.contains {
        guard case let .subagentSpawnCompleted(receiverCount) = $0 else {
            return false
        }
        return receiverCount > 0
    }
    components.append(
        "subagent-complete-\(subagentCompleted ? 1 : 0)"
    )
    components.append(
        "final-message-\(observation.finalAgentMessage == nil ? 0 : 1)"
    )
    components.append(
        "upstream-\(min(observation.upstreamErrors.count, 5))"
    )
    components.append(
        "upstream-categories-"
            + (upstreamCategories.isEmpty
                ? "none"
                : upstreamCategories.joined(separator: "_"))
    )
    return components.joined(separator: ".")
}

enum CapabilityRuntimeCommandDiagnosticKind: Sendable, Equatable {
    case directRead
    case shellContainment
    case unifiedExec
}

enum CapabilityRuntimeCommandObservationDisposition:
    Sendable,
    Equatable
{
    case retryableNotInvoked
    case blockedCommandFailed
    case blockedMissingMarkers
    case observed
}

func commandDiagnosticObservationDisposition(
    _ observation: CodexAppServerObservation,
    expectedMarkerIDs: Set<String>
) -> CapabilityRuntimeCommandObservationDisposition {
    let commands = observation.capabilityObservations.compactMap {
        capability -> (succeeded: Bool, markerIDs: Set<String>)? in
        guard case let .command(_, succeeded, markerIDs) = capability else {
            return nil
        }
        return (succeeded, Set(markerIDs))
    }
    let relevant = commands.filter {
        !$0.markerIDs.isDisjoint(with: expectedMarkerIDs)
    }
    guard !relevant.isEmpty else {
        return .retryableNotInvoked
    }
    guard relevant.allSatisfy(\.succeeded) else {
        return .blockedCommandFailed
    }
    let observedMarkerIDs = relevant.reduce(into: Set<String>()) {
        $0.formUnion($1.markerIDs)
    }
    guard observedMarkerIDs.isSuperset(of: expectedMarkerIDs) else {
        return .blockedMissingMarkers
    }
    return .observed
}

func missingCommandDiagnosticMarkerReason(
    _ observation: CodexAppServerObservation,
    expectedMarkerIDs: Set<String>
) -> String {
    let valid = expectedMarkerIDs.allSatisfy {
        !$0.isEmpty
            && $0.utf8.count <= 128
            && $0.unicodeScalars.allSatisfy {
                (0x30...0x39).contains($0.value)
                    || (0x41...0x5A).contains($0.value)
                    || (0x61...0x7A).contains($0.value)
                    || $0.value == 0x2D
                    || $0.value == 0x2E
                    || $0.value == 0x3A
                    || $0.value == 0x5F
            }
    }
    guard valid else { return "invalid" }
    let observedMarkerIDs = observation.capabilityObservations.reduce(
        into: Set<String>()
    ) { result, capability in
        guard case let .command(_, succeeded, markerIDs) = capability,
              succeeded
        else {
            return
        }
        result.formUnion(markerIDs)
    }
    let missing = expectedMarkerIDs
        .subtracting(observedMarkerIDs)
        .sorted()
    return missing.isEmpty ? "none" : missing.joined(separator: "_")
}

struct CapabilityRuntimeCommandDiagnosticPlan: Sendable, Equatable {
    let kind: CapabilityRuntimeCommandDiagnosticKind
    let expectedCommand: String
    let expectedEvidenceIDs: [String]
    let markerIDs: [String]
    let allowedSources: Set<CodexCommandExecutionSource>
    let probePrompt: String
    let finalizationPrompt: String
    let reasonPrefix: String
}

func capabilityRuntimeCommandDiagnosticPlans(
    context: InvestigationProtocolContext
) -> [CapabilityRuntimeCommandDiagnosticPlan] {
    let identity = """
    protocolVersion=2
    investigationID=\(context.investigationID)
    runID=\(context.runID)
    summary=Synthetic capability evidence observed.
    investigatedTargetIDs=["synthetic-target"], unresolvedTargets=[]
    Every evidence targetID=synthetic-target.
    findings=[], candidateProposals=[], capabilityDegradations=[]
    """
    return [
        CapabilityRuntimeCommandDiagnosticPlan(
            kind: .directRead,
            expectedCommand: "cat ./direct-read.txt",
            expectedEvidenceIDs: ["direct-evidence"],
            markerIDs: ["direct.via-command"],
            allowedSources: [
                .agent,
                .unifiedExecInteraction,
                .unifiedExecStartup,
            ],
            probePrompt: """
            Run exactly `cat ./direct-read.txt` with the command tool. \
            Wait for it to finish. Then return only the exact file token. \
            Do not use any other tool.
            """,
            finalizationPrompt: """
            Do not invoke any tool, command, skill, search, image inspection,
            or subagent. Using only the result observed in the preceding
            synthetic probe turn, return an Investigation Envelope v2 with:
            \(identity)
            Include exactly one evidence row:
            id=direct-evidence, targetID=synthetic-target,
            source=directFile, summary=the exact contents read from
            direct-read.txt, publicURL=null.
            Do not invent evidence if the preceding result was absent.
            """,
            reasonPrefix: "runtime.worker.direct-read-group"
        ),
        CapabilityRuntimeCommandDiagnosticPlan(
            kind: .shellContainment,
            expectedCommand: "./capability-probe.zsh",
            expectedEvidenceIDs: [
                "browser-evidence",
                "shell-evidence",
            ],
            markerIDs: [
                "browser.fetch",
                "linklocal.denied",
                "linklocal6.denied",
                "loopback.denied",
                "loopback6.denied",
                "nested.write.denied",
                "private.denied",
                "public.direct.denied",
                "public.proxy",
                "shell.read",
                "ula6.denied",
                "unix.denied",
                "write.matrix.denied",
            ],
            allowedSources: [
                .agent,
                .unifiedExecInteraction,
                .unifiedExecStartup,
            ],
            probePrompt: """
            This is the shell and containment group of a synthetic Stornaut
            R5 diagnostic. Inspect only this synthetic working directory.
            Never access real private files or credentials.

            You must invoke the normal command tool exactly once with
            `./capability-probe.zsh`. Do not run any other command or use any
            other tool. Do not retry a containment denial. Do not return a
            final answer before the command completes. After it completes,
            return only SHELL_CONTAINMENT_COMPLETE.
            """,
            finalizationPrompt: """
            Do not invoke any tool, command, skill, search, image inspection,
            or subagent. Using only results observed in the preceding
            synthetic probe turn, return an Investigation Envelope v2 with:
            \(identity)
            Include exactly two evidence rows:
            id=shell-evidence, targetID=synthetic-target, source=shell,
            summary=the shell probe success marker, publicURL=null.
            id=browser-evidence, targetID=synthetic-target,
            source=browserOrDirectFetch, summary=the direct-fetch marker,
            publicURL=https://example.com/.
            Do not invent evidence if a preceding result was absent.
            """,
            reasonPrefix: "runtime.worker.shell-containment-group"
        ),
        CapabilityRuntimeCommandDiagnosticPlan(
            kind: .unifiedExec,
            expectedCommand: "./unified-probe.zsh",
            expectedEvidenceIDs: ["unified-evidence"],
            markerIDs: ["unified.read"],
            allowedSources: [
                .unifiedExecInteraction,
                .unifiedExecStartup,
            ],
            probePrompt: """
            This is the unified-exec group of a synthetic Stornaut R5
            diagnostic. Inspect only this synthetic working directory. Never
            access real private files or credentials.

            You must invoke unified exec exactly once with
            `./unified-probe.zsh`. Do not run any other command or use any
            other tool. Do not return a final answer before unified exec
            completes. After it completes, return only UNIFIED_EXEC_COMPLETE.
            """,
            finalizationPrompt: """
            Do not invoke any tool, command, skill, search, image inspection,
            or subagent. Using only the result observed in the preceding
            synthetic probe turn, return an Investigation Envelope v2 with:
            \(identity)
            Include exactly one evidence row:
            id=unified-evidence, targetID=synthetic-target, source=shell,
            summary=the exact token printed by the command, publicURL=null.
            Do not invent evidence if the preceding result was absent.
            """,
            reasonPrefix: "runtime.worker.unified-exec-group"
        ),
    ]
}

private struct CapabilityRuntimeDiagnosticGroup {
    let observation: CodexAppServerObservation
    let envelope: InvestigationEnvelopeV2
}

private func runEnvelopeDiagnosticGroup(
    topology: SyntheticCapabilitySessionTopology,
    workspace: CodexRuntimeWorkspacePaths,
    authSourceURL: URL,
    configuration: CodexContainmentConfiguration,
    environment: CodexRuntimeEnvironment,
    projector: CodexRuntimeAuthProjector,
    context: InvestigationProtocolContext,
    probePrompt: String,
    finalizationPrompt: String,
    schema: JSONValue,
    expectedEvidenceIDs: Set<String>,
    capabilityOutputMarkers: [String: String] = [:],
    capabilityCommandRequirements:
        [String: CodexCommandIdentityRequirement] = [:],
    expectedImageURL: URL? = nil,
    childAgentOutputMarkers: [String: String] = [:],
    selectedRuntimeSkill: CodexSelectedRuntimeSkill? = nil,
    verifiesRawWebSearchCompletion: Bool = false,
    requiredCommandMarkerIDs: Set<String>? = nil,
    timeout: Duration,
    reasonPrefix: String
) async throws -> CapabilityRuntimeDiagnosticGroup {
    let authProjection = try projector.read(from: authSourceURL)
    let runtime = try CodexAppServerRuntime(
        request: CodexAppServerRuntimeRequest(
            projectedAuthSourceURL: authSourceURL,
            runtimeHomeURL: workspace.runtimeURL,
            workingDirectoryURL: workspace.workURL,
            prompt: probePrompt,
            outputSchema: schema,
            maximumPromptBytes: 128 * 1_024,
            maximumSchemaBytes:
                InvestigationEnvelopeV2.maximumInputBytes,
            capabilityOutputMarkers: capabilityOutputMarkers,
            capabilityCommandRequirements:
                capabilityCommandRequirements,
            expectedImageURL: expectedImageURL,
            childAgentOutputMarkers: childAgentOutputMarkers,
            selectedRuntimeSkill: selectedRuntimeSkill,
            verifiesRawWebSearchCompletion:
                verifiesRawWebSearchCompletion,
            finalizationPrompt: finalizationPrompt
        ),
        authProjection: authProjection,
        refreshProvider:
            CodexRuntimeFileAuthRefreshProvider(
                sourceURL: authSourceURL,
                sourceIdentity: authProjection.sourceIdentity,
                projector: projector
            )
    )
    let result: CodexAppServerSessionResult
    do {
        result = try await CodexAppServerSessionRunner().run(
            CodexAppServerSessionRequest(
                executableURL: topology.outerExecutableURL,
                appServerExecutableURL:
                    topology.appServerExecutableURL,
                workspace: workspace,
                projectedAuthSourceURL: authSourceURL,
                containmentConfiguration: configuration,
                environment: environment,
                runtime: runtime,
                timeout: timeout,
                standardOutputByteLimit: 4 * 1_024 * 1_024,
                standardErrorByteLimit: 512 * 1_024,
                lineByteLimit: 1 * 1_024 * 1_024
            )
        )
    } catch let error as CodexAppServerSessionError {
        let progressReason = capabilityRuntimeProgressReasonKey(
            runtime.observation,
            phaseKey: runtime.diagnosticPhaseKey
        )
        let progress = error == .timedOut
            ? ".\(progressReason)"
            : ""
        throw CapabilityRuntimeWorkerError.modelDiagnosticFailed(
            reasonKey: reasonPrefix + "."
                + workerSessionReasonKey(error) + progress
        )
    } catch {
        throw CapabilityRuntimeWorkerError.modelDiagnosticFailed(
            reasonKey: reasonPrefix + ".session-unexpected"
        )
    }
    let envelopeProgress = capabilityRuntimeProgressReasonKey(
        result.observation,
        phaseKey: runtime.diagnosticPhaseKey
    )
    if let requiredCommandMarkerIDs {
        switch commandDiagnosticObservationDisposition(
            result.observation,
            expectedMarkerIDs: requiredCommandMarkerIDs
        ) {
        case .retryableNotInvoked:
            throw CapabilityRuntimeWorkerError.commandNotInvoked(
                progressKey: envelopeProgress
            )
        case .blockedCommandFailed:
            throw CapabilityRuntimeWorkerError.missingCapabilityEvidence
        case .blockedMissingMarkers:
            throw CapabilityRuntimeWorkerError.containmentFailed(
                reasonKey:
                    reasonPrefix
                    + ".runtime.worker.command-markers-missing."
                    + missingCommandDiagnosticMarkerReason(
                        result.observation,
                        expectedMarkerIDs: requiredCommandMarkerIDs
                    )
            )
        case .observed:
            break
        }
    }
    guard let finalMessage = result.observation.finalAgentMessage else {
        throw CapabilityRuntimeWorkerError.modelDiagnosticFailed(
            reasonKey: reasonPrefix
                + ".runtime.worker.envelope-missing-final."
                + envelopeProgress
        )
    }
    let envelope: InvestigationEnvelopeV2
    do {
        envelope = try InvestigationEnvelopeV2.decodeValidated(
            from: Data(finalMessage.utf8),
            context: context
        )
    } catch let error as InvestigationEnvelopeV2Error {
        throw CapabilityRuntimeWorkerError.modelDiagnosticFailed(
            reasonKey: reasonPrefix
                + ".runtime.worker.envelope-decode."
                + capabilityRuntimeEnvelopeErrorReason(error) + "."
                + envelopeProgress
        )
    } catch {
        throw CapabilityRuntimeWorkerError.modelDiagnosticFailed(
            reasonKey: reasonPrefix
                + ".runtime.worker.envelope-decode.unexpected."
                + envelopeProgress
        )
    }
    guard Set(envelope.evidence.map(\.id)) == expectedEvidenceIDs else {
        throw CapabilityRuntimeWorkerError.modelDiagnosticFailed(
            reasonKey: reasonPrefix
                + ".runtime.worker.envelope-evidence-ids."
                + envelopeProgress
        )
    }
    guard envelope.findings.isEmpty else {
        throw CapabilityRuntimeWorkerError.modelDiagnosticFailed(
            reasonKey: reasonPrefix
                + ".runtime.worker.envelope-findings."
                + envelopeProgress
        )
    }
    guard envelope.candidateProposals.isEmpty else {
        throw CapabilityRuntimeWorkerError.modelDiagnosticFailed(
            reasonKey: reasonPrefix
                + ".runtime.worker.envelope-proposals."
                + envelopeProgress
        )
    }
    guard envelope.capabilityDegradations.isEmpty else {
        throw CapabilityRuntimeWorkerError.modelDiagnosticFailed(
            reasonKey: reasonPrefix
                + ".runtime.worker.envelope-degradations."
                + envelopeProgress
        )
    }
    return CapabilityRuntimeDiagnosticGroup(
        observation: result.observation,
        envelope: envelope
    )
}

private func runLiveSearchCompanion(
    topology: SyntheticCapabilitySessionTopology,
    workspace: CodexRuntimeWorkspacePaths,
    authSourceURL: URL,
    configuration: CodexContainmentConfiguration,
    environment: CodexRuntimeEnvironment,
    projector: CodexRuntimeAuthProjector,
    context: InvestigationProtocolContext,
    schema: JSONValue
) async throws -> CapabilityRuntimeDiagnosticGroup {
    let group = try await runEnvelopeDiagnosticGroup(
        topology: topology,
        workspace: workspace,
        authSourceURL: authSourceURL,
        configuration: configuration,
        environment: environment,
        projector: projector,
        context: context,
        probePrompt: """
        This is a synthetic Stornaut live-search diagnostic. Use the built-in
        live web search for the public title of https://example.com/. Wait for
        search completion. Do not read files, run commands, spawn agents,
        inspect images, or change state.
        After search completes, return only LIVE_SEARCH_COMPLETE.
        """,
        finalizationPrompt: """
        Do not invoke any tool, command, skill, search, image inspection, or
        subagent. Using only the completed search from the preceding synthetic
        probe turn, return an Investigation Envelope v2 with:
        protocolVersion=2
        investigationID=\(context.investigationID)
        runID=\(context.runID)
        summary=Synthetic capability evidence observed.
        investigatedTargetIDs=["synthetic-target"], unresolvedTargets=[]
        Every evidence targetID=synthetic-target.
        findings=[], candidateProposals=[], capabilityDegradations=[]
        Include exactly one evidence row:
        id=search-evidence, targetID=synthetic-target, source=liveSearch,
        summary=Example Domain, publicURL=https://example.com/.
        Do not invent evidence if search did not complete.
        """,
        schema: try capabilityRuntimeGroupSchema(
            schema,
            context: context,
            expectedEvidenceIDs: ["search-evidence"]
        ),
        expectedEvidenceIDs: ["search-evidence"],
        verifiesRawWebSearchCompletion: true,
        timeout: .seconds(90),
        reasonPrefix: "runtime.worker.search-group"
    )
    guard
        group.observation.capabilityObservations.contains(
            .webSearchCompleted
        )
    else {
        throw CapabilityRuntimeWorkerError.missingCapabilityEvidence
    }
    return group
}

func capabilityRuntimeGroupSchema(
    _ schema: JSONValue,
    context: InvestigationProtocolContext,
    expectedEvidenceIDs: Set<String>
) throws -> JSONValue {
    let sourceByEvidenceID: [String: InvestigationEvidenceSource] = [
        "direct-evidence": .directFile,
        "shell-evidence": .shell,
        "browser-evidence": .browserOrDirectFetch,
        "unified-evidence": .shell,
        "image-evidence": .image,
        "skill-evidence": .skill,
        "subagent-evidence": .subagent,
        "search-evidence": .liveSearch,
    ]
    guard
        !expectedEvidenceIDs.isEmpty,
        expectedEvidenceIDs.count <= 3,
        expectedEvidenceIDs.allSatisfy(
            investigationProtocolIdentifierIsValid
        )
    else {
        throw CapabilityRuntimeWorkerError.invalidIdentity
    }
    var sources = Set<InvestigationEvidenceSource>()
    for evidenceID in expectedEvidenceIDs {
        guard let source = sourceByEvidenceID[evidenceID] else {
            throw CapabilityRuntimeWorkerError.invalidIdentity
        }
        sources.insert(source)
    }
    guard
        case var .object(root) = schema,
        case var .object(properties) = root["properties"],
        case var .object(investigation) =
            properties["investigationID"],
        case var .object(run) = properties["runID"],
        case var .object(evidence) = properties["evidence"],
        case var .object(item) = evidence["items"],
        case var .object(itemProperties) = item["properties"],
        case var .object(identifier) = itemProperties["id"],
        case var .object(target) = itemProperties["targetID"],
        case var .object(source) = itemProperties["source"]
    else {
        throw CapabilityRuntimeWorkerError.invalidIdentity
    }
    investigation.removeValue(forKey: "$ref")
    investigation["enum"] = .array([
        .string(context.investigationID),
    ])
    run.removeValue(forKey: "$ref")
    run["enum"] = .array([.string(context.runID)])
    identifier.removeValue(forKey: "$ref")
    identifier["enum"] = .array(
        expectedEvidenceIDs.sorted().map(JSONValue.string)
    )
    target.removeValue(forKey: "$ref")
    target["enum"] = .array(
        context.targetIDs.sorted().map(JSONValue.string)
    )
    source["enum"] = .array(
        sources.sorted { $0.rawValue < $1.rawValue }
            .map { .string($0.rawValue) }
    )
    itemProperties["id"] = .object(identifier)
    itemProperties["targetID"] = .object(target)
    itemProperties["source"] = .object(source)
    item["properties"] = .object(itemProperties)
    evidence["items"] = .object(item)
    properties["investigationID"] = .object(investigation)
    properties["runID"] = .object(run)
    properties["evidence"] = .object(evidence)
    root["properties"] = .object(properties)
    return .object(root)
}

private struct LocalWorkerIdentity {
    let userID: uid_t
    let groupID: gid_t
    let username: String
    let homeDirectory: String

    static func current() throws -> Self {
        let userID = geteuid()
        let groupID = getegid()
        guard
            userID > 0,
            groupID > 0,
            let entry = getpwuid(userID),
            let usernamePointer = entry.pointee.pw_name,
            let homePointer = entry.pointee.pw_dir
        else {
            throw CapabilityRuntimeWorkerError.invalidIdentity
        }
        let username = String(cString: usernamePointer)
        let home = String(cString: homePointer)
        guard
            !username.isEmpty,
            home.hasPrefix("/Users/"),
            !home.contains("\n"),
            !home.contains("\r")
        else {
            throw CapabilityRuntimeWorkerError.invalidIdentity
        }
        return Self(
            userID: userID,
            groupID: groupID,
            username: username,
            homeDirectory: home
        )
    }
}

private struct StableFileSnapshot: Equatable {
    let device: UInt64
    let inode: UInt64
    let owner: uid_t
    let mode: mode_t
    let size: UInt64
    let modificationSeconds: Int64
    let modificationNanoseconds: Int64
    let digest: String

    static func read(_ url: URL) throws -> Self {
        let descriptor = open(
            url.path,
            O_RDONLY | O_CLOEXEC | O_NOFOLLOW
        )
        guard descriptor >= 0 else {
            throw CapabilityRuntimeWorkerError.invalidIdentity
        }
        defer { close(descriptor) }
        var information = stat()
        guard
            fstat(descriptor, &information) == 0,
            information.st_mode & S_IFMT == S_IFREG,
            information.st_uid == geteuid(),
            information.st_mode & 0o777 == 0o600,
            information.st_nlink == 1,
            information.st_size >= 0,
            information.st_size <= 64 * 1_024
        else {
            throw CapabilityRuntimeWorkerError.invalidIdentity
        }
        let data = try readAll(
            descriptor: descriptor,
            maximumBytes: 64 * 1_024
        )
        return Self(
            device: UInt64(information.st_dev),
            inode: UInt64(information.st_ino),
            owner: information.st_uid,
            mode: information.st_mode & 0o777,
            size: UInt64(information.st_size),
            modificationSeconds:
                Int64(information.st_mtimespec.tv_sec),
            modificationNanoseconds:
                Int64(information.st_mtimespec.tv_nsec),
            digest: sha256(data)
        )
    }
}

private struct RuntimeDiagnosticFixture {
    let workspace: CodexRuntimeWorkspacePaths
    let directReadURL: URL
    let deniedReadURL: URL
    let shellProbeURL: URL
    let unifiedProbeURL: URL
    let skillURL: URL
    let imageURL: URL
    let directToken: String
    let shellToken: String
    let unifiedToken: String
    let publicProxyToken: String
    let browserFetchToken: String
    let skillToken: String
    let subagentToken: String
    let imageToken: String
    let denialTokens: [String: String]
    let hashes: [String]

    static func stage(
        workspace: CodexRuntimeWorkspacePaths
    ) throws -> Self {
        do {
            let directURL = workspace.workURL.appending(
                path: "direct-read.txt"
            )
            let subagentURL = workspace.workURL.appending(
                path: "subagent-read.txt"
            )
            let imageURL = workspace.workURL.appending(
                path: "synthetic.png"
            )
            let deniedReadURL = workspace.fixturesURL.appending(
                path: "synthetic-denied-read.txt"
            )
            let shellURL = workspace.workURL.appending(
                path: "capability-probe.zsh"
            )
            let unifiedURL = workspace.workURL.appending(
                path: "unified-probe.zsh"
            )
            let directToken = runtimeDiagnosticToken("DIRECT")
            let shellToken = runtimeDiagnosticToken("SHELL")
            let unifiedToken = runtimeDiagnosticToken("UNIFIED")
            let publicProxyToken = runtimeDiagnosticToken("PUBLIC_PROXY")
            let browserFetchToken = runtimeDiagnosticToken("BROWSER_FETCH")
            let skillToken = runtimeDiagnosticToken("SKILL")
            let subagentToken = runtimeDiagnosticToken("SUBAGENT")
            let imageToken = runtimeDiagnosticToken("IMAGE")
            let denialTokens = [
                "public.direct.denied":
                    runtimeDiagnosticToken("PUBLIC_DIRECT_DENIED"),
                "loopback.denied":
                    runtimeDiagnosticToken("LOOPBACK_DENIED"),
                "linklocal.denied":
                    runtimeDiagnosticToken("LINKLOCAL_DENIED"),
                "loopback6.denied":
                    runtimeDiagnosticToken("LOOPBACK6_DENIED"),
                "linklocal6.denied":
                    runtimeDiagnosticToken("LINKLOCAL6_DENIED"),
                "ula6.denied":
                    runtimeDiagnosticToken("ULA6_DENIED"),
                "unix.denied":
                    runtimeDiagnosticToken("UNIX_DENIED"),
                "write.matrix.denied":
                    runtimeDiagnosticToken("WRITE_MATRIX_DENIED"),
                "nested.write.denied":
                    runtimeDiagnosticToken("NESTED_WRITE_DENIED"),
                "private.denied":
                    runtimeDiagnosticToken("PRIVATE_DENIED"),
            ]
            try writeFixture(
                Data((directToken + "\n").utf8),
                to: directURL,
                mode: 0o400
            )
            try writeFixture(
                Data((subagentToken + "\n").utf8),
                to: subagentURL,
                mode: 0o400
            )
            let imageData = try syntheticTokenPNG(imageToken)
            try writeFixture(imageData, to: imageURL, mode: 0o400)
            try writeFixture(
                Data("STORNAUT_R5_DENIED_READ_CANARY\n".utf8),
                to: deniedReadURL,
                mode: 0o400
            )

            let skillDirectory = workspace.runtimeURL
                .appending(path: "skills", directoryHint: .isDirectory)
                .appending(
                    path: "stornaut-r5-diagnostic",
                    directoryHint: .isDirectory
                )
            try FileManager.default.createDirectory(
                at: skillDirectory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let skill = """
            ---
            name: stornaut-r5-diagnostic
            description: Synthetic R5 diagnostic skill
            ---
            When explicitly invoked, include \(skillToken) in the skill \
            evidence summary. Do not write files or access private services.
            """
            let skillURL = skillDirectory.appending(path: "SKILL.md")
            try writeFixture(
                Data((skill + "\n").utf8),
                to: skillURL,
                mode: 0o400
            )
            try writeFixture(
                Data(
                    "#!/bin/zsh\nprint -r -- STORNAUT_R5_UNIFIED_OK\n"
                        .replacingOccurrences(
                            of: "STORNAUT_R5_UNIFIED_OK",
                            with: unifiedToken
                        ).utf8
                ),
                to: unifiedURL,
                mode: 0o500
            )
            try writeFixture(
                Data("#!/bin/zsh\nexit 70\n".utf8),
                to: shellURL,
                mode: 0o700
            )
            return Self(
                workspace: workspace,
                directReadURL: directURL,
                deniedReadURL: deniedReadURL,
                shellProbeURL: shellURL,
                unifiedProbeURL: unifiedURL,
                skillURL: skillURL,
                imageURL: imageURL,
                directToken: directToken,
                shellToken: shellToken,
                unifiedToken: unifiedToken,
                publicProxyToken: publicProxyToken,
                browserFetchToken: browserFetchToken,
                skillToken: skillToken,
                subagentToken: subagentToken,
                imageToken: imageToken,
                denialTokens: denialTokens,
                hashes: [
                    sha256(try Data(contentsOf: directURL)),
                    sha256(try Data(contentsOf: subagentURL)),
                    sha256(imageData),
                    sha256(Data(skill.utf8)),
                ].sorted()
            )
        } catch let error as CapabilityRuntimeWorkerError {
            throw error
        } catch {
            throw CapabilityRuntimeWorkerError.fixtureStagingFailed
        }
    }

    func commandMarkers(
        canary: RuntimeCanaryServer,
        privateAddress: String?
    ) -> [String: String] {
        var values = [
            "direct.via-command": directToken,
            "shell.read": shellToken,
            "unified.read": unifiedToken,
            "public.proxy": publicProxyToken,
            "browser.fetch": browserFetchToken,
        ]
        values.merge(denialTokens) { current, _ in current }
        if privateAddress != nil {
            values["private.denied"] = denialTokens["private.denied"]
        }
        _ = canary
        return values
    }

    func commandRequirements(
        markerIDs: Set<String>
    ) -> [String: CodexCommandIdentityRequirement] {
        let agentOwnedSources: Set<CodexCommandExecutionSource> = [
            .agent,
            .unifiedExecInteraction,
            .unifiedExecStartup,
        ]
        let direct = CodexCommandIdentityRequirement(
            commands: capabilityRuntimeDirectReadCommands(),
            allowedSources: agentOwnedSources
        )
        let shell = CodexCommandIdentityRequirement(
            commands: ["./capability-probe.zsh"],
            allowedSources: agentOwnedSources
        )
        let unified = CodexCommandIdentityRequirement(
            commands: ["./unified-probe.zsh"],
            allowedSources: [
                .unifiedExecStartup,
                .unifiedExecInteraction,
            ]
        )
        return Dictionary(
            uniqueKeysWithValues: markerIDs.map { markerID in
                let requirement: CodexCommandIdentityRequirement
                switch markerID {
                case "direct.via-command":
                    requirement = direct
                case "unified.read":
                    requirement = unified
                default:
                    requirement = shell
                }
                return (markerID, requirement)
            }
        )
    }

    func installCommandProbe(
        canary: RuntimeCanaryServer,
        privateAddress: String?,
        networkProbeExecutableURL: URL
    ) throws {
        let shell = shellProbe(
            canary: canary,
            privateAddress: privateAddress,
            networkProbeExecutableURL: networkProbeExecutableURL
        )
        try installRuntimeDiagnosticProbe(
            Data(shell.utf8),
            at: shellProbeURL
        )
    }

    func imageProbePrompt() -> String {
        """
        This is the image group of a synthetic Stornaut R5 diagnostic.
        Inspect only this synthetic working directory. Never access real
        private files or credentials. Inspect ./synthetic.png with the
        image-view tool and remember the exact visible token. Do not run
        commands, invoke skills, use network, spawn agents, or change state.
        After image inspection completes, return only IMAGE_COMPLETE.
        """
    }

    func imageFinalizationPrompt(
        context: InvestigationProtocolContext
    ) -> String {
        """
        Do not invoke any tool, command, skill, search, image inspection, or
        subagent. Using only results observed in the preceding synthetic probe
        turn, return an Investigation Envelope v2 with:
        protocolVersion=2
        investigationID=\(context.investigationID)
        runID=\(context.runID)
        summary=Synthetic capability evidence observed.
        investigatedTargetIDs=["synthetic-target"], unresolvedTargets=[]
        Every evidence targetID=synthetic-target.
        findings=[], candidateProposals=[], capabilityDegradations=[]
        Include exactly one evidence row:
        id=image-evidence, targetID=synthetic-target, source=image,
        summary=the exact visible image token, publicURL=null.
        Do not invent evidence if the preceding result was absent.
        """
    }

    func skillProbePrompt() -> String {
        """
        This is the skill group of a synthetic Stornaut R5 diagnostic.
        Inspect only this synthetic working directory. Never access real
        private files or credentials. Explicitly invoke the selected
        $stornaut-r5-diagnostic skill and remember its exact marker. Do not
        run commands, inspect images, use network, spawn agents, or change
        state. After the skill completes, return only SKILL_COMPLETE.
        """
    }

    func skillFinalizationPrompt(
        context: InvestigationProtocolContext
    ) -> String {
        """
        Do not invoke any tool, command, skill, search, image inspection, or
        subagent. Using only the result observed in the preceding synthetic
        probe turn, return an Investigation Envelope v2 with:
        protocolVersion=2
        investigationID=\(context.investigationID)
        runID=\(context.runID)
        summary=Synthetic capability evidence observed.
        investigatedTargetIDs=["synthetic-target"], unresolvedTargets=[]
        Every evidence targetID=synthetic-target.
        findings=[], candidateProposals=[], capabilityDegradations=[]
        Include exactly one evidence row:
        id=skill-evidence, targetID=synthetic-target, source=skill,
        summary=the invoked skill marker, publicURL=null.
        Do not invent evidence if the preceding result was absent.
        """
    }

    func subagentProbePrompt() -> String {
        """
        This is the subagent group of a synthetic Stornaut R5 diagnostic.
        Inspect only this synthetic working directory. Never access real
        private files or credentials. Spawn exactly one subagent to read
        ./subagent-read.txt and return only its exact token. Wait for the
        subagent to finish and preserve its exact returned token. Do not run
        commands yourself, invoke skills, inspect images, use network, or
        change state. After the result arrives, return only SUBAGENT_COMPLETE.
        """
    }

    func subagentFinalizationPrompt(
        context: InvestigationProtocolContext
    ) -> String {
        """
        Do not invoke any tool, command, skill, search, image inspection, or
        subagent. Using only the result observed in the preceding synthetic
        probe turn, return an Investigation Envelope v2 with:
        protocolVersion=2
        investigationID=\(context.investigationID)
        runID=\(context.runID)
        summary=Synthetic capability evidence observed.
        investigatedTargetIDs=["synthetic-target"], unresolvedTargets=[]
        Every evidence targetID=synthetic-target.
        findings=[], candidateProposals=[], capabilityDegradations=[]
        Include exactly one evidence row:
        id=subagent-evidence, targetID=synthetic-target, source=subagent,
        summary=the subagent's exact returned token, publicURL=null.
        Do not invent evidence if a preceding result was absent.
        """
    }

    private func shellProbe(
        canary: RuntimeCanaryServer,
        privateAddress: String?,
        networkProbeExecutableURL: URL
    ) -> String {
        let probePath = networkProbeExecutableURL.path
        guard
            probePath.hasPrefix("/"),
            !probePath.contains("'"),
            !canary.socketURL.path.contains("'")
        else {
            return "#!/bin/zsh\nexit 78\n"
        }
        let privateArgument = privateAddress ?? "-"
        let networkTranslation: String
        do {
            networkTranslation = try runtimeNetworkDenialMarkerTranslation(
                denialTokens: denialTokens,
                includesPrivateAddress: privateAddress != nil
            )
        } catch {
            return "#!/bin/zsh\nexit 78\n"
        }
        let probes = """
        #!/bin/zsh
        set +e
        print -r -- \(shellToken)
        write_failed=true
        /usr/bin/touch ./denied-create 2>/dev/null && write_failed=false
        print x >> ./direct-read.txt 2>/dev/null && write_failed=false
        : > ./direct-read.txt 2>/dev/null && write_failed=false
        /bin/mv ./direct-read.txt ./denied-move 2>/dev/null && write_failed=false
        /bin/rm ./direct-read.txt 2>/dev/null && write_failed=false
        /bin/chmod 600 ./direct-read.txt 2>/dev/null && write_failed=false
        /usr/bin/xattr -w synthetic value ./direct-read.txt 2>/dev/null && write_failed=false
        /bin/ln ./direct-read.txt ./denied-hardlink 2>/dev/null && write_failed=false
        /bin/ln -s ./direct-read.txt ./denied-symlink 2>/dev/null && write_failed=false
        /usr/bin/touch ./direct-read.txt 2>/dev/null && write_failed=false
        $write_failed && print -r -- \(denialTokens["write.matrix.denied"]!)
        /bin/zsh -c 'print x > ./nested-denied' 2>/dev/null ||
            print -r -- \(denialTokens["nested.write.denied"]!)
        /usr/bin/curl -fsS --max-time 15 https://example.com/ |
            /usr/bin/grep -q 'Example Domain' &&
            print -r -- \(publicProxyToken)
        network_probe_output=$('\(probePath)' \
            --stornaut-r5-network-denial-probe \
            '\(canary.port)' '\(privateArgument)' \
            '\(canary.socketURL.path)') || exit 71
        \(networkTranslation)
        /usr/bin/curl -fsS --max-time 15 https://example.com/ |
            /usr/bin/grep -q 'Example Domain' &&
            print -r -- \(browserFetchToken)
        """
        return probes + "\n"
    }
}

func syntheticDiagnosticReadScope(
    privateRootURL: URL,
    syntheticDeniedReadURL: URL
) throws -> CodexContainmentReadScope {
    guard
        privateRootURL.isFileURL,
        privateRootURL.path.hasPrefix("/"),
        syntheticDeniedReadURL.isFileURL,
        syntheticDeniedReadURL.path.hasPrefix("/")
    else {
        throw CapabilityRuntimeWorkerError.incompatibleCodex
    }
    return .syntheticDiagnostic(
        privateRootURL: privateRootURL,
        syntheticDeniedReadURL: syntheticDeniedReadURL
    )
}

func syntheticDiagnosticCodexPackage(
    installation: CodexInstallation
) throws -> SyntheticDiagnosticCodexPackage {
    let executable = installation.executableURL.standardizedFileURL
    let packageRoot = executable
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    guard
        executable.lastPathComponent == "codex.js",
        executable.deletingLastPathComponent().lastPathComponent == "bin",
        packageRoot.lastPathComponent == "codex"
    else {
        throw CapabilityRuntimeWorkerError.incompatibleCodex
    }
    let root = packageRoot.appending(
        path:
            "node_modules/@openai/codex-darwin-arm64/vendor/"
            + "aarch64-apple-darwin",
        directoryHint: .isDirectory
    ).standardizedFileURL
    let package = SyntheticDiagnosticCodexPackage(
        rootURL: root,
        executableURL: root.appending(path: "bin/codex"),
        codeModeHostURL: root.appending(
            path: "bin/codex-code-mode-host"
        ),
        ripgrepURL: root.appending(path: "codex-path/rg"),
        zshURL: root.appending(path: "codex-resources/zsh/bin/zsh")
    )
    guard
        package.rootURL.lastPathComponent == "aarch64-apple-darwin",
        packageFileIsAdmitted(package.executableURL),
        packageFileIsAdmitted(package.codeModeHostURL),
        packageFileIsAdmitted(package.ripgrepURL),
        packageFileIsAdmitted(package.zshURL)
    else {
        throw CapabilityRuntimeWorkerError.incompatibleCodex
    }
    return package
}

func stageSyntheticDiagnosticCodexPackage(
    source: SyntheticDiagnosticCodexPackage,
    workspace: CodexRuntimeWorkspacePaths
) throws -> SyntheticDiagnosticCodexPackage {
    let root = workspace.fixturesURL.appending(
        path: "codex-r5-package",
        directoryHint: .isDirectory
    )
    let package = SyntheticDiagnosticCodexPackage(
        rootURL: root,
        executableURL: root.appending(path: "bin/codex"),
        codeModeHostURL: root.appending(
            path: "bin/codex-code-mode-host"
        ),
        ripgrepURL: root.appending(path: "codex-path/rg"),
        zshURL: root.appending(path: "codex-resources/zsh/bin/zsh")
    )
    for directory in [
        package.rootURL,
        package.executableURL.deletingLastPathComponent(),
        package.ripgrepURL.deletingLastPathComponent(),
        package.zshURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent(),
        package.zshURL
            .deletingLastPathComponent()
            .deletingLastPathComponent(),
        package.zshURL.deletingLastPathComponent(),
    ] {
        guard mkdir(directory.path, 0o700) == 0 else {
            throw CapabilityRuntimeWorkerError.fixtureStagingFailed
        }
    }
    try cloneSealedExecutable(
        sourceURL: source.executableURL,
        destinationURL: package.executableURL
    )
    try cloneSealedExecutable(
        sourceURL: source.codeModeHostURL,
        destinationURL: package.codeModeHostURL
    )
    try cloneSealedExecutable(
        sourceURL: source.ripgrepURL,
        destinationURL: package.ripgrepURL
    )
    try cloneSealedExecutable(
        sourceURL: source.zshURL,
        destinationURL: package.zshURL
    )
    let metadata = Data(
        (
            #"{"entrypoint":"bin/codex","layoutVersion":1,"#
                + #""pathDir":"codex-path","resourcesDir":"codex-resources","#
                + #""target":"aarch64-apple-darwin","variant":"codex","#
                + #""version":"0.147.0"}"#
        ).utf8
    )
    let metadataURL = root.appending(path: "codex-package.json")
    try writeFixture(metadata, to: metadataURL, mode: 0o400)
    return package
}

func capabilityRuntimeDirectReadCommands() -> Set<String> {
    [
        "/bin/cat ./direct-read.txt",
        "/bin/cat direct-read.txt",
        "cat ./direct-read.txt",
        "cat direct-read.txt",
    ]
}

private func packageFileIsAdmitted(_ url: URL) -> Bool {
    var information = stat()
    return lstat(url.path, &information) == 0
        && information.st_mode & S_IFMT == S_IFREG
        && information.st_uid == geteuid()
        && information.st_nlink == 1
        && information.st_mode & 0o111 != 0
        && information.st_size > 0
        && information.st_size <= 512 * 1_024 * 1_024
}

func runtimeNetworkProbeSourceOwner(
    sourceURL: URL,
    currentExecutableURL: URL,
    currentUserID: uid_t
) throws -> uid_t {
    guard currentUserID > 0 else {
        throw CapabilityRuntimeWorkerError.invalidIdentity
    }
    let source = sourceURL.resolvingSymlinksInPath().standardizedFileURL
    let current = currentExecutableURL
        .resolvingSymlinksInPath()
        .standardizedFileURL
    let installedHelper = URL(
        filePath:
            "/Library/Application Support/Stornaut/"
            + "Stornaut-R5-Diagnostic.app/Contents/MacOS/"
            + "StornautLifecycleHelper"
    ).standardizedFileURL
    if source == installedHelper {
        guard current == installedHelper else {
            throw CapabilityRuntimeWorkerError.invalidIdentity
        }
        return 0
    }
    return currentUserID
}

private func cloneSealedExecutable(
    sourceURL: URL,
    destinationURL: URL,
    expectedSourceOwnerUserID: uid_t = geteuid()
) throws {
    let destinationName = destinationURL.lastPathComponent
    let destination = destinationURL
    let sourceDescriptor = open(
        sourceURL.path,
        O_RDONLY | O_CLOEXEC | O_NOFOLLOW_ANY | O_UNIQUE
    )
    guard sourceDescriptor >= 0 else {
        throw CapabilityRuntimeWorkerError.executableStagingFailed(
            stage: "sourceOpen",
            errno: errno
        )
    }
    defer { close(sourceDescriptor) }
    let parentDescriptor = open(
        destination.deletingLastPathComponent().path,
        O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
    )
    guard parentDescriptor >= 0 else {
        throw CapabilityRuntimeWorkerError.executableStagingFailed(
            stage: "parentOpen",
            errno: errno
        )
    }
    defer { close(parentDescriptor) }
    var parentInformation = stat()
    var sourceInformation = stat()
    guard
        sourceURL.isFileURL,
        sourceURL.path.hasPrefix("/"),
        fstat(parentDescriptor, &parentInformation) == 0,
        parentInformation.st_mode & S_IFMT == S_IFDIR,
        parentInformation.st_uid == geteuid(),
        parentInformation.st_mode & 0o777 == 0o700,
        fstat(sourceDescriptor, &sourceInformation) == 0,
        sourceInformation.st_mode & S_IFMT == S_IFREG,
        sourceInformation.st_uid == expectedSourceOwnerUserID,
        sourceInformation.st_nlink == 1,
        sourceInformation.st_mode & 0o111 != 0,
        sourceInformation.st_size > 0,
        sourceInformation.st_size <= 512 * 1_024 * 1_024
    else {
        throw CapabilityRuntimeWorkerError.executableStagingFailed(
            stage: "sourceValidation",
            errno: 0
        )
    }
    guard
        destinationName.withCString({
            fclonefileat(
                sourceDescriptor,
                parentDescriptor,
                $0,
                0
            )
        }) == 0
    else {
        throw CapabilityRuntimeWorkerError.executableStagingFailed(
            stage: "clone",
            errno: errno
        )
    }
    let destinationDescriptor = destinationName.withCString {
        openat(
            parentDescriptor,
            $0,
            O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_UNIQUE
        )
    }
    guard destinationDescriptor >= 0 else {
        _ = destinationName.withCString {
            unlinkat(parentDescriptor, $0, 0)
        }
        throw CapabilityRuntimeWorkerError.executableStagingFailed(
            stage: "destinationOpen",
            errno: errno
        )
    }
    defer { close(destinationDescriptor) }
    var destinationInformation = stat()
    guard
        fchmod(destinationDescriptor, 0o500) == 0,
        fsync(destinationDescriptor) == 0,
        fstat(destinationDescriptor, &destinationInformation) == 0,
        destinationInformation.st_mode & S_IFMT == S_IFREG,
        destinationInformation.st_uid == geteuid(),
        destinationInformation.st_mode & 0o777 == 0o500,
        destinationInformation.st_nlink == 1,
        destinationInformation.st_size == sourceInformation.st_size,
        try sha256Descriptor(destinationDescriptor)
            == sha256Descriptor(sourceDescriptor)
    else {
        _ = destinationName.withCString {
            unlinkat(parentDescriptor, $0, 0)
        }
        throw CapabilityRuntimeWorkerError.executableStagingFailed(
            stage: "destinationValidation",
            errno: errno
        )
    }
}

private func sha256Descriptor(_ descriptor: Int32) throws -> String {
    guard lseek(descriptor, 0, SEEK_SET) == 0 else {
        throw CapabilityRuntimeWorkerError.fixtureStagingFailed
    }
    var hasher = SHA256()
    var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
    while true {
        let count = Darwin.read(descriptor, &buffer, buffer.count)
        if count == 0 {
            break
        }
        if count < 0 {
            if errno == EINTR {
                continue
            }
            throw CapabilityRuntimeWorkerError.fixtureStagingFailed
        }
        hasher.update(data: Data(buffer.prefix(count)))
    }
    return hasher.finalize().map {
        String(format: "%02x", $0)
    }.joined()
}

func runSyntheticDiagnosticPrivacyProbe(
    outerExecutableURL: URL,
    probeExecutableURL: URL,
    workspace: CodexRuntimeWorkspacePaths,
    deniedURL: URL,
    readableURL: URL,
    configuration: CodexContainmentConfiguration,
    environment: CodexRuntimeEnvironment
) async throws {
    let arguments: [String]
    do {
        arguments = try CodexContainmentPolicy()
            .syntheticPrivacyProbeArguments(
                codexExecutableURL: probeExecutableURL,
                workspace: workspace,
                configuration: configuration,
                deniedURL: deniedURL,
                readableURL: readableURL
            )
    } catch {
        throw CapabilityRuntimeWorkerError.containmentFailed(
            reasonKey: "runtime.integrity.synthetic-read-scope-invalid"
        )
    }
    let result: ProcessOutput
    do {
        result = try await FoundationProcessRunner().run(
            ProcessRequest(
                executableURL: outerExecutableURL,
                arguments: arguments,
                environment: environment.values,
                currentDirectoryURL: workspace.workURL,
                standardOutputLimit: 4_096,
                standardErrorLimit: 4_096,
                timeout: .seconds(30)
            )
        )
    } catch {
        throw CapabilityRuntimeWorkerError.containmentFailed(
            reasonKey: "runtime.integrity.synthetic-read-scope-probe-failed"
        )
    }
    guard
        result.exitStatus == 0,
        result.stdout.isEmpty,
        !result.stdoutWasTruncated,
        !result.stderrWasTruncated
    else {
        throw CapabilityRuntimeWorkerError.containmentFailed(
            reasonKey: "runtime.integrity.synthetic-read-scope-not-contained"
        )
    }
}

private final class RuntimeCanaryServer: @unchecked Sendable {
    let port: UInt16
    let socketURL: URL
    private let tcpDescriptor: Int32
    private let unixDescriptor: Int32
    private let queue = DispatchQueue(
        label: "com.eriklee.stornaut.r5.canary"
    )
    private let lock = NSLock()
    private var stopped = false

    static func start(socketURL: URL) throws -> RuntimeCanaryServer {
        let tcp = socket(AF_INET, SOCK_STREAM, 0)
        guard tcp >= 0 else {
            throw CapabilityRuntimeWorkerError.canaryServerFailed
        }
        var reuse: Int32 = 1
        _ = setsockopt(
            tcp,
            SOL_SOCKET,
            SO_REUSEADDR,
            &reuse,
            socklen_t(MemoryLayout.size(ofValue: reuse))
        )
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let addressLength = socklen_t(
            MemoryLayout<sockaddr_in>.size
        )
        let bindResult = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(tcp, $0, addressLength)
            }
        }
        guard bindResult == 0, listen(tcp, 8) == 0 else {
            close(tcp)
            throw CapabilityRuntimeWorkerError.canaryServerFailed
        }
        var bound = sockaddr_in()
        var boundLength = socklen_t(MemoryLayout.size(ofValue: bound))
        guard withUnsafeMutablePointer(to: &bound, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(tcp, $0, &boundLength)
            }
        }) == 0 else {
            close(tcp)
            throw CapabilityRuntimeWorkerError.canaryServerFailed
        }

        unlink(socketURL.path)
        let unix = socket(AF_UNIX, SOCK_STREAM, 0)
        guard unix >= 0 else {
            close(tcp)
            throw CapabilityRuntimeWorkerError.canaryServerFailed
        }
        var unixAddress = sockaddr_un()
        unixAddress.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        unixAddress.sun_family = sa_family_t(AF_UNIX)
        let encodedPath = Array(socketURL.path.utf8CString)
        guard encodedPath.count <= MemoryLayout.size(
            ofValue: unixAddress.sun_path
        ) else {
            close(tcp)
            close(unix)
            throw CapabilityRuntimeWorkerError.canaryServerFailed
        }
        withUnsafeMutableBytes(of: &unixAddress.sun_path) { destination in
            destination.initializeMemory(as: UInt8.self, repeating: 0)
            encodedPath.withUnsafeBytes { source in
                destination.copyBytes(from: source)
            }
        }
        let unixBindResult = withUnsafePointer(to: &unixAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(
                    unix,
                    $0,
                    socklen_t(MemoryLayout<sockaddr_un>.size)
                )
            }
        }
        guard
            unixBindResult == 0,
            chmod(socketURL.path, 0o600) == 0,
            listen(unix, 8) == 0
        else {
            close(tcp)
            close(unix)
            unlink(socketURL.path)
            throw CapabilityRuntimeWorkerError.canaryServerFailed
        }

        let server = RuntimeCanaryServer(
            port: UInt16(bigEndian: bound.sin_port),
            socketURL: socketURL,
            tcpDescriptor: tcp,
            unixDescriptor: unix
        )
        server.run()
        return server
    }

    private init(
        port: UInt16,
        socketURL: URL,
        tcpDescriptor: Int32,
        unixDescriptor: Int32
    ) {
        self.port = port
        self.socketURL = socketURL
        self.tcpDescriptor = tcpDescriptor
        self.unixDescriptor = unixDescriptor
    }

    func stop() {
        let shouldStop = lock.withLock {
            guard !stopped else { return false }
            stopped = true
            return true
        }
        guard shouldStop else { return }
        shutdown(tcpDescriptor, SHUT_RDWR)
        shutdown(unixDescriptor, SHUT_RDWR)
        close(tcpDescriptor)
        close(unixDescriptor)
        unlink(socketURL.path)
    }

    private func run() {
        for descriptor in [tcpDescriptor, unixDescriptor] {
            queue.async { [weak self] in
                guard let self else { return }
                while !self.lock.withLock({ self.stopped }) {
                    let client = accept(descriptor, nil, nil)
                    if client < 0 {
                        if errno == EINTR { continue }
                        return
                    }
                    let response = """
                    HTTP/1.1 200 OK\r
                    Content-Length: 19\r
                    Connection: close\r
                    \r
                    STORNAUT_CANARY_OK
                    """
                    _ = response.withCString {
                        write(client, $0, strlen($0))
                    }
                    close(client)
                }
            }
        }
    }
}

private func capabilityEvidence(
    staticReport: CodexRuntimeCapabilityReport,
    observation: CodexAppServerObservation,
    evidence: [InvestigationEvidenceV2],
    fixture: RuntimeDiagnosticFixture
) throws -> [CapabilityRuntimeCapabilityEvidence] {
    let commands = observation.capabilityObservations.compactMap {
        if case let .command(source, succeeded, markerIDs) = $0 {
            return (source, succeeded, Set(markerIDs))
        }
        return nil
    }
    let evidenceBySource = Dictionary(
        grouping: evidence,
        by: \.source
    )
    func marker(
        _ identifier: String,
        source: CodexCommandExecutionSource? = nil
    ) -> Bool {
        commands.contains {
            $0.1
                && $0.2.contains(identifier)
                && (source == nil || $0.0 == source)
        }
    }
    let commandSources = Set(commands.map(\.0))
    let directEvidence = evidenceBySource[.directFile]
    let shellEvidence = evidenceBySource[.shell]
    let liveSearchStarted = observation.capabilityObservations.contains(
        .webSearchStarted
    )
    let liveSearchCompleted = observation.capabilityObservations.contains(
        .webSearchCompleted
    )
    let imageStarted = observation.capabilityObservations.contains(
        .imageViewStarted
    )
    let skillSelected = observation.capabilityObservations.contains(
        .runtimeSkillSelected
    )
    let subagentStarted = observation.capabilityObservations.contains(
        .subagentSpawnStarted
    )
    let subagentCompleted = observation.capabilityObservations.contains {
        if case .subagentSpawnCompleted(let receiverCount) = $0 {
            return receiverCount > 0
        }
        return false
    }
    let invoked: [CapabilityRuntimeCapability: Bool] = [
        .directRead: marker("direct.via-command"),
        .shell: commands.contains {
            $0.1 && $0.2.contains("shell.read")
        },
        .unifiedExec:
            commandSources.contains(.unifiedExecStartup)
                || commandSources.contains(.unifiedExecInteraction),
        .liveSearch: liveSearchStarted || liveSearchCompleted,
        .publicCommandNetwork:
            commands.contains { $0.2.contains("public.proxy") },
        .browserOrDirectFetch:
            commands.contains { $0.2.contains("browser.fetch") },
        .imageInspection: imageStarted
            || observation.capabilityObservations.contains(
                .imageViewCompleted
            ),
        .skills: skillSelected,
        .subagents: subagentStarted || subagentCompleted,
    ]
    let observed: [CapabilityRuntimeCapability: Bool] = [
        .directRead: directEvidence?.contains {
            $0.summary.contains(fixture.directToken)
        } == true && marker("direct.via-command"),
        .shell: marker("shell.read")
            && shellEvidence != nil,
        .unifiedExec:
            (
                marker("unified.read", source: .unifiedExecStartup)
                    || marker(
                        "unified.read",
                        source: .unifiedExecInteraction
                    )
            ) && shellEvidence != nil,
        .liveSearch: liveSearchCompleted
            && evidenceBySource[.liveSearch] != nil,
        .publicCommandNetwork: marker("public.proxy"),
        .browserOrDirectFetch: marker("browser.fetch")
            && evidenceBySource[.browserOrDirectFetch] != nil,
        .imageInspection: observation.capabilityObservations.contains(
            .imageViewCompleted
        ) && imageEvidenceContainsSyntheticToken(
            evidenceBySource[.image] ?? [],
            token: fixture.imageToken
        ),
        .skills: skillSelected
            && evidenceBySource[.skill]?.contains {
            $0.summary.contains(fixture.skillToken)
        } == true,
        .subagents: subagentCompleted
            && observation.capabilityObservations.contains(
                .subagentResultObserved
            )
            && evidenceBySource[.subagent]?.contains {
            $0.summary.contains(fixture.subagentToken)
        } == true,
    ]
    let configuredMap: [
        CapabilityRuntimeCapability: CodexRuntimeCapability
    ] = [
        .directRead: .directRead,
        .shell: .shell,
        .unifiedExec: .unifiedExec,
        .liveSearch: .liveSearch,
        .publicCommandNetwork: .publicCommandNetwork,
        .browserOrDirectFetch: .browserOrDirectFetch,
        .imageInspection: .imageInspection,
        .skills: .runtimeSkills,
        .subagents: .subagents,
    ]
    return try CapabilityRuntimeCapability.required.sorted {
        $0.rawValue < $1.rawValue
    }.map { capability in
        let runtimeCapability = configuredMap[capability]!
        let entry = staticReport.entries[runtimeCapability]
        let advertised = entry?.advertised == true
        let configured = entry?.configured == true
        let didInvoke = invoked[capability] == true
        let didObserve = observed[capability] == true
        return try CapabilityRuntimeCapabilityEvidence(
            capability: capability,
            advertised: advertised,
            configured: configured,
            invoked: didInvoke,
            observed: didObserve,
            reasonKey: didObserve
                ? nil
                : didInvoke
                    ? "runtime.capability.\(capability.rawValue).not-observed"
                    : "runtime.capability.\(capability.rawValue).not-invoked"
        )
    }
}

private func integrityEvidence(
    observation: CodexAppServerObservation,
    fixture: RuntimeDiagnosticFixture,
    authSourceURL: URL,
    initialAuthSnapshot: StableFileSnapshot
) throws -> [CapabilityRuntimeIntegrityEvidence] {
    let commands = observation.capabilityObservations.compactMap {
        if case let .command(_, succeeded, markerIDs) = $0, succeeded {
            return Set(markerIDs)
        }
        return nil
    }
    func observed(_ marker: String) -> Bool {
        commands.contains { $0.contains(marker) }
    }
    let mutationResidue = [
        "denied-create",
        "denied-move",
        "denied-hardlink",
        "denied-symlink",
        "nested-denied",
    ].contains {
        FileManager.default.fileExists(
            atPath: fixture.workspace.workURL.appending(path: $0).path
        )
    }
    let snapshot = CapabilityRuntimeContainmentSnapshot(
        observedMarkerIDs: Set(commands.flatMap { $0 }),
        mutationResidue: mutationResidue,
        requiresPrivateDenial: privateIPv4Address() != nil,
        authUnchanged:
            try StableFileSnapshot.read(authSourceURL)
                == initialAuthSnapshot
    )
    if let reasonKey = capabilityRuntimeContainmentFailureReason(snapshot) {
        throw CapabilityRuntimeWorkerError.containmentFailed(
            reasonKey: reasonKey
        )
    }
    return try [
        CapabilityRuntimeIntegrityEvidence(
            property: .userDataWriteDenial,
            verdict: .contained,
            reasonKey: nil
        ),
        CapabilityRuntimeIntegrityEvidence(
            property: .nestedDescendantWriteDenial,
            verdict: .contained,
            reasonKey: nil
        ),
        CapabilityRuntimeIntegrityEvidence(
            property: .loopbackPrivateLinkLocalDenial,
            verdict: .contained,
            reasonKey: nil
        ),
        CapabilityRuntimeIntegrityEvidence(
            property: .unixSocketDenial,
            verdict: .contained,
            reasonKey: nil
        ),
    ]
}

private func localRunRoot(
    userID: uid_t,
    investigationID: UUID
) throws -> URL {
    guard userID > 0 else {
        throw CapabilityRuntimeWorkerError.invalidIdentity
    }
    let root = URL(
        filePath:
            "/Library/Application Support/Stornaut/R5Runtime",
        directoryHint: .isDirectory
    )
    .appending(path: String(userID), directoryHint: .isDirectory)
    .appending(
        path: investigationID.uuidString.lowercased(),
        directoryHint: .isDirectory
    )
    .standardizedFileURL
    let userRoot = root.deletingLastPathComponent()
    let diagnosticRoot = userRoot.deletingLastPathComponent()
    let installedRoot = diagnosticRoot.deletingLastPathComponent()
    var installedInformation = stat()
    var diagnosticInformation = stat()
    var userRootInformation = stat()
    var information = stat()
    guard
        lstat(installedRoot.path, &installedInformation) == 0,
        installedInformation.st_mode & S_IFMT == S_IFDIR,
        installedInformation.st_uid == 0,
        installedInformation.st_gid == 0,
        installedInformation.st_mode & 0o777 == 0o755,
        lstat(diagnosticRoot.path, &diagnosticInformation) == 0,
        diagnosticInformation.st_mode & S_IFMT == S_IFDIR,
        diagnosticInformation.st_uid == 0,
        diagnosticInformation.st_gid == 0,
        diagnosticInformation.st_mode & 0o777 == 0o711,
        lstat(userRoot.path, &userRootInformation) == 0,
        userRootInformation.st_mode & S_IFMT == S_IFDIR,
        userRootInformation.st_uid == 0,
        userRootInformation.st_gid == 0,
        userRootInformation.st_mode & 0o777 == 0o711,
        lstat(root.path, &information) == 0,
        information.st_mode & S_IFMT == S_IFDIR,
        information.st_uid == userID,
        information.st_mode & 0o777 == 0o700,
        root.path.hasPrefix(
            "/Library/Application Support/Stornaut/R5Runtime/\(userID)/"
        )
    else {
        throw CapabilityRuntimeWorkerError.invalidDiagnosticRoot
    }
    return root
}

private func standaloneTestRunRoot(
    url: URL,
    userID: uid_t,
    investigationID: UUID
) throws -> URL {
    guard userID > 0 else {
        throw CapabilityRuntimeWorkerError.invalidIdentity
    }
    let expected = URL(
        filePath: "/Library/Caches/Stornaut-R5-WorkerTests",
        directoryHint: .isDirectory
    )
    .appending(path: String(userID), directoryHint: .isDirectory)
    .appending(
        path: investigationID.uuidString.lowercased(),
        directoryHint: .isDirectory
    )
    .standardizedFileURL
    let root = url.resolvingSymlinksInPath().standardizedFileURL
    var information = stat()
    guard
        root == expected,
        lstat(root.path, &information) == 0,
        information.st_mode & S_IFMT == S_IFDIR,
        information.st_uid == userID,
        information.st_mode & 0o777 == 0o700
    else {
        throw CapabilityRuntimeWorkerError.invalidDiagnosticRoot
    }
    return root
}

private func closedWorkerEnvironment(
    homeURL: URL
) -> [String: String] {
    let inherited = ProcessInfo.processInfo.environment
    var values = [
        "HOME": homeURL.path,
        "PATH":
            "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
        "TERM": inherited["TERM"] ?? "dumb",
    ]
    for key in ["LANG", "LC_ALL", "LC_CTYPE"] {
        if let value = inherited[key], !value.isEmpty {
            values[key] = value
        }
    }
    for key in ["SSL_CERT_FILE", "SSL_CERT_DIR"] {
        if let value = inherited[key], !value.isEmpty {
            values[key] = value
        }
    }
    return values
}

private func locateCodex(
    environment: [String: String]
) async throws -> CodexInstallation {
    guard
        let installation = await CodexLocator().locate(
            configuredURL: nil,
            environment: environment
        ).installation
    else {
        throw CapabilityRuntimeWorkerError.codexUnavailable
    }
    return installation
}

private func codexVersion(
    executableURL: URL,
    environment: [String: String],
    workingDirectoryURL: URL
) async throws -> String {
    let result = try await FoundationProcessRunner().run(
        ProcessRequest(
            executableURL: executableURL,
            arguments: ["--version"],
            environment: environment,
            currentDirectoryURL: workingDirectoryURL,
            standardOutputLimit: 4_096,
            standardErrorLimit: 4_096,
            timeout: .seconds(10)
        )
    )
    guard
        result.exitStatus == 0,
        !result.stdoutWasTruncated,
        let value = String(data: result.stdout, encoding: .utf8)
    else {
        throw CapabilityRuntimeWorkerError.codexUnavailable
    }
    return value
}

func installRuntimeDiagnosticProbe(
    _ data: Data,
    at url: URL
) throws {
    let descriptor = open(
        url.path,
        O_WRONLY | O_TRUNC | O_CLOEXEC | O_NOFOLLOW
    )
    guard descriptor >= 0 else {
        throw CapabilityRuntimeWorkerError.fixtureStagingFailed
    }
    defer { close(descriptor) }
    var information = stat()
    guard
        fstat(descriptor, &information) == 0,
        information.st_mode & S_IFMT == S_IFREG,
        information.st_uid == geteuid(),
        information.st_mode & 0o777 == 0o700,
        information.st_nlink == 1
    else {
        throw CapabilityRuntimeWorkerError.fixtureStagingFailed
    }
    let didWrite = data.withUnsafeBytes { bytes in
        guard let base = bytes.baseAddress else { return true }
        var offset = 0
        while offset < bytes.count {
            let count = Darwin.write(
                descriptor,
                base.advanced(by: offset),
                bytes.count - offset
            )
            if count < 0 {
                if errno == EINTR { continue }
                return false
            }
            offset += count
        }
        return true
    }
    guard
        didWrite,
        fchmod(descriptor, 0o500) == 0,
        fsync(descriptor) == 0
    else {
        throw CapabilityRuntimeWorkerError.fixtureStagingFailed
    }
}

private func writeFixture(
    _ data: Data,
    to url: URL,
    mode: mode_t,
    replacesExisting: Bool = false
) throws {
    let flags = O_WRONLY | O_CREAT | O_CLOEXEC | O_NOFOLLOW
        | (replacesExisting ? O_TRUNC : O_EXCL)
    let descriptor = open(url.path, flags, mode)
    guard descriptor >= 0 else {
        throw CapabilityRuntimeWorkerError.fixtureStagingFailed
    }
    defer { close(descriptor) }
    let didWrite = data.withUnsafeBytes { bytes in
        guard let base = bytes.baseAddress else { return true }
        var offset = 0
        while offset < bytes.count {
            let count = Darwin.write(
                descriptor,
                base.advanced(by: offset),
                bytes.count - offset
            )
            if count < 0 {
                if errno == EINTR { continue }
                return false
            }
            offset += count
        }
        return true
    }
    guard
        didWrite,
        fchmod(descriptor, mode) == 0,
        fsync(descriptor) == 0
    else {
        throw CapabilityRuntimeWorkerError.fixtureStagingFailed
    }
}

private func privateIPv4Address() -> String? {
    var pointer: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&pointer) == 0, let first = pointer else {
        return nil
    }
    defer { freeifaddrs(pointer) }
    var current: UnsafeMutablePointer<ifaddrs>? = first
    while let item = current {
        defer { current = item.pointee.ifa_next }
        guard
            let address = item.pointee.ifa_addr,
            address.pointee.sa_family == UInt8(AF_INET),
            item.pointee.ifa_flags & UInt32(IFF_LOOPBACK) == 0
        else {
            continue
        }
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = getnameinfo(
            address,
            socklen_t(address.pointee.sa_len),
            &host,
            socklen_t(host.count),
            nil,
            0,
            NI_NUMERICHOST
        )
        guard result == 0 else { continue }
        let value = String(
            decoding: host.prefix { $0 != 0 }.map {
                UInt8(bitPattern: $0)
            },
            as: UTF8.self
        )
        let octets = value.split(separator: ".").compactMap {
            UInt8($0)
        }
        guard octets.count == 4 else { continue }
        if octets[0] == 10
            || (octets[0] == 172 && (16...31).contains(octets[1]))
            || (octets[0] == 192 && octets[1] == 168)
            || (octets[0] == 100 && (64...127).contains(octets[1]))
        {
            return value
        }
    }
    return nil
}

private func readAll(
    descriptor: Int32,
    maximumBytes: Int
) throws -> Data {
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4_096)
    while true {
        let count = Darwin.read(descriptor, &buffer, buffer.count)
        if count == 0 { return data }
        if count < 0 {
            if errno == EINTR { continue }
            throw CapabilityRuntimeWorkerError.invalidIdentity
        }
        guard data.count + count <= maximumBytes else {
            throw CapabilityRuntimeWorkerError.invalidIdentity
        }
        data.append(contentsOf: buffer.prefix(count))
    }
}

private func sha256File(_ url: URL) throws -> String {
    sha256(try Data(contentsOf: url, options: .mappedIfSafe))
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func workerSessionReasonKey(
    _ error: CodexAppServerSessionError
) -> String {
    switch error {
    case .invalidRequest:
        "runtime.worker.session-invalid-request"
    case .launchFailed:
        "runtime.worker.session-launch-failed"
    case .inputWriteFailed:
        "runtime.worker.session-input-failed"
    case .outputReadFailed:
        "runtime.worker.session-output-read-failed"
    case .outputLimitExceeded:
        "runtime.worker.session-output-limit"
    case .errorLimitExceeded:
        "runtime.worker.session-error-limit"
    case let .protocolFailure(runtimeError):
        workerProtocolReasonKey(runtimeError)
    case .providerCatalogProtocolFailure:
        "runtime.worker.session-unexpected-provider-preflight"
    case .timedOut:
        "runtime.worker.session-timeout"
    case .cancelled:
        "runtime.worker.session-cancelled"
    case .nonzeroExit:
        "runtime.worker.session-nonzero-exit"
    case .terminationFailed:
        "runtime.worker.session-termination-failed"
    }
}

func workerProtocolReasonKey(
    _ error: CodexAppServerRuntimeError
) -> String {
    switch error {
    case .invalidRequest:
        "runtime.worker.protocol-invalid-request"
    case .invalidState:
        "runtime.worker.protocol-invalid-state"
    case .inputLimitExceeded:
        "runtime.worker.protocol-input-limit"
    case .invalidMessage:
        "runtime.worker.protocol-invalid-message"
    case let .unexpectedResponse(reasonKey):
        "runtime.worker.protocol.\(reasonKey)"
    case .unexpectedRequest:
        "runtime.worker.protocol-unexpected-request"
    case let .unexpectedNotification(reasonKey):
        "runtime.worker.protocol.\(reasonKey)"
    case let .unexpectedItem(type):
        "runtime.worker.protocol-unexpected-item.\(type)"
    case let .identityMismatch(reasonKey):
        "runtime.worker.protocol.\(reasonKey)"
    case .authenticationRefreshBlocked:
        "runtime.worker.protocol-auth-refresh-blocked"
    case let .upstreamError(error):
        [
            "runtime.worker.protocol-upstream",
            error.category.rawValue,
            error.code.map { "code-\($0)" } ?? "code-none",
            error.willRetry ? "retry-true" : "retry-false",
        ].joined(separator: ".")
    case let .turnFailed(reasonKey):
        "runtime.worker.protocol.\(reasonKey)"
    }
}

private extension Duration {
    var boundedMilliseconds: Int {
        let components = self.components
        let seconds = max(0, components.seconds)
        let milliseconds = max(
            0,
            components.attoseconds / 1_000_000_000_000_000
        )
        let result = seconds.multipliedReportingOverflow(by: 1_000)
        guard !result.overflow else { return 3_600_000 }
        return min(
            3_600_000,
            Int(result.partialValue + milliseconds)
        )
    }
}
#endif
