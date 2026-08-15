# Task 36 Implementation Brief — Investigation Domain, Planner, Budget and Stop Contracts

> **Status:** Complete; independent review clean and authoritative full
> verifier passed.
>
> **Parent plan:**
> [Phase D Conditional Deep Dive](phase-d-conditional-deep-dive.md)
>
> **Implementation baseline:** authoritative pushed Phase C / Task 35 closure
> `86ee2aa9428cfc71036e18dcb2c1349ec248ec73`; Task 36 is materialized directly
> on this baseline and does not inherit any synthetic replay commit.
>
> **Normative low-level contract:**
> [Investigation Canonical v1](../../specs/investigation-canonical-v1.md). Its complete codec/schema,
> source-manifest bounds, priority arithmetic, clock/resource lifecycle,
> receipt-versioned runtime normalization, persisted URL grammar and
> capability matrix override every summary in this brief.
>
> **Completion evidence:**
> [Phase D Task 36 Review](../../reports/phase-d-task-36-review.md).

## 1. Objective

Task 36 creates the deterministic, non-executing scientific planning core for
Deep Dive:

```text
one retained terminal Quick Scan projection
→ typed unknown/conflict/gap candidates
→ deterministic priority and stable target set
→ closed Investigation Plan
→ exact budget limits
→ pure hard-reservation and observed-usage ledger
→ pure stop evaluation
```

It does not launch Codex, call a model, create a runtime workspace, migrate the
Evidence Store, change the App, accept disclosure, persist an Investigation,
build a Cleanup Plan, run Policy, or expose any cleanup authority.

Completion requires tests-first contracts, a bounded benchmark, independent
review with zero unresolved P0–P2 findings, one authoritative
`scripts/verify --full` exit `0`, and an independent commit/push.

## 2. Required Upstream Study

Before implementation, add
`docs/upstream-studies/epic-6-investigation-planning.md` and record:

- OpenAI Codex official current documentation for runtime/tool/cancellation
  and token-usage semantics relevant to planning, without treating prompt
  controls or a successful model call as containment;
- scientific-agent or investigation-loop references used only for behavior;
- deterministic ranking/stop-condition references;
- URL, reviewed version/commit/date, license, exact files/pages, adopted
  behavior, rejected behavior, code reuse decision and attribution;
- why Stornaut uses independent Swift domain code rather than copied Agent
  orchestration code.
- why direct Agent tools and App Server tokens are event-time observations,
  while only Swift-owned operations can be hard-reserved before admission.

The study must verify the current official documentation live when practical.
No new dependency is allowed unless separately justified with license and
maintenance cost.

## 3. ADR

Add `docs/adr/0017-investigation-planning-and-stop-semantics.md` with:

- deterministic Swift ownership of target generation and budget enforcement;
- fixed-point/integer priority calculation and missing-size behavior;
- stable tie-break rules;
- exact budget presets;
- hard-admission versus event-time-observed usage semantics;
- unavailable usage and observed-overrun behavior;
- exact stop precedence;
- pause/cancel distinction;
- evidence-gain definition;
- partial-report obligation;
- explicit non-authority and no-Executor boundary;
- rejected alternatives, including model-owned budgets, floating-point
  nondeterminism, optimistic missing-size ranking and Agent-only Ready
  promotion.

The ADR may be accepted for Task 36 implementation only. It must not claim
to enable production Deep Dive.

## 4. Domain Changes

### 4.1 IDs

Add strongly typed domain IDs:

- `InvestigationID`, prefix `investigation-`;
- `InvestigationRunID`, prefix `investigation-run-`;
- `InvestigationReportID`, prefix `investigation-report-`.

Retain `InvestigationTargetID`, prefix `target-`, for compatibility.

### 4.2 Target v2

Replace the unused v1-only placeholder with a strict v2 product target. Legacy
v1 decoding is allowed only in a separately named fixture/migration adapter.
Legacy values are rejected by planning, Plan construction, Store v4, runtime
admission and continuation unless a future explicit migration reconstructs and
verifies every mandatory v2 source binding. Task 36 performs no lossy or
implicit v1 upgrade.

`InvestigationTarget` v2 must include:

- `id`;
- source `scanSessionID`;
- source `scanScopeID`;
- one strict `InvestigationSourceBinding`:
  - snapshot ID;
  - classification ID plus its exact snapshot ID;
  - closed Space Ledger measure key for the retained session/scope;
- `kind`;
- reason keys as a canonical-set: unique and already sorted by each
  `DomainToken`'s complete canonical bytes;
- expected allocated bytes when measurable;
- uncertainty factor;
- user-relevance factor;
- estimated investigation-cost factor;
- deterministic priority;
- creation timestamp.

Approved target kinds:

| Swift case | Canonical wire token |
| --- | --- |
| `unknownLargeConsumer` | `unknown-large-consumer-v1` |
| `unexplainedSpaceGap` | `unexplained-space-gap-v1` |
| `classificationConflict` | `classification-conflict-v1` |
| `unknownProducer` | `unknown-producer-v1` |
| `staleOrInsufficientEvidence` | `stale-or-insufficient-evidence-v1` |

