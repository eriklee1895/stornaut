import Foundation

package struct InvestigationGeneralProcessIdentityV1: Sendable, Equatable {
  package static let supplementaryGroupCapacity = 16

  package let processID: UInt32
  package let processIDVersion: UInt32
  package let startSeconds: Int64
  package let startMicroseconds: Int32
  package let parentProcessID: UInt32
  package let processGroupID: UInt32
  package let sessionID: UInt32
  package let auditSessionID: UInt32
  package let auditTokenWords: [UInt32]
  package let realUserID: UInt32
  package let effectiveUserID: UInt32
  package let savedUserID: UInt32
  package let realGroupID: UInt32
  package let effectiveGroupID: UInt32
  package let savedGroupID: UInt32
  package let supplementaryGroups: [UInt32]

  package init(
    processID: UInt32, processIDVersion: UInt32, startSeconds: Int64,
    startMicroseconds: Int32, parentProcessID: UInt32,
    processGroupID: UInt32, sessionID: UInt32, auditSessionID: UInt32,
    auditTokenWords: [UInt32], realUserID: UInt32,
    effectiveUserID: UInt32, savedUserID: UInt32, realGroupID: UInt32,
    effectiveGroupID: UInt32, savedGroupID: UInt32,
    supplementaryGroups: [UInt32]
  ) throws {
    guard
      processID > 1, processIDVersion > 0, startSeconds > 0,
      (0...999_999).contains(startMicroseconds), parentProcessID > 0,
      processGroupID > 1, sessionID > 0, auditSessionID > 0,
      auditTokenWords.count == 8,
      auditTokenWords[1] == effectiveUserID,
      auditTokenWords[2] == effectiveGroupID,
      auditTokenWords[3] == realUserID,
      auditTokenWords[4] == realGroupID,
      auditTokenWords[5] == processID,
      auditTokenWords[6] == auditSessionID,
      auditTokenWords[7] == processIDVersion,
      (1...Self.supplementaryGroupCapacity)
        .contains(supplementaryGroups.count),
      supplementaryGroups == supplementaryGroups.sorted(),
      Set(supplementaryGroups).count == supplementaryGroups.count,
      supplementaryGroups.contains(effectiveGroupID)
    else {
      throw InvestigationHandoffContractError.invalidValue
    }
    self.processID = processID
    self.processIDVersion = processIDVersion
    self.startSeconds = startSeconds
    self.startMicroseconds = startMicroseconds
    self.parentProcessID = parentProcessID
    self.processGroupID = processGroupID
    self.sessionID = sessionID
    self.auditSessionID = auditSessionID
    self.auditTokenWords = auditTokenWords
    self.realUserID = realUserID
    self.effectiveUserID = effectiveUserID
    self.savedUserID = savedUserID
    self.realGroupID = realGroupID
    self.effectiveGroupID = effectiveGroupID
    self.savedGroupID = savedGroupID
    self.supplementaryGroups = supplementaryGroups
  }
}

package struct InvestigationResolvedRootDriverNodeIdentityV1:
  Sendable, Equatable
{
  package let deviceID: UInt64
  package let inode: UInt64
  package let generation: UInt32
  package let isRegularFile: Bool
  package let ownerUserID: UInt32
  package let ownerGroupID: UInt32
  package let mode: UInt32
  package let linkCount: UInt64
  package let size: Int64
  package let flags: UInt32

  package init(
    deviceID: UInt64, inode: UInt64, generation: UInt32,
    isRegularFile: Bool, ownerUserID: UInt32, ownerGroupID: UInt32,
    mode: UInt32, linkCount: UInt64, size: Int64, flags: UInt32
  ) throws {
    guard
      deviceID > 0, inode > 0, isRegularFile, ownerUserID == 0,
      ownerGroupID == 0, mode == 0o755, linkCount == 1,
      (1...(16 * 1_024 * 1_024)).contains(size), flags == 0
    else {
      throw InvestigationHandoffContractError.invalidValue
    }
    self.deviceID = deviceID
    self.inode = inode
    self.generation = generation
    self.isRegularFile = isRegularFile
    self.ownerUserID = ownerUserID
    self.ownerGroupID = ownerGroupID
    self.mode = mode
    self.linkCount = linkCount
    self.size = size
    self.flags = flags
  }
}

