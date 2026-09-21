import Foundation

public enum ExecutionProfileCatalogError:
    Error,
    Sendable,
    Equatable
{
    case invalidProfile
    case invalidCatalog
}

public enum ExecutionEvidenceResolver:
    String,
    Codable,
    Sendable,
    CaseIterable
{
    case compilerAttested
    case currentFilesystem
    case currentActivity
}

public struct ExecutionEvidenceBinding:
    Codable,
    Sendable,
    Equatable
{
    public let key: DomainToken
    public let resolver: ExecutionEvidenceResolver

    public init(
        key: DomainToken,
        resolver: ExecutionEvidenceResolver
    ) {
        self.key = key
        self.resolver = resolver
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            key: try container.decode(DomainToken.self, forKey: .key),
            resolver: try container.decode(
                ExecutionEvidenceResolver.self,
                forKey: .resolver
            )
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case key
        case resolver
    }
}

public enum VersionedProcessFamily:
    String,
    Codable,
    Sendable,
    CaseIterable
{
    case python
    case pip
}

public struct ExecutionProcessSubjects:
    Codable,
    Sendable,
    Equatable
{
    public let bundleIdentifiers: [DomainToken]
    public let exactNames: [DomainLabel]
    public let versionedFamilies: [VersionedProcessFamily]

    public init(
        bundleIdentifiers: [DomainToken],
        exactNames: [DomainLabel],
        versionedFamilies: [VersionedProcessFamily]
    ) throws {
        guard bundleIdentifiers.isEmpty,
              !exactNames.isEmpty,
              exactNames.count <= 64,
              Set(exactNames).count == exactNames.count,
              versionedFamilies.count <= 2,
              Set(versionedFamilies).count == versionedFamilies.count
        else {
            throw ExecutionProfileCatalogError.invalidProfile
        }
        self.bundleIdentifiers = []
        self.exactNames = exactNames.sorted {
            $0.rawValue < $1.rawValue
        }
        self.versionedFamilies = versionedFamilies.sorted {
            $0.rawValue < $1.rawValue
        }
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            bundleIdentifiers: container.decode(
                [DomainToken].self,
                forKey: .bundleIdentifiers
            ),
            exactNames: container.decode(
                [DomainLabel].self,
                forKey: .exactNames
            ),
            versionedFamilies: container.decode(
                [VersionedProcessFamily].self,
                forKey: .versionedFamilies
            )
        )
    }

    public func matches(processName: String) -> Bool {
        guard Self.isASCII(processName),
              processName.utf8.count <= 32
        else {
            return false
        }
        let normalized = processName.lowercased()
        if exactNames.contains(where: { $0.rawValue == normalized }) {
            return true
        }
        return versionedFamilies.contains {
            Self.matchesVersioned(normalized, family: $0)
        }
    }

    private static func matchesVersioned(
        _ name: String,
        family: VersionedProcessFamily
    ) -> Bool {
        let prefix = family.rawValue
        guard name.hasPrefix(prefix) else {
            return false
        }
        let suffix = name.dropFirst(prefix.count)
        guard !suffix.isEmpty,
              suffix.utf8.count <= 8,
              suffix.first != ".",
              suffix.last != "."
        else {
            return false
        }
        let components = suffix.split(
            separator: ".",
            omittingEmptySubsequences: false
        )
        guard components.count <= 3 else {
            return false
        }
        return components.allSatisfy { component in
            !component.isEmpty
                && component.utf8.count <= 3
                && component.utf8.allSatisfy {
                    (48...57).contains($0)
                }
        }
    }

    private static func isASCII(_ value: String) -> Bool {
        value.unicodeScalars.allSatisfy { $0.value < 128 }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case bundleIdentifiers
        case exactNames
        case versionedFamilies
    }
}

public enum ExecutionDefaultSuggestion:
    String,
    Codable,
    Sendable,
    CaseIterable
{
    case readyWhenEligible
    case never
}

