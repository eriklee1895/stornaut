import CryptoKit
import Foundation
import StornautCore

public enum RuleCompilerError: Error, Sendable, Equatable {
    case inputTooLarge(limit: Int)
    case invalidJSON
    case duplicateKey(String)
    case nestingTooDeep(limit: Int)
    case scalarTooLarge(limit: Int)
    case unknownField(String)
    case missingField(String)
    case invalidValue(String)
    case duplicateRule(String)
    case duplicateOverlay(String)
    case overlayTargetMissing(String)
    case overlayNotConservative(String)
}

public struct RuleManifestEntry: Codable, Sendable, Equatable {
    public let ruleID: RuleID
    public let rationaleKey: DomainToken
    public let provenance: RuleProvenance
    public let fixtureIDs: [DomainToken]

    public init(rule: CompiledRule) {
        ruleID = rule.id
        rationaleKey = rule.rationaleKey
        provenance = rule.provenance
        fixtureIDs = rule.fixtureIDs
    }
}

public struct RuleCompileManifest: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let catalogVersion: String
    public let sourceCatalogVersions: [String]
    public let ruleCount: Int
    public let ruleIDs: [RuleID]
    public let provenanceSourceCount: Int
    public let fixtureCount: Int
    public let appliedOverlayCount: Int
    public let catalogSHA256: String
    public let rules: [RuleManifestEntry]

    public init(
        catalogVersion: String,
        sourceCatalogVersions: [String],
        ruleCount: Int,
        ruleIDs: [RuleID],
        provenanceSourceCount: Int,
        fixtureCount: Int,
        appliedOverlayCount: Int,
        catalogSHA256: String,
        rules: [RuleManifestEntry]
    ) {
        schemaVersion = 2
        self.catalogVersion = catalogVersion
        self.sourceCatalogVersions = sourceCatalogVersions
        self.ruleCount = ruleCount
        self.ruleIDs = ruleIDs
        self.provenanceSourceCount = provenanceSourceCount
        self.fixtureCount = fixtureCount
        self.appliedOverlayCount = appliedOverlayCount
        self.catalogSHA256 = catalogSHA256
        self.rules = rules
    }
}

public struct CompiledRuleArtifact: Sendable, Equatable {
    public let catalog: RuleCatalog
    public let data: Data
    public let sha256: String
    public let manifest: RuleCompileManifest

    public init(
        catalog: RuleCatalog,
        data: Data,
        sha256: String,
        manifest: RuleCompileManifest
    ) {
        self.catalog = catalog
        self.data = data
        self.sha256 = sha256
        self.manifest = manifest
    }
}

public struct RuleSourceCompiler: Sendable {
    public static let maximumInputBytes = 1_048_576
    public static let maximumSourceCount = 16
    public static let maximumRuleCount = 4_096
    public static let maximumNestingDepth = 16
    public static let maximumScalarBytes = 16_384

    private let maximumVerificationDate: String

    public init(
        maximumVerificationDate: RuleVerificationDate? = nil
    ) {
        self.maximumVerificationDate = maximumVerificationDate?.rawValue
            ?? Self.currentUTCDateString()
    }

    public func compile(
        catalogData: Data,
        overlayData: Data? = nil,
        promotionData: Data? = nil
    ) throws -> CompiledRuleArtifact {
        try compile(
            catalogSources: [catalogData],
            catalogVersion: try catalogVersion(catalogData),
            overlayData: overlayData,
            promotionData: promotionData
        )
    }

    public func compile(
        catalogSources: [Data],
        catalogVersion: DomainToken,
        overlayData: Data? = nil,
        promotionData: Data? = nil
    ) throws -> CompiledRuleArtifact {
        do {
            return try compileValidated(
                catalogSources: catalogSources,
                catalogVersion: catalogVersion,
                overlayData: overlayData,
                promotionData: promotionData
            )
        } catch let error as RuleCompilerError {
            throw error
        } catch {
            throw RuleCompilerError.invalidValue("catalog")
        }
    }

