import Foundation

package protocol CodexInteractiveAppServerTransport: Sendable {
    func writeLine(_ line: Data) async throws
    func readLine() async throws -> Data
    func retire() async throws
}

package protocol CodexInteractiveSessionDriving: Sendable {
    func prepareRoot() async throws -> CodexInteractiveRootIdentity

    func startTurn(
        threadID: String,
        inputTexts: [String]
    ) async throws -> CodexInteractiveTurnIdentity

    func readThread(
        threadID: String
    ) async throws -> CodexInteractiveThreadMetadata

    func interrupt(
        _ identity: CodexInteractiveTurnIdentity
    ) async throws

    func nextValidatedNotification() async throws -> Data

    func retire() async throws
}

package struct CodexInteractiveAppServerConfiguration: Sendable {
    package let runtimeHomeURL: URL
    package let workingDirectoryURL: URL
    package let projectedAuthSourceURL: URL
    package let outputSchema: JSONValue
    package let maximumLineBytes: Int
    package let maximumInputTextBytes: Int

    package init(
        runtimeHomeURL: URL,
        workingDirectoryURL: URL,
        projectedAuthSourceURL: URL,
        outputSchema: JSONValue,
        maximumLineBytes: Int = 2 * 1_024 * 1_024,
        maximumInputTextBytes: Int = 256 * 1_024
    ) {
        self.runtimeHomeURL = runtimeHomeURL
        self.workingDirectoryURL = workingDirectoryURL
        self.projectedAuthSourceURL = projectedAuthSourceURL
        self.outputSchema = outputSchema
        self.maximumLineBytes = maximumLineBytes
        self.maximumInputTextBytes = maximumInputTextBytes
    }
}

package struct CodexInteractiveRootIdentity: Sendable, Equatable {
    package let id: String
    package let sessionID: String

    package init(id: String, sessionID: String) {
        self.id = id
        self.sessionID = sessionID
    }
}

package struct CodexInteractiveTurnIdentity: Sendable, Equatable {
    package let threadID: String
    package let turnID: String

    package init(threadID: String, turnID: String) {
        self.threadID = threadID
        self.turnID = turnID
    }
}

package struct CodexInteractiveThreadMetadata: Sendable, Equatable {
    package let id: String
    package let parentThreadID: String?
    package let sessionID: String

    package init(
        id: String,
        parentThreadID: String?,
        sessionID: String
    ) {
        self.id = id
        self.parentThreadID = parentThreadID
        self.sessionID = sessionID
    }
}

package enum CodexInteractiveAppServerError:
    Error,
    Sendable,
    Equatable
{
    case invalidConfiguration
    case invalidState
    case invalidLine
    case inputLimitExceeded
    case unexpectedEOF
    case unexpectedResponse(reasonKey: String)
    case unexpectedRequest(reasonKey: String)
    case unexpectedNotification(reasonKey: String)
    case identityMismatch(reasonKey: String)
    case authenticationRefreshBlocked
    case transportFailed
}

