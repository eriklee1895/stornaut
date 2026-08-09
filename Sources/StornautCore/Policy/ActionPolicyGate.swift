import Foundation

public struct ActionPolicyContext: Sendable, Equatable {
    public let allowedRoots: [URL]
    public let activeURLs: [URL]

    public init(allowedRoots: [URL], activeURLs: [URL]) {
        self.allowedRoots = allowedRoots
        self.activeURLs = activeURLs
    }
}

public enum ActionPolicyError: Error, Sendable, Equatable {
    case filesystemRoot
    case homeDirectory
    case mountRoot
    case symbolicLink
    case sensitivePath
    case activePath
    case outsideAllowedRoots
    case identityChanged
    case missingPath
    case unregisteredAction
    case invalidRegisteredAction
}

public struct ActionPreflightToken: Sendable, Equatable {
    public let action: CleanupAction
    public let registeredInvocation: RegisteredActionInvocation?
    let executableIdentity: ActionFileIdentity?

    init(
        action: CleanupAction,
        registeredInvocation: RegisteredActionInvocation?,
        executableIdentity: ActionFileIdentity?
    ) {
        self.action = action
        self.registeredInvocation = registeredInvocation
        self.executableIdentity = executableIdentity
    }
}

public struct ActionPolicyGate: Sendable {
    public typealias MountRootCheck = @Sendable (URL) -> Bool

    private let registry: ActionRegistry
    private let homeDirectoryURL: URL
    private let isMountRoot: MountRootCheck
    private let denylist: SensitivePathDenylist

    public init(
        registry: ActionRegistry = ActionRegistry(definitions: []),
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        isMountRoot: @escaping MountRootCheck =
            CanonicalPathPolicy.defaultMountRootCheck
    ) {
        self.registry = registry
        self.homeDirectoryURL = homeDirectoryURL.standardizedFileURL
            .resolvingSymlinksInPath()
        self.isMountRoot = isMountRoot
        denylist = SensitivePathDenylist(
            homeDirectoryURL: homeDirectoryURL
        )
    }

    public func preflight(
        _ action: CleanupAction,
        context: ActionPolicyContext
    ) throws -> ActionPreflightToken {
        switch action {
        case let .moveToTrash(pathAction):
            try validate(pathAction, context: context)
            return ActionPreflightToken(
                action: action,
                registeredInvocation: nil,
                executableIdentity: nil
            )
        case let .runRegisteredAction(request):
            let invocation: RegisteredActionInvocation
            do {
                invocation = try registry.resolve(request)
            } catch ActionRegistryError.unregisteredAction {
                throw ActionPolicyError.unregisteredAction
            } catch {
                throw ActionPolicyError.invalidRegisteredAction
            }
            guard let identity = ActionFileIdentity.read(
                at: invocation.executableURL
            ), identity.isRegularFile else {
                throw ActionPolicyError.invalidRegisteredAction
            }
            return ActionPreflightToken(
                action: action,
                registeredInvocation: invocation,
                executableIdentity: identity
            )
        }
    }

    public func revalidate(
        _ token: ActionPreflightToken,
        context: ActionPolicyContext
    ) throws -> CleanupAction {
        switch token.action {
        case let .moveToTrash(pathAction):
            try validate(pathAction, context: context)
        case let .runRegisteredAction(request):
            let invocation: RegisteredActionInvocation
            do {
                invocation = try registry.resolve(request)
            } catch ActionRegistryError.unregisteredAction {
                throw ActionPolicyError.unregisteredAction
            } catch {
                throw ActionPolicyError.invalidRegisteredAction
            }
            guard invocation == token.registeredInvocation,
                  ActionFileIdentity.read(at: invocation.executableURL)
                    == token.executableIdentity
            else {
                throw ActionPolicyError.identityChanged
            }
        }
        return token.action
    }

    private func validate(
        _ pathAction: PathAction,
        context: ActionPolicyContext
    ) throws {
        guard pathAction.targetURL.isFileURL,
              pathAction.targetURL.baseURL != nil
                || pathAction.targetURL.path.hasPrefix("/")
        else {
            throw ActionPolicyError.outsideAllowedRoots
        }
        let standardizedURL = pathAction.targetURL.standardizedFileURL
        guard standardizedURL.path != "/" else {
            throw ActionPolicyError.filesystemRoot
        }
        if isMountRoot(standardizedURL) {
            throw ActionPolicyError.mountRoot
        }

        guard let observedIdentity = ActionFileIdentity.read(
            at: standardizedURL
        ) else {
            throw ActionPolicyError.missingPath
        }
        if observedIdentity.isSymbolicLink {
            throw ActionPolicyError.symbolicLink
        }

        let canonicalURL = standardizedURL.resolvingSymlinksInPath()
        if sameActionPath(canonicalURL, homeDirectoryURL) {
            throw ActionPolicyError.homeDirectory
        }
        if case .denied = denylist.evaluate(canonicalURL) {
            throw ActionPolicyError.sensitivePath
        }
        if context.activeURLs.contains(where: { activeURL in
            let canonicalActiveURL = activeURL.standardizedFileURL
                .resolvingSymlinksInPath()
            return actionPathContains(canonicalURL, canonicalActiveURL)
                || actionPathContains(canonicalActiveURL, canonicalURL)
        }) {
            throw ActionPolicyError.activePath
        }

        let allowed = context.allowedRoots.contains { root in
            let canonicalRoot = root.standardizedFileURL
                .resolvingSymlinksInPath()
            guard canonicalRoot.path != "/",
                  !sameActionPath(canonicalRoot, homeDirectoryURL),
                  !isMountRoot(root.standardizedFileURL),
                  let rootIdentity = ActionFileIdentity.read(at: canonicalRoot)
            else {
                return false
            }
            return rootIdentity.device == observedIdentity.device
                && actionPathContains(canonicalRoot, canonicalURL)
        }
        guard allowed else {
            throw ActionPolicyError.outsideAllowedRoots
        }
        guard observedIdentity == pathAction.expectedIdentity else {
            throw ActionPolicyError.identityChanged
        }
    }
}

private func actionPathContains(_ root: URL, _ candidate: URL) -> Bool {
    let caseSensitive = (
        try? root.resourceValues(
            forKeys: [.volumeSupportsCaseSensitiveNamesKey]
        ).volumeSupportsCaseSensitiveNames
    ) ?? true
    let rootComponents = actionPathComponents(
        root,
        caseSensitive: caseSensitive
    )
    let candidateComponents = actionPathComponents(
        candidate,
        caseSensitive: caseSensitive
    )
    guard candidateComponents.count >= rootComponents.count else {
        return false
    }
    return zip(rootComponents, candidateComponents).allSatisfy(==)
}

private func sameActionPath(_ lhs: URL, _ rhs: URL) -> Bool {
    let caseSensitive = (
        try? lhs.resourceValues(
            forKeys: [.volumeSupportsCaseSensitiveNamesKey]
        ).volumeSupportsCaseSensitiveNames
    ) ?? true
    return actionPathComponents(lhs, caseSensitive: caseSensitive)
        == actionPathComponents(rhs, caseSensitive: caseSensitive)
}

private func actionPathComponents(
    _ url: URL,
    caseSensitive: Bool
) -> [String] {
    url.standardizedFileURL.pathComponents.map { component in
        let normalized = component.precomposedStringWithCanonicalMapping
        return caseSensitive
            ? normalized
            : normalized.folding(
                options: [.caseInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
    }
}
