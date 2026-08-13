import Foundation

public enum LifecycleSupervisorXPCError:
    Error,
    Sendable,
    Equatable
{
    case invalidPeer
    case connectionFailed
    case invalidResponse
    case remoteRejected(reasonKey: String)
}

@objc public protocol LifecycleSupervisorXPCWire {
    func handle(
        _ request: Data,
        withReply reply: @escaping (Data?, String?) -> Void
    )
}

public struct LifecycleSupervisorXPCResponse:
    Codable,
    Sendable,
    Equatable
{
    private enum CodingKeys: String, CodingKey {
        case protocolVersion
        case status
        case callerAuthenticated
        case freshAuditSession
        case workerEvidenceReady
        case drained
        case staleRecoveryObserved
        case workerEvidence
    }

    public let protocolVersion: Int
    public let status: String
    public let callerAuthenticated: Bool
    public let freshAuditSession: Bool
    public let workerEvidenceReady: Bool
    public let drained: Bool
    public let staleRecoveryObserved: Bool
    public let workerEvidence: Data?

    public init(
        callerAuthenticated: Bool,
        freshAuditSession: Bool,
        workerEvidence: Data? = nil,
        drained: Bool = false,
        staleRecoveryObserved: Bool = false
    ) {
        protocolVersion = 1
        status = "accepted"
        self.callerAuthenticated = callerAuthenticated
        self.freshAuditSession = freshAuditSession
        workerEvidenceReady = workerEvidence != nil
        self.drained = drained
        self.staleRecoveryObserved = staleRecoveryObserved
        self.workerEvidence = workerEvidence
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(protocolVersion, forKey: .protocolVersion)
        try container.encode(status, forKey: .status)
        try container.encode(
            callerAuthenticated,
            forKey: .callerAuthenticated
        )
        try container.encode(
            freshAuditSession,
            forKey: .freshAuditSession
        )
        try container.encode(
            workerEvidenceReady,
            forKey: .workerEvidenceReady
        )
        try container.encode(drained, forKey: .drained)
        try container.encode(
            staleRecoveryObserved,
            forKey: .staleRecoveryObserved
        )
        if let workerEvidence {
            try container.encode(
                workerEvidence,
                forKey: .workerEvidence
            )
        } else {
            try container.encodeNil(forKey: .workerEvidence)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(
            decoder: decoder,
            expectedKeys: [
                "callerAuthenticated",
                "drained",
                "freshAuditSession",
                "protocolVersion",
                "staleRecoveryObserved",
                "status",
                "workerEvidence",
                "workerEvidenceReady",
            ]
        )
        let workerEvidence = try container.decodeIfPresent(
            Data.self,
            forKey: AnyLifecycleCodingKey("workerEvidence")
        )
        guard
            try container.decode(
                Int.self,
                forKey: AnyLifecycleCodingKey("protocolVersion")
            ) == 1,
            try container.decode(
                String.self,
                forKey: AnyLifecycleCodingKey("status")
            ) == "accepted",
            try container.decode(
                Bool.self,
                forKey: AnyLifecycleCodingKey(
                    "callerAuthenticated"
                )
            ),
            try container.decode(
                Bool.self,
                forKey: AnyLifecycleCodingKey(
                    "freshAuditSession"
                )
            ),
            let workerEvidenceReady = try? container.decode(
                Bool.self,
                forKey: AnyLifecycleCodingKey(
                    "workerEvidenceReady"
                )
            ),
            let drained = try? container.decode(
                Bool.self,
                forKey: AnyLifecycleCodingKey("drained")
            ),
            let staleRecoveryObserved = try? container.decode(
                Bool.self,
                forKey: AnyLifecycleCodingKey(
                    "staleRecoveryObserved"
                )
            ),
            workerEvidence.map({ $0.count <= 1_024 * 1_024 }) ?? true,
            workerEvidenceReady == (workerEvidence != nil)
        else {
            throw DecodingError.dataCorruptedError(
                forKey: AnyLifecycleCodingKey("status"),
                in: container,
                debugDescription: "Invalid lifecycle XPC response"
            )
        }
        protocolVersion = 1
        status = "accepted"
        callerAuthenticated = true
        freshAuditSession = true
        self.workerEvidenceReady = workerEvidenceReady
        self.drained = drained
        self.staleRecoveryObserved = staleRecoveryObserved
        self.workerEvidence = workerEvidence
    }
}

public actor LifecycleSupervisorXPCClient {
    public static let serviceName =
        "com.eriklee.stornaut.lifecycle"

    private let helperBundleURL: URL
    private let identityReader: LifecycleBundleSigningIdentityReader
    private var connection: NSXPCConnection?

    public init(
        helperBundleURL: URL,
        identityReader: LifecycleBundleSigningIdentityReader = .init()
    ) {
        self.helperBundleURL = helperBundleURL
        self.identityReader = identityReader
    }

    public func send(
        _ request: LifecycleSupervisorRequest
    ) async throws -> LifecycleSupervisorXPCResponse {
        let connection = try activeConnection()
        let data = try JSONEncoder().encode(request)
        return try await withCheckedThrowingContinuation {
            continuation in
            let resolver = LifecycleSupervisorXPCReplyResolver(
                continuation
            )
            let proxy = connection.remoteObjectProxyWithErrorHandler {
                _ in
                resolver.failConnection()
            }
            guard let wire = proxy as? LifecycleSupervisorXPCWire else {
                resolver.failConnection()
                return
            }
            wire.handle(data) { response, reasonKey in
                resolver.resolve(
                    response: response,
                    reasonKey: reasonKey
                )
            }
        }
    }

    public func invalidate() {
        connection?.invalidate()
        connection = nil
    }

    private func activeConnection() throws -> NSXPCConnection {
        if let connection {
            return connection
        }
        let identity: LifecycleSigningIdentity
        do {
            identity = try identityReader.read(
                bundleURL: helperBundleURL
            )
        } catch {
            throw LifecycleSupervisorXPCError.invalidPeer
        }
        let connection = NSXPCConnection(
            machServiceName: Self.serviceName,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(
            with: LifecycleSupervisorXPCWire.self
        )
        connection.setCodeSigningRequirement(
            LifecyclePeerCodeSigningRequirement.exact(
                identity: identity
            )
        )
        connection.resume()
        self.connection = connection
        return connection
    }
}

final class LifecycleSupervisorXPCReplyResolver:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var continuation:
        CheckedContinuation<LifecycleSupervisorXPCResponse, any Error>?

    init(
        _ continuation:
            CheckedContinuation<
                LifecycleSupervisorXPCResponse,
                any Error
            >
    ) {
        self.continuation = continuation
    }

    var hasPendingContinuation: Bool {
        lock.withLock { continuation != nil }
    }

    func failConnection() {
        finish(
            .failure(
                LifecycleSupervisorXPCError.connectionFailed
            )
        )
    }

    func resolve(
        response: Data?,
        reasonKey: String?
    ) {
        if let reasonKey {
            finish(
                .failure(
                    LifecycleSupervisorXPCError.remoteRejected(
                        reasonKey: reasonKey
                    )
                )
            )
            return
        }
        guard
            let response,
            let decoded = try? JSONDecoder().decode(
                LifecycleSupervisorXPCResponse.self,
                from: response
            )
        else {
            finish(
                .failure(
                    LifecycleSupervisorXPCError.invalidResponse
                )
            )
            return
        }
        finish(.success(decoded))
    }

    private func finish(
        _ result: Result<
            LifecycleSupervisorXPCResponse,
            any Error
        >
    ) {
        let continuation = lock.withLock {
            let value = self.continuation
            self.continuation = nil
            return value
        }
        continuation?.resume(with: result)
    }
}

public func lifecycleContainingAppURL(
    helperExecutableURL: URL
) -> URL? {
    guard
        helperExecutableURL.isFileURL,
        helperExecutableURL.lastPathComponent
            == "StornautLifecycleHelper",
        helperExecutableURL.deletingLastPathComponent()
            .lastPathComponent == "MacOS"
    else {
        return nil
    }
    let contents = helperExecutableURL
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let app = contents.deletingLastPathComponent()
    guard
        contents.lastPathComponent == "Contents",
        app.pathExtension == "app"
    else {
        return nil
    }
    return app.standardizedFileURL
}
