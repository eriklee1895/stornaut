# Task 34 Implementation Brief — Manifest-aware History and Retention

> Status: Complete; authoritative full verifier passed
>
> Date: 2026-08-14
>
> Baseline:
> `435e2a050c516fa15f33b7fb8012610b7afc78e9`
>
> Parent plan:
> [Epic 8 Safe Execution Vertical Slice](epic-8-safe-execution-vertical-slice.md)
>
> Accepted inputs:
> [ADR 0012](../../adr/0012-cleanup-execution-journal.md),
> [Task 33 Review](../../reports/epic-8-task-33-review.md),
> [UI/UX §10](../../design/ui-ux.md#10-cleanup-result-与-history) and
> [History Round 1](../../assets/ui-concepts/HISTORY-ROUND-1.md)

## 1. Objective

Task 34 extends the existing native History workspace from scan-only history
to one typed, read-only audit union:

```text
Quick Scan session
Cleanup Manifest
isolated corrupt Quick Scan row
isolated corrupt Cleanup Manifest row
```

The implementation reuses the current Evidence Store v3 records. It does not
create Store v4, copy Manifest data into another table, rewrite immutable
Manifests or turn the execution journal into a second user-facing history.

The Task is complete only when:

- Quick Scan and Cleanup Manifest records share deterministic date/type/ID
  ordering and selection;
- Cleanup Manifest paging is bounded and does not truncate retained records;
- linked Plan facts enrich a Manifest only while the seven-day record remains
  valid and exactly bound to the Manifest;
- after linked Evidence expires, History retains only the 90-day minimal
  Manifest and never reconstructs item names, paths or Trash destinations;
- corrupt scan and Manifest rows are isolated independently;
- deleting one Manifest is confirmed and atomically removes only that local
  Manifest plus its exactly associated audit/recovery journal, if present;
- scan deletion cannot remove a retained Manifest and Manifest deletion
  cannot remove a scan, user file, Trash item or Local Knowledge;
- moved-to-Trash, permanent release and free-space observations stay separate;
- Storage Trend event markers remain explicitly non-causal;
- History has no filled primary action and no cleanup execution affordance;
- App/UI tests, actual signed Debug App evidence, Peekaboo inspection,
  independent review, the authoritative full verifier and one commit/push are
  complete.

## 2. Planning Corrections

### 2.1 Store v3 already contains the required durable truth

Task 28 already added insert-only `cleanup_manifests`, mutable private
`cleanup_run_journals`, seven-day `cleanup_plans` and independent retention
operations. Task 34 adds query/deletion behavior on those records and keeps
`user_version = 3`.

No migration is justified because:

- Manifest paging already has a stable `created_at_ms DESC, id ASC` indexable
  order;
- a Manifest already binds its Plan ID and all stable action/item IDs;
- the Plan is the existing seven-day path-rich record;
- the Manifest is already the 90-day minimal audit;
- adding a duplicate History table would create mutable drift.

### 2.2 Manifest enrichment is a join, not Manifest content

The Core History projection has two layers:

```text
Cleanup Manifest history record
├── immutable CleanupManifest
└── optional exactly matching CleanupPlan
```

The Plan may provide display-only relative item labels and Evidence lineage
when all of these hold:

- the Plan is still retained and current;
- `plan.id == manifest.planID`;
- every Manifest item ID belongs to the Plan;
- action and item identity bindings remain consistent;
- the Plan has not reached its seven-day expiry.

Any missing, corrupt, expired or mismatched Plan makes enrichment
`evidenceExpired`. History then shows stable Manifest/action/item IDs and
minimal result/accounting/error facts only. It does not guess names, rebuild
paths from the current filesystem or retain a new enrichment cache.

### 2.3 History paging has two independent retention clocks

Quick Scan sessions expire after seven days. Cleanup Manifests expire after
ninety days. The App loader:

- runs the existing retention operation before presenting History;
- pages scan and Manifest sources with bounded page sizes;
- merges only decoded typed records;
- sorts by event time descending, record type, then stable ID;
- keeps corrupt IDs typed by source;
- never treats one source's empty page as proof that the other is empty.

The UI date filter uses each record's event timestamp. The navigator retention
badge uses the record's own expiry.

### 2.4 Deletion is local-record deletion, never cleanup

`deleteCleanupManifest(id:)` is one Evidence Store transaction:

1. decode and identity-check the selected Manifest;
2. identify only journals whose decoded `manifestID` exactly matches it;
3. delete matching audit/recovery journal rows;
4. delete the Manifest row.

It does not delete the Plan, scan session, Evidence, file, Trash item or Local
Knowledge. A corrupt journal that cannot prove the exact binding cannot be
silently associated. Failure rolls the transaction back.

Deleting a Quick Scan keeps the current Task 28 behavior: seven-day Plan and
evidence-linked journal data may cascade or expire, but retained Manifests do
not. The post-delete History reload proves the other record class remains.

### 2.5 Export is a secondary read-only projection

History exposes a secondary `Export Record…` action. The selected record is
projected to bounded JSON before the native save panel:

- a Quick Scan export contains the retained session/ledger summary and
  normalizes the current home prefix to `~`;
- a Manifest export contains the same minimal durable audit facts as History;
- path-rich Manifest enrichment is included only while linked Evidence is
  retained;
- an expired Manifest export contains no item name, original path or Trash
  destination;
- the user explicitly chooses the output URL and replacing an existing file
  remains native-panel controlled.

The View does not import AppKit or write files. Export is not an Executor
action and cannot mutate any scanned target.

### 2.6 Trend markers are events, not attribution

Storage Trend remains based only on comparable Quick Scan volume samples.
Manifest markers may be rendered at `manifest.createdAt`, but they do not
become samples, alter the lines or claim a causal storage change. The
persistent caption remains:

```text
Events mark when records were created. They do not prove what caused a
storage change.
```

## 3. Planned Artifacts

Core:

```text
Sources/StornautCore/Evidence/EvidenceStore.swift
Tests/StornautCoreTests/CleanupHistoryStoreTests.swift
```

App:

```text
StornautApp/History/HistoryState.swift
StornautApp/History/HistoryModel.swift
StornautApp/History/HistoryNavigator.swift
StornautApp/History/HistoryDetailView.swift
StornautApp/History/HistoryManifestDetailView.swift
StornautApp/History/HistoryExport.swift
StornautApp/History/HistoryView.swift
StornautApp/History/StorageTrendView.swift
StornautAppTests/HistoryModelTests.swift
StornautAppTests/HistoryAppModelTests.swift
StornautAppTests/HistoryExportTests.swift
```

Harness/docs:

```text
scripts/verify-history-boundaries
StornautAppUITests/StornautAppUITests.swift
docs/reports/epic-8-task-34-review.md
```

Existing App dependencies, model, DEBUG fixtures, localization, screenshot
contracts, verifier and docs indexes may change only as required by the typed
History flow.

## 4. Tests-first Matrix

### Core Store

- Manifest pages are stable for equal timestamps and continue across page
  boundaries.
- Corrupt Manifest rows are isolated without hiding healthy Manifests.
- Seven-day Plan deletion/expiry leaves the Manifest readable.
- Scan deletion leaves the retained Manifest readable.
- Manifest deletion leaves the scan and Plan/Evidence readable.
- Manifest deletion removes only an exactly matching audit/recovery journal.
- A mismatched or undecodable journal cannot be silently deleted.
- Manifest deletion rollback leaves all local records unchanged on failure.
- Ninety-day expiry remains independent and Store schema remains v3.

### App model

- Quick Scan and Manifest records form one stable typed union.
- Type/date/search filters never invent facts for corrupt rows.
- Selection moves to the next valid record after deletion or expiry.
- Retained Plan facts produce item names/lineage.
- Expired or mismatched Plan facts produce `Evidence expired` and no names or
  paths.
- Manifest outcome and accounting are derived from the immutable Manifest.
- Moved-to-Trash bytes are the navigator metric and are never labeled Freed.
- Related Records says lineage only.
- Trend lines remain scan-only while Manifest event markers are separate.
- Delete contracts name only local record effects.
- Export projections enforce the retained/expired privacy boundary.

### App/UI

- type filter includes All, Quick Scan and Cleanup Manifest;
- Light/Dark Manifest detail;
- English and `zh-Hans` parity;
- Evidence-expired Manifest state;
- isolated corrupt Manifest row;
- Manifest delete confirmation and post-delete selection;
- Export remains secondary and native;
- keyboard selection, VoiceOver summaries and Reduce Motion remain usable;
- actual `.app` + Peekaboo show no execution, restore, Empty Trash or filled
  primary CTA.

## 5. Verification Order

Heavy SwiftPM/Xcode commands remain serial:

1. focused Store red/green tests;
2. focused App model/export tests;
3. History source boundary and localization checks;
4. focused History XCUITest;
5. actual signed Debug App launch and Peekaboo read-only capture/inspection;
6. independent read-only review with zero unresolved P0–P2;
7. `scripts/verify --full` once uninterrupted;
8. documentation links, credential/artifact scan and `git diff --check`;
9. one commit with subject `feat: add cleanup manifests to history`;
10. push `origin/main` with token environment overrides unset and verify
    `HEAD == origin/main`.

If user screen activity steals focus, retain the failed evidence and rerun only
the affected UI case before changing code.

## 6. Explicit Non-goals

Task 34 does not:

- enable real App Trash or construct an Executor;
- change production execution from `writeDisabled`;
- add restore, Empty Trash, permanent deletion or blind retry;
- expose the private journal as a History record;
- extend Evidence beyond seven days;
- preserve exact original/Trash paths in the 90-day Manifest;
- create Store v4 or a duplicate History database;
- add Deep Dive, Adapter, Registered Action, telemetry or background work;
- run Task 35's signed-App disposable real Trash diagnostic.

Task 35 remains the sole owner of that real Trash diagnostic. The user
provided its fresh explicit opt-in on 2026-08-15; no real Trash operation ran
as part of Task 34.
