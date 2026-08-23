# Stornaut Phase D — Conditional Deep Dive Product Flow Plan

> **Status:** Approved for sequential Tasks 36–44; Tasks 36–38 are complete.
> Task 38 passed implementation, independent review, an 811-test serialized
> regression and the 23/23-stage authoritative full verifier. Task 39 is in
> progress: 39A, 39B1a, 39B1b-i, 39B1b-ii, 39B2a and 39B2b-i are complete
> and independently verified. 39B2b-ii prerequisite authority extraction is
> complete; the resumed signed diagnostic-App/Task 38 composition has passed
> focused validation, strict final-Mach-O admission and independent post-fix
> review. Its single authoritative full verifier passed 23/23 stages in 981
> wall-clock seconds, including the 898-test serialized regression, with no
> restart or stage retry. 39B2b-ii is complete. The narrow 39B2c
> attempt-binding prerequisite is also complete, followed by strict decoding,
> L1/L2 observation, L3 trusted-target/root-collection and L3c1a typed-owner
> prerequisites. L3c1b-i closed the configuration-bound memory-only helper
> escrow, and L3c1b-ii closed the synthetic non-Codable Machine claim/collector
> join; their 1025- and 1035-test clean staged-only serials plus independent
> reviews passed. L3c1 is complete. The mandatory L3c2 preflight split claim
> transport, root-host/topology composition and eight-scenario driving into
> L3c2a-i/L3c2a-ii/L3c2b. L3c2a-i strict Machine-claim transport is complete
> after a 1041-test clean staged-only serial and independent post-fix review;
> L3c2a-ii root host/topology is also complete after a 1046-test clean staged-only
> serial and independent post-fix review. L3c2b deterministic eight-scenario
> driving is complete after its exact eight-path implementation, layered gates,
> 1,055-test clean staged-only serial and independent final review. L3c3a then
> closed the strict driver-bound attempt schema after its 1,057-test serial and
> independent post-fix review. L3c3b preflight split native packaging from
> installer/L2 admission. A final-Mach-O spike then inserted L3c3b-0 authority
> closure before packaging. Its zero-dependency DriverSupport, final-Mach-O
> authority gates, 1,059-test clean staged-only serial and independent post-fix
> review passed. L3c3b-i diagnostic-only native packaging, final-artifact gates,
> 1,060-test clean staged-only serial and post-fix/cross-group review also passed.
> L3c3b-ii installer/L2 admission is complete. L3c3c-i transport/root-launch
> audit is also complete: B3/B4 algorithm evidence is retained, while `sudo -v`
> and UID-staged no-cache external root paths are NO-GO. i-b2b-0b/i-b2b-1 were
> superseded before execution; B4 root count is zero. ADR 0018 remains Proposed.
> L3c3c-ii-a authority-closed installed-driver/manifest observation and exact
> source/final-Mach-O admission are complete. ii-b is split into ii-b0a/ii-b0b
> and ii-b1–ii-b5 with ii-c0 before the privileged gate. ii-b0a exact
> frame/capsule, ii-b0b claim/release and ii-b0c bootstrap implementations are
> complete. ii-b1 is also complete after the post-RED topology correction split
> one Debug-only diagnostic target from one dependency-free Release shell. The
> ii-b2 ASID prerequisite is complete after separate 1,142-test implementation
> and 1,143-test decoder-negative supplement serials. ii-b2a typed escrow/
> deadline state is complete after its 1,162-test combined serial. ii-b2b-i
> non-connected server integration is complete after its 1,194-test staged-only
> serial and post-fix reviews; ii-b2b-ii legacy-client quarantine / Machine
> production block is complete after its helper-private legacy server correction,
> complete App/main-Mach-O gate and 1,196-test staged-only serial. ii-b2b-iii
> live-helper server migration has been split into iii-a handle-v3/single-
> quantized transfer and iii-b public live façade/helper integration; iii-a,
> iii-b-i semantic/live integration, iii-b-ii executable physical-adapter
> closure and ii-b3a/ii-b3b are complete/non-admitting; iii-b/ii-b2b are
> closed; ii-b3c, ii-b4, ii-b5a0, ii-b5a, ii-b5b-i-a, i-b1 and i-b2a are
> complete/non-admitting; i-b2b-a, i-b2b-b, i-b3 and i-c1 are
> complete/non-admitting; aggregate i-c2 semantic/physical-owner closure and
> ii-b5b-ii-a fixed FD-0 capsule intake, ii-b5b-ii-b independent Darwin App
> identity observation, ii-b5b-ii-c fixed FD-7 session and ii-b5b-ii-d exact
> owned-PGID retirement and ii-c0a projection-in-capsule input/intake are
> complete/non-admitting. ii-b5b-iii is current, followed by ii-c0b and then
> ii-c one no-model privileged gate. The authoritative
> real-model run and readiness verdict remain unimplemented.
> Production Deep Dive remains unavailable until Task 44 admission.
>
> **Roadmap phase:** Phase D — Conditional Deep Dive
>
> **Implementation baseline:** authoritative pushed Phase C / Task 35 closure
> `86ee2aa9428cfc71036e18dcb2c1349ec248ec73`; Phase D is materialized directly
> on this baseline and does not inherit any synthetic replay commit.
>
> **Runtime prerequisite:** capability-first Runtime R1–R6 foundation `go`.
>
> **Normative low-level contract:**
> [Investigation Canonical v1](../../specs/investigation-canonical-v1.md). Codec/tag tables, source-manifest
> bounds, priority arithmetic, clocks, reserve/commit/release lifecycle,
> runtime-event normalization, URL persistence and capability evidence in that
> specification override every summary in this plan.
>
> **Scope rule:** This phase productionizes investigation only. It does not add
> an Adapter, Registered Action, permanent deletion, release distribution,
> notarization, background monitoring, scheduled scanning, login launch item,
> telemetry, remote rule service, or a second Policy/Executor path.

## Goal

Deliver one complete, evidence-driven Deep Dive product flow:

```text
latest retained Quick Scan
→ deterministic Candidate Planner
→ bounded Investigation Plan
→ first-use aggregate disclosure
→ closed capability-first Codex runtime
→ direct read / shell / live web / browser / image / skills / subagents
   plus preferred typed Probe Broker evidence
→ strict Investigation Envelope v2
→ Swift identity binding and normalization
→ durable partial/final Evidence Report
→ non-authoritative Review proposal
→ existing Phase C CleanupPlan / Policy / selection / confirmation path
→ existing Phase C Executor only after normal user admission
```

The Phase D gate must prove that production Deep Dive preserves both sides of
ADR 0004:

1. Codex has the complete approved read-only Agent capability surface and
   public internet access needed for useful investigation.
2. Codex and all descendants remain OS-contained from user-data writes,
   localhost/private/link-local destinations, arbitrary Unix sockets, Policy,
   Trash and Executor.

Deep Dive remains `.implementationUnavailable` until the final Task in this
plan passes. A runtime receipt, Codex discovery, Settings toggle, disclosure
acceptance, or successful model call alone must not enable it.

### Normative terminology correction

PRD §6.2 currently says “Codex generates `InvestigationPlan`”, while the
architecture assigns candidate and budget construction to Swift and limits
Codex output to advisory evidence/proposals. Phase D must resolve that drift:

- `InvestigationPlan` means the deterministic, Swift-owned admitted target and
  budget contract;
- Codex owns the dynamic investigation strategy within that contract;
- Codex may propose the next target/evidence hypothesis, but does not mint,
  rewrite or expand the admitted Plan.

The checked-in Phase D plan must update the PRD/architecture wording together
before Task 36 implementation. This is a terminology correction, not a product
scope change.

## 1. Non-Negotiable Architecture

### 1.1 One authority path

Codex returns advisory evidence, findings and candidate proposals only.
Neither a prompt, final envelope, normalized report nor persisted
Investigation record is execution authority.

All cleanup-capable output must rejoin the existing Phase C chain:

```text
retained Swift IDs
→ current Store lookup
→ canonical path / identity resolution
→ deterministic CleanupPlanBuilder
→ CleanupPolicyGate
→ explicit in-memory ReviewSelection
→ exact confirmation
→ one-shot ExecutionAuthorization
→ CleanupExecutionRuntime
→ ActionPolicyGate
→ ActionExecutor
```

