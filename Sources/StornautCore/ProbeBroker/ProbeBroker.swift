import Darwin
import Foundation

public struct ProbeBroker: Sendable {
    public typealias AccessHook = @Sendable () async throws -> Void

    private let allowedCapabilities: Set<ProbeCapability>
    private let beforeAccess: AccessHook

    public init(
        allowedCapabilities: Set<ProbeCapability> = Set(ProbeCapability.allCases),
        beforeAccess: @escaping AccessHook = {}
    ) {
        self.allowedCapabilities = allowedCapabilities
        self.beforeAccess = beforeAccess
    }

    public func execute(
        _ request: ProbeRequest,
        in context: ProbeContext
    ) async -> ProbeResult {
        guard allowedCapabilities.contains(request.capability) else {
            return await finish(
                .failure(.capabilityNotAllowed),
                capability: request.capability,
                context: context
            )
        }
        guard request.capability.requiredReadLevel <= context.maximumReadLevel else {
            return await finish(
                .failure(.readLevelDenied),
                capability: request.capability,
                context: context
            )
        }
        guard validate(request) else {
            return await finish(
                .failure(.invalidRequest),
                capability: request.capability,
                context: context
            )
        }
        guard await context.session.reserveCall() else {
            return await finish(
                .failure(.sessionCallBudgetExceeded),
                capability: request.capability,
                context: context
            )
        }

        let pathDecision = CanonicalPathPolicy().evaluate(
            requestedURL: request.targetURL,
            allowedRoots: context.allowedRoots
        )
        guard case let .allowed(path) = pathDecision else {
            let failure: ProbeFailure
            switch pathDecision {
            case .denied:
                failure = .pathDenied
            case .unknown:
                failure = .pathUnknown
            case .allowed:
                preconditionFailure("Handled by guard")
            }
            return await finish(
                .failure(failure),
                capability: request.capability,
                context: context
            )
        }

        let reservedReadBytes = estimatedReadBytes(for: request)
        guard await context.session.reserveReadBytes(reservedReadBytes) else {
            return await finish(
                .failure(.sessionReadBudgetExceeded),
                capability: request.capability,
                context: context
            )
        }
        let result = await runWithTimeout(
            request: request,
            path: path,
            timeout: context.perCallTimeout
        )
        guard case let .success(response) = result else {
            return await finish(
                result,
                capability: request.capability,
                context: context
            )
        }

        let outputBytes: Int
        do {
            outputBytes = try JSONEncoder().encode(response).count
        } catch {
            return await finish(
                .failure(.accessFailed),
                capability: request.capability,
                context: context
            )
        }
        guard outputBytes <= context.perCallOutputByteLimit else {
            return await finish(
                .failure(.outputByteLimitExceeded),
                capability: request.capability,
                context: context,
                readBytes: response.readBytes,
                outputBytes: outputBytes
            )
        }
        guard await context.session.reserveOutputBytes(outputBytes) else {
            return await finish(
                .failure(.sessionOutputBudgetExceeded),
                capability: request.capability,
                context: context,
                readBytes: response.readBytes,
                outputBytes: outputBytes
            )
        }
        return await finish(
            result,
            capability: request.capability,
            context: context,
            readBytes: response.readBytes,
            outputBytes: outputBytes
        )
    }

    private func runWithTimeout(
        request: ProbeRequest,
        path: CanonicalPath,
        timeout: Duration
    ) async -> ProbeResult {
        guard timeout > .zero else {
            return .failure(.timedOut)
        }

        return await withTaskGroup(of: TimedProbeResult.self) { group in
            group.addTask {
                do {
                    try Task.checkCancellation()
                    try await beforeAccess()
                    try Task.checkCancellation()
                    return .operation(perform(request, at: path))
                } catch is CancellationError {
                    return .operation(.failure(.cancelled))
                } catch {
                    return .operation(.failure(.accessFailed))
                }
            }
            group.addTask {
                do {
                    try await Task.sleep(for: timeout)
                    return .timeout
                } catch {
                    return .cancelled
                }
            }

            let first = await group.next() ?? .cancelled
            group.cancelAll()
            switch first {
            case let .operation(result):
                return result
            case .timeout:
                return .failure(.timedOut)
            case .cancelled:
                return .failure(.cancelled)
            }
        }
    }

