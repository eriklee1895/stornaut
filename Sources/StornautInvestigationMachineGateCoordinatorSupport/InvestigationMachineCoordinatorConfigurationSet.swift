#if DEBUG
  import Foundation
  import StornautCore
  import StornautInvestigation
  import StornautInvestigationDiagnostic
  package enum InvestigationMachineCoordinatorConfigurationSetError:
    Error, Sendable, Equatable
  {
    case invalidTemplatePlan
    case invalidAttemptRoot
    case identifierGenerationFailed
    case invalidIdentifiers
    case invalidConfiguration
  }
  package struct InvestigationMachineCoordinatorConfigurationRow:
    Sendable, Equatable
  {
    package let scenario: SignedInvestigationRuntimeDiagnosticScenario
    package let investigationID: InvestigationID
    package let runID: InvestigationRunID
    package let plan: InvestigationPlan
    package let configuration: SignedInvestigationRuntimeDiagnosticConfiguration
    package let canonicalConfigurationData: Data
  }
  package enum InvestigationMachineCoordinatorSourceFixtureTemplate {
    package struct File: Sendable, Equatable {
      package let relativePath: String
      package let bytes: Data
    }
    package static let scanSessionID =
      ScanSessionID(rawValue: "scan-machine-coordinator-source-v1")!
    package static let primaryScopeID =
      ScanScopeID(rawValue: "scope-machine-coordinator-source-v1")!
    package static let rootSnapshotID =
      SnapshotID(rawValue: "snapshot-machine-coordinator-root-v1")!
    package static let candidateSnapshotID =
      SnapshotID(rawValue: "snapshot-machine-coordinator-candidate-v1")!
    package static let classificationID =
      ClassificationID(
        rawValue: "classification-machine-coordinator-candidate-v1"
      )!
    package static let catalogVersion =
      DomainToken(rawValue: "catalog.machine-coordinator-source.v1")!
    package static let classificationRuleID =
      DomainToken(rawValue: "rule.machine-coordinator-source.v1")!
    package static let classificationCategory: ArtifactCategory = .unknownLargeConsumers
    package static let classificationDisposition: ReclaimDisposition = .unknown
    package static let classificationRisk: RiskLevel = .low
    package static let classificationConfidence: EvidenceConfidence = .high
    package static let relevanceTokens = [
      DomainToken(rawValue: "relevance.developer")!
    ]
    package static let files = [
      File(
        relativePath: "candidate/source-evidence.txt",
        bytes: Data(
          "STORNAUT_MACHINE_COORDINATOR_SOURCE_V1\n".utf8
        )
      )
    ]
    package static let expectedTargetKind: InvestigationTargetKind = .unknownProducer
    package static let expectedTargetAllocatedBytes = ByteCount(4_096)!
    package static let expectedReasonKeys = [
      DomainToken(rawValue: "reason.unknown-producer")!
    ]
    package static let templateInvestigationID =
      InvestigationID(
        rawValue: "investigation-machine-coordinator-template-v1"
      )!
    package static func validates(
      _ plan: InvestigationPlan,
      sourceFingerprint: InvestigationFingerprint,
      now: Date
    ) -> Bool {
      guard
        plan.id == templateInvestigationID,
        plan.scanSessionID == scanSessionID,
        plan.scanScopeID == primaryScopeID,
        plan.sourceFingerprint == sourceFingerprint,
        plan.budgetPreset == .focused,
        plan.requiredCapabilities == InvestigationCapability.required,
        plan.createdAt == now,
        plan.expiresAt == now.addingTimeInterval(600),
        plan.targets.count == 1,
        let target = plan.targets.first,
        target.kind == expectedTargetKind,
        target.reasonKeys == expectedReasonKeys,
        target.expectedAllocatedBytes == expectedTargetAllocatedBytes,
        target.uncertaintyPermille == 850,
        target.relevancePermille == 800,
        target.investigationCostPermille == 400,
        target.createdAt == plan.createdAt,
        target.sourceBinding
          == .classification(
            classificationID: classificationID,
            snapshotID: candidateSnapshotID
          )
      else { return false }
      return true
    }
  }
  package struct InvestigationMachineCoordinatorConfigurationSet:
    @unchecked Sendable
  {
    package let currentSourceBinding: InvestigationMachineCurrentSourceBinding
    package let rows: [InvestigationMachineCoordinatorConfigurationRow]
    package var configurations: [SignedInvestigationRuntimeDiagnosticConfiguration] {
      rows.map(\.configuration)
    }
    package var canonicalConfigurationData: [Data] {
      rows.map(\.canonicalConfigurationData)
    }
    package var runtimeReceipt: InvestigationRuntimeReceiptV1 {
      currentSourceBinding.runtimeReceipt
    }
    package var binding: SignedInvestigationRuntimeBinding {
      currentSourceBinding.binding
    }
  }
  package struct InvestigationMachineCoordinatorGeneratedIdentifiers:
    Sendable, Equatable
  {
    package let configurationNonces: [UUID]
    package let investigationIDs: [InvestigationID]
    package let runIDs: [InvestigationRunID]
    package init(
      configurationNonces: [UUID],
      investigationIDs: [InvestigationID],
      runIDs: [InvestigationRunID]
    ) {
      self.configurationNonces = configurationNonces
      self.investigationIDs = investigationIDs
      self.runIDs = runIDs
    }
  }
  package struct InvestigationMachineCoordinatorConfigurationSetSource:
    Sendable
  {
    package typealias IdentifierProvider =
      @Sendable () throws
      -> InvestigationMachineCoordinatorGeneratedIdentifiers
    private let identifiers: IdentifierProvider
    package init() {
      identifiers = {
        let nonces = (0..<Self.scenarioCount).map { _ in UUID() }
        return InvestigationMachineCoordinatorGeneratedIdentifiers(
          configurationNonces: nonces,
          investigationIDs: nonces.map {
            InvestigationID(
              rawValue: "investigation-"
                + $0.uuidString.lowercased()
            )!
          },
          runIDs: nonces.map {
            InvestigationRunID(
              rawValue: "investigation-run-"
                + $0.uuidString.lowercased()
            )!
          }
        )
      }
    }
    init(identifiers: @escaping IdentifierProvider) {
      self.identifiers = identifiers
    }
    package func make(
      currentSourceBinding: InvestigationMachineCurrentSourceBinding,
      canonicalPlan: InvestigationPlan,
      attemptRoot: URL,
      now: Date
    ) throws -> InvestigationMachineCoordinatorConfigurationSet {
      guard Self.scenarioCount == 8,
        InvestigationMachineCoordinatorSourceFixtureTemplate.validates(
          canonicalPlan,
          sourceFingerprint: currentSourceBinding.sourceFingerprint,
          now: now
        )
      else {
        throw InvestigationMachineCoordinatorConfigurationSetError
          .invalidTemplatePlan
      }
      guard
        attemptRoot.isFileURL,
        attemptRoot.path.hasPrefix("/"),
        attemptRoot.lastPathComponent.hasPrefix("attempt-"),
        FileManager.default.fileExists(atPath: attemptRoot.path),
        !attemptRoot.path.contains("/../"),
        !attemptRoot.path.contains("/./")
      else {
        throw InvestigationMachineCoordinatorConfigurationSetError
          .invalidAttemptRoot
      }
      let generated: InvestigationMachineCoordinatorGeneratedIdentifiers
      do {
        generated = try identifiers()
      } catch {
        throw InvestigationMachineCoordinatorConfigurationSetError
          .identifierGenerationFailed
      }
      try validateIdentifiers(generated)
      guard
        try currentSourceBinding.runtimeReceiptReconstructedAndValidated()
          == currentSourceBinding.runtimeReceipt
      else {
        throw InvestigationMachineCoordinatorConfigurationSetError
          .invalidConfiguration
      }
      try currentSourceBinding.revalidateBeforeFirstConfiguration()
      let scenarios = SignedInvestigationRuntimeDiagnosticScenario.allCases
      let validBefore = now.addingTimeInterval(
        SignedInvestigationRuntimeDiagnosticConfiguration
          .maximumMachineCohortValiditySeconds
      )
      var rows: [InvestigationMachineCoordinatorConfigurationRow] = []
      do {
        for index in scenarios.indices {
          let nonce = generated.configurationNonces[index]
          guard generated.investigationIDs[index].rawValue
            == "investigation-" + nonce.uuidString.lowercased(),
            generated.runIDs[index].rawValue
              == "investigation-run-" + nonce.uuidString.lowercased()
          else {
            throw InvestigationMachineCoordinatorConfigurationSetError
              .invalidIdentifiers
          }
          let paths = makePaths(
            attemptRoot: attemptRoot, ordinal: index, nonce: nonce
          )
          let plan = try derivedPlan(
            canonicalPlan, investigationID: generated.investigationIDs[index]
          )
          let configuration = try SignedInvestigationRuntimeDiagnosticConfiguration
            .machineCohort(
            nonce: nonce, scenario: scenarios[index],
            optIn: SignedInvestigationRuntimeDiagnosticConfiguration.requiredOptIn,
            diagnosticRootPath: paths.diagnosticRoot.path,
            sourceRootPath: paths.sourceRoot.path,
            supportRootPath: paths.supportRoot.path,
            runtimeRootPath: paths.runtimeRoot.path,
            reportPath: paths.reportURL.path, storePath: paths.storeURL.path,
            binding: currentSourceBinding.binding,
            expectedModel: .gpt56Luna, expectedProvider: .openAI,
            validBefore: validBefore, maximumWallClockSeconds:
              SignedInvestigationRuntimeDiagnosticConfiguration
                .maximumMachineEpochWallClockSeconds,
            maximumTurns: 3, maximumProbeCalls: 16,
            maximumContextBytes: 1_048_576, now: now
          )
          let data = try configuration.canonicalJSONData()
          guard try SignedInvestigationRuntimeDiagnosticConfiguration
            .decodeMachineCohortValidated(from: data, now: now) == configuration,
            configuration.validBefore == validBefore,
            configuration.maximumWallClockSeconds
              == SignedInvestigationRuntimeDiagnosticConfiguration
                .maximumMachineEpochWallClockSeconds,
            plan.sourceFingerprint == currentSourceBinding.sourceFingerprint,
            plan.targetSetFingerprint == canonicalPlan.targetSetFingerprint
          else {
            throw InvestigationMachineCoordinatorConfigurationSetError
              .invalidConfiguration
          }
          rows.append(InvestigationMachineCoordinatorConfigurationRow(
            scenario: scenarios[index],
            investigationID: generated.investigationIDs[index],
            runID: generated.runIDs[index], plan: plan,
            configuration: configuration, canonicalConfigurationData: data
          ))
        }
        guard rows.count == Self.scenarioCount,
          Set(rows.map { $0.configuration.validBefore }).count == 1
        else {
          throw InvestigationMachineCoordinatorConfigurationSetError
            .invalidConfiguration
        }
        return InvestigationMachineCoordinatorConfigurationSet(
          currentSourceBinding: currentSourceBinding, rows: rows
        )
      } catch {
        if let typed = error
          as? InvestigationMachineCoordinatorConfigurationSetError
        { throw typed }
        throw InvestigationMachineCoordinatorConfigurationSetError
          .invalidConfiguration
      }
    }
    private static let scenarioCount =
      SignedInvestigationRuntimeDiagnosticScenario.allCases.count
    private func derivedPlan(
      _ template: InvestigationPlan,
      investigationID: InvestigationID
    ) throws -> InvestigationPlan {
      do {
        return try InvestigationPlan(
          id: investigationID,
          scanSessionID: template.scanSessionID,
          scanScopeID: template.scanScopeID,
          sourceFingerprint: template.sourceFingerprint,
          budgetPreset: template.budgetPreset,
          targets: template.targets,
          createdAt: template.createdAt,
          expiresAt: template.expiresAt,
          requestedCoveragePermille:
            template.requestedCoveragePermille,
          remainingUnknownByteThreshold:
            template.remainingUnknownByteThreshold,
          requiredCapabilities: InvestigationCapability.required
        )
      } catch {
        throw InvestigationMachineCoordinatorConfigurationSetError
          .invalidTemplatePlan
      }
    }
    private func validateIdentifiers(
      _ generated: InvestigationMachineCoordinatorGeneratedIdentifiers
    ) throws {
      guard
        generated.configurationNonces.count == Self.scenarioCount,
        generated.investigationIDs.count == Self.scenarioCount,
        generated.runIDs.count == Self.scenarioCount,
        generated.configurationNonces.allSatisfy({ !Self.isZero($0) }),
        Set(generated.configurationNonces).count == Self.scenarioCount,
        Set(generated.investigationIDs).count == Self.scenarioCount,
        Set(generated.runIDs).count == Self.scenarioCount
      else {
        throw InvestigationMachineCoordinatorConfigurationSetError
          .invalidIdentifiers
      }
    }
    private func makePaths(
      attemptRoot: URL,
      ordinal: Int,
      nonce: UUID
    ) -> ConfigurationPaths {
      let directory = attemptRoot.appending(
        path: String(
          format: "epoch-%02d-%@", ordinal,
          nonce.uuidString.lowercased()),
        directoryHint: .isDirectory
      )
      let source = directory.appending(
        path: "source", directoryHint: .isDirectory
      )
      let support = directory.appending(
        path: "support", directoryHint: .isDirectory
      )
      let runtime = directory.appending(
        path: "runtime", directoryHint: .isDirectory
      )
      let store = support.appending(
        path: "com.eriklee.stornaut", directoryHint: .isDirectory
      ).appending(path: "Evidence.sqlite")
      return ConfigurationPaths(
        diagnosticRoot: directory,
        sourceRoot: source,
        supportRoot: support,
        runtimeRoot: runtime,
        reportURL: directory.appending(path: "report.json"),
        storeURL: store
      )
    }
    private static func isZero(_ value: UUID) -> Bool {
      value
        == UUID(
          uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        )
    }
    private struct ConfigurationPaths {
      let diagnosticRoot, sourceRoot, supportRoot, runtimeRoot: URL
      let reportURL, storeURL: URL
    }
  }
#endif
