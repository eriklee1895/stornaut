# Task 31 Implementation Brief — Crash-Safe Serial Trash Execution

> Status: Complete; implementation, independent review and unified verifier
> passed
>
> Date: 2026-08-14
>
> Baseline:
> `a80634d33ed4bd1ffdd35f6c078d259fc5238b79`
>
> Parent plan:
> [Epic 8 Safe Execution Vertical Slice](epic-8-safe-execution-vertical-slice.md)
>
> Accepted decisions:
> [ADR 0011](../../adr/0011-review-policy-authorization.md),
> [ADR 0012](../../adr/0012-cleanup-execution-journal.md),
> [Task 30 Review](../../reports/epic-8-task-30-review.md) and
> [Task 27 Study](../../upstream-studies/epic-8-safe-execution.md)
>
> Completion evidence:
> [Task 31 Review](../../reports/epic-8-task-31-review.md)

## 1. Objective

Task 31 closes the deterministic Core execution vertical slice with an
injected fake Trash dependency:

```text
admitted Task 30 batch
+ immutable Plan/selection/order
+ durable prepared journal
+ per-item fresh Policy and ActionPolicyGate
+ serial injected MoveToTrash
+ durable per-item outcome
+ checked accounting
→ immutable Cleanup Manifest
→ finalized or audit-pending result
```

The Task is complete only when:

- `CleanupExecutionCoordinator` is an actor and admits at most one run;
- no adapter call occurs without a valid, fresh, first-use Task 30
  authorization;
- one complete ordered intent journal is durable before the first target
  write;
- every selected item receives a fresh single-item Policy revalidation bound
  to the original full selection generation/fingerprint;
- every action receives low-level `ActionPolicyGate` preflight and immediate
  final revalidation;
- journal `actionStarted` is durable immediately before the injected action;
- each returned action outcome is durable before another action starts;
- stop-after-current, known failure, stale failure and outcome uncertainty
  follow ADR 0011/0012 exactly;
- accounting never reports Trash bytes as permanently released space;
- the immutable Manifest is derived only from journal outcomes and exact
  system samples;
- Manifest persistence failure enters `auditPending` and can retry only the
  exact same Manifest;
- crash recovery never reruns a started or completed action;
- ordinary tests use only fake/injected Trash and uniquely marked temporary
  fixtures;
- the real App `FileManagerTrashAdapter` remains absent from production App
  wiring;
- no Registered Action, Shell, Codex, Adapter, permanent delete, restore
  promise, background service or Store v4 is added;
- tests-first evidence, independent review, focused/full verification,
  completion report and one commit/push are complete.

## 2. Planning Corrections

The parent plan and ADRs remain authoritative. This brief refines the
implementation after inspecting Task 28 journal/Manifest foundations and the
completed Task 30 admission layer.

### 2.1 Full-selection admission and per-item revalidation are different

Task 30 final confirmation and authorization bind the complete ordered
selection. Task 31 must not collect/re-evaluate that full selection before
every later action because earlier successful items have already moved to
Trash and would correctly fail current identity checks.

Add a narrow Task 30 continuation API:

```text
collect one authorized item
→ pure revalidate one item
```

It must:

- retain the original Plan ID, selection generation and full selection
  fingerprint;
- accept only an item ID in the admitted ordered list;
- collect only that exact item's Store/filesystem/Evidence/Activity facts;
- return one `PolicyDecision`, never a new confirmation or authorization;
- reject an unknown/completed/reordered item;
- never reinterpret prior successful items.

The existing full-selection `evaluate` remains the only path that produces a
confirmation.

### 2.2 Coordinator accepts an admitted batch, not a raw authorization

The first `run` attempt must call Task 30 authorization admission before
journal creation or adapter access. The internal admitted batch is then
consumed by the coordinator.

No coordinator initializer or `run` API may accept arbitrary Plan IDs,
ordered item IDs or decision fingerprints as authority. Persisted Plan,
Policy, journal or Manifest records cannot reconstruct admission.

