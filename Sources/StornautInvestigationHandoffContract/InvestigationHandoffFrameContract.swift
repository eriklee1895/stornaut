import Foundation

package enum InvestigationHandoffFrameDirection:
    Sendable,
    Equatable
{
    case appToDriver
    case driverToApp
}

package enum InvestigationHandoffFrameKind:
    UInt16,
    Sendable,
    CaseIterable
{
    case preDropReady = 1
    case dropRelease = 2
    case dropEvidence = 3
    case configuration = 4
    case configurationAcknowledgement = 5
    case hello = 6
    case handle = 7
    case acknowledgement = 8
    case release = 9
    case alive = 10
    case exit = 11

    package var sequence: UInt32 {
        UInt32(rawValue)
    }

    package var direction: InvestigationHandoffFrameDirection {
        switch self {
        case .preDropReady,
             .dropEvidence,
             .configurationAcknowledgement,
             .hello,
             .handle,
             .alive:
            .appToDriver
        case .dropRelease,
             .configuration,
             .acknowledgement,
             .release,
             .exit:
            .driverToApp
        }
    }

    package var expectedSenderEffectiveUserID: UInt32 {
        switch self {
        case .dropEvidence,
             .configurationAcknowledgement,
             .hello,
             .handle,
             .alive:
            501
        case .preDropReady,
             .dropRelease,
             .configuration,
             .acknowledgement,
             .release,
             .exit:
            0
        }
    }

    package func admitsPayloadByteCount(_ count: Int) -> Bool {
        switch self {
        case .preDropReady, .dropRelease, .hello, .release, .alive, .exit:
            count == 0
        case .configuration:
            (1...65_536).contains(count)
        case .dropEvidence,
             .configurationAcknowledgement,
             .handle,
             .acknowledgement:
            (1...1_024).contains(count)
        }
    }
}

package struct InvestigationHandoffProcessClaim:
    Sendable,
    Equatable
{
    package let processID: UInt32
    package let processIDVersion: UInt32
    package let effectiveUserID: UInt32
    package let auditSessionID: UInt32

    package init(
        processID: UInt32,
        processIDVersion: UInt32,
        effectiveUserID: UInt32,
        auditSessionID: UInt32
    ) throws {
        guard
            processID > 1,
            processIDVersion > 0,
            auditSessionID > 0
        else {
            throw InvestigationHandoffContractError.invalidValue
        }
        self.processID = processID
        self.processIDVersion = processIDVersion
        self.effectiveUserID = effectiveUserID
        self.auditSessionID = auditSessionID
    }
}

