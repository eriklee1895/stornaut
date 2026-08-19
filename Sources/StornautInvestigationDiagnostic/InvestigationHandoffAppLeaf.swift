#if DEBUG
import Foundation
import StornautInvestigationHandoffContract

package enum InvestigationHandoffAppLeafError:
    Error,
    Sendable,
    Equatable
{
    case alreadyConsumed
    case invalidTransition
    case operationFailed
}

package enum InvestigationHandoffAppLeafResult:
    Sendable,
    Equatable
{
    case completed
}

package struct InvestigationHandoffAppLeafDropResult:
    Sendable,
    Equatable
{
    package let processClaim: InvestigationHandoffProcessClaim
    package let evidence: InvestigationHandoffDropEvidence

    package init(
        processClaim: InvestigationHandoffProcessClaim,
        evidence: InvestigationHandoffDropEvidence
    ) throws {
        guard processClaim.effectiveUserID == 501 else {
            throw InvestigationHandoffAppLeafError.invalidTransition
        }
        self.processClaim = processClaim
        self.evidence = evidence
    }
}

package protocol InvestigationHandoffAppLeafOperations: Sendable {
    func preDropClaim() async throws -> InvestigationHandoffProcessClaim
    func sendPreDropReady(_ frame: InvestigationHandoffFrame) async throws
    func receiveDropRelease() async throws -> InvestigationHandoffFrame
    func performIdentityDrop() async throws
        -> InvestigationHandoffAppLeafDropResult
    func sendDropEvidence(_ frame: InvestigationHandoffFrame) async throws
    func receiveConfiguration() async throws -> InvestigationHandoffFrame
    func acknowledgeConfiguration(_ configuration: Data) async throws
        -> InvestigationHandoffConfigurationAcknowledgement
    func sendConfigurationAcknowledgement(
        _ frame: InvestigationHandoffFrame
    ) async throws
    func sendHello(_ frame: InvestigationHandoffFrame) async throws
    func retirementHandle() async throws
        -> InvestigationHandoffRetirementHandle
    func sendRetirementHandle(_ frame: InvestigationHandoffFrame) async throws
    func receiveHandleAcknowledgement() async throws
        -> InvestigationHandoffFrame
    func receiveRelease() async throws -> InvestigationHandoffFrame
    func sendAlive(_ frame: InvestigationHandoffFrame) async throws
    func halfCloseAndProveEOF() async throws
    func receiveExit() async throws -> InvestigationHandoffFrame
}

