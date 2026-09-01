import Darwin
import Foundation
import Testing
@testable import StornautInvestigationMachineGateCoordinatorSupport
@testable import StornautInvestigationMachineGateSupport
@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationMachineLaunchSupport
@Suite("Investigation machine gate coordinator composition", .serialized)
struct InvestigationMachineGateCoordinatorCompositionTests {
  @Test
  func productionMaterializerUsesStorePlannerAndRetiresItsExactAttempt() async throws {
    let result = try await InvestigationMachineGateCoordinatorMaterializationProbe
      .run()
    #expect(result.rootWasPresent)
    #expect(result.rootIsAbsentAfterRetirement)
    #expect(result.sourceFingerprintSHA256 == result.canonicalPlan.sourceFingerprint.hex)
    #expect(InvestigationMachineCoordinatorSourceFixtureTemplate.validates(
      result.canonicalPlan,
      sourceFingerprint: result.canonicalPlan.sourceFingerprint,
      now: result.canonicalPlan.createdAt
    ))
  }
  @Test(arguments: InvestigationMachineGateCoordinatorOwnedAttempt.RootBootstrapStage.allCases)
  func rootSetupFailureRemovesTheExactCreatedAttempt(
    _ fault: InvestigationMachineGateCoordinatorOwnedAttempt.RootBootstrapStage) async throws {
    let probe = CoordinatorRootBootstrapProbe()
    await #expect(throws: (any Error).self) {
      _ = try await InvestigationMachineGateCoordinatorOwnedAttempt.materialize {
        stage, _, _, root in
        probe.observe(root); if stage == fault { throw CoordinatorRootFault() }
      }
    }
    var value = stat(); errno = 0
    #expect(lstat(try #require(probe.root).path, &value) != 0 && errno == ENOENT)
  }
  @Test
  func rootSetupReplacementIsNeverRemovedOrTraversed() async throws {
    let probe = CoordinatorRootBootstrapProbe()
    do {
      _ = try await InvestigationMachineGateCoordinatorOwnedAttempt.materialize {
        stage, parent, name, root in
          guard stage == .open else { return }
          let backupName = name + "-original"
          guard renameat(parent, name, parent, backupName) == 0,
                mkdirat(parent, name, 0o700) == 0 else { throw CoordinatorRootFault() }
          probe.observe(root, backup: root.deletingLastPathComponent()
            .appending(path: backupName, directoryHint: .isDirectory))
          throw CoordinatorRootFault()
        }
      Issue.record("replacement must make containment uncertain")
    } catch {
      #expect(InvestigationMachineGateCoordinatorSupport.status(for: error) == 82)
    }
    let root = try #require(probe.root), backup = try #require(probe.backup)
    defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: backup) }
    #expect(FileManager.default.fileExists(atPath: root.path))
    #expect(FileManager.default.fileExists(atPath: backup.path))
  }
  @Test(arguments: [
    InvestigationMachineGateCoordinatorInvocationSnapshot(
      argumentCount: 2, environmentEntries: [], descriptors: [0, 1, 2, 3],
      realUserID: 501, effectiveUserID: 501, realGroupID: 20,
      effectiveGroupID: 20, processID: 4_001, processGroupID: 4_001,
      sessionID: 4_001, foregroundProcessGroupID: 4_001,
      standardOutputWritable: true, terminalWritableCharacterDevice: true,
      receiptPipeWritable: true
    ),
    InvestigationMachineGateCoordinatorInvocationSnapshot(
      argumentCount: 1, environmentEntries: ["HOME=/tmp"],
      descriptors: [0, 1, 2, 3], realUserID: 501, effectiveUserID: 501,
      realGroupID: 20, effectiveGroupID: 20, processID: 4_001,
      processGroupID: 4_001, sessionID: 4_001,
      foregroundProcessGroupID: 4_001, standardOutputWritable: true,
      terminalWritableCharacterDevice: true, receiptPipeWritable: true
    ),
    InvestigationMachineGateCoordinatorInvocationSnapshot(
      argumentCount: 1, environmentEntries: [], descriptors: [0, 1, 2, 3, 4],
      realUserID: 501, effectiveUserID: 501, realGroupID: 20,
      effectiveGroupID: 20, processID: 4_001, processGroupID: 4_001,
      sessionID: 4_001, foregroundProcessGroupID: 4_001,
      standardOutputWritable: true, terminalWritableCharacterDevice: true,
      receiptPipeWritable: true
    ),
  ])
  func productionInvocationRejectsArgumentsEnvironmentAndExtraDescriptors(
    _ snapshot: InvestigationMachineGateCoordinatorInvocationSnapshot
  ) {
    #expect(throws: InvestigationMachineGateCoordinatorProductionError.invalidInvocation) {
      try InvestigationMachineGateCoordinatorInvocationValidator.validate(snapshot)
    }
  }
  @Test
  func productionInvocationAcceptsOnlyClosedCoordinatorShape() throws {
    try InvestigationMachineGateCoordinatorInvocationValidator.validate(.init(
      argumentCount: 1, environmentEntries: [], descriptors: [0, 1, 2, 3],
      realUserID: 501, effectiveUserID: 501, realGroupID: 20,
      effectiveGroupID: 20, processID: 4_001, processGroupID: 4_001,
      sessionID: 4_001, foregroundProcessGroupID: 4_001,
      standardOutputWritable: true, terminalWritableCharacterDevice: true,
      receiptPipeWritable: true
    ))
  }
  @Test
  func productionExitMappingKeepsProtocolAndContainmentDistinct() {
    #expect(InvestigationMachineGateCoordinatorSupport.status(
      for: InvestigationMachineGateCoordinatorProductionError.invalidInvocation
    ) == 80)
    #expect(InvestigationMachineGateCoordinatorSupport.status(
      for: InvestigationMachineGateCoordinatorProductionError.protocolFailure
    ) == 81)
    #expect(InvestigationMachineGateCoordinatorSupport.status(for: InvestigationMachineGateCoordinatorReceiptError.invalidValue) == 81)
    #expect(InvestigationMachineGateCoordinatorSupport.status(
      for: InvestigationMachineGateCoordinatorProductionError
        .postSettlementProtocolFailure
    ) == 81)
    #expect(InvestigationMachineGateCoordinatorSupport.status(
      for: InvestigationMachineGateCoordinatorProductionError
        .containmentUncertain
    ) == 82)
    #expect(InvestigationMachineGateCoordinatorSupport.status(
      for: CancellationError()
    ) == 83)
    #expect(InvestigationMachineGateCoordinatorSupport.status(
      for: InvestigationFixedGateHandoffError.forwardedSignal(SIGTERM)
    ) == 83)
    #expect(InvestigationMachineGateCoordinatorSupport.status(
      for: InvestigationFixedGateHandoffError.exactReapUncertain
    ) == 82)
    #expect(InvestigationMachineGateCoordinatorSupport.status(
      for: InvestigationFixedGateHandoffError.invalidTransportReceipt
    ) == 81)
    #expect(InvestigationMachineGateCoordinatorSupport.status(
      for: InvestigationFixedGateHandoffError.deadlineExceeded
    ) == 81)
    #expect(InvestigationMachineGateCoordinatorSupport.status(
      for: InvestigationFixedGateHandoffError.settlementResidue
    ) == 82)
  }
  @Test
  func receiptSinkWritesOneLengthPrefixedFrameThenEOF() async throws {
    var descriptors = [Int32](repeating: -1, count: 2)
    try #require(pipe(&descriptors) == 0)
    defer { _ = Darwin.close(descriptors[0]) }
    let receipt = try InvestigationMachineGateCoordinatorReceiptV1(
      terminal: await CoordinatorCompositionProbe().terminalState()
    )
    let payload = try receipt.encoded()
    let deadline = try InvestigationHandoffUTCMicroseconds(
      rawValue: Int64.max)
    let sink = InvestigationMachineGateCoordinatorReceiptSink(
      descriptor: descriptors[1], validBefore: deadline
    )
    try sink.writeAndClose(.receipt(receipt))
    var storage = [UInt8](repeating: 0, count: 4_096)
    let count = Darwin.read(descriptors[0], &storage, storage.count)
    try #require(count == payload.count + 4)
    let frame = Data(storage.prefix(count))
    let declared = frame.prefix(4).reduce(UInt32(0)) {
      ($0 << 8) | UInt32($1)
    }
    #expect(declared == UInt32(payload.count))
    #expect(frame.dropFirst(4) == payload)
    #expect(Darwin.read(descriptors[0], &storage, storage.count) == 0)
    #expect(throws: InvestigationMachineGateCoordinatorProductionError
      .containmentUncertain) { try sink.writeAndClose(.closeOnly) }
  }
  @Test
  func receiptWriterRetriesBackpressureWithoutRefreshingDeadline() throws {
    let deadline = try InvestigationHandoffUTCMicroseconds(rawValue: 42)
    let probe = CoordinatorReceiptOutputProbe(waits: [
      .interrupted, .writable, .writable, .writable], writes: [
        .wouldBlock, .written(2), .written(2)])
    try InvestigationMachineGateCoordinatorReceiptOutputWriter.writeAll(
      Data([1, 2, 3, 4]), to: 39, validBefore: deadline, system: .init(
        waitWritable: probe.wait, write: probe.write))
    #expect(probe.deadlines == Array(repeating: deadline, count: 4))
    #expect(probe.offsets == [0, 0, 2])
  }
  @Test(arguments: [
    InvestigationMachineGateCoordinatorReceiptWaitResult.expiredOrFailed,
  ])
  func receiptWriterFailsClosedAtDeadline(
    _ result: InvestigationMachineGateCoordinatorReceiptWaitResult
  ) throws {
    let deadline = try InvestigationHandoffUTCMicroseconds(rawValue: 42)
    let probe = CoordinatorReceiptOutputProbe(
      waits: [result], writes: [.written(1)])
    #expect(throws: InvestigationMachineGateCoordinatorProductionError
      .containmentUncertain) {
        try InvestigationMachineGateCoordinatorReceiptOutputWriter.writeAll(
          Data([1]), to: 39, validBefore: deadline, system: .init(
            waitWritable: probe.wait, write: probe.write))
    }
    #expect(probe.deadlines == [deadline] && probe.offsets.isEmpty)
  }
  @Test
  func receiptWriterRetriesInterruptedWriteOnTheSameDeadline() throws {
    let deadline = try InvestigationHandoffUTCMicroseconds(rawValue: 42)
    let probe = CoordinatorReceiptOutputProbe(
      waits: [.writable, .writable], writes: [.interrupted, .written(1)])
    try InvestigationMachineGateCoordinatorReceiptOutputWriter.writeAll(
      Data([1]), to: 39, validBefore: deadline, system: .init(
        waitWritable: probe.wait, write: probe.write))
    #expect(probe.deadlines == [deadline, deadline])
    #expect(probe.offsets == [0, 0])
  }
  @Test(arguments: [
    InvestigationMachineGateCoordinatorReceiptWriteResult.failed,
    .written(0), .written(2),
  ])
  func receiptWriterRejectsNonretryableOrInvalidWrites(
    _ result: InvestigationMachineGateCoordinatorReceiptWriteResult
  ) throws {
    let deadline = try InvestigationHandoffUTCMicroseconds(rawValue: 42)
    let probe = CoordinatorReceiptOutputProbe(
      waits: [.writable], writes: [result])
    #expect(throws: InvestigationMachineGateCoordinatorProductionError
      .containmentUncertain) {
        try InvestigationMachineGateCoordinatorReceiptOutputWriter.writeAll(
          Data([1]), to: 39, validBefore: deadline, system: .init(
            waitWritable: probe.wait, write: probe.write))
    }
    #expect(probe.deadlines == [deadline] && probe.offsets == [0])
  }
  @Test
  func receiptSinkClosesOnceAfterWriteFailure() async throws {
    var descriptors = [Int32](repeating: -1, count: 2)
    try #require(pipe(&descriptors) == 0)
    defer { _ = Darwin.close(descriptors[0]) }
    let deadline = try InvestigationHandoffUTCMicroseconds(rawValue: 42)
    let probe = CoordinatorReceiptOutputProbe(
      descriptor: descriptors[1], waits: [.writable], writes: [.failed])
    let sink = InvestigationMachineGateCoordinatorReceiptSink(
      descriptor: descriptors[1], validBefore: deadline, outputSystem: .init(
        waitWritable: probe.wait, write: probe.write))
    let receipt = try InvestigationMachineGateCoordinatorReceiptV1(
      terminal: await CoordinatorCompositionProbe().terminalState())
    #expect(throws: InvestigationMachineGateCoordinatorProductionError
      .containmentUncertain) { try sink.writeAndClose(.receipt(receipt)) }
    var byte: UInt8 = 0
    #expect(Darwin.read(descriptors[0], &byte, 1) == 0)
    #expect(throws: InvestigationMachineGateCoordinatorProductionError
      .containmentUncertain) { try sink.writeAndClose(.closeOnly) }
  }
  @Test
  func ownedDescriptorClosesExactlyOnceOnSuccessAndFailure() throws {
    var closes: [Int32] = []
    let value = try InvestigationMachineGateCoordinatorOwnedAttempt.withClosed(7,
      close: { closes.append($0); return 0 }) { 39 }
    #expect(value == 39 && closes == [7])
    #expect(throws: CoordinatorCompositionProbeError.ordinary(.materializeSource)) {
      _ = try InvestigationMachineGateCoordinatorOwnedAttempt.withClosed(8,
        close: { closes.append($0); return 0 }) {
          throw CoordinatorCompositionProbeError.ordinary(.materializeSource)
        } as Int
    }
    #expect(closes == [7, 8])
    do {
      _ = try InvestigationMachineGateCoordinatorOwnedAttempt.withClosed(9,
        close: { closes.append($0); return -1 }) { 39 }
      Issue.record("close failure must fail closed")
    } catch {
      #expect(InvestigationMachineGateCoordinatorSupport.status(for: error) == 82)
    }
    #expect(closes == [7, 8, 9])
  }
  @Test
  func inventoryFailureClosesEnumerationStream() throws {
    let root = FileManager.default.temporaryDirectory.appending(
      path: "stornaut-inventory-" + UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    try Data([1]).write(to: root.appending(path: "entry"))
    defer { try? FileManager.default.removeItem(at: root) }
    let descriptor = open(root.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC)
    try #require(descriptor >= 0); defer { _ = close(descriptor) }
    var closes = 0
    #expect(throws: (any Error).self) {
      _ = try InvestigationMachineGateCoordinatorOwnedAttempt.inventory(
        descriptor, maximumEntries: 0,
        closeDirectory: { closes += 1; return closedir($0) })
    }
    #expect(closes == 1)
  }
  @Test
  func coordinatorCompletionArtifactMatchesIndependentDriverContract() throws {
    let fixture = CoordinatorCompositionProbe()
    let projected = try fixture.projectedInput()
    let encoded = try coordinatorExpectedCompletionArtifact(projected)
    #expect(encoded.count == 207)
    #expect(try HandoffBinaryTranscript.decode(
      encoded,
      expectedDomain: "stornaut.task39.machine.driver-completion",
      expectedBusinessFieldByteCounts: [
        16...16, 32...32, 32...32, 4...4, 32...32,
      ],
      maximumByteCount: 512
    ).count == 5)
    #expect(InvestigationHandoffSHA256.hashing(encoded).rawBytes.contains {
      $0 != 0
    })
  }
  @Test
  func successUsesOneSourceAndEightConfigurationsInExactOrder() async throws {
    let probe = CoordinatorCompositionProbe()
    let composition = InvestigationMachineGateCoordinatorComposition(
      dependencies: probe.dependencies()
    )
    let receipt = try await composition.run()
    #expect(await probe.events == CoordinatorCompositionStage.allCases)
    #expect(await probe.materializeSourceCallCount == 1)
    #expect(await probe.makeBindingCallCount == 1)
    #expect(await probe.makeConfigurationsCallCount == 1)
    #expect(await probe.authorCohortCallCount == 1)
    #expect(await probe.handoffCallCount == 1)
    #expect(await probe.retireArtifactsCallCount == 1)
    #expect(await probe.makeReceiptCallCount == 1)
    #expect(await probe.writeCloseCallCount == 1)
    #expect(receipt.buildProvenanceSHA256 == probe.buildProvenanceSHA256)
    #expect(receipt.signedBindingSHA256.lowercaseHex == probe.signedBindingSHA256)
    #expect(receipt.outerAttemptUUID == probe.outerAttemptUUID)
    #expect(receipt.wholeProjectedInputSHA256.lowercaseHex
      == probe.wholeProjectedInputSHA256)
    #expect(receipt.gateTransportReceiptSHA256.lowercaseHex
      == probe.gateTransportReceiptSHA256)
    let handoffTiming = try #require(await probe.handoffTiming)
    let retirementCompleted = try #require(await probe.retirementCompletedNanoseconds)
    #expect(receipt.monotonicStartedNanoseconds < handoffTiming.started
      && receipt.monotonicCompletedNanoseconds > max(handoffTiming.completed, retirementCompleted))
    #expect(receipt.attemptBaseRetired)
    #expect(receipt.runtimeArtifactsRetired)
    #expect(await probe.lastSinkDisposition == .receipt(receipt))
  }
  @Test
  func productionSourceRequiresCompleteCampaignWindowBeforeHandoff() async throws {
    let probe = CoordinatorCompositionProbe()
    let deadline = Date(timeIntervalSince1970: 11_125)
    let cohort = try probe.authoredCohort(configurationValidBefore: deadline)
    #expect(InvestigationMachineGateCoordinatorHandoffAdmission
      .minimumHandoffRemainingSeconds == 1_125)
    #expect(throws: Never.self) {
      try InvestigationMachineGateCoordinatorHandoffAdmission.validate(
        cohort, now: deadline.addingTimeInterval(-1_125)
      )
    }
    #expect(throws: InvestigationMachineGateCoordinatorProductionError
      .protocolFailure) {
      try InvestigationMachineGateCoordinatorHandoffAdmission.validate(
        cohort, now: Date(timeIntervalSince1970: 10_000.0000006)
      )
    }
    #expect(throws: InvestigationMachineGateCoordinatorProductionError
      .protocolFailure) {
      try InvestigationMachineGateCoordinatorHandoffAdmission.validate(
        cohort, now: Date(timeIntervalSince1970: .infinity)
      )
    }
    let late = CoordinatorCompositionProbe(
      configurationValidBefore: deadline,
      wallNow: Date(timeIntervalSince1970: 10_000.0000006)
    )
    await #expect(throws: InvestigationMachineGateCoordinatorProductionError
      .protocolFailure) {
      _ = try await InvestigationMachineGateCoordinatorComposition(
        dependencies: late.dependencies()
      ).run()
    }
    #expect(await late.handoffCallCount == 0)
    #expect(await late.retireArtifactsCallCount == 1)
    #expect(await late.lastSinkDisposition == .closeOnly)

    let mixed = try probe.projectedInput(
      configurationValidBeforeRawValues: [
        Int64(deadline.timeIntervalSince1970 * 1_000_000),
        Int64(deadline.timeIntervalSince1970 * 1_000_000) - 1,
      ] + Array(repeating:
        Int64(deadline.timeIntervalSince1970 * 1_000_000), count: 6)
    )
    #expect(throws: InvestigationMachineGateCoordinatorProductionError
      .protocolFailure) {
      _ = try InvestigationMachineGateCoordinatorAuthoredCohort(
        sourceFingerprintSHA256: probe.sourceFingerprintSHA256,
        configurationSHA256s: mixed.capsule.epochs.map {
          $0.configurationSHA256.lowercaseHex
        },
        configurationValidBefore: try .init(
          timeIntervalSince1970: deadline.timeIntervalSince1970
        ),
        projectedInput: mixed
      )
    }
  }
  @Test(arguments: CoordinatorClockFault.allCases)
  fileprivate func invalidCoordinatorClockCannotMintReceipt(_ fault: CoordinatorClockFault) async {
    let clock = CoordinatorMonotonicProbe(fault.steps)
    let probe = CoordinatorCompositionProbe(monotonic: clock)
    await #expect(throws: InvestigationMachineGateCoordinatorProductionError
      .containmentUncertain) {
      _ = try await InvestigationMachineGateCoordinatorComposition(
        dependencies: probe.dependencies()).run()
    }
    #expect(await probe.makeReceiptCallCount == 0)
    #expect(await probe.lastSinkDisposition == .closeOnly)
    #expect(clock.calls == fault.expectedCalls)
    if fault.expectedCalls == 1 { #expect(await probe.validateInvocationCallCount == 0) }
  }
  @Test
  func incompleteOrDivergentTerminalStateCannotMintReceipt() async throws {
    let probe = CoordinatorCompositionProbe()
    let complete = try await probe.terminalState()
    #expect(try InvestigationMachineGateCoordinatorReceiptV1(
      terminal: complete
    ).attemptBaseRetired)
    let missingHandoff = InvestigationMachineGateCoordinatorTerminalState(
      source: complete.source, binding: complete.binding,
      configurations: complete.configurations, cohort: complete.cohort,
      handoff: nil, retirementOutcome: .retired,
      monotonicStartedNanoseconds: 999, monotonicCompletedNanoseconds: 2_001
    )
    #expect(throws: InvestigationMachineGateCoordinatorCompositionError
      .incompleteTerminalState) {
      _ = try InvestigationMachineGateCoordinatorReceiptV1(
        terminal: missingHandoff
      )
    }
    let divergentSource = InvestigationMachineGateCoordinatorTerminalState(
      source: InvestigationMachineGateCoordinatorMaterializedSource(
        sourceFingerprintSHA256: String(repeating: "f", count: 64)
      ),
      binding: complete.binding, configurations: complete.configurations,
      cohort: complete.cohort, handoff: complete.handoff,
      retirementOutcome: .retired, monotonicStartedNanoseconds: 999,
      monotonicCompletedNanoseconds: 2_001
    )
    #expect(throws: InvestigationMachineGateCoordinatorCompositionError
      .incompleteTerminalState) {
      _ = try InvestigationMachineGateCoordinatorReceiptV1(
        terminal: divergentSource
      )
    }
  }
  @Test(arguments: CoordinatorCompositionStage.preHandoffStages)
  fileprivate func preHandoffFailureStopsLaunchRetiresAndClosesWithoutReceipt(
    _ failedStage: CoordinatorCompositionStage
  ) async throws {
    let probe = CoordinatorCompositionProbe(failure: .ordinary(failedStage))
    let composition = InvestigationMachineGateCoordinatorComposition(
      dependencies: probe.dependencies()
    )
    await #expect(throws: CoordinatorCompositionProbeError.ordinary(failedStage)) {
      _ = try await composition.run()
    }
    let events = await probe.events
    #expect(!events.contains(.handoff))
    #expect(events.suffix(2) == [.retireArtifacts, .writeClose])
    #expect(await probe.handoffCallCount == 0)
    #expect(await probe.retireArtifactsCallCount == 1)
    #expect(await probe.makeReceiptCallCount == 0)
    #expect(await probe.writeCloseCallCount == 1)
    #expect(await probe.lastSinkDisposition == .closeOnly)
  }
  @Test
  func handoffFailureRetiresAndPreservesOriginalWhenCleanupIsCertain() async throws {
    let clock = CoordinatorMonotonicProbe()
    let probe = CoordinatorCompositionProbe(
      failure: .handoffDefinitelyNotSpawned, monotonic: clock)
    let composition = InvestigationMachineGateCoordinatorComposition(
      dependencies: probe.dependencies()
    )
    await #expect(throws: InvestigationFixedGateHandoffError.spawnFailedBeforeTransfer) {
      _ = try await composition.run()
    }
    #expect(await probe.events.suffix(2)
      == [.retireArtifacts, .writeClose])
    #expect(await probe.retireArtifactsCallCount == 1)
    #expect(await probe.makeReceiptCallCount == 0)
    #expect(await probe.writeCloseCallCount == 1)
    #expect(await probe.lastSinkDisposition == .closeOnly)
    #expect(clock.calls == 1)
  }
  @Test
  func uncertainHandoffPreservesAttemptAndClosesWithoutReceipt() async throws {
    let probe = CoordinatorCompositionProbe(failure: .handoffContainmentUncertain)
    let composition = InvestigationMachineGateCoordinatorComposition(
      dependencies: probe.dependencies()
    )
    await #expect(throws: InvestigationMachineGateCoordinatorCompositionError
      .retirementUncertain) { _ = try await composition.run() }
    #expect(await probe.retireArtifactsCallCount == 0)
    #expect(await probe.makeReceiptCallCount == 0)
    #expect(await probe.writeCloseCallCount == 1)
    #expect(await probe.lastSinkDisposition == .closeOnly)
    #expect(InvestigationMachineGateCoordinatorSupport.status(
      for: InvestigationMachineGateCoordinatorCompositionError
        .retirementUncertain
    ) == 82)
  }
  @Test
  func postSettlementFailureStillRetiresAttempt() async throws {
    let probe = CoordinatorCompositionProbe(failure: .handoffAfterSettlementMismatch)
    let composition = InvestigationMachineGateCoordinatorComposition(
      dependencies: probe.dependencies()
    )
    await #expect(throws: InvestigationMachineGateCoordinatorProductionError
      .postSettlementProtocolFailure) { _ = try await composition.run() }
    #expect(await probe.retireArtifactsCallCount == 1)
    #expect(await probe.lastSinkDisposition == .closeOnly)
  }
  @Test
  func retirementUncertaintyDominatesHandoffFailure() async throws {
    let probe = CoordinatorCompositionProbe(
      failure: .handoffAndRetirementUncertain
    )
    let composition = InvestigationMachineGateCoordinatorComposition(
      dependencies: probe.dependencies()
    )
    await #expect(
      throws: CoordinatorCompositionProbeError.uncertain(.retireArtifacts)
    ) {
      _ = try await composition.run()
    }
    #expect(await probe.events.suffix(2)
      == [.retireArtifacts, .writeClose])
    #expect(await probe.makeReceiptCallCount == 0)
    #expect(await probe.writeCloseCallCount == 1)
    #expect(await probe.lastSinkDisposition == .closeOnly)
  }
  @Test
  func writeCloseUncertaintyDominatesEarlierFailure() async throws {
    let probe = CoordinatorCompositionProbe(
      failure: .handoffAndWriteCloseUncertain
    )
    let composition = InvestigationMachineGateCoordinatorComposition(
      dependencies: probe.dependencies()
    )
    await #expect(
      throws: CoordinatorCompositionProbeError.uncertain(.writeClose)
    ) {
      _ = try await composition.run()
    }
    #expect(await probe.events.suffix(2)
      == [.retireArtifacts, .writeClose])
    #expect(await probe.makeReceiptCallCount == 0)
    #expect(await probe.lastSinkDisposition == .closeOnly)
  }
  @Test
  func cancellationFailsClosedThroughRetirementAndWriteClose() async throws {
    let probe = CoordinatorCompositionProbe(failure: .cancelledAtBinding)
    let composition = InvestigationMachineGateCoordinatorComposition(
      dependencies: probe.dependencies()
    )
    await #expect(throws: CancellationError.self) {
      _ = try await composition.run()
    }
    let events = await probe.events
    #expect(events == [
      .validateInvocation, .materializeSource, .makeBinding,
      .retireArtifacts, .writeClose,
    ])
    #expect(await probe.retireArtifactsCallCount == 1)
    #expect(await probe.makeReceiptCallCount == 0)
    #expect(await probe.writeCloseCallCount == 1)
    #expect(await probe.lastSinkDisposition == .closeOnly)
  }
  @Test
  func receiptJoinsEveryAuthoritativeStageWithoutAuthoritySurface() async throws {
    let probe = CoordinatorCompositionProbe()
    let receipt = try await InvestigationMachineGateCoordinatorComposition(
      dependencies: probe.dependencies()
    ).run()
    #expect(receipt.buildProvenanceSHA256 == probe.buildProvenanceSHA256)
    #expect(receipt.signedBindingSHA256.lowercaseHex == probe.signedBindingSHA256)
    #expect(receipt.outerAttemptUUID == probe.outerAttemptUUID)
    #expect(receipt.wholeProjectedInputSHA256.lowercaseHex
      == probe.wholeProjectedInputSHA256)
    #expect(receipt.gateExecutableSHA256.lowercaseHex == probe.gateExecutableSHA256)
    #expect(receipt.gateTransportReceiptSHA256.lowercaseHex
      == probe.gateTransportReceiptSHA256)
    #expect(receipt.gateProcessID == 4101)
    #expect(receipt.gateProcessGroupID == 4101)
    #expect(receipt.gateSessionID == 4001)
    #expect(receipt.exactGateWaitClassification == .exited(status: 0))
    #expect(receipt.attemptBaseRetired)
    #expect(receipt.runtimeArtifactsRetired)
    #expect(try InvestigationMachineGateCoordinatorReceiptV1.decode(
      receipt.encoded()
    ) == receipt)
    #expect(!(receipt as Any is any Encodable))
    #expect(!(receipt as Any is any Decodable))
    let receiptLabels = Mirror(reflecting: receipt).children.compactMap(\.label)
    let dependencyLabels = Mirror(
      reflecting: probe.dependencies()
    ).children.compactMap(\.label)
    for forbidden in ["descriptor", "fd", "path", "proof", "callback"] {
      #expect(!receiptLabels.contains {
        $0.localizedCaseInsensitiveContains(forbidden)
      })
    }
    #expect(!dependencyLabels.contains {
      $0.localizedCaseInsensitiveContains("descriptor")
        || $0.localizedCaseInsensitiveContains("path")
        || $0.localizedCaseInsensitiveContains("proof")
        || $0.localizedCaseInsensitiveContains("callback")
    })
  }
  @Test
  func compositionIsOneShotAfterSuccessAndFailure() async throws {
    let successProbe = CoordinatorCompositionProbe()
    let success = InvestigationMachineGateCoordinatorComposition(
      dependencies: successProbe.dependencies()
    )
    _ = try await success.run()
    await #expect(throws: InvestigationMachineGateCoordinatorCompositionError.alreadyConsumed) {
      _ = try await success.run()
    }
    #expect(await successProbe.validateInvocationCallCount == 1)
    let failureProbe = CoordinatorCompositionProbe(
      failure: .ordinary(.makeConfigurations)
    )
    let failed = InvestigationMachineGateCoordinatorComposition(
      dependencies: failureProbe.dependencies()
    )
    await #expect(throws: CoordinatorCompositionProbeError.ordinary(.makeConfigurations)) {
      _ = try await failed.run()
    }
    await #expect(throws: InvestigationMachineGateCoordinatorCompositionError.alreadyConsumed) {
      _ = try await failed.run()
    }
    #expect(await failureProbe.validateInvocationCallCount == 1)
  }
}

