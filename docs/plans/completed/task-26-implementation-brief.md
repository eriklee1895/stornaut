# Task 26 Implementation Brief — Phase B Evidence Gate and Handoff

> **Historical-brief notice (2026-08-11):** Deep Dive paused/no-go wording
> below records the Phase B gate at closure. Current Codex policy is the
> capability-first
> [ADR 0004](../../adr/0004-codex-file-read-isolation.md).

> 状态：Completed — product evidence、Automation Mode orchestration、UI
> stability fixes and the final unified verifier all passed
>
> 日期：2026-08-10
>
> 上位计划：[Epic 2–4 Deterministic Product Core](epic-2-4-deterministic-product-core.md)
>
> Study gate：Tasks 9–25 已完成的四份 Phase B upstream study、ADR
> 0007–0010 与逐 Task review；本 Task 不引入新的产品技术主题或依赖

## 1. Objective

Close Phase B only with current-machine evidence for the implemented
deterministic product path:

```text
ScanRequest
→ Surveyor
→ Evidence Store
→ built-in Rule Catalog
→ conservative Activity
→ deterministic Classification
→ Space Ledger
→ QuickScanProjection
```

Task 26 is complete only when:

- the anonymous domain, migration, retention, scanner, accounting, rule,
  activity, Local Knowledge, no-Codex and no-target-write regressions pass;
- one current Apple Silicon real-machine product-path scan records time to
  first useful progress, elapsed time, peak RSS, store size, counts, coverage
  gaps and ledger explanations;
- cancellation latency is measured separately without presenting a cancelled
  sample as the completed benchmark;
- the real App passes the unified verifier and read-only actual-window
  inspection in Light/Dark and English/`zh-Hans`;
- source, dependency and built-bundle audits find no Phase B scope leakage;
- all skipped or environment-dependent checks and proof limitations are named;
- ADRs 0007–0010, project routing docs and the validation report agree;
- the completed plan is moved out of `active/`, which is then intentionally
  left without executable work.

## 2. Gate Corrections

### 2.1 Product benchmark, not the Task 12 writer benchmark

The existing `SurveyorBenchmark` runs `ScanSessionWriter`. It proves bounded
Surveyor traversal and Evidence persistence, but it cannot report final
classification counts or Known/Unknown/Unmeasurable/Free, and therefore cannot
be used as the Phase B product-path gate.

Preserve the historical writer mode for regression. Add an explicit product
mode that runs the public production `QuickScanCoordinator(store:)` with the
checked-in 67-rule catalog and conservative native Activity provider. The
Phase B report must use product-mode output. It must not combine old Task 6 or
Task 12 numbers with new product claims.

### 2.2 One Primary Scan Root is an accepted Phase B limitation

The architecture sketch shows `roots: [URL]`, while the accepted implementation
has one `ScanRequest.rootURL`, one scope, one volume baseline and one ledger.
Task 25 correctly exposes this as one **Primary Scan Root** instead of a fake
multi-root control.

This does not block the Phase B evidence gate: the milestone promises a useful
read-only deterministic scanner, and one explicit root is real, safe and
testable. It is recorded as architecture drift and a Phase C planning input.
No report may claim multi-root or multi-ledger support.

### 2.3 FDA and target-write evidence remain bounded

The public macOS SDK does not provide a supported general FDA-state query.
Task 26 records the current packaged-App/CLI observations and real scan
coverage; it does not modify TCC or infer Full access from one readable path.

Real-root target-write evidence consists of:

- source/dependency audit proving Surveyor opens directories read-only and the
  product graph exposes no target mutation dependency;
- the existing real anonymous fixture before/after audit over path, type,
  identity, size, mtime and content;
- benchmark stores isolated under a temporary Stornaut-owned directory outside
  the selected target;
- an inert fake `codex` marker executable that must remain unlaunched.

This is behavioral plus structural evidence, not syscall-level tracing. The
report must state that limitation.

### 2.4 JSONL wording follows implementation

Raw Codex JSONL is bounded in memory and never persisted by the current
implementation. The unimplemented 24-hour crash-remnant SLA from the design
specification is not claimed as Phase B evidence. Deep Dive remains paused.

## 3. Files

Create:

```text
docs/plans/active/task-26-implementation-brief.md
Sources/StornautCore/Accounting/IncrementalSpaceLedger.swift
Sources/StornautCore/QuickScan/ProductScanAccumulator.swift
scripts/verify-phase-b-gate
scripts/verify-ui-automation-mode
docs/reports/epic-2-4-task-26-review.md
docs/reports/epic-2-4-validation-report.md
```

Modify:

```text
Benchmarks/SurveyorBenchmark/main.swift
Sources/StornautCore/Accounting/SpaceLedgerReconciler.swift
Sources/StornautCore/Domain/{DomainPrimitives,FileIdentity,ScanSession}.swift
Sources/StornautCore/Evidence/{EvidenceStore,SQLiteConnection}.swift
Sources/StornautCore/KnowledgeBase/RuleCatalogMatcher.swift
Sources/StornautCore/QuickScan/{QuickScanCoordinator,QuickScanState,ScanSessionWriter}.swift
Sources/StornautCore/ProbeBroker/ProbeBroker.swift
Sources/StornautCore/Surveyor/{DirectoryEntryDecoder,PathSnapshot}.swift
Sources/StornautCore/Surveyor/{ScanRequest,Surveyor}.swift
StornautApp/Scan/{ScanFlowState,ScanModel}.swift
StornautAppTests/{ScanFlowReducerTests,ScanModelTests}.swift
StornautAppUITests/StornautAppUITests.swift
Tests/StornautCodexTests/CodexProcessTests.swift
Tests/StornautCoreTests/{DomainContractTests,EvidenceStoreTests}.swift
Tests/StornautCoreTests/{QuickScanBoundaryTests,QuickScanIntegrationTests}.swift
Tests/StornautCoreTests/{QuickScanLifecycleTests,RegisteredActionTests,SurveyorTests}.swift
scripts/verify
docs/adr/0007-domain-persistence-boundary.md
docs/adr/0008-production-quick-scan-lifecycle.md
docs/adr/0009-space-accounting-semantics.md
docs/adr/0010-knowledge-activity-policy.md
README.md
AGENTS.md
docs/README.md
docs/reports/README.md
docs/agent/coding-agent-handoff.md
docs/agent/ui-testing-guide.md
docs/plans/roadmap.md
docs/plans/active/README.md
docs/plans/active/epic-2-4-deterministic-product-core.md
```

The larger-than-initial write set is evidence-driven, not a product-scope
expansion. The first product-mode Home run exposed unbounded projection,
stream-overflow, incomplete terminal aggregates, persistence scaling and App
summary defects. Each implementation change above is tied to a failing
contract, measured gate or confirmed review finding.

After all gates pass, move the Epic plan and Task 21–26 implementation briefs
together to `docs/plans/completed/`. Completed briefs must not remain as
apparent active instructions.

## 4. Machine-Readable Product Benchmark

Add an explicit CLI selection:

```text
--pipeline writer
--pipeline product
```

`writer` preserves the current schema-2 output and historical synthetic
invariants. `product` emits a versioned aggregate report containing:

- sanitized root description and launch context;
- OS/build, architecture, model and physical memory;
- bounded worker/queue/stream/batch configuration;
- volume capacity/free baseline source kinds;
- entry kind and measurement-status counts;
- classification count and all four disposition counts;
- evidence, product issue and corrupt-record counts;
- completed/unfinished scope counts and typed unfinished reasons;
- ledger status, exact Known/Unknown/Free bytes when measurable,
  Unmeasurable status/bytes, `unknownIncludesUnmeasurable`, owner/gap/caveat
  counts and formula/explanation keys;
- first useful progress, elapsed time, throughput, peak RSS and store bytes;
- terminal state and cancellation latency;
- whether the caller-provided Codex marker appeared.

The output contains no scanned relative/absolute paths, user content, Git
output, process names or raw SQLite rows.

Product-mode acceptance fails when:

- elapsed time is at least five minutes or peak RSS exceeds 256 MiB;
- no durable store or no terminal projection exists;
- a non-cancelled run has no ledger or first useful progress;
- classification/snapshot/count invariants disagree;
- a completed projection contains product issues, corrupt rows or unfinished
  scopes;
- ledger formulas/explanations are absent;
- the Codex marker exists.

Partial real scans caused by permission, mount or race gaps are accepted only
when every gap remains explicit and the ledger does not invent Unmeasurable
bytes. Cancellation is accepted only with a persisted Cancelled terminal and
latency below one second.

## 5. Tests First

Before implementing product mode, `scripts/verify-phase-b-gate` must fail
because the benchmark lacks the new CLI/report contract. After implementation
it must:

1. build the benchmark once;
2. run a synthetic product benchmark;
3. validate report schema, product pipeline, exact fixture entry count,
   non-empty classifications, all disposition keys, ledger formula keys,
   store bytes, terminal truth and absent Codex marker;
4. run a separate synthetic product cancellation sample and validate
   Cancelled plus sub-second latency;
5. run domain/migration/retention, Surveyor, accounting, rule/activity,
   Local Knowledge and Quick Scan focused suites;
6. run every Phase B source-boundary script;
7. audit source/package declarations for Phase B leakage.

The final `scripts/verify` remains the single complete repository verifier. It
must invoke `scripts/verify-phase-b-gate` after the read-only Automation Mode
preflight so one successful command covers the product benchmark contract as
well as App/UI acceptance. A standalone focused pass is supporting evidence,
not a substitute. Xcode App contracts, XCUITest/screenshots, signed bundle
identity and Debug-to-Release fixture isolation remain owned by that unified
verifier and must not be inferred from the source-only focused gate.

