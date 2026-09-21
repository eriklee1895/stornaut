# Phase D Task 39B2b-i Code Review and Completion Audit

> Status: Complete; authoritative `scripts/verify --full` passed 23/23 stages
> in one uninterrupted run
>
> Date: 2026-08-16
>
> Baseline:
> `dfdff339725126c712d04144d25674224bc48523`
>
> Scope: helper-owned contained interactive worker under the fixed lifecycle
> topology

## 1. Current Decision

Task 39B2b-i is complete. Focused validation, independent post-fix review,
the serialized SwiftPM regression, documentation/diff hygiene and one
uninterrupted authoritative `scripts/verify --full` all passed.

This checkpoint proves only the helper-owned contained interactive worker:
the root helper owns XPC, lease, audit-session lifecycle and cleanup while a
same-helper child drops to the caller UID before constructing the Codex
session. It does not compose the signed diagnostic App with Task 38, invoke a
real model, assemble a machine report or claim
`signedInvestigationRuntimeReady`.

Task 39 remains incomplete. Task 39B2b-ii owns signed diagnostic-App and Task
38 production-session composition. Task 39B2c alone owns the real-model
machine admission, three-plane report, failure matrix and zero-residue
readiness proof. Production Deep Dive remains `.implementationUnavailable`;
Task 44 remains its sole normal-product admission gate.

## 2. Delivered Boundary

Task 39B2b-i adds:

- a closed actor-owned lifecycle broker for exact `start`, `write`, `read` and
  `retire` operations;
- exact Investigation and operation identity validation, operation replay
  rejection, a 900-second maximum horizon, 2 MiB line limit, 16 MiB combined
  session budget and one in-flight I/O operation;
- one shared retirement task so explicit retirement, invalidation and
  concurrent callers cannot drain the worker more than once;
- a public contained-session configuration exposing only Investigation ID,
  deadline and line/session budgets, with no executable, URL, provider, model,
  environment or arbitrary CLI authority;
- fixed Codex discovery, auth projection, runtime workspace, containment
  installation and exact `app-server --stdio` launch arguments derived inside
  `StornautCodex`;
- exact pre-spawn validation of executable identity, owner-only workspace,
  projected environment, installed containment digest and fixed launch
  arguments;
- bounded stdin/stdout/stderr I/O, process-group retirement and workspace
  removal;
- a DEBUG helper interactive wire whose root process owns XPC admission,
  lease creation, audit-session inventory, reply multiplexing, expiry and
  cleanup;
- one same-helper worker mode that calls `initgroups`, `setgid` and `setuid`
  before constructing `CodexContainedInteractiveSession`;
- operation-ID reply routing so one suspended read cannot block a later
  retirement request on the root helper queue;
- proactive deadline expiry, pending-reply draining and fail-closed helper
  exit;
- structural gates proving the root helper has no contained-session
  constructor and the public configuration has no launch-authority fields.

The helper wire remains DEBUG-only. No ordinary App or Release activation
surface changed.

## 3. Scope and Cost Audit

The checkpoint changes nine non-document source, test and script paths and
adds 3,497 non-document lines with 30 deletions. It stays below the hard split
gate of 14 non-document paths or approximately 4,000 added non-document
lines.

39B2b was split before implementation:

- **39B2b-i** owns only the helper-owned contained worker and strict
  root/UID boundary;
- **39B2b-ii** owns signed diagnostic-App composition and the Task 38
  production-session driver.

Real-model execution, machine-report assembly and the adversarial admission
matrix remain exclusively 39B2c.

## 4. Tests-First and Focused Evidence

The initial expected-red witnesses proved that the required broker, contained
session and helper composition seams did not exist:

```text
/tmp/stornaut-39b2b-i-contained-red.log
/tmp/stornaut-39b2b-i-helper-structural-red.log
```

The final focused matrix passed:

| Focus | Result |
| --- | ---: |
| Lifecycle interactive contract and broker | passed |
| Contained interactive process session | passed |
| Combined focused suites | 37/37 passed |
| Investigation structural boundaries | passed |
| Fixed XcodeBuildMCP Debug build | passed in 15.2 seconds |
| Serialized SwiftPM regression | 889 tests in 37 suites passed |
| Diff hygiene | passed |

Final focused evidence:

```text
/tmp/stornaut-39b2b-i-focused-final.log
/tmp/stornaut-39b2b-i-structural-final-focused.log
/tmp/stornaut-39b2b-i-xcode-build-post-review.log
/tmp/stornaut-39b2b-i-serial.log
```

The ordinary serialized SwiftPM regression completed in 74.47 seconds, with
the Swift Testing runner reporting 889 tests in 37 suites passed after 72.790
seconds. Explicit opt-in real-model, destructive and maximum-capacity
diagnostics remained skipped. Its SHA-256 is
`a36b3252c2002796e097c05e47e0a53bb541c3247050facdca34da67e98680ab`.

Supporting evidence hashes:

| Evidence | SHA-256 |
| --- | --- |
| Focused tests | `f7ebe98045ccd208721d2e8b14587d91e0448e2f6c7bc43c9c88dbfd2264b383` |
| Structural gate | `1de43c3ed562531d7251b48311896a4be9dda3cb391fc4a17a447a2fd461e0bb` |
| Fixed XcodeBuildMCP Debug build | `5074406141b9bf3f2dcbe3c0642b43f5dcca2aacf31c99b5eeef75baeb29045a` |

The contained process tests cover fixed launch arguments, line relay,
configuration expiry, line/session limits, descendant termination, blocked
read retirement, concurrent retirement, failed-launch cleanup, containment
tamper rejection and an escaped stderr owner.

The broker tests cover strict session identity, operation replay, combined
budget accounting, exact worker failure categories, actor reentrancy,
concurrent retirement, failed-start cleanup and unconfirmed drain rejection.

## 5. Independent Review and Repairs

The independent local `bits-code-guard` fallback reviewed all nine changed
files across the Codex session, Lifecycle broker and root-helper/UID-worker
call chains. No subagent was used. The review found four P1 defects:

1. contained `lineLimitExceeded` and `sessionLimitExceeded` failures were
   collapsed by the broker into generic `readFailed` / `writeFailed`;
2. an escaped descendant retaining stderr could keep `retire()` blocked until
   that process closed the pipe;
3. the root helper's worker input pipe lacked `F_SETNOSIGPIPE`, so an exited
   worker could terminate the cleanup owner with `SIGPIPE`;
4. the first cancellable stderr drain fix returned before accounting bytes
   already buffered in the pipe, allowing an over-limit stderr stream to be
   reported as clean.

Each finding received a failing witness before its repair:

```text
/tmp/stornaut-39b2b-i-review-broker-red2.log
/tmp/stornaut-39b2b-i-review-stderr-red2.log
/tmp/stornaut-39b2b-i-review-sigpipe-red.log
/tmp/stornaut-39b2b-i-review-stderr-buffer-red.log
```

The repairs:

- add a closed `LifecycleInteractiveWorkerError` contract and exact broker
  mapping;
- use cancellable nonblocking stderr polling;
- after cancellation, consume only bytes already ready in the pipe and stop
  immediately when no more bytes are available;
- set `F_SETNOSIGPIPE` on the root helper's worker input descriptor.

The escaped-stderr witness improved from `4.021` seconds to less than one
second in the final focused run while still preserving buffered stderr limit
accounting. The final post-fix review has zero unresolved P0–P2.

Review artifacts:

```text
/tmp/stornaut_39b2b_i_review_20260816/final_comments.json
/tmp/stornaut_39b2b_i_review_20260816/report.html
/tmp/stornaut_39b2b_i_review_20260816/report.md
```

## 6. Final Verification

The checkpoint followed the fixed validation funnel without using the full
verifier for debugging:

1. structural and focused tests;
2. one ordinary serialized SwiftPM regression;
3. independent review and focused repairs;
4. documentation links, shell syntax and diff hygiene;
5. exactly one uninterrupted authoritative `scripts/verify --full`.

The final full verifier passed 23/23 stages with exit `0` in 15 minutes
33.21 seconds. Its SwiftPM stage passed 889 tests in 37 suites, XCUITest
passed on its first run in 540.620 seconds, the screenshot contract passed,
and the Debug/Release, Investigation benchmark, source-boundary,
no-Executor, docs/diff and signed-App receipt gates all passed.

Final evidence:

| Evidence | Result | SHA-256 |
| --- | --- | --- |
| Serialized SwiftPM | 889 tests / 37 suites; 74.47 seconds | `a36b3252c2002796e097c05e47e0a53bb541c3247050facdca34da67e98680ab` |
| Authoritative full verifier | 23/23 stages; 15:33.21; exit 0 | `7b0cf0fe04c3484d6ac2a4d280f1db89bf8c41f09decaae27a138da3b9a7f046` |
| Documentation links | passed | `10bf4866d66ce89db383ceb902ed1e87c031bedcf9bef2edb631c837581e9715` |

The sealed Task 35 Trash/recovery mutation was not replayed.

## 7. Scope and Safety Audit

Task 39B2b-i does not:

- compose or launch the signed diagnostic App;
- invoke a real model;
- assemble a machine report or readiness verdict;
- enable normal product Deep Dive;
- edit `~/.codex/config.toml`;
- add provider/model/URL/executable/CLI choices to the helper wire;
- expand Codex write, private-network, localhost or Unix-socket authority;
- add cleanup, Policy, authorization, Executor, Trash or Registered Action
  authority;
- alter release, notarization, FDA/TCC or distribution claims.

The root helper never constructs `CodexContainedInteractiveSession`. The
contained session is created only after the worker has dropped to the exact
caller UID and GID. Audit-session draining remains the lifecycle backstop for
new-session descendants.

## 8. Next Gate

After this checkpoint's independent commit/push, Task 39B2b-ii is next. It
receives a fresh scope/cost preflight and owns:

- current-source signed diagnostic-App composition;
- the Task 38 production-session driver;
- deterministic/synthetic end-to-end protocol fixtures;
- exact App/helper/config binding without a real model or Ready machine
  report.

Task 39B2c remains the only checkpoint allowed to invoke the real model,
assemble the three evidence planes, run the adversarial failure matrix and
claim machine readiness.
