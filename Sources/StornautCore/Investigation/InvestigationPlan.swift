import CryptoKit
import Foundation

public enum InvestigationDomainError: Error, Sendable, Equatable {
    case invalidFingerprint
    case invalidSourceBinding
    case invalidCanonicalSet
    case invalidFactor
    case invalidPriority
    case invalidBudget
    case invalidPlan
    case canonicalInputTooLarge
}

public struct InvestigationFingerprint:
    Codable,
    Sendable,
    Hashable
{
    public let bytes: Data

    public init(validating bytes: Data) throws {
        guard bytes.count == 32 else {
            throw InvestigationDomainError.invalidFingerprint
        }
        self.bytes = bytes
    }

    public init(validatingHex hex: String) throws {
        guard hex.utf8.count == 64,
              hex.utf8.allSatisfy({
                (48...57).contains($0) || (97...102).contains($0)
              })
        else {
            throw InvestigationDomainError.invalidFingerprint
        }
        var bytes = Data()
        bytes.reserveCapacity(32)
        var index = hex.startIndex
        for _ in 0..<32 {
            let end = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<end], radix: 16) else {
                throw InvestigationDomainError.invalidFingerprint
            }
            bytes.append(byte)
            index = end
        }
        try self.init(validating: bytes)
    }

    public var hex: String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    public init(from decoder: Decoder) throws {
        try self.init(
            validatingHex: decoder.singleValueContainer().decode(String.self)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }
}

extension InvestigationFingerprint: StrictIntegerDomainJSON {}

public enum InvestigationSpaceLedgerMeasureKey:
    String,
    Codable,
    Sendable,
    Hashable,
    CaseIterable
{
    case unknownResidual = "unknown-residual-v1"
}

public enum InvestigationSourceBinding: Sendable, Hashable {
    case snapshot(SnapshotID)
    case classification(
        classificationID: ClassificationID,
        snapshotID: SnapshotID
    )
    case spaceLedger(InvestigationSpaceLedgerMeasureKey)
}

extension InvestigationSourceBinding: Codable {
    public init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard CodingKeys.allCases.allSatisfy(container.contains) else {
            throw InvestigationDomainError.invalidSourceBinding
        }
        let kind = try container.decode(String.self, forKey: .kind)
        let snapshotID = try container.decodeIfPresent(
            SnapshotID.self,
            forKey: .snapshotID
        )
        let classificationID = try container.decodeIfPresent(
            ClassificationID.self,
            forKey: .classificationID
        )
        let measureKey = try container.decodeIfPresent(
            InvestigationSpaceLedgerMeasureKey.self,
            forKey: .measureKey
        )
        switch (kind, snapshotID, classificationID, measureKey) {
        case ("snapshot-v1", let snapshotID?, nil, nil):
            self = .snapshot(snapshotID)
        case (
            "classification-snapshot-v1",
            let snapshotID?,
            let classificationID?,
            nil
        ):
            self = .classification(
                classificationID: classificationID,
                snapshotID: snapshotID
            )
        case ("space-ledger-measure-v1", nil, nil, let measureKey?):
            self = .spaceLedger(measureKey)
        default:
            throw InvestigationDomainError.invalidSourceBinding
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .snapshot(snapshotID):
            try container.encode("snapshot-v1", forKey: .kind)
            try container.encode(snapshotID, forKey: .snapshotID)
            try container.encodeNil(forKey: .classificationID)
            try container.encodeNil(forKey: .measureKey)
        case let .classification(classificationID, snapshotID):
            try container.encode(
                "classification-snapshot-v1",
                forKey: .kind
            )
            try container.encode(snapshotID, forKey: .snapshotID)
            try container.encode(classificationID, forKey: .classificationID)
            try container.encodeNil(forKey: .measureKey)
        case let .spaceLedger(measureKey):
            try container.encode("space-ledger-measure-v1", forKey: .kind)
            try container.encodeNil(forKey: .snapshotID)
            try container.encodeNil(forKey: .classificationID)
            try container.encode(measureKey, forKey: .measureKey)
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case snapshotID
        case classificationID
        case measureKey
    }
}

extension InvestigationSourceBinding: StrictIntegerDomainJSON {}

public enum InvestigationTargetKind:
    String,
    Codable,
    Sendable,
    Hashable,
    CaseIterable
{
    case unknownLargeConsumer = "unknown-large-consumer-v1"
    case unexplainedSpaceGap = "unexplained-space-gap-v1"
    case classificationConflict = "classification-conflict-v1"
    case unknownProducer = "unknown-producer-v1"
    case staleOrInsufficientEvidence = "stale-or-insufficient-evidence-v1"
}

public enum InvestigationPriorityTier:
    String,
    Codable,
    Sendable,
    Hashable
{
    case measured = "measured-v1"
    case unmeasurable = "unmeasurable-v1"
}

public struct InvestigationPriority:
    Sendable,
    Hashable
{
    public let tier: InvestigationPriorityTier
    public let score: UInt64

    public init(tier: InvestigationPriorityTier, score: UInt64) {
        self.tier = tier
        self.score = score
    }
}

extension InvestigationPriority: Codable {
    public init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard CodingKeys.allCases.allSatisfy(container.contains) else {
            throw InvestigationDomainError.invalidPriority
        }
        self.init(
            tier: try container.decode(
                InvestigationPriorityTier.self,
                forKey: .tier
            ),
            score: try container.decode(UInt64.self, forKey: .score)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tier, forKey: .tier)
        try container.encode(score, forKey: .score)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case tier
        case score
    }
}

