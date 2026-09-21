import Darwin
import Foundation
import Testing
@testable import StornautInvestigationMachineDriverSupport

@Suite("Investigation machine driver support")
struct InvestigationMachineDriverSupportTests {
    @Test(
        arguments: [
            InstalledDriverAuthorityIdentity(
                realUserID: 501,
                effectiveUserID: 0,
                realGroupID: 0,
                effectiveGroupID: 0
            ),
            InstalledDriverAuthorityIdentity(
                realUserID: 0,
                effectiveUserID: 501,
                realGroupID: 0,
                effectiveGroupID: 0
            ),
            InstalledDriverAuthorityIdentity(
                realUserID: 0,
                effectiveUserID: 0,
                realGroupID: 20,
                effectiveGroupID: 0
            ),
            InstalledDriverAuthorityIdentity(
                realUserID: 0,
                effectiveUserID: 0,
                realGroupID: 0,
                effectiveGroupID: 20
            ),
        ]
    )
    func installedObservationRejectsEachNonRootIdentityAxisBeforeReading(
        _ identity: InstalledDriverAuthorityIdentity
    ) {
        let source = RecordingInstalledDriverObservationSource(
            candidate: .validFixture()
        )
        let observer = InvestigationMachineInstalledDriverObserver(
            realUserID: { identity.realUserID },
            effectiveUserID: { identity.effectiveUserID },
            realGroupID: { identity.realGroupID },
            effectiveGroupID: { identity.effectiveGroupID },
            argumentCount: { 1 },
            source: source
        )

        #expect(throws: InvestigationMachineInstalledDriverObservationError
            .rootAuthorityRequired) {
            _ = try observer.observe()
        }
        #expect(source.readCount == 0)
    }

    @Test
    func installedObservationRejectsArgumentsBeforeReadingTheArtifact() {
        let source = RecordingInstalledDriverObservationSource(
            candidate: .validFixture()
        )
        let observer = InvestigationMachineInstalledDriverObserver(
            realUserID: { 0 },
            effectiveUserID: { 0 },
            realGroupID: { 0 },
            effectiveGroupID: { 0 },
            argumentCount: { 2 },
            source: source
        )

        #expect(throws: InvestigationMachineInstalledDriverObservationError
            .invalidInvocation) {
            _ = try observer.observe()
        }
        #expect(source.readCount == 0)
    }

    @Test
    func installedObservationReturnsOnlyTheExactStableIdentity() throws {
        let candidate = InvestigationMachineInstalledDriverCandidate
            .validFixture()
        let source = RecordingInstalledDriverObservationSource(
            candidate: candidate
        )
        let observer = rootObserver(source: source)

        let observation = try observer.observe()

        #expect(source.readCount == 1)
        #expect(
            observation.executablePath
                == InvestigationMachineInstalledDriverObservation
                    .fixedExecutablePath
        )
        #expect(observation.node == candidate.initialNode)
        #expect(observation.executableSHA256 == candidate.executableSHA256)
        #expect(observation.signing == candidate.staticSigning)
        #expect(observation.manifest == candidate.manifest)
        #expect(observation.isAdHoc)
        #expect(!(InvestigationMachineInstalledDriverObservation.self
            is any Codable.Type))
        #expect(!(InvestigationMachineInstalledManifestIdentity.self
            is any Codable.Type))
    }

    @Test(
        arguments: InstalledDriverObservationMutation.allCases
    )
    func installedObservationRejectsEveryIdentityDrift(
        _ mutation: InstalledDriverObservationMutation
    ) {
        let source = RecordingInstalledDriverObservationSource(
            candidate: mutation.apply(to: .validFixture())
        )
        let observer = rootObserver(source: source)

        #expect(throws: InvestigationMachineInstalledDriverObservationError
            .invalidObservation) {
            _ = try observer.observe()
        }
        #expect(source.readCount == 1)
    }

    @Test
    func installedObservationPreservesSourceFailure() {
        let source = RecordingInstalledDriverObservationSource(
            error: .sourceUnavailable
        )
        let observer = rootObserver(source: source)

        #expect(throws: InvestigationMachineInstalledDriverObservationError
            .sourceUnavailable) {
            _ = try observer.observe()
        }
        #expect(source.readCount == 1)
    }

    @Test
    func systemSourceReadsOneHeldDescriptorInStrictOrder() throws {
        let system = RecordingInstalledDriverSystem()
        let source = InvestigationMachineInstalledDriverSystemSource(
            system: system
        )

        let candidate = try source.readCandidate()

        #expect(candidate == .validFixture())
        #expect(system.events == InstalledDriverSystemPoint.successOrder)
        #expect(system.closeCount == 1)
    }

    @Test(
        arguments: [
            Int64(0),
            InvestigationMachineInstalledDriverObserver.maximumExecutableBytes
                + 1,
        ]
    )
    func systemSourceRejectsInvalidSizeBeforeReadingDescriptorContents(
        _ size: Int64
    ) {
        let system = RecordingInstalledDriverSystem(descriptorSize: size)
        let source = InvestigationMachineInstalledDriverSystemSource(
            system: system
        )

        #expect(throws: InvestigationMachineInstalledDriverObservationError
            .sourceUnavailable) {
            _ = try source.readCandidate()
        }
        #expect(system.events == [
            .initialManifest,
            .processExecutablePath,
            .trustedAncestorChain,
            .initialPathNode,
            .open,
            .initialDescriptorNode,
            .close,
        ])
        #expect(system.closeCount == 1)
    }

    @Test
    func darwinSourceAcceptsOnlyProtectionOnlyAncestorFlags() {
        #expect(
            DarwinInvestigationMachineInstalledDriverSystem
                .hasOnlyAllowedAncestorFlags(0)
        )
        #expect(
            DarwinInvestigationMachineInstalledDriverSystem
                .hasOnlyAllowedAncestorFlags(UInt32(SF_NOUNLINK))
        )
        #expect(
            !DarwinInvestigationMachineInstalledDriverSystem
                .hasOnlyAllowedAncestorFlags(UInt32(UF_HIDDEN))
        )
        #expect(
            !DarwinInvestigationMachineInstalledDriverSystem
                .hasOnlyAllowedAncestorFlags(
                    UInt32(SF_NOUNLINK | UF_HIDDEN)
                )
        )
    }

    @Test
    func darwinSourceAllowsOnlyTheSystemProvenanceAttribute() throws {
        let provenance = Array("com.apple.provenance".utf8) + [0]
        #expect(try !DarwinInvestigationMachineInstalledDriverSystem
            .hasUnexpectedExtendedAttributes(provenance))
        #expect(try DarwinInvestigationMachineInstalledDriverSystem
            .hasUnexpectedExtendedAttributes(
                provenance + Array("com.example.mutable".utf8) + [0]
            ))
        #expect(throws: (any Error).self) {
            _ = try DarwinInvestigationMachineInstalledDriverSystem
                .hasUnexpectedExtendedAttributes(
                    Array("com.apple.provenance".utf8)
                )
        }
        #expect(throws: (any Error).self) {
            _ = try DarwinInvestigationMachineInstalledDriverSystem
                .hasUnexpectedExtendedAttributes([0])
        }
        #expect(throws: (any Error).self) {
            _ = try DarwinInvestigationMachineInstalledDriverSystem
                .hasUnexpectedExtendedAttributes([0xff, 0])
        }
    }

    @Test
    func darwinSourceRecognizesARealExtendedACL() throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-installed-driver-acl-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        let file = root.appending(path: "artifact")
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        defer {
            let removeACL = Process()
            removeACL.executableURL = URL(filePath: "/bin/chmod")
            removeACL.arguments = ["-N", file.path]
            do {
                try removeACL.run()
                removeACL.waitUntilExit()
            } catch {}
            try? FileManager.default.removeItem(at: root)
        }
        try Data([0x01]).write(to: file)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: file.path
        )
        let system = DarwinInvestigationMachineInstalledDriverSystem()
        let initialDescriptor = Darwin.open(
            file.path,
            O_RDONLY | O_CLOEXEC
        )
        try #require(initialDescriptor >= 0)
        #expect(try !system.hasExtendedACL(initialDescriptor))
        Darwin.close(initialDescriptor)

        let addACL = Process()
        addACL.executableURL = URL(filePath: "/bin/chmod")
        addACL.arguments = ["+a", "everyone allow read", file.path]
        try addACL.run()
        addACL.waitUntilExit()
        try #require(addACL.terminationStatus == 0)

        let descriptor = Darwin.open(file.path, O_RDONLY | O_CLOEXEC)
        try #require(descriptor >= 0)
        defer { Darwin.close(descriptor) }

        #expect(try system.hasExtendedACL(descriptor))
    }

    @Test
    func darwinSourceStrictlyParsesTheFrozenLaunchDaemonManifest() throws {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repositoryRoot.appending(
            path: "StornautLifecycleHelper/"
                + "com.eriklee.stornaut.lifecycle.plist"
        )
        let data = try Data(contentsOf: sourceURL)
        let parsed = try DarwinInvestigationMachineInstalledDriverSystem
            .parseManifest(data)

        #expect(parsed.label == "com.eriklee.stornaut.lifecycle")
        #expect(parsed.program
            == InvestigationMachineInstalledDriverObservation
                .fixedLifecycleProgram)
        #expect(parsed.primaryServiceIdentifier == parsed.label)
        #expect(parsed.machineClaimServiceIdentifier
            == "com.eriklee.stornaut.lifecycle.machine-claim")

        var format = PropertyListSerialization.PropertyListFormat.xml
        let object = try #require(
            try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: &format
            ) as? [String: Any]
        )
        for mutation in ManifestMutation.allCases {
            let mutated = mutation.apply(to: object)
            let encoded = try PropertyListSerialization.data(
                fromPropertyList: mutated,
                format: .xml,
                options: 0
            )
            #expect(throws: (any Error).self) {
                _ = try DarwinInvestigationMachineInstalledDriverSystem
                    .parseManifest(encoded)
            }
        }
    }

    @Test
    func systemSourceDoesNotCloseBeforeAnExecutableWasOpened() {
        let system = RecordingInstalledDriverSystem(
            failingAt: .initialPathNode
        )
        let source = InvestigationMachineInstalledDriverSystemSource(
            system: system
        )

        #expect(throws: InvestigationMachineInstalledDriverObservationError
            .sourceUnavailable) {
            _ = try source.readCandidate()
        }
        #expect(system.events == [
            .initialManifest,
            .processExecutablePath,
            .trustedAncestorChain,
            .initialPathNode,
        ])
        #expect(system.closeCount == 0)
    }

    @Test
    func systemSourceRejectsManifestFailureBeforeReadingExecutable() {
        let system = RecordingInstalledDriverSystem(
            failingAt: .initialManifest
        )
        let source = InvestigationMachineInstalledDriverSystemSource(
            system: system
        )

        #expect(throws: InvestigationMachineInstalledDriverObservationError
            .sourceUnavailable) {
            _ = try source.readCandidate()
        }
        #expect(system.events == [.initialManifest])
        #expect(system.closeCount == 0)
    }

    @Test(
        arguments: InstalledDriverSystemPoint.postOpenFailurePoints
    )
    func systemSourceClosesExactlyOnceAfterEveryPostOpenFailure(
        _ point: InstalledDriverSystemPoint
    ) {
        let system = RecordingInstalledDriverSystem(failingAt: point)
        let source = InvestigationMachineInstalledDriverSystemSource(
            system: system
        )

        #expect(throws: InvestigationMachineInstalledDriverObservationError
            .sourceUnavailable) {
            _ = try source.readCandidate()
        }
        #expect(system.events.last == .close)
        #expect(system.events.filter { $0 == .close }.count == 1)
        #expect(system.closeCount == 1)
    }

    @Test
    func systemSourceRejectsCloseFailureAfterCompleteObservation() {
        let system = RecordingInstalledDriverSystem(closeSucceeds: false)
        let source = InvestigationMachineInstalledDriverSystemSource(
            system: system
        )

        #expect(throws: InvestigationMachineInstalledDriverObservationError
            .sourceUnavailable) {
            _ = try source.readCandidate()
        }
        #expect(system.events == InstalledDriverSystemPoint.successOrder)
        #expect(system.closeCount == 1)
    }

    @Test
    func exitStatusesMatchTheFrozenDriverContract() {
        #expect(
            InvestigationMachineDriverSupport.completedExitStatus == 0
        )
        #expect(
            InvestigationMachineDriverSupport
                .rootAuthorityRequiredExitStatus == 77
        )
        #expect(
            InvestigationMachineDriverSupport
                .handoffUnavailableExitStatus == 78
        )
        #expect(
            InvestigationMachineDriverSupport
                .installedObservationUnavailableExitStatus == 79
        )
        #expect(
            InvestigationMachineDriverSupport.invalidInvocationExitStatus
                == 80
        )
        #expect(
            InvestigationMachineDriverSupport.protocolFailureExitStatus
                == 81
        )
        #expect(
            InvestigationMachineDriverSupport
                .containmentUncertainExitStatus == 82
        )
        #expect(
            InvestigationMachineDriverSupport.cancelledExitStatus == 83
        )
    }

    @Test(arguments: DriverSupportInvalidInvocation.allCases)
    fileprivate func runtimeRejectsEveryInvalidAuthorityOrArgumentBeforeObservation(
        _ invocation: DriverSupportInvalidInvocation
    ) async {
        let source = RecordingInstalledDriverObservationSource(
            candidate: .validFixture()
        )

        let status = await InvestigationMachineDriverSupport.run(
            realUserID: { invocation.realUserID },
            effectiveUserID: { invocation.effectiveUserID },
            realGroupID: { invocation.realGroupID },
            effectiveGroupID: { invocation.effectiveGroupID },
            argumentCount: { invocation.argumentCount },
            source: source
        )

        #expect(status == invocation.expectedStatus)
        #expect(source.readCount == 0)
    }

    @Test(arguments: DriverSupportStatusScenario.allCases)
    fileprivate func runtimeMapsEveryEntryFailureWithoutInvokingTheDriver(
        _ scenario: DriverSupportStatusScenario
    ) async {
        let trace = DriverSupportEntryTrace()
        let entry = driverSupportEntry(
            trace: trace,
            validationError: scenario.error
        )
        let status = await InvestigationMachineDriverSupport.run(entry: entry)

        #expect(status == scenario.expectedStatus)
        #expect(trace.snapshot() == ["validate"])
    }

    @Test
    func unclassifiedErrorsPreserveContainmentUncertainty() {
        #expect(
            InvestigationMachineDriverSupport.status(
                for: CancellationError()
            ) == InvestigationMachineDriverSupport
                .containmentUncertainExitStatus
        )
        #expect(
            InvestigationMachineDriverSupport.status(
                for: DriverSupportUnknownError.failure
            ) == InvestigationMachineDriverSupport
                .containmentUncertainExitStatus
        )
    }

    @Test
    func runtimeReturnsSuccessOnlyAfterTheInjectedEntryCompletes() async {
        let trace = DriverSupportEntryTrace()
        let entry = driverSupportEntry(trace: trace)

        let status = await InvestigationMachineDriverSupport.run(entry: entry)

        #expect(
            status == InvestigationMachineDriverSupport.completedExitStatus
        )
        #expect(trace.snapshot() == ["validate", "role", "inner"])
    }

    private func rootObserver(
        source: RecordingInstalledDriverObservationSource
    ) -> InvestigationMachineInstalledDriverObserver {
        InvestigationMachineInstalledDriverObserver(
            realUserID: { 0 },
            effectiveUserID: { 0 },
            realGroupID: { 0 },
            effectiveGroupID: { 0 },
            argumentCount: { 1 },
            source: source
        )
    }
}

