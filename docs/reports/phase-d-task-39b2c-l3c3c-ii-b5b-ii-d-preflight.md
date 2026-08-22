# Phase D Task 39B2c L3c3c-ii-b5b-ii-d Preflight

> Status: approved for tests-first implementation / non-admitting
> Date: 2026-08-23
> Frozen source baseline: `efe079f95a9f15a360d280ea656bf9548bfaa3c3`
> Admission: none
> Next checkpoint: ii-b5b-iii production/artifact composition

## 1. Decision

ii-b5b-ii-d remains one bounded checkpoint, but the concrete Darwin retirement
owner is placed in a new DriverSupport source file instead of enlarging the
already 1,208-line session implementation. This checkpoint closes only exact
owned-PGID retirement and the spawned-only fail-closed fallback required by
ii-b5b-ii-c. It does not compose the native production entry or execute an
installed/root process.

The generic `ProcessTreeTerminator` is not reused. Its public API, SIGINT stage,
per-member `EPERM` fallback and lack of leader reap ownership do not match the
strict parent-owned epoch contract. The new implementation remains module-
internal and receives no caller-selected PID, PGID, signal, deadline or policy.

The existing retirement protocol is narrowed before implementation:
`retireSpawnedProcess` returns no proof because a child whose PGID was not
independently validated cannot prove descendant absence. Only
`retireOwnedProcessGroup` may mint
`InvestigationMachineSingleEpochRetirementProof`.

## 2. Frozen Scope and Cost

The exact non-document path set is eight paths with a hard ceiling of 3,200
changed lines:

1. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinEpochSession.swift`;
2. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinEpochRetirement.swift`;
3. `Tests/StornautInvestigationTests/InvestigationMachineDarwinEpochSessionTests.swift`;
4. `Tests/StornautInvestigationTests/InvestigationMachineDarwinEpochRetirementTests.swift`;
5. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
6. `scripts/verify-investigation-boundaries`;
7. `scripts/verify-app-release-boundaries`; and
8. `scripts/verify-contract`.

The split keeps retirement state/syscalls and their focused matrix separate from
the transport actor. `Package.swift` needs no change because both new files are
inside existing source/test targets. A seventh production/test/script path, a
ninth total non-document path, or an approach to 3,200 changed lines forces a
new pre-implementation split.

## 3. Exact Owned-PGID Contract

The production owner uses fixed constants: 4,096 maximum inventory entries, a
five-second total retirement window, a one-second TERM window and bounded short
polling. It first closes every descriptor exactly once. A close failure is
retained as uncertainty while process retirement continues; an attempted close
removes that descriptor from further ownership even when `close(2)` reports an
error, because retrying a numeric descriptor after an uncertain close can affect
a reused file descriptor.

Group-wide authority exists only for an opaque owned epoch satisfying all of:

- leader PID and PGID are greater than one;
- PGID equals leader PID;
- PGID differs from the current driver's process group; and
- every inventory sample is complete, bounded, aligned to `pid_t`, positive and
  duplicate-free.

The owner uses `proc_listpids(PROC_PGRP_ONLY)` to obtain the exact group,
`waitid(P_PID, ..., WEXITED | WNOHANG | WNOWAIT)` to prove the leader remains a
waitable child, `kill(-pgid, SIGTERM)` followed when necessary by one exact
`kill(-pgid, SIGKILL)`, and nonblocking `waitpid(pid, ..., WNOHANG)` only after
the leader is waitable and all other group members are absent. After reap it
observes the same numeric PGID once more; non-empty state is treated as PGID
reuse/uncertainty and is never signalled. `ESRCH` from a signal is not terminal
proof and cannot bypass inventory, WNOWAIT, reap or the post-reap empty check.

For an untrusted spawned epoch, the owner closes known descriptors, proves only
the exact PID is its waitable child, and if needed sends `SIGKILL` only to that
positive PID before bounded nonblocking reap. It never inventories or signals a
negative PGID and never returns a retirement proof. Factory startup therefore
always returns `terminalUncertain` after this fallback, even when direct-child
cleanup succeeds.

All blocking Darwin work runs on a private queue. Cancellation may request
cleanup but cannot resume the async caller until the worker has finished; this
prevents stale PID/FD operations after numeric identity reuse. Any timeout,
inventory ambiguity, signal failure, wait ambiguity, reap ambiguity, descriptor
failure or post-reap reuse withholds proof.

## 4. Tests-First Matrix

RED tests must cover:

- natural leader exit: no signal, WNOWAIT, descendants empty, reap last,
  post-reap empty and one proof;
- TERM drain and TERM-ignoring descendant escalation to exact negative-PGID
  SIGKILL;
- a waitable leader with a live descendant is never reaped early;
- cleanup uses its own fixed deadline even if the business epoch deadline has
  expired;
- inventory growth and failures: saturated 4,096 entries, byte misalignment,
  duplicates, invalid PIDs and syscall failure;
- `waitid` wrong PID/`ECHILD`/other errors and `waitpid` zero/wrong PID/
  `ECHILD`/other errors, with only `EINTR` retried;
- signal `ESRCH`, `EPERM` and other errors never become proof by themselves;
- post-reap same-number PGID reuse returns uncertainty without another signal;
- descriptor-close failure continues process cleanup but withholds proof and is
  never retried;
- cancellation waits for the retirement worker and cannot double-resume;
- duplicate/concurrent retirement stays one-shot;
- untrusted spawned cleanup uses positive PID only and always returns startup
  uncertainty; and
- two bounded same-UID fixtures cover natural exit and a TERM-ignoring
  descendant, including WNOWAIT, exact group drain, reap-last and zero residue.

Verifier mutations must reject a spawned-only proof, removed PGID/current-group
guard, removed WNOWAIT, removed TERM/KILL, positive group signal, early or
blocking reap, inventory ambiguity accepted as empty, `ESRCH` accepted as proof,
missing post-reap observation, ignored descriptor error, early cancellation
return, caller-selectable authority, vacuous physical tests and path/budget/mode
drift. Syscall allowlists remain exact to this one retirement source.

## 5. Validation and Non-Claims

Validation is structural -> retirement/session focused tests -> affected
Investigation tests -> `scripts/verify-contract` ->
`scripts/verify-investigation-boundaries` -> applicable Xcode Debug/Release
artifact gate -> one staged-only `swift test --no-parallel` -> independent
implementation/verifier review. `scripts/verify --full` is not run; L3c4 alone
owns it.

This checkpoint performs no sudo/root operation, install/uninstall, real App or
XPC launch, Codex authentication, model call, network access, Trash, Executor or
Registered Action. Same-UID fixtures prove only the Darwin retirement algorithm,
not root-to-UID behavior, audit-session containment, installed topology or
machine readiness. ADR 0018 remains Proposed, Task 39 remains incomplete and
production Deep Dive remains `.implementationUnavailable`.
