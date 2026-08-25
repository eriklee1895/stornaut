import CInvestigationIdentitySupport
import Darwin

package enum InvestigationMachineDarwinDriverChildObservationError:
    Error, Sendable, Equatable
{
    case identityInvalid
    case observationUnavailable
}

package struct InvestigationMachineDarwinDriverChildNarrowIdentity:
    Sendable, Equatable
{
    package var processID: UInt32
    package var processIDVersion: UInt32
    package var auditSessionID: UInt32
    package var effectiveUserID: UInt32
    package var auditTokenWords: [UInt32]

    package init(
        processID: UInt32, processIDVersion: UInt32, auditSessionID: UInt32,
        effectiveUserID: UInt32, auditTokenWords: [UInt32]
    ) {
        self.processID = processID
        self.processIDVersion = processIDVersion
        self.auditSessionID = auditSessionID
        self.effectiveUserID = effectiveUserID
        self.auditTokenWords = auditTokenWords
    }
}

package struct InvestigationMachineDarwinDriverChildProcessSnapshot:
    Sendable, Equatable
{
    package var processID: UInt32
    package var parentProcessID: UInt32
    package var processGroupID: UInt32
    package var realUserID: UInt32
    package var effectiveUserID: UInt32
    package var savedUserID: UInt32
    package var realGroupID: UInt32
    package var effectiveGroupID: UInt32
    package var savedGroupID: UInt32
    package var auditUserID: UInt32
    package var auditSessionID: UInt32
    package var supplementaryGroups: [UInt32]
    package var startTimeSeconds: UInt64
    package var startTimeMicroseconds: UInt64

    package init(
        processID: UInt32, parentProcessID: UInt32, processGroupID: UInt32,
        realUserID: UInt32 = 0, effectiveUserID: UInt32,
        savedUserID: UInt32 = 0, realGroupID: UInt32 = 0,
        effectiveGroupID: UInt32 = 0, savedGroupID: UInt32 = 0,
        auditUserID: UInt32 = 0, auditSessionID: UInt32 = 1,
        supplementaryGroups: [UInt32] = [0], startTimeSeconds: UInt64,
        startTimeMicroseconds: UInt64
    ) {
        self.processID = processID
        self.parentProcessID = parentProcessID
        self.processGroupID = processGroupID
        self.realUserID = realUserID
        self.effectiveUserID = effectiveUserID
        self.savedUserID = savedUserID
        self.realGroupID = realGroupID
        self.effectiveGroupID = effectiveGroupID
        self.savedGroupID = savedGroupID
        self.auditUserID = auditUserID
        self.auditSessionID = auditSessionID
        self.supplementaryGroups = supplementaryGroups
        self.startTimeSeconds = startTimeSeconds
        self.startTimeMicroseconds = startTimeMicroseconds
    }
}

package struct InvestigationMachineDarwinDriverChildTopologySnapshot:
    Sendable, Equatable
{
    package let processID: UInt32
    package let parentProcessID: UInt32
    package let processGroupID: UInt32
    package let effectiveUserID: UInt32
    package let startTimeSeconds: UInt64
    package let startTimeMicroseconds: UInt64
}

package enum InvestigationMachineDarwinDriverChildTopologyReader {
    package static func observe(processID: UInt32) throws
        -> InvestigationMachineDarwinDriverChildTopologySnapshot
    {
        guard processID > 1, processID <= UInt32(Int32.max) else {
            throw InvestigationMachineDarwinDriverChildObservationError
                .observationUnavailable
        }
        var information = proc_bsdinfo()
        let count = proc_pidinfo(
            pid_t(processID), PROC_PIDTBSDINFO, 0, &information,
            Int32(MemoryLayout<proc_bsdinfo>.size)
        )
        guard
            count == MemoryLayout<proc_bsdinfo>.size,
            information.pbi_pid == processID,
            information.pbi_ppid > 1, information.pbi_pgid > 1,
            information.pbi_start_tvsec > 0,
            information.pbi_start_tvusec < 1_000_000
        else {
            throw InvestigationMachineDarwinDriverChildObservationError
                .observationUnavailable
        }
        return .init(
            processID: processID,
            parentProcessID: UInt32(information.pbi_ppid),
            processGroupID: UInt32(information.pbi_pgid),
            effectiveUserID: UInt32(information.pbi_uid),
            startTimeSeconds: UInt64(information.pbi_start_tvsec),
            startTimeMicroseconds: UInt64(information.pbi_start_tvusec)
        )
    }
}

