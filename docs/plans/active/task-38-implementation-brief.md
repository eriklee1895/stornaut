# Task 38 Implementation Brief — Closed Investigation Coordinator with Fake Runtime

> **Status:** Approved; unblocked by completed Task 37. Next implementation
> Task from the pushed Task 37 baseline.
>
> **Parent plan:**
> [Phase D Conditional Deep Dive](phase-d-conditional-deep-dive.md)
>
> **Normative contract:**
> [Investigation Canonical v1](../../specs/investigation-canonical-v1.md).

## 1. Objective

Task 38 creates a closed, dependency-injected investigation coordinator:

```text
persisted admitted Investigation Plan
→ Store-owned source rejoin
→ bounded Swift context and prompt resource
→ injected fake contained runtime + Probe Broker
→ receipt-selected identity/event normalization
→ staged serial scientific loop
→ bounded interrupt and 140-second terminal settlement envelope
→ strict Envelope v2 normalization
→ atomic partial/final Store truth
→ lifecycle/artifact drain
```

It adds the `StornautInvestigation` SwiftPM module and its tests. It does not
call a real model, compose the signed App runtime, change App availability,
add UI, project Agent proposals into Review, or expose cleanup authority.

Completion requires tests-first state-machine and adversarial fixtures,
structural no-Executor verification, zero unresolved independent P0–P2
findings, one uninterrupted authoritative `scripts/verify --full` exit `0`,
and an independent commit/push.

## 2. Preconditions and Ownership

Task 38 begins only after Tasks 36–37 are independently committed and pushed.
It consumes, without duplicating:

- Task 36 domain, Plan, canonical codec, budget ledger and stop evaluator;
- Task 37 Store v4, source rejoin, terminal transaction and retention APIs;
- current `StornautCodex` strict Investigation Envelope v2 decoder;
- current `StornautLifecycle` audit-session drain contract;
- current Probe Broker and `ProbeSessionBudget`.

Task 38 alone owns:

- the product coordinator state machine;
- App Server wire-event decoding into Core-neutral observations;
- receipt-selected collaboration/tool schemas;
- root/descendant lineage and replay accounting;
- runtime interrupt/terminal barrier ordering;
- context compression and production prompt resource contract;
- orchestration of existing Store/runtime/lifecycle seams.

It does not own Store schema, capability diagnosis, signed-App composition,
disclosure, App state, UI or Review projection.

## 3. Module Boundary

Add:

```text
Sources/StornautInvestigation/
Tests/StornautInvestigationTests/
```

`StornautInvestigation` may depend only on:

- `StornautCore`;
- `StornautCodex`;
- `StornautLifecycle`;
- `StornautProbeBridge` if needed for the typed bridge protocol.

It must expose one closed public facade, tentatively:

```text
InvestigationRuntime
  prepare(...)
  start(...)
  requestPause(...)
  requestStop(...)
  cancel(...)
  recover(...)
  events(...)
```

Exact names may follow repo style. The operational facade accepts only typed
Investigation/run IDs, one Task 41/42-owned one-shot
`InvestigationStartAdmissionV1`, one Store-owned transaction entrypoint and
injected protocol owners. It never accepts a caller-supplied Plan, target
list, source fingerprint, expected manifest, freshness Boolean/token or
reusable Store admission handle. The coordinator cannot construct the
one-shot admission; it consumes it exactly once, including failed starts.
Immediately before `thread/start`, the Store-owned transaction:

1. validates the consumed admission's typed Investigation/run/source and
   exact receipt/disclosure/workflow/final-gate bindings without
   re-deciding those external facts;
2. loads the immutable run-owned Plan and ordered run-target membership;
3. strict-decodes/recomputes Plan, target-set and source fingerprints;
4. invokes the Task 37 runtime-admission source rejoin;
5. builds a non-escaping runtime context used only while that transaction
   closure remains valid.

The context cannot be constructed by App/runtime callers, persisted, replayed
or used after transaction closure. The facade never accepts or returns:

- `CleanupExecutionRuntime`;
- `ActionExecutor`;
- `ExecutionAuthorization`;
- `CleanupAction`;
- `RegisteredActionDefinition`;
- a filesystem mutation closure;
- arbitrary executable/shell arguments;
- arbitrary model/provider/CLI flags.

Store `noEligibleTargets` produces a typed non-start outcome. The facade must
not create a runtime thread, workspace, lifecycle lease or budget event for an
empty Plan.

No public initializer may let App code assemble a less-contained production
runtime. Task 39 later owns the diagnostic signed-App composition root; Task
44 owns a separate normal-product composition root after final admission.

## 4. Injected Protocols

### 4.1 Runtime

Define a closed injected runtime protocol whose fake implementation can:

- start one new ephemeral root thread only;
- emit typed App Server lines/events;
- accept bounded turn-start requests;
- accept at-most-once interrupt per active `(threadID, turnID)`;
- report exact runtime receipt and selected collaboration schema;
- expose terminal status;
- retire ephemeral artifacts.

Production never resumes, forks or reuses a stored runtime thread. A root
thread is valid only when `thread.id == thread.sessionId`.

The protocol does not expose raw process launch, environment mutation,
arbitrary CLI flags or auth projection to coordinator callers.

### 4.2 Lifecycle

Inject a lifecycle owner that:

- proves one admitted audit session/lease belongs to the Investigation/run;
- invokes idempotent complete-session drain;
- proves audit session and managed proxy owner empty;
- distinguishes proved drain, unproved drain and drain failure;
- exposes no generic process-kill API to App/UI callers.

### 4.3 Store

Use one typed protocol implemented by `EvidenceStore` for:

- run-owned Plan/session load;
- the Task 37 source rejoin barriers, invoked only with typed
  Investigation ID + closed barrier while the Store owns the pinned
  transaction and expected normalized manifest;
- aggregate budget event persistence under Task 37's `4,096` event / `4 MiB`
  per-run and `32 MiB` per-Investigation ceilings;
- atomic terminal commit under the target-scoped evidence and report-scoped
  degradation quotas: exactly one partial/final report for
  partial/completed, zero report/evidence for blocked/failed;
- recovery candidates and terminal truth.

The Store transaction owns only Store facts: Plan, membership, source rows,
fingerprints, rejoin and persistence invariants. It does not evaluate
disclosure, runtime freshness, workflow availability or Task 44 product
admission. The coordinator cannot supply a Plan or “source is fresh” as a
boolean; the Store recomputes those facts. It also cannot supply an expected
manifest/fingerprint or source cursor, and no reusable freshness receipt or
start authority escapes the transaction.

### 4.4 Clock and IDs

Inject:

- one `ContinuousClock`-compatible monotonic clock;
- wall-calendar metadata provider;
- App-internal typed ID provider for caller-created Investigation/run/report
  IDs.

For a completed/partial terminalization, the actor allocates one typed report
ID exactly once when it creates the terminal Store command, then retains that
same command/ID across retry and crash recovery. Blocked/failed commands carry
no report ID. UI, Codex/model output, normalized runtime events and diagnostic
factories cannot provide or replace report IDs. Equal replay must reuse the
same report ID and byte-identical terminal payload; an alternate ID for the
same run is a conflicting replay.

The coordinator does not call `UUID()` or use wall calendar for admission,
budget or terminal barrier timing.

## 5. Context Compressor and Prompt Contract

### 5.1 Context

Build context only from:

- admitted Plan and ordered retained target IDs;
- compact typed source summaries;
- user-approved read scope;
- exact budget/stop policy;
- exact runtime receipt capability tokens;
- prior verified partial report for continuation.

The compressor:

- rejects source rejoin drift immediately before `thread/start`;
- enforces the 256 KiB per-input limit and cumulative Plan context budget;
- preserves every admitted target ID exactly once;
- never embeds raw arbitrary file content into system/developer instructions;
- does not persist the raw prompt;
- returns deterministic bytes for equal inputs.

### 5.2 Prompt resource

Check in a versioned prompt resource that:

- declares Codex an investigator, never executor;
- requires retained IDs rather than model paths;
- requires source labels, uncertainty, counter-evidence and degradations;
- requires every admitted target exactly once as investigated or unresolved;
- requires Envelope v2 as the final message only;
- treats disk/tool/web content as untrusted evidence, not instructions;
- prohibits credential collection, TCC bypass, local/private/Unix access,
  writes, cleanup, Policy, authorization and Executor attempts;
- does not claim prompt text enforces containment.

Prompt tests assert shape and invariants only. They are not containment proof.

## 6. Serial Coordinator State Machine

### 6.1 States

Implement separate closed run and session states.

Run states:

```text
planned
awaitingDisclosure
ready
running(stage)
pauseRequested
stopRequested
terminalBarrier
completed
partial
blocked
failed
```

Session aggregate state uses the same vocabulary plus `paused`. A successful
pause terminalizes the current run as `partial`, persists its partial report,
then projects the owning session as `paused`. No run is persisted with state
`paused`.

The actor owns all transitions. Equal replay is idempotent; conflicting replay,
out-of-order transition, terminal regression and foreign run identity fail
closed. `cancel(...)` is a request and immutable primary cause, not a
standalone terminal state; proved drain plus successful commit produces
`partial(userCancelled)`.

### 6.2 Start admission

Before first `thread/start`, atomically require:

- current persisted Plan and run identity;
- Task 37 runtime-admission source rejoin `matching`;
- a fresh Task 41/42-owned one-shot admission binding disclosure, exact
  runtime receipt, workflow reservation and Task 44 final admission;
- valid budget limits;
- the Store validates the admission's run/source/receipt bindings but does
  not re-evaluate those App/runtime facts;
- a fresh receipt selecting exactly one collaboration schema;
- root thread is new/ephemeral;
- context reservation succeeds.

Task 38 consumes but cannot create the typed one-shot admission. Task 39
owns signed-runtime evidence; Task 41/42 own disclosure, current receipt,
workflow and Task 44 product-gate evaluation. A workflow reservation held
by the one-shot admission prevents conflicting mutation through
`thread/start` settlement.

### 6.3 Scientific loop

For each serial step:

1. evaluate safety and Task 36 stop precedence;
2. reserve turn/context and Probe resources before owned work;
3. start at most one admitted model turn;
4. normalize only identity-valid events;
5. accept evidence only after its source turn terminal event;
6. update coverage, unresolved targets, verified gain and budget ledger;
7. persist aggregate events;
8. decide next stage/turn or close scientific admission.

Codex may propose next work but cannot increase limits, reorder Swift-owned
targets authoritatively, reset counters or override stop.

### 6.4 Pause, stop and cancel

Pause is cooperative cancel-and-continue:

```text
pause requested
→ finish or bounded-interrupt current admitted turn
→ observe matching terminal event
→ drain complete audit session
→ persist current run as partial with verified partial report
→ project session aggregate as paused
```

Resume is not process/thread resume. It creates a new run identity through the
Task 37 continuation contract.

User stop records distinct immutable `userStopped`, closes later admission
and preserves only verified evidence. After the terminal barrier and Store
commit it produces `partial(userStopped)`; a later final event cannot
overwrite it. User cancel has the higher Task 36 precedence, records
`userCancelled` and produces `partial(userCancelled)`. Neither request is a
standalone persisted terminal state or may expose terminal App truth before
the barrier and commit.

## 7. Receipt-Selected Runtime Event Normalization

### 7.1 Receipt schema

One admitted receipt selects exactly one:

```text
collab-tool-call-v1
collab-agent-tool-call-v1
```

and its exact closed direct-tool item set from the canonical spec. Runtime
events are rejected if they use the non-selected schema, mix schemas, omit the
receipt identity or conflict with selected tool spellings.

### 7.2 Lineage

Maintain one actor-owned lineage graph:

- root `thread.id == thread.sessionId`;
- child admitted only after the receipt-selected collaboration spawn edge;
- child `parentThreadId` and root `sessionId` must match;
- every turn/item belongs to one admitted thread/run;
- unknown, orphan, cyclic, foreign or post-terminal lineage blocks;
- finalization rejects any live or unclassified descendant.