package struct InvestigationHandoffDropEvidence:
    Sendable,
    Equatable
{
    package static let domain =
        "stornaut.task39.handoff.drop-evidence"
    package static let maximumByteCount = 1_024
    package static let requiredPermissionErrno: UInt32 = 1

    package let realUserID: UInt32
    package let effectiveUserID: UInt32
    package let savedUserID: UInt32
    package let realGroupID: UInt32
    package let effectiveGroupID: UInt32
    package let savedGroupID: UInt32
    package let supplementaryGroups: [UInt32]
    package let auditTokenWords: [UInt32]
    package let setuidRootErrno: UInt32
    package let seteuidRootErrno: UInt32
    package let setgidRootErrno: UInt32

    package init(
        realUserID: UInt32,
        effectiveUserID: UInt32,
        savedUserID: UInt32,
        realGroupID: UInt32,
        effectiveGroupID: UInt32,
        savedGroupID: UInt32,
        supplementaryGroups: [UInt32],
        auditTokenWords: [UInt32],
        setuidRootErrno: UInt32,
        seteuidRootErrno: UInt32,
        setgidRootErrno: UInt32
    ) throws {
        guard
            realUserID == 501,
            effectiveUserID == 501,
            savedUserID == 501,
            realGroupID == 20,
            effectiveGroupID == 20,
            savedGroupID == 20,
            supplementaryGroups.count == 16,
            supplementaryGroups == supplementaryGroups.sorted(),
            Set(supplementaryGroups).count == 16,
            supplementaryGroups.contains(20),
            auditTokenWords.count == 8,
            auditTokenWords[1] == 501,
            auditTokenWords[2] == 20,
            auditTokenWords[3] == 501,
            auditTokenWords[4] == 20,
            auditTokenWords[5] > 1,
            auditTokenWords[6] > 0,
            auditTokenWords[7] > 0,
            setuidRootErrno == Self.requiredPermissionErrno,
            seteuidRootErrno == Self.requiredPermissionErrno,
            setgidRootErrno == Self.requiredPermissionErrno
        else {
            throw InvestigationHandoffContractError.invalidValue
        }
        self.realUserID = realUserID
        self.effectiveUserID = effectiveUserID
        self.savedUserID = savedUserID
        self.realGroupID = realGroupID
        self.effectiveGroupID = effectiveGroupID
        self.savedGroupID = savedGroupID
        self.supplementaryGroups = supplementaryGroups
        self.auditTokenWords = auditTokenWords
        self.setuidRootErrno = setuidRootErrno
        self.seteuidRootErrno = seteuidRootErrno
        self.setgidRootErrno = setgidRootErrno
    }

    package func encoded() throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: Self.domain,
            businessFields: [
                handoffData(realUserID),
                handoffData(effectiveUserID),
                handoffData(savedUserID),
                handoffData(realGroupID),
                handoffData(effectiveGroupID),
                handoffData(savedGroupID),
                handoffData(UInt32(supplementaryGroups.count)),
                supplementaryGroups.reduce(into: Data()) {
                    $0.append(handoffData($1))
                },
                auditTokenWords.reduce(into: Data()) {
                    $0.append(handoffData($1))
                },
                handoffData(setuidRootErrno),
                handoffData(seteuidRootErrno),
                handoffData(setgidRootErrno),
            ],
            maximumByteCount: Self.maximumByteCount
        )
    }

    package static func decode(_ data: Data) throws -> Self {
        let fields = try HandoffBinaryTranscript.decode(
            data,
            expectedDomain: domain,
            expectedBusinessFieldByteCounts: [
                4...4, 4...4, 4...4, 4...4, 4...4, 4...4,
                4...4, 64...64, 32...32, 4...4, 4...4, 4...4,
            ],
            maximumByteCount: maximumByteCount
        )
        return try Self(
            realUserID: handoffDecodeUInt32(fields[0]),
            effectiveUserID: handoffDecodeUInt32(fields[1]),
            savedUserID: handoffDecodeUInt32(fields[2]),
            realGroupID: handoffDecodeUInt32(fields[3]),
            effectiveGroupID: handoffDecodeUInt32(fields[4]),
            savedGroupID: handoffDecodeUInt32(fields[5]),
            supplementaryGroups: try handoffDecodeUInt32Array(
                fields[7],
                expectedCount: Int(handoffDecodeUInt32(fields[6]))
            ),
            auditTokenWords: try handoffDecodeUInt32Array(
                fields[8],
                expectedCount: 8
            ),
            setuidRootErrno: handoffDecodeUInt32(fields[9]),
            seteuidRootErrno: handoffDecodeUInt32(fields[10]),
            setgidRootErrno: handoffDecodeUInt32(fields[11])
        )
    }

    func matches(sender: InvestigationHandoffProcessClaim) -> Bool {
        sender.processID == auditTokenWords[5]
            && sender.processIDVersion == auditTokenWords[7]
            && sender.effectiveUserID == auditTokenWords[1]
            && sender.auditSessionID == auditTokenWords[6]
    }
}