    private func perform(
        _ request: ProbeRequest,
        at path: CanonicalPath
    ) -> ProbeResult {
        guard !Task.isCancelled else {
            return .failure(.cancelled)
        }
        guard fileIdentity(at: path.url) == path.identity else {
            return .failure(.fileIdentityChanged)
        }

        let result: ProbeResult
        switch request.capability {
        case .diskSnapshot:
            result = diskSnapshot(at: path)
        case .directorySummary:
            result = directorySummary(
                at: path,
                limit: request.limit ?? ProbeRequest.maximumChildLimit
            )
        case .largestChildren:
            result = largestChildren(
                at: path,
                limit: request.limit ?? 20
            )
        case .safeTextSnippet:
            result = safeTextSnippet(
                at: path,
                byteLimit: request.byteLimit ?? 4_096
            )
        }

        guard fileIdentity(at: path.url) == path.identity else {
            return .failure(.fileIdentityChanged)
        }
        return result
    }

    private func finish(
        _ result: ProbeResult,
        capability: ProbeCapability,
        context: ProbeContext,
        readBytes: Int = 0,
        outputBytes: Int = 0
    ) async -> ProbeResult {
        let outcome: ProbeAuditOutcome
        switch result {
        case .success:
            outcome = .success
        case let .failure(failure):
            switch failure {
            case .cancelled:
                outcome = .cancelled
            case .timedOut:
                outcome = .timedOut
            case .capabilityNotAllowed, .invalidRequest, .pathDenied,
                 .pathUnknown, .readLevelDenied, .fileTypeNotAllowed:
                outcome = .denied
            default:
                outcome = .failed
            }
        }
        await context.auditRecorder.append(
            ProbeAuditRecord(
                capability: capability,
                outcome: outcome,
                readBytes: readBytes,
                outputBytes: outputBytes
            )
        )
        return result
    }
}

private func estimatedReadBytes(for request: ProbeRequest) -> Int {
    switch request.capability {
    case .diskSnapshot, .directorySummary, .largestChildren:
        0
    case .safeTextSnippet:
        (request.byteLimit ?? 4_096) + 1
    }
}

private enum TimedProbeResult: Sendable {
    case operation(ProbeResult)
    case timeout
    case cancelled
}

private func validate(_ request: ProbeRequest) -> Bool {
    if let limit = request.limit,
       !(1...ProbeRequest.maximumChildLimit).contains(limit)
    {
        return false
    }
    if let byteLimit = request.byteLimit,
       !(1...ProbeRequest.maximumSnippetBytes).contains(byteLimit)
    {
        return false
    }
    switch request.capability {
    case .diskSnapshot:
        return request.limit == nil && request.byteLimit == nil
    case .directorySummary, .largestChildren:
        return request.byteLimit == nil
    case .safeTextSnippet:
        return request.limit == nil
    }
}

private func diskSnapshot(at path: CanonicalPath) -> ProbeResult {
    guard let descriptor = openVerifiedDescriptor(
        at: path,
        flags: O_RDONLY | O_CLOEXEC | O_NOFOLLOW
    ) else {
        return .failure(.accessFailed)
    }
    defer { close(descriptor) }

    var information = statfs()
    guard fstatfs(descriptor, &information) == 0 else {
        return .failure(.accessFailed)
    }
    let blockSize = Int64(information.f_bsize)
    return .success(
        ProbeResponse(
            payload: .diskSnapshot(
                DiskSnapshot(
                    totalBytes: blockSize * Int64(information.f_blocks),
                    availableBytes: blockSize * Int64(information.f_bavail)
                )
            ),
            readBytes: 0
        )
    )
}

private func directorySummary(
    at path: CanonicalPath,
    limit: Int
) -> ProbeResult {
    guard path.identity.isDirectory else {
        return .failure(.invalidRequest)
    }
    guard let entries = directoryEntries(at: path) else {
        return .failure(.accessFailed)
    }
    guard entries.count <= limit else {
        return .failure(.outputByteLimitExceeded)
    }
    return .success(
        ProbeResponse(
            payload: .directorySummary(
                DirectorySummary(
                    entryCount: entries.count,
                    logicalBytes: entries.reduce(0) { $0 + $1.logicalBytes },
                    allocatedBytes: entries.reduce(0) { $0 + $1.allocatedBytes }
                )
            ),
            readBytes: 0
        )
    )
}

private func largestChildren(
    at path: CanonicalPath,
    limit: Int
) -> ProbeResult {
    guard path.identity.isDirectory else {
        return .failure(.invalidRequest)
    }
    guard let entries = directoryEntries(at: path) else {
        return .failure(.accessFailed)
    }
    let values = entries.map {
        LargestChild(
            name: $0.name,
            logicalBytes: $0.logicalBytes,
            isDirectory: $0.isDirectory
        )
    }
    .sorted {
        if $0.logicalBytes == $1.logicalBytes {
            return $0.name < $1.name
        }
        return $0.logicalBytes > $1.logicalBytes
    }
    return .success(
        ProbeResponse(
            payload: .largestChildren(
                LargestChildren(children: Array(values.prefix(limit)))
            ),
            readBytes: 0
        )
    )
}

