# ADR 0017: Investigation Planning, Budget and Stop Semantics

> **Status:** Accepted for Task 36 implementation; production Deep Dive
> admission remains pending through Task 44.
>
> **Date:** 2026-08-15
>
> **Decision owners:** Stornaut maintainers
>
> **Related study:**
> [Epic 6 Investigation Planning](../upstream-studies/epic-6-investigation-planning.md)
>
> **Normative low-level contract:**
> [Investigation Canonical v1](../specs/investigation-canonical-v1.md). Its complete codec/schema,
> source-manifest bounds, priority arithmetic, clock/resource lifecycle,
> receipt-versioned runtime normalization, persisted URL grammar and
> capability matrix override every summary in this ADR.
>
> **Governing boundaries:**
> ADR 0004, ADR 0013, ADR 0016 and the Phase C Policy/Executor chain.

## Context

The capability-first runtime foundation has passed R1–R6, but production Deep
Dive is not implemented. Phase D needs a scientific work queue and stopping
contract before integrating that runtime.

The current product already has:

- retained terminal Quick Scan sessions and one Primary Scan scope;
- Space Ledger reconciliation and classifications;
- a v1 placeholder `InvestigationTarget`;
- 10/30/60-minute Settings presets;
- a strict advisory Envelope v2;
- a Probe Broker with hard call/read/output reservations;
- an App Server runtime that currently discards token usage;
- one accepted Phase C Policy, authorization, Trash and Executor path.

The product specifications have one terminology drift. PRD §6.2 says Codex
generates `InvestigationPlan`, while the architecture assigns targets and
budgets to Swift. The accepted meaning is:

- Swift mints the admitted `InvestigationPlan`;
- Codex dynamically investigates within it and may propose advisory next
  hypotheses;
- model output cannot rewrite plan identity, targets, limits or authority.

The official Codex App Server makes three constraints important:

1. `turn/start` is a real admission boundary.
2. `turn/interrupt` is only a cancellation request; terminal truth arrives in
   matching `turn/completed`.
3. token usage is asynchronous event evidence and may be absent.

Direct Agent tools may also occur inside one already admitted turn. Their
canonical item events are observable, but the current product does not have a
universal pre-call hook and intentionally does not introduce per-command
approvals or allowlists.

Therefore Stornaut must distinguish resources that Swift can reserve before
work from usage it can only observe afterward.

## Decision

### 1. Swift owns the admitted plan

`InvestigationPlan` is an immutable, strict-decoding Core value bound to:

- one `InvestigationID`;
- one retained terminal `ScanSessionID`;
- one `ScanScopeID`;
- one immutable source fingerprint;
- one ordered target set and target-set fingerprint;
- one budget preset and its complete limits;
- one creation/expiry interval;
- coverage and remaining-Unknown thresholds;
- one Core-neutral required-capability set.

It contains no executable, shell argument, path mutation, cleanup action,
disposition, Policy decision, selection, confirmation, Trash reference or
authorization.

The plan grants no authority and cannot be expanded by Codex.

### 2. Candidate priority is deterministic integer data

Every measurable candidate receives a priority equivalent to:

```text
expected allocated MiB × uncertainty permille × relevance permille
-----------------------------------------------------------------
                   investigation-cost permille
```

Rules:

- expected bytes are rounded up to MiB for ranking only; the original exact
  measurement remains separate;
- uncertainty, relevance and cost are integers in `1...1_000`;
- multiplication uses checked UInt64 arithmetic; complete admitted bounds
  prove the maximum numerator
  `8_796_093_022_208_000_000 < UInt64.max`;
- division uses integer floor;
- no floating-point value participates in ordering or fingerprints;
- overflow, invalid factors and invalid source binding fail closed;
- unmeasurable size remains a separate tier and is never encoded as zero;
- ties sort by target kind, retained source IDs and ordered reason keys;
- the admitted set is capped at 512 targets;
- omitted count and measurable omitted bytes are reported conservatively.

There is no saturation path. Overflow or a factor outside the normative
bounds is invalid input. Silent wrapping is forbidden.

### 3. Candidate generation is a closed product policy

`CandidatePolicyV1` removes hidden prompt/caller heuristics:

- an unknown large consumer requires measured allocated bytes greater than or
  equal to `1_073_741_824`; there is no scope-relative v1 threshold;
