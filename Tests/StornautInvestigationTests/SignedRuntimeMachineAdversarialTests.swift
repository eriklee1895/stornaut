import Darwin
import Foundation
import Testing
import StornautCore
@_private(sourceFile: "SignedInvestigationRuntimeMachineContract.swift")
import StornautInvestigation

@Suite("Task 39 machine filesystem adversarial cases", .serialized)
struct SignedRuntimeMachineAdversarialTests {
    @Test(
        .enabled(
            if: machineTestVolumeIsCaseInsensitive,
            "Requires a case-insensitive test volume"
        )
    )
    func rejectsCaseAliasedAttemptDirectories() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let cohortRoot = fixture.root.appending(
            path: "case-alias-attempts",
            directoryHint: .isDirectory
        )
        let upperRoot = cohortRoot.appending(
            path: "Attempt-A",
            directoryHint: .isDirectory
        )
        let lowerRoot = cohortRoot.appending(
            path: "attempt-a",
            directoryHint: .isDirectory
        )
        let successNonce = UUID(
            uuidString: "aaaaaaaa-1111-4111-8111-111111111111"
        )!
        let cancellationNonce = UUID(
            uuidString: "bbbbbbbb-2222-4222-8222-222222222222"
        )!
        var configurations = [
            try fixture.configuration(
                nonce: successNonce,
                scenario: .success,
                diagnosticRootPath: upperRoot.path
            ),
            try fixture.configuration(
                nonce: cancellationNonce,
                scenario: .cancellation,
                diagnosticRootPath: lowerRoot.path
            ),
        ]
        var upperInformation = stat()
        var lowerInformation = stat()
        let upperDescriptor = open(
            upperRoot.path,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        let lowerDescriptor = open(
            lowerRoot.path,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        defer {
            if upperDescriptor >= 0 { close(upperDescriptor) }
            if lowerDescriptor >= 0 { close(lowerDescriptor) }
        }
        guard
            upperDescriptor >= 0,
            lowerDescriptor >= 0,
            fstat(upperDescriptor, &upperInformation) == 0,
            fstat(lowerDescriptor, &lowerInformation) == 0
        else {
            throw MachineAdversarialSynchronizationError.timedOut
        }
        #expect(upperInformation.st_dev == lowerInformation.st_dev)
        #expect(upperInformation.st_ino == lowerInformation.st_ino)
        for scenario in SignedInvestigationRuntimeDiagnosticScenario
            .allCases
        where scenario != .success && scenario != .cancellation {
            configurations.append(
                try fixture.configuration(
                    nonce: UUID(),
                    scenario: scenario,
                    diagnosticRootPath: cohortRoot.appending(
                        path: "attempt-\(scenario.rawValue)",
                        directoryHint: .isDirectory
                    ).path
                )
            )
        }
        fixture.materializeOutputs()
        let artifacts = try configurations.map {
            try fixture.caseEvidence(configuration: $0)
        }
        let success = try #require(
            configurations.first { $0.scenario == .success }
        )

        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidConfiguration
        ) {
            _ = try SignedInvestigationRuntimeMachineAssembler()
                .assemble(
                    configurations: configurations,
                    artifacts: artifacts,
                    capabilityMetadata: fixture.capabilityMetadata(),
                    capabilityWorker: fixture.capabilityWorker(
                        investigationID: success.nonce,
                        evidenceBindingSHA256:
                            success.capabilityEvidenceBindingSHA256()
                    ),
                    capabilityLifecycleIntegrity:
                        fixture.capabilityLifecycleIntegrity(),
                    capabilityRepository:
                        fixture.capabilityRepositoryEvidence(),
                    now: fixture.now.addingTimeInterval(30)
                )
        }
    }

    @Test
    func rejectsUnsafeIntermediateAncestor() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let unsafeAncestor = fixture.root.appending(
            path: "unsafe-machine-ancestor",
            directoryHint: .isDirectory
        )
        let privateChild = unsafeAncestor.appending(
            path: "private-child",
            directoryHint: .isDirectory
        )
        let cohortRoot = privateChild.appending(
            path: "attempts",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: cohortRoot,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o777],
            ofItemAtPath: unsafeAncestor.path
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: privateChild.path
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: cohortRoot.path
        )
        let configurations =
            try SignedInvestigationRuntimeDiagnosticScenario
                .allCases
                .map { scenario in
                    let nonce = UUID()
                    return try fixture.configuration(
                        nonce: nonce,
                        scenario: scenario,
                        diagnosticRootPath: cohortRoot.appending(
                            path: nonce.uuidString.lowercased(),
                            directoryHint: .isDirectory
                        ).path
                    )
                }
        fixture.materializeOutputs()
        let artifacts = try configurations.map {
            try fixture.caseEvidence(configuration: $0)
        }
        let success = try #require(
            configurations.first { $0.scenario == .success }
        )

        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try SignedInvestigationRuntimeMachineAssembler()
                .assemble(
                    configurations: configurations,
                    artifacts: artifacts,
                    capabilityMetadata: fixture.capabilityMetadata(),
                    capabilityWorker: fixture.capabilityWorker(
                        investigationID: success.nonce,
                        evidenceBindingSHA256:
                            success.capabilityEvidenceBindingSHA256()
                    ),
                    capabilityLifecycleIntegrity:
                        fixture.capabilityLifecycleIntegrity(),
                    capabilityRepository:
                        fixture.capabilityRepositoryEvidence(),
                    now: fixture.now.addingTimeInterval(30)
                )
        }
    }

    @Test
    func rejectsCrossAttemptOverlap() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        var configurations =
            try SignedInvestigationRuntimeDiagnosticScenario
                .allCases
                .map {
                    try fixture.configuration(
                        nonce: UUID(),
                        scenario: $0
                    )
                }
        let overlapIndex = try #require(
            configurations.firstIndex { $0.scenario == .timeout }
        )
        let successConfiguration = try #require(
            configurations.first { $0.scenario == .success }
        )
        configurations[overlapIndex] = try fixture.configuration(
            nonce: configurations[overlapIndex].nonce,
            scenario: .timeout,
            diagnosticRootPath: successConfiguration.sourceRootPath
        )
        fixture.materializeOutputs()
        let artifacts = try configurations.map {
            try fixture.caseEvidence(configuration: $0)
        }
        #expect(
            throws:
                SignedInvestigationRuntimeContractError
                .invalidConfiguration
        ) {
            _ = try SignedInvestigationRuntimeMachineAssembler()
                .assemble(
                    configurations: configurations,
                    artifacts: artifacts,
                    capabilityMetadata: fixture.capabilityMetadata(),
                    capabilityWorker: fixture.capabilityWorker(
                        investigationID: successConfiguration.nonce,
                        evidenceBindingSHA256:
                            successConfiguration
                            .capabilityEvidenceBindingSHA256()
                    ),
                    capabilityLifecycleIntegrity:
                        fixture.capabilityLifecycleIntegrity(),
                    capabilityRepository:
                        fixture.capabilityRepositoryEvidence(),
                    now: fixture.now.addingTimeInterval(30)
                )
        }

    }

    @Test
    func rejectsForeignCohortAttempt() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        var configurations =
            try SignedInvestigationRuntimeDiagnosticScenario
                .allCases
                .map {
                    try fixture.configuration(
                        nonce: UUID(),
                        scenario: $0
                    )
                }
        let foreignIndex = try #require(
            configurations.firstIndex {
                $0.scenario == .transportLoss
            }
        )
        let foreignCohortRoot = fixture.root
            .appending(
                path: "foreign-cohort",
                directoryHint: .isDirectory
            )
            .appending(
                path:
                    configurations[foreignIndex]
                    .nonce.uuidString.lowercased(),
                directoryHint: .isDirectory
            )
        configurations[foreignIndex] =
            try fixture.configuration(
                nonce: configurations[foreignIndex].nonce,
                scenario: .transportLoss,
                diagnosticRootPath: foreignCohortRoot.path
            )
        fixture.materializeOutputs()
        let artifacts = try configurations.map {
            try fixture.caseEvidence(configuration: $0)
        }
        let success = try #require(
            configurations.first { $0.scenario == .success }
        )
        #expect(
            throws:
                SignedInvestigationRuntimeContractError
                .invalidConfiguration
        ) {
            _ = try SignedInvestigationRuntimeMachineAssembler()
                .assemble(
                    configurations: configurations,
                    artifacts: artifacts,
                    capabilityMetadata: fixture.capabilityMetadata(),
                    capabilityWorker: fixture.capabilityWorker(
                        investigationID: success.nonce,
                        evidenceBindingSHA256:
                            success.capabilityEvidenceBindingSHA256()
                    ),
                    capabilityLifecycleIntegrity:
                        fixture.capabilityLifecycleIntegrity(),
                    capabilityRepository:
                        fixture.capabilityRepositoryEvidence(),
                    now: fixture.now.addingTimeInterval(30)
                )
        }

    }

    @Test
    func rejectsReportTamperAfterEvidenceCreation() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configurations = try fixture.machineConfigurations()
        fixture.materializeOutputs()
        let artifacts = try configurations.map {
            try fixture.caseEvidence(configuration: $0)
        }
        let success = try #require(
            configurations.first { $0.scenario == .success }
        )
        try Data("tampered-after-evidence".utf8).write(
            to: URL(filePath: success.reportPath)
        )
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.bindingMismatch
        ) {
            _ = try SignedInvestigationRuntimeMachineAssembler()
                .assemble(
                    configurations: configurations,
                    artifacts: artifacts,
                    capabilityMetadata: fixture.capabilityMetadata(),
                    capabilityWorker: fixture.capabilityWorker(
                        investigationID: success.nonce,
                        evidenceBindingSHA256:
                            success.capabilityEvidenceBindingSHA256()
                    ),
                    capabilityLifecycleIntegrity:
                        fixture.capabilityLifecycleIntegrity(),
                    capabilityRepository:
                        fixture.capabilityRepositoryEvidence(),
                    now: fixture.now.addingTimeInterval(30)
                )
        }
    }

    @Test
    func rejectsStoreReplacementAfterEvidenceCreation() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configurations = try fixture.machineConfigurations()
        fixture.materializeOutputs()
        let artifacts = try configurations.map {
            try fixture.caseEvidence(configuration: $0)
        }
        let success = try #require(
            configurations.first { $0.scenario == .success }
        )
        let storeURL = URL(filePath: success.storePath)
        try FileManager.default.removeItem(at: storeURL)
        try writeOwnerOnly(
            Data("replacement-store".utf8),
            to: storeURL
        )

        #expect(
            throws:
                SignedInvestigationRuntimeContractError.bindingMismatch
        ) {
            _ = try SignedInvestigationRuntimeMachineAssembler()
                .assemble(
                    configurations: configurations,
                    artifacts: artifacts,
                    capabilityMetadata: fixture.capabilityMetadata(),
                    capabilityWorker: fixture.capabilityWorker(
                        investigationID: success.nonce,
                        evidenceBindingSHA256:
                            success.capabilityEvidenceBindingSHA256()
                    ),
                    capabilityLifecycleIntegrity:
                        fixture.capabilityLifecycleIntegrity(),
                    capabilityRepository:
                        fixture.capabilityRepositoryEvidence(),
                    now: fixture.now.addingTimeInterval(30)
                )
        }
    }

    @Test
    func hashingRejectsASymlinkAncestor() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        fixture.materializeOutputs()
        let linkedRoot = fixture.root.appending(
            path: "linked-root",
            directoryHint: .isDirectory
        )
        try FileManager.default.createSymbolicLink(
            at: linkedRoot,
            withDestinationURL: fixture.diagnosticRoot
        )
        let linkedReport = linkedRoot.appending(
            path: fixture.reportURL.lastPathComponent
        )

        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try machineOwnerRegularFileSHA256(linkedReport.path)
        }
    }

    @Test
    func hashingRejectsEmbeddedNULPath() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        fixture.materializeOutputs()

        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try machineOwnerRegularFileSHA256(
                fixture.reportURL.path + "\0ignored"
            )
        }
    }

    @Test
    func hashingRejectsFIFOWithoutBlocking() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let fifoURL = fixture.root.appending(path: "artifact.fifo")
        guard mkfifo(fifoURL.path, 0o600) == 0 else {
            throw MachineAdversarialSynchronizationError.timedOut
        }
        let completed = DispatchSemaphore(value: 0)
        let result = LockedMachineAdversarialResult()
        let reader = Thread {
            defer { completed.signal() }
            do {
                _ = try machineOwnerRegularFileSHA256(fifoURL.path)
                result.store(
                    MachineAdversarialSynchronizationError
                        .unexpectedSuccess
                )
            } catch {
                result.store(error)
            }
        }
        reader.start()

        let rejectedWithoutWriter =
            completed.wait(timeout: .now() + 1) == .success
        if !rejectedWithoutWriter {
            let writer = open(
                fifoURL.path,
                O_WRONLY | O_NONBLOCK | O_CLOEXEC
            )
            if writer >= 0 {
                close(writer)
            }
            _ = completed.wait(timeout: .now() + 5)
        }

        #expect(rejectedWithoutWriter)
        #expect(
            result.error as? SignedInvestigationRuntimeContractError
                == .invalidReport
        )
    }

    @Test
    func hashingRejectsFileGrowthDuringRead() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let artifactURL = fixture.root.appending(
            path: "growing-artifact.bin"
        )
        try writeOwnerOnly(
            Data(repeating: 0x61, count: 16 * 1_024 * 1_024),
            to: artifactURL
        )
        let hashingStarted = DispatchSemaphore(value: 0)
        let appendCompleted = DispatchSemaphore(value: 0)
        let writerResult = LockedMachineAdversarialResult()
        let writer = Thread {
            hashingStarted.wait()
            defer { appendCompleted.signal() }
            do {
                let handle = try FileHandle(forWritingTo: artifactURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(
                    contentsOf: Data(
                        repeating: 0x62,
                        count: 256 * 1_024
                    )
                )
            } catch {
                writerResult.store(error)
            }
        }
        writer.start()

        var didSynchronize = false
        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try machineOwnerRegularFileSHA256(
                artifactURL.path,
                didRead: { _ in
                    guard !didSynchronize else { return }
                    didSynchronize = true
                    hashingStarted.signal()
                    guard
                        appendCompleted.wait(
                            timeout: .now() + 5
                        ) == .success
                    else {
                        throw MachineAdversarialSynchronizationError
                            .timedOut
                    }
                }
            )
        }
        if !didSynchronize {
            hashingStarted.signal()
            _ = appendCompleted.wait(timeout: .now() + 5)
        }
        #expect(didSynchronize)
        if let error = writerResult.error {
            throw error
        }
    }

    @Test
    func rejectsRepeatedSealedCohortInvocation() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configurations = try fixture.machineConfigurations()
        fixture.materializeOutputs()
        let artifacts = try configurations.map {
            try fixture.caseEvidence(configuration: $0)
        }
        let success = try #require(
            configurations.first { $0.scenario == .success }
        )
        let lifecycleRecords = try fixture.lifecycleResidueRecords(
            artifacts: artifacts
        )

        #expect(
            throws:
                SignedInvestigationRuntimeContractError.invalidReport
        ) {
            _ = try SignedInvestigationRuntimeMachineAssembler()
                .assemble(
                    configurations: configurations,
                    artifacts: artifacts,
                    lifecycleResidueRecords: lifecycleRecords,
                    capabilityMetadata: fixture.capabilityMetadata(),
                    capabilityWorker: fixture.capabilityWorker(
                        investigationID: success.nonce,
                        evidenceBindingSHA256:
                            success.capabilityEvidenceBindingSHA256()
                    ),
                    capabilityLifecycleIntegrity:
                        fixture.capabilityLifecycleIntegrity(),
                    capabilityRepository:
                        fixture.capabilityRepositoryEvidence(),
                    sealedCohortAuthority:
                        RepeatedInvocationSealedCohortAuthority(
                            lifecycleRecords: lifecycleRecords
                        ),
                    now: fixture.now.addingTimeInterval(30)
                )
        }
    }
}

