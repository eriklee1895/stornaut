# Task 35 Implementation Brief — Signed-App Trash Evidence and Phase C Gate

> Status: Complete and archived; signed evidence recovered, mutation sealed,
> independent review clean and authoritative full verifier passed
>
> Date: 2026-08-14
>
> Baseline:
> `26a46dcd9d3711ec56ec63398bbc4c789a6ca775`
>
> Parent plan:
> [Epic 8 Safe Execution Vertical Slice](epic-8-safe-execution-vertical-slice.md)
>
> Accepted inputs:
> [ADR 0006](../../adr/0006-trash-and-registered-actions.md),
> [ADR 0011](../../adr/0011-review-policy-authorization.md),
> [ADR 0012](../../adr/0012-cleanup-execution-journal.md),
> [Task 34 Review](../../reports/epic-8-task-34-review.md) and the user's
> explicit authorization for this Task's bounded signed-App real Trash
> diagnostic.

## 1. Objective

Task 35 closes the deterministic Phase C vertical slice only after proving
that the current locally signed Debug App can execute the existing product
flow with Foundation Trash:

```text
diagnostic-owned exact fixture
→ Quick Scan
→ Cleanup Plan
→ Review selection
→ fresh Policy preflight
→ exact confirmation
→ one-shot authorization
→ per-item fresh Policy and ActionPolicy revalidation
→ FileManager.trashItem
→ execution journal
→ immutable Manifest
→ Cleanup Result and History projection
```

The real operation is authorized only for one uniquely marked, disposable
fixture created for the diagnostic. It must never reuse or open the user's
actual npm, pip, uv, Go or other cache. It must never permanently delete,
empty Trash, launch a Registered Action or retry an uncertain write.

Task 35 is complete only when:

- a closed Core runtime composes the existing collector, pure Policy,
  one-shot authorization controller and serial execution coordinator without
  exposing authority construction to the App;
- only the strict signed-App DEBUG diagnostic can inject the real Trash
  runtime; ordinary `.live()` and `.production()` composition remain
  `writeDisabled` after this evidence gate;
- the one authorized diagnostic attempt proves exact fixture identity and
  exact attempt cardinality; if post-write finalization fails after the
  filesystem move, a separately signed recovery-only App may finalize the
  existing journal/Manifest and restore the exact fixture without invoking
  Executor or replaying an action;
- a privacy-safe checked receipt binds the original diagnostic, recovery
  report, final Evidence Store, current safety-critical sources and exact
  terminal accounting;
- Release has no diagnostic argument, config marker or harness;
- deterministic fake end-to-end fixtures and the signed-App diagnostic both
  pass;
- bounded planning/Policy benchmarks and the complete Phase C scope audit
  pass;
- independent review has zero unresolved P0–P2 findings;
- one uninterrupted authoritative `scripts/verify --full` owns the Phase C
  gate and exits zero without invoking another mutation;
- Phase C plans are archived, documentation is fresh and the Task is committed
  and pushed independently.

## 2. Authorization Boundary

The user's explicit authorization covers exactly:

- one current-build, locally signed Debug `Stornaut.app`;
- one absolute diagnostic config supplied through the checked-in harness;
- one newly created, uniquely marked temporary Primary Scan Root;
- one exact-rule-shaped `.npm/_cacache` fixture beneath that root;
- one real `FileManager.trashItem` attempt through the product coordinator;
- one identity-checked restore attempt for that same marked fixture.

The authorized mutation budget was consumed by the recorded attempt on
2026-08-15. That attempt is final even though a post-write Manifest timestamp
defect prevented the original diagnostic from reporting ready. No second
Trash attempt is allowed. The only permitted follow-up was a bounded,
separately signed recovery-only launch over the retained journal and exact
returned destination. It used a deny-only executor and proved zero executor
invocations before restoring the fixture.

It does not cover:

- any pre-existing user file or directory;
- the real `~/.npm`, `~/Library/Caches/pip`,
  `~/Library/Caches/go-build`, uv cache or another developer cache;
