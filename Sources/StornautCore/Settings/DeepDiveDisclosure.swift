import CryptoKit
import Darwin
import Foundation

public enum DeepDiveDisclosureSemanticItem:
    String,
    Sendable,
    Equatable,
    CaseIterable
{
    case authorizedScopeDirectRead = "authorized-scope-direct-read"
    case modelContextEvidence = "model-context-evidence"
    case publicInternetServices = "public-internet-services"
    case autonomousReadOnlyTools = "autonomous-read-only-tools"
    case aggregateConsent = "aggregate-consent"
    case noWriteCleanupPolicyAuthorizationExecutor =
        "no-write-cleanup-policy-authorization-executor"
    case cleanupRejoinAndReauthorization =
        "cleanup-rejoin-and-reauthorization"
    case noCompletenessGuarantee = "no-completeness-guarantee"
    case quickScanRemainsLocal = "quick-scan-remains-local"
}

enum DeepDiveDisclosureDecision:
    String,
    Codable,
    Sendable,
    Equatable
{
    case accepted
    case declined
}

enum DeepDiveDisclosureRecordState: Sendable, Equatable {
    case notPresented
    case accepted(DeepDiveDisclosureRecord)
    case declined(DeepDiveDisclosureRecord)
    case obsolete(DeepDiveDisclosureRecord)
}

enum DeepDiveDisclosureStoreError: Error, Sendable, Equatable {
    case invalidDescriptor
    case invalidRecord
    case unsupportedSchema
    case payloadTooLarge
    case invalidPayload
    case unsafeStorage
}

public struct DeepDiveDisclosureDescriptor: Sendable, Equatable {
    public static let current: Self = {
        let version = DomainToken(
            rawValue: "deep-dive-disclosure-v1"
        )!
        let profile = DomainToken(
            rawValue: "deep-dive-data-boundary-v1"
        )!
        let fingerprint = semanticFingerprint(
            version: version,
            profile: profile
        )
        return try! Self(
            version: version,
            contentFingerprint: fingerprint,
            dataBoundaryProfileVersion: profile
        )
    }()

    public let version: DomainToken
    public let contentFingerprint: DomainToken
    public let dataBoundaryProfileVersion: DomainToken

    init(
        version: DomainToken,
        contentFingerprint: DomainToken,
        dataBoundaryProfileVersion: DomainToken
    ) throws {
        guard version.rawValue.hasPrefix("deep-dive-disclosure-v"),
              dataBoundaryProfileVersion.rawValue.hasPrefix(
                  "deep-dive-data-boundary-v"
              ),
              Self.isSHA256(contentFingerprint.rawValue)
        else {
            throw DeepDiveDisclosureStoreError.invalidDescriptor
        }
        self.version = version
        self.contentFingerprint = contentFingerprint
        self.dataBoundaryProfileVersion = dataBoundaryProfileVersion
    }

    public func semanticItems(
        for language: SettingsLanguage
    ) -> [DeepDiveDisclosureSemanticItem] {
        switch language {
        case .english, .simplifiedChinese:
            DeepDiveDisclosureSemanticItem.allCases
        }
    }

    func record(
        decision: DeepDiveDisclosureDecision,
        decidedAt: Date
    ) throws -> DeepDiveDisclosureRecord {
        try DeepDiveDisclosureRecord(
            disclosureVersion: version,
            decision: decision,
            decidedAt: decidedAt,
            contentFingerprint: contentFingerprint,
            dataBoundaryProfileVersion: dataBoundaryProfileVersion
        )
    }

    func state(
        for record: DeepDiveDisclosureRecord?
    ) -> DeepDiveDisclosureRecordState {
        guard let record else {
            return .notPresented
        }
        guard record.disclosureVersion == version,
              record.contentFingerprint == contentFingerprint,
              record.dataBoundaryProfileVersion
                == dataBoundaryProfileVersion
        else {
            return .obsolete(record)
        }
        switch record.decision {
        case .accepted:
            return .accepted(record)
        case .declined:
            return .declined(record)
        }
    }

    private static func semanticFingerprint(
        version: DomainToken,
        profile: DomainToken
    ) -> DomainToken {
        let lines = [version.rawValue]
            + DeepDiveDisclosureSemanticItem.allCases.map(\.rawValue)
            + ["profile:\(profile.rawValue)"]
        let digest = SHA256.hash(
            data: Data(lines.joined(separator: "\n").utf8)
        ).map { String(format: "%02x", $0) }.joined()
        return DomainToken(rawValue: digest)!
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.utf8.count == 64
            && value.unicodeScalars.allSatisfy { scalar in
                switch scalar.value {
                case 48...57, 97...102:
                    true
                default:
                    false
                }
            }
    }
}

