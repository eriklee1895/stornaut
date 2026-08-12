import Darwin
import Foundation
import Testing
@testable import StornautLifecycle

@Suite("Lifecycle supervisor closed contract")
struct LifecycleSupervisorContractTests {
    @Test
    func acceptsOnlyAuthenticatedStartAndCancelRequests() throws {
        let authorizer = RecordingLifecycleCallerAuthorizer(
            authorizedIdentity: LifecycleCallerIdentity(
                processID: 701,
                effectiveUserID: 501,
                signingIdentifier: "com.eriklee.stornaut"
            )
        )
        let dispatcher = RecordingLifecycleOperationDispatcher()
        let contract = LifecycleSupervisorContract(
            authorizer: authorizer,
            dispatcher: dispatcher
        )
        let start = LifecycleSupervisorRequest.start(
            LifecycleInvestigationID(
                rawValue: UUID(
                    uuidString: "11111111-2222-3333-4444-555555555555"
                )!
            )
        )
        let caller = authorizer.authorizedIdentity

        let startResponse = try contract.handle(
            start,
            caller: caller
        )
        let cancelResponse = try contract.handle(
            .cancel(start.investigationID),
            caller: caller
        )

        #expect(startResponse == .accepted)
        #expect(cancelResponse == .accepted)
        #expect(dispatcher.operations == [
            .start(
                start.investigationID,
                requestingUserID: 501
            ),
            .cancel(
                start.investigationID,
                requestingUserID: 501
            ),
        ])
    }

    @Test
    func rejectsUnauthorizedCallerBeforeDispatch() {
        let authorizer = RecordingLifecycleCallerAuthorizer(
            authorizedIdentity: LifecycleCallerIdentity(
                processID: 701,
                effectiveUserID: 501,
                signingIdentifier: "com.eriklee.stornaut"
            )
        )
        let dispatcher = RecordingLifecycleOperationDispatcher()
        let contract = LifecycleSupervisorContract(
            authorizer: authorizer,
            dispatcher: dispatcher
        )

        #expect(throws: LifecycleSupervisorContractError.unauthorizedCaller) {
            _ = try contract.handle(
                .start(LifecycleInvestigationID()),
                caller: LifecycleCallerIdentity(
                    processID: 702,
                    effectiveUserID: 501,
                    signingIdentifier: "untrusted.codex.descendant"
                )
            )
        }
        #expect(authorizer.checkedIdentities.count == 1)
        #expect(dispatcher.operations.isEmpty)
    }

    @Test(arguments: [
        LifecycleCallerIdentity(
            processID: 1,
            effectiveUserID: 501,
            signingIdentifier: "com.eriklee.stornaut"
        ),
        LifecycleCallerIdentity(
            processID: 701,
            effectiveUserID: 0,
            signingIdentifier: "com.eriklee.stornaut"
        ),
        LifecycleCallerIdentity(
            processID: 701,
            effectiveUserID: 501,
            signingIdentifier: ""
        ),
        LifecycleCallerIdentity(
            processID: 701,
            effectiveUserID: 501,
            signingIdentifier: "com.eriklee.stornaut\ninjected"
        ),
    ])
    func rejectsMalformedCallerIdentityBeforeAuthorization(
        caller: LifecycleCallerIdentity
    ) {
        let authorizer = RecordingLifecycleCallerAuthorizer(
            authorizedIdentity: caller
        )
        let dispatcher = RecordingLifecycleOperationDispatcher()
        let contract = LifecycleSupervisorContract(
            authorizer: authorizer,
            dispatcher: dispatcher
        )

        #expect(
            throws: LifecycleSupervisorContractError.invalidCallerIdentity
        ) {
            _ = try contract.handle(
                .start(LifecycleInvestigationID()),
                caller: caller
            )
        }
        #expect(authorizer.checkedIdentities.isEmpty)
        #expect(dispatcher.operations.isEmpty)
    }

    @Test
    func wireRequestHasNoPidSignalExecutableArgumentOrPathSurface() throws {
        let request = LifecycleSupervisorRequest.start(
            LifecycleInvestigationID(
                rawValue: UUID(
                    uuidString: "11111111-2222-3333-4444-555555555555"
                )!
            )
        )
        let data = try JSONEncoder().encode(request)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(Set(object.keys) == [
            "investigationID",
            "protocolVersion",
            "type",
        ])
        #expect(object["protocolVersion"] as? Int == 1)
        #expect(object["type"] as? String == "start")
        for forbidden in [
            "auditSessionID",
            "pid",
            "signal",
            "executable",
            "arguments",
            "argv",
            "path",
            "lease",
            "trash",
            "executor",
            "policy",
        ] {
            #expect(!String(decoding: data, as: UTF8.self)
                .localizedCaseInsensitiveContains(forbidden))
        }
    }

    @Test
    func decoderRejectsUnknownFieldsVersionsAndCommands() {
        for object: [String: Any] in [
            [
                "protocolVersion": 2,
                "type": "start",
                "investigationID": UUID().uuidString,
            ],
            [
                "protocolVersion": 1,
                "type": "spawn",
                "investigationID": UUID().uuidString,
            ],
            [
                "protocolVersion": 1,
                "type": "start",
                "investigationID": UUID().uuidString,
                "executable": "/bin/sh",
            ],
            [
                "protocolVersion": 1,
                "type": "cancel",
                "investigationID": "not-a-uuid",
            ],
        ] {
            let data = try! JSONSerialization.data(withJSONObject: object)
            #expect(throws: DecodingError.self) {
                _ = try JSONDecoder().decode(
                    LifecycleSupervisorRequest.self,
                    from: data
                )
            }
        }
    }
}

private final class RecordingLifecycleCallerAuthorizer:
    LifecycleCallerAuthorizing,
    @unchecked Sendable
{
    let authorizedIdentity: LifecycleCallerIdentity
    private let lock = NSLock()
    private(set) var checkedIdentities: [LifecycleCallerIdentity] = []

    init(authorizedIdentity: LifecycleCallerIdentity) {
        self.authorizedIdentity = authorizedIdentity
    }

    func authorize(_ caller: LifecycleCallerIdentity) -> Bool {
        lock.withLock { checkedIdentities.append(caller) }
        return caller == authorizedIdentity
    }
}

private final class RecordingLifecycleOperationDispatcher:
    LifecycleOperationDispatching,
    @unchecked Sendable
{
    private let lock = NSLock()
    private(set) var operations: [LifecycleSupervisorOperation] = []

    func dispatch(
        _ operation: LifecycleSupervisorOperation
    ) throws -> LifecycleSupervisorResponse {
        lock.withLock { operations.append(operation) }
        return .accepted
    }
}
