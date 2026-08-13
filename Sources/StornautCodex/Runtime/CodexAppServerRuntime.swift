import Foundation

protocol CodexRuntimeAuthRefreshProviding: Sendable {
    func refresh() throws -> CodexRuntimeAuthProjection
}

struct CodexSelectedRuntimeSkill: Sendable, Equatable {
    let name: String
    let path: URL
}

struct CodexCommandIdentityRequirement: Sendable, Equatable {
    let commands: Set<String>
    let allowedSources: Set<CodexCommandExecutionSource>
}

struct CodexAppServerRuntimeRequest: Sendable, Equatable {
    let projectedAuthSourceURL: URL
    let runtimeHomeURL: URL
    let workingDirectoryURL: URL
    let prompt: String
    let outputSchema: JSONValue
    let maximumPromptBytes: Int
    let maximumSchemaBytes: Int
    let maximumInputLineBytes: Int
    let capabilityOutputMarkers: [String: String]
    let capabilityCommandRequirements:
        [String: CodexCommandIdentityRequirement]
    let expectedImageURL: URL?
    let childAgentOutputMarkers: [String: String]
    let selectedRuntimeSkill: CodexSelectedRuntimeSkill?
    let verifiesRawWebSearchCompletion: Bool
    let finalizationPrompt: String?

    init(
        projectedAuthSourceURL: URL,
        runtimeHomeURL: URL,
        workingDirectoryURL: URL,
        prompt: String,
        outputSchema: JSONValue,
        maximumPromptBytes: Int = 256 * 1_024,
        maximumSchemaBytes: Int = 256 * 1_024,
        maximumInputLineBytes: Int = 2 * 1_024 * 1_024,
        capabilityOutputMarkers: [String: String] = [:],
        capabilityCommandRequirements:
            [String: CodexCommandIdentityRequirement] = [:],
        expectedImageURL: URL? = nil,
        childAgentOutputMarkers: [String: String] = [:],
        selectedRuntimeSkill: CodexSelectedRuntimeSkill? = nil,
        verifiesRawWebSearchCompletion: Bool = false,
        finalizationPrompt: String? = nil
    ) {
        self.projectedAuthSourceURL = projectedAuthSourceURL
        self.runtimeHomeURL = runtimeHomeURL
        self.workingDirectoryURL = workingDirectoryURL
        self.prompt = prompt
        self.outputSchema = outputSchema
        self.maximumPromptBytes = maximumPromptBytes
        self.maximumSchemaBytes = maximumSchemaBytes
        self.maximumInputLineBytes = maximumInputLineBytes
        self.capabilityOutputMarkers = capabilityOutputMarkers
        self.capabilityCommandRequirements =
            capabilityCommandRequirements
        self.expectedImageURL = expectedImageURL
        self.childAgentOutputMarkers = childAgentOutputMarkers
        self.selectedRuntimeSkill = selectedRuntimeSkill
        self.verifiesRawWebSearchCompletion =
            verifiesRawWebSearchCompletion
        self.finalizationPrompt = finalizationPrompt
    }
}

enum CodexAppServerRuntimeStatus: Sendable, Equatable {
    case ready
    case configuring
    case running
    case completed
    case failed
}

enum CodexSanitizedUpstreamErrorCategory:
    String,
    Sendable,
    Equatable
{
    case contextWindowExceeded
    case sessionBudgetExceeded
    case usageLimitExceeded
    case serverOverloaded
    case cyberPolicy
    case httpConnectionFailed
    case responseStreamConnectionFailed
    case internalServerError
    case unauthorized
    case badRequest
    case threadRollbackFailed
    case sandboxError
    case responseStreamDisconnected
    case responseTooManyFailedAttempts
    case activeTurnNotSteerable
    case other
    case unclassified
}

struct CodexSanitizedUpstreamError: Sendable, Equatable {
    let category: CodexSanitizedUpstreamErrorCategory
    let code: Int?
    let willRetry: Bool
}

enum CodexAppServerRuntimeError: Error, Sendable, Equatable {
    case invalidRequest
    case invalidState
    case inputLimitExceeded
    case invalidMessage
    case unexpectedResponse(reasonKey: String)
    case unexpectedRequest
    case unexpectedNotification(reasonKey: String)
    case unexpectedItem(type: String)
    case identityMismatch(reasonKey: String)
    case authenticationRefreshBlocked
    case upstreamError(CodexSanitizedUpstreamError)
    case turnFailed(reasonKey: String)
}

struct CodexAppServerObservation: Sendable, Equatable {
    let notificationMethods: [String]
    let itemTypes: [String]
    let finalAgentMessage: String?
    let capabilityObservations: [CodexCapabilityObservation]
    let upstreamErrors: [CodexSanitizedUpstreamError]
    let commandIdentityEligibleCount: Int
    let commandOutputDeltaCount: Int
    let commandAggregatedOutputCount: Int

    init(
        notificationMethods: [String],
        itemTypes: [String],
        finalAgentMessage: String?,
        capabilityObservations: [CodexCapabilityObservation] = [],
        upstreamErrors: [CodexSanitizedUpstreamError] = [],
        commandIdentityEligibleCount: Int = 0,
        commandOutputDeltaCount: Int = 0,
        commandAggregatedOutputCount: Int = 0
    ) {
        self.notificationMethods = notificationMethods
        self.itemTypes = itemTypes
        self.finalAgentMessage = finalAgentMessage
        self.capabilityObservations = capabilityObservations
        self.upstreamErrors = upstreamErrors
        self.commandIdentityEligibleCount =
            commandIdentityEligibleCount
        self.commandOutputDeltaCount = commandOutputDeltaCount
        self.commandAggregatedOutputCount =
            commandAggregatedOutputCount
    }

    func mergingEvidence(
        from companion: CodexAppServerObservation
    ) -> Self {
        CodexAppServerObservation(
            notificationMethods: Array(
                Set(notificationMethods)
                    .union(companion.notificationMethods)
            ).sorted(),
            itemTypes: Array(
                Set(itemTypes).union(companion.itemTypes)
            ).sorted(),
            finalAgentMessage: finalAgentMessage,
            capabilityObservations: Array(
                Set(capabilityObservations)
                    .union(companion.capabilityObservations)
            ).sorted {
                String(reflecting: $0) < String(reflecting: $1)
            },
            upstreamErrors: Array(
                (upstreamErrors + companion.upstreamErrors).prefix(5)
            ),
            commandIdentityEligibleCount:
                min(
                    commandIdentityEligibleCount
                        + companion.commandIdentityEligibleCount,
                    32
                ),
            commandOutputDeltaCount:
                min(
                    commandOutputDeltaCount
                        + companion.commandOutputDeltaCount,
                    32
                ),
            commandAggregatedOutputCount:
                min(
                    commandAggregatedOutputCount
                        + companion.commandAggregatedOutputCount,
                    32
                )
        )
    }
}

enum CodexCommandExecutionSource:
    String,
    Sendable,
    Equatable,
    Hashable
{
    case agent
    case userShell
    case unifiedExecStartup
    case unifiedExecInteraction
}

enum CodexCapabilityObservation:
    Sendable,
    Equatable,
    Hashable
{
    case command(
        source: CodexCommandExecutionSource,
        succeeded: Bool,
        matchedMarkerIDs: [String]
    )
    case webSearchStarted
    case webSearchCompleted
    case imageViewStarted
    case imageViewCompleted
    case runtimeSkillSelected
    case subagentSpawnStarted
    case subagentSpawnCompleted(receiverCount: Int)
    case subagentResultObserved
}

final class CodexAppServerRuntime: @unchecked Sendable {
    private static let provider =
        CodexRuntimeProvider.openAI
    private static let maximumChildThreads = 8
    private static let maximumRetryableStreamErrors = 5

    private enum Phase {
        case ready
        case awaitingInitialize
        case awaitingLogin
        case awaitingThread
        case awaitingTurn
        case running
        case completed
        case failed
    }

    private struct ChildThreadState {
        var settingsValidated = false
        var turnID: String?
    }

    private struct CommandStreamState {
        let source: CodexCommandExecutionSource
        let eligibleMarkerIDs: Set<String>
        var markerProgress: [String: Int]
        var matchedMarkerIDs: Set<String>
    }

