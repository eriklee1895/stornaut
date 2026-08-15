#if DEBUG
import AppKit
import CryptoKit
import Darwin
import Foundation
import Security
import StornautCore
import StornautLifecycle

enum PhaseCTrashDiagnosticError:
    String,
    Error,
    Codable,
    Sendable,
    Equatable
{
    case invalidConfiguration
    case unsafePath
    case optInMismatch
    case buildMismatch
    case expired
    case fixtureExists
    case fixtureMismatch
    case scanFailed
    case planFailed
    case policyFailed
    case executionFailed
    case executionRejectedAuthorization
    case executionRejectedWorkflowConflict
    case executionRejectedPlanMismatch
    case executionRejectedPersistence
    case executionRejectedProgrammingError
    case receiptMismatch
}

private extension PhaseCTrashDiagnosticError {
    var stage: String {
        switch self {
        case .invalidConfiguration, .unsafePath, .optInMismatch,
             .buildMismatch, .expired:
            "configuration"
        case .fixtureExists, .fixtureMismatch:
            "fixture"
        case .scanFailed:
            "quickScan"
        case .planFailed:
            "planning"
        case .policyFailed:
            "policy"
        case .executionFailed, .executionRejectedAuthorization,
             .executionRejectedWorkflowConflict,
             .executionRejectedPlanMismatch,
             .executionRejectedPersistence,
             .executionRejectedProgrammingError:
            "execution"
        case .receiptMismatch:
            "receipt"
        }
    }
}

enum PhaseCTrashDiagnosticPreflightError:
    String,
    Codable,
    Sendable,
    Equatable
{
    case signingEvidenceUnavailable
    case invalidConfiguration
    case unsafePath
    case optInMismatch
    case buildMismatch
    case expired
}

struct PhaseCTrashDiagnosticPreflightReceipt:
    Codable,
    Sendable,
    Equatable
{
    let schemaVersion: Int
    let startedAt: Date
    let finishedAt: Date
    let outcome: String
    let errorStage: String
    let error: PhaseCTrashDiagnosticPreflightError

    static func make(
        error: any Error,
        startedAt: Date
    ) -> Self {
        let category: PhaseCTrashDiagnosticPreflightError
        let stage: String
        if let diagnosticError =
            error as? PhaseCTrashDiagnosticError
        {
            category = switch diagnosticError {
            case .invalidConfiguration:
                .invalidConfiguration
            case .unsafePath:
                .unsafePath
            case .optInMismatch:
                .optInMismatch
            case .buildMismatch:
                .buildMismatch
            case .expired:
                .expired
            case .fixtureExists, .fixtureMismatch, .scanFailed,
                 .planFailed, .policyFailed, .executionFailed,
                 .executionRejectedAuthorization,
                 .executionRejectedWorkflowConflict,
                 .executionRejectedPlanMismatch,
                 .executionRejectedPersistence,
                 .executionRejectedProgrammingError,
                 .receiptMismatch:
                .invalidConfiguration
            }
            stage = diagnosticError.stage
        } else {
            category = .signingEvidenceUnavailable
            stage = "signing"
        }
        return Self(
            schemaVersion: 1,
            startedAt: startedAt,
            finishedAt: Date(),
            outcome: "signedAppTrashPreflightBlocked",
            errorStage: stage,
            error: category
        )
    }
}

struct PhaseCTrashDiagnosticConfiguration: Codable, Sendable, Equatable {
    static let schemaVersion = 1
    static let optInEnvironmentKey =
        "STORNAUT_PHASE_C_TRASH_OPT_IN"
    static let optInStatement =
        "I authorize Stornaut Task 35 to Trash and restore only this disposable fixture."
    static let expectedRelativePath = ".npm/_cacache"

    let schemaVersion: Int
    let nonce: String
    let optInStatement: String
    let optInNonce: String
    let diagnosticRoot: String
    let fixtureRoot: String
    let applicationSupportBase: String
    let cachesBase: String
    let reportPath: String
    let expectedBundleIdentifier: String
    let expectedExecutableSHA256: String
    let expectedRelativePath: String
    let issuedAt: Date
    let expiresAt: Date

