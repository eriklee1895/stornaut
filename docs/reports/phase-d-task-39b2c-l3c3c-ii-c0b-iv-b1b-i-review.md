# Phase D Task 39B2c L3c3c-ii-c0b-iv-b1b-i Completion Audit

> Status: complete / non-admitting
>
> Date: 2026-08-29
>
> Implementation: `41d34f26a32b9740124bd5fdf3857a4520ebdfea`
>
> Tree: `8ab58932cf67b5da81d0478968600181149c808f`
>
> Parent: `6386603f7b2ee3e38b96c02a1e37d9b85966a2cf`
>
> Next frontier: ii-c0b-iv-b1b-ii dedicated physical evidence and verifier
> closure

## 1. Result

ii-c0b-iv-b1b-i is complete and remains non-admitting. The checkpoint
implements the injected Darwin fixed-gate lifecycle and its narrow system-call
adapter without claiming physical outer-adapter execution.

The implementation is exactly three non-document paths. Its two production
sources contain 1,173 changed lines, below the frozen 1,180-line ceiling. The
test path adds 874 lines; the implementation commit contains 2,047 additions
in total.

## 2. Closed Behavior

- The injected lifecycle owns one immutable absolute deadline across sibling
  executable acquisition and revalidation, transport creation, spawn, prepared
  and terminal frame drain, wait/reap, signal forwarding, TTY restoration and
  exact process-group-empty observation.
- The Darwin adapter is the narrow syscall edge for executable identity and
  metadata checks, CLOEXEC descriptor plumbing, spawn file actions, bounded
  reads and EOF, wait classification, signal handling and exact process
  inventory/reap.
- Spawn or descriptor-transfer uncertainty remains fail closed and cannot be
  converted into settlement, unlink or ownership release.
- Read-stage gate death preserves the typed terminal classification; malformed
  terminal evidence is not hidden by a separately observed coordinator signal.
- Exact terminal admission requires the receipt and coordinator-observed
  forwarded-signal projections to agree, including the nil case.
- Deterministic tests cover the injected lifecycle without using a real
  production gate or substituting for iv-b1b-ii physical evidence.

## 3. Scope and Validation

The exact three non-document paths are:

1. `Sources/StornautInvestigationMachineLaunchSupport/DarwinInvestigationFixedGateHandoffSystem.swift`;
2. `Sources/StornautInvestigationMachineLaunchSupport/InvestigationFixedGateDarwinLifecycle.swift`; and
3. `Tests/StornautInvestigationTests/InvestigationFixedGateDarwinLifecycleTests.swift`.

| Evidence | Result |
| --- | --- |
| implementation commit/tree | `41d34f26a32b9740124bd5fdf3857a4520ebdfea` / `8ab58932cf67b5da81d0478968600181149c808f` |
| exact scope | 3/3 paths |
| production changed lines | 1,173 / 1,180 ceiling |
| clean affected suite | 806/806 tests, 56 suites, 47.391 seconds |
| clean staged-only Release target build | exit 0, 15.30 seconds |
| two final independent review groups | no unresolved P0-P2 |
| staged/worktree whitespace checks | exit 0 |

The affected suite and Release target build both used the exact staged tree
later committed as `41d34f2`. The final review groups independently covered
the lifecycle state machine and the Darwin/replay adapter.

Earlier review findings around pre-spawn close uncertainty, post-spawn cleanup
eligibility, ACL interpretation, read-stage termination, terminal signal
agreement and invalid first terminal observation were repaired before the final
snapshot. The final two reviews found no unresolved P0-P2.

## 4. Non-Claims and Next Step

This checkpoint does not provide the dedicated outer-adapter physical fixture,
physical-success evidence, verifier closure, aggregate c0b serial, real
App/helper/driver/gate launch, root/sudo, XPC, model/auth/network evidence,
machine readiness or ADR 0018 acceptance. It did not run the authoritative
full verifier. Task 39 remains incomplete and production Deep Dive remains
unavailable.

The next frontier is ii-c0b-iv-b1b-ii: the frozen exact five-path dedicated
non-product physical fixture, physical tests, target-boundary test and two
verifiers. The accepted c0b-iii PTY suite remains corroborating inner-gate
evidence and cannot substitute for this outer-adapter evidence.
