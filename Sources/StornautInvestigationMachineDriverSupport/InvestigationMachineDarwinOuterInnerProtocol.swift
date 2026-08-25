import Foundation
import StornautInvestigationHandoffContract

package enum InvestigationMachineDarwinOuterInnerProtocolError:
    Error, Sendable, Equatable
{
    case invalidValue
    case invalidEncoding
    case invalidState
    case terminalEvidenceInvalid
}

package struct InvestigationMachineSingleEpochAdmittedPhysicalResult:
    Sendable, Equatable
{
    package let helperIdentity: InvestigationMachineProcessIdentity
    package let bindingSHA256: InvestigationHandoffSHA256
    package let mode: InvestigationMachineOuterContainmentMode
    fileprivate let selection: InvestigationMachineFixedEpochSelection
    fileprivate let predecessorSHA256: InvestigationHandoffSHA256
    fileprivate let terminalProofSHA256: InvestigationHandoffSHA256
    fileprivate let admissionOwner: UUID

    fileprivate init(
        helperIdentity: InvestigationMachineProcessIdentity,
        bindingSHA256: InvestigationHandoffSHA256,
        mode: InvestigationMachineOuterContainmentMode,
        selection: InvestigationMachineFixedEpochSelection,
        predecessorSHA256: InvestigationHandoffSHA256,
        terminalProofSHA256: InvestigationHandoffSHA256,
        admissionOwner: UUID
    ) {
        self.helperIdentity = helperIdentity
        self.bindingSHA256 = bindingSHA256
        self.mode = mode
        self.selection = selection
        self.predecessorSHA256 = predecessorSHA256
        self.terminalProofSHA256 = terminalProofSHA256
        self.admissionOwner = admissionOwner
    }

    func isBound(
        to expectedSelection: InvestigationMachineFixedEpochSelection
    ) -> Bool {
        selection == expectedSelection
            && mode == protocolMode(for: expectedSelection.epoch.scenario)
            && helperIdentity.role == .helper
            && protocolNonzero(bindingSHA256)
            && protocolNonzero(predecessorSHA256)
            && protocolNonzero(terminalProofSHA256)
    }

    func isBound(
        to expectedSelection: InvestigationMachineFixedEpochSelection,
        predecessor: InvestigationMachineHelperEpochPredecessor
    ) -> Bool {
        isBound(to: expectedSelection)
            && predecessorSHA256 == predecessor.continuitySHA256
    }

    func isBound(
        to expectedSelection: InvestigationMachineFixedEpochSelection,
        predecessor: InvestigationMachineHelperEpochPredecessor,
        admissionOwner expectedOwner: UUID,
        terminalProofSHA256 expectedTerminalProof: InvestigationHandoffSHA256
    ) -> Bool {
        isBound(to: expectedSelection, predecessor: predecessor)
            && admissionOwner == expectedOwner
            && terminalProofSHA256 == expectedTerminalProof
    }
}

package struct InvestigationMachineDarwinEpochRequest: Sendable, Equatable {
    private static let domain =
        "stornaut.task39.machine.outer-inner.epoch-request"
    private static let maximumByteCount = 128 * 1_024

    package let invocation: InvestigationMachineSingleEpochInvocation
    package let epochDeadlineNanoseconds: UInt64
    package let mode: InvestigationMachineOuterContainmentMode

    package init(
        invocation: InvestigationMachineSingleEpochInvocation,
        epochDeadlineNanoseconds: UInt64
    ) throws {
        guard epochDeadlineNanoseconds > 0 else { throw protocolInvalidValue() }
        self.invocation = invocation
        self.epochDeadlineNanoseconds = epochDeadlineNanoseconds
        mode = protocolMode(for: invocation.selection.epoch.scenario)
    }

    package func encoded() throws -> Data {
        let invocationBytes = try invocation.encoded()
        return try HandoffBinaryTranscript.encode(
            domain: Self.domain,
            businessFields: [
                invocationBytes,
                InvestigationHandoffSHA256.hashing(invocationBytes).rawBytes,
                protocolData(epochDeadlineNanoseconds),
                Data([mode.rawValue]),
            ],
            maximumByteCount: Self.maximumByteCount
        )
    }

    package static func decode(
        _ data: Data,
        expectedSelection: InvestigationMachineFixedEpochSelection
    ) throws -> Self {
        let value = try decodeUntrusted(data)
        guard value.invocation.selection == expectedSelection else {
            throw protocolInvalidEncoding()
        }
        return value
    }

    package static func decodeUntrusted(_ data: Data) throws -> Self {
        let fields = try protocolDecode(
            data, domain: domain, ranges: [
                1...(96 * 1_024), 32...32, 8...8, 1...1,
            ], maximum: maximumByteCount
        )
        let invocation = try InvestigationMachineSingleEpochInvocation
            .decodeUntrusted(fields[0])
        let selection = invocation.selection
        guard
            InvestigationHandoffSHA256.hashing(fields[0]).rawBytes == fields[1],
            let mode = InvestigationMachineOuterContainmentMode(
                rawValue: fields[3][fields[3].startIndex]
            ),
            mode == protocolMode(for: selection.epoch.scenario)
        else { throw protocolInvalidEncoding() }
        let value = try Self(
            invocation: invocation,
            epochDeadlineNanoseconds: try protocolUInt64(fields[2])
        )
        guard try value.encoded() == data else { throw protocolInvalidEncoding() }
        return value
    }

    fileprivate func isBound(
        to selection: InvestigationMachineFixedEpochSelection
    ) -> Bool {
        invocation.selection == selection
            && mode == protocolMode(for: selection.epoch.scenario)
            && epochDeadlineNanoseconds > 0
    }

    fileprivate func digest() throws -> InvestigationHandoffSHA256 {
        .hashing(try encoded())
    }
}

