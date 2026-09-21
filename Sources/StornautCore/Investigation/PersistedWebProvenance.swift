import Foundation

public enum PersistedWebProvenanceReason:
    String,
    Codable,
    Sendable,
    Equatable,
    CaseIterable
{
    case acceptedOrigin
    case pathRedacted
    case queryRedacted
    case pathAndQueryRedacted
    case rejectedNonPublic
    case rejectedMalformed
}

public enum PersistedWebTransportClassification:
    String,
    Codable,
    Sendable,
    Equatable
{
    case publicInternet
    case nonPublic
}

public struct PersistedWebProvenance:
    Codable,
    Sendable,
    Equatable
{
    public let origin: String?
    public let reason: PersistedWebProvenanceReason

    public init(
        sanitizing input: String,
        transport: PersistedWebTransportClassification
    ) {
        guard transport == .publicInternet else {
            origin = nil
            reason = .rejectedNonPublic
            return
        }
        switch Self.parse(input) {
        case let .accepted(host, hasPath, hasQuery):
            origin = "https://\(host)/"
            switch (hasPath, hasQuery) {
            case (false, false):
                reason = .acceptedOrigin
            case (true, false):
                reason = .pathRedacted
            case (false, true):
                reason = .queryRedacted
            case (true, true):
                reason = .pathAndQueryRedacted
            }
        case .nonPublic:
            origin = nil
            reason = .rejectedNonPublic
        case .malformed:
            origin = nil
            reason = .rejectedMalformed
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedOrigin = try container.decodeIfPresent(
            String.self,
            forKey: .origin
        )
        let decodedReason = try container.decode(
            PersistedWebProvenanceReason.self,
            forKey: .reason
        )
        guard Self.isValidStoredPair(
            origin: decodedOrigin,
            reason: decodedReason
        ) else {
            throw DecodingError.dataCorruptedError(
                forKey: .origin,
                in: container,
                debugDescription: "Invalid persisted web provenance"
            )
        }
        origin = decodedOrigin
        reason = decodedReason
    }

    private enum ParseResult {
        case accepted(host: String, hasPath: Bool, hasQuery: Bool)
        case nonPublic
        case malformed
    }

    private enum CodingKeys: String, CodingKey {
        case origin
        case reason
    }

    private static let rejectedHostSuffixes = [
        ".localhost",
        ".local",
        ".internal",
        ".home",
        ".lan",
        ".test",
        ".example",
        ".invalid",
        ".onion",
    ]

    private static func parse(_ input: String) -> ParseResult {
        let bytes = Array(input.utf8)
        guard !bytes.isEmpty,
              bytes.count <= 2_048,
              bytes.allSatisfy({ $0 < 0x80 }),
              hasValidPercentEscapes(bytes),
              input.hasPrefix("https://")
        else {
            return .malformed
        }
        let remainder = input.dropFirst("https://".count)
        guard !remainder.isEmpty,
              !remainder.contains("#"),
              let authorityEnd = remainder.firstIndex(where: {
                  $0 == "/" || $0 == "?"
              })
        else {
            if remainder.isEmpty || remainder.contains("#") {
                return .malformed
            }
            return parseAuthorityAndSuffix(
                authority: remainder,
                suffix: Substring()
            )
        }
        return parseAuthorityAndSuffix(
            authority: remainder[..<authorityEnd],
            suffix: remainder[authorityEnd...]
        )
    }

    private static func parseAuthorityAndSuffix(
        authority: Substring,
        suffix: Substring
    ) -> ParseResult {
        guard !authority.isEmpty,
              !authority.contains("@"),
              !authority.hasPrefix("["),
              !authority.contains("]"),
              !authority.contains("%")
        else {
            return authority.hasPrefix("[") || authority.contains("]")
                ? .nonPublic
                : .malformed
        }
        let host: Substring
        if let colon = authority.lastIndex(of: ":") {
            guard authority[..<colon].contains(":") == false,
                  authority[authority.index(after: colon)...] == "443"
            else {
                return .malformed
            }
            host = authority[..<colon]
        } else {
            host = authority
        }
        guard isSyntacticallyValidHost(host) else {
            return .malformed
        }
        let hostString = String(host)
        guard isPublicDNSHost(hostString) else {
            return .nonPublic
        }

        let hasQuery: Bool
        let path: Substring
        if let queryStart = suffix.firstIndex(of: "?") {
            hasQuery = true
            path = suffix[..<queryStart]
        } else {
            hasQuery = false
            path = suffix
        }
        guard path.isEmpty || path.hasPrefix("/"),
              path != "//",
              !path.hasPrefix("//")
        else {
            return .malformed
        }
        guard !containsEncodedHomePath(path) else {
            return .malformed
        }
        let hasPath = !path.isEmpty && path != "/"
        return .accepted(
            host: hostString,
            hasPath: hasPath,
            hasQuery: hasQuery
        )
    }

    private static func isSyntacticallyValidHost(
        _ host: Substring
    ) -> Bool {
        guard !host.isEmpty,
              host.utf8.count <= 253,
              host == host.lowercased(),
              !host.hasSuffix(".")
        else {
            return false
        }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else {
            return false
        }
        return labels.allSatisfy { label in
            guard !label.isEmpty,
                  label.utf8.count <= 63,
                  !label.hasPrefix("-"),
                  !label.hasSuffix("-"),
                  !label.hasPrefix("xn--")
            else {
                return false
            }
            return label.utf8.allSatisfy {
                ($0 >= 0x61 && $0 <= 0x7a)
                    || ($0 >= 0x30 && $0 <= 0x39)
                    || $0 == 0x2d
            }
        }
    }

    private static func isPublicDNSHost(_ host: String) -> Bool {
        if host == "localhost"
            || rejectedHostSuffixes.contains(where: host.hasSuffix)
        {
            return false
        }
        if isLegacyIPv4Literal(host) {
            return false
        }
        return true
    }

    private static func isLegacyIPv4Literal(_ host: String) -> Bool {
        let labels = host.split(
            separator: ".",
            omittingEmptySubsequences: false
        )
        guard (1...4).contains(labels.count) else {
            return false
        }
        return labels.allSatisfy { label in
            if label.hasPrefix("0x") {
                let digits = label.dropFirst(2)
                return !digits.isEmpty && digits.utf8.allSatisfy(isHex)
            }
            return !label.isEmpty && label.utf8.allSatisfy {
                $0 >= 0x30 && $0 <= 0x39
            }
        }
    }

    private static func containsEncodedHomePath(_ path: Substring) -> Bool {
        guard path.contains("%"),
              let decoded = percentDecodedASCII(path)
        else {
            return false
        }
        let folded = decoded.lowercased()
        return folded.hasPrefix("/users/")
            || folded.contains("/users/")
            || folded.hasPrefix("/~")
            || folded.contains("/~/")
            || folded.hasPrefix("~")
    }

    private static func percentDecodedASCII(
        _ value: Substring
    ) -> String? {
        let bytes = Array(value.utf8)
        var decoded: [UInt8] = []
        decoded.reserveCapacity(bytes.count)
        var index = 0
        while index < bytes.count {
            if bytes[index] == 0x25 {
                guard index + 2 < bytes.count,
                      let high = hexValue(bytes[index + 1]),
                      let low = hexValue(bytes[index + 2])
                else {
                    return nil
                }
                decoded.append(high << 4 | low)
                index += 3
            } else {
                decoded.append(bytes[index])
                index += 1
            }
        }
        guard decoded.allSatisfy({ $0 < 0x80 }) else {
            return nil
        }
        return String(decoding: decoded, as: UTF8.self)
    }

    private static func hasValidPercentEscapes(_ bytes: [UInt8]) -> Bool {
        var index = 0
        while index < bytes.count {
            if bytes[index] == 0x25 {
                guard index + 2 < bytes.count,
                      isHex(bytes[index + 1]),
                      isHex(bytes[index + 2])
                else {
                    return false
                }
                index += 3
            } else {
                index += 1
            }
        }
        return true
    }

    private static func isHex(_ byte: UInt8) -> Bool {
        hexValue(byte) != nil
    }

    private static func hexValue(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 0x30 ... 0x39:
            byte - 0x30
        case 0x41 ... 0x46:
            byte - 0x41 + 10
        case 0x61 ... 0x66:
            byte - 0x61 + 10
        default:
            nil
        }
    }

    private static func isValidStoredPair(
        origin: String?,
        reason: PersistedWebProvenanceReason
    ) -> Bool {
        switch reason {
        case .acceptedOrigin,
             .pathRedacted,
             .queryRedacted,
             .pathAndQueryRedacted:
            guard let origin else {
                return false
            }
            if case let .accepted(host, hasPath, hasQuery) = parse(origin) {
                return !hasPath
                    && !hasQuery
                    && origin == "https://\(host)/"
            }
            return false
        case .rejectedNonPublic, .rejectedMalformed:
            return origin == nil
        }
    }
}