- a second write after an uncertain first outcome;
- permanent deletion, `removeItem`, Empty Trash or Trash cleanup;
- a normal UI restore feature;
- a Registered Action, shell cleanup or arbitrary executable;
- TCC, FDA, Accessibility, Event Synthesizing or Automation Mode changes;
- release signing, notarization or distribution.

If any marker, root, identity, App/build binding, Policy fact, receipt or
postcondition is missing or mismatched, the diagnostic fails closed before a
write. If the Trash call has an uncertain result, no automatic retry or restore
is attempted.

Both mutation harnesses are now sealed by the checked receipt. Their scripts
exit before build, launch or filesystem mutation when the receipt exists. All
remaining repository gates validate the receipt and, when supplied locally,
the retained raw evidence read-only.

## 3. Closed Runtime Composition

### 3.1 `CleanupExecutionRuntime` is the only new public execution facade

Add a public actor in `StornautCore` that owns:

- one `CleanupPolicyContextCollector`;
- one `CleanupPolicyGate`;
- one `CleanupAuthorizationController`;
- one `CleanupExecutionCoordinator`;
- one in-memory pending preflight slot;
- the existing shared `CleanupWorkflowCoordinator`.

Its Core-internal Foundation constructor composes:

```text
ActionPolicyGate(registry: ActionRegistry(definitions: []))
ActionExecutor(
  trashMoving: TrashMoving(adapter: FileManagerTrashAdapter()),
  registeredActionRunner: DenyRegisteredActionRunner()
)
FoundationCleanupVolumeSampler
```

The deny-only runner is defense in depth. It always rejects and cannot spawn a
process even if a malformed future plan reaches the executor. The production
registry remains exactly empty.

The facade exposes only:

- `preflight(plan:selection:)`;
- `execute(plan:selection:confirmation:)`;
- `requestStopAfterCurrent()`;
- `retrySavingAudit(_:)`;
- `recover()`.

It does not expose:

- `ExecutionAuthorization`;
- `CleanupAuthorizationController`;
- `CleanupExecutionRequest`;
- `CleanupExecutionCoordinator`;
- an arbitrary `CleanupAction`;
- an arbitrary target URL;
- a registry mutation or process runner.

The Foundation constructor itself is not public outside `StornautCore`.
External App code can obtain a real instance only through the DEBUG-only
`diagnostic(...)` factory, which injects the recording observation required by
the signed-App evidence protocol.

### 3.2 Preflight and execution share one exact memory-only context

`preflight` collects one fresh context, evaluates pure Policy and stores the
exact allowed evaluation plus collected context in one actor-owned pending
slot. A blocked/stale result clears the slot.

`execute` accepts only the original Plan, Selection and the typed Confirmation
derived from that evaluation. It verifies:

- Plan ID/fingerprint and Selection generation/fingerprint;
- ordered selected item IDs;
- decision and context fingerprints;
- confirmation admission deadline;
- the complete pending evaluation and collected context;
- no newer preflight replaced the pending slot.

Only then may the facade issue one authorization and immediately pass the
closed request to the coordinator. The pending slot is consumed on the first
execution attempt, including an error. Repeating the same confirmation or
replaying it after App restart is rejected.

The coordinator still performs fresh per-item Policy and ActionPolicy identity
checks immediately before each Trash call. The preflight context is admission
evidence, not permission to skip later freshness checks.

### 3.3 Existing coordinator boundaries remain intact

`CleanupExecutionCoordinator` remains internal and dependency-injected. It
does not acquire a default Foundation adapter. Task 31 fake tests remain able
to prove journal ordering, failures and recovery without touching Trash.

The real adapter is created only by the new closed facade. Existing structural
checks must distinguish this reviewed composition root from prohibited direct
App/View/coordinator access.

## 4. App Composition Boundary

`AppQuickScanRuntime` remains the App composition owner because it already
owns:

- the exact `EvidenceStore`;
- Settings and Primary Root resolution;
- the shared `CleanupWorkflowCoordinator`;
- Review Plan/Policy dependencies;
- Result/History persistence.

It owns the only App-side runtime factory seam because the strict DEBUG
diagnostic must compose `CleanupExecutionRuntime` from those same objects.
Ordinary `AppDependencies.live` and `.production` expose
`ReviewExecutionAvailability.writeDisabled` and retain no execution runtime
factory. Passing a factory with `.writeDisabled` must discard it rather than
merely hiding execution in the UI.

