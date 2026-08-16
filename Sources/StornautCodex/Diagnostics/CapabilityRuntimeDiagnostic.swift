import Foundation

public enum CapabilityRuntimeCapability:
    String,
    Codable,
    Sendable,
    CaseIterable
{
    case directRead
    case shell
    case unifiedExec
    case liveSearch
    case publicCommandNetwork
    case browserOrDirectFetch
    case imageInspection
    case skills
    case subagents
    case probeBroker

    public static let required: Set<Self> = [
        .directRead,
        .shell,
        .unifiedExec,
        .liveSearch,
        .publicCommandNetwork,
        .browserOrDirectFetch,
        .imageInspection,
        .skills,
        .subagents,
    ]
}

public enum CapabilityRuntimeIntegrityProperty:
    String,
    Codable,
    Sendable,
    CaseIterable
{
    case signedAppIdentity
    case helperCallerAuthentication
    case perInvestigationAuditSession
    case userDataWriteDenial
    case nestedDescendantWriteDenial
    case loopbackPrivateLinkLocalDenial
    case unixSocketDenial
    case noExecutorReachability
    case timeoutCancellationCleanup
    case helperCrashRecovery
    case runtimeStateCleanup
    case authStateNonPersistence

    public static let required = Set(allCases)
}

public enum CapabilityRuntimeIntegrityVerdict:
    String,
    Codable,
    Sendable
{
    case contained
    case failed
    case unverified
}

public enum CapabilityRuntimeSignatureKind:
    String,
    Codable,
    Sendable
{
    case adHoc
    case developerID
}

public enum CapabilityRuntimeDiagnosticOutcome:
    Codable,
    Sendable,
    Equatable
{
    case signedRuntimeReady
    case signedRuntimeBlocked(reasonKeys: [String])
    case externalStateBlocked(reasonKeys: [String])

    public init(from decoder: Decoder) throws {
        let container = try strictCapabilityRuntimeContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue)),
            optionalKeys: Set(CodingKeys.allCases.map(\.rawValue))
        )
        guard container.allKeys.count == 1,
              let key = container.allKeys.first,
              let codingKey = CodingKeys(rawValue: key.stringValue)
        else {
            throw CapabilityRuntimeDiagnosticError.invalidReport
        }
        let payload = try container.nestedContainer(
            keyedBy: CapabilityRuntimeCodingKey.self,
            forKey: key
        )
        switch codingKey {
        case .signedRuntimeReady:
            guard payload.allKeys.isEmpty else {
                throw CapabilityRuntimeDiagnosticError.invalidReport
            }
            self = .signedRuntimeReady
        case .signedRuntimeBlocked, .externalStateBlocked:
            let reasonKey = CapabilityRuntimeCodingKey(
                PayloadCodingKeys.reasonKeys.rawValue
            )
            guard
                Set(payload.allKeys.map(\.stringValue))
                    == [PayloadCodingKeys.reasonKeys.rawValue]
            else {
                throw CapabilityRuntimeDiagnosticError.invalidReport
            }
            let reasonKeys = try payload.decode(
                [String].self,
                forKey: reasonKey
            )
            self = codingKey == .signedRuntimeBlocked
                ? .signedRuntimeBlocked(reasonKeys: reasonKeys)
                : .externalStateBlocked(reasonKeys: reasonKeys)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(
            keyedBy: CapabilityRuntimeCodingKey.self
        )
        let codingKey: CodingKeys
        let reasonKeys: [String]?
        switch self {
        case .signedRuntimeReady:
            codingKey = .signedRuntimeReady
            reasonKeys = nil
        case let .signedRuntimeBlocked(values):
            codingKey = .signedRuntimeBlocked
            reasonKeys = values
        case let .externalStateBlocked(values):
            codingKey = .externalStateBlocked
            reasonKeys = values
        }
        let key = CapabilityRuntimeCodingKey(codingKey.rawValue)
        var payload = container.nestedContainer(
            keyedBy: CapabilityRuntimeCodingKey.self,
            forKey: key
        )
        if let reasonKeys {
            try payload.encode(
                reasonKeys,
                forKey: CapabilityRuntimeCodingKey(
                    PayloadCodingKeys.reasonKeys.rawValue
                )
            )
        }
    }

    private enum CodingKeys: String, CaseIterable {
        case signedRuntimeReady
        case signedRuntimeBlocked
        case externalStateBlocked
    }

    private enum PayloadCodingKeys: String {
        case reasonKeys
    }
}