Phase D must not:

- create an Agent-specific executor, action runner, authorization, Trash
  adapter or direct filesystem mutation;
- accept a path, action, shell command, disposition, Policy decision or
  authorization from model output;
- allow Agent-only evidence to produce default-selected
  `Ready to Reclaim`;
- persist or replay execution authority.

### 1.2 Module boundary

The product coordinator should be a dedicated `StornautInvestigation` SwiftPM
target once runtime integration begins. It may depend on:

- `StornautCore` for investigation domain, Store and deterministic projection;
- `StornautCodex` for the closed runtime and strict advisory protocol;
- `StornautLifecycle` for the already accepted audit-session lifecycle
  boundary;
- `StornautProcessSupport` only through the runtime modules that already own
  process termination.

It must have no product API accepting or returning:

- `CleanupExecutionRuntime`;
- `ActionExecutor`;
- `ExecutionAuthorization`;
- `CleanupAction`;
- `RegisteredActionDefinition`;
- arbitrary executable or shell arguments.

A checked-in structural verifier must reject references from
`StornautInvestigation`, `StornautCodex`, Lifecycle helpers, prompt resources
and App Investigation views to Executor/Trash/authorization construction.

### 1.3 IDs, not model-provided paths

Swift creates and retains:

- Investigation ID;
- run/attempt ID;
- source Scan session and scope IDs;
- Investigation target IDs;
- candidate proposal IDs;
- exact target-to-snapshot/classification bindings;
- budget and stop-policy fingerprints.

The final Envelope v2 must echo only the admitted IDs. Model-provided paths,
actions, Policy, authorization or cleanup fields are forbidden by schema.
Swift resolves retained IDs back to current Store records before any later
planning or Review projection.

### 1.4 Runtime composition remains closed

Production runtime construction must reuse the exact accepted R5/R6
capability-first ingredients:

- closed runtime profile and environment;
- isolated owner-only runtime workspace with no repository/target
  `AGENTS.md`;
- projected authenticated Codex state without modifying
  `~/.codex/config.toml`;
- same-investigation, parent-owned random-loopback managed proxy exception;
- OS blocking for every other localhost/private/link-local destination and
  every Unix socket;
- outer write denial inherited by the entire audit-session process tree;
- lifecycle lease, cancellation, timeout, crash recovery and zero-residue
  drain;
- strict App/helper identity binding;
- Investigation Envelope v2 decoder and source/capability labels;
- no Executor module or XPC operation in the investigation protocol.

The diagnostic worker and production coordinator may share low-level
components, but diagnostic-only canaries, hard-coded evidence and fixture
tokens cannot enter the product prompt or report path.

## 2. Prompt-to-Artifact Matrix

| Stage | Owner | Inputs | Output | Persisted | Authority |
| --- | --- | --- | --- | --- | --- |
| Candidate planning | Swift Core | retained terminal Quick Scan, Space Ledger, classifications, evidence, user budget preset | `InvestigationPlan` with retained IDs, priorities, budgets and stop policy | Task 37, 7 days | none |
| Runtime context | Swift Investigation | admitted plan, compact typed evidence, approved read scope, current runtime receipt | strict context + prompt resources + Envelope v2 schema | no raw prompt; bounded plan fingerprint only | none |
| Investigation | contained Codex | direct read-only tools, Probe Broker, public internet, current compact context | tool events and one final Envelope v2 | raw events deleted normally; crash residue <= 24h | none |
| Protocol decode | StornautCodex | final Agent message + exact `InvestigationProtocolContext` | validated `InvestigationAdvisoryReport` | not directly | none |
| Normalization | Swift Investigation/Core | advisory report + retained ID map + budget ledger + runtime receipt | typed `InvestigationReport` with source labels, coverage, unresolved targets and degradations | Task 37, 7 days | none |
| Review projection | Swift Core | retained report IDs joined back to current Store records | findings, Evidence summaries and candidate rows | derived / bounded report payload | none |
| Cleanup planning | existing Phase C Core | current deterministic evidence and approved execution profiles | existing `CleanupPlan` / `ReviewProjection` | existing 7-day rules | proposal only |
| Execution | existing Phase C App/Core | explicit selection, fresh Policy, exact confirmation, one-shot authorization | existing journal, Manifest, Result, History | existing 7/90-day rules | existing typed authority only |

### Artifact restrictions

- Do not persist raw file snippets, prompt text, hidden reasoning, raw JSONL,
  stdout/stderr, cookies, tokens, credentials or encountered secret values.
- Persisted web provenance is origin-only:
  `https://<lowercase-ASCII-public-DNS-host>/`. It permits no userinfo,
  non-default port, path, query or fragment. An accepted source with any
  non-root path or removed component stores the origin plus a typed redaction
  reason; it never stores the removed bytes. IP literals, localhost, private,
  link-local, reserved/non-public hosts, non-HTTPS and malformed destinations
  store no URL, only a typed rejection reason. This closed representation
  cannot retain signed URLs, token-like paths, credentials, secret-bearing
  parameters, percent-encoded local paths or user Home paths.
- Direct-read/shell evidence must be labeled advisory and cannot pretend to
  carry Probe Broker audit guarantees.
- User-facing report text is bounded, normalized model output; it is not
  executable input and must never be interpolated into a command.
- Every partial/final report records exact coverage, unresolved targets,
  capability degradation, stop reason and whether continuation is allowed.

## 3. Investigation Domain

Phase D evolves the unused v1 `InvestigationTarget` placeholder into closed
product contracts. The domain must represent:

- `InvestigationID`, `InvestigationRunID` and report ID;
- source Scan session/scope and immutable source fingerprint;
- target kind:
  - large deterministic rule miss / unknown consumer;
  - unexplained Space Ledger reconciliation gap;
  - conflicting classification/risk evidence;
  - unknown producer;
  - stale or insufficient evidence;
- retained snapshot/classification bindings;
- one exact source binding per target: retained snapshot, retained
  classification+snapshot, or a closed Space Ledger measure key;
- expected allocated bytes when measurable;
- bounded uncertainty, user relevance and estimated investigation cost;
- stable deterministic priority and tie-break;
- budget limits and a provenance-preserving ledger:
  - hard Swift admission for wall clock, coordinator/model turns, Probe calls,
    Probe read/output reservations, Swift-built model-context bytes and Probe
    concurrency;
  - event-time observation for direct Agent tool starts and token usage;
  - typed `unavailable`/invalid usage rather than fabricated zero;
  - consecutive verified no-evidence-gain steps;
- stages: `Prioritize`, `Identify`, `Verify`, `Build Plan`;
- run state: planned, awaiting disclosure, ready, running, pause requested,
  stop requested, terminal barrier, completed, partial, blocked or failed;
  session aggregate state additionally includes `paused`. Pause closes the
  current run as `partial` and only then projects the owning session as
  `paused`; no run is persisted with state `paused`. Stop and cancellation
  are distinct requests with immutable primary causes. After the terminal
  barrier and atomic commit they become `partial(userStopped)` and
  `partial(userCancelled)` respectively; neither is a standalone persisted
  or UI terminal state;
- required stop reasons:
  - coverage reached;
  - remaining unknown below threshold;
  - budget exhausted, with exact dimension;
  - no evidence gain;
  - user stop;
  - user cancellation;
- safety/runtime/protocol failures as typed blocked/failed outcomes rather than
  false scientific stop success;
- bounded coverage and evidence-gain deltas;
- immutable partial/final report status and continuation lineage.

Wall-clock presets are normative:

- Focused: 10 minutes;
- Balanced: 30 minutes, default;
- Thorough: 60 minutes.

Task 36 pins exact non-wall-clock defaults in its Upstream Study and ADR.
They are finite, positive, monotonic across presets and visible in advanced
disclosure. No preset disables an approved investigation capability.

The budget contract distinguishes enforcement quality:

