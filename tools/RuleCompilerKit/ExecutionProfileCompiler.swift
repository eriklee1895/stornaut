import CryptoKit
import Foundation
import StornautCore

public struct ExecutionProfileCompileManifest:
    Codable,
    Sendable,
    Equatable
{
    public let schemaVersion: Int
    public let catalogVersion: String
    public let ruleCatalogVersion: String
    public let profileCount: Int
    public let profileIDs: [DomainToken]
    public let ruleIDs: [RuleID]
    public let catalogSHA256: String

    public init(
        catalogVersion: String,
        ruleCatalogVersion: String,
        profileCount: Int,
        profileIDs: [DomainToken],
        ruleIDs: [RuleID],
        catalogSHA256: String
    ) {
        schemaVersion = 1
        self.catalogVersion = catalogVersion
        self.ruleCatalogVersion = ruleCatalogVersion
        self.profileCount = profileCount
        self.profileIDs = profileIDs
        self.ruleIDs = ruleIDs
        self.catalogSHA256 = catalogSHA256
    }
}

public struct CompiledExecutionProfileArtifact:
    Sendable,
    Equatable
{
    public let catalog: ExecutionProfileCatalog
    public let data: Data
    public let sha256: String
    public let manifest: ExecutionProfileCompileManifest

    public init(
        catalog: ExecutionProfileCatalog,
        data: Data,
        sha256: String,
        manifest: ExecutionProfileCompileManifest
    ) {
        self.catalog = catalog
        self.data = data
        self.sha256 = sha256
        self.manifest = manifest
    }
}

public struct ExecutionProfileCompiler: Sendable {
    private static let approvedProfiles: [String: ApprovedProfile] = [
        "phase-c.go-build-cache-v1": ApprovedProfile(
            ruleID: "cache-go-build",
            relativePath: "Library/Caches/go-build",
            disposition: .reviewRecommended,
            defaultSuggestion: .never,
            exactNames: ["asm", "cgo", "compile", "go", "link"],
            versionedFamilies: [],
            fixtureIDs: [
                "cache-go-build-active",
                "cache-go-build-config",
                "cache-go-build-other",
                "cache-go-build-positive",
            ]
        ),
        "phase-c.npm-cacache-v1": ApprovedProfile(
            ruleID: "cache-npm-content",
            relativePath: ".npm/_cacache",
            disposition: .readyToReclaim,
            defaultSuggestion: .readyWhenEligible,
            exactNames: ["corepack", "node", "npm", "npx"],
            versionedFamilies: [],
            fixtureIDs: [
                "cache-npm-content-active",
                "cache-npm-content-config",
                "cache-npm-content-other",
                "cache-npm-content-positive",
            ]
        ),
        "phase-c.pip-cache-v1": ApprovedProfile(
            ruleID: "cache-pip",
            relativePath: "Library/Caches/pip",
            disposition: .readyToReclaim,
            defaultSuggestion: .readyWhenEligible,
            exactNames: ["pip", "python"],
            versionedFamilies: [.pip, .python],
            fixtureIDs: [
                "cache-pip-active",
                "cache-pip-config",
                "cache-pip-other",
                "cache-pip-positive",
            ]
        ),
    ]

    private static let approvedResolvers: [String: ExecutionEvidenceResolver] = [
        "activity.process.inactive": .currentActivity,
        "evidence.cache.layout": .compilerAttested,
        "evidence.cache.reclaimable": .compilerAttested,
        "evidence.cache.tool-owned": .compilerAttested,
        "evidence.scope.user-owned": .currentFilesystem,
    ]

    public init() {}

    public func compile(
        profileData: Data,
        ruleCatalog: RuleCatalog
    ) throws -> CompiledExecutionProfileArtifact {
        do {
            return try compileValidated(
                profileData: profileData,
                ruleCatalog: ruleCatalog
            )
        } catch let error as RuleCompilerError {
            throw error
        } catch {
            throw RuleCompilerError.invalidValue("executionProfileCatalog")
        }
    }