The camelCase spelling exists only in Swift source. Canonical encoding and all
persisted identity/fingerprint inputs use only the exact versioned wire token.

The contract rejects:

- no source binding;
- more than one source binding;
- cross-session/scope binding;
- classification/snapshot mismatch;
- ledger-only target with an invented path/snapshot;
- zero/negative factors;
- duplicate reason keys;
- unmeasurable gap represented as `0 B`;
- invalid priority;
- unknown persisted keys.

### 4.3 Budget limits

Add `InvestigationBudgetLimits` with finite positive limits:

- wall-clock duration;
- coordinator/model turns;
- Probe Broker calls;
- Probe read bytes;
- Probe output bytes;
- cumulative Swift-built model-context bytes;
- maximum concurrent probes;
- maximum consecutive no-evidence-gain steps;
- observed direct Agent tool-start ceiling;
- observed total-token ceiling.

Add a deterministic mapping from the existing
`InvestigationBudgetPreset`:

- `.focused` → exactly 10 wall-clock minutes;
- `.balanced` → exactly 30 wall-clock minutes;
- `.thorough` → exactly 60 wall-clock minutes.

The exact preset matrix selected by the Upstream Study/ADR is:

| Dimension | Focused | Balanced | Thorough |
| --- | ---: | ---: | ---: |
| Wall clock | 600 s | 1,800 s | 3,600 s |
| Coordinator/model turns | 4 | 12 | 24 |
| Probe calls | 16 | 48 | 96 |
| Probe read reservation | 8 MiB | 32 MiB | 64 MiB |
| Probe output reservation | 2 MiB | 8 MiB | 16 MiB |
| Cumulative Swift-built context | 1 MiB | 4 MiB | 8 MiB |
| Concurrent Probes | 2 | 4 | 8 |
| Consecutive verified no-gain steps | 2 | 3 | 4 |
| Observed direct Agent tool starts | 32 | 96 | 192 |
| Observed total tokens | 100,000 | 300,000 | 600,000 |

Every single Swift-built model input is additionally capped at 256 KiB.
Existing lower protocol-specific limits remain authoritative.

All elapsed-time behavior uses an injected `ContinuousClock`. A later serial
coordinator atomically samples immutable `runStart` with its transition into
running, and samples immutable T0 exactly once at the first accepted fact
whose normative precedence closes scientific admission. Wall-calendar time is
metadata only. The wall-clock deadline closes admission of new scientific
work; the separate 140-monotonic-second terminal settlement envelope begins at
T0:

1. at T0 atomically close turn/Probe/context admission, record the cause and
   send at most one interrupt per active `(threadID, turnID)`;
2. through T0+15 seconds consume matching terminal/usage/item events and never
   promote evidence from an unterminated turn;
3. when all admitted turns are terminal, or at T0+15 seconds, invoke the
   idempotent audit-session drain;
4. by T0+45 seconds prove the audit session and managed proxy owner empty,
   retire ephemeral artifacts and begin the Store-owned terminal transaction;
5. by T0+135 seconds atomically persist terminal truth or interrupt/roll back
   the transaction;
6. by T0+140 seconds complete the separate rollback/connection cleanup or
   quarantine the Store connection as `rollbackUnconfirmed`.

Missing terminal events plus proved forced drain become
`blocked(runtimeTerminalUnobserved)`. Unproved drain becomes
`blocked(lifecycleDrainUnconfirmed)`. Terminal persistence failure becomes
`failed(terminalPersistenceFailed)`. None may be represented as cancelled,
paused, budget-complete or successful. The Store operation retains Task 37's
independent 90-second deadline and five-second cleanup bound; the outer
140-second envelope is not additional scientific budget.

The first eight dimensions are hard admission/reservation limits where Swift
owns the operation boundary. Direct Agent tool starts and tokens are
event-time observed ceilings: one already admitted turn may exceed them
before an event arrives. Reaching an observed ceiling prevents later turns
and requests bounded interruption in Task 38; it is not an exact prepaid cost
guarantee.

Token observation may be unavailable. The domain must represent unavailable
as distinct from zero and must not estimate tokens from bytes, elapsed time or
model prose. All limits remain finite, monotonic and cannot be supplied as
arbitrary CLI flags.

Observed direct-tool and token ceilings apply to the complete
same-investigation session tree, including spawned descendant
threads/subagents. Task 38 owns identity binding, cumulative/replay
deduplication and rejection of unrelated thread events.

Task 36 defines only the following Core-neutral observation shape:
Investigation/run identity, root session ID, thread/parent/turn/item IDs, closed
observation kind, source-method token and serial coordinator ordinal. Task 38
is the sole wire decoder. The admitted runtime receipt selects exactly one of
the normative collaboration schemas and its corresponding closed direct-tool
set for the run; Task 38 must enforce:

