import Foundation

enum StrictDomainJSONError: Error, Sendable, Equatable {
    case invalidJSON
}

enum StrictDomainJSONNumberPolicy: Sendable, Equatable {
    case standardJSON
    case exactInteger64
}

struct StrictDomainJSONAuditor {
    private let data: Data
    private let numberPolicy: StrictDomainJSONNumberPolicy

    init(
        data: Data,
        numberPolicy: StrictDomainJSONNumberPolicy = .standardJSON
    ) {
        self.data = data
        self.numberPolicy = numberPolicy
    }

    func validate() throws {
        try data.withUnsafeBytes { rawBuffer in
            var parser = StrictDomainJSONParser(
                bytes: rawBuffer.bindMemory(to: UInt8.self),
                numberPolicy: numberPolicy
            )
            try parser.validate()
        }
    }
}

private struct StrictDomainJSONParser {
    private static let maximumDepth = 64
    private static let maximumScalarBytes = 16 * 1_048_576

    private let bytes: UnsafeBufferPointer<UInt8>
    private let numberPolicy: StrictDomainJSONNumberPolicy
    private var index = 0

    init(
        bytes: UnsafeBufferPointer<UInt8>,
        numberPolicy: StrictDomainJSONNumberPolicy
    ) {
        self.bytes = bytes
        self.numberPolicy = numberPolicy
    }

    mutating func validate() throws {
        skipWhitespace()
        try parseValue(depth: 0)
        skipWhitespace()
        guard index == bytes.count else {
            throw StrictDomainJSONError.invalidJSON
        }
    }

    private mutating func parseValue(depth: Int) throws {
        guard depth <= Self.maximumDepth, index < bytes.count else {
            throw StrictDomainJSONError.invalidJSON
        }
        switch bytes[index] {
        case 0x7B:
            try parseObject(depth: depth + 1)
        case 0x5B:
            try parseArray(depth: depth + 1)
        case 0x22:
            _ = try parseString(materializing: false)
        case 0x74:
            try consumeLiteral("true")
        case 0x66:
            try consumeLiteral("false")
        case 0x6E:
            try consumeLiteral("null")
        case 0x2D, 0x30...0x39:
            try parseNumber()
        default:
            throw StrictDomainJSONError.invalidJSON
        }
    }

    private mutating func parseObject(depth: Int) throws {
        try consume(0x7B)
        skipWhitespace()
        var keys = Set<String>()
        if consumeIf(0x7D) {
            return
        }
        while true {
            guard index < bytes.count, bytes[index] == 0x22 else {
                throw StrictDomainJSONError.invalidJSON
            }
            guard let key = try parseString(materializing: true) else {
                throw StrictDomainJSONError.invalidJSON
            }
            guard keys.insert(key).inserted else {
                throw StrictDomainJSONError.invalidJSON
            }
            skipWhitespace()
            try consume(0x3A)
            skipWhitespace()
            try parseValue(depth: depth)
            skipWhitespace()
            if consumeIf(0x7D) {
                return
            }
            try consume(0x2C)
            skipWhitespace()
        }
    }

    private mutating func parseArray(depth: Int) throws {
        try consume(0x5B)
        skipWhitespace()
        if consumeIf(0x5D) {
            return
        }
        while true {
            try parseValue(depth: depth)
            skipWhitespace()
            if consumeIf(0x5D) {
                return
            }
            try consume(0x2C)
            skipWhitespace()
        }
    }

