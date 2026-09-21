import Foundation

public enum RuleCatalogError: Error, Sendable, Equatable {
    case invalidIdentifier
    case invalidPattern
    case invalidDate
    case invalidSource
    case invalidRule
    case invalidCatalog
}

public struct RuleID: RawRepresentable, Codable, Sendable, Hashable, Comparable {
    public let rawValue: String

    public init?(rawValue: String) {
        guard Self.isValid(rawValue) else {
            return nil
        }
        self.rawValue = rawValue
    }

    public init(validating rawValue: String) throws {
        guard Self.isValid(rawValue) else {
            throw RuleCatalogError.invalidIdentifier
        }
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        try self.init(
            validating: decoder.singleValueContainer().decode(String.self)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    private static func isValid(_ value: String) -> Bool {
        guard !value.isEmpty,
              value.utf8.count <= 96,
              let first = value.utf8.first,
              (97...122).contains(first)
        else {
            return false
        }
        var previousWasSeparator = false
        for byte in value.utf8 {
            let isLetterOrDigit = (97...122).contains(byte)
                || (48...57).contains(byte)
            let isSeparator = byte == 45 || byte == 46 || byte == 95
            guard isLetterOrDigit || isSeparator,
                  !(isSeparator && previousWasSeparator)
            else {
                return false
            }
            previousWasSeparator = isSeparator
        }
        return !previousWasSeparator
    }
}

public struct RulePathPattern:
    RawRepresentable,
    Codable,
    Sendable,
    Hashable,
    Comparable
{
    public let rawValue: String

    public init?(rawValue: String) {
        guard Self.isValid(rawValue) else {
            return nil
        }
        self.rawValue = rawValue
    }

    public init(validating rawValue: String) throws {
        guard Self.isValid(rawValue) else {
            throw RuleCatalogError.invalidPattern
        }
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        try self.init(
            validating: decoder.singleValueContainer().decode(String.self)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    private static func isValid(_ value: String) -> Bool {
        guard !value.isEmpty,
              value.utf8.count <= 512,
              value != ".",
              value != "~",
              value != "*",
              value != "**",
              !value.hasPrefix("/"),
              !value.hasSuffix("/"),
              !value.contains("//"),
              !value.contains("\\"),
              !value.contains("?"),
              !value.contains("["),
              !value.contains("]"),
              !value.contains("\0"),
              !value.unicodeScalars.contains(where: {
                  CharacterSet.controlCharacters.contains($0)
              })
        else {
            return false
        }
        var hasLiteral = false
        for component in value.split(
            separator: "/",
            omittingEmptySubsequences: false
        ) {
            guard !component.isEmpty,
                  component != ".",
                  component != "..",
                  component.utf8.count <= 255
            else {
                return false
            }
            if component == "*" || component == "**" {
                continue
            }
            guard !component.contains("*") else {
                return false
            }
            hasLiteral = true
        }
        return hasLiteral
    }
}

public struct RuleVerificationDate:
    RawRepresentable,
    Codable,
    Sendable,
    Hashable,
    Comparable
{
    public let rawValue: String

    public init?(rawValue: String) {
        guard Self.isValid(rawValue) else {
            return nil
        }
        self.rawValue = rawValue
    }

    public init(validating rawValue: String) throws {
        guard Self.isValid(rawValue) else {
            throw RuleCatalogError.invalidDate
        }
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        try self.init(
            validating: decoder.singleValueContainer().decode(String.self)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    private static func isValid(_ value: String) -> Bool {
        guard value.utf8.count == 10,
              value[value.index(value.startIndex, offsetBy: 4)] == "-",
              value[value.index(value.startIndex, offsetBy: 7)] == "-"
        else {
            return false
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: value) else {
            return false
        }
        return formatter.string(from: date) == value
    }
}

public enum RuleExpectedKind: String, Codable, Sendable, CaseIterable {
    case regularFile
    case directory
    case symbolicLink
    case other
}

public enum RuleRecommendedAction: String, Codable, Sendable, CaseIterable {
    case none
    case moveToTrash
}

public enum RuleSourceUsage: String, Codable, Sendable, CaseIterable {
    case behaviorReferenceOnly
    case officialDocumentation
    case independentObservation
    case blackBoxVerification
}

public struct RuleMatch: Codable, Sendable, Equatable {
    public let pathPattern: RulePathPattern
    public let expectedKind: RuleExpectedKind

    public init(
        pathPattern: RulePathPattern,
        expectedKind: RuleExpectedKind
    ) {
        self.pathPattern = pathPattern
        self.expectedKind = expectedKind
    }
}

public struct RuleProvenanceSource: Codable, Sendable, Equatable {
    public let project: DomainLabel
    public let url: URL
    public let revision: DomainToken
    public let license: DomainToken
    public let usage: RuleSourceUsage

    public init(
        project: DomainLabel,
        url: URL,
        revision: DomainToken,
        license: DomainToken,
        usage: RuleSourceUsage
    ) throws {
        guard url.scheme == "https",
              url.host != nil,
              url.user == nil,
              url.password == nil
        else {
            throw RuleCatalogError.invalidSource
        }
        self.project = project
        self.url = url
        self.revision = revision
        self.license = license
        self.usage = usage
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            project: container.decode(DomainLabel.self, forKey: .project),
            url: container.decode(URL.self, forKey: .url),
            revision: container.decode(DomainToken.self, forKey: .revision),
            license: container.decode(DomainToken.self, forKey: .license),
            usage: container.decode(RuleSourceUsage.self, forKey: .usage)
        )
    }
}

public struct RuleProvenance: Codable, Sendable, Equatable {
    public let sources: [RuleProvenanceSource]
    public let independentlyVerified: Bool
    public let verifiedAt: RuleVerificationDate

    public init(
        sources: [RuleProvenanceSource],
        independentlyVerified: Bool,
        verifiedAt: RuleVerificationDate
    ) throws {
        guard !sources.isEmpty,
              independentlyVerified,
              Set(sources.map {
                  "\($0.url.absoluteString)|\($0.revision.rawValue)"
              }).count == sources.count
        else {
            throw RuleCatalogError.invalidSource
        }
        self.sources = sources
        self.independentlyVerified = independentlyVerified
        self.verifiedAt = verifiedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            sources: container.decode(
                [RuleProvenanceSource].self,
                forKey: .sources
            ),
            independentlyVerified: container.decode(
                Bool.self,
                forKey: .independentlyVerified
            ),
            verifiedAt: container.decode(
                RuleVerificationDate.self,
                forKey: .verifiedAt
            )
        )
    }
}

public struct CompiledRule: Codable, Sendable, Equatable {
    public let id: RuleID
    public let match: RuleMatch
    public let excludedPatterns: [RulePathPattern]
    public let producer: DomainLabel
    public let rationaleKey: DomainToken
    public let category: ArtifactCategory
    public let disposition: ReclaimDisposition
    public let risk: RiskLevel
    public let confidenceRequirement: EvidenceConfidence
    public let veto: Bool
    public let requiredEvidenceKeys: [DomainToken]
    public let requiredActivityKeys: [DomainToken]
    public let recovery: RecoveryGuidance?
    public let recommendedAction: RuleRecommendedAction
    public let provenance: RuleProvenance
    public let fixtureIDs: [DomainToken]
    public let appliedOverlayIDs: [RuleID]

    public init(
        id: RuleID,
        match: RuleMatch,
        excludedPatterns: [RulePathPattern] = [],
        producer: DomainLabel,
        rationaleKey: DomainToken,
        category: ArtifactCategory,
        disposition: ReclaimDisposition,
        risk: RiskLevel,
        confidenceRequirement: EvidenceConfidence,
        veto: Bool,
        requiredEvidenceKeys: [DomainToken],
        requiredActivityKeys: [DomainToken],
        recovery: RecoveryGuidance?,
        recommendedAction: RuleRecommendedAction,
        provenance: RuleProvenance,
        fixtureIDs: [DomainToken],
        appliedOverlayIDs: [RuleID] = []
    ) throws {
        let evidence = Set(requiredEvidenceKeys)
        let activity = Set(requiredActivityKeys)
        let exclusions = Set(excludedPatterns)
        let fixtures = Set(fixtureIDs)
        let overlayIDs = Set(appliedOverlayIDs)
        guard evidence.count == requiredEvidenceKeys.count,
              activity.count == requiredActivityKeys.count,
              exclusions.count == excludedPatterns.count,
              fixtures.count == fixtureIDs.count,
              overlayIDs.count == appliedOverlayIDs.count,
              fixtureIDs.count >= 2,
              category == .protected || disposition != .protected,
              category != .protected || disposition == .protected,
              !veto || disposition == .protected,
              disposition != .protected || veto,
              disposition != .protected || risk == .critical,
              (disposition != .protected && disposition != .unknown)
                || recommendedAction == .none
        else {
            throw RuleCatalogError.invalidRule
        }
        if disposition == .readyToReclaim {
            guard !veto,
                  recovery != nil,
                  confidenceRequirement == .high,
                  !requiredEvidenceKeys.isEmpty,
                  !requiredActivityKeys.isEmpty,
                  recommendedAction == .moveToTrash
            else {
                throw RuleCatalogError.invalidRule
            }
        }
        if recommendedAction == .moveToTrash {
            guard recovery != nil,
                  !requiredEvidenceKeys.isEmpty,
                  !requiredActivityKeys.isEmpty
            else {
                throw RuleCatalogError.invalidRule
            }
        }
        self.id = id
        self.match = match
        self.excludedPatterns = excludedPatterns.sorted()
        self.producer = producer
        self.rationaleKey = rationaleKey
        self.category = category
        self.disposition = disposition
        self.risk = risk
        self.confidenceRequirement = confidenceRequirement
        self.veto = veto
        self.requiredEvidenceKeys = requiredEvidenceKeys.sorted {
            $0.rawValue < $1.rawValue
        }
        self.requiredActivityKeys = requiredActivityKeys.sorted {
            $0.rawValue < $1.rawValue
        }
        self.recovery = recovery
        self.recommendedAction = recommendedAction
        self.provenance = provenance
        self.fixtureIDs = fixtureIDs.sorted {
            $0.rawValue < $1.rawValue
        }
        self.appliedOverlayIDs = appliedOverlayIDs.sorted()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(RuleID.self, forKey: .id),
            match: container.decode(RuleMatch.self, forKey: .match),
            excludedPatterns: container.decode(
                [RulePathPattern].self,
                forKey: .excludedPatterns
            ),
            producer: container.decode(DomainLabel.self, forKey: .producer),
            rationaleKey: container.decode(
                DomainToken.self,
                forKey: .rationaleKey
            ),
            category: container.decode(ArtifactCategory.self, forKey: .category),
            disposition: container.decode(
                ReclaimDisposition.self,
                forKey: .disposition
            ),
            risk: container.decode(RiskLevel.self, forKey: .risk),
            confidenceRequirement: container.decode(
                EvidenceConfidence.self,
                forKey: .confidenceRequirement
            ),
            veto: container.decode(Bool.self, forKey: .veto),
            requiredEvidenceKeys: container.decode(
                [DomainToken].self,
                forKey: .requiredEvidenceKeys
            ),
            requiredActivityKeys: container.decode(
                [DomainToken].self,
                forKey: .requiredActivityKeys
            ),
            recovery: container.decodeIfPresent(
                RecoveryGuidance.self,
                forKey: .recovery
            ),
            recommendedAction: container.decode(
                RuleRecommendedAction.self,
                forKey: .recommendedAction
            ),
            provenance: container.decode(
                RuleProvenance.self,
                forKey: .provenance
            ),
            fixtureIDs: container.decode(
                [DomainToken].self,
                forKey: .fixtureIDs
            ),
            appliedOverlayIDs: container.decode(
                [RuleID].self,
                forKey: .appliedOverlayIDs
            )
        )
    }
}

public struct RuleCatalog: Codable, Sendable, Equatable {
    public let schemaVersion: DomainSchemaVersion
    public let catalogVersion: DomainToken
    public let rules: [CompiledRule]

    public init(
        schemaVersion: DomainSchemaVersion = .v1,
        catalogVersion: DomainToken,
        rules: [CompiledRule]
    ) throws {
        try requireDomainSchemaVersion(schemaVersion, expected: .v1)
        let sorted = rules.sorted { $0.id < $1.id }
        let allFixtures = rules.flatMap(\.fixtureIDs)
        guard !rules.isEmpty,
              Set(rules.map(\.id)).count == rules.count,
              Set(allFixtures).count == allFixtures.count,
              rules == sorted
        else {
            throw RuleCatalogError.invalidCatalog
        }
        self.schemaVersion = schemaVersion
        self.catalogVersion = catalogVersion
        self.rules = rules
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(
                DomainSchemaVersion.self,
                forKey: .schemaVersion
            ),
            catalogVersion: container.decode(
                DomainToken.self,
                forKey: .catalogVersion
            ),
            rules: container.decode([CompiledRule].self, forKey: .rules)
        )
    }
}
