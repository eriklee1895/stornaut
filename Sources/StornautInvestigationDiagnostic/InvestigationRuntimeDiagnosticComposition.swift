#if DEBUG
import Darwin
import Foundation
import StornautCodex
import StornautCore
import StornautInvestigation
import StornautInvestigationHandoffContract
import StornautInvestigationRuntime
import StornautLifecycle

public enum InvestigationRuntimeDiagnosticCompositionError:
    Error,
    Sendable,
    Equatable
{
    case invalidConfiguration
    case bindingMismatch
    case compositionUnavailable
}

public enum InvestigationRuntimeDiagnosticCompositionRetirement:
    Sendable,
    Equatable
{
    case retiredWithoutStarting
    case retiredAfterUse
    case retirementFailed
}

package enum InvestigationHandoffConcreteAppLeafError:
    Error,
    Sendable,
    Equatable
{
    case invalidConfiguration
    case bindingMismatch
    case invalidState
    case retirementFailed
}

package actor InvestigationHandoffConcreteAppLeafOperations:
    InvestigationHandoffAppLeafOperations
{
    private enum Phase: Equatable {
        case idle
        case operation(UUID)
        case retiring(UUID)
        case terminal
    }

    package typealias RetirementHandle = @Sendable (
        SignedInvestigationRuntimeDiagnosticConfiguration,
        String
    ) async throws -> InvestigationHandoffRetirementHandle

    private let adapter: any InvestigationHandoffAppLeafAdapting
    private let peer: InvestigationHandoffAppLeafPeerObservation
    private let now: @Sendable () -> Date
    private let retirementHandleFactory: RetirementHandle
    private var configuration:
        SignedInvestigationRuntimeDiagnosticConfiguration?
    private var configurationSHA256: String?
    private var didRetire = false
    private var phase = Phase.idle

    package init(
        adapter: any InvestigationHandoffAppLeafAdapting,
        peer: InvestigationHandoffAppLeafPeerObservation,
        now: @escaping @Sendable () -> Date = Date.init,
        retirementHandle: @escaping RetirementHandle = { configuration, digest in
            try await InvestigationHandoffNoAuthRetirement.live(
                configuration: configuration,
                configurationSHA256: digest
            )
        }
    ) throws {
        guard
            peer.driverIdentity.effectiveUserID == 0,
            UInt32(exactly: peer.driverIdentity.processID)
                == peer.driverClaim.processID,
            UInt32(exactly: peer.driverIdentity.processIDVersion)
                == peer.driverClaim.processIDVersion,
            UInt32(exactly: peer.driverIdentity.auditSessionID)
                == peer.driverClaim.auditSessionID,
            UInt32(exactly: peer.driverIdentity.effectiveUserID)
                == peer.driverClaim.effectiveUserID,
            peer.driverIdentity.auditToken.words.count
                == LifecycleAuditToken.wordCount,
            peer.driverIdentity.auditToken.words[1]
                == peer.driverClaim.effectiveUserID,
            peer.driverIdentity.auditToken.words[5]
                == peer.driverClaim.processID,
            peer.driverIdentity.auditToken.words[6]
                == peer.driverClaim.auditSessionID,
            peer.driverIdentity.auditToken.words[7]
                == peer.driverClaim.processIDVersion,
            peer.signingEvidence.isAdHoc
        else {
            throw InvestigationHandoffConcreteAppLeafError.bindingMismatch
        }
        self.adapter = adapter
        self.peer = peer
        self.now = now
        retirementHandleFactory = retirementHandle
    }

    package func preDropClaim() async throws
        -> InvestigationHandoffProcessClaim
    {
        let adapter = self.adapter
        return try await performOperation {
            try await adapter.preDropClaim()
        }
    }

    package func sendPreDropReady(
        _ frame: InvestigationHandoffFrame
    ) async throws {
        try await write(frame)
    }

    package func receiveDropRelease() async throws
        -> InvestigationHandoffFrame
    {
        try await read()
    }

    package func performIdentityDrop() async throws
        -> InvestigationHandoffAppLeafDropResult
    {
        let adapter = self.adapter
        return try await performOperation {
            try await adapter.performIdentityDrop()
        }
    }

    package func sendDropEvidence(
        _ frame: InvestigationHandoffFrame
    ) async throws {
        try await write(frame)
    }

    package func receiveConfiguration() async throws
        -> InvestigationHandoffFrame
    {
        try await read()
    }

    package func acknowledgeConfiguration(
        _ bytes: Data
    ) async throws -> InvestigationHandoffConfigurationAcknowledgement {
        let ticket = try beginOperation()
        guard configuration == nil else {
            return try fail(.invalidState)
        }
        let decoded: SignedInvestigationRuntimeDiagnosticConfiguration
        do {
            decoded = try SignedInvestigationRuntimeDiagnosticConfiguration
                .decodeValidated(from: bytes, now: now())
            guard try decoded.canonicalJSONData() == bytes else {
                return try fail(.invalidConfiguration)
            }
        } catch let error as InvestigationHandoffConcreteAppLeafError {
            throw error
        } catch {
            return try fail(.invalidConfiguration)
        }
        guard machineDriverMatchesPeer(decoded.binding.machineDriver) else {
            return try fail(.bindingMismatch)
        }
        let wireSHA = InvestigationHandoffSHA256.hashing(bytes)
        let machineSHA: String
        let bindingSHA: String
        do {
            machineSHA = try decoded.machineConfigurationSHA256()
            bindingSHA = try decoded.capabilityEvidenceBindingSHA256()
        } catch {
            return try fail(.invalidConfiguration)
        }
        guard wireSHA.lowercaseHex == machineSHA else {
            return try fail(.invalidConfiguration)
        }
        let scenario = InvestigationHandoffScenarioMapping.handoffScenario(
            decoded.scenario
        )
        let acknowledgement: InvestigationHandoffConfigurationAcknowledgement
        do {
            acknowledgement = try .init(
                epochUUID: peer.bootstrap.epochUUID,
                ordinal: scenario.rawValue - 1,
                configurationNonce: decoded.nonce,
                scenario: scenario,
                configurationSHA256: wireSHA,
                signedRuntimeBindingSHA256: try .init(
                    lowercaseHex: bindingSHA
                )
            )
        } catch {
            return try fail(.invalidConfiguration)
        }
        try finishOperation(ticket)
        configuration = decoded
        configurationSHA256 = machineSHA
        return acknowledgement
    }

    package func sendConfigurationAcknowledgement(
        _ frame: InvestigationHandoffFrame
    ) async throws {
        try await write(frame)
    }

    package func sendHello(
        _ frame: InvestigationHandoffFrame
    ) async throws {
        try await write(frame)
    }

    package func retirementHandle() async throws
        -> InvestigationHandoffRetirementHandle
    {
        let ticket = try beginOperation(retiring: true)
        guard
            !didRetire,
            let configuration,
            let configurationSHA256
        else {
            return try fail(.invalidState)
        }
        didRetire = true
        let startedAt = now()
        do {
            let handle = try await retirementHandleFactory(
                configuration,
                configurationSHA256
            )
            guard validRetirementHandle(
                handle,
                configuration: configuration,
                configurationSHA256: configurationSHA256,
                startedAt: startedAt,
                completedAt: now()
            ) else {
                return try fail(.retirementFailed)
            }
            try finishOperation(ticket, retiring: true)
            return handle
        } catch {
            return try fail(.retirementFailed)
        }
    }

    package func sendRetirementHandle(
        _ frame: InvestigationHandoffFrame
    ) async throws {
        try await write(frame)
    }

    package func receiveHandleAcknowledgement() async throws
        -> InvestigationHandoffFrame
    {
        try await read()
    }

    package func receiveRelease() async throws
        -> InvestigationHandoffFrame
    {
        try await read()
    }

    package func sendAlive(
        _ frame: InvestigationHandoffFrame
    ) async throws {
        try await write(frame)
    }

    package func halfCloseAndProveEOF() async throws {
        let adapter = self.adapter
        _ = try await performOperation {
            try await adapter.halfCloseWrite()
            return true
        }
    }

    package func receiveExit() async throws -> InvestigationHandoffFrame {
        let adapter = self.adapter
        return try await performOperation(terminalOnSuccess: true) {
            try await adapter.readFrame()
        }
    }

    private func read() async throws -> InvestigationHandoffFrame {
        let adapter = self.adapter
        return try await performOperation {
            return try await adapter.readFrame()
        }
    }

    private func write(_ frame: InvestigationHandoffFrame) async throws {
        let adapter = self.adapter
        _ = try await performOperation {
            try await adapter.writeFrame(frame)
            return true
        }
    }

    private func performOperation<T: Sendable>(
        terminalOnSuccess: Bool = false,
        _ body: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let ticket = try beginOperation()
        do {
            let result = try await body()
            try finishOperation(
                ticket,
                terminalOnSuccess: terminalOnSuccess
            )
            return result
        } catch {
            return try fail(.invalidState)
        }
    }

    private func beginOperation(retiring: Bool = false) throws -> UUID {
        do {
            try Task.checkCancellation()
        } catch {
            return try fail(.invalidState)
        }
        guard phase == .idle else {
            return try fail(.invalidState)
        }
        let ticket = UUID()
        phase = retiring ? .retiring(ticket) : .operation(ticket)
        return ticket
    }

    private func finishOperation(
        _ ticket: UUID,
        retiring: Bool = false,
        terminalOnSuccess: Bool = false
    ) throws {
        do {
            try Task.checkCancellation()
        } catch {
            return try fail(.invalidState)
        }
        let expected = retiring ? Phase.retiring(ticket) : .operation(ticket)
        guard phase == expected else {
            return try fail(.invalidState)
        }
        phase = terminalOnSuccess ? .terminal : .idle
    }

    private func fail<T>(
        _ error: InvestigationHandoffConcreteAppLeafError
    ) throws -> T {
        phase = .terminal
        throw error
    }

    private func machineDriverMatchesPeer(
        _ binding: SignedInvestigationRuntimeMachineDriverBinding
    ) -> Bool {
        peer.signingEvidence.executableSHA256 == binding.executableSHA256
            && peer.signingEvidence.identity.signingIdentifier
                == binding.signingIdentifier
            && peer.signingEvidence.identity.designatedRequirementSHA256
                == binding.designatedRequirementSHA256
            && peer.signingEvidence.identity.codeDirectoryHash
                == binding.codeDirectoryHash
    }

    private func validRetirementHandle(
        _ handle: InvestigationHandoffRetirementHandle,
        configuration: SignedInvestigationRuntimeDiagnosticConfiguration,
        configurationSHA256: String,
        startedAt: Date,
        completedAt: Date
    ) -> Bool {
        handle.investigationUUID == configuration.nonce
            && handle.configurationSHA256.lowercaseHex
                == configurationSHA256
            && validRetirementDeadline(
                handle.validBefore.rawValue,
                configurationValidBefore: configuration.validBefore,
                startedAt: startedAt,
                completedAt: completedAt
            )
    }

}