- coverage is exactly `900` permille;
- remaining measurable Unknown stops only below `1_073_741_824` bytes;
- Plan expiry is the earlier of retained Scan-session expiry and injected
  creation time plus the selected preset wall clock;
- relevance starts at `700` and the only accepted relevance tokens,
  `relevance.large` and `relevance.developer`, may each add `100` under their
  exact typed applicability rules;
- unknown or duplicate relevance tokens fail closed;
- fixed `(uncertainty, cost)` values are `(750,250)` unknown large,
  `(1_000,800)` gap, `(1_000,350)` conflict, `(850,400)` unknown producer and
  `(700,300)` stale/insufficient.

One non-Protected classification/snapshot source produces at most one target,
with precedence: conflict, unknown large, unknown producer, then
stale/insufficient. It retains all applicable fixed reason keys and exact
missing-evidence keys. Ordinary Ready is excluded; only a contradictory Ready
safety shape — high/critical risk or confidence below high — becomes a
conflict candidate and gains no cleanup authority.

A non-root snapshot missing classification produces only the
missing-classification target when its allocated bytes are measured and meet
the inclusive large threshold. The eligible reconciled ledger produces at
most one gap target for measurable nonzero Unknown residual. Measured zero
creates no gap and unavailable bytes remain unavailable. Coverage-limited or
inconsistent ledgers fail source eligibility; they are not candidate branches
in v1.

Every target contains `1...16` canonical reasons. The complete canonical Plan
digest input is at most `2 MiB`; overflow rejects without truncating or
silently dropping data.

The pure Planner may return an empty Plan with typed `noEligibleTargets`.
Empty is not runtime admission: Task 37 rolls back and persists no
Investigation/run, and Task 38 starts no Codex. Every persisted run-owned Plan
therefore has `1...512` targets.

### 4. Target identity is source-derived, not random

The pure Planner accepts a caller-created `InvestigationID` and injected
`now`. It does not call `UUID()` or the system clock.

Every target has exactly one strict source binding:

- retained snapshot ID;
- retained classification ID plus its exact snapshot ID;
- one closed Space Ledger measure key for the retained session/scope.

A ledger-only source invents no path.

Target IDs use:

```text
target-<full lowercase SHA-256>
```

over a versioned, domain-separated, length-prefixed canonical encoding of Scan
session, scope, target kind and source binding. Reasons, priority and current
evidence do not change source identity. Duplicate derived IDs fail closed.

Source, target-set and plan fingerprints use different domain tags and the
same unambiguous encoding discipline. Plan fingerprints include the supplied
Investigation ID, exact source fingerprint, full limits, thresholds,
timestamps and ordered target payloads.

The normative codec is `StornautInvestigationCanonicalV1`:

- magic ASCII `STORNAUT-INV-CANON-1\0`;
- one encoded domain string followed by one root record;
- nil `00`, false `01`, true `02`;
- UInt64 `10` + 8-byte big-endian value;
- Int64 `11` + 8-byte big-endian two's-complement value;
- text `20` + UInt64 UTF-8 byte length + exact bytes;
- bytes `21` + UInt64 length + bytes;
- array `30` + UInt64 count + each UInt64-length-prefixed encoded value;
- record `40` + UInt64 field count + each strictly increasing unique UInt16
  field tag and UInt64-length-prefixed encoded value.

Every optional field is present and encodes as nil when absent. Enums use
exact lowercase versioned ASCII tokens. Dates use Int64 microseconds since
Unix epoch, truncated toward zero. Text receives no Unicode, case, path,
percent or locale normalization. Trailing bytes, invalid UTF-8,
duplicate/out-of-order tags, missing optionals and non-domain values are
rejected.

The fixed digest domains are:

```text
stornaut.investigation.target.v2
stornaut.investigation.source.v1
stornaut.investigation.target-set.v1
stornaut.investigation.plan.v1
```

Task 36 checks complete encoded-hex/SHA-256 primitive and product golden
vectors. `JSONEncoder`, reflection, native layout, dictionary order and
`Hashable.hashValue` are forbidden for identity.

`sourceFingerprint` is computed by the Planner, not accepted as caller text.
Its strict source projection is the normative complete typed-row manifest:
one terminal Scan-session row, one complete same-session Space Ledger row and
exhaustive selected-scope snapshot/classification/evidence rows. Each row
binds the exact stored payload digest plus all non-payload identity columns,
with Store identity checks, strict typed decode and byte-identical
`DomainJSON` re-encode. The normative row/payload/relevance bounds reject all
top-N truncation. Exact source payload bytes aggregate to at most 256 MiB;
canonical SourceProjection identity input is separately bounded at 512 MiB.
The canonical Plan identity input is bounded at 2 MiB and its strict
persistence `DomainJSON` at 4 MiB; neither bound substitutes for the other.