package struct InvestigationMachineDarwinDriverChildIdentity:
    Sendable, Equatable
{
    private static let domain =
        "stornaut.task39.machine.outer-inner.driver-child"
    private static let maximumByteCount = 1_024

    package let processID: UInt32
    package let processIDVersion: UInt32
    package let parentProcessID: UInt32
    package let processGroupID: UInt32
    package let auditSessionID: UInt32
    package let effectiveUserID: UInt32
    package let auditTokenWords: [UInt32]

    package init(
        processID: UInt32, processIDVersion: UInt32, parentProcessID: UInt32,
        processGroupID: UInt32, auditSessionID: UInt32,
        effectiveUserID: UInt32, auditTokenWords: [UInt32]
    ) throws {
        guard
            processID > 1, processIDVersion > 0, parentProcessID > 1,
            processGroupID == processID, auditSessionID > 0,
            effectiveUserID == 0, auditTokenWords.count == 8,
            auditTokenWords[1] == effectiveUserID,
            auditTokenWords[5] == processID,
            auditTokenWords[6] == auditSessionID,
            auditTokenWords[7] == processIDVersion
        else { throw protocolInvalidValue() }
        self.processID = processID
        self.processIDVersion = processIDVersion
        self.parentProcessID = parentProcessID
        self.processGroupID = processGroupID
        self.auditSessionID = auditSessionID
        self.effectiveUserID = effectiveUserID
        self.auditTokenWords = auditTokenWords
    }

    package func encoded() throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: Self.domain,
            businessFields: [
                protocolData(processID), protocolData(processIDVersion),
                protocolData(parentProcessID), protocolData(processGroupID),
                protocolData(auditSessionID), protocolData(effectiveUserID),
                protocolWords(auditTokenWords),
            ], maximumByteCount: Self.maximumByteCount
        )
    }

    package static func decode(_ data: Data) throws -> Self {
        let fields = try protocolDecode(
            data, domain: domain,
            ranges: [4...4, 4...4, 4...4, 4...4, 4...4, 4...4, 32...32],
            maximum: maximumByteCount
        )
        let value = try Self(
            processID: try protocolUInt32(fields[0]),
            processIDVersion: try protocolUInt32(fields[1]),
            parentProcessID: try protocolUInt32(fields[2]),
            processGroupID: try protocolUInt32(fields[3]),
            auditSessionID: try protocolUInt32(fields[4]),
            effectiveUserID: try protocolUInt32(fields[5]),
            auditTokenWords: try protocolWords(fields[6])
        )
        guard try value.encoded() == data else { throw protocolInvalidEncoding() }
        return value
    }
}

package struct InvestigationMachineDarwinAppChildIdentity:
    Sendable, Equatable
{
    private static let domain =
        "stornaut.task39.machine.outer-inner.app-child"
    private static let maximumByteCount = 2_048

    package let identity: InvestigationMachineProcessIdentity
    package let parentProcessID: UInt32
    package let processGroupID: UInt32

    package init(
        identity: InvestigationMachineProcessIdentity,
        parentProcessID: UInt32, processGroupID: UInt32
    ) throws {
        guard
            identity.role == .app, parentProcessID > 1, processGroupID > 1
        else { throw protocolInvalidValue() }
        self.identity = identity
        self.parentProcessID = parentProcessID
        self.processGroupID = processGroupID
    }

    package func encoded() throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: Self.domain, businessFields: [
                try identity.encoded(), protocolData(parentProcessID),
                protocolData(processGroupID),
            ], maximumByteCount: Self.maximumByteCount
        )
    }

    package static func decode(_ data: Data) throws -> Self {
        let fields = try protocolDecode(
            data, domain: domain, ranges: [
                1...InvestigationMachineProcessIdentity.maximumByteCount,
                4...4, 4...4,
            ], maximum: maximumByteCount
        )
        let identity = try InvestigationMachineProcessIdentity.decode(fields[0])
        guard try identity.encoded() == fields[0] else {
            throw protocolInvalidEncoding()
        }
        let value = try Self(
            identity: identity, parentProcessID: try protocolUInt32(fields[1]),
            processGroupID: try protocolUInt32(fields[2])
        )
        guard try value.encoded() == data else { throw protocolInvalidEncoding() }
        return value
    }
}

package struct InvestigationMachineDarwinEpochOwnershipRecord:
    Sendable, Equatable
{
    private static let domain =
        "stornaut.task39.machine.outer-inner.ownership-record"
    private static let maximumByteCount = 16 * 1_024

    package let requestSHA256: InvestigationHandoffSHA256
    package let driverChild: InvestigationMachineDarwinDriverChildIdentity
    package let appChild: InvestigationMachineDarwinAppChildIdentity
    fileprivate let physicalOwnershipBytes: Data
    package let physicalOwnershipSHA256: InvestigationHandoffSHA256

    package init(
        request: InvestigationMachineDarwinEpochRequest,
        driverChild: InvestigationMachineDarwinDriverChildIdentity,
        appChild: InvestigationMachineDarwinAppChildIdentity,
        physicalOwnership: InvestigationMachineSingleEpochPhysicalOwnership
    ) throws {
        guard
            physicalOwnership.isBound(to: request.invocation.selection),
            physicalOwnership.mode == request.mode,
            physicalOwnership.epochDeadlineNanoseconds
                == request.epochDeadlineNanoseconds,
            physicalOwnership.appIdentity == appChild.identity,
            appChild.parentProcessID == driverChild.processID,
            appChild.processGroupID == driverChild.processGroupID
        else { throw protocolInvalidValue() }
        requestSHA256 = try request.digest()
        self.driverChild = driverChild
        self.appChild = appChild
        physicalOwnershipBytes = try physicalOwnership.encoded()
        physicalOwnershipSHA256 = .hashing(physicalOwnershipBytes)
    }

    private init(
        requestSHA256: InvestigationHandoffSHA256,
        driverChild: InvestigationMachineDarwinDriverChildIdentity,
        appChild: InvestigationMachineDarwinAppChildIdentity,
        physicalOwnershipBytes: Data,
        physicalOwnershipSHA256: InvestigationHandoffSHA256
    ) {
        self.requestSHA256 = requestSHA256
        self.driverChild = driverChild
        self.appChild = appChild
        self.physicalOwnershipBytes = physicalOwnershipBytes
        self.physicalOwnershipSHA256 = physicalOwnershipSHA256
    }

    package func encoded() throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: Self.domain, businessFields: [
                requestSHA256.rawBytes, try driverChild.encoded(),
                try appChild.encoded(), physicalOwnershipBytes,
                physicalOwnershipSHA256.rawBytes,
            ], maximumByteCount: Self.maximumByteCount
        )
    }

    package static func decode(_ data: Data) throws -> Self {
        let fields = try protocolDecode(
            data, domain: domain, ranges: [
                32...32, 1...1_024, 1...2_048, 1...8_192, 32...32,
            ], maximum: maximumByteCount
        )
        let requestDigest = try protocolDigest(fields[0])
        let driver = try InvestigationMachineDarwinDriverChildIdentity
            .decode(fields[1])
        let app = try InvestigationMachineDarwinAppChildIdentity.decode(fields[2])
        let ownershipDigest = try protocolDigest(fields[4])
        guard
            protocolNonzero(requestDigest),
            ownershipDigest == .hashing(fields[3]),
            app.parentProcessID == driver.processID,
            app.processGroupID == driver.processGroupID
        else { throw protocolInvalidEncoding() }
        let value = Self(
            requestSHA256: requestDigest, driverChild: driver, appChild: app,
            physicalOwnershipBytes: fields[3],
            physicalOwnershipSHA256: ownershipDigest
        )
        guard try value.encoded() == data else { throw protocolInvalidEncoding() }
        return value
    }

    package func physicalOwnership(
        expectedSelection: InvestigationMachineFixedEpochSelection
    ) throws -> InvestigationMachineSingleEpochPhysicalOwnership {
        let value = try InvestigationMachineSingleEpochPhysicalOwnership.decode(
            physicalOwnershipBytes, expectedSelection: expectedSelection
        )
        guard physicalOwnershipSHA256 == .hashing(physicalOwnershipBytes) else {
            throw protocolInvalidValue()
        }
        return value
    }

    fileprivate func digest() throws -> InvestigationHandoffSHA256 {
        .hashing(try encoded())
    }
}

