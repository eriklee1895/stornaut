# Task 22 Implementation Brief — Snapshot-First Overview

> 状态：Completed
>
> 日期：2026-08-10
>
> 上位计划：[Epic 2–4 Deterministic Product Core](epic-2-4-deterministic-product-core.md)
>
> Study gate：[Epic 2–4 Native UI Study](../../upstream-studies/epic-2-4-ui.md#12-task-22-snapshot-first-overview-refresh)

## 1. Objective

Replace only the Overview placeholder with a real snapshot-first page backed by
the latest `QuickScanProjection`.

Task 22 is complete only when:

- no-snapshot, current, stale, scan-in-progress, permission-limited and local
  store failure states are deterministic and page-preserving;
- Free, Explained and Ready to Reclaim are distinct metrics;
- Known, Unknown, Unmeasurable and Free stay distinct in the Space Ledger;
- the orbit, ledger, opportunities and recovery UI consume typed projection
  values only;
- Quick Scan is the only primary action and routes to Scan without starting a
  scan;
- Deep Dive is visibly safety-paused and cannot start;
- at most three real opportunities are shown;
- VoiceOver receives exact values, sources, sample time and coverage status;
- Light/Dark and English/`zh-Hans` render in the real App;
- Scan, Investigations and History remain placeholders.

## 2. Files

Create:

```text
StornautApp/Overview/OverviewModel.swift
StornautApp/Overview/OverviewView.swift
StornautApp/Overview/StorageOrbitView.swift
StornautApp/Overview/SpaceLedgerView.swift
StornautApp/Overview/OverviewOpportunityRow.swift
StornautAppTests/OverviewModelTests.swift
scripts/verify-overview-boundaries
docs/reports/epic-2-4-task-22-review.md
```

Modify:

```text
StornautApp/AppShell/RootView.swift
StornautApp/AppState/DebugAppFixtures.swift
StornautAppTests/AppTestProjectionFactory.swift
StornautAppUITests/StornautAppUITests.swift
StornautApp/Resources/en.lproj/Localizable.strings
StornautApp/Resources/zh-Hans.lproj/Localizable.strings
scripts/verify
scripts/export-ui-screenshots
scripts/verify-ui-screenshots
docs/upstream-studies/epic-2-4-ui.md
docs/plans/active/epic-2-4-deterministic-product-core.md
docs/agent/ui-testing-guide.md
AGENTS.md
```

File-system-synchronized Xcode groups include new Swift files without project
file edits.

## 3. Projection Contract

`OverviewModel` is a pure, throwable projection from `AppPageState`.

It exposes:

- presentation phase and retained snapshot timestamp;
- scope label and coverage;
- Free metric from `ledger.free`;
- Explained bytes from `ledger.known`;
- Explained ratio from `known / (capacity - free)` when measured;
- Ready to Reclaim bytes from real ready owners only;
- ledger rows for Known, Unknown, Unmeasurable and Free;
- deterministic orbit aggregates;
- at most three opportunities from real Ready/Review owners;
- safe recovery state and Deep Dive paused state.

Arithmetic is checked. Invalid or inconsistent arithmetic fails closed to
Unknown instead of wrapping or guessing.

`unknownIncludesUnmeasurable` forbids double-counting: unmeasurable remains a
separate unquantified coverage row, while Unknown owns the measured residual
segment.

## 4. Stable Ordering and Opportunity Rules

Opportunity candidates require:

- a joined `SpaceLedgerOwner` and `Classification`;
- `readyToReclaim` or `reviewRecommended`;
- measured allocated bytes;
- no Protected or Unknown disposition.

Ordering:

```text
Ready to Reclaim before Review Recommended
→ allocated bytes descending
→ relative path ascending
→ classification ID ascending
```

Only the first three are rendered. Producer and recovery text come from real
classification fields. Activity summary is conservative and derived from typed
evidence/missing requirements; absence of evidence never becomes Inactive.

## 5. View and Interaction Contract

The page uses one main `ScrollView`:

1. volume/snapshot/coverage header;
2. Free, Explained and Ready to Reclaim metrics;
3. medium code-native Storage Orbit plus full Space Ledger;
4. Quick Scan primary entry and disabled safety-paused Deep Dive;
5. Top Opportunities, at most three rows.

No star field, constellation, raster background, raw concept palette, chat,
terminal, AI badge, cleanup CTA or generic dashboard grid is added.

Task 22 action boundary:

- `Run Quick Scan` / `Scan Again` selects `AppDestination.scan`;
- it does not call `QuickScanCoordinator.start`;
- no scan cancel/progress implementation;
- Deep Dive has no start callback or bypass.

## 6. State Matrix

| State | Preserved content | Inline state | Safe action |
| --- | --- | --- | --- |
| Empty | none | code-native no-snapshot state | Go to Scan |
| Loading, no projection | none | loading without fake progress | none |
| Loading, retained projection | latest snapshot | scan-in-progress summary | View Scan |
| Success | latest snapshot | complete/current | Go to Scan |
| Partial/cancelled | valid projection | affected scope and reason | Go to Scan |
| Limited permission | measured projection | coverage gap, no `0 B` | Review Permissions |
| Stale | full retained snapshot | scanned-time stale banner | Go to Scan |
| Error, retained projection | full retained snapshot | local failure banner | Retry latest load |
| Error, no projection | none | store unavailable state | Retry latest load |

Task 25 owns the real Permissions destination. Until then,
`reviewPermissions` is rendered as an explanatory disabled recovery affordance,
not a broken navigation or System Settings automation.

## 7. Accessibility and Localization

- orbit is a custom Canvas with synthetic accessible child elements;
- each ledger row exposes label, exact formatted value or localized Unknown,
  status, source and sample time;
- no state relies on color alone;
- metrics expose one title/value pair;
- system type, SF Symbols and semantic colors only;
- English and `zh-Hans` keys remain in parity;
- exact dates/bytes are localized and tabular;
- keyboard order matches visual order;
- no decorative animation; Reduce Motion has no special branch to maintain.

## 8. Tests First

Initial tests must fail on missing Task 22 types/APIs and cover:

1. the six required Overview states plus page-preserving partial/cancelled;
2. exact metric separation;
3. Unknown/Unmeasurable separation and no double-count;
4. checked arithmetic and zero-used Explained behavior;
5. deterministic opportunity join/order/limit;
6. Protected/Unknown exclusion;
7. activity-summary conservative fallback;
8. source/sample/coverage accessibility metadata;
9. state action mapping and Deep Dive no-go;
10. both localization tables;
11. source gate proving Overview has no service/start/action dependency.

## 9. Verification

```text
red Overview tests + source gate
→ implement projection and Views
→ focused App tests
→ build/launch real Debug App
→ read-only Peekaboo Light/Dark current + limited state captures
→ XCUITest English/zh-Hans and stable Overview screenshot attachments
→ bits-code-guard grouped review and fixes
→ scripts/verify
→ docs/provenance update
```

Task 22 uses one reviewed commit:

```text
feat: render snapshot-first overview
```

Current evidence:

- SwiftPM 263/263 and App tests 33/33 pass;
- final unified XCUITest 4/4 and six screenshot checks pass;
- English/Chinese real-App Peekaboo PID captures pass;
- grouped review has no open P0–P2 finding:
  `/tmp/stornaut_task22_final_review_1786340140/report.html`;
- final `scripts/verify` passed after the user completed the standard macOS
  Automation Mode authentication;
- no no-authentication policy, root daemon, TCC/SIP or system permission was
  modified.

## 10. Explicit Non-goals

- no scan start/stop/progress or results page;
- no History implementation;
- no Investigations implementation;
- no full Settings or Permissions navigation;
- no Deep Dive enablement;
- no cleanup/review/action UI;
- no raster/vector asset generation;
- no new dependency, entitlement, telemetry, background task or scheduler.