Only the signed-App diagnostic may explicitly combine:

- `ReviewExecutionAvailability.productionTrash`;
- a non-nil closed runtime factory;
- a typed execution stream that emits bounded progress and one terminal state;
- stop-after-current and audit-retry closures backed by the same runtime.

`ReviewExecutionAvailability` becomes:

```text
writeDisabled
debugFake
productionTrash
```

`ReviewSnapshot.canExecute` permits `debugFake` and `productionTrash`, while
`writeDisabled` remains useful for tests and an unavailable composition. Views
still cannot import or name Core execution authority.

The diagnostic does not unlock a preference, feature flag or ordinary App
composition. It is current-source gate evidence only. Any future product
admission requires its own approved plan and must still remain closed by
Plan/Policy/confirmation/authorization on every run.

## 5. Signed-App Diagnostic Protocol

### 5.1 Invocation

Add one DEBUG-only argument:

```text
--stornaut-phase-c-trash-config=/absolute/path/config.json
```

No environment-only activation, relative path, default path or normal UI
entry exists. The checked-in script creates a fresh config and launches the
exact current `.derivedData/app/Build/Products/Debug/Stornaut.app`.

The App must resolve this exact launch request before constructing ordinary
production composition. A valid diagnostic launch uses an inert,
write-disabled shell model while the harness owns the isolated Quick Scan and
closed execution runtime. It must not start normal Settings refresh, Codex
discovery/capability probes or another App service before the diagnostic's
authoritative Activity snapshot. Invalid, duplicate or relative diagnostic
arguments do not select this composition.

The config is strict Codable data containing:

- schema version;
- random investigation/fixture nonce;
- exact opt-in statement and opt-in nonce;
- absolute fixture root;
- absolute isolated support and cache roots;
- absolute report output;
- expected App bundle ID;
- expected executable SHA-256;
- expected fixture relative path `.npm/_cacache`;
- maximum runtime deadline.

Unknown keys, missing keys, symlinks, a non-empty existing root, a path outside
the script-owned temporary parent, a stale config or an App/build mismatch
fail before fixture creation or Trash.

### 5.2 Fixture

The App harness creates:

```text
<unique temporary root>/
  .stornaut-phase-c-trash-fixture-<nonce>
  .npm/
    _cacache/
      .stornaut-phase-c-trash-item-<nonce>
      content-v2/sha512/<deterministic disposable bytes>
```

The marker content includes only the random nonce and fixed schema text. The
App scans only this temporary Primary Root and uses isolated Store/Settings
configuration. It records device/inode identity before planning and verifies
that the resulting Plan binds the same identity and exact relative path.

The harness must not enumerate, inspect or resolve the user's real cache
locations.

### 5.3 Execution and report

The signed App runs the real Quick Scan and the closed execution
runtime/coordinator path intended for future production admission, with a
diagnostic recording wrapper around the same Foundation Trash adapter.
Ordinary production composition remains `writeDisabled`. The report
distinguishes:

- `configured`: current App identity/build/config accepted;
- `planned`: exact Rule/Profile/Plan/Selection admitted;
- `observed`: real Trash receipt and coordinator terminal state;
- `contained`: only the exact fixture identity moved and no Registered Action
  or permanent release was possible;
- `restored`: diagnostic restore outcome;
- `residual`: exact remaining original/Trash/temporary-root state; if a Trash
  call was attempted, the original identity disappeared and no returned
  destination was available, Trash presence is `unknown`/JSON `null` rather
  than falsely reported absent.

The diagnostic does not prove resistance to a malicious same-user process
that races path ancestors between the final policy check and the Foundation
path-based Trash call. Its fresh root is mode `0700`, uniquely owned by the
diagnostic and never exposed as a normal product target; ordinary product
execution remains `writeDisabled`.

The original diagnostic report includes:

- schema version, nonce and timestamps;
- current executable path/hash, bundle ID, code-sign status and entitlements
  summary;
