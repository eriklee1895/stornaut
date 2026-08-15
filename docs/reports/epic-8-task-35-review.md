# Epic 8 Task 35 Code Review and Completion Audit

> Status: Complete; signed evidence recovered, mutation sealed, independent
> review clean and authoritative full verifier passed
>
> Date: 2026-08-15
>
> Baseline:
> `26a46dcd9d3711ec56ec63398bbc4c789a6ca775`
>
> Scope: Closed real-Trash composition, strict signed-App disposable
> diagnostic and final Phase C gate

## 1. Current Decision

Task 35 has complete signed-App filesystem evidence and a sealed,
source-bound receipt. One authorized real Trash attempt moved only the exact
diagnostic-owned fixture. A post-write Manifest timeline defect caused the
original App report to remain truthfully blocked after durable
`actionOutcomeRecorded`; the attempt was not retried. A separately signed
recovery-only App then:

- opened only the bound retained Store and exact journal;
- invoked Executor zero times;
- finalized the journal and one-record immutable Manifest;
- projected one success with zero failed/cancelled/unknown outcomes;
- retained permanent release at zero;
- restored the exact fixture by identity and proved the Trash destination
  absent.

Both mutation scripts are now sealed by the checked receipt. The final
authoritative `scripts/verify --full` completed with exit `0`; it was read-only
with respect to Task 35 evidence and did not invoke either mutation harness.

Normal App composition remains:

```text
ReviewExecutionAvailability.writeDisabled
makeExecutionRuntime: nil
```

The DEBUG diagnostic is the only App-side composition that may request the
closed Foundation Trash runtime, but its checked-in launch script now exits
before launch because the one authorized mutation has already occurred.

## 2. Delivered Boundary

### 2.1 Closed Core facade

`CleanupExecutionRuntime` is an actor-owned facade over the existing:

- fresh `CleanupPolicyContextCollector`;
- pure `CleanupPolicyGate`;
- memory-only one-shot `CleanupAuthorizationController`;
- serial `CleanupExecutionCoordinator`;
- empty `ActionRegistry`;
- deny-only Registered Action runner;
- Foundation Trash adapter.

Its Foundation constructor is Core-internal. It exposes typed preflight,
execution, stop-after-current, audit retry and recovery operations, but no raw
authorization, coordinator, target URL, action, registry or executable
surface.

### 2.2 App composition

- ordinary live/production composition is `writeDisabled`;
- a runtime factory supplied to `writeDisabled` composition is discarded;
- `.productionTrash` is an explicit typed state used only by the strict DEBUG
  diagnostic;
- execution single-flight is reserved before any actor suspension;
- Cleanup Result enrichment follows retained Plan → Scan Session → Scope
  identity instead of current Settings.

### 2.3 Signed-App diagnostic

The checked-in diagnostic requires:

- a fresh lowercase UUID opt-in;
- the current locally signed Debug App;
- exact bundle and executable SHA-256 binding;
- a strict, fresh, owner-only absolute config;
- a unique mode-`0700` temporary root;
- one exact `.npm/_cacache` fixture generated inside that root;
- the real Quick Scan → Plan → Policy → confirmation → authorization →
  coordinator path;
- exactly one recorded `FileManager.trashItem` attempt;
- returned destination and original identity agreement;
- finalized journal and immutable one-record Manifest;
- zero permanent-release bytes;
- one identity-checked diagnostic restore;
- residual truth proving the original is present and the returned Trash
  destination is absent.

If a Trash call was attempted but its destination cannot be located, the
report keeps `trashPresent` nullable. It does not retry, restore by guess or
claim absence.

## 3. Tests-First Evidence

The implementation was developed from failing Core/App/diagnostic contracts.
The former global same-user safe-window experiments are retained only as
rejected historical evidence: they incorrectly treated unrelated Apps as test
coordination state and were deleted.

Current verifier contracts instead fail if repository scripts contain:

- `pkill` or `killall`;
- `pgrep`;
- global same-user `ps -U` enumeration;
- a safe-window helper or fake empty Activity admission.

The final full verifier performs no global process preflight. It verifies the
sealed source-bound receipt and retained raw evidence only. Chrome, Cursor,
Claude, MCP servers and unrelated Node processes are not enumerated, do not
block the gate and cannot become signal targets.

