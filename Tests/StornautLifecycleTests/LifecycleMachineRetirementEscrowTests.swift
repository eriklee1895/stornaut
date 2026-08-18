import Foundation
import Testing
@testable import StornautLifecycle

@Suite("Lifecycle machine retirement escrow")
struct LifecycleMachineRetirementEscrowTests {
    @Test
    func strictRecordsRoundTripAndRejectUnknownOrInconsistentIdentity() throws {
        let fixture = try MachineRetirementEscrowFixture()
        let encoded = try JSONEncoder().encode(fixture.appRecord)
        var identity = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        #expect(identity["protocolVersion"] as? Int == 1)
        identity["processIDVersion"] = 999
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                LifecycleMachineProcessIdentityRecord.self,
                from: try JSONSerialization.data(withJSONObject: identity)
            )
        }
        var unknownIdentity = identity
        unknownIdentity["processIDVersion"] = 11
        unknownIdentity["unexpected"] = true
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                LifecycleMachineProcessIdentityRecord.self,
                from: try JSONSerialization.data(
                    withJSONObject: unknownIdentity
                )
            )
        }

        var missing = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(try fixture.request())
            ) as? [String: Any]
        )
        #expect(missing["protocolVersion"] as? Int == 2)
        missing.removeValue(forKey: "challengeNonce")
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                LifecycleMachineRetirementClaimRequest.self,
                from: try JSONSerialization.data(withJSONObject: missing)
            )
        }
        var unknownRequest = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(try fixture.request())
            ) as? [String: Any]
        )
        unknownRequest["unexpected"] = true
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                LifecycleMachineRetirementClaimRequest.self,
                from: try JSONSerialization.data(
                    withJSONObject: unknownRequest
                )
            )
        }
        var futureRequest = unknownRequest
        futureRequest.removeValue(forKey: "unexpected")
        futureRequest["protocolVersion"] = 3
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                LifecycleMachineRetirementClaimRequest.self,
                from: try JSONSerialization.data(
                    withJSONObject: futureRequest
                )
            )
        }
    }

    @Test
    func recordAndFreshClaimProduceStrictEchoedResponse() throws {
        let fixture = try MachineRetirementEscrowFixture()
        let escrow = fixture.escrow()
        let handle = try fixture.record(into: escrow)
        #expect(escrow.isAwaitingClaim)
        let request = try fixture.request(handle: handle)

        let response = try escrow.claim(request, authorized: true)

        #expect(response.request == request)
        #expect(response.appIdentity == fixture.appRecord)
        #expect(response.helperIdentity == fixture.helperRecord)
        #expect(response.userID == fixture.userID)
        #expect(response.recordedAt == fixture.now)
        #expect(response.claimedAt == fixture.claimAt)
        #expect(
            response.ownerRetirementObservation
                == .retiredOwnedResources
        )
        #expect(response.residueObservation.provedEmpty)
        #expect(!escrow.isAwaitingClaim)
        #expect(
            try JSONDecoder().decode(
                LifecycleMachineRetirementClaimResponse.self,
                from: JSONEncoder().encode(response)
            ) == response
        )
    }

    @Test
    func publicResponseInitializerRejectsInvalidFacts() throws {
        let fixture = try MachineRetirementEscrowFixture()
        let request = try fixture.request()
        let valid = try LifecycleMachineRetirementClaimResponse(
            request: request,
            appIdentity: fixture.appRecord,
            helperIdentity: fixture.helperRecord,
            userID: fixture.userID,
            recordedAt: fixture.now,
            claimedAt: fixture.claimAt,
            ownerRetirementObservation: .retiredOwnedResources,
            residueObservation: try fixture.residue()
        )
        #expect(valid.recordedAt < valid.claimedAt)
        #expect(throws: LifecycleMachineRetirementEscrowError.invalidRecord) {
            _ = try LifecycleMachineRetirementClaimResponse(
                request: request,
                appIdentity: fixture.appRecord,
                helperIdentity: fixture.helperRecord,
                userID: fixture.userID,
                recordedAt: fixture.now,
                claimedAt: fixture.claimAt,
                ownerRetirementObservation: .retiredOwnedResources,
                residueObservation: try fixture.residue(
                    observedAt: fixture.now.addingTimeInterval(1)
                )
            )
        }

        #expect(throws: LifecycleMachineRetirementEscrowError.invalidRecord) {
            _ = try LifecycleMachineRetirementClaimResponse(
                request: request,
                appIdentity: fixture.appRecord,
                helperIdentity: fixture.helperRecord,
                userID: fixture.userID,
                recordedAt: request.issuedAt.addingTimeInterval(1),
                claimedAt: fixture.claimAt,
                ownerRetirementObservation: .retiredOwnedResources,
                residueObservation: try fixture.residue()
            )
        }
        #expect(throws: LifecycleMachineRetirementEscrowError.invalidRecord) {
            _ = try LifecycleMachineRetirementClaimResponse(
                request: request,
                appIdentity: fixture.appRecord,
                helperIdentity: fixture.helperRecord,
                userID: fixture.userID,
                recordedAt: fixture.now,
                claimedAt: request.validBefore.addingTimeInterval(1),
                ownerRetirementObservation: .noOwnedResources,
                residueObservation: try fixture.residue()
            )
        }
    }

    @Test
    func explicitExpireConsumesEmptyAndRecordedEscrows() throws {
        let fixture = try MachineRetirementEscrowFixture()
        let empty = fixture.escrow()
        empty.expire()
        #expect(!empty.isAwaitingClaim)
        #expect(throws: LifecycleMachineRetirementEscrowError.consumed) {
            _ = try empty.claim(try fixture.request(), authorized: true)
        }

        let recorded = fixture.escrow()
        let request = try fixture.request(
            handle: try fixture.record(into: recorded)
        )
        #expect(recorded.isAwaitingClaim)
        recorded.expire()
        #expect(!recorded.isAwaitingClaim)
        #expect(throws: LifecycleMachineRetirementEscrowError.consumed) {
            _ = try recorded.claim(request, authorized: true)
        }

        let restarted = fixture.escrow()
        restarted.expire()
        #expect(!restarted.isAwaitingClaim)
    }

    @Test
    func recordRejectsNoOwnershipNonzeroResidueAndIdentityDrift() throws {
        let fixture = try MachineRetirementEscrowFixture()
        #expect(throws: LifecycleMachineRetirementEscrowError.invalidRecord) {
            _ = try fixture.record(
                into: fixture.escrow(),
                owner: .noOwnedResources
            )
        }
        #expect(throws: LifecycleMachineRetirementEscrowError.invalidRecord) {
            _ = try fixture.record(
                into: fixture.escrow(),
                residue: try fixture.residue(remainingMembers: 1)
            )
        }
        #expect(throws: LifecycleMachineRetirementEscrowError.invalidRecord) {
            _ = try fixture.record(
                into: fixture.escrow(),
                appIdentity: fixture.helperRecord
            )
        }
    }

    @Test
    func authorizedMismatchAndExpiryConsumeTerminally() throws {
        let fixture = try MachineRetirementEscrowFixture()
        let mismatchEscrow = fixture.escrow()
        let mismatchHandle = try fixture.record(into: mismatchEscrow)
        let foreignHandle = try LifecycleMachineRetirementHandle(
            token: UUID(),
            investigationID: mismatchHandle.investigationID,
            retireOperationID: mismatchHandle.retireOperationID,
            configurationSHA256: mismatchHandle.configurationSHA256,
            validBefore: mismatchHandle.validBefore
        )
        let foreign = try LifecycleMachineRetirementClaimRequest(
            handle: foreignHandle,
            challengeNonce: UUID(),
            issuedAt: fixture.now,
            validBefore: fixture.now.addingTimeInterval(10)
        )
        #expect(throws: LifecycleMachineRetirementEscrowError.claimMismatch) {
            _ = try mismatchEscrow.claim(foreign, authorized: true)
        }
        #expect(!mismatchEscrow.isAwaitingClaim)
        #expect(throws: LifecycleMachineRetirementEscrowError.consumed) {
            _ = try mismatchEscrow.claim(foreign, authorized: true)
        }

        let clock = MutableMachineEscrowClock(now: fixture.now)
        let expiredEscrow = fixture.escrow(now: clock.read)
        let expiredHandle = try fixture.record(into: expiredEscrow)
        clock.set(expiredHandle.validBefore.addingTimeInterval(1))
        #expect(throws: LifecycleMachineRetirementEscrowError.expired) {
            _ = try expiredEscrow.claim(
                try fixture.request(handle: expiredHandle),
                authorized: true
            )
        }
        #expect(!expiredEscrow.isAwaitingClaim)
    }

    @Test
    func unauthorizedAndEmptyClaimsDoNotInventOrConsumeEvidence() throws {
        let fixture = try MachineRetirementEscrowFixture()
        let empty = fixture.escrow()
        #expect(throws: LifecycleMachineRetirementEscrowError.empty) {
            _ = try empty.claim(try fixture.request(), authorized: true)
        }
        #expect(!empty.isAwaitingClaim)

        let escrow = fixture.escrow()
        let handle = try fixture.record(into: escrow)
        let request = try fixture.request(handle: handle)
        #expect(throws: LifecycleMachineRetirementEscrowError.unauthorized) {
            _ = try escrow.claim(request, authorized: false)
        }
        #expect(escrow.isAwaitingClaim)
        _ = try escrow.claim(request, authorized: true)

        let restarted = fixture.escrow()
        #expect(!restarted.isAwaitingClaim)
        #expect(throws: LifecycleMachineRetirementEscrowError.empty) {
            _ = try restarted.claim(request, authorized: true)
        }
        #expect(
            !((LifecycleMachineRetirementEscrow.self as Any.Type)
                is any Codable.Type)
        )
    }

    @Test
    func concurrentClaimsHaveExactlyOneWinner() async throws {
        let fixture = try MachineRetirementEscrowFixture()
        let escrow = fixture.escrow()
        let request = try fixture.request(
            handle: try fixture.record(into: escrow)
        )

        let successes = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<16 {
                group.addTask {
                    (try? escrow.claim(request, authorized: true)) != nil
                }
            }
            var count = 0
            for await success in group where success { count += 1 }
            return count
        }

        #expect(successes == 1)
        #expect(!escrow.isAwaitingClaim)
    }

    @Test
    func productionClaimRequiresLiveMachineDriverAdmissionBeforeConsume()
        throws
    {
        let fixture = try MachineRetirementEscrowFixture()
        let denied = fixture.escrow()
        let deniedRequest = try fixture.request(
            handle: try fixture.record(into: denied)
        )
        let rejected = RecordingMachineDriverClaimAdmission(
            accepted: false
        )

        #expect(throws: LifecycleMachineRetirementEscrowError.unauthorized) {
            _ = try denied.claim(
                deniedRequest,
                machineDriverIdentity: fixture.machineDriverIdentity,
                admission: rejected
            )
        }
        #expect(denied.isAwaitingClaim)
        #expect(rejected.identities == [fixture.machineDriverIdentity])

        let accepted = fixture.escrow()
        let acceptedRequest = try fixture.request(
            handle: try fixture.record(into: accepted)
        )
        let allowed = RecordingMachineDriverClaimAdmission(accepted: true)
        let response = try accepted.claim(
            acceptedRequest,
            machineDriverIdentity: fixture.machineDriverIdentity,
            admission: allowed
        )
        #expect(response.request == acceptedRequest)
        #expect(!accepted.isAwaitingClaim)
        #expect(allowed.identities == [fixture.machineDriverIdentity])
    }
}

