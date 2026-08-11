import StornautCore
import SwiftUI

struct HistoryView: View {
    @Environment(StornautAppModel.self) private var appModel
    let openScan: () -> Void

    @State private var query = ""
    @State private var terminalFilter = HistoryTerminalFilter.all
    @State private var dateFilter = HistoryDateFilter.allRetained
    @State private var selection: ScanSessionID?
    @State private var showsTrend = false
    @State private var pendingDelete: HistoryDeleteContract?

    init(openScan: @escaping () -> Void) {
        self.openScan = openScan
#if DEBUG
        _showsTrend = State(
            initialValue: DebugHistoryInitialPresentation.selection(
                arguments: CommandLine.arguments
            ) == .trend
        )
#endif
    }

    var body: some View {
        let now = Date()
        let model = HistoryModel(
            state: appModel.historyState,
            now: now,
            calendar: .autoupdatingCurrent,
            query: query,
            terminalFilter: terminalFilter,
            dateFilter: dateFilter,
            selectedID: selection
        )

        VStack(spacing: 0) {
            header(model)
            Divider()

            if model.presentation == .empty {
                emptyState
            } else if model.presentation == .noResults {
                noResultsState
            } else {
                statusBanner(model)
                HSplitView {
                    HistoryNavigator(
                        groups: model.groups,
                        corruptRecords: model.corruptRecords,
                        now: now,
                        selection: $selection
                    )
                    .frame(minWidth: 340, idealWidth: 370, maxWidth: 410)

                    Group {
                        if showsTrend, let trend = model.trend {
                            StorageTrendView(
                                model: trend,
                                close: { showsTrend = false }
                            )
                        } else if let selection,
                                  let record = model.records.first(
                                      where: { $0.id == selection }
                                  )
                        {
                            HistoryDetailView(
                                record: record,
                                now: now,
                                requestDelete: {
                                    pendingDelete = model.deleteContract(
                                        for: record.id
                                    )
                                }
                            )
                        } else {
                            ContentUnavailableView(
                                "history.selection.title",
                                systemImage: "clock.arrow.circlepath",
                                description: Text(
                                    "history.selection.message"
                                )
                            )
                        }
                    }
                    .frame(minWidth: 500, maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(pageBackground)
        .navigationTitle("history.title")
        .task(
            id: appModel.scanState.projection?.session.id.rawValue
                ?? "history-initial"
        ) {
            await appModel.refreshHistoryIfNeeded()
        }
        .onChange(of: model.records.map(\.id), initial: true) {
            _,
            IDs in
            if let selection, IDs.contains(selection) {
                return
            }
            selection = model.selectedID
            if model.trend == nil {
                showsTrend = false
            }
        }
        .confirmationDialog(
            "history.delete.confirm.title",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingDelete = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let pendingDelete {
                Button(
                    "history.delete.confirm.action",
                    role: .destructive
                ) {
                    let sessionID = pendingDelete.sessionID
                    self.pendingDelete = nil
                    Task {
                        await appModel.deleteHistorySession(sessionID)
                    }
                }
                .accessibilityIdentifier("history.delete.confirm.action")
            }
            Button("history.delete.cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text("history.delete.confirm.message")
                .accessibilityIdentifier(
                    "history.delete.confirm.message"
                )
        }
    }

    private func header(_ model: HistoryModel) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("history.title")
                    .font(.largeTitle.weight(.semibold))
                Text("history.subtitle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            TextField("history.search", text: $query)
                .textFieldStyle(.roundedBorder)
                .frame(width: 230)
                .accessibilityIdentifier("history.search")

            Picker("history.filter.status", selection: $terminalFilter) {
                ForEach(HistoryTerminalFilter.allCases) { value in
                    Text(
                        localized(
                            "history.filter.status.\(value.rawValue)"
                        )
                    )
                    .tag(value)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 130)

            Picker("history.filter.date", selection: $dateFilter) {
                ForEach(HistoryDateFilter.allCases) { value in
                    Text(
                        localized(
                            "history.filter.date.\(value.rawValue)"
                        )
                    )
                    .tag(value)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 130)

            if model.trend != nil {
                Button {
                    showsTrend.toggle()
                } label: {
                    Label(
                        showsTrend
                            ? "history.trend.back"
                            : "history.action.trend",
                        systemImage: "chart.xyaxis.line"
                    )
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("history.action.trend")
            }

            Button {
                Task {
                    await appModel.refreshHistory()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("history.action.refresh")
            .disabled(
                model.presentation == .loading
                    || model.presentation == .deleting
            )
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private func statusBanner(_ model: HistoryModel) -> some View {
        if model.presentation == .loading {
            statusStrip(
                titleKey: "history.status.loading",
                systemImage: "progress.indicator",
                role: .informational
            )
        } else if model.presentation == .deleting {
            statusStrip(
                titleKey: "history.status.deleting",
                systemImage: "trash",
                role: .limited
            )
        } else if model.presentation == .error {
            statusStrip(
                titleKey: model.reasonKey?.rawValue
                    ?? "history.error.storeUnavailable",
                systemImage: "exclamationmark.triangle",
                role: .failed
            )
        }
    }

    private var emptyState: some View {
        StornautEmptyStateView(
            titleKey: "history.empty.title",
            messageKey: "history.empty.message",
            systemImage: "clock.arrow.circlepath",
            actionTitleKey: "history.empty.action",
            action: openScan
        )
        .accessibilityIdentifier("history.empty")
    }

    private var noResultsState: some View {
        ContentUnavailableView(
            "history.noResults.title",
            systemImage: "line.3.horizontal.decrease.circle",
            description: Text("history.noResults.message")
        )
        .accessibilityIdentifier("history.noResults")
    }

    private func statusStrip(
        titleKey: String,
        systemImage: String,
        role: SemanticStatusRole
    ) -> some View {
        Label(
            LocalizedStringKey(titleKey),
            systemImage: systemImage
        )
        .font(.callout.weight(.medium))
        .foregroundStyle(role.color)
        .padding(.horizontal, 22)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(role.color.opacity(0.08))
        .accessibilityIdentifier("history.status")
    }

    private var pageBackground: Color {
#if DEBUG
        LaunchAppearanceOverride.backgroundColor
            ?? Color(nsColor: .windowBackgroundColor)
#else
        Color(nsColor: .windowBackgroundColor)
#endif
    }
}
