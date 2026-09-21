import Foundation

struct StrictJSONAuditor {
    private let bytes: [UInt8]
    private var index = 0

    init(data: Data) {
        bytes = Array(data)
    }

    mutating func validate() throws {
        skipWhitespace()
        try parseValue(depth: 0)
        skipWhitespace()
        guard index == bytes.count else {
            throw RuleCompilerError.invalidJSON
        }
    }

    private mutating func parseValue(depth: Int) throws {
        guard depth <= RuleSourceCompiler.maximumNestingDepth,
              index < bytes.count
        else {
            if depth > RuleSourceCompiler.maximumNestingDepth {
                throw RuleCompilerError.nestingTooDeep(
                    limit: RuleSourceCompiler.maximumNestingDepth
                )
            }
            throw RuleCompilerError.invalidJSON
        }
        switch bytes[index] {
        case 0x7B:
            try parseObject(depth: depth + 1)
        case 0x5B:
            try parseArray(depth: depth + 1)
        case 0x22:
            _ = try parseString()
        case 0x74:
            try consumeLiteral("true")
        case 0x66:
            try consumeLiteral("false")
        case 0x6E:
            try consumeLiteral("null")
        case 0x2D, 0x30...0x39:
            try parseNumber()
        default:
            throw RuleCompilerError.invalidJSON
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
                throw RuleCompilerError.invalidJSON
            }
            let key = try parseString()
            guard keys.insert(key).inserted else {
                throw RuleCompilerError.duplicateKey(key)
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

    private mutating func parseString() throws -> String {
        try consume(0x22)
        var output: [UInt8] = []
        while index < bytes.count {
            let byte = bytes[index]
            index += 1
            if byte == 0x22 {
                guard output.count <= RuleSourceCompiler.maximumScalarBytes,
                      let value = String(bytes: output, encoding: .utf8)
                else {
                    throw RuleCompilerError.scalarTooLarge(
                        limit: RuleSourceCompiler.maximumScalarBytes
                    )
                }
                return value
            }
            if byte == 0x5C {
                guard index < bytes.count else {
                    throw RuleCompilerError.invalidJSON
                }
                let escape = bytes[index]
                index += 1
                switch escape {
                case 0x22, 0x5C, 0x2F:
                    output.append(escape)
                case 0x62:
                    output.append(0x08)
                case 0x66:
                    output.append(0x0C)
                case 0x6E:
                    output.append(0x0A)
                case 0x72:
                    output.append(0x0D)
                case 0x74:
                    output.append(0x09)
                case 0x75:
                    let scalar = try parseUnicodeEscape()
                    output.append(contentsOf: String(scalar).utf8)
                default:
                    throw RuleCompilerError.invalidJSON
                }
            } else {
                guard byte >= 0x20 else {
                    throw RuleCompilerError.invalidJSON
                }
                output.append(byte)
            }
            guard output.count <= RuleSourceCompiler.maximumScalarBytes else {
                throw RuleCompilerError.scalarTooLarge(
                    limit: RuleSourceCompiler.maximumScalarBytes
                )
            }
        }
        throw RuleCompilerError.invalidJSON
    }

    private mutating func parseUnicodeEscape() throws -> UnicodeScalar {
        guard index + 4 <= bytes.count else {
            throw RuleCompilerError.invalidJSON
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
                throw RuleCompilerError.invalidJSON
            }
        }
        guard !(0xD800...0xDFFF).contains(value),
              let scalar = UnicodeScalar(value)
        else {
            throw RuleCompilerError.invalidJSON
        }
        return scalar
    }

    private mutating func parseNumber() throws {
        let start = index
        if consumeIf(0x2D), index >= bytes.count {
            throw RuleCompilerError.invalidJSON
        }
        if consumeIf(0x30) {
            if index < bytes.count, (0x30...0x39).contains(bytes[index]) {
                throw RuleCompilerError.invalidJSON
            }
        } else {
            guard consumeDigits() else {
                throw RuleCompilerError.invalidJSON
            }
        }
        if consumeIf(0x2E) {
            guard consumeDigits() else {
                throw RuleCompilerError.invalidJSON
            }
        }
        if index < bytes.count,
           (bytes[index] == 0x65 || bytes[index] == 0x45)
        {
            index += 1
            _ = consumeIf(0x2B) || consumeIf(0x2D)
            guard consumeDigits() else {
                throw RuleCompilerError.invalidJSON
            }
        }
        guard index - start <= 128 else {
            throw RuleCompilerError.scalarTooLarge(limit: 128)
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
        let literalBytes = Array(literal.utf8)
        guard index + literalBytes.count <= bytes.count,
              Array(bytes[index..<(index + literalBytes.count)])
                == literalBytes
        else {
            throw RuleCompilerError.invalidJSON
        }
        index += literalBytes.count
    }

    private mutating func consume(_ byte: UInt8) throws {
        guard consumeIf(byte) else {
            throw RuleCompilerError.invalidJSON
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
