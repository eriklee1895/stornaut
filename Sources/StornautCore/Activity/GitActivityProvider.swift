import Darwin
import Foundation

struct GitCommandRequest: Sendable, Equatable {
    let executableURL: URL
    let arguments: [String]
    let environment: [String: String]
    let standardOutputLimit: Int
    let standardErrorLimit: Int
    let timeout: Duration
}

struct GitCommandOutput: Sendable, Equatable {
    let exitStatus: Int32
    let stdout: Data
    let stderr: Data
    let stdoutWasTruncated: Bool
    let stderrWasTruncated: Bool

    init(
        exitStatus: Int32,
        stdout: Data,
        stderr: Data = Data(),
        stdoutWasTruncated: Bool = false,
        stderrWasTruncated: Bool = false
    ) {
        self.exitStatus = exitStatus
        self.stdout = stdout
        self.stderr = stderr
        self.stdoutWasTruncated = stdoutWasTruncated
        self.stderrWasTruncated = stderrWasTruncated
    }
}

protocol GitCommandRunning: Sendable {
    func run(_ request: GitCommandRequest) async throws -> GitCommandOutput
}

enum GitCommandRunnerError: Error, Sendable, Equatable {
    case launchFailed
    case timedOut
    case outputReadFailed
}

struct FoundationGitCommandRunner: GitCommandRunning {
    func run(_ request: GitCommandRequest) async throws -> GitCommandOutput {
        try await Task.detached(priority: .utility) {
            try runGitCommandSynchronously(request)
        }.value
    }
}

public struct GitActivitySnapshot: Sendable, Equatable {
    public let status: ActivityProviderStatus
    public let hasStagedChanges: Bool?
    public let hasModifiedFiles: Bool?
    public let hasUntrackedFiles: Bool?
    public let branch: DomainLabel?
    public let upstream: DomainLabel?
    public let aheadCount: Int?
    public let behindCount: Int?
    public let lastCommitAt: Date?
    public let lastCommitStatus: ActivityProviderStatus
    public let observations: [ActivityObservation]
    public let timestamps: [ActivityTimestampObservation]

    public var isClean: Bool? {
        guard let hasStagedChanges,
              let hasModifiedFiles,
              let hasUntrackedFiles
        else {
            return nil
        }
        return !hasStagedChanges
            && !hasModifiedFiles
            && !hasUntrackedFiles
    }

    public var isUpstreamSynchronized: Bool? {
        guard status == .available else {
            return nil
        }
        guard upstream != nil,
              let aheadCount,
              let behindCount
        else {
            return false
        }
        return aheadCount == 0 && behindCount == 0
    }
}

public struct GitActivityProvider: Sendable {
    static let fixedEnvironment = [
        "GIT_CONFIG_GLOBAL": "/dev/null",
        "GIT_CONFIG_NOSYSTEM": "1",
        "GIT_CONFIG_SYSTEM": "/dev/null",
        "GIT_NO_LAZY_FETCH": "1",
        "GIT_OPTIONAL_LOCKS": "0",
        "GIT_PAGER": "cat",
        "GIT_TERMINAL_PROMPT": "0",
        "HOME": "/var/empty",
        "LANG": "C",
        "LC_ALL": "C",
        "PATH": "/usr/bin:/bin",
    ]

    private let runner: any GitCommandRunning

    public init() {
        runner = FoundationGitCommandRunner()
    }

    init(runner: any GitCommandRunning) {
        self.runner = runner
    }

    static func fixedPrefix(for repositoryURL: URL) -> [String] {
        [
            "--no-pager",
            "--no-optional-locks",
            "-c", "core.hooksPath=/dev/null",
            "-c", "core.fsmonitor=false",
            "-c", "core.untrackedCache=false",
            "-C", repositoryURL.path,
        ]
    }