    static func validated(
        data: Data,
        configURL: URL,
        environment: [String: String],
        now: Date,
        bundleIdentifier: String?,
        executableSHA256: String
    ) throws -> Self {
        guard let object = try? JSONSerialization.jsonObject(
                with: data
            ) as? [String: Any]
        else {
            throw PhaseCTrashDiagnosticError.invalidConfiguration
        }
        guard Set(object.keys) == Set(
                CodingKeys.allCases.map(\.stringValue)
            ),
            let value = try? JSONDecoder.phaseC.decode(
                Self.self,
                from: data
            ),
            value.schemaVersion == schemaVersion,
            UUID(uuidString: value.nonce) != nil,
            UUID(uuidString: value.optInNonce) != nil,
            value.optInStatement == optInStatement,
            environment[optInEnvironmentKey] == value.optInNonce,
            value.expectedBundleIdentifier
                == "com.eriklee.stornaut",
            bundleIdentifier == value.expectedBundleIdentifier,
            validSHA256(value.expectedExecutableSHA256),
            executableSHA256 == value.expectedExecutableSHA256,
            value.expectedRelativePath == expectedRelativePath,
            value.issuedAt.timeIntervalSince1970.isFinite,
            value.expiresAt.timeIntervalSince1970.isFinite,
            value.issuedAt <= now,
            now <= value.expiresAt,
            value.expiresAt.timeIntervalSince(value.issuedAt) <= 300
        else {
            if environment[optInEnvironmentKey]
                != (object["optInNonce"] as? String)
            {
                throw PhaseCTrashDiagnosticError.optInMismatch
            }
            if bundleIdentifier
                != (object["expectedBundleIdentifier"] as? String)
                || executableSHA256
                != (object["expectedExecutableSHA256"] as? String)
            {
                throw PhaseCTrashDiagnosticError.buildMismatch
            }
            if let expiresAt = object["expiresAt"] as? TimeInterval,
               now.timeIntervalSince1970 > expiresAt
            {
                throw PhaseCTrashDiagnosticError.expired
            }
            throw PhaseCTrashDiagnosticError.invalidConfiguration
        }

        let config = configURL.standardizedFileURL
        let root = URL(filePath: value.diagnosticRoot)
            .standardizedFileURL
        let fixture = URL(filePath: value.fixtureRoot)
            .standardizedFileURL
        let support = URL(filePath: value.applicationSupportBase)
            .standardizedFileURL
        let caches = URL(filePath: value.cachesBase)
            .standardizedFileURL
        let report = URL(filePath: value.reportPath)
            .standardizedFileURL
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .standardizedFileURL
        guard config.isFileURL,
        [
            value.diagnosticRoot,
            value.fixtureRoot,
            value.applicationSupportBase,
            value.cachesBase,
            value.reportPath,
        ].allSatisfy(isNormalizedAbsolutePath),
        value.fixtureRoot == value.diagnosticRoot + "/fixture",
        value.applicationSupportBase
            == value.diagnosticRoot + "/support",
        value.cachesBase == value.diagnosticRoot + "/caches",
        value.reportPath == value.diagnosticRoot + "/report.json",
        sameDirectory(
            config.deletingLastPathComponent(),
            root
        ),
        sameDirectory(
            root.deletingLastPathComponent(),
            temporaryDirectory
        ),
        root.lastPathComponent.hasPrefix(
            "stornaut-phase-c-trash."
        ),
        Set([
            config.path,
            fixture.path,
            support.path,
            caches.path,
            report.path,
        ]).count == 5,
        safeDiagnosticRoot(root, configURL: config),
        safeConfigFile(config),
        fixture.lastPathComponent == "fixture",
        support.lastPathComponent == "support",
        caches.lastPathComponent == "caches",
        report.lastPathComponent == "report.json",
        !pathExists(fixture),
        !pathExists(support),
        !pathExists(caches),
        !pathExists(report)
        else {
            throw PhaseCTrashDiagnosticError.unsafePath
        }
        return value
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case nonce
        case optInStatement
        case optInNonce
        case diagnosticRoot
        case fixtureRoot
        case applicationSupportBase
        case cachesBase
        case reportPath
        case expectedBundleIdentifier
        case expectedExecutableSHA256
        case expectedRelativePath
        case issuedAt
        case expiresAt
    }
}

enum PhaseCTrashDiagnosticRestoreOutcome:
    String,
    Codable,
    Sendable,
    Equatable
{
    case restored
    case destinationUnavailable
    case originalOccupied
    case identityChanged
    case markerMismatch
    case moveFailed
}

enum PhaseCTrashDiagnosticRestore {
    typealias BeforeMove = () throws -> Void

    static func restore(
        returnedTrashURL: URL?,
        originalURL: URL,
        expectedIdentity: FileIdentity,
        expectedDestinationParentIdentity: FileIdentity,
        marker: String,
        markerName: String,
        beforeMove: BeforeMove = {}
    ) -> PhaseCTrashDiagnosticRestoreOutcome {
        guard let returnedTrashURL else {
            return .destinationUnavailable
        }
        let source = returnedTrashURL.standardizedFileURL
        let destination = originalURL.standardizedFileURL
        let sourceName = source.lastPathComponent
        let destinationName = destination.lastPathComponent
        guard validDescriptorRelativeName(sourceName),
              validDescriptorRelativeName(destinationName),
              validDescriptorRelativeName(markerName)
        else {
            return .identityChanged
        }
        let sourceParentDescriptor = open(
            source.deletingLastPathComponent().path,
            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        )
        guard sourceParentDescriptor >= 0 else {
            return .identityChanged
        }
        defer { close(sourceParentDescriptor) }
        let destinationParent = destination.deletingLastPathComponent()
        let destinationParentDescriptor = open(
            destinationParent.path,
            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        )
        guard destinationParentDescriptor >= 0 else {
            return .identityChanged
        }
        defer { close(destinationParentDescriptor) }
        guard sameFileObject(
            descriptorIdentity(destinationParentDescriptor),
            expectedDestinationParentIdentity
        )
        else {
            return .identityChanged
        }
        let sourceDescriptor = sourceName.withCString {
            openat(
                sourceParentDescriptor,
                $0,
                O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
            )
        }
        guard sourceDescriptor >= 0 else {
            return .identityChanged
        }
        defer { close(sourceDescriptor) }
        guard descriptorIdentity(sourceDescriptor) == expectedIdentity,
              descriptorRelativeIdentity(
                parentDescriptor: sourceParentDescriptor,
                name: sourceName
              ) == expectedIdentity
        else {
            return .identityChanged
        }
        guard descriptorRelativeText(
            parentDescriptor: sourceDescriptor,
            name: markerName,
            maximumSize: 4_096
        ) == marker
        else {
            return .markerMismatch
        }
        guard let destinationExists = descriptorRelativePathExists(
            parentDescriptor: destinationParentDescriptor,
            name: destinationName
        ) else {
            return .identityChanged
        }
        if destinationExists {
            return .originalOccupied
        }
        do {
            try beforeMove()
        } catch {
            return .moveFailed
        }
        guard sameFileObject(
            FileIdentity.read(at: destinationParent),
            expectedDestinationParentIdentity
        ),
        sameFileObject(
            descriptorIdentity(destinationParentDescriptor),
            expectedDestinationParentIdentity
        ),
        descriptorRelativeIdentity(
            parentDescriptor: sourceParentDescriptor,
            name: sourceName
        ) == expectedIdentity,
        descriptorRelativePathExists(
            parentDescriptor: destinationParentDescriptor,
            name: destinationName
        ) == false
        else {
            return .identityChanged
        }
        let moveResult = sourceName.withCString { sourceNamePointer in
            destinationName.withCString { destinationNamePointer in
                renameatx_np(
                    sourceParentDescriptor,
                    sourceNamePointer,
                    destinationParentDescriptor,
                    destinationNamePointer,
                    UInt32(RENAME_EXCL)
                )
            }
        }
        guard moveResult == 0 else {
            return errno == EEXIST
                ? .originalOccupied
                : .moveFailed
        }
        guard descriptorRelativeIdentity(
            parentDescriptor: destinationParentDescriptor,
            name: destinationName
        ) == expectedIdentity,
        descriptorRelativePathExists(
            parentDescriptor: sourceParentDescriptor,
            name: sourceName
        ) == false
        else {
            return .moveFailed
        }
        return .restored
    }

