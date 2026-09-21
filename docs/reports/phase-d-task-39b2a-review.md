# Phase D Task 39B2a Code Review and Completion Audit

> Status: Complete; tests-first implementation, focused regressions,
> independent post-fix review, serialized SwiftPM regression and one
> uninterrupted 23-stage authoritative `scripts/verify --full` passed
>
> Date: 2026-08-16
>
> Baseline:
> `a6ebf12b80a3e97b725707dddf21af1783126ee6`
>
> Scope: strict lifecycle interactive-session contract, exact signed-peer XPC
> client and package-closed supervised Codex App Server transport

## 1. Current Decision

Task 39B2a is complete. Its tests-first implementation, focused validation,
serialized SwiftPM regression, independent post-fix review and one
uninterrupted authoritative `scripts/verify --full` all passed.

This checkpoint proves only the closed supervised transport foundation. It
does not change the lifecycle helper, invoke Codex or a model, compose the
signed App/helper production diagnostic, assemble a machine report or produce
`signedInvestigationRuntimeReady`.

Task 39 remains incomplete. Task 39B2b must add the helper-owned contained
interactive worker and signed production composition. Task 39B2c alone owns
the real-model machine admission, three-plane report, failure matrix and
zero-residue proof. Production Deep Dive remains
`.implementationUnavailable`; Task 44 remains its sole normal-product
admission gate.

## 2. Delivered Boundary

Task 39B2a adds:

- a strict versioned `start` / `write` / `read` / `retire` lifecycle contract
  bound to exact Investigation and operation identities;
- fixed raw-line, encoded-envelope and cumulative-session limits of 2 MiB,
  3 MiB and 16 MiB;
- an exact signed-peer `NSXPCConnection` client with one-shot response
  resolution, 15-second ordinary-operation timeout and independently
  cancellation-shielded 45-second retirement timeout;
- cancellation/dispatch linearization: cancellation before dispatch prevents
  the XPC request, while cancellation after dispatch commitment cannot report
  a false local cancellation for an already committed remote operation;
- a closed privacy-safe remote reason allowlist whose unknown values collapse
  to `runtime.lifecycle.interactive.remote-rejected`;
- a package-scoped serialized App Server transport with lazy start, exact
  response identity validation, line/session accounting, deadline checks
  before dispatch and after response, cancellation-aware waiters and mandatory
  drained retirement;
- direct retirement of a fresh transport without implicitly starting a
  worker, while an ambiguous failed start remains retirable by Task 38's
  unique cleanup owner;
- structural gates that reject helper-side interactive-wire implementation,
  public product exposure, direct process/network/filesystem authority,
  cleanup/Executor authority and blocking XPC bridges during this checkpoint.

The helper intentionally still lacks `handleInteractive`. That implementation
belongs to Task 39B2b.

## 3. Scope and Cost Audit

The checkpoint changes seven non-document source, test and script paths and
adds 2,572 non-document lines with two deletions. It stays below the hard
split gate of 14 non-document paths or approximately 4,000 added
non-document lines and within the approved nine-path 39B2a write set.

No App, Xcode target, helper executable, real-model script, runtime report
assembler, UI or product availability source changed.

## 4. Tests-First and Focused Evidence

The final focused matrix passed:

| Focus | Result |
| --- | ---: |
| Lifecycle interactive contract | 13/13 passed |
| Complete `StornautLifecycleTests` | 73/73 passed |
| Lifecycle App Server transport | 11/11 passed |
| Complete `StornautInvestigationTests` | 103/103 passed |
| Investigation structural boundaries | passed |
| Documentation links | passed |
| Diff and shell hygiene | passed |

The final cancellation/dispatch regression first failed against the old
implementation because a committed dispatch still completed locally as
`.cancelled`:

```text
/tmp/stornaut-39b2a-dispatch-linearization-red.log
SHA-256 9d40d8d8c467d335dd98a7c6dba34fd3f3ed13146edfc832c85c8615dbcbc31c
```

After the lock-linearized repair, the exact suite passed 13/13:

```text
/tmp/stornaut-39b2a-dispatch-linearization-green.log
SHA-256 87ee53bd6b0655ca1dccc1b1685289ce3dfeb339f775ee6ad39a5b22f19a5d40
```

Final affected-suite evidence:

```text
/tmp/stornaut-39b2a-lifecycle-final.log
SHA-256 375040d6c451d077190e7d2df7a71a7bffd4923adb25ab8019f0d0413b9f5f07

/tmp/stornaut-39b2a-investigation-final.log
SHA-256 021a7dcd20d99389914778da115cdb9c2a99f002c9476d29a779272901d606bc

/tmp/stornaut-39b2a-boundaries-final.log
SHA-256 f1caed6ddda86f7a34f6dd07952efd824c9561d1bbb02cb21f648bc92015be5c
```

The final serialized SwiftPM regression passed:

```text
865 tests in 35 suites passed after 65.977 seconds
real 66.81 seconds
```

The five maximum benchmarks owned by the authoritative full verifier were
explicitly skipped so they are not duplicated in the ordinary serial suite.

```text
/tmp/stornaut-39b2a-final-serial-post-linearization.log
SHA-256 1bb43fbe1564b6ec435a68010048b6466fc067d73e7c275da8f13b8f3f32d203
```

