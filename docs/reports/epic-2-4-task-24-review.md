# Epic 2–4 Task 24 Code Review — 2026-08-10

> 状态：All confirmed code-review findings fixed; final automatic review has
> no open P0–P2 finding; unified verification passed
>
> 范围：typed Scan History persistence、seven-day sweep、Quick Scan/History
> concurrency、App-owned History state、master-detail UI、Storage Trend、
> confirmed deletion、accessibility、Light/Dark、English/`zh-Hans` 与
> screenshot gates
>
> 方法：tests-first red baselines + current Apple SwiftUI study +
> `bits-code-guard` grouped fallback review + real App/XCUITest/Peekaboo

## 1. Study and Tests-First Baseline

- Current Apple SwiftUI documentation confirmed macOS selection-driven `List`,
  `HSplitView`, `confirmationDialog` and accessibility semantics as the native
  implementation surface.
- The approved History E+A+C composition supplied hierarchy only. No raster,
  generated date/path/size, raw palette or pixel constant entered production.
- Initial Core/App tests failed on missing `ScanHistoryPage`, History state,
  projection, dependencies and View types.
- Runtime AX review found raw `history.ledger.*` keys and established a second
  red XCUITest before the final accessibility fix.
- Review regressions were added before fixes for filter-empty semantics,
  invalidated refresh flights, active-scan access, measured/distinct trend
  samples, corrupt-filter truth, missing scope, retention sweep and
  actor-reentrancy ordering.

## 2. Confirmed Review Findings and Fixes

| Severity | Finding | Fix | Regression evidence |
| --- | --- | --- | --- |
| P1 | A filtered page with no matches was labeled `No history yet`, falsely implying no persisted scans | Add a distinct `noResults` presentation and localized recovery copy | no-match projection test |
| P1 | A History refresh invalidated by a new scan could remain Loading or permanently block later refresh/delete | Replace the Boolean with a generation-scoped refresh flight; stale completion cannot clear or overwrite a replacement | suspended/replacement flight tests |
| P1 | Core History reads were allowed during an active scan, exposing provisional sessions below the App guard | Add coordinator-level active-scan rejection | active-scan integration test |
| P1 | Actor reentrancy left a TOCTOU window where Scan could begin while History store access was suspended | Add reader count, exclusive mutation and pending-start barrier; Scan waits for existing readers while new readers cannot overtake it | blocking History store concurrency test |
| P1 | The accepted seven-day retention API had no production call site, so expired Evidence could remain indefinitely and become latest Overview truth | Sweep retention before inactive `loadLatest` and `loadHistory` through the same actor-owned store | injected-clock coordinator sweep test |
| P1 | `.estimated` capacity/free values could qualify as measured Storage Trend samples | Require both measure statuses to be `.measured` | estimated-free trend regression |
| P1 | Four sessions at duplicate timestamps could satisfy the four-snapshot trend gate | Deterministically deduplicate by timestamp before the minimum-count check | distinct-timestamp trend regression |
| P1 | Corrupt rows with no trustworthy date/status appeared under Complete/Today filters | Show corrupt rows only under unqualified status/date filters and filter them only by raw ID | corrupt filter truth test |
| P1 | A valid scope-less failed/cancelled session fabricated `.` as its scope | Make scope optional and render localized `Scope unavailable` | scope-less session regression |
| P1 | A started stream that failed without a terminal event could leave the pre-scan History page current | Invalidate History after started-stream failure; start failure before a stream preserves existing records | Scan App-model failure tests |
| P1 | The trend screenshot attachment was not exported or verified | Add it to the stable thirteen-image export and Dark/content gate | final unified screenshot gate |
| P2 | Space Ledger AX rows exposed raw localization keys and a parent identifier swallowed child identifiers | Remove the parent identifier and give each metric an explicit localized label/value/ID | red/green XCUITest + Peekaboo AX |

## 3. Persistence, Retention and Concurrency Contract

