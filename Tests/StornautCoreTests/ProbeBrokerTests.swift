import Foundation
import Testing
@testable import StornautCore

@Test
func probeBrokerRunsTheFourBoundedReadOnlyCapabilities() async throws {
    let fixture = try ProbeBrokerFixture()
    defer { fixture.remove() }
    let context = fixture.makeContext(readLevel: .level1)
    let broker = ProbeBroker()

    let disk = await broker.execute(
        ProbeRequest(capability: .diskSnapshot, targetURL: fixture.rootURL),
        in: context
    )
    guard case let .success(response) = disk,
          case let .diskSnapshot(snapshot) = response.payload
    else {
        Issue.record("Expected a disk snapshot")
        return
    }
    #expect(snapshot.totalBytes > 0)
    #expect(snapshot.availableBytes <= snapshot.totalBytes)

    let summary = await broker.execute(
        ProbeRequest(
            capability: .directorySummary,
            targetURL: fixture.rootURL,
            limit: 32
        ),
        in: context
    )
    guard case let .success(response) = summary,
          case let .directorySummary(value) = response.payload
    else {
        Issue.record("Expected a directory summary")
        return
    }
    #expect(value.entryCount == 3)
    #expect(value.logicalBytes > 0)

    let largest = await broker.execute(
        ProbeRequest(
            capability: .largestChildren,
            targetURL: fixture.rootURL,
            limit: 2
        ),
        in: context
    )
    guard case let .success(response) = largest,
          case let .largestChildren(value) = response.payload
    else {
        Issue.record("Expected largest children")
        return
    }
    #expect(value.children.count == 2)
    #expect(value.children.first?.name == "package.json")
    #expect(value.children.map(\.logicalBytes) == value.children.map(\.logicalBytes).sorted(by: >))
    #expect(value.children.allSatisfy { !$0.name.contains("/") })

    let snippet = await broker.execute(
        ProbeRequest(
            capability: .safeTextSnippet,
            targetURL: fixture.readmeURL,
            byteLimit: 4_096
        ),
        in: context
    )
    guard case let .success(response) = snippet,
          case let .safeTextSnippet(value) = response.payload
    else {
        Issue.record("Expected a safe text snippet")
        return
    }
    #expect(value.text.contains("[REDACTED]"))
    #expect(!value.text.contains("sk-secret-value"))
    #expect(value.byteCount <= 4_096)
}

@Test
func probeBrokerEnforcesCapabilityRootAndReadLevelPolicies() async throws {
    let fixture = try ProbeBrokerFixture()
    defer { fixture.remove() }
    let session = ProbeSessionBudget(limits: .generousForTesting)
    let audit = ProbeAuditRecorder()
    let context = ProbeContext(
        allowedRoots: [fixture.rootURL],
        maximumReadLevel: .level0,
        perCallTimeout: .seconds(1),
        perCallOutputByteLimit: 64 * 1_024,
        session: session,
        auditRecorder: audit
    )
    let metadataOnlyBroker = ProbeBroker(
        allowedCapabilities: [.directorySummary]
    )

    #expect(await metadataOnlyBroker.execute(
        ProbeRequest(capability: .largestChildren, targetURL: fixture.rootURL),
        in: context
    ) == .failure(.capabilityNotAllowed))

    #expect(await metadataOnlyBroker.execute(
        ProbeRequest(
            capability: .directorySummary,
            targetURL: fixture.outsideURL
        ),
        in: context
    ) == .failure(.pathDenied))

    #expect(await ProbeBroker().execute(
        ProbeRequest(
            capability: .safeTextSnippet,
            targetURL: fixture.readmeURL
        ),
        in: context
    ) == .failure(.readLevelDenied))
}

