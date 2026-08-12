# R4 Implementation Brief: Investigation Protocol v2 and No-Executor Seam

> Status: Complete — `protocolReady`
>
> Prepared: 2026-08-12
>
> Baseline: `428656b5a3e38120d33f30a9e769a66ffdc39965`
>
> Plan:
> [Capability-First Runtime Gate](capability-first-codex-runtime-gate.md)
>
> Previous gate:
> [R3 Review](../../reports/capability-first-runtime-r3-review.md)

## 1. Gate Purpose

R4 converts the R3 behavior-ready runtime into one bounded, versioned,
advisory result protocol and proves that neither the Codex process nor decoded
model output can reach Stornaut cleanup authority.

R4 must establish:

```text
untrusted Codex final JSON
→ strict Investigation Envelope v2 decoder
→ Swift-supplied identity binding
→ bounded advisory report
→ no PolicyDecision / authorization / Trash / Registered Action / Executor
```

R4 does not:

- implement a production Deep Dive coordinator;
- create a CleanupPlan or PolicyDecision from Codex output;
- add an XPC, Mach, callback or inherited-descriptor cleanup route;
- enable product Deep Dive;
- prove signed-App capabilities or helper packaging;
- start Epic 8 Task 29.

R5 owns signed-App observed capabilities. R6 owns the final admission
decision.

## 2. Confirmed Tests-First Gaps

The first R4 red suite confirms:

1. `StornautCodex` directly links the complete `StornautCore` target, which
   includes Policy, Trash, Registered Action and Executor implementations.
   Source grep alone cannot prove no-Executor reachability while that package
   edge exists.
2. historical `InvestigationEnvelope` v1 has no protocol version, run
   identity, Swift target/candidate binding, evidence provenance, coverage,
   capability degradation, confidence or explicit uncertainty. It remains
   valid historical data but cannot become the R4 runtime contract.

Evidence:

```text
Tests/StornautCodexTests/R4ProtocolBoundaryTests.swift
/tmp/stornaut-r4-tests-red-2.log
```

The v1 compatibility case passed. The v2 schema and package-boundary cases
failed for the expected missing artifacts/edges.

## 3. Module Boundary

### 3.1 `StornautProcessSupport`

Move generic process-group lifecycle support into a target that contains only:

- `ProcessGroupID`;
- `ProcessTreeTerminator`;
- typed termination transitions/errors.

Both `StornautCore` and `StornautCodex` may depend on this target. It contains
no filesystem cleanup, Policy, persistence, Probe Broker or domain model.

### 3.2 `StornautProbeBridge`

Move the historical typed Probe Bridge into a separate host-side target:

```text
StornautProbeBridge
→ StornautCodex for JSONValue only
→ StornautCore for bounded Probe Broker contracts
```

`StornautCodex` must not depend on `StornautProbeBridge` or `StornautCore`.
The bridge is Swift-host functionality; it is not an Executor route and is not
exposed as a generic child-process IPC endpoint in R4.

### 3.3 Package graph requirement

The admitting graph is:

```text
StornautCodex → StornautProcessSupport
StornautCore → StornautProcessSupport
StornautProbeBridge → StornautCodex + StornautCore
```

Any direct or transitive path from `StornautCodex` to `StornautCore` blocks
R4.

## 4. Investigation Envelope v2

### 4.1 Swift-owned context

Swift creates a non-Codable `InvestigationProtocolContext` before model
execution. It contains:

- one bounded `investigationID`;
- one bounded `runID`;
- the exact allowed target IDs;
- the exact candidate-to-target ID map;
- the required capability set for this run.

The model may echo these IDs but cannot invent a new target/candidate or
rebind a candidate to another target. The protocol contains no model-supplied
filesystem path.

### 4.2 Top-level wire object

The exact required keys are:

```text
protocolVersion
investigationID
runID
summary
coverage
evidence
findings
candidateProposals
capabilityDegradations
```

`protocolVersion` is exactly `2`. Unknown or missing fields at any nesting
level fail closed.

### 4.3 Evidence

Each evidence entry has:

- unique bounded evidence ID;
- one Swift-known target ID;
- closed source enum;
- bounded summary;
- optional public URL provenance.

Closed source values:

```text
probeBroker
directFile
shell
liveSearch
browserOrDirectFetch
image
skill
subagent
```

Source display labels are Swift-owned computed values. Direct evidence cannot
claim Broker filtering/redaction guarantees.

Public URL provenance:

- is allowed only for `liveSearch` or `browserOrDirectFetch`;
- accepts only `http`/`https` with a public hostname;
- rejects credentials, localhost, private/link-local literal addresses and
  invalid ports;
- strips query and fragment before retention;
- is bounded after normalization.

R4 records only the normalized origin/path reference, not response bodies,
search queries or raw browser content.

### 4.4 Coverage

Coverage contains:

- unique investigated target IDs;
- unique unresolved target objects with target ID and bounded reason.

Every Swift-known target appears exactly once across investigated and
unresolved sets. Unknown, duplicate or overlapping IDs fail closed.

### 4.5 Findings and candidate proposals

Findings contain:

- unique finding ID;
- one investigated target ID;
- bounded summary;
- one or more non-dangling evidence IDs for that same target;
- closed confidence (`low`, `medium`, `high`);
- explicit bounded uncertainty text.

Candidate proposals contain:

- one Swift-known candidate ID;
- its exact Swift-bound target ID;
- bounded advisory summary;
- non-dangling same-target evidence IDs;
- closed confidence;
- explicit uncertainty.

There is no action, command, executable, argument, path, authorization,
Policy, journal, Trash or Executor field.

### 4.6 Capability degradation

Each entry contains:

- one closed required capability;
- one bounded stable reason key;
- one bounded user-facing summary.

Capabilities are unique. A capability not required by the Swift context cannot
be reported as a runtime degradation for that run.

### 4.7 Bounds

The decoder enforces UTF-8 bytes, not only character counts:

- aggregate input: 1 MiB;
- summary: 8 KiB;
- IDs/reason keys: 256 bytes;
- evidence/finding/proposal/degradation summaries: 4 KiB;
- uncertainty: 2 KiB;
- URL: 2 KiB after normalization;
- evidence: 512;
- findings: 256;
- candidate proposals: 256;
- capability degradations: all closed capabilities at most;
- per-item evidence references: 64.

Duplicate IDs, duplicate references and integer/array overflow fail closed.

## 5. Advisory Normalization

`InvestigationEnvelopeV2.decodeValidated` returns only validated protocol
types. A separate `InvestigationAdvisoryNormalizer` produces a bounded
`InvestigationAdvisoryReport`.

The report:

- preserves only Swift-bound IDs, summaries, normalized provenance,
  confidence and uncertainty;
- contains no path or executable action;
- is not a `CleanupPlan`, `PolicyDecision`, `ExecutionAuthorization`,
  `CleanupAction`, journal or Manifest;
- cannot be converted to Core execution types inside `StornautCodex`.

A future App/Core coordinator must explicitly look up retained target/candidate
IDs and perform canonicalization, current identity checks and Policy before
creating any deterministic proposal. R4 does not implement that coordinator.

## 6. Historical v1

`InvestigationEnvelope.decodeValidated` remains available only for historical
Task 4 fixtures and records. It is not silently promoted to v2 and cannot be
used as an R4 behavior-ready result.

The checked-in v1 schema remains unchanged. R4 adds a separate
`investigation-envelope-v2.schema.json`.

## 7. No-Executor Verifier

Create `scripts/verify-codex-no-executor-boundary` to prove:

1. the package graph matches §3.3;
2. `StornautProcessSupport` has no dependency;
3. `Sources/StornautCodex` imports neither `StornautCore` nor
   `StornautProbeBridge`;
4. Codex source contains no PolicyDecision, ExecutionAuthorization,
   CleanupPlan, CleanupAction, TrashMoving, RegisteredAction, ActionExecutor,
   CleanupRunJournal or persistence invocation;
5. the v2 schema recursively excludes action/authority field names;
6. App Server environment and spawn continue to use a closed key set and
   `POSIX_SPAWN_CLOEXEC_DEFAULT`;
7. no cleanup endpoint, Mach/XPC service name or callback appears in the child
   request/environment contract.

The verifier is added to both headless and full repository verification.

## 8. Tests First

Create:

```text
Tests/StornautCodexTests/R4ProtocolBoundaryTests.swift
Tests/StornautCodexTests/InvestigationEnvelopeV2Tests.swift
Tests/Fixtures/Codex/investigation-envelope-v2-valid.json
```

Test:

- exact schema keys and recursive authority-field absence;
- exact package dependencies;
- successful v2 decode and advisory normalization;
- version/context mismatch;
- strict unknown/missing nested fields;
- aggregate/string/array UTF-8 byte bounds;
- duplicates and dangling/cross-target references;
- unknown source/capability/confidence values;
- complete coverage partition;
- forged target/candidate IDs and candidate rebind;
- prompt-injection text remains inert data;
- public URL credential/query/fragment/private-host handling;
- direct evidence cannot claim Broker provenance;
- action-like fields at every nesting layer;
- historical v1 decode remains available.

## 9. Verification and Gate

Required:

```text
swift test --filter R4ProtocolBoundaryTests
swift test --filter InvestigationEnvelopeV2Tests
scripts/verify-codex-no-executor-boundary
swift test --filter StornautCodexTests
swift test --no-parallel
scripts/verify --headless
scripts/check-doc-links
git diff --check
independent review has zero unresolved P0–P2
```

R4 passes only when:

- v2 is strict, bounded, identity-bound and advisory-only;
- v1 remains explicitly historical;
- `StornautCodex` has no package reachability to Executor-bearing targets;
- the verifier is part of the repository gate;
- no production Deep Dive or cleanup route is introduced.

Any ambiguous action reachability, schema confusion, privacy leak or missing
identity proof yields `protocolBlocked` and stops R5–R6.

R4 ends with one independent commit/push and remote-state check. R5 starts only
after that gate passes.

Final evidence:
[Capability-First Runtime R4 Review](../../reports/capability-first-runtime-r4-review.md).