private final class RecordingMachineDriverClaimAdmission:
    LifecycleMachineDriverClaimAdmitting,
    @unchecked Sendable
{
    private let accepted: Bool
    private let lock = NSLock()
    private(set) var identities: [LifecycleProcessIdentity] = []

    init(accepted: Bool) { self.accepted = accepted }

    func authorize(_ identity: LifecycleProcessIdentity) -> Bool {
        lock.withLock { identities.append(identity) }
        return accepted
    }
}

private struct MachineRetirementEscrowFixture {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let claimAt = Date(timeIntervalSince1970: 2_000_000_002)
    let investigationID = LifecycleInvestigationID(
        rawValue: UUID(
            uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
        )!
    )
    let retireOperationID = UUID(
        uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
    )!
    let token = UUID(
        uuidString: "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
    )!
    let challenge = UUID(
        uuidString: "dddddddd-dddd-4ddd-8ddd-dddddddddddd"
    )!
    let configurationSHA256 = String(repeating: "a", count: 64)
    let userID: UInt32 = 501
    let appRecord: LifecycleMachineProcessIdentityRecord
    let helperRecord: LifecycleMachineProcessIdentityRecord
    let machineDriverIdentity: LifecycleProcessIdentity

    init() throws {
        appRecord = try Self.identity(
            processID: 701,
            processIDVersion: 11,
            auditSessionID: 44_001,
            effectiveUserID: userID
        )
        helperRecord = try Self.identity(
            processID: 702,
            processIDVersion: 12,
            auditSessionID: 33_001,
            effectiveUserID: 0
        )
        machineDriverIdentity = LifecycleProcessIdentity(
            processID: 801,
            processIDVersion: 7,
            auditSessionID: 55_001,
            effectiveUserID: 0,
            auditToken: try LifecycleAuditToken(words: [
                0, 0, 0, 0, 0, 801, 55_001, 7,
            ])
        )
    }

