import Foundation
import StornautInvestigationHandoffContract
import StornautInvestigationInstalledL2

package enum InvestigationMachineDarwinOuterInnerProtocolError:
    Error, Sendable, Equatable
{
    case invalidValue
    case invalidEncoding
    case invalidState
    case terminalEvidenceInvalid
}

package struct InvestigationMachineEpochAdmissionMaterial: Sendable, Equatable {
    private static let domain =
        "stornaut.task39.machine.outer-inner.admission-material"
    package static let maximumByteCount = 50 * 1_024
    fileprivate let ownership: InvestigationMachineDarwinEpochOwnershipRecord
    fileprivate let acknowledgement: InvestigationMachineDarwinEpochAcknowledgement
    fileprivate let decision: InvestigationMachineDarwinEpochDecision
    fileprivate let owner: UUID

    package init(
        request: InvestigationMachineDarwinEpochRequest,
        ownership: InvestigationMachineDarwinEpochOwnershipRecord,
        acknowledgement: InvestigationMachineDarwinEpochAcknowledgement,
        decision: InvestigationMachineDarwinEpochDecision, owner: UUID
    ) throws {
        let physical = try ownership.physicalOwnership(
            expectedSelection: request.invocation.selection)
        try Self.validate(request: request, ownership: ownership,
            physicalOwnership: physical, acknowledgement: acknowledgement,
            decision: decision, owner: owner)
        self.ownership = ownership; self.acknowledgement = acknowledgement
        self.decision = decision; self.owner = owner
    }

    package func encoded() throws -> Data {
        try HandoffBinaryTranscript.encode(domain: Self.domain, businessFields: [
            try ownership.encoded(), try acknowledgement.encoded(),
            try decision.encoded(), protocolData(owner),
        ], maximumByteCount: Self.maximumByteCount)
    }

    fileprivate static func decode(
        _ data: Data, request: InvestigationMachineDarwinEpochRequest,
        physicalOwnership: InvestigationMachineSingleEpochPhysicalOwnership
    ) throws -> Self {
        let fields = try protocolDecode(data, domain: domain, ranges: [
            1...(48 * 1_024), 1...512, 1...512, 16...16,
        ], maximum: maximumByteCount)
        let ownership = try InvestigationMachineDarwinEpochOwnershipRecord
            .decode(fields[0])
        let acknowledgement = try InvestigationMachineDarwinEpochAcknowledgement
            .decode(fields[1])
        let decision = try InvestigationMachineDarwinEpochDecision.decode(fields[2])
        let owner = try protocolUUID(fields[3])
        try validate(request: request, ownership: ownership,
            physicalOwnership: physicalOwnership, acknowledgement: acknowledgement,
            decision: decision, owner: owner)
        let value = Self(ownership: ownership, acknowledgement: acknowledgement,
            decision: decision, owner: owner)
        guard try value.encoded() == data else { throw protocolInvalidEncoding() }
        return value
    }

    private init(ownership: InvestigationMachineDarwinEpochOwnershipRecord,
        acknowledgement: InvestigationMachineDarwinEpochAcknowledgement,
        decision: InvestigationMachineDarwinEpochDecision, owner: UUID) {
        self.ownership = ownership; self.acknowledgement = acknowledgement
        self.decision = decision; self.owner = owner
    }

    fileprivate func admissionTranscript(requestBytes: Data, resultBytes: Data,
        terminalEvidenceBytes: Data) throws -> Data {
        try HandoffBinaryTranscript.encode(domain:
            "stornaut.task39.machine.outer-inner.admission", businessFields: [
            requestBytes, try ownership.encoded(), try acknowledgement.encoded(),
            try decision.encoded(),
            InvestigationHandoffSHA256.hashing(resultBytes).rawBytes,
            InvestigationHandoffSHA256.hashing(terminalEvidenceBytes).rawBytes,
            protocolData(owner),
        ], maximumByteCount: 192 * 1_024)
    }

    private static func validate(request: InvestigationMachineDarwinEpochRequest,
        ownership: InvestigationMachineDarwinEpochOwnershipRecord,
        physicalOwnership: InvestigationMachineSingleEpochPhysicalOwnership,
        acknowledgement: InvestigationMachineDarwinEpochAcknowledgement,
        decision: InvestigationMachineDarwinEpochDecision, owner: UUID) throws {
        let requestDigest = try request.digest(), ownershipDigest = try ownership.digest()
        guard protocolUUIDIsNonzero(owner),
            ownership.requestSHA256 == requestDigest,
            try ownership.physicalOwnership(expectedSelection:
                request.invocation.selection) == physicalOwnership,
            acknowledgement.requestSHA256 == requestDigest,
            acknowledgement.ownershipSHA256 == ownershipDigest,
            acknowledgement.physicalOwnershipSHA256
                == ownership.physicalOwnershipSHA256,
            decision.requestSHA256 == requestDigest,
            decision.ownershipSHA256 == ownershipDigest,
            decision.acknowledgementSHA256 == (try acknowledgement.digest()),
            decision.kind == (request.mode == .normal ? .continue : .crashNow)
        else { throw protocolInvalidEncoding() }
    }
}

