import Darwin
import Foundation

public enum StoreApplicationID: Int32, Codable, Sendable, Equatable {
    case evidence = 0x5354_4E45
    case localKnowledge = 0x5354_4E4B
}

public struct LocalStoreConfiguration: Sendable, Equatable {
    public let applicationSupportBaseURL: URL?
    public let cachesBaseURL: URL?

    public static let memory = LocalStoreConfiguration()

    public init(
        applicationSupportBaseURL: URL,
        cachesBaseURL: URL
    ) throws {
        guard applicationSupportBaseURL.isFileURL,
              cachesBaseURL.isFileURL,
              applicationSupportBaseURL.path.hasPrefix("/"),
              cachesBaseURL.path.hasPrefix("/")
        else {
            throw EvidenceStoreError.unsafeStoragePath
        }
        self.applicationSupportBaseURL = try canonicalizingExistingAncestor(
            applicationSupportBaseURL
        )
        self.cachesBaseURL = try canonicalizingExistingAncestor(
            cachesBaseURL
        )
    }

    private init() {
        applicationSupportBaseURL = nil
        cachesBaseURL = nil
    }

    public var isMemory: Bool {
        applicationSupportBaseURL == nil
    }

    public var supportDirectoryURL: URL {
        guard let applicationSupportBaseURL else {
            return URL(filePath: ":memory:")
        }
        return applicationSupportBaseURL.appending(
            path: "com.eriklee.stornaut",
            directoryHint: .isDirectory
        )
    }

    public var cacheDirectoryURL: URL {
        guard let cachesBaseURL else {
            return URL(filePath: ":memory:")
        }
        return cachesBaseURL.appending(
            path: "com.eriklee.stornaut",
            directoryHint: .isDirectory
        )
    }

    public var evidenceDatabaseURL: URL {
        isMemory
            ? URL(filePath: ":memory:")
            : supportDirectoryURL.appending(path: "Evidence.sqlite")
    }

    public var localKnowledgeDatabaseURL: URL {
        isMemory
            ? URL(filePath: ":memory:")
            : supportDirectoryURL.appending(path: "LocalKnowledge.sqlite")
    }

    public static func production() throws -> Self {
        try Self(
            applicationSupportBaseURL: .applicationSupportDirectory,
            cachesBaseURL: .cachesDirectory
        )
    }

}

func canonicalizingExistingAncestor(_ url: URL) throws -> URL {
    var ancestor = url.standardizedFileURL
    var suffix: [String] = []
    while !FileManager.default.fileExists(atPath: ancestor.path) {
        guard ancestor.path != "/" else {
            throw EvidenceStoreError.unsafeStoragePath
        }
        suffix.append(ancestor.lastPathComponent)
        ancestor.deleteLastPathComponent()
    }
    guard let resolvedPointer = realpath(ancestor.path, nil) else {
        throw EvidenceStoreError.unsafeStoragePath
    }
    defer { free(resolvedPointer) }
    var result = URL(
        filePath: String(cString: resolvedPointer),
        directoryHint: .isDirectory
    )
    for component in suffix.reversed() {
        result.append(path: component)
    }
    return result
}

enum LocalStorePathPolicy {
    static func prepare(
        configuration: LocalStoreConfiguration,
        databaseURL: URL
    ) throws {
        guard !configuration.isMemory else {
            return
        }
        try ensureBaseDirectory(configuration.applicationSupportBaseURL!)
        try ensurePrivateDirectory(configuration.supportDirectoryURL)
        try ensureBaseDirectory(configuration.cachesBaseURL!)
        try ensurePrivateDirectory(configuration.cacheDirectoryURL)
        try ensurePrivateDatabaseFile(databaseURL)
    }

    static func finalizeDatabase(
        _ databaseURL: URL,
        isMemory: Bool,
        excludeFromBackup: Bool
    ) throws {
        guard !isMemory else {
            return
        }
        try ensureSafeItem(
            databaseURL,
            requiredKind: S_IFREG,
            mode: 0o600
        )
        var values = URLResourceValues()
        values.isExcludedFromBackup = excludeFromBackup
        var mutableDatabaseURL = databaseURL
        try mutableDatabaseURL.setResourceValues(values)
    }

    static func createPrivateFileExclusive(_ url: URL) throws {
        let descriptor = open(
            url.path,
            O_CREAT | O_EXCL | O_RDWR | O_CLOEXEC | O_NOFOLLOW,
            0o600
        )
        guard descriptor >= 0 else {
            throw EvidenceStoreError.unsafeStoragePath
        }
        defer { close(descriptor) }
        var information = stat()
        guard fstat(descriptor, &information) == 0,
              information.st_mode & S_IFMT == S_IFREG,
              information.st_uid == geteuid(),
              fchmod(descriptor, 0o600) == 0
        else {
            throw EvidenceStoreError.unsafeStoragePath
        }
    }

    private static func ensurePrivateDirectory(_ url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700]
            )
        }
        try ensureSafeItem(url, requiredKind: S_IFDIR, mode: 0o700)
    }

    private static func ensureBaseDirectory(_ url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700]
            )
        }
        let descriptor = open(
            url.path,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard descriptor >= 0 else {
            throw EvidenceStoreError.unsafeStoragePath
        }
        defer { close(descriptor) }
        var information = stat()
        guard fstat(descriptor, &information) == 0,
              information.st_mode & S_IFMT == S_IFDIR,
              information.st_uid == geteuid()
        else {
            throw EvidenceStoreError.unsafeStoragePath
        }
    }

    private static func ensurePrivateDatabaseFile(_ url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try createPrivateFileExclusive(url)
        }
        try ensureSafeItem(url, requiredKind: S_IFREG, mode: 0o600)
    }

    private static func ensureSafeItem(
        _ url: URL,
        requiredKind: mode_t,
        mode: mode_t
    ) throws {
        let flags = requiredKind == S_IFDIR
            ? O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
            : O_RDWR | O_CLOEXEC | O_NOFOLLOW
        let descriptor = open(url.path, flags)
        guard descriptor >= 0 else {
            throw EvidenceStoreError.unsafeStoragePath
        }
        defer { close(descriptor) }
        var information = stat()
        guard fstat(descriptor, &information) == 0,
              information.st_mode & S_IFMT == requiredKind,
              information.st_uid == geteuid(),
              fchmod(descriptor, mode) == 0
        else {
            throw EvidenceStoreError.unsafeStoragePath
        }
    }
}
