import CryptoKit
import Darwin
import Foundation
import SQLite3
import Testing
@testable import StornautCore

@Test(
    .enabled(
        if: ProcessInfo.processInfo.environment[
            "STORNAUT_RUN_TASK37_CAPACITY_BENCHMARK"
        ] == "1",
        "Task 37 Release production Store capacity benchmark"
    )
)
func investigationStoreCapacityBenchmark() async throws {
    let fixture = try await Task37CapacityFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let sampleCount = 3

    var samples: [Task37CapacitySample] = []
    var insertedTemplateURL: URL?
    for sampleIndex in 0..<sampleCount {
        let configuration = try fixture.copySourceFixture(
            operation: "insertion",
            sampleIndex: sampleIndex
        )
        samples.append(
            try fixture.runWorker(
                operation: "insertion",
                sampleIndex: sampleIndex,
                configuration: configuration
            )
        )
        if sampleIndex == 0 {
            insertedTemplateURL = fixture.insertedTemplateURL
            try fixture.copyDatabase(
                from: configuration.evidenceDatabaseURL,
                to: fixture.insertedTemplateURL
            )
        }
        try FileManager.default.removeItem(
            at: configuration.applicationSupportBaseURL!
                .deletingLastPathComponent()
        )
    }
    let insertedTemplate = try #require(insertedTemplateURL)

    for sampleIndex in 0..<sampleCount {
        let configuration = try fixture.copyDatabaseFixture(
            from: insertedTemplate,
            operation: "rejoin",
            sampleIndex: sampleIndex
        )
        samples.append(
            try fixture.runWorker(
                operation: "rejoin",
                sampleIndex: sampleIndex,
                configuration: configuration
            )
        )
        try FileManager.default.removeItem(
            at: configuration.applicationSupportBaseURL!
                .deletingLastPathComponent()
        )
    }

    for sampleIndex in 0..<sampleCount {
        let configuration = try fixture.copyDatabaseFixture(
            from: insertedTemplate,
            operation: "terminal",
            sampleIndex: sampleIndex
        )
        let store = try fixture.store(configuration: configuration)
        try await fixture.enterTerminalBarrier(
            store: store,
            cause: .coverageReached
        )
        samples.append(
            try fixture.runWorker(
                operation: "terminal",
                sampleIndex: sampleIndex,
                configuration: configuration
            )
        )
        try FileManager.default.removeItem(
            at: configuration.applicationSupportBaseURL!
                .deletingLastPathComponent()
        )
    }

    try fixture.copyDatabase(
        from: insertedTemplate,
        to: fixture.recoveryTemplateURL
    )
    do {
        let store = try fixture.store(
            configuration: fixture.recoveryTemplateConfiguration
        )
        try await fixture.enterTerminalBarrier(
            store: store,
            cause: .coverageReached
        )
    }
    for sampleIndex in 0..<sampleCount {
        let configuration = try fixture.copyDatabaseFixture(
            from: fixture.recoveryTemplateURL,
            operation: "recovery",
            sampleIndex: sampleIndex
        )
        samples.append(
            try fixture.runWorker(
                operation: "recovery",
                sampleIndex: sampleIndex,
                configuration: configuration
            )
        )
        try FileManager.default.removeItem(
            at: configuration.applicationSupportBaseURL!
                .deletingLastPathComponent()
        )
    }

    let partialCommand = try await fixture.maximumTerminalCommand(
        configuration: fixture.insertedTemplateConfiguration,
        kind: .partial
    )
    try fixture.copyDatabase(
        from: insertedTemplate,
        to: fixture.continuationTemplateURL
    )
    do {
        let store = try fixture.store(
            configuration: fixture.continuationTemplateConfiguration
        )
        try await fixture.enterTerminalBarrier(
            store: store,
            cause: .paused
        )
        _ = try await store.commitInvestigationTerminal(partialCommand)
    }
    for sampleIndex in 0..<sampleCount {
        let configuration = try fixture.copyDatabaseFixture(
            from: fixture.continuationTemplateURL,
            operation: "continuation",
            sampleIndex: sampleIndex
        )
        samples.append(
            try fixture.runWorker(
                operation: "continuation",
                sampleIndex: sampleIndex,
                configuration: configuration
            )
        )
        try FileManager.default.removeItem(
            at: configuration.applicationSupportBaseURL!
                .deletingLastPathComponent()
        )
    }

    #expect(samples.count == sampleCount * 5)
    #expect(samples.count == 15)
    #expect(samples.allSatisfy { $0.durationSeconds <= 75 })
    #expect(
        samples.allSatisfy {
            $0.peakIncrement <= Task37CapacityFixture.maximumPeakIncrement
        }
    )
    #expect(samples.allSatisfy { $0.operationAdvancedLifetimePeak })
    let worst = try #require(
        samples.max { $0.durationSeconds < $1.durationSeconds }
    )
    print(
        "Task 37 capacity environment:",
        "machine=\(fixture.machine)",
        "build=release+-DDEBUG",
        "journal=DELETE",
        "synchronous=FULL",
        "busyTimeoutMs=2000",
        "sourceFixtureSHA256=\(fixture.sourceFixtureSHA256)",
        "terminalFixtureSHA256=\(fixture.terminalFixtureSHA256)"
    )
    for sample in samples {
        print(
            "Task 37 capacity sample:",
            "operation=\(sample.operation)",
            "sample=\(sample.sampleIndex + 1)",
            "durationSeconds=\(sample.durationSeconds)",
            "baselineFootprint=\(sample.baselineFootprint)",
            "baselineLifetimePeak=\(sample.baselineLifetimePeak)",
            "peakFootprint=\(sample.peakFootprint)",
            "peakIncrement=\(sample.peakIncrement)",
            "databaseBytes=\(sample.databaseBytes)"
        )
    }
    print(
        "Task 37 capacity worst:",
        "operation=\(worst.operation)",
        "sample=\(worst.sampleIndex + 1)",
        "durationSeconds=\(worst.durationSeconds)"
    )
}