public enum CapabilityRuntimeDiagnosticError:
    Error,
    Sendable,
    Equatable
{
    case invalidMetadata
    case invalidCapabilityEvidence
    case invalidIntegrityEvidence
    case invalidReport
}

public struct CapabilityRuntimeCapabilityEvidence:
    Codable,
    Sendable,
    Equatable
{
    public let capability: CapabilityRuntimeCapability
    public let advertised: Bool
    public let configured: Bool
    public let invoked: Bool
    public let observed: Bool
    public let reasonKey: String?

    public init(
        capability: CapabilityRuntimeCapability,
        advertised: Bool,
        configured: Bool,
        invoked: Bool,
        observed: Bool,
        reasonKey: String?
    ) throws {
        guard
            !configured
                || advertised
                || !capability.requiresAdvertisedSurface,
            !invoked || configured,
            !observed || invoked,
            reasonKey.map(stableRuntimeReasonKey) ?? true,
            observed == (reasonKey == nil)
        else {
            throw CapabilityRuntimeDiagnosticError
                .invalidCapabilityEvidence
        }
        self.capability = capability
        self.advertised = advertised
        self.configured = configured
        self.invoked = invoked
        self.observed = observed
        self.reasonKey = reasonKey
    }

    public init(from decoder: Decoder) throws {
        let container = try strictCapabilityRuntimeContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue)),
            optionalKeys: [CodingKeys.reasonKey.rawValue]
        )
        try self.init(
            capability: container.decode(
                CapabilityRuntimeCapability.self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.capability.rawValue
                )
            ),
            advertised: container.decode(
                Bool.self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.advertised.rawValue
                )
            ),
            configured: container.decode(
                Bool.self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.configured.rawValue
                )
            ),
            invoked: container.decode(
                Bool.self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.invoked.rawValue
                )
            ),
            observed: container.decode(
                Bool.self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.observed.rawValue
                )
            ),
            reasonKey: container.decodeIfPresent(
                String.self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.reasonKey.rawValue
                )
            )
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case capability
        case advertised
        case configured
        case invoked
        case observed
        case reasonKey
    }
}

private extension CapabilityRuntimeCapability {
    var requiresAdvertisedSurface: Bool {
        switch self {
        case .directRead, .skills, .probeBroker:
            false
        case .shell, .unifiedExec, .liveSearch,
             .publicCommandNetwork, .browserOrDirectFetch,
             .imageInspection, .subagents:
            true
        }
    }
}

public struct CapabilityRuntimeIntegrityEvidence:
    Codable,
    Sendable,
    Equatable
{
    public let property: CapabilityRuntimeIntegrityProperty
    public let verdict: CapabilityRuntimeIntegrityVerdict
    public let reasonKey: String?

    public init(
        property: CapabilityRuntimeIntegrityProperty,
        verdict: CapabilityRuntimeIntegrityVerdict,
        reasonKey: String?
    ) throws {
        guard
            reasonKey.map(stableRuntimeReasonKey) ?? true,
            (verdict == .contained) == (reasonKey == nil)
        else {
            throw CapabilityRuntimeDiagnosticError
                .invalidIntegrityEvidence
        }
        self.property = property
        self.verdict = verdict
        self.reasonKey = reasonKey
    }

    public init(from decoder: Decoder) throws {
        let container = try strictCapabilityRuntimeContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue)),
            optionalKeys: [CodingKeys.reasonKey.rawValue]
        )
        try self.init(
            property: container.decode(
                CapabilityRuntimeIntegrityProperty.self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.property.rawValue
                )
            ),
            verdict: container.decode(
                CapabilityRuntimeIntegrityVerdict.self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.verdict.rawValue
                )
            ),
            reasonKey: container.decodeIfPresent(
                String.self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.reasonKey.rawValue
                )
            )
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case property
        case verdict
        case reasonKey
    }
}

