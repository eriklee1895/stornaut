# Task 44 Implementation Brief — Production Vertical Slice and Phase D Final Gate

> **Status:** Approved; blocked on pushed Task 43 baseline.
>
> **Parent plan:**
> [Phase D Conditional Deep Dive](phase-d-conditional-deep-dive.md)

## 1. Objective

Task 44 is Phase D's only normal product admission gate:

```text
current retained Quick Scan
→ normal Investigations start
→ current disclosure + runtime admission
→ real current-source signed-App Deep Dive
→ strict partial/final Investigation report
→ History session
→ conservative Review projection
→ unchanged Phase C Cleanup Plan/Policy/Executor if user later cleans
```

It removes `.implementationUnavailable` only when the complete product
composition is present and every Phase D gate passes. It produces the final
prompt-to-artifact matrix, privacy audit, signed runtime reports, actual-window
evidence, completion audit and Phase D validation report.

Task 44 does not add Adapters, real Registered Actions, permanent actions,
background work, telemetry, provider selection, release distribution,
Developer ID or notarization.

## 2. Preconditions

Tasks 35–43 must each be independently committed and pushed with:

- zero unresolved P0–P2 review findings;
- one authoritative `scripts/verify --full` exit `0`;
- fresh docs/routers;
- `HEAD == origin/main`.

Task 44 revalidates rather than blindly trusts:

- Store v4 migration/retention/source rejoin;
- Task 38 coordinator/terminal barrier;
- Task 39 signed runtime receipt;
- Task 40 conservative projection;
- Task 41 disclosure;
- Task 42 workflow/recovery;
- Task 43 actual UI;
- unchanged Phase C Plan/Policy/Trash authority chain.

Any drift or failed prerequisite blocks admission.

## 3. Final Product Composition

### 3.1 Remove final feature gate

Replace the final `.implementationUnavailable` only behind one exact
composition predicate:

- usable retained source or baseline Quick Scan path;
- current disclosure acceptance;
- Codex installed/authenticated/syntax compatible;
- current Task 39 signed runtime receipt fresh/admitted;
- `StornautInvestigation` production dependencies available;
- valid fixed budget preset;
- no conflicting workflow;
- Store v4 healthy;
- no unresolved Phase D safety/review gate.

No single preference, environment variable, DEBUG argument, receipt file or
Codex discovery result can enable the feature alone.

“Usable retained source” is exactly the shared
`InvestigationSourceEligibilityV1`: terminal completed/partial/existing Quick
Scan cancelled, not failed, selected primary scope exactly once completed and
no unfinished scopes, exact same-session Space Ledger `reconciled` with zero
`coverageGaps`, measured-zero unmeasurable bytes and
`unknownIncludesUnmeasurable == false`, unexpired, and exact Task 37 rejoin
matching. Phase D selects one primary root and has no secondary-scope
permission exception. Task 44 has no second completed-only predicate.

If any dimension later becomes false, Deep Dive becomes unavailable with the
typed repair state; Quick Scan and retained valid reports remain available.

### 3.2 Production factory

Task 44 adds a separate normal-product composition root. It constructs a new
instance of the closed Task 38 facade from reviewed low-level
runtime/lifecycle/Store components, but it cannot call, import or adapt the
Task 39 diagnostic factory or any diagnostic-only source/config/canary/result
type. The normal factory must not expose:

- raw runtime/process/profile/environment construction;
- diagnostic canaries or hard-coded evidence;
- arbitrary model/provider/CLI flags;
- Executor/Trash/authorization;
- a second source rejoin/Store;
- a runtime receipt bypass.

DEBUG diagnostics remain separately activated and cannot influence normal
availability.

Structural build/source checks prove:

- normal App dependency composition and Release sources contain no reference
  to the diagnostic factory or `StornautApp/Diagnostics` types;
- diagnostic source/config/nonce/canaries cannot satisfy production factory
  inputs;
- the Task 44 DEBUG fixture-root launch selector is consumed by the outer
  harness before dependency construction and neither its type nor raw value can
  flow into the production factory;
- shared code is limited to reviewed low-level protocols/implementations;
- only the Task 44 feature-gated production root can make the normal start
  facade reachable.

### 3.3 Model choice

For the admission run, prefer the user's authenticated:

```text
gpt-5.6-luna
```

Record exact provider/model observed. A temporary upstream/provider failure
may produce a truthful blocked Task report and bounded fresh retry, but cannot
waive runtime, protocol, report or product gates. Deterministic fake tests
remain authoritative for edge cases.