private func safeTextSnippet(
    at path: CanonicalPath,
    byteLimit: Int
) -> ProbeResult {
    guard path.identity.isRegularFile else {
        return .failure(.invalidRequest)
    }
    guard approvedTextFilenames.contains(
        path.url.lastPathComponent.lowercased()
    ) else {
        return .failure(.fileTypeNotAllowed)
    }

    guard let descriptor = openVerifiedDescriptor(
        at: path,
        flags: O_RDONLY | O_NOFOLLOW | O_CLOEXEC
    ) else {
        return .failure(.accessFailed)
    }
    defer { close(descriptor) }

    var bytes = [UInt8](repeating: 0, count: byteLimit + 1)
    let count = read(descriptor, &bytes, bytes.count)
    guard count >= 0 else {
        return .failure(.accessFailed)
    }
    bytes.removeSubrange(Int(count)..<bytes.count)
    guard !bytes.contains(0) else {
        return .failure(.binaryContent)
    }
    guard let text = String(bytes: bytes.prefix(byteLimit), encoding: .utf8) else {
        return .failure(.binaryContent)
    }
    let redacted = redactSecrets(in: text)
    return .success(
        ProbeResponse(
            payload: .safeTextSnippet(
                SafeTextSnippet(
                    text: redacted,
                    byteCount: min(Int(count), byteLimit),
                    truncated: count > byteLimit
                )
            ),
            readBytes: Int(count)
        )
    )
}

private struct DirectoryEntryMetadata {
    let name: String
    let logicalBytes: Int64
    let allocatedBytes: Int64
    let isDirectory: Bool
}

private func directoryEntries(
    at path: CanonicalPath
) -> [DirectoryEntryMetadata]? {
    guard let descriptor = openVerifiedDescriptor(
        at: path,
        flags: O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
    ) else {
        return nil
    }
    guard let directory = fdopendir(descriptor) else {
        close(descriptor)
        return nil
    }
    defer { closedir(directory) }

    let directoryDescriptor = dirfd(directory)
    var entries: [DirectoryEntryMetadata] = []
    while let entry = readdir(directory) {
        let name = withUnsafePointer(to: entry.pointee.d_name) {
            $0.withMemoryRebound(
                to: CChar.self,
                capacity: Int(MAXNAMLEN) + 1
            ) {
                String(cString: $0)
            }
        }
        if name == "." || name == ".." {
            continue
        }

        var information = stat()
        let result = name.withCString {
            fstatat(
                directoryDescriptor,
                $0,
                &information,
                AT_SYMLINK_NOFOLLOW
            )
        }
        guard result == 0 else {
            continue
        }
        entries.append(
            DirectoryEntryMetadata(
                name: name,
                logicalBytes: Int64(information.st_size),
                allocatedBytes: Int64(information.st_blocks) * 512,
                isDirectory: information.st_mode & S_IFMT == S_IFDIR
            )
        )
    }
    return entries
}

private func openVerifiedDescriptor(
    at path: CanonicalPath,
    flags: Int32
) -> Int32? {
    let descriptor = open(path.url.path, flags)
    guard descriptor >= 0 else {
        return nil
    }
    var information = stat()
    guard fstat(descriptor, &information) == 0,
          information.st_dev == dev_t(path.identity.device),
          information.st_ino == ino_t(path.identity.inode)
    else {
        close(descriptor)
        return nil
    }
    return descriptor
}

private let approvedTextFilenames: Set<String> = [
    "readme",
    "readme.md",
    "readme.markdown",
    "package.json",
    "package.swift",
    "cargo.toml",
    "pyproject.toml",
    "go.mod",
    "go.sum",
    "podfile",
    "cartfile",
]

private func redactSecrets(in text: String) -> String {
    let patterns = [
        #"(?im)\b(api[_-]?key|token|password|secret)\s*[:=]\s*[^\s"'`]+"#,
        #"(?i)\b(sk-[A-Za-z0-9_-]{8,})\b"#,
    ]
    return patterns.reduce(text) { partial, pattern in
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return partial
        }
        let range = NSRange(partial.startIndex..., in: partial)
        return expression.stringByReplacingMatches(
            in: partial,
            range: range,
            withTemplate: "[REDACTED]"
        )
    }
}
