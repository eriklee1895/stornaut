import Darwin
import Foundation
import Testing

@testable import StornautInvestigationDiagnostic
@testable import StornautInvestigationHandoffContract
@testable import StornautLifecycle

@Suite("Investigation handoff concrete App adapter")
struct InvestigationHandoffAppLeafAdapterTests {
  @Test
  func peerAdmissionPrecedesBootstrapAndUsesFixedDescriptor() async throws {
    let fixture = try AdapterFixture()
    let adapter = InvestigationHandoffAppLeafAdapter(system: fixture.system)
    let observation = try await adapter.admitPeerAndBootstrap()
    #expect(observation.bootstrap == fixture.bootstrap)
    #expect(observation.driverIdentity == fixture.driverIdentity)
    #expect(observation.signingEvidence == fixture.signingEvidence)
    #expect(
      fixture.calls.values == [
        "peer:7", "admit", "clock", "read:7:32:6000000000", "clock",
      ])
    await #expect(throws: InvestigationHandoffAppLeafAdapterError.alreadyConsumed) {
      _ = try await adapter.admitPeerAndBootstrap()
    }
  }

  @Test
  func bootstrapRejectsPeerDeadlineAndEncodingDrift() async throws {
    let fixture = try AdapterFixture()
    for mutation in [
      AdapterMutation.peerRejected,
      .bootstrap(Data(repeating: 0, count: 32)),
      .clocks([1_000_000_000, fixture.bootstrap.epochDeadlineNanoseconds]),
      .clocks([1_000_000_000, 6_000_000_000]),
      .clocks([1_000_000_000, 999_999_999]),
      .bootstrap(try AdapterFixture.bootstrap(deadline: 141_000_000_001).encoded()),
      .clocks([UInt64.max - 1, UInt64.max - 1]),
    ] {
      let mutated = try AdapterFixture(mutation: mutation)
      let adapter = InvestigationHandoffAppLeafAdapter(system: mutated.system)
      await #expect(throws: (any Error).self) {
        _ = try await adapter.admitPeerAndBootstrap()
      }
      await #expect(
        throws: InvestigationHandoffAppLeafAdapterError.alreadyConsumed
      ) {
        _ = try await adapter.admitPeerAndBootstrap()
      }
    }
  }

  @Test
  func incomingFrameMustMatchDriverEpochAndBecomesTerminalOnDrift()
    async throws
  {
    let fixture = try AdapterFixture()
    let adapter = InvestigationHandoffAppLeafAdapter(system: fixture.system)
    _ = try await adapter.admitPeerAndBootstrap()
    let foreign = try InvestigationHandoffFrame(
      kind: .dropRelease,
      epochUUID: #require(
        UUID(
          uuidString: "00000000-0000-0000-0000-000000000012"
        )),
      epochDeadlineNanoseconds: fixture.bootstrap.epochDeadlineNanoseconds,
      sender: try .init(
        processID: 901, processIDVersion: 11,
        effectiveUserID: 0, auditSessionID: 77_001
      ),
      payload: .empty
    )
    let bytes = try foreign.encoded()
    await fixture.reads.append(contentsOf: [
      Data(bytes.prefix(InvestigationHandoffFrame.headerByteCount)),
      Data(bytes.dropFirst(InvestigationHandoffFrame.headerByteCount)),
    ])
    await #expect(throws: InvestigationHandoffAppLeafAdapterError.transportFailed) {
      _ = try await adapter.readFrame()
    }
    await #expect(throws: InvestigationHandoffAppLeafAdapterError.invalidPeer) {
      _ = try await adapter.readFrame()
    }
  }

  @Test
  func concurrentFrameOperationsMakeTheEpochTerminal() async throws {
    let gate = AdapterReadGate()
    let fixture = try AdapterFixture(readGate: gate)
    let adapter = InvestigationHandoffAppLeafAdapter(system: fixture.system)
    _ = try await adapter.admitPeerAndBootstrap()
    let incoming = try fixture.incomingFrame()
    let bytes = try incoming.encoded()
    await fixture.reads.append(contentsOf: [
      Data(bytes.prefix(InvestigationHandoffFrame.headerByteCount)),
      Data(bytes.dropFirst(InvestigationHandoffFrame.headerByteCount)),
    ])
    let first = Task { try await adapter.readFrame() }
    await gate.waitUntilBlocked()
    await #expect(throws: InvestigationHandoffAppLeafAdapterError.alreadyConsumed) {
      _ = try await adapter.readFrame()
    }
    await gate.release()
    await #expect(throws: InvestigationHandoffAppLeafAdapterError.transportFailed) {
      _ = try await first.value
    }
  }

  @Test(arguments: [false, true])
  func identityDropOverlapWithFrameIOIsTerminal(write: Bool) async throws {
    let gate = AdapterReadGate()
    let fixture = try AdapterFixture(readGate: gate)
    let adapter = InvestigationHandoffAppLeafAdapter(system: fixture.system)
    _ = try await adapter.admitPeerAndBootstrap()
    _ = try await adapter.preDropClaim()
    if !write {
      let bytes = try fixture.incomingFrame().encoded()
      await fixture.reads.append(contentsOf: [
        Data(bytes.prefix(InvestigationHandoffFrame.headerByteCount)),
        Data(bytes.dropFirst(InvestigationHandoffFrame.headerByteCount)),
      ])
    }
    let operation = Task {
      if write { try await adapter.writeFrame(try fixture.outgoingFrame()) }
      else { _ = try await adapter.readFrame() }
    }
    await gate.waitUntilBlocked()
    await #expect(throws: InvestigationHandoffAppLeafAdapterError.alreadyConsumed) {
      _ = try await adapter.performIdentityDrop()
    }
    await gate.release()
    await #expect(throws: InvestigationHandoffAppLeafAdapterError.transportFailed) {
      try await operation.value
    }
    #expect(!fixture.calls.values.contains { $0.hasPrefix("initgroups:") })
  }

  @Test
  func concurrentBootstrapCallsCannotPublishAnObservation() async throws {
    let gate = AdapterReadGate(blockOnCount: 32)
    let fixture = try AdapterFixture(readGate: gate)
    let adapter = InvestigationHandoffAppLeafAdapter(system: fixture.system)
    let first = Task { try await adapter.admitPeerAndBootstrap() }
    await gate.waitUntilBlocked()
    await #expect(throws: InvestigationHandoffAppLeafAdapterError.alreadyConsumed) {
      _ = try await adapter.admitPeerAndBootstrap()
    }
    await gate.release()
    await #expect(throws: InvestigationHandoffAppLeafAdapterError.deadlineExceeded) {
      _ = try await first.value
    }
    await #expect(throws: InvestigationHandoffAppLeafAdapterError.alreadyConsumed) {
      _ = try await adapter.admitPeerAndBootstrap()
    }
  }

  @Test
  func exactFrameIOAndHalfCloseUseEpochDeadline() async throws {
    let fixture = try AdapterFixture()
    let adapter = InvestigationHandoffAppLeafAdapter(system: fixture.system)
    _ = try await adapter.admitPeerAndBootstrap()
    let incoming = try fixture.incomingFrame()
    await fixture.reads.append(
      contentsOf: [
        try incoming.encoded().prefix(
          InvestigationHandoffFrame.headerByteCount
        ),
        try incoming.encoded().dropFirst(
          InvestigationHandoffFrame.headerByteCount
        ),
      ].map { Data($0) })
    #expect(try await adapter.readFrame() == incoming)
    let outgoing = try fixture.outgoingFrame()
    try await adapter.writeFrame(outgoing)
    try await adapter.halfCloseWrite()
    let deadline = fixture.bootstrap.epochDeadlineNanoseconds
    #expect(
      fixture.calls.values.suffix(5) == [
        "read:7:56:\(deadline)",
        "read:7:0:\(deadline)",
        "current-identity",
        "write:7:\((try outgoing.encoded()).count):\(deadline)",
        "shutdown:7",
      ])
    await #expect(throws: InvestigationHandoffAppLeafAdapterError.alreadyConsumed) {
      try await adapter.writeFrame(outgoing)
    }
  }

  @Test
  func fixedIdentityDropProducesExactEvidenceAndOrder() async throws {
    let fixture = try AdapterFixture()
    let adapter = InvestigationHandoffAppLeafAdapter(system: fixture.system)
    _ = try await adapter.admitPeerAndBootstrap()
    let preDrop = try await adapter.preDropClaim()
    let result = try await adapter.performIdentityDrop()
    #expect(preDrop.effectiveUserID == 0)
    #expect(preDrop.processID == result.processClaim.processID)
    #expect(preDrop.processIDVersion == result.processClaim.processIDVersion)
    #expect(preDrop.auditSessionID == result.processClaim.auditSessionID)
    #expect(result.processClaim.processID == 902)
    #expect(result.processClaim.processIDVersion == 12)
    #expect(result.processClaim.effectiveUserID == 501)
    #expect(result.processClaim.auditSessionID == 77_002)
    #expect(result.evidence.supplementaryGroups == fixture.groups.sorted())
    #expect(
      fixture.calls.values.suffix(16)
        == [
          "current-identity", "resolve", "clock", "initgroups:local-user:20",
          "getgroups", "setgid:20",
          "setuid:501", "getresuid", "getresgid", "audit-token",
          "regain-setuid:0", "errno", "regain-seteuid:0", "errno",
          "regain-setgid:0", "errno",
        ].suffix(16))
    await #expect(throws: InvestigationHandoffAppLeafAdapterError.alreadyConsumed) {
      _ = try await adapter.performIdentityDrop()
    }
  }

  @Test(arguments: [UInt64(9_999_999_999), 10_000_000_000, 10_000_000_001])
  func identityDropRequiresLiveEpoch(now: UInt64) async throws {
    let fixture = try AdapterFixture(
      mutation: .clocks([1_000_000_000, 1_000_000_001, now]))
    let adapter = InvestigationHandoffAppLeafAdapter(system: fixture.system)
    _ = try await adapter.admitPeerAndBootstrap()
    _ = try await adapter.preDropClaim()
    if now < fixture.bootstrap.epochDeadlineNanoseconds {
      _ = try await adapter.performIdentityDrop()
      #expect(fixture.calls.values.contains("initgroups:local-user:20"))
    } else {
      await #expect(throws: InvestigationHandoffAppLeafAdapterError.deadlineExceeded) {
        _ = try await adapter.performIdentityDrop()
      }
      #expect(!fixture.calls.values.contains { $0.hasPrefix("initgroups:") })
    }
  }

  @Test
  func identityDropRejectsEveryCriticalFailure() async throws {
    for mutation in [
      AdapterMutation.groups(Array(1...15).map(gid_t.init)),
      .initializeGroupsResult(-1),
      .setGroupIDResult(-1),
      .setUserIDResult(-1),
      .userIDs(.init(real: 0, effective: 501, saved: 501)),
      .groupIDs(.init(real: 0, effective: 20, saved: 20)),
      .regainErrno(0),
    ] {
      let fixture = try AdapterFixture(mutation: mutation)
      let adapter = InvestigationHandoffAppLeafAdapter(system: fixture.system)
      _ = try await adapter.admitPeerAndBootstrap()
      _ = try await adapter.preDropClaim()
      await #expect(throws: (any Error).self) {
        _ = try await adapter.performIdentityDrop()
      }
    }
  }

  @Test
  func reorderedAndDuplicateOperationsPermanentlyConsumeTheEpoch() async throws {
    let reordered = try AdapterFixture()
    let reorderedAdapter = InvestigationHandoffAppLeafAdapter(
      system: reordered.system
    )
    await #expect(throws: InvestigationHandoffAppLeafAdapterError.invalidPeer) {
      _ = try await reorderedAdapter.preDropClaim()
    }
    await #expect(throws: InvestigationHandoffAppLeafAdapterError.alreadyConsumed) {
      _ = try await reorderedAdapter.admitPeerAndBootstrap()
    }

    let duplicate = try AdapterFixture()
    let duplicateAdapter = InvestigationHandoffAppLeafAdapter(
      system: duplicate.system
    )
    _ = try await duplicateAdapter.admitPeerAndBootstrap()
    _ = try await duplicateAdapter.preDropClaim()
    await #expect(throws: InvestigationHandoffAppLeafAdapterError.alreadyConsumed) {
      _ = try await duplicateAdapter.preDropClaim()
    }
    await #expect(throws: InvestigationHandoffAppLeafAdapterError.invalidPeer) {
      _ = try await duplicateAdapter.readFrame()
    }
  }

  @Test
  func physicalSystemUsesPeerTokenAndBoundedSocketIO() async throws {
    let descriptors = try temporarySocketPair()
    defer {
      Darwin.close(descriptors.0)
      Darwin.close(descriptors.1)
    }
    let system = InvestigationHandoffAppLeafAdapterSystem.system
    let peer = try system.peerIdentity(descriptors.0)
    #expect(peer.processID == getpid())
    #expect(peer.processIDVersion > 0)
    #expect(peer.auditSessionID > 0)
    #expect(peer.effectiveUserID == geteuid())
    #expect(peer.auditToken.words.count == 8)
    let deadlineResult = try system.continuousNanoseconds()
      .addingReportingOverflow(5_000_000_000)
    #expect(!deadlineResult.overflow)
    let deadline = deadlineResult.partialValue
    let readTask = Task {
      try await system.readExactly(descriptors.0, 4, deadline)
    }
    try sendPhysical(Data([0x01, 0x02]), to: descriptors.1)
    try sendPhysical(Data([0x03, 0x04]), to: descriptors.1)
    #expect(try await readTask.value == Data([0x01, 0x02, 0x03, 0x04]))
    let outgoing = Data([0x05, 0x06, 0x07])
    try await system.writeExactly(descriptors.0, outgoing, deadline)
    #expect(
      try receivePhysical(count: outgoing.count, from: descriptors.1)
        == outgoing)
    try system.shutdownWrite(descriptors.0)
    var trailing: UInt8 = 0
    #expect(recv(descriptors.1, &trailing, 1, 0) == 0)
  }

  @Test
  func physicalSystemDeadlineAndCancellationFailClosed() async throws {
    let expired = try temporarySocketPair()
    defer {
      Darwin.close(expired.0)
      Darwin.close(expired.1)
    }
    let system = InvestigationHandoffAppLeafAdapterSystem.system
    let now = try system.continuousNanoseconds()
    await #expect(throws: InvestigationHandoffAppLeafAdapterError.deadlineExceeded) {
      _ = try await system.readExactly(expired.0, 1, now)
    }

    let cancelled = try temporarySocketPair()
    defer {
      Darwin.close(cancelled.0)
      Darwin.close(cancelled.1)
    }
    let deadlineResult = try system.continuousNanoseconds()
      .addingReportingOverflow(5_000_000_000)
    #expect(!deadlineResult.overflow)
    let deadline = deadlineResult.partialValue
    let task = Task {
      try await system.readExactly(cancelled.0, 1, deadline)
    }
    await Task.yield()
    task.cancel()
    await #expect(throws: (any Error).self) {
      _ = try await task.value
    }
    #expect(fcntl(expired.0, F_GETFD) >= 0)
  }

  @Test
  func physicalResolutionHasExactlyOneCancellationOrCompletionWinner() async {
    let cancelFirst = InvestigationHandoffPhysicalResolution<Int>()
    #expect(cancelFirst.cancel())
    #expect(!cancelFirst.resolve(.success(7)))
    await #expect(throws: CancellationError.self) {
      try await withCheckedThrowingContinuation { continuation in
        cancelFirst.install(continuation)
      }
    }

    let completeFirst = InvestigationHandoffPhysicalResolution<Int>()
    let value = Task {
      try await withCheckedThrowingContinuation { continuation in
        completeFirst.install(continuation)
      }
    }
    await Task.yield()
    #expect(completeFirst.resolve(.success(9)))
    #expect(!completeFirst.cancel())
    let resolved = try? await value.value
    #expect(resolved == 9)
  }
}

