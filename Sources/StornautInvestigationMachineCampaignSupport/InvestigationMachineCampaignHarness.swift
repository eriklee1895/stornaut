#if DEBUG
import CInvestigationIdentitySupport
import CInvestigationMachineCampaignSupport
import Darwin
import Foundation
import StornautInvestigationHandoffContract

package struct InvestigationMachineCampaignExpectedBinding:
    Sendable, Equatable
{
    package let attemptUUID: UUID
    package let buildProvenanceSHA256: String
    package let signedRuntimeBindingSHA256: InvestigationHandoffSHA256
    package let wholeProjectedInputSHA256: InvestigationHandoffSHA256

    package init(
        attemptUUID: UUID, buildProvenanceSHA256: String,
        signedRuntimeBindingSHA256: InvestigationHandoffSHA256,
        wholeProjectedInputSHA256: InvestigationHandoffSHA256
    ) throws {
        guard Self.nonzero(attemptUUID),
              buildProvenanceSHA256.utf8.count == 64,
              buildProvenanceSHA256.utf8.allSatisfy({ byte in
                  (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                      || (UInt8(ascii: "a")...UInt8(ascii: "f")).contains(byte)
              }),
              signedRuntimeBindingSHA256.rawBytes.contains(where: { $0 != 0 }),
              wholeProjectedInputSHA256.rawBytes.contains(where: { $0 != 0 })
        else { throw InvestigationMachineCampaignHarnessFailure.bindingInvalid }
        self.attemptUUID = attemptUUID
        self.buildProvenanceSHA256 = buildProvenanceSHA256
        self.signedRuntimeBindingSHA256 = signedRuntimeBindingSHA256
        self.wholeProjectedInputSHA256 = wholeProjectedInputSHA256
    }

    private static func nonzero(_ value: UUID) -> Bool {
        withUnsafeBytes(of: value.uuid) { $0.contains(where: { $0 != 0 }) }
    }
}

package struct InvestigationMachineCampaignSpawnedProcess:
    Sendable, Equatable
{
    package let processID: pid_t
    package let terminalDescriptor: Int32
    package let receiptDescriptor: Int32
    package let bootstrapDescriptor: Int32
    package let parentTransferCloseError: Int32?

    package init(
        processID: pid_t, terminalDescriptor: Int32, receiptDescriptor: Int32,
        bootstrapDescriptor: Int32 = 12,
        parentTransferCloseError: Int32? = nil
    ) {
        self.processID = processID
        self.terminalDescriptor = terminalDescriptor
        self.receiptDescriptor = receiptDescriptor
        self.bootstrapDescriptor = bootstrapDescriptor
        self.parentTransferCloseError = parentTransferCloseError
    }
}

package struct InvestigationMachineCampaignOuterIdentity:
    Sendable, Equatable
{
    package let processID: pid_t
    package let processIDVersion: UInt32
    package let parentProcessID: pid_t
    package let processGroupID: pid_t
    package let sessionID: pid_t
    package let foregroundProcessGroupID: pid_t
    package let effectiveUserID: uid_t
    package let startTimeSeconds: UInt64
    package let startTimeMicroseconds: UInt64

    package init(
        processID: pid_t, processIDVersion: UInt32, parentProcessID: pid_t,
        processGroupID: pid_t, sessionID: pid_t,
        foregroundProcessGroupID: pid_t, effectiveUserID: uid_t,
        startTimeSeconds: UInt64, startTimeMicroseconds: UInt64
    ) {
        self.processID = processID
        self.processIDVersion = processIDVersion
        self.parentProcessID = parentProcessID
        self.processGroupID = processGroupID
        self.sessionID = sessionID
        self.foregroundProcessGroupID = foregroundProcessGroupID
        self.effectiveUserID = effectiveUserID
        self.startTimeSeconds = startTimeSeconds
        self.startTimeMicroseconds = startTimeMicroseconds
    }
}

package enum InvestigationMachineCampaignChannel: Hashable, Sendable {
    case terminal
    case receipt
}

package enum InvestigationMachineCampaignReadObservation:
    Sendable, Equatable
{
    case bytes(Data)
    case eof
}

package enum InvestigationMachineCampaignExactWait: Sendable, Equatable {
    case exited(status: Int32)
    case signaled(signal: Int32)
    case stopped(signal: Int32)
}

package struct InvestigationMachineCampaignResidueObservation:
    Sendable, Equatable
{
    package let processGroupMembers: [pid_t]
    package let sessionMembers: [pid_t]
    package let complete: Bool

    package init(
        processGroupMembers: [pid_t], sessionMembers: [pid_t], complete: Bool
    ) {
        self.processGroupMembers = processGroupMembers
        self.sessionMembers = sessionMembers
        self.complete = complete
    }
}

package enum InvestigationMachineCampaignHarnessOperation:
    Sendable, Equatable
{
    case makeAbsoluteDeadline
    case observeHarness(absoluteDeadlineNanoseconds: UInt64)
    case spawnFixedSibling(absoluteDeadlineNanoseconds: UInt64)
    case readBootstrap(
        descriptor: Int32, maximumByteCount: Int,
        absoluteDeadlineNanoseconds: UInt64
    )
    case observeOuterIdentity(
        processID: pid_t, absoluteDeadlineNanoseconds: UInt64
    )
    case pollReadable(
        channels: [InvestigationMachineCampaignChannel],
        absoluteDeadlineNanoseconds: UInt64
    )
    case read(
        channel: InvestigationMachineCampaignChannel, maximumByteCount: Int,
        absoluteDeadlineNanoseconds: UInt64
    )
    case terminateOwnedGroup(
        processID: pid_t, processGroupID: pid_t,
        absoluteDeadlineNanoseconds: UInt64
    )
    case waitExact(
        processID: pid_t, absoluteDeadlineNanoseconds: UInt64
    )
    case observeResidue(
        processGroupID: pid_t, sessionID: pid_t,
        absoluteDeadlineNanoseconds: UInt64
    )
    case closeParentChannels(
        terminalDescriptor: Int32, receiptDescriptor: Int32,
        bootstrapDescriptor: Int32,
        absoluteDeadlineNanoseconds: UInt64
    )
}

package enum InvestigationMachineCampaignHarnessResponse:
    Sendable, Equatable
{
    case absoluteDeadline(UInt64)
    case harnessIdentity(processID: pid_t, effectiveUserID: uid_t)
    case spawned(InvestigationMachineCampaignSpawnedProcess)
    case bootstrap(bytes: Data, reachedEOF: Bool)
    case outerIdentity(InvestigationMachineCampaignOuterIdentity)
    case readable([InvestigationMachineCampaignChannel])
    case read(InvestigationMachineCampaignReadObservation)
    case wait(InvestigationMachineCampaignExactWait)
    case residue(InvestigationMachineCampaignResidueObservation)
    case completed
}

package protocol InvestigationMachineCampaignHarnessSystem: Sendable {
    func perform(
        _ operation: InvestigationMachineCampaignHarnessOperation
    ) async throws -> InvestigationMachineCampaignHarnessResponse
}

package struct InvestigationMachineCampaignHarnessResult:
    Sendable, Equatable
{
    package let receipt: InvestigationMachineCoordinatorRawReceiptV1
    package let diagnosticBytes: Data
    package let outerIdentity: InvestigationMachineCampaignOuterIdentity
    package let receiptReachedEOF: Bool
    package let terminalReachedEOF: Bool
    package let exactWait: InvestigationMachineCampaignExactWait
    package let residue: InvestigationMachineCampaignResidueObservation
}

package enum InvestigationMachineCampaignHarnessFailure:
    Error, Sendable, Equatable
{
    case alreadyConsumed
    case bindingInvalid
    case deadlineExceeded
    case spawnUncertain
    case identityMismatch
    case receiptInvalid
    case diagnosticOverflow
    case childTerminated
    case exactReapUncertain
    case residueUncertain
    case transportUncertain
    case cancelled
    case unexpectedResponse
}

package enum InvestigationMachineCampaignCleanupIssue:
    Sendable, Equatable
{
    case identityObservationFailed
    case terminateFailed
    case waitFailed
    case closeFailed
    case residueObservationFailed
}

package struct InvestigationMachineCampaignHarnessFailureResult:
    Sendable, Equatable
{
    package let primary: InvestigationMachineCampaignHarnessFailure
    package let cleanupIssues: [InvestigationMachineCampaignCleanupIssue]
}

package enum InvestigationMachineCampaignHarnessOutcome:
    Sendable, Equatable
{
    case completed(InvestigationMachineCampaignHarnessResult)
    case failed(InvestigationMachineCampaignHarnessFailureResult)
}

package actor InvestigationMachineCampaignHarness {
    private static let readMaximumByteCount = 16 * 1_024
    private static let diagnosticMaximumByteCount =
        Int(InvestigationMachineEvidenceArtifact.maximumByteCount)
    private static let receiptMaximumByteCount =
        InvestigationMachineCoordinatorRawReceiptV1.maximumByteCount + 4

    private enum State { case fresh, running, consumed }
    private let system: any InvestigationMachineCampaignHarnessSystem
    private var state = State.fresh

    package init(system: any InvestigationMachineCampaignHarnessSystem) {
        self.system = system
    }

    package func run(
        expected: InvestigationMachineCampaignExpectedBinding
    ) async -> InvestigationMachineCampaignHarnessOutcome {
        guard state == .fresh else { return Self.failure(.alreadyConsumed) }
        state = .running
        defer { state = .consumed }
        return await execute(expected: expected)
    }

    private func execute(
        expected: InvestigationMachineCampaignExpectedBinding
    ) async -> InvestigationMachineCampaignHarnessOutcome {
        let deadline: UInt64
        do {
            guard case let .absoluteDeadline(value) = try await system.perform(
                .makeAbsoluteDeadline
            ), value > 0 else { return Self.failure(.deadlineExceeded) }
            deadline = value
        } catch { return Self.failure(.deadlineExceeded) }

        let harnessPID: pid_t
        let harnessUID: uid_t
        do {
            guard case let .harnessIdentity(processID, effectiveUserID) =
                    try await system.perform(.observeHarness(
                        absoluteDeadlineNanoseconds: deadline
                    )),
                  processID > 1
            else { return Self.failure(.identityMismatch) }
            harnessPID = processID
            harnessUID = effectiveUserID
        } catch { return Self.failure(.identityMismatch) }

        let spawned: InvestigationMachineCampaignSpawnedProcess
        do {
            guard case let .spawned(value) = try await system.perform(
                .spawnFixedSibling(absoluteDeadlineNanoseconds: deadline)
            )
            else { return Self.failure(.spawnUncertain) }
            spawned = value
        } catch { return Self.failure(.spawnUncertain) }
        guard Self.valid(spawned) else {
            guard spawned.processID > 1 else {
                return Self.failure(.spawnUncertain)
            }
            return await finalizeMalformedSpawn(
                primary: .spawnUncertain, spawned: spawned, deadline: deadline,
                harnessPID: harnessPID, harnessUID: harnessUID
            )
        }

        var primary: InvestigationMachineCampaignHarnessFailure?
        do {
            guard spawned.parentTransferCloseError == nil,
                  case let .bootstrap(bytes, reachedEOF) = try await system.perform(
                    .readBootstrap(
                        descriptor: spawned.bootstrapDescriptor,
                        maximumByteCount: 16,
                        absoluteDeadlineNanoseconds: deadline
                    )
                  ),
                  bytes == Data([
                      UInt8(STORNAUT_INVESTIGATION_CAMPAIGN_BOOTSTRAP_READY)
                  ]), reachedEOF
            else { primary = .spawnUncertain; throw HarnessInternalError.bootstrap }
        } catch {
            return await finalize(
                primary: primary ?? .spawnUncertain, spawned: spawned,
                deadline: deadline, outerIdentity: nil, receipt: nil,
                diagnosticBytes: Data(), receiptEOF: false, terminalEOF: false
            )
        }
        var outerIdentity: InvestigationMachineCampaignOuterIdentity?
        do {
            guard case let .outerIdentity(value) = try await system.perform(
                .observeOuterIdentity(
                    processID: spawned.processID,
                    absoluteDeadlineNanoseconds: deadline
                )
            ), Self.valid(
                value, spawned: spawned, harnessPID: harnessPID,
                harnessUID: harnessUID
            ) else {
                primary = .identityMismatch
                return await finalize(
                    primary: primary!, spawned: spawned, deadline: deadline,
                    outerIdentity: nil, receipt: nil, diagnosticBytes: Data(),
                    receiptEOF: false, terminalEOF: false
                )
            }
            outerIdentity = value
        } catch {
            return await finalize(
                primary: .identityMismatch, spawned: spawned,
                deadline: deadline, outerIdentity: nil, receipt: nil,
                diagnosticBytes: Data(), receiptEOF: false, terminalEOF: false
            )
        }

        var diagnosticBytes = Data()
        var receiptBytes = Data()
        var terminalEOF = false
        var receiptEOF = false
        var preferred = InvestigationMachineCampaignChannel.terminal

        drain: while !terminalEOF || !receiptEOF {
            if Task.isCancelled { primary = .cancelled; break }
            let channels = Self.orderedOpenChannels(
                preferred: preferred, terminalEOF: terminalEOF,
                receiptEOF: receiptEOF
            )
            do {
                guard case let .readable(ready) = try await system.perform(
                    .pollReadable(
                        channels: channels,
                        absoluteDeadlineNanoseconds: deadline
                    )
                ) else { primary = .unexpectedResponse; break }
                guard let channel = channels.first(where: { ready.contains($0) })
                else {
                    primary = !receiptEOF && !receiptBytes.isEmpty
                        ? .receiptInvalid : .deadlineExceeded
                    break
                }
                guard case let .read(observation) = try await system.perform(
                    .read(
                        channel: channel,
                        maximumByteCount: Self.readMaximumByteCount,
                        absoluteDeadlineNanoseconds: deadline
                    )
                ) else { primary = .unexpectedResponse; break }
                switch (channel, observation) {
                case (.terminal, .bytes(let bytes)):
                    guard !bytes.isEmpty, diagnosticBytes.count + bytes.count
                            <= Self.diagnosticMaximumByteCount
                    else { primary = .diagnosticOverflow; break drain }
                    diagnosticBytes.append(bytes)
                case (.receipt, .bytes(let bytes)):
                    guard !bytes.isEmpty, receiptBytes.count + bytes.count
                            <= Self.receiptMaximumByteCount
                    else { primary = .receiptInvalid; break drain }
                    receiptBytes.append(bytes)
                case (.terminal, .eof): terminalEOF = true
                case (.receipt, .eof): receiptEOF = true
                }
                preferred = channel == .terminal ? .receipt : .terminal
            } catch {
                primary = Task.isCancelled ? .cancelled : .transportUncertain
                break
            }
        }

        var receipt: InvestigationMachineCoordinatorRawReceiptV1?
        if primary == nil {
            do {
                let value = try InvestigationMachineCoordinatorRawReceiptV1
                    .decodeFrame(receiptBytes, reachedEOF: receiptEOF)
                guard Self.matches(value, expected: expected) else {
                    primary = .identityMismatch
                    return await finalize(
                        primary: primary!, spawned: spawned, deadline: deadline,
                        outerIdentity: outerIdentity, receipt: nil,
                        diagnosticBytes: diagnosticBytes, receiptEOF: receiptEOF,
                        terminalEOF: terminalEOF
                    )
                }
                receipt = value
            } catch { primary = .receiptInvalid }
        }

        if primary == nil {
            do {
                guard case let .outerIdentity(value) = try await system.perform(
                    .observeOuterIdentity(
                        processID: spawned.processID,
                        absoluteDeadlineNanoseconds: deadline
                    )
                ), value == outerIdentity, Self.valid(
                    value, spawned: spawned, harnessPID: harnessPID,
                    harnessUID: harnessUID
                ) else {
                    primary = .identityMismatch
                    return await finalize(
                        primary: primary!, spawned: spawned, deadline: deadline,
                        outerIdentity: outerIdentity, receipt: receipt,
                        diagnosticBytes: diagnosticBytes, receiptEOF: receiptEOF,
                        terminalEOF: terminalEOF
                    )
                }
            } catch { primary = .identityMismatch }
        }

        return await finalize(
            primary: primary, spawned: spawned, deadline: deadline,
            outerIdentity: outerIdentity, receipt: receipt,
            diagnosticBytes: diagnosticBytes, receiptEOF: receiptEOF,
            terminalEOF: terminalEOF
        )
    }

    private func finalize(
        primary initialPrimary: InvestigationMachineCampaignHarnessFailure?,
        spawned: InvestigationMachineCampaignSpawnedProcess, deadline: UInt64,
        outerIdentity: InvestigationMachineCampaignOuterIdentity?,
        receipt: InvestigationMachineCoordinatorRawReceiptV1?,
        diagnosticBytes: Data, receiptEOF: Bool, terminalEOF: Bool
    ) async -> InvestigationMachineCampaignHarnessOutcome {
        var primary = initialPrimary
        var cleanupIssues: [InvestigationMachineCampaignCleanupIssue] = []
        var terminationAttempted = false
        if primary != nil {
            terminationAttempted = true
            do {
                guard case .completed = try await system.perform(
                    .terminateOwnedGroup(
                        processID: spawned.processID,
                        processGroupID: spawned.processID,
                        absoluteDeadlineNanoseconds: deadline
                    )
                ) else { throw HarnessInternalError.unexpectedResponse }
            } catch { cleanupIssues.append(.terminateFailed) }
        }

        var exactWait: InvestigationMachineCampaignExactWait?
        var needsTerminalWaitRetry = false
        do {
            guard case let .wait(value) = try await system.perform(
                .waitExact(
                    processID: spawned.processID,
                    absoluteDeadlineNanoseconds: deadline
                )
            ) else { throw HarnessInternalError.unexpectedResponse }
            exactWait = value
            switch value {
            case .exited(status: 0): break
            case .exited, .signaled:
                if primary == nil { primary = .childTerminated }
            case .stopped:
                if primary == nil { primary = .childTerminated }
                needsTerminalWaitRetry = true
            }
        } catch {
            cleanupIssues.append(.waitFailed)
            if primary == nil { primary = .exactReapUncertain }
            needsTerminalWaitRetry = true
        }
        if needsTerminalWaitRetry {
            if !terminationAttempted {
                terminationAttempted = true
                do {
                    guard case .completed = try await system.perform(
                        .terminateOwnedGroup(
                            processID: spawned.processID,
                            processGroupID: spawned.processID,
                            absoluteDeadlineNanoseconds: deadline
                        )
                    ) else { throw HarnessInternalError.unexpectedResponse }
                } catch { cleanupIssues.append(.terminateFailed) }
            }
            do {
                guard case let .wait(value) = try await system.perform(
                    .waitExact(
                        processID: spawned.processID,
                        absoluteDeadlineNanoseconds: deadline
                    )
                ) else { throw HarnessInternalError.unexpectedResponse }
                switch value {
                case .exited, .signaled: exactWait = value
                case .stopped: throw HarnessInternalError.unexpectedResponse
                }
            } catch { cleanupIssues.append(.waitFailed) }
        }
        return await completeFinalization(
            primary: primary, cleanupIssues: cleanupIssues, spawned: spawned,
            deadline: deadline, outerIdentity: outerIdentity, receipt: receipt,
            diagnosticBytes: diagnosticBytes, receiptEOF: receiptEOF,
            terminalEOF: terminalEOF, exactWait: exactWait
        )
    }

    private func finalizeMalformedSpawn(
        primary: InvestigationMachineCampaignHarnessFailure,
        spawned: InvestigationMachineCampaignSpawnedProcess, deadline: UInt64,
        harnessPID: pid_t, harnessUID: uid_t
    ) async -> InvestigationMachineCampaignHarnessOutcome {
        var cleanupIssues: [InvestigationMachineCampaignCleanupIssue] = []
        do {
            guard case let .outerIdentity(value) = try await system.perform(
                .observeOuterIdentity(
                    processID: spawned.processID,
                    absoluteDeadlineNanoseconds: deadline
                )
            ), Self.validIdentityShape(
                value, processID: spawned.processID, harnessPID: harnessPID,
                harnessUID: harnessUID
            ) else { throw HarnessInternalError.unexpectedResponse }
            _ = value
        } catch { cleanupIssues.append(.identityObservationFailed) }
        do {
            guard case .completed = try await system.perform(
                .terminateOwnedGroup(
                    processID: spawned.processID,
                    processGroupID: spawned.processID,
                    absoluteDeadlineNanoseconds: deadline
                )
            ) else { throw HarnessInternalError.unexpectedResponse }
        } catch { cleanupIssues.append(.terminateFailed) }
        do {
            guard case let .wait(value) = try await system.perform(.waitExact(
                processID: spawned.processID,
                absoluteDeadlineNanoseconds: deadline
            )) else { throw HarnessInternalError.unexpectedResponse }
            switch value {
            case .exited, .signaled: break
            case .stopped:
                guard case .completed = try await system.perform(
                    .terminateOwnedGroup(
                        processID: spawned.processID,
                        processGroupID: spawned.processID,
                        absoluteDeadlineNanoseconds: deadline
                    )
                ), case let .wait(retry) = try await system.perform(.waitExact(
                    processID: spawned.processID,
                    absoluteDeadlineNanoseconds: deadline
                )) else { throw HarnessInternalError.unexpectedResponse }
                guard case .exited = retry else {
                    if case .signaled = retry { break }
                    throw HarnessInternalError.unexpectedResponse
                }
            }
        } catch { cleanupIssues.append(.waitFailed) }
        do {
            guard case .completed = try await system.perform(
                .closeParentChannels(
                    terminalDescriptor: spawned.terminalDescriptor,
                    receiptDescriptor: spawned.receiptDescriptor,
                    bootstrapDescriptor: spawned.bootstrapDescriptor,
                    absoluteDeadlineNanoseconds: deadline
                )
            ) else { throw HarnessInternalError.unexpectedResponse }
        } catch { cleanupIssues.append(.closeFailed) }
        do {
            guard case let .residue(value) = try await system.perform(
                .observeResidue(
                    processGroupID: spawned.processID,
                    sessionID: spawned.processID,
                    absoluteDeadlineNanoseconds: deadline
                )
            ), value.complete, value.processGroupMembers.isEmpty,
                value.sessionMembers.isEmpty
            else { throw HarnessInternalError.unexpectedResponse }
        } catch { cleanupIssues.append(.residueObservationFailed) }
        return .failed(.init(primary: primary, cleanupIssues: cleanupIssues))
    }

    private func completeFinalization(
        primary initialPrimary: InvestigationMachineCampaignHarnessFailure?,
        cleanupIssues initialCleanupIssues:
            [InvestigationMachineCampaignCleanupIssue],
        spawned: InvestigationMachineCampaignSpawnedProcess, deadline: UInt64,
        outerIdentity: InvestigationMachineCampaignOuterIdentity?,
        receipt: InvestigationMachineCoordinatorRawReceiptV1?,
        diagnosticBytes: Data, receiptEOF: Bool, terminalEOF: Bool,
        exactWait: InvestigationMachineCampaignExactWait?
    ) async -> InvestigationMachineCampaignHarnessOutcome {
        var primary = initialPrimary
        var cleanupIssues = initialCleanupIssues
        do {
            guard case .completed = try await system.perform(
                .closeParentChannels(
                    terminalDescriptor: spawned.terminalDescriptor,
                    receiptDescriptor: spawned.receiptDescriptor,
                    bootstrapDescriptor: spawned.bootstrapDescriptor,
                    absoluteDeadlineNanoseconds: deadline
                )
            ) else { throw HarnessInternalError.unexpectedResponse }
        } catch {
            cleanupIssues.append(.closeFailed)
            if primary == nil { primary = .transportUncertain }
        }

        var residue: InvestigationMachineCampaignResidueObservation?
        do {
            guard case let .residue(value) = try await system.perform(
                .observeResidue(
                    processGroupID: spawned.processID,
                    sessionID: spawned.processID,
                    absoluteDeadlineNanoseconds: deadline
                )
            ) else { throw HarnessInternalError.unexpectedResponse }
            residue = value
            if !value.complete || !value.processGroupMembers.isEmpty
                || !value.sessionMembers.isEmpty
            {
                if primary == nil { primary = .residueUncertain }
            }
        } catch {
            cleanupIssues.append(.residueObservationFailed)
            if primary == nil { primary = .residueUncertain }
        }

        if let primary {
            return .failed(.init(
                primary: primary, cleanupIssues: cleanupIssues
            ))
        }
        guard cleanupIssues.isEmpty, let receipt, let outerIdentity,
              let exactWait, let residue, receiptEOF, terminalEOF
        else { return Self.failure(.unexpectedResponse) }
        return .completed(.init(
            receipt: receipt, diagnosticBytes: diagnosticBytes,
            outerIdentity: outerIdentity, receiptReachedEOF: receiptEOF,
            terminalReachedEOF: terminalEOF, exactWait: exactWait,
            residue: residue
        ))
    }

    private static func valid(
        _ spawned: InvestigationMachineCampaignSpawnedProcess
    ) -> Bool {
        spawned.processID > 1 && spawned.terminalDescriptor >= 3
            && spawned.receiptDescriptor >= 3
            && spawned.bootstrapDescriptor >= 3
            && spawned.terminalDescriptor != spawned.receiptDescriptor
            && spawned.terminalDescriptor != spawned.bootstrapDescriptor
            && spawned.receiptDescriptor != spawned.bootstrapDescriptor
    }

    private static func valid(
        _ identity: InvestigationMachineCampaignOuterIdentity,
        spawned: InvestigationMachineCampaignSpawnedProcess,
        harnessPID: pid_t, harnessUID: uid_t
    ) -> Bool {
        validIdentityShape(
            identity, processID: spawned.processID, harnessPID: harnessPID,
            harnessUID: harnessUID
        )
    }

    private static func validIdentityShape(
        _ identity: InvestigationMachineCampaignOuterIdentity,
        processID: pid_t, harnessPID: pid_t, harnessUID: uid_t
    ) -> Bool {
        identity.processID == processID
            && identity.processIDVersion > 0
            && identity.parentProcessID == harnessPID
            && identity.processGroupID == processID
            && identity.sessionID == processID
            && identity.foregroundProcessGroupID == processID
            && identity.effectiveUserID == harnessUID
            && identity.startTimeSeconds > 0
            && identity.startTimeMicroseconds < 1_000_000
    }

    private static func matches(
        _ receipt: InvestigationMachineCoordinatorRawReceiptV1,
        expected: InvestigationMachineCampaignExpectedBinding
    ) -> Bool {
        receipt.outerAttemptUUID == expected.attemptUUID
            && receipt.buildProvenanceSHA256
                == expected.buildProvenanceSHA256
            && receipt.signedBindingSHA256
                == expected.signedRuntimeBindingSHA256
            && receipt.wholeProjectedInputSHA256
                == expected.wholeProjectedInputSHA256
    }

    private static func orderedOpenChannels(
        preferred: InvestigationMachineCampaignChannel,
        terminalEOF: Bool, receiptEOF: Bool
    ) -> [InvestigationMachineCampaignChannel] {
        let other: InvestigationMachineCampaignChannel = preferred == .terminal
            ? .receipt : .terminal
        return [preferred, other].filter { channel in
            channel == .terminal ? !terminalEOF : !receiptEOF
        }
    }

    private static func failure(
        _ primary: InvestigationMachineCampaignHarnessFailure
    ) -> InvestigationMachineCampaignHarnessOutcome {
        .failed(.init(primary: primary, cleanupIssues: []))
    }
}

private enum HarnessInternalError: Error {
    case bootstrap
    case unexpectedResponse
}
#endif
