# Epic 2–4 Task 21 Code Review — 2026-08-10

> **Historical-scope notice (2026-08-11):** Deep Dive paused/no-go references
> record the reviewed Phase B scope, not current Codex policy. See capability-first
> [ADR 0004](../adr/0004-codex-file-read-isolation.md).

> 状态：All confirmed findings fixed; final review has no open P0–P2 finding
>
> 范围：App-owned model state、production/DEBUG composition、semantic
> DesignSystem、localization、fixture/Release boundaries 与 UI fixture contract
>
> 方法：tests-first red baseline + current Apple API study + grouped
> `bits-code-guard` fallback review + machine boundary/Release gates

## 1. Study and Tests-First Baseline

- The accepted Phase B UI study was refreshed against current Apple SwiftUI
  model-data documentation and unchanged ClearDisk/PureMac MIT revisions.
- Apple’s `@State`-owned `@Observable` model plus Scene `.environment(model)`
  path was selected; no third-party DI or Combine-era App singleton was added.
- Initial App tests failed only on missing Task 21 App state, fixture and
  DesignSystem APIs.
- `scripts/verify-app-state-boundaries` initially failed on missing Task 21
  files before implementation.

## 2. Confirmed Review Findings and Fixes

| Severity | Finding | Fix | Regression evidence |
| --- | --- | --- | --- |
| P1 | A selected DEBUG fixture construction error could be swallowed by `try?` and silently fall back to production storage | Parse selection first; a selected fixture either builds or yields a closed error composition, never production fallback | injected fixture-construction failure test |
| P1 | Production composition opened/configured SQLite synchronously during App initialization | Defer production configuration/store/coordinator creation to an async utility task behind an actor loader | deferred-factory test + real App runtime |
| P1 | Concurrent first refreshes could create multiple stores/coordinators through actor reentrancy | Add a single-flight coordinator task and reuse the resolved coordinator | concurrent-load factory-count test |
| P1 | After a failed coordinator flight, a stale waiter could clear a newer retry flight and allow duplicate coordinator creation | Give each flight an identity and let a waiter clear only the flight it observed | 32-way failed-first-flight retry regression |
| P1 | Task cancellation was rendered as a store error | Restore the exact pre-refresh page on `CancellationError` | cancellation state regression |
| P1 | Partial/cancelled/limited/loading states accepted contradictory reason/recovery/timestamp combinations | Close `AppPageState` invariants for all eight phases | invalid-state contract tests |
| P1 | Error/stale transitions rewrote the retained snapshot time as the failure time | Preserve the prior successful `refreshedAt`; use current time only when no prior timestamp exists | page-preserving timestamp assertions |
| P1 | Multiple DEBUG fixtures sharing a terminal state reused the same domain IDs | Include the closed fixture slug in session/scope/snapshot/classification IDs | all fixture projection IDs unique |
| P1 | Release fixture isolation was only manually checked | Add `scripts/verify-app-release-boundaries` and integrate it into `scripts/verify` | Release binary marker/value audit |
| P1 | The first Release gate inspected only Xcode 26's Debug launcher thunk, so its checks could pass without seeing known Debug markers | Scan every regular file in both App bundles, require all eight markers in Debug as a positive control, then require all eight to be absent from Release | positive-control Debug/Release App gate |
| P2 | Unknown-locale formatter fallback could use the current App language instead of the requested deterministic fallback | Map `zh` to `zh-Hans`; all other unknown language codes fall back to English | `fr_FR` Unknown test |
| P2 | Expired evidence used failed/red semantics even though expiry is retention state, not an operation failure | Use neutral expired role with explicit icon/text | retention role test |
| P2 | Coverage accepted nonzero unmeasurable bytes as complete and preserved negative input count | Only `0 gaps + 0 B` is complete; normalize count before state selection | coverage boundary tests |
| P2 | Metric VoiceOver combined visible value and an explicit accessibility value | Ignore children and expose one title/value pair | source review + App build |

## 3. Final Architecture

- `StornautApp` owns one `@MainActor @Observable StornautAppModel` in `@State`
  and injects it into main and Settings scenes.
- `AppDependencies` exposes only `loadLatestQuickScan()`.
- Production loading is:

  ```text
  async utility creation
  → LocalStoreConfiguration.production()
  → EvidenceStore
  → QuickScanCoordinator
  → actor-owned reusable loadLatest()
  ```

- SwiftUI Views never construct or reference Surveyor, SQLite, Codex, Probe,
  Policy, Executor, Trash or Registered Action APIs.
- RootView still renders the approved four placeholder destinations. Task 21
  does not implement Overview, Scan or History.

## 4. State and Fixture Result

- Closed phases: empty, loading, partial, cancelled, success,
  limited-permission, stale and error.
- Loading/error/stale preserve valid projection state.
- DEBUG fixture IDs are closed, deterministic and use real StornautCore
  constructors.
- Missing, malformed, unknown or duplicate fixture arguments select production.
- Selected fixture construction failure never selects production.
- XCUITest proves the `limited-permission` fixture reaches the live App while
  the foundation placeholder remains unchanged.
- The machine gate first proves the Debug App contains every reviewed selector
  and fixture marker, then proves the Release App contains none of them.

## 5. Semantic Design System

Task 21 adds only the primitives requested by the active plan:

- metric tile;
- disposition label;
- App phase status;
- coverage and retention badges;
- empty and page-preserving recovery states;
- byte/status formatting.

All use system colors/type/SF Symbols and localized icon + text semantics.
Unknown bytes are an em dash plus localized `Unknown`; measured zero is `0 B`.
No canonical image color/layout value was copied.

## 6. Final Verification

- `scripts/verify`: exit 0 on 2026-08-10;
- SwiftPM: 263/263;
- App tests: 22/22;
- XCUITest: 3/3, including fixture selection;
- four Light/Dark screenshots exported and checked: shell `2360 × 1520`,
  Settings `1800 × 900`;
- App-state source boundary gate passes;
- Debug-positive-control/Release-negative-control fixture gate passes;
- localization parity and plist lint pass;
- signed App bundle validation and the 67-rule catalog at
  `133b3829816fa951f03cb87473e03454c3e561b421c83e6c8efaf8ad89849e99`
  pass;
- real Debug App launches and Peekaboo captures a nonblank `2360 × 1520`
  window in the focused runtime check;
- no new dependency, entitlement, telemetry, background task or product asset;
- `git diff --check` and documentation links pass.

An earlier passing UI run attached two non-failure `.ips` reports. Both identify
Google Chrome 151 (`com.google.Chrome`), not Stornaut; their stacks contain
Chrome/XCTAutomationSupport and no Stornaut image or frame. The final unified
rerun exported only the four expected screenshots and reports all three
Stornaut UI tests as Passed. The external process was not modified or terminated
by this Task.

## 7. Remaining Boundaries

- Task 22 owns real Overview rendering.
- Task 23 owns Quick Scan start/stop/progress/results UI.
- Task 24 owns History.
- Task 25 owns full Settings sections and preferences.
- Task 26 owns real-machine Phase B benchmark/evidence gate.
- Deep Dive remains no-go/paused.

The final automatic report is retained at
`/tmp/stornaut_task21_final_review_1786332053/report.html`; it has no open
P0–P2 finding.