    private mutating func parseString(
        materializing: Bool
    ) throws -> String? {
        try consume(0x22)
        var output: [UInt8]? = materializing ? [] : nil
        var scalarByteCount = 0
        while index < bytes.count {
            let byte = bytes[index]
            index += 1
            if byte == 0x22 {
                guard scalarByteCount <= Self.maximumScalarBytes else {
                    throw StrictDomainJSONError.invalidJSON
                }
                guard let output else {
                    return nil
                }
                guard let value = String(bytes: output, encoding: .utf8) else {
                    throw StrictDomainJSONError.invalidJSON
                }
                return value
            }
            if byte == 0x5C {
                guard index < bytes.count else {
                    throw StrictDomainJSONError.invalidJSON
                }
                let escape = bytes[index]
                index += 1
                switch escape {
                case 0x22, 0x5C, 0x2F:
                    output?.append(escape)
                    scalarByteCount += 1
                case 0x62:
                    output?.append(0x08)
                    scalarByteCount += 1
                case 0x66:
                    output?.append(0x0C)
                    scalarByteCount += 1
                case 0x6E:
                    output?.append(0x0A)
                    scalarByteCount += 1
                case 0x72:
                    output?.append(0x0D)
                    scalarByteCount += 1
                case 0x74:
                    output?.append(0x09)
                    scalarByteCount += 1
                case 0x75:
                    let scalarBytes = String(try parseUnicodeEscape()).utf8
                    output?.append(contentsOf: scalarBytes)
                    scalarByteCount += scalarBytes.count
                default:
                    throw StrictDomainJSONError.invalidJSON
                }
            } else {
                guard byte >= 0x20 else {
                    throw StrictDomainJSONError.invalidJSON
                }
                let sequenceStart = index - 1
                if byte >= 0x80 {
                    try consumeUTF8ContinuationBytes(startingWith: byte)
                }
                output?.append(
                    contentsOf: bytes[sequenceStart..<index]
                )
                scalarByteCount += index - sequenceStart
            }
            guard scalarByteCount <= Self.maximumScalarBytes else {
                throw StrictDomainJSONError.invalidJSON
            }
        }
        throw StrictDomainJSONError.invalidJSON
    }

    private mutating func consumeUTF8ContinuationBytes(
        startingWith first: UInt8
    ) throws {
        switch first {
        case 0xC2...0xDF:
            try consumeUTF8Continuation(in: 0x80...0xBF)
        case 0xE0:
            try consumeUTF8Continuation(in: 0xA0...0xBF)
            try consumeUTF8Continuation(in: 0x80...0xBF)
        case 0xE1...0xEC, 0xEE...0xEF:
            try consumeUTF8Continuation(in: 0x80...0xBF)
            try consumeUTF8Continuation(in: 0x80...0xBF)
        case 0xED:
            try consumeUTF8Continuation(in: 0x80...0x9F)
            try consumeUTF8Continuation(in: 0x80...0xBF)
        case 0xF0:
            try consumeUTF8Continuation(in: 0x90...0xBF)
            try consumeUTF8Continuation(in: 0x80...0xBF)
            try consumeUTF8Continuation(in: 0x80...0xBF)
        case 0xF1...0xF3:
            try consumeUTF8Continuation(in: 0x80...0xBF)
            try consumeUTF8Continuation(in: 0x80...0xBF)
            try consumeUTF8Continuation(in: 0x80...0xBF)
        case 0xF4:
            try consumeUTF8Continuation(in: 0x80...0x8F)
            try consumeUTF8Continuation(in: 0x80...0xBF)
            try consumeUTF8Continuation(in: 0x80...0xBF)
        default:
            throw StrictDomainJSONError.invalidJSON
        }
    }

    private mutating func consumeUTF8Continuation(
        in allowedRange: ClosedRange<UInt8>
    ) throws {
        guard index < bytes.count,
              allowedRange.contains(bytes[index])
        else {
            throw StrictDomainJSONError.invalidJSON
        }
        index += 1
    }

    private mutating func parseUnicodeEscape() throws -> UnicodeScalar {
        let first = try parseUnicodeCodeUnit()
        if (0xD800...0xDBFF).contains(first) {
            guard index + 6 <= bytes.count,
                  bytes[index] == 0x5C,
                  bytes[index + 1] == 0x75
            else {
                throw StrictDomainJSONError.invalidJSON
            }
            index += 2
            let second = try parseUnicodeCodeUnit()
            guard (0xDC00...0xDFFF).contains(second) else {
                throw StrictDomainJSONError.invalidJSON
            }
            let scalarValue = 0x1_0000
                + ((first - 0xD800) << 10)
                + (second - 0xDC00)
            guard let scalar = UnicodeScalar(scalarValue) else {
                throw StrictDomainJSONError.invalidJSON
            }
            return scalar
        }
        guard !(0xDC00...0xDFFF).contains(first),
              let scalar = UnicodeScalar(first)
        else {
            throw StrictDomainJSONError.invalidJSON
        }
        return scalar
    }

