import SwiftUI

struct ReviewConfirmationSheet: View {
    let model: ReviewConfirmationModel
    let cancel: () -> Void
    let confirm: () -> Void

    private let byteFormatter = StornautByteFormatter()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(
                "review.confirmation.title",
                systemImage: "trash"
            )
            .font(.title2.weight(.semibold))
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("review.confirmation")

            Text("review.confirmation.message")
                .foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 12) {
                row(
                    "review.confirmation.items",
                    value: model.itemCount.formatted()
                )
                row(
                    "review.confirmation.action",
                    valueKey: "review.action.moveToTrash"
                )
                row(
                    "review.confirmation.estimatedTrash",
                    value: byteFormatter.string(
                        for: model.estimatedTrashBytes
                    )
                )
                row(
                    "review.confirmation.reviewItems",
                    value: model.selectedReviewCount.formatted()
                )
                row(
                    "review.confirmation.permanentRelease",
                    valueKey: "review.value.none"
                )
            }

            Label(
                LocalizedStringKey(model.recoveryCaveatKey.rawValue),
                systemImage: "arrow.uturn.backward.circle"
            )
            .font(.callout)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.accentColor.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 10)
            )

            if !model.canConfirmExecution {
                Label(
                    "review.execution.writeDisabled",
                    systemImage: "lock.shield"
                )
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(
                    "review.confirmation.writeDisabled"
                )
            }

            HStack {
                Spacer()
                Button("review.action.cancel", action: cancel)
                    .keyboardShortcut(.cancelAction)
                Button("review.confirmation.confirm", action: confirm)
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.canConfirmExecution)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier(
                        "review.confirmation.confirm"
                    )
            }
        }
        .padding(24)
        .frame(width: 500)
    }

    private func row(
        _ key: String,
        value: String? = nil,
        valueKey: String? = nil
    ) -> some View {
        GridRow {
            Text(LocalizedStringKey(key))
                .foregroundStyle(.secondary)
            if let valueKey {
                Text(LocalizedStringKey(valueKey))
                    .fontWeight(.medium)
            } else {
                Text(value ?? "—")
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
        }
    }
}
