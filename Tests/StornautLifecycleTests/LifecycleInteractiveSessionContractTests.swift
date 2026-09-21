import Foundation
import Testing
@testable import StornautLifecycle

@Suite("Lifecycle Interactive Session Contract")
struct LifecycleInteractiveSessionContractTests {
    @Test
    func startEnvelopeAndResponseBindCanonicalNativeDigest() throws {
        let fixture = LifecycleInteractiveSessionFixture()
        let request = try LifecycleInteractiveSessionRequest.start(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID,
            configurationSHA256: fixture.configurationSHA256,
            codexExecutableSHA256: fixture.codexExecutableSHA256,
            validBefore: fixture.validBefore,
            maximumLineBytes: 1_024,
            maximumSessionBytes: 8_192
        )
        let requestObject = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(request)
            ) as? [String: Any]
        )
        #expect(requestObject["protocolVersion"] as? Int == 3)
        #expect(
            requestObject["codexExecutableSHA256"] as? String
                == fixture.codexExecutableSHA256
        )

        let response = try LifecycleInteractiveSessionResponse.started(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID,
            codexExecutableSHA256: fixture.codexExecutableSHA256
        )
        let responseObject = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(response)
            ) as? [String: Any]
        )
        #expect(responseObject["protocolVersion"] as? Int == 5)
        #expect(
            responseObject["codexExecutableSHA256"] as? String
                == fixture.codexExecutableSHA256
        )

        #expect(try response.validated(for: request) == response)
    }

    @Test
    func strictRequestsRoundTripForEveryOperation() throws {
        let fixture = LifecycleInteractiveSessionFixture()
        let requests: [LifecycleInteractiveSessionRequest] = [
            try .start(
                investigationID: fixture.investigationID,
                operationID: fixture.operationID,
                configurationSHA256: fixture.configurationSHA256,
                codexExecutableSHA256: fixture.codexExecutableSHA256,
                validBefore: fixture.validBefore,
                maximumLineBytes: 1_024,
                maximumSessionBytes: 8_192
            ),
            try .write(
                investigationID: fixture.investigationID,
                operationID: fixture.operationID,
                configurationSHA256: fixture.configurationSHA256,
                line: Data("{\"id\":1}\n".utf8)
            ),
            try .read(
                investigationID: fixture.investigationID,
                operationID: fixture.operationID,
                configurationSHA256: fixture.configurationSHA256
            ),
            try .retire(
                investigationID: fixture.investigationID,
                operationID: fixture.operationID,
                configurationSHA256: fixture.configurationSHA256
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
            try .started(
                investigationID: fixture.investigationID,
                operationID: fixture.operationID,
                codexExecutableSHA256: fixture.codexExecutableSHA256
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
            #expect(object["protocolVersion"] as? Int == 5)
            #expect(
                try JSONDecoder().decode(
                    LifecycleInteractiveSessionResponse.self,
                    from: encoded
                ) == response
            )
        }
    }

    @Test
    func retiredResponsePreservesExactV3RetirementHandleJSON() throws {
        let fixture = LifecycleInteractiveSessionFixture()
        let input = Date(
            timeIntervalSince1970: 2_000_000_030.000_249_9
        )
        let expectedMicroseconds = Int64(
            (input.timeIntervalSince1970 * 1_000_000).rounded(.down)
        )
        let handle = try LifecycleMachineRetirementHandle(
            token: UUID(
                uuidString: "93939393-9393-4393-8393-939393939393"
            )!,
            investigationID: fixture.investigationID,
            retireOperationID: fixture.operationID,
            configurationSHA256: fixture.configurationSHA256,
            validBefore: input
        )
        let response = LifecycleInteractiveSessionResponse.retired(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID,
            drained: true,
            ownerRetirementObservation: .retiredOwnedResources,
            machineRetirementHandle: handle
        )

        let encoded = try JSONEncoder().encode(response)
        let object = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        let nested = try #require(
            object["machineRetirementHandle"] as? [String: Any]
        )
        #expect(nested["protocolVersion"] as? Int == 3)
        #expect(nested["validBefore"] == nil)
        #expect(
            (nested["validBeforeUTCMicroseconds"] as? NSNumber)?.int64Value
                == expectedMicroseconds
        )
        #expect(
            try JSONDecoder().decode(
                LifecycleInteractiveSessionResponse.self,
                from: encoded
            ) == response
        )
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
    func rootHelperActivatesServerBeforeReplyAndPreservesItAfterDisconnect()
        throws
    {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appending(
                path: "StornautLifecycleHelper/main.swift"
            ),
            encoding: .utf8
        )
        let retireStart = try #require(
            source.range(
                of: "if pending.request.kind == .retire {\n"
                    + "            guard let ownerRetirementObservation"
            )
        )
        let suffix = source[retireStart.lowerBound...]
        let retireEnd = try #require(
            suffix.range(of: "\n            return\n        }")
        )
        let retireBody = String(suffix[..<retireEnd.upperBound])
        let record = try #require(
            retireBody.range(of: "recordMachineRetirementEscrow(")
        )
        let sealedResponse = try #require(
            retireBody.range(of: "let sealedResponse")
        )
        let reply = try #require(
            retireBody.range(
                of: "pending.reply(",
                range: sealedResponse.lowerBound..<retireBody.endIndex
            )
        )
        let activate = try #require(
            retireBody.range(of: "machineClaimServer.activate()")
        )
        #expect(record.lowerBound < activate.lowerBound)
        #expect(activate.lowerBound < reply.lowerBound)
        #expect(source.contains("let handle = try retirementEscrow.record("))
        #expect(source.contains("guard !invalidated else"))
        #expect(source.contains("interactiveRouteClosed = true"))
        #expect(source.contains("!interactiveRouteClosed"))
        #expect(!retireBody.contains("scheduleRetirementClaimDeadline("))
        #expect(retireBody.contains("machineRetirementHandle: handle"))
        #expect(!retireBody.contains("scheduleSuccessfulExitAfterReply()"))

        let invalidationStart = try #require(
            source.range(of: "func invalidateAndDrain() {")
        )
        let invalidationSuffix = source[invalidationStart.lowerBound...]
        let invalidationEnd = try #require(
            invalidationSuffix.range(of: "\n    }\n\n#if DEBUG")
        )
        let invalidationBody = String(
            invalidationSuffix[..<invalidationEnd.upperBound]
        )
        #expect(
            invalidationBody.contains("machineClaimServer.isPending")
        )
        #expect(
            invalidationBody.contains("preserveRetirementServer")
        )

        let legacyStart = try #require(
            source.range(
                of: "case let .start(\n"
                    + "            investigationID,\n"
                    + "            evidenceBindingSHA256"
            )
        )
        let legacySuffix = source[legacyStart.lowerBound...]
        let legacyEnd = try #require(
            legacySuffix.range(
                of: "\n    }\n\n#if DEBUG\n"
                    + "    private func admitAndEnqueueLegacyStart("
            )
        )
        let legacyBody = String(legacySuffix[..<legacyEnd.upperBound])
        #expect(legacyBody.contains("interactiveRouteClosed"))
        #expect(legacyBody.contains("machineClaimServer.isPending"))
        #expect(!source.contains("retirementEscrow.isAwaitingClaim"))
        #expect(!source.contains("scheduleRetirementClaimDeadline("))
    }

    @Test
    func rootHelperLinearizesInteractiveAdmissionQueueAndDispatchEpoch()
        throws
    {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let helperSource = try String(
            contentsOf: repositoryRoot.appending(
                path: "StornautLifecycleHelper/main.swift"
            ),
            encoding: .utf8
        )
        let contractSource = try String(
            contentsOf: repositoryRoot.appending(
                path: "Sources/StornautLifecycle/"
                    + "LifecycleInteractiveSessionContract.swift"
            ),
            encoding: .utf8
        )

        #expect(!contractSource.contains("public func validatedResponse("))
        #expect(helperSource.contains("private func validateWorkerReply("))

        let admissionStart = try #require(
            helperSource.range(of: "private func admitAndEnqueueInteractive(")
        )
        let admissionSuffix = helperSource[admissionStart.lowerBound...]
        let admissionEnd = try #require(
            admissionSuffix.range(
                of: "\n    }\n#endif\n\n    func invalidateAndDrain()"
            )
        )
        let admissionBody = String(
            admissionSuffix[..<admissionEnd.upperBound]
        )
        let lock = try #require(
            admissionBody.range(of: "lock.withLock")
        )
        let enqueue = try #require(
            admissionBody.range(of: "operationQueue.async")
        )
        #expect(lock.lowerBound < enqueue.lowerBound)
        #expect(admissionBody.contains("interactivePending[decoded.operationID] = pending"))

        let dispatchStart = try #require(
            helperSource.range(of: "private func dispatchInteractive(")
        )
        let dispatchSuffix = helperSource[dispatchStart.lowerBound...]
        let dispatchEnd = try #require(
            dispatchSuffix.range(of: "\n    }\n\n    private func startInteractiveWorker(")
        )
        let dispatchBody = String(dispatchSuffix[..<dispatchEnd.upperBound])
        #expect(dispatchBody.contains("interactiveDispatchStillAdmitted("))
        #expect(dispatchBody.contains("failInteractiveOperation("))

        #expect(helperSource.contains("private func admitAndEnqueueLegacyStart("))
        #expect(helperSource.contains("legacyRunStillAdmitted("))
        let runStart = try #require(
            helperSource.range(of: "private func run(\n")
        )
        let runSuffix = helperSource[runStart.lowerBound...]
        let userRead = try #require(
            runSuffix.range(of: "let userIdentity = try LifecycleUserIdentity.read(")
        )
        let epochCheck = try #require(
            runSuffix.range(of: "legacyRunStillAdmitted(")
        )
        #expect(epochCheck.lowerBound < userRead.lowerBound)
    }

    @Test
    func workerReplyRejectsUnknownMissingAndAmbiguousPayloads() throws {
        let fixture = LifecycleInteractiveSessionFixture()
        let response = try LifecycleInteractiveSessionResponse.started(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID,
            codexExecutableSHA256: fixture.codexExecutableSHA256
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
            try LifecycleInteractiveSessionRequest.read(
                investigationID: fixture.investigationID,
                operationID: fixture.operationID,
                configurationSHA256: fixture.configurationSHA256
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

        var misplacedDigest = object
        misplacedDigest["codexExecutableSHA256"] =
            fixture.codexExecutableSHA256
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                LifecycleInteractiveSessionRequest.self,
                from: try JSONSerialization.data(
                    withJSONObject: misplacedDigest
                )
            )
        }

        let start = try LifecycleInteractiveSessionRequest.start(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID,
            configurationSHA256: fixture.configurationSHA256,
            codexExecutableSHA256: fixture.codexExecutableSHA256,
            validBefore: fixture.validBefore,
            maximumLineBytes: 1_024,
            maximumSessionBytes: 8_192
        )
        var missingDigest = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(start)
            ) as? [String: Any]
        )
        missingDigest.removeValue(forKey: "codexExecutableSHA256")
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                LifecycleInteractiveSessionRequest.self,
                from: try JSONSerialization.data(
                    withJSONObject: missingDigest
                )
            )
        }
        for invalid in [
            String(repeating: "B", count: 64),
            String(repeating: "b", count: 63),
            String(repeating: "g", count: 64),
        ] {
            var malformed = try #require(
                JSONSerialization.jsonObject(
                    with: JSONEncoder().encode(start)
                ) as? [String: Any]
            )
            malformed["codexExecutableSHA256"] = invalid
            #expect(throws: DecodingError.self) {
                _ = try JSONDecoder().decode(
                    LifecycleInteractiveSessionRequest.self,
                    from: try JSONSerialization.data(
                        withJSONObject: malformed
                    )
                )
            }
        }
    }

    @Test
    func startedResponseRejectsMissingMisplacedAndForeignDigest() throws {
        let fixture = LifecycleInteractiveSessionFixture()
        let request = try LifecycleInteractiveSessionRequest.start(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID,
            configurationSHA256: fixture.configurationSHA256,
            codexExecutableSHA256: fixture.codexExecutableSHA256,
            validBefore: fixture.validBefore,
            maximumLineBytes: 1_024,
            maximumSessionBytes: 8_192
        )
        let started = try LifecycleInteractiveSessionResponse.started(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID,
            codexExecutableSHA256: fixture.codexExecutableSHA256
        )
        var missing = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(started)
            ) as? [String: Any]
        )
        missing.removeValue(forKey: "codexExecutableSHA256")
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                LifecycleInteractiveSessionResponse.self,
                from: try JSONSerialization.data(withJSONObject: missing)
            )
        }
        for invalid in [
            String(repeating: "B", count: 64),
            String(repeating: "b", count: 63),
            String(repeating: "g", count: 64),
        ] {
            var malformed = try #require(
                JSONSerialization.jsonObject(
                    with: JSONEncoder().encode(started)
                ) as? [String: Any]
            )
            malformed["codexExecutableSHA256"] = invalid
            #expect(throws: DecodingError.self) {
                _ = try JSONDecoder().decode(
                    LifecycleInteractiveSessionResponse.self,
                    from: try JSONSerialization.data(
                        withJSONObject: malformed
                    )
                )
            }
        }
        var unknown = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(started)
            ) as? [String: Any]
        )
        unknown["unexpected"] = true
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                LifecycleInteractiveSessionResponse.self,
                from: try JSONSerialization.data(withJSONObject: unknown)
            )
        }
        #expect(throws: LifecycleInteractiveSessionContractError.self) {
            let foreign = try LifecycleInteractiveSessionResponse.started(
                investigationID: fixture.investigationID,
                operationID: fixture.operationID,
                codexExecutableSHA256: String(repeating: "c", count: 64)
            )
            _ = try foreign.validated(for: request)
        }

        let nonStarted = LifecycleInteractiveSessionResponse.writeAccepted(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID
        )
        var misplaced = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(nonStarted)
            ) as? [String: Any]
        )
        misplaced["codexExecutableSHA256"] =
            fixture.codexExecutableSHA256
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                LifecycleInteractiveSessionResponse.self,
                from: try JSONSerialization.data(withJSONObject: misplaced)
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
                configurationSHA256: fixture.configurationSHA256,
                codexExecutableSHA256: fixture.codexExecutableSHA256,
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
                configurationSHA256: fixture.configurationSHA256,
                codexExecutableSHA256: fixture.codexExecutableSHA256,
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
                configurationSHA256: fixture.configurationSHA256,
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
                configurationSHA256: fixture.configurationSHA256,
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
        let request = try LifecycleInteractiveSessionRequest.read(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID,
            configurationSHA256: fixture.configurationSHA256
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
    func ownedOuterRetirementRequiresTheExactClaimHandle() throws {
        let fixture = LifecycleInteractiveSessionFixture()
        let request = try LifecycleInteractiveSessionRequest.retire(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID,
            configurationSHA256: fixture.configurationSHA256
        )
        let unsealed = LifecycleInteractiveSessionResponse.retired(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID,
            drained: true,
            ownerRetirementObservation: .retiredOwnedResources
        )

        #expect(
            throws: LifecycleInteractiveSessionContractError.identityMismatch
        ) {
            _ = try unsealed.validated(for: request)
        }

        var object = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(unsealed)
            ) as? [String: Any]
        )
        object["machineRetirementHandle"] = NSNull()
        let decoded = try JSONDecoder().decode(
            LifecycleInteractiveSessionResponse.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        #expect(
            throws: LifecycleInteractiveSessionContractError.identityMismatch
        ) {
            _ = try decoded.validated(for: request)
        }

        let workerReply = LifecycleInteractiveWorkerReply(
            operationID: fixture.operationID,
            response: unsealed
        )
        #expect(workerReply.response == unsealed)
    }

    @Test
    func interactiveXPCReplyResolverCompletesExactlyOnce() async throws {
        let fixture = LifecycleInteractiveSessionFixture()
        let request = try LifecycleInteractiveSessionRequest.read(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID,
            configurationSHA256: fixture.configurationSHA256
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
        let request = try! LifecycleInteractiveSessionRequest.read(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID,
            configurationSHA256: fixture.configurationSHA256
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
        let request = try! LifecycleInteractiveSessionRequest.read(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID,
            configurationSHA256: fixture.configurationSHA256
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
        let request = try! LifecycleInteractiveSessionRequest.read(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID,
            configurationSHA256: fixture.configurationSHA256
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
        let request = try LifecycleInteractiveSessionRequest.read(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID,
            configurationSHA256: fixture.configurationSHA256
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
        let request = try LifecycleInteractiveSessionRequest.retire(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID,
            configurationSHA256: fixture.configurationSHA256
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
        let request = try! LifecycleInteractiveSessionRequest.retire(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID,
            configurationSHA256: fixture.configurationSHA256
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
        let request = try! LifecycleInteractiveSessionRequest.read(
            investigationID: fixture.investigationID,
            operationID: fixture.operationID,
            configurationSHA256: fixture.configurationSHA256
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
    let configurationSHA256 = String(repeating: "a", count: 64)
    let codexExecutableSHA256 = String(repeating: "b", count: 64)
    let validBefore = Date(timeIntervalSince1970: 2_000_000_000)
}
