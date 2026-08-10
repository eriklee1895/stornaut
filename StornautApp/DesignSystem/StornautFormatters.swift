import Foundation
import StornautCore

struct StornautByteFormatter: Sendable {
    private let locale: Locale

    init(locale: Locale = .autoupdatingCurrent) {
        self.locale = locale
    }

    func string(for bytes: ByteCount?) -> String {
        guard let bytes else {
            return "—"
        }
        guard bytes.value != 0 else {
            return "0 B"
        }
        return Int64(bytes.value).formatted(
            ByteCountFormatStyle(
                style: .file,
                allowedUnits: .all,
                spellsOutZero: false,
                includesActualByteCount: false
            ).locale(locale)
        )
    }

    func accessibilityString(for bytes: ByteCount?) -> String {
        guard let bytes else {
            return localizedUnknown()
        }
        guard bytes.value != 0 else {
            return Int64(0).formatted(
                .byteCount(
                    style: .file,
                    allowedUnits: .bytes,
                    spellsOutZero: false,
                    includesActualByteCount: false
                ).locale(locale)
            )
        }
        return Int64(bytes.value).formatted(
            ByteCountFormatStyle(
                style: .file,
                allowedUnits: .all,
                spellsOutZero: false,
                includesActualByteCount: true
            ).locale(locale)
        )
    }

    private func localizedUnknown() -> String {
        let appBundle = Bundle(identifier: "com.eriklee.stornaut") ?? .main
        let languageCode = locale.language.languageCode?.identifier ?? "en"
        let localization = languageCode == "zh" ? "zh-Hans" : "en"
        guard let path = appBundle.path(
            forResource: localization,
            ofType: "lproj"
        ),
              let bundle = Bundle(path: path)
        else {
            return appBundle.localizedString(
                forKey: "status.unknown",
                value: "Unknown",
                table: nil
            )
        }
        return bundle.localizedString(
            forKey: "status.unknown",
            value: "Unknown",
            table: nil
        )
    }
}
