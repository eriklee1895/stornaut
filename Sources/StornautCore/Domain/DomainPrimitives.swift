import Foundation

public enum DomainSchemaVersion: Int, Codable, Sendable, Equatable {
    case v1 = 1
    case v2 = 2
}

public enum DomainContractError: Error, Sendable, Equatable {
    case invalidIdentifier(expectedPrefix: String)
    case invalidPath
    case invalidToken
    case invalidMeasurement
    case unsupportedSchemaVersion(
        expected: DomainSchemaVersion,
        actual: DomainSchemaVersion
    )
}

public struct PersistedPath: RawRepresentable, Codable, Sendable, Hashable {
    public let rawValue: String

    public init?(rawValue: String) {
        guard Self.isValid(rawValue) else {
            return nil
        }
        self.rawValue = rawValue
    }

    public init(validating rawValue: String) throws {
        guard Self.isValid(rawValue) else {
            throw DomainContractError.invalidPath
        }
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        try self.init(validating: decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private static func isValid(_ value: String) -> Bool {
        !value.isEmpty
            && value.utf8.count <= 16_384
            && !value.contains("\0")
    }
}

public struct DomainToken: RawRepresentable, Codable, Sendable, Hashable {
    public let rawValue: String

    public init?(rawValue: String) {
        guard isSafeDomainToken(rawValue) else {
            return nil
        }
        self.rawValue = rawValue
    }

    public init(validating rawValue: String) throws {
        guard isSafeDomainToken(rawValue) else {
            throw DomainContractError.invalidToken
        }
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        try self.init(validating: decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct DomainLabel: RawRepresentable, Codable, Sendable, Hashable {
    public let rawValue: String

    public init?(rawValue: String) {
        guard Self.isValid(rawValue) else {
            return nil
        }
        self.rawValue = rawValue
    }

    public init(validating rawValue: String) throws {
        guard Self.isValid(rawValue) else {
            throw DomainContractError.invalidToken
        }
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        try self.init(validating: decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private static func isValid(_ value: String) -> Bool {
        !value.isEmpty
            && value.utf8.count <= 256
            && !value.unicodeScalars.contains {
                CharacterSet.controlCharacters.contains($0)
            }
    }
}

public protocol DomainIDTag: Sendable {
    static var prefix: String { get }
}

public struct DomainID<Tag>: RawRepresentable, Codable, Sendable, Hashable
where Tag: DomainIDTag {
    public let rawValue: String

    public init() {
        rawValue = "\(Tag.prefix)\(UUID().uuidString.lowercased())"
    }

    public init?(rawValue: String) {
        guard Self.isValid(rawValue) else {
            return nil
        }
        self.rawValue = rawValue
    }

    public init(validating rawValue: String) throws {
        guard Self.isValid(rawValue) else {
            throw DomainContractError.invalidIdentifier(
                expectedPrefix: Tag.prefix
            )
        }
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        try self.init(validating: decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private static func isValid(_ rawValue: String) -> Bool {
        rawValue.hasPrefix(Tag.prefix)
            && rawValue.count > Tag.prefix.count
            && isSafeDomainToken(rawValue)
    }
}

public enum ScanSessionIDTag: DomainIDTag {
    public static let prefix = "scan-"
}

public enum ScanScopeIDTag: DomainIDTag {
    public static let prefix = "scope-"
}

public enum SnapshotIDTag: DomainIDTag {
    public static let prefix = "snapshot-"
}

public enum ClassificationIDTag: DomainIDTag {
    public static let prefix = "classification-"
}

public enum EvidenceIDTag: DomainIDTag {
    public static let prefix = "evidence-"
}

public enum InvestigationIDTag: DomainIDTag {
    public static let prefix = "investigation-"
}

public enum InvestigationRunIDTag: DomainIDTag {
    public static let prefix = "investigation-run-"
}

public enum InvestigationReportIDTag: DomainIDTag {
    public static let prefix = "investigation-report-"
}

public enum InvestigationTargetIDTag: DomainIDTag {
    public static let prefix = "target-"
}

public enum CleanupPlanIDTag: DomainIDTag {
    public static let prefix = "plan-"
}

public enum CleanupPlanItemIDTag: DomainIDTag {
    public static let prefix = "plan-item-"
}

public enum PolicyDecisionIDTag: DomainIDTag {
    public static let prefix = "decision-"
}

public enum CleanupManifestIDTag: DomainIDTag {
    public static let prefix = "manifest-"
}

public enum CleanupActionIDTag: DomainIDTag {
    public static let prefix = "action-"
}

public enum CleanupRunIDTag: DomainIDTag {
    public static let prefix = "run-"
}

public typealias ScanSessionID = DomainID<ScanSessionIDTag>
public typealias ScanScopeID = DomainID<ScanScopeIDTag>
public typealias SnapshotID = DomainID<SnapshotIDTag>
public typealias ClassificationID = DomainID<ClassificationIDTag>
public typealias EvidenceID = DomainID<EvidenceIDTag>
public typealias InvestigationID = DomainID<InvestigationIDTag>
public typealias InvestigationRunID = DomainID<InvestigationRunIDTag>
public typealias InvestigationReportID = DomainID<InvestigationReportIDTag>
public typealias InvestigationTargetID = DomainID<InvestigationTargetIDTag>
public typealias CleanupPlanID = DomainID<CleanupPlanIDTag>
public typealias CleanupPlanItemID = DomainID<CleanupPlanItemIDTag>
public typealias PolicyDecisionID = DomainID<PolicyDecisionIDTag>
public typealias CleanupManifestID = DomainID<CleanupManifestIDTag>
public typealias CleanupActionID = DomainID<CleanupActionIDTag>
public typealias CleanupRunID = DomainID<CleanupRunIDTag>

func requireDomainSchemaVersion(
    _ actual: DomainSchemaVersion,
    expected: DomainSchemaVersion
) throws {
    guard actual == expected else {
        throw DomainContractError.unsupportedSchemaVersion(
            expected: expected,
            actual: actual
        )
    }
}

struct DomainAnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

func rejectUnknownCodingKeys(
    _ decoder: Decoder,
    allowedKeys: Set<String>
) throws {
    let container = try decoder.container(keyedBy: DomainAnyCodingKey.self)
    let unknownKeys = container.allKeys
        .map(\.stringValue)
        .filter { !allowedKeys.contains($0) }
    guard unknownKeys.isEmpty else {
        throw DecodingError.dataCorrupted(
            .init(
                codingPath: decoder.codingPath,
                debugDescription:
                    "Unknown persisted keys: \(unknownKeys.sorted())"
            )
        )
    }
}

private func isSafeDomainToken(_ rawValue: String) -> Bool {
    !rawValue.isEmpty
        && rawValue.utf8.count <= 128
        && rawValue.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 48...57, 65...90, 97...122, 45, 46, 95:
                true
            default:
                false
            }
        }
}

public struct ByteCount: Codable, Sendable, Hashable, Comparable {
    public let value: UInt64

    public init?(_ value: UInt64) {
        guard value <= UInt64(Int64.max) else {
            return nil
        }
        self.value = value
    }

    public init?(exactly value: Int64) {
        guard value >= 0 else {
            return nil
        }
        self.value = UInt64(value)
    }

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(UInt64.self)
        guard value <= UInt64(Int64.max) else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Byte count exceeds SQLite INTEGER range"
                )
            )
        }
        self.value = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.value < rhs.value
    }

    public var int64Value: Int64? {
        Int64(exactly: value)
    }
}

public struct SignedByteDelta: Codable, Sendable, Hashable, Comparable {
    public let value: Int64

    public init(_ value: Int64) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decode(Int64.self, forKey: .value)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.value < rhs.value
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case value
    }
}

protocol StrictIntegerDomainJSON {}

public enum DomainJSON {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        try DomainJSONCanonicalCodec().encode(value)
    }

    public static func decode<T: Decodable>(
        _ type: T.Type,
        from data: Data
    ) throws -> T {
        let numberPolicy: StrictDomainJSONNumberPolicy =
            type is any StrictIntegerDomainJSON.Type
                ? .exactInteger64
                : .standardJSON
        let auditor = StrictDomainJSONAuditor(
            data: data,
            numberPolicy: numberPolicy
        )
        try auditor.validate()
        return try decodePayload(type, from: data)
    }

    static func decodeCanonical<T: Codable>(
        _ type: T.Type,
        from data: Data
    ) throws -> T {
        try DomainJSONCanonicalCodec().decode(type, from: data)
    }

    private static func decodePayload<T: Decodable>(
        _ type: T.Type,
        from data: Data
    ) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode(type, from: data)
    }
}

final class DomainJSONCanonicalCodec {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
    }

    func encode<T: Encodable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }

    func decode<T: Codable>(
        _ type: T.Type,
        from data: Data
    ) throws -> T {
        let decoded = try decoder.decode(type, from: data)
        guard try encoder.encode(decoded) == data else {
            throw StrictDomainJSONError.invalidJSON
        }
        return decoded
    }
}
