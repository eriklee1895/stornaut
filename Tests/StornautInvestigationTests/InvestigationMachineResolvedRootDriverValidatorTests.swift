import Foundation
import Testing
@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationMachineGateSupport

@Suite("Resolved root-driver pure validator")
struct InvestigationMachineResolvedRootDriverValidatorTests {
    @Test("direct exec continuity and one/two-monitor successors resolve",
          arguments: [0, 1, 2])
    func resolvesAdmittedLineageShapes(_ monitorCount: Int) throws {
        let fixture = try ValidatorFixture(monitorCount: monitorCount)

        let result = try InvestigationMachineResolvedRootDriverValidator
            .validate(fixture.input())

        #expect(result.resolvedProcess == fixture.driver)
        #expect(result.lineage.count == (monitorCount == 0 ? 1 : monitorCount + 2))
        #expect(result.resolutionKind == (monitorCount == 0
            ? .execContinuity : .containedSuccessor))
    }

    @Test("attempt and whole-input commitments are exact",
          arguments: BindingMutation.allCases)
    fileprivate func rejectsClaimBindingDrift(_ mutation: BindingMutation) throws {
        let fixture = try ValidatorFixture(monitorCount: 1)
        var input = fixture.input()
        switch mutation {
        case .attempt:
            input.expectedOuterAttemptUUID = fixture.uuid(0xf0)
        case .wholeInput:
            input.expectedWholeInputSHA256 = fixture.digest(0xf1)
        case .projectedCohort:
            input.projectedCohortInput = try fixture.projectedInput(marker: 0xf2)
        }
        #expect(throws: InvestigationMachineResolvedRootDriverValidationError
            .claimBindingMismatch) {
            _ = try InvestigationMachineResolvedRootDriverValidator.validate(input)
        }
    }

    @Test("lineage rejects gaps, cycles, duplicates, siblings and overflow",
          arguments: LineageMutation.allCases)
    fileprivate func rejectsMalformedLineage(_ mutation: LineageMutation) throws {
        let fixture = try ValidatorFixture(monitorCount: 2)
        var edges = fixture.edges
        let initial = fixture.lineage[0]
        let first = fixture.lineage[1]
        let second = fixture.lineage[2]
        let driver = fixture.lineage[3]
        switch mutation {
        case .gap:
            edges[1] = .init(parent: fixture.process(777, parent: 100), child: second)
        case .cycle:
            edges = [
                .init(parent: initial, child: first),
                .init(parent: first, child: initial),
                .init(parent: initial, child: driver),
            ]
        case .duplicate:
            edges = [edges[0], edges[0], edges[2]]
        case .unrelatedSibling:
            edges[2] = .init(
                parent: fixture.process(778, parent: first.processID),
                child: driver
            )
        case .tooLong:
            let third = fixture.process(103, parent: second.processID)
            let fourth = fixture.process(104, parent: third.processID)
            edges = [
                .init(parent: initial, child: first),
                .init(parent: first, child: second),
                .init(parent: second, child: third),
                .init(parent: third, child: fourth),
            ]
        }
        var input = fixture.input()
        input.lineageEdges = edges
        #expect(throws: InvestigationMachineResolvedRootDriverValidationError
            .lineageUnproved) {
            _ = try InvestigationMachineResolvedRootDriverValidator.validate(input)
        }
    }

    @Test("every process identity axis stays stable and contained",
          arguments: ProcessMutation.allCases)
    fileprivate func rejectsProcessDrift(_ mutation: ProcessMutation) throws {
        let fixture = try ValidatorFixture(monitorCount: 1)
        var input = fixture.input()
        switch mutation {
        case .parent:
            input.lineageEdges[1] = .init(
                parent: input.lineageEdges[1].parent,
                child: fixture.process(fixture.driver.processID, parent: 999)
            )
        case .processGroup:
            input.recoveryProcessGroupID &+= 1
        case .session:
            input.coordinatorSessionID &+= 1
        case .auditSession:
            input.secondProcessSample = fixture.sample(
                fixture.process(fixture.driver.processID, parent: 101, auditSessionID: 61),
                at: 1_001
            )
        case .start:
            input.secondProcessSample = fixture.sample(
                fixture.process(fixture.driver.processID, parent: 101, startSeconds: 2_000),
                at: 1_001
            )
        case .auditUser:
            input.claim = try fixture.claim(auditUserID: 502)
        }
        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineResolvedRootDriverValidator.validate(input)
        }
    }

    @Test("stopped samples bracket the claim and exact injected evidence")
    func rejectsStoppedNodeHashAndSigningDrift() throws {
        let fixture = try ValidatorFixture(monitorCount: 1)
        for mutation in EvidenceMutation.allCases {
            var input = fixture.input()
            switch mutation {
            case .notStopped:
                input.secondProcessSample = .init(
                    identity: fixture.driver, isStopped: false,
                    observedAtContinuousNanoseconds: 1_001
                )
            case .timeOrder:
                input.firstProcessSample = fixture.sample(fixture.driver, at: 999)
            case .node:
                input.fixedExecutableNode = try fixture.node(inode: 999)
            case .sha:
                input.fixedExecutableSHA256 = fixture.digest(0xee)
            case .staticSigning:
                input.fixedStaticSigning = try fixture.signing(marker: 0xee)
            case .liveSigning:
                input.liveSigning = try fixture.signing(marker: 0xef)
            case .projectionSHA:
                var projections = input.projectedCohortInput.projections
                projections[0] = try fixture.projection(
                    index: 0, executableSHA256: fixture.digest(0xed)
                )
                input.projectedCohortInput = try .init(
                    capsule: input.projectedCohortInput.capsule,
                    projections: projections
                )
            case .projectionSigning:
                var projections = input.projectedCohortInput.projections
                projections[0] = try fixture.projection(
                    index: 0, signingMarker: 0xec
                )
                input.projectedCohortInput = try .init(
                    capsule: input.projectedCohortInput.capsule,
                    projections: projections
                )
            }
            #expect(throws: (any Error).self, "mutation \(mutation)") {
                _ = try InvestigationMachineResolvedRootDriverValidator.validate(input)
            }
        }
    }

    @Test("retirement accepts absence and PID reuse outside the old cohort")
    func retirementAcceptsAbsenceAndReuse() throws {
        let fixture = try ValidatorFixture(monitorCount: 1)
        let resolution = try InvestigationMachineResolvedRootDriverValidator
            .validate(fixture.input())
        let absent = resolution.lineage.map { identity in
            InvestigationMachineResolvedRootDriverRetirementObservation(
                processID: identity.processID, state: .absent
            )
        }
        let absentResult = try InvestigationMachineResolvedRootDriverValidator
            .verifyRetirement(
                resolution, enumeration: .init(isComplete: true, observations: absent)
            )
        #expect(absentResult.reusedProcessIDs.isEmpty)

        var reuse = absent
        let old = resolution.lineage[1]
        let reused = fixture.process(
            old.processID, parent: 900, processGroupID: 901, sessionID: 902,
            startSeconds: old.startSeconds + 1
        )
        reuse[1] = .init(processID: old.processID, state: .present(reused))
        let reuseResult = try InvestigationMachineResolvedRootDriverValidator
            .verifyRetirement(
                resolution, enumeration: .init(isComplete: true, observations: reuse)
            )
        #expect(reuseResult.reusedProcessIDs == [old.processID])
    }

    @Test("retirement fails closed for live identity, cohort residue and gaps")
    func retirementRejectsLiveResidueAndIncompleteEnumeration() throws {
        let fixture = try ValidatorFixture(monitorCount: 1)
        let resolution = try InvestigationMachineResolvedRootDriverValidator
            .validate(fixture.input())
        var absent = resolution.lineage.map { identity in
            InvestigationMachineResolvedRootDriverRetirementObservation(
                processID: identity.processID, state: .absent
            )
        }
        for enumeration in [
            InvestigationMachineResolvedRootDriverRetirementEnumeration(
                isComplete: false, observations: absent),
            .init(isComplete: true, observations: Array(absent.dropLast())),
        ] {
            #expect(throws: InvestigationMachineResolvedRootDriverValidationError
                .retirementUnproved) {
                _ = try InvestigationMachineResolvedRootDriverValidator
                    .verifyRetirement(resolution, enumeration: enumeration)
            }
        }
        absent[0] = .init(
            processID: resolution.lineage[0].processID,
            state: .present(resolution.lineage[0])
        )
        #expect(throws: InvestigationMachineResolvedRootDriverValidationError
            .liveResidue) {
            _ = try InvestigationMachineResolvedRootDriverValidator
                .verifyRetirement(
                    resolution, enumeration: .init(
                        isComplete: true, observations: absent
                    )
                )
        }

        let old = resolution.lineage[0]
        let reusedInside = fixture.process(
            old.processID, parent: 900,
            startSeconds: old.startSeconds + 1
        )
        absent[0] = .init(processID: old.processID, state: .present(reusedInside))
        #expect(throws: InvestigationMachineResolvedRootDriverValidationError
            .liveResidue) {
            _ = try InvestigationMachineResolvedRootDriverValidator
                .verifyRetirement(
                    resolution, enumeration: .init(
                        isComplete: true, observations: absent
                    )
                )
        }
    }
}