package struct InvestigationHandoffConfigurationAcknowledgement:
    Sendable,
    Equatable
{
    package static let domain =
        "stornaut.task39.handoff.configuration-ack"
    package static let maximumByteCount = 1_024

    package let epochUUID: UUID
    package let ordinal: UInt32
    package let configurationNonce: UUID
    package let scenario: InvestigationHandoffScenario
    package let configurationSHA256: InvestigationHandoffSHA256
    package let signedRuntimeBindingSHA256: InvestigationHandoffSHA256

    package init(
        epochUUID: UUID,
        ordinal: UInt32,
        configurationNonce: UUID,
        scenario: InvestigationHandoffScenario,
        configurationSHA256: InvestigationHandoffSHA256,
        signedRuntimeBindingSHA256: InvestigationHandoffSHA256
    ) throws {
        guard
            handoffUUIDIsNonzero(epochUUID),
            ordinal < 8,
            handoffUUIDIsNonzero(configurationNonce),
            scenario.rawValue == ordinal + 1
        else {
            throw InvestigationHandoffContractError.invalidValue
        }
        self.epochUUID = epochUUID
        self.ordinal = ordinal
        self.configurationNonce = configurationNonce
        self.scenario = scenario
        self.configurationSHA256 = configurationSHA256
        self.signedRuntimeBindingSHA256 = signedRuntimeBindingSHA256
    }

    package func encoded() throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: Self.domain,
            businessFields: [
                handoffData(epochUUID),
                handoffData(ordinal),
                handoffData(configurationNonce),
                handoffData(scenario.rawValue),
                configurationSHA256.rawBytes,
                signedRuntimeBindingSHA256.rawBytes,
            ],
            maximumByteCount: Self.maximumByteCount
        )
    }

    package static func decode(_ data: Data) throws -> Self {
        let fields = try HandoffBinaryTranscript.decode(
            data,
            expectedDomain: domain,
            expectedBusinessFieldByteCounts: [
                16...16, 4...4, 16...16, 4...4, 32...32, 32...32,
            ],
            maximumByteCount: maximumByteCount
        )
        guard let scenario = InvestigationHandoffScenario(
            rawValue: try handoffDecodeUInt32(fields[3])
        ) else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        return try Self(
            epochUUID: handoffUUID(fields[0]),
            ordinal: handoffDecodeUInt32(fields[1]),
            configurationNonce: handoffUUID(fields[2]),
            scenario: scenario,
            configurationSHA256: InvestigationHandoffSHA256(
                rawBytes: fields[4]
            ),
            signedRuntimeBindingSHA256: InvestigationHandoffSHA256(
                rawBytes: fields[5]
            )
        )
    }
}

package struct InvestigationHandoffRetirementHandle:
    Sendable,
    Equatable
{
    package static let domain =
        "stornaut.task39.handoff.retirement-handle"
    package static let maximumByteCount = 1_024

    package let token: UUID
    package let investigationUUID: UUID
    package let retireOperationUUID: UUID
    package let configurationSHA256: InvestigationHandoffSHA256
    package let validBefore: InvestigationHandoffUTCMicroseconds

    package init(
        token: UUID,
        investigationUUID: UUID,
        retireOperationUUID: UUID,
        configurationSHA256: InvestigationHandoffSHA256,
        validBefore: InvestigationHandoffUTCMicroseconds
    ) throws {
        guard
            handoffUUIDIsNonzero(token),
            handoffUUIDIsNonzero(investigationUUID),
            handoffUUIDIsNonzero(retireOperationUUID)
        else {
            throw InvestigationHandoffContractError.invalidValue
        }
        self.token = token
        self.investigationUUID = investigationUUID
        self.retireOperationUUID = retireOperationUUID
        self.configurationSHA256 = configurationSHA256
        self.validBefore = validBefore
    }

    package func encoded() throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: Self.domain,
            businessFields: [
                handoffData(token),
                handoffData(investigationUUID),
                handoffData(retireOperationUUID),
                configurationSHA256.rawBytes,
                handoffData(validBefore.rawValue),
            ],
            maximumByteCount: Self.maximumByteCount
        )
    }

    package static func decode(_ data: Data) throws -> Self {
        let fields = try HandoffBinaryTranscript.decode(
            data,
            expectedDomain: domain,
            expectedBusinessFieldByteCounts: [
                16...16, 16...16, 16...16, 32...32, 8...8,
            ],
            maximumByteCount: maximumByteCount
        )
        return try Self(
            token: handoffUUID(fields[0]),
            investigationUUID: handoffUUID(fields[1]),
            retireOperationUUID: handoffUUID(fields[2]),
            configurationSHA256: InvestigationHandoffSHA256(
                rawBytes: fields[3]
            ),
            validBefore: InvestigationHandoffUTCMicroseconds(
                rawValue: handoffDecodeInt64(fields[4])
            )
        )
    }
}

