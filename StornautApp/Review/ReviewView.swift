import StornautCore
import SwiftUI

struct ReviewView: View {
    @Environment(StornautAppModel.self) private var appModel
    @State private var focus: ClassificationID?
    @State private var inspectorIsPresented = false

    private let byteFormatter = StornautByteFormatter()

    var body: some View {
        let model = ReviewModel(
            state: appModel.reviewState,
            pageProjection: appModel.pageState.projection
                ?? appModel.scanState.projection
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
        .navigationTitle("review.title")
        .inspector(isPresented: $inspectorIsPresented) {
            if let inspector = model.inspector {
                ReviewInspector(
                    model: inspector,
                    close: {
                        inspectorIsPresented = false
                        focus = nil
                        appModel.focusReviewRow(nil)
                    }
                )
            }
        }
        .sheet(
            isPresented: Binding(
                get: { model.confirmation != nil },
                set: {
                    if !$0 { appModel.cancelReviewSheet() }
                }
            )
        ) {
            if let confirmation = model.confirmation {
                ReviewConfirmationSheet(
                    model: confirmation,
                    cancel: appModel.cancelReviewSheet,
                    confirm: appModel.confirmReviewExecution
                )
            }
        }
        .sheet(
            isPresented: Binding(
                get: {
                    model.stale != nil
                        && appModel.reviewStaleSheetIsPresented
                },
                set: {
                    if !$0 { appModel.cancelReviewSheet() }
                }
            )
        ) {
            if let stale = model.stale {
                ReviewStaleSheet(
                    model: stale,
                    refresh: appModel.refreshStaleReview,
                    cancel: appModel.cancelReviewSheet
                )
            }
        }
        .onChange(of: focus) { _, value in
            appModel.focusReviewRow(value)
            inspectorIsPresented = value != nil
        }
        .onChange(of: model.inspector?.classificationID) { _, value in
            if value != focus {
                focus = value
            }
            inspectorIsPresented = value != nil
        }
        .task(id: model.inspector?.classificationID) {
            if let classificationID = model.inspector?.classificationID {
                focus = classificationID
                inspectorIsPresented = true
            }
        }
        .accessibilityIdentifier(
            "review.presentation.\(model.phase.rawValue)"
        )
    }

    private func header(_ model: ReviewModel) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Button(action: appModel.closeReview) {
                    Label(
                        "review.action.backToResults",
                        systemImage: "chevron.left"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("review.back")

                Text("review.title")
                    .font(.largeTitle.weight(.semibold))
                Text("review.subtitle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                if inspectorIsPresented {
                    inspectorIsPresented = false
                    focus = nil
                    appModel.focusReviewRow(nil)
                } else if let first = model.rows.first {
                    focus = first.classificationID
                }
            } label: {
                Label(
                    "review.inspector.title",
                    systemImage: "sidebar.right"
                )
            }
            .buttonStyle(.bordered)
            .disabled(model.rows.isEmpty)
            .keyboardShortcut("i", modifiers: [.command, .option])
            .accessibilityIdentifier("review.inspector.toggle")
        }
    }

    @ViewBuilder
    private func content(_ model: ReviewModel) -> some View {
        switch model.phase {
        case .loading, .preflighting:
            VStack(spacing: 12) {
                ProgressView()
                Text(
                    model.phase == .preflighting
                        ? "review.preflight.loading"
                        : "review.loading"
                )
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            ContentUnavailableView(
                "review.empty.title",
                systemImage: "checkmark.shield",
                description: Text("review.empty.message")
            )
            .accessibilityIdentifier("review.empty")
        case .scanAgain, .unavailable:
            ContentUnavailableView {
                Label(
                    model.phase == .scanAgain
                        ? "review.scanAgain.title"
                        : "review.unavailable.title",
                    systemImage: "exclamationmark.triangle"
                )
            } description: {
                Text(
                    LocalizedStringKey(
                        model.reasonKeys.first?.rawValue
                            ?? "review.unavailable.message"
                    )
                )
            } actions: {
                Button(
                    "scan.action.runAgain",
                    action: {
                        appModel.closeReview()
                        appModel.startQuickScan()
                    }
                )
            }
        case .idle:
            ContentUnavailableView(
                "review.unavailable.title",
                systemImage: "doc.text.magnifyingglass"
            )
        case .ready, .stale, .confirming, .executing,
             .executionBlocked:
            ReviewTable(
                groups: model.groups,
                focus: $focus,
                compactColumns: inspectorIsPresented,
                setSelection: {
                    appModel.setReviewSelection(
                        classificationID: $0,
                        isSelected: $1
                    )
                }
            )
        }
    }

    private func footer(_ model: ReviewModel) -> some View {
        HStack(spacing: 20) {
            metric(
                "review.summary.selected",
                value: model.summary.selectedCount.formatted()
            )
            metric(
                "review.summary.trash",
                value: byteFormatter.string(
                    for: model.summary.estimatedTrashBytes
                )
            )
            metric(
                "review.summary.permanent",
                value: byteFormatter.string(
                    for: model.summary.permanentReleaseBytes
                )
            )

            Spacer()

            if model.phase == .executionBlocked {
                Label(
                    "review.execution.writeDisabled",
                    systemImage: "lock.shield"
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }

            switch model.primaryAction {
            case .preflight:
                Button {
                    appModel.preflightReview()
                } label: {
                    Label(
                        String(
                            format: localized(
                                "review.action.moveItemsToTrash"
                            ),
                            model.summary.selectedCount
                        ),
                        systemImage: "trash"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.summary.selectedCount == 0)
                .accessibilityIdentifier("review.action.preflight")
            case .stopAfterCurrent:
                Button(
                    "review.action.stopAfterCurrent",
                    action: appModel.stopReviewAfterCurrent
                )
                .buttonStyle(.bordered)
                .accessibilityIdentifier(
                    "review.action.stopAfterCurrent"
                )
            case .stopWaiting:
                Button(
                    "review.action.stopWaiting",
                    action: appModel.cancelReviewExecutionWait
                )
                .buttonStyle(.bordered)
                .accessibilityIdentifier(
                    "review.action.stopWaiting"
                )
            case .none:
                EmptyView()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func metric(_ key: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStringKey(key))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}