package struct InvestigationMachineDarwinEpochAcknowledgement:
    Sendable, Equatable
{
    private static let domain =
        "stornaut.task39.machine.outer-inner.acknowledgement"
    private static let maximumByteCount = 512

    package let requestSHA256: InvestigationHandoffSHA256
    package let ownershipSHA256: InvestigationHandoffSHA256
    package let physicalOwnershipSHA256: InvestigationHandoffSHA256

    package init(
        request: InvestigationMachineDarwinEpochRequest,
        ownership: InvestigationMachineDarwinEpochOwnershipRecord
    ) throws {
        let requestDigest = try request.digest()
        guard ownership.requestSHA256 == requestDigest else {
            throw protocolInvalidValue()
        }
        requestSHA256 = requestDigest
        ownershipSHA256 = try ownership.digest()
        physicalOwnershipSHA256 = ownership.physicalOwnershipSHA256
    }

    private init(
        requestSHA256: InvestigationHandoffSHA256,
        ownershipSHA256: InvestigationHandoffSHA256,
        physicalOwnershipSHA256: InvestigationHandoffSHA256
    ) throws {
        guard
            protocolNonzero(requestSHA256), protocolNonzero(ownershipSHA256),
            protocolNonzero(physicalOwnershipSHA256)
        else { throw protocolInvalidValue() }
        self.requestSHA256 = requestSHA256
        self.ownershipSHA256 = ownershipSHA256
        self.physicalOwnershipSHA256 = physicalOwnershipSHA256
    }

    package func encoded() throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: Self.domain, businessFields: [
                requestSHA256.rawBytes, ownershipSHA256.rawBytes,
                physicalOwnershipSHA256.rawBytes,
            ], maximumByteCount: Self.maximumByteCount
        )
    }

    package static func decode(_ data: Data) throws -> Self {
        let fields = try protocolDecode(
            data, domain: domain, ranges: [32...32, 32...32, 32...32],
            maximum: maximumByteCount
        )
        let value = try Self(
            requestSHA256: protocolDigest(fields[0]),
            ownershipSHA256: protocolDigest(fields[1]),
            physicalOwnershipSHA256: protocolDigest(fields[2])
        )
        guard try value.encoded() == data else { throw protocolInvalidEncoding() }
        return value
    }

    fileprivate func digest() throws -> InvestigationHandoffSHA256 {
        .hashing(try encoded())
    }
}

package enum InvestigationMachineDarwinEpochDecisionKind:
    UInt8, Sendable, Equatable
{
    case `continue` = 0x01
    case crashNow = 0x02
}