extension InvestigationPriority: StrictIntegerDomainJSON {}

public struct InvestigationTarget: Sendable, Hashable {
    public let schemaVersion: DomainSchemaVersion
    public let id: InvestigationTargetID
    public let scanSessionID: ScanSessionID
    public let scanScopeID: ScanScopeID
    public let sourceBinding: InvestigationSourceBinding
    public let kind: InvestigationTargetKind
    public let reasonKeys: [DomainToken]
    public let expectedAllocatedBytes: ByteCount?
    public let uncertaintyPermille: UInt64
    public let relevancePermille: UInt64
    public let investigationCostPermille: UInt64
    public let priority: InvestigationPriority
    public let createdAt: Date

    public init(
        scanSessionID: ScanSessionID,
        scanScopeID: ScanScopeID,
        sourceBinding: InvestigationSourceBinding,
        kind: InvestigationTargetKind,
        reasonKeys: [DomainToken],
        expectedAllocatedBytes: ByteCount?,
        uncertaintyPermille: UInt64,
        relevancePermille: UInt64,
        investigationCostPermille: UInt64,
        createdAt: Date
    ) throws {
        _ = try createdAt.validatedInvestigationMicroseconds
        guard (1...1_000).contains(uncertaintyPermille),
              (1...1_000).contains(relevancePermille),
              (1...1_000).contains(investigationCostPermille)
        else {
            throw InvestigationDomainError.invalidFactor
        }
        try InvestigationCanonicalCodec.validateCanonicalTokens(
            reasonKeys,
            allowedCount: 1...16
        )
        let priority = try InvestigationCanonicalCodec.priority(
            expectedAllocatedBytes: expectedAllocatedBytes,
            uncertaintyPermille: uncertaintyPermille,
            relevancePermille: relevancePermille,
            investigationCostPermille: investigationCostPermille
        )
        let identity = try InvestigationCanonicalCodec.targetIdentityBytes(
            scanSessionID: scanSessionID,
            scanScopeID: scanScopeID,
            kind: kind,
            sourceBinding: sourceBinding
        )
        let digest = SHA256.hash(data: identity)
        guard let id = InvestigationTargetID(
            rawValue: "target-\(digest.hexString)"
        ) else {
            throw InvestigationDomainError.invalidPlan
        }

        schemaVersion = .v2
        self.id = id
        self.scanSessionID = scanSessionID
        self.scanScopeID = scanScopeID
        self.sourceBinding = sourceBinding
        self.kind = kind
        self.reasonKeys = reasonKeys
        self.expectedAllocatedBytes = expectedAllocatedBytes
        self.uncertaintyPermille = uncertaintyPermille
        self.relevancePermille = relevancePermille
        self.investigationCostPermille = investigationCostPermille
        self.priority = priority
        self.createdAt = createdAt
    }
}

extension InvestigationTarget: Codable {
    public init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard CodingKeys.allCases.allSatisfy(container.contains) else {
            throw InvestigationDomainError.invalidPlan
        }
        let schemaVersion = try container.decode(
            DomainSchemaVersion.self,
            forKey: .schemaVersion
        )
        try requireDomainSchemaVersion(schemaVersion, expected: .v2)
        let encodedID = try container.decode(
            InvestigationTargetID.self,
            forKey: .id
        )
        let encodedPriority = try container.decode(
            InvestigationPriority.self,
            forKey: .priority
        )
        try self.init(
            scanSessionID: container.decode(
                ScanSessionID.self,
                forKey: .scanSessionID
            ),
            scanScopeID: container.decode(
                ScanScopeID.self,
                forKey: .scanScopeID
            ),
            sourceBinding: container.decode(
                InvestigationSourceBinding.self,
                forKey: .sourceBinding
            ),
            kind: container.decode(
                InvestigationTargetKind.self,
                forKey: .kind
            ),
            reasonKeys: container.decode(
                [DomainToken].self,
                forKey: .reasonKeys
            ),
            expectedAllocatedBytes: container.decodeIfPresent(
                ByteCount.self,
                forKey: .expectedAllocatedBytes
            ),
            uncertaintyPermille: container.decode(
                UInt64.self,
                forKey: .uncertaintyPermille
            ),
            relevancePermille: container.decode(
                UInt64.self,
                forKey: .relevancePermille
            ),
            investigationCostPermille: container.decode(
                UInt64.self,
                forKey: .investigationCostPermille
            ),
            createdAt: try Date(
                investigationMicroseconds: container.decode(
                    Int64.self,
                    forKey: .createdAtMicros
                )
            )
        )
        guard id == encodedID, priority == encodedPriority else {
            throw InvestigationDomainError.invalidPriority
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(scanSessionID, forKey: .scanSessionID)
        try container.encode(scanScopeID, forKey: .scanScopeID)
        try container.encode(sourceBinding, forKey: .sourceBinding)
        try container.encode(kind, forKey: .kind)
        try container.encode(reasonKeys, forKey: .reasonKeys)
        if let expectedAllocatedBytes {
            try container.encode(
                expectedAllocatedBytes,
                forKey: .expectedAllocatedBytes
            )
        } else {
            try container.encodeNil(forKey: .expectedAllocatedBytes)
        }
        try container.encode(
            uncertaintyPermille,
            forKey: .uncertaintyPermille
        )
        try container.encode(relevancePermille, forKey: .relevancePermille)
        try container.encode(
            investigationCostPermille,
            forKey: .investigationCostPermille
        )
        try container.encode(priority, forKey: .priority)
        try container.encode(
            createdAt.validatedInvestigationMicroseconds,
            forKey: .createdAtMicros
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case id
        case scanSessionID
        case scanScopeID
        case sourceBinding
        case kind
        case reasonKeys
        case expectedAllocatedBytes
        case uncertaintyPermille
        case relevancePermille
        case investigationCostPermille
        case priority
        case createdAtMicros
    }
}

extension InvestigationTarget: StrictIntegerDomainJSON {}

public enum InvestigationCapability:
    String,
    Codable,
    Sendable,
    Hashable,
    CaseIterable
{
    case directRead = "direct-read-v1"
    case shell = "shell-v1"
    case unifiedExec = "unified-exec-v1"
    case liveSearch = "live-search-v1"
    case publicCommandNetwork = "public-command-network-v1"
    case browserOrDirectFetch = "browser-or-direct-fetch-v1"
    case imageInspection = "image-inspection-v1"
    case skills = "skills-v1"
    case subagents = "subagents-v1"

    public static let required: [InvestigationCapability] = [
        .shell,
        .skills,
        .subagents,
        .directRead,
        .liveSearch,
        .unifiedExec,
        .imageInspection,
        .publicCommandNetwork,
        .browserOrDirectFetch,
    ]
}

public struct InvestigationPlan: Sendable, Equatable {
    public static let maximumTargetCount = 512
    public static let maximumCanonicalBytes = 2_097_152
    public static let maximumJSONBytes = 4_194_304
    public static let policyRequestedCoveragePermille: UInt64 = 900
    public static let policyRemainingUnknownByteThreshold =
        ByteCount(1_073_741_824)!