    private struct MarkerDefinition {
        let token: [UInt8]
        let failure: [Int]

        init(_ value: String) {
            token = Array(value.utf8)
            var table = [Int](repeating: 0, count: token.count)
            var prefixLength = 0
            if token.count > 1 {
                for index in 1..<token.count {
                    while
                        prefixLength > 0,
                        token[index] != token[prefixLength]
                    {
                        prefixLength = table[prefixLength - 1]
                    }
                    if token[index] == token[prefixLength] {
                        prefixLength += 1
                    }
                    table[index] = prefixLength
                }
            }
            failure = table
        }
    }

    private static let allowedStreamingNotifications: Set<String> = [
        "item/agentMessage/delta",
        "item/commandExecution/outputDelta",
        "item/commandExecution/terminalInteraction",
        "item/plan/delta",
        "item/reasoning/summaryPartAdded",
        "item/reasoning/summaryTextDelta",
        "thread/status/changed",
        "thread/tokenUsage/updated",
        "turn/plan/updated",
    ]
    private static let allowedItemTypes: Set<String> = [
        "agentMessage",
        "collabAgentToolCall",
        "commandExecution",
        "imageView",
        "plan",
        "reasoning",
        "sleep",
        "userMessage",
        "webSearch",
    ]
    private static let allowedChildItemTypes: Set<String> = [
        "agentMessage",
        "commandExecution",
        "plan",
        "reasoning",
        "userMessage",
    ]
    private static let allowedFinalizationItemTypes: Set<String> = [
        "agentMessage",
        "reasoning",
        "userMessage",
    ]

    private let request: CodexAppServerRuntimeRequest
    private let capabilityMarkerDefinitions:
        [String: MarkerDefinition]
    private var authProjection: CodexRuntimeAuthProjection
    private let refreshProvider:
        (any CodexRuntimeAuthRefreshProviding)?
    private let lock = NSLock()
    private var phase = Phase.ready
    private var threadID: String?
    private var turnID: String?
    private var isFinalizationTurn = false
    private var probeAgentMessageObserved = false
    private var refreshUsed = false
    private var turnSettingsValidated = false
    private var childThreads: [String: ChildThreadState] = [:]
    private var observedNotificationMethods = Set<String>()
    private var observedItemTypes = Set<String>()
    private var observedFinalAgentMessage: String?
    private var observedCapabilities = Set<CodexCapabilityObservation>()
    private var commandStreams: [String: CommandStreamState] = [:]
    private var rawSearchCanonicalStartObserved = false
    private var rawSearchItemCompletionObserved = false
    private var rawSearchResponseCompletionObserved = false
    private var observedUpstreamErrors:
        [CodexSanitizedUpstreamError] = []
    private var commandIdentityEligibleCount = 0
    private var commandOutputDeltaCount = 0
    private var commandAggregatedOutputCount = 0

    init(
        request: CodexAppServerRuntimeRequest,
        authProjection: CodexRuntimeAuthProjection,
        refreshProvider: (any CodexRuntimeAuthRefreshProviding)?
    ) throws {
        guard
            Self.validAbsolutePath(request.runtimeHomeURL),
            Self.validAbsolutePath(request.workingDirectoryURL),
            Self.validAbsolutePath(request.projectedAuthSourceURL),
            request.projectedAuthSourceURL.standardizedFileURL
                == authProjection.sourceURL.standardizedFileURL,
            !pathsOverlap(
                request.runtimeHomeURL,
                request.workingDirectoryURL
            ),
            !request.prompt.isEmpty,
            request.prompt.utf8.count <= request.maximumPromptBytes,
            !request.prompt.utf8.contains(0),
            (
                request.finalizationPrompt.map {
                    !$0.isEmpty
                        && $0.utf8.count <= request.maximumPromptBytes
                        && !$0.utf8.contains(0)
                } ?? true
            ),
            request.maximumPromptBytes > 0,
            request.maximumSchemaBytes > 0,
            request.maximumInputLineBytes > 0,
            request.capabilityOutputMarkers.count <= 32,
            request.capabilityOutputMarkers.keys.allSatisfy(
                Self.validCapabilityMarkerID
            ),
            request.capabilityOutputMarkers.values.allSatisfy(
                Self.validCapabilityToken
            ),
            request.capabilityCommandRequirements.isEmpty
                || Set(request.capabilityCommandRequirements.keys)
                    == Set(request.capabilityOutputMarkers.keys),
            request.capabilityCommandRequirements.values.allSatisfy(
                Self.validCommandRequirement
            ),
            Self.validExpectedImage(
                request.expectedImageURL,
                workingDirectoryURL: request.workingDirectoryURL
            ),
            request.childAgentOutputMarkers.count <= 8,
            request.childAgentOutputMarkers.keys.allSatisfy(
                Self.validCapabilityMarkerID
            ),
            request.childAgentOutputMarkers.values.allSatisfy(
                Self.validCapabilityToken
            ),
            Self.validSelectedRuntimeSkill(
                request.selectedRuntimeSkill,
                runtimeHomeURL: request.runtimeHomeURL
            ),
            Self.isClosedOutputSchema(request.outputSchema),
            let schemaData = try? JSONEncoder().encode(
                request.outputSchema
            ),
            schemaData.count <= request.maximumSchemaBytes
        else {
            throw CodexAppServerRuntimeError.invalidRequest
        }
        self.request = request
        capabilityMarkerDefinitions = request.capabilityOutputMarkers
            .mapValues(MarkerDefinition.init)
        self.authProjection = authProjection
        self.refreshProvider = refreshProvider
    }

    var status: CodexAppServerRuntimeStatus {
        lock.withLock {
            switch phase {
            case .ready:
                .ready
            case .awaitingInitialize, .awaitingLogin,
                 .awaitingThread, .awaitingTurn:
                .configuring
            case .running:
                .running
            case .completed:
                .completed
            case .failed:
                .failed
            }
        }
    }

    var diagnosticPhaseKey: String {
        lock.withLock {
            switch phase {
            case .ready:
                "ready"
            case .awaitingInitialize:
                "awaiting-initialize"
            case .awaitingLogin:
                "awaiting-login"
            case .awaitingThread:
                "awaiting-thread"
            case .awaitingTurn:
                isFinalizationTurn
                    ? "awaiting-finalization"
                    : "awaiting-probe"
            case .running:
                isFinalizationTurn
                    ? "running-finalization"
                    : "running-probe"
            case .completed:
                "completed"
            case .failed:
                "failed"
            }
        }
    }

    var observation: CodexAppServerObservation {
        lock.withLock {
            CodexAppServerObservation(
                notificationMethods: observedNotificationMethods.sorted(),
                itemTypes: observedItemTypes.sorted(),
                finalAgentMessage: observedFinalAgentMessage,
                capabilityObservations: observedCapabilities.sorted {
                    String(reflecting: $0) < String(reflecting: $1)
                },
                upstreamErrors: observedUpstreamErrors,
                commandIdentityEligibleCount:
                    commandIdentityEligibleCount,
                commandOutputDeltaCount: commandOutputDeltaCount,
                commandAggregatedOutputCount:
                    commandAggregatedOutputCount
            )
        }
    }

    func begin() throws -> [Data] {
        try lock.withLock {
            guard phase == .ready else {
                throw CodexAppServerRuntimeError.invalidState
            }
            phase = .awaitingInitialize
            return [
                try encodeLine([
                    "id": .number(1),
                    "method": .string("initialize"),
                    "params": .object([
                        "capabilities": .object([
                            "experimentalApi": .bool(true),
                            "optOutNotificationMethods": .array([
                                .string("item/agentMessage/delta"),
                                .string(
                                    """
                                    item/commandExecution/\
                                    terminalInteraction
                                    """
                                ),
                                .string("item/plan/delta"),
                                .string(
                                    "item/reasoning/summaryPartAdded"
                                ),
                                .string(
                                    "item/reasoning/summaryTextDelta"
                                ),
                                .string("thread/started"),
                                .string("thread/status/changed"),
                                .string("thread/tokenUsage/updated"),
                                .string("turn/plan/updated"),
                            ]),
                        ]),
                        "clientInfo": .object([
                            "name": .string("stornaut"),
                            "title": .string("Stornaut"),
                            "version": .string("1"),
                        ]),
                    ]),
                ]),
            ]
        }
    }