package actor CodexInteractiveAppServerClient:
    CodexInteractiveSessionDriving
{
    private typealias ResponseContinuation = CheckedContinuation<
        [String: JSONValue],
        any Error
    >
    private typealias NotificationContinuation = CheckedContinuation<
        Data,
        any Error
    >

    private enum State {
        case ready
        case preparingRoot
        case active
        case failed
        case retired
    }

    private static let provider = CodexRuntimeProvider.openAI.rawValue
    private static let model = CodexRuntimeModel.gpt56Luna.rawValue
    private static let investigationNotificationMethods: Set<String> = [
        "item/completed",
        "item/started",
        "thread/started",
        "thread/tokenUsage/updated",
        "turn/completed",
        "turn/started",
    ]
    private static let ignoredNotificationMethods: Set<String> = [
        "account/login/completed",
        "account/rateLimits/updated",
        "account/updated",
        "remoteControl/status/changed",
        "thread/status/changed",
    ]

    private let configuration: CodexInteractiveAppServerConfiguration
    private let transport: any CodexInteractiveAppServerTransport
    private var authProjection: CodexRuntimeAuthProjection
    private let refreshProvider:
        (any CodexRuntimeAuthRefreshProviding)?
    private var state = State.ready
    private var nextRequestID = 1
    private var pendingResponses: [Int: ResponseContinuation] = [:]
    private var notificationWaiter: NotificationContinuation?
    private var queuedNotifications: [Data] = []
    private var readTask: Task<Void, Never>?
    private var root: CodexInteractiveRootIdentity?
    private var admittedTurns = Set<CodexInteractiveTurnIdentityKey>()
    private var refreshUsed = false

    package init(
        configuration: CodexInteractiveAppServerConfiguration,
        transport: any CodexInteractiveAppServerTransport
    ) throws {
        let projector = CodexRuntimeAuthProjector()
        let projection = try projector.read(
            from: configuration.projectedAuthSourceURL
        )
        try self.init(
            configuration: configuration,
            transport: transport,
            authProjection: projection,
            refreshProvider: CodexRuntimeFileAuthRefreshProvider(
                sourceURL: projection.sourceURL,
                sourceIdentity: projection.sourceIdentity,
                projector: projector
            )
        )
    }

    init(
        configuration: CodexInteractiveAppServerConfiguration,
        transport: any CodexInteractiveAppServerTransport,
        authProjection: CodexRuntimeAuthProjection,
        refreshProvider: (any CodexRuntimeAuthRefreshProviding)?
    ) throws {
        guard
            Self.validAbsoluteURL(configuration.runtimeHomeURL),
            Self.validAbsoluteURL(configuration.workingDirectoryURL),
            Self.validAbsoluteURL(configuration.projectedAuthSourceURL),
            configuration.projectedAuthSourceURL.standardizedFileURL
                == authProjection.sourceURL.standardizedFileURL,
            configuration.maximumLineBytes > 0,
            configuration.maximumInputTextBytes > 0,
            Self.closedOutputSchema(configuration.outputSchema),
            let schemaData = try? JSONEncoder().encode(
                configuration.outputSchema
            ),
            schemaData.count <= 256 * 1_024
        else {
            throw CodexInteractiveAppServerError.invalidConfiguration
        }
        self.configuration = configuration
        self.transport = transport
        self.authProjection = authProjection
        self.refreshProvider = refreshProvider
    }

    package func prepareRoot() async throws
        -> CodexInteractiveRootIdentity
    {
        guard state == .ready else {
            throw CodexInteractiveAppServerError.invalidState
        }
        state = .preparingRoot
        do {
            let initialized = try await request(
                method: "initialize",
                params: .object([
                    "capabilities": .object([
                        "experimentalApi": .bool(true),
                        "optOutNotificationMethods": .array([
                            .string("item/agentMessage/delta"),
                            .string(
                                "item/commandExecution/terminalInteraction"
                            ),
                            .string("item/plan/delta"),
                            .string("item/reasoning/summaryPartAdded"),
                            .string("item/reasoning/summaryTextDelta"),
                            .string("turn/plan/updated"),
                        ]),
                    ]),
                    "clientInfo": .object([
                        "name": .string("stornaut"),
                        "title": .string("Stornaut"),
                        "version": .string("1"),
                    ]),
                ])
            )
            let initializeResult = try requiredObject(
                initialized["result"],
                reasonKey: "initialize-result"
            )
            guard canonicalPath(
                string(initializeResult["codexHome"])
            ) == canonicalPath(configuration.runtimeHomeURL.path) else {
                throw CodexInteractiveAppServerError.identityMismatch(
                    reasonKey: "initialize-codex-home"
                )
            }
            try await writeNotification(method: "initialized")

            let login = try await request(
                method: "account/login/start",
                params: .object(loginObject(currentCredentials()))
            )
            let loginResult = try requiredObject(
                login["result"],
                reasonKey: "login-result"
            )
            guard
                string(loginResult["type"])
                    == loginType(currentCredentials())
            else {
                throw CodexInteractiveAppServerError.unexpectedResponse(
                    reasonKey: "login-response-shape"
                )
            }

            let response = try await request(
                method: "thread/start",
                params: .object([
                    "approvalPolicy": .string("never"),
                    "cwd": .string(configuration.workingDirectoryURL.path),
                    "ephemeral": .bool(true),
                    "model": .string(Self.model),
                    "modelProvider": .string(Self.provider),
                ])
            )
            let result = try requiredObject(
                response["result"],
                reasonKey: "thread-start-result"
            )
            let thread = try requiredObject(
                result["thread"],
                reasonKey: "thread-start-thread"
            )
            let activePermissionProfile = try requiredObject(
                result["activePermissionProfile"],
                reasonKey: "thread-start-permission-profile"
            )
            guard
                let threadID = boundedIdentifier(string(thread["id"])),
                let sessionID = boundedIdentifier(
                    string(thread["sessionId"])
                ),
                threadID == sessionID,
                bool(thread["ephemeral"]) == true,
                string(thread["modelProvider"]) == Self.provider,
                string(result["approvalPolicy"]) == "never",
                string(result["model"]) == Self.model,
                string(result["modelProvider"]) == Self.provider,
                string(activePermissionProfile["id"])
                    == CodexContainmentPolicy.profileName,
                array(result["instructionSources"])?.isEmpty == true,
                canonicalPath(string(result["cwd"]))
                    == canonicalPath(
                        configuration.workingDirectoryURL.path
                    )
            else {
                throw CodexInteractiveAppServerError.identityMismatch(
                    reasonKey: "thread-start-root-identity"
                )
            }
            let root = CodexInteractiveRootIdentity(
                id: threadID,
                sessionID: sessionID
            )
            self.root = root
            state = .active
            return root
        } catch {
            fail(error)
            throw error
        }
    }

    package func startTurn(
        threadID: String,
        inputTexts: [String]
    ) async throws -> CodexInteractiveTurnIdentity {
        guard
            state == .active,
            let root,
            boundedIdentifier(threadID) != nil,
            !inputTexts.isEmpty,
            inputTexts.count <= 8,
            inputTexts.allSatisfy({
                !$0.isEmpty
                    && $0.utf8.count
                        <= configuration.maximumInputTextBytes
                    && !$0.utf8.contains(0)
            })
        else {
            throw CodexInteractiveAppServerError.invalidState
        }
        let cumulativeBytes = inputTexts.reduce(0) { total, text in
            let result = total.addingReportingOverflow(
                text.utf8.count
            )
            return result.overflow ? Int.max : result.partialValue
        }
        guard cumulativeBytes <= configuration.maximumInputTextBytes else {
            throw CodexInteractiveAppServerError.inputLimitExceeded
        }
        let input: [JSONValue] = inputTexts.map {
            .object([
                "text": .string($0),
                "textElements": .array([]),
                "type": .string("text"),
            ])
        }
        do {
            let response = try await request(
                method: "turn/start",
                params: .object([
                    "approvalPolicy": .string("never"),
                    "cwd": .string(
                        configuration.workingDirectoryURL.path
                    ),
                    "input": .array(input),
                    "model": .string(Self.model),
                    "outputSchema": configuration.outputSchema,
                    "sandboxPolicy": .object([
                        "networkAccess": .string("enabled"),
                        "type": .string("externalSandbox"),
                    ]),
                    "threadId": .string(threadID),
                ])
            )
            let result = try requiredObject(
                response["result"],
                reasonKey: "turn-start-result"
            )
            let turn = try requiredObject(
                result["turn"],
                reasonKey: "turn-start-turn"
            )
            guard
                let turnID = boundedIdentifier(string(turn["id"])),
                string(turn["status"]) == "inProgress",
                array(turn["items"]) != nil
            else {
                throw CodexInteractiveAppServerError.identityMismatch(
                    reasonKey: "turn-start-identity"
                )
            }
            let identity = CodexInteractiveTurnIdentity(
                threadID: threadID,
                turnID: turnID
            )
            admittedTurns.insert(
                CodexInteractiveTurnIdentityKey(identity)
            )
            _ = root
            return identity
        } catch {
            fail(error)
            throw error
        }
    }

    package func readThread(
        threadID: String
    ) async throws -> CodexInteractiveThreadMetadata {
        guard
            state == .active,
            let root,
            boundedIdentifier(threadID) != nil
        else {
            throw CodexInteractiveAppServerError.invalidState
        }
        do {
            let response = try await request(
                method: "thread/read",
                params: .object([
                    "includeTurns": .bool(false),
                    "threadId": .string(threadID),
                ])
            )
            let result = try requiredObject(
                response["result"],
                reasonKey: "thread-read-result"
            )
            let thread = try requiredObject(
                result["thread"],
                reasonKey: "thread-read-thread"
            )
            guard
                let observedID = boundedIdentifier(string(thread["id"])),
                observedID == threadID,
                let sessionID = boundedIdentifier(
                    string(thread["sessionId"])
                ),
                sessionID == root.sessionID,
                let parent = optionalBoundedIdentifier(
                    thread["parentThreadId"]
                )
            else {
                throw CodexInteractiveAppServerError.identityMismatch(
                    reasonKey: "thread-read-identity"
                )
            }
            return CodexInteractiveThreadMetadata(
                id: observedID,
                parentThreadID: parent,
                sessionID: sessionID
            )
        } catch {
            fail(error)
            throw error
        }
    }

    package func interrupt(
        _ identity: CodexInteractiveTurnIdentity
    ) async throws {
        guard
            state == .active,
            admittedTurns.contains(
                CodexInteractiveTurnIdentityKey(identity)
            )
        else {
            throw CodexInteractiveAppServerError.invalidState
        }
        do {
            let response = try await request(
                method: "turn/interrupt",
                params: .object([
                    "threadId": .string(identity.threadID),
                    "turnId": .string(identity.turnID),
                ])
            )
            _ = try requiredObject(
                response["result"],
                reasonKey: "turn-interrupt-result"
            )
        } catch {
            fail(error)
            throw error
        }
    }

    package func nextValidatedNotification() async throws -> Data {
        guard state == .active else {
            throw CodexInteractiveAppServerError.invalidState
        }
        if !queuedNotifications.isEmpty {
            return queuedNotifications.removeFirst()
        }
        guard notificationWaiter == nil else {
            throw CodexInteractiveAppServerError.invalidState
        }
        return try await withCheckedThrowingContinuation {
            notificationWaiter = $0
            scheduleReadIfNeeded()
        }
    }

    package func retire() async throws {
        guard state != .retired else {
            throw CodexInteractiveAppServerError.invalidState
        }
        state = .retired
        let error = CodexInteractiveAppServerError.invalidState
        drainWaiters(error: error)
        readTask?.cancel()
        readTask = nil
        authProjection.erase()
        try await transport.retire()
    }

    private func request(
        method: String,
        params: JSONValue
    ) async throws -> [String: JSONValue] {
        guard state != .failed, state != .retired else {
            throw CodexInteractiveAppServerError.invalidState
        }
        let requestID = nextRequestID
        nextRequestID += 1
        let line = try encodeLine([
            "id": .number(requestID),
            "method": .string(method),
            "params": params,
        ])
        return try await withCheckedThrowingContinuation { continuation in
            pendingResponses[requestID] = continuation
            Task {
                await writePendingRequest(
                    line,
                    requestID: requestID
                )
            }
        }
    }

    private func writePendingRequest(
        _ line: Data,
        requestID: Int
    ) async {
        do {
            try await transport.writeLine(line)
            scheduleReadIfNeeded()
        } catch {
            guard let continuation = pendingResponses.removeValue(
                forKey: requestID
            ) else {
                return
            }
            let mapped = CodexInteractiveAppServerError.transportFailed
            continuation.resume(throwing: mapped)
            fail(mapped)
        }
    }

    private func writeNotification(method: String) async throws {
        do {
            try await transport.writeLine(
                try encodeLine(["method": .string(method)])
            )
        } catch {
            throw CodexInteractiveAppServerError.transportFailed
        }
    }

    private func scheduleReadIfNeeded() {
        guard
            readTask == nil,
            state != .failed,
            state != .retired,
            !pendingResponses.isEmpty || notificationWaiter != nil
        else {
            return
        }
        let transport = self.transport
        readTask = Task {
            do {
                let line = try await transport.readLine()
                await receiveLine(.success(line))
            } catch {
                await receiveLine(.failure(error))
            }
        }
    }

    private func receiveLine(_ result: Result<Data, any Error>) async {
        readTask = nil
        guard state != .retired, state != .failed else {
            return
        }
        do {
            let line = try result.get()
            let object = try decodeLine(line)
            if object["method"] != nil, object["id"] != nil {
                try await handleServerRequest(object)
            } else if object["id"] != nil {
                try handleResponse(object)
            } else {
                try handleNotification(object, line: line)
            }
        } catch {
            let mapped = mapError(error)
            fail(mapped)
        }
        scheduleReadIfNeeded()
    }

    private func handleResponse(
        _ object: [String: JSONValue]
    ) throws {
        guard
            let requestID = integer(object["id"]),
            let continuation = pendingResponses.removeValue(
                forKey: requestID
            )
        else {
            throw CodexInteractiveAppServerError.unexpectedResponse(
                reasonKey: "response-id"
            )
        }
        if object["error"] != nil {
            continuation.resume(
                throwing:
                    CodexInteractiveAppServerError.unexpectedResponse(
                        reasonKey: "server-error"
                    )
            )
            return
        }
        continuation.resume(returning: object)
    }

    private func handleNotification(
        _ object: [String: JSONValue],
        line: Data
    ) throws {
        guard let method = string(object["method"]) else {
            throw CodexInteractiveAppServerError.invalidLine
        }
        if method == "thread/started", root == nil {
            throw CodexInteractiveAppServerError
                .unexpectedNotification(
                    reasonKey: "thread-start-before-response"
                )
        }
        if method == "turn/started" {
            let params = try requiredObject(
                object["params"],
                reasonKey: "turn-started-params"
            )
            let turn = try requiredObject(
                params["turn"],
                reasonKey: "turn-started-turn"
            )
            let identity = CodexInteractiveTurnIdentity(
                threadID: string(params["threadId"]) ?? "",
                turnID: string(turn["id"]) ?? ""
            )
            guard admittedTurns.contains(
                CodexInteractiveTurnIdentityKey(identity)
            ) else {
                throw CodexInteractiveAppServerError
                    .unexpectedNotification(
                        reasonKey: "turn-start-before-response"
                    )
            }
        }
        if Self.investigationNotificationMethods.contains(method) {
            if let waiter = notificationWaiter {
                notificationWaiter = nil
                waiter.resume(returning: line)
            } else {
                guard queuedNotifications.count < 256 else {
                    throw CodexInteractiveAppServerError.inputLimitExceeded
                }
                queuedNotifications.append(line)
            }
            return
        }
        guard Self.ignoredNotificationMethods.contains(method) else {
            throw CodexInteractiveAppServerError
                .unexpectedNotification(reasonKey: "unknown-method")
        }
        try validateIgnoredNotification(method, object: object)
    }

    private func validateIgnoredNotification(
        _ method: String,
        object: [String: JSONValue]
    ) throws {
        let params = try requiredObject(
            object["params"],
            reasonKey: "ignored-notification-params"
        )
        switch method {
        case "account/login/completed":
            guard
                bool(params["success"]) == true,
                params["loginId"] == .null,
                params["error"] == .null
            else {
                throw CodexInteractiveAppServerError
                    .unexpectedNotification(
                        reasonKey: "account-login-completed"
                    )
            }
        case "account/updated":
            guard
                string(params["authMode"])
                    == notificationAuthMode(currentCredentials())
            else {
                throw CodexInteractiveAppServerError
                    .unexpectedNotification(
                        reasonKey: "account-updated"
                    )
            }
        case "remoteControl/status/changed":
            guard
                string(params["status"]) == "disabled",
                params["environmentId"] == .null
            else {
                throw CodexInteractiveAppServerError
                    .unexpectedNotification(
                        reasonKey: "remote-control-status"
                    )
            }
        case "account/rateLimits/updated", "thread/status/changed":
            break
        default:
            throw CodexInteractiveAppServerError
                .unexpectedNotification(reasonKey: "unknown-method")
        }
    }

    private func handleServerRequest(
        _ object: [String: JSONValue]
    ) async throws {
        guard
            state == .active,
            string(object["method"])
                == "account/chatgptAuthTokens/refresh",
            !refreshUsed,
            let identifier = object["id"],
            validRPCIdentifier(identifier),
            let refreshProvider,
            case let .chatGPT(_, currentAccountID, _)
                = currentCredentials()
        else {
            throw CodexInteractiveAppServerError
                .unexpectedRequest(reasonKey: "unsupported-request")
        }
        let params = try requiredObject(
            object["params"],
            reasonKey: "auth-refresh-params"
        )
        guard
            string(params["reason"]) == "unauthorized",
            string(params["previousAccountId"]) == currentAccountID
        else {
            throw CodexInteractiveAppServerError
                .authenticationRefreshBlocked
        }
        let refreshed: CodexRuntimeAuthProjection
        do {
            refreshed = try refreshProvider.refresh()
        } catch {
            throw CodexInteractiveAppServerError
                .authenticationRefreshBlocked
        }
        let credentials = refreshed.withCredentials { $0 }
        guard
            refreshed.sourceIdentity == authProjection.sourceIdentity,
            refreshed.sourceURL.standardizedFileURL
                == configuration.projectedAuthSourceURL.standardizedFileURL,
            case let .chatGPT(_, accountID, _) = credentials,
            accountID == currentAccountID
        else {
            refreshed.erase()
            throw CodexInteractiveAppServerError.identityMismatch(
                reasonKey: "auth-refresh-identity"
            )
        }
        refreshUsed = true
        authProjection.erase()
        authProjection = refreshed
        do {
            try await transport.writeLine(
                try encodeLine([
                    "id": identifier,
                    "result": .object(authObject(credentials)),
                ])
            )
        } catch {
            throw CodexInteractiveAppServerError.transportFailed
        }
    }

    private func fail(_ error: any Error) {
        guard state != .retired, state != .failed else {
            return
        }
        state = .failed
        authProjection.erase()
        drainWaiters(error: mapError(error))
        readTask?.cancel()
        readTask = nil
    }

    private func drainWaiters(error: any Error) {
        let pending = pendingResponses.values
        pendingResponses.removeAll()
        pending.forEach { $0.resume(throwing: error) }
        if let waiter = notificationWaiter {
            notificationWaiter = nil
            waiter.resume(throwing: error)
        }
    }

    private func mapError(
        _ error: any Error
    ) -> CodexInteractiveAppServerError {
        if let error = error as? CodexInteractiveAppServerError {
            return error
        }
        return CodexInteractiveAppServerError.transportFailed
    }

    private func currentCredentials() -> CodexRuntimeAuthCredentials {
        authProjection.withCredentials { $0 }
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
        var result = authObject(credentials)
        result["type"] = .string("chatgptAuthTokens")
        return result
    }

    private func loginType(
        _ credentials: CodexRuntimeAuthCredentials
    ) -> String {
        switch credentials {
        case .chatGPT:
            "chatgptAuthTokens"
        }
    }

    private func notificationAuthMode(
        _ credentials: CodexRuntimeAuthCredentials
    ) -> String {
        switch credentials {
        case .chatGPT:
            "chatgptAuthTokens"
        }
    }

    private func encodeLine(
        _ object: [String: JSONValue]
    ) throws -> Data {
        var data = try JSONEncoder().encode(JSONValue.object(object))
        guard data.count + 1 <= configuration.maximumLineBytes else {
            throw CodexInteractiveAppServerError.inputLimitExceeded
        }
        data.append(0x0A)
        return data
    }

    private func decodeLine(
        _ line: Data
    ) throws -> [String: JSONValue] {
        guard
            !line.isEmpty,
            line.count <= configuration.maximumLineBytes,
            line.last == 0x0A,
            line.dropLast().firstIndex(of: 0x0A) == nil,
            case let .object(object) = try JSONDecoder().decode(
                JSONValue.self,
                from: line.dropLast()
            )
        else {
            throw CodexInteractiveAppServerError.invalidLine
        }
        return object
    }

    private func requiredObject(
        _ value: JSONValue?,
        reasonKey: String
    ) throws -> [String: JSONValue] {
        guard case let .object(object)? = value else {
            throw CodexInteractiveAppServerError.unexpectedResponse(
                reasonKey: reasonKey
            )
        }
        return object
    }

    private func optionalBoundedIdentifier(
        _ value: JSONValue?
    ) -> String?? {
        if value == nil || value == .null {
            return .some(nil)
        }
        guard let identifier = boundedIdentifier(string(value)) else {
            return nil
        }
        return .some(.some(identifier))
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
            .standardizedFileURL.path
    }

    private func validRPCIdentifier(_ value: JSONValue) -> Bool {
        switch value {
        case let .string(value):
            boundedIdentifier(value) != nil
        case let .number(value):
            value >= 0
        case .array, .bool, .null, .object:
            false
        }
    }

    private static func validAbsoluteURL(_ url: URL) -> Bool {
        url.isFileURL
            && url.path.hasPrefix("/")
            && url.path.unicodeScalars.allSatisfy({
                $0.value >= 0x20 && $0.value != 0x7F
            })
    }

    private static func closedOutputSchema(
        _ schema: JSONValue
    ) -> Bool {
        guard
            case let .object(object) = schema,
            object["type"] == .string("object"),
            object["additionalProperties"] == .bool(false),
            case .object? = object["properties"],
            case .array? = object["required"]
        else {
            return false
        }
        return true
    }
}

private struct CodexInteractiveTurnIdentityKey: Hashable {
    let threadID: String
    let turnID: String

    init(_ identity: CodexInteractiveTurnIdentity) {
        threadID = identity.threadID
        turnID = identity.turnID
    }
}

private func string(_ value: JSONValue?) -> String? {
    guard case let .string(value)? = value else {
        return nil
    }
    return value
}

private func integer(_ value: JSONValue?) -> Int? {
    guard case let .number(value)? = value else {
        return nil
    }
    return value
}

private func bool(_ value: JSONValue?) -> Bool? {
    guard case let .bool(value)? = value else {
        return nil
    }
    return value
}

private func array(_ value: JSONValue?) -> [JSONValue]? {
    guard case let .array(value)? = value else {
        return nil
    }
    return value
}
