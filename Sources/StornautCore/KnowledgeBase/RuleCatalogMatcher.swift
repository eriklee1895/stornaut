import Foundation

public struct RuleCatalogMatcher: Sendable {
    private let exactLiteralEntries: [RuleMatcherKey: [RuleMatcherEntry]]
    private let insensitiveLiteralEntries: [RuleMatcherKey: [RuleMatcherEntry]]
    private let wildcardEntries: [RuleExpectedKind: [RuleMatcherEntry]]

    public init(catalog: RuleCatalog) {
        var exact: [RuleMatcherKey: [RuleMatcherEntry]] = [:]
        var insensitive: [RuleMatcherKey: [RuleMatcherEntry]] = [:]
        var wildcard: [RuleExpectedKind: [RuleMatcherEntry]] = [:]
        for rule in catalog.rules {
            let entry = RuleMatcherEntry(
                rule: rule,
                exactPattern: normalizedComponents(
                    rule.match.pathPattern.rawValue,
                    caseSensitive: true
                ),
                insensitivePattern: normalizedComponents(
                    rule.match.pathPattern.rawValue,
                    caseSensitive: false
                ),
                exactTerminalLiteral: terminalLiteral(
                    rule.match.pathPattern.rawValue,
                    caseSensitive: true
                ),
                insensitiveTerminalLiteral: terminalLiteral(
                    rule.match.pathPattern.rawValue,
                    caseSensitive: false
                ),
                exactExclusions: rule.excludedPatterns.map {
                    normalizedComponents(
                        $0.rawValue,
                        caseSensitive: true
                    )
                },
                insensitiveExclusions: rule.excludedPatterns.map {
                    normalizedComponents(
                        $0.rawValue,
                        caseSensitive: false
                    )
                }
            )
            if let literal = entry.exactTerminalLiteral,
               let insensitiveLiteral = entry.insensitiveTerminalLiteral
            {
                exact[
                    RuleMatcherKey(
                        kind: rule.match.expectedKind,
                        terminalLiteral: literal
                    ),
                    default: []
                ].append(entry)
                insensitive[
                    RuleMatcherKey(
                        kind: rule.match.expectedKind,
                        terminalLiteral: insensitiveLiteral
                    ),
                    default: []
                ].append(entry)
            } else {
                wildcard[rule.match.expectedKind, default: []]
                    .append(entry)
            }
        }
        exactLiteralEntries = exact
        insensitiveLiteralEntries = insensitive
        wildcardEntries = wildcard
    }

    public func matchingRules(
        relativePath: String,
        kind: RuleExpectedKind,
        caseSensitive: Bool = true
    ) throws -> [CompiledRule] {
        guard isValidCandidatePath(relativePath) else {
            throw RuleCatalogError.invalidPattern
        }
        let terminal = normalizedTerminalComponent(
            relativePath,
            caseSensitive: caseSensitive
        )
        let key = RuleMatcherKey(
            kind: kind,
            terminalLiteral: terminal
        )
        let literalEntries = caseSensitive
            ? exactLiteralEntries[key, default: []]
            : insensitiveLiteralEntries[key, default: []]
        let candidates = literalEntries
            + wildcardEntries[kind, default: []]
        guard !candidates.isEmpty else {
            return []
        }
        let path = normalizedComponents(
            relativePath,
            caseSensitive: caseSensitive
        )
        return candidates.compactMap { entry in
            let pattern = caseSensitive
                ? entry.exactPattern
                : entry.insensitivePattern
            let terminalLiteral = caseSensitive
                ? entry.exactTerminalLiteral
                : entry.insensitiveTerminalLiteral
            let exclusions = caseSensitive
                ? entry.exactExclusions
                : entry.insensitiveExclusions
            if let terminalLiteral,
               path.last != terminalLiteral
            {
                return nil
            }
            return glob(
                    pattern,
                    matches: path
                )
                && !exclusions.contains {
                    glob($0, matches: path)
                }
                ? entry.rule
                : nil
        }
    }
}

private struct RuleMatcherKey: Hashable, Sendable {
    let kind: RuleExpectedKind
    let terminalLiteral: String
}

private struct RuleMatcherEntry: Sendable {
    let rule: CompiledRule
    let exactPattern: [String]
    let insensitivePattern: [String]
    let exactTerminalLiteral: String?
    let insensitiveTerminalLiteral: String?
    let exactExclusions: [[String]]
    let insensitiveExclusions: [[String]]
}

private struct RuleMatchState: Hashable {
    let patternIndex: Int
    let pathIndex: Int
}

private func isValidCandidatePath(_ path: String) -> Bool {
    guard !path.isEmpty,
          path.utf8.count <= 16_384,
          !path.hasPrefix("/"),
          !path.hasSuffix("/"),
          !path.contains("//"),
          !path.contains("\\"),
          !path.contains("*"),
          !path.contains("?"),
          !path.contains("["),
          !path.contains("]"),
          !path.contains("\0"),
          !path.unicodeScalars.contains(where: {
              CharacterSet.controlCharacters.contains($0)
          })
    else {
        return false
    }
    let components = path.split(
        separator: "/",
        omittingEmptySubsequences: false
    )
    return components.count <= 256 && components.allSatisfy {
        !$0.isEmpty && $0 != "." && $0 != ".." && $0.utf8.count <= 255
    }
}

private func glob(
    _ patternComponents: [String],
    matches pathComponents: [String]
) -> Bool {
    var memo: [RuleMatchState: Bool] = [:]
    func match(_ patternIndex: Int, _ pathIndex: Int) -> Bool {
        let state = RuleMatchState(
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

private func normalizedComponents(
    _ path: String,
    caseSensitive: Bool
) -> [String] {
    path.split(separator: "/", omittingEmptySubsequences: false).map {
        let normalized = String($0).precomposedStringWithCanonicalMapping
        return caseSensitive
            ? normalized
            : normalized.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
    }
}

private func normalizedTerminalComponent(
    _ path: String,
    caseSensitive: Bool
) -> String {
    let start = path.lastIndex(of: "/").map {
        path.index(after: $0)
    } ?? path.startIndex
    let component = path[start...]
    let normalized = String(component)
        .precomposedStringWithCanonicalMapping
    return caseSensitive
        ? normalized
        : normalized.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
}

private func terminalLiteral(
    _ pattern: String,
    caseSensitive: Bool
) -> String? {
    guard let last = normalizedComponents(
        pattern,
        caseSensitive: caseSensitive
    ).last,
          last != "*",
          last != "**"
    else {
        return nil
    }
    return last
}
