# Phase D Task 37 Code Review and Completion Audit

> Status: Complete; implementation, focused regression, independent review,
> two complete capacity runs and one uninterrupted 23/23-stage authoritative
> `scripts/verify --full` passed.
>
> Date: 2026-08-16
>
> Baseline:
> `1ba874a2e9f23cfc43db5c2e2306e32e5e5dcb9c`
>
> Scope: Evidence Store v4, Investigation persistence, exact source rejoin,
> terminal/recovery truth, retention, paging, deletion and public-web
> provenance

## 1. Current Decision

Task 37 is complete. The implementation and authoritative evidence advance the
Evidence Store from schema v3 to v4 without weakening the existing Scan,
Cleanup, journal or Manifest contracts.

The performance optimization is effective on the measured machine:

- two independent complete Release benchmark runs each passed all five
  operations with three samples per operation, for `30/30` passing samples;
- the combined worst operation took `53.159062` seconds against the immutable
  `75`-second sample limit and retained `21.840938` seconds of margin;
- the combined worst kernel footprint increment was `210,944,240` bytes
  against `218,103,808`, retaining `7,159,568` bytes (about `6.8 MiB`) of
  margin;
- the two worst runtimes differed by only about `0.46` seconds;
- the ordinary serialized `744`-test suite skipped the explicit capacity
  benchmark and completed in `100.90` seconds wall time.

The memory margin is valid but intentionally described as narrow, not broad.
Future Store changes must preserve the explicit full-capacity benchmark and
may not relax its threshold, increase the 90-second operation deadline, pick
best-case samples, split the snapshot or reintroduce a partial-run bypass.

Production Deep Dive remains `.implementationUnavailable`, normal App
execution remains `writeDisabled`, and no Codex, Lifecycle, App, UI, Policy,
authorization or Executor path is added by this Task.

## 2. Delivered Boundary

Task 37 adds:

- Evidence Store schema v4 with ten `STRICT` Investigation tables, exact
  indexes, ownership constraints, quotas and immutable/delete triggers;
- direct v0/v1/v2/v3 migration coverage while preserving every existing Store
  domain;
- immutable Investigation sessions, complete typed source-row manifests,
  relevance tokens, targets, run-owned Plans, reports, evidence,
  degradations and budget events;
- Store-owned source recomputation and rejoin with pinned transaction,
  cancellation, deadline and typed stale/corrupt/expired/missing outcomes;
- atomic completed/partial terminal persistence and zero-report
  blocked/failed persistence;
- exact continuation replay, lineage, recovery and conflict handling;
- seven-day Investigation retention independent from the existing 90-day
  Cleanup Manifest contract;
- stable bounded paging, corrupt-sibling isolation and exact local-record
  deletion;
- strict public-HTTPS provenance normalization that rejects credentials,
  fragments, query leakage, local/private destinations and ambiguous legacy
  numeric IPv4 spellings;
- SQLite defensive mode through a repository-owned C shim plus a private
  deny-by-default authorizer and closed typed statement surface.

The C shim links the existing Apple system `libsqlite3`; it adds no package or
shipped third-party dependency. SQLite remains public-domain system
infrastructure under the previously accepted persistence study.

## 3. Tests-First and Correctness Evidence

The Task was implemented against focused migration, schema, rejoin,
terminal/recovery, retention/paging, provenance, performance and structural
tests. The final ordinary serialized SwiftPM regression passed:

```text
744 tests in 21 suites passed after 99.626 seconds
wall time 100.90 seconds
```

Evidence:

```text
/tmp/stornaut-task37-swift-serial-1786829450.log
SHA-256 2d5879c6e91350ac30da8a99afee44e79a26fa9ed7f439069d9bf2920fe0705f
```

That run explicitly reported the production Store capacity benchmark and its
isolated worker as skipped. This is required behavior: ordinary development
regressions prove the contracts without regenerating a roughly 1 GiB database
fifteen times.

The focused tests also cover:

- transaction rollback on failed v4 migration;
- future-version refusal and legacy record preservation;
- exact manifest row shape, ordinal, ownership and count checks;
- source drift, retention expiry and corrupt/missing source rejection;
- exact continuation replay only after current source rejoin;
- terminal report identity, equal replay and conflicting replay;
- quota, authorizer, cancellation, deadline, busy and quarantine behavior;
- query plans without temporary sorts;
- 23 adversarial public-web URL rejection cases;
- Cleanup History and Manifest retention independence.

## 4. Capacity and Performance Validation

### 4.1 Normative workload

The explicit Release benchmark uses:

- one maximum `300,002`-row / `256 MiB` canonical source;
- all five complete Store operations: insertion, rejoin, terminal,
  recovery and continuation;
- three serial process-isolated samples for each operation;
- `DELETE` journal, `FULL` synchronous mode and a two-second busy timeout;
- the same fixed source and terminal fixture bytes in both complete runs.

The fixture identities were:

```text
source SHA-256
19f7c63d2bb73a94cc1d9c12fd1739f192de31726b9f8105ca96122079c90f79

terminal SHA-256
e7936e86313e4b2e8756b8c27dd12ceff82446bf1d08efe55c232f7dd14d3578
```

