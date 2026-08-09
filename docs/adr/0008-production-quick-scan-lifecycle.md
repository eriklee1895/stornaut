# ADR 0008: Production Quick Scan Lifecycle

> Status: Accepted; Task 12 production lifecycle validated
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
bounded `AsyncThrowingStream`, POSIX descriptor traversal and typed path
observations.

`ScanSessionWriter` is an actor-owned lifecycle orchestrator:

- permits one active scan per writer;
- captures a typed `VolumeBaseline`;
- persists a fail-safe provisional partial session before child facts;
- writes path facts in batches of at most 100, with a default of 64;
- emits bounded typed lifecycle events;
- owns explicit `cancelActiveScan()` independently of UI consumer lifetime;
- replaces provisional state with completed, partial, cancelled or failed truth.

One Task 12 `ScanRequest` still means one root/scope. Task 20 will compose
multiple roots after rules and Activity exist; Task 12 does not fabricate those
later stages' product results.

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
- each successful scan writes each path payload once and then streams its typed
  event, increasing synthetic runtime relative to the scanner-only spike;
- the initial two-second SQLite busy timeout still needs Task 12/26 benchmark
  evidence before tuning.

## Residual Risks

- A process kill between a committed fact batch and terminal replacement leaves
  the provisional partial session, but it cannot identify which in-flight
  directory was last active.
- Async stream failure can race a consumer that never begins iteration; durable
  non-success state is the authoritative result.
- Volume resource values can drift during a scan. Task 13 owns reconciliation,
  not Task 12.
- Real packaged-App FDA coverage and real-machine production-path benchmarking
  remain Task 26.
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
