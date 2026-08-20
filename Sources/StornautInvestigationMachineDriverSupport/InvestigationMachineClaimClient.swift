import Darwin
import CryptoKit
import Foundation
import Security
import StornautInvestigationHandoffContract
package enum InvestigationMachineClaimClientError:
    Error,
    Sendable,
    Equatable
{
    case concurrentOperation
    case oneShotConsumed
    case invalidDeadline
    case unavailable
    case invalidPeer
    case protocolViolation
    case bindingMismatch
    case duplicateOrReplay
    case expired
    case helperIdentityMismatch
    case signingIdentityMismatch
    case outcomeUnknown
}
package struct InvestigationMachineClaimClientSharedDeadline:
    Sendable,
    Equatable
{
    package let epochDeadlineNanoseconds: UInt64

    package init(epochDeadlineNanoseconds: UInt64) throws {
        guard epochDeadlineNanoseconds > 0 else {
            throw InvestigationMachineClaimClientError.invalidDeadline
        }
        self.epochDeadlineNanoseconds = epochDeadlineNanoseconds
    }
}
package struct InvestigationMachineClaimClientStaticIdentityObservation:
    Sendable,
    Equatable
{
    package let executablePath: String
    package let signingIdentifier: String
    package let designatedRequirementSHA256: String
    package let codeDirectoryHash: String
    package let isAdHoc: Bool
}
package struct InvestigationMachineClaimClientDynamicIdentityObservation:
    Sendable,
    Equatable
{
    package let processID: UInt32
    package let processIDVersion: UInt32
    package let auditSessionID: UInt32
    package let effectiveUserID: UInt32
    package let executablePath: String
    package let signingIdentifier: String
    package let designatedRequirementSHA256: String
    package let codeDirectoryHash: String
    package let isAdHoc: Bool
}
package struct InvestigationMachineClaimClientConnectionIdentity:
    Sendable,
    Equatable
{
    package let serviceName: String
    package let processID: UInt32
    package let auditSessionID: UInt32
    package let effectiveUserID: UInt32
}
package struct InvestigationMachineClaimClientClockObservation:
    Sendable,
    Equatable
{
    package let continuousNanoseconds: UInt64
    package let wallUTCMicroseconds: InvestigationHandoffUTCMicroseconds
}
package enum InvestigationMachineClaimClientHelperEpoch:
    Sendable,
    Equatable
{
    case originalHelperAbsent
    case originalHelperPresent
}
package protocol InvestigationMachineClaimClientSession: Sendable {
    func currentConnectionIdentity() async throws
        -> InvestigationMachineClaimClientConnectionIdentity
    func claim(
        _ request: Data, deadlineNanoseconds: UInt64
    ) async throws -> (Data?, String?)
    func release(
        _ request: Data, deadlineNanoseconds: UInt64
    ) async throws -> (Data?, String?)
    func invalidate() async
}
package protocol InvestigationMachineClaimClientTransporting: Sendable {
    func connect(
        serviceName: String,
        codeSigningRequirement: String
    ) async throws -> any InvestigationMachineClaimClientSession
}
package protocol InvestigationMachineClaimClientStaticIdentityReading:
    Sendable
{
    func readHelperIdentity() throws
        -> InvestigationMachineClaimClientStaticIdentityObservation
}
package protocol InvestigationMachineClaimClientDynamicIdentityReading:
    Sendable
{
    func readHelperIdentity(
        auditTokenWords: [UInt32]
    ) throws -> InvestigationMachineClaimClientDynamicIdentityObservation
}
package protocol InvestigationMachineClaimClientHelperEpochObserving:
    Sendable
{
    func observe(
        serviceName: String,
        claimedHelperIdentity: InvestigationMachineProcessIdentity
    ) async throws -> InvestigationMachineClaimClientHelperEpoch
}
package protocol InvestigationMachineClaimClientClocking: Sendable {
    func observe() throws -> InvestigationMachineClaimClientClockObservation
    func sleep(untilNanoseconds deadlineNanoseconds: UInt64) async
}
package actor InvestigationMachineClaimClient {
    package enum Constants {
        package static let machineClaimServiceIdentifier =
            InvestigationMachineInstalledDriverObservation
            .fixedMachineClaimServiceIdentifier
        package static let helperExecutablePath =
            InvestigationMachineInstalledDriverObservation.fixedLifecycleProgram
        package static let helperSigningIdentifier =
            "com.eriklee.stornaut.lifecycle.helper"
    }

    private struct ClaimedState {
        let session: any InvestigationMachineClaimClientSession
        let evidence: InvestigationMachineClaimEvidence
        let sharedDeadline: InvestigationMachineClaimClientSharedDeadline
    }

    private enum State {
        case idle
        case claimed(ClaimedState)
        case consumed
    }

    private let transport: any InvestigationMachineClaimClientTransporting
    private let staticHelperIdentityReader:
        any InvestigationMachineClaimClientStaticIdentityReading
    private let dynamicHelperIdentityReader:
        any InvestigationMachineClaimClientDynamicIdentityReading
    private let helperEpochObserver:
        any InvestigationMachineClaimClientHelperEpochObserving
    private let clock: any InvestigationMachineClaimClientClocking
    private let uuid: @Sendable () -> UUID
    private var state: State = .idle
    private var operationInProgress = false
    package init() {
        self.init(
            transport: InvestigationMachineClaimClientTransport(),
            staticHelperIdentityReader:
                InvestigationMachineClaimClientStaticIdentityReader(),
            dynamicHelperIdentityReader:
                InvestigationMachineClaimClientDynamicIdentityReader(),
            helperEpochObserver:
                InvestigationMachineClaimClientHelperEpochObserver(),
            clock: InvestigationMachineClaimClientClock(),
            uuid: UUID.init
        )
    }
    init(
        transport: any InvestigationMachineClaimClientTransporting
            ,
        staticHelperIdentityReader:
            any InvestigationMachineClaimClientStaticIdentityReading
            ,
        dynamicHelperIdentityReader:
            any InvestigationMachineClaimClientDynamicIdentityReading
            ,
        helperEpochObserver:
            any InvestigationMachineClaimClientHelperEpochObserving
            ,
        clock: any InvestigationMachineClaimClientClocking
            ,
        uuid: @escaping @Sendable () -> UUID
    ) {
        self.transport = transport
        self.staticHelperIdentityReader = staticHelperIdentityReader
        self.dynamicHelperIdentityReader = dynamicHelperIdentityReader
        self.helperEpochObserver = helperEpochObserver
        self.clock = clock
        self.uuid = uuid
    }
    package func claim(
        handle: InvestigationHandoffRetirementHandle,
        appIdentity: InvestigationMachineProcessIdentity,
        sharedDeadline: InvestigationMachineClaimClientSharedDeadline,
        previousHelperIdentity: InvestigationMachineProcessIdentity?
    ) async throws -> InvestigationMachineClaimEvidence {
        try beginOperationForClaim()
        defer { operationInProgress = false }
        let staticObservation: InvestigationMachineClaimClientStaticIdentityObservation
        let claimObservation: InvestigationMachineClaimClientClockObservation
        let request: InvestigationMachineRetirementClaimRequest
        do {
            try Task.checkCancellation()
            staticObservation = try staticHelperIdentityObservation()
            claimObservation = try clock.observe()
            request = try makeClaimRequest(
                handle: handle,
                claimObservation: claimObservation,
                sharedDeadline: sharedDeadline
            )
        } catch let error as InvestigationMachineClaimClientError {
            throw error
        } catch {
            throw InvestigationMachineClaimClientError.unavailable
        }
        let session: any InvestigationMachineClaimClientSession
        do {
            session = try await transport.connect(
                serviceName: Constants.machineClaimServiceIdentifier,
                codeSigningRequirement:
                    exactCodeSigningRequirement(staticObservation)
            )
        } catch {
            throw InvestigationMachineClaimClientError.unavailable
        }

        do {
            guard !Task.isCancelled else {
                throw InvestigationMachineClaimClientError.unavailable
            }
            let reply: (Data?, String?)
            do {
                reply = try await session.claim(
                    request.encoded(),
                    deadlineNanoseconds:
                        sharedDeadline.epochDeadlineNanoseconds
                )
            } catch let error as InvestigationMachineClaimClientError
                where error == .unavailable
            {
                throw error
            } catch {
                throw InvestigationMachineClaimClientError.outcomeUnknown
            }
            let replyValue: InvestigationMachineClaimXPCReplyValue
            do {
                replyValue = try InvestigationMachineClaimXPCReply.validateClaim(
                    response: reply.0,
                    reasonKey: reply.1
                )
            } catch {
                throw InvestigationMachineClaimClientError.outcomeUnknown
            }
            let replyData: Data
            replyData = try requiredSuccessData(replyValue)
            let evidence: InvestigationMachineClaimEvidence
            do {
                evidence = try InvestigationMachineClaimEvidence.decode(replyData)
                try await validateClaimEvidence(
                    evidence,
                    request: request,
                    appIdentity: appIdentity,
                    session: session,
                    staticObservation: staticObservation
                )
            } catch {
                throw InvestigationMachineClaimClientError.outcomeUnknown
            }
            let replyObservation: InvestigationMachineClaimClientClockObservation
            do {
                replyObservation = try clock.observe()
            } catch {
                throw InvestigationMachineClaimClientError.outcomeUnknown
            }
            let maximum = replyObservation.continuousNanoseconds
                .addingReportingOverflow(
                    InvestigationMachineClaimRelease
                        .maximumReleaseWindowNanoseconds
                )
            guard
                !maximum.overflow,
                evidence.releaseDeadlineNanoseconds
                    > replyObservation.continuousNanoseconds,
                evidence.releaseDeadlineNanoseconds <= maximum.partialValue,
                evidence.releaseDeadlineNanoseconds
                    <= sharedDeadline.epochDeadlineNanoseconds
            else {
                throw InvestigationMachineClaimClientError.outcomeUnknown
            }
            guard
                previousHelperIdentity == nil
                    || previousHelperIdentity != evidence.helperIdentity
            else {
                throw InvestigationMachineClaimClientError.outcomeUnknown
            }
            do {
                try await validateConnectionIdentity(
                    session: session,
                    helperIdentity: evidence.helperIdentity
                )
            } catch {
                throw InvestigationMachineClaimClientError.outcomeUnknown
            }
            guard !Task.isCancelled else {
                throw InvestigationMachineClaimClientError.outcomeUnknown
            }
            state = .claimed(
                ClaimedState(
                    session: session,
                    evidence: evidence,
                    sharedDeadline: sharedDeadline
                )
            )
            return evidence
        } catch {
            await session.invalidate()
            throw error
        }
    }
    package func release() async throws -> InvestigationMachineClaimReleased {
        try beginOperationForRelease()
        defer { operationInProgress = false }
        guard case let .claimed(claimedState) = state else {
            throw InvestigationMachineClaimClientError.oneShotConsumed
        }
        state = .consumed
        do {
            do {
                try await validateConnectionIdentity(
                    session: claimedState.session,
                    helperIdentity: claimedState.evidence.helperIdentity
                )
                let releaseObservation = try clock.observe()
                guard
                    releaseObservation.continuousNanoseconds
                        < claimedState.sharedDeadline.epochDeadlineNanoseconds,
                    releaseObservation.continuousNanoseconds
                        < claimedState.evidence.releaseDeadlineNanoseconds,
                    claimedState.evidence.releaseDeadlineNanoseconds
                        <= claimedState.sharedDeadline.epochDeadlineNanoseconds
                else {
                    throw InvestigationMachineClaimClientError.expired
                }
                try Task.checkCancellation()
            } catch {
                throw InvestigationMachineClaimClientError.unavailable
            }
            let release = try InvestigationMachineClaimRelease(
                requestBindingSHA256: claimedState.evidence.requestBindingSHA256,
                releaseChallenge: uuid(),
                claimedHelperIdentitySHA256:
                    try claimedState.evidence.helperIdentity.helperIdentitySHA256(),
                claimConnectionEpoch: claimedState.evidence.claimConnectionEpoch,
                releaseDeadlineNanoseconds:
                    claimedState.evidence.releaseDeadlineNanoseconds
            )
            let reply: (Data?, String?)
            do {
                reply = try await claimedState.session.release(
                    release.encoded(),
                    deadlineNanoseconds:
                        claimedState.evidence.releaseDeadlineNanoseconds
                )
            } catch let error as InvestigationMachineClaimClientError
                where error == .unavailable
            {
                throw error
            } catch {
                throw InvestigationMachineClaimClientError.outcomeUnknown
            }
            let replyValue: InvestigationMachineClaimXPCReplyValue
            do {
                replyValue = try InvestigationMachineClaimXPCReply.validateRelease(
                    response: reply.0,
                    reasonKey: reply.1
                )
            } catch {
                throw InvestigationMachineClaimClientError.outcomeUnknown
            }
            let replyData: Data
            replyData = try requiredSuccessData(replyValue)
            let released: InvestigationMachineClaimReleased
            do {
                released = try InvestigationMachineClaimReleased.decode(replyData)
                try released.validateEcho(of: release)
            } catch {
                throw InvestigationMachineClaimClientError.outcomeUnknown
            }
            let replyObservation: InvestigationMachineClaimClientClockObservation
            do {
                replyObservation = try clock.observe()
            } catch {
                throw InvestigationMachineClaimClientError.outcomeUnknown
            }
            let maximum = replyObservation.continuousNanoseconds
                .addingReportingOverflow(
                    InvestigationMachineClaimReleased
                        .maximumPostReplyExitWindowNanoseconds
                )
            guard
                !maximum.overflow,
                replyObservation.continuousNanoseconds
                    < claimedState.evidence.releaseDeadlineNanoseconds,
                released.postReplyExitDeadlineNanoseconds
                    > replyObservation.continuousNanoseconds,
                released.postReplyExitDeadlineNanoseconds
                    <= maximum.partialValue,
                released.postReplyExitDeadlineNanoseconds
                    <= claimedState.sharedDeadline.epochDeadlineNanoseconds
            else {
                throw InvestigationMachineClaimClientError.outcomeUnknown
            }
            do {
                try await confirmHelperEpochTransition(
                    claimedState: claimedState,
                    released: released,
                    observedAt: replyObservation.continuousNanoseconds
                )
            } catch {
                throw InvestigationMachineClaimClientError.outcomeUnknown
            }
            guard !Task.isCancelled else {
                throw InvestigationMachineClaimClientError.outcomeUnknown
            }
            await claimedState.session.invalidate()
            return released
        } catch {
            await claimedState.session.invalidate()
            if error is CancellationError {
                throw InvestigationMachineClaimClientError.unavailable
            }
            throw error
        }
    }
    private func beginOperationForClaim() throws {
        guard !operationInProgress else {
            throw InvestigationMachineClaimClientError.concurrentOperation
        }
        guard case .idle = state else {
            throw InvestigationMachineClaimClientError.oneShotConsumed
        }
        operationInProgress = true
        state = .consumed
    }
    private func beginOperationForRelease() throws {
        guard !operationInProgress else {
            throw InvestigationMachineClaimClientError.concurrentOperation
        }
        guard case .claimed = state else {
            throw InvestigationMachineClaimClientError.oneShotConsumed
        }
        operationInProgress = true
    }
    private func makeClaimRequest(
        handle: InvestigationHandoffRetirementHandle,
        claimObservation: InvestigationMachineClaimClientClockObservation,
        sharedDeadline: InvestigationMachineClaimClientSharedDeadline
    ) throws -> InvestigationMachineRetirementClaimRequest {
        guard
            claimObservation.continuousNanoseconds
                < sharedDeadline.epochDeadlineNanoseconds
        else {
            throw InvestigationMachineClaimClientError.invalidDeadline
        }
        let remainingNanoseconds =
            sharedDeadline.epochDeadlineNanoseconds
            - claimObservation.continuousNanoseconds
        let remainingMicroseconds = Int64(
            min(
                remainingNanoseconds / 1_000,
                UInt64(
                    InvestigationMachineRetirementClaimRequest
                    .maximumWallWindowMicroseconds
                )
            )
        )
        guard remainingMicroseconds > 0 else {
            throw InvestigationMachineClaimClientError.invalidDeadline
        }
        let wallLimit = claimObservation.wallUTCMicroseconds.rawValue
            .addingReportingOverflow(remainingMicroseconds)
        guard !wallLimit.overflow else {
            throw InvestigationMachineClaimClientError.invalidDeadline
        }
        let requestValidBefore = try InvestigationHandoffUTCMicroseconds(
            rawValue: min(
                handle.validBefore.rawValue,
                wallLimit.partialValue
            )
        )
        guard requestValidBefore > claimObservation.wallUTCMicroseconds else {
            throw InvestigationMachineClaimClientError.invalidDeadline
        }
        return try InvestigationMachineRetirementClaimRequest(
            handle: handle,
            claimChallenge: uuid(),
            issuedAt: claimObservation.wallUTCMicroseconds,
            requestValidBefore: requestValidBefore,
            claimConnectionEpoch: uuid(),
            epochDeadlineNanoseconds: sharedDeadline.epochDeadlineNanoseconds
        )
    }
    private func staticHelperIdentityObservation() throws
        -> InvestigationMachineClaimClientStaticIdentityObservation {
        let observation = try staticHelperIdentityReader.readHelperIdentity()
        guard
            observation.executablePath == Constants.helperExecutablePath,
            observation.signingIdentifier == Constants.helperSigningIdentifier,
            observation.isAdHoc,
            machineClaimValidHex(
                observation.designatedRequirementSHA256, count: 64
            ),
            (machineClaimValidHex(observation.codeDirectoryHash, count: 40)
                || machineClaimValidHex(
                    observation.codeDirectoryHash, count: 64
                ))
        else {
            throw InvestigationMachineClaimClientError.signingIdentityMismatch
        }
        return observation
    }
    private func validateClaimEvidence(
        _ evidence: InvestigationMachineClaimEvidence,
        request: InvestigationMachineRetirementClaimRequest,
        appIdentity: InvestigationMachineProcessIdentity,
        session: any InvestigationMachineClaimClientSession,
        staticObservation: InvestigationMachineClaimClientStaticIdentityObservation
    ) async throws {
        let expectation = try InvestigationMachineClaimExpectation(
            request: request,
            appUserID: appIdentity.effectiveUserID,
            appIdentity: appIdentity,
            helperIdentity: evidence.helperIdentity
        )
        try evidence.validate(against: expectation)
        try await validateConnectionIdentity(
            session: session,
            helperIdentity: evidence.helperIdentity
        )
        let dynamicObservation = try dynamicHelperIdentityReader.readHelperIdentity(
            auditTokenWords: evidence.helperIdentity.auditTokenWords
        )
        guard
            dynamicObservation.processID == evidence.helperIdentity.processID,
            dynamicObservation.processIDVersion
                == evidence.helperIdentity.processIDVersion,
            dynamicObservation.auditSessionID
                == evidence.helperIdentity.auditSessionID,
            dynamicObservation.effectiveUserID
                == evidence.helperIdentity.effectiveUserID,
            dynamicObservation.executablePath == Constants.helperExecutablePath,
            dynamicObservation.isAdHoc
        else {
            throw InvestigationMachineClaimClientError.helperIdentityMismatch
        }
        guard
            dynamicObservation.signingIdentifier == staticObservation.signingIdentifier,
            dynamicObservation.designatedRequirementSHA256
                == staticObservation.designatedRequirementSHA256,
            dynamicObservation.codeDirectoryHash == staticObservation.codeDirectoryHash
        else {
            throw InvestigationMachineClaimClientError.signingIdentityMismatch
        }
        let finalStaticObservation = try staticHelperIdentityObservation()
        guard finalStaticObservation == staticObservation else {
            throw InvestigationMachineClaimClientError.signingIdentityMismatch
        }
        try await validateConnectionIdentity(
            session: session,
            helperIdentity: evidence.helperIdentity
        )
    }
    private func validateConnectionIdentity(
        session: any InvestigationMachineClaimClientSession,
        helperIdentity: InvestigationMachineProcessIdentity
    ) async throws {
        let connectionIdentity = try await session.currentConnectionIdentity()
        guard
            connectionIdentity.serviceName == Constants.machineClaimServiceIdentifier,
            connectionIdentity.processID == helperIdentity.processID,
            connectionIdentity.auditSessionID == helperIdentity.auditSessionID,
            connectionIdentity.effectiveUserID
                == helperIdentity.effectiveUserID
        else {
            throw InvestigationMachineClaimClientError.helperIdentityMismatch
        }
    }
    private func confirmHelperEpochTransition(
        claimedState: ClaimedState,
        released: InvestigationMachineClaimReleased,
        observedAt: UInt64
    ) async throws {
        let deadline = min(
            claimedState.sharedDeadline.epochDeadlineNanoseconds,
            released.postReplyExitDeadlineNanoseconds
        )
        var current = observedAt
        while current < deadline {
            guard !Task.isCancelled else {
                throw InvestigationMachineClaimClientError.outcomeUnknown
            }
            let observation = try await helperEpochObserver.observe(
                serviceName: Constants.machineClaimServiceIdentifier,
                claimedHelperIdentity: claimedState.evidence.helperIdentity
            )
            let afterObservation = try clock.observe().continuousNanoseconds
            guard
                !Task.isCancelled,
                afterObservation >= current,
                afterObservation < deadline
            else {
                throw InvestigationMachineClaimClientError.outcomeUnknown
            }
            if observation == .originalHelperAbsent { return }
            let next = min(
                deadline,
                afterObservation.addingReportingOverflow(100_000_000)
                    .partialValue
            )
            guard next > afterObservation, next < deadline else {
                throw InvestigationMachineClaimClientError.outcomeUnknown
            }
            await clock.sleep(untilNanoseconds: next)
            let sampled = try clock.observe().continuousNanoseconds
            guard
                !Task.isCancelled,
                sampled >= next,
                sampled <= deadline
            else {
                throw InvestigationMachineClaimClientError.outcomeUnknown
            }
            current = sampled
        }
        throw InvestigationMachineClaimClientError.outcomeUnknown
    }
    private func requiredSuccessData(
        _ value: InvestigationMachineClaimXPCReplyValue
    ) throws -> Data {
        switch value {
        case let .success(data):
            return data
        case let .failure(reason):
            throw error(for: reason)
        }
    }
    private func error(
        for reason: InvestigationMachineClaimXPCReason
    ) -> InvestigationMachineClaimClientError {
        switch reason {
        case .invalidRequest: .protocolViolation
        case .invalidPeer: .invalidPeer
        case .empty: .protocolViolation
        case .consumed: .duplicateOrReplay
        case .expired: .expired
        case .mismatch: .bindingMismatch
        case .unavailable: .unavailable
        }
    }
}
private struct InvestigationMachineClaimClientTransport:
    InvestigationMachineClaimClientTransporting
{
    func connect(
        serviceName: String,
        codeSigningRequirement: String
    ) async throws -> any InvestigationMachineClaimClientSession {
        let connection = NSXPCConnection(
            machServiceName: serviceName,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(
            with: InvestigationMachineClaimXPCWire.self
        )
        connection.setCodeSigningRequirement(codeSigningRequirement)
        let session = InvestigationMachineClaimClientLiveSession(
            serviceName: serviceName,
            connection: connection
        )
        session.activate()
        return session
    }
}
private final class InvestigationMachineClaimClientLiveSession:
    InvestigationMachineClaimClientSession,
    @unchecked Sendable
{
    private let serviceName: String
    private let connection: NSXPCConnection
    private let epoch: InvestigationMachineClaimClientConnectionEpoch
    init(serviceName: String, connection: NSXPCConnection) {
        self.serviceName = serviceName
        self.connection = connection
        epoch = InvestigationMachineClaimClientConnectionEpoch(
            connection: connection
        )
        connection.invalidationHandler = { [epoch] in
            epoch.invalidate()
        }
        connection.interruptionHandler = { [epoch] in
            epoch.invalidate()
        }
    }
    func activate() {
        connection.activate()
    }
    func currentConnectionIdentity() async throws
        -> InvestigationMachineClaimClientConnectionIdentity {
        guard epoch.isValid else {
            throw InvestigationMachineClaimClientError.unavailable
        }
        let processIdentifier = connection.processIdentifier
        let auditSessionIdentifier = connection.auditSessionIdentifier
        let effectiveUserIdentifier = connection.effectiveUserIdentifier
        guard
            processIdentifier > 1,
            auditSessionIdentifier > 0,
            epoch.isValid
        else {
            throw InvestigationMachineClaimClientError.unavailable
        }
        return InvestigationMachineClaimClientConnectionIdentity(
            serviceName: serviceName,
            processID: UInt32(processIdentifier),
            auditSessionID: UInt32(auditSessionIdentifier),
            effectiveUserID: UInt32(effectiveUserIdentifier)
        )
    }
    func claim(
        _ request: Data, deadlineNanoseconds: UInt64
    ) async throws -> (Data?, String?) {
        do {
            return try await exchange(deadlineNanoseconds: deadlineNanoseconds) {
                proxy, resolve in
                proxy.claimMachineRetirement(request) { data, reason in
                    resolve((data, reason))
                }
            }
        } catch {
            terminate()
            throw error
        }
    }
    func release(
        _ request: Data, deadlineNanoseconds: UInt64
    ) async throws -> (Data?, String?) {
        do {
            return try await exchange(deadlineNanoseconds: deadlineNanoseconds) {
                proxy, resolve in
                proxy.releaseMachineRetirement(request) { data, reason in
                    resolve((data, reason))
                }
            }
        } catch {
            terminate()
            throw error
        }
    }
    func invalidate() async {
        terminate()
    }
    private func terminate() {
        epoch.invalidate()
    }
    private func exchange(
        deadlineNanoseconds: UInt64,
        _ body: @escaping (
            InvestigationMachineClaimXPCWire,
            @escaping @Sendable ((Data?, String?)) -> Void
        ) -> Void
    ) async throws -> (Data?, String?) {
        try await epoch.exchange(deadlineNanoseconds: deadlineNanoseconds) {
            [connection, epoch] resolver in
            let proxy = connection.remoteObjectProxyWithErrorHandler {
                [epoch, weak resolver] _ in
                guard let resolver else { return }
                epoch.fail(resolver)
            }
            guard let typed = proxy as? InvestigationMachineClaimXPCWire else {
                epoch.fail(resolver)
                return
            }
            guard epoch.beginDispatch(resolver) else {
                epoch.fail(resolver)
                return
            }
            body(typed) { [epoch, weak resolver] value in
                guard let resolver else { return }
                epoch.resolve(resolver, value: value)
            }
        }
    }
}
final class InvestigationMachineClaimClientConnectionEpoch:
    @unchecked Sendable
{
    private let lock = NSLock()
    private weak var connection: NSXPCConnection?
    private var valid = true
    private var activeResolver: InvestigationMachineClaimClientReplyResolver?
    init(connection: NSXPCConnection? = nil) {
        self.connection = connection
    }
    var isValid: Bool {
        lock.withLock { valid }
    }
    func exchange(
        deadlineNanoseconds: UInt64,
        prepare: @escaping (InvestigationMachineClaimClientReplyResolver) -> Void
    ) async throws -> (Data?, String?) {
        let resolver = InvestigationMachineClaimClientReplyResolver()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard resolver.install(continuation) else { return }
                guard register(resolver) else {
                    resolver.failBoundary()
                    return
                }
                resolver.scheduleTimeout(
                    deadlineNanoseconds: deadlineNanoseconds
                ) { [weak resolver, self] in
                    guard let resolver else { return }
                    fail(resolver)
                }
                guard
                    let now = try? machineClaimContinuousNanoseconds(),
                    now < deadlineNanoseconds
                else {
                    fail(resolver)
                    return
                }
                prepare(resolver)
            }
        } onCancel: { [self] in
            cancel(resolver)
            resolver.failBoundary()
        }
    }
    func register(
        _ resolver: InvestigationMachineClaimClientReplyResolver
    ) -> Bool {
        lock.withLock {
            guard
                valid,
                activeResolver == nil,
                resolver.isPending
            else {
                return false
            }
            activeResolver = resolver
            return true
        }
    }
    func beginDispatch(
        _ resolver: InvestigationMachineClaimClientReplyResolver
    ) -> Bool {
        lock.withLock {
            guard valid, activeResolver === resolver else { return false }
            return resolver.beginDispatch()
        }
    }
    func resolve(
        _ resolver: InvestigationMachineClaimClientReplyResolver,
        value: (Data?, String?)
    ) {
        let completion: InvestigationMachineClaimClientReplyResolver.Completion? =
            lock.withLock {
            guard valid, activeResolver === resolver else { return nil }
            guard let completion = resolver.takeSuccess(value) else {
                return nil
            }
            activeResolver = nil
            return completion
        }
        if let completion {
            InvestigationMachineClaimClientReplyResolver.complete(completion)
        }
    }
    func fail(_ resolver: InvestigationMachineClaimClientReplyResolver) {
        terminalize(resolver)
    }
    func cancel(_ resolver: InvestigationMachineClaimClientReplyResolver) {
        terminalize(resolver)
    }
    func invalidate() {
        let completion: (
            Bool, InvestigationMachineClaimClientReplyResolver.Completion?
        ) =
            lock.withLock {
            guard valid else { return (false, nil) }
            valid = false
            let resolution = activeResolver?.takeBoundaryFailure()
            activeResolver = nil
            return (true, resolution)
        }
        if let resolution = completion.1 {
            InvestigationMachineClaimClientReplyResolver.complete(resolution)
        }
        if completion.0 { connection?.invalidate() }
    }
    private func terminalize(
        _ resolver: InvestigationMachineClaimClientReplyResolver
    ) {
        let completion: (
            Bool, InvestigationMachineClaimClientReplyResolver.Completion?
        ) = lock.withLock {
            guard valid, activeResolver === resolver else {
                return (false, nil)
            }
            valid = false
            activeResolver = nil
            return (true, resolver.takeBoundaryFailure())
        }
        if let resolution = completion.1 {
            InvestigationMachineClaimClientReplyResolver.complete(resolution)
        }
        if completion.0 { connection?.invalidate() }
    }
}
final class InvestigationMachineClaimClientReplyResolver:
    @unchecked Sendable
{
    struct Completion {
        let continuation: CheckedContinuation<(Data?, String?), Error>?
        let timeoutTask: Task<Void, Never>?
        let result: Result<(Data?, String?), Error>
    }
    private let lock = NSLock()
    private var finished = false
    private var dispatchBegan = false
    private var continuation: CheckedContinuation<(Data?, String?), Error>?
    private var pendingResult: Result<(Data?, String?), Error>?
    private var timeoutTask: Task<Void, Never>?
    var isPending: Bool {
        lock.withLock { !finished && !dispatchBegan }
    }
    func install(
        _ continuation: CheckedContinuation<(Data?, String?), Error>
    ) -> Bool {
        let installation: (Bool, Result<(Data?, String?), Error>?) =
            lock.withLock {
            if finished { return (false, pendingResult) }
            guard self.continuation == nil else { return (false, nil) }
            self.continuation = continuation
            return (true, nil)
        }
        if let pending = installation.1 {
            continuation.resume(with: pending)
        }
        return installation.0
    }
    func scheduleTimeout(
        deadlineNanoseconds: UInt64,
        onTimeout: @escaping @Sendable () -> Void
    ) {
        let task = Task.detached(priority: nil) {
            guard let now = try? machineClaimContinuousNanoseconds() else {
                onTimeout()
                return
            }
            if deadlineNanoseconds > now {
                do {
                    try await Task.sleep(
                        nanoseconds: deadlineNanoseconds - now
                    )
                } catch {
                    return
                }
            }
            onTimeout()
        }
        let cancel = lock.withLock {
            guard !finished else { return true }
            timeoutTask = task
            return false
        }
        if cancel { task.cancel() }
    }
    func beginDispatch() -> Bool {
        lock.withLock {
            guard !finished, !dispatchBegan else { return false }
            dispatchBegan = true
            return true
        }
    }
    func resolve(_ value: (Data?, String?)) {
        if let completion = takeSuccess(value) { Self.complete(completion) }
    }
    func failBoundary() {
        if let completion = takeBoundaryFailure() { Self.complete(completion) }
    }
    func takeSuccess(_ value: (Data?, String?)) -> Completion? {
        takeResolution { _ in .success(value) }
    }
    func takeBoundaryFailure() -> Completion? {
        takeResolution { dispatched in
            .failure(
                dispatched
                    ? InvestigationMachineClaimClientError.outcomeUnknown
                    : InvestigationMachineClaimClientError.unavailable
            )
        }
    }
    static func complete(_ completion: Completion) {
        completion.timeoutTask?.cancel()
        completion.continuation?.resume(with: completion.result)
    }
    private func takeResolution(
        _ result: (Bool) -> Result<(Data?, String?), Error>
    ) -> Completion? {
        lock.withLock {
            guard !finished else { return nil }
            finished = true
            let finalResult = result(dispatchBegan)
            let continuation = self.continuation
            self.continuation = nil
            if continuation == nil { pendingResult = finalResult }
            let timeoutTask = self.timeoutTask
            self.timeoutTask = nil
            return Completion(
                continuation: continuation,
                timeoutTask: timeoutTask,
                result: finalResult
            )
        }
    }
}
private struct InvestigationMachineClaimClientStaticIdentityReader:
    InvestigationMachineClaimClientStaticIdentityReading
{
    func readHelperIdentity() throws
        -> InvestigationMachineClaimClientStaticIdentityObservation {
        let codeURL = URL(filePath: InvestigationMachineClaimClient.Constants.helperExecutablePath)
        var staticCode: SecStaticCode?
        guard
            SecStaticCodeCreateWithPath(codeURL as CFURL, SecCSFlags(), &staticCode)
                == errSecSuccess,
            let staticCode,
            SecStaticCodeCheckValidity(
                staticCode,
                SecCSFlags(rawValue: kSecCSStrictValidate),
                nil
            ) == errSecSuccess
        else {
            throw InvestigationMachineClaimClientError.unavailable
        }
        var information: CFDictionary?
        let flags = SecCSFlags(
            rawValue: kSecCSSigningInformation | kSecCSRequirementInformation
        )
        guard
            SecCodeCopySigningInformation(staticCode, flags, &information)
                == errSecSuccess,
            let dictionary = information as? [CFString: Any],
            let signingIdentifier = dictionary[kSecCodeInfoIdentifier] as? String,
            let codeDirectoryData = dictionary[kSecCodeInfoUnique] as? Data,
            let requirement = secRequirement(
                dictionary[kSecCodeInfoDesignatedRequirement]
            ),
            let requirementData = requirementData(requirement)
        else {
            throw InvestigationMachineClaimClientError.unavailable
        }
        var resolvedURL: CFURL?
        guard
            SecCodeCopyPath(staticCode, SecCSFlags(), &resolvedURL)
                == errSecSuccess,
            let resolvedURL,
            (resolvedURL as URL).standardizedFileURL == codeURL.standardizedFileURL
        else {
            throw InvestigationMachineClaimClientError.unavailable
        }
        return InvestigationMachineClaimClientStaticIdentityObservation(
            executablePath: codeURL.path,
            signingIdentifier: signingIdentifier,
            designatedRequirementSHA256: machineClaimSHA256(requirementData),
            codeDirectoryHash: machineClaimHex(codeDirectoryData),
            isAdHoc: machineClaimIsAdHoc(dictionary)
        )
    }
}
private struct InvestigationMachineClaimClientDynamicIdentityReader:
    InvestigationMachineClaimClientDynamicIdentityReading
{
    func readHelperIdentity(
        auditTokenWords: [UInt32]
    ) throws -> InvestigationMachineClaimClientDynamicIdentityObservation {
        guard auditTokenWords.count == 8 else {
            throw InvestigationMachineClaimClientError.helperIdentityMismatch
        }
        var rawToken = audit_token_t()
        let didCopy = withUnsafeMutableBytes(of: &rawToken) { destination in
            auditTokenWords.withUnsafeBytes { source in
                guard destination.count == source.count else { return false }
                destination.copyBytes(from: source)
                return true
            }
        }
        guard didCopy else {
            throw InvestigationMachineClaimClientError.unavailable
        }
        let tokenData = withUnsafeBytes(of: rawToken) { Data($0) }
        let attributes: [CFString: Any] = [
            kSecGuestAttributeAudit: tokenData as CFData,
        ]
        var dynamicCode: SecCode?
        guard
            SecCodeCopyGuestWithAttributes(
                nil,
                attributes as CFDictionary,
                SecCSFlags(),
                &dynamicCode
            ) == errSecSuccess,
            let dynamicCode
        else {
            throw InvestigationMachineClaimClientError.unavailable
        }
        guard SecCodeCheckValidity(
            dynamicCode,
            SecCSFlags(rawValue: kSecCSStrictValidate),
            nil
        ) == errSecSuccess else {
            throw InvestigationMachineClaimClientError.unavailable
        }
        var staticCode: SecStaticCode?
        guard
            SecCodeCopyStaticCode(
                dynamicCode, SecCSFlags(), &staticCode
            ) == errSecSuccess,
            let staticCode,
            SecStaticCodeCheckValidity(
                staticCode,
                SecCSFlags(rawValue: kSecCSStrictValidate),
                nil
            ) == errSecSuccess
        else {
            throw InvestigationMachineClaimClientError.unavailable
        }
        let signing = try machineClaimSigning(staticCode)
        var path: CFURL?
        guard
            SecCodeCopyPath(staticCode, SecCSFlags(), &path)
                == errSecSuccess,
            let path
        else {
            throw InvestigationMachineClaimClientError.unavailable
        }
        return InvestigationMachineClaimClientDynamicIdentityObservation(
            processID: auditTokenWords[5],
            processIDVersion: auditTokenWords[7],
            auditSessionID: auditTokenWords[6],
            effectiveUserID: auditTokenWords[1],
            executablePath: (path as URL).standardizedFileURL.path,
            signingIdentifier: signing.signingIdentifier,
            designatedRequirementSHA256:
                signing.designatedRequirementSHA256,
            codeDirectoryHash: signing.codeDirectoryHash,
            isAdHoc: signing.isAdHoc
        )
    }
}
private struct InvestigationMachineClaimClientHelperEpochObserver:
    InvestigationMachineClaimClientHelperEpochObserving
{
    func observe(
        serviceName _: String,
        claimedHelperIdentity: InvestigationMachineProcessIdentity
    ) async throws -> InvestigationMachineClaimClientHelperEpoch {
        guard claimedHelperIdentity.auditTokenWords.count == 8 else {
            throw InvestigationMachineClaimClientError.helperIdentityMismatch
        }
        var rawToken = audit_token_t()
        let didCopy = withUnsafeMutableBytes(of: &rawToken) { destination in
            claimedHelperIdentity.auditTokenWords.withUnsafeBytes { source in
                guard destination.count == source.count else { return false }
                destination.copyBytes(from: source)
                return true
            }
        }
        guard didCopy else {
            throw InvestigationMachineClaimClientError.helperIdentityMismatch
        }
        let tokenData = withUnsafeBytes(of: rawToken) { Data($0) }
        let attributes: [CFString: Any] = [
            kSecGuestAttributeAudit: tokenData as CFData,
        ]
        var dynamicCode: SecCode?
        let result = SecCodeCopyGuestWithAttributes(
            nil, attributes as CFDictionary, SecCSFlags(), &dynamicCode
        )
        if result == errSecCSNoSuchCode {
            return .originalHelperAbsent
        }
        guard result == errSecSuccess, dynamicCode != nil else {
            throw InvestigationMachineClaimClientError.outcomeUnknown
        }
        return .originalHelperPresent
    }
}
private struct InvestigationMachineClaimClientClock:
    InvestigationMachineClaimClientClocking
{
    func observe() throws -> InvestigationMachineClaimClientClockObservation {
        InvestigationMachineClaimClientClockObservation(
            continuousNanoseconds: try machineClaimContinuousNanoseconds(),
            wallUTCMicroseconds: try InvestigationHandoffUTCMicroseconds(
                timeIntervalSince1970: Date().timeIntervalSince1970
            )
        )
    }

    func sleep(untilNanoseconds deadlineNanoseconds: UInt64) async {
        guard let now = try? machineClaimContinuousNanoseconds() else { return }
        guard deadlineNanoseconds > now else { return }
        try? await Task.sleep(nanoseconds: deadlineNanoseconds - now)
    }
}
private func machineClaimContinuousNanoseconds() throws -> UInt64 {
    var timebase = mach_timebase_info_data_t()
    guard
        mach_timebase_info(&timebase) == KERN_SUCCESS,
        timebase.numer > 0,
        timebase.denom > 0
    else {
        throw InvestigationMachineClaimClientError.unavailable
    }
    let ticks = mach_continuous_time()
    let whole = (ticks / UInt64(timebase.denom))
        .multipliedReportingOverflow(by: UInt64(timebase.numer))
    let fractional = (ticks % UInt64(timebase.denom))
        .multipliedReportingOverflow(by: UInt64(timebase.numer))
    guard !whole.overflow, !fractional.overflow else {
        throw InvestigationMachineClaimClientError.unavailable
    }
    let result = whole.partialValue.addingReportingOverflow(
        fractional.partialValue / UInt64(timebase.denom)
    )
    guard !result.overflow, result.partialValue > 0 else {
        throw InvestigationMachineClaimClientError.unavailable
    }
    return result.partialValue
}
private struct MachineClaimSigning {
    let signingIdentifier: String
    let designatedRequirementSHA256: String
    let codeDirectoryHash: String
    let isAdHoc: Bool
}
private func machineClaimSigning(
    _ staticCode: SecStaticCode
) throws -> MachineClaimSigning {
    var information: CFDictionary?
    let flags = SecCSFlags(
        rawValue: kSecCSSigningInformation | kSecCSRequirementInformation
    )
    guard
        SecCodeCopySigningInformation(staticCode, flags, &information)
            == errSecSuccess,
        let dictionary = information as? [CFString: Any],
        let signingIdentifier = dictionary[kSecCodeInfoIdentifier] as? String,
        let codeDirectoryData = dictionary[kSecCodeInfoUnique] as? Data,
        let requirement = secRequirement(
            dictionary[kSecCodeInfoDesignatedRequirement]
        ),
        let requirementData = requirementData(requirement)
    else {
        throw InvestigationMachineClaimClientError.unavailable
    }
    return MachineClaimSigning(
        signingIdentifier: signingIdentifier,
        designatedRequirementSHA256: machineClaimSHA256(requirementData),
        codeDirectoryHash: machineClaimHex(codeDirectoryData),
        isAdHoc: machineClaimIsAdHoc(dictionary)
    )
}
private func secRequirement(_ value: Any?) -> SecRequirement? {
    guard let value else { return nil }
    let object = value as AnyObject
    guard CFGetTypeID(object) == SecRequirementGetTypeID() else { return nil }
    return unsafeDowncast(object, to: SecRequirement.self)
}
private func requirementData(_ requirement: SecRequirement) -> Data? {
    var data: CFData?
    guard
        SecRequirementCopyData(requirement, SecCSFlags(), &data)
            == errSecSuccess,
        let data
    else { return nil }
    return data as Data
}
private func machineClaimIsAdHoc(_ dictionary: [CFString: Any]) -> Bool {
    guard let flags = dictionary[kSecCodeInfoFlags] as? NSNumber else {
        return false
    }
    return flags.uint32Value & 0x0002 != 0
}
private func machineClaimSHA256(_ data: Data) -> String {
    machineClaimHex(Data(SHA256.hash(data: data)))
}
private func machineClaimHex(_ data: Data) -> String {
    data.map { String(format: "%02x", $0) }.joined()
}
private func machineClaimValidHex(_ value: String, count: Int) -> Bool {
    value.utf8.count == count
        && value.unicodeScalars.allSatisfy {
            (0x30...0x39).contains($0.value)
                || (0x61...0x66).contains($0.value)
        }
}
private func exactCodeSigningRequirement(
    _ observation: InvestigationMachineClaimClientStaticIdentityObservation
) -> String {
    "identifier \"\(observation.signingIdentifier)\" and cdhash H\"\(observation.codeDirectoryHash)\""
}