    func receive(_ line: Data) throws -> [Data] {
        try lock.withLock {
            guard phase != .ready, phase != .completed, phase != .failed else {
                throw CodexAppServerRuntimeError.invalidState
            }
            do {
                let object = try decodeLine(line)
                return try process(object)
            } catch {
                phase = .failed
                authProjection.erase()
                throw error
            }
        }
    }

    func eraseCredentials() {
        lock.withLock {
            authProjection.erase()
        }
    }

    private func process(
        _ object: [String: JSONValue]
    ) throws -> [Data] {
        if let method = string(object["method"]) {
            if object["id"] != nil {
                return try processServerRequest(
                    method: method,
                    object: object
                )
            }
            return try processNotification(
                method: method,
                object: object
            )
        }
        return try processResponse(object)
    }

    private func processResponse(
        _ object: [String: JSONValue]
    ) throws -> [Data] {
        if let error = object["error"] {
            let errorObject = try requireObject(error)
            let code: String
            if case let .number(value) = errorObject["code"] {
                code = String(value)
            } else {
                code = "unknown"
            }
            throw CodexAppServerRuntimeError.unexpectedResponse(
                reasonKey: responseReasonKey(
                    suffix: "serverError.\(code)"
                )
            )
        }
        switch phase {
        case .awaitingInitialize:
            try requireNumericID(1, object: object)
            let result = try requireObject(object["result"])
            guard
                canonicalPath(
                    string(result["codexHome"])
                ) == canonicalPath(request.runtimeHomeURL.path)
            else {
                throw CodexAppServerRuntimeError.identityMismatch(
                    reasonKey: "appServer.initialize.codexHome"
                )
            }
            phase = .awaitingLogin
            return [
                try encodeLine([
                    "method": .string("initialized"),
                ]),
                try loginRequest(),
            ]
        case .awaitingLogin:
            try requireNumericID(2, object: object)
            let result = try requireObject(object["result"])
            guard
                string(result["type"]) == currentCredentials().loginType
            else {
                throw CodexAppServerRuntimeError.unexpectedResponse(
                    reasonKey: "appServer.login.responseShape"
                )
            }
            phase = .awaitingThread
            return [try threadStartRequest()]
        case .awaitingThread:
            try requireNumericID(3, object: object)
            let result = try requireObject(object["result"])
            let thread = try requireObject(result["thread"])
            let instructionSources = try requireArray(
                result["instructionSources"]
            )
            let activePermissionProfile = try requireObject(
                result["activePermissionProfile"]
            )
            guard
                let observedThreadID = boundedIdentifier(
                    string(thread["id"])
                ),
                string(result["model"]) == CodexRuntimeModel.gpt56Luna.rawValue,
                string(result["modelProvider"]) == Self.provider.rawValue,
                string(thread["modelProvider"]) == Self.provider.rawValue,
                string(result["approvalPolicy"]) == "never",
                instructionSources.isEmpty,
                string(activePermissionProfile["id"])
                    == CodexContainmentPolicy.profileName,
                canonicalPath(string(result["cwd"]))
                    == canonicalPath(request.workingDirectoryURL.path),
                threadID == nil || threadID == observedThreadID
            else {
                throw CodexAppServerRuntimeError.identityMismatch(
                    reasonKey: "appServer.thread.response"
                )
            }
            threadID = observedThreadID
            phase = .awaitingTurn
            return [
                try turnStartRequest(
                    threadID: observedThreadID,
                    requestID: 4,
                    prompt: request.prompt,
                    includesOutputSchema: request.finalizationPrompt == nil,
                    includesSelectedSkill: true
                ),
            ]
        case .awaitingTurn:
            try requireNumericID(
                isFinalizationTurn ? 5 : 4,
                object: object
            )
            let result = try requireObject(object["result"])
            let turn = try requireObject(result["turn"])
            guard
                let observedTurnID = boundedIdentifier(
                    string(turn["id"])
                ),
                string(turn["status"]) == "inProgress",
                turnID == nil || turnID == observedTurnID
            else {
                throw CodexAppServerRuntimeError.identityMismatch(
                    reasonKey: "appServer.turn.response"
                )
            }
            turnID = observedTurnID
            phase = .running
            return []
        case .ready, .running, .completed, .failed:
            throw CodexAppServerRuntimeError.unexpectedResponse(
                reasonKey: "appServer.response.unexpectedPhase"
            )
        }
    }

    private func processServerRequest(
        method: String,
        object: [String: JSONValue]
    ) throws -> [Data] {
        guard
            case let .chatGPT(
                _,
                currentAccountID,
                _
            ) = currentCredentials()
        else {
            throw CodexAppServerRuntimeError.unexpectedRequest
        }
        guard
            phase == .running,
            method == "account/chatgptAuthTokens/refresh",
            !refreshUsed,
            let identifier = object["id"],
            validRPCIdentifier(identifier),
            let provider = refreshProvider
        else {
            throw CodexAppServerRuntimeError.unexpectedRequest
        }
        let params = try requireObject(object["params"])
        guard
            string(params["reason"]) == "unauthorized",
            string(params["previousAccountId"])
                == currentAccountID
        else {
            throw CodexAppServerRuntimeError.authenticationRefreshBlocked
        }

        let refreshed: CodexRuntimeAuthProjection
        do {
            refreshed = try provider.refresh()
        } catch {
            throw CodexAppServerRuntimeError.authenticationRefreshBlocked
        }
        guard
            refreshed.sourceIdentity == authProjection.sourceIdentity,
            refreshed.sourceURL.standardizedFileURL
                == request.projectedAuthSourceURL.standardizedFileURL
        else {
            throw CodexAppServerRuntimeError.identityMismatch(
                reasonKey: "appServer.authRefresh.sourceIdentity"
            )
        }
        let credentials = refreshed.withCredentials { $0 }
        guard
            case let .chatGPT(_, refreshedAccountID, _) = credentials,
            refreshedAccountID == currentAccountID
        else {
            throw CodexAppServerRuntimeError.identityMismatch(
                reasonKey: "appServer.authRefresh.accountID"
            )
        }
        refreshUsed = true
        authProjection.erase()
        authProjection = refreshed
        return [
            try encodeLine([
                "id": identifier,
                "result": .object(authObject(credentials)),
            ]),
        ]
    }