@Test
func probeBrokerEnforcesCallOutputAndSessionByteBudgets() async throws {
    let fixture = try ProbeBrokerFixture()
    defer { fixture.remove() }
    let callLimitedSession = ProbeSessionBudget(limits: ProbeBudgetLimits(
        maximumCallCount: 1,
        maximumReadBytes: 1_000_000,
        maximumOutputBytes: 1_000_000
    ))
    let context = fixture.makeContext(session: callLimitedSession)
    let request = ProbeRequest(
        capability: .directorySummary,
        targetURL: fixture.rootURL
    )

    guard case .success = await ProbeBroker().execute(request, in: context) else {
        Issue.record("Expected the first call to fit the budget")
        return
    }
    #expect(
        await ProbeBroker().execute(request, in: context)
            == .failure(.sessionCallBudgetExceeded)
    )

    let outputLimitedContext = fixture.makeContext(
        perCallOutputByteLimit: 16
    )
    #expect(
        await ProbeBroker().execute(request, in: outputLimitedContext)
            == .failure(.outputByteLimitExceeded)
    )

    let byteLimitedSession = ProbeSessionBudget(limits: ProbeBudgetLimits(
        maximumCallCount: 4,
        maximumReadBytes: 1,
        maximumOutputBytes: 1_000_000
    ))
    let hook = AccessObservationHook()
    let byteLimitedContext = fixture.makeContext(session: byteLimitedSession)
    #expect(
        await ProbeBroker(beforeAccess: {
            await hook.markAccessed()
        }).execute(
            ProbeRequest(
                capability: .safeTextSnippet,
                targetURL: fixture.readmeURL,
                byteLimit: 128
            ),
            in: byteLimitedContext
        ) == .failure(.sessionReadBudgetExceeded)
    )
    #expect(await hook.wasAccessed == false)
}

@Test
func probeBrokerTimeoutAndCancellationFailClosed() async throws {
    let fixture = try ProbeBrokerFixture()
    defer { fixture.remove() }
    let slowBroker = ProbeBroker(beforeAccess: {
        try await Task.sleep(for: .seconds(5))
    })
    let timeoutContext = fixture.makeContext(
        perCallTimeout: .milliseconds(50)
    )
    let request = ProbeRequest(
        capability: .directorySummary,
        targetURL: fixture.rootURL
    )

    #expect(
        await slowBroker.execute(request, in: timeoutContext)
            == .failure(.timedOut)
    )

    let task = Task {
        await slowBroker.execute(
            request,
            in: fixture.makeContext(perCallTimeout: .seconds(10))
        )
    }
    try await Task.sleep(for: .milliseconds(30))
    task.cancel()
    #expect(await task.value == .failure(.cancelled))
}

@Test
func probeBrokerBindsAuthorizationToFileIdentity() async throws {
    let fixture = try ProbeBrokerFixture()
    defer { fixture.remove() }
    let hook = ReplacementHook(
        targetURL: fixture.readmeURL,
        replacementURL: fixture.outsideURL
    )
    let broker = ProbeBroker(beforeAccess: {
        try await hook.replaceTarget()
    })

    let result = await broker.execute(
        ProbeRequest(
            capability: .safeTextSnippet,
            targetURL: fixture.readmeURL
        ),
        in: fixture.makeContext()
    )

    #expect(result == .failure(.fileIdentityChanged))
}

@Test
func promptInjectionTextIsDataAndAuditRecordsStayRedacted() async throws {
    let fixture = try ProbeBrokerFixture(usePromptInjectionFixture: true)
    defer { fixture.remove() }
    let audit = ProbeAuditRecorder()
    let context = fixture.makeContext(auditRecorder: audit)

    let result = await ProbeBroker().execute(
        ProbeRequest(
            capability: .safeTextSnippet,
            targetURL: fixture.readmeURL
        ),
        in: context
    )

    guard case let .success(response) = result,
          case let .safeTextSnippet(snippet) = response.payload
    else {
        Issue.record("Expected the README fixture to remain readable data")
        return
    }
    #expect(snippet.text.contains("IGNORE ALL PREVIOUS INSTRUCTIONS"))

    let records = await audit.records
    #expect(records.count == 1)
    #expect(records[0].capability == .safeTextSnippet)
    #expect(records[0].outcome == .success)
    #expect(records[0].target == .redacted)
    let encodedAudit = try JSONEncoder().encode(records)
    let auditText = String(decoding: encodedAudit, as: UTF8.self)
    #expect(!auditText.contains("IGNORE ALL PREVIOUS INSTRUCTIONS"))
    #expect(!auditText.contains(fixture.rootURL.path))
    #expect(!auditText.contains(snippet.text))
}