package enum InvestigationHandoffScenarioMapping {
    package static func handoffScenario(
        _ scenario: SignedInvestigationRuntimeDiagnosticScenario
    ) -> InvestigationHandoffScenario {
        switch scenario {
        case .success: .success
        case .cancellation: .cancellation
        case .timeout: .timeout
        case .invalidEnvelope: .invalidEnvelope
        case .identityMismatch: .identityMismatch
        case .transportLoss: .transportLoss
        case .lifecycleRecovery: .lifecycleRecovery
        case .artifactCleanupFailure: .artifactCleanupFailure
        }
    }
}

package enum InvestigationHandoffNoAuthRetirement {
    package static func live(
        configuration: SignedInvestigationRuntimeDiagnosticConfiguration,
        configurationSHA256: String
    ) async throws -> InvestigationHandoffRetirementHandle {
        let contract = try LifecycleLocalInstallationContract()
        guard
            configuration.binding.helperServiceIdentifier
                == contract.machServiceName,
            configuration.binding.machineDriver.signingIdentifier
                == contract.machineDriverSigningIdentifier,
            configuration.binding.machineDriver.machineClaimServiceIdentifier
                == contract.machineClaimMachServiceName
        else {
            throw InvestigationHandoffConcreteAppLeafError.bindingMismatch
        }
        let session = LifecycleInteractiveSessionXPCClient(
            helperBundleURL: contract.helperExecutableURL
        )
        do {
            let handle = try await run(
                configuration: configuration,
                configurationSHA256: configurationSHA256,
                session: session
            )
            await session.invalidate()
            return handle
        } catch {
            await session.invalidate()
            throw error
        }
    }

    package static func run(
        configuration: SignedInvestigationRuntimeDiagnosticConfiguration,
        configurationSHA256: String,
        session: any LifecycleInteractiveSessionSending,
        now: @escaping @Sendable () -> Date = Date.init,
        operationID: @escaping @Sendable () throws -> UUID = UUID.init
    ) async throws -> InvestigationHandoffRetirementHandle {
        guard
            try configuration.canonicalJSONData()
                .handoffSHA256Hex == configurationSHA256,
            try configuration.machineConfigurationSHA256()
                == configurationSHA256
        else {
            throw InvestigationHandoffConcreteAppLeafError.invalidConfiguration
        }
        let evidenceStore = InvestigationLifecycleRetirementEvidenceStore()
        let transport = try InvestigationLifecycleAppServerTransport(
            investigationID: LifecycleInvestigationID(
                rawValue: configuration.nonce
            ),
            configurationSHA256: configurationSHA256,
            validBefore: configuration.validBefore,
            maximumLineBytes:
                LifecycleInteractiveSessionRequest.maximumAllowedLineBytes,
            maximumSessionBytes:
                LifecycleInteractiveSessionRequest.maximumAllowedSessionBytes,
            expectedUserID: 501,
            now: now,
            operationID: operationID,
            session: session,
            retirementEvidenceStore: evidenceStore
        )
        let retirementStartedAt = now()
        let returned = try await transport.startAndRetireWithEvidence()
        let retirementCompletedAt = now()
        guard let stored = await evidenceStore.consume(), stored == returned else {
            throw InvestigationHandoffConcreteAppLeafError.retirementFailed
        }
        let lifecycle = returned.machineRetirementHandle
        guard
            lifecycle.investigationID.rawValue == configuration.nonce,
            lifecycle.configurationSHA256 == configurationSHA256,
            validRetirementDeadline(
                lifecycle.validBeforeUTCMicroseconds,
                configurationValidBefore: configuration.validBefore,
                startedAt: retirementStartedAt,
                completedAt: retirementCompletedAt
            )
        else {
            throw InvestigationHandoffConcreteAppLeafError.retirementFailed
        }
        return try InvestigationHandoffRetirementHandle(
            token: lifecycle.token,
            investigationUUID: configuration.nonce,
            retireOperationUUID: lifecycle.retireOperationID,
            configurationSHA256: .init(
                lowercaseHex: lifecycle.configurationSHA256
            ),
            validBefore: .init(
                rawValue: lifecycle.validBeforeUTCMicroseconds
            )
        )
    }
}

