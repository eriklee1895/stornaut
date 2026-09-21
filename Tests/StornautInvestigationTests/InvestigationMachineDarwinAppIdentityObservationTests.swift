import Darwin
import Foundation
import Testing
@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationInstalledL2
@testable import StornautInvestigationMachineDriverSupport
@Suite("Investigation machine Darwin App identity observation", .serialized)
struct InvestigationMachineDarwinAppIdentityObservationTests {
    @Test
    func exactRootToAppObservationUsesIndependentStableEvidence() throws {
        let fixture = try DarwinAppIdentityFixture()
        let preSystem = fixture.system(
            narrows: [fixture.preDropNarrow, fixture.preDropNarrow],
            snapshots: [
                .success(fixture.preDropSnapshot),
                .success(fixture.preDropSnapshot),
            ],
            liveSigning: fixture.liveSigning
        )
        let preDrop = try InvestigationMachineDarwinAppIdentityObserver(
            system: preSystem
        ).prepare(
            processClaim: fixture.preDropClaim,
            projection: fixture.projection
        )
        #expect(preSystem.calls == [
            "resolved-app-identity", "narrow:701", "current-pid",
            "snapshot:701", "path:701",
            "artifact", "static-signing", "live-signing:701",
            "artifact", "static-signing", "path:701", "snapshot:701",
            "narrow:701",
        ])
        let postSystem = fixture.system(
            snapshots: [
                .success(fixture.postDropSnapshot),
                .success(fixture.postDropSnapshot),
            ],
            liveSigning: fixture.liveSigning
        )
        let observation = try InvestigationMachineDarwinAppIdentityObserver(
            system: postSystem
        ).observe(
            preDrop: preDrop,
            processClaim: fixture.postDropClaim,
            dropEvidence: fixture.dropEvidence,
            projection: fixture.projection
        )
        #expect(observation == InvestigationMachineSingleEpochAppObservation(
            identity: fixture.appIdentity
        ))
        #expect(postSystem.calls == [
            "narrow:701", "resolved-app-identity", "snapshot:701",
            "path:701", "artifact", "static-signing", "live-signing:701",
            "artifact", "static-signing", "path:701", "snapshot:701",
            "narrow:701",
        ])
        #expect(!(type(of: observation) is any Codable.Type))
        #expect(!(type(of: preDrop) is any Codable.Type))
    }
    @Test
    func inheritedProcessGroupTopologyUsesFactoryOwnedExpectations() throws {
        let fixture = try DarwinAppIdentityFixture()
        let parentProcessID = fixture.inheritedParentProcessID
        let processGroupID = fixture.inheritedProcessGroupID
        let preDrop = try fixture.preDropObservation(
            expectedParentProcessID: parentProcessID,
            expectedProcessGroupID: processGroupID
        )
        let postDropSnapshot = fixture.makePostDropSnapshot(
            parentProcessID: parentProcessID,
            processGroupID: processGroupID
        )

        let observation = try fixture.observe(
            system: fixture.system(snapshots: [
                .success(postDropSnapshot), .success(postDropSnapshot),
            ]),
            preDrop: preDrop
        )

        #expect(fixture.processID != processGroupID)
        #expect(observation == InvestigationMachineSingleEpochAppObservation(
            identity: fixture.appIdentity
        ))
    }
    @Test(arguments: DarwinAppExpectedTopologyMismatch.allCases)
    fileprivate func inheritedTopologyRejectsWrongExpectedParentOrGroup(
        _ mismatch: DarwinAppExpectedTopologyMismatch
    ) throws {
        let fixture = try DarwinAppIdentityFixture()
        let snapshot = fixture.makePreDropSnapshot(
            parentProcessID: fixture.inheritedParentProcessID,
            processGroupID: fixture.inheritedProcessGroupID
        )
        let expectedParentProcessID = mismatch == .parentProcessID
            ? fixture.inheritedParentProcessID + 1
            : fixture.inheritedParentProcessID
        let expectedProcessGroupID = mismatch == .processGroupID
            ? fixture.inheritedProcessGroupID + 1
            : fixture.inheritedProcessGroupID
        let system = fixture.system(
            narrows: [fixture.preDropNarrow, fixture.preDropNarrow],
            snapshots: [.success(snapshot), .success(snapshot)],
            liveSigning: fixture.liveSigning
        )

        #expect(
            throws: InvestigationMachineDarwinAppIdentityObservationError
                .invalidPreDropIdentity
        ) {
            _ = try InvestigationMachineDarwinAppIdentityObserver(
                system: system
            ).prepare(
                processClaim: fixture.preDropClaim,
                projection: fixture.projection,
                expectedParentProcessID: expectedParentProcessID,
                expectedProcessGroupID: expectedProcessGroupID
            )
        }
    }
    @Test(arguments: DarwinAppInheritedTopologyDrift.allCases)
    fileprivate func inheritedTopologyRejectsPreAndPostObservationDrift(
        _ drift: DarwinAppInheritedTopologyDrift
    ) throws {
        let fixture = try DarwinAppIdentityFixture()
        let parentProcessID = fixture.inheritedParentProcessID
        let processGroupID = fixture.inheritedProcessGroupID

        switch drift {
        case .preDropParent, .preDropGroup:
            let initial = fixture.makePreDropSnapshot(
                parentProcessID: parentProcessID,
                processGroupID: processGroupID
            )
            let final = fixture.makePreDropSnapshot(
                parentProcessID: drift == .preDropParent
                    ? parentProcessID + 1 : parentProcessID,
                processGroupID: drift == .preDropGroup
                    ? processGroupID + 1 : processGroupID
            )
            let system = fixture.system(
                narrows: [fixture.preDropNarrow, fixture.preDropNarrow],
                snapshots: [.success(initial), .success(final)],
                liveSigning: fixture.liveSigning
            )
            #expect(
                throws: InvestigationMachineDarwinAppIdentityObservationError
                    .invalidPreDropIdentity
            ) {
                _ = try InvestigationMachineDarwinAppIdentityObserver(
                    system: system
                ).prepare(
                    processClaim: fixture.preDropClaim,
                    projection: fixture.projection,
                    expectedParentProcessID: parentProcessID,
                    expectedProcessGroupID: processGroupID
                )
            }
        case .postDropParent, .postDropGroup:
            let preDrop = try fixture.preDropObservation(
                expectedParentProcessID: parentProcessID,
                expectedProcessGroupID: processGroupID
            )
            let initial = fixture.makePostDropSnapshot(
                parentProcessID: parentProcessID,
                processGroupID: processGroupID
            )
            let final = fixture.makePostDropSnapshot(
                parentProcessID: drift == .postDropParent
                    ? parentProcessID + 1 : parentProcessID,
                processGroupID: drift == .postDropGroup
                    ? processGroupID + 1 : processGroupID
            )
            let system = fixture.system(snapshots: [
                .success(initial), .success(final),
            ])
            #expect(
                throws: InvestigationMachineDarwinAppIdentityObservationError
                    .invalidPostDropIdentity
            ) {
                _ = try fixture.observe(system: system, preDrop: preDrop)
            }
        }
    }
    @Test(arguments: DarwinAppIdentitySnapshotMutation.allCases)
    fileprivate func everyIndependentPostDropIdentityAxisFailsClosed(
        _ mutation: DarwinAppIdentitySnapshotMutation
    ) throws {
        let fixture = try DarwinAppIdentityFixture()
        let preDrop = try fixture.preDropObservation()
        let changed = fixture.postDropSnapshot(mutating: mutation)
        let system = fixture.system(
            snapshots: [.success(changed), .success(changed)],
            liveSigning: fixture.liveSigning
        )
        #expect(throws: InvestigationMachineDarwinAppIdentityObservationError.self) {
            _ = try fixture.observe(system: system, preDrop: preDrop)
        }
    }
    @Test(arguments: DarwinAppPreDropSnapshotMutation.allCases)
    fileprivate func everyIndependentPreDropIdentityAxisFailsClosed(
        _ mutation: DarwinAppPreDropSnapshotMutation
    ) throws {
        let fixture = try DarwinAppIdentityFixture()
        let changed = fixture.preDropSnapshot(mutating: mutation)
        let system = fixture.system(
            narrows: [fixture.preDropNarrow],
            snapshots: [.success(changed), .success(changed)],
            liveSigning: fixture.liveSigning
        )
        #expect(throws: InvestigationMachineDarwinAppIdentityObservationError.self) {
            _ = try InvestigationMachineDarwinAppIdentityObserver(
                system: system
            ).prepare(
                processClaim: fixture.preDropClaim,
                projection: fixture.projection
            )
        }
    }
    @Test(arguments: DarwinAppIdentityRaceMutation.allCases)
    fileprivate func everyObservationRaceAndEvidenceFailureFailsClosed(
        _ mutation: DarwinAppIdentityRaceMutation
    ) throws {
        let fixture = try DarwinAppIdentityFixture()
        let preDrop = try fixture.preDropObservation()
        let initial = fixture.postDropSnapshot
        let changed = fixture.postDropSnapshot(mutating: .startTime)
        let system: RecordingDarwinAppIdentitySystem
        switch mutation {
        case .initialNarrow:
            system = fixture.system(narrows: [fixture.foreignPostDropNarrow])
        case .finalNarrow:
            system = fixture.system(narrows: [
                fixture.postDropNarrow, fixture.foreignPostDropNarrow,
            ])
        case .snapshot:
            system = fixture.system(
                snapshots: [.failure(.observationUnavailable)]
            )
        case .finalSnapshot:
            system = fixture.system(snapshots: [
                .success(initial), .success(changed),
            ])
        case .initialPath:
            system = fixture.system(paths: [.failure(.observationUnavailable)])
        case .finalPath:
            system = fixture.system(paths: [
                .success(fixture.appURL),
                .success(fixture.foreignURL),
            ])
        case .initialArtifact:
            system = fixture.system(artifacts: [.invalid])
        case .finalArtifact:
            system = fixture.system(artifacts: [.presentValid, .invalid])
        case .initialStaticSigning:
            system = fixture.system(staticSignings: [.invalid])
        case .finalStaticSigning:
            system = fixture.system(staticSignings: [
                .observed(fixture.signing), .observed(fixture.foreignSigning),
            ])
        case .liveSigning:
            system = fixture.system(liveSigning: .unavailable)
        case .liveProcess:
            system = fixture.system(liveSigning: .observed(.init(
                processID: 702, identity: fixture.signing
            )))
        case .liveIdentity:
            system = fixture.system(liveSigning: .observed(.init(
                processID: 701, identity: fixture.foreignSigning
            )))
        }
        #expect(throws: InvestigationMachineDarwinAppIdentityObservationError.self) {
            _ = try fixture.observe(system: system, preDrop: preDrop)
        }
    }
    @Test
    func reportedAuditIdentityAndProjectionCannotReplaceIndependentFacts() throws {
        let fixture = try DarwinAppIdentityFixture()
        let preDrop = try fixture.preDropObservation()
        let foreignAuditEvidence = try fixture.dropEvidence(auditUserID: 777)
        let system = fixture.system()
        #expect(throws: InvestigationMachineDarwinAppIdentityObservationError.self) {
            _ = try fixture.observe(
                system: system, preDrop: preDrop, evidence: foreignAuditEvidence
            )
        }
        #expect(system.calls.isEmpty)
        let foreignProjection = try fixture.projection(appDigestByte: 0x71)
        #expect(throws: InvestigationMachineDarwinAppIdentityObservationError.self) {
            _ = try fixture.observe(
                system: system, preDrop: preDrop, projection: foreignProjection
            )
        }
        #expect(system.calls.isEmpty)
    }
    @Test
    func reportedGroupsMustExactlyMatchIndependentKernelGroups() throws {
        let fixture = try DarwinAppIdentityFixture()
        let preDrop = try fixture.preDropObservation()
        let differentGroups = Array(UInt32(1)...UInt32(14)) + [20, 21]
        let evidence = try fixture.dropEvidence(groups: differentGroups)
        let system = fixture.system()
        #expect(throws: InvestigationMachineDarwinAppIdentityObservationError.self) {
            _ = try fixture.observe(
                system: system, preDrop: preDrop, evidence: evidence
            )
        }
    }
    @Test
    func reportedAndKernelGroupsCannotReplaceIndependentDirectoryGroups() throws {
        let fixture = try DarwinAppIdentityFixture()
        let preDrop = try fixture.preDropObservation()
        let foreignGroups = Array(UInt32(2)...UInt32(16)) + [20]
        let foreignSnapshot = fixture.postDropSnapshot(groups: foreignGroups)
        let evidence = try fixture.dropEvidence(groups: foreignGroups)
        let system = fixture.system(snapshots: [
            .success(foreignSnapshot), .success(foreignSnapshot),
        ])
        #expect(
            throws: InvestigationMachineDarwinAppIdentityObservationError
                .invalidPostDropIdentity
        ) {
            _ = try fixture.observe(
                system: system, preDrop: preDrop, evidence: evidence
            )
        }
    }
    @Test(arguments: DarwinAppUnavailableObservationSample.allCases)
    fileprivate func unavailablePhysicalEvidenceHasExactError(
        _ sample: DarwinAppUnavailableObservationSample
    ) throws {
        let fixture = try DarwinAppIdentityFixture()
        let preDrop = try fixture.preDropObservation()
        #expect(
            throws: InvestigationMachineDarwinAppIdentityObservationError
                .observationUnavailable
        ) {
            _ = try fixture.observe(
                system: sample.system(fixture: fixture), preDrop: preDrop
            )
        }
    }
    @Test(arguments: DarwinAppInvalidObservationSample.allCases)
    fileprivate func invalidPhysicalEvidenceHasExactError(
        _ sample: DarwinAppInvalidObservationSample
    ) throws {
        let fixture = try DarwinAppIdentityFixture()
        let preDrop = try fixture.preDropObservation()
        #expect(throws: sample.expectedError) {
            _ = try fixture.observe(
                system: sample.system(fixture: fixture), preDrop: preDrop
            )
        }
    }
    @Test(arguments: DarwinAppResolvedIdentityFailureSample.allCases)
    fileprivate func resolvedIdentityFailureHasPhaseExactError(
        _ sample: DarwinAppResolvedIdentityFailureSample
    ) throws {
        let fixture = try DarwinAppIdentityFixture()
        if sample.isUnavailable {
            #expect(
                throws: InvestigationMachineDarwinAppIdentityObservationError
                    .observationUnavailable
            ) {
                _ = try sample.perform(fixture: fixture)
            }
        } else {
            #expect(throws: sample.expectedPhaseError) {
                _ = try sample.perform(fixture: fixture)
            }
        }
    }
    @Test
    func wrongPreDropClaimFailsBeforePhysicalObservation() throws {
        let fixture = try DarwinAppIdentityFixture()
        let system = fixture.system()
        #expect(throws: InvestigationMachineDarwinAppIdentityObservationError.self) {
            _ = try InvestigationMachineDarwinAppIdentityObserver(
                system: system
            ).prepare(
                processClaim: fixture.postDropClaim,
                projection: fixture.projection
            )
        }
        #expect(system.calls.isEmpty)
    }
    @Test
    func preDropNarrowIdentityMustRemainStableAcrossObservation() throws {
        let fixture = try DarwinAppIdentityFixture()
        var changedWords = fixture.preDropNarrow.auditTokenWords
        changedWords[7] += 1
        let changed = InvestigationMachineDarwinAppNarrowIdentity(
            processID: fixture.preDropNarrow.processID,
            processIDVersion: fixture.preDropNarrow.processIDVersion,
            auditSessionID: fixture.preDropNarrow.auditSessionID,
            effectiveUserID: fixture.preDropNarrow.effectiveUserID,
            auditTokenWords: changedWords
        )
        let system = fixture.system(
            narrows: [fixture.preDropNarrow, changed],
            snapshots: [
                .success(fixture.preDropSnapshot),
                .success(fixture.preDropSnapshot),
            ],
            liveSigning: fixture.liveSigning
        )
        #expect(throws: InvestigationMachineDarwinAppIdentityObservationError.self) {
            _ = try InvestigationMachineDarwinAppIdentityObserver(
                system: system
            ).prepare(
                processClaim: fixture.preDropClaim,
                projection: fixture.projection
            )
        }
        #expect(system.calls.last == "narrow:701")
    }
    @Test
    func concreteReadOnlySystemObservesCurrentExecutableAndSigning() throws {
        let system = DarwinInvestigationMachineAppIdentitySystem()
        let processID = UInt32(getpid())
        switch system.resolvedAppIdentity() {
        case .observed(let identity):
            #expect(identity.userID == 501)
            #expect(identity.groupID == 20)
            #expect(identity.supplementaryGroups.count == 16)
            #expect(identity.supplementaryGroups
                == identity.supplementaryGroups.sorted())
            #expect(Set(identity.supplementaryGroups).count == 16)
            #expect(identity.supplementaryGroups.contains(20))
        case .invalid, .unavailable:
            Issue.record("expected exact App directory identity")
        }
        let url = try system.executableURL(processID: processID).get()
        #expect(url.isFileURL)
        #expect(url.path.hasPrefix("/"))
        switch system.liveSigning(processID: processID) {
        case .observed(let observation):
            #expect(observation.processID == processID)
            #expect(!observation.identity.signingIdentifier.isEmpty)
        case .invalid, .unavailable:
            Issue.record("expected current signed test process")
        }
    }
    @Test
    func directoryGroupSelectionPreservesReturnedOrderBeforeKernelLimit() {
        let returned: [gid_t] = [20] + Array(100...114) + [1]
        let selected = DarwinInvestigationMachineAppIdentitySystem
            .selectedSupplementaryGroups(from: returned)
        #expect(selected == ([20] + Array(UInt32(100)...UInt32(114))).sorted())
        #expect(selected?.contains(1) == false)
    }
    @Test
    func sourceAndDarwinABIStayClosedAndComplete() throws {
        let root = repositoryRoot()
        let source = try String(
            contentsOf: root.appending(
                path: "Sources/StornautInvestigationMachineDriverSupport/"
                    + "InvestigationMachineDarwinAppIdentityObservation.swift"
            ),
            encoding: .utf8
        )
        for required in [
            "package struct InvestigationMachineDarwinAppIdentityObserver",
            "package func prepare(", "package func observe(",
            "InvestigationHandoffProcessClaim",
            "InvestigationHandoffDropEvidence",
            "InvestigationInstalledL2IdentityProjection",
            "parentProcessID", "processGroupID", "realUserID",
            "savedUserID", "realGroupID", "savedGroupID",
            "supplementaryGroups", "auditTokenWords",
            "appExecutableSHA256", "appBundleIdentifier",
            "staticSigning", "liveSigning",
            "getpwuid_r", "getgrouplist", "NGROUPS_MAX",
            "InvestigationMachineSingleEpochAppObservation",
        ] {
            #expect(source.contains(required))
        }
        for forbidden in [
            "public struct InvestigationMachineDarwinAppIdentity", "Codable",
            "StornautLifecycle", "StornautInvestigationDiagnostic",
            "posix_spawn", "socketpair", "kill(",
        ] {
            #expect(!source.contains(forbidden))
        }
        let header = try String(
            contentsOf: root.appending(
                path: "Sources/CInvestigationIdentitySupport/include/"
                    + "CInvestigationIdentitySupport.h"
            ),
            encoding: .utf8
        )
        let implementation = try String(
            contentsOf: root.appending(
                path: "Sources/CInvestigationIdentitySupport/"
                    + "CInvestigationIdentitySupport.c"
            ),
            encoding: .utf8
        )
        for required in [
            "parent_process_id", "process_group_id", "real_user_id",
            "saved_user_id", "real_group_id", "effective_group_id",
            "saved_group_id", "audit_user_id", "audit_session_id",
            "start_time_seconds", "start_time_microseconds",
            "supplementary_group_count", "supplementary_groups",
            "STORNAUT_INVESTIGATION_IDENTITY_MISMATCH",
        ] {
            #expect(header.contains(required))
        }
        for required in [
            "PROC_PIDTBSDINFO", "KERN_PROC_PID", "audit_get_pinfo_addr",
            "pbi_ppid", "pbi_pgid", "pbi_ruid", "pbi_uid",
            "pbi_svuid", "pbi_rgid", "pbi_gid", "pbi_svgid",
            "cr_ngroups", "cr_groups",
            "return STORNAUT_INVESTIGATION_IDENTITY_MISMATCH",
        ] {
            #expect(implementation.contains(required))
        }
    }
}
private enum DarwinAppIdentitySnapshotMutation: CaseIterable {
    case processID, parentProcessID, processGroupID
    case realUserID, effectiveUserID, savedUserID
    case realGroupID, effectiveGroupID, savedGroupID
    case auditUserID, auditSessionID, startTime, groupCount, duplicateGroup
}
private enum DarwinAppExpectedTopologyMismatch: CaseIterable {
    case parentProcessID, processGroupID
}
private enum DarwinAppInheritedTopologyDrift: CaseIterable {
    case preDropParent, preDropGroup, postDropParent, postDropGroup
}
private enum DarwinAppPreDropSnapshotMutation: CaseIterable {
    case processID, parentProcessID, processGroupID
    case realUserID, effectiveUserID, savedUserID
    case realGroupID, effectiveGroupID, savedGroupID
    case auditUserID, auditSessionID, startTime, noGroups
}
private enum DarwinAppIdentityRaceMutation: CaseIterable {
    case initialNarrow, finalNarrow, snapshot, finalSnapshot, initialPath, finalPath
    case initialArtifact, finalArtifact, initialStaticSigning, finalStaticSigning
    case liveSigning, liveProcess, liveIdentity
}
private enum DarwinAppUnavailableObservationSample: CaseIterable {
    case initialSnapshot, finalSnapshot, initialPath, finalPath
    case initialArtifact, finalArtifact
    case initialStaticSigning, finalStaticSigning, liveSigning
    func system(
        fixture: DarwinAppIdentityFixture
    ) -> RecordingDarwinAppIdentitySystem {
        switch self {
        case .initialSnapshot:
            fixture.system(snapshots: [.failure(.observationUnavailable)])
        case .finalSnapshot:
            fixture.system(snapshots: [
                .success(fixture.postDropSnapshot),
                .failure(.observationUnavailable),
            ])
        case .initialPath:
            fixture.system(paths: [.failure(.observationUnavailable)])
        case .finalPath:
            fixture.system(paths: [
                .success(fixture.appURL),
                .failure(.observationUnavailable),
            ])
        case .initialArtifact:
            fixture.system(artifacts: [.unavailable])
        case .finalArtifact:
            fixture.system(artifacts: [.presentValid, .unavailable])
        case .initialStaticSigning:
            fixture.system(staticSignings: [.unavailable])
        case .finalStaticSigning:
            fixture.system(staticSignings: [
                .observed(fixture.signing), .unavailable,
            ])
        case .liveSigning:
            fixture.system(liveSigning: .unavailable)
        }
    }
}
private enum DarwinAppInvalidObservationSample: CaseIterable {
    case initialSnapshot, finalSnapshot, initialArtifact, finalArtifact
    case initialPath, finalPath
    case initialStaticSigning, initialStaticSigningMismatch, finalStaticSigning
    case liveSigning, liveProcessMismatch, liveIdentityMismatch
    case finalPhaseIdentity
    var expectedError: InvestigationMachineDarwinAppIdentityObservationError {
        switch self {
        case .initialArtifact, .finalArtifact, .initialPath, .finalPath:
            .executableIdentityInvalid
        case .initialStaticSigning, .initialStaticSigningMismatch,
                .finalStaticSigning, .liveSigning, .liveProcessMismatch,
                .liveIdentityMismatch:
            .signingIdentityInvalid
        case .initialSnapshot, .finalSnapshot, .finalPhaseIdentity:
            .invalidPostDropIdentity
        }
    }
    func system(
        fixture: DarwinAppIdentityFixture
    ) -> RecordingDarwinAppIdentitySystem {
        switch self {
        case .initialSnapshot:
            fixture.system(snapshots: [.failure(.physicalIdentityInvalid)])
        case .finalSnapshot:
            fixture.system(snapshots: [
                .success(fixture.postDropSnapshot),
                .failure(.physicalIdentityInvalid),
            ])
        case .initialArtifact:
            fixture.system(artifacts: [.invalid])
        case .finalArtifact:
            fixture.system(artifacts: [.presentValid, .invalid])
        case .initialPath:
            fixture.system(paths: [.success(fixture.foreignURL)])
        case .finalPath:
            fixture.system(paths: [
                .success(fixture.appURL), .success(fixture.foreignURL),
            ])
        case .initialStaticSigning:
            fixture.system(staticSignings: [.invalid])
        case .initialStaticSigningMismatch:
            fixture.system(staticSignings: [
                .observed(fixture.foreignSigning),
            ])
        case .finalStaticSigning:
            fixture.system(staticSignings: [
                .observed(fixture.signing),
                .observed(fixture.foreignSigning),
            ])
        case .liveSigning:
            fixture.system(liveSigning: .invalid)
        case .liveProcessMismatch:
            fixture.system(liveSigning: .observed(.init(
                processID: fixture.processID + 1,
                identity: fixture.signing
            )))
        case .liveIdentityMismatch:
            fixture.system(liveSigning: .observed(.init(
                processID: fixture.processID,
                identity: fixture.foreignSigning
            )))
        case .finalPhaseIdentity:
            fixture.system(snapshots: [
                .success(fixture.postDropSnapshot),
                .success(fixture.postDropSnapshot(mutating: .startTime)),
            ])
        }
    }
}
private enum DarwinAppResolvedIdentityFailureSample: CaseIterable {
    case preDropUnavailable, preDropInvalid, preDropSnapshotConflict
    case postDropUnavailable, postDropInvalid, postDropDrift
    var isUnavailable: Bool {
        self == .preDropUnavailable || self == .postDropUnavailable
    }
    var expectedPhaseError:
        InvestigationMachineDarwinAppIdentityObservationError
    {
        switch self {
        case .preDropUnavailable, .preDropInvalid, .preDropSnapshotConflict:
            .invalidPreDropIdentity
        case .postDropUnavailable, .postDropInvalid, .postDropDrift:
            .invalidPostDropIdentity
        }
    }
    func perform(fixture: DarwinAppIdentityFixture) throws -> Any {
        switch self {
        case .preDropUnavailable:
            return try prepare(fixture: fixture, result: .unavailable)
        case .preDropInvalid:
            return try prepare(fixture: fixture, result: .invalid)
        case .preDropSnapshotConflict:
            return try InvestigationMachineDarwinAppIdentityObserver(
                system: fixture.system(
                    narrows: [fixture.preDropNarrow],
                    snapshots: [.failure(.physicalIdentityInvalid)]
                )
            ).prepare(
                processClaim: fixture.preDropClaim, projection: fixture.projection
            )
        case .postDropUnavailable:
            return try observe(fixture: fixture, result: .unavailable)
        case .postDropInvalid:
            return try observe(fixture: fixture, result: .invalid)
        case .postDropDrift:
            return try observe(fixture: fixture, result: .observed(.init(
                username: fixture.resolvedAppIdentity.username,
                userID: 501,
                groupID: 20,
                supplementaryGroups:
                    Array(UInt32(2)...UInt32(16)) + [20]
            )))
        }
    }
    private func prepare(
        fixture: DarwinAppIdentityFixture,
        result: InvestigationMachineDarwinAppResolvedIdentityResult
    ) throws -> InvestigationMachineDarwinAppPreDropObservation {
        try InvestigationMachineDarwinAppIdentityObserver(
            system: fixture.system(resolvedAppIdentities: [result])
        ).prepare(
            processClaim: fixture.preDropClaim,
            projection: fixture.projection
        )
    }
    private func observe(
        fixture: DarwinAppIdentityFixture,
        result: InvestigationMachineDarwinAppResolvedIdentityResult
    ) throws -> InvestigationMachineSingleEpochAppObservation {
        let preDrop = try fixture.preDropObservation()
        return try fixture.observe(
            system: fixture.system(resolvedAppIdentities: [result]),
            preDrop: preDrop
        )
    }
}
private struct DarwinAppIdentityFixture {
    let driverProcessID: UInt32 = 900
    let inheritedParentProcessID: UInt32 = 702
    let inheritedProcessGroupID: UInt32 = 702
    let processID: UInt32 = 701
    let processVersion: UInt32 = 11
    let auditSessionID: UInt32 = 44_001
    let auditUserID: UInt32 = 501
    let appURL = InvestigationInstalledL2FixedPaths().appExecutable
    let foreignURL = URL(fileURLWithPath: "/tmp/foreign-app")
    let groups = Array(UInt32(1)...UInt32(15)) + [20]
    let signing: InvestigationInstalledL2SigningIdentity
    let foreignSigning: InvestigationInstalledL2SigningIdentity
    let projection: InvestigationInstalledL2IdentityProjection
    let preDropClaim: InvestigationHandoffProcessClaim
    let postDropClaim: InvestigationHandoffProcessClaim
    let preDropNarrow: InvestigationMachineDarwinAppNarrowIdentity
    let preDropSnapshot: InvestigationMachineDarwinAppProcessSnapshot
    let postDropSnapshot: InvestigationMachineDarwinAppProcessSnapshot
    let dropEvidence: InvestigationHandoffDropEvidence
    let appIdentity: InvestigationMachineProcessIdentity
    let resolvedAppIdentity: InvestigationMachineDarwinAppResolvedIdentity
    var postDropNarrow: InvestigationMachineDarwinAppNarrowIdentity {
        .init(
            processID: processID, processIDVersion: processVersion,
            auditSessionID: auditSessionID, effectiveUserID: 501,
            auditTokenWords: appIdentity.auditTokenWords
        )
    }
    var foreignPostDropNarrow: InvestigationMachineDarwinAppNarrowIdentity {
        var words = appIdentity.auditTokenWords; words[7] += 1
        return .init(
            processID: processID, processIDVersion: processVersion + 1,
            auditSessionID: auditSessionID, effectiveUserID: 501,
            auditTokenWords: words
        )
    }
    init() throws {
        signing = try Self.signing(identifier: "com.eriklee.stornaut", byte: 0x61)
        foreignSigning = try Self.signing(identifier: "foreign.app", byte: 0x62)
        projection = try Self.projection(appDigestByte: 0x31)
        let rootWords: [UInt32] = [501, 0, 0, 0, 0, processID, auditSessionID, processVersion]
        let appWords: [UInt32] = [
            auditUserID, 501, 20, 501, 20, processID, auditSessionID, processVersion,
        ]
        preDropClaim = try .init(
            processID: processID, processIDVersion: processVersion,
            effectiveUserID: 0, auditSessionID: auditSessionID
        )
        postDropClaim = try .init(
            processID: processID, processIDVersion: processVersion,
            effectiveUserID: 501, auditSessionID: auditSessionID
        )
        preDropNarrow = .init(
            processID: processID, processIDVersion: processVersion,
            auditSessionID: auditSessionID, effectiveUserID: 0,
            auditTokenWords: rootWords
        )
        preDropSnapshot = Self.snapshot(
            processID: processID, parent: driverProcessID, group: processID,
            userID: 0, groupID: 0, auditUserID: auditUserID,
            auditSessionID: auditSessionID, groups: [0]
        )
        postDropSnapshot = Self.snapshot(
            processID: processID, parent: driverProcessID, group: processID,
            userID: 501, groupID: 20, auditUserID: auditUserID,
            auditSessionID: auditSessionID, groups: groups
        )
        dropEvidence = try Self.dropEvidence(
            processID: processID, processVersion: processVersion,
            auditSessionID: auditSessionID, auditUserID: auditUserID, groups: groups
        )
        appIdentity = try .init(
            role: .app, processID: processID, processIDVersion: processVersion,
            auditSessionID: auditSessionID, effectiveUserID: 501,
            auditTokenWords: appWords
        )
        resolvedAppIdentity = .init(
            username: "app-user", userID: 501, groupID: 20,
            supplementaryGroups: groups
        )
    }
    func preDropObservation() throws
        -> InvestigationMachineDarwinAppPreDropObservation
    {
        try InvestigationMachineDarwinAppIdentityObserver(
            system: system(
                narrows: [preDropNarrow, preDropNarrow],
                snapshots: [
                    .success(preDropSnapshot), .success(preDropSnapshot),
                ],
                liveSigning: liveSigning
            )
        ).prepare(processClaim: preDropClaim, projection: projection)
    }
    func preDropObservation(
        expectedParentProcessID: UInt32,
        expectedProcessGroupID: UInt32
    ) throws -> InvestigationMachineDarwinAppPreDropObservation {
        let snapshot = makePreDropSnapshot(
            parentProcessID: expectedParentProcessID,
            processGroupID: expectedProcessGroupID
        )
        return try InvestigationMachineDarwinAppIdentityObserver(
            system: system(
                narrows: [preDropNarrow, preDropNarrow],
                snapshots: [.success(snapshot), .success(snapshot)],
                liveSigning: liveSigning
            )
        ).prepare(
            processClaim: preDropClaim,
            projection: projection,
            expectedParentProcessID: expectedParentProcessID,
            expectedProcessGroupID: expectedProcessGroupID
        )
    }
    func observe(
        system: RecordingDarwinAppIdentitySystem,
        preDrop: InvestigationMachineDarwinAppPreDropObservation,
        evidence: InvestigationHandoffDropEvidence? = nil,
        projection selectedProjection:
            InvestigationInstalledL2IdentityProjection? = nil
    ) throws -> InvestigationMachineSingleEpochAppObservation {
        try InvestigationMachineDarwinAppIdentityObserver(system: system).observe(
            preDrop: preDrop, processClaim: postDropClaim,
            dropEvidence: evidence ?? dropEvidence,
            projection: selectedProjection ?? projection
        )
    }
    func system(
        resolvedAppIdentities:
            [InvestigationMachineDarwinAppResolvedIdentityResult]? = nil,
        narrows: [InvestigationMachineDarwinAppNarrowIdentity] = [],
        snapshots: [Result<
            InvestigationMachineDarwinAppProcessSnapshot,
            InvestigationMachineDarwinAppIdentityObservationError
        >]? = nil,
        paths: [Result<URL, InvestigationMachineDarwinAppIdentityObservationError>]? = nil,
        artifacts: [InvestigationInstalledL2ArtifactObservation]? = nil,
        staticSignings: [InvestigationInstalledL2StaticSigningResult]? = nil,
        liveSigning: InvestigationMachineDarwinAppLiveSigningResult? = nil
    ) -> RecordingDarwinAppIdentitySystem {
        RecordingDarwinAppIdentitySystem(
            currentProcessID: driverProcessID,
            resolvedAppIdentityResults: resolvedAppIdentities ?? [
                .observed(resolvedAppIdentity),
            ],
            narrowResults: (narrows.isEmpty
                ? [postDropNarrow, postDropNarrow] : narrows).map { .success($0) },
            snapshotResults: snapshots ?? [
                .success(postDropSnapshot), .success(postDropSnapshot),
            ],
            pathResults: paths ?? [.success(appURL), .success(appURL)],
            artifactResults: artifacts ?? [.presentValid, .presentValid],
            staticSigningResults: staticSignings ?? [
                .observed(signing), .observed(signing),
            ],
            liveSigningResults: [liveSigning ?? self.liveSigning]
        )
    }
    var liveSigning: InvestigationMachineDarwinAppLiveSigningResult {
        .observed(.init(processID: processID, identity: signing))
    }
    func postDropSnapshot(
        mutating mutation: DarwinAppIdentitySnapshotMutation
    ) -> InvestigationMachineDarwinAppProcessSnapshot {
        var groups = groups
        if mutation == .groupCount { groups.removeLast() }
        if mutation == .duplicateGroup { groups[1] = groups[0] }
        return .init(
            processID: mutation == .processID ? processID + 1 : processID,
            parentProcessID: mutation == .parentProcessID
                ? driverProcessID + 1 : driverProcessID,
            processGroupID: mutation == .processGroupID
                ? processID + 1 : processID,
            realUserID: mutation == .realUserID ? 502 : 501,
            effectiveUserID: mutation == .effectiveUserID ? 502 : 501,
            savedUserID: mutation == .savedUserID ? 502 : 501,
            realGroupID: mutation == .realGroupID ? 21 : 20,
            effectiveGroupID: mutation == .effectiveGroupID ? 21 : 20,
            savedGroupID: mutation == .savedGroupID ? 21 : 20,
            auditUserID: mutation == .auditUserID ? 777 : auditUserID,
            auditSessionID: mutation == .auditSessionID
                ? auditSessionID + 1 : auditSessionID,
            startTimeSeconds: mutation == .startTime ? 2 : 1,
            startTimeMicroseconds: 2, supplementaryGroups: groups
        )
    }
    func postDropSnapshot(
        groups: [UInt32]
    ) -> InvestigationMachineDarwinAppProcessSnapshot {
        Self.snapshot(
            processID: processID, parent: driverProcessID, group: processID,
            userID: 501, groupID: 20, auditUserID: auditUserID,
            auditSessionID: auditSessionID, groups: groups
        )
    }
    func makePreDropSnapshot(
        parentProcessID: UInt32, processGroupID: UInt32
    ) -> InvestigationMachineDarwinAppProcessSnapshot {
        Self.snapshot(
            processID: processID, parent: parentProcessID,
            group: processGroupID, userID: 0, groupID: 0,
            auditUserID: auditUserID, auditSessionID: auditSessionID,
            groups: [0]
        )
    }
    func makePostDropSnapshot(
        parentProcessID: UInt32, processGroupID: UInt32
    ) -> InvestigationMachineDarwinAppProcessSnapshot {
        Self.snapshot(
            processID: processID, parent: parentProcessID,
            group: processGroupID, userID: 501, groupID: 20,
            auditUserID: auditUserID, auditSessionID: auditSessionID,
            groups: groups
        )
    }
    func preDropSnapshot(
        mutating mutation: DarwinAppPreDropSnapshotMutation
    ) -> InvestigationMachineDarwinAppProcessSnapshot {
        .init(
            processID: mutation == .processID ? processID + 1 : processID,
            parentProcessID: mutation == .parentProcessID
                ? driverProcessID + 1 : driverProcessID,
            processGroupID: mutation == .processGroupID
                ? processID + 1 : processID,
            realUserID: mutation == .realUserID ? 501 : 0,
            effectiveUserID: mutation == .effectiveUserID ? 501 : 0,
            savedUserID: mutation == .savedUserID ? 501 : 0,
            realGroupID: mutation == .realGroupID ? 20 : 0,
            effectiveGroupID: mutation == .effectiveGroupID ? 20 : 0,
            savedGroupID: mutation == .savedGroupID ? 20 : 0,
            auditUserID: mutation == .auditUserID ? 777 : auditUserID,
            auditSessionID: mutation == .auditSessionID
                ? auditSessionID + 1 : auditSessionID,
            startTimeSeconds: mutation == .startTime ? 0 : 1,
            startTimeMicroseconds: 2,
            supplementaryGroups: mutation == .noGroups ? [] : [0]
        )
    }
    func dropEvidence(auditUserID: UInt32) throws
        -> InvestigationHandoffDropEvidence
    {
        try Self.dropEvidence(
            processID: processID, processVersion: processVersion,
            auditSessionID: auditSessionID, auditUserID: auditUserID, groups: groups
        )
    }
    func dropEvidence(groups: [UInt32]) throws
        -> InvestigationHandoffDropEvidence
    {
        try Self.dropEvidence(
            processID: processID,
            processVersion: processVersion,
            auditSessionID: auditSessionID,
            auditUserID: auditUserID,
            groups: groups
        )
    }
    func projection(appDigestByte: UInt8) throws
        -> InvestigationInstalledL2IdentityProjection
    {
        try Self.projection(appDigestByte: appDigestByte)
    }
    private static func snapshot(
        processID: UInt32, parent: UInt32, group: UInt32, userID: UInt32,
        groupID: UInt32, auditUserID: UInt32, auditSessionID: UInt32,
        groups: [UInt32]
    ) -> InvestigationMachineDarwinAppProcessSnapshot {
        .init(
            processID: processID, parentProcessID: parent,
            processGroupID: group, realUserID: userID,
            effectiveUserID: userID, savedUserID: userID,
            realGroupID: groupID, effectiveGroupID: groupID,
            savedGroupID: groupID, auditUserID: auditUserID,
            auditSessionID: auditSessionID, startTimeSeconds: 1,
            startTimeMicroseconds: 2, supplementaryGroups: groups
        )
    }
    private static func dropEvidence(
        processID: UInt32, processVersion: UInt32, auditSessionID: UInt32,
        auditUserID: UInt32, groups: [UInt32]
    ) throws -> InvestigationHandoffDropEvidence {
        try .init(
            realUserID: 501, effectiveUserID: 501, savedUserID: 501,
            realGroupID: 20, effectiveGroupID: 20, savedGroupID: 20,
            supplementaryGroups: groups,
            auditTokenWords: [
                auditUserID, 501, 20, 501, 20, processID, auditSessionID,
                processVersion,
            ],
            setuidRootErrno: 1, seteuidRootErrno: 1, setgidRootErrno: 1
        )
    }
    private static func projection(
        appDigestByte: UInt8
    ) throws -> InvestigationInstalledL2IdentityProjection {
        try .init(
            epochUUID: uuid(0x11), configurationNonce: uuid(0x12),
            configurationValidBefore: .init(rawValue: 2_000_000_000_000_000),
            configurationSHA256: digest(0x21),
            signedRuntimeBindingSHA256: digest(0x22),
            appExecutableSHA256: digest(appDigestByte),
            appBundleIdentifier: "com.eriklee.stornaut",
            helperExecutableSHA256: digest(0x32),
            helperServiceIdentifier: "com.eriklee.stornaut.lifecycle",
            machineDriverExecutableSHA256: digest(0x33),
            machineDriverSigningIdentifier:
                "com.eriklee.stornaut.investigation.machine-driver",
            machineDriverDesignatedRequirementSHA256: digest(0x34),
            machineDriverCodeDirectoryHash: Data(repeating: 0x35, count: 20),
            machineClaimServiceIdentifier:
                "com.eriklee.stornaut.lifecycle.machine-claim"
        )
    }
    private static func signing(
        identifier: String, byte: UInt8
    ) throws -> InvestigationInstalledL2SigningIdentity {
        try .init(
            signingIdentifier: identifier,
            designatedRequirementSHA256: digest(byte),
            codeDirectoryHash: Data(repeating: byte, count: 20),
            isAdHoc: true
        )
    }
    private static func digest(_ byte: UInt8) throws
        -> InvestigationHandoffSHA256
    {
        try .init(rawBytes: Data(repeating: byte, count: 32))
    }
    private static func uuid(_ byte: UInt8) -> UUID {
        UUID(uuidString: String(
            format: "00000000-0000-4000-8000-0000000000%02x", byte
        ))!
    }
}
private final class RecordingDarwinAppIdentitySystem:
    InvestigationMachineDarwinAppIdentitySystem,
    @unchecked Sendable
{
    private let lock = NSLock()
    private let selectedCurrentProcessID: UInt32
    private var resolvedAppIdentityResults:
        [InvestigationMachineDarwinAppResolvedIdentityResult]
    private var narrowResults: [Result<
        InvestigationMachineDarwinAppNarrowIdentity,
        InvestigationMachineDarwinAppIdentityObservationError
    >]
    private var snapshotResults: [Result<
        InvestigationMachineDarwinAppProcessSnapshot,
        InvestigationMachineDarwinAppIdentityObservationError
    >]
    private var pathResults: [Result<
        URL, InvestigationMachineDarwinAppIdentityObservationError
    >]
    private var artifactResults: [InvestigationInstalledL2ArtifactObservation]
    private var staticSigningResults: [InvestigationInstalledL2StaticSigningResult]
    private var liveSigningResults: [InvestigationMachineDarwinAppLiveSigningResult]
    private(set) var calls: [String] = []
    init(
        currentProcessID: UInt32,
        resolvedAppIdentityResults:
            [InvestigationMachineDarwinAppResolvedIdentityResult],
        narrowResults: [Result<InvestigationMachineDarwinAppNarrowIdentity, InvestigationMachineDarwinAppIdentityObservationError>],
        snapshotResults: [Result<InvestigationMachineDarwinAppProcessSnapshot, InvestigationMachineDarwinAppIdentityObservationError>],
        pathResults: [Result<URL, InvestigationMachineDarwinAppIdentityObservationError>],
        artifactResults: [InvestigationInstalledL2ArtifactObservation],
        staticSigningResults: [InvestigationInstalledL2StaticSigningResult],
        liveSigningResults: [InvestigationMachineDarwinAppLiveSigningResult]
    ) {
        selectedCurrentProcessID = currentProcessID
        self.resolvedAppIdentityResults = resolvedAppIdentityResults
        self.narrowResults = narrowResults
        self.snapshotResults = snapshotResults
        self.pathResults = pathResults
        self.artifactResults = artifactResults
        self.staticSigningResults = staticSigningResults
        self.liveSigningResults = liveSigningResults
    }
    func currentProcessID() -> UInt32 {
        record("current-pid")
        return selectedCurrentProcessID
    }
    func resolvedAppIdentity()
        -> InvestigationMachineDarwinAppResolvedIdentityResult
    {
        take(&resolvedAppIdentityResults, call: "resolved-app-identity")
    }
    func narrowIdentity(processID: UInt32)
        -> Result<InvestigationMachineDarwinAppNarrowIdentity, InvestigationMachineDarwinAppIdentityObservationError>
    {
        take(&narrowResults, call: "narrow:\(processID)")
    }
    func snapshot(processID: UInt32)
        -> Result<InvestigationMachineDarwinAppProcessSnapshot, InvestigationMachineDarwinAppIdentityObservationError>
    {
        take(&snapshotResults, call: "snapshot:\(processID)")
    }
    func executableURL(processID: UInt32)
        -> Result<URL, InvestigationMachineDarwinAppIdentityObservationError>
    {
        take(&pathResults, call: "path:\(processID)")
    }
    func executableObservation(expectedSHA256: InvestigationHandoffSHA256)
        -> InvestigationInstalledL2ArtifactObservation
    {
        take(&artifactResults, call: "artifact")
    }
    func staticSigning() -> InvestigationInstalledL2StaticSigningResult {
        take(&staticSigningResults, call: "static-signing")
    }
    func liveSigning(processID: UInt32)
        -> InvestigationMachineDarwinAppLiveSigningResult
    {
        take(&liveSigningResults, call: "live-signing:\(processID)")
    }
    private func record(_ call: String) {
        lock.withLock { calls.append(call) }
    }
    private func take<Value>(_ values: inout [Value], call: String) -> Value {
        lock.lock()
        defer { lock.unlock() }
        calls.append(call)
        return values.removeFirst()
    }
}
private func repositoryRoot() -> URL {
    URL(filePath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
}
