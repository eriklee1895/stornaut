import Foundation

protocol CodexRuntimeAuthRefreshProviding: Sendable {
    func refresh() throws -> CodexRuntimeAuthProjection
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

    init(
        projectedAuthSourceURL: URL,
        runtimeHomeURL: URL,
        workingDirectoryURL: URL,
        prompt: String,
        outputSchema: JSONValue,
        maximumPromptBytes: Int = 256 * 1_024,
        maximumSchemaBytes: Int = 256 * 1_024,
        maximumInputLineBytes: Int = 2 * 1_024 * 1_024
    ) {
        self.projectedAuthSourceURL = projectedAuthSourceURL
        self.runtimeHomeURL = runtimeHomeURL
        self.workingDirectoryURL = workingDirectoryURL
        self.prompt = prompt
        self.outputSchema = outputSchema
        self.maximumPromptBytes = maximumPromptBytes
        self.maximumSchemaBytes = maximumSchemaBytes
        self.maximumInputLineBytes = maximumInputLineBytes
    }
}

enum CodexAppServerRuntimeStatus: Sendable, Equatable {
    case ready
    case configuring
    case running
    case completed
    case failed
}

enum CodexAppServerRuntimeError: Error, Sendable, Equatable {
    case invalidRequest
    case invalidState
    case inputLimitExceeded
    case invalidMessage
    case unexpectedResponse(reasonKey: String)
    case unexpectedRequest
    case unexpectedNotification(reasonKey: String)
    case identityMismatch(reasonKey: String)
    case authenticationRefreshBlocked
    case turnFailed
}

struct CodexAppServerObservation: Sendable, Equatable {
    let notificationMethods: [String]
    let itemTypes: [String]
    let finalAgentMessage: String?
}

final class CodexAppServerRuntime: @unchecked Sendable {
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

    private static let allowedStreamingNotifications: Set<String> = [
        "item/agentMessage/delta",
        "item/commandExecution/outputDelta",
        "item/commandExecution/terminalInteraction",
        "item/plan/delta",
        "item/reasoning/summaryPart/added",
        "item/reasoning/summaryText/delta",
        "thread/status/changed",
        "thread/tokenUsage/updated",
        "turn/plan/updated",
    ]
    private static let allowedItemTypes: Set<String> = [
        "agentMessage",
        "collabToolCall",
        "commandExecution",
        "imageView",
        "plan",
        "reasoning",
        "sleep",
        "userMessage",
        "webSearch",
    ]

    private let request: CodexAppServerRuntimeRequest
    private var authProjection: CodexRuntimeAuthProjection
    private let refreshProvider:
        (any CodexRuntimeAuthRefreshProviding)?
    private let lock = NSLock()
    private var phase = Phase.ready
    private var threadID: String?
    private var turnID: String?
    private var refreshUsed = false
    private var turnSettingsValidated = false
    private var observedNotificationMethods = Set<String>()
    private var observedItemTypes = Set<String>()
    private var observedFinalAgentMessage: String?

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
            request.maximumPromptBytes > 0,
            request.maximumSchemaBytes > 0,
            request.maximumInputLineBytes > 0,
            Self.isClosedOutputSchema(request.outputSchema),
            let schemaData = try? JSONEncoder().encode(
                request.outputSchema
            ),
            schemaData.count <= request.maximumSchemaBytes
        else {
            throw CodexAppServerRuntimeError.invalidRequest
        }
        self.request = request
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

