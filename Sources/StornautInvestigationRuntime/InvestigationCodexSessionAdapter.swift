import Foundation
import StornautCodex
import StornautCore
import StornautInvestigation

package enum InvestigationCodexSessionAdapterError:
    Error,
    Sendable,
    Equatable
{
    case invalidIdentity
    case invalidState
    case invalidText
}

package final class InvestigationCodexSessionAdapter:
    InvestigationProductionSessionDriving,
    @unchecked Sendable
{
    private struct PreparedRoot: Sendable {
        let request: InvestigationRuntimeRootPreparationRequestV1
        let root: InvestigationRuntimeRootV1
    }

    private struct ActiveRun: Sendable {
        let investigationID: InvestigationID
        let runID: InvestigationRunID
        let root: InvestigationRuntimeRootV1
        var canonicalPrompt: String?
        var canonicalContext: String?
        var turnStartInProgress: Bool
    }

    private struct RunIdentity: Sendable {
        let investigationID: InvestigationID
        let runID: InvestigationRunID
    }

    private enum State: Sendable {
        case ready
        case preparing(RunIdentity)
        case prepared(PreparedRoot)
        case active(ActiveRun)
        case failed(RunIdentity)
        case retired
    }

    private let lock = NSLock()
    private let client: any CodexInteractiveSessionDriving
    private var state = State.ready

    package init(client: any CodexInteractiveSessionDriving) {
        self.client = client
    }

    package func prepareRoot(
        _ request: InvestigationRuntimeRootPreparationRequestV1
    ) async throws {
        try lock.withLock {
            guard case .ready = state else {
                throw InvestigationCodexSessionAdapterError.invalidState
            }
            state = .preparing(
                RunIdentity(
                    investigationID: request.investigationID,
                    runID: request.runID
                )
            )
        }
        do {
            let codexRoot = try await client.prepareRoot()
            guard
                let rootID = DomainToken(rawValue: codexRoot.id),
                let sessionID = DomainToken(
                    rawValue: codexRoot.sessionID
                ),
                rootID == sessionID
            else {
                throw InvestigationCodexSessionAdapterError
                    .invalidIdentity
            }
            try lock.withLock {
                guard
                    case let .preparing(identity) = state,
                    identity.investigationID == request.investigationID,
                    identity.runID == request.runID
                else {
                    throw InvestigationCodexSessionAdapterError
                        .invalidState
                }
                state = .prepared(
                    PreparedRoot(
                        request: request,
                        root: InvestigationRuntimeRootV1(
                            id: rootID,
                            sessionID: sessionID
                        )
                    )
                )
            }
        } catch {
            lock.withLock {
                if case .retired = state {
                    return
                }
                state = .failed(
                    RunIdentity(
                        investigationID: request.investigationID,
                        runID: request.runID
                    )
                )
            }
            throw error
        }
    }

    package func start(
        _ request: InvestigationRuntimeStartRequestV1
    ) throws -> InvestigationRuntimeRootV1 {
        try lock.withLock {
            guard
                case let .prepared(prepared) = state,
                request.investigationID
                    == prepared.request.investigationID,
                request.runID == prepared.request.runID,
                request.receiptID == prepared.request.receiptID,
                request.schema == prepared.request.schema,
                request.ephemeral,
                !request.context.promptText.isEmpty,
                !request.context.contextBytes.isEmpty,
                let contextText = String(
                    data: request.context.contextBytes,
                    encoding: .utf8
                ),
                !contextText.isEmpty
            else {
                throw InvestigationCodexSessionAdapterError.invalidState
            }
            state = .active(
                ActiveRun(
                    investigationID: request.investigationID,
                    runID: request.runID,
                    root: prepared.root,
                    canonicalPrompt: request.context.promptText,
                    canonicalContext: contextText,
                    turnStartInProgress: false
                )
            )
            return prepared.root
        }
    }

    package func startTurn(
        _ request: InvestigationRuntimeTurnStartRequestV1
    ) async throws -> InvestigationRuntimeTurnIdentityV1 {
        let input: (
            threadID: DomainToken,
            texts: [String],
            includesCanonical: Bool
        )
        do {
            input = try lock.withLock {
                guard
                    case var .active(active) = state,
                    !active.turnStartInProgress,
                    request.identity.investigationID
                        == active.investigationID,
                    request.identity.runID == active.runID,
                    let contextText = String(
                        data: request.contextBytes,
                        encoding: .utf8
                    ),
                    !contextText.isEmpty
                else {
                    throw InvestigationCodexSessionAdapterError
                        .invalidState
                }
                var texts = [String]()
                let includesCanonical = active.canonicalPrompt != nil
                if let prompt = active.canonicalPrompt,
                   let context = active.canonicalContext
                {
                    guard request.identity.threadID == active.root.id else {
                        throw InvestigationCodexSessionAdapterError
                            .invalidIdentity
                    }
                    texts.append(prompt)
                    texts.append(context)
                }
                texts.append(contextText)
                active.turnStartInProgress = true
                state = .active(active)
                return (
                    request.identity.threadID,
                    texts,
                    includesCanonical
                )
            }
        } catch {
            throw error
        }

        let codexIdentity: CodexInteractiveTurnIdentity
        do {
            codexIdentity = try await client.startTurn(
                threadID: input.threadID.rawValue,
                inputTexts: input.texts
            )
        } catch {
            fail()
            throw error
        }
        guard
            let threadID = DomainToken(
                rawValue: codexIdentity.threadID
            ),
            let turnID = DomainToken(rawValue: codexIdentity.turnID),
            threadID == input.threadID
        else {
            fail()
            throw InvestigationCodexSessionAdapterError.invalidIdentity
        }
        do {
            return try lock.withLock {
                guard case var .active(active) = state else {
                    throw InvestigationCodexSessionAdapterError
                        .invalidState
                }
                active.turnStartInProgress = false
                if input.includesCanonical {
                    active.canonicalPrompt = nil
                    active.canonicalContext = nil
                }
                state = .active(active)
                return InvestigationRuntimeTurnIdentityV1(
                    investigationID: request.identity.investigationID,
                    runID: request.identity.runID,
                    threadID: threadID,
                    turnID: turnID
                )
            }
        } catch {
            fail()
            throw error
        }
    }

    package func readThreadMetadata(
        threadID: DomainToken,
        rootSessionID: DomainToken
    ) async throws -> InvestigationRuntimeThreadMetadataV1 {
        try requireActiveRoot(rootSessionID)
        let metadata: CodexInteractiveThreadMetadata
        do {
            metadata = try await client.readThread(
                threadID: threadID.rawValue
            )
        } catch {
            fail()
            throw error
        }
        guard
            let observedID = DomainToken(rawValue: metadata.id),
            let sessionID = DomainToken(rawValue: metadata.sessionID),
            observedID == threadID,
            sessionID == rootSessionID
        else {
            fail()
            throw InvestigationCodexSessionAdapterError.invalidIdentity
        }
        let parentID: DomainToken?
        if let rawParentID = metadata.parentThreadID {
            guard let token = DomainToken(rawValue: rawParentID) else {
                fail()
                throw InvestigationCodexSessionAdapterError
                    .invalidIdentity
            }
            parentID = token
        } else {
            parentID = nil
        }
        return InvestigationRuntimeThreadMetadataV1(
            id: observedID,
            parentThreadID: parentID,
            sessionID: sessionID
        )
    }

    package func interrupt(
        _ turn: InvestigationRuntimeTurnIdentityV1
    ) async throws {
        try requireActiveRun(
            investigationID: turn.investigationID,
            runID: turn.runID
        )
        do {
            try await client.interrupt(
                CodexInteractiveTurnIdentity(
                    threadID: turn.threadID.rawValue,
                    turnID: turn.turnID.rawValue
                )
            )
        } catch {
            fail()
            throw error
        }
    }

    package func retireArtifacts(
        investigationID: InvestigationID,
        runID: InvestigationRunID
    ) async throws {
        try lock.withLock {
            let matches: Bool
            switch state {
            case let .prepared(prepared):
                matches =
                    prepared.request.investigationID == investigationID
                    && prepared.request.runID == runID
            case let .active(active):
                matches =
                    active.investigationID == investigationID
                    && active.runID == runID
            case let .failed(identity):
                matches =
                    identity.investigationID == investigationID
                    && identity.runID == runID
            case .ready, .preparing, .retired:
                matches = false
            }
            guard matches else {
                throw InvestigationCodexSessionAdapterError.invalidState
            }
            state = .retired
        }
        try await client.retire()
    }

    package func nextValidatedAppServerLine(
        rootSessionID: DomainToken
    ) async throws -> Data? {
        try requireActiveRoot(rootSessionID)
        do {
            return try await client.nextValidatedNotification()
        } catch {
            fail()
            throw error
        }
    }

    private func requireActiveRoot(
        _ rootSessionID: DomainToken
    ) throws {
        try lock.withLock {
            guard
                case let .active(active) = state,
                active.root.sessionID == rootSessionID
            else {
                throw InvestigationCodexSessionAdapterError.invalidState
            }
        }
    }

    private func requireActiveRun(
        investigationID: InvestigationID,
        runID: InvestigationRunID
    ) throws {
        try lock.withLock {
            guard
                case let .active(active) = state,
                active.investigationID == investigationID,
                active.runID == runID
            else {
                throw InvestigationCodexSessionAdapterError.invalidState
            }
        }
    }

    private func fail() {
        lock.withLock {
            let identity: RunIdentity?
            switch state {
            case let .preparing(value):
                identity = value
            case let .prepared(value):
                identity = RunIdentity(
                    investigationID: value.request.investigationID,
                    runID: value.request.runID
                )
            case let .active(value):
                identity = RunIdentity(
                    investigationID: value.investigationID,
                    runID: value.runID
                )
            case let .failed(value):
                identity = value
            case .ready, .retired:
                identity = nil
            }
            guard let identity else {
                return
            }
            state = .failed(identity)
        }
    }
}