    public func collect(
        repositoryURL: URL,
        observedAt: Date
    ) async -> GitActivitySnapshot {
        guard validRepositoryURL(repositoryURL),
              isValidActivityDate(observedAt)
        else {
            return unavailableSnapshot(
                failure: .invalidInput,
                observedAt: observedAt
            )
        }

        let statusResult = await run(
            arguments: Self.fixedPrefix(for: repositoryURL) + [
                "status",
                "--porcelain=v2",
                "--branch",
                "--untracked-files=normal",
                "--no-renames",
            ]
        )
        let lastCommitResult = await run(
            arguments: Self.fixedPrefix(for: repositoryURL) + [
                "log",
                "-1",
                "--format=%ct",
            ]
        )

        let status: ParsedGitStatus?
        let providerStatus: ActivityProviderStatus
        switch statusResult {
        case let .success(output):
            do {
                status = try parseStatus(output)
                providerStatus = .available
            } catch let failure as ActivityProviderFailure {
                status = nil
                providerStatus = .unavailable(failure)
            } catch {
                status = nil
                providerStatus = .unavailable(.malformedOutput)
            }
        case let .failure(failure):
            status = nil
            providerStatus = .unavailable(failure)
        }

        let lastCommit: Date?
        let lastCommitStatus: ActivityProviderStatus
        switch lastCommitResult {
        case let .success(output):
            do {
                lastCommit = try parseLastCommit(output)
                lastCommitStatus = .available
            } catch let failure as ActivityProviderFailure {
                lastCommit = nil
                lastCommitStatus = .unavailable(failure)
            } catch {
                lastCommit = nil
                lastCommitStatus = .unavailable(.malformedOutput)
            }
        case let .failure(failure):
            lastCommit = nil
            lastCommitStatus = .unavailable(failure)
        }

        let observations = makeObservations(
            status: status,
            failure: providerStatus.failure,
            observedAt: observedAt
        )
        let timestamps: [ActivityTimestampObservation]
        if let lastCommit,
           let timestamp = try? ActivityTimestampObservation(
               source: .gitLastCommit,
               origin: .external,
               observedAt: lastCommit
           )
        {
            timestamps = [timestamp]
        } else {
            timestamps = []
        }
        return GitActivitySnapshot(
            status: providerStatus,
            hasStagedChanges: status?.hasStagedChanges,
            hasModifiedFiles: status?.hasModifiedFiles,
            hasUntrackedFiles: status?.hasUntrackedFiles,
            branch: status?.branch,
            upstream: status?.upstream,
            aheadCount: status?.aheadCount,
            behindCount: status?.behindCount,
            lastCommitAt: lastCommit,
            lastCommitStatus: lastCommitStatus,
            observations: observations,
            timestamps: timestamps
        )
    }

    private func run(
        arguments: [String]
    ) async -> Result<GitCommandOutput, ActivityProviderFailure> {
        do {
            let output = try await runner.run(
                GitCommandRequest(
                    executableURL: URL(filePath: "/usr/bin/git"),
                    arguments: arguments,
                    environment: Self.fixedEnvironment,
                    standardOutputLimit: 262_144,
                    standardErrorLimit: 8_192,
                    timeout: .seconds(2)
                )
            )
            if output.stdoutWasTruncated || output.stderrWasTruncated {
                return .failure(.outputTruncated)
            }
            guard output.exitStatus == 0 else {
                let failure: ActivityProviderFailure =
                    output.stderr.localizedCaseInsensitiveContains(
                        "permission denied"
                    )
                    ? .permissionDenied
                    : .nonzeroExit
                return .failure(failure)
            }
            return .success(output)
        } catch GitCommandRunnerError.timedOut {
            return .failure(.timedOut)
        } catch GitCommandRunnerError.outputReadFailed {
            return .failure(.malformedOutput)
        } catch {
            return .failure(.launchFailed)
        }
    }
}

private struct ParsedGitStatus {
    var hasStagedChanges = false
    var hasModifiedFiles = false
    var hasUntrackedFiles = false
    var branch: DomainLabel?
    var upstream: DomainLabel?
    var aheadCount: Int?
    var behindCount: Int?
}