package struct InvestigationResolvedRootDriverSigningIdentityV1:
  Sendable, Equatable
{
  package let signingIdentifier: String
  package let designatedRequirementSHA256: InvestigationHandoffSHA256
  package let codeDirectoryHash: Data
  package let isAdHoc: Bool

  package init(
    signingIdentifier: String,
    designatedRequirementSHA256: InvestigationHandoffSHA256,
    codeDirectoryHash: Data, isAdHoc: Bool
  ) throws {
    guard
      lineageValidIdentifier(signingIdentifier),
      codeDirectoryHash.count == 20 || codeDirectoryHash.count == 32,
      designatedRequirementSHA256.rawBytes.contains(where: { $0 != 0 }),
      codeDirectoryHash.contains(where: { $0 != 0 })
    else {
      throw InvestigationHandoffContractError.invalidValue
    }
    self.signingIdentifier = signingIdentifier
    self.designatedRequirementSHA256 = designatedRequirementSHA256
    self.codeDirectoryHash = codeDirectoryHash
    self.isAdHoc = isAdHoc
  }
}

package struct InvestigationResolvedRootDriverExecutableIdentityV1:
  Sendable, Equatable
{
  package let path: String
  package let node: InvestigationResolvedRootDriverNodeIdentityV1
  package let sha256: InvestigationHandoffSHA256
  package let staticSigning: InvestigationResolvedRootDriverSigningIdentityV1
  package let liveSigning: InvestigationResolvedRootDriverSigningIdentityV1

  package init(
    path: String, node: InvestigationResolvedRootDriverNodeIdentityV1,
    sha256: InvestigationHandoffSHA256,
    staticSigning: InvestigationResolvedRootDriverSigningIdentityV1,
    liveSigning: InvestigationResolvedRootDriverSigningIdentityV1
  ) throws {
    guard
      path.utf8.count <= 512, path.hasPrefix("/"),
      Data(path.utf8).contains(where: { $0 != 0 }),
      sha256.rawBytes.contains(where: { $0 != 0 })
    else {
      throw InvestigationHandoffContractError.invalidValue
    }
    self.path = path
    self.node = node
    self.sha256 = sha256
    self.staticSigning = staticSigning
    self.liveSigning = liveSigning
  }
}

