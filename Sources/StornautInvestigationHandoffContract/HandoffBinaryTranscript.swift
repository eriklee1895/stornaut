import CryptoKit
import Foundation

package enum InvestigationHandoffContractError:
    Error,
    Sendable,
    Equatable
{
    case invalidValue
    case invalidEncoding
    case sizeLimitExceeded
    case incompleteInput
}

package struct InvestigationHandoffSHA256:
    Sendable,
    Hashable
{
    package static let byteCount = 32

    package let rawBytes: Data

    package init(rawBytes: Data) throws {
        guard rawBytes.count == Self.byteCount else {
            throw InvestigationHandoffContractError.invalidValue
        }
        self.rawBytes = rawBytes
    }

    package init(lowercaseHex: String) throws {
        let characters = Array(lowercaseHex.utf8)
        guard characters.count == Self.byteCount * 2 else {
            throw InvestigationHandoffContractError.invalidValue
        }
        var bytes = Data()
        bytes.reserveCapacity(Self.byteCount)
        for index in stride(from: 0, to: characters.count, by: 2) {
            guard
                let high = handoffHexNibble(characters[index]),
                let low = handoffHexNibble(characters[index + 1])
            else {
                throw InvestigationHandoffContractError.invalidValue
            }
            bytes.append((high << 4) | low)
        }
        try self.init(rawBytes: bytes)
    }

    package static func hashing(_ data: Data) -> Self {
        Self(validatedRawBytes: Data(SHA256.hash(data: data)))
    }

    package var lowercaseHex: String {
        rawBytes.map { String(format: "%02x", $0) }.joined()
    }

    private init(validatedRawBytes: Data) {
        precondition(validatedRawBytes.count == Self.byteCount)
        rawBytes = validatedRawBytes
    }
}

