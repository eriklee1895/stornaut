# Task 23 Implementation Brief — Quick Scan Progress and Results

> 状态：Completed
>
> 日期：2026-08-10
>
> 上位计划：[Epic 2–4 Deterministic Product Core](epic-2-4-deterministic-product-core.md)
>
> Study gate：[Epic 2–4 Native UI Study](../../upstream-studies/epic-2-4-ui.md#13-task-23-quick-scan-progress-and-results-refresh)

## 1. Objective

Replace only the Scan placeholder with a real user-initiated Quick Scan
workspace backed by `QuickScanCoordinator`.

Task 23 is complete only when:

- entering Scan does not start work;
- an explicit Run/Scan Again intent starts one deterministic local scan;
- the App model, not a View or navigation lifetime, owns the stream task;
- five stages, scope count, candidate count, measured allocated bytes and
  elapsed time remain separate and honest;
- progressive facts and terminal results share one stable grouped surface;
- Stop Scan is neutral and retains the coordinator's partial snapshot;
- completed, partial, cancelled, permission-limited and store-failure outcomes
  preserve valid facts;
- results and Evidence Inspector are read-only;
- no Review, Trash, Registered Action, Codex or Deep Dive process is enabled;
- Light/Dark and English/`zh-Hans` render in the real App.

## 2. Files

Create:

```text
StornautApp/Scan/ScanFlowState.swift
StornautApp/Scan/ScanModel.swift
StornautApp/Scan/ScanView.swift
StornautApp/Scan/ScanStageRail.swift
StornautApp/Scan/ScanResultsTable.swift
StornautApp/Scan/ScanEvidenceInspector.swift
StornautAppTests/ScanAppModelTests.swift
StornautAppTests/ScanFlowReducerTests.swift
StornautAppTests/ScanModelTests.swift
scripts/verify-scan-boundaries
docs/reports/epic-2-4-task-23-review.md
```

Modify:

```text
StornautApp/AppShell/RootView.swift
StornautApp/AppState/AppDependencies.swift
StornautApp/AppState/DebugAppFixtures.swift
StornautApp/AppState/StornautAppModel.swift
Sources/StornautCore/QuickScan/QuickScanCoordinator.swift
Sources/StornautCore/QuickScan/QuickScanState.swift
StornautAppTests/AppFixtureTests.swift
StornautAppTests/AppStateTests.swift
StornautAppUITests/StornautAppUITests.swift
Tests/StornautCoreTests/QuickScanIntegrationTests.swift
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
file edits. The exact file split may be reduced when adjacent View code remains
clear; responsibilities and boundary tests are mandatory.

## 3. App-Owned Scan Contract

`AppDependencies` exposes three typed operations:

```text
load latest QuickScanProjection
start QuickScanProductEvent stream
cancel the active Quick Scan
```

One actor-owned runtime resolves and reuses one `QuickScanCoordinator`.
Production composition creates each `ScanRequest` with the current user's home
directory as the Phase B default root. Task 25 replaces this default with
configured roots/exclusions. A SwiftUI View never reads the home directory or
constructs the request, coordinator, store or Surveyor. The same composition
exposes the root as a typed `PersistedPath` so the Inspector can render an exact
path without filesystem access.

The product stream exposes each progressive result as one paired classified
snapshot event. It does not forward every persisted traversal snapshot into App
state; full traversal facts stay in the bounded Core persistence path.

DEBUG/UI fixtures inject deterministic streams and never scan the real home.
Tests that exercise live composition must pass a temporary root explicitly.

`StornautAppModel` owns the stream-consumer `Task`. It exposes synchronous typed
intents for Run and Stop and publishes a closed `ScanFlowState`. Selecting
Overview, History or Investigations cannot cancel the task. A second Run intent
while active is ignored at the App boundary and remains rejected by the
coordinator boundary.

The authoritative terminal projection is also reduced through
`AppPageReducer` so Overview and Scan converge on the same latest snapshot.

## 4. Reducer and Progress Contract

The pure `ScanFlowReducer` accepts:

- explicit start with an injected timestamp;
- every closed `QuickScanProductEvent`;
- explicit stop-request acknowledgement;
- stream/start failure;
- elapsed-time ticks while active.

It rejects regressive or skipped stage presentation and uses this exact order:

1. Index Volumes
2. Map Projects
3. Classify Artifacts
4. Check Activity
5. Finalize Snapshot

The state keeps:

- active/idle/terminal phase;
- current stage and stage statuses;
- current relative path and scope ID;
- scanned entry count from `ScanProgress.completedEntries`;
- measured allocated bytes from non-negative
  `ScanProgress.allocatedFileBytes`;
- distinct candidate snapshot IDs observed through classifications;
- progressively observed classified snapshot pairs, evidence and ledger;
- latest authoritative terminal projection;
- start time and elapsed duration;
- stop-request state and safe failure reason.

No percentage is shown because the stream has no trustworthy total-work
denominator. Snapshot bytes are not summed into measured progress when the
coordinator already supplies an allocated-byte counter.

## 5. Results Projection

`ScanModel` is a deterministic projection over the flow state and optional
retained `AppPageState` projection.

Rows require stable snapshot identity. A joined classification supplies:

- lifecycle category;
- producer;
- recovery method key and rebuild cost;
- disposition;
- missing evidence requirements.

The classified snapshot supplies:

- exact relative path;
- item/path summary;
- conservative Last Active using `modifiedAt` only, labeled as filesystem
  modification rather than an unsupported app-use claim.

Terminal allocated size comes only from a matching `SpaceLedgerOwner`; a
directory entry's inode size is never presented as subtree occupancy. Before
the ledger exists, allocated size is an em dash with Pending Final Accounting.
Evidence records join by snapshot ID. Supporting and missing evidence remain
separate. Unknown rows are not decorated as AI findings. Root bookkeeping rows
are omitted from the classified grouped outline but remain counted in scan
progress.

Group order is the seven closed `ArtifactCategory` cases. Within a group:

```text
disposition priority
→ allocated bytes descending, nil last
→ relative path ascending
→ snapshot ID ascending
```

Search matches item/path and producer locally. Filters are All, Ready, Review,
Unknown and Protected. Filtering changes no underlying classification.

## 6. Stable View and Interaction Contract

The Scan page keeps one structural hierarchy:

1. local deterministic/no-Codex header;
2. Run Quick Scan or neutral Stop Scan;
3. four metrics: Scope Scanned, Candidates Found, Measured, Elapsed;
4. compact five-stage rail;
5. one-line current-scope strip;
6. search/disposition controls;
7. grouped result outline/table;
8. separate Ready, Review, Unknown and Protected summary.

Idle shows no fabricated progress and waits for the user. Active state grows
the same rows used by terminal results. Stop text explicitly states that
measured partial results are retained.

Selection opens the native trailing Inspector. Inspector data is immutable and
contains producer, lifecycle, activity/evidence, recovery, missing evidence,
exact path, allocated measurement and disposition. Closing or changing
selection has no domain effect.

The approved result specification's enabled `Review Reclaim Plan` conflicts
with the narrower active Phase B plan. Task 23 follows the active plan:

- no enabled Review CTA;
- no checkbox or selection for cleanup;
- no Reveal/Copy action unless a typed local intent is implemented and tested;
- no Investigate action or Codex launch;
- a visible future Review affordance must be disabled and labeled unavailable.

## 7. State Matrix

| State | Stable content | Inline truth | Safe action |
| --- | --- | --- | --- |
| Idle, no snapshot | empty grouped surface | no scan has started | Run Quick Scan |
| Idle, retained snapshot | latest results | snapshot timestamp/status | Scan Again |
| Active | progressive facts | current stage/scope and honest counters | Stop Scan |
| Stop requested | progressive facts | finishing and retaining partial snapshot | none |
| Cancelled | committed partial facts | stopped by user, unfinished scope | Scan Again |
| Partial | healthy committed facts | typed affected stage/scope | Scan Again |
| Permission limited | healthy measurable facts | missing scope remains unmeasurable | Scan Again |
| Store/start failure | retained valid projection | local persistence/start reason | Try Again |
| Completed | authoritative projection | complete snapshot | Scan Again |

## 8. Accessibility and Localization

- stages expose ordinal, label and Complete/Current/Pending text;
- status never relies on color alone;
- metrics are individual title/value accessibility elements;
- table rows and group headers have stable IDs and summaries;
- selection and Inspector work with keyboard and VoiceOver;
- exact bytes include actual byte count in accessibility text;
- nil/unmeasurable bytes use an em dash plus localized reason, never `0 B`;
- long paths truncate visually but the Inspector exposes the exact path;
- system type, semantic colors and SF Symbols only;
- English and `zh-Hans` keys remain in parity;
- no decorative animation is required, so Reduce Motion does not hide state.

## 9. Tests First

Initial tests must fail on missing Task 23 types/APIs and cover:

1. idle does not start automatically;
2. all five stage transitions and explicit status mapping;
3. scope count, candidates, measured bytes and elapsed remain separate;
4. progressive snapshot/classification/evidence/ledger accumulation;
5. explicit stop and idempotent cancellation;
6. cancelled, partial, permission-limited, store-failure and completed
   terminals;
7. retained valid projection after start/stream failure;
8. one active model task and navigation-independent lifetime;
9. grouping, stable ordering, search and all filters;
10. Recovery and Disposition remain separate;
11. missing measurements use em dash plus reason;
12. Inspector joins supporting/missing evidence and stays read-only;
13. DEBUG fixtures use fake streams and never invoke production start;
14. source/dependency gate forbids View references to Surveyor, SQLite, Codex,
    Policy, Executor, Trash or action APIs.

## 10. Verification

```text
red scan reducer/model tests + source gate
→ implement App-owned composition and Views
→ focused App tests
→ live temporary-root App model integration
→ build/launch real Debug App
→ read-only Peekaboo in-progress + partial + completed captures
→ XCUITest English/zh-Hans and Light/Dark screenshot attachments
→ bits-code-guard grouped review and fixes
→ scripts/verify
→ docs/provenance update
```

Task 23 uses one reviewed commit:

```text
feat: deliver quick scan results
```

Final evidence:

- SwiftPM 263/263, including 17 focused Quick Scan integration tests;
- App tests 57/57;
- XCUITest 5/5 and nine screenshot contracts;
- read-only Peekaboo real-App captures for active Dark, partial Light and
  completed Light Inspector with distinct window IDs;
- `scripts/verify`: exit 0;
- final grouped review:
  `/tmp/stornaut_task23_review_1786343771/report.html`, no open P0–P2.

## 11. Explicit Non-goals

- no configured roots/exclusions UI before Task 25;
- no History implementation;
- no Investigations implementation;
- no Deep Dive/Codex enablement;
- no Review workflow, Cleanup Manifest, Trash or Registered Action;
- no filesystem mutation under the scan target;
- no enabled Reveal/Copy shell integration;
- no raster/vector asset generation;
- no dependency, entitlement, telemetry, background task or scheduler.
