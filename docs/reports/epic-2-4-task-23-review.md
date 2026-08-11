# Epic 2–4 Task 23 Code Review — 2026-08-10

> **Historical-scope notice (2026-08-11):** Deep Dive paused/no-go references
> record the reviewed Phase B scope, not current Codex policy. See capability-first
> [ADR 0004](../adr/0004-codex-file-read-isolation.md).

> 状态：All confirmed code-review findings fixed; final automatic review has
> no open P0–P2 finding; unified verification passed
>
> 范围：App-owned Quick Scan lifecycle、五阶段 progress、progressive
> classified results、grouped native Table、read-only Evidence Inspector、
> DEBUG fixtures、Light/Dark、English/`zh-Hans` 与 screenshot gates
>
> 方法：tests-first red baseline + current Apple SwiftUI study +
> `bits-code-guard` grouped fallback review + real App/XCUITest/Peekaboo

## 1. Study and Tests-First Baseline

- Current Apple SwiftUI documentation confirms native macOS `Table`,
  selection, bounded `inspector`, `ProgressView` and accessibility input/hint
  APIs remain the appropriate platform surface.
- `ui-ux-pro-max` reinforced stable IDs, explicit multi-step status, honest
  loading feedback, long-path detail and text/icon status rather than
  color-only meaning.
- The approved Quick Scan E+A and Scan Results A+D assets supplied hierarchy
  only. No generated value, path, raw palette or pixel constant entered
  production.
- Initial focused App build failed on the missing `ScanFlowReducer`,
  `ScanFlowState` and `ScanModel`, establishing the red baseline.
- A second red baseline failed on missing App start/cancel typed dependencies
  and App-owned lifecycle.

## 2. Confirmed Review Findings and Fixes

| Severity | Finding | Fix | Regression evidence |
| --- | --- | --- | --- |
| P1 | Result rows initially used each directory `PathSnapshot.allocatedByteCount`, which is directory-entry size rather than artifact subtree occupancy | Terminal result size now requires a classification-consistent `SpaceLedgerOwner`; progressive rows show Pending Final Accounting until the ledger exists | owner-size and progressive-accounting tests |
| P1 | App initially accumulated every traversal snapshot with linear identity replacement, creating unbounded memory and O(n²) updates on a real home scan | Product stream now emits paired classified snapshots only; full traversal facts remain in bounded Core persistence | paired-event integration assertion + App reducer tests |
| P1 | Stop requested before coordinator initialization could be lost | Retry cancellation immediately after the stream exists and test the delayed-start race | immediate-stop regression |
| P1 | An old initial `loadLatest` could complete after a newer user scan and overwrite its terminal projection | Add a scan-generation guard; stale load success/failure/cancellation cannot update state | stale-refresh race regression |
| P1 | A detached late cancel could overlap the next session | Track the cancellation task and forbid a new start until it completes | model lifecycle tests |
| P1 | Stream/start failure preserved reducer facts but left shared page state in Loading or old success | Reduce failures to a page-preserving safe error state and retain current progressive typed facts when available | failure projection/model regressions |
| P1 | Initial store refresh updated Overview but not Scan's retained terminal phase/metrics | Synchronize non-active `ScanFlowState` from loaded projection; active flows remain authoritative | App-state refresh regressions |
| P1 | Root bookkeeping classifications appeared as user result rows and candidate counts | Exclude `relativePath == "."` from results/candidates while retaining scope progress | grouping/candidate regressions |
| P1 | Inspector labeled a relative path as Exact Path | Composition injects the typed Phase B root; Inspector renders root-qualified exact path plus relative path without View filesystem access | exact-path model test + real App AX |
| P1 | Dynamic active status used `Text(String)` and exposed `scan.status.active` instead of localized copy | Convert dynamic key to `LocalizedStringKey` | real App Peekaboo AX review |
| P1 | Retained partial snapshots fabricated all five stages as Pending despite no persisted stage history | Retained partial/cancelled/failed state marks Stage History Unavailable; live interruption marks only the current stage Incomplete | retained-stage regression |
| P1 | Immediate terminal processing could remain active until arbitrary post-terminal stream events | Terminal is authoritative; App updates shared state, breaks consumption and lets one defer close lifecycle | model terminal tests |
| P2 | Stage accessibility label was replaced by only `3, 5`, hiding the stage name | Stage name is the label, status the value, ordinal the hint | Peekaboo AX contains `Classify Artifacts · Current` |
| P2 | Inspector omitted the recovery method and showed only rebuild cost | Add read-only recovery method token separately from cost and disposition | Inspector projection/source review |
| P2 | Completed/partial screenshots could pass without distinct content/theme evidence | Add three Scan screenshots to the nine-image luminance/content-variance gate | final screenshot statistics |