    public let schemaVersion: DomainSchemaVersion
    public let id: InvestigationID
    public let scanSessionID: ScanSessionID
    public let scanScopeID: ScanScopeID
    public let sourceFingerprint: InvestigationFingerprint
    public let budgetPreset: InvestigationBudgetPreset
    public let budgetLimits: InvestigationBudgetLimits
    public let targets: [InvestigationTarget]
    public let targetSetFingerprint: InvestigationFingerprint
    public let createdAt: Date
    public let expiresAt: Date
    public let requestedCoveragePermille: UInt64
    public let remainingUnknownByteThreshold: ByteCount?
    public let requiredCapabilities: [InvestigationCapability]

    public init(
        id: InvestigationID,
        scanSessionID: ScanSessionID,
        scanScopeID: ScanScopeID,
        sourceFingerprint: InvestigationFingerprint,
        budgetPreset: InvestigationBudgetPreset,
        targets: [InvestigationTarget],
        createdAt: Date,
        expiresAt: Date,
        requestedCoveragePermille: UInt64,
        remainingUnknownByteThreshold: ByteCount?,
        requiredCapabilities: [InvestigationCapability]
    ) throws {
        _ = try createdAt.validatedInvestigationMicroseconds
        _ = try expiresAt.validatedInvestigationMicroseconds
        guard targets.count <= Self.maximumTargetCount,
              createdAt < expiresAt,
              requestedCoveragePermille
                == Self.policyRequestedCoveragePermille,
              remainingUnknownByteThreshold
                == Self.policyRemainingUnknownByteThreshold,
              requiredCapabilities == InvestigationCapability.required,
              targets.allSatisfy({
                $0.scanSessionID == scanSessionID
                    && $0.scanScopeID == scanScopeID
              }),
              Set(targets.map(\.id)).count == targets.count,
              Set(targets.map(\.sourceBinding)).count == targets.count
        else {
            throw InvestigationDomainError.invalidPlan
        }
        guard try InvestigationTargetPlannerOrder.isCanonical(targets) else {
            throw InvestigationDomainError.invalidPlan
        }

        schemaVersion = .v1
        self.id = id
        self.scanSessionID = scanSessionID
        self.scanScopeID = scanScopeID
        self.sourceFingerprint = sourceFingerprint
        self.budgetPreset = budgetPreset
        budgetLimits = .forPreset(budgetPreset)
        self.targets = targets
        targetSetFingerprint = try InvestigationCanonicalCodec.fingerprint(
            InvestigationCanonicalCodec.targetSetBytes(targets: targets)
        )
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.requestedCoveragePermille = requestedCoveragePermille
        self.remainingUnknownByteThreshold = remainingUnknownByteThreshold
        self.requiredCapabilities = requiredCapabilities

        guard try InvestigationCanonicalCodec.planBytes(self).count
                <= Self.maximumCanonicalBytes,
              try DomainJSON.encode(self).count <= Self.maximumJSONBytes
        else {
            throw InvestigationDomainError.canonicalInputTooLarge
        }
    }

    public var fingerprint: InvestigationFingerprint {
        try! InvestigationCanonicalCodec.fingerprint(
            InvestigationCanonicalCodec.planBytes(self)
        )
    }
}

enum InvestigationTargetPlannerOrder {
    static func sorted(
        _ targets: [InvestigationTarget]
    ) throws -> [InvestigationTarget] {
        try targets.map {
            RankedTarget(
                target: $0,
                tieBreakBytes: try tieBreakBytes($0)
            )
        }.sorted(by: precedes).map(\.target)
    }

    static func isCanonical(
        _ targets: [InvestigationTarget]
    ) throws -> Bool {
        var previous: RankedTarget?
        for target in targets {
            let current = RankedTarget(
                target: target,
                tieBreakBytes: try tieBreakBytes(target)
            )
            if let previous, !precedes(previous, current) {
                return false
            }
            previous = current
        }
        return true
    }

