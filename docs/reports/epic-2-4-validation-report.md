# Epic 2–4 Deterministic Product Core Validation Report

> **Historical-scope notice (2026-08-11):** Deep Dive no-go/paused references
> below record what Phase B did not ship. Current Codex policy is the
> capability-first
> [ADR 0004](../adr/0004-codex-file-read-isolation.md); production Deep Dive now
> waits for that profile's runtime evidence rather than Broker-only enforcement.

> 状态：Passed — final unified verifier exited 0 and Phase B gates are closed
>
> 日期：2026-08-11
>
> 范围：Epic 2–4 Tasks 9–26
>
> 验证对象：Task 26 product benchmark、focused gate、App contract、真实窗口、
> unified verifier 与范围审计

## 1. Executive Decision

**Phase B deterministic product evidence is complete. The final
current-source unified verifier exited `0`, so Epic 2–4 Tasks 9–26 may be
archived as the completed Deterministic Product Core milestone.**

Stornaut may now prepare a separate Phase C plan for the deterministic Epic 8
subset:

```text
Quick Scan
→ Review Reclaim Plan
→ Policy Gate
→ fresh revalidation
→ MoveToTrash
→ Cleanup Manifest
→ Cleanup Result / History
```

This decision means:

- domain and local persistence contracts are suitable for the next
  deterministic slice;
- the production Quick Scan path remains useful without Codex;
- Known, Unknown, Unmeasurable and Free remain distinct and explainable;
- the built-in Knowledge/Activity path fails conservative;
- the current App/Overview/Scan/History/Settings surfaces can accept Phase C
  planning;
- Phase C implementation remains blocked until that detailed plan is reviewed
  and explicitly approved by the user.

It does **not** mean:

- Deep Dive may start — it remains `no-go/paused`;
- the product supports multiple simultaneous roots or ledgers — it supports one
  explicit Primary Scan Root;
- release signing, hardened runtime, notarization or packaged-App FDA coverage
  is ready — release/distribution remains not evaluated;
- the Task 26 source/behavioral target-write audit is equivalent to syscall
  tracing;
- raw Codex JSONL has a 24-hour crash-remnant implementation — current code
  keeps it bounded in memory and never persists it.

## 2. Validated Environment

| Item | Observed value |
| --- | --- |
| macOS | 26.5.1, build `25F80` |
| Architecture | Apple Silicon `arm64` |
| Hardware model | `Mac15,7` |
| Physical memory | 36 GiB |
| Xcode | 26.6, build `17F113` |
| Swift | Apple Swift 6.3.3 |
| Volume capacity | 494,384,795,648 bytes, 460.43 GiB |
| App identity | `com.eriklee.stornaut` |
| Runtime catalog | 67 rules |
| Catalog SHA-256 | `133b3829816fa951f03cb87473e03454c3e561b421c83e6c8efaf8ad89849e99` |
| Package dependencies | no external Swift package dependencies |

Observed versions describe this machine and run. They are evidence, not a
permanent version contract.

## 3. Functional and Safety Gate

`scripts/verify-phase-b-gate` passed after the Task 26 performance,
projection, Automation Mode parser and unified-ownership fixes. The latest
current-source run completed on 2026-08-11 after the ownership correction:

- 279/279 SwiftPM functional/security tests passed after the ASan fix;
- three opt-in, environment-dependent diagnostics remained explicitly skipped:
  installed Codex capability, real Codex static-envelope process, and platform
  Trash lifecycle;
- anonymous synthetic product mode reported the exact 1,356-entry typed
  aggregate: 804 regular files, 551 directories, one symlink, zero issues and
  68,167,269 logical bytes;
- separate synthetic cancellation persisted `Cancelled` with sub-second
  latency;
- Surveyor backpressure, abandoned-consumer exit, cancellation, persistence
  batch and target-read-only regressions passed;
- eleven directory/concurrency-critical Surveyor/Quick Scan/Probe tests passed
  under Thread Sanitizer in an isolated scratch build: variable records,
  errno-aware directory failure, bounded queue/stream, abandoned consumer,
  product backpressure, concurrent intent and retained cancellation truth;
- eleven raw-pointer/integer/accounting/paging/terminal tests passed under
  Undefined Behavior Sanitizer in an isolated scratch build;
