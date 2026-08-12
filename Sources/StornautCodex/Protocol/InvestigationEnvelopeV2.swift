import Darwin
import Foundation

public struct InvestigationUnresolvedTargetV2: Sendable, Equatable {
    public let targetID: String
    public let reason: String
}

public struct InvestigationCoverageV2: Sendable, Equatable {
    public let investigatedTargetIDs: [String]
    public let unresolvedTargets: [InvestigationUnresolvedTargetV2]
}

public struct InvestigationEvidenceV2: Sendable, Equatable {
    public let id: String
    public let targetID: String
    public let source: InvestigationEvidenceSource
    public let summary: String
    public let publicURL: URL?
}

public struct InvestigationFindingV2: Sendable, Equatable {
    public let id: String
    public let targetID: String
    public let summary: String
    public let evidenceIDs: [String]
    public let confidence: InvestigationConfidence
    public let uncertainty: String
}

public struct InvestigationCandidateProposalV2: Sendable, Equatable {
    public let candidateID: String
    public let targetID: String
    public let summary: String
    public let evidenceIDs: [String]
    public let confidence: InvestigationConfidence
    public let uncertainty: String
}

public struct InvestigationCapabilityDegradationV2:
    Sendable,
    Equatable
{
    public let capability: InvestigationCapability
    public let reasonKey: String
    public let summary: String
}

public struct InvestigationEnvelopeV2: Sendable, Equatable {
    public static let protocolVersion = 2
    public static let maximumInputBytes = 1_024 * 1_024
    public static let summaryByteLimit = 8 * 1_024
    public static let itemSummaryByteLimit = 4 * 1_024
    public static let uncertaintyByteLimit = 2 * 1_024
    public static let publicURLByteLimit = 2 * 1_024
    public static let maximumEvidenceCount = 512
    public static let maximumFindingCount = 256
    public static let maximumCandidateProposalCount = 256
    public static let maximumEvidenceReferences = 64

    public let protocolVersion: Int
    public let investigationID: String
    public let runID: String
    public let summary: String
    public let coverage: InvestigationCoverageV2
    public let evidence: [InvestigationEvidenceV2]
    public let findings: [InvestigationFindingV2]
    public let candidateProposals: [InvestigationCandidateProposalV2]
    public let capabilityDegradations:
        [InvestigationCapabilityDegradationV2]

    public static func decodeValidated(
        from data: Data,
        context: InvestigationProtocolContext
    ) throws -> Self {
        guard
            !data.isEmpty,
            data.count <= maximumInputBytes
        else {
            throw InvestigationEnvelopeV2Error.inputLimitExceeded
        }
        var auditor = StrictProtocolJSONAuditor(data: data)
        try auditor.validate()
        let object: [String: Any]
        do {
            guard
                let decoded = try JSONSerialization.jsonObject(
                    with: data
                ) as? [String: Any]
            else {
                throw InvestigationEnvelopeV2Error.invalidStructure
            }
            object = decoded
        } catch let error as InvestigationEnvelopeV2Error {
            throw error
        } catch {
            throw InvestigationEnvelopeV2Error.invalidJSON
        }
        try validateWireKeys(object)

        let wire: WireEnvelope
        do {
            wire = try JSONDecoder().decode(WireEnvelope.self, from: data)
        } catch {
            throw InvestigationEnvelopeV2Error.invalidStructure
        }
        return try validated(wire, context: context)
    }

    private static func validated(
        _ wire: WireEnvelope,
        context: InvestigationProtocolContext
    ) throws -> Self {
        guard wire.protocolVersion == protocolVersion else {
            throw InvestigationEnvelopeV2Error.unsupportedVersion
        }
        guard
            wire.investigationID == context.investigationID,
            wire.runID == context.runID
        else {
            throw InvestigationEnvelopeV2Error.identityMismatch
        }
        guard boundedText(wire.summary, limit: summaryByteLimit) else {
            throw InvestigationEnvelopeV2Error.invalidSummary
        }

        let coverage = try validatedCoverage(
            wire.coverage,
            context: context
        )
        let investigatedTargets = Set(coverage.investigatedTargetIDs)
        let evidence = try validatedEvidence(
            wire.evidence,
            investigatedTargets: investigatedTargets
        )
        let evidenceByID = Dictionary(
            uniqueKeysWithValues: evidence.map { ($0.id, $0) }
        )
        let findings = try validatedFindings(
            wire.findings,
            investigatedTargets: investigatedTargets,
            evidenceByID: evidenceByID
        )
        let proposals = try validatedProposals(
            wire.candidateProposals,
            context: context,
            investigatedTargets: investigatedTargets,
            evidenceByID: evidenceByID
        )
        let degradations = try validatedDegradations(
            wire.capabilityDegradations,
            context: context
        )

        return InvestigationEnvelopeV2(
            protocolVersion: wire.protocolVersion,
            investigationID: wire.investigationID,
            runID: wire.runID,
            summary: wire.summary,
            coverage: coverage,
            evidence: evidence,
            findings: findings,
            candidateProposals: proposals,
            capabilityDegradations: degradations
        )
    }

