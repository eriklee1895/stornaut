# Phase D Task 39B2c Shared-Deadline Repair Completion Audit

> Status: complete / non-admitting
>
> Date: 2026-08-30
>
> Implementation: `c144c1e1d7b21e40f300cddfe1ff2c80993513db`
>
> Tree: `3c2d7f01b73e0b5a943262a4b1fd273e00e4a0d0`
>
> Parent and implementation-scope baseline:
> `66453397ae70c59347f02fff4e1a5528926c5141`
>
> Next frontier at this checkpoint: fixed-gate deadline cleanup repair, then
> interactive-native identity binding repair -> ii-c -> L3c3d -> L3c4

## 1. Result

The shared-deadline repair is complete and remains non-admitting.

The machine-only eight-epoch cohort now has one fixed 1,200-second validity
horizon while each epoch retains its independent 140-second active execution
ceiling. The focused Investigation Plan remains a separate 600-second
admission-freshness artifact, and the reusable diagnostic configuration
constructor and decoder retain their 900-second ceiling.

Immediately before the fixed handoff, the coordinator revalidates the complete
projected cohort and requires at least 1,125 seconds of canonical remaining
time: eight 140-second epochs plus the existing five-second final-output
reserve. Insufficient, expired, mixed, non-finite or conservatively rounded
insufficient time fails before the handoff is called.

The App-side deadline is derived from one wall-clock anchor plus monotonic
elapsed time. It does not restart after bootstrap or acknowledgement and cannot
be extended by a wall-clock rollback, forward jump followed by rollback, or a
later retirement-time sample. The machine decoder, projected-cohort author,
runner and final assembler preserve the exact machine profile and immutable
configuration identities.

This checkpoint does not perform the privileged machine campaign and makes no
machine-readiness claim.

## 2. Prompt-to-Artifact Completion Audit

| Frozen requirement | Concrete result | Status |
| --- | --- | --- |
| Focused Plan freshness | Plan expiry remains exactly 600 seconds | complete |
| Machine cohort horizon | All eight pre-authored configurations share one exact 1,200-second `validBefore` | complete |
| Per-epoch execution bound | Each epoch remains bounded by the existing 140-second monotonic ceiling | complete |
| App/Lifecycle clamp | Effective deadline is derived once from the epoch anchor and is the earlier of cohort validity and the 140-second epoch bound | complete |
| Generic safety boundary | Reusable diagnostic construction and decoding continue to reject validity beyond 900 seconds | complete |
| Exact machine profile | Machine-only validation binds the fixed wall-clock, turn, probe-call and context limits | complete |
| Immutable evidence identity | Configuration bytes, configuration SHA-256, projected cohort and whole-input identities are not re-authored at epoch start | complete |
| Pre-handoff reserve | Exactly 1,125 seconds is accepted; a smaller or mixed window is rejected before handoff | complete |
| Structural closure | Dedicated source, scope and 36-mutation contracts passed | complete |
| Scope and budget | Exact 14 non-document paths and 1,500 changed lines | complete |
| Admission | No ii-c execution, ADR acceptance or readiness claim | intentionally absent |

## 3. Exact Scope and Diff

The implementation changed exactly fourteen non-document paths:

1. `Sources/StornautInvestigation/SignedInvestigationRuntimeContract.swift`;
2. `Sources/StornautInvestigationDiagnostic/InvestigationProjectedCohortAuthor.swift`;
3. `Sources/StornautInvestigationDiagnostic/InvestigationRuntimeDiagnosticComposition.swift`;
4. `Sources/StornautInvestigationMachine/InvestigationFixedScenarioRunner.swift`;
5. `Sources/StornautInvestigationMachine/SignedInvestigationRuntimeMachineContract.swift`;
6. `Sources/StornautInvestigationMachineGateCoordinatorSupport/InvestigationMachineCoordinatorConfigurationSet.swift`;
7. `Sources/StornautInvestigationMachineGateCoordinatorSupport/InvestigationMachineGateCoordinatorComposition.swift`;
8. `Tests/StornautInvestigationTests/InvestigationHandoffConcreteCompositionTests.swift`;
9. `Tests/StornautInvestigationTests/InvestigationLifecycleTopologyTestSupport.swift`;
10. `Tests/StornautInvestigationTests/InvestigationMachineCoordinatorBindingSourceTests.swift`;
11. `Tests/StornautInvestigationTests/InvestigationMachineGateCoordinatorCompositionTests.swift`;
12. `Tests/StornautInvestigationTests/SignedRuntimeContractTests.swift`;
13. `scripts/verify-contract`; and
14. `scripts/verify-investigation-boundaries`.