- migration, rollback, future-schema, corruption, retention and clear-boundary
  regressions passed;
- accounting overlap, hard-link, sparse, permission, mount, drift and
  disposition-independence fixtures passed;
- compiler, provenance, overlay, protected/veto, Activity and Local Knowledge
  boundaries passed;
- all Phase B source-boundary scripts passed;
- the complete catalog regenerated with the expected hash;
- the Automation Mode parser accepted supported lowercase/uppercase enabled
  and authentication-free forms, while authentication-required,
  contradictory and unknown forms failed closed.

One P0 and sixteen P1 defects found across the final gate and post-gate review
were fixed before acceptance:

1. App `Measured` bytes now consume the full persisted `ScanAggregate`, not a
   bounded display page.
2. product benchmark schema v3 consumes the terminal aggregate instead of
   reconstructing counts from a non-terminal progress sample.
3. terminal disposition summary now consumes full closed counts while active
   progressive state continues to count only arrived facts.
4. the 100-row terminal/restart projection is candidate-first, then fills any
   remaining capacity with auxiliary display facts; classified candidates are
   no longer displaced by arbitrary path order.
5. App disposition counts exclude the internal root owner and reconcile to the
   product candidate count.
6. projection construction and decode reject impossible aggregate,
   classification and disposition relations.
7. typed count constructors and decoders use checked sums and cannot bypass
   closed validation through malformed JSON.
8. the Automation Mode preflight normalizes documented case variants and
   fails closed on contradictory mode/policy or unknown output.
9. the preflight invokes only Apple's `/usr/bin/automationmodetool`, accepts
   exactly the known two-line status protocol and proves a `PATH` shadow is
   never launched.
10. Surveyor and Probe Broker now decode variable-length Darwin `dirent`
    records through a shared raw-pointer helper bounded by `d_reclen` and
    `d_namlen`; the full 279-test non-performance functional/security suite
    passes under Address Sanitizer without the original heap-buffer-overflow.
11. Surveyor now distinguishes normal `readdir` EOF from nonzero `errno`;
    malformed names, invalid UTF-8 and injected EIO fail closed, and Quick Scan
    persists `failed/scannerFailure` rather than false Completed truth.
12. the unified verifier now invokes `scripts/verify-phase-b-gate` immediately
    after its read-only host preflight, so a single green `scripts/verify`
    cannot omit the product/cancel schema and fake-Codex-marker acceptance.
13. four process-lifecycle tests now separate fixture readiness/safety budgets
    from the product timeout or cancellation behavior they assert; focused,
    ten-round stress and complete 279-test pool verification pass without
    weakening timeout, cancellation or process-group cleanup expectations.
14. standard user-authenticated Automation Mode is no longer treated as a
    durable host toggle: the unified verifier accepts only the exact
    authentication-required developer state and starts XCUITest immediately,
    while standalone preflight, unknown/contradictory/trailing states and
    PATH-shadow attempts still fail closed.
15. the App bounded-row fixture now gives its 1,000 full classifications a
    truthful 10,000-item full snapshot count instead of violating the closed
    projection relation; the exact test and all 97 App contracts pass.
16. Settings UI tests no longer trust a transient initial page marker that can
    be replaced by macOS scene restoration; each request clicks the current
    hittable sidebar item and waits for the requested page. The affected
    Settings pair passed 3/3 independent-process repetitions.
17. an unrelated crashing App window could trigger XCUITest interruption
    handling and swallow a click whose only effect was to present a
    confirmation dialog. The test now retries that pre-confirmation click once
    only while the dialog is absent and the action remains hittable. It passed
    5/5 independent-process repetitions, including one repetition that still
    recorded the external Chrome crash warning.

## 4. Real-Machine Product Benchmark

### 4.1 Method

The final run used the built `SurveyorBenchmark` binary in explicit
`--pipeline product` mode:

- target: current-user Home, reported only as `current-user-home`;
- store: uniquely named Stornaut-owned temporary Application Support/Caches
  roots outside the target;
- runtime graph: public `QuickScanCoordinator(store:)`, built-in 67-rule
  catalog and native conservative Activity provider;
- fake `codex` executable: prepended to `PATH`, with an inert marker outside
  the target;
