# Epic 8 Safe Execution Vertical Slice Validation Report

> Status: Passed; Phase C admission `go`
>
> Date: 2026-08-15
>
> Scope: Epic 8 Tasks 27–35, including the capability-first Runtime R1–R6
> interlock inserted before Task 29

## 1. Executive Decision

Phase C is complete. The non-mutating authoritative full verifier exited `0`,
final independent reviews found no unresolved P0–P2, and all Phase C plans and
Task briefs are archived.

Tasks 27–34 and Runtime R1–R6 are complete. Task 35 delivered the closed
real-Trash composition, strict signed-App disposable diagnostic, recovery-only
runtime and source-bound receipt. The one authorized Trash attempt moved only
the exact fixture and durably recorded `actionOutcomeRecorded`; a Manifest
timeline defect prevented the original run from finalizing, so its report
truthfully remains blocked. The action was not retried. A separately signed
recovery-only App finalized the existing journal/Manifest with zero Executor
invocations, restored the exact fixture and proved a clean residual.

Both mutation scripts are sealed. The full verifier now validates only the
checked receipt and, when locally supplied, retained raw evidence. It does not
run Trash or recovery.

The admitted evidence chain is:

```text
current signed Debug App
→ unique diagnostic-owned .npm/_cacache fixture
→ exact shared attestation and fresh Policy
→ exactly one Foundation Trash attempt
→ durable actionOutcomeRecorded journal
→ recovery-only zero-replay finalization
→ immutable Manifest and truthful accounting
→ identity-checked restore and clean residual
→ source-bound checked receipt
→ uninterrupted non-mutating scripts/verify --full exit 0
```

Focused tests and structural checks cannot substitute for that receipt.

## 2. Prompt-to-Artifact Matrix

| Approved requirement | Artifact or gate | Current evidence | Status |
| --- | --- | --- | --- |
| deterministic Quick Scan → Review plan | Tasks 29 and 32 | Task reviews and prior full gates | passed |
| pure Policy and fresh context | Task 30 | Task review and prior full gate | passed |
| memory-only one-shot authorization | Task 30 | Task review and prior full gate | passed |
| serial fake-Trash coordinator and journal | Task 31 | Task review and prior full gate | passed |
| immutable Manifest and truthful accounting | Tasks 31 and 33 | Task reviews and prior full gates | passed |
| native Review/Result/History flow | Tasks 32–34 | XCUITest, actual-App evidence and prior full gates | passed |
| capability-first Codex runtime interlock | Runtime R1–R6 | final runtime validation and R6 review | passed |
| closed Core real-Trash facade | Task 35 | Core tests and structural gate | passed |
| normal App remains write-disabled | Task 35 | App tests and source boundary | passed |
| strict signed-App diagnostic | Task 35 | original signed report + source-bound receipt | passed |
| exactly one real Trash attempt | Task 35 original report | `trashAttemptCount = 1`; exact fixture identity | passed |
| no action replay during recovery | Task 35 recovery report/Core tests | Executor invocation count `0` | passed |
| journal/Manifest terminal truth | final Store + recovery report | finalized; one record; 1/0/0/0 outcomes | passed |
| identity-checked restore and clean residual | Task 35 recovery report | original present; Trash absent | passed |
| mutation sealed after evidence | scripts/contracts | diagnostic/recovery scripts exit 65; full gate receipt-only | passed |
| zero unresolved P0–P2 | Task 35 independent review | whole-diff and focused timestamp reviews | passed |
| bounded Phase C performance | product gate | 4,096 rows ~0.70 s; 100 items ~0.04 s | passed |
| authoritative single full verifier | `scripts/verify --full` | 22/22 stages; exit `0`; 847.921 s | passed |
| archive | docs lifecycle | Phase C and Runtime interlock plans moved to `plans/completed/` | passed |

## 3. Safety Invariants

The current implementation and gates preserve:

- Quick Scan does not call a model;
- Codex cannot reach Policy/Executor or perform cleanup;
- execution profiles are the exact three approved profiles;
- only npm and pip may be Ready when complete current evidence permits;
- uv has no execution profile;
- Plan, Policy and confirmation are not reusable execution authority;
- authorization is one-shot, bounded and memory-only;
- Policy and filesystem identity are revalidated immediately before mutation;
- `FileManager.trashItem` is the only selected-target production mutation;
- the production `ActionRegistry` is empty;
- no permanent-delete fallback exists;
- uncertain Trash outcome remains Unknown and is never replayed;
- normal App composition remains `writeDisabled`;
- production Deep Dive remains unavailable.

