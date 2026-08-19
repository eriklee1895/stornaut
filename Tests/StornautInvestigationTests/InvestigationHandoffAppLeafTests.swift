import Foundation
import Testing
@testable import StornautInvestigationDiagnostic
@testable import StornautInvestigationHandoffContract

@Suite("Investigation inherited-FD App leaf")
struct InvestigationHandoffAppLeafTests {
    @Test
    func successfulRunUsesTheExactClosedSequenceAndJoins() async throws {
        let fixture = try AppLeafFixture()
        let operations = ScriptedAppLeafOperations(fixture: fixture)
        let leaf = InvestigationHandoffAppLeaf(
            bootstrap: fixture.bootstrap,
            driverClaim: fixture.driverClaim,
            operations: operations
        )

        #expect(try await leaf.run() == .completed)
        let calls = await operations.observedCalls()
        #expect(calls.map(\.kind) == AppLeafCallKind.allCases)
        #expect(calls.compactMap(\.frame).map(\.kind) == [
            .preDropReady,
            .dropEvidence,
            .configurationAcknowledgement,
            .hello,
            .handle,
            .alive,
        ])
        for frame in calls.compactMap(\.frame) {
            #expect(frame.epochUUID == fixture.bootstrap.epochUUID)
            #expect(
                frame.epochDeadlineNanoseconds
                    == fixture.bootstrap.epochDeadlineNanoseconds
            )
        }
        #expect(calls.compactMap(\.frame).first?.sender == fixture.preDropClaim)
        #expect(
            calls.compactMap(\.frame).dropFirst().allSatisfy {
                $0.sender == fixture.postDropClaim
            }
        )
    }

    @Test
    func leafIsOneShotAndTerminalAfterSuccess() async throws {
        let fixture = try AppLeafFixture()
        let leaf = InvestigationHandoffAppLeaf(
            bootstrap: fixture.bootstrap,
            driverClaim: fixture.driverClaim,
            operations: ScriptedAppLeafOperations(fixture: fixture)
        )
        #expect(try await leaf.run() == .completed)
        await #expect(throws: InvestigationHandoffAppLeafError.alreadyConsumed) {
            _ = try await leaf.run()
        }
    }

    @Test
    func wrongIncomingStageSenderEpochDeadlineAndPayloadFailTerminally()
        async throws
    {
        let fixture = try AppLeafFixture()
        let mutations: [AppLeafMutation] = [
            .dropReleaseFrame(try fixture.incoming(kind: .release)),
            .dropReleaseFrame(try fixture.incoming(
                kind: .dropRelease,
                sender: fixture.foreignDriverClaim
            )),
            .configurationFrame(try fixture.incoming(
                kind: .configuration,
                epochUUID: fixture.foreignEpochUUID,
                payload: .configuration(fixture.configuration)
            )),
            .configurationFrame(try fixture.incoming(
                kind: .configuration,
                deadline: fixture.bootstrap.epochDeadlineNanoseconds + 1,
                payload: .configuration(fixture.configuration)
            )),
            .configurationFrame(try fixture.incoming(kind: .release)),
            .acknowledgementFrame(try fixture.incoming(kind: .release)),
            .releaseFrame(try fixture.incoming(kind: .exit)),
            .exitFrame(try fixture.incoming(kind: .release)),
        ]

        for mutation in mutations {
            let operations = ScriptedAppLeafOperations(
                fixture: fixture,
                mutation: mutation
            )
            let leaf = InvestigationHandoffAppLeaf(
                bootstrap: fixture.bootstrap,
                driverClaim: fixture.driverClaim,
                operations: operations
            )
            await #expect(throws: InvestigationHandoffAppLeafError.invalidTransition) {
                _ = try await leaf.run()
            }
            await #expect(throws: InvestigationHandoffAppLeafError.alreadyConsumed) {
                _ = try await leaf.run()
            }
        }
    }

    @Test
    func preAndPostDropClaimsAndEvidenceMustJoinExactly() async throws {
        let fixture = try AppLeafFixture()
        let mutations: [AppLeafMutation] = [
            .preDropClaim(fixture.postDropClaim),
            .dropResult(try InvestigationHandoffAppLeafDropResult(
                processClaim: fixture.foreignPostDropClaim,
                evidence: fixture.dropEvidence
            )),
            .dropResult(try InvestigationHandoffAppLeafDropResult(
                processClaim: fixture.postDropClaim,
                evidence: fixture.foreignDropEvidence
            )),
        ]
        for mutation in mutations {
            let leaf = InvestigationHandoffAppLeaf(
                bootstrap: fixture.bootstrap,
                driverClaim: fixture.driverClaim,
                operations: ScriptedAppLeafOperations(
                    fixture: fixture,
                    mutation: mutation
                )
            )
            await #expect(throws: InvestigationHandoffAppLeafError.invalidTransition) {
                _ = try await leaf.run()
            }
        }
    }

    @Test
    func configurationAndHandleMustShareNonceAndDigest() async throws {
        let fixture = try AppLeafFixture()
        for handle in [
            try fixture.handle(investigationUUID: fixture.foreignEpochUUID),
            try fixture.handle(configurationSHA256: fixture.foreignDigest),
        ] {
            let leaf = InvestigationHandoffAppLeaf(
                bootstrap: fixture.bootstrap,
                driverClaim: fixture.driverClaim,
                operations: ScriptedAppLeafOperations(
                    fixture: fixture,
                    mutation: .handle(handle)
                )
            )
            await #expect(throws: InvestigationHandoffAppLeafError.invalidTransition) {
                _ = try await leaf.run()
            }
        }
    }

    @Test
    func handleAcknowledgementMustHashTheCompleteExactHandle() async throws {
        let fixture = try AppLeafFixture()
        let wrong = InvestigationHandoffRetirementHandleAcknowledgement(
            handleSHA256: fixture.foreignDigest
        )
        let leaf = InvestigationHandoffAppLeaf(
            bootstrap: fixture.bootstrap,
            driverClaim: fixture.driverClaim,
            operations: ScriptedAppLeafOperations(
                fixture: fixture,
                mutation: .acknowledgementFrame(try fixture.incoming(
                    kind: .acknowledgement,
                    payload: .retirementHandleAcknowledgement(wrong)
                ))
            )
        )
        await #expect(throws: InvestigationHandoffAppLeafError.invalidTransition) {
            _ = try await leaf.run()
        }
    }

    @Test
    func everyInjectedOperationFailureIsTerminalAndSanitized() async throws {
        let fixture = try AppLeafFixture()
        for failure in AppLeafCallKind.allCases {
            let leaf = InvestigationHandoffAppLeaf(
                bootstrap: fixture.bootstrap,
                driverClaim: fixture.driverClaim,
                operations: ScriptedAppLeafOperations(
                    fixture: fixture,
                    failure: failure
                )
            )
            await #expect(throws: InvestigationHandoffAppLeafError.operationFailed) {
                _ = try await leaf.run()
            }
            await #expect(throws: InvestigationHandoffAppLeafError.alreadyConsumed) {
                _ = try await leaf.run()
            }
        }
    }

    @Test
    func transportLossAfterAliveNeverBecomesSuccess() async throws {
        let fixture = try AppLeafFixture()
        let leaf = InvestigationHandoffAppLeaf(
            bootstrap: fixture.bootstrap,
            driverClaim: fixture.driverClaim,
            operations: ScriptedAppLeafOperations(
                fixture: fixture,
                failure: .receiveExit
            )
        )
        await #expect(throws: InvestigationHandoffAppLeafError.operationFailed) {
            _ = try await leaf.run()
        }
    }

    @Test
    func publicEntryIsNoArgumentAndFailsClosedUntilB3() {
        #expect(InvestigationHandoffAppLeafEntryPoint.run() == 78)
    }
}