private func validRetirementDeadline(
    _ validBeforeMicroseconds: Int64,
    configurationValidBefore: Date,
    startedAt: Date,
    completedAt: Date
) -> Bool {
    guard
        let configuration = exactUTCMicroseconds(configurationValidBefore),
        let started = exactUTCMicroseconds(startedAt),
        let completed = exactUTCMicroseconds(completedAt),
        completed >= started
    else { return false }
    let maximum = completed.addingReportingOverflow(30_000_000)
    return !maximum.overflow
        && validBeforeMicroseconds > completed
        && validBeforeMicroseconds <= configuration
        && validBeforeMicroseconds <= maximum.partialValue
}

private func exactUTCMicroseconds(_ value: Date) -> Int64? {
    let seconds = value.timeIntervalSince1970
    guard seconds.isFinite, seconds > 0 else { return nil }
    let scaled = seconds * 1_000_000
    guard scaled.isFinite, scaled >= 1, scaled < Double(Int64.max) else {
        return nil
    }
    return Int64(scaled.rounded(.down))
}

private extension Data {
    var handoffSHA256Hex: String {
        InvestigationHandoffSHA256.hashing(self).lowercaseHex
    }
}

public final class InvestigationRuntimeDiagnosticComposition:
    @unchecked Sendable
{
    public let nonce: UUID
    public let investigationID: String
    public let storePath: String
    public let helperExecutablePath: String
    public let hasRuntimeFacade: Bool
    package let configurationSHA256: String

    private let runtimeFacade: InvestigationRuntimeDiagnosticFacade
    private let transportOwner:
        InvestigationRuntimeDiagnosticTransportOwner
    private let retirementEvidenceStore:
        InvestigationLifecycleRetirementEvidenceStore

    private init(
        nonce: UUID,
        investigationID: InvestigationID,
        storePath: String,
        helperExecutablePath: String,
        configurationSHA256: String,
        runtimeFacade: InvestigationRuntimeDiagnosticFacade,
        transportOwner: InvestigationRuntimeDiagnosticTransportOwner,
        retirementEvidenceStore:
            InvestigationLifecycleRetirementEvidenceStore
    ) {
        self.nonce = nonce
        self.investigationID = investigationID.rawValue
        self.storePath = storePath
        self.helperExecutablePath = helperExecutablePath
        self.configurationSHA256 = configurationSHA256
        hasRuntimeFacade = true
        self.runtimeFacade = runtimeFacade
        self.transportOwner = transportOwner
        self.retirementEvidenceStore = retirementEvidenceStore
    }

    public static func prepare(
        configurationData: Data,
        now: Date
    ) throws -> Self {
        let installation: InvestigationRuntimeDiagnosticBindingObservation
        do {
            installation =
                try InvestigationRuntimeDiagnosticBindingObservation
                    .installed()
        } catch {
            throw InvestigationRuntimeDiagnosticCompositionError
                .bindingMismatch
        }
        return try prepare(
            configurationData: configurationData,
            now: now,
            installation: installation,
            runtimeNow: Date.init
        )
    }

    package static func prepare(
        configurationData: Data,
        now: Date,
        installation:
            InvestigationRuntimeDiagnosticBindingObservation,
        runtimeNow: @escaping @Sendable () -> Date = Date.init
    ) throws -> Self {
        let configuration: SignedInvestigationRuntimeDiagnosticConfiguration
        do {
            configuration =
                try SignedInvestigationRuntimeDiagnosticConfiguration
                    .decodeValidated(
                        from: configurationData,
                        now: now
                    )
        } catch {
            throw InvestigationRuntimeDiagnosticCompositionError
                .invalidConfiguration
        }
        guard installation.matches(configuration.binding) else {
            throw InvestigationRuntimeDiagnosticCompositionError
                .bindingMismatch
        }

        do {
            let lifecycleID = LifecycleInvestigationID(
                rawValue: configuration.nonce
            )
            let lifecycleContract =
                try LifecycleLocalInstallationContract()
            guard
                installation.installedAppURL
                    == lifecycleContract.installedAppURL,
                installation.helperExecutableURL
                    == lifecycleContract.helperExecutableURL,
                installation.serviceIdentifier
                    == lifecycleContract.machServiceName
            else {
                throw InvestigationRuntimeDiagnosticCompositionError
                    .bindingMismatch
            }
            let runtimeRoot = try lifecycleContract.diagnosticPaths(
                userID: geteuid(),
                investigationID: lifecycleID
            ).rootURL
            let authSource = try currentAuthSourceURL()
            let outputSchema =
                try InvestigationEnvelopeV2Schema
                    .loadStructuredOutputJSONValue()
            let session = LifecycleInteractiveSessionXPCClient(
                helperBundleURL: installation.helperExecutableURL
            )
            let retirementEvidenceStore =
                InvestigationLifecycleRetirementEvidenceStore()
            let configurationSHA256 =
                try configuration.machineConfigurationSHA256()
            let lifecycleTransport =
                try InvestigationLifecycleAppServerTransport(
                    investigationID: lifecycleID,
                    configurationSHA256: configurationSHA256,
                    validBefore: configuration.validBefore,
                    maximumLineBytes:
                        LifecycleInteractiveSessionRequest
                        .maximumAllowedLineBytes,
                    maximumSessionBytes:
                        LifecycleInteractiveSessionRequest
                        .maximumAllowedSessionBytes,
                    now: runtimeNow,
                    session: session,
                    retirementEvidenceStore: retirementEvidenceStore
                )
            let transportOwner =
                InvestigationRuntimeDiagnosticTransportOwner(
                    transport: lifecycleTransport,
                    session: session
                )
            let client = try CodexInteractiveAppServerClient(
                configuration: CodexInteractiveAppServerConfiguration(
                    allowedRuntimeRootURL: runtimeRoot,
                    projectedAuthSourceURL: authSource,
                    outputSchema: outputSchema,
                    maximumInputTextBytes:
                        configuration.maximumContextBytes
                ),
                transport: transportOwner
            )
            let runtime = InvestigationCodexSessionAdapter(
                client: client
            )
            let storeConfiguration = try LocalStoreConfiguration(
                applicationSupportBaseURL: URL(
                    filePath: configuration.supportRootPath,
                    directoryHint: .isDirectory
                ),
                cachesBaseURL: URL(
                    filePath: configuration.runtimeRootPath,
                    directoryHint: .isDirectory
                )
            )
            guard
                storeConfiguration.evidenceDatabaseURL.path
                    == configuration.storePath
            else {
                throw InvestigationRuntimeDiagnosticCompositionError
                    .invalidConfiguration
            }
            let store = try EvidenceStore(configuration: storeConfiguration)
            let probe = InvestigationProbeBrokerAdapter(
                broker: ProbeBroker(),
                allowedRoots: [
                    URL(
                        filePath: configuration.sourceRootPath,
                        directoryHint: .isDirectory
                    ),
                ],
                maximumReadLevel: .level1,
                perCallTimeout: .seconds(5),
                perCallOutputByteLimit: min(
                    configuration.maximumContextBytes,
                    ProbeRequest.maximumSnippetBytes
                )
            )
            let domainIdentity =
                try InvestigationRuntimeDiagnosticDomainIdentity(
                    nonce: configuration.nonce
                )
            let lifecycle =
                InvestigationRuntimeDiagnosticLifecycleOwner(
                    identity: domainIdentity,
                    transportOwner: transportOwner
                )
            let facade = InvestigationRuntimeDiagnosticFacade(
                store: store,
                session: runtime,
                lifecycle: lifecycle,
                probe: probe,
                idProvider: domainIdentity,
                monotonicNow: {
                    DispatchTime.now().uptimeNanoseconds
                }
            )
            return Self(
                nonce: configuration.nonce,
                investigationID: domainIdentity.investigationID,
                storePath: configuration.storePath,
                helperExecutablePath:
                    installation.helperExecutableURL.path,
                configurationSHA256: configurationSHA256,
                runtimeFacade: facade,
                transportOwner: transportOwner,
                retirementEvidenceStore: retirementEvidenceStore
            )
        } catch let error
            as InvestigationRuntimeDiagnosticCompositionError
        {
            throw error
        } catch {
            throw InvestigationRuntimeDiagnosticCompositionError
                .compositionUnavailable
        }
    }

    public func retirePreparedComposition() async
        -> InvestigationRuntimeDiagnosticCompositionRetirement
    {
        do {
            return try await transportOwner.retirePrepared()
                ? .retiredWithoutStarting
                : .retiredAfterUse
        } catch {
            return .retirementFailed
        }
    }

    package func retirePreparedCompositionWithEvidence() async throws
        -> InvestigationLifecycleRetirementEvidence?
    {
        _ = try await transportOwner.retirePrepared()
        return await retirementEvidenceStore.consume()
    }

}

