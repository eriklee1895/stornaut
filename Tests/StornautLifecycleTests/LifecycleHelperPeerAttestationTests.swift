import Darwin
import Foundation
import Testing
@testable import StornautLifecycle

@Suite("Lifecycle helper peer attestation")
struct LifecycleHelperPeerAttestationTests {
    @Test
    func exactConnectedRootHelperIdentityIsAccepted() throws {
        let fixture = try LifecycleHelperPeerAttestationFixture()
        let verifier = RecordingHelperPeerSigningVerifier(
            result: fixture.verifiedSigning()
        )
        let attestor = LifecycleConnectedHelperPeerAttestor(
            expectedSigningIdentity: fixture.signingIdentity,
            signingVerifier: verifier
        )

        let peer = try attestor.attest(
            fixture.response,
            for: fixture.request,
            connectedProcessID: fixture.identity.processID,
            connectedEffectiveUserID:
                fixture.identity.effectiveUserID,
            connectedAuditSessionID:
                fixture.identity.auditSessionID,
            receivedAt: fixture.receivedAt
        )

        #expect(peer.identity == fixture.identity)
        #expect(verifier.auditTokens == [fixture.identity.auditToken])
        #expect(
            try JSONDecoder().decode(
                LifecycleHelperPeerAttestationResponse.self,
                from: JSONEncoder().encode(fixture.response)
            ) == fixture.response
        )
    }

    @Test
    func connectionMetadataAndFullTokenMustRemainExact() throws {
        let fixture = try LifecycleHelperPeerAttestationFixture()

        for connection in [
            (
                fixture.identity.processID + 1,
                fixture.identity.effectiveUserID,
                fixture.identity.auditSessionID
            ),
            (
                fixture.identity.processID,
                fixture.identity.effectiveUserID + 1,
                fixture.identity.auditSessionID
            ),
            (
                fixture.identity.processID,
                fixture.identity.effectiveUserID,
                fixture.identity.auditSessionID + 1
            ),
        ] {
            #expect(
                throws: LifecycleHelperPeerAttestationError
                    .connectionIdentityMismatch
            ) {
                _ = try fixture.attestor().attest(
                    fixture.response,
                    for: fixture.request,
                    connectedProcessID: connection.0,
                    connectedEffectiveUserID: connection.1,
                    connectedAuditSessionID: connection.2,
                    receivedAt: fixture.receivedAt
                )
            }
        }

        var object = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(fixture.response)
            ) as? [String: Any]
        )
        object["processIDVersion"] =
            Int(fixture.identity.processIDVersion) + 1
        let mismatchedVersion = try JSONSerialization.data(
            withJSONObject: object
        )
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                LifecycleHelperPeerAttestationResponse.self,
                from: mismatchedVersion
            )
        }

        object = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(fixture.response)
            ) as? [String: Any]
        )
        var words = try #require(
            object["auditTokenWords"] as? [UInt32]
        )
        words[5] &+= 1
        object["auditTokenWords"] = words
        let mismatchedToken = try JSONSerialization.data(
            withJSONObject: object
        )
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                LifecycleHelperPeerAttestationResponse.self,
                from: mismatchedToken
            )
        }
    }

    @Test
    func challengeFreshnessAndStrictWireShapeRejectReplay() throws {
        let fixture = try LifecycleHelperPeerAttestationFixture()
        let foreignRequest = try LifecycleHelperPeerAttestationRequest(
            nonce: UUID(
                uuidString: "abababab-abab-4bab-8bab-abababababab"
            )!,
            issuedAt: fixture.issuedAt,
            validBefore: fixture.validBefore
        )

        #expect(
            throws: LifecycleHelperPeerAttestationError
                .challengeMismatch
        ) {
            _ = try fixture.attestor().attest(
                fixture.response,
                for: foreignRequest,
                connectedProcessID: fixture.identity.processID,
                connectedEffectiveUserID:
                    fixture.identity.effectiveUserID,
                connectedAuditSessionID:
                    fixture.identity.auditSessionID,
                receivedAt: fixture.receivedAt
            )
        }
        #expect(
            throws: LifecycleHelperPeerAttestationError
                .observationOutsideWindow
        ) {
            _ = try fixture.attestor().attest(
                fixture.response,
                for: fixture.request,
                connectedProcessID: fixture.identity.processID,
                connectedEffectiveUserID:
                    fixture.identity.effectiveUserID,
                connectedAuditSessionID:
                    fixture.identity.auditSessionID,
                receivedAt: fixture.validBefore.addingTimeInterval(1)
            )
        }

        var responseObject = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(fixture.response)
            ) as? [String: Any]
        )
        responseObject["unexpected"] = true
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                LifecycleHelperPeerAttestationResponse.self,
                from: JSONSerialization.data(
                    withJSONObject: responseObject
                )
            )
        }

        var requestObject = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(fixture.request)
            ) as? [String: Any]
        )
        requestObject["unexpected"] = true
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                LifecycleHelperPeerAttestationRequest.self,
                from: JSONSerialization.data(
                    withJSONObject: requestObject
                )
            )
        }
    }

    @Test
    func futureObservationAndOversizedWindowAreRejected() throws {
        let fixture = try LifecycleHelperPeerAttestationFixture()
        #expect(
            throws: LifecycleHelperPeerAttestationError
                .observationOutsideWindow
        ) {
            _ = try fixture.attestor().attest(
                fixture.response,
                for: fixture.request,
                connectedProcessID: fixture.identity.processID,
                connectedEffectiveUserID:
                    fixture.identity.effectiveUserID,
                connectedAuditSessionID:
                    fixture.identity.auditSessionID,
                receivedAt: fixture.response.observedAt
                    .addingTimeInterval(-0.5)
            )
        }
        #expect(
            throws: LifecycleHelperPeerAttestationError
                .invalidRequest
        ) {
            _ = try LifecycleHelperPeerAttestationRequest(
                nonce: UUID(),
                issuedAt: fixture.issuedAt,
                validBefore: fixture.issuedAt.addingTimeInterval(16)
            )
        }
    }

    @Test
    func connectionEpochInvalidationIsPermanentAndIdempotent() {
        let epoch = LifecycleXPCConnectionEpoch()

        #expect(epoch.isValid)
        epoch.invalidate()
        #expect(!epoch.isValid)
        epoch.invalidate()
        #expect(!epoch.isValid)
    }

    @Test
    func exactHelperSigningIsRequiredWithoutWideningRootAppPolicy()
        throws
    {
        let fixture = try LifecycleHelperPeerAttestationFixture()
        for verification in [
            LifecycleCodeSigningVerification.unresolved,
            fixture.verifiedSigning(
                signingIdentifier: "com.example.foreign.helper"
            ),
            fixture.verifiedSigning(
                designatedRequirementSHA256:
                    String(repeating: "f", count: 64)
            ),
            fixture.verifiedSigning(
                codeDirectoryHash: String(repeating: "e", count: 40)
            ),
        ] {
            let attestor = LifecycleConnectedHelperPeerAttestor(
                expectedSigningIdentity: fixture.signingIdentity,
                signingVerifier: RecordingHelperPeerSigningVerifier(
                    result: verification
                )
            )
            #expect(
                throws: LifecycleHelperPeerAttestationError
                    .signingIdentityMismatch
            ) {
                _ = try attestor.attest(
                    fixture.response,
                    for: fixture.request,
                    connectedProcessID: fixture.identity.processID,
                    connectedEffectiveUserID:
                        fixture.identity.effectiveUserID,
                    connectedAuditSessionID:
                        fixture.identity.auditSessionID,
                    receivedAt: fixture.receivedAt
                )
            }
        }

        let rootCaller = LifecycleCallerIdentity(
            processID: fixture.identity.processID,
            effectiveUserID: 0,
            signingIdentifier:
                fixture.signingIdentity.signingIdentifier
        )
        let appVerifier = RecordingHelperPeerSigningVerifier(
            result: fixture.verifiedSigning()
        )
        let appPolicy = LifecycleAppAuthorizationPolicy(
            expectedSigningIdentifier:
                fixture.signingIdentity.signingIdentifier,
            expectedDesignatedRequirementSHA256:
                fixture.signingIdentity
                .designatedRequirementSHA256,
            expectedCodeDirectoryHash:
                fixture.signingIdentity.codeDirectoryHash,
            verifier: appVerifier
        )
        #expect(
            !appPolicy.authorize(
                rootCaller,
                auditToken: fixture.identity.auditToken
            )
        )
        #expect(appVerifier.auditTokens.isEmpty)
    }
}

