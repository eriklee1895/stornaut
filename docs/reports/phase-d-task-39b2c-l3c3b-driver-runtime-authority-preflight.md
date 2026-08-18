# Phase D Task 39B2c-L3c3b Driver Runtime Authority Preflight

> Status: Implemented and reviewed; L3c3b-0 and L3c3b-i complete, L3c3b-ii next
>
> Date: 2026-08-18
>
> Baseline: `5c6015276f575829ae5b266d833e1b13eaa7edcc`
>
> Scope: root-driver final-Mach-O authority closure before native packaging; no
> Xcode packaging acceptance, installer/L2 admission, launch, handoff, model,
> readiness or full verifier

## 1. Finding

The first L3c3b-i artifact spike disproved the proposed static-facade topology.
A native Xcode tool that linked
`DriverSupport -> StornautInvestigationMachine -> StornautCore` built and signed
successfully, but its final Mach-O carried metadata and symbols for:

- `StornautCore.CleanupAuthorizationController`;
- `StornautCore.CleanupPolicyGate`;
- `StornautCore.ActionPolicyGate`;
- `StornautCore.CleanupPlan`;
- `StornautCore.CleanupExecutionRuntime`; and
- `StornautCore.RegisteredAction`.

The same markers remained in an isolated Release build using whole-module
optimization. Concrete `StornautExecution` Executor/Trash symbols were absent,
but that is insufficient: the root Machine driver is forbidden from carrying
Cleanup, Policy or Registered Action surfaces at all. Dead stripping cannot be
the trust boundary. L3c3b-i therefore cannot proceed with a facade that links
the complete Machine target. No serial or checkpoint acceptance was consumed.

## 2. Revised Topology

Insert **L3c3b-0 authority-closed driver runtime extraction** before native
packaging:

```text
StornautInvestigationMachineDriverSupport
  imports Darwin only
  owns fixed root admission and unavailable statuses
  exposes only public async run() -> Int32

StornautInvestigationMachine
  -> DriverSupport
  retains a package compatibility wrapper for deterministic tests

SwiftPM driver executable -> DriverSupport only
future Xcode native driver -> DriverSupport only
```

The support target accepts no executable, path, argument, environment, UID,
endpoint, PID, signal, action or configuration input. It performs only the
current deterministic behavior: non-root returns `77`; root without the later
one-shot handoff returns `78`. The full Machine target must have no membership in
the Support static product or driver executable product.

This is not the later production handoff runtime. L3c3c-i/ii still owns the
launcher/handoff design and its dedicated narrow implementation target.
L3c3b-0 merely makes the packageable fail-closed entrypoint authority-free.

## 3. Frozen Scope

L3c3b-0 owns at most seven non-document paths and 1,500 added non-document
lines:

1. `Package.swift`
2. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDriverSupport.swift` (new)
3. `Sources/StornautInvestigationMachine/InvestigationMachineDriverHost.swift`
4. `Tools/StornautInvestigationMachineDriver/main.swift`
5. `Tests/StornautInvestigationTests/InvestigationMachineDriverHostTests.swift`
6. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`
7. `scripts/verify-investigation-boundaries`

The Xcode project/scheme and packaging gates remain unchanged until this
prerequisite is independently complete and pushed. If final Debug or Release
SwiftPM driver Mach-O still carries any Cleanup/Policy/Registered Action or
Executor/Trash marker, stop and redesign before L3c3b-i.

## 4. Validation

Validation is structural -> focused host/boundary tests -> complete
Investigation suite -> Debug and Release SwiftPM driver builds -> final Mach-O
negative controls -> independent review -> one clean staged serial. The binary
gate must prove the driver imports/links only Support and that the complete
Machine target is not a driver product member.

No `scripts/verify --full`, Xcode packaging build, install/uninstall, driver
root execution, handoff, model or readiness is permitted.

## 5. Safety Boundary

The failed artifact spike used isolated temporary build roots and changed no
installed state. Its prototype repository diff was fully reverted before this
preflight. `~/.codex/config.toml` was not modified. Production Deep Dive remains
unavailable. L3c3b-0 is complete; see the
[completion review](phase-d-task-39b2c-l3c3b-driver-runtime-authority-review.md).
L3c3b-i subsequently completed with the authority-closed Support product;
L3c3b-ii installer/L2 admission is next.