public struct ExecutionProfile:
    Codable,
    Sendable,
    Equatable
{
    public let id: DomainToken
    public let ruleID: RuleID
    public let relativePath: RulePathPattern
    public let expectedKind: RuleExpectedKind
    public let resolverBindings: [ExecutionEvidenceBinding]
    public let processSubjects: ExecutionProcessSubjects
    public let defaultSuggestion: ExecutionDefaultSuggestion
    public let fixtureIDs: [DomainToken]

    public init(
        id: DomainToken,
        ruleID: RuleID,
        relativePath: RulePathPattern,
        expectedKind: RuleExpectedKind,
        resolverBindings: [ExecutionEvidenceBinding],
        processSubjects: ExecutionProcessSubjects,
        defaultSuggestion: ExecutionDefaultSuggestion,
        fixtureIDs: [DomainToken]
    ) throws {
        let resolverKeys = resolverBindings.map(\.key)
        guard expectedKind == .directory,
              Self.isExactPath(relativePath),
              !resolverBindings.isEmpty,
              resolverBindings.count <= 16,
              Set(resolverKeys).count == resolverKeys.count,
              fixtureIDs.count == 4,
              Set(fixtureIDs).count == fixtureIDs.count
        else {
            throw ExecutionProfileCatalogError.invalidProfile
        }
        self.id = id
        self.ruleID = ruleID
        self.relativePath = relativePath
        self.expectedKind = expectedKind
        self.resolverBindings = resolverBindings.sorted {
            $0.key.rawValue < $1.key.rawValue
        }
        self.processSubjects = processSubjects
        self.defaultSuggestion = defaultSuggestion
        self.fixtureIDs = fixtureIDs.sorted {
            $0.rawValue < $1.rawValue
        }
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(DomainToken.self, forKey: .id),
            ruleID: container.decode(RuleID.self, forKey: .ruleID),
            relativePath: container.decode(
                RulePathPattern.self,
                forKey: .relativePath
            ),
            expectedKind: container.decode(
                RuleExpectedKind.self,
                forKey: .expectedKind
            ),
            resolverBindings: container.decode(
                [ExecutionEvidenceBinding].self,
                forKey: .resolverBindings
            ),
            processSubjects: container.decode(
                ExecutionProcessSubjects.self,
                forKey: .processSubjects
            ),
            defaultSuggestion: container.decode(
                ExecutionDefaultSuggestion.self,
                forKey: .defaultSuggestion
            ),
            fixtureIDs: container.decode(
                [DomainToken].self,
                forKey: .fixtureIDs
            )
        )
    }

    private static func isExactPath(_ path: RulePathPattern) -> Bool {
        let value = path.rawValue
        return !value.contains("*")
            && !value.hasPrefix("/")
            && value.split(separator: "/").allSatisfy {
                !$0.isEmpty && $0 != "." && $0 != ".."
            }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case ruleID
        case relativePath
        case expectedKind
        case resolverBindings
        case processSubjects
        case defaultSuggestion
        case fixtureIDs
    }
}

public struct ExecutionProfileCatalog:
    Codable,
    Sendable,
    Equatable
{
    public let schemaVersion: DomainSchemaVersion
    public let catalogVersion: DomainToken
    public let ruleCatalogVersion: DomainToken
    public let profiles: [ExecutionProfile]

    public init(
        schemaVersion: DomainSchemaVersion = .v1,
        catalogVersion: DomainToken,
        ruleCatalogVersion: DomainToken,
        profiles: [ExecutionProfile]
    ) throws {
        try requireDomainSchemaVersion(schemaVersion, expected: .v1)
        let sorted = profiles.sorted {
            $0.id.rawValue < $1.id.rawValue
        }
        guard !profiles.isEmpty,
              profiles.count <= 100,
              profiles == sorted,
              Set(profiles.map(\.id)).count == profiles.count,
              Set(profiles.map(\.ruleID)).count == profiles.count
        else {
            throw ExecutionProfileCatalogError.invalidCatalog
        }
        self.schemaVersion = schemaVersion
        self.catalogVersion = catalogVersion
        self.ruleCatalogVersion = ruleCatalogVersion
        self.profiles = profiles
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
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
            ruleCatalogVersion: container.decode(
                DomainToken.self,
                forKey: .ruleCatalogVersion
            ),
            profiles: container.decode(
                [ExecutionProfile].self,
                forKey: .profiles
            )
        )
    }

    public func profile(ruleID: RuleID) -> ExecutionProfile? {
        profiles.first { $0.ruleID == ruleID }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case catalogVersion
        case ruleCatalogVersion
        case profiles
    }
}
