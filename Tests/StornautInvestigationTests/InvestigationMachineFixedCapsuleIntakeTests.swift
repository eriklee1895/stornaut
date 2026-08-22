import Darwin
import Foundation
import Testing
@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationMachineDriverSupport

@Suite("Investigation machine fixed capsule intake", .serialized)
struct InvestigationMachineFixedCapsuleIntakeTests {
    @Test
    func fixedCapsuleIntakeProvidesClosedFDZeroSurface() throws {
        let source = try fixedCapsuleIntakeSource()
        for required in [
            "package struct InvestigationMachineFixedCapsuleIntake",
            "package func read() throws",
            "STDIN_FILENO",
            "package actor InvestigationMachineFixedEpochPlan",
            "package func takeNext() throws",
        ] {
            #expect(source.contains(required))
        }
        for forbidden in [
            "package func read(descriptor:",
            "package func read(path:",
            "package func select(ordinal:",
            "package func select(scenario:",
            "FileHandle.standardInput",
            "JSONDecoder",
        ] {
            #expect(!source.contains(forbidden))
        }
    }

    @Test
    func validCapsuleReadsOnlyFDZeroAndYieldsCanonicalRows() async throws {
        let capsule = try fixedCapsule()
        let encoded = try capsule.encoded()
        let system = ScriptedFixedCapsuleSystem(bytes: encoded)
        let plan = try InvestigationMachineFixedCapsuleIntake(
            system: system
        ).read()

        var selections: [InvestigationMachineFixedEpochSelection] = []
        for _ in 0..<InvestigationCohortCapsule.epochCount {
            selections.append(try await plan.takeNext())
        }
        await #expect(
            throws: InvestigationMachineFixedCapsuleIntakeError.exhausted
        ) {
            _ = try await plan.takeNext()
        }

        #expect(selections.map(\.outerAttemptUUID) == Array(
            repeating: UUID(
                uuidString: "00000000-0000-0000-0000-000000000001"
            )!,
            count: 8
        ))
        #expect(selections.map(\.wholeCapsuleSHA256) == Array(
            repeating: capsule.wholeCapsuleSHA256,
            count: 8
        ))
        #expect(selections.map { $0.epoch.ordinal } == Array(UInt32(0)...7))
        #expect(
            selections.map { $0.epoch.scenario }
                == InvestigationHandoffScenario.allCases
        )
        #expect(system.descriptors.allSatisfy { $0 == STDIN_FILENO })
        #expect(system.setFlags == [FD_CLOEXEC])
        #expect(system.maximumReadCounts.allSatisfy {
            $0 > 0 && $0 <= 16 * 1_024
        })
    }

    @Test(arguments: FixedCapsuleInputMutation.allCases)
    fileprivate func invalidDescriptorProvenanceFailsClosed(
        _ mutation: FixedCapsuleInputMutation
    ) throws {
        let encoded = try fixedCapsule().encoded()
        let system = ScriptedFixedCapsuleSystem(
            bytes: mutation == .trailingGrowth
                ? encoded + Data([0xff])
                : mutation == .prematureEOF
                    ? Data(encoded.dropLast())
                    : encoded,
            declaredSize: mutation == .trailingGrowth
                || mutation == .prematureEOF
                ? Int64(encoded.count)
                : nil
        )
        mutation.apply(to: system)

        #expect(
            throws: InvestigationMachineFixedCapsuleIntakeError
                .invalidStandardInput
        ) {
            _ = try InvestigationMachineFixedCapsuleIntake(
                system: system
            ).read()
        }
    }

    @Test
    func interruptedReadRetriesAndMalformedCapsuleIsRejected() throws {
        let encoded = try fixedCapsule().encoded()
        let interrupted = ScriptedFixedCapsuleSystem(
            bytes: encoded,
            scriptedReads: [.failure(.init(errno: EINTR))]
        )
        _ = try InvestigationMachineFixedCapsuleIntake(
            system: interrupted
        ).read()
        #expect(interrupted.readCallCount >= 3)

        var malformed = encoded
        malformed[malformed.startIndex] ^= 0xff
        let malformedSystem = ScriptedFixedCapsuleSystem(bytes: malformed)
        #expect(
            throws: InvestigationMachineFixedCapsuleIntakeError.invalidCapsule
        ) {
            _ = try InvestigationMachineFixedCapsuleIntake(
                system: malformedSystem
            ).read()
        }
    }

    @Test
    func darwinSystemRecognizesARealExtendedACL() throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-fixed-capsule-acl-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        let file = root.appending(path: "capsule")
        let system = DarwinInvestigationMachineFixedCapsuleSystem()
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
        let initialDescriptor = Darwin.open(
            file.path,
            O_RDONLY | O_CLOEXEC
        )
        try #require(initialDescriptor >= 0)
        #expect(try !system.hasExtendedACL(initialDescriptor).get())
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

        let hasACL = try system.hasExtendedACL(descriptor).get()
        #expect(hasACL)
    }

    @Test
    func planAliasesShareOneNonReplayableCursor() async throws {
        let capsule = try fixedCapsule()
        let plan = try InvestigationMachineFixedCapsuleIntake(
            system: ScriptedFixedCapsuleSystem(
                bytes: try capsule.encoded()
            )
        ).read()
        let alias = plan

        #expect(try await plan.takeNext().epoch.ordinal == 0)
        #expect(try await alias.takeNext().epoch.ordinal == 1)
        for expected in UInt32(2)...UInt32(7) {
            #expect(try await plan.takeNext().epoch.ordinal == expected)
        }
        await #expect(
            throws: InvestigationMachineFixedCapsuleIntakeError.exhausted
        ) {
            _ = try await alias.takeNext()
        }
    }
}

