# Phase D Task 39B2c ii-c-b1 Root-Owned Gate Preflight

> Status: frozen / implementation current / non-admitting
>
> Date: 2026-08-31
>
> Baseline commit: `41f5dba1b7ff7f1272d5a2607ae9794b266e6c47`
>
> Baseline tree: `dc126f7d734d4906f5acef85498d2ec62ff3058e`
>
> Parent checkpoint: ii-c-b (root-owned Gate plus non-privileged dry-run
> campaign harness)

## 1. Defect and Decision

The ii-c-a installer normalizes the complete diagnostic App, including the
fixed Gate executable, to `root:wheel` and mode `0755`. The current
`InvestigationFixedGateDarwinLifecycle.validateExecutable(_:)` instead accepts
only a Gate whose file owner and group equal the non-privileged coordinator's
current process identity. On the approved local topology that is `501:20`, so a
correctly installed Gate is deterministically rejected before spawn.

ii-c-b is therefore split internally without adding a new Task:

1. **ii-c-b1** closes only the root-owned Gate file-admission mismatch; and
2. **ii-c-b2** later implements the non-privileged PTY/FD3/raw-evidence
   campaign harness and independent verifier.

The file identity and process identity remain distinct contracts. ii-c-b1
requires the installed Gate file to be exactly UID 0 / GID 0, while Gate and
Coordinator invocation identities remain exactly UID 501 / GID 20. There is no
`root || currentUser` fallback.

## 2. Frozen Scope and Budget

The implementation may change exactly these six non-document paths:

1. `Sources/StornautInvestigationMachineLaunchSupport/InvestigationFixedGateDarwinLifecycle.swift`;
2. `Tests/StornautInvestigationTests/InvestigationFixedGateDarwinLifecycleTests.swift`;
3. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
4. `scripts/verify-investigation-boundaries`;
5. `scripts/verify-app-release-boundaries`; and
6. `scripts/verify-contract`.

The aggregate changed-line ceiling is 1,900 non-document lines. A seventh
non-document path, line 1,901, package/Xcode topology change, schema/protocol
change, new public API, or new authority stops implementation for a new
preflight. Documentation and the final completion audit do not count toward
the non-document path limit.

`InvestigationFixedGateHandoffPhysicalTests.swift` is deliberately excluded.
Its temporary Gate is copied by the non-root test process and cannot honestly
prove the production root-owned success path. It remains historical evidence;
the real root-owned physical proof belongs to the unique ii-c-c installed
campaign.

## 3. Required Contract

The current-tree implementation and tests must prove all of the following:

- a Gate file owned by UID 0 / GID 0 passes acquisition, pre-spawn
  revalidation and post-spawn revalidation;
- `501:0`, `0:20`, arbitrary non-root/non-wheel ownership and any owner/group
  drift fail closed;
- the Gate and Coordinator process identity constants remain `501:20`;
- held and named node identities remain equal;
- mode remains `0755`, link count one, flags zero and extended ACL empty;
- xattrs remain limited to `com.apple.provenance`;
- descriptor SHA remains equal to independently read bytes;
- sibling basename, acquisition, pre-spawn and post-spawn revalidation remain
  mandatory; and
- no root execution, sudo invocation, install, launchctl, readiness, product
  Deep Dive or cleanup/Executor/Registered Action authority is added.

## 4. Verification Funnel

The checkpoint runs, in order:

1. a focused RED proving the current owner mismatch;
2. focused lifecycle GREEN tests;
3. current-tree source and semantic mutation gates;
4. exact six-path staged-scope gate;
5. component/final-Mach-O boundary inspection;
6. one clean staged-only serialized `StornautInvestigationTests` regression;
7. independent semantic, verifier and cross-group review; and
8. the current-tree aggregate contract gate.

Historical ii-c-a and fixed-gate gates are immutable replay only. The remaining
authoritative `scripts/verify --full` belongs exclusively to L3c4.

## 5. Prohibited Operations and Non-Claims

ii-c-b1 does not run sudo, install/uninstall, system launchctl, an installed
driver/Gate/Coordinator, product XPC, Codex auth/model/network, or the unique
machine campaign. It does not arm or consume the ii-c-c attempt. ADR 0018
remains Proposed, Task 39 remains incomplete and production Deep Dive remains
unavailable.
