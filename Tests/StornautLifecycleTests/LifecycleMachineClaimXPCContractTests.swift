import Foundation
import Testing
@testable import StornautLifecycle

@Suite("Lifecycle Machine claim XPC contract")
struct LifecycleMachineClaimXPCContractTests {
    @Test
    func claimWireHasOneStrictSelectorAndBoundedEcho() throws {
        let fixture = try MachineClaimXPCFixture()
        let encodedRequest = try JSONEncoder().encode(fixture.request)
        let encodedResponse = try JSONEncoder().encode(fixture.response)

        #expect(
            LifecycleMachineClaimXPCClient.serviceName
                == "com.eriklee.stornaut.lifecycle.machine-claim"
        )
        #expect(encodedRequest.count <= 16 * 1_024)
        #expect(encodedResponse.count <= 32 * 1_024)
        #expect(
            try JSONDecoder().decode(
                LifecycleMachineRetirementClaimRequest.self,
                from: encodedRequest
            ) == fixture.request
        )
        #expect(
            try JSONDecoder().decode(
                LifecycleMachineRetirementClaimResponse.self,
                from: encodedResponse
            ) == fixture.response
        )
    }

    @Test
    func sourceKeepsAppAndMachineClaimRolesPhysicallySeparate() throws {
        let root = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let xpc = try String(
            contentsOf: root.appending(
                path: "Sources/StornautLifecycle/LifecycleSupervisorXPC.swift"
            ),
            encoding: .utf8
        )
        let helper = try String(
            contentsOf: root.appending(
                path: "StornautLifecycleHelper/main.swift"
            ),
            encoding: .utf8
        )

        #expect(xpc.contains("@objc public protocol LifecycleMachineClaimXPCWire"))
        #expect(xpc.contains("func claimMachineRetirement("))
        #expect(xpc.contains("public actor LifecycleMachineClaimXPCClient"))
        #expect(
            xpc.contains(
                "com.eriklee.stornaut.lifecycle.machine-claim"
            )
        )
        #expect(helper.contains("LifecycleMachineClaimListenerDelegate"))
        #expect(helper.contains("LifecycleMachineClaimHelperService"))
        #expect(helper.contains("LifecycleMachineDriverAdmissionPolicy"))
        #expect(helper.contains("machineClaimListener"))
        #expect(helper.contains("appListener"))
        #expect(!helper.contains("authorized: true"))
        let claimStart = try #require(
            helper.range(of: "func claimMachineRetirement(")
        )
        let claimSuffix = helper[claimStart.lowerBound...]
        let claimEnd = try #require(
            claimSuffix.range(of: "\n    func invalidate()")
        )
        let claimBody = claimSuffix[..<claimEnd.lowerBound]
        #expect(!claimBody.contains("scheduleSuccessfulExitAfterReply"))
        #expect(
            xpc.contains(
                "contract.helperExecutableURL"
            )
        )
        let resolverStart = try #require(
            xpc.range(of: "final class LifecycleMachineClaimXPCReplyResolver:")
        )
        let resolverSuffix = xpc[resolverStart.lowerBound...]
        let resolverEnd = try #require(
            resolverSuffix.range(
                of: "\nfinal class LifecycleHelperPeerAttestationReplyResolver:"
            )
        )
        let resolverBody = resolverSuffix[..<resolverEnd.lowerBound]
        #expect(!resolverBody.contains("transportFailure("))
        #expect(resolverBody.contains("finishTransportFailure("))
        #expect(resolverBody.contains("dispatchBegan ? .outcomeUnknown"))
    }

    @Test
    func postDispatchTransportFailureIsOutcomeUnknown() async {
        await #expect(
            throws: LifecycleMachineClaimXPCError.connectionFailed
        ) {
            _ = try await withCheckedThrowingContinuation { continuation in
                let resolver = LifecycleMachineClaimXPCReplyResolver()
                #expect(resolver.install(continuation))
                resolver.failConnection()
            } as LifecycleMachineRetirementClaimResponse
        }

        await #expect(
            throws: LifecycleMachineClaimXPCError.outcomeUnknown
        ) {
            _ = try await withCheckedThrowingContinuation { continuation in
                let resolver = LifecycleMachineClaimXPCReplyResolver()
                #expect(resolver.install(continuation))
                #expect(resolver.beginDispatch())
                resolver.failConnection()
            } as LifecycleMachineRetirementClaimResponse
        }

        await #expect(
            throws: LifecycleMachineClaimXPCError.outcomeUnknown
        ) {
            _ = try await withCheckedThrowingContinuation { continuation in
                let resolver = LifecycleMachineClaimXPCReplyResolver()
                #expect(resolver.install(continuation))
                #expect(resolver.beginDispatch())
                resolver.resolve(
                    response: Data("not-json".utf8),
                    reasonKey: nil
                )
            } as LifecycleMachineRetirementClaimResponse
        }

        await #expect(
            throws: LifecycleMachineClaimXPCError.outcomeUnknown
        ) {
            _ = try await withCheckedThrowingContinuation { continuation in
                let resolver = LifecycleMachineClaimXPCReplyResolver()
                #expect(resolver.install(continuation))
                #expect(resolver.beginDispatch())
                resolver.failTimeout()
            } as LifecycleMachineRetirementClaimResponse
        }
    }
}

private struct MachineClaimXPCFixture {
    let request: LifecycleMachineRetirementClaimRequest
    let response: LifecycleMachineRetirementClaimResponse

    init() throws {
        let investigationID = LifecycleInvestigationID(
            rawValue: UUID(
                uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
            )!
        )
        let handle = try LifecycleMachineRetirementHandle(
            token: UUID(
                uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
            )!,
            investigationID: investigationID,
            retireOperationID: UUID(
                uuidString: "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
            )!,
            configurationSHA256: String(repeating: "a", count: 64),
            validBefore: Date(timeIntervalSince1970: 2_000_000_030)
        )
        request = try LifecycleMachineRetirementClaimRequest(
            handle: handle,
            challengeNonce: UUID(
                uuidString: "dddddddd-dddd-4ddd-8ddd-dddddddddddd"
            )!,
            issuedAt: Date(timeIntervalSince1970: 2_000_000_001),
            validBefore: Date(timeIntervalSince1970: 2_000_000_011)
        )
        let app = try Self.record(
            processID: 701,
            processIDVersion: 11,
            auditSessionID: 44_001,
            effectiveUserID: 501
        )
        let helper = try Self.record(
            processID: 702,
            processIDVersion: 12,
            auditSessionID: 33_001,
            effectiveUserID: 0
        )
        response = try LifecycleMachineRetirementClaimResponse(
            request: request,
            appIdentity: app,
            helperIdentity: helper,
            userID: 501,
            recordedAt: Date(timeIntervalSince1970: 2_000_000_000),
            claimedAt: Date(timeIntervalSince1970: 2_000_000_002),
            ownerRetirementObservation: .retiredOwnedResources,
            residueObservation: LifecycleInvestigationResidueObservation(
                investigationID: investigationID,
                auditSessionID: helper.auditSessionID,
                userID: 501,
                observedAt: Date(timeIntervalSince1970: 2_000_000_000),
                remainingAuditSessionMemberCount: 0,
                matchingLeaseCount: 0,
                leaseRootEntryCount: 0,
                investigationArtifactCount: 0
            )
        )
    }

    private static func record(
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
                effectiveUserID, 0, UInt32(processID),
                UInt32(auditSessionID), UInt32(processIDVersion),
            ]
        )
    }
}