package actor InvestigationHandoffAppLeaf {
    package static let concreteAdapterUnavailableExitStatus: Int32 = 78

    private let bootstrap: InvestigationHandoffEpochBootstrap
    private let driverClaim: InvestigationHandoffProcessClaim
    private let operations: any InvestigationHandoffAppLeafOperations
    private var consumed = false

    package init(
        bootstrap: InvestigationHandoffEpochBootstrap,
        driverClaim: InvestigationHandoffProcessClaim,
        operations: any InvestigationHandoffAppLeafOperations
    ) {
        self.bootstrap = bootstrap
        self.driverClaim = driverClaim
        self.operations = operations
    }

    package func run() async throws -> InvestigationHandoffAppLeafResult {
        guard !consumed else {
            throw InvestigationHandoffAppLeafError.alreadyConsumed
        }
        consumed = true
        do {
            return try await execute()
        } catch let error as InvestigationHandoffAppLeafError {
            throw error
        } catch {
            throw InvestigationHandoffAppLeafError.invalidTransition
        }
    }

    private func execute() async throws -> InvestigationHandoffAppLeafResult {
        let preDropClaim = try await operation {
            try await operations.preDropClaim()
        }
        guard preDropClaim.effectiveUserID == 0 else {
            throw InvestigationHandoffAppLeafError.invalidTransition
        }

        try await send(
            kind: .preDropReady,
            sender: preDropClaim,
            payload: .empty,
            through: operations.sendPreDropReady
        )
        try validateIncoming(
            try await operation {
                try await operations.receiveDropRelease()
            },
            kind: .dropRelease,
            payload: .empty
        )

        let drop = try await operation {
            try await operations.performIdentityDrop()
        }
        guard
            drop.processClaim.effectiveUserID == 501,
            drop.processClaim.processID == preDropClaim.processID,
            drop.processClaim.processIDVersion
                == preDropClaim.processIDVersion,
            drop.processClaim.auditSessionID == preDropClaim.auditSessionID,
            evidence(drop.evidence, matches: drop.processClaim)
        else {
            throw InvestigationHandoffAppLeafError.invalidTransition
        }
        try await send(
            kind: .dropEvidence,
            sender: drop.processClaim,
            payload: .dropEvidence(drop.evidence),
            through: operations.sendDropEvidence
        )

        let configurationFrame = try await operation {
            try await operations.receiveConfiguration()
        }
        let configuration = try validateConfigurationFrame(configurationFrame)
        let acknowledgement = try await operation {
            try await operations.acknowledgeConfiguration(configuration)
        }
        guard
            acknowledgement.epochUUID == bootstrap.epochUUID,
            acknowledgement.configurationSHA256
                == InvestigationHandoffSHA256.hashing(configuration)
        else {
            throw InvestigationHandoffAppLeafError.invalidTransition
        }
        try await send(
            kind: .configurationAcknowledgement,
            sender: drop.processClaim,
            payload: .configurationAcknowledgement(acknowledgement),
            through: operations.sendConfigurationAcknowledgement
        )
        try await send(
            kind: .hello,
            sender: drop.processClaim,
            payload: .empty,
            through: operations.sendHello
        )

        let handle = try await operation {
            try await operations.retirementHandle()
        }
        guard
            handle.investigationUUID == acknowledgement.configurationNonce,
            handle.configurationSHA256 == acknowledgement.configurationSHA256
        else {
            throw InvestigationHandoffAppLeafError.invalidTransition
        }
        try await send(
            kind: .handle,
            sender: drop.processClaim,
            payload: .retirementHandle(handle),
            through: operations.sendRetirementHandle
        )

        let acknowledgementFrame = try await operation {
            try await operations.receiveHandleAcknowledgement()
        }
        try validateHandleAcknowledgement(acknowledgementFrame, handle: handle)
        try validateIncoming(
            try await operation { try await operations.receiveRelease() },
            kind: .release,
            payload: .empty
        )
        try await send(
            kind: .alive,
            sender: drop.processClaim,
            payload: .empty,
            through: operations.sendAlive
        )
        try await operation {
            try await operations.halfCloseAndProveEOF()
        }
        try validateIncoming(
            try await operation { try await operations.receiveExit() },
            kind: .exit,
            payload: .empty
        )
        return .completed
    }

    private func operation<T: Sendable>(
        _ body: () async throws -> T
    ) async throws -> T {
        do {
            return try await body()
        } catch {
            throw InvestigationHandoffAppLeafError.operationFailed
        }
    }

    private func send(
        kind: InvestigationHandoffFrameKind,
        sender: InvestigationHandoffProcessClaim,
        payload: InvestigationHandoffFramePayload,
        through operation: (InvestigationHandoffFrame) async throws -> Void
    ) async throws {
        let frame = try InvestigationHandoffFrame(
            kind: kind,
            epochUUID: bootstrap.epochUUID,
            epochDeadlineNanoseconds: bootstrap.epochDeadlineNanoseconds,
            sender: sender,
            payload: payload
        )
        try await self.operation {
            try await operation(frame)
        }
    }

    private func validateIncoming(
        _ frame: InvestigationHandoffFrame,
        kind: InvestigationHandoffFrameKind,
        payload: InvestigationHandoffFramePayload
    ) throws {
        guard
            frame.kind == kind,
            frame.epochUUID == bootstrap.epochUUID,
            frame.epochDeadlineNanoseconds
                == bootstrap.epochDeadlineNanoseconds,
            frame.sender == driverClaim,
            frame.payload == payload
        else {
            throw InvestigationHandoffAppLeafError.invalidTransition
        }
    }

    private func validateConfigurationFrame(
        _ frame: InvestigationHandoffFrame
    ) throws -> Data {
        guard case let .configuration(configuration) = frame.payload else {
            throw InvestigationHandoffAppLeafError.invalidTransition
        }
        try validateIncoming(
            frame,
            kind: .configuration,
            payload: .configuration(configuration)
        )
        return configuration
    }

    private func validateHandleAcknowledgement(
        _ frame: InvestigationHandoffFrame,
        handle: InvestigationHandoffRetirementHandle
    ) throws {
        guard
            case let .retirementHandleAcknowledgement(value) = frame.payload,
            value.handleSHA256
                == InvestigationHandoffSHA256.hashing(try handle.encoded())
        else {
            throw InvestigationHandoffAppLeafError.invalidTransition
        }
        try validateIncoming(
            frame,
            kind: .acknowledgement,
            payload: .retirementHandleAcknowledgement(value)
        )
    }

    private func evidence(
        _ value: InvestigationHandoffDropEvidence,
        matches claim: InvestigationHandoffProcessClaim
    ) -> Bool {
        value.auditTokenWords.count == 8
            && value.auditTokenWords[1] == claim.effectiveUserID
            && value.auditTokenWords[5] == claim.processID
            && value.auditTokenWords[6] == claim.auditSessionID
            && value.auditTokenWords[7] == claim.processIDVersion
    }
}

public enum InvestigationHandoffAppLeafEntryPoint {
    public static func run() -> Int32 {
        InvestigationHandoffAppLeaf.concreteAdapterUnavailableExitStatus
    }
}
#endif
