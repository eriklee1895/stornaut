#if DEBUG
import Darwin
import Foundation
import StornautCodex
import StornautCore
import StornautInvestigation
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

public final class InvestigationRuntimeDiagnosticComposition:
    @unchecked Sendable
{
    public let nonce: UUID
    public let investigationID: String
    public let storePath: String
    public let helperExecutablePath: String
    public let hasRuntimeFacade: Bool

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
        runtimeFacade: InvestigationRuntimeDiagnosticFacade,
        transportOwner: InvestigationRuntimeDiagnosticTransportOwner,
        retirementEvidenceStore:
            InvestigationLifecycleRetirementEvidenceStore
    ) {
        self.nonce = nonce
        self.investigationID = investigationID.rawValue
        self.storePath = storePath
        self.helperExecutablePath = helperExecutablePath
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
            let lifecycleTransport =
                try InvestigationLifecycleAppServerTransport(
                    investigationID: lifecycleID,
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

    package init(
        installedAppURL: URL,
        helperExecutableURL: URL,
        appExecutableName: String,
        appExecutableSHA256: String,
        helperExecutableSHA256: String,
        appBundleIdentifier: String,
        helperSigningIdentifier: String,
        serviceIdentifier: String
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
            serviceIdentifier: contract.machServiceName
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