private struct ValidatorFixture {
    let attempt = UUID(uuidString: "12345678-1234-5678-9abc-def012345678")!
    let wholeInput: InvestigationHandoffSHA256
    let driverSHA: InvestigationHandoffSHA256
    let signingIdentity: InvestigationResolvedRootDriverSigningIdentityV1
    let initialLaunch: InvestigationMachineInitialSudoLaunchIdentity
    let lineage: [InvestigationMachineGateObservedProcessIdentity]
    let edges: [InvestigationMachineResolvedRootDriverLineageEdge]
    let driver: InvestigationMachineGateObservedProcessIdentity
    let claim: ResolvedRootDriverClaimV1
    let projectedInput: InvestigationProjectedCohortInput

    init(monitorCount: Int) throws {
        let fixedDriverSHA = InvestigationHandoffSHA256.hashing(Data([0x22]))
        let fixedSigningIdentity = try Self.makeSigning(marker: 0x23)
        driverSHA = fixedDriverSHA
        signingIdentity = fixedSigningIdentity
        initialLaunch = try .init(
            processID: 100, parentProcessID: 90, processGroupID: 80,
            sessionID: 70, startSeconds: 1_000, startMicroseconds: 123
        )
        var values = [try Self.makeProcess(100, parent: 90)]
        for index in 0..<monitorCount {
            values.append(try Self.makeProcess(
                UInt32(101 + index), parent: values.last!.processID
            ))
        }
        if monitorCount > 0 {
            values.append(try Self.makeProcess(
                UInt32(101 + monitorCount), parent: values.last!.processID
            ))
        }
        lineage = values
        driver = values.last!
        edges = zip(values, values.dropFirst()).map { .init(parent: $0, child: $1) }
        let executable = try InvestigationResolvedRootDriverExecutableIdentityV1(
            path: ResolvedRootDriverClaimV1.fixedExecutablePath,
            node: Self.makeNode(), sha256: fixedDriverSHA,
            staticSigning: fixedSigningIdentity, liveSigning: fixedSigningIdentity
        )
        let builtProjections = try (
            0..<InvestigationProjectedCohortInput.projectionCount
        )
            .map { try Self.makeProjection(
                index: $0, executableSHA256: fixedDriverSHA,
                signing: fixedSigningIdentity
            ) }
        let epochs = try (0..<InvestigationProjectedCohortInput.projectionCount)
            .map { try Self.makeEpoch(index: $0) }
        let builtInput = try InvestigationProjectedCohortInput(
            capsule: .init(outerAttemptUUID: attempt, epochs: epochs),
            projections: builtProjections
        )
        projectedInput = builtInput
        wholeInput = builtInput.wholeInputSHA256
        claim = try ResolvedRootDriverClaimV1(
            outerAttemptUUID: attempt, wholeInputSHA256: builtInput.wholeInputSHA256,
            process: try Self.makeClaimProcess(driver), executable: executable,
            observedAtContinuousNanoseconds: 1_000
        )
    }