### 2.3 Real Trash remains structurally unavailable to normal App wiring

`ActionExecutor` currently defaults to Foundation Trash for Spike tests.
Task 31 production coordinator must have an internal initializer requiring an
injected executor/factory and must not expose a convenience initializer that
constructs `TrashMoving()` or `FileManagerTrashAdapter`.

The checked-in App dependency graph remains unchanged. Task 32 may use a
write-disabled fake coordinator. Task 35 still owns real signed-App
disposable Trash admission and requires separate user opt-in.

### 2.4 Durable intent precedes every target write

Before the first action, persist one prepared journal containing the complete
ordered selected batch. For each action:

```text
fresh one-item context and pure Policy
→ low-level preflight
→ persist actionStarted
→ immediate ActionExecutor.execute/revalidate
→ typed postflight
→ persist outcome
```

If prepared journal or `actionStarted` persistence fails, the adapter call
count must remain zero for that item.

### 2.5 Known pre-write failure is not outcome Unknown

Failures before the injected adapter is invoked are known failures:

- fresh Policy deny;
- low-level preflight deny;
- final `ActionPolicyGate` revalidation deny;
- cancellation before adapter invocation.

They record a typed failed-before-write outcome with the exact original
confirmed when it can be read and matched. They do not become
`outcomeUnknown`.

`outcomeUnknown` is reserved for crash/recovery after durable `started` with
no durable outcome, or a returned/postcondition state whose mutation result
cannot be established.

### 2.6 Known Trash failure continuation needs exact unchanged identity

An adapter failure may continue only when a fresh post-failure identity read
equals the exact expected identity and the failure is typed as known
before/without mutation.

The following always stop:

- stale/fresh Policy failure;
- low-level final revalidation failure;
- postcondition failure;
- cancellation during/after the synchronous action;
- missing or changed original after a failed action;
- any uncertain outcome.

### 2.7 Finalized journal retention is not deletion

ADR 0012 says journal deletion only follows verified Manifest round-trip, but
Store v3 already models `.finalized` audit journals and retention/clear rules.
Task 31 uses the existing finalized stage as durable minimal recovery state;
it does not introduce a deletion API or schema migration.

A future compaction may remove finalized journals only under a separately
reviewed retention rule. Task 31 does not silently delete audit evidence.

## 3. Closed Coordinator Contract

Planned artifacts:

```text
Sources/StornautCore/Actions/CleanupExecutionCoordinator.swift
Sources/StornautCore/Actions/CleanupExecutionState.swift
Sources/StornautCore/Accounting/CleanupAccounting.swift
Tests/StornautCoreTests/CleanupExecutionCoordinatorTests.swift
Tests/StornautCoreTests/CleanupAccountingTests.swift
Tests/StornautCoreTests/CleanupRecoveryTests.swift
scripts/verify-cleanup-execution-boundaries
docs/reports/epic-8-task-31-review.md
```

### 3.1 Workflow exclusion

Introduce one Core actor that can grant mutually exclusive leases for:

- Quick Scan;
- root/settings mutation;
- History deletion/retention mutation;
- cleanup execution.

Read-only History viewing remains allowed.

The Task 31 coordinator must hold the cleanup lease for admission through
finalization/audit-pending transition. Concurrent cleanup and mutation lease
requests fail deterministically.

Task 31 does not wire this actor into App UI yet. Task 32 will replace the
App-local booleans with this shared contract.

### 3.2 Coordinator inputs

Internal run inputs are:

- exact current `CleanupPlan`;
- original `ReviewSelection`;
- exact Task 30 allowed evaluation/confirmation/collected context;
- opaque `ExecutionAuthorization`;
- root URL/access retained by Task 30;
- injected Store, fresh collector, pure Policy gate, Action executor,
  identity reader, volume sampler and clock;
- deterministic test ID sources.

The coordinator verifies:

- admitted Plan/generation/order/decision fingerprint equals the supplied
  immutable values;
- Plan item order equals the admitted order;
- all actions are `moveToTrash`;
- there are no unknown/duplicate items;
- no active workflow conflict;
- no previous active in-memory run.