    private func compileValidated(
        profileData: Data,
        ruleCatalog: RuleCatalog
    ) throws -> CompiledExecutionProfileArtifact {
        let root = try strictJSONObject(profileData)
        try requireExactKeys(
            root,
            allowed: [
                "schemaVersion",
                "catalogVersion",
                "ruleCatalogVersion",
                "profiles",
            ],
            required: [
                "schemaVersion",
                "catalogVersion",
                "ruleCatalogVersion",
                "profiles",
            ],
            context: "executionProfileCatalog"
        )
        guard try integer(root, "schemaVersion") == 1 else {
            throw RuleCompilerError.invalidValue(
                "executionProfileCatalog.schemaVersion"
            )
        }
        let catalogVersion = try token(root, "catalogVersion")
        let ruleCatalogVersion = try token(root, "ruleCatalogVersion")
        guard catalogVersion.rawValue == "safe-execution-v1",
              ruleCatalogVersion == ruleCatalog.catalogVersion,
              ruleCatalogVersion.rawValue
                == "builtin-runtime-tool-residue-v2"
        else {
            throw RuleCompilerError.invalidValue(
                "executionProfileCatalog.catalogVersion"
            )
        }
        let rawProfiles = try array(root, "profiles")
        guard rawProfiles.count == Self.approvedProfiles.count else {
            throw RuleCompilerError.invalidValue(
                "executionProfileCatalog.profiles"
            )
        }
        var profiles: [ExecutionProfile] = []
        var identifiers = Set<DomainToken>()
        var ruleIdentifiers = Set<RuleID>()
        for (index, value) in rawProfiles.enumerated() {
            let profile = try decodeProfile(
                try object(
                    value,
                    context: "executionProfileCatalog.profiles[\(index)]"
                ),
                context: "executionProfileCatalog.profiles[\(index)]"
            )
            guard identifiers.insert(profile.id).inserted,
                  ruleIdentifiers.insert(profile.ruleID).inserted
            else {
                throw RuleCompilerError.invalidValue(
                    "executionProfileCatalog.profiles"
                )
            }
            try validate(profile, ruleCatalog: ruleCatalog)
            profiles.append(profile)
        }
        guard Set(profiles.map(\.id.rawValue))
                == Set(Self.approvedProfiles.keys)
        else {
            throw RuleCompilerError.invalidValue(
                "executionProfileCatalog.profiles"
            )
        }
        let catalog = try ExecutionProfileCatalog(
            catalogVersion: catalogVersion,
            ruleCatalogVersion: ruleCatalogVersion,
            profiles: profiles.sorted {
                $0.id.rawValue < $1.id.rawValue
            }
        )
        let data = try DomainJSON.encode(catalog)
        let sha256 = SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
        let manifest = ExecutionProfileCompileManifest(
            catalogVersion: catalog.catalogVersion.rawValue,
            ruleCatalogVersion: catalog.ruleCatalogVersion.rawValue,
            profileCount: catalog.profiles.count,
            profileIDs: catalog.profiles.map(\.id),
            ruleIDs: catalog.profiles.map(\.ruleID),
            catalogSHA256: sha256
        )
        return CompiledExecutionProfileArtifact(
            catalog: catalog,
            data: data,
            sha256: sha256,
            manifest: manifest
        )
    }