    func input() -> InvestigationMachineResolvedRootDriverValidationInput {
        .init(
            claim: claim, expectedOuterAttemptUUID: attempt,
            expectedWholeInputSHA256: wholeInput, initialLaunch: initialLaunch,
            recoveryProcessGroupID: 80, coordinatorSessionID: 70,
            lineageEdges: edges, firstProcessSample: sample(driver, at: 1_001),
            secondProcessSample: sample(driver, at: 1_002),
            fixedExecutableNode: claim.executable.node,
            fixedExecutableSHA256: driverSHA,
            fixedStaticSigning: signingIdentity, liveSigning: signingIdentity,
            liveSigningProcessID: driver.processID,
            projectedCohortInput: projectedInput
        )
    }

    func sample(
        _ identity: InvestigationMachineGateObservedProcessIdentity, at time: UInt64
    ) -> InvestigationMachineResolvedRootDriverProcessSample {
        .init(identity: identity, isStopped: true,
              observedAtContinuousNanoseconds: time)
    }

    func process(
        _ pid: UInt32, parent: UInt32, processGroupID: UInt32 = 80,
        sessionID: UInt32 = 70, auditSessionID: UInt32 = 60,
        startSeconds: Int64 = 1_000
    ) -> InvestigationMachineGateObservedProcessIdentity {
        try! Self.makeProcess(
            pid, parent: parent, processGroupID: processGroupID,
            sessionID: sessionID, auditUserID: 501,
            auditSessionID: auditSessionID,
            startSeconds: startSeconds
        )
    }