public struct CapabilityRuntimeDiagnosticMetadata:
    Codable,
    Sendable,
    Equatable
{
    public let appBundleIdentifier: String
    public let appExecutableSHA256: String
    public let appDesignatedRequirementSHA256: String
    public let signatureKind: CapabilityRuntimeSignatureKind
    public let codexVersion: String
    public let codexExecutableSHA256: String
    public let model: CodexRuntimeModel
    public let provider: CodexRuntimeProvider
    public let publicEndpointHosts: [String]
    public let syntheticFixtureSHA256s: [String]
    public let sanitizedEventCategories: [String]
    public let durationMilliseconds: Int

    public init(
        appBundleIdentifier: String,
        appExecutableSHA256: String,
        appDesignatedRequirementSHA256: String,
        signatureKind: CapabilityRuntimeSignatureKind,
        codexVersion: String,
        codexExecutableSHA256: String,
        model: CodexRuntimeModel,
        provider: CodexRuntimeProvider,
        publicEndpointHosts: [String],
        syntheticFixtureSHA256s: [String],
        sanitizedEventCategories: [String],
        durationMilliseconds: Int
    ) throws {
        guard
            boundedRuntimeIdentifier(appBundleIdentifier),
            sha256Digest(appExecutableSHA256),
            sha256Digest(appDesignatedRequirementSHA256),
            boundedRuntimeText(codexVersion, maximumBytes: 128),
            sha256Digest(codexExecutableSHA256),
            publicEndpointHosts.count <= 16,
            publicEndpointHosts.allSatisfy(publicDiagnosticHost),
            Set(publicEndpointHosts).count == publicEndpointHosts.count,
            syntheticFixtureSHA256s.count <= 64,
            syntheticFixtureSHA256s.allSatisfy(sha256Digest),
            Set(syntheticFixtureSHA256s).count
                == syntheticFixtureSHA256s.count,
            sanitizedEventCategories.count <= 128,
            sanitizedEventCategories.allSatisfy(boundedRuntimeIdentifier),
            Set(sanitizedEventCategories).count
                == sanitizedEventCategories.count,
            (0...3_600_000).contains(durationMilliseconds)
        else {
            throw CapabilityRuntimeDiagnosticError.invalidMetadata
        }
        self.appBundleIdentifier = appBundleIdentifier
        self.appExecutableSHA256 = appExecutableSHA256
        self.appDesignatedRequirementSHA256 =
            appDesignatedRequirementSHA256
        self.signatureKind = signatureKind
        self.codexVersion = codexVersion
        self.codexExecutableSHA256 = codexExecutableSHA256
        self.model = model
        self.provider = provider
        self.publicEndpointHosts = publicEndpointHosts.sorted()
        self.syntheticFixtureSHA256s = syntheticFixtureSHA256s.sorted()
        self.sanitizedEventCategories = sanitizedEventCategories.sorted()
        self.durationMilliseconds = durationMilliseconds
    }

    public init(from decoder: Decoder) throws {
        let container = try strictCapabilityRuntimeContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue))
        )
        try self.init(
            appBundleIdentifier: container.decode(
                String.self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.appBundleIdentifier.rawValue
                )
            ),
            appExecutableSHA256: container.decode(
                String.self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.appExecutableSHA256.rawValue
                )
            ),
            appDesignatedRequirementSHA256: container.decode(
                String.self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.appDesignatedRequirementSHA256.rawValue
                )
            ),
            signatureKind: container.decode(
                CapabilityRuntimeSignatureKind.self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.signatureKind.rawValue
                )
            ),
            codexVersion: container.decode(
                String.self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.codexVersion.rawValue
                )
            ),
            codexExecutableSHA256: container.decode(
                String.self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.codexExecutableSHA256.rawValue
                )
            ),
            model: container.decode(
                CodexRuntimeModel.self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.model.rawValue
                )
            ),
            provider: container.decode(
                CodexRuntimeProvider.self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.provider.rawValue
                )
            ),
            publicEndpointHosts: container.decode(
                [String].self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.publicEndpointHosts.rawValue
                )
            ),
            syntheticFixtureSHA256s: container.decode(
                [String].self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.syntheticFixtureSHA256s.rawValue
                )
            ),
            sanitizedEventCategories: container.decode(
                [String].self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.sanitizedEventCategories.rawValue
                )
            ),
            durationMilliseconds: container.decode(
                Int.self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.durationMilliseconds.rawValue
                )
            )
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case appBundleIdentifier
        case appExecutableSHA256
        case appDesignatedRequirementSHA256
        case signatureKind
        case codexVersion
        case codexExecutableSHA256
        case model
        case provider
        case publicEndpointHosts
        case syntheticFixtureSHA256s
        case sanitizedEventCategories
        case durationMilliseconds
    }
}