| Dimension | Focused | Balanced | Thorough | Quality |
| --- | ---: | ---: | ---: | --- |
| Wall clock | 600 s | 1,800 s | 3,600 s | hard |
| Coordinator/model turns | 4 | 12 | 24 | hard before `turn/start` |
| Probe calls | 16 | 48 | 96 | hard reservation |
| Probe read | 8 MiB | 32 MiB | 64 MiB | hard reservation |
| Probe output | 2 MiB | 8 MiB | 16 MiB | hard reservation |
| Swift-built context, cumulative | 1 MiB | 4 MiB | 8 MiB | hard reservation |
| Concurrent Probes | 2 | 4 | 8 | hard admission |
| Consecutive verified no-gain steps | 2 | 3 | 4 | hard stop |
| Direct Agent tool starts | 32 | 96 | 192 | event-time observed |
| Total tokens | 100,000 | 300,000 | 600,000 | event-time observed, may be unavailable |

Every single Swift-built model input is additionally limited to 256 KiB, and
the lower existing protocol limit always wins. Observed ceilings are stopping
ceilings, not exact prepaid cost guarantees: an admitted turn may cross one
before the event arrives. The coordinator then requests one bounded
interruption, admits no later turn, drains the runtime and reports the exact
overrun. Missing token usage is a typed degradation, never `0`.

All elapsed-time decisions use one injected `ContinuousClock`. The serial
coordinator samples immutable `runStart` atomically with the transition into
running, and evaluates `runStart.duration(to: now)`. It samples immutable T0
exactly once at the first accepted fact whose normative precedence closes
scientific admission; later causes are retained only as secondary facts.
Wall-calendar timestamps are metadata and never drive admission.

The wall-clock deadline closes admission of new scientific work. A separate
140-monotonic-second terminal settlement envelope starts at T0:

```text
T0:
  atomically close turn/Probe/context admission and record the cause
  send at most one interrupt for each active (threadID, turnID)
T0...T0+15s:
  collect only matching item/usage/turn terminal events
  never promote evidence from an unterminated turn
at all turns terminal, or T0+15s:
  invoke the idempotent audit-session drain
by T0+45s:
  prove audit session and proxy owner empty
  retire ephemeral artifacts
  begin the Store-owned terminal transaction no later than this instant
by T0+135s:
  atomically commit terminal truth
by T0+140s:
  if commit did not succeed, finish rollback/connection cleanup or quarantine
```

Missing terminal events followed by proved forced drain yield
`blocked(runtimeTerminalUnobserved)`. Unproved process/proxy drain yields
`blocked(lifecycleDrainUnconfirmed)`. Terminal persistence failure yields
`failed(terminalPersistenceFailed)`. The Store operation keeps Task 37's
independent 90-second deadline and separate 5-second cleanup bound; starting it
no later than T0+45 makes T0+140 the exact outer settlement bound. The envelope
is not additional scientific budget and none of those outcomes may appear as
cancelled, paused, budget-complete or successful.

Observed direct-tool and token ceilings apply to the whole
same-investigation live session tree, including spawned descendant
threads/subagents. Task 38 must bind descendants to the admitted run,
deduplicate cumulative/replayed usage and reject unrelated events.

Task 36 defines a Core-neutral observation ledger; Task 38 is the only App
Server wire decoder. The runtime receipt selects exactly one collaboration
schema and the closed direct-tool item set for the run, as specified by the
normative canonical v1 contract. The normalized contract requires
Investigation/run identity, root session ID, thread/parent/turn/item IDs, a
closed observation kind, source-method token and serial coordinator ordinal:

- the root ephemeral thread requires `thread.id == thread.sessionId`;
- a child is admitted only after the receipt-selected canonical collaboration
  spawn edge and matching `parentThreadId` plus root `sessionId`;
- production never resumes or forks a stored runtime thread; transport loss
  blocks and drains;
- the first valid `item/started` for unique
  `(threadID, turnID, itemID)` counts once only when its type belongs to the
  receipt-selected closed direct-tool set;
- equal replay is a no-op; conflicting duplicate, `fileChange`, unknown
  tool-capable item or write-capable MCP annotation blocks;
- `thread/tokenUsage/updated` carries `threadID`, `turnID`, cumulative `total`,
  `last` and optional context-window fields;
- each admitted thread retains only its latest nondecreasing cumulative
  `total`; run total is the sum of each latest `total.totalTokens` once, never
  `last` or cached input;
- negative, decreasing, conflicting or identity-mismatched usage blocks;
- no matching usage snapshot by the terminal barrier becomes
  `usageUnavailable`, never zero or an estimate;
- finalization rejects every live or unclassified descendant.

## 4. Candidate Planner

The Planner is deterministic Swift and operates only on one retained terminal
Quick Scan projection. Its caller supplies one `InvestigationID` and injected
current time; the Planner must not call `UUID()` or read the system clock. It
must:

1. reject missing, corrupt, expired, non-terminal or scope/root-mismatched
   source records;
2. generate candidates only from the approved target kinds;
3. retain source IDs and one exact source binding without exposing authority;
4. calculate a deterministic priority equivalent to:

   ```text
   expectedBytes × uncertainty × userRelevance / estimatedProbeCost
   ```

   by rounding measurable bytes up to MiB, multiplying three `1...1_000`
   UInt64 factors with checked arithmetic, dividing by the cost factor with
   integer floor, and placing every measurable tier before the separate
   unmeasurable tier; the normative maximum numerator is below
   `UInt64.max`;
5. deduplicate multiple reasons for the same retained target while preserving
   all reason keys;
6. cap the admitted target set at Envelope v2's 512-target limit;
7. preserve Protected and Unknown semantics;
8. never convert a classification or create an executable action;
9. produce an empty, truthful plan when no target qualifies.

Planner output is a scientific work queue, not a cleanup recommendation.
An empty Planner result is terminal `noEligibleTargets` for admission: Task 37
rolls back its pass-one manifest rows and persists no Investigation session,
run or report; Task 38 does not start Codex. Empty output remains a tested Core
value so the absence of candidates is deterministic, but Store v4 admits only
run-owned Plans with `1...512` targets.

`CandidatePolicyV1` closes every product heuristic:

- an unknown large consumer requires measured allocated bytes greater than or
  equal to `1_073_741_824`; v1 has no scope-relative threshold;
- coverage is exactly `900` permille and remaining measurable Unknown stops
  only below `1_073_741_824` bytes;
- Plan expiry is the earlier of source-session expiry and injected creation
  time plus selected preset wall clock;
- relevance is base `700`, plus at most `100` each for closed tokens
  `relevance.large` and `relevance.developer`; unknown/duplicate tokens reject;
- fixed `(uncertainty,cost)` factors are
  `(750,250)/(1_000,800)/(1_000,350)/(850,400)/(700,300)` in target-kind
  order;
- one classification source produces at most one target, with precedence:
  conflict, unknown large, unknown producer, stale/insufficient;
- ordinary Ready is excluded; only contradictory Ready safety metadata may
  create a non-authoritative conflict target;
- missing classification creates only a snapshot-bound stale/insufficient
  target;
- an eligible reconciled ledger creates at most one measurable nonzero
  unknown-residual target and never converts unavailable, coverage-limited,
  inconsistent or measured-zero state into a candidate;
- a target has `1...16` reasons and the complete canonical Plan digest input is
  at most `2 MiB`; overflow rejects without truncation.

Target IDs are stable source identities:

```text
target-<full lowercase SHA-256>
```

The digest uses a versioned, domain-separated, length-prefixed canonical
encoding of Scan session, scope, target kind and source binding. Ledger-only
targets use a closed measure key and invent no path. Source, target-set and
plan fingerprints use separate domain tags. Reasons and priority do not change
target identity; duplicate derived IDs fail closed.

The normative codec is `StornautInvestigationCanonicalV1`:

- magic ASCII `STORNAUT-INV-CANON-1\0`, then one encoded domain string and one
  root record;
- nil `00`, false `01`, true `02`;
- UInt64 `10` plus 8-byte big-endian value;
- Int64 `11` plus 8-byte big-endian two's-complement value;
- text `20` plus UInt64 UTF-8 byte length and exact bytes;
- bytes `21` plus UInt64 length and exact bytes;
- array `30` plus UInt64 count and individually UInt64-length-prefixed encoded
  elements;