package struct InvestigationMachineEpochEvidence: Sendable, Equatable {
    package static let maximumByteCount = 256 * 1_024
    package let ordinal: UInt32; package let scenario: InvestigationHandoffScenario
    package let epochUUID: UUID; package let configurationNonce: UUID
    package let requestBytes, physicalEvidenceBytes, terminalEvidenceBytes: Data
    package let admissionMaterialBytes: Data
    package let admissionSHA256: InvestigationHandoffSHA256
    package func encoded() throws -> Data { try HandoffBinaryTranscript.encode(
        domain: "stornaut.task39.machine.epoch-evidence.v1", businessFields: [
            protocolData(ordinal), protocolData(scenario.rawValue),
            protocolData(epochUUID), protocolData(configurationNonce),
            requestBytes, physicalEvidenceBytes, terminalEvidenceBytes,
            admissionMaterialBytes, admissionSHA256.rawBytes],
        maximumByteCount: Self.maximumByteCount) }
    package static func decode(_ data: Data) throws -> Self {
        let f = try protocolDecode(data, domain:
            "stornaut.task39.machine.epoch-evidence.v1", ranges: [
                4...4, 4...4, 16...16, 16...16, 1...(128 * 1_024),
                1...(64 * 1_024), 1...2_048,
                1...InvestigationMachineEpochAdmissionMaterial.maximumByteCount,
                32...32], maximum: Self.maximumByteCount)
        let request=try InvestigationMachineDarwinEpochRequest.decodeUntrusted(f[4]),
            selection=request.invocation.selection
        guard let scenario = InvestigationHandoffScenario(rawValue:
            try protocolUInt32(f[1])) else { throw protocolInvalidEncoding() }
        let value=Self(ordinal:try protocolUInt32(f[0]),scenario:scenario,
            epochUUID:try protocolUUID(f[2]),configurationNonce:try protocolUUID(f[3]),requestBytes:f[4],
            physicalEvidenceBytes: f[5], terminalEvidenceBytes: f[6],
            admissionMaterialBytes: f[7],
            admissionSHA256: try protocolDigest(f[8]))
        guard value.ordinal == selection.epoch.ordinal,
            value.scenario == selection.epoch.scenario,
            value.epochUUID == selection.epoch.epochUUID,
            value.configurationNonce == selection.epoch.configurationNonce,
            protocolNonzero(value.admissionSHA256),
            try value.encoded() == data else { throw protocolInvalidEncoding() }
        let normal=request.mode == .normal,p=try protocolDecode(f[5],domain:
            "stornaut.task39.machine.epoch-physical-evidence.v1",
            ranges: normal ? [1...32*1024, 1...48*1024] : [1...32*1024],
            maximum: 64 * 1_024)
        let ownership=try InvestigationMachineSingleEpochPhysicalOwnership.decodeEvidence(p[0],expectedSelection:selection)
        guard !ownership.installedL2ProofBytes.isEmpty else { throw protocolInvalidEncoding() }
        let installedL2ObservedAtNanoseconds = try protocolValidateInstalledL2Evidence(
            ownership.installedL2ProofBytes, selection: selection,
            claimEvidence: ownership.claimEvidence,
            appIdentity: ownership.appIdentity,
            helperIdentity: ownership.helperIdentity,
            epochDeadlineNanoseconds: request.epochDeadlineNanoseconds)
        let resultBytes = normal ? p[1] : Data()
        let result = normal ? try InvestigationMachineDarwinEpochNormalResult
            .decode(resultBytes, expectedSelection: selection) : nil
        let terminal = try InvestigationMachineDarwinEpochTerminalEvidence.decode(f[6])
        let material = try InvestigationMachineEpochAdmissionMaterial.decode(
            f[7], request: request, physicalOwnership: ownership)
        if let result { guard
            result.requestSHA256 == (try request.digest()),
            result.ownershipSHA256 == (try material.ownership.digest()),
            result.acknowledgementSHA256
                == (try material.acknowledgement.digest()),
            result.decisionSHA256 == (try material.decision.digest()),
            result.physicalResult.physicalOwnership == ownership
            else { throw protocolInvalidEncoding() } }
        guard protocolTerminalEvidenceIsExact(terminal, request: request,
                ownership: material.ownership, physicalOwnership: ownership,
                physicalResult: result?.physicalResult),
            installedL2ObservedAtNanoseconds
                <= terminal.observedAtNanoseconds,
            InvestigationHandoffSHA256.hashing(try material.admissionTranscript(
                requestBytes: f[4], resultBytes: resultBytes,
                terminalEvidenceBytes: f[6])) == value.admissionSHA256
        else { throw protocolInvalidEncoding() }
        return value
    }
}
package struct InvestigationMachineEpochEvidenceBundle: Sendable, Equatable {
    package static let maximumByteCount = 3 * 1_024 * 1_024
    package let outerAttemptUUID: UUID; package let epochs: [InvestigationMachineEpochEvidence]
    package let wholeCapsuleSHA256, wholeInputSHA256: InvestigationHandoffSHA256
    package func bundleSHA256() throws -> InvestigationHandoffSHA256 { .hashing(try encoded()) }
    package func encoded() throws -> Data {
        var f=[protocolData(outerAttemptUUID),wholeCapsuleSHA256.rawBytes,
            wholeInputSHA256.rawBytes,protocolData(UInt32(epochs.count))]
        f += try epochs.map { try $0.encoded() }
        return try HandoffBinaryTranscript.encode(domain:
            "stornaut.task39.machine.driver-evidence-bundle.v1",
            businessFields: f, maximumByteCount: Self.maximumByteCount)
    }
    package static func decode(_ data: Data) throws -> Self {
        let f = try protocolDecode(data, domain:
            "stornaut.task39.machine.driver-evidence-bundle.v1", ranges:
            [16...16, 32...32, 32...32, 4...4] +
            Array(repeating: 1...InvestigationMachineEpochEvidence.maximumByteCount,
                count: 8), maximum: Self.maximumByteCount)
        let epochs=try f.dropFirst(4).map(InvestigationMachineEpochEvidence.decode),
            value=Self(outerAttemptUUID:try protocolUUID(f[0]),epochs:epochs,
                wholeCapsuleSHA256:try protocolDigest(f[1]),wholeInputSHA256:try protocolDigest(f[2]))
        let selections = try epochs.map { try InvestigationMachineDarwinEpochRequest
            .decodeUntrusted($0.requestBytes).invocation.selection }
        let capsule = try InvestigationCohortCapsule(
            outerAttemptUUID: value.outerAttemptUUID, epochs: selections.map(\.epoch))
        let projected = try InvestigationProjectedCohortInput(
            capsule: capsule, projections: selections.map(\.projection))
        guard try protocolUInt32(f[3]) == 8,
            epochs.map(\.ordinal) == Array(UInt32(0)...7),
            selections.allSatisfy({
                $0.outerAttemptUUID == value.outerAttemptUUID
                    && $0.wholeCapsuleSHA256 == value.wholeCapsuleSHA256
                    && $0.wholeInputSHA256 == value.wholeInputSHA256
            }),
            capsule.wholeCapsuleSHA256 == value.wholeCapsuleSHA256,
            projected.wholeInputSHA256 == value.wholeInputSHA256,
            try protocolContinuityIsExact(epochs: epochs, selections: selections),
            try value.encoded() == data else { throw protocolInvalidEncoding() }
        return value
    }
}
package final class InvestigationMachineEpochEvidenceCollector: @unchecked Sendable {
    private let lock = NSLock(); private var active = false
    private var activeAttempt: UUID?; private var terminal = false
    private var values: [InvestigationMachineEpochEvidence] = []
    package func begin(attemptUUID: UUID) throws { try lock.withLock {
        guard !terminal, !active, activeAttempt == nil,
            protocolUUIDIsNonzero(attemptUUID) else { throw protocolInvalidState() }
        active = true; activeAttempt = attemptUUID } }
    package func record(selection:InvestigationMachineFixedEpochSelection,requestBytes:Data,
        physicalEvidenceBytes:Data,terminalEvidenceBytes:Data,
        admissionMaterialBytes:Data,admissionSHA256:InvestigationHandoffSHA256,
        commitIsStillValid: @Sendable () throws -> Bool)throws{try lock.withLock{
        guard active, !terminal, activeAttempt == selection.outerAttemptUUID,
            values.count == Int(selection.epoch.ordinal),
            selection.epoch.scenario.rawValue == selection.epoch.ordinal + 1,
            !requestBytes.isEmpty, !physicalEvidenceBytes.isEmpty,
            !terminalEvidenceBytes.isEmpty, !admissionMaterialBytes.isEmpty,
            protocolNonzero(admissionSHA256), try commitIsStillValid()
            else { terminal = true; throw protocolInvalidState() }
        values.append(.init(ordinal: selection.epoch.ordinal,
            scenario: selection.epoch.scenario, epochUUID: selection.epoch.epochUUID,
            configurationNonce: selection.epoch.configurationNonce,
            requestBytes: requestBytes, physicalEvidenceBytes: physicalEvidenceBytes,
            terminalEvidenceBytes: terminalEvidenceBytes,
            admissionMaterialBytes: admissionMaterialBytes,
            admissionSHA256: admissionSHA256)) } }
    package func finish(summary:InvestigationMachineEightEpochCompletionSummary)throws->Data{try lock.withLock{
        guard !terminal, activeAttempt == summary.outerAttemptUUID,
            values.count == InvestigationCohortCapsule.epochCount,
            values.map(\.ordinal) == Array(UInt32(0)...7)
            else { terminal = true; throw protocolInvalidState() }
        terminal = true; return try InvestigationMachineEpochEvidenceBundle(outerAttemptUUID:
            summary.outerAttemptUUID, epochs: values,
            wholeCapsuleSHA256: summary.wholeCapsuleSHA256,
            wholeInputSHA256: summary.wholeInputSHA256).encoded() } }
    package func abort() { lock.withLock { terminal = true; values.removeAll() } }
}
private let investigationMachineActiveEvidenceCollector = NSLock()
private nonisolated(unsafe) var investigationMachineEvidenceCollector: InvestigationMachineEpochEvidenceCollector?

