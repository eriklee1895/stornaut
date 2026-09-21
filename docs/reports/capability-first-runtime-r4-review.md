# Capability-First Runtime R4 Review

> Status: Passed — protocolReady; R5 signed-App gate pending
>
> Date: 2026-08-12
>
> Gate: Investigation Envelope v2 and structural no-Executor seam

## 1. Review Scope

R4 converts the R3 behavior-ready runtime output into one closed advisory
protocol and removes the package edge that previously let `StornautCodex`
reach the Executor-bearing `StornautCore` target.

Reviewed production scope:

```text
Package.swift
Sources/StornautProcessSupport/
Sources/StornautCore/Actions/ProcessTreeTerminator.swift
Sources/StornautCodex/Protocol/InvestigationEnvelopeV2.swift
Sources/StornautCodex/Protocol/InvestigationEvidenceSource.swift
Sources/StornautCodex/Protocol/JSONValue.swift
Sources/StornautCodex/Protocol/StrictProtocolJSONAuditor.swift
Sources/StornautCodex/Runtime/CodexAppServerAdvisoryResult.swift
Sources/StornautCodex/Runtime/CodexAppServerSessionRunner.swift
Sources/StornautCodex/Runtime/CodexRuntimeEnvironment.swift
Sources/StornautCodex/ProbeBridge/
Sources/StornautCodex/Schemas/investigation-envelope-v2.schema.json
scripts/verify-codex-no-executor-boundary
scripts/verify
scripts/verify-rule-compiler
```

Reviewed tests and fixtures:

```text
Tests/Fixtures/Codex/investigation-envelope-v2-valid.json
Tests/StornautCodexTests/InvestigationEnvelopeV2Tests.swift
Tests/StornautCodexTests/R4ProtocolBoundaryTests.swift
Tests/StornautCodexTests/ProbeBridgeIntegrationTests.swift
```

R4 adds no production Deep Dive coordinator, Cleanup Plan conversion, Policy
decision, authorization, journal write, Trash request, Registered Action or
Executor invocation.

## 2. Admitted Protocol

The admitted flow is:

```text
untrusted App Server final message
→ 1 MiB aggregate bound
→ strict JSON duplicate/scalar/depth audit
→ exact nested-key decoder
→ Swift-owned investigation/run/target/candidate binding
→ closed evidence/capability/confidence enums
→ bounded advisory normalization
→ InvestigationAdvisoryReport
```

The v2 wire protocol:

- requires protocol version `2`;
- requires exact investigation and run identity;
- requires every Swift-known target to appear exactly once as investigated or
  unresolved;
- binds every evidence, finding and proposal to a known investigated target;
- binds every proposal to the Swift-owned candidate-to-target map;
- rejects duplicate, dangling and cross-target references;
- records only bounded summaries, uncertainty and normalized public URL
  provenance;
- contains no model-supplied path, command, executable, argument,
  authorization, Policy, Trash, journal, Manifest or Executor field.

Historical v1 decoding remains available only for old records and fixtures.
There is no silent v1-to-v2 promotion.

## 3. Structural No-Executor Result

The final package graph is:

```text
StornautCodex → StornautProcessSupport
StornautCore → StornautProcessSupport
StornautProbeBridge → StornautCodex + StornautCore
StornautProcessSupport → no target dependency
```

`StornautProcessSupport` contains only process-group termination types and
behavior. The historical Probe Bridge moved to a host-side target, so
`StornautCodex` has neither direct nor transitive package reachability to
`StornautCore`.

The repository verifier independently checks:

- exact direct dependencies and transitive Codex reachability;
- absence of cleanup/Policy/Executor symbols from Codex runtime source;
- authority-like field names throughout the v2 JSON Schema;
- the actual shared `spawnDiagnosticProcess` body for CLOEXEC, process-group
  isolation, fixed working directory and `posix_spawn`;
- App Server use of that checked spawn function;
- one exact typed Runtime environment key set;
- one exact App Server request field set;
- absence of XPC/Mach/cleanup callback surfaces.

This is structural source/package evidence. It does not claim that a successful
model call itself proves no-Executor containment.

## 4. Independent Review Findings

The `bits-code-guard` working-tree workflow reviewed 22 reviewable files in
four serial fallback groups because subagent delegation was not authorized in
this run. The repository has no custom review workflow.

### R4-01 — Valid JSON supplementary Unicode was rejected

**Severity before fix:** P1 protocol compatibility
**Disposition:** Fixed

The duplicate-key auditor rejected every UTF-16 surrogate code unit, including
a valid high/low pair such as `\uD83D\uDE80`. JSON emitted by a conforming
producer could therefore pass Foundation decoding but fail the strict preflight.

The auditor now combines valid high/low pairs into one Unicode scalar and
continues to reject isolated or malformed surrogates. A focused regression
uses an escaped rocket scalar.

### R4-02 — Public URL provenance accepted ambiguous host spellings

**Severity before fix:** P1 privacy/integrity
**Disposition:** Fixed

The first URL check rejected canonical loopback/private literals but accepted
ambiguous forms such as trailing-dot localhost, legacy IPv4 notation and
malformed DNS labels. Those strings are unsafe provenance because another
resolver can interpret them as local or otherwise non-public.

The final normalizer:

- rejects trailing-dot hosts and malformed DNS labels;
- accepts only canonical decimal IPv4 literals;
- rejects legacy IPv4 spellings;
- rejects loopback, unspecified, private, shared, link-local, multicast,
  benchmarking and documentation-only IPv4 ranges;