package struct ResolvedRootDriverClaimV1: Sendable, Equatable {
  package static let domain =
    "stornaut.task39.resolved-root-driver-claim-v1"
  package static let fixedExecutablePath =
    "/Library/Application Support/Stornaut/"
    + "Stornaut-R5-Diagnostic.app/Contents/MacOS/"
    + "StornautInvestigationMachineDriver"
  package static let fixedSigningIdentifier =
    InvestigationInstalledL2IdentityProjection
    .fixedMachineDriverSigningIdentifier
  package static let encodedByteCount = 1_006
  package static let maximumByteCount = encodedByteCount

  package let outerAttemptUUID: UUID
  package let wholeInputSHA256: InvestigationHandoffSHA256
  package let process: InvestigationGeneralProcessIdentityV1
  package let executable: InvestigationResolvedRootDriverExecutableIdentityV1
  package let observedAtContinuousNanoseconds: UInt64
  package let selfSHA256: InvestigationHandoffSHA256

  package init(
    outerAttemptUUID: UUID,
    wholeInputSHA256: InvestigationHandoffSHA256,
    process: InvestigationGeneralProcessIdentityV1,
    executable: InvestigationResolvedRootDriverExecutableIdentityV1,
    observedAtContinuousNanoseconds: UInt64
  ) throws {
    try Self.validate(
      outerAttemptUUID: outerAttemptUUID, wholeInputSHA256: wholeInputSHA256,
      process: process, executable: executable,
      observedAtContinuousNanoseconds: observedAtContinuousNanoseconds
    )
    self.outerAttemptUUID = outerAttemptUUID
    self.wholeInputSHA256 = wholeInputSHA256
    self.process = process
    self.executable = executable
    self.observedAtContinuousNanoseconds = observedAtContinuousNanoseconds
    let zero = try InvestigationHandoffSHA256(
      rawBytes: Data(repeating: 0, count: 32)
    )
    selfSHA256 = InvestigationHandoffSHA256.hashing(
      try Self.encode(
        outerAttemptUUID: outerAttemptUUID, wholeInputSHA256: wholeInputSHA256,
        process: process, executable: executable,
        observedAtContinuousNanoseconds: observedAtContinuousNanoseconds,
        selfSHA256: zero
      ))
  }

  package func encoded() throws -> Data {
    let data = try Self.encode(
      outerAttemptUUID: outerAttemptUUID, wholeInputSHA256: wholeInputSHA256,
      process: process, executable: executable,
      observedAtContinuousNanoseconds: observedAtContinuousNanoseconds,
      selfSHA256: selfSHA256
    )
    guard data.count == Self.encodedByteCount else {
      throw InvestigationHandoffContractError.invalidEncoding
    }
    return data
  }

  package static func decode(_ data: Data) throws -> Self {
    guard data.count == encodedByteCount else {
      throw InvestigationHandoffContractError.invalidEncoding
    }
    let fields = try HandoffBinaryTranscript.decode(
      data, expectedDomain: domain,
      expectedBusinessFieldByteCounts: fieldByteCounts,
      maximumByteCount: maximumByteCount
    )
    let groupCount = try lineageCount(fields[17], maximum: 16)
    let process = try InvestigationGeneralProcessIdentityV1(
      processID: handoffDecodeUInt32(fields[2]),
      processIDVersion: handoffDecodeUInt32(fields[3]),
      startSeconds: handoffDecodeInt64(fields[4]),
      startMicroseconds: Int32(bitPattern: handoffDecodeUInt32(fields[5])),
      parentProcessID: handoffDecodeUInt32(fields[6]),
      processGroupID: handoffDecodeUInt32(fields[7]),
      sessionID: handoffDecodeUInt32(fields[8]),
      auditSessionID: handoffDecodeUInt32(fields[9]),
      auditTokenWords: try lineageUInt32Vector(fields[10], count: 8),
      realUserID: handoffDecodeUInt32(fields[11]),
      effectiveUserID: handoffDecodeUInt32(fields[12]),
      savedUserID: handoffDecodeUInt32(fields[13]),
      realGroupID: handoffDecodeUInt32(fields[14]),
      effectiveGroupID: handoffDecodeUInt32(fields[15]),
      savedGroupID: handoffDecodeUInt32(fields[16]),
      supplementaryGroups: try lineagePaddedUInt32Vector(
        fields[18], count: groupCount, capacity: 16
      )
    )
    let node = try InvestigationResolvedRootDriverNodeIdentityV1(
      deviceID: handoffDecodeUInt64(fields[20]),
      inode: handoffDecodeUInt64(fields[21]),
      generation: handoffDecodeUInt32(fields[22]),
      isRegularFile: try lineageBool(fields[23]),
      ownerUserID: handoffDecodeUInt32(fields[24]),
      ownerGroupID: handoffDecodeUInt32(fields[25]),
      mode: handoffDecodeUInt32(fields[26]),
      linkCount: handoffDecodeUInt64(fields[27]),
      size: handoffDecodeInt64(fields[28]),
      flags: handoffDecodeUInt32(fields[29])
    )
    let staticSigning = try signing(fields, start: 31)
    let liveSigning = try signing(fields, start: 36)
    let executable = try InvestigationResolvedRootDriverExecutableIdentityV1(
      path: try lineageString(fields[19]), node: node,
      sha256: InvestigationHandoffSHA256(rawBytes: fields[30]),
      staticSigning: staticSigning, liveSigning: liveSigning
    )
    let claim = try Self(
      outerAttemptUUID: handoffUUID(fields[0]),
      wholeInputSHA256: InvestigationHandoffSHA256(rawBytes: fields[1]),
      process: process, executable: executable,
      observedAtContinuousNanoseconds: handoffDecodeUInt64(fields[41])
    )
    guard
      try InvestigationHandoffSHA256(rawBytes: fields[42])
        == claim.selfSHA256,
      try claim.encoded() == data
    else {
      throw InvestigationHandoffContractError.invalidEncoding
    }
    return claim
  }

  private static let fieldByteCounts: [ClosedRange<Int>] = [
    16...16, 32...32, 4...4, 4...4, 8...8, 4...4, 4...4,
    4...4, 4...4, 4...4, 32...32, 4...4, 4...4, 4...4,
    4...4, 4...4, 4...4, 4...4, 64...64,
    fixedExecutablePath.utf8.count...fixedExecutablePath.utf8.count,
    8...8, 8...8, 4...4, 1...1, 4...4, 4...4, 4...4, 8...8,
    8...8, 4...4, 32...32,
    fixedSigningIdentifier.utf8.count...fixedSigningIdentifier.utf8.count,
    32...32, 4...4, 32...32, 1...1,
    fixedSigningIdentifier.utf8.count...fixedSigningIdentifier.utf8.count,
    32...32, 4...4, 32...32, 1...1, 8...8, 32...32,
  ]

  private static func validate(
    outerAttemptUUID: UUID, wholeInputSHA256: InvestigationHandoffSHA256,
    process: InvestigationGeneralProcessIdentityV1,
    executable: InvestigationResolvedRootDriverExecutableIdentityV1,
    observedAtContinuousNanoseconds: UInt64
  ) throws {
    guard
      handoffUUIDIsNonzero(outerAttemptUUID),
      wholeInputSHA256.rawBytes.contains(where: { $0 != 0 }),
      observedAtContinuousNanoseconds > 0,
      process.realUserID == 0, process.effectiveUserID == 0,
      process.savedUserID == 0, process.realGroupID == 0,
      process.effectiveGroupID == 0, process.savedGroupID == 0,
      process.supplementaryGroups.contains(0),
      executable.path == fixedExecutablePath,
      executable.staticSigning == executable.liveSigning,
      executable.staticSigning.signingIdentifier == fixedSigningIdentifier,
      executable.staticSigning.isAdHoc
    else {
      throw InvestigationHandoffContractError.invalidValue
    }
  }

  private static func signing(
    _ fields: [Data], start: Int
  ) throws -> InvestigationResolvedRootDriverSigningIdentityV1 {
    let count = try lineageCount(fields[start + 2], maximum: 32)
    guard count == 20 || count == 32 else {
      throw InvestigationHandoffContractError.invalidEncoding
    }
    return try .init(
      signingIdentifier: try lineageString(fields[start]),
      designatedRequirementSHA256: try .init(rawBytes: fields[start + 1]),
      codeDirectoryHash: try lineagePaddedBytes(
        fields[start + 3], count: count, capacity: 32
      ),
      isAdHoc: try lineageBool(fields[start + 4])
    )
  }

  private static func encode(
    outerAttemptUUID: UUID, wholeInputSHA256: InvestigationHandoffSHA256,
    process p: InvestigationGeneralProcessIdentityV1,
    executable e: InvestigationResolvedRootDriverExecutableIdentityV1,
    observedAtContinuousNanoseconds: UInt64,
    selfSHA256: InvestigationHandoffSHA256
  ) throws -> Data {
    let ss = e.staticSigning
    let ls = e.liveSigning
    return try HandoffBinaryTranscript.encode(
      domain: domain,
      businessFields: [
        handoffData(outerAttemptUUID), wholeInputSHA256.rawBytes,
        handoffData(p.processID), handoffData(p.processIDVersion),
        handoffData(p.startSeconds),
        handoffData(UInt32(bitPattern: p.startMicroseconds)),
        handoffData(p.parentProcessID), handoffData(p.processGroupID),
        handoffData(p.sessionID), handoffData(p.auditSessionID),
        lineageUInt32VectorData(p.auditTokenWords),
        handoffData(p.realUserID), handoffData(p.effectiveUserID),
        handoffData(p.savedUserID), handoffData(p.realGroupID),
        handoffData(p.effectiveGroupID), handoffData(p.savedGroupID),
        handoffData(UInt32(p.supplementaryGroups.count)),
        lineagePaddedUInt32VectorData(p.supplementaryGroups, capacity: 16),
        Data(e.path.utf8), handoffData(e.node.deviceID),
        handoffData(e.node.inode), handoffData(e.node.generation),
        handoffData(e.node.isRegularFile ? UInt8(1) : UInt8(0)),
        handoffData(e.node.ownerUserID), handoffData(e.node.ownerGroupID),
        handoffData(e.node.mode), handoffData(e.node.linkCount),
        handoffData(e.node.size), handoffData(e.node.flags), e.sha256.rawBytes,
        Data(ss.signingIdentifier.utf8), ss.designatedRequirementSHA256.rawBytes,
        handoffData(UInt32(ss.codeDirectoryHash.count)),
        lineagePaddedBytes(ss.codeDirectoryHash, capacity: 32),
        handoffData(ss.isAdHoc ? UInt8(1) : UInt8(0)),
        Data(ls.signingIdentifier.utf8), ls.designatedRequirementSHA256.rawBytes,
        handoffData(UInt32(ls.codeDirectoryHash.count)),
        lineagePaddedBytes(ls.codeDirectoryHash, capacity: 32),
        handoffData(ls.isAdHoc ? UInt8(1) : UInt8(0)),
        handoffData(observedAtContinuousNanoseconds), selfSHA256.rawBytes,
      ], maximumByteCount: maximumByteCount
    )
  }
}