Task 37 persists the source fingerprint and complete source-row manifest as
normalized bounded source-row and relevance-token rows, not one aggregate
session JSON payload. It recomputes exact membership and bytes at the
normative eight rejoin barriers. A mismatch is stale/corrupt, never accepted
by IDs alone.

Construction/rejoin uses repeatable two-pass streaming over one Store-owned
pinned SQLite snapshot. Only one exact source payload is decoded/hashed at a
time and released before advancing. Pass one submits normalized row metadata
to a non-escaping manifest sink; pass two feeds a write-only canonical hash
sink that returns digest/count metadata and never accumulated `Data`. No full
payload/manifest/canonical buffer is permitted. Rejoin callers provide only
typed Investigation ID plus a closed barrier. The Store owns expected
normalized rows/fingerprint and never returns a reusable freshness token.

Measured bytes use `ByteCountV1` in `0...Int64.max`; binary and strict
duplicate-aware `DomainJSON` reject larger UInt64 values, duplicate/omitted
keys and floating-point integer conversion. The compact policy index retains
only a derived `isRoot` bit, not path text, for the missing-classification
rule.

Task 37 owns immutable source/session truth and at most 16 immutable run-owned
Plans. Initial creation and continuation accept only typed IDs, preset and
injected time; Store creates each Plan/ordered target membership after fresh
rejoin. Runtime receives IDs only and loads/rechecks the Plan inside Store
immediately before `thread/start`.

Durable evidence/degradation/budget rows have closed per-owner and
per-Investigation aggregate quotas. Only whole-Investigation deletion
cascades; direct child deletion cannot erase terminal or continuation truth.
Maximum-size transactions use a two-second busy ceiling, 90-monotonic-second
deadline, cancellation/progress handling, proved rollback and fail-closed
connection quarantine. One immutable retention anchor,
`min(source expiry, session creation + 604_800_000 ms)`, covers the complete
continuation lineage.

Legacy v1 targets are decoded only by a separately named fixture/migration
adapter. They are rejected by planning, Plan construction, Store v4,
runtime admission and continuation unless a future explicit migration can
reconstruct and verify every v2 source binding. Task 36 performs no lossy
automatic upgrade.

### 5. Budget dimensions preserve enforcement quality

`InvestigationBudgetLimits` has two explicit classes.

#### Hard admission limits

Swift can refuse work before the bounded operation begins:

| Dimension | Focused | Balanced | Thorough |
| --- | ---: | ---: | ---: |
| Wall clock | 600 s | 1,800 s | 3,600 s |
| Coordinator/model turns | 4 | 12 | 24 |
| Probe Broker calls | 16 | 48 | 96 |
| Probe read reservation | 8 MiB | 32 MiB | 64 MiB |
| Probe output reservation | 2 MiB | 8 MiB | 16 MiB |
| Cumulative Swift-admitted model-context bytes | 1 MiB | 4 MiB | 8 MiB |
| Concurrent Probe operations | 2 | 4 | 8 |
| Consecutive verified no-gain steps | 2 | 3 | 4 |

Every single Swift-built model input is additionally capped at 256 KiB. Lower
existing protocol limits continue to win.

All elapsed-time decisions use an injected `ContinuousClock`. The serial
coordinator samples immutable `runStart` atomically with its transition into
running and samples immutable T0 exactly once at the first accepted fact whose
normative precedence closes admission. Wall-calendar timestamps are metadata
only. The wall-clock limit closes admission of new scientific work. A separate
**140-monotonic-second terminal settlement envelope** begins at T0:

1. atomically close all turn/Probe/context admission and record the cause;
2. send at most one interrupt for every active `(threadID, turnID)`;
3. consume matching terminal/usage/item events for at most 15 seconds;
4. once all admitted turns are terminal, or at 15 seconds, invoke the
   idempotent audit-session drain;
5. by 45 seconds, prove the audit session and proxy owner empty, retire
   ephemeral artifacts and begin the Store-owned terminal transaction;
6. by 135 seconds, atomically commit terminal truth or interrupt/roll back the
   Store transaction;
