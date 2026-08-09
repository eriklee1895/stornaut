# ADR 0005: Swift Surveyor Performance and Cancellation

> Status: Accepted for the Epic 1 Task 6 Spike
> Date: 2026-08-09
> Decision owners: Stornaut maintainers
> Related study: [`../upstream-studies/epic-1-surveyor.md`](../upstream-studies/epic-1-surveyor.md)

## Context

Stornaut's deterministic Quick Scan depends on a read-only scanner that can:

- traverse a 460GiB-class developer Mac in under five minutes;
- remain within a modest memory budget;
- stream partial observations;
- preserve permission gaps instead of reporting zero;
- cancel promptly;
- avoid symlink and mount-boundary recursion;
- report logical and allocated bytes separately.

The approved architecture forbids adding Rust merely because other tools use
it. Task 6 must first produce Swift evidence.

## Decision

**Swift meets the current Spike performance, memory and cancellation goals.**

Continue with Swift/Foundation/POSIX for the production Surveyor. Do not open a
Rust evaluation ADR.

### Narrow scanner contract

`SurveyorSpike.scan(_:)` returns
`AsyncThrowingStream<PathSnapshot, Error>`. It uses:

- one validated absolute directory root;
- a fixed worker pool;
- a bounded shared directory FIFO;
- worker-local overflow stacks so a full FIFO neither drops work nor deadlocks
  producers;
- bounded stream buffering that fails with `streamBufferExceeded` instead of
  silently dropping observations;
- `open(O_DIRECTORY|O_NOFOLLOW)`, `fdopendir`, `readdir` and
  `fstatat(AT_SYMLINK_NOFOLLOW)`;
- same-device recursion by default;
- cooperative cancellation before/after queue waits and inside directory
  loops;
- immutable snapshots containing relative path, type, device/inode, logical
  bytes, allocated bytes, issue and progress.

Symlinks are observed but never followed. A different-device directory is
observed with `.mountBoundary` and pruned. Per-path permission/metadata/read
failures emit `.inaccessible` snapshots; only invalid root/topology and internal
invariants fail the whole stream.

A directory replaced after scheduling but before descriptor verification is a
per-path `.metadataUnavailable` result. It does not erase valid siblings or
abort the whole scan.

Logical bytes use `st_size`; allocated bytes use `st_blocks * 512`. Files with
multiple hard links are counted once in progress byte totals using
`(device,inode)` identity, while both directory entries remain observable.
APFS clones/purgeable/compression still prevent these totals from being treated
as reclaimable or free-space truth.

### Benchmark harness

`SurveyorBenchmark` is a SwiftPM executable product used only for local
measurement. It emits one JSON object per run containing machine/OS, anonymized
root description, counts, byte totals, elapsed time, throughput, peak RSS,
permission/error counts and cancellation latency.

`Tests/Fixtures/Surveyor/generate-fixture.sh`:

- requires an absolute target whose parent already exists;
- refuses `/`, `$HOME`, the repository root and any repository child;
- refuses existing non-fixture paths;
- creates a deterministic shallow/deep/high-fanout tree, allocated file,
  sparse file, package directory and symlink;
- cleans only a directory carrying the exact fixture marker.

## Evidence

### Upstream study

The accepted study fixed current Mole, ClearDisk, kondo and npkill commits,
licenses, source fingerprints and implementation observations. Mole remained
GPL behavior-only; no upstream code or package dependency was added.

### Tests first

Contract-first compilation initially failed because `ScanRequest`,
`PathSnapshot` and `SurveyorSpike` did not exist.

Final Surveyor coverage includes:

- regular files, directories and packages;
- sparse-file logical/allocated distinction;
- symlink observation without target recursion;
- injected mount-boundary pruning;
- partial permission failure without erasing valid siblings;
- fixed worker bound;
- bounded shared queue without dropped directories;
- bounded stream overflow failure;
- cancellation and worker exit within one second;
- invalid root/worker/queue/stream requests;
- signed `dev_t` bit-pattern conversion;
- hardlink byte deduplication;
- fixture generator refusal and marker-bound cleanup.

Informational coverage before final benchmark hardening was:

- line coverage: `89.45%`;
- function coverage: `92.86%`.

Coverage is not used as a substitute for the real-machine benchmark.

### Synthetic benchmark

Three initial generated-fixture runs produced the same counts and byte totals:

| Metric | Run 1 | Run 2 | Run 3 |
| --- | ---: | ---: | ---: |
| Entries | 1,356 | 1,356 | 1,356 |
| Regular files | 804 | 804 | 804 |
| Directories | 551 | 551 | 551 |
| Symlinks | 1 | 1 | 1 |
| Logical file bytes | 68,167,269 | 68,167,269 | 68,167,269 |
| Allocated file bytes | 4,349,952 | 4,349,952 | 4,349,952 |
| Elapsed | 47.27 ms | 42.89 ms | 45.69 ms |
| Peak RSS | 9.83 MB | 10.13 MB | 10.26 MB |

