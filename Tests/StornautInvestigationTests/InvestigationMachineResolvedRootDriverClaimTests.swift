import Foundation
import Testing

@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationMachineDriverSupport

@Suite("Resolved root-driver claim collector", .serialized)
struct InvestigationMachineResolvedRootDriverClaimTests {
    @Test
    func stableInjectedEvidenceProducesCanonicalClaim() throws {
        let fixture = try RootDriverClaimFixture()
        let claim = try fixture.collect()

        #expect(claim.outerAttemptUUID == fixture.binding.outerAttemptUUID)
        #expect(claim.wholeInputSHA256 == fixture.binding.wholeInputSHA256)
        #expect(claim.process.processID == fixture.process.processID)
        #expect(claim.process.processIDVersion == fixture.process.processIDVersion)
        #expect(claim.process.startSeconds == fixture.process.startSeconds)
        #expect(claim.process.sessionID == fixture.process.sessionID)
        #expect(claim.process.auditTokenWords == fixture.process.auditTokenWords)
        #expect(claim.process.supplementaryGroups == [0, 20, 80])
        #expect(claim.executable.path == ResolvedRootDriverClaimV1.fixedExecutablePath)
        #expect(claim.executable.node.inode == fixture.executable.node.inode)
        #expect(claim.executable.staticSigning == claim.executable.liveSigning)
        #expect(claim.observedAtContinuousNanoseconds == fixture.clock)
        #expect(try ResolvedRootDriverClaimV1.decode(claim.encoded()) == claim)
    }

    @Test(arguments: RootDriverStableDrift.allCases)
    fileprivate func anyDifferenceBetweenFirstAndSecondSamplesFailsClosed(
        _ drift: RootDriverStableDrift
    ) throws {
        let fixture = try RootDriverClaimFixture()
        #expect(throws: InvestigationMachineResolvedRootDriverClaimError.unstableProcessIdentity) {
            _ = try fixture.collect(second: drift.apply(to: fixture.process))
        }
    }

    @Test(arguments: RootDriverInvalidProcessMutation.allCases)
    fileprivate func invalidProcessAndAuditIdentityFailsClosed(
        _ mutation: RootDriverInvalidProcessMutation
    ) throws {
        let fixture = try RootDriverClaimFixture()
        let changed = mutation.apply(to: fixture.process)
        #expect(throws: InvestigationMachineResolvedRootDriverClaimError.invalidProcessIdentity) {
            _ = try fixture.collect(first: changed, second: changed)
        }
    }

    @Test(arguments: RootDriverCredentialMutation.allCases)
    fileprivate func everyNonRootCredentialFailsClosed(
        _ mutation: RootDriverCredentialMutation
    ) throws {
        let fixture = try RootDriverClaimFixture()
        let changed = mutation.apply(to: fixture.process)
        #expect(throws: InvestigationMachineResolvedRootDriverClaimError.invalidProcessIdentity) {
            _ = try fixture.collect(first: changed, second: changed)
        }
    }

    @Test(arguments: RootDriverGroupMutation.allCases)
    fileprivate func supplementaryGroupsMustBeBoundedCanonicalAndContainRoot(
        _ mutation: RootDriverGroupMutation
    ) throws {
        let fixture = try RootDriverClaimFixture()
        var changed = fixture.process
        changed.supplementaryGroups = mutation.groups
        #expect(throws: InvestigationMachineResolvedRootDriverClaimError.invalidProcessIdentity) {
            _ = try fixture.collect(first: changed, second: changed)
        }
    }

    @Test(arguments: RootDriverNodeMutation.allCases)
    fileprivate func fixedExecutableNodeMustBeRootOwnedRegularAndBounded(
        _ mutation: RootDriverNodeMutation
    ) throws {
        let fixture = try RootDriverClaimFixture()
        var executable = fixture.executable
        executable.node = mutation.apply(to: executable.node)
        #expect(throws: InvestigationMachineResolvedRootDriverClaimError.invalidExecutableIdentity) {
            _ = try fixture.collect(executable: executable)
        }
    }

    @Test(arguments: RootDriverSigningMutation.allCases)
    fileprivate func signingAndExecutableDigestDriftFailsClosed(
        _ mutation: RootDriverSigningMutation
    ) throws {
        let fixture = try RootDriverClaimFixture()
        let values = try mutation.apply(
            executable: fixture.executable, live: fixture.signing
        )
        #expect(throws: InvestigationMachineResolvedRootDriverClaimError.invalidExecutableIdentity) {
            _ = try fixture.collect(executable: values.0, live: values.1)
        }
    }

    @Test
    func fixedPathAndSelfProcessIDAreNotCallerSelectable() throws {
        let fixture = try RootDriverClaimFixture()
        var wrongPath = fixture.executable
        wrongPath.path = "/tmp/foreign-driver"
        #expect(throws: InvestigationMachineResolvedRootDriverClaimError.invalidExecutableIdentity) {
            _ = try fixture.collect(executable: wrongPath)
        }
        #expect(throws: InvestigationMachineResolvedRootDriverClaimError.invalidProcessIdentity) {
            _ = try fixture.collect(selfProcessID: fixture.process.processID + 1)
        }
    }

    @Test
    func zeroClockAttemptAndInputDigestFailClosed() throws {
        let fixture = try RootDriverClaimFixture()
        #expect(throws: InvestigationMachineResolvedRootDriverClaimError.invalidClock) {
            _ = try fixture.collect(clock: 0)
        }
        let zeroAttempt = InvestigationMachineResolvedRootDriverClaimBinding(
            outerAttemptUUID: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)),
            wholeInputSHA256: fixture.binding.wholeInputSHA256
        )
        #expect(throws: InvestigationMachineResolvedRootDriverClaimError.invalidBinding) {
            _ = try fixture.collect(binding: zeroAttempt)
        }
        let zeroInput = InvestigationMachineResolvedRootDriverClaimBinding(
            outerAttemptUUID: fixture.binding.outerAttemptUUID,
            wholeInputSHA256: try InvestigationHandoffSHA256(
                rawBytes: Data(repeating: 0, count: 32)
            )
        )
        #expect(throws: InvestigationMachineResolvedRootDriverClaimError.invalidBinding) {
            _ = try fixture.collect(binding: zeroInput)
        }
    }
}