private extension Collection {
    var only: Element? {
        count == 1 ? first : nil
    }
}

@Test(
    .enabled(
        if: ProcessInfo.processInfo.environment[
            "STORNAUT_TASK37_CAPACITY_WORKER"
        ] == "1",
        "Task 37 isolated capacity operation worker"
    )
)
func investigationStoreCapacityBenchmarkWorker() async throws {
    let environment = ProcessInfo.processInfo.environment
    let rootPath = try #require(
        environment["STORNAUT_TASK37_CAPACITY_ROOT"]
    )
    let configurationRootPath = try #require(
        environment["STORNAUT_TASK37_CAPACITY_CONFIGURATION_ROOT"]
    )
    let operation = try #require(
        environment["STORNAUT_TASK37_CAPACITY_OPERATION"]
    )
    let sampleIndex = try #require(
        Int(environment["STORNAUT_TASK37_CAPACITY_SAMPLE"] ?? "")
    )
    let resultPath = try #require(
        environment["STORNAUT_TASK37_CAPACITY_RESULT"]
    )
    let fixture = try Task37CapacityFixture(
        existingRoot: URL(fileURLWithPath: rootPath, isDirectory: true)
    )
    let configuration = try Task37CapacityFixture.configuration(
        root: URL(
            fileURLWithPath: configurationRootPath,
            isDirectory: true
        )
    )
    let sample = try await fixture.measureIsolatedOperation(
        operation: operation,
        sampleIndex: sampleIndex,
        configuration: configuration
    )
    let resultURL = URL(fileURLWithPath: resultPath)
    try JSONEncoder().encode(sample).write(to: resultURL, options: .atomic)
}

private struct Task37CapacitySample: Codable {
    let operation: String
    let sampleIndex: Int
    let durationSeconds: Double
    let baselineFootprint: UInt64
    let baselineLifetimePeak: UInt64
    let peakFootprint: UInt64
    let peakIncrement: UInt64
    let databaseBytes: UInt64

    var operationAdvancedLifetimePeak: Bool {
        peakFootprint > baselineLifetimePeak
    }
}

private struct Task37CapacityFixture {
    static let maximumPeakIncrement: UInt64 = 218_103_808

    let root: URL
    let sourceConfiguration: LocalStoreConfiguration
    let sourceFixtureSHA256: String
    let terminalFixtureSHA256: String
    let investigationID = InvestigationID(
        rawValue: "investigation-capacity-production"
    )!
    let initialRunID = InvestigationRunID(
        rawValue: "investigation-run-capacity-production"
    )!
    let continuationRunID = InvestigationRunID(
        rawValue: "investigation-run-capacity-continuation"
    )!
    let planningAt = Date(timeIntervalSince1970: 1_800_000_001)
    let terminalAt = Date(timeIntervalSince1970: 1_800_000_010)
    let source: Task37MaximumSource
    private let clock = ContinuousClock()
    private let footprint = Task37Footprint()

    init() async throws {
        root = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-task37-production-capacity-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        source = try Task37MaximumSource()
        sourceConfiguration = try Self.configuration(
            root: root.appending(path: "source", directoryHint: .isDirectory)
        )
        do {
            let store = try EvidenceStore(configuration: sourceConfiguration)
            _ = try await store.diagnostics()
        }
        try source.install(at: sourceConfiguration.evidenceDatabaseURL)
        sourceFixtureSHA256 = try Self.fileSHA256(
            sourceConfiguration.evidenceDatabaseURL
        )
        terminalFixtureSHA256 = Self.sha256(
            """
            task37-terminal-v1|evidence=512|max-typed-summary=8192|\
            max-typed-uncertainty=2048|degradations=64|\
            budget-events=4096|report-summary=8192
            """
        )
    }

    init(existingRoot: URL) throws {
        root = existingRoot
        source = try Task37MaximumSource()
        sourceConfiguration = try Self.configuration(
            root: root.appending(path: "source", directoryHint: .isDirectory)
        )
        sourceFixtureSHA256 = "parent-verified"
        terminalFixtureSHA256 = Self.sha256(
            """
            task37-terminal-v1|evidence=512|max-typed-summary=8192|\
            max-typed-uncertainty=2048|degradations=64|\
            budget-events=4096|report-summary=8192
            """
        )
    }

    var insertedTemplateURL: URL {
        insertedTemplateConfiguration.evidenceDatabaseURL
    }

    var insertedTemplateConfiguration: LocalStoreConfiguration {
        try! Self.configuration(
            root: root.appending(
                path: "inserted-template",
                directoryHint: .isDirectory
            )
        )
    }

    var recoveryTemplateURL: URL {
        recoveryTemplateConfiguration.evidenceDatabaseURL
    }

    var recoveryTemplateConfiguration: LocalStoreConfiguration {
        try! Self.configuration(
            root: root.appending(
                path: "recovery-template",
                directoryHint: .isDirectory
            )
        )
    }

    var continuationTemplateURL: URL {
        continuationTemplateConfiguration.evidenceDatabaseURL
    }

    var continuationTemplateConfiguration: LocalStoreConfiguration {
        try! Self.configuration(
            root: root.appending(
                path: "continuation-template",
                directoryHint: .isDirectory
            )
        )
    }

