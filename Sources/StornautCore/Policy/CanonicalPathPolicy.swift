import Foundation

public struct CanonicalPath: Codable, Sendable, Equatable {
    public let url: URL
    public let identity: FileIdentity
}

public enum PathDenialReason: String, Codable, Sendable, Equatable {
    case relativePath
    case outsideAllowedRoots
    case filesystemRoot
    case homeDirectory
    case mountRoot
    case protectedAllowedRoot
    case sensitivePath
    case symbolicLinkLoop
}

public enum PathUnknownReason: String, Codable, Sendable, Equatable {
    case pathDoesNotExist
    case allowedRootUnavailable
    case metadataUnavailable
}

public enum PathDecision: Sendable, Equatable {
    case allowed(CanonicalPath)
    case denied(PathDenialReason)
    case unknown(PathUnknownReason)
}

public struct CanonicalPathPolicy: Sendable {
    public typealias MountRootCheck = @Sendable (URL) -> Bool

    private let homeDirectoryURL: URL
    private let isMountRoot: MountRootCheck
    private let denylist: SensitivePathDenylist

    public init(
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        isMountRoot: @escaping MountRootCheck = CanonicalPathPolicy.defaultMountRootCheck
    ) {
        self.homeDirectoryURL = homeDirectoryURL.standardizedFileURL
        self.isMountRoot = isMountRoot
        denylist = SensitivePathDenylist(homeDirectoryURL: homeDirectoryURL)
    }

    public func evaluate(
        requestedURL: URL,
        allowedRoots: [URL]
    ) -> PathDecision {
        guard requestedURL.isFileURL,
              requestedURL.baseURL != nil || requestedURL.path.hasPrefix("/")
        else {
            return .denied(.relativePath)
        }

        let standardizedRequest = requestedURL.standardizedFileURL
        let canonicalRequest = standardizedRequest.resolvingSymlinksInPath()
        guard canonicalRequest.path != "/" else {
            return .denied(.filesystemRoot)
        }
        guard !samePath(canonicalRequest, homeDirectoryURL.resolvingSymlinksInPath()) else {
            return .denied(.homeDirectory)
        }
        guard !isMountRoot(canonicalRequest) else {
            return .denied(.mountRoot)
        }

        switch denylist.evaluate(canonicalRequest) {
        case .allowed:
            break
        case .denied:
            return .denied(.sensitivePath)
        }

        var canonicalRoots: [(url: URL, identity: FileIdentity)] = []
        for root in allowedRoots {
            guard root.isFileURL,
                  root.baseURL != nil || root.path.hasPrefix("/")
            else {
                continue
            }
            let canonicalRoot = root.standardizedFileURL.resolvingSymlinksInPath()
            guard canonicalRoot.path != "/",
                  !samePath(
                      canonicalRoot,
                      homeDirectoryURL.resolvingSymlinksInPath()
                  ),
                  !isMountRoot(canonicalRoot)
            else {
                return .denied(.protectedAllowedRoot)
            }
            guard let identity = fileIdentity(at: canonicalRoot) else {
                continue
            }
            canonicalRoots.append((canonicalRoot, identity))
        }
        guard !canonicalRoots.isEmpty else {
            return .unknown(.allowedRootUnavailable)
        }
        guard let identity = fileIdentity(at: canonicalRequest) else {
            return FileManager.default.fileExists(atPath: canonicalRequest.path)
                ? .unknown(.metadataUnavailable)
                : .unknown(.pathDoesNotExist)
        }
        guard canonicalRoots.contains(where: {
            contains($0.url, canonicalRequest)
                && $0.identity.device == identity.device
        }) else {
            return .denied(.outsideAllowedRoots)
        }

        return .allowed(CanonicalPath(url: canonicalRequest, identity: identity))
    }

    public static func defaultMountRootCheck(_ url: URL) -> Bool {
        guard url.path != "/" else {
            return true
        }
        guard let identity = fileIdentity(at: url),
              let parentIdentity = fileIdentity(
                  at: url.deletingLastPathComponent().resolvingSymlinksInPath()
              )
        else {
            return false
        }
        return identity.device != parentIdentity.device
    }
}

func fileIdentity(at url: URL) -> FileIdentity? {
    FileIdentity.read(at: url)
}

func unsignedDeviceIdentity(_ device: dev_t) -> UInt64 {
    UInt64(bitPattern: Int64(device))
}

private func contains(_ root: URL, _ candidate: URL) -> Bool {
    let caseSensitive = (
        try? root.resourceValues(
            forKeys: [.volumeSupportsCaseSensitiveNamesKey]
        ).volumeSupportsCaseSensitiveNames
    ) ?? true
    let rootComponents = normalizedComponents(root, caseSensitive: caseSensitive)
    let candidateComponents = normalizedComponents(
        candidate,
        caseSensitive: caseSensitive
    )
    guard candidateComponents.count >= rootComponents.count else {
        return false
    }
    return zip(rootComponents, candidateComponents).allSatisfy(==)
}

private func samePath(_ lhs: URL, _ rhs: URL) -> Bool {
    let caseSensitive = (
        try? lhs.resourceValues(
            forKeys: [.volumeSupportsCaseSensitiveNamesKey]
        ).volumeSupportsCaseSensitiveNames
    ) ?? true
    return normalizedComponents(lhs, caseSensitive: caseSensitive)
        == normalizedComponents(rhs, caseSensitive: caseSensitive)
}

private func normalizedComponents(
    _ url: URL,
    caseSensitive: Bool
) -> [String] {
    url.standardizedFileURL.pathComponents.map {
        let normalized = $0.precomposedStringWithCanonicalMapping
        return caseSensitive
            ? normalized
            : normalized.folding(
                options: [.caseInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
    }
}
