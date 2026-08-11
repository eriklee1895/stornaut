# ADR 0012: Crash-Safe Cleanup Journal and Immutable Manifest

> Status: Accepted for Phase C implementation
>
> Date: 2026-08-11
>
> Decision owners: Stornaut maintainers
>
> Related study:
> [`../upstream-studies/epic-8-safe-execution.md`](../upstream-studies/epic-8-safe-execution.md)

## Context

The current `ActionExecutor` can preflight, revalidate, execute and postflight
one action. The current `CleanupManifest` and Evidence Store are not yet safe
for a product batch:

- no write-ahead record exists before a filesystem mutation;
- a crash can occur after Trash but before an outcome is durable;
- `saveCleanupManifest` uses an upsert helper and can overwrite an ID;
- Manifest results cannot represent outcome Unknown;
- Trash/permanent/recovery measures are not fully separated;
- exact original and resulting Trash URLs are present in `TrashedItemReceipt`;
- a 90-day minimal Manifest must not extend seven-day path-rich Evidence;
- persistence failure is not represented separately from action failure.

An immutable Manifest written only after the batch cannot close the crash
window. A private mutable journal is required, but it must not become a second
user-facing history or a path-retention loophole.

## Decision

### Journal ownership and records

`CleanupExecutionCoordinator` is an actor and the only production owner of one
active run. It writes an internal journal with:

- run, plan, selection generation and ordered item IDs;
- action IDs and action/identity fingerprints;
- prepared, actionStarted, actionOutcomeRecorded, manifestPending and
  finalized states;
- typed outcome, stable destination identity/recovery state and typed error;
- stop-after-current intent;
- timestamps and recovery classification.

The journal contains no authorization, arbitrary command, stdout/stderr,
private content, exact original path or exact Trash URL. Path-rich context
remains linked seven-day Plan/Evidence.

### Write ordering

For each action:

```text
persist run/ordered intent
→ fresh Policy and ActionPolicy preflight
→ persist actionStarted
→ Foundation Trash
→ typed postflight
→ persist outcome
→ consider next action
```

No target write occurs if prepared/start persistence fails. No later action
starts until the current outcome is durable.

`actionStarted` is recorded after pure Policy and lower-level preflight, then
immediately before `ActionExecutor.execute`, whose first operation is the final
`ActionPolicyGate` revalidation. A final pre-write revalidation failure is
recorded as a known failed-before-write outcome. The journal therefore
distinguishes:

- no attempted action;
- known pre-write failure;
- known returned Trash outcome;
- crash/termination after start with no durable outcome.

### Crash recovery

At startup or workflow entry:

- prepared with no started action is safe to abandon/finalize as cancelled;
- a durable known outcome is never executed again;
- manifestPending retries Manifest insertion only;
- every started action without a durable outcome becomes `outcomeUnknown`,
  even when the original path appears unchanged;
- current original/Trash observations are supporting evidence, not proof of
  whether the platform call ran;
- Unknown stops the batch, marks all later not-started actions cancelled and
  finalizes a conservative Manifest;
- no action is automatically retried.

The user must inspect Trash and run a new Quick Scan before a new plan can
include the affected scope.

### Manifest immutability

The final Manifest is insert-only:

- first insert succeeds;
- retry with the same ID and byte-identical payload is idempotent success;
- the same ID with different payload is an integrity error;
- no update API rewrites results, Policy, measures, errors or expiry;
- journal deletion occurs only after Manifest round-trip identity and payload
  verification.

Historical v1 manifests decode into conservative v2 projections; they are not
rewritten in place.

### Persistence failure

If one or more filesystem outcomes are durable in the journal but Manifest
insertion/verification fails:

- workflow enters `auditPending`;
- normal Completed is forbidden;
- the user may invoke only idempotent Retry Saving Audit;
- no filesystem action, Policy admission or authorization is recreated;
- the journal remains the minimal durable audit source.

An `auditPending` journal follows the 90-day audit ceiling, participates in
Clear Manifests and is never silently expired while it is the sole durable
record.

### Data retention and privacy

Seven-day Plan/Evidence may contain:

- exact original path;
- returned Trash URL when supplied;
- item labels and detailed evidence lineage.

The 90-day minimal Manifest retains only:

- stable action/plan/item IDs;
- Policy disposition and reason keys;
- action type;
- typed result/recovery/error;
- before/processed/Trash/permanent measures;
- system observation and timestamps.

After linked Evidence expires, History displays Evidence expired and does not
reconstruct names/paths from guesses.