private func temporarySocketPair() throws -> (Int32, Int32) {
  var descriptors = [Int32](repeating: -1, count: 2)
  guard socketpair(AF_UNIX, SOCK_STREAM, 0, &descriptors) == 0 else {
    throw AdapterInjectedFailure()
  }
  return (descriptors[0], descriptors[1])
}

private func sendPhysical(_ data: Data, to descriptor: Int32) throws {
  let sent = data.withUnsafeBytes {
    send(descriptor, $0.baseAddress, $0.count, MSG_NOSIGNAL)
  }
  guard sent == data.count else { throw AdapterInjectedFailure() }
}

private func receivePhysical(count: Int, from descriptor: Int32) throws -> Data {
  var data = Data(count: count)
  let received = data.withUnsafeMutableBytes {
    recv(descriptor, $0.baseAddress, $0.count, 0)
  }
  guard received == count else { throw AdapterInjectedFailure() }
  return data
}

private enum AdapterMutation {
  case none
  case peerRejected
  case bootstrap(Data)
  case clocks([UInt64])
  case groups([gid_t])
  case initializeGroupsResult(Int32)
  case setGroupIDResult(Int32)
  case setUserIDResult(Int32)
  case userIDs(InvestigationHandoffAppLeafUserIDs)
  case groupIDs(InvestigationHandoffAppLeafGroupIDs)
  case regainErrno(Int32)
}