    public func compile(
        catalogSources: [Data],
        catalogVersion: String,
        overlayData: Data? = nil,
        promotionData: Data? = nil
    ) throws -> CompiledRuleArtifact {
        guard let version = DomainToken(rawValue: catalogVersion) else {
            throw RuleCompilerError.invalidValue("catalogVersion")
        }
        return try compile(
            catalogSources: catalogSources,
            catalogVersion: version,
            overlayData: overlayData,
            promotionData: promotionData
        )
    }

    private func compileValidated(
        catalogSources: [Data],
        catalogVersion: DomainToken,
        overlayData: Data?,
        promotionData: Data?
    ) throws -> CompiledRuleArtifact {
        guard !catalogSources.isEmpty,
              catalogSources.count <= Self.maximumSourceCount,
              catalogSources.reduce(0, { $0 + $1.count })
                <= Self.maximumInputBytes
        else {
            throw RuleCompilerError.invalidValue("catalogSources")
        }
        let decodedSources = try catalogSources.map {
            (version: try self.catalogVersion($0), rules: try decodeCatalog($0))
        }
        let sourceVersions = decodedSources.map(\.version).sorted {
            $0.rawValue < $1.rawValue
        }
        guard Set(sourceVersions).count == sourceVersions.count else {
            throw RuleCompilerError.invalidValue("catalogSources")
        }
        var ruleIDs = Set<RuleID>()
        var rules: [CompiledRule] = []
        var effectiveSourceVersions = sourceVersions
        for rule in decodedSources.flatMap(\.rules) {
            guard ruleIDs.insert(rule.id).inserted else {
                throw RuleCompilerError.duplicateRule(rule.id.rawValue)
            }
            rules.append(rule)
        }
        guard rules.count <= Self.maximumRuleCount else {
            throw RuleCompilerError.invalidValue("catalog.rules")
        }
        let overlayVersion: DomainToken?
        let overlays: [SourceOverlay]
        if let overlayData {
            let decoded = try decodeOverlays(overlayData)
            overlayVersion = decoded.version
            overlays = decoded.overlays
            rules = try apply(overlays, to: rules)
        } else {
            overlayVersion = nil
            overlays = []
        }
        if let promotionData {
            let result = try RuleDispositionPromotionCompiler().apply(
                promotionData: promotionData,
                rules: rules
            )
            guard sourceVersions.contains(result.baseCatalogVersion),
                  catalogVersion.rawValue
                    == "builtin-runtime-tool-residue-v2"
            else {
                throw RuleCompilerError.invalidValue("promotionCatalog")
            }
            rules = result.rules
            effectiveSourceVersions.append(result.sourceVersion)
            effectiveSourceVersions.sort {
                $0.rawValue < $1.rawValue
            }
        }
        let finalVersionValue = overlayVersion.map {
            "\(catalogVersion.rawValue).\($0.rawValue)"
        } ?? catalogVersion.rawValue
        guard let finalVersion = DomainToken(rawValue: finalVersionValue) else {
            throw RuleCompilerError.invalidValue("catalogVersion")
        }
        let catalog = try RuleCatalog(
            catalogVersion: finalVersion,
            rules: rules.sorted { $0.id < $1.id }
        )
        let data = try DomainJSON.encode(catalog)
        let digest = SHA256.hash(data: data)
        let sha256 = digest.map { String(format: "%02x", $0) }.joined()
        let manifest = RuleCompileManifest(
            catalogVersion: catalog.catalogVersion.rawValue,
            sourceCatalogVersions:
                effectiveSourceVersions.map(\.rawValue),
            ruleCount: catalog.rules.count,
            ruleIDs: catalog.rules.map(\.id),
            provenanceSourceCount: catalog.rules.reduce(0) {
                $0 + $1.provenance.sources.count
            },
            fixtureCount: Set(
                catalog.rules.flatMap(\.fixtureIDs)
            ).count,
            appliedOverlayCount: overlays.count,
            catalogSHA256: sha256,
            rules: catalog.rules.map(RuleManifestEntry.init)
        )
        return CompiledRuleArtifact(
            catalog: catalog,
            data: data,
            sha256: sha256,
            manifest: manifest
        )
    }
}

private struct SourceOverlay {
    let id: RuleID
    let ruleID: RuleID
    let addExclusions: [RulePathPattern]
    let addRequiredEvidenceKeys: [DomainToken]
    let addRequiredActivityKeys: [DomainToken]
    let riskOverride: RiskLevel?
    let dispositionOverride: ReclaimDisposition?
    let forceProtected: Bool
}

