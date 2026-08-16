import Darwin
import Foundation
import StornautInvestigation
import Testing
@testable import StornautInvestigationDiagnosticApp

private typealias InvestigationRuntimeDiagnosticConfiguration =
    SignedInvestigationRuntimeDiagnosticConfiguration
private typealias InvestigationRuntimeBinding =
    SignedInvestigationRuntimeBinding

@Test
func investigationRuntimeDiagnosticLaunchAcceptsOneExactAbsoluteConfig() {
    let expected = URL(
        filePath: "/tmp/stornaut-investigation-runtime.A/config.json"
    ).standardizedFileURL
    let validArguments = [
        "Stornaut",
        "--stornaut-investigation-runtime-config=\(expected.path)",
    ]

    #expect(
        InvestigationRuntimeDiagnosticLaunchRequest(
            arguments: validArguments
        )?.configURL == expected
    )
    #expect(
        InvestigationRuntimeDiagnosticActivation.select(
            arguments: validArguments
        )
            == .request(
                InvestigationRuntimeDiagnosticLaunchRequest(
                    arguments: validArguments
                )!
            )
    )
    for arguments in [
        [
            "Stornaut",
            "--stornaut-investigation-runtime-config=relative/config.json",
        ],
        [
            "Stornaut",
            "--stornaut-investigation-runtime-config",
            expected.path,
        ],
        [
            "Stornaut",
            "--stornaut-investigation-runtime-config=\(expected.path)",
            "--stornaut-investigation-runtime-config=/tmp/second.json",
        ],
        [
            "Stornaut",
            "--stornaut-investigation-runtime-config=\(expected.path)",
            "--stornaut-phase-c-trash-config=/tmp/trash.json",
        ],
        [
            "Stornaut",
            "--stornaut-investigation-runtime-config=\(expected.path)",
            "--stornaut-capability-runtime-config=/tmp/capability.json",
        ],
        [
            "Stornaut",
            "--stornaut-investigation-runtime-config=\(expected.path)",
            "--model=gpt-5.6-luna",
        ],
        [
            "Stornaut",
            "--stornaut-investigation-runtime-config=\(expected.path)",
            "--provider=openai",
        ],
        [
            "Stornaut",
            "--stornaut-investigation-runtime-config=\(expected.path)",
            "--danger-full-access",
        ],
    ] {
        #expect(
            InvestigationRuntimeDiagnosticLaunchRequest(
                arguments: arguments
            ) == nil
        )
        #expect(
            InvestigationRuntimeDiagnosticActivation.select(
                arguments: arguments
            ) == .invalid
        )
    }
    #expect(
        InvestigationRuntimeDiagnosticActivation.select(arguments: [
            "Stornaut",
        ]) == .notRequested
    )
}

@Test
func investigationRuntimeDiagnosticActivationNeverPromotesMalformedInput() {
    let configPath =
        "/tmp/stornaut-investigation-runtime.A/config.json"
    let validArguments = [
        "Stornaut",
        "--stornaut-investigation-runtime-config=\(configPath)",
    ]
    let request = InvestigationRuntimeDiagnosticLaunchRequest(
        arguments: validArguments
    )
    #expect(request != nil)
    #expect(
        InvestigationRuntimeDiagnosticActivation.select(
            arguments: validArguments
        ) == .request(request!)
    )

    for malformed in [
        [
            "Stornaut",
            "--stornaut-investigation-runtime-config",
        ],
        [
            "Stornaut",
            "--stornaut-investigation-runtime-config=\(configPath)",
            "--stornaut-investigation-runtime-config",
        ],
        [
            "Stornaut",
            "--stornaut-investigation-runtime-config=\(configPath)",
            "--unexpected",
        ],
    ] {
        #expect(
            InvestigationRuntimeDiagnosticActivation.select(
                arguments: malformed
            ) == .invalid
        )
    }
}

@Test
func investigationRuntimeDiagnosticLeafValidatesTheClosedConfiguration()
    throws
{
    let fixture = try InvestigationRuntimeAppLeafFixture()
    defer { fixture.remove() }
    let configuration = try fixture.configuration()
    let data = try configuration.canonicalJSONData()

    let leaf = try InvestigationRuntimeDiagnosticLeaf.prepare(
        configurationData: data,
        now: fixture.now
    )
    #expect(leaf.nonce == configuration.nonce)
    #expect(leaf.diagnosticRootPath == configuration.diagnosticRootPath)

    var object = try #require(
        JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
    object["unexpected"] = true
    let invalid = try JSONSerialization.data(withJSONObject: object)
    #expect(
        throws: InvestigationRuntimeDiagnosticContractError
            .invalidConfiguration
    ) {
        _ = try InvestigationRuntimeDiagnosticLeaf.prepare(
            configurationData: invalid,
            now: fixture.now
        )
    }
}

