import CryptoKit
import Darwin
import Foundation
import StornautCore
import Testing

@testable import StornautCodex
@testable import StornautInvestigation
@testable import StornautInvestigationDiagnostic
@testable import StornautInvestigationMachineGateCoordinatorSupport

@Suite("Investigation machine coordinator binding source", .serialized)
struct InvestigationMachineCoordinatorBindingSourceTests {
  @Test
  func asyncBindingSourceRequiresStableInstalledObservation() async throws {
    let fixture = try CoordinatorBindingBehaviorFixture()
    defer { fixture.remove() }
    let observation = fixture.observation()
    let provenance = try fixture.provenance()
    let lease = try fixture.codexLease()
    let stable = CoordinatorObservationProbe([observation, observation])
    let source = InvestigationMachineCurrentSourceBindingSource(
      buildProvenance: { provenance },
      installedObservation: stable.next,
      resolveCodexIdentity: { lease }
    )
    let result = try await source.make(
      sourceFingerprint: fixture.sourceFingerprint()
    )
    #expect(result.binding.appExecutableSHA256
      == observation.appExecutableSHA256)
    #expect(stable.callCount == 2)

    let drift = CoordinatorObservationProbe([
      observation, fixture.observation(
        appExecutableSHA256: String(repeating: "0", count: 64)
      ),
    ])
    let drifted = InvestigationMachineCurrentSourceBindingSource(
      buildProvenance: { provenance },
      installedObservation: drift.next,
      resolveCodexIdentity: { lease }
    )
    await #expect(throws: InvestigationMachineCoordinatorBindingSourceError
      .invalidInstalledObservation) {
        _ = try await drifted.make(
          sourceFingerprint: fixture.sourceFingerprint()
        )
      }
    #expect(drift.callCount == 2)
  }

  @Test
  func bindingSourceJoinsEveryAuthoritativeField() throws {
    let fixture = try CoordinatorBindingBehaviorFixture()
    defer { fixture.remove() }
    let provenance = try fixture.provenance()
    let sourceFingerprint = try fixture.sourceFingerprint()
    let observation = fixture.observation()
    let codexLease = try fixture.codexLease()
    let result = try InvestigationMachineCurrentSourceBindingSource.make(
      provenance: provenance,
      sourceFingerprint: sourceFingerprint,
      observation: observation,
      codexLease: codexLease
    )
    let binding = result.binding
    let expectedReceipt = try InvestigationRuntimeReceiptCanonicalV1.receipt(
      repositoryHEAD: provenance.repositoryHEAD,
      sourceFingerprintSHA256: sourceFingerprint.hex
    )
    let expectedReceiptSHA256 =
      try InvestigationRuntimeReceiptCanonicalV1
      .sha256(expectedReceipt)
    #expect(result.buildProvenance == provenance)
    #expect(result.buildProvenanceSHA256 == provenance.sha256)
    #expect(result.sourceFingerprint == sourceFingerprint)
    #expect(result.runtimeReceipt == expectedReceipt)
    #expect(result.installedBinding.matches(binding))
    #expect(result.codexNativeIdentityLease === codexLease)
    #expect(codexLease.canonicalURL == fixture.nativeURL.standardizedFileURL)
    #expect(codexLease.canonicalURL != fixture.wrapperURL)
    #expect([
      binding.repositoryHEAD == provenance.repositoryHEAD,
      binding.sourceFingerprintSHA256 == sourceFingerprint.hex,
      binding.appExecutableSHA256 == observation.appExecutableSHA256,
      binding.helperExecutableSHA256 == observation.helperExecutableSHA256,
      binding.runtimeReceiptSHA256 == expectedReceiptSHA256,
      binding.promptSHA256 == provenance.promptSHA256,
      binding.envelopeSchemaSHA256 == provenance.envelopeSchemaSHA256,
      binding.facadeSHA256 == provenance.facadeSHA256,
      binding.codexExecutableSHA256 == codexLease.sha256,
      binding.appBundleIdentifier == observation.appBundleIdentifier,
      binding.helperServiceIdentifier == observation.serviceIdentifier,
      binding.machineDriver.executableSHA256
        == observation.machineDriverExecutableSHA256,
      binding.machineDriver.signingIdentifier
        == observation.machineDriverSigningIdentifier,
      binding.machineDriver.designatedRequirementSHA256
        == observation.machineDriverDesignatedRequirementSHA256,
      binding.machineDriver.codeDirectoryHash
        == observation.machineDriverCodeDirectoryHash,
      binding.machineDriver.machineClaimServiceIdentifier
        == observation.machineClaimServiceIdentifier,
    ].allSatisfy { $0 })
    #expect(Set([
      binding.repositoryHEAD, binding.sourceFingerprintSHA256,
      provenance.repositoryTree, provenance.canonicalManifestSHA256,
      result.buildProvenanceSHA256,
    ]).count == 5)
    #expect(try result.runtimeReceiptReconstructedAndValidated() == expectedReceipt)
  }

  @Test
  func configurationSetEagerlyBuildsEightRowsWithSharedCohortDeadline() throws {
    let fixture = try CoordinatorBindingBehaviorFixture()
    defer { fixture.remove() }
    let current = try fixture.currentSourceBinding()
    let plan = try fixture.canonicalPlan(
      sourceFingerprint: current.sourceFingerprint
    )
    let identifiers = fixture.generatedIdentifiers()
    let attemptRoot = try fixture.attemptRoot(named: "attempt-eight-rows")
    try fixture.materializeConfigurationRoots(
      attemptRoot: attemptRoot, identifiers: identifiers
    )
    let source = fixture.configurationSource(identifiers: identifiers)
    let result = try source.make(
      currentSourceBinding: current,
      canonicalPlan: plan,
      attemptRoot: attemptRoot,
      now: fixture.now
    )
    let scenarios = SignedInvestigationRuntimeDiagnosticScenario.allCases
    let rows = result.rows
    #expect(rows.count == 8)
    #expect(result.configurations.count == 8)
    #expect(result.canonicalConfigurationData.count == 8)
    #expect(result.binding == current.binding)
    #expect(result.runtimeReceipt == current.runtimeReceipt)
    #expect(rows.map(\.scenario) == scenarios)
    for uniqueCount in [
      Set(rows.map { $0.configuration.nonce }).count,
      Set(rows.map(\.investigationID)).count, Set(rows.map(\.runID)).count,
      Set(rows.map { $0.plan.fingerprint }).count,
      Set(rows.map { $0.configuration.diagnosticRootPath }).count,
    ] {
      #expect(uniqueCount == 8)
    }
    for index in rows.indices {
      let row = rows[index]
      let nonce = identifiers.configurationNonces[index]
      let expectedRoot = fixture.epochRoot(
        attemptRoot: attemptRoot, index: index, nonce: nonce
      )
      #expect(row.scenario == scenarios[index])
      #expect(row.configuration.nonce == nonce)
      #expect(row.investigationID == identifiers.investigationIDs[index])
      #expect(row.runID == identifiers.runIDs[index])
      #expect(row.plan.id == row.investigationID)
      #expect(row.plan.sourceFingerprint == current.sourceFingerprint)
      #expect(row.plan.targetSetFingerprint == plan.targetSetFingerprint)
      #expect(row.configuration.binding == current.binding)
      #expect(row.configuration.maximumWallClockSeconds == 140)
      #expect(row.configuration.validBefore == plan.expiresAt)
      #expect(row.configuration.diagnosticRootPath == expectedRoot.path)
      #expect(row.configuration.sourceRootPath
        == expectedRoot.appending(path: "source").path)
      #expect(row.configuration.supportRootPath
        == expectedRoot.appending(path: "support").path)
      #expect(row.configuration.runtimeRootPath
        == expectedRoot.appending(path: "runtime").path)
      #expect(try row.configuration.canonicalJSONData()
        == row.canonicalConfigurationData)
      #expect(try InvestigationRuntimeDiagnosticReceiptJoin.reconstruct(
        from: row.configuration.binding) == current.runtimeReceipt)
    }
    #expect(Set(rows.map { $0.configuration.validBefore }).count == 1)
    for data in result.canonicalConfigurationData {
      #expect(throws: SignedInvestigationRuntimeContractError
        .invalidConfiguration) {
          _ = try SignedInvestigationRuntimeDiagnosticConfiguration
            .decodeValidated(
              from: data, now: plan.expiresAt
            )
        }
    }
  }

  @Test
  func sourceFixtureTemplateIsFixedAndPlanBound() throws {
    let template = InvestigationMachineCoordinatorSourceFixtureTemplate.self
    #expect(template.files.count == 1)
    let file = try #require(template.files.first)
    #expect(file.relativePath == "candidate/source-evidence.txt")
    #expect(
      file.bytes
        == Data(
          "STORNAUT_MACHINE_COORDINATOR_SOURCE_V1\n".utf8
        )
    )
    #expect(
      SHA256.hash(data: file.bytes).map {
        String(format: "%02x", $0)
      }.joined()
        == "25520c1a895baac099972eb6c324651e479f0f4f12e6f093089044cf175df8e7"
    )
    #expect(template.relevanceTokens.map(\.rawValue) == ["relevance.developer"])
    #expect(template.classificationCategory == .unknownLargeConsumers)
    #expect(template.classificationDisposition == .unknown)
    #expect(template.classificationRisk == .low)
    #expect(template.classificationConfidence == .high)
    #expect(template.expectedTargetKind == .unknownProducer)
    #expect(template.expectedTargetAllocatedBytes == ByteCount(4_096))
    #expect(file.bytes.count == 39)
    #expect(template.expectedTargetAllocatedBytes.value != UInt64(file.bytes.count))
    #expect(template.expectedReasonKeys.map(\.rawValue) == ["reason.unknown-producer"])
    let fixture = try CoordinatorBindingBehaviorFixture()
    defer { fixture.remove() }
    let fingerprint = try fixture.sourceFingerprint()
    let plan = try fixture.canonicalPlan(sourceFingerprint: fingerprint)
    #expect(template.validates(plan, sourceFingerprint: fingerprint, now: fixture.now))
    for mutation in [
      try fixture.canonicalPlan(
        sourceFingerprint: fingerprint,
        expectedAllocatedBytes: ByteCount(39)
      ),
      try fixture.canonicalPlan(
        sourceFingerprint: fingerprint,
        expectedAllocatedBytes: ByteCount(8_192)
      ),
      try fixture.canonicalPlan(
        sourceFingerprint: fingerprint,
        targetCreatedAt: fixture.now.addingTimeInterval(-1)
      ),
      try fixture.canonicalPlan(
        sourceFingerprint: fingerprint,
        planCreatedAt: fixture.now.addingTimeInterval(-1)
      ),
    ] {
      #expect(
        !template.validates(
          mutation, sourceFingerprint: fingerprint, now: fixture.now
        )
      )
    }
  }

  @Test
  func configurationSetRejectsIdentifierAndSourceDrift() throws {
    let fixture = try CoordinatorBindingBehaviorFixture()
    defer { fixture.remove() }
    let current = try fixture.currentSourceBinding()
    let plan = try fixture.canonicalPlan(
      sourceFingerprint: current.sourceFingerprint
    )
    let identifiers = fixture.generatedIdentifiers()
    var duplicateNonces = identifiers.configurationNonces
    duplicateNonces[1] = duplicateNonces[0]
    let duplicate = InvestigationMachineCoordinatorGeneratedIdentifiers(
      configurationNonces: duplicateNonces,
      investigationIDs: identifiers.investigationIDs,
      runIDs: identifiers.runIDs
    )
    #expect(
      throws:
        InvestigationMachineCoordinatorConfigurationSetError
        .invalidIdentifiers
    ) {
      _ = try fixture.configurationSource(identifiers: duplicate).make(
        currentSourceBinding: current,
        canonicalPlan: plan,
        attemptRoot: try fixture.attemptRoot(
          named: "attempt-duplicate-identifiers"
        ),
        now: fixture.now
      )
    }
    var foreignInvestigationIDs = identifiers.investigationIDs
    foreignInvestigationIDs[0] = InvestigationID(
      rawValue: "investigation-foreign-iv-a"
    )!
    let foreign = InvestigationMachineCoordinatorGeneratedIdentifiers(
      configurationNonces: identifiers.configurationNonces,
      investigationIDs: foreignInvestigationIDs,
      runIDs: identifiers.runIDs
    )
    #expect(
      throws:
        InvestigationMachineCoordinatorConfigurationSetError
        .invalidIdentifiers
    ) {
      _ = try fixture.configurationSource(identifiers: foreign).make(
        currentSourceBinding: current,
        canonicalPlan: plan,
        attemptRoot: try fixture.attemptRoot(
          named: "attempt-foreign-identifiers"
        ),
        now: fixture.now
      )
    }
    let foreignSource = try InvestigationFingerprint(
      validating: Data(repeating: 0xfe, count: 32)
    )
    let foreignPlan = try fixture.canonicalPlan(
      sourceFingerprint: foreignSource
    )
    #expect(
      throws:
        InvestigationMachineCoordinatorConfigurationSetError
        .invalidTemplatePlan
    ) {
      _ = try fixture.configurationSource(identifiers: identifiers).make(
        currentSourceBinding: current,
        canonicalPlan: foreignPlan,
        attemptRoot: try fixture.attemptRoot(
          named: "attempt-foreign-source"
        ),
        now: fixture.now
      )
    }
  }

}

