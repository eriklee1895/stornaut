#if DEBUG
  import CryptoKit
  import Foundation
  import StornautCodex
  import StornautCore
  import StornautInvestigation
  import StornautInvestigationDiagnostic

  package enum InvestigationMachineCoordinatorBindingSourceError:
    Error, Sendable, Equatable
  {
    case buildProvenanceUnavailable
    case invalidBuildProvenance
    case invalidSourceFingerprint
    case invalidInstalledObservation
    case invalidRuntimeReceipt
    case invalidBinding
    case codexIdentityChanged
  }

  package struct InvestigationMachineBuildProvenanceReceiptV1:
    Sendable, Equatable
  {
    package static let schemaVersion = 1
    package static let domain =
      "stornaut.task39.machine.build-provenance.v1"
    package static let requiredTargetIdentifier =
      "StornautInvestigationMachineGateCoordinatorSupport"
    package static let requiredProductIdentifier =
      "StornautInvestigationMachineGateCoordinator"

    package let repositoryHEAD: String
    package let repositoryTree: String
    package let canonicalManifestSHA256: String
    package let buildConfiguration: String
    package let coordinatorTargetIdentifier: String
    package let coordinatorProductIdentifier: String
    package let promptSHA256: String
    package let envelopeSchemaSHA256: String
    package let facadeSHA256: String

    init(
      repositoryHEAD: String,
      repositoryTree: String,
      canonicalManifestSHA256: String,
      buildConfiguration: String,
      coordinatorTargetIdentifier: String,
      coordinatorProductIdentifier: String,
      promptSHA256: String,
      envelopeSchemaSHA256: String,
      facadeSHA256: String
    ) throws {
      guard
        Self.isLowercaseHex(repositoryHEAD, count: 40),
        Self.isLowercaseHex(repositoryTree, count: 40),
        [
          canonicalManifestSHA256, promptSHA256,
          envelopeSchemaSHA256, facadeSHA256,
        ].allSatisfy({ Self.isLowercaseHex($0, count: 64) }),
        buildConfiguration == "debug"
          || buildConfiguration == "release",
        coordinatorTargetIdentifier == Self.requiredTargetIdentifier,
        coordinatorProductIdentifier == Self.requiredProductIdentifier
      else {
        throw InvestigationMachineCoordinatorBindingSourceError
          .invalidBuildProvenance
      }
      self.repositoryHEAD = repositoryHEAD
      self.repositoryTree = repositoryTree
      self.canonicalManifestSHA256 = canonicalManifestSHA256
      self.buildConfiguration = buildConfiguration
      self.coordinatorTargetIdentifier = coordinatorTargetIdentifier
      self.coordinatorProductIdentifier = coordinatorProductIdentifier
      self.promptSHA256 = promptSHA256
      self.envelopeSchemaSHA256 = envelopeSchemaSHA256
      self.facadeSHA256 = facadeSHA256
    }

    package func canonicalData() -> Data {
      var data = Data()
      Self.appendFramed(Self.domain, to: &data)
      Self.appendBigEndian(UInt64(Self.schemaVersion), to: &data)
      for value in [
        repositoryHEAD, repositoryTree, canonicalManifestSHA256,
        buildConfiguration, coordinatorTargetIdentifier,
        coordinatorProductIdentifier, promptSHA256,
        envelopeSchemaSHA256, facadeSHA256,
      ] {
        Self.appendFramed(value, to: &data)
      }
      return data
    }

    package var sha256: String { Self.sha256Hex(canonicalData()) }

    package static func generated() throws -> Self {
      guard
        InvestigationMachineGeneratedBuildProvenance.schemaVersion
          == schemaVersion,
        InvestigationMachineGeneratedBuildProvenance.domain == domain,
        InvestigationMachineGeneratedBuildProvenance.availability
          == .available,
        let repositoryHEAD =
          InvestigationMachineGeneratedBuildProvenance.validationCommit,
        let repositoryTree =
          InvestigationMachineGeneratedBuildProvenance.validationTree,
        let canonicalManifestSHA256 =
          InvestigationMachineGeneratedBuildProvenance
          .canonicalManifestSHA256,
        let promptSHA256 =
          InvestigationMachineGeneratedBuildProvenance.promptSHA256,
        let envelopeSchemaSHA256 =
          InvestigationMachineGeneratedBuildProvenance
          .envelopeSchemaSHA256,
        let facadeSHA256 =
          InvestigationMachineGeneratedBuildProvenance.facadeSHA256
      else {
        throw InvestigationMachineCoordinatorBindingSourceError
          .buildProvenanceUnavailable
      }
      return try Self(
        repositoryHEAD: repositoryHEAD,
        repositoryTree: repositoryTree,
        canonicalManifestSHA256: canonicalManifestSHA256,
        buildConfiguration:
          InvestigationMachineGeneratedBuildProvenance
          .buildConfiguration,
        coordinatorTargetIdentifier:
          InvestigationMachineGeneratedBuildProvenance
          .coordinatorTargetIdentifier,
        coordinatorProductIdentifier:
          InvestigationMachineGeneratedBuildProvenance
          .coordinatorProductIdentifier,
        promptSHA256: promptSHA256,
        envelopeSchemaSHA256: envelopeSchemaSHA256,
        facadeSHA256: facadeSHA256
      )
    }

    private static func isLowercaseHex(
      _ value: String, count: Int
    ) -> Bool {
      value.utf8.count == count
        && value.utf8.allSatisfy {
          (48...57).contains($0) || (97...102).contains($0)
        }
    }

    private static func appendFramed(
      _ value: String, to data: inout Data
    ) {
      let bytes = Data(value.utf8)
      appendBigEndian(UInt64(bytes.count), to: &data)
      data.append(bytes)
    }

    private static func appendBigEndian(
      _ value: UInt64, to data: inout Data
    ) {
      for shift in stride(from: 56, through: 0, by: -8) {
        data.append(UInt8(truncatingIfNeeded: value >> UInt64(shift)))
      }
    }

    private static func sha256Hex(_ data: Data) -> String {
      SHA256.hash(data: data).map {
        String(format: "%02x", $0)
      }.joined()
    }
  }

  package struct InvestigationMachineCurrentSourceBinding:
    @unchecked Sendable
  {
    package let buildProvenance: InvestigationMachineBuildProvenanceReceiptV1
    package let buildProvenanceSHA256: String
    package let sourceFingerprint: InvestigationFingerprint
    package let runtimeReceipt: InvestigationRuntimeReceiptV1
    package let binding: SignedInvestigationRuntimeBinding
    package let installedBinding: InvestigationProjectedCohortInstalledBinding
    package let codexNativeIdentityLease: CodexNativeExecutableIdentityLease

    package func revalidateBeforeFirstConfiguration() throws {
      do {
        try codexNativeIdentityLease.revalidate()
      } catch {
        throw InvestigationMachineCoordinatorBindingSourceError
          .codexIdentityChanged
      }
    }

    package func runtimeReceiptReconstructedAndValidated() throws
      -> InvestigationRuntimeReceiptV1
    {
      let reconstructed: InvestigationRuntimeReceiptV1
      let digest: String
      do {
        reconstructed =
          try InvestigationRuntimeReceiptCanonicalV1
          .receipt(
            repositoryHEAD: binding.repositoryHEAD,
            sourceFingerprintSHA256:
              binding.sourceFingerprintSHA256
          )
        digest = try InvestigationRuntimeReceiptCanonicalV1.sha256(
          reconstructed
        )
      } catch {
        throw InvestigationMachineCoordinatorBindingSourceError
          .invalidRuntimeReceipt
      }
      guard
        reconstructed == runtimeReceipt,
        digest == binding.runtimeReceiptSHA256,
        binding.repositoryHEAD == buildProvenance.repositoryHEAD,
        binding.sourceFingerprintSHA256 == sourceFingerprint.hex
      else {
        throw InvestigationMachineCoordinatorBindingSourceError
          .invalidRuntimeReceipt
      }
      return reconstructed
    }

  }

  package struct InvestigationMachineCurrentSourceBindingSource: Sendable {
    typealias BuildProvenance = @Sendable () throws
      -> InvestigationMachineBuildProvenanceReceiptV1
    typealias InstalledObservation = @Sendable () throws
      -> InvestigationRuntimeDiagnosticBindingObservation
    typealias CodexIdentityResolver = @Sendable () async throws
      -> CodexNativeExecutableIdentityLease
    private let buildProvenance: BuildProvenance
    private let installedObservation: InstalledObservation
    private let resolveCodexIdentity: CodexIdentityResolver

    package init() {
      buildProvenance = {
        try InvestigationMachineBuildProvenanceReceiptV1.generated()
      }
      installedObservation = {
        try InvestigationRuntimeDiagnosticBindingObservation.installed()
      }
      resolveCodexIdentity = {
        try await CodexNativeExecutableIdentitySource().resolveInstalled()
      }
    }

    init(
      buildProvenance: @escaping BuildProvenance,
      installedObservation: @escaping InstalledObservation,
      resolveCodexIdentity: @escaping CodexIdentityResolver
    ) {
      self.buildProvenance = buildProvenance
      self.installedObservation = installedObservation
      self.resolveCodexIdentity = resolveCodexIdentity
    }

    package func make(
      sourceFingerprint: InvestigationFingerprint
    ) async throws -> InvestigationMachineCurrentSourceBinding {
      let provenance = try buildProvenance()
      let initialObservation: InvestigationRuntimeDiagnosticBindingObservation
      do { initialObservation = try installedObservation() } catch {
        throw InvestigationMachineCoordinatorBindingSourceError
          .invalidInstalledObservation
      }
      let codexLease: CodexNativeExecutableIdentityLease
      do {
        codexLease = try await resolveCodexIdentity()
      } catch {
        throw InvestigationMachineCoordinatorBindingSourceError
          .invalidInstalledObservation
      }
      let observation: InvestigationRuntimeDiagnosticBindingObservation
      do { observation = try installedObservation() } catch {
        throw InvestigationMachineCoordinatorBindingSourceError
          .invalidInstalledObservation
      }
      guard observation == initialObservation else {
        throw InvestigationMachineCoordinatorBindingSourceError
          .invalidInstalledObservation
      }
      return try Self.make(
        provenance: provenance,
        sourceFingerprint: sourceFingerprint,
        observation: observation,
        codexLease: codexLease
      )
    }

    static func make(
      provenance: InvestigationMachineBuildProvenanceReceiptV1,
      sourceFingerprint: InvestigationFingerprint,
      observation: InvestigationRuntimeDiagnosticBindingObservation,
      codexLease: CodexNativeExecutableIdentityLease
    ) throws -> InvestigationMachineCurrentSourceBinding {
      let sourceFingerprintSHA256 = sourceFingerprint.hex
      guard sourceFingerprintSHA256.utf8.count == 64 else {
        throw InvestigationMachineCoordinatorBindingSourceError
          .invalidSourceFingerprint
      }
      do {
        try codexLease.revalidate()
      } catch {
        throw InvestigationMachineCoordinatorBindingSourceError
          .codexIdentityChanged
      }
      let runtimeReceipt: InvestigationRuntimeReceiptV1
      let runtimeReceiptSHA256: String
      do {
        runtimeReceipt =
          try InvestigationRuntimeReceiptCanonicalV1
          .receipt(
            repositoryHEAD: provenance.repositoryHEAD,
            sourceFingerprintSHA256: sourceFingerprintSHA256
          )
        runtimeReceiptSHA256 =
          try InvestigationRuntimeReceiptCanonicalV1.sha256(
            runtimeReceipt
          )
      } catch {
        throw InvestigationMachineCoordinatorBindingSourceError
          .invalidRuntimeReceipt
      }
      let machineDriver: SignedInvestigationRuntimeMachineDriverBinding
      do {
        machineDriver =
          try SignedInvestigationRuntimeMachineDriverBinding(
            executableSHA256:
              observation.machineDriverExecutableSHA256,
            signingIdentifier:
              observation.machineDriverSigningIdentifier,
            designatedRequirementSHA256:
              observation
              .machineDriverDesignatedRequirementSHA256,
            codeDirectoryHash:
              observation.machineDriverCodeDirectoryHash,
            machineClaimServiceIdentifier:
              observation.machineClaimServiceIdentifier
          )
      } catch {
        throw InvestigationMachineCoordinatorBindingSourceError
          .invalidInstalledObservation
      }
      let binding = SignedInvestigationRuntimeBinding(
        repositoryHEAD: provenance.repositoryHEAD,
        sourceFingerprintSHA256: sourceFingerprintSHA256,
        appExecutableSHA256: observation.appExecutableSHA256,
        helperExecutableSHA256: observation.helperExecutableSHA256,
        runtimeReceiptSHA256: runtimeReceiptSHA256,
        promptSHA256: provenance.promptSHA256,
        envelopeSchemaSHA256: provenance.envelopeSchemaSHA256,
        facadeSHA256: provenance.facadeSHA256,
        codexExecutableSHA256: codexLease.sha256,
        appBundleIdentifier: observation.appBundleIdentifier,
        helperServiceIdentifier: observation.serviceIdentifier,
        machineDriver: machineDriver
      )
      let installedBinding: InvestigationProjectedCohortInstalledBinding
      do {
        installedBinding = try InvestigationProjectedCohortInstalledBinding(
          appExecutableSHA256: observation.appExecutableSHA256,
          appBundleIdentifier: observation.appBundleIdentifier,
          helperExecutableSHA256:
            observation.helperExecutableSHA256,
          helperServiceIdentifier: observation.serviceIdentifier,
          machineDriverExecutableSHA256:
            observation.machineDriverExecutableSHA256,
          machineDriverSigningIdentifier:
            observation.machineDriverSigningIdentifier,
          machineDriverDesignatedRequirementSHA256:
            observation.machineDriverDesignatedRequirementSHA256,
          machineDriverCodeDirectoryHash:
            observation.machineDriverCodeDirectoryHash,
          machineClaimServiceIdentifier:
            observation.machineClaimServiceIdentifier
        )
      } catch {
        throw InvestigationMachineCoordinatorBindingSourceError
          .invalidInstalledObservation
      }
      guard binding.isValid, observation.matches(binding),
        installedBinding.matches(binding),
        binding.runtimeReceiptSHA256 == runtimeReceiptSHA256,
        binding.codexExecutableSHA256 == codexLease.sha256
      else {
        throw InvestigationMachineCoordinatorBindingSourceError
          .invalidBinding
      }
      do {
        try codexLease.revalidate()
      } catch {
        throw InvestigationMachineCoordinatorBindingSourceError
          .codexIdentityChanged
      }
      return InvestigationMachineCurrentSourceBinding(
        buildProvenance: provenance,
        buildProvenanceSHA256: provenance.sha256,
        sourceFingerprint: sourceFingerprint,
        runtimeReceipt: runtimeReceipt,
        binding: binding,
        installedBinding: installedBinding,
        codexNativeIdentityLease: codexLease
      )
    }
  }
#endif
