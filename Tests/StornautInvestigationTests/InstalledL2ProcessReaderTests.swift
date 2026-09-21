import Darwin
import Foundation
import Testing
@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationInstalledL2

@Suite("Installed L2 process reader", .serialized)
struct InstalledL2ProcessReaderTests {
    @Test(arguments: InstalledL2ProcessRoleCase.allCases)
    fileprivate func exactTypedProcessUsesTwoIdentityAndPathSamples(
        _ roleCase: InstalledL2ProcessRoleCase
    ) throws {
        let fixture = try InstalledL2ProcessFixture()
        let expected = roleCase.identity(in: fixture)
        let kernel = fixture.kernel(expected)
        let identities = RecordingInstalledL2IdentityReader(
            results: [.success(kernel), .success(kernel)]
        )
        let paths = RecordingInstalledL2PathReader(
            results: [
                .success(roleCase.path(in: fixture.paths)),
                .success(roleCase.path(in: fixture.paths)),
            ]
        )
        let signing = RecordingInstalledL2LiveSigningReader(
            results: [.observed(fixture.liveSigning(expected, adHoc: roleCase == .helper))]
        )
        let reader = fixture.reader(
            identities: identities, paths: paths, signing: signing
        )

        let result = roleCase.observe(reader, expected: expected)
        guard case let .observed(observed) = result else {
            Issue.record("expected a complete observed process")
            return
        }
        #expect(observed.identity == expected)
        #expect(observed.executableURL == roleCase.path(in: fixture.paths))
        #expect(observed.liveSigning.isAdHoc == (roleCase == .helper))
        #expect(identities.processIDs == [expected.processID, expected.processID])
        #expect(paths.processIDs == [expected.processID, expected.processID])
        #expect(signing.auditTokens == [expected.auditTokenWords])
    }

    @Test
    func wrongRoleIsRejectedBeforeAnyPhysicalRead() throws {
        let fixture = try InstalledL2ProcessFixture()
        let identities = RecordingInstalledL2IdentityReader(results: [])
        let paths = RecordingInstalledL2PathReader(results: [])
        let signing = RecordingInstalledL2LiveSigningReader(results: [])
        let reader = fixture.reader(
            identities: identities, paths: paths, signing: signing
        )

        #expect(reader.observeApp(expected: fixture.helper) == .unavailable)
        #expect(reader.observeHelper(expected: fixture.app) == .unavailable)
        #expect(identities.processIDs.isEmpty)
        #expect(paths.processIDs.isEmpty)
        #expect(signing.auditTokens.isEmpty)
    }

    @Test(arguments: InstalledL2ProcessFailureStage.allCases)
    fileprivate func onlyInitialESRCHCanBecomeAbsent(
        _ stage: InstalledL2ProcessFailureStage
    ) throws {
        let fixture = try InstalledL2ProcessFixture()
        let expected = fixture.app
        let kernel = fixture.kernel(expected)
        let error = InvestigationInstalledL2ProcessSystemError(errno: ESRCH)
        let identities: RecordingInstalledL2IdentityReader
        let paths: RecordingInstalledL2PathReader
        let signing: RecordingInstalledL2LiveSigningReader
        switch stage {
        case .initialIdentity:
            identities = .init(results: [.failure(error)])
            paths = .init(results: [])
            signing = .init(results: [])
        case .firstPath:
            identities = .init(results: [.success(kernel)])
            paths = .init(results: [.failure(error)])
            signing = .init(results: [])
        case .signing:
            identities = .init(results: [.success(kernel)])
            paths = .init(results: [.success(fixture.paths.appExecutable)])
            signing = .init(results: [.unavailable])
        case .secondPath:
            identities = .init(results: [.success(kernel)])
            paths = .init(results: [
                .success(fixture.paths.appExecutable), .failure(error),
            ])
            signing = .init(results: [.observed(fixture.liveSigning(expected))])
        case .finalIdentity:
            identities = .init(results: [.success(kernel), .failure(error)])
            paths = .init(results: [
                .success(fixture.paths.appExecutable),
                .success(fixture.paths.appExecutable),
            ])
            signing = .init(results: [.observed(fixture.liveSigning(expected))])
        }
        let result = fixture.reader(
            identities: identities, paths: paths, signing: signing
        ).observeApp(expected: expected)

        #expect(result == (stage == .initialIdentity ? .absent : .unavailable))
    }