private enum AppLeafCallKind: String, CaseIterable, Sendable {
    case preDropClaim
    case sendPreDropReady
    case receiveDropRelease
    case performIdentityDrop
    case sendDropEvidence
    case receiveConfiguration
    case acknowledgeConfiguration
    case sendConfigurationAcknowledgement
    case sendHello
    case retirementHandle
    case sendRetirementHandle
    case receiveHandleAcknowledgement
    case receiveRelease
    case sendAlive
    case halfCloseAndProveEOF
    case receiveExit
}

private struct AppLeafCall: Sendable {
    let kind: AppLeafCallKind
    let frame: InvestigationHandoffFrame?
}

private enum AppLeafMutation: Sendable {
    case none
    case preDropClaim(InvestigationHandoffProcessClaim)
    case dropReleaseFrame(InvestigationHandoffFrame)
    case dropResult(InvestigationHandoffAppLeafDropResult)
    case configurationFrame(InvestigationHandoffFrame)
    case handle(InvestigationHandoffRetirementHandle)
    case acknowledgementFrame(InvestigationHandoffFrame)
    case releaseFrame(InvestigationHandoffFrame)
    case exitFrame(InvestigationHandoffFrame)
}

private struct AppLeafFixture: Sendable {
    let bootstrap: InvestigationHandoffEpochBootstrap
    let preDropClaim: InvestigationHandoffProcessClaim
    let postDropClaim: InvestigationHandoffProcessClaim
    let foreignPostDropClaim: InvestigationHandoffProcessClaim
    let driverClaim: InvestigationHandoffProcessClaim
    let foreignDriverClaim: InvestigationHandoffProcessClaim
    let foreignEpochUUID: UUID
    let configuration: Data
    let configurationAcknowledgement:
        InvestigationHandoffConfigurationAcknowledgement
    let dropEvidence: InvestigationHandoffDropEvidence
    let foreignDropEvidence: InvestigationHandoffDropEvidence
    let retirementHandle: InvestigationHandoffRetirementHandle
    let foreignDigest: InvestigationHandoffSHA256