```text
History page
  = ordered ScanSession page (limit 1...100)
  + one bounded SpaceLedger IN query
  + isolated corrupt session/ledger IDs

Inactive loadLatest/loadHistory
  → seven-day Evidence sweep
  → typed read

History readers may overlap
History delete is exclusive
Quick Scan waits for existing readers and blocks new History access
Active Quick Scan rejects History read/delete
```

- Row ID, parent ID and closed `SpaceLedger` payload identity are all checked.
- Corrupt/missing ledgers preserve the session but never fabricate bytes.
- Session deletion is a typed Evidence-store cascade and cannot address target
  files, Trash or the independent Local Knowledge store.
- A page already open when its clock crosses expiry may render `Expired` until
  refresh. Every new production History/latest load sweeps it first.
- A start failure before the coordinator stream exists preserves History;
  failures after the stream starts invalidate History for a truthful reload.

## 4. Projection and UI Contract

- History contains only real Quick Scan records. No synthetic Deep Dive,
  report, Cleanup Manifest, export or cleanup action is displayed.
- The navigator groups Today, Yesterday and Earlier and shows type, terminal
  state, real scope or unavailable, Known metric and retention countdown.
- Search, status and date filters are read-only projections. Corrupt rows never
  claim unknown status/date facts.
- Detail keeps terminal state, coverage, lineage, retention, Known, Unknown,
  Unmeasurable and Free separate.
- Confirmed deletion states that files, Trash, prior cleanup effects and Local
  Knowledge remain unchanged.
- Storage Trend requires at least four completed, measured, non-inconsistent,
  distinct-timestamp samples. Used/Free have direct labels, different line
  styles, exact data rows and the fixed non-causality statement.
- DEBUG fixtures and the initial-trend presentation argument are absent from
  the Release binary; no new dependency, entitlement, telemetry, background
  task, scheduler or product permission was added.

## 5. Verification Evidence

Final unified evidence:

- `scripts/verify`: exit 0;
- SwiftPM: 267/267; two explicit opt-in diagnostics skipped;
- App tests: 79/79;
- XCUITest: 7/7;
- thirteen stable screenshots: shell/Settings Light/Dark, limited and
  `zh-Hans` Overview, three Scan states, populated/expired/corrupt History and
  Storage Trend Dark;
- History screenshot statistics:
  - populated Light `239.38`, sd `24.74`;
  - expired Dark `47.87`, sd `27.26`;
  - corrupt Light `239.40`, sd `24.67`;
  - trend Dark `45.55`, sd `27.19`;
- final signed real-App Peekaboo captures:
  - populated Light window `40802`, 264 AX elements;
  - expired Dark window `40817`, 250 AX elements;
  - corrupt Light window `40832`, 264 AX elements;
  - trend Dark window `40847`, 252 AX elements;
  - every capture was `2360 × 1520`; no raw localization key remained in
    label/description/value;
- History/App/Quick Scan/Overview/Scan/Release source and binary gates pass;
- signed App bundle, localization parity, plist lint, docs links,
  `git diff --check` and checked-in 67-rule catalog
  `133b3829816fa951f03cb87473e03454c3e561b421c83e6c8efaf8ad89849e99`
  pass.

Xcode emitted non-blocking `DebuggerVersionStore` / `no debugger version`
warnings while initializing UI runner launches. All seven UI test methods
executed and passed. No Automation Mode no-authentication policy, root daemon,
TCC/SIP, Accessibility, Event Synthesizing or other system permission was
modified.

The final automatic report is retained at
`/tmp/stornaut_task24_review_1786353018/report.html`; it has no open P0–P2
finding. The grouped review covered 29 tracked/untracked files and 4,511 lines;
12 confirmed findings were fixed before the final pass.

## 6. Remaining Boundaries

- Task 25 owns full Phase B Settings, configured roots/exclusions, separate
  clear actions and structured Local Knowledge management.
- Task 26 owns the Phase B real-machine gate and plan lifecycle closure.
- Investigations remains a placeholder and Deep Dive remains no-go/paused.
- Export, Cleanup Manifest History and deterministic cleanup remain outside
  Task 24.
