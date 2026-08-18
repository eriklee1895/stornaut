# Phase D Task 39B2c-L3c2b Plan Freshness Prerequisite Review

> Status: Complete; non-admitting machine-contract prerequisite
>
> Date: 2026-08-18
>
> Baseline: `c79e74c2c6123135bdb80e8d4a91e710bb107cab`
>
> Scope: fresh actual Investigation-plan identity and shared target-set binding
> for the eight-scenario Machine matrix; no scenario driver, model, packaging,
> report admission, readiness or full verifier

## 1. Decision

The L3c2b mandatory preflight exposed a real contract contradiction and this
narrow prerequisite closes it. A real `InvestigationPlan.fingerprint` includes
the Investigation ID, complete limits, timestamps and ordered target payloads,
as required by ADR 0017. L3c2b also requires each scenario to use a fresh nonce
and therefore a fresh Investigation ID. Eight real fresh plans consequently
have eight distinct plan fingerprints.

The previous `SignedInvestigationRuntimeFailureMatrix` instead required every
case to carry the same `planFingerprint`. The shared test fixture hid the
contradiction by writing a constant synthetic `bbbb...` fingerprint into every
case. That rule would reject the forthcoming real Task 38 scenario cohort while
accepting a fixture that was not bound to any actual plan.

The corrected contract now requires both independent properties:

- every case has a distinct actual `planFingerprint`, preventing plan replay
  between fresh attempts; and
- every case carries the same `targetSetFingerprint`, proving that the eight
  fresh plans investigate one exact logical target cohort rather than unrelated
  targets.

`SignedInvestigationRuntimeMachineCaseEvidence` now carries the target-set
fingerprint directly. The shared fixture constructs an actual
`InvestigationPlan` for each configuration and uses its real plan and target-set
fingerprints by default.

## 2. Tests First

The mandatory unit-test workflow generated a real-plan cohort regression before
production changes. It constructed eight fresh configurations and eight actual
plans with fresh Investigation IDs but one exact target set, then proved:

- eight distinct plan fingerprints;
- one target-set fingerprint; and
- the correct matrix should accept the cohort.

Before the fix, the test compiled and failed with
`SignedInvestigationRuntimeContractError.invalidReport` at matrix construction.
After the contract repair, the same test passed. A second assertion reuses one
actual plan fingerprint across two otherwise fresh cases and requires rejection.

The prior mixed-plan test was corrected to exercise the actual forbidden splice:
one case now carries a foreign target-set fingerprint while retaining its own
fresh plan fingerprint.

## 3. Schema and Strict Decoding

Adding a required field changes the persisted machine evidence wire. Versions
were bumped explicitly rather than allowing an old payload to be interpreted
under new semantics:

- `SignedInvestigationRuntimeMachineCaseEvidence`: schema 1 -> 2;
- `SignedInvestigationRuntimeFailureMatrix`: schema 1 -> 2;
- `SignedInvestigationRuntimeMachineReport`: schema 1 -> 2; and
- `SignedInvestigationRuntimeMachineEvidenceBundle`: schema 5 -> 6.

Serialization tests verify round-trip values and reject:

- legacy outer bundle schema 5;
- legacy report and matrix schema 1;
- legacy case schema 1;
- missing `targetSetFingerprint`;
- a valid-format foreign target-set fingerprint; and
- unknown nested fields and existing hash tamper cases.

Outer matrix/report hashes are rebuilt from the complete encoded values, so the
new field participates in canonical evidence identity.

## 4. Validation

| Gate | Result |
| --- | --- |
| real-plan cohort red test | compiled; expected `.invalidReport` before fix |
| exact red-to-green regression | passed after contract repair |
| contract + serialization affected | 48 tests in 2 suites passed |
| contract + serialization + adversarial | 59 tests in 3 suites passed |
| complete `StornautInvestigationTests` | 189 tests in 18 suites passed |
| exact Investigation structural boundary | passed |
| staged diff hygiene | passed |
| independent review | no unresolved P0-P2 |

The implementation changes exactly three non-document paths with 249 additions
and 10 deletions. The accepted staged implementation tree is
`3ae763de9e8d056428bde9d0bbfd0c4eadee1e2a`.

This prerequisite intentionally does not run `scripts/verify --full` or another
whole-repository serial. It does not move authority, alter App/UI behavior,
package the driver, or make a readiness claim; its complete affected suites,
full Investigation suite, structural gate and independent review are the
approved narrow-checkpoint substitute. L3c4 still exclusively owns Task 39's
remaining full verifier.

## 5. Safety Boundary and Next Gate

This prerequisite does not execute any scenario, create a Machine failure
matrix from runtime observations, invoke Task 38, call a model, install or
remove topology, create a Ready receipt or enable Deep Dive. It adds no process,
network, filesystem mutation, Cleanup, Trash, Policy, Executor or Registered
Action authority.

L3c2b fixed eight-scenario driving resumes next. Its runner must now source both
fingerprints from each actual Task 38 plan, use one exact target set across all
eight fresh attempts and reject any replay or cross-target splice.
