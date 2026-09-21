# Epic 8 Task 32 Code Review and Completion Audit

> Status: Complete; implementation, actual-App evidence, independent review
> and authoritative unified verifier passed
>
> Date: 2026-08-14
>
> Baseline:
> `22327f80cee303389906b7d3d5fbe2df3fce8acd`
>
> Scope: Scan-owned Review routing, Core Plan/Policy service seam, memory-only
> selection, write-disabled production execution, DEBUG fake progress and
> native macOS Review UI

## 1. Objective and Delivered Boundary

Task 32 delivers the approved native Review Reclaim Plan without enabling
real App Trash:

```text
latest retained Quick Scan
→ Core CleanupPlanBuilder over complete shared Store truth
→ immutable Plan + bounded Review projection
→ App-owned memory-only selection/focus
→ fresh Core Policy preflight
→ exact confirmation or blocking stale state
→ production writeDisabled / DEBUG-only bounded fake progress
```

The top-level destinations remain exactly Overview, Scan, Investigations and
History. Review is an internal Scan route; Task 32 reserves but never enters
`cleanupResult`.

Production `AppDependencies`:

- build the Plan from the same `EvidenceStore` used by Quick Scan;
- collect fresh Policy context through the shared workflow coordinator;
- expose `ReviewExecutionAvailability.writeDisabled`;
- do not construct `CleanupExecutionCoordinator`, `ActionExecutor`,
  `TrashMoving` or `FileManagerTrashAdapter`;
- cannot issue `ExecutionAuthorization`;
- keep Registered Actions empty and real Trash unavailable.

## 2. App State and Native UI

The App model owns:

- Results → Review → Results routing under Scan;
- Plan loading and generation-safe cancellation;
- default Ready selection and explicit Review selection;
- focus independent from execution selection;
- fresh preflight and exact confirmation binding;
- stale refresh/cancel presentation while the Plan remains stale;
- bounded DEBUG fake progress and durable stop-after-current intent.

The native UI contains:

- five independent grouped `Table` sections;
- Item, Last Active, Recovery, Action and Size columns;
- system checkboxes with typed disabled reasons;
- a read-only Evidence Inspector;
- exact confirmation and stale sheets;
- separate selected count, estimated Trash bytes and zero permanent release;
- no permanent-delete control, row-level cleanup button or real Registered
  Action.

Inspector compact columns eliminate horizontal scrolling while open at the
actual `1180 × 760` test window. Internal Evidence/reason tokens are mapped to
closed bilingual copy rather than exposed as raw keys.

## 3. Tests-First Evidence

The initial Review tests were written before implementation and failed to
compile because the Task 32 route, snapshot and reducer types did not exist:

```text
/tmp/stornaut-task32-red-tests.log
SHA-256 77caf29dabb6337dad5c405d1dd55b896c31ae9d97bd27846258e2322534588c
```

Independent review also produced a valid red witness for selection mutation
during an in-flight preflight:

```text
App suite: 137/138 passed
appModelRejectsSelectionChangesWhilePreflightIsInFlight failed
actual selection generation: 8
expected frozen generation: 7
```

The App model and presentation model now both disable mutation outside
`.ready`; the final App suite passes `140/140`.

## 4. Independent Review Findings and Corrections

Review used:

- local seven-dimension `bits-code-guard` fallback over tracked and untracked
  Task 32 files;
- local `codex review --uncommitted` with `gpt-5.6-luna`, read-only sandbox and
  no approvals;
- manual state/concurrency/UI/boundary audit;
- actual App/Peekaboo screenshot and AX inspection.

### 4.1 Selection could mutate during preflight

**Severity before fix:** P1 confirmation-integrity race

**Disposition:** Fixed.

The Table remained interactive while the App awaited Policy. A changed
generation could receive a confirmation for the previous selection and leave
the UI in a confirmation state with no valid sheet. Selection is now accepted
only in `.ready`, and every non-ready row is non-interactive.

### 4.2 In-memory Quick Scan and Review used different Stores

**Severity before fix:** P2 integration correctness

**Disposition:** Fixed.

Separate SQLite `:memory:` connections do not share data. The runtime now
single-flights one `EvidenceStore` and injects that exact instance into the
Quick Scan coordinator and Review builder. The live in-memory integration test
now executes Quick Scan and then builds Review from the same retained truth.

### 4.3 Stale Cancel re-enabled a stale Plan

**Severity before fix:** P2 fail-closed UX

**Disposition:** Fixed.

The approved UI/UX contract says Cancel dismisses the stale sheet but leaves
the Plan stale and non-executable. Sheet presentation is now separate from
typed stale state. Only Refresh rebuilds a Plan.

### 4.4 DEBUG execution stream was unbounded

**Severity before fix:** P2 fixture/task lifecycle

**Disposition:** Fixed.

The fake stream now emits bounded queued/current progress and finishes without
claiming success, failure, Manifest or Cleanup Result. Task 33 still owns
terminal routing.

### 4.5 Late progress could erase stop intent

**Severity before fix:** P1 cancellation truth

**Disposition:** Fixed.

Once stop-after-current is recorded, later queued/current events cannot
downgrade it. The regression test deliberately emits a late event after the
stop callback.

