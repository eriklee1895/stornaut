import Foundation
import Testing
@testable import StornautLifecycle

@Suite("Lifecycle Interactive Session Contract")
struct LifecycleInteractiveSessionContractTests {
    @Test
    func strictRequestsRoundTripForEveryOperation() throws {
        let fixture = LifecycleInteractiveSessionFixture()
        let requests: [LifecycleInteractiveSessionRequest] = [
            try .start(
                investigationID: fixture.investigationID,
                operationID: fixture.operationID,
                validBefore: fixture.validBefore,
                maximumLineBytes: 1_024,
                maximumSessionBytes: 8_192
            ),
            try .write(
                investigationID: fixture.investigationID,
                operationID: fixture.operationID,
                line: Data("{\"id\":1}\n".utf8)
            ),
            .read(
                investigationID: fixture.investigationID,
                operationID: fixture.operationID
            ),
            .retire(
                investigationID: fixture.investigationID,
                operationID: fixture.operationID
            ),
        ]

        for request in requests {
            let encoded = try JSONEncoder().encode(request)
            #expect(
                try JSONDecoder().decode(
                    LifecycleInteractiveSessionRequest.self,
                    from: encoded
                ) == request
            )
        }
    }

    @Test
    func strictResponsesRoundTripForEveryOutcome() throws {
        let fixture = LifecycleInteractiveSessionFixture()
        let residue = try LifecycleInvestigationResidueObservation(
            investigationID: fixture.investigationID,
            auditSessionID: 44_001,
            userID: 501,
            observedAt: fixture.validBefore.addingTimeInterval(-1),
            remainingAuditSessionMemberCount: 0,
            matchingLeaseCount: 0,
            leaseRootEntryCount: 0,
            investigationArtifactCount: 0
        )
        let responses: [LifecycleInteractiveSessionResponse] = [
            .started(
                investigationID: fixture.investigationID,
                operationID: fixture.operationID
            ),
            .writeAccepted(
                investigationID: fixture.investigationID,
                operationID: fixture.operationID
            ),
            try .line(
                investigationID: fixture.investigationID,
                operationID: fixture.operationID,
                line: Data("{\"result\":{}}\n".utf8)
            ),
            .endOfStream(
                investigationID: fixture.investigationID,
                operationID: fixture.operationID
            ),
            .retired(
                investigationID: fixture.investigationID,
                operationID: fixture.operationID,
                drained: true,
                ownerRetirementObservation: .retiredOwnedResources,
                residueObservation: residue
            ),
        ]

        for response in responses {
            let encoded = try JSONEncoder().encode(response)
            let object = try #require(
                JSONSerialization.jsonObject(with: encoded)
                    as? [String: Any]
            )
            #expect(object["protocolVersion"] as? Int == 3)
            #expect(
                try JSONDecoder().decode(
                    LifecycleInteractiveSessionResponse.self,
                    from: encoded
                ) == response
            )
        }
    }

    @Test
    func ownerRetirementObservationRejectsInconsistentWireFacts() throws {
        let fixture = LifecycleInteractiveSessionFixture()
        for observation in [
            LifecycleInteractiveWorkerRetirementObservation
                .noOwnedResources,
            .retiredPreparedWorkspace,
            .retiredOwnedResources,
        ] {
            let encoded = try JSONEncoder().encode(observation)
            #expect(
                try JSONDecoder().decode(
                    LifecycleInteractiveWorkerRetirementObservation.self,
                    from: encoded
                ) == observation
            )
        }

        let inconsistent: [[String: Any]] = [
            [
                "resourceOwnership": "owned",
                "processGroupTerminated": false,
                "standardErrorContained": true,
                "workspaceRemoved": true,
            ],
            [
                "resourceOwnership": "none",
                "processGroupTerminated": true,
                "standardErrorContained": false,
                "workspaceRemoved": false,
            ],
            [
                "resourceOwnership": "preparedWorkspace",
                "processGroupTerminated": true,
                "standardErrorContained": false,
                "workspaceRemoved": true,
            ],
        ]
        for object in inconsistent {
            #expect(throws: DecodingError.self) {
                _ = try JSONDecoder().decode(
                    LifecycleInteractiveWorkerRetirementObservation.self,
                    from: try JSONSerialization.data(withJSONObject: object)
                )
            }
        }

        var unknown = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(
                    LifecycleInteractiveWorkerRetirementObservation
                        .retiredOwnedResources
                )
            ) as? [String: Any]
        )
        unknown["unexpected"] = true
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                LifecycleInteractiveWorkerRetirementObservation.self,
                from: try JSONSerialization.data(withJSONObject: unknown)
            )
        }

        let retired = LifecycleInteractiveSessionResponse.retired(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID,
            drained: true,
            ownerRetirementObservation: .retiredOwnedResources
        )
        let encoded = try JSONEncoder().encode(retired)
        var responseObject = try #require(
            JSONSerialization.jsonObject(with: encoded)
                as? [String: Any]
        )
        responseObject.removeValue(forKey: "ownerRetirementObservation")
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                LifecycleInteractiveSessionResponse.self,
                from: try JSONSerialization.data(
                    withJSONObject: responseObject
                )
            )
        }

    }

    @Test
    func residueObservationIsStrictIdentityBoundAndCanonical() throws {
        let fixture = LifecycleInteractiveSessionFixture()
        let observation = try LifecycleInvestigationResidueObservation(
            investigationID: fixture.investigationID,
            auditSessionID: 44_001,
            userID: 501,
            observedAt: fixture.validBefore.addingTimeInterval(-1),
            remainingAuditSessionMemberCount: 0,
            matchingLeaseCount: 0,
            leaseRootEntryCount: 0,
            investigationArtifactCount: 0
        )
        #expect(observation.provedEmpty)
        let encoded = try JSONEncoder().encode(observation)
        #expect(
            try JSONDecoder().decode(
                LifecycleInvestigationResidueObservation.self,
                from: encoded
            ) == observation
        )

        var object = try #require(
            JSONSerialization.jsonObject(with: encoded)
                as? [String: Any]
        )
        object["unexpected"] = true
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                LifecycleInvestigationResidueObservation.self,
                from: try JSONSerialization.data(withJSONObject: object)
            )
        }

        #expect(throws: LifecycleInteractiveSessionContractError.self) {
            _ = try LifecycleInvestigationResidueObservation(
                investigationID: fixture.investigationID,
                auditSessionID: 0,
                userID: 501,
                observedAt: fixture.validBefore,
                remainingAuditSessionMemberCount: 0,
                matchingLeaseCount: 0,
                leaseRootEntryCount: 0,
                investigationArtifactCount: 0
            )
        }
    }

    @Test
    func rootHelperSealsResidueAfterCleanupBeforeStateRelease() throws {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let helperURL = repositoryRoot.appending(
            path: "StornautLifecycleHelper/main.swift"
        )
        let source = try String(contentsOf: helperURL, encoding: .utf8)
        let functionStart = try #require(
            source.range(
                of: "private func finishInteractiveSession() throws"
            )
        )
        let suffix = source[functionStart.lowerBound...]
        let functionEnd = try #require(
            suffix.range(of: "\n    }\n#endif")
        )
        let body = String(suffix[..<functionEnd.upperBound])

        let removeRoot = try #require(
            body.range(of: "try removeDiagnosticRoot(")
        )
        let removeLease = try #require(
            body.range(of: ".remove(investigationID)")
        )
        let observation = try #require(
            body.range(of: "makeResidueObservation(")
        )
        let zeroGuard = try #require(
            body.range(of: "guard residueObservation.provedEmpty")
        )
        let stateRelease = try #require(
            body.range(of: "activeInvestigationID = nil")
        )
        #expect(removeRoot.lowerBound < observation.lowerBound)
        #expect(removeLease.lowerBound < observation.lowerBound)
        #expect(observation.lowerBound < stateRelease.lowerBound)
        #expect(observation.lowerBound < zeroGuard.lowerBound)
        #expect(zeroGuard.lowerBound < stateRelease.lowerBound)

        let retireBranch = try #require(
            source.range(
                of: "if pending.request.kind == .retire {"
            )
        )
        let retireSuffix = source[retireBranch.lowerBound...]
        let nextBranch = try #require(
            retireSuffix.range(of: "\n        do {\n            pending.reply(")
        )
        let retireBody = String(
            retireSuffix[..<nextBranch.lowerBound]
        )
        #expect(retireBody.contains("let residueObservation"))
        #expect(retireBody.contains(".retired("))
        #expect(!retireBody.contains("encode(validated)"))
    }

    @Test
    func workerReplyRejectsUnknownMissingAndAmbiguousPayloads() throws {
        let fixture = LifecycleInteractiveSessionFixture()
        let response = LifecycleInteractiveSessionResponse.started(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID
        )
        let reply = LifecycleInteractiveWorkerReply(
            operationID: fixture.operationID,
            response: response
        )
        let encoded = try JSONEncoder().encode(reply)
        #expect(
            try JSONDecoder().decode(
                LifecycleInteractiveWorkerReply.self,
                from: encoded
            ) == reply
        )
        var object = try #require(
            JSONSerialization.jsonObject(with: encoded)
                as? [String: Any]
        )
        object["unexpected"] = true
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                LifecycleInteractiveWorkerReply.self,
                from: try JSONSerialization.data(withJSONObject: object)
            )
        }
        object.removeValue(forKey: "unexpected")
        object.removeValue(forKey: "operationID")
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                LifecycleInteractiveWorkerReply.self,
                from: try JSONSerialization.data(withJSONObject: object)
            )
        }
        object["operationID"] = fixture.operationID.uuidString
        object["reasonKey"] =
            "runtime.lifecycle.interactive.retire-failed"
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                LifecycleInteractiveWorkerReply.self,
                from: try JSONSerialization.data(withJSONObject: object)
            )
        }
        object["response"] = NSNull()
        object["reasonKey"] = NSNull()
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                LifecycleInteractiveWorkerReply.self,
                from: try JSONSerialization.data(withJSONObject: object)
            )
        }
    }

    @Test
    func requestDecoderRejectsUnknownMissingAndCrossOperationFields()
        throws
    {
        let fixture = LifecycleInteractiveSessionFixture()
        let valid = try JSONEncoder().encode(
            LifecycleInteractiveSessionRequest.read(
                investigationID: fixture.investigationID,
                operationID: fixture.operationID
            )
        )
        let object = try #require(
            JSONSerialization.jsonObject(with: valid)
                as? [String: Any]
        )

        var unknown = object
        unknown["unexpected"] = true
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                LifecycleInteractiveSessionRequest.self,
                from: try JSONSerialization.data(withJSONObject: unknown)
            )
        }

        var missing = object
        missing.removeValue(forKey: "operationID")
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                LifecycleInteractiveSessionRequest.self,
                from: try JSONSerialization.data(withJSONObject: missing)
            )
        }

        var crossOperation = object
        crossOperation["line"] = Data("{}\n".utf8).base64EncodedString()
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                LifecycleInteractiveSessionRequest.self,
                from: try JSONSerialization.data(
                    withJSONObject: crossOperation
                )
            )
        }
    }

    @Test
    func lineAndBoundValidationFailClosed() throws {
        let fixture = LifecycleInteractiveSessionFixture()

        #expect(
            throws: LifecycleInteractiveSessionContractError
                .invalidRequest
        ) {
            _ = try LifecycleInteractiveSessionRequest.start(
                investigationID: fixture.investigationID,
                operationID: fixture.operationID,
                validBefore: Date(timeIntervalSince1970: .infinity),
                maximumLineBytes: 1_024,
                maximumSessionBytes: 8_192
            )
        }
        #expect(
            throws: LifecycleInteractiveSessionContractError
                .invalidRequest
        ) {
            _ = try LifecycleInteractiveSessionRequest.start(
                investigationID: fixture.investigationID,
                operationID: fixture.operationID,
                validBefore: fixture.validBefore,
                maximumLineBytes: 0,
                maximumSessionBytes: 8_192
            )
        }
        #expect(
            throws: LifecycleInteractiveSessionContractError
                .invalidRequest
        ) {
            _ = try LifecycleInteractiveSessionRequest.write(
                investigationID: fixture.investigationID,
                operationID: fixture.operationID,
                line: Data("{}".utf8)
            )
        }
        #expect(
            throws: LifecycleInteractiveSessionContractError
                .invalidRequest
        ) {
            _ = try LifecycleInteractiveSessionRequest.write(
                investigationID: fixture.investigationID,
                operationID: fixture.operationID,
                line: Data([0x7B, 0x00, 0x7D, 0x0A])
            )
        }
        #expect(
            throws: LifecycleInteractiveSessionContractError
                .invalidResponse
        ) {
            _ = try LifecycleInteractiveSessionResponse.line(
                investigationID: fixture.investigationID,
                operationID: fixture.operationID,
                line: Data("\n".utf8)
            )
        }
    }

    @Test
    func responseIdentityMustMatchTheExactRequest() throws {
        let fixture = LifecycleInteractiveSessionFixture()
        let request = LifecycleInteractiveSessionRequest.read(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID
        )
        let matching = try LifecycleInteractiveSessionResponse.line(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID,
            line: Data("{\"method\":\"turn/started\"}\n".utf8)
        )
        #expect(try matching.validated(for: request) == matching)

        let foreign = try LifecycleInteractiveSessionResponse.line(
            investigationID: fixture.investigationID,
            operationID: UUID(),
            line: Data("{\"method\":\"turn/started\"}\n".utf8)
        )
        #expect(
            throws: LifecycleInteractiveSessionContractError
                .identityMismatch
        ) {
            _ = try foreign.validated(for: request)
        }
    }

    @Test
    func interactiveXPCReplyResolverCompletesExactlyOnce() async throws {
        let fixture = LifecycleInteractiveSessionFixture()
        let request = LifecycleInteractiveSessionRequest.read(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID
        )
        let response = try LifecycleInteractiveSessionResponse.line(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID,
            line: Data("{\"method\":\"turn/started\"}\n".utf8)
        )
        let encoded = try JSONEncoder().encode(response)

        let value: LifecycleInteractiveSessionResponse =
            try await withCheckedThrowingContinuation { continuation in
                let resolver =
                    LifecycleInteractiveSessionXPCReplyResolver(
                        request: request,
                        continuation: continuation
                    )
                resolver.resolve(response: encoded, reasonKey: nil)
                resolver.failConnection()
                resolver.resolve(response: encoded, reasonKey: nil)
            }

        #expect(value == response)
    }

    @Test
    func interactiveXPCReplyResolverRejectsForeignAndMalformedResponses()
        async
    {
        let fixture = LifecycleInteractiveSessionFixture()
        let request = LifecycleInteractiveSessionRequest.read(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID
        )
        let foreign = try! LifecycleInteractiveSessionResponse.line(
            investigationID: fixture.investigationID,
            operationID: UUID(),
            line: Data("{\"method\":\"turn/started\"}\n".utf8)
        )

        await #expect(
            throws: LifecycleInteractiveSessionXPCError.invalidResponse
        ) {
            _ = try await withCheckedThrowingContinuation {
                continuation in
                LifecycleInteractiveSessionXPCReplyResolver(
                    request: request,
                    continuation: continuation
                ).resolve(
                    response: try! JSONEncoder().encode(foreign),
                    reasonKey: nil
                )
            } as LifecycleInteractiveSessionResponse
        }

        await #expect(
            throws: LifecycleInteractiveSessionXPCError.invalidResponse
        ) {
            _ = try await withCheckedThrowingContinuation {
                continuation in
                LifecycleInteractiveSessionXPCReplyResolver(
                    request: request,
                    continuation: continuation
                ).resolve(
                    response: Data("not-json".utf8),
                    reasonKey: nil
                )
            } as LifecycleInteractiveSessionResponse
        }
    }

    @Test
    func maximumValidLineFitsTheEncodedXPCEnvelope() throws {
        let fixture = LifecycleInteractiveSessionFixture()
        var line = Data(
            repeating: 0x61,
            count:
                LifecycleInteractiveSessionRequest
                    .maximumAllowedLineBytes
        )
        line[line.index(before: line.endIndex)] = 0x0A
        let response = try LifecycleInteractiveSessionResponse.line(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID,
            line: line
        )

        #expect(
            try JSONEncoder().encode(response).count
                <= LifecycleInteractiveSessionRequest
                    .maximumEncodedEnvelopeBytes
        )
    }

    @Test
    func interactiveXPCReplyResolverTimesOutExactlyOnce() async {
        let fixture = LifecycleInteractiveSessionFixture()
        let request = LifecycleInteractiveSessionRequest.read(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID
        )

        await #expect(
            throws: LifecycleInteractiveSessionXPCError.timedOut
        ) {
            _ = try await withCheckedThrowingContinuation {
                continuation in
                let resolver =
                    LifecycleInteractiveSessionXPCReplyResolver(
                        request: request,
                        continuation: continuation
                    )
                resolver.scheduleTimeout(seconds: 0)
                resolver.failConnection()
            } as LifecycleInteractiveSessionResponse
        }
    }

    @Test
    func interactiveXPCReplyResolverOrdersCancellationBeforeDispatch() async {
        let fixture = LifecycleInteractiveSessionFixture()
        let request = LifecycleInteractiveSessionRequest.read(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID
        )

        await #expect(
            throws: LifecycleInteractiveSessionXPCError.cancelled
        ) {
            _ = try await withCheckedThrowingContinuation {
                continuation in
                let resolver =
                    LifecycleInteractiveSessionXPCReplyResolver(
                        request: request,
                        continuation: continuation
                    )
                resolver.failCancellation()
                #expect(!resolver.beginDispatch())
            } as LifecycleInteractiveSessionResponse
        }
    }

    @Test
    func interactiveXPCReplyResolverIgnoresCancellationAfterDispatchCommit()
        async throws
    {
        let fixture = LifecycleInteractiveSessionFixture()
        let request = LifecycleInteractiveSessionRequest.read(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID
        )
        let response = try LifecycleInteractiveSessionResponse.line(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID,
            line: Data("{\"id\":1,\"result\":{}}\n".utf8)
        )
        let encoded = try JSONEncoder().encode(response)

        let value: LifecycleInteractiveSessionResponse =
            try await withCheckedThrowingContinuation { continuation in
                let resolver =
                    LifecycleInteractiveSessionXPCReplyResolver(
                        request: request,
                        continuation: continuation
                    )
                #expect(resolver.beginDispatch())
                resolver.failCancellation()
                resolver.resolve(response: encoded, reasonKey: nil)
            }

        #expect(value == response)
    }

    @Test
    func interactiveXPCReplyResolverKeepsRetirementCancellationShielded()
        async throws
    {
        let fixture = LifecycleInteractiveSessionFixture()
        let request = LifecycleInteractiveSessionRequest.retire(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID
        )
        let response = LifecycleInteractiveSessionResponse.retired(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID,
            drained: true,
            ownerRetirementObservation: .noOwnedResources
        )
        let encoded = try JSONEncoder().encode(response)

        let value: LifecycleInteractiveSessionResponse =
            try await withCheckedThrowingContinuation { continuation in
                let resolver =
                    LifecycleInteractiveSessionXPCReplyResolver(
                        request: request,
                        continuation: continuation
                    )
                resolver.failCancellation()
                resolver.resolve(response: encoded, reasonKey: nil)
            }

        #expect(value == response)
    }

    @Test
    func interactiveXPCReplyResolverSanitizesRemoteRejection() async {
        let fixture = LifecycleInteractiveSessionFixture()
        let request = LifecycleInteractiveSessionRequest.retire(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID
        )

        await #expect(
            throws:
                LifecycleInteractiveSessionXPCError.remoteRejected(
                    reasonKey:
                        "runtime.lifecycle.interactive.retire-failed"
                )
        ) {
            _ = try await withCheckedThrowingContinuation {
                continuation in
                LifecycleInteractiveSessionXPCReplyResolver(
                    request: request,
                    continuation: continuation
                ).resolve(
                    response: nil,
                    reasonKey:
                        "runtime.lifecycle.interactive.retire-failed"
                )
            } as LifecycleInteractiveSessionResponse
        }

        await #expect(
            throws: LifecycleInteractiveSessionXPCError.remoteRejected(
                reasonKey: "runtime.lifecycle.interactive.remote-rejected"
            )
        ) {
            _ = try await withCheckedThrowingContinuation {
                continuation in
                LifecycleInteractiveSessionXPCReplyResolver(
                    request: request,
                    continuation: continuation
                ).resolve(
                    response: nil,
                    reasonKey: "secret /Users/example token=abc"
                )
            } as LifecycleInteractiveSessionResponse
        }

        await #expect(
            throws: LifecycleInteractiveSessionXPCError.remoteRejected(
                reasonKey: "runtime.lifecycle.interactive.remote-rejected"
            )
        ) {
            _ = try await withCheckedThrowingContinuation {
                continuation in
                LifecycleInteractiveSessionXPCReplyResolver(
                    request: request,
                    continuation: continuation
                ).resolve(
                    response: nil,
                    reasonKey:
                        "runtime.lifecycle.interactive.token-abc123"
                )
            } as LifecycleInteractiveSessionResponse
        }
    }

    @Test
    func interactiveXPCReplyResolverPreservesBoundedLimitCategories()
        async
    {
        let fixture = LifecycleInteractiveSessionFixture()
        let request = LifecycleInteractiveSessionRequest.read(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID
        )
        for reasonKey in [
            "runtime.lifecycle.interactive.session-expired",
            "runtime.lifecycle.interactive.line-limit-exceeded",
            "runtime.lifecycle.interactive.session-limit-exceeded",
        ] {
            await #expect(
                throws:
                    LifecycleInteractiveSessionXPCError.remoteRejected(
                        reasonKey: reasonKey
                    )
            ) {
                _ = try await withCheckedThrowingContinuation {
                    continuation in
                    LifecycleInteractiveSessionXPCReplyResolver(
                        request: request,
                        continuation: continuation
                    ).resolve(
                        response: nil,
                        reasonKey: reasonKey
                    )
                } as LifecycleInteractiveSessionResponse
            }
        }
    }
}

private struct LifecycleInteractiveSessionFixture {
    let investigationID = LifecycleInvestigationID(
        rawValue: UUID(
            uuidString: "91919191-9191-4191-8191-919191919191"
        )!
    )
    let operationID = UUID(
        uuidString: "92929292-9292-4292-8292-929292929292"
    )!
    let validBefore = Date(timeIntervalSince1970: 2_000_000_000)
}