package struct InvestigationRuntimeDiagnosticBindingObservation:
    Sendable,
    Equatable
{
    package let installedAppURL: URL
    package let helperExecutableURL: URL
    package let appExecutableName: String
    package let appExecutableSHA256: String
    package let helperExecutableSHA256: String
    package let appBundleIdentifier: String
    package let helperSigningIdentifier: String
    package let serviceIdentifier: String
    package let machineDriverExecutableURL: URL
    package let machineDriverExecutableSHA256: String
    package let machineDriverSigningIdentifier: String
    package let machineDriverDesignatedRequirementSHA256: String
    package let machineDriverCodeDirectoryHash: String
    package let machineClaimServiceIdentifier: String

    package init(
        installedAppURL: URL,
        helperExecutableURL: URL,
        appExecutableName: String,
        appExecutableSHA256: String,
        helperExecutableSHA256: String,
        appBundleIdentifier: String,
        helperSigningIdentifier: String,
        serviceIdentifier: String,
        machineDriverExecutableURL: URL,
        machineDriverExecutableSHA256: String,
        machineDriverSigningIdentifier: String,
        machineDriverDesignatedRequirementSHA256: String,
        machineDriverCodeDirectoryHash: String,
        machineClaimServiceIdentifier: String
    ) {
        self.installedAppURL = installedAppURL.standardizedFileURL
        self.helperExecutableURL =
            helperExecutableURL.standardizedFileURL
        self.appExecutableName = appExecutableName
        self.appExecutableSHA256 = appExecutableSHA256
        self.helperExecutableSHA256 = helperExecutableSHA256
        self.appBundleIdentifier = appBundleIdentifier
        self.helperSigningIdentifier = helperSigningIdentifier
        self.serviceIdentifier = serviceIdentifier
        self.machineDriverExecutableURL =
            machineDriverExecutableURL.standardizedFileURL
        self.machineDriverExecutableSHA256 =
            machineDriverExecutableSHA256
        self.machineDriverSigningIdentifier =
            machineDriverSigningIdentifier
        self.machineDriverDesignatedRequirementSHA256 =
            machineDriverDesignatedRequirementSHA256
        self.machineDriverCodeDirectoryHash =
            machineDriverCodeDirectoryHash
        self.machineClaimServiceIdentifier =
            machineClaimServiceIdentifier
    }

    package static func installed() throws -> Self {
        let contract = try LifecycleLocalInstallationContract()
        let reader = LifecycleBundleSigningIdentityReader()
        let appEvidence = try reader.evidence(
            bundleURL: contract.installedAppURL
        )
        let helperEvidence = try reader.evidence(
            bundleURL: contract.helperExecutableURL
        )
        let machineDriverEvidence = try reader.evidence(
            bundleURL: contract.machineDriverExecutableURL
        )
        guard
            let bundle = Bundle(url: contract.installedAppURL),
            let executableURL = bundle.executableURL,
            let bundleIdentifier = bundle.bundleIdentifier
        else {
            throw InvestigationRuntimeDiagnosticCompositionError
                .bindingMismatch
        }
        return Self(
            installedAppURL: contract.installedAppURL,
            helperExecutableURL: contract.helperExecutableURL,
            appExecutableName: executableURL.lastPathComponent,
            appExecutableSHA256: appEvidence.executableSHA256,
            helperExecutableSHA256:
                helperEvidence.executableSHA256,
            appBundleIdentifier: bundleIdentifier,
            helperSigningIdentifier:
                helperEvidence.identity.signingIdentifier,
            serviceIdentifier: contract.machServiceName,
            machineDriverExecutableURL:
                contract.machineDriverExecutableURL,
            machineDriverExecutableSHA256:
                machineDriverEvidence.executableSHA256,
            machineDriverSigningIdentifier:
                machineDriverEvidence.identity.signingIdentifier,
            machineDriverDesignatedRequirementSHA256:
                machineDriverEvidence.identity
                    .designatedRequirementSHA256,
            machineDriverCodeDirectoryHash:
                machineDriverEvidence.identity.codeDirectoryHash,
            machineClaimServiceIdentifier:
                contract.machineClaimMachServiceName
        )
    }

    package func matches(
        _ binding: SignedInvestigationRuntimeBinding
    ) -> Bool {
        installedAppURL.path
            == "/Library/Application Support/Stornaut/"
                + "Stornaut-R5-Diagnostic.app"
            && helperExecutableURL.path
                == installedAppURL.appending(
                    path: "Contents/MacOS/"
                        + "StornautLifecycleHelper"
                ).path
            && appExecutableName == "StornautInvestigationDiagnostic"
            && appExecutableSHA256 == binding.appExecutableSHA256
            && helperExecutableSHA256
                == binding.helperExecutableSHA256
            && appBundleIdentifier == binding.appBundleIdentifier
            && helperSigningIdentifier
                == "com.eriklee.stornaut.lifecycle.helper"
            && serviceIdentifier
                == binding.helperServiceIdentifier
            && machineDriverExecutableURL
                == installedAppURL.appending(
                    path: "Contents/MacOS/"
                        + "StornautInvestigationMachineDriver"
                )
            && machineDriverExecutableSHA256
                == binding.machineDriver.executableSHA256
            && machineDriverSigningIdentifier
                == binding.machineDriver.signingIdentifier
            && machineDriverDesignatedRequirementSHA256
                == binding.machineDriver
                    .designatedRequirementSHA256
            && machineDriverCodeDirectoryHash
                == binding.machineDriver.codeDirectoryHash
            && machineClaimServiceIdentifier
                == binding.machineDriver
                    .machineClaimServiceIdentifier
    }
}

