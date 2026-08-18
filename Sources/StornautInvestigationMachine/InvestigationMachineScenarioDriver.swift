import Darwin
import Foundation
import StornautCore
import StornautInvestigation
import StornautLifecycle

enum InvestigationMachineScenarioDriverError:
    Error,
    Sendable,
    Equatable
{
    case invalidCohort
    case consumed
}

struct InvestigationMachineSyntheticSuccessEvidence:
    Sendable,
    Equatable
{
    let capabilityEvidenceSHA256: String
    let denials: [SignedInvestigationRuntimeDenialEvidence]
}

struct InvestigationMachineScenarioAttempt: Sendable {
    let configuration:
        SignedInvestigationRuntimeDiagnosticConfiguration
    let plan: InvestigationPlan
    let host: InvestigationMachineDriverHost
    let runner: InvestigationFixedScenarioRunner
    let syntheticSuccessEvidence:
        InvestigationMachineSyntheticSuccessEvidence?

    init(
        configuration:
            SignedInvestigationRuntimeDiagnosticConfiguration,
        plan: InvestigationPlan,
        host: InvestigationMachineDriverHost,
        runner: InvestigationFixedScenarioRunner,
        syntheticSuccessEvidence:
            InvestigationMachineSyntheticSuccessEvidence?
    ) throws {
        guard
            plan.id.rawValue
                == "investigation-"
                    + configuration.nonce.uuidString.lowercased(),
            plan.sourceFingerprint.hex
                == configuration.binding.sourceFingerprintSHA256,
            host.configuration == configuration,
            host.transitionBindingToken == runner.bindingToken,
            runner.configuration == configuration,
            runner.plan == plan,
            (configuration.scenario == .success)
                == (syntheticSuccessEvidence != nil),
            syntheticSuccessEvidence.map(
                InvestigationMachineScenarioDriver
                    .validSyntheticSuccessEvidence
            ) ?? true
        else {
            throw InvestigationMachineScenarioDriverError.invalidCohort
        }
        self.configuration = configuration
        self.plan = plan
        self.host = host
        self.runner = runner
        self.syntheticSuccessEvidence = syntheticSuccessEvidence
    }
}

private struct InvestigationMachineScenarioObjectIdentity: Hashable {
    let device: UInt64
    let inode: UInt64
}

private struct InvestigationMachineScenarioOpenedObject {
    let descriptor: Int32
    let identity: InvestigationMachineScenarioObjectIdentity
}

