import Foundation

public struct PathAction: Codable, Sendable, Equatable {
    public let targetURL: URL
    public let expectedIdentity: ActionFileIdentity

    public init(
        targetURL: URL,
        expectedIdentity: ActionFileIdentity
    ) {
        self.targetURL = targetURL
        self.expectedIdentity = expectedIdentity
    }
}

public enum RegisteredActionMode: String, Codable, Sendable, CaseIterable {
    case success
    case dryRun
    case timeout
    case partialFailure
}

public struct RegisteredActionRequest: Codable, Sendable, Equatable {
    public let id: String
    public let mode: RegisteredActionMode

    public init(id: String, mode: RegisteredActionMode) {
        self.id = id
        self.mode = mode
    }
}

public enum CleanupAction: Codable, Sendable, Equatable {
    case moveToTrash(PathAction)
    case runRegisteredAction(RegisteredActionRequest)
}
