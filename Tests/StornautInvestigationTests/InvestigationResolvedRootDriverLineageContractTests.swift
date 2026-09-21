import Foundation
import Testing

@testable import StornautInvestigationHandoffContract

@Suite("Resolved root-driver lineage canonical contract")
struct InvestigationResolvedRootDriverLineageContractTests {
  @Test("golden claim is fixed-size, self-sealed, and round-trips exactly")
  func goldenRoundTrip() throws {
    let claim = try fixture(process: process(groups: [0, 20, 80]))
    let encoded = try claim.encoded()

    #expect(encoded.count == ResolvedRootDriverClaimV1.encodedByteCount)
    #expect(ResolvedRootDriverClaimV1.maximumByteCount == encoded.count)
    #expect(try ResolvedRootDriverClaimV1.decode(encoded) == claim)
    #expect(try ResolvedRootDriverClaimV1.decode(encoded).encoded() == encoded)
    #expect(claim.selfSHA256.rawBytes.contains { $0 != 0 })
    #expect(claim.process.supplementaryGroups == [0, 20, 80])
  }

  @Test("general process identity admits the initial sudo UID shape")
  func generalIdentityAdmitsInitialSudo() throws {
    let identity = try process(
      realUserID: 501, effectiveUserID: 501, savedUserID: 0,
      realGroupID: 20, effectiveGroupID: 20, savedGroupID: 0,
      groups: [0, 20, 80]
    )
    #expect(identity.effectiveUserID == 501)
    #expect(identity.supplementaryGroups == [0, 20, 80])
  }