package struct InvestigationMachineDarwinEpochDecision: Sendable, Equatable {
    private static let domain =
        "stornaut.task39.machine.outer-inner.decision"
    private static let maximumByteCount = 512

    package let requestSHA256: InvestigationHandoffSHA256
    package let ownershipSHA256: InvestigationHandoffSHA256
    package let acknowledgementSHA256: InvestigationHandoffSHA256
    package let kind: InvestigationMachineDarwinEpochDecisionKind

    package init(
        request: InvestigationMachineDarwinEpochRequest,
        ownership: InvestigationMachineDarwinEpochOwnershipRecord,
        acknowledgement: InvestigationMachineDarwinEpochAcknowledgement
    ) throws {
        let requestDigest = try request.digest()
        let ownershipDigest = try ownership.digest()
        guard
            ownership.requestSHA256 == requestDigest,
            acknowledgement.requestSHA256 == requestDigest,
            acknowledgement.ownershipSHA256 == ownershipDigest,
            acknowledgement.physicalOwnershipSHA256
                == ownership.physicalOwnershipSHA256
        else { throw protocolInvalidValue() }
        requestSHA256 = requestDigest
        ownershipSHA256 = ownershipDigest
        acknowledgementSHA256 = try acknowledgement.digest()
        kind = request.mode == .normal ? .continue : .crashNow
    }

    private init(
        requestSHA256: InvestigationHandoffSHA256,
        ownershipSHA256: InvestigationHandoffSHA256,
        acknowledgementSHA256: InvestigationHandoffSHA256,
        kind: InvestigationMachineDarwinEpochDecisionKind
    ) throws {
        guard
            protocolNonzero(requestSHA256), protocolNonzero(ownershipSHA256),
            protocolNonzero(acknowledgementSHA256)
        else { throw protocolInvalidValue() }
        self.requestSHA256 = requestSHA256
        self.ownershipSHA256 = ownershipSHA256
        self.acknowledgementSHA256 = acknowledgementSHA256
        self.kind = kind
    }

    package func encoded() throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: Self.domain, businessFields: [
                requestSHA256.rawBytes, ownershipSHA256.rawBytes,
                acknowledgementSHA256.rawBytes, Data([kind.rawValue]),
            ], maximumByteCount: Self.maximumByteCount
        )
    }

    package static func decode(_ data: Data) throws -> Self {
        let fields = try protocolDecode(
            data, domain: domain,
            ranges: [32...32, 32...32, 32...32, 1...1],
            maximum: maximumByteCount
        )
        guard let kind = InvestigationMachineDarwinEpochDecisionKind(
            rawValue: fields[3][fields[3].startIndex]
        ) else { throw protocolInvalidEncoding() }
        let value = try Self(
            requestSHA256: protocolDigest(fields[0]),
            ownershipSHA256: protocolDigest(fields[1]),
            acknowledgementSHA256: protocolDigest(fields[2]), kind: kind
        )
        guard try value.encoded() == data else { throw protocolInvalidEncoding() }
        return value
    }

    fileprivate func digest() throws -> InvestigationHandoffSHA256 {
        .hashing(try encoded())
    }
}

package struct InvestigationMachineDarwinEpochNormalResult:
    Sendable, Equatable
{
    private static let domain =
        "stornaut.task39.machine.outer-inner.normal-result"
    private static let maximumByteCount = 16 * 1_024

    package let requestSHA256: InvestigationHandoffSHA256
    package let ownershipSHA256: InvestigationHandoffSHA256
    package let acknowledgementSHA256: InvestigationHandoffSHA256
    package let decisionSHA256: InvestigationHandoffSHA256
    package let physicalResult: InvestigationMachineSingleEpochPhysicalResult

    package init(
        request: InvestigationMachineDarwinEpochRequest,
        ownership: InvestigationMachineDarwinEpochOwnershipRecord,
        acknowledgement: InvestigationMachineDarwinEpochAcknowledgement,
        decision: InvestigationMachineDarwinEpochDecision,
        physicalResult: InvestigationMachineSingleEpochPhysicalResult
    ) throws {
        guard
            request.mode == .normal, decision.kind == .continue,
            physicalResult.mode == .normal,
            try physicalResult.physicalOwnership.encoded()
                == ownership.physicalOwnershipBytes
        else { throw protocolInvalidValue() }
        try Self.validateChain(
            request: request, ownership: ownership,
            acknowledgement: acknowledgement, decision: decision
        )
        requestSHA256 = try request.digest()
        ownershipSHA256 = try ownership.digest()
        acknowledgementSHA256 = try acknowledgement.digest()
        decisionSHA256 = try decision.digest()
        self.physicalResult = physicalResult
    }

    private init(
        requestSHA256: InvestigationHandoffSHA256,
        ownershipSHA256: InvestigationHandoffSHA256,
        acknowledgementSHA256: InvestigationHandoffSHA256,
        decisionSHA256: InvestigationHandoffSHA256,
        physicalResult: InvestigationMachineSingleEpochPhysicalResult
    ) {
        self.requestSHA256 = requestSHA256
        self.ownershipSHA256 = ownershipSHA256
        self.acknowledgementSHA256 = acknowledgementSHA256
        self.decisionSHA256 = decisionSHA256
        self.physicalResult = physicalResult
    }

    package func encoded() throws -> Data {
        let physicalBytes = try physicalResult.encoded()
        return try HandoffBinaryTranscript.encode(
            domain: Self.domain, businessFields: [
                requestSHA256.rawBytes, ownershipSHA256.rawBytes,
                acknowledgementSHA256.rawBytes, decisionSHA256.rawBytes,
                physicalBytes,
                InvestigationHandoffSHA256.hashing(physicalBytes).rawBytes,
            ], maximumByteCount: Self.maximumByteCount
        )
    }

    package static func decode(
        _ data: Data,
        expectedSelection: InvestigationMachineFixedEpochSelection
    ) throws -> Self {
        let fields = try protocolDecode(
            data, domain: domain, ranges: [
                32...32, 32...32, 32...32, 32...32,
                1...12_288, 32...32,
            ], maximum: maximumByteCount
        )
        let physical = try InvestigationMachineSingleEpochPhysicalResult.decode(
            fields[4], expectedSelection: expectedSelection
        )
        guard
            physical.mode == .normal,
            InvestigationHandoffSHA256.hashing(fields[4]).rawBytes == fields[5]
        else { throw protocolInvalidEncoding() }
        let value = Self(
            requestSHA256: try protocolDigest(fields[0]),
            ownershipSHA256: try protocolDigest(fields[1]),
            acknowledgementSHA256: try protocolDigest(fields[2]),
            decisionSHA256: try protocolDigest(fields[3]),
            physicalResult: physical
        )
        guard try value.encoded() == data else { throw protocolInvalidEncoding() }
        return value
    }

    fileprivate static func fromInner(
        request: InvestigationMachineDarwinEpochRequest,
        ownership: InvestigationMachineDarwinEpochOwnershipRecord,
        acknowledgement: InvestigationMachineDarwinEpochAcknowledgement,
        decision: InvestigationMachineDarwinEpochDecision,
        physicalResult: InvestigationMachineSingleEpochPhysicalResult
    ) throws -> Self {
        guard
            request.mode == .normal, decision.kind == .continue,
            acknowledgement.requestSHA256 == (try request.digest()),
            acknowledgement.ownershipSHA256 == (try ownership.digest()),
            acknowledgement.physicalOwnershipSHA256
                == .hashing(try physicalResult.physicalOwnership.encoded()),
            decision.requestSHA256 == acknowledgement.requestSHA256,
            decision.ownershipSHA256 == acknowledgement.ownershipSHA256,
            decision.acknowledgementSHA256 == (try acknowledgement.digest()),
            physicalResult.mode == .normal
        else { throw protocolInvalidValue() }
        try validateChain(
            request: request, ownership: ownership,
            acknowledgement: acknowledgement, decision: decision
        )
        return Self(
            requestSHA256: try request.digest(),
            ownershipSHA256: acknowledgement.ownershipSHA256,
            acknowledgementSHA256: try acknowledgement.digest(),
            decisionSHA256: try decision.digest(),
            physicalResult: physicalResult
        )
    }

    private static func validateChain(
        request: InvestigationMachineDarwinEpochRequest,
        ownership: InvestigationMachineDarwinEpochOwnershipRecord,
        acknowledgement: InvestigationMachineDarwinEpochAcknowledgement,
        decision: InvestigationMachineDarwinEpochDecision
    ) throws {
        let requestDigest = try request.digest()
        let ownershipDigest = try ownership.digest()
        guard
            ownership.requestSHA256 == requestDigest,
            acknowledgement.requestSHA256 == requestDigest,
            acknowledgement.ownershipSHA256 == ownershipDigest,
            acknowledgement.physicalOwnershipSHA256
                == ownership.physicalOwnershipSHA256,
            decision.requestSHA256 == requestDigest,
            decision.ownershipSHA256 == ownershipDigest,
            decision.acknowledgementSHA256 == (try acknowledgement.digest())
        else { throw protocolInvalidValue() }
    }
}