- original fixture URL relative to the temporary root, never a user path;
- original and returned Trash identities;
- returned Trash URL only for this disposable fixture;
- exact real Trash attempt count, which must equal one for a ready report;
- journal/Manifest IDs, stages, summary and recovery state;
- selected/moved/permanent/system-observation accounting fields;
- restore attempt/result and post-restore identity;
- sanitized typed error stage/category;
- explicit statements that FDA/TCC inheritance, distribution and unrelated
  user paths were not evaluated.

The original attempt reached `trashAttemptCount = 1`, moved the exact fixture
and durably recorded `actionOutcomeRecorded`, but failed before finalization
because the Manifest timestamp did not cover the final volume observation. Its
outcome therefore remains `signedAppTrashBlocked` / `executionFailed`; it is
not relabelled as a clean diagnostic success.

The recovery-only report binds:

- the original config/report and their SHA-256 values;
- the retained Evidence Store and exact journal stage;
- original fixture, returned Trash destination, marker and filesystem
  identities;
- the current recovery App executable SHA-256;
- journal transition `actionOutcomeRecorded → finalized`;
- one-record Manifest and exact terminal/accounting summary;
- zero executor invocations;
- identity-checked restore and final residual truth.

The checked receipt validates both reports, the final Store and all
safety-critical source hashes. A prior report or receipt cannot admit changed
source.

### 5.4 Diagnostic-only restore and residual truth

Restore is not part of `CleanupExecutionRuntime` or ordinary App UI. A separate
DEBUG diagnostic helper may move only the returned Trash URL when all are
true:

- the returned URL is present;
- it still has the original fixture identity;
- its marker nonce matches the current diagnostic;
- the original destination is absent;
- both paths remain exactly those derived from the current config.

The helper uses one direct Foundation move for the diagnostic fixture. It does
not overwrite, merge or choose another destination.

After a successful restore, the harness and verifier preserve the exact
script-owned temporary fixture tree as local evidence. If restore is
unavailable or fails, they leave the item in Trash and record that residual.
They never call `removeItem`, shell `rm`, Empty Trash or any equivalent cleanup,
and never change a failed result merely to make the gate pass.

## 6. Tests-First Matrix

### 6.1 Core runtime

- allowed preflight stores one exact pending context;
- blocked/stale preflight stores no authority;
- a newer preflight invalidates the older pending candidate;
- exact confirmation executes once;
- repeated, expired, mismatched and post-restart confirmations reject;
- execution still performs per-item fresh collection;
- workflow conflicts consume/reject authority without a write;
- stop-after-current and audit retry delegate to the same coordinator;
- recovery never replays an action;
- production composition uses empty Registry, real Trash and deny-only runner;
- malformed Registered Action input cannot launch a process;
- coordinator source remains free of a default real adapter.

### 6.2 App composition and state

- `.production()` and ordinary `.live()` remain `.writeDisabled`;
- only the strict DEBUG diagnostic composition may explicitly combine
  `.productionTrash` with a non-nil runtime factory;
- `.writeDisabled` composition discards an accidentally supplied runtime
  factory rather than merely hiding the execution UI;
- `.writeDisabled` remains non-executable;
- `.debugFake` remains fixture-only;
- `.productionTrash` permits confirmation only after allowed preflight;
- execution emits one terminal state accepted by the existing route reducer;
- Settings mutation, Quick Scan and History mutation conflict with execution;
- Result enrichment, audit retry and History use the same Store;
- no View/App state file names authorization, executor, Trash adapter or target
  filesystem writes.

### 6.3 Diagnostic and gate

- strict config decode rejects unknown/missing/stale/relative/symlinked paths;
- root reuse, marker mismatch and App hash mismatch fail before Trash;
- exact fixture generation never resolves real cache paths;
- current signed Debug App report is nonce/build/identity bound;
- ready reports require exactly one recorded Foundation Trash attempt;
- returned destination and Manifest recovery receipt agree;
- identity-checked restore succeeds for the fresh disposable fixture;
- destination collision, missing destination or changed identity never
  overwrites or deletes;
- failed restore leaves an exact residual report;
- Release contains none of the argument/config/report/marker strings;
- a stale or synthetic report cannot satisfy `verify-phase-c-gate`.