package struct InvestigationHandoffRetirementHandleAcknowledgement:
    Sendable,
    Equatable
{
    package static let domain =
        "stornaut.task39.handoff.retirement-handle-ack"
    package static let maximumByteCount = 1_024

    package let handleSHA256: InvestigationHandoffSHA256

    package init(handleSHA256: InvestigationHandoffSHA256) {
        self.handleSHA256 = handleSHA256
    }

    package func encoded() throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: Self.domain,
            businessFields: [handleSHA256.rawBytes],
            maximumByteCount: Self.maximumByteCount
        )
    }

    package static func decode(_ data: Data) throws -> Self {
        let fields = try HandoffBinaryTranscript.decode(
            data,
            expectedDomain: domain,
            expectedBusinessFieldByteCounts: [32...32],
            maximumByteCount: maximumByteCount
        )
        return try Self(
            handleSHA256: InvestigationHandoffSHA256(rawBytes: fields[0])
        )
    }
}

package enum InvestigationHandoffFramePayload:
    Sendable,
    Equatable
{
    case empty
    case configuration(Data)
    case dropEvidence(InvestigationHandoffDropEvidence)
    case configurationAcknowledgement(
        InvestigationHandoffConfigurationAcknowledgement
    )
    case retirementHandle(InvestigationHandoffRetirementHandle)
    case retirementHandleAcknowledgement(
        InvestigationHandoffRetirementHandleAcknowledgement
    )

    func encoded(for kind: InvestigationHandoffFrameKind) throws -> Data {
        switch (kind, self) {
        case (.preDropReady, .empty),
             (.dropRelease, .empty),
             (.hello, .empty),
             (.release, .empty),
             (.alive, .empty),
             (.exit, .empty):
            Data()
        case let (.configuration, .configuration(data)):
            data
        case let (.dropEvidence, .dropEvidence(value)):
            try value.encoded()
        case let (
            .configurationAcknowledgement,
            .configurationAcknowledgement(value)
        ):
            try value.encoded()
        case let (.handle, .retirementHandle(value)):
            try value.encoded()
        case let (
            .acknowledgement,
            .retirementHandleAcknowledgement(value)
        ):
            try value.encoded()
        default:
            throw InvestigationHandoffContractError.invalidValue
        }
    }

    static func decode(
        _ data: Data,
        for kind: InvestigationHandoffFrameKind
    ) throws -> Self {
        switch kind {
        case .preDropReady, .dropRelease, .hello, .release, .alive, .exit:
            guard data.isEmpty else {
                throw InvestigationHandoffContractError.invalidEncoding
            }
            return .empty
        case .configuration:
            return .configuration(data)
        case .dropEvidence:
            return .dropEvidence(
                try InvestigationHandoffDropEvidence.decode(data)
            )
        case .configurationAcknowledgement:
            return .configurationAcknowledgement(
                try InvestigationHandoffConfigurationAcknowledgement.decode(
                    data
                )
            )
        case .handle:
            return .retirementHandle(
                try InvestigationHandoffRetirementHandle.decode(data)
            )
        case .acknowledgement:
            return .retirementHandleAcknowledgement(
                try InvestigationHandoffRetirementHandleAcknowledgement.decode(
                    data
                )
            )
        }
    }
}

