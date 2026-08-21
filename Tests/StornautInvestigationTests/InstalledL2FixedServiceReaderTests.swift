import Foundation
import Testing
@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationInstalledL2

@Suite("Installed L2 fixed service reader", .serialized)
struct InstalledL2FixedServiceReaderTests {
    @Test(arguments: [
        InvestigationInstalledL2ServiceRegistrationStatus.notRegistered,
        .notFound,
    ])
    func onlyConsistentStructuredMissingStateIsAbsent(
        _ status: InvestigationInstalledL2ServiceRegistrationStatus
    ) {
        let inspector = RecordingInstalledL2ServiceInspector(
            statuses: [status], jobs: [.missing]
        )
        let registry = InvestigationInstalledL2FixedServiceRegistry(
            inspector: inspector
        )

        #expect(registry.sample() == .absent)
        expectFixedServiceInputs(inspector)
    }

    @Test
    func enabledExactBoundedJobProducesRegisteredPID() {
        let inspector = RecordingInstalledL2ServiceInspector(
            statuses: [.enabled],
            jobs: [.present(
                label: "com.eriklee.stornaut.lifecycle",
                processID: 702,
                fieldCount: 4
            )]
        )

        #expect(
            InvestigationInstalledL2FixedServiceRegistry(
                inspector: inspector
            ).sample() == .registered(processID: 702)
        )
        expectFixedServiceInputs(inspector)
    }

    @Test
    func servicePIDRequiresAnExactNonBooleanIntegerNumber() {
        #expect(investigationInstalledL2ExactPID(NSNumber(value: 702)) == 702)
        #expect(investigationInstalledL2ExactPID(NSNumber(value: Int64.max)) == Int64.max)
        #expect(investigationInstalledL2ExactPID(NSNumber(value: 702.5)) == nil)
        #expect(investigationInstalledL2ExactPID(NSNumber(value: true)) == nil)
        #expect(investigationInstalledL2ExactPID("702") == nil)
    }

    @Test(arguments: InstalledL2RegistryDrift.allCases)
    fileprivate func everyContradictoryOrMalformedRegistryStateIsUnavailable(
        _ drift: InstalledL2RegistryDrift
    ) {
        let inspector = RecordingInstalledL2ServiceInspector(
            statuses: [drift.status], jobs: [drift.job]
        )
        #expect(
            InvestigationInstalledL2FixedServiceRegistry(
                inspector: inspector
            ).sample() == .unavailable
        )
    }

    @Test
    func loadedServiceRequiresTwoRegistryAndTwoCompleteIdentitySamples() throws {
        let helper = try installedL2ServiceIdentity(
            pid: 702, version: 12, asid: 33_001
        )
        let kernel = installedL2ServiceKernel(helper)
        let registry = RecordingInstalledL2ServiceRegistry(results: [
            .registered(processID: helper.processID),
            .registered(processID: helper.processID),
        ])
        let identities = RecordingServiceIdentityReader(results: [
            .success(kernel), .success(kernel),
        ])
        let reader = InvestigationInstalledL2FixedServiceReader(
            registry: registry, identityReader: identities
        )

        #expect(reader.observe(expectedHelper: helper) == .loaded(identity: helper))
        #expect(registry.sampleCount == 2)
        #expect(identities.processIDs == [helper.processID, helper.processID])
    }

    @Test
    func absentServiceRequiresTwoAbsentSamplesWithoutIdentityRead() throws {
        let helper = try installedL2ServiceIdentity(
            pid: 702, version: 12, asid: 33_001
        )
        let registry = RecordingInstalledL2ServiceRegistry(
            results: [.absent, .absent]
        )
        let identities = RecordingServiceIdentityReader(results: [])

        #expect(
            InvestigationInstalledL2FixedServiceReader(
                registry: registry, identityReader: identities
            ).observe(expectedHelper: helper) == .absent
        )
        #expect(registry.sampleCount == 2)
        #expect(identities.processIDs.isEmpty)
    }

    @Test(arguments: InstalledL2ServiceRace.allCases)
    fileprivate func registryIdentityAndRestartDriftRemainUnavailable(
        _ race: InstalledL2ServiceRace
    ) throws {
        let helper = try installedL2ServiceIdentity(
            pid: 702, version: 12, asid: 33_001
        )
        let kernel = installedL2ServiceKernel(helper)
        var reused = kernel
        reused.processIDVersion += 1
        reused.auditTokenWords[7] += 1
        let registry = RecordingInstalledL2ServiceRegistry(
            results: race.registryResults(helper: helper)
        )
        let identities = RecordingServiceIdentityReader(
            results: race.identityResults(valid: kernel, reused: reused)
        )

        #expect(
            InvestigationInstalledL2FixedServiceReader(
                registry: registry, identityReader: identities
            ).observe(expectedHelper: helper) == .unavailable
        )
    }

    @Test
    func wrongRoleIsRejectedBeforeRegistryOrIdentityRead() throws {
        let app = try InvestigationMachineProcessIdentity(
            role: .app,
            processID: 701,
            processIDVersion: 11,
            auditSessionID: 44_001,
            effectiveUserID: 501,
            auditTokenWords: installedL2ServiceToken(
                pid: 701, version: 11, asid: 44_001, euid: 501
            )
        )
        let registry = RecordingInstalledL2ServiceRegistry(results: [])
        let identities = RecordingServiceIdentityReader(results: [])
        #expect(
            InvestigationInstalledL2FixedServiceReader(
                registry: registry, identityReader: identities
            ).observe(expectedHelper: app) == .unavailable
        )
        #expect(registry.sampleCount == 0)
        #expect(identities.processIDs.isEmpty)
    }
}

