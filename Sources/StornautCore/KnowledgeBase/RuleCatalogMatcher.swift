import Foundation

public struct RuleCatalogMatcher: Sendable {
    private let entries: [RuleMatcherEntry]

    public init(catalog: RuleCatalog) {
        entries = catalog.rules.map { rule in
            return RuleMatcherEntry(
                rule: rule,
                exactPattern: normalizedComponents(
                    rule.match.pathPattern.rawValue,
                    caseSensitive: true
                ),
                insensitivePattern: normalizedComponents(
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
        }
    }

    public func matchingRules(
        relativePath: String,
        kind: RuleExpectedKind,
        caseSensitive: Bool = true
    ) throws -> [CompiledRule] {
        guard isValidCandidatePath(relativePath) else {
            throw RuleCatalogError.invalidPattern
        }
        let path = normalizedComponents(
            relativePath,
            caseSensitive: caseSensitive
        )
        return entries.compactMap { entry in
            let pattern = caseSensitive
                ? entry.exactPattern
                : entry.insensitivePattern
            let exclusions = caseSensitive
                ? entry.exactExclusions
                : entry.insensitiveExclusions
            return entry.rule.match.expectedKind == kind
                && glob(
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

private struct RuleMatcherEntry: Sendable {
    let rule: CompiledRule
    let exactPattern: [String]
    let insensitivePattern: [String]
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
