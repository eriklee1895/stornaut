# Task 42 Implementation Brief — App Investigation Workflow and Recovery State

> **Status:** Approved; blocked on pushed Task 41 baseline.
>
> **Parent plan:**
> [Phase D Conditional Deep Dive](phase-d-conditional-deep-dive.md)

## 1. Objective

Task 42 integrates the closed Task 38 Investigation facade into App-owned
state and dependency orchestration:

```text
normal start intent
→ typed Task 41 admission dimensions
→ latest valid Quick Scan or baseline Quick Scan transition
→ one App-owned Investigation actor/single flight
→ staged events, budget, pause/stop/cancel
→ Task 38 matching terminal barrier
→ atomic Store truth
→ partial/final/recovery App state
```

Task 42 does not replace the Investigations placeholder with production UI and
does not remove the final product feature gate. It builds and tests the App
workflow behind injected/debug fixtures only. Task 43 consumes the state for
UI; Task 44 alone enables normal production start.

## 2. Preconditions and Reuse

Task 42 starts after Tasks 36–41 are independently committed and pushed. It
must reuse:

- Task 36 Plan/budget/stage/stop contracts;
- Task 37 Store v4 source/terminal/continuation truth;
- Task 38 closed `StornautInvestigation` facade/events/terminal barrier;
- Task 39 current signed runtime admission projection;
- Task 40 report/Review/continuation projection;
- Task 41 disclosure/admission dimensions;
- current `StornautAppModel`, `AppDependencies` and workflow exclusions;
- current Quick Scan, Review/cleanup, History and Settings state owners.

It must not create a second coordinator, runtime runner, source rejoin, Store,
receipt verifier or disclosure store.

## 3. App Dependency Boundary

### 3.1 Closed dependency

Add one App-facing `InvestigationDependencies` value with closures for:

- load latest usable Quick Scan source;
- run baseline Quick Scan using the existing Quick Scan dependency;
- evaluate Task 41 admission dimensions and the explicit Task 44 final
  product gate;
- present/obtain typed disclosure result;
- create one actor-owned, memory-only, exactly-once
  `InvestigationStartAdmissionV1` binding Investigation/run/source,
  disclosure version, exact runtime receipt, workflow reservation and
  `admittedByTask44`;
- construct/start the already-closed Task 38 facade with that admission;
- consume typed Investigation events;
- request pause/stop/cancel;
- create continuation from a verified partial record;
- load report/history projection;
- route eligible deterministic rows to existing Review.

It must not expose:

- raw Codex process/runtime/profile/environment;
- helper/XPC generic operations;
- Executor/Trash/authorization/action types;
- arbitrary paths/commands/CLI flags;
- a caller-supplied “receipt is valid” boolean.

Normal production dependencies remain feature-gated. DEBUG fixtures may inject
fake Task 38 runtime/events but cannot bypass reducer invariants.

### 3.2 One actor owner

Add one App-owned actor or equivalent serial owner for:

- active Investigation ID/run ID;
- current facade/session stream;
- start generation;
- cancellation/pause/stop requests;
- one terminal acceptance;
- continuation generation;
- recovery flight.

`StornautAppModel` remains `@MainActor` presentation owner, but it cannot race
multiple async streams or accept a terminal event from an old generation.

## 4. Workflow Exclusion

### 4.1 Conflicts

Investigation cannot start while any is active:

- Quick Scan;
- Review loading/preflight;
- cleanup execution;
- mutating History deletion/clear;
- mutating Settings root/exclusion/preferences/data/knowledge operation;
- another Investigation/start/recovery/continuation.

While Investigation is active:

- Quick Scan start is disabled;
- Review cleanup start/preflight is disabled;
- mutating History/Settings operations are disabled;
- read-only History/report inspection remains allowed if it cannot alter the
  active source;
- Settings status inspection remains allowed;
- no background start/scheduler is created.

Use one shared workflow coordinator or exact App-level single-flight contract.
Do not replicate conflicting flags inconsistently across methods.

### 4.2 Authority consumption

The admission/disclosure/start intent and its one-shot
`InvestigationStartAdmissionV1` are actor-owned, memory-only and consumed by
the first start attempt, including failure. The value is not a reusable
Boolean or freshness token; it binds exact run/source/disclosure/receipt,
workflow reservation and Task 44 final admission. It cannot be replayed
after drift, copied into persistence or survive App restart.

## 5. Baseline Quick Scan Chaining

### 5.1 Existing usable baseline

