# Epic 3 Production Quick Scan Upstream Study

> 状态：Accepted as the study gate for Epic 3 Tasks 12–13 and 20
>
> 日期：2026-08-09
>
> Coding Agent：TRAE CLI
>
> 目标模块：production Surveyor、streaming、partial/cancel、volume baseline、Space Ledger

## 1. Executive Conclusion

Production Quick Scan should evolve the validated Epic 1 Swift Surveyor rather
than replace it:

- retain bounded GCD/POSIX traversal, no-follow and same-device defaults;
- separate immutable path facts from transient progress events;
- persist facts in bounded batches instead of retaining a whole object graph;
- use a session state machine with explicit completed, partial, cancelled and
  failed terminal states;
- keep five approved UI stages stable while internal traversal remains dynamic;
- sample volume capacity/free space through Foundation as separately timestamped
  observations;
- never derive Free or reclaimable bytes from raw entry sums;
- preserve permission/race/mount gaps as typed Unmeasurable/partial evidence;
- enforce one active Quick Scan and zero Codex/Adapter/cleanup dependencies.

No upstream code or taxonomy is copied. This study revalidates the exact
commits used by the accepted Epic 1 Surveyor study and records only the
production deltas.

## 2. Upstream Snapshots

| Source | Version/commit | License | Material read |
| --- | --- | --- | --- |
| [Mole](https://github.com/tw93/Mole) | `e83f44f8ca56bb49f93c0479c82a984601b22d5d` | GPL-3.0 | `cmd/analyze/scanner.go`, `live_scan.go`, `model.go`, `cache.go`, `scanner_test.go` |
| [ClearDisk](https://github.com/bysiber/cleardisk) | tag `v1.9.0`, `1aaec92b91c40fdc0c2fce92fef20df08b5f5c43` | MIT | `Sources/ClearDisk/DiskMonitor.swift`, `MainView.swift`, README |
| [kondo](https://github.com/tbillington/kondo) | `1d351ca80b3d3adfad9bbe7db872c27359190210` | MIT | `kondo-lib/src/lib.rs`, manifests, README |
| Apple Foundation | Xcode 26.6 / macOS 26.5 SDK | Apple documentation terms | `URLResourceValues` volume capacity APIs, `FileManager.attributesOfFileSystem`, [Files and directories](https://developer.apple.com/documentation/technologyoverviews/files-and-directories) |
| Stornaut Epic 1 | commit `a043188753d4777cfa3d26900b387312c863393f` | MIT | [Surveyor study](epic-1-surveyor.md), [ADR 0005](../adr/0005-swift-surveyor-performance.md), tests and benchmark |

### Source fingerprints

| File | SHA-256 |
| --- | --- |
| Mole `scanner.go` | `d89a94421c57ee35c4dda37acd3013ad40c23eef2be68b8a0c3b4198b5dc303b` |
| Mole `live_scan.go` | `d3962a729a2409cabe54baa41fc43383382dded17d983088ca98f91ba6d52468` |
| ClearDisk `DiskMonitor.swift` | `4e0d766d3f6be1989e7d71efe2104461823c767fcb80735c10f08b18788cc7fb` |
| ClearDisk `MainView.swift` | `9314b5dce074d52cbbd87c3102e92a9344b196443c7167f4c3cdae877999b82f` |
| kondo `kondo-lib/src/lib.rs` | `0ddd4a6e218e3c3a67f37eb7f1f393b946b6b9bf9e907270cdede0409e540d64` |

The commits and key scanner fingerprints match the 2026-08-09 Epic 1 study;
no upstream drift requires revisiting the Swift performance decision.

## 3. Observed Upstream Behavior

### 3.1 Mole

Useful:

- separates entry, recursive walker, `du`, queue and fallback budgets;
- streams initial rows and child updates;
- uses explicit context cancellation;
- deduplicates hard links by `(device,inode)`;
- avoids persisting scan-order-dependent hard-link cache results;
- bounds top-N and queue memory separately.

Rejected:

- GPL implementation reuse;
- shell/Spotlight/`du` as the production scanner;
- cache reuse before Stornaut has stable snapshot identity/invalidation;
- cleanup and scan in one module;
- treating a successfully measured path size as reclaimability.

### 3.2 ClearDisk

Useful:

- allocated-size awareness for sparse files;
- prevents overlapping scans;
- keeps project/cache results understandable in a native UI;
- history-clear wording distinguishes deleting records from restoring files.

Rejected:

- serial recursive scanning and swallowed `try?` errors;
- menu-bar lifecycle and background/predictive behavior;
- removing result rows before executor success;
- broad "safe cache" labels without Stornaut evidence/activity gates;
- coupling UI state to disk mutation.

### 3.3 kondo

Useful:

- explicit `follow_symlinks` and `same_file_system`;
- shared project-detection core;
- stopping at project boundaries can prevent nested double counting;
- artifact taxonomy provides fixture ideas.

Rejected:

- Rust introduction after Swift met the measured gate;
- direct recursive deletion;
- logical-only directory sizing and dropped traversal errors;
- static project cleanup as a substitute for a volume ledger.

## 4. Foundation Volume Baseline Evidence

A read-only Task 9 probe sampled `/` through current Foundation APIs:

```text
volumeTotalCapacity                  494,384,795,648
volumeAvailableCapacity               80,288,444,416
volumeAvailableCapacityForImportant   82,639,392,992
volumeAvailableCapacityForOpportunistic
                                      68,634,177,406
volumeIsReadOnly                       false
FileManager.systemSize              494,384,795,648
FileManager.systemFreeSize            80,288,440,320
```

The two general free-space APIs differed slightly even in one process, and
"important" versus "opportunistic" capacity differed by many gigabytes. This
is direct evidence that:

- Free requires a source label and sample time;
- different capacity semantics cannot be collapsed into one unexplained number;
- path-snapshot sums cannot replace a volume API;
- an accounting reconciliation must tolerate live changes between samples.

## 5. Production Quick Scan Brief

### Session state

```text
idle
  → indexingVolumes
  → mappingProjects
  → classifyingArtifacts
  → checkingActivity
  → finalizingSnapshot
  → completed | partial | cancelled | failed
```

The five product stages are user-facing milestones. They are not persisted in
every path row and do not claim traversal knows total work in advance.

### Events

The production stream distinguishes:

- `stageChanged`;
- `progress`;
- `factObserved`;
- `issueObserved`;
- `scopeFinished`;
- `terminal`.

Progress includes bounded counters and current summarized scope, not a
scrolling path log. Persisted final facts do not embed a copy of global
progress.

### Cancellation and partial results

- cancellation is explicit and idempotent;
- no new directories are scheduled after cancellation;
- bounded committed batches remain queryable;
- unfinished roots/scopes are persisted;
- cancellation is not rewritten as an empty success or generic failure;
- UI navigation never owns scanner lifetime;
- a second start intent cannot create another uncontrolled scan.

### Persistence and memory

- fixed worker, queue and stream bounds remain;
- a `ScanSessionWriter` consumes events in bounded transactions;
- progress is transient; session/facts/issues/unfinished scopes are durable;
- paging and indexes replace an in-memory full-tree object graph;
- store failure stops the producer and marks the session failed/partial without
  pretending all prior facts are invalid.

### No-write and no-Codex boundaries

Quick Scan:

- opens scanned directories read-only;
- has no `StornautCodex` dependency;
- cannot obtain Probe Bridge, Adapter, Policy or Executor instances;
- writes only through an injected Stornaut store root;
- includes a fake-Codex marker and before/after target audit in Task 20.

## 6. Space Accounting Inputs

Task 13 must model:

- volume total/free observations, each with source and sampled-at time;
- disjoint accounting owners rather than parent-plus-child sums;
- logical and allocated path observations separately;
- hard-link identity;
- permission/mount/race gaps;
- residual measured-but-unclassified bytes;
- APFS clone/compression/sparse/purgeable caveats.

The resulting ledger keeps occupancy separate from disposition. A path becoming
`Ready to Reclaim` does not change Known/Unknown/Unmeasurable/Free totals.

## 7. Fixtures and Benchmark

Tasks 12–13 and 20 require:

- deterministic high-fanout/deep/sparse/hardlink/symlink fixtures;
- root identity replacement and permission/mount injection;
- consumer backpressure and store-failure seams;
- cancellation with committed partial facts and unfinished scopes;
- overlapping parent/child accounting fixtures;
- volume samples that drift during a scan;
- target before/after path/type/identity/mtime/hash audit;
- fake Codex marker that remains absent;
- three synthetic production-path runs;
- final real-machine run recording first-result time, elapsed, RSS, store size,
  issue counts, ledger explanations and cancellation latency.

## 8. License and Reuse Boundary

Mole remains GPL behavior-only. ClearDisk and kondo are MIT but no code is
copied and neither becomes a dependency. Task 9 adds no shipped notice.

## 9. Relative Improvement

Stornaut combines the useful bounded/cancellable behavior observed upstream
with stronger partial-error semantics, durable session identity and a
source-bearing volume ledger. Unlike the compared tools, it makes "measured",
"classified", "reclaimable" and "free" separate facts and proves Quick Scan has
no model or cleanup call path.
