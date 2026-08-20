#if DEBUG
  import Darwin
  import Foundation
  import StornautInvestigationHandoffContract
  import StornautLifecycle

  package enum InvestigationHandoffAppLeafAdapterError:
    Error,
    Sendable,
    Equatable
  {
    case alreadyConsumed
    case invalidPeer
    case invalidBootstrap
    case deadlineExceeded
    case transportFailed
    case identityDropFailed
    case invalidDropEvidence
  }

  package struct InvestigationHandoffAppLeafPeerObservation:
    Sendable,
    Equatable
  {
    package let bootstrap: InvestigationHandoffEpochBootstrap
    package let driverIdentity: LifecycleProcessIdentity
    package let driverClaim: InvestigationHandoffProcessClaim
    package let signingEvidence: LifecycleBundleSigningEvidence
  }

  package struct InvestigationHandoffAppLeafAdapterSystem: Sendable {
    package let peerIdentity: @Sendable (Int32) throws -> LifecycleProcessIdentity
    package let admitPeer:
      @Sendable (LifecycleProcessIdentity)
        -> LifecycleMachineDriverPeerAdmissionEvidence?
    package let continuousNanoseconds: @Sendable () throws -> UInt64
    package let readExactly: @Sendable (Int32, Int, UInt64) async throws -> Data
    package let writeExactly: @Sendable (Int32, Data, UInt64) async throws -> Void
    package let shutdownWrite: @Sendable (Int32) throws -> Void
    package let resolveIdentity: @Sendable () throws -> InvestigationHandoffAppLeafResolvedIdentity
    package let initializeGroups: @Sendable (String, gid_t) -> Int32
    package let supplementaryGroups: @Sendable () throws -> [gid_t]
    package let setGroupID: @Sendable (gid_t) -> Int32
    package let setUserID: @Sendable (uid_t) -> Int32
    package let userIDs: @Sendable () throws -> InvestigationHandoffAppLeafUserIDs
    package let groupIDs: @Sendable () throws -> InvestigationHandoffAppLeafGroupIDs
    package let currentProcessIdentity: @Sendable () throws -> LifecycleProcessIdentity
    package let auditTokenWords: @Sendable () throws -> [UInt32]
    package let attemptSetUserID: @Sendable (uid_t) -> Int32
    package let attemptSetEffectiveUserID: @Sendable (uid_t) -> Int32
    package let attemptSetGroupID: @Sendable (gid_t) -> Int32
    package let errnoValue: @Sendable () -> Int32

    package init(
      peerIdentity:
        @escaping @Sendable (Int32) throws -> LifecycleProcessIdentity,
      admitPeer:
        @escaping @Sendable (LifecycleProcessIdentity)
        -> LifecycleMachineDriverPeerAdmissionEvidence?,
      continuousNanoseconds: @escaping @Sendable () throws -> UInt64,
      readExactly:
        @escaping @Sendable (Int32, Int, UInt64) async throws -> Data,
      writeExactly:
        @escaping @Sendable (Int32, Data, UInt64) async throws -> Void,
      shutdownWrite: @escaping @Sendable (Int32) throws -> Void,
      resolveIdentity:
        @escaping @Sendable () throws
        -> InvestigationHandoffAppLeafResolvedIdentity,
      initializeGroups: @escaping @Sendable (String, gid_t) -> Int32,
      supplementaryGroups: @escaping @Sendable () throws -> [gid_t],
      setGroupID: @escaping @Sendable (gid_t) -> Int32,
      setUserID: @escaping @Sendable (uid_t) -> Int32,
      userIDs:
        @escaping @Sendable () throws -> InvestigationHandoffAppLeafUserIDs,
      groupIDs:
        @escaping @Sendable () throws -> InvestigationHandoffAppLeafGroupIDs,
      currentProcessIdentity:
        @escaping @Sendable () throws -> LifecycleProcessIdentity,
      auditTokenWords: @escaping @Sendable () throws -> [UInt32],
      attemptSetUserID: @escaping @Sendable (uid_t) -> Int32,
      attemptSetEffectiveUserID: @escaping @Sendable (uid_t) -> Int32,
      attemptSetGroupID: @escaping @Sendable (gid_t) -> Int32,
      errnoValue: @escaping @Sendable () -> Int32
    ) {
      self.peerIdentity = peerIdentity
      self.admitPeer = admitPeer
      self.continuousNanoseconds = continuousNanoseconds
      self.readExactly = readExactly
      self.writeExactly = writeExactly
      self.shutdownWrite = shutdownWrite
      self.resolveIdentity = resolveIdentity
      self.initializeGroups = initializeGroups
      self.supplementaryGroups = supplementaryGroups
      self.setGroupID = setGroupID
      self.setUserID = setUserID
      self.userIDs = userIDs
      self.groupIDs = groupIDs
      self.currentProcessIdentity = currentProcessIdentity
      self.auditTokenWords = auditTokenWords
      self.attemptSetUserID = attemptSetUserID
      self.attemptSetEffectiveUserID = attemptSetEffectiveUserID
      self.attemptSetGroupID = attemptSetGroupID
      self.errnoValue = errnoValue
    }

    package static let system = Self(
      peerIdentity: investigationHandoffPeerIdentity,
      admitPeer: {
        LifecycleMachineDriverAdmissionPolicy()
          .authorizeAndObserveStableEvidence($0)
      },
      continuousNanoseconds: investigationHandoffContinuousNanoseconds,
      readExactly: { descriptor, count, deadline in
        try await InvestigationHandoffPhysicalIO.readExactly(
          descriptor: descriptor,
          count: count,
          deadlineNanoseconds: deadline
        )
      },
      writeExactly: { descriptor, data, deadline in
        try await InvestigationHandoffPhysicalIO.writeExactly(
          descriptor: descriptor,
          data: data,
          deadlineNanoseconds: deadline
        )
      },
      shutdownWrite: { descriptor in
        guard shutdown(descriptor, SHUT_WR) == 0 else {
          throw InvestigationHandoffAppLeafAdapterError.transportFailed
        }
      },
      resolveIdentity: investigationHandoffResolveIdentity,
      initializeGroups: { username, groupID in
        initgroups(username, Int32(groupID))
      },
      supplementaryGroups: investigationHandoffSupplementaryGroups,
      setGroupID: Darwin.setgid,
      setUserID: Darwin.setuid,
      userIDs: {
        let information = try investigationHandoffCurrentBSDInfo()
        return .init(
          real: information.pbi_ruid,
          effective: information.pbi_uid,
          saved: information.pbi_svuid
        )
      },
      groupIDs: {
        let information = try investigationHandoffCurrentBSDInfo()
        return .init(
          real: information.pbi_rgid,
          effective: information.pbi_gid,
          saved: information.pbi_svgid
        )
      },
      currentProcessIdentity: {
        try DarwinLifecycleInventory().identity(for: getpid())
      },
      auditTokenWords: investigationHandoffCurrentAuditTokenWords,
      attemptSetUserID: Darwin.setuid,
      attemptSetEffectiveUserID: Darwin.seteuid,
      attemptSetGroupID: Darwin.setgid,
      errnoValue: { Darwin.errno }
    )
  }

  package struct InvestigationHandoffAppLeafResolvedIdentity:
    Sendable,
    Equatable
  {
    package let username: String
    package let userID: uid_t
    package let groupID: gid_t
    package let selectedGroups: [gid_t]

    package init(
      username: String,
      userID: uid_t,
      groupID: gid_t,
      selectedGroups: [gid_t]
    ) throws {
      guard
        !username.isEmpty,
        username.utf8.count <= 255,
        userID == 501,
        groupID == 20,
        selectedGroups.count == 16,
        Set(selectedGroups).count == selectedGroups.count,
        selectedGroups.contains(groupID)
      else {
        throw InvestigationHandoffAppLeafAdapterError.invalidDropEvidence
      }
      self.username = username
      self.userID = userID
      self.groupID = groupID
      self.selectedGroups = selectedGroups
    }
  }

  package struct InvestigationHandoffAppLeafUserIDs: Sendable, Equatable {
    package let real: uid_t
    package let effective: uid_t
    package let saved: uid_t
  }

  package struct InvestigationHandoffAppLeafGroupIDs: Sendable, Equatable {
    package let real: gid_t
    package let effective: gid_t
    package let saved: gid_t
  }

  package actor InvestigationHandoffAppLeafAdapter {
    package static let fixedDescriptor: Int32 = 7
    package static let bootstrapWindowNanoseconds: UInt64 = 5_000_000_000
    package static let maximumEpochWindowNanoseconds: UInt64 = 140_000_000_000

    private let system: InvestigationHandoffAppLeafAdapterSystem
    private var peerObservation: InvestigationHandoffAppLeafPeerObservation?
    private var preDropProcessClaim: InvestigationHandoffProcessClaim?
    private var bootstrapAttempted = false
    private var terminalFailure = false
    private var ioInProgress = false
    private var didDropIdentity = false
    private var didHalfClose = false

    package init(system: InvestigationHandoffAppLeafAdapterSystem) {
      self.system = system
    }

    package func admitPeerAndBootstrap() async throws
      -> InvestigationHandoffAppLeafPeerObservation
    {
      guard !bootstrapAttempted, !terminalFailure else {
      terminalFailure = true
        throw InvestigationHandoffAppLeafAdapterError.alreadyConsumed
      }
      bootstrapAttempted = true
      do {
        return try await executePeerAndBootstrap()
    } catch let error as InvestigationHandoffAppLeafAdapterError {
        terminalFailure = true
        throw error
    } catch {
      terminalFailure = true
      throw InvestigationHandoffAppLeafAdapterError.invalidBootstrap
      }
    }

    private func executePeerAndBootstrap() async throws
      -> InvestigationHandoffAppLeafPeerObservation
    {
      let identity: LifecycleProcessIdentity
      let admitted: LifecycleMachineDriverPeerAdmissionEvidence
      do {
        identity = try system.peerIdentity(Self.fixedDescriptor)
        guard let value = system.admitPeer(identity) else {
          throw InvestigationHandoffAppLeafAdapterError.invalidPeer
        }
        admitted = value
      } catch let error as InvestigationHandoffAppLeafAdapterError {
        throw error
      } catch {
        throw InvestigationHandoffAppLeafAdapterError.invalidPeer
      }
      guard
        identity.effectiveUserID == 0,
        admitted.processIdentity == identity
      else {
        throw InvestigationHandoffAppLeafAdapterError.invalidPeer
      }

      let startedAt = try system.continuousNanoseconds()
      let bootstrapDeadline = startedAt.addingReportingOverflow(
        Self.bootstrapWindowNanoseconds
      )
      guard !bootstrapDeadline.overflow else {
        throw InvestigationHandoffAppLeafAdapterError.invalidBootstrap
      }
      let bytes: Data
      do {
        bytes = try await system.readExactly(
          Self.fixedDescriptor,
          InvestigationHandoffEpochBootstrap.byteCount,
          bootstrapDeadline.partialValue
        )
      } catch {
        throw InvestigationHandoffAppLeafAdapterError.transportFailed
      }
      let bootstrap: InvestigationHandoffEpochBootstrap
      do {
        bootstrap = try InvestigationHandoffEpochBootstrap.decode(bytes)
      } catch {
        throw InvestigationHandoffAppLeafAdapterError.invalidBootstrap
      }
      let observedAt = try system.continuousNanoseconds()
      let maximumDeadline = startedAt.addingReportingOverflow(
        Self.maximumEpochWindowNanoseconds
      )
      guard
      !terminalFailure,
        !maximumDeadline.overflow,
        observedAt >= startedAt,
        observedAt < bootstrapDeadline.partialValue,
        observedAt < bootstrap.epochDeadlineNanoseconds,
        bootstrap.epochDeadlineNanoseconds <= maximumDeadline.partialValue
      else {
        throw InvestigationHandoffAppLeafAdapterError.deadlineExceeded
      }
      let observation = InvestigationHandoffAppLeafPeerObservation(
        bootstrap: bootstrap,
        driverIdentity: identity,
        driverClaim: try processClaim(identity),
        signingEvidence: admitted.signingEvidence
      )
      peerObservation = observation
      return observation
    }

    package func readFrame() async throws -> InvestigationHandoffFrame {
      let observation = try requirePeerObservation()
      try beginIO()
      defer { ioInProgress = false }
      do {
        let header = try await system.readExactly(
          Self.fixedDescriptor,
          InvestigationHandoffFrame.headerByteCount,
          observation.bootstrap.epochDeadlineNanoseconds
        )
        guard header.count == InvestigationHandoffFrame.headerByteCount else {
          throw InvestigationHandoffAppLeafAdapterError.transportFailed
        }
        let payloadCount = header.withUnsafeBytes { bytes -> UInt32 in
          bytes.loadUnaligned(fromByteOffset: 8, as: UInt32.self).bigEndian
        }
        guard payloadCount <= 65_536 else {
          throw InvestigationHandoffAppLeafAdapterError.transportFailed
        }
        let payload = try await system.readExactly(
          Self.fixedDescriptor,
          Int(payloadCount),
          observation.bootstrap.epochDeadlineNanoseconds
        )
        let frame = try InvestigationHandoffFrame.decode(header + payload)
        guard
          !terminalFailure,
          frame.kind.direction == .driverToApp,
          frame.epochUUID == observation.bootstrap.epochUUID,
          frame.epochDeadlineNanoseconds
            == observation.bootstrap.epochDeadlineNanoseconds,
          frame.sender == observation.driverClaim
        else {
          throw InvestigationHandoffAppLeafAdapterError.transportFailed
        }
        return frame
      } catch {
        terminalFailure = true
        if let error = error as? InvestigationHandoffAppLeafAdapterError {
          throw error
        }
        throw InvestigationHandoffAppLeafAdapterError.transportFailed
      }
    }

    package func writeFrame(_ frame: InvestigationHandoffFrame) async throws {
      let observation = try requirePeerObservation()
      guard !didHalfClose else {
        terminalFailure = true
        throw InvestigationHandoffAppLeafAdapterError.alreadyConsumed
      }
      try beginIO()
      defer { ioInProgress = false }
      do {
        let currentClaim = try processClaim(system.currentProcessIdentity())
        guard
          frame.kind.direction == .appToDriver,
          frame.epochUUID == observation.bootstrap.epochUUID,
          frame.epochDeadlineNanoseconds
            == observation.bootstrap.epochDeadlineNanoseconds,
          frame.sender == currentClaim
        else {
          throw InvestigationHandoffAppLeafAdapterError.transportFailed
        }
        try await system.writeExactly(
          Self.fixedDescriptor,
          frame.encoded(),
          observation.bootstrap.epochDeadlineNanoseconds
        )
        guard !terminalFailure else {
          throw InvestigationHandoffAppLeafAdapterError.transportFailed
        }
      } catch {
        terminalFailure = true
        throw InvestigationHandoffAppLeafAdapterError.transportFailed
      }
    }

    package func performIdentityDrop() throws
      -> InvestigationHandoffAppLeafDropResult
    {
      guard
        !terminalFailure,
        !ioInProgress,
        let peerObservation,
        let preDropProcessClaim,
        !didDropIdentity
      else {
        terminalFailure = true
        throw InvestigationHandoffAppLeafAdapterError.alreadyConsumed
      }
      didDropIdentity = true
      do {
        let identity = try system.resolveIdentity()
        guard try system.continuousNanoseconds()
          < peerObservation.bootstrap.epochDeadlineNanoseconds
        else { throw InvestigationHandoffAppLeafAdapterError.deadlineExceeded }
        guard system.initializeGroups(identity.username, identity.groupID) == 0
        else { throw InvestigationHandoffAppLeafAdapterError.identityDropFailed }
        let actualGroups = try system.supplementaryGroups()
        guard
          actualGroups.count == 16,
          Set(actualGroups).count == actualGroups.count,
          actualGroups.sorted() == identity.selectedGroups.sorted(),
          system.setGroupID(identity.groupID) == 0,
          system.setUserID(identity.userID) == 0
        else { throw InvestigationHandoffAppLeafAdapterError.identityDropFailed }

        let users = try system.userIDs()
        let groups = try system.groupIDs()
        let tokenWords = try system.auditTokenWords()
        guard
          users
            == InvestigationHandoffAppLeafUserIDs(
              real: 501, effective: 501, saved: 501
            ),
          groups
            == InvestigationHandoffAppLeafGroupIDs(
              real: 20, effective: 20, saved: 20
            ),
          tokenWords.count == 8
        else { throw InvestigationHandoffAppLeafAdapterError.invalidDropEvidence }

        let regainUser = regainErrno { system.attemptSetUserID(0) }
        guard regainUser == EPERM else {
          throw InvestigationHandoffAppLeafAdapterError.invalidDropEvidence
        }
        let regainEffective = regainErrno {
          system.attemptSetEffectiveUserID(0)
        }
        guard regainEffective == EPERM else {
          throw InvestigationHandoffAppLeafAdapterError.invalidDropEvidence
        }
        let regainGroup = regainErrno { system.attemptSetGroupID(0) }
        guard regainGroup == EPERM else {
          throw InvestigationHandoffAppLeafAdapterError.invalidDropEvidence
        }

        let claim = try InvestigationHandoffProcessClaim(
          processID: tokenWords[5],
          processIDVersion: tokenWords[7],
          effectiveUserID: tokenWords[1],
          auditSessionID: tokenWords[6]
        )
        guard
          claim.processID == preDropProcessClaim.processID,
          claim.processIDVersion == preDropProcessClaim.processIDVersion,
          claim.auditSessionID == preDropProcessClaim.auditSessionID
        else {
          throw InvestigationHandoffAppLeafAdapterError.invalidDropEvidence
        }
        let evidence = try InvestigationHandoffDropEvidence(
          realUserID: UInt32(users.real),
          effectiveUserID: UInt32(users.effective),
          savedUserID: UInt32(users.saved),
          realGroupID: UInt32(groups.real),
          effectiveGroupID: UInt32(groups.effective),
          savedGroupID: UInt32(groups.saved),
          supplementaryGroups: actualGroups.sorted().map { UInt32($0) },
          auditTokenWords: tokenWords,
          setuidRootErrno: UInt32(regainUser),
          seteuidRootErrno: UInt32(regainEffective),
          setgidRootErrno: UInt32(regainGroup)
        )
        return try InvestigationHandoffAppLeafDropResult(
          processClaim: claim,
          evidence: evidence
        )
      } catch let error as InvestigationHandoffAppLeafAdapterError {
        terminalFailure = true
        throw error
      } catch {
        terminalFailure = true
        throw InvestigationHandoffAppLeafAdapterError.invalidDropEvidence
      }
    }

    package func preDropClaim() throws -> InvestigationHandoffProcessClaim {
      _ = try requirePeerObservation()
      guard !didDropIdentity, preDropProcessClaim == nil else {
      terminalFailure = true
        throw InvestigationHandoffAppLeafAdapterError.alreadyConsumed
      }
      do {
        let identity = try system.currentProcessIdentity()
        guard identity.effectiveUserID == 0 else {
          throw InvestigationHandoffAppLeafAdapterError.invalidPeer
        }
        let claim = try processClaim(identity)
        preDropProcessClaim = claim
        return claim
      } catch let error as InvestigationHandoffAppLeafAdapterError {
        terminalFailure = true
        throw error
      } catch {
        terminalFailure = true
        throw InvestigationHandoffAppLeafAdapterError.invalidPeer
      }
    }

    package func halfCloseWrite() throws {
      _ = try requirePeerObservation()
      guard !didHalfClose, !ioInProgress else {
        terminalFailure = true
        throw InvestigationHandoffAppLeafAdapterError.alreadyConsumed
      }
      didHalfClose = true
      do {
        try system.shutdownWrite(Self.fixedDescriptor)
      } catch {
        terminalFailure = true
        throw InvestigationHandoffAppLeafAdapterError.transportFailed
      }
    }

    private func requirePeerObservation() throws
      -> InvestigationHandoffAppLeafPeerObservation
    {
      guard !terminalFailure, let peerObservation else {
      terminalFailure = true
        throw InvestigationHandoffAppLeafAdapterError.invalidPeer
      }
      return peerObservation
    }

    private func regainErrno(_ operation: () -> Int32) -> Int32 {
      guard operation() != 0 else { return 0 }
      return system.errnoValue()
    }

    private func beginIO() throws {
      guard !ioInProgress else {
        terminalFailure = true
        throw InvestigationHandoffAppLeafAdapterError.alreadyConsumed
      }
      ioInProgress = true
    }

    private func processClaim(
      _ identity: LifecycleProcessIdentity
    ) throws -> InvestigationHandoffProcessClaim {
      guard
        let processID = UInt32(exactly: identity.processID),
        let processIDVersion = UInt32(exactly: identity.processIDVersion),
        let effectiveUserID = UInt32(exactly: identity.effectiveUserID),
        let auditSessionID = UInt32(exactly: identity.auditSessionID)
      else {
        throw InvestigationHandoffAppLeafAdapterError.invalidPeer
      }
      return try InvestigationHandoffProcessClaim(
        processID: processID,
        processIDVersion: processIDVersion,
        effectiveUserID: effectiveUserID,
        auditSessionID: auditSessionID
      )
    }
  }

  private enum InvestigationHandoffPhysicalIO {
    private static let queue = DispatchQueue(
      label: "com.eriklee.stornaut.investigation-handoff-io"
    )

    static func readExactly(
      descriptor: Int32,
      count: Int,
      deadlineNanoseconds: UInt64
    ) async throws -> Data {
      guard count >= 0 else {
        throw InvestigationHandoffAppLeafAdapterError.transportFailed
      }
      let resolution = InvestigationHandoffPhysicalResolution<Data>()
      return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
          resolution.install(continuation)
          guard !Task.isCancelled else {
            if resolution.cancel() { _ = shutdown(descriptor, SHUT_RDWR) }
            return
          }
          queue.async {
            resolution.resolve(
              Result {
                try blockingRead(
                  descriptor: descriptor,
                  count: count,
                  deadlineNanoseconds: deadlineNanoseconds
                )
              })
          }
        }
      } onCancel: {
        if resolution.cancel() { _ = shutdown(descriptor, SHUT_RDWR) }
      }
    }

    static func writeExactly(
      descriptor: Int32,
      data: Data,
      deadlineNanoseconds: UInt64
    ) async throws {
      let resolution = InvestigationHandoffPhysicalResolution<Void>()
      try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
          resolution.install(continuation)
          guard !Task.isCancelled else {
            if resolution.cancel() { _ = shutdown(descriptor, SHUT_RDWR) }
            return
          }
          queue.async {
            resolution.resolve(
              Result {
                try blockingWrite(
                  descriptor: descriptor,
                  data: data,
                  deadlineNanoseconds: deadlineNanoseconds
                )
              })
          }
        }
      } onCancel: {
        if resolution.cancel() { _ = shutdown(descriptor, SHUT_RDWR) }
      }
    }

    private static func blockingRead(
      descriptor: Int32,
      count: Int,
      deadlineNanoseconds: UInt64
    ) throws -> Data {
      var result = Data(count: count)
      if count == 0 { return result }
      var offset = 0
      while offset < count {
        try wait(
          descriptor: descriptor,
          events: Int16(POLLIN | POLLHUP),
          deadlineNanoseconds: deadlineNanoseconds
        )
        let readCount = result.withUnsafeMutableBytes { bytes in
          recv(
            descriptor,
            bytes.baseAddress?.advanced(by: offset),
            count - offset,
            MSG_DONTWAIT
          )
        }
        if readCount > 0 {
          offset += readCount
          continue
        }
        if readCount == 0 {
          throw InvestigationHandoffAppLeafAdapterError.transportFailed
        }
        if errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK {
          continue
        }
        throw InvestigationHandoffAppLeafAdapterError.transportFailed
      }
      return result
    }

    private static func blockingWrite(
      descriptor: Int32,
      data: Data,
      deadlineNanoseconds: UInt64
    ) throws {
      try data.withUnsafeBytes { bytes in
        var offset = 0
        while offset < bytes.count {
          try wait(
            descriptor: descriptor,
            events: Int16(POLLOUT | POLLHUP),
            deadlineNanoseconds: deadlineNanoseconds
          )
          let written = send(
            descriptor,
            bytes.baseAddress?.advanced(by: offset),
            bytes.count - offset,
            MSG_DONTWAIT | MSG_NOSIGNAL
          )
          if written > 0 {
            offset += written
            continue
          }
          if written < 0,
            errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK
          {
            continue
          }
          throw InvestigationHandoffAppLeafAdapterError.transportFailed
        }
      }
    }

    private static func wait(
      descriptor: Int32,
      events: Int16,
      deadlineNanoseconds: UInt64
    ) throws {
      while true {
        let now = try investigationHandoffContinuousNanoseconds()
        guard now < deadlineNanoseconds else {
          throw InvestigationHandoffAppLeafAdapterError.deadlineExceeded
        }
        let remaining = deadlineNanoseconds - now
        let milliseconds = Int32(
          min(
            max(1, min(remaining / 1_000_000, 50)),
            UInt64(Int32.max)
          ))
        var value = pollfd(fd: descriptor, events: events, revents: 0)
        let result = poll(&value, 1, milliseconds)
        if result == 0 { continue }
        if result < 0 {
          if errno == EINTR { continue }
          throw InvestigationHandoffAppLeafAdapterError.transportFailed
        }
        guard value.revents & events != 0 else {
          throw InvestigationHandoffAppLeafAdapterError.transportFailed
        }
        guard try investigationHandoffContinuousNanoseconds()
          < deadlineNanoseconds
        else {
          throw InvestigationHandoffAppLeafAdapterError.deadlineExceeded
        }
        return
      }
    }
  }

  package final class InvestigationHandoffPhysicalResolution<Value: Sendable>:
    @unchecked Sendable
  {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, any Error>?
    private var pendingResult: Result<Value, any Error>?
    private var resolved = false

    func install(_ continuation: CheckedContinuation<Value, any Error>) {
      let result = lock.withLock { () -> Result<Value, any Error>? in
        if resolved { return pendingResult }
        self.continuation = continuation
        return nil
      }
      if let result { continuation.resume(with: result) }
    }

    @discardableResult
    func resolve(_ result: Result<Value, any Error>) -> Bool {
      let state = lock.withLock {
        () -> (Bool, CheckedContinuation<Value, any Error>?) in
        guard !resolved else { return (false, nil) }
        resolved = true
        pendingResult = result
        let continuation = self.continuation
        self.continuation = nil
        return (true, continuation)
      }
      state.1?.resume(with: result)
      return state.0
    }

    @discardableResult
    func cancel() -> Bool {
      resolve(.failure(CancellationError()))
    }
  }

  private func investigationHandoffPeerIdentity(
    descriptor: Int32
  ) throws -> LifecycleProcessIdentity {
    var token = audit_token_t()
    var length = socklen_t(MemoryLayout<audit_token_t>.size)
    guard
      getsockopt(
        descriptor,
        SOL_LOCAL,
        LOCAL_PEERTOKEN,
        &token,
        &length
      ) == 0,
      length == MemoryLayout<audit_token_t>.size
    else {
      throw InvestigationHandoffAppLeafAdapterError.invalidPeer
    }
    let words = withUnsafeBytes(of: token) {
      Array($0.bindMemory(to: UInt32.self))
    }
    return LifecycleProcessIdentity(
      processID: audit_token_to_pid(token),
      processIDVersion: audit_token_to_pidversion(token),
      auditSessionID: audit_token_to_asid(token),
      effectiveUserID: audit_token_to_euid(token),
      auditToken: try LifecycleAuditToken(words: words)
    )
  }

  private func investigationHandoffContinuousNanoseconds() throws -> UInt64 {
    var timebase = mach_timebase_info_data_t()
    guard
      mach_timebase_info(&timebase) == KERN_SUCCESS,
      timebase.denom > 0
    else {
      throw InvestigationHandoffAppLeafAdapterError.deadlineExceeded
    }
    let ticks = mach_continuous_time()
    let product = ticks.multipliedFullWidth(by: UInt64(timebase.numer))
    guard product.high < UInt64(timebase.denom) else {
      throw InvestigationHandoffAppLeafAdapterError.deadlineExceeded
    }
    let division = UInt64(timebase.denom).dividingFullWidth(product)
    guard division.remainder < UInt64(timebase.denom) else {
      throw InvestigationHandoffAppLeafAdapterError.deadlineExceeded
    }
    return division.quotient
  }

  private func investigationHandoffResolveIdentity() throws
    -> InvestigationHandoffAppLeafResolvedIdentity
  {
    let targetUserID: uid_t = 501
    var record = passwd()
    var result: UnsafeMutablePointer<passwd>?
    var capacity = 1_024
    while capacity <= 64 * 1_024 {
      var buffer = [CChar](repeating: 0, count: capacity)
      let status = getpwuid_r(
        targetUserID,
        &record,
        &buffer,
        buffer.count,
        &result
      )
      if status == ERANGE {
        capacity *= 2
        continue
      }
      guard
        status == 0,
        result != nil,
        record.pw_uid == 501,
        record.pw_gid == 20,
        let namePointer = record.pw_name
      else {
        throw InvestigationHandoffAppLeafAdapterError.identityDropFailed
      }
      let username = String(cString: namePointer)
      var groups = [gid_t](repeating: 0, count: 64)
      var groupCount = Int32(groups.count)
      guard
        getgrouplist(
          username,
          Int32(record.pw_gid),
          &groups,
          &groupCount
        ) >= 0,
        groupCount == 17,
        Set(groups.prefix(Int(groupCount))).count == Int(groupCount),
        NGROUPS_MAX == 16
      else {
        throw InvestigationHandoffAppLeafAdapterError.identityDropFailed
      }
      return try InvestigationHandoffAppLeafResolvedIdentity(
        username: username,
        userID: record.pw_uid,
        groupID: record.pw_gid,
        selectedGroups: Array(groups.prefix(16))
      )
    }
    throw InvestigationHandoffAppLeafAdapterError.identityDropFailed
  }

  private func investigationHandoffSupplementaryGroups() throws -> [gid_t] {
    let count = getgroups(0, nil)
    guard count == 16 else {
      throw InvestigationHandoffAppLeafAdapterError.invalidDropEvidence
    }
    var groups = [gid_t](repeating: 0, count: Int(count))
    guard getgroups(count, &groups) == count else {
      throw InvestigationHandoffAppLeafAdapterError.invalidDropEvidence
    }
    return groups
  }

  private func investigationHandoffCurrentAuditTokenWords() throws -> [UInt32] {
    guard let identity = try? DarwinLifecycleInventory().identity(for: getpid())
    else {
      throw InvestigationHandoffAppLeafAdapterError.invalidDropEvidence
    }
    return identity.auditToken.words
  }

  private func investigationHandoffCurrentBSDInfo() throws -> proc_bsdinfo {
    var information = proc_bsdinfo()
    let byteCount = proc_pidinfo(
      getpid(),
      PROC_PIDTBSDINFO,
      0,
      &information,
      Int32(MemoryLayout<proc_bsdinfo>.size)
    )
    guard byteCount == MemoryLayout<proc_bsdinfo>.size else {
      throw InvestigationHandoffAppLeafAdapterError.invalidDropEvidence
    }
    return information
  }
#endif