actor InvestigationMachineScenarioDriver {
    private enum State {
        case ready
        case running
        case consumed
    }

    private var state = State.ready

    func run(
        attempts: [InvestigationMachineScenarioAttempt]
    ) async throws -> SignedInvestigationRuntimeFailureMatrix {
        guard case .ready = state else {
            throw InvestigationMachineScenarioDriverError.consumed
        }
        state = .running
        defer { state = .consumed }

        let ordered = try preflight(attempts)
        var evidence: [SignedInvestigationRuntimeMachineCaseEvidence] = []
        evidence.reserveCapacity(ordered.count)
        for attempt in ordered {
            let authority = try await attempt.host.run()
            let observation = try await attempt.runner.consumeObservation()
            evidence.append(
                try makeEvidence(
                    attempt: attempt,
                    authority: authority,
                    observation: observation
                )
            )
        }
        return try SignedInvestigationRuntimeFailureMatrix(
            cases: evidence
        )
    }

    private func preflight(
        _ attempts: [InvestigationMachineScenarioAttempt]
    ) throws -> [InvestigationMachineScenarioAttempt] {
        let scenarios =
            SignedInvestigationRuntimeDiagnosticScenario.allCases
        guard attempts.count == scenarios.count else {
            throw InvestigationMachineScenarioDriverError.invalidCohort
        }
        let byScenario = Dictionary(
            grouping: attempts,
            by: { $0.configuration.scenario }
        )
        guard
            Set(byScenario.keys) == Set(scenarios),
            byScenario.values.allSatisfy({ $0.count == 1 })
        else {
            throw InvestigationMachineScenarioDriverError.invalidCohort
        }
        let ordered = try scenarios.map { scenario in
            guard let attempt = byScenario[scenario]?.first else {
                throw InvestigationMachineScenarioDriverError
                    .invalidCohort
            }
            return attempt
        }
        let configurations = ordered.map(\.configuration)
        let plans = ordered.map(\.plan)
        let configurationDigests = try configurations.map {
            try $0.machineConfigurationSHA256()
        }
        let diagnosticRoots = configurations.map(\.diagnosticRootPath)
        let pathGroups = [
            diagnosticRoots,
            configurations.map(\.sourceRootPath),
            configurations.map(\.supportRootPath),
            configurations.map(\.runtimeRootPath),
            configurations.map(\.reportPath),
            configurations.map(\.storePath),
        ]
        guard
            Set(configurations.map(\.nonce)).count == ordered.count,
            Set(configurationDigests).count == ordered.count,
            pathGroups.allSatisfy({ Set($0).count == ordered.count }),
            Set(diagnosticRoots.map {
                URL(filePath: $0).deletingLastPathComponent().path
            }).count == 1,
            pairwiseRootsDoNotOverlap(diagnosticRoots),
            configurations.dropFirst().allSatisfy({
                $0.binding == configurations[0].binding
            }),
            Set(plans.map(\.fingerprint)).count == ordered.count,
            plans.dropFirst().allSatisfy({
                $0.targetSetFingerprint
                    == plans[0].targetSetFingerprint
            }),
            try uniqueOpenedObjects(
                configurations: configurations
            )
        else {
            throw InvestigationMachineScenarioDriverError.invalidCohort
        }
        for attempt in ordered {
            let configuration = attempt.configuration
            guard
                attempt.plan.id.rawValue
                    == "investigation-"
                        + configuration.nonce.uuidString.lowercased(),
                attempt.plan.sourceFingerprint.hex
                    == configuration.binding.sourceFingerprintSHA256,
                configuration.reportPath
                    == URL(filePath: configuration.diagnosticRootPath)
                        .appending(path: "report.json")
                        .path,
                configuration.storePath
                    == URL(filePath: configuration.diagnosticRootPath)
                        .appending(
                            path: "support/com.eriklee.stornaut/"
                                + "Evidence.sqlite"
                        )
                        .path,
                (configuration.scenario == .success)
                    == (attempt.syntheticSuccessEvidence != nil),
                attempt.syntheticSuccessEvidence.map(
                    Self.validSyntheticSuccessEvidence
                ) ?? true
            else {
                throw InvestigationMachineScenarioDriverError
                    .invalidCohort
            }
        }
        return ordered
    }

    private func uniqueOpenedObjects(
        configurations:
            [SignedInvestigationRuntimeDiagnosticConfiguration]
    ) throws -> Bool {
        var opened: [InvestigationMachineScenarioOpenedObject] = []
        defer { opened.forEach { close($0.descriptor) } }
        let roots = try configurations.map {
            let object = try openedObject(
                $0.diagnosticRootPath,
                directory: true
            )
            opened.append(object)
            return object.identity
        }
        let reports = try configurations.map {
            let object = try openedObject(
                $0.reportPath,
                directory: false,
                maximumBytes: 16 * 1_024 * 1_024
            )
            opened.append(object)
            return object.identity
        }
        let stores = try configurations.map {
            let object = try openedObject(
                $0.storePath,
                directory: false,
                maximumBytes: 1_073_741_824
            )
            opened.append(object)
            return object.identity
        }
        return [roots, reports, stores].allSatisfy {
            Set($0).count == configurations.count
        }
    }

    private func openedObject(
        _ path: String,
        directory: Bool,
        maximumBytes: Int64? = nil
    ) throws -> InvestigationMachineScenarioOpenedObject {
        let components = (path as NSString).pathComponents
        guard components.first == "/", components.count > 1 else {
            throw InvestigationMachineScenarioDriverError.invalidCohort
        }
        var descriptor = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard descriptor >= 0 else {
            throw InvestigationMachineScenarioDriverError.invalidCohort
        }
        for (index, component) in components.dropFirst().enumerated() {
            let isLast = index == components.count - 2
            let flags = O_RDONLY | O_NONBLOCK | O_CLOEXEC | O_NOFOLLOW
                | ((!isLast || directory) ? O_DIRECTORY : 0)
            let next = component.withCString {
                openat(descriptor, $0, flags)
            }
            close(descriptor)
            guard next >= 0 else {
                throw InvestigationMachineScenarioDriverError
                    .invalidCohort
            }
            descriptor = next
        }
        var information = stat()
        let expectedType = directory ? S_IFDIR : S_IFREG
        guard
            fstat(descriptor, &information) == 0,
            information.st_mode & S_IFMT == expectedType,
            information.st_uid == getuid(),
            directory
                ? information.st_mode & 0o077 == 0
                : information.st_mode & 0o777 == 0o600
                    && information.st_nlink == 1
                    && information.st_size > 0
                    && (maximumBytes.map {
                        information.st_size <= $0
                    } == true)
        else {
            close(descriptor)
            throw InvestigationMachineScenarioDriverError.invalidCohort
        }
        return InvestigationMachineScenarioOpenedObject(
            descriptor: descriptor,
            identity: InvestigationMachineScenarioObjectIdentity(
                device: UInt64(bitPattern: Int64(information.st_dev)),
                inode: UInt64(information.st_ino)
            )
        )
    }

    private func pairwiseRootsDoNotOverlap(
        _ roots: [String]
    ) -> Bool {
        for leftIndex in roots.indices {
            for rightIndex in roots.indices where rightIndex > leftIndex {
                let left = roots[leftIndex]
                let right = roots[rightIndex]
                if left == right
                    || left.hasPrefix(right + "/")
                    || right.hasPrefix(left + "/")
                {
                    return false
                }
            }
        }
        return true
    }

    private func makeEvidence(
        attempt: InvestigationMachineScenarioAttempt,
        authority: InvestigationMachineTopologyAuthority,
        observation: InvestigationFixedScenarioObservation
    ) throws -> SignedInvestigationRuntimeMachineCaseEvidence {
        let configuration = attempt.configuration
        let plan = attempt.plan
        let cohort = authority.cohort
        guard
            cohort.investigationID.rawValue == configuration.nonce,
            cohort.scenario == configuration.scenario,
            cohort.signedBinding == configuration.binding,
            cohort.ownerRetirementObservation
                == .retiredOwnedResources,
            cohort.lifecycleResidueObservation.provedEmpty,
            cohort.installedTopology.provesInstalledTopology,
            cohort.postTeardownTopology.provesPostTeardownTopology,
            cohort.observedAt >= observation.completedAt,
            observation.scenario == configuration.scenario,
            observation.nonce == configuration.nonce,
            observation.investigationID == plan.id,
            observation.sourceFingerprint == plan.sourceFingerprint,
            observation.planFingerprint == plan.fingerprint,
            observation.targetSetFingerprint
                == plan.targetSetFingerprint,
            observation.isExpectedOutcome
        else {
            throw InvestigationMachineScenarioDriverError.invalidCohort
        }
        return try SignedInvestigationRuntimeMachineCaseEvidence(
            scenario: observation.scenario,
            nonce: observation.nonce,
            configurationSHA256:
                configuration.machineConfigurationSHA256(),
            runtimeArtifactSHA256:
                machineOwnerRegularFileSHA256(
                    configuration.reportPath
                ),
            evidenceStoreSHA256:
                machineOwnerRegularFileSHA256(
                    configuration.storePath
                ),
            capabilityEvidenceSHA256:
                attempt.syntheticSuccessEvidence?
                    .capabilityEvidenceSHA256,
            binding: configuration.binding,
            investigationID: observation.investigationID,
            runID: observation.runID,
            reportID: observation.finalReportID,
            sourceFingerprint: observation.sourceFingerprint,
            planFingerprint: observation.planFingerprint,
            targetSetFingerprint:
                observation.targetSetFingerprint,
            outcome: observation.outcome,
            runStarted: observation.runStarted,
            turnAdmitted: observation.turnAdmitted,
            finalEnvelopeAccepted:
                observation.finalEnvelopeAccepted,
            terminalBarrierSettled:
                observation.terminalBarrierSettled,
            artifactsRetired: observation.artifactsRetired,
            localRuntimeDrained: observation.localRuntimeDrained,
            recoveryAttempted: observation.recoveryAttempted,
            recoveryCompleted: observation.recoveryCompleted,
            denials: attempt.syntheticSuccessEvidence?.denials ?? [],
            finalResidue: SignedInvestigationRuntimeResidue(
                appProcessCount: 0,
                helperProcessCount: 0,
                workerProcessCount: 0,
                proxyProcessCount: 0,
                leaseCount: 0,
                runtimeArtifactCount: 0
            ),
            observationReasonKey: observation.observationReasonKey,
            upstreamError: observation.upstreamError,
            startedAt: observation.startedAt,
            completedAt: observation.completedAt
        )
    }

    fileprivate static func validSyntheticSuccessEvidence(
        _ evidence: InvestigationMachineSyntheticSuccessEvidence
    ) -> Bool {
        evidence.capabilityEvidenceSHA256.utf8.count == 64
            && evidence.capabilityEvidenceSHA256.unicodeScalars
                .allSatisfy {
                    (0x30...0x39).contains($0.value)
                        || (0x61...0x66).contains($0.value)
                }
            && Set(evidence.denials.map(\.kind))
                == SignedInvestigationRuntimeDenialKind.required
            && evidence.denials.count
                == SignedInvestigationRuntimeDenialKind.required.count
            && evidence.denials.allSatisfy {
                $0.attempted
                    && $0.contained
                    && $0.controlReasonKey != nil
                    && $0.failureReasonKey == nil
            }
    }
}