private final class AdapterCalls: @unchecked Sendable {
  private let lock = NSLock()
  private var recorded: [String] = []
  var values: [String] { lock.withLock { recorded } }
  func append(_ value: String) { lock.withLock { recorded.append(value) } }
}

private actor AdapterReads {
  private var values: [Data]
  init(_ values: [Data]) { self.values = values }
  func append(contentsOf newValues: [Data]) { values.append(contentsOf: newValues) }
  func next(count: Int) throws -> Data {
    guard !values.isEmpty else { throw AdapterInjectedFailure() }
    let value = values.removeFirst()
    guard value.count == count else { throw AdapterInjectedFailure() }
    return value
  }
}

private actor AdapterReadGate {
  private let blockOnCount: Int
  private var blocked = false
  private var released = false
  private var blockWaiters: [CheckedContinuation<Void, Never>] = []
  private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

  init(blockOnCount: Int = InvestigationHandoffFrame.headerByteCount) {
    self.blockOnCount = blockOnCount
  }

  func blockOnce(count: Int) async {
    guard count == blockOnCount else { return }
    guard !blocked else { return }
    blocked = true
    blockWaiters.forEach { $0.resume() }
    blockWaiters.removeAll()
    if released { return }
    await withCheckedContinuation { releaseWaiters.append($0) }
  }

  func waitUntilBlocked() async {
    if blocked { return }
    await withCheckedContinuation { blockWaiters.append($0) }
  }

  func release() {
    released = true
    releaseWaiters.forEach { $0.resume() }
    releaseWaiters.removeAll()
  }
}