- root ephemeral `thread.id == thread.sessionId`;
- child admission only after the receipt-selected canonical collaboration
  spawn edge plus matching `parentThreadId` and root `sessionId`;
- no production resume/fork of a stored runtime thread;
- exactly one direct-tool count for the first valid `item/started` keyed by
  `(threadID, turnID, itemID)`;
- the receipt-selected closed tool set from the normative specification;
- block on `fileChange`, unknown tool-capable items, write-capable MCP
  annotations, conflicting duplicate or mismatched identity;
- `thread/tokenUsage/updated` as a cumulative per-thread snapshot containing
  `threadID`, `turnID`, `total`, `last` and optional context-window data;
- retain only the latest nondecreasing `total` per admitted thread and sum each
  latest `total.totalTokens` once across the run, never `last` or cached input;
- equal replay is a no-op; negative, decreasing, conflicting or mismatched
  snapshots fail;
- no matching usage snapshot at the terminal barrier means
  `usageUnavailable`;
- finalization rejects live or unclassified descendants.

### 4.4 Streaming source projection

Task 36 defines a closed, Store-neutral
`InvestigationSourceCursorFactory` seam rather than accepting arrays of every
stored payload. A factory:

- owns immutable selected Scan session/scope IDs and at most 256 relevance
  tokens;
- creates exactly two fresh cursors for one opaque source-generation token;
- emits one `InvestigationStoredSourceRow` at a time in complete canonical
  `SourceRowV1` byte order;
- gives each cursor only one current raw Store row: closed row kind, required
  non-payload columns and exact stored payload bytes;
- cannot supply a caller-computed digest, “verified” flag, omitted-row count or
  prebuilt source fingerprint.

The raw row constructor rejects more than four storage columns, empty or
greater-than-64-byte UTF-8 column names, and greater-than-16,384-byte UTF-8
text values before any canonical buffer allocation. It also computes each
complete canonical row length with checked arithmetic before allocation and
rejects a row above the 512 MiB source canonical bound.
Canonical `SourceProjectionV1` validation reuses the same raw bounds before
canonical column re-encoding, ordering checks or row-kind semantic matching;
over-bound persisted input is `sourceProjectionTooLarge`, not a later
`storageMismatch` or `nonCanonicalOrder`.

Projection is a repeatable two-pass stream:

1. pass one alone strict-decodes/re-encodes each raw payload into its exact
   typed Core value, validates every required Store column against that value,
   hashes one payload at a time, validates parent/session/scope membership,
   canonical row order and every count/byte bound, submits each normalized
   `SourceRowV1` metadata value to a caller-owned non-escaping
   `InvestigationManifestSink`, builds only a compact policy-relevant index,
   and records a checked row-sequence verification digest;
2. pass two must carry the same source-generation token and re-hash the exact
   bytes plus required columns without repeating typed policy-index
   construction; it reproduces the exact count, aggregate lengths and
   row-sequence digest while feeding the canonical SourceProjection encoder
   into a write-only
   `InvestigationCanonicalHashSink` incrementally;
3. any cursor error, generation change, sequence drift, early end, extra row
   or aggregate mismatch fails closed;
4. the current payload buffer is released before requesting the next row.

The pass-one sink receives one normalized manifest row at a time and may fail
the operation; Task 37 supplies a prepared-statement Store sink inside its
pinned transaction. The hash sink returns only digest/count metadata and never
returns accumulated `Data`. A materializing sink exists only in small golden
vector tests and is unavailable to production projection APIs.

The compact planner index retains only validated IDs, source bindings,
measurements and fields required by `CandidatePolicyV1`, including a derived
`isRoot` bit for snapshot rows whose strict `relativePath == "."`. It retains
no raw payload, relative path, complete typed source record, canonical row
bytes or full source-row manifest. The resulting
`InvestigationSourceProjectionSummary` contains selected IDs, exact
counts/byte totals, relevance tokens and source fingerprint, not the
300,002-row manifest. Task 37 later implements the production cursor and
manifest sink from one pinned Store transaction.

The source-domain complete canonical input is at most `512 MiB`; exact source
payload bytes remain independently capped at `256 MiB`. The maximum-size
streaming benchmark uses 300,002 generated rows and the 256 MiB payload
boundary, completes within 60 seconds on the recorded supported Apple Silicon
development machine, and keeps incremental resident-memory growth below
192 MiB plus the single largest admitted payload (16 MiB). Peak memory is read
from the kernel process-lifetime
`task_vm_info_data_t.ledger_phys_footprint_peak` high-water mark, not from
periodic row sampling. The benchmark runs in its own
`swift test --no-parallel --filter` invocation after ordinary Swift suites
have excluded it, so unrelated concurrent tests cannot contaminate the
measurement. Exceeding a threshold blocks Task 36; it is not relaxed without
fresh review.

### 4.5 Plan

Add immutable `InvestigationPlan`:

- strict v1 plan schema containing v2-only targets;
- Investigation ID;
- source Scan session/scope IDs and source fingerprint;
- selected budget preset and full limits;
- ordered targets, maximum 512;
- target-set fingerprint;
- created/expires timestamps;
- requested coverage threshold;
- remaining-unknown byte threshold;

Every measured byte value uses `ByteCountV1` in `0...Int64.max`. Binary and
strict `DomainJSON` decoding reject `Int64.max + 1...UInt64.max`.
- required capability set expressed in Core-neutral tokens, not Codex runtime
  types.

The plan:

- contains no absolute executable, command, output schema bytes, runtime auth,
  path mutation, action, disposition, Policy, Trash or Executor fields;
- grants no authority;
- rejects duplicate target IDs/source bindings;
- rejects any target sequence outside the exact Planner order even when a
  caller recomputes internally consistent target-set and Plan fingerprints;
- uses one shared ordering implementation for Planner output, construction,
  strict `DomainJSON` decoding and canonical-binary decoding;
- rejects expired-at-creation and malformed thresholds;
- is strict-decoding and bounded.

### 4.6 Budget ledger

Add immutable `InvestigationBudgetLedger` and pure reducer events with
explicit provenance:

- wall-clock elapsed;
- coordinator/model turns reserved;
- Probe calls/read/output bytes reserved;
- Swift-built context bytes reserved;
- active concurrent probes;
- consecutive no-evidence-gain count;
- direct Agent tool starts observed;
- total tokens observed or unavailable.

The reducer:

- rejects counter decreases, overflow and negative deltas;
- rejects concurrency above the admitted limit;
- distinguishes “at limit” from “would exceed before next operation”;
- distinguishes hard reservation, accepted observation and unavailable
  observation;
- rejects conflicting duplicate or identity-mismatched observations;
- never double-counts cached input as additional total input;
- never trusts model-reported consumption;
- remains pure and deterministic.

Hard arithmetic is normative. For unsigned limit `L`, consumed `C` and
reservation `A`, admission succeeds only when:

```text
A > 0 && C <= L && A <= L - C
```

Exactly `L` is admitted and then the next operation is blocked. Checked
arithmetic is mandatory:

- admitted turns and Probe calls remain consumed after failure/interruption;
- reserved Probe read bytes remain consumed;
- Probe output is encoded and checked against the per-call bound first, then
  atomically committed through the current `reserveOutputBytes`; failed
  encoding/per-call/session commit discards the response and consumes zero,
  while a committed amount survives later delivery/audit failure;
- context consumes when accepted by `turn/start`;
- concurrency is an actor-owned exactly-once lease acquired only when
  `active < limit`; normal terminal paths release once and recovery releases
  only after lifecycle evidence proves no Probe worker remains;
- wall-clock work admits only while `elapsed < limit`;
- observed tools/tokens close later admission at `>= ceiling` and retain exact
  overruns;
- verified gain resets no-gain, valid no-gain increments once, and invalid,
  cancelled or protocol-failed steps do not change it.

Duplicate release, underflow, overflow, counter decrease or conflicting replay
is a typed failure.

Task 36 models these semantics only. It does not parse App Server events.
Task 38 must subscribe to and normalize identity-bound usage/tool events or
truthfully produce `usageUnavailable`. The existing `ProbeSessionBudget`
remains the operational owner of Probe call/read/output reservations.

### 4.7 Stages and stop outcomes

Add:

- `InvestigationStage`: prioritize, identify, verify, buildPlan;
- `InvestigationStopReason`:
  - coverageReached;
  - remainingUnknownBelowThreshold;
  - budgetExhausted(dimension);
  - noEvidenceGain;
  - userStopped;
  - userCancelled;
- Investigation terminal status excludes standalone `stopped` and
  `cancelled` cases: stop and cancellation are internal requests/primary
  causes and, after the canonical barrier plus atomic commit, become
  `partial(userStopped)` and `partial(userCancelled)` respectively;
- typed safety/runtime/protocol failure outcomes separate from scientific stop
  reasons;
- `InvestigationStopEvaluation`: continue, stop(reason), block(reason),
  fail(reason).

Stop precedence:

1. containment/lifecycle safety loss → block/fail;
2. user cancellation → stop with `userCancelled` as the immutable primary
   cause; the coordinator later commits canonical `partial(userCancelled)`;
3. user stop → stop with distinct `userStopped` as immutable primary cause;
   the coordinator later commits canonical `partial(userStopped)`;
4. any hard budget exhausted/would be exceeded → budget stop with exact
   dimension;
5. any identity-valid observed ceiling reached → budget stop with exact
   dimension and observation quality;
6. coverage threshold reached;
7. remaining measurable Unknown below threshold;
8. consecutive no-evidence-gain limit reached;
9. continue.

Unavailable token usage proves neither exhaustion nor remaining capacity.
An observed ceiling may record a post-event overrun; the ledger preserves the
exact observed value rather than clamping it.

Pause is not a terminal stop reason and must be represented separately for a
later coordinator Task.

## 5. Candidate Planner