package struct InvestigationMachineDarwinEpochTerminalEvidence:
    Sendable, Equatable
{
    package let controlEOFObserved: Bool
    package let resultEOFObserved: Bool
    package let driverChild: InvestigationMachineDarwinDriverChildIdentity
    package let appChild: InvestigationMachineDarwinAppChildIdentity
    package let helperIdentity: InvestigationMachineProcessIdentity
    package let innerExitedSuccessfully: Bool
    package let appAbsent: Bool
    package let groupLeaderReapedLast: Bool
    package let postReapGroupEmpty: Bool
    package let helperAbsent: Bool
    package let l1ResidueAbsent: Bool
    package let initialDriverObservationSHA256: InvestigationHandoffSHA256
    package let finalDriverObservationSHA256: InvestigationHandoffSHA256
    package let observedAtNanoseconds: UInt64

    package init(
        controlEOFObserved: Bool, resultEOFObserved: Bool,
        driverChild: InvestigationMachineDarwinDriverChildIdentity,
        appChild: InvestigationMachineDarwinAppChildIdentity,
        helperIdentity: InvestigationMachineProcessIdentity,
        innerExitedSuccessfully: Bool, appAbsent: Bool,
        groupLeaderReapedLast: Bool, postReapGroupEmpty: Bool,
        helperAbsent: Bool, l1ResidueAbsent: Bool,
        initialDriverObservationSHA256: InvestigationHandoffSHA256,
        finalDriverObservationSHA256: InvestigationHandoffSHA256,
        observedAtNanoseconds: UInt64
    ) throws {
        guard
            helperIdentity.role == .helper,
            protocolNonzero(initialDriverObservationSHA256),
            protocolNonzero(finalDriverObservationSHA256),
            observedAtNanoseconds > 0
        else { throw protocolInvalidValue() }
        self.controlEOFObserved = controlEOFObserved
        self.resultEOFObserved = resultEOFObserved
        self.driverChild = driverChild
        self.appChild = appChild
        self.helperIdentity = helperIdentity
        self.innerExitedSuccessfully = innerExitedSuccessfully
        self.appAbsent = appAbsent
        self.groupLeaderReapedLast = groupLeaderReapedLast
        self.postReapGroupEmpty = postReapGroupEmpty
        self.helperAbsent = helperAbsent
        self.l1ResidueAbsent = l1ResidueAbsent
        self.initialDriverObservationSHA256 = initialDriverObservationSHA256
        self.finalDriverObservationSHA256 = finalDriverObservationSHA256
        self.observedAtNanoseconds = observedAtNanoseconds
    }

    fileprivate func digest() throws -> InvestigationHandoffSHA256 {
        .hashing(try HandoffBinaryTranscript.encode(
            domain: "stornaut.task39.machine.outer-inner.terminal-evidence",
            businessFields: [
                protocolBool(controlEOFObserved), protocolBool(resultEOFObserved),
                try driverChild.encoded(), try appChild.encoded(),
                try helperIdentity.encoded(),
                protocolBool(innerExitedSuccessfully),
                protocolBool(appAbsent), protocolBool(groupLeaderReapedLast),
                protocolBool(postReapGroupEmpty), protocolBool(helperAbsent),
                protocolBool(l1ResidueAbsent),
                initialDriverObservationSHA256.rawBytes,
                finalDriverObservationSHA256.rawBytes,
                protocolData(observedAtNanoseconds),
            ], maximumByteCount: 2_048
        ))
    }
}