private final class AdapterClock: @unchecked Sendable {
  private let lock = NSLock()
  private var values: [UInt64]
  init(_ values: [UInt64]) { self.values = values }
  func next() throws -> UInt64 {
    try lock.withLock {
      guard !values.isEmpty else { throw AdapterInjectedFailure() }
      return values.removeFirst()
    }
  }
}

private struct AdapterFixture {
  let calls = AdapterCalls()
  let reads: AdapterReads
  let bootstrap: InvestigationHandoffEpochBootstrap
  let driverIdentity: LifecycleProcessIdentity
  let signingEvidence: LifecycleBundleSigningEvidence
  let groups = Array(gid_t(1)...gid_t(15)) + [20]
  let system: InvestigationHandoffAppLeafAdapterSystem

  init(
    mutation: AdapterMutation = .none,
    readGate: AdapterReadGate? = nil
  ) throws {
    let bootstrapData: Data
    let clocks: [UInt64]
    switch mutation {
    case .bootstrap(let value): bootstrapData = value
    default: bootstrapData = Self.defaultBootstrapData
    }
    switch mutation {
    case .clocks(let value): clocks = value
    default: clocks = [1_000_000_000, 1_000_000_001, 1_000_000_002]
    }
    bootstrap = try Self.bootstrap(deadline: 10_000_000_000)
    driverIdentity = Self.driverIdentity
    signingEvidence = try Self.signingEvidence
    reads = AdapterReads([bootstrapData])
    let calls = calls
    let reads = reads
    let clock = AdapterClock(clocks)
    let selectedGroups: [gid_t]
    if case .groups(let value) = mutation {
      selectedGroups = value
    } else {
      selectedGroups = groups
    }
    let initResult: Int32
    if case .initializeGroupsResult(let value) = mutation {
      initResult = value
    } else {
      initResult = 0
    }
    let gidResult: Int32
    if case .setGroupIDResult(let value) = mutation { gidResult = value } else { gidResult = 0 }
    let uidResult: Int32
    if case .setUserIDResult(let value) = mutation { uidResult = value } else { uidResult = 0 }
    let userIDs: InvestigationHandoffAppLeafUserIDs
    if case .userIDs(let value) = mutation {
      userIDs = value
    } else {
      userIDs = .init(real: 501, effective: 501, saved: 501)
    }
    let groupIDs: InvestigationHandoffAppLeafGroupIDs
    if case .groupIDs(let value) = mutation {
      groupIDs = value
    } else {
      groupIDs = .init(real: 20, effective: 20, saved: 20)
    }
    let regainErrno: Int32
    if case .regainErrno(let value) = mutation { regainErrno = value } else { regainErrno = EPERM }
    let peerRejected: Bool
    if case .peerRejected = mutation { peerRejected = true } else { peerRejected = false }
    let evidence = LifecycleMachineDriverPeerAdmissionEvidence(
      processIdentity: driverIdentity,
      signingEvidence: signingEvidence
    )
    system = InvestigationHandoffAppLeafAdapterSystem(
      peerIdentity: { descriptor in
        calls.append("peer:\(descriptor)")
        return Self.driverIdentity
      },
      admitPeer: { _ in
        calls.append("admit")
        return peerRejected ? nil : evidence
      },
      continuousNanoseconds: {
        calls.append("clock")
        return try clock.next()
      },
      readExactly: { descriptor, count, deadline in
        calls.append("read:\(descriptor):\(count):\(deadline)")
        await readGate?.blockOnce(count: count)
        return try await reads.next(count: count)
      },
      writeExactly: { descriptor, data, deadline in
        calls.append("write:\(descriptor):\(data.count):\(deadline)")
        await readGate?.blockOnce(count: data.count)
      },
      shutdownWrite: { descriptor in
        calls.append("shutdown:\(descriptor)")
      },
      resolveIdentity: {
        calls.append("resolve")
        return try InvestigationHandoffAppLeafResolvedIdentity(
          username: "local-user", userID: 501, groupID: 20,
          selectedGroups: selectedGroups
        )
      },
      initializeGroups: { username, groupID in
        calls.append("initgroups:\(username):\(groupID)")
        return initResult
      },
      supplementaryGroups: {
        calls.append("getgroups")
        return selectedGroups
      },
      setGroupID: { value in
        calls.append("setgid:\(value)")
        return gidResult
      },
      setUserID: { value in
        calls.append("setuid:\(value)")
        return uidResult
      },
      userIDs: {
        calls.append("getresuid")
        return userIDs
      },
      groupIDs: {
        calls.append("getresgid")
        return groupIDs
      },
      currentProcessIdentity: {
        calls.append("current-identity")
        return LifecycleProcessIdentity(
          processID: 902,
          processIDVersion: 12,
          auditSessionID: 77_002,
          effectiveUserID: 0,
          auditToken: try .init(words: [
            0, 0, 0, 0, 0, 902, 77_002, 12,
          ])
        )
      },
      auditTokenWords: {
        calls.append("audit-token")
        return [501, 501, 20, 501, 20, 902, 77_002, 12]
      },
      attemptSetUserID: { value in
        calls.append("regain-setuid:\(value)")
        return -1
      },
      attemptSetEffectiveUserID: { value in
        calls.append("regain-seteuid:\(value)")
        return -1
      },
      attemptSetGroupID: { value in
        calls.append("regain-setgid:\(value)")
        return -1
      },
      errnoValue: {
        calls.append("errno")
        return regainErrno
      }
    )
  }