    private static func precedes(
        _ lhs: RankedTarget,
        _ rhs: RankedTarget
    ) -> Bool {
        if lhs.target.priority.tier != rhs.target.priority.tier {
            return lhs.target.priority.tier == .measured
        }
        if lhs.target.priority.score != rhs.target.priority.score {
            return lhs.target.priority.score > rhs.target.priority.score
        }
        return lhs.tieBreakBytes.lexicographicallyPrecedes(rhs.tieBreakBytes)
    }

    private static func tieBreakBytes(
        _ target: InvestigationTarget
    ) throws -> Data {
        let kind = try canonicalBytes(.text(target.kind.rawValue))
        let binding = try canonicalBytes(target.sourceBinding.canonicalValue)
        var reasons = Data()
        for reason in target.reasonKeys {
            let encoded = try canonicalBytes(.text(reason.rawValue))
            reasons.append(bigEndianData(UInt64(encoded.count)))
            reasons.append(encoded)
        }
        return framed([kind, binding, reasons])
    }

    private static func canonicalBytes(
        _ value: InvestigationCanonicalValue
    ) throws -> Data {
        var data = Data()
        try StornautInvestigationCanonicalV1.appendValueForSchema(
            value,
            to: &data
        )
        return data
    }

    private static func framed(_ values: [Data]) -> Data {
        var result = Data()
        for value in values {
            result.append(bigEndianData(UInt64(value.count)))
            result.append(value)
        }
        return result
    }

    private static func bigEndianData(_ value: UInt64) -> Data {
        var data = Data()
        data.reserveCapacity(8)
        for shift in stride(from: 56, through: 0, by: -8) {
            data.append(UInt8(truncatingIfNeeded: value >> UInt64(shift)))
        }
        return data
    }

    private struct RankedTarget {
        let target: InvestigationTarget
        let tieBreakBytes: Data
    }
}

extension InvestigationPlan: Codable {
    public init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard CodingKeys.allCases.allSatisfy(container.contains) else {
            throw InvestigationDomainError.invalidPlan
        }
        let schemaVersion = try container.decode(
            DomainSchemaVersion.self,
            forKey: .schemaVersion
        )
        try requireDomainSchemaVersion(schemaVersion, expected: .v1)
        let presetToken = try container.decode(
            String.self,
            forKey: .budgetPreset
        )
        guard let preset = InvestigationCanonicalCodec.preset(
            wireToken: presetToken
        ) else {
            throw InvestigationDomainError.invalidBudget
        }
        let encodedLimits = try container.decode(
            InvestigationBudgetLimits.self,
            forKey: .budgetLimits
        )
        let encodedTargetSetFingerprint = try container.decode(
            InvestigationFingerprint.self,
            forKey: .targetSetFingerprint
        )
        try self.init(
            id: container.decode(InvestigationID.self, forKey: .id),
            scanSessionID: container.decode(
                ScanSessionID.self,
                forKey: .scanSessionID
            ),
            scanScopeID: container.decode(
                ScanScopeID.self,
                forKey: .scanScopeID
            ),
            sourceFingerprint: container.decode(
                InvestigationFingerprint.self,
                forKey: .sourceFingerprint
            ),
            budgetPreset: preset,
            targets: container.decode(
                [InvestigationTarget].self,
                forKey: .targets
            ),
            createdAt: try Date(
                investigationMicroseconds: container.decode(
                    Int64.self,
                    forKey: .createdAtMicros
                )
            ),
            expiresAt: try Date(
                investigationMicroseconds: container.decode(
                    Int64.self,
                    forKey: .expiresAtMicros
                )
            ),
            requestedCoveragePermille: container.decode(
                UInt64.self,
                forKey: .requestedCoveragePermille
            ),
            remainingUnknownByteThreshold: container.decodeIfPresent(
                ByteCount.self,
                forKey: .remainingUnknownByteThreshold
            ),
            requiredCapabilities: container.decode(
                [InvestigationCapability].self,
                forKey: .requiredCapabilities
            )
        )
        guard budgetLimits == encodedLimits,
              targetSetFingerprint == encodedTargetSetFingerprint
        else {
            throw InvestigationDomainError.invalidPlan
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(scanSessionID, forKey: .scanSessionID)
        try container.encode(scanScopeID, forKey: .scanScopeID)
        try container.encode(sourceFingerprint, forKey: .sourceFingerprint)
        try container.encode(
            InvestigationCanonicalCodec.wireToken(for: budgetPreset),
            forKey: .budgetPreset
        )
        try container.encode(budgetLimits, forKey: .budgetLimits)
        try container.encode(targets, forKey: .targets)
        try container.encode(
            targetSetFingerprint,
            forKey: .targetSetFingerprint
        )
        try container.encode(
            createdAt.validatedInvestigationMicroseconds,
            forKey: .createdAtMicros
        )
        try container.encode(
            expiresAt.validatedInvestigationMicroseconds,
            forKey: .expiresAtMicros
        )
        try container.encode(
            requestedCoveragePermille,
            forKey: .requestedCoveragePermille
        )
        if let remainingUnknownByteThreshold {
            try container.encode(
                remainingUnknownByteThreshold,
                forKey: .remainingUnknownByteThreshold
            )
        } else {
            try container.encodeNil(forKey: .remainingUnknownByteThreshold)
        }
        try container.encode(
            requiredCapabilities,
            forKey: .requiredCapabilities
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case id
        case scanSessionID
        case scanScopeID
        case sourceFingerprint
        case budgetPreset
        case budgetLimits
        case targets
        case targetSetFingerprint
        case createdAtMicros
        case expiresAtMicros
        case requestedCoveragePermille
        case remainingUnknownByteThreshold
        case requiredCapabilities
    }
}

extension InvestigationPlan: StrictIntegerDomainJSON {}

enum InvestigationCanonicalCodec {
    static func validateTargetIdentityBytes(_ data: Data) throws {
        let root = try StornautInvestigationCanonicalV1.decode(
            data,
            expectedDomain: "stornaut.investigation.target.v2",
            maximumInputBytes: 4_096
        )
        let fields = try exactRecord(root, tags: Array(1...5))
        guard try unsigned(fields[1]) == 2 else {
            throw InvestigationDomainError.invalidPlan
        }
        let scanSessionID = try ScanSessionID(
            validating: text(fields[2])
        )
        let scanScopeID = try ScanScopeID(
            validating: text(fields[3])
        )
        guard let kind = InvestigationTargetKind(
            rawValue: try text(fields[4])
        ) else {
            throw InvestigationDomainError.invalidPlan
        }
        let sourceBinding = try decodeSourceBinding(fields[5])
        guard try targetIdentityBytes(
            scanSessionID: scanSessionID,
            scanScopeID: scanScopeID,
            kind: kind,
            sourceBinding: sourceBinding
        ) == data else {
            throw InvestigationDomainError.invalidPlan
        }
    }

