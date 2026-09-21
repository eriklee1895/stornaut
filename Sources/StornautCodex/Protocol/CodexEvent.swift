import Foundation

public struct CodexUsage: Sendable, Equatable {
    public let inputTokens: Int64
    public let cachedInputTokens: Int64
    public let cacheWriteInputTokens: Int64
    public let outputTokens: Int64
    public let reasoningOutputTokens: Int64

    public init(
        inputTokens: Int64,
        cachedInputTokens: Int64,
        cacheWriteInputTokens: Int64,
        outputTokens: Int64,
        reasoningOutputTokens: Int64
    ) {
        self.inputTokens = inputTokens
        self.cachedInputTokens = cachedInputTokens
        self.cacheWriteInputTokens = cacheWriteInputTokens
        self.outputTokens = outputTokens
        self.reasoningOutputTokens = reasoningOutputTokens
    }
}

public struct CodexItem: Sendable, Equatable {
    public let id: String
    public let type: String
    public let succeeded: Bool?
    let agentMessageText: String?

    init(
        id: String,
        type: String,
        succeeded: Bool?,
        agentMessageText: String?
    ) {
        self.id = id
        self.type = type
        self.succeeded = succeeded
        self.agentMessageText = agentMessageText
    }

    func redactedForStreaming() -> Self {
        Self(
            id: id,
            type: type,
            succeeded: succeeded,
            agentMessageText: nil
        )
    }
}

public struct UnknownCodexEvent: Sendable, Equatable {
    public let type: String
    public let metadata: [String: String]

    public init(type: String, metadata: [String: String]) {
        self.type = type
        self.metadata = metadata
    }
}

public enum CodexEvent: Sendable, Equatable {
    case threadStarted
    case turnStarted
    case turnCompleted(CodexUsage)
    case turnFailed
    case itemStarted(CodexItem)
    case itemCompleted(CodexItem)
    case error
    case unknown(UnknownCodexEvent)
}
