# Phase D Task 39B2c-L3c3c-ii-b5b-i-b1 Semantic Target Review

> Status: Complete; authority-closed installed-L2 semantic target, immutable
> complete observation, exact structural gates and independent review passed;
> non-admitting
>
> Date: 2026-08-21
>
> Implementation commit: `315d85ec98747f06f2bbfe2ba1b2d34324089ff7`
>
> Parent: `89662d0d802760a85c6894b87127288a23bcbb2d`
>
> Final accepted implementation tree:
> `35834ad00ec61441169d29566b98744a08237ec1`
>
> Staged validation commit: `d47209e2fef268035504d884456b31c72af7737f`
>
> Staged validation tree: `9e8762f4c312c3aa8df94c1c7e2354ba073981c2`
>
> Scope: exactly six non-document source/test/script paths; no physical reader,
> DriverSupport join, App/helper launch, real XPC, install, root, model, auth,
> network, readiness claim or authoritative full verifier

## 1. Outcome

ii-b5b-i-b1 is complete. The new non-product
`StornautInvestigationInstalledL2` target depends only on
`StornautInvestigationHandoffContract` and owns the installed-phase semantic
vocabulary and predicate. It defines exactly eight artifact roles, closed
artifact/service states, complete immutable App/helper/driver evidence, paired
clock samples and one package-scoped, non-`Codable` ordinary observation.

The contract accepts only typed facts. It requires all eight artifact roles,
with the six installed artifacts present and valid while only runtime/lease
roots may also be absent. It joins distinct complete App/helper identities,
exact executable commitments, static/live signing equality, the fixed helper
service identity, the projected driver signing facts and same-domain clock
ordering. Missing, foreign, unavailable, invalid, rollback or expired facts
fail closed.

This checkpoint adds no filesystem, process, service or signing reader. It does
not accept claim evidence, perform the repeated-App join or mint an opaque
installed-L2 proof. Those boundaries remain with i-b2a/i-b2b/i-b3 and i-c as
frozen by the exact-path preflight.

## 2. Scope, Cost and Tree Identity

The implementation changed exactly the six frozen non-document paths and 979
added-or-deleted lines: 968 additions and 11 deletions, below the 1,800-line
ceiling:

1. `Package.swift`;
2. `Sources/StornautInvestigationInstalledL2/InstalledL2SemanticContract.swift`;
3. `Tests/StornautInvestigationTests/InstalledL2SemanticContractTests.swift`;
4. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
5. `scripts/verify-contract`; and
6. `scripts/verify-investigation-boundaries`.

Implementation commit `315d85ec98747f06f2bbfe2ba1b2d34324089ff7` and
validation commit `d47209e2fef268035504d884456b31c72af7737f` share parent
`89662d0d802760a85c6894b87127288a23bcbb2d`. Their trees differ by exactly one
test line: the final accepted tree updates the historical
`StornautInvestigationHandoffContract` consumer-count expectation from six to
seven after the new target became its seventh package consumer. No production
source, package declaration or verifier differs between the validation and
accepted trees.

## 3. Contract Completion Checklist

| Requirement | Direct evidence | Result |
| --- | --- | --- |
| authority-closed target | sole target dependency is HandoffContract; source imports only Foundation and HandoffContract | satisfied |
| exact artifact vocabulary | closed eight-role enum and exact-key-set predicate | satisfied |
| immutable process facts | package-scoped `let` identity, executable digest and static/live signing evidence | satisfied |
| complete ordinary observation | projection/epoch/nonce, all artifacts, full App/helper/driver/service facts and both samples are retained | satisfied |
| exact identity and signing joins | App/helper roles and distinct identity, executable commitments, static/live equality, fixed identifiers and driver requirement/CDHash/ad-hoc joins | satisfied |
| exact service join | loaded service identity must equal the complete helper identity | satisfied |
| clock separation | wall ordering/expiry and continuous ordering are checked without cross-domain conversion | satisfied |
| no opaque-proof overreach | no claim evidence, repeated-App join, release/epoch deadline, proof minting, readiness or receipt | satisfied |
| no physical authority | no filesystem/process/service/Security/XPC/write/signal/cleanup implementation | satisfied |
| closed API | package-scoped, `Sendable`/`Equatable`, non-public and non-`Codable` | satisfied |

## 4. Validation Evidence

| Gate | Result |
| --- | --- |
| final focused semantic suite | 8 top-level tests passed; parameter matrices covered 8 artifact roles, 10 projection/signing mutations, 7 process/service mutations and 5 clock mutations |
| final affected regression | 26 tests in 2 suites passed |
| `scripts/verify-contract` | exit 0; dependency/public/`Codable`/authority, artifact/signing/service/cross-clock and exact scope/budget mutation controls passed |
| `scripts/verify-investigation-boundaries` | exit 0; package dependency, import, source-seal and authority boundaries passed |
| applicable Mach-O boundary | passed; no new write/process/network/signal authority and no final composition admission claim |
| independent review | four P1 findings were repaired; final review found no unresolved P0-P2 |

The checkpoint's only staged-only serial ran from validation commit
`d47209e2fef268035504d884456b31c72af7737f`, tree
`9e8762f4c312c3aa8df94c1c7e2354ba073981c2`. It executed 1,311 tests in 64
suites in 101.235 seconds and recorded four issues. It was not green and was
not restarted or rerun. The exact failures were closed narrowly:

- the CleanupPlan performance case measured 2.290 seconds against its strict
  `< 2`-second threshold; the exact case passed on the same validation tree at
  1.659 seconds;
- two Codex fixture cases failed in the serial; those exact two cases passed on
  the same validation tree; and
- the checkpoint-related HandoffContract static consumer-count test still
  expected six consumers after this target added the seventh. The accepted tree
  changes only that one expectation from six to seven, and the exact case
  passed.

The final 26-test affected run and focused/contract/structural/Mach-O gates
passed on the accepted implementation. This evidence is deliberately not
described as a clean or green serial, and the exact-case reruns are not treated
as a substitute whole-package regression.

## 5. Independent Review and Repairs

Independent review found four P1 issues and all were closed before acceptance:

- process evidence became immutable rather than retaining a mutable fact
  surface;
- the semantic observation now preserves the complete App/helper/driver,
  artifact, service and clock facts instead of collapsing them into a lossy
  summary;
- the ordinary installed observation no longer crosses the i-c boundary by
  presenting itself as an opaque installed-L2 proof; and
- driver static and live signing evidence must compare equal before the
  projection join can succeed.

The final independent review found no unresolved P0-P2.

## 6. Non-Admission and Next Gate

ii-b5b-i-b1 is complete but non-admitting. It did not launch an App/helper, use
real XPC, install or mutate system state, use root, call a model, read auth,
access a network, create a machine report/receipt or run
`scripts/verify --full`. ADR 0018 remains Proposed, Task 39 remains incomplete
and production Deep Dive remains `.implementationUnavailable`.

The strict next checkpoint is ii-b5b-i-b2a artifact/static readers. i-b2b still
owns process/service readers plus the narrow read-only C identity target, i-b3
owns observer composition, and i-c exclusively owns the DriverSupport join,
opaque proof and legacy-owner closure. L3c4 alone owns machine readiness and
Task 39's remaining authoritative full verifier.
