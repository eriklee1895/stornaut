import Darwin
import Foundation
import StornautCodex

private enum VerifierCommand: String {
    case assemble
    case verify
}

private struct HarnessEvidence: Decodable {
    let schemaVersion: Int
    let diagnosticMetadata: CapabilityRuntimeDiagnosticMetadata?
    let diagnosticWorkerEvidence: CapabilityRuntimeWorkerEvidence?
    let lifecycleIntegrity:
        [CapabilityRuntimeIntegrityEvidence]?
    let reasonKey: String?
}

private enum VerifierError: Error {
    case invalidArguments
    case invalidInput
    case blocked
}

private func run() throws {
    guard
        CommandLine.arguments.count >= 2,
        let command = VerifierCommand(
            rawValue: CommandLine.arguments[1]
        )
    else {
        throw VerifierError.invalidArguments
    }
    let expectedArgumentCount = command == .assemble ? 5 : 4
    guard CommandLine.arguments.count == expectedArgumentCount else {
        throw VerifierError.invalidArguments
    }
    let inputURL = URL(filePath: CommandLine.arguments[2])
    let outputURL = URL(
        filePath: CommandLine.arguments[expectedArgumentCount - 1]
    )
    let input = try readBoundedRegularFile(inputURL)
    let verifier = CapabilityRuntimeDiagnosticVerifier()
    let report: CapabilityRuntimeDiagnosticReport
    switch command {
    case .assemble:
        let evidence = try JSONDecoder().decode(
            HarnessEvidence.self,
            from: input
        )
        guard
            evidence.schemaVersion == 1,
            evidence.reasonKey == nil,
            let metadata = evidence.diagnosticMetadata,
            let worker = evidence.diagnosticWorkerEvidence,
            let lifecycle = evidence.lifecycleIntegrity
        else {
            throw VerifierError.invalidInput
        }
        let repositoryData = try readBoundedRegularFile(
            URL(filePath: CommandLine.arguments[3])
        )
        let repository = try JSONDecoder().decode(
            CapabilityRuntimeRepositoryEvidence.self,
            from: repositoryData
        )
        report = try verifier.assembleSignedRuntimeReport(
            metadata: metadata,
            worker: worker,
            lifecycleIntegrity: lifecycle,
            repository: repository
        )
    case .verify:
        let decoded = try JSONDecoder().decode(
            CapabilityRuntimeDiagnosticReport.self,
            from: input
        )
        report = try verifier.verifyReadyReport(decoded)
    }
    guard report.outcome == .signedRuntimeReady else {
        throw VerifierError.blocked
    }
    try writeExclusive(
        JSONEncoder.canonical.encode(report),
        to: outputURL
    )
}

private func readBoundedRegularFile(_ url: URL) throws -> Data {
    let descriptor = open(
        url.path,
        O_RDONLY | O_CLOEXEC | O_NOFOLLOW
    )
    guard descriptor >= 0 else {
        throw VerifierError.invalidInput
    }
    defer { close(descriptor) }
    var information = stat()
    guard
        fstat(descriptor, &information) == 0,
        information.st_mode & S_IFMT == S_IFREG,
        information.st_uid == getuid(),
        information.st_mode & 0o777 == 0o600,
        information.st_nlink == 1,
        information.st_size > 0,
        information.st_size <= 2 * 1_024 * 1_024
    else {
        throw VerifierError.invalidInput
    }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4_096)
    while true {
        let count = Darwin.read(descriptor, &buffer, buffer.count)
        if count == 0 {
            return data
        }
        if count < 0 {
            if errno == EINTR {
                continue
            }
            throw VerifierError.invalidInput
        }
        guard data.count + count <= 2 * 1_024 * 1_024 else {
            throw VerifierError.invalidInput
        }
        data.append(contentsOf: buffer.prefix(count))
    }
}

private func writeExclusive(_ data: Data, to url: URL) throws {
    guard
        url.isFileURL,
        url.path.hasPrefix("/"),
        !FileManager.default.fileExists(atPath: url.path)
    else {
        throw VerifierError.invalidInput
    }
    let descriptor = open(
        url.path,
        O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
        0o600
    )
    guard descriptor >= 0 else {
        throw VerifierError.invalidInput
    }
    var shouldRemove = true
    defer {
        close(descriptor)
        if shouldRemove {
            unlink(url.path)
        }
    }
    let didWrite = data.withUnsafeBytes { bytes in
        guard let base = bytes.baseAddress else {
            return true
        }
        var offset = 0
        while offset < bytes.count {
            let count = Darwin.write(
                descriptor,
                base.advanced(by: offset),
                bytes.count - offset
            )
            if count < 0 {
                if errno == EINTR {
                    continue
                }
                return false
            }
            offset += count
        }
        return true
    }
    guard didWrite, fsync(descriptor) == 0 else {
        throw VerifierError.invalidInput
    }
    shouldRemove = false
}

private extension JSONEncoder {
    static var canonical: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

do {
    try run()
} catch {
    FileHandle.standardError.write(
        Data("stornaut capability runtime verification failed\n".utf8)
    )
    exit(1)
}