Add a pure `InvestigationCandidatePlanner` in
`Sources/StornautCore/Investigation/`.

### 5.1 Input

The Planner accepts one bounded streaming projection containing:

- caller-created `InvestigationID`;
- retained terminal `ScanSession`;
- exact primary `ScanScope`;
- repeatable canonical source-row cursor factory;
- Space Ledger and reconciliation status;
- relevant retained Evidence freshness;
- optional user relevance tokens;
- selected budget preset and current time.

The current time is an injected value. The Planner must not call `UUID()` or
read the system clock.

The selected Scan session is usable only when it is not failed, the selected
primary scope appears exactly once completed, `unfinishedScopes` is empty, its
retained expiry is strictly after the injected planning time, and the
exhaustive same-session source projection passes. Its Space Ledger must be
exactly `reconciled`, contain zero `coverageGaps`, report
`unknownIncludesUnmeasurable == false`, and carry measured-zero unmeasurable
bytes. The existing Quick Scan `completed`, `partial` and `cancelled` terminal
states may supply that exact completed-primary/no-gap shape; this does not add
a standalone Investigation terminal `cancelled` state.

Phase D selects one primary root, so v1 has no non-primary/secondary-scope
exception. A permission or boundary limitation is represented by either a
typed unfinished-scope reason or an exact retained Space Ledger coverage gap;
both fail eligibility through the closed
`InvestigationSourceEligibilityV1` reason enum. No free-form “limited” flag is
accepted.

It must reject:

- non-terminal or unusable Scan sessions;
- mixed sessions/scopes;
- expired/corrupt source facts;
- missing ledger when creating a gap target;
- more input rows than the explicit planning limit;
- invalid target bindings.

### 5.2 Candidate rules

Generate candidates only for:

- `.unknown` large measured classifications;
- ledger unexplained/gap records that are actually measurable;
- typed classification/risk conflicts;
- missing producer identity;
- stale/insufficient evidence on otherwise relevant unknown items.

Protected and known Ready items are not investigation candidates merely to
increase finding count.

Multiple reasons for the same snapshot/classification become one target with
reason keys in canonical-set byte order. A ledger-only gap remains a distinct
target with no invented path or snapshot.

The normative `CandidatePolicyV1` table in
`docs/specs/investigation-canonical-v1.md` is the only rule/factor/default
source. In summary:

- measured large means allocated bytes greater than or equal to exactly
  `1_073_741_824`;
- v1 has no scope-relative large threshold;
- coverage is exactly `900` permille;
- the remaining measurable Unknown threshold is exactly
  `1_073_741_824` bytes and stops only when the remaining value is strictly
  below it;
- Plan expiry is the earlier of the retained Scan-session expiry and
  `createdAt + selected preset wall clock`;
- relevance starts at `700` permille and only the closed canonical-set tokens
  `relevance.large` and `relevance.developer` can each add `100` under the
  exact applicability rules in the normative specification;
- unknown or duplicate relevance tokens reject planning;
- kind-specific uncertainty/cost factors are closed constants, not caller or
  model input;
- one non-Protected classification/snapshot source produces at most one target
  using exact precedence: classification conflict, unknown large consumer,
  unknown producer, then stale/insufficient evidence;
- a classification source retains every applicable fixed reason and exact
  missing-evidence key even when precedence selects one target kind;
- a missing classification creates only a snapshot-bound
  stale/insufficient-evidence candidate, never a size-only Unknown candidate;
- the eligible reconciled Space Ledger produces at most one
  `unknown-residual-v1` target for measurable nonzero Unknown;
- measured zero, unavailable bytes, coverage gaps and inconsistent status
  create no target and are never converted to zero;
- every target has `1...16` reasons and the complete canonical Plan digest
  input is at most `2 MiB`; overflow rejects without truncation.

The v1 factor matrix is:

| Target kind | Uncertainty | Cost |
| --- | ---: | ---: |
| unknown large consumer | `750` | `250` |
| unexplained space gap | `1_000` | `800` |
| classification conflict | `1_000` | `350` |
| unknown producer | `850` | `400` |
| stale/insufficient evidence | `700` | `300` |

Ordinary `readyToReclaim` remains ineligible. The only Ready conflict
candidate is a retained contradictory safety shape: risk is `high`/`critical`
or confidence is not `high`. This detects a conflict and grants no cleanup
authority.

### 5.3 Stable identity and fingerprints

Derive `InvestigationTargetID` as:

```text
target-<full lowercase SHA-256>
```

over a versioned, domain-separated, length-prefixed canonical encoding of:

- Scan session ID;
- Scan scope ID;
- target kind;
- exact source binding.

Reason keys, priority and current evidence are not part of target identity.
Duplicate derived IDs fail closed.

The normative codec is `StornautInvestigationCanonicalV1`:

- magic ASCII `STORNAUT-INV-CANON-1\0`, then one encoded domain string and one
  root record;
