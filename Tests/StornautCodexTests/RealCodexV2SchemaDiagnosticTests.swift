import Foundation
import Testing
@testable import StornautCodex

@Test(
    .enabled(
        if: ProcessInfo.processInfo.environment[
            "STORNAUT_RUN_V2_SCHEMA_DIAGNOSTIC"
        ] == "1",
        """
        Opt in to a no-tool gpt-5.6-luna Investigation Envelope v2 schema test
        """
    )
)
func realCodexV2SchemaDiagnostic() async throws {
    let inherited = ProcessInfo.processInfo.environment
    let usesCapabilityGroupSchema =
        inherited["STORNAUT_V2_SCHEMA_MODE"] == "group"
    let normalHome = FileManager.default.homeDirectoryForCurrentUser
    var processEnvironment = [
        "HOME": normalHome.path,
        "PATH":
            "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
        "TERM": inherited["TERM"] ?? "dumb",
    ]
    for key in ["LANG", "LC_ALL", "LC_CTYPE"] {
        if let value = inherited[key], !value.isEmpty {
            processEnvironment[key] = value
        }
    }
    for key in ["SSL_CERT_FILE", "SSL_CERT_DIR"] {
        if let value = inherited[key], !value.isEmpty {
            processEnvironment[key] = value
        }
    }
    let installation = try #require(
        await CodexLocator().locate(
            configuredURL: nil,
            environment: processEnvironment
        ).installation
    )
    let parent = FileManager.default.temporaryDirectory.appending(
        path: "stornaut-v2-schema-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: parent,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    defer { try? FileManager.default.removeItem(at: parent) }

    let authSourceURL = normalHome.appending(
        path: ".codex/auth.json"
    )
    let workspace = try CodexRuntimeWorkspace.create(
        under: parent,
        forbiddenRoots: [normalHome]
    )
    let policy = CodexContainmentPolicy()
    let configuration = try policy.configuration(
        workspace: workspace.paths,
        projectedAuthSourceURL: authSourceURL
    )
    _ = try policy.install(configuration, in: workspace.paths)
    let environment = try CodexRuntimeEnvironmentPolicy().project(
        inherited: processEnvironment,
        workspace: workspace.paths,
        forbiddenHomeURL: normalHome
    )
    let projector = CodexRuntimeAuthProjector()
    let projection = try projector.read(from: authSourceURL)
    let context = try InvestigationProtocolContext(
        investigationID: "v2-schema-diagnostic",
        runID: "v2-schema-run",
        targetIDs: ["synthetic-target"],
        candidateTargetIDs: [:],
        requiredCapabilities: [.directRead]
    )
    let baseSchema = try InvestigationEnvelopeV2Schema
        .loadStructuredOutputJSONValue()
    let outputSchema = usesCapabilityGroupSchema
        ? try capabilityRuntimeGroupSchema(
            baseSchema,
            context: context,
            expectedEvidenceIDs: ["direct-evidence"]
        )
        : baseSchema
    let prompt = usesCapabilityGroupSchema
        ? """
          Do not inspect files, run tools, access the network, or change state.
          Return this Investigation Envelope v2 identity:
          protocolVersion=2
          investigationID=v2-schema-diagnostic
          runID=v2-schema-run
          summary=Synthetic capability evidence observed.
          coverage.investigatedTargetIDs=["synthetic-target"]
          coverage.unresolvedTargets=[]
          evidence=[{"id":"direct-evidence","targetID":"synthetic-target","source":"directFile","summary":"Synthetic direct evidence.","publicURL":null}]
          findings=[]
          candidateProposals=[]
          capabilityDegradations=[]
          """
        : """
          Do not inspect files, run tools, access the network, or change state.
          Return this Investigation Envelope v2 identity with a short summary:
          protocolVersion=2
          investigationID=v2-schema-diagnostic
          runID=v2-schema-run
          coverage.investigatedTargetIDs=["synthetic-target"]
          coverage.unresolvedTargets=[]
          evidence=[]
          findings=[]
          candidateProposals=[]
          capabilityDegradations=[]
          """
    let runtime = try CodexAppServerRuntime(
        request: CodexAppServerRuntimeRequest(
            projectedAuthSourceURL: authSourceURL,
            runtimeHomeURL: workspace.paths.runtimeURL,
            workingDirectoryURL: workspace.paths.workURL,
            prompt: prompt,
            outputSchema: outputSchema
        ),
        authProjection: projection,
        refreshProvider: CodexRuntimeFileAuthRefreshProvider(
            sourceURL: authSourceURL,
            sourceIdentity: projection.sourceIdentity,
            projector: projector
        )
    )
    let result = try await CodexAppServerSessionRunner().run(
        CodexAppServerSessionRequest(
            executableURL: installation.executableURL,
            workspace: workspace.paths,
            projectedAuthSourceURL: authSourceURL,
            containmentConfiguration: configuration,
            environment: environment,
            runtime: runtime,
            timeout: .seconds(120),
            standardOutputByteLimit: 2 * 1_024 * 1_024,
            standardErrorByteLimit: 256 * 1_024,
            lineByteLimit: 512 * 1_024
        )
    )
    let finalMessage = try #require(
        result.observation.finalAgentMessage
    )
    let envelope = try InvestigationEnvelopeV2.decodeValidated(
        from: Data(finalMessage.utf8),
        context: context
    )

    #expect(envelope.protocolVersion == 2)
    #expect(
        envelope.evidence.map(\.id)
            == (usesCapabilityGroupSchema ? ["direct-evidence"] : [])
    )
    #expect(envelope.findings.isEmpty)
    #expect(
        Set(result.observation.itemTypes).isSubset(
            of: ["agentMessage", "reasoning", "userMessage"]
        )
    )
    #expect(result.observation.itemTypes.contains("agentMessage"))
    #expect(result.observation.itemTypes.contains("userMessage"))
    #expect(result.observation.capabilityObservations.isEmpty)
    print("v2_schema.model=gpt-5.6-luna")
    print("v2_schema.provider=openai")
    print(
        "v2_schema.mode="
            + (usesCapabilityGroupSchema ? "group" : "base")
    )
    print("v2_schema.tools=not-invoked")
    print("v2_schema.verdict=passed")
    try workspace.remove()
}
