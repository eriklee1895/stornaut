import CInvestigationIdentitySupport
import CInvestigationMachineCampaignSupport
import Darwin
import Dispatch
import Foundation
import StornautInvestigationHandoffContract

#if DEBUG
import StornautInvestigationMachineCampaignSupport

package enum InvestigationMachineCampaignLifecycleFinalizer {
    package enum Error: Swift.Error, Equatable {
        case installedStateUncertain
    }

    package struct Capture: Sendable {
        package let status: Int32
        package let output: Data

        package init(status: Int32, output: Data) {
            self.status = status
            self.output = output
        }
    }

    package static func run<Receipt>(
        uninstall: () throws -> Capture,
        decode: (Data) throws -> Receipt,
        validate: (Receipt) throws -> Void,
        reportUncertainty: () -> Void
    ) throws -> Receipt {
        do {
            let capture = try uninstall()
            guard capture.status == 0 else { throw Error.installedStateUncertain }
            let receipt = try decode(capture.output)
            try validate(receipt)
            return receipt
        } catch {
            reportUncertainty()
            throw Error.installedStateUncertain
        }
    }
}

package enum InvestigationMachineCampaignExecutable {
    private static let coordinatorName="StornautInvestigationMachineCampaignCoordinator"
    private static let installedCoordinator="/Library/Application Support/Stornaut/Stornaut-R5-Diagnostic.app/Contents/MacOS/StornautInvestigationMachineGateCoordinator"
    private static let deadlineWindowNanoseconds: UInt64 = 5_000_000_000
    private static let productionDeadlineNanoseconds: UInt64 = 1_200_000_000_000
    private static let lifecycleScriptSHA256 = "307ebc0b29078e53cc2d0c567a25cf359c6c852c9e8533b24bbb0d7e20553940"
    private static let completedExitStatus: Int32 = 0
    private static let failedExitStatus: Int32 = 70

    package static func run() async -> Int32 {
        let system = CampaignDarwinSystem()
        if system.isBootstrapInvocation { return system.runBootstrap() }
        guard CommandLine.argc == 1 else {
            return failedExitStatus
        }
        if !system.usesFixtureSibling {
            do { try await system.installProduction() }
            catch { return failedExitStatus }
        }
        let outcome = await InvestigationMachineCampaignHarness(
            system: system).run(expected: system.usesFixtureSibling
                ? legacyFixtureBinding() : nil)
        if !system.usesFixtureSibling {
            do { return try await system.finishProduction(outcome)
                    ? completedExitStatus : failedExitStatus }
            catch { return failedExitStatus }
        }
        switch outcome {
        case .completed(let result):
            writeReport(
                completed: true, identity: result.outerIdentity,
                diagnostic: result.diagnosticBytes, residue: result.residue,
                failure: nil, cleanup: [])
            return completedExitStatus
        case .failed(let failure):
            let projection = await system.reportProjection()
            writeReport(
                completed: false, identity: projection.identity,
                diagnostic: Data(), residue: projection.residue,
                failure: String(describing: failure.primary),
                cleanup: failure.cleanupIssues.map(String.init(describing:)))
            return failedExitStatus
        }
    }

    private static func legacyFixtureBinding()
        -> InvestigationMachineCampaignExpectedBinding
    {
        try! .init(
            attemptUUID: UUID(uuid: (0x41, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 1)),
            buildProvenanceSHA256: String(repeating: "a", count: 64),
            signedRuntimeBindingSHA256: .hashing(Data(repeating: 0x42, count: 32)),
            wholeProjectedInputSHA256: .hashing(Data(repeating: 0x43, count: 32)))
    }

    private static func writeReport(
        completed: Bool, identity: InvestigationMachineCampaignOuterIdentity?,
        diagnostic: Data,
        residue: InvestigationMachineCampaignResidueObservation?,
        failure: String?, cleanup: [String]
    ) {
        let object: [String: Any] = [
            "completed": completed, "processID": identity?.processID ?? 0,
            "processGroupID": identity?.processGroupID ?? 0,
            "sessionID": identity?.sessionID ?? 0,
            "foregroundProcessGroupID":
                identity?.foregroundProcessGroupID ?? 0,
            "diagnostic": String(decoding: diagnostic, as: UTF8.self),
            "residueComplete": residue?.complete ?? false,
            "processGroupResidueCount":
                residue?.processGroupMembers.count ?? -1,
            "sessionResidueCount": residue?.sessionMembers.count ?? -1,
            "failure": failure ?? "", "cleanup": cleanup,
        ]
        guard let data = try? JSONSerialization.data(
            withJSONObject: object, options: [.sortedKeys])
        else { return }
        var offset = 0
        while offset < data.count {
            let count = data.withUnsafeBytes { bytes in
                Darwin.write(
                    STDOUT_FILENO, bytes.baseAddress! + offset,
                    data.count - offset)
            }
            if count > 0 { offset += count; continue }
            if count < 0, errno == EINTR { continue }
            return
        }
    }

    private actor CampaignDarwinSystem:
        InvestigationMachineCampaignHarnessSystem
    {
        private enum Failure: Error { case invalid, deadline, installedStateUncertain, posix(Int32) }
        private struct CommandCapture { let status: Int32; let stdout, stderr: Data }
        private struct TerminalEvidence { let bundle:Data;let epochs:[[Data]];let diagnostic:Data;let rawGateReceipt:Data;let finalReceipt:InvestigationMachineCoordinatorRawReceiptV1 };private var spawned:InvestigationMachineCampaignSpawnedProcess?;private var deadline:UInt64?;private var channelsClosed=false,bootstrapVerified=false,activationPrepared=false,preparedPublished=false,armedConsumed=false,promptObserved=false,humanActionObserved=false,attestationPublished=false
        private var preparedFrameSHA256:Data?;private var bufferedReceipt=Data();private var evidenceWriter:InvestigationMachineRawEvidenceWriter?;private var evidenceParentDescriptor:Int32 = -1;private var lastEvidenceTime:Int64=0;private var installReceipt:[String:Any]?;private var lifecyclePayload:(root:String,bytes:Data,hashes:[String],plist:String)?
        private var policyProbe:CommandCapture?;private var campaignUUID:UUID?;private var evidenceParentPath:String?;private var validatedTerminal:TerminalEvidence?;private var activePreArm:InvestigationMachineCampaignPreArmFrame?;private var preArmWire=Data();private var lastIdentity:InvestigationMachineCampaignOuterIdentity?;private var lastResidue:InvestigationMachineCampaignResidueObservation?

        func reportProjection()->(identity:InvestigationMachineCampaignOuterIdentity?,residue:InvestigationMachineCampaignResidueObservation?){(lastIdentity,lastResidue)}

        func installProduction() throws {
            guard !usesFixtureSibling, installReceipt == nil else { throw Failure.invalid }
            let script = try Self.lifecycleScript(); lifecyclePayload=script
            do {
                let capture = try Self.runLifecycle(script, action: "install")
                guard capture.status == 0 else { throw Failure.invalid }
                installReceipt = try Self.receipt(capture.stdout,
                    domain: "lifecycle.local.install.receipt.v1", action: "install")
            } catch {
                do {
                    let rollback = try Self.runLifecycle(script, action: "uninstall")
                    guard rollback.status == 0 else { throw Failure.invalid }
                    let receipt = try Self.receipt(rollback.stdout,
                        domain: "lifecycle.local.uninstall.receipt.v1",
                        action: "uninstall")
                    try Self.validateUninstall(receipt, install: nil)
                } catch {
                    Self.writeFixedError("stornaut ii-c installed-state-uncertain\n")
                    throw Failure.installedStateUncertain
                }
                throw error
            }
        }

        func finishProduction(_ outcome: InvestigationMachineCampaignHarnessOutcome)
            throws -> Bool {
            guard let install=installReceipt,let lifecyclePayload else{throw Failure.invalid}
            let preArm = activePreArm, writer = evidenceWriter
            var evidenceUsable = preparedPublished && preArm != nil && writer != nil
            let observedEpochCount = validatedTerminal?.epochs.count ?? 0
            var admitting = false
            if let preArm, let writer, evidenceUsable {
                do {
                    if armedConsumed {
                        let transportLoss = switch outcome {
                        case .failed(let failure):
                            failure.primary == .transportUncertain
                        case .completed: false
                        }
                        if case let .completed(result) = outcome,
                           observedEpochCount == 8,
                           let terminal = validatedTerminal,
                           result.rawGateReceiptBytes == terminal.rawGateReceipt,
                           result.diagnosticBytes == terminal.diagnostic,
                           result.receipt == terminal.finalReceipt
                        {
                            _ = try writer.appendAttemptEvent(kind: .spawnObserved,
                                payload: try canonical(["schemaVersion": 1,
                                    "kind": "spawnObserved",
                                    "attemptUUID": preArm.outerAttemptUUID.uuidString.lowercased(),
                                    "evidenceSetSHA256": preArm.frameSHA256.lowercaseHex,
                                    "processID": Int(result.outerIdentity.processID),
                                    "processGroupID": Int(result.outerIdentity.processGroupID),
                                    "sessionID": Int(result.outerIdentity.sessionID)]),
                                observedAt: try nextEvidenceTime())
                            admitting = true
                        } else {
                            _ = try writer.appendAttemptEvent(kind: .spawnUncertain,
                                payload: try event(.spawnUncertain, preArm: preArm,
                                    reason: "campaign-incomplete"),
                                observedAt: try nextEvidenceTime())
                        }
                        if !transportLoss {
                            _ = try writer.appendAttemptEvent(kind: .terminal,
                                payload: try event(.terminal, preArm: preArm),
                                observedAt: try nextEvidenceTime())
                        }
                    } else {
                        _ = try writer.appendAttemptEvent(kind: .cancelledBeforeArm,
                            payload: try event(.cancelledBeforeArm, preArm: preArm,
                                reason: "activation-incomplete"),
                            observedAt: try nextEvidenceTime())
                    }
                } catch { evidenceUsable = false; admitting = false }
            }
            if let preArm, evidenceUsable {
                do {
                    try publishAttestation(preArm)
                    if let terminal = validatedTerminal {
                        try writePostArm(terminal, preArm: preArm)
                    }
                } catch { evidenceUsable = false; admitting = false }
            }
            let un: [String: Any]
            do {
                un = try InvestigationMachineCampaignLifecycleFinalizer.run(
                    uninstall: {
                        let value = try Self.runLifecycle(
                            lifecyclePayload, action: "uninstall")
                        return .init(status: value.status, output: value.stdout)
                    },
                    decode: { try Self.receipt($0, domain:
                        "lifecycle.local.uninstall.receipt.v1", action: "uninstall") },
                    validate: { try Self.validateUninstall($0, install: install) },
                    reportUncertainty: { Self.writeFixedError(
                        "stornaut ii-c installed-state-uncertain\n") })
            } catch { throw Failure.installedStateUncertain }
            let global = try globalObservation()
            guard let preArm, let writer, evidenceUsable else { return false }
            try writeTeardown(un, preArm: preArm, global: global,
                expectedConsumed: armedConsumed,
                expectedEpochCount: observedEpochCount)
            let seal = try writer.finalize()
            try publishSeal(seal, admitting: admitting, consumed: armedConsumed)
            return admitting
        }

        private func writePostArm(_ terminal: TerminalEvidence,
            preArm: InvestigationMachineCampaignPreArmFrame) throws {
            guard let writer=evidenceWriter else{throw Failure.invalid}
            let stream = preArmWire + Self.framed(terminal.rawGateReceipt)
                + Self.framed(try terminal.finalReceipt.encoded())
            _=try writer.writeArtifact(path:.init(phase:.driverEpochs,
                leafName:"coordinator-receipt.bin"),role:.protocolReceipt,
                encoding:.framedCanonicalBinary,bytes:stream)
            _=try writer.writeArtifact(path:.init(phase:.driverEpochs,
                leafName:"diagnostic-output.bin"),role:.diagnosticOutput,
                encoding:.opaqueBytes,bytes:terminal.diagnostic)
            let projected=try InvestigationProjectedCohortInput.decode(preArm.canonicalProjectedInput)
            for index in 0..<8 { let row=terminal.epochs[index],selection=try projected.selection(at:index)
                let physical=try HandoffBinaryTranscript.decode(row[5],expectedDomain:
                    "stornaut.task39.machine.epoch-physical-evidence.v1",
                    expectedBusinessFieldByteCounts:index==6 ? [1...(32<<10)] : [1...(32<<10),1...(48<<10)],maximumByteCount:64<<10)
                let own=try HandoffBinaryTranscript.decode(physical[0],expectedDomain:
                    "stornaut.task39.machine.physical-ownership.evidence-v1",
                    expectedBusinessFieldByteCounts:[16...16,32...32,32...32,16...16,4...4,4...4,32...32,1...4096,1...4096,1...(64<<10),32...32,32...32,1...16384,8...8,8...8,32...32],maximumByteCount:32<<10)
                let projection=try selection.projection.encoded(),proof=own[12]
                let l2=try json(.epochL2Projection,preArm:preArm,extra:[
                    "ordinal":index+1,"scenario":Self.scenario(index),
                    "epochUUID":selection.epoch.epochUUID.uuidString.lowercased(),
                    "configurationNonce":selection.epoch.configurationNonce.uuidString.lowercased(),
                    "configurationSHA256":selection.epoch.configurationSHA256.lowercaseHex,
                    "signedRuntimeBindingSHA256":selection.epoch.signedRuntimeBindingSHA256.lowercaseHex,
                    "wholeProjectedInputSHA256":preArm.wholeProjectedInputSHA256.lowercaseHex,
                    "projectionBase64":projection.base64EncodedString(),"projectionSHA256":selection.projection.projectionSHA256.lowercaseHex,
                    "installedL2ProofBase64":proof.base64EncodedString(),"installedL2ProofSHA256":Self.digest(proof),
                    "claimEvidenceSHA256":Self.digest(own[9]),"physicalOwnershipSHA256":Self.digest(physical[0])])
                _=try writer.writeArtifact(path:.init(phase:.driverEpochs,leafName:String(format:"epoch-%02d-l2.json",index+1)),role:.epochL2Projection,encoding:.strictJSON,bytes:l2)
                try writeJSON(["ordinal":index+1,"scenario":Self.scenario(index),
                    "epochUUID":selection.epoch.epochUUID.uuidString.lowercased(),"l2ArtifactSHA256":Self.digest(l2),
                    "helperIdentitySHA256":Self.digest(own[8]),"completionBindingSHA256":Self.digest(row[7]),
                    "terminalEvidenceBase64":row[6].base64EncodedString(),"terminalEvidenceSHA256":Self.digest(row[6]),
                    "childCount":0,"descendantCount":0,"openChannelCount":0,"ownedProcessGroupMemberCount":0,
                    "helperExitObserved":true,"artifactsRetired":true],role:.epochResidueProjection,
                    phase:.driverEpochs,leaf:String(format:"epoch-%02d-residue.json",index+1),preArm:preArm)
            }
        }

        func prepareActivation(
            receiptDescriptor: Int32, terminalDescriptor: Int32,
            absoluteDeadlineNanoseconds: UInt64
        ) async throws -> InvestigationMachineCampaignPreArmFrame? {
            try check(absoluteDeadlineNanoseconds, reservingCleanup: true)
            guard !activationPrepared, !armedConsumed,
                  receiptDescriptor == spawned?.receiptDescriptor,
                  terminalDescriptor == spawned?.terminalDescriptor
            else { throw Failure.invalid }
            let frame = try readFrame(
                receiptDescriptor,
                maximum: InvestigationMachineCampaignPreArmFrame.maximumByteCount,
                deadline: try operationDeadline(absoluteDeadlineNanoseconds)
            )
            if frame.count <= InvestigationMachineCoordinatorRawReceiptV1.maximumByteCount + 4 {
                bufferedReceipt = frame
                return nil
            }
            let preArm = try InvestigationMachineCampaignPreArmFrame
                .decode(Data(frame.dropFirst(4)))
            preArmWire=frame
            guard let installReceipt else { throw Failure.invalid }
            try Self.validateInstall(installReceipt, preArm: preArm)
            let probe = try Self.runFixed("/usr/bin/sudo", ["-knv"], maximum: 4_096)
            guard probe.status != 0 else { throw Failure.invalid }
            policyProbe = probe
            activePreArm = preArm
            let ready = Data((
                "STORNAUT-IICC-READY-v1 "
                    + preArm.frameSHA256.lowercaseHex + "\n"
            ).utf8)
            try readExactLine(
                terminalDescriptor, expected: ready,
                deadline: try operationDeadline(absoluteDeadlineNanoseconds)
            )
            activationPrepared = true
            preparedFrameSHA256 = preArm.frameSHA256.rawBytes
            evidenceWriter = try makeEvidenceWriter(preArm)
            try writePreArmEvidence(preArm, install: installReceipt, probe: probe)
            return preArm
        }

        func durablyPublishArmedConsumed(
            _ preArm: InvestigationMachineCampaignPreArmFrame,
            absoluteDeadlineNanoseconds: UInt64
        ) async throws {
            try check(absoluteDeadlineNanoseconds, reservingCleanup: true)
            guard activationPrepared, !armedConsumed,
                  preparedPublished,
                  preArm.frameSHA256.rawBytes == preparedFrameSHA256
            else { throw Failure.invalid }
            guard let evidenceWriter, policyProbe != nil else { throw Failure.invalid }
            _ = try evidenceWriter.appendAttemptEvent(kind: .armedConsumed,
                payload: try event(.armedConsumed, preArm: preArm),
                observedAt: try nextEvidenceTime())
            armedConsumed = true
        }

        func sendArmAfterDurablePublish(
            _ preArm: InvestigationMachineCampaignPreArmFrame,
            terminalDescriptor: Int32, absoluteDeadlineNanoseconds: UInt64
        ) async throws {
            try check(absoluteDeadlineNanoseconds, reservingCleanup: true)
            guard activationPrepared, armedConsumed,
                  preArm.frameSHA256.rawBytes == preparedFrameSHA256,
                  terminalDescriptor == spawned?.terminalDescriptor
            else { throw Failure.invalid }
            try writeAll(
                terminalDescriptor, bytes: Array((
                    "STORNAUT-IICC-ARM-v1 "
                        + preArm.frameSHA256.lowercaseHex + "\n"
                ).utf8)
            )
        }

        func relayCredentialAfterExactPrompt(
            _ preArm: InvestigationMachineCampaignPreArmFrame,
            terminalDescriptor: Int32, absoluteDeadlineNanoseconds: UInt64
        ) async throws {
            _ = preArm
            try check(absoluteDeadlineNanoseconds, reservingCleanup: true)
            guard armedConsumed,
                  preArm.frameSHA256.rawBytes == preparedFrameSHA256,
                  terminalDescriptor == spawned?.terminalDescriptor
            else { throw Failure.invalid }
            let prompt = Array(
                "Stornaut Task 39 ii-c administrator authorization: ".utf8
            )
            try readExactPrompt(
                terminalDescriptor, expected: prompt,
                deadline: try operationDeadline(absoluteDeadlineNanoseconds)
            )
            promptObserved = true
            var attributes = termios()
            guard tcgetattr(terminalDescriptor, &attributes) == 0,
                  attributes.c_lflag & tcflag_t(ECHO | ECHONL) == 0
            else { throw Failure.invalid }
            var duplicate = pollfd(
                fd: terminalDescriptor, events: Int16(POLLIN), revents: 0
            )
            guard poll(&duplicate, 1, 0) == 0 else { throw Failure.invalid }
            try writeAll(STDERR_FILENO, bytes: prompt)
            var credential = [CChar](repeating: 0, count: 1_025)
            defer {
                credential.withUnsafeMutableBytes { raw in
                    _ = memset_s(raw.baseAddress, raw.count, 0, raw.count)
                }
            }
            guard readpassphrase(
                "", &credential, credential.count, RPP_REQUIRE_TTY
            ) != nil, let end = credential.firstIndex(of: 0), end > 0,
                end < credential.count - 1
            else { throw Failure.invalid }
            humanActionObserved = true
            try credential.withUnsafeBytes { raw in
                try writeRaw(
                    terminalDescriptor,
                    bytes: UnsafeRawBufferPointer(rebasing: raw.prefix(end))
                )
            }
            try writeAll(terminalDescriptor, bytes: [UInt8(ascii: "\n")])
            try publishAttestation(preArm)
        }

        func validateTerminalEvidence(
            _ bytes: Data, rawGateReceipt: Data,
            finalReceipt: InvestigationMachineCoordinatorRawReceiptV1,
            preArm: InvestigationMachineCampaignPreArmFrame,
            absoluteDeadlineNanoseconds: UInt64
        ) async throws {
            try check(absoluteDeadlineNanoseconds, reservingCleanup: true)
            guard finalReceipt.gateTransportReceiptSHA256
                    == .hashing(rawGateReceipt)
            else { throw Failure.invalid }
            let validated = try Self.validateTerminal(bytes,
                rawGateReceipt: rawGateReceipt, preArm: preArm)
            validatedTerminal = .init(bundle: validated.bundle,
                epochs: validated.epochs, diagnostic: bytes,
                rawGateReceipt: rawGateReceipt, finalReceipt: finalReceipt)
        }

        private static func validateTerminal(_ terminal: Data,
            rawGateReceipt: Data, preArm: InvestigationMachineCampaignPreArmFrame)
            throws -> (bundle: Data, epochs: [[Data]]) {
            let prefix = Data("STORNAUT_TASK39_IIC_EPOCH_BUNDLE_V1 ".utf8)
            let suffix = terminal.suffix(2) == Data("\r\n".utf8) ? 2 : 1
            let encoded = terminal.dropFirst(prefix.count).dropLast(suffix)
            guard terminal.starts(with: prefix), terminal.suffix(1) == Data("\n".utf8),
                  !terminal.dropLast(suffix).contains(UInt8(ascii: "\n")),
                  let bundle = Data(base64Encoded: encoded),
                  Data(bundle.base64EncodedString().utf8) == encoded else { throw Failure.invalid }
            let fields = try HandoffBinaryTranscript.decode(bundle, expectedDomain:
                "stornaut.task39.machine.driver-evidence-bundle.v1",
                expectedBusinessFieldByteCounts: [16...16,32...32,32...32,4...4]
                    + Array(repeating: 1...(64<<10), count: 8), maximumByteCount: 512<<10)
            guard uuid(fields[0]) == preArm.outerAttemptUUID,
                  fields[1] == preArm.wholeCapsuleSHA256.rawBytes,
                  fields[2] == preArm.wholeProjectedInputSHA256.rawBytes,
                  uint32(fields[3]) == 8
            else { throw Failure.invalid }
            let projected = try InvestigationProjectedCohortInput.decode(
                preArm.canonicalProjectedInput)
            var decodedEpochs: [[Data]] = []
            for index in 0..<8 {
                let epoch = try HandoffBinaryTranscript.decode(fields[index+4], expectedDomain:
                    "stornaut.task39.machine.epoch-evidence.v1",
                    expectedBusinessFieldByteCounts: [4...4,4...4,16...16,16...16,1...(128<<10),1...(64<<10),1...2048,32...32], maximumByteCount: 64<<10)
                let selection = try projected.selection(at: index)
                guard uint32(epoch[0]) == index,
                      uint32(epoch[1]) == Int(selection.epoch.scenario.rawValue),
                      uuid(epoch[2]) == selection.epoch.epochUUID,
                      uuid(epoch[3]) == selection.epoch.configurationNonce else { throw Failure.invalid }
                decodedEpochs.append(epoch)
            }
            let bundleSHA = InvestigationHandoffSHA256.hashing(bundle)
            let zero = Data(repeating: 0, count: 32)
            let completionFields = [fields[0],fields[1],fields[2],fields[3],bundleSHA.rawBytes]
            let unsigned = try HandoffBinaryTranscript.encode(domain:
                "stornaut.task39.machine.driver-completion-v2",
                businessFields: completionFields + [zero], maximumByteCount: 512)
            let completion = try HandoffBinaryTranscript.encode(domain:
                "stornaut.task39.machine.driver-completion-v2", businessFields:
                completionFields + [InvestigationHandoffSHA256.hashing(unsigned).rawBytes], maximumByteCount: 512)
            guard rawGateReceipt.count == 422,
                  Data(rawGateReceipt.prefix(4)) == Data([0x53,0x54,0x4e,0x47]),
                  Data(rawGateReceipt[4..<8]) == Data([0,1,2,2]),
                  uint32(Data(rawGateReceipt[8..<12])) == 410,
                  uint32(Data(rawGateReceipt[349..<353])) == completion.count,
                  Data(rawGateReceipt[353..<385]) == InvestigationHandoffSHA256.hashing(completion).rawBytes
            else { throw Failure.invalid }
            return (bundle, decodedEpochs)
        }

        private static func uint32(_ bytes: Data) -> Int {
            bytes.reduce(0) { ($0 << 8) | Int($1) }
        }
        private static func uuid(_ bytes: Data) -> UUID? {
            guard bytes.count == 16 else { return nil }; let b = Array(bytes)
            return UUID(uuid: (b[0],b[1],b[2],b[3],b[4],b[5],b[6],b[7],
                b[8],b[9],b[10],b[11],b[12],b[13],b[14],b[15]))
        }

        private func makeEvidenceWriter(_ preArm: InvestigationMachineCampaignPreArmFrame)
            throws -> InvestigationMachineRawEvidenceWriter
        {
            let campaignUUID = UUID()
            let path = FileManager.default.temporaryDirectory.appending(
                path: "stornaut-iic-evidence-" + campaignUUID.uuidString.lowercased()).path
            guard mkdir(path, 0o700) == 0 else { throw Failure.posix(errno) }
            let parent = open(path, O_RDONLY | O_DIRECTORY | O_CLOEXEC
                | O_NOFOLLOW_ANY | O_UNIQUE | O_NONBLOCK)
            guard parent >= 3 else { throw Failure.posix(errno) }
            evidenceParentDescriptor = parent
            let system = DarwinInvestigationMachineRawEvidenceSystem()
            let writer = try InvestigationMachineRawEvidenceWriter(
                system: system, parentDescriptor: parent,
                expectedParentIdentity: try system.metadata(descriptor: parent).identity,
                campaignUUID: campaignUUID, attemptUUID: preArm.outerAttemptUUID,
                mode: .privileged, sourceBinding: .init(
                    repositoryHEAD: preArm.repositoryHEAD,
                    repositoryTree: preArm.repositoryTree,
                    canonicalSourceManifestSHA256: preArm.canonicalSourceManifestSHA256,
                    buildProvenanceSHA256: preArm.buildProvenanceSHA256,
                    signedRuntimeBindingSHA256: preArm.signedRuntimeBindingSHA256))
            self.campaignUUID=campaignUUID;self.evidenceParentPath=path
            let source = try InvestigationMachineEvidenceJSON.canonicalData([
                "schemaVersion": 1, "role": "sourceBuildIdentity",
                "campaignUUID": campaignUUID.uuidString.lowercased(),
                "attemptUUID": preArm.outerAttemptUUID.uuidString.lowercased(),
                "repositoryHEAD": preArm.repositoryHEAD,
                "repositoryTree": preArm.repositoryTree,
                "canonicalSourceManifestSHA256": preArm.canonicalSourceManifestSHA256.lowercaseHex,
                "buildProvenanceSHA256": preArm.buildProvenanceSHA256.lowercaseHex,
                "signedRuntimeBindingSHA256": preArm.signedRuntimeBindingSHA256.lowercaseHex,
                "preArmFrameSHA256": preArm.frameSHA256.lowercaseHex,
            ])
            _ = try writer.writeArtifact(path: .init(phase: .preflight,
                leafName: "source-build.json"), role: .sourceBuildIdentity,
                encoding: .strictJSON, bytes: source)
            return writer
        }

        private func writePreArmEvidence(_ preArm: InvestigationMachineCampaignPreArmFrame,
            install: [String: Any], probe: CommandCapture) throws {
            guard let writer = evidenceWriter, let campaignUUID else { throw Failure.invalid }
            let executableKeys = ["appExecutableSHA256","helperExecutableSHA256",
                "machineDriverExecutableSHA256","gateExecutableSHA256",
                "coordinatorExecutableSHA256"]
            var installed: [String: Any] = [
                "buildProvenanceSHA256": preArm.buildProvenanceSHA256.lowercaseHex,
                "signedRuntimeBindingSHA256": preArm.signedRuntimeBindingSHA256.lowercaseHex,
                "transactionReceiptSHA256": digest(try canonical(install)),
                "builtIdentitySHA256": install["builtIdentitySHA256"]!,
                "stagingIdentitySHA256": install["stagingIdentitySHA256"]!,
                "installedIdentitySHA256": install["installedIdentitySHA256"]!,
                "plistSHA256": install["plistSHA256"]!, "serviceLoaded": true,
            ]
            for key in executableKeys { installed[key] = install[key] }
            try writeJSON(installed, role: .builtStagingInstalledIdentity,
                phase: .install, leaf: "installed.json", preArm: preArm)
            try writeJSON(["command":"/usr/bin/sudo -knv",
                "exitStatus":Int(probe.status), "stdoutByteCount":probe.stdout.count,
                "stdoutSHA256":digest(probe.stdout), "stderrByteCount":probe.stderr.count,
                "stderrSHA256":digest(probe.stderr)], role:.policyProbe,
                phase:.authorization, leaf:"policy-probe.json", preArm:preArm)
            try writeJSON(["authInvocationCount":0,"modelInvocationCount":0,
                "networkInvocationCount":0,"credentialTranscriptByteCount":0],
                role:.noAuthModelNetworkCounters, phase:.authorization,
                leaf:"capability-counts.json", preArm:preArm)
            _ = try writer.appendAttemptEvent(kind: .prepared,
                payload: try event(.prepared, preArm: preArm),
                observedAt: try nextEvidenceTime())
            preparedPublished = true
            _ = campaignUUID; _ = writer
        }

        private func publishAttestation(
            _ preArm: InvestigationMachineCampaignPreArmFrame
        ) throws {
            guard !attestationPublished else { return }
            try writeJSON([
                "prompt": "Stornaut Task 39 ii-c administrator authorization: ",
                "machinePromptObserved": promptObserved,
                "attestationKind": humanActionObserved
                    ? "trustedOperatorInteractiveAction"
                    : "operatorCancellationBeforeCredential",
                "humanActionObserved": humanActionObserved,
                "credentialRetainedByteCount": 0,
            ], role: .humanPromptAttestation, phase: .authorization,
                leaf: "human-attestation.json", preArm: preArm)
            attestationPublished = true
        }

        private func writeJSON(_ extra: [String: Any], role: InvestigationMachineEvidenceRole,
            phase: InvestigationMachineEvidencePhase, leaf: String,
            preArm: InvestigationMachineCampaignPreArmFrame) throws {
            guard let writer = evidenceWriter, let campaignUUID else { throw Failure.invalid }
            var object = extra; object["schemaVersion"] = 1
            object["role"] = roleName(role)
            object["campaignUUID"] = campaignUUID.uuidString.lowercased()
            object["attemptUUID"] = preArm.outerAttemptUUID.uuidString.lowercased()
            _ = try writer.writeArtifact(path:.init(phase:phase,leafName:leaf),
                role:role,encoding:.strictJSON,bytes:try canonical(object))
        }

        private func json(_ role: InvestigationMachineEvidenceRole,
            preArm: InvestigationMachineCampaignPreArmFrame,
            extra: [String: Any]) throws -> Data {
            guard let campaignUUID else { throw Failure.invalid }
            var value = extra; value["schemaVersion"] = 1; value["role"] = roleName(role)
            value["campaignUUID"] = campaignUUID.uuidString.lowercased()
            value["attemptUUID"] = preArm.outerAttemptUUID.uuidString.lowercased()
            return try canonical(value)
        }
        private func event(_ kind: InvestigationMachineAttemptEventKind,
            preArm: InvestigationMachineCampaignPreArmFrame,
            reason: String? = nil) throws -> Data {
            var value: [String: Any] = ["schemaVersion":1,"kind":eventName(kind),
                "attemptUUID":preArm.outerAttemptUUID.uuidString.lowercased(),
                "evidenceSetSHA256":preArm.frameSHA256.lowercaseHex]
            if kind == .cancelledBeforeArm || kind == .spawnUncertain {
                guard let reason else { throw Failure.invalid }
                value["reason"] = reason
            }
            return try canonical(value)
        }

        private static func roleName(_ role: InvestigationMachineEvidenceRole) -> String {
            switch role { case .sourceBuildIdentity:"sourceBuildIdentity";
            case .builtStagingInstalledIdentity:"builtStagingInstalledIdentity";
            case .policyProbe:"policyProbe"; case .humanPromptAttestation:"humanPromptAttestation";
            case .noAuthModelNetworkCounters:"noAuthModelNetworkCounters";
            case .protocolReceipt:"protocolReceipt"; case .diagnosticOutput:"diagnosticOutput";
            case .epochL2Projection:"epochL2Projection"; case .epochResidueProjection:"epochResidueProjection";
            case .uninstallEvidence:"uninstallEvidence"; case .globalPostTeardown:"globalPostTeardown";
            case .verifierInput:"verifierInput"; case .attemptEvent:"attemptEvent" }
        }
        private static func eventName(_ kind: InvestigationMachineAttemptEventKind) -> String {
            switch kind { case .prepared:"prepared"; case .cancelledBeforeArm:"cancelledBeforeArm";
            case .armedConsumed:"armedConsumed"; case .spawnObserved:"spawnObserved";
            case .spawnUncertain:"spawnUncertain"; case .terminal:"terminal" }
        }
        private func roleName(_ role: InvestigationMachineEvidenceRole) -> String { Self.roleName(role) }
        private func eventName(_ kind: InvestigationMachineAttemptEventKind) -> String { Self.eventName(kind) }
        private static func canonical(_ object: Any) throws -> Data {
            try JSONSerialization.data(withJSONObject: object,
                options:[.sortedKeys,.withoutEscapingSlashes])
        }
        private func canonical(_ object: Any) throws -> Data { try Self.canonical(object) }
        private static func digest(_ data: Data) -> String {
            InvestigationHandoffSHA256.hashing(data).lowercaseHex
        }
        private static func framed(_ data:Data)->Data{
            let n=UInt32(data.count);return Data([UInt8(n>>24),UInt8(truncatingIfNeeded:n>>16),
                UInt8(truncatingIfNeeded:n>>8),UInt8(truncatingIfNeeded:n)])+data
        }
        private func digest(_ data: Data) -> String { Self.digest(data) }

        private func nextEvidenceTime() throws -> InvestigationHandoffUTCMicroseconds {
            let now = Int64(Date().timeIntervalSince1970 * 1_000_000)
            lastEvidenceTime = max(now, lastEvidenceTime + 1)
            return try .init(rawValue: lastEvidenceTime)
        }

        private static func lifecycleScript()throws->(root:String,bytes:Data,hashes:[String],plist:String){let root=URL(filePath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent(),script=root.appending(path:"scripts/stornaut-r5-local-lifecycle").path;var metadata=stat()
            guard script.first == "/", lstat(script,&metadata) == 0,
                  metadata.st_mode & S_IFMT == S_IFREG, metadata.st_nlink == 1,
                  metadata.st_uid == getuid(), metadata.st_mode & 0o022 == 0,
                  access(script,X_OK) == 0,
                  let bytes=stableFileBytes(script,maximum:64<<10),
                  InvestigationHandoffSHA256.hashing(bytes).lowercaseHex
                    == lifecycleScriptSHA256 else { throw Failure.invalid }
            let executable=root.appending(path:".derivedData/xcodebuildmcp/Build/Products/Debug/StornautInvestigationDiagnostic.app/Contents/MacOS"),names=["StornautInvestigationDiagnostic","StornautLifecycleHelper","StornautInvestigationMachineDriver","StornautInvestigationMachineGate","StornautInvestigationMachineGateCoordinator"],paths=names.map{executable.appending(path:$0).path}+[root.appending(path:"StornautLifecycleHelper/com.eriklee.stornaut.lifecycle.plist").path]
            let held=try paths.map{path->Data in guard let value=stableFileBytes(path,maximum:64<<20)else{throw Failure.invalid};return value};return(root.path,bytes,held.map{InvestigationHandoffSHA256.hashing($0).lowercaseHex},held.last!.base64EncodedString())
        }
        private static func runLifecycle(_ script:(root:String,bytes:Data,hashes:[String],plist:String),action:String)throws->CommandCapture{try runFixed("/usr/bin/sudo",
            ["-k","--","/bin/zsh","-f","-s","--","--held-source",script.root,action]+script.hashes+[script.plist],standardInput:script.bytes,maximum:16_384)}

        private static func receipt(_ output: Data, domain: String,
            action: String) throws -> [String: Any] {
            let lines = output.split(separator: 10,omittingEmptySubsequences:true)
            guard let receiptLine = lines.first(where:{ $0.first == UInt8(ascii:"{") }),
                  lines.filter({$0.first == UInt8(ascii:"{")}).count == 1,
                  let value = try JSONSerialization.jsonObject(with: receiptLine) as? [String:Any],
                  try canonical(value) == Data(receiptLine),
                  value["domain"] as? String == domain,
                  value["action"] as? String == action else { throw Failure.invalid }
            return value
        }

        private static func validateInstall(_ value:[String:Any],
            preArm:InvestigationMachineCampaignPreArmFrame) throws {
            let keys:Set<String>=["action","appExecutableSHA256","builtIdentitySHA256",
                "builtStagingInstalledEqual","coordinatorExecutableSHA256","domain",
                "gateExecutableSHA256","helperExecutableSHA256","installedIdentitySHA256",
                "machineDriverExecutableSHA256","plistSHA256","schemaVersion",
                "serviceLoaded","stagingIdentitySHA256"]
            let projected=try InvestigationProjectedCohortInput.decode(preArm.canonicalProjectedInput)
            guard Set(value.keys)==keys, value["schemaVersion"] as? Int==1,
                  value["builtStagingInstalledEqual"] as? Bool==true,
                  value["serviceLoaded"] as? Bool==true,
                  value["builtIdentitySHA256"] as? String==value["stagingIdentitySHA256"] as? String,
                  value["builtIdentitySHA256"] as? String==value["installedIdentitySHA256"] as? String,
                  projected.projections.allSatisfy({ p in
                    value["appExecutableSHA256"] as? String==p.appExecutableSHA256.lowercaseHex
                    && value["helperExecutableSHA256"] as? String==p.helperExecutableSHA256.lowercaseHex
                    && value["machineDriverExecutableSHA256"] as? String==p.machineDriverExecutableSHA256.lowercaseHex
                  }), ["gateExecutableSHA256","coordinatorExecutableSHA256","plistSHA256",
                    "installedIdentitySHA256"].allSatisfy({ validHex(value[$0]) })
            else { throw Failure.invalid }
        }
        private static func validHex(_ value:Any?) -> Bool {
            guard let value=value as? String, value.count==64 else{return false}
            return value.utf8.allSatisfy{(48...57).contains($0)||(97...102).contains($0)}
        }

        private static func runFixed(_ executable:String,_ arguments:[String],
            standardInput:Data?=nil,maximum:Int)throws->CommandCapture{
            var out=[Int32](repeating:0,count:2),err=out,input=[Int32](repeating:-1,count:2)
            guard pipe(&out)==0,pipe(&err)==0,standardInput.map({_ in pipe(&input)==0}) ?? true else{throw Failure.posix(errno)}
            defer{for fd in out+err+input where fd>=0{_ = close(fd)}}
            var actions:posix_spawn_file_actions_t?
            guard posix_spawn_file_actions_init(&actions)==0 else{throw Failure.invalid}
            defer{posix_spawn_file_actions_destroy(&actions)}
            guard posix_spawn_file_actions_adddup2(&actions,out[1],STDOUT_FILENO)==0,
                  posix_spawn_file_actions_adddup2(&actions,err[1],STDERR_FILENO)==0,
                  (standardInput != nil ? posix_spawn_file_actions_adddup2(&actions,input[0],STDIN_FILENO)
                    : posix_spawn_file_actions_addopen(&actions,STDIN_FILENO,"/dev/null",O_RDONLY,0))==0,
                  posix_spawn_file_actions_addclose(&actions,out[0])==0,
                  posix_spawn_file_actions_addclose(&actions,err[0])==0,
                  standardInput == nil || posix_spawn_file_actions_addclose(&actions,input[1])==0 else{throw Failure.invalid}
            var argv=([executable]+arguments).map{strdup($0)}+[nil]
            defer{for case let pointer? in argv{free(pointer)}}
            var env:[UnsafeMutablePointer<CChar>?]=[nil],pid:pid_t=0
            let result=argv.withUnsafeMutableBufferPointer{a in env.withUnsafeMutableBufferPointer{e in
                posix_spawn(&pid,executable,&actions,nil,a.baseAddress!,e.baseAddress!)}}
            guard result==0 else{throw Failure.posix(result)}
            var childOutstanding=true
            defer{if childOutstanding{_=kill(pid,SIGKILL);var status:Int32=0
                while waitpid(pid,&status,0)<0 && errno==EINTR{}}}
            _=close(out[1]);out[1] = -1;_=close(err[1]);err[1] = -1
            if input[0]>=0{_=close(input[0]);input[0] = -1;guard fcntl(input[1],F_SETFL,O_NONBLOCK)==0,fcntl(input[1],F_SETNOSIGPIPE,1)==0 else{throw Failure.posix(errno)}}
            var stdout=Data(),stderr=Data(),overflow=false,open=[out[0],err[0]],inputOffset=0
            while !open.isEmpty || input[1]>=0 {
                var events=open.map{pollfd(fd:$0,events:Int16(POLLIN|POLLHUP),revents:0)}
                if input[1]>=0{events.append(pollfd(fd:input[1],events:Int16(POLLOUT),revents:0))}
                let ready=poll(&events,nfds_t(events.count),-1)
                if ready<0,errno==EINTR{continue}
                guard ready>0 else{throw Failure.posix(errno)}
                guard events.allSatisfy({$0.revents & Int16(POLLERR|POLLNVAL)==0}),input[1]<0 || events.last!.revents&Int16(POLLHUP)==0
                else{throw Failure.invalid}
                if input[1]>=0,let event=events.first(where:{$0.fd==input[1]}),event.revents&Int16(POLLOUT) != 0,let standardInput{
                    let count=standardInput.withUnsafeBytes{write(input[1],
                        $0.baseAddress!+inputOffset,min(4096,standardInput.count-inputOffset))}
                    if count<0,errno != EINTR && errno != EAGAIN{throw Failure.posix(errno)}
                    if count>0{inputOffset+=count;if inputOffset==standardInput.count{_=close(input[1]);input[1] = -1}}
                }
                for index in events.indices.reversed() where open.contains(events[index].fd) && events[index].revents & Int16(POLLIN|POLLHUP) != 0 {
                    var bytes=[UInt8](repeating:0,count:4096)
                    let count=read(events[index].fd,&bytes,bytes.count)
                    if count<0,errno==EINTR{continue}
                    if count==0{open.remove(at:index);continue}
                    guard count>0 else{throw Failure.posix(errno)}
                    if events[index].fd==out[0]{if stdout.count+count<=maximum{stdout.append(contentsOf:bytes.prefix(count))}else{overflow=true}}
                    else{if stderr.count+count<=maximum{stderr.append(contentsOf:bytes.prefix(count))}else{overflow=true}}
                }
            }
            var waitStatus:Int32=0
            guard waitpid(pid,&waitStatus,0)==pid,(waitStatus&0x7f)==0,
                  (waitStatus&0x7f) != 0x7f else{throw Failure.invalid}
            childOutstanding=false
            guard !overflow else{throw Failure.invalid}
            return .init(status:(waitStatus>>8)&0xff,stdout:stdout,stderr:stderr)
        }

        private static func validateUninstall(_ value:[String:Any],
            install:[String:Any]?)throws{
            let identities=["installedIdentitySHA256","plistSHA256","appExecutableSHA256",
                "helperExecutableSHA256","machineDriverExecutableSHA256","gateExecutableSHA256",
                "coordinatorExecutableSHA256"]
            let truths=["bootoutCompleted","appAbsent","rootAbsent","plistAbsent",
                "runtimeAbsent","leaseAbsent","serviceAbsent","globalPostTeardown"]
            let keys=Set(["schemaVersion","domain","action"]+identities+truths)
            guard Set(value.keys)==keys,value["schemaVersion"] as? Int==1,
                  identities.allSatisfy({ validHex(value[$0]) }),
                  install.map({ expected in identities.allSatisfy({
                    value[$0] as? String == expected[$0] as? String }) }) ?? true,
                  truths.allSatisfy({value[$0] as? Bool==true}) else{throw Failure.invalid}
        }
        private static func writeFixedError(_ value:String){
            let bytes=Array(value.utf8);bytes.withUnsafeBytes{raw in
                var offset=0;while offset<raw.count{let n=write(STDERR_FILENO,
                    raw.baseAddress!+offset,raw.count-offset);if n>0{offset+=n}
                    else if n<0,errno==EINTR{continue}else{return}}}
        }
        private func writeTeardown(_ uninstall:[String:Any],
            preArm: InvestigationMachineCampaignPreArmFrame, global: [Int],
            expectedConsumed: Bool, expectedEpochCount: Int) throws {
            var un:[String:Any]=["transactionReceiptSHA256":Self.digest(try Self.canonical(uninstall)),
                "bootoutCompleted":true,"installedRootRemoved":true,"installedAppRemoved":true,
                "plistRemoved":true,"runtimeRootRemoved":true,"leaseRootRemoved":true]
            for key in ["installedIdentitySHA256","plistSHA256","appExecutableSHA256",
                "helperExecutableSHA256","machineDriverExecutableSHA256","gateExecutableSHA256",
                "coordinatorExecutableSHA256"]{un[key]=uninstall[key]}
            try writeJSON(un,role:.uninstallEvidence,phase:.uninstall,leaf:"uninstall.json",preArm:preArm)
            try writeJSON(["observationReceiptSHA256":Self.digest(try Self.canonical(uninstall)),
                "appProcessCount":global[0],"helperProcessCount":global[1],
                "driverProcessCount":global[2],"gateProcessCount":global[3],
                "coordinatorProcessCount":global[4],"childCount":global[5],
                "descendantCount":global[6],"openChannelCount":global[7],
                "ownedProcessGroupMemberCount":global[8],
                "serviceAbsent":true,"gateOwnerLockRevalidated":true,"gateAttemptEntryCount":0,
                "gateCapsuleEntryCount":0],role:.globalPostTeardown,phase:.verifier,
                leaf:"global-post-teardown.json",preArm:preArm)
            try writeJSON(["expectedConsumed":expectedConsumed,
                "expectedEpochCount":expectedEpochCount,
                "evidenceSetSHA256":preArm.frameSHA256.lowercaseHex,
                "verifierExecutableSHA256":Self.digest(try Data(contentsOf:URL(filePath:
                    try Self.repositoryRoot()+"/scripts/verify-investigation-runtime-machine-report")))],
                role:.verifierInput,phase:.verifier,leaf:"verification-input.json",preArm:preArm)
        }
        private func publishSeal(_ seal: InvestigationMachineRawEvidenceSeal,
            admitting: Bool, consumed: Bool) throws {
            guard let parent=evidenceParentPath,evidenceParentDescriptor>=3
            else{throw Failure.invalid}
            let object:[String:Any]=["schemaVersion":1,"campaignUUID":seal.campaignUUID.uuidString.lowercased(),
                "attemptUUID":seal.attemptUUID.uuidString.lowercased(),"rootIdentity":["device":String(seal.rootIdentity.device),"inode":String(seal.rootIdentity.inode),"generation":String(seal.rootIdentity.generation),"size":String(seal.rootIdentity.size)],
                "manifestSHA256":seal.manifestSHA256.lowercaseHex,"contentRootSHA256":seal.contentRootSHA256.lowercaseHex,
                "artifactCount":seal.artifactCount,"totalByteCount":String(seal.totalByteCount),
                "attemptSummary":["attemptUUID":seal.attemptSummary.attemptUUID.uuidString.lowercased(),
                    "mode":Int(seal.attemptSummary.mode.rawValue),"outcome":Int(seal.attemptSummary.outcome.rawValue),
                    "consumed":seal.attemptSummary.consumed,"eventCount":Int(seal.attemptSummary.eventCount),
                    "finalEventSHA256":seal.attemptSummary.finalEventSHA256.lowercaseHex]]
            let parentFD=evidenceParentDescriptor
            var parentHeld=stat(),parentNamed=stat()
            guard fstat(parentFD,&parentHeld)==0,lstat(parent,&parentNamed)==0,
                  parentHeld.st_dev==parentNamed.st_dev,
                  parentHeld.st_ino==parentNamed.st_ino,
                  parentHeld.st_gen==parentNamed.st_gen,
                  parentHeld.st_mode&S_IFMT==S_IFDIR,
                  parentHeld.st_mode&0o7777==0o700,parentHeld.st_uid==getuid()
            else{throw Failure.invalid}
            let pending="seal.pending",final="seal.json",data=try Self.canonical(object)
            let fd=openat(parentFD,pending,O_WRONLY|O_CREAT|O_EXCL|O_CLOEXEC|O_NOFOLLOW_ANY|O_UNIQUE,0o600)
            guard fd>=3 else{throw Failure.posix(errno)};defer{_ = close(fd)}
            var offset=0;while offset<data.count{let n=data.withUnsafeBytes{write(fd,$0.baseAddress!+offset,data.count-offset)};guard n>0 else{throw Failure.posix(errno)};offset+=n}
            let renameFlags=UInt32(RENAME_EXCL|RENAME_NOFOLLOW_ANY|RENAME_RESOLVE_BENEATH)
            var pendingMetadata=stat()
            guard fchmod(fd,0o600)==0,fstat(fd,&pendingMetadata)==0,
                  pendingMetadata.st_mode&S_IFMT==S_IFREG,
                  pendingMetadata.st_mode&0o7777==0o600,
                  pendingMetadata.st_uid==getuid(),pendingMetadata.st_nlink==1,
                  fsync(fd)==0,renameatx_np(parentFD,pending,parentFD,final,renameFlags)==0,fsync(parentFD)==0
            else{throw Failure.posix(errno)}
            let reader=openat(parentFD,final,O_RDONLY|O_CLOEXEC|O_NOFOLLOW_ANY|O_UNIQUE)
            guard reader>=3 else{throw Failure.posix(errno)};defer{_=close(reader)}
            var finalNamed=stat(),finalHeld=stat()
            guard fstatat(parentFD,final,&finalNamed,AT_SYMLINK_NOFOLLOW)==0,
                  fstat(reader,&finalHeld)==0,
                  finalNamed.st_dev==pendingMetadata.st_dev,
                  finalNamed.st_ino==pendingMetadata.st_ino,
                  finalNamed.st_gen==pendingMetadata.st_gen,
                  finalHeld.st_dev==pendingMetadata.st_dev,
                  finalHeld.st_ino==pendingMetadata.st_ino,
                  finalHeld.st_gen==pendingMetadata.st_gen,
                  finalHeld.st_size==data.count
            else{throw Failure.invalid}
            var observed=Data(),buffer=[UInt8](repeating:0,count:4096);while true{let n=read(reader,&buffer,buffer.count);if n>0{observed.append(contentsOf:buffer.prefix(n));continue};guard n==0 else{throw Failure.posix(errno)};break};guard observed==data else{throw Failure.invalid}
            let sealURL=URL(filePath:parent).appending(path:final)
            let verifier=try Self.repositoryRoot()+"/scripts/verify-investigation-runtime-machine-report"
            let root=URL(filePath:parent).appending(path:InvestigationMachineRawEvidenceWriter.rootName(campaignUUID:seal.campaignUUID)).path
            let result = try Self.runFixed(
                verifier, [root, sealURL.path], maximum: 8_192)
            if admitting {
                guard result.status == 0 else { throw Failure.invalid }
            } else if consumed {
                guard result.status != 0,
                      String(decoding: result.stderr, as: UTF8.self)
                        .contains("non-admitting")
                else { throw Failure.invalid }
            } else {
                guard result.status == 0 else { throw Failure.invalid }
            }
        }
        private static func repositoryRoot()throws->String{
            URL(filePath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent().path
        }
        private static func scenario(_ index:Int)->String{["success","cancellation","timeout",
            "invalidEnvelope","identityMismatch","transportLoss","lifecycleRecovery",
            "artifactCleanupFailure"][index]}
        private func globalObservation()throws->[Int]{
            let exact=["/Library/Application Support/Stornaut/Stornaut-R5-Diagnostic.app/Contents/MacOS/StornautInvestigationDiagnostic","/Library/Application Support/Stornaut/Stornaut-R5-Diagnostic.app/Contents/MacOS/StornautLifecycleHelper","/Library/Application Support/Stornaut/Stornaut-R5-Diagnostic.app/Contents/MacOS/StornautInvestigationMachineDriver","/Library/Application Support/Stornaut/Stornaut-R5-Diagnostic.app/Contents/MacOS/StornautInvestigationMachineGate",installedCoordinator]
            var counts=[Int](repeating:0,count:9),capacity=4096
            while capacity<=131072{var pids=[pid_t](repeating:0,count:capacity);let n=pids.withUnsafeMutableBytes{proc_listallpids($0.baseAddress,Int32($0.count))};guard n>=0 else{throw Failure.posix(errno)};if n<capacity{for pid in pids.prefix(Int(n)) where pid>1{var path=[CChar](repeating:0,count:Int(MAXPATHLEN));let size=proc_pidpath(pid,&path,UInt32(path.count));if size>0,let value=String(bytes:path.prefix(Int(size)).map(UInt8.init(bitPattern:)),encoding:.utf8),let i=exact.firstIndex(of:value){counts[i]+=1}};break};capacity*=2}
            guard counts.prefix(5).allSatisfy({$0==0}),channelsClosed,
                  let residue=lastResidue,residue.complete,
                  residue.processGroupMembers.isEmpty,residue.sessionMembers.isEmpty
            else{throw Failure.invalid}
            for path in exact{var absent=stat();guard lstat(path,&absent) != 0,
                errno==ENOENT else{throw Failure.invalid}}
            guard let pw=getpwuid(getuid()) else{throw Failure.invalid}
            let base=String(cString:pw.pointee.pw_dir)+"/Library/Caches/com.eriklee.stornaut.task39-machine-gate"
            let names=try FileManager.default.contentsOfDirectory(atPath:base)
            guard names==[".owner-lock-v1"] else{throw Failure.invalid}
            var lock=stat();guard lstat(base+"/.owner-lock-v1",&lock)==0,
                  lock.st_mode&S_IFMT==S_IFREG,lock.st_uid==getuid(),lock.st_nlink==1
            else{throw Failure.invalid}
            return counts}

        nonisolated var isBootstrapInvocation: Bool {
            CommandLine.argc == 1 && getpid() > 1 && getsid(0) == getpid()
                && getpgrp() == getpid()
                && Self.validDescriptor(3, type: S_IFIFO, access: O_WRONLY)
                && Self.validDescriptor(4, type: S_IFCHR, access: O_RDWR)
                && Self.validDescriptor(5, type: S_IFIFO, access: O_WRONLY)
        }

        nonisolated var usesFixtureSibling: Bool {
            guard let executable = try? Self.executablePath() else { return false }
            return Self.fixtureCoordinatorPath(executable) != nil
        }

        nonisolated func runBootstrap() -> Int32 {
            guard let executable = try? Self.executablePath() else { return 70 }
            let fixture=Self.consumeFixtureCapability(executable)
            let coordinator = fixture ?? installedCoordinator
            return coordinator.withCString {
                stornaut_investigation_campaign_bootstrap_fixed($0)
            }
        }

        private nonisolated static func fixtureCoordinatorPath(_ executable:String)->String?{
            let executableURL=URL(filePath:executable).standardizedFileURL,
                directory=executableURL.deletingLastPathComponent(),
                prefix="stornaut-campaign-physical-",directoryName=directory.lastPathComponent
            guard executableURL.lastPathComponent=="StornautInvestigationMachineCampaign",
                  directoryName.hasPrefix(prefix),UUID(uuidString:String(
                    directoryName.dropFirst(prefix.count))) != nil,
                  let canonicalExecutable=fixtureBuildExecutable(executable:executable),
                  let fixtureDigest=stableExecutableDigest(executable),
                  stableExecutableDigest(canonicalExecutable)==fixtureDigest else{return nil}
            var directoryMetadata=stat(),executableMetadata=stat()
            guard lstat(directory.path,&directoryMetadata)==0,
                  directoryMetadata.st_mode&S_IFMT==S_IFDIR,
                  directoryMetadata.st_mode&0o7777==0o700,
                  directoryMetadata.st_uid==getuid(),lstat(executable,&executableMetadata)==0,
                  executableMetadata.st_mode&S_IFMT==S_IFREG,
                  executableMetadata.st_mode&0o022==0,executableMetadata.st_uid==getuid(),
                  executableMetadata.st_nlink==1,access(executable,X_OK)==0 else{return nil}
            let coordinator=directory.appending(path:coordinatorName).path
            var coordinatorMetadata=stat()
            if lstat(coordinator,&coordinatorMetadata)==0 {
                guard stableExecutableDigest(coordinator,privateParent:true) != nil
                else{return nil}
            } else if errno != ENOENT { return nil }
            return realPath(coordinator) ?? coordinator
        }
        private nonisolated static func fixtureBuildExecutable(executable:String)->String?{
            let helper=testingHelperPath
            guard let currentDigest=stableExecutableDigest(executable) else{return nil}
            var ancestor=getppid(),outerObserved=false,helperObserved=false
            for depth in 0..<3 {
                guard ancestor>1,let path=processPath(ancestor) else{return nil}
                if path==helper{helperObserved=true;break}
                if depth==0,stableExecutableDigest(path)==currentDigest{outerObserved=true}
                else{return nil}
                guard let parent=parentProcessID(ancestor) else{return nil}
                ancestor=parent
            }
            guard helperObserved,(getppid()==ancestor)||outerObserved,
                  let repository=try? repositoryRoot() else{return nil}
            return repository+"/.build/arm64-apple-macosx/debug/StornautInvestigationMachineCampaign"
        }
        private nonisolated static func fixtureCapability(_ executable:String)->Data?{
            guard let sibling=fixtureCoordinatorPath(executable),
                  let campaign=stableExecutableDigest(executable) else{return nil}
            let coordinator=stableExecutableDigest(sibling,privateParent:true)
            let value="STORNAUT-IICC-FIXTURE-v1 \(getpid()) "+campaign.lowercaseHex+" "+(coordinator?.lowercaseHex ?? "missing")+"\n"
            return Data(value.utf8)
        }
        private nonisolated static func consumeFixtureCapability(_ executable:String)->String?{
            guard let candidate=fixtureCandidatePath(executable) else{return nil};
            var pollValue=pollfd(fd:4,events:Int16(POLLIN),revents:0)
            guard poll(&pollValue,1,5_000)>0 else{return nil}
            var bytes=[UInt8](),byte:UInt8=0
            while bytes.count<256,read(4,&byte,1)==1{bytes.append(byte);if byte==10{break}}
            guard bytes.last==10,let line=String(data:Data(bytes.dropLast()),encoding:.utf8)
            else{return nil}
            let fields=line.split(separator:" ",omittingEmptySubsequences:false)
            let sibling=candidate
            guard fields.count==4,fields[0]=="STORNAUT-IICC-FIXTURE-v1",
                  fields[1]==Substring(String(getppid())),validHex(String(fields[2]))
            else{return nil}
            guard fields[3]=="missing" || validHex(String(fields[3])),
                  let grandparent=parentProcessID(getppid()),grandparent>1,
                  let helper=processPath(grandparent),
                  realPath(helper)==realPath(testingHelperPath)
            else{return nil}
            return sibling
        }
        private nonisolated static func fixtureCandidatePath(_ executable:String)->String?{
            let url=URL(filePath:executable),directory=url.deletingLastPathComponent(),
                name=directory.lastPathComponent,prefix="stornaut-campaign-physical-"
            guard url.lastPathComponent=="StornautInvestigationMachineCampaign",
                  name.hasPrefix(prefix),UUID(uuidString:String(
                    name.dropFirst(prefix.count))) != nil else{return nil}
            return directory.appending(path:coordinatorName).path
        }
        private nonisolated static let testingHelperPath="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/libexec/swift/pm/swiftpm-testing-helper"
        private nonisolated static func processPath(_ pid:pid_t)->String?{
            var bytes=[CChar](repeating:0,count:Int(MAXPATHLEN))
            let count=proc_pidpath(pid,&bytes,UInt32(bytes.count))
            guard count>1,count<bytes.count else{return nil}
            return String(bytes:bytes.prefix(Int(count)).map(UInt8.init(bitPattern:)),encoding:.utf8)
        }
        private nonisolated static func parentProcessID(_ pid:pid_t)->pid_t?{
            var info=proc_bsdinfo();let count=proc_pidinfo(pid,PROC_PIDTBSDINFO,0,
                &info,Int32(MemoryLayout<proc_bsdinfo>.size))
            return count==MemoryLayout<proc_bsdinfo>.size ? pid_t(info.pbi_ppid):nil
        }
        private nonisolated static func stableFileBytes(_ path:String,
            privateParent:Bool=false,maximum:Int64=32<<20)->Data?{
            let url=URL(filePath:path),leaf=url.lastPathComponent
            guard !leaf.isEmpty,let parent=realPath(
                url.deletingLastPathComponent().path) else{return nil}
            let parentFD=open(parent,O_RDONLY|O_DIRECTORY|O_CLOEXEC|O_NOFOLLOW_ANY)
            guard parentFD>=3 else{return nil};defer{_=close(parentFD)}
            var named=stat();guard fstatat(parentFD,leaf,&named,AT_SYMLINK_NOFOLLOW)==0,
                named.st_mode&S_IFMT==S_IFREG,
                named.st_mode&(privateParent ? 0o002:0o022)==0,
                named.st_uid==getuid(),named.st_nlink==1,named.st_size>0,
                named.st_size<=maximum else{return nil}
            let fd=openat(parentFD,leaf,O_RDONLY|O_CLOEXEC|O_NOFOLLOW_ANY)
            guard fd>=3 else{return nil};defer{_=close(fd)}
            var held=stat();guard fstat(fd,&held)==0,held.st_dev==named.st_dev,
                held.st_ino==named.st_ino,held.st_gen==named.st_gen,
                held.st_size==named.st_size else{return nil}
            var data=Data(),offset:Int64=0,buffer=[UInt8](repeating:0,count:16<<10)
            while offset<held.st_size{let count=pread(fd,&buffer,min(buffer.count,
                Int(held.st_size-offset)),offset);if count<0,errno==EINTR{continue}
                guard count>0 else{return nil};data.append(contentsOf:buffer.prefix(count));
                offset+=Int64(count)}
            var after=stat(),renamed=stat();guard fstat(fd,&after)==0,
                fstatat(parentFD,leaf,&renamed,AT_SYMLINK_NOFOLLOW)==0,
                after.st_dev==held.st_dev,
                after.st_ino==held.st_ino,after.st_gen==held.st_gen,
                after.st_size==held.st_size,renamed.st_dev==held.st_dev,
                renamed.st_ino==held.st_ino,renamed.st_gen==held.st_gen
            else{return nil}
            return data
        }
        private nonisolated static func stableExecutableDigest(_ path:String,
            privateParent:Bool=false)->InvestigationHandoffSHA256?{
            stableFileBytes(path,privateParent:privateParent)
                .map(InvestigationHandoffSHA256.hashing)
        }
        private nonisolated static func realPath(_ path:String)->String?{
            guard let pointer = realpath(path, nil) else { return nil }
            defer { free(pointer) }
            return String(cString: pointer)
        }
        func perform(_ operation: InvestigationMachineCampaignHarnessOperation)
            async throws -> InvestigationMachineCampaignHarnessResponse
        {
            switch operation {
            case .makeAbsoluteDeadline:
                guard deadline == nil else { throw Failure.invalid }
                let value = DispatchTime.now().uptimeNanoseconds
                    .addingReportingOverflow(usesFixtureSibling
                        ? deadlineWindowNanoseconds
                        : productionDeadlineNanoseconds)
                guard !value.overflow else { throw Failure.deadline }
                deadline = value.partialValue
                return .absoluteDeadline(value.partialValue)
            case .observeHarness(let value):
                try check(value, reservingCleanup: true)
                return .harnessIdentity(
                    processID: getpid(), effectiveUserID: geteuid())
            case .spawnFixedSibling(let value):
                try check(value, reservingCleanup: true)
                guard spawned == nil else { throw Failure.invalid }
                var raw = stornaut_investigation_campaign_spawn()
                let executable = try Self.executablePath()
                let fixtureCapability=Self.fixtureCapability(executable)
                let status = executable.withCString {
                    stornaut_investigation_campaign_spawn_fixed($0, &raw)
                }
                guard status == 0, raw.process_id > 1 else {
                    throw Failure.posix(status)
                }
                let result = InvestigationMachineCampaignSpawnedProcess(
                    processID: raw.process_id,
                    terminalDescriptor: raw.terminal_master_descriptor,
                    receiptDescriptor: raw.receipt_read_descriptor,
                    bootstrapDescriptor: raw.bootstrap_read_descriptor,
                    parentTransferCloseError:
                        raw.parent_transfer_close_error == 0
                            ? nil : raw.parent_transfer_close_error)
                spawned = result
                if let capability=fixtureCapability{
                    var attributes=termios()
                    if tcgetattr(raw.terminal_master_descriptor,&attributes)==0{
                        let original=attributes;attributes.c_lflag &= ~tcflag_t(ECHO|ECHONL)
                        if tcsetattr(raw.terminal_master_descriptor,TCSANOW,&attributes)==0{
                            _=try? capability.withUnsafeBytes { bytes in
                                try writeRaw(raw.terminal_master_descriptor,bytes:bytes)
                            }
                            var restore=original;_=tcsetattr(
                                raw.terminal_master_descriptor,TCSANOW,&restore)
                        }
                    }
                }
                return .spawned(result)
            case .readBootstrap(let descriptor, let maximum, let value):
                try check(value, reservingCleanup: true)
                guard descriptor == spawned?.bootstrapDescriptor else {
                    throw Failure.invalid
                }
                let result = try readToEOF(
                    descriptor, maximum: maximum,
                    deadline: try operationDeadline(value))
                bootstrapVerified = result.data == Data([
                    UInt8(STORNAUT_INVESTIGATION_CAMPAIGN_BOOTSTRAP_READY)
                ]) && result.eof
                return .bootstrap(bytes: result.data, reachedEOF: result.eof)
            case .observeOuterIdentity(let processID, let value):
                try check(value, reservingCleanup: true)
                guard bootstrapVerified, processID == spawned?.processID,
                      let spawned else { throw Failure.invalid }
                let identity = try Self.identity(
                    processID, terminal: spawned.terminalDescriptor,
                    initial: lastIdentity)
                lastIdentity = identity
                return .outerIdentity(identity)
            case .pollReadable(let channels, let value):
                try check(value, reservingCleanup: true)
                let operationDeadline = try operationDeadline(value)
                var events = try channels.map {
                    pollfd(fd: try descriptor(for: $0),
                        events: Int16(POLLIN | POLLHUP), revents: 0)
                }
                while true {
                    let count = events.withUnsafeMutableBufferPointer {
                        poll($0.baseAddress, nfds_t($0.count),
                            Self.timeout(operationDeadline))
                    }
                    if count < 0, errno == EINTR { continue }
                    if count == 0 {
                        guard DispatchTime.now().uptimeNanoseconds
                                < operationDeadline
                        else { throw Failure.deadline }
                        continue
                    }
                    guard count > 0, events.allSatisfy({
                        $0.revents & Int16(POLLERR | POLLNVAL) == 0
                    }) else { throw Failure.invalid }
                    return .readable(zip(channels, events).compactMap {
                        $1.revents & Int16(POLLIN | POLLHUP) != 0 ? $0 : nil
                    })
                }
            case .read(let channel, let maximum, let value):
                try check(value, reservingCleanup: true)
                guard (1...16_384).contains(maximum) else {
                    throw Failure.invalid
                }
                let fd = try descriptor(for: channel)
                if channel == .receipt, !bufferedReceipt.isEmpty {
                    let count = min(maximum, bufferedReceipt.count)
                    let result = Data(bufferedReceipt.prefix(count))
                    bufferedReceipt.removeFirst(count)
                    return .read(.bytes(result))
                }
                var bytes = [UInt8](repeating: 0, count: maximum)
                while true {
                    let count = Darwin.read(fd, &bytes, bytes.count)
                    if count > 0 {
                        return .read(.bytes(Data(bytes.prefix(count))))
                    }
                    if count == 0 || channel == .terminal && errno == EIO {
                        return .read(.eof)
                    }
                    if errno == EINTR { continue }
                    throw Failure.posix(errno)
                }
            case .terminateOwnedGroup(
                let processID, let groupID, let value):
                try check(value)
                guard processID == spawned?.processID, groupID == processID
                else { throw Failure.invalid }
                if kill(-groupID, SIGKILL) != 0, errno != ESRCH {
                    throw Failure.posix(errno)
                }
                return .completed
            case .waitExact(let processID, let value):
                try check(value)
                guard processID == spawned?.processID else {
                    throw Failure.invalid
                }
                return .wait(try wait(processID, deadline: value))
            case .closeParentChannels(
                let terminal, let receipt, let bootstrap, let value):
                try check(value)
                guard !channelsClosed, let expected = spawned,
                      terminal == expected.terminalDescriptor,
                      receipt == expected.receiptDescriptor,
                      bootstrap == expected.bootstrapDescriptor
                else { throw Failure.invalid }
                channelsClosed = true
                var failed = false
                for fd in Set([terminal, receipt, bootstrap]) where fd >= 0 {
                    if close(fd) != 0, errno != EBADF { failed = true }
                }
                if failed { throw Failure.posix(errno) }
                return .completed
            case .observeResidue(let groupID, let sessionID, let value):
                try check(value)
                guard groupID == spawned?.processID, sessionID == groupID
                else { throw Failure.invalid }
                let result = try Self.residue(
                    groupID: groupID, sessionID: sessionID)
                lastResidue = result
                spawned = nil
                return .residue(result)
            }
        }

        private func check(
            _ value: UInt64, reservingCleanup: Bool = false
        ) throws {
            let effective = reservingCleanup ? try operationDeadline(value) : value
            guard value == deadline,
                  DispatchTime.now().uptimeNanoseconds < effective
            else { throw Failure.deadline }
        }

        private func operationDeadline(_ value: UInt64) throws -> UInt64 {
            guard value == deadline, value > 1_000_000_000 else {
                throw Failure.deadline
            }
            return value - 1_000_000_000
        }

        private func descriptor(
            for channel: InvestigationMachineCampaignChannel
        ) throws -> Int32 {
            guard !channelsClosed, let spawned else { throw Failure.invalid }
            return channel == .terminal
                ? spawned.terminalDescriptor : spawned.receiptDescriptor
        }

        private func readToEOF(
            _ descriptor: Int32, maximum: Int, deadline: UInt64
        ) throws -> (data: Data, eof: Bool) {
            var result = Data()
            while result.count <= maximum {
                var event = pollfd(fd: descriptor,
                    events: Int16(POLLIN | POLLHUP), revents: 0)
                let ready = poll(&event, 1, Self.timeout(deadline))
                if ready < 0, errno == EINTR { continue }
                if ready == 0 {
                    guard DispatchTime.now().uptimeNanoseconds < deadline
                    else { throw Failure.deadline }
                    continue
                }
                guard ready > 0,
                      event.revents & Int16(POLLERR | POLLNVAL) == 0
                else { throw Failure.invalid }
                var bytes = [UInt8](repeating: 0,
                    count: max(1, maximum + 1 - result.count))
                let count = Darwin.read(descriptor, &bytes, bytes.count)
                if count > 0 {
                    result.append(contentsOf: bytes.prefix(count)); continue
                }
                if count == 0 { return (result, true) }
                if errno == EINTR { continue }
                throw Failure.posix(errno)
            }
            return (result, false)
        }

        private func readFrame(_ descriptor:Int32,maximum:Int,deadline:UInt64)throws->Data{
            var frame = Data()
            while frame.count < 4 {
                frame.append(try readSome(descriptor,maximum:4-frame.count,deadline:deadline))
            }
            let declared=frame.prefix(4).reduce(UInt32(0)){($0<<8)|UInt32($1)}
            guard declared > 0, let count = Int(exactly: declared), count <= maximum
            else { throw Failure.invalid }
            if count<=InvestigationMachineCoordinatorRawReceiptV1.maximumByteCount{return frame}
            while frame.count < count + 4 {
                frame.append(try readSome(descriptor,maximum:count+4-frame.count,
                    deadline:deadline))
            }
            return frame
        }
        private func readExactLine(_ descriptor:Int32,expected:Data,deadline:UInt64)throws{
            var observed = Data()
            while observed.count <= expected.count {
                let next=try readSome(descriptor,maximum:1,deadline:deadline);observed.append(next)
                if next.first == UInt8(ascii: "\n") { break }
            }
            guard observed == expected else { throw Failure.invalid }
        }
        private func readExactPrompt(_ descriptor:Int32,expected:[UInt8],deadline:UInt64)throws{
            var matched = 0
            while matched < expected.count {
                let next = try readSome(descriptor, maximum: 1, deadline: deadline)
                guard next.count==1,next[next.startIndex]==expected[matched] else{throw Failure.invalid}
                matched += 1
            }
        }
        private func readSome(_ descriptor:Int32,maximum:Int,deadline:UInt64)throws->Data{
            while true {
                var event=pollfd(fd:descriptor,events:Int16(POLLIN|POLLHUP),revents:0)
                let ready = poll(&event, 1, Self.timeout(deadline))
                if ready < 0, errno == EINTR { continue }
                guard ready>0,event.revents&Int16(POLLERR|POLLNVAL)==0
                else{throw Failure.deadline}
                var bytes=[UInt8](repeating:0,count:maximum);let count=Darwin.read(
                    descriptor,&bytes,maximum)
                if count < 0, errno == EINTR { continue }
                guard count > 0 else { throw Failure.invalid }
                return Data(bytes.prefix(count))
            }
        }
        private func writeAll(_ descriptor:Int32,bytes:[UInt8])throws{
            try bytes.withUnsafeBytes{try writeRaw(descriptor,bytes:$0)}}
        private func writeRaw(_ descriptor:Int32,bytes:UnsafeRawBufferPointer)throws{
            var offset = 0
            while offset < bytes.count {
                let count=Darwin.write(descriptor,bytes.baseAddress?.advanced(by:offset),
                    bytes.count-offset)
                if count < 0, errno == EINTR { continue }
                guard count > 0 else { throw Failure.posix(errno) }
                offset += count
            }
        }
        private func wait(_ processID: pid_t, deadline: UInt64) throws
            -> InvestigationMachineCampaignExactWait
        {
            while true {
                try check(deadline)
                var status: Int32 = 0
                let value = waitpid(processID, &status, WNOHANG | WUNTRACED)
                if value == processID {
                    let low = status & 0x7f
                    if low == 0 {
                        return .exited(status: status >> 8 & 0xff)
                    }
                    if low == 0x7f {
                        return .stopped(signal: status >> 8 & 0xff)
                    }
                    guard low > 0 && low < NSIG else { throw Failure.invalid }
                    return .signaled(signal: low)
                }
                if value < 0, errno != EINTR { throw Failure.posix(errno) }
                _ = poll(nil, 0, 10)
            }
        }

        private static func identity(
            _ processID: pid_t, terminal: Int32,
            initial: InvestigationMachineCampaignOuterIdentity?
        ) throws -> InvestigationMachineCampaignOuterIdentity {
            var narrow = stornaut_investigation_identity()
            var process = proc_bsdinfo()
            let narrowStatus = stornaut_investigation_identity_for_pid(
                processID, &narrow)
            let processBytes = proc_pidinfo(
                processID, PROC_PIDTBSDINFO, 0, &process,
                Int32(MemoryLayout<proc_bsdinfo>.size))
            guard narrowStatus == 0,
                  processBytes == MemoryLayout<proc_bsdinfo>.size,
                  narrow.process_id == processID,
                  process.pbi_pid == processID, process.pbi_pgid == processID,
                  narrow.process_id_version > 0, process.pbi_ppid > 1,
                  process.pbi_start_tvsec > 0,
                  process.pbi_start_tvusec < 1_000_000,
                  getsid(processID) == processID,
                  Self.validDescriptor(terminal, type: S_IFCHR, access: O_RDWR)
            else { throw Failure.invalid }
            let observed = InvestigationMachineCampaignOuterIdentity(
                processID: processID,
                processIDVersion: UInt32(narrow.process_id_version),
                parentProcessID: pid_t(process.pbi_ppid),
                processGroupID: pid_t(process.pbi_pgid), sessionID: processID,
                foregroundProcessGroupID: initial?.foregroundProcessGroupID
                    ?? pid_t(process.e_tpgid),
                effectiveUserID: uid_t(process.pbi_uid),
                startTimeSeconds: process.pbi_start_tvsec,
                startTimeMicroseconds: process.pbi_start_tvusec)
            if let initial {
                guard observed == initial else { throw Failure.invalid }
            } else {
                guard process.pbi_flags & UInt32(PROC_FLAG_CONTROLT) != 0,
                      process.e_tpgid == UInt32(processID)
                else { throw Failure.invalid }
            }
            return observed
        }

        private static func residue(
            groupID: pid_t, sessionID: pid_t
        ) throws -> InvestigationMachineCampaignResidueObservation {
            var capacity = 4_096
            while capacity <= 131_072 {
                var pids = [pid_t](repeating: 0, count: capacity)
                let count = pids.withUnsafeMutableBytes {
                    proc_listallpids($0.baseAddress, Int32($0.count))
                }
                guard count >= 0 else { throw Failure.posix(errno) }
                if count < capacity {
                    var groups: [pid_t] = [], sessions: [pid_t] = []
                    for pid in pids.prefix(Int(count)) where pid > 1 {
                        errno = 0; let group = getpgid(pid)
                        if group == groupID { groups.append(pid) }
                        else if group < 0, errno != ESRCH {
                            throw Failure.posix(errno)
                        }
                        errno = 0; let session = getsid(pid)
                        if session == sessionID { sessions.append(pid) }
                        else if session < 0, errno != ESRCH {
                            throw Failure.posix(errno)
                        }
                    }
                    return .init(
                        processGroupMembers: groups.sorted(),
                        sessionMembers: sessions.sorted(), complete: true)
                }
                capacity *= 2
            }
            return .init(
                processGroupMembers: [], sessionMembers: [], complete: false)
        }

        private static func validDescriptor(
            _ descriptor: Int32, type: mode_t, access: Int32
        ) -> Bool {
            var value = stat(); let flags = fcntl(descriptor, F_GETFL)
            return fstat(descriptor, &value) == 0
                && value.st_mode & S_IFMT == type && flags >= 0
                && flags & O_ACCMODE == access
        }

        private static func executablePath() throws -> String {
            var bytes = [CChar](repeating: 0, count: Int(MAXPATHLEN))
            let count = proc_pidpath(getpid(), &bytes, UInt32(bytes.count))
            guard count > 1, count < bytes.count, let value = String(
                bytes: bytes.prefix(Int(count)).map(UInt8.init(bitPattern:)),
                encoding: .utf8), value.first == "/"
            else { throw Failure.invalid }
            return value
        }

        private static func timeout(_ deadline: UInt64) -> Int32 {
            let now = DispatchTime.now().uptimeNanoseconds
            guard now < deadline else { return 0 }
            return Int32(min(
                UInt64(Int32.max), max(1, (deadline - now) / 1_000_000)))
        }
    }
}


@main
struct StornautInvestigationMachineCampaignCommand {
    static func main() async {
        exit(await InvestigationMachineCampaignExecutable.run())
    }
}
#else
@main
struct StornautInvestigationMachineCampaignCommand {
    static func main() { exit(78) }
}
#endif