- complete-run watchdog: 330 seconds;
- acceptance thresholds: elapsed below 300 seconds, peak RSS at or below
  256 MiB, non-empty durable store and ledger, no Codex marker;
- raw JSON and benchmark SQLite files: kept outside the repository and removed
  after extracting aggregate evidence.

The measured binary remains byte-identical to the current product-source
build:

| Provenance item | SHA-256 |
| --- | --- |
| 51-file full product-source manifest | `6be52845a58b9b7ed2a0f5c304b544d4e32a668f25742733a24131dba6fe193c` |
| `.build/debug/SurveyorBenchmark` | `b938c231f0660098758f365a708d9be2d6f6efe7d0293087c855a08554d0b558` |

The source manifest is the SHA-256 of a stable ordered file containing each
participating source path and its individual SHA-256. It covers `Package.swift`,
the benchmark, all 48 current StornautCore Swift sources and the immutable
runtime catalog. Both values were recomputed after the ASan/errno fixes and
match the binary used for the current-machine results below.

### 4.2 Complete product run

| Measure | Observed |
| --- | ---: |
| Terminal state | `partial` |
| Entries | 3,107,607 |
| Regular files | 2,694,157 |
| Directories | 365,862 |
| Symbolic links | 47,399 |
| Inaccessible entries | 132 |
| Other entries | 57 |
| Permission gaps | 132 |
| Product issues / corrupt records | 0 / 0 |
| Directory read failures | 0 |
| Classifications | 4,261 |
| Protected / Unknown | 1,223 / 3,038 |
| Ready / Review | 0 / 0 |
| Typed Activity evidence | 9,463 |
| First useful progress | 26.42 ms |
| Elapsed | 247.24 s |
| Throughput | 12,568.95 entries/s |
| Peak RSS | 73,220,096 bytes, 69.83 MiB |
| Evidence Store | 20,795,392 bytes, 19.83 MiB |
| Logical regular-file bytes | 729,604,527,933 |
| Allocated regular-file bytes | 233,067,016,192 |
| Codex marker | absent |

The partial result is expected and accepted because 132 paths were not
measurable. The run did not turn those paths into `0 B`, did not report
completion, and did not invent an Unmeasurable byte total.

### 4.3 Space Ledger

| Measure | Status | Bytes |
| --- | --- | ---: |
| Volume capacity | measured | 494,384,795,648 |
| Free at start | measured | 52,196,851,712 |
| Free at end | measured | 52,115,566,592 |
| Known | measured | 58,006,814,720 |
| Unknown volume residual | measured | 384,262,414,336 |
| Unmeasurable | unmeasurable | unavailable |
| Observed unclassified diagnostic | measured | 10,575,872 |

The ledger contains 4,261 non-overlapping owner projections and 132 coverage
gaps. `unknownIncludesUnmeasurable=true`: Unknown already contains the volume
residual, so UI must not add Unmeasurable as a second byte amount. Caveats
record sparse files, hard-link deduplication/ambiguity, clone/compression,
purgeable space and live-volume drift.

An independent arithmetic audit confirms:

- all five path-kind counts and all measurement-status counts each sum to
  3,107,607;
- all four disposition counts sum to 4,261 classifications;
- `Known + Unknown + Free = 494,384,795,648`, exactly the measured capacity,
  with Unmeasurable remaining status-only and non-additive;
- elapsed time, RSS, store and cancellation latency satisfy their hard gates.

### 4.4 Cancellation sample

| Measure | Observed |
| --- | ---: |
| Requested after | 100 ms |
| Terminal state | `cancelled` |
| Entries retained | 1,256 |
| First useful progress | 26.79 ms |
| Total elapsed | 110.20 ms |
| Cancellation response | 1.82 ms |
| Peak RSS | 21,086,208 bytes |
| Store | 122,880 bytes |
| Final ledger | absent |
| Codex marker | absent |

This is a separate cancellation sample. It is not used as the completed
performance result.

## 5. App and UI Acceptance

### Passed

- XcodeBuildMCP built and launched the current Debug arm64 App with no build
  diagnostics.
- `scripts/verify-ui-runtime` captured a real Overview window by returned PID;
  the PNG was 2,360 × 1,520 with non-uniform luminance.