private struct GlobState: Hashable {
    let patternIndex: Int
    let pathIndex: Int
}

private extension RuleSourceCompiler {
    func decodeCatalog(_ data: Data) throws -> [CompiledRule] {
        let root = try strictJSONObject(data)
        try requireExactKeys(
            root,
            allowed: ["schemaVersion", "catalogVersion", "rules"],
            required: ["schemaVersion", "catalogVersion", "rules"],
            context: "catalog"
        )
        guard try integer(root, "schemaVersion") == 1 else {
            throw RuleCompilerError.invalidValue("catalog.schemaVersion")
        }
        _ = try token(root, "catalogVersion")
        let sourceRules = try array(root, "rules")
        guard !sourceRules.isEmpty,
              sourceRules.count <= Self.maximumRuleCount
        else {
            throw RuleCompilerError.invalidValue("catalog.rules")
        }
        var ids = Set<RuleID>()
        var rules: [CompiledRule] = []
        for (index, value) in sourceRules.enumerated() {
            let object = try object(value, context: "rules[\(index)]")
            let rule = try decodeRule(object, index: index)
            guard ids.insert(rule.id).inserted else {
                throw RuleCompilerError.duplicateRule(rule.id.rawValue)
            }
            rules.append(rule)
        }
        return rules
    }

    func catalogVersion(_ data: Data) throws -> DomainToken {
        try token(strictJSONObject(data), "catalogVersion")
    }

    func decodeRule(
        _ object: [String: Any],
        index: Int
    ) throws -> CompiledRule {
        let context = "rules[\(index)]"
        try requireExactKeys(
            object,
            allowed: [
                "id", "match", "producer", "rationaleKey", "category", "disposition",
                "risk", "confidenceRequirement", "veto",
                "requiredEvidenceKeys", "requiredActivityKeys", "recovery",
                "recommendedAction", "provenance", "fixtureIDs",
            ],
            required: [
                "id", "match", "producer", "rationaleKey", "category", "disposition",
                "risk", "confidenceRequirement", "veto",
                "requiredEvidenceKeys", "requiredActivityKeys", "recovery",
                "recommendedAction", "provenance", "fixtureIDs",
            ],
            context: context
        )
        let id = try RuleID(validating: string(object, "id"))
        let matchObject = try self.object(
            required(object, "match"),
            context: "\(context).match"
        )
        try requireExactKeys(
            matchObject,
            allowed: ["pathPattern", "expectedKind"],
            required: ["pathPattern", "expectedKind"],
            context: "\(context).match"
        )
        let match = RuleMatch(
            pathPattern: try RulePathPattern(
                validating: string(matchObject, "pathPattern")
            ),
            expectedKind: try enumeration(
                RuleExpectedKind.self,
                object: matchObject,
                key: "expectedKind"
            )
        )
        let recovery: RecoveryGuidance?
        if object["recovery"] is NSNull {
            recovery = nil
        } else {
            let recoveryObject = try self.object(
                required(object, "recovery"),
                context: "\(context).recovery"
            )
            try requireExactKeys(
                recoveryObject,
                allowed: ["methodKey", "cost"],
                required: ["methodKey", "cost"],
                context: "\(context).recovery"
            )
            recovery = RecoveryGuidance(
                methodKey: try token(recoveryObject, "methodKey"),
                cost: try enumeration(
                    RebuildCost.self,
                    object: recoveryObject,
                    key: "cost"
                )
            )
        }
        let provenance = try decodeProvenance(
            try self.object(
                required(object, "provenance"),
                context: "\(context).provenance"
            ),
            context: "\(context).provenance"
        )
        guard let producer = DomainLabel(
            rawValue: try string(object, "producer")
        ) else {
            throw RuleCompilerError.invalidValue("\(context).producer")
        }
        let category = try enumeration(
            ArtifactCategory.self,
            object: object,
            key: "category"
        )
        let disposition = try enumeration(
            ReclaimDisposition.self,
            object: object,
            key: "disposition"
        )
        let veto = try boolean(object, "veto")
        if category != .protected,
           disposition != .protected,
           !veto,
           patternTouchesPermanentDenylist(match.pathPattern)
        {
            throw RuleCompilerError.invalidValue(
                "\(context).match.pathPattern"
            )
        }
        do {
            return try CompiledRule(
                id: id,
                match: match,
                producer: producer,
                rationaleKey: try token(object, "rationaleKey"),
                category: category,
                disposition: disposition,
                risk: try enumeration(
                    RiskLevel.self,
                    object: object,
                    key: "risk"
                ),
                confidenceRequirement: try enumeration(
                    EvidenceConfidence.self,
                    object: object,
                    key: "confidenceRequirement"
                ),
                veto: veto,
                requiredEvidenceKeys: try tokens(
                    object,
                    "requiredEvidenceKeys"
                ),
                requiredActivityKeys: try tokens(
                    object,
                    "requiredActivityKeys"
                ),
                recovery: recovery,
                recommendedAction: try enumeration(
                    RuleRecommendedAction.self,
                    object: object,
                    key: "recommendedAction"
                ),
                provenance: provenance,
                fixtureIDs: try tokens(object, "fixtureIDs")
            )
        } catch let error as RuleCompilerError {
            throw error
        } catch {
            throw RuleCompilerError.invalidValue(context)
        }
    }