package enum InvestigationMachineEpochEvidenceCollection {
    package static func begin(attemptUUID: UUID) throws {
        guard protocolUUIDIsNonzero(attemptUUID) else { throw protocolInvalidState() }; try investigationMachineActiveEvidenceCollector.withLock {
            guard investigationMachineEvidenceCollector == nil else { throw protocolInvalidState() }
            let c = InvestigationMachineEpochEvidenceCollector()
            try c.begin(attemptUUID: attemptUUID); investigationMachineEvidenceCollector = c }
    }
    package static func finish(summary:InvestigationMachineEightEpochCompletionSummary)throws->Data{try investigationMachineActiveEvidenceCollector.withLock{
        guard let c = investigationMachineEvidenceCollector
            else { throw protocolInvalidState() }
        defer { investigationMachineEvidenceCollector = nil }
        return try c.finish(summary: summary) } }
    package static func abort() { investigationMachineActiveEvidenceCollector.withLock {
        investigationMachineEvidenceCollector?.abort(); investigationMachineEvidenceCollector = nil } }
    fileprivate static func record(selection: InvestigationMachineFixedEpochSelection,
        requestBytes: Data, physicalEvidenceBytes: Data, terminalEvidenceBytes: Data,
        admissionMaterialBytes: Data, admissionSHA256: InvestigationHandoffSHA256,
        commitIsStillValid: @Sendable () throws -> Bool) throws {
        let c = investigationMachineActiveEvidenceCollector.withLock { investigationMachineEvidenceCollector }
        try c?.record(selection: selection, requestBytes: requestBytes,
            physicalEvidenceBytes: physicalEvidenceBytes, terminalEvidenceBytes:
            terminalEvidenceBytes, admissionMaterialBytes: admissionMaterialBytes,
            admissionSHA256: admissionSHA256,
            commitIsStillValid: commitIsStillValid)
    }
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
            auditTokenWords[2] == 0,
            auditTokenWords[3] == 0,
            auditTokenWords[4] == 0,
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
    private static let maximumByteCount = 48 * 1_024

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
        physicalOwnershipBytes = try physicalOwnership.evidenceEncoded()
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
                32...32, 1...1_024, 1...2_048, 1...(32 * 1_024),
                32...32,
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
        let value = try protocolPhysicalOwnership(
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
    private static let maximumByteCount = 48 * 1_024

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
            try physicalResult.physicalOwnership.evidenceEncoded()
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
        let physicalBytes = try physicalResult.evidenceEncoded()
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
                1...InvestigationMachineSingleEpochPhysicalResult.maximumCompletionByteCount, 32...32,
            ], maximum: maximumByteCount
        )
        let physical = try InvestigationMachineSingleEpochPhysicalResult
            .decodeEvidence(
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
                == .hashing(try physicalResult.physicalOwnership.evidenceEncoded()),
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

    package func encoded() throws -> Data {
        try HandoffBinaryTranscript.encode(
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
        )
    }

    package static func decode(_ data: Data) throws -> Self {
        let f = try protocolDecode(data, domain:
            "stornaut.task39.machine.outer-inner.terminal-evidence", ranges: [
            1...1, 1...1, 1...1_024, 1...2_048,
            1...InvestigationMachineProcessIdentity.maximumByteCount,
            1...1, 1...1, 1...1, 1...1, 1...1, 1...1,
            32...32, 32...32, 8...8], maximum: 2_048)
        func boolean(_ field: Data) throws -> Bool {
            guard field == Data([0]) || field == Data([1])
                else { throw protocolInvalidEncoding() }
            return field == Data([1])
        }
        let value = try Self(controlEOFObserved: boolean(f[0]),
            resultEOFObserved: boolean(f[1]), driverChild: .decode(f[2]),
            appChild: .decode(f[3]), helperIdentity: .decode(f[4]),
            innerExitedSuccessfully: boolean(f[5]), appAbsent: boolean(f[6]),
            groupLeaderReapedLast: boolean(f[7]), postReapGroupEmpty: boolean(f[8]),
            helperAbsent: boolean(f[9]), l1ResidueAbsent: boolean(f[10]),
            initialDriverObservationSHA256: protocolDigest(f[11]),
            finalDriverObservationSHA256: protocolDigest(f[12]),
            observedAtNanoseconds: protocolUInt64(f[13]))
        guard try value.encoded() == data else { throw protocolInvalidEncoding() }
        return value
    }

    fileprivate func digest() throws -> InvestigationHandoffSHA256 {
        .hashing(try encoded())
    }
}