    static func restoreIfNeeded(
        existingOutcome: PhaseCTrashDiagnosticRestoreOutcome?,
        returnedTrashURL: URL?,
        originalURL: URL,
        expectedIdentity: FileIdentity,
        expectedDestinationParentIdentity: FileIdentity,
        marker: String,
        markerName: String,
        beforeMove: BeforeMove = {}
    ) -> PhaseCTrashDiagnosticRestoreOutcome {
        if let existingOutcome {
            return existingOutcome
        }
        return restore(
            returnedTrashURL: returnedTrashURL,
            originalURL: originalURL,
            expectedIdentity: expectedIdentity,
            expectedDestinationParentIdentity:
                expectedDestinationParentIdentity,
            marker: marker,
            markerName: markerName,
            beforeMove: beforeMove
        )
    }
}

struct PhaseCTrashDiagnosticLaunchRequest:
    Sendable,
    Equatable
{
    private static let argumentPrefix =
        "--stornaut-phase-c-trash-config="

    let configURL: URL

    init?(arguments: [String]) {
        guard !arguments.contains(where: {
            $0.hasPrefix(
                "--stornaut-phase-c-trash-recovery-config"
            )
        }) else {
            return nil
        }
        let matching = arguments.filter {
            $0 == String(Self.argumentPrefix.dropLast())
                || $0.hasPrefix(Self.argumentPrefix)
        }
        guard matching.count == 1,
              matching[0].hasPrefix(Self.argumentPrefix)
        else {
            return nil
        }
        let rawPath = String(
            matching[0].dropFirst(Self.argumentPrefix.count)
        )
        guard rawPath.hasPrefix("/") else {
            return nil
        }
        configURL = URL(filePath: rawPath).standardizedFileURL
    }
}

enum PhaseCTrashDiagnosticHarness {
    @MainActor
    static func startIfRequested() {
        guard let request = PhaseCTrashDiagnosticLaunchRequest(
            arguments: CommandLine.arguments
        ) else {
            return
        }
        Task {
            await Task.yield()
            if let result = await run(configURL: request.configURL) {
                write(result.report, reportURL: result.reportURL)
            }
            NSApplication.shared.terminate(nil)
        }
    }

    private static func run(
        configURL: URL
    ) async -> PhaseCTrashDiagnosticRunResult? {
        let startedAt = Date()
        do {
            let signing = try LifecycleBundleSigningIdentityReader()
                .evidence(bundleURL: Bundle.main.bundleURL)
            let data = try loadConfigurationData(configURL)
            let config = try PhaseCTrashDiagnosticConfiguration.validated(
                data: data,
                configURL: configURL,
                environment: ProcessInfo.processInfo.environment,
                now: Date(),
                bundleIdentifier: Bundle.main.bundleIdentifier,
                executableSHA256: signing.executableSHA256
            )
            let report = await execute(
                config: config,
                signing: signing
            )
            return PhaseCTrashDiagnosticRunResult(
                report: report,
                reportURL: URL(
                    filePath: config.reportPath
                ).standardizedFileURL
            )
        } catch {
            writePreflightReceipt(
                .make(error: error, startedAt: startedAt),
                configURL: configURL
            )
            return nil
        }
    }

