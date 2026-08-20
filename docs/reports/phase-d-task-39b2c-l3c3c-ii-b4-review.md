# Phase D Task 39B2c-L3c3c-ii-b4 Fixed Helper-Claim Client Review

> Status: Complete; fixed DriverSupport claim/release client, strict helper
> identity and deadline joins, permanent one-shot XPC epoch, structural/
> mutation/final-Mach-O gates and independent post-fix reviews passed;
> non-admitting
>
> Date: 2026-08-21
>
> Implementation commit: `8ba49c1a02acab556df474d334cb2f9c01eb639f`
>
> Parent: `6367c3b4a0b98eeb2877706ef016612cfd59e6a1`
>
> Validated implementation tree: `b2e1f94ecb19bf3bfa3e679376f536f428c9917a`
>
> Staged validation commit: `e2cca91c1a8f163f43c553e0fbd12b16c44260be`
>
> Scope: seven non-document source/test/script paths plus the approved
> preflight correction; no App/helper launch, real XPC, install, sudo/root/
> launchctl, model/auth/network use, readiness claim or authoritative full
> verifier

## 1. Outcome

L3c3c-ii-b4 is complete. `StornautInvestigationMachineDriverSupport` now owns
the only concrete fixed machine-claim client. The client accepts only the
already-validated retirement handle, App identity, shared outer-epoch deadline
and optional previous-helper identity. Service selection, helper path/signing,
connection epoch, challenges and transport remain compile-time or internally
generated choices; callers gain no endpoint, path, authorization or retry
authority.

The actor implements a one-way `idle -> claimed -> consumed` state machine. It
opens one fixed privileged XPC connection, dispatches one claim, retains that
same connection across ii-b5's installed-L2 barrier, dispatches one release and
invalidates exactly once after the reply and bounded original-helper absence
proof. Repeated or concurrent operations have one winner, every failure makes
the epoch terminal, and a later epoch must use a new client plus a different
complete helper identity.

Claim admission joins the fixed helper's strict static identity, XPC PID/EUID/
ASID, all eight audit-token words and Security-derived dynamic code identity.
Release joins the same connection epoch, request digest, helper identity, fresh
challenge, reply echo and shared deadline. Strict local validation and strict
server negative replies preserve their typed reasons, including
`invalidDeadline`, `signingIdentityMismatch`, `protocolViolation`, `invalidPeer`
and `expired`. Only pre-dispatch transport failure or cancellation maps to
`unavailable`; once dispatch may have crossed the external boundary, missing or
malformed reply, interruption, invalidation, cancellation, helper-exit ambiguity
or deadline ambiguity maps to `outcomeUnknown`. No typed rejection or ambiguity
is downgraded to success.

## 2. Scope, Cost and Artifact Identity

The implementation changed exactly seven non-document paths and 3,153
added-or-deleted lines: 3,088 additions and 65 deletions. That stayed below the
re-audited 10-path / 3,200-line ceiling. The whole commit changed eight paths
and 3,164 lines (3,095 additions, 69 deletions) because it also recorded the
approved preflight correction. The seven non-document paths are:

1. `Package.swift`;
2. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineClaimClient.swift`;
3. `Tests/StornautInvestigationTests/InvestigationMachineClaimClientTests.swift`;
4. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
5. `scripts/verify-contract`;
6. `scripts/verify-investigation-boundaries`; and
7. `scripts/verify-app-release-boundaries`.

Independent pre-implementation review expanded the concurrency, ambiguity,
identity and deadline matrix and triggered the preflight's verifier/cost
re-audit before the accepted implementation snapshot. No Xcode project, helper,
server, Lifecycle, Machine-host or shared-wire implementation path changed.

The implementation and staged-validation commits share parent
`6367c3b4a0b98eeb2877706ef016612cfd59e6a1` and exact tree
`b2e1f94ecb19bf3bfa3e679376f536f428c9917a`. The implementation commit is
pushed to `origin/main`. Verifier source identity at that tree is:

- `scripts/verify-contract`: `2348f6fdfe7420731cb9a17fa614b045a77b5e6d5d5b4f64d93048c5b4da3820`;
- `scripts/verify-investigation-boundaries`: `ecd261fcaa9c9231603756d47752b9d3a7358a49937e257253d7c3dec4429d8a`; and
- `scripts/verify-app-release-boundaries`: `42ee86284c289efce8025ae366336046a47d689838c93ac577b0bfc1ed68f92c`.

## 3. Prompt-to-Artifact Completion Checklist

| Requirement | Direct evidence | Result |
| --- | --- | --- |
| fixed service/path/signing | exact constants and no caller/environment-selected transport input | satisfied |
| one claim / one retained connection / one release | actor state, permanent connection epoch and dispatch-count tests | satisfied |
| opaque ii-b5 seam | package-scoped claim evidence and internal retained session; no connection or endpoint escape | satisfied |
| exact request and helper joins | request digest, connection epoch, challenges and complete helper identity checked | satisfied |
| static/dynamic attestation | fixed-path static code, audit-token dynamic code and XPC PID/EUID/ASID join | satisfied |
| strict clocks and helper absence | post-dispatch clocks, bounded polling and exact original-helper absence before deadline | satisfied |
| failure classification | strict validation/server reasons preserved; only pre-dispatch transport/cancel is `unavailable`; post-dispatch ambiguity is `outcomeUnknown` | satisfied |
| no replay or retry | concurrent claim/release matrix, one-shot cancellation and terminal epoch controls | satisfied |
| fresh next epoch | reused previous-helper identity rejected; only a different complete identity admitted | satisfied |
| package/API closure | opaque `Sendable`, non-`Codable` surface and exact DriverSupport dependency | satisfied |
| artifact attribution | shared wire/service/selectors distinguished from client implementation symbols in every image | satisfied |
| no premature admission | no live topology, L2, report, receipt, readiness or full-verifier claim | satisfied |

## 4. Validation Evidence

| Gate | Result |
| --- | --- |
| focused claim-client matrix | 11 test functions / 47 cases passed |
| affected regression | 102 tests in 5 suites passed |
| `scripts/verify-contract` | exit 0; real staged index, comment/source, mutation, scope and seal controls passed |
| full `scripts/verify-investigation-boundaries` | exit 0; package/source/dependency/authority and Debug/Release projections passed |
| full `scripts/verify-app-release-boundaries` | exit 0; native final-Mach-O positive/negative and closed-image matrices passed |
| SwiftPM artifacts | Debug and Release exact projections passed |
| native Xcode artifacts | Debug and Release exact projections passed; Release final-Mach-O coverage included |
| App images and target tests | ordinary/diagnostic closed images and App target tests passed |
| sole clean staged-only serial | 1,269 tests in 61 suites passed in 84.694 seconds; five maximum benchmarks skipped |
| serial identity | staged validation `e2cca91...` and implementation `8ba49c1...` have identical tree `b2e1f94e...` |
| independent review | final runtime, tests, verifier and fresh cross-group reviews report no unresolved P0-P2 |

The clean staged-only serial ran once and passed without retry or restart. It
was not followed by a second serial. `scripts/verify --full` was not run.

## 5. Independent Review and Repairs

Runtime review closed stale-clock and race windows by sampling clocks after
dispatch, enforcing strict absence/deadline bounds, making the XPC connection
epoch permanently one-shot and classifying cancellation from whether dispatch
could have crossed the boundary. Claim and release can no longer publish a
second outcome, retry a connection or leave a reusable epoch after failure.

Test review removed fixture self-oracles and expanded the matrix across
concurrency, complete identity drift, deadline edges, cancellation phases and
typed XPC reasons. The success fixture now proves sleep-before-absence ordering
instead of manufacturing absence independently of the client's clock.

Verifier review replaced synthetic-only assumptions with the real staged index,
comment-aware source checks, executable mutation controls and exact Mach-O
positive/negative seals. It added native Release final-Mach-O coverage and
separated shared wire/service/selector attribution from ownership of the client
implementation. Final runtime, test, verifier and fresh cross-group reviews
found no unresolved P0-P2.

## 6. Non-Admission and Next Gate

ii-b4 is complete but non-admitting. This checkpoint did not launch the App or
helper, invoke real XPC, install an artifact, use `sudo` or root, mutate
`launchctl`, run L2, call a model, read auth, access public network, create a
machine report/receipt or claim readiness. ADR 0018 remains Proposed, Task 39
remains incomplete and production Deep Dive remains
`.implementationUnavailable`.

ii-b5 fixed single-epoch composition is the current implementation frontier. It
alone may join the completed App handoff, fixed claim client, installed-L2
barrier and exact epoch retirement. ii-c0 still requires its own fresh
privilege-launcher preflight; ii-c alone may accept ADR 0018. L3c4 alone owns
machine readiness and Task 39's remaining authoritative full verifier.