private func protocolTerminalEvidenceIsExact(
    _ evidence: InvestigationMachineDarwinEpochTerminalEvidence,
    request: InvestigationMachineDarwinEpochRequest,
    ownership: InvestigationMachineDarwinEpochOwnershipRecord,
    physicalOwnership: InvestigationMachineSingleEpochPhysicalOwnership,
    physicalResult: InvestigationMachineSingleEpochPhysicalResult?
) -> Bool {
    guard
        evidence.controlEOFObserved, evidence.resultEOFObserved,
        evidence.driverChild == ownership.driverChild,
        evidence.appChild == ownership.appChild,
        evidence.helperIdentity == physicalOwnership.helperIdentity,
        evidence.appAbsent, evidence.groupLeaderReapedLast,
        evidence.postReapGroupEmpty, evidence.helperAbsent,
        evidence.l1ResidueAbsent,
        evidence.initialDriverObservationSHA256
            == evidence.finalDriverObservationSHA256,
        evidence.observedAtNanoseconds < request.epochDeadlineNanoseconds,
        physicalOwnership.mode == request.mode,
        physicalOwnership.epochDeadlineNanoseconds
            == request.epochDeadlineNanoseconds
    else { return false }

    switch request.mode {
    case .normal:
        guard let physicalResult else { return false }
        return evidence.innerExitedSuccessfully
            && physicalResult.mode == .normal
            && physicalResult.physicalOwnership == physicalOwnership
            && physicalResult.helperIdentity == evidence.helperIdentity
            && physicalResult.driverObservationSHA256
                == evidence.initialDriverObservationSHA256
    case .parentCrash:
        return !evidence.innerExitedSuccessfully && physicalResult == nil
    }
}