## 4. Real Vertical Slice Fixture

### 4.1 Safe source

Use one fresh, bounded, disposable diagnostic/product source fixture beneath a
script-owned temporary primary root. It contains:

- known deterministic files for Quick Scan;
- unknown large-consumer/rule-miss evidence;
- one classification conflict;
- one safe public provenance clue;
- one image/manifest/README evidence set;
- no secret, credential, real user cache or private source;
- no writable outcome needed from Codex.

The normal signed App runs the real Quick Scan baseline and production Deep
Dive flow against this source through the same UI/dependencies used for user
operation.

The outer DEBUG signed-App test launcher may supply one one-shot fixture-root
path through a Task 44-only launch argument. A DEBUG harness owned outside the
production composition root:

1. rejects absent/duplicate/unknown launch arguments;
2. canonicalizes the root and proves it is the exact script-owned temporary
   fixture beneath the harness nonce directory, with no symlink escape;
3. creates the same product-neutral bookmark/`ScanRequest` input used by a
   normal user-selected root;
4. removes the raw launch selector from the environment/state before
   constructing production dependencies;
5. invokes the ordinary UI start path.

The production factory receives only normal product types and cannot observe
whether the selected root originated from the DEBUG harness or user UI. The
selector is never persisted, never accepted in Release, grants no start
authority and cannot bypass disclosure, receipt, workflow, Store creation,
source rejoin or terminal barriers. It is not a Task 39 diagnostic
configuration/source/config/nonce/canary/result type.

Structural tests compile the production composition without diagnostics and
reject every import/reference to Task 39 diagnostic source/config/factory
types. Separate DEBUG harness tests prove the launch selector is consumed
before production composition and cannot flow into a production factory
initializer.

### 4.2 Required outcomes

The real run must produce one valid:

- final report, or
- verified partial report if a truthful bounded stop condition occurs.

For final Phase D `go`, evidence must demonstrate:

- at least one retained target investigated;
- every admitted target resolved or explicitly unresolved;
- source labels and counter-evidence;
- exact coverage/Unknown accounting;
- budget ledger and stop reason;
- capability degradation truth;
- Store v4 immutable report/history;
- conservative Review projection;
- zero cleanup execution during the Investigation.

The fixture cannot script or hard-code the model's final findings into product
code. The protocol validates IDs/shape; report quality is reviewed against
fixture truth without granting authority.

## 5. Three Separate Runtime Reports

Task 44 generates and archives summaries/fingerprints for three independent
reports bound to the same current App/helper/runtime receipt.

### 5.1 Capability observation report

Require actual observation of all nine:

```text
directRead
shell
unifiedExec
liveSearch
publicCommandNetwork
browserOrDirectFetch
imageInspection
skills
subagents
```

Public internet success is recorded separately. Advertised/configured does not
equal observed.

### 5.2 Enforced-control verification report

Require current enforced evidence for:

- signed App/helper/service identity;
- identity drop;
- outer inherited write denial;
- same-investigation managed proxy ownership;
- all other local/private/link-local/Unix block;
- audit-session/descendant lifecycle ownership;
- receipt-selected event schema;
- Store source rejoin;
- structural no-Executor/no-Trash/no-authorization;
- complete drain/artifact/auth cleanup;
- zero residue.

Model success/non-observation is not used as proof.

### 5.3 Adversarial denial report

Require explicit attempted and attributed denial for:

- user-data write/mutation;
- localhost IPv4/IPv6 except exact proxy transport;
- private/link-local/reserved network;
- direct proxy bypass;
- Unix socket;
- cleanup/Policy/Executor/XPC authority reachability;
- descendant/subagent variants.

An unattempted, timed-out or absent event does not count as denial.

## 6. Protocol and Report Admission

The real run must prove:

- exact current Investigation/run/target IDs;
- one receipt-selected collaboration schema;
- full root/descendant accounting;
- strict Envelope v2 final output;
- malformed/unknown/forged/prompt-injected output rejected;
- no model-provided path/action/disposition/Policy/authorization accepted;
- evidence only after matching terminal turn;
- observed tool/token usage exact or typed unavailable;
- exact T0/15/45/135/140 terminal settlement envelope;
- complete lifecycle/proxy/Probe/artifact drain;
- atomic Store terminal commit;
- no raw JSONL/prompt/reasoning persisted.

