# Task 21 Implementation Brief — App State, Fixtures and Design System

> 状态：Completed
>
> 日期：2026-08-10
>
> 上位计划：[Epic 2–4 Deterministic Product Core](epic-2-4-deterministic-product-core.md)
>
> Study gate：[Epic 2–4 Native UI Study](../../upstream-studies/epic-2-4-ui.md#11-task-21-app-state-composition-refresh)

## 1. Objective

Establish the App-owned state boundary and the smallest semantic UI primitives
needed by Tasks 22–25 without implementing those destination pages.

Task 21 is complete only when:

- production composition can load the latest real Quick Scan projection;
- SwiftUI Views only read App state and send typed intents;
- reducer state preserves valid pages across loading, stale and local failure;
- DEBUG fixture selection is closed, deterministic and absent from Release
  behavior;
- semantic byte/status/disposition/coverage/retention primitives are
  localized, accessible and theme-independent;
- the four existing destination placeholders remain placeholders;
- focused, architecture, App, UI and unified verification pass.

## 2. Files

Create:

```text
StornautApp/AppState/AppDependencies.swift
StornautApp/AppState/AppPageState.swift
StornautApp/AppState/StornautAppModel.swift
StornautApp/AppState/DebugAppFixtures.swift        #if DEBUG only
StornautApp/DesignSystem/StornautFormatters.swift
StornautApp/DesignSystem/SemanticStatus.swift
StornautApp/DesignSystem/AppPhaseStatus.swift
StornautApp/DesignSystem/EmptyStateView.swift
StornautApp/DesignSystem/MetricTile.swift
StornautApp/DesignSystem/ReclaimDispositionLabel.swift
StornautApp/DesignSystem/CoverageBadge.swift
StornautApp/DesignSystem/RetentionBadge.swift
StornautApp/DesignSystem/RecoveryStateView.swift
StornautAppTests/AppStateTests.swift
StornautAppTests/AppFixtureTests.swift
StornautAppTests/DesignSystemTests.swift
scripts/verify-app-state-boundaries
scripts/verify-app-release-boundaries
docs/reports/epic-2-4-task-21-review.md
```

Modify:

```text
StornautApp/StornautApp.swift
StornautApp/AppShell/RootView.swift
StornautApp/Resources/en.lproj/Localizable.strings
StornautApp/Resources/zh-Hans.lproj/Localizable.strings
scripts/verify
docs/plans/active/epic-2-4-deterministic-product-core.md
docs/agent/coding-agent-handoff.md
AGENTS.md
```

The file-system-synchronized Xcode groups include new Swift files without
manual project-file entries.

## 3. State Contract

`AppPagePhase` is a closed enum:

```text
empty
loading
partial
cancelled
success
limitedPermission
stale
error
```

`AppPageState` carries:

- `phase`;
- optional latest `QuickScanProjection`;
- typed/localization-safe reason key;
- optional safe recovery intent;
- refresh timestamp.

Invariants:

- success requires a completed projection;
- partial/cancelled/limited require the corresponding projection truth;
- loading, stale and error may retain the prior projection;
- error never erases a previously valid projection;
- no projection means Unknown/empty, never synthetic `0 B`;
- a corrupt or dependent failure remains page-preserving.

The reducer has pure operations for:

```text
beginRefresh(previous)
loaded(projection?, previous, now)
failed(reasonKey, previous, now)
markStale(previous, reasonKey, now)
```

## 4. Dependency Boundary

`AppDependencies` exposes only:

```swift
loadLatestQuickScan() async throws -> QuickScanProjection?
```

Production composition:

```text
LocalStoreConfiguration.production()
→ EvidenceStore
→ QuickScanCoordinator
→ loadLatest()
```

`StornautAppModel` owns dependencies and reducer transitions. `RootView`,
destination views and DesignSystem files must not reference:

```text
Surveyor
ScanSessionWriter
EvidenceStore
SQLite
StornautCodex
Codex
Probe
Policy
Executor
Trash
RegisteredAction
```

Task 21 does not expose a Quick Scan start/stop intent. Task 23 owns that
interaction.

## 5. DEBUG Fixture Contract

Exact argument:

```text
--stornaut-debug-fixture=<fixture-id>
```

Closed IDs:

```text
empty
loading
partial
cancelled
success
limited-permission
stale
error
```

Rules:

- implementation and sample values are wrapped in `#if DEBUG`;
- exactly one known selector activates a fixture;
- missing, unknown, malformed or duplicate selectors select production;
- fixture state is built from real `StornautCore` domain constructors;
- fixtures write no production database and start no scan/process;
- Release source path contains no fixture activation behavior.

## 6. Design-System Boundary

Task 21 creates semantic primitives, not a broad framework:

- byte formatting distinguishes `nil`/Unknown from measured zero;
- values use tabular figures and localized unit formatting;
- disposition maps to localized label + SF Symbol + semantic role;
- coverage and retention badges expose text/icon, never color alone;
- recovery state preserves supplied content and exposes at most one primary
  safe recovery action plus one quiet secondary action;
- MetricTile renders supplied values only and performs no accounting.

No raw image-model hex values or page-specific layout constants are copied.
System dynamic colors and the approved semantic roles are used.

## 7. Tests First

Initial tests must fail on missing Task 21 types/APIs and cover:

1. all eight phases;
2. page-preserving loading/error/stale transitions;
3. completed/partial/cancelled/permission projection mapping;
4. production dependency loading from an in-memory `EvidenceStore`;
5. closed fixture selector behavior and deterministic fixture equality;
6. unknown bytes render em dash/Unknown, while measured zero renders `0 B`;
7. every disposition has a localized label, icon and semantic role;
8. coverage/retention/recovery semantics;
9. source gate for View/service separation;
10. Release build contains no DEBUG fixture selection marker.

## 8. Verification

```text
focused App state/design-system tests
→ scripts/verify-app-state-boundaries
→ complete SwiftPM suite
→ Xcode App contract tests
→ real Debug App + read-only Peekaboo
→ XCUITest + four Light/Dark screenshots
→ scripts/verify
→ bits-code-guard review and fixes
→ final scripts/verify
```

Task 21 uses one reviewed commit:

```text
feat: establish deterministic app state
```

Final evidence:

- `scripts/verify` passed on 2026-08-10;
- SwiftPM 263/263, App tests 22/22 and XCUITest 3/3 passed;
- four Light/Dark screenshots, App-state source boundaries, Debug-positive /
  Release-negative fixture isolation, signing/bundle, localization, catalogs
  and documentation checks passed;
- final grouped review has no open P0–P2 finding:
  `/tmp/stornaut_task21_final_review_1786332053/report.html`.

## 9. Explicit Non-goals

- no Overview implementation;
- no Quick Scan progress/results UI;
- no History UI;
- no six-section Settings implementation;
- no Deep Dive enablement;
- no App-level scan startup;
- no cleanup/review/action UI;
- no background task, MenuBarExtra, scheduler or telemetry;
- no new third-party dependency or asset.