public struct CapabilityRuntimeDiagnosticReport:
    Codable,
    Sendable,
    Equatable
{
    public static let schemaVersion = 2

    public let schemaVersion: Int
    public let metadata: CapabilityRuntimeDiagnosticMetadata
    public let capabilities: [CapabilityRuntimeCapabilityEvidence]
    public let integrity: [CapabilityRuntimeIntegrityEvidence]
    public let externalStateReasonKeys: [String]
    public let outcome: CapabilityRuntimeDiagnosticOutcome

    public init(
        metadata: CapabilityRuntimeDiagnosticMetadata,
        capabilities: [CapabilityRuntimeCapabilityEvidence],
        integrity: [CapabilityRuntimeIntegrityEvidence],
        externalStateReasonKeys: [String]
    ) throws {
        let capabilityKeys = capabilities.map(\.capability)
        let integrityKeys = integrity.map(\.property)
        guard
            capabilities.count <= CapabilityRuntimeCapability
                .allCases.count,
            Set(capabilityKeys).count == capabilityKeys.count,
            Set(capabilityKeys).isSuperset(
                of: CapabilityRuntimeCapability.required
            ),
            integrity.count
                == CapabilityRuntimeIntegrityProperty.required.count,
            Set(integrityKeys)
                == CapabilityRuntimeIntegrityProperty.required,
            externalStateReasonKeys.count <= 16,
            externalStateReasonKeys.allSatisfy(stableRuntimeReasonKey),
            Set(externalStateReasonKeys).count
                == externalStateReasonKeys.count
        else {
            throw CapabilityRuntimeDiagnosticError.invalidReport
        }

        let integrityFailures = integrity.compactMap {
            $0.verdict == .failed ? $0.reasonKey : nil
        }
        let missingCapabilities = capabilities.compactMap {
            !$0.observed ? $0.reasonKey : nil
        }
        let unverifiedIntegrity = integrity.compactMap {
            $0.verdict == .unverified ? $0.reasonKey : nil
        }
        let outcome: CapabilityRuntimeDiagnosticOutcome
        if !integrityFailures.isEmpty {
            outcome = .signedRuntimeBlocked(
                reasonKeys: sortedUnique(integrityFailures)
            )
        } else {
            let blocked = sortedUnique(
                missingCapabilities + unverifiedIntegrity
            )
            if !blocked.isEmpty {
                outcome = .signedRuntimeBlocked(
                    reasonKeys: blocked
                )
            } else if !externalStateReasonKeys.isEmpty {
                outcome = .externalStateBlocked(
                    reasonKeys: sortedUnique(
                        externalStateReasonKeys
                    )
                )
            } else {
                outcome = .signedRuntimeReady
            }
        }

        self.schemaVersion = Self.schemaVersion
        self.metadata = metadata
        self.capabilities = capabilities.sorted {
            $0.capability.rawValue < $1.capability.rawValue
        }
        self.integrity = integrity.sorted {
            $0.property.rawValue < $1.property.rawValue
        }
        self.externalStateReasonKeys =
            externalStateReasonKeys.sorted()
        self.outcome = outcome
    }

    public init(from decoder: Decoder) throws {
        let container = try strictCapabilityRuntimeContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let schemaVersion = try container.decode(
            Int.self,
            forKey: CapabilityRuntimeCodingKey(
                CodingKeys.schemaVersion.rawValue
            )
        )
        guard schemaVersion == Self.schemaVersion else {
            throw CapabilityRuntimeDiagnosticError.invalidReport
        }
        let decodedOutcome = try container.decode(
            CapabilityRuntimeDiagnosticOutcome.self,
            forKey: CapabilityRuntimeCodingKey(
                CodingKeys.outcome.rawValue
            )
        )
        try self.init(
            metadata: container.decode(
                CapabilityRuntimeDiagnosticMetadata.self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.metadata.rawValue
                )
            ),
            capabilities: container.decode(
                [CapabilityRuntimeCapabilityEvidence].self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.capabilities.rawValue
                )
            ),
            integrity: container.decode(
                [CapabilityRuntimeIntegrityEvidence].self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.integrity.rawValue
                )
            ),
            externalStateReasonKeys: container.decode(
                [String].self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.externalStateReasonKeys.rawValue
                )
            )
        )
        guard outcome == decodedOutcome else {
            throw CapabilityRuntimeDiagnosticError.invalidReport
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case metadata
        case capabilities
        case integrity
        case externalStateReasonKeys
        case outcome
    }
}