private func parseStatus(_ output: GitCommandOutput) throws -> ParsedGitStatus {
    guard let string = String(data: output.stdout, encoding: .utf8),
          !string.contains("\0"),
          string.utf8.count <= 262_144
    else {
        throw ActivityProviderFailure.malformedOutput
    }
    var status = ParsedGitStatus()
    var sawOID = false
    var sawBranch = false
    var sawAheadBehind = false
    for line in string.split(separator: "\n", omittingEmptySubsequences: true) {
        guard line.utf8.count <= 16_384 else {
            throw ActivityProviderFailure.malformedOutput
        }
        if line.hasPrefix("# branch.oid ") {
            sawOID = true
        } else if line.hasPrefix("# branch.head ") {
            let value = String(line.dropFirst("# branch.head ".count))
            guard let label = DomainLabel(rawValue: value) else {
                throw ActivityProviderFailure.malformedOutput
            }
            status.branch = label
            sawBranch = true
        } else if line.hasPrefix("# branch.upstream ") {
            let value = String(line.dropFirst("# branch.upstream ".count))
            guard let label = DomainLabel(rawValue: value) else {
                throw ActivityProviderFailure.malformedOutput
            }
            status.upstream = label
        } else if line.hasPrefix("# branch.ab ") {
            let values = line.dropFirst("# branch.ab ".count).split(
                separator: " "
            )
            guard values.count == 2,
                  values[0].first == "+",
                  values[1].first == "-",
                  let ahead = Int(values[0].dropFirst()),
                  let behind = Int(values[1].dropFirst()),
                  ahead >= 0,
                  behind >= 0,
                  ahead <= 1_000_000_000,
                  behind <= 1_000_000_000
            else {
                throw ActivityProviderFailure.malformedOutput
            }
            status.aheadCount = ahead
            status.behindCount = behind
            sawAheadBehind = true
        } else if line.hasPrefix("1 ")
                    || line.hasPrefix("2 ")
                    || line.hasPrefix("u ")
        {
            let fields = line.split(
                separator: " ",
                maxSplits: 2,
                omittingEmptySubsequences: true
            )
            guard fields.count >= 2, fields[1].count == 2 else {
                throw ActivityProviderFailure.malformedOutput
            }
            let state = Array(fields[1])
            status.hasStagedChanges = status.hasStagedChanges
                || state[0] != "."
            status.hasModifiedFiles = status.hasModifiedFiles
                || state[1] != "."
        } else if line.hasPrefix("? ") {
            status.hasUntrackedFiles = true
        } else if line.hasPrefix("! ") {
            continue
        } else if line.hasPrefix("# ") {
            continue
        } else {
            throw ActivityProviderFailure.malformedOutput
        }
    }
    guard sawOID,
          sawBranch,
          (status.upstream == nil || sawAheadBehind),
          (status.upstream != nil || !sawAheadBehind)
    else {
        throw ActivityProviderFailure.malformedOutput
    }
    return status
}

private func parseLastCommit(_ output: GitCommandOutput) throws -> Date {
    guard let string = String(data: output.stdout, encoding: .utf8),
          let seconds = Int64(string.trimmingCharacters(in: .whitespacesAndNewlines)),
          seconds >= 0
    else {
        throw ActivityProviderFailure.malformedOutput
    }
    let date = Date(timeIntervalSince1970: TimeInterval(seconds))
    guard isValidActivityDate(date) else {
        throw ActivityProviderFailure.malformedOutput
    }
    return date
}

private func makeObservations(
    status: ParsedGitStatus?,
    failure: ActivityProviderFailure?,
    observedAt: Date
) -> [ActivityObservation] {
    if let status {
        let clean = !status.hasStagedChanges
            && !status.hasModifiedFiles
            && !status.hasUntrackedFiles
        let synchronized = status.upstream != nil
            && status.aheadCount == 0
            && status.behindCount == 0
        return [
            try! ActivityObservation(
                key: .gitClean,
                state: clean ? .satisfied : .contradicted,
                source: .git,
                origin: .external,
                observedAt: observedAt,
                reason: DomainToken(
                    rawValue: clean
                        ? "activity.git.clean"
                        : "activity.git.changed"
                )!
            ),
            try! ActivityObservation(
                key: .gitUpstreamSynchronized,
                state: synchronized ? .satisfied : .contradicted,
                source: .git,
                origin: .external,
                observedAt: observedAt,
                reason: DomainToken(
                    rawValue: synchronized
                        ? "activity.git.upstream-synced"
                        : "activity.git.upstream-not-synced"
                )!
            ),
        ]
    }
    let reason = DomainToken(
        rawValue: "activity.git.\((failure ?? .malformedOutput).rawValue)"
    )!
    return [
        try! ActivityObservation(
            key: .gitClean,
            state: .unavailable,
            source: .git,
            origin: .external,
            observedAt: observedAt,
            reason: reason
        ),
        try! ActivityObservation(
            key: .gitUpstreamSynchronized,
            state: .unavailable,
            source: .git,
            origin: .external,
            observedAt: observedAt,
            reason: reason
        ),
    ]
}

private func unavailableSnapshot(
    failure: ActivityProviderFailure,
    observedAt: Date
) -> GitActivitySnapshot {
    let evidenceDate = safeActivityObservationDate(observedAt)
    return GitActivitySnapshot(
        status: .unavailable(failure),
        hasStagedChanges: nil,
        hasModifiedFiles: nil,
        hasUntrackedFiles: nil,
        branch: nil,
        upstream: nil,
        aheadCount: nil,
        behindCount: nil,
        lastCommitAt: nil,
        lastCommitStatus: .unavailable(failure),
        observations: makeObservations(
            status: nil,
            failure: failure,
            observedAt: evidenceDate
        ),
        timestamps: []
    )
}