    private func decodeProfile(
        _ object: [String: Any],
        context: String
    ) throws -> ExecutionProfile {
        try requireExactKeys(
            object,
            allowed: [
                "id",
                "ruleID",
                "relativePath",
                "expectedKind",
                "resolverBindings",
                "processSubjects",
                "defaultSuggestion",
                "fixtureIDs",
            ],
            required: [
                "id",
                "ruleID",
                "relativePath",
                "expectedKind",
                "resolverBindings",
                "processSubjects",
                "defaultSuggestion",
                "fixtureIDs",
            ],
            context: context
        )
        guard let ruleID = RuleID(rawValue: try string(object, "ruleID")),
              let path = RulePathPattern(
                  rawValue: try string(object, "relativePath")
              )
        else {
            throw RuleCompilerError.invalidValue(context)
        }
        let resolverValues = try array(object, "resolverBindings")
        guard !resolverValues.isEmpty, resolverValues.count <= 16 else {
            throw RuleCompilerError.invalidValue(
                "\(context).resolverBindings"
            )
        }
        let resolverBindings = try resolverValues.enumerated().map {
            index,
            value in
            let bindingContext = "\(context).resolverBindings[\(index)]"
            let binding = try self.object(value, context: bindingContext)
            try requireExactKeys(
                binding,
                allowed: ["key", "resolver"],
                required: ["key", "resolver"],
                context: bindingContext
            )
            return ExecutionEvidenceBinding(
                key: try token(binding, "key"),
                resolver: try enumeration(
                    ExecutionEvidenceResolver.self,
                    object: binding,
                    key: "resolver"
                )
            )
        }
        let processObject = try self.object(
            try required(object, "processSubjects"),
            context: "\(context).processSubjects"
        )
        try requireExactKeys(
            processObject,
            allowed: [
                "bundleIdentifiers",
                "exactNames",
                "versionedFamilies",
            ],
            required: [
                "bundleIdentifiers",
                "exactNames",
                "versionedFamilies",
            ],
            context: "\(context).processSubjects"
        )
        let bundles = try tokens(processObject, "bundleIdentifiers")
        let exactNames = try strings(
            processObject,
            "exactNames",
            maximumCount: 64
        ).map {
            guard let label = DomainLabel(rawValue: $0) else {
                throw RuleCompilerError.invalidValue(
                    "\(context).processSubjects.exactNames"
                )
            }
            return label
        }
        let versionedFamilies = try strings(
            processObject,
            "versionedFamilies",
            maximumCount: 2
        ).map {
            guard let family = VersionedProcessFamily(rawValue: $0) else {
                throw RuleCompilerError.invalidValue(
                    "\(context).processSubjects.versionedFamilies"
                )
            }
            return family
        }
        return try ExecutionProfile(
            id: try token(object, "id"),
            ruleID: ruleID,
            relativePath: path,
            expectedKind: try enumeration(
                RuleExpectedKind.self,
                object: object,
                key: "expectedKind"
            ),
            resolverBindings: resolverBindings,
            processSubjects: try ExecutionProcessSubjects(
                bundleIdentifiers: bundles,
                exactNames: exactNames,
                versionedFamilies: versionedFamilies
            ),
            defaultSuggestion: try enumeration(
                ExecutionDefaultSuggestion.self,
                object: object,
                key: "defaultSuggestion"
            ),
            fixtureIDs: try tokens(object, "fixtureIDs")
        )
    }

    private func validate(
        _ profile: ExecutionProfile,
        ruleCatalog: RuleCatalog
    ) throws {
        guard let approved = Self.approvedProfiles[profile.id.rawValue],
              profile.ruleID.rawValue == approved.ruleID,
              profile.relativePath.rawValue == approved.relativePath,
              profile.expectedKind == .directory,
              profile.defaultSuggestion == approved.defaultSuggestion,
              profile.processSubjects.bundleIdentifiers.isEmpty,
              profile.processSubjects.exactNames.map(\.rawValue)
                == approved.exactNames,
              profile.processSubjects.versionedFamilies
                == approved.versionedFamilies,
              profile.fixtureIDs.map(\.rawValue) == approved.fixtureIDs,
              Dictionary(
                  uniqueKeysWithValues: profile.resolverBindings.map {
                      ($0.key.rawValue, $0.resolver)
                  }
              ) == Self.approvedResolvers,
              let rule = ruleCatalog.rules.first(where: {
                  $0.id == profile.ruleID
              }),
              rule.match.pathPattern.rawValue == approved.relativePath,
              rule.match.expectedKind == .directory,
              rule.disposition == approved.disposition,
              rule.confidenceRequirement == .high,
              !rule.veto,
              rule.recovery != nil,
              rule.recommendedAction == .moveToTrash,
              Set(rule.requiredEvidenceKeys.map(\.rawValue)
                  + rule.requiredActivityKeys.map(\.rawValue))
                == Set(Self.approvedResolvers.keys),
              rule.fixtureIDs == profile.fixtureIDs
        else {
            throw RuleCompilerError.invalidValue(
                "executionProfileCatalog.profile"
            )
        }
    }