private func protocolContinuityIsExact(
    epochs: [InvestigationMachineEpochEvidence],
    selections: [InvestigationMachineFixedEpochSelection]
) throws -> Bool {
    guard epochs.count == InvestigationCohortCapsule.epochCount,
        selections.count == epochs.count
    else { return false }

    for index in epochs.indices {
        let request = try InvestigationMachineDarwinEpochRequest
            .decodeUntrusted(epochs[index].requestBytes)
        guard request.invocation.selection == selections[index] else { return false }
        if index == 0 {
            let predecessor = try protocolDecode(
                request.invocation.predecessorTranscript, domain:
                    "stornaut.task39.machine.helper-continuity.genesis",
                ranges: [16...16, 32...32, 32...32, 4...4, 16...16],
                maximum: 512)
            guard request.invocation.previousHelperIdentity == nil,
                try protocolUUID(predecessor[0]) == selections[index].outerAttemptUUID,
                try protocolDigest(predecessor[1])
                    == selections[index].wholeCapsuleSHA256,
                try protocolDigest(predecessor[2])
                    == selections[index].wholeInputSHA256,
                try protocolUInt32(predecessor[3]) == 0,
                try protocolUUID(predecessor[4]) == selections[index].epoch.epochUUID,
                InvestigationHandoffSHA256.hashing(
                    request.invocation.predecessorTranscript)
                    == request.invocation.predecessorSHA256
            else { return false }
            continue
        }

        let previous = epochs[index - 1]
        let previousPhysicalFields = try protocolDecode(
            previous.physicalEvidenceBytes, domain:
                "stornaut.task39.machine.epoch-physical-evidence.v1",
            ranges: index - 1 == 6
                ? [1...(32 * 1_024)]
                : [1...(32 * 1_024), 1...(48 * 1_024)],
            maximum: 64 * 1_024)
        let previousOwnership = try InvestigationMachineSingleEpochPhysicalOwnership
            .decodeEvidence(previousPhysicalFields[0],
                expectedSelection: selections[index - 1])
        let currentPhysicalFields = try protocolDecode(
            epochs[index].physicalEvidenceBytes, domain:
                "stornaut.task39.machine.epoch-physical-evidence.v1",
            ranges: index == 6
                ? [1...(32 * 1_024)]
                : [1...(32 * 1_024), 1...(48 * 1_024)],
            maximum: 64 * 1_024)
        let currentOwnership = try InvestigationMachineSingleEpochPhysicalOwnership
            .decodeEvidence(currentPhysicalFields[0],
                expectedSelection: selections[index])
        let previousResult = index - 1 == 6 ? nil
            : try InvestigationMachineDarwinEpochNormalResult.decode(
                previousPhysicalFields[1],
                expectedSelection: selections[index - 1]).physicalResult
        let expectedCompletion = previousResult?.bindingSHA256
            ?? previousOwnership.bindingSHA256
        let predecessor = try protocolDecode(
            request.invocation.predecessorTranscript, domain:
                "stornaut.task39.machine.helper-continuity.successor",
            ranges: [16...16, 32...32, 32...32, 4...4, 16...16,
                1...InvestigationMachineProcessIdentity.maximumByteCount,
                32...32, 32...32, 32...32, 1...1], maximum: 4_096)
        let predecessorHelper = try InvestigationMachineProcessIdentity
            .decode(predecessor[5])
        guard request.invocation.previousHelperIdentity == previousOwnership.helperIdentity,
            predecessorHelper == previousOwnership.helperIdentity,
            currentOwnership.helperIdentity != previousOwnership.helperIdentity,
            try protocolUUID(predecessor[0]) == selections[index].outerAttemptUUID,
            try protocolDigest(predecessor[1]) == selections[index].wholeCapsuleSHA256,
            try protocolDigest(predecessor[2]) == selections[index].wholeInputSHA256,
            try protocolUInt32(predecessor[3]) == UInt32(index - 1),
            try protocolUUID(predecessor[4]) == selections[index - 1].epoch.epochUUID,
            try protocolDigest(predecessor[6])
                == requestForEpoch(epochs[index - 1])
                    .invocation.predecessorSHA256,
            try protocolDigest(predecessor[7]) == expectedCompletion,
            try protocolDigest(predecessor[8]) == previous.admissionSHA256,
            predecessor[9] == Data([
                selections[index - 1].epoch.scenario == .lifecycleRecovery
                    ? InvestigationMachineOuterContainmentMode.parentCrash.rawValue
                    : InvestigationMachineOuterContainmentMode.normal.rawValue
            ]),
            InvestigationHandoffSHA256.hashing(
                request.invocation.predecessorTranscript)
                == request.invocation.predecessorSHA256
        else { return false }
    }
    return true
}

