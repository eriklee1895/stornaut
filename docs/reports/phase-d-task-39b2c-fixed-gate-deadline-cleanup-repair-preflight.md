# Phase D Task 39B2c Fixed-Gate Deadline Cleanup Repair Preflight

> Status: complete / non-admitting
>
> Date: 2026-08-30
>
> Implementation: `bc42fbc58ea1c6eed52ff646fa2f6043e2af4316`
>
> Tree: `29eb2d048142fb873f0306acc4bfebbbb250b03d`
>
> Completion audit:
> [Fixed-Gate Deadline Cleanup Repair Completion Audit](phase-d-task-39b2c-fixed-gate-deadline-cleanup-repair-review.md)
>
> Baseline: `c144c1e` (`fix(investigation): preserve shared machine deadline`)
>
> Scope: local source, tests and structural verifiers only. This checkpoint does
> not authorize root/sudo, an installed App/helper/driver launch, product XPC,
> model/auth/network access, or `scripts/verify --full`.

## 1. Defect and Decision

Two clean staged-only Investigation serial runs reproduced the same physical
cleanup failure under load, once for `malformedPrepared` and once for
`overflowPrepared`. The fixed-gate lifecycle returned
`spawnOrTransferUncertain` after failing to prove the direct gate was reaped,
although the unchanged isolated seven-scenario physical fixture passed and no
post-run process, attempt-directory or fixture-directory residue remained.

The root cause is a second, unintended time boundary in
`drainRecoveryGroup`: at most 512 process-group inventory observations are made.
The Darwin inventory operation already checks the immutable absolute cleanup
deadline and performs a deadline-bounded pause while the group is non-empty.
Consequently, the fixed count limits a loaded run to roughly 5.12 seconds even
when the authoritative absolute deadline has substantially more time left.

The repair removes only that redundant observation-count limit. The loop keeps
using the same immutable absolute deadline for every inventory operation, so
deadline expiry and every observation failure remain fail-closed. No identity,
process-group, stable-empty, exact-reap or residue requirement is weakened.

## 2. Frozen Scope and Budget

The implementation may change exactly these five non-document paths:

1. `Sources/StornautInvestigationMachineLaunchSupport/InvestigationFixedGateDarwinLifecycle.swift`;
2. `Tests/StornautInvestigationTests/InvestigationFixedGateDarwinLifecycleTests.swift`;
3. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
4. `scripts/verify-investigation-boundaries`; and
5. `scripts/verify-contract`.

The maximum changed-line budget is 700 non-document lines. No package graph,
schema, protocol field, public API, entitlement or authority may be added. The
Darwin syscall adapter and the physical fixture stay unchanged. Historical
checkpoint commits, trees and replay constants stay immutable.

## 3. Tests First

The deterministic RED must show that a valid admitted process group which
becomes gate-only after more than 512 observations is rejected by the old
implementation before exact reap. The GREEN test must require:

- more than 512 inventory observations;
- the same absolute deadline on every observation;
- `SIGTERM`, `SIGCONT`, then `SIGKILL` for the admitted group;
- exactly one direct-gate reap; and
- a final empty process-group observation.

A second test must inject deadline expiry at inventory and prove that the result
remains `spawnOrTransferUncertain`, with no exact reap and no empty-group proof.

The recorded clean-snapshot RED returned `spawnOrTransferUncertain`, performed
zero reap operations and retained a non-empty final inventory.

## 4. Verification

Run in this order:

1. focused lifecycle tests;
2. dedicated source and mutation contracts;
3. exact five-path staged scope gate;
4. bare Investigation boundary verifier;
5. one clean staged-only serialized `StornautInvestigationTests` regression;
6. targeted Release build for `StornautInvestigationMachineLaunchSupport`;
7. independent post-fix review; and
8. bare `scripts/verify-contract`.

The existing physical seven-scenario test remains strict: an expected malformed
or overflow result cannot be changed to accept `spawnUncertain`, and gate/process
group residue assertions cannot be removed. A full verifier remains reserved for
Task 39 L3c4.

## 5. Non-Claims

This repair does not execute the privileged machine campaign, call Codex App
Server, claim machine readiness, accept ADR 0018, or enable production Deep
Dive. After completion, Task 39 returns to the interactive-native identity
binding prerequisite before ii-c, L3c3d and L3c4.
