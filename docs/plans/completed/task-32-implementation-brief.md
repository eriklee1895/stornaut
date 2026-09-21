# Task 32 Implementation Brief — Review Workflow App State and Native UI

> Status: Complete; implementation, actual-App evidence, independent review
> and authoritative unified verifier passed
>
> Date: 2026-08-14
>
> Baseline:
> `22327f80cee303389906b7d3d5fbe2df3fce8acd`
>
> Parent plan:
> [Epic 8 Safe Execution Vertical Slice](epic-8-safe-execution-vertical-slice.md)
>
> Accepted inputs:
> [Task 29 Review](../../reports/epic-8-task-29-review.md),
> [Task 30 Review](../../reports/epic-8-task-30-review.md),
> [Task 31 Review](../../reports/epic-8-task-31-review.md),
> [UI/UX §9](../../design/ui-ux.md#9-review-reclaim-plan) and
> [Review Round 2](../../assets/ui-concepts/REVIEW-ROUND-2.md)

## 1. Objective

Task 32 implements the approved Review Reclaim Plan as a native sub-flow of
the existing Scan workspace:

```text
latest retained Quick Scan
→ Core CleanupPlanBuilder
→ immutable Cleanup Plan + bounded Review projection
→ App-owned memory-only selection generation
→ Core CleanupPolicyContextCollector + pure CleanupPolicyGate
→ stale sheet or exact final confirmation
→ write-disabled execution seam / DEBUG fake progress only
```

The Task is complete only when:

- the top-level Sidebar still contains exactly Overview, Scan,
  Investigations and History;
- Scan stays selected throughout Results and Review;
- Core, not a View or bounded Quick Scan projection, builds the Cleanup Plan;
- App state owns typed Results/Review routing, focus, selection generation,
  preflight, stale, confirmation and fake execution progress;
- only executable Ready items are selected by default;
- executable Review items require explicit user selection;
- no-profile Review context, Protected and Unknown rows are disabled;
- row focus/Inspector state never changes execution selection;
- the five approved groups remain independent;
- final confirmation binds exact Core confirmation facts;
- stale exposes only Refresh Affected Items and Cancel;
- production App dependencies cannot call Task 31 execution or construct
  Foundation Trash;
- DEBUG fixtures may simulate progress and stop-after-current without touching
  the filesystem;
- Task 33 remains the owner of Cleanup Result and Manifest-detail UI;
- App/UI tests, actual signed Debug App screenshots, Peekaboo inspection,
  independent review, unified verifier and one commit/push are complete.

## 2. Planning Corrections

### 2.1 Review must not rebuild a Plan from `QuickScanProjection`

The existing Scan page consumes a deliberately bounded product projection.
Task 29 proved that Plan building must validate the complete retained Store
join. Therefore Task 32 adds an App dependency that calls
`CleanupPlanBuilder` against `EvidenceStore`; it must not infer Plan items,
execution profiles, identities, bytes or evidence fingerprints from visible
Scan rows.

The retained `QuickScanProjection` is used only to enrich App presentation
with item names, producer, last activity, recovery and read-only Evidence.

### 2.2 Production execution stays disabled

`CleanupExecutionCoordinator` remains an internal Core boundary and the
normal App dependency graph must not instantiate it in Task 32.

Task 32 adds a closed App-facing execution seam:

- production returns typed `writeDisabled`;
- DEBUG fixture dependencies can emit bounded deterministic progress;
- stop-after-current is modeled and tested against the fake stream;
- no state may claim `Moved to Trash`, bytes processed or completion;
- Task 33 will own terminal Cleanup Result routing;
- Task 35 still owns real signed-App Trash admission and separate user opt-in.

The Review CTA may open the exact confirmation sheet in production, but its
confirmation action remains disabled with a truthful explanation while the
execution seam is write-disabled. DEBUG fixture modes can enable it for UI
interaction tests.

### 2.3 Shared workflow exclusion is a service concern

Task 31 introduced `CleanupWorkflowCoordinator`. Task 32 creates one shared
instance per App composition and injects it into scan/settings/history and
Review services.

- Quick Scan holds `.quickScan` from start until its stream terminates.
- Settings mutations hold `.settingsMutation`.
- History deletion holds `.historyMutation`.
- Review Plan building is read-only.
- Review preflight reads the shared workflow snapshot and fails stale/blocked
  when any conflicting lease exists.
- read-only History remains allowed.

The View does not acquire or release leases.

### 2.4 Task 32 does not implement Task 33

The internal route type may reserve `cleanupResult`, but no production or
fixture path renders a Cleanup Result in Task 32. Fake execution remains an
in-progress state. Task 33 will add terminal routing and Manifest projection.

## 3. Planned Artifacts

```text
StornautApp/Review/ReviewState.swift
StornautApp/Review/ReviewModel.swift
StornautApp/Review/ReviewView.swift
StornautApp/Review/ReviewTable.swift
StornautApp/Review/ReviewInspector.swift
StornautApp/Review/ReviewConfirmationSheet.swift
StornautApp/Review/ReviewStaleSheet.swift
StornautAppTests/ReviewStateTests.swift
StornautAppTests/ReviewModelTests.swift
StornautAppTests/ReviewAppModelTests.swift
scripts/verify-review-workflow-boundaries
docs/reports/epic-8-task-32-review.md
```

Existing files may be changed only where required:

- `StornautApp/AppState/AppDependencies.swift`
- `StornautApp/AppState/StornautAppModel.swift`
- `StornautApp/AppState/DebugAppFixtures.swift`
- `StornautApp/AppShell/RootView.swift`
- `StornautApp/Scan/ScanView.swift`
- localized strings
- App contract/UI tests
- verifier/docs indexes.

## 4. Closed App Contracts

### 4.1 Route

```text
ScanWorkspaceRoute.results
ScanWorkspaceRoute.review
ScanWorkspaceRoute.cleanupResult  // reserved for Task 33
```

Task 32 transitions:

```text
results --openReview--> review
review --cancel/back--> results
```

No Task 32 event may enter `cleanupResult`.

### 4.2 Review loading state

Closed phases:

```text
idle
loading(retained?)
ready(snapshot)
empty(projection)
scanAgain(reasons)
unavailable(reasons)
preflighting(snapshot)
stale(snapshot, staleResult)
confirming(snapshot, confirmation)
executing(snapshot, progress)   // DEBUG/write-disabled fake only
executionBlocked(snapshot, reason)
```

`ReviewSnapshot` binds:

- exact current `CleanupPlan`;
- bounded `ReviewProjection`;
- selection generation;
- selected item IDs and origins;
- focus item ID;
- joined read-only presentation facts;
- execution availability.

It is memory-only and non-`Codable`.

### 4.3 Selection

Selection rules:

- initialize from `suggestedDefault`;
- every default-selected row must be executable Ready;
- selectable Review rows use `.explicitUser`;
- unselecting/reselecting increments generation;
- `ReviewSelection` is reconstructed through its Core initializer after every
  user selection change;
- invalid selection produces a typed local conflict and disables preflight;
- empty selection is valid App UI state but does not construct
  `ReviewSelection` and disables the CTA;
- focus is independent and may point to any visible row.

### 4.4 Preflight

The dependency accepts exact Plan + `ReviewSelection` and returns the real
Core `CleanupPolicyEvaluation`.

- allowed → exact `CleanupConfirmation`;
- blocked → exact `CleanupStaleResult`;
- provider/store/root failure → typed unavailable state;
- no authorization is issued;
- no executor is called;
- returning to Review after stale refresh rebuilds the Plan and resets the
  default selection from new truth.

### 4.5 Write-disabled execution seam

Closed availability:

```text
writeDisabled
debugFake
```

Closed fake progress:

```text
queued(total)
current(index, itemID)
stopRequested(completed, total)
```

There is no success/failed/Manifest terminal event in Task 32. The fake stream
must be bounded, deterministic and path-free.

## 5. Presentation Model

### 5.1 Rows and groups

Join Plan/Review projection with retained Scan facts by stable IDs.

Columns:

- Item
- Last Active
- Recovery
- Action
- Size

Groups and canonical explanations:

1. Ready to Reclaim — `Reviewed rules · Moves to Trash`
2. Review Recommended — `Check evidence before selecting`
3. Protected — `Active or policy blocked`
4. Unknown — `Insufficient evidence · Will not be processed`
5. Registered Actions — `Separate confirmation`

Registered Actions is an empty/deferred production group. DEBUG fixtures may
not inject a fake Registered Action.

### 5.2 Row semantics

Each row exposes:

- selection state;
- focus state;
- enabled/disabled selection state;
- localized disabled reason;
- producer and exact path for Inspector;
- last-active date or unavailable;
- recovery/rebuild cost or unavailable;
- action literal `Move to Trash` only for executable Plan items;
- allocated size or unmeasurable;
- current disposition and reason keys;
- supporting/missing Evidence.

No row-level cleanup button exists.

### 5.3 Footer

The fixed footer keeps separate:

- selected item count;
- estimated bytes moved to Trash;
- permanent release: zero/not available;
- one filled `Move N Items to Trash` CTA.

The CTA is disabled for:

- empty selection;
- invalid/overlapping local selection;
- stale/preflighting/executing state;
- production `writeDisabled` confirmation action.

## 6. Confirmation and Stale Sheets

### Confirmation

The sheet names exact:

- item count;
- action `Move to Trash`;
- estimated allocated bytes;
- selected Review item count;
- recoverability caveat;
- permanent release not claimed.

Cancel returns to ready without changing selection. Confirm enters fake
execution only when execution availability is `.debugFake`; otherwise the
button is disabled and explains that real Trash remains gated.

### Stale

The sheet lists affected item names when available and reason groups. Actions
are exactly:

- Refresh Affected Items;
- Cancel.

There is no proceed-anyway path. Refresh rebuilds the entire current Plan
through the dependency because the bounded App projection cannot safely patch
execution truth.

## 7. DEBUG Fixtures

Add an exact single argument:

```text
--stornaut-debug-review=<fixture>
```

Fixtures:

- `default`
- `inspector`
- `stale`
- `limited`
- `empty`
- `overlap-conflict`
- `preflight-failure`
- `executing`

Default fixture facts:

- two selected executable Ready cache items;
- one unselected executable Go build Review item;
- one disabled uv/no-profile Review context row;
- one Protected row;
- one Unknown row;
- Registered Actions empty.

All fixture paths use `/tmp/stornaut-review-fixture/`; fixture IDs and markers
must be absent from Release products. The fixture projection and Review Plan
share the same stable IDs, paths and retained presentation facts.

## 8. Tests-First Matrix

Before production implementation, add tests for:

### State and routing

- Review is under Scan and no `AppDestination.review` exists;
- Results → Review → Results;
- `cleanupResult` cannot be entered in Task 32;
- loading retains the previous snapshot;
- build failure preserves Results truth;
- concurrent open/build requests do not race.

### Selection

- Ready defaults selected;
- Review defaults unselected and becomes explicit-user selected;
- uv/no-profile, Protected and Unknown cannot be selected;
- focus does not change selection;
- generation increments on each selection mutation;
- empty and overlap conflict disable preflight;
- selected count and bytes are checked and exact.

### Policy and sheets

- preflight allowed uses exact confirmation;
- stale exposes refresh/cancel only;
- provider failure becomes unavailable;
- confirmation lists exact count/action/bytes/Review count/caveat;
- production write-disabled confirmation cannot execute;
- fake execution emits progress and durable stop intent without file writes.

### Structural

- no new top-level destination;
- no `CleanupExecutionCoordinator`, `ActionExecutor`, `TrashMoving`,
  `FileManagerTrashAdapter`, Registered Action or filesystem mutation in App
  Review sources;
- Views do not import/store `ExecutionAuthorization`;
- Release bundle has no fixture markers;
- Store remains v3;
- Deep Dive remains unavailable.

The first focused App test run must fail because Task 32 Review types and App
dependencies do not yet exist. Preserve log and digest.

## 9. UI and Accessibility Verification

Use native SwiftUI/AppKit behavior:

- grouped native `Table`;
- system checkbox/button semantics;
- keyboard traversal and Space selection;
- visible focus;
- `⌥⌘I` Inspector command;
- VoiceOver labels include group, disposition, selection and disabled reason;
- no color-only status;
- system text styles and tabular figures;
- one primary action;
- no nested horizontal scrolling at `960 × 640`;
- identical hierarchy in Light/Dark;
- confirmation and stale sheet heading receives initial accessibility focus;
- dismissal restores normal traversal and does not trap focus.

Required actual App captures:

- default Review Light;
- default Review Dark;
- Inspector Dark;
- stale sheet;
- limited or empty state;
- `zh-Hans`.

## 10. Verification and Review

Run heavy commands serially:

1. focused Review state/model/App tests;
2. full StornautAppTests;
3. Review XCUITest and screenshot export/contracts;
4. build/sign actual Debug App;
5. Peekaboo read-only capture and AX inspection;
6. `scripts/verify-review-workflow-boundaries`;
7. `scripts/check-doc-links`;
8. `scripts/verify`;
9. diff/secret/Release-fixture hygiene;
10. independent code and UI review.

Create `docs/reports/epic-8-task-32-review.md`.

Final current-source evidence:

```text
scripts/verify --full
exit 0
XCUITest 12/12
canonical screenshots 23/23
SwiftPM 610/610
StornautAppTests 140/140
log SHA-256 bff16f0870ff948920161675aad705f7dc5e34b528372e7255bf22c4c3190e35
```

## 11. Explicit Non-Goals

Task 32 does not add:

- real App Trash execution;
- Cleanup Result or Manifest UI;
- production Registered Actions;
- permanent deletion;
- restore/Undo implementation;
- Deep Dive or Adapter behavior;
- background execution;
- Store v4;
- release/notarization work;
- new dependencies.

Suggested commit subject:

```text
feat: add evidence-driven reclaim review
```
