import CryptoKit
import Darwin
import Foundation
import StornautCore
import StornautInvestigation
import StornautInvestigationDiagnostic
import StornautInvestigationHandoffContract
import StornautInvestigationMachineGateSupport
import StornautInvestigationMachineLaunchSupport
public enum InvestigationMachineGateCoordinatorSupport {
  package static let completedExitStatus: Int32 = 0
  package static let unavailableExitStatus: Int32 = 78
  package static let invalidInvocationExitStatus: Int32 = 80
  package static let protocolFailureExitStatus: Int32 = 81
  package static let containmentUncertainExitStatus: Int32 = 82
  package static let cancelledExitStatus: Int32 = 83
  public static func run() async -> Int32 {
    #if DEBUG
      let context = InvestigationMachineGateCoordinatorProductionContext()
      let sink = InvestigationMachineGateCoordinatorReceiptSink()
      let composition = InvestigationMachineGateCoordinatorComposition(
        dependencies: .production(context: context, sink: sink)
      )
      do {
        _ = try await composition.run()
        return completedExitStatus
      } catch {
        return status(for: error)
      }
    #else
      return unavailableExitStatus
    #endif
  }
  #if DEBUG
    package static func status(for error: any Error) -> Int32 {
      if error is CancellationError { return cancelledExitStatus }
      if let error = error as? InvestigationFixedGateHandoffError {
        switch error {
        case .forwardedSignal:
          return cancelledExitStatus
        case .spawnUncertain, .exactReapUncertain,
             .transportCloseUncertain, .settlementResidue,
             .settlementFailed, .proofRejected:
          return containmentUncertainExitStatus
        default:
          return protocolFailureExitStatus
        }
      }
      if let error = error
        as? InvestigationMachineGateCoordinatorProductionError {
        switch error {
        case .invalidInvocation:
          return invalidInvocationExitStatus
        case .protocolFailure, .postSettlementProtocolFailure:
          return protocolFailureExitStatus
        case .containmentUncertain:
          return containmentUncertainExitStatus
        }
      }
      if let error = error as? InvestigationMachineGateCoordinatorSystemError {
        return error.kind == .protocolFailure
          ? protocolFailureExitStatus : containmentUncertainExitStatus
      }
      if error is InvestigationMachineGateCoordinatorReceiptError { return protocolFailureExitStatus }
      if let error = error
        as? InvestigationMachineGateCoordinatorPreArmFailureReportedError {
        return error.reason.expectedExitStatus
      }
      if let error = error
        as? InvestigationMachineGateCoordinatorCompositionError {
        return error == .retirementUncertain
          ? containmentUncertainExitStatus : protocolFailureExitStatus
      }
      return containmentUncertainExitStatus
    }
  #endif
}
#if DEBUG
  @_silgen_name("_NSGetEnviron")
  private func investigationMachineCoordinatorEnvironmentPointer()
    -> UnsafeMutablePointer<UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?>
  enum InvestigationMachineGateCoordinatorProductionError:
    Error, Equatable, Sendable
  {
    case invalidInvocation
    case protocolFailure
    case postSettlementProtocolFailure
    case containmentUncertain
  }
  private struct InvestigationMachineGateCoordinatorSystemError:
    Error, CustomStringConvertible, Sendable
  {
    enum Kind: Sendable { case protocolFailure, containmentUncertain }
    let kind: Kind
    let operation: String
    var description: String { "coordinator system failure: " + operation }
  }
  package enum InvestigationMachineGateCoordinatorCompositionError:
    Error, Equatable, Sendable
  {
    case alreadyConsumed
    case incompleteTerminalState
    case retirementUncertain
  }
  private struct InvestigationMachineGateCoordinatorPreArmFailureReportedError:
    Error, Sendable
  {
    let reason: InvestigationMachineGateCoordinatorPreArmFailureFrameV1.Reason
  }
  package struct InvestigationMachineGateCoordinatorPreArmFrameV1:
    Sendable, Equatable
  {
    package static let domain = "stornaut.task39.iic.coordinator-prearm.v1"
    package static let maximumByteCount = InvestigationProjectedCohortInput.maximumByteCount + 1_024
    package let repositoryHEAD, repositoryTree: String
    package let canonicalSourceManifestSHA256: InvestigationHandoffSHA256
    package let buildProvenanceSHA256, signedRuntimeBindingSHA256:
      InvestigationHandoffSHA256
    package let outerAttemptUUID: UUID
    package let wholeCapsuleSHA256: InvestigationHandoffSHA256
    package let wholeProjectedInputSHA256: InvestigationHandoffSHA256
    package let canonicalProjectedInput: Data
    package private(set) var frameSHA256: InvestigationHandoffSHA256

    package init(
      provenance: InvestigationMachineBuildProvenanceReceiptV1,
      binding: InvestigationMachineGateCoordinatorBinding,
      projectedInput: InvestigationProjectedCohortInput
    ) throws {
      repositoryHEAD = provenance.repositoryHEAD
      repositoryTree = provenance.repositoryTree
      canonicalSourceManifestSHA256 = try .init(
        lowercaseHex: provenance.canonicalManifestSHA256
      )
      buildProvenanceSHA256 = try .init(
        lowercaseHex: binding.buildProvenanceSHA256
      )
      signedRuntimeBindingSHA256 = try .init(
        lowercaseHex: binding.signedBindingSHA256
      )
      outerAttemptUUID = projectedInput.capsule.outerAttemptUUID
      wholeCapsuleSHA256 = projectedInput.capsule.wholeCapsuleSHA256
      wholeProjectedInputSHA256 = projectedInput.wholeInputSHA256
      canonicalProjectedInput = try projectedInput.encoded()
      frameSHA256 = Self.zeroDigest
      frameSHA256 = .hashing(try transcript(digest: Self.zeroDigest))
    }

    package func encoded() throws -> Data {
      guard .hashing(try transcript(digest: Self.zeroDigest)) == frameSHA256 else {
        throw InvestigationMachineGateCoordinatorProductionError.protocolFailure
      }
      return try transcript(digest: frameSHA256)
    }

    private func transcript(digest: InvestigationHandoffSHA256) throws -> Data {
      try HandoffBinaryTranscript.encode(
        domain: Self.domain, businessFields: [
          Data(repositoryHEAD.utf8), Data(repositoryTree.utf8),
          canonicalSourceManifestSHA256.rawBytes,
          buildProvenanceSHA256.rawBytes,
          signedRuntimeBindingSHA256.rawBytes,
          coordinatorUUIDData(outerAttemptUUID), wholeCapsuleSHA256.rawBytes,
          wholeProjectedInputSHA256.rawBytes, canonicalProjectedInput,
          digest.rawBytes,
        ], maximumByteCount: Self.maximumByteCount
      )
    }
    private static let zeroDigest = try! InvestigationHandoffSHA256(
      rawBytes: Data(repeating: 0, count: 32))
  }
  package struct InvestigationMachineGateCoordinatorPreArmFailureFrameV1:
    Sendable, Equatable
  {
    package enum Stage: UInt8, CaseIterable, Sendable {
      case materializeSource = 1, makeBinding, makeConfigurations
      case authorCohort, preArmPublication
    }
    package enum Reason: UInt8, CaseIterable, Sendable {
      case buildProvenanceRejected = 1, installedObservationInvalid
      case codexIdentityChanged, admissionDeadline, protocolRejected
      case containmentUncertain, appSigningUnavailable
      case helperSigningUnavailable, machineDriverSigningUnavailable
      case signedBundleMetadataUnavailable, installedObservationChanged
      case sourceStateInvalid, codexIdentityUnavailable, codexLayoutInvalid
      case codexExecutableOpenInvalid, codexExecutableMetadataInvalid
      case codexExecutableACLInvalid, codexExecutableXattrInvalid
      case runtimeReceiptInvalid
      case machineDriverBindingInvalid, installedBindingInvalid
      case bindingJoinInvalid, bindingEncodingInvalid
      package var expectedExitStatus: Int32 {
        self == .containmentUncertain ? 82 : 81
      }
    }
    package enum Checkpoint: Sendable, Equatable {
      case bootstrapStarted(nonce: InvestigationHandoffSHA256)
      case sourceVerified(
        nonce: InvestigationHandoffSHA256,
        sourceFingerprintSHA256: InvestigationHandoffSHA256
      )
      case runtimeBound(
        nonce: InvestigationHandoffSHA256,
        sourceFingerprintSHA256: InvestigationHandoffSHA256,
        buildProvenanceSHA256: InvestigationHandoffSHA256,
        signedRuntimeBindingSHA256: InvestigationHandoffSHA256
      )
    }
    package static let domain =
      "stornaut.task39.iic.coordinator-prearm-failure.v1"
    package static let maximumByteCount = 512
    package let stage: Stage
    package let checkpoint: Checkpoint
    package let reason: Reason
    package let frameSHA256: InvestigationHandoffSHA256
    package var exitStatus: Int32 { reason.expectedExitStatus }

    package init(
      stage: Stage, checkpoint: Checkpoint, reason: Reason
    ) throws {
      guard Self.admits(stage: stage, checkpoint: checkpoint, reason: reason)
      else { throw InvestigationMachineGateCoordinatorProductionError.protocolFailure }
      self.stage = stage; self.checkpoint = checkpoint; self.reason = reason
      frameSHA256 = .hashing(try Self.transcript(
        stage: stage, checkpoint: checkpoint, reason: reason,
        digest: Self.zeroDigest
      ))
    }

    package func encoded() throws -> Data {
      let zeroed = try Self.transcript(
        stage: stage, checkpoint: checkpoint, reason: reason,
        digest: Self.zeroDigest
      )
      guard .hashing(zeroed) == frameSHA256 else {
        throw InvestigationMachineGateCoordinatorProductionError.protocolFailure
      }
      return try Self.transcript(
        stage: stage, checkpoint: checkpoint, reason: reason,
        digest: frameSHA256
      )
    }

    private static func admits(
      stage: Stage, checkpoint: Checkpoint, reason: Reason
    ) -> Bool {
      let shape = switch checkpoint {
      case .bootstrapStarted(let nonce):
        stage == .materializeSource && nonce != zeroDigest
      case .sourceVerified(let nonce, let source):
        stage == .makeBinding && nonce != zeroDigest && source != zeroDigest
      case .runtimeBound(let nonce, let source, let build, let binding):
        [.makeConfigurations, .authorCohort, .preArmPublication].contains(stage)
          && [nonce, source, build, binding].allSatisfy { $0 != zeroDigest }
      }
      guard shape else { return false }
      switch reason {
      case .buildProvenanceRejected, .installedObservationInvalid,
           .appSigningUnavailable, .helperSigningUnavailable,
           .machineDriverSigningUnavailable,
           .signedBundleMetadataUnavailable,
           .installedObservationChanged, .sourceStateInvalid,
           .codexIdentityUnavailable, .codexLayoutInvalid,
           .codexExecutableOpenInvalid, .codexExecutableMetadataInvalid,
           .codexExecutableACLInvalid, .codexExecutableXattrInvalid,
           .runtimeReceiptInvalid,
           .machineDriverBindingInvalid, .installedBindingInvalid,
           .bindingJoinInvalid, .bindingEncodingInvalid:
        return stage == .makeBinding
      case .codexIdentityChanged:
        return stage == .makeBinding || stage == .makeConfigurations
      case .admissionDeadline:
        return stage == .preArmPublication
      case .protocolRejected, .containmentUncertain:
        return true
      }
    }

    private static func transcript(
      stage: Stage, checkpoint: Checkpoint, reason: Reason,
      digest: InvestigationHandoffSHA256
    ) throws -> Data {
      try HandoffBinaryTranscript.encode(
        domain: domain, businessFields: [
          Data([stage.rawValue]), try checkpointData(checkpoint),
          Data([reason.rawValue]), uint32Data(UInt32(reason.expectedExitStatus)),
          digest.rawBytes,
        ], maximumByteCount: maximumByteCount
      )
    }
    private static func checkpointData(_ value: Checkpoint) throws -> Data {
      switch value {
      case .bootstrapStarted(let nonce): return Data([1]) + nonce.rawBytes
      case .sourceVerified(let nonce, let source):
        return Data([2]) + nonce.rawBytes + source.rawBytes
      case .runtimeBound(let nonce, let source, let build, let binding):
        return Data([3]) + nonce.rawBytes + source.rawBytes + build.rawBytes
          + binding.rawBytes
      }
    }
    private static func uint32Data(_ value: UInt32) -> Data {
      Data([UInt8(value >> 24), UInt8(truncatingIfNeeded: value >> 16),
        UInt8(truncatingIfNeeded: value >> 8), UInt8(truncatingIfNeeded: value)])
    }
    private static let zeroDigest = try! InvestigationHandoffSHA256(
      rawBytes: Data(repeating: 0, count: 32))
  }
  package enum InvestigationMachineGateCoordinatorInvocation:
    Equatable, Sendable
  {
    case validated
  }
  package struct InvestigationMachineGateCoordinatorMaterializedSource:
    @unchecked Sendable
  {
    package let sourceFingerprintSHA256: String
    fileprivate let attempt: InvestigationMachineGateCoordinatorOwnedAttempt?
    package init(sourceFingerprintSHA256: String) {
      self.sourceFingerprintSHA256 = sourceFingerprintSHA256
      attempt = nil
    }
    fileprivate init(attempt: InvestigationMachineGateCoordinatorOwnedAttempt) {
      sourceFingerprintSHA256 = attempt.sourceFingerprint.hex
      self.attempt = attempt
    }
  }
  package struct InvestigationMachineGateCoordinatorBinding:
    @unchecked Sendable
  {
    package let buildProvenanceSHA256: String
    package let signedBindingSHA256: String
    package let sourceFingerprintSHA256: String
    let currentSourceBinding: InvestigationMachineCurrentSourceBinding?
    init(
      buildProvenanceSHA256: String,
      signedBindingSHA256: String,
      sourceFingerprintSHA256: String
    ) {
      self.buildProvenanceSHA256 = buildProvenanceSHA256
      self.signedBindingSHA256 = signedBindingSHA256
      self.sourceFingerprintSHA256 = sourceFingerprintSHA256
      currentSourceBinding = nil
    }
    init(currentSourceBinding: InvestigationMachineCurrentSourceBinding) throws {
      self.currentSourceBinding = currentSourceBinding
      buildProvenanceSHA256 = currentSourceBinding.buildProvenanceSHA256
      signedBindingSHA256 = try InvestigationHandoffSHA256.hashing(
        JSONEncoder.stornautCoordinator.encode(currentSourceBinding.binding)
      ).lowercaseHex
      sourceFingerprintSHA256 = currentSourceBinding.sourceFingerprint.hex
    }
  }
  package struct InvestigationMachineGateCoordinatorConfigurationBatch:
    @unchecked Sendable
  {
    package let sourceFingerprintSHA256: String
    package let configurationSHA256s: [String]
    package let configurationValidBefore: InvestigationHandoffUTCMicroseconds
    let source: InvestigationMachineCoordinatorConfigurationSet?
    package init(
      sourceFingerprintSHA256: String,
      configurationSHA256s: [String],
      configurationValidBefore: InvestigationHandoffUTCMicroseconds
    ) {
      self.sourceFingerprintSHA256 = sourceFingerprintSHA256
      self.configurationSHA256s = configurationSHA256s
      self.configurationValidBefore = configurationValidBefore
      source = nil
    }
    init(source: InvestigationMachineCoordinatorConfigurationSet) throws {
      guard
      let firstValidBefore = source.configurations.first?.validBefore,
        source.configurations.count == InvestigationCohortCapsule.epochCount,
        source.configurations.allSatisfy({
          $0.validBefore == firstValidBefore
            && $0.maximumWallClockSeconds
              == SignedInvestigationRuntimeDiagnosticConfiguration
                .maximumMachineEpochWallClockSeconds
        })
      else {
        throw InvestigationMachineGateCoordinatorProductionError.protocolFailure
      }
      self.source = source
      sourceFingerprintSHA256 = source.currentSourceBinding.sourceFingerprint.hex
      configurationSHA256s = try source.configurations.map {
        try $0.machineConfigurationSHA256()
      }
      configurationValidBefore = try InvestigationHandoffUTCMicroseconds(
        timeIntervalSince1970: firstValidBefore.timeIntervalSince1970
      )
    }
  }
  package struct InvestigationMachineGateCoordinatorAuthoredCohort:
    Equatable, Sendable
  {
    package let sourceFingerprintSHA256: String
    package let configurationSHA256s: [String]
    package let outerAttemptUUID: UUID
    package let wholeProjectedInputSHA256: String
    package let configurationValidBefore: InvestigationHandoffUTCMicroseconds
    let canonicalProjectedInput: Data?
    package init(
      sourceFingerprintSHA256: String,
      configurationSHA256s: [String],
      outerAttemptUUID: UUID,
      wholeProjectedInputSHA256: String,
      configurationValidBefore: InvestigationHandoffUTCMicroseconds
    ) {
      self.sourceFingerprintSHA256 = sourceFingerprintSHA256
      self.configurationSHA256s = configurationSHA256s
      self.outerAttemptUUID = outerAttemptUUID
      self.wholeProjectedInputSHA256 = wholeProjectedInputSHA256
      self.configurationValidBefore = configurationValidBefore
      canonicalProjectedInput = nil
    }
    init(
      sourceFingerprintSHA256: String, configurationSHA256s: [String],
      configurationValidBefore: InvestigationHandoffUTCMicroseconds,
      projectedInput: InvestigationProjectedCohortInput
    ) throws {
      self.sourceFingerprintSHA256 = sourceFingerprintSHA256
      self.configurationSHA256s = configurationSHA256s
      outerAttemptUUID = projectedInput.capsule.outerAttemptUUID
      wholeProjectedInputSHA256 = projectedInput.wholeInputSHA256.lowercaseHex
      guard
        projectedInput.capsule.epochs.map({ $0.configurationSHA256.lowercaseHex })
          == configurationSHA256s,
        projectedInput.projections.allSatisfy({
          $0.configurationValidBefore == configurationValidBefore
        })
      else {
        throw InvestigationMachineGateCoordinatorProductionError.protocolFailure
      }
      self.configurationValidBefore = configurationValidBefore
      canonicalProjectedInput = try projectedInput.encoded()
    }
  }
  package enum InvestigationMachineGateCoordinatorWaitClassification:
    Equatable, Sendable {
    case exited(status: Int32)
    case signaled(signal: Int32)
    case stopped(signal: Int32)
  }
  package struct InvestigationMachineGateCoordinatorHandoff:
    Equatable, Sendable
  {
    package let outerAttemptUUID: UUID
    package let wholeProjectedInputSHA256: String
    package let gateExecutableSHA256: String
    package let gateTransportReceiptSHA256: String
    package let gateProcessID: Int32
    package let gateProcessGroupID: Int32
    package let gateSessionID: Int32
    package let capsule: InvestigationMachineGateNodeObservation
    package let receiptReachedEOF: Bool
    package let receiptOverflowObserved: Bool
    package let receiptDeadlineExpired: Bool
    package let capsuleSettlementRemoved: Bool
    package let monotonicStartedNanoseconds: UInt64
    package let monotonicCompletedNanoseconds: UInt64
    package let waitClassification:
      InvestigationMachineGateCoordinatorWaitClassification
    package init(
      outerAttemptUUID: UUID,
      wholeProjectedInputSHA256: String,
      gateExecutableSHA256: String,
      gateTransportReceiptSHA256: String,
      gateProcessID: Int32,
      gateProcessGroupID: Int32,
      gateSessionID: Int32,
      capsule: InvestigationMachineGateNodeObservation,
      receiptReachedEOF: Bool,
      receiptOverflowObserved: Bool,
      receiptDeadlineExpired: Bool,
      capsuleSettlementRemoved: Bool,
      monotonicStartedNanoseconds: UInt64,
      monotonicCompletedNanoseconds: UInt64,
      waitClassification:
        InvestigationMachineGateCoordinatorWaitClassification
    ) {
      self.outerAttemptUUID = outerAttemptUUID
      self.wholeProjectedInputSHA256 = wholeProjectedInputSHA256
      self.gateExecutableSHA256 = gateExecutableSHA256
      self.gateTransportReceiptSHA256 = gateTransportReceiptSHA256
      self.gateProcessID = gateProcessID
      self.gateProcessGroupID = gateProcessGroupID
      self.gateSessionID = gateSessionID
      self.capsule = capsule
      self.receiptReachedEOF = receiptReachedEOF
      self.receiptOverflowObserved = receiptOverflowObserved
      self.receiptDeadlineExpired = receiptDeadlineExpired
      self.capsuleSettlementRemoved = capsuleSettlementRemoved
      self.monotonicStartedNanoseconds = monotonicStartedNanoseconds
      self.monotonicCompletedNanoseconds = monotonicCompletedNanoseconds
      self.waitClassification = waitClassification
    }
  }
  package struct InvestigationMachineGateCoordinatorRetirementOutcome:
    Equatable, Sendable {
    package static let retired = Self(
      attemptBaseRetired: true, runtimeArtifactsRetired: true
    )
    package static let uncertain = Self(
      attemptBaseRetired: false, runtimeArtifactsRetired: false
    )
    package let attemptBaseRetired: Bool
    package let runtimeArtifactsRetired: Bool
  }
  package struct InvestigationMachineGateCoordinatorTerminalState:
    Sendable
  {
    package let source:
      InvestigationMachineGateCoordinatorMaterializedSource?
    package let binding: InvestigationMachineGateCoordinatorBinding?
    package let configurations:
      InvestigationMachineGateCoordinatorConfigurationBatch?
    package let cohort: InvestigationMachineGateCoordinatorAuthoredCohort?
    package let handoff: InvestigationMachineGateCoordinatorHandoff?
    package let retirementOutcome:
      InvestigationMachineGateCoordinatorRetirementOutcome
    package let monotonicStartedNanoseconds: UInt64
    package let monotonicCompletedNanoseconds: UInt64
    init(
      source: InvestigationMachineGateCoordinatorMaterializedSource?,
      binding: InvestigationMachineGateCoordinatorBinding?,
      configurations: InvestigationMachineGateCoordinatorConfigurationBatch?,
      cohort: InvestigationMachineGateCoordinatorAuthoredCohort?,
      handoff: InvestigationMachineGateCoordinatorHandoff?,
      retirementOutcome:
        InvestigationMachineGateCoordinatorRetirementOutcome,
      monotonicStartedNanoseconds: UInt64, monotonicCompletedNanoseconds: UInt64
    ) {
      self.source = source
      self.binding = binding
      self.configurations = configurations
      self.cohort = cohort
      self.handoff = handoff
      self.retirementOutcome = retirementOutcome
      self.monotonicStartedNanoseconds = monotonicStartedNanoseconds
      self.monotonicCompletedNanoseconds = monotonicCompletedNanoseconds
    }
  }
  package enum InvestigationMachineGateCoordinatorSinkDisposition:
    Equatable, Sendable
  {
    case receipt(InvestigationMachineGateCoordinatorReceiptV1)
    case failure(InvestigationMachineGateCoordinatorPreArmFailureFrameV1)
    case closeOnly
  }
  extension InvestigationMachineGateCoordinatorReceiptV1 {
    package init(
      terminal state: InvestigationMachineGateCoordinatorTerminalState
    ) throws {
      guard
        let source = state.source,
        let binding = state.binding,
        let configurations = state.configurations,
        let cohort = state.cohort,
        let handoff = state.handoff,
        state.retirementOutcome == .retired,
        source.sourceFingerprintSHA256 == binding.sourceFingerprintSHA256,
        source.sourceFingerprintSHA256
          == configurations.sourceFingerprintSHA256,
        source.sourceFingerprintSHA256 == cohort.sourceFingerprintSHA256,
        configurations.configurationSHA256s == cohort.configurationSHA256s,
        configurations.configurationSHA256s.count == 8,
        Set(configurations.configurationSHA256s).count == 8,
        cohort.outerAttemptUUID == handoff.outerAttemptUUID,
        cohort.wholeProjectedInputSHA256
          == handoff.wholeProjectedInputSHA256,
        state.monotonicStartedNanoseconds < handoff.monotonicStartedNanoseconds,
        state.monotonicCompletedNanoseconds > handoff.monotonicCompletedNanoseconds
      else {
        throw InvestigationMachineGateCoordinatorCompositionError
          .incompleteTerminalState
      }
      let wait: InvestigationMachineGateWaitClassification = switch handoff
        .waitClassification
      {
      case .exited(let status): .exited(status: status)
      case .signaled(let signal): .signaled(signal: signal)
      case .stopped(let signal): .stopped(signal: signal)
      }
      try self.init(
        buildProvenanceSHA256: binding.buildProvenanceSHA256,
        signedBindingSHA256: .init(
          lowercaseHex: binding.signedBindingSHA256
        ),
        outerAttemptUUID: cohort.outerAttemptUUID,
        wholeProjectedInputSHA256: .init(
          lowercaseHex: cohort.wholeProjectedInputSHA256
        ),
        capsule: handoff.capsule,
        gateExecutableSHA256: .init(
          lowercaseHex: handoff.gateExecutableSHA256
        ),
        gateTransportReceiptSHA256: .init(
          lowercaseHex: handoff.gateTransportReceiptSHA256
        ),
        gateProcessID: handoff.gateProcessID,
        gateProcessGroupID: handoff.gateProcessGroupID,
        gateSessionID: handoff.gateSessionID,
        exactGateWaitClassification: wait,
        receiptReachedEOF: handoff.receiptReachedEOF,
        receiptOverflowObserved: handoff.receiptOverflowObserved,
        receiptDeadlineExpired: handoff.receiptDeadlineExpired,
        capsuleSettlementRemoved: handoff.capsuleSettlementRemoved,
        attemptBaseRetired: state.retirementOutcome.attemptBaseRetired,
        runtimeArtifactsRetired: state.retirementOutcome.runtimeArtifactsRetired,
        monotonicStartedNanoseconds: state.monotonicStartedNanoseconds,
        monotonicCompletedNanoseconds: state.monotonicCompletedNanoseconds
      )
    }
  }
  package struct InvestigationMachineGateCoordinatorDependencies: Sendable {
    typealias ValidateInvocation = @Sendable () async throws
      -> InvestigationMachineGateCoordinatorInvocation
    typealias MaterializeSource = @Sendable (
      InvestigationMachineGateCoordinatorInvocation
    ) async throws -> InvestigationMachineGateCoordinatorMaterializedSource
    typealias MakeBinding = @Sendable (
      InvestigationMachineGateCoordinatorMaterializedSource
    ) async throws -> InvestigationMachineGateCoordinatorBinding
    typealias MakeConfigurations = @Sendable (
      InvestigationMachineGateCoordinatorBinding,
      InvestigationMachineGateCoordinatorMaterializedSource
    ) async throws -> InvestigationMachineGateCoordinatorConfigurationBatch
    typealias AuthorCohort = @Sendable (
      InvestigationMachineGateCoordinatorConfigurationBatch
    ) async throws -> InvestigationMachineGateCoordinatorAuthoredCohort
    typealias Handoff = @Sendable (
      InvestigationMachineGateCoordinatorAuthoredCohort
    ) async throws -> InvestigationMachineGateCoordinatorHandoff
    typealias ActivateBeforeHandoff = @Sendable (
      InvestigationMachineGateCoordinatorBinding,
      InvestigationMachineGateCoordinatorAuthoredCohort
    ) async throws -> Void
    typealias RetireArtifacts = @Sendable (
      InvestigationMachineGateCoordinatorMaterializedSource?,
      InvestigationMachineGateCoordinatorHandoff?
    ) async throws -> InvestigationMachineGateCoordinatorRetirementOutcome
    typealias MakeReceipt = @Sendable (
      InvestigationMachineGateCoordinatorTerminalState
    ) async throws -> InvestigationMachineGateCoordinatorReceiptV1
    typealias WriteClose = @Sendable (
      InvestigationMachineGateCoordinatorSinkDisposition
    ) async throws -> Void
    typealias Monotonic = @Sendable () throws -> UInt64
    typealias WallNow = @Sendable () -> Date
    let validateInvocation: ValidateInvocation
    let materializeSource: MaterializeSource
    let makeBinding: MakeBinding
    let makeConfigurations: MakeConfigurations
    let authorCohort: AuthorCohort
    let activateBeforeHandoff: ActivateBeforeHandoff
    let handoff: Handoff
    let retireArtifacts: RetireArtifacts
    let makeReceipt: MakeReceipt
    let writeClose: WriteClose
    let monotonic: Monotonic
    let wallNow: WallNow
    let emitsPreArmFailure: Bool
    init(
      validateInvocation: @escaping ValidateInvocation,
      materializeSource: @escaping MaterializeSource,
      makeBinding: @escaping MakeBinding,
      makeConfigurations: @escaping MakeConfigurations,
      authorCohort: @escaping AuthorCohort,
      activateBeforeHandoff: @escaping ActivateBeforeHandoff = { _, _ in },
      handoff: @escaping Handoff,
      retireArtifacts: @escaping RetireArtifacts,
      makeReceipt: @escaping MakeReceipt,
      writeClose: @escaping WriteClose, monotonic: @escaping Monotonic,
      wallNow: @escaping WallNow = Date.init,
      emitsPreArmFailure: Bool = false
    ) {
      self.validateInvocation = validateInvocation
      self.materializeSource = materializeSource
      self.makeBinding = makeBinding
      self.makeConfigurations = makeConfigurations
      self.authorCohort = authorCohort
      self.activateBeforeHandoff = activateBeforeHandoff
      self.handoff = handoff
      self.retireArtifacts = retireArtifacts
      self.makeReceipt = makeReceipt
      self.writeClose = writeClose
      self.monotonic = monotonic
      self.wallNow = wallNow
      self.emitsPreArmFailure = emitsPreArmFailure
    }
  }
  package actor InvestigationMachineGateCoordinatorComposition {
    private enum State { case ready, consumed }
    private let dependencies: InvestigationMachineGateCoordinatorDependencies
    private var state = State.ready
    package init(
      dependencies: InvestigationMachineGateCoordinatorDependencies
    ) {
      self.dependencies = dependencies
    }
    package func run() async throws
      -> InvestigationMachineGateCoordinatorReceiptV1
    {
      guard state == .ready else {
        throw InvestigationMachineGateCoordinatorCompositionError
          .alreadyConsumed
      }
      state = .consumed
      var monotonicStartedNanoseconds: UInt64 = 0
      var source: InvestigationMachineGateCoordinatorMaterializedSource?
      var binding: InvestigationMachineGateCoordinatorBinding?
      var configurations:
        InvestigationMachineGateCoordinatorConfigurationBatch?
      var cohort: InvestigationMachineGateCoordinatorAuthoredCohort?
      var handoff: InvestigationMachineGateCoordinatorHandoff?
      var originalError: (any Error)?
      var handoffStarted = false
      var failureStage:
        InvestigationMachineGateCoordinatorPreArmFailureFrameV1.Stage?
      var failureCheckpoint:
        InvestigationMachineGateCoordinatorPreArmFailureFrameV1.Checkpoint?
      var failureEligible = false
      do {
        do { monotonicStartedNanoseconds = try dependencies.monotonic() }
        catch { throw InvestigationMachineGateCoordinatorProductionError.containmentUncertain }
        guard monotonicStartedNanoseconds > 0 else {
          throw InvestigationMachineGateCoordinatorProductionError
            .containmentUncertain
        }
        let invocation = try await dependencies.validateInvocation()
        let failureNonce = InvestigationHandoffSHA256.hashing(
          Data(UUID().uuidString.utf8)
        )
        failureStage = .materializeSource
        failureCheckpoint = .bootstrapStarted(nonce: failureNonce)
        failureEligible = dependencies.emitsPreArmFailure
        let materialized = try await dependencies.materializeSource(invocation)
        source = materialized
        if let fingerprint = try? InvestigationHandoffSHA256(
          lowercaseHex: materialized.sourceFingerprintSHA256
        ) {
          failureStage = .makeBinding
          failureCheckpoint = .sourceVerified(
            nonce: failureNonce, sourceFingerprintSHA256: fingerprint
          )
        }
        let currentBinding = try await dependencies.makeBinding(materialized)
        binding = currentBinding
        if let fingerprint = try? InvestigationHandoffSHA256(
          lowercaseHex: currentBinding.sourceFingerprintSHA256
        ), let build = try? InvestigationHandoffSHA256(
          lowercaseHex: currentBinding.buildProvenanceSHA256
        ), let signed = try? InvestigationHandoffSHA256(
          lowercaseHex: currentBinding.signedBindingSHA256
        ) {
          failureStage = .makeConfigurations
          failureCheckpoint = .runtimeBound(
            nonce: failureNonce, sourceFingerprintSHA256: fingerprint,
            buildProvenanceSHA256: build,
            signedRuntimeBindingSHA256: signed
          )
        }
        let batch = try await dependencies.makeConfigurations(
          currentBinding, materialized
        )
        configurations = batch
        failureStage = .authorCohort
        let authored = try await dependencies.authorCohort(batch)
        cohort = authored
        failureStage = .preArmPublication
        try InvestigationMachineGateCoordinatorHandoffAdmission.validate(
          authored, now: dependencies.wallNow()
        )
        failureEligible = false
        try await dependencies.activateBeforeHandoff(currentBinding, authored)
        try InvestigationMachineGateCoordinatorHandoffAdmission.validate(
          authored, now: dependencies.wallNow()
        )
        handoffStarted = true
        handoff = try await dependencies.handoff(authored)
      } catch {
        originalError = error
      }
      var retirementOutcome =
        InvestigationMachineGateCoordinatorRetirementOutcome.uncertain
      var retirementError: (any Error)?
      if retirementIsSafe(handoffStarted: handoffStarted, error: originalError) {
        do {
          retirementOutcome = try await dependencies.retireArtifacts(
            source, handoff
          )
        } catch {
          retirementError = error
        }
      }
      if retirementError == nil, retirementOutcome == .uncertain {
        retirementError =
          InvestigationMachineGateCoordinatorCompositionError
          .retirementUncertain
      }
      var monotonicCompletedNanoseconds: UInt64 = 0
      if originalError == nil, retirementError == nil {
        do { monotonicCompletedNanoseconds = try dependencies.monotonic() }
        catch { originalError = InvestigationMachineGateCoordinatorProductionError.containmentUncertain }
        if monotonicCompletedNanoseconds <= monotonicStartedNanoseconds
          || handoff.map({ monotonicStartedNanoseconds >= $0.monotonicStartedNanoseconds
            || monotonicCompletedNanoseconds <= $0.monotonicCompletedNanoseconds }) != false
        {
          originalError = InvestigationMachineGateCoordinatorProductionError
            .containmentUncertain
        }
      }
      let terminal = detachedTerminalState(
        source: source, binding: binding, configurations: configurations,
        cohort: cohort, handoff: handoff, retirementOutcome: retirementOutcome,
        monotonicStartedNanoseconds: monotonicStartedNanoseconds,
        monotonicCompletedNanoseconds: monotonicCompletedNanoseconds
      )
      source = nil; binding = nil; configurations = nil; cohort = nil
      var receipt: InvestigationMachineGateCoordinatorReceiptV1?
      var failureFrame:
        InvestigationMachineGateCoordinatorPreArmFailureFrameV1?
      var receiptError: (any Error)?
      if originalError == nil, retirementError == nil {
        do {
          receipt = try await dependencies.makeReceipt(terminal)
        } catch {
          receiptError = error
        }
      }
      if let originalError, retirementError == nil,
         retirementOutcome == .retired, failureEligible,
         let failureStage, let failureCheckpoint,
         !(originalError is CancellationError)
      {
        let reason = Self.preArmFailureReason(
          for: originalError, stage: failureStage
        )
        failureFrame = try? .init(
          stage: failureStage, checkpoint: failureCheckpoint, reason: reason
        )
      }
      var writeCloseError: (any Error)?
      do {
        if let receipt {
          try await dependencies.writeClose(.receipt(receipt))
        } else if let failureFrame {
          try await dependencies.writeClose(.failure(failureFrame))
        } else {
          try await dependencies.writeClose(.closeOnly)
        }
      } catch {
        writeCloseError = error
      }
      if let writeCloseError { throw writeCloseError }
      if let retirementError { throw retirementError }
      if let failureFrame {
        throw InvestigationMachineGateCoordinatorPreArmFailureReportedError(
          reason: failureFrame.reason
        )
      }
      if let originalError { throw originalError }
      if let receiptError { throw receiptError }
      guard let receipt else {
        throw InvestigationMachineGateCoordinatorCompositionError
          .incompleteTerminalState
      }
      return receipt
    }
    private static func preArmFailureReason(
      for error: any Error,
      stage: InvestigationMachineGateCoordinatorPreArmFailureFrameV1.Stage
    ) -> InvestigationMachineGateCoordinatorPreArmFailureFrameV1.Reason {
      if let value = error as? InvestigationMachineCoordinatorBindingSourceError {
        switch value {
        case .buildProvenanceUnavailable, .invalidBuildProvenance:
          return .buildProvenanceRejected
        case .appSigningUnavailable: return .appSigningUnavailable
        case .helperSigningUnavailable: return .helperSigningUnavailable
        case .machineDriverSigningUnavailable:
          return .machineDriverSigningUnavailable
        case .signedBundleMetadataUnavailable:
          return .signedBundleMetadataUnavailable
        case .installedObservationChanged:
          return .installedObservationChanged
        case .installedObservationInvalid:
          return .installedObservationInvalid
        case .invalidSourceFingerprint, .sourceStateInvalid:
          return .sourceStateInvalid
        case .codexIdentityUnavailable:
          return .codexIdentityUnavailable
        case .codexLayoutInvalid:
          return .codexLayoutInvalid
        case .codexExecutableOpenInvalid:
          return .codexExecutableOpenInvalid
        case .codexExecutableMetadataInvalid:
          return .codexExecutableMetadataInvalid
        case .codexExecutableACLInvalid:
          return .codexExecutableACLInvalid
        case .codexExecutableXattrInvalid:
          return .codexExecutableXattrInvalid
        case .invalidRuntimeReceipt:
          return .runtimeReceiptInvalid
        case .machineDriverBindingInvalid:
          return .machineDriverBindingInvalid
        case .installedBindingInvalid:
          return .installedBindingInvalid
        case .bindingJoinInvalid:
          return .bindingJoinInvalid
        case .bindingEncodingInvalid:
          return .bindingEncodingInvalid
        case .codexIdentityChanged: return .codexIdentityChanged
        }
      }
      if stage == .preArmPublication,
         error as? InvestigationMachineGateCoordinatorProductionError
          == .protocolFailure { return .admissionDeadline }
      if let value = error as? InvestigationMachineGateCoordinatorSystemError,
         value.kind == .containmentUncertain { return .containmentUncertain }
      if error as? InvestigationMachineGateCoordinatorProductionError
          == .containmentUncertain { return .containmentUncertain }
      if error as? InvestigationMachineGateCoordinatorProductionError
          == .protocolFailure { return .protocolRejected }
      if error is InvestigationMachineCoordinatorConfigurationSetError
          || error is InvestigationProjectedCohortAuthorError {
        return .protocolRejected
      }
      return .containmentUncertain
    }
    private func retirementIsSafe(
      handoffStarted: Bool, error: (any Error)?
    ) -> Bool {
      guard handoffStarted else { return true }
      guard let error else { return true }
      guard let error = error as? InvestigationFixedGateHandoffError else {
        return error as? InvestigationMachineGateCoordinatorProductionError
          == .postSettlementProtocolFailure
      }
      return error == .invalidCanonicalInput
        || error == .spawnFailedBeforeTransfer || error == .alreadyConsumed
    }
    private func detachedTerminalState(
      source: InvestigationMachineGateCoordinatorMaterializedSource?,
      binding: InvestigationMachineGateCoordinatorBinding?,
      configurations: InvestigationMachineGateCoordinatorConfigurationBatch?,
      cohort: InvestigationMachineGateCoordinatorAuthoredCohort?,
      handoff: InvestigationMachineGateCoordinatorHandoff?,
      retirementOutcome: InvestigationMachineGateCoordinatorRetirementOutcome,
      monotonicStartedNanoseconds: UInt64, monotonicCompletedNanoseconds: UInt64
    ) -> InvestigationMachineGateCoordinatorTerminalState {
      .init(
        source: source.map { .init(sourceFingerprintSHA256: $0.sourceFingerprintSHA256) },
        binding: binding.map { .init(
          buildProvenanceSHA256: $0.buildProvenanceSHA256,
          signedBindingSHA256: $0.signedBindingSHA256,
          sourceFingerprintSHA256: $0.sourceFingerprintSHA256
        ) },
        configurations: configurations.map { .init(
          sourceFingerprintSHA256: $0.sourceFingerprintSHA256,
          configurationSHA256s: $0.configurationSHA256s,
          configurationValidBefore: $0.configurationValidBefore
        ) },
        cohort: cohort.map { .init(
          sourceFingerprintSHA256: $0.sourceFingerprintSHA256,
          configurationSHA256s: $0.configurationSHA256s,
          outerAttemptUUID: $0.outerAttemptUUID,
          wholeProjectedInputSHA256: $0.wholeProjectedInputSHA256,
          configurationValidBefore: $0.configurationValidBefore
        ) }, handoff: handoff, retirementOutcome: retirementOutcome,
        monotonicStartedNanoseconds: monotonicStartedNanoseconds,
        monotonicCompletedNanoseconds: monotonicCompletedNanoseconds
      )
    }
  }
  package enum InvestigationMachineGateCoordinatorHandoffAdmission {
    package static let finalOutputReserveSeconds: TimeInterval = 5
    package static let minimumHandoffRemainingSeconds =
      TimeInterval(InvestigationCohortCapsule.epochCount
        * SignedInvestigationRuntimeDiagnosticConfiguration
          .maximumMachineEpochWallClockSeconds)
      + finalOutputReserveSeconds

    package static func validate(
      _ cohort: InvestigationMachineGateCoordinatorAuthoredCohort,
      now: Date
    ) throws {
      let nowSeconds = now.timeIntervalSince1970
      let scaledNow = nowSeconds * 1_000_000
      guard nowSeconds.isFinite, nowSeconds > 0, scaledNow.isFinite,
            scaledNow >= 1, scaledNow < Double(Int64.max)
      else {
        throw InvestigationMachineGateCoordinatorProductionError.protocolFailure
      }
      let observedMicroseconds = Int64(scaledNow.rounded(.up))
      let remaining = cohort.configurationValidBefore.rawValue
        .subtractingReportingOverflow(observedMicroseconds)
      let minimumMicroseconds = Int64(minimumHandoffRemainingSeconds * 1_000_000)
      let maximumMicroseconds = Int64(
        SignedInvestigationRuntimeDiagnosticConfiguration
          .maximumMachineCohortValiditySeconds * 1_000_000
      )
      guard !remaining.overflow, remaining.partialValue >= minimumMicroseconds,
            remaining.partialValue <= maximumMicroseconds
      else {
        throw InvestigationMachineGateCoordinatorProductionError.protocolFailure
      }
    }
  }
  private extension JSONEncoder {
    static var stornautCoordinator: JSONEncoder {
      let value = JSONEncoder()
      value.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
      return value
    }
  }
  package struct InvestigationMachineGateCoordinatorInvocationSnapshot:
    Equatable, Sendable
  {
    package let argumentCount: Int
    package let environmentEntries: [String]
    package let descriptors: [Int32]
    package let realUserID: uid_t
    package let effectiveUserID: uid_t
    package let realGroupID: gid_t
    package let effectiveGroupID: gid_t
    package let processID: pid_t
    package let processGroupID: pid_t
    package let sessionID: pid_t
    package let foregroundProcessGroupID: pid_t
    package let standardOutputWritable: Bool
    package let terminalWritableCharacterDevice: Bool
    package let receiptPipeWritable: Bool
  }
  package enum InvestigationMachineGateCoordinatorInvocationValidator {
    package static func validate(
      _ value: InvestigationMachineGateCoordinatorInvocationSnapshot
    ) throws {
      guard
        value.argumentCount == 1,
        normalizedEnvironment(value.environmentEntries),
        value.descriptors == [0, 1, 2, 3],
        value.realUserID == InvestigationMachineFixedGateContract.requiredUserID,
        value.effectiveUserID
          == InvestigationMachineFixedGateContract.requiredUserID,
        value.realGroupID == InvestigationMachineFixedGateContract.requiredGroupID,
        value.effectiveGroupID
          == InvestigationMachineFixedGateContract.requiredGroupID,
        value.processID > 1, value.processGroupID == value.processID,
        value.sessionID == value.processID,
        value.foregroundProcessGroupID == value.processID,
        value.standardOutputWritable,
        value.terminalWritableCharacterDevice,
        value.receiptPipeWritable
      else {
        throw InvestigationMachineGateCoordinatorProductionError
          .invalidInvocation
      }
    }
    static func validate() throws {
      let entries = environmentEntries()
      guard normalizedEnvironment(entries) else {
        throw InvestigationMachineGateCoordinatorProductionError
          .invalidInvocation
      }
      if !entries.isEmpty {
        guard unsetenv("__CF_USER_TEXT_ENCODING") == 0,
              environmentEntries().isEmpty else {
          throw InvestigationMachineGateCoordinatorProductionError
            .invalidInvocation
        }
      }
      try blockRequiredSignals()
      guard unsafeBitCast(
        Darwin.signal(SIGCHLD, SIG_DFL), to: UInt.self
      ) != unsafeBitCast(SIG_ERR, to: UInt.self) else {
        throw InvestigationMachineGateCoordinatorProductionError
          .invalidInvocation
      }
      try configureReceiptPipe()
      let snapshot = InvestigationMachineGateCoordinatorInvocationSnapshot(
        argumentCount: Int(CommandLine.argc),
        environmentEntries: [], descriptors: try descriptorInventory(),
        realUserID: getuid(), effectiveUserID: geteuid(),
        realGroupID: getgid(), effectiveGroupID: getegid(),
        processID: getpid(), processGroupID: getpgrp(),
        sessionID: getsid(0),
        foregroundProcessGroupID: tcgetpgrp(STDERR_FILENO),
        standardOutputWritable: try writable(STDOUT_FILENO),
        terminalWritableCharacterDevice: try terminalIsValid(),
        receiptPipeWritable: try receiptPipeIsValid()
      )
      try validate(snapshot)
    }
    private static func normalizedEnvironment(_ entries: [String]) -> Bool {
      guard entries.count <= 1 else { return false }
      guard let entry = entries.first else { return true }
      let fields = entry.split(
        separator: "=", maxSplits: 1, omittingEmptySubsequences: false
      )
      guard fields.count == 2, fields[0] == "__CF_USER_TEXT_ENCODING"
      else { return false }
      let parts = fields[1].split(
        separator: ":", omittingEmptySubsequences: false
      )
      return parts.count == 3 && parts.allSatisfy { part in
        part.count >= 3 && part.hasPrefix("0x")
          && part.dropFirst(2).allSatisfy(\.isHexDigit)
      }
    }
    private static func environmentEntries() -> [String] {
      guard let environment = investigationMachineCoordinatorEnvironmentPointer()
        .pointee else { return [] }
      var values: [String] = []
      var index = 0
      while let value = environment[index] {
        values.append(String(cString: value))
        index += 1
      }
      return values
    }
    private static func descriptorInventory() throws -> [Int32] {
      var values = [proc_fdinfo](repeating: proc_fdinfo(), count: 64)
      let byteCount = values.withUnsafeMutableBytes { buffer in
        proc_pidinfo(
          getpid(), PROC_PIDLISTFDS, 0, buffer.baseAddress,
          Int32(buffer.count)
        )
      }
      guard
        byteCount >= 0,
        Int(byteCount) < values.count * MemoryLayout<proc_fdinfo>.stride,
        Int(byteCount).isMultiple(of: MemoryLayout<proc_fdinfo>.stride)
      else {
        throw InvestigationMachineGateCoordinatorProductionError
          .invalidInvocation
      }
      let result = values
        .prefix(Int(byteCount) / MemoryLayout<proc_fdinfo>.stride)
        .map(\.proc_fd).sorted()
      guard Set(result).count == result.count else {
        throw InvestigationMachineGateCoordinatorProductionError
          .invalidInvocation
      }
      return result
    }
    private static func configureReceiptPipe() throws {
      let descriptorFlags = fcntl(3, F_GETFD)
      let statusFlags = fcntl(3, F_GETFL)
      guard descriptorFlags >= 0, statusFlags >= 0,
            fcntl(3, F_SETFD, descriptorFlags | FD_CLOEXEC) == 0,
            fcntl(3, F_SETFL, statusFlags | O_NONBLOCK) == 0,
            fcntl(3, F_SETNOSIGPIPE, 1) == 0 else {
        throw InvestigationMachineGateCoordinatorProductionError
          .invalidInvocation
      }
    }
    private static func blockRequiredSignals() throws {
      var set = sigset_t()
      guard sigemptyset(&set) == 0 else {
        throw InvestigationMachineGateCoordinatorProductionError
          .invalidInvocation
      }
      for signal in InvestigationMachineFixedGateContract.forwardedSignals
        + [SIGTTIN, SIGTTOU, SIGTSTP]
      where sigaddset(&set, signal) != 0 {
        throw InvestigationMachineGateCoordinatorProductionError
          .invalidInvocation
      }
      guard pthread_sigmask(SIG_BLOCK, &set, nil) == 0 else {
        throw InvestigationMachineGateCoordinatorProductionError
          .invalidInvocation
      }
    }
    private static func writable(_ descriptor: Int32) throws -> Bool {
      let flags = fcntl(descriptor, F_GETFL)
      guard flags >= 0 else {
        throw InvestigationMachineGateCoordinatorProductionError
          .invalidInvocation
      }
      let access = flags & O_ACCMODE
      return access == O_WRONLY || access == O_RDWR
    }
    private static func terminalIsValid() throws -> Bool {
      var value = stat()
      let isWritable = try writable(STDERR_FILENO)
      return fstat(STDERR_FILENO, &value) == 0
        && value.st_mode & S_IFMT == S_IFCHR
        && isatty(STDERR_FILENO) == 1
        && isWritable
    }
    private static func receiptPipeIsValid() throws -> Bool {
      var value = stat()
      let descriptorFlags = fcntl(3, F_GETFD)
      let statusFlags = fcntl(3, F_GETFL)
      let isWritable = try writable(3)
      return fstat(3, &value) == 0 && value.st_mode & S_IFMT == S_IFIFO
        && descriptorFlags >= 0
        && descriptorFlags & FD_CLOEXEC == FD_CLOEXEC
        && statusFlags >= 0 && statusFlags & O_NONBLOCK == O_NONBLOCK
        && isWritable && fcntl(3, F_GETNOSIGPIPE) == 1
    }
  }
  package enum InvestigationMachineGateCoordinatorReceiptWriteResult:
    Equatable, Sendable
  {
    case written(Int), interrupted, wouldBlock, failed
  }
  package enum InvestigationMachineGateCoordinatorReceiptWaitResult:
    Equatable, Sendable
  {
    case writable, interrupted, expiredOrFailed
  }
  package struct InvestigationMachineGateCoordinatorReceiptOutputSystem:
    Sendable
  {
    package let waitWritable: @Sendable (
      Int32, InvestigationHandoffUTCMicroseconds
    ) -> InvestigationMachineGateCoordinatorReceiptWaitResult
    package let write: @Sendable (
      Int32, Data, Int
    ) -> InvestigationMachineGateCoordinatorReceiptWriteResult
    package init(
      waitWritable: @escaping @Sendable (Int32, InvestigationHandoffUTCMicroseconds)
        -> InvestigationMachineGateCoordinatorReceiptWaitResult,
      write: @escaping @Sendable (Int32, Data, Int)
        -> InvestigationMachineGateCoordinatorReceiptWriteResult
    ) {
      self.waitWritable = waitWritable; self.write = write
    }
    package static let production = Self(
      waitWritable: { descriptor, deadline in
        var event = pollfd(fd: descriptor, events: Int16(POLLOUT), revents: 0)
        var now = timespec()
        guard clock_gettime(CLOCK_REALTIME, &now) == 0 else {
          return .expiredOrFailed
        }
        let current = Int64(now.tv_sec) * 1_000_000 + Int64(now.tv_nsec / 1_000)
        guard current < deadline.rawValue else { return .expiredOrFailed }
        let remaining = deadline.rawValue - current
        let result = poll(&event, 1, Int32(min(
          remaining / 1_000, Int64(Int32.max))))
        if result < 0, errno == EINTR { return .interrupted }
        guard result > 0, event.revents & Int16(POLLOUT) != 0,
              event.revents & Int16(POLLERR | POLLHUP | POLLNVAL) == 0,
              clock_gettime(CLOCK_REALTIME, &now) == 0 else {
          return .expiredOrFailed
        }
        let after = Int64(now.tv_sec) * 1_000_000 + Int64(now.tv_nsec / 1_000)
        return after < deadline.rawValue ? .writable : .expiredOrFailed
      },
      write: { descriptor, bytes, offset in
        let count = bytes.withUnsafeBytes {
          Darwin.write(descriptor, $0.baseAddress?.advanced(by: offset),
            $0.count - offset)
        }
        if count >= 0 { return .written(count) }
        if errno == EINTR { return .interrupted }
        if errno == EAGAIN || errno == EWOULDBLOCK { return .wouldBlock }
        return .failed
      })
  }
  package enum InvestigationMachineGateCoordinatorReceiptOutputWriter {
    package static func writeAll(
      _ bytes: Data, to descriptor: Int32,
      validBefore: InvestigationHandoffUTCMicroseconds,
      system: InvestigationMachineGateCoordinatorReceiptOutputSystem = .production
    ) throws {
      var offset = 0
      while offset < bytes.count {
        switch system.waitWritable(descriptor, validBefore) {
        case .interrupted: continue
        case .expiredOrFailed:
          throw InvestigationMachineGateCoordinatorProductionError
            .containmentUncertain
        case .writable: break
        }
        switch system.write(descriptor, bytes, offset) {
        case .interrupted, .wouldBlock: continue
        case .failed:
          throw InvestigationMachineGateCoordinatorProductionError
            .containmentUncertain
        case .written(let count):
          guard count > 0, count <= bytes.count - offset else {
            throw InvestigationMachineGateCoordinatorProductionError
              .containmentUncertain
          }
          offset += count
        }
      }
    }
  }
  final class InvestigationMachineGateCoordinatorReceiptSink:
    @unchecked Sendable
  {
    private let descriptor: Int32
    private let outputSystem: InvestigationMachineGateCoordinatorReceiptOutputSystem
    private let lock = NSLock()
    private var closed = false
    private var prepared = false
    private var normalPreArmWritten = false
    private var validBefore: InvestigationHandoffUTCMicroseconds?
    init(descriptor: Int32 = 3,
      validBefore: InvestigationHandoffUTCMicroseconds? = nil,
      outputSystem: InvestigationMachineGateCoordinatorReceiptOutputSystem =
        .production) {
      self.descriptor = descriptor; self.validBefore = validBefore
      self.outputSystem = outputSystem
    }
    func markPrepared() { lock.withLock { prepared = true } }
    func writePreArm(_ value: InvestigationMachineGateCoordinatorPreArmFrameV1,
      validBefore: InvestigationHandoffUTCMicroseconds)
      throws
    {
      try lock.withLock {
        guard !closed, !normalPreArmWritten, self.validBefore == nil else {
          throw InvestigationMachineGateCoordinatorProductionError.protocolFailure
        }
        normalPreArmWritten = true; self.validBefore = validBefore
      }
      try writeFrame(try value.encoded())
    }
    func writeRawGateReceipt(_ value: InvestigationMachineGateTransportReceipt)
      throws
    {
      let payload = try value.encoded()
      guard try InvestigationMachineGateTransportReceipt.decode(payload) == value
      else { throw InvestigationMachineGateCoordinatorProductionError.protocolFailure }
      try writeFrame(payload)
    }
    func writeAndClose(
      _ disposition: InvestigationMachineGateCoordinatorSinkDisposition
    ) throws {
      try lock.withLock {
        guard !closed else {
          throw InvestigationMachineGateCoordinatorProductionError
            .containmentUncertain
        }
        closed = true
        var failure: (any Error)?
        if case .failure(let frame) = disposition {
          do {
            guard !normalPreArmWritten else {
              throw InvestigationMachineGateCoordinatorProductionError
                .protocolFailure
            }
            validBefore = try InvestigationHandoffUTCMicroseconds(
              timeIntervalSince1970: Date().addingTimeInterval(5)
                .timeIntervalSince1970
            )
            try writeFrame(try frame.encoded())
          } catch { failure = error }
        } else if case .receipt(let receipt) = disposition {
          do {
            let payload: Data
            do { payload = try receipt.encoded() }
            catch {
              throw InvestigationMachineGateCoordinatorProductionError
                .protocolFailure
            }
            guard try InvestigationMachineGateCoordinatorReceiptV1.decode(
              payload
            ) == receipt else {
              throw InvestigationMachineGateCoordinatorProductionError
                .protocolFailure
            }
            try writeFrame(payload)
          } catch {
            failure = error
          }
        }
        let closeResult = Darwin.close(descriptor)
        if closeResult != 0, !(
          errno == EBADF && disposition == .closeOnly && !prepared
        ) {
          throw InvestigationMachineGateCoordinatorProductionError
            .containmentUncertain
        }
        if let failure { throw failure }
      }
    }
    private func writeFrame(_ payload: Data) throws {
      guard let count = UInt32(exactly: payload.count), payload.count <= 1 << 20
      else { throw InvestigationMachineGateCoordinatorProductionError.protocolFailure }
      var frame = Data([
        UInt8(count >> 24), UInt8(truncatingIfNeeded: count >> 16),
        UInt8(truncatingIfNeeded: count >> 8), UInt8(truncatingIfNeeded: count),
      ])
      frame.append(payload)
      guard let validBefore else {
        throw InvestigationMachineGateCoordinatorProductionError.protocolFailure
      }
      try InvestigationMachineGateCoordinatorReceiptOutputWriter.writeAll(
        frame, to: descriptor, validBefore: validBefore, system: outputSystem)
    }
  }
  private enum InvestigationMachineCoordinatorActivation {
    static func waitForDurableArm(
      preArm: InvestigationMachineGateCoordinatorPreArmFrameV1,
      sink: InvestigationMachineGateCoordinatorReceiptSink,
      validBefore: InvestigationHandoffUTCMicroseconds
    ) throws {
      var saved = termios()
      guard tcgetattr(STDIN_FILENO, &saved) == 0,
            tcgetpgrp(STDIN_FILENO) == getpid() else {
        throw InvestigationMachineGateCoordinatorProductionError
          .invalidInvocation
      }
      var guarded = saved
      guarded.c_lflag &= ~tcflag_t(ECHO | ECHONL)
      guard tcsetattr(STDIN_FILENO, TCSANOW, &guarded) == 0 else {
        throw InvestigationMachineGateCoordinatorProductionError
          .containmentUncertain
      }
      defer { _ = tcsetattr(STDIN_FILENO, TCSANOW, &saved) }
      try sink.writePreArm(preArm, validBefore: validBefore)
      let digest = preArm.frameSHA256.lowercaseHex
      try writeTerminal("STORNAUT-IICC-READY-v1 " + digest + "\n")
      let expected = Data(("STORNAUT-IICC-ARM-v1 " + digest + "\n").utf8)
      var received = Data()
      while received.count <= expected.count {
        var event = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
        let ready = poll(&event, 1, timeout(validBefore))
        guard ready > 0, event.revents & Int16(POLLERR | POLLNVAL) == 0 else {
          if ready < 0, errno == EINTR { continue }
          throw InvestigationMachineGateCoordinatorProductionError.protocolFailure
        }
        var byte: UInt8 = 0
        let count = Darwin.read(STDIN_FILENO, &byte, 1)
        if count < 0, errno == EINTR { continue }
        guard count == 1 else {
          throw InvestigationMachineGateCoordinatorProductionError
            .protocolFailure
        }
        received.append(byte)
        if byte == UInt8(ascii: "\n") { break }
      }
      guard received == expected else {
        throw InvestigationMachineGateCoordinatorProductionError
          .protocolFailure
      }
      guard tcsetattr(STDIN_FILENO, TCSANOW, &saved) == 0,
            tcgetpgrp(STDIN_FILENO) == getpid() else {
        throw InvestigationMachineGateCoordinatorProductionError
          .containmentUncertain
      }
    }
    private static func timeout(_ deadline: InvestigationHandoffUTCMicroseconds)
      -> Int32
    {
      var now = timespec(); guard clock_gettime(CLOCK_REALTIME, &now) == 0 else { return 0 }
      let current = Int64(now.tv_sec) * 1_000_000 + Int64(now.tv_nsec / 1_000)
      let remaining = max(0, deadline.rawValue - current)
      return Int32(min(remaining / 1_000, Int64(Int32.max)))
    }

    private static func writeTerminal(_ value: String) throws {
      try coordinatorWriteAll(Data(value.utf8), to: STDERR_FILENO)
    }
  }
  private func coordinatorWriteAll(_ bytes: Data, to descriptor: Int32) throws {
    var offset = 0
    while offset < bytes.count {
      let count = bytes.withUnsafeBytes {
        Darwin.write(descriptor, $0.baseAddress?.advanced(by: offset),
          $0.count - offset)
      }
      if count < 0, errno == EINTR { continue }
      guard count > 0 else {
        throw InvestigationMachineGateCoordinatorProductionError
          .containmentUncertain
      }
      offset += count
    }
  }
  private final class InvestigationMachineGateCoordinatorRuntimeState:
    @unchecked Sendable
  {
    let lock = NSLock()
    var materialized: InvestigationMachineGateCoordinatorOwnedAttempt?
    var projectedInput: InvestigationProjectedCohortInput?
  }
  private struct InvestigationMachineGateCoordinatorProductionContext:
    @unchecked Sendable
  {
    let state = InvestigationMachineGateCoordinatorRuntimeState()
    func dependencies(
      sink: InvestigationMachineGateCoordinatorReceiptSink
    ) -> InvestigationMachineGateCoordinatorDependencies {
      InvestigationMachineGateCoordinatorDependencies(
        validateInvocation: {
          try InvestigationMachineGateCoordinatorInvocationValidator.validate()
          sink.markPrepared()
          return .validated
        },
        materializeSource: { _ in
          let attempt = try await InvestigationMachineGateCoordinatorOwnedAttempt
            .materialize()
          self.state.lock.withLock { self.state.materialized = attempt }
          return InvestigationMachineGateCoordinatorMaterializedSource(
            attempt: attempt
          )
        },
        makeBinding: { source in
          guard let fingerprint = self.state.lock.withLock({
            self.state.materialized?.sourceFingerprint
          }), fingerprint.hex == source.sourceFingerprintSHA256 else {
            throw InvestigationMachineCoordinatorBindingSourceError
              .sourceStateInvalid
          }
          let value = try await InvestigationMachineCurrentSourceBindingSource()
            .make(sourceFingerprint: fingerprint)
          do {
            return try InvestigationMachineGateCoordinatorBinding(
              currentSourceBinding: value
            )
          } catch {
            throw InvestigationMachineCoordinatorBindingSourceError
              .bindingEncodingInvalid
          }
        },
        makeConfigurations: { binding, source in
          guard let attempt = source.attempt,
                let current = binding.currentSourceBinding,
                binding.sourceFingerprintSHA256
                  == source.sourceFingerprintSHA256,
                current.sourceFingerprint.hex == source.sourceFingerprintSHA256
          else {
            throw InvestigationMachineGateCoordinatorProductionError
              .protocolFailure
          }
          let set = try await attempt.makeConfigurationSet(
            currentSourceBinding: current
          )
          return try InvestigationMachineGateCoordinatorConfigurationBatch(
            source: set
          )
        },
        authorCohort: { batch in
          guard let set = batch.source else {
            throw InvestigationMachineGateCoordinatorProductionError
              .protocolFailure
          }
          let projected = try InvestigationProjectedCohortAuthor().author(
            configurationData: set.canonicalConfigurationData,
            installedBinding: set.currentSourceBinding.installedBinding
          )
          let value = try InvestigationMachineGateCoordinatorAuthoredCohort(
            sourceFingerprintSHA256: batch.sourceFingerprintSHA256,
            configurationSHA256s: batch.configurationSHA256s,
            configurationValidBefore: batch.configurationValidBefore,
            projectedInput: projected
          )
          self.state.lock.withLock { self.state.projectedInput = projected }
          return value
        },
        activateBeforeHandoff: { binding, cohort in
          guard let current = binding.currentSourceBinding,
                let projected = self.state.lock.withLock({
                  self.state.projectedInput
                }) else {
            throw InvestigationMachineGateCoordinatorProductionError
              .protocolFailure
          }
          let preArm = try InvestigationMachineGateCoordinatorPreArmFrameV1(
            provenance: current.buildProvenance,
            binding: binding, projectedInput: projected
          )
          guard preArm.outerAttemptUUID == cohort.outerAttemptUUID else {
            throw InvestigationMachineGateCoordinatorProductionError
              .protocolFailure
          }
          try InvestigationMachineCoordinatorActivation.waitForDurableArm(
            preArm: preArm, sink: sink,
            validBefore: cohort.configurationValidBefore
          )
        },
        handoff: { cohort in
          guard let bytes = cohort.canonicalProjectedInput else {
            throw InvestigationMachineGateCoordinatorProductionError
              .protocolFailure
          }
          let value = try InvestigationFixedGateHandoff().run(
            canonicalProjectedInput: bytes
          )
          let transport = value.gateTransportReceipt
          try sink.writeRawGateReceipt(transport)
          guard
            transport.output.byteCount
              == coordinatorExpectedProductionCompletionByteCount(),
            transport.output.sha256.rawBytes.contains(where: { $0 != 0 }),
            transport.output.reachedEOF, !transport.output.overflowObserved,
            !transport.output.deadlineExpired
          else {
            throw InvestigationMachineGateCoordinatorProductionError
              .postSettlementProtocolFailure
          }
          let wait: InvestigationMachineGateCoordinatorWaitClassification =
            switch value.exactGateWaitClassification {
            case .exited(let status): .exited(status: status)
            case .signaled(let signal): .signaled(signal: signal)
            case .stopped(let signal): .stopped(signal: signal)
            }
          return InvestigationMachineGateCoordinatorHandoff(
            outerAttemptUUID: value.outerAttemptUUID,
            wholeProjectedInputSHA256: value.wholeInputSHA256.lowercaseHex,
            gateExecutableSHA256: value.gateExecutableSHA256.lowercaseHex,
            gateTransportReceiptSHA256:
              value.gateTransportReceiptSHA256.lowercaseHex,
            gateProcessID: value.gateProcessID,
            gateProcessGroupID: value.gateProcessGroupID,
            gateSessionID: transport.sessionID, capsule: value.capsule,
            receiptReachedEOF: transport.output.reachedEOF,
            receiptOverflowObserved: transport.output.overflowObserved,
            receiptDeadlineExpired: transport.output.deadlineExpired,
            capsuleSettlementRemoved: value.settlement == .removed,
            monotonicStartedNanoseconds: transport.monotonicStartedNanoseconds,
            monotonicCompletedNanoseconds:
              transport.monotonicCompletedNanoseconds,
            waitClassification: wait
          )
        },
        retireArtifacts: { _, _ in
          guard let attempt = self.state.lock.withLock({ self.state.materialized })
          else { return .retired }
          try attempt.retire()
          self.state.lock.withLock {
            self.state.materialized = nil
            self.state.projectedInput = nil
          }
          return .retired
        },
        makeReceipt: { terminal in
          try InvestigationMachineGateCoordinatorReceiptV1(terminal: terminal)
        },
        writeClose: { disposition in
          try sink.writeAndClose(disposition)
        }, monotonic: InvestigationHandoffAppLeafAdapterSystem.system.continuousNanoseconds,
        emitsPreArmFailure: true
      )
    }
  }
  private extension InvestigationMachineGateCoordinatorDependencies {
    static func production(
      context: InvestigationMachineGateCoordinatorProductionContext,
      sink: InvestigationMachineGateCoordinatorReceiptSink
    ) -> Self {
      context.dependencies(sink: sink)
    }
  }
  package func coordinatorExpectedCompletionArtifact(
    _ input: InvestigationProjectedCohortInput
  ) throws -> Data {
    let domain = "stornaut.task39.machine.driver-completion"
    let fields = [
      coordinatorUUIDData(input.capsule.outerAttemptUUID),
      input.capsule.wholeCapsuleSHA256.rawBytes,
      input.wholeInputSHA256.rawBytes,
      coordinatorUInt32Data(UInt32(InvestigationCohortCapsule.epochCount)),
    ]
    let zeroed = try HandoffBinaryTranscript.encode(
      domain: domain,
      businessFields: fields + [Data(
        repeating: 0, count: InvestigationHandoffSHA256.byteCount
      )],
      maximumByteCount: 512
    )
    return try HandoffBinaryTranscript.encode(
      domain: domain,
      businessFields: fields + [
        InvestigationHandoffSHA256.hashing(zeroed).rawBytes,
      ],
      maximumByteCount: 512
    )
  }
  package func coordinatorExpectedProductionCompletionByteCount() -> Int {
    // L2 stdout is one bounded lineage frame followed by the fixed-width v3
    // completion. The Gate receipt still owns the digest and byte-count wire
    // fields; this constant only closes the coordinator's expected-size gate.
    return 4 + ResolvedRootDriverClaimV1.encodedByteCount + 180
  }
  private func coordinatorUUIDData(_ value: UUID) -> Data {
    var bytes = value.uuid
    return withUnsafeBytes(of: &bytes) { Data($0) }
  }
  private func coordinatorUInt32Data(_ value: UInt32) -> Data {
    Data([
      UInt8(truncatingIfNeeded: value >> 24),
      UInt8(truncatingIfNeeded: value >> 16),
      UInt8(truncatingIfNeeded: value >> 8),
      UInt8(truncatingIfNeeded: value),
    ])
  }
  private struct InvestigationMachineGateCoordinatorNodeIdentity:
    Equatable, Sendable
  {
    let device: UInt64
    let inode: UInt64
    let generation: UInt64
    let type: mode_t
    let ownerUserID: uid_t
    let ownerGroupID: gid_t
    let permissions: mode_t
    let linkCount: UInt64
    let flags: UInt32
    let size: Int64
    let modificationSeconds: Int64
    let modificationNanoseconds: Int64
  }
  final class InvestigationMachineGateCoordinatorOwnedAttempt:
    @unchecked Sendable
  {
    enum RootBootstrapStage: CaseIterable, Sendable { case open, chmod, validate }
    typealias RootBootstrapHook = @Sendable (
      RootBootstrapStage, Int32, String, URL
    ) throws -> Void
    private static let directoryFlags = Int32(
      O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW_ANY | O_RESOLVE_BENEATH
        | O_UNIQUE
    )
    private static let namedFlags = Int32(
      AT_SYMLINK_NOFOLLOW_ANY | AT_RESOLVE_BENEATH | AT_UNIQUE
    )
    private static let unlinkFlags = Int32(
      AT_NODELETEBUSY | AT_UNIQUE | AT_SYMLINK_NOFOLLOW_ANY | AT_RESOLVE_BENEATH
    )
    private static let allowedExtendedAttributes = Set([
      "com.apple.provenance", "com.apple.quarantine",
    ])
    private static let maximumTreeEntries = 2_048
    let rootURL: URL
    let planningAt: Date
    let sourceFingerprint: InvestigationFingerprint
    let canonicalPlan: InvestigationPlan
    private var store: EvidenceStore?
    private var parentDescriptor: Int32
    private var rootDescriptor: Int32
    private let rootName: String
    private let rootIdentity: InvestigationMachineGateCoordinatorNodeIdentity
    private let stateLock = NSLock()
    private var retired = false
    private init(
      rootURL: URL, planningAt: Date,
      sourceFingerprint: InvestigationFingerprint,
      canonicalPlan: InvestigationPlan, store: EvidenceStore,
      parentDescriptor: Int32, rootDescriptor: Int32, rootName: String,
      rootIdentity: InvestigationMachineGateCoordinatorNodeIdentity
    ) {
      self.rootURL = rootURL
      self.planningAt = planningAt
      self.sourceFingerprint = sourceFingerprint
      self.canonicalPlan = canonicalPlan
      self.store = store
      self.parentDescriptor = parentDescriptor
      self.rootDescriptor = rootDescriptor
      self.rootName = rootName
      self.rootIdentity = rootIdentity
    }
    deinit {
      if rootDescriptor >= 0 { _ = Darwin.close(rootDescriptor) }
      if parentDescriptor >= 0 { _ = Darwin.close(parentDescriptor) }
    }
    static func materialize(
      rootHook: @escaping RootBootstrapHook = { _, _, _, _ in }
    ) async throws -> Self {
      let planningAt = millisecondDate(Date())
      let parentURL = try trustedTemporaryDirectory()
      let parentDescriptor = Darwin.open(
        parentURL.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW_ANY
      )
      guard parentDescriptor >= 0 else { throw uncertain() }
      var rootDescriptor: Int32 = -1
      var rootName: String?
      var rootNodeIdentity: InvestigationMachineGateCoordinatorNodeIdentity?
      var rootAdmissionCompleted = false
      do {
        try validatePrivateDirectory(parentDescriptor, named: nil)
        let name = "attempt-" + UUID().uuidString.lowercased()
        guard mkdirat(parentDescriptor, name, 0o700) == 0 else {
          throw uncertain()
        }
        rootName = name
        let rootURL = parentURL.appending(path: name, directoryHint: .isDirectory)
        let createdRootIdentity = try namedIdentity(
          parent: parentDescriptor, name: name
        )
        guard createdRootIdentity.type == S_IFDIR,
              createdRootIdentity.ownerUserID == geteuid(),
              createdRootIdentity.ownerGroupID == getegid(),
              createdRootIdentity.linkCount > 0 else { throw uncertain() }
        rootNodeIdentity = createdRootIdentity
        try rootHook(.open, parentDescriptor, name, rootURL)
        rootDescriptor = openat(parentDescriptor, name, directoryFlags)
        guard rootDescriptor >= 0, sameDirectoryNode(
          try identity(rootDescriptor), createdRootIdentity
        ) else {
          throw uncertain()
        }
        try rootHook(.chmod, parentDescriptor, name, rootURL)
        guard fchmod(rootDescriptor, 0o700) == 0 else { throw uncertain() }
        try rootHook(.validate, parentDescriptor, name, rootURL)
        try validatePrivateDirectory(rootDescriptor, named: (parentDescriptor, name))
        let attemptRootIdentity = try identity(rootDescriptor)
        guard sameDirectoryNode(attemptRootIdentity, createdRootIdentity) else {
          throw uncertain()
        }
        rootNodeIdentity = attemptRootIdentity
        rootAdmissionCompleted = true
        let sourceRoot = try createDirectory(
          parent: rootDescriptor, name: "canonical-source", parentURL: rootURL
        )
        let (sourceIdentity, templateFile, candidateIdentity) = try withClosed(
          sourceRoot.descriptor
        ) {
          let candidate = try createDirectory(
            parent: sourceRoot.descriptor, name: "candidate",
            parentURL: sourceRoot.url
          )
          return try withClosed(candidate.descriptor) {
            let templateFile = try requireSingleTemplateFile()
            let candidateIdentity = try writeFile(
              parent: candidate.descriptor, name: "source-evidence.txt",
              bytes: templateFile.bytes
            )
            guard templateFile.relativePath == "candidate/source-evidence.txt",
                  SHA256.hash(data: templateFile.bytes).map({
                    String(format: "%02x", $0)
                  }).joined()
                    == "25520c1a895baac099972eb6c324651e479f0f4f12e6f093089044cf175df8e7",
                  candidateIdentity.size == Int64(templateFile.bytes.count),
                  candidateIdentity.allocatedBytes == Int64(
                    InvestigationMachineCoordinatorSourceFixtureTemplate
                      .expectedTargetAllocatedBytes.value
                  ) else { throw protocolFailure() }
            return (
              try fileIdentity(sourceRoot.descriptor), templateFile,
              candidateIdentity
            )
          }
        }
        let session = try ScanSession(
          id: InvestigationMachineCoordinatorSourceFixtureTemplate.scanSessionID,
          startedAt: planningAt.addingTimeInterval(-2),
          finishedAt: planningAt.addingTimeInterval(-1),
          terminalState: .completed,
          completedScopes: [ScanScope(
            id: InvestigationMachineCoordinatorSourceFixtureTemplate.primaryScopeID,
            rootPath: try PersistedPath(validating: sourceRoot.url.path),
            completedAt: planningAt.addingTimeInterval(-1)
          )], unfinishedScopes: []
        )
        let snapshots = [
          try snapshot(
            id: InvestigationMachineCoordinatorSourceFixtureTemplate.rootSnapshotID,
            relativePath: ".", identity: sourceIdentity, kind: .directory,
            planningAt: planningAt
          ),
          try snapshot(
            id: InvestigationMachineCoordinatorSourceFixtureTemplate
              .candidateSnapshotID,
            relativePath: templateFile.relativePath,
            identity: candidateIdentity, kind: .regularFile,
            planningAt: planningAt
          ),
        ]
        let classification = try Classification(
          id: InvestigationMachineCoordinatorSourceFixtureTemplate.classificationID,
          snapshotID: InvestigationMachineCoordinatorSourceFixtureTemplate
            .candidateSnapshotID,
          ruleID: InvestigationMachineCoordinatorSourceFixtureTemplate
            .classificationRuleID, producer: nil,
          category: InvestigationMachineCoordinatorSourceFixtureTemplate
            .classificationCategory,
          disposition: InvestigationMachineCoordinatorSourceFixtureTemplate
            .classificationDisposition,
          risk: InvestigationMachineCoordinatorSourceFixtureTemplate
            .classificationRisk,
          confidence: InvestigationMachineCoordinatorSourceFixtureTemplate
            .classificationConfidence,
          recovery: nil, requiredEvidenceKeys: [], missingEvidenceKeys: [],
          catalogVersion: InvestigationMachineCoordinatorSourceFixtureTemplate
            .catalogVersion, classifiedAt: planningAt.addingTimeInterval(-1)
        )
        let baseline = try VolumeBaseline(
          sessionID: session.id,
          scopeID: InvestigationMachineCoordinatorSourceFixtureTemplate
            .primaryScopeID,
          rootPath: try PersistedPath(validating: sourceRoot.url.path),
          rootIdentity: sourceIdentity, totalCapacity: ByteCount(8_192),
          availableCapacity: ByteCount(8_192),
          availableCapacityForImportantUsage: nil,
          availableCapacityForOpportunisticUsage: nil, volumeIsReadOnly: false,
          source: AccountingSource(
            kind: .volumeResourceValues,
            identifier: DomainToken(rawValue: "machine-coordinator.volume")!,
            sampledAt: planningAt.addingTimeInterval(-1)
          )
        )
        let ledger = try SpaceLedgerReconciler().reconcile(.init(
          startBaseline: baseline, endBaseline: baseline, snapshots: snapshots,
          classifications: [classification]
        ))
        let store = try EvidenceStore(configuration: .memory)
        try await store.saveScanSession(session)
        try await store.savePathSnapshots(snapshots)
        try await store.saveClassifications([classification])
        try await store.saveSpaceLedger(ledger)
        let stored = try await store.createInvestigation(.init(
          investigationID: InvestigationMachineCoordinatorSourceFixtureTemplate
            .templateInvestigationID,
          initialRunID: InvestigationRunID(
            rawValue: "investigation-run-machine-coordinator-template-v1"
          )!,
          scanSessionID: session.id,
          scanScopeID: InvestigationMachineCoordinatorSourceFixtureTemplate
            .primaryScopeID,
          budgetPreset: .focused, planningAt: planningAt,
          relevanceTokens: InvestigationMachineCoordinatorSourceFixtureTemplate
            .relevanceTokens
        ))
        guard InvestigationMachineCoordinatorSourceFixtureTemplate.validates(
          stored.plan, sourceFingerprint: stored.plan.sourceFingerprint,
          now: planningAt
        ) else {
          throw InvestigationMachineGateCoordinatorSystemError(
            kind: .protocolFailure,
            operation: "template-plan-" + String(describing: stored.plan)
          )
        }
        return Self(
          rootURL: rootURL, planningAt: planningAt,
          sourceFingerprint: stored.plan.sourceFingerprint,
          canonicalPlan: stored.plan, store: store,
          parentDescriptor: parentDescriptor, rootDescriptor: rootDescriptor,
          rootName: name, rootIdentity: attemptRootIdentity
        )
      } catch {
        let original = error
        var cleanupCertain = true
        var cleanupStage = "pre-root"
        if rootDescriptor < 0, let rootName, rootNodeIdentity != nil {
          rootDescriptor = openat(parentDescriptor, rootName, directoryFlags)
        }
        if rootDescriptor >= 0, let rootName, let rootNodeIdentity {
          do {
            let admittedHeld = try identity(rootDescriptor)
            guard sameDirectoryNode(admittedHeld, rootNodeIdentity),
                  try namedIdentity(parent: parentDescriptor, name: rootName)
                    == admittedHeld else { throw uncertain() }
            cleanupStage = "remove-contents"
            var count = 0
            try removeContents(
              descriptor: rootDescriptor, depth: 0, count: &count
            )
            cleanupStage = "verify-root"
            let finalHeld = try identity(rootDescriptor)
            let finalNamed = try namedIdentity(
              parent: parentDescriptor, name: rootName
            )
            let securityIsValid = try !rootAdmissionCompleted
              || privateDirectorySecurity(rootDescriptor)
            guard fsync(rootDescriptor) == 0,
                  (rootAdmissionCompleted
                    ? sameDirectory(finalHeld, rootNodeIdentity)
                    : sameDirectoryNode(finalHeld, rootNodeIdentity)),
                  finalNamed == finalHeld,
                  securityIsValid
            else { throw uncertain() }
            let closingRoot = rootDescriptor; rootDescriptor = -1
            guard Darwin.close(closingRoot) == 0 else { throw uncertain() }
            cleanupStage = "remove-root"
            guard unlinkat(
              parentDescriptor, rootName, unlinkFlags | AT_REMOVEDIR
            ) == 0, fsync(parentDescriptor) == 0 else { throw uncertain() }
          } catch {
            cleanupStage += "-" + String(describing: error)
            cleanupCertain = false
          }
        } else if rootName != nil {
          cleanupCertain = false
        }
        if rootDescriptor >= 0, Darwin.close(rootDescriptor) != 0 {
          cleanupCertain = false
        }
        if Darwin.close(parentDescriptor) != 0 { cleanupCertain = false }
        guard cleanupCertain else { throw uncertain("cleanup-" + cleanupStage) }
        throw original
      }
    }
    func makeConfigurationSet(
      currentSourceBinding: InvestigationMachineCurrentSourceBinding
    ) async throws -> InvestigationMachineCoordinatorConfigurationSet {
      guard let store else { throw Self.uncertain() }
      let identifiers = Self.identifiers()
      try materializeEpochRoots(identifiers)
      let value = try InvestigationMachineCoordinatorConfigurationSetSource(
        identifiers: { identifiers }
      ).make(
        currentSourceBinding: currentSourceBinding,
        canonicalPlan: canonicalPlan, attemptRoot: rootURL, now: planningAt
      )
      var stored: [InvestigationStoredSession] = []
      for row in value.rows {
        stored.append(try await store.createInvestigation(.init(
          investigationID: row.investigationID, initialRunID: row.runID,
          scanSessionID: canonicalPlan.scanSessionID,
          scanScopeID: canonicalPlan.scanScopeID, budgetPreset: .focused,
          planningAt: planningAt,
          relevanceTokens: InvestigationMachineCoordinatorSourceFixtureTemplate
            .relevanceTokens
        )))
      }
      guard stored.map(\.plan) == value.rows.map(\.plan),
            Set(stored.map { $0.plan.sourceFingerprint }).count == 1,
            stored.allSatisfy({
              $0.plan.sourceFingerprint == sourceFingerprint
                && $0.plan.targetSetFingerprint
                  == canonicalPlan.targetSetFingerprint
            }) else { throw Self.protocolFailure() }
      // The App-side strict handoff decoder requires report/store outputs to be
      // vacant when it accepts the configuration. Retain the one canonical
      // in-memory Store here as the source/Planner authority; each App epoch
      // creates its exact configured Store only after admission.
      return value
    }
    func retire() throws {
      try stateLock.withLock {
        guard !retired, rootDescriptor >= 0 else { throw Self.uncertain() }
        retired = true
        store = nil
        let descriptor = rootDescriptor
        do {
          var count = 0
          try Self.removeContents(
            descriptor: descriptor, depth: 0, count: &count
          )
          guard fsync(descriptor) == 0 else { throw Self.uncertain() }
          let finalHeld = try Self.identity(descriptor)
          let finalNamed = try Self.namedIdentity(
            parent: parentDescriptor, name: rootName
          )
          guard Self.sameDirectory(finalHeld, rootIdentity),
                finalNamed == finalHeld,
                try Self.privateDirectorySecurity(descriptor) else {
            throw Self.uncertain()
          }
          rootDescriptor = -1
          guard Darwin.close(descriptor) == 0 else { throw Self.uncertain() }
          guard unlinkat(
            parentDescriptor, rootName,
            Self.unlinkFlags | AT_REMOVEDIR
          ) == 0, fsync(parentDescriptor) == 0 else { throw Self.uncertain() }
          var absent = stat()
          guard fstatat(
            parentDescriptor, rootName, &absent, Self.namedFlags
          ) != 0, errno == ENOENT else { throw Self.uncertain() }
          let closingParent = parentDescriptor; parentDescriptor = -1
          guard Darwin.close(closingParent) == 0 else { throw Self.uncertain() }
        } catch {
          if rootDescriptor >= 0 {
            _ = Darwin.close(rootDescriptor)
            rootDescriptor = -1
          }
          throw error
        }
      }
    }
    private func materializeEpochRoots(
      _ identifiers: InvestigationMachineCoordinatorGeneratedIdentifiers
    ) throws {
      for index in identifiers.configurationNonces.indices {
        let name = String(
          format: "epoch-%02d-%@", index,
          identifiers.configurationNonces[index].uuidString.lowercased()
        )
        let epoch = try Self.createDirectory(
          parent: rootDescriptor, name: name, parentURL: rootURL
        )
        try Self.withClosed(epoch.descriptor) {
          let source = try Self.createDirectory(
            parent: epoch.descriptor, name: "source", parentURL: epoch.url
          )
          try Self.withClosed(source.descriptor) {
            let candidate = try Self.createDirectory(
              parent: source.descriptor, name: "candidate", parentURL: source.url
            )
            try Self.withClosed(candidate.descriptor) {
              let file = try Self.requireSingleTemplateFile()
              let copied = try Self.writeFile(
                parent: candidate.descriptor, name: "source-evidence.txt", bytes: file.bytes
              )
              guard copied.size == Int64(file.bytes.count), copied.allocatedBytes
                == Int64(InvestigationMachineCoordinatorSourceFixtureTemplate.expectedTargetAllocatedBytes.value)
              else { throw Self.protocolFailure() }
            }
          }
          let support = try Self.createDirectory(
            parent: epoch.descriptor, name: "support", parentURL: epoch.url
          )
          try Self.withClosed(support.descriptor) {
            let store = try Self.createDirectory(
              parent: support.descriptor, name: "com.eriklee.stornaut", parentURL: support.url
            )
            try Self.withClosed(store.descriptor) {}
          }
          let runtime = try Self.createDirectory(
            parent: epoch.descriptor, name: "runtime", parentURL: epoch.url
          )
          try Self.withClosed(runtime.descriptor) {}
        }
      }
    }
    static func withClosed<T>(
      _ descriptor: Int32, close: (Int32) -> Int32 = Darwin.close,
      _ body: () throws -> T
    ) throws -> T {
      let result: Result<T, Error>
      do { result = .success(try body()) }
      catch { result = .failure(error) }
      guard close(descriptor) == 0 else { throw uncertain() }
      return try result.get()
    }
    private static func removeContents(
      descriptor: Int32, depth: Int, count: inout Int
    ) throws {
      guard depth <= 16, count <= maximumTreeEntries else {
        throw Self.uncertain()
      }
      let names = try Self.inventory(descriptor)
      guard count + names.count <= maximumTreeEntries else {
        throw Self.uncertain()
      }
      count += names.count
      for name in names {
        let before = try Self.namedIdentity(parent: descriptor, name: name)
        if before.type == S_IFDIR {
          let child = openat(descriptor, name, Self.directoryFlags)
          guard child >= 0, try Self.identity(child) == before else {
            if child >= 0 { _ = Darwin.close(child) }
            throw Self.uncertain()
          }
          let finalHeld = try withClosed(child) {
            try removeContents(descriptor: child, depth: depth + 1, count: &count)
            guard fsync(child) == 0 else { throw Self.uncertain() }
            let held = try Self.identity(child)
            guard Self.sameDirectory(held, before),
                  try Self.privateDirectorySecurity(child) else {
              throw Self.uncertain()
            }
            return held
          }
          guard try Self.namedIdentity(parent: descriptor, name: name) == finalHeld,
                unlinkat(
                  descriptor, name, Self.unlinkFlags | AT_REMOVEDIR
                ) == 0 else { throw Self.uncertain() }
        } else if before.type == S_IFREG {
          let child = openat(
            descriptor, name,
            O_RDONLY | O_CLOEXEC | O_NONBLOCK | O_NOFOLLOW_ANY
              | O_RESOLVE_BENEATH | O_UNIQUE
          )
          guard child >= 0 else { throw Self.uncertain() }
          let finalHeld = try withClosed(child) {
            let held = try Self.identity(child)
            guard held == before, try Self.privateRegularFileSecurity(child)
            else { throw Self.uncertain() }
            return held
          }
          guard try Self.namedIdentity(parent: descriptor, name: name) == finalHeld,
                unlinkat(descriptor, name, Self.unlinkFlags) == 0 else {
            throw Self.uncertain()
          }
        } else {
          throw Self.uncertain()
        }
      }
    }
    private static func identifiers()
      -> InvestigationMachineCoordinatorGeneratedIdentifiers {
      let nonces = (0..<8).map { _ in UUID() }
      return .init(
        configurationNonces: nonces,
        investigationIDs: nonces.map {
          InvestigationID(
            rawValue: "investigation-" + $0.uuidString.lowercased()
          )!
        },
        runIDs: nonces.map {
          InvestigationRunID(
            rawValue: "investigation-run-" + $0.uuidString.lowercased()
          )!
        }
      )
    }
    private static func snapshot(
      id: SnapshotID, relativePath: String, identity: FileIdentity,
      kind: PathKind, planningAt: Date
    ) throws -> PathSnapshot {
      try PathSnapshot(
        id: id,
        sessionID: InvestigationMachineCoordinatorSourceFixtureTemplate
          .scanSessionID,
        scopeID: InvestigationMachineCoordinatorSourceFixtureTemplate
          .primaryScopeID,
        relativePath: relativePath, kind: kind,
        logicalByteCount: ByteCount(exactly: identity.size),
        allocatedByteCount: ByteCount(exactly: identity.allocatedBytes),
        modifiedAt: Date(
          timeIntervalSince1970: TimeInterval(identity.modificationSeconds)
            + TimeInterval(identity.modificationNanoseconds) / 1_000_000_000
        ),
        fileIdentity: identity, symlinkTarget: nil,
        measurementStatus: .measured, observedAt: planningAt
      )
    }
    private static func requireSingleTemplateFile() throws
      -> InvestigationMachineCoordinatorSourceFixtureTemplate.File {
      guard InvestigationMachineCoordinatorSourceFixtureTemplate.files.count == 1,
            let file = InvestigationMachineCoordinatorSourceFixtureTemplate
              .files.first else { throw protocolFailure() }
      return file
    }
    private static func trustedTemporaryDirectory() throws -> URL {
      let count = confstr(_CS_DARWIN_USER_TEMP_DIR, nil, 0)
      guard count > 1 else { throw uncertain() }
      var buffer = [CChar](repeating: 0, count: count)
      guard confstr(_CS_DARWIN_USER_TEMP_DIR, &buffer, count) == count else {
        throw uncertain()
      }
      guard let end = buffer.firstIndex(of: 0) else { throw uncertain() }
      let source = URL(
        filePath: String(decoding: buffer[..<end].map(UInt8.init(bitPattern:)),
          as: UTF8.self),
        directoryHint: .isDirectory
      ).standardizedFileURL
      guard let resolved = realpath(source.path, nil) else { throw uncertain() }
      defer { free(resolved) }
      return URL(
        filePath: String(cString: resolved), directoryHint: .isDirectory
      )
    }
    private static func createDirectory(
      parent: Int32, name: String, parentURL: URL
    ) throws -> (descriptor: Int32, url: URL) {
      guard safeName(name), mkdirat(parent, name, 0o700) == 0 else {
        throw uncertain()
      }
      let descriptor = openat(parent, name, directoryFlags)
      guard descriptor >= 0, fchmod(descriptor, 0o700) == 0 else {
        if descriptor >= 0 { _ = Darwin.close(descriptor) }
        throw uncertain()
      }
      do { try validatePrivateDirectory(descriptor, named: (parent, name)) }
      catch { _ = Darwin.close(descriptor); throw error }
      return (descriptor, parentURL.appending(path: name, directoryHint: .isDirectory))
    }
    private static func writeFile(
      parent: Int32, name: String, bytes: Data
    ) throws -> FileIdentity {
      guard safeName(name) else { throw uncertain() }
      let descriptor = openat(
        parent, name, O_RDWR | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW_ANY
          | O_RESOLVE_BENEATH | O_UNIQUE, 0o600
      )
      guard descriptor >= 0 else { throw uncertain() }
      return try withClosed(descriptor) {
        guard fchmod(descriptor, 0o600) == 0 else { throw uncertain() }
        var offset = 0
        while offset < bytes.count {
          let written = bytes.withUnsafeBytes { raw in
            pwrite(
              descriptor, raw.baseAddress?.advanced(by: offset),
              bytes.count - offset, off_t(offset)
            )
          }
          if written < 0, errno == EINTR { continue }
          guard written > 0 else { throw uncertain() }
          offset += written
        }
        guard fsync(descriptor) == 0 else { throw uncertain() }
        var verified = Data()
        var readOffset = 0
        while readOffset < bytes.count {
          var buffer = [UInt8](
            repeating: 0, count: min(4_096, bytes.count - readOffset)
          )
          let amount = pread(
            descriptor, &buffer, buffer.count, off_t(readOffset)
          )
          if amount < 0, errno == EINTR { continue }
          guard amount > 0 else { throw uncertain() }
          verified.append(contentsOf: buffer.prefix(amount))
          readOffset += amount
        }
        var trailing: UInt8 = 0
        guard pread(descriptor, &trailing, 1, off_t(bytes.count)) == 0,
              verified == bytes else { throw uncertain() }
        let held = try identity(descriptor)
        let named = try namedIdentity(parent: parent, name: name)
        guard held == named, held.type == S_IFREG, held.permissions == 0o600,
              held.ownerUserID == geteuid(), held.ownerGroupID == getegid(),
              held.linkCount == 1, held.flags == 0,
              try extendedACLIsEmpty(descriptor),
              try extendedAttributeNames(descriptor).allSatisfy(
                allowedExtendedAttributes.contains
              ) else { throw uncertain() }
        let result = try fileIdentity(descriptor)
        return result
      }
    }
    static func inventory(
      _ descriptor: Int32, maximumEntries: Int = maximumTreeEntries,
      closeDirectory: (UnsafeMutablePointer<DIR>?) -> Int32 = closedir
    ) throws -> [String] {
      let duplicate = dup(descriptor)
      guard duplicate >= 0, fcntl(duplicate, F_SETFD, FD_CLOEXEC) == 0,
            let directory = fdopendir(duplicate) else {
        if duplicate >= 0 { _ = Darwin.close(duplicate) }
        throw uncertain()
      }
      let outcome: Result<[String], Error>
      do {
        var names: [String] = []
        errno = 0
        while let entry = readdir(directory) {
          let name = withUnsafePointer(to: entry.pointee.d_name) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) {
              String(cString: $0)
            }
          }
          if name == "." || name == ".." { continue }
          guard safeName(name), names.count < maximumEntries else {
            throw uncertain()
          }
          names.append(name); errno = 0
        }
        guard errno == 0 else { throw uncertain() }
        outcome = .success(names.sorted())
      } catch { outcome = .failure(error) }
      guard closeDirectory(directory) == 0 else { throw uncertain() }
      return try outcome.get()
    }
    private static func validatePrivateDirectory(
      _ descriptor: Int32, named: (Int32, String)?
    ) throws {
      let held = try identity(descriptor)
      guard held.type == S_IFDIR, held.ownerUserID == geteuid(),
            held.ownerGroupID == getegid(), held.permissions == 0o700,
            held.linkCount > 0, try extendedACLIsEmpty(descriptor)
      else { throw uncertain() }
      if let named {
        guard held.flags == 0, try privateDirectorySecurity(descriptor),
              try namedIdentity(parent: named.0, name: named.1) == held else {
          throw uncertain()
        }
      } else {
        // Darwin's per-user temporary root is OS-owned in lifecycle terms and
        // legitimately carries the rootless extended attribute and sunlnk flag.
        // The coordinator never removes or mutates that parent; it only requires
        // a held, current-user 0700 directory returned by confstr(3).
        let attributes = try extendedAttributeNames(descriptor)
        guard attributes.allSatisfy({ $0 == "com.apple.rootless" }) else {
          throw uncertain()
        }
      }
    }
    private static func identity(
      _ descriptor: Int32
    ) throws -> InvestigationMachineGateCoordinatorNodeIdentity {
      var value = stat()
      guard fstat(descriptor, &value) == 0 else { throw uncertain() }
      return nodeIdentity(value)
    }
    private static func sameDirectory(
      _ lhs: InvestigationMachineGateCoordinatorNodeIdentity,
      _ rhs: InvestigationMachineGateCoordinatorNodeIdentity
    ) -> Bool {
      sameDirectoryNode(lhs, rhs)
        && rhs.type == S_IFDIR && lhs.ownerUserID == rhs.ownerUserID
        && lhs.ownerGroupID == rhs.ownerGroupID
        && lhs.permissions == rhs.permissions && lhs.flags == rhs.flags
    }
    private static func sameDirectoryNode(
      _ lhs: InvestigationMachineGateCoordinatorNodeIdentity,
      _ rhs: InvestigationMachineGateCoordinatorNodeIdentity
    ) -> Bool {
      lhs.device == rhs.device && lhs.inode == rhs.inode
        && lhs.generation == rhs.generation && lhs.type == S_IFDIR
        && rhs.type == S_IFDIR
    }
    private static func privateDirectorySecurity(_ descriptor: Int32) throws
      -> Bool {
      try extendedACLIsEmpty(descriptor)
        && extendedAttributeNames(descriptor).allSatisfy(
          allowedExtendedAttributes.contains
        )
    }
    private static func privateRegularFileSecurity(_ descriptor: Int32) throws
      -> Bool {
      let value = try identity(descriptor)
      let aclIsEmpty = try extendedACLIsEmpty(descriptor)
      let attributesAreAllowed = try extendedAttributeNames(descriptor)
        .allSatisfy(allowedExtendedAttributes.contains)
      return value.type == S_IFREG && value.ownerUserID == geteuid()
        && value.ownerGroupID == getegid() && value.permissions == 0o600
        && value.linkCount == 1 && value.flags == 0
        && aclIsEmpty && attributesAreAllowed
    }
    private static func fileIdentity(_ descriptor: Int32) throws
      -> FileIdentity {
      var value = stat()
      guard fstat(descriptor, &value) == 0 else { throw uncertain() }
      let allocated = Int64(value.st_blocks).multipliedReportingOverflow(by: 512)
      guard !allocated.overflow else { throw uncertain() }
      return try FileIdentity(
        device: UInt64(bitPattern: Int64(value.st_dev)), inode: UInt64(value.st_ino),
        mode: UInt16(value.st_mode), ownerUserID: value.st_uid,
        ownerGroupID: value.st_gid, linkCount: UInt64(value.st_nlink),
        size: value.st_size,
        allocatedBytes: allocated.partialValue,
        modificationSeconds: Int64(value.st_mtimespec.tv_sec),
        modificationNanoseconds: Int64(value.st_mtimespec.tv_nsec)
      )
    }
    private static func namedIdentity(
      parent: Int32, name: String
    ) throws -> InvestigationMachineGateCoordinatorNodeIdentity {
      guard safeName(name) else { throw uncertain() }
      var value = stat()
      guard fstatat(parent, name, &value, namedFlags) == 0 else {
        throw uncertain()
      }
      return nodeIdentity(value)
    }
    private static func extendedACLIsEmpty(_ descriptor: Int32) throws
      -> Bool {
      errno = 0
      guard let acl = acl_get_fd_np(descriptor, ACL_TYPE_EXTENDED) else {
        if errno == ENOENT { return true }
        throw uncertain()
      }
      var entry: acl_entry_t?
      let result = acl_get_entry(acl, Int32(ACL_FIRST_ENTRY.rawValue), &entry)
      let savedError = errno
      guard acl_free(UnsafeMutableRawPointer(acl)) == 0, result >= 0 else {
        errno = savedError
        throw uncertain()
      }
      return result != 0
    }
    private static func extendedAttributeNames(_ descriptor: Int32) throws
      -> [String] {
      let count = flistxattr(descriptor, nil, 0, 0)
      guard count >= 0, count <= 4_096 else { throw uncertain() }
      guard count > 0 else { return [] }
      var bytes = [CChar](repeating: 0, count: count)
      guard flistxattr(descriptor, &bytes, bytes.count, 0) == count,
            bytes.last == 0 else { throw uncertain() }
      return try bytes.split(separator: 0).map { raw in
        guard let value = String(
          bytes: raw.map(UInt8.init(bitPattern:)), encoding: .utf8
        ), !value.isEmpty else { throw uncertain() }
        return value
      }
    }
    private static func nodeIdentity(
      _ value: stat
    ) -> InvestigationMachineGateCoordinatorNodeIdentity {
      .init(
        device: UInt64(value.st_dev), inode: UInt64(value.st_ino),
        generation: UInt64(value.st_gen), type: value.st_mode & S_IFMT,
        ownerUserID: value.st_uid, ownerGroupID: value.st_gid,
        permissions: value.st_mode & 0o7777,
        linkCount: UInt64(value.st_nlink), flags: value.st_flags,
        size: value.st_size,
        modificationSeconds: Int64(value.st_mtimespec.tv_sec),
        modificationNanoseconds: Int64(value.st_mtimespec.tv_nsec)
      )
    }
    private static func safeName(_ value: String) -> Bool {
      !value.isEmpty && value != "." && value != ".."
        && !value.contains("/") && !value.contains("\0")
        && value.utf8.count < Int(NAME_MAX)
    }
    private static func millisecondDate(_ value: Date) -> Date {
      Date(
        timeIntervalSince1970:
          floor(value.timeIntervalSince1970 * 1_000) / 1_000
      )
    }
    private static func protocolFailure(
      _ operation: String = #function, line: Int = #line
    ) -> InvestigationMachineGateCoordinatorSystemError {
      .init(
        kind: .protocolFailure,
        operation: "protocol-" + operation + ":" + String(line)
      )
    }
    private static func uncertain(
      _ operation: String = #function, line: Int = #line
    ) -> InvestigationMachineGateCoordinatorSystemError {
      .init(
        kind: .containmentUncertain,
        operation: operation + ":" + String(line)
      )
    }
  }
  struct InvestigationMachineGateCoordinatorMaterializationProbeResult:
    Equatable, Sendable
  {
    let sourceFingerprintSHA256: String
    let canonicalPlan: InvestigationPlan
    let rootWasPresent: Bool
    let rootIsAbsentAfterRetirement: Bool
  }
  enum InvestigationMachineGateCoordinatorMaterializationProbe {
    static func run() async throws
      -> InvestigationMachineGateCoordinatorMaterializationProbeResult {
      let attempt = try await InvestigationMachineGateCoordinatorOwnedAttempt
        .materialize()
      let root = attempt.rootURL
      var before = stat()
      let present = lstat(root.path, &before) == 0
      try attempt.retire()
      var value = stat()
      errno = 0
      let absent = lstat(root.path, &value) != 0 && errno == ENOENT
      return .init(
        sourceFingerprintSHA256: attempt.sourceFingerprint.hex,
        canonicalPlan: attempt.canonicalPlan, rootWasPresent: present,
        rootIsAbsentAfterRetirement: absent
      )
    }
  }
#endif