    static func decodeTargetSetBytes(
        _ data: Data
    ) throws -> [InvestigationTargetID] {
        let root = try StornautInvestigationCanonicalV1.decode(
            data,
            expectedDomain: "stornaut.investigation.target-set.v1",
            maximumInputBytes: 65_536
        )
        let fields = try exactRecord(root, tags: [1, 2])
        guard try unsigned(fields[1]) == 1 else {
            throw InvestigationDomainError.invalidPlan
        }
        let identifiers = try array(fields[2]).map {
            try InvestigationTargetID(validating: text($0))
        }
        guard identifiers.count <= InvestigationPlan.maximumTargetCount,
              Set(identifiers).count == identifiers.count,
              try StornautInvestigationCanonicalV1.encode(
                  domain: "stornaut.investigation.target-set.v1",
                  root: .record([
                      .init(tag: 1, value: .unsigned(1)),
                      .init(
                          tag: 2,
                          value: .array(
                              identifiers.map { .text($0.rawValue) }
                          )
                      ),
                  ])
              ) == data
        else {
            throw InvestigationDomainError.invalidPlan
        }
        return identifiers
    }

    static func decodePlanBytes(_ data: Data) throws -> InvestigationPlan {
        let root = try StornautInvestigationCanonicalV1.decode(
            data,
            expectedDomain: "stornaut.investigation.plan.v1",
            maximumInputBytes: InvestigationPlan.maximumCanonicalBytes
        )
        let fields = try exactRecord(root, tags: Array(1...14))
        guard try unsigned(fields[1]) == 1 else {
            throw InvestigationDomainError.invalidPlan
        }
        let id = try InvestigationID(validating: text(fields[2]))
        let scanSessionID = try ScanSessionID(
            validating: text(fields[3])
        )
        let scanScopeID = try ScanScopeID(
            validating: text(fields[4])
        )
        let sourceFingerprint = try InvestigationFingerprint(
            validating: bytes(fields[5])
        )
        guard let budgetPreset = preset(wireToken: try text(fields[6]))
        else {
            throw InvestigationDomainError.invalidBudget
        }
        let encodedBudgetLimits = try budgetLimits(fields[7])
        let targets = try array(fields[8]).map(decodeTarget)
        let encodedTargetSetFingerprint = try InvestigationFingerprint(
            validating: bytes(fields[9])
        )
        let createdAt = try Date(
            investigationMicroseconds: signed(fields[10])
        )
        let expiresAt = try Date(
            investigationMicroseconds: signed(fields[11])
        )
        let requestedCoveragePermille = try unsigned(fields[12])
        let remainingUnknownByteThreshold = try optionalByteCount(
            fields[13]
        )
        let requiredCapabilities = try array(fields[14]).map { value in
            guard let capability = InvestigationCapability(
                rawValue: try text(value)
            ) else {
                throw InvestigationDomainError.invalidPlan
            }
            return capability
        }

        let plan = try InvestigationPlan(
            id: id,
            scanSessionID: scanSessionID,
            scanScopeID: scanScopeID,
            sourceFingerprint: sourceFingerprint,
            budgetPreset: budgetPreset,
            targets: targets,
            createdAt: createdAt,
            expiresAt: expiresAt,
            requestedCoveragePermille: requestedCoveragePermille,
            remainingUnknownByteThreshold: remainingUnknownByteThreshold,
            requiredCapabilities: requiredCapabilities
        )
        guard plan.budgetLimits == encodedBudgetLimits,
              plan.targetSetFingerprint == encodedTargetSetFingerprint,
              try planBytes(plan) == data
        else {
            throw InvestigationDomainError.invalidPlan
        }
        return plan
    }

    static func targetIdentityBytes(
        scanSessionID: ScanSessionID,
        scanScopeID: ScanScopeID,
        kind: InvestigationTargetKind,
        sourceBinding: InvestigationSourceBinding
    ) throws -> Data {
        try StornautInvestigationCanonicalV1.encode(
            domain: "stornaut.investigation.target.v2",
            root: .record([
                .init(tag: 1, value: .unsigned(2)),
                .init(tag: 2, value: .text(scanSessionID.rawValue)),
                .init(tag: 3, value: .text(scanScopeID.rawValue)),
                .init(tag: 4, value: .text(kind.rawValue)),
                .init(tag: 5, value: sourceBinding.canonicalValue),
            ])
        )
    }