private enum DriverSupportInvalidInvocation: CaseIterable, Sendable {
    case nonRootRealUser
    case nonRootEffectiveUser
    case nonRootRealGroup
    case nonRootEffectiveGroup
    case missingArgumentVector
    case extraArgument

    var realUserID: uid_t { self == .nonRootRealUser ? 501 : 0 }
    var effectiveUserID: uid_t {
        self == .nonRootEffectiveUser ? 501 : 0
    }
    var realGroupID: gid_t { self == .nonRootRealGroup ? 20 : 0 }
    var effectiveGroupID: gid_t {
        self == .nonRootEffectiveGroup ? 20 : 0
    }
    var argumentCount: Int32 {
        switch self {
        case .missingArgumentVector: 0
        case .extraArgument: 2
        default: 1
        }
    }
    var expectedStatus: Int32 {
        switch self {
        case .nonRootRealUser, .nonRootEffectiveUser, .nonRootRealGroup,
             .nonRootEffectiveGroup:
            InvestigationMachineDriverSupport.rootAuthorityRequiredExitStatus
        case .missingArgumentVector, .extraArgument:
            InvestigationMachineDriverSupport.invalidInvocationExitStatus
        }
    }
}

private enum DriverSupportStatusScenario: CaseIterable, Sendable {
    case rootAuthorityRequired
    case installedObservationUnavailable
    case invalidInvocation
    case invalidInput
    case invalidRole
    case invalidOuterDescriptor
    case protocolFailure
    case outputUnavailable
    case invalidCompletion
    case containmentUncertain
    case cancelled

