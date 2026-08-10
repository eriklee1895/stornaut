import SwiftUI

struct SettingsPageProbe: NSViewRepresentable {
    let identifier: String

    func makeNSView(context: Context) -> NSView {
        makeView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.setAccessibilityIdentifier(identifier)
    }

    private func makeView() -> NSView {
        let view = NSView(frame: .zero)
        view.setAccessibilityElement(true)
        view.setAccessibilityIdentifier(identifier)
        view.setAccessibilityRole(.group)
        return view
    }
}

struct SettingsPageHeader: View {
    let titleKey: String
    let messageKey: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(titleKey))
                    .font(.title2.weight(.semibold))
                Text(LocalizedStringKey(messageKey))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
    }
}

struct SettingsStatusRow: View {
    let titleKey: String
    let valueKey: String
    let messageKey: String?
    let systemImage: String
    let role: SemanticStatusRole

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(role.color)
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(LocalizedStringKey(titleKey))
                        .font(.callout.weight(.medium))
                    Spacer()
                    Text(LocalizedStringKey(valueKey))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(role.color)
                }
                if let messageKey {
                    Text(LocalizedStringKey(messageKey))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct SettingsPolicyRow: View {
    let titleKey: String
    let value: String
    let messageKey: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(LocalizedStringKey(titleKey))
                        .font(.callout.weight(.medium))
                    Spacer()
                    Text(value)
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text(LocalizedStringKey(messageKey))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
