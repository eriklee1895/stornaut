# Epic 1 Swift Surveyor Upstream Study

> 状态：Accepted as the study gate for Epic 1 Task 6
>
> 日期：2026-08-09
>
> Coding Agent：TRAE CLI
>
> 目标模块：Swift Surveyor correctness、streaming progress、cancellation、synthetic/real-machine benchmark

## 1. Executive Conclusion

Task 6 should implement a deliberately narrow POSIX-backed Swift scanner:

- an explicit bounded work queue rather than unbounded recursive Tasks;
- `lstat`/`fstatat` metadata and no symlink following;
- same-device recursion by default;
- separate logical and allocated-byte accounting;
- per-path partial failures instead of converting permission gaps to zero;
- cooperative cancellation checked before enqueue, dequeue and directory loops;
- streamed immutable `PathSnapshot` values;
- no taxonomy, Git/IDE signals, Spotlight, SQLite, resume cache or deletion.

This combines the best observed behavior without copying implementation:

- Mole shows why entry/recursive/`du`/queue budgets must be separate and why
  cancellation/progress need first-class state.
- ClearDisk confirms macOS allocated-size APIs matter for sparse files, but its
  serial recursive scan and swallowed errors are not enough for Stornaut.
- kondo demonstrates explicit `follow_symlinks` and `same_file_system` options,
  but its current size function uses logical `metadata.len()` and its deletion
  model is outside this Spike.
- npkill demonstrates bounded worker/process counts, chunked metadata reads,
  stop propagation and allocated-size fallback, while also showing the risk of
  turning permission failures into silent empty/zero results.

No upstream code will be copied. Mole is GPL behavior-only. The three MIT
projects are also used as behavior/test references only, so Task 6 adds no
runtime dependency and no new shipped notice.

## 2. Execution-Time Environment

| Item | Observed value |
| --- | --- |
| Date | 2026-08-09 |
| macOS | 26.5.1, build 25F80 |
| Architecture | arm64 |
| Xcode | 26.6, build 17F113 |
| Swift | 6.3.3 |
| Mac | MacBook Pro `Mac15,7`, Apple M3 Pro |
| CPU | 12 cores |
| Memory | 36 GB |
| Internal filesystem | APFS, internal solid-state |
| Container size | 494,384,795,648 bytes (`460 GiB` class) |
| Container free space | approximately 76.7 GB |
| Installed Mole | `1.49.2`, Homebrew |

The root data volume is APFS and the machine matches the PRD's 460GB-class
benchmark target. These values are evidence for this run, not permanent product
constants.

## 3. Upstream Snapshots