### 7.3 Direct-tool observations

Count only the first valid `item/started` for unique:

```text
(threadID, turnID, itemID)
```

when the type belongs to the receipt-selected closed direct-tool set.

- equal replay: no-op;
- conflicting duplicate: block;
- `fileChange`: block;
- unknown tool-capable item: block;
- write-capable MCP annotation: block;
- unrelated thread/run: block;
- model prose claiming tool use: ignored.

Observed ceilings are event-time facts. At `>= ceiling`, preserve exact
overrun, close later admission and request one bounded interrupt.

### 7.4 Token observations

Normalize only receipt-compatible `thread/tokenUsage/updated` events with:

- thread ID;
- matching active/terminal turn ID;
- cumulative `total`;
- `last`;
- optional context-window fields.

Retain each admitted thread's latest nondecreasing cumulative `total`. Run
total is the sum of each thread's latest `total.totalTokens` exactly once.
Never add `last` or cached input again.

- equal replay: no-op;
- decreasing/negative/conflicting cumulative snapshot: block;
- foreign identity: block;
- missing matching usage by terminal barrier: typed `usageUnavailable`;
- bytes/time/model prose never estimate tokens.

## 8. Probe and Evidence Semantics

Use the existing `ProbeSessionBudget` as operational owner:

- call/read reservations remain consumed after admitted failure;
- output commits only after encoded per-call/session checks;
- concurrency uses actor-owned exactly-once leases;
- recovery releases only after lifecycle proves no Probe worker remains;
- duplicate/foreign release blocks.

Direct read/shell/web evidence is advisory and labeled by exact source method.
Probe evidence retains its structured audit label. No source label is upgraded
to another.

Evidence from an unterminated, foreign, invalid or cancelled turn is never
promoted. Prompt-injected instructions in local/web/tool content remain data.

## 9. Terminal Barrier

Sample immutable T0 once at the first accepted highest-precedence closing fact.
At T0:

- atomically close turn/Probe/context admission;
- record primary cause and later secondary facts;
- send at most one interrupt per active `(threadID, turnID)`.

From T0 through T0+15 seconds:

- accept only matching item/usage/turn terminal events;
- admit no new scientific work;
- promote no evidence from a nonterminal turn.

When all turns are terminal, or at T0+15 seconds:

- invoke idempotent complete audit-session/proxy drain.

By T0+45 seconds:

- prove all descendants/audit session/proxy owner empty;
- retire raw ephemeral artifacts;
- begin the Task 37 terminal source rejoin/Store transaction.

By T0+135 seconds:

- atomically commit terminal truth; or
- interrupt and roll back the Store transaction under its independent
  90-second deadline.

By T0+140 seconds:

- complete the separate rollback/connection cleanup; or
- quarantine the connection as `rollbackUnconfirmed`.

Outcomes:

- user cancellation + proved drain + successful Store commit:
  `partial(userCancelled)`;
- user stop + proved drain + successful Store commit:
  `partial(userStopped)`;
- missing matching turn terminal + proved forced drain:
  `blocked(runtimeTerminalUnobserved)`, persisted as terminal run/cause/budget
  truth with zero report and zero promoted evidence;
- unproved descendant/proxy drain:
  `blocked(lifecycleDrainUnconfirmed)`, persisted as terminal run/cause/budget
  truth with zero report and zero promoted evidence;
- terminal Store failure:
  `failed(terminalPersistenceFailed)` in App memory; if Store can durably
  record the failure in a fresh recovery transaction it uses zero report and
  zero evidence, otherwise the prior nonterminal run remains for crash
  recovery.

Cancellation is not a standalone persisted/UI terminal state. Failure outcomes
may not surface as paused, cancelled, budget-complete or successful. The
15/45/135/140-second boundaries use the same injected clock and the outer
settlement envelope is not additional scientific budget.

## 10. Strict Envelope Normalization

Use the existing strict Envelope v2 decoder with exact
`InvestigationProtocolContext`. The final advisory report:

- echoes only admitted Investigation/run/target/proposal IDs;
- contains no path/action/Policy/authorization/command fields;
- labels evidence source and uncertainty;
- covers every admitted target exactly once as investigated or unresolved;
- reports capability degradation;
- remains advisory and non-executable.

Target-scoped finding/proposal/counter-evidence/unresolved rows retain a
mandatory target ID. Run/report-wide capability, usage or source degradation
uses Task 37 `investigation_report_degradations` with a closed degradation
kind and no synthetic target association. Both families are checked against
their independent row/aggregate-byte quotas before atomic terminal commit.

Normalization joins IDs against the actor-owned admitted map, budget ledger
and source receipt. A valid schema with forged/foreign IDs is rejected.
Malformed final output may yield a truthful partial/blocked result but never
fabricated findings.

## 11. Crash Recovery and Artifacts

Recovery:

- loads nonterminal runs from Store v4;
- never resumes/forks a prior runtime thread;
- invokes lifecycle recovery/drain;
- proves no descendant/Proxy/Probe lease remains;
- retires ephemeral artifacts within the existing maximum 24-hour contract;
- promotes only evidence already verified and terminally persisted;
- creates a typed blocked/partial truth;
- requires a new run identity for continuation.

Normal terminal paths delete raw JSONL/runtime workspaces immediately after
truth is safely committed. Failure to retire artifacts is a typed terminal
failure/degradation; it is not silently ignored.

## 12. Tests First

Write failing tests and fixtures before implementation.

### 12.1 State/admission

- valid fresh start;
- stale/expired/corrupt source at runtime admission;
- duplicate/concurrent start;
- invalid disclosure/runtime receipt input;
- context N−1/N/N+1 and cumulative bounds;
- no UUID/system-clock dependency;
- illegal/out-of-order/terminal-regression transitions;
- source drift at explicit refresh.

### 12.2 Runtime lineage/events

- both receipt schemas independently;
- mixed/non-selected schema rejection;
- root identity;
- valid nested descendants/subagents;
- orphan/cycle/foreign/post-terminal child rejection;
- direct-tool exact-once replay/conflict;
- `fileChange`, unknown tool and write-capable MCP block;
- cumulative per-thread token aggregation;
- cached input/`last` not double-counted;
- decreasing/negative/conflicting/mismatched usage block;
- usage unavailable;
- complete live-tree observed ceiling and exact overrun.

### 12.3 Budgets/stop/pause

- every hard dimension N−1/N/N+1;
- Probe reserve/commit/release failure paths;
- observed ceiling prevents later turn;
- all Task 36 stop precedence combinations;
- no-gain;
- pause drains and creates verified partial;
- continuation uses new run;
- stop/cancel preserve only verified evidence.

### 12.4 Terminal barrier

- all turns terminal before 15 seconds;
- missing terminal until 15 seconds then drain;
- exact T0/T0+15/T0+45/T0+135/T0+140 boundaries with injected clock;
- one interrupt per active turn;
- no later admission;
- matching late usage accepted within window;
- unrelated late event rejected;
- proved forced drain + missing terminal classification;
- unproved drain classification;
- terminal persistence failure;
- no terminal state before drain/artifact retirement/Store commit.

### 12.5 Protocol/evidence/adversarial

- valid Envelope v2;
- malformed/unknown/duplicate fields;
- prompt-injection fixture;
- forged target/run/proposal ID;
- path/action/Policy/authorization field impossible;
- incomplete target coverage;
- false source label;
- capability degradation;
- evidence from unterminated/cancelled turn rejected.

### 12.6 Recovery/artifacts

- normal raw artifact deletion;
- crash residue recovery;
- no runtime thread resume;
- no evidence replay/promotion;
- Probe lease recovery only after proved drain;
- idempotent recovery;
- report ID allocated once by the App-internal provider, reused on equal
  replay/recovery, with alternate-ID and blocked/failed-ID rejection;
- 24-hour stale residue handling.

### 12.7 Structural

Extend `scripts/verify-investigation-boundaries` across:

- `Sources/StornautInvestigation`;
- `Sources/StornautCodex`;
- lifecycle helpers;
- prompt resources;
- future App Investigation sources.

