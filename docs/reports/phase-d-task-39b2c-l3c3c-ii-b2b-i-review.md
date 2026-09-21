# Phase D Task 39B2c-L3c3c-ii-b2b-i Machine-Claim Server Review

> Status: Complete; sealed Lifecycle transfer, non-actor shared-wire adapter,
> injected deadline effects, exact source/package gates, executable mutations,
> one staged-only serial and independent post-fix reviews passed; non-connected
> and non-admitting
>
> Date: 2026-08-20
>
> a1 commit: `e90a139a862b55518189cca1e4bc611501024ae5`
>
> a2 commit: `0e6a377f020d3e446ea9a8d7b045516d0bd9515b`
>
> b1 commit: `147247ffadcb37c8a7ab83983bf884bd858ac51b`
>
> b2 commit: `08184b0a769d904b895636455688ada9e3c3e9e3`
>
> Accepted a2/serial tree: `d2d02025834a4667d3e21171b71bf0d1b8d654fe`
>
> Final verifier tree: `2d9a22d0e9fc5158898fd3c2a304582c93ec8a94`
>
> Scope: non-connected package server primitive and verifier evidence only; no
> live escrow/XPC/helper linkage, fixed client, App/Machine composition, install,
> privilege, model/auth, readiness claim or authoritative full verifier

## 1. Outcome

L3c3c-ii-b2b-i is complete. Lifecycle now owns a sealed, one-shot
`LifecycleMachineRetirementReservationTransfer` and the claim/release response
commit linearization. The new non-product
`StornautInvestigationMachineClaimServer` target translates the strict STNC
claim/release bytes into that Lifecycle state, executes only injected
schedule/cancel/terminal effects, and retains no raw token or independently
mintable reservation seed.

The accepted dependency direction is:

```text
StornautInvestigationMachineClaimServer
    +-> StornautInvestigationHandoffContract
    `-> StornautLifecycle -> CLifecycleSupport
