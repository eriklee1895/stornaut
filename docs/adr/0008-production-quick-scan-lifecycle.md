# ADR 0008: Production Quick Scan Lifecycle

> Status: Accepted; Phase B product path validated
>
> Date: 2026-08-10
>
> Decision owners: Stornaut maintainers
>
> Related study:
> [`../upstream-studies/epic-3-quick-scan.md`](../upstream-studies/epic-3-quick-scan.md)

## Context

Epic 1 proved that the Swift/POSIX Surveyor can traverse a 460 GiB-class Mac
with bounded memory, no-follow semantics, same-device recursion and prompt
cancellation. The spike stream did not yet provide:

- the five approved product stages;
- durable volume/root baselines;
- bounded incremental persistence;
- one-active-session ownership;
- persisted partial/cancelled/failed terminal truth;
- App-navigation-independent cancellation.

Task 12 must productionize that path without introducing Codex, classification,
Activity or cleanup dependencies.

## Decision

### Responsibility split

`Surveyor` is the production low-level scanner. It retains the accepted fixed
GCD worker pool, bounded shared directory queue, worker-local overflow stack,
POSIX descriptor traversal and typed path observations. Its producer/consumer
channel is bounded and applies cancellable backpressure: a slow consumer does
not silently drop facts or fail merely because the buffer fills, and abandoning
the sequence wakes blocked producers and stops workers.

`ScanSessionWriter` is an actor-owned lifecycle orchestrator:

- permits one active scan per writer;
- captures a typed `VolumeBaseline`;
- persists a fail-safe provisional partial session before child facts;
- commits the first retained path fact separately, then writes bounded batches
  with a default of 4,096 and maximum of 8,192;
- emits bounded typed lifecycle events;
- owns explicit `cancelActiveScan()` independently of UI consumer lifetime;
- replaces provisional state with completed, partial, cancelled or failed truth.

One `ScanRequest` still means one root/scope/ledger. Task 20 composed rules and
Activity over that one real root; Phase B did not implement or claim multi-root
or multi-ledger support.

### Event contract

`QuickScanEvent` is a closed `Sendable` enum:

```text
stageChanged
progress
factObserved
issueObserved
scopeFinished
terminal
```

The fixed stage order is:

1. `Index Volumes`
2. `Map Projects`
3. `Classify Artifacts`
4. `Check Activity`
5. `Finalize Snapshot`

Tasks 14–19 later populate classification/activity facts. Task 12 emits the
stable milestones but does not claim such work occurred beyond current
deterministic inputs.

Progress is transient. Volume baselines, path snapshots, localized issue status
and final session/scope state are durable.

### Cancellation and failures

- User cancellation requests producer cancellation through the writer and
  returns a persisted `.cancelled` terminal session.
- Permission, mount and metadata gaps remain localized snapshots/issues and make
  the scope partial rather than erasing siblings.
- Root identity replacement or scanner failure produces `.failed`.
- Store failure stops scanning and persists `.failed` with `.storeFailure` when
  terminal persistence remains available.
- Consumer backpressure never silently drops facts: it fails with
  `eventBufferExceeded` after persisted session state is made non-success.
- If terminal persistence itself fails, the stream fails with
  `terminalPersistenceFailed`; no success terminal is emitted.

### Volume and root baseline

`FoundationVolumeBaselineSampler` records:

- root path and full `FileIdentity`;
- volume total capacity;
- general, important and opportunistic available capacity separately;
- read-only state;
- source and sample time.

The writer compares baseline root identity with the Surveyor root observation.
Capacity values are never derived from path sums.

### Persistence migration

Evidence schema v2 adds `volume_baselines` keyed by
`(session_id, scope_id)`. It is a closed typed payload with duplicated indexed
columns validated on read. Exact v1 schema validation occurs before the
transactional v1-to-v2 migration.

## Evidence

The Task 12 tests cover:

- monotonic five-stage events and first useful fact before terminal;
- bounded workers, directory queue, streams and persistence batches;
- localized permission gaps and same-device/no-follow behavior;
- explicit user cancellation preserving committed facts;
- consumer backpressure and store failure without false success;
- concurrent-run refusal and root replacement fail-closed;
- v0-to-v2 and exact v1-to-v2 migrations with rollback injection;
- baseline/session/snapshots surviving a real SQLite store reopen;
- impossible capacity and non-directory baseline rejection.

The production synthetic benchmark records events through `ScanSessionWriter`
and `Evidence.sqlite`, including store size and terminal state.

## Consequences

Positive:

- Quick Scan lifecycle no longer depends on a SwiftUI view or consumer task;
- crash/interruption cannot leave a persisted completed session by default;
- first facts stream while bounded batches become durable;
- root/volume truth has explicit source and sample time;
- scanner safety and the proven Swift performance path remain unchanged.

Costs:

- the writer currently models one root/scope;
- product stages for classification/activity are milestones until later Tasks
  provide their deterministic engines;
- reference writer mode still persists each path for lifecycle regression;
  product mode instead persists candidate/owner/gap facts plus a typed full
  aggregate to avoid a multi-million-row product database;
- the two-second SQLite busy timeout remains intentionally bounded.

## Residual Risks

- A process kill between a committed fact batch and terminal replacement leaves
  the provisional partial session, but it cannot identify which in-flight
  directory was last active.
- Async stream failure can race a consumer that never begins iteration; durable
  non-success state is the authoritative result.
- Volume resource values can drift during a scan. Task 13 owns reconciliation,
  not Task 12.
- Real packaged-App FDA state still has no supported general query. Task 26
  measured CLI/product coverage and actual App rendering without claiming an
  FDA verdict.
- Deep Dive remains no-go/paused.