private final class CoordinatorBindingBehaviorFixture {
  let now = Date(timeIntervalSince1970: 1_800_900_000)
  let root: URL
  let wrapperURL: URL
  let nativeURL: URL

  init() throws {
    root = URL(filePath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appending(path: ".build", directoryHint: .isDirectory)
      .appending(
        path: "InvestigationMachineCoordinatorBindingSourceTests-"
          + UUID().uuidString,
        directoryHint: .isDirectory
      )
    wrapperURL = root.appending(
      path: "lib/node_modules/@openai/codex/bin/codex.js"
    )
    nativeURL = root.appending(
      path:
        "lib/node_modules/@openai/codex/node_modules/@openai/"
        + "codex-darwin-arm64/vendor/aarch64-apple-darwin/bin/codex"
    )
    try writeExecutable(
      Data("#!/usr/bin/env node\n".utf8),
      to: wrapperURL
    )
    try writeExecutable(
      Data("fake-codex-native-iv-a\n".utf8),
      to: nativeURL
    )
  }

  func remove() {
    try? FileManager.default.removeItem(at: root)
  }
  func provenance() throws
    -> InvestigationMachineBuildProvenanceReceiptV1
  {
    try InvestigationMachineBuildProvenanceReceiptV1(
      repositoryHEAD: String(repeating: "a", count: 40),
      repositoryTree: String(repeating: "c", count: 40),
      canonicalManifestSHA256: String(repeating: "d", count: 64),
      buildConfiguration: "debug",
      coordinatorTargetIdentifier:
        InvestigationMachineBuildProvenanceReceiptV1
        .requiredTargetIdentifier,
      coordinatorProductIdentifier:
        InvestigationMachineBuildProvenanceReceiptV1
        .requiredProductIdentifier,
      promptSHA256: String(repeating: "6", count: 64),
      envelopeSchemaSHA256: String(repeating: "7", count: 64),
      facadeSHA256: String(repeating: "8", count: 64)
    )
  }

  func sourceFingerprint() throws -> InvestigationFingerprint {
    try InvestigationFingerprint(
      validating: Data(repeating: 0xb2, count: 32)
    )
  }
  func observation(
    appExecutableSHA256: String = String(repeating: "1", count: 64)
  ) -> InvestigationRuntimeDiagnosticBindingObservation {
    let app = URL(
      filePath:
        "/Library/Application Support/Stornaut/"
        + "Stornaut-R5-Diagnostic.app",
      directoryHint: .isDirectory
    )
    return InvestigationRuntimeDiagnosticBindingObservation(
      installedAppURL: app,
      helperExecutableURL: app.appending(
        path: "Contents/MacOS/StornautLifecycleHelper"
      ),
      appExecutableName: "StornautInvestigationDiagnostic",
      appExecutableSHA256: appExecutableSHA256,
      helperExecutableSHA256: String(repeating: "2", count: 64),
      appBundleIdentifier: "com.eriklee.stornaut",
      helperSigningIdentifier:
        "com.eriklee.stornaut.lifecycle.helper",
      serviceIdentifier: "com.eriklee.stornaut.lifecycle",
      machineDriverExecutableURL: app.appending(
        path: "Contents/MacOS/StornautInvestigationMachineDriver"
      ),
      machineDriverExecutableSHA256:
        String(repeating: "3", count: 64),
      machineDriverSigningIdentifier:
        SignedInvestigationRuntimeMachineDriverBinding
        .requiredSigningIdentifier,
      machineDriverDesignatedRequirementSHA256:
        String(repeating: "4", count: 64),
      machineDriverCodeDirectoryHash:
        String(repeating: "5", count: 40),
      machineClaimServiceIdentifier:
        SignedInvestigationRuntimeMachineDriverBinding
        .requiredMachineClaimServiceIdentifier
    )
  }

  func codexLease() throws -> CodexNativeExecutableIdentityLease {
    try CodexNativeExecutableIdentitySource().resolve(
      installation: CodexInstallation(
        executableURL: wrapperURL,
        source: .configured
      ),
      expectedUserID: geteuid()
    )
  }
  func currentSourceBinding() throws
    -> InvestigationMachineCurrentSourceBinding
  {
    try InvestigationMachineCurrentSourceBindingSource.make(
      provenance: provenance(),
      sourceFingerprint: sourceFingerprint(),
      observation: observation(),
      codexLease: codexLease()
    )
  }

  func canonicalPlan(
    sourceFingerprint: InvestigationFingerprint,
    expectedAllocatedBytes: ByteCount? = ByteCount(4_096),
    targetCreatedAt: Date? = nil,
    planCreatedAt: Date? = nil
  ) throws -> InvestigationPlan {
    let template = InvestigationMachineCoordinatorSourceFixtureTemplate.self
    let scanSessionID = template.scanSessionID
    let scanScopeID = template.primaryScopeID
    let target = try InvestigationTarget(
      scanSessionID: scanSessionID,
      scanScopeID: scanScopeID,
      sourceBinding: .classification(
        classificationID: template.classificationID,
        snapshotID: template.candidateSnapshotID
      ),
      kind: template.expectedTargetKind,
      reasonKeys: template.expectedReasonKeys,
      expectedAllocatedBytes: expectedAllocatedBytes,
      uncertaintyPermille: 850,
      relevancePermille: 800,
      investigationCostPermille: 400,
      createdAt: targetCreatedAt ?? planCreatedAt ?? now
    )
    return try InvestigationPlan(
      id: template.templateInvestigationID,
      scanSessionID: scanSessionID,
      scanScopeID: scanScopeID,
      sourceFingerprint: sourceFingerprint,
      budgetPreset: .focused,
      targets: [target],
      createdAt: planCreatedAt ?? now,
      expiresAt: now.addingTimeInterval(600),
      requestedCoveragePermille:
        InvestigationPlan.policyRequestedCoveragePermille,
      remainingUnknownByteThreshold:
        InvestigationPlan.policyRemainingUnknownByteThreshold,
      requiredCapabilities: InvestigationCapability.required
    )
  }

  func generatedIdentifiers()
    -> InvestigationMachineCoordinatorGeneratedIdentifiers
  {
    let nonces = (1...8).map { index in
      UUID(
        uuidString: String(
          format: "00000000-0000-4000-8000-%012d", index
        )
      )!
    }
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
  func configurationSource(
    identifiers: InvestigationMachineCoordinatorGeneratedIdentifiers
  ) -> InvestigationMachineCoordinatorConfigurationSetSource {
    InvestigationMachineCoordinatorConfigurationSetSource(
      identifiers: { identifiers }
    )
  }

  func epochRoot(attemptRoot: URL, index: Int, nonce: UUID) -> URL {
    attemptRoot.appending(
      path: String(
        format: "epoch-%02d-%@", index,
        nonce.uuidString.lowercased()
      ),
      directoryHint: .isDirectory
    )
  }
  func attemptRoot(named name: String) throws -> URL {
    let url = root.appending(path: name, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(
      at: url,
      withIntermediateDirectories: false,
      attributes: [.posixPermissions: 0o700]
    )
    return url
  }

  func materializeConfigurationRoots(
    attemptRoot: URL,
    identifiers: InvestigationMachineCoordinatorGeneratedIdentifiers
  ) throws {
    for index in identifiers.configurationNonces.indices {
      let root = epochRoot(
        attemptRoot: attemptRoot,
        index: index,
        nonce: identifiers.configurationNonces[index]
      )
      for url in [root, root.appending(path: "source"),
                  root.appending(path: "support"),
                  root.appending(path: "support/com.eriklee.stornaut"),
                  root.appending(path: "runtime")] {
        try FileManager.default.createDirectory(
          at: url, withIntermediateDirectories: false,
          attributes: [.posixPermissions: 0o700]
        )
      }
    }
  }

  private func writeExecutable(_ data: Data, to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try data.write(to: url)
    guard chmod(url.path, 0o755) == 0 else {
      throw POSIXError(POSIXErrorCode(rawValue: errno)!)
    }
  }
}
private final class CoordinatorObservationProbe: @unchecked Sendable {
  private let lock = NSLock()
  private var values: [InvestigationRuntimeDiagnosticBindingObservation]
  private(set) var callCount = 0
  init(_ values: [InvestigationRuntimeDiagnosticBindingObservation]) {
    self.values = values
  }
  func next() throws -> InvestigationRuntimeDiagnosticBindingObservation {
    try lock.withLock {
      guard !values.isEmpty else { throw CocoaError(.fileReadUnknown) }
      callCount += 1
      return values.removeFirst()
    }
  }
}