### 6.4 Deterministic end-to-end matrix

Fake-only product fixtures cover:

- complete success;
- partial failure with prior successful record;
- stale before first action;
- stop after current action;
- Manifest persistence/audit pending and retry;
- recovered crash with unknown outcome and no replay;
- corrupt journal isolation;
- Result and History projection after each terminal state.

## 7. Phase C Gate and Benchmarks

`scripts/verify-phase-c-gate` has two non-mutating modes:

```text
scripts/verify-phase-c-gate --product-only
STORNAUT_PHASE_C_TRASH_EVIDENCE_ROOT=<retained local evidence root> \
  scripts/verify-phase-c-gate --signed-app-trash-receipt
```

`--product-only` runs deterministic tests, structural boundaries, benchmarks
and scope audits. `--signed-app-trash-receipt` verifies the committed
privacy-safe receipt, safety-critical source hashes and, when the local root is
provided, the original config/report, recovery config/report, final Evidence
Store and restored residual. It never builds or launches a mutation harness.

The obsolete global process safe-window was deleted. It incorrectly treated
unrelated same-user Node processes from Chrome, Cursor, Claude or MCP servers
as a test coordination problem and created pressure to stop other Apps.
Neither the product-only gate nor the receipt gate enumerates, signals or
coordinates global processes. Contracts reject `pkill`, `killall`, `pgrep`,
same-UID `ps` coordination and reintroduction of the old script.

Ordinary product Activity remains conservative: a real npm candidate is still
blocked by current relevant Node/npm activity. The diagnostic exception was
limited to the random mode-`0700`, diagnostic-owned fixture and one exact
attestation shared across Quick Scan, Plan, preflight and per-item Policy. It
does not change production Activity semantics.

Benchmark gates, measured serially on the current Apple Silicon development
machine:

- 4,096 Review candidates load/project in at most 2.0 seconds;
- 100 selected items collect/evaluate in at most 2.0 seconds;
- exactly one process snapshot is captured per collection;
- Git invocation count remains bounded by the execution profile set;
- one-shot authorization issue/admission remains below 50 milliseconds;
- encoded journal and Manifest each remain below 1 MiB at 100 items;
- stop request acknowledgement outside a synchronous Trash call remains below
  100 milliseconds.

Thresholds include generous debug-build margin over existing bounded
algorithms. They may be tightened from evidence but not raised merely to pass.

`scripts/verify --full` ends with one `phase-c-signed-app-trash-receipt` step
after App/UI, SwiftPM and matcher verification. The step owns
`scripts/verify-phase-c-gate --signed-app-trash-receipt`; it cannot invoke the
diagnostic or recovery mutation scripts. Focused logs or an unbound raw report
cannot substitute for the checked receipt.

The authoritative full gate remains intentionally broad, but it is not the
inner development loop. Attempt 6 timing evidence showed that XCUITest
orchestration and the Debug/Release fixture boundary account for about 80% of
the full gate, while the complete SwiftPM and App test targets each finish in
about one minute. During implementation, use focused tests and product-only
gates. Run the full gate once after source and checked receipt are stable; do
not repeatedly rerun the multi-fixture XCUITest suite to diagnose already
sealed evidence.

## 8. Scope and Bundle Audit

The Phase C gate checks source, package graph and built Release App for:

- only three approved execution profiles and exactly two default Ready rules;
- empty production `ActionRegistry`;
- no production Registered Action definition or process launch path reachable
  from the runtime;
- no arbitrary shell/executable/arguments surface;
- no permanent delete, Empty Trash or failure fallback;
- `FileManager.trashItem` as the only selected-target mutation;
- no persisted authorization or diagnostic opt-in;
- no Codex, Probe Bridge or Adapter path in deterministic execution;
- no background monitor, scheduler, login item, MenuBarExtra, telemetry,
  network rule service or remote cleanup;
- no DEBUG diagnostic marker in Release;
- no dependency/license drift.

Existing Codex runtime modules may remain linked to the App for Settings/runtime
status, but the deterministic execution call graph cannot reach them.