Start directly from the latest source only if:

- the shared canonical `InvestigationSourceEligibilityV1` passes: the Scan is
  terminal `completed`, `partial` or existing Quick Scan `cancelled`, is not
  failed, and the selected primary scope appears exactly once in
  `completedScopes`, `unfinishedScopes` is empty, and the exact same-session
  Space Ledger is `reconciled` with zero `coverageGaps`, measured-zero
  unmeasurable bytes and `unknownIncludesUnmeasurable == false`;
- source retention/currentness and Task 37 exact projection/rejoin pass;
- no corrupt/expired/missing required rows;
- selected budget and Task 41 dimensions are valid.

Task 42 does not implement a second completed-only baseline predicate.

### 5.2 Missing/stale baseline

If no usable source:

```text
start Deep Dive intent
→ state .preparingBaseline
→ run the same existing Quick Scan coordinator
→ show Quick Scan stages as baseline work
→ receive one terminal projection
→ freshly evaluate all admission dimensions
→ ask Task 37 Store to create the Investigation + initial run-owned Plan
→ start only if still admitted
```

The App does not ask the user to navigate away and retry manually. A baseline
partial/cancelled outcome is re-evaluated by the same shared predicate: it may
proceed only when the selected primary scope completed, no unfinished scope
exists, and the retained Space Ledger has zero permission/boundary coverage
gaps. Phase D has one selected primary root, so v1 has no secondary-scope
exception. Failed, unfinished-primary, permission/boundary-limited or
otherwise non-rejoinable outcomes preserve valid Scan state and block
Investigation with the exact typed
`InvestigationSourceEligibilityV1` reason.

It must not interpret missing/limited bytes as zero or silently switch roots.

### 5.3 Source changes

Any Quick Scan/root/exclusion mutation after intent but before Task 38
`thread/start` invalidates the pending start. The Task 37 runtime-admission
rejoin remains authoritative.

## 6. App Investigation State

Add a closed `InvestigationState` and reducer. Suggested phases:

```text
idle
checkingAdmission
awaitingDisclosure
preparingBaseline
planning
ready
starting
running
pauseRequested
stopRequested
cancelling
terminalizing
paused
partial
completed
blocked
failed
recovering
```

State retains only truthful typed values:

- Investigation/run/report/Plan IDs;
- source Scan session/scope;
- current stage;
- current retained target ID and bounded summary;
- coverage/Unknown metrics;
- budget ledger projection with hard/observed/unavailable quality;
- verified evidence/findings count;
- unresolved/degradation summaries;
- primary and secondary terminal causes;
- continuation eligibility;
- last valid partial/final report.

Safety blocked before runtime start shows no stages as started, no explained
gain and no finding count. Page-preserving errors retain prior valid report
but mark the affected current run.

## 7. Event and Generation Admission

Every event from Task 38 must match:

- current App start generation;
- Investigation ID;
- run ID;
- source/plan fingerprint;
- Task 38 serial coordinator ordinal;
- expected event phase.

Equal replay may be ignored. Foreign, stale, out-of-order or conflicting
events fail/are ignored according to whether they indicate coordinator
corruption; they never overwrite a newer run.

Progress events update UI only before one accepted terminal truth. Once
terminalizing begins, only matching Task 38 barrier/lifecycle/persistence
events are accepted.

## 8. Terminal UI Admission

The App may display `paused`, `partial`, `completed`, `blocked` or `failed`
only after Task 38 proves:

- all admitted active turns have matching terminal events or the exact
  `runtimeTerminalUnobserved` classification;
- the T0+15 collection/drain ordering completed;
- complete audit session and managed proxy owner drain is proved, or exact
  `lifecycleDrainUnconfirmed` block is persisted;
- all Probe leases/artifacts are terminal/recovered;
- Task 37 terminal source rejoin ran;
- one atomic terminal Store transaction committed;
- the App loaded that exact persisted terminal record.

The exact timing contract is T0+15 for terminal-event collection, T0+45 for
complete lifecycle/artifact drain plus Store transaction start, T0+135 for
terminal commit, and T0+140 for rollback/connection cleanup or quarantine.
`paused` is an App/session aggregate projection over a persisted `partial` run
and partial report; it is never a persisted run state.

`cancelling` is request-only. A successfully drained and committed cancelled
run displays canonical `partial` with primary cause `userCancelled`; a drain or
persistence failure displays its canonical blocked/failed outcome. There is no
standalone terminal `cancelled` state.