## 4. Deterministic Verification

Current Task 35 evidence:

```text
scripts/verify-phase-c-gate --product-only
74/74 focused tests passed

recovery-focused Core and App tests
passed

STORNAUT_PHASE_C_TRASH_EVIDENCE_ROOT=<retained root> \
  scripts/verify-phase-c-trash-receipt
external original/recovery/SQLite/residual evidence passed

scripts/verify-phase-c-gate --signed-app-trash-receipt
checked receipt and source binding passed
```

The product gate additionally verifies:

- three exact execution profiles and two default-ready profiles;
- empty Registry and deny-only Registered Action execution;
- Core-internal Foundation authority construction;
- no implicit real adapter on coordinator/executor;
- no App View/state execution authority;
- no Codex, Probe Bridge or Adapter reachability;
- no permanent deletion, Empty Trash or shell cleanup;
- no background monitor, scheduler, login launch, telemetry or remote rules;
- no dependency/license drift.

Authoritative final evidence:

```text
STORNAUT_PHASE_C_TRASH_EVIDENCE_ROOT=<retained root> \
  scripts/verify --full
Verification passed in full mode.
```

The final run passed XCUITest and 30 screenshot contracts, all 634 SwiftPM
tests, the complete App target, the Debug/Release boundary, Phase C product
tests 74/74, source/no-Executor/localization/rule-compiler boundaries, docs
links and diff hygiene, and the source-bound retained raw receipt.

## 5. Independent Review

Eight P1 findings were fixed before acceptance of the deterministic candidate:

- actor single-flight reentrancy;
- restore-parent symlink replacement;
- stale Settings root used for Result enrichment;
- hidden real runtime retained by `writeDisabled`;
- diagnostic restore replay;
- false absent Trash residual;
- public raw Foundation constructor;
- boolean rather than exact attempt evidence.

The final whole-diff review and the separate verifier-preflight review each
reported zero unresolved P0–P2. The post-launch review then found and closed:

- mixed assigned + bare diagnostic argument duplication;
- missing actual `makeComposition(arguments:)` coverage;
- fail-open execution-availability projection;
- confirmation projection that omitted `.productionTrash`.

The complete App target passed 213/213 at that checkpoint and the review
reported zero unresolved P0–P2. One intentional P3 limitation remains:
reusable XCUITest fixtures use `.debugFake`, while the bounded signed-App
diagnostic is the only `.productionTrash` product path. The later
recovery/sealing diff received a fresh final whole-diff review over 43 files
and 11,124 changed lines. It reported no unresolved P0–P2. The
timestamp-canonicalization repair discovered by the first full run received a
separate focused review with the same zero-finding result. Details, rationale
and hashes are recorded in
[Task 35 Review](epic-8-task-35-review.md).

## 6. Signed-App Evidence Contract

The checked receipt binds two truthful signed-App reports rather than
rewriting the original blocked outcome:

| Dimension | Observed value |
| --- | --- |
| original outcome | `signedAppTrashBlocked` / `executionFailed` |
| configured/planned | both `true` |
| Trash attempts | exactly `1` |
| profile target | exact `.npm/_cacache` under diagnostic-owned root |
| identities | original equals returned destination identity |
| durable pre-recovery journal | `actionOutcomeRecorded` |
| recovery Executor invocations | `0` |
| final journal | `finalized` |
| Manifest | one immutable record |
| terminal counts | one success; zero failed/cancelled/unknown |
| accounting | selected = processed = moved = `128`; permanent = `0` |
| restore | `restored` |
| residual | original present; Trash absent |
| final Store | SQLite integrity `ok`; SHA-256 bound |
| privacy | no local path, opt-in nonce or returned Trash path committed |
| limitations | diagnostic fixture and local ad-hoc signed Apps only |

The receipt also binds the safety-critical Core/App source set. Changed source
cannot reuse the evidence.

## 7. Final-Gate Diagnosis

Attempts 5–8 provided historical fail-closed evidence, but their global
same-user safe-window architecture was later rejected and deleted. It made
unrelated Chrome, Cursor, Claude or MCP Node processes part of test
coordination even though those processes did not own the diagnostic fixture.
Current verifier contracts prohibit global process enumeration or signaling.

