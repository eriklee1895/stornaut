import Foundation
import Testing
@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationInstalledL2

@Suite("Installed L2 observer composition", .serialized)
struct InstalledL2ObserverTests {
    @Test
    func darwinClockProducesOrderedPositiveSamples() throws {
        let clock = InvestigationInstalledL2DarwinClock()
        let first = try clock.sample()
        let second = try clock.sample()

        #expect(first.wallUTC <= second.wallUTC)
        #expect(first.continuousNanoseconds <= second.continuousNanoseconds)
    }

    @Test
    func composesEachFixedReaderOnceBetweenPairedClockSamples() throws {
        let fixture = try InstalledL2ObserverFixture()
        let trace = InstalledL2ObserverTrace()
        let observer = try fixture.observer(trace: trace)

        let result = try observer.observe(
            projection: fixture.projection,
            expectedApp: fixture.appIdentity,
            expectedHelper: fixture.helperIdentity
        )

        #expect(trace.events == [
            .clock, .artifacts, .app, .helper, .driver, .service, .clock,
        ])
        #expect(result.projectionSHA256 == fixture.projection.projectionSHA256)
        #expect(result.app.identity == fixture.appIdentity)
        #expect(result.helper.identity == fixture.helperIdentity)
        #expect(result.app.staticSigning == fixture.appSigning)
        #expect(result.app.liveSigning == fixture.appSigning)
        #expect(result.helper.staticSigning == fixture.helperSigning)
        #expect(result.helper.liveSigning == fixture.helperSigning)
        #expect(result.machineDriver.staticSigning == fixture.driverSigning)
        #expect(result.machineDriver.liveSigning == fixture.driverSigning)
        #expect(result.service == .loaded(identity: fixture.helperIdentity))
        #expect(result.started == fixture.started)
        #expect(result.observed == fixture.observed)
    }

    @Test(arguments: InstalledL2ObserverFailureStage.allCases)
    fileprivate func everyPhysicalFailureStopsBeforeLaterReaders(
        _ stage: InstalledL2ObserverFailureStage
    ) throws {
        let fixture = try InstalledL2ObserverFixture()
        let trace = InstalledL2ObserverTrace()
        let observer = try fixture.observer(trace: trace, failure: stage)

        #expect(throws: InvestigationInstalledL2SemanticError.self) {
            _ = try observer.observe(
                projection: fixture.projection,
                expectedApp: fixture.appIdentity,
                expectedHelper: fixture.helperIdentity
            )
        }
        #expect(trace.events == stage.expectedTrace)
    }

    @Test(arguments: InstalledL2ObserverProcessDrift.allCases)
    fileprivate func processIdentityAndFixedPathAreRecheckedAtComposition(
        _ drift: InstalledL2ObserverProcessDrift
    ) throws {
        let fixture = try InstalledL2ObserverFixture()
        let trace = InstalledL2ObserverTrace()
        let observer = try fixture.observer(trace: trace, processDrift: drift)

        #expect(throws: InvestigationInstalledL2SemanticError.self) {
            _ = try observer.observe(
                projection: fixture.projection,
                expectedApp: fixture.appIdentity,
                expectedHelper: fixture.helperIdentity
            )
        }
        #expect(!trace.events.contains(.service))
        #expect(trace.events.last == (drift.isApp ? .app : .helper))
    }

    @Test(arguments: InstalledL2ObserverSemanticDrift.allCases)
    fileprivate func semanticDriftNeverProducesAnInstalledObservation(
        _ drift: InstalledL2ObserverSemanticDrift
    ) throws {
        let fixture = try InstalledL2ObserverFixture()
        let trace = InstalledL2ObserverTrace()
        let observer = try fixture.observer(trace: trace, semanticDrift: drift)

        #expect(throws: InvestigationInstalledL2SemanticError.self) {
            _ = try observer.observe(
                projection: fixture.projection,
                expectedApp: fixture.appIdentity,
                expectedHelper: fixture.helperIdentity
            )
        }
        #expect(trace.events == drift.expectedTrace)
    }

    @Test
    func wrongInputRolesAreRejectedBeforeClockOrPhysicalReads() throws {
        let fixture = try InstalledL2ObserverFixture()
        let trace = InstalledL2ObserverTrace()
        let observer = try fixture.observer(trace: trace)

        #expect(throws: InvestigationInstalledL2SemanticError.self) {
            _ = try observer.observe(
                projection: fixture.projection,
                expectedApp: fixture.helperIdentity,
                expectedHelper: fixture.appIdentity
            )
        }
        #expect(trace.events.isEmpty)
    }
}