package struct InvestigationHandoffFrame:
    Sendable,
    Equatable
{
    package static let magic: UInt32 = 0x5354_4e48
    package static let version: UInt16 = 1
    package static let headerByteCount = 56

    package let kind: InvestigationHandoffFrameKind
    package let epochUUID: UUID
    package let epochDeadlineNanoseconds: UInt64
    package let sender: InvestigationHandoffProcessClaim
    package let payload: InvestigationHandoffFramePayload

    package init(
        kind: InvestigationHandoffFrameKind,
        epochUUID: UUID,
        epochDeadlineNanoseconds: UInt64,
        sender: InvestigationHandoffProcessClaim,
        payload: InvestigationHandoffFramePayload
    ) throws {
        let encodedPayload = try payload.encoded(for: kind)
        guard
            handoffUUIDIsNonzero(epochUUID),
            epochDeadlineNanoseconds > 0,
            sender.effectiveUserID == kind.expectedSenderEffectiveUserID,
            kind.admitsPayloadByteCount(encodedPayload.count)
        else {
            throw InvestigationHandoffContractError.invalidValue
        }
        if case let .dropEvidence(evidence) = payload {
            guard evidence.matches(sender: sender) else {
                throw InvestigationHandoffContractError.invalidValue
            }
        }
        if case let .configurationAcknowledgement(value) = payload {
            guard value.epochUUID == epochUUID else {
                throw InvestigationHandoffContractError.invalidValue
            }
        }
        self.kind = kind
        self.epochUUID = epochUUID
        self.epochDeadlineNanoseconds = epochDeadlineNanoseconds
        self.sender = sender
        self.payload = payload
    }

    package func encoded() throws -> Data {
        let encodedPayload = try payload.encoded(for: kind)
        guard let length = UInt32(exactly: encodedPayload.count) else {
            throw InvestigationHandoffContractError.sizeLimitExceeded
        }
        var data = Data()
        data.reserveCapacity(Self.headerByteCount + encodedPayload.count)
        data.append(handoffData(Self.magic))
        data.append(handoffData(Self.version))
        data.append(handoffData(kind.rawValue))
        data.append(handoffData(length))
        data.append(handoffData(kind.sequence))
        data.append(handoffData(epochUUID))
        data.append(handoffData(epochDeadlineNanoseconds))
        data.append(handoffData(sender.processID))
        data.append(handoffData(sender.processIDVersion))
        data.append(handoffData(sender.effectiveUserID))
        data.append(handoffData(sender.auditSessionID))
        guard data.count == Self.headerByteCount else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        data.append(encodedPayload)
        return data
    }

    package static func decode<D: DataProtocol>(_ input: D) throws -> Self {
        let data = Data(input)
        guard data.count >= headerByteCount else {
            throw InvestigationHandoffContractError.incompleteInput
        }
        var cursor = HandoffBinaryCursor(data: data)
        guard
            try cursor.readUInt32() == magic,
            try cursor.readUInt16() == version,
            let kind = InvestigationHandoffFrameKind(
                rawValue: try cursor.readUInt16()
            )
        else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        let payloadLength = try cursor.readUInt32()
        guard
            let payloadByteCount = Int(exactly: payloadLength),
            kind.admitsPayloadByteCount(payloadByteCount),
            try cursor.readUInt32() == kind.sequence
        else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        let epochUUID = try handoffUUID(try cursor.read(count: 16))
        let deadline = try cursor.readUInt64()
        let sender = try InvestigationHandoffProcessClaim(
            processID: cursor.readUInt32(),
            processIDVersion: cursor.readUInt32(),
            effectiveUserID: cursor.readUInt32(),
            auditSessionID: cursor.readUInt32()
        )
        guard
            cursor.offset == headerByteCount,
            cursor.remainingByteCount == payloadByteCount
        else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        let payload = try InvestigationHandoffFramePayload.decode(
            cursor.read(count: payloadByteCount),
            for: kind
        )
        guard cursor.isAtEnd else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        return try Self(
            kind: kind,
            epochUUID: epochUUID,
            epochDeadlineNanoseconds: deadline,
            sender: sender,
            payload: payload
        )
    }
}