@Test
func safeTextSnippetRejectsUnapprovedNamesBinaryDataAndOversizedRequests() async throws {
    let fixture = try ProbeBrokerFixture()
    defer { fixture.remove() }
    let broker = ProbeBroker()
    let context = fixture.makeContext()
    let unapprovedURL = fixture.rootURL.appending(path: "notes.txt")
    let binaryURL = fixture.rootURL.appending(path: "package.json")
    try Data("private notes".utf8).write(to: unapprovedURL)
    try Data([0x00, 0x01, 0x02]).write(to: binaryURL)

    #expect(await broker.execute(
        ProbeRequest(
            capability: .safeTextSnippet,
            targetURL: unapprovedURL
        ),
        in: context
    ) == .failure(.fileTypeNotAllowed))
    #expect(await broker.execute(
        ProbeRequest(
            capability: .safeTextSnippet,
            targetURL: binaryURL
        ),
        in: context
    ) == .failure(.binaryContent))
    #expect(await broker.execute(
        ProbeRequest(
            capability: .safeTextSnippet,
            targetURL: fixture.readmeURL,
            byteLimit: ProbeRequest.maximumSnippetBytes + 1
        ),
        in: context
    ) == .failure(.invalidRequest))
}

@Test
func probeBrokerRedactsStructuredSecretsAndPrivateKeys() async throws {
    let fixture = try ProbeBrokerFixture()
    defer { fixture.remove() }
    let manifestURL = fixture.rootURL.appending(path: "pyproject.toml")
    try Data(
        """
        "token": "json-secret-value",
        password = "toml-secret-value"
        aws_secret_access_key = "aws-secret-value"
        Authorization: Bearer bearer-secret-value
        github_pat_1234567890abcdef
        AKIAIOSFODNN7EXAMPLE
        -----BEGIN PRIVATE KEY-----
        private-key-material
        """.utf8
    ).write(to: manifestURL)

    let result = await ProbeBroker().execute(
        ProbeRequest(
            capability: .safeTextSnippet,
            targetURL: manifestURL,
            byteLimit: 4_096
        ),
        in: fixture.makeContext()
    )
    guard case let .success(response) = result,
          case let .safeTextSnippet(snippet) = response.payload
    else {
        Issue.record("Expected a redacted structured snippet")
        return
    }
    #expect(!snippet.text.contains("json-secret-value"))
    #expect(!snippet.text.contains("toml-secret-value"))
    #expect(!snippet.text.contains("aws-secret-value"))
    #expect(!snippet.text.contains("bearer-secret-value"))
    #expect(!snippet.text.contains("private-key-material"))
    #expect(!snippet.text.contains("github_pat_1234567890abcdef"))
    #expect(!snippet.text.contains("AKIAIOSFODNN7EXAMPLE"))
    #expect(snippet.text.contains("[REDACTED]"))
}

