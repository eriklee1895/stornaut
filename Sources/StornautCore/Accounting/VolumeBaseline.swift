import Foundation

public struct VolumeBaseline: Codable, Sendable, Equatable {
    public let schemaVersion: DomainSchemaVersion
    public let sessionID: ScanSessionID
    public let scopeID: ScanScopeID
    public let rootPath: PersistedPath
    public let rootIdentity: FileIdentity
    public let totalCapacity: ByteCount?
    public let availableCapacity: ByteCount?
    public let availableCapacityForImportantUsage: ByteCount?
    public let availableCapacityForOpportunisticUsage: ByteCount?
    public let volumeIsReadOnly: Bool?
    public let source: AccountingSource

    public init(
        schemaVersion: DomainSchemaVersion = .v1,
        sessionID: ScanSessionID,
        scopeID: ScanScopeID,
        rootPath: PersistedPath,
        rootIdentity: FileIdentity,
        totalCapacity: ByteCount?,
        availableCapacity: ByteCount?,
        availableCapacityForImportantUsage: ByteCount?,
        availableCapacityForOpportunisticUsage: ByteCount?,
        volumeIsReadOnly: Bool?,
        source: AccountingSource
    ) throws {
        try requireDomainSchemaVersion(schemaVersion, expected: .v1)
        guard rootIdentity.isDirectory,
              source.kind == .volumeResourceValues
                || source.kind == .fileSystemAttributes,
              Self.isValidCapacity(
                  availableCapacity,
                  total: totalCapacity
              ),
              Self.isValidCapacity(
                  availableCapacityForImportantUsage,
                  total: totalCapacity
              ),
              Self.isValidCapacity(
                  availableCapacityForOpportunisticUsage,
                  total: totalCapacity
              )
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.schemaVersion = schemaVersion
        self.sessionID = sessionID
        self.scopeID = scopeID
        self.rootPath = rootPath
        self.rootIdentity = rootIdentity
        self.totalCapacity = totalCapacity
        self.availableCapacity = availableCapacity
        self.availableCapacityForImportantUsage =
            availableCapacityForImportantUsage
        self.availableCapacityForOpportunisticUsage =
            availableCapacityForOpportunisticUsage
        self.volumeIsReadOnly = volumeIsReadOnly
        self.source = source
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
            scopeID: container.decode(ScanScopeID.self, forKey: .scopeID),
            rootPath: container.decode(PersistedPath.self, forKey: .rootPath),
            rootIdentity: container.decode(
                FileIdentity.self,
                forKey: .rootIdentity
            ),
            totalCapacity: container.decodeIfPresent(
                ByteCount.self,
                forKey: .totalCapacity
            ),
            availableCapacity: container.decodeIfPresent(
                ByteCount.self,
                forKey: .availableCapacity
            ),
            availableCapacityForImportantUsage: container.decodeIfPresent(
                ByteCount.self,
                forKey: .availableCapacityForImportantUsage
            ),
            availableCapacityForOpportunisticUsage: container.decodeIfPresent(
                ByteCount.self,
                forKey: .availableCapacityForOpportunisticUsage
            ),
            volumeIsReadOnly: container.decodeIfPresent(
                Bool.self,
                forKey: .volumeIsReadOnly
            ),
            source: container.decode(AccountingSource.self, forKey: .source)
        )
    }

    private static func isValidCapacity(
        _ value: ByteCount?,
        total: ByteCount?
    ) -> Bool {
        guard let value, let total else {
            return true
        }
        return value <= total
    }
}

public protocol VolumeBaselineSampling: Sendable {
    func sample(
        request: ScanRequest,
        sampledAt: Date
    ) throws -> VolumeBaseline
}

public struct FoundationVolumeBaselineSampler: VolumeBaselineSampling {
    public init() {}

    public func sample(
        request: ScanRequest,
        sampledAt: Date
    ) throws -> VolumeBaseline {
        let root = request.rootURL.standardizedFileURL
        var info = stat()
        guard lstat(root.path, &info) == 0 else {
            throw SurveyorError.invalidRoot
        }
        let identity = try FileIdentity(
            device: UInt64(bitPattern: Int64(info.st_dev)),
            inode: UInt64(info.st_ino),
            mode: UInt16(info.st_mode),
            ownerUserID: info.st_uid,
            ownerGroupID: info.st_gid,
            linkCount: UInt64(info.st_nlink),
            size: max(0, Int64(info.st_size)),
            allocatedBytes: allocatedBytes(info),
            modificationSeconds: Int64(info.st_mtimespec.tv_sec),
            modificationNanoseconds: Int64(info.st_mtimespec.tv_nsec)
        )
        let values = try root.resourceValues(
            forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityForOpportunisticUsageKey,
                .volumeIsReadOnlyKey,
            ]
        )
        return try VolumeBaseline(
            sessionID: request.sessionID,
            scopeID: request.scopeID,
            rootPath: PersistedPath(validating: root.path),
            rootIdentity: identity,
            totalCapacity: byteCount(values.volumeTotalCapacity.map(Int64.init)),
            availableCapacity: byteCount(
                values.volumeAvailableCapacity.map(Int64.init)
            ),
            availableCapacityForImportantUsage: byteCount(
                values.volumeAvailableCapacityForImportantUsage
            ),
            availableCapacityForOpportunisticUsage: byteCount(
                values.volumeAvailableCapacityForOpportunisticUsage
            ),
            volumeIsReadOnly: values.volumeIsReadOnly,
            source: AccountingSource(
                kind: .volumeResourceValues,
                identifier: try DomainToken(
                    validating: "foundation.volume-resource-values"
                ),
                sampledAt: sampledAt
            )
        )
    }
}

private func byteCount(_ value: Int64?) -> ByteCount? {
    value.flatMap(ByteCount.init(exactly:))
}

private func allocatedBytes(_ info: stat) -> Int64 {
    let result = Int64(info.st_blocks).multipliedReportingOverflow(by: 512)
    return result.overflow ? .max : max(0, result.partialValue)
}
