import Foundation
import StornautCore
import Synchronization

enum StornautLocalization {
    private static let language = Mutex(SettingsLanguage.english)

    static func apply(_ value: SettingsLanguage) {
        language.withLock { $0 = value }
    }

    static var currentLanguage: SettingsLanguage {
        language.withLock { $0 }
    }

    static var locale: Locale {
        let selected = currentLanguage
        return Locale(
            identifier: selected == .simplifiedChinese
                ? "zh-Hans"
                : "en"
        )
    }

    static func string(_ key: String) -> String {
        let selected = language.withLock { $0 }
        let name = selected == .simplifiedChinese ? "zh-Hans" : "en"
        let bundle = Bundle(identifier: "com.eriklee.stornaut") ?? .main
        guard let path = bundle.path(
            forResource: name,
            ofType: "lproj"
        ),
              let localized = Bundle(path: path)
        else {
            return bundle.localizedString(
                forKey: key,
                value: key,
                table: nil
            )
        }
        return localized.localizedString(
            forKey: key,
            value: key,
            table: nil
        )
    }
}