- read-only Peekaboo `see` captured four actual Overview windows:
  English Light/Dark and `zh-Hans` Light/Dark;
- the four captures contained 237/237/237/240 accessibility objects;
- approved Overview, Quick Scan, Space Ledger, Safety Paused, Unknown and
  Unmeasurable wording appeared in both languages;
- no raw localization key appeared in visible AX labels;
- Light windows had mean luminance about 244, Dark about 50, and all captures
  had non-blank variance;
- permission-limited `zh-Hans` remained Partial/Unmeasurable rather than
  reporting `0 B`;
- Investigations remained a safety-paused placeholder and no Review/Trash or
  Codex investigation button became enabled.
- an independent current-source App gate also passed Debug arm64 build, local
  ad-hoc signing, designated-requirement/entitlement/bundle/catalog audit,
  Debug-to-Release fixture isolation and English/`zh-Hans` localization parity.
- an isolated SwiftPM `-warnings-as-errors` build passed in `12.86 s`;
- an isolated Xcode `build-for-testing` for the App, App tests and UI-test
  runner passed with `SUPPRESS_WARNINGS=NO` and Swift/Clang warnings treated as
  errors. It compiled test products but executed no test and did not require
  Automation Mode.

Peekaboo was used through `scripts/peekaboo-readonly`; no click, type, hotkey,
window mutation or AI analysis tool was used.

The first Xcode strict-build attempt combined Xcode's package-target
`-suppress-warnings` with `-warnings-as-errors` and stopped on conflicting
driver options before source compilation. It is recorded as a diagnostic
harness configuration failure, not a product build failure. The corrected
isolated attempt explicitly disabled suppression and passed.

An attempted no-run test enumeration first omitted Xcode's required
`test-without-building` action and failed with command-contract error 66. After
the action was corrected, Xcode 26 still entered test-execution orchestration
and waited instead of emitting a JSON inventory. No UI runner appeared and the
existing authentication window did not change; the Coding Agent interrupted
only its own `xcodebuild` process before it could layer another request, then
removed the 350 MiB temporary DerivedData. This path is not counted as method
coverage. The later final verifier proved all nine XCUITest methods by actual
execution.

### Historical host-blocked UI automation

Two UI-only XCUITest attempts stopped before any test method:

```text
The test runner failed to initialize for UI testing.
Timed out while enabling automation mode.
```

Read-only diagnosis showed:

- active display: yes;
- Screen Recording: granted;
- `automationmodetool`: Automation Mode disabled, user authentication required;
- one `com.apple.LocalAuthentication.UIAgent` authentication window.

The Coding Agent did not authenticate, modify Automation Mode policy, restart
the root writer daemon, change TCC/SIP, or interact with the authentication
window. Those attempts were **host blocked**, not passed or failed product
assertions. The user later completed the standard authentication and the final
unified verifier passed.

The final review added `scripts/verify-ui-automation-mode`, a read-only
fail-fast readiness gate at the beginning of `scripts/verify`. Its parser
self-test covers lowercase/uppercase enabled output, authentication-free
CI/lab output, authentication-required developer-host output, contradictory
mode/policy output and unknown output. Contradictory and unknown states fail
closed. It accepts exactly two known status lines, invokes the Apple tool by
absolute `/usr/bin` path and includes a marker regression proving that a
`PATH`-shadowed executable is not launched. On this host it now exits in under
five seconds before any build/test begins, instead of allowing Xcode to hang
while waiting for the same user authentication. It invokes no mutating
Automation Mode command.

A current-source integration probe ran `scripts/verify` while the host remained
authentication-required. It exited `1` in `0.026 s`; `.build` and
`.derivedData` mtimes were unchanged, and the count of Swift/Xcode/UI-test
processes remained zero before and after. This proves the guard is first in the
real verifier, but the intentional fail-fast run is not counted as unified
acceptance.

One isolated UI-only authentication probe was then run to refresh the standard
XCTest request; it was not counted as the unified verifier. The runner never
entered a test method and timed out after `704.704 s` with
`The test runner hung before establishing connection`. The `.xcresult` reported
one runner-level failure, zero passed tests and no method-level result. After
the runner and `xcodebuild` exited, read-only window inventory still showed the
same on-screen `XCTest` LocalAuthentication window while
`automationmodetool` remained disabled. This proves the authentication UI can
outlive the requesting runner; the visible window is not evidence that a test
is still active or that authentication succeeded.

