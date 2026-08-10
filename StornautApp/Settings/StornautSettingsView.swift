import StornautCore
import SwiftUI

struct StornautSettingsView: View {
    @Environment(StornautAppModel.self) private var appModel
    @State private var selection: SettingsSection
    @State private var knowledgeSelection: LocalKnowledgeID?
    @State private var confirmation: SettingsConfirmation?

    init() {
#if DEBUG
        _selection = State(
            initialValue: DebugSettingsInitialSection.selection(
                arguments: CommandLine.arguments
            )
        )
#else
        _selection = State(initialValue: .general)
#endif
    }

    var body: some View {
        let model = SettingsModel(
            state: appModel.settingsState,
            latestProjection: appModel.pageState.projection
        )
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(
                    LocalizedStringKey(section.localizationKey),
                    systemImage: section.systemImage
                )
                .tag(section)
                .accessibilityIdentifier(
                    "settings.sidebar.\(section.rawValue)"
                )
            }
            .listStyle(.sidebar)
            .navigationTitle("settings.title")
            .navigationSplitViewColumnWidth(
                min: 190,
                ideal: 210,
                max: 230
            )
        } detail: {
            ZStack {
                settingsBackground
                    .ignoresSafeArea()
                SettingsContentProbe()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                VStack(spacing: 0) {
                    settingsStatus(model)
                    sectionContent(model)
                }
            }
            .navigationTitle(
                LocalizedStringKey(selection.localizationKey)
            )
        }
        .frame(minWidth: 860, minHeight: 560)
        .task {
            await appModel.refreshSettingsIfNeeded()
        }
        .onChange(
            of: model.localKnowledge.records.map(\.id),
            initial: true
        ) { _, IDs in
            if let knowledgeSelection, IDs.contains(knowledgeSelection) {
                return
            }
            knowledgeSelection = IDs.first
        }
        .confirmationDialog(
            confirmationTitle,
            isPresented: Binding(
                get: { confirmation != nil },
                set: { isPresented in
                    if !isPresented {
                        confirmation = nil
                    }
                }
            ),
            titleVisibility: .visible,
            presenting: confirmation
        ) { confirmation in
            Button(role: .destructive) {
                perform(confirmation)
            } label: {
                Text(verbatim: confirmationActionTitle(confirmation))
            }
            .accessibilityIdentifier(
                "settings.confirm.\(confirmation.rawValue).action"
            )
            Button("settings.action.cancel", role: .cancel) {
                self.confirmation = nil
            }
        } message: { confirmation in
            Text(verbatim: localized(confirmationMessageKey(confirmation)))
        }
    }

    @ViewBuilder
    private func sectionContent(
        _ model: SettingsModel
    ) -> some View {
        let snapshot = appModel.settingsState.snapshot
        let preferences = snapshot?.preferences ?? .defaults
        switch selection {
        case .general:
            GeneralSettingsView(
                model: model.general,
                updatePreferences: updatePreferences,
                preferences: preferences
            )
        case .scanning:
            ScanningSettingsView(
                model: model.scanning,
                chooseRoot: {
                    Task { await appModel.chooseSettingsPrimaryRoot() }
                },
                resetRoot: {
                    Task { await appModel.resetSettingsPrimaryRoot() }
                },
                chooseExclusion: {
                    Task { await appModel.chooseSettingsExclusion() }
                },
                removeExclusion: { exclusion in
                    Task {
                        await appModel.removeSettingsExclusion(exclusion)
                    }
                }
            )
        case .permissions:
            PermissionsSettingsView(
                model: model.permissions,
                openSystemSettings: {
                    Task { await appModel.openFullDiskAccessSettings() }
                },
                checkAgain: {
                    Task { await appModel.refreshSettings() }
                }
            )
        case .codexAndDeepDive:
            CodexSettingsView(
                model: model.codex,
                preferences: preferences,
                updatePreferences: updatePreferences,
                checkAgain: {
                    Task { await appModel.refreshSettings() }
                }
            )
        case .privacyAndData:
            PrivacyDataSettingsView(
                model: model.privacy,
                requestConfirmation: {
                    confirmation = $0
                }
            )
        case .localKnowledge:
            LocalKnowledgeSettingsView(
                model: model.localKnowledge,
                selection: $knowledgeSelection,
                requestForget: {
                    confirmation = .forgetKnowledge
                },
                requestForgetAll: {
                    confirmation = .forgetAllKnowledge
                }
            )
        }
    }

    @ViewBuilder
    private func settingsStatus(_ model: SettingsModel) -> some View {
        if model.presentation == .loading {
            Label(
                "settings.status.loading",
                systemImage: "progress.indicator"
            )
            .foregroundStyle(.secondary)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary)
            .accessibilityIdentifier("settings.status")
        } else if model.presentation == .error {
            Label(
                LocalizedStringKey(
                    model.reasonKey?.rawValue
                        ?? "settings.error.loadFailed"
                ),
                systemImage: "exclamationmark.triangle"
            )
            .foregroundStyle(.red)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.red.opacity(0.08))
            .accessibilityIdentifier("settings.status")
        }
    }

    private func updatePreferences(
        _ preferences: SettingsPreferences
    ) {
        Task {
            await appModel.updateSettingsPreferences(preferences)
        }
    }

    private var confirmationTitle: String {
        guard let confirmation else {
            return localized("settings.confirm.generic")
        }
        return localized(confirmationTitleKey(confirmation))
    }

    private func confirmationTitleKey(
        _ value: SettingsConfirmation
    ) -> String {
        "settings.confirm.\(value.rawValue).title"
    }

    private func confirmationMessageKey(
        _ value: SettingsConfirmation
    ) -> String {
        "settings.confirm.\(value.rawValue).message"
    }

    private func confirmationActionTitle(
        _ value: SettingsConfirmation
    ) -> String {
        localized(
            "settings.confirm.\(value.rawValue).action"
        )
    }

    private func perform(_ value: SettingsConfirmation) {
        confirmation = nil
        Task {
            switch value {
            case .clearEvidence:
                await appModel.clearSettingsEvidence()
            case .clearManifests:
                await appModel.clearSettingsManifests()
            case .forgetKnowledge:
                if let knowledgeSelection {
                    await appModel.forgetSettingsKnowledge(
                        knowledgeSelection
                    )
                }
            case .forgetAllKnowledge:
                await appModel.forgetAllSettingsKnowledge()
            }
        }
    }

    private var settingsBackground: Color {
#if DEBUG
        LaunchAppearanceOverride.backgroundColor
            ?? Color(nsColor: .windowBackgroundColor)
#else
        Color(nsColor: .windowBackgroundColor)
#endif
    }
}

private struct SettingsContentProbe: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.setAccessibilityElement(true)
        view.setAccessibilityIdentifier("settings.content")
        view.setAccessibilityRole(.group)
        view.setAccessibilityLabel(localized("settings.title"))
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.setAccessibilityLabel(localized("settings.title"))
    }
}