- nil `00`, false `01`, true `02`;
- UInt64 `10` plus 8-byte big-endian value;
- Int64 `11` plus 8-byte big-endian two's-complement value;
- text `20` plus UInt64 UTF-8 byte length and exact bytes;
- bytes `21` plus UInt64 length and exact bytes;
- array `30` plus UInt64 count and individually UInt64-length-prefixed encoded
  values;
- record `40` plus UInt64 field count and strictly increasing unique
  big-endian UInt16 tags, each followed by a UInt64-length-prefixed encoded
  value.

Every optional field is present and encodes nil when absent. Enums use exact
lowercase versioned ASCII tokens. Dates use Int64 Unix microseconds truncated
toward zero. Text receives no Unicode, case, path, locale or percent
normalization. Invalid UTF-8, trailing bytes, missing optionals,
duplicate/out-of-order tags and non-domain values are rejected. JSON,
reflection, native layout, dictionary order and `Hashable.hashValue` are
forbidden for identity.

Fixed domains are:

```text
stornaut.investigation.target.v2
stornaut.investigation.source.v1
stornaut.investigation.target-set.v1
stornaut.investigation.plan.v1
```

Source, target-set and plan fingerprints use those separate domains. The plan
fingerprint includes the caller-supplied Investigation ID, source fingerprint,
exact limits, thresholds, timestamps and ordered target payloads. Tests inject
identical Investigation IDs/current time when asserting repeatability and pin
complete encoded-hex/SHA-256 product vectors plus:

```text
empty      724b07f461c7690c1e0614abdbd72081d88622e2aab47183236b6bf8e049dc3b
primitives 56a27067b51cef0ebc1236d51200b250987fce1ee74832047fa2063ef0da9075
```

`sourceFingerprint` is computed by the Planner from the complete bounded
immutable typed-row manifest, never accepted as caller text. It binds exact
stored payload digests plus every non-payload identity column for the terminal
session row, complete Space Ledger row, and exhaustive selected-scope
snapshot/classification/evidence rows, with strict typed decode and
byte-identical `DomainJSON` re-encode. The normative specification fixes all
row/payload/relevance limits and rejects top-N truncation:

- snapshots: at most `100,000`;
- classifications: at most `100,000`;
- evidence: at most `100,000`;
- evidence per snapshot: at most `100`;
- total source rows: at most `300,002`;
- relevance tokens: at most `256`;
- ordinary payload: at most `1 MiB`;
- Space Ledger payload: at most `16 MiB`;
- aggregate exact source payload: at most `256 MiB`;
- complete canonical SourceProjection digest input: at most `512 MiB`;
- complete canonical Plan digest input: at most `2 MiB`;
- strict persisted Plan `DomainJSON`: at most `4 MiB`.

The binary and JSON Plan bounds are independent; fitting one does not excuse
exceeding the other. Task 37 persists the fingerprint and complete manifest as
normalized bounded source-row and relevance-token rows, then recomputes exact
membership and bytes at all eight normative rejoin barriers.

### 5.4 Priority

Implement:

```text
expectedBytes × uncertainty × userRelevance / estimatedInvestigationCost
```

by rounding measurable bytes up to MiB, multiplying the three bounded
`1...1_000` UInt64 factors with checked arithmetic, and dividing by cost with
integer floor. The proved maximum numerator remains below `UInt64.max`; there
is no saturation path. It must:

- avoid floating-point ordering drift;
- avoid overflow;
- place every measurable target tier before a separate unmeasurable tier,
  without treating unknown as zero bytes in the domain;
- sort by descending priority, then stable target kind/source ID/reason
  tie-breaks;
- cap admitted targets at 512 and report omitted candidate count/bytes
  conservatively.

### 5.5 Output

Return:

- `InvestigationPlan`;
- deterministic planning diagnostics:
  - considered count;
  - admitted count;
  - omitted count;
  - measurable admitted/omitted bytes;
  - target-kind counts;
- no prompt, model text, action or Cleanup Plan.

The pure Planner may return an empty `InvestigationPlan` plus
`noEligibleTargets` diagnostics. That value is never runtime-admissible.
Task 37 must roll back initial creation and persist no Investigation/run when
the target array is empty; Task 38 must never start Codex for it. Persisted
run-owned Plans therefore contain `1...512` targets.

## 6. Tests First

Write failing tests before implementation.

### 6.1 Domain tests

- strict valid round trips for every new type;
- v1 fixture/migration-only decoding and rejection from v2 planning/Plan
  admission without reconstructable strict bindings;
- unknown/duplicate key, omitted optional, unsupported version and malformed
  ID rejection;
- explicit-null optional fixtures plus exact integer lexeme fixtures for
  `2^53 - 1`, `2^53`, `2^53 + 1`, `Int64.max`, `Int64.max + 1`,
  `UInt64.max`, negative unsigned input and overflow;