    var machine: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var bytes = [CChar](repeating: 0, count: max(size, 1))
        sysctlbyname("hw.model", &bytes, &size, nil, 0)
        return String(decoding: bytes.prefix { $0 != 0 }.map(UInt8.init), as: UTF8.self)
    }

    func store(
        configuration: LocalStoreConfiguration
    ) throws -> EvidenceStore {
        let now = terminalAt
        return try EvidenceStore(
            configuration: configuration,
            testHooks: EvidenceStoreTestHooks(now: { now })
        )
    }

    func createInvestigation(
        configuration: LocalStoreConfiguration
    ) async throws -> InvestigationStoredSession {
        let progress = Task37CapacityProgressRecorder()
        let store = try EvidenceStore(
            configuration: configuration,
            investigationProgress: { progress.record($0) }
        )
        defer {
            if ProcessInfo.processInfo.environment[
                "STORNAUT_TASK37_PROGRESS_DIAGNOSTIC"
            ] == "1" {
                print(
                    "Task 37 progress diagnostic:",
                    progress.timeline.joined(separator: " | ")
                )
            }
        }
        let created = try await store.createInvestigation(
            InvestigationCreateCommand(
                investigationID: investigationID,
                initialRunID: initialRunID,
                scanSessionID: source.session.id,
                scanScopeID: source.scopeID,
                budgetPreset: .thorough,
                planningAt: planningAt,
                relevanceTokens: source.relevanceTokens
            )
        )
        #expect(created.sourceRowCount == 300_002)
        #expect(created.plan.targets.count == 512)
        return created
    }

    func enterTerminalBarrier(
        store: EvidenceStore,
        cause: InvestigationTerminalCause
    ) async throws {
        for command in try transitionCommands(cause: cause) {
            _ = try await store.transitionInvestigationRun(command)
        }
    }

    func maximumTerminalCommand(
        configuration: LocalStoreConfiguration,
        kind: InvestigationReportKind
    ) async throws -> InvestigationTerminalCommand {
        let store = try store(configuration: configuration)
        let session = try #require(
            try await store.investigation(id: investigationID)
        )
        let unresolved = kind == .partial
        let evidencePayload = try InvestigationEvidencePayload(
            summary: Self.noncompressibleText(count: 8_192, seed: 1),
            confidence: DomainToken(
                rawValue: String(repeating: "c", count: 128)
            )!,
            uncertainty: Self.noncompressibleText(count: 2_048, seed: 2),
            webProvenance: PersistedWebProvenance(
                sanitizing: Self.maximumPublicHTTPSOrigin,
                transport: .publicInternet
            )
        )
        let evidence = session.plan.targets.enumerated().map {
            index, target in
            InvestigationEvidenceInput(
                id: InvestigationEvidenceID(
                    rawValue: String(
                        format: "investigation-evidence-capacity-%04d",
                        index
                    )
                )!,
                targetID: target.id,
                kind: unresolved ? .unresolved : .finding,
                payload: evidencePayload
            )
        }
        let degradationPayload = try Self.maximumDegradationPayload()
        let degradations = (0..<64).map { index in
            InvestigationDegradationInput(
                id: InvestigationDegradationID(
                    rawValue: String(
                        format: "investigation-degradation-capacity-%02d",
                        index
                    )
                )!,
                kind: .runtimeLimited,
                payload: degradationPayload
            )
        }
        let maximumToken = DomainToken(
            rawValue: String(repeating: "b", count: 128)
        )!
        let budgets = (0..<4_096).map { index in
            InvestigationBudgetEventInput(
                id: InvestigationBudgetEventID(
                    rawValue: String(
                        format: "investigation-budget-event-capacity-%04d",
                        index
                    )
                )!,
                ordinal: UInt64(index),
                kind: index == 4_095 ? .terminalSummary : .reservation,
                payload: InvestigationBudgetEventPayload(
                    dimension: maximumToken,
                    amount: .max,
                    quality: maximumToken
                )
            )
        }
        return try InvestigationTerminalCommand(
            investigationID: investigationID,
            runID: initialRunID,
            runState: kind == .final ? .completed : .partial,
            sessionState: kind == .final ? .completed : .partial,
            stage: .buildPlan,
            cause: kind == .final ? .coverageReached : .paused,
            report: InvestigationTerminalReportInput(
                id: InvestigationReportID(
                    rawValue: kind == .final
                        ? "investigation-report-capacity-final"
                        : "investigation-report-capacity-partial"
                )!,
                kind: kind,
                payload: try InvestigationReportPayload(
                    summary: Self.noncompressibleText(
                        count: 8_192,
                        seed: 3
                    )
                ),
                evidence: evidence,
                degradations: degradations
            ),
            budgetEvents: budgets,
            terminalAt: terminalAt
        )
    }

    func runWorker(
        operation: String,
        sampleIndex: Int,
        configuration: LocalStoreConfiguration
    ) throws -> Task37CapacitySample {
        let resultURL = root.appending(
            path: "worker-\(operation)-\(sampleIndex + 1).json"
        )
        let logURL = root.appending(
            path: "worker-\(operation)-\(sampleIndex + 1).log"
        )
        FileManager.default.createFile(
            atPath: logURL.path,
            contents: nil
        )
        let log = try FileHandle(forWritingTo: logURL)
        defer { try? log.close() }

        let testExecutable = try Self.testExecutableURL()
        let helperURL = URL(
            fileURLWithPath:
                "/Applications/Xcode.app/Contents/Developer/Toolchains/"
                    + "XcodeDefault.xctoolchain/usr/libexec/swift/pm/"
                    + "swiftpm-testing-helper"
        )
        let process = Process()
        process.executableURL = helperURL
        process.arguments = [
            "--test-bundle-path",
            testExecutable.path,
            "-c",
            "release",
            "--no-parallel",
            "--filter",
            "investigationStoreCapacityBenchmarkWorker",
            testExecutable.path,
            "--testing-library",
            "swift-testing",
        ]
        var environment = ProcessInfo.processInfo.environment
        environment["STORNAUT_RUN_TASK37_CAPACITY_BENCHMARK"] = nil
        environment["STORNAUT_TASK37_CAPACITY_WORKER"] = "1"
        environment["STORNAUT_TASK37_CAPACITY_ROOT"] = root.path
        environment["STORNAUT_TASK37_CAPACITY_CONFIGURATION_ROOT"] =
            configuration.applicationSupportBaseURL!
                .deletingLastPathComponent()
                .path
        environment["STORNAUT_TASK37_CAPACITY_OPERATION"] = operation
        environment["STORNAUT_TASK37_CAPACITY_SAMPLE"] = String(sampleIndex)
        environment["STORNAUT_TASK37_CAPACITY_RESULT"] = resultURL.path
        environment["DYLD_FRAMEWORK_PATH"] =
            "/Applications/Xcode.app/Contents/Developer/Platforms/"
                + "MacOSX.platform/Developer/Library/Frameworks"
        process.environment = environment
        process.standardOutput = log
        process.standardError = log
        try process.run()
        process.waitUntilExit()

        guard process.terminationReason == .exit,
              process.terminationStatus == 0,
              FileManager.default.fileExists(atPath: resultURL.path)
        else {
            try? log.synchronize()
            let output = (try? String(contentsOf: logURL, encoding: .utf8))
                ?? "<worker log unavailable>"
            throw Task37CapacityError.workerFailed(
                status: process.terminationStatus,
                output: output
            )
        }
        if ProcessInfo.processInfo.environment[
            "STORNAUT_TASK37_PROGRESS_DIAGNOSTIC"
        ] == "1" {
            try? log.synchronize()
            if let output = try? String(contentsOf: logURL, encoding: .utf8) {
                print(output)
            }
        }
        return try JSONDecoder().decode(
            Task37CapacitySample.self,
            from: Data(contentsOf: resultURL)
        )
    }

    func measureIsolatedOperation(
        operation: String,
        sampleIndex: Int,
        configuration: LocalStoreConfiguration
    ) async throws -> Task37CapacitySample {
        let operationBody = try await isolatedOperation(
            operation,
            configuration: configuration
        )
        let baseline = try footprint.sample()
        let baselinePeak = try footprint.peak()
        let started = clock.now
        try await operationBody()
        let duration = started.duration(to: clock.now)
        let current = try footprint.sample()
        let peak = try footprint.peak()
        let observed = max(current, peak)
        guard observed >= baseline,
              peak >= baselinePeak,
              peak > baselinePeak
        else {
            throw Task37CapacityError.invalidPeakMeasurement
        }
        let databaseBytes = try configuration.evidenceDatabaseURL
            .resourceValues(
            forKeys: [.fileSizeKey]
        ).fileSize ?? 0
        let sample = Task37CapacitySample(
            operation: operation,
            sampleIndex: sampleIndex,
            durationSeconds: Self.seconds(duration),
            baselineFootprint: baseline,
            baselineLifetimePeak: baselinePeak,
            peakFootprint: observed,
            peakIncrement: observed - baseline,
            databaseBytes: UInt64(databaseBytes)
        )
        guard sample.durationSeconds <= 75,
              sample.peakIncrement <= Self.maximumPeakIncrement
        else {
            throw Task37CapacityError.capacityExceeded(
                durationSeconds: sample.durationSeconds,
                peakIncrement: sample.peakIncrement
            )
        }
        return sample
    }

    private func isolatedOperation(
        _ operation: String,
        configuration: LocalStoreConfiguration
    ) async throws -> () async throws -> Void {
        switch operation {
        case "insertion":
            return {
                _ = try await createInvestigation(
                    configuration: configuration
                )
            }
        case "rejoin":
            let store = try store(configuration: configuration)
            return {
                guard try await store.rejoinInvestigation(
                    id: investigationID,
                    barrier: .activeRunRefresh
                ) == .matching else {
                    throw Task37CapacityError.invalidFixture
                }
            }
        case "terminal":
            let command = try await maximumTerminalCommand(
                configuration: insertedTemplateConfiguration,
                kind: .final
            )
            let store = try store(configuration: configuration)
            return {
                _ = try await store.commitInvestigationTerminal(command)
            }
        case "recovery":
            let command = try await maximumTerminalCommand(
                configuration: insertedTemplateConfiguration,
                kind: .final
            )
            let store = try store(configuration: configuration)
            return {
                _ = try await store.promoteInvestigationRecovery(command)
            }
        case "continuation":
            let command = try InvestigationContinuationCommand(
                investigationID: investigationID,
                parentRunID: initialRunID,
                parentReportID: InvestigationReportID(
                    rawValue: "investigation-report-capacity-partial"
                )!,
                newRunID: continuationRunID,
                budgetPreset: .thorough,
                planningAt: terminalAt.addingTimeInterval(1)
            )
            let store = try store(configuration: configuration)
            return {
                let child = try await store
                    .createInvestigationContinuation(command)
                guard child.plan.targets.count == 512 else {
                    throw Task37CapacityError.invalidFixture
                }
            }
        default:
            throw Task37CapacityError.invalidOperation(operation)
        }
    }

    func copySourceFixture(
        operation: String,
        sampleIndex: Int
    ) throws -> LocalStoreConfiguration {
        try copyDatabaseFixture(
            from: sourceConfiguration.evidenceDatabaseURL,
            operation: operation,
            sampleIndex: sampleIndex
        )
    }

    func copyDatabaseFixture(
        from source: URL,
        operation: String,
        sampleIndex: Int
    ) throws -> LocalStoreConfiguration {
        let configuration = try Self.configuration(
            root: root.appending(
                path: "\(operation)-\(sampleIndex + 1)",
                directoryHint: .isDirectory
            )
        )
        try copyDatabase(from: source, to: configuration.evidenceDatabaseURL)
        return configuration
    }

    func copyDatabase(from source: URL, to destination: URL) throws {
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.copyItem(at: source, to: destination)
    }

    private func transitionCommands(
        cause: InvestigationTerminalCause
    ) throws -> [InvestigationRunTransitionCommand] {
        [
            try InvestigationRunTransitionCommand(
                investigationID: investigationID,
                runID: initialRunID,
                expectedRunState: .planned,
                runState: .ready,
                sessionState: .ready,
                stage: .prioritize,
                updatedAt: planningAt.addingTimeInterval(1)
            ),
            try InvestigationRunTransitionCommand(
                investigationID: investigationID,
                runID: initialRunID,
                expectedRunState: .ready,
                runState: .running,
                sessionState: .running,
                stage: .identify,
                updatedAt: planningAt.addingTimeInterval(2)
            ),
            try InvestigationRunTransitionCommand(
                investigationID: investigationID,
                runID: initialRunID,
                expectedRunState: .running,
                runState: .terminalBarrier,
                sessionState: .terminalBarrier,
                stage: .verify,
                terminalCause: cause,
                updatedAt: planningAt.addingTimeInterval(3)
            ),
        ]
    }

    private static func maximumDegradationPayload()
        throws -> InvestigationDegradationPayload
    {
        let reason = DomainToken(
            rawValue: String(repeating: "d", count: 128)
        )!
        for count in stride(from: 8_192, through: 1, by: -1) {
            let payload = try InvestigationDegradationPayload(
                reasonKey: reason,
                summary: String(repeating: "x", count: count)
            )
            if try DomainJSON.encode(payload).count <= 8_192 {
                return payload
            }
        }
        throw Task37CapacityError.invalidFixture
    }

    private static var maximumPublicHTTPSOrigin: String {
        let labels = [
            String(repeating: "a", count: 63),
            String(repeating: "b", count: 63),
            String(repeating: "c", count: 63),
            String(repeating: "d", count: 57),
        ]
        return "https://\(labels.joined(separator: "."))/"
    }

    private static func noncompressibleText(
        count: Int,
        seed: UInt64
    ) -> String {
        String(decoding: Task37PRNG.bytes(count: count, seed: seed), as: UTF8.self)
    }

    static func configuration(
        root: URL
    ) throws -> LocalStoreConfiguration {
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        return try LocalStoreConfiguration(
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

    private static func fileSHA256(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = SHA256()
        while let data = try handle.read(upToCount: 1_048_576),
              !data.isEmpty
        {
            hash.update(data: data)
        }
        return Data(hash.finalize()).map {
            String(format: "%02x", $0)
        }.joined()
    }

    private static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map {
            String(format: "%02x", $0)
        }.joined()
    }

    private static func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }

    private static func testExecutableURL() throws -> URL {
        if let executable = Bundle.allBundles.lazy
            .filter({ $0.bundleURL.pathExtension == "xctest" })
            .compactMap(\.executableURL)
            .first(where: {
                $0.lastPathComponent == "StornautPackageTests"
            })
        {
            return executable.standardizedFileURL
        }
        if let argument = CommandLine.arguments.first(where: {
            $0.contains(".xctest/Contents/MacOS/StornautPackageTests")
        }) {
            return URL(fileURLWithPath: argument).standardizedFileURL
        }
        throw Task37CapacityError.testExecutableUnavailable
    }
}