| Source | commit/version | license | Files read |
| --- | --- | --- | --- |
| [Mole](https://github.com/tw93/Mole) | commit `e83f44f8ca56bb49f93c0479c82a984601b22d5d`; installed `1.49.2` | GPL-3.0 | `cmd/analyze/scanner.go`, `live_scan.go`, `model.go`, `constants.go`, `scanner_test.go`, help and license |
| [ClearDisk](https://github.com/bysiber/cleardisk) | tag `v1.9.0`, commit `1aaec92b91c40fdc0c2fce92fef20df08b5f5c43` | MIT | `Sources/ClearDisk/DiskMonitor.swift`, README, license |
| [kondo](https://github.com/tbillington/kondo) | commit `1d351ca80b3d3adfad9bbe7db872c27359190210`; crate `0.9.0` | MIT | `kondo-lib/src/lib.rs`, Cargo manifests, README, license |
| [npkill](https://github.com/voidcosmos/npkill) | commit `2dad63647fdd6887e9022c8d22887fe5606eb92f`; package `0.12.2` | MIT | worker service/worker/file service, tests, package metadata, license |

Execution-time Mole's installed binary SHA-256 is
`c8003565374a7eb31f2230cc26897bd6ceae73164b542afdc034a70ca9756d1f`.

### Source fingerprints

| File | SHA-256 |
| --- | --- |
| Mole `scanner.go` | `d89a94421c57ee35c4dda37acd3013ad40c23eef2be68b8a0c3b4198b5dc303b` |
| Mole `live_scan.go` | `d3962a729a2409cabe54baa41fc43383382dded17d983088ca98f91ba6d52468` |
| Mole `constants.go` | `dbd1ed86b188c2d9d8de03a37d6cb437c20a40628cba95286acd4dcf23e1a5ba` |
| ClearDisk `DiskMonitor.swift` | `4e0d766d3f6be1989e7d71efe2104461823c767fcb80735c10f08b18788cc7fb` |
| kondo `lib.rs` | `0ddd4a6e218e3c3a67f37eb7f1f393b946b6b9bf9e907270cdede0409e540d64` |
| npkill `files.worker.service.ts` | `c1212252cab812ac487965725ac8cdee9020527ff568f209ab4a16ffeff89c63` |
| npkill `files.worker.ts` | `b22f4777c39ad9fbcec3eab16f734ee41d59fd2cf071f16e83e13214b4c2209b` |

Firecrawl was authenticated but had insufficient credits. The study therefore
used shallow clones from the official repositories, current remote tags,
checked-in license files and local source fingerprints rather than substituting
remembered behavior.

## 4. Upstream Findings

### 4.1 Mole

Current Mole has moved beyond shell-only scanning. Its Go analyzer separates
five resource budgets:

- top-level entry workers;
- recursive directory walkers;
- concurrent `du` subprocesses;
- queued `du` work;
- fallback sizing workers.

The comments record real macOS thread-exhaustion failures and deliberately cap
general workers at 12, recursive walkers at 6 and `du` at 4. Channels and heaps
bound pending output and top-N memory. Hard links are deduplicated by
`(device,inode)`. Live scan uses `context.WithCancel`, streamed child progress,
partial child errors and a bounded event channel. Symlinks are represented but
their targets are not recursively counted.

Useful behavior:

- separate I/O and queue budgets;
- immediate partial rows, then child completion updates;
- cancellation is a state, not a generic error;
- cap retained result sets independently from traversal;
- track files/directories/bytes and current path;
- account for hard links.

Rejected for Task 6:

- invoking `du` or Spotlight;
- cache reuse and taxonomy/folded-directory behavior;
- GPL code reuse;
- inheriting analyzer cleanup behavior.

### 4.2 ClearDisk

ClearDisk runs one background dispatch job and then performs disk, known cache,
large-file and project-artifact scans serially. It prevents overlapping scans
but does not expose cooperative scanner cancellation.

Its useful macOS-specific observations:

- `totalFileAllocatedSize` with `fileAllocatedSize` fallback is more useful than
  logical size for sparse developer artifacts;
- hardlink count matters when estimating reclaimable allocated blocks;
- app-managed media-library packages should be pruned rather than traversed;
- project scans need disjoint roots and deduplication;
- a project root should stop deeper artifact discovery to avoid nested doubles.

Task 6 adopts only generic file accounting and fixture ideas. It does not copy
ClearDisk's known-path taxonomy. It also improves on the `try?`/return-empty
pattern by emitting explicit permission/error snapshots.

### 4.3 kondo

kondo uses `walkdir`/`ignore` with explicit `follow_symlinks` and
`same_file_system` options. Project detection skips hidden directories and
stops at discovered project roots. The CLI and GUI share `kondo-lib`.

Its current `dir_size` sums logical file length and silently drops walk or
metadata errors. This is sufficient for artifact selection but not Stornaut's
space ledger. Task 6 will:

- default to no-follow and same-device;
- report errors rather than dropping them;
- keep logical and allocated bytes separate;
- avoid its recursive permanent-deletion model.

No Rust evaluation is justified by source style alone. Performance evidence
must come from Task 6's Swift benchmark.

### 4.4 npkill

npkill uses up to eight worker threads, round-robin jobs and an internal queue.
Each worker caps active asynchronous operations at 100 and sizes files in
chunks of 100. It rejects symlink directories/files and has explicit stop and
worker termination paths. On Unix it prefers `st_blocks * 512`, falling back to
logical size.

Useful behavior:

- explicit queue and worker caps;
- chunked directory metadata work;
- cancellation stops enqueueing and terminates workers;
- size operations have a timeout;
- symlink exclusion has dedicated tests.

Rejected behavior:

- permission errors returning empty arrays or zero size;
- worker respawn via throw;
- treating bytes as released immediately after permanent `rm -rf`;
- substring-based exclusions.

## 5. Task 6 Implementation Brief

### Public contract

`SurveyorSpike.scan(_:)` returns an `AsyncThrowingStream<PathSnapshot, Error>`.
Snapshots are observations, not classifications or cleanup candidates.

`ScanRequest` supplies:

- one absolute existing root;
- maximum worker count;
- same-device recursion policy;
- optional injected boundary/error/cancellation seams for tests;
- bounded stream capacity.

`PathSnapshot` contains:

- URL relative to the scan root for test/product consumption;
- kind (`file`, `directory`, `symlink`, `other`, `inaccessible`);
- logical and allocated bytes;
- device/inode and observation time;
- optional typed scan issue;
- progress counters.

### Traversal

- Open/list directories with POSIX APIs and inspect children with
  `fstatat(..., AT_SYMLINK_NOFOLLOW)`.
- Never recurse into symbolic links.
- Do not recurse when the child device differs from the root device.
- Use a bounded actor/lock-protected FIFO and fixed worker count.
- Check cancellation before waiting, after dequeue and inside each directory
  loop.
- Keep partial snapshots already emitted if another path is unreadable.
- A full stream failure is reserved for invalid request/topology or internal
  invariants; per-path access errors are snapshots.

### Accounting

- `logicalBytes = st_size`.
- `allocatedBytes = st_blocks * 512`.
- Directory entries retain their metadata size; aggregate benchmark totals
  count regular files only to avoid implying a directory's `st_size` is
  reclaimable content.
- Sparse-file fixtures must prove allocated bytes can be lower than logical
  bytes.
- Hardlink deduplication is recorded as a Task 6 metric or duplicate flag;
  production reclaim accounting remains later work.

### Benchmark

The benchmark executable emits one JSON object per run with:

- anonymized root description, never individual paths;
- OS/hardware and launch context;
- entry/file/directory counts;
- logical/allocated bytes;
- elapsed time and entries/second;
- peak resident memory;
- permission/error counts;
- cancellation latency where requested.

Synthetic fixture generation uses a marker file and refuses `/`, `$HOME`, the
repository root and any pre-existing non-fixture directory. Cleanup requires
the same marker and exact caller-provided root.

Three synthetic runs establish repeatability. A read-only CLI full-scope run on
the 460GB-class machine establishes throughput/memory/error behavior but not
packaged-App FDA coverage. No TCC setting is changed.

## 6. License and Provenance

- Mole: behavior-only GPL reference. No code, constants or test fixture is
  copied.
- ClearDisk/kondo/npkill: MIT, but Task 6 still independently implements the
  narrow scanner and does not add them as dependencies.
- No third-party package is added.
- Existing MIT `LICENSE` and shipped `ThirdPartyNotices` remain unchanged.

## 7. Expected Improvement

Compared with the studied implementations, Task 6 aims to combine:

- Mole's bounded resources and cancellation;
- ClearDisk's allocated-size awareness;
- kondo's explicit no-follow/same-filesystem behavior;
- npkill's queue/chunk/cancellation tests;
- Stornaut's stronger partial-error semantics and no-write boundary.

The Spike intentionally avoids upstream cleanup paths, static artifact
taxonomy, background monitoring and cache persistence.
