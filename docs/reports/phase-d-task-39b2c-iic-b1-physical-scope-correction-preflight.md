# Phase D Task 39B2c ii-c-b1 Physical Scope Correction

> Status: frozen / implementation current / non-admitting
>
> Date: 2026-08-31
>
> Original baseline: `41f5dba1b7ff7f1272d5a2607ae9794b266e6c47`
>
> Parent preflight:
> [ii-c-b1 Root-Owned Gate Preflight](phase-d-task-39b2c-iic-b1-root-owned-gate-preflight.md)

## 1. Trigger

The first clean staged-only `StornautInvestigationTests` run compiled and ran
860 tests. Its only failing suite was
`InvestigationFixedGateHandoffPhysicalTests`: every scenario returned
`spawnFailedBeforeTransfer` before a Gate PID existed. This is deterministic,
not load-related. The fixture copies the Gate as UID 501 / GID 20, while the
new production contract correctly requires the installed Gate file to be UID 0
/ GID 0.

The original six-path preflight incorrectly treated that physical test as
historical evidence while leaving it active in the current serialized suite.
That scope decision is superseded by this correction. The failed serial is not
acceptance evidence and will not be rerun unchanged.

## 2. Corrected Scope

The exact non-document scope is expanded by one path, from six to seven:

1. `Sources/StornautInvestigationMachineLaunchSupport/InvestigationFixedGateDarwinLifecycle.swift`;
2. `Tests/StornautInvestigationTests/InvestigationFixedGateDarwinLifecycleTests.swift`;
3. `Tests/StornautInvestigationTests/InvestigationFixedGateHandoffPhysicalTests.swift`;
4. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
5. `scripts/verify-investigation-boundaries`;
6. `scripts/verify-app-release-boundaries`; and
7. `scripts/verify-contract`.

The aggregate ceiling remains 1,900 changed non-document lines. This is below
the mandatory split threshold and does not expand product authority.

## 3. Current and Historical Evidence

The current physical test must execute only the non-root fixture and prove:

- the coordinator still runs as UID 501 / GID 20;
- the copied Gate is a regular, non-symlink file owned by UID 501 / GID 20 and
  therefore is not an installed root-owned artifact;
- the production handoff returns exactly `spawnFailedBeforeTransfer`;
- no Gate PID or process group was created;
- foreground control is preserved;
- the owner-only capsule is removed; and
- no attempt directory remains.

The former seven-scenario user-owned success/failure matrix remains immutable
historical evidence at commit
`373431d4d1c4022815eca3c0c5ac3dd9aa4c5f2d`, tree
`b08342e5a17d678768309a2efd190ef33e37b3e8`. The existing
`verify_iic0bivb1_contract` historical replay must remain green; current-tree
tests may not manufacture root ownership or add a current-user fallback.

## 4. Verification Correction

After the current physical test and b1 verifier are updated, run its focused
suite and all b1 source/mutation/scope gates before starting one replacement
clean staged-only serialized Investigation run. The failed 860-test run above
does not count as the checkpoint serial. No `scripts/verify --full` is allowed.

This correction does not run sudo, chown, install/uninstall, launchctl, an
installed artifact, product XPC, Codex, or the unique ii-c-c campaign.
