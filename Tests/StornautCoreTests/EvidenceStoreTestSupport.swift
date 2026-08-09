import Foundation
@testable import StornautCore

enum EvidenceStoreTestSupport {
    static func fixtureData(
        directory: String = "Domain",
        name: String
    ) throws -> Data {
        try Data(
            contentsOf: repositoryRoot
                .appending(path: "Tests/Fixtures/\(directory)/\(name).json")
        )
    }

    static func fixture<T: Decodable>(
        _ type: T.Type,
        name: String
    ) throws -> T {
        try DomainJSON.decode(type, from: fixtureData(name: name))
    }

    static func temporaryDirectory(_ suffix: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-store-\(suffix)-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }

    static func makeFileConfiguration(
        root: URL
    ) throws -> LocalStoreConfiguration {
        try LocalStoreConfiguration(
            applicationSupportBaseURL: root.appending(
                path: "Application Support",
                directoryHint: .isDirectory
            ),
            cachesBaseURL: root.appending(
                path: "Caches",
                directoryHint: .isDirectory
            )
        )
    }

    static func runSQLite(
        databaseURL: URL,
        sql: String
    ) throws -> String {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/sqlite3")
        process.arguments = [databaseURL.path, sql]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw StoreTestError.sqlite(
                String(
                    decoding: errors.fileHandleForReading.readDataToEndOfFile(),
                    as: UTF8.self
                )
            )
        }
        return String(
            decoding: output.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var repositoryRoot: URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

enum StoreTestError: Error {
    case sqlite(String)
}