    func escrow(
        now: (@Sendable () -> Date)? = nil
    ) -> LifecycleMachineRetirementEscrow {
        let sequence = MachineEscrowSequenceClock(
            values: [self.now, claimAt]
        )
        return LifecycleMachineRetirementEscrow(
            now: now ?? sequence.read,
            token: { token }
        )
    }

    func handle() -> LifecycleMachineRetirementHandle {
        try! LifecycleMachineRetirementHandle(
            token: token,
            investigationID: investigationID,
            retireOperationID: retireOperationID,
            configurationSHA256: configurationSHA256,
            validBefore: now.addingTimeInterval(30)
        )
    }

    func request(
        handle: LifecycleMachineRetirementHandle? = nil
    ) throws -> LifecycleMachineRetirementClaimRequest {
        try LifecycleMachineRetirementClaimRequest(
            handle: handle ?? self.handle(),
            challengeNonce: challenge,
            issuedAt: now.addingTimeInterval(1),
            validBefore: now.addingTimeInterval(11)
        )
    }

    func residue(
        remainingMembers: Int = 0,
        observedAt: Date? = nil
    ) throws
        -> LifecycleInvestigationResidueObservation
    {
        try LifecycleInvestigationResidueObservation(
            investigationID: investigationID,
            auditSessionID: helperRecord.auditSessionID,
            userID: userID,
            observedAt: observedAt ?? now,
            remainingAuditSessionMemberCount: remainingMembers,
            matchingLeaseCount: 0,
            leaseRootEntryCount: 0,
            investigationArtifactCount: 0
        )
    }