    init() throws {
        let epochUUID = try Self.fixedUUID(0x11)
        bootstrap = try InvestigationHandoffEpochBootstrap(
            epochUUID: epochUUID,
            epochDeadlineNanoseconds: 9_000_000_000
        )
        preDropClaim = try Self.processClaim(pid: 42, version: 7, uid: 0, asid: 9)
        postDropClaim = try Self.processClaim(pid: 42, version: 7, uid: 501, asid: 9)
        foreignPostDropClaim = try Self.processClaim(
            pid: 43, version: 7, uid: 501, asid: 9
        )
        driverClaim = try Self.processClaim(pid: 84, version: 8, uid: 0, asid: 10)
        foreignDriverClaim = try Self.processClaim(
            pid: 85, version: 8, uid: 0, asid: 10
        )
        foreignEpochUUID = try Self.fixedUUID(0x12)
        configuration = Data("configuration".utf8)
        let configurationDigest = InvestigationHandoffSHA256.hashing(configuration)
        foreignDigest = try Self.digest(0xee)
        configurationAcknowledgement =
            try InvestigationHandoffConfigurationAcknowledgement(
                epochUUID: epochUUID,
                ordinal: 0,
                configurationNonce: Self.fixedUUID(0x21),
                scenario: .success,
                configurationSHA256: configurationDigest,
                signedRuntimeBindingSHA256: Self.digest(0x31)
            )
        dropEvidence = try Self.evidence(pid: 42)
        foreignDropEvidence = try Self.evidence(pid: 43)
        retirementHandle = try InvestigationHandoffRetirementHandle(
            token: Self.fixedUUID(0x41),
            investigationUUID: configurationAcknowledgement.configurationNonce,
            retireOperationUUID: Self.fixedUUID(0x42),
            configurationSHA256: configurationDigest,
            validBefore: InvestigationHandoffUTCMicroseconds(rawValue: 2_000_000)
        )
    }

    func incoming(
        kind: InvestigationHandoffFrameKind,
        sender: InvestigationHandoffProcessClaim? = nil,
        epochUUID: UUID? = nil,
        deadline: UInt64? = nil,
        payload: InvestigationHandoffFramePayload = .empty
    ) throws -> InvestigationHandoffFrame {
        try InvestigationHandoffFrame(
            kind: kind,
            epochUUID: epochUUID ?? bootstrap.epochUUID,
            epochDeadlineNanoseconds:
                deadline ?? bootstrap.epochDeadlineNanoseconds,
            sender: sender ?? driverClaim,
            payload: payload
        )
    }

    func handle(
        investigationUUID: UUID? = nil,
        configurationSHA256: InvestigationHandoffSHA256? = nil
    ) throws -> InvestigationHandoffRetirementHandle {
        try InvestigationHandoffRetirementHandle(
            token: retirementHandle.token,
            investigationUUID:
                investigationUUID ?? retirementHandle.investigationUUID,
            retireOperationUUID: retirementHandle.retireOperationUUID,
            configurationSHA256:
                configurationSHA256 ?? retirementHandle.configurationSHA256,
            validBefore: retirementHandle.validBefore
        )
    }

    private static func processClaim(
        pid: UInt32,
        version: UInt32,
        uid: UInt32,
        asid: UInt32
    ) throws -> InvestigationHandoffProcessClaim {
        try InvestigationHandoffProcessClaim(
            processID: pid,
            processIDVersion: version,
            effectiveUserID: uid,
            auditSessionID: asid
        )
    }

    private static func evidence(
        pid: UInt32
    ) throws -> InvestigationHandoffDropEvidence {
        try InvestigationHandoffDropEvidence(
            realUserID: 501, effectiveUserID: 501, savedUserID: 501,
            realGroupID: 20, effectiveGroupID: 20, savedGroupID: 20,
            supplementaryGroups: Array(UInt32(1)...UInt32(15)) + [20],
            auditTokenWords: [501, 501, 20, 501, 20, pid, 9, 7],
            setuidRootErrno: 1, seteuidRootErrno: 1, setgidRootErrno: 1
        )
    }

