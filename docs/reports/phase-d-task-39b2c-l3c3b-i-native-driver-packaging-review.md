# Phase D Task 39B2c-L3c3b-i Native Driver Packaging Review

> Status: Complete; diagnostic-only native packaging admitted
>
> Date: 2026-08-18
>
> Baseline: 589fb0460c75f09931414f10532ffe6efa66be0d
>
> Scope: native Xcode Machine-driver target, diagnostic-only copy/signing and
> final-artifact admission; no installer/L2 admission, launch, handoff, model,
> readiness or full verifier

## 1. Decision

L3c3b-i is complete. Xcode now builds exactly one native command-line target,
StornautInvestigationMachineDriverNative, whose final product is
StornautInvestigationMachineDriver. The target compiles only the shared
Tools/StornautInvestigationMachineDriver/main.swift entrypoint and links only
the zero-dependency StornautInvestigationMachineDriverSupport static product.
It has no Machine, Core, Lifecycle, Runtime, Diagnostic, Codex or Execution
dependency.

Only StornautInvestigationDiagnostic.app depends on and copies the driver. A
separate Copy Investigation Driver phase owns exactly one CodeSignOnCopy member
at Contents/MacOS. The ordinary App, helper and all test targets remain
driver-free, and the ordinary scheme is unchanged.

The fixed native signing identifier is
com.eriklee.stornaut.investigation.machine-driver. Both driver build
configurations are arm64, manually ad-hoc signed, inject no base entitlements,
use no App entitlement file and compile the shared @main source with
-parse-as-library. The Support runtime still fails closed with status 77 for
non-root and 78 for root without the later one-shot handoff.

## 2. Exact Scope and Cost

The implementation changes exactly six non-document paths:

1. Stornaut.xcodeproj/project.pbxproj
2. Stornaut.xcodeproj/xcshareddata/xcschemes/StornautInvestigationDiagnosticApp.xcscheme
3. Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift
4. scripts/verify-investigation-boundaries
5. scripts/verify-app-release-boundaries
6. scripts/verify-contract

The frozen implementation tree contains 1,503 additions and 27 deletions,
below the approved nine-path / 2,500-added-line ceiling. Its accepted staged
tree is e1878eced30a6193aa89ad89dd88d02949e9f2a3. Package.swift,
DriverSupport, the shared main source, the ordinary scheme, App/helper source,
the installer, Lifecycle/L2 source and the launchd plist did not change.

## 3. Tests First, Build Evidence and Review Fix

The mandatory Swift unit-test workflow completed all seven steps and flushed
its report. Four structural tests first failed with 24 issues against the old
six-target/two-copy-phase and driver-absent contracts. The implementation then
closed the graph, scheme, artifact and installer-blocked contracts. Coverage was
skipped because no CI or user threshold applies and Swift line coverage cannot
measure Xcode-project or shell/Python verifier contracts.

The first native build exposed the Xcode-specific main.swift/@main parse-mode
conflict. Adding -parse-as-library only to the driver's Debug and Release build
configurations preserved one shared entrypoint without a wrapper target. The
subsequent diagnostic build passed.

A representative current-source local build observed the standalone product
and final nested copy as byte-identical arm64 regular executables: mode 0755,
one hard link, 63,216 bytes, signing identifier exactly
com.eriklee.stornaut.investigation.machine-driver, SHA-256
336d0f68622bf2cd1c87dd412bda6c1bac69b524c64c5f8c6764e3942d4eb932
and CodeDirectory hash 040dc16f4bb40a743ba900a41459cbbb004addaa. The
actual ad-hoc designated requirement was CDHash-based, not identifier-based.
The gate therefore validates the exact current product/nested identifier,
designated requirement, CodeDirectory hash and executable SHA relationship
instead of hard-coding one build's hashes.

Independent review found one P1 in the first Swift structural test: several
driver build settings were checked with whole-project string searches and could
be satisfied by unrelated targets. The test now resolves the driver target,
Sources/Frameworks/copy objects, copy build file, configuration list and both
Debug/Release configuration objects before checking their exact members. A
post-fix review confirmed the P1 is closed; the verifier group and cross-group
review found no unresolved P0-P2.

Review artifacts:

- /tmp/stornaut_l3c3bi_review/group/group_1.jsonl
- /tmp/stornaut_l3c3bi_review/group/group_2.jsonl
- /tmp/stornaut_l3c3bi_review/postfix.jsonl
- /tmp/stornaut_l3c3bi_review/cross_group.jsonl
- /tmp/stornaut_l3c3bi_review/report.html

The final empty finding set SHA-256 is
37517e5f3dc66819f61f5a7bb8ace1921282415f10551d2defa5c3eb0985b570.

## 4. Validation

| Gate | Result |
| --- | --- |
| tests-first structural suite | expected 24-issue failure, then 4/4 passed |
| Xcode project parse/list | seven native targets observed |
| diagnostic Debug build | passed after target-local parse-mode fix |
| verifier self-contract | passed |
| default Investigation structural gate | passed |
| focused App final-artifact gate | passed |
| complete Investigation target | 202 tests in 19 suites passed |
| clean staged-only serial regression | 1,060 tests in 51 suites passed |
| serial test / stage time | 91.117 / 143.281 seconds |
| accepted implementation tree | e1878eced30a6193aa89ad89dd88d02949e9f2a3 |
| final independent review | no unresolved P0-P2 |

The clean staged-only serial ran exactly once from generated validation commit
719808e8b34022c44774a7055c6d3b4e64f5743a over the accepted index tree. The
validation commit tree and the main index are exact, and the isolated validation
worktree was removed. There was no restart, failed-stage retry or second serial
execution. Maximum benchmarks remained skipped.

Neither authoritative headless verification nor scripts/verify --full was run.
The remaining authoritative full verifier is reserved for L3c4.

## 5. Safety Boundary and Next Gate

This checkpoint built and inspected artifacts only. It did not install or
launch the App, helper or driver; invoke the driver; implement handoff; call a
model; consume authoritative machine evidence; or make a readiness claim. The
root lifecycle installer deliberately continues to reject a present driver at
built, staging and installed validation until L3c3b-ii migrates exact admission.

L3c3b-ii installer and L2 driver admission is next. Production Deep Dive
remains unavailable, Task 39 is incomplete, and ~/.codex/config.toml was not
modified.