    @Test(arguments: InstalledL2ProcessDrift.allCases)
    fileprivate func completeIdentityAndPathDriftFailClosed(
        _ drift: InstalledL2ProcessDrift
    ) throws {
        let fixture = try InstalledL2ProcessFixture()
        let expected = fixture.app
        let kernel = fixture.kernel(expected)
        var reused = kernel
        reused.processIDVersion += 1
        reused.auditTokenWords[7] += 1
        let identities = RecordingInstalledL2IdentityReader(results:
            drift == .initialIdentity
                ? [.success(reused)]
                : [.success(kernel), .success(drift == .finalIdentity ? reused : kernel)]
        )
        let paths = RecordingInstalledL2PathReader(results: [
            .success(fixture.paths.appExecutable),
            .success(drift == .path
                ? fixture.paths.helperExecutable
                : fixture.paths.appExecutable),
        ])
        let signing = RecordingInstalledL2LiveSigningReader(results: [
            .observed(fixture.liveSigning(expected)),
        ])

        let result = fixture.reader(
            identities: identities, paths: paths, signing: signing
        ).observeApp(expected: expected)
        #expect(result == (drift == .path ? .unavailable : .identityReused))
    }

    @Test(arguments: InstalledL2SigningDrift.allCases)
    fileprivate func liveSigningMustBindTheCompleteExpectedProcess(
        _ drift: InstalledL2SigningDrift
    ) throws {
        let fixture = try InstalledL2ProcessFixture()
        let expected = fixture.helper
        let kernel = fixture.kernel(expected)
        let observation: InvestigationInstalledL2LiveSigningResult
        switch drift {
        case .processID:
            observation = .observed(fixture.liveSigning(
                expected, processID: expected.processID + 1
            ))
        case .effectiveUserID:
            observation = .observed(fixture.liveSigning(
                expected, effectiveUserID: expected.effectiveUserID + 1
            ))
        case .invalid:
            observation = .invalid
        case .unavailable:
            observation = .unavailable
        }
        let reader = fixture.reader(
            identities: .init(results: [.success(kernel), .success(kernel)]),
            paths: .init(results: [
                .success(fixture.paths.helperExecutable),
                .success(fixture.paths.helperExecutable),
            ]),
            signing: .init(results: [observation])
        )
        #expect(reader.observeHelper(expected: expected) == .unavailable)
    }

    @Test
    func malformedKernelIdentityCannotReachPathOrSigning() throws {
        let fixture = try InstalledL2ProcessFixture()
        var malformed = fixture.kernel(fixture.app)
        malformed.auditTokenWords[5] += 1
        let paths = RecordingInstalledL2PathReader(results: [])
        let signing = RecordingInstalledL2LiveSigningReader(results: [])
        let reader = fixture.reader(
            identities: .init(results: [.success(malformed)]),
            paths: paths,
            signing: signing
        )

        #expect(reader.observeApp(expected: fixture.app) == .unavailable)
        #expect(paths.processIDs.isEmpty)
        #expect(signing.auditTokens.isEmpty)
    }

