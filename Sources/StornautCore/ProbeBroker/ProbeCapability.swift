public enum ProbeCapability: String, CaseIterable, Codable, Sendable {
    case diskSnapshot
    case directorySummary
    case largestChildren
    case safeTextSnippet

    public var requiredReadLevel: ProbeReadLevel {
        switch self {
        case .diskSnapshot, .directorySummary, .largestChildren:
            .level0
        case .safeTextSnippet:
            .level1
        }
    }
}

public enum ProbeReadLevel: Int, Codable, Comparable, Sendable {
    case level0
    case level1
    case level2

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
