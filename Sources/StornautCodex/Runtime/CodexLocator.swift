import Foundation

public enum CodexDiscoverySource: String, Sendable, Equatable {
    case configured
    case environmentPATH
    case knownCandidate
}

public struct CodexInstallation: Sendable, Equatable {
    public let executableURL: URL
    public let source: CodexDiscoverySource

    public init(executableURL: URL, source: CodexDiscoverySource) {
        self.executableURL = executableURL
        self.source = source
    }
}

public enum CodexUnavailableReason: Sendable, Equatable {
    case invalidConfiguredExecutable(URL)
    case notFound
}

public enum CodexAvailability: Sendable, Equatable {
    case available(CodexInstallation)
    case unavailable(CodexUnavailableReason)

    public var installation: CodexInstallation? {
        guard case let .available(installation) = self else {
            return nil
        }
        return installation
    }
}

public struct CodexLocator: Sendable {
    public static let defaultMaximumPATHEntries = 64
    public static let defaultMaximumKnownCandidates = 16

    private let knownCandidateURLs: [URL]?
    private let maximumPATHEntries: Int
    private let maximumKnownCandidates: Int

    public init(
        knownCandidateURLs: [URL]? = nil,
        maximumPATHEntries: Int = defaultMaximumPATHEntries,
        maximumKnownCandidates: Int = defaultMaximumKnownCandidates
    ) {
        self.knownCandidateURLs = knownCandidateURLs
        self.maximumPATHEntries = max(0, maximumPATHEntries)
        self.maximumKnownCandidates = max(0, maximumKnownCandidates)
    }

    public func locate(
        configuredURL: URL?,
        environment: [String: String]
    ) async -> CodexAvailability {
        if let configuredURL {
            guard let executableURL = canonicalExecutableURL(for: configuredURL) else {
                return .unavailable(
                    .invalidConfiguredExecutable(configuredURL.standardizedFileURL)
                )
            }
            return .available(
                CodexInstallation(executableURL: executableURL, source: .configured)
            )
        }

        for directoryURL in pathDirectories(from: environment["PATH"]) {
            let candidateURL = directoryURL.appending(path: "codex")
            if let executableURL = canonicalExecutableURL(for: candidateURL) {
                return .available(
                    CodexInstallation(
                        executableURL: executableURL,
                        source: .environmentPATH
                    )
                )
            }
        }

        let candidates = knownCandidateURLs ?? defaultKnownCandidateURLs(environment: environment)
        for candidateURL in candidates.prefix(maximumKnownCandidates) {
            if let executableURL = canonicalExecutableURL(for: candidateURL) {
                return .available(
                    CodexInstallation(
                        executableURL: executableURL,
                        source: .knownCandidate
                    )
                )
            }
        }

        return .unavailable(.notFound)
    }

    private func pathDirectories(from path: String?) -> [URL] {
        guard let path else {
            return []
        }

        return path
            .split(separator: ":", omittingEmptySubsequences: true)
            .prefix(maximumPATHEntries)
            .compactMap { component in
                let directory = String(component)
                guard directory.hasPrefix("/") else {
                    return nil
                }
                return URL(filePath: directory, directoryHint: .isDirectory)
            }
    }

    private func defaultKnownCandidateURLs(environment: [String: String]) -> [URL] {
        guard
            let homePath = environment["HOME"],
            homePath.hasPrefix("/")
        else {
            return []
        }

        let homeURL = URL(filePath: homePath, directoryHint: .isDirectory)
        return [
            homeURL.appending(path: ".npm-global/bin/codex"),
            homeURL.appending(path: ".local/bin/codex"),
            homeURL.appending(path: ".bun/bin/codex"),
            homeURL.appending(path: ".volta/bin/codex"),
        ]
    }

    private func canonicalExecutableURL(for candidateURL: URL) -> URL? {
        guard candidateURL.isFileURL, candidateURL.path.hasPrefix("/") else {
            return nil
        }

        let fileManager = FileManager.default
        let standardizedCandidate = candidateURL.standardizedFileURL

        let aliasResolvedURL: URL
        do {
            let values = try standardizedCandidate.resourceValues(
                forKeys: [.isAliasFileKey]
            )
            if values.isAliasFile == true {
                aliasResolvedURL = try URL(
                    resolvingAliasFileAt: standardizedCandidate,
                    options: [.withoutUI, .withoutMounting]
                )
            } else {
                aliasResolvedURL = standardizedCandidate
            }
        } catch {
            return nil
        }

        let canonicalURL = aliasResolvedURL
            .resolvingSymlinksInPath()
            .standardizedFileURL

        guard
            fileManager.isExecutableFile(atPath: canonicalURL.path),
            let values = try? canonicalURL.resourceValues(
                forKeys: [.isRegularFileKey, .isDirectoryKey]
            ),
            values.isRegularFile == true,
            values.isDirectory != true
        else {
            return nil
        }

        return canonicalURL
    }
}