```

No product target consumes the new static product.
`StornautInvestigationTests` directly depends on the server target/module only.
No App, helper, Machine host, DriverSupport or native driver links it yet. This
checkpoint therefore does not make the helper speak the new wire and does not
advance product availability.

## 2. Scope, Cost and Artifact Identity

The mandatory split produced four ordered commits. “Exact paths” below means
exact non-document paths; a1 and b1 also update the governing preflight.

| Checkpoint | Exact non-document scope | Changed lines | Ceiling | Commit/tree |
| --- | --- | ---: | ---: | --- |
| a1 | four Lifecycle source/test paths | 614 | 900 | `e90a139` / `cc042d7…` |
| a2 | `Package.swift`, two server sources, two Investigation tests | 2,414 | 2,650 | `0e6a377` / `d2d0202…` |
| b1 | `scripts/verify-investigation-boundaries` | 616 | 650 | `147247f` / `617b736…` |
| b2 | `scripts/verify-contract` | 397 | 400 | `08184b0` / `2d9a22d…` |

The commits are a strict ancestry chain, contain no Coding Agent co-author
trailer, are pushed to `origin/main`, and the completion audit observed
`HEAD == origin/main == 08184b0…` with a clean worktree.

The a2 serial validation commit `21aeb8e462c76e51752b8051197c576781374128`
has tree `d2d0202…`, exactly equal to pushed a2. The final b1 validation commit
`5ecd6ef7d577d3707bc1df85b6c4f12af401480c` has tree `617b736…`, exactly
equal to pushed b1. The final b2 validation commit
`10f902652f8b8a58e46e7281ffde74848ace000b` has tree `2d9a22d…`, exactly
equal to pushed b2.

## 3. Prompt-to-Artifact Completion Checklist

No row below relies on a passing serial alone. Shared codec, state-owner, server
entry, source graph and mutation evidence are listed separately.

| Requirement | Direct evidence | Result |
| --- | --- | --- |
| exact request -> semantic claim -> evidence bytes | `claimAndReleaseTranslateToExactHandleFreeBytes`; exact golden claim/evidence/release contract tests | satisfied |
| request/helper digest recomputation | `helperAndRequestDigestsAreIndependentlyRecomputed`; adapter hashes decoded request and helper identity | satisfied |
| no handle/token or reversible projection | evidence/release golden tests and byte negatives; server response byte negatives | satisfied |
| exact release echo | release/released golden bytes and adapter equality test cover digest, challenge, helper, epoch and deadline | satisfied |
| strict domain/version/tag/order/length/trailing/legacy rejection | shared `HandoffBinaryTranscript` structural-drift suite owns domain/order/unknown/trailing; claim contract owns nested/golden shape; server tests prove exact validators run before state use | satisfied |
| malformed before consumption; decoded binding mismatch through state owner | malformed claim preserves awaiting state; every decoded handle axis reaches `rejectBinding`; malformed release reason and terminal state both map to binding mismatch | satisfied |
| exact binding rejection cleanup | direct pending/armed/foreign/terminal Lifecycle test plus late-arm cancel | satisfied |
| callback ticket-bound clock rejection | direct current/foreign/replaced ticket test; executor captures and passes complete ticket | satisfied |
| operation-bound clock rejection | claim/release/reply clock-failure test and direct exact/foreign/empty/idempotent state test | satisfied |
| sealed typed provenance | one-shot transfer/legacy-claim race; exact owner/L1 fields; no transfer constructor in server | satisfied |
| owner/residue/time negatives | both non-owned values, every nonzero count, foreign investigation/ASID/UID, future/stale, exact 60-second and fractional-floor cases | satisfied |
| duplicate/replay and binding drift | concurrent/sequential claim replay, every release axis, foreign epoch/helper/digest/deadline | satisfied |
| release challenge freshness | original claim challenge, connection epoch and reservation UUID reach Lifecycle and fail terminally; self-challenge API is structurally forbidden | satisfied |
| response commit two-order linearization | direct claim/release callback-first and commit-first tests; release-before-commit and reply-before-commit concurrency tests | satisfied |
| synchronous external reentry | scheduler, cancellation-handle and terminal-handler reentry tests complete without actor/lock deadlock | satisfied |
| slot lifecycle | callback-before-handle, scheduler failure, normal due, clock failure, stale replacement and exact pending-slot accounting | satisfied |
| arm/install race | production checker requires `armSucceeded -> apply -> slot.install`; executable reverse-order mutation is rejected | satisfied |
| narrow lock only | parser enumerates exactly four immutable evidence lock closures; widened-lock mutation is rejected | satisfied |
| authority-free package surface | package-only APIs, exact imports, no XPC/listener/filesystem/process/Security/Policy/Cleanup/Executor authority | satisfied |
| exact package graph/no product consumer | static product with two exact dependencies/sources; test-only consumer; Lifecycle reverse dependency rejected | satisfied |
| parser/verifier anti-spoofing | comments/strings stripped; conditional compilation, raw strings and regex forbidden; fourteen source and four package mutations match exact diagnostics | satisfied |
| exact scope/budgets | executable b1 baseline gate; b2 exact-commit path/line gate and normalized whole-file self-seal | satisfied |
| one serial and independent review | exact a2 tree serial plus a1/a2/b1/b2 independent and post-fix reviews recorded below | satisfied |

## 4. Validation and Review

| Gate | Result |
| --- | --- |
| a1 focused response-commit/transfer | 36/36 passed |
| a1 Lifecycle affected | 175 tests in 17 suites passed |
| a2 server suite | 23/23 passed |
| a2 combined focused | 59 tests in 3 suites passed |
| a2 Investigation affected | 306 tests in 25 suites passed |
| final-main focused coverage | 196 functions / 2,333 lines / 640 regions; 97.45% / 96.49% / 90.47% |
| sole staged-only serial | 1,194 tests in 58 suites passed |
| serial test / stage time | 83.258 / 124.575 seconds |
| serial identity | validation `21aeb8e…`, tree `d2d0202…`, exactly pushed a2 |
| b1 canonical source/package modes | exit 0 |
| b1 full Investigation boundary | exit 0, including Debug/Release authority-closed driver gates |
| b1 raw-string negative | exact `gained raw literal or regex` rejection |
| b2 `scripts/verify-contract` | exit 0 in clean `/Users` worktree; source/package/snapshot/CLI contracts passed |
| independent final reviews | no unresolved P0-P2 |

The review loop did not treat earlier green trees as completion evidence. The
first actor/raw-seed tree was rejected after two P1s and one P2. The corrected
tree then fixed malformed-release reason divergence, a test-only reentry data
race, arm/install ordering, inactive conditional/raw-literal parser spoofing,
dirty-scope acceptance and verifier self-sealing. Each changed tree received
focused or exact-gate revalidation and post-fix review.

The serial is intentionally not repeated after b1/b2: those checkpoints change
only verifier scripts, the preflight assigns the parent’s sole serial to a2, and
b1/b2 instead execute the canonical source/package/boundary and mutation
contracts. This preserves the approved cost funnel. No authoritative headless or
full verifier was run.

## 5. Safety Boundary and Next Gate

This checkpoint remains non-connected and non-admitting. It did not change the
live helper, old Lifecycle concrete claim client, Machine production factory,
Xcode graph, App composition or installed topology. It did not install or launch
an App/helper, use privilege, call a model/auth flow, accept ADR 0018, claim
machine readiness or consume Task 39’s remaining authoritative full verifier.

`ii-b2b-ii` is next. It must quarantine the legacy broad Lifecycle concrete
client and make Machine production explicitly unavailable before the helper wire
is changed. `ii-b2b-iii` later links and migrates the live helper server. The
fixed retained NSXPC client remains exclusively owned by ii-b4.

ADR 0018 remains Proposed. Task 39 remains incomplete. Production Deep Dive
remains `.implementationUnavailable`; only L3c4 owns machine readiness and the
remaining full verifier, and only Task 44 may admit normal-product Deep Dive.
