import Foundation
import Testing
@testable import StornautApp

@Test
func appDestinationsMatchTheApprovedNavigation() {
    #expect(AppDestination.allCases.map(\.rawValue) == [
        "overview",
        "scan",
        "investigations",
        "history",
    ])
}

@Test
func appDestinationLocalizationKeysResolve() {
    let bundle = Bundle(identifier: "com.eriklee.stornaut")

    #expect(bundle != nil)

    for destination in AppDestination.allCases {
        let localized = bundle?.localizedString(
            forKey: destination.localizationKey,
            value: nil,
            table: nil
        )

        #expect(localized != nil)
        #expect(localized != destination.localizationKey)
    }
}
