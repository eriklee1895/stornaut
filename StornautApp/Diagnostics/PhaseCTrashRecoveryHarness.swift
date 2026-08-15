#if DEBUG
import AppKit
import CryptoKit
import Darwin
import Foundation
import Security
import StornautCore
import StornautLifecycle

enum PhaseCTrashRecoveryError:
    String,
    Error,
    Codable,
    Sendable,
    Equatable
{
    case invalidConfiguration
    case unsafePath
    case invalidAbsolutePath
    case unsafeRecoveryConfig
    case recoveryReceiptExists
    case unsafeDiagnosticRoot
    case unsafeRetainedEvidencePath
    case unsafeStorePath
    case unsafeTrashPath
    case optInMismatch
    case buildMismatch
    case expired
    case retainedEvidenceMismatch
    case journalMismatch
    case recoveryFailed
    case executorReplay
    case restoreFailed
    case receiptMismatch
}

struct PhaseCTrashRecoveryLaunchRequest:
    Sendable,
    Equatable
{
    private static let argumentPrefix =
        "--stornaut-phase-c-trash-recovery-config="
    private static let trashArgumentPrefix =
        "--stornaut-phase-c-trash-config"

    let configURL: URL

    init?(arguments: [String]) {
        guard !arguments.contains(where: {
            $0.hasPrefix(Self.trashArgumentPrefix)
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

struct PhaseCTrashRecoveryConfiguration:
    Codable,
    Sendable,
    Equatable
{
    static let schemaVersion = 1
    static let optInEnvironmentKey =
        "STORNAUT_PHASE_C_TRASH_RECOVERY_OPT_IN"
    static let optInStatement =
        "I authorize Stornaut Task 35 to recover the retained journal and restore only its exact disposable fixture without another Trash attempt."
    static let expectedRelativePath = ".npm/_cacache"

    let schemaVersion: Int
    let recoveryNonce: String
    let recoveryOptInStatement: String
    let recoveryOptInNonce: String
    let diagnosticNonce: String
    let diagnosticRoot: String
    let retainedConfigPath: String
    let retainedReportPath: String
    let applicationSupportBase: String
    let cachesBase: String
    let evidenceDatabasePath: String
    let recoveryReportPath: String
    let expectedBundleIdentifier: String
    let expectedRecoveryExecutableSHA256: String
    let expectedOriginalExecutableSHA256: String
    let expectedRetainedConfigSHA256: String
    let expectedRetainedReportSHA256: String
    let expectedDatabaseSHA256: String
    let expectedRelativePath: String
    let expectedJournalID: String
    let expectedManifestID: String
    let expectedOriginalIdentity: FileIdentity
    let expectedDestinationParentIdentity: FileIdentity
    let expectedReturnedTrashPath: String
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
        ) as? [String: Any],
        Set(object.keys) == Set(
            CodingKeys.allCases.map(\.stringValue)
        ),
        let value = try? JSONDecoder.phaseCRecovery.decode(
            Self.self,
            from: data
        )
        else {
            throw PhaseCTrashRecoveryError.invalidConfiguration
        }
        guard value.schemaVersion == schemaVersion,
              UUID(uuidString: value.recoveryNonce) != nil,
              UUID(uuidString: value.recoveryOptInNonce) != nil,
              UUID(uuidString: value.diagnosticNonce) != nil,
              value.recoveryOptInStatement == optInStatement,
              environment[optInEnvironmentKey]
                == value.recoveryOptInNonce,
              value.expectedBundleIdentifier
                == "com.eriklee.stornaut",
              bundleIdentifier == value.expectedBundleIdentifier,
              validRecoverySHA256(
                value.expectedRecoveryExecutableSHA256
              ),
              executableSHA256
                == value.expectedRecoveryExecutableSHA256,
              validRecoverySHA256(
                value.expectedOriginalExecutableSHA256
              ),
              validRecoverySHA256(
                value.expectedRetainedConfigSHA256
              ),
              validRecoverySHA256(
                value.expectedRetainedReportSHA256
              ),
              validRecoverySHA256(value.expectedDatabaseSHA256),
              value.expectedRelativePath == expectedRelativePath,
              CleanupRunID(rawValue: value.expectedJournalID) != nil,
              CleanupManifestID(
                rawValue: value.expectedManifestID
              ) != nil,
              value.expectedOriginalIdentity.isDirectory,
              !value.expectedOriginalIdentity.isSymbolicLink,
              value.expectedDestinationParentIdentity.isDirectory,
              !value.expectedDestinationParentIdentity.isSymbolicLink,
              value.issuedAt.timeIntervalSince1970.isFinite,
              value.expiresAt.timeIntervalSince1970.isFinite,
              value.issuedAt <= now,
              now <= value.expiresAt,
              value.expiresAt.timeIntervalSince(value.issuedAt) <= 300
        else {
            if environment[optInEnvironmentKey]
                != (object["recoveryOptInNonce"] as? String)
            {
                throw PhaseCTrashRecoveryError.optInMismatch
            }
            if bundleIdentifier
                != (object["expectedBundleIdentifier"] as? String)
                || executableSHA256
                != (
                    object["expectedRecoveryExecutableSHA256"]
                        as? String
                )
            {
                throw PhaseCTrashRecoveryError.buildMismatch
            }
            if let expiresAt = object["expiresAt"] as? TimeInterval,
               now.timeIntervalSince1970 > expiresAt
            {
                throw PhaseCTrashRecoveryError.expired
            }
            throw PhaseCTrashRecoveryError.invalidConfiguration
        }

        let config = configURL.standardizedFileURL
        let root = URL(filePath: value.diagnosticRoot)
            .standardizedFileURL
        let retainedConfig = URL(
            filePath: value.retainedConfigPath
        ).standardizedFileURL
        let retainedReport = URL(
            filePath: value.retainedReportPath
        ).standardizedFileURL
        let support = URL(
            filePath: value.applicationSupportBase
        ).standardizedFileURL
        let caches = URL(filePath: value.cachesBase)
            .standardizedFileURL
        let database = URL(
            filePath: value.evidenceDatabasePath
        ).standardizedFileURL
        let recoveryReport = URL(
            filePath: value.recoveryReportPath
        ).standardizedFileURL
        let returnedTrash = URL(
            filePath: value.expectedReturnedTrashPath
        ).standardizedFileURL
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .standardizedFileURL
        let expectedTrashParent = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".Trash", directoryHint: .isDirectory)
            .standardizedFileURL

        guard [
            value.diagnosticRoot,
            value.retainedConfigPath,
            value.retainedReportPath,
            value.applicationSupportBase,
            value.cachesBase,
            value.evidenceDatabasePath,
            value.recoveryReportPath,
            value.expectedReturnedTrashPath,
        ].allSatisfy(isNormalizedRecoveryAbsolutePath)
        else {
            throw PhaseCTrashRecoveryError.invalidAbsolutePath
        }
        guard recoveryArtifactNonce(
                config,
                prefix: "recovery-config-"
              ) == value.recoveryNonce,
              sameRecoveryDirectory(
                config.deletingLastPathComponent(),
                root
              ),
              sameRecoveryDirectory(
                root.deletingLastPathComponent(),
                temporaryDirectory
              ),
              root.lastPathComponent.hasPrefix(
                "stornaut-phase-c-trash."
              ),
              safeRecoveryDirectory(root)
        else {
            throw PhaseCTrashRecoveryError.unsafeDiagnosticRoot
        }
        guard
        retainedConfig.path == root.appending(path: "config.json").path,
        retainedReport.path == root.appending(path: "report.json").path,
        safeRecoveryRegularFile(
            retainedConfig,
            maximumSize: 65_536
        ),
        safeRecoveryRegularFile(
            retainedReport,
            maximumSize: 262_144
        )
        else {
            throw PhaseCTrashRecoveryError.unsafeRetainedEvidencePath
        }
        guard
        support.path == root.appending(path: "support").path,
        caches.path == root.appending(path: "caches").path,
        database.path == support.appending(
            path: "com.eriklee.stornaut/Evidence.sqlite"
        ).path,
        safeRecoveryRegularFile(
            database,
            maximumSize: 64 * 1_024 * 1_024
        ),
        safeRecoveryDirectory(support),
        safeRecoveryDirectory(caches)
        else {
            throw PhaseCTrashRecoveryError.unsafeStorePath
        }
        guard recoveryReport.lastPathComponent
                == "recovery-report-\(value.recoveryNonce).json",
        sameRecoveryDirectory(
            recoveryReport.deletingLastPathComponent(),
            root
        ),
        safeRecoveryRegularFile(config, maximumSize: 65_536)
        else {
            throw PhaseCTrashRecoveryError.unsafeRecoveryConfig
        }
        guard recoveryPathPresence(recoveryReport) == false else {
            throw PhaseCTrashRecoveryError.recoveryReceiptExists
        }
        guard
        sameRecoveryDirectory(
            returnedTrash.deletingLastPathComponent(),
            expectedTrashParent
        ),
        returnedTrash.lastPathComponent == "_cacache"
        else {
            throw PhaseCTrashRecoveryError.unsafeTrashPath
        }
        guard
        sha256File(retainedConfig)
            == value.expectedRetainedConfigSHA256,
        sha256File(retainedReport)
            == value.expectedRetainedReportSHA256,
        sha256File(database) == value.expectedDatabaseSHA256
        else {
            throw PhaseCTrashRecoveryError
                .retainedEvidenceMismatch
        }
        return value
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map {
            String(format: "%02x", $0)
        }.joined()
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case recoveryNonce
        case recoveryOptInStatement
        case recoveryOptInNonce
        case diagnosticNonce
        case diagnosticRoot
        case retainedConfigPath
        case retainedReportPath
        case applicationSupportBase
        case cachesBase
        case evidenceDatabasePath
        case recoveryReportPath
        case expectedBundleIdentifier
        case expectedRecoveryExecutableSHA256
        case expectedOriginalExecutableSHA256
        case expectedRetainedConfigSHA256
        case expectedRetainedReportSHA256
        case expectedDatabaseSHA256
        case expectedRelativePath
        case expectedJournalID
        case expectedManifestID
        case expectedOriginalIdentity
        case expectedDestinationParentIdentity
        case expectedReturnedTrashPath
        case issuedAt
        case expiresAt
    }
}

struct PhaseCTrashRecoveryReport:
    Codable,
    Sendable,
    Equatable
{
    let schemaVersion: Int
    let recoveryNonce: String
    let diagnosticNonce: String
    let startedAt: Date
    let finishedAt: Date
    let outcome: String
    let bundleIdentifier: String
    let recoveryExecutablePath: String?
    let recoveryExecutableSHA256: String
    let originalExecutableSHA256: String
    let retainedConfigSHA256: String
    let retainedReportSHA256: String
    let databaseSHA256BeforeRecovery: String
    let databaseSHA256AfterRecovery: String?
    let expectedRelativePath: String
    let journalID: String
    let journalStageBeforeRecovery: String?
    let journalStageAfterRecovery: String?
    let manifestID: String
    let manifestRecordCount: Int?
    let succeededCount: Int?
    let failedCount: Int?
    let cancelledCount: Int?
    let unknownCount: Int?
    let selectedLogicalBytes: UInt64?
    let processedLogicalBytes: UInt64?
    let movedToTrashLogicalBytes: UInt64?
    let permanentlyReleasedLogicalBytes: UInt64?
    let retainedTrashAttemptCount: Int
    let executorInvocationCount: Int
    let restoreOutcome: PhaseCTrashDiagnosticRestoreOutcome?
    let originalPresent: Bool
    let trashPresent: Bool?
    let error: PhaseCTrashRecoveryError?
    let limitations: [String]
}

enum PhaseCTrashRecoveryHarness {
    @MainActor
    static func startIfRequested() {
        guard let request = PhaseCTrashRecoveryLaunchRequest(
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
    ) async -> PhaseCTrashRecoveryRunResult? {
        let startedAt = Date()
        do {
            let signing = try LifecycleBundleSigningIdentityReader()
                .evidence(bundleURL: Bundle.main.bundleURL)
            let data = try loadRecoveryData(
                configURL,
                maximumSize: 65_536
            )
            let config = try PhaseCTrashRecoveryConfiguration.validated(
                data: data,
                configURL: configURL,
                environment: ProcessInfo.processInfo.environment,
                now: Date(),
                bundleIdentifier: Bundle.main.bundleIdentifier,
                executableSHA256: signing.executableSHA256
            )
            return PhaseCTrashRecoveryRunResult(
                report: await execute(config: config, signing: signing),
                reportURL: URL(
                    filePath: config.recoveryReportPath
                ).standardizedFileURL
            )
        } catch {
            writePreflightReceipt(
                error: error,
                startedAt: startedAt,
                configURL: configURL
            )
            return nil
        }
    }

    private static func execute(
        config: PhaseCTrashRecoveryConfiguration,
        signing: LifecycleBundleSigningEvidence
    ) async -> PhaseCTrashRecoveryReport {
        let startedAt = Date()
        let databaseURL = URL(
            filePath: config.evidenceDatabasePath
        ).standardizedFileURL
        let originalURL = URL(
            filePath: config.diagnosticRoot,
            directoryHint: .isDirectory
        ).appending(
            path: "fixture/\(config.expectedRelativePath)",
            directoryHint: .isDirectory
        )
        let returnedTrashURL = URL(
            filePath: config.expectedReturnedTrashPath,
            directoryHint: .isDirectory
        ).standardizedFileURL
        let markerName =
            ".stornaut-phase-c-trash-item-\(config.diagnosticNonce)"
        let marker =
            "stornaut-phase-c-trash-item:\(config.diagnosticNonce)"
        var stageBefore: String?
        var stageAfter: String?
        var result: CleanupExecutionResult?
        var restoreOutcome: PhaseCTrashDiagnosticRestoreOutcome?
        let observation = CleanupRecoveryDiagnosticObservation()
        var terminalError: PhaseCTrashRecoveryError?

        do {
            try revalidateRetainedArtifacts(config)
            let retainedConfig = try retainedConfiguration(config)
            let retainedReport = try retainedReport(config)
            try validateRetainedEvidence(
                config: config,
                retainedConfig: retainedConfig,
                retainedReport: retainedReport,
                originalURL: originalURL,
                returnedTrashURL: returnedTrashURL,
                markerName: markerName,
                marker: marker
            )
            try revalidateRetainedArtifacts(config)
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
            guard storeConfiguration.evidenceDatabaseURL
                    .standardizedFileURL == databaseURL,
                  let journalID = CleanupRunID(
                    rawValue: config.expectedJournalID
                  ),
                  let manifestID = CleanupManifestID(
                    rawValue: config.expectedManifestID
                  )
            else {
                throw PhaseCTrashRecoveryError.unsafePath
            }
            let preOpenBinding = try retainedArtifactBinding(config)
            let store = try EvidenceStore(
                configuration: storeConfiguration
            )
            guard try await store.diagnosticDatabaseSHA256()
                    == config.expectedDatabaseSHA256,
                  try retainedArtifactBinding(config)
                    == preOpenBinding
            else {
                throw PhaseCTrashRecoveryError
                    .retainedEvidenceMismatch
            }
            let page = try await store.cleanupRunJournals(
                limit: 2,
                offset: 0
            )
            guard page.corruptRecordIDs.isEmpty,
                  page.records.count == 1,
                  let journal = page.records.first,
                  journal.id == journalID,
                  journal.manifestID == manifestID,
                  journal.stage == .actionOutcomeRecorded,
                  journal.selectionGeneration == 1,
                  journal.selectionFingerprint.rawValue
                    == retainedReport.selectionFingerprint,
                  journal.planID.rawValue == retainedReport.planID,
                  journal.entries.count == 1,
                  let entry = journal.entries.first,
                  entry.expectedIdentity
                    == config.expectedOriginalIdentity,
                  entry.state == .outcomeRecorded,
                  entry.outcome?.result == .succeeded,
                  entry.outcome?.recovery == .movedToTrash,
                  entry.outcome?.destinationIdentity
                    == config.expectedOriginalIdentity,
                  entry.outcome?.measures
                    .permanentlyReleasedLogicalBytes == ByteCount(0),
                  try await store.cleanupManifest(id: manifestID) == nil
            else {
                throw PhaseCTrashRecoveryError.journalMismatch
            }
            stageBefore = journal.stage.rawValue

            let runtime = CleanupExecutionRuntime.diagnosticRecovery(
                store: store,
                workflowCoordinator: CleanupWorkflowCoordinator(),
                observation: observation
            )
            let states = await runtime.recover()
            guard observation.invocationCount() == 0 else {
                throw PhaseCTrashRecoveryError.executorReplay
            }
            guard states.count == 1,
                  case let .completed(recovered) = states[0],
                  recovered.journal.id == journalID,
                  recovered.journal.stage == .finalized,
                  recovered.manifest.id == manifestID,
                  recovered.manifest.records.count == 1,
                  recovered.manifest.summary.succeededCount == 1,
                  recovered.manifest.summary.failedCount == 0,
                  recovered.manifest.summary.cancelledCount == 0,
                  recovered.manifest.summary.unknownCount == 0,
                  recovered.manifest.summary
                    .permanentlyReleasedLogicalBytes == ByteCount(0),
                  recovered.journal.entries.first?.outcome?
                    .destinationIdentity
                    == config.expectedOriginalIdentity,
                  try await store.cleanupRunJournal(id: journalID)
                    == recovered.journal,
                  try await store.cleanupManifest(id: manifestID)
                    == recovered.manifest
            else {
                throw PhaseCTrashRecoveryError.recoveryFailed
            }
            result = recovered
            stageAfter = recovered.journal.stage.rawValue

            restoreOutcome = PhaseCTrashDiagnosticRestore.restore(
                returnedTrashURL: returnedTrashURL,
                originalURL: originalURL,
                expectedIdentity: config.expectedOriginalIdentity,
                expectedDestinationParentIdentity:
                    config.expectedDestinationParentIdentity,
                marker: marker,
                markerName: markerName
            )
            guard restoreOutcome == .restored,
                  FileIdentity.read(at: originalURL)
                    == config.expectedOriginalIdentity,
                  recoveryPathPresence(returnedTrashURL) == false,
                  observation.invocationCount() == 0
            else {
                throw PhaseCTrashRecoveryError.restoreFailed
            }
        } catch let error as PhaseCTrashRecoveryError {
            terminalError = error
        } catch {
            terminalError = .recoveryFailed
        }

        let summary = result?.manifest.summary
        let residual = PhaseCTrashDiagnosticResidual.make(
            originalURL: originalURL,
            returnedTrashURL: returnedTrashURL,
            expectedIdentity: config.expectedOriginalIdentity,
            fixtureRoot: URL(
                filePath: config.diagnosticRoot,
                directoryHint: .isDirectory
            ).appending(path: "fixture", directoryHint: .isDirectory),
            trashWasAttempted: true
        )
        let originalPresent = residual.originalPresent
        let trashPresent = residual.trashPresent
        let ready = terminalError == nil
            && stageBefore == CleanupRunJournalStage
                .actionOutcomeRecorded.rawValue
            && stageAfter == CleanupRunJournalStage.finalized.rawValue
            && restoreOutcome == .restored
            && originalPresent
            && trashPresent == false
            && observation.invocationCount() == 0
        if !ready, terminalError == nil {
            terminalError = .receiptMismatch
        }
        return PhaseCTrashRecoveryReport(
            schemaVersion: 1,
            recoveryNonce: config.recoveryNonce,
            diagnosticNonce: config.diagnosticNonce,
            startedAt: startedAt,
            finishedAt: Date(),
            outcome: ready
                ? "signedAppTrashRecoveryReady"
                : "signedAppTrashRecoveryBlocked",
            bundleIdentifier: signing.identity.signingIdentifier,
            recoveryExecutablePath: Bundle.main.executableURL?
                .standardizedFileURL.path,
            recoveryExecutableSHA256: signing.executableSHA256,
            originalExecutableSHA256:
                config.expectedOriginalExecutableSHA256,
            retainedConfigSHA256:
                config.expectedRetainedConfigSHA256,
            retainedReportSHA256:
                config.expectedRetainedReportSHA256,
            databaseSHA256BeforeRecovery: config.expectedDatabaseSHA256,
            databaseSHA256AfterRecovery: sha256File(databaseURL),
            expectedRelativePath: config.expectedRelativePath,
            journalID: config.expectedJournalID,
            journalStageBeforeRecovery: stageBefore,
            journalStageAfterRecovery: stageAfter,
            manifestID: config.expectedManifestID,
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
            retainedTrashAttemptCount: 1,
            executorInvocationCount: observation.invocationCount(),
            restoreOutcome: restoreOutcome,
            originalPresent: originalPresent,
            trashPresent: trashPresent,
            error: terminalError,
            limitations: [
                "recovery-only continuation of one retained Trash attempt",
                "no Executor or Trash replay",
                "diagnostic-owned disposable fixture only",
                "release distribution not evaluated",
            ]
        )
    }

    private static func retainedConfiguration(
        _ config: PhaseCTrashRecoveryConfiguration
    ) throws -> PhaseCTrashDiagnosticConfiguration {
        let data = try loadRecoveryData(
            URL(filePath: config.retainedConfigPath),
            maximumSize: 65_536
        )
        guard PhaseCTrashRecoveryConfiguration.sha256(data)
                == config.expectedRetainedConfigSHA256
        else {
            throw PhaseCTrashRecoveryError.retainedEvidenceMismatch
        }
        guard let object = try? JSONSerialization.jsonObject(
            with: data
        ) as? [String: Any],
        Set(object.keys) == Set([
            "schemaVersion",
            "nonce",
            "optInStatement",
            "optInNonce",
            "diagnosticRoot",
            "fixtureRoot",
            "applicationSupportBase",
            "cachesBase",
            "reportPath",
            "expectedBundleIdentifier",
            "expectedExecutableSHA256",
            "expectedRelativePath",
            "issuedAt",
            "expiresAt",
        ]),
        let value = try? JSONDecoder.phaseCRecovery.decode(
            PhaseCTrashDiagnosticConfiguration.self,
            from: data
        )
        else {
            throw PhaseCTrashRecoveryError.retainedEvidenceMismatch
        }
        return value
    }

    private static func retainedReport(
        _ config: PhaseCTrashRecoveryConfiguration
    ) throws -> PhaseCTrashDiagnosticReport {
        let data = try loadRecoveryData(
            URL(filePath: config.retainedReportPath),
            maximumSize: 262_144
        )
        guard PhaseCTrashRecoveryConfiguration.sha256(data)
                == config.expectedRetainedReportSHA256
        else {
            throw PhaseCTrashRecoveryError.retainedEvidenceMismatch
        }
        guard let object = try? JSONSerialization.jsonObject(
            with: data
        ) as? [String: Any],
        Set(object.keys) == PhaseCTrashDiagnosticReport.requiredJSONKeys,
        let value = try? JSONDecoder.phaseCRecovery.decode(
            PhaseCTrashDiagnosticReport.self,
            from: data
        )
        else {
            throw PhaseCTrashRecoveryError.retainedEvidenceMismatch
        }
        return value
    }

    private static func revalidateRetainedArtifacts(
        _ config: PhaseCTrashRecoveryConfiguration
    ) throws {
        _ = try retainedArtifactBinding(config)
    }

    private static func retainedArtifactBinding(
        _ config: PhaseCTrashRecoveryConfiguration
    ) throws -> PhaseCTrashRetainedArtifactBinding {
        try PhaseCTrashRetainedArtifactBinding(
            retainedConfiguration: recoveryArtifactBinding(
                URL(filePath: config.retainedConfigPath),
                maximumSize: 65_536,
                expectedSHA256:
                    config.expectedRetainedConfigSHA256
            ),
            retainedReport: recoveryArtifactBinding(
                URL(filePath: config.retainedReportPath),
                maximumSize: 262_144,
                expectedSHA256:
                    config.expectedRetainedReportSHA256
            ),
            evidenceDatabase: recoveryArtifactBinding(
                URL(filePath: config.evidenceDatabasePath),
                maximumSize: 64 * 1_024 * 1_024,
                expectedSHA256: config.expectedDatabaseSHA256
            )
        )
    }

    private static func validateRetainedEvidence(
        config: PhaseCTrashRecoveryConfiguration,
        retainedConfig: PhaseCTrashDiagnosticConfiguration,
        retainedReport: PhaseCTrashDiagnosticReport,
        originalURL: URL,
        returnedTrashURL: URL,
        markerName: String,
        marker: String
    ) throws {
        let rootMarker = URL(
            filePath: config.diagnosticRoot
        ).appending(
            path:
                ".stornaut-phase-c-trash-fixture-\(config.diagnosticNonce)"
        )
        let expectedRootMarker =
            "stornaut-phase-c-root:\(config.diagnosticNonce)"
        let itemMarker = returnedTrashURL.appending(path: markerName)
        guard retainedConfig.schemaVersion
                == PhaseCTrashDiagnosticConfiguration.schemaVersion,
              retainedConfig.nonce == config.diagnosticNonce,
              retainedConfig.diagnosticRoot == config.diagnosticRoot,
              retainedConfig.applicationSupportBase
                == config.applicationSupportBase,
              retainedConfig.cachesBase == config.cachesBase,
              retainedConfig.reportPath == config.retainedReportPath,
              retainedConfig.expectedExecutableSHA256
                == config.expectedOriginalExecutableSHA256,
              retainedConfig.expectedRelativePath
                == config.expectedRelativePath,
              retainedReport.schemaVersion == 2,
              retainedReport.nonce == config.diagnosticNonce,
              retainedReport.outcome == "signedAppTrashBlocked",
              retainedReport.configured,
              retainedReport.planned,
              !retainedReport.contained,
              !retainedReport.restored,
              retainedReport.bundleIdentifier
                == config.expectedBundleIdentifier,
              retainedReport.executableSHA256
                == config.expectedOriginalExecutableSHA256,
              retainedReport.expectedRelativePath
                == config.expectedRelativePath,
              retainedReport.originalIdentity
                == config.expectedOriginalIdentity,
              retainedReport.destinationIdentity
                == config.expectedOriginalIdentity,
              retainedReport.returnedTrashPath
                == config.expectedReturnedTrashPath,
              retainedReport.trashAttemptCount == 1,
              retainedReport.restoreOutcome == nil,
              retainedReport.residual.originalPresent == false,
              retainedReport.residual.trashPresent == true,
              retainedReport.residual.fixtureRootPresent,
              retainedReport.errorStage == "execution",
              retainedReport.error == .executionFailed,
              retainedReport.planID != nil,
              retainedReport.selectionGeneration == 1,
              retainedReport.selectionFingerprint != nil,
              retainedReport.decisionFingerprint != nil,
              retainedReport.journalID == nil,
              retainedReport.manifestID == nil,
              recoveryPathPresence(originalURL) == false,
              FileIdentity.read(at: returnedTrashURL)
                == config.expectedOriginalIdentity,
              sameRecoveryFileObject(
                FileIdentity.read(
                    at: originalURL.deletingLastPathComponent()
                ),
                config.expectedDestinationParentIdentity
              ),
              readSmallRecoveryText(rootMarker) == expectedRootMarker,
              readSmallRecoveryText(itemMarker) == marker
        else {
            throw PhaseCTrashRecoveryError.retainedEvidenceMismatch
        }
    }

    private static func write(
        _ report: PhaseCTrashRecoveryReport,
        reportURL: URL
    ) {
        guard let data = try? JSONEncoder.phaseCRecovery.encode(report)
        else {
            return
        }
        try? writeRecoveryExclusivePrivate(data, to: reportURL)
    }

    private static func writePreflightReceipt(
        error: any Error,
        startedAt: Date,
        configURL: URL
    ) {
        let config = configURL.standardizedFileURL
        let root = config.deletingLastPathComponent()
        guard let nonce = recoveryArtifactNonce(
            config,
            prefix: "recovery-config-"
        ),
              safeRecoveryDirectory(root),
              safeRecoveryRegularFile(config, maximumSize: 65_536)
        else {
            return
        }
        let reportURL = root.appending(
            path: "recovery-preflight-error-\(nonce).json"
        )
        guard recoveryPathPresence(reportURL) == false else {
            return
        }
        let category =
            (error as? PhaseCTrashRecoveryError)
                ?? .invalidConfiguration
        let receipt = PhaseCTrashRecoveryPreflightReceipt(
            schemaVersion: 1,
            startedAt: startedAt,
            finishedAt: Date(),
            outcome: "signedAppTrashRecoveryPreflightBlocked",
            error: category
        )
        guard let data = try? JSONEncoder.phaseCRecovery.encode(receipt)
        else {
            return
        }
        try? writeRecoveryExclusivePrivate(data, to: reportURL)
    }
}

private struct PhaseCTrashRecoveryRunResult: Sendable {
    let report: PhaseCTrashRecoveryReport
    let reportURL: URL
}

private struct PhaseCTrashRetainedArtifactBinding:
    Sendable,
    Equatable
{
    let retainedConfiguration: PhaseCTrashArtifactBinding
    let retainedReport: PhaseCTrashArtifactBinding
    let evidenceDatabase: PhaseCTrashArtifactBinding
}

private struct PhaseCTrashArtifactBinding:
    Sendable,
    Equatable
{
    let identity: FileIdentity
    let sha256: String
}

private struct PhaseCTrashRecoveryPreflightReceipt:
    Codable,
    Sendable
{
    let schemaVersion: Int
    let startedAt: Date
    let finishedAt: Date
    let outcome: String
    let error: PhaseCTrashRecoveryError
}

private extension JSONDecoder {
    static var phaseCRecovery: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}

private extension JSONEncoder {
    static var phaseCRecovery: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private func loadRecoveryData(
    _ url: URL,
    maximumSize: Int
) throws -> Data {
    guard safeRecoveryRegularFile(url, maximumSize: maximumSize) else {
        throw PhaseCTrashRecoveryError.unsafePath
    }
    let data = try Data(contentsOf: url, options: .mappedIfSafe)
    guard !data.isEmpty, data.count <= maximumSize else {
        throw PhaseCTrashRecoveryError.invalidConfiguration
    }
    return data
}

private func recoveryArtifactBinding(
    _ url: URL,
    maximumSize: Int,
    expectedSHA256: String
) throws -> PhaseCTrashArtifactBinding {
    let descriptor = open(
        url.path,
        O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK
    )
    guard descriptor >= 0 else {
        throw PhaseCTrashRecoveryError.retainedEvidenceMismatch
    }
    defer { close(descriptor) }
    var before = stat()
    guard fstat(descriptor, &before) == 0,
          before.st_mode & S_IFMT == S_IFREG,
          before.st_mode & 0o777 == 0o600,
          before.st_uid == geteuid(),
          before.st_nlink == 1,
          before.st_size > 0,
          before.st_size <= maximumSize,
          let identity = recoveryFileIdentity(before),
          FileIdentity.read(at: url) == identity
    else {
        throw PhaseCTrashRecoveryError.retainedEvidenceMismatch
    }
    var data = Data(count: Int(before.st_size))
    var offset = 0
    while offset < data.count {
        let count = data.withUnsafeMutableBytes {
            Darwin.pread(
                descriptor,
                $0.baseAddress!.advanced(by: offset),
                $0.count - offset,
                off_t(offset)
            )
        }
        guard count > 0 else {
            throw PhaseCTrashRecoveryError.retainedEvidenceMismatch
        }
        offset += count
    }
    var after = stat()
    let digest = PhaseCTrashRecoveryConfiguration.sha256(data)
    guard fstat(descriptor, &after) == 0,
          recoveryFileIdentity(after) == identity,
          FileIdentity.read(at: url) == identity,
          digest == expectedSHA256
    else {
        throw PhaseCTrashRecoveryError.retainedEvidenceMismatch
    }
    return PhaseCTrashArtifactBinding(
        identity: identity,
        sha256: digest
    )
}

private func recoveryFileIdentity(_ information: stat) -> FileIdentity? {
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

private func sha256File(_ url: URL) -> String? {
    guard let data = try? Data(
        contentsOf: url,
        options: .mappedIfSafe
    ) else {
        return nil
    }
    return PhaseCTrashRecoveryConfiguration.sha256(data)
}

private func readSmallRecoveryText(_ url: URL) -> String? {
    guard safeRecoveryMarkerFile(url, maximumSize: 4_096),
          let data = try? Data(contentsOf: url, options: .mappedIfSafe)
    else {
        return nil
    }
    return String(decoding: data, as: UTF8.self)
}

private func writeRecoveryExclusivePrivate(
    _ data: Data,
    to url: URL
) throws {
    let descriptor = open(
        url.path,
        O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
        0o600
    )
    guard descriptor >= 0 else {
        throw PhaseCTrashRecoveryError.unsafePath
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
                throw PhaseCTrashRecoveryError.unsafePath
            }
            offset += count
        }
    }
    guard fsync(descriptor) == 0 else {
        throw PhaseCTrashRecoveryError.unsafePath
    }
}

private func safeRecoveryDirectory(_ url: URL) -> Bool {
    var information = stat()
    return lstat(url.path, &information) == 0
        && information.st_mode & S_IFMT == S_IFDIR
        && information.st_mode & 0o777 == 0o700
        && information.st_uid == geteuid()
        && information.st_nlink >= 1
}

private func safeRecoveryRegularFile(
    _ url: URL,
    maximumSize: Int
) -> Bool {
    var information = stat()
    return lstat(url.path, &information) == 0
        && information.st_mode & S_IFMT == S_IFREG
        && information.st_mode & 0o777 == 0o600
        && information.st_uid == geteuid()
        && information.st_nlink == 1
        && information.st_size > 0
        && information.st_size <= maximumSize
}

private func safeRecoveryMarkerFile(
    _ url: URL,
    maximumSize: Int
) -> Bool {
    var information = stat()
    return lstat(url.path, &information) == 0
        && information.st_mode & S_IFMT == S_IFREG
        && information.st_mode & 0o022 == 0
        && information.st_uid == geteuid()
        && information.st_nlink == 1
        && information.st_size > 0
        && information.st_size <= maximumSize
}

private func sameRecoveryDirectory(_ lhs: URL, _ rhs: URL) -> Bool {
    var lhsInformation = stat()
    var rhsInformation = stat()
    return lstat(lhs.path, &lhsInformation) == 0
        && lstat(rhs.path, &rhsInformation) == 0
        && lhsInformation.st_mode & S_IFMT == S_IFDIR
        && rhsInformation.st_mode & S_IFMT == S_IFDIR
        && lhsInformation.st_dev == rhsInformation.st_dev
        && lhsInformation.st_ino == rhsInformation.st_ino
}

private func sameRecoveryFileObject(
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

func recoveryPathPresence(_ url: URL) -> Bool? {
    var information = stat()
    errno = 0
    if lstat(url.path, &information) == 0 {
        return true
    }
    return errno == ENOENT ? false : nil
}

private func validRecoverySHA256(_ value: String) -> Bool {
    value.count == 64
        && value.unicodeScalars.allSatisfy {
            (0x30...0x39).contains($0.value)
                || (0x61...0x66).contains($0.value)
        }
}

private func isNormalizedRecoveryAbsolutePath(_ value: String) -> Bool {
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

private func recoveryArtifactNonce(
    _ url: URL,
    prefix: String
) -> String? {
    let name = url.lastPathComponent
    guard name.hasPrefix(prefix),
          name.hasSuffix(".json")
    else {
        return nil
    }
    let raw = String(
        name.dropFirst(prefix.count).dropLast(".json".count)
    )
    guard let value = UUID(uuidString: raw),
          value.uuidString.lowercased() == raw
    else {
        return nil
    }
    return raw
}
#endif
