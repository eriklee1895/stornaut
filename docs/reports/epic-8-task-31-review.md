# Epic 8 Task 31 Code Review and Completion Audit

> Status: Passed; implementation, completion audit, independent review and
> final unified verifier complete
>
> Date: 2026-08-14
>
> Baseline:
> `a80634d33ed4bd1ffdd35f6c078d259fc5238b79`
>
> Scope: serial injected fake-Trash execution, durable journal ordering,
> per-item fresh Policy, immutable Manifest accounting, audit retry and
> no-replay crash recovery

## 1. Objective and Success Criteria

Task 31 had to close the deterministic Core execution vertical slice without
enabling real App Trash:

```text
admitted Task 30 batch
+ immutable Plan/selection/order
+ durable prepared intent
+ per-item fresh Policy and low-level ActionPolicyGate
+ serial injected MoveToTrash
+ durable per-item outcome
+ checked accounting
→ immutable Cleanup Manifest
→ finalized, audit-pending or recovery-required result
```

Completion required:

1. one actor-owned run and one mutually exclusive cleanup workflow lease;
2. first-use Task 30 authorization before journal or executor access;
3. a complete ordered prepared journal before any target write;
4. fresh single-item Policy collection/revalidation without reinterpreting
   already completed items;
5. durable `actionStarted` immediately before execution;
6. durable outcome before the next item starts;
7. stop-after-current without starting another item;
8. known pre-write, known unchanged failure and uncertain outcome remain
   distinct;
9. success binds exact destination identity to the expected original identity;
10. post-start cancellation is Unknown unless zero-write is proved;
11. recovery never replays a started or completed action;
12. journal-to-Manifest value identity and immutable Manifest insertion;
13. Trash bytes never become permanently released bytes;
14. audit retry persists only the exact derived Manifest;
15. automatic retention never removes unfinished audit truth;
16. Evidence deletion cannot authorize a later prepared item to start;
17. ordinary tests use injected fake executors only;
18. no App wiring, default Foundation Trash, Registered Action, permanent
    delete, Shell, Codex, Adapter, Store v4 or new dependency;
19. tests-first evidence, independent review, focused/full verification and
    one independent commit/push.

## 2. Delivered Architecture

### 2.1 Closed execution coordinator

`CleanupExecutionCoordinator` is an actor with an injected
`CleanupActionExecuting` dependency and no convenience initializer for
`TrashMoving`, `ActionExecutor` or `FileManagerTrashAdapter`.

The run sequence is:

```text
workflow lease
→ one-shot authorization admission
→ persist/round-trip all Policy decisions
→ persist/round-trip complete prepared journal
→ for each item:
   fresh one-item collection
   → pure Policy revalidation
   → low-level preflight
   → persist/round-trip started
   → injected execute/final revalidation
   → typed postflight
   → persist/round-trip outcome
→ persist manifest-pending metadata
→ insert/load exact immutable Manifest
→ persist finalized
```

The actor may re-enter while awaiting the injected executor so
`requestStopAfterCurrent()` can durably set a monotonic stop intent. The run
reloads the newest in-memory journal before recording the outcome and cancels
all later prepared entries only after the current outcome is durable.

### 2.2 Journal and persistence

The journal now binds:

- run, Plan and Manifest IDs;
- selection generation/fingerprint and ordered items;
- Policy decision/disposition/reasons;
- expected identity and deterministic action fingerprint;
- prepared/started/outcome/cancelled item state;
- manifest creation time and system observation;
- seven-day evidence-linked or 90-day audit retention.

`EvidenceStore` validates monotonic transitions and exact current Plan/Policy
truth while Evidence exists. After Evidence is explicitly cleared, an existing
audit journal remains self-contained only for convergence: current started
entries may receive outcomes, prepared entries may stay prepared or become
cancelled, and the journal may become manifest-pending/audit-pending/finalized.
It cannot start or fail a previously prepared item.

Automatic retention removes only finalized audit journals. Clear Manifests
may remove final Manifests and audit-pending/finalized journals as explicitly
defined by ADR 0012; it does not touch user files, Trash or Local Knowledge.

### 2.3 Outcome semantics

- Policy collection/deny and low-level preflight/final revalidation deny are
  known failed-before-write outcomes with `.notStarted`.
- A typed Trash failure may continue only when a fresh identity read exactly
  confirms the original.
- Missing/changed identity, postcondition failure, unexpected error and
  generic cancellation after durable started become `.outcomeUnknown`.