    func decodeProvenance(
        _ object: [String: Any],
        context: String
    ) throws -> RuleProvenance {
        try requireExactKeys(
            object,
            allowed: ["sources", "independentlyVerified", "verifiedAt"],
            required: ["sources", "independentlyVerified", "verifiedAt"],
            context: context
        )
        let sourceValues = try array(object, "sources")
        guard sourceValues.count <= 16 else {
            throw RuleCompilerError.invalidValue("\(context).sources")
        }
        var sources: [RuleProvenanceSource] = []
        for (index, value) in sourceValues.enumerated() {
            let sourceContext = "\(context).sources[\(index)]"
            let source = try self.object(value, context: sourceContext)
            try requireExactKeys(
                source,
                allowed: [
                    "project", "url", "revision", "license", "usage",
                ],
                required: [
                    "project", "url", "revision", "license", "usage",
                ],
                context: sourceContext
            )
            guard let project = DomainLabel(
                rawValue: try string(source, "project")
            ), let url = URL(string: try string(source, "url"))
            else {
                throw RuleCompilerError.invalidValue(sourceContext)
            }
            sources.append(
                try RuleProvenanceSource(
                    project: project,
                    url: url,
                    revision: try token(source, "revision"),
                    license: try token(source, "license"),
                    usage: try enumeration(
                        RuleSourceUsage.self,
                        object: source,
                        key: "usage"
                    )
                )
            )
        }
        let verifiedAt = try RuleVerificationDate(
            validating: string(object, "verifiedAt")
        )
        guard verifiedAt.rawValue <= maximumVerificationDate else {
            throw RuleCompilerError.invalidValue("\(context).verifiedAt")
        }
        return try RuleProvenance(
            sources: sources,
            independentlyVerified: try boolean(
                object,
                "independentlyVerified"
            ),
            verifiedAt: verifiedAt
        )
    }