    func claim(
        processIDVersion: UInt32 = 9, auditUserID: UInt32 = 501
    ) throws -> ResolvedRootDriverClaimV1 {
        try .init(
            outerAttemptUUID: attempt, wholeInputSHA256: wholeInput,
            process: Self.makeClaimProcess(
                driver, processIDVersion: processIDVersion,
                auditUserID: auditUserID
            ),
            executable: claim.executable,
            observedAtContinuousNanoseconds: claim.observedAtContinuousNanoseconds
        )
    }

    func node(inode: UInt64) throws
        -> InvestigationResolvedRootDriverNodeIdentityV1
    {
        try Self.makeNode(inode: inode)
    }

    func signing(marker: UInt8) throws
        -> InvestigationResolvedRootDriverSigningIdentityV1
    {
        try Self.makeSigning(marker: marker)
    }

    func projection(
        index: Int, executableSHA256: InvestigationHandoffSHA256? = nil,
        signingMarker: UInt8? = nil
    ) throws -> InvestigationInstalledL2IdentityProjection {
        try Self.makeProjection(
            index: index, executableSHA256: executableSHA256 ?? driverSHA,
            signing: signingMarker.map { try! Self.makeSigning(marker: $0) }
                ?? signingIdentity
        )
    }

    func projectedInput(marker: UInt8) throws
        -> InvestigationProjectedCohortInput
    {
        let epochs = try (0..<InvestigationProjectedCohortInput.projectionCount)
            .map { try Self.makeEpoch(index: $0, attemptMarker: marker) }
        let projections = try epochs.indices.map { index in
            try Self.makeProjection(
                index: index, executableSHA256: driverSHA, signing: signingIdentity,
                attemptMarker: marker
            )
        }
        return try .init(
            capsule: .init(outerAttemptUUID: attempt, epochs: epochs),
            projections: projections
        )
    }

    func digest(_ byte: UInt8) -> InvestigationHandoffSHA256 {
        Self.digest(byte)
    }

    func uuid(_ byte: UInt8) -> UUID { Self.uuid(byte) }

    private static func makeProcess(
        _ pid: UInt32, parent: UInt32, processGroupID: UInt32 = 80,
        sessionID: UInt32 = 70, auditUserID: UInt32 = 501,
        auditSessionID: UInt32 = 60,
        startSeconds: Int64 = 1_000
    ) throws -> InvestigationMachineGateObservedProcessIdentity {
        try .init(
            processID: pid, startSeconds: startSeconds, startMicroseconds: 123,
            parentProcessID: parent, processGroupID: processGroupID,
            sessionID: sessionID, auditUserID: auditUserID,
            auditSessionID: auditSessionID,
            realUserID: 0, effectiveUserID: 0, savedUserID: 0,
            realGroupID: 0, effectiveGroupID: 0, savedGroupID: 0,
            supplementaryGroups: [0]
        )
    }

    private static func makeClaimProcess(
        _ observed: InvestigationMachineGateObservedProcessIdentity,
        processIDVersion: UInt32 = 9, auditUserID: UInt32? = nil
    ) throws -> InvestigationGeneralProcessIdentityV1 {
        try .init(
            processID: observed.processID,
            processIDVersion: processIDVersion,
            startSeconds: observed.startSeconds,
            startMicroseconds: observed.startMicroseconds,
            parentProcessID: observed.parentProcessID,
            processGroupID: observed.processGroupID,
            sessionID: observed.sessionID,
            auditSessionID: observed.auditSessionID,
            auditTokenWords: [
                auditUserID ?? observed.auditUserID, observed.effectiveUserID,
                observed.effectiveGroupID,
                observed.realUserID, observed.realGroupID, observed.processID,
                observed.auditSessionID, processIDVersion,
            ],
            realUserID: observed.realUserID,
            effectiveUserID: observed.effectiveUserID,
            savedUserID: observed.savedUserID,
            realGroupID: observed.realGroupID,
            effectiveGroupID: observed.effectiveGroupID,
            savedGroupID: observed.savedGroupID,
            supplementaryGroups: observed.supplementaryGroups
        )
    }

