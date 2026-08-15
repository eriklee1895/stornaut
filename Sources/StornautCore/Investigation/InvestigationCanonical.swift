import Foundation

indirect enum InvestigationCanonicalValue: Sendable, Equatable {
    case null
    case bool(Bool)
    case unsigned(UInt64)
    case signed(Int64)
    case text(String)
    case bytes(Data)
    case array([InvestigationCanonicalValue])
    case record([InvestigationCanonicalField])
}

struct InvestigationCanonicalField: Sendable, Equatable {
    let tag: UInt16
    let value: InvestigationCanonicalValue

    init(tag: UInt16, value: InvestigationCanonicalValue) {
        self.tag = tag
        self.value = value
    }
}

enum InvestigationCanonicalError: Error, Sendable, Equatable {
    case inputTooLarge
    case invalidMagic
    case domainMismatch
    case rootMustBeRecord
    case nonCanonicalRecord
    case invalidType
    case invalidUTF8
    case invalidLength
    case invalidCount
    case maximumDepthExceeded
    case trailingBytes
}

enum StornautInvestigationCanonicalV1 {
    private static let magic = Data("STORNAUT-INV-CANON-1\0".utf8)
    private static let maximumDepth = 8

    static func encode(
        domain: String,
        root: InvestigationCanonicalValue
    ) throws -> Data {
        guard case .record = root else {
            throw InvestigationCanonicalError.rootMustBeRecord
        }

        var encoded = magic
        try append(.text(domain), to: &encoded, depth: 0)
        try append(root, to: &encoded, depth: 0)
        return encoded
    }

    static func decode(
        _ data: Data,
        expectedDomain: String,
        maximumInputBytes: Int
    ) throws -> InvestigationCanonicalValue {
        guard maximumInputBytes >= 0, data.count <= maximumInputBytes else {
            throw InvestigationCanonicalError.inputTooLarge
        }

        var cursor = CanonicalByteCursor(data: data)
        guard try cursor.read(count: magic.count) == magic else {
            throw InvestigationCanonicalError.invalidMagic
        }
        guard case let .text(domain) = try readValue(
            from: &cursor,
            depth: 0
        ) else {
            throw InvestigationCanonicalError.invalidType
        }
        guard domain == expectedDomain else {
            throw InvestigationCanonicalError.domainMismatch
        }

        let root = try readValue(from: &cursor, depth: 0)
        guard case .record = root else {
            throw InvestigationCanonicalError.rootMustBeRecord
        }
        guard cursor.isAtEnd else {
            throw InvestigationCanonicalError.trailingBytes
        }
        return root
    }

    static func appendValueForSchema(
        _ value: InvestigationCanonicalValue,
        to output: inout Data
    ) throws {
        try append(value, to: &output, depth: 0)
    }

    private static func append(
        _ value: InvestigationCanonicalValue,
        to output: inout Data,
        depth: Int
    ) throws {
        guard depth <= maximumDepth else {
            throw InvestigationCanonicalError.maximumDepthExceeded
        }

        switch value {
        case .null:
            output.append(0x00)
        case let .bool(value):
            output.append(value ? 0x02 : 0x01)
        case let .unsigned(value):
            output.append(0x10)
            output.appendBigEndian(value)
        case let .signed(value):
            output.append(0x11)
            output.appendBigEndian(UInt64(bitPattern: value))
        case let .text(value):
            let bytes = Data(value.utf8)
            output.append(0x20)
            output.appendBigEndian(UInt64(bytes.count))
            output.append(bytes)
        case let .bytes(value):
            output.append(0x21)
            output.appendBigEndian(UInt64(value.count))
            output.append(value)
        case let .array(values):
            output.append(0x30)
            output.appendBigEndian(UInt64(values.count))
            for element in values {
                var encodedElement = Data()
                try append(element, to: &encodedElement, depth: depth + 1)
                output.appendBigEndian(UInt64(encodedElement.count))
                output.append(encodedElement)
            }
        case let .record(fields):
            try validateRecord(fields)
            output.append(0x40)
            output.appendBigEndian(UInt64(fields.count))
            for field in fields {
                output.appendBigEndian(field.tag)
                var encodedValue = Data()
                try append(
                    field.value,
                    to: &encodedValue,
                    depth: depth + 1
                )
                output.appendBigEndian(UInt64(encodedValue.count))
                output.append(encodedValue)
            }
        }
    }