private final class Task37CapacityProgressRecorder:
    @unchecked Sendable
{
    private let lock = NSLock()
    private let startedAt = DispatchTime.now().uptimeNanoseconds
    private var storage: [String] = []

    var timeline: [String] {
        lock.withLock { storage }
    }

    func record(_ progress: InvestigationStoreProgress) {
        lock.withLock {
            guard storage.last?.contains(
                "phase=\(progress.phase.rawValue) "
            ) != true else {
                return
            }
            let elapsed = DispatchTime.now().uptimeNanoseconds - startedAt
            let footprint = try? Task37Footprint().snapshot()
            storage.append(
                "phase=\(progress.phase.rawValue) "
                    + "seconds=\(Double(elapsed) / 1_000_000_000) "
                    + "rows=\(progress.checkedRows) "
                    + "bytes=\(progress.checkedBytes) "
                    + "currentFootprint=\(footprint?.current ?? 0) "
                    + "peakFootprint=\(footprint?.peak ?? 0)"
            )
        }
    }
}

private struct Task37MaximumSource {
    private static let marker = "999999"

    let session: ScanSession
    let scopeID: ScanScopeID
    let ledger: SpaceLedger
    let relevanceTokens: [DomainToken]
    let sessionPayload: String
    let ledgerPayload: String
    let snapshotTemplate: Task37PayloadTemplate
    let classificationTemplate: Task37PayloadTemplate
    let evidenceTemplate: Task37PayloadTemplate
    let maximumPaddingCount: Int
    let partialPaddingCount: Int
    let maximumPaddedSnapshotCount: Int

