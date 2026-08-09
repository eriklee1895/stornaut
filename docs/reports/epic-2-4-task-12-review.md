# Epic 2–4 Task 12 Code Review — 2026-08-10

> 状态：All confirmed findings fixed; post-fix review has no open P0–P2
> finding
>
> 范围：production Surveyor、Quick Scan lifecycle、volume/root baseline、
> Evidence schema v2、incremental persistence 与 benchmark
>
> 方法：`bits-code-guard` diff scope + 7-dimension Swift/SQLite manual
> fallback + adversarial lifecycle tests + production-path benchmark + full
> repository verification

## 1. Review Scope

- 24 changed files in the final Task 12 scope, including routing/ADR/report
  updates;
- 11 Swift/SQL files and 2,199 changed lines selected by `bits-code-guard`;
- two pure renames and three Markdown files filtered by the automatic scope;
- full-file manual review of the renamed production Surveyor and its retained
  test suite;
- no repository custom review workflow.

The large-diff fallback reviewed four functional groups:

1. bounded POSIX Surveyor and request limits;
2. `ScanSessionWriter` actor, events, cancellation and backpressure;
3. volume baseline plus Evidence schema v1-to-v2 migration;
4. production benchmark and adversarial lifecycle tests.

The post-fix automatic report is retained at the Task 12 `/tmp` review
workspace; it reports no open P0–P2 finding.

## 2. Confirmed Findings and Fixes

| Severity | Finding | Fix | Regression evidence |
| --- | --- | --- | --- |
| P1 | Cancellation thrown inside a store batch was caught as generic persistence failure and could produce `.failed/.storeFailure` | Preserve `CancellationError` through baseline, batch and terminal paths | store-cancellation lifecycle test returns persisted `.cancelled` |
| P1 | A default batch of 64 delayed the first path fact until a small scan had already completed | Persist and emit the first observation immediately, then use bounded configured batches | first-fact hook proves producer completion was still false |
| P1 | Event-consumer termination cancelled the producer, so App navigation could stop scanning | Decouple event iterator lifetime from producer lifetime; only `cancelActiveScan()` requests user cancellation | navigation-away test reaches durable `.completed` |
| P1 | Publicly reusable session IDs could upsert a new provisional partial record over completed History | Add atomic INSERT-only `beginScanSession`; duplicate IDs fail before scan and preserve existing history | real SQLite duplicate-session test |
| P1 | Provisional crash-safe session used `.scannerFailure`, falsely blaming a scanner bug before one occurred | Add `.interrupted` unfinished reason for in-flight provisional truth | lifecycle fixtures and domain round-trip coverage |
| P1 | Transient progress omitted current scope/path despite the approved UI contract | Add `QuickScanProgress(scopeID,currentRelativePath,counters)` | lifecycle event assertions |
| P1 | Queue/stream/event/batch values were only lower-bounded, allowing callers to defeat bounded-memory claims | Add explicit 64-worker, 65,536-directory, 16,384-event/stream and 100-row batch ceilings | invalid-boundary tests |
| P1 | Progress byte counters used unchecked `Int64` addition | Use saturating addition for logical and allocated counters | existing hard-link/accounting regression plus code-path review |
| P1 | Comparing the complete root identity would reject normal directory mtime changes during scanning | Compare stable device/inode/type between baseline and root descriptor | root-replacement failure plus normal fixture scans |
| P1 | Multiple baselines could collide if different sessions reused a scope ID | Key schema v2 baseline rows by `(session_id, scope_id)` | real reopen/query test and exact schema validation |
| P1 | v1-to-v2 migration accepted any claimed v1 object layout | Compare exact v1 DDL signature before transactional migration | checked-in v1 fixture and injected v2 rollback |
| P1 | Benchmark emitted metrics but did not fail on wrong counts, terminal state, memory, elapsed or cancellation | Add self-validating completion/cancellation gates and first-useful-result/store metrics | three deterministic production runs and one cancellation run |
| P2 | Volume baseline could claim classifier/surveyor sources rather than a volume API | Restrict sources to volume resource values or filesystem attributes | invalid-source domain test |

## 3. Architecture and Safety Result

### Scanner boundary

- `SurveyorSpike` is retired; production `Surveyor` preserves the accepted
  GCD/POSIX implementation.
- Directories are opened no-follow and verified by descriptor identity.
- Symlinks are observed but not followed.
- Same-device recursion remains the default.
- Permission, mount, metadata and directory-read gaps remain localized typed
  observations.
- Counts and bytes are bounded/saturating; stream overflow fails instead of
  dropping facts silently.

### Lifecycle boundary

- One actor owns an active run and explicit user cancellation.
- A provisional `.partial/.interrupted` session is persisted before child
  facts, so interruption cannot leave false success.
- The first path fact is committed and streamed before producer completion.
- Later writes use bounded transactions; progress/current path is transient.
- User cancellation, store failure, scanner failure and event backpressure are
  distinct outcomes.
- Event consumers may disappear without owning the producer lifetime.
- No Codex, Adapter, Policy Gate, Executor or cleanup type is injected or
  called.

### Baseline and persistence

- `VolumeBaseline` preserves root identity, four distinct capacity semantics,
  read-only state, source and sample time.
- Path sums do not create Free or reclaimable values.
- Evidence schema v2 adds a closed `volume_baselines` table with cascade and
  exact DDL validation.
- v0-to-v2 and v1-to-v2 paths are deterministic; injected v2 failure rolls back
  the whole v2 step.
- Session, baseline and snapshots survive closing/reopening real
  `Evidence.sqlite`.

## 4. Verification

Focused post-review result:

- 62 domain, Surveyor, lifecycle, migration, store and retention tests passed;
- no warning or diff-whitespace failure.

Self-validating production-path synthetic benchmark:

| Run | Entries | First useful result | Elapsed | Peak RSS | Store |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 1,356 | 29.75 ms | 107.66 ms | 16,564,224 B | 1,531,904 B |
| 2 | 1,356 | 17.43 ms | 97.81 ms | 16,842,752 B | 1,531,904 B |
| 3 | 1,356 | 16.12 ms | 96.77 ms | 16,957,440 B | 1,523,712 B |

Every run also produced exactly 804 files, 551 directories, one symlink,
68,167,269 logical bytes, 4,349,952 allocated bytes and terminal
`completed`.

Cancellation benchmark:

- terminal: `cancelled`;
- cancellation latency: 21.70 ms;
- total elapsed: 29.30 ms;
- persisted store: 122,880 B;
- no process or fixture residue.

Final `scripts/verify` passed:

- 169 SwiftPM tests (3 opt-in diagnostics skipped by design);
- Xcode App contract tests;
- 2/2 XCUITest cases;
- four Light/Dark shell/Settings screenshots and image checks;
- local App signing and bundle verification;
- English/`zh-Hans` localization parity;
- docs links and diff whitespace checks.

## 5. Remaining Boundaries

- Task 12 orchestrates one root/scope. Task 20 owns multi-root deterministic
  Quick Scan composition after Knowledge and Activity are available.
- Stage milestones for classification and Activity are stable, but Tasks 14–19
  provide those actual engines and facts.
- Task 13 owns accounting reconciliation and cannot turn Surveyor sums into
  volume truth.
- The provisional record identifies an interrupted scope but not the last
  in-flight directory after process death.
- Real packaged-App FDA coverage and production-path full-machine benchmark
  remain Task 26.
- Deep Dive remains no-go/paused.