private func lineageValidIdentifier(_ value: String) -> Bool {
  !value.isEmpty && value.utf8.count <= 256
    && value.unicodeScalars.allSatisfy { scalar in
      (0x30...0x39).contains(scalar.value)
        || (0x41...0x5a).contains(scalar.value)
        || (0x61...0x7a).contains(scalar.value)
        || scalar.value == 0x2d || scalar.value == 0x2e
        || scalar.value == 0x5f
    }
}

private func lineageString(_ data: Data) throws -> String {
  guard let value = String(data: data, encoding: .utf8), Data(value.utf8) == data
  else { throw InvestigationHandoffContractError.invalidEncoding }
  return value
}

private func lineageBool(_ data: Data) throws -> Bool {
  guard data.count == 1, let byte = data.first, byte <= 1
  else { throw InvestigationHandoffContractError.invalidEncoding }
  return byte == 1
}

private func lineageCount(_ data: Data, maximum: Int) throws -> Int {
  let value = try handoffDecodeUInt32(data)
  guard let count = Int(exactly: value), (1...maximum).contains(count)
  else { throw InvestigationHandoffContractError.invalidEncoding }
  return count
}

private func lineageUInt32VectorData(_ values: [UInt32]) -> Data {
  values.reduce(into: Data()) { $0.append(handoffData($1)) }
}