    private static func execute(
        config: PhaseCTrashDiagnosticConfiguration,
        signing: LifecycleBundleSigningEvidence
    ) async -> PhaseCTrashDiagnosticReport {
        let startedAt = Date()
        let root = URL(
            filePath: config.fixtureRoot,
            directoryHint: .isDirectory
        )
        let itemURL = root.appending(
            path: config.expectedRelativePath,
            directoryHint: .isDirectory
        )
        let itemMarkerName =
            ".stornaut-phase-c-trash-item-\(config.nonce)"
        let itemMarker =
            "stornaut-phase-c-trash-item:\(config.nonce)"
        let observation = CleanupTrashDiagnosticObservation()
        var originalIdentity: FileIdentity?
        var plan: CleanupPlan?
        var selection: ReviewSelection?
        var confirmation: CleanupConfirmation?
        var result: CleanupExecutionResult?
        var destinationParentIdentity: FileIdentity?
        var restoreOutcome: PhaseCTrashDiagnosticRestoreOutcome?
        do {
            guard !pathExists(root) else {
                throw PhaseCTrashDiagnosticError.fixtureExists
            }
            try createFixture(
                diagnosticRoot: root.deletingLastPathComponent(),
                fixtureRoot: root,
                itemURL: itemURL,
                nonce: config.nonce,
                markerName: itemMarkerName,
                marker: itemMarker
            )
            let identity = try requireIdentity(itemURL)
            originalIdentity = identity
            let evidenceResolver = try ExecutableEvidenceResolver
                .phaseCTrashDiagnostic(
                    diagnosticRootURL: root.deletingLastPathComponent(),
                    fixtureRootURL: root,
                    nonce: config.nonce,
                    expectedTargetIdentity: identity
                )
            let parentIdentity = try requireDirectoryIdentity(
                itemURL.deletingLastPathComponent()
            )
            destinationParentIdentity = parentIdentity
            let storeConfiguration = try LocalStoreConfiguration(
                applicationSupportBaseURL: URL(
                    filePath: config.applicationSupportBase,
                    directoryHint: .isDirectory
                ),
                cachesBaseURL: URL(
                    filePath: config.cachesBase,
                    directoryHint: .isDirectory
                )
            )
            let dependencies = AppDependencies.phaseCTrashDiagnostic(
                configuration: storeConfiguration,
                rootURL: root,
                diagnosticEvidenceResolver: evidenceResolver,
                makeExecutionRuntime: {
                    try CleanupExecutionRuntime.diagnostic(
                        store: $0,
                        rootObserver: $1,
                        workflowCoordinator: $2,
                        resolver: $3,
                        observation: observation
                    )
                }
            )
            let stream = try await dependencies.startQuickScan()
            var projection: QuickScanProjection?
            for try await event in stream {
                if case let .terminal(value) = event {
                    projection = value
                }
            }
            guard projection?.session.terminalState == .completed else {
                throw PhaseCTrashDiagnosticError.scanFailed
            }
            let build = await dependencies.buildReview()
            guard case let .planReady(builtPlan, review) = build,
                  builtPlan.items.count == 1,
                  let item = builtPlan.items.first,
                  item.expectedRelativePath?.rawValue
                    == config.expectedRelativePath,
                  item.expectedIdentity == identity,
                  review.counts.executableReady == 1
            else {
                throw PhaseCTrashDiagnosticError.planFailed
            }
            plan = builtPlan
            let selected = try ReviewSelection(
                plan: builtPlan,
                generation: 1,
                items: [
                    ReviewSelectionItem(
                        itemID: item.id,
                        origin: .defaultReady
                    ),
                ],
                dispositions: [item.id: .readyToReclaim]
            )
            selection = selected
            let evaluation = try await dependencies.preflightReview(
                builtPlan,
                selected
            )
            guard let admitted = evaluation.allowed?.confirmation else {
                throw PhaseCTrashDiagnosticError.policyFailed
            }
            confirmation = admitted
            let execution = try await dependencies.startReviewExecution(
                builtPlan,
                selected,
                admitted
            )
            var terminal: CleanupExecutionState?
            for await event in execution {
                if case let .terminal(value) = event {
                    terminal = value
                }
            }
            guard let terminal else {
                throw PhaseCTrashDiagnosticError.executionFailed
            }
            guard let completedResult = terminal.phaseCDiagnosticResult else {
                throw terminal.phaseCDiagnosticFailure
                    ?? PhaseCTrashDiagnosticError.executionFailed
            }
            result = completedResult
            guard terminal.isCompleted,
                  completedResult.manifest.summary.succeededCount == 1,
                  completedResult.manifest.summary.failedCount == 0,
                  completedResult.manifest.summary.unknownCount == 0,
                  completedResult.manifest.summary
                    .permanentlyReleasedLogicalBytes == ByteCount(0),
                  completedResult.journal.entries.first?.outcome?
                    .destinationIdentity == identity,
                  let trashURL = observation.trashURL(),
                  FileIdentity.read(at: trashURL) == identity,
                  !pathExists(itemURL)
            else {
                throw PhaseCTrashDiagnosticError.receiptMismatch
            }
            let destinationIdentity = FileIdentity.read(at: trashURL)
            let restore = PhaseCTrashDiagnosticRestore.restoreIfNeeded(
                existingOutcome: restoreOutcome,
                returnedTrashURL: trashURL,
                originalURL: itemURL,
                expectedIdentity: identity,
                expectedDestinationParentIdentity: parentIdentity,
                marker: itemMarker,
                markerName: itemMarkerName
            )
            restoreOutcome = restore
            let trashAttemptCount = observation.attemptCount()
            let residual = residual(
                originalURL: itemURL,
                returnedTrashURL: trashURL,
                expectedIdentity: identity,
                fixtureRoot: root,
                trashWasAttempted: trashAttemptCount > 0
            )
            guard trashAttemptCount == 1,
                  restore == .restored,
                  residual.originalPresent,
                  residual.trashPresent == false,
                  residual.fixtureRootPresent
            else {
                throw PhaseCTrashDiagnosticError.receiptMismatch
            }
            return report(
                config: config,
                signing: signing,
                startedAt: startedAt,
                outcome: "signedAppTrashReady",
                configured: true,
                planned: true,
                observed: true,
                contained: true,
                restored: true,
                plan: builtPlan,
                selection: selected,
                confirmation: admitted,
                originalIdentity: identity,
                returnedTrashURL: trashURL,
                destinationIdentity: destinationIdentity,
                trashAttemptCount: trashAttemptCount,
                result: completedResult,
                restoreOutcome: restore,
                residual: residual,
                errorStage: nil,
                error: nil
            )
        } catch let error as PhaseCTrashDiagnosticError {
            return blockedReport(
                error: error,
                config: config,
                signing: signing,
                startedAt: startedAt,
                itemURL: itemURL,
                itemMarker: itemMarker,
                itemMarkerName: itemMarkerName,
                fixtureRoot: root,
                originalIdentity: originalIdentity,
                destinationParentIdentity: destinationParentIdentity,
                observation: observation,
                plan: plan,
                selection: selection,
                confirmation: confirmation,
                result: result,
                existingRestoreOutcome: restoreOutcome
            )
        } catch {
            return blockedReport(
                error: .executionFailed,
                config: config,
                signing: signing,
                startedAt: startedAt,
                itemURL: itemURL,
                itemMarker: itemMarker,
                itemMarkerName: itemMarkerName,
                fixtureRoot: root,
                originalIdentity: originalIdentity,
                destinationParentIdentity: destinationParentIdentity,
                observation: observation,
                plan: plan,
                selection: selection,
                confirmation: confirmation,
                result: result,
                existingRestoreOutcome: restoreOutcome
            )
        }
    }

    static func createFixture(
        diagnosticRoot: URL,
        fixtureRoot: URL,
        itemURL: URL,
        nonce: String,
        markerName: String,
        marker: String
    ) throws {
        try FileManager.default.createDirectory(
            at: itemURL.appending(
                path: "content-v2/sha512",
                directoryHint: .isDirectory
            ),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try Data("stornaut-phase-c-root:\(nonce)".utf8).write(
            to: diagnosticRoot.appending(
                path: ".stornaut-phase-c-trash-fixture-\(nonce)"
            ),
            options: .withoutOverwriting
        )
        try Data(marker.utf8).write(
            to: itemURL.appending(path: markerName),
            options: .withoutOverwriting
        )
        try Data("disposable-phase-c-cache:\(nonce)".utf8).write(
            to: itemURL.appending(
                path: "content-v2/sha512/disposable"
            ),
            options: .withoutOverwriting
        )
        for url in [
            diagnosticRoot,
            fixtureRoot,
            itemURL.deletingLastPathComponent(),
            itemURL,
        ] {
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: url.path
            )
        }
    }

    private static func requireIdentity(
        _ url: URL
    ) throws -> FileIdentity {
        guard let identity = FileIdentity.read(at: url) else {
            throw PhaseCTrashDiagnosticError.fixtureMismatch
        }
        return identity
    }

