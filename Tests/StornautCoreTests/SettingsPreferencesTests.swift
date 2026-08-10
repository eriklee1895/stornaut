import Foundation
import Testing
@testable import StornautCore

@Test
func settingsPreferencesAreClosedBoundedAndDeterministic() throws {
    let defaults = SettingsPreferences.defaults

    #expect(defaults.language == .english)
    #expect(defaults.appearance == .system)
    #expect(defaults.primaryRoot == nil)
    #expect(defaults.exclusions.isEmpty)
    #expect(defaults.investigationBudget == .balanced)

    let normalized = try SettingsPreferences(
        language: .simplifiedChinese,
        appearance: .dark,
        primaryRoot: nil,
        exclusions: [
            ScanExclusion(validating: "Projects/App/DerivedData"),
            ScanExclusion(validating: "Library/Caches"),
            ScanExclusion(validating: "Library/Caches/npm"),
            ScanExclusion(validating: "Library/Caches"),
        ],
        investigationBudget: .focused
    )

    #expect(normalized.exclusions.map(\.rawValue) == [
        "Library/Caches",
        "Projects/App/DerivedData",
    ])
    #expect(
        try ScanExclusion(validating: "Library/Caches")
            .contains("library/caches/npm", caseSensitive: false)
    )
    #expect(
        try ScanExclusion(validating: "Library/Caches")
            .contains("library/caches/npm", caseSensitive: true) == false
    )
    #expect(throws: SettingsPreferencesError.invalidExclusion) {
        _ = try ScanExclusion(validating: "../outside")
    }
    #expect(throws: SettingsPreferencesError.invalidExclusion) {
        _ = try ScanExclusion(validating: "/absolute")
    }
    #expect(throws: SettingsPreferencesError.tooManyExclusions) {
        _ = try SettingsPreferences(
            exclusions: (0...SettingsPreferences.maximumExclusionCount).map {
                try ScanExclusion(validating: "excluded-\($0)")
            }
        )
    }
}

@Test
func settingsPreferenceStoreRoundTripsAndRejectsFutureOrOversizedPayloads()
    async throws
{
    let root = try EvidenceStoreTestSupport.temporaryDirectory(
        "settings-preferences"
    )
    defer { try? FileManager.default.removeItem(at: root) }
    let configuration = try EvidenceStoreTestSupport.makeFileConfiguration(
        root: root
    )
    let store = try SettingsPreferencesStore(
        configuration: configuration
    )
    let value = try SettingsPreferences(
        language: .simplifiedChinese,
        appearance: .light,
        exclusions: [
            ScanExclusion(validating: "Library/Caches"),
        ],
        investigationBudget: .thorough
    )

    #expect(try await store.load() == .defaults)
    try await store.save(value)
    #expect(try await store.load() == value)
    let fileMode = try settingsFileMode(
        configuration.settingsPreferencesURL
    )
    #expect(fileMode == 0o600)

    try await store._testReplacePayload(
        Data(
            """
            {"schemaVersion":999,"language":"english","appearance":"system",\
            "primaryRoot":null,"exclusions":[],"investigationBudget":"balanced"}
            """.utf8
        )
    )
    await #expect(throws: SettingsPreferencesError.unsupportedSchema) {
        _ = try await store.load()
    }

    try await store._testReplacePayload(
        Data(
            """
            {"schemaVersion":1,"language":"english","appearance":"system",\
            "primaryRoot":null,"exclusions":[],"investigationBudget":"balanced",\
            "unexpected":true}
            """.utf8
        )
    )
    await #expect(throws: SettingsPreferencesError.invalidPayload) {
        _ = try await store.load()
    }

    try await store._testReplacePayload(
        Data(
            repeating: 0x41,
            count: SettingsPreferencesStore.maximumPayloadBytes + 1
        )
    )
    await #expect(throws: SettingsPreferencesError.payloadTooLarge) {
        _ = try await store.load()
    }
}

@Test
func primaryRootBookmarkResolvesExactTemporaryDirectory() throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "stornaut-settings-root-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: false
    )
    defer { try? FileManager.default.removeItem(at: root) }

    let bookmark = try SettingsPrimaryRoot.bookmark(for: root)
    let resolved = SettingsPrimaryRoot.resolve(
        bookmark,
        fallbackURL: FileManager.default.homeDirectoryForCurrentUser
    )
    let inspected = SettingsPrimaryRoot.resolve(
        bookmark,
        fallbackURL: FileManager.default.homeDirectoryForCurrentUser,
        acquireAccess: false
    )

    #expect(resolved.status == .available)
    #expect(
        resolved.rootURL.standardizedFileURL.path
            == root.standardizedFileURL.path
    )
    #expect(resolved.accessLease != nil)
    #expect(inspected.status == .available)
    #expect(inspected.rootURL == resolved.rootURL)
    #expect(inspected.accessLease == nil)
}

private func settingsFileMode(_ url: URL) throws -> mode_t {
    var information = stat()
    guard lstat(url.path, &information) == 0 else {
        throw CocoaError(.fileReadUnknown)
    }
    return information.st_mode & 0o777
}