    private func processNotification(
        method: String,
        object: [String: JSONValue]
    ) throws -> [Data] {
        var responses: [Data] = []
        switch method {
        case "remoteControl/status/changed":
            let params = try requireObject(object["params"])
            guard
                string(params["status"]) == "disabled",
                params["environmentId"] == .null
            else {
                throw unexpectedNotification(method)
            }
        case "configWarning", "warning":
            throw unexpectedNotification(method)
        case "account/login/completed":
            guard phaseAllowsDelayedAuthNotification else {
                throw CodexAppServerRuntimeError.unexpectedNotification(
                    reasonKey: "appServer.notification.accountLoginCompleted.phase"
                )
            }
            let params = try requireObject(object["params"])
            guard
                bool(params["success"]) == true,
                params["loginId"] == .null,
                params["error"] == .null
            else {
                throw CodexAppServerRuntimeError.unexpectedNotification(
                    reasonKey: "appServer.notification.accountLoginCompleted.success"
                )
            }
        case "account/updated":
            guard phaseAllowsDelayedAuthNotification else {
                throw CodexAppServerRuntimeError.unexpectedNotification(
                    reasonKey: "appServer.notification.accountUpdated.phase"
                )
            }
            let params = try requireObject(object["params"])
            guard let authMode = string(params["authMode"]) else {
                throw CodexAppServerRuntimeError.unexpectedNotification(
                    reasonKey: "appServer.notification.accountUpdated.missingAuthMode"
                )
            }
            guard authMode == currentCredentials().notificationAuthMode else {
                throw CodexAppServerRuntimeError.unexpectedNotification(
                    reasonKey: "appServer.notification.accountUpdated.unsupportedAuthMode"
                )
            }
        case "account/rateLimits/updated":
            guard phase == .running else {
                throw unexpectedNotification(method)
            }
        case "thread/started":
            guard phase == .awaitingThread || phase == .awaitingTurn else {
                throw unexpectedNotification(method)
            }
            let params = try requireObject(object["params"])
            let thread = try requireObject(params["thread"])
            guard
                let observed = boundedIdentifier(string(thread["id"])),
                threadID == nil || threadID == observed
            else {
                throw CodexAppServerRuntimeError.identityMismatch(
                    reasonKey: "appServer.thread.notification"
                )
            }
            threadID = observed
        case "thread/settings/updated":
            guard phase == .awaitingTurn || phase == .running else {
                throw unexpectedNotification(method)
            }
            let params = try requireObject(object["params"])
            let settings = try requireObject(params["threadSettings"])
            guard runtimeSettingsAreValid(settings) else {
                throw CodexAppServerRuntimeError.identityMismatch(
                    reasonKey: "appServer.threadSettings.externalSandbox"
                )
            }
            let observedThreadID = string(params["threadId"])
            if observedThreadID == threadID {
                turnSettingsValidated = true
            } else {
                guard
                    let observedThreadID,
                    childThreads[observedThreadID] != nil
                else {
                    throw CodexAppServerRuntimeError.identityMismatch(
                        reasonKey:
                            "appServer.event.threadSettingsUpdated.thread"
                    )
                }
                childThreads[observedThreadID]?.settingsValidated = true
            }
        case "thread/status/changed":
            guard phase == .awaitingTurn || phase == .running else {
                throw unexpectedNotification(method)
            }
            let params = try requireObject(object["params"])
            try requireThreadIdentity(
                params,
                method: "threadStatusChanged"
            )
        case "turn/started":
            guard phase == .awaitingTurn || phase == .running else {
                throw unexpectedNotification(method)
            }
            let params = try requireObject(object["params"])
            let turn = try requireObject(params["turn"])
            guard
                let observed = boundedIdentifier(string(turn["id"])),
                string(turn["status"]) == "inProgress"
            else {
                throw CodexAppServerRuntimeError.identityMismatch(
                    reasonKey: "appServer.turn.notification"
                )
            }
            let observedThreadID = string(params["threadId"])
            if observedThreadID == threadID {
                guard turnID == nil || turnID == observed else {
                    throw CodexAppServerRuntimeError.identityMismatch(
                        reasonKey: "appServer.turn.notification"
                    )
                }
                turnID = observed
            } else {
                guard
                    !isFinalizationTurn,
                    let observedThreadID,
                    var child = childThreads[observedThreadID],
                    child.turnID == nil || child.turnID == observed
                else {
                    throw CodexAppServerRuntimeError.identityMismatch(
                        reasonKey:
                            "appServer.event.turnStarted.thread"
                    )
                }
                child.turnID = observed
                childThreads[observedThreadID] = child
            }
        case "item/started", "item/completed":
            guard phase == .running else {
                throw unexpectedNotification(method)
            }
            let params = try requireObject(object["params"])
            let item = try requireObject(params["item"])
            guard
                let rawType = string(item["type"]),
                let type = boundedIdentifier(rawType)
            else {
                throw unexpectedNotification(method)
            }
            let observedThreadID = string(params["threadId"])
            if observedThreadID == threadID {
                try requireThreadAndTurnIdentity(
                    params,
                    method: method == "item/started"
                        ? "itemStarted"
                        : "itemCompleted"
                )
                guard Self.allowedItemTypes.contains(type) else {
                    throw CodexAppServerRuntimeError.unexpectedItem(
                        type: type
                    )
                }
                if
                    isFinalizationTurn,
                    !Self.allowedFinalizationItemTypes.contains(type)
                {
                    throw CodexAppServerRuntimeError.unexpectedItem(
                        type: type
                    )
                }
                observedItemTypes.insert(type)
                if method == "item/started" {
                    try recordStartedItem(type: type, item: item)
                }
                if method == "item/completed" {
                    try recordCompletedItem(type: type, item: item)
                }
            } else {
                guard
                    !isFinalizationTurn,
                    let observedThreadID,
                    let child = childThreads[observedThreadID],
                    let childTurnID = child.turnID,
                    string(params["turnId"]) == childTurnID,
                    Self.allowedChildItemTypes.contains(type)
                else {
                    throw CodexAppServerRuntimeError.identityMismatch(
                        reasonKey: "appServer.event.childItem.identity"
                    )
                }
                if
                    method == "item/completed",
                    type == "agentMessage",
                    let text = string(item["text"]),
                    text.utf8.count <= request.maximumSchemaBytes,
                    request.childAgentOutputMarkers.values.contains(
                        where: text.contains
                    )
                {
                    observedCapabilities.insert(.subagentResultObserved)
                }
            }
        case "turn/completed":
            guard phase == .running else {
                throw unexpectedNotification(method)
            }
            let params = try requireObject(object["params"])
            let turn = try requireObject(params["turn"])
            let observedThreadID = string(params["threadId"])
            if observedThreadID == threadID {
                guard string(turn["id"]) == turnID else {
                    throw CodexAppServerRuntimeError.identityMismatch(
                        reasonKey: "appServer.turn.completed"
                    )
                }
                let phaseKey = isFinalizationTurn
                    ? "finalization"
                    : request.finalizationPrompt == nil
                        ? "single"
                        : "probe"
                guard string(turn["status"]) == "completed" else {
                    throw CodexAppServerRuntimeError.turnFailed(
                        reasonKey: "appServer.turn.\(phaseKey).status"
                    )
                }
                guard turnSettingsValidated else {
                    throw CodexAppServerRuntimeError.turnFailed(
                        reasonKey: "appServer.turn.\(phaseKey).settings"
                    )
                }
                let hasRequiredMessage = isFinalizationTurn
                    ? observedFinalAgentMessage != nil
                    : request.finalizationPrompt == nil
                        ? observedFinalAgentMessage != nil
                        : probeAgentMessageObserved
                guard hasRequiredMessage else {
                    throw CodexAppServerRuntimeError.turnFailed(
                        reasonKey: "appServer.turn.\(phaseKey).message"
                    )
                }
                if
                    let rawSearchFailureReason =
                        rawSearchHandshakeFailureReason
                {
                    throw CodexAppServerRuntimeError.turnFailed(
                        reasonKey:
                            "appServer.turn.\(phaseKey).rawSearch."
                            + rawSearchFailureReason
                    )
                }
                if
                    !isFinalizationTurn,
                    let finalizationPrompt = request.finalizationPrompt
                {
                    guard childThreads.values.allSatisfy({
                        $0.turnID == nil
                    }) else {
                        throw CodexAppServerRuntimeError.turnFailed(
                            reasonKey:
                                "appServer.turn.probe.childActivity"
                        )
                    }
                    turnID = nil
                    observedFinalAgentMessage = nil
                    isFinalizationTurn = true
                    phase = .awaitingTurn
                    responses.append(
                        try turnStartRequest(
                            threadID: threadID ?? "",
                            requestID: 5,
                            prompt: finalizationPrompt,
                            includesOutputSchema: true,
                            includesSelectedSkill: false
                        )
                    )
                } else {
                    authProjection.erase()
                    phase = .completed
                }
            } else {
                guard
                    !isFinalizationTurn,
                    let observedThreadID,
                    var child = childThreads[observedThreadID],
                    string(turn["id"]) == child.turnID,
                    string(turn["status"]) == "completed"
                else {
                    throw CodexAppServerRuntimeError.identityMismatch(
                        reasonKey:
                            "appServer.event.childTurnCompleted.identity"
                    )
                }
                child.turnID = nil
                childThreads[observedThreadID] = child
            }
        case "error":
            guard phase == .running else {
                throw unexpectedNotification(method)
            }
            let params = try requireObject(object["params"])
            try requireThreadAndTurnIdentity(
                params,
                method: "error"
            )
            let upstreamError = try sanitizedUpstreamError(params)
            if
                retryableStreamError(upstreamError),
                observedUpstreamErrors.count
                    < Self.maximumRetryableStreamErrors
            {
                observedUpstreamErrors.append(upstreamError)
            } else {
                throw CodexAppServerRuntimeError.upstreamError(
                    upstreamError
                )
            }
        case "rawResponseItem/completed":
            guard
                phase == .running,
                request.verifiesRawWebSearchCompletion
            else {
                throw unexpectedNotification(method)
            }
            let params = try requireObject(object["params"])
            try requireThreadAndTurnIdentity(
                params,
                method: "rawResponseItemCompleted"
            )
            try recordRawWebSearchCompletion(params)
        case "rawResponse/completed":
            guard
                phase == .running,
                request.verifiesRawWebSearchCompletion
            else {
                throw unexpectedNotification(method)
            }
            let params = try requireObject(object["params"])
            try requireThreadAndTurnIdentity(
                params,
                method: "rawResponseCompleted"
            )
            try validateRawResponseCompletion(params)
            rawSearchResponseCompletionObserved = true
            promoteRawSearchIfComplete()
        case "item/reasoning/summaryPartAdded":
            guard phase == .running else {
                throw unexpectedNotification(method)
            }
            let params = try requireObject(object["params"])
            try requireThreadAndTurnIdentity(
                params,
                method: "reasoningSummaryPartAdded"
            )
            guard
                boundedIdentifier(string(params["itemId"])) != nil,
                let summaryIndex = integer(params["summaryIndex"]),
                summaryIndex >= 0
            else {
                throw CodexAppServerRuntimeError.invalidMessage
            }
        default:
            guard
                phase == .running,
                Self.allowedStreamingNotifications.contains(method)
            else {
                throw unexpectedNotification(method)
            }
            let params = try requireObject(object["params"])
            if string(params["threadId"]) == threadID {
                switch method {
                case "item/commandExecution/outputDelta":
                    try recordCommandOutputDelta(params)
                case "thread/tokenUsage/updated":
                    try requireThreadIdentity(
                        params,
                        method: "threadTokenUsageUpdated"
                    )
                    if
                        let observedTurnID = string(params["turnId"]),
                        observedTurnID != turnID
                    {
                        throw CodexAppServerRuntimeError.identityMismatch(
                            reasonKey: "appServer.stream.turn"
                        )
                    }
                default:
                    try requireThreadAndTurnIdentity(
                        params,
                        method: method.replacingOccurrences(
                            of: "/",
                            with: "."
                        )
                    )
                }
            } else {
                guard
                    !isFinalizationTurn,
                    let observedThreadID = string(params["threadId"]),
                    let childTurnID =
                        childThreads[observedThreadID]?.turnID,
                    string(params["turnId"]) == childTurnID
                else {
                    throw CodexAppServerRuntimeError.identityMismatch(
                        reasonKey: "appServer.stream.childThreadOrTurn"
                    )
                }
            }
        }
        observedNotificationMethods.insert(method)
        return responses
    }