package struct InvestigationHandoffUTCMicroseconds:
    Sendable,
    Hashable,
    Comparable
{
    package let rawValue: Int64

    package init(rawValue: Int64) throws {
        guard rawValue > 0 else {
            throw InvestigationHandoffContractError.invalidValue
        }
        self.rawValue = rawValue
    }

    package init(timeIntervalSince1970: TimeInterval) throws {
        guard
            timeIntervalSince1970.isFinite,
            timeIntervalSince1970 > 0
        else {
            throw InvestigationHandoffContractError.invalidValue
        }
        let scaled = timeIntervalSince1970 * 1_000_000
        guard
            scaled.isFinite,
            scaled >= 1,
            scaled < Double(Int64.max)
        else {
            throw InvestigationHandoffContractError.invalidValue
        }
        try self.init(rawValue: Int64(scaled.rounded(.down)))
    }

    package var timeIntervalSince1970: TimeInterval {
        TimeInterval(rawValue) / 1_000_000
    }

    package static func < (
        lhs: InvestigationHandoffUTCMicroseconds,
        rhs: InvestigationHandoffUTCMicroseconds
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

package enum InvestigationHandoffScenario:
    UInt32,
    Sendable,
    CaseIterable
{
    case success = 1
    case cancellation = 2
    case timeout = 3
    case invalidEnvelope = 4
    case identityMismatch = 5
    case transportLoss = 6
    case lifecycleRecovery = 7
    case artifactCleanupFailure = 8

    package var name: String {
        switch self {
        case .success: "success"
        case .cancellation: "cancellation"
        case .timeout: "timeout"
        case .invalidEnvelope: "invalidEnvelope"
        case .identityMismatch: "identityMismatch"
        case .transportLoss: "transportLoss"
        case .lifecycleRecovery: "lifecycleRecovery"
        case .artifactCleanupFailure: "artifactCleanupFailure"
        }
    }
}

package enum HandoffBinaryTranscript {
    package static let magic: UInt32 = 0x5354_4e43
    package static let version: UInt32 = 1
    package static let maximumDomainByteCount = 64

    package static func encode(
        domain: String,
        businessFields: [Data],
        maximumByteCount: Int
    ) throws -> Data {
        let domainBytes = Data(domain.utf8)
        guard
            handoffValidDomain(domainBytes),
            maximumByteCount > 0,
            businessFields.count <= Int(UInt16.max) - 1
        else {
            throw InvestigationHandoffContractError.invalidValue
        }

        var encoded = Data()
        encoded.reserveCapacity(min(maximumByteCount, 4_096))
        encoded.append(handoffData(magic))
        try handoffAppendTaggedField(
            tag: 0,
            payload: domainBytes,
            to: &encoded,
            maximumByteCount: maximumByteCount
        )
        try handoffAppendTaggedField(
            tag: 1,
            payload: handoffData(version),
            to: &encoded,
            maximumByteCount: maximumByteCount
        )
        for (index, field) in businessFields.enumerated() {
            guard !field.isEmpty else {
                throw InvestigationHandoffContractError.invalidValue
            }
            try handoffAppendTaggedField(
                tag: UInt16(index + 2),
                payload: field,
                to: &encoded,
                maximumByteCount: maximumByteCount
            )
        }
        guard encoded.count <= maximumByteCount else {
            throw InvestigationHandoffContractError.sizeLimitExceeded
        }
        return encoded
    }

    package static func decode(
        _ data: Data,
        expectedDomain: String,
        expectedBusinessFieldByteCounts: [ClosedRange<Int>],
        maximumByteCount: Int
    ) throws -> [Data] {
        let expectedDomainBytes = Data(expectedDomain.utf8)
        guard
            handoffValidDomain(expectedDomainBytes),
            maximumByteCount > 0,
            data.count <= maximumByteCount,
            expectedBusinessFieldByteCounts.count
                <= Int(UInt16.max) - 1
        else {
            throw InvestigationHandoffContractError.sizeLimitExceeded
        }

        var cursor = HandoffBinaryCursor(data: data)
        guard try cursor.readUInt32() == magic else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        let domain = try cursor.readTaggedField(
            expectedTag: 0,
            admittedByteCounts: 1...maximumDomainByteCount
        )
        guard
            handoffValidDomain(domain),
            domain == expectedDomainBytes
        else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        let versionBytes = try cursor.readTaggedField(
            expectedTag: 1,
            admittedByteCounts: 4...4
        )
        var versionCursor = HandoffBinaryCursor(data: versionBytes)
        guard
            try versionCursor.readUInt32() == version,
            versionCursor.isAtEnd
        else {
            throw InvestigationHandoffContractError.invalidEncoding
        }

        var fields: [Data] = []
        fields.reserveCapacity(expectedBusinessFieldByteCounts.count)
        for (index, admittedByteCounts)
            in expectedBusinessFieldByteCounts.enumerated()
        {
            guard
                admittedByteCounts.lowerBound > 0,
                admittedByteCounts.upperBound <= maximumByteCount
            else {
                throw InvestigationHandoffContractError.invalidValue
            }
            fields.append(try cursor.readTaggedField(
                expectedTag: UInt16(index + 2),
                admittedByteCounts: admittedByteCounts
            ))
        }
        guard cursor.isAtEnd else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        return fields
    }
}

struct HandoffBinaryCursor {
    private let data: Data
    private(set) var offset = 0

    init(data: Data) {
        self.data = data
    }

    var remainingByteCount: Int {
        data.count - offset
    }

    var isAtEnd: Bool {
        offset == data.count
    }

    mutating func read(count: Int) throws -> Data {
        guard
            count >= 0,
            offset >= 0,
            offset <= data.count,
            count <= data.count - offset
        else {
            throw InvestigationHandoffContractError.incompleteInput
        }
        let range = offset..<(offset + count)
        offset += count
        return data.subdata(in: range)
    }

    mutating func readUInt8() throws -> UInt8 {
        let bytes = try read(count: 1)
        return bytes[bytes.startIndex]
    }

    mutating func readUInt16() throws -> UInt16 {
        let bytes = try read(count: 2)
        return bytes.reduce(UInt16(0)) {
            ($0 << 8) | UInt16($1)
        }
    }

    mutating func readUInt32() throws -> UInt32 {
        let bytes = try read(count: 4)
        return bytes.reduce(UInt32(0)) {
            ($0 << 8) | UInt32($1)
        }
    }

    mutating func readUInt64() throws -> UInt64 {
        let bytes = try read(count: 8)
        return bytes.reduce(UInt64(0)) {
            ($0 << 8) | UInt64($1)
        }
    }

    mutating func readInt64() throws -> Int64 {
        Int64(bitPattern: try readUInt64())
    }

    mutating func readTaggedField(
        expectedTag: UInt16,
        admittedByteCounts: ClosedRange<Int>
    ) throws -> Data {
        guard try readUInt16() == expectedTag else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        let length = try readUInt32()
        guard
            let count = Int(exactly: length),
            admittedByteCounts.contains(count),
            count <= remainingByteCount
        else {
            throw InvestigationHandoffContractError.sizeLimitExceeded
        }
        return try read(count: count)
    }
}

func handoffData(_ value: UInt8) -> Data {
    Data([value])
}

func handoffData(_ value: UInt16) -> Data {
    Data([
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value),
    ])
}

func handoffData(_ value: UInt32) -> Data {
    Data([
        UInt8(truncatingIfNeeded: value >> 24),
        UInt8(truncatingIfNeeded: value >> 16),
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value),
    ])
}