package actor InvestigationMachineDarwinInnerProtocolState {
    private static let maximumEpochWindowNanoseconds: UInt64 = 140_000_000_000
    private enum State {
        case ready
        case requested(InvestigationMachineDarwinEpochRequest)
        case ownership(
            InvestigationMachineDarwinEpochRequest,
            InvestigationMachineDarwinEpochOwnershipRecord,
            InvestigationMachineSingleEpochPhysicalOwnership
        )
        case acknowledged(
            InvestigationMachineDarwinEpochRequest,
            InvestigationMachineDarwinEpochOwnershipRecord,
            InvestigationMachineSingleEpochPhysicalOwnership,
            InvestigationMachineDarwinEpochAcknowledgement
        )
        case decided(
            InvestigationMachineDarwinEpochRequest,
            InvestigationMachineDarwinEpochOwnershipRecord,
            InvestigationMachineSingleEpochPhysicalOwnership,
            InvestigationMachineDarwinEpochAcknowledgement,
            InvestigationMachineDarwinEpochDecision
        )
        case terminal
    }

    private let selection: InvestigationMachineFixedEpochSelection
    private var state: State = .ready

    package init(selection: InvestigationMachineFixedEpochSelection) {
        self.selection = selection
    }

    func run(
        composer: any InvestigationMachinePhysicalSingleEpochComposing,
        request: InvestigationMachineDarwinEpochRequest,
        observedAtNanoseconds: UInt64
    ) async throws -> InvestigationMachineSingleEpochResult {
        try accept(request, observedAtNanoseconds: observedAtNanoseconds)
        guard composer.isBound(to: selection) else {
            return try failValue()
        }
        do {
            let result = try await composer.run(
                invocation: request.invocation,
                epochDeadlineNanoseconds: request.epochDeadlineNanoseconds
            )
            guard
                case let .decided(
                    activeRequest, _, _, _, activeDecision
                ) = state,
                activeRequest == request, activeDecision.kind == .continue,
                !Task.isCancelled
            else { return try failState() }
            return result
        } catch {
            state = .terminal
            throw error
        }
    }

    package func accept(
        _ request: InvestigationMachineDarwinEpochRequest,
        observedAtNanoseconds: UInt64
    ) throws {
        guard case .ready = state, !Task.isCancelled else {
            return try failState()
        }
        let maximum = observedAtNanoseconds.addingReportingOverflow(
            Self.maximumEpochWindowNanoseconds
        )
        guard
            request.isBound(to: selection), !maximum.overflow,
            request.epochDeadlineNanoseconds > observedAtNanoseconds,
            request.epochDeadlineNanoseconds <= maximum.partialValue
        else { return try failValue() }
        state = .requested(request)
    }

    package func emit(
        _ ownership: InvestigationMachineDarwinEpochOwnershipRecord
    ) throws -> InvestigationMachineDarwinEpochOwnershipRecord {
        guard case let .requested(request) = state, !Task.isCancelled else {
            return try failState()
        }
        let physical: InvestigationMachineSingleEpochPhysicalOwnership
        do {
            physical = try .decode(
                ownership.physicalOwnershipBytes,
                expectedSelection: selection
            )
        } catch { return try failValue() }
        guard
            ownership.requestSHA256 == (try request.digest()),
            ownership.physicalOwnershipSHA256
                == .hashing(ownership.physicalOwnershipBytes),
            physical.isBound(to: selection), physical.mode == request.mode,
            physical.epochDeadlineNanoseconds
                == request.epochDeadlineNanoseconds
        else { return try failValue() }
        state = .ownership(request, ownership, physical)
        return ownership
    }

    package func accept(
        _ acknowledgement: InvestigationMachineDarwinEpochAcknowledgement
    ) throws {
        guard
            case let .ownership(request, ownership, physical) = state,
            !Task.isCancelled
        else { return try failState() }
        guard
            acknowledgement.requestSHA256 == (try request.digest()),
            acknowledgement.ownershipSHA256 == (try ownership.digest()),
            acknowledgement.physicalOwnershipSHA256
                == .hashing(try physical.encoded())
        else { return try failValue() }
        state = .acknowledged(
            request, ownership, physical, acknowledgement
        )
    }

    package func accept(
        _ decision: InvestigationMachineDarwinEpochDecision
    ) throws {
        guard
            case let .acknowledged(
                request, ownership, physical, acknowledgement
            ) = state,
            !Task.isCancelled
        else { return try failState() }
        let expectedKind: InvestigationMachineDarwinEpochDecisionKind =
            request.mode == .normal ? .continue : .crashNow
        guard
            decision.requestSHA256 == (try request.digest()),
            decision.ownershipSHA256 == (try ownership.digest()),
            decision.acknowledgementSHA256 == (try acknowledgement.digest()),
            decision.kind == expectedKind
        else { return try failValue() }
        state = .decided(
            request, ownership, physical, acknowledgement, decision
        )
    }

    package func finish(
        _ physicalResult: InvestigationMachineSingleEpochPhysicalResult
    ) throws -> InvestigationMachineDarwinEpochNormalResult {
        guard
            case let .decided(
                request, ownership, physical, acknowledgement, decision
            ) = state,
            !Task.isCancelled
        else { return try failState() }
        guard
            request.mode == .normal, decision.kind == .continue,
            physicalResult.physicalOwnership == physical
        else { return try failValue() }
        let result = try InvestigationMachineDarwinEpochNormalResult.fromInner(
            request: request, ownership: ownership,
            acknowledgement: acknowledgement, decision: decision,
            physicalResult: physicalResult
        )
        state = .terminal
        return result
    }

    private func failState<T>() throws -> T {
        state = .terminal
        throw InvestigationMachineDarwinOuterInnerProtocolError.invalidState
    }

    private func failValue<T>() throws -> T {
        state = .terminal
        throw InvestigationMachineDarwinOuterInnerProtocolError.invalidValue
    }
}