    private func recordCompletedItem(
        type: String,
        item: [String: JSONValue]
    ) throws {
        switch type {
        case "agentMessage":
            if
                let message = string(item["text"]),
                message.utf8.count <= request.maximumSchemaBytes
            {
                if
                    request.finalizationPrompt != nil,
                    !isFinalizationTurn
                {
                    probeAgentMessageObserved = true
                } else {
                    observedFinalAgentMessage = message
                }
            }
        case "commandExecution":
            guard
                let itemID = boundedIdentifier(string(item["id"])),
                let sourceValue = string(item["source"]),
                let source = CodexCommandExecutionSource(
                    rawValue: sourceValue
                ),
                let status = string(item["status"]),
                let eligibleMarkerIDs = try? eligibleCommandMarkerIDs(
                    item: item,
                    source: source
                )
            else {
                throw CodexAppServerRuntimeError.invalidMessage
            }
            var matched = Set<String>()
            if let stream = commandStreams.removeValue(forKey: itemID) {
                guard
                    stream.source == source,
                    stream.eligibleMarkerIDs == eligibleMarkerIDs
                else {
                    throw CodexAppServerRuntimeError.invalidMessage
                }
                matched.formUnion(stream.matchedMarkerIDs)
            }
            if let output = string(item["aggregatedOutput"]) {
                if !output.isEmpty {
                    commandAggregatedOutputCount = min(
                        commandAggregatedOutputCount + 1,
                        32
                    )
                }
                matched.formUnion(
                    matchedMarkerIDs(
                        in: output,
                        eligibleMarkerIDs: eligibleMarkerIDs
                    )
                )
            } else if item["aggregatedOutput"] != nil,
                      item["aggregatedOutput"] != .null
            {
                throw CodexAppServerRuntimeError.invalidMessage
            }
            let exitCode = integer(item["exitCode"])
            if item["exitCode"] != nil,
               item["exitCode"] != .null,
               exitCode == nil
            {
                throw CodexAppServerRuntimeError.invalidMessage
            }
            observedCapabilities.insert(
                .command(
                    source: source,
                    succeeded: status == "completed"
                        && (exitCode == nil || exitCode == 0),
                    matchedMarkerIDs: matched.sorted()
                )
            )
        case "webSearch":
            if !request.verifiesRawWebSearchCompletion {
                observedCapabilities.insert(.webSearchCompleted)
            }
        case "imageView":
            guard
                item["status"] == nil
                    || string(item["status"]) == "completed",
                imageItemMatchesExpectation(item)
            else {
                return
            }
            observedCapabilities.insert(.imageViewCompleted)
        case "collabAgentToolCall":
            guard
                let tool = string(item["tool"]),
                string(item["status"]) == "completed",
                string(item["senderThreadId"]) == threadID,
                let receivers = array(item["receiverThreadIds"]),
                !receivers.isEmpty,
                receivers.count <= Self.maximumChildThreads
            else {
                if
                    item["senderThreadId"] != nil,
                    string(item["senderThreadId"]) != threadID
                {
                    throw CodexAppServerRuntimeError.identityMismatch(
                        reasonKey: "appServer.subagent.sender"
                    )
                }
                return
            }
            let receiverIDs = try receivers.map {
                guard let identifier = boundedIdentifier(string($0)) else {
                    throw CodexAppServerRuntimeError.invalidMessage
                }
                return identifier
            }
            guard
                Set(receiverIDs).count == receiverIDs.count,
                !receiverIDs.contains(threadID ?? ""),
                receiverIDs.count <= Self.maximumChildThreads
            else {
                throw CodexAppServerRuntimeError.invalidMessage
            }
            switch tool {
            case "spawnAgent":
                let receiverIDsAreNew = receiverIDs.allSatisfy {
                    childThreads[$0] == nil
                }
                guard
                    receiverIDsAreNew,
                    childThreads.count + receiverIDs.count
                        <= Self.maximumChildThreads
                else {
                    throw CodexAppServerRuntimeError.invalidMessage
                }
                for receiverID in receiverIDs {
                    childThreads[receiverID] = ChildThreadState()
                }
                try recordSubagentResult(
                    item: item,
                    receiverIDs: receiverIDs
                )
                observedCapabilities.insert(
                    .subagentSpawnCompleted(
                        receiverCount: receiverIDs.count
                    )
                )
            case "wait":
                guard receiverIDs.allSatisfy({
                    childThreads[$0] != nil
                }) else {
                    throw CodexAppServerRuntimeError.invalidMessage
                }
                try recordSubagentResult(
                    item: item,
                    receiverIDs: receiverIDs
                )
            default:
                return
            }
        default:
            break
        }
    }

    private func recordSubagentResult(
        item: [String: JSONValue],
        receiverIDs: [String]
    ) throws {
        guard item["agentsStates"] != nil else { return }
        let states = try requireObject(item["agentsStates"])
        guard
            Set(states.keys) == Set(receiverIDs),
            !request.childAgentOutputMarkers.isEmpty
        else {
            return
        }
        for receiverID in receiverIDs {
            let state = try requireObject(states[receiverID])
            guard
                string(state["status"]) == "completed",
                let message = string(state["message"]),
                message.utf8.count <= request.maximumSchemaBytes,
                request.childAgentOutputMarkers.values.contains(
                    where: message.contains
                )
            else {
                continue
            }
            observedCapabilities.insert(.subagentResultObserved)
        }
    }