## 4. Independent Review

The whole Task 35 diff received an independent review over 23 files. Eight P1
findings were fixed tests-first:

1. execution single-flight reservation occurred after an actor suspension;
2. diagnostic restore could follow a replaced destination-parent symlink;
3. Cleanup Result enrichment used current Settings instead of retained scope;
4. `writeDisabled` retained an injected real runtime factory;
5. a failed restore could be attempted a second time while reporting failure;
6. an unlocated post-attempt destination was reported as absent;
7. the Foundation runtime constructor was public outside Core;
8. boolean attempt evidence could not prove exactly one real Trash call.

The fixed-findings record is:

```text
/tmp/stornaut_task35_review_1786738123/fixed_findings.md
SHA-256 c9e6a27a3f538c48f48658b7dee4ca5f5b7834260703a0e6db096051e755c9e2
```

The post-fix whole-diff result contains no unresolved P0–P2:

```text
/tmp/stornaut_task35_review_1786738123/final_comments.json
SHA-256 37517e5f3dc66819f61f5a7bb8ace1921282415f10551d2defa5c3eb0985b570
```

An earlier review of the now-deleted read-only safe-window preflight also found
zero unresolved P0–P2 at that point:

```text
/tmp/stornaut_task35_preflight_final_review_1786741740/final.txt
SHA-256 ca147082085ffe1ab0c38bb5e6fdf5f65bcf14d9ca075ba76f910d17c2e86d34
```

The launch-composition correction then received a separate tests-first
post-fix review. The first pass found three additional gaps:

1. a valid assigned diagnostic argument plus a duplicate bare option could
   bypass exact-one parsing;
2. tests exercised the parser but not the actual
   `StornautApp.makeComposition(arguments:)` wiring;
3. execution availability used a fail-open negative check rather than an
   explicit allowlist.

Those findings were fixed with mixed-argument, actual-composition and typed
availability tests. A second pass then found that
`ReviewConfirmationModel` still admitted only `.debugFake`, so the
`.productionTrash` diagnostic could reach Review but not its typed
confirmation action. The dedicated red test is:

```text
/tmp/stornaut-task35-confirmation-red.log
SHA-256 b653e84b8b254d92b81b90feaf6f9e2b5f43c3ea40650729d72f9d3ed7ce75c0
```

The confirmation projection now reuses the same explicit
`ReviewExecutionAvailability.admitsExecution` allowlist as the snapshot and
reducer. The final complete App target and final independent review are:

```text
/tmp/stornaut-task35-postreview-final-app-tests.log
SHA-256 942554abf23f5a09778ee269a4cc3c5e6401b5a7e0a2b7c037efa81f946548c0

/tmp/stornaut-task35-final-postfix-review.txt
SHA-256 b9787c5a99fd3ed86bc54715b1392d2b2da541bb4115a72fe3b48e4ec2738bc0

/tmp/stornaut-task35-final-postfix-review.jsonl
SHA-256 850b6854db3b761c2a23db698f11a50a5782aedff8578530bb54582ff3356cd5
```

The final review closes all four post-launch findings and reports zero
unresolved P0–P2. One intentional P3 limitation remains: the reusable
XCUITest fixture renders confirmation with `.debugFake`, not
`.productionTrash`. The bounded signed-App diagnostic is the only
`.productionTrash` product path; adding a second UI fixture with real
execution availability would create another execution surface without
proving the required real-Trash receipt.

After the authorized write exposed the Manifest timeline defect, the
recovery-only changes, source-bound checked receipt, sealed mutation scripts
and removal of global process coordination received a final independent
whole-diff review. The later timestamp-canonicalization fix received a
separate focused review.

## 5. Current Verification

### Phase C product gate

```text
scripts/verify-phase-c-gate --product-only
74/74 focused tests passed
```

Latest observed benchmark samples:

| Contract | Observed | Limit |
| --- | ---: | ---: |
| 4,096-row Plan/Review projection | about 0.70 s | 2.0 s |
| 100-item Policy/authorization/audit | about 0.04 s | 2.0 s |

The same gate passed the Cleanup Policy, execution, Review workflow, Cleanup
Result, History, no-Executor and exact Phase C scope boundaries.