## 9. Planned Artifacts

Core:

```text
Sources/StornautCore/Actions/CleanupExecutionRuntime.swift
Tests/StornautCoreTests/CleanupExecutionRuntimeTests.swift
Tests/StornautCoreTests/PhaseCEndToEndTests.swift
Tests/StornautCoreTests/PhaseCBenchmarkTests.swift
```

App/diagnostic:

```text
StornautApp/AppState/AppDependencies.swift
StornautApp/Review/ReviewState.swift
StornautApp/Diagnostics/PhaseCTrashDiagnosticHarness.swift
StornautAppTests/AppDependenciesTests.swift
StornautAppTests/ReviewStateTests.swift
StornautAppTests/PhaseCTrashDiagnosticTests.swift
```

Verification/docs:

```text
scripts/verify-phase-c-trash-diagnostic
scripts/verify-phase-c-trash-recovery
scripts/verify-phase-c-trash-receipt
scripts/verify-phase-c-trash-diagnostic-contract
scripts/verify-phase-c-gate
scripts/verify-cleanup-execution-boundaries
scripts/verify-review-workflow-boundaries
scripts/verify-app-release-boundaries
scripts/verify-contract
scripts/verify
docs/reports/epic-8-task-35-review.md
docs/reports/epic-8-safe-execution-validation-report.md
```

Exact files may be consolidated when an existing test/support file is the
clear owner. Any broader artifact requires an explicit brief correction.

## 10. Verification Order

Heavy SwiftPM/Xcode work remains serial:

1. Core runtime and App contract red tests;
2. verifier-contract red checks;
3. Core runtime and deterministic fake end-to-end green tests;
4. App dependency/state tests;
5. Phase C product-only boundary and benchmark gate;
6. current Debug App build/sign plus the one authorized real Trash diagnostic;
7. if required, one recovery-only signed App launch with zero Executor replay;
8. seal both mutation scripts and create the privacy-safe source-bound receipt;
9. focused Review/Result/History XCUITest and actual App/Peekaboo inspection;
10. fresh independent whole-diff review and regression fixes;
11. one uninterrupted non-mutating authoritative `scripts/verify --full`;
12. docs links, credential/generated-artifact scan and `git diff --check`;
13. archive Phase C plans, update routers/handoff/ADRs/reports;
14. one commit with subject `docs: close safe execution vertical slice`;
15. unset `GITHUB_TOKEN GH_TOKEN`, push `origin/main` and verify
    `HEAD == origin/main`.

If user screen activity steals XCUITest focus, preserve the failure evidence
and retry only the affected UI case before changing product code.

## 11. Failure and Stop Rules

Stop Phase C closure and keep normal execution `.writeDisabled` if:

- the current signed App cannot move the exact disposable fixture to Trash;
- App/build/config/fixture identity cannot be proven;
- the operation affects or inspects a path outside the unique diagnostic root
  and returned Trash destination;
- a Trash outcome is uncertain and journal/Manifest truth is incomplete;
- the gate requires permanent deletion, Empty Trash or blind retry;
- a current-build report cannot be distinguished from a stale report;
- Release contains the diagnostic;
- an unresolved P0–P2 finding remains;
- the authoritative full verifier fails.

A restore failure alone is not permission to delete the residual. It must be
reported accurately and reviewed against the diagnostic acceptance criteria.

## 12. Explicit Non-goals

Task 35 does not:

- implement production Deep Dive, an Adapter or a real Registered Action;
- add arbitrary cache targets or expand the exact execution profile;
- add permanent deletion, Empty Trash or ordinary UI restore;
- promise Trash recovery is guaranteed;
- persist authorization or diagnostic opt-in;
- request or change system permissions;
- evaluate Developer ID, notarization or distribution;
- add telemetry, remote rules, background work or login launch;
- modify `~/.codex/config.toml`;
- commit diagnostic reports, screenshots, logs, `.xcresult` or temporary
  fixture artifacts.

After Phase C is archived and pushed, the next phase requires a fresh
implementation plan grounded in the roadmap. The capability-first runtime
foundation is `go`, but production Deep Dive remains unavailable until its own
product-flow gates pass.