  func incomingFrame() throws -> InvestigationHandoffFrame {
    try InvestigationHandoffFrame(
      kind: .dropRelease,
      epochUUID: bootstrap.epochUUID,
      epochDeadlineNanoseconds: bootstrap.epochDeadlineNanoseconds,
      sender: try .init(
        processID: 901, processIDVersion: 11,
        effectiveUserID: 0, auditSessionID: 77_001
      ),
      payload: .empty
    )
  }

  func outgoingFrame() throws -> InvestigationHandoffFrame {
    try InvestigationHandoffFrame(
      kind: .preDropReady,
      epochUUID: bootstrap.epochUUID,
      epochDeadlineNanoseconds: bootstrap.epochDeadlineNanoseconds,
      sender: try .init(
        processID: 902, processIDVersion: 12,
        effectiveUserID: 0, auditSessionID: 77_002
      ),
      payload: .empty
    )
  }

  static func bootstrap(deadline: UInt64) throws
    -> InvestigationHandoffEpochBootstrap
  {
    try .init(
      epochUUID: #require(
        UUID(
          uuidString: "00000000-0000-0000-0000-000000000011"
        )),
      epochDeadlineNanoseconds: deadline
    )
  }

  static let defaultBootstrapData = try! bootstrap(
    deadline: 10_000_000_000
  ).encoded()

  static let driverIdentity = LifecycleProcessIdentity(
    processID: 901,
    processIDVersion: 11,
    auditSessionID: 77_001,
    effectiveUserID: 0,
    auditToken: try! .init(words: [0, 0, 0, 0, 0, 901, 77_001, 11])
  )

  static var signingEvidence: LifecycleBundleSigningEvidence {
    get throws {
      try .init(
        identity: .init(
          signingIdentifier:
            "com.eriklee.stornaut.investigation.machine-driver",
          designatedRequirementSHA256: String(repeating: "a", count: 64),
          codeDirectoryHash: String(repeating: "b", count: 40)
        ),
        executableSHA256: String(repeating: "c", count: 64),
        isAdHoc: true
      )
    }
  }
}

private struct AdapterInjectedFailure: Error {}
