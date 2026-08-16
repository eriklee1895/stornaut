#if DEBUG
import Darwin
import Foundation

public struct InvestigationRuntimeDiagnosticAppLeaf: Sendable {
    public static let requiredOptIn =
        "I authorize one bounded disposable read-only Stornaut Investigation diagnostic."

    public let nonce: UUID
    public let diagnosticRootPath: String

    public static func prepare(
        configurationData: Data,
        now: Date
    ) throws -> Self {
        guard configurationData.count <= 64 * 1_024 else {
            throw InvestigationRuntimeDiagnosticAppLeafError
                .invalidConfiguration
        }
        let configuration: Configuration
        do {
            configuration = try JSONDecoder().decode(
                Configuration.self,
                from: configurationData
            )
        } catch {
            throw InvestigationRuntimeDiagnosticAppLeafError
                .invalidConfiguration
        }
        try configuration.validate(now: now)
        return Self(
            nonce: configuration.nonce,
            diagnosticRootPath: configuration.diagnosticRootPath
        )
    }
}

public enum InvestigationRuntimeDiagnosticAppLeafError:
    Error,
    Sendable,
    Equatable
{
    case invalidConfiguration
}

private struct Configuration: Decodable {
    let schemaVersion: Int
    let nonce: UUID
    let optIn: String
    let diagnosticRootPath: String
    let sourceRootPath: String
    let supportRootPath: String
    let runtimeRootPath: String
    let reportPath: String
    let storePath: String
    let binding: Binding
    let expectedModel: String
    let expectedProvider: String
    let validBefore: Date
    let maximumWallClockSeconds: Int
    let maximumTurns: Int
    let maximumProbeCalls: Int
    let maximumContextBytes: Int

    init(from decoder: Decoder) throws {
        let container = try strictContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue))
        )
        schemaVersion = try container.decode(
            Int.self,
            forKey: DynamicCodingKey(CodingKeys.schemaVersion.rawValue)
        )
        nonce = try container.decode(
            UUID.self,
            forKey: DynamicCodingKey(CodingKeys.nonce.rawValue)
        )
        optIn = try container.decode(
            String.self,
            forKey: DynamicCodingKey(CodingKeys.optIn.rawValue)
        )
        diagnosticRootPath = try container.decode(
            String.self,
            forKey: DynamicCodingKey(
                CodingKeys.diagnosticRootPath.rawValue
            )
        )
        sourceRootPath = try container.decode(
            String.self,
            forKey: DynamicCodingKey(CodingKeys.sourceRootPath.rawValue)
        )
        supportRootPath = try container.decode(
            String.self,
            forKey: DynamicCodingKey(CodingKeys.supportRootPath.rawValue)
        )
        runtimeRootPath = try container.decode(
            String.self,
            forKey: DynamicCodingKey(CodingKeys.runtimeRootPath.rawValue)
        )
        reportPath = try container.decode(
            String.self,
            forKey: DynamicCodingKey(CodingKeys.reportPath.rawValue)
        )
        storePath = try container.decode(
            String.self,
            forKey: DynamicCodingKey(CodingKeys.storePath.rawValue)
        )
        binding = try container.decode(
            Binding.self,
            forKey: DynamicCodingKey(CodingKeys.binding.rawValue)
        )
        expectedModel = try container.decode(
            String.self,
            forKey: DynamicCodingKey(CodingKeys.expectedModel.rawValue)
        )
        expectedProvider = try container.decode(
            String.self,
            forKey: DynamicCodingKey(CodingKeys.expectedProvider.rawValue)
        )
        validBefore = try container.decode(
            Date.self,
            forKey: DynamicCodingKey(CodingKeys.validBefore.rawValue)
        )
        maximumWallClockSeconds = try container.decode(
            Int.self,
            forKey: DynamicCodingKey(
                CodingKeys.maximumWallClockSeconds.rawValue
            )
        )
        maximumTurns = try container.decode(
            Int.self,
            forKey: DynamicCodingKey(CodingKeys.maximumTurns.rawValue)
        )
        maximumProbeCalls = try container.decode(
            Int.self,
            forKey: DynamicCodingKey(CodingKeys.maximumProbeCalls.rawValue)
        )
        maximumContextBytes = try container.decode(
            Int.self,
            forKey: DynamicCodingKey(CodingKeys.maximumContextBytes.rawValue)
        )
    }

    func validate(now: Date) throws {
        let directoryPaths = [
            diagnosticRootPath,
            sourceRootPath,
            supportRootPath,
            runtimeRootPath,
        ]
        let filePaths = [reportPath, storePath]
        guard
            schemaVersion == 1,
            optIn == InvestigationRuntimeDiagnosticAppLeaf.requiredOptIn,
            binding.isValid,
            expectedModel == "gpt-5.6-luna",
            expectedProvider == "openai",
            validBefore > now,
            validBefore.timeIntervalSince(now) <= 900,
            validBefore.timeIntervalSince1970.isFinite,
            (1...140).contains(maximumWallClockSeconds),
            (1...3).contains(maximumTurns),
            (1...16).contains(maximumProbeCalls),
            (1...1_048_576).contains(maximumContextBytes),
            directoryPaths.allSatisfy(validAbsolutePath),
            filePaths.allSatisfy(validAbsolutePath),
            Set(directoryPaths).count == directoryPaths.count,
            Set(filePaths).count == filePaths.count,
            Set(directoryPaths).isDisjoint(with: Set(filePaths)),
            directoryPaths.allSatisfy(ownerDirectoryWithoutSymlink),
            filePaths.allSatisfy(pathDoesNotExistWithoutSymlink),
            sourceRootPath != supportRootPath,
            sourceRootPath != runtimeRootPath,
            supportRootPath != runtimeRootPath,
            containsPath(diagnosticRootPath, sourceRootPath),
            containsPath(diagnosticRootPath, supportRootPath),
            containsPath(diagnosticRootPath, runtimeRootPath),
            containsPath(diagnosticRootPath, reportPath),
            containsPath(diagnosticRootPath, storePath),
            storePath
                == supportRootPath
                    + "/com.eriklee.stornaut/Evidence.sqlite",
            !pathsOverlap(sourceRootPath, supportRootPath),
            !pathsOverlap(sourceRootPath, runtimeRootPath),
            !pathsOverlap(supportRootPath, runtimeRootPath)
        else {
            throw InvestigationRuntimeDiagnosticAppLeafError
                .invalidConfiguration
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case nonce
        case optIn
        case diagnosticRootPath
        case sourceRootPath
        case supportRootPath
        case runtimeRootPath
        case reportPath
        case storePath
        case binding
        case expectedModel
        case expectedProvider
        case validBefore
        case maximumWallClockSeconds
        case maximumTurns
        case maximumProbeCalls
        case maximumContextBytes
    }
}