private enum InstalledL2RegistryDrift: CaseIterable {
    case approval, unknown, missingEnabled, registeredNotEnabled
    case foreignLabel, zeroFields, tooManyFields, invalidPID, missingPID

    var status: InvestigationInstalledL2ServiceRegistrationStatus {
        switch self {
        case .approval: .requiresApproval
        case .unknown: .unknown
        case .missingEnabled, .foreignLabel, .zeroFields, .tooManyFields,
             .invalidPID, .missingPID: .enabled
        case .registeredNotEnabled: .notRegistered
        }
    }

    var job: InvestigationInstalledL2ServiceJobLookup {
        switch self {
        case .approval, .unknown, .missingEnabled: .missing
        case .registeredNotEnabled:
            .present(label: "com.eriklee.stornaut.lifecycle", processID: 702, fieldCount: 4)
        case .foreignLabel:
            .present(label: "foreign.service", processID: 702, fieldCount: 4)
        case .zeroFields:
            .present(label: "com.eriklee.stornaut.lifecycle", processID: 702, fieldCount: 0)
        case .tooManyFields:
            .present(label: "com.eriklee.stornaut.lifecycle", processID: 702, fieldCount: 129)
        case .invalidPID:
            .present(label: "com.eriklee.stornaut.lifecycle", processID: 1, fieldCount: 4)
        case .missingPID:
            .present(label: "com.eriklee.stornaut.lifecycle", processID: nil, fieldCount: 4)
        }
    }
}

private enum InstalledL2ServiceRace: CaseIterable {
    case firstUnavailable, firstForeignPID, firstIdentityFailure
    case firstIdentityReused, secondIdentityFailure, secondIdentityReused
    case serviceDisappeared, serviceRestarted, secondUnavailable

    func registryResults(
        helper: InvestigationMachineProcessIdentity
    ) -> [InvestigationInstalledL2FixedServiceSample] {
        switch self {
        case .firstUnavailable: [.unavailable]
        case .firstForeignPID: [.registered(processID: helper.processID + 1)]
        case .firstIdentityFailure, .firstIdentityReused,
             .secondIdentityFailure, .secondIdentityReused:
            [.registered(processID: helper.processID)]
        case .serviceDisappeared:
            [.registered(processID: helper.processID), .absent]
        case .serviceRestarted:
            [.registered(processID: helper.processID),
             .registered(processID: helper.processID + 1)]
        case .secondUnavailable:
            [.registered(processID: helper.processID), .unavailable]
        }
    }