    private static func requireDirectoryIdentity(
        _ url: URL
    ) throws -> FileIdentity {
        guard let identity = FileIdentity.read(at: url),
              identity.isDirectory,
              !identity.isSymbolicLink
        else {
            throw PhaseCTrashDiagnosticError.fixtureMismatch
        }
        return identity
    }

    private static func blockedReport(
        error: PhaseCTrashDiagnosticError,
        config: PhaseCTrashDiagnosticConfiguration,
        signing: LifecycleBundleSigningEvidence,
        startedAt: Date,
        itemURL: URL,
        itemMarker: String,
        itemMarkerName: String,
        fixtureRoot: URL,
        originalIdentity: FileIdentity?,
        destinationParentIdentity: FileIdentity?,
        observation: CleanupTrashDiagnosticObservation,
        plan: CleanupPlan?,
        selection: ReviewSelection?,
        confirmation: CleanupConfirmation?,
        result: CleanupExecutionResult?,
        existingRestoreOutcome:
            PhaseCTrashDiagnosticRestoreOutcome?
    ) -> PhaseCTrashDiagnosticReport {
        let trashURL = observation.trashURL()
        let trashAttemptCount = observation.attemptCount()
        let destinationIdentity = trashURL.flatMap(FileIdentity.read(at:))
        var restoreOutcome = existingRestoreOutcome
        if let result,
           result.manifest.summary.succeededCount == 1,
           result.manifest.summary.failedCount == 0,
           result.manifest.summary.unknownCount == 0,
           let originalIdentity,
           let destinationParentIdentity,
           let trashURL,
           destinationIdentity == originalIdentity,
           result.journal.entries.first?.outcome?
            .destinationIdentity == originalIdentity,
           !pathExists(itemURL)
        {
            restoreOutcome =
                PhaseCTrashDiagnosticRestore.restoreIfNeeded(
                    existingOutcome: restoreOutcome,
                    returnedTrashURL: trashURL,
                    originalURL: itemURL,
                    expectedIdentity: originalIdentity,
                    expectedDestinationParentIdentity:
                        destinationParentIdentity,
                    marker: itemMarker,
                    markerName: itemMarkerName
                )
        }
        return report(
            config: config,
            signing: signing,
            startedAt: startedAt,
            outcome: "signedAppTrashBlocked",
            configured: true,
            planned: plan != nil && selection != nil,
            observed: result != nil && trashURL != nil,
            contained: result.map {
                $0.manifest.summary
                    .permanentlyReleasedLogicalBytes == ByteCount(0)
                    && $0.manifest.summary.unknownCount == 0
            } ?? false,
            restored: restoreOutcome == .restored,
            plan: plan,
            selection: selection,
            confirmation: confirmation,
            originalIdentity: originalIdentity,
            returnedTrashURL: trashURL,
            destinationIdentity: destinationIdentity,
            trashAttemptCount: trashAttemptCount,
            result: result,
            restoreOutcome: restoreOutcome,
            residual: residual(
                originalURL: itemURL,
                returnedTrashURL: trashURL,
                expectedIdentity: originalIdentity,
                fixtureRoot: fixtureRoot,
                trashWasAttempted: trashAttemptCount > 0
            ),
            errorStage: error.stage,
            error: error
        )
    }

    private static func report(
        config: PhaseCTrashDiagnosticConfiguration,
        signing: LifecycleBundleSigningEvidence,
        startedAt: Date,
        outcome: String,
        configured: Bool,
        planned: Bool,
        observed: Bool,
        contained: Bool,
        restored: Bool,
        plan: CleanupPlan?,
        selection: ReviewSelection?,
        confirmation: CleanupConfirmation?,
        originalIdentity: FileIdentity?,
        returnedTrashURL: URL?,
        destinationIdentity: FileIdentity?,
        trashAttemptCount: Int,
        result: CleanupExecutionResult?,
        restoreOutcome: PhaseCTrashDiagnosticRestoreOutcome?,
        residual: PhaseCTrashDiagnosticResidual,
        errorStage: String?,
        error: PhaseCTrashDiagnosticError?
    ) -> PhaseCTrashDiagnosticReport {
        let summary = result?.manifest.summary
        return PhaseCTrashDiagnosticReport(
            schemaVersion: 2,
            nonce: config.nonce,
            startedAt: startedAt,
            finishedAt: Date(),
            outcome: outcome,
            configured: configured,
            planned: planned,
            observed: observed,
            contained: contained,
            restored: restored,
            bundleIdentifier: signing.identity.signingIdentifier,
            executablePath: Bundle.main.executableURL?
                .standardizedFileURL.path,
            executableSHA256: signing.executableSHA256,
            designatedRequirementSHA256:
                signing.identity.designatedRequirementSHA256,
            codeDirectoryHash: signing.identity.codeDirectoryHash,
            adHocSigned: signing.isAdHoc,
            appSandboxEntitlement: currentAppSandboxEntitlement(),
            expectedRelativePath: config.expectedRelativePath,
            planID: plan?.id.rawValue,
            selectionGeneration: selection?.generation,
            selectionFingerprint: selection?.fingerprint.rawValue,
            decisionFingerprint: confirmation?
                .decisionFingerprint.rawValue,
            originalIdentity: originalIdentity,
            returnedTrashPath: returnedTrashURL?.path,
            destinationIdentity: destinationIdentity,
            trashAttemptCount: trashAttemptCount,
            journalID: result?.journal.id.rawValue,
            journalStage: result?.journal.stage.rawValue,
            journalEntryCount: result?.journal.entries.count,
            manifestID: result?.manifest.id.rawValue,
            manifestRecordCount: result?.manifest.records.count,
            succeededCount: summary?.succeededCount,
            failedCount: summary?.failedCount,
            cancelledCount: summary?.cancelledCount,
            unknownCount: summary?.unknownCount,
            selectedLogicalBytes: summary?.selectedLogicalBytes.value,
            processedLogicalBytes: summary?.processedLogicalBytes.value,
            movedToTrashLogicalBytes:
                summary?.movedToTrashLogicalBytes.value,
            permanentlyReleasedLogicalBytes:
                summary?.permanentlyReleasedLogicalBytes.value,
            systemObservationRecorded:
                result?.manifest.systemObservation != nil,
            restoreOutcome: restoreOutcome,
            residual: residual,
            errorStage: errorStage,
            error: error,
            limitations: [
                "diagnostic-owned disposable fixture only",
                "FDA and TCC inheritance not evaluated",
                "release distribution not evaluated",
                "unrelated user paths not evaluated",
            ]
        )
    }

