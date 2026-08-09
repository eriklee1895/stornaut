import Darwin
import Foundation
import StornautCore

@main
struct SurveyorBenchmarkCommand {
    static func main() async {
        do {
            let options = try BenchmarkOptions.parse(CommandLine.arguments)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]

            var reference: BenchmarkReport?
            for repetition in 1...options.repeatCount {
                let report = try await runBenchmark(
                    options: options,
                    repetition: repetition
                )
                try validate(
                    report,
                    options: options,
                    reference: reference
                )
                reference = reference ?? report
                FileHandle.standardOutput.write(try encoder.encode(report))
                FileHandle.standardOutput.write(Data([0x0A]))
            }
        } catch {
            let message = "SurveyorBenchmark error: \(error)\n"
            FileHandle.standardError.write(Data(message.utf8))
            exit(2)
        }
    }
}

private struct BenchmarkOptions {
    enum Fixture: String {
        case synthetic
        case path
    }

    let fixture: Fixture
    let rootURL: URL?
    let repeatCount: Int
    let maximumWorkers: Int
    let maximumPendingDirectories: Int
    let streamBufferCapacity: Int
    let persistenceBatchSize: Int
    let cancelAfter: Duration?
    let launchContext: String

    static func parse(_ arguments: [String]) throws -> Self {
        var fixture: Fixture?
        var rootURL: URL?
        var repeatCount = 1
        var maximumWorkers = ScanRequest.defaultMaximumWorkers
        var maximumPendingDirectories =
            ScanRequest.defaultMaximumPendingDirectories
        var streamBufferCapacity = ScanRequest.defaultStreamBufferCapacity
        var persistenceBatchSize = ScanRequest.defaultPersistenceBatchSize
        var cancelAfter: Duration?
        var launchContext = "cli"

        var index = 1
        while index < arguments.count {
            let argument = arguments[index]
            func nextValue() throws -> String {
                guard index + 1 < arguments.count else {
                    throw BenchmarkError.invalidArguments
                }
                index += 1
                return arguments[index]
            }

            switch argument {
            case "--fixture":
                fixture = Fixture(rawValue: try nextValue())
            case "--root":
                let value = try nextValue()
                guard value.hasPrefix("/") else {
                    throw BenchmarkError.invalidArguments
                }
                rootURL = URL(filePath: value, directoryHint: .isDirectory)
            case "--repeat":
                repeatCount = try positiveInteger(nextValue())
            case "--workers":
                maximumWorkers = try positiveInteger(nextValue())
            case "--queue-capacity":
                maximumPendingDirectories = try positiveInteger(nextValue())
            case "--stream-capacity":
                streamBufferCapacity = try positiveInteger(nextValue())
            case "--batch-size":
                persistenceBatchSize = try positiveInteger(nextValue())
            case "--cancel-after-ms":
                cancelAfter = .milliseconds(try positiveInteger(nextValue()))
            case "--launch-context":
                launchContext = try nextValue()
            case "--help", "-h":
                printUsageAndExit()
            default:
                throw BenchmarkError.invalidArguments
            }
            index += 1
        }

        guard let fixture, repeatCount <= 100 else {
            throw BenchmarkError.invalidArguments
        }
        if fixture == .path, rootURL == nil {
            throw BenchmarkError.invalidArguments
        }
        return Self(
            fixture: fixture,
            rootURL: rootURL,
            repeatCount: repeatCount,
            maximumWorkers: maximumWorkers,
            maximumPendingDirectories: maximumPendingDirectories,
            streamBufferCapacity: streamBufferCapacity,
            persistenceBatchSize: persistenceBatchSize,
            cancelAfter: cancelAfter,
            launchContext: launchContext
        )
    }
}

private struct BenchmarkReport: Codable {
    let schemaVersion: Int
    let fixture: String
    let rootDescription: String
    let repetition: Int
    let osVersion: String
    let osBuild: String
    let architecture: String
    let hardwareModel: String
    let physicalMemoryBytes: UInt64
    let launchContext: String
    let maximumWorkers: Int
    let maximumPendingDirectories: Int
    let streamBufferCapacity: Int
    let persistenceBatchSize: Int
    let entryCount: Int
    let regularFileCount: Int
    let directoryCount: Int
    let symlinkCount: Int
    let logicalFileBytes: Int64
    let allocatedFileBytes: Int64
    let permissionFailureCount: Int
    let errorCount: Int
    let firstUsefulResultMilliseconds: Double?
    let elapsedMilliseconds: Double
    let entriesPerSecond: Double
    let peakResidentMemoryBytes: UInt64
    let storeBytes: UInt64
    let terminalState: String
    let cancelled: Bool
    let cancellationLatencyMilliseconds: Double?
}