    private func recordStartedItem(
        type: String,
        item: [String: JSONValue]
    ) throws {
        switch type {
        case "webSearch":
            observedCapabilities.insert(.webSearchStarted)
            rawSearchCanonicalStartObserved = true
            promoteRawSearchIfComplete()
            return
        case "imageView":
            if imageItemMatchesExpectation(item) {
                observedCapabilities.insert(.imageViewStarted)
            }
            return
        case "collabAgentToolCall":
            if string(item["tool"]) == "spawnAgent" {
                observedCapabilities.insert(.subagentSpawnStarted)
            }
            return
        case "commandExecution":
            break
        default:
            return
        }
        guard
            let itemID = boundedIdentifier(string(item["id"])),
            let sourceValue = string(item["source"]),
            let source = CodexCommandExecutionSource(
                rawValue: sourceValue
            ),
            string(item["status"]) == "inProgress",
            commandStreams[itemID] == nil,
            let eligibleMarkerIDs = try? eligibleCommandMarkerIDs(
                item: item,
                source: source
            )
        else {
            throw CodexAppServerRuntimeError.invalidMessage
        }
        commandStreams[itemID] = CommandStreamState(
            source: source,
            eligibleMarkerIDs: eligibleMarkerIDs,
            markerProgress: Dictionary(
                uniqueKeysWithValues:
                    eligibleMarkerIDs.map {
                        ($0, 0)
                    }
            ),
            matchedMarkerIDs: []
        )
        if !eligibleMarkerIDs.isEmpty {
            commandIdentityEligibleCount = min(
                commandIdentityEligibleCount + 1,
                32
            )
        }
    }

    private func recordCommandOutputDelta(
        _ params: [String: JSONValue]
    ) throws {
        try requireThreadAndTurnIdentity(
            params,
            method: "item.commandExecution.outputDelta"
        )
        guard
            let itemID = boundedIdentifier(string(params["itemId"])),
            var state = commandStreams[itemID],
            let delta = string(params["delta"]),
            delta.utf8.count <= request.maximumInputLineBytes
        else {
            throw CodexAppServerRuntimeError.invalidMessage
        }
        commandOutputDeltaCount = min(commandOutputDeltaCount + 1, 32)
        for markerID in state.eligibleMarkerIDs {
            guard let definition = capabilityMarkerDefinitions[markerID] else {
                throw CodexAppServerRuntimeError.invalidMessage
            }
            guard !state.matchedMarkerIDs.contains(markerID) else {
                continue
            }
            var progress = state.markerProgress[markerID] ?? 0
            for byte in delta.utf8 {
                progress = nextMarkerProgress(
                    definition: definition,
                    current: progress,
                    byte: byte
                )
                if progress == definition.token.count {
                    state.matchedMarkerIDs.insert(markerID)
                    progress = 0
                    break
                }
            }
            state.markerProgress[markerID] = progress
        }
        commandStreams[itemID] = state
    }

    private func matchedMarkerIDs(
        in output: String,
        eligibleMarkerIDs: Set<String>
    ) -> Set<String> {
        Set(eligibleMarkerIDs.compactMap { markerID in
            guard let token = request.capabilityOutputMarkers[markerID] else {
                return nil
            }
            return output.contains(token) ? markerID : nil
        })
    }

    private func eligibleCommandMarkerIDs(
        item: [String: JSONValue],
        source: CodexCommandExecutionSource
    ) throws -> Set<String> {
        if request.capabilityCommandRequirements.isEmpty {
            return Set(request.capabilityOutputMarkers.keys)
        }
        guard
            let command = string(item["command"]),
            command.utf8.count <= request.maximumInputLineBytes,
            canonicalPath(string(item["cwd"]))
                == canonicalPath(request.workingDirectoryURL.path)
        else {
            throw CodexAppServerRuntimeError.invalidMessage
        }
        return Set(
            request.capabilityCommandRequirements.compactMap {
                markerID, requirement in
                requirement.allowedSources.contains(source)
                    && requirement.commands.contains {
                        commandMatchesRequirement(
                            observed: command,
                            expected: $0,
                            source: source
                        )
                    }
                    ? markerID
                    : nil
            }
        )
    }

    private func commandMatchesRequirement(
        observed: String,
        expected: String,
        source: CodexCommandExecutionSource
    ) -> Bool {
        if observed == expected {
            return true
        }
        guard
            source == .unifiedExecStartup
                || source == .unifiedExecInteraction,
            !expected.isEmpty,
            expected.utf8.count <= request.maximumInputLineBytes,
            !expected.contains("'"),
            !expected.contains("\\"),
            !expected.unicodeScalars.contains(where: {
                $0.value < 0x20 || $0.value == 0x7F
            })
        else {
            return false
        }
        if observed == "/bin/zsh -lc '\(expected)'" {
            return true
        }
        let isSafeUnquotedCommand = expected.unicodeScalars.allSatisfy {
            (0x30...0x39).contains($0.value)
                || (0x41...0x5A).contains($0.value)
                || (0x61...0x7A).contains($0.value)
                || $0.value == 0x2D
                || $0.value == 0x2E
                || $0.value == 0x2F
                || $0.value == 0x5F
        }
        return isSafeUnquotedCommand
            && observed == "/bin/zsh -lc \(expected)"
    }

    private func imageItemMatchesExpectation(
        _ item: [String: JSONValue]
    ) -> Bool {
        guard let expected = request.expectedImageURL else {
            return true
        }
        return canonicalPath(string(item["path"]))
            == canonicalPath(expected.path)
    }

    private func nextMarkerProgress(
        definition: MarkerDefinition,
        current: Int,
        byte: UInt8
    ) -> Int {
        var progress = min(current, definition.token.count - 1)
        while
            progress > 0,
            definition.token[progress] != byte
        {
            progress = definition.failure[progress - 1]
        }
        if definition.token[progress] == byte {
            progress += 1
        }
        return progress
    }

    private func runtimeSettingsAreValid(
        _ settings: [String: JSONValue]
    ) -> Bool {
        guard
            let sandbox = try? requireObject(
                settings["sandboxPolicy"]
            )
        else {
            return false
        }
        return canonicalPath(string(settings["cwd"]))
            == canonicalPath(request.workingDirectoryURL.path)
            && string(settings["approvalPolicy"]) == "never"
            && string(settings["model"])
                == CodexRuntimeModel.gpt56Luna.rawValue
            && string(settings["modelProvider"])
                == Self.provider.rawValue
            && string(sandbox["type"]) == "externalSandbox"
            && string(sandbox["networkAccess"]) == "enabled"
    }

    private func sanitizedUpstreamError(
        _ params: [String: JSONValue]
    ) throws -> CodexSanitizedUpstreamError {
        let error = try requireObject(params["error"])
        guard
            string(error["message"]) != nil,
            let willRetry = bool(params["willRetry"])
        else {
            throw CodexAppServerRuntimeError.invalidMessage
        }
        if
            let details = error["additionalDetails"],
            details != .null,
            string(details) == nil
        {
            throw CodexAppServerRuntimeError.invalidMessage
        }
        let sanitized = try sanitizedUpstreamCategory(
            error["codexErrorInfo"]
        )
        return CodexSanitizedUpstreamError(
            category: sanitized.category,
            code: sanitized.code,
            willRetry: willRetry
        )
    }

    private func retryableStreamError(
        _ error: CodexSanitizedUpstreamError
    ) -> Bool {
        guard error.willRetry else { return false }
        switch error.category {
        case .responseStreamConnectionFailed,
             .responseStreamDisconnected:
            return true
        default:
            return false
        }
    }

