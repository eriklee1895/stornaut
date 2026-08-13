import Foundation

struct CodexProviderCatalogPreflightRequest: Sendable, Equatable {
    let runtimeHomeURL: URL
    let workingDirectoryURL: URL
    let targetModel: CodexRuntimeModel
    let maximumInputLineBytes: Int
    let maximumCatalogModels: Int

    init(
        runtimeHomeURL: URL,
        workingDirectoryURL: URL,
        targetModel: CodexRuntimeModel,
        maximumInputLineBytes: Int = 1 * 1_024 * 1_024,
        maximumCatalogModels: Int = 1_000
    ) {
        self.runtimeHomeURL = runtimeHomeURL
        self.workingDirectoryURL = workingDirectoryURL
        self.targetModel = targetModel
        self.maximumInputLineBytes = maximumInputLineBytes
        self.maximumCatalogModels = maximumCatalogModels
    }
}

enum CodexProviderCatalogPreflightStatus: Sendable, Equatable {
    case ready
    case running
    case completed
    case failed
}

enum CodexProviderCatalogPreflightError:
    Error,
    Sendable,
    Equatable
{
    case invalidRequest
    case invalidState
    case inputLimitExceeded
    case invalidMessage
    case unexpectedMessage
    case serverError(code: Int)
    case unexpectedRequest(method: String)
    case unexpectedNotification(method: String)
    case identityMismatch
    case invalidCatalog
    case catalogLimitExceeded
}

struct CodexProviderCatalogCapabilities: Sendable, Equatable {
    let namespaceTools: Bool
    let imageGeneration: Bool
    let webSearch: Bool
}

enum CodexProviderSelectionSource:
    String,
    Sendable,
    Equatable
{
    case explicitConfiguration
    case codexBuiltInDefault
}

struct CodexProviderCatalogPreflightReport: Sendable, Equatable {
    let effectiveProviderID: String
    let providerSelectionSource: CodexProviderSelectionSource
    let configuredModelID: String?
    let targetModelID: String
    let targetModelAdvertised: Bool
    let catalogModelCount: Int
    let defaultModelID: String?
    let capabilities: CodexProviderCatalogCapabilities
}

final class CodexProviderCatalogPreflightRuntime: @unchecked Sendable {
    private enum Phase: Equatable {
        case ready
        case awaitingInitialize
        case awaitingConfig
        case awaitingCapabilities
        case awaitingModels(responseID: Int)
        case completed
        case failed
    }

    private let request: CodexProviderCatalogPreflightRequest
    private let lock = NSLock()
    private var phase: Phase = .ready
    private var effectiveProviderID: String?
    private var providerSelectionSource:
        CodexProviderSelectionSource?
    private var configuredModelID: String?
    private var capabilities: CodexProviderCatalogCapabilities?
    private var targetModelAdvertised = false
    private var catalogModelCount = 0
    private var defaultModelID: String?
    private var modelIDs = Set<String>()
    private var modelNames = Set<String>()
    private var cursors = Set<String>()
    private var completedReport: CodexProviderCatalogPreflightReport?

    init(request: CodexProviderCatalogPreflightRequest) throws {
        guard
            Self.validAbsolutePath(request.runtimeHomeURL),
            Self.validAbsolutePath(request.workingDirectoryURL),
            request.runtimeHomeURL.standardizedFileURL.path
                != request.workingDirectoryURL.standardizedFileURL.path,
            request.maximumInputLineBytes > 0,
            request.maximumCatalogModels > 0,
            request.maximumCatalogModels <= 10_000
        else {
            throw CodexProviderCatalogPreflightError.invalidRequest
        }
        self.request = request
    }

    var status: CodexProviderCatalogPreflightStatus {
        lock.withLock {
            switch phase {
            case .ready:
                .ready
            case .awaitingInitialize, .awaitingConfig,
                 .awaitingCapabilities, .awaitingModels:
                .running
            case .completed:
                .completed
            case .failed:
                .failed
            }
        }
    }

    var report: CodexProviderCatalogPreflightReport? {
        lock.withLock { completedReport }
    }