private enum FixedCapsuleInputMutation: CaseIterable {
    case initialOffset, flagsRead, flagsWrite, flagsNotSet
    case statusFlagsRead, writableDescriptor, finalDescriptorFlagsDrift
    case finalStatusFlagsDrift
    case zeroDevice, zeroInode, nonRegular, wrongOwner, wrongMode
    case multipleLinks, unexpectedFileFlags
    case empty, oversized, initialACL, initialXattr
    case prematureEOF, trailingGrowth, finalOffset, metadataDrift
    case finalACL, finalXattr, readFailure

    func apply(to system: ScriptedFixedCapsuleSystem) {
        switch self {
        case .initialOffset:
            system.offsets = [.success(1)]
        case .flagsRead:
            system.flagReads = [.failure(.init(errno: EBADF))]
        case .flagsWrite:
            system.setFlagsError = .init(errno: EBADF)
        case .flagsNotSet:
            system.flagReads = [.success(0), .success(0)]
        case .statusFlagsRead:
            system.statusFlagReads = [.failure(.init(errno: EBADF))]
        case .writableDescriptor:
            system.statusFlagReads = [.success(O_RDWR)]
        case .finalDescriptorFlagsDrift:
            system.flagReads = [
                .success(0),
                .success(FD_CLOEXEC),
                .success(0),
            ]
        case .finalStatusFlagsDrift:
            system.statusFlagReads = [.success(O_RDONLY), .success(O_RDWR)]
        case .zeroDevice:
            system.snapshots = [.success(.valid(deviceID: 0))]
        case .zeroInode:
            system.snapshots = [.success(.valid(inode: 0))]
        case .nonRegular:
            system.snapshots = [.success(.valid(isRegularFile: false))]
        case .wrongOwner:
            system.snapshots = [.success(.valid(ownerUserID: 502))]
        case .wrongMode:
            system.snapshots = [.success(.valid(mode: 0o640))]
        case .multipleLinks:
            system.snapshots = [.success(.valid(linkCount: 2))]
        case .unexpectedFileFlags:
            system.snapshots = [.success(.valid(flags: 1))]
        case .empty:
            system.snapshots = [.success(.valid(size: 0))]
        case .oversized:
            system.snapshots = [.success(.valid(
                size: Int64(InvestigationCohortCapsule.maximumByteCount + 1)
            ))]
        case .initialACL:
            system.aclResults = [.success(true)]
        case .initialXattr:
            system.xattrResults = [.success(true)]
        case .prematureEOF, .trailingGrowth:
            break
        case .finalOffset:
            system.offsets = [.success(0), .success(1)]
        case .metadataDrift:
            let size = system.declaredSize
            system.snapshots = [
                .success(.valid(size: size)),
                .success(.valid(
                    size: size,
                    modificationNanoseconds: 2
                )),
            ]
        case .finalACL:
            system.aclResults = [.success(false), .success(true)]
        case .finalXattr:
            system.xattrResults = [.success(false), .success(true)]
        case .readFailure:
            system.scriptedReads = [.failure(.init(errno: EIO))]
        }
    }
}