private enum InstalledL2ObserverEvent: Sendable, Equatable {
    case clock, artifacts, app, helper, driver, service
}

private final class InstalledL2ObserverTrace: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [InstalledL2ObserverEvent] = []

    var events: [InstalledL2ObserverEvent] {
        lock.withLock { storage }
    }

    func append(_ event: InstalledL2ObserverEvent) {
        lock.withLock { storage.append(event) }
    }
}

private enum InstalledL2ObserverFailureStage: CaseIterable {
    case firstClock, artifacts, app, helper, driver, service, secondClock

    var expectedTrace: [InstalledL2ObserverEvent] {
        switch self {
        case .firstClock: [.clock]
        case .artifacts: [.clock, .artifacts]
        case .app: [.clock, .artifacts, .app]
        case .helper: [.clock, .artifacts, .app, .helper]
        case .driver: [.clock, .artifacts, .app, .helper, .driver]
        case .service: [.clock, .artifacts, .app, .helper, .driver, .service]
        case .secondClock:
            [.clock, .artifacts, .app, .helper, .driver, .service, .clock]
        }
    }
}

private enum InstalledL2ObserverProcessDrift: CaseIterable {
    case appIdentity, appPath, helperIdentity, helperPath

    var isApp: Bool {
        self == .appIdentity || self == .appPath
    }
}

private enum InstalledL2ObserverSemanticDrift: CaseIterable {
    case appStaticLiveMismatch, helperStaticLiveMismatch
    case driverStaticLiveMismatch, serviceAbsent, serviceForeign
    case serviceUnavailable, wallRollback, wallExpiry, continuousRollback

    var expectedTrace: [InstalledL2ObserverEvent] {
        switch self {
        case .appStaticLiveMismatch:
            [.clock, .artifacts, .app]
        case .helperStaticLiveMismatch:
            [.clock, .artifacts, .app, .helper]
        case .serviceAbsent, .serviceForeign, .serviceUnavailable:
            [.clock, .artifacts, .app, .helper, .driver, .service]
        case .wallRollback, .wallExpiry, .continuousRollback,
             .driverStaticLiveMismatch:
            [.clock, .artifacts, .app, .helper, .driver, .service, .clock]
        }
    }
}

private struct InstalledL2ObserverFixture {
    let projection: InvestigationInstalledL2IdentityProjection
    let appIdentity: InvestigationMachineProcessIdentity
    let helperIdentity: InvestigationMachineProcessIdentity
    let appSigning: InvestigationInstalledL2SigningIdentity
    let helperSigning: InvestigationInstalledL2SigningIdentity
    let driverSigning: InvestigationInstalledL2SigningIdentity
    let artifacts: InvestigationInstalledL2ArtifactFacts
    let started: InvestigationInstalledL2ClockSample
    let observed: InvestigationInstalledL2ClockSample

    init() throws {
        appSigning = try Self.signing(
            identifier: "com.eriklee.stornaut", byte: 0x41, adHoc: false
        )
        helperSigning = try Self.signing(
            identifier: "com.eriklee.stornaut.lifecycle.helper",
            byte: 0x42, adHoc: false
        )
        driverSigning = try Self.signing(
            identifier: "com.eriklee.stornaut.investigation.machine-driver",
            byte: 0x43, adHoc: true
        )
        projection = try .init(
            epochUUID: Self.uuid(0x11),
            configurationNonce: Self.uuid(0x12),
            configurationValidBefore: .init(rawValue: 1_000),
            configurationSHA256: Self.digest(0x21),
            signedRuntimeBindingSHA256: Self.digest(0x22),
            appExecutableSHA256: Self.digest(0x31),
            appBundleIdentifier: "com.eriklee.stornaut",
            helperExecutableSHA256: Self.digest(0x32),
            helperServiceIdentifier: "com.eriklee.stornaut.lifecycle",
            machineDriverExecutableSHA256: Self.digest(0x33),
            machineDriverSigningIdentifier:
                "com.eriklee.stornaut.investigation.machine-driver",
            machineDriverDesignatedRequirementSHA256:
                driverSigning.designatedRequirementSHA256,
            machineDriverCodeDirectoryHash: driverSigning.codeDirectoryHash,
            machineClaimServiceIdentifier:
                "com.eriklee.stornaut.lifecycle.machine-claim"
        )
        appIdentity = try Self.identity(
            role: .app, pid: 701, version: 11, asid: 44_001, euid: 501
        )
        helperIdentity = try Self.identity(
            role: .helper, pid: 702, version: 12, asid: 44_001, euid: 0
        )
        artifacts = .init(
            artifacts: Dictionary(uniqueKeysWithValues:
                InvestigationInstalledL2ArtifactRole.allCases.map {
                    ($0, .presentValid)
                }
            ),
            appStaticSigning: appSigning,
            helperStaticSigning: helperSigning,
            machineDriverStaticSigning: driverSigning
        )
        started = try .init(
            wallUTC: .init(rawValue: 100), continuousNanoseconds: 200
        )
        observed = try .init(
            wallUTC: .init(rawValue: 101), continuousNanoseconds: 201
        )
    }

