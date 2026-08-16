# Phase D Task 39B2b-ii-E1 Code Review and Completion Audit

> Status: Complete; authoritative `scripts/verify --full` passed 23/23 stages
> in one uninterrupted run
>
> Date: 2026-08-16
>
> Baseline:
> `82ba09840a0845fca2125b0c1918208fb59c8fde`
>
> Scope: Registered Action process authority extraction from `StornautCore`

## 1. Current Decision

Task 39B2b-ii-E1 is complete. The concrete Registered Action process runner
now lives in a one-way `StornautExecution` target while `StornautCore` retains
only the typed protocol, output and error contracts.

This checkpoint is a prerequisite repair for the strict final-Mach-O gate. It
does not compose the signed Investigation diagnostic App, launch Codex, invoke
a model, assemble a readiness report or change normal product availability.

Task 39 remains incomplete. E2 must remove concrete Trash/Executor authority
from the Core dependency closure before the stashed 39B2b-ii signed
composition can resume. Task 39B2c alone owns the real-model machine
admission. Production Deep Dive remains `.implementationUnavailable`.

## 2. Root Cause and Delivered Boundary

39B2b-ii preflight found that the dedicated diagnostic App's final Mach-O
carried concrete cleanup and Registered Action authority because its static
dependency closure linked the complete `StornautCore` target. Source-level
non-use was insufficient. Dead stripping, disabling the Xcode Debug dylib,
whole-module optimization and `-Osize` did not remove the authority symbols.

E1 therefore:

- adds the public `StornautExecution` library and target;
- fixes its dependency direction to
  `StornautExecution → StornautCore + StornautProcessSupport`;
- moves `FoundationRegisteredActionRunner`, `posix_spawn`, process-group
  termination, `waitpid` and bounded output draining into that target without
  changing their behavior;
- leaves `RegisteredActionRunning`, `RegisteredActionProcessOutput` and
  `RegisteredActionRunnerError` in Core;
- requires clients that construct the concrete runner to explicitly import
  `StornautExecution`;
- adds source and package-graph gates proving Core has no Registered Action
  process authority and Investigation targets do not link the execution
  target.

The strict binary gate remains unchanged. This extraction is not a substitute
for E2 or for the final diagnostic Mach-O inspection.

## 3. Scope and Cost Audit

The checkpoint changes six non-document source, test and script paths. It adds
approximately 518 non-document lines and deletes 414, primarily by moving the
existing 413-line concrete runner without rewriting it.

It stays well below the hard split gate of 14 non-document paths or
approximately 4,000 added non-document lines. E2 remains a separate
checkpoint so Trash/Executor authority extraction is not mixed with this
process-runner move or with the stashed signed composition.

## 4. Tests-First and Focused Evidence

The initial structural test was written before the new target existed and
failed as expected because
`Sources/StornautExecution/Actions/FoundationRegisteredActionRunner.swift`
was absent.

Final focused verification:

| Focus | Result |
| --- | ---: |
| Registered Action tests | 11/11 passed |
| Investigation structural boundary | passed |
| Serialized SwiftPM regression | 895 tests in 37 suites passed |
| Documentation links | passed |
| Diff hygiene | passed |

The serialized regression completed in 111.42 seconds. Explicit opt-in
real-model, destructive and maximum-capacity diagnostics remained skipped.

## 5. Independent Review

An ephemeral read-only `codex exec` review used the official `openai`
provider and `gpt-5.6-luna`. It reviewed package direction, process cleanup,
API compatibility, Investigation linkage and the complete tracked/untracked
E1 diff.

The final result was:

```text
No P0–P2 findings.
```

The reviewer confirmed:

- Core retains only the typed Registered Action contract;
- all concrete spawn, process-group, wait and output-drain authority moved to
  `StornautExecution`;
- the package graph points only from Execution to Core/ProcessSupport;
- no Investigation, diagnostic or normal product App target currently links
  `StornautExecution`;
- the public concrete runner's new import requirement is the intentional API
  migration for this authority boundary.

The review sandbox could not create SwiftPM temporary/cache files because it
was read-only. This is a review-harness limitation, not a product failure;
the main agent's focused, serialized and authoritative full gates supplied
the executable evidence.

## 6. Final Verification

The checkpoint used the fixed validation funnel:

1. structural and focused tests;
2. one ordinary serialized SwiftPM regression;
3. independent read-only review;
4. documentation links and diff hygiene;
5. exactly one uninterrupted authoritative `scripts/verify --full`.

The authoritative full verifier passed all 23 stages with exit `0`. Timed
stages totaled 954.459 seconds:

| Stage | Result |
| --- | ---: |
| XCUITest | passed in 542.508 seconds |
| SwiftPM build | passed in 18.040 seconds |
| SwiftPM tests | 890 tests / 37 suites; passed in 63.610 seconds |
| Investigation benchmarks | passed in 33.453 seconds |
| App tests and snapshots | passed in 46.294 seconds |
| Debug/Release fixture boundary | passed in 148.596 seconds |
| Source, no-Executor, docs/diff and signed receipt gates | passed |

Full verifier log:

```text
/tmp/stornaut-task-39b2b-ii-e1-full-verify.log
SHA-256 dcb668d60e781565d5b4692f3dc938474f401cd4a65471e69fc07e03be9d0f3f
```

The sealed Task 35 Trash/recovery mutation was not replayed.

## 7. Scope and Safety Audit

Task 39B2b-ii-E1 does not:

- link `StornautExecution` into Investigation or diagnostic products;
- change Registered Action arguments, environment, timeout, output limits or
  process cleanup behavior;
- compose or launch the signed Investigation diagnostic App;
- invoke a real model or claim `signedInvestigationRuntimeReady`;
- enable normal product Deep Dive;
- edit `~/.codex/config.toml`;
- expand Codex write, localhost, private-network or Unix-socket authority;
- invoke Trash, recovery or any filesystem mutation;
- alter release, notarization, FDA/TCC or distribution claims.

## 8. Next Gate

Task 39B2b-ii-E2 is next. It receives a fresh tests-first scope/cost preflight
and owns:

- concrete FileManager Trash and Executor composition extraction from the
  Core dependency closure;
- explicit linkage only from authorized ordinary App/diagnostic paths;
- a strict final-Mach-O gate proving the Investigation diagnostic has no
  cleanup, Trash, Registered Action or process execution authority.

After E2 independently passes and is pushed, the stashed 39B2b-ii signed
diagnostic-App/Task 38 composition can resume. Machine execution remains
exclusive to 39B2c.