public struct CapabilityRuntimeWorkerEvidence:
    Codable,
    Sendable,
    Equatable
{
    public static let allowedIntegrityProperties:
        Set<CapabilityRuntimeIntegrityProperty> = [
            .userDataWriteDenial,
            .nestedDescendantWriteDenial,
            .loopbackPrivateLinkLocalDenial,
            .unixSocketDenial,
            .runtimeStateCleanup,
            .authStateNonPersistence,
        ]

    public let investigationID: UUID
    public let evidenceBindingSHA256: String
    public let codexVersion: String
    public let codexExecutableSHA256: String
    public let provider: CodexRuntimeProvider
    public let publicEndpointHosts: [String]
    public let syntheticFixtureSHA256s: [String]
    public let sanitizedEventCategories: [String]
    public let durationMilliseconds: Int
    public let completedAt: Date
    public let capabilities: [CapabilityRuntimeCapabilityEvidence]
    public let integrity: [CapabilityRuntimeIntegrityEvidence]

    public init(
        investigationID: UUID,
        evidenceBindingSHA256: String,
        codexVersion: String,
        codexExecutableSHA256: String,
        provider: CodexRuntimeProvider,
        publicEndpointHosts: [String],
        syntheticFixtureSHA256s: [String],
        sanitizedEventCategories: [String],
        durationMilliseconds: Int,
        completedAt: Date,
        capabilities: [CapabilityRuntimeCapabilityEvidence],
        integrity: [CapabilityRuntimeIntegrityEvidence]
    ) throws {
        let capabilityKeys = Set(capabilities.map(\.capability))
        let integrityKeys = Set(integrity.map(\.property))
        guard
            sha256Digest(evidenceBindingSHA256),
            boundedRuntimeText(codexVersion, maximumBytes: 128),
            sha256Digest(codexExecutableSHA256),
            publicEndpointHosts.count <= 16,
            publicEndpointHosts.allSatisfy(publicDiagnosticHost),
            Set(publicEndpointHosts).count == publicEndpointHosts.count,
            syntheticFixtureSHA256s.count <= 64,
            syntheticFixtureSHA256s.allSatisfy(sha256Digest),
            Set(syntheticFixtureSHA256s).count
                == syntheticFixtureSHA256s.count,
            sanitizedEventCategories.count <= 128,
            sanitizedEventCategories.allSatisfy(boundedRuntimeIdentifier),
            Set(sanitizedEventCategories).count
                == sanitizedEventCategories.count,
            (0...3_600_000).contains(durationMilliseconds),
            completedAt.timeIntervalSince1970.isFinite,
            capabilityKeys == CapabilityRuntimeCapability.required,
            capabilities.count == capabilityKeys.count,
            integrityKeys == Self.allowedIntegrityProperties,
            integrity.count == integrityKeys.count
        else {
            throw CapabilityRuntimeDiagnosticError.invalidReport
        }
        self.investigationID = investigationID
        self.evidenceBindingSHA256 = evidenceBindingSHA256
        self.codexVersion = codexVersion
        self.codexExecutableSHA256 = codexExecutableSHA256
        self.provider = provider
        self.publicEndpointHosts = publicEndpointHosts.sorted()
        self.syntheticFixtureSHA256s = syntheticFixtureSHA256s.sorted()
        self.sanitizedEventCategories = sanitizedEventCategories.sorted()
        self.durationMilliseconds = durationMilliseconds
        self.completedAt = completedAt
        self.capabilities = capabilities.sorted {
            $0.capability.rawValue < $1.capability.rawValue
        }
        self.integrity = integrity.sorted {
            $0.property.rawValue < $1.property.rawValue
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try strictCapabilityRuntimeContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue))
        )
        try self.init(
            investigationID: container.decode(
                UUID.self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.investigationID.rawValue
                )
            ),
            evidenceBindingSHA256: container.decode(
                String.self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.evidenceBindingSHA256.rawValue
                )
            ),
            codexVersion: container.decode(
                String.self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.codexVersion.rawValue
                )
            ),
            codexExecutableSHA256: container.decode(
                String.self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.codexExecutableSHA256.rawValue
                )
            ),
            provider: container.decode(
                CodexRuntimeProvider.self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.provider.rawValue
                )
            ),
            publicEndpointHosts: container.decode(
                [String].self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.publicEndpointHosts.rawValue
                )
            ),
            syntheticFixtureSHA256s: container.decode(
                [String].self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.syntheticFixtureSHA256s.rawValue
                )
            ),
            sanitizedEventCategories: container.decode(
                [String].self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.sanitizedEventCategories.rawValue
                )
            ),
            durationMilliseconds: container.decode(
                Int.self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.durationMilliseconds.rawValue
                )
            ),
            completedAt: container.decode(
                Date.self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.completedAt.rawValue
                )
            ),
            capabilities: container.decode(
                [CapabilityRuntimeCapabilityEvidence].self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.capabilities.rawValue
                )
            ),
            integrity: container.decode(
                [CapabilityRuntimeIntegrityEvidence].self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.integrity.rawValue
                )
            )
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case investigationID
        case evidenceBindingSHA256
        case codexVersion
        case codexExecutableSHA256
        case provider
        case publicEndpointHosts
        case syntheticFixtureSHA256s
        case sanitizedEventCategories
        case durationMilliseconds
        case completedAt
        case capabilities
        case integrity
    }
}

