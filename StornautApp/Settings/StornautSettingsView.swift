import SwiftUI

struct StornautSettingsView: View {
    var body: some View {
        Form {
            LabeledContent("settings.language") {
                Text("settings.systemDefault")
                    .foregroundStyle(.secondary)
            }

            LabeledContent("settings.appearance") {
                Text("settings.systemDefault")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
#if DEBUG
        .scrollContentBackground(.hidden)
        .background {
            if let color = LaunchAppearanceOverride.backgroundColor {
                color.ignoresSafeArea()
            }
        }
#endif
        .frame(width: 520, height: 260)
        .navigationTitle("settings.title")
        .accessibilityIdentifier("settings.content")
    }
}