    func decodeOverlays(
        _ data: Data
    ) throws -> (version: DomainToken, overlays: [SourceOverlay]) {
        let root = try strictJSONObject(data)
        try requireExactKeys(
            root,
            allowed: ["schemaVersion", "catalogVersion", "overlays"],
            required: ["schemaVersion", "catalogVersion", "overlays"],
            context: "overlayCatalog"
        )
        guard try integer(root, "schemaVersion") == 1 else {
            throw RuleCompilerError.invalidValue(
                "overlayCatalog.schemaVersion"
            )
        }
        let version = try token(root, "catalogVersion")
        let values = try array(root, "overlays")
        guard values.count <= Self.maximumRuleCount else {
            throw RuleCompilerError.invalidValue("overlayCatalog.overlays")
        }
        var ids = Set<RuleID>()
        var overlays: [SourceOverlay] = []
        for (index, value) in values.enumerated() {
            let context = "overlays[\(index)]"
            let object = try self.object(value, context: context)
            try requireExactKeys(
                object,
                allowed: [
                    "id", "ruleID", "addExclusions",
                    "addRequiredEvidenceKeys", "addRequiredActivityKeys",
                    "riskOverride", "dispositionOverride", "forceProtected",
                ],
                required: [
                    "id", "ruleID", "addExclusions",
                    "addRequiredEvidenceKeys", "addRequiredActivityKeys",
                    "riskOverride", "dispositionOverride", "forceProtected",
                ],
                context: context
            )
            let id = try RuleID(validating: string(object, "id"))
            guard ids.insert(id).inserted else {
                throw RuleCompilerError.duplicateOverlay(id.rawValue)
            }
            overlays.append(
                SourceOverlay(
                    id: id,
                    ruleID: try RuleID(
                        validating: string(object, "ruleID")
                    ),
                    addExclusions: try patterns(object, "addExclusions"),
                    addRequiredEvidenceKeys: try tokens(
                        object,
                        "addRequiredEvidenceKeys"
                    ),
                    addRequiredActivityKeys: try tokens(
                        object,
                        "addRequiredActivityKeys"
                    ),
                    riskOverride: try optionalEnumeration(
                        RiskLevel.self,
                        object: object,
                        key: "riskOverride"
                    ),
                    dispositionOverride: try optionalEnumeration(
                        ReclaimDisposition.self,
                        object: object,
                        key: "dispositionOverride"
                    ),
                    forceProtected: try boolean(
                        object,
                        "forceProtected"
                    )
                )
            )
        }
        return (version, overlays.sorted { $0.id < $1.id })
    }

    func apply(
        _ overlays: [SourceOverlay],
        to sourceRules: [CompiledRule]
    ) throws -> [CompiledRule] {
        var rules = Dictionary(
            uniqueKeysWithValues: sourceRules.map { ($0.id, $0) }
        )
        for overlay in overlays {
            guard let rule = rules[overlay.ruleID] else {
                throw RuleCompilerError.overlayTargetMissing(
                    overlay.ruleID.rawValue
                )
            }
            if overlay.dispositionOverride == .readyToReclaim {
                throw RuleCompilerError.overlayNotConservative(
                    overlay.id.rawValue
                )
            }
            if rule.veto || rule.disposition == .protected {
                guard overlay.dispositionOverride == nil
                        || overlay.dispositionOverride == .protected,
                      overlay.riskOverride == nil
                        || overlay.riskOverride == .critical
                else {
                    throw RuleCompilerError.overlayNotConservative(
                        overlay.id.rawValue
                    )
                }
            }
            let risk = overlay.riskOverride ?? rule.risk
            guard riskRank(risk) >= riskRank(rule.risk) else {
                throw RuleCompilerError.overlayNotConservative(
                    overlay.id.rawValue
                )
            }
            let disposition = overlay.dispositionOverride
                ?? rule.disposition
            guard dispositionRank(disposition)
                    >= dispositionRank(rule.disposition),
                  (disposition == .protected) == overlay.forceProtected
                    || disposition == rule.disposition
            else {
                throw RuleCompilerError.overlayNotConservative(
                    overlay.id.rawValue
                )
            }
            let protected = overlay.forceProtected
                || rule.veto
                || disposition == .protected
            do {
                rules[rule.id] = try CompiledRule(
                    id: rule.id,
                    match: rule.match,
                    excludedPatterns: union(
                        rule.excludedPatterns,
                        overlay.addExclusions
                    ),
                    producer: rule.producer,
                    rationaleKey: rule.rationaleKey,
                    category: protected ? .protected : rule.category,
                    disposition: protected ? .protected : disposition,
                    risk: protected ? .critical : risk,
                    confidenceRequirement: rule.confidenceRequirement,
                    veto: protected,
                    requiredEvidenceKeys: tokenUnion(
                        rule.requiredEvidenceKeys,
                        overlay.addRequiredEvidenceKeys
                    ),
                    requiredActivityKeys: tokenUnion(
                        rule.requiredActivityKeys,
                        overlay.addRequiredActivityKeys
                    ),
                    recovery: rule.recovery,
                    recommendedAction: protected
                        ? .none
                        : disposition == .unknown
                            ? .none
                        : rule.recommendedAction,
                    provenance: rule.provenance,
                    fixtureIDs: rule.fixtureIDs,
                    appliedOverlayIDs: union(
                        rule.appliedOverlayIDs,
                        [overlay.id]
                    )
                )
            } catch {
                throw RuleCompilerError.overlayNotConservative(
                    overlay.id.rawValue
                )
            }
        }
        return Array(rules.values)
    }