Prompt-injection fixtures in local files and public content must be treated as
evidence, not instructions. They may not cause write/local-network/cleanup
attempt admission or protocol escape.

## 7. History Integration

Extend History's typed union with Deep Dive sessions:

- session/run/report type;
- final/partial/blocked/failed state, with stop and cancellation represented
  only as canonical `partial(userStopped)` and
  `partial(userCancelled)`;
- source Quick Scan reference;
- coverage/Unknown;
- budget preset/stop reason;
- findings/unresolved/degradation counts;
- source/report freshness;
- continuation lineage;
- corrupt/expired isolation;
- safe report detail link.

Keep Quick Scan, Deep Dive and Cleanup Manifest as non-causal event markers:

```text
Events mark when records were created. They do not prove what caused a
storage change.
```

Investigation expiry is the immutable Task 37 boundary
`now_ms >= min(source expires_at_ms, session created_at_ms + 604_800_000)`.
Continuation never extends it. Whole-lineage expiry/deletion must not erase a
linked 90-day Cleanup Manifest. History reports evidence expired or locally
removed without inventing detail.

History deletion remains exact local-record deletion only and cannot touch
disk targets, Codex auth/config, Trash or Local Knowledge.
The only Investigation delete is whole-Investigation lineage deletion;
report/run/evidence/degradation/budget child deletion is not exposed.

## 8. Review and Cleanup Authority Audit

From the real report:

- Agent-only rule miss appears at most `Review Recommended`;
- it is not default-selected;
- it is non-executable without independent deterministic profile;
- forged action/path/disposition fields are impossible/rejected;
- current source rejoin occurs before projection and before builder join;
- an independently existing deterministic Rule/Profile may enter the existing
  `CleanupPlanBuilder`;
- any later cleanup uses unchanged:

```text
CleanupPlanBuilder
→ CleanupPolicyGate
→ in-memory ReviewSelection
→ exact confirmation
→ one-shot ExecutionAuthorization
→ CleanupExecutionRuntime
→ ActionPolicyGate
→ ActionExecutor
```

Task 44 need not execute Trash as part of Deep Dive; Phase C already has its
own signed real-Trash gate. If a deterministic fixture is later cleaned during
an end-to-end check, it must use the exact Task 35 authorization boundary and
requires a separately safe one-shot fixture/restore contract. Do not combine
the Deep Dive gate with an unreviewed new write.

## 9. Product UI and Actual-Window Evidence

Run the normal product flow in the actual signed Debug App:

- Overview Deep Dive entry;
- disclosure if reset;
- baseline Quick Scan;
- preset start;
- running Guided Journey;
- Details Inspector;
- partial/final report;
- History detail;
- Review projection;
- blocked/recovery state.

Capture Peekaboo image/AX evidence in Light/Dark and English/`zh-Hans` across
the canonical states. Verify:

- no placeholder/implementation-unavailable remains when fully admitted;
- no chat/console/raw JSONL/reasoning;
- no false metrics before start or after safety block;
- Agent-only rows remain unselected/non-executable;
- keyboard/VoiceOver/Reduce Motion;
- no clipping/overflow at minimum/normal windows;
- Settings shows separate source/disclosure/Codex/runtime/dependency/workflow/
  budget states.

Focused XCUITest covers:

- first-use disclosure;
- baseline chaining;
- start;
- Inspector;
- pause/stop/cancel;
- partial continuation;
- final History;
- Review route;
- safety blocked;
- keyboard navigation.

User screen interference may justify a focused retry, not product weakening.

## 10. Prompt-to-Artifact Matrix

Create the final checked-in matrix mapping every stage to:

- owner;
- exact inputs;
- output type;
- persistence and retention;
- authority level;
- source/rejoin fingerprint;
- test/report/gate evidence;
- privacy classification;
- failure/recovery behavior.

Required rows:

1. Quick Scan source;
2. Candidate Planner;
3. Investigation Plan;
4. source manifest;
5. disclosure;
6. runtime receipt;
7. context/prompt;
8. direct tools;
9. Probe Broker;
10. App Server events;
11. Envelope v2;
12. normalized report;
13. Store v4;
14. History;
15. Review projection;
16. existing Cleanup Plan;
17. existing Policy/selection/confirmation/authorization;
18. existing execution/Manifest/Result.

The matrix must make clear that no Agent artifact has cleanup authority.

## 11. Privacy Audit

Audit source, SQLite and generated runtime artifacts for:

- raw prompt;
- raw JSONL;
- hidden reasoning;
- stdout/stderr;
- file snippets/content;
- full URL path/query/fragment/userinfo;
- signed URL/token/API key/cookie/auth;
- absolute Home/user paths;
- Codex auth copy residue;
- runtime workspace residue;
- report/config/log/test artifacts accidentally tracked;
- credentials in git diff/history for this Task.

Expected durable data is limited to:

- typed source manifest/fingerprints;
- bounded normalized report/evidence;
- safe public origin/reason;
- aggregate budget events;
- versioned disclosure acceptance;
- current runtime receipt metadata;
- normal Scan/Manifest records under existing retention.

Produce a checked-in sanitized audit report; raw machine/runtime files remain
outside the repository.

## 12. Failure Matrix

Final admission exercises deterministic fixtures for:

- no Codex/auth;
- stale/failed runtime receipt;
- disclosure declined/obsolete;
- missing/stale/partial baseline;
- workflow conflict;
- malformed/forged Envelope;
- prompt injection;
- hard budget exhaustion;
- observed overrun;
- usage unavailable;
- no evidence gain;
- user pause/stop/cancel;
- runtime terminal unobserved;
- lifecycle drain unconfirmed;
- terminal persistence failure;
- crash recovery;
- source drift at every rejoin;
- expired/corrupt report;
- Agent-only proposal;
- History deletion;
- unchanged Phase C cleanup authority.

All fail closed while preserving valid prior results.

## 13. Performance and Resource Gates

Measure, do not guess, on current Apple Silicon:

- Task 36 100,000-row planner benchmark remains within admitted threshold;
- Task 37 Release maximum-size Store report remains admitted: insertion,
  rejoin, terminal, recovery and continuation each have three serial samples,
  every sample is at most 75 monotonic seconds, preserves the streaming memory
  bound and retains at least 15 seconds measured margin below the immutable
  90-second deadline;
- Store v4 migration/source manifest/paging remains bounded and the private
  deny-by-default authorizer still exposes no raw connection or generic SQL;
- context compression bounded at 256 KiB per input and preset cumulative limit;
- App event processing does not retain unbounded raw stream;
- UI remains responsive during fake/real bounded run;
- terminal settlement honors exact 15/45/135/140-second monotonic limits;
- raw artifacts and processes reach zero residue;
- normal Quick Scan performance regression remains within prior gate.

Document thresholds and observed results in the validation report. Do not
raise thresholds merely to pass without review.

## 14. Final Documents

Add/update:

```text
docs/reports/phase-d-validation-report.md
docs/reports/phase-d-task-44-review.md
docs/reports/phase-d-privacy-audit.md
docs/reports/phase-d-prompt-to-artifact-matrix.md
docs/plans/completed/phase-d-conditional-deep-dive.md
docs/plans/active/README.md
docs/plans/roadmap.md
docs/agent/coding-agent-handoff.md
docs/README.md
AGENTS.md
```

Archive Tasks 36–44 briefs/plan according to the existing docs convention.
Update statuses without deleting historical blockers/reports. State explicitly:

- Phase D local-only product Deep Dive is admitted or blocked;
- release distribution/notarization/FDA onboarding remains deferred;
- Phase E is next only if Phase D is `go`;
- no unresolved P0–P2 findings;
- exact commit/report fingerprints and verifier result.

## 15. Tests First and Verification Order

Before implementation, add/extend tests for the final feature predicate,
normal composition, History union and end-to-end fake flow.

Run heavy work serially:

1. focused Core/Investigation/Store tests;
2. focused App model/tests;
3. focused XCUITest fixtures;
4. structural no-Executor/Release/privacy/docs gates;
5. current signed-App runtime machine diagnostic;
6. one real normal product `gpt-5.6-luna` Deep Dive;
7. actual-window Peekaboo/AX;
8. History and Review inspection;
9. zero-residue/privacy audit;
10. independent whole-diff review and fixes;
11. one uninterrupted authoritative `scripts/verify --full`;
12. prompt-to-artifact completion audit;
13. docs links/diff/credential/generated-artifact hygiene;
14. independent commit/push.

The current-source signed-App normal-product `gpt-5.6-luna` vertical slice in
step 6 is mandatory for a Phase D `go`. Provider/model unavailability or any
failure to complete that real path produces a blocked final verdict and keeps
`.implementationUnavailable`; deterministic fake fixtures remain authoritative
for edge cases but cannot substitute for this gate.

Suggested focused commands adapt to current repo names:

```text
swift test --filter Investigation
swift test --filter EvidenceStore
swift test --filter CleanupPlanBuilder
swift test --filter CleanupPolicy
xcodebuild ... -only-testing:StornautAppTests/Investigation
xcodebuild ... -only-testing:StornautAppTests/History
xcodebuild ... -only-testing:StornautAppUITests/InvestigationsUITests
scripts/verify-investigation-boundaries
scripts/verify-investigation-runtime-diagnostic
scripts/verify-app-release-boundaries
scripts/check-doc-links
git diff --check
swift test --parallel false
scripts/verify --full
```

### 15.1 Focused validation acceptance

The focused phase is green only when:

- Core/Investigation/Store/App/UI tests selected above exit `0`;
- all three runtime report verifiers pass independently;
- structural no-Executor, Release, privacy and docs gates pass;
- the real signed-App run and actual-window inspection are bound to the same
  current source/build/receipt;
- History and conservative Review projections match the persisted report;
- zero lifecycle/proxy/Probe/artifact residue is observed;
- `git diff --check` and generated-artifact/credential hygiene pass.

Focused success does not complete Task 44 and cannot replace the final
uninterrupted authoritative `scripts/verify --full`.

The final full verifier must run uninterrupted once and own all admitted Phase
D checks. Separate prior green logs cannot be assembled as a substitute.

## 16. Independent Review

Use a fresh independent reviewer, preferably authenticated local Codex
`gpt-5.6-luna`, read-only. Review the complete Task 44 diff and Phase D
composition for:

- feature gate bypass;
- stale/synthetic receipt/report reuse;
- model success treated as containment;
- missing adversarial denial;
- no-Executor structural gaps;
- source rejoin omissions;
- raw secret/path/prompt/event persistence;
- terminal UI before drain/commit;
- Agent-only Ready/default selection;
- second Plan/Policy/Executor path;
- product/diagnostic fixture mixing;
- History causal claims;
- stale/expired/corrupt handling;
- normal flow UI/accessibility/localization defects;
- Release/debug marker leakage;
- docs claim overreach;
- deferred Phase E/F scope creep.

Fix all P0–P2 findings and rerun affected gates, then run the final full
verifier again if any source changed.

## 17. Completion Audit

Before declaring Phase D complete, restate the objective as concrete success
criteria and build a prompt-to-artifact checklist mapping:

- every Phase D plan requirement;
- every Task 36–44 deliverable;
- every named report/spec/ADR/brief;
- every command/test/benchmark/runtime/UI/privacy gate;
- every authority/privacy/retention invariant;
- every commit/push;
- every explicit deferred item.

Inspect current files, git history, reports and fresh command output. Passing
tests alone are not sufficient if a requirement is uncovered. Treat
uncertainty as incomplete.

Phase D is `go` only if:

- complete product flow works in current signed App;
- one successful current-source signed-App normal-product `gpt-5.6-luna`
  vertical slice completes; provider/model unavailability or run failure is a
  blocked verdict and cannot be replaced by fake fixtures;
- all three runtime evidence planes pass separately;
- strict protocol and lifecycle gates pass;
- Store/privacy/retention pass;
- Agent-only authority invariant passes;
- actual-window UI passes;
- zero unresolved P0–P2;
- final uninterrupted `scripts/verify --full` exits `0`;
- a docs-freshness audit verifies every referenced normative document, task
  dependency/status router, ownership/non-goal claim and product-availability
  claim matches the committed diff and canonical contract;
- Task 44 commit is pushed and `HEAD == origin/main`.

Otherwise publish a precise `blocked` result and keep normal Deep Dive
unavailable.

## 18. Explicit Non-Goals

- external Adapters;
- real Registered Actions;
- permanent actions;
- arbitrary provider/model selection;
- public distribution;
- Developer ID/notarization;
- expanded FDA/TCC onboarding;
- background/scheduled/login investigation;
- telemetry/remote rules;
- multi-user/remote runtime;
- model-written Local Knowledge;
- any new cleanup authority.

## 19. Commit and Push

Task 44 uses one independent commit after all gates:

- no Coding Agent co-author trailer;
- no raw machine reports, JSONL, credentials, logs, screenshots, `.xcresult`,
  temporary fixtures or auth projection;
- unset `GITHUB_TOKEN GH_TOKEN`;
- push `origin/main`;
- verify local `HEAD`, `origin/main` and expected commit match;
- record final commit and report fingerprints in the validation report.
