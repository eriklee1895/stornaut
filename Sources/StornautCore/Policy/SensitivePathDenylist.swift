import Foundation

public enum SensitivePathReason: String, Codable, Sendable, Equatable {
    case sensitiveDirectory
    case secretFile
}

public enum SensitivePathDecision: Sendable, Equatable {
    case allowed
    case denied(SensitivePathReason)
}

public struct SensitivePathDenylist: Sendable {
    public static let publicConfigurationKeys: Set<String> = []

    private let homeURL: URL

    public init(
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        homeURL = homeDirectoryURL.standardizedFileURL.resolvingSymlinksInPath()
    }

    public func evaluate(_ url: URL) -> SensitivePathDecision {
        let canonicalURL = url.standardizedFileURL.resolvingSymlinksInPath()
        let globalComponents = canonicalURL.pathComponents.map(
            denylistComponent
        )
        if containsSensitiveGlobalDirectory(globalComponents) {
            return .denied(.sensitiveDirectory)
        }
        if let filename = globalComponents.last,
           isSecretFilename(filename)
        {
            return .denied(.secretFile)
        }

        let relativeComponents = relativeComponents(
            canonicalURL: canonicalURL,
            homeURL: homeURL
        )
        guard let relativeComponents else {
            return .allowed
        }

        if isSensitiveDirectory(relativeComponents) {
            return .denied(.sensitiveDirectory)
        }
        if let filename = relativeComponents.last,
           isSecretFilename(filename)
        {
            return .denied(.secretFile)
        }
        return .allowed
    }
}

private func relativeComponents(
    canonicalURL: URL,
    homeURL: URL
) -> [String]? {
    let caseSensitive = (
        try? homeURL.resourceValues(
            forKeys: [.volumeSupportsCaseSensitiveNamesKey]
        ).volumeSupportsCaseSensitiveNames
    ) ?? true
    let homeComponents = containmentComponents(
        homeURL,
        caseSensitive: caseSensitive
    )
    let candidateComponents = containmentComponents(
        canonicalURL,
        caseSensitive: caseSensitive
    )
    guard candidateComponents.count >= homeComponents.count,
          zip(homeComponents, candidateComponents).allSatisfy(==)
    else {
        return nil
    }
    return candidateComponents
        .dropFirst(homeComponents.count)
        .map(denylistComponent)
}

private func isSensitiveDirectory(_ components: [String]) -> Bool {
    guard !components.isEmpty else {
        return false
    }

    let sensitivePrefixes: [[String]] = [
        ["library", "keychains"],
        ["library", "mail"],
        ["library", "messages"],
        ["library", "photos"],
        ["library", "safari"],
        ["library", "application support", "1password"],
        ["library", "application support", "bitwarden"],
        ["library", "application support", "lastpass"],
        ["library", "application support", "google", "chrome"],
        ["library", "application support", "microsoft edge"],
        ["library", "application support", "bravesoftware", "brave-browser"],
        ["library", "application support", "arc", "user data"],
        ["library", "application support", "firefox", "profiles"],
        ["pictures", "photos library.photoslibrary"],
    ]
    return sensitivePrefixes.contains { prefix in
        components.count >= prefix.count
            && zip(prefix, components).allSatisfy(==)
    }
}

private func containsSensitiveGlobalDirectory(
    _ components: [String]
) -> Bool {
    if components.contains(".ssh")
        || components.contains(".gnupg")
        || components.contains(".aws")
        || components.contains(".kube")
        || components.contains(".azure")
    {
        return true
    }
    let sensitiveSequences: [[String]] = [
        ["library", "keychains"],
        [".config", "gcloud"],
        [".config", "gh"],
        [".config", "op"],
        [".config", "1password"],
        [".config", "bitwarden"],
        [".docker"],
    ]
    return sensitiveSequences.contains { sequence in
        components.windows(ofCount: sequence.count).contains(sequence)
    }
}

private func isSecretFilename(_ filename: String) -> Bool {
    let exactNames: Set<String> = [
        ".netrc",
        ".npmrc",
        ".pypirc",
        ".vault-token",
        "application_default_credentials.json",
        "auth.json",
        "credentials",
        "credentials.json",
        ".git-credentials",
        "id_dsa",
        "id_ecdsa",
        "id_ed25519",
        "id_rsa",
        "kubeconfig",
        "secret.json",
        "secrets.json",
        "service-account.json",
        "credentials.tfrc.json",
    ]
    return exactNames.contains(filename)
        || filename == ".env"
        || filename.hasPrefix(".env.")
        || filename.hasSuffix(".env")
        || filename.hasSuffix(".key")
        || filename.hasSuffix(".pem")
        || filename.hasSuffix(".p12")
        || filename.hasSuffix(".pfx")
}

private func containmentComponents(
    _ url: URL,
    caseSensitive: Bool
) -> [String] {
    url.pathComponents.map { component in
        let normalized = component.precomposedStringWithCanonicalMapping
        return caseSensitive
            ? normalized
            : normalized.lowercased(
                with: Locale(identifier: "en_US_POSIX")
            )
    }
}

private func denylistComponent(_ component: String) -> String {
    let decomposed = component.decomposedStringWithCanonicalMapping
    let scalars = decomposed.unicodeScalars.filter {
        !CharacterSet.nonBaseCharacters.contains($0)
    }
    return String(String.UnicodeScalarView(scalars)).lowercased(
        with: Locale(identifier: "en_US_POSIX")
    )
}

private extension Array where Element: Equatable {
    func windows(ofCount count: Int) -> [[Element]] {
        guard count > 0, self.count >= count else {
            return []
        }
        return (0...(self.count - count)).map {
            Array(self[$0..<($0 + count)])
        }
    }
}
