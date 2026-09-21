# Phase D Task 39B2c ii-c Resolved Root-Driver Lineage L1 Completion Audit

> Status: complete / non-privileged / non-admitting
>
> Date: 2026-09-01
>
> Implementation: `83f6271ace2d52cc2ba170aae559a2d1fcc46864`
>
> Accepted tree: `98289e2b5764571b7a3a8a108d992905da6712ea`
>
> Verifier replay compatibility: `cf4041c346c2703092ddc46e7b45769c29ff2ffb`
>
> Baseline: `0815ee26624f83520e30ce68aa54396761c14566`
>
> Next frontier: L2 Driver/Gate state machine and evidence composition

## 1. Result

L1 is complete. The HandoffContract now owns a fixed 1,006-byte, self-sealed
`ResolvedRootDriverClaimV1`; DriverSupport owns an authority-free injected
collector; GateSupport owns a pure resolver/validator and PID-reuse-safe
retirement verifier. No production startup, pipe, sudo or campaign seam was
opened.

The validator admits direct exec continuity or a bounded one/two-monitor
successor chain, requires two stopped samples around the claim, binds kernel,
audit-token, executable node/SHA and static/live signing identity, and consumes
the complete canonical `InvestigationProjectedCohortInput`. Its capsule attempt
and whole-input SHA must equal the claim and expected binding before the exact
Installed-L2 projections are used. Detached or foreign-cohort projection arrays
are no longer representable at this boundary.

Root credentials remain exact while supplementary groups are the bounded,
sorted, unique observed root set containing GID 0; valid sudo-launched root
drivers are not incorrectly restricted to `[0]`.

## 2. Exact Scope and Budget

Relative to `0815ee2`, the implementation changes exactly eleven non-document
paths: 2,780 additions and 6 deletions, or 2,786 changed lines, below the frozen
3,900-line aggregate ceiling and every per-path ceiling.

| Path | Changed | Ceiling |
| --- | ---: | ---: |
| `Package.swift` | 5 | 20 |
| `Sources/StornautInvestigationHandoffContract/InvestigationResolvedRootDriverLineageContract.swift` | 465 | 520 |
| `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineResolvedRootDriverClaim.swift` | 370 | 520 |
| `Sources/StornautInvestigationMachineGateSupport/InvestigationMachineResolvedRootDriverValidator.swift` | 377 | 700 |
| `Tests/StornautInvestigationTests/InvestigationResolvedRootDriverLineageContractTests.swift` | 256 | 480 |
| `Tests/StornautInvestigationTests/InvestigationMachineResolvedRootDriverClaimTests.swift` | 327 | 420 |
| `Tests/StornautInvestigationTests/InvestigationMachineResolvedRootDriverValidatorTests.swift` | 494 | 600 |
| `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift` | 57 | 80 |
| `scripts/verify-investigation-boundaries` | 250 | 350 |
| `scripts/verify-contract` | 111 | 140 |
| `scripts/verify-app-release-boundaries` | 74 | 80 |

The follow-up replay-compatibility commit changes only the two verifier scripts
by 38 additions and 5 deletions. It makes completed ii-c-b1 and evidence gates
replay their immutable accepted commits and teaches the older live-claim
projection to subtract the exact L1 GateSupport/Handoff deltas. It does not
weaken their mutation matrices.

## 3. Validation Evidence

| Evidence | Result |
| --- | --- |
| L1 combined focused tests | 25 tests in 4 suites passed on the final implementation tree |
| L1 source contract | exit 0 |
| L1 staged-scope contract | exact 11 paths / 2,786 changed lines; exit 0 |
| L1 mutation contract | 15 controlled mutations plus scope negatives; exit 0 |
| L1 component/final-image gate | staged snapshot Debug build; required ordinary-product Mach-O inventory and Security/namespace controls passed |
| live-claim historical projection | exit 0 after subtracting exact L1 deltas |
| diff and shell hygiene | `git diff --cached --check` and `zsh -n` passed |

The one reserved staged-only serialized Investigation run executed once. It
finished with 959 tests in 65 suites and seven issues, all in three
`InvestigationMachineTargetBoundaryTests` entries: one target-block parser chose
the product declaration and two closed source inventories omitted the new L1
files. No product implementation test failed. Those three entries were fixed
and precisely rerun (3/3 passed); the full serial was intentionally not
duplicated.

The component gate initially exposed two gate defects: an unexported local PATH
prevented SwiftPM from spawning `codesign`, and an invalid Security-symbol
positive-control contradicted the frozen pure-validator design. The final gate
exports a fixed system PATH, forbids actual `_Sec*`, `_kSec*` and
`_Authorization*` authority, requires concrete ordinary-product Mach-O inputs,
fails closed on scanner failure, and passes.

## 4. Review Findings and Closure

Independent grouped review found five P1 classes and no P0:

- exact `[0]` supplementary groups rejected valid sudo-root shapes;
- Installed-L2 projections were not tied to the committed projected input;
- L1 gates were opt-in rather than wired into default verifier paths;
- the Security object check matched a framework name rather than real symbols;
- missing/unscannable closed images could pass vacuously.

All five were fixed. Final independent review of accepted tree `98289e2` is
empty (`/tmp/stornaut_l1_lineage_review.8X2Rmx/final_postfix_v3.jsonl`, SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`).
The rendered zero-finding reports are `/tmp/stornaut_l1_lineage_review.8X2Rmx/report.html`
(SHA-256 `fd26933ba7889d299b3447a022aaeabe20f489dd5d1a3122e5e7f10dbfc11ad4`)
and `report.md` (SHA-256
`f29c71ca995aacf692242d288db618bac4084f660a0192255742fe398ba53d15`).
The two-file replay follow-up also received an independent no-P0-P2 review.

## 5. Non-Claims and Next Step

L1 and its validation ran no sudo/root operation, install/uninstall, launchctl
mutation, real campaign, model/auth/network operation or full verifier. The
unique privileged ii-c-c attempt remains unconsumed. Task 39 remains incomplete,
ADR 0018 remains Proposed and production Deep Dive remains unavailable.

The frozen next checkpoint is L2: claim-before-business startup, self-stop, exact
claim read, live Gate validation, group continuation, completion-v3/evidence
joins and independent replay. After L2 is implemented, reviewed and pushed, the
next action is the unique ii-c-c machine campaign; no third lineage prerequisite
may be inserted.