public struct CapabilityRuntimeLifecycleEvidence:
    Codable,
    Sendable,
    Equatable
{
    public static let allowedIntegrityProperties:
        Set<CapabilityRuntimeIntegrityProperty> = [
            .signedAppIdentity,
            .helperCallerAuthentication,
            .perInvestigationAuditSession,
            .timeoutCancellationCleanup,
            .helperCrashRecovery,
        ]

    public let integrity: [CapabilityRuntimeIntegrityEvidence]

    public init(
        integrity: [CapabilityRuntimeIntegrityEvidence]
    ) throws {
        let keys = Set(integrity.map(\.property))
        guard
            keys == Self.allowedIntegrityProperties,
            integrity.count == keys.count
        else {
            throw CapabilityRuntimeDiagnosticError.invalidReport
        }
        self.integrity = integrity.sorted {
            $0.property.rawValue < $1.property.rawValue
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try strictCapabilityRuntimeContainer(
            decoder,
            keys: [CodingKeys.integrity.rawValue]
        )
        try self.init(
            integrity: container.decode(
                [CapabilityRuntimeIntegrityEvidence].self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.integrity.rawValue
                )
            )
        )
    }

    private enum CodingKeys: String, CodingKey {
        case integrity
    }
}

public struct CapabilityRuntimeRepositoryEvidence:
    Codable,
    Sendable,
    Equatable
{
    public let integrity: [CapabilityRuntimeIntegrityEvidence]

    public init(
        integrity: [CapabilityRuntimeIntegrityEvidence]
    ) throws {
        guard
            integrity.count == 1,
            integrity.first?.property == .noExecutorReachability
        else {
            throw CapabilityRuntimeDiagnosticError.invalidReport
        }
        self.integrity = integrity
    }

    public init(from decoder: Decoder) throws {
        let container = try strictCapabilityRuntimeContainer(
            decoder,
            keys: [CodingKeys.integrity.rawValue]
        )
        try self.init(
            integrity: container.decode(
                [CapabilityRuntimeIntegrityEvidence].self,
                forKey: CapabilityRuntimeCodingKey(
                    CodingKeys.integrity.rawValue
                )
            )
        )
    }

    private enum CodingKeys: String, CodingKey {
        case integrity
    }
}

public struct CapabilityRuntimeDiagnosticAssembler: Sendable {
    public init() {}