    @Test
    func currentMachineDriverSigningIsRootOnlyAndCallerCannotChoosePID() throws {
        let fixture = try InstalledL2ProcessFixture()
        let root = fixture.kernel(
            role: .helper, processID: 991, version: 31, asid: 51_001, euid: 0
        )
        let identities = RecordingInstalledL2IdentityReader(results: [.success(root)])
        let signing = RecordingInstalledL2LiveSigningReader(results: [
            .observed(.init(
                processID: root.processID,
                effectiveUserID: 0,
                identity: fixture.signing(identifier:
                    "com.eriklee.stornaut.investigation.machine-driver", adHoc: true)
            )),
        ])
        let reader = InvestigationInstalledL2ProcessReader(
            identityReader: identities,
            pathReader: RecordingInstalledL2PathReader(results: []),
            signingReader: signing,
            currentProcessID: { 991 }
        )
        guard case let .observed(identity) =
            reader.observeCurrentMachineDriverSigning()
        else {
            Issue.record("expected current root driver signing evidence")
            return
        }
        #expect(identity.isAdHoc)
        #expect(identities.processIDs == [991])
        #expect(signing.auditTokens == [root.auditTokenWords])

        let nonroot = fixture.kernel(fixture.app)
        let rejected = InvestigationInstalledL2ProcessReader(
            identityReader: RecordingInstalledL2IdentityReader(
                results: [.success(nonroot)]
            ),
            pathReader: RecordingInstalledL2PathReader(results: []),
            signingReader: RecordingInstalledL2LiveSigningReader(results: []),
            currentProcessID: { nonroot.processID }
        )
        #expect(rejected.observeCurrentMachineDriverSigning() == .unavailable)
    }

    @Test
    func concreteReadersObserveTheCurrentSignedTestProcess() throws {
        let processID = UInt32(getpid())
        let identityReader = InvestigationInstalledL2DarwinProcessIdentityReader()
        let kernel = try #require(try? identityReader.read(processID: processID).get())
        #expect(kernel.processID == processID)
        #expect(kernel.auditTokenWords.count == 8)
        let path = try #require(
            try? InvestigationInstalledL2DarwinProcessPathReader()
                .read(processID: processID).get()
        )
        #expect(path.isFileURL)
        #expect(path.path.hasPrefix("/"))
        switch InvestigationInstalledL2SecurityLiveSigningReader().read(
            auditTokenWords: kernel.auditTokenWords
        ) {
        case .observed(let observation):
            #expect(observation.processID == processID)
            #expect(observation.effectiveUserID == UInt32(geteuid()))
            #expect(!observation.identity.signingIdentifier.isEmpty)
        case .invalid, .unavailable:
            Issue.record("expected current test process live signing evidence")
        }
    }
}

private enum InstalledL2ProcessRoleCase: CaseIterable {
    case app, helper

    func identity(in fixture: InstalledL2ProcessFixture)
        -> InvestigationMachineProcessIdentity
    {
        self == .app ? fixture.app : fixture.helper
    }

    func path(in paths: InvestigationInstalledL2FixedPaths) -> URL {
        self == .app ? paths.appExecutable : paths.helperExecutable
    }

    func observe(
        _ reader: InvestigationInstalledL2ProcessReader,
        expected: InvestigationMachineProcessIdentity
    ) -> InvestigationInstalledL2ProcessReadResult {
        self == .app
            ? reader.observeApp(expected: expected)
            : reader.observeHelper(expected: expected)
    }
}

private enum InstalledL2ProcessFailureStage: CaseIterable {
    case initialIdentity, firstPath, signing, secondPath, finalIdentity
}

private enum InstalledL2ProcessDrift: CaseIterable {
    case initialIdentity, path, finalIdentity
}

private enum InstalledL2SigningDrift: CaseIterable {
    case processID, effectiveUserID, invalid, unavailable
}

private struct InstalledL2ProcessFixture {
    let paths = InvestigationInstalledL2FixedPaths()
    let app: InvestigationMachineProcessIdentity
    let helper: InvestigationMachineProcessIdentity

    init() throws {
        app = try Self.identity(
            role: .app, processID: 701, version: 11, asid: 44_001, euid: 501
        )
        helper = try Self.identity(
            role: .helper, processID: 702, version: 12, asid: 33_001, euid: 0
        )
    }

    func reader(
        identities: RecordingInstalledL2IdentityReader,
        paths: RecordingInstalledL2PathReader,
        signing: RecordingInstalledL2LiveSigningReader
    ) -> InvestigationInstalledL2ProcessReader {
        .init(
            identityReader: identities,
            pathReader: paths,
            signingReader: signing,
            currentProcessID: { 991 }
        )
    }

