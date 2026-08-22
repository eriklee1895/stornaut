import CInvestigationIdentitySupport
import Darwin
import Foundation
import Security
import StornautInvestigationHandoffContract
import StornautInvestigationInstalledL2
package enum InvestigationMachineDarwinAppIdentityObservationError:
    Error, Sendable, Equatable
{
    case invalidPreDropIdentity
    case invalidPostDropIdentity
    case physicalIdentityInvalid
    case observationUnavailable
    case executableIdentityInvalid
    case signingIdentityInvalid
}
struct InvestigationMachineDarwinAppNarrowIdentity: Sendable, Equatable {
    let processID: UInt32
    let processIDVersion: UInt32
    let auditSessionID: UInt32
    let effectiveUserID: UInt32
    let auditTokenWords: [UInt32]
}
struct InvestigationMachineDarwinAppProcessSnapshot: Sendable, Equatable {
    let processID: UInt32
    let parentProcessID: UInt32
    let processGroupID: UInt32
    let realUserID: UInt32
    let effectiveUserID: UInt32
    let savedUserID: UInt32
    let realGroupID: UInt32
    let effectiveGroupID: UInt32
    let savedGroupID: UInt32
    let auditUserID: UInt32
    let auditSessionID: UInt32
    let startTimeSeconds: UInt64
    let startTimeMicroseconds: UInt64
    let supplementaryGroups: [UInt32]
}
struct InvestigationMachineDarwinAppLiveSigningObservation: Sendable, Equatable {
    let processID: UInt32
    let identity: InvestigationInstalledL2SigningIdentity
}
enum InvestigationMachineDarwinAppLiveSigningResult: Sendable, Equatable {
    case observed(InvestigationMachineDarwinAppLiveSigningObservation)
    case invalid
    case unavailable
}
struct InvestigationMachineDarwinAppResolvedIdentity: Sendable, Equatable {
    let username: String
    let userID: UInt32
    let groupID: UInt32
    let supplementaryGroups: [UInt32]
}
enum InvestigationMachineDarwinAppResolvedIdentityResult: Sendable, Equatable {
    case observed(InvestigationMachineDarwinAppResolvedIdentity)
    case invalid
    case unavailable
}
protocol InvestigationMachineDarwinAppIdentitySystem: Sendable {
    func currentProcessID() -> UInt32
    func resolvedAppIdentity()
        -> InvestigationMachineDarwinAppResolvedIdentityResult
    func narrowIdentity(
        processID: UInt32
    ) -> Result<
        InvestigationMachineDarwinAppNarrowIdentity,
        InvestigationMachineDarwinAppIdentityObservationError
    >
    func snapshot(
        processID: UInt32
    ) -> Result<
        InvestigationMachineDarwinAppProcessSnapshot,
        InvestigationMachineDarwinAppIdentityObservationError
    >
    func executableURL(
        processID: UInt32
    ) -> Result<URL, InvestigationMachineDarwinAppIdentityObservationError>
    func executableObservation(
        expectedSHA256: InvestigationHandoffSHA256
    ) -> InvestigationInstalledL2ArtifactObservation
    func staticSigning() -> InvestigationInstalledL2StaticSigningResult
    func liveSigning(
        processID: UInt32
    ) -> InvestigationMachineDarwinAppLiveSigningResult
}
package struct InvestigationMachineDarwinAppPreDropObservation:
    Sendable, Equatable
{
    fileprivate let processID: UInt32
    fileprivate let processIDVersion: UInt32
    fileprivate let auditSessionID: UInt32
    fileprivate let auditTokenWords: [UInt32]
    fileprivate let parentProcessID: UInt32
    fileprivate let processGroupID: UInt32
    fileprivate let startTimeSeconds: UInt64
    fileprivate let startTimeMicroseconds: UInt64
    fileprivate let staticSigning: InvestigationInstalledL2SigningIdentity
    fileprivate let projectionSHA256: InvestigationHandoffSHA256
    fileprivate let expectedAppIdentity:
        InvestigationMachineDarwinAppResolvedIdentity
}
package struct InvestigationMachineDarwinAppIdentityObserver: Sendable {
    private static let rootUserID: UInt32 = 0
    private static let rootGroupID: UInt32 = 0
    private static let appUserID: UInt32 = 501
    private static let appGroupID: UInt32 = 20
    private static let groupCount = 16
    private let system: any InvestigationMachineDarwinAppIdentitySystem
    package init() {
        system = DarwinInvestigationMachineAppIdentitySystem()
    }
    init(system: any InvestigationMachineDarwinAppIdentitySystem) {
        self.system = system
    }
    package func prepare(
        processClaim: InvestigationHandoffProcessClaim,
        projection: InvestigationInstalledL2IdentityProjection
    ) throws -> InvestigationMachineDarwinAppPreDropObservation {
        guard
            processClaim.effectiveUserID == Self.rootUserID,
            processClaim.processID > 1,
            processClaim.processIDVersion > 0,
            processClaim.auditSessionID > 0
        else {
            throw InvestigationMachineDarwinAppIdentityObservationError
                .invalidPreDropIdentity
        }
        let expectedAppIdentity = try resolvedAppIdentity(phase: .preDrop)
        let narrow = try value(system.narrowIdentity(
            processID: processClaim.processID
        ))
        guard narrowMatches(narrow, claim: processClaim) else {
            throw InvestigationMachineDarwinAppIdentityObservationError
                .invalidPreDropIdentity
        }
        let facts = try stableFacts(
            processID: processClaim.processID,
            expectedParentProcessID: system.currentProcessID(),
            projection: projection,
            phase: .preDrop
        )
        guard
            facts.snapshot.auditSessionID == processClaim.auditSessionID,
            facts.snapshot.effectiveUserID == processClaim.effectiveUserID,
            auditTokenMatches(narrow.auditTokenWords, snapshot: facts.snapshot)
        else {
            throw InvestigationMachineDarwinAppIdentityObservationError
                .invalidPreDropIdentity
        }
        let finalNarrow = try value(system.narrowIdentity(
            processID: processClaim.processID
        ))
        guard finalNarrow == narrow, narrowMatches(finalNarrow, claim: processClaim)
        else {
            throw InvestigationMachineDarwinAppIdentityObservationError
                .invalidPreDropIdentity
        }
        return InvestigationMachineDarwinAppPreDropObservation(
            processID: processClaim.processID,
            processIDVersion: processClaim.processIDVersion,
            auditSessionID: processClaim.auditSessionID,
            auditTokenWords: narrow.auditTokenWords,
            parentProcessID: facts.snapshot.parentProcessID,
            processGroupID: facts.snapshot.processGroupID,
            startTimeSeconds: facts.snapshot.startTimeSeconds,
            startTimeMicroseconds: facts.snapshot.startTimeMicroseconds,
            staticSigning: facts.staticSigning,
            projectionSHA256: projection.projectionSHA256,
            expectedAppIdentity: expectedAppIdentity
        )
    }
    package func observe(
        preDrop: InvestigationMachineDarwinAppPreDropObservation,
        processClaim: InvestigationHandoffProcessClaim,
        dropEvidence: InvestigationHandoffDropEvidence,
        projection: InvestigationInstalledL2IdentityProjection
    ) throws -> InvestigationMachineSingleEpochAppObservation {
        guard
            projection.projectionSHA256 == preDrop.projectionSHA256,
            processClaim.processID == preDrop.processID,
            processClaim.processIDVersion == preDrop.processIDVersion,
            processClaim.auditSessionID == preDrop.auditSessionID,
            processClaim.effectiveUserID == Self.appUserID,
            dropEvidence.auditTokenWords[0] == preDrop.auditTokenWords[0],
            dropEvidenceMatches(
                dropEvidence,
                claim: processClaim,
                preDrop: preDrop
            )
        else {
            throw InvestigationMachineDarwinAppIdentityObservationError
                .invalidPostDropIdentity
        }
        let initialNarrow = try value(
            system.narrowIdentity(processID: processClaim.processID)
        )
        guard
            narrowMatches(initialNarrow, claim: processClaim),
            initialNarrow.auditTokenWords == dropEvidence.auditTokenWords
        else {
            throw InvestigationMachineDarwinAppIdentityObservationError
                .invalidPostDropIdentity
        }
        let resolvedAppIdentity = try resolvedAppIdentity(phase: .postDrop)
        let facts = try stableFacts(
            processID: processClaim.processID,
            expectedParentProcessID: preDrop.parentProcessID,
            projection: projection,
            phase: .postDrop
        )
        guard
            resolvedAppIdentity == preDrop.expectedAppIdentity,
            facts.snapshot.supplementaryGroups
                == preDrop.expectedAppIdentity.supplementaryGroups,
            dropEvidence.supplementaryGroups
                == preDrop.expectedAppIdentity.supplementaryGroups,
            facts.snapshot.auditSessionID == preDrop.auditSessionID,
            facts.snapshot.processGroupID == preDrop.processGroupID,
            facts.snapshot.startTimeSeconds == preDrop.startTimeSeconds,
            facts.snapshot.startTimeMicroseconds
                == preDrop.startTimeMicroseconds,
            facts.staticSigning == preDrop.staticSigning,
            auditTokenMatches(
                dropEvidence.auditTokenWords,
                snapshot: facts.snapshot
            )
        else {
            throw InvestigationMachineDarwinAppIdentityObservationError
                .invalidPostDropIdentity
        }
        let finalNarrow = try value(
            system.narrowIdentity(processID: processClaim.processID)
        )
        guard
            finalNarrow == initialNarrow,
            narrowMatches(finalNarrow, claim: processClaim),
            finalNarrow.auditTokenWords == dropEvidence.auditTokenWords
        else {
            throw InvestigationMachineDarwinAppIdentityObservationError
                .invalidPostDropIdentity
        }
        let identity: InvestigationMachineProcessIdentity
        do {
            identity = try InvestigationMachineProcessIdentity(
                role: .app,
                processID: processClaim.processID,
                processIDVersion: processClaim.processIDVersion,
                auditSessionID: processClaim.auditSessionID,
                effectiveUserID: processClaim.effectiveUserID,
                auditTokenWords: dropEvidence.auditTokenWords
            )
        } catch {
            throw InvestigationMachineDarwinAppIdentityObservationError
                .invalidPostDropIdentity
        }
        return InvestigationMachineSingleEpochAppObservation(identity: identity)
    }
    private enum Phase {
        case preDrop
        case postDrop
    }
    private struct StableFacts {
        let snapshot: InvestigationMachineDarwinAppProcessSnapshot
        let staticSigning: InvestigationInstalledL2SigningIdentity
    }
    private func stableFacts(
        processID: UInt32,
        expectedParentProcessID: UInt32,
        projection: InvestigationInstalledL2IdentityProjection,
        phase: Phase
    ) throws -> StableFacts {
        guard expectedParentProcessID > 1 else {
            throw InvestigationMachineDarwinAppIdentityObservationError
                .observationUnavailable
        }
        let initial = try snapshot(processID: processID, phase: phase)
        guard valid(
            initial,
            processID: processID,
            parentProcessID: expectedParentProcessID,
            phase: phase
        )
        else {
            throw phaseIdentityError(phase)
        }
        let expectedURL = InvestigationInstalledL2FixedPaths().appExecutable
            .standardizedFileURL
        let initialURL = try value(system.executableURL(processID: processID))
            .standardizedFileURL
        guard initialURL == expectedURL else {
            throw InvestigationMachineDarwinAppIdentityObservationError
                .executableIdentityInvalid
        }
        switch system.executableObservation(
            expectedSHA256: projection.appExecutableSHA256
        ) {
        case .presentValid:
            break
        case .unavailable:
            throw InvestigationMachineDarwinAppIdentityObservationError
                .observationUnavailable
        case .absent, .invalid:
            throw InvestigationMachineDarwinAppIdentityObservationError
                .executableIdentityInvalid
        }
        let staticSigning: InvestigationInstalledL2SigningIdentity
        switch system.staticSigning() {
        case .observed(let identity):
            staticSigning = identity
        case .unavailable:
            throw InvestigationMachineDarwinAppIdentityObservationError
                .observationUnavailable
        case .invalid:
            throw InvestigationMachineDarwinAppIdentityObservationError
                .signingIdentityInvalid
        }
        let live: InvestigationMachineDarwinAppLiveSigningObservation
        switch system.liveSigning(processID: processID) {
        case .observed(let observation):
            live = observation
        case .unavailable:
            throw InvestigationMachineDarwinAppIdentityObservationError
                .observationUnavailable
        case .invalid:
            throw InvestigationMachineDarwinAppIdentityObservationError
                .signingIdentityInvalid
        }
        guard
            staticSigning.signingIdentifier == projection.appBundleIdentifier,
            live.processID == processID,
            live.identity == staticSigning
        else {
            throw InvestigationMachineDarwinAppIdentityObservationError
                .signingIdentityInvalid
        }
        switch system.executableObservation(
            expectedSHA256: projection.appExecutableSHA256
        ) {
        case .presentValid:
            break
        case .unavailable:
            throw InvestigationMachineDarwinAppIdentityObservationError
                .observationUnavailable
        case .absent, .invalid:
            throw InvestigationMachineDarwinAppIdentityObservationError
                .executableIdentityInvalid
        }
        let finalStaticSigning: InvestigationInstalledL2SigningIdentity
        switch system.staticSigning() {
        case .observed(let identity):
            finalStaticSigning = identity
        case .unavailable:
            throw InvestigationMachineDarwinAppIdentityObservationError
                .observationUnavailable
        case .invalid:
            throw InvestigationMachineDarwinAppIdentityObservationError
                .signingIdentityInvalid
        }
        let finalURL = try value(system.executableURL(processID: processID))
            .standardizedFileURL
        let final = try snapshot(processID: processID, phase: phase)
        guard finalURL == initialURL, finalURL == expectedURL else {
            throw InvestigationMachineDarwinAppIdentityObservationError
                .executableIdentityInvalid
        }
        guard finalStaticSigning == staticSigning else {
            throw InvestigationMachineDarwinAppIdentityObservationError
                .signingIdentityInvalid
        }
        guard final == initial, valid(
            final,
            processID: processID,
            parentProcessID: expectedParentProcessID,
            phase: phase
        ) else {
            throw phaseIdentityError(phase)
        }
        return StableFacts(snapshot: final, staticSigning: staticSigning)
    }
    private func valid(
        _ snapshot: InvestigationMachineDarwinAppProcessSnapshot,
        processID: UInt32,
        parentProcessID: UInt32,
        phase: Phase
    ) -> Bool {
        guard
            snapshot.processID == processID,
            snapshot.parentProcessID == parentProcessID,
            snapshot.processGroupID == processID,
            snapshot.auditSessionID > 0,
            snapshot.startTimeSeconds > 0,
            snapshot.startTimeMicroseconds < 1_000_000,
            !snapshot.supplementaryGroups.isEmpty,
            snapshot.supplementaryGroups.count <= Self.groupCount,
            snapshot.supplementaryGroups
                == snapshot.supplementaryGroups.sorted(),
            Set(snapshot.supplementaryGroups).count
                == snapshot.supplementaryGroups.count
        else {
            return false
        }
        switch phase {
        case .preDrop:
            return snapshot.realUserID == Self.rootUserID
                && snapshot.effectiveUserID == Self.rootUserID
                && snapshot.savedUserID == Self.rootUserID
                && snapshot.realGroupID == Self.rootGroupID
                && snapshot.effectiveGroupID == Self.rootGroupID
                && snapshot.savedGroupID == Self.rootGroupID
                && snapshot.supplementaryGroups.contains(Self.rootGroupID)
        case .postDrop:
            return snapshot.realUserID == Self.appUserID
                && snapshot.effectiveUserID == Self.appUserID
                && snapshot.savedUserID == Self.appUserID
                && snapshot.realGroupID == Self.appGroupID
                && snapshot.effectiveGroupID == Self.appGroupID
                && snapshot.savedGroupID == Self.appGroupID
                && snapshot.supplementaryGroups.count == Self.groupCount
                && snapshot.supplementaryGroups.contains(Self.appGroupID)
        }
    }
    private func narrowMatches(
        _ identity: InvestigationMachineDarwinAppNarrowIdentity,
        claim: InvestigationHandoffProcessClaim
    ) -> Bool {
        identity.processID == claim.processID
            && identity.processIDVersion == claim.processIDVersion
            && identity.auditSessionID == claim.auditSessionID
            && identity.effectiveUserID == claim.effectiveUserID
            && identity.auditTokenWords.count == 8
            && identity.auditTokenWords[1] == claim.effectiveUserID
            && identity.auditTokenWords[5] == claim.processID
            && identity.auditTokenWords[6] == claim.auditSessionID
            && identity.auditTokenWords[7] == claim.processIDVersion
    }
    private func auditTokenMatches(
        _ words: [UInt32],
        snapshot: InvestigationMachineDarwinAppProcessSnapshot
    ) -> Bool {
        words.count == 8
            && words[0] == snapshot.auditUserID
            && words[1] == snapshot.effectiveUserID
            && words[2] == snapshot.effectiveGroupID
            && words[3] == snapshot.realUserID
            && words[4] == snapshot.realGroupID
            && words[5] == snapshot.processID
            && words[6] == snapshot.auditSessionID
    }
    private func dropEvidenceMatches(
        _ evidence: InvestigationHandoffDropEvidence,
        claim: InvestigationHandoffProcessClaim,
        preDrop: InvestigationMachineDarwinAppPreDropObservation
    ) -> Bool {
        evidence.realUserID == Self.appUserID
            && evidence.effectiveUserID == Self.appUserID
            && evidence.savedUserID == Self.appUserID
            && evidence.realGroupID == Self.appGroupID
            && evidence.effectiveGroupID == Self.appGroupID
            && evidence.savedGroupID == Self.appGroupID
            && evidence.supplementaryGroups.count == Self.groupCount
            && evidence.supplementaryGroups
                == evidence.supplementaryGroups.sorted()
            && Set(evidence.supplementaryGroups).count == Self.groupCount
            && evidence.supplementaryGroups.contains(Self.appGroupID)
            && evidence.auditTokenWords.count == 8
            && evidence.auditTokenWords[1] == claim.effectiveUserID
            && evidence.auditTokenWords[2] == Self.appGroupID
            && evidence.auditTokenWords[3] == Self.appUserID
            && evidence.auditTokenWords[4] == Self.appGroupID
            && evidence.auditTokenWords[5] == claim.processID
            && evidence.auditTokenWords[6] == preDrop.auditSessionID
            && evidence.auditTokenWords[7] == preDrop.processIDVersion
    }
    private func phaseIdentityError(
        _ phase: Phase
    ) -> InvestigationMachineDarwinAppIdentityObservationError {
        switch phase {
        case .preDrop: .invalidPreDropIdentity
        case .postDrop: .invalidPostDropIdentity
        }
    }
    private func resolvedAppIdentity(
        phase: Phase
    ) throws -> InvestigationMachineDarwinAppResolvedIdentity {
        switch system.resolvedAppIdentity() {
        case .observed(let identity):
            guard
                !identity.username.isEmpty,
                identity.username.utf8.count <= 255,
                identity.userID == Self.appUserID,
                identity.groupID == Self.appGroupID,
                identity.supplementaryGroups.count == Self.groupCount,
                identity.supplementaryGroups
                    == identity.supplementaryGroups.sorted(),
                Set(identity.supplementaryGroups).count == Self.groupCount,
                identity.supplementaryGroups.contains(Self.appGroupID)
            else {
                throw phaseIdentityError(phase)
            }
            return identity
        case .invalid:
            throw phaseIdentityError(phase)
        case .unavailable:
            throw InvestigationMachineDarwinAppIdentityObservationError
                .observationUnavailable
        }
    }
    private func value<Value>(
        _ result: Result<
            Value,
            InvestigationMachineDarwinAppIdentityObservationError
        >
    ) throws -> Value {
        try result.get()
    }
    private func snapshot(
        processID: UInt32,
        phase: Phase
    ) throws -> InvestigationMachineDarwinAppProcessSnapshot {
        switch system.snapshot(processID: processID) {
        case .success(let snapshot): return snapshot
        case .failure(.physicalIdentityInvalid): throw phaseIdentityError(phase)
        case .failure(let error): throw error
        }
    }
}
struct DarwinInvestigationMachineAppIdentitySystem:
    InvestigationMachineDarwinAppIdentitySystem,
    Sendable
{
    private let paths = InvestigationInstalledL2FixedPaths()
    func currentProcessID() -> UInt32 { UInt32(getpid()) }
    func resolvedAppIdentity()
        -> InvestigationMachineDarwinAppResolvedIdentityResult
    {
        let targetUserID: uid_t = 501
        let expectedGroupID: gid_t = 20
        var record = passwd()
        var result: UnsafeMutablePointer<passwd>?
        var capacity = 1_024
        while capacity <= 64 * 1_024 {
            var buffer = [CChar](repeating: 0, count: capacity)
            let status = getpwuid_r(
                targetUserID,
                &record,
                &buffer,
                buffer.count,
                &result
            )
            if status == ERANGE {
                capacity *= 2
                continue
            }
            guard status == 0 else { return .unavailable }
            guard
                result != nil,
                record.pw_uid == targetUserID,
                record.pw_gid == expectedGroupID,
                let namePointer = record.pw_name
            else {
                return .invalid
            }
            let username = String(cString: namePointer)
            guard !username.isEmpty, username.utf8.count <= 255 else {
                return .invalid
            }
            var groups = [gid_t](repeating: 0, count: 64)
            var groupCount = Int32(groups.count)
            let groupStatus = username.withCString { name in
                getgrouplist(
                    name,
                    Int32(record.pw_gid),
                    &groups,
                    &groupCount
                )
            }
            guard
                groupStatus >= 0,
                groupCount == 17,
                NGROUPS_MAX == 16
            else {
                return .invalid
            }
            guard let selectedGroups = Self.selectedSupplementaryGroups(
                from: Array(groups.prefix(Int(groupCount))),
                expectedGroupID: expectedGroupID
            ) else {
                return .invalid
            }
            return .observed(.init(
                username: username,
                userID: UInt32(record.pw_uid),
                groupID: UInt32(record.pw_gid),
                supplementaryGroups: selectedGroups
            ))
        }
        return .unavailable
    }
    static func selectedSupplementaryGroups(
        from returnedGroups: [gid_t],
        expectedGroupID: gid_t = 20
    ) -> [UInt32]? {
        guard
            returnedGroups.count == 17,
            Set(returnedGroups).count == 17,
            NGROUPS_MAX == 16
        else {
            return nil
        }
        let selected = Array(returnedGroups.prefix(Int(NGROUPS_MAX)))
        guard
            selected.count == Int(NGROUPS_MAX),
            selected.contains(expectedGroupID)
        else {
            return nil
        }
        return selected.map { UInt32($0) }.sorted()
    }
    func narrowIdentity(
        processID: UInt32
    ) -> Result<
        InvestigationMachineDarwinAppNarrowIdentity,
        InvestigationMachineDarwinAppIdentityObservationError
    > {
        guard processID > 1, processID <= UInt32(Int32.max) else {
            return .failure(.observationUnavailable)
        }
        var raw = stornaut_investigation_identity()
        guard stornaut_investigation_identity_for_pid(
            pid_t(processID),
            &raw
        ) == 0 else {
            return .failure(.observationUnavailable)
        }
        let words = withUnsafeBytes(of: raw.audit_token_words) { bytes in
            Array(bytes.bindMemory(to: UInt32.self))
        }
        guard
            raw.process_id > 1,
            raw.process_id_version > 0,
            raw.audit_session_id > 0,
            words.count == 8
        else {
            return .failure(.observationUnavailable)
        }
        return .success(.init(
            processID: UInt32(raw.process_id),
            processIDVersion: UInt32(raw.process_id_version),
            auditSessionID: UInt32(raw.audit_session_id),
            effectiveUserID: UInt32(raw.effective_user_id),
            auditTokenWords: words
        ))
    }
    func snapshot(
        processID: UInt32
    ) -> Result<
        InvestigationMachineDarwinAppProcessSnapshot,
        InvestigationMachineDarwinAppIdentityObservationError
    > {
        guard processID > 1, processID <= UInt32(Int32.max) else {
            return .failure(.observationUnavailable)
        }
        var raw = stornaut_investigation_process_snapshot()
        let status = stornaut_investigation_process_snapshot_for_pid(
            pid_t(processID),
            &raw
        )
        guard status == 0 else {
            return .failure(
                status == STORNAUT_INVESTIGATION_IDENTITY_MISMATCH
                    ? .physicalIdentityInvalid : .observationUnavailable
            )
        }
        guard raw.process_id > 1, raw.audit_session_id > 0 else {
            return .failure(.observationUnavailable)
        }
        let count = Int(raw.supplementary_group_count)
        let allGroups = withUnsafeBytes(of: raw.supplementary_groups) { bytes in
            Array(bytes.bindMemory(to: gid_t.self))
        }
        guard (1...16).contains(count), allGroups.count == 16 else {
            return .failure(.observationUnavailable)
        }
        guard
            let parentProcessID = UInt32(exactly: raw.parent_process_id),
            let processGroupID = UInt32(exactly: raw.process_group_id),
            let auditSessionID = UInt32(exactly: raw.audit_session_id)
        else {
            return .failure(.observationUnavailable)
        }
        var groups: [UInt32] = []
        groups.reserveCapacity(count)
        for index in 0..<count {
            groups.append(UInt32(allGroups[index]))
        }
        groups.sort()
        return .success(.init(
            processID: UInt32(raw.process_id),
            parentProcessID: parentProcessID,
            processGroupID: processGroupID,
            realUserID: UInt32(raw.real_user_id),
            effectiveUserID: UInt32(raw.effective_user_id),
            savedUserID: UInt32(raw.saved_user_id),
            realGroupID: UInt32(raw.real_group_id),
            effectiveGroupID: UInt32(raw.effective_group_id),
            savedGroupID: UInt32(raw.saved_group_id),
            auditUserID: UInt32(raw.audit_user_id),
            auditSessionID: auditSessionID,
            startTimeSeconds: raw.start_time_seconds,
            startTimeMicroseconds: raw.start_time_microseconds,
            supplementaryGroups: groups
        ))
    }
    func executableURL(
        processID: UInt32
    ) -> Result<URL, InvestigationMachineDarwinAppIdentityObservationError> {
        guard processID > 1, processID <= UInt32(Int32.max) else {
            return .failure(.observationUnavailable)
        }
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let count = buffer.withUnsafeMutableBytes { bytes in
            proc_pidpath(
                pid_t(processID),
                bytes.baseAddress,
                UInt32(bytes.count)
            )
        }
        guard count > 0 else { return .failure(.observationUnavailable) }
        let returned = buffer.prefix(Int(count))
        let pathBytes: ArraySlice<CChar>
        if let terminator = returned.firstIndex(of: 0) {
            guard returned[terminator...].allSatisfy({ $0 == 0 }) else {
                return .failure(.observationUnavailable)
            }
            pathBytes = returned[..<terminator]
        } else {
            pathBytes = returned
        }
        let utf8 = pathBytes.map { UInt8(bitPattern: $0) }
        guard
            let path = String(bytes: utf8, encoding: .utf8),
            path.utf8.count == utf8.count,
            path.hasPrefix("/")
        else {
            return .failure(.observationUnavailable)
        }
        return .success(URL(fileURLWithPath: path).standardizedFileURL)
    }
    func executableObservation(
        expectedSHA256: InvestigationHandoffSHA256
    ) -> InvestigationInstalledL2ArtifactObservation {
        let expectation: InvestigationInstalledL2NodeExpectation
        do {
            expectation = try InvestigationInstalledL2NodeExpectation(
                url: paths.appExecutable,
                kind: .regularFile,
                ownerUserID: 0,
                ownerGroupID: 0,
                mode: 0o755,
                requiresSingleLink: true,
                expectedSHA256: expectedSHA256,
                maximumSize:
                    InvestigationInstalledL2ArtifactReader.maximumExecutableBytes
            )
        } catch {
            return .invalid
        }
        return InvestigationInstalledL2NodeReader().observe(expectation)
    }
    func staticSigning() -> InvestigationInstalledL2StaticSigningResult {
        InvestigationInstalledL2StaticSigningReader().read(
            at: paths.appExecutable
        )
    }
    func liveSigning(
        processID: UInt32
    ) -> InvestigationMachineDarwinAppLiveSigningResult {
        guard processID > 1, processID <= UInt32(Int32.max) else {
            return .invalid
        }
        let attributes: [CFString: Any] = [
            kSecGuestAttributePid: NSNumber(value: pid_t(processID)),
        ]
        var dynamicCode: SecCode?
        guard
            SecCodeCopyGuestWithAttributes(
                nil,
                attributes as CFDictionary,
                SecCSFlags(),
                &dynamicCode
            ) == errSecSuccess,
            let dynamicCode
        else {
            return .unavailable
        }
        guard SecCodeCheckValidity(
            dynamicCode,
            SecCSFlags(rawValue: kSecCSStrictValidate),
            nil
        ) == errSecSuccess else {
            return .invalid
        }
        var staticCode: SecStaticCode?
        guard
            SecCodeCopyStaticCode(dynamicCode, SecCSFlags(), &staticCode)
                == errSecSuccess,
            let staticCode,
            SecStaticCodeCheckValidity(
                staticCode,
                SecCSFlags(rawValue: kSecCSStrictValidate),
                nil
            ) == errSecSuccess
        else {
            return .invalid
        }
        var information: CFDictionary?
        let flags = SecCSFlags(
            rawValue: kSecCSSigningInformation | kSecCSRequirementInformation
        )
        guard
            SecCodeCopySigningInformation(staticCode, flags, &information)
                == errSecSuccess,
            let dictionary = information as? [CFString: Any],
            let identifier = dictionary[kSecCodeInfoIdentifier] as? String,
            let codeDirectoryHash = dictionary[kSecCodeInfoUnique] as? Data,
            let signatureFlags = dictionary[kSecCodeInfoFlags] as? NSNumber,
            let requirement = Self.requirement(
                dictionary[kSecCodeInfoDesignatedRequirement]
            ),
            let requirementData = Self.requirementData(requirement),
            let identity = try? InvestigationInstalledL2SigningIdentity(
                signingIdentifier: identifier,
                designatedRequirementSHA256:
                    InvestigationHandoffSHA256.hashing(requirementData),
                codeDirectoryHash: codeDirectoryHash,
                isAdHoc: signatureFlags.uint32Value & 0x0002 != 0
            )
        else {
            return .invalid
        }
        return .observed(.init(
            processID: processID,
            identity: identity
        ))
    }
    private static func requirement(_ value: Any?) -> SecRequirement? {
        guard let value else { return nil }
        let object = value as AnyObject
        guard CFGetTypeID(object) == SecRequirementGetTypeID() else {
            return nil
        }
        return unsafeDowncast(object, to: SecRequirement.self)
    }
    private static func requirementData(
        _ requirement: SecRequirement
    ) -> Data? {
        var data: CFData?
        guard SecRequirementCopyData(
            requirement,
            SecCSFlags(),
            &data
        ) == errSecSuccess, let data else {
            return nil
        }
        return data as Data
    }
}
