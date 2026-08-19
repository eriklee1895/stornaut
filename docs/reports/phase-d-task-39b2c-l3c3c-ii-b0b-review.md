# Phase D Task 39B2c-L3c3c-ii-b0b Claim/Release Wire Review

> Status: Complete; exact claim/evidence/release wire implemented and reviewed
>
> Date: 2026-08-19
>
> Implementation commit: `96fdb0eb3b7c116f3cfd035d7e41009b22a90784`
>
> Implementation tree: `ab60a7c928bb13f31c3ecf796dbb73937af7f367`
>
> Scope: non-product claim/release wire contract only; no App leaf, install,
> privilege, model/auth, readiness or final verifier

## 1. Outcome

L3c3c-ii-b0b is complete. Together, ii-b0a and ii-b0b now close the shared
frame/capsule and claim/evidence/release wire contract. The next frontier is
ii-b1, the authority-free App inherited-FD leaf.

The implementation adds the complete request-derived expectation, enforces
`observed <= recorded <= issued <= claimed < validBefore`, strictly decodes the
Data-only XPC payload, and keeps the package target free of filesystem, clock,
scheduler and state-owner authority. Recursive absence scanning now covers the
full App bundle. A 768-byte evidence golden plus nested App/helper/owner/L1
mutations freeze the exact bytes and fail-closed joins.

## 2. Scope and Tests First

The checkpoint changed exactly six non-document paths with 1,980 additions and
21 deletions, within the frozen six-path / 2,200-line ceiling:

1. `Sources/StornautInvestigationHandoffContract/InvestigationMachineClaimContract.swift`
2. `Tests/StornautInvestigationTests/InvestigationMachineClaimContractTests.swift`
3. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`
4. `scripts/verify-app-release-boundaries`
5. `scripts/verify-contract`
6. `scripts/verify-investigation-boundaries`

The tests-first RED was the expected compile failure for missing claim/release
APIs. The implementation also expanded the filesystem/clock/scheduler/state-
owner denylist and the recursive full-bundle absence contract.

## 3. Validation and Review

| Gate | Result |
| --- | --- |
| tests-first RED | missing claim/release APIs compile failure |
| focused claim/release contract | 15/15 passed |
| exact boundary test | 1/1 passed |
| Investigation regression | 261 tests in 22 suites passed |
| Debug target build | passed via XcodeBuildMCP SwiftPM |
| Release target build | passed |
| coverage | 42/42 functions; 575/577 lines, 99.65% |
| `verify-investigation-boundaries` | independent exit 0 |
| `verify-contract` | independent exit 0 |
| clean staged-only serial | 1,122 tests in 54 suites passed |
| serial test / stage time | 94.708 / 97.349 seconds |
| accepted implementation tree | `ab60a7c928bb13f31c3ecf796dbb73937af7f367` |
| two final review paths | no unresolved P0-P2 |

The staged serial ran exactly once and passed without retry. The two final
reviews independently found no unresolved P0-P2.

## 4. Safety Boundary and Next Gate

This checkpoint did not run `verify-app-release-boundaries`, authoritative
headless/full verification, App/XCUITest, sudo, install, model or auth. It made
no readiness claim. ADR 0018 remains Proposed, Task 39 remains incomplete,
production Deep Dive remains unavailable, real Trash remains closed and the
final full verifier remains reserved for L3c4.

ii-b1 is next. It may implement only the authority-free App inherited-FD leaf
against the now-complete ii-b0a/ii-b0b wire contract. Later helper, concrete App
adapter, claim client, single-epoch composition and privileged gates remain
outside ii-b1.
