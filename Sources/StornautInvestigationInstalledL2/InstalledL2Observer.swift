import Darwin
import Foundation
import StornautInvestigationHandoffContract

protocol InvestigationInstalledL2ArtifactReading: Sendable {
    func observe(
        projection: InvestigationInstalledL2IdentityProjection
    ) throws -> InvestigationInstalledL2ArtifactFacts
}

extension InvestigationInstalledL2ArtifactReader:
    InvestigationInstalledL2ArtifactReading {}

protocol InvestigationInstalledL2ProcessObserving: Sendable {
    func observeApp(
        expected: InvestigationMachineProcessIdentity
    ) -> InvestigationInstalledL2ProcessReadResult

    func observeHelper(
        expected: InvestigationMachineProcessIdentity
    ) -> InvestigationInstalledL2ProcessReadResult

    func observeCurrentMachineDriverSigning()
        -> InvestigationInstalledL2CurrentProcessSigningResult
}

extension InvestigationInstalledL2ProcessReader:
    InvestigationInstalledL2ProcessObserving {}

protocol InvestigationInstalledL2ServiceObserving: Sendable {
    func observe(
        expectedHelper: InvestigationMachineProcessIdentity
    ) -> InvestigationInstalledL2ServiceObservation
}

extension InvestigationInstalledL2FixedServiceReader:
    InvestigationInstalledL2ServiceObserving {}

protocol InvestigationInstalledL2ClockSampling: Sendable {
    func sample() throws -> InvestigationInstalledL2ClockSample
}

struct InvestigationInstalledL2DarwinClock:
    InvestigationInstalledL2ClockSampling,
    Sendable
{
    func sample() throws -> InvestigationInstalledL2ClockSample {
        do {
            return try InvestigationInstalledL2ClockSample(
                wallUTC: InvestigationHandoffUTCMicroseconds(
                    timeIntervalSince1970: Date().timeIntervalSince1970
                ),
                continuousNanoseconds:
                    try investigationInstalledL2ContinuousNanoseconds()
            )
        } catch {
            throw InvestigationInstalledL2SemanticError.installedContractUnproved
        }
    }
}

