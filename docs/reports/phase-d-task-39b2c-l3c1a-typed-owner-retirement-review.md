# Phase D Task 39B2c-L3c1a Typed Owner Retirement Review

> Status: Complete; non-admitting typed-retirement prerequisite
>
> Date: 2026-08-18
>
> Baseline: `dcc034d031886b337d9041b60036de7b1e5e75d2`
>
> Scope: contained owner-retirement truth, strict worker/broker/helper wire and
> Investigation transport admission; no helper escrow/root claim, live
> install/uninstall, model, report, readiness or full verifier

## 1. Decision

L3c1a is complete. `CodexContainedInteractiveSession` now mints a non-`Codable`
owner observation only after the exact owned resource class has retired:

- `.none` means planning never began and no workspace/process was owned;
- `.preparedWorkspace` means an in-flight plan was joined and its workspace was
  confirmed absent before retirement completed; and
- `.owned` means the process group was terminated, its leader was reaped, exact
  PGID membership was observed empty, stderr stayed bounded and the workspace
  was removed.

The lifecycle worker wire carries the same closed facts under response protocol
v3. Its strict decoder accepts only the three internally consistent combinations.
The broker shares one retirement task across retire/invalidation races. The root
helper wraps the exact worker wire observation instead of deriving it from
`drained` or L1 residue. That wire remains untrusted: Investigation requires an
`.owned` completion signal but deliberately does not copy it into package-only
retirement evidence. The existing non-`Codable` evidence continues to contain
only the independently bound exact helper peer and fresh exact-zero same-retire
L1 observation. L3c1b alone will create trusted owner authority after root-side
revalidation.

## 2. Tests First and Review Fixes

Tests first failed against the former Boolean retirement API. Focused coverage
now includes owned/no-owned/prepared-workspace truth, repeated/concurrent
retirement, failed retirement, strict unknown/missing/ambiguous wire decoding,
helper transport binding and L1/L2 collector compatibility.

Independent review found two P1 and one P2 issue:

1. a suspended plan builder could prematurely mint `.noOwnedResources`;
2. leader reap did not independently prove the complete PGID empty; and
3. the worker reply envelope still used synthesized permissive decoding.

A final boundary review also found that copying the lower-privilege worker DTO
into package evidence would prematurely promote untrusted wire data. The copy
was removed, and the structural gate now rejects any future worker-owner field
inside `InvestigationLifecycleRetirementEvidence`.

The post-fix implementation joins the in-flight plan and fail-closes workspace
cleanup, performs bounded exact PGID membership observation after leader reap,
and uses a strict `LifecycleInteractiveWorkerReply` with exact keys, XOR payload
shape and a closed bounded reason key. Independent post-fix review found no
unresolved P0-P2.

## 3. Validation

| Gate | Result |
| --- | --- |
| owner/lifecycle/transport focused | 86/86 passed |
| exact Investigation boundaries | passed |
| local Markdown links | passed |
| targeted Debug diagnostic App build | passed |
| dedicated diagnostic App tests | 11/11 passed |
| clean staged-only serial regression | 1012 tests in 46 suites passed |
| serial test time | 115.256 seconds |
| independent post-fix review | no unresolved P0-P2 |

The accepted serial ran from exact staged commit
`dd15836c37478d7814179bb3cf6ffb05fc93e1a9` in a clean physical
`/Users/.../stornaut-validation.*/worktree`. Its final test time was
111.469 seconds.
The final checkpoint changes twelve non-document source/test/script paths with
1,083 added non-document lines, below both hard scope limits.

The code-review artifact is available locally at
`/tmp/stornaut_l3c1a_review.r9B0nd/report.html` and the equivalent Markdown at
`/tmp/stornaut_l3c1a_review.r9B0nd/report.md`.

## 4. Safety Boundary

This checkpoint does not make the wire observation trusted by itself. A worker
reply remains untrusted after strict decoding and cannot enter package evidence.
L3c1b must bind a future opaque claim to the exact App connection, helper,
retire operation and independent root observations. L3c1a adds no new XPC
listener role or root claim,
filesystem mailbox, process launch authority, Cleanup/Trash/Executor/Registered
Action surface or readiness promotion.

`~/.codex/config.toml` was not modified. Production Deep Dive remains
unavailable. `scripts/verify --full` was not run; L3c4 still owns the only
remaining Task 39 full verifier.

## 5. Next Gate

L3c1b must implement the helper-owned, challenge-bound one-shot escrow and a
root claim policy that survives App exit without persisting or exposing trusted
evidence. Production root claim remains closed until L3c2 supplies the exact
signed machine-driver identity.