    var observation: CodexAppServerObservation {
        lock.withLock {
            CodexAppServerObservation(
                notificationMethods: observedNotificationMethods.sorted(),
                itemTypes: observedItemTypes.sorted(),
                finalAgentMessage: observedFinalAgentMessage
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
            try processNotification(method: method, object: object)
            return []
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
            guard string(result["type"]) == "chatgptAuthTokens" else {
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
            return [try turnStartRequest(threadID: observedThreadID)]
        case .awaitingTurn:
            try requireNumericID(4, object: object)
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
                == currentCredentials().accountID
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
        guard credentials.accountID == currentCredentials().accountID else {
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
    ) throws {
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
            guard authMode == "chatgptAuthTokens" else {
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
            try requireThreadIdentity(params)
            let settings = try requireObject(params["threadSettings"])
            let sandbox = try requireObject(settings["sandboxPolicy"])
            guard
                canonicalPath(string(settings["cwd"]))
                    == canonicalPath(request.workingDirectoryURL.path),
                string(settings["approvalPolicy"]) == "never",
                string(settings["model"])
                    == CodexRuntimeModel.gpt56Luna.rawValue,
                string(sandbox["type"]) == "externalSandbox",
                string(sandbox["networkAccess"]) == "enabled"
            else {
                throw CodexAppServerRuntimeError.identityMismatch(
                    reasonKey: "appServer.threadSettings.externalSandbox"
                )
            }
            turnSettingsValidated = true
        case "thread/status/changed":
            guard phase == .awaitingTurn || phase == .running else {
                throw unexpectedNotification(method)
            }
            let params = try requireObject(object["params"])
            try requireThreadIdentity(params)
        case "turn/started":
            guard phase == .awaitingTurn || phase == .running else {
                throw unexpectedNotification(method)
            }
            let params = try requireObject(object["params"])
            try requireThreadIdentity(params)
            let turn = try requireObject(params["turn"])
            guard
                let observed = boundedIdentifier(string(turn["id"])),
                string(turn["status"]) == "inProgress",
                turnID == nil || turnID == observed
            else {
                throw CodexAppServerRuntimeError.identityMismatch(
                    reasonKey: "appServer.turn.notification"
                )
            }
            turnID = observed
        case "item/started", "item/completed":
            guard phase == .running else {
                throw unexpectedNotification(method)
            }
            let params = try requireObject(object["params"])
            try requireThreadAndTurnIdentity(params)
            let item = try requireObject(params["item"])
            guard
                let type = string(item["type"]),
                Self.allowedItemTypes.contains(type)
            else {
                throw unexpectedNotification(method)
            }
            observedItemTypes.insert(type)
            if
                method == "item/completed",
                type == "agentMessage",
                let message = string(item["text"]),
                message.utf8.count <= request.maximumSchemaBytes
            {
                observedFinalAgentMessage = message
            }
        case "turn/completed":
            guard phase == .running else {
                throw unexpectedNotification(method)
            }
            let params = try requireObject(object["params"])
            try requireThreadIdentity(params)
            let turn = try requireObject(params["turn"])
            guard string(turn["id"]) == turnID else {
                throw CodexAppServerRuntimeError.identityMismatch(
                    reasonKey: "appServer.turn.completed"
                )
            }
            guard
                string(turn["status"]) == "completed",
                turnSettingsValidated,
                observedFinalAgentMessage != nil
            else {
                throw CodexAppServerRuntimeError.turnFailed
            }
            authProjection.erase()
            phase = .completed
        default:
            guard
                phase == .running,
                Self.allowedStreamingNotifications.contains(method)
            else {
                throw unexpectedNotification(method)
            }
            let params = try requireObject(object["params"])
            switch method {
            case "thread/tokenUsage/updated":
                try requireThreadIdentity(params)
                if
                    let observedTurnID = string(params["turnId"]),
                    observedTurnID != turnID
                {
                    throw CodexAppServerRuntimeError.identityMismatch(
                        reasonKey: "appServer.stream.turn"
                    )
                }
            default:
                try requireThreadAndTurnIdentity(params)
            }
        }
        observedNotificationMethods.insert(method)
    }

    private func loginRequest() throws -> Data {
        let credentials = currentCredentials()
        return try encodeLine([
            "id": .number(2),
            "method": .string("account/login/start"),
            "params": .object([
                "accessToken": .string(credentials.accessToken),
                "chatgptAccountId": .string(credentials.accountID),
                "chatgptPlanType": credentials.planType.map(JSONValue.string)
                    ?? .null,
                "type": .string("chatgptAuthTokens"),
            ]),
        ])
    }

    private func threadStartRequest() throws -> Data {
        try encodeLine([
            "id": .number(3),
            "method": .string("thread/start"),
            "params": .object([
                "approvalPolicy": .string("never"),
                "cwd": .string(request.workingDirectoryURL.path),
                "ephemeral": .bool(true),
                "model": .string(CodexRuntimeModel.gpt56Luna.rawValue),
            ]),
        ])
    }

    private func turnStartRequest(threadID: String) throws -> Data {
        try encodeLine([
            "id": .number(4),
            "method": .string("turn/start"),
            "params": .object([
                "approvalPolicy": .string("never"),
                "cwd": .string(request.workingDirectoryURL.path),
                "input": .array([
                    .object([
                        "text": .string(request.prompt),
                        "textElements": .array([]),
                        "type": .string("text"),
                    ]),
                ]),
                "model": .string(CodexRuntimeModel.gpt56Luna.rawValue),
                "outputSchema": request.outputSchema,
                "sandboxPolicy": .object([
                    "networkAccess": .string("enabled"),
                    "type": .string("externalSandbox"),
                ]),
                "threadId": .string(threadID),
            ]),
        ])
    }

    private func authObject(
        _ credentials: CodexRuntimeAuthCredentials
    ) -> [String: JSONValue] {
        [
            "accessToken": .string(credentials.accessToken),
            "chatgptAccountId": .string(credentials.accountID),
            "chatgptPlanType": credentials.planType.map(JSONValue.string)
                ?? .null,
        ]
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
        _ params: [String: JSONValue]
    ) throws {
        guard string(params["threadId"]) == threadID else {
            throw CodexAppServerRuntimeError.identityMismatch(
                reasonKey: "appServer.event.thread"
            )
        }
    }

    private func requireThreadAndTurnIdentity(
        _ params: [String: JSONValue]
    ) throws {
        guard
            string(params["threadId"]) == threadID,
            string(params["turnId"]) == turnID
        else {
            throw CodexAppServerRuntimeError.identityMismatch(
                reasonKey: "appServer.event.threadOrTurn"
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
        return .unexpectedNotification(
            reasonKey: reasonKeys[method]
                ?? "appServer.notification.unknown"
        )
    }

    private var phaseAllowsDelayedAuthNotification: Bool {
        switch phase {
        case .awaitingLogin, .awaitingThread, .awaitingTurn, .running:
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