    var error: InvestigationMachineZeroArgumentEntryError {
        switch self {
        case .rootAuthorityRequired:
            InvestigationMachineZeroArgumentEntryError.rootAuthorityRequired
        case .installedObservationUnavailable:
            InvestigationMachineZeroArgumentEntryError
                .installedObservationUnavailable
        case .invalidInvocation:
            InvestigationMachineZeroArgumentEntryError.invalidInvocation
        case .invalidInput:
            InvestigationMachineZeroArgumentEntryError.invalidInput
        case .invalidRole:
            InvestigationMachineZeroArgumentEntryError.invalidRole
        case .invalidOuterDescriptor:
            InvestigationMachineZeroArgumentEntryError.invalidOuterDescriptor
        case .protocolFailure:
            InvestigationMachineZeroArgumentEntryError.protocolFailure
        case .outputUnavailable:
            InvestigationMachineZeroArgumentEntryError.outputUnavailable
        case .invalidCompletion:
            InvestigationMachineZeroArgumentEntryError.invalidCompletion
        case .containmentUncertain:
            InvestigationMachineZeroArgumentEntryError.containmentUncertain
        case .cancelled:
            InvestigationMachineZeroArgumentEntryError.cancelled
        }
    }

    var expectedStatus: Int32 {
        switch self {
        case .rootAuthorityRequired:
            InvestigationMachineDriverSupport.rootAuthorityRequiredExitStatus
        case .installedObservationUnavailable:
            InvestigationMachineDriverSupport
                .installedObservationUnavailableExitStatus
        case .invalidInvocation, .invalidInput, .invalidRole,
             .invalidOuterDescriptor:
            InvestigationMachineDriverSupport.invalidInvocationExitStatus
        case .protocolFailure, .outputUnavailable, .invalidCompletion:
            InvestigationMachineDriverSupport.protocolFailureExitStatus
        case .containmentUncertain:
            InvestigationMachineDriverSupport.containmentUncertainExitStatus
        case .cancelled:
            InvestigationMachineDriverSupport.cancelledExitStatus
        }
    }
}

