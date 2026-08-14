# Task 33 Implementation Brief — Cleanup Result, Manifest Detail and Recovery UI

> Status: Complete; independent review and authoritative full verifier passed
>
> Date: 2026-08-14
>
> Baseline:
> `2ce21ce6cac4c89ee3936fff16dd9f7f4d44851b`
>
> Parent plan:
> [Epic 8 Safe Execution Vertical Slice](epic-8-safe-execution-vertical-slice.md)
>
> Accepted inputs:
> [Task 31 Review](../../reports/epic-8-task-31-review.md),
> [Task 32 Review](../../reports/epic-8-task-32-review.md),
> [UI/UX §10](../../design/ui-ux.md#10-cleanup-result-与-history) and
> [Cleanup Result Round 1](../../assets/ui-concepts/CLEANUP-RESULT-ROUND-1.md)

## 1. Objective

Task 33 implements the approved Cleanup Result workflow page and Manifest
detail as a native sub-flow of Scan:

```text
Review confirmation
→ DEBUG-only fake execution event stream
→ Core CleanupExecutionState terminal truth
→ immutable CleanupManifest + matching CleanupRunJournal
→ one App-owned CleanupResultSnapshot
→ Reversible First result page
→ optional Manifest detail
→ Done returns to Scan Results
```

Production execution remains `writeDisabled`. Task 33 does not construct or
call `CleanupExecutionCoordinator`, `ActionExecutor`, `TrashMoving` or
`FileManagerTrashAdapter`. Only a DEBUG fixture may emit a terminal Core
execution state for UI acceptance.

The Task is complete only when:

- the top-level Sidebar still contains exactly Overview, Scan,
  Investigations and History;
- Scan remains selected throughout Review and Cleanup Result;
- Task 32 progress and Task 33 terminal truth share one closed execution event
  stream;
- only a manifest-bearing, Core-validated `CleanupExecutionState` can enter
  Cleanup Result;
- every result row, count and byte aggregate is projected from one immutable
  `CleanupManifest`;
- the matching `CleanupRunJournal` supplies ordering, timestamps, Policy
  bindings and Manifest persistence state;
- optional item names, exact paths and Evidence lineage are display-only
  enrichment and disappear when linked Evidence is unavailable or expired;
- Trash, permanent release and system-observed free-space delta are never
  summed into a synthetic `Freed` or `Reclaimed` value;
- audit persistence failure remains distinct from action failure;
- outcome-unknown never offers retry or claims the original or Trash state;
- `Open Trash` is a typed App dependency and never a View-side `NSWorkspace`
  call;
- no restore, Empty Trash, permanent-delete fallback or blind retry exists;
- App/UI tests, actual signed Debug App screenshots, Peekaboo inspection,
  independent review, authoritative unified verifier and one commit/push are
  complete.

## 2. Planning Corrections

### 2.1 Task 33 consumes Core terminal truth; it does not create a second result model

Task 31 already defines and validates:

- `CleanupExecutionState`;
- `CleanupExecutionResult`;
- immutable `CleanupManifest`;
- matching `CleanupRunJournal`;
- audit-pending and recovery-required states.

Task 33 adds no second execution/accounting domain. The App projection may
format and group those values, but must not:

- add row bytes;
- infer a terminal state from progress;
- synthesize success after a stream ends;
- replace the Manifest summary;
- infer permanent release from Trash bytes;
- attribute free-space delta to one action.

The App snapshot validates the Manifest summary again before presentation and
rejects a mismatched terminal state.

### 2.2 Path and item-name enrichment has a shorter lifetime than the Manifest

The 90-day minimal Manifest intentionally excludes item names, original paths,
Trash destination URLs, Evidence payloads and content-derived summaries.
Task 33 therefore models enrichment separately:

```text
CleanupResultSnapshot
├── immutable Core execution result
└── optional evidence-linked presentation facts
```

When current Review/Plan/Quick Scan facts still match the Manifest, the result
may show item names, exact original paths, producer/recovery context and
display-safe Evidence lineage. If those facts are missing, expired or
inconsistent:

- the Manifest remains usable;
- result rows use neutral expired-detail copy;
- stable Action/Plan item IDs remain available only in Manifest detail;
- no path, name or Evidence is guessed or reconstructed;
- the 90-day record is not extended or rewritten.

### 2.3 DEBUG terminal fixtures do not prove production execution

Task 32's progress-only stream becomes a closed event stream:

```text
progress(ReviewExecutionProgress)
terminal(CleanupExecutionState)
```

Rules:

- exactly one terminal event is accepted;
- progress after terminal is ignored;
- stream completion without terminal remains in a typed blocked state;
- a terminal state without a valid immutable Manifest does not route to
  Cleanup Result;
- production still throws before creating a stream;
- DEBUG fixtures construct valid Core journal/Manifest pairs in memory and
  never touch the filesystem;
- fixture success is not evidence for signed-App Trash admission.

Task 35 remains the only owner of real signed-App disposable Trash admission
and requires separate user opt-in.

### 2.4 Manifest persistence and action outcome are independent

The header derives Manifest persistence from the journal:

- `finalized` → saved;
- `manifestPending` / `auditPending` → audit pending;
- corrupt or unavailable record → isolated failure state.

An action may have succeeded while the Manifest is audit pending. The page
must keep the successful Trash result visible while showing a separate
durability failure. Normal `Completed` copy is prohibited until persistence is
finalized.

`Retry Saving Audit` calls a typed dependency that may only retry persistence
for the exact existing `CleanupExecutionResult`. It cannot execute, revalidate
or replay any action. Production Task 33 has no active result to retry, while
DEBUG fixtures exercise the interaction contract.

### 2.5 Open Trash is a read-only navigation dependency

`Open Trash` is exposed once, in the Reversible First hero, and calls an
App-owned dependency that:

- resolves the current user's system Trash directory;
- asks `NSWorkspace` to open it;
- returns success/failure without mutating the Manifest;
- does not restore, move, delete or empty any item.

Failure is a local page-preserving error and does not change execution truth.
The View must not import AppKit for this action.

## 3. Planned Artifacts

```text
StornautApp/Cleanup/CleanupResultState.swift
StornautApp/Cleanup/CleanupResultModel.swift
StornautApp/Cleanup/CleanupResultView.swift
StornautApp/Cleanup/CleanupResultTable.swift
StornautApp/Cleanup/CleanupAccountingDetails.swift
StornautApp/Cleanup/CleanupManifestDetail.swift
StornautAppTests/CleanupResultStateTests.swift
StornautAppTests/CleanupResultModelTests.swift
StornautAppTests/CleanupResultAppModelTests.swift
scripts/verify-cleanup-result-boundaries
docs/reports/epic-8-task-33-review.md
```

Existing files may change only where required:

- Task 32 route/reducer and execution event contract;
- `AppDependencies` and `StornautAppModel`;
- DEBUG fixtures;
- `ScanView`;
- localized strings;
- App fixture/UI tests;
- screenshot/verifier/docs indexes.

No Store migration or Core execution behavior change is planned.

## 4. Closed App Contracts

### 4.1 Route

```text
results --openReview--> review
review --terminalManifest--> cleanupResult
cleanupResult --done--> results
```

Back navigation from Cleanup Result is `Done`; it does not return to the
stale pre-execution selection. A new cleanup attempt requires a newly built
Review and fresh Policy validation.

### 4.2 Cleanup Result state

Closed phases:

```text
idle
presented(snapshot)
openingTrash(snapshot)
trashUnavailable(snapshot)
retryingAudit(snapshot)
corrupt(recordID?)
unavailable(reason)
```

`CleanupResultSnapshot` binds:

- one manifest-bearing `CleanupExecutionState`;
- exact matching `CleanupExecutionResult`;
- immutable `CleanupManifest`;
- matching `CleanupRunJournal`;
- optional evidence-linked item facts keyed by Plan item ID;
- evidence availability (`retained` or `expired`);
- local Trash-open status only outside immutable execution truth.

It is memory-only and non-`Codable`.

### 4.3 Accepted Core terminal states

Manifest-bearing states accepted for presentation:

- `completed`;
- `partiallyFailed`;
- `stopped`;
- `auditPending`;
- `recoveryRequired`.

`stale`, `recoveryBlocked`, `recoveryCorrupt` and `rejected` do not enter the
normal result page because they do not represent the approved terminal
Manifest contract for this workflow. A DEBUG fixture may initialize the
isolated `corrupt` page directly to validate recovery grammar.

### 4.4 Outcome grammar

Presentation outcome is derived, never stored:

- all successful, finalized → Completed;
- success plus failed/unknown/cancelled → Completed with Issues;
- no write completed and failed rows exist → Failed;
- cancelled rows after completed work → Stopped;
- audit-pending journal → Audit Pending regardless of action mix;
- any unknown row → Outcome Unknown / Recovery Required.

Unknown outranks ordinary partial copy. Audit durability status remains
separate and visible even when the action outcome is otherwise known.

## 5. Immutable Projection

### 5.1 Rows

Each row is a direct projection of one `CleanupManifestRecord`:

- stable Action ID;
- stable Plan item ID;
- optional retained item name and exact path;
- action literal `Move to Trash`;
- result;
- allocated candidate/processed/Trash/permanent measures;
- recovery state;
- Policy disposition and closed reason mappings;
- started/finished timestamps;
- typed failure stage/code mapping.

Rows remain in journal order. Manifest and journal order must match.

### 5.2 Summary

Use `CleanupManifest.summary` without recomputation:

- selected logical/allocated;
- processed logical/allocated;
- moved-to-Trash logical/allocated;
- permanently released logical/allocated;
- succeeded/failed/cancelled/unknown counts.

Task 33 asserts permanent release remains zero because Registered Actions are
still empty/deferred.

### 5.3 System observation

If present, show:

- source;
- before/after sample times;
- free-space delta;
- unexplained delta.

Always label it `Not attributed to a single action`.

If absent, show `System observation unavailable`, never `0 B`.

## 6. Reversible First UI

The page uses native SwiftUI/AppKit idioms and the approved B + A + E
composition:

1. Header: Cleanup Result, terminal outcome, Manifest persistence.
2. Hero: literal moved-to-Trash bytes, item count, recovery caveat and one
   `Open Trash`.
3. Three independent summaries: Processed, Permanently Released, System
   Observation.
4. Native result `Table`: Item, Action, Result, Size, Recovery.
5. Collapsed `Accounting Details`: selected/processed/Trash/permanent/system
   plan/actual ledger.
6. Footer: secondary `View Manifest`, one prominent `Done`.

The page never renders `Freed`, `Reclaimed` or a sum across those categories.

Partial/failure grammar:

- amber is limited to overall partial/audit state;
- red is local to failed action or audit durability detail;
- `Original remains in place` appears only for
  `.originalConfirmed`/`.notStarted`;
- `.outcomeUnknown` says the location is unknown and offers no retry;
- successful Trash rows remain recoverable and are not visually rolled back;
- there is no permanent-delete fallback.

## 7. Manifest Detail

`View Manifest` opens a read-only sheet or Inspector with:

- Manifest ID, Plan ID, creation/expiry and persistence state;
- ordered journal-derived action timeline;
- Action ID and Plan item ID;
- Policy disposition and closed localized reasons;
- started/finished timestamps;
- typed error stage/code mapping;
- candidate/processed/Trash/permanent measures;
- system observation;
- retained Evidence lineage, exact path and recovery context only when
  available;
- explicit `Evidence expired` otherwise.

It contains no raw JSON, stdout/stderr, shell output, destination URLs,
hidden reasoning or execution action.

## 8. DEBUG Fixtures

Add one exact argument:

```text
--stornaut-debug-cleanup=<fixture>
```

Fixtures:

- `completed`;
- `partial`;
- `failed`;
- `stopped`;
- `audit-pending`;
- `outcome-unknown`;
- `observation-unavailable`;
- `evidence-expired`;
- `trash-unavailable`;
- `corrupt`.

Every normal fixture constructs a valid Core Manifest/journal pair. Item
names and exact paths use the existing npm/pip/Go Review fixture truth.
`corrupt` uses only an isolated identifier and never attempts to decode or
repair malformed payload.

## 9. Tests-First Matrix

Write the following before implementation and preserve the initial failing
compile log:

### State/reducer

- route opens only from a terminal manifest event;
- duplicate terminal and late progress cannot overwrite result;
- stream completion without terminal does not claim success;
- `Done` clears result and returns to Scan Results;
- Trash-open failure preserves the exact snapshot;
- audit retry cannot change action rows and only accepts exact result identity;
- rejected/non-manifest Core states cannot enter Cleanup Result;
- corrupt state remains isolated.

### Model

- completed, partial, failed, stopped, audit-pending and outcome-unknown;
- summary is exactly Manifest summary;
- rows preserve journal order and exact record values;
- no Trash/permanent/system addition;
- permanent remains zero;
- known original versus unknown recovery copy;
- observation unavailable is unknown, not zero;
- evidence-expired removes names/paths while retaining IDs and audit truth;
- typed failure/reason localization has closed fallbacks;
- no retry for outcome unknown.

### App composition

- production is still write-disabled and cannot emit terminal events;
- DEBUG terminal route is Scan-owned;
- only exact fake result reaches Cleanup Result;
- Open Trash calls the typed dependency once;
- audit retry calls only retry persistence;
- close/relaunch/late task completion cannot overwrite a replacement result;
- all fixture modes construct.

### UI

- Completed Light/Dark;
- partial state;
- audit pending and retry;
- outcome unknown with no retry;
- evidence expired Manifest detail;
- Trash unavailable page-preserving error;
- `zh-Hans`;
- no `Freed`, `Reclaimed`, `Delete Permanently`, restore or Empty Trash;
- one Open Trash and one primary Done;
- no horizontal Table scroll at the minimum window;
- VoiceOver terminal summary and literal Trash/permanent distinction.

## 10. Motion and Accessibility

- one 200–300 ms opacity/scale completion transition;
- `accessibilityReduceMotion` makes the update immediate;
- system text styles and semantic colors;
- no color-only status;
- tab order: header → hero → summary → rows → accounting → footer;
- VoiceOver announces terminal status, succeeded/failed counts, Trash bytes
  and permanent bytes;
- tabular localized number formatting;
- native macOS control sizing; no iOS-specific row-height rule;
- one primary action.

## 11. Verification and Review

Run heavy commands serially:

1. focused Cleanup Result state/model/App tests;
2. full `StornautAppTests`;
3. Cleanup Result XCUITest and screenshot contracts;
4. build/sign actual Debug App;
5. Peekaboo read-only capture and AX inspection;
6. `scripts/verify-cleanup-result-boundaries`;
7. `scripts/check-doc-links`;
8. independent code/UI review and regression fixes;
9. authoritative `scripts/verify --full`;
10. diff/secret/Release-fixture hygiene.

Create `docs/reports/epic-8-task-33-review.md`.

## 12. Explicit Non-Goals

Task 33 does not add:

- real App Trash execution;
- signed-App Trash admission;
- restore/Undo or Empty Trash;
- permanent deletion;
- production Registered Actions;
- Manifest-aware History paging/deletion (Task 34);
- Store v4;
- Deep Dive or Adapter behavior;
- background execution;
- release/notarization work;
- new dependencies.

Suggested commit subject:

```text
feat: present truthful cleanup results
```
