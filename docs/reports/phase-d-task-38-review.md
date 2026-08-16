# Phase D Task 38 Code Review and Completion Audit

> Status: Complete; tests-first implementation, focused regression,
> independent post-fix review, serialized SwiftPM regression and one
> uninterrupted 23/23-stage authoritative `scripts/verify --full` passed.
>
> Date: 2026-08-16
>
> Baseline:
> `e8242d891301627c49a91b6e29cd653ecf0f64fd`
>
> Scope: closed dependency-injected Investigation coordinator, fake runtime,
> strict App Server normalization, scientific loop, terminal barrier,
> recovery and structural no-Executor boundary

## 1. Current Decision

Task 38 is complete. The repository now has a closed
`StornautInvestigation` module that can coordinate one persisted admitted
Investigation through injected fake runtime, Store, lifecycle, Probe, clock
and ID owners.

The Task does not compose or call a real Codex runtime. It does not add App
state, UI, disclosure, Review projection, Policy, authorization, Executor,
Trash or product availability. Production Deep Dive remains
`.implementationUnavailable`; Task 39 is the next signed-App diagnostic gate
and Task 44 remains the sole normal-product admission gate.

The ordinary serialized suite confirms that the Task 37 maximum Store capacity
benchmark remains isolated:

```text
811 tests in 30 suites passed after 99.077 seconds
wall time 99.74 seconds
```

No maximum Store capacity worker ran. The authoritative full verifier did run
the existing bounded Task 36 Investigation source and planner benchmarks
exactly once, as required.

## 2. Delivered Boundary

Task 38 adds:

- `StornautInvestigation` as a SwiftPM product and module with no App or
  Executor dependency;
- one actor-owned `InvestigationCoordinator` facade for typed start, event,
  pause, stop, cancel, settlement and recovery operations;
- a one-shot Store-owned runtime-admission transaction that loads the
  persisted Plan, recomputes source truth and prevents an admission context
  from escaping;
- closed injected runtime, lifecycle, Probe, Store, clock and ID protocols;
- strict bounded one-line App Server decoding with receipt-selected
  collaboration and direct-tool schemas;
- root/child lineage, replay identity, direct-tool accounting and cumulative
  per-thread token normalization;
- atomic turn/context reservation plus monotonic operational Probe usage;
- deterministic bounded context compression and a versioned investigator-only
  prompt resource;
- the immutable T0, T0+15, T0+45, T0+135 and T0+140 terminal barrier;
- strict Envelope v2 report normalization joined to App-owned IDs;
- atomic terminal/recovery Store commands with report identity reuse and no
  report/evidence for blocked or failed outcomes;
- structural checks that reject process, shell, network, cleanup, Policy,
  authorization and Executor reachability from the coordinator module.

The public coordinator accepts no caller-supplied Plan, source fingerprint,
manifest, freshness Boolean, executable, shell argument, cleanup action or
reusable admission handle.

## 3. Tests-First and Focused Evidence

The focused matrix passed after the final review repairs:

| Focus | Result | Evidence SHA-256 |
| --- | ---: | --- |
| InvestigationCoordinator | 9 passed | `8420b265111c471c5d762e6364611557bc43d882d038e19955010af8cd77b0fb` |
| InvestigationEventNormalizer | 12 passed | `0c9cdbcdefbe2a828c9441d6d1832766b049795c762a481dc27710e7d2843d59` |
| InvestigationTerminalBarrier | 3 passed | `d930cc7c0482491fa496253f27523cc1ca3662c1c09e155276ea690b53ed6f75` |
| InvestigationRecovery | 19 passed | `86a7ec0f63e3575aaa9a92423a018a9d7ece637a59f02d67b75e6dc71665dfab` |
| InvestigationEnvelopeV2 | 16 passed | `2774306800834b4cdc43c3e95853cb5532aa4eeb7e35c776f63cae5a861f8ee2` |
| ProbeBroker | 9 passed | `a638a4f027e653dd0305b3d96f866161d1e777b6910a6f75e8305098b19efa51` |
| Lifecycle | 82 passed | `222422132bd3ab5498a97ab87dfd586ab7b3ea74c9b18583803c1d3589904c3a` |
| Investigation boundaries | passed | `029251799c423ef1debad24d51024081ba689494d1af76f21328462f37b570f5` |

The focused logs are under:

```text
/tmp/stornaut-task38-focused-1786843621/
```

The final serialized SwiftPM regression used the Swift 6.3-supported
`swift test --no-parallel` form:

```text
811 tests in 30 suites passed after 99.077 seconds
real 99.74
```

Evidence:

```text
/tmp/stornaut-task38-swift-serial-1786843655.log
SHA-256 62e1c74c26a18f929606820d94ea0cb40d1cf260813d8cebb5b071d093c13338
```

## 4. Independent Review and Repairs

The complete pre-documentation Task diff covered 30 source, test, package and
boundary files with approximately 8,605 changed or newly added lines.
Independent review used the `bits-code-guard` local fallback because no
repository custom workflow was configured. The final post-fix report found
zero unresolved P0–P2 findings.

Review artifacts:

```text
/tmp/stornaut_task38_review_1786842689/final_comments.json
SHA-256 37517e5f3dc66819f61f5a7bb8ace1921282415f10551d2defa5c3eb0985b570

/tmp/stornaut_task38_review_1786842689/report.html
SHA-256 73c97d824c6ceea297f6bf0af4d2e119ab6b401dd23008ced8d88f97b44f6df1

/tmp/stornaut_task38_review_1786842689/report.md
SHA-256 49d32bd7ffaa113e3244f6c9b9ef441b96a9c8b975da1473734fceee871c52e5
```

Confirmed P1-class issues repaired before that final report:

1. ordinary App Server prose/reasoning/plan items were initially treated as
   unknown tools. They are now semantic no-ops while still consuming their
   replay identity, preventing a later tool-shaped reuse of the same item ID;
2. actor reentrancy allowed recovery to overlap a live/start-in-progress
   coordinator. Separate start and recovery guards now fail closed in both
   directions across suspension points;
3. out-of-order Probe completions could regress cumulative usage. Every
   cumulative dimension now merges monotonically;
4. collaboration `item/started` incorrectly required child IDs that exist
   only in completed payloads. Started events are accepted without creating
   lineage; only a valid completed spawn edge admits a child;
5. a missing started event could let completion-side `fileChange`, unknown
   tool or write-capable MCP data avoid the tool classifier. Started and
   completed tool-capable events now use the same blocking classification;
6. terminal persistence initially risked treating its Store deadline as a new
   interval and accepting an older terminal root turn. It now receives only
   the remaining outer T0+135 envelope and accepts the latest matching
   terminal root turn.

Each repair was preceded by a failing regression and followed by the affected
focused matrix plus the complete serialized suite.

## 5. Task 35 Seal Preservation

Task 38 legitimately changes the shared Evidence Store and SQLite transaction
implementation already bound by the sealed Task 35 receipt. Only those two
source hashes were refreshed:

```text
Sources/StornautCore/Evidence/EvidenceStore.swift
364d06d93c4e956413658fa6beaaeb89403986c8ebd7b815ac78ae1cd8cf7549

Sources/StornautCore/Evidence/SQLiteConnection.swift
5c3747ca5eee8e35bf7203f706ae2fbdedf1cbd48706f975f458ea7a7f21cd3d
```

The first full-verifier invocation stopped at the early read-only seal
preflight after `0.56` seconds:

```text
Task 35 safety-critical source binding drifted:
Sources/StornautCore/Evidence/EvidenceStore.swift
```

No build, UI test, Trash or recovery mutation ran in that attempt. After the
two exact bindings were updated:

- the checked receipt/source verifier passed;
- the diagnostic and recovery mutation scripts still refused execution with
  their sealed exit code `65`;
- the target-aware diagnostic contract and verifier contract passed;
- artifact identity, historical outcome, limitations and raw mutation
  evidence remained unchanged.

## 6. Authoritative Verification

One uninterrupted final `scripts/verify --full` passed all 23 ordered stages:

```text
Verification passed in full mode.
real 884.57
user 262.67
sys 79.44
```

Evidence:

```text
/tmp/stornaut-task38-verify-full-final-1786843960.log
SHA-256 6e549a3d7335564cc704a35a851b5ccaeef8b39e06bccf5230251215e08f9745
```

Important stage evidence:

- XCUITest and screenshot contracts passed in `537.606 + 3.185` seconds;
- the full SwiftPM stage passed `806` tests in `62.934` seconds;
- bounded Investigation benchmarks passed in `33.055` seconds;
- App tests/snapshots, Debug build/signing, bundle validation and
  Debug/Release fixture boundary passed;
- all source boundaries, Rule Compiler, verifier contract, docs/diff,
  Phase C product and sealed signed-App Trash receipt gates passed.

The XCUITest stage accounted for about 61% of total wall time. Task 38 focused
tests completed in milliseconds to a few seconds, and the serialized full
SwiftPM suite completed in about 100 seconds. The prior development delay was
therefore not caused by Task 37 capacity benchmark leakage or a SwiftPM
performance regression.

## 7. Iteration Granularity Audit

Task 38 combined module creation, Store admission, event protocol, lineage,
scientific-loop budgets, terminal settlement, recovery, prompt resources and
structural verification in one Task. Its 30-file, approximately 8,605-line
pre-documentation review surface was too large for one normal iteration.

That planning granularity, plus six real P1-class review repairs, was the
primary reason one evening advanced only one numbered Task. Future Tasks must
perform a scope/estimated-cost preflight before implementation and keep
focused regression on changed seams. The authoritative full verifier remains
one final Task-boundary run; it must not be repeated after every local repair.

This correction changes delivery mechanics only. It does not weaken the
tests-first, independent-review, full-verifier or one-Task/one-commit gates.

## 8. Scope Audit

Task 38 does not:

- call a real Codex/model or compose the signed helper/App runtime;
- claim capability observation or containment from fake-runtime tests;
- add first-use disclosure, App workflow, navigation or UI;
- project findings or candidate proposals into Review;
- construct Cleanup Plans, Policy decisions, authorization or execution;
- enable Trash, Registered Actions or permanent deletion;
- change release signing, notarization or distribution;
- edit `~/.codex/config.toml`.

Task 39 may now implement only its approved signed-App diagnostic admission.
Production Deep Dive remains unavailable until the separate Task 44 final
admission.