    private static func fixedUUID(_ byte: UInt8) throws -> UUID {
        let suffix = String(format: "%02x", byte)
        return try #require(UUID(
            uuidString: "00000000-0000-0000-0000-0000000000" + suffix
        ))
    }

    private static func digest(
        _ byte: UInt8
    ) throws -> InvestigationHandoffSHA256 {
        try InvestigationHandoffSHA256(
            rawBytes: Data(repeating: byte, count: 32)
        )
    }
}

private actor ScriptedAppLeafOperations:
    InvestigationHandoffAppLeafOperations
{
    private let fixture: AppLeafFixture
    private let mutation: AppLeafMutation
    private let failure: AppLeafCallKind?
    private var calls: [AppLeafCall] = []

    init(
        fixture: AppLeafFixture,
        mutation: AppLeafMutation = .none,
        failure: AppLeafCallKind? = nil
    ) {
        self.fixture = fixture
        self.mutation = mutation
        self.failure = failure
    }

    func observedCalls() -> [AppLeafCall] { calls }

    func preDropClaim() throws -> InvestigationHandoffProcessClaim {
        try record(.preDropClaim)
        if case let .preDropClaim(value) = mutation { return value }
        return fixture.preDropClaim
    }

    func sendPreDropReady(_ frame: InvestigationHandoffFrame) throws {
        try record(.sendPreDropReady, frame: frame)
    }

    func receiveDropRelease() throws -> InvestigationHandoffFrame {
        try record(.receiveDropRelease)
        if case let .dropReleaseFrame(value) = mutation { return value }
        return try fixture.incoming(kind: .dropRelease)
    }

    func performIdentityDrop() throws -> InvestigationHandoffAppLeafDropResult {
        try record(.performIdentityDrop)
        if case let .dropResult(value) = mutation { return value }
        return try InvestigationHandoffAppLeafDropResult(
            processClaim: fixture.postDropClaim,
            evidence: fixture.dropEvidence
        )
    }

    func sendDropEvidence(_ frame: InvestigationHandoffFrame) throws {
        try record(.sendDropEvidence, frame: frame)
    }

    func receiveConfiguration() throws -> InvestigationHandoffFrame {
        try record(.receiveConfiguration)
        if case let .configurationFrame(value) = mutation { return value }
        return try fixture.incoming(
            kind: .configuration,
            payload: .configuration(fixture.configuration)
        )
    }

    func acknowledgeConfiguration(
        _ configuration: Data
    ) throws -> InvestigationHandoffConfigurationAcknowledgement {
        try record(.acknowledgeConfiguration)
        #expect(configuration == fixture.configuration)
        return fixture.configurationAcknowledgement
    }

    func sendConfigurationAcknowledgement(
        _ frame: InvestigationHandoffFrame
    ) throws {
        try record(.sendConfigurationAcknowledgement, frame: frame)
    }

    func sendHello(_ frame: InvestigationHandoffFrame) throws {
        try record(.sendHello, frame: frame)
    }

    func retirementHandle() throws -> InvestigationHandoffRetirementHandle {
        try record(.retirementHandle)
        if case let .handle(value) = mutation { return value }
        return fixture.retirementHandle
    }

    func sendRetirementHandle(_ frame: InvestigationHandoffFrame) throws {
        try record(.sendRetirementHandle, frame: frame)
    }

    func receiveHandleAcknowledgement() throws -> InvestigationHandoffFrame {
        try record(.receiveHandleAcknowledgement)
        if case let .acknowledgementFrame(value) = mutation { return value }
        let acknowledgement = InvestigationHandoffRetirementHandleAcknowledgement(
            handleSHA256: .hashing(try fixture.retirementHandle.encoded())
        )
        return try fixture.incoming(
            kind: .acknowledgement,
            payload: .retirementHandleAcknowledgement(acknowledgement)
        )
    }

    func receiveRelease() throws -> InvestigationHandoffFrame {
        try record(.receiveRelease)
        if case let .releaseFrame(value) = mutation { return value }
        return try fixture.incoming(kind: .release)
    }

    func sendAlive(_ frame: InvestigationHandoffFrame) throws {
        try record(.sendAlive, frame: frame)
    }

    func halfCloseAndProveEOF() throws {
        try record(.halfCloseAndProveEOF)
    }

    func receiveExit() throws -> InvestigationHandoffFrame {
        try record(.receiveExit)
        if case let .exitFrame(value) = mutation { return value }
        return try fixture.incoming(kind: .exit)
    }

    private func record(
        _ kind: AppLeafCallKind,
        frame: InvestigationHandoffFrame? = nil
    ) throws {
        calls.append(AppLeafCall(kind: kind, frame: frame))
        if failure == kind { throw AppLeafInjectedFailure() }
    }
}

private struct AppLeafInjectedFailure: Error {}