- record `40` plus UInt64 field count and strictly increasing unique
  big-endian UInt16 tags, each followed by a UInt64-length-prefixed encoded
  value.

Every optional field is present and encodes nil when absent. Enums use exact
lowercase versioned ASCII tokens. Dates are Int64 Unix microseconds truncated
toward zero. Text receives no Unicode, case, locale, path or percent
normalization. Invalid UTF-8, trailing bytes, missing optionals,
duplicate/out-of-order tags and non-domain values are rejected. Target,
source, target-set and plan use separate fixed domain strings. JSON,
reflection, native layout, dictionary order and `Hashable.hashValue` are
forbidden for identity. Task 36 pins complete encoded-hex/SHA-256 product
vectors plus the primitive SHA-256 vectors:

```text
empty      724b07f461c7690c1e0614abdbd72081d88622e2aab47183236b6bf8e049dc3b
primitives 56a27067b51cef0ebc1236d51200b250987fce1ee74832047fa2063ef0da9075
```

The normative specification contains the complete required tag/type tables,
enum tables, array class for every collection and complete encoded-hex/SHA-256
vectors for primitive, target, source, target-set and plan records. No
implementation may infer missing schema details from this summary.

`sourceFingerprint` is computed by Swift from the complete immutable typed-row
manifest; it is not accepted as caller text. The manifest binds the exact
stored UTF-8 payload SHA-256 and all non-payload identity columns for the one
session row, one complete Space Ledger row, and exhaustive selected-scope
snapshot/classification/evidence rows. Store identity checks, typed decode and
byte-identical `DomainJSON` re-encode must pass. The normative specification
fixes limits at 100,000 rows per record family, 100 evidence rows per snapshot,
300,002 total source rows, 256 relevance tokens, 256 MiB aggregate exact
source payload and 512 MiB complete canonical SourceProjection digest input.
No top-N truncation is allowed; any overflow blocks planning. The canonical
Plan identity input is independently bounded at 2 MiB; its strict persisted
`DomainJSON` representation is independently bounded at 4 MiB.

Task 37 persists that fingerprint and complete source-row manifest. It
recomputes exact membership and bytes at the specification's eight exhaustive
rejoin barriers: insertion, runtime admission, explicit active-run refresh,
terminal normalization, crash recovery, continuation, Review projection and
Agent proposal → `CleanupPlanBuilder` join. A mismatch is stale/corrupt, never
accepted by matching IDs alone. Legacy v1 targets are fixture/migration-only
and cannot enter planning, Plan construction, Store v4, runtime admission or
continuation without an explicit future migration that reconstructs and
verifies every v2 binding.

Maximum-size projection/rejoin is a repeatable two-pass stream over one
Store-owned pinned `BEGIN IMMEDIATE` snapshot. Swift validates and releases one
source payload at a time, incrementally computes canonical identity, and never
retains a complete source-payload array, 300,002-row manifest array or
512 MiB canonical buffer. Rejoin callers supply only typed Investigation ID
plus a closed barrier; expected normalized rows/fingerprint remain Store-owned.

## 5. Budget and Stop Semantics

The Swift coordinator owns budget accounting. Codex may suggest that enough
evidence exists, but it cannot increase a limit, consume/reset a counter or
override a stop.

Hard arithmetic is exact. For unsigned limit `L`, consumed amount `C` and
reservation `A`, admission succeeds only when:

```text
A > 0 && C <= L && A <= L - C
```

Exactly `L` is admitted, and the next operation is blocked. Checked arithmetic
is mandatory. Admitted turns and Probe calls remain consumed after failure or
interruption; reserved Probe read bytes remain consumed. Probe output is first
encoded and checked against its per-call bound, then atomically committed by
the current `reserveOutputBytes`; a failed encode/per-call/session commit
discards the response and consumes zero output bytes, while a committed amount
remains consumed after later delivery/audit failure. Context consumes when
accepted by `turn/start`. Probe concurrency is an actor-owned exactly-once
lease acquired only while `active < limit`; normal terminal paths release it
once, while recovery releases it only after lifecycle evidence proves no Probe
worker remains. Wall-clock work admits only while `elapsed < limit`.
Observed tools/tokens close later admission at `>= ceiling` and preserve any
exact overrun. Verified gain resets no-gain to zero; valid no-gain increments
once; invalid, cancelled or protocol-failed steps do not alter it. Duplicate
release, underflow, overflow, counter decrease and conflicting replay fail.

Hard admission and event-time observation are not interchangeable:

- before `turn/start`, Swift can enforce wall clock, turn count and
  Swift-built context reservations;
- the existing `ProbeSessionBudget` enforces Probe call/read/output
  reservations and is adapted from the plan rather than duplicated;
- direct Agent tool starts are counted from identity-valid canonical item
  events after turn admission;
- token usage is accepted only from identity-valid App Server usage events
  and may be unavailable;
- model prose, elapsed-time estimates and UTF-8 byte/token guesses never
  update consumption.

The coordinator evaluates stop conditions after every admitted evidence
delta and before every new Swift-owned admission. Precedence:

1. safety/runtime containment loss or invalid lifecycle state: block/fail,
   drain and produce a truthful partial report if retained evidence exists;
2. user cancellation: record `userCancelled` as the immutable primary cause,
   drain and commit `partial(userCancelled)`, preserving verified evidence;
3. user stop: record `userStopped` as the immutable primary cause, close later
   admission, drain and commit `partial(userStopped)`; a later final model
   event cannot overwrite it;
4. exhausted hard budget or a reservation that would exceed it: stop with the
   exact hard dimension;
5. identity-valid event-time observed ceiling reached: stop with the exact
   observed dimension and usage quality;
6. configured coverage reached;
7. remaining measurable Unknown below threshold;
8. configured consecutive no-evidence-gain limit;
9. otherwise continue.

Unavailable token usage proves neither exhaustion nor remaining capacity.
Unmeasurable Unknown cannot satisfy a byte threshold.

Pause is cooperative and occurs only at a safe coordinator boundary. It must
not claim to suspend an in-flight synchronous tool call or arbitrarily freeze
an audit session. If the production Codex protocol cannot expose a safe
between-step pause boundary, the truthful v1 behavior is:

```text
Pause requested
→ finish or request bounded interruption of the current admitted run
→ observe matching terminal turn/completed
→ drain the complete audit session
→ persist only the latest verified partial report
→ Paused
→ Resume starts a new run from retained IDs and that verified report
```

Unverified tool streams from a cancellation-requested run are not promoted to
evidence. Cancellation and timeout must drain the entire investigation audit
session and managed proxy owner before terminal truth. Cancellation is never a
standalone persisted/UI terminal state: a proved drain and successful commit
produce `partial(userCancelled)`. A separately accepted stop request produces
`partial(userStopped)` under the same barrier and atomic-commit rule. Drain or
persistence failures remain the canonical blocked/failed outcomes.

Every terminal path must produce either:

- a verified final report;
- a verified partial report with unresolved targets and continuation lineage;
- a typed blocked/failed state with no fabricated findings.

## 6. Store v4 Boundary

Task 37 owns the only Evidence Store migration in this phase. It evolves schema
v3 to v4 atomically and adds investigation-specific records. Proposed tables:

- `investigation_sessions`
  - source Scan/scope IDs and source fingerprint, aggregate state/stage,
    immutable seven-day retention anchor and bounded aggregate counters;
- `investigation_source_rows`
  - one bounded normalized row per canonical `SourceRowV1`, with contiguous
    ordinal, row kind/primary ID, the exact row-kind-specific non-payload
    storage columns, source payload byte count and source payload SHA-256;
    never copied source payload bytes;
- `investigation_relevance_tokens`
  - one bounded canonical relevance token per contiguous ordinal;
- `investigation_targets`
  - session ID, target ID, retained source bindings, priority, reason payload,
    terminal resolution;
- `investigation_runs`
  - run identity, immutable run-owned Plan/target-set fingerprints, strict
    bounded Plan JSON, budget preset, same-Investigation continuation parent,
    runtime state, bounded budget counters and terminal linkage;
