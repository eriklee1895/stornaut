# Phase D Task 39B2c Shared-Deadline Repair Preflight

> Status: complete / non-admitting
>
> Date: 2026-08-30
>
> Implementation: `c144c1e1d7b21e40f300cddfe1ff2c80993513db`
>
> Tree: `3c2d7f01b73e0b5a943262a4b1fd273e00e4a0d0`
>
> Completion audit:
> [Shared-Deadline Repair Completion Audit](phase-d-task-39b2c-shared-deadline-repair-review.md)
>
> Implementation scope baseline: `66453397ae70c59347f02fff4e1a5528926c5141`
> (`8452f9c466574e550ac8bc8540287b76d444e07e` was the original defect
> baseline; the newer baseline adds only the independently committed historical
> boundary-diagnostic assertion alignment.)
>
> Scope: local source, tests and structural verifiers only. No root/sudo,
> installed App/helper/driver launch, product XPC, model/auth, network or
> `scripts/verify --full` is authorized by this checkpoint.

## 1. Defect and Decision

The current c0b-iv cohort eagerly seals eight configurations with one
`validBefore = planningAt + 600 seconds`, while the accepted machine driver runs
the eight epochs strictly in order and gives each epoch an independent
140-second monotonic ceiling. The bounded worst case is therefore 1,120 seconds,
so a valid slow campaign can make later configurations expire before admission.
Raising the shared deadline only to the generic 900-second configuration limit
does not close the defect.

The repair keeps the already accepted sequential continuity and immutable
projected-cohort identities. It separates two existing time roles:

1. the canonical focused `InvestigationPlan` remains an admission-freshness
   artifact with `expiresAt = planningAt + 600 seconds`;
2. the machine-only, pre-authored configuration cohort uses one fixed
   `validBefore = planningAt + 1,200 seconds`; and
3. each launched epoch still receives its existing just-in-time 140-second
   monotonic deadline. The App-side Lifecycle/App Server deadline is derived
   once per epoch as `min(configuration.validBefore, epochStart + 140 seconds)`.

The general diagnostic configuration constructor and decoder retain their
900-second ceiling. Only package-scoped machine-cohort construction, decoding
and final validation may accept the 1,200-second horizon. This is not a schema
change: the JSON keys, schema version, Handoff binary layouts and Store schema
remain unchanged.

Immediately before the coordinator calls the fixed sudo/gate handoff, it must
revalidate the complete projected cohort and require at least
`8 * 140 + 5 = 1,125 seconds` remaining. The five-second reserve matches the
driver's bounded terminal output window. Insufficient, non-finite, mismatched or
expired timing fails before any gate/root spawn.

## 2. Rejected Alternatives

- A 900-second shared deadline is still shorter than the 1,120-second bounded
  sequential campaign.
- Per-epoch wall deadlines do not close the 1,120/900 contradiction and would
  change otherwise shared configuration bytes.
- Reauthoring configuration at epoch start would change configuration SHA-256,
  L2 projection, capsule and whole-input identity after the parent sealed them.
- Parallel epochs would break the accepted single helper/continuity chain and
  enlarge the process-ownership review surface.
- Extending generic Lifecycle or Codex validity beyond 900 seconds would widen
  a reusable runtime boundary instead of repairing the machine-only caller.

## 3. Exact Scope and Budget

Post-RED semantic review found that the inherited App leaf must retain the
epoch-start wall clock before configuration acknowledgement, and that the
machine decoder must close the exact machine profile rather than only widen
the validity horizon. Those repairs stay inside the same fourteen paths but
need a small amount of production and negative-test evidence not included in
the original estimate. The frozen scope therefore remains exactly the same,
while the ceiling is amended before the repair to at most fourteen
non-document paths and 1,600 added-or-deleted non-document lines. A grouped
review then required five concrete closures: bootstrap-time binding, runner
profile admission, final shared-deadline revalidation, non-vacuous test
verification and binary-numstat rejection. Those repairs remain inside the
same fourteen paths:

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
13. `scripts/verify-investigation-boundaries`; and
14. `scripts/verify-contract`.

Production changes are capped at 350 lines, tests at 750 lines and verifiers at
500 lines; the three categories are independent ceilings and may total up to
1,600 lines. A fifteenth non-document path or line 1,601 blocks implementation
and requires a new scope decision. Documentation is outside this count. The
amendment does not add a target, protocol field, machine action or authority.

## 4. Tests First

RED evidence must cover all of the following before production changes:

- the focused Plan remains exactly 600 seconds while all eight machine
  configurations share exactly 1,200 seconds;
- generic construction/decoding still rejects 901 seconds; machine-only
  construction/decoding accepts exactly 1,200 and rejects values beyond it,
  equality, expiry and non-finite time;
- projected cohort authoring accepts only the machine profile, retains exact
  canonical configuration bytes and hashes, and rejects an overlong horizon;
- inherited App acknowledgement accepts a fresh machine cohort configuration;
- the derived Lifecycle start deadline is exactly the earlier of the cohort
  deadline and `epochStart + maximumWallClockSeconds`, without changing the
  configuration digest;
- machine runner/final assembly accepts a valid long-horizon configuration but
  continues rejecting expired evidence and case duration over 140 seconds; and
- coordinator pre-handoff admission accepts exactly 1,125 seconds remaining,
  rejects one microsecond less, rejects mixed deadlines, and makes zero handoff
  calls on rejection.

Structural mutations must reject replacing machine-only decode with the generic
decoder, removing or weakening the session clamp, changing the fixed 1,200 /
140 / 5-second constants, removing pre-handoff admission, or making any deadline
caller-selected.

## 5. Validation and Non-Claims

Use the existing funnel: RED focused cases, minimum production fix, affected
focused suites, named structural/mutation gates, one clean staged-only serialized
`StornautInvestigationTests` run, then independent grouped review. Coverage is
reported only if the repository's existing opt-in coverage command can run
without duplicating the serial suite. No authoritative full verifier is run here.

This checkpoint does not run or admit ii-c, does not accept ADR 0018, does not
enable product Deep Dive, and adds no root, cleanup, Executor, network, target,
dependency, command-line, environment or persistent protocol authority. The
original preflight expected interactive-native binding repair next. The staged
serial instead exposed the independent fixed-gate deadline cleanup defect,
which was isolated and subsequently closed before returning to
`interactive-native identity binding repair -> ii-c -> L3c3d -> L3c4`.