struct DeepDiveDisclosureRecord:
    Codable,
    Sendable,
    Equatable
{
    static let schemaVersion = 1

    let schemaVersion: Int
    let disclosureVersion: DomainToken
    let decision: DeepDiveDisclosureDecision
    let decidedAt: Date
    let contentFingerprint: DomainToken
    let dataBoundaryProfileVersion: DomainToken

    init(
        disclosureVersion: DomainToken,
        decision: DeepDiveDisclosureDecision,
        decidedAt: Date,
        contentFingerprint: DomainToken,
        dataBoundaryProfileVersion: DomainToken
    ) throws {
        guard decidedAt.timeIntervalSinceReferenceDate.isFinite,
              disclosureVersion.rawValue.hasPrefix(
                  "deep-dive-disclosure-v"
              ),
              dataBoundaryProfileVersion.rawValue.hasPrefix(
                  "deep-dive-data-boundary-v"
              ),
              contentFingerprint.rawValue.utf8.count == 64,
              contentFingerprint.rawValue.unicodeScalars.allSatisfy({
                  switch $0.value {
                  case 48...57, 97...102:
                      true
                  default:
                      false
                  }
              })
        else {
            throw DeepDiveDisclosureStoreError.invalidRecord
        }
        schemaVersion = Self.schemaVersion
        self.disclosureVersion = disclosureVersion
        self.decision = decision
        self.decidedAt = decidedAt
        self.contentFingerprint = contentFingerprint
        self.dataBoundaryProfileVersion = dataBoundaryProfileVersion
    }

    init(from decoder: Decoder) throws {
        try rejectUnknownCodingKeys(
            decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard try container.decode(Int.self, forKey: .schemaVersion)
            == Self.schemaVersion
        else {
            throw DeepDiveDisclosureStoreError.unsupportedSchema
        }
        try self.init(
            disclosureVersion: container.decode(
                DomainToken.self,
                forKey: .disclosureVersion
            ),
            decision: container.decode(
                DeepDiveDisclosureDecision.self,
                forKey: .decision
            ),
            decidedAt: container.decode(Date.self, forKey: .decidedAt),
            contentFingerprint: container.decode(
                DomainToken.self,
                forKey: .contentFingerprint
            ),
            dataBoundaryProfileVersion: container.decode(
                DomainToken.self,
                forKey: .dataBoundaryProfileVersion
            )
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case disclosureVersion
        case decision
        case decidedAt
        case contentFingerprint
        case dataBoundaryProfileVersion
    }
}

protocol DeepDiveDisclosureRecordStoring: Sendable {
    func load() async throws -> DeepDiveDisclosureRecord?
    func save(_ record: DeepDiveDisclosureRecord) async throws
    func forget() async throws
}

actor DeepDiveDisclosurePreferenceStore:
    DeepDiveDisclosureRecordStoring
{
    static let maximumPayloadBytes = 16 * 1_024

    private let fileURL: URL?
    private var memoryPayload: Data?
    private var failNextMutationForTesting = false

    init(configuration: LocalStoreConfiguration) throws {
        guard !configuration.isMemory else {
            fileURL = nil
            return
        }
        let url = configuration.deepDiveDisclosureURL
        try LocalStorePathPolicy.preparePrivateFile(
            configuration: configuration,
            fileURL: url,
            excludeFromBackup: true
        )
        fileURL = url
    }

    func load() throws -> DeepDiveDisclosureRecord? {
        let payload: Data?
        if let fileURL {
            payload = try readDisclosureBounded(
                from: fileURL,
                maximumPayloadBytes: Self.maximumPayloadBytes
            )
        } else {
            payload = memoryPayload
        }
        guard let payload, !payload.isEmpty else {
            return nil
        }
        guard payload.count <= Self.maximumPayloadBytes else {
            throw DeepDiveDisclosureStoreError.payloadTooLarge
        }
        do {
            return try DomainJSON.decode(
                DeepDiveDisclosureRecord.self,
                from: payload
            )
        } catch DeepDiveDisclosureStoreError.unsupportedSchema {
            throw DeepDiveDisclosureStoreError.unsupportedSchema
        } catch DeepDiveDisclosureStoreError.payloadTooLarge {
            throw DeepDiveDisclosureStoreError.payloadTooLarge
        } catch {
            throw DeepDiveDisclosureStoreError.invalidPayload
        }
    }

    func save(_ record: DeepDiveDisclosureRecord) throws {
        let payload = try DomainJSON.encode(record)
        guard payload.count <= Self.maximumPayloadBytes else {
            throw DeepDiveDisclosureStoreError.payloadTooLarge
        }
        try prepareMutation()
        if let fileURL {
            try writeDisclosureAtomically(payload, to: fileURL)
        } else {
            memoryPayload = payload
        }
    }

    func forget() throws {
        try prepareMutation()
        if let fileURL {
            try writeDisclosureAtomically(Data(), to: fileURL)
        } else {
            memoryPayload = nil
        }
    }

    func _testReplacePayload(_ payload: Data) throws {
        if let fileURL {
            try writeDisclosureAtomically(payload, to: fileURL)
        } else {
            memoryPayload = payload
        }
    }

    func _testFailNextMutation() {
        failNextMutationForTesting = true
    }

    private func prepareMutation() throws {
        if failNextMutationForTesting {
            failNextMutationForTesting = false
            throw DeepDiveDisclosureStoreError.unsafeStorage
        }
    }
}

private func readDisclosureBounded(
    from source: URL,
    maximumPayloadBytes: Int
) throws -> Data {
    let descriptor = open(
        source.path,
        O_RDONLY | O_CLOEXEC | O_NOFOLLOW
    )
    guard descriptor >= 0 else {
        throw DeepDiveDisclosureStoreError.unsafeStorage
    }
    defer { close(descriptor) }

    var before = stat()
    guard fstat(descriptor, &before) == 0,
          before.st_mode & S_IFMT == S_IFREG,
          before.st_uid == geteuid(),
          before.st_nlink == 1,
          before.st_mode & 0o077 == 0,
          before.st_size >= 0
    else {
        throw DeepDiveDisclosureStoreError.unsafeStorage
    }
    guard before.st_size <= off_t(maximumPayloadBytes) else {
        throw DeepDiveDisclosureStoreError.payloadTooLarge
    }

    let expectedCount = Int(before.st_size)
    var payload = Data(count: expectedCount)
    var offset = 0
    while offset < expectedCount {
        let count = payload.withUnsafeMutableBytes { bytes in
            read(
                descriptor,
                bytes.baseAddress!.advanced(by: offset),
                expectedCount - offset
            )
        }
        if count < 0, errno == EINTR {
            continue
        }
        guard count > 0 else {
            throw DeepDiveDisclosureStoreError.unsafeStorage
        }
        offset += count
    }

    var trailingByte: UInt8 = 0
    while true {
        let trailingCount = read(descriptor, &trailingByte, 1)
        if trailingCount < 0, errno == EINTR {
            continue
        }
        guard trailingCount == 0 else {
            if trailingCount > 0 {
                throw DeepDiveDisclosureStoreError.payloadTooLarge
            }
            throw DeepDiveDisclosureStoreError.unsafeStorage
        }
        break
    }

    var after = stat()
    guard fstat(descriptor, &after) == 0,
          after.st_dev == before.st_dev,
          after.st_ino == before.st_ino,
          after.st_gen == before.st_gen,
          after.st_nlink == before.st_nlink,
          after.st_size == before.st_size,
          after.st_mtimespec.tv_sec == before.st_mtimespec.tv_sec,
          after.st_mtimespec.tv_nsec == before.st_mtimespec.tv_nsec,
          after.st_ctimespec.tv_sec == before.st_ctimespec.tv_sec,
          after.st_ctimespec.tv_nsec == before.st_ctimespec.tv_nsec
    else {
        throw DeepDiveDisclosureStoreError.unsafeStorage
    }
    return payload
}

private func writeDisclosureAtomically(
    _ data: Data,
    to destination: URL
) throws {
    let temporary = destination.deletingLastPathComponent().appending(
        path: ".stornaut-disclosure-\(UUID().uuidString).tmp"
    )
    defer { try? FileManager.default.removeItem(at: temporary) }
    do {
        try LocalStorePathPolicy.createPrivateFileExclusive(temporary)
        let descriptor = open(
            temporary.path,
            O_WRONLY | O_TRUNC | O_CLOEXEC | O_NOFOLLOW
        )
        guard descriptor >= 0 else {
            throw DeepDiveDisclosureStoreError.unsafeStorage
        }
        defer { close(descriptor) }
        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let count = write(
                    descriptor,
                    bytes.baseAddress!.advanced(by: offset),
                    bytes.count - offset
                )
                guard count > 0 else {
                    throw DeepDiveDisclosureStoreError.unsafeStorage
                }
                offset += count
            }
        }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableTemporary = temporary
        try mutableTemporary.setResourceValues(values)
        guard fsync(descriptor) == 0,
              rename(temporary.path, destination.path) == 0
        else {
            throw DeepDiveDisclosureStoreError.unsafeStorage
        }
    } catch let error as DeepDiveDisclosureStoreError {
        throw error
    } catch {
        throw DeepDiveDisclosureStoreError.unsafeStorage
    }
}