    private static func validatedCoverage(
        _ wire: WireCoverage,
        context: InvestigationProtocolContext
    ) throws -> InvestigationCoverageV2 {
        guard
            Set(wire.investigatedTargetIDs).count
                == wire.investigatedTargetIDs.count,
            wire.investigatedTargetIDs.allSatisfy(
                investigationProtocolIdentifierIsValid
            )
        else {
            throw InvestigationEnvelopeV2Error.invalidCoverage
        }
        let unresolved = try wire.unresolvedTargets.map {
            guard
                investigationProtocolIdentifierIsValid($0.targetID),
                stableReasonKeyIsValid($0.reason)
            else {
                throw InvestigationEnvelopeV2Error.invalidCoverage
            }
            return InvestigationUnresolvedTargetV2(
                targetID: $0.targetID,
                reason: $0.reason
            )
        }
        let unresolvedIDs = unresolved.map(\.targetID)
        guard
            Set(unresolvedIDs).count == unresolvedIDs.count,
            Set(wire.investigatedTargetIDs).isDisjoint(
                with: Set(unresolvedIDs)
            ),
            Set(wire.investigatedTargetIDs).union(unresolvedIDs)
                == context.targetIDs
        else {
            throw InvestigationEnvelopeV2Error.invalidCoverage
        }
        return InvestigationCoverageV2(
            investigatedTargetIDs: wire.investigatedTargetIDs,
            unresolvedTargets: unresolved
        )
    }

    private static func validatedEvidence(
        _ wire: [WireEvidence],
        investigatedTargets: Set<String>
    ) throws -> [InvestigationEvidenceV2] {
        guard wire.count <= maximumEvidenceCount else {
            throw InvestigationEnvelopeV2Error.collectionLimitExceeded
        }
        var observedIDs = Set<String>()
        return try wire.map { item in
            guard
                investigationProtocolIdentifierIsValid(item.id),
                observedIDs.insert(item.id).inserted,
                investigatedTargets.contains(item.targetID),
                boundedText(
                    item.summary,
                    limit: itemSummaryByteLimit
                )
            else {
                throw InvestigationEnvelopeV2Error.invalidEvidence
            }
            let normalizedURL: URL?
            if let publicURL = item.publicURL {
                guard item.source.permitsPublicURL else {
                    throw InvestigationEnvelopeV2Error.invalidPublicURL
                }
                normalizedURL = try normalizePublicURL(publicURL)
            } else {
                normalizedURL = nil
            }
            return InvestigationEvidenceV2(
                id: item.id,
                targetID: item.targetID,
                source: item.source,
                summary: item.summary,
                publicURL: normalizedURL
            )
        }
    }

    private static func validatedFindings(
        _ wire: [WireFinding],
        investigatedTargets: Set<String>,
        evidenceByID: [String: InvestigationEvidenceV2]
    ) throws -> [InvestigationFindingV2] {
        guard wire.count <= maximumFindingCount else {
            throw InvestigationEnvelopeV2Error.collectionLimitExceeded
        }
        var observedIDs = Set<String>()
        return try wire.map { item in
            guard
                investigationProtocolIdentifierIsValid(item.id),
                observedIDs.insert(item.id).inserted,
                investigatedTargets.contains(item.targetID),
                boundedText(
                    item.summary,
                    limit: itemSummaryByteLimit
                ),
                boundedText(
                    item.uncertainty,
                    limit: uncertaintyByteLimit
                ),
                referencesAreValid(
                    item.evidenceIDs,
                    targetID: item.targetID,
                    evidenceByID: evidenceByID
                )
            else {
                throw InvestigationEnvelopeV2Error.invalidFinding
            }
            return InvestigationFindingV2(
                id: item.id,
                targetID: item.targetID,
                summary: item.summary,
                evidenceIDs: item.evidenceIDs,
                confidence: item.confidence,
                uncertainty: item.uncertainty
            )
        }
    }