private struct LifecycleHelperPeerAttestationFixture {
    let issuedAt = Date(timeIntervalSince1970: 1_900_000_000)
    let validBefore = Date(timeIntervalSince1970: 1_900_000_015)
    let receivedAt = Date(timeIntervalSince1970: 1_900_000_002)
    let signingIdentity: LifecycleSigningIdentity
    let identity: LifecycleProcessIdentity
    let request: LifecycleHelperPeerAttestationRequest
    let response: LifecycleHelperPeerAttestationResponse

    init() throws {
        signingIdentity = try LifecycleSigningIdentity(
            signingIdentifier:
                "com.eriklee.stornaut.lifecycle.helper",
            designatedRequirementSHA256:
                String(repeating: "a", count: 64),
            codeDirectoryHash: String(repeating: "b", count: 40)
        )
        identity = LifecycleProcessIdentity(
            processID: 702,
            processIDVersion: 12,
            auditSessionID: 33_001,
            effectiveUserID: 0,
            auditToken: try LifecycleAuditToken(words: [
                0, 0, 0, 0, 0, 702, 33_001, 12,
            ])
        )
        request = try LifecycleHelperPeerAttestationRequest(
            nonce: UUID(
                uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
            )!,
            issuedAt: issuedAt,
            validBefore: validBefore
        )
        response = try LifecycleHelperPeerAttestationResponse(
            request: request,
            identity: identity,
            observedAt: receivedAt.addingTimeInterval(-1)
        )
    }