    private func sanitizedUpstreamCategory(
        _ value: JSONValue?
    ) throws -> (
        category: CodexSanitizedUpstreamErrorCategory,
        code: Int?
    ) {
        guard let value, value != .null else {
            return (.unclassified, nil)
        }
        switch value {
        case let .string(rawCategory):
            let scalarCategories:
                Set<CodexSanitizedUpstreamErrorCategory> = [
                    .contextWindowExceeded,
                    .sessionBudgetExceeded,
                    .usageLimitExceeded,
                    .serverOverloaded,
                    .cyberPolicy,
                    .internalServerError,
                    .unauthorized,
                    .badRequest,
                    .threadRollbackFailed,
                    .sandboxError,
                    .other,
                ]
            guard
                let category = CodexSanitizedUpstreamErrorCategory(
                    rawValue: rawCategory
                )
            else {
                return (.unclassified, nil)
            }
            guard scalarCategories.contains(category) else {
                throw CodexAppServerRuntimeError.invalidMessage
            }
            return (category, nil)
        case let .object(object):
            guard object.count == 1, let entry = object.first else {
                throw CodexAppServerRuntimeError.invalidMessage
            }
            switch entry.key {
            case "httpConnectionFailed":
                return (
                    .httpConnectionFailed,
                    try sanitizedHTTPStatusCode(entry.value)
                )
            case "responseStreamConnectionFailed":
                return (
                    .responseStreamConnectionFailed,
                    try sanitizedHTTPStatusCode(entry.value)
                )
            case "responseStreamDisconnected":
                return (
                    .responseStreamDisconnected,
                    try sanitizedHTTPStatusCode(entry.value)
                )
            case "responseTooManyFailedAttempts":
                return (
                    .responseTooManyFailedAttempts,
                    try sanitizedHTTPStatusCode(entry.value)
                )
            case "activeTurnNotSteerable":
                let details = try requireObject(entry.value)
                guard
                    details.count == 1,
                    let turnKind = string(details["turnKind"]),
                    turnKind == "review" || turnKind == "compact"
                else {
                    throw CodexAppServerRuntimeError.invalidMessage
                }
                return (.activeTurnNotSteerable, nil)
            default:
                return (.unclassified, nil)
            }
        case .number, .bool, .array:
            throw CodexAppServerRuntimeError.invalidMessage
        case .null:
            return (.unclassified, nil)
        }
    }

    private func sanitizedHTTPStatusCode(
        _ value: JSONValue
    ) throws -> Int? {
        let details = try requireObject(value)
        guard details.keys.allSatisfy({ $0 == "httpStatusCode" }) else {
            throw CodexAppServerRuntimeError.invalidMessage
        }
        guard let status = details["httpStatusCode"], status != .null else {
            return nil
        }
        guard
            let code = integer(status),
            (0...65_535).contains(code)
        else {
            throw CodexAppServerRuntimeError.invalidMessage
        }
        return code
    }

    private func loginRequest() throws -> Data {
        let credentials = currentCredentials()
        return try encodeLine([
            "id": .number(2),
            "method": .string("account/login/start"),
            "params": .object(loginObject(credentials)),
        ])
    }

    private func threadStartRequest() throws -> Data {
        var params: [String: JSONValue] = [
            "approvalPolicy": .string("never"),
            "cwd": .string(request.workingDirectoryURL.path),
            "ephemeral": .bool(true),
            "model": .string(CodexRuntimeModel.gpt56Luna.rawValue),
            "modelProvider": .string(Self.provider.rawValue),
        ]
        if request.verifiesRawWebSearchCompletion {
            params["experimentalRawEvents"] = .bool(true)
        }
        return try encodeLine([
            "id": .number(3),
            "method": .string("thread/start"),
            "params": .object(params),
        ])
    }

    private func turnStartRequest(
        threadID: String,
        requestID: Int,
        prompt: String,
        includesOutputSchema: Bool,
        includesSelectedSkill: Bool
    ) throws -> Data {
        var input: [JSONValue] = [
            .object([
                "text": .string(prompt),
                "textElements": .array([]),
                "type": .string("text"),
            ]),
        ]
        if includesSelectedSkill, let skill = request.selectedRuntimeSkill {
            observedCapabilities.insert(.runtimeSkillSelected)
            input.append(.object([
                "name": .string(skill.name),
                "path": .string(skill.path.path),
                "type": .string("skill"),
            ]))
        }
        var params: [String: JSONValue] = [
            "approvalPolicy": .string("never"),
            "cwd": .string(request.workingDirectoryURL.path),
            "input": .array(input),
            "model": .string(CodexRuntimeModel.gpt56Luna.rawValue),
            "sandboxPolicy": .object([
                "networkAccess": .string("enabled"),
                "type": .string("externalSandbox"),
            ]),
            "threadId": .string(threadID),
        ]
        if includesOutputSchema {
            params["outputSchema"] = request.outputSchema
        }
        return try encodeLine([
            "id": .number(requestID),
            "method": .string("turn/start"),
            "params": .object(params),
        ])
    }

    private func recordRawWebSearchCompletion(
        _ params: [String: JSONValue]
    ) throws {
        let item = try requireObject(params["item"])
        guard
            string(item["type"]) == "web_search_call",
            string(item["status"]) == "completed"
        else {
            return
        }
        if let actionValue = item["action"], actionValue != .null {
            let actionObject = try requireObject(actionValue)
            guard let actionType = string(actionObject["type"]) else {
                throw CodexAppServerRuntimeError.invalidMessage
            }
            guard
                [
                    "search",
                    "open_page",
                    "find_in_page",
                    "other",
                ].contains(actionType)
            else {
                return
            }
        }
        rawSearchItemCompletionObserved = true
        promoteRawSearchIfComplete()
    }

    private var rawSearchHandshakeIsComplete: Bool {
        rawSearchHandshakeFailureReason == nil
    }

    private var rawSearchHandshakeFailureReason: String? {
        guard request.verifiesRawWebSearchCompletion else {
            return nil
        }
        if !rawSearchResponseCompletionObserved {
            return "raw-response"
        }
        if
            !rawSearchCanonicalStartObserved,
            !rawSearchItemCompletionObserved
        {
            return "invocation"
        }
        return nil
    }

    private func promoteRawSearchIfComplete() {
        if rawSearchHandshakeIsComplete {
            observedCapabilities.insert(.webSearchCompleted)
        }
    }

    private func validateRawResponseCompletion(
        _ params: [String: JSONValue]
    ) throws {
        guard boundedIdentifier(string(params["responseId"])) != nil else {
            throw CodexAppServerRuntimeError.invalidMessage
        }
        switch params["usage"] {
        case .object, .null:
            return
        case .array, .bool, .number, .string, nil:
            throw CodexAppServerRuntimeError.invalidMessage
        }
    }

    private func authObject(
        _ credentials: CodexRuntimeAuthCredentials
    ) -> [String: JSONValue] {
        switch credentials {
        case let .chatGPT(accessToken, accountID, planType):
            [
                "accessToken": .string(accessToken),
                "chatgptAccountId": .string(accountID),
                "chatgptPlanType": planType.map(JSONValue.string)
                    ?? .null,
            ]
        }
    }

    private func loginObject(
        _ credentials: CodexRuntimeAuthCredentials
    ) -> [String: JSONValue] {
        switch credentials {
        case .chatGPT:
            var object = authObject(credentials)
            object["type"] = .string("chatgptAuthTokens")
            return object
        }
    }

    private func currentCredentials() -> CodexRuntimeAuthCredentials {
        authProjection.withCredentials { $0 }
    }

    private func decodeLine(
        _ data: Data
    ) throws -> [String: JSONValue] {
        guard
            !data.isEmpty,
            data.count <= request.maximumInputLineBytes,
            data.last == 0x0A
        else {
            if data.count > request.maximumInputLineBytes {
                throw CodexAppServerRuntimeError.inputLimitExceeded
            }
            throw CodexAppServerRuntimeError.invalidMessage
        }
        do {
            let value = try JSONDecoder().decode(JSONValue.self, from: data)
            return try requireObject(value)
        } catch let error as CodexAppServerRuntimeError {
            throw error
        } catch {
            throw CodexAppServerRuntimeError.invalidMessage
        }
    }

    private func encodeLine(
        _ object: [String: JSONValue]
    ) throws -> Data {
        var data = try JSONEncoder().encode(JSONValue.object(object))
        data.append(0x0A)
        return data
    }

    private func requireNumericID(
        _ expected: Int,
        object: [String: JSONValue]
    ) throws {
        guard object["id"] == .number(expected) else {
            throw CodexAppServerRuntimeError.unexpectedResponse(
                reasonKey: responseReasonKey(suffix: "responseID")
            )
        }
    }

    private func responseReasonKey(suffix: String) -> String {
        let phaseKey: String
        switch phase {
        case .ready:
            phaseKey = "ready"
        case .awaitingInitialize:
            phaseKey = "initialize"
        case .awaitingLogin:
            phaseKey = "login"
        case .awaitingThread:
            phaseKey = "thread"
        case .awaitingTurn:
            phaseKey = "turn"
        case .running:
            phaseKey = "running"
        case .completed:
            phaseKey = "completed"
        case .failed:
            phaseKey = "failed"
        }
        return "appServer.\(phaseKey).\(suffix)"
    }