    private static func readValue(
        from cursor: inout CanonicalByteCursor,
        depth: Int
    ) throws -> InvestigationCanonicalValue {
        guard depth <= maximumDepth else {
            throw InvestigationCanonicalError.maximumDepthExceeded
        }

        switch try cursor.readByte() {
        case 0x00:
            return .null
        case 0x01:
            return .bool(false)
        case 0x02:
            return .bool(true)
        case 0x10:
            return .unsigned(try cursor.readUInt64())
        case 0x11:
            return .signed(Int64(bitPattern: try cursor.readUInt64()))
        case 0x20:
            let bytes = try cursor.readCountedData()
            guard let value = String(data: bytes, encoding: .utf8) else {
                throw InvestigationCanonicalError.invalidUTF8
            }
            return .text(value)
        case 0x21:
            return .bytes(try cursor.readCountedData())
        case 0x30:
            let count = try cursor.readCollectionCount(minimumBytesPerValue: 9)
            var values: [InvestigationCanonicalValue] = []
            values.reserveCapacity(count)
            for _ in 0..<count {
                values.append(
                    try readFramedValue(from: &cursor, depth: depth + 1)
                )
            }
            return .array(values)
        case 0x40:
            let count = try cursor.readCollectionCount(
                minimumBytesPerValue: 11
            )
            var fields: [InvestigationCanonicalField] = []
            fields.reserveCapacity(count)
            for _ in 0..<count {
                let tag = try cursor.readUInt16()
                let value = try readFramedValue(
                    from: &cursor,
                    depth: depth + 1
                )
                fields.append(.init(tag: tag, value: value))
            }
            try validateRecord(fields)
            return .record(fields)
        default:
            throw InvestigationCanonicalError.invalidType
        }
    }

    private static func readFramedValue(
        from cursor: inout CanonicalByteCursor,
        depth: Int
    ) throws -> InvestigationCanonicalValue {
        let length = try cursor.readLength()
        let end = try cursor.endIndex(advancingBy: length)
        var framed = cursor.withLimit(end)
        let value = try readValue(from: &framed, depth: depth)
        guard framed.isAtEnd else {
            throw InvestigationCanonicalError.invalidLength
        }
        cursor.advance(to: end)
        return value
    }

    private static func validateRecord(
        _ fields: [InvestigationCanonicalField]
    ) throws {
        var previous: UInt16?
        for field in fields {
            if let previous, field.tag <= previous {
                throw InvestigationCanonicalError.nonCanonicalRecord
            }
            previous = field.tag
        }
    }
}

private struct CanonicalByteCursor {
    let data: Data
    private(set) var index: Data.Index
    private let limit: Data.Index

    init(data: Data) {
        self.data = data
        index = data.startIndex
        limit = data.endIndex
    }

    private init(data: Data, index: Data.Index, limit: Data.Index) {
        self.data = data
        self.index = index
        self.limit = limit
    }

    var isAtEnd: Bool {
        index == limit
    }

    var remainingCount: Int {
        data.distance(from: index, to: limit)
    }

    mutating func readByte() throws -> UInt8 {
        guard index < limit else {
            throw InvestigationCanonicalError.invalidLength
        }
        let byte = data[index]
        data.formIndex(after: &index)
        return byte
    }

    mutating func readUInt16() throws -> UInt16 {
        var value: UInt16 = 0
        for _ in 0..<2 {
            value = (value << 8) | UInt16(try readByte())
        }
        return value
    }

    mutating func readUInt64() throws -> UInt64 {
        var value: UInt64 = 0
        for _ in 0..<8 {
            value = (value << 8) | UInt64(try readByte())
        }
        return value
    }

    mutating func readLength() throws -> Int {
        let raw = try readUInt64()
        guard let length = Int(exactly: raw), length <= remainingCount else {
            throw InvestigationCanonicalError.invalidLength
        }
        return length
    }

    mutating func readCountedData() throws -> Data {
        try read(count: readLength())
    }

    mutating func readCollectionCount(
        minimumBytesPerValue: Int
    ) throws -> Int {
        let raw = try readUInt64()
        guard let count = Int(exactly: raw),
              count <= remainingCount / minimumBytesPerValue
        else {
            throw InvestigationCanonicalError.invalidCount
        }
        return count
    }

    mutating func read(count: Int) throws -> Data {
        let end = try endIndex(advancingBy: count)
        let result = Data(data[index..<end])
        index = end
        return result
    }

    func endIndex(advancingBy count: Int) throws -> Data.Index {
        guard count >= 0,
              let end = data.index(
                index,
                offsetBy: count,
                limitedBy: limit
              ),
              end <= limit
        else {
            throw InvestigationCanonicalError.invalidLength
        }
        return end
    }

    func withLimit(_ end: Data.Index) -> CanonicalByteCursor {
        CanonicalByteCursor(data: data, index: index, limit: end)
    }

    mutating func advance(to newIndex: Data.Index) {
        index = newIndex
    }
}

private extension Data {
    mutating func appendBigEndian(_ value: UInt16) {
        append(UInt8(truncatingIfNeeded: value >> 8))
        append(UInt8(truncatingIfNeeded: value))
    }

    mutating func appendBigEndian(_ value: UInt64) {
        for shift in stride(from: 56, through: 0, by: -8) {
            append(UInt8(truncatingIfNeeded: value >> UInt64(shift)))
        }
    }
}
