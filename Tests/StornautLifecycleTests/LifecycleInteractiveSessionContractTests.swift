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
                drained: true
            ),
        ]

        for response in responses {
            let encoded = try JSONEncoder().encode(response)
            #expect(
                try JSONDecoder().decode(
                    LifecycleInteractiveSessionResponse.self,
                    from: encoded
                ) == response
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
            drained: true
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