    public func assemble(
        metadata: CapabilityRuntimeDiagnosticMetadata,
        worker: CapabilityRuntimeWorkerEvidence,
        lifecycle: CapabilityRuntimeLifecycleEvidence,
        repository: CapabilityRuntimeRepositoryEvidence,
        externalStateReasonKeys: [String]
    ) throws -> CapabilityRuntimeDiagnosticReport {
        guard
            metadata.codexVersion == worker.codexVersion,
            metadata.codexExecutableSHA256
                == worker.codexExecutableSHA256,
            metadata.provider == worker.provider,
            metadata.publicEndpointHosts
                == worker.publicEndpointHosts,
            metadata.syntheticFixtureSHA256s
                == worker.syntheticFixtureSHA256s,
            metadata.sanitizedEventCategories
                == worker.sanitizedEventCategories,
            metadata.durationMilliseconds
                == worker.durationMilliseconds
        else {
            throw CapabilityRuntimeDiagnosticError.invalidReport
        }
        return try CapabilityRuntimeDiagnosticReport(
            metadata: metadata,
            capabilities: worker.capabilities,
            integrity:
                worker.integrity
                + lifecycle.integrity
                + repository.integrity,
            externalStateReasonKeys: externalStateReasonKeys
        )
    }
}

public struct CapabilityRuntimeDiagnosticVerifier: Sendable {
    public init() {}

    public func assembleSignedRuntimeReport(
        metadata: CapabilityRuntimeDiagnosticMetadata,
        worker: CapabilityRuntimeWorkerEvidence,
        lifecycleIntegrity: [CapabilityRuntimeIntegrityEvidence],
        repository: CapabilityRuntimeRepositoryEvidence
    ) throws -> CapabilityRuntimeDiagnosticReport {
        let validatedMetadata = try revalidate(metadata)
        guard
            validatedMetadata.appBundleIdentifier
                == "com.eriklee.stornaut",
            validatedMetadata.model == .gpt56Luna,
            validatedMetadata.provider
                == .openAI,
            validatedMetadata.signatureKind == .adHoc
        else {
            throw CapabilityRuntimeDiagnosticError.invalidReport
        }
        let validatedWorker = try revalidate(worker)
        let validatedLifecycle = try CapabilityRuntimeLifecycleEvidence(
            integrity: try lifecycleIntegrity.map(revalidate)
        )
        let validatedRepository = try CapabilityRuntimeRepositoryEvidence(
            integrity: try repository.integrity.map(revalidate)
        )
        return try CapabilityRuntimeDiagnosticAssembler().assemble(
            metadata: validatedMetadata,
            worker: validatedWorker,
            lifecycle: validatedLifecycle,
            repository: validatedRepository,
            externalStateReasonKeys: []
        )
    }

    public func verifyReadyReport(
        _ report: CapabilityRuntimeDiagnosticReport
    ) throws -> CapabilityRuntimeDiagnosticReport {
        guard
            report.metadata.appBundleIdentifier
                == "com.eriklee.stornaut",
            report.metadata.model == .gpt56Luna,
            report.metadata.provider == .openAI,
            report.metadata.signatureKind == .adHoc
        else {
            throw CapabilityRuntimeDiagnosticError.invalidReport
        }
        let validated = try CapabilityRuntimeDiagnosticReport(
            metadata: revalidate(report.metadata),
            capabilities: try report.capabilities.map(revalidate),
            integrity: try report.integrity.map(revalidate),
            externalStateReasonKeys: report.externalStateReasonKeys
        )
        guard
            validated == report,
            validated.outcome == .signedRuntimeReady
        else {
            throw CapabilityRuntimeDiagnosticError.invalidReport
        }
        return validated
    }

    private func revalidate(
        _ metadata: CapabilityRuntimeDiagnosticMetadata
    ) throws -> CapabilityRuntimeDiagnosticMetadata {
        try CapabilityRuntimeDiagnosticMetadata(
            appBundleIdentifier: metadata.appBundleIdentifier,
            appExecutableSHA256: metadata.appExecutableSHA256,
            appDesignatedRequirementSHA256:
                metadata.appDesignatedRequirementSHA256,
            signatureKind: metadata.signatureKind,
            codexVersion: metadata.codexVersion,
            codexExecutableSHA256: metadata.codexExecutableSHA256,
            model: metadata.model,
            provider: metadata.provider,
            publicEndpointHosts: metadata.publicEndpointHosts,
            syntheticFixtureSHA256s:
                metadata.syntheticFixtureSHA256s,
            sanitizedEventCategories:
                metadata.sanitizedEventCategories,
            durationMilliseconds: metadata.durationMilliseconds
        )
    }

