import StornautCore
import SwiftUI

struct CleanupResultView: View {
    @Environment(StornautAppModel.self) private var appModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var manifestIsPresented = false
    @State private var appeared = false

    private let byteFormatter = StornautByteFormatter()

    var body: some View {
        let model = CleanupResultModel(
            state: appModel.cleanupResultState
        )

        VStack(spacing: 0) {
            header(model)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 14)

            Divider()

            content(model)

            Divider()

            footer(model)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("cleanup.result.title")
        .sheet(isPresented: $manifestIsPresented) {
            if let detail = model.manifestDetail {
                CleanupManifestDetail(
                    model: detail,
                    dismiss: { manifestIsPresented = false }
                )
            }
        }
        .opacity(appeared ? 1 : 0.96)
        .scaleEffect(appeared ? 1 : 0.995)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.24),
            value: appeared
        )
        .task {
            appeared = true
        }
        .accessibilityIdentifier(
            "cleanup.result.presentation.\(model.phase.rawValue)"
        )
    }

    private func header(_ model: CleanupResultModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("cleanup.result.title")
                        .font(.largeTitle.weight(.semibold))
                    Text("cleanup.result.subtitle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let outcome = model.outcome {
                    let outcomeLabel = localizedOutcome(outcome)
                    VStack(alignment: .trailing, spacing: 7) {
                        HStack(spacing: 6) {
                            Image(systemName: outcomeImage(outcome))
                                .accessibilityHidden(true)
                            Text(verbatim: outcomeLabel)
                                .accessibilityIdentifier(
                                    "cleanup.result.outcome"
                                )
                        }
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(outcomeRole(outcome).color)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            Text(verbatim: outcomeLabel)
                        )
                        .accessibilityIdentifier("cleanup.result.outcome")

                        if let persistence = model.manifestPersistence {
                            let persistenceLabel =
                                localizedPersistence(persistence)
                            HStack(spacing: 6) {
                                Image(
                                    systemName:
                                        persistence == .saved
                                            ? "checkmark.seal"
                                            : "exclamationmark.arrow.triangle.2.circlepath"
                                )
                                .accessibilityHidden(true)
                                Text(verbatim: persistenceLabel)
                                    .accessibilityIdentifier(
                                        "cleanup.result.persistence"
                                    )
                            }
                            .font(.caption)
                            .foregroundStyle(
                                persistence == .saved
                                    ? SemanticStatusRole.positive.color
                                    : SemanticStatusRole.failed.color
                            )
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(
                                Text(verbatim: persistenceLabel)
                            )
                            .accessibilityIdentifier(
                                "cleanup.result.persistence"
                            )
                        }
                    }
                }
            }

            if model.summary != nil {
                Text(verbatim: accessibilitySummaryText(model))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityValue(accessibilitySummaryText(model))
        .accessibilityIdentifier("cleanup.result.header")
    }

    @ViewBuilder
    private func content(_ model: CleanupResultModel) -> some View {
        switch model.phase {
        case .presented, .openingTrash, .trashUnavailable,
             .retryingAudit:
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    recoveryHero(model)
                    summaries(model)
                    if model.phase == .trashUnavailable {
                        trashFailure
                    }
                    if model.manifestPersistence == .auditPending {
                        auditWarning(model)
                    }
                    CleanupResultTable(rows: model.rows)
                        .frame(minHeight: 210)
                    if let summary = model.summary {
                        CleanupAccountingDetails(
                            summary: summary,
                            observation: model.systemObservation
                        )
                    }
                }
                .padding(20)
            }
        case .corrupt:
            ContentUnavailableView {
                Label(
                    "cleanup.result.corrupt.title",
                    systemImage: "doc.badge.ellipsis"
                )
            } description: {
                Text("cleanup.result.corrupt.message")
            } actions: {
                Button(
                    "cleanup.action.done",
                    action: appModel.doneCleanupResult
                )
            }
            .accessibilityIdentifier("cleanup.result.corrupt")
        case .unavailable, .idle:
            ContentUnavailableView {
                Label(
                    "cleanup.result.unavailable.title",
                    systemImage: "exclamationmark.triangle"
                )
            } description: {
                Text(
                    verbatim: localized(
                        model.reasonKey?.rawValue
                            ?? "cleanup.result.unavailable.message"
                    )
                )
            } actions: {
                Button(
                    "cleanup.action.done",
                    action: appModel.doneCleanupResult
                )
            }
        }
    }

    private func recoveryHero(
        _ model: CleanupResultModel
    ) -> some View {
        HStack(alignment: .center, spacing: 20) {
            Image(systemName: "trash.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(
                    model.movedToTrashBytes.value > 0
                        ? SemanticStatusRole.positive.color
                        : SemanticStatusRole.neutral.color
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(
                    String(
                        format: localized(
                            "cleanup.result.hero.moved"
                        ),
                        byteFormatter.string(
                            for: model.movedToTrashBytes
                        )
                    )
                )
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                Text(
                    String(
                        format: localized(
                            "cleanup.result.hero.items"
                        ),
                        model.movedToTrashItemCount
                    )
                )
                    .font(.callout)
                Text("cleanup.result.hero.recoverable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if model.availableActions.contains(.openTrash) {
                Button(
                    "cleanup.action.openTrash",
                    action: appModel.openTrashFromCleanupResult
                )
                .buttonStyle(.bordered)
                .disabled(model.phase == .openingTrash)
                .accessibilityIdentifier("cleanup.result.openTrash")
            }
        }
        .padding(18)
        .background(
            Color.accentColor.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cleanup.result.hero")
    }

    private func summaries(
        _ model: CleanupResultModel
    ) -> some View {
        HStack(spacing: 12) {
            MetricTile(
                title: "cleanup.result.metric.processed",
                value: byteFormatter.string(
                    for: model.summary?.processedAllocatedBytes
                ),
                accessibilityValue:
                    byteFormatter.accessibilityString(
                        for: model.summary?.processedAllocatedBytes
                    ),
                systemImage: "checklist"
            )
            MetricTile(
                title: "cleanup.result.metric.permanent",
                value: byteFormatter.string(
                    for: model.permanentlyReleasedBytes
                ),
                accessibilityValue:
                    byteFormatter.accessibilityString(
                        for: model.permanentlyReleasedBytes
                    ),
                systemImage: "lock.shield"
            )
            MetricTile(
                title: "cleanup.result.metric.system",
                value: model.systemObservation.map {
                    CleanupResultFormatting.signedBytes(
                        $0.freeSpaceDelta,
                        formatter: byteFormatter
                    )
                } ?? localized(
                    "cleanup.result.system.unavailable.short"
                ),
                accessibilityValue: model.systemObservation.map {
                    CleanupResultFormatting.signedBytes(
                        $0.freeSpaceDelta,
                        formatter: byteFormatter
                    )
                } ?? localized(
                    "cleanup.result.system.unavailable"
                ),
                systemImage: "internaldrive"
            )
        }
    }

    private var trashFailure: some View {
        HStack(spacing: 10) {
            Label(
                "cleanup.result.trashOpen.failed",
                systemImage: "exclamationmark.triangle"
            )
            .foregroundStyle(SemanticStatusRole.failed.color)
            Spacer()
            Button(
                "cleanup.action.dismiss",
                action: appModel.dismissCleanupResultTrashFailure
            )
        }
        .padding(12)
        .background(
            SemanticStatusRole.failed.color.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            Text("cleanup.result.trashOpen.failed")
        )
        .accessibilityIdentifier("cleanup.result.trashUnavailable")
    }

    private func auditWarning(
        _ model: CleanupResultModel
    ) -> some View {
        HStack(spacing: 10) {
            Label(
                "cleanup.result.auditPending.message",
                systemImage: "exclamationmark.arrow.triangle.2.circlepath"
            )
            .foregroundStyle(SemanticStatusRole.failed.color)
            Spacer()
            if model.availableActions.contains(.retrySavingAudit) {
                Button(
                    "cleanup.action.retryAudit",
                    action: appModel.retryCleanupResultAudit
                )
                .disabled(model.phase == .retryingAudit)
                .accessibilityIdentifier("cleanup.result.retryAudit")
            }
        }
        .padding(12)
        .background(
            SemanticStatusRole.failed.color.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .accessibilityIdentifier("cleanup.result.auditPending")
    }

    private func accessibilitySummaryText(
        _ model: CleanupResultModel
    ) -> String {
        String(
            format: localized("cleanup.result.accessibility.summary"),
            model.summary?.succeededCount ?? 0,
            model.summary?.failedCount ?? 0,
            model.summary?.cancelledCount ?? 0,
            model.summary?.unknownCount ?? 0,
            byteFormatter.accessibilityString(
                for: model.movedToTrashBytes
            ),
            byteFormatter.accessibilityString(
                for: model.permanentlyReleasedBytes
            )
        )
    }

    private func footer(_ model: CleanupResultModel) -> some View {
        HStack {
            Text("cleanup.result.footer.truth")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("cleanup.action.viewManifest") {
                manifestIsPresented = true
            }
            .disabled(model.manifestDetail == nil)
            .accessibilityIdentifier("cleanup.result.viewManifest")

            Button(
                "cleanup.action.done",
                action: appModel.doneCleanupResult
            )
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("cleanup.result.done")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func outcomeImage(
        _ outcome: CleanupResultOutcome
    ) -> String {
        switch outcome {
        case .completed:
            "checkmark.circle"
        case .completedWithIssues, .stopped, .auditPending:
            "exclamationmark.triangle"
        case .failed:
            "xmark.octagon"
        case .outcomeUnknown:
            "questionmark.diamond"
        }
    }

    private func localizedOutcome(
        _ outcome: CleanupResultOutcome
    ) -> String {
        switch outcome {
        case .completed:
            localized("cleanup.result.outcome.completed")
        case .completedWithIssues:
            localized("cleanup.result.outcome.completedWithIssues")
        case .failed:
            localized("cleanup.result.outcome.failed")
        case .stopped:
            localized("cleanup.result.outcome.stopped")
        case .auditPending:
            localized("cleanup.result.outcome.auditPending")
        case .outcomeUnknown:
            localized("cleanup.result.outcome.outcomeUnknown")
        }
    }

    private func localizedPersistence(
        _ persistence: CleanupManifestPersistence
    ) -> String {
        switch persistence {
        case .saved:
            localized("cleanup.result.persistence.saved")
        case .auditPending:
            localized("cleanup.result.persistence.auditPending")
        }
    }

    private func outcomeRole(
        _ outcome: CleanupResultOutcome
    ) -> SemanticStatusRole {
        switch outcome {
        case .completed:
            .positive
        case .completedWithIssues, .stopped, .auditPending,
             .outcomeUnknown:
            .limited
        case .failed:
            .failed
        }
    }

}