private struct Binding: Decodable {
    let repositoryHEAD: String
    let sourceFingerprintSHA256: String
    let appExecutableSHA256: String
    let helperExecutableSHA256: String
    let runtimeReceiptSHA256: String
    let promptSHA256: String
    let envelopeSchemaSHA256: String
    let facadeSHA256: String
    let codexExecutableSHA256: String
    let appBundleIdentifier: String
    let helperServiceIdentifier: String

    init(from decoder: Decoder) throws {
        let container = try strictContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue))
        )
        repositoryHEAD = try container.decode(
            String.self,
            forKey: DynamicCodingKey(CodingKeys.repositoryHEAD.rawValue)
        )
        sourceFingerprintSHA256 = try container.decode(
            String.self,
            forKey: DynamicCodingKey(
                CodingKeys.sourceFingerprintSHA256.rawValue
            )
        )
        appExecutableSHA256 = try container.decode(
            String.self,
            forKey: DynamicCodingKey(
                CodingKeys.appExecutableSHA256.rawValue
            )
        )
        helperExecutableSHA256 = try container.decode(
            String.self,
            forKey: DynamicCodingKey(
                CodingKeys.helperExecutableSHA256.rawValue
            )
        )
        runtimeReceiptSHA256 = try container.decode(
            String.self,
            forKey: DynamicCodingKey(
                CodingKeys.runtimeReceiptSHA256.rawValue
            )
        )
        promptSHA256 = try container.decode(
            String.self,
            forKey: DynamicCodingKey(CodingKeys.promptSHA256.rawValue)
        )
        envelopeSchemaSHA256 = try container.decode(
            String.self,
            forKey: DynamicCodingKey(
                CodingKeys.envelopeSchemaSHA256.rawValue
            )
        )
        facadeSHA256 = try container.decode(
            String.self,
            forKey: DynamicCodingKey(CodingKeys.facadeSHA256.rawValue)
        )
        codexExecutableSHA256 = try container.decode(
            String.self,
            forKey: DynamicCodingKey(
                CodingKeys.codexExecutableSHA256.rawValue
            )
        )
        appBundleIdentifier = try container.decode(
            String.self,
            forKey: DynamicCodingKey(
                CodingKeys.appBundleIdentifier.rawValue
            )
        )
        helperServiceIdentifier = try container.decode(
            String.self,
            forKey: DynamicCodingKey(
                CodingKeys.helperServiceIdentifier.rawValue
            )
        )
    }

    var isValid: Bool {
        lowercaseHex(repositoryHEAD, count: 40)
            && [
                sourceFingerprintSHA256,
                appExecutableSHA256,
                helperExecutableSHA256,
                runtimeReceiptSHA256,
                promptSHA256,
                envelopeSchemaSHA256,
                facadeSHA256,
                codexExecutableSHA256,
            ].allSatisfy { lowercaseHex($0, count: 64) }
            && appBundleIdentifier == "com.eriklee.stornaut"
            && helperServiceIdentifier
                == "com.eriklee.stornaut.lifecycle"
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case repositoryHEAD
        case sourceFingerprintSHA256
        case appExecutableSHA256
        case helperExecutableSHA256
        case runtimeReceiptSHA256
        case promptSHA256
        case envelopeSchemaSHA256
        case facadeSHA256
        case codexExecutableSHA256
        case appBundleIdentifier
        case helperServiceIdentifier
    }
}