    private static func validatedProposals(
        _ wire: [WireCandidateProposal],
        context: InvestigationProtocolContext,
        investigatedTargets: Set<String>,
        evidenceByID: [String: InvestigationEvidenceV2]
    ) throws -> [InvestigationCandidateProposalV2] {
        guard wire.count <= maximumCandidateProposalCount else {
            throw InvestigationEnvelopeV2Error.collectionLimitExceeded
        }
        var observedIDs = Set<String>()
        return try wire.map { item in
            guard
                investigationProtocolIdentifierIsValid(item.candidateID),
                observedIDs.insert(item.candidateID).inserted,
                context.candidateTargetIDs[item.candidateID]
                    == item.targetID,
                investigatedTargets.contains(item.targetID),
                boundedText(
                    item.summary,
                    limit: itemSummaryByteLimit
                ),
                boundedText(
                    item.uncertainty,
                    limit: uncertaintyByteLimit
                ),
                referencesAreValid(
                    item.evidenceIDs,
                    targetID: item.targetID,
                    evidenceByID: evidenceByID
                )
            else {
                throw InvestigationEnvelopeV2Error.invalidCandidateProposal
            }
            return InvestigationCandidateProposalV2(
                candidateID: item.candidateID,
                targetID: item.targetID,
                summary: item.summary,
                evidenceIDs: item.evidenceIDs,
                confidence: item.confidence,
                uncertainty: item.uncertainty
            )
        }
    }

    private static func validatedDegradations(
        _ wire: [WireCapabilityDegradation],
        context: InvestigationProtocolContext
    ) throws -> [InvestigationCapabilityDegradationV2] {
        guard wire.count <= InvestigationCapability.allCases.count else {
            throw InvestigationEnvelopeV2Error.collectionLimitExceeded
        }
        var observed = Set<InvestigationCapability>()
        return try wire.map { item in
            guard
                observed.insert(item.capability).inserted,
                context.requiredCapabilities.contains(item.capability),
                stableReasonKeyIsValid(item.reasonKey),
                boundedText(
                    item.summary,
                    limit: itemSummaryByteLimit
                )
            else {
                throw InvestigationEnvelopeV2Error.invalidDegradation
            }
            return InvestigationCapabilityDegradationV2(
                capability: item.capability,
                reasonKey: item.reasonKey,
                summary: item.summary
            )
        }
    }

    private static func referencesAreValid(
        _ references: [String],
        targetID: String,
        evidenceByID: [String: InvestigationEvidenceV2]
    ) -> Bool {
        !references.isEmpty
            && references.count <= maximumEvidenceReferences
            && Set(references).count == references.count
            && references.allSatisfy {
                evidenceByID[$0]?.targetID == targetID
            }
    }

    private static func boundedText(
        _ value: String,
        limit: Int
    ) -> Bool {
        !value.isEmpty
            && value.utf8.count <= limit
            && !value.utf8.contains(0)
            && value.unicodeScalars.allSatisfy {
                !CharacterSet.controlCharacters.contains($0)
                    || $0 == "\n"
                    || $0 == "\t"
            }
    }

    private static func stableReasonKeyIsValid(_ value: String) -> Bool {
        investigationProtocolIdentifierIsValid(value)
    }

    private static func normalizePublicURL(_ value: String) throws -> URL {
        guard
            value.utf8.count <= publicURLByteLimit,
            var components = URLComponents(string: value),
            let scheme = components.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            components.user == nil,
            components.password == nil,
            let serializedHost = components.host?.lowercased(),
            components.port.map({ (1...65_535).contains($0) }) ?? true,
            publicHostIsAllowed(serializedHost)
        else {
            throw InvestigationEnvelopeV2Error.invalidPublicURL
        }
        components.scheme = scheme
        components.host = serializedHost
        components.query = nil
        components.fragment = nil
        guard
            let normalized = components.url,
            normalized.absoluteString.utf8.count <= publicURLByteLimit
        else {
            throw InvestigationEnvelopeV2Error.invalidPublicURL
        }
        return normalized
    }
}

public enum InvestigationEnvelopeV2Error: Error, Sendable, Equatable {
    case invalidContext
    case invalidJSON
    case invalidStructure
    case inputLimitExceeded
    case unsupportedVersion
    case identityMismatch
    case invalidSummary
    case invalidCoverage
    case invalidEvidence
    case invalidFinding
    case invalidCandidateProposal
    case invalidDegradation
    case invalidPublicURL
    case collectionLimitExceeded
}

