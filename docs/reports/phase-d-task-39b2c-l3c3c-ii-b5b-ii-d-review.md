# Phase D Task 39B2c L3c3c-ii-b5b-ii-d Review

> Status: complete / non-admitting
> Date: 2026-08-23
> Implementation commit: `d89d201448a99281a554d9b3fca00512b4f0c0be`
> Parent: `47f2715f9dc1a835aa769290b1b581b38066f04c`
> Tree: `6c82ece7639e4335dbbb40e25090abc8fc264913`
> Next frontier: ii-b5b-iii production/artifact composition

## 1. Result

ii-b5b-ii-d completes the exact owned-PGID retirement owner required by the
fixed Darwin single-epoch runtime. The owner closes transferred descriptors
once, validates the closed PID/PGID authority, obtains bounded group inventory,
preserves the leader as a waitable child, drains descendants with TERM and one
exact group KILL fallback, reaps the leader last and checks the same numeric
PGID again before minting one opaque retirement proof.

The implementation changed exactly eight non-document paths and 2,253 lines
against the frozen parent, within the reviewed eight-path / 3,200-line ceiling.
It added no package dependency, public API, product availability, report or
readiness surface.

## 2. Implemented Contract

- Only an opaque owned epoch with positive leader PID/PGID, `PID == PGID` and a
  group different from the current driver group can receive group-wide signal
  authority. An unverified spawned process may receive only positive-PID
  `SIGKILL`, returns no proof and always leaves startup terminal state
  uncertain.
- Every transferred descriptor is attempted exactly once. A close error is
  retained as uncertainty while process retirement continues; the numeric
  descriptor is never retried after an uncertain close.
- Group membership comes only from a bounded 4,096-entry
  `proc_listpids(PROC_PGRP_ONLY)` sample. Saturation, misalignment, duplicate or
  nonpositive PIDs and syscall failure all fail closed.
- `waitid(P_PID, ..., WEXITED | WNOHANG | WNOWAIT)` is the only leader
  waitability proof. The leader is not reaped while any descendant remains.
- The retirement window is freshly fixed at five seconds with a one-second
  TERM interval. Remaining members receive exactly `kill(-pgid, SIGTERM)` and,
  if necessary, one `kill(-pgid, SIGKILL)`. `ESRCH` is not treated as proof.
- The leader is reaped only through nonblocking `waitpid(pid, ..., WNOHANG)`.
  A final inventory of the same numeric PGID must be empty after reap; any
  apparent reuse withholds proof and is never signalled.
- Deadline checks surround inventory/wait observations and every `EINTR` retry.
  Cancellation records the request but resumes the async caller only after the
  private blocking worker has completed, preventing stale PID or descriptor
  operations after numeric reuse.
- The owner is one-shot across concurrent and repeated calls. The sole proof
  construction site exists only after the complete owned-group success chain.

Accepted canonical source SHA-256 values include:

- retirement owner: `574fe7df157c04b573602a222df40fe08bc4759d41fc88b56e8695b636ce38a8`;
- Darwin session: `22b8ed4e85519694e0761ab0fcffef22d692fe1c86e39023d3fba2173e4ccdf5`;
- retirement tests: `355932bd5dde0766acc9ec169e902efbe1bf9adaf256d10ddc2751e74c839775`;
- session tests: `c5961a76b2f9f203e1b62454a78ad0fa43f4e9c26c25e64174671ab8d8ee2042`.

## 3. Tests-First and Validation

- The final focused selection passed 40 tests in three suites: 16 retirement
  tests, 23 fixed-session tests and the package-boundary test.
- The affected `StornautInvestigationTests` selection passed 527 tests in 40
  suites with zero failures.
- Both same-UID physical fixtures passed: natural waitable exit and a
  TERM-ignoring descendant requiring exact negative-PGID KILL. They verify
  final leader reap and zero process-group residue.
- `scripts/verify-contract` passed, including ii-d semantic, binary-scanner and
  scope/mode mutations. Historical ii-c scope replay now consumes its immutable
  completed commit `d935422` instead of allowing later shared-verifier growth to
  corrupt the old budget calculation.
- `scripts/verify-investigation-boundaries` passed, including the single-source
  syscall allowlist and exact SwiftPM Debug/Release projections.
- `scripts/verify-app-release-boundaries` passed, including ordinary and
  diagnostic App boundaries plus the separate Xcode Debug/Release Machine
  Driver projections.
- The one final clean staged-snapshot serial regression passed 1,409 tests in
  73 suites with zero failures. The diagnostic step took 149.196 seconds.
- `git diff --cached --check` and the exact eight-path, 2,253-line staged scope
  and file-mode gate passed.

`scripts/verify --full` was deliberately not run. This is a bounded,
non-admitting implementation checkpoint; L3c4 alone owns Task 39's final
authoritative full verifier.

## 4. Review Closure

Tests-first review found false-green risks in reap-relative inventory
assertions, permissive mock-script exhaustion and physical-fixture cleanup.
They were repaired before the final test funnel. A later implementation review
found that repeated `EINTR` could bypass the fixed deadline; every retry now
rechecks the total deadline, with explicit boundary tests.

Verifier iteration found that older ii-c scope replay compared its completed
checkpoint against current shared verifier files. The replay now reconstructs
and validates the immutable `d935422` completion snapshot without widening the
old budget. SwiftPM and Xcode binary projections are sealed independently
because their optimization/link graphs are intentionally different.

Final implementation, verifier and cross-group reviews report no unresolved
P0-P2 findings. The generated external review artifacts are
`/tmp/stornaut_iid_review.9crrIt/report.html` and `report.md`.

## 5. Prompt-to-Artifact Completion Checklist

| Requirement | Concrete evidence | Result |
| --- | --- | --- |
| Close every transferred descriptor once | owner state machine, descriptor-error test and mutation gate | complete |
| Validate exact PID/PGID authority | closed owned-epoch guards and invalid-authority matrix | complete |
| Bounded complete group inventory | 4,096-entry parser and malformed/saturated tests | complete |
| Preserve waitable leader | exact WNOWAIT contract and mutation | complete |
| TERM then exact-group KILL | fixed signal sequence and physical ignoring-descendant fixture | complete |
| Reap only after descendants drain | scripted ordering assertions and nonblocking reap gate | complete |
| Reject post-reap PGID reuse | final inventory and no-resignal test | complete |
| Bounded deadline and cancellation join | post-syscall/EINTR checks and blocked-worker cancellation test | complete |
| Spawned fallback cannot mint proof | Void protocol, positive-PID-only cleanup and terminal-uncertain routing | complete |
| No public or cleanup-authority expansion | source allowlist and Debug/Release final-artifact gates | complete |
| Exact scope and file modes | 8 paths / 2,253 lines, staged scope/mode gate | complete |
| Regression and independent review | 40 focused, 527 affected, 1,409 serial, zero unresolved P0-P2 | complete |

## 6. Non-Claims and Next Step

This checkpoint did not run as root, install or launch the signed product
App/helper, invoke XPC, read Codex authentication, access the network or call a
model. Its physical fixtures prove only same-UID Darwin retirement behavior. It
does not prove root-to-UID transition, installed topology or machine readiness.

ADR 0018 remains Proposed, Task 39 remains incomplete, production Deep Dive
remains `.implementationUnavailable`, and the final full verifier remains
unconsumed. The next checkpoint is ii-b5b-iii production/artifact composition,
followed by ii-c0, the one no-model privileged ii-c gate, L3c3d authenticated
success and L3c4 final admission.
