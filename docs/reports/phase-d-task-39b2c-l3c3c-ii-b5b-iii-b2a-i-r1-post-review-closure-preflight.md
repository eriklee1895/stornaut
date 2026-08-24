# Phase D Task 39B2c L3c3c-ii-b5b-iii-b2a-i-r1 Post-Review Closure Preflight

> Status: complete / non-admitting; immutable completion seal recorded
>
> Date: 2026-08-24
>
> Baseline: `2f3a116be4644829fc513bcc2287c6bd2a1ea0ec`
>
> Closure commit: `6f6579834b3f5a707ab7b35152e5425e4260c6ad`
>
> Accepted implementation tree: `62994279cc5a262dee3a490d845dc2f32a8fa4b6`
>
> Completion-seal commit: `30ee32e02fd1ce5fe45a55f64f083f9294c85695`
>
> Scope: close six independent-review findings in the package-only supervisor
> and verifier surface. No Darwin spawn or descriptor I/O, App/helper/XPC
> launch, install, privilege, model/authentication/network operation, public
> driver entry, product admission or authoritative full verifier.

## 1. Reason for the split

The original iii-b2a-i implementation used 3,236 of its 3,600 non-document
line budget. Two verifier findings and four protocol findings require explicit
negative controls and concurrency tests. Keeping those corrections in the same
uncommitted review surface would exceed the frozen budget. The reviewed
implementation snapshot is therefore retained as a local, unpushed baseline,
and this correction is a separate checkpoint. Neither commit may be described
as complete until this closure, immutable seal and final review pass.

## 2. Confirmed defects and RED evidence

1. The App source-only authority denylist covered only the protocol file, not
   all five iii-b2a-i source inputs.
2. `verify-contract` did not mutation-test the App source-only gate.
3. A valid 65,536-byte configuration exceeded the admission transcript's
   64-KiB cap, and an encoding error left the actor in `.decided`.
4. Normal admission did not join the inner completion driver-observation digest
   to the independent outer initial/final observations.
5. The inner actor could be terminalized while awaiting the composer and still
   return the composer's success.
6. A generic package prover could construct a containment proof for an
   admitted token without knowing its admission owner or exact terminal digest.

The focused RED run compiled and produced exactly four behavior failures: one
`sizeLimitExceeded` and three expected-error assertions that did not throw. The
two verifier defects were independently reviewed and reproduced through missing
cross-file/App-gate negative controls.

## 3. Exact scope and budget

Maximum: eight non-document paths and 1,200 changed non-document lines against
the baseline. Planned paths:

1. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinOuterInnerProtocol.swift`;
2. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineHelperEpochContinuity.swift`;
3. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineSingleEpochPhysicalBridge.swift`;
4. `Tests/StornautInvestigationTests/InvestigationMachineDarwinOuterInnerProtocolTests.swift`;
5. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
6. `scripts/verify-app-release-boundaries`;
7. `scripts/verify-contract`; and
8. `scripts/verify-investigation-boundaries`.

Any ninth non-document path or more than 1,200 changed non-document lines
requires another split before the edit.

## 4. Correction contract

- Every iii-b2a-i source is scanned for direct process, file, network, syscall
  and descriptor authority. Existing injected `send` methods are admitted only
  by exact source-shape cardinality.
- The App gate has per-source authority mutations and a raw-DTO admission
  mutation with exact diagnostics.
- Admission transcript capacity covers the maximum valid canonical request and
  the complete exchange. Any local transcript construction failure consumes the
  actor terminally.
- A normal result's driver-observation digest equals both independent outer
  observation digests.
- An inner run rechecks nonterminal actor state after every composer suspension
  before returning a value.
- Generic containment proof construction rejects `.admittedPhysical`. The
  admitted-only constructor requires the private random admission owner and the
  token's exact terminal digest; the completion join validates the returned
  proof against the result without learning those secrets.

## 5. Validation

Run focused RED/GREEN, adjacent continuity/physical-bridge tests, affected
Investigation tests, exact contract/structural/App gates, applicable
Debug/Release builds, one final frozen-tree serialized SwiftPM regression and
independent post-fix review. Do not run `scripts/verify --full`.

The closure completed within its frozen eight-path / 1,200-line ceiling at
exactly eight non-document paths and 977 changed lines. The accepted tree passed
12 focused tests, 35 adjacent tests, 593 affected Investigation tests, all three
boundary gates, Debug/Release Machine Driver builds and one 1,475-test /
77-suite frozen-tree serial regression. Independent post-fix and seal review
reported no unresolved P0-P2. The three-path immutable seal records the original
implementation and r1 identities, exact scopes and same-path substitution
failures. Completion details are in the
[iii-b2a-i review](phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2a-i-review.md).