private let machineTestVolumeIsCaseInsensitive: Bool = {
    let values = try? FileManager.default.temporaryDirectory
        .resourceValues(
            forKeys: [.volumeSupportsCaseSensitiveNamesKey]
        )
    return values?.volumeSupportsCaseSensitiveNames == false
}()

private struct RepeatedInvocationSealedCohortAuthority:
    SignedInvestigationRuntimeSealedCohortAuthority
{
    let lifecycleRecords:
        [SignedInvestigationRuntimeLifecycleResidueRecord]

    func withSealedCohort<Result: Sendable>(
        configurations:
            [SignedInvestigationRuntimeDiagnosticConfiguration],
        expectedLifecycleResidueRecords:
            [SignedInvestigationRuntimeLifecycleResidueRecord],
        _ operation:
            @Sendable (
                [
                    SignedInvestigationRuntimeLifecycleResidueObservation
                ]
            ) throws -> Result
    ) throws -> Result {
        guard
            !configurations.isEmpty,
            lifecycleRecords.sorted(by: lifecycleRecordOrder)
                == expectedLifecycleResidueRecords.sorted(
                    by: lifecycleRecordOrder
                )
        else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        let observations = lifecycleRecords.map {
            SignedInvestigationRuntimeLifecycleResidueObservation(
                record: $0
            )
        }
        let result = try operation(observations)
        _ = try operation(observations)
        return result
    }

    private func lifecycleRecordOrder(
        _ left: SignedInvestigationRuntimeLifecycleResidueRecord,
        _ right: SignedInvestigationRuntimeLifecycleResidueRecord
    ) -> Bool {
        left.scenario.rawValue < right.scenario.rawValue
    }
}

private final class LockedMachineAdversarialResult:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var storedError: (any Error)?

    var error: (any Error)? {
        lock.withLock { storedError }
    }

    func store(_ error: any Error) {
        lock.withLock {
            storedError = error
        }
    }
}

private enum MachineAdversarialSynchronizationError: Error {
    case timedOut
    case unexpectedSuccess
}