    init() throws {
        let sessionID = ScanSessionID(rawValue: "scan-capacity-production")!
        scopeID = ScanScopeID(rawValue: "scope-capacity-production")!
        let finishedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let rootPath = PersistedPath(rawValue: "/capacity")!
        let rootIdentity = try FileIdentity(
            device: 1,
            inode: 1,
            mode: UInt16(S_IFDIR | 0o755),
            ownerUserID: 501,
            ownerGroupID: 20,
            size: 0,
            allocatedBytes: 0,
            modificationSeconds: 1_800_000_000,
            modificationNanoseconds: 0
        )
        session = try ScanSession(
            id: sessionID,
            startedAt: finishedAt.addingTimeInterval(-60),
            finishedAt: finishedAt,
            terminalState: .completed,
            completedScopes: [
                ScanScope(
                    id: scopeID,
                    rootPath: rootPath,
                    completedAt: finishedAt
                ),
            ],
            unfinishedScopes: []
        )
        let start = try VolumeBaseline(
            sessionID: sessionID,
            scopeID: scopeID,
            rootPath: rootPath,
            rootIdentity: rootIdentity,
            totalCapacity: ByteCount(10 * 1_073_741_824),
            availableCapacity: ByteCount(5 * 1_073_741_824),
            availableCapacityForImportantUsage: nil,
            availableCapacityForOpportunisticUsage: nil,
            volumeIsReadOnly: false,
            source: AccountingSource(
                kind: .volumeResourceValues,
                identifier: DomainToken(rawValue: "capacity.start")!,
                sampledAt: finishedAt.addingTimeInterval(-60)
            )
        )
        let end = try VolumeBaseline(
            sessionID: sessionID,
            scopeID: scopeID,
            rootPath: rootPath,
            rootIdentity: rootIdentity,
            totalCapacity: ByteCount(10 * 1_073_741_824),
            availableCapacity: ByteCount(4 * 1_073_741_824),
            availableCapacityForImportantUsage: nil,
            availableCapacityForOpportunisticUsage: nil,
            volumeIsReadOnly: false,
            source: AccountingSource(
                kind: .volumeResourceValues,
                identifier: DomainToken(rawValue: "capacity.end")!,
                sampledAt: finishedAt
            )
        )
        ledger = try SpaceLedgerReconciler().reconcile(
            SpaceLedgerInput(
                startBaseline: start,
                endBaseline: end,
                snapshots: [],
                classifications: []
            )
        )
        relevanceTokens = [
            DomainToken(rawValue: "relevance.large")!,
            DomainToken(rawValue: "relevance.developer")!,
        ]
        sessionPayload = String(
            decoding: try DomainJSON.encode(session),
            as: UTF8.self
        )
        ledgerPayload = String(
            decoding: try DomainJSON.encode(ledger),
            as: UTF8.self
        )
        snapshotTemplate = try Task37PayloadTemplate(
            payload: DomainJSON.encode(
                try Self.snapshot(
                    index: 999_999,
                    sessionID: sessionID,
                    scopeID: scopeID,
                    finishedAt: finishedAt
                )
            ),
            marker: Self.marker,
            expectedOccurrences: 2
        )
        classificationTemplate = try Task37PayloadTemplate(
            payload: DomainJSON.encode(
                try Self.classification(index: 999_999, finishedAt: finishedAt)
            ),
            marker: Self.marker,
            expectedOccurrences: 2
        )
        evidenceTemplate = try Task37PayloadTemplate(
            payload: DomainJSON.encode(
                Self.evidence(index: 999_999, finishedAt: finishedAt)
            ),
            marker: Self.marker,
            expectedOccurrences: 2
        )
        let baseBytes = sessionPayload.utf8.count
            + ledgerPayload.utf8.count
            + 100_000 * (
                snapshotTemplate.renderedByteCount
                    + classificationTemplate.renderedByteCount
                    + evidenceTemplate.renderedByteCount
            )
        let additional = 268_435_456 - baseBytes
        guard additional > 0 else {
            throw Task37CapacityError.invalidFixture
        }
        maximumPaddingCount = 16_384 - "item-\(Self.marker)".utf8.count
        maximumPaddedSnapshotCount = additional / maximumPaddingCount
        partialPaddingCount = additional % maximumPaddingCount
        guard maximumPaddedSnapshotCount < 100_000 else {
            throw Task37CapacityError.invalidFixture
        }
    }