private struct WireEnvelope: Decodable {
    let protocolVersion: Int
    let investigationID: String
    let runID: String
    let summary: String
    let coverage: WireCoverage
    let evidence: [WireEvidence]
    let findings: [WireFinding]
    let candidateProposals: [WireCandidateProposal]
    let capabilityDegradations: [WireCapabilityDegradation]
}

private struct WireCoverage: Decodable {
    let investigatedTargetIDs: [String]
    let unresolvedTargets: [WireUnresolvedTarget]
}

private struct WireUnresolvedTarget: Decodable {
    let targetID: String
    let reason: String
}

private struct WireEvidence: Decodable {
    let id: String
    let targetID: String
    let source: InvestigationEvidenceSource
    let summary: String
    let publicURL: String?
}

private struct WireFinding: Decodable {
    let id: String
    let targetID: String
    let summary: String
    let evidenceIDs: [String]
    let confidence: InvestigationConfidence
    let uncertainty: String
}

private struct WireCandidateProposal: Decodable {
    let candidateID: String
    let targetID: String
    let summary: String
    let evidenceIDs: [String]
    let confidence: InvestigationConfidence
    let uncertainty: String
}

private struct WireCapabilityDegradation: Decodable {
    let capability: InvestigationCapability
    let reasonKey: String
    let summary: String
}

private func validateWireKeys(_ object: [String: Any]) throws {
    try requireExactKeys(
        object,
        expected: [
            "protocolVersion",
            "investigationID",
            "runID",
            "summary",
            "coverage",
            "evidence",
            "findings",
            "candidateProposals",
            "capabilityDegradations",
        ]
    )
    let coverage = try requireObject(object["coverage"])
    try requireExactKeys(
        coverage,
        expected: ["investigatedTargetIDs", "unresolvedTargets"]
    )
    for item in try requireObjectArray(coverage["unresolvedTargets"]) {
        try requireExactKeys(item, expected: ["targetID", "reason"])
    }
    for item in try requireObjectArray(object["evidence"]) {
        try requireExactKeys(
            item,
            expected: [
                "id",
                "targetID",
                "source",
                "summary",
                "publicURL",
            ]
        )
    }
    for item in try requireObjectArray(object["findings"]) {
        try requireExactKeys(
            item,
            expected: [
                "id",
                "targetID",
                "summary",
                "evidenceIDs",
                "confidence",
                "uncertainty",
            ]
        )
    }
    for item in try requireObjectArray(object["candidateProposals"]) {
        try requireExactKeys(
            item,
            expected: [
                "candidateID",
                "targetID",
                "summary",
                "evidenceIDs",
                "confidence",
                "uncertainty",
            ]
        )
    }
    for item in try requireObjectArray(object["capabilityDegradations"]) {
        try requireExactKeys(
            item,
            expected: ["capability", "reasonKey", "summary"]
        )
    }
}

private func requireExactKeys(
    _ object: [String: Any],
    expected: Set<String>
) throws {
    guard Set(object.keys) == expected else {
        throw InvestigationEnvelopeV2Error.invalidStructure
    }
}

private func requireObject(_ value: Any?) throws -> [String: Any] {
    guard let object = value as? [String: Any] else {
        throw InvestigationEnvelopeV2Error.invalidStructure
    }
    return object
}

private func requireObjectArray(_ value: Any?) throws -> [[String: Any]] {
    guard let array = value as? [[String: Any]] else {
        throw InvestigationEnvelopeV2Error.invalidStructure
    }
    return array
}

private func publicHostIsAllowed(_ serializedHost: String) -> Bool {
    guard
        !serializedHost.isEmpty,
        !serializedHost.hasSuffix("."),
        let host = unbracketedHost(serializedHost),
        host != "localhost",
        !host.hasSuffix(".localhost"),
        !host.hasSuffix(".local")
    else {
        return false
    }

    var ipv4 = in_addr()
    if inet_pton(AF_INET, host, &ipv4) == 1 {
        return canonicalIPv4Text(ipv4) == host
            && publicIPv4IsAllowed(ipv4)
    }
    var ipv6 = in6_addr()
    if inet_pton(AF_INET6, host, &ipv6) == 1 {
        return publicIPv6IsAllowed(ipv6)
    }
    var legacyIPv4 = in_addr()
    guard inet_aton(host, &legacyIPv4) == 0 else {
        return false
    }
    return publicDNSHostIsAllowed(host)
}

private func unbracketedHost(_ host: String) -> String? {
    guard host.first == "[" || host.last == "]" else {
        return host
    }
    guard host.first == "[", host.last == "]" else {
        return nil
    }
    return String(host.dropFirst().dropLast())
}