The probe's temporary DerivedData and failed `.xcresult` were removed. No
second request was layered over the residual window. The subsequent complete
`scripts/verify` exit `0` is the accepted gate evidence.

The user later completed the standard Automation Mode authentication. The
first strengthened unified run then entered its initial 279-test pool and
failed four process-lifecycle tests before any Xcode/App test:

- two normal/partial Registered Action fixtures exhausted a two-second test
  budget under host scheduling load and were misreported as product timeout;
- the 100 ms Registered Action timeout behaved correctly, but its test also
  required total wall time below two seconds and observed 3.11 seconds under
  the same pool load;
- the Codex consumer-cancellation test gave both child-readiness and the
  request safety timeout five seconds, so request timeout won before the test
  reached `collector.cancel()`.

The failed run was not accepted as unified evidence. No production process
code changed. Test infrastructure now keeps the real timeout/cancellation and
process-group cleanup assertions while giving fixture readiness a distinct
budget. The five related lifecycle tests passed 5/5 focused, 50/50 across ten
stress rounds and 279/279 in a fresh full SwiftPM pool before the final unified
run.

After that failed non-UI run, the read-only Apple status returned to
`disabled + requires authentication` and the authentication window was gone.
This proves ordinary user-authenticated Automation Mode is tied to a live
UI-test request rather than a durable switch suitable for a long preflight.
The verifier now runs
`scripts/verify-ui-automation-mode --allow-auth-prompt` and makes XCUITest the
immediate next external command. The explicit mode accepts only the exact
authentication-required state; default standalone checks still fail, and no
no-auth policy, TCC, daemon or credential operation was added.

With that orchestration, a later unified run completed 9/9 XCUITest methods,
exported and validated all seventeen screenshots, passed the focused Phase B
gate, passed both 279-test SwiftPM pools, passed all three isolated matcher
benchmarks and passed every source boundary. It then failed in the Xcode App
contract target before bundle/release/docs closure because the new
`scanModelUsesFullDispositionCountsWithBoundedRows()` fixture declared 1,000
full classifications against only seven full snapshots. The closed production
projection correctly rejected the impossible relation. The failed run was not
accepted; only the test fixture changed, and focused 1/1 plus complete App
target 97/97 verification now pass.

Two later complete-suite runs exposed macOS UI-runner race assumptions rather
than product failures:

- Settings scene restoration could replace a briefly visible requested page
  before the test acted on it;
- an external Chrome crash window could consume the pre-confirmation click
  while XCUITest ran interruption monitors.

Both paths received bounded UI-test fixes and repeated independent-process
coverage. The final current-source `scripts/verify` then completed in one
uninterrupted run with exit code `0`.

### Verifier coverage

The focused gate remains directly runnable for iteration, but the unified
verifier invokes it after XCUITest and the read-only host preflight. Standalone
green focused runs are supporting evidence only; the accepted Task 26 gate is
one complete `scripts/verify` exit `0`:

| Requirement | Owning command/evidence | Current state |
| --- | --- | --- |
| read-only host state classification and standard prompt handoff | `scripts/verify` line 8 | passed |
| all nine XCUITest methods and seventeen exported screenshot contracts | `scripts/verify` lines 12–23 | 9/9 and 17/17 passed |
| anonymous product pipeline, typed aggregate, ledger, no Codex and separate cancellation | `scripts/verify` line 25 → `scripts/verify-phase-b-gate` | passed inside unified run |
| domain, migration, retention, Surveyor, accounting, Knowledge/Activity and Local Knowledge regressions | two 279-test functional/security pools | 279/279 twice; three opt-in diagnostics explicitly skipped |
| source boundaries, deterministic 67-rule catalog and Automation Mode parser self-test | focused gate through `scripts/verify` line 25 | passed |
| current-machine product performance and cancellation | separately recorded Home product/cancel runs in §4 | passed |
| SwiftPM build/tests and three isolated matcher performance gates | `scripts/verify` lines 27–36 | passed; 0.229 s / 0.381 s / 0.529 s |
| Xcode App contract tests | `scripts/verify` lines 46–53 | 97/97 passed |
| signed Debug App, bundle/catalog identity and Debug-to-Release fixture isolation | `scripts/verify` lines 55–65 | passed |
| English/`zh-Hans` key parity, Settings entry points, compiler, docs and diff hygiene | `scripts/verify` lines 67–80 | passed |
| real current-source App/window quality | independent XcodeBuildMCP + read-only Peekaboo evidence above | passed; does not replace XCUITest |