7. by 140 seconds, complete the separate rollback/connection cleanup or
   quarantine the connection as `rollbackUnconfirmed`.

Missing terminal events followed by a proved forced drain yield
`blocked(runtimeTerminalUnobserved)`. Unproved process/proxy drain yields
`blocked(lifecycleDrainUnconfirmed)`. Terminal persistence failure yields
`failed(terminalPersistenceFailed)`. Task 37's Store operation keeps its
independent 90-second deadline and five-second cleanup bound. The outer
settlement envelope is not extra investigation time and none of these outcomes
may appear as cancelled, paused, budget complete or successful.

#### Event-time observed ceilings

Current App Server evidence can arrive only after turn admission:

| Dimension | Focused | Balanced | Thorough |
| --- | ---: | ---: | ---: |
| Observed direct Agent tool starts | 32 | 96 | 192 |
| Observed total tokens | 100,000 | 300,000 | 600,000 |

These are bounded stopping ceilings, not exact prepaid cost guarantees.

When an identity-valid event reaches one:

- request one bounded interruption when a turn is active;
- admit no later turn;
- wait for terminal `turn/completed`;
- drain the investigation audit session and proxy owner;
- report exact observed usage, including any overrun caused by event latency.

When token usage is absent, its state is `unavailable`, never zero. The run
continues under enforceable hard dimensions but records a typed degradation.
The UI cannot display exact remaining tokens or claim token-budget compliance.

### 6. Budget accounting is typed and monotonic

Task 36 defines a pure value ledger with:

- hard reservations;
- accepted observations;
- unavailable observations;
- active concurrency;
- consecutive verified no-gain steps.

Every event carries a dimension and provenance. The reducer rejects:

- negative deltas;
- counter decreases;
- overflow;
- exceeding hard concurrency;
- conflicting duplicate events;
- observations without matching investigation/run identity;
- model-prose consumption claims.

Hard arithmetic is exact. With unsigned limit `L`, consumed `C` and amount
`A`, reservation succeeds only when:

```text
A > 0 && C <= L && A <= L - C
```

Exactly `L` is admitted; equality then stops the next operation. Checked
arithmetic is mandatory.

- admitted turns and Probe calls consume one permanently even if they fail or
  are interrupted;
- reserved Probe read bytes remain consumed under the current conservative
  Broker contract;
- Probe output is encoded and checked against its per-call bound first, then
  atomically committed through the current `reserveOutputBytes`; a failed
  encode/per-call/session commit discards the response and consumes zero,
  while a committed amount remains consumed after later delivery/audit
  failure;
- context consumes when accepted by `turn/start`;
- Probe concurrency is an actor-owned lease acquired only when
  `active < limit`; normal terminal paths release exactly once and recovery
  releases only after lifecycle evidence proves no Probe worker remains;
- wall clock admits only while `elapsed < limit`;
- observed tool count closes admission at `count >= ceiling`;
- observed token usage closes admission at `totalTokens >= ceiling` and
  retains any exact overrun;
- after one valid scientific step, verified gain resets no-gain to zero and
  valid no-gain increments once; invalid/cancelled/protocol-failed steps use
  their higher-precedence path and do not change it.

Duplicate release, underflow, leaked concurrency, counter decrease, overflow
or conflicting replay is failure. Tests cover `N-1`, `N`, `N+1`, failure,
interruption and duplicate-release behavior for every dimension.

Cached input tokens are a breakdown of input tokens and are not added twice.
Task 38 owns the exact App Server normalization and must test it against
current protocol fixtures.

Observed direct-tool and token ceilings cover the complete
same-investigation live session tree, including spawned descendant
threads/subagents. Task 38 must bind every descendant to the admitted run,
deduplicate cumulative or replayed usage and reject unrelated thread events.

The Task 36 Core-neutral observation includes Investigation/run identity,
root session ID, thread/parent/turn/item IDs, a closed observation kind,
source-method token and serial coordinator ordinal. The admitted runtime
receipt selects exactly one normative collaboration schema and its closed
direct-tool set for the run. Task 38 is the only wire decoder:

- root thread ID must equal its ephemeral `sessionId`;
- a child requires both the receipt-selected canonical collaboration spawn
  edge and matching `parentThreadId`/root `sessionId` metadata;
- production never resumes/forks a stored thread; transport loss fails and
  drains;