@Test
func investigationRuntimeDiagnosticConfigFileAdmissionIsStrict() throws {
    let fixture = try InvestigationRuntimeAppLeafFixture()
    defer { fixture.remove() }
    let configuration = try fixture.configuration()
    let configURL = fixture.root.appending(path: "config.json")
    let validData = try configuration.canonicalJSONData()
    try validData.write(to: configURL, options: .atomic)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o600],
        ofItemAtPath: configURL.path
    )

    let decoded =
        try InvestigationRuntimeDiagnosticConfiguration.decodeValidated(
            from: validData,
            now: Date()
        )
    #expect(decoded == configuration)

    var information = stat()
    #expect(lstat(configURL.path, &information) == 0)
    #expect(information.st_mode & S_IFMT == S_IFREG)
    #expect(information.st_mode & 0o777 == 0o600)
    #expect(information.st_uid == geteuid())
    #expect(information.st_nlink == 1)
    #expect(information.st_size == validData.count)
    #expect(
        URL(filePath: decoded.diagnosticRootPath)
            .appending(path: "config.json")
            .standardizedFileURL
            == configURL.standardizedFileURL
    )

    #expect(
        try InvestigationRuntimeDiagnosticHarness.loadConfiguration(
            configURL
        ) == validData
    )

    try FileManager.default.setAttributes(
        [.posixPermissions: 0o644],
        ofItemAtPath: configURL.path
    )
    #expect(throws: InvestigationRuntimeDiagnosticContractError.self) {
        _ = try InvestigationRuntimeDiagnosticHarness.loadConfiguration(
            configURL
        )
    }

    let linkRoot = fixture.root.appending(
        path: "linked",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: linkRoot,
        withIntermediateDirectories: false
    )
    let linkURL = linkRoot.appending(path: "config.json")
    try FileManager.default.createSymbolicLink(
        at: linkURL,
        withDestinationURL: configURL
    )
    #expect(throws: InvestigationRuntimeDiagnosticContractError.self) {
        _ = try InvestigationRuntimeDiagnosticHarness.loadConfiguration(
            linkURL
        )
    }

    try FileManager.default.setAttributes(
        [.posixPermissions: 0o600],
        ofItemAtPath: configURL.path
    )
    let parentLinkURL = fixture.root.appending(
        path: "linked-root",
        directoryHint: .isDirectory
    )
    try FileManager.default.createSymbolicLink(
        at: parentLinkURL,
        withDestinationURL: fixture.root
    )
    #expect(throws: InvestigationRuntimeDiagnosticContractError.self) {
        _ = try InvestigationRuntimeDiagnosticHarness.loadConfiguration(
            parentLinkURL.appending(path: "config.json")
        )
    }
}

@Test
func investigationRuntimeDiagnosticReceiptIsExclusiveAndPreservesExisting()
    throws
{
    let fixture = try InvestigationRuntimeAppLeafFixture()
    defer { fixture.remove() }
    let configURL = fixture.root.appending(path: "config.json")
    let receiptURL = fixture.root.appending(
        path: "investigation-runtime-preflight.json"
    )
    let receipt =
        InvestigationRuntimeDiagnosticPreflightReceipt.prepared(
            nonce: UUID(),
            startedAt: fixture.now,
            completedAt: fixture.now
        )

    #expect(
        InvestigationRuntimeDiagnosticReceiptWriter.write(
            receipt: receipt,
            configURL: configURL
        ) == .written
    )
    let original = try Data(contentsOf: receiptURL)
    #expect(!original.isEmpty)

    #expect(
        InvestigationRuntimeDiagnosticReceiptWriter.write(
            receipt: .blocked(
                reasonKey: "must-not-replace",
                startedAt: fixture.now,
                completedAt: fixture.now
            ),
            configURL: configURL
        ) == .alreadyExists
    )
    #expect(try Data(contentsOf: receiptURL) == original)

    try original.write(to: receiptURL, options: .atomic)
    #expect(
        InvestigationRuntimeDiagnosticReceiptWriter.write(
            receipt: receipt,
            configURL: configURL
        ) == .alreadyExists
    )
    #expect(try Data(contentsOf: receiptURL) == original)
}