private actor InvestigationRuntimeDiagnosticTransportOwner:
    CodexInteractiveAppServerTransport
{
    private enum State {
        case ready
        case used
        case retiring
        case retired
        case failed
    }

    private let transport: InvestigationLifecycleAppServerTransport
    private let session: LifecycleInteractiveSessionXPCClient
    private var state = State.ready
    private var retirementTask: Task<
        InvestigationLifecycleRetirementEvidence,
        any Error
    >?
    private var retirementEvidence:
        InvestigationLifecycleRetirementEvidence?

    init(
        transport: InvestigationLifecycleAppServerTransport,
        session: LifecycleInteractiveSessionXPCClient
    ) {
        self.transport = transport
        self.session = session
    }

    func writeLine(_ line: Data) async throws {
        try admitUse()
        do {
            try await transport.writeLine(line)
        } catch {
            state = .failed
            throw error
        }
    }

    func readLine() async throws -> Data {
        try admitUse()
        do {
            return try await transport.readLine()
        } catch {
            state = .failed
            throw error
        }
    }

    func retire() async throws {
        _ = try await retirePrepared()
    }

    func retirePrepared() async throws -> Bool {
        if let retirementTask {
            _ = try await retirementTask.value
            return false
        }
        switch state {
        case .retired:
            return false
        case .retiring:
            throw InvestigationRuntimeDiagnosticCompositionError
                .compositionUnavailable
        case .ready:
            state = .retired
            await session.invalidate()
            return true
        case .used, .failed:
            break
        }

        state = .retiring
        let transport = self.transport
        let session = self.session
        let task = Task {
            do {
                let evidence = try await transport
                    .retireWithEvidence()
                await session.invalidate()
                return evidence
            } catch {
                await session.invalidate()
                throw error
            }
        }
        retirementTask = task
        do {
            retirementEvidence = try await task.value
            state = .retired
            return false
        } catch {
            state = .failed
            throw error
        }
    }

    private func admitUse() throws {
        switch state {
        case .ready, .used:
            state = .used
        case .retiring, .retired, .failed:
            throw InvestigationRuntimeDiagnosticCompositionError
                .compositionUnavailable
        }
    }
}