    func install(at url: URL) throws {
        let database = try Task37SQLiteDatabase(path: url.path)
        try database.execute("PRAGMA foreign_keys=ON")
        try database.execute("PRAGMA synchronous=FULL")
        try database.execute("BEGIN IMMEDIATE")
        do {
            try database.execute(
                """
                INSERT INTO scan_sessions
                (id, started_at_ms, finished_at_ms, expires_at_ms, payload)
                VALUES (?, ?, ?, ?, ?)
                """,
                bindings: [
                    .text(session.id.rawValue),
                    .integer(1_799_999_940_000),
                    .integer(1_800_000_000_000),
                    .integer(1_800_604_800_000),
                    .text(sessionPayload),
                ]
            )
            let snapshot = try database.statement(
                """
                INSERT INTO path_snapshots
                (id, session_id, relative_path, observed_at_ms, payload)
                VALUES (?, ?, ?, ?, ?)
                """
            )
            let classification = try database.statement(
                """
                INSERT INTO classifications
                (id, snapshot_id, disposition, classified_at_ms, payload)
                VALUES (?, ?, 'unknown', ?, ?)
                """
            )
            let evidence = try database.statement(
                """
                INSERT INTO evidence
                (id, snapshot_id, observed_at_ms, payload)
                VALUES (?, ?, ?, ?)
                """
            )
            defer {
                sqlite3_finalize(snapshot)
                sqlite3_finalize(classification)
                sqlite3_finalize(evidence)
            }
            var payloadBytes = sessionPayload.utf8.count
                + ledgerPayload.utf8.count
            for index in 0..<100_000 {
                let suffix = Self.padded(index)
                let snapshotID = "snapshot-capacity-\(suffix)"
                let paddingCount: Int
                if index < maximumPaddedSnapshotCount {
                    paddingCount = maximumPaddingCount
                } else if index == maximumPaddedSnapshotCount {
                    paddingCount = partialPaddingCount
                } else {
                    paddingCount = 0
                }
                let padding = Task37PRNG.bytes(
                    count: paddingCount,
                    seed: UInt64(index + 1)
                )
                let relativePath =
                    "item-\(suffix)" + String(decoding: padding, as: UTF8.self)
                let snapshotPayload = snapshotTemplate.render(
                    replacingWith: suffix,
                    appending: padding,
                    afterOccurrence: 2
                )
                let classificationPayload = classificationTemplate.render(
                    replacingWith: suffix
                )
                let evidencePayload = evidenceTemplate.render(
                    replacingWith: suffix
                )
                try database.step(
                    snapshot,
                    bindings: [
                        .text(snapshotID),
                        .text(session.id.rawValue),
                        .text(relativePath),
                        .integer(1_800_000_000_000),
                        .text(String(decoding: snapshotPayload, as: UTF8.self)),
                    ]
                )
                try database.step(
                    classification,
                    bindings: [
                        .text("classification-capacity-\(suffix)"),
                        .text(snapshotID),
                        .integer(1_800_000_000_000),
                        .text(
                            String(
                                decoding: classificationPayload,
                                as: UTF8.self
                            )
                        ),
                    ]
                )
                try database.step(
                    evidence,
                    bindings: [
                        .text("evidence-capacity-\(suffix)"),
                        .text(snapshotID),
                        .integer(1_800_000_000_000),
                        .text(String(decoding: evidencePayload, as: UTF8.self)),
                    ]
                )
                payloadBytes += snapshotPayload.count
                    + classificationPayload.count
                    + evidencePayload.count
            }
            guard payloadBytes == 268_435_456 else {
                throw Task37CapacityError.invalidFixture
            }
            try database.execute(
                """
                INSERT INTO space_accounting (id, session_id, payload)
                VALUES (?, ?, ?)
                """,
                bindings: [
                    .text(session.id.rawValue),
                    .text(session.id.rawValue),
                    .text(ledgerPayload),
                ]
            )
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
        try database.verify()
    }

    private static func snapshot(
        index: Int,
        sessionID: ScanSessionID,
        scopeID: ScanScopeID,
        finishedAt: Date
    ) throws -> PathSnapshot {
        let bytes: Int64 = 1_073_741_824
        return try PathSnapshot(
            id: SnapshotID(rawValue: "snapshot-capacity-\(padded(index))")!,
            sessionID: sessionID,
            scopeID: scopeID,
            relativePath: "item-\(padded(index))",
            kind: .regularFile,
            logicalByteCount: ByteCount(UInt64(bytes)),
            allocatedByteCount: ByteCount(UInt64(bytes)),
            modifiedAt: finishedAt,
            fileIdentity: FileIdentity(
                device: 1,
                inode: UInt64(index + 10),
                mode: UInt16(S_IFREG | 0o644),
                ownerUserID: 501,
                ownerGroupID: 20,
                size: bytes,
                allocatedBytes: bytes,
                modificationSeconds: 1_800_000_000,
                modificationNanoseconds: 0
            ),
            symlinkTarget: nil,
            measurementStatus: .measured,
            observedAt: finishedAt
        )
    }

    private static func classification(
        index: Int,
        finishedAt: Date
    ) throws -> Classification {
        try Classification(
            id: ClassificationID(
                rawValue: "classification-capacity-\(padded(index))"
            )!,
            snapshotID: SnapshotID(
                rawValue: "snapshot-capacity-\(padded(index))"
            )!,
            ruleID: nil,
            producer: nil,
            category: .unknownLargeConsumers,
            disposition: .unknown,
            risk: .medium,
            confidence: .high,
            recovery: nil,
            requiredEvidenceKeys: [],
            missingEvidenceKeys: [],
            catalogVersion: DomainToken(rawValue: "capacity.catalog")!,
            classifiedAt: finishedAt
        )
    }

    private static func evidence(
        index: Int,
        finishedAt: Date
    ) -> EvidenceRecord {
        EvidenceRecord(
            id: EvidenceID(
                rawValue: "evidence-capacity-\(padded(index))"
            )!,
            targetID: SnapshotID(
                rawValue: "snapshot-capacity-\(padded(index))"
            )!,
            kind: .activity,
            source: EvidenceSource(
                kind: .system,
                identifier: DomainToken(rawValue: "capacity.evidence")!
            ),
            summaryKey: DomainToken(rawValue: "capacity.current")!,
            observedAt: finishedAt,
            freshness: .current
        )
    }

    private static func padded(_ index: Int) -> String {
        String(format: "%06d", index)
    }
}

private struct Task37PayloadTemplate {
    let fragments: [Data]
    let renderedByteCount: Int