package struct InvestigationMachineDarwinDriverChildIdentitySystem:
    Sendable
{
    package let narrowIdentity:
        @Sendable (UInt32) throws
            -> InvestigationMachineDarwinDriverChildNarrowIdentity
    package let processSnapshot:
        @Sendable (UInt32) throws
            -> InvestigationMachineDarwinDriverChildProcessSnapshot

    package init(
        narrowIdentity: @escaping @Sendable (UInt32) throws
            -> InvestigationMachineDarwinDriverChildNarrowIdentity,
        processSnapshot: @escaping @Sendable (UInt32) throws
            -> InvestigationMachineDarwinDriverChildProcessSnapshot
    ) {
        self.narrowIdentity = narrowIdentity
        self.processSnapshot = processSnapshot
    }
}

package protocol InvestigationMachineDarwinDriverChildObserving: Sendable {
    func observe(
        processID: UInt32, expectedParentProcessID: UInt32
    ) throws -> InvestigationMachineDarwinDriverChildIdentity
}

package struct InvestigationMachineDarwinDriverChildObserver:
    InvestigationMachineDarwinDriverChildObserving, Sendable
{
    private let system: InvestigationMachineDarwinDriverChildIdentitySystem

    package init(
        system: InvestigationMachineDarwinDriverChildIdentitySystem
    ) {
        self.system = system
    }

    package init() {
        system = .system
    }

    package func observe(
        processID: UInt32, expectedParentProcessID: UInt32
    ) throws -> InvestigationMachineDarwinDriverChildIdentity {
        guard
            processID > 1, processID <= UInt32(Int32.max),
            expectedParentProcessID > 1
        else {
            throw InvestigationMachineDarwinDriverChildObservationError
                .identityInvalid
        }

        let firstNarrow: InvestigationMachineDarwinDriverChildNarrowIdentity
        let firstSnapshot: InvestigationMachineDarwinDriverChildProcessSnapshot
        let secondSnapshot: InvestigationMachineDarwinDriverChildProcessSnapshot
        let secondNarrow: InvestigationMachineDarwinDriverChildNarrowIdentity
        do {
            firstNarrow = try system.narrowIdentity(processID)
            firstSnapshot = try system.processSnapshot(processID)
            secondSnapshot = try system.processSnapshot(processID)
            secondNarrow = try system.narrowIdentity(processID)
        } catch {
            throw InvestigationMachineDarwinDriverChildObservationError
                .observationUnavailable
        }

        guard firstNarrow == secondNarrow, firstSnapshot == secondSnapshot else {
            throw InvestigationMachineDarwinDriverChildObservationError
                .identityInvalid
        }
        guard
            firstNarrow.processID == processID,
            firstNarrow.processIDVersion > 0,
            firstNarrow.auditSessionID > 0,
            firstNarrow.effectiveUserID == 0,
            firstNarrow.auditTokenWords.count == 8,
            firstNarrow.auditTokenWords[1] == firstNarrow.effectiveUserID,
            firstNarrow.auditTokenWords[5] == firstNarrow.processID,
            firstNarrow.auditTokenWords[6] == firstNarrow.auditSessionID,
            firstNarrow.auditTokenWords[7] == firstNarrow.processIDVersion,
            firstSnapshot.processID == processID,
            firstSnapshot.parentProcessID == expectedParentProcessID,
            firstSnapshot.processGroupID == processID,
            firstSnapshot.realUserID == 0,
            firstSnapshot.effectiveUserID == 0,
            firstSnapshot.savedUserID == 0,
            firstSnapshot.realGroupID == 0,
            firstSnapshot.effectiveGroupID == 0,
            firstSnapshot.savedGroupID == 0,
            firstSnapshot.auditUserID == firstNarrow.auditTokenWords[0],
            firstSnapshot.auditSessionID == firstNarrow.auditSessionID,
            firstNarrow.auditTokenWords[2]
                == firstSnapshot.effectiveGroupID,
            firstNarrow.auditTokenWords[3] == firstSnapshot.realUserID,
            firstNarrow.auditTokenWords[4] == firstSnapshot.realGroupID,
            !firstSnapshot.supplementaryGroups.isEmpty,
            firstSnapshot.supplementaryGroups.count <= 16,
            firstSnapshot.supplementaryGroups
                == firstSnapshot.supplementaryGroups.sorted(),
            Set(firstSnapshot.supplementaryGroups).count
                == firstSnapshot.supplementaryGroups.count,
            firstSnapshot.supplementaryGroups.contains(0),
            firstSnapshot.startTimeSeconds > 0,
            firstSnapshot.startTimeMicroseconds < 1_000_000
        else {
            throw InvestigationMachineDarwinDriverChildObservationError
                .identityInvalid
        }

        do {
            return try .init(
                processID: firstNarrow.processID,
                processIDVersion: firstNarrow.processIDVersion,
                parentProcessID: firstSnapshot.parentProcessID,
                processGroupID: firstSnapshot.processGroupID,
                auditSessionID: firstNarrow.auditSessionID,
                effectiveUserID: firstNarrow.effectiveUserID,
                auditTokenWords: firstNarrow.auditTokenWords
            )
        } catch {
            throw InvestigationMachineDarwinDriverChildObservationError
                .identityInvalid
        }
    }
}