    func observer(
        trace: InstalledL2ObserverTrace,
        failure: InstalledL2ObserverFailureStage? = nil,
        processDrift: InstalledL2ObserverProcessDrift? = nil,
        semanticDrift: InstalledL2ObserverSemanticDrift? = nil
    ) throws -> InvestigationInstalledL2Observer {
        let paths = InvestigationInstalledL2FixedPaths()
        let appLiveSigning = semanticDrift == .appStaticLiveMismatch
            ? try Self.signing(
                identifier: "foreign.app", byte: 0x45, adHoc: false
            )
            : appSigning
        let helperLiveSigning = semanticDrift == .helperStaticLiveMismatch
            ? try Self.signing(
                identifier: "foreign.helper", byte: 0x46, adHoc: false
            )
            : helperSigning
        var app = InvestigationInstalledL2ObservedProcess(
            identity: appIdentity,
            executableURL: paths.appExecutable,
            liveSigning: appLiveSigning
        )
        var helper = InvestigationInstalledL2ObservedProcess(
            identity: helperIdentity,
            executableURL: paths.helperExecutable,
            liveSigning: helperLiveSigning
        )
        switch processDrift {
        case .appIdentity:
            app = .init(
                identity: helperIdentity, executableURL: paths.appExecutable,
                liveSigning: appSigning
            )
        case .appPath:
            app = .init(
                identity: appIdentity, executableURL: paths.helperExecutable,
                liveSigning: appSigning
            )
        case .helperIdentity:
            helper = .init(
                identity: appIdentity, executableURL: paths.helperExecutable,
                liveSigning: helperSigning
            )
        case .helperPath:
            helper = .init(
                identity: helperIdentity, executableURL: paths.appExecutable,
                liveSigning: helperSigning
            )
        case nil:
            break
        }

        let service: InvestigationInstalledL2ServiceObservation
        switch semanticDrift {
        case .serviceAbsent: service = .absent
        case .serviceForeign:
            service = .loaded(identity: try Self.identity(
                role: .helper, pid: 703, version: 13, asid: 44_001, euid: 0
            ))
        case .serviceUnavailable: service = .unavailable
        default: service = .loaded(identity: helperIdentity)
        }
        let finalClock: InvestigationInstalledL2ClockSample
        switch semanticDrift {
        case .wallRollback:
            finalClock = try .init(
                wallUTC: .init(rawValue: 99), continuousNanoseconds: 201
            )
        case .wallExpiry:
            finalClock = try .init(
                wallUTC: projection.configurationValidBefore,
                continuousNanoseconds: 201
            )
        case .continuousRollback:
            finalClock = try .init(
                wallUTC: .init(rawValue: 101), continuousNanoseconds: 199
            )
        default:
            finalClock = observed
        }
        let liveDriver = semanticDrift == .driverStaticLiveMismatch
            ? try Self.signing(
                identifier: "foreign.driver", byte: 0x44, adHoc: true
            )
            : driverSigning

        return InvestigationInstalledL2Observer(
            artifactReader: RecordingInstalledL2ObserverArtifactReader(
                trace: trace, result: failure == .artifacts
                    ? .failure(.installedContractUnproved) : .success(artifacts)
            ),
            processReader: RecordingInstalledL2ObserverProcessReader(
                trace: trace,
                app: failure == .app ? .unavailable : .observed(app),
                helper: failure == .helper ? .unavailable : .observed(helper),
                driver: failure == .driver ? .unavailable : .observed(liveDriver)
            ),
            serviceReader: RecordingInstalledL2ObserverServiceReader(
                trace: trace,
                result: failure == .service ? .unavailable : service
            ),
            clock: RecordingInstalledL2ObserverClock(
                trace: trace,
                results: [
                    failure == .firstClock
                        ? .failure(.installedContractUnproved) : .success(started),
                    failure == .secondClock
                        ? .failure(.installedContractUnproved) : .success(finalClock),
                ]
            )
        )
    }

