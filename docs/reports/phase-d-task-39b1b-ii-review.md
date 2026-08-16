# Phase D Task 39B1b-ii Code Review and Completion Audit

> Status: Complete; tests-first implementation, focused regressions,
> independent post-fix review, serialized SwiftPM regression and one
> uninterrupted 23-stage authoritative `scripts/verify --full` passed.
>
> Date: 2026-08-16
>
> Baseline:
> `90055fb524955765733f5eeb120f7446a77af0af`
>
> Scope: strict DEBUG diagnostic App leaf, exclusive bounded preflight
> receipt and ordinary Debug/Release activation boundaries

## 1. Current Decision

Task 39B1b-ii is complete as the strict DEBUG App leaf checkpoint.
Implementation, focused validation, independent post-fix review and one
uninterrupted authoritative `scripts/verify --full` all passed.

The checkpoint adds only a preflight App leaf. It does not compose the
39B1b-i transport, invoke Codex, install the fixed lifecycle topology, create
a machine report or claim signed Investigation runtime readiness. Those
remain exclusively Task 39B2. Normal product Deep Dive remains
`.implementationUnavailable`; Task 44 remains its sole normal-product
admission gate.

## 2. Delivered Boundary

Task 39B1b-ii adds:

- an explicit static `StornautInvestigationDiagnostic` package product and
  target with zero dependencies;
- a dedicated `StornautInvestigationDiagnosticApp` Xcode target with exactly
  one explicit App source and one zero-dependency static package product;
- no synchronized ordinary App source group, Codex, Core, Lifecycle, helper,
  Trash, cleanup, Policy, Executor, direct network or arbitrary process
  dependency in the diagnostic product;
- a strict DEBUG activation parser accepting exactly one
  `--stornaut-investigation-runtime-config=` argument and no absent,
  malformed, duplicate or additional arguments;
- owner/mode/size/symlink-safe configuration loading using `O_NOFOLLOW`;
- a Foundation/Darwin-only preflight decoder that returns only the bounded
  nonce and diagnostic root path after validating the authoritative
  configuration;
- exclusive one-shot creation of
  `investigation-runtime-preflight.json`;
- typed open/write/fsync/close failure handling that removes a newly created
  partial receipt and returns a nonzero exit;
- preservation and nonzero rejection of an already existing receipt;
- a dedicated test target that may link `StornautInvestigation` only to
  construct the authoritative configuration for comparison; that dependency
  is absent from the product App scanned before XCTest injection;
- ordinary Debug and Release App negative controls plus diagnostic product
  positive controls in `scripts/verify-app-release-boundaries`.

The ordinary App remains unchanged except that `CFBundleName` now derives from
`$(PRODUCT_NAME)`, allowing the dedicated diagnostic product to carry its own
name without forking the shared plist.

## 3. Scope and Cost Audit

The checkpoint changes nine non-document source, test, project and script
paths, adding 2,131 lines and deleting three. It remains below the Task 39 hard
split gate of 14 non-document paths or approximately 4,000 added non-document
lines.

Real-model execution, fixed-topology installation, machine-report assembly,
failure-matrix diagnostics, product UI and production availability remain
outside this checkpoint.

## 4. Tests-First and Focused Evidence

The final dedicated Xcode test target passed:

```text
total=11
passed=11
failed=0
skipped=0
```

The tests cover:

1. absent, malformed, duplicate and additional activation rejection;
2. exact authoritative configuration comparison;
3. relative, symlinked, wrong-owner/mode and oversized config rejection;
4. exclusive first receipt creation;
5. second-run nonzero rejection without receipt replacement;
6. partial write, write failure and fsync failure cleanup;
7. dedicated target/source/dependency structure boundaries.

Evidence:

```text
.derivedData/task39b1bii-fix3/Logs/Test/
Test-StornautInvestigationDiagnosticApp-2026.08.16_15-38-06-+0800.xcresult

/tmp/stornaut-task39b1bii-focused-postreview-v2.log
SHA-256 f330a1f50d9ee7f2d68d4d7cde8192d5f5d0b2308474e4aac39c2a0d111998c8
```

The final product-bundle boundary gate built and scanned the pure diagnostic
App before running its test action, preventing XCTest injection from creating
a false product finding. It verified:

- ordinary Debug App: diagnostic marker absent;
- ordinary Release App: diagnostic marker absent;
- diagnostic Debug App: exact marker present;
- diagnostic App: forbidden authority/binary markers absent;
- diagnostic target: exact source and package dependency allowlists;
- diagnostic product: no helper copy or forbidden linked dependency.

Evidence:

```text
Release App fixture boundary verification passed.
real 161.79

/tmp/stornaut-task39b1bii-app-release-postreview-v3.log
SHA-256 7d087866ea119bab7b1b8cc36e2d6d81f0444435512e960c9e82ad092f675be1
```

The final structural gates passed:

```text
scripts/verify-investigation-boundaries
scripts/verify-codex-no-executor-boundary
scripts/check-doc-links
git diff --check
zsh -n scripts/verify-app-release-boundaries scripts/verify-investigation-boundaries
```

The post-fix serialized SwiftPM regression passed:

```text
846 tests in 33 suites passed after 99.178 seconds
12 explicit opt-in diagnostics skipped
real 105.27
```

Evidence:

```text
/tmp/stornaut-task39b1bii-serial-postfix.log
SHA-256 c4efb86724c11f0f621981e91927ae26b2a5d95da1ee0010c2bb1c22310f8af1
```

The explicit opt-in real-model and destructive diagnostics remained skipped.
No Task 35 Trash/recovery mutation was replayed.

## 5. Independent Review and Repair

The first independent P0-P2 review found:

1. P1: the original diagnostic target compiled the ordinary App source tree
   and linked Codex/Lifecycle/helper;
2. P1: the original composition retained live Trash authority through the
   ordinary App model;
3. P1: the first boundary verifier could pass despite that dependency leak;
4. P2: malformed activation could select diagnostic composition;
5. P2: receipt open/write/fsync failure could be reported as success.

Tests were added or strengthened before each repair. The implementation was
then reduced to a dedicated zero-dependency static leaf and one-source App,
the ordinary App composition was removed, activation became exact, and
receipt failures became typed, fail-closed and partial-cleaning.

The final independent `gpt-5.6-luna` post-fix review inspected the nine-path
scope and reported:

```text
NO_UNRESOLVED_P0_P2
```

Evidence:

```text
/tmp/stornaut-task39b1bii-postfix-review-result.txt
SHA-256 f3d212a3dfda094a5813b761e77d23ee0f3265b3d5bb7d8282d1effac540df26
```

Model review is review evidence only. It is not capability observation,
signed-App containment, structural no-Executor proof or Task 39B2 admission
evidence.

## 6. Task 35 Seal Preservation

The first final-verifier command stopped in its zero-cost read-only preflight
before stage selection:

```text
Task 35 safety-critical source binding drifted:
Stornaut.xcodeproj/project.pbxproj
FULL_VERIFY_EXIT=1
FULL_VERIFY_SECONDS=0
```

No build, App launch, UI test, Trash or recovery mutation ran. The checkpoint
legitimately changed two files already bound by the sealed Task 35 receipt:

```text
Stornaut.xcodeproj/project.pbxproj
7ab73e0c57eda446659032524d4fa1499062c0a709f197a76d0ab5f69d6758ea

scripts/verify-app-release-boundaries
af5d313634e349a20e8128cae1947e56ab75126f3ee167c22fe4f278c0a69e53
```

Only those two exact source hashes were refreshed. The artifact identities,
historical Trash/recovery outcomes, limitations and every other source binding
remain unchanged. Post-refresh evidence:

```text
Phase C signed Trash checked receipt and source binding passed.
source_binding_drift_count=0
scripts/verify-phase-c-trash-diagnostic exit 65
scripts/verify-phase-c-trash-recovery exit 65
Phase C target-aware Trash diagnostic contract passed.
Verifier mode and CI contract verification passed.
```

The mutation entrypoints therefore remain sealed and were not replayed.

## 7. Authoritative Verification

One uninterrupted final `scripts/verify --full` passed all 23 ordered stages:

```text
Verification passed in full mode.
FULL_VERIFY_EXIT=0
FULL_VERIFY_SECONDS=972
```

Evidence:

```text
/tmp/stornaut-task39b1bii-full-verify-final.log
SHA-256 01ae7d7b09803c89bf11f501702c1a95e73bfe6b42584ecd16dacb6d7c96c2e9
```

Important timings and evidence:

- XCUITest passed in `534.284` seconds;
- all 30 screenshot contracts passed;
- SwiftPM clean build passed in `18.498` seconds;
- 841 regular SwiftPM tests passed in `33` suites; explicit opt-in real-model,
  capacity and destructive diagnostics remained skipped;
- the isolated maximum Investigation benchmarks passed in `33.301` seconds;
- App tests and snapshots passed in `42.169` seconds;
- Debug App build/sign and bundle validation passed;
- ordinary Debug/Release plus diagnostic product boundaries passed in
  `143.876` seconds;
- source boundaries, localization, rule compiler, verifier contracts,
  documentation links and diff hygiene passed;
- the 74-test Phase C product gate and sealed Task 35 receipt passed without
  replaying Trash or recovery.

## 8. Scope and Safety Audit

Task 39B1b-ii does not:

- invoke a real model or infer containment from model success;
- compose the 39B1b-i Codex transport into the diagnostic App;
- install, start or remove the fixed helper/runtime topology;
- create a capability, containment or machine-readiness report;
- edit `~/.codex/config.toml`;
- inspect a real user investigation path;
- add normal product navigation or Deep Dive availability;
- add Review, cleanup, Policy, authorization, Executor or Trash authority;
- change release, notarization, FDA/TCC or distribution claims.

## 9. Next Gate

Task 39B2 is next after this checkpoint's independent commit and push. It
exclusively owns:

- current-source signed App/helper invocation;
- one bounded real authenticated Codex Investigation;
- independent capability, control and denial evidence planes;
- cancellation, timeout, invalid-envelope and transport/lifecycle failure
  matrix;
- fixed-topology teardown and zero-residue proof;
- the final `signedInvestigationRuntimeReady` Task 39 admission decision.