    private func strictJSONObject(_ data: Data) throws -> [String: Any] {
        guard data.count <= RuleSourceCompiler.maximumInputBytes else {
            throw RuleCompilerError.inputTooLarge(
                limit: RuleSourceCompiler.maximumInputBytes
            )
        }
        var auditor = StrictJSONAuditor(data: data)
        try auditor.validate()
        let value: Any
        do {
            value = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw RuleCompilerError.invalidJSON
        }
        return try object(value, context: "root")
    }

    private func requireExactKeys(
        _ object: [String: Any],
        allowed: Set<String>,
        required: Set<String>,
        context: String
    ) throws {
        if let unknown = Set(object.keys).subtracting(allowed).sorted().first {
            throw RuleCompilerError.unknownField("\(context).\(unknown)")
        }
        if let missing = required.subtracting(object.keys).sorted().first {
            throw RuleCompilerError.missingField("\(context).\(missing)")
        }
    }

    private func required(
        _ object: [String: Any],
        _ key: String
    ) throws -> Any {
        guard let value = object[key] else {
            throw RuleCompilerError.missingField(key)
        }
        return value
    }

    private func object(
        _ value: Any,
        context: String
    ) throws -> [String: Any] {
        guard let object = value as? [String: Any] else {
            throw RuleCompilerError.invalidValue(context)
        }
        return object
    }

    private func array(
        _ object: [String: Any],
        _ key: String
    ) throws -> [Any] {
        guard let values = object[key] as? [Any] else {
            throw RuleCompilerError.invalidValue(key)
        }
        return values
    }

    private func string(
        _ object: [String: Any],
        _ key: String
    ) throws -> String {
        guard let value = object[key] as? String, !value.isEmpty else {
            throw RuleCompilerError.invalidValue(key)
        }
        return value
    }

    private func strings(
        _ object: [String: Any],
        _ key: String,
        maximumCount: Int
    ) throws -> [String] {
        let values = try array(object, key)
        guard values.count <= maximumCount else {
            throw RuleCompilerError.invalidValue(key)
        }
        return try values.map {
            guard let value = $0 as? String, !value.isEmpty else {
                throw RuleCompilerError.invalidValue(key)
            }
            return value
        }
    }

    private func integer(
        _ object: [String: Any],
        _ key: String
    ) throws -> Int {
        guard let number = object[key] as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.rounded() == number.doubleValue
        else {
            throw RuleCompilerError.invalidValue(key)
        }
        return number.intValue
    }

    private func token(
        _ object: [String: Any],
        _ key: String
    ) throws -> DomainToken {
        guard let token = DomainToken(rawValue: try string(object, key)) else {
            throw RuleCompilerError.invalidValue(key)
        }
        return token
    }

    private func tokens(
        _ object: [String: Any],
        _ key: String
    ) throws -> [DomainToken] {
        try strings(object, key, maximumCount: 64).map {
            guard let token = DomainToken(rawValue: $0) else {
                throw RuleCompilerError.invalidValue(key)
            }
            return token
        }
    }

    private func enumeration<T: RawRepresentable>(
        _ type: T.Type,
        object: [String: Any],
        key: String
    ) throws -> T where T.RawValue == String {
        guard let value = T(rawValue: try string(object, key)) else {
            throw RuleCompilerError.invalidValue(key)
        }
        return value
    }
}

private struct ApprovedProfile {
    let ruleID: String
    let relativePath: String
    let disposition: ReclaimDisposition
    let defaultSuggestion: ExecutionDefaultSuggestion
    let exactNames: [String]
    let versionedFamilies: [VersionedProcessFamily]
    let fixtureIDs: [String]
}