private struct RootDriverClaimFixture {
    let binding: InvestigationMachineResolvedRootDriverClaimBinding
    let process: InvestigationMachineResolvedRootDriverProcessObservation
    let executable: InvestigationMachineResolvedRootDriverExecutableObservation
    let signing: InvestigationMachineResolvedRootDriverSigningObservation
    let clock: UInt64 = 8_000_000

    init() throws {
        binding = .init(
            outerAttemptUUID: UUID(uuidString: "22222222-3333-4444-8555-666666666666")!,
            wholeInputSHA256: try Self.digest(0x11)
        )
        process = .init(
            processID: 701, processIDVersion: 19, startSeconds: 1_800,
            startMicroseconds: 321, parentProcessID: 600, processGroupID: 600,
            sessionID: 500, auditSessionID: 99,
            auditTokenWords: [501, 0, 0, 0, 0, 701, 99, 19],
            realUserID: 0, effectiveUserID: 0, savedUserID: 0,
            realGroupID: 0, effectiveGroupID: 0, savedGroupID: 0,
            supplementaryGroups: [0, 20, 80]
        )
        signing = .init(
            signingIdentifier: ResolvedRootDriverClaimV1.fixedSigningIdentifier,
            designatedRequirementSHA256: try Self.digest(0x22),
            codeDirectoryHash: Data(repeating: 0x33, count: 20), isAdHoc: true
        )
        executable = .init(
            path: ResolvedRootDriverClaimV1.fixedExecutablePath,
            node: .init(
                deviceID: 2, inode: 90, generation: 7, isRegularFile: true,
                ownerUserID: 0, ownerGroupID: 0, mode: 0o755,
                linkCount: 1, size: 1_024, flags: 0
            ),
            sha256: try Self.digest(0x44), staticSigning: signing
        )
    }

    func collect(
        binding: InvestigationMachineResolvedRootDriverClaimBinding? = nil,
        selfProcessID: UInt32? = nil,
        first: InvestigationMachineResolvedRootDriverProcessObservation? = nil,
        second: InvestigationMachineResolvedRootDriverProcessObservation? = nil,
        executable: InvestigationMachineResolvedRootDriverExecutableObservation? = nil,
        live: InvestigationMachineResolvedRootDriverSigningObservation? = nil,
        clock: UInt64? = nil
    ) throws -> ResolvedRootDriverClaimV1 {
        let first = first ?? process
        return try InvestigationMachineResolvedRootDriverClaimCollector(
            source: .init(
                selfProcessID: { selfProcessID ?? process.processID },
                processSnapshot1: { first },
                executableObservation: { executable ?? self.executable },
                liveSigning: { token in
                    guard token == first.auditTokenWords else { throw FixtureError.rejected }
                    return live ?? signing
                },
                processSnapshot2: { second ?? process },
                continuousNanoseconds: { clock ?? self.clock }
            )
        ).collect(binding: binding ?? self.binding)
    }

    static func digest(_ byte: UInt8) throws -> InvestigationHandoffSHA256 {
        try .init(rawBytes: Data(repeating: byte, count: 32))
    }
}

private enum FixtureError: Error { case rejected }

private enum RootDriverStableDrift: CaseIterable, Sendable {
    case pid, version, startSeconds, startMicroseconds, parent, group, session, auditSession, token, groups
    func apply(to value: InvestigationMachineResolvedRootDriverProcessObservation)
        -> InvestigationMachineResolvedRootDriverProcessObservation
    {
        var copy = value
        switch self {
        case .pid: copy.processID += 1; copy.auditTokenWords[5] += 1
        case .version: copy.processIDVersion += 1; copy.auditTokenWords[7] += 1
        case .startSeconds: copy.startSeconds += 1
        case .startMicroseconds: copy.startMicroseconds += 1
        case .parent: copy.parentProcessID += 1
        case .group: copy.processGroupID += 1
        case .session: copy.sessionID += 1
        case .auditSession: copy.auditSessionID += 1; copy.auditTokenWords[6] += 1
        case .token: copy.auditTokenWords[0] += 1
        case .groups: copy.supplementaryGroups = [0, 1]
        }
        return copy
    }
}

