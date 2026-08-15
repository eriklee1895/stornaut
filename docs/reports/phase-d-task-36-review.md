# Phase D Task 36 Code Review and Completion Audit

> Status: Complete; performance optimization confirmed, independent review
> clean and authoritative full verifier passed
>
> Date: 2026-08-15
>
> Baseline:
> `86ee2aa9428cfc71036e18dcb2c1349ec248ec73`
>
> Scope: Investigation canonical domain, source projection, Candidate Planner,
> budget ledger, stop semantics and non-executing Core boundary

## 1. Current Decision

Task 36 is complete. The checked implementation provides the deterministic
planning foundation for Phase D without launching Codex, calling a model,
migrating the Evidence Store, changing App availability or creating cleanup
authority.

The maximum source-projection workload is no longer an iteration blocker. Its
continuous worst observed runtime is `22.540198084` seconds against the
`60`-second contract, and its worst kernel high-water increment is
`100,958,328` bytes against the `218,103,808`-byte contract. One uninterrupted
authoritative `scripts/verify --full` completed with exit `0`.

Production Deep Dive remains `.implementationUnavailable`. Task 37 is now the
current sequential Task and owns Store v4, persistence, retention and source
rejoin.

## 2. Delivered Boundary

Task 36 adds:

- closed Investigation IDs, v2 targets, Plan, fixed-point priority and exact
  deterministic target ordering;
- duplicate-aware strict JSON auditing with exact signed 64-bit integer
  lexical validation;
- a normative canonical binary codec and six product vectors;
- a two-pass, Store-neutral source projection with exhaustive manifest
  emission, exact source fingerprinting and bounded raw-row decoding;
- a deterministic Candidate Planner with bounded diagnostics;
- closed budget presets, hard reservations, observed-usage accounting and
  replay/conflict handling;
- pure stop evaluation with explicit precedence;
- a structural Investigation no-Executor verifier.

The implementation does not import or expose Policy, authorization, Trash,
Registered Actions, cleanup execution, App runtime or Codex process
composition.

## 3. Tests-First and Contract Evidence

The Task was built from focused domain, canonical, source-projection, planner,
budget, stop and specification contracts. The final test surface includes:

- strict decode/re-encode and integer/duplicate-key rejection;
- canonical binary vectors and fingerprint stability;
- source-row count, order, payload, freshness and drift rejection;
- raw binary bounds before allocation;
- deterministic planner ordering under shuffled input;
- priority overflow and target-cap behavior;
- token cumulative/replay/conflict accounting;
- reservation, deadline, cancellation and stop-precedence semantics;
- structural no-Executor and verifier-topology contracts.

The ordinary serialized SwiftPM suite passed `708` tests in `63.746` seconds
(`64.50` seconds wall time) while correctly excluding the two isolated
Investigation benchmarks.

## 4. Performance Optimization Validation

### 4.1 Maximum source projection

The normative source benchmark contains:

- `300,002` complete source rows;
- `100,000` snapshots;
- `100,000` classifications;
- `100,000` evidence records;
- exactly `268,435,456` payload bytes.

Three consecutive independent serial runs produced:

| Run | Duration | Kernel peak increment |
| --- | ---: | ---: |
| 1 | 22.513547209 s | 100,827,256 bytes |
| 2 | 22.540198084 s | 88,359,032 bytes |
| 3 | 22.479527791 s | 100,958,328 bytes |

The continuous worst case uses `37.6%` of the time limit and `46.3%` of the
memory limit. The measurement uses
`TASK_VM_INFO.ledger_phys_footprint_peak`, not a final-RSS approximation or a
selected best run.

Evidence:

```text
/tmp/stornaut_task36_perf_final_1786811588/source-1.log
SHA-256 34413585b19844d94b6b793845087eeb3b8ccbb09cf801579f6535c1303d86c0

/tmp/stornaut_task36_perf_final_1786811588/source-2.log
SHA-256 d3992cdead9ec9b4b70d67492d1d43360aaf9acd073e2db319eccaa6bb690ab7

/tmp/stornaut_task36_perf_final_1786811588/source-3.log
SHA-256 41e4e1d4ad4f4dbad0ba60d3779ce8a2e2acbca3ba2685d98e7fa8c16f6a16a9
```

### 4.2 Candidate Planner

The focused `100,002`-row Candidate Planner benchmark completed in
`8.527847875` seconds against its `20`-second limit:

```text
/tmp/stornaut_task36_perf_final_1786811588/candidate.log
SHA-256 f00e5622a8b04e8c36746bcfcd8f32657dbc912a2a4099214cc549d56efa9bb5
```