An in-memory model callback, `turn/completed` alone, process exit alone or
stream end alone cannot produce terminal UI.

Terminal persistence failure yields failed state and no promoted report.
Unverified partial events remain absent.

## 9. Pause, Resume, Stop and Cancel

### 9.1 Pause

`Pause`:

- is available only while running at an allowed coordinator state;
- requests Task 38 cooperative close/interruption;
- enters `pauseRequested`/`terminalizing`;
- waits for full barrier/drain/partial commit;
- ends in `paused` only with a verified persisted partial run/report and
  matching session aggregate state.

### 9.2 Resume

`Resume`:

- is available only from a verified paused/partial report;
- invokes Task 40 continuation planning;
- uses a new run ID and fresh Task 41 admission;
- performs Task 37 continuation rejoin;
- starts a new ephemeral runtime thread;
- never resumes/forks old runtime state.

### 9.3 Stop

User stop records the distinct immutable `userStopped` primary cause and
requests a graceful verified partial through Task 38. After drain and
atomic commit the result is `partial(userStopped)`; a later final event
cannot overwrite it. Stop cannot skip the terminal barrier.

### 9.4 Cancel

Cancel has Task 36 precedence:

- closes later admission;
- interrupts/drains;
- preserves verified prior evidence;
- records `userCancelled` as the immutable primary cause;
- reports canonical `partial(userCancelled)` only after terminal commit;
- cannot be changed to success because a final model message arrives late.

## 10. Recovery

On App launch/refresh, one recovery flight:

1. loads nonterminal Store v4 Investigation sessions;
2. invokes Task 38 recovery/drain;
3. proves descendant/proxy/Probe/artifact state;
4. promotes only already verified/persisted evidence;
5. commits exact blocked/partial truth;
6. loads that truth into App state;
7. offers continuation only when allowed.

Recovery never:

- resumes a stored thread;
- retries a model turn automatically;
- fabricates a final report;
- starts in background;
- modifies source files;
- calls cleanup.

Multiple/replayed recovery attempts are idempotent and single-flight.

## 11. Report and Review Routing

From a verified partial/final report:

- open Investigation detail/history;
- start a typed continuation when eligible;
- route deterministic eligible rows to the existing Scan-owned Review flow;
- preserve Agent-only rows as unselected non-executable Review Recommended;
- invoke no cleanup action directly.

Task 42 adds route/state seams only. Task 43 supplies Investigations UI and
Task 44 validates the full normal product route.

## 12. Tests First

### 12.1 Admission/baseline

- usable latest Quick Scan starts planning;
- absent baseline chains existing Quick Scan;
- `completed`, `partial` and existing Quick Scan `cancelled` baselines each
  proceed only when the selected primary scope is exactly completed,
  `unfinishedScopes` is empty, the Space Ledger is reconciled with zero
  coverage gaps/measured-zero unmeasurable bytes, current and exactly
  rejoinable;
- stale, failed, corrupt/non-rejoinable, or partial/cancelled baselines with
  any unfinished scope block with the precise typed reason;
- primary-scope permission denial and contradictory completed-primary plus
  permission/boundary `coverageGap` fixtures both block; a non-primary-scope
  exception does not exist in v1 because one Investigation has one selected
  primary root;
- every closed eligibility reason
  (`terminalStateIneligible`, `primaryScopeMissingOrDuplicate`,
  `primaryScopeUnfinished`, `permissionOrBoundaryLimited`, `sourceExpired`,
  `sourceMissing`, `sourceCorrupt`, `sourceStale`) maps to one recovery state;
- source/root/exclusion drift invalidates;
- disclosure/runtime/dependency/workflow/budget dimensions independently;
- start intent consumed once;
- no stale snapshot start.

### 12.2 Single flight/conflicts

- concurrent start requests;
- Investigation vs Scan;
- Investigation vs Review/cleanup;
- Investigation vs History mutation;
- Investigation vs Settings mutation;
- read-only Settings/History inspection allowed;
- generation invalidates stale async completion;
- no background/scheduled start.

### 12.3 Reducer/events

- all phases and legal transitions;
- four stages;
- current target/budget/coverage metrics;
- observed/unavailable usage quality;
- stale/foreign/out-of-order/conflicting events;
- safety blocked before start has zero false metrics;
- page-preserving prior report on later failure.

### 12.4 Terminal truth

