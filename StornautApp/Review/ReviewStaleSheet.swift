import SwiftUI

struct ReviewStaleSheet: View {
    let model: ReviewStaleModel
    let refresh: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(
                "review.stale.title",
                systemImage: "exclamationmark.triangle"
            )
            .font(.title2.weight(.semibold))
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("review.stale")

            Text("review.stale.message")
                .foregroundStyle(.secondary)

            if !model.affectedItemNames.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("review.stale.affected")
                        .font(.headline)
                    ForEach(model.affectedItemNames, id: \.self) { name in
                        Label(name, systemImage: "circle.fill")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("review.stale.reasons")
                    .font(.headline)
                ForEach(
                    model.reasonGroups.sorted {
                        $0.rawValue < $1.rawValue
                    },
                    id: \.rawValue
                ) { reason in
                    Label(
                        LocalizedStringKey(
                            "review.stale.reason.\(reason.rawValue)"
                        ),
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
            }

            HStack {
                Spacer()
                Button("review.action.cancel", action: cancel)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("review.stale.cancel")
                Button(
                    "review.action.refreshAffected",
                    action: refresh
                )
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("review.stale.refresh")
            }
        }
        .padding(24)
        .frame(width: 500)
    }
}
