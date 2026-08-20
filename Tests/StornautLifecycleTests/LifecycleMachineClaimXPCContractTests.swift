import Foundation
import Testing
@testable import StornautLifecycle

@Suite("Lifecycle Machine claim XPC contract")
struct LifecycleMachineClaimXPCContractTests {
    @Test
    func legacyJSONTypesRemainBoundedButAreNotTheLiveWire() throws {
        let fixture = try MachineClaimXPCFixture()
        let encodedRequest = try JSONEncoder().encode(fixture.request)
        let encodedResponse = try JSONEncoder().encode(fixture.response)

        #expect(encodedRequest.count <= 16 * 1_024)
        #expect(encodedResponse.count <= 32 * 1_024)
        let requestObject = try #require(
            JSONSerialization.jsonObject(with: encodedRequest)
                as? [String: Any]
        )
        let requestHandle = try #require(
            requestObject["handle"] as? [String: Any]
        )
        #expect(requestHandle["protocolVersion"] as? Int == 3)
        #expect(requestHandle["validBefore"] == nil)
        #expect(
            (requestHandle["validBeforeUTCMicroseconds"] as? NSNumber)?
                .int64Value == 2_000_000_030_000_000
        )
        let responseObject = try #require(
            JSONSerialization.jsonObject(with: encodedResponse)
                as? [String: Any]
        )
        let echoedRequest = try #require(
            responseObject["request"] as? [String: Any]
        )
        #expect(
            echoedRequest["handle"] as? NSDictionary
                == requestHandle as NSDictionary
        )
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

        #expect(!xpc.contains("LifecycleMachineClaimXPCWire"))
        #expect(!xpc.contains("LifecycleMachineClaimXPCClient"))
        #expect(!xpc.contains("LifecycleMachineClaimXPCServerNamespace"))
        #expect(
            helper.contains(
                "com.eriklee.stornaut.lifecycle.machine-claim"
            )
        )
        #expect(helper.contains("import StornautInvestigationHandoffContract"))
        #expect(helper.contains("import StornautInvestigationMachineClaimServer"))
        #expect(!helper.contains("@objc private protocol LifecycleMachineClaimXPCWire"))
        #expect(helper.contains("InvestigationMachineClaimXPCWire.self"))
        #expect(helper.contains("InvestigationMachineClaimServerSession"))
        #expect(helper.contains("LifecycleMachineClaimListenerDelegate"))
        #expect(!helper.contains("LifecycleMachineClaimHelperService"))
        #expect(helper.contains("LifecycleMachineDriverAdmissionPolicy"))
        #expect(helper.contains("machineClaimListener"))
        #expect(helper.contains("appListener"))
        #expect(!helper.contains("authorized: true"))
        #expect(helper.contains("machineClaimServer.makeSession()"))
        #expect(helper.contains("session.invalidate()"))
        #expect(!xpc.contains("contract.helperExecutableURL"))
        #expect(!xpc.contains("public actor LifecycleMachineClaimXPCClient"))
        #expect(!xpc.contains("LifecycleMachineClaimXPCReplyResolver"))
        #expect(!xpc.contains("LifecycleMachineClaimResult"))
        #expect(!xpc.contains("LifecycleMachineClaimXPCError"))
        #expect(!xpc.contains("proxy as? LifecycleMachineClaimXPCWire"))
    }

    @Test
    func liveServerContractIsHelperOwnedAndHasNoClientAuthority() throws {
        let root = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let lifecycle = try String(
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
        #expect(!lifecycle.contains("LifecycleMachineClaimXPCWire"))
        #expect(!lifecycle.contains("LifecycleMachineClaimXPCClient"))
        #expect(!helper.contains("legacyMachineClaimServiceName"))
        #expect(!helper.contains("LifecycleMachineClaimXPCWire"))
        #expect(!helper.contains("JSONDecoder().decode(\n                LifecycleMachineRetirementClaimRequest.self"))
        #expect(!helper.contains("retirementEscrow.claim("))
        #expect(!helper.contains("LifecycleMachineClaimXPCClient"))
        #expect(!helper.contains("LifecycleMachineClaimXPCReplyResolver"))
        #expect(!helper.contains("remoteObjectProxy"))
    }

    @Test
    func helperOwnsCheckedContinuousClockCancellableSchedulerAndTerminalAction()
        throws
    {
        let root = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let helper = try String(
            contentsOf: root.appending(
                path: "StornautLifecycleHelper/main.swift"
            ),
            encoding: .utf8
        )
        for marker in [
            "struct DarwinInvestigationMachineClaimServerClock",
            "mach_continuous_time()",
            "mach_timebase_info(",
            "multipliedReportingOverflow",
            "addingReportingOverflow",
            "InvestigationMachineClaimServerObservation(",
            "final class DarwinInvestigationMachineClaimServerScheduler",
            "deadlineNanoseconds",
            "final class DarwinInvestigationMachineClaimServerScheduledHandle",
            "func cancel()",
            "enum DarwinInvestigationMachineClaimServerTerminal",
        ] {
            #expect(helper.contains(marker))
        }
        #expect(!helper.contains("scheduleRetirementClaimDeadline("))
        let machineClaimStart = try #require(
            helper.range(of: "private final class LifecycleMachineClaimListenerDelegate")
        )
        let suffix = helper[machineClaimStart.lowerBound...]
        let machineClaimEnd = try #require(
            suffix.range(of: "\nprivate final class LifecycleHelperService")
        )
        let machineClaim = String(suffix[..<machineClaimEnd.lowerBound])
        #expect(!machineClaim.contains("scheduleSuccessfulExitAfterReply"))
        #expect(!machineClaim.contains("scheduleFailureExitAfterReply"))
        #expect(!machineClaim.contains("DispatchQueue.global().asyncAfter"))
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