func handoffData(_ value: UInt64) -> Data {
    Data([
        UInt8(truncatingIfNeeded: value >> 56),
        UInt8(truncatingIfNeeded: value >> 48),
        UInt8(truncatingIfNeeded: value >> 40),
        UInt8(truncatingIfNeeded: value >> 32),
        UInt8(truncatingIfNeeded: value >> 24),
        UInt8(truncatingIfNeeded: value >> 16),
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value),
    ])
}

func handoffData(_ value: Int64) -> Data {
    handoffData(UInt64(bitPattern: value))
}

func handoffData(_ value: UUID) -> Data {
    var bytes = value.uuid
    return withUnsafeBytes(of: &bytes) { Data($0) }
}

func handoffUUID(_ data: Data) throws -> UUID {
    guard data.count == 16 else {
        throw InvestigationHandoffContractError.invalidEncoding
    }
    var bytes: uuid_t = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    let copied = withUnsafeMutableBytes(of: &bytes) { destination in
        data.copyBytes(to: destination)
    }
    guard copied == 16 else {
        throw InvestigationHandoffContractError.invalidEncoding
    }
    return UUID(uuid: bytes)
}

func handoffUUIDIsNonzero(_ value: UUID) -> Bool {
    handoffData(value).contains { $0 != 0 }
}

func handoffDecodeUInt32(_ data: Data) throws -> UInt32 {
    var cursor = HandoffBinaryCursor(data: data)
    let value = try cursor.readUInt32()
    guard cursor.isAtEnd else {
        throw InvestigationHandoffContractError.invalidEncoding
    }
    return value
}

func handoffDecodeUInt64(_ data: Data) throws -> UInt64 {
    var cursor = HandoffBinaryCursor(data: data)
    let value = try cursor.readUInt64()
    guard cursor.isAtEnd else {
        throw InvestigationHandoffContractError.invalidEncoding
    }
    return value
}

func handoffDecodeInt64(_ data: Data) throws -> Int64 {
    var cursor = HandoffBinaryCursor(data: data)
    let value = try cursor.readInt64()
    guard cursor.isAtEnd else {
        throw InvestigationHandoffContractError.invalidEncoding
    }
    return value
}

private func handoffAppendTaggedField(
    tag: UInt16,
    payload: Data,
    to output: inout Data,
    maximumByteCount: Int
) throws {
    guard
        !payload.isEmpty,
        let length = UInt32(exactly: payload.count),
        output.count <= maximumByteCount,
        6 <= maximumByteCount - output.count,
        payload.count <= maximumByteCount - output.count - 6
    else {
        throw InvestigationHandoffContractError.sizeLimitExceeded
    }
    output.append(handoffData(tag))
    output.append(handoffData(length))
    output.append(payload)
}

private func handoffValidDomain(_ data: Data) -> Bool {
    (1...HandoffBinaryTranscript.maximumDomainByteCount).contains(data.count)
        && data.allSatisfy { $0 > 0 && $0 < 0x80 }
}

private func handoffHexNibble(_ character: UInt8) -> UInt8? {
    switch character {
    case 0x30...0x39:
        character - 0x30
    case 0x61...0x66:
        character - 0x61 + 10
    default:
        nil
    }
}