private final class CoordinatorReceiptOutputProbe: @unchecked Sendable {
  private let lock = NSLock()
  private let descriptor: Int32
  private var waitValues: [InvestigationMachineGateCoordinatorReceiptWaitResult]
  private var writeValues: [InvestigationMachineGateCoordinatorReceiptWriteResult]
  private var observedDeadlines: [InvestigationHandoffUTCMicroseconds] = []
  private var observedOffsets: [Int] = []
  init(descriptor: Int32 = 39,
    waits: [InvestigationMachineGateCoordinatorReceiptWaitResult],
    writes: [InvestigationMachineGateCoordinatorReceiptWriteResult]) {
    self.descriptor = descriptor; waitValues = waits; writeValues = writes
  }
  var deadlines: [InvestigationHandoffUTCMicroseconds] {
    lock.withLock { observedDeadlines }
  }
  var offsets: [Int] { lock.withLock { observedOffsets } }
  func wait(_ descriptor: Int32, _ deadline: InvestigationHandoffUTCMicroseconds)
    -> InvestigationMachineGateCoordinatorReceiptWaitResult {
    lock.withLock {
      precondition(descriptor == self.descriptor && !waitValues.isEmpty)
      observedDeadlines.append(deadline); return waitValues.removeFirst()
    }
  }
  func write(_ descriptor: Int32, _ bytes: Data, _ offset: Int)
    -> InvestigationMachineGateCoordinatorReceiptWriteResult {
    lock.withLock {
      precondition(descriptor == self.descriptor && offset < bytes.count
        && !writeValues.isEmpty)
      observedOffsets.append(offset); return writeValues.removeFirst()
    }
  }
}
private enum CoordinatorCompositionStage: String, CaseIterable, Sendable {
  case validateInvocation
  case materializeSource
  case makeBinding
  case makeConfigurations
  case authorCohort
  case handoff
  case retireArtifacts
  case makeReceipt
  case writeClose
  static let preHandoffStages: [Self] = [
    .validateInvocation, .materializeSource, .makeBinding,
    .makeConfigurations, .authorCohort,
  ]
}
private enum CoordinatorCompositionProbeFailure: Sendable {
  case ordinary(CoordinatorCompositionStage)
  case handoffDefinitelyNotSpawned
  case handoffContainmentUncertain
  case handoffAfterSettlementMismatch
  case handoffAndRetirementUncertain
  case handoffAndWriteCloseUncertain
  case cancelledAtBinding
}
private enum CoordinatorCompositionProbeError: Error, Equatable, Sendable {
  case ordinary(CoordinatorCompositionStage)
  case uncertain(CoordinatorCompositionStage)
}
private actor CoordinatorCompositionProbe {
  nonisolated let sourceFingerprintSHA256 = String(repeating: "1", count: 64)
  nonisolated let buildProvenanceSHA256 = String(repeating: "2", count: 64)
  nonisolated let signedBindingSHA256 = String(repeating: "3", count: 64)
  nonisolated let outerAttemptUUID = UUID(
    uuidString: "00000000-0000-4000-8000-000000000039"
  )!
  nonisolated let wholeProjectedInputSHA256 = String(repeating: "4", count: 64)
  nonisolated let gateExecutableSHA256 = String(repeating: "5", count: 64)
  nonisolated let gateTransportReceiptSHA256 = String(repeating: "6", count: 64)
  nonisolated let configurationSHA256s = (0..<8).map { index in
    String(format: "%064x", index + 16)
  }
  nonisolated let configurationValidBefore:
    InvestigationHandoffUTCMicroseconds
  nonisolated let wallNow: Date
  private(set) var events: [CoordinatorCompositionStage] = []
  private(set) var validateInvocationCallCount = 0
  private(set) var materializeSourceCallCount = 0
  private(set) var makeBindingCallCount = 0
  private(set) var makeConfigurationsCallCount = 0
  private(set) var authorCohortCallCount = 0
  private(set) var handoffCallCount = 0
  private(set) var retireArtifactsCallCount = 0
  private(set) var makeReceiptCallCount = 0
  private(set) var writeCloseCallCount = 0
  private(set) var handoffTiming: (started: UInt64, completed: UInt64)?
  private(set) var retirementCompletedNanoseconds: UInt64?
  nonisolated private let monotonic: CoordinatorMonotonicProbe
  private(set) var lastSinkDisposition:
    InvestigationMachineGateCoordinatorSinkDisposition?
  private let failure: CoordinatorCompositionProbeFailure?
  init(
    failure: CoordinatorCompositionProbeFailure? = nil,
    monotonic: CoordinatorMonotonicProbe = .init(),
    configurationValidBefore: Date = Date(timeIntervalSince1970: 2_000_001_200),
    wallNow: Date = Date(timeIntervalSince1970: 2_000_000_000)
  ) {
    self.failure = failure
    self.monotonic = monotonic
    self.configurationValidBefore = try! InvestigationHandoffUTCMicroseconds(
      timeIntervalSince1970: configurationValidBefore.timeIntervalSince1970
    )
    self.wallNow = wallNow
  }
  nonisolated func projectedInput(
    configurationValidBeforeRawValues: [Int64]? = nil
  ) throws
    -> InvestigationProjectedCohortInput {
    let binding = try InvestigationHandoffSHA256(
      lowercaseHex: signedBindingSHA256
    )
    let epochs = try (0..<8).map { index in
      let nonce = UUID(
        uuidString: String(
          format: "00000000-0000-4000-8000-%012d", index + 1
        )
      )!
      return try InvestigationCohortEpoch(
        ordinal: UInt32(index),
        epochUUID: UUID(
          uuidString: String(
            format: "00000000-0000-4000-9000-%012d", index + 1
          )
        )!,
        scenario: InvestigationHandoffScenario.allCases[index],
        configurationNonce: nonce, configuration: Data([UInt8(index + 1)]),
        configurationSHA256: .hashing(Data([UInt8(index + 1)])),
        signedRuntimeBindingSHA256: binding
      )
    }
    let capsule = try InvestigationCohortCapsule(
      outerAttemptUUID: outerAttemptUUID, epochs: epochs
    )
    let deadlines = configurationValidBeforeRawValues
      ?? Array(repeating: self.configurationValidBefore.rawValue, count: 8)
    guard deadlines.count == 8 else { throw CoordinatorRootFault() }
    let projections = try epochs.enumerated().map { index, epoch in
      try InvestigationInstalledL2IdentityProjection(
        epochUUID: epoch.epochUUID,
        configurationNonce: epoch.configurationNonce,
        configurationValidBefore: .init(rawValue: deadlines[index]),
        configurationSHA256: epoch.configurationSHA256,
        signedRuntimeBindingSHA256: epoch.signedRuntimeBindingSHA256,
        appExecutableSHA256: .init(rawBytes: Data(repeating: 0x21, count: 32)),
        appBundleIdentifier:
          InvestigationInstalledL2IdentityProjection.fixedAppBundleIdentifier,
        helperExecutableSHA256: .init(
          rawBytes: Data(repeating: 0x22, count: 32)
        ),
        helperServiceIdentifier:
          InvestigationInstalledL2IdentityProjection
          .fixedHelperServiceIdentifier,
        machineDriverExecutableSHA256: .init(
          rawBytes: Data(repeating: 0x23, count: 32)
        ),
        machineDriverSigningIdentifier:
          InvestigationInstalledL2IdentityProjection
          .fixedMachineDriverSigningIdentifier,
        machineDriverDesignatedRequirementSHA256: .init(
          rawBytes: Data(repeating: 0x24, count: 32)
        ),
        machineDriverCodeDirectoryHash: Data(repeating: 0x25, count: 20),
        machineClaimServiceIdentifier:
          InvestigationInstalledL2IdentityProjection
          .fixedMachineClaimServiceIdentifier
      )
    }
    return try InvestigationProjectedCohortInput(
      capsule: capsule, projections: projections
    )
  }
  nonisolated func authoredCohort(
    configurationValidBefore: Date? = nil
  ) throws -> InvestigationMachineGateCoordinatorAuthoredCohort {
    let deadline = try InvestigationHandoffUTCMicroseconds(
      timeIntervalSince1970: configurationValidBefore?.timeIntervalSince1970
        ?? self.configurationValidBefore.timeIntervalSince1970
    )
    return InvestigationMachineGateCoordinatorAuthoredCohort(
      sourceFingerprintSHA256: sourceFingerprintSHA256,
      configurationSHA256s: configurationSHA256s,
      outerAttemptUUID: outerAttemptUUID,
      wholeProjectedInputSHA256: wholeProjectedInputSHA256,
      configurationValidBefore: deadline
    )
  }
  func terminalState() throws
    -> InvestigationMachineGateCoordinatorTerminalState {
    let source = InvestigationMachineGateCoordinatorMaterializedSource(
      sourceFingerprintSHA256: sourceFingerprintSHA256
    )
    let binding = InvestigationMachineGateCoordinatorBinding(
      buildProvenanceSHA256: buildProvenanceSHA256,
      signedBindingSHA256: signedBindingSHA256,
      sourceFingerprintSHA256: sourceFingerprintSHA256
    )
    let configurations = InvestigationMachineGateCoordinatorConfigurationBatch(
      sourceFingerprintSHA256: sourceFingerprintSHA256,
      configurationSHA256s: configurationSHA256s,
      configurationValidBefore: configurationValidBefore
    )
    let cohort = try authoredCohort()
    let handoff = try self.handoff(cohort)
    return InvestigationMachineGateCoordinatorTerminalState(
      source: source, binding: binding, configurations: configurations,
      cohort: cohort, handoff: handoff, retirementOutcome: .retired,
      monotonicStartedNanoseconds: handoff.monotonicStartedNanoseconds - 1,
      monotonicCompletedNanoseconds: handoff.monotonicCompletedNanoseconds + 1
    )
  }
  nonisolated func dependencies()
    -> InvestigationMachineGateCoordinatorDependencies
  {
    InvestigationMachineGateCoordinatorDependencies(
      validateInvocation: { try await self.validateInvocation() },
      materializeSource: { invocation in
        try await self.materializeSource(invocation)
      },
      makeBinding: { source in try await self.makeBinding(source) },
      makeConfigurations: { binding, source in
        try await self.makeConfigurations(binding, source)
      },
      authorCohort: { configurations in
        try await self.authorCohort(configurations)
      },
      handoff: { cohort in try await self.handoff(cohort) },
      retireArtifacts: { source, handoff in
        try await self.retireArtifacts(source, handoff)
      },
      makeReceipt: { state in try await self.makeReceipt(state) },
      writeClose: { disposition in
        try await self.writeClose(disposition)
      }, monotonic: { try self.monotonic.next() }, wallNow: { self.wallNow }
    )
  }
  private func validateInvocation() throws
    -> InvestigationMachineGateCoordinatorInvocation
  {
    try record(.validateInvocation)
    validateInvocationCallCount += 1
    return InvestigationMachineGateCoordinatorInvocation.validated
  }
  private func materializeSource(
    _ invocation: InvestigationMachineGateCoordinatorInvocation
  ) throws -> InvestigationMachineGateCoordinatorMaterializedSource {
    try record(.materializeSource)
    materializeSourceCallCount += 1
    #expect(invocation == .validated)
    return InvestigationMachineGateCoordinatorMaterializedSource(
      sourceFingerprintSHA256: sourceFingerprintSHA256
    )
  }
  private func makeBinding(
    _ source: InvestigationMachineGateCoordinatorMaterializedSource
  ) throws -> InvestigationMachineGateCoordinatorBinding {
    try record(.makeBinding)
    makeBindingCallCount += 1
    if case .cancelledAtBinding = failure { throw CancellationError() }
    #expect(source.sourceFingerprintSHA256 == sourceFingerprintSHA256)
    return InvestigationMachineGateCoordinatorBinding(
      buildProvenanceSHA256: buildProvenanceSHA256,
      signedBindingSHA256: signedBindingSHA256,
      sourceFingerprintSHA256: sourceFingerprintSHA256
    )
  }
  private func makeConfigurations(
    _ binding: InvestigationMachineGateCoordinatorBinding,
    _ source: InvestigationMachineGateCoordinatorMaterializedSource
  ) throws -> InvestigationMachineGateCoordinatorConfigurationBatch {
    try record(.makeConfigurations)
    makeConfigurationsCallCount += 1
    #expect(binding.sourceFingerprintSHA256 == source.sourceFingerprintSHA256)
    return InvestigationMachineGateCoordinatorConfigurationBatch(
      sourceFingerprintSHA256: sourceFingerprintSHA256,
      configurationSHA256s: configurationSHA256s,
      configurationValidBefore: configurationValidBefore
    )
  }
  private func authorCohort(
    _ configurations: InvestigationMachineGateCoordinatorConfigurationBatch
  ) throws -> InvestigationMachineGateCoordinatorAuthoredCohort {
    try record(.authorCohort)
    authorCohortCallCount += 1
    #expect(configurations.configurationSHA256s.count == 8)
    #expect(configurations.sourceFingerprintSHA256 == sourceFingerprintSHA256)
    return try authoredCohort()
  }
  private func handoff(
    _ cohort: InvestigationMachineGateCoordinatorAuthoredCohort
  ) throws -> InvestigationMachineGateCoordinatorHandoff {
    try record(.handoff)
    handoffCallCount += 1
    #expect(cohort.configurationSHA256s == configurationSHA256s)
    switch failure {
    case .handoffDefinitelyNotSpawned?,
         .handoffAndRetirementUncertain?,
         .handoffAndWriteCloseUncertain?:
      throw InvestigationFixedGateHandoffError.spawnFailedBeforeTransfer
    case .handoffContainmentUncertain?:
      throw InvestigationFixedGateHandoffError.spawnUncertain(processID: 4_101)
    case .handoffAfterSettlementMismatch?:
      throw InvestigationMachineGateCoordinatorProductionError
        .postSettlementProtocolFailure
    default:
      break
    }
    let started = try monotonic.next()
    let completed = try monotonic.next()
    handoffTiming = (started, completed)
    return InvestigationMachineGateCoordinatorHandoff(
      outerAttemptUUID: outerAttemptUUID,
      wholeProjectedInputSHA256: wholeProjectedInputSHA256,
      gateExecutableSHA256: gateExecutableSHA256,
      gateTransportReceiptSHA256: gateTransportReceiptSHA256,
      gateProcessID: 4101, gateProcessGroupID: 4101, gateSessionID: 4001,
      capsule: InvestigationMachineGateNodeObservation(
        device: 1, inode: 2, generation: 3, size: 4_096
      ),
      receiptReachedEOF: true, receiptOverflowObserved: false,
      receiptDeadlineExpired: false, capsuleSettlementRemoved: true,
      monotonicStartedNanoseconds: started,
      monotonicCompletedNanoseconds: completed,
      waitClassification: .exited(status: 0)
    )
  }
  private func retireArtifacts(
    _ source: InvestigationMachineGateCoordinatorMaterializedSource?,
    _ handoff: InvestigationMachineGateCoordinatorHandoff?
  ) throws -> InvestigationMachineGateCoordinatorRetirementOutcome {
    events.append(.retireArtifacts)
    retireArtifactsCallCount += 1
    if handoff != nil { retirementCompletedNanoseconds = try monotonic.next() }
    if case .handoffAndRetirementUncertain = failure {
      throw CoordinatorCompositionProbeError.uncertain(.retireArtifacts)
    }
    return .retired
  }
  private func makeReceipt(
    _ state: InvestigationMachineGateCoordinatorTerminalState
  ) throws -> InvestigationMachineGateCoordinatorReceiptV1 {
    events.append(.makeReceipt)
    makeReceiptCallCount += 1
    return try InvestigationMachineGateCoordinatorReceiptV1(terminal: state)
  }
  private func writeClose(
    _ disposition: InvestigationMachineGateCoordinatorSinkDisposition
  ) throws {
    events.append(.writeClose)
    writeCloseCallCount += 1
    lastSinkDisposition = disposition
    if case .handoffAndWriteCloseUncertain = failure {
      throw CoordinatorCompositionProbeError.uncertain(.writeClose)
    }
    if case .receipt(let receipt) = disposition {
      #expect(receipt.attemptBaseRetired)
      #expect(receipt.runtimeArtifactsRetired)
    }
  }
  private func record(_ stage: CoordinatorCompositionStage) throws {
    events.append(stage)
    if case .ordinary(stage) = failure {
      throw CoordinatorCompositionProbeError.ordinary(stage)
    }
  }
}
private enum CoordinatorClockStep: Sendable { case value(UInt64), failure }
private enum CoordinatorClockFault: CaseIterable, Sendable {
  case startThrow, startZero, startEqual, completionThrow, completionEqual, completionReverse
  var steps: [CoordinatorClockStep] { switch self {
  case .startThrow: [.failure]; case .startZero: [.value(0)]
  case .startEqual: [.value(200), .value(200), .value(300), .value(400), .value(500)]
  case .completionThrow: values(.failure); case .completionEqual: values(.value(300))
  case .completionReverse: values(.value(99))
  } }
  private func values(_ final: CoordinatorClockStep) -> [CoordinatorClockStep] {
    [.value(100), .value(200), .value(300), .value(400), final] }
  var expectedCalls: Int { self == .startThrow || self == .startZero ? 1 : 5 }
}
private final class CoordinatorMonotonicProbe: @unchecked Sendable {
  private let lock = NSLock(); private var value: UInt64 = 100
  private var steps: [CoordinatorClockStep]; private var callCount = 0
  init(_ steps: [CoordinatorClockStep] = []) { self.steps = steps }
  var calls: Int { lock.withLock { callCount } }
  func next() throws -> UInt64 { try lock.withLock { callCount += 1
    if !steps.isEmpty { switch steps.removeFirst() {
    case .value(let value): return value; case .failure: throw CoordinatorRootFault() } }
    value += 1; return value } }
}
private struct CoordinatorRootFault: Error {}
private final class CoordinatorRootBootstrapProbe: @unchecked Sendable {
  private let lock = NSLock(); private var values: (URL?, URL?) = (nil, nil)
  var root: URL? { lock.withLock { values.0 } }
  var backup: URL? { lock.withLock { values.1 } }
  func observe(_ root: URL, backup: URL? = nil) {
    lock.withLock { values = (root, backup ?? values.1) }
  }
}