package actor InvestigationMachineDarwinOuterAdmission:
    InvestigationMachineOuterContainmentProving
{
    private static let maximumAdmissionByteCount = 192 * 1_024
    private struct Exchange: Sendable {
        let request: InvestigationMachineDarwinEpochRequest
        let ownership: InvestigationMachineDarwinEpochOwnershipRecord
        let physicalOwnership: InvestigationMachineSingleEpochPhysicalOwnership
        let driverChild: InvestigationMachineDarwinDriverChildIdentity
        let appChild: InvestigationMachineDarwinAppChildIdentity
        let acknowledgement: InvestigationMachineDarwinEpochAcknowledgement
        let decision: InvestigationMachineDarwinEpochDecision?
    }
    private enum State {
        case ready
        case requested(InvestigationMachineDarwinEpochRequest)
        case acknowledged(Exchange)
        case decided(Exchange)
        case admitted(InvestigationMachineSingleEpochResult)
        case terminal
    }

    private let selection: InvestigationMachineFixedEpochSelection
    private let outerProcessID: UInt32
    private let clock: any InvestigationMachineDarwinOuterInnerCompositionClocking
    private let owner = UUID()
    private var state: State = .ready

    package init(
        selection: InvestigationMachineFixedEpochSelection,
        outerProcessID: UInt32
    ) {
        self.init(
            selection: selection, outerProcessID: outerProcessID,
            clock: InvestigationMachineDarwinCompositionClock()
        )
    }

    init(
        selection: InvestigationMachineFixedEpochSelection,
        outerProcessID: UInt32,
        clock: any InvestigationMachineDarwinOuterInnerCompositionClocking
    ) {
        self.selection = selection
        self.outerProcessID = outerProcessID
        self.clock = clock
    }

    package func accept(
        _ request: InvestigationMachineDarwinEpochRequest
    ) throws {
        guard case .ready = state, !Task.isCancelled else {
            return try failState()
        }
        guard outerProcessID > 1, request.isBound(to: selection) else {
            return try failValue()
        }
        state = .requested(request)
    }

    package func acceptOwnership(
        _ ownership: InvestigationMachineDarwinEpochOwnershipRecord,
        observedDriverChild: InvestigationMachineDarwinDriverChildIdentity,
        observedAppChild: InvestigationMachineDarwinAppChildIdentity
    ) throws -> InvestigationMachineDarwinEpochAcknowledgement {
        guard case let .requested(request) = state, !Task.isCancelled else {
            return try failState()
        }
        let physical: InvestigationMachineSingleEpochPhysicalOwnership
        do {
            physical = try .decode(
                ownership.physicalOwnershipBytes, expectedSelection: selection
            )
        } catch { return try failValue() }
        guard
            ownership.requestSHA256 == (try request.digest()),
            ownership.physicalOwnershipSHA256
                == .hashing(ownership.physicalOwnershipBytes),
            ownership.driverChild == observedDriverChild,
            ownership.appChild == observedAppChild,
            observedDriverChild.parentProcessID == outerProcessID,
            observedDriverChild.processID == observedDriverChild.processGroupID,
            observedAppChild.parentProcessID == observedDriverChild.processID,
            observedAppChild.processGroupID
                == observedDriverChild.processGroupID,
            observedAppChild.identity == physical.appIdentity,
            physical.mode == request.mode,
            physical.epochDeadlineNanoseconds
                == request.epochDeadlineNanoseconds
        else { return try failValue() }
        let acknowledgement = try InvestigationMachineDarwinEpochAcknowledgement(
            request: request, ownership: ownership
        )
        state = .acknowledged(Exchange(
            request: request, ownership: ownership,
            physicalOwnership: physical, driverChild: observedDriverChild,
            appChild: observedAppChild, acknowledgement: acknowledgement,
            decision: nil
        ))
        return acknowledgement
    }

    package func issueDecision(
        _ acknowledgement: InvestigationMachineDarwinEpochAcknowledgement
    ) throws -> InvestigationMachineDarwinEpochDecision {
        guard case let .acknowledged(exchange) = state, !Task.isCancelled else {
            return try failState()
        }
        guard acknowledgement == exchange.acknowledgement else {
            return try failValue()
        }
        let decision = try InvestigationMachineDarwinEpochDecision(
            request: exchange.request, ownership: exchange.ownership,
            acknowledgement: acknowledgement
        )
        state = .decided(Exchange(
            request: exchange.request, ownership: exchange.ownership,
            physicalOwnership: exchange.physicalOwnership,
            driverChild: exchange.driverChild, appChild: exchange.appChild,
            acknowledgement: acknowledgement, decision: decision
        ))
        return decision
    }

    package func admit(
        resultBytes: Data,
        terminalEvidence: InvestigationMachineDarwinEpochTerminalEvidence
    ) throws -> InvestigationMachineSingleEpochResult {
        guard
            case let .decided(exchange) = state,
            let decision = exchange.decision, !Task.isCancelled
        else { return try failState() }
        state = .terminal
        guard terminalEvidenceIsExact(terminalEvidence, exchange: exchange) else {
            return try failTerminalEvidence()
        }

        let helper: InvestigationMachineProcessIdentity
        let binding: InvestigationHandoffSHA256
        switch exchange.request.mode {
        case .normal:
            guard terminalEvidence.innerExitedSuccessfully else {
                return try failTerminalEvidence()
            }
            let normal: InvestigationMachineDarwinEpochNormalResult
            do {
                normal = try .decode(resultBytes, expectedSelection: selection)
            } catch { return try failValue() }
            guard
                normal.requestSHA256 == (try exchange.request.digest()),
                normal.ownershipSHA256 == (try exchange.ownership.digest()),
                normal.acknowledgementSHA256
                    == (try exchange.acknowledgement.digest()),
                normal.decisionSHA256 == (try decision.digest()),
                normal.physicalResult.physicalOwnership
                    == exchange.physicalOwnership,
                normal.physicalResult.driverObservationSHA256
                    == terminalEvidence.initialDriverObservationSHA256
            else { return try failValue() }
            helper = normal.physicalResult.helperIdentity
            binding = normal.physicalResult.bindingSHA256
        case .parentCrash:
            guard
                resultBytes.isEmpty, !terminalEvidence.innerExitedSuccessfully,
                decision.kind == .crashNow
            else { return try failTerminalEvidence() }
            helper = exchange.physicalOwnership.helperIdentity
            binding = exchange.physicalOwnership.bindingSHA256
        }

        let terminalDigest = try terminalEvidence.digest()
        let admissionDigest: InvestigationHandoffSHA256
        do {
            admissionDigest = try InvestigationHandoffSHA256.hashing(
                HandoffBinaryTranscript.encode(
                domain: "stornaut.task39.machine.outer-inner.admission",
                businessFields: [
                    try exchange.request.encoded(),
                    try exchange.ownership.encoded(),
                    try exchange.acknowledgement.encoded(),
                    try decision.encoded(),
                    InvestigationHandoffSHA256.hashing(resultBytes).rawBytes,
                    terminalDigest.rawBytes, protocolData(owner),
                ], maximumByteCount: Self.maximumAdmissionByteCount
                )
            )
        } catch { return try failValue() }
        let admittedAtNanoseconds: UInt64
        guard !Task.isCancelled else { return try failState() }
        do {
            admittedAtNanoseconds = try clock.continuousNanoseconds()
        } catch {
            return try failTerminalEvidence()
        }
        guard
            !Task.isCancelled,
            admittedAtNanoseconds >= terminalEvidence.observedAtNanoseconds,
            admittedAtNanoseconds < exchange.request.epochDeadlineNanoseconds
        else {
            return try failTerminalEvidence()
        }
        let token = InvestigationMachineSingleEpochAdmittedPhysicalResult(
            helperIdentity: helper, bindingSHA256: binding,
            mode: exchange.request.mode, selection: selection,
            predecessorSHA256: exchange.request.invocation.predecessorSHA256,
            terminalProofSHA256: admissionDigest, admissionOwner: owner
        )
        let result = InvestigationMachineSingleEpochResult.admittedPhysical(token)
        state = .admitted(result)
        return result
    }

    package func proveContainment(
        selection: InvestigationMachineFixedEpochSelection,
        result: InvestigationMachineSingleEpochResult,
        predecessor: InvestigationMachineHelperEpochPredecessor
    ) async -> InvestigationMachineOuterContainmentOutcome {
        guard case let .admitted(expected) = state else {
            state = .terminal
            return .terminalUncertain
        }
        state = .terminal
        guard
            result == expected, selection == self.selection,
            case let .admittedPhysical(token) = result,
            token.admissionOwner == owner, token.selection == selection,
            token.predecessorSHA256 == predecessor.continuitySHA256,
            !Task.isCancelled,
            let proof = try? InvestigationMachineOuterContainmentProof(
                selection: selection, result: result, predecessor: predecessor,
                terminalProofSHA256: token.terminalProofSHA256,
                admittedBy: owner
            )
        else { return .terminalUncertain }
        return .contained(proof)
    }

    private func terminalEvidenceIsExact(
        _ evidence: InvestigationMachineDarwinEpochTerminalEvidence,
        exchange: Exchange
    ) -> Bool {
        evidence.controlEOFObserved
            && evidence.resultEOFObserved
            && evidence.driverChild == exchange.driverChild
            && evidence.appChild == exchange.appChild
            && evidence.helperIdentity
                == exchange.physicalOwnership.helperIdentity
            && evidence.appAbsent
            && evidence.groupLeaderReapedLast
            && evidence.postReapGroupEmpty
            && evidence.helperAbsent
            && evidence.l1ResidueAbsent
            && evidence.initialDriverObservationSHA256
                == evidence.finalDriverObservationSHA256
            && evidence.observedAtNanoseconds
                < exchange.request.epochDeadlineNanoseconds
    }

    private func failState<T>() throws -> T {
        state = .terminal
        throw InvestigationMachineDarwinOuterInnerProtocolError.invalidState
    }

    private func failValue<T>() throws -> T {
        state = .terminal
        throw InvestigationMachineDarwinOuterInnerProtocolError.invalidValue
    }

    private func failTerminalEvidence<T>() throws -> T {
        state = .terminal
        throw InvestigationMachineDarwinOuterInnerProtocolError
            .terminalEvidenceInvalid
    }
}