### 3.3 Execution states

Planned closed output states:

```text
completed(result)
partiallyFailed(result)
stopped(result)
stale(staleResult, durableJournal)
auditPending(result, exactManifest)
recoveryRequired(result)
rejected(reason)
```

These are typed workflow states, not UI strings. They expose no retry action
except exact Manifest audit retry for `auditPending`.

## 4. Journal State Machine

### 4.1 Prepared

The initial journal contains:

- one run and Manifest ID;
- Plan ID;
- selection generation and fingerprint;
- ordered selected entries only;
- one action/Policy decision per entry;
- expected identity and deterministic action fingerprint;
- all entries `.prepared`;
- seven-day evidence-linked retention.

The Store already verifies exact Plan order, action, identity, allowed Policy
decision and generation. Task 31 additionally binds selection fingerprint and
admitted order before save.

### 4.2 Started

After fresh Policy and low-level preflight, transition exactly one next entry
to `.started`, stage `.actionStarted`, audit retention and 90-day expiry.

No later entry may start and no adapter may run until this transition
round-trips from the Store.

### 4.3 Outcome recorded

Map typed results:

| Execution result | Journal/Manifest result | Recovery |
| --- | --- | --- |
| successful Trash receipt | `succeeded` | `movedToTrash` |
| known adapter failure + exact original unchanged | `failed` | `originalConfirmed` |
| known pre-write failure + exact original unchanged | `failed` | `originalConfirmed` |
| user stop before next item | `cancelled` | `notStarted` |
| crash after started/no outcome | `outcomeUnknown` | `outcomeUnknown` |
| postcondition or identity uncertainty | `outcomeUnknown` | `outcomeUnknown` |

Every outcome uses checked `CleanupManifestMeasures`; permanent bytes are
zero.

### 4.4 Manifest pending, audit pending and finalized

After all remaining entries become terminal:

1. transition journal to `.manifestPending`;
2. derive exact Manifest and summary;
3. sample volume after when available;
4. insert immutable Manifest;
5. load it back and require byte/value identity;
6. transition journal to `.finalized`.

If insert/load/identity fails:

- transition to `.auditPending`;
- return only exact audit retry;
- retain the exact in-memory Manifest fingerprint/value;
- do not re-admit authorization or call the executor.

## 5. Partial Failure and Cancellation

### 5.1 Stop semantics

- cancellation before admission or before prepared save: no journal, no write;
- cancellation after prepared but before first start: mark all entries
  cancelled and finalize;
- during synchronous Trash: record stop-after-current intent; do not claim the
  in-flight call was cancelled;
- after current durable outcome: cancel all remaining prepared entries and
  finalize;
- stop request is monotonic and journal-persisted.

### 5.2 Failure continuation

Continue after a known independent failure only when:

- the adapter reported a typed known failure;
- current original identity still exactly matches expected;
- no Policy/root/workflow conflict exists;
- journal outcome persistence succeeded;
- stop-after-current was not requested.

Any uncertainty stops immediately and cancels all later prepared entries.

## 6. Accounting

`CleanupAccounting` accepts only immutable Plan/journal/system samples.

It derives:

- selected candidate logical/allocated;
- processed logical/allocated;
- moved-to-Trash logical/allocated;
- permanent logical/allocated = zero;
- succeeded/failed/cancelled/unknown counts;
- system free before/after;
- signed free delta;
- unexplained delta =
  `free delta - permanent release` (therefore free delta in Phase C);
- source/sample timestamps.

Requirements:

- checked addition and conversion;
- exact equality with `CleanupManifestSummary(records:)`;
- no subtraction of moved-to-Trash bytes from system delta;
- before/after volume device/source consistency;
- unavailable before or after sample yields `systemObservation == nil`;
- unavailable system observation does not erase action results.

## 7. Crash Recovery

`CleanupExecutionCoordinator.recover()` scans bounded Store journal pages.

For every non-finalized healthy journal:

- `.prepared`: cancel every entry, build/finalize Manifest;
- `.actionStarted`: convert the single started entry to
  `outcomeUnknown`, cancel every later prepared entry, finalize;
- `.actionOutcomeRecorded`: preserve all outcomes, cancel later prepared
  entries, finalize;
- `.manifestPending`: derive/verify and retry only Manifest insertion;
- `.auditPending`: expose exact audit retry only;
- `.finalized`: no action.

Recovery performs read-only identity/Trash relationship observations for
diagnostic reason keys only. A started-without-outcome entry is Unknown even
when the original appears unchanged. No action is retried.

Corrupt journal rows are isolated and reported as recovery-required; they are
never ignored as if no run existed.

## 8. Tests-First Matrix

Before production implementation, add focused tests for:

### Admission and zero-write

- missing, expired, consumed, invalidated and mismatched authorization;
- workflow conflict and concurrent run;
- Plan/selection/order/fingerprint mismatch;
- Registered Action rejection;
- prepared journal save failure;
- fresh Policy deny;
- low-level preflight/final revalidation deny;
- actionStarted save failure;
- cancellation before first action;
- all above assert zero fake-adapter calls where no start was durable.

### Serial execution

- exact Plan order and at most one active adapter call;
- next action starts only after prior outcome round-trip;
- successful two-item run;
- stop-after-current;
- known failure + unchanged identity continuation;
- known failure + changed/missing identity stop;
- postcondition uncertainty stop;
- no permanent delete or rollback.

### Manifest/accounting

- exact records from journal only;
- checked selected/processed/Trash/permanent totals;
- free delta and unexplained delta;
- missing volume sample preserves outcomes;
- immutable insert and same-payload retry;
- different-payload conflict;
- round-trip verification;
- audit pending and exact retry without executor calls.

### Recovery

- prepared cancellation;
- started-without-outcome always Unknown;
- outcome-recorded preservation;
- manifest-pending retry;
- audit-pending no action replay;
- later entries cancelled;
- corrupt row isolation;
- repeated recovery is idempotent.

### Structural

- coordinator cannot construct Foundation Trash;
- no App wiring;
- no production Registry definitions;
- no Shell/Codex/Adapter/background dependency;
- no target write outside injected temporary fixture;
- Store remains v3.

The first focused run must fail because Task 31 coordinator/state/accounting
types do not yet exist. Preserve the command and digest in the completion
report.

## 9. Verification and Review

Run heavy commands serially:

1. focused coordinator/journal/accounting/recovery tests;
2. existing Task 28 journal/Store/Manifest and Task 30 Policy/authorization
   regressions;
3. complete `StornautCoreTests`;
4. serial complete `swift test`;
5. Task 31 structural/boundary verifier;
6. `scripts/check-doc-links`;
7. `scripts/verify`;
8. diff hygiene and secret scan.

Review independently for:

- authority replay or duplicate admission;
- adapter call before durable `started`;
- next action before prior durable outcome;
- actor reentrancy and stop races;
- stale/failed/unknown result confusion;
- hidden retry after crash;
- identity-read TOCTOU and false original-confirmed claims;
- Manifest/journal divergence;
- arithmetic overflow or Trash-as-free-space claims;
- audit-pending action replay;
- App/default Foundation Trash leakage;
- persistence errors swallowed as action errors.

Create `docs/reports/epic-8-task-31-review.md` with tests-first evidence,
state-transition audit, review findings and all gates.

## 10. Explicit Non-Goals

Task 31 does not add:

- production App cleanup wiring;
- real `FileManagerTrashAdapter` admission;
- SwiftUI Review, confirmation, progress or Cleanup Result pages;
- Registered Actions;
- permanent deletion;
- automatic restore/Undo;
- Deep Dive or Adapter behavior;
- background execution;
- Store v4;
- third-party dependencies;
- release/notarization work.

Task 35's signed-App disposable Trash diagnostic still requires separate
explicit user opt-in.

Suggested commit subject:

```text
feat: orchestrate crash-safe trash execution
```