@Test
func investigationRuntimeDiagnosticRunExposesOneShotReceiptFailure()
    async throws
{
    let fixture = try InvestigationRuntimeAppLeafFixture()
    defer { fixture.remove() }
    let configuration = try fixture.configuration()
    let configURL = fixture.root.appending(path: "config.json")
    try configuration.canonicalJSONData().write(
        to: configURL,
        options: .atomic
    )
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o600],
        ofItemAtPath: configURL.path
    )
    let arguments = [
        "StornautInvestigationDiagnostic",
        "--stornaut-investigation-runtime-config=\(configURL.path)",
    ]
    let compositionPrepare:
        @Sendable (Data, Date) async throws -> UUID = { data, now in
            try InvestigationRuntimeDiagnosticConfiguration
                .decodeValidated(from: data, now: now)
                .nonce
        }

    #expect(
        await InvestigationRuntimeDiagnosticHarness.run(
            arguments: arguments,
            now: fixture.now,
            compositionPrepare: compositionPrepare
        ) == 0
    )
    let receiptURL = fixture.root.appending(
        path: "investigation-runtime-preflight.json"
    )
    let original = try Data(contentsOf: receiptURL)
    #expect(!original.isEmpty)

    #expect(
        await InvestigationRuntimeDiagnosticHarness.run(
            arguments: arguments,
            now: fixture.now,
            compositionPrepare: compositionPrepare
        ) == 73
    )
    #expect(try Data(contentsOf: receiptURL) == original)
}

@Test
func investigationRuntimeDiagnosticReceiptHandlesPartialWrites() {
    let expected = Data("bounded receipt".utf8)
    var observed = Data()
    let completed =
        InvestigationRuntimeDiagnosticReceiptWriter.writeAll(
            expected,
            descriptor: 42
        ) { descriptor, pointer, count in
            #expect(descriptor == 42)
            let written = min(count, 3)
            observed.append(
                pointer.assumingMemoryBound(to: UInt8.self),
                count: written
            )
            return written
        }

    #expect(completed)
    #expect(observed == expected)
}

@Test
func investigationRuntimeDiagnosticReceiptRejectsPartialWriteFailure() {
    let expected = Data("bounded receipt".utf8)
    var calls = 0
    let completed =
        InvestigationRuntimeDiagnosticReceiptWriter.writeAll(
            expected,
            descriptor: 42
        ) { _, _, count in
            calls += 1
            if calls == 1 {
                return min(count, 3)
            }
            return -1
        }

    #expect(!completed)
    #expect(calls == 2)
}

@Test
func investigationRuntimeDiagnosticReceiptCleansPartialWriteFailure() {
    let receipt =
        InvestigationRuntimeDiagnosticPreflightReceipt.prepared(
            nonce: UUID(),
            startedAt: Date(),
            completedAt: Date()
        )
    var writes = 0
    var synchronized = false
    var closed = false
    var unlinkedPath: String?
    let outcome = InvestigationRuntimeDiagnosticReceiptWriter.write(
        receipt: receipt,
        configURL: URL(filePath: "/tmp/diagnostic/config.json"),
        operations: InvestigationRuntimeDiagnosticReceiptOperations(
            openExclusive: { path in
                #expect(
                    path
                        == "/tmp/diagnostic/"
                            + "investigation-runtime-preflight.json"
                )
                return 42
            },
            write: { _, _, count in
                writes += 1
                return writes == 1 ? min(count, 3) : -1
            },
            synchronize: { _ in
                synchronized = true
                return true
            },
            close: { descriptor in
                #expect(descriptor == 42)
                closed = true
                return true
            },
            unlink: { path in
                unlinkedPath = path
            },
            errorCode: { EIO }
        )
    )

    #expect(outcome == .failed)
    #expect(writes == 2)
    #expect(!synchronized)
    #expect(closed)
    #expect(
        unlinkedPath
            == "/tmp/diagnostic/"
                + "investigation-runtime-preflight.json"
    )
}

@Test
func investigationRuntimeDiagnosticReceiptCleansSyncFailure() {
    let receipt =
        InvestigationRuntimeDiagnosticPreflightReceipt.prepared(
            nonce: UUID(),
            startedAt: Date(),
            completedAt: Date()
        )
    var closed = false
    var unlinked = false
    let outcome = InvestigationRuntimeDiagnosticReceiptWriter.write(
        receipt: receipt,
        configURL: URL(filePath: "/tmp/diagnostic/config.json"),
        operations: InvestigationRuntimeDiagnosticReceiptOperations(
            openExclusive: { _ in 42 },
            write: { _, _, count in count },
            synchronize: { _ in false },
            close: { _ in
                closed = true
                return true
            },
            unlink: { _ in
                unlinked = true
            },
            errorCode: { EIO }
        )
    )

    #expect(outcome == .failed)
    #expect(closed)
    #expect(unlinked)
}