### 4.3 Why the improvement is durable

The accepted optimization is structural rather than a relaxed threshold:

1. source projection uses two bounded cursor passes instead of retaining the
   complete canonical source;
2. the hot manifest path uses a dedicated pre-sized binary writer;
3. raw constructor and decoder limits reject oversized lengths before
   allocation;
4. Planner and all constructors/decoders share one exact ordering rule;
5. the two maximum benchmarks are excluded exactly once from ordinary
   parallel and serialized suites;
6. full verification runs each benchmark exactly once in its own serial
   process;
7. `scripts/verify-contract` rejects topology drift, duplicate benchmark
   execution and background execution.

Two attempted generic-writer substitutions regressed the same workload to
approximately `82.2` and `66.8` seconds and were rejected. The final design
therefore keeps the measured specialized path rather than generalizing away
the performance proof.

This prevents the Task 36 maximum fixture from multiplying ordinary suite
runtime in later Tasks. It does not claim that the entire full verifier is
short: the final full run still spent `539.329` seconds in XCUITest and
`104.866` seconds in the Debug/Release fixture boundary. Those are retained
authoritative product gates, while normal development should continue to use
focused tests first and run the full gate once after review closure.

Task 37 additionally requires its Release maximum-size Store benchmark before
implementation admission. That front-loads the next high-risk capacity check
instead of discovering an infeasible Store design after the implementation is
complete.

## 5. Task 35 Seal Preservation

The first full verifier reached its final stage and failed after `884.40`
seconds because Task 36 had legitimately changed `scripts/verify`:

```text
Task 35 safety-critical source binding drifted: scripts/verify
```

Removing the two top-level verifier hashes from the Task 35 receipt was
considered and independently rejected as P1 because it would weaken the
future non-mutation guarantee. The final correction instead:

- keeps exact receipt hashes for `scripts/verify` and
  `scripts/verify-contract`;
- runs the Task 35 receipt/source preflight before any build or test step;
- fails immediately on future orchestration drift;
- keeps both Task 35 mutation scripts sealed;
- retains exact bindings for the dedicated receipt verifier, Phase C gate and
  all mutation-critical sources.

The post-fix focused review found no recursion, circular hash or fail-open
path and reported zero unresolved P0–P2.

## 6. Independent Review

The final complete Task 36 diff review reported zero unresolved P0–P2:

```text
/tmp/stornaut_task36_final_review_1786811129/codex-review-final.txt
SHA-256 3f4707b246e0c9c55d0e32203754a8271243146384c3a22709a43077e2d977f8
```

The initial Task 35 receipt-focused review found the P1 described above:

```text
/tmp/stornaut_task36_receipt_review_1786812794/codex-review-final.txt
SHA-256 0bd7cd1373c0b7afb57c71cc9b5645092edae0d9416f3ac932b360cc9d572f13
```

The final receipt post-fix review closed it and reported zero unresolved
P0–P2:

```text
/tmp/stornaut_task36_receipt_postfix_review_1786813243/codex-review-final.txt
SHA-256 6c247ff3ad1d6f709f30307cee1fc440fe57097c1a94977a26ef7d7fcf79945a
```

## 7. Authoritative Verification

The final uninterrupted command was:

```text
scripts/verify --full
```

Observed Task 36 performance inside that complete environment:

| Contract | Observed |
| --- | ---: |
| maximum source projection | 22.708510208 s / 88,424,568-byte peak increment |
| Candidate Planner | 8.619682459 s |

The complete verifier passed all `23` ordered stages:

```text
Phase C signed Trash checked receipt and source binding passed
Phase C signed-App Trash receipt verification passed
Verification passed in full mode.
real 875.36
```

Evidence:

```text
/tmp/stornaut_task36_perf_final_1786811588/verify-full-final.log
SHA-256 fdddf00a0cf12e2d20c61ec207f2dd982b890140081b3e7178a03e82be923da1
```

No Task 35 Trash or recovery mutation was rerun.

## 8. Scope Audit

Task 36 does not:

- launch Codex or call a model;
- parse App Server events;
- migrate or write the Evidence Store;
- add App dependencies, state, UI or availability;
- create runtime/proxy/lifecycle composition;
- project an Investigation report into Review;
- create a Cleanup Plan, Policy, authorization or execution path;
- enable Trash, Registered Actions or permanent deletion;
- change release signing, notarization or distribution.

The result is a deterministic, non-executing Phase D foundation. Task 37 may
persist this truth, but production Deep Dive remains unavailable until Task 44
passes its own normal-product admission gate.