    private static func residual(
        originalURL: URL,
        returnedTrashURL: URL?,
        expectedIdentity: FileIdentity?,
        fixtureRoot: URL,
        trashWasAttempted: Bool
    ) -> PhaseCTrashDiagnosticResidual {
        PhaseCTrashDiagnosticResidual.make(
            originalURL: originalURL,
            returnedTrashURL: returnedTrashURL,
            expectedIdentity: expectedIdentity,
            fixtureRoot: fixtureRoot,
            trashWasAttempted: trashWasAttempted
        )
    }

    private static func write(
        _ report: PhaseCTrashDiagnosticReport,
        reportURL: URL
    ) {
        guard let encoded = try? JSONEncoder.phaseC.encode(report) else {
            return
        }
        try? writeExclusivePrivate(encoded, to: reportURL)
    }

    private static func writePreflightReceipt(
        _ receipt: PhaseCTrashDiagnosticPreflightReceipt,
        configURL: URL
    ) {
        guard let reportURL =
            phaseCTrashDiagnosticPreflightReceiptURL(
                configURL: configURL
            ),
            let encoded = try? JSONEncoder.phaseC.encode(receipt)
        else {
            return
        }
        try? writeExclusivePrivate(encoded, to: reportURL)
    }
}

private struct PhaseCTrashDiagnosticRunResult: Sendable {
    let report: PhaseCTrashDiagnosticReport
    let reportURL: URL
}

struct PhaseCTrashDiagnosticResidual:
    Codable,
    Sendable,
    Equatable
{
    let originalPresent: Bool
    let trashPresent: Bool?
    let fixtureRootPresent: Bool

    static func make(
        originalURL: URL,
        returnedTrashURL: URL?,
        expectedIdentity: FileIdentity?,
        fixtureRoot: URL,
        trashWasAttempted: Bool
    ) -> Self {
        let originalPresent = expectedIdentity.map {
            FileIdentity.read(at: originalURL) == $0
        } ?? pathExists(originalURL)
        let trashPresent: Bool?
        if let returnedTrashURL {
            if let expectedIdentity {
                if FileIdentity.read(at: returnedTrashURL)
                    == expectedIdentity
                {
                    trashPresent = true
                } else if pathPresence(returnedTrashURL) == true {
                    trashPresent = nil
                } else if pathPresence(returnedTrashURL) == false {
                    trashPresent =
                        trashWasAttempted && !originalPresent
                        ? nil
                        : false
                } else {
                    trashPresent = nil
                }
            } else {
                trashPresent = pathPresence(returnedTrashURL)
            }
        } else if trashWasAttempted && !originalPresent {
            trashPresent = nil
        } else {
            trashPresent = false
        }
        return Self(
            originalPresent: originalPresent,
            trashPresent: trashPresent,
            fixtureRootPresent: pathExists(fixtureRoot)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(
            originalPresent,
            forKey: .originalPresent
        )
        try container.encode(trashPresent, forKey: .trashPresent)
        try container.encode(
            fixtureRootPresent,
            forKey: .fixtureRootPresent
        )
    }

    enum CodingKeys: String, CodingKey {
        case originalPresent
        case trashPresent
        case fixtureRootPresent
    }
}

struct PhaseCTrashDiagnosticReport: Codable, Sendable, Equatable {
    let schemaVersion: Int
    let nonce: String
    let startedAt: Date
    let finishedAt: Date
    let outcome: String
    let configured: Bool
    let planned: Bool
    let observed: Bool
    let contained: Bool
    let restored: Bool
    let bundleIdentifier: String
    let executablePath: String?
    let executableSHA256: String?
    let designatedRequirementSHA256: String
    let codeDirectoryHash: String
    let adHocSigned: Bool?
    let appSandboxEntitlement: Bool?
    let expectedRelativePath: String?
    let planID: String?
    let selectionGeneration: UInt64?
    let selectionFingerprint: String?
    let decisionFingerprint: String?
    let originalIdentity: FileIdentity?
    let returnedTrashPath: String?
    let destinationIdentity: FileIdentity?
    let trashAttemptCount: Int
    let journalID: String?
    let journalStage: String?
    let journalEntryCount: Int?
    let manifestID: String?
    let manifestRecordCount: Int?
    let succeededCount: Int?
    let failedCount: Int?
    let cancelledCount: Int?
    let unknownCount: Int?
    let selectedLogicalBytes: UInt64?
    let processedLogicalBytes: UInt64?
    let movedToTrashLogicalBytes: UInt64?
    let permanentlyReleasedLogicalBytes: UInt64?
    let systemObservationRecorded: Bool
    let restoreOutcome: PhaseCTrashDiagnosticRestoreOutcome?
    let residual: PhaseCTrashDiagnosticResidual
    let errorStage: String?
    let error: PhaseCTrashDiagnosticError?
    let limitations: [String]

    static let requiredJSONKeys = Set(
        CodingKeys.allCases.map(\.stringValue)
    )

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(nonce, forKey: .nonce)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(finishedAt, forKey: .finishedAt)
        try container.encode(outcome, forKey: .outcome)
        try container.encode(configured, forKey: .configured)
        try container.encode(planned, forKey: .planned)
        try container.encode(observed, forKey: .observed)
        try container.encode(contained, forKey: .contained)
        try container.encode(restored, forKey: .restored)
        try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encode(executablePath, forKey: .executablePath)
        try container.encode(executableSHA256, forKey: .executableSHA256)
        try container.encode(
            designatedRequirementSHA256,
            forKey: .designatedRequirementSHA256
        )
        try container.encode(
            codeDirectoryHash,
            forKey: .codeDirectoryHash
        )
        try container.encode(adHocSigned, forKey: .adHocSigned)
        try container.encode(
            appSandboxEntitlement,
            forKey: .appSandboxEntitlement
        )
        try container.encode(
            expectedRelativePath,
            forKey: .expectedRelativePath
        )
        try container.encode(planID, forKey: .planID)
        try container.encode(
            selectionGeneration,
            forKey: .selectionGeneration
        )
        try container.encode(
            selectionFingerprint,
            forKey: .selectionFingerprint
        )
        try container.encode(
            decisionFingerprint,
            forKey: .decisionFingerprint
        )
        try container.encode(
            originalIdentity,
            forKey: .originalIdentity
        )
        try container.encode(
            returnedTrashPath,
            forKey: .returnedTrashPath
        )
        try container.encode(
            destinationIdentity,
            forKey: .destinationIdentity
        )
        try container.encode(
            trashAttemptCount,
            forKey: .trashAttemptCount
        )
        try container.encode(journalID, forKey: .journalID)
        try container.encode(journalStage, forKey: .journalStage)
        try container.encode(
            journalEntryCount,
            forKey: .journalEntryCount
        )
        try container.encode(manifestID, forKey: .manifestID)
        try container.encode(
            manifestRecordCount,
            forKey: .manifestRecordCount
        )
        try container.encode(succeededCount, forKey: .succeededCount)
        try container.encode(failedCount, forKey: .failedCount)
        try container.encode(cancelledCount, forKey: .cancelledCount)
        try container.encode(unknownCount, forKey: .unknownCount)
        try container.encode(
            selectedLogicalBytes,
            forKey: .selectedLogicalBytes
        )
        try container.encode(
            processedLogicalBytes,
            forKey: .processedLogicalBytes
        )
        try container.encode(
            movedToTrashLogicalBytes,
            forKey: .movedToTrashLogicalBytes
        )
        try container.encode(
            permanentlyReleasedLogicalBytes,
            forKey: .permanentlyReleasedLogicalBytes
        )
        try container.encode(
            systemObservationRecorded,
            forKey: .systemObservationRecorded
        )
        try container.encode(restoreOutcome, forKey: .restoreOutcome)
        try container.encode(residual, forKey: .residual)
        try container.encode(errorStage, forKey: .errorStage)
        try container.encode(error, forKey: .error)
        try container.encode(limitations, forKey: .limitations)
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case nonce
        case startedAt
        case finishedAt
        case outcome
        case configured
        case planned
        case observed
        case contained
        case restored
        case bundleIdentifier
        case executablePath
        case executableSHA256
        case designatedRequirementSHA256
        case codeDirectoryHash
        case adHocSigned
        case appSandboxEntitlement
        case expectedRelativePath
        case planID
        case selectionGeneration
        case selectionFingerprint
        case decisionFingerprint
        case originalIdentity
        case returnedTrashPath
        case destinationIdentity
        case trashAttemptCount
        case journalID
        case journalStage
        case journalEntryCount
        case manifestID
        case manifestRecordCount
        case succeededCount
        case failedCount
        case cancelledCount
        case unknownCount
        case selectedLogicalBytes
        case processedLogicalBytes
        case movedToTrashLogicalBytes
        case permanentlyReleasedLogicalBytes
        case systemObservationRecorded
        case restoreOutcome
        case residual
        case errorStage
        case error
        case limitations
    }
}