@Test
func investigationRuntimeDiagnosticLeafIsAClosedDebugTerminal() throws {
    let repositoryRoot = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let harness = try String(
        contentsOf: repositoryRoot.appending(
            path:
                "StornautApp/Diagnostics/InvestigationRuntimeDiagnosticHarness.swift"
        ),
        encoding: .utf8
    )
    let app = try String(
        contentsOf: repositoryRoot.appending(
            path:
                "Stornaut.xcodeproj/project.pbxproj"
        ),
        encoding: .utf8
    )

    for required in [
        "#if DEBUG && STORNAUT_INVESTIGATION_DIAGNOSTIC",
        "--stornaut-investigation-runtime-config=",
        "InvestigationRuntimeDiagnosticLeaf.prepare(",
        "InvestigationRuntimeDiagnosticActivation.select(",
        "InvestigationRuntimeDiagnosticReceiptWriter.write(",
        "typealias InvestigationRuntimeDiagnosticLeaf",
        "@main",
    ] {
        #expect(harness.contains(required))
    }
    for prohibited in [
        "ActionExecutor",
        "Cleanup",
        "MoveToTrash",
        "RegisteredAction",
        "URLSession",
        "Process(",
        "NSTask",
        "AGENTS.md",
        "UserDefaults",
        "PhaseCTrash",
        "StornautAppModel",
        "AppDependencies",
    ] {
        #expect(!harness.contains(prohibited))
    }
    #expect(
        app.contains(
            "InvestigationRuntimeDiagnosticHarness.swift in Sources"
        )
    )
    #expect(
        !app.contains(
            "E00000000000000000000001 /* StornautApp */,\n"
                + "\t\t\t);\n"
                + "\t\t\tname = StornautInvestigationDiagnosticApp"
        )
    )
}

private struct InvestigationRuntimeAppLeafFixture {
    let root: URL
    let source: URL
    let support: URL
    let runtime: URL
    let report: URL
    let store: URL
    let now: Date

    init() throws {
        now = Date()
        let temporaryPath = FileManager.default.temporaryDirectory.path
        guard let resolvedTemporaryPath = realpath(temporaryPath, nil) else {
            throw InvestigationRuntimeDiagnosticContractError
                .invalidConfiguration
        }
        defer { free(resolvedTemporaryPath) }
        root = URL(
            filePath: String(cString: resolvedTemporaryPath),
            directoryHint: .isDirectory
        ).appending(
            path: "stornaut-investigation-app-leaf-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        source = root.appending(path: "source", directoryHint: .isDirectory)
        support = root.appending(
            path: "support",
            directoryHint: .isDirectory
        )
        runtime = root.appending(
            path: "runtime",
            directoryHint: .isDirectory
        )
        report = root.appending(path: "report.json")
        store = support.appending(
            path: "com.eriklee.stornaut/Evidence.sqlite"
        )
        for directory in [
            root,
            source,
            support,
            runtime,
            store.deletingLastPathComponent(),
        ] {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        }
    }

    func configuration()
        throws -> InvestigationRuntimeDiagnosticConfiguration
    {
        try InvestigationRuntimeDiagnosticConfiguration(
            nonce: UUID(),
            optIn:
                InvestigationRuntimeDiagnosticConfiguration
                .requiredOptIn,
            diagnosticRootPath: root.path,
            sourceRootPath: source.path,
            supportRootPath: support.path,
            runtimeRootPath: runtime.path,
            reportPath: report.path,
            storePath: store.path,
            binding: InvestigationRuntimeBinding(
                repositoryHEAD: String(repeating: "a", count: 40),
                sourceFingerprintSHA256:
                    String(repeating: "b", count: 64),
                appExecutableSHA256:
                    String(repeating: "c", count: 64),
                helperExecutableSHA256:
                    String(repeating: "d", count: 64),
                runtimeReceiptSHA256:
                    String(repeating: "e", count: 64),
                promptSHA256: String(repeating: "f", count: 64),
                envelopeSchemaSHA256:
                    String(repeating: "1", count: 64),
                facadeSHA256: String(repeating: "2", count: 64),
                codexExecutableSHA256:
                    String(repeating: "3", count: 64),
                appBundleIdentifier: "com.eriklee.stornaut",
                helperServiceIdentifier:
                    "com.eriklee.stornaut.lifecycle"
            ),
            expectedModel: .gpt56Luna,
            expectedProvider: .openAI,
            validBefore: now.addingTimeInterval(300),
            maximumWallClockSeconds: 135,
            maximumTurns: 2,
            maximumProbeCalls: 8,
            maximumContextBytes: 262_144,
            now: now
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
