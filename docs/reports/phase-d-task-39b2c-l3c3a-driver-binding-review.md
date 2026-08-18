# Phase D Task 39B2c-L3c3a Driver-Bound Signed Attempt Review

> Status: Complete; strict schema prerequisite only
>
> Date: 2026-08-18
>
> Baseline: `08ae188ef82987f406720c9cc947c5958364bb71`
>
> Scope: signed Machine-driver identity binding, strict enclosing schema
> migrations, installed identity comparison and blocked-until-L3c3b structural
> gates; no Xcode packaging, launcher, model, install/uninstall, readiness or
> authoritative full verifier

## 1. Decision

L3c3a is complete. Every Task 39 signed attempt now carries one required
`SignedInvestigationRuntimeMachineDriverBinding` containing the exact driver
executable SHA-256, fixed signing identifier, designated-requirement SHA-256,
CodeDirectory hash and fixed Machine-claim service identifier. The binding,
configuration, capability receipt, runtime report and every enclosing Machine
contract received explicit strict schema migrations. Missing, unknown, old or
malformed fields fail closed.

The DEBUG App leaf independently decodes the same closed three-level schema.
Production diagnostic composition reads the fixed installed driver path through
`LifecycleBundleSigningIdentityReader` and compares its complete static identity
to the signed binding. A missing driver therefore produces `bindingMismatch`.
That is the intended L3c3a state: all ordinary Debug/Release and diagnostic
Debug bundles still exclude the driver, and neither `Package.swift` nor the
Xcode project gains a production packaging or launch surface. L3c3b must
deliberately replace this absence gate with exact diagnostic-only native
packaging.

The exact schema versions are:

| Contract | Version |
| --- | ---: |
| `SignedInvestigationRuntimeMachineDriverBinding` | 1 |
| `SignedInvestigationRuntimeBinding` | 2 |
| `SignedInvestigationRuntimeDiagnosticConfiguration` | 3 |
| `SignedInvestigationCapabilityEvidenceReceipt` | 4 |
| `SignedInvestigationRuntimeReport` | 4 |
| `SignedInvestigationRuntimeMachineCaseEvidence` | 3 |
| `SignedInvestigationRuntimeFailureMatrix` | 3 |
| `SignedInvestigationRuntimeMachineReport` | 3 |
| `SignedInvestigationRuntimeLifecycleResidueRecord` | 2 |
| `SignedInvestigationRuntimeMachineEvidenceBundle` | 7 |

## 2. Exact Scope and Cost

The implementation changes exactly the fourteen non-document paths frozen by
the preflight:

1. `Sources/StornautInvestigation/SignedInvestigationRuntimeContract.swift`
2. `Sources/StornautInvestigationDiagnostic/InvestigationRuntimeDiagnosticAppLeaf.swift`
3. `Sources/StornautInvestigationDiagnostic/InvestigationRuntimeDiagnosticComposition.swift`
4. `Sources/StornautInvestigationMachine/SignedInvestigationRuntimeMachineContract.swift`
5. `StornautAppTests/InvestigationRuntimeDiagnosticTests.swift`
6. `Tests/StornautInvestigationTests/InvestigationLifecycleTopologyCollectorTests.swift`
7. `Tests/StornautInvestigationTests/InvestigationLifecycleTopologyTestSupport.swift`
8. `Tests/StornautInvestigationTests/InvestigationMachineRetirementClaimTests.swift`
9. `Tests/StornautInvestigationTests/InvestigationMachineScenarioTestSupport.swift`
10. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`
11. `Tests/StornautInvestigationTests/SignedRuntimeContractTests.swift`
12. `Tests/StornautInvestigationTests/SignedRuntimeMachineSerializationTests.swift`
13. `scripts/verify-app-release-boundaries`
14. `scripts/verify-investigation-boundaries`

The frozen implementation tree contains 1,266 additions and 22 deletions, well
below the approved 3,000-added-line ceiling. Its accepted staged tree is
`41521e44ba1e349496f3ab708d8e9f3f376620b3`. No package manifest, Xcode project,
scheme, helper, plist, lifecycle XPC selector, launcher, install script, model
flow or readiness verdict changed.

## 3. Tests First and Review Fixes

The mandatory Swift unit-test workflow completed preparation, scope and defect
analysis, tests-first red/green generation, affected validation, coverage
decision and report flush. Coverage execution was skipped because neither the
user, repository nor execution source defines an incremental coverage gate for
this checkpoint.

The initial red runs failed only for the deliberately missing driver-binding
type/fields. Strict configuration, nested unknown/missing fields, all installed
identity dimensions, enclosing Machine round trips and the independent App leaf
were then covered.

The grouped independent review found one P1: the first implementation accepted
only a 40-hex CodeDirectory hash while the authoritative
`LifecycleSigningIdentity` contract accepts lowercase 40 or 64 hex. A dedicated
test first reproduced the 64-hex rejection. Both signed and App-leaf validators
now use the exact 40-or-64 contract and reject 39/41/63/65 lengths, uppercase and
non-hex input. The App target independently covers both valid lengths and every
rejection class. The original reviewer and a second post-fix reviewer report no
remaining P0-P2.

The local review artifacts are available at:

- `/tmp/stornaut_l3c3a_review.kbMjaG/pre_fix_report.html`;
- `/tmp/stornaut_l3c3a_review.kbMjaG/report.html`; and
- `/tmp/stornaut_l3c3a_review.kbMjaG/report.md`.

The final empty finding set SHA-256 is
`37517e5f3dc66819f61f5a7bb8ace1921282415f10551d2defa5c3eb0985b570`.

## 4. Validation

| Gate | Result |
| --- | --- |
| strict contract + Machine serialization focused | 48/48 passed before structural closeout |
| new trusted-target structural suite | 2/2 passed |
| affected contract/topology/claim/boundary suites | 69 tests in 5 suites passed |
| complete Investigation target before post-fix | 198 tests in 19 suites passed |
| CodeDirectory hash post-fix focused | red on valid 64-hex, then green for valid 40/64 and invalid shapes |
| complete Investigation target after post-fix | 199 tests in 19 suites passed |
| dedicated diagnostic App target | 11/11 passed with independent 40/64 validation |
| exact Investigation structural boundary | passed without warnings |
| Machine target/driver build | passed |
| built driver fail-closed behavior | non-root exit 77 |
| ordinary Debug/Release and diagnostic App release boundary | passed; driver absent from all three bundles |
| clean staged-only serial regression | 1,057 tests in 51 suites passed |
| serial test / stage / wall time | 79.124 / 123.761 / 128 seconds |
| accepted implementation tree | `41521e44ba1e349496f3ab708d8e9f3f376620b3` |
| final independent post-fix review | no unresolved P0-P2 |

The clean staged-only serial ran exactly once from generated validation commit
`f88a08a7293612b547a121ee4f484f108148d739` over the accepted index tree. The index tree before and after the run
is exact, and the isolated validation worktree was removed. There was no restart,
failed-stage retry or second serial execution. Maximum Task 36/37 benchmarks
remained explicitly skipped. The diagnostic stage explicitly reported that
authoritative headless verification was not run.

`scripts/verify --full` was not run. Its remaining use is still reserved only
for L3c4 sealed final admission.

## 5. Safety Boundary and Next Gate

This checkpoint does not package or sign a native driver, launch the App, add a
handoff channel, call or authenticate a model, consume authoritative capability
evidence, install/remove the fixed topology, create a Machine report, enable
Deep Dive or claim readiness. Production Deep Dive remains unavailable.

The subsequent
[L3c3b preflight](phase-d-task-39b2c-l3c3b-scope-trust-preflight.md) split native
packaging from installer/L2 admission; L3c3b-i is next. It must package the fixed-signing driver
only in the diagnostic App and prove its built/staging/installed topology without
live installation, handoff or model execution. L3c3c-i remains a mandatory
repository-external launcher/handoff spike and ADR before any production handoff
code. L3c4 alone owns readiness and the remaining authoritative full verifier.

`~/.codex/config.toml` was not modified. No global same-UID process discovery or
coordination, dependency, license or product-availability change was added.