- `ByteCountV1` max/max+1 binary and `DomainJSON` rejection;
- invalid/missing source binding rejection;
- classification/snapshot and ledger-binding rejection;
- duplicate reason/target/source rejection;
- measured zero vs unknown measurement semantics;
- missing-classification root/non-root behavior through the derived `isRoot`
  bit with no retained path in the compact index;
- plan expiry/threshold/512-limit validation;
- absence of action/Policy/authorization fields in encoded fixtures.

### 6.2 Budget tests

- exact 10/30/60-minute presets;
- exact monotonic finite non-wall-clock limits;
- every limit dimension;
- overflow/decrease/negative/concurrency rejection;
- exact boundary and next-operation admission;
- hard reservation versus event-time observation provenance;
- token usage unavailable is not zero;
- observed ceiling may retain an exact overrun while blocking later work;
- duplicate/conflicting/identity-mismatched observation rejection;
- root and descendant observations aggregate once for the same investigation;
- replayed/cumulative observations do not double-count;
- cached input does not double-count total input;
- no-evidence-gain reset/increment semantics.
- `N-1`, `N`, `N+1`, failure/interruption and duplicate-release fixtures for
  every hard dimension;

### 6.3 Stop evaluator tests

- all six required stop reasons;
- exact precedence combinations;
- containment failure never becomes budget/cancel success;
- cancellation before coverage;
- exhausted dimension is preserved;
- hard budget precedes observed budget and both precede coverage;
- unavailable token usage does not imply continue capacity or exhaustion;
- observed overrun is retained without admitting later work;
- unmeasurable remaining Unknown cannot satisfy a byte threshold;
- no-evidence-gain only after the admitted consecutive limit;
- pause is non-terminal.

### 6.4 Planner tests

- exact `InvestigationSourceEligibilityV1` matrix for eligible `completed`,
  `partial` and existing Quick Scan `cancelled` states;
- every unfinished primary reason (`interrupted`, `cancelled`,
  `permissionDenied`, `mountBoundary`, `userExcluded`, `metadataChanged`,
  `storeFailure`, `scannerFailure`) rejects with typed
  `primaryScopeUnfinished`;
- contradictory completed-primary plus permission/boundary coverage gap
  rejects as `permissionOrBoundaryLimited`;
- stale, expired, missing and corrupt source map to their exact closed reasons;
- each approved target kind;
- no target for ordinary known/Protected/Ready facts;
- deduped multi-reason target;
- stable ordering independent of input order;
- direct construction and both decoders reject reordered targets;
- no random UUID/system-clock dependency;
- exact domain-separated target/source/target-set/plan fingerprint fixtures;
- canonical primitive/Unicode/optional/enum/array/integer-boundary vectors,
  non-canonical rejection and pinned encoded hex/SHA-256;
- complete source-projection inclusion and fingerprint drift rejection;
- changed source-generation token, second-pass row/count/length/digest drift,
  early end and extra-row rejection;
- maximum-size projection retains no raw payload/full manifest arrays and
  meets the exact peak-memory/time thresholds;
- integer overflow adversarial fixtures;
- missing expected bytes;
- eligible ledger-only unknown residual without invented path;
- source session/scope mismatch;
- stale/corrupt/expired input fail closed;
- 512 cap and truthful omissions;
- empty plan;
- empty Plan yields `noEligibleTargets`, creates no Store session/run and is
  not runtime-admissible;
- deterministic repeated fingerprint;
- Agent-independent output.

### 6.5 Normative specification tests

- strict decode/re-encode for all complete schema/tag/type/enum/collection
  tables;
- all six complete encoded-hex/SHA-256 vectors;
- exact source-row bounds and all eight rejoin-barrier names;
- injected `ContinuousClock`, atomic immutable `runStart`/T0 and terminal
  barrier boundaries;
- exact Probe reserve/commit/release and recovery semantics;
- both receipt-versioned collaboration schemas with exactly one selected per
  run;
- strict persisted HTTPS public-origin grammar and Task 37 ownership contract;
  Task 37 implements the parser, adversarial fixtures and SQLite byte-sentinel
  persistence tests;
- the fixed capability set:
  `directRead`, `shell`, `unifiedExec`, `liveSearch`,
  `publicCommandNetwork`, `browserOrDirectFetch`, `imageInspection`, `skills`,
  `subagents`.

### 6.6 Structural tests

Add or extend a script that proves Task 36 Investigation Core files contain no
reference to:

- `ActionExecutor`;
- `CleanupExecutionRuntime`;
- `ExecutionAuthorization`;
- `TrashMoving` / `FileManager.trashItem`;
- `RegisteredActionRunner`;
- `Process` or arbitrary shell execution;
- `StornautCodex` / `StornautLifecycle`.

`StornautCore` must retain no dependency on Codex/Lifecycle.

## 7. Benchmark

Add deterministic streaming and planner benchmarks. The source benchmark uses
exactly 300,002 generated source rows and exercises a checked 256 MiB payload
sum without retaining the payloads. The candidate benchmark uses at least
100,000 bounded policy-relevant rows. Both benchmark tests are excluded from
ordinary parallel and serial Swift suites. The authoritative full verifier
runs each one separately through its own
`swift test --no-parallel --filter <exact-test-name>` invocation; they may not
share a Swift test process with one another or with unrelated tests. Assert:

- bounded wall-clock target selected after a baseline measurement rather than
  guessed;
- deterministic output/fingerprint across repeated and shuffled input;
- bounded peak data shape with no full filesystem tree;
- no full source payload, canonical SourceProjection byte buffer or
  300,002-row manifest array;
- source projection completes within 60 seconds and stays below the normative
  192 MiB plus one 16 MiB current-payload incremental-memory limit on the
  recorded machine, using the kernel process-lifetime
  `ledger_phys_footprint_peak` high-water mark rather than periodic samples;
- cap at 512 admitted targets;
- no integer overflow or priority instability.

The benchmarks cover deterministic source projection and Candidate Planner
behavior only. They do not call Codex, scan the user's Home, or access private
data.

## 8. Explicit Non-Goals

- Evidence Store v4 migration;
- Investigation session/report persistence;
- Codex/runtime/lifecycle integration;
- Probe Broker execution;
- App Server direct-tool/token event parsing;
- App dependencies or SwiftUI;
- disclosure acceptance;
- Deep Dive availability changes;
- Cleanup Plan generation;
- Policy, selection, confirmation or Executor integration;
- real filesystem writes;
- Adapters or Registered Actions;
- provider/model selection.

## 9. Expected Files

Expected new/modified tracked files after Task 35 is complete:

```text
Sources/StornautCore/Domain/DomainPrimitives.swift
Sources/StornautCore/Domain/Evidence.swift
Sources/StornautCore/Investigation/InvestigationBudget.swift
Sources/StornautCore/Investigation/InvestigationPlan.swift
Sources/StornautCore/Investigation/InvestigationCandidatePlanner.swift
Sources/StornautCore/Investigation/InvestigationStopEvaluator.swift
Tests/StornautCoreTests/InvestigationDomainTests.swift
Tests/StornautCoreTests/InvestigationSourceProjectionTests.swift
Tests/StornautCoreTests/InvestigationBudgetTests.swift
Tests/StornautCoreTests/InvestigationCandidatePlannerTests.swift
Tests/StornautCoreTests/InvestigationStopEvaluatorTests.swift
Tests/StornautCoreTests/InvestigationPlannerBenchmarkTests.swift
Tests/Fixtures/Investigation/...
scripts/verify-investigation-boundaries
docs/upstream-studies/epic-6-investigation-planning.md
docs/adr/0017-investigation-planning-and-stop-semantics.md
docs/plans/active/task-36-implementation-brief.md
docs/reports/phase-d-task-36-review.md
docs/agent/coding-agent-handoff.md
docs/plans/active/README.md
docs/plans/roadmap.md
AGENTS.md
```

Exact filenames may follow current repo style, but write scope must remain
inside Core/tests/scripts/docs. No App or Codex production file is in scope.

## 10. Focused Validation

Run serially:

```text
swift test --filter InvestigationDomain
swift test --filter InvestigationBudget
swift test --filter InvestigationCandidatePlanner
swift test --filter InvestigationStopEvaluator
swift test --filter InvestigationPlannerBenchmark
scripts/verify-investigation-boundaries
scripts/check-doc-links
git diff --check
```

Then:

```text
swift test --no-parallel
scripts/verify --full
```

Use the repository's actual accepted test-product/build commands if the names
above need adaptation. Heavy SwiftPM/Xcode commands must not overlap.

## 11. Independent Review

Review the complete Task diff for:

- model-owned or prompt-owned authority;
- incorrect target source binding;
- optimistic missing-size behavior;
- floating-point/nondeterministic priority;
- arithmetic overflow;
- budget off-by-one;
- false hard-cap claims for event-time direct-tool/token usage;
- unavailable usage becoming zero or exact remaining capacity;
- token double-counting;
- stop precedence errors;
- Unknown becoming measured zero;
- accidental Store/App/runtime scope creep;
- Core dependency inversion;
- encoded action/Policy/authorization fields;
- stale docs or broken links.

Fix all P0–P2 findings and rerun affected focused checks before the final full
verifier.

## 12. Completion and Git

Task 36 completes only when:

- Upstream Study and ADR are checked in;
- tests were authored before implementation;
- focused tests and boundary verifier pass;
- benchmark passes;
- independent review has zero unresolved P0–P2;
- one uninterrupted authoritative `scripts/verify --full` exits `0`;
- docs accurately state Deep Dive remains unavailable;
- a docs-freshness audit verifies every referenced normative document, task
  dependency/status router, ownership/non-goal claim and product-availability
  claim matches the committed diff and canonical contract;
- `git diff --check`, docs links and credential/artifact hygiene pass;
- the Task has one independent commit with no Coding Agent co-author trailer;
- `GITHUB_TOKEN` and `GH_TOKEN` are unset before push;
- the commit is pushed to `origin/main`.