Explicit opt-in real-model and destructive diagnostics remained skipped. The
sealed Task 35 Trash/recovery mutation was not replayed.

## 5. Independent Review and Repairs

Independent review used authenticated Codex `gpt-5.6-luna` in read-only mode.
It inspected tracked and untracked source directly and did not run tests,
modify source or alter `~/.codex/config.toml`.

Review iterations found and tests-first repaired:

1. failed-start actor state could be resurrected;
2. XPC operations could wait indefinitely or complete more than once;
3. encoded XPC envelopes needed an independent cap above the raw-line cap;
4. a response arriving after the immutable deadline could still be accepted;
5. retirement needed cancellation shielding with an independent timeout;
6. cancelled queued waiters needed exact actor-serialized removal;
7. cancellation between continuation installation and dispatch could send
   stale ordinary I/O;
8. fresh retirement could implicitly start a worker;
9. prefix-only remote reason filtering could expose detail-bearing strings;
10. cancellation after dispatch commitment could report a false local
    cancellation while the request still executed remotely.

The last issue received a dedicated red witness and repair. `beginDispatch`
and cancellation now share one lock and one linearization point:

- cancellation wins first: the resolver finishes and dispatch is rejected;
- dispatch wins first: late cancellation is ignored and the operation waits
  for its response, connection failure or independent timeout.

Initial and closure-review evidence:

```text
/tmp/stornaut_39b2a_closure_review_1786871272/codex-review.md
SHA-256 c5a465b0e2c284530ab051def31aa7cdc305bba5e5482d73909235b30d1313df

/tmp/stornaut_39b2a_closure_review_1786871272/post-fix-review.md
SHA-256 bb40bebc1bc4ab381bc64ddc8b7644fe9773258ccde25e0f81cb7789e9a7d2fe
```

The final one-finding re-review, session
`01a009ea-516a-76c1-bb2b-462e2ac0004a`, concluded:

```text
Verdict: PASS
Finding 1: CLOSED
New P0-P2 directly introduced: None
```

Evidence:

```text
/tmp/stornaut_39b2a_closure_review_1786871272/final-linearization-review.md
SHA-256 9891276173893d14de021c6a2dc33b211445ec482d43113e6453254631ad9f42
```

Model review is review evidence only. It is not model capability observation,
signed-App containment, no-Executor proof or Task 39 machine admission.

## 6. Authoritative Verification

One uninterrupted final `scripts/verify --full` passed all 23 ordered stages:

```text
Verification passed in full mode.
wall time: 932 seconds
sum of recorded stage timings: 931.354 seconds
```

Evidence:

```text
/tmp/stornaut-39b2a-full-verify.log
SHA-256 5e19b24827579d531dbfeb45ed7453c5b38f71d543dc69f9c71ca08142ff75aa

.derivedData/verification/full-timings.tsv
SHA-256 3f08eb6f2b8b03d62a10bb5d99dbd02f4f9ce3f80149cb54e7ae2260ad7ac124
```

Important stage evidence:

- XCUITest passed in `540.479` seconds without a focus-loss retry;
- screenshot contracts passed with 30 exported canonical images;
- the full SwiftPM stage passed all 865 tests in 35 suites;
- maximum Investigation source and candidate benchmarks passed in `33.328`
  seconds;
- all source/no-Executor boundaries, App tests/snapshots, Debug build/signing,
  bundle validation and Debug/Release fixture boundaries passed;
- documentation links, diff hygiene, Rule Compiler and verifier contracts
  passed;
- the sealed Phase C signed-App Trash receipt passed without rerunning the real
  Trash/recovery mutation.

The verification wrapper's optional elapsed-time echo used an unset zsh
`EPOCHSECONDS` and printed `0`; the verifier result itself was exit `0`.
The wall time above is derived from the full log creation/modification
timestamps and agrees within one second with the sum of the verifier's own 23
recorded stage durations. The full verifier was not rerun.

## 7. Scope and Safety Audit

Task 39B2a does not:

- implement or export the helper-side interactive wire;
- launch Codex or call a model;
- install, start or remove the fixed runtime topology;
- create a machine report or readiness verdict;
- edit `~/.codex/config.toml`;
- inspect a real user Investigation path;
- add product Deep Dive UI or availability;
- add Review, cleanup, Policy, authorization, Executor or Trash authority;
- change network containment, release, notarization, FDA/TCC or distribution
  claims.

The transport depends on `StornautLifecycle` only through its strict sending
contract. It cannot directly create the XPC client, spawn a process, open a
network connection or mutate the filesystem.

## 8. Next Gate

After this independent commit/push, Task 39B2b is the next checkpoint. It
receives a fresh scope/cost preflight and owns:

- helper-side authenticated interactive session state;
- the contained App Server worker under the fixed lifecycle topology;
- signed production diagnostic composition and Task 38 session driving;
- deterministic/synthetic composition fixtures.

Task 39B2b still cannot emit `signedInvestigationRuntimeReady`. Real model
execution, three-plane report assembly, adversarial failure matrix, teardown
and zero-residue machine admission remain exclusively Task 39B2c.