### Complete App target

```text
Recovery-specific App contracts passed.
```

Current result:

```text
/tmp/stornaut-task35-postreview-final-app-tests.log
SHA-256 942554abf23f5a09778ee269a4cc3c5e6401b5a7e0a2b7c037efa81f946548c0
```

### Debug/Release boundary

The exact diagnostic argument marker remains present in the Debug App and
absent from the Release App after the parser hardening:

```text
scripts/verify-app-release-boundaries
Release App fixture boundary verification passed.
real 175.13

/tmp/stornaut-task35-release-boundary-postfix.log
SHA-256 8ee6984b7aa1cd48ac89dc93f5b1a3a89d046f84e1848b77f4af32b4e7f27f1c
```

### Sealed signed evidence

```text
STORNAUT_PHASE_C_TRASH_EVIDENCE_ROOT=<retained root> \
  scripts/verify-phase-c-trash-receipt
scripts/verify-phase-c-gate --signed-app-trash-receipt
```

Both passed. The first command checked the external original/recovery reports,
final SQLite Store and restored residual. The second checked the committed
privacy-safe receipt and safety-critical source bindings. Neither invokes
Trash or recovery.

### Authoritative full verifier

```text
STORNAUT_PHASE_C_TRASH_EVIDENCE_ROOT=<retained root> \
  scripts/verify --full
exit 0
```

The final run completed all 22 stages in 847.921 seconds:

- XCUITest and 30 screenshot contracts passed;
- SwiftPM build and all 634 tests passed;
- the complete App test target and Debug/Release boundary passed;
- Phase C product tests passed 74/74;
- source boundaries, localization, rule compiler, docs links and diff hygiene
  passed;
- the source-bound receipt, retained reports, final SQLite Store and restored
  fixture passed.

The previously failing
`cleanupExecutionManifestTimelineIncludesFinalVolumeSample` test passed in the
full SwiftPM target.

## 6. Final-Gate Diagnostics

Attempts 5–8 were useful historical fail-closed evidence, but their global
same-user safe-window design was later rejected. It conflated unrelated Apps'
Node processes with ownership of the diagnostic fixture. The script was
deleted, and verifier contracts now prohibit global process coordination.
Chrome, Cursor, Claude and MCP processes are neither blockers nor kill
targets for the isolated Task 35 receipt gate.

Attempt 8 ran against source fingerprint
`13b167a07cf675dbd13180bd40dfa80074c100cda92838afab25bc1388ee6290`.
It passed the first 21/22 authoritative stages, including 14/14 XCUITest
methods, 30 screenshot contracts, 624/624 SwiftPM tests, the complete App
target, Debug/Release fixture boundaries and the 72/72 Phase C product gate.
Only the final signed-App diagnostic failed:

```text
outcome = signedAppTrashBlocked
errorStage = planning
error = planFailed
trashAttemptCount = 0
originalPresent = true
trashPresent = false
```

The exact Policy reason in the retained Store was:

```text
execution.activity.process.inactive.contradicted
```

The signed App ran for about 152 ms and attempted no Trash. Its report
SHA-256 is
`994c982c22a8bca221d56401020d85d63acc7fb61e875beb0b464f970210514c`;
the retained Evidence Store SHA-256 is
`fb14608e59fb12f64c3eb330cceed204b340f21051af53c089ee812782d2afc5`.

### 6.1 Launch-race root cause and fix

A Core-equivalent 1 ms native monitor then reproduced an ordinary signed-App
launch while the exact Cursor MCP workers were stopped and their supervisor
was suspended. It proved that the transient Node activity was created by
`Stornaut.app` itself, not by an external developer tool. Ordinary production
composition refreshed Settings before the Task 35 harness ran; Codex discovery
and capability detection launched short-lived:

```text
node .../@openai/codex/bin/codex.js --version
node .../@openai/codex/bin/codex.js --help
node .../@openai/codex/bin/codex.js ... features list
node .../@openai/codex/bin/codex.js ... app-server --stdio
```

The original harmless-launch monitor and controller receipts are:

```text
/tmp/stornaut-task35-harmless-launch-probe.log
SHA-256 bf1e261cc5117acfe478719f252b799167d021b2e45f66c2eada5569ce928339

/tmp/stornaut-task35-harmless-launch-probe.state
SHA-256 f53bb1b13d7945add5d918118e7e91eecf27dfacc36a1398be719d76282fe87e
```

The product Activity result was therefore correct. Weakening Node matching,
special-casing App descendants or overriding persisted evidence would have
made the gate unsound.

The fix is limited to DEBUG launch composition:

- one strict `PhaseCTrashDiagnosticLaunchRequest` parser is shared by App
  composition selection and the harness;
- only one absolute exact config argument selects the diagnostic;
- that launch uses an inert, write-disabled shell model and does not refresh
  ordinary page/Settings services;
- the harness still creates and owns the isolated live dependencies and the
  only closed real-Trash runtime;
- ordinary production composition and its Codex status behavior are
  unchanged.

Tests-first evidence:

```text
/tmp/stornaut-task35-launch-request-red.log
SHA-256 a744d483442b08df5f9eee59cdd8a98fe9b735b746d2ee5bbf3cab900875e39c

/tmp/stornaut-task35-launch-request-green.log
SHA-256 be86a24f2979f41a000b657cc2ec3e19306b8db19d09a5ed395a38b13a2e065a
```

The current signed App was then launched through the exact diagnostic argument
path with an invalid `/dev/null` config and no opt-in. The App performed no
fixture or Trash operation, exited after preflight and the same 1 ms monitor
observed `unique=0` Node/npm/npx/corepack processes:

```text
/tmp/stornaut-task35-diagnostic-launch-probe.log
SHA-256 c8492366f249284b3f3027b43db3a15fae0164ad821e628aa359ae3b963475b4

/tmp/stornaut-task35-diagnostic-launch-probe.state
SHA-256 649989825850ec0ace9c42902dc4b0044810b8b96095ea10e577c44e909aa9cc
```

The Phase C product gate subsequently passed 72/72. The complete App target
passed 213/213 after the final confirmation-projection fix, and the independent
post-fix review reported zero unresolved P0–P2 at that checkpoint.

### 6.2 Authorized attempt and recovery-only closure

The only authorized real Trash attempt used a newly generated mode-`0700`
diagnostic root and the exact `.npm/_cacache` fixture. It produced:

```text
outcome = signedAppTrashBlocked
error = executionFailed
trashAttemptCount = 1
journal stage = actionOutcomeRecorded
original present = false
Trash destination present = true
```

The filesystem mutation succeeded, but Manifest creation rejected a timeline
whose final volume sample fell after `endedAt`. The original report therefore
remains blocked and is not rewritten as success. The defect was fixed by
canonicalizing journal/Plan timestamps and deriving Manifest end time from the
final sample.

Because the mutation budget was consumed, validation switched to a separate
recovery-only signed App. Its composition used a refusing collector and
executor while observing invocation count. It bound the original config,
report, Store, fixture/parent identities, marker, returned destination and
current recovery executable. Its result was:

```text
journal = actionOutcomeRecorded → finalized
Manifest records = 1
succeeded = 1
failed/cancelled/unknown = 0/0/0
selected/processed/moved = 128/128/128 bytes
permanently released = 0 bytes
Executor invocations = 0
restore = restored
original present = true
Trash destination present = false
SQLite integrity = ok
```

The checked receipt is
[`evidence/epic-8-task-35-signed-trash-receipt.json`](evidence/epic-8-task-35-signed-trash-receipt.json).
It contains no private path, nonce or returned Trash location. It binds the
original/recovery artifacts, final Store and all safety-critical source hashes.
The raw evidence remains local and external.

### 6.3 Final review and timestamp repair

The recovery/sealing whole-diff review examined 43 files and 11,124 changed
lines and reported no unresolved P0–P2:

```text
/tmp/stornaut_task35_final_review_1786794245/final_comments.json
SHA-256 37517e5f3dc66819f61f5a7bb8ace1921282415f10551d2defa5c3eb0985b570
```

The first authoritative full run then exposed one deterministic persistence
boundary defect: `DomainJSON` stores dates at millisecond precision, but the
final journal transition reused the pre-persistence `Date`. A value that
rounded backward could make `manifestCreatedAt` appear earlier than the
persisted final volume sample and leave the run at `manifestPending`.