    private func revalidate(
        _ worker: CapabilityRuntimeWorkerEvidence
    ) throws -> CapabilityRuntimeWorkerEvidence {
        try CapabilityRuntimeWorkerEvidence(
            investigationID: worker.investigationID,
            evidenceBindingSHA256: worker.evidenceBindingSHA256,
            codexVersion: worker.codexVersion,
            codexExecutableSHA256: worker.codexExecutableSHA256,
            provider: worker.provider,
            publicEndpointHosts: worker.publicEndpointHosts,
            syntheticFixtureSHA256s:
                worker.syntheticFixtureSHA256s,
            sanitizedEventCategories:
                worker.sanitizedEventCategories,
            durationMilliseconds: worker.durationMilliseconds,
            completedAt: worker.completedAt,
            capabilities: try worker.capabilities.map(revalidate),
            integrity: try worker.integrity.map(revalidate)
        )
    }

    private func revalidate(
        _ evidence: CapabilityRuntimeCapabilityEvidence
    ) throws -> CapabilityRuntimeCapabilityEvidence {
        try CapabilityRuntimeCapabilityEvidence(
            capability: evidence.capability,
            advertised: evidence.advertised,
            configured: evidence.configured,
            invoked: evidence.invoked,
            observed: evidence.observed,
            reasonKey: evidence.reasonKey
        )
    }

    private func revalidate(
        _ evidence: CapabilityRuntimeIntegrityEvidence
    ) throws -> CapabilityRuntimeIntegrityEvidence {
        try CapabilityRuntimeIntegrityEvidence(
            property: evidence.property,
            verdict: evidence.verdict,
            reasonKey: evidence.reasonKey
        )
    }
}

private func sortedUnique(_ values: [String]) -> [String] {
    Array(Set(values)).sorted()
}

private func stableRuntimeReasonKey(_ value: String) -> Bool {
    boundedRuntimeIdentifier(value)
}

private func boundedRuntimeIdentifier(_ value: String) -> Bool {
    !value.isEmpty
        && value.utf8.count <= 256
        && value.unicodeScalars.allSatisfy {
            (0x30...0x39).contains($0.value)
                || (0x41...0x5A).contains($0.value)
                || (0x61...0x7A).contains($0.value)
                || $0.value == 0x2D
                || $0.value == 0x2E
                || $0.value == 0x3A
                || $0.value == 0x5F
        }
}

private func boundedRuntimeText(
    _ value: String,
    maximumBytes: Int
) -> Bool {
    !value.isEmpty
        && value.utf8.count <= maximumBytes
        && value.unicodeScalars.allSatisfy {
            !CharacterSet.controlCharacters.contains($0)
        }
}

private func sha256Digest(_ value: String) -> Bool {
    value.utf8.count == 64
        && value.unicodeScalars.allSatisfy {
            (0x30...0x39).contains($0.value)
                || (0x61...0x66).contains($0.value)
        }
}

private func publicDiagnosticHost(_ value: String) -> Bool {
    guard
        value.utf8.count <= 253,
        !value.hasSuffix("."),
        !value.localizedCaseInsensitiveContains("localhost")
    else {
        return false
    }
    let labels = value.lowercased().split(
        separator: ".",
        omittingEmptySubsequences: false
    )
    return labels.count >= 2
        && labels.allSatisfy {
            !$0.isEmpty
                && $0.utf8.count <= 63
                && $0.first != "-"
                && $0.last != "-"
                && $0.unicodeScalars.allSatisfy {
                    (0x30...0x39).contains($0.value)
                        || (0x61...0x7A).contains($0.value)
                        || $0.value == 0x2D
                }
        }
}

private struct CapabilityRuntimeCodingKey: CodingKey, Hashable {
    let stringValue: String
    let intValue: Int? = nil

    init(_ value: String) {
        stringValue = value
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}

private func strictCapabilityRuntimeContainer(
    _ decoder: Decoder,
    keys: Set<String>,
    optionalKeys: Set<String> = []
) throws -> KeyedDecodingContainer<CapabilityRuntimeCodingKey> {
    let container = try decoder.container(
        keyedBy: CapabilityRuntimeCodingKey.self
    )
    let actualKeys = Set(container.allKeys.map(\.stringValue))
    guard
        optionalKeys.isSubset(of: keys),
        actualKeys.isSubset(of: keys),
        keys.subtracting(optionalKeys).isSubset(of: actualKeys)
    else {
        throw CapabilityRuntimeDiagnosticError.invalidReport
    }
    return container
}