    func attestor() -> LifecycleConnectedHelperPeerAttestor {
        LifecycleConnectedHelperPeerAttestor(
            expectedSigningIdentity: signingIdentity,
            signingVerifier: RecordingHelperPeerSigningVerifier(
                result: verifiedSigning()
            )
        )
    }

    func verifiedSigning(
        signingIdentifier: String? = nil,
        designatedRequirementSHA256: String? = nil,
        codeDirectoryHash: String? = nil
    ) -> LifecycleCodeSigningVerification {
        .verified(
            processID: identity.processID,
            effectiveUserID: identity.effectiveUserID,
            signingIdentifier:
                signingIdentifier
                    ?? self.signingIdentity.signingIdentifier,
            designatedRequirementSHA256:
                designatedRequirementSHA256
                    ?? self.signingIdentity
                    .designatedRequirementSHA256,
            codeDirectoryHash:
                codeDirectoryHash
                    ?? self.signingIdentity.codeDirectoryHash
        )
    }
}

private final class RecordingHelperPeerSigningVerifier:
    LifecycleCodeSigningVerifying,
    @unchecked Sendable
{
    private let lock = NSLock()
    private let result: LifecycleCodeSigningVerification
    private(set) var auditTokens: [LifecycleAuditToken] = []

    init(result: LifecycleCodeSigningVerification) {
        self.result = result
    }

    func verify(
        auditToken: LifecycleAuditToken
    ) -> LifecycleCodeSigningVerification {
        lock.withLock { auditTokens.append(auditToken) }
        return result
    }
}