private func protocolMode(
    for scenario: InvestigationHandoffScenario
) -> InvestigationMachineOuterContainmentMode {
    scenario == .lifecycleRecovery ? .parentCrash : .normal
}

private func protocolInvalidValue()
    -> InvestigationMachineDarwinOuterInnerProtocolError {
    .invalidValue
}

private func protocolInvalidEncoding()
    -> InvestigationMachineDarwinOuterInnerProtocolError {
    .invalidEncoding
}

private func protocolDecode(
    _ data: Data, domain: String, ranges: [ClosedRange<Int>], maximum: Int
) throws -> [Data] {
    do {
        return try HandoffBinaryTranscript.decode(
            data, expectedDomain: domain,
            expectedBusinessFieldByteCounts: ranges, maximumByteCount: maximum
        )
    } catch {
        throw protocolInvalidEncoding()
    }
}

private func protocolNonzero(_ value: InvestigationHandoffSHA256) -> Bool {
    value.rawBytes.contains(where: { $0 != 0 })
}

private func protocolDigest(_ data: Data) throws
    -> InvestigationHandoffSHA256 {
    do { return try InvestigationHandoffSHA256(rawBytes: data) }
    catch { throw protocolInvalidEncoding() }
}

private func protocolData(_ value: UInt32) -> Data {
    Data([
        UInt8(truncatingIfNeeded: value >> 24),
        UInt8(truncatingIfNeeded: value >> 16),
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value),
    ])
}

private func protocolData(_ value: UInt64) -> Data {
    Data([
        UInt8(truncatingIfNeeded: value >> 56),
        UInt8(truncatingIfNeeded: value >> 48),
        UInt8(truncatingIfNeeded: value >> 40),
        UInt8(truncatingIfNeeded: value >> 32),
        UInt8(truncatingIfNeeded: value >> 24),
        UInt8(truncatingIfNeeded: value >> 16),
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value),
    ])
}

private func protocolData(_ value: UUID) -> Data {
    var bytes = value.uuid
    return withUnsafeBytes(of: &bytes) { Data($0) }
}

private func protocolUInt32(_ data: Data) throws -> UInt32 {
    guard data.count == 4 else { throw protocolInvalidEncoding() }
    return data.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
}

private func protocolUInt64(_ data: Data) throws -> UInt64 {
    guard data.count == 8 else { throw protocolInvalidEncoding() }
    return data.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
}

private func protocolWords(_ values: [UInt32]) -> Data {
    values.reduce(into: Data()) { $0.append(protocolData($1)) }
}

private func protocolWords(_ data: Data) throws -> [UInt32] {
    guard data.count == 32 else { throw protocolInvalidEncoding() }
    return try stride(from: 0, to: data.count, by: 4).map { offset in
        try protocolUInt32(data.subdata(in: offset..<(offset + 4)))
    }
}

private func protocolBool(_ value: Bool) -> Data {
    Data([value ? 0x01 : 0x00])
}