The measured database sizes were:

| Operation family | Database bytes |
| --- | ---: |
| insertion / rejoin | 962,113,536 |
| terminal / recovery | 972,333,056 |
| continuation | 972,574,720 |

### 4.2 Two complete runs

| Complete run | Samples | Worst duration | Worst peak increment |
| --- | ---: | ---: | ---: |
| 1 | 15/15 | 52.694852167 s | 204,505,304 bytes |
| 2 | 15/15 | 53.159062 s | 210,944,240 bytes |
| Combined | 30/30 | 53.159062 s | 210,944,240 bytes |

Evidence:

```text
/tmp/stornaut-task37-capacity-formal-1786826132.log
SHA-256 ad3b76f99a6ec09a7e6d47a60bee97d6a0537d8aa9725734280558cae8ba3262

/tmp/stornaut-task37-capacity-final-1786828320.log
SHA-256 bf015e46b7ca0f31efb536aeaddcc627f1d9060833b5076600faf49d75f88913
```

Both runs were measured on `Mac15,7`, Apple M3 Pro, arm64, macOS 26.5.1
build `25F80`.

### 4.3 Why later Tasks do not inherit the prior delay

The accepted correction addresses both product performance and test-harness
self-blocking:

1. maximum source rows are streamed through compressed temporary staging and
   five typed families rather than retained as a complete object graph;
2. bulk `INSERT ... SELECT`, reduced indexes, `WITHOUT ROWID` staging and
   direct SQLite text-byte handling remove the previous row-by-row overhead;
3. each measured operation/sample runs in a fresh process, so
   `ledger_phys_footprint_peak` is not contaminated by earlier fixture work;
4. the worker invokes the already-built test bundle through
   `swiftpm-testing-helper`; it does not nest `swift test` under a parent
   SwiftPM process and therefore cannot wait on the parent's `.build` lock;
5. the formal gate has one explicit environment opt-in, always runs exactly
   `3 × 5 = 15` samples and has no smoke, insertion-only or best-case bypass;
6. ordinary focused, serialized and authoritative repository suites do not
   run this maximum Store benchmark;
7. `scripts/verify-contract` rejects future nested SwiftPM execution, sample
   reduction, partial-run flags, threshold drift or accidental routing into
   `scripts/verify`.

This makes the approximately 14–16 minute formal capacity measurement a
deliberate Task-boundary gate rather than a repeated cost inside every later
regression. It does not remove legitimate Xcode/XCUITest time from the
authoritative full verifier.

## 5. Review Findings and Repairs

The complete Task diff was reviewed for migration, transaction, authorizer,
source-rejoin, terminal/recovery, retention, privacy, quota and benchmark
routing risks. There are no unresolved P0–P2 findings.

Confirmed issues repaired during review:

1. exact continuation replay originally returned an existing child before
   checking current source drift; the Store now validates replay identity,
   performs a current Store-owned rejoin and only then returns the child;
2. exact continuation replay originally reused historical `planningAt` for
   retention, allowing a now-expired session to replay; current injected
   Store time now controls expiry;
3. a formal benchmark worker nested `swift test` and could self-block on the
   parent SwiftPM build lock; it now directly invokes the built test bundle;
4. lifetime peak memory was contaminated when multiple operations shared one
   process; every operation/sample now uses a fresh worker process;
5. whole-database hashing in the worker inflated the measured baseline by
   hundreds of MiB; fixed fixture hashes are verified and reported by the
   parent without polluting the operation measurement;
6. temporary smoke and insertion-only diagnostic paths could be mistaken for
   formal evidence; those bypasses were removed and contractually prohibited;
7. legacy Cleanup Store tests still asserted schema v3; they now prove the
   same records round-trip unchanged through schema v4;
8. the archived Phase C gate treated any uncommitted `Package.swift` change as
   dependency/license drift, even after exact package-graph boundary checks
   had approved the repository-owned `CSQLiteSupport` target. The gate now
   validates resolved package semantics: zero external package dependencies,
   exactly the reviewed Core target set, one repository-owned Clang shim,
   no binary target, and no lockfile/license-notice drift. The verifier
   contract rejects restoring the dirty-worktree proxy.

## 6. Task 35 Seal Preservation

Task 37 legitimately changes the shared Evidence Store, SQLite connection and
verifier contracts already bound by the sealed Task 35 receipt. Only the
changed source hashes for those files were updated. Receipt artifact identity,
observed outcome, limitations and all mutation evidence remain unchanged.

The current bindings are:

```text
Sources/StornautCore/Evidence/EvidenceStore.swift
110088295b425f946c9267fb8591af5d3e4a9ffed0fa31c6ea97d8308a34143b

Sources/StornautCore/Evidence/SQLiteConnection.swift
0aafad17a206c7eb906c38e8c7b0ba9b11d8ed7c87dc954ea4405579950de364

scripts/verify-contract
5e44b27dd9f1348a1a315edc847d1c742c27d233a9511419c2885231d0fe6f55

scripts/verify-cleanup-execution-boundaries
29fdfa7eebc06a7c0db28791eb62a6c4cb3d4b4fc2c87e4305b177b5bf70e329

scripts/verify-phase-c-gate
d3bdc60fed95c3474c1c3e5af1669f56984d6695e805441fdfd19567c6992bc1
```

