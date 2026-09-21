import Foundation

public enum AccountingMeasurementStatus: String, Codable, Sendable {
    case measured
    case estimated
    case unknown
    case unmeasurable
}

public enum AccountingSourceKind: String, Codable, Sendable {
    case volumeResourceValues
    case fileSystemAttributes
    case surveyor
    case classifier
    case permissionGap
}

public struct AccountingSource: Codable, Sendable, Equatable {
    public let kind: AccountingSourceKind
    public let identifier: DomainToken
    public let sampledAt: Date

    public init(
        kind: AccountingSourceKind,
        identifier: DomainToken,
        sampledAt: Date
    ) {
        self.kind = kind
        self.identifier = identifier
        self.sampledAt = sampledAt
    }
}

public struct AccountingMeasure: Codable, Sendable, Equatable {
    public let status: AccountingMeasurementStatus
    public let bytes: ByteCount?
    public let source: AccountingSource
    public let explanationKey: DomainToken

    public init(
        status: AccountingMeasurementStatus,
        bytes: ByteCount?,
        source: AccountingSource,
        explanationKey: DomainToken
    ) throws {
        if (status == .measured || status == .estimated), bytes == nil {
            throw DomainContractError.invalidMeasurement
        }
        if (status == .unknown || status == .unmeasurable), bytes != nil {
            throw DomainContractError.invalidMeasurement
        }
        self.status = status
        self.bytes = bytes
        self.source = source
        self.explanationKey = explanationKey
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            status: container.decode(
                AccountingMeasurementStatus.self,
                forKey: .status
            ),
            bytes: container.decodeIfPresent(ByteCount.self, forKey: .bytes),
            source: container.decode(AccountingSource.self, forKey: .source),
            explanationKey: container.decode(
                DomainToken.self,
                forKey: .explanationKey
            )
        )
    }
}

public struct SpaceAccounting: Codable, Sendable, Equatable {
    public let schemaVersion: DomainSchemaVersion
    public let sessionID: ScanSessionID
    public let volumeCapacity: AccountingMeasure
    public let known: AccountingMeasure
    public let unknown: AccountingMeasure
    public let unmeasurable: AccountingMeasure
    public let free: AccountingMeasure

    public init(
        schemaVersion: DomainSchemaVersion = .v1,
        sessionID: ScanSessionID,
        volumeCapacity: AccountingMeasure,
        known: AccountingMeasure,
        unknown: AccountingMeasure,
        unmeasurable: AccountingMeasure,
        free: AccountingMeasure
    ) throws {
        try requireDomainSchemaVersion(schemaVersion, expected: .v1)
        self.schemaVersion = schemaVersion
        self.sessionID = sessionID
        self.volumeCapacity = volumeCapacity
        self.known = known
        self.unknown = unknown
        self.unmeasurable = unmeasurable
        self.free = free
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(
                DomainSchemaVersion.self,
                forKey: .schemaVersion
            ),
            sessionID: container.decode(
                ScanSessionID.self,
                forKey: .sessionID
            ),
            volumeCapacity: container.decode(
                AccountingMeasure.self,
                forKey: .volumeCapacity
            ),
            known: container.decode(AccountingMeasure.self, forKey: .known),
            unknown: container.decode(AccountingMeasure.self, forKey: .unknown),
            unmeasurable: container.decode(
                AccountingMeasure.self,
                forKey: .unmeasurable
            ),
            free: container.decode(AccountingMeasure.self, forKey: .free)
        )
    }
}