    private static func signing(
        identifier: String, byte: UInt8, adHoc: Bool
    ) throws -> InvestigationInstalledL2SigningIdentity {
        try .init(
            signingIdentifier: identifier,
            designatedRequirementSHA256: digest(byte),
            codeDirectoryHash: Data(repeating: byte, count: 20),
            isAdHoc: adHoc
        )
    }

    private static func identity(
        role: InvestigationMachineProcessRole,
        pid: UInt32, version: UInt32, asid: UInt32, euid: UInt32
    ) throws -> InvestigationMachineProcessIdentity {
        try .init(
            role: role, processID: pid, processIDVersion: version,
            auditSessionID: asid, effectiveUserID: euid,
            auditTokenWords: [euid, euid, 20, euid, 20, pid, asid, version]
        )
    }

    private static func digest(_ byte: UInt8)
        throws -> InvestigationHandoffSHA256
    {
        try .init(rawBytes: Data(repeating: byte, count: 32))
    }

    private static func uuid(_ byte: UInt8) -> UUID {
        UUID(uuid: (byte, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    }
}

private final class RecordingInstalledL2ObserverArtifactReader:
    InvestigationInstalledL2ArtifactReading, @unchecked Sendable
{
    let trace: InstalledL2ObserverTrace
    let result: Result<
        InvestigationInstalledL2ArtifactFacts,
        InvestigationInstalledL2SemanticError
    >

    init(
        trace: InstalledL2ObserverTrace,
        result: Result<
            InvestigationInstalledL2ArtifactFacts,
            InvestigationInstalledL2SemanticError
        >
    ) {
        self.trace = trace
        self.result = result
    }

    func observe(projection: InvestigationInstalledL2IdentityProjection) throws
        -> InvestigationInstalledL2ArtifactFacts
    {
        trace.append(.artifacts)
        return try result.get()
    }
}

private final class RecordingInstalledL2ObserverProcessReader:
    InvestigationInstalledL2ProcessObserving, @unchecked Sendable
{
    let trace: InstalledL2ObserverTrace
    let app: InvestigationInstalledL2ProcessReadResult
    let helper: InvestigationInstalledL2ProcessReadResult
    let driver: InvestigationInstalledL2CurrentProcessSigningResult

    init(
        trace: InstalledL2ObserverTrace,
        app: InvestigationInstalledL2ProcessReadResult,
        helper: InvestigationInstalledL2ProcessReadResult,
        driver: InvestigationInstalledL2CurrentProcessSigningResult
    ) {
        self.trace = trace
        self.app = app
        self.helper = helper
        self.driver = driver
    }

    func observeApp(expected: InvestigationMachineProcessIdentity)
        -> InvestigationInstalledL2ProcessReadResult
    { trace.append(.app); return app }

    func observeHelper(expected: InvestigationMachineProcessIdentity)
        -> InvestigationInstalledL2ProcessReadResult
    { trace.append(.helper); return helper }

    func observeCurrentMachineDriverSigning()
        -> InvestigationInstalledL2CurrentProcessSigningResult
    { trace.append(.driver); return driver }
}

private final class RecordingInstalledL2ObserverServiceReader:
    InvestigationInstalledL2ServiceObserving, @unchecked Sendable
{
    let trace: InstalledL2ObserverTrace
    let result: InvestigationInstalledL2ServiceObservation

    init(
        trace: InstalledL2ObserverTrace,
        result: InvestigationInstalledL2ServiceObservation
    ) {
        self.trace = trace
        self.result = result
    }

    func observe(expectedHelper: InvestigationMachineProcessIdentity)
        -> InvestigationInstalledL2ServiceObservation
    { trace.append(.service); return result }
}

private final class RecordingInstalledL2ObserverClock:
    InvestigationInstalledL2ClockSampling, @unchecked Sendable
{
    let trace: InstalledL2ObserverTrace
    private let lock = NSLock()
    private var results: [Result<
        InvestigationInstalledL2ClockSample,
        InvestigationInstalledL2SemanticError
    >]

    init(
        trace: InstalledL2ObserverTrace,
        results: [Result<
            InvestigationInstalledL2ClockSample,
            InvestigationInstalledL2SemanticError
        >]
    ) {
        self.trace = trace
        self.results = results
    }

    func sample() throws -> InvestigationInstalledL2ClockSample {
        trace.append(.clock)
        return try lock.withLock { try results.removeFirst().get() }
    }
}