private enum DriverSupportUnknownError: Error {
    case failure
}

private final class DriverSupportEntryTrace: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [String] = []

    func append(_ event: String) {
        lock.withLock { events.append(event) }
    }

    func snapshot() -> [String] {
        lock.withLock { events }
    }
}

private func driverSupportEntry(
    trace: DriverSupportEntryTrace,
    validationError: InvestigationMachineZeroArgumentEntryError? = nil
) -> InvestigationMachineZeroArgumentEntry {
    InvestigationMachineZeroArgumentEntry(
        dependencies: .init(
            validateInvocation: {
                trace.append("validate")
                if let validationError { throw validationError }
            },
            selectRole: { trace.append("role"); return .inner },
            runInner: { trace.append("inner") },
            observeInstalledDriver: { trace.append("installed") },
            readPlan: { fatalError("outer path is unreachable") },
            runCohort: { _ in fatalError("outer path is unreachable") },
            checkCancellation: { trace.append("cancel") },
            revalidateOuter: { _ in trace.append("revalidate") },
            writeArtifact: { _ in trace.append("write") }
        )
    )
}

struct InstalledDriverAuthorityIdentity:
    Sendable,
    CustomTestStringConvertible
{
    let realUserID: uid_t
    let effectiveUserID: uid_t
    let realGroupID: gid_t
    let effectiveGroupID: gid_t

    var testDescription: String {
        "ruid=\(realUserID),euid=\(effectiveUserID),"
            + "rgid=\(realGroupID),egid=\(effectiveGroupID)"
    }
}