Attempt 6 exposed that the two checks also needed the same process identity
semantics as the product. The old `pgrep -x node` form matched display command
titles and omitted two Node parents whose titles had changed to
`npm exec ...`; the product's `proc_name` Activity capture correctly observed
their kernel executable name. Attempt 6 therefore passed 21/22 stages before
the App returned `signedAppTrashBlocked` / `planFailed` with:

```text
Policy reason = execution.activity.process.inactive.contradicted
trashAttemptCount = 0
originalPresent = true
trashPresent = false
```

This was not Planner corruption, permission failure or a product false
positive. Production Activity semantics remain conservative, but a repository
test must not coordinate or terminate unrelated same-user Apps.

Attempt 8 used those corrected checks and passed 21/22 stages. The final App
still returned the same fail-closed planning result with zero Trash attempts.
A 1 ms Core-equivalent monitor isolated the remaining race: ordinary
`Stornaut.app` production composition refreshed Settings before the DEBUG
Trash harness ran. Its Codex installation/capability detection launched
short-lived Node wrappers for `codex --version`, `--help`, `features list` and
strict-config app-server probes. The subsequent Quick Scan correctly observed
that App-owned Node activity and contradicted
`activity.process.inactive`.

The fix does not weaken Activity evidence. The strict absolute diagnostic
argument is now resolved before ordinary composition; it selects an inert,
write-disabled shell model while the harness owns the isolated Quick Scan and
closed execution runtime. Focused parser/composition tests passed, the Phase C
product gate passed 72/72 and a current signed-App launch through that exact
argument path with an invalid config and no opt-in observed zero
Node/npm/npx/corepack processes at 1 ms resolution. The probe created no
fixture and performed no Trash call.

Post-launch independent review hardened the parser against mixed bare and
assigned duplicates, tested the actual App composition selector, replaced the
availability negative check with an explicit allowlist, and made the
confirmation projection admit both `.debugFake` and `.productionTrash`.
The complete App target passed 213/213 after those fixes. A fresh
Debug/Release boundary build also passed in 175.13 seconds, proving the exact
diagnostic marker remains Debug-only.

The final diagnostic used a random mode-`0700`, diagnostic-owned fixture and a
target-aware attestation shared across Quick Scan, Plan, preflight and
per-item Policy. This exception cannot apply to ordinary caches.

The sole real attempt then moved the exact fixture but exposed a post-write
Manifest timeline defect. It durably stopped at `actionOutcomeRecorded`, and
the original report remained blocked with attempt count one. No second action
was attempted.

A separately signed recovery-only App bound the retained reports, Store,
filesystem identities, marker and recovery executable. It finalized the
existing journal/Manifest with zero Executor invocations, restored the exact
fixture and proved the clean residual. The mutation scripts were then sealed;
all subsequent gates are receipt-only.

The first authoritative full run then found one Core persistence edge case:
millisecond JSON canonicalization could round the persisted final volume
sample backward while a later transition reused the original `Date`. The
stable tests-first reproducer failed at `manifestPending`. The repair reuses
the persisted `journal.systemObservation` for Manifest and final/audit
transitions. Focused coordinator tests, Phase C 74/74 and the final 634-test
SwiftPM target all passed.

Attempt 6 also established why the final full gate must not be used as the
inner debugging loop. Of 1,280.5 seconds, XCUITest consumed 869.5 seconds and
the Debug/Release fixture boundary consumed 157.3 seconds; together they were
80.2% of runtime. The 624-test SwiftPM target and then-current App target each took
about one minute, and the Task-specific Phase C product gate took about six
seconds. The coverage layers remain valid, but focused/product-only checks must
precede the one final full run.

Attempt 8 independently confirmed the same shape: of about 902.2 seconds,
XCUITest used 563.2 seconds (62.4%) and the Debug/Release fixture boundary
110.7 seconds (12.3%), while Phase C product verification used 4.7 seconds
(0.5%). Full-gate latency is dominated by UI/process orchestration rather than
the deterministic safety core.

## 8. Admission Decision

Current Phase C admission:

```text
go
```

Admission means:

- normal App execution stays `writeDisabled`;
- production Deep Dive stays unavailable;
- the sole real Trash and recovery mutation harnesses remain sealed;
- Phase D requires a fresh approved plan and its own implementation and gates;
- release distribution, Developer ID/notarization and production FDA/TCC
  remain outside this evidence.
