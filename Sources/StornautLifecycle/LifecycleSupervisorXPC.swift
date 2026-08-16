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

@objc public protocol LifecycleInteractiveSessionXPCWire:
    LifecycleSupervisorXPCWire
{
    func handleInteractive(
        _ request: Data,
        withReply reply: @escaping (Data?, String?) -> Void
    )
}

public enum LifecycleInteractiveSessionXPCError:
    Error,
    Sendable,
    Equatable
{
    case invalidPeer
    case connectionFailed
    case timedOut
    case cancelled
    case invalidResponse
    case remoteRejected(reasonKey: String)
}

public protocol LifecycleInteractiveSessionSending: Sendable {
    func send(
        _ request: LifecycleInteractiveSessionRequest
    ) async throws -> LifecycleInteractiveSessionResponse
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

public actor LifecycleInteractiveSessionXPCClient:
    LifecycleInteractiveSessionSending
{
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
        _ request: LifecycleInteractiveSessionRequest
    ) async throws -> LifecycleInteractiveSessionResponse {
        let connection = try activeConnection()
        let data: Data
        do {
            data = try JSONEncoder().encode(request)
            guard
                data.count <= LifecycleInteractiveSessionRequest
                    .maximumEncodedEnvelopeBytes
            else {
                throw LifecycleInteractiveSessionXPCError
                    .invalidResponse
            }
        } catch {
            if let error = error as? LifecycleInteractiveSessionXPCError {
                throw error
            }
            throw LifecycleInteractiveSessionXPCError.invalidResponse
        }
        let resolver = LifecycleInteractiveSessionXPCReplyResolver(
            request: request
        )
        return try await withTaskCancellationHandler {
            if request.kind != .retire {
                try Task.checkCancellation()
            }
            return try await withCheckedThrowingContinuation {
                continuation in
                guard resolver.install(continuation) else {
                    return
                }
                resolver.scheduleTimeout(
                    seconds: request.kind == .retire ? 45 : 15
                )
                let proxy = connection.remoteObjectProxyWithErrorHandler {
                    _ in
                    resolver.failConnection()
                }
                guard
                    let wire =
                        proxy as? LifecycleInteractiveSessionXPCWire
                else {
                    resolver.failConnection()
                    return
                }
                guard resolver.beginDispatch() else {
                    return
                }
                wire.handleInteractive(data) { response, reasonKey in
                    resolver.resolve(
                        response: response,
                        reasonKey: reasonKey
                    )
                }
            }
        } onCancel: {
            if request.kind != .retire {
                resolver.failCancellation()
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
            throw LifecycleInteractiveSessionXPCError.invalidPeer
        }
        let connection = NSXPCConnection(
            machServiceName: LifecycleSupervisorXPCClient.serviceName,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(
            with: LifecycleInteractiveSessionXPCWire.self
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

final class LifecycleInteractiveSessionXPCReplyResolver:
    @unchecked Sendable
{
    private let lock = NSLock()
    private let request: LifecycleInteractiveSessionRequest
    private var finished = false
    private var continuation:
        CheckedContinuation<
            LifecycleInteractiveSessionResponse,
            any Error
        >?
    private var pendingResult:
        Result<LifecycleInteractiveSessionResponse, any Error>?
    private var timeoutTask: Task<Void, Never>?
    private var dispatchBegan = false

    init(request: LifecycleInteractiveSessionRequest) {
        self.request = request
    }

    convenience init(
        request: LifecycleInteractiveSessionRequest,
        continuation:
            CheckedContinuation<
                LifecycleInteractiveSessionResponse,
                any Error
            >
    ) {
        self.init(request: request)
        _ = install(continuation)
    }

    func install(
        _ continuation:
            CheckedContinuation<
                LifecycleInteractiveSessionResponse,
                any Error
            >
    ) -> Bool {
        let pending = lock.withLock {
            if finished {
                return pendingResult
            }
            self.continuation = continuation
            return nil
        }
        if let pending {
            continuation.resume(with: pending)
            return false
        }
        return true
    }

    func scheduleTimeout(seconds: Int) {
        guard seconds > 0 else {
            failTimeout()
            return
        }
        let task = Task.detached(priority: nil) { [self] in
            do {
                try await Task.sleep(for: .seconds(seconds))
            } catch {
                return
            }
            failTimeout()
        }
        let cancel = lock.withLock {
            guard !finished else {
                return true
            }
            timeoutTask = task
            return false
        }
        if cancel {
            task.cancel()
        }
    }

    func beginDispatch() -> Bool {
        lock.withLock {
            guard !finished, !dispatchBegan else {
                return false
            }
            dispatchBegan = true
            return true
        }
    }

    func failConnection() {
        finish(
            .failure(
                LifecycleInteractiveSessionXPCError.connectionFailed
            )
        )
    }

    func failTimeout() {
        finish(
            .failure(
                LifecycleInteractiveSessionXPCError.timedOut
            )
        )
    }

    func failCancellation() {
        guard request.kind != .retire else {
            return
        }
        finish(
            .failure(
                LifecycleInteractiveSessionXPCError.cancelled
            ),
            onlyBeforeDispatch: true
        )
    }

    func resolve(
        response: Data?,
        reasonKey: String?
    ) {
        if let reasonKey {
            finish(
                .failure(
                    LifecycleInteractiveSessionXPCError.remoteRejected(
                        reasonKey:
                            sanitizedLifecycleInteractiveReasonKey(
                                reasonKey
                            )
                    )
                )
            )
            return
        }
        guard
            let response,
            response.count <= LifecycleInteractiveSessionRequest
                .maximumEncodedEnvelopeBytes,
            let decoded = try? JSONDecoder().decode(
                LifecycleInteractiveSessionResponse.self,
                from: response
            ),
            let validated = try? decoded.validated(for: request)
        else {
            finish(
                .failure(
                    LifecycleInteractiveSessionXPCError.invalidResponse
                )
            )
            return
        }
        finish(.success(validated))
    }

    private func finish(
        _ result: Result<
            LifecycleInteractiveSessionResponse,
            any Error
        >,
        onlyBeforeDispatch: Bool = false
    ) {
        let completion = lock.withLock {
            guard
                !finished,
                !onlyBeforeDispatch || !dispatchBegan
            else {
                return (
                    nil as CheckedContinuation<
                        LifecycleInteractiveSessionResponse,
                        any Error
                    >?,
                    nil as Task<Void, Never>?
                )
            }
            finished = true
            let value = self.continuation
            self.continuation = nil
            if value == nil {
                pendingResult = result
            }
            let timeout = timeoutTask
            timeoutTask = nil
            return (value, timeout)
        }
        completion.1?.cancel()
        completion.0?.resume(with: result)
    }
}

private func sanitizedLifecycleInteractiveReasonKey(
    _ value: String
) -> String {
    let allowed = Set([
        "runtime.lifecycle.interactive.invalid-request",
        "runtime.lifecycle.interactive.session-unavailable",
        "runtime.lifecycle.interactive.session-mismatch",
        "runtime.lifecycle.interactive.session-expired",
        "runtime.lifecycle.interactive.line-limit-exceeded",
        "runtime.lifecycle.interactive.session-limit-exceeded",
        "runtime.lifecycle.interactive.start-failed",
        "runtime.lifecycle.interactive.write-failed",
        "runtime.lifecycle.interactive.read-failed",
        "runtime.lifecycle.interactive.retire-failed",
        "runtime.lifecycle.interactive.remote-rejected",
    ])
    return allowed.contains(value)
        ? value
        : "runtime.lifecycle.interactive.remote-rejected"
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
