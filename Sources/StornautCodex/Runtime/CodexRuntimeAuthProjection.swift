import Darwin
import Foundation

struct CodexRuntimeAuthSourceIdentity: Sendable, Equatable {
    let device: UInt64
    let inode: UInt64
    let ownerUserID: uid_t
    let mode: mode_t
}

struct CodexRuntimeAuthCredentials: Sendable, Equatable {
    let accessToken: String
    let accountID: String
    let planType: String?
}

final class CodexRuntimeAuthProjection:
    @unchecked Sendable,
    CustomStringConvertible
{
    let sourceURL: URL
    let sourceIdentity: CodexRuntimeAuthSourceIdentity
    private let lock = NSLock()
    private var credentials: CodexRuntimeAuthCredentials?

    init(
        sourceURL: URL,
        sourceIdentity: CodexRuntimeAuthSourceIdentity,
        credentials: CodexRuntimeAuthCredentials
    ) {
        self.sourceURL = sourceURL
        self.sourceIdentity = sourceIdentity
        self.credentials = credentials
    }

    var description: String {
        "<CodexRuntimeAuthProjection:redacted>"
    }

    func withCredentials<Result: Sendable>(
        _ body: (CodexRuntimeAuthCredentials) throws -> Result
    ) rethrows -> Result {
        try lock.withLock {
            guard let credentials else {
                preconditionFailure("Credentials were erased")
            }
            return try body(credentials)
        }
    }

    func erase() {
        lock.withLock {
            credentials = nil
        }
    }

    deinit {
        credentials = nil
    }
}

enum CodexRuntimeAuthProjectionError: Error, Sendable, Equatable {
    case invalidFile
    case multipleLinks
    case invalidOwner
    case invalidMode
    case fileTooLarge
    case readFailed
    case malformed
    case unsupportedAuthMode
    case invalidAccessToken
    case invalidAccountID
    case identityChanged
}

struct CodexRuntimeAuthProjector: Sendable {
    let maximumBytes: Int

    init(maximumBytes: Int = 64 * 1_024) {
        self.maximumBytes = max(1, maximumBytes)
    }