extension InvestigationMachineDarwinDriverChildIdentitySystem {
    package static let system = Self(
        narrowIdentity: darwinDriverChildNarrowIdentity,
        processSnapshot: darwinDriverChildProcessSnapshot
    )
}

private func darwinDriverChildNarrowIdentity(_ processID: UInt32) throws
        -> InvestigationMachineDarwinDriverChildNarrowIdentity
{
        guard processID > 1, processID <= UInt32(Int32.max) else {
            throw InvestigationMachineDarwinDriverChildObservationError
                .observationUnavailable
        }
        var raw = stornaut_investigation_identity()
        guard stornaut_investigation_identity_for_pid(
            pid_t(processID), &raw
        ) == 0 else {
            throw InvestigationMachineDarwinDriverChildObservationError
                .observationUnavailable
        }
        let words = withUnsafeBytes(of: raw.audit_token_words) { bytes in
            stride(from: 0, to: bytes.count, by: MemoryLayout<UInt32>.size)
                .map { bytes.loadUnaligned(fromByteOffset: $0, as: UInt32.self) }
        }
        guard
            raw.process_id > 1, raw.process_id_version > 0,
            raw.audit_session_id > 0,
            words.count == 8
        else {
            throw InvestigationMachineDarwinDriverChildObservationError
                .identityInvalid
        }
        return .init(
            processID: UInt32(raw.process_id),
            processIDVersion: UInt32(raw.process_id_version),
            auditSessionID: UInt32(raw.audit_session_id),
            effectiveUserID: UInt32(raw.effective_user_id),
            auditTokenWords: words
        )
}

private func darwinDriverChildProcessSnapshot(_ processID: UInt32) throws
    -> InvestigationMachineDarwinDriverChildProcessSnapshot
{
        guard processID > 1, processID <= UInt32(Int32.max) else {
            throw InvestigationMachineDarwinDriverChildObservationError
                .observationUnavailable
        }
        var raw = stornaut_investigation_process_snapshot()
        guard stornaut_investigation_process_snapshot_for_pid(
            pid_t(processID), &raw
        ) == 0 else {
            throw InvestigationMachineDarwinDriverChildObservationError
                .observationUnavailable
        }
        guard
            raw.process_id > 1, raw.parent_process_id > 1,
            raw.process_group_id > 1, raw.process_group_id == raw.process_id,
            raw.audit_session_id > 0,
            raw.start_time_seconds > 0,
            raw.start_time_microseconds < 1_000_000
        else {
            throw InvestigationMachineDarwinDriverChildObservationError
                .identityInvalid
        }
        let groupCount = Int(raw.supplementary_group_count)
        let allGroups = withUnsafeBytes(of: raw.supplementary_groups) { bytes in
            Array(bytes.bindMemory(to: gid_t.self))
        }
        guard (1...16).contains(groupCount), allGroups.count == 16 else {
            throw InvestigationMachineDarwinDriverChildObservationError
                .identityInvalid
        }
        var groups: [UInt32] = []
        groups.reserveCapacity(groupCount)
        for index in 0..<groupCount {
            groups.append(UInt32(allGroups[index]))
        }
        groups.sort()
        return .init(
            processID: UInt32(raw.process_id),
            parentProcessID: UInt32(raw.parent_process_id),
            processGroupID: UInt32(raw.process_group_id),
            realUserID: UInt32(raw.real_user_id),
            effectiveUserID: UInt32(raw.effective_user_id),
            savedUserID: UInt32(raw.saved_user_id),
            realGroupID: UInt32(raw.real_group_id),
            effectiveGroupID: UInt32(raw.effective_group_id),
            savedGroupID: UInt32(raw.saved_group_id),
            auditUserID: UInt32(raw.audit_user_id),
            auditSessionID: UInt32(raw.audit_session_id),
            supplementaryGroups: groups,
            startTimeSeconds: raw.start_time_seconds,
            startTimeMicroseconds: raw.start_time_microseconds
        )
}