    private func requireObject(
        _ value: JSONValue?
    ) throws -> [String: JSONValue] {
        guard case let .object(object) = value else {
            throw CodexAppServerRuntimeError.invalidMessage
        }
        return object
    }

    private func requireArray(
        _ value: JSONValue?
    ) throws -> [JSONValue] {
        guard case let .array(array) = value else {
            throw CodexAppServerRuntimeError.invalidMessage
        }
        return array
    }

    private func string(_ value: JSONValue?) -> String? {
        guard case let .string(value) = value else { return nil }
        return value
    }

    private func bool(_ value: JSONValue?) -> Bool? {
        guard case let .bool(value) = value else { return nil }
        return value
    }

    private func integer(_ value: JSONValue?) -> Int? {
        guard case let .number(value) = value else { return nil }
        return value
    }

    private func array(_ value: JSONValue?) -> [JSONValue]? {
        guard case let .array(value) = value else { return nil }
        return value
    }

    private func boundedIdentifier(_ value: String?) -> String? {
        guard
            let value,
            !value.isEmpty,
            value.utf8.count <= 256,
            value.unicodeScalars.allSatisfy({
                $0.value >= 0x20 && $0.value != 0x7F
            })
        else {
            return nil
        }
        return value
    }

    private func canonicalPath(_ value: String?) -> String? {
        guard
            let value,
            value.hasPrefix("/"),
            value.unicodeScalars.allSatisfy({
                $0.value >= 0x20 && $0.value != 0x7F
            })
        else {
            return nil
        }
        return URL(filePath: value)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
    }

    private func validRPCIdentifier(_ value: JSONValue) -> Bool {
        switch value {
        case let .string(identifier):
            boundedIdentifier(identifier) != nil
        case let .number(identifier):
            identifier >= 0
        case .bool, .object, .array, .null:
            false
        }
    }

    private func requireThreadIdentity(
        _ params: [String: JSONValue],
        method: String
    ) throws {
        guard string(params["threadId"]) == threadID else {
            throw CodexAppServerRuntimeError.identityMismatch(
                reasonKey: "appServer.event.\(method).thread"
            )
        }
    }

    private func requireThreadAndTurnIdentity(
        _ params: [String: JSONValue],
        method: String
    ) throws {
        guard
            string(params["threadId"]) == threadID,
            string(params["turnId"]) == turnID
        else {
            throw CodexAppServerRuntimeError.identityMismatch(
                reasonKey:
                    "appServer.event.\(method).threadOrTurn"
            )
        }
    }

    private func unexpectedNotification(
        _ method: String
    ) -> CodexAppServerRuntimeError {
        let reasonKeys: [String: String] = [
            "account/login/completed":
                "appServer.notification.accountLoginCompleted",
            "account/updated":
                "appServer.notification.accountUpdated",
            "account/rateLimits/updated":
                "appServer.notification.accountRateLimitsUpdated",
            "configWarning":
                "appServer.notification.configWarning",
            "error":
                "appServer.notification.error",
            "item/completed":
                "appServer.notification.itemCompleted",
            "item/started":
                "appServer.notification.itemStarted",
            "remoteControl/status/changed":
                "appServer.notification.remoteControlStatusChanged",
            "thread/settings/updated":
                "appServer.notification.threadSettingsUpdated",
            "thread/started":
                "appServer.notification.threadStarted",
            "thread/status/changed":
                "appServer.notification.threadStatusChanged",
            "thread/tokenUsage/updated":
                "appServer.notification.threadTokenUsageUpdated",
            "turn/completed":
                "appServer.notification.turnCompleted",
            "turn/started":
                "appServer.notification.turnStarted",
            "warning":
                "appServer.notification.warning",
        ]
        let boundedMethod = method.utf8.count <= 128
            && method.unicodeScalars.allSatisfy {
                (0x30...0x39).contains($0.value)
                    || (0x41...0x5A).contains($0.value)
                    || (0x61...0x7A).contains($0.value)
                    || $0.value == 0x2D
                    || $0.value == 0x2E
                    || $0.value == 0x2F
                    || $0.value == 0x3A
                    || $0.value == 0x5F
            }
            ? method.replacingOccurrences(of: "/", with: ".")
            : "unbounded"
        return .unexpectedNotification(
            reasonKey: reasonKeys[method]
                ?? "appServer.notification.unknown.\(boundedMethod)"
        )
    }

    private var phaseAllowsDelayedAuthNotification: Bool {
        switch phase {
        case .awaitingLogin, .awaitingThread, .awaitingTurn,
             .running:
            true
        case .ready, .awaitingInitialize, .completed, .failed:
            false
        }
    }

    private static func validAbsolutePath(_ url: URL) -> Bool {
        url.isFileURL
            && url.path.hasPrefix("/")
            && url.path.unicodeScalars.allSatisfy({
                $0.value >= 0x20 && $0.value != 0x7F
            })
    }

    private static func validCapabilityToken(_ value: String) -> Bool {
        !value.isEmpty
            && value.utf8.count <= 128
            && value.unicodeScalars.allSatisfy {
                (0x30...0x39).contains($0.value)
                    || (0x41...0x5A).contains($0.value)
                    || (0x61...0x7A).contains($0.value)
                    || $0.value == 0x2D
                    || $0.value == 0x2E
                    || $0.value == 0x3A
                    || $0.value == 0x5F
            }
    }

    private static func validSelectedRuntimeSkill(
        _ skill: CodexSelectedRuntimeSkill?,
        runtimeHomeURL: URL
    ) -> Bool {
        guard let skill else { return true }
        let skillsRoot = runtimeHomeURL.appending(
            path: "skills",
            directoryHint: .isDirectory
        ).standardizedFileURL
        let path = skill.path.standardizedFileURL
        return validCapabilityMarkerID(skill.name)
            && path.isFileURL
            && path.lastPathComponent == "SKILL.md"
            && path.path.hasPrefix(skillsRoot.path + "/")
            && path.path.unicodeScalars.allSatisfy {
                $0.value >= 0x20 && $0.value != 0x7F
            }
    }

    private static func validCommandRequirement(
        _ requirement: CodexCommandIdentityRequirement
    ) -> Bool {
        !requirement.commands.isEmpty
            && requirement.commands.count <= 8
            && requirement.commands.allSatisfy {
                !$0.isEmpty
                    && $0.utf8.count <= 16 * 1_024
                    && $0.unicodeScalars.allSatisfy {
                        $0.value >= 0x20 && $0.value != 0x7F
                    }
            }
            && !requirement.allowedSources.isEmpty
    }

    private static func validExpectedImage(
        _ imageURL: URL?,
        workingDirectoryURL: URL
    ) -> Bool {
        guard let imageURL else {
            return true
        }
        return validAbsolutePath(imageURL)
            && contains(workingDirectoryURL, imageURL)
            && imageURL.pathExtension.lowercased() == "png"
    }

    private static func validCapabilityMarkerID(_ value: String) -> Bool {
        !value.isEmpty
            && value.utf8.count <= 128
            && value.unicodeScalars.allSatisfy {
                (0x30...0x39).contains($0.value)
                    || (0x41...0x5A).contains($0.value)
                    || (0x61...0x7A).contains($0.value)
                    || $0.value == 0x2D
                    || $0.value == 0x2E
                    || $0.value == 0x3A
                    || $0.value == 0x5F
            }
    }

    private static func isClosedOutputSchema(
        _ value: JSONValue
    ) -> Bool {
        guard
            case let .object(schema) = value,
            schema["type"] == .string("object"),
            schema["additionalProperties"] == .bool(false),
            case .object = schema["properties"],
            case .array = schema["required"]
        else {
            return false
        }
        return true
    }
}

private extension CodexRuntimeAuthCredentials {
    var loginType: String {
        switch self {
        case .chatGPT:
            "chatgptAuthTokens"
        }
    }

    var notificationAuthMode: String {
        switch self {
        case .chatGPT:
            "chatgptAuthTokens"
        }
    }
}