private func protocolValidateInstalledL2Evidence(
    _ bytes: Data, selection: InvestigationMachineFixedEpochSelection,
    claimEvidence: InvestigationMachineClaimEvidence,
    appIdentity: InvestigationMachineProcessIdentity,
    helperIdentity: InvestigationMachineProcessIdentity,
    epochDeadlineNanoseconds: UInt64
) throws -> UInt64 {
    do {
        let fields = try protocolDecode(bytes, domain:
            "stornaut.task39.machine.single-epoch.installed-l2-proof",
            ranges: [
                32...32, 32...32, 16...16, 16...16, 8...8,
                1...1_024, 32...32, 1...1_024, 1...1_024,
                1...1_024, 32...32, 1...1_024, 1...1_024, 32...32,
                1...1_024, 1...1_024, 1...2_048, 8...8, 8...8,
                8...8, 8...8, 1...1_024, 8...8,
            ], maximum: 16_384)
        guard try HandoffBinaryTranscript.encode(
            domain: "stornaut.task39.machine.single-epoch.installed-l2-proof",
            businessFields: fields, maximumByteCount: 16_384) == bytes,
            protocolNonzero(claimEvidence.requestBindingSHA256),
            fields[0] == selection.projection.projectionSHA256.rawBytes,
            fields[1] == InvestigationHandoffSHA256.hashing(
                try claimEvidence.encoded()).rawBytes,
            try protocolUUID(fields[2]) == selection.epoch.epochUUID,
            try protocolUUID(fields[3]) == selection.epoch.configurationNonce,
            try InvestigationMachineProcessIdentity.decode(fields[5])
                == appIdentity,
            fields[6] == selection.projection.appExecutableSHA256.rawBytes,
            try InvestigationMachineProcessIdentity.decode(fields[9])
                == helperIdentity,
            fields[10] == selection.projection.helperExecutableSHA256.rawBytes,
            fields[13]
                == selection.projection.machineDriverExecutableSHA256.rawBytes,
            fields[16] == Data([0x02]) + (try helperIdentity.encoded()),
            try InvestigationMachineProcessIdentity.decode(fields[21])
                == appIdentity,
            try protocolUInt64(fields[22]) == epochDeadlineNanoseconds
        else { throw protocolInvalidEncoding() }

        let artifactBytes = Array(fields[4])
        guard artifactBytes.count
                == InvestigationInstalledL2ArtifactRole.allCases.count
        else { throw protocolInvalidEncoding() }
        let artifacts = try Dictionary(uniqueKeysWithValues:
            zip(InvestigationInstalledL2ArtifactRole.allCases, artifactBytes)
                .map { role, byte in
                    let value: InvestigationInstalledL2ArtifactObservation =
                        switch byte {
                        case 0x01: .absent
                        case 0x02: .presentValid
                        case 0x03: .invalid
                        case 0x04: .unavailable
                        default: throw protocolInvalidEncoding()
                        }
                    return (role, value)
                })
        let appStatic = try protocolInstalledL2Signing(fields[7])
        let appLive = try protocolInstalledL2Signing(fields[8])
        let helperStatic = try protocolInstalledL2Signing(fields[11])
        let helperLive = try protocolInstalledL2Signing(fields[12])
        let driverStatic = try protocolInstalledL2Signing(fields[14])
        let driverLive = try protocolInstalledL2Signing(fields[15])
        let started = try InvestigationInstalledL2ClockSample(
            wallUTC: .init(rawValue: Int64(bitPattern:
                protocolUInt64(fields[17]))),
            continuousNanoseconds: protocolUInt64(fields[18]))
        let observed = try InvestigationInstalledL2ClockSample(
            wallUTC: .init(rawValue: Int64(bitPattern:
                protocolUInt64(fields[19]))),
            continuousNanoseconds: protocolUInt64(fields[20]))
        let semantic = try InvestigationInstalledL2SemanticContract.evaluate(
            projection: selection.projection, artifacts: artifacts,
            app: .init(identity: appIdentity,
                executableSHA256: try protocolDigest(fields[6]),
                staticSigning: appStatic, liveSigning: appLive),
            helper: .init(identity: helperIdentity,
                executableSHA256: try protocolDigest(fields[10]),
                staticSigning: helperStatic, liveSigning: helperLive),
            machineDriver: .init(
                executableSHA256: try protocolDigest(fields[13]),
                staticSigning: driverStatic, liveSigning: driverLive),
            service: .loaded(identity: helperIdentity),
            started: started, observed: observed)
        _ = try InvestigationInstalledL2TemporalWindow(
            projection: selection.projection, claimEvidence: claimEvidence,
            epochBootstrap: .init(
                epochUUID: selection.epoch.epochUUID,
                epochDeadlineNanoseconds: epochDeadlineNanoseconds),
            started: semantic.started, observed: semantic.observed)
        return semantic.observed.continuousNanoseconds
    } catch {
        throw protocolInvalidEncoding()
    }
}