    private static func makeNode(inode: UInt64 = 22) throws
        -> InvestigationResolvedRootDriverNodeIdentityV1
    {
        try .init(
            deviceID: 11, inode: inode, generation: 3, isRegularFile: true,
            ownerUserID: 0, ownerGroupID: 0, mode: 0o755, linkCount: 1,
            size: 1_048_576, flags: 0
        )
    }

    private static func makeSigning(marker: UInt8) throws
        -> InvestigationResolvedRootDriverSigningIdentityV1
    {
        try .init(
            signingIdentifier: ResolvedRootDriverClaimV1.fixedSigningIdentifier,
            designatedRequirementSHA256: digest(marker),
            codeDirectoryHash: Data(repeating: marker, count: 20),
            isAdHoc: true
        )
    }

    private static func makeProjection(
        index: Int, executableSHA256: InvestigationHandoffSHA256,
        signing: InvestigationResolvedRootDriverSigningIdentityV1,
        attemptMarker: UInt8 = 0
    ) throws -> InvestigationInstalledL2IdentityProjection {
        try .init(
            epochUUID: uuid(UInt8(0x30 + index) &+ attemptMarker),
            configurationNonce: uuid(UInt8(0x50 + index) &+ attemptMarker),
            configurationValidBefore: .init(rawValue: 9_000_000),
            configurationSHA256: digest(UInt8(0x70 + index)),
            signedRuntimeBindingSHA256: digest(UInt8(0x80 + index)),
            appExecutableSHA256: digest(0x90),
            appBundleIdentifier: InvestigationInstalledL2IdentityProjection
                .fixedAppBundleIdentifier,
            helperExecutableSHA256: digest(0x91),
            helperServiceIdentifier: InvestigationInstalledL2IdentityProjection
                .fixedHelperServiceIdentifier,
            machineDriverExecutableSHA256: executableSHA256,
            machineDriverSigningIdentifier: signing.signingIdentifier,
            machineDriverDesignatedRequirementSHA256:
                signing.designatedRequirementSHA256,
            machineDriverCodeDirectoryHash: signing.codeDirectoryHash,
            machineClaimServiceIdentifier: InvestigationInstalledL2IdentityProjection
                .fixedMachineClaimServiceIdentifier
        )
    }

    private static func makeEpoch(
        index: Int, attemptMarker: UInt8 = 0
    ) throws -> InvestigationCohortEpoch {
        let configuration = Data([UInt8(0x70 + index)])
        return try .init(
            ordinal: UInt32(index),
            epochUUID: uuid(UInt8(0x30 + index) &+ attemptMarker),
            scenario: InvestigationHandoffScenario.allCases[index],
            configurationNonce: uuid(UInt8(0x50 + index) &+ attemptMarker),
            configuration: configuration,
            configurationSHA256: .hashing(configuration),
            signedRuntimeBindingSHA256: digest(UInt8(0x80 + index))
        )
    }

    private static func digest(_ byte: UInt8) -> InvestigationHandoffSHA256 {
        InvestigationHandoffSHA256.hashing(Data([byte]))
    }

    private static func uuid(_ byte: UInt8) -> UUID {
        UUID(uuid: (byte, 1, 2, 3, 4, 5, 0x46, 7, 0x88, 9, 10, 11, 12, 13, 14, 15))
    }
}

private enum BindingMutation: CaseIterable { case attempt, wholeInput, projectedCohort }
private enum LineageMutation: CaseIterable {
    case gap, cycle, duplicate, unrelatedSibling, tooLong
}
private enum ProcessMutation: CaseIterable {
    case parent, processGroup, session, auditSession, start, auditUser
}
private enum EvidenceMutation: CaseIterable {
    case notStopped, timeOrder, node, sha, staticSigning, liveSigning
    case projectionSHA, projectionSigning
}