private func publicDNSHostIsAllowed(_ host: String) -> Bool {
    guard host.utf8.count <= 253 else {
        return false
    }
    let labels = host.split(separator: ".", omittingEmptySubsequences: false)
    guard
        labels.count >= 2,
        labels.allSatisfy({ label in
            guard
                !label.isEmpty,
                label.utf8.count <= 63,
                let first = label.unicodeScalars.first,
                let last = label.unicodeScalars.last,
                asciiAlphaNumeric(first),
                asciiAlphaNumeric(last)
            else {
                return false
            }
            return label.unicodeScalars.allSatisfy {
                asciiAlphaNumeric($0) || $0.value == 0x2D
            }
        }),
        labels.contains(where: {
            $0.unicodeScalars.contains(where: asciiLetter)
        })
    else {
        return false
    }
    return true
}

private func asciiAlphaNumeric(_ scalar: UnicodeScalar) -> Bool {
    asciiLetter(scalar) || (0x30...0x39).contains(scalar.value)
}

private func asciiLetter(_ scalar: UnicodeScalar) -> Bool {
    (0x61...0x7A).contains(scalar.value)
}

private func publicIPv4IsAllowed(_ address: in_addr) -> Bool {
    let value = UInt32(bigEndian: address.s_addr)
    let first = UInt8((value >> 24) & 0xFF)
    let second = UInt8((value >> 16) & 0xFF)
    if first == 0 || first == 10 || first == 127 || first >= 224 {
        return false
    }
    if first == 169 && second == 254 {
        return false
    }
    if first == 172 && (16...31).contains(second) {
        return false
    }
    if first == 192 && second == 168 {
        return false
    }
    if first == 100 && (64...127).contains(second) {
        return false
    }
    let third = UInt8((value >> 8) & 0xFF)
    if first == 192 && second == 0 && (third == 0 || third == 2) {
        return false
    }
    if first == 198 && (second == 18 || second == 19) {
        return false
    }
    if first == 198 && second == 51 && third == 100 {
        return false
    }
    if first == 203 && second == 0 && third == 113 {
        return false
    }
    return true
}

private func canonicalIPv4Text(_ address: in_addr) -> String? {
    var address = address
    var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
    guard
        inet_ntop(
            AF_INET,
            &address,
            &buffer,
            socklen_t(buffer.count)
        ) != nil
    else {
        return nil
    }
    let end = buffer.firstIndex(of: 0) ?? buffer.endIndex
    return String(
        decoding: buffer[..<end].map {
            UInt8(bitPattern: $0)
        },
        as: UTF8.self
    )
}

private func publicIPv6IsAllowed(_ address: in6_addr) -> Bool {
    let bytes = withUnsafeBytes(of: address) { Array($0) }
    guard bytes.count == 16 else { return false }
    if bytes.allSatisfy({ $0 == 0 }) {
        return false
    }
    if bytes.dropLast().allSatisfy({ $0 == 0 }) && bytes.last == 1 {
        return false
    }
    if bytes[0] == 0xFF || bytes[0] & 0xFE == 0xFC {
        return false
    }
    if bytes[0] == 0xFE && bytes[1] & 0xC0 == 0x80 {
        return false
    }
    if
        bytes[0] == 0x20,
        bytes[1] == 0x01,
        bytes[2] == 0x0D,
        bytes[3] == 0xB8
    {
        return false
    }
    if
        bytes[0] == 0x01,
        bytes[1] == 0x00,
        bytes[2..<8].allSatisfy({ $0 == 0 })
    {
        return false
    }
    if
        bytes.prefix(10).allSatisfy({ $0 == 0 }),
        bytes[10] == 0xFF,
        bytes[11] == 0xFF
    {
        var ipv4 = in_addr(
            s_addr: UInt32(bytes[12]) << 24
                | UInt32(bytes[13]) << 16
                | UInt32(bytes[14]) << 8
                | UInt32(bytes[15])
        )
        ipv4.s_addr = ipv4.s_addr.bigEndian
        return publicIPv4IsAllowed(ipv4)
    }
    if bytes.prefix(12).allSatisfy({ $0 == 0 }) {
        var ipv4 = in_addr(
            s_addr: UInt32(bytes[12]) << 24
                | UInt32(bytes[13]) << 16
                | UInt32(bytes[14]) << 8
                | UInt32(bytes[15])
        )
        ipv4.s_addr = ipv4.s_addr.bigEndian
        return publicIPv4IsAllowed(ipv4)
    }
    return true
}