private func loadConfigurationData(_ url: URL) throws -> Data {
    guard safeConfigFile(url) else {
        throw PhaseCTrashDiagnosticError.invalidConfiguration
    }
    let data = try Data(contentsOf: url, options: .mappedIfSafe)
    guard !data.isEmpty, data.count <= 65_536 else {
        throw PhaseCTrashDiagnosticError.invalidConfiguration
    }
    return data
}

private func currentAppSandboxEntitlement() -> Bool? {
    guard let task = SecTaskCreateFromSelf(kCFAllocatorDefault),
          let value = SecTaskCopyValueForEntitlement(
              task,
              "com.apple.security.app-sandbox" as CFString,
              nil
          )
    else {
        return nil
    }
    return value as? Bool
}

private func writeExclusivePrivate(
    _ data: Data,
    to url: URL
) throws {
    let descriptor = open(
        url.path,
        O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
        0o600
    )
    guard descriptor >= 0 else {
        throw PhaseCTrashDiagnosticError.unsafePath
    }
    defer { close(descriptor) }
    try data.withUnsafeBytes { bytes in
        var offset = 0
        while offset < bytes.count {
            let count = Darwin.write(
                descriptor,
                bytes.baseAddress!.advanced(by: offset),
                bytes.count - offset
            )
            guard count > 0 else {
                throw PhaseCTrashDiagnosticError.unsafePath
            }
            offset += count
        }
    }
    guard fsync(descriptor) == 0 else {
        throw PhaseCTrashDiagnosticError.unsafePath
    }
}

extension CleanupExecutionState {
    var phaseCDiagnosticResult: CleanupExecutionResult? {
        switch self {
        case let .completed(result),
             let .partiallyFailed(result),
             let .stopped(result),
             let .auditPending(result),
             let .recoveryRequired(result):
            result
        case .recoveryBlocked, .recoveryCorrupt, .stale, .rejected:
            nil
        }
    }

    var phaseCDiagnosticFailure: PhaseCTrashDiagnosticError? {
        guard case let .rejected(rejection) = self else {
            return nil
        }
        return switch rejection {
        case .authorization:
            .executionRejectedAuthorization
        case .workflowConflict:
            .executionRejectedWorkflowConflict
        case .planMismatch:
            .executionRejectedPlanMismatch
        case .persistence:
            .executionRejectedPersistence
        case .programmingError:
            .executionRejectedProgrammingError
        }
    }
}

private extension JSONDecoder {
    static var phaseC: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}