    func read(from sourceURL: URL) throws -> CodexRuntimeAuthProjection {
        let (identity, bytes) = try readBoundedFile(sourceURL)
        var data = bytes
        defer {
            data.resetBytes(in: 0..<data.count)
        }
        let object: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(
                with: data
            ) as? [String: Any] else {
                throw CodexRuntimeAuthProjectionError.malformed
            }
            object = parsed
        } catch let error as CodexRuntimeAuthProjectionError {
            throw error
        } catch {
            throw CodexRuntimeAuthProjectionError.malformed
        }
        guard object["auth_mode"] as? String == "chatgpt" else {
            throw CodexRuntimeAuthProjectionError.unsupportedAuthMode
        }
        guard let tokens = object["tokens"] as? [String: Any] else {
            throw CodexRuntimeAuthProjectionError.malformed
        }
        guard
            let accessToken = tokens["access_token"] as? String,
            isJWT(accessToken)
        else {
            throw CodexRuntimeAuthProjectionError.invalidAccessToken
        }
        guard
            let accountID = tokens["account_id"] as? String,
            !accountID.isEmpty,
            accountID.utf8.count <= 256,
            accountID.unicodeScalars.allSatisfy({
                $0.value >= 0x20 && $0.value != 0x7F
            })
        else {
            throw CodexRuntimeAuthProjectionError.invalidAccountID
        }
        let planType = (object["plan_type"] as? String).flatMap {
            $0.isEmpty || $0.utf8.count > 64 ? nil : $0
        }
        return CodexRuntimeAuthProjection(
            sourceURL: sourceURL.standardizedFileURL,
            sourceIdentity: identity,
            credentials: CodexRuntimeAuthCredentials(
                accessToken: accessToken,
                accountID: accountID,
                planType: planType
            )
        )
    }

    func refresh(
        from sourceURL: URL,
        matching expectedIdentity: CodexRuntimeAuthSourceIdentity
    ) throws -> CodexRuntimeAuthProjection {
        let projection = try read(from: sourceURL)
        guard projection.sourceIdentity == expectedIdentity else {
            projection.erase()
            throw CodexRuntimeAuthProjectionError.identityChanged
        }
        return projection
    }

    private func readBoundedFile(
        _ url: URL
    ) throws -> (CodexRuntimeAuthSourceIdentity, Data) {
        guard
            url.isFileURL,
            url.path.hasPrefix("/"),
            let canonicalParent = canonicalAuthParent(
                url.deletingLastPathComponent()
            ),
            canonicalParent.appending(
                path: url.lastPathComponent
            ).standardizedFileURL.path == url.standardizedFileURL.path
        else {
            throw CodexRuntimeAuthProjectionError.invalidFile
        }
        let descriptor = open(
            url.path,
            O_RDONLY | O_CLOEXEC | O_NOFOLLOW
        )
        guard descriptor >= 0 else {
            throw CodexRuntimeAuthProjectionError.invalidFile
        }
        defer { close(descriptor) }
        var information = stat()
        guard
            fstat(descriptor, &information) == 0,
            information.st_mode & S_IFMT == S_IFREG
        else {
            throw CodexRuntimeAuthProjectionError.invalidFile
        }
        guard information.st_uid == geteuid() else {
            throw CodexRuntimeAuthProjectionError.invalidOwner
        }
        guard information.st_mode & 0o777 == 0o600 else {
            throw CodexRuntimeAuthProjectionError.invalidMode
        }
        guard information.st_nlink == 1 else {
            throw CodexRuntimeAuthProjectionError.multipleLinks
        }
        guard
            information.st_size >= 0,
            information.st_size <= maximumBytes
        else {
            throw CodexRuntimeAuthProjectionError.fileTooLarge
        }
        let identity = CodexRuntimeAuthSourceIdentity(
            device: UInt64(information.st_dev),
            inode: UInt64(information.st_ino),
            ownerUserID: information.st_uid,
            mode: information.st_mode & 0o777
        )
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        defer {
            _ = buffer.withUnsafeMutableBytes {
                $0.initializeMemory(as: UInt8.self, repeating: 0)
            }
        }
        while true {
            let count = Darwin.read(descriptor, &buffer, buffer.count)
            if count == 0 {
                break
            }
            if count < 0 {
                if errno == EINTR { continue }
                throw CodexRuntimeAuthProjectionError.readFailed
            }
            guard data.count + count <= maximumBytes else {
                throw CodexRuntimeAuthProjectionError.fileTooLarge
            }
            data.append(contentsOf: buffer.prefix(count))
        }
        var finalInformation = stat()
        guard
            fstat(descriptor, &finalInformation) == 0,
            finalInformation.st_dev == information.st_dev,
            finalInformation.st_ino == information.st_ino,
            finalInformation.st_size == information.st_size,
            finalInformation.st_mtimespec.tv_sec
                == information.st_mtimespec.tv_sec,
            finalInformation.st_mtimespec.tv_nsec
                == information.st_mtimespec.tv_nsec
        else {
            throw CodexRuntimeAuthProjectionError.identityChanged
        }
        return (identity, data)
    }

    private func isJWT(_ value: String) -> Bool {
        guard value.utf8.count <= 32 * 1_024 else {
            return false
        }
        let components = value.split(
            separator: ".",
            omittingEmptySubsequences: false
        )
        return components.count == 3
            && components.allSatisfy({ !$0.isEmpty })
            && value.unicodeScalars.allSatisfy({
                (0x2D...0x39).contains($0.value)
                    || (0x41...0x5A).contains($0.value)
                    || $0.value == 0x5F
                    || (0x61...0x7A).contains($0.value)
            })
    }
}

private func canonicalAuthParent(_ url: URL) -> URL? {
    guard let pointer = realpath(url.path, nil) else { return nil }
    defer { free(pointer) }
    return URL(
        filePath: String(cString: pointer),
        directoryHint: .isDirectory
    ).standardizedFileURL
}

struct CodexRuntimeFileAuthRefreshProvider:
    CodexRuntimeAuthRefreshProviding,
    Sendable
{
    let sourceURL: URL
    let sourceIdentity: CodexRuntimeAuthSourceIdentity
    let projector: CodexRuntimeAuthProjector

    init(
        sourceURL: URL,
        sourceIdentity: CodexRuntimeAuthSourceIdentity,
        projector: CodexRuntimeAuthProjector = CodexRuntimeAuthProjector()
    ) {
        self.sourceURL = sourceURL
        self.sourceIdentity = sourceIdentity
        self.projector = projector
    }

    func refresh() throws -> CodexRuntimeAuthProjection {
        try projector.refresh(
            from: sourceURL,
            matching: sourceIdentity
        )
    }
}
