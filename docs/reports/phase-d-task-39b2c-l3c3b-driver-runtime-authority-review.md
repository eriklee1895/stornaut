# Phase D Task 39B2c-L3c3b-0 Driver Runtime Authority Review

> Status: Complete; authority-closed packageable entrypoint prerequisite
>
> Date: 2026-08-18
>
> Baseline: `28a7bbea78a57f9b676216256039de8cb3d63f4f`
>
> Scope: SwiftPM driver runtime target-graph closure and final-Mach-O admission;
> no Xcode packaging, installer/L2 admission, handoff, model, readiness or full
> verifier

## 1. Decision

L3c3b-0 is complete. The new
`StornautInvestigationMachineDriverSupport` static product has no target
dependencies and imports only Darwin. Its only public operation is the
no-argument asynchronous `run() -> Int32`; its UID-specific status helper is
module-internal. It preserves the already accepted fail-closed behavior: a
non-root caller returns `77`, while root without the later one-shot handoff
returns `78`.

The package dependency direction is now:

```text
StornautInvestigationMachine -> DriverSupport
SwiftPM driver executable    -> DriverSupport
DriverSupport                -> no package target
```

The complete Machine target has no product membership. The driver executable's
final Debug and Release Mach-O files therefore cannot reach Machine/Core. The
Machine module retains only a package compatibility wrapper for deterministic
host tests; it does not become part of the packageable driver runtime.

## 2. Exact Scope and Cost

The implementation changes exactly seven non-document paths:

1. `Package.swift`
2. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDriverSupport.swift`
3. `Sources/StornautInvestigationMachine/InvestigationMachineDriverHost.swift`
4. `tools/StornautInvestigationMachineDriver/main.swift`
5. `Tests/StornautInvestigationTests/InvestigationMachineDriverHostTests.swift`
6. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`
7. `scripts/verify-investigation-boundaries`

The frozen implementation tree contains 302 additions and 16 deletions, below
the approved seven-path / 1,500-added-line ceiling. Its accepted staged tree is
`9b3642ad88fcccf9768141a8ebf1917565c99c49`. The Xcode project, scheme, App,
helper, installer, L2 observer, plist and signing configuration did not change.

## 3. Tests First and Review Fixes

The mandatory Swift unit-test workflow completed preparation, target/defect
analysis, tests-first red/green generation, affected validation, coverage
decision and report flush. Coverage execution was skipped because there is no
incremental coverage threshold for this checkpoint. The red test failed only
because the Support target did not yet exist.

The first final-Mach-O spike that motivated this prerequisite found forbidden
Cleanup/Policy/Registered Action surfaces in both Debug and Release when the
driver linked the complete Machine/Core graph. After dependency reversal, the
explicit binary gate builds both configurations in isolated scratch roots,
requires arm64 non-symlink executables and non-root exit `77`, and rejects whole
authority symbol families.

Independent review found one P1 in the first structural gate: the Support-only
denylist was narrower than the existing Machine authority pattern, allowing raw
`Darwin.unlink`, `Darwin.write` or socket calls to bypass source checks. The
Support resolved source graph now reuses the complete
`machine_authority_pattern`, and the boundary test lists the corresponding raw
write/network tokens. Direct pattern negative controls proved all three example
mutations are rejected. A final independent review reports no unresolved P0-P2.

Review artifacts:

- `/tmp/stornaut_l3c3b0_review.hoMkdC/pre_fix_report.html`;
- `/tmp/stornaut_l3c3b0_review.hoMkdC/report.html`; and
- `/tmp/stornaut_l3c3b0_review.hoMkdC/report.md`.

The final empty finding set SHA-256 is
`37517e5f3dc66819f61f5a7bb8ace1921282415f10551d2defa5c3eb0985b570`.

## 4. Validation

| Gate | Result |
| --- | --- |
| tests-first missing Support target | expected failure |
| Support/host/boundary focused | 13 tests in 2 suites passed before final API tightening |
| post-tightening focused | 12 tests in 2 suites passed |
| complete Investigation target | 201 tests in 19 suites passed |
| default Investigation structural boundary | passed |
| Debug and Release final driver binary gate | passed |
| raw write/network pattern controls | `Darwin.unlink`, `Darwin.write`, `socket` all matched |
| clean staged-only serial regression | 1,059 tests in 51 suites passed |
| serial test / stage / wall time | 87.093 / 138.815 / 143 seconds |
| accepted implementation tree | `9b3642ad88fcccf9768141a8ebf1917565c99c49` |
| final independent review | no unresolved P0-P2 |
| active-state documentation audit | no omissions or factual/link errors |

The clean staged-only serial ran exactly once from generated validation commit
`359eae5dceced4d17b98b8ea7c81c2ec675ecb28` over the accepted index tree. The
index tree before and after the run is exact, and the isolated validation
worktree was removed. There was no restart,
failed-stage retry or second serial execution. Maximum benchmarks remained
explicitly skipped. The diagnostic stage explicitly reported that authoritative
headless verification was not run.

`scripts/verify --full` was not run. It remains reserved for L3c4.
The final documentation-only closeout uses `scripts/check-doc-links` and
`git diff --check`; it does not rerun the accepted serial.

## 5. Safety Boundary and Next Gate

This checkpoint does not package or sign an Xcode driver, install or launch any
runtime, implement handoff, call a model, consume authoritative evidence or make
a readiness claim. The Support runtime is deliberately unavailable after root
admission until L3c3c's separately approved handoff implementation exists.

L3c3b-i native diagnostic-only packaging subsequently completed while linking
only this authority-closed Support product. L3c3b-ii installer/L2 admission is
next. Production Deep Dive remains unavailable.
`~/.codex/config.toml` was not modified.