  @Test(
    "claim construction rejects every non-root credential component",
    arguments: CredentialMutation.allCases)
  func rejectsNonRootCredential(_ mutation: CredentialMutation) throws {
    var values = Credentials.root
    mutation.apply(to: &values)
    #expect(throws: InvestigationHandoffContractError.self) {
      _ = try fixture(
        process: process(
          realUserID: values.ruid, effectiveUserID: values.euid,
          savedUserID: values.suid, realGroupID: values.rgid,
          effectiveGroupID: values.egid, savedGroupID: values.sgid,
          groups: values.groups
        ))
    }
  }

  @Test(
    "audit token must bind PID, pidversion, ASID, EUID and IDs",
    arguments: [1, 2, 3, 4, 5, 6, 7])
  func rejectsAuditTokenDrift(_ word: Int) throws {
    var token = rootAuditToken
    token[word] &+= 1
    #expect(throws: InvestigationHandoffContractError.self) {
      _ = try process(auditTokenWords: token)
    }
  }

  @Test("canonical decoder rejects scalar, token, node, hash and signing drift")
  func rejectsCanonicalPayloadMutations() throws {
    let encoded = try fixture().encoded()
    // Every field below is security-significant. Flipping its final byte must
    // either violate semantic admission or invalidate the self-seal.
    for field in [
      0, 1,  // attempt and whole input
      2, 3, 4, 5, 6, 7, 8, 9,  // process scalars
      10,  // audit token
      11, 12, 13, 14, 15, 16, 17, 18,  // credentials/groups
      19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29,  // path/node
      30,  // executable SHA
      31, 32, 33, 34, 35,  // static signing
      36, 37, 38, 39, 40,  // live signing
      41, 42,  // observed time/self hash
    ] {
      var mutated = encoded
      let range = try payloadRange(field: field, in: mutated)
      mutated[range.upperBound - 1] ^= 0x01
      #expect(throws: Error.self, "field \(field)") {
        _ = try ResolvedRootDriverClaimV1.decode(mutated)
      }
    }
  }

  @Test("canonical decoder rejects group and CodeDirectory padding")
  func rejectsNonzeroPadding() throws {
    let encoded = try fixture().encoded()
    for field in [18, 34, 39] {
      var mutated = encoded
      let range = try payloadRange(field: field, in: mutated)
      mutated[range.upperBound - 1] = 0x7f
      #expect(throws: Error.self) {
        _ = try ResolvedRootDriverClaimV1.decode(mutated)
      }
    }
  }

  @Test("canonical decoder rejects trailing and every one-byte truncation")
  func rejectsFramingDrift() throws {
    let encoded = try fixture().encoded()
    #expect(throws: Error.self) {
      _ = try ResolvedRootDriverClaimV1.decode(encoded + Data([0]))
    }
    for count in 1...encoded.count {
      #expect(throws: Error.self, "truncated to \(count - 1)") {
        _ = try ResolvedRootDriverClaimV1.decode(encoded.prefix(count - 1))
      }
    }
  }

  @Test("fixed executable and signing identity are mandatory")
  func rejectsExecutableIdentityDrift() throws {
    let expectedSigning = try signing()
    #expect(throws: InvestigationHandoffContractError.self) {
      _ = try fixture(
        executable: executable(
          path: "/tmp/driver", staticSigning: expectedSigning,
          liveSigning: expectedSigning
        ))
    }
    let other = try signing(identifier: "com.example.other")
    #expect(throws: InvestigationHandoffContractError.self) {
      _ = try fixture(
        executable: executable(
          staticSigning: other, liveSigning: other
        ))
    }
    let nonAdHoc = try signing(isAdHoc: false)
    #expect(throws: InvestigationHandoffContractError.self) {
      _ = try fixture(
        executable: executable(
          staticSigning: nonAdHoc, liveSigning: nonAdHoc
        ))
    }
    #expect(throws: InvestigationHandoffContractError.self) {
      _ = try fixture(
        executable: executable(
          staticSigning: expectedSigning, liveSigning: other
        ))
    }
  }

  private let rootAuditToken: [UInt32] = [501, 0, 0, 0, 0, 4_242, 77, 9]

  private func process(
    auditTokenWords: [UInt32]? = nil, realUserID: UInt32 = 0,
    effectiveUserID: UInt32 = 0, savedUserID: UInt32 = 0,
    realGroupID: UInt32 = 0, effectiveGroupID: UInt32 = 0,
    savedGroupID: UInt32 = 0, groups: [UInt32] = [0]
  ) throws -> InvestigationGeneralProcessIdentityV1 {
    try .init(
      processID: 4_242, processIDVersion: 9, startSeconds: 1_900_000_000,
      startMicroseconds: 123_456, parentProcessID: 4_200,
      processGroupID: 4_200, sessionID: 4_000, auditSessionID: 77,
      auditTokenWords: auditTokenWords ?? [
        501, effectiveUserID, effectiveGroupID, realUserID, realGroupID,
        4_242, 77, 9,
      ],
      realUserID: realUserID, effectiveUserID: effectiveUserID,
      savedUserID: savedUserID, realGroupID: realGroupID,
      effectiveGroupID: effectiveGroupID, savedGroupID: savedGroupID,
      supplementaryGroups: groups
    )
  }

  private func node() throws -> InvestigationResolvedRootDriverNodeIdentityV1 {
    try .init(
      deviceID: 11, inode: 22, generation: 3, isRegularFile: true,
      ownerUserID: 0, ownerGroupID: 0, mode: 0o755, linkCount: 1,
      size: 1_048_576, flags: 0
    )
  }

  private func signing(
    identifier: String = ResolvedRootDriverClaimV1.fixedSigningIdentifier,
    marker: UInt8 = 0x44, isAdHoc: Bool = true
  ) throws -> InvestigationResolvedRootDriverSigningIdentityV1 {
    try .init(
      signingIdentifier: identifier,
      designatedRequirementSHA256: .hashing(Data([marker])),
      codeDirectoryHash: Data(repeating: marker, count: 20),
      isAdHoc: isAdHoc
    )
  }

  private func executable(
    path: String = ResolvedRootDriverClaimV1.fixedExecutablePath,
    staticSigning: InvestigationResolvedRootDriverSigningIdentityV1? = nil,
    liveSigning: InvestigationResolvedRootDriverSigningIdentityV1? = nil
  ) throws -> InvestigationResolvedRootDriverExecutableIdentityV1 {
    let signing = try signing()
    return try .init(
      path: path, node: node(), sha256: .hashing(Data([0x33])),
      staticSigning: staticSigning ?? signing,
      liveSigning: liveSigning ?? signing
    )
  }

  private func fixture(
    process: InvestigationGeneralProcessIdentityV1? = nil,
    executable: InvestigationResolvedRootDriverExecutableIdentityV1? = nil
  ) throws -> ResolvedRootDriverClaimV1 {
    try .init(
      outerAttemptUUID: UUID(uuidString: "12345678-1234-5678-9abc-def012345678")!,
      wholeInputSHA256: .hashing(Data([0x22])),
      process: process ?? self.process(),
      executable: executable ?? self.executable(),
      observedAtContinuousNanoseconds: 9_876_543_210
    )
  }

  private func payloadRange(field: Int, in data: Data) throws -> Range<Int> {
    var offset = 4
    for expectedTag in 0...(field + 2) {
      guard offset + 6 <= data.count else { throw TestError.invalidFixture }
      let tag = Int(data[offset]) << 8 | Int(data[offset + 1])
      guard tag == expectedTag else { throw TestError.invalidFixture }
      let length = data[(offset + 2)..<(offset + 6)].reduce(0) {
        ($0 << 8) | Int($1)
      }
      let range = (offset + 6)..<(offset + 6 + length)
      guard range.upperBound <= data.count else { throw TestError.invalidFixture }
      if expectedTag == field + 2 { return range }
      offset = range.upperBound
    }
    throw TestError.invalidFixture
  }
}

private enum TestError: Error { case invalidFixture }

struct Credentials {
  var ruid: UInt32
  var euid: UInt32
  var suid: UInt32
  var rgid: UInt32
  var egid: UInt32
  var sgid: UInt32
  var groups: [UInt32]
  static let root = Self(ruid: 0, euid: 0, suid: 0, rgid: 0, egid: 0, sgid: 0, groups: [0])
}

enum CredentialMutation: CaseIterable {
  case ruid, euid, suid, rgid, egid, sgid, missingRootGroup
  func apply(to value: inout Credentials) {
    switch self {
    case .ruid: value.ruid = 501
    case .euid: value.euid = 501
    case .suid: value.suid = 501
    case .rgid: value.rgid = 20
    case .egid: value.egid = 20
    case .sgid: value.sgid = 20
    case .missingRootGroup: value.groups = [20]
    }
  }
}