private enum FixedCapsuleEvent: Equatable {
    case flags, statusFlags, setFlags(Int32), offset, snapshot, acl, xattr
    case read(Int)
}

private final class ScriptedFixedCapsuleSystem:
    InvestigationMachineFixedCapsuleSystem,
    @unchecked Sendable
{
    var bytes: Data
    let declaredSize: Int64
    var cursor = 0
    var flagReads: [Result<Int32, InvestigationMachineFixedCapsuleSystemError>]
    var statusFlagReads:
        [Result<Int32, InvestigationMachineFixedCapsuleSystemError>]
    var setFlagsError: InvestigationMachineFixedCapsuleSystemError?
    var offsets: [Result<Int64, InvestigationMachineFixedCapsuleSystemError>] = []
    var snapshots: [Result<InvestigationMachineFixedCapsuleDescriptorSnapshot, InvestigationMachineFixedCapsuleSystemError>]
    var aclResults: [Result<Bool, InvestigationMachineFixedCapsuleSystemError>] = [
        .success(false), .success(false),
    ]
    var xattrResults: [Result<Bool, InvestigationMachineFixedCapsuleSystemError>] = [
        .success(false), .success(false),
    ]
    var scriptedReads: [Result<Data, InvestigationMachineFixedCapsuleSystemError>]
    var events: [FixedCapsuleEvent] = []
    var descriptors: [Int32] = []
    var setFlags: [Int32] = []
    var maximumReadCounts: [Int] = []
    var readCallCount = 0

    init(
        bytes: Data,
        declaredSize: Int64? = nil,
        scriptedReads: [Result<Data, InvestigationMachineFixedCapsuleSystemError>] = []
    ) {
        self.bytes = bytes
        self.declaredSize = declaredSize ?? Int64(bytes.count)
        flagReads = [
            .success(0),
            .success(FD_CLOEXEC),
            .success(FD_CLOEXEC),
        ]
        statusFlagReads = [.success(O_RDONLY), .success(O_RDONLY)]
        snapshots = [
            .success(.valid(size: self.declaredSize)),
            .success(.valid(size: self.declaredSize)),
        ]
        self.scriptedReads = scriptedReads
    }

    func descriptorFlags(_ descriptor: Int32)
        -> Result<Int32, InvestigationMachineFixedCapsuleSystemError>
    {
        record(.flags, descriptor: descriptor)
        return flagReads.removeFirst()
    }

    func setDescriptorFlags(_ descriptor: Int32, flags: Int32)
        -> Result<Void, InvestigationMachineFixedCapsuleSystemError>
    {
        record(.setFlags(flags), descriptor: descriptor)
        setFlags.append(flags)
        return setFlagsError.map(Result.failure) ?? .success(())
    }

    func descriptorStatusFlags(_ descriptor: Int32)
        -> Result<Int32, InvestigationMachineFixedCapsuleSystemError>
    {
        record(.statusFlags, descriptor: descriptor)
        if statusFlagReads.count == 1 { return statusFlagReads[0] }
        return statusFlagReads.removeFirst()
    }

    func offset(_ descriptor: Int32)
        -> Result<Int64, InvestigationMachineFixedCapsuleSystemError>
    {
        record(.offset, descriptor: descriptor)
        if !offsets.isEmpty { return offsets.removeFirst() }
        return .success(Int64(cursor))
    }

    func snapshot(_ descriptor: Int32)
        -> Result<InvestigationMachineFixedCapsuleDescriptorSnapshot, InvestigationMachineFixedCapsuleSystemError>
    {
        record(.snapshot, descriptor: descriptor)
        if snapshots.count == 1 { return snapshots[0] }
        return snapshots.removeFirst()
    }

    func hasExtendedACL(_ descriptor: Int32)
        -> Result<Bool, InvestigationMachineFixedCapsuleSystemError>
    {
        record(.acl, descriptor: descriptor)
        if aclResults.count == 1 { return aclResults[0] }
        return aclResults.removeFirst()
    }

    func hasExtendedAttributes(_ descriptor: Int32)
        -> Result<Bool, InvestigationMachineFixedCapsuleSystemError>
    {
        record(.xattr, descriptor: descriptor)
        if xattrResults.count == 1 { return xattrResults[0] }
        return xattrResults.removeFirst()
    }

    func read(_ descriptor: Int32, maximumByteCount: Int)
        -> Result<Data, InvestigationMachineFixedCapsuleSystemError>
    {
        record(.read(maximumByteCount), descriptor: descriptor)
        maximumReadCounts.append(maximumByteCount)
        readCallCount += 1
        if !scriptedReads.isEmpty { return scriptedReads.removeFirst() }
        let count = min(maximumByteCount, bytes.count - cursor)
        guard count > 0 else { return .success(Data()) }
        defer { cursor += count }
        return .success(bytes[cursor..<(cursor + count)])
    }

    private func record(_ event: FixedCapsuleEvent, descriptor: Int32) {
        events.append(event)
        descriptors.append(descriptor)
    }
}