    private mutating func parseUnicodeCodeUnit() throws -> UInt32 {
        guard index + 4 <= bytes.count else {
            throw StrictDomainJSONError.invalidJSON
        }
        var value: UInt32 = 0
        for _ in 0..<4 {
            value <<= 4
            let byte = bytes[index]
            index += 1
            switch byte {
            case 0x30...0x39:
                value += UInt32(byte - 0x30)
            case 0x41...0x46:
                value += UInt32(byte - 0x41 + 10)
            case 0x61...0x66:
                value += UInt32(byte - 0x61 + 10)
            default:
                throw StrictDomainJSONError.invalidJSON
            }
        }
        return value
    }

    private mutating func parseNumber() throws {
        let start = index
        let isNegative = consumeIf(0x2D)
        if isNegative, index >= bytes.count {
            throw StrictDomainJSONError.invalidJSON
        }
        let digitsStart = index
        if consumeIf(0x30) {
            if index < bytes.count, (0x30...0x39).contains(bytes[index]) {
                throw StrictDomainJSONError.invalidJSON
            }
        } else {
            guard consumeDigits() else {
                throw StrictDomainJSONError.invalidJSON
            }
        }
        let integerEnd = index
        if numberPolicy == .exactInteger64 {
            guard index == bytes.count
                    || bytes[index] != 0x2E
                        && bytes[index] != 0x65
                        && bytes[index] != 0x45
            else {
                throw StrictDomainJSONError.invalidJSON
            }
            try validateExactInteger64(
                digits: bytes[digitsStart..<integerEnd],
                isNegative: isNegative
            )
            return
        }
        if consumeIf(0x2E) {
            guard consumeDigits() else {
                throw StrictDomainJSONError.invalidJSON
            }
        }
        if index < bytes.count,
           bytes[index] == 0x65 || bytes[index] == 0x45
        {
            index += 1
            _ = consumeIf(0x2B) || consumeIf(0x2D)
            guard consumeDigits() else {
                throw StrictDomainJSONError.invalidJSON
            }
        }
        guard index - start <= 128 else {
            throw StrictDomainJSONError.invalidJSON
        }
    }

    private func validateExactInteger64(
        digits: Slice<UnsafeBufferPointer<UInt8>>,
        isNegative: Bool
    ) throws {
        let limit = isNegative
            ? UInt64(Int64.max) + 1
            : UInt64.max
        var value: UInt64 = 0
        for digitByte in digits {
            let multiplication = value.multipliedReportingOverflow(by: 10)
            guard !multiplication.overflow else {
                throw StrictDomainJSONError.invalidJSON
            }
            let addition = multiplication.partialValue.addingReportingOverflow(
                UInt64(digitByte - 0x30)
            )
            guard !addition.overflow, addition.partialValue <= limit else {
                throw StrictDomainJSONError.invalidJSON
            }
            value = addition.partialValue
        }
        if isNegative, value == 0 {
            throw StrictDomainJSONError.invalidJSON
        }
    }

    private mutating func consumeDigits() -> Bool {
        let start = index
        while index < bytes.count, (0x30...0x39).contains(bytes[index]) {
            index += 1
        }
        return index > start
    }

    private mutating func consumeLiteral(_ literal: String) throws {
        for expectedByte in literal.utf8 {
            guard index < bytes.count, bytes[index] == expectedByte else {
                throw StrictDomainJSONError.invalidJSON
            }
            index += 1
        }
    }

    private mutating func consume(_ byte: UInt8) throws {
        guard consumeIf(byte) else {
            throw StrictDomainJSONError.invalidJSON
        }
    }

    private mutating func consumeIf(_ byte: UInt8) -> Bool {
        guard index < bytes.count, bytes[index] == byte else {
            return false
        }
        index += 1
        return true
    }

    private mutating func skipWhitespace() {
        while index < bytes.count,
              bytes[index] == 0x20
                || bytes[index] == 0x09
                || bytes[index] == 0x0A
                || bytes[index] == 0x0D
        {
            index += 1
        }
    }
}