Before any build or test, the unified verifier runs the read-only
`scripts/verify-ui-automation-mode --allow-auth-prompt` preflight. Its
self-test covers lowercase and uppercase Apple status variants,
authentication-free CI/lab state, authentication-required developer-host
state, contradictory output and unknown output. Contradictory, unknown or
trailing output fails closed. The default standalone mode still rejects
`disabled + requires authentication`; the explicit unified mode accepts only
that exact state and requires XCUITest to be the immediate next external
command so Apple's standard prompt remains attached to a live runner. The
preflight invokes only `/usr/bin/automationmodetool`; a marker regression
proves a `PATH`-shadowed executable is never launched. It never calls an
enable/disable command.

## 6. Real-Machine Run

Use the built benchmark binary, not repeated `swift run` builds, and keep raw
JSON outside the repository. Run:

1. one product scan of the current user's explicitly permitted Home scope;
2. one separate product cancellation sample on the same scope;
3. optional writer-mode regression only as supporting scanner evidence.

Prepend a temporary directory containing an inert fake executable named
`codex`; its marker path is outside the target and passed to the benchmark.
Record only aggregate output in the report. Do not commit private paths, raw
directory names, user content or the local benchmark database.

If product mode exceeds five minutes, lacks a ledger or produces unexplained
accounting, stop the gate and update ADR/plan. Do not authorize Rust or replace
the result with the old writer benchmark.

## 7. App, UI and Scope Acceptance

Run:

```text
scripts/verify-phase-b-gate
scripts/verify
```

Then launch the signed Debug App and use only
`scripts/peekaboo-readonly` for actual-window inspection. XCUITest owns all
interaction. Confirm:

- Overview, Scan, History and all six Settings sections remain useful with
  Codex unavailable/paused;
- limited access remains Partial/Unmeasurable, never `0 B`;
- English/`zh-Hans` and Light/Dark have no raw localization keys;
- Investigations remains a truthful paused placeholder;
- Settings remains an independent window.

Audit product sources, package graph and the built App for:

- Quick Scan → Codex/Probe/Adapter/Policy/Executor/cleanup reachability;
- target mutation or arbitrary executable/argument surfaces;
- enabled Trash or Registered Action flows;
- raw controlled-content/JSONL persistence;
- telemetry, networking, remote rules, MenuBar, background tasks, schedulers or
  login items;
- external packages, copied upstream code and notice/license drift;
- Debug fixture leakage into Release.

## 8. Gate Decisions and Lifecycle

The final report makes separate decisions for:

1. deterministic domain/persistence;
2. production Quick Scan;
3. accounting explainability;
4. Knowledge/Activity safety;
5. App/UI readiness for Phase C planning;
6. Deep Dive — remains no-go/paused;
7. release/distribution — remains not evaluated.

Only after the report, final review and unified verifier pass:

- check all Task 26 boxes;
- set the Epic plan to Completed and move it plus Task 21–26 briefs to
  `plans/completed/`;
- leave `plans/active/README.md` with no executable active plan;
- update the roadmap and handoff;
- commit and push the Phase B closure;
- propose, but do not silently start, a separate Phase C deterministic Epic 8
  plan.

The gate may close Phase B while recording one-root architecture drift,
packaged-App FDA uncertainty and syscall-audit limitations. It may not hide
failed tests, unmeasured release work or the Deep Dive no-go.

## 9. Completion Evidence

The final current-source `scripts/verify` run completed on 2026-08-11 with
exit code `0`. One uninterrupted command covered:

- read-only Automation Mode classification followed immediately by XCUITest;
- 9/9 XCUITest methods and 17/17 screenshot attachments/contracts;
- the synthetic product and cancellation benchmark contracts;
- two complete 279-test SwiftPM functional/security pools, with the same three
  opt-in diagnostics explicitly skipped;
- three isolated catalog matcher performance gates;
- all Quick Scan, App-state, Overview, Scan, History, Settings, activity and
  rule-source boundary scripts;
- Xcode App contract tests, signed Debug App, bundle identity, catalog
  identity and Debug-to-Release fixture isolation;
- English/`zh-Hans` localization parity, rule compiler, Markdown links and
  `git diff --check`.

The final UI stabilization did not change product behavior. It corrected two
XCUITest assumptions exposed only under complete-suite host load:

1. a Settings scene may briefly render the requested initial page and then
   restore a previous section; tests now explicitly click the current
   hittable sidebar item and wait for the requested page;
2. an unrelated crashing App window can trigger XCUITest's interruption
   monitor and swallow a click whose only effect is to present a confirmation
   dialog; tests now retry that pre-confirmation click once, only while the
   dialog is absent and the action remains hittable.

The second recovery path passed five independent-process repetitions,
including one run that still recorded the external Chrome crash warning. A
fresh complete UI suite then passed 9/9 before the final unified verifier.

Phase B closes with Deep Dive still `no-go/paused`, one Primary Scan Root as
the explicit product contract, release/distribution unassessed, and no enabled
Review, Trash or Registered Action product flow. Phase C work is not
authorized by this completion record; its deterministic Epic 8 plan requires
separate user review and approval before implementation.