    func begin() throws -> [Data] {
        try lock.withLock {
            guard phase == .ready else {
                throw CodexProviderCatalogPreflightError.invalidState
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
            guard
                phase != .ready,
                phase != .completed,
                phase != .failed
            else {
                throw CodexProviderCatalogPreflightError.invalidState
            }
            do {
                let object = try decodeLine(line)
                if let method = string(object["method"]) {
                    guard
                        let boundedMethod = boundedMethod(method)
                    else {
                        throw CodexProviderCatalogPreflightError
                            .unexpectedMessage
                    }
                    if object["id"] != nil {
                        throw CodexProviderCatalogPreflightError
                            .unexpectedRequest(method: boundedMethod)
                    }
                    if
                        boundedMethod
                            == "remoteControl/status/changed"
                    {
                        let params = try requireObject(
                            object["params"]
                        )
                        guard
                            string(params["status"]) == "disabled",
                            params["environmentId"] == .null
                        else {
                            throw CodexProviderCatalogPreflightError
                                .unexpectedNotification(
                                    method: boundedMethod
                                )
                        }
                        return []
                    }
                    throw CodexProviderCatalogPreflightError
                        .unexpectedNotification(
                            method: boundedMethod
                        )
                }
                if let error = object["error"] {
                    let errorObject = try requireObject(error)
                    guard
                        case let .number(code) = errorObject["code"]
                    else {
                        throw CodexProviderCatalogPreflightError
                            .invalidMessage
                    }
                    throw CodexProviderCatalogPreflightError
                        .serverError(code: code)
                }
                return try processResponse(object)
            } catch {
                phase = .failed
                throw error
            }
        }
    }

    private func processResponse(
        _ object: [String: JSONValue]
    ) throws -> [Data] {
        switch phase {
        case .awaitingInitialize:
            try requireID(1, object: object)
            let result = try requireObject(object["result"])
            guard
                canonicalPath(string(result["codexHome"]))
                    == canonicalPath(request.runtimeHomeURL.path)
            else {
                throw CodexProviderCatalogPreflightError
                    .identityMismatch
            }
            phase = .awaitingConfig
            return [
                try encodeLine([
                    "method": .string("initialized"),
                ]),
                try encodeLine([
                    "id": .number(2),
                    "method": .string("config/read"),
                    "params": .object([
                        "cwd": .string(
                            request.workingDirectoryURL.path
                        ),
                        "includeLayers": .bool(false),
                    ]),
                ]),
            ]
        case .awaitingConfig:
            try requireID(2, object: object)
            let result = try requireObject(object["result"])
            let config = try requireObject(result["config"])
            let provider: String
            let selectionSource: CodexProviderSelectionSource
            if
                let value = config["model_provider"],
                value != .null
            {
                guard
                    let configuredProvider = boundedIdentifier(
                        string(value)
                    )
                else {
                    throw CodexProviderCatalogPreflightError
                        .invalidMessage
                }
                provider = configuredProvider
                selectionSource = .explicitConfiguration
            } else {
                provider = "openai"
                selectionSource = .codexBuiltInDefault
            }
            let configuredModel: String?
            if
                let value = config["model"],
                value != .null
            {
                guard
                    let model = boundedIdentifier(string(value))
                else {
                    throw CodexProviderCatalogPreflightError
                        .invalidMessage
                }
                configuredModel = model
            } else {
                configuredModel = nil
            }
            if
                let layers = result["layers"],
                layers != .null
            {
                throw CodexProviderCatalogPreflightError.invalidMessage
            }
            _ = try requireObject(result["origins"])
            effectiveProviderID = provider
            providerSelectionSource = selectionSource
            configuredModelID = configuredModel
            phase = .awaitingCapabilities
            return [
                try encodeLine([
                    "id": .number(3),
                    "method": .string(
                        "modelProvider/capabilities/read"
                    ),
                    "params": .object([:]),
                ]),
            ]
        case .awaitingCapabilities:
            try requireID(3, object: object)
            let result = try requireObject(object["result"])
            guard
                let namespaceTools = bool(result["namespaceTools"]),
                let imageGeneration = bool(
                    result["imageGeneration"]
                ),
                let webSearch = bool(result["webSearch"])
            else {
                throw CodexProviderCatalogPreflightError.invalidMessage
            }
            capabilities = CodexProviderCatalogCapabilities(
                namespaceTools: namespaceTools,
                imageGeneration: imageGeneration,
                webSearch: webSearch
            )
            phase = .awaitingModels(responseID: 4)
            return [try modelListRequest(id: 4, cursor: nil)]
        case let .awaitingModels(responseID):
            try requireID(responseID, object: object)
            let result = try requireObject(object["result"])
            let models = try requireArray(result["data"])
            guard
                catalogModelCount + models.count
                    <= request.maximumCatalogModels
            else {
                throw CodexProviderCatalogPreflightError
                    .catalogLimitExceeded
            }
            for modelValue in models {
                try recordModel(modelValue)
            }
            guard defaultModelCount <= 1 else {
                throw CodexProviderCatalogPreflightError.invalidCatalog
            }
            let nextCursor: String?
            if
                let value = result["nextCursor"],
                value != .null
            {
                guard
                    let cursor = boundedIdentifier(string(value)),
                    cursors.insert(cursor).inserted
                else {
                    throw CodexProviderCatalogPreflightError
                        .invalidCatalog
                }
                nextCursor = cursor
            } else {
                nextCursor = nil
            }
            if let nextCursor {
                let nextID = responseID + 1
                phase = .awaitingModels(responseID: nextID)
                return [
                    try modelListRequest(
                        id: nextID,
                        cursor: nextCursor
                    ),
                ]
            }
            guard
                let effectiveProviderID,
                let providerSelectionSource,
                let capabilities
            else {
                throw CodexProviderCatalogPreflightError.invalidState
            }
            completedReport = CodexProviderCatalogPreflightReport(
                effectiveProviderID: effectiveProviderID,
                providerSelectionSource: providerSelectionSource,
                configuredModelID: configuredModelID,
                targetModelID: request.targetModel.rawValue,
                targetModelAdvertised: targetModelAdvertised,
                catalogModelCount: catalogModelCount,
                defaultModelID: defaultModelID,
                capabilities: capabilities
            )
            phase = .completed
            return []
        case .ready, .completed, .failed:
            throw CodexProviderCatalogPreflightError.invalidState
        }
    }

    private func recordModel(_ value: JSONValue) throws {
        let object = try requireObject(value)
        guard
            let identifier = boundedIdentifier(string(object["id"])),
            let model = boundedIdentifier(string(object["model"])),
            let isDefault = bool(object["isDefault"]),
            modelIDs.insert(identifier).inserted,
            modelNames.insert(model).inserted
        else {
            throw CodexProviderCatalogPreflightError.invalidCatalog
        }
        catalogModelCount += 1
        if
            identifier == request.targetModel.rawValue
                || model == request.targetModel.rawValue
        {
            targetModelAdvertised = true
        }
        if isDefault {
            guard defaultModelID == nil else {
                throw CodexProviderCatalogPreflightError.invalidCatalog
            }
            defaultModelID = identifier
        }
    }

    private var defaultModelCount: Int {
        defaultModelID == nil ? 0 : 1
    }

    private func modelListRequest(
        id: Int,
        cursor: String?
    ) throws -> Data {
        var params: [String: JSONValue] = [
            "includeHidden": .bool(true),
            "limit": .number(100),
        ]
        if let cursor {
            params["cursor"] = .string(cursor)
        }
        return try encodeLine([
            "id": .number(id),
            "method": .string("model/list"),
            "params": .object(params),
        ])
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
                throw CodexProviderCatalogPreflightError
                    .inputLimitExceeded
            }
            throw CodexProviderCatalogPreflightError.invalidMessage
        }
        do {
            let value = try JSONDecoder().decode(
                JSONValue.self,
                from: data
            )
            return try requireObject(value)
        } catch let error as CodexProviderCatalogPreflightError {
            throw error
        } catch {
            throw CodexProviderCatalogPreflightError.invalidMessage
        }
    }

    private func encodeLine(
        _ object: [String: JSONValue]
    ) throws -> Data {
        var data = try JSONEncoder().encode(JSONValue.object(object))
        data.append(0x0A)
        return data
    }

    private func requireID(
        _ expected: Int,
        object: [String: JSONValue]
    ) throws {
        guard object["id"] == .number(expected) else {
            throw CodexProviderCatalogPreflightError
                .unexpectedMessage
        }
    }

    private func requireObject(
        _ value: JSONValue?
    ) throws -> [String: JSONValue] {
        guard case let .object(object) = value else {
            throw CodexProviderCatalogPreflightError.invalidMessage
        }
        return object
    }

    private func requireObject(
        _ value: JSONValue
    ) throws -> [String: JSONValue] {
        try requireObject(Optional(value))
    }

    private func requireArray(
        _ value: JSONValue?
    ) throws -> [JSONValue] {
        guard case let .array(array) = value else {
            throw CodexProviderCatalogPreflightError.invalidMessage
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
                (0x30...0x39).contains($0.value)
                    || (0x41...0x5A).contains($0.value)
                    || (0x61...0x7A).contains($0.value)
                    || $0.value == 0x2D
                    || $0.value == 0x2E
                    || $0.value == 0x3A
                    || $0.value == 0x5F
            })
        else {
            return nil
        }
        return value
    }

    private func boundedMethod(_ value: String) -> String? {
        guard
            !value.isEmpty,
            value.utf8.count <= 256,
            value.unicodeScalars.allSatisfy({
                (0x30...0x39).contains($0.value)
                    || (0x41...0x5A).contains($0.value)
                    || (0x61...0x7A).contains($0.value)
                    || $0.value == 0x2D
                    || $0.value == 0x2E
                    || $0.value == 0x2F
                    || $0.value == 0x3A
                    || $0.value == 0x5F
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

    private static func validAbsolutePath(_ url: URL) -> Bool {
        url.isFileURL
            && url.path.hasPrefix("/")
            && url.path.unicodeScalars.allSatisfy({
                $0.value >= 0x20 && $0.value != 0x7F
            })
    }
}