- stream end alone insufficient;
- process exit alone insufficient;
- `turn/completed` alone insufficient;
- exact barrier + drain + Store commit admits terminal;
- runtime terminal unobserved block;
- lifecycle drain unconfirmed block;
- terminal persistence failure;
- duplicate terminal ignored;
- late success cannot overwrite `partial(userCancelled)`/block;
- no evidence promotion before turn terminal.

### 12.5 Pause/resume/stop/cancel

- pause waits for verified partial;
- pause failure not shown paused;
- resume creates new run/root thread;
- continuation source rejoin;
- stop terminalizes;
- cancel precedence and partial preservation;
- no old-thread resume;
- no start if fresh admission changed.

### 12.6 Recovery

- one abandoned running session;
- multiple sessions deterministic handling;
- complete drain;
- unproved drain;
- artifact residue;
- idempotent repeated recovery;
- no model replay;
- no background continuation;
- valid partial remains available.

### 12.7 Structural

- App state/views do not reference Executor/Trash/authorization;
- dependencies expose no raw Codex/process/XPC generic surface;
- only Task 38 facade owns runtime state machine;
- normal production feature gate remains false;
- DEBUG fixture cannot bypass terminal admission.

## 13. Expected Files

```text
StornautApp/AppState/AppDependencies.swift
StornautApp/AppState/StornautAppModel.swift
StornautApp/Investigations/InvestigationState.swift
StornautApp/Investigations/InvestigationReducer.swift
StornautApp/Investigations/InvestigationModel.swift
StornautApp/Investigations/AppInvestigationCoordinator.swift
StornautApp/AppShell/AppDestination.swift
StornautAppTests/InvestigationStateTests.swift
StornautAppTests/InvestigationAppModelTests.swift
StornautAppTests/InvestigationWorkflowTests.swift
StornautAppTests/InvestigationRecoveryTests.swift
scripts/verify-investigation-boundaries
docs/plans/active/task-42-implementation-brief.md
docs/reports/phase-d-task-42-review.md
docs/agent/coding-agent-handoff.md
docs/plans/active/README.md
docs/plans/roadmap.md
AGENTS.md
```

Task 42 may add a minimal non-production fixture host/probe for tests but must
not replace the Investigations placeholder or add final visual design.

## 14. Focused Validation

Run serially:

```text
swift test --filter InvestigationCoordinator
xcodebuild ... -only-testing:StornautAppTests/InvestigationStateTests
xcodebuild ... -only-testing:StornautAppTests/InvestigationAppModelTests
xcodebuild ... -only-testing:StornautAppTests/InvestigationWorkflowTests
xcodebuild ... -only-testing:StornautAppTests/InvestigationRecoveryTests
scripts/verify-investigation-boundaries
scripts/check-doc-links
git diff --check
```

Then:

```text
swift test --parallel false
scripts/verify --full
```

No actual normal UI start or real-model run is required in Task 42.

## 15. Independent Review

Review for:

- duplicated coordinator/runtime/Store logic;
- stale snapshot start;
- workflow race/single-flight escape;
- disclosure/receipt/start authority replay;
- false progress/metrics before start;
- terminal UI before full barrier/drain/commit;
- cancellation overwritten by late success;
- pause claiming process suspension;
- resume using old runtime thread;
- unverified evidence promotion;
- recovery replaying work;
- normal feature gate removed early;
- cleanup authority leakage;
- Task 43 UI scope creep;
- stale docs/broken links.

Fix all P0–P2 findings and rerun affected checks before final full verification.

## 16. Explicit Non-Goals

- final Investigations workspace visuals;
- normal production Deep Dive availability;
- changing signed runtime diagnostic;
- changing Store schema/domain contracts;
- new report projection semantics;
- Cleanup Plan/Policy/selection/authorization/execution;
- system permission changes;
- adapters/Registered Actions;
- release work.

## 17. Completion and Git

Task 42 completes only when:

- baseline chaining, single flight and all terminal/recovery contracts pass;
- partial evidence remains truthful and available;
- continuation uses a new run identity;
- normal product Deep Dive remains feature-gated;
- structural boundaries pass;
- independent review has zero unresolved P0–P2;
- one uninterrupted authoritative `scripts/verify --full` exits `0`;
- a docs-freshness audit verifies every referenced normative document, task
  dependency/status router, ownership/non-goal claim and product-availability
  claim matches the committed diff and canonical contract;
- docs links, credential/artifact hygiene and `git diff --check` pass;
- one independent commit has no Coding Agent co-author trailer;
- `GITHUB_TOKEN` and `GH_TOKEN` are unset before push;
- `HEAD == origin/main` after push.
