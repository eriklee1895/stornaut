import Foundation
import StornautCodex
import StornautCore

package enum InvestigationContextError: Error, Sendable, Equatable {
    case inputLimitExceeded
    case invalidProtocolContext
}

package struct InvestigationCompressedContextV1:
    Sendable,
    Equatable
{
    public let contextBytes: Data
    public let contextText: String
    public let protocolContext: InvestigationProtocolContext

    package init(
        contextBytes: Data,
        contextText: String,
        protocolContext: InvestigationProtocolContext
    ) {
        self.contextBytes = contextBytes
        self.contextText = contextText
        self.protocolContext = protocolContext
    }
}

package struct InvestigationContextCompressor: Sendable {
    package init() {}

    package func compress(
        plan: InvestigationPlan,
        runID: InvestigationRunID,
        receipt: InvestigationRuntimeReceiptV1,
        priorPartialSummary: String?
    ) throws -> InvestigationCompressedContextV1 {
        let targetIDs = plan.targets.map(\.id.rawValue)
        let candidateBindings = plan.targets.prefix(256).enumerated().map {
            (
                candidateID: String(
                    format: "candidate-%04d",
                    $0.offset + 1
                ),
                targetID: $0.element.id.rawValue
            )
        }
        let candidateTargetIDs = Dictionary(
            uniqueKeysWithValues: candidateBindings.map {
                ($0.candidateID, $0.targetID)
            }
        )
        let candidateIDByTarget = Dictionary(
            uniqueKeysWithValues: candidateBindings.map {
                ($0.targetID, $0.candidateID)
            }
        )
        let sourceFingerprint = plan.sourceFingerprint.hex
        let targetSetFingerprint = plan.targetSetFingerprint.hex
        let capabilities = receipt.capabilityTokens
            .map(\.rawValue)
            .joined(separator: ",")
        let remainingUnknown = String(
            plan.remainingUnknownByteThreshold?.value ?? 0
        )
        var lines = [
            "context-version: investigation-context-v1",
            "investigation-id: \(plan.id.rawValue)",
            "source-fingerprint: \(sourceFingerprint)",
            "target-set-fingerprint: \(targetSetFingerprint)",
            "budget-preset: \(plan.budgetPreset.rawValue)",
            "requested-coverage-permille: \(plan.requestedCoveragePermille)",
            "remaining-unknown-byte-threshold: \(remainingUnknown)",
            "runtime-receipt-id: \(receipt.id.rawValue)",
            "collaboration-schema: \(receipt.schema.rawValue)",
            "capabilities: \(capabilities)",
            "retained-targets:",
        ]
        for target in plan.targets {
            lines.append("- target-id: \(target.id.rawValue)")
            lines.append("  kind: \(target.kind.rawValue)")
            lines.append(
                "  expected-allocated-bytes: "
                    + String(target.expectedAllocatedBytes?.value ?? 0)
            )
            lines.append(
                "  uncertainty-permille: \(target.uncertaintyPermille)"
            )
            lines.append(
                "  relevance-permille: \(target.relevancePermille)"
            )
            if let candidateID = candidateIDByTarget[target.id.rawValue] {
                lines.append("  candidate-proposal-id: \(candidateID)")
            }
        }
        if let priorPartialSummary {
            lines.append(
                "verified-prior-partial-summary: \(priorPartialSummary)"
            )
        }
        let text = lines.joined(separator: "\n") + "\n"
        let bytes = Data(text.utf8)
        guard Self.admission(
            inputByteCount: UInt64(bytes.count),
            cumulativeConsumed: 0,
            limits: plan.budgetLimits
        ) == .admitted else {
            throw InvestigationContextError.inputLimitExceeded
        }
        let context: InvestigationProtocolContext
        do {
            context = try InvestigationProtocolContext(
                investigationID: plan.id.rawValue,
                runID: runID.rawValue,
                targetIDs: targetIDs,
                candidateTargetIDs: candidateTargetIDs,
                requiredCapabilities: Set(
                    receipt.capabilityTokens.compactMap {
                        StornautCodex.InvestigationCapability(
                            rawValue: codexCapabilityToken($0)
                        )
                    }
                )
            )
        } catch {
            throw InvestigationContextError.invalidProtocolContext
        }
        return InvestigationCompressedContextV1(
            contextBytes: bytes,
            contextText: text,
            protocolContext: context
        )
    }

    package static func admission(
        inputByteCount: UInt64,
        cumulativeConsumed: UInt64,
        limits: InvestigationBudgetLimits
    ) -> InvestigationBudgetAdmission {
        guard inputByteCount > 0,
              inputByteCount <= limits.singleContextInputBytes,
              cumulativeConsumed <= limits.cumulativeContextBytes,
              inputByteCount
                <= limits.cumulativeContextBytes - cumulativeConsumed
        else {
            return .wouldExceed
        }
        return .admitted
    }
}

package enum InvestigationPromptV1 {
    package static func load() throws -> String {
        guard let url = Bundle.module.url(
            forResource: "investigation-prompt-v1",
            withExtension: "txt"
        ) else {
            throw InvestigationContextError.invalidProtocolContext
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

private func codexCapabilityToken(
    _ capability: StornautCore.InvestigationCapability
) -> String {
    switch capability {
    case .directRead:
        "directRead"
    case .shell:
        "shell"
    case .unifiedExec:
        "unifiedExec"
    case .liveSearch:
        "liveSearch"
    case .publicCommandNetwork:
        "publicNetwork"
    case .browserOrDirectFetch:
        "browserOrDirectFetch"
    case .imageInspection:
        "imageInspection"
    case .skills:
        "skills"
    case .subagents:
        "subagents"
    }
}
