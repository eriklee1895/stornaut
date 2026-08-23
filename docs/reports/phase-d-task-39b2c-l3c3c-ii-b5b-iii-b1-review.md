# Phase D Task 39B2c L3c3c-ii-b5b-iii-b1 Injected Cohort Review

> Status: complete / non-admitting
>
> Date: 2026-08-23
>
> Implementation commit: `5e2365d0c5f3fbeef8e015f5e9ad4252c484217e`
>
> Parent: `67306345f057398063aa20f6b9b2ae7f6175d9af`
>
> Implementation tree: `b46d39bfcb4a24cee80b4be9562e281519450cb8`
>
> Completion-seal commit: `b08077f26dff73db24050948dc75866c4e921365`
>
> Next frontier: ii-b5b-iii-b2a Darwin outer/inner physical adapter

## 1. Result

iii-b1 closes the package-only injected eight-epoch cohort state machine. It
consumes exactly one projected plan, constructs a fresh selection-bound execution
wrapper and outer containment join for each epoch, carries only the immediately
preceding opaque helper continuity, and stops permanently on any error, drift,
uncertainty or cancellation.

The implementation changes exactly seven non-document paths against the frozen
parent: 2,373 additions and 65 deletions, or 2,438 changed lines. This remains
inside the eight-path / 3,200-line ceiling. It adds no target, package dependency,
public or `Codable` protocol, physical process launch, descriptor transport, file
write, network access, cleanup authority, readiness claim or product admission.

## 2. Implemented Contract

- The actor is one-shot: `ready -> running -> terminal`, with `running` committed
  before the first suspension and no retry after success or failure.
- Ordinals zero through seven are consumed in order. Each selection must preserve
  the outer-attempt UUID, capsule digest, projected-input digest, epoch/projection
  identity and the exact scenario-to-ordinal mapping. UUID reuse fails closed.
- `.lifecycleRecovery` maps only to `.parentCrash`; the other seven scenarios map
  only to `.normal`. The factory cannot choose the overlay.
- Each epoch requires a distinct retained execution wrapper. The wrapper is
  selection- and mode-bound, one-shot, and exposes only the injected composer and
  containment prover.
- Cancellation is checked before selection, after selection, after dependency
  construction and after exact plan exhaustion. External containment uncertainty
  or foreign proof remains authoritative over caller cancellation.
- The ordinal-seven successor retains its exact completed selection and proof.
  Final destruction is one-shot and revalidates cohort, projection, helper,
  containment mode and the complete successor transcript before consuming it.
- Success requires a ninth plan read that returns exactly typed `.exhausted`; an
  extra epoch or another plan failure cannot produce a completion summary.
- The returned summary is package-only and non-`Codable`; it carries identity and
  count only and is not admission or execution authority.

## 3. Verification Evidence

The final implementation tree passed:

| Gate | Result |
| --- | --- |
| exact 7-path / 2,438-line scope and modes | passed |
| `InvestigationMachineEightEpochCohortTests` | 13 top-level tests / 1 suite passed |
| affected `StornautInvestigationTests` | 573 tests / 42 suites passed |
| `scripts/verify-contract` | passed, including exact semantic diagnostics and mutation controls |
| `scripts/verify-investigation-boundaries` | passed, including SwiftPM Debug/Release exact projections |
| `scripts/verify-app-release-boundaries` | passed, including Xcode Debug/Release and ordinary-App negative boundaries |
| clean same-tree staged-only serial regression | 1,455 tests / 75 suites passed; 93.236 seconds test time, 161.993 seconds complete step |
| independent implementation and verifier review | no unresolved P0-P2 findings |

The staged validation commit `1712c1e` and pushed implementation commit
`5e2365d` share exact tree `b46d39bfcb4a24cee80b4be9562e281519450cb8`.
The completion seal then replays the pushed implementation commit and pins its
parent, tree, seven paths and exact 2,438-line count. Same-path tamper mutations
cover both production sources, both tests and all three verifier scripts.

The accepted primary source hashes are:

- cohort: `822cecb3489e16b9713244ff45312726045ffcc235757d132a6d6ca13ea4c3e2`;
- helper continuity: `89e21c75856601fccdbb4c6ff21fddc485b81407c11aebf9ee1cc202da318a61`;
- focused tests: `0300da3c92a1eed18c8ea15f6c6f99116f2c03a0383347a0b444c477fbd58449`.

The SwiftPM Machine Driver loaded-library projection stayed unchanged. Its only
new undefined symbols are Swift collection/object-identity/hash runtime support;
owned-symbol additions are the cohort, execution wrapper, completion summary and
final-continuity destruction. Xcode Debug/Release projections show the same
bounded change. No new write, spawn, network, Trash, Executor or
`StornautExecution` authority was observed.

## 4. Review Closure

Independent review found and closed two verifier false-success windows:

1. semantic mutation fixtures originally accepted any diagnostic containing
   `iii-b1`, allowing the final source hash to mask a missing semantic check; each
   fixture now requires its exact semantic failure, while only the dedicated
   source-seal mutation may fail on the source hash; and
2. the staged-scope verifier initially constrained only path/mode/budget. After
   the implementation commit was pushed, the completion seal bound the immutable
   commit, parent, tree, path set and line count and added same-path tampering for
   every checkpoint artifact.

The full post-fix implementation/verifier review reports no unresolved P0-P2.
The `Cleanup` source scanner was also narrowed only for the closed enum token
`.artifactCleanupFailure`; exact imports, source hashes and all other authority
tokens remain enforced.

## 5. Non-Claims and Next Step

This checkpoint did not launch the installed App/helper, run real XPC, use root,
read Codex authentication, call a model, access the network or run
`scripts/verify --full`. No real authenticated Codex App Server run occurred in
iii-b1. The unrelated `codex app-server --listen stdio://` process observed on
the machine was started on 2026-08-21, not by this checkpoint.

ADR 0018 remains Proposed, Task 39 remains incomplete and production Deep Dive
remains `.implementationUnavailable`. The next checkpoint is iii-b2a, which owns
the Darwin outer/inner physical adapter but not the zero-argument entry, FD-0
intake, privileged install, authenticated model run, machine readiness or product
availability.
