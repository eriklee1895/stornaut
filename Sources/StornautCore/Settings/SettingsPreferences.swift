import Darwin
import Foundation

public enum SettingsLanguage: String, Codable, Sendable, CaseIterable {
    case english
    case simplifiedChinese
}

public enum SettingsAppearance: String, Codable, Sendable, CaseIterable {
    case system
    case light
    case dark
}

public enum InvestigationBudgetPreset:
    String,
    Codable,
    Sendable,
    CaseIterable
{
    case focused
    case balanced
    case thorough
}

public enum SettingsPreferencesError: Error, Sendable, Equatable {
    case invalidExclusion
    case tooManyExclusions
    case invalidBookmark
    case unsupportedSchema
    case payloadTooLarge
    case unsafeStorage
    case invalidPayload
}

public struct ScanExclusion:
    RawRepresentable,
    Codable,
    Sendable,
    Hashable
{
    public let rawValue: String

    public init?(rawValue: String) {
        guard let value = try? Self.normalized(rawValue) else {
            return nil
        }
        self.rawValue = value
    }

    public init(validating rawValue: String) throws {
        self.rawValue = try Self.normalized(rawValue)
    }

    public init(from decoder: Decoder) throws {
        try self.init(
            validating: decoder.singleValueContainer().decode(String.self)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    func contains(
        _ relativePath: String,
        caseSensitive: Bool = true
    ) -> Bool {
        let candidate = comparisonPath(
            relativePath,
            caseSensitive: caseSensitive
        )
        let exclusion = comparisonPath(
            rawValue,
            caseSensitive: caseSensitive
        )
        return candidate == exclusion
            || candidate.hasPrefix(exclusion + "/")
    }

    public init(
        selectedURL: URL,
        relativeTo rootURL: URL
    ) throws {
        let root = rootURL.standardizedFileURL
            .resolvingSymlinksInPath()
        let selected = selectedURL.standardizedFileURL
            .resolvingSymlinksInPath()
        guard root.isFileURL,
              selected.isFileURL,
              selected.path != root.path
        else {
            throw SettingsPreferencesError.invalidExclusion
        }
        let caseSensitive = (
            try? root.resourceValues(
                forKeys: [.volumeSupportsCaseSensitiveNamesKey]
            ).volumeSupportsCaseSensitiveNames
        ) ?? true
        let rootComponents = comparablePathComponents(
            root,
            caseSensitive: caseSensitive
        )
        let selectedComponents = comparablePathComponents(
            selected,
            caseSensitive: caseSensitive
        )
        guard selectedComponents.count > rootComponents.count,
              zip(rootComponents, selectedComponents).allSatisfy(==)
        else {
            throw SettingsPreferencesError.invalidExclusion
        }
        let originalComponents = selected.pathComponents.dropFirst(
            root.pathComponents.count
        )
        try self.init(
            validating: originalComponents.joined(separator: "/")
        )
    }

    private static func normalized(_ rawValue: String) throws -> String {
        guard !rawValue.isEmpty,
              rawValue.utf8.count <= 16_384,
              !rawValue.hasPrefix("/"),
              !rawValue.contains("\0"),
              !rawValue.unicodeScalars.contains(where: {
                  CharacterSet.newlines.contains($0)
              })
        else {
            throw SettingsPreferencesError.invalidExclusion
        }
        let components = rawValue.split(
            separator: "/",
            omittingEmptySubsequences: false
        )
        guard !components.isEmpty,
              components.allSatisfy({
                  !$0.isEmpty && $0 != "." && $0 != ".."
              })
        else {
            throw SettingsPreferencesError.invalidExclusion
        }
        return components.joined(separator: "/")
            .precomposedStringWithCanonicalMapping
    }
}

private func comparisonPath(
    _ path: String,
    caseSensitive: Bool
) -> String {
    let normalized = path.precomposedStringWithCanonicalMapping
    return caseSensitive
        ? normalized
        : normalized.folding(
            options: [.caseInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
}

public struct SettingsPrimaryRootBookmark:
    Codable,
    Sendable,
    Equatable
{
    public let data: Data
    public let displayPath: PersistedPath

    public init(data: Data, displayPath: PersistedPath) throws {
        guard !data.isEmpty,
              data.count <= SettingsPreferences.maximumBookmarkBytes,
              displayPath.rawValue.hasPrefix("/")
        else {
            throw SettingsPreferencesError.invalidBookmark
        }
        self.data = data
        self.displayPath = displayPath
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            data: container.decode(Data.self, forKey: .data),
            displayPath: container.decode(
                PersistedPath.self,
                forKey: .displayPath
            )
        )
    }

}

public struct SettingsPreferences: Codable, Sendable, Equatable {
    public static let schemaVersion = 1
    public static let maximumExclusionCount = 64
    public static let maximumBookmarkBytes = 64 * 1_024

    public let schemaVersion: Int
    public let language: SettingsLanguage
    public let appearance: SettingsAppearance
    public let primaryRoot: SettingsPrimaryRootBookmark?
    public let exclusions: [ScanExclusion]
    public let investigationBudget: InvestigationBudgetPreset

    public static let defaults = try! SettingsPreferences()

    public init(
        language: SettingsLanguage = .english,
        appearance: SettingsAppearance = .system,
        primaryRoot: SettingsPrimaryRootBookmark? = nil,
        exclusions: [ScanExclusion] = [],
        investigationBudget: InvestigationBudgetPreset = .balanced
    ) throws {
        guard exclusions.count <= Self.maximumExclusionCount else {
            throw SettingsPreferencesError.tooManyExclusions
        }
        var normalized: [ScanExclusion] = []
        for candidate in exclusions.sorted(by: {
            $0.rawValue < $1.rawValue
        }) {
            guard !normalized.contains(where: {
                $0.contains(candidate.rawValue)
            }) else {
                continue
            }
            normalized.append(candidate)
        }
        self.schemaVersion = Self.schemaVersion
        self.language = language
        self.appearance = appearance
        self.primaryRoot = primaryRoot
        self.exclusions = normalized
        self.investigationBudget = investigationBudget
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard try container.decode(Int.self, forKey: .schemaVersion)
            == Self.schemaVersion
        else {
            throw SettingsPreferencesError.unsupportedSchema
        }
        try self.init(
            language: container.decode(
                SettingsLanguage.self,
                forKey: .language
            ),
            appearance: container.decode(
                SettingsAppearance.self,
                forKey: .appearance
            ),
            primaryRoot: container.decodeIfPresent(
                SettingsPrimaryRootBookmark.self,
                forKey: .primaryRoot
            ),
            exclusions: container.decode(
                [ScanExclusion].self,
                forKey: .exclusions
            ),
            investigationBudget: container.decode(
                InvestigationBudgetPreset.self,
                forKey: .investigationBudget
            )
        )
    }

    public func replacing(
        language: SettingsLanguage? = nil,
        appearance: SettingsAppearance? = nil,
        primaryRoot: SettingsPrimaryRootBookmark?? = nil,
        exclusions: [ScanExclusion]? = nil,
        investigationBudget: InvestigationBudgetPreset? = nil
    ) throws -> SettingsPreferences {
        try SettingsPreferences(
            language: language ?? self.language,
            appearance: appearance ?? self.appearance,
            primaryRoot: primaryRoot ?? self.primaryRoot,
            exclusions: exclusions ?? self.exclusions,
            investigationBudget:
                investigationBudget ?? self.investigationBudget
        )
    }
}

public enum SettingsPrimaryRootAvailability:
    String,
    Sendable,
    Equatable
{
    case available
    case stale
    case unavailable
    case fallbackHome
}

public final class SettingsPrimaryRootAccessLease:
    @unchecked Sendable
{
    private let url: URL
    private let didStart: Bool

    init(url: URL, didStart: Bool) {
        self.url = url
        self.didStart = didStart
    }

    deinit {
        if didStart {
            url.stopAccessingSecurityScopedResource()
        }
    }
}

public struct ResolvedSettingsPrimaryRoot: Sendable {
    public let rootURL: URL
    public let status: SettingsPrimaryRootAvailability
    public let accessLease: SettingsPrimaryRootAccessLease?
}

public enum SettingsPrimaryRoot {
    public static func bookmark(
        for url: URL
    ) throws -> SettingsPrimaryRootBookmark {
        let canonical = url.standardizedFileURL
            .resolvingSymlinksInPath()
        guard canonical.isFileURL,
              canonical.path.hasPrefix("/"),
              let values = try? canonical.resourceValues(
                  forKeys: [.isDirectoryKey]
              ),
              values.isDirectory == true
        else {
            throw SettingsPreferencesError.invalidBookmark
        }
        let data = try canonical.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: [.isDirectoryKey],
            relativeTo: nil
        )
        return try SettingsPrimaryRootBookmark(
            data: data,
            displayPath: PersistedPath(validating: canonical.path)
        )
    }

    public static func resolve(
        _ bookmark: SettingsPrimaryRootBookmark?,
        fallbackURL: URL,
        acquireAccess: Bool = true
    ) -> ResolvedSettingsPrimaryRoot {
        let fallback = fallbackURL.standardizedFileURL
            .resolvingSymlinksInPath()
        guard let bookmark else {
            return ResolvedSettingsPrimaryRoot(
                rootURL: fallback,
                status: .fallbackHome,
                accessLease: nil
            )
        }
        var stale = false
        guard let resolved = try? URL(
            resolvingBookmarkData: bookmark.data,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else {
            return ResolvedSettingsPrimaryRoot(
                rootURL: fallback,
                status: .unavailable,
                accessLease: nil
            )
        }
        let canonical = resolved.standardizedFileURL
            .resolvingSymlinksInPath()
        guard canonical.path == bookmark.displayPath.rawValue,
              let values = try? canonical.resourceValues(
                  forKeys: [.isDirectoryKey]
              ),
              values.isDirectory == true
        else {
            return ResolvedSettingsPrimaryRoot(
                rootURL: fallback,
                status: .unavailable,
                accessLease: nil
            )
        }
        guard !stale else {
            return ResolvedSettingsPrimaryRoot(
                rootURL: fallback,
                status: .stale,
                accessLease: nil
            )
        }
        let lease: SettingsPrimaryRootAccessLease?
        if acquireAccess {
            let didStart = canonical.startAccessingSecurityScopedResource()
            lease = SettingsPrimaryRootAccessLease(
                url: canonical,
                didStart: didStart
            )
        } else {
            lease = nil
        }
        return ResolvedSettingsPrimaryRoot(
            rootURL: canonical,
            status: .available,
            accessLease: lease
        )
    }
}

public actor SettingsPreferencesStore {
    public static let maximumPayloadBytes = 256 * 1_024

    private let fileURL: URL?
    private var memoryPayload: Data?

    public init(configuration: LocalStoreConfiguration) throws {
        guard !configuration.isMemory else {
            fileURL = nil
            return
        }
        let url = configuration.settingsPreferencesURL
        try LocalStorePathPolicy.preparePrivateFile(
            configuration: configuration,
            fileURL: url,
            excludeFromBackup: false
        )
        fileURL = url
    }

    public func load() throws -> SettingsPreferences {
        let payload: Data?
        if let fileURL {
            payload = try Data(contentsOf: fileURL)
        } else {
            payload = memoryPayload
        }
        guard let payload, !payload.isEmpty else {
            return .defaults
        }
        guard payload.count <= Self.maximumPayloadBytes else {
            throw SettingsPreferencesError.payloadTooLarge
        }
        let requiredKeys: Set<String> = [
            "schemaVersion",
            "language",
            "appearance",
            "exclusions",
            "investigationBudget",
        ]
        let allowedKeys = requiredKeys.union(["primaryRoot"])
        guard let object = try? JSONSerialization.jsonObject(
            with: payload
        ) as? [String: Any],
              requiredKeys.isSubset(of: object.keys),
              Set(object.keys).isSubset(of: allowedKeys)
        else {
            throw SettingsPreferencesError.invalidPayload
        }
        return try DomainJSON.decode(
            SettingsPreferences.self,
            from: payload
        )
    }

    public func save(_ preferences: SettingsPreferences) throws {
        let payload = try DomainJSON.encode(preferences)
        guard payload.count <= Self.maximumPayloadBytes else {
            throw SettingsPreferencesError.payloadTooLarge
        }
        guard let fileURL else {
            memoryPayload = payload
            return
        }
        try writeAtomically(payload, to: fileURL)
    }

    func _testReplacePayload(_ payload: Data) throws {
        if let fileURL {
            try writeAtomically(payload, to: fileURL)
        } else {
            memoryPayload = payload
        }
    }
}

private func writeAtomically(_ data: Data, to destination: URL) throws {
    let temporary = destination.deletingLastPathComponent().appending(
        path: ".stornaut-settings-\(UUID().uuidString).tmp"
    )
    defer { try? FileManager.default.removeItem(at: temporary) }
    try LocalStorePathPolicy.createPrivateFileExclusive(temporary)
    let descriptor = open(
        temporary.path,
        O_WRONLY | O_TRUNC | O_CLOEXEC | O_NOFOLLOW
    )
    guard descriptor >= 0 else {
        throw SettingsPreferencesError.unsafeStorage
    }
    defer { close(descriptor) }
    do {
        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let count = write(
                    descriptor,
                    bytes.baseAddress!.advanced(by: offset),
                    bytes.count - offset
                )
                guard count > 0 else {
                    throw SettingsPreferencesError.unsafeStorage
                }
                offset += count
            }
        }
        guard fsync(descriptor) == 0 else {
            throw SettingsPreferencesError.unsafeStorage
        }
        guard rename(temporary.path, destination.path) == 0 else {
            throw SettingsPreferencesError.unsafeStorage
        }
    } catch {
        throw error
    }
}

private func comparablePathComponents(
    _ url: URL,
    caseSensitive: Bool
) -> [String] {
    url.pathComponents.map {
        let normalized = $0.precomposedStringWithCanonicalMapping
        return caseSensitive
            ? normalized
            : normalized.folding(
                options: [.caseInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
    }
}
