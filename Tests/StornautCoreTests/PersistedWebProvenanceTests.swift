import Foundation
import Testing
@testable import StornautCore

@Test(
    arguments: [
        (
            "https://docs.example.com/",
            true,
            PersistedWebProvenanceReason.acceptedOrigin
        ),
        (
            "https://docs.example.com/reference/private-token",
            true,
            PersistedWebProvenanceReason.pathRedacted
        ),
        (
            "https://docs.example.com/?api_key=query-secret",
            true,
            PersistedWebProvenanceReason.queryRedacted
        ),
        (
            "https://docs.example.com/reference?signature=signed-secret",
            true,
            PersistedWebProvenanceReason.pathAndQueryRedacted
        ),
    ]
)
func persistedWebProvenanceKeepsOnlyCanonicalPublicOrigin(
    input: String,
    isPublicTransport: Bool,
    expectedReason: PersistedWebProvenanceReason
) throws {
    let provenance = PersistedWebProvenance(
        sanitizing: input,
        transport: isPublicTransport ? .publicInternet : .nonPublic
    )

    #expect(provenance.origin == "https://docs.example.com/")
    #expect(provenance.reason == expectedReason)
    let encoded = try DomainJSON.encode(provenance)
    #expect(!String(decoding: encoded, as: UTF8.self).contains("private-token"))
    #expect(!String(decoding: encoded, as: UTF8.self).contains("query-secret"))
    #expect(!String(decoding: encoded, as: UTF8.self).contains("signed-secret"))
}

@Test(
    arguments: [
        "https://user:credential-secret@docs.example.com/private",
        "https://127.0.0.1/loopback-secret",
        "https://2130706433/decimal-secret",
        "https://0177.0.0.1/octal-secret",
        "https://0x7f000001/hex-secret",
        "https://0x7f.0.0.1/dotted-hex-secret",
        "https://127.0.0x0.1/mixed-hex-secret",
        "https://127.1/short-secret",
        "https://[::1]/ipv6-secret",
        "https://[::ffff:127.0.0.1]/mapped-secret",
        "https://localhost/local-secret",
        "https://service.internal/internal-secret",
        "https://service.local/local-domain-secret",
        "https://docs.example.com./trailing-dot-secret",
        "https://Docs.example.com/mixed-case-secret",
        "https://例子.example/unicode-secret",
        "https://xn--fsqu00a.example/punycode-secret",
        "https://docs.example.com:8443/port-secret",
        "https://docs.example.com/%2FUsers%2Ferik%2Fhome-secret",
        "https://docs.example.com/%7E/private-home-secret",
        "https://docs.example.com/%zz/malformed-secret",
        "https:///empty-host-secret",
        "http://docs.example.com/http-secret",
    ]
)
func persistedWebProvenanceRejectsAmbiguousOrNonPublicSources(
    input: String
) throws {
    let provenance = PersistedWebProvenance(
        sanitizing: input,
        transport: .publicInternet
    )
    let encoded = String(
        decoding: try DomainJSON.encode(provenance),
        as: UTF8.self
    )

    #expect(provenance.origin == nil)
    #expect(
        provenance.reason == .rejectedNonPublic
            || provenance.reason == .rejectedMalformed
    )
    #expect(!encoded.contains(input))
    #expect(!encoded.contains("secret"))
}

@Test
func persistedWebProvenanceRequiresIdentityBoundPublicTransport() {
    let provenance = PersistedWebProvenance(
        sanitizing: "https://docs.example.com/private-transport-secret",
        transport: .nonPublic
    )

    #expect(provenance.origin == nil)
    #expect(provenance.reason == .rejectedNonPublic)
}