    init(
        payload: Data,
        marker: String,
        expectedOccurrences: Int
    ) throws {
        let markerData = Data(marker.utf8)
        var fragments: [Data] = []
        var start = payload.startIndex
        while let range = payload.range(
            of: markerData,
            in: start..<payload.endIndex
        ) {
            fragments.append(payload[start..<range.lowerBound])
            start = range.upperBound
        }
        fragments.append(payload[start..<payload.endIndex])
        guard fragments.count == expectedOccurrences + 1 else {
            throw Task37CapacityError.invalidFixture
        }
        self.fragments = fragments
        renderedByteCount = payload.count
    }

    func render(
        replacingWith replacement: String,
        appending padding: Data = Data(),
        afterOccurrence paddedOccurrence: Int? = nil
    ) -> Data {
        let replacementData = Data(replacement.utf8)
        var result = Data()
        result.reserveCapacity(renderedByteCount + padding.count)
        for (index, fragment) in fragments.enumerated() {
            if index > 0 {
                result.append(replacementData)
                if index == paddedOccurrence {
                    result.append(padding)
                }
            }
            result.append(fragment)
        }
        return result
    }
}

private enum Task37SQLiteBinding {
    case integer(Int64)
    case text(String)
}

private final class Task37SQLiteDatabase {
    private let database: OpaquePointer