private enum ManifestMutation: CaseIterable {
    case label
    case program
    case primaryService
    case machineClaimService
    case unknownKey
    case runAtLoad

    func apply(to manifest: [String: Any]) -> [String: Any] {
        var value = manifest
        switch self {
        case .label:
            value["Label"] = "foreign.lifecycle"
        case .program:
            value["Program"] = "/tmp/foreign-helper"
        case .primaryService:
            var services = value["MachServices"] as? [String: Bool] ?? [:]
            services["com.eriklee.stornaut.lifecycle"] = false
            value["MachServices"] = services
        case .machineClaimService:
            var services = value["MachServices"] as? [String: Bool] ?? [:]
            services["com.eriklee.stornaut.lifecycle.machine-claim"] = false
            value["MachServices"] = services
        case .unknownKey:
            value["ForeignKey"] = true
        case .runAtLoad:
            value["RunAtLoad"] = true
        }
        return value
    }
}

private final class RecordingInstalledDriverObservationSource:
    InvestigationMachineInstalledDriverObservationSource,
    @unchecked Sendable
{
    private let candidate: InvestigationMachineInstalledDriverCandidate?
    private let error: InvestigationMachineInstalledDriverObservationError?
    private(set) var readCount = 0

    init(candidate: InvestigationMachineInstalledDriverCandidate) {
        self.candidate = candidate
        error = nil
    }

    init(error: InvestigationMachineInstalledDriverObservationError) {
        candidate = nil
        self.error = error
    }

    func readCandidate() throws
        -> InvestigationMachineInstalledDriverCandidate
    {
        readCount += 1
        if let error { throw error }
        return try #require(candidate)
    }
}