@Test
func directoryProbesHideSensitiveChildrenAndStopAtBounds() async throws {
    let fixture = try ProbeBrokerFixture()
    defer { fixture.remove() }
    try FileManager.default.createDirectory(
        at: fixture.rootURL.appending(path: ".aws"),
        withIntermediateDirectories: true
    )
    try Data("secret".utf8).write(
        to: fixture.rootURL.appending(path: "private.pem")
    )
    for index in 0..<8 {
        try Data([UInt8(index % 255)]).write(
            to: fixture.rootURL.appending(path: "entry-\(index)")
        )
    }
    let broker = ProbeBroker()
    let context = fixture.makeContext()

    let largest = await broker.execute(
        ProbeRequest(
            capability: .largestChildren,
            targetURL: fixture.rootURL,
            limit: 4
        ),
        in: context
    )
    guard case let .success(response) = largest,
          case let .largestChildren(value) = response.payload
    else {
        Issue.record("Expected bounded largest children")
        return
    }
    #expect(value.children.count == 4)
    #expect(!value.children.contains { $0.name == ".aws" })
    #expect(!value.children.contains { $0.name == "private.pem" })

    #expect(
        await broker.execute(
            ProbeRequest(
                capability: .directorySummary,
                targetURL: fixture.rootURL,
                limit: 4
            ),
            in: context
        ) == .failure(.outputByteLimitExceeded)
    )
}

private struct ProbeBrokerFixture {
    let parentURL: URL
    let rootURL: URL
    let outsideURL: URL
    let readmeURL: URL

    init(usePromptInjectionFixture: Bool = false) throws {
        parentURL = FileManager.default.temporaryDirectory
            .appending(path: "stornaut-probe-broker-\(UUID().uuidString)")
        rootURL = parentURL.appending(path: "allowed")
        outsideURL = parentURL.appending(path: "outside.txt")
        readmeURL = rootURL.appending(path: "README.md")
        try FileManager.default.createDirectory(
            at: rootURL.appending(path: "Sources"),
            withIntermediateDirectories: true
        )
        let readmeData: Data
        if usePromptInjectionFixture {
            readmeData = try Data(contentsOf: fixtureURL(
                "Tests/Fixtures/Codex/prompt-injection-readme.md"
            ))
        } else {
            readmeData = Data(
                """
                # Fixture
                OPENAI_API_KEY=sk-secret-value
                password=hunter2
                """.utf8
            )
        }
        try readmeData.write(to: readmeURL)
        try Data(repeating: 0x61, count: 256).write(
            to: rootURL.appending(path: "package.json")
        )
        try Data("source".utf8).write(
            to: rootURL.appending(path: "Sources/main.swift")
        )
        try Data("outside".utf8).write(to: outsideURL)
    }

    func makeContext(
        readLevel: ProbeReadLevel = .level1,
        perCallTimeout: Duration = .seconds(1),
        perCallOutputByteLimit: Int = 64 * 1_024,
        session: ProbeSessionBudget = ProbeSessionBudget(
            limits: .generousForTesting
        ),
        auditRecorder: ProbeAuditRecorder = ProbeAuditRecorder()
    ) -> ProbeContext {
        ProbeContext(
            allowedRoots: [rootURL],
            maximumReadLevel: readLevel,
            perCallTimeout: perCallTimeout,
            perCallOutputByteLimit: perCallOutputByteLimit,
            session: session,
            auditRecorder: auditRecorder
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: parentURL)
    }
}

private actor ReplacementHook {
    private let targetURL: URL
    private let replacementURL: URL
    private var didReplace = false

    init(targetURL: URL, replacementURL: URL) {
        self.targetURL = targetURL
        self.replacementURL = replacementURL
    }

    func replaceTarget() throws {
        guard !didReplace else {
            return
        }
        didReplace = true
        try FileManager.default.removeItem(at: targetURL)
        try FileManager.default.createSymbolicLink(
            at: targetURL,
            withDestinationURL: replacementURL
        )
    }
}

private actor AccessObservationHook {
    private var accessed = false

    var wasAccessed: Bool {
        accessed
    }

    func markAccessed() {
        accessed = true
    }
}

private func fixtureURL(_ relativePath: String) -> URL {
    URL(filePath: FileManager.default.currentDirectoryPath)
        .appending(path: relativePath)
}
