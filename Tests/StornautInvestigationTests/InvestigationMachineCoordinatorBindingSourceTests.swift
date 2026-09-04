import CryptoKit
import Darwin
import Foundation
import StornautCore
import StornautLifecycle
import Testing

@testable import StornautCodex
@testable import StornautInvestigation
@testable import StornautInvestigationDiagnostic
@testable import StornautInvestigationMachineGateCoordinatorSupport

@Suite("Investigation machine coordinator binding source", .serialized)
struct InvestigationMachineCoordinatorBindingSourceTests {
  @Test(
    .enabled(
      if: ProcessInfo.processInfo.environment[
        "STORNAUT_RUN_CURRENT_APP_BINDING_DIAGNOSTIC"
      ] == "1",
      "Opt in to the read-only current App and installed Codex binding diagnostic"
    )
  )
  func currentAppAndInstalledCodexComposeCompleteBinding() async throws {
    let environment = ProcessInfo.processInfo.environment
    let appPath = try #require(
      environment["STORNAUT_CURRENT_DIAGNOSTIC_APP"]
    )
    let builtApp = URL(
      filePath: appPath, directoryHint: .isDirectory
    ).standardizedFileURL
    let contract = try LifecycleLocalInstallationContract()
    let reader = LifecycleBundleSigningIdentityReader()
    let builtMain = builtApp.appending(
      path: "Contents/MacOS/StornautInvestigationDiagnostic"
    )
    let builtHelper = builtApp.appending(
      path: "Contents/MacOS/StornautLifecycleHelper"
    )
    let builtDriver = builtApp.appending(
      path: "Contents/MacOS/StornautInvestigationMachineDriver"
    )
    let observation = try InvestigationRuntimeDiagnosticBindingObservation
      .installed(
        contract: contract,
        signedAppObservation: { requested in
          guard requested == contract.installedAppURL else {
            throw LifecycleSigningIdentityError.unavailable
          }
          let value = try reader.signedBundleObservation(
            bundleURL: builtApp
          )
          #expect(value.mainExecutableURL == builtMain)
          return try LifecycleSignedBundleObservation(
            signingEvidence: value.signingEvidence,
            mainExecutableURL: contract.appExecutableURL,
            bundleIdentifier: value.bundleIdentifier
          )
        },
        signingEvidence: { requested in
          switch requested {
          case contract.helperExecutableURL:
            return try reader.evidence(bundleURL: builtHelper)
          case contract.machineDriverExecutableURL:
            return try reader.evidence(bundleURL: builtDriver)
          default:
            throw LifecycleSigningIdentityError.unavailable
          }
        }
      )
    let fixture = try CoordinatorBindingBehaviorFixture()
    defer { fixture.remove() }
    let lease = try await CodexNativeExecutableIdentitySource()
      .resolveInstalled()
    let sourceFingerprint = try fixture.sourceFingerprint()
    let current = try InvestigationMachineCurrentSourceBindingSource.make(
      provenance: fixture.provenance(),
      sourceFingerprint: sourceFingerprint,
      observation: observation,
      codexLease: lease
    )
    let wrapper = try InvestigationMachineGateCoordinatorBinding(
      currentSourceBinding: current
    )