    func union<T: Hashable & Comparable>(
        _ lhs: [T],
        _ rhs: [T]
    ) -> [T] {
        Array(Set(lhs).union(rhs)).sorted()
    }

    func patternTouchesPermanentDenylist(
        _ pattern: RulePathPattern
    ) -> Bool {
        let concrete = pattern.rawValue
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { component in
                component == "*" || component == "**"
                    ? "_stornaut_wildcard_"
                    : String(component)
            }
            .joined(separator: "/")
        let home = URL(
            filePath: "/Users/stornaut-rule-compiler",
            directoryHint: .isDirectory
        )
        let candidate = home.appending(path: concrete)
        if case .denied = SensitivePathDenylist(
            homeDirectoryURL: home
        ).evaluate(candidate) {
            return true
        }
        return permanentSensitiveExamples.contains {
            glob(pattern.rawValue, matches: $0)
        }
    }

    var permanentSensitiveExamples: [String] {
        [
            ".ssh",
            ".ssh/id_ed25519",
            ".gnupg",
            ".aws/credentials",
            ".kube/config",
            ".azure",
            ".config/gcloud",
            ".config/gh",
            ".config/op",
            ".docker/config.json",
            "Library/Keychains",
            "Library/Mail",
            "Library/Messages",
            "Library/Photos/Libraries.photoslibrary",
            "Library/Safari",
            "Library/Application Support/1Password",
            "Library/Application Support/Bitwarden",
            "Library/Application Support/LastPass",
            "Library/Application Support/Google/Chrome",
            "Library/Application Support/Microsoft Edge",
            "Library/Application Support/BraveSoftware/Brave-Browser",
            "Library/Application Support/Arc/User Data",
            "Library/Application Support/Firefox/Profiles",
            "Pictures/Photos Library.photoslibrary",
            "Projects/app/.env",
            "Projects/app/.env.production",
            "Projects/app/private.key",
            "Projects/app/certificate.pem",
            "Projects/app/identity.p12",
            "Projects/app/credentials.json",
        ]
    }

    func glob(_ pattern: String, matches path: String) -> Bool {
        let patternComponents = normalizedComponents(pattern)
        let pathComponents = normalizedComponents(path)
        var memo: [GlobState: Bool] = [:]
        func match(_ patternIndex: Int, _ pathIndex: Int) -> Bool {
            let state = GlobState(
                patternIndex: patternIndex,
                pathIndex: pathIndex
            )
            if let result = memo[state] {
                return result
            }
            let result: Bool
            if patternIndex == patternComponents.count {
                result = pathIndex == pathComponents.count
            } else if patternComponents[patternIndex] == "**" {
                result = match(patternIndex + 1, pathIndex)
                    || (
                        pathIndex < pathComponents.count
                            && match(patternIndex, pathIndex + 1)
                    )
            } else if pathIndex < pathComponents.count,
                      patternComponents[patternIndex] == "*"
                        || patternComponents[patternIndex]
                            == pathComponents[pathIndex]
            {
                result = match(patternIndex + 1, pathIndex + 1)
            } else {
                result = false
            }
            memo[state] = result
            return result
        }
        return match(0, 0)
    }

    func normalizedComponents(_ path: String) -> [String] {
        path.split(separator: "/", omittingEmptySubsequences: false).map {
            String($0).folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
        }
    }

    func tokenUnion(
        _ lhs: [DomainToken],
        _ rhs: [DomainToken]
    ) -> [DomainToken] {
        Array(Set(lhs).union(rhs)).sorted {
            $0.rawValue < $1.rawValue
        }
    }

    func riskRank(_ value: RiskLevel) -> Int {
        switch value {
        case .low: 0
        case .medium: 1
        case .high: 2
        case .critical: 3
        }
    }

    func dispositionRank(_ value: ReclaimDisposition) -> Int {
        switch value {
        case .readyToReclaim: 0
        case .reviewRecommended: 1
        case .unknown: 2
        case .protected: 3
        }
    }
}