The exact non-document diff against
`66453397ae70c59347f02fff4e1a5528926c5141` is:

| Category | Changed lines |
| --- | ---: |
| Production | 337 |
| Tests | 750 |
| Verifiers | 413 |
| Total | 1,500 |

The implementation commit also amended
`docs/reports/phase-d-task-39b2c-shared-deadline-repair-preflight.md` by 26
insertions and 10 deletions. Documentation is outside the frozen non-document
budget. No non-document path was added outside the frozen fourteen-path set,
and no package target, schema, protocol field, entitlement or authority was
added.

## 4. Review-Driven Closures

The implementation and verifier review cycle closed the following issues:

- the inherited App path derives its wall-clock deadline at epoch start rather
  than after bootstrap;
- construction, decoding, runner admission and final assembly bind the exact
  machine profile instead of accepting the generic 900-second profile;
- the pre-handoff comparison handles sub-microsecond time conservatively and
  final assembly independently rejects mixed shared deadlines;
- focused-test presence checks, source seals, subordinate verifier seals and
  binary-numstat rejection prevent comments, literals, vacuous tests or
  malformed scope data from satisfying the gate; and
- historical iv-b2 verification replays its accepted immutable tree rather
  than treating the successor worktree as that checkpoint.

The final frozen non-document diff SHA was
`1527b0ed41d21d1fd223d7d9625ad02da416a5a4df1ec4497ab966d03b153e42`.
Three grouped reviews and the cross-group review used that same diff and found
no unresolved P0-P2. The retained generic report is
`/var/folders/bd/stx12mg16dd8hsrj72kswfl40000gn/T/stornaut_shared_deadline_frozen_review.FzwmCq/report.html`,
SHA-256 `c74bd41c31cf449e7c319495e54e7071478854522db9c6cfe21767d7af2900d0`.
Its approximate 1,521-line review basis does not replace the authoritative
1,500-line Git numstat.

## 5. Validation Evidence

| Command or evidence | Result |
| --- | --- |
| Final affected selection | 122 tests in 7 suites passed in 25.451 seconds |
| Earlier green affected selections | 122 tests in 7 suites passed in 19.694 seconds and 23.489 seconds |
| Focused progression | 7 tests / 4 suites in 0.396 seconds; 9 / 4 in 0.547 seconds; 12 / 4 in 0.241 seconds; 23 / 4 in 0.252 seconds; all passed |
| Dedicated source and exact staged-scope contracts | exit 0 |
| Dedicated mutation contract | all 36 controlled mutations rejected; exit 0 |
| Bare `scripts/verify-investigation-boundaries` | exit 0, including Debug/Release Machine-driver binary boundaries |
| Bare `scripts/verify-contract` | exit 0; approximately 2,375 seconds |
| Independent grouped, cross-group and generic reviews | no unresolved P0-P2; final finding set empty |

The staged-only `StornautInvestigationTests` run executed 844 tests in 59
suites. It was not wholly green: its final run completed in 125.344 seconds
with two issues in the pre-existing fixed-gate physical cleanup path. All
shared-deadline, monotonic-clock, machine-profile, cohort and handoff-admission
cases passed.

The remaining issues came from the `overflowPrepared` physical scenario
returning `spawnUncertain` and failing to prove immediate gate-process absence
under aggregate load. The same failure class had appeared in
`malformedPrepared`. The physical scenario passed when rerun alone (1 test /
1 suite in 11.241 seconds), with no matching process, temporary-directory or
attempt-directory residue afterward. It was therefore isolated as the
fixed-gate deadline cleanup checkpoint rather than dismissed as noise. The
retirement deadline case also passed its exact rerun (1 test / 1 suite in 0.411
seconds).

No standalone targeted Release-build timing can be attributed exclusively to
this checkpoint. Debug/Release Machine-driver builds passed within the bare
boundary verifier.

## 6. Non-Claims and Next Order

This checkpoint ran no root or sudo operation, no installed
App/helper/driver/gate chain, no product XPC campaign and no Codex model,
authentication or network operation. It did not accept ADR 0018, establish
machine readiness, enable production Deep Dive or run `scripts/verify --full`.

The contemporaneous next step was the fixed-gate deadline cleanup repair,
which subsequently completed at `bc42fbc`. The current frontier is therefore
interactive-native identity binding repair, followed by
`ii-c -> L3c3d -> L3c4`. Task 39 remains incomplete, ADR 0018 remains
Proposed, and L3c4 exclusively owns final admission and the remaining
authoritative full verifier.