private func lineagePaddedUInt32VectorData(
  _ values: [UInt32], capacity: Int
) -> Data {
  lineageUInt32VectorData(values + Array(repeating: 0, count: capacity - values.count))
}

private func lineageUInt32Vector(_ data: Data, count: Int) throws -> [UInt32] {
  guard data.count == count * 4 else {
    throw InvestigationHandoffContractError.invalidEncoding
  }
  return try stride(from: 0, to: data.count, by: 4).map { offset in
    try handoffDecodeUInt32(data.subdata(in: offset..<(offset + 4)))
  }
}

private func lineagePaddedUInt32Vector(
  _ data: Data, count: Int, capacity: Int
) throws -> [UInt32] {
  let values = try lineageUInt32Vector(data, count: capacity)
  guard values.dropFirst(count).allSatisfy({ $0 == 0 }) else {
    throw InvestigationHandoffContractError.invalidEncoding
  }
  return Array(values.prefix(count))
}

private func lineagePaddedBytes(_ value: Data, capacity: Int) -> Data {
  value + Data(repeating: 0, count: capacity - value.count)
}

private func lineagePaddedBytes(
  _ data: Data, count: Int, capacity: Int
) throws -> Data {
  guard
    data.count == capacity,
    data.dropFirst(count).allSatisfy({ $0 == 0 })
  else {
    throw InvestigationHandoffContractError.invalidEncoding
  }
  return data.prefix(count)
}