private extension RuleSourceCompiler {
    static func currentUTCDateString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

private extension RuleSourceCompiler {
    func strictJSONObject(_ data: Data) throws -> [String: Any] {
        guard data.count <= Self.maximumInputBytes else {
            throw RuleCompilerError.inputTooLarge(
                limit: Self.maximumInputBytes
            )
        }
        var parser = StrictJSONAuditor(data: data)
        try parser.validate()
        let value: Any
        do {
            value = try JSONSerialization.jsonObject(
                with: data,
                options: []
            )
        } catch {
            throw RuleCompilerError.invalidJSON
        }
        return try object(value, context: "root")
    }

    func requireExactKeys(
        _ object: [String: Any],
        allowed: Set<String>,
        required: Set<String>,
        context: String
    ) throws {
        if let unknown = Set(object.keys).subtracting(allowed).sorted().first {
            throw RuleCompilerError.unknownField(
                "\(context).\(unknown)"
            )
        }
        if let missing = required.subtracting(object.keys).sorted().first {
            throw RuleCompilerError.missingField(
                "\(context).\(missing)"
            )
        }
    }

    func required(
        _ object: [String: Any],
        _ key: String
    ) throws -> Any {
        guard let value = object[key] else {
            throw RuleCompilerError.missingField(key)
        }
        return value
    }

    func object(
        _ value: Any,
        context: String
    ) throws -> [String: Any] {
        guard let object = value as? [String: Any] else {
            throw RuleCompilerError.invalidValue(context)
        }
        return object
    }

    func array(
        _ object: [String: Any],
        _ key: String
    ) throws -> [Any] {
        guard let value = object[key] as? [Any] else {
            throw RuleCompilerError.invalidValue(key)
        }
        return value
    }

    func string(
        _ object: [String: Any],
        _ key: String
    ) throws -> String {
        guard let value = object[key] as? String,
              !value.isEmpty
        else {
            throw RuleCompilerError.invalidValue(key)
        }
        return value
    }

    func integer(
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

    func boolean(
        _ object: [String: Any],
        _ key: String
    ) throws -> Bool {
        guard let number = object[key] as? NSNumber,
              CFGetTypeID(number) == CFBooleanGetTypeID()
        else {
            throw RuleCompilerError.invalidValue(key)
        }
        return number.boolValue
    }

    func token(
        _ object: [String: Any],
        _ key: String
    ) throws -> DomainToken {
        guard let value = DomainToken(rawValue: try string(object, key)) else {
            throw RuleCompilerError.invalidValue(key)
        }
        return value
    }

    func tokens(
        _ object: [String: Any],
        _ key: String
    ) throws -> [DomainToken] {
        let values = try array(object, key)
        guard values.count <= 64 else {
            throw RuleCompilerError.invalidValue(key)
        }
        return try values.map {
            guard let value = $0 as? String,
                  let token = DomainToken(rawValue: value)
            else {
                throw RuleCompilerError.invalidValue(key)
            }
            return token
        }
    }

    func patterns(
        _ object: [String: Any],
        _ key: String
    ) throws -> [RulePathPattern] {
        let values = try array(object, key)
        guard values.count <= 64 else {
            throw RuleCompilerError.invalidValue(key)
        }
        return try values.map {
            guard let value = $0 as? String,
                  let pattern = RulePathPattern(rawValue: value)
            else {
                throw RuleCompilerError.invalidValue(key)
            }
            return pattern
        }
    }

    func enumeration<T: RawRepresentable>(
        _ type: T.Type,
        object: [String: Any],
        key: String
    ) throws -> T where T.RawValue == String {
        guard let value = T(rawValue: try string(object, key)) else {
            throw RuleCompilerError.invalidValue(key)
        }
        return value
    }

    func optionalEnumeration<T: RawRepresentable>(
        _ type: T.Type,
        object: [String: Any],
        key: String
    ) throws -> T? where T.RawValue == String {
        guard let value = object[key] else {
            throw RuleCompilerError.missingField(key)
        }
        if value is NSNull {
            return nil
        }
        guard let string = value as? String,
              let result = T(rawValue: string)
        else {
            throw RuleCompilerError.invalidValue(key)
        }
        return result
    }
}