    func kernel(
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

    func kernel(
        role: InvestigationMachineProcessRole,
        processID: UInt32,
        version: UInt32,
        asid: UInt32,
        euid: UInt32
    ) -> InvestigationInstalledL2KernelIdentity {
        kernel(try! Self.identity(
            role: role,
            processID: processID,
            version: version,
            asid: asid,
            euid: euid
        ))
    }

    func liveSigning(
        _ identity: InvestigationMachineProcessIdentity,
        processID: UInt32? = nil,
        effectiveUserID: UInt32? = nil,
        adHoc: Bool = false
    ) -> InvestigationInstalledL2LiveSigningObservation {
        .init(
            processID: processID ?? identity.processID,
            effectiveUserID: effectiveUserID ?? identity.effectiveUserID,
            identity: signing(identifier: identity.role == .app
                ? "com.eriklee.stornaut"
                : "com.eriklee.stornaut.lifecycle.helper", adHoc: adHoc)
        )
    }

    func signing(
        identifier: String,
        adHoc: Bool
    ) -> InvestigationInstalledL2SigningIdentity {
        try! .init(
            signingIdentifier: identifier,
            designatedRequirementSHA256: .init(
                rawBytes: Data(repeating: 0x41, count: 32)
            ),
            codeDirectoryHash: Data(repeating: 0x42, count: 20),
            isAdHoc: adHoc
        )
    }

    private static func identity(
        role: InvestigationMachineProcessRole,
        processID: UInt32,
        version: UInt32,
        asid: UInt32,
        euid: UInt32
    ) throws -> InvestigationMachineProcessIdentity {
        var words = Array(repeating: UInt32(0), count: 8)
        words[0] = 0xA1
        words[1] = euid
        words[5] = processID
        words[6] = asid
        words[7] = version
        return try .init(
            role: role,
            processID: processID,
            processIDVersion: version,
            auditSessionID: asid,
            effectiveUserID: euid,
            auditTokenWords: words
        )
    }
}

private final class RecordingInstalledL2IdentityReader:
    InvestigationInstalledL2ProcessIdentityReading,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var results: [Result<
        InvestigationInstalledL2KernelIdentity,
        InvestigationInstalledL2ProcessSystemError
    >]
    private(set) var processIDs: [UInt32] = []

    init(results: [Result<
        InvestigationInstalledL2KernelIdentity,
        InvestigationInstalledL2ProcessSystemError
    >]) {
        self.results = results
    }

    func read(processID: UInt32) -> Result<
        InvestigationInstalledL2KernelIdentity,
        InvestigationInstalledL2ProcessSystemError
    > {
        lock.withLock {
            processIDs.append(processID)
            return results.removeFirst()
        }
    }
}

private final class RecordingInstalledL2PathReader:
    InvestigationInstalledL2ProcessPathReading,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var results: [Result<URL, InvestigationInstalledL2ProcessSystemError>]
    private(set) var processIDs: [UInt32] = []

    init(results: [Result<URL, InvestigationInstalledL2ProcessSystemError>]) {
        self.results = results
    }

    func read(processID: UInt32)
        -> Result<URL, InvestigationInstalledL2ProcessSystemError>
    {
        lock.withLock {
            processIDs.append(processID)
            return results.removeFirst()
        }
    }
}

private final class RecordingInstalledL2LiveSigningReader:
    InvestigationInstalledL2LiveSigningReading,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var results: [InvestigationInstalledL2LiveSigningResult]
    private(set) var auditTokens: [[UInt32]] = []

    init(results: [InvestigationInstalledL2LiveSigningResult]) {
        self.results = results
    }

    func read(auditTokenWords: [UInt32])
        -> InvestigationInstalledL2LiveSigningResult
    {
        lock.withLock {
            auditTokens.append(auditTokenWords)
            return results.removeFirst()
        }
    }
}
