# Phase D Task 39B2c-L3c3c-ii-b2b-iii-b-i Live Integration Review

> Status: Complete; public live facade, Lifecycle-owned reservation, helper
> composition, activation/cancellation/invalidation linearization, exact
> structural/final-Mach-O gates, one staged-only serial and independent
> post-fix/cross-group review passed; non-admitting
>
> Date: 2026-08-20
>
> Implementation commit: `9d80821a591f4d331e66575d310cd63a3c0340e8`
>
> Validated tree: `c0bbf8cd95b5c8e00f63deae0ca6fa22af84d853`
>
> Staged validation commit: `799d92b644d7707e32a9ac825ee57652acf7e4c8`
>
> Scope: semantic/live integration closure only; no executable physical clock/
> scheduler/terminal matrix, fixed Machine client, App/helper launch, real XPC,
> install, privilege, model/auth, readiness or authoritative full verifier

## 1. Outcome

L3c3c-ii-b2b-iii-b-i is complete. The package-scoped machine-claim server now
exposes the narrow public facade required by the lifecycle helper, while its
deadline ticket, sealed transfer and mutable state remain package-owned. The
Lifecycle escrow creates an independent reservation identifier and transfers it
exactly once; neither the helper nor the server invents or aliases that identity.

The helper now exports only the shared two-selector claim/release wire, records
the App retirement before activation, activates the server-owned reservation
before replying to the retired App, and removes the legacy one-selector service,
legacy timers and helper-side pending-state reads. The Xcode graph links the
claim-server product only into `StornautLifecycleHelper`. Ordinary, diagnostic
and Release App Mach-Os remain negative controls.

Independent review found real cancel-versus-activation and operation-versus-
invalidation races. The final implementation makes cancellation publication,
session creation, response commitment and deferred invalidation linearizable. A
cancel winner cannot publish a runtime or later create a session; a reserved
claim/release operation commits its reply before invalidation terminates the
session. The App's preactivation escrow projection and helper invalidation guard
jointly prevent an invalidated connection from becoming the retirement owner.

This checkpoint intentionally does not claim the helper-private physical clock,
scheduler or terminal adapters are executably closed. That bounded matrix is the
sole responsibility of iii-b-ii.

## 2. Scope, Cost and Artifact Identity

The implementation changed exactly thirteen non-document paths and 3,355
added-or-deleted lines (2,834 additions, 521 deletions), below the post-review
3,700-line ceiling. Two approved preflight documents were also corrected, for
fifteen paths total. `Package.swift`, HandoffContract, DriverSupport, native
driver, App/runtime product sources and every new production file remained
frozen.

The implementation commit is the direct child of
`17d9f1fecd670eb4ca7b7ddd92a27303c0c4bdb0`. Its tree
`c0bbf8cd95b5c8e00f63deae0ca6fa22af84d853` exactly matches the sole staged
validation commit `799d92b644d7707e32a9ac825ee57652acf7e4c8`; both commits have
the same parent. The implementation commit is pushed to `origin/main`.

Verifier source identity at that tree is sealed as follows:

- `scripts/verify-investigation-boundaries`: `19437cd2f2013fc8971a5669ff5d48cba4c6aabd9fb2d9285680423d246fdfa8`;
- `scripts/verify-app-release-boundaries`: `4b2f5b2a6c2a0624a0376d4751f5a8ec9b60ae62b23cc27991d81bec3df01075`; and
- normalized `scripts/verify-contract`: `ad9faa90b48435b4ca1b40f8cfe0253289a20df70732222e17105891a4a93cf1`.

## 3. Prompt-to-Artifact Completion Checklist

| Requirement | Direct evidence | Result |
| --- | --- | --- |
| narrow public live facade | public scalar facade tests; parser-backed exact-surface gate rejects every `public extension` escape | satisfied |
| Lifecycle-owned reservation | escrow tests prove fresh identifier distinct from token and one-shot sealed transfer | satisfied |
| record before activate before App reply | Lifecycle contract and helper-source ordering gates bind the exact sequence | satisfied |
| activation/cancel linearization | race tests prove a cancellation winner publishes no runtime and permanently disables `makeSession()` | satisfied |
| operation/invalidation linearization | reentrant claim/release tests prove reserved response commitment precedes deferred invalidation | satisfied |
| no invalidated App retirement owner | preactivation escrow projection plus helper invalidation guard; targeted source mutation controls | satisfied |
| exact shared wire and legacy removal | two-selector XPC contract tests and final helper artifact marker gates; legacy selector/service/timer checks are negative | satisfied |
| helper-only linkage | PBX graph gate and Debug/Release helper positive controls; every non-helper App Mach-O is a negative control | satisfied |
| fixed terminal semantics | public terminal effect is exactly-once and helper exit mapping remains closed/non-caller-selectable | satisfied for semantic facade; physical executable matrix deferred |
| old JSON fail closed | strict decode rejects after activation transfer and before claim-state consumption | satisfied |
| exact scope and cost | executable baseline/path/budget gate; observed 13 non-document paths / 3,355 lines | satisfied |
| no authority or admission expansion | no Execution/Trash authority, fixed client, launch/install/privilege/model/auth/readiness/full | satisfied |
| one serial and independent review | exact validated tree passed once; final review has no unresolved P0-P2 | satisfied |
| physical adapter closure | explicitly excluded and assigned to iii-b-ii with frozen nine-path/2,200-line ceiling | deferred by approved split |

## 4. Validation Evidence

| Gate | Result |
| --- | --- |
| final focused gate | 83 tests in 5 suites passed |
| affected regression | 499 tests in 42 suites passed |
| focused coverage | 191 functions / 1,740 lines / 564 regions; 94.76% / 93.97% / 88.48%; Effects 47/47 functions |
| `scripts/verify-contract` | exit 0; live facade, Xcode and final-Mach-O mutations plus scope/budget and source/self seals passed |
| `scripts/verify-investigation-boundaries` | exit 0; parser-backed public surface, Lifecycle seed, PBX graph and admission ordering passed |
| `scripts/verify-app-release-boundaries` | exit 0; Debug/Release helper positives and per-non-helper final-Mach-O negatives passed |
| sole staged-only serial | 1,212 tests in 58 suites passed; five maximum benchmarks explicitly skipped |
| serial timing | 81.754 seconds test time; 132.24 seconds real time; 136.737 seconds wrapper wall time |
| serial identity | validation `799d92b...`, implementation `9d80821...`, identical tree `c0bbf8c...` |
| independent review | concurrency, App-state, tests and verifier findings repaired; fresh cross-group review found no unresolved P0-P2 |
| diff hygiene | exact approved paths, no unstaged/untracked drift, `git diff --check` passed |

No authoritative full verifier ran. No test, gate or report in this checkpoint
substitutes for iii-b-ii's physical-adapter matrix or L3c4's machine admission.

## 5. Non-Admission and Next Gate

This checkpoint is non-admitting. It did not launch the App/helper, invoke real
XPC, create a fixed Machine client, install or execute a privileged artifact,
call a model, consume authorization, prove installed-L2/runtime residue or make a
readiness claim.

ADR 0018 remains Proposed. Task 39 remains incomplete. Production Deep Dive
remains `.implementationUnavailable`; only ii-c may accept ADR 0018, only L3c4
owns machine readiness and Task 39's remaining authoritative full verifier, and
only Task 44 may admit normal-product Deep Dive.

The strict next checkpoint is L3c3c-ii-b2b-iii-b-ii executable physical-adapter
closure. Only its completion closes iii-b and ii-b2b.