## Acceptance Evidence

Task 12 accepts this ADR because:

1. 62 focused Surveyor/lifecycle/store/domain tests pass;
2. three production-path benchmark runs each produce the exact 1,356-entry
   fixture and completed terminal in 96.77–107.66 ms;
3. first useful durable results arrive in 16.12–29.75 ms;
4. cancellation produces durable `.cancelled` in 21.70 ms;
5. post-fix `bits-code-guard` review has no open P0–P2 finding;
6. full `scripts/verify` passes 169 SwiftPM tests, App tests, 2/2 XCUITest,
   screenshots, signing, localization and docs;
7. static dependency review confirms no Quick Scan reference to StornautCodex,
   Adapters, Policy Gate or Executor.

## Task 20 Product Composition Delta

Task 20 adds `QuickScanCoordinator` above the accepted writer:

- suppresses Task 12's compatibility-only classification/activity/finalization
  milestones and emits them only when real deterministic work runs;
- keeps the writer's provisional partial session authoritative until
  classifications, activity evidence and the Space Ledger are durable;
- rejects a second start intent while any writer remains active;
- replays immediate cancellation after the writer stream exists, revalidates
  cancellation at post-scan commit points and persists cancelled truth;
- defines an atomic product-finalization commit point before ledger/session
  persistence: cancellation accepted before it wins and persists Cancelled;
  cancellation requested after it returns `false` instead of falsely promising
  to overturn committed final facts;
- fails product-stream backpressure without silently dropping facts;
- preserves healthy snapshots/evidence/classifications when a dependent stage
  fails and emits typed partial issues;
- treats end-volume sampling and final terminal persistence as dependent product
  stages: failures preserve healthy facts as Partial, and a durable ledger is
  reloaded only when every classification/corruption dependency remains valid;
- restores typed product issues from bounded evidence, unfinished-scope reasons
  and durable completeness checks after restart without storing raw provider
  output or adding a schema migration;
- treats scanned names outside the matcher grammar as no candidate/Unknown
  rather than failing the session, while keeping catalog errors fail-closed;
- collects all Git requirements for one rule from one repository snapshot;
- pages the latest valid restart projection while isolating corrupt rows.

The public production initializer accepts only `EvidenceStore`. Store/activity,
clock and identity injection seams remain internal for tests, so App/UI code
cannot introduce a new scan-target mutation dependency through composition.

The Coordinator consumes the checked-in immutable 67-rule runtime catalog,
performs candidate matching, conservative evidence/activity reduction and
Space Ledger reconciliation. Protected vetoes remain Protected; rule misses and
unproven prerequisites remain Unknown. It never calls Codex, Probe Bridge,
Adapter, Policy Gate, Executor or cleanup code.

Activity observations used by classification are persisted as bounded typed
`EvidenceRecord` values containing only key/source/reason/time/freshness. No raw
Git output, process list, content or command text is stored.

Task 20 evidence adds:

- a read-only target E2E audit over path/type/identity/size/mtime/content;
- an inert fake Codex executable whose external marker remains absent;
- deterministic output under injected clocks and stable snapshot,
  classification and evidence identities;
- cancellation during traversal and activity, concurrent-start rejection,
  product backpressure and partial store failure;
- restart loading with corrupt-newer-session isolation;
- permission gaps retained as Unmeasurable with `bytes=nil`;
- machine regeneration of the runtime catalog and source/dependency boundary
  checks.

## Phase B Product Gate Delta

Task 26 keeps this ADR Accepted and records the production scaling decisions:

- `ProductScanAccumulator` matches rules and reduces owner/unclassified bytes,
  coverage gaps, hard links, typed entry/issue counts and logical/allocated
  file totals while Surveyor streams.
- Product persistence retains rule candidates, top-level owners, coverage gaps
  and at most 100 auxiliary display facts. It does not persist every ordinary
  path merely for UI count reconstruction.
- `ScanSession.aggregate` preserves full typed counts for completed, partial and
  cancelled truth; terminal App metrics consume the aggregate rather than the
  bounded display page.
- Classification and ledger finalization use 4,096-row keyset pages. Terminal
  and restart projections are candidate-first, bounded to 100 records, and
  fill remaining slots with auxiliary display facts.
- `QuickScanProjection` separately carries full snapshot/classification/
  candidate/evidence/disposition counts and bounded records.
- Darwin directory entries are variable-length records. Surveyor and Probe
  Broker share a raw-pointer decoder that validates `d_reclen`, `d_namlen`,
  NUL termination and UTF-8 without loading Swift's fixed 1,024-byte `d_name`
  tuple. ASan covers minimal, maximum-length and malformed records.
- Surveyor clears and checks `errno` around every `readdir` call. EIO or a
  malformed record becomes `directoryReadFailed`; Quick Scan persists
  `failed/scannerFailure` and cannot convert it to normal EOF/Completed.
- The machine-readable benchmark has explicit `writer` and `product` modes.
  Product mode runs the public coordinator and emits schema version 3.

The final-source current-machine Home product run processed 3,107,607 entries
in 247.24 seconds at 12,568.95 entries/s. First useful progress arrived in
26.42 ms, peak RSS was 73,220,096 bytes and the store was 20,795,392 bytes.
The run correctly ended Partial for 132 permission gaps, emitted no product or
corrupt-record or directory-read issue and did not launch the inert fake Codex
marker.

A separate sample persisted Cancelled after 1,256 entries in 110.20 ms, with
1.82 ms measured cancellation response, no ledger and no Codex marker.

These results meet the `< 5 min` and `<= 256 MiB` gates. They do not prove
multi-root support, packaged-App FDA coverage, syscall-level target-write
absence or release readiness.