    func record(
        into escrow: LifecycleMachineRetirementEscrow,
        owner: LifecycleInteractiveWorkerRetirementObservation =
            .retiredOwnedResources,
        residue: LifecycleInvestigationResidueObservation? = nil,
        appIdentity: LifecycleMachineProcessIdentityRecord? = nil
    ) throws -> LifecycleMachineRetirementHandle {
        try escrow.record(
            investigationID: investigationID,
            retireOperationID: retireOperationID,
            configurationSHA256: configurationSHA256,
            validBefore: now.addingTimeInterval(30),
            appIdentity: appIdentity ?? appRecord,
            helperIdentity: helperRecord,
            userID: userID,
            ownerRetirementObservation: owner,
            residueObservation: residue ?? self.residue()
        )
    }

    private static func identity(
        processID: Int32,
        processIDVersion: Int32,
        auditSessionID: Int32,
        effectiveUserID: UInt32
    ) throws -> LifecycleMachineProcessIdentityRecord {
        try LifecycleMachineProcessIdentityRecord(
            processID: processID,
            processIDVersion: processIDVersion,
            auditSessionID: auditSessionID,
            effectiveUserID: effectiveUserID,
            auditTokenWords: [
                effectiveUserID, effectiveUserID, 0,
                effectiveUserID, 0,
                UInt32(processID), UInt32(auditSessionID),
                UInt32(processIDVersion),
            ]
        )
    }
}

private final class MutableMachineEscrowClock: @unchecked Sendable {
    private let lock = NSLock()
    private var now: Date

    init(now: Date) { self.now = now }

    func read() -> Date { lock.withLock { now } }

    func set(_ value: Date) { lock.withLock { now = value } }
}

private final class MachineEscrowSequenceClock: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Date]

    init(values: [Date]) { self.values = values }

    func read() -> Date {
        lock.withLock {
            guard values.count > 1 else { return values[0] }
            return values.removeFirst()
        }
    }
}