private final class InvestigationRuntimeDiagnosticLifecycleOwner:
    InvestigationLifecycleOwning,
    @unchecked Sendable
{
    private let identity: InvestigationRuntimeDiagnosticDomainIdentity
    private let transportOwner:
        InvestigationRuntimeDiagnosticTransportOwner

    init(
        identity: InvestigationRuntimeDiagnosticDomainIdentity,
        transportOwner:
            InvestigationRuntimeDiagnosticTransportOwner
    ) {
        self.identity = identity
        self.transportOwner = transportOwner
    }

    func drain(
        investigationID: InvestigationID,
        runID: InvestigationRunID
    ) async throws -> InvestigationLifecycleDrainResultV1 {
        guard
            identity.matches(
                investigationID: investigationID,
                runID: runID
            )
        else {
            throw InvestigationRuntimeDiagnosticCompositionError
                .bindingMismatch
        }
        try await transportOwner.retire()
        return InvestigationLifecycleDrainResultV1(
            auditSessionEmpty: true,
            managedProxyOwnerEmpty: true,
            probeWorkerEmpty: true
        )
    }
}

private final class InvestigationRuntimeDiagnosticDomainIdentity:
    InvestigationIDProviding,
    @unchecked Sendable
{
    let investigationID: InvestigationID
    let runID: InvestigationRunID
    private let reportIDValue: InvestigationReportID

    init(nonce: UUID) throws {
        let value = nonce.uuidString.lowercased()
        guard
            let investigationID = InvestigationID(
                rawValue: "investigation-\(value)"
            ),
            let runID = InvestigationRunID(
                rawValue: "investigation-run-\(value)"
            ),
            let reportID = InvestigationReportID(
                rawValue: "investigation-report-\(value)"
            )
        else {
            throw InvestigationRuntimeDiagnosticCompositionError
                .invalidConfiguration
        }
        self.investigationID = investigationID
        self.runID = runID
        reportIDValue = reportID
    }

    func reportID(
        investigationID: InvestigationID,
        runID: InvestigationRunID
    ) throws -> InvestigationReportID {
        guard
            matches(
                investigationID: investigationID,
                runID: runID
            )
        else {
            throw InvestigationRuntimeDiagnosticCompositionError
                .bindingMismatch
        }
        return reportIDValue
    }

    func matches(
        investigationID: InvestigationID,
        runID: InvestigationRunID
    ) -> Bool {
        investigationID == self.investigationID
            && runID == self.runID
    }
}

private func currentAuthSourceURL() throws -> URL {
    let userID = geteuid()
    guard
        userID > 0,
        let entry = getpwuid(userID),
        entry.pointee.pw_uid == userID,
        let home = entry.pointee.pw_dir
    else {
        throw InvestigationRuntimeDiagnosticCompositionError
            .compositionUnavailable
    }
    let homeURL = URL(
        filePath: String(cString: home),
        directoryHint: .isDirectory
    ).resolvingSymlinksInPath().standardizedFileURL
    var information = stat()
    guard
        homeURL.path.hasPrefix("/"),
        lstat(homeURL.path, &information) == 0,
        information.st_mode & S_IFMT == S_IFDIR,
        information.st_uid == userID
    else {
        throw InvestigationRuntimeDiagnosticCompositionError
            .compositionUnavailable
    }
    return homeURL.appending(path: ".codex/auth.json")
}
#endif