The receipt/source verifier and contract pass without rerunning the sealed
Task 35 real Trash or recovery mutation.

## 7. Verification Status

Completed:

- focused Task 37 Store/migration/rejoin/performance/provenance tests;
- two complete formal Release capacity benchmark runs (`30/30`);
- Cleanup History and Store v3 compatibility regressions;
- ordinary serialized SwiftPM regression (`744/744`);
- Investigation structural boundary verifier;
- verifier contract and Task 35 receipt/source checks;
- protected Task 36 benchmark implementation and `scripts/verify` zero diff;
- independent complete-diff review with zero unresolved P0–P2;
- one uninterrupted authoritative `scripts/verify --full` with all `23/23`
  stages passing.

The first final full-verifier attempt passed XCUITest, SwiftPM regression and
both Investigation benchmarks, then failed at `source-boundaries` after
`680.62` seconds. The root cause was stale pre-Task-37 static verifier
contracts: six scripts still required `schemaVersion = 3`, and three
package-graph checks still required `StornautCore` to depend only on
`StornautProcessSupport`. They were migrated exactly to schema v4 and
`{"CSQLiteSupport", "StornautProcessSupport"}` without weakening Review,
Policy, Executor or Codex reachability rules. All fourteen source-boundary
scripts and the Rule Compiler gate passed after the repair.

Failed-attempt evidence:

```text
/tmp/stornaut-task37-verify-full-final-1786829863.log
SHA-256 f49109cad0db29f6b72b70da1d198aa3711e0ae654499d772388997d0057325a
```

The next full attempt passed the repaired source-boundary stage and every
earlier gate, then exposed a Release-only compile failure at
`debug-release-fixture-boundary`: the actor's test forwarding method referenced
a DEBUG-only SQLite authorization-probe type and method. The forwarding method
is now guarded by the same `#if DEBUG`; the focused authorizer test still
passes in Debug, and the standalone Debug/Release fixture boundary passes.

Second failed-attempt evidence:

```text
/tmp/stornaut-task37-verify-full-authoritative-1786830788.log
SHA-256 4bba35af5494c8d38d9e88511935a2cfc232e5dc3885e2e8fb92e022693a848c
```

The third full attempt passed every preceding stage, including XCUITest,
SwiftPM tests, Investigation benchmarks, all source boundaries, the
Debug/Release fixture build, Rule Compiler, verifier contract and docs/diff
hygiene. It failed after `892.27` seconds at the final Phase C product gate
because that archived gate used dirty `Package.swift` status as a proxy for
dependency review. The Task 37 repository-owned SQLite defensive-mode C shim
was therefore rejected despite the exact dependency graph and zero external
dependencies having already passed. The semantic package check described in
finding 8 now passes the complete Phase C product gate in `5.80` seconds.

Third failed-attempt evidence:

```text
/tmp/stornaut-task37-verify-full-authoritative-final-1786831818.log
SHA-256 33134a206eda2f9a9fe4db88c654e2d52fafc7d543a28297fca2fcae455df0e3
```

The final uninterrupted full verifier passed all `23/23` stages in `893.65`
seconds, including XCUITest, screenshot contract, ordinary SwiftPM tests,
the two Task 36 Investigation benchmarks, source boundaries, Debug/Release
fixture compilation, Phase C product semantics and the sealed signed-App
Trash receipt. The explicit Task 37 maximum Store capacity benchmark did not
run inside this ordinary full verifier, as required.

```text
/tmp/stornaut-task37-verify-full-authoritative-pass-1786832965.log
SHA-256 dffcb475920fbcb8b3c8fa8fa12ff132149edaed56d86d3d25f01a37b4a90bc0
23/23 stages passed
real 893.65 seconds
xcuitest 542.944 seconds
swiftpm-tests 59.160 seconds
investigation-benchmarks 33.202 seconds
debug-release-fixture-boundary 109.238 seconds
```

This timing confirms the optimization's routing effect: normal full
verification pays existing UI and release-boundary costs, but not the
approximately 14–16 minute `3 × 5` production Store capacity measurement.
That measurement remains an explicit Task-boundary gate protected by
`scripts/verify-contract`.

## 8. Scope Audit

Task 37 does not:

- launch real or fake Codex or call a model;
- add the `StornautInvestigation` coordinator;
- parse App Server events or compose a runtime;
- add lifecycle/proxy orchestration;
- add App dependencies, state, UI or availability;
- project Investigation evidence into Review;
- create Cleanup Plan, Policy, selection, authorization or execution;
- enable Trash, Registered Actions or permanent deletion;
- change release signing, notarization or distribution.

Task 38 is unblocked as the next implementation Task after the independent
Task 37 commit is pushed.