A stable tests-first reproducer dynamically selects such a backward-drifting
date. The repair makes Manifest creation and final/audit transitions reuse the
canonical `journal.systemObservation` that was actually persisted. The
focused timestamp/persistence review reported no unresolved P0–P2:

```text
/tmp/stornaut_task35_timestamp_review_1786798629/final_comments.json
SHA-256 37517e5f3dc66819f61f5a7bb8ace1921282415f10551d2defa5c3eb0985b570
```

## 7. Test Logic and Runtime Economics

The verification layers test different risks and should remain:

- the 634-test SwiftPM target proves Core domain, Policy, persistence,
  execution and recovery behavior; the final run used 54.045 seconds including
  build;
- the complete App target proves composition and projection contracts; the
  final run used 44.975 seconds;
- the Phase C focused product gate proves the Task-specific boundary and
  benchmarks; the final run used 4.159 seconds;
- the signed-App receipt is the only layer that proves the current App
  performed exactly one real Foundation Trash operation under the closed
  product path and recovered it without replay.

The expensive part is UI fixture orchestration, not Core correctness.
Attempt 6 recorded:

| Full stage | Time | Share of 1,280.5 s |
| --- | ---: | ---: |
| XCUITest | 869.5 s | 67.9% |
| Debug/Release fixture boundary | 157.3 s | 12.3% |
| both combined | 1,026.7 s | 80.2% |
| SwiftPM 624 tests | 58.6 s | 4.6% |
| App tests and snapshots | 59.5 s | 4.6% |

The XCUITest target has 14 serialized methods but starts independent fixture
Apps about 40 times. Its three longest methods consume 56.1% of UI test time:
runtime-status variants 205.8 seconds, six-section Settings 137.4 seconds and
Cleanup Result/Manifest states 120.3 seconds. Their acceptance coverage is
valid, but this organization is unsuitable as a repeated diagnostic loop.

Task 35 therefore keeps the authoritative full product gate but makes its
final signed-evidence stage receipt-only. The old global safe-window was not a
valid efficiency mechanism and has been removed. UI fixture materialization
and launch-count reduction remain a separate test-infrastructure iteration.

Attempt 8 completed in about 902.2 seconds before its final failure. XCUITest
used 563.2 seconds (62.4%), the Debug/Release fixture boundary 110.7 seconds
(12.3%), SwiftPM tests 64.9 seconds (7.2%), App tests 50.2 seconds (5.6%) and
the Phase C product gate 4.7 seconds (0.5%). This second sample confirms the
same conclusion: full-gate latency is dominated by UI/process orchestration,
not the deterministic safety core.

## 8. Final Delivery Evidence

Signed evidence now proves:

1. exactly one real Trash attempt against only the diagnostic fixture;
2. truthful blocked original report rather than success relabelling;
3. finalized journal and one-record immutable Manifest;
4. one success and zero failed/cancelled/unknown outcomes;
5. zero permanent release and zero recovery Executor invocations;
6. identity-checked restore and clean residual;
7. privacy-safe, source-bound checked receipt;
8. both mutation scripts sealed against reuse.

Delivery evidence also proves:

1. final whole-diff and focused timestamp reviews have zero unresolved P0–P2;
2. one uninterrupted non-mutating `scripts/verify --full` exited `0`;
3. docs links, source bindings, credentials/artifact boundaries and diff
   hygiene passed;
4. Phase C plans and Task briefs are archived as completed history.

## 9. Scope Audit

Task 35 does not:

- enable ordinary App Trash;
- add arbitrary targets, shell cleanup or a Registered Action;
- add permanent deletion, Empty Trash or ordinary restore;
- inspect a real npm/pip/uv/Go cache;
- change TCC, FDA, Accessibility, Event Synthesizing or Automation Mode;
- add telemetry, background work, login launch or a remote service;
- enable production Deep Dive;
- evaluate release signing, notarization or distribution.

Ordinary App execution intentionally remains `writeDisabled`; Task 35 proves
the closed diagnostic foundation rather than enabling production cleanup.
Phase C is complete with admission `go`. Production Deep Dive remains
unavailable until Phase D's own approved plan, implementation and gates pass.