private struct DynamicCodingKey: CodingKey, Hashable {
    let stringValue: String
    let intValue: Int? = nil

    init(_ value: String) {
        stringValue = value
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}

private func strictContainer(
    _ decoder: Decoder,
    keys: Set<String>
) throws -> KeyedDecodingContainer<DynamicCodingKey> {
    let container = try decoder.container(
        keyedBy: DynamicCodingKey.self
    )
    guard Set(container.allKeys.map(\.stringValue)) == keys else {
        throw InvestigationRuntimeDiagnosticAppLeafError
            .invalidConfiguration
    }
    return container
}

private func validAbsolutePath(_ path: String) -> Bool {
    guard
        path.hasPrefix("/"),
        path != "/",
        !path.hasSuffix("/"),
        !path.contains("//"),
        !path.contains("\n"),
        !path.contains("\r"),
        path.utf8.count <= 4_096
    else {
        return false
    }
    return (path as NSString).pathComponents
        .dropFirst()
        .allSatisfy { $0 != "." && $0 != ".." && !$0.isEmpty }
}

private func ownerDirectoryWithoutSymlink(_ path: String) -> Bool {
    var information = stat()
    return pathHasNoSymlinkComponents(path)
        && lstat(path, &information) == 0
        && information.st_mode & S_IFMT == S_IFDIR
        && information.st_uid == geteuid()
        && information.st_mode & 0o077 == 0
}

private func pathDoesNotExistWithoutSymlink(_ path: String) -> Bool {
    var information = stat()
    if lstat(path, &information) == 0 {
        return false
    }
    let parent = URL(filePath: path).deletingLastPathComponent().path
    return errno == ENOENT
        && pathHasNoSymlinkComponents(parent)
        && ownerDirectoryWithoutSymlink(parent)
}

private func pathHasNoSymlinkComponents(_ path: String) -> Bool {
    let components = (path as NSString).pathComponents
    guard components.first == "/" else {
        return false
    }
    var current = "/"
    for component in components.dropFirst() {
        current = URL(
            filePath: current,
            directoryHint: .isDirectory
        )
        .appending(path: component)
        .path
        var information = stat()
        guard
            lstat(current, &information) == 0,
            information.st_mode & S_IFMT != S_IFLNK
        else {
            return false
        }
    }
    return true
}

private func containsPath(_ root: String, _ child: String) -> Bool {
    child.hasPrefix(root + "/")
}

private func pathsOverlap(_ lhs: String, _ rhs: String) -> Bool {
    lhs == rhs || containsPath(lhs, rhs) || containsPath(rhs, lhs)
}

private func lowercaseHex(_ value: String, count: Int) -> Bool {
    value.utf8.count == count
        && value.unicodeScalars.allSatisfy {
            (0x30...0x39).contains($0.value)
                || (0x61...0x66).contains($0.value)
        }
}
#endif