    static func targetSetBytes(
        targets: [InvestigationTarget]
    ) throws -> Data {
        try StornautInvestigationCanonicalV1.encode(
            domain: "stornaut.investigation.target-set.v1",
            root: .record([
                .init(tag: 1, value: .unsigned(1)),
                .init(
                    tag: 2,
                    value: .array(targets.map { .text($0.id.rawValue) })
                ),
            ])
        )
    }

    static func planBytes(_ plan: InvestigationPlan) throws -> Data {
        try StornautInvestigationCanonicalV1.encode(
            domain: "stornaut.investigation.plan.v1",
            root: .record([
                .init(tag: 1, value: .unsigned(1)),
                .init(tag: 2, value: .text(plan.id.rawValue)),
                .init(tag: 3, value: .text(plan.scanSessionID.rawValue)),
                .init(tag: 4, value: .text(plan.scanScopeID.rawValue)),
                .init(tag: 5, value: .bytes(plan.sourceFingerprint.bytes)),
                .init(
                    tag: 6,
                    value: .text(wireToken(for: plan.budgetPreset))
                ),
                .init(tag: 7, value: plan.budgetLimits.canonicalValue),
                .init(
                    tag: 8,
                    value: .array(
                        try plan.targets.map { try $0.canonicalValue }
                    )
                ),
                .init(
                    tag: 9,
                    value: .bytes(plan.targetSetFingerprint.bytes)
                ),
                .init(
                    tag: 10,
                    value: .signed(
                        try plan.createdAt.validatedInvestigationMicroseconds
                    )
                ),
                .init(
                    tag: 11,
                    value: .signed(
                        try plan.expiresAt.validatedInvestigationMicroseconds
                    )
                ),
                .init(
                    tag: 12,
                    value: .unsigned(plan.requestedCoveragePermille)
                ),
                .init(
                    tag: 13,
                    value: plan.remainingUnknownByteThreshold
                        .map { .unsigned($0.value) } ?? .null
                ),
                .init(
                    tag: 14,
                    value: .array(
                        plan.requiredCapabilities.map { .text($0.rawValue) }
                    )
                ),
            ])
        )
    }

    static func fingerprint(_ data: Data) throws -> InvestigationFingerprint {
        try InvestigationFingerprint(validating: Data(SHA256.hash(data: data)))
    }

    static func priority(
        expectedAllocatedBytes: ByteCount?,
        uncertaintyPermille: UInt64,
        relevancePermille: UInt64,
        investigationCostPermille: UInt64
    ) throws -> InvestigationPriority {
        let base: UInt64
        let tier: InvestigationPriorityTier
        if let expectedAllocatedBytes {
            let value = expectedAllocatedBytes.value
            let quotient = value / 1_048_576
            let remainder = value % 1_048_576
            let rounded = quotient.addingReportingOverflow(
                remainder == 0 ? 0 : 1
            )
            guard !rounded.overflow else {
                throw InvestigationDomainError.invalidPriority
            }
            base = rounded.partialValue
            tier = .measured
        } else {
            base = 1
            tier = .unmeasurable
        }
        let first = base.multipliedReportingOverflow(
            by: uncertaintyPermille
        )
        let second = first.partialValue.multipliedReportingOverflow(
            by: relevancePermille
        )
        guard !first.overflow, !second.overflow else {
            throw InvestigationDomainError.invalidPriority
        }
        return InvestigationPriority(
            tier: tier,
            score: second.partialValue / investigationCostPermille
        )
    }

    static func validateCanonicalTokens(
        _ tokens: [DomainToken],
        allowedCount: ClosedRange<Int>
    ) throws {
        guard allowedCount.contains(tokens.count) else {
            throw InvestigationDomainError.invalidCanonicalSet
        }
        let values = tokens.map {
            InvestigationCanonicalValue.text($0.rawValue)
        }
        var previous: Data?
        for value in values {
            var encoded = Data()
            try StornautInvestigationCanonicalV1.appendValueForSchema(
                value,
                to: &encoded
            )
            if let previous,
               previous.lexicographicallyPrecedes(encoded) == false
            {
                throw InvestigationDomainError.invalidCanonicalSet
            }
            previous = encoded
        }
    }

    static func wireToken(
        for preset: InvestigationBudgetPreset
    ) -> String {
        "\(preset.rawValue)-v1"
    }

    static func preset(
        wireToken: String
    ) -> InvestigationBudgetPreset? {
        guard wireToken.hasSuffix("-v1") else {
            return nil
        }
        return InvestigationBudgetPreset(
            rawValue: String(wireToken.dropLast(3))
        )
    }