private func validRepositoryURL(_ url: URL) -> Bool {
    url.isFileURL
        && url.path.hasPrefix("/")
        && !url.path.contains("\0")
        && url.path.utf8.count <= 16_384
}

private extension ActivityProviderStatus {
    var failure: ActivityProviderFailure? {
        guard case let .unavailable(failure) = self else {
            return nil
        }
        return failure
    }
}

private extension Data {
    func localizedCaseInsensitiveContains(_ value: String) -> Bool {
        String(data: self, encoding: .utf8)?
            .localizedCaseInsensitiveContains(value) == true
    }
}

private func runGitCommandSynchronously(
    _ request: GitCommandRequest
) throws -> GitCommandOutput {
    let process = Process()
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    let termination = DispatchSemaphore(value: 0)
    let readers = DispatchGroup()
    let stdout = GitLockedBox(GitBoundedOutput())
    let stderr = GitLockedBox(GitBoundedOutput())

    process.executableURL = request.executableURL
    process.arguments = request.arguments
    process.environment = request.environment
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    process.terminationHandler = { _ in termination.signal() }

    readers.enter()
    DispatchQueue.global(qos: .utility).async {
        stdout.set(
            drainGitOutput(
                stdoutPipe.fileHandleForReading,
                limit: request.standardOutputLimit
            )
        )
        readers.leave()
    }
    readers.enter()
    DispatchQueue.global(qos: .utility).async {
        stderr.set(
            drainGitOutput(
                stderrPipe.fileHandleForReading,
                limit: request.standardErrorLimit
            )
        )
        readers.leave()
    }

    do {
        try process.run()
    } catch {
        stdoutPipe.fileHandleForWriting.closeFile()
        stderrPipe.fileHandleForWriting.closeFile()
        readers.wait()
        throw GitCommandRunnerError.launchFailed
    }
    guard termination.wait(
        timeout: request.timeout.gitDispatchDeadline
    ) == .success else {
        process.terminate()
        if termination.wait(timeout: .now() + .milliseconds(250)) == .timedOut {
            kill(process.processIdentifier, SIGKILL)
            _ = termination.wait(timeout: .now() + .seconds(2))
        }
        throw GitCommandRunnerError.timedOut
    }

    readers.wait()
    guard stdout.value.readError == nil,
          stderr.value.readError == nil
    else {
        throw GitCommandRunnerError.outputReadFailed
    }
    return GitCommandOutput(
        exitStatus: process.terminationStatus,
        stdout: stdout.value.data,
        stderr: stderr.value.data,
        stdoutWasTruncated: stdout.value.wasTruncated,
        stderrWasTruncated: stderr.value.wasTruncated
    )
}

private struct GitBoundedOutput: Sendable {
    var data = Data()
    var wasTruncated = false
    var readError: String?
}

private final class GitLockedBox<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: Value

    init(_ value: Value) {
        storedValue = value
    }

    var value: Value {
        lock.withLock { storedValue }
    }

    func set(_ value: Value) {
        lock.withLock { storedValue = value }
    }
}

private func drainGitOutput(
    _ fileHandle: FileHandle,
    limit: Int
) -> GitBoundedOutput {
    var output = GitBoundedOutput()
    while true {
        do {
            guard let chunk = try fileHandle.read(upToCount: 4_096),
                  !chunk.isEmpty
            else {
                return output
            }
            let remaining = max(0, limit - output.data.count)
            output.data.append(chunk.prefix(remaining))
            if chunk.count > remaining {
                output.wasTruncated = true
            }
        } catch {
            output.readError = String(describing: error)
            return output
        }
    }
}

private extension Duration {
    var gitDispatchDeadline: DispatchTime {
        guard self > .zero else {
            return .now()
        }
        let components = self.components
        let seconds = components.seconds
        let fractionalNanoseconds = components.attoseconds / 1_000_000_000
        let secondsInNanoseconds = seconds.multipliedReportingOverflow(
            by: 1_000_000_000
        )
        let total: Int64
        if secondsInNanoseconds.overflow {
            total = .max
        } else {
            let addition = secondsInNanoseconds.partialValue
                .addingReportingOverflow(fractionalNanoseconds)
            total = addition.overflow ? .max : addition.partialValue
        }
        return .now() + .nanoseconds(Int(clamping: total))
    }
}