- A successful outcome requires a Trash receipt plus a destination identity
  exactly equal to the expected original identity.
- Cancelled later entries remain `.cancelled/.notStarted`.

No rollback, permanent-delete fallback or automatic action retry exists.

### 2.4 Accounting and Manifest

`CleanupAccounting` derives every Manifest record only from terminal journal
entries. It uses checked domain counts and keeps distinct:

- selected candidate logical/allocated bytes;
- processed logical/allocated bytes;
- moved-to-Trash logical/allocated bytes;
- permanently released logical/allocated bytes, always zero;
- succeeded/failed/cancelled/unknown counts;
- optional same-device/same-source free-space samples;
- signed free-space delta;
- unexplained delta equal to the complete free-space delta in this Phase.

The journal stores Manifest creation time and the exact optional system
observation before insertion, allowing crash recovery and audit retry to
derive the same immutable Manifest after seven-day Plan/Evidence is gone.

## 3. Tests-First Evidence

The initial focused Task 31 tests were added before production coordinator,
state and accounting types. The test target failed to compile because those
types did not exist:

```text
/tmp/stornaut-task31-red-tests.log
SHA-256 3593df8a632d94d28b198f40d34039c7e2b005a6cd75f5579ccf1024846ae31d
```

Independent review later produced three additional valid red witnesses:

### 3.1 Evidence-cleared journal progression

An audit journal could start another prepared action after Clear Evidence had
removed the Plan and Policy truth:

```text
auditJournalCannotStartAnotherActionAfterEvidenceWasCleared
expected invalidJournalTransition, but no error was thrown

/tmp/stornaut-task31-evidence-clear-red.log
SHA-256 313ddf6acc479917e185f1b1381ca5eff0c909b1ce850c82996257b0728c93f4
```

### 3.2 Post-start cancellation and destination identity

The coordinator classified a generic cancellation after durable started as a
known failed-before-write outcome, and the journal accepted a successful
destination identity different from the expected identity:

```text
cleanupExecutionCoordinatorTreatsPostStartCancellationAsUnknown
actual: failed; expected: outcomeUnknown

cleanupJournalSuccessBindsDestinationToExpectedIdentity
expected invalidMeasurement, but no error was thrown

/tmp/stornaut-task31-cancellation-destination-red.log
SHA-256 1784dba36e0eb46b99acb011a043c3bcd3e1e2e44e760c3fddedb09a599896a3
```

All three witnesses pass after the fixes.

## 4. Independent Review Findings and Corrections

The final review covered authority replay, persistence ordering, actor
reentrancy, recovery replay, TOCTOU, journal/Manifest divergence, retention,
accounting, App/default Trash leakage and the process termination regression.

### 4.1 Evidence-cleared audit journal could start new work

**Severity before fix:** P1 audit/replay integrity

**Disposition:** Fixed.

When retained Plan truth was absent, `saveCleanupRunJournal` skipped semantic
Plan/Policy validation for all transitions of an existing audit journal. A
tampered continuation could therefore advance a later prepared entry to
started. The Store now permits only self-contained convergence after Evidence
deletion and rejects any prepared-to-started or prepared-to-failed transition.

### 4.2 Generic cancellation after durable start claimed zero write

**Severity before fix:** P1 outcome truthfulness

**Disposition:** Fixed.

The injected executor protocol does not prove that every
`CancellationError` occurred before adapter invocation. After durable
`actionStarted`, absence of such proof must remain uncertain. The coordinator
now records `.outcomeUnknown` and stops the batch.

### 4.3 Success did not bind destination identity in the journal contract

**Severity before fix:** P1 audit integrity

**Disposition:** Fixed.

The coordinator checked the destination identity, but a decoded or constructed
journal success only required a non-nil destination identity. The journal
entry invariant now requires any destination identity to equal the exact
expected identity. Shared fixtures were corrected rather than weakening the
production contract.

### 4.4 Parallel process-runner cleanup false failure

**Severity before fix:** P1 load-sensitive verifier/runtime robustness

**Disposition:** Fixed.

The synchronous diagnostic process runner bridged to async process-group
termination through `Task.detached` and then blocked on a semaphore. Under
parallel SwiftPM load, cooperative-pool starvation caused
`runtime.process.terminationTimedOut`; a temporary 24-way witness could
deadlock the old bridge.

`ProcessTreeTerminator` now exposes one synchronous bounded implementation for
synchronous callers while preserving its dispatch-backed async API.
`terminateDiagnosticProcessGroup` calls the synchronous path directly.