private func protocolInstalledL2Signing(
    _ bytes: Data
) throws -> InvestigationInstalledL2SigningIdentity {
    let fields = try protocolDecode(bytes, domain:
        "stornaut.task39.machine.single-epoch.installed-l2-signing",
        ranges: [1...256, 32...32, 20...32, 1...1], maximum: 1_024)
    guard let identifier = String(data: fields[0], encoding: .utf8),
        Data(identifier.utf8) == fields[0],
        fields[3] == Data([0]) || fields[3] == Data([1]),
        try HandoffBinaryTranscript.encode(
            domain: "stornaut.task39.machine.single-epoch.installed-l2-signing",
            businessFields: fields, maximumByteCount: 1_024) == bytes
    else { throw protocolInvalidEncoding() }
    return try InvestigationInstalledL2SigningIdentity(
        signingIdentifier: identifier,
        designatedRequirementSHA256: protocolDigest(fields[1]),
        codeDirectoryHash: fields[2], isAdHoc: fields[3] == Data([1]))
}

private func requestForEpoch(
    _ evidence: InvestigationMachineEpochEvidence
) throws -> InvestigationMachineDarwinEpochRequest {
    try InvestigationMachineDarwinEpochRequest.decodeUntrusted(
        evidence.requestBytes)
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
            physical = try protocolPhysicalOwnership(
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
                == .hashing(try physical.evidenceEncoded())
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
    private struct Exchange: Sendable {
        let request: InvestigationMachineDarwinEpochRequest
        let ownership: InvestigationMachineDarwinEpochOwnershipRecord
        let physicalOwnership: InvestigationMachineSingleEpochPhysicalOwnership
        let driverChild: InvestigationMachineDarwinDriverChildIdentity
        let appChild: InvestigationMachineDarwinAppChildIdentity
        let acknowledgement: InvestigationMachineDarwinEpochAcknowledgement
        let decision: InvestigationMachineDarwinEpochDecision?
    }
    private struct PendingEvidence: Sendable {
        let requestBytes: Data
        let physicalEvidenceBytes: Data
        let terminalEvidenceBytes: Data
        let admissionMaterialBytes: Data
        let admissionSHA256: InvestigationHandoffSHA256
        let observedAtNanoseconds: UInt64
        let deadlineNanoseconds: UInt64
    }
    private enum State {
        case ready
        case requested(InvestigationMachineDarwinEpochRequest)
        case acknowledged(Exchange)
        case decided(Exchange)
        case admitted(InvestigationMachineSingleEpochResult, PendingEvidence)
        case proved(InvestigationMachineSingleEpochResult, PendingEvidence)
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
            physical = try protocolPhysicalOwnership(
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

        let helper: InvestigationMachineProcessIdentity
        let binding: InvestigationHandoffSHA256
        let physicalResult: InvestigationMachineSingleEpochPhysicalResult?
        switch exchange.request.mode {
        case .normal:
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
            physicalResult = normal.physicalResult
            helper = normal.physicalResult.helperIdentity
            binding = normal.physicalResult.bindingSHA256
        case .parentCrash:
            guard
                resultBytes.isEmpty, !terminalEvidence.innerExitedSuccessfully,
                decision.kind == .crashNow
            else { return try failTerminalEvidence() }
            physicalResult = nil
            helper = exchange.physicalOwnership.helperIdentity
            binding = exchange.physicalOwnership.bindingSHA256
        }
        guard terminalEvidenceIsExact(
            terminalEvidence, exchange: exchange,
            physicalResult: physicalResult
        ) else { return try failTerminalEvidence() }

        let requestBytes: Data
        let terminalEvidenceBytes: Data
        let admissionMaterialBytes: Data
        let admissionDigest: InvestigationHandoffSHA256
        do {
            requestBytes = try exchange.request.encoded()
            terminalEvidenceBytes = try terminalEvidence.encoded()
            let material = try InvestigationMachineEpochAdmissionMaterial(
                request: exchange.request, ownership: exchange.ownership,
                acknowledgement: exchange.acknowledgement,
                decision: decision, owner: owner
            )
            admissionMaterialBytes = try material.encoded()
            admissionDigest = .hashing(try material.admissionTranscript(
                requestBytes: requestBytes, resultBytes: resultBytes,
                terminalEvidenceBytes: terminalEvidenceBytes
            ))
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
        let physicalEvidenceBytes: Data
        do {
            let ownershipBytes = try exchange.physicalOwnership
                .evidenceEncoded()
            let fields = exchange.request.mode == .normal
                ? [ownershipBytes, resultBytes] : [ownershipBytes]
            physicalEvidenceBytes = try HandoffBinaryTranscript.encode(
                domain: "stornaut.task39.machine.epoch-physical-evidence.v1",
                businessFields: fields, maximumByteCount: 64 * 1_024)
        } catch { return try failValue() }
        let token = InvestigationMachineSingleEpochAdmittedPhysicalResult(
            helperIdentity: helper, bindingSHA256: binding,
            mode: exchange.request.mode, selection: selection,
            predecessorSHA256: exchange.request.invocation.predecessorSHA256,
            terminalProofSHA256: admissionDigest, admissionOwner: owner
        )
        let result = InvestigationMachineSingleEpochResult.admittedPhysical(token)
        state = .admitted(result, PendingEvidence(
            requestBytes: requestBytes,
            physicalEvidenceBytes: physicalEvidenceBytes,
            terminalEvidenceBytes: terminalEvidenceBytes,
            admissionMaterialBytes: admissionMaterialBytes,
            admissionSHA256: admissionDigest,
            observedAtNanoseconds: terminalEvidence.observedAtNanoseconds,
            deadlineNanoseconds: exchange.request.epochDeadlineNanoseconds))
        return result
    }

    package func proveContainment(
        selection: InvestigationMachineFixedEpochSelection,
        result: InvestigationMachineSingleEpochResult,
        predecessor: InvestigationMachineHelperEpochPredecessor
    ) async -> InvestigationMachineOuterContainmentOutcome {
        guard case let .admitted(expected, pending) = state else {
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
        state = .proved(expected, pending)
        return .contained(proof)
    }

    package func commitContainmentEvidence(
        selection: InvestigationMachineFixedEpochSelection,
        result: InvestigationMachineSingleEpochResult,
        predecessor: InvestigationMachineHelperEpochPredecessor
    ) async -> Bool {
        guard case let .proved(expected, pending) = state else {
            state = .terminal
            return false
        }
        state = .terminal
        guard result == expected, selection == self.selection,
            case let .admittedPhysical(token) = result,
            token.admissionOwner == owner, token.selection == selection,
            token.predecessorSHA256 == predecessor.continuitySHA256
        else { return false }
        let clock = clock
        do {
            try InvestigationMachineEpochEvidenceCollection.record(
                selection: selection, requestBytes: pending.requestBytes,
                physicalEvidenceBytes: pending.physicalEvidenceBytes,
                terminalEvidenceBytes: pending.terminalEvidenceBytes,
                admissionMaterialBytes: pending.admissionMaterialBytes,
                admissionSHA256: pending.admissionSHA256,
                commitIsStillValid: {
                    guard !Task.isCancelled else { return false }
                    let committedAt = try clock.continuousNanoseconds()
                    return !Task.isCancelled
                        && committedAt >= pending.observedAtNanoseconds
                        && committedAt < pending.deadlineNanoseconds
                })
        } catch { return false }
        return true
    }

    private func terminalEvidenceIsExact(
        _ evidence: InvestigationMachineDarwinEpochTerminalEvidence,
        exchange: Exchange,
        physicalResult: InvestigationMachineSingleEpochPhysicalResult?
    ) -> Bool {
        protocolTerminalEvidenceIsExact(
            evidence, request: exchange.request, ownership: exchange.ownership,
            physicalOwnership: exchange.physicalOwnership,
            physicalResult: physicalResult
        )
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

private func protocolInvalidState() -> InvestigationMachineDarwinOuterInnerProtocolError
    { .invalidState }

private func protocolPhysicalOwnership(_ data: Data, expectedSelection:
    InvestigationMachineFixedEpochSelection) throws ->
    InvestigationMachineSingleEpochPhysicalOwnership {
    if let value = try? InvestigationMachineSingleEpochPhysicalOwnership
        .decodeEvidence(data, expectedSelection: expectedSelection)
    { return value }
    return try InvestigationMachineSingleEpochPhysicalOwnership.decode(data,
        expectedSelection: expectedSelection)
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

private func protocolUUIDIsNonzero(_ value: UUID) -> Bool
    { protocolData(value).contains { $0 != 0 } }

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

private func protocolUUID(_ data: Data) throws -> UUID {
    guard data.count == 16 else { throw protocolInvalidEncoding() }; let b = [UInt8](data)
    let value = UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
        b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    guard protocolUUIDIsNonzero(value) else { throw protocolInvalidEncoding() }
    return value
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