## 3. Final State and Accounting Contract

```text
Scope Scanned    = ScanProgress.completedEntries
Candidates Found = distinct non-root classified snapshot IDs
Measured         = Surveyor hardlink-deduplicated allocated regular-file bytes
Elapsed          = injected start clock → current/terminal time
Result size      = matching SpaceLedgerOwner.allocatedBytes only
```

- No percentage is shown because no trustworthy total-work denominator exists.
- Negative or overflowing transport values fail closed to prior/saturated
  typed truth.
- Missing and unmeasurable values render an em dash plus a localized reason;
  they never become `0 B`.
- Recovery, Disposition, risk/evidence and measured occupancy remain separate.
- The App stores only classified result pairs, bounded evidence and one ledger,
  not the full traversal tree.

## 4. Final UI and Safety Boundary

- Opening Scan never starts a scan. Only `Run Quick Scan`/`Scan Again` invokes
  the typed App intent.
- Five stages use icon, label and Complete/Current/Incomplete/Pending/
  Unavailable text, never color alone.
- One native grouped Table renders the seven lifecycle categories and the
  approved independent columns.
- Search and All/Ready/Review/Unknown/Protected filters mutate no domain state.
- The trailing Inspector is read-only and exposes full path, lifecycle,
  producer, filesystem modification time, recovery, supporting/missing
  evidence and disposition.
- Stop Scan is neutral and says partial results are retained.
- Review is explicitly disabled in Phase B.
- No checkbox, Trash, Registered Action, Reveal/Copy shell integration, Codex
  launch, Deep Dive bypass, new dependency, entitlement, telemetry, background
  task or scheduler was added.

## 5. Verification Evidence

Final unified evidence:

- `scripts/verify`: exit 0;
- SwiftPM: 263/263;
- focused Quick Scan integration: 17/17;
- App tests: 57/57;
- XCUITest: 5/5;
- nine stable screenshots: shell/Settings Light/Dark, limited Overview,
  `zh-Hans` Overview, Scan active Dark, partial Light and completed Inspector
  Light;
- screenshot theme/content gate:
  - Scan active Dark `39.75`, sd `24.84`;
  - Scan partial Light `244.01`, sd `29.13`;
  - Scan Inspector Light `236.80`, sd `41.99`;
- read-only Peekaboo launched one real App at a time and captured distinct
  final window IDs `37082`, `37107`, `37123`; required AX text was present and
  `Move to Trash` / `Investigate with Codex` were absent;
- App/state/Overview/Scan/Release source and binary gates pass;
- signed App bundle, localization parity, plist lint, docs links,
  `git diff --check` and checked-in 67-rule catalog
  `133b3829816fa951f03cb87473e03454c3e561b421c83e6c8efaf8ad89849e99`
  pass.

Xcode emitted non-blocking `DebuggerVersionStore`/`no debugger version`
warnings while initializing some UI runner launches. All five UI test methods
still executed and passed. No no-authentication Automation Mode policy, root
daemon, TCC/SIP, Accessibility, Event Synthesizing or other system permission
was modified.

One post-documentation verifier attempt hit an existing Codex process timing
test before the App/UI stages: the fake process had not yet written `pid.txt`.
The focused test passed immediately afterward, and the next full
`scripts/verify` run passed all 263 SwiftPM tests and every downstream gate.
The transient failure is recorded rather than counted as a successful run.

The final automatic report is retained at
`/tmp/stornaut_task23_review_1786343771/report.html`; it has no open P0–P2
finding.

## 6. Remaining Boundaries

- Task 24 owns Scan-only History.
- Task 25 owns full Settings and configured roots/exclusions.
- Task 26 owns the Phase B real-machine gate.
- Investigations remains a placeholder and Deep Dive remains no-go/paused.
