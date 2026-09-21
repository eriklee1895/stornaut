import Foundation
import Testing
@testable import StornautCore

@Test
func investigationDomainSpecificationPinsFutureRejoinAndRuntimeContracts()
    throws
{
    let specification = try investigationSpecification()
    let rejoinBarriers = [
        "1. Investigation session insertion;",
        "2. Task 38 runtime admission immediately before ephemeral `thread/start`;",
        "3. any explicit source refresh before a later `turn/start`",
        "4. terminal advisory normalization before report/session atomic commit;",
        "5. crash-recovery normalization before any partial report is promoted;",
        "6. continuation-plan construction;",
        "7. Investigation report → current Review projection;",
        "8. any Agent proposal → current `CleanupPlanBuilder` join.",
    ]

    for barrier in rejoinBarriers {
        #expect(specification.contains(barrier))
    }
    for boundary in [
        "`runStart` is sampled once",
        "monotonic `elapsed = runStart.duration(to: now)`",
        "The first transition from `open` to `closing` is an atomic compare-and-set.",
        "T0+15, T0+45, T0+135 and T0+140",
        "turn | consume 1 immediately before writing one `turn/start` request",
        "Probe output | after successful response encoding and per-call bound",
        "no-gain | update after one valid normalized scientific step",
        "`collab-tool-call-v1`",
        "`collab-agent-tool-call-v1`",
        "A run never accepts both schemas.",
    ] {
        #expect(specification.contains(boundary))
    }
}

@Test
func investigationDomainSpecificationPinsSourceBoundsAndCapabilities()
    throws
{
    let specification = try investigationSpecification()
    let decision = try investigationDecision()
    let upstreamStudy = try investigationUpstreamStudy()

    #expect(
        InvestigationSourceProjectionAccounting.maximumPathSnapshots
            == 100_000
    )
    #expect(
        InvestigationSourceProjectionAccounting.maximumClassifications
            == 100_000
    )
    #expect(
        InvestigationSourceProjectionAccounting.maximumEvidence == 100_000
    )
    #expect(
        InvestigationSourceProjectionAccounting.maximumEvidencePerSnapshot
            == 100
    )
    #expect(
        InvestigationSourceProjectionAccounting.maximumSourceRows == 300_002
    )
    #expect(
        InvestigationSourceProjectionAccounting.maximumExactPayloadBytes
            == 256 * 1_048_576
    )
    #expect(
        InvestigationSourceProjectionAccounting.maximumCanonicalBytes
            == 512 * 1_048_576
    )
    for row in [
        "| path snapshots | 100,000 |",
        "| classifications | 100,000 |",
        "| evidence total | 100,000 |",
        "| evidence per snapshot | 100 |",
        "| source rows total | 300,002 |",
        "| relevance tokens | 256 |",
        "| ordinary row payload | 1 MiB |",
        "| Space Ledger payload | 16 MiB |",
        "| sum of all exact payload bytes | 256 MiB |",
        "| complete canonical SourceProjection digest input | 512 MiB |",
    ] {
        #expect(specification.contains(row))
    }

    let requiredCapabilities: [InvestigationCapability] = [
        .shell,
        .skills,
        .subagents,
        .directRead,
        .liveSearch,
        .unifiedExec,
        .imageInspection,
        .publicCommandNetwork,
        .browserOrDirectFetch,
    ]
    #expect(InvestigationCapability.required == requiredCapabilities)
    for capability in requiredCapabilities {
        #expect(specification.contains(capability.rawValue))
    }
    for document in [specification, decision, upstreamStudy] {
        let normalizedDocument = document
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        #expect(
            normalizedDocument.contains(
                "Coverage-limited or inconsistent ledgers fail source eligibility"
            )
            || normalizedDocument.contains(
                "Coverage-limited and inconsistent ledgers fail"
            )
        )
        #expect(!normalizedDocument.contains("preferring inconsistent"))
        #expect(!normalizedDocument.contains("coverage-gap residual"))
    }
}

@Test
func investigationDomainSpecificationPinsPersistedHTTPSOriginGrammar()
    throws
{
    let specification = try investigationSpecification()

    for requirement in [
        "Input is at most 2,048 UTF-8 bytes",
        "scheme must be exact lowercase `https`",
        "user/password and fragment are rejected",
        "port is absent or exactly `443`",
        "host must already be ASCII lowercase",
        "each label is 1–63 bytes",
        "IPv4/IPv6 literals and numeric-only hosts are rejected",
        "`localhost` and suffixes `.localhost`, `.local`, `.internal`, `.home`,",
        "https://<host>/",
        "`acceptedOrigin`, `pathRedacted`, `queryRedacted`,",
        "`pathAndQueryRedacted`, `rejectedNonPublic`, `rejectedMalformed`",
        "Task 37 tests the SQLite database bytes",
    ] {
        #expect(specification.contains(requirement))
    }
}

private func investigationSpecification() throws -> String {
    try investigationDocument(
        path: "docs/specs/investigation-canonical-v1.md"
    )
}

private func investigationDecision() throws -> String {
    try investigationDocument(
        path: "docs/adr/0017-investigation-planning-and-stop-semantics.md"
    )
}

private func investigationUpstreamStudy() throws -> String {
    try investigationDocument(
        path: "docs/upstream-studies/epic-6-investigation-planning.md"
    )
}

private func investigationDocument(path: String) throws -> String {
    let root = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(
        contentsOf: root.appending(path: path),
        encoding: .utf8
    )
}
