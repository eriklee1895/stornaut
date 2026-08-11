# Task 24 Implementation Brief — Scan-Only History

> 状态：Completed and verified
>
> 日期：2026-08-10
>
> 上位计划：[Epic 2–4 Deterministic Product Core](epic-2-4-deterministic-product-core.md)
>
> Study gate：[Epic 2–4 Native UI Study](../../upstream-studies/epic-2-4-ui.md#14-task-24-scan-only-history-refresh)

## 1. Objective

Replace only the History placeholder with a real local Quick Scan history
workspace backed by typed Evidence Store records.

Task 24 is complete only when:

- History loads real paged scan sessions and matching Space Ledgers;
- corrupt records are isolated without hiding healthy siblings;
- navigator records are grouped Today, Yesterday and Earlier;
- selection defaults to the newest healthy record and is keyboard stable;
- terminal state, coverage, lineage, retention and ledger measures remain
  distinct and evidence-backed;
- expired records are labeled and never treated as current truth;
- deletion is explicitly confirmed and removes only the selected Evidence
  session graph;
- deletion cannot touch scanned files, Trash or Local Knowledge;
- Storage Trend appears only after four comparable user-initiated Quick Scan
  snapshots;
- no synthetic Deep Dive, Cleanup Manifest, export, causality or background
  collection claim is added;
- Light/Dark and English/`zh-Hans` render in the real App.

## 2. Files

Create:

```text
StornautApp/History/HistoryState.swift
StornautApp/History/HistoryModel.swift
StornautApp/History/HistoryView.swift
StornautApp/History/HistoryNavigator.swift
StornautApp/History/HistoryDetailView.swift
StornautApp/History/StorageTrendView.swift
StornautAppTests/HistoryModelTests.swift
StornautAppTests/HistoryAppModelTests.swift
scripts/verify-history-boundaries
docs/reports/epic-2-4-task-24-review.md
```

Modify:

```text
Sources/StornautCore/Evidence/EvidenceStore.swift
Tests/StornautCoreTests/EvidenceStoreTests.swift
StornautApp/AppShell/RootView.swift
StornautApp/AppState/AppDependencies.swift
StornautApp/AppState/DebugAppFixtures.swift
StornautApp/AppState/StornautAppModel.swift
StornautAppTests/AppFixtureTests.swift
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
file edits. The exact View split may be reduced when responsibilities remain
clear; state, projection and boundary tests are mandatory.

## 3. Typed Store and App Dependency Contract

Add a closed `ScanHistoryPage` contract:

```text
sessions: [ScanSession]
ledgersBySessionID: [ScanSessionID: SpaceLedger]
corruptSessionIDs: [String]
corruptLedgerSessionIDs: [String]
```

`EvidenceStore.scanHistory(limit:offset:)`:

- validates the existing 1...100 page bound;
- loads sessions in `finishedAt DESC, id ASC`;
- batch-loads ledgers for the healthy page session IDs with one bounded query;
- validates ledger row ID, parent ID and closed payload;
- isolates a corrupt ledger to its session ID;
- returns no snapshots, classifications, raw evidence or generic payload.

`AppDependencies` exposes:

```text
load first ScanHistoryPage
delete one ScanSessionID
```

The actor-owned App runtime reuses the same `EvidenceStore` that backs its
`QuickScanCoordinator`. Views never construct or call the store.

Deletion returns only after the Evidence transaction/cascade completes. App
state reloads the page and moves selection predictably. A failed delete keeps
the record and exposes a localized page-preserving error.

## 4. History State and Projection

`HistoryState` is App-owned and closed:

```text
idle
loading(retained page?)
loaded(page)
deleting(retained page, target)
error(retained page?, reason)
```

`HistoryModel` is a pure projection over History state, current time, query,
terminal filter and date filter.

Valid navigator records contain:

- session ID and Quick Scan type;
- started/finished times and duration;
- terminal state;
- canonical completed or unfinished scope;
- exact expiry = `finishedAt + 7 days`;
- retention state/countdown;
- ledger-backed Known bytes and measured Used/Free values when available;
- coverage gap count and ledger caveats;
- per-record ledger-unavailable/corrupt status.

Corrupt session rows contain only a stable corrupt record ID and a read error.
They are never decoded into a fake session, size, scope or status.

Stable navigator ordering:

```text
finishedAt descending
→ session ID ascending
→ corrupt rows after healthy rows without a trustworthy timestamp
```

Date groups are Today, Yesterday and Earlier using injected Calendar/time-zone
semantics. Filters never alter persisted records.

## 5. Detail and Retention Contract

The selected healthy detail shows:

1. Quick Scan and terminal status;
2. exact start, finish and duration;
3. completed/unfinished scopes and reason;
4. retention badge, exact expiry and countdown;
5. Known, Unknown, Unmeasurable and Free as separate measures;
6. volume capacity, source identifiers/sample times and caveats;
7. Related Records wording limited to scan → snapshot/ledger lineage;
8. fixed non-causality statement;
9. `Delete Record…` destructive footer action.

Missing ledger or corrupted ledger produces an inline unavailable state without
hiding the session. Missing bytes use an em dash plus reason, never `0 B`.

An already open selected record may remain visibly Expired until a reload.
Production `loadLatest` and `loadHistory` sweep expired Evidence before reading,
so expired records do not re-enter Overview or a newly loaded History page.

Delete confirmation must name the selected Quick Scan record and state:

- deletion cannot be undone;
- files on disk are unchanged;
- Trash is unchanged;
- prior cleanup effects are unchanged;
- Local Knowledge is unchanged.

No `Adjust Retention` action is added.

## 6. Storage Trend Contract

Comparable trend samples require:

- completed terminal session;
- ledger status not inconsistent;
- measured capacity and free values;
- `free <= capacity`;
- distinct session ID/timestamp.

Only four or more comparable samples enable `Storage Trend`. The substate:

- replaces the detail pane, not the whole workspace;
- plots exact Used and Free values in timestamp order;
- differentiates direct labels, line styles and semantic colors;
- exposes every point in a data table and accessibility summary;
- displays `Events mark when records were created. They do not prove what
  caused a storage change.`;
- has no forecast, anomaly, smoothing, live update or causal arrow.

Because every Phase B Quick Scan is user initiated and no background scheduler
exists, no additional persisted initiation flag is invented in Task 24.

## 7. Action Boundary

Phase B History:

- loads and deletes local Evidence records only;
- never scans automatically;
- never restores or removes files;
- never opens or mutates Trash;
- never reads/writes Local Knowledge;
- never creates synthetic Cleanup Manifest rows;
- never starts Codex or Deep Dive;
- never attributes a storage delta to an event.

`Export Record…` is not implemented or displayed in Task 24. A future typed
exporter must separately prove canonical-home redaction, residual path privacy,
atomic destination writes and save-panel lifecycle. A dead or fake action is
not acceptable.

## 8. Accessibility and Localization

- navigator rows expose type, time, status, metric and retention in reading
  order;
- current selection has the selected accessibility trait;
- keyboard selection changes no domain state;
- terminal, expired and corrupt states use icon plus text, not color alone;
- delete confirmation and result are VoiceOver-readable;
- trend points expose exact timestamp, Used and Free values plus data table;
- system type, semantic colors and SF Symbols only;
- English and `zh-Hans` keys remain in parity;
- no decorative animation; Reduce Motion does not hide state.

## 9. Tests First

Initial tests must fail on missing Task 24 APIs/types and cover:

1. empty/loading/loaded/error/deleting phases;
2. newest healthy default selection;
3. Today/Yesterday/Earlier grouping with injected Calendar;
4. current, partial, cancelled, failed and expired sessions;
5. corrupt session and corrupt/missing ledger isolation;
6. search, terminal and date filters;
7. exact seven-day expiry/countdown;
8. Known/Unknown/Unmeasurable/Free separation;
9. stable ordering and no fabricated type/size/status;
10. trend unavailable for fewer than four comparable snapshots;
11. trend exact values/order/non-causality with four snapshots;
12. batch ledger query contract and page bound;
13. confirmed deletion cascade and predictable next selection;
14. target tree, Trash marker and Local Knowledge unchanged by deletion;
15. DEBUG fixtures never touch the production store;
16. source gate forbids History View references to Surveyor, SQLite, Codex,
    Policy, Executor, Trash or Local Knowledge mutation APIs.

## 10. Verification

```text
red History/Core tests + source gate
→ implement typed batch read/delete and pure projection
→ focused Core/App tests
→ real temporary-store integration and target/knowledge audit
→ build/launch real Debug App
→ read-only Peekaboo populated + expired + corrupt captures
→ XCUITest Light/Dark and stable screenshot attachments
→ bits-code-guard grouped review and fixes
→ scripts/verify
→ docs/provenance update
```

Task 24 uses one reviewed commit:

```text
feat: add scan history workspace
```

Final evidence:

- grouped review report:
  [Epic 2–4 Task 24 Code Review](../../reports/epic-2-4-task-24-review.md);
- SwiftPM 267/267, App tests 79/79, XCUITest 7/7;
- thirteen stable screenshot attachments including Storage Trend Dark;
- signed real-App Peekaboo captures for populated/expired/corrupt/trend;
- no open P0–P2 finding after the final review pass;
- no new dependency, entitlement, product permission or deferred feature.

## 11. Explicit Non-goals

- no Deep Dive/report/Manifest history rows;
- no Cleanup execution or causal attribution;
- no export/save-panel implementation;
- no configurable retention;
- no history pagination UI beyond the first bounded page;
- no configured roots/exclusions before Task 25;
- no new dependency, entitlement, telemetry, background task or scheduler.