The manual-only GitHub workflow also invokes `scripts/verify`. The preflight
does not special-case CI: it proceeds only when Automation Mode is already
enabled or an administrator has explicitly configured the documented no-auth
CI/lab policy. This repository change does not configure that machine policy.

Current-source static contract audit finds nine unique XCUITest method
declarations. The canonical 17-name screenshot set matches exactly across the
UI testing guide, export script, screenshot verifier and XCUITest attachments
(13 literal names plus four Light/Dark helper expansions). The final unified
run executed 9/9 methods and validated all 17 PNGs.

## 6. Phase B Scope Audit

| Constraint | Result |
| --- | --- |
| Quick Scan invokes Codex | No; package/source graph and fake marker passed |
| Quick Scan invokes Probe/Adapter/Policy/Executor | No reachability from Surveyor/Quick Scan/App Scan |
| Scanned-target mutation | No mutation API in Surveyor/Quick Scan; anonymous fixture before/after path/type/identity/size/mtime/content audit passed |
| Arbitrary executable/arguments | No Quick Scan surface; native Activity uses fixed `/usr/bin/git status/log` only |
| Enabled cleanup/Trash/Registered Action | No; Scan inspector exposes only Close, Review remains disabled |
| Raw controlled content/JSONL persistence | No matching Evidence/Quick Scan persistence surface |
| Telemetry/network/remote rules | None added; Codex runtime explicitly disables analytics |
| Background/MenuBar/scheduler/login item | None found |
| New dependency/copied upstream code | None; Swift package graph remains dependency-free |
| Dev harness bundled in App | No XcodeBuildMCP/Peekaboo/MCP artifact found |
| Release DEBUG fixture leakage | Unified Release boundary verifier passed |

Target-write evidence is structural plus behavioral. It is not an
EndpointSecurity/DTrace/syscall trace, and the report does not claim otherwise.

## 7. Gate Decisions

| Area | Decision | Residual boundary |
| --- | --- | --- |
| Deterministic domain/persistence | **Pass** | narrow SQLite wrapper not fuzzed; one DB remains a page-level failure domain |
| Production Quick Scan | **Pass for one Primary Scan Root** | no multi-root/multi-ledger implementation; packaged-App FDA still uncertain |
| Accounting explainability | **Pass** | APFS clone/compression/purgeable and live drift remain explicit caveats |
| Knowledge/Activity safety | **Pass** | provider gaps remain Unknown; no promotion from time or path alone |
| App/UI readiness for Phase C planning | **Pass** | implementation still requires a separately approved Phase C plan |
| Deep Dive | **No-go/paused** | Broker-only tool surface still not technically enforced |
| Release/distribution | **Not evaluated** | Developer ID, hardened runtime, notarization and release FDA remain Epic 9 |

## 8. Accepted Architecture Drift and Follow-ups

- One `ScanRequest.rootURL`, one scope and one ledger are the current real
  product contract. Phase C must not claim multi-root.
- The product persists candidate/owner/gap facts plus a full typed aggregate,
  not millions of arbitrary path rows. Terminal/restart projections are
  candidate-first and bounded to 100 records.
- Generic typed payloads remain capped at 1 MiB. Only `SpaceLedger` has a
  role-specific 16 MiB allowance for thousands of typed owners/gaps.
- Persistence batches default to 4,096 and are capped at 8,192; the first fact
  is still committed separately for useful early durability.
- Raw Codex JSONL remains bounded memory-only and never persisted. The
  unimplemented crash-remnant SLA is not claimed.
- Current code contains no Rust need. The measured product path met both time
  and memory gates.

## 9. Final Gate

Phase B evidence supports the following final decisions:

- domain/persistence: **pass**;
- product Quick Scan: **pass**;
- accounting: **pass**;
- Knowledge/Activity: **pass**;
- Phase C deterministic planning: **go**;
- Phase C implementation: **blocked pending user approval of the new plan**;
- Deep Dive: **no-go/paused**;
- release/distribution: **not evaluated**.