package struct InvestigationInstalledL2Observer: Sendable {
    private let artifactReader: any InvestigationInstalledL2ArtifactReading
    private let processReader: any InvestigationInstalledL2ProcessObserving
    private let serviceReader: any InvestigationInstalledL2ServiceObserving
    private let clock: any InvestigationInstalledL2ClockSampling
    private let paths = InvestigationInstalledL2FixedPaths()

    package init() {
        self.init(
            artifactReader: InvestigationInstalledL2ArtifactReader(),
            processReader: InvestigationInstalledL2ProcessReader(),
            serviceReader: InvestigationInstalledL2FixedServiceReader(),
            clock: InvestigationInstalledL2DarwinClock()
        )
    }

    init(
        artifactReader: any InvestigationInstalledL2ArtifactReading,
        processReader: any InvestigationInstalledL2ProcessObserving,
        serviceReader: any InvestigationInstalledL2ServiceObserving,
        clock: any InvestigationInstalledL2ClockSampling
    ) {
        self.artifactReader = artifactReader
        self.processReader = processReader
        self.serviceReader = serviceReader
        self.clock = clock
    }

    package func observe(
        projection: InvestigationInstalledL2IdentityProjection,
        expectedApp: InvestigationMachineProcessIdentity,
        expectedHelper: InvestigationMachineProcessIdentity
    ) throws -> InvestigationInstalledL2SemanticObservation {
        guard
            expectedApp.role == .app,
            expectedHelper.role == .helper,
            expectedApp != expectedHelper,
            expectedApp.processID != expectedHelper.processID
        else {
            throw InvestigationInstalledL2SemanticError.invalidValue
        }

        let started = try sampleClock()
        let artifacts = try readArtifacts(projection: projection)
        let app = try readProcess(
            processReader.observeApp(expected: expectedApp),
            expected: expectedApp,
            expectedURL: paths.appExecutable,
            executableSHA256: projection.appExecutableSHA256,
            staticSigning: artifacts.appStaticSigning
        )
        let helper = try readProcess(
            processReader.observeHelper(expected: expectedHelper),
            expected: expectedHelper,
            expectedURL: paths.helperExecutable,
            executableSHA256: projection.helperExecutableSHA256,
            staticSigning: artifacts.helperStaticSigning
        )
        let driverSigning: InvestigationInstalledL2SigningIdentity
        switch processReader.observeCurrentMachineDriverSigning() {
        case .observed(let value):
            driverSigning = value
        case .unavailable:
            throw InvestigationInstalledL2SemanticError.installedContractUnproved
        }
        let service = serviceReader.observe(expectedHelper: expectedHelper)
        guard service == .loaded(identity: expectedHelper) else {
            throw InvestigationInstalledL2SemanticError.installedContractUnproved
        }
        let observed = try sampleClock()

        do {
            let machineDriver = try InvestigationInstalledL2MachineDriverEvidence(
                executableSHA256: projection.machineDriverExecutableSHA256,
                staticSigning: artifacts.machineDriverStaticSigning,
                liveSigning: driverSigning
            )
            return try InvestigationInstalledL2SemanticContract.evaluate(
                projection: projection,
                artifacts: artifacts.artifacts,
                app: app,
                helper: helper,
                machineDriver: machineDriver,
                service: service,
                started: started,
                observed: observed
            )
        } catch let error as InvestigationInstalledL2SemanticError {
            throw error
        } catch {
            throw InvestigationInstalledL2SemanticError.installedContractUnproved
        }
    }

    private func readArtifacts(
        projection: InvestigationInstalledL2IdentityProjection
    ) throws -> InvestigationInstalledL2ArtifactFacts {
        do {
            return try artifactReader.observe(projection: projection)
        } catch let error as InvestigationInstalledL2SemanticError {
            throw error
        } catch {
            throw InvestigationInstalledL2SemanticError.installedContractUnproved
        }
    }

    private func readProcess(
        _ result: InvestigationInstalledL2ProcessReadResult,
        expected: InvestigationMachineProcessIdentity,
        expectedURL: URL,
        executableSHA256: InvestigationHandoffSHA256,
        staticSigning: InvestigationInstalledL2SigningIdentity
    ) throws -> InvestigationInstalledL2ProcessEvidence {
        guard case let .observed(observed) = result,
              observed.identity == expected,
              observed.executableURL.standardizedFileURL
                == expectedURL.standardizedFileURL
        else {
            throw InvestigationInstalledL2SemanticError.installedContractUnproved
        }
        do {
            return try InvestigationInstalledL2ProcessEvidence(
                identity: expected,
                executableSHA256: executableSHA256,
                staticSigning: staticSigning,
                liveSigning: observed.liveSigning
            )
        } catch {
            throw InvestigationInstalledL2SemanticError.installedContractUnproved
        }
    }

    private func sampleClock() throws -> InvestigationInstalledL2ClockSample {
        do {
            return try clock.sample()
        } catch {
            throw InvestigationInstalledL2SemanticError.installedContractUnproved
        }
    }
}

private func investigationInstalledL2ContinuousNanoseconds() throws -> UInt64 {
    var timebase = mach_timebase_info_data_t()
    guard
        mach_timebase_info(&timebase) == KERN_SUCCESS,
        timebase.numer > 0,
        timebase.denom > 0
    else {
        throw InvestigationInstalledL2SemanticError.installedContractUnproved
    }
    let ticks = mach_continuous_time()
    let whole = (ticks / UInt64(timebase.denom))
        .multipliedReportingOverflow(by: UInt64(timebase.numer))
    let fractional = (ticks % UInt64(timebase.denom))
        .multipliedReportingOverflow(by: UInt64(timebase.numer))
    guard !whole.overflow, !fractional.overflow else {
        throw InvestigationInstalledL2SemanticError.installedContractUnproved
    }
    let result = whole.partialValue.addingReportingOverflow(
        fractional.partialValue / UInt64(timebase.denom)
    )
    guard !result.overflow, result.partialValue > 0 else {
        throw InvestigationInstalledL2SemanticError.installedContractUnproved
    }
    return result.partialValue
}