Median elapsed time was approximately `45.69 ms`. A post-hardening synthetic
run remained consistent at `47.78 ms`.

### 460GiB-class real Mac

Launch context: CLI SwiftPM executable, read-only root scan. The App-context
TCC state from ADR 0004 was not changed. This proves scanner throughput,
memory, cancellation and current permission gaps; it does not prove packaged
App FDA coverage.

Machine:

- Apple M3 Pro, 12 cores, 36GB RAM;
- internal APFS solid-state container;
- 494,384,795,648-byte container (`460 GiB` class);
- macOS 26.5.1, build 25F80.

Three pre-hardlink-hardening full scans:

| Metric | Run 1 | Run 2 | Run 3 |
| --- | ---: | ---: | ---: |
| Entries | 9,086,853 | 9,086,883 | 9,087,104 |
| Elapsed | 93.16 s | 96.20 s | 97.53 s |
| Throughput | 97,544/s | 94,458/s | 93,177/s |
| Peak RSS | 25.44 MB | 27.00 MB | 27.41 MB |
| Permission failures | 982 | 982 | 982 |
| Total errors | 983 | 987 | 986 |

Median full-root elapsed time was approximately `96.20 s`, well below five
minutes.

A post-hardlink-hardening full scan produced:

- 9,087,325 entries;
- 98.52 s;
- 92,235 entries/second;
- 25.67 MB peak RSS;
- 982 permission failures and 985 total issues.

The small count drift is expected on a live development machine; no individual
private paths were persisted.

The first real scan exposed a signed-`dev_t` conversion trap on APFS metadata.
Device identity now uses explicit bit-pattern conversion and has a regression
test.

Byte totals on the live root exceed physical container capacity even after
hardlink deduplication. This is recorded evidence that APFS clones,
compression, dataless files, purgeable data and live mutation prevent raw
per-file allocated/logical sums from becoming reclaimable/free-space claims.
Later space accounting must reconcile filesystem/volume evidence separately.

### Cancellation

A root scan cancelled after 100 ms reported:

- 9,422 already-streamed entries;
- producer-completion cancellation latency: approximately `0.136 ms`;
- 12.24 MB peak RSS;
- no write operation.

The benchmark now waits for the scanner's producer completion callback before
recording cancellation latency; consumer termination alone is not accepted.

After changing directory scheduling so high fan-out is bounded during
`readdir` rather than after collecting all children, 11 focused tests passed.
Three final synthetic runs remained deterministic at `51.56`, `44.41` and
`43.70 ms`, with peak RSS below `10.3 MB`.

The final post-verification command required by the active plan emitted the
same counts/bytes at `46.00`, `43.79` and `84.28 ms`; the slower third run did
not affect correctness and remained negligible relative to the real-machine
gate.

Full parallel SwiftPM verification initially exposed cooperative-executor
starvation: the first implementation put blocking POSIX traversal and
`NSCondition.wait` inside Swift `TaskGroup` workers, delaying unrelated Codex
timeout/cancellation tests to 7–8 seconds. Surveyor workers now run on a fixed
GCD utility pool and the Swift task only awaits `DispatchGroup` completion.
Two consecutive full 94-test SwiftPM runs then passed in about six seconds with
no surviving fake process.

## Consequences

Positive:

- the current Swift approach has substantial headroom against `<5 min`;
- memory stayed below 28 MB in measured full scans;
- cancellation is far below the one-second synthetic goal;
- permission failures remain explicit;
- no Rust toolchain/runtime dependency is justified;
- the scanner remains independently testable without the App or Codex.

Costs and limitations:

- one snapshot per entry means more protocol traffic than a production
  hierarchical aggregation layer will need;
- the fixed FIFO may spill into worker-local stacks under high fan-out;
- hardlink identity state grows with distinct multiply-linked files;
- tests use injected permission/mount seams because the current user cannot
  safely manufacture alternate TCC/mount states;
- root scans are CLI evidence, not App-host FDA coverage;
- live-machine counts vary as files change;
- APFS byte totals are observations, not reclaimable-space accounting.

## Residual Risks and Follow-up

- Epic 3 should add production aggregation/progress semantics and App-host
  coverage tests without changing the no-follow/same-device defaults.
- Epic 8 space accounting must reconcile APFS/free-space changes rather than
  sum snapshots naively.
- Hardlink/clone handling needs larger anonymous fixtures before cleanup
  estimates.
- App-context full-scope coverage remains unmeasured under FDA; do not change
  TCC automatically.
- If future production features materially regress performance, optimize the
  Swift path first and reopen a separate Rust ADR only with new measurements.

## Validation

Task 6 is accepted only after:

- focused Surveyor tests;
- fixture generator safety checks;
- three synthetic JSON runs;
- real full/cancelled root runs;
- full `scripts/verify`;
- documentation links and diff checks;
- no benchmark artifact, private path list or permission mutation committed.