- the first valid `item/started` for unique
  `(threadID, turnID, itemID)` counts one current-receipt tool item;
- equal replay is a no-op; conflicting duplicate, unknown tool-capable item,
  `fileChange` or write-capable MCP annotation blocks;
- `thread/tokenUsage/updated` is a cumulative per-thread snapshot with
  `total`, `last` and optional context window;
- the reducer retains only each thread's latest nondecreasing `total`, sums
  `total.totalTokens` once across admitted threads, never sums `last` or
  cached input, and rejects negative/decreasing/conflicting snapshots;
- missing matching usage at the terminal barrier becomes
  `usageUnavailable`, never an estimate.

Finalization rejects any live or unclassified descendant.

The existing `ProbeSessionBudget` remains the operational owner of Probe
call/read/output reservations. Phase D adapts admitted plan limits into it
rather than implementing a second Probe budget.

### 7. Turn, Probe and direct-tool counts remain separate

- one coordinator/model turn is one admitted `turn/start`;
- one Probe call is one admitted `ProbeBroker.execute`;
- one direct tool observation is one identity-valid canonical tool-item
  start;
- one scientific step is one normalized evidence delta evaluated by the stop
  reducer.

A turn may contain zero or many direct tools. Combining the counters would
misrepresent their enforcement quality.

### 8. Evidence gain is an accepted state change

Verified evidence gain requires at least one Swift-accepted change:

- a new identity-bound fact for an admitted target;
- target resolution state changes;
- valid reconciliation reduces measurable unexplained bytes;
- a new contradiction narrows or invalidates a hypothesis;
- a capability degradation truthfully narrows the report.

Model prose, repeated evidence, partial streams, unadmitted IDs, failed tools,
unsupported byte estimates and proposed actions are not gain.

The consecutive no-gain counter resets only after verified gain.

### 9. Stop precedence is exact

After each accepted evidence delta and before every next Swift-owned
admission:

1. containment, lifecycle, runtime identity or protocol loss:
   block/fail, request drain and preserve only verified partial evidence;
2. user cancellation:
   record `userCancelled`, request terminal interruption/drain and preserve
   verified partial evidence;
3. user stop:
   record distinct `userStopped`, close later admission and drain while
   preserving verified partial evidence;
4. hard limit exhausted or next reservation would exceed it:
   `budgetExhausted` with exact hard dimension;
5. event-time observed ceiling reached:
   `budgetExhausted` with exact observed dimension and usage quality;
6. requested coverage reached;
7. remaining measurable Unknown is below threshold;
8. consecutive verified no-gain limit reached;
9. continue.

Safety failure cannot become cancellation, user stop or a successful
scientific stop. Cancellation precedes user stop, and user stop precedes
budget/coverage. Accepted stop and cancel requests terminally map to
`partial(userStopped)` and `partial(userCancelled)` after the same drain and
atomic-commit barrier. Unmeasurable Unknown cannot satisfy a byte
threshold. An unavailable token observation proves neither exhaustion nor
remaining capacity.

### 10. Pause is bounded cancel-and-continue, not process suspension

Pause is a coordinator lifecycle request, not an
`InvestigationStopReason`.

Unless a future accepted protocol proves a safe between-step pause:

```text
pause requested
→ finish or bounded-interrupt current run
→ observe terminal turn
→ drain the complete audit session
→ persist latest verified partial report
→ paused
→ resume creates a new run with continuation lineage
```

Unverified streamed items from the interrupted run are not promoted.

### 11. Every terminal path is truthful

A run ends with one of:

- verified final report;
- verified partial report with unresolved targets, exact stop/degradation
  state and continuation lineage;
- typed blocked/failed result with no fabricated findings.

Model completion alone is not a final report. Strict Envelope v2 identity,
normalization, accepted budget observations and lifecycle drain remain
separate evidence.

### 12. No execution authority enters Investigation Core

Task 36 Core files cannot reference:

- `ActionExecutor`;
- `CleanupExecutionRuntime`;
- `ExecutionAuthorization`;
- `TrashMoving` or `FileManager.trashItem`;
- `RegisteredActionRunner`;
- `StornautCodex` or `StornautLifecycle`;
- arbitrary `Process` or shell execution.

Later `StornautInvestigation` runtime code may depend on Codex/Lifecycle but
must still have no Executor, Trash, Policy-authorization or action-construction
surface.