enum InstalledDriverObservationMutation:
    CaseIterable,
    CustomTestStringConvertible
{
    case wrongPath
    case finalPath
    case untrustedAncestorChain
    case finalUntrustedAncestorChain
    case nonRegularFile
    case initialOwner
    case initialGroup
    case initialMode
    case initialLinkCount
    case initialSize
    case initialFlags
    case acl
    case finalACL
    case extendedAttributes
    case finalExtendedAttributes
    case descriptorIdentity
    case finalDescriptorIdentity
    case finalIdentity
    case malformedSHA
    case staticIdentifier
    case staticRequirement
    case staticCodeDirectory
    case notAdHoc
    case liveAdHoc
    case liveSigning
    case manifestPath
    case manifestOwner
    case manifestMode
    case manifestSHA
    case manifestLabel
    case manifestProgram
    case manifestPrimaryService
    case manifestMachineClaimService
    case finalManifest

    var testDescription: String { String(describing: self) }

    func apply(
        to candidate: InvestigationMachineInstalledDriverCandidate
    ) -> InvestigationMachineInstalledDriverCandidate {
        var value = candidate
        switch self {
        case .wrongPath:
            value.executablePath = "/tmp/foreign-driver"
        case .finalPath:
            value.finalExecutablePath = "/tmp/foreign-driver"
        case .untrustedAncestorChain:
            value.hasTrustedAncestorChain = false
        case .finalUntrustedAncestorChain:
            value.finalHasTrustedAncestorChain = false
        case .nonRegularFile:
            value.initialNode.isRegularFile = false
        case .initialOwner:
            value.initialNode.ownerUserID = 501
        case .initialGroup:
            value.initialNode.ownerGroupID = 20
        case .initialMode:
            value.initialNode.mode = 0o775
        case .initialLinkCount:
            value.initialNode.linkCount = 2
        case .initialSize:
            value.initialNode.size = 0
        case .initialFlags:
            value.initialNode.flags = 1
        case .acl:
            value.hasExtendedACL = true
        case .finalACL:
            value.finalHasExtendedACL = true
        case .extendedAttributes:
            value.hasUnexpectedExtendedAttributes = true
        case .finalExtendedAttributes:
            value.finalHasUnexpectedExtendedAttributes = true
        case .descriptorIdentity:
            value.descriptorNode.inode &+= 1
        case .finalDescriptorIdentity:
            value.finalDescriptorNode.inode &+= 1
        case .finalIdentity:
            value.finalNode.inode &+= 1
        case .malformedSHA:
            value.executableSHA256 = String(repeating: "0", count: 63)
        case .staticIdentifier:
            value.staticSigning.signingIdentifier = "foreign.driver"
        case .staticRequirement:
            value.staticSigning.designatedRequirementSHA256 =
                String(repeating: "0", count: 64)
        case .staticCodeDirectory:
            value.staticSigning.codeDirectoryHash =
                String(repeating: "0", count: 40)
        case .notAdHoc:
            value.staticSigning.isAdHoc = false
        case .liveAdHoc:
            value.liveSigning.isAdHoc = false
        case .liveSigning:
            value.liveSigning.codeDirectoryHash =
                String(repeating: "f", count: 40)
        case .manifestPath:
            value.manifest.path = "/tmp/foreign.plist"
        case .manifestOwner:
            value.manifest.node.ownerUserID = 501
        case .manifestMode:
            value.manifest.node.mode = 0o664
        case .manifestSHA:
            value.manifest.sha256 = String(repeating: "0", count: 64)
        case .manifestLabel:
            value.manifest.label = "foreign.lifecycle"
        case .manifestProgram:
            value.manifest.program = "/tmp/foreign-helper"
        case .manifestPrimaryService:
            value.manifest.primaryServiceIdentifier = "foreign.service"
        case .manifestMachineClaimService:
            value.manifest.machineClaimServiceIdentifier = "foreign.claim"
        case .finalManifest:
            value.finalManifest.sha256 = String(repeating: "f", count: 64)
        }
        return value
    }
}