The correct next action is a separate Phase C deterministic Epic 8 plan. It
must reuse the existing typed Policy/Action foundations, but it must not be
implemented until user review/approval and must not enable a cleanup path
before its own tests, revalidation, UI and real-machine safety gate pass.

## 10. Prompt-to-Artifact Completion Audit

This audit checks the original approved objective against repository and remote
evidence rather than treating plan checkboxes or one green test command as
completion by themselves.

| Objective requirement | Concrete evidence | Current result |
| --- | --- | --- |
| Execute the approved Epic 2–4 plan | approved plan commit `11b9b79`; executable plan remains in `plans/active/` until Task 26 closes | satisfied for plan approval and execution |
| Complete Tasks 9–25 | every Task block has only checked steps; dedicated commits `1a23cc6` through `96c9b96` | satisfied |
| Review every Task | `epic-2-4-task-9-review.md` through `epic-2-4-task-25-review.md` exist inside their corresponding Task commits | satisfied |
| Verify every Task and iterate findings | per-Task focused/full evidence is recorded in the plan; confirmed findings and fixes are recorded in each review | satisfied |
| Record development knowledge | four upstream studies, ADR 0007–0010, Task briefs, review reports and this validation report | satisfied |
| Preserve visual asset provenance | `docs/assets/*/PROMPTS.md` and round notes identify `$erik-gpt-image-2`; generated images remain non-pixel-accurate references | satisfied; Task 26 required no new asset |
| Push each completed Task | every Task 9–25 commit is reachable from `origin/main`; remote head is `96c9b96` | satisfied |
| Complete Task 26 product evidence | 279/279 focused tests, ASan/TSan, synthetic contracts, current-machine product/cancel benchmark, scope audit, actual-window inspection and post-fix review | satisfied |
| Complete Task 26 unified verification | one uninterrupted current-source `scripts/verify` run passed 9/9 UI, 17/17 screenshots, both 279-test pools, matcher benchmarks, 97/97 App contracts, bundle/release/docs gates and exited `0` | satisfied |
| Close plan lifecycle | Epic plan and Task 21–26 briefs move together to `completed/`; active router is intentionally empty | satisfied by this closure change |
| Push Task 26 | dedicated closure commit must be pushed with invalid token variables removed and then checked against `origin/main` | post-commit operational check; not a product proxy |

Every Task 9–25 commit was checked for:

- reachability from `origin/main`;
- the matching Task review file already present in that commit;
- exactly one
  `Co-authored-by: TRAE CLI <noreply@bytedance.com>` trailer.

This mapping was rechecked against the current local remote-tracking ref:
Tasks 9–25 resolve respectively to commits `1a23cc6`, `ed42aa8`, `09646d5`,
`d4bff23`, `714d2bb`, `766d8e7`, `b8633ae`, `51046ce`, `8a7f6a6`,
`a7c1e38`, `dbe61f3`, `265a214`, `d569a85`, `8db0f83`, `98a44af`,
`30df532` and `96c9b96`; each is reachable and carries one trailer. Local
`HEAD` and `origin/main` are both `96c9b9670c64accb4ad0c121a586e5be4aad66e5`
before the Task 26 commit.

The audit marks the Phase B product milestone complete. The closure commit and
push remain repository transport operations rather than substitutes for the
product evidence above.

Pre-commit and lifecycle audits also passed:

- the Task 26 brief's evidence-driven write set matches the Git working tree,
  including the additional process-test and XCUITest stabilization files;
- all untracked Task 26 files are trackable and no intended source, script or
  document is silently ignored;
- changed files contain no credential/token pattern, private user Home path,
  benchmark database/JSON, `.xcresult`, runtime screenshot, unexpected binary,
  symlink or mode change;
- high-risk changed-line review found only UUID-named benchmark/test temporary
  cleanup and Stornaut-owned Evidence Store writes; no new target write,
  network, Codex, Probe, Executor or background-service surface exists;
- Task 26 and the parent plan record completion only after the unified verifier
  succeeded;
- the Epic plan and Task 21–26 briefs are archived together, and the active
  router contains no executable work;
- the Git index remains empty until the final audit finishes.