Agent-only rule misses remain at most `Review Recommended`, unselected and
non-executable. Any later cleanup rejoins the unchanged Phase C chain through
current Store IDs, current deterministic evidence, Plan Builder, Policy,
selection, exact confirmation and one-shot authorization.

Task 37's SQLite connection is actor-private and installs a deny-by-default
`sqlite3_set_authorizer`. Investigation mutations are permitted only while the
owner prepares source-constant SQL for one closed typed migration/operation;
the raw handle, generic SQL, statement construction and mutable authorizer
mode never escape. DDL owns row-local checks. Decoded Plan membership,
aggregate-counter equality and lifecycle transitions remain typed
transaction/pre-commit invariants, reverified on reopen so same-user external
database mutation becomes corrupt rather than trusted state.

The closed 90-second Store deadline is not inferred from Task 36's planner
benchmark. Task 37 must measure three serial Release samples each for
maximum-size insertion, rejoin, terminal commit, crash recovery and
continuation. Every sample includes source/decode/hash/SQLite/verification and
commit, preserves the streaming memory bound and completes within 75
monotonic seconds. Otherwise Task 37 is `capacityBlocked` and requires ADR/user
review; it cannot raise the deadline, truncate, retry or split a snapshot.

## Alternatives Rejected

### Codex-generated admitted plan

Rejected because model output cannot create target or budget authority.

### Prompt-owned budgets

Rejected because prompts are advisory, mutable and not enforcement.

### Exact in-flight token preemption

Rejected because usage events are asynchronous and may be absent.

### Token estimation from bytes or prose

Rejected because it is not provider accounting and may double-count or omit
reasoning/cached input.

### Exact direct-tool cap within one turn

Rejected because direct tools occur inside an admitted turn and no universal
pre-call coordinator hook exists without weakening approved capabilities.

### One undifferentiated tool budget

Rejected because Probe reservations are hard while direct tools are observed.

### Unlimited turns when usage is unavailable

Rejected because missing telemetry cannot remove finite wall-clock and turn
limits.

### Floating-point ranking

Rejected because nondeterministic order would change plan fingerprints.

### Unknown bytes represented as zero

Rejected because measurement gaps must remain Unknown.

### Agent-only promotion to Ready

Rejected by the product invariant and existing Phase C admission model.

### New Agent-specific Executor

Rejected because it would create a second write-authority path.

## Consequences

Positive:

- target planning and stopping are reproducible without a model;
- budget UI can distinguish guaranteed admission limits from observed usage;
- missing token telemetry degrades truthfully instead of becoming zero;
- direct Agent capability remains intact without fake hard-cap claims;
- the existing Probe budget and Phase C Executor remain authoritative;
- pause/cancel semantics match actual App Server and lifecycle behavior.

Costs:

- the budget domain is more explicit than a single “tokens remaining” number;
- Task 38 must add identity-bound usage/tool observation or expose degradation;
- one admitted turn may overshoot an observed ceiling;
- UI copy must communicate enforcement quality without excessive complexity;
- continuation requires a new run rather than frozen process state.

## Residual Risks

1. App Server event shapes can drift. Runtime receipt and protocol fixtures
   must invalidate admission on incompatible versions.
2. Token usage may remain absent for some providers or completions.
3. A single model turn may perform more direct tools or tokens than desired
   before interruption is observed.
4. Integer priority factors are product heuristics, not proof that the most
   valuable unknown is always first.
5. Task 36 does not prove runtime behavior, persistence, App integration,
   report quality or production Deep Dive admission.
6. SQLite authorizer is an in-process API boundary, not OS containment against
   a separate same-user process editing the database file.

## Validation

Task 36 admission requires:

```text
tests authored before implementation
strict domain and unknown-key fixtures
exact preset mapping tests
reservation/observation provenance tests
usage unavailable and observed-overrun tests
all stop precedence combinations
deterministic shuffled-input and overflow fixtures
100,000-row bounded planner benchmark
structural no-Executor verifier
serial SwiftPM
independent review with zero unresolved P0-P2
one uninterrupted scripts/verify --full exit 0
independent commit and push
```

This ADR is `Accepted for Task 36 implementation`. Task 36 is materialized
directly on authoritative pushed Phase C / Task 35 closure
`86ee2aa9428cfc71036e18dcb2c1349ec248ec73`; no synthetic replay commit enters
the mainline history. This decision does not make production Deep Dive
available. Task 44 remains the final product-flow admission gate.
