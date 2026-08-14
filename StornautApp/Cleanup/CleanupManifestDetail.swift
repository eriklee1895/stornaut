import StornautCore
import SwiftUI

struct CleanupManifestDetail: View {
    let model: CleanupManifestDetailModel
    let dismiss: () -> Void

    private let byteFormatter = StornautByteFormatter()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("cleanup.manifest.title")
                        .font(.title2.weight(.semibold))
                    Text("cleanup.manifest.subtitle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("cleanup.action.done", action: dismiss)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("cleanup.manifest.done")
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    identity
                    evidenceState
                    timeline
                    systemObservation
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 700, idealWidth: 760, minHeight: 560)
        .accessibilityIdentifier("cleanup.manifest.detail")
    }

    private var identity: some View {
        manifestSection("cleanup.manifest.identity") {
            fact(
                "cleanup.manifest.id",
                value: model.manifestID.rawValue
            )
            fact(
                "cleanup.manifest.planID",
                value: model.planID.rawValue
            )
            fact(
                "cleanup.manifest.created",
                value: date(model.createdAt)
            )
            fact(
                "cleanup.manifest.expires",
                value: date(model.expiresAt)
            )
            fact(
                "cleanup.manifest.persistence",
                valueKey:
                    "cleanup.result.persistence."
                        + model.persistence.rawValue
            )
        }
    }

    private var evidenceState: some View {
        manifestSection("cleanup.manifest.evidence") {
            let evidenceLabel = localized(
                "cleanup.result.evidence."
                    + model.evidenceAvailability.rawValue
            )
            Label(
                title: { Text(verbatim: evidenceLabel) },
                icon: {
                    Image(
                        systemName:
                            model.evidenceAvailability == .retained
                                ? "link.circle"
                                : "clock.badge.xmark"
                    )
                }
            )
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                Text(verbatim: evidenceLabel)
            )
            .accessibilityIdentifier("cleanup.manifest.evidence.status")
        }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("cleanup.manifest.timeline")
                .font(.headline)
            ForEach(Array(model.entries.enumerated()), id: \.element.id) {
                index, entry in
                HStack(alignment: .top, spacing: 12) {
                    Image(
                        systemName:
                            entry.result == .succeeded
                                ? "checkmark.circle.fill"
                                : entry.result == .cancelled
                                    ? "stop.circle"
                                    : "exclamationmark.circle"
                    )
                    .foregroundStyle(
                        entry.result == .succeeded
                            ? SemanticStatusRole.positive.color
                            : entry.result == .cancelled
                                ? SemanticStatusRole.neutral.color
                                : SemanticStatusRole.failed.color
                    )
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(
                                entry.itemName
                                    ?? localized(
                                        "cleanup.result.item.evidenceExpired"
                                    )
                            )
                                .fontWeight(.semibold)
                            Spacer()
                            Text(
                                String(
                                    format: localized(
                                        "cleanup.manifest.step"
                                    ),
                                    index + 1
                                )
                            )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let path = entry.exactOriginalPath {
                            Text(path)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        fact(
                            "cleanup.manifest.actionID",
                            value: entry.actionID.rawValue
                        )
                        fact(
                            "cleanup.manifest.itemID",
                            value: entry.planItemID.rawValue
                        )
                        fact(
                            "cleanup.manifest.policy",
                            valueKey:
                                "disposition."
                                    + dispositionSlug(
                                        entry.policyDisposition
                                    )
                        )
                        ForEach(
                            entry.policyReasonKeys,
                            id: \.rawValue
                        ) { reason in
                            fact(
                                "cleanup.manifest.policyReason",
                                valueKey: policyReasonKey(reason),
                                identifier:
                                    "cleanup.manifest.policyReason."
                                        + reason.rawValue
                            )
                        }
                        fact(
                            "cleanup.manifest.result",
                            valueKey:
                                "cleanup.result.row.result."
                                    + entry.result.rawValue
                        )
                        if let startedAt = entry.startedAt {
                            fact(
                                "cleanup.manifest.started",
                                value: date(startedAt)
                            )
                        }
                        if let finishedAt = entry.finishedAt {
                            fact(
                                "cleanup.manifest.finished",
                                value: date(finishedAt)
                            )
                        }
                        fact(
                            "cleanup.manifest.candidate",
                            value: byteFormatter.string(
                                for:
                                    entry.measures
                                        .candidateAllocatedBytes
                            ),
                            identifier: "cleanup.manifest.candidate"
                        )
                        fact(
                            "cleanup.manifest.processed",
                            value: byteFormatter.string(
                                for:
                                    entry.measures
                                        .processedAllocatedBytes
                            )
                        )
                        fact(
                            "cleanup.manifest.trash",
                            value: byteFormatter.string(
                                for:
                                    entry.measures
                                        .movedToTrashAllocatedBytes
                            )
                        )
                        fact(
                            "cleanup.manifest.permanent",
                            value: byteFormatter.string(
                                for:
                                    entry.measures
                                        .permanentlyReleasedAllocatedBytes
                            ),
                            identifier: "cleanup.manifest.permanent"
                        )
                        if let recoveryDetailKey =
                            entry.recoveryDetailKey
                        {
                            fact(
                                "cleanup.manifest.recovery",
                                valueKey: recoveryKey(
                                    recoveryDetailKey
                                )
                            )
                        }
                        ForEach(
                            entry.evidenceLineage,
                            id: \.rawValue
                        ) { lineage in
                            fact(
                                "cleanup.manifest.lineage",
                                valueKey: evidenceLineageKey(lineage),
                                identifier:
                                    "cleanup.manifest.lineage."
                                        + lineage.rawValue
                            )
                        }
                        if let error = entry.error {
                            fact(
                                "cleanup.manifest.failureStage",
                                valueKey:
                                    "cleanup.failure.stage."
                                        + error.stage.rawValue
                            )
                            fact(
                                "cleanup.manifest.failure",
                                valueKey: failureKey(error.code)
                            )
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
                .accessibilityElement(children: .contain)
            }
        }
    }

    @ViewBuilder
    private var systemObservation: some View {
        if let observation = model.systemObservation {
            manifestSection("cleanup.manifest.system") {
                fact(
                    "cleanup.manifest.source",
                    value: observation.source.rawValue
                )
                fact(
                    "cleanup.manifest.sampledBefore",
                    value: date(observation.sampledBeforeAt)
                )
                fact(
                    "cleanup.manifest.sampledAfter",
                    value: date(observation.sampledAfterAt)
                )
                fact(
                    "cleanup.manifest.freeDelta",
                    value: CleanupResultFormatting.signedBytes(
                        observation.freeSpaceDelta,
                        formatter: byteFormatter
                    ),
                    identifier: "cleanup.manifest.freeDelta"
                )
                fact(
                    "cleanup.manifest.unexplainedDelta",
                    value: observation.unexplainedDelta.map {
                        CleanupResultFormatting.signedBytes(
                            $0,
                            formatter: byteFormatter
                        )
                    } ?? localized(
                        "cleanup.result.system.unavailable.short"
                    ),
                    identifier: "cleanup.manifest.unexplainedDelta"
                )
                Text("cleanup.result.system.nonCausal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            manifestSection("cleanup.manifest.system") {
                Label(
                    "cleanup.result.system.unavailable",
                    systemImage: "questionmark.circle"
                )
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(
                    "cleanup.manifest.system.unavailable"
                )
            }
        }
    }

    private func manifestSection<Content: View>(
        _ titleKey: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: localized(titleKey))
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
    }

    private func fact(
        _ titleKey: String,
        value: String? = nil,
        valueKey: String? = nil,
        identifier: String? = nil
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: localized(titleKey))
                .foregroundStyle(.secondary)
            Spacer()
            if let value {
                Text(value)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.trailing)
            } else if let valueKey {
                Text(verbatim: localized(valueKey))
                    .multilineTextAlignment(.trailing)
            }
        }
        .font(.callout)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier ?? titleKey)
    }

    private func date(_ value: Date) -> String {
        value.formatted(
            .dateTime.year().month().day().hour().minute().second()
        )
    }

    private func dispositionSlug(
        _ disposition: ReclaimDisposition
    ) -> String {
        switch disposition {
        case .readyToReclaim:
            "ready"
        case .reviewRecommended:
            "review"
        case .protected:
            "protected"
        case .unknown:
            "unknown"
        }
    }

    private func failureKey(_ code: DomainToken) -> String {
        switch code.rawValue {
        case "trash.destination.unavailable":
            "cleanup.failure.trashUnavailable"
        case "cleanup.recovery.unknown":
            "cleanup.failure.outcomeUnknown"
        default:
            "cleanup.failure.unknown"
        }
    }

    private func policyReasonKey(_ reason: DomainToken) -> String {
        switch reason.rawValue {
        case "policy.item.allowed", "policy.profile.allowed":
            "cleanup.policy.allowed"
        case let value where value.hasPrefix("policy.evidence."):
            "cleanup.policy.evidence"
        case let value where value.hasPrefix("policy.activity."):
            "cleanup.policy.activity"
        case let value where value.hasPrefix("policy.path."):
            "cleanup.policy.path"
        case let value where value.hasPrefix("policy.identity."):
            "cleanup.policy.identity"
        case let value where value.hasPrefix("policy.workflow."):
            "cleanup.policy.workflow"
        default:
            "cleanup.policy.other"
        }
    }

    private func recoveryKey(_ key: DomainToken) -> String {
        switch key.rawValue {
        case "cleanup.recovery.trash":
            "cleanup.result.recovery.recoverableFromTrash"
        case "cleanup.recovery.original":
            "cleanup.result.recovery.originalRemains"
        case "cleanup.recovery.not-started":
            "cleanup.result.recovery.notStarted"
        default:
            "cleanup.result.recovery.outcomeUnknown"
        }
    }

    private func evidenceLineageKey(_ key: DomainToken) -> String {
        switch key.rawValue {
        case "cleanup.evidence.rule":
            "cleanup.evidence.lineage.rule"
        case "cleanup.evidence.activity":
            "cleanup.evidence.lineage.activity"
        default:
            "cleanup.evidence.lineage.other"
        }
    }
}
