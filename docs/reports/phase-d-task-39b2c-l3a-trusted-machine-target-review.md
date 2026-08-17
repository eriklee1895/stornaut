# Phase D Task 39B2c-L3a Trusted Machine Target Review

> Status: Complete; package target extraction prerequisite
>
> Date: 2026-08-17
>
> Baseline: `5201f039e15e2e8eaa29f13a5eb83e1a1f3f7e4b`
>
> Scope: isolate the existing machine contract, sealed authority, assembler and
> verifier in a non-product target; no CLI, collector, lifecycle mutation, model
> run, report emission or readiness claim

## 1. Decision

This prerequisite is complete. The 2,509-line machine-only contract and trusted
filesystem implementation moved unchanged from `StornautInvestigation` into a
dedicated `StornautInvestigationMachine` package target. Git records the move as
a 99% rename. The ordinary Investigation, Runtime and Diagnostic targets do not
depend on the machine target, and the target is not a package product.

The sealed-cohort authority, assembler and verifier remain module-internal.
They are not `public` or `package`, so another production target cannot
construct a fake authority. Future L3b machine-driver source must live in this
same target to use the trusted implementation directly. Tests use `@testable`
instead of production private-import flags.

This checkpoint does not implement or connect the old JSON CLI skeleton, collect
L1/L2 evidence, install or uninstall the fixed topology, invoke a model, emit a
machine report, claim `signedInvestigationRuntimeReady` or enable Deep Dive.

## 2. Target Boundary

`StornautInvestigationMachine` depends exactly on:

- `StornautCodex` for the existing capability evidence types;
- `StornautCore` for Investigation identities; and
- `StornautInvestigation` for the signed runtime contract.

It has no dependency on `StornautExecution`, `StornautLifecycle`, the runtime
composition target or the diagnostic target. It is not referenced by ordinary
product/runtime/diagnostic targets. Only `StornautInvestigationTests` adds a
test dependency.

The migration requires six narrow package-read surfaces in the common signed
runtime contract: binding validity, completed-output decoding/validation,
production validity/readiness and residue validity. They expose no process,
filesystem, lifecycle, cleanup or sealed-authority constructor.

## 3. Tests First

The new target-boundary test initially failed on three expected facts: the old
source still existed under `StornautInvestigation`, the new source did not exist
and the Package graph had no machine target. After extraction it proves:

- the trusted source exists only in `StornautInvestigationMachine`;
- the exact dependency graph and no product export;
- no Execution/Lifecycle/runtime/diagnostic dependency;
- no public/package trusted authority, assembler or verifier; and
- no cleanup, process-launch, mutation, direct-network or readiness surface.

The existing serialization, filesystem-adversarial and signed-runtime suites
now import the new target with `@testable`; no production private import remains.

## 4. Validation

| Gate | Result |
| --- | --- |
| tests-first target boundary | red before extraction; green after extraction |
| machine report serialization | 3/3 passed |
| machine filesystem adversarial | 11/11 passed |
| signed runtime contract | 44/44 passed |
| full Investigation focused suite | 151 tests in 14 suites passed |
| exact `source-boundaries` stage | passed in 4.416 seconds; diagnostic-only |
| targeted Debug diagnostic App build | passed in 10.4 seconds |
| independent review | `No unresolved P0-P2 findings.` |
| final clean staged-only serial SwiftPM regression | 982 tests in 42 suites passed |
| serial test execution | 109.363 seconds after a 40.78-second clean build |
| diff hygiene and target authority scan | passed |

The final serial ran once from an exact staged commit in a clean physical
`/Users/.../stornaut-validation.*/worktree` and exited `0`; the worktree and
process group were removed afterward.

The checkpoint changes eight non-document paths with 181 additions and 16
deletions plus a 99% source rename. It intentionally does not run XCUITest or
`scripts/verify --full`: there is no UI, executable, live collector, topology
mutation, model execution or readiness decision. The enclosing L3c machine
security gate still owns the single authoritative full-verifier run.

## 5. Safety Audit

The updated Investigation boundary gate requires the new source, rejects the old
source location, pins exact target dependencies, rejects package product export
or ordinary-target reverse dependencies, rejects public/package trusted
declarations and scans the target for Execution/Lifecycle/cleanup/process/
mutation/network/readiness surfaces.

No dependency or license was added. `~/.codex/config.toml` was not modified.
Production Deep Dive remains unavailable.

## 6. Next Gate

L3b may add a root-owned driver and fixed-service observer inside the trusted
machine target, then combine L1 helper-sealed residue with L2 installed and
post-teardown topology evidence in one bounded sealed cohort. L3b must remain
synthetic/non-admitting unless its own preflight explicitly proves the complete
live surface remains below checkpoint limits. L3c remains responsible for the
eight-case failure matrix, real bounded Task 38/model run, machine report,
admission receipt and final authoritative full verifier.