private extension InvestigationMachineFixedCapsuleDescriptorSnapshot {
    static func valid(
        deviceID: UInt64 = 1,
        inode: UInt64 = 2,
        isRegularFile: Bool = true,
        ownerUserID: UInt32 = 501,
        mode: UInt16 = 0o600,
        linkCount: UInt64 = 1,
        size: Int64 = 1,
        flags: UInt32 = 0,
        modificationNanoseconds: Int64 = 1
    ) -> Self {
        .init(
            deviceID: deviceID, inode: inode, generation: 3,
            isRegularFile: isRegularFile, ownerUserID: ownerUserID,
            ownerGroupID: 20, mode: mode, linkCount: linkCount, size: size,
            flags: flags, modificationSeconds: 1,
            modificationNanoseconds: modificationNanoseconds,
            statusChangeSeconds: 1, statusChangeNanoseconds: 1
        )
    }
}

private func fixedCapsule() throws -> InvestigationCohortCapsule {
    try InvestigationCohortCapsule(
        outerAttemptUUID: fixedCapsuleUUID(1),
        epochs: (0..<8).map { ordinal in
            let bytes = Data("configuration-\(ordinal)".utf8)
            return try InvestigationCohortEpoch(
                ordinal: UInt32(ordinal),
                epochUUID: fixedCapsuleUUID(UInt8(0x10 + ordinal)),
                scenario: try #require(InvestigationHandoffScenario(
                    rawValue: UInt32(ordinal + 1)
                )),
                configurationNonce: fixedCapsuleUUID(
                    UInt8(0x20 + ordinal)
                ),
                configuration: bytes,
                configurationSHA256: .hashing(bytes),
                signedRuntimeBindingSHA256: try InvestigationHandoffSHA256(
                    rawBytes: Data(
                        repeating: UInt8(0x40 + ordinal),
                        count: InvestigationHandoffSHA256.byteCount
                    )
                )
            )
        }
    )
}

private func fixedCapsuleUUID(_ finalByte: UInt8) -> UUID {
    UUID(
        uuidString: "00000000-0000-0000-0000-0000000000"
            + String(format: "%02x", finalByte)
    )!
}

private func fixedCapsuleIntakeSource() throws -> String {
    let root = URL(filePath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    return try String(
        contentsOf: root.appending(
            path: "Sources/StornautInvestigationMachineDriverSupport/"
                + "InvestigationMachineFixedCapsuleIntake.swift"
        ),
        encoding: .utf8
    )
}