private extension InvestigationMachineInstalledDriverCandidate {
    static func validFixture() -> Self {
        let node = InvestigationMachineInstalledDriverNodeIdentity(
            deviceID: 1,
            inode: 2,
            generation: 3,
            isRegularFile: true,
            ownerUserID: 0,
            ownerGroupID: 0,
            mode: 0o755,
            linkCount: 1,
            size: 64 * 1_024,
            flags: 0,
            modificationSeconds: 4,
            modificationNanoseconds: 5,
            statusChangeSeconds: 6,
            statusChangeNanoseconds: 7
        )
        let signing = InvestigationMachineInstalledDriverSigningIdentity(
            signingIdentifier:
                "com.eriklee.stornaut.investigation.machine-driver",
            designatedRequirementSHA256:
                String(repeating: "a", count: 64),
            codeDirectoryHash: String(repeating: "b", count: 40),
            isAdHoc: true
        )
        let manifestNode = InvestigationMachineInstalledDriverNodeIdentity(
            deviceID: 8,
            inode: 9,
            generation: 10,
            isRegularFile: true,
            ownerUserID: 0,
            ownerGroupID: 0,
            mode: 0o644,
            linkCount: 1,
            size: 1_063,
            flags: 0,
            modificationSeconds: 11,
            modificationNanoseconds: 12,
            statusChangeSeconds: 13,
            statusChangeNanoseconds: 14
        )
        let manifest = InvestigationMachineInstalledManifestIdentity(
            path: InvestigationMachineInstalledDriverObservation
                .fixedLaunchDaemonManifestPath,
            node: manifestNode,
            sha256: InvestigationMachineInstalledDriverObservation
                .fixedLaunchDaemonManifestSHA256,
            label: InvestigationMachineInstalledDriverObservation
                .fixedLifecycleLabel,
            program: InvestigationMachineInstalledDriverObservation
                .fixedLifecycleProgram,
            primaryServiceIdentifier:
                InvestigationMachineInstalledDriverObservation
                    .fixedLifecycleLabel,
            machineClaimServiceIdentifier:
                InvestigationMachineInstalledDriverObservation
                    .fixedMachineClaimServiceIdentifier
        )
        return Self(
            executablePath: InvestigationMachineInstalledDriverObservation
                .fixedExecutablePath,
            finalExecutablePath:
                InvestigationMachineInstalledDriverObservation
                    .fixedExecutablePath,
            hasTrustedAncestorChain: true,
            finalHasTrustedAncestorChain: true,
            initialNode: node,
            descriptorNode: node,
            finalDescriptorNode: node,
            finalNode: node,
            hasExtendedACL: false,
            finalHasExtendedACL: false,
            hasUnexpectedExtendedAttributes: false,
            finalHasUnexpectedExtendedAttributes: false,
            executableSHA256: String(repeating: "c", count: 64),
            staticSigning: signing,
            liveSigning: signing,
            manifest: manifest,
            finalManifest: manifest
        )
    }
}

enum InstalledDriverSystemPoint:
    CaseIterable,
    CustomTestStringConvertible
{
    case initialManifest
    case processExecutablePath
    case trustedAncestorChain
    case initialPathNode
    case open
    case initialDescriptorNode
    case acl
    case extendedAttributes
    case sha256
    case staticSigning
    case liveSigning
    case finalDescriptorNode
    case finalPathNode
    case finalManifest
    case finalACL
    case finalExtendedAttributes
    case finalTrustedAncestorChain
    case finalProcessExecutablePath
    case close

    static let successOrder: [Self] = [
        .initialManifest,
        .processExecutablePath,
        .trustedAncestorChain,
        .initialPathNode,
        .open,
        .initialDescriptorNode,
        .acl,
        .extendedAttributes,
        .sha256,
        .staticSigning,
        .liveSigning,
        .finalACL,
        .finalExtendedAttributes,
        .finalManifest,
        .finalTrustedAncestorChain,
        .finalProcessExecutablePath,
        .finalDescriptorNode,
        .finalPathNode,
        .close,
    ]

    static let postOpenFailurePoints: [Self] = [
        .initialDescriptorNode,
        .acl,
        .extendedAttributes,
        .sha256,
        .staticSigning,
        .liveSigning,
        .finalACL,
        .finalExtendedAttributes,
        .finalManifest,
        .finalTrustedAncestorChain,
        .finalProcessExecutablePath,
        .finalDescriptorNode,
        .finalPathNode,
    ]

    var testDescription: String { String(describing: self) }
}

private struct InstalledDriverSystemFixtureError: Error {}