package struct InvestigationHandoffFrameStreamDecoder: Sendable {
    package static let maximumBufferedByteCount = 65_592

    private var buffer = Data()

    package init() {}

    package mutating func append<D: DataProtocol>(
        _ input: D
    ) throws -> [InvestigationHandoffFrame] {
        let incoming = Data(input)
        var incomingOffset = 0
        var frames: [InvestigationHandoffFrame] = []
        while incomingOffset < incoming.count {
            frames += try drainCompleteFrames()
            let capacity = Self.maximumBufferedByteCount - buffer.count
            guard capacity > 0 else {
                throw InvestigationHandoffContractError.sizeLimitExceeded
            }
            let count = min(capacity, incoming.count - incomingOffset)
            buffer.append(
                incoming.subdata(
                    in: incomingOffset..<(incomingOffset + count)
                )
            )
            incomingOffset += count
        }
        frames += try drainCompleteFrames()
        return frames
    }

    package func finish() throws {
        guard buffer.isEmpty else {
            throw InvestigationHandoffContractError.incompleteInput
        }
    }

    private mutating func drainCompleteFrames() throws
        -> [InvestigationHandoffFrame]
    {
        var frames: [InvestigationHandoffFrame] = []
        while buffer.count >= InvestigationHandoffFrame.headerByteCount {
            let frameByteCount = try handoffAdmittedFrameByteCount(
                buffer.prefix(InvestigationHandoffFrame.headerByteCount)
            )
            guard frameByteCount <= Self.maximumBufferedByteCount else {
                throw InvestigationHandoffContractError.sizeLimitExceeded
            }
            guard buffer.count >= frameByteCount else { break }
            let bytes = Data(buffer.prefix(frameByteCount))
            frames.append(try InvestigationHandoffFrame.decode(bytes))
            buffer.removeFirst(frameByteCount)
        }
        return frames
    }
}

private func handoffDecodeUInt32Array(
    _ data: Data,
    expectedCount: Int
) throws -> [UInt32] {
    guard
        expectedCount >= 0,
        data.count == expectedCount * 4
    else {
        throw InvestigationHandoffContractError.invalidEncoding
    }
    var cursor = HandoffBinaryCursor(data: data)
    var values: [UInt32] = []
    values.reserveCapacity(expectedCount)
    for _ in 0..<expectedCount {
        values.append(try cursor.readUInt32())
    }
    guard cursor.isAtEnd else {
        throw InvestigationHandoffContractError.invalidEncoding
    }
    return values
}

private func handoffAdmittedFrameByteCount<D: DataProtocol>(
    _ headerInput: D
) throws -> Int {
    let header = Data(headerInput)
    guard header.count == InvestigationHandoffFrame.headerByteCount else {
        throw InvestigationHandoffContractError.incompleteInput
    }
    var cursor = HandoffBinaryCursor(data: header)
    guard
        try cursor.readUInt32() == InvestigationHandoffFrame.magic,
        try cursor.readUInt16() == InvestigationHandoffFrame.version,
        let kind = InvestigationHandoffFrameKind(
            rawValue: try cursor.readUInt16()
        )
    else {
        throw InvestigationHandoffContractError.invalidEncoding
    }
    let payloadLength = try cursor.readUInt32()
    guard
        let payloadByteCount = Int(exactly: payloadLength),
        kind.admitsPayloadByteCount(payloadByteCount),
        try cursor.readUInt32() == kind.sequence
    else {
        throw InvestigationHandoffContractError.invalidEncoding
    }
    return InvestigationHandoffFrame.headerByteCount + payloadByteCount
}