- `investigation_run_targets`
  - one contiguous ordered membership row per admitted run target;
- `investigation_reports`
  - exactly one immutable final/partial normalized report for
    completed/partial runs; blocked/failed runs have zero reports/evidence and
    retain typed terminal run truth;
- `investigation_evidence`
  - bounded target-scoped evidence/finding/proposal records with source labels
    and retained target IDs;
  - every evidence row has a composite foreign key to the exact
    `(investigation_id, run_id, target_id)` admitted by
    `investigation_run_targets`; same-Investigation targets from another run
    are invalid;
- `investigation_report_degradations`
  - bounded report-scoped capability/usage/source degradation records with no
    invented target association;
- `investigation_budget_events`
  - typed aggregate consumption/delta records, never raw prompts/events.

Exact schema may combine immutable payload tables where that improves atomic
consistency, but it may not collapse the complete source manifest into one
session JSON payload and must preserve:

- strict typed/BLOB/byte-length/row-kind/ordinal constraints and
  same-Investigation composite foreign keys;
- at most 16 runs per Investigation; at most 512 target-scoped evidence rows
  and 8 MiB plus 64 report degradations and 512 KiB per report; at most 4,096
  budget events and 4 MiB per run; closed per-Investigation aggregates of
  64 MiB evidence, 4 MiB degradations and 32 MiB budget events;
- foreign-key ownership and no orphan report/evidence rows;
- only whole-Investigation deletion cascades; direct child deletion is
  rejected and cannot erase terminal/continuation lineage;
- insert-only report identity;
- atomic terminal session + report transition;
- paging and bounded read APIs;
- per-record corrupt isolation;
- exact local-record deletion without touching disk targets, Trash, Codex
  auth or Local Knowledge;
- immutable retention expiry
  `min(source expiry, session creation + 604_800_000 ms)`, shared by the whole
  continuation lineage and independent from 90-day Cleanup Manifests;
- linked Cleanup Manifest survival after Investigation evidence expiry;
- migration rollback and future-schema refusal;
- no raw Codex JSONL in SQLite.

Raw runtime workspace events remain ephemeral: delete on every normal terminal
path; on crash, recover/drain and remove residues within the existing maximum
24-hour contract.

Every maximum-size Store insertion/rejoin/terminal/recovery/continuation
transaction uses a two-second busy ceiling, injected cancellation, SQLite
progress handling, a 90-monotonic-second operation deadline, guaranteed
rollback and a five-second cleanup proof. Unconfirmed rollback quarantines the
connection and fails new mutations closed; no automatic retry or snapshot
splitting is allowed.

The SQLite connection remains private to the Evidence Store actor. A
deny-by-default `sqlite3_set_authorizer` permits Investigation writes only
while the owner prepares fixed SQL for one closed typed migration/operation;
no raw handle, generic SQL API, statement factory or mutable authorization
mode escapes. Row-local DDL checks do not claim to prove decoded Plan
membership, aggregate-counter equality or legal lifecycle transitions: the
typed operation verifies those cross-row facts before commit, and reopen
classifies external file mutation as corrupt.

The 90-second operation deadline is admitted only after a Release-build,
maximum-size end-to-end Store benchmark covers initial insertion, unchanged
rejoin, maximum terminal commit, crash recovery and 512-target continuation.
Three serial samples of each operation must all complete in at most 75
monotonic seconds, including source/decode/hash/SQLite/verification/commit
work and preserving Task 36's memory bound. A miss yields
`capacityBlocked`; it does not authorize a larger deadline, truncation, retry
or split snapshot.

## 7. Task Sequence

### Task 36 — Investigation Domain, Planner, Budget and Stop Contracts

Deliver:

- upstream study and accepted ADR for scientific planning/budget semantics;
- checked-in normative
  `docs/specs/investigation-canonical-v1.md`, including the complete
  grammar/tag/type/enum/collection tables, source manifest and bounds, exact
  rejoin barriers, clock and resource lifecycles, receipt-versioned runtime
  normalization, URL grammar, capability tokens and six complete
  encoded-hex/SHA-256 vectors;
- v2 Investigation IDs and domain contracts in `StornautCore`;
- deterministic Candidate Planner;
- preset-to-limit mapping;
- pure hard-reservation/observed-usage ledger and stop evaluator;
- bounded priority/target-selection benchmark;
- no Store migration, Codex launch, App UI or writes.

Gate:

- tests-first contract, adversarial and property-style fixtures;
- exact 10/30/60-minute and non-wall-clock preset limits;
- hard-versus-observed provenance, unavailable usage and observed-overrun
  semantics;
- stable priority/tie ordering;
- all six required stop reasons;
- zero execution/authorization surface;
- focused Core tests, serial SwiftPM, docs links, diff hygiene;
- independent review and authoritative `scripts/verify --full`;
- independent commit/push.

### Task 37 — Investigation Persistence and Retention

Deliver:

- Evidence Store v4 migration from v0/v1/v2/v3;
- session/target/report/evidence/budget persistence;
- persisted source fingerprint plus the complete bounded source-row manifest,
  stored as normalized bounded rows plus normalized relevance-token rows, with
  recomputation at all eight normative rejoin barriers;
- pinned-snapshot streaming insertion/rejoin with no caller-owned expected
  manifest/fingerprint/freshness token and no full payload/manifest buffer;
- private deny-by-default SQLite authorizer boundary with fixed typed
  operations only; no raw connection/generic SQL escape;
- immutable partial/final report transactions;
- seven-day retention, paging, exact deletion and corrupt isolation;
- strict origin-only web provenance sanitizer:
  `https://<lowercase-ASCII-public-DNS-host>/`; no IP literal, userinfo,
  non-default port, path, query or fragment; persist typed redaction/rejection
  reason rather than removed raw bytes;
- Deep Dive History data model only, no product UI.

Gate:

- migration rollback/future-version/role/integrity tests;
- no raw prompt/JSONL/secret/path-content payloads;
- signed URL, embedded-credential, query/fragment, local/private destination,
  percent-encoded Home path and secret-like path fixtures;
- source-fingerprint drift at every rejoin boundary fails stale/corrupt;
- executable DDL rejects malformed typed Scan/Scope IDs;
- low-level bypass tests reject Plan-membership, aggregate-counter and
  lifecycle forgery through the production connection;
- all fifteen maximum-size Store benchmark samples complete within 75 seconds
  and retain at least 15 seconds measured margin below the 90-second deadline;
- retained Manifest behavior unchanged;
- focused Store tests, serial SwiftPM, independent review,
  authoritative `scripts/verify --full`;
- independent commit/push.

### Task 38 — Closed Investigation Coordinator with Fake Runtime

Deliver:

- `StornautInvestigation` module and public closed facade;
- context compressor and prompt resource contract;
- retained-ID protocol binding;
- injected fake Codex/runtime and Probe Broker;
- staged state machine, budget accounting, pause/continue/stop/cancel;
- identity-bound App Server direct-tool and token-usage observation, or typed
  `usageUnavailable` degradation;
- complete same-investigation root/descendant accounting with replay
  deduplication;
- exact root/receipt-selected collaboration lineage, receipt-selected closed
  tool-item types, cumulative per-thread token snapshots and invalid-event
  fail-closed behavior;
- no later turn after an observed ceiling and the exact 15/45/135/140-second
  terminal settlement boundaries with `turn/completed`-before-drain semantics;
- strict Envelope v2 normalization into Core reports;
- lifecycle drain and ephemeral artifact cleanup contracts;
- no real model and no App availability change.

Gate:

- fake success, malformed schema, prompt injection, timeout, cancellation,
  capability degradation, hard budget exhaustion, usage unavailable,
  observed usage overrun, no-evidence-gain and crash recovery tests;
- structural no-Executor/no-Trash/no-authorization verifier;
- raw artifact deletion tests;
- focused Investigation/Codex/Lifecycle tests, serial SwiftPM,
  independent review, authoritative `scripts/verify --full`;
- independent commit/push.

### Task 39 — Signed-App Production Runtime Admission

Checkpoint status:

- 39A strict signed-runtime contract, server-owned turn identity binding and
  package-closed diagnostic facade are complete; focused tests, 829-test
  serialized SwiftPM, independent post-fix review and the 23/23-stage
  authoritative full verifier passed. See
  [Task 39A Review](../../reports/phase-d-task-39a-review.md).
- 39B1a exact Store binding and directly async lifecycle prerequisites are
  complete; its 83-test Investigation suite, 833-test serialized SwiftPM,
  independent post-fix review and 23/23-stage authoritative full verifier
  passed. See
  [Task 39B1a Review](../../reports/phase-d-task-39b1a-review.md).
- 39B1b-i package-closed interactive transport and non-product composition are
  complete; its 92-test Investigation suite, 240-test Codex suite, 846-test
  serialized SwiftPM regression, independent post-fix review and 23/23-stage
  authoritative full verifier passed. See
  [Task 39B1b-i Review](../../reports/phase-d-task-39b1b-i-review.md).
- 39B1b-ii strict DEBUG App leaf implementation, 11-test dedicated App target,
  pure-product Debug/Release boundary, 846-test serialized SwiftPM regression
  and independent post-fix review passed. Its 23-stage authoritative full
  verifier exited `0` in 972 seconds. See
  [Task 39B1b-ii Review](../../reports/phase-d-task-39b1b-ii-review.md).
- 39B2a strict supervised interactive transport and 39B2b-i helper-owned
  contained worker are complete and independently verified.
- 39B2b-ii prerequisite authority extraction is complete. The resumed signed
  diagnostic composition binds the opaque Task 38 facade, delayed auth
  projection, helper-reported random workspace, exact diagnostic Store and
  dedicated App/helper topology. Focused Codex/Investigation/App tests, the
  strict final-Mach-O gate and independent post-fix review passed. Its single
  authoritative full verifier passed 23/23 stages in 981 wall-clock seconds,
  including the 898-test serialized regression, with no restart or stage
  retry. 39B2b-ii is complete. See
  [Task 39B2b-ii Review](../../reports/phase-d-task-39b2b-ii-review.md).
- The narrow 39B2c attempt-binding prerequisite is complete and independently
  reviewed: raw R5 capability evidence is bound to the exact Task 39
  nonce/source/build/runtime receipt; the final verifier reconstructs the
  receipt from authoritative raw evidence; 903 serialized tests passed. See
  the
  [Attempt-Binding Prerequisite Review](../../reports/phase-d-task-39b2c-attempt-binding-prerequisite-review.md).