    private static func decodeTarget(
        _ value: InvestigationCanonicalValue
    ) throws -> InvestigationTarget {
        var encoded = Data()
        try StornautInvestigationCanonicalV1.appendValueForSchema(
            value,
            to: &encoded
        )
        guard encoded.count <= 16_384 else {
            throw InvestigationDomainError.canonicalInputTooLarge
        }

        let fields = try exactRecord(value, tags: Array(1...13))
        guard try unsigned(fields[1]) == 2 else {
            throw InvestigationDomainError.invalidPlan
        }
        let encodedID = try InvestigationTargetID(
            validating: text(fields[2])
        )
        let scanSessionID = try ScanSessionID(
            validating: text(fields[3])
        )
        let scanScopeID = try ScanScopeID(
            validating: text(fields[4])
        )
        guard let kind = InvestigationTargetKind(
            rawValue: try text(fields[5])
        ) else {
            throw InvestigationDomainError.invalidPlan
        }
        let sourceBinding = try decodeSourceBinding(fields[6])
        let reasonKeys = try array(fields[7]).map {
            try DomainToken(validating: text($0))
        }
        let expectedAllocatedBytes = try optionalByteCount(fields[8])
        let uncertaintyPermille = try unsigned(fields[9])
        let relevancePermille = try unsigned(fields[10])
        let investigationCostPermille = try unsigned(fields[11])
        let encodedPriority = try decodePriority(fields[12])
        let createdAt = try Date(
            investigationMicroseconds: signed(fields[13])
        )

        let target = try InvestigationTarget(
            scanSessionID: scanSessionID,
            scanScopeID: scanScopeID,
            sourceBinding: sourceBinding,
            kind: kind,
            reasonKeys: reasonKeys,
            expectedAllocatedBytes: expectedAllocatedBytes,
            uncertaintyPermille: uncertaintyPermille,
            relevancePermille: relevancePermille,
            investigationCostPermille: investigationCostPermille,
            createdAt: createdAt
        )
        guard target.id == encodedID,
              target.priority == encodedPriority,
              try target.canonicalValue == value
        else {
            throw InvestigationDomainError.invalidPlan
        }
        return target
    }

    private static func decodeSourceBinding(
        _ value: InvestigationCanonicalValue?
    ) throws -> InvestigationSourceBinding {
        guard let value else {
            throw InvestigationDomainError.invalidSourceBinding
        }
        let fields = try exactRecord(value, tags: Array(1...4))
        let kind = try text(fields[1])
        let snapshotID = try optionalText(fields[2]).map {
            try SnapshotID(validating: $0)
        }
        let classificationID = try optionalText(fields[3]).map {
            try ClassificationID(validating: $0)
        }
        let measureKey = try optionalText(fields[4]).map { token in
            guard let value = InvestigationSpaceLedgerMeasureKey(
                rawValue: token
            ) else {
                throw InvestigationDomainError.invalidSourceBinding
            }
            return value
        }

        switch (kind, snapshotID, classificationID, measureKey) {
        case ("snapshot-v1", let snapshotID?, nil, nil):
            return .snapshot(snapshotID)
        case (
            "classification-snapshot-v1",
            let snapshotID?,
            let classificationID?,
            nil
        ):
            return .classification(
                classificationID: classificationID,
                snapshotID: snapshotID
            )
        case ("space-ledger-measure-v1", nil, nil, let measureKey?):
            return .spaceLedger(measureKey)
        default:
            throw InvestigationDomainError.invalidSourceBinding
        }
    }

    private static func decodePriority(
        _ value: InvestigationCanonicalValue?
    ) throws -> InvestigationPriority {
        guard let value else {
            throw InvestigationDomainError.invalidPriority
        }
        let fields = try exactRecord(value, tags: [1, 2])
        guard let tier = InvestigationPriorityTier(
            rawValue: try text(fields[1])
        ) else {
            throw InvestigationDomainError.invalidPriority
        }
        return InvestigationPriority(
            tier: tier,
            score: try unsigned(fields[2])
        )
    }

    private static func budgetLimits(
        _ value: InvestigationCanonicalValue?
    ) throws -> InvestigationBudgetLimits {
        guard let value else {
            throw InvestigationDomainError.invalidBudget
        }
        let fields = try exactRecord(value, tags: Array(1...11))
        let limits = InvestigationBudgetLimits(
            wallClockNanoseconds: try unsigned(fields[1]),
            coordinatorTurns: try unsigned(fields[2]),
            probeCalls: try unsigned(fields[3]),
            probeReadBytes: try unsigned(fields[4]),
            probeOutputBytes: try unsigned(fields[5]),
            cumulativeContextBytes: try unsigned(fields[6]),
            concurrentProbes: try unsigned(fields[7]),
            consecutiveNoGainSteps: try unsigned(fields[8]),
            observedDirectToolStarts: try unsigned(fields[9]),
            observedTotalTokens: try unsigned(fields[10]),
            singleContextInputBytes: try unsigned(fields[11])
        )
        guard InvestigationBudgetPreset.allCases.contains(where: {
            limits == .forPreset($0)
        }) else {
            throw InvestigationDomainError.invalidBudget
        }
        return limits
    }

    private static func optionalByteCount(
        _ value: InvestigationCanonicalValue?
    ) throws -> ByteCount? {
        guard let value else {
            throw InvestigationDomainError.invalidPlan
        }
        if case .null = value {
            return nil
        }
        guard let byteCount = ByteCount(try unsigned(value)) else {
            throw InvestigationDomainError.invalidPlan
        }
        return byteCount
    }

    private static func exactRecord(
        _ value: InvestigationCanonicalValue,
        tags: [UInt16]
    ) throws -> [UInt16: InvestigationCanonicalValue] {
        guard case let .record(fields) = value,
              fields.map(\.tag) == tags
        else {
            throw InvestigationDomainError.invalidPlan
        }
        return Dictionary(
            uniqueKeysWithValues: fields.map { ($0.tag, $0.value) }
        )
    }