Clear Evidence removes path-rich Plan/Evidence but not a retained Manifest or
audit-pending journal. Clear Manifests removes final Manifests and
audit-pending journals without touching user files, Trash or Local Knowledge.

### Accounting

Manifest accounting keeps distinct:

- selected candidate logical/allocated bytes;
- Executor processed logical/allocated bytes;
- moved-to-Trash logical/allocated bytes;
- permanent release, always zero in this Phase;
- volume free before/after and signed delta;
- unexplained delta;
- source and sample timestamps.

Trash bytes are not added to free-space delta. A missing volume sample remains
unavailable/partial; it is not encoded as zero. System observation is
explicitly non-causal.

### Partial failure and stop

A known Trash failure may coexist with prior success. The coordinator may
continue only when post-failure identity proves the exact original remains
unchanged. Stale/revalidation failure, postcondition uncertainty and Unknown
stop the batch. Stop After Current Action marks every remaining action
cancelled/not-started.

There is no rollback, automatic restore or permanent-delete fallback.

## Evidence

- Foundation Trash is synchronous, collision-aware and returns a destination
  by reference when available.
- ADR 0006 diagnostics observed that cancellation cannot interrupt the
  synchronous platform call.
- ClearDisk checks that the original disappeared and records history only for
  successful moves.
- devklean tests show why per-item partial outcomes and structural no-write
  paths must be explicit; its compression/direct-delete flow is not adopted.
- Pearcleaner persists exact original↔Trash path pairs for Undo and removes
  stale records when Trash state disappears; this demonstrates both the value
  and privacy/staleness cost of path-rich receipts. Its Commons Clause code is
  behavior-only evidence.
- Current Evidence Store schema is 2, uses `journal_mode=DELETE`,
  `synchronous=FULL`, foreign keys in production connections and upsert-based
  Manifest saving. Task 28 must replace the Manifest write path rather than
  rely on current upsert behavior.

The live production Evidence database was opened read-only for Task 27:

- `user_version = 2`;
- `application_id = 1398033989` (`0x53544E45`);
- `journal_mode = delete`;
- `quick_check = ok`.

`PRAGMA foreign_keys` reported `0` in that separate read-only sqlite3 CLI
connection. This is connection-local and does not contradict the Store's
runtime `PRAGMA foreign_keys=ON`; Task 28 migration tests must verify it on the
actual Store connection.

## Alternatives Rejected

### Write only a final Manifest

Rejected because a crash after Trash and before insert loses the only durable
record and can encourage duplicate retry.

### Retry a started action when the original still exists

Rejected because current path state does not prove whether Foundation ran,
renamed, partially moved or returned before the process died.

### Store the exact Trash URL for 90 days

Rejected because it extends path-rich Evidence retention and creates a false
Undo guarantee.

### Make Manifest updateable to repair errors

Rejected because history could be rewritten after outcomes change. Recovery
must create the correct immutable result once or remain audit pending.

### Combine Trash bytes and free-space delta

Rejected because moving to Trash is not permanent release and APFS/system
changes are not attributable to one action.

## Consequences

Positive:

- a crash cannot silently create a replayable action;
- every terminal or uncertain outcome becomes durable audit truth;
- Manifest history is immutable;
- path retention stays bounded;
- partial failure and persistence failure remain distinguishable;
- accounting cannot claim Trash bytes as freed space.

Costs:

- Task 28 adds Store schema v3 and recovery fixtures;
- each action adds durable journal writes;
- audit finalization needs idempotent payload comparison;
- Unknown outcomes require user inspection and a new scan;
- path-rich UI detail disappears after Evidence expiry by design.

## Residual Risks

- `synchronous=FULL` reduces but cannot eliminate storage/hardware failure.
- A process can still die inside Foundation Trash, producing unavoidable
  outcome uncertainty.
- A destination identity without an exact path cannot implement automatic
  restore; Phase C intentionally offers Open Trash only.
- APFS free-space observations remain noisy and non-causal.
- Task 35 must prove real App-context Trash and residual cleanup behavior on
  disposable data.

## Validation

ADR 0012 is accepted for implementation only if Task 28/31 tests cover every
journal phase and injected persistence failure, including:

- zero writes when intent/start persistence fails;
- no auto-retry for every started-without-outcome state;
- known outcome finalization without action replay;
- same-payload Manifest retry and different-payload rejection;
- seven-day Evidence versus 90-day Manifest/audit-pending retention;
- Clear Evidence/Clear Manifests separation;
- checked arithmetic and unavailable system observations;
- no path/Trash URL in the minimal Manifest;
- no permanent deletion, restore promise or hidden rollback.
