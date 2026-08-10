import Foundation
import StornautCore
import Testing
@testable import StornautApp

@Test
func byteFormattingDistinguishesUnknownMeasuredZeroAndValues() {
    let formatter = StornautByteFormatter(
        locale: Locale(identifier: "en_US")
    )

    #expect(formatter.string(for: nil) == "—")
    #expect(formatter.accessibilityString(for: nil) == "Unknown")
    #expect(formatter.string(for: ByteCount(0)) == "0 B")
    #expect(formatter.accessibilityString(for: ByteCount(0)) == "0 bytes")
    #expect(formatter.string(for: ByteCount(1_500)) == "2 kB")
    #expect(
        StornautByteFormatter(
            locale: Locale(identifier: "fr_FR")
        ).accessibilityString(for: nil) == "Unknown"
    )
}

@Test
func everyDispositionHasLocalizedSemanticMetadata() {
    let descriptors = ReclaimDisposition.allCases.map {
        SemanticDisposition($0)
    }

    #expect(descriptors.map(\.disposition) == ReclaimDisposition.allCases)
    #expect(Set(descriptors.map(\.localizationKey)).count == 4)
    #expect(Set(descriptors.map(\.systemImage)).count == 4)
    #expect(descriptors.allSatisfy { !$0.accessibilityLocalizationKey.isEmpty })
    #expect(
        descriptors.first {
            $0.disposition == .readyToReclaim
        }?.role == .positive
    )
    #expect(
        descriptors.first {
            $0.disposition == .protected
        }?.role == .protected
    )
}

@Test
func everyAppPhaseHasSemanticTextIconAndRole() {
    let descriptors = AppPagePhase.allCases.map(SemanticAppPhase.init)

    #expect(descriptors.map(\.phase) == AppPagePhase.allCases)
    #expect(Set(descriptors.map(\.localizationKey)).count == 8)
    #expect(Set(descriptors.map(\.systemImage)).count == 8)
    #expect(
        descriptors.first { $0.phase == .limitedPermission }?.role
            == .limited
    )
    #expect(descriptors.first { $0.phase == .error }?.role == .failed)
}

@Test
func coverageBadgeNeverTurnsUnknownIntoZero() {
    let limited = CoverageBadgeModel(
        gapCount: 2,
        unmeasurableBytes: nil
    )
    let complete = CoverageBadgeModel(
        gapCount: 0,
        unmeasurableBytes: ByteCount(0)
    )

    #expect(limited.state == .limited)
    #expect(limited.value == nil)
    #expect(limited.localizationKey == "coverage.limited")
    #expect(complete.state == .complete)
    #expect(complete.value == ByteCount(0))
    #expect(complete.localizationKey == "coverage.complete")
    #expect(
        CoverageBadgeModel(
            gapCount: -4,
            unmeasurableBytes: ByteCount(0)
        ).gapCount == 0
    )
    #expect(
        CoverageBadgeModel(
            gapCount: 0,
            unmeasurableBytes: ByteCount(1)
        ).state == .limited
    )
}

@Test
func retentionBadgeUsesClosedStatesAndStableBoundaries() {
    let now = Date(timeIntervalSince1970: 1_786_320_000)

    #expect(
        RetentionBadgeModel(
            expiresAt: now.addingTimeInterval(-1),
            now: now
        ).state == .expired
    )
    #expect(
        RetentionBadgeModel(
            expiresAt: now.addingTimeInterval(-1),
            now: now
        ).role == .neutral
    )
    #expect(
        RetentionBadgeModel(
            expiresAt: now.addingTimeInterval(86_400),
            now: now
        ).state == .expiringSoon
    )
    #expect(
        RetentionBadgeModel(
            expiresAt: now.addingTimeInterval(8 * 86_400),
            now: now
        ).state == .retained
    )
}

@Test
func recoveryStateAllowsOnlySafeClosedIntents() {
    let model = RecoveryStateModel(
        titleKey: "recovery.partial.title",
        messageKey: "recovery.partial.message",
        systemImage: "exclamationmark.triangle",
        role: .limited,
        primaryIntent: .retryLatestSnapshot,
        secondaryIntent: .reviewPermissions
    )

    #expect(model.primaryIntent == .retryLatestSnapshot)
    #expect(model.secondaryIntent == .reviewPermissions)
    #expect(SafeRecoveryIntent.allCases.contains(model.primaryIntent!))
    #expect(SafeRecoveryIntent.allCases.contains(model.secondaryIntent!))
}

@Test
func designSystemLocalizationKeysResolveInBothLanguages() throws {
    let bundle = try #require(Bundle(identifier: "com.eriklee.stornaut"))
    let keys = Set(
        ReclaimDisposition.allCases.flatMap {
            let semantic = SemanticDisposition($0)
            return [
                semantic.localizationKey,
                semantic.accessibilityLocalizationKey,
            ]
        }
            + AppPageStateLocalizationKeys.all
            + AppPagePhase.allCases.map {
                SemanticAppPhase($0).localizationKey
            }
            + SafeRecoveryIntent.allCases.map(\.localizationKey)
            + [
                "coverage.complete",
                "coverage.limited",
                "retention.retained",
                "retention.expiringSoon",
                "retention.expired",
                "recovery.partial.title",
                "recovery.partial.message",
                "empty.snapshot.title",
                "empty.snapshot.message",
                "status.unknown",
            ]
    )

    for language in ["en", "zh-Hans"] {
        let localization = try #require(
            bundle.path(forResource: language, ofType: "lproj")
        )
        let localizedBundle = try #require(Bundle(path: localization))

        for key in keys {
            #expect(
                localizedBundle.localizedString(
                    forKey: key,
                    value: nil,
                    table: nil
                ) != key
            )
        }
    }
}

private enum AppPageStateLocalizationKeys {
    static let all = [
        "app.state.partial",
        "app.state.cancelled",
        "app.state.permission-limited",
        "app.state.snapshot-stale",
        "app.state.store-unavailable",
        "app.state.scan-failed",
    ]
}