private func runBenchmark(
    options: BenchmarkOptions,
    repetition: Int
) async throws -> BenchmarkReport {
    let fixture: BenchmarkFixture
    switch options.fixture {
    case .synthetic:
        fixture = try createSyntheticFixture()
    case .path:
        fixture = BenchmarkFixture(
            rootURL: options.rootURL!,
            description: describeRoot(options.rootURL!),
            cleanup: {}
        )
    }
    defer { fixture.cleanup() }

    let storeRoot = FileManager.default.temporaryDirectory.appending(
        path: "stornaut-surveyor-benchmark-store-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: storeRoot,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: storeRoot) }
    let configuration = try LocalStoreConfiguration(
        applicationSupportBaseURL: storeRoot.appending(path: "Application Support"),
        cachesBaseURL: storeRoot.appending(path: "Caches")
    )
    let store = try EvidenceStore(configuration: configuration)
    let writer = ScanSessionWriter(store: store)
    let request = ScanRequest(
        rootURL: fixture.rootURL,
        maximumWorkers: options.maximumWorkers,
        maximumPendingDirectories: options.maximumPendingDirectories,
        streamBufferCapacity: options.streamBufferCapacity,
        persistenceBatchSize: options.persistenceBatchSize
    )
    let clock = ContinuousClock()
    let started = clock.now
    let stream = try await writer.run(request)
    let collector = Task {
        var aggregate = BenchmarkAggregate()
        for try await event in stream {
            aggregate.consume(
                event,
                elapsedMilliseconds: started.duration(to: clock.now).milliseconds
            )
        }
        return aggregate
    }

    var cancellationStart: ContinuousClock.Instant?
    if let cancelAfter = options.cancelAfter {
        try await Task.sleep(for: cancelAfter)
        cancellationStart = clock.now
        await writer.cancelActiveScan()
    }
    let aggregate = try await collector.value
    let finished = clock.now
    let elapsed = started.duration(to: finished).milliseconds
    let cancellationLatency = cancellationStart.map {
        $0.duration(to: finished).milliseconds
    }
    let system = systemEvidence()
    let fileSize = try FileManager.default.attributesOfItem(
        atPath: configuration.evidenceDatabaseURL.path
    )[.size] as? NSNumber

    return BenchmarkReport(
        schemaVersion: 2,
        fixture: options.fixture.rawValue,
        rootDescription: fixture.description,
        repetition: repetition,
        osVersion: system.osVersion,
        osBuild: system.osBuild,
        architecture: system.architecture,
        hardwareModel: system.hardwareModel,
        physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
        launchContext: options.launchContext,
        maximumWorkers: options.maximumWorkers,
        maximumPendingDirectories: options.maximumPendingDirectories,
        streamBufferCapacity: options.streamBufferCapacity,
        persistenceBatchSize: options.persistenceBatchSize,
        entryCount: aggregate.entryCount,
        regularFileCount: aggregate.regularFileCount,
        directoryCount: aggregate.directoryCount,
        symlinkCount: aggregate.symlinkCount,
        logicalFileBytes: aggregate.logicalFileBytes,
        allocatedFileBytes: aggregate.allocatedFileBytes,
        permissionFailureCount: aggregate.permissionFailureCount,
        errorCount: aggregate.errorCount,
        firstUsefulResultMilliseconds:
            aggregate.firstUsefulResultMilliseconds,
        elapsedMilliseconds: elapsed,
        entriesPerSecond: elapsed > 0
            ? Double(aggregate.entryCount) / (elapsed / 1_000)
            : 0,
        peakResidentMemoryBytes: peakResidentMemoryBytes(),
        storeBytes: fileSize?.uint64Value ?? 0,
        terminalState: aggregate.terminalState.rawValue,
        cancelled: aggregate.terminalState == .cancelled,
        cancellationLatencyMilliseconds: cancellationLatency
    )
}

private struct BenchmarkAggregate {
    var entryCount = 0
    var regularFileCount = 0
    var directoryCount = 0
    var symlinkCount = 0
    var logicalFileBytes: Int64 = 0
    var allocatedFileBytes: Int64 = 0
    var permissionFailureCount = 0
    var errorCount = 0
    var firstUsefulResultMilliseconds: Double?

    var terminalState: ScanTerminalState = .failed

    mutating func consume(
        _ event: QuickScanEvent,
        elapsedMilliseconds: Double
    ) {
        switch event {
        case let .progress(progress):
            let counters = progress.counters
            regularFileCount = max(
                regularFileCount,
                counters.regularFileCount
            )
            directoryCount = max(directoryCount, counters.directoryCount)
            symlinkCount = max(symlinkCount, counters.symlinkCount)
            logicalFileBytes = max(logicalFileBytes, counters.logicalFileBytes)
            allocatedFileBytes = max(
                allocatedFileBytes,
                counters.allocatedFileBytes
            )
        case let .factObserved(.pathSnapshot(snapshot)):
            entryCount += 1
            firstUsefulResultMilliseconds =
                firstUsefulResultMilliseconds ?? elapsedMilliseconds
            if snapshot.issue == .permissionDenied {
                permissionFailureCount += 1
            }
        case let .issueObserved(issue):
            if issue.issue != .mountBoundary {
                errorCount += 1
            }
        case let .terminal(session):
            terminalState = session.terminalState
        case .stageChanged, .factObserved(.volumeBaseline), .scopeFinished:
            break
        }
    }
}

private func validate(
    _ report: BenchmarkReport,
    options: BenchmarkOptions,
    reference: BenchmarkReport?
) throws {
    guard report.peakResidentMemoryBytes <= 256 * 1_024 * 1_024,
          report.elapsedMilliseconds < 5 * 60 * 1_000,
          report.storeBytes > 0
    else {
        throw BenchmarkError.acceptanceFailed
    }
    if options.cancelAfter != nil {
        guard report.terminalState == ScanTerminalState.cancelled.rawValue,
              report.cancelled,
              report.cancellationLatencyMilliseconds.map({ $0 < 1_000 }) == true
        else {
            throw BenchmarkError.acceptanceFailed
        }
        return
    }
    guard report.terminalState == ScanTerminalState.completed.rawValue,
          !report.cancelled,
          report.firstUsefulResultMilliseconds != nil
    else {
        throw BenchmarkError.acceptanceFailed
    }
    if options.fixture == .synthetic {
        guard report.entryCount == 1_356,
              report.regularFileCount == 804,
              report.directoryCount == 551,
              report.symlinkCount == 1,
              report.logicalFileBytes == 68_167_269,
              report.allocatedFileBytes > 0
        else {
            throw BenchmarkError.acceptanceFailed
        }
        if let reference {
            guard report.entryCount == reference.entryCount,
                  report.regularFileCount == reference.regularFileCount,
                  report.directoryCount == reference.directoryCount,
                  report.symlinkCount == reference.symlinkCount,
                  report.logicalFileBytes == reference.logicalFileBytes,
                  report.allocatedFileBytes == reference.allocatedFileBytes
            else {
                throw BenchmarkError.acceptanceFailed
            }
        }
    }
}

private struct BenchmarkFixture {
    let rootURL: URL
    let description: String
    let cleanup: () -> Void
}

private func createSyntheticFixture() throws -> BenchmarkFixture {
    let root = FileManager.default.temporaryDirectory
        .appending(
            path: "stornaut-surveyor-benchmark-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
    let script = URL(filePath: FileManager.default.currentDirectoryPath)
        .appending(path: "Tests/Fixtures/Surveyor/generate-fixture.sh")
    try runFixtureScript(script, command: "generate", root: root)

    return BenchmarkFixture(
        rootURL: root,
        description: "generated-synthetic-v1",
        cleanup: {
            try? runFixtureScript(script, command: "clean", root: root)
        }
    )
}

private func runFixtureScript(
    _ script: URL,
    command: String,
    root: URL
) throws {
    let process = Process()
    process.executableURL = script
    process.arguments = [command, root.path]
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw BenchmarkError.fixtureFailed
    }
}

private func describeRoot(_ root: URL) -> String {
    let canonical = root.standardizedFileURL.resolvingSymlinksInPath()
    if canonical.path == "/" {
        return "filesystem-root"
    }
    if canonical == FileManager.default.homeDirectoryForCurrentUser
        .standardizedFileURL.resolvingSymlinksInPath()
    {
        return "current-user-home"
    }
    return "caller-provided-read-only-root"
}

private func systemEvidence() -> (
    osVersion: String,
    osBuild: String,
    architecture: String,
    hardwareModel: String
) {
    let version = ProcessInfo.processInfo.operatingSystemVersion
    return (
        "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
        sysctlString("kern.osversion"),
        sysctlString("hw.machine"),
        sysctlString("hw.model")
    )
}

private func sysctlString(_ name: String) -> String {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else {
        return "unknown"
    }
    var bytes = [CChar](repeating: 0, count: size)
    guard sysctlbyname(name, &bytes, &size, nil, 0) == 0 else {
        return "unknown"
    }
    let end = bytes.firstIndex(of: 0) ?? bytes.endIndex
    return String(decoding: bytes[..<end].map(UInt8.init(bitPattern:)), as: UTF8.self)
}

private func peakResidentMemoryBytes() -> UInt64 {
    var usage = rusage()
    guard getrusage(RUSAGE_SELF, &usage) == 0 else {
        return 0
    }
    return UInt64(max(0, usage.ru_maxrss))
}

private func positiveInteger(_ value: String) throws -> Int {
    guard let integer = Int(value), integer > 0 else {
        throw BenchmarkError.invalidArguments
    }
    return integer
}

private func printUsageAndExit() -> Never {
    print(
        """
        Usage:
          SurveyorBenchmark --fixture synthetic [--repeat N] [--batch-size N]
          SurveyorBenchmark --fixture path --root /absolute/path [--cancel-after-ms N]

        Bounds:
          workers <= 64, queue <= 65536, stream <= 16384, batch <= 100
        """
    )
    exit(0)
}

private enum BenchmarkError: Error {
    case acceptanceFailed
    case invalidArguments
    case fixtureFailed
}

private extension Duration {
    var milliseconds: Double {
        let components = self.components
        return Double(components.seconds) * 1_000
            + Double(components.attoseconds) / 1_000_000_000_000_000
    }
}