    #expect(observation.helperSigningIdentifier
      == "com.eriklee.stornaut.lifecycle.helper")
    #expect(current.binding.isValid)
    #expect(observation.matches(current.binding))
    #expect(current.installedBinding.matches(current.binding))
    #expect(wrapper.sourceFingerprintSHA256
      == sourceFingerprint.hex)
    #expect(wrapper.signedBindingSHA256.utf8.count == 64)
    _ = builtMain
  }

  @Test
  func asyncBindingSourcePreservesClosedObservationFailureReason() async throws {
    let fixture = try CoordinatorBindingBehaviorFixture()
    defer { fixture.remove() }
    let observation = fixture.observation()
    let provenance = try fixture.provenance()
    let lease = try fixture.codexLease()

    let first = CoordinatorObservationResultProbe([
      .failure(.appSigningUnavailable),
    ])
    let firstSource = makeBindingSource(
      provenance: provenance, observations: first, lease: lease
    )
    let firstError = await Self.bindingSourceError(
      firstSource, fingerprint: try fixture.sourceFingerprint())
    #expect(first.callCount == 1)
    #expect(firstError == .appSigningUnavailable)

    for (failure, expected) in [
      (InvestigationRuntimeDiagnosticBindingObservationError
        .installationContractInvalid,
       InvestigationMachineCoordinatorBindingSourceError
        .installationContractInvalid),
      (InvestigationRuntimeDiagnosticBindingObservationError
        .helperSigningUnavailable,
       InvestigationMachineCoordinatorBindingSourceError
        .helperSigningUnavailable),
      (.machineDriverSigningUnavailable, .machineDriverSigningUnavailable),
      (.signedBundleMetadataUnavailable, .signedBundleMetadataUnavailable),
    ] {
      let second = CoordinatorObservationResultProbe([
        .success(observation), .failure(failure),
      ])
      let secondSource = makeBindingSource(
        provenance: provenance, observations: second, lease: lease
      )
      let secondError = await Self.bindingSourceError(
        secondSource, fingerprint: try fixture.sourceFingerprint())
      #expect(second.callCount == 2)
      #expect(secondError == expected)
    }
  }

  @Test
  func installedObservationDoesNotDependOnProcessMainBundleExecutable() throws {
    let source = try String(
      contentsOf: URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Sources/StornautInvestigationDiagnostic/"
          + "InvestigationRuntimeDiagnosticComposition.swift"),
      encoding: .utf8
    )
    let installedStart = try #require(source.range(
      of: "package static func installed() throws -> Self {"))
    let matchesStart = try #require(source.range(
      of: "package func matches(", range: installedStart.upperBound..<source.endIndex))
    let installed = source[installedStart.lowerBound..<matchesStart.lowerBound]

    let compact = installed.filter { !$0.isWhitespace }
    #expect(compact.contains(
      "appExecutableName:appObservation.mainExecutableURL"
        + ".lastPathComponent"))
    #expect(compact.contains(
      "appBundleIdentifier:appObservation.bundleIdentifier"))
    #expect(compact.contains(
      "signedAppObservation:reader.signedBundleObservation"))
    #expect(!compact.contains("Bundle(url:"))
    #expect(!compact.contains("bundle.executableURL"))
  }

  @Test
  func installedObservationMapsSigningAndMetadataFailuresExactly() throws {
    let fixture = try CoordinatorBindingBehaviorFixture()
    defer { fixture.remove() }
    let contract = try LifecycleLocalInstallationContract()
    let appObservation = try fixture.signedAppObservation()
    let signingEvidence = try fixture.signingEvidence()

    #expect(throws: InvestigationRuntimeDiagnosticBindingObservationError
      .appSigningUnavailable) {
        _ = try InvestigationRuntimeDiagnosticBindingObservation.installed(
          contract: contract,
          signedAppObservation: { _ in
            throw LifecycleSignedBundleObservationError
              .signingEvidenceUnavailable
          },
          signingEvidence: { _ in signingEvidence }
        )
    }
    #expect(throws: InvestigationRuntimeDiagnosticBindingObservationError
      .signedBundleMetadataUnavailable) {
        _ = try InvestigationRuntimeDiagnosticBindingObservation.installed(
          contract: contract,
          signedAppObservation: { _ in
            throw LifecycleSignedBundleObservationError
              .signedMetadataUnavailable
          },
          signingEvidence: { _ in signingEvidence }
        )
    }
    #expect(throws: InvestigationRuntimeDiagnosticBindingObservationError
      .signedBundleMetadataUnavailable) {
        let foreignEvidence = try LifecycleBundleSigningEvidence(
          identity: LifecycleSigningIdentity(
            signingIdentifier: "com.eriklee.foreign",
            designatedRequirementSHA256: String(repeating: "4", count: 64),
            codeDirectoryHash: String(repeating: "5", count: 40)
          ),
          executableSHA256: String(repeating: "1", count: 64),
          isAdHoc: true
        )
        let foreign = try LifecycleSignedBundleObservation(
          signingEvidence: foreignEvidence,
          mainExecutableURL: contract.appExecutableURL,
          bundleIdentifier: "com.eriklee.foreign"
        )
        _ = try InvestigationRuntimeDiagnosticBindingObservation.installed(
          contract: contract,
          signedAppObservation: { _ in foreign },
          signingEvidence: { _ in signingEvidence }
        )
    }
    #expect(throws: InvestigationRuntimeDiagnosticBindingObservationError
      .signedBundleMetadataUnavailable) {
        let foreign = try LifecycleSignedBundleObservation(
          signingEvidence: signingEvidence,
          mainExecutableURL: contract.installedAppURL.appending(
            path: "Contents/MacOS/ForeignExecutable"
          ),
          bundleIdentifier: "com.eriklee.stornaut"
        )
        _ = try InvestigationRuntimeDiagnosticBindingObservation.installed(
          contract: contract,
          signedAppObservation: { _ in foreign },
          signingEvidence: { _ in signingEvidence }
        )
    }
    #expect(throws: InvestigationRuntimeDiagnosticBindingObservationError
      .helperSigningUnavailable) {
        _ = try InvestigationRuntimeDiagnosticBindingObservation.installed(
          contract: contract,
          signedAppObservation: { _ in appObservation },
          signingEvidence: { url in
            if url == contract.helperExecutableURL {
              throw LifecycleSigningIdentityError.unavailable
            }
            return signingEvidence
          }
        )
    }
    #expect(throws: InvestigationRuntimeDiagnosticBindingObservationError
      .machineDriverSigningUnavailable) {
        _ = try InvestigationRuntimeDiagnosticBindingObservation.installed(
          contract: contract,
          signedAppObservation: { _ in appObservation },
          signingEvidence: { url in
            if url == contract.machineDriverExecutableURL {
              throw LifecycleSigningIdentityError.unavailable
            }
            return signingEvidence
          }
        )
    }
  }

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
      .installedObservationChanged) {
        _ = try await drifted.make(
          sourceFingerprint: fixture.sourceFingerprint()
        )
      }
    #expect(drift.callCount == 2)
  }

  @Test
  func asyncBindingSourceKeepsUnknownCodexFailureOutOfObservationReason()
    async throws
  {
    let fixture = try CoordinatorBindingBehaviorFixture()
    defer { fixture.remove() }
    let observation = fixture.observation()
    let provenance = try fixture.provenance()
    let probe = CoordinatorObservationProbe([observation])
    let source = InvestigationMachineCurrentSourceBindingSource(
      buildProvenance: { provenance },
      installedObservation: probe.next,
      resolveCodexIdentity: { throw CocoaError(.fileReadUnknown) }
    )

    await #expect(throws: InvestigationMachineCoordinatorBindingSourceError
      .codexIdentityUnavailable) {
        _ = try await source.make(
          sourceFingerprint: fixture.sourceFingerprint()
        )
      }
    #expect(probe.callCount == 1)
  }

  @Test
  func unknownInstalledObservationFailuresPreserveTheirPhase() async throws {
    let fixture = try CoordinatorBindingBehaviorFixture()
    defer { fixture.remove() }
    let provenance = try fixture.provenance()
    let lease = try fixture.codexLease()

    let initial = CoordinatorAnyObservationResultProbe([
      .failure(CocoaError(.fileReadUnknown)),
    ])
    let initialSource = InvestigationMachineCurrentSourceBindingSource(
      buildProvenance: { provenance },
      installedObservation: initial.next,
      resolveCodexIdentity: { lease }
    )
    #expect(await Self.bindingSourceError(
      initialSource, fingerprint: try fixture.sourceFingerprint()
    ) == .initialInstalledObservationInvalid)

    let final = CoordinatorAnyObservationResultProbe([
      .success(fixture.observation()),
      .failure(CocoaError(.fileReadUnknown)),
    ])
    let finalSource = InvestigationMachineCurrentSourceBindingSource(
      buildProvenance: { provenance },
      installedObservation: final.next,
      resolveCodexIdentity: { lease }
    )
    #expect(await Self.bindingSourceError(
      finalSource, fingerprint: try fixture.sourceFingerprint()
    ) == .finalInstalledObservationInvalid)
  }

  @Test
  func asyncBindingSourcePreservesClosedCodexResolutionReason() async throws {
    let fixture = try CoordinatorBindingBehaviorFixture()
    defer { fixture.remove() }
    let failures: [(
      CodexNativeExecutableIdentityError,
      InvestigationMachineCoordinatorBindingSourceError
    )] = [
      (.unavailable, .codexIdentityUnavailable),
      (.invalidLayout, .codexLayoutInvalid),
      (.invalidExecutable(stage: "open-13"), .codexExecutableOpenInvalid),
      (.invalidExecutable(stage: "metadata"),
       .codexExecutableMetadataInvalid),
      (.invalidExecutable(stage: "acl-read"), .codexExecutableACLInvalid),
      (.invalidExecutable(stage: "xattr"), .codexExecutableXattrInvalid),
      (.invalidExecutable(stage: "xattr-read"),
       .codexExecutableXattrInvalid),
      (.identityChanged, .codexIdentityChanged),
      (.stagedDigestMismatch, .codexIdentityChanged),
    ]

    for (failure, expected) in failures {
      let probe = CoordinatorObservationProbe([fixture.observation()])
      let provenance = try fixture.provenance()
      let source = InvestigationMachineCurrentSourceBindingSource(
        buildProvenance: { provenance },
        installedObservation: probe.next,
        resolveCodexIdentity: { throw failure }
      )
      let observed = await Self.bindingSourceError(
        source, fingerprint: try fixture.sourceFingerprint()
      )
      #expect(observed == expected)
      #expect(probe.callCount == 1)
    }
  }

  @Test
  func bindingConstructionFailuresPreserveClosedReasons() throws {
    let fixture = try CoordinatorBindingBehaviorFixture()
    defer { fixture.remove() }
    let provenance = try fixture.provenance()
    let fingerprint = try fixture.sourceFingerprint()
    let lease = try fixture.codexLease()

    for (observation, expected) in [
      (fixture.observation(
        machineDriverSigningIdentifier: "foreign.machine-driver"
      ), InvestigationMachineCoordinatorBindingSourceError
        .machineDriverBindingInvalid),
      (fixture.observation(appBundleIdentifier: "foreign.app"),
       InvestigationMachineCoordinatorBindingSourceError
        .installedBindingInvalid),
      (fixture.observation(
        helperSigningIdentifier: "foreign.helper"
      ), InvestigationMachineCoordinatorBindingSourceError
        .bindingJoinInvalid),
    ] {
      #expect(throws: expected) {
          _ = try InvestigationMachineCurrentSourceBindingSource.make(
            provenance: provenance,
            sourceFingerprint: fingerprint,
            observation: observation,
            codexLease: lease
          )
        }
    }
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
    let expectedCohortDeadline = fixture.now.addingTimeInterval(1_200)
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
      #expect(row.plan.expiresAt == fixture.now.addingTimeInterval(600))
      #expect(row.configuration.validBefore == expectedCohortDeadline)
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
              from: data, now: fixture.now
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

  private func makeBindingSource(
    provenance: InvestigationMachineBuildProvenanceReceiptV1,
    observations: CoordinatorObservationResultProbe,
    lease: CodexNativeExecutableIdentityLease
  ) -> InvestigationMachineCurrentSourceBindingSource {
    InvestigationMachineCurrentSourceBindingSource(
      buildProvenance: { provenance },
      installedObservation: observations.next,
      resolveCodexIdentity: { lease }
    )
  }

  private static func bindingSourceError(
    _ source: InvestigationMachineCurrentSourceBindingSource,
    fingerprint: InvestigationFingerprint
  ) async -> InvestigationMachineCoordinatorBindingSourceError? {
    do {
      _ = try await source.make(sourceFingerprint: fingerprint)
      return nil
    } catch let error as InvestigationMachineCoordinatorBindingSourceError {
      return error
    } catch {
      return nil
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
    appExecutableSHA256: String = String(repeating: "1", count: 64),
    appBundleIdentifier: String = "com.eriklee.stornaut",
    helperSigningIdentifier: String =
      "com.eriklee.stornaut.lifecycle.helper",
    machineDriverSigningIdentifier: String =
      SignedInvestigationRuntimeMachineDriverBinding
      .requiredSigningIdentifier
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
      appBundleIdentifier: appBundleIdentifier,
      helperSigningIdentifier: helperSigningIdentifier,
      serviceIdentifier: "com.eriklee.stornaut.lifecycle",
      machineDriverExecutableURL: app.appending(
        path: "Contents/MacOS/StornautInvestigationMachineDriver"
      ),
      machineDriverExecutableSHA256:
        String(repeating: "3", count: 64),
      machineDriverSigningIdentifier: machineDriverSigningIdentifier,
      machineDriverDesignatedRequirementSHA256:
        String(repeating: "4", count: 64),
      machineDriverCodeDirectoryHash:
        String(repeating: "5", count: 40),
      machineClaimServiceIdentifier:
        SignedInvestigationRuntimeMachineDriverBinding
        .requiredMachineClaimServiceIdentifier
    )
  }

  func signingEvidence() throws -> LifecycleBundleSigningEvidence {
    try LifecycleBundleSigningEvidence(
      identity: LifecycleSigningIdentity(
        signingIdentifier: "com.eriklee.stornaut",
        designatedRequirementSHA256: String(repeating: "4", count: 64),
        codeDirectoryHash: String(repeating: "5", count: 40)
      ),
      executableSHA256: String(repeating: "1", count: 64),
      isAdHoc: true
    )
  }

  func signedAppObservation() throws -> LifecycleSignedBundleObservation {
    let contract = try LifecycleLocalInstallationContract()
    return try LifecycleSignedBundleObservation(
      signingEvidence: signingEvidence(),
      mainExecutableURL: contract.appExecutableURL,
      bundleIdentifier: "com.eriklee.stornaut"
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
private final class CoordinatorObservationResultProbe: @unchecked Sendable {
  private let lock = NSLock()
  private var values: [Result<
    InvestigationRuntimeDiagnosticBindingObservation,
    InvestigationRuntimeDiagnosticBindingObservationError
  >]
  private(set) var callCount = 0

  init(_ values: [Result<
    InvestigationRuntimeDiagnosticBindingObservation,
    InvestigationRuntimeDiagnosticBindingObservationError
  >]) {
    self.values = values
  }

  func next() throws -> InvestigationRuntimeDiagnosticBindingObservation {
    try lock.withLock {
      guard !values.isEmpty else { throw CocoaError(.fileReadUnknown) }
      callCount += 1
      return try values.removeFirst().get()
    }
  }
}

private final class CoordinatorAnyObservationResultProbe: @unchecked Sendable {
  private enum Value {
    case success(InvestigationRuntimeDiagnosticBindingObservation)
    case failure(any Error)
  }
  private let lock = NSLock()
  private var values: [Value]
  private(set) var callCount = 0

  init(_ values: [Result<
    InvestigationRuntimeDiagnosticBindingObservation, CocoaError
  >]) {
    self.values = values.map { value in
      switch value {
      case .success(let observation): .success(observation)
      case .failure(let error): .failure(error)
      }
    }
  }

  func next() throws -> InvestigationRuntimeDiagnosticBindingObservation {
    try lock.withLock {
      guard !values.isEmpty else { throw CocoaError(.fileReadUnknown) }
      callCount += 1
      switch values.removeFirst() {
      case .success(let observation): return observation
      case .failure(let error): throw error
      }
    }
  }
}