    init(path: String) throws {
        var pointer: OpaquePointer?
        let code = sqlite3_open_v2(
            path,
            &pointer,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard code == SQLITE_OK, let pointer else {
            throw Task37CapacityError.sqlite(code)
        }
        database = pointer
    }

    deinit {
        sqlite3_close_v2(database)
    }

    func execute(
        _ sql: String,
        bindings: [Task37SQLiteBinding] = []
    ) throws {
        let statement = try statement(sql)
        defer { sqlite3_finalize(statement) }
        try step(statement, bindings: bindings)
    }

    func statement(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        let code = sqlite3_prepare_v3(
            database,
            sql,
            -1,
            UInt32(SQLITE_PREPARE_PERSISTENT),
            &statement,
            nil
        )
        guard code == SQLITE_OK, let statement else {
            throw Task37CapacityError.sqlite(code)
        }
        return statement
    }

    func step(
        _ statement: OpaquePointer,
        bindings: [Task37SQLiteBinding]
    ) throws {
        guard sqlite3_reset(statement) == SQLITE_OK,
              sqlite3_clear_bindings(statement) == SQLITE_OK
        else {
            throw Task37CapacityError.sqlite(SQLITE_MISUSE)
        }
        for (offset, binding) in bindings.enumerated() {
            let index = Int32(offset + 1)
            let code: Int32
            switch binding {
            case let .integer(value):
                code = sqlite3_bind_int64(statement, index, value)
            case let .text(value):
                code = value.withCString {
                    sqlite3_bind_text(
                        statement,
                        index,
                        $0,
                        -1,
                        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                    )
                }
            }
            guard code == SQLITE_OK else {
                throw Task37CapacityError.sqlite(code)
            }
        }
        let code = sqlite3_step(statement)
        guard code == SQLITE_DONE else {
            throw Task37CapacityError.sqlite(code)
        }
    }

    func verify() throws {
        guard try scalarText("PRAGMA quick_check") == "ok",
              try scalarInt("SELECT count(*) FROM pragma_foreign_key_check") == 0
        else {
            throw Task37CapacityError.invalidFixture
        }
    }

    private func scalarInt(_ sql: String) throws -> Int64 {
        let statement = try statement(sql)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw Task37CapacityError.invalidFixture
        }
        return sqlite3_column_int64(statement, 0)
    }

    private func scalarText(_ sql: String) throws -> String {
        let statement = try statement(sql)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              let bytes = sqlite3_column_text(statement, 0)
        else {
            throw Task37CapacityError.invalidFixture
        }
        return String(cString: bytes)
    }
}

private final class Task37Footprint {
    struct Snapshot {
        let current: UInt64
        let peak: UInt64
    }

    func sample() throws -> UInt64 {
        try info().phys_footprint
    }

    func peak() throws -> UInt64 {
        let value = try info().ledger_phys_footprint_peak
        guard value >= 0 else {
            throw Task37CapacityError.invalidFixture
        }
        return UInt64(value)
    }

    func snapshot() throws -> Snapshot {
        let value = try info()
        guard value.ledger_phys_footprint_peak >= 0 else {
            throw Task37CapacityError.invalidFixture
        }
        return Snapshot(
            current: value.phys_footprint,
            peak: UInt64(value.ledger_phys_footprint_peak)
        )
    }

    private func info() throws -> task_vm_info_data_t {
        var value = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size
                / MemoryLayout<natural_t>.size
        )
        let code = withUnsafeMutablePointer(to: &value) { pointer in
            pointer.withMemoryRebound(
                to: integer_t.self,
                capacity: Int(count)
            ) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(TASK_VM_INFO),
                    $0,
                    &count
                )
            }
        }
        guard code == KERN_SUCCESS else {
            throw Task37CapacityError.kernel(code)
        }
        return value
    }
}

private enum Task37PRNG {
    static func bytes(count: Int, seed: UInt64) -> Data {
        let alphabet = Array(
            "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
                .utf8
        )
        var state = seed ^ 0x9E37_79B9_7F4A_7C15
        var result = Data(count: count)
        result.withUnsafeMutableBytes { rawBuffer in
            let buffer = rawBuffer.bindMemory(to: UInt8.self)
            for index in buffer.indices {
                state ^= state << 13
                state ^= state >> 7
                state ^= state << 17
                buffer[index] = alphabet[Int(state % UInt64(alphabet.count))]
            }
        }
        return result
    }
}

private enum Task37CapacityError: Error {
    case capacityExceeded(durationSeconds: Double, peakIncrement: UInt64)
    case invalidFixture
    case invalidOperation(String)
    case invalidPeakMeasurement
    case sqlite(Int32)
    case testExecutableUnavailable
    case kernel(kern_return_t)
    case workerFailed(status: Int32, output: String)
}