- 39B2c L3a/L3b are complete. The mandatory L3c scope/trust preflight split
  the remaining work into L3c1 helper-owned opaque retirement escrow, L3c2
  deterministic machine driver, L3c3 current-source real-success three-plane
  composition and L3c4 sealed final admission. L3c1a typed owner retirement,
  L3c1b-i configuration-bound helper escrow and L3c1b-ii synthetic Machine
  claim/collector join are complete; L3c1 is closed. L3c2 is split into
  L3c2a-i strict claim transport, L3c2a-ii non-product root host/topology and
  L3c2b fixed eight-scenario driving. L3c2a-i is complete after its exact
  14-path implementation, layered gates, 1041-test clean staged-only serial and
  independent post-fix review. L3c2a-ii is also complete after its seven-path
  root host/topology composition, resolved authority gates, targeted builds,
  1046-test clean staged-only serial and independent post-fix review. L3c2b is
  also complete after its deterministic eight-scenario driver, structural and
  targeted gates, 1,055-test clean staged-only serial and final independent
  review. L3c3a strict driver binding is also complete after its exact 14-path
  schema/identity implementation, structural and App gates, 1,057-test clean
  staged-only serial and independent post-fix review. L3c3b native diagnostic-
  only driver packaging/topology admission was split before coding into
  L3c3b-i native packaging and L3c3b-ii installer/L2 admission. A final-Mach-O
  spike then exposed forbidden Cleanup/Policy surfaces through the full Machine
  graph. L3c3b-0 authority closure is complete after its final-Mach-O gates,
  1,059-test clean staged-only serial and independent post-fix review. L3c3b-i
  native packaging is also complete after its diagnostic-only Xcode graph,
  final-artifact identity/authority gates, 1,060-test clean staged-only serial
  and independent post-fix/cross-group review. L3c3b-ii installer/L2 is complete.
  L3c3c-i transport/root-launch audit is complete and rejects the external
  branch; i-b2b-0b/i-b2b-1 were superseded before execution. ADR 0018 remains
  Proposed. L3c3c-ii-a is complete; ii-b is frozen as ii-b0a/ii-b0b and
  ii-b1–ii-b5 with ii-c0 before the privileged gate. ii-b0a and ii-b0b are
  complete after their single staged-only serials and independent reviews. ii-b0c
  bootstrap is complete after the ii-b1 first-frame origin audit. ii-b1 is also
  complete after its corrected Debug-only diagnostic/dependency-free Release-shell
  topology, 9/9 leaf, 13/13 App and 277 affected tests, exact structural/artifact
  gates, one 1,138-test staged-only serial and independent post-fix review. The
  ii-b2 ASID prerequisite is also complete after its semantic-only shared
  contract correction, structural mutation controls, separate 1,142-test
  implementation serial and independent 1,143-test decoder-negative supplement.
  ii-b2a typed escrow/deadline state is complete after its focused/affected/
  coverage/structural gates, sole 1,162-test combined serial and final review.
  ii-b2b-i sealed/non-connected server integration is complete after 59 focused
  tests, sole 1,194-test staged-only serial, source/package/mutation gates and
  independent post-fix reviews. ii-b2b-ii legacy-client quarantine / Machine
  production block is also complete after 34 focused, 175 Lifecycle affected,
  308 Investigation affected, complete App/main-Mach-O, 1,196-test staged-only
  serial and grouped/cross-group review gates. ii-b2b-iii is split into iii-a/
  iii-b; iii-a strict handle-v3/single-quantized transfer is complete after 91
  focused, 181 Lifecycle, 309 Investigation, one 1,208-test staged-only serial
  and post-fix/cross-group review. iii-b-i semantic/live integration closure is
  complete after 83 focused, 499 affected, one 1,212-test staged-only serial,
  helper/final-Mach-O gates and fresh cross-group review. iii-b-ii executable
  physical-adapter closure is also complete after 51 focused, 504 affected, one
  1,223-test staged-only serial, physical/five-symbol final-Mach-O gates and
  post-fix review. iii-b/ii-b2b are closed; ii-b3a fixed handoff adapter is
  complete after 35 focused, 521 affected, one 1,234-test staged-only serial,
  exact contract/structural/artifact gates and final review; ii-b3b and its
  test-only fixture prerequisite, ii-b3c and ii-b4 are complete/non-admitting;
  ii-b5 is split into b5a0/b5a/b5b-i/b5b-ii/b5b-iii; b5a0/b5a, all b5b-i checkpoints through aggregate i-c2, ii-b5b-ii-a/ii-b/ii-c/ii-d and ii-c0a are complete/non-admitting. The corrected remaining order is `ii-b5b-iii -> ii-c0b -> ii-c -> L3c3d -> L3c4`; ii-b5b-iii is current. ii-c0a closed at tree `6064cccce400cd07f7ebdc4653a2496c67c83434` with exact 8 paths / 1,863 changed lines, 90 focused tests, 536 affected tests, a clean 1,418-test / 73-suite staged-only serial, all three boundary gates and no unresolved P0-P2 review findings; it ran no root/model/network/full gate.
  See the
  [ii-b2 ASID prerequisite review](../../reports/phase-d-task-39b2c-l3c3c-ii-b2-asid-prerequisite-review.md),
  the
  [ii-b2a typed escrow/deadline review](../../reports/phase-d-task-39b2c-l3c3c-ii-b2a-review.md),
  the
  [ii-b2b-i machine-claim server review](../../reports/phase-d-task-39b2c-l3c3c-ii-b2b-i-review.md),
  the
  [ii-b2b-ii legacy-client quarantine review](../../reports/phase-d-task-39b2c-l3c3c-ii-b2b-ii-review.md),
  the
  [ii-b2b-iii split preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b2b-iii-split-preflight.md),
  the
  [iii-a handle v3 review](../../reports/phase-d-task-39b2c-l3c3c-ii-b2b-iii-a-review.md),
  the
  [iii-b-i live integration review](../../reports/phase-d-task-39b2c-l3c3c-ii-b2b-iii-b-i-review.md),
  the
  [iii-b-ii physical adapter review](../../reports/phase-d-task-39b2c-l3c3c-ii-b2b-iii-b-ii-review.md),
  the
  [ii-b3a review](../../reports/phase-d-task-39b2c-l3c3c-ii-b3a-review.md),
  the
  [ii-b3b fixture review](../../reports/phase-d-task-39b2c-l3c3c-ii-b3b-fixture-prerequisite-review.md),
  the
  [ii-b3b seam review](../../reports/phase-d-task-39b2c-l3c3c-ii-b3b-review.md),
  the
  [ii-b3c review](../../reports/phase-d-task-39b2c-l3c3c-ii-b3c-review.md),
  the
  [ii-b4 preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b4-preflight.md),
  the
  [ii-b4 review](../../reports/phase-d-task-39b2c-l3c3c-ii-b4-review.md),
  the
  [i-b2b-b review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-i-b2b-b-review.md),
  the
  [i-b3 review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-i-b3-review.md),
  the
  [i-c1 review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-i-c1-review.md),
  the
  [i-c2a review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-i-c2a-review.md),
  the
  [i-c2b preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-i-c2b-preflight.md),
  the [i-c2b review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-i-c2b-review.md),
  the [ii-b5b-ii preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-ii-preflight.md),
  the [ii-b5b-ii-b review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-ii-b-review.md),
  the [ii-b5b-ii-c review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-ii-c-review.md),
  the [ii-c0a preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-c0a-projection-capsule-preflight.md),
  the [ii-c0a review](../../reports/phase-d-task-39b2c-l3c3c-ii-c0a-review.md),
  the
  [L3c1b-i Review](../../reports/phase-d-task-39b2c-l3c1b-i-configuration-bound-helper-escrow-review.md)
  and
  [L3c1b-ii Review](../../reports/phase-d-task-39b2c-l3c1b-ii-synthetic-machine-claim-review.md).
  L3c2a-i evidence is in the
  [Machine-Claim Transport Review](../../reports/phase-d-task-39b2c-l3c2a-i-machine-claim-transport-review.md).
  L3c2a-ii evidence is in the
  [Machine Driver Host Review](../../reports/phase-d-task-39b2c-l3c2a-ii-machine-driver-host-review.md).
  The L3c2b preflight's real-plan matrix contradiction is closed by the
  [Plan Freshness Prerequisite Review](../../reports/phase-d-task-39b2c-l3c2b-plan-freshness-prerequisite-review.md);
  L3c2b evidence is in the
  [Eight-Scenario Driver Review](../../reports/phase-d-task-39b2c-l3c2b-eight-scenario-driver-review.md);
  L3c3a evidence is in the
  [Driver-Bound Attempt Review](../../reports/phase-d-task-39b2c-l3c3a-driver-binding-review.md).
  The split is recorded in the
  [L3c3b Scope/Trust Preflight](../../reports/phase-d-task-39b2c-l3c3b-scope-trust-preflight.md).
  The blocker and revised graph are recorded in the
  [Driver Runtime Authority Preflight](../../reports/phase-d-task-39b2c-l3c3b-driver-runtime-authority-preflight.md).
  Completion evidence is in the
  [Driver Runtime Authority Review](../../reports/phase-d-task-39b2c-l3c3b-driver-runtime-authority-review.md).
  Native packaging evidence is in the
  [Native Driver Packaging Review](../../reports/phase-d-task-39b2c-l3c3b-i-native-driver-packaging-review.md).
  Installer/L2 admission evidence is in the
  [Installer/L2 Admission Review](../../reports/phase-d-task-39b2c-l3c3b-ii-installer-l2-admission-review.md).
  L3c3c's measured candidate, completed reproducibility contract, remaining
  privileged gate and product-code block
  are recorded in the
  [Parent-Owned Handoff Study](../../upstream-studies/phase-d-task-39b2c-l3c3c-parent-owned-handoff.md),
  [Proposed ADR 0018](../../adr/0018-parent-owned-investigation-handoff.md),
  [L3c3c-i Final Review](../../reports/phase-d-task-39b2c-l3c3c-i-handoff-launcher-spike-review.md),
  [L3c3c-i-b2a Reproducibility Review](../../reports/phase-d-task-39b2c-l3c3c-i-b2a-reproducibility-contract-review.md) and
  [L3c3c-i-b2b-0a Root Provenance Review](../../reports/phase-d-task-39b2c-l3c3c-i-b2b-0a-root-provenance-review.md).
  The revised implementation split is frozen by the
  [Installed-Driver Preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-installed-driver-path-cost-preflight.md).
  The nested handoff budgets and protocol corrections are frozen by the
  [ii-b Split Preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b-split-preflight.md)
  and [ii-b0 Wire Preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b0-wire-contract-preflight.md).
  ii-b0a/ii-b0b completion evidence is in the
  [Frame/Capsule Review](../../reports/phase-d-task-39b2c-l3c3c-ii-b0a-review.md) and
  [Claim/Release Review](../../reports/phase-d-task-39b2c-l3c3c-ii-b0b-review.md).
  The inserted bootstrap contract is in the
  [ii-b0c Preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b0c-epoch-bootstrap-preflight.md).
  Completion evidence is in the
  [ii-b0c Review](../../reports/phase-d-task-39b2c-l3c3c-ii-b0c-review.md).
  The authority-free leaf contract and completion evidence are in the
  [ii-b1 Preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b1-app-leaf-preflight.md)
  and
  [ii-b1 Review](../../reports/phase-d-task-39b2c-l3c3c-ii-b1-review.md).
  ii-a completion evidence is in the
  [Installed-Driver Observation Review](../../reports/phase-d-task-39b2c-l3c3c-ii-a-installed-driver-observation-review.md).
  Only L3c4 owns
  real-model signed-App machine readiness, the complete failure matrix, exact
  zero-residue proof and the remaining authoritative full verifier. Task 39 and
  production Deep Dive are not admitted by any earlier checkpoint.

Deliver:

- current-source signed Debug App composition of the closed production
  Investigation facade;
- current R5/R6 helper/runtime topology and exact receipt admission;
- bounded disposable read-only investigation with real authenticated Codex,
  preferring `gpt-5.6-luna`;
- current capability/integrity receipt binding;
- one valid Envelope v2 normalized into a non-authoritative report;
- cancellation, timeout, invalid-envelope and zero-residue diagnostics.

Gate:

- capability observation: all nine required read-only Agent capabilities
  (`directRead`, `shell`, `unifiedExec`, `liveSearch`,
  `publicCommandNetwork`, `browserOrDirectFetch`, `imageInspection`, `skills`,
  `subagents`) actually exercised, with public internet success recorded
  separately;
- enforced-control verification: current signed App/helper receipt, outer
  write denial, network/Unix policy, lifecycle ownership and structural
  no-Executor boundary independently admitted;
- adversarial denial: attempted user-data write, localhost/private/link-local,
  Unix socket and cleanup-authority reachability are denied and attributed to
  the expected enforced control;
- lifecycle and managed proxy residue `0`;
- model/capability success or absence of an observed violation is never
  reported as containment proof;
- signed-App report fingerprint and independent review;
- authoritative `scripts/verify --full`;
- independent commit/push.

This Task may call the user's authenticated Codex repeatedly, but every
diagnostic is bounded and read-only. It must not modify
`~/.codex/config.toml`.

### Task 40 — Evidence Report and Conservative Review Projection

Deliver:

- Core normalization from retained advisory IDs to persisted evidence/report;
- source-aware Evidence display summaries;
- deterministic reconciliation against current Store records;
- candidate rows for Review with Agent-only rule miss capped at
  `Review Recommended`, unselected and non-executable;
- existing `CleanupPlanBuilder` reuse only where current deterministic
  execution profiles independently admit an item;
- continuation plan generation from unresolved targets.

Gate:

- forged path/action/disposition/Policy fields impossible or rejected;
- expired/stale/corrupt source records fail closed;
- model confidence cannot override deterministic disposition;
- no second CleanupPlan/Policy/Executor implementation;
- focused Core/App model tests, independent review,
  authoritative `scripts/verify --full`;
- independent commit/push.

### Task 41 — First-Use Disclosure and Runtime Admission State

Deliver:

- aggregate bilingual first-use disclosure covering direct read, model
  context, public internet and no-write/no-cleanup boundary;
- explicit acceptance before the first production investigation;
- bounded local preference for disclosure version/acceptance only;
- runtime receipt freshness + Codex availability + disclosure acceptance as
  separate typed states;
- Settings `Codex & Deep Dive` status, budget details and safe repair actions;
- no provider selector, arbitrary CLI flags, per-tool toggles or safety bypass.

Gate:

- acceptance cannot substitute for runtime containment;
- runtime success cannot substitute for disclosure;
- declined/obsolete disclosure preserves Quick Scan and keeps Deep Dive
  unavailable;
- Light/Dark actual-window Peekaboo evidence and focused XCUITest;
- independent review and authoritative `scripts/verify --full`;
- independent commit/push.

### Task 42 — App Investigation Workflow and Recovery State

Deliver:

- App-owned Investigation dependency and actor state;
- start from latest valid Quick Scan; if absent, typed baseline Quick Scan
  transition before investigation;
- single-flight exclusion with Scan, cleanup execution and mutating History/
  Settings operations;
- staged progress, current target, budget, pause/resume, stop/cancel and
  continuation state;
- partial/blocked/failed reducers preserving valid evidence;
- terminal UI transitions depend on Task 38's matching terminal-event, exact
  15/45/135/140-second settlement envelope, full descendant/proxy drain and
  atomic persistence/rollback-cleanup contract;
- production Deep Dive still feature-gated from the normal UI.

Gate:

- no stale snapshot start;
- safety blocked never enters started/progress metrics;
- cancellation, timeout, pause and crash recovery cannot expose terminal UI or
  promote evidence before matching completion, full drain and terminal commit;
- continuation starts only from the resulting verified partial record and a
  new run identity;
- partial report remains available;
- App tests, focused integration tests, independent review,
  authoritative `scripts/verify --full`;
- independent commit/push.

### Task 43 — Investigations UI and Navigation

Deliver:

- real Investigations workspace replacing the placeholder;
- 10/30/60-minute start picker;
- approved four-stage Guided Journey;
- functional coverage/Unknown metrics and current-target card;
- Investigation Details Inspector with source/probe/budget/counter-evidence/
  unresolved/degradation summaries;
- `Investigate with Codex` only on eligible Unknown/rule-miss rows;
- Overview secondary Deep Dive entry;
- no chat, console, hidden reasoning or raw JSONL;
- Light/Dark, English/zh-Hans, keyboard and accessibility contracts.

Gate:

- actual `.app` build/run;
- Peekaboo screenshot and AX inspection of empty, disclosure, running, partial,
  safety-blocked and final states;
- focused XCUITest for navigation, Inspector, cancellation and continuation;
- independent review and authoritative `scripts/verify --full`;
- independent commit/push.

### Task 44 — Production Vertical Slice and Phase D Final Gate

Deliver:

- remove `.implementationUnavailable` only behind the complete admitted product
  composition;
- one signed-App real Deep Dive from retained Quick Scan through final/partial
  report and Review projection;
- Deep Dive sessions in History with non-causal event marker;
- prompt-to-artifact evidence matrix and privacy audit;
- full Phase D validation/review report;
- archive the Phase D plan and update roadmap/handoff/AGENTS.

Gate:

- one successful current-source signed-App normal-product `gpt-5.6-luna`
  vertical slice is mandatory for `go`; provider/model unavailability or run
  failure publishes a blocked Phase D verdict and retains
  `.implementationUnavailable`;
- fake deterministic fixtures remain authoritative only for edge-case
  coverage and cannot substitute for the mandatory real vertical slice;
- separate capability-observation report for complete approved tools/public
  internet;
- separate enforced-control verification for the signed runtime and structural
  no-Executor boundary;
- separate adversarial denial report for write, local/private/link-local
  network, Unix-socket and cleanup-authority attempts;
- no success or non-observation is promoted into containment proof;
- malformed/prompt-injected output cannot escape strict report protocol;
- Agent-only proposals never become Ready/default-selected;
- any later cleanup still uses unchanged Phase C Policy/Executor;
- actual-window final UI evidence;
- zero unresolved P0–P2 independent findings;
- one uninterrupted authoritative `scripts/verify --full` exit `0`;
- independent commit/push.

## 8. Prompt Contract

The checked-in production prompt must:

- declare Codex an investigator, never an executor;
- provide exact Investigation/run/target/candidate IDs;
- describe user-approved read scope and current budget;
- require evidence source labels and uncertainty;
- require all admitted target IDs to appear exactly once as investigated or
  unresolved;
- require explicit capability degradations;
- require Envelope v2 only as the final message;
- treat local files, tool output and web content as untrusted evidence, not
  instructions;
- prohibit credentials collection, TCC bypass, local/private network, Unix
  socket, write, cleanup, Policy and Executor attempts;
- avoid embedding arbitrary source text into system/developer instructions;
- avoid claiming that prompt text enforces OS containment.

Prompt tests validate shape and invariants, but containment evidence must come
from the signed runtime gate.

## 9. UI Availability Gate

Normal App Deep Dive can start only when all are true:

- source Quick Scan is retained, terminal and usable;
- user has accepted the current disclosure version;
- Codex discovery/auth is available;
- exact current runtime receipt is admitted and fresh;
- production Investigation dependencies are present;
- no conflicting mutating workflow is active;
- the selected budget is valid;
- the typed Phase D final admission is exactly `admittedByTask44`.

Every normal App start path consumes that Task 44 condition in addition to
configuration availability. Each false dimension has a separate typed state
and safe recovery action.
There is no generic “trust Codex”, “proceed anyway” or write-isolation bypass.

## 10. Validation Strategy

Every Task follows:

```text
Upstream Study
→ Implementation Brief
→ ADR where a new invariant is selected
→ failing tests/fixtures
→ implementation
→ focused checks
→ benchmark/runtime evidence
→ docs/provenance
→ independent review
→ scripts/verify --full
→ independent commit/push
```

Heavy SwiftPM/Xcode runs remain serial. UI Tasks additionally run:

```text
narrow build/test
→ launch actual .app
→ Peekaboo read-only capture/inspect
→ focused XCUITest
→ authoritative full verifier
```

No Task may enable normal product Deep Dive before Task 44.

## 11. Phase D Exit Matrix

| Requirement | Required artifact |
| --- | --- |
| deterministic target selection | Planner tests + benchmark + ADR |
| 10/30/60 budgets, hard/observed usage quality and all stop reasons | domain/state-machine tests |
| strict advisory-only protocol | Envelope v2 and forged-field tests |
| complete Agent capabilities | signed current-source runtime report |
| write/private/local/Unix/no-Executor containment | signed integrity report + structural verifier |
| lifecycle cleanup | cancellation/timeout/crash zero-residue reports |
| partial report truth | Store + reducer + UI tests |
| seven-day investigation privacy | Store v4 retention/deletion audit |
| first-use data disclosure | persisted versioned acceptance + actual-window evidence |
| Agent-only max Review Recommended | projection/selection/Policy tests |
| one cleanup authority path | Phase C reuse audit + no-Executor verifier |
| product usability | actual signed-App Deep Dive + Peekaboo/XCUITest |
| repository admission | independent review + `scripts/verify --full` exit `0` |

## 12. Explicitly Deferred

- all external Adapters and their licenses/golden fixtures;
- real Registered Actions;
- permanent actions;
- public distribution, Developer ID and notarization;
- Full Disk Access product onboarding beyond existing status/repair surfaces;
- background/scheduled investigation;
- multi-user or remote runtime;
- arbitrary provider/model selection;
- telemetry or remote policy/rule services;
- model-generated Local Knowledge without explicit structured user
  confirmation.