Evidence:

```text
focused process termination: 3/3 passed
parallel StornautCodexTests: 236/236 passed

/tmp/stornaut-process-termination-fix-focused.log
SHA-256 d1a603863e07bdb5a54b1e29f69269b359c51cf163af8d355ac96fd60b492823

/tmp/stornaut-task31-codex-parallel-regression.log
SHA-256 d19c5763a106c058f539f3fbd9d8a1359e85656c0aa5c0c84aacb72e7f4957bf
```

One discarded review candidate attempted to construct a `ByteCount` greater
than `Int64.max`; the domain initializer already rejects that value, so the
suspected accounting conversion trap was unreachable and no production change
was made.

The final review has no unresolved P0–P2 finding. Review artifacts:

```text
/tmp/stornaut_task31_final_review/report.html
/tmp/stornaut_task31_final_review/report.md
```

## 5. Final Verification

All heavy commands ran serially except the deliberate ordinary parallel
SwiftPM run inside `scripts/verify`.

### Focused Task 28/30/31 regressions

```text
swift test --no-parallel \
  --filter 'CleanupExecution|CleanupAccounting|CleanupJournal|CleanupStoreV3|RetentionPolicy|CleanupPolicy|CleanupAuthorization|ActionPolicyGate'

83/83 passed
/tmp/stornaut-task31-release-focused.log
SHA-256 ef928aa035c7b926bb238f7b809f1eb98ad09df913d7231633f7b5c64730f44d
```

### Complete Core tests

```text
swift test --no-parallel --filter StornautCoreTests

280/280 passed
/tmp/stornaut-task31-release-core.log
SHA-256 04426bda364b46c1b2c3c6b85e30a3016f43f01a2a0056875a5a92aedbdd302f
```

### Complete serial SwiftPM

```text
swift test --no-parallel

613/613 passed
/tmp/stornaut-task31-release-swift-test-serial.log
SHA-256 3c25c723e77f274b2f6206a9d8bf15f4ecac01b9954a5b41747877bbe010c24f
```

### Structural and documentation gates

```text
scripts/verify-cleanup-execution-boundaries
Cleanup execution boundary verification passed.
SHA-256 62f13f082d104142154c962a89a05eff8eaf10e1b69ebd32e305e9ff55880549

scripts/check-doc-links
All local Markdown links resolve.
SHA-256 292eddb8a69fea6bf5f5812927d04b20d0931e7f08fb4277f57452e420a7e1a6

git diff --check
passed

bounded secret scan
passed
```

### Authoritative full verifier

```text
scripts/verify
exit 0

/tmp/stornaut-task31-release-full-verify.log
SHA-256 627335b6e946fb5402712ed71910331fd302d1b5905916a3be04e47bfa896ba9
```

Key full-mode evidence:

- Automation readiness: passed;
- XCUITest: passed;
- 17 canonical screenshot contracts exported and validated;
- SwiftPM build: passed;
- ordinary parallel SwiftPM: 610/610 passed;
- matcher benchmarks: 3/3 passed;
- Phase B product/cancellation evidence: passed;
- all source boundaries, including Cleanup execution: passed;
- App tests/snapshots: passed;
- Debug App build/sign/bundle: passed;
- Release fixture isolation: passed;
- localization, rule compiler, verifier contract, docs and diff: passed.

No App/UI code changed. The full XCUITest and 17 existing screenshot contracts
prove that the Core-only task did not regress the current App surface.

## 6. Boundary and Scope Audit

Task 31 does not:

- wire the coordinator or real Trash into the App;
- construct `FileManagerTrashAdapter`, `TrashMoving()` or `ActionExecutor`;
- add Review, confirmation, progress or Cleanup Result UI;
- enable a production cleanup CTA;
- add a production Registered Action;
- add permanent deletion, rollback or automatic restore;
- add Deep Dive, Adapter, Shell cleanup or background behavior;
- migrate Store v3;
- add a third-party dependency;
- change release/notarization scope.

Task 35 remains the only place for the signed-App disposable real Trash
diagnostic and still requires separate explicit user opt-in.

## 7. Final Decision

Task 31 is complete.

The repository now has a crash-safe deterministic Core execution vertical
slice using injected fake Trash, with no unresolved P0–P2 finding and with the
real App Trash dependency still structurally unavailable. Task 32 is the next
eligible task and may implement the approved Review workflow with a fake or
write-disabled coordinator only.