    private static func unsigned(
        _ value: InvestigationCanonicalValue?
    ) throws -> UInt64 {
        guard case let .unsigned(decoded)? = value else {
            throw InvestigationDomainError.invalidPlan
        }
        return decoded
    }

    private static func signed(
        _ value: InvestigationCanonicalValue?
    ) throws -> Int64 {
        guard case let .signed(decoded)? = value else {
            throw InvestigationDomainError.invalidPlan
        }
        return decoded
    }

    private static func text(
        _ value: InvestigationCanonicalValue?
    ) throws -> String {
        guard case let .text(decoded)? = value else {
            throw InvestigationDomainError.invalidPlan
        }
        return decoded
    }

    private static func optionalText(
        _ value: InvestigationCanonicalValue?
    ) throws -> String? {
        guard let value else {
            throw InvestigationDomainError.invalidPlan
        }
        if case .null = value {
            return nil
        }
        return try text(value)
    }

    private static func bytes(
        _ value: InvestigationCanonicalValue?
    ) throws -> Data {
        guard case let .bytes(decoded)? = value else {
            throw InvestigationDomainError.invalidPlan
        }
        return decoded
    }

    private static func array(
        _ value: InvestigationCanonicalValue?
    ) throws -> [InvestigationCanonicalValue] {
        guard case let .array(decoded)? = value else {
            throw InvestigationDomainError.invalidPlan
        }
        return decoded
    }
}

private extension InvestigationSourceBinding {
    var canonicalValue: InvestigationCanonicalValue {
        switch self {
        case let .snapshot(snapshotID):
            .record([
                .init(tag: 1, value: .text("snapshot-v1")),
                .init(tag: 2, value: .text(snapshotID.rawValue)),
                .init(tag: 3, value: .null),
                .init(tag: 4, value: .null),
            ])
        case let .classification(classificationID, snapshotID):
            .record([
                .init(tag: 1, value: .text("classification-snapshot-v1")),
                .init(tag: 2, value: .text(snapshotID.rawValue)),
                .init(tag: 3, value: .text(classificationID.rawValue)),
                .init(tag: 4, value: .null),
            ])
        case let .spaceLedger(measureKey):
            .record([
                .init(tag: 1, value: .text("space-ledger-measure-v1")),
                .init(tag: 2, value: .null),
                .init(tag: 3, value: .null),
                .init(tag: 4, value: .text(measureKey.rawValue)),
            ])
        }
    }
}

private extension InvestigationTarget {
    var canonicalValue: InvestigationCanonicalValue {
        get throws {
            .record([
                .init(tag: 1, value: .unsigned(2)),
                .init(tag: 2, value: .text(id.rawValue)),
                .init(tag: 3, value: .text(scanSessionID.rawValue)),
                .init(tag: 4, value: .text(scanScopeID.rawValue)),
                .init(tag: 5, value: .text(kind.rawValue)),
                .init(tag: 6, value: sourceBinding.canonicalValue),
                .init(
                    tag: 7,
                    value: .array(reasonKeys.map { .text($0.rawValue) })
                ),
                .init(
                    tag: 8,
                    value: expectedAllocatedBytes
                        .map { .unsigned($0.value) } ?? .null
                ),
                .init(tag: 9, value: .unsigned(uncertaintyPermille)),
                .init(tag: 10, value: .unsigned(relevancePermille)),
                .init(
                    tag: 11,
                    value: .unsigned(investigationCostPermille)
                ),
                .init(
                    tag: 12,
                    value: .record([
                        .init(tag: 1, value: .text(priority.tier.rawValue)),
                        .init(tag: 2, value: .unsigned(priority.score)),
                    ])
                ),
                .init(
                    tag: 13,
                    value: .signed(
                        try createdAt.validatedInvestigationMicroseconds
                    )
                ),
            ])
        }
    }
}

private extension InvestigationBudgetLimits {
    var canonicalValue: InvestigationCanonicalValue {
        .record([
            .init(tag: 1, value: .unsigned(wallClockNanoseconds)),
            .init(tag: 2, value: .unsigned(coordinatorTurns)),
            .init(tag: 3, value: .unsigned(probeCalls)),
            .init(tag: 4, value: .unsigned(probeReadBytes)),
            .init(tag: 5, value: .unsigned(probeOutputBytes)),
            .init(tag: 6, value: .unsigned(cumulativeContextBytes)),
            .init(tag: 7, value: .unsigned(concurrentProbes)),
            .init(tag: 8, value: .unsigned(consecutiveNoGainSteps)),
            .init(tag: 9, value: .unsigned(observedDirectToolStarts)),
            .init(tag: 10, value: .unsigned(observedTotalTokens)),
            .init(tag: 11, value: .unsigned(singleContextInputBytes)),
        ])
    }
}

private extension Date {
    init(investigationMicroseconds: Int64) throws {
        let decoded = Date(
            timeIntervalSince1970: TimeInterval(investigationMicroseconds)
                / 1_000_000
        )
        guard try decoded.validatedInvestigationMicroseconds
                == investigationMicroseconds
        else {
            throw InvestigationDomainError.invalidPlan
        }
        self = decoded
    }

    var validatedInvestigationMicroseconds: Int64 {
        get throws {
            let seconds = timeIntervalSince1970
            guard seconds.isFinite else {
                throw InvestigationDomainError.invalidPlan
            }
            let scaled = seconds * 1_000_000
            guard scaled.isFinite,
                  let value = Int64(
                      exactly: scaled.rounded(.towardZero)
                  )
            else {
                throw InvestigationDomainError.invalidPlan
            }
            return value
        }
    }
}

private extension Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