private enum RootDriverInvalidProcessMutation: CaseIterable, Sendable {
    case pid, version, start, microsNegative, microsHigh, parent, group, session, auditSession
    case tokenCount, tokenEUID, tokenEGID, tokenRUID, tokenRGID, tokenPID, tokenASID, tokenVersion
    func apply(to value: InvestigationMachineResolvedRootDriverProcessObservation)
        -> InvestigationMachineResolvedRootDriverProcessObservation
    {
        var copy = value
        switch self {
        case .pid: copy.processID = 1
        case .version: copy.processIDVersion = 0
        case .start: copy.startSeconds = 0
        case .microsNegative: copy.startMicroseconds = -1
        case .microsHigh: copy.startMicroseconds = 1_000_000
        case .parent: copy.parentProcessID = 0
        case .group: copy.processGroupID = 1
        case .session: copy.sessionID = 0
        case .auditSession: copy.auditSessionID = 0
        case .tokenCount: copy.auditTokenWords.removeLast()
        case .tokenEUID: copy.auditTokenWords[1] = 9
        case .tokenEGID: copy.auditTokenWords[2] = 9
        case .tokenRUID: copy.auditTokenWords[3] = 9
        case .tokenRGID: copy.auditTokenWords[4] = 9
        case .tokenPID: copy.auditTokenWords[5] += 1
        case .tokenASID: copy.auditTokenWords[6] += 1
        case .tokenVersion: copy.auditTokenWords[7] += 1
        }
        return copy
    }
}

private enum RootDriverCredentialMutation: CaseIterable, Sendable {
    case realUser, effectiveUser, savedUser, realGroup, effectiveGroup, savedGroup
    func apply(to value: InvestigationMachineResolvedRootDriverProcessObservation)
        -> InvestigationMachineResolvedRootDriverProcessObservation
    {
        var copy = value
        switch self {
        case .realUser: copy.realUserID = 501; copy.auditTokenWords[3] = 501
        case .effectiveUser: copy.effectiveUserID = 501; copy.auditTokenWords[1] = 501
        case .savedUser: copy.savedUserID = 501
        case .realGroup: copy.realGroupID = 20; copy.auditTokenWords[4] = 20
        case .effectiveGroup: copy.effectiveGroupID = 20; copy.auditTokenWords[2] = 20
        case .savedGroup: copy.savedGroupID = 20
        }
        return copy
    }
}

private enum RootDriverGroupMutation: CaseIterable, Sendable {
    case empty, nonRoot, duplicate, unsorted, overCapacity
    var groups: [UInt32] {
        switch self {
        case .empty: []
        case .nonRoot: [20]
        case .duplicate: [0, 0]
        case .unsorted: [20, 0]
        case .overCapacity: Array(0...16)
        }
    }
}

private enum RootDriverNodeMutation: CaseIterable, Sendable {
    case device, inode, regular, ownerUser, ownerGroup, mode, links, empty, oversized, flags
    func apply(to value: InvestigationMachineResolvedRootDriverNodeObservation)
        -> InvestigationMachineResolvedRootDriverNodeObservation
    {
        var copy = value
        switch self {
        case .device: copy.deviceID = 0
        case .inode: copy.inode = 0
        case .regular: copy.isRegularFile = false
        case .ownerUser: copy.ownerUserID = 501
        case .ownerGroup: copy.ownerGroupID = 20
        case .mode: copy.mode = 0o775
        case .links: copy.linkCount = 2
        case .empty: copy.size = 0
        case .oversized: copy.size = 16 * 1_024 * 1_024 + 1
        case .flags: copy.flags = 1
        }
        return copy
    }
}

private enum RootDriverSigningMutation: CaseIterable, Sendable {
    case sha, identifier, requirement, codeDirectory, adHoc, live
    func apply(
        executable: InvestigationMachineResolvedRootDriverExecutableObservation,
        live: InvestigationMachineResolvedRootDriverSigningObservation
    ) throws -> (InvestigationMachineResolvedRootDriverExecutableObservation, InvestigationMachineResolvedRootDriverSigningObservation) {
        var executable = executable, live = live
        switch self {
        case .sha: executable.sha256 = try RootDriverClaimFixture.digest(0)
        case .identifier: executable.staticSigning.signingIdentifier = "foreign"
        case .requirement: executable.staticSigning.designatedRequirementSHA256 = try RootDriverClaimFixture.digest(0)
        case .codeDirectory: executable.staticSigning.codeDirectoryHash = Data(repeating: 1, count: 19)
        case .adHoc: executable.staticSigning.isAdHoc = false
        case .live: live.codeDirectoryHash = Data(repeating: 0x55, count: 20)
        }
        return (executable, live)
    }
}