### 4.6 Confirmation facts were validated only by the View model

**Severity before fix:** P2 fail-closed robustness

**Disposition:** Fixed.

The reducer now validates Plan ID, selection generation/order/count, Review
count, bytes and action before entering `.confirming`. A mismatch becomes
typed unavailable; no blank confirmation state is possible.

### 4.7 Selected-byte overflow silently became zero

**Severity before fix:** P1 accounting truthfulness

**Disposition:** Fixed.

Selected allocated bytes are checked when the snapshot/selection is created.
Overflow rejects the selection contract instead of displaying `0 B`.

### 4.8 Fixture truth and user-visible copy drift

**Severity before fix:** P2 test validity / UX truthfulness

**Disposition:** Fixed.

The final DEBUG fixture uses the approved exact dataset:

- npm and pip Ready/default-selected;
- Go build Review/unselected;
- uv visible but no execution profile;
- Protected and Unknown disabled;
- Registered Actions empty.

The Scan projection and Review Plan share stable IDs, paths and retained
facts. Raw reason/Evidence tokens, misleading confirmation future tense and
the root item `/` label were replaced with truthful bilingual copy.

No unresolved P0–P2 finding remains. Review artifacts:

```text
/tmp/stornaut_task32_code_review/report.html
/tmp/stornaut_task32_code_review/report.md
```

## 5. Verification Evidence

### App tests

```text
StornautAppTests
140/140 passed
```

This includes route/state, exact selection, byte overflow, confirmation
binding, stale Cancel, generation-safe close/reopen, in-memory shared Store,
durable stop intent, fixture truth, localization and existing App/snapshot
regressions.

### Focused Review XCUITest

```text
testReviewWorkflowStatesAndConfirmation
1/1 passed
```

It covers:

- default Review Light/Dark;
- confirmation and DEBUG-only progress;
- read-only Inspector with joined facts;
- no Inspector horizontal scroll;
- stale Refresh/Cancel with no Proceed Anyway;
- stale Cancel remains stale and non-executable;
- empty state;
- `zh-Hans`.

### Canonical screenshot contract

The latest complete UI run exported and validated all 23 canonical
screenshots, including six Review attachments:

```text
stornaut-review-default-light
stornaut-review-default-dark
stornaut-review-inspector-dark
stornaut-review-stale-dark
stornaut-review-empty-light
stornaut-review-zh-Hans
```

Light/Dark luminance deltas, non-blank variance and expected theme ranges
passed.

### Actual App and Peekaboo

The real Debug `.app` launched through XcodeBuildMCP. Read-only Peekaboo
captured and inspected the actual Review/Inspector window:

```text
/tmp/stornaut-task32-review-inspector-final-v2.png
SHA-256 52d037de0f8d723e4a2f2f384e607564e7f282ab31c47727a0252c896c62f8d6
```

AX evidence confirmed:

- Scan remains the selected top-level destination;
- all five Review groups exist;
- only executable rows are actionable;
- two default selections and separate 300 kB Trash accounting;
- Inspector is read-only;
- producer/activity/recovery/exact path facts are joined;
- no permanent-delete action;
- compact Inspector layout has no horizontal Table scroll.

### Structural and documentation gates

```text
scripts/verify-review-workflow-boundaries
Review workflow boundary verification passed.

scripts/verify-cleanup-execution-boundaries
Cleanup execution boundary verification passed.

scripts/verify-contract
Verifier mode and CI contract verification passed.

scripts/check-doc-links
All local Markdown links resolve.

localization plist/key parity
passed

git diff --check
passed
```

### Authoritative full verifier

```text
scripts/verify --full
exit 0
elapsed stage time: 667.755 seconds

XCUITest: 12/12
canonical screenshots: 23/23
SwiftPM: 610/610
StornautAppTests: 140/140
```

The current-source log is:

```text
/tmp/stornaut-task32-release-full-verify-passed.log
SHA-256 bff16f0870ff948920161675aad705f7dc5e34b528372e7255bf22c4c3190e35
```

The final run also passed matcher benchmarks, Phase B product/cancellation
evidence, all source boundaries, Automation Mode parser self-test, Debug and
Release fixture boundaries, App signing/bundle verification, localization,
rule compiler parity, verifier-contract regression, local Markdown links and
diff hygiene.

## 6. Scope Audit

Task 32 does not:

- enable real App Trash or Foundation Trash construction;
- call Task 31 execution from production App dependencies;
- enter Cleanup Result or render Manifest detail;
- add a production Registered Action;
- add permanent deletion, restore or rollback;
- enable Deep Dive, Adapter or Shell cleanup;
- add Store v4, telemetry, background work or a dependency;
- change release/notarization scope.

Task 33 remains the owner of Cleanup Result/Manifest UI. Task 35 remains the
only place for signed-App disposable real Trash admission and still requires
separate explicit user opt-in.

## 7. Current Decision

Task 32 is complete. The current-source authoritative verifier exited `0`;
the implementation is eligible for its independent commit and push.

Real App Trash remains disabled. Task 33 owns Cleanup Result/Manifest UI, and
Task 35 remains the only authorized place for signed-App disposable real
Trash admission with separate user opt-in.
