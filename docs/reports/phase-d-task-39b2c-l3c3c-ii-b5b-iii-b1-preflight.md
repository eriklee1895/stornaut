# Phase D Task 39B2c L3c3c-ii-b5b-iii-b1 Injected Cohort Preflight

> Status: scope, trust boundary, tests-first matrix and budget frozen; RED
> contract confirmed; production implementation not started
>
> Date: 2026-08-23
>
> Baseline: `61f70b85c819c96e61f37482437e2af3a2d40ca4`
>
> Scope: package-only deterministic cohort state; no Darwin spawn, descriptor
> transport, App/helper/XPC launch, install, root, model, authentication, network,
> product admission or authoritative full verifier

## 1. Decision

iii-b1 remains one bounded implementation checkpoint. It composes the existing
one-shot projected plan and iii-a single-epoch continuity into one injected
eight-epoch actor. It does not implement the physical outer/inner topology.

The cohort owns the plan, current continuity and every per-epoch composition. A
factory may provide only selection-bound semantic execution dependencies. The
cohort itself constructs a fresh `InvestigationMachineOuterCompletionJoin` and
`InvestigationMachineSingleEpochComposition` for each epoch; callers cannot
return a raw successor continuity or select an epoch, overlay, descriptor, path
or process identity.

No new plan exhaustion API is needed. After eight sealed epochs, the cohort uses
the existing ninth `takeNext()` and accepts only the exact typed `.exhausted`
result. Adding `isExhausted` would create a repeatable observation/TOCTOU surface.

## 2. Frozen State and Trust Contract

The package actor is permanently one-shot:

```text
ready -> running -> terminal
```

`running` is set before the first suspension. Success, dependency error,
selection drift, containment uncertainty and cancellation all leave the actor
terminal; no retry or resume exists.

For ordinals zero through seven, the actor must:

1. reject cancellation before consuming the next selection;
2. take exactly one internally ordered epoch/projection pair;
3. require the exact ordinal/scenario relation and unchanged outer-attempt,
   capsule and projected-input bindings;
4. derive `.parentCrash` only for `.lifecycleRecovery`, and `.normal` for the
   other seven scenarios;
5. request one fresh selection-bound execution dependency object;
6. construct the per-epoch join/composition internally;
7. run it with genesis or the immediately preceding continuity; and
8. stop before selecting the next epoch on any failure or uncertainty.

After ordinal seven, the actor irreversibly destroys the final successor
continuity, proves the plan's ninth read is exactly `.exhausted`, and returns
only a package-only, non-`Codable` summary containing the cohort identity and
completed count. The summary is not admission or execution authority.

The final continuity API is package-only and one-shot. It accepts only an exact
ordinal-seven successor from the same cohort and validates the retained outer
proof before consuming itself. Genesis, earlier successors, foreign selection,
zero/foreign proof and replay fail closed.

## 3. Exact Scope and Cost

Maximum: eight non-document paths and 3,200 changed lines. Planned set: seven
paths, leaving one emergency path unused.

1. new `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineEightEpochCohort.swift`;
2. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineHelperEpochContinuity.swift`;
3. new `Tests/StornautInvestigationTests/InvestigationMachineEightEpochCohortTests.swift`;
4. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
5. `scripts/verify-contract`;
6. `scripts/verify-investigation-boundaries`; and
7. `scripts/verify-app-release-boundaries`.

`Package.swift`, Xcode project files, the fixed plan/intake source and its tests
are excluded. If implementation needs a planning protocol, C shim, new target,
Xcode membership or another production path, stop and split before continuing.

## 4. Tests-First Matrix

The focused suite must cover:

- exact eight ordered selections and fixed overlay mapping;
- distinct execution dependency objects and exactly one factory/run/proof per
  epoch;
- genesis only at ordinal zero and immediate prior-helper propagation through
  ordinals one through seven;
- actor reentrancy, concurrent run and permanent one-shot behavior;
- factory, composer, containment, cancellation and binding failure at early,
  middle and final epochs, with no prefetch or later execution;
- reused/misbound execution dependency rejection before running it;
- containment uncertainty and foreign proof outranking caller cancellation;
- final continuity destruction, replay rejection and exact ninth-read
  exhaustion; and
- a package/source/final-artifact negative surface with no physical, write,
  network, cleanup or readiness authority.

The tests-first RED command was:

```text
swift test --no-parallel --filter InvestigationMachineEightEpochCohortTests
```

It compiled and ran two tests; both failed for the intended missing artifacts:
the cohort source did not exist and `destroyAfterFinal` did not exist. There was
no infrastructure or unrelated historical failure.

## 5. Validation Funnel and Non-Claims

Validation order is structural/source/scope, exact focused tests, affected
Investigation tests, contract/Investigation/App-release gates, applicable
Debug/Release projections, one clean staged-only serial and independent
implementation/verifier/cross-boundary review. This checkpoint does not run
`scripts/verify --full`.

iii-b1 cannot accept ADR 0018, run the no-model privileged gate, call Codex or
claim machine readiness. Production Deep Dive remains
`.implementationUnavailable`. The next checkpoint after iii-b1 is iii-b2a
Darwin outer/inner physical adaptation.