Reject references/construction for Executor, Trash, authorization, action
registry/runner, arbitrary process execution and filesystem mutation.

## 13. Expected Files

```text
Package.swift
Sources/StornautInvestigation/InvestigationRuntime.swift
Sources/StornautInvestigation/InvestigationCoordinator.swift
Sources/StornautInvestigation/InvestigationRuntimeProtocols.swift
Sources/StornautInvestigation/InvestigationEventNormalizer.swift
Sources/StornautInvestigation/InvestigationContextCompressor.swift
Sources/StornautInvestigation/InvestigationTerminalBarrier.swift
Sources/StornautInvestigation/Resources/investigation-prompt-v1.txt
Tests/StornautInvestigationTests/InvestigationCoordinatorTests.swift
Tests/StornautInvestigationTests/InvestigationEventNormalizerTests.swift
Tests/StornautInvestigationTests/InvestigationTerminalBarrierTests.swift
Tests/StornautInvestigationTests/InvestigationRecoveryTests.swift
Tests/Fixtures/InvestigationRuntime/...
scripts/verify-investigation-boundaries
docs/plans/active/task-38-implementation-brief.md
docs/reports/phase-d-task-38-review.md
docs/agent/coding-agent-handoff.md
docs/plans/active/README.md
docs/plans/roadmap.md
AGENTS.md
```

Exact filenames may follow repo style. App/Xcode project source is out of
scope except package product visibility needed by later Tasks.

## 14. Focused Validation

Run serially:

```text
swift test --filter InvestigationCoordinator
swift test --filter InvestigationEventNormalizer
swift test --filter InvestigationTerminalBarrier
swift test --filter InvestigationRecovery
swift test --filter InvestigationEnvelopeV2
swift test --filter ProbeBroker
swift test --filter Lifecycle
scripts/verify-investigation-boundaries
scripts/check-doc-links
git diff --check
```

Then:

```text
swift test --parallel false
scripts/verify --full
```

No real Codex/model diagnostic belongs to Task 38.

## 15. Independent Review

Review for:

- a second execution/authorization path;
- raw process/runtime construction exposed to App;
- mixed receipt schemas or incomplete direct-tool set;
- descendant/root identity escape;
- replay/token double counting;
- observed ceilings falsely claimed hard-preemptive;
- late/unterminated evidence promotion;
- incorrect T0/15/45/135/140 ordering;
- terminal state before complete drain and Store commit;
- source rejoin skipped at runtime/terminal/recovery/continuation;
- raw prompt/event/artifact persistence;
- prompt text treated as containment;
- continuation resuming an old thread;
- Task 39/40/41/42/43 scope creep;
- stale docs/broken links.

Fix all P0–P2 findings and rerun affected checks before the final full
verifier.

## 16. Explicit Non-Goals

- real Codex/model call;
- signed-App runtime composition or receipt admission;
- current capability/integrity diagnostic;
- first-use disclosure persistence/UI;
- App workflow/navigation/UI;
- Review projection or Cleanup Plan;
- production Deep Dive availability;
- Store migration changes beyond Task 37 APIs;
- Trash, Policy, authorization, Executor or Registered Actions;
- release/notarization/distribution.

## 17. Completion and Git

Task 38 completes only when:

- fake-runtime success/failure/recovery matrix passes;
- receipt-selected full-tree accounting and terminal barrier pass;
- raw artifacts are deleted/recovered as specified;
- structural no-Executor verifier passes;
- independent review has zero unresolved P0–P2;
- one uninterrupted authoritative `scripts/verify --full` exits `0`;
- docs keep production Deep Dive unavailable;
- a docs-freshness audit verifies every referenced normative document, task
  dependency/status router, ownership/non-goal claim and product-availability
  claim matches the committed diff and canonical contract;
- docs links, credential/artifact hygiene and `git diff --check` pass;
- one independent commit has no Coding Agent co-author trailer;
- `GITHUB_TOKEN` and `GH_TOKEN` are unset before push;
- `HEAD == origin/main` after push.