    func identityResults(
        valid: InvestigationInstalledL2KernelIdentity,
        reused: InvestigationInstalledL2KernelIdentity
    ) -> [Result<InvestigationInstalledL2KernelIdentity, InvestigationInstalledL2ProcessSystemError>] {
        let error = InvestigationInstalledL2ProcessSystemError(errno: ESRCH)
        switch self {
        case .firstUnavailable, .firstForeignPID:
            return []
        case .firstIdentityFailure:
            return [.failure(error)]
        case .firstIdentityReused:
            return [.success(reused)]
        case .secondIdentityFailure:
            return [.success(valid), .failure(error)]
        case .secondIdentityReused:
            return [.success(valid), .success(reused)]
        case .serviceDisappeared, .serviceRestarted, .secondUnavailable:
            return [.success(valid), .success(valid)]
        }
    }
}

private final class RecordingInstalledL2ServiceInspector:
    InvestigationInstalledL2FixedServiceInspecting,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var statuses: [InvestigationInstalledL2ServiceRegistrationStatus]
    private var jobs: [InvestigationInstalledL2ServiceJobLookup]
    private(set) var plistURLs: [URL] = []
    private(set) var labels: [String] = []

    init(
        statuses: [InvestigationInstalledL2ServiceRegistrationStatus],
        jobs: [InvestigationInstalledL2ServiceJobLookup]
    ) {
        self.statuses = statuses
        self.jobs = jobs
    }

    func registrationStatus(plistURL: URL)
        -> InvestigationInstalledL2ServiceRegistrationStatus
    {
        lock.withLock { plistURLs.append(plistURL); return statuses.removeFirst() }
    }

    func job(label: String) -> InvestigationInstalledL2ServiceJobLookup {
        lock.withLock { labels.append(label); return jobs.removeFirst() }
    }
}

private final class RecordingInstalledL2ServiceRegistry:
    InvestigationInstalledL2FixedServiceRegistryReading,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var results: [InvestigationInstalledL2FixedServiceSample]
    private(set) var sampleCount = 0

    init(results: [InvestigationInstalledL2FixedServiceSample]) {
        self.results = results
    }

    func sample() -> InvestigationInstalledL2FixedServiceSample {
        lock.withLock { sampleCount += 1; return results.removeFirst() }
    }
}

private final class RecordingServiceIdentityReader:
    InvestigationInstalledL2ProcessIdentityReading,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var results: [Result<InvestigationInstalledL2KernelIdentity, InvestigationInstalledL2ProcessSystemError>]
    private(set) var processIDs: [UInt32] = []

    init(results: [Result<InvestigationInstalledL2KernelIdentity, InvestigationInstalledL2ProcessSystemError>]) {
        self.results = results
    }

    func read(processID: UInt32) -> Result<InvestigationInstalledL2KernelIdentity, InvestigationInstalledL2ProcessSystemError> {
        lock.withLock { processIDs.append(processID); return results.removeFirst() }
    }
}

private func expectFixedServiceInputs(
    _ inspector: RecordingInstalledL2ServiceInspector
) {
    #expect(inspector.plistURLs.map(\.path) == [
        "/Library/LaunchDaemons/com.eriklee.stornaut.lifecycle.plist",
    ])
    #expect(inspector.labels == ["com.eriklee.stornaut.lifecycle"])
}

private func installedL2ServiceIdentity(
    pid: UInt32,
    version: UInt32,
    asid: UInt32
) throws -> InvestigationMachineProcessIdentity {
    try .init(
        role: .helper,
        processID: pid,
        processIDVersion: version,
        auditSessionID: asid,
        effectiveUserID: 0,
        auditTokenWords: installedL2ServiceToken(
            pid: pid, version: version, asid: asid, euid: 0
        )
    )
}

private func installedL2ServiceKernel(
    _ identity: InvestigationMachineProcessIdentity
) -> InvestigationInstalledL2KernelIdentity {
    .init(
        processID: identity.processID,
        processIDVersion: identity.processIDVersion,
        auditSessionID: identity.auditSessionID,
        effectiveUserID: identity.effectiveUserID,
        auditTokenWords: identity.auditTokenWords
    )
}

private func installedL2ServiceToken(
    pid: UInt32,
    version: UInt32,
    asid: UInt32,
    euid: UInt32
) -> [UInt32] {
    var words = Array(repeating: UInt32(0), count: 8)
    words[0] = 0xB2
    words[1] = euid
    words[5] = pid
    words[6] = asid
    words[7] = version
    return words
}
