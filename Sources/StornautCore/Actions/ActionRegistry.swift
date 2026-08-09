import Foundation

public struct RegisteredActionInvocation: Sendable, Equatable {
    public let id: String
    public let mode: RegisteredActionMode
    public let executableURL: URL
    public let arguments: [String]
    public let environment: [String: String]
    public let timeout: Duration
    public let standardOutputLimit: Int
    public let standardErrorLimit: Int

    public init(
        id: String,
        mode: RegisteredActionMode,
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        timeout: Duration,
        standardOutputLimit: Int,
        standardErrorLimit: Int
    ) {
        self.id = id
        self.mode = mode
        self.executableURL = executableURL
        self.arguments = arguments
        self.environment = environment
        self.timeout = timeout
        self.standardOutputLimit = standardOutputLimit
        self.standardErrorLimit = standardErrorLimit
    }
}

public struct RegisteredActionDefinition: Sendable, Equatable {
    public typealias ArgumentResolver = @Sendable (
        RegisteredActionMode
    ) -> [String]?

    public let id: String
    public let executableURL: URL
    public let environment: [String: String]
    public let timeout: Duration
    public let standardOutputLimit: Int
    public let standardErrorLimit: Int
    private let argumentResolver: ArgumentResolver

    public init(
        id: String,
        executableURL: URL,
        environment: [String: String],
        timeout: Duration,
        standardOutputLimit: Int,
        standardErrorLimit: Int,
        arguments: @escaping ArgumentResolver
    ) {
        self.id = id
        self.executableURL = executableURL
        self.environment = environment
        self.timeout = timeout
        self.standardOutputLimit = standardOutputLimit
        self.standardErrorLimit = standardErrorLimit
        argumentResolver = arguments
    }

    public static func == (
        lhs: RegisteredActionDefinition,
        rhs: RegisteredActionDefinition
    ) -> Bool {
        lhs.id == rhs.id
            && lhs.executableURL == rhs.executableURL
            && lhs.environment == rhs.environment
            && lhs.timeout == rhs.timeout
            && lhs.standardOutputLimit == rhs.standardOutputLimit
            && lhs.standardErrorLimit == rhs.standardErrorLimit
            && RegisteredActionMode.allCases.allSatisfy {
                lhs.argumentResolver($0) == rhs.argumentResolver($0)
            }
    }

    public static func fakeCleaner(
        executableURL: URL,
        timeout: Duration = .seconds(2)
    ) -> RegisteredActionDefinition {
        RegisteredActionDefinition(
            id: "fixture.fake-cleaner",
            executableURL: executableURL,
            environment: [
                "LANG": "C",
                "LC_ALL": "C",
                "PATH": "/usr/bin:/bin",
            ],
            timeout: timeout,
            standardOutputLimit: 16_384,
            standardErrorLimit: 4_096
        ) { mode in
            switch mode {
            case .success:
                ["success"]
            case .dryRun:
                ["dry-run"]
            case .timeout:
                ["timeout"]
            case .partialFailure:
                ["partial-failure"]
            }
        }
    }

    func resolve(
        _ request: RegisteredActionRequest
    ) throws -> RegisteredActionInvocation {
        let standardizedExecutableURL = executableURL.standardizedFileURL
        guard executableURL.isFileURL,
              executableURL.baseURL != nil
                || executableURL.path.hasPrefix("/"),
              standardizedExecutableURL == executableURL,
              FileManager.default.isExecutableFile(atPath: executableURL.path),
              let arguments = argumentResolver(request.mode)
        else {
            throw ActionRegistryError.invalidDefinition
        }
        return RegisteredActionInvocation(
            id: id,
            mode: request.mode,
            executableURL: executableURL,
            arguments: arguments,
            environment: environment,
            timeout: timeout,
            standardOutputLimit: standardOutputLimit,
            standardErrorLimit: standardErrorLimit
        )
    }
}

public enum ActionRegistryError: Error, Sendable, Equatable {
    case duplicateActionID
    case unregisteredAction
    case invalidDefinition
}

public struct ActionRegistry: Sendable {
    private let definitions: [String: RegisteredActionDefinition]
    private let hasDuplicateIDs: Bool

    public init(definitions: [RegisteredActionDefinition]) {
        var indexed: [String: RegisteredActionDefinition] = [:]
        var duplicate = false
        for definition in definitions {
            if indexed.updateValue(definition, forKey: definition.id) != nil {
                duplicate = true
            }
        }
        self.definitions = indexed
        hasDuplicateIDs = duplicate
    }

    public func resolve(
        _ request: RegisteredActionRequest
    ) throws -> RegisteredActionInvocation {
        guard !hasDuplicateIDs else {
            throw ActionRegistryError.duplicateActionID
        }
        guard let definition = definitions[request.id] else {
            throw ActionRegistryError.unregisteredAction
        }
        return try definition.resolve(request)
    }
}