private extension JSONEncoder {
    static var phaseC: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private func safeDiagnosticRoot(
    _ url: URL,
    configURL: URL
) -> Bool {
    var information = stat()
    guard lstat(url.path, &information) == 0,
          information.st_mode & S_IFMT == S_IFDIR,
          information.st_mode & 0o777 == 0o700,
          information.st_uid == geteuid(),
          information.st_nlink >= 1,
          FileIdentity.read(at: url)?.isSymbolicLink == false,
          let entries = try? FileManager.default.contentsOfDirectory(
              at: url,
              includingPropertiesForKeys: nil,
              options: []
          )
    else {
        return false
    }
    return entries.map(\.standardizedFileURL) == [
        configURL.standardizedFileURL,
    ]
}

private func safeConfigFile(_ url: URL) -> Bool {
    var information = stat()
    return lstat(url.path, &information) == 0
        && information.st_mode & S_IFMT == S_IFREG
        && information.st_mode & 0o777 == 0o600
        && information.st_uid == geteuid()
        && information.st_nlink == 1
}

func phaseCTrashDiagnosticPreflightReceiptURL(
    configURL: URL
) -> URL? {
    let config = configURL.standardizedFileURL
    let root = config.deletingLastPathComponent()
    guard config.lastPathComponent == "config.json",
          safeDiagnosticRoot(root, configURL: config),
          safeConfigFile(config)
    else {
        return nil
    }
    let receipt = root.appending(path: "preflight-error.json")
    guard !pathExists(receipt) else {
        return nil
    }
    return receipt
}

private func pathExists(_ url: URL) -> Bool {
    pathPresence(url) == true
}

private func pathPresence(_ url: URL) -> Bool? {
    var information = stat()
    errno = 0
    if lstat(url.path, &information) == 0 {
        return true
    }
    return errno == ENOENT ? false : nil
}

private func validDescriptorRelativeName(_ value: String) -> Bool {
    !value.isEmpty
        && value != "."
        && value != ".."
        && !value.contains("/")
        && value.utf8.count <= NAME_MAX
}

private func descriptorIdentity(_ descriptor: Int32) -> FileIdentity? {
    var information = stat()
    guard fstat(descriptor, &information) == 0 else {
        return nil
    }
    return fileIdentity(information)
}

private func descriptorRelativeIdentity(
    parentDescriptor: Int32,
    name: String
) -> FileIdentity? {
    guard validDescriptorRelativeName(name) else {
        return nil
    }
    var information = stat()
    let result = name.withCString {
        fstatat(
            parentDescriptor,
            $0,
            &information,
            AT_SYMLINK_NOFOLLOW
        )
    }
    guard result == 0 else {
        return nil
    }
    return fileIdentity(information)
}

private func descriptorRelativePathExists(
    parentDescriptor: Int32,
    name: String
) -> Bool? {
    guard validDescriptorRelativeName(name) else {
        return nil
    }
    var information = stat()
    errno = 0
    let result = name.withCString {
        fstatat(
            parentDescriptor,
            $0,
            &information,
            AT_SYMLINK_NOFOLLOW
        )
    }
    if result == 0 {
        return true
    }
    return errno == ENOENT ? false : nil
}

private func descriptorRelativeText(
    parentDescriptor: Int32,
    name: String,
    maximumSize: Int
) -> String? {
    guard validDescriptorRelativeName(name), maximumSize > 0 else {
        return nil
    }
    let descriptor = name.withCString {
        openat(
            parentDescriptor,
            $0,
            O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK
        )
    }
    guard descriptor >= 0 else {
        return nil
    }
    defer { close(descriptor) }
    var information = stat()
    guard fstat(descriptor, &information) == 0,
          information.st_mode & S_IFMT == S_IFREG,
          information.st_mode & 0o022 == 0,
          information.st_uid == geteuid(),
          information.st_nlink == 1,
          information.st_size > 0,
          information.st_size <= maximumSize
    else {
        return nil
    }
    var data = Data(count: Int(information.st_size))
    let count = data.withUnsafeMutableBytes {
        Darwin.read(descriptor, $0.baseAddress, $0.count)
    }
    guard count == data.count else {
        return nil
    }
    return String(decoding: data, as: UTF8.self)
}

private func fileIdentity(_ information: stat) -> FileIdentity? {
    let allocated = Int64(information.st_blocks)
        .multipliedReportingOverflow(by: 512)
    guard !allocated.overflow else {
        return nil
    }
    return try? FileIdentity(
        device: UInt64(bitPattern: Int64(information.st_dev)),
        inode: UInt64(information.st_ino),
        mode: UInt16(information.st_mode),
        ownerUserID: information.st_uid,
        ownerGroupID: information.st_gid,
        linkCount: UInt64(information.st_nlink),
        size: max(0, Int64(information.st_size)),
        allocatedBytes: max(0, allocated.partialValue),
        modificationSeconds: Int64(information.st_mtimespec.tv_sec),
        modificationNanoseconds: Int64(
            information.st_mtimespec.tv_nsec
        )
    )
}

private func sameDirectory(_ lhs: URL, _ rhs: URL) -> Bool {
    var lhsInformation = stat()
    var rhsInformation = stat()
    return lstat(lhs.path, &lhsInformation) == 0
        && lstat(rhs.path, &rhsInformation) == 0
        && lhsInformation.st_mode & S_IFMT == S_IFDIR
        && rhsInformation.st_mode & S_IFMT == S_IFDIR
        && lhsInformation.st_dev == rhsInformation.st_dev
        && lhsInformation.st_ino == rhsInformation.st_ino
}

private func sameFileObject(
    _ observed: FileIdentity?,
    _ expected: FileIdentity
) -> Bool {
    guard let observed,
          observed.isDirectory,
          !observed.isSymbolicLink
    else {
        return false
    }
    return observed.device == expected.device
        && observed.inode == expected.inode
}

private func validSHA256(_ value: String) -> Bool {
    value.count == 64
        && value.unicodeScalars.allSatisfy {
            (0x30...0x39).contains($0.value)
                || (0x61...0x66).contains($0.value)
        }
}

private func isNormalizedAbsolutePath(_ value: String) -> Bool {
    guard value.hasPrefix("/"),
          value != "/",
          !value.hasSuffix("/"),
          !value.contains("//"),
          value.utf8.count <= PATH_MAX
    else {
        return false
    }
    return value.split(
        separator: "/",
        omittingEmptySubsequences: false
    ).dropFirst().allSatisfy {
        !$0.isEmpty && $0 != "." && $0 != ".."
    }
}
#endif