private final class RecordingInstalledDriverSystem:
    InvestigationMachineInstalledDriverSystem,
    @unchecked Sendable
{
    private let candidate = InvestigationMachineInstalledDriverCandidate
        .validFixture()
    private let failingAt: InstalledDriverSystemPoint?
    private let closeSucceeds: Bool
    private let descriptorSize: Int64?
    private(set) var events: [InstalledDriverSystemPoint] = []
    private(set) var closeCount = 0
    private var processPathReadCount = 0
    private var ancestorReadCount = 0
    private var pathNodeReadCount = 0
    private var descriptorNodeReadCount = 0
    private var aclReadCount = 0
    private var extendedAttributeReadCount = 0
    private var manifestReadCount = 0

    init(
        failingAt: InstalledDriverSystemPoint? = nil,
        closeSucceeds: Bool = true,
        descriptorSize: Int64? = nil
    ) {
        self.failingAt = failingAt
        self.closeSucceeds = closeSucceeds
        self.descriptorSize = descriptorSize
    }

    func installedManifestIdentity() throws
        -> InvestigationMachineInstalledManifestIdentity
    {
        manifestReadCount += 1
        let point: InstalledDriverSystemPoint = manifestReadCount == 1
            ? .initialManifest
            : .finalManifest
        return try value(
            point,
            point == .initialManifest
                ? candidate.manifest
                : candidate.finalManifest
        )
    }

    func processExecutablePath() throws -> String {
        processPathReadCount += 1
        let point: InstalledDriverSystemPoint = processPathReadCount == 1
            ? .processExecutablePath
            : .finalProcessExecutablePath
        return try value(
            point,
            point == .processExecutablePath
                ? candidate.executablePath
                : candidate.finalExecutablePath
        )
    }

    func hasTrustedAncestorChain() throws -> Bool {
        ancestorReadCount += 1
        let point: InstalledDriverSystemPoint = ancestorReadCount == 1
            ? .trustedAncestorChain
            : .finalTrustedAncestorChain
        return try value(
            point,
            point == .trustedAncestorChain
                ? candidate.hasTrustedAncestorChain
                : candidate.finalHasTrustedAncestorChain
        )
    }

    func pathNode() throws
        -> InvestigationMachineInstalledDriverNodeIdentity
    {
        pathNodeReadCount += 1
        let point: InstalledDriverSystemPoint = pathNodeReadCount == 1
            ? .initialPathNode
            : .finalPathNode
        return try value(
            point,
            point == .initialPathNode
                ? candidate.initialNode
                : candidate.finalNode
        )
    }

    func openExecutable() throws -> Int32 {
        try value(.open, 71)
    }

    func descriptorNode(
        _ descriptor: Int32
    ) throws -> InvestigationMachineInstalledDriverNodeIdentity {
        #expect(descriptor == 71)
        descriptorNodeReadCount += 1
        let point: InstalledDriverSystemPoint = descriptorNodeReadCount == 1
            ? .initialDescriptorNode
            : .finalDescriptorNode
        var node = point == .initialDescriptorNode
            ? candidate.descriptorNode
            : candidate.finalDescriptorNode
        if point == .initialDescriptorNode, let descriptorSize {
            node.size = descriptorSize
        }
        return try value(
            point,
            node
        )
    }

    func hasExtendedACL(_ descriptor: Int32) throws -> Bool {
        #expect(descriptor == 71)
        aclReadCount += 1
        let point: InstalledDriverSystemPoint = aclReadCount == 1
            ? .acl
            : .finalACL
        return try value(
            point,
            point == .acl
                ? candidate.hasExtendedACL
                : candidate.finalHasExtendedACL
        )
    }

    func hasUnexpectedExtendedAttributes(_ descriptor: Int32) throws -> Bool {
        #expect(descriptor == 71)
        extendedAttributeReadCount += 1
        let point: InstalledDriverSystemPoint =
            extendedAttributeReadCount == 1
                ? .extendedAttributes
                : .finalExtendedAttributes
        return try value(
            point,
            point == .extendedAttributes
                ? candidate.hasUnexpectedExtendedAttributes
                : candidate.finalHasUnexpectedExtendedAttributes
        )
    }

    func sha256(
        _ descriptor: Int32,
        size: Int64
    ) throws -> String {
        #expect(descriptor == 71)
        #expect(size == candidate.descriptorNode.size)
        return try value(.sha256, candidate.executableSHA256)
    }

    func staticSigning() throws
        -> InvestigationMachineInstalledDriverSigningIdentity
    {
        try value(.staticSigning, candidate.staticSigning)
    }

    func liveSigning() throws
        -> InvestigationMachineInstalledDriverSigningIdentity
    {
        try value(.liveSigning, candidate.liveSigning)
    }

    func close(_ descriptor: Int32) -> Bool {
        #expect(descriptor == 71)
        events.append(.close)
        closeCount += 1
        return closeSucceeds
    }

    private func value<Value>(
        _ point: InstalledDriverSystemPoint,
        _ value: Value
    ) throws -> Value {
        events.append(point)
        if failingAt == point { throw InstalledDriverSystemFixtureError() }
        return value
    }
}