- rejects local, link-local, unique-local, multicast, documentation,
  discard-only, IPv4-mapped and IPv4-compatible non-public IPv6 literals;
- strips credentials by rejection and removes query/fragment before retention.

Regression tests preserve canonical public DNS, IPv4 and IPv6 examples.

### R4-03 — Initial verifier could produce a textual false green

**Severity before fix:** P1 gate-integrity
**Disposition:** Fixed

The first verifier only searched whole files for
`POSIX_SPAWN_CLOEXEC_DEFAULT` and `let allowedKeys = Set`. An unrelated
occurrence could satisfy those checks after the real App Server spawn or
environment contract drifted.

The verifier now extracts and checks the actual declaration bodies, proves the
App Server runner calls the checked spawn seam, compares exact environment and
request field sets, and computes transitive package reachability.

### R4-04 — Adversarial coverage did not exercise every declared bound

**Severity before fix:** P2 test reliability
**Disposition:** Fixed

The initial tests covered representative byte and identity failures but not
every nested authority layer or every collection limit promised by the brief.
The final suite injects authority fields at each nested wire layer and directly
tests item summary, uncertainty, reference, evidence, finding, proposal,
degradation and context limits.

### R4-05 — Advisory text allowed terminal control characters

**Severity before fix:** P2 output hygiene
**Disposition:** Fixed

The original bounded-text helper rejected NUL but allowed other control
characters. A decoded advisory summary could therefore contain terminal escape
sequences or non-printing controls before later UI/report projection.

The final decoder rejects control characters except newline and tab, preserving
bounded multi-line prose while preventing terminal-control injection. The
focused suite includes an ESC-sequence regression.

Final independent-review result:

```text
P0 unresolved: 0
P1 unresolved: 0
P2 unresolved: 0
```

Review artifacts:

```text
/tmp/stornaut_r4_review_1786522094/report.html
SHA-256 26c79bf553c5220c8617bc905e063a1cc75392080fcb40ffdbf3c1a3c6ca0f2d

/tmp/stornaut_r4_review_1786522094/report.md
SHA-256 0ea59f19bab57b34087ca086ca229350c7e856ddb6710b42e7484aa0ac8984ef
```

## 5. Verification

Focused Investigation Envelope v2:

```text
15/15 passed
/tmp/stornaut-r4-v2-final-2.log
SHA-256 faad225d0824b7d5daa37e31866586b80aa13692259a5c6376f00780ef435b69
```

Focused protocol/package boundary:

```text
3/3 passed
/tmp/stornaut-r4-boundary-final-2.log
SHA-256 6555d5e981fb90d00d35e321d311ce9677177352466f4df73f26ab11d8d3e859
```

Probe Bridge and process lifecycle regressions:

```text
5/5 Probe Bridge tests passed
15/15 Codex process tests passed

/tmp/stornaut-r4-probe-bridge-final.log
SHA-256 32c6f160da5d30ea096c179d797d17a8ffdd336408f3d72f15bc94759283b549

/tmp/stornaut-r4-process-final.log
SHA-256 0d7804837d1a0bfedb6aa044874eec1e8ead1131f786ade4f75963512613f499
```

No-Executor verifier:

```text
passed
/tmp/stornaut-r4-no-executor-final-2.log
SHA-256 ccdec24fb79539684fbc50e9b0fc4209652d8e5b02bb6b4d13f8f40646cfe2b9
```

Complete Codex and SwiftPM suites:

```text
148/148 StornautCodexTests passed; four opt-in diagnostics skipped
/tmp/stornaut-r4-codex-full-final-2.log
SHA-256 b17858ede46a66e926df1484e95ed4b82eefe123281aa7a57f4805bd3b765eb8

420/420 serial SwiftPM tests passed; opt-in diagnostics skipped
/tmp/stornaut-r4-swift-full-final-2.log
SHA-256 eb9870677176e6b2865ae244e8a473b3c02cf2eafa7301cd82b2f769585489fc
```

Headless repository verifier:

```text
passed; 417 non-benchmark Swift tests plus source, compiler, App and docs gates
/tmp/stornaut-r4-headless-final-2.log
SHA-256 2c50431f0a1c82400da327de36f7bc32510756309c2cce4c18f18a2f2411547d
```

XcodeBuildMCP App contract regression:

```text
114/114 passed; UI tests intentionally skipped because R4 has no UI change
~/Library/Developer/XcodeBuildMCP/workspaces/stornaut-26b7f3f69f83/
result-bundles/test_macos_2026-08-12T08-40-16-128Z_pid51792_b34c55dc.xcresult

build log SHA-256
d1f8ec8a4f5b2f84c756dedc88f046978e2ab3eedb95093fe01ecac233f4bbd8
```

Documentation links and diff hygiene passed. No credential, private key,
private file content, raw Codex JSONL or real user path is added.

## 6. Gate Result

- protocol: `protocolReady`;
- identity and reference integrity: passed;
- public URL privacy: passed for normalized retained provenance;
- structural no-Executor seam: passed;
- historical v1 compatibility: retained and isolated;
- production Deep Dive: still unavailable;
- R5 signed-App capability/containment diagnostic: pending;
- R6 final admission: pending.

R4 is admitted for one independent commit and push. R5 may start only after
`HEAD == origin/main` for that commit.
