# Phase D Task 39B2c Fixed-Gate Deadline Cleanup Repair Completion Audit

> Status: complete / non-admitting
>
> Date: 2026-08-30
>
> Implementation: `bc42fbc58ea1c6eed52ff646fa2f6043e2af4316`
>
> Tree: `29eb2d048142fb873f0306acc4bfebbbb250b03d`
>
> Parent and implementation-scope baseline:
> `edf27647e19cbd204fde0264722babfcf6e04199`
>
> Next frontier: interactive-native identity binding repair -> ii-c -> L3c3d ->
> L3c4

## 1. Result

The fixed-gate deadline cleanup repair is complete and remains non-admitting.

The accepted implementation removes the redundant 512-observation ceiling from
`drainRecoveryGroup`. Cleanup continues until the admitted process group
reaches the existing stable gate-only state or the immutable absolute cleanup
deadline expires. Every process-group inventory operation remains bound to that
same absolute deadline and remains fail-closed on expiry or observation
failure.

The repair does not weaken process identity, admitted-group membership,
stable-empty, exact-reap, residue or uncertainty requirements. A valid delayed
cleanup may now continue beyond 512 observations, but deadline expiry still
returns `spawnOrTransferUncertain` and withholds exact-reap and empty-group
proof.

This checkpoint does not perform the privileged machine campaign and makes no
machine-readiness claim.

## 2. Prompt-to-Artifact Completion Audit

| Frozen requirement | Concrete result | Status |
| --- | --- | --- |
| Remove redundant observation ceiling | `maximumDrainObservations` and the bounded `0..<512` drain loop are removed | complete |
| Preserve authoritative time bound | Every cleanup inventory operation continues to receive the immutable absolute cleanup deadline | complete |
| Delayed convergence | Deterministic test remains non-empty beyond 512 observations and then reaches gate-only, exact reap and final empty inventory | complete |
| Signal sequence | Delayed-drain test observes `SIGTERM`, `SIGCONT`, then `SIGKILL` for the admitted group | complete |
| Exact reap | Successful delayed cleanup performs exactly one direct-gate reap | complete |
| Deadline failure | Injected inventory deadline failure remains `spawnOrTransferUncertain`, with no reap and no empty-group proof | complete |
| Darwin adapter immutability | Existing Darwin inventory deadline guard and deadline-bounded pause remain SHA-bound and unchanged | complete |
| Mutation closure | Fifteen exact named mutations are reconstructed and rejected | complete |
| Exact scope | Five non-document paths, no hidden type-change or extra path | complete |
| Admission | No ii-c execution, ADR acceptance or readiness claim | intentionally absent |

## 3. Exact Scope and Diff

The implementation changed exactly five non-document paths:

1. `Sources/StornautInvestigationMachineLaunchSupport/InvestigationFixedGateDarwinLifecycle.swift`;
2. `Tests/StornautInvestigationTests/InvestigationFixedGateDarwinLifecycleTests.swift`;
3. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
4. `scripts/verify-contract`; and
5. `scripts/verify-investigation-boundaries`.

The exact diff against
`edf27647e19cbd204fde0264722babfcf6e04199` is:

| Category | Changed lines |
| --- | ---: |
| Production | 4 |
| Tests | 73 |
| Verifiers | 322 |
| Total | 399 |

The Git diff contains 392 insertions and 7 deletions. No package graph, schema,
protocol field, public API, entitlement or authority was added. The Darwin
syscall adapter and physical fixture were not changed.

## 4. Tests-First and Review Closure

The effective RED ran against the old production implementation with the new
delayed-drain test staged. It failed with three issues as expected: the process
group remained non-empty beyond the former 512-observation limit, the lifecycle
returned `.spawnOrTransferUncertain`, no exact reap occurred and empty-group
proof was withheld.

After replacing the redundant bounded loop with deadline-governed iteration,
both directions became green:

- a delayed group requiring more than 512 observations reaches the required
  signal sequence, exact one reap and final empty inventory; and
- an injected deadline failure remains fail-closed and does not manufacture
  reap or empty-group evidence.

Independent review initially found weaknesses in the verifier rather than the
production repair. The final closure binds the `run()` call edge to
`absoluteDeadline`, rejects inline/helper/adapter counters and deadline
rebinding, strips comment/string spoofing, rejects interpolation, seals the
lifecycle executable-code shape and immutable Darwin adapter SHA, requires
exact canonical byte reconstruction for all fifteen named mutations, and
compares the complete five-path staged scope including Git type changes.

Final production/test and verifier reviews found no unresolved P0-P2.

## 5. Validation Evidence

| Command or evidence | Result |
| --- | --- |
| Effective RED against old production | 1 test failed with 3 expected issues |
| Focused lifecycle suite | 23 tests in 1 suite passed in 0.017 seconds |
| Final focused boundary test | 1 test in 1 suite passed in 0.096 seconds |
| Dedicated source contract | exit 0; approximately 0.7-0.8 seconds |
| Dedicated exact staged-scope contract | exit 0; approximately 0.6 seconds |
| Dedicated mutation contract | all 15 named mutations rejected; exit 0; approximately 6.6 seconds |
| Bare `scripts/verify-investigation-boundaries` | exit 0 in 42.368 seconds |
| Clean staged-only `StornautInvestigationTests` regression | 847 tests in 59 suites passed in 133.053 seconds |
| Existing real seven-scenario physical handoff test | passed within the same loaded 847-test run |
| Retirement monotonic-clock regression | passed within the same loaded 847-test run |
| Clean staged Release build for `StornautInvestigationMachineLaunchSupport` | exit 0 in 25.99 seconds |
| Bare `scripts/verify-contract` | exit 0 in 796.727 seconds |
| Final production/test, verifier and generic reviews | no unresolved P0-P2; final finding set empty |

The final bare contract also replays the shared-deadline checkpoint against
implementation `c144c1e` and tree
`3c2d7f01b73e0b5a943262a4b1fd273e00e4a0d0`. This permits legitimate
successor work while preserving immutable historical verification.

The retained generic review artifacts are:

- `/private/tmp/stornaut_fixed_gate_cleanup_review.7f0cd7/report.md`;
- `/private/tmp/stornaut_fixed_gate_cleanup_review.7f0cd7/report.html`; and
- `/private/tmp/stornaut_fixed_gate_cleanup_review.7f0cd7/final_comments.json`.

The HTML SHA-256 is
`8644689ae88581400c56e5348bc21046a48de0a3a28d933863a219775d0b7e06`.
It covered the five-path, approximately 389-line staged snapshot with no P0-P2.
The accepted commit's authoritative Git numstat is 399 lines; the additional
ten verifier-only historical-replay lines passed the final dedicated and bare
gates and received a separate no-unresolved-P0-P2 verifier review. The custom
review workflow could not be fetched because its TLS certificate verification
failed; the generic workflow completed normally.

## 6. Non-Claims and Next Order

This checkpoint ran no root or sudo operation, no installed
App/helper/driver/gate chain, no product XPC campaign and no Codex model,
authentication or network operation. It did not accept ADR 0018, establish
machine readiness, enable production Deep Dive or run `scripts/verify --full`.

The current remaining order is:

`interactive-native identity binding repair -> ii-c -> L3c3d -> L3c4`.

The identity-binding repair remains a machine-campaign prerequisite rather than
a recursively named Task. Only ii-c may accept ADR 0018 after its privileged
no-model gate succeeds. L3c3d owns the authenticated real Codex attempt, and
L3c4 exclusively owns final admission and the remaining authoritative full
verifier. Task 39 remains incomplete and production Deep Dive remains
unavailable.
