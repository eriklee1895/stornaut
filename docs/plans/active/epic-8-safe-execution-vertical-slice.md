# Stornaut Phase C — Epic 8 Safe Execution Vertical Slice Plan

> **Status:** In progress — approved on 2026-08-11; Task 27 completed and Task
> 28 is active
>
> **Roadmap phase:** Phase C — Safe Execution Vertical Slice
>
> **Plan date:** 2026-08-11
>
> **Baseline:** `546b3a2c1fc689dfc288b46f61f9a134e8ffeaf5`
>
> **Execution rule:** The user approved this plan on 2026-08-11. Tasks 27–35
> are authorized in order; approval does not authorize Deep Dive, Adapters, real
> Registered Actions, release/notarization, permanent deletion, background
> cleanup, or any permission-boundary expansion. Approval authorizes building
> the Task 35 signed-App diagnostic harness, but the diagnostic's real Trash
> run still requires a separate explicit opt-in when Task 35 is reached.

## Goal

Deliver one useful, deterministic and evidence-driven write vertical slice:

```text
latest valid Quick Scan
→ deterministic execution evidence refresh
→ Review Reclaim Plan
→ user selection
→ pure Cleanup Policy decision
→ blocking stale check
→ final user confirmation
→ one-shot execution authorization
→ fresh filesystem/activity revalidation
→ MoveToTrash
→ crash-safe execution journal
→ immutable Cleanup Manifest
→ truthful Cleanup Result
→ History audit
```

The slice must run without Codex, without external tools and without a
Registered Action. It must preserve the Phase B one-Primary-Scan-Root contract,
keep Deep Dive outside this deterministic slice with its capability-first
runtime gate still pending, and make `FileManager.trashItem` the only
production write primitive that mutates a selected target path. Stornaut-owned
SQLite, preferences and diagnostic fixture writes remain separate,
scope-bounded infrastructure.

## Architecture

Phase C evolves the existing Phase A/B contracts instead of building parallel
types:

- `CleanupPlan`, `PolicyDecision`, `CleanupManifest`, `ActionPolicyGate`,
  `ActionExecutor`, `TrashMoving`, `EvidenceStore`, Activity providers and
  Space Accounting remain the foundations;
- a new deterministic review/planning layer resolves a deliberately bounded
  execution-evidence profile from the checked-in Rule Catalog;
- a pure plan-level Policy Gate decides whether selected items may proceed;
- the existing filesystem `ActionPolicyGate` remains the final identity,
  active-path, denylist, root, mount and symlink boundary;
- a one-shot in-memory authorization separates user confirmation from a
  reusable persisted plan;
- an actor-owned execution coordinator serializes actions, records a
  write-ahead journal and finalizes one immutable Manifest;
- SwiftUI Views consume typed Review/Cleanup state and never call
  `FileManager`, `ActionExecutor`, SQLite, Activity providers or Trash directly.

The intended layering is:

```text
Rule/Evidence Resolver
  deterministic facts only
        ↓
CleanupPlanBuilder
  immutable proposal, no authority
        ↓
CleanupPolicyGate
  pure per-item allow/deny + reason
        ↓
User confirmation
        ↓
ExecutionAuthorization
  one-shot, short-lived, memory-only
        ↓
CleanupExecutionCoordinator
        ↓
ActionPolicyGate
  current path/identity/activity boundary
        ↓
ActionExecutor → TrashMoving → FileManager.trashItem
        ↓
Execution Journal → Cleanup Manifest → Result/History
```

## 1. Approval Decisions Encoded by This Plan

Approval of this plan confirms the following implementation choices.

### 1.1 Phase C ships only `MoveToTrash`

- Production `ActionRegistry` remains empty.
- The existing `fixture.fake-cleaner` stays test-only.
- The Review page may render an empty/deferred Registered Actions section to
  preserve the approved information architecture, but it cannot execute the
  fixture or advertise a real tool action.
- No Homebrew, npm, pnpm, uv, Docker or other executable is registered.
- No permanent action exists, so Phase C permanent-release bytes are always
  zero and must still remain a separate accounting field.

Real Registered Actions remain Phase E / Epic 7 + remaining Epic 8.

### 1.2 The initial executable catalog is an explicit exact-path allowlist

Phase B currently has 34 rules recommending `moveToTrash`, but zero production
rules with a `readyToReclaim` base disposition. Phase C must not connect all 34
recommendations to Trash or treat fixture provenance as fresh runtime proof.

Task 27 revalidated the proposed four-rule set and narrowed the executable
profile to three exact user-cache rules:

| Rule | Phase C disposition after all evidence passes | Default selection |
| --- | --- | --- |
| `cache-npm-content` — `.npm/_cacache` | `readyToReclaim` | selected |
| `cache-pip` — `Library/Caches/pip` | `readyToReclaim` | selected |
| `cache-go-build` — `Library/Caches/go-build` | `reviewRecommended` | unselected |

`cache-uv` remains ordinary read-only `reviewRecommended` classification
evidence but receives no Phase C execution profile. uv's pinned official
documentation states that directly modifying/removing its cache directory is
never safe and that cleanup must use its lock-aware `uv cache` commands. Phase C
does not ship that Registered Action, so moving `.cache/uv` directly would
contradict upstream safety guidance.

This evidence-driven narrowing is the Task 27 outcome allowed by the approved
plan; it does not substitute a wildcard, project artifact, runtime/update path
or Agent-only item.

All other rules remain read-only classification evidence in Phase C. They may
appear as Review Recommended, Protected or Unknown, but they are not
executable until a later reviewed execution profile proves their facts.

### 1.3 Rule evidence and runtime evidence are different

The rule compiler may attest only closed, provenance-backed static facts such
as the exact cache layout and documented recovery method. It cannot assert:

- that a process is currently inactive;
- that a path still has the same identity;
- that Git is currently clean/synchronized;
- that a cache is currently unreferenced;
- that a path contains no user data unless the approved execution profile
  supplies a dedicated deterministic proof.

Every execution profile names exactly which evidence keys are:

- compiler-attested static facts;
- current filesystem facts;
- current running App/process facts;
- current Git facts.

Missing, contradicted, stale or unavailable facts fail closed.

Changing an approved rule's base disposition does not retroactively rewrite a
retained Quick Scan classification. The existing classifier already reduces a
Ready base rule to Protected/Unknown when evidence or activity is contradicted
or missing. The shared resolver must supply the closed evidence during a new
Quick Scan so that its immutable classification truth is complete. Review then
refreshes and may preserve or downgrade that disposition, but never promotes a
persisted Protected/Unknown item. An older or catalog-mismatched scan requires
`Scan Again`.

### 1.4 Review selection is not execution authority

- A checkbox is only a local user intent.
- `CleanupPlan` is a persisted, non-executable proposal.
- `PolicyDecision` is an auditable result, not a capability token.
- Final confirmation produces a short-lived, one-shot,
  non-`Codable` `ExecutionAuthorization`.
- Authorization expires after at most 30 seconds, is bound to one plan
  generation and the selected item/decision fingerprint, and is consumed on
  the first execution attempt.
- The 30-second TTL is an admission deadline: it must be valid when a run is
  accepted and consumed, but it does not cancel an already admitted serial
  batch. Every later item still receives fresh Policy and filesystem
  revalidation immediately before its write.
- Authorization is never stored in SQLite, UserDefaults, Local Knowledge,
  logs, Manifest or a Deep Dive workspace.

### 1.5 Default selection remains conservative

- Only `readyToReclaim` items with an approved `moveToTrash` execution profile,
  complete current evidence and a current Policy preview are selected by
  default.
- `reviewRecommended` items are always unselected and require explicit user
  selection plus final confirmation.
- `protected` and `unknown` are disabled.
- An item discovered by Codex in a future phase follows the same rule; its
  source badge cannot change selection.
- If the initial Ready allowlist is removed during Task 27 review, an empty
  default selection is valid and truthful.

### 1.6 Overlapping selected paths are rejected

Phase C does not infer dependencies or silently collapse parent/child
selections. A selected ancestor and descendant form a plan conflict:

- both remain visible;
- execution is blocked;
- Review names the conflict;
- the user must deselect one.

This avoids ordering a parent Trash followed by a child action against a path
that no longer exists.

### 1.7 Execution is serial and cancellation is between actions

- Phase C executes selected actions one at a time in a stable order.
- The user may cancel before confirmation or request `Stop After Current
  Action` while a batch runs.
- Foundation Trash is synchronous and has no safe mid-call cancellation
  contract; the UI must not claim otherwise.
- After the current Trash call reaches a terminal result, no further action
  starts when stop was requested.
- A failure may coexist with prior successful records only when the failed
  item's original identity is proven unchanged. Stale/revalidation failures or
  an uncertain Trash outcome stop the batch before any later action starts.
- There are no implicit rollbacks and no permanent-delete fallback.

### 1.8 Crash consistency requires a journal before an immutable Manifest

An immutable final Manifest alone cannot safely describe a crash between a
filesystem write and persistence. Phase C therefore introduces a private
Stornaut-owned execution journal:

```text
prepared
→ actionStarted
→ actionOutcomeRecorded
→ manifestPending
→ finalized
```

- journal intent is persisted before the first write;
- each action is marked started before calling Trash;
- each returned outcome/receipt is persisted before the next action;
- the final Manifest is insert-only and never rewritten;
- journal recovery never reruns an action automatically;
- every `actionStarted` record without a durable outcome becomes
  `outcomeUnknown`, even when the original path currently appears unchanged;
  observed original/Trash state is supporting recovery evidence, not proof
  that the platform call did or did not run;
- an unknown outcome stops later actions, blocks retry, and asks the user to
  inspect Trash and run a new scan before creating another plan;
- recovery converts the unresolved started action and every not-started
  remainder into a conservative immutable Manifest; Unknown is a recorded
  result, not a reason to leave a mutable journal indefinitely;
- a final Manifest persistence failure is reported separately and retried from
  the journal without rerunning filesystem actions.

The journal is implementation/audit infrastructure, not a second Manifest or a
user-facing log stream.

### 1.9 Trash is recoverable, not guaranteed Undo

- Cleanup Result says `Moved to Trash`, never `Freed`.
- `Open Trash` opens the system Trash; Phase C does not implement one-click
  restore.
- A returned destination is retained only in linked path-rich recovery
  evidence for at most 7 days. The 90-day minimal Manifest records a
  typed recovery state, not an exact Trash URL or original path.
- Trash can be emptied, renamed, moved or become unavailable; no UI says
  recovery is guaranteed.
- Stornaut never empties Trash.

### 1.10 Accounting remains non-causal

The Manifest and UI keep separate:

- selected candidate logical/allocated bytes;
- Executor processed logical/allocated bytes;
- moved-to-Trash bytes;
- permanently released bytes (`0` in Phase C);
- volume free-space before/after delta;
- unexplained delta.

Trash bytes are not added to free-space delta. The system observation always
states that it is not attributed to a single action.

### 1.11 One Primary Scan Root remains the product contract

Every plan is bound to:

- one `ScanSessionID`;
- one `ScanScopeID`;
- one resolved Primary Scan Root and access lease;
- one catalog version;
- one set of selected item identities.

No Phase C document, UI or domain type may claim multi-root execution or merge
ledgers from multiple volumes.

### 1.12 Existing action code is a Spike until the Phase C gate passes

ADR 0006 proves the narrow action lifecycle is viable, but explicitly lacks
user confirmation, production planning, manifest persistence, crash recovery,
dependency ordering and signed-App FDA/TCC evidence.

Therefore:

- the Phase B disabled Review button must not be enabled by directly calling
  `ActionExecutor`;
- App dependencies remain closed until Tasks 27–31 complete;
- real user-path execution remains disabled until the signed-App disposable
  Trash diagnostic and Phase C end-to-end gate pass.

## 2. Global Constraints

- Preserve every invariant in `AGENTS.md`, the PRD, architecture, approved
  Agent/UI specifications and ADRs 0004/0006–0010.
- Deep Dive remains outside Phase C and awaits its ADR 0004 capability-first
  runtime gate; Phase C imports no `StornautCodex`,
  `ProbeBridge`, Adapter or model dependency.
- No arbitrary Shell, `Process`, executable URL or argument array reaches
  Review, plan, Policy, authorization or Manifest APIs.
- The production App can reach `ActionExecutor` only through the coordinator
  after one-shot authorization consumption. Lower-level Core seams remain
  directly injectable only for focused tests and diagnostics.
- No permanent deletion API, fallback closure, `removeItem` target path or
  `rm` command is added.
- All selected-target filesystem writes are explicit user-initiated Trash
  actions.
- No background monitoring, scheduled cleanup, MenuBarExtra, login item,
  notification agent, telemetry, networking or remote rule service.
- No real Registered Action and no optional Adapter.
- No new third-party dependency without a separately documented license and
  necessity decision.
- No copied Mole GPL or Pearcleaner restricted code.
- Protected/Unknown never execute. Review Recommended executes only after
  explicit selection, complete fresh evidence, Policy allow and final
  confirmation.
- Stale execution has only `Refresh Affected Items` or `Cancel`; there is no
  `Proceed Anyway`.
- Trash failure never falls back to permanent deletion. Post-failure identity
  checks may say `Original remains in place` only when the same identity is
  proven; otherwise the outcome is Unknown and cannot be retried
  automatically.
- Manifest persistence failure cannot be displayed as normal completion.
- View types do not access filesystem, SQLite, Activity providers, Policy or
  Executor directly.
- English/`zh-Hans`, System/Light/Dark, keyboard, VoiceOver and Reduce Motion
  are first-class acceptance dimensions.
- Every completed Task receives focused tests, a code review, the current
  unified verifier, a dedicated commit and immediate push to `origin/main`.

## 3. Explicit Non-Goals

This plan does not implement:

- Deep Dive, Candidate Planner, Codex-driven Cleanup Plans or any Codex investigation/read path;
- any real Registered Action;
- Homebrew, npm, pnpm, uv, Docker, Mole, kondo or system-tool execution;
- permanent deletion or Trash emptying;
- guaranteed Undo or automatic restore;
- compression/archive-before-trash;
- multi-root/multi-ledger execution;
- automatic cleanup, background cleanup, scheduling or notifications;
- release signing, hardened runtime, notarization or distribution;
- a generic public plugin/action API;
- full content inspection;
- a new top-level Review or Cleanup Result sidebar destination;
- a second Policy/Executor stack.

## 4. Validated Baseline and Gaps

### 4.1 Reusable accepted foundations

Phase C reuses:

- versioned Cleanup Plan, Policy Decision and Manifest domain records;
- SQLite tables and 7/90-day retention boundaries;
- `ActionPolicyGate` path/root/mount/symlink/denylist/activity/identity checks;
- registry-only executable resolution;
- `ActionExecutor` revalidation and typed postflight;
- `TrashMoving` with Foundation Trash, returned destination, identity
  postconditions and no permanent fallback;
- process-group hardening for test-only registered actions;
- Quick Scan candidate-first bounded projection plus full typed aggregate;
- Rule Catalog provenance/compiler and Activity providers;
- one Primary Scan Root Settings bookmark/access lease;
- Scan, History, Settings and DEBUG fixture/XCUITest infrastructure.

### 4.2 Confirmed gaps that block direct product wiring

The current checkout has:

- zero production `readyToReclaim` rules;
- no closed execution profile or process-subject mapping in the Rule Catalog;
- incomplete deterministic evidence resolution for cache/project safety keys;
- `CleanupPlan` records that do not bind catalog/evidence/activity
  fingerprints or current identity strongly enough for product authorization;
- `PolicyDecision` records without explicit user-selection/confirmation
  semantics;
- a reusable preflight token rather than a one-shot product authorization;
- no plan-level pure Policy evaluator;
- no execution coordinator, dependency conflict check, serial batch state or
  stop-after-current behavior;
- no crash-safe execution journal;
- a Manifest shape that does not explicitly separate Trash/permanent/recovery
  and unresolved crash outcomes;
- upsert-capable Manifest persistence rather than insert-only immutability;
- History that loads only scan sessions and ledgers;
- no Review/Cleanup Result App state or workflow routing;
- no signed-App real Trash evidence;
- no end-to-end product gate.

No Task may bypass a gap by wiring the current disabled CTA directly to the
Spike.

## 5. Domain and State Semantics

### 5.1 Cleanup Plan

A production Cleanup Plan is:

- a proposal bound to one retained scan session/scope/catalog version;
- a bounded list of execution-profile items;
- independent from current checkbox selection;
- persisted for evidence lineage, not execution authority;
- expired by its normal Evidence lifecycle;
- invalidated for execution by a newer scan, changed catalog, changed
  identity, changed activity, missing evidence or explicit user refresh.

The plan stores stable IDs and bounded snapshots of the facts required to
explain what was proposed. It does not store raw content, shell text or an
authorization.

### 5.2 Review Selection

`ReviewSelection` is App/session state:

- selected item IDs;
- default-selected IDs;
- explicitly user-selected Review IDs;
- selection generation;
- overlap/conflict status.

It is not persisted as Local Knowledge and cannot change disposition.

### 5.3 Policy pipeline

The policy pipeline has two layers under one product contract:

1. `CleanupPolicyGate` — pure domain decision over plan, selection, current
   rule/classification/evidence/activity facts and time.
2. `ActionPolicyGate` — final filesystem/executable identity boundary directly
   before the write.

An item is executable only if both layers allow it.

### 5.4 Execution authorization

The authorization is:

- one-shot;
- memory-only;
- bound to plan ID, generation, ordered selected item IDs and Policy decision
  fingerprint;
- short-lived (maximum 30 seconds);
- invalidated by selection, refresh, App lifecycle, scan start, settings root
  change or any failed revalidation;
- consumed even when execution fails before the first write.

### 5.5 Execution result states

The product state machine is:

```text
noPlan
→ buildingPlan
→ reviewing
→ preflighting
→ stale(affectedItems)
→ confirming
→ executing(current, completed, failed, stopRequested)
→ finalizingManifest
→ completed
→ completedWithIssues
→ failedBeforeWrite
→ auditPending
→ recoveredInterruptedRun
```

Rules:

- `stale` cannot transition directly to `confirming` or `executing`;
- `failedBeforeWrite` proves no target write completed;
- `auditPending` means one or more actions reached a terminal filesystem result
  but the immutable Manifest is not yet durable;
- `recoveredInterruptedRun` never auto-retries an action;
- every normal terminal Result page consumes one immutable Manifest. Exact
  path/Trash recovery detail may be joined from still-live linked Evidence,
  but it cannot change Manifest outcomes or accounting and becomes
  `Evidence expired` when unavailable.

### 5.6 Journal and Manifest

The mutable journal is private and crash-recovery oriented:

- it stores stable IDs, state, identity/action fingerprints and typed outcomes,
  but no authorization and no exact path or Trash URL;
- path-rich recovery detail remains in the separately expiring Plan/Evidence
  payload for at most 7 days;
- a finalized journal is deleted only after Manifest round-trip verification;
- an unfinished journal is recovered into a Manifest at the next startup or
  workflow entry; only a Manifest-persistence failure may keep it in
  `auditPending`;
- an `auditPending` journal is minimal audit state, follows the 90-day Manifest
  ceiling, participates in `Clear Manifests`, and is never silently expired
  while it is the only durable action record.

The Manifest is:

- immutable and insert-only;
- retained for at most 90 days;
- bounded to minimal typed audit metadata;
- independent from 7-day Evidence/Plan payload;
- able to represent `outcomeUnknown` for a crash window;
- explicit about Trash bytes, permanent bytes and system observation;
- free of exact original paths and Trash destination URLs after linked
  Evidence expires;
- never rewritten to hide a failed or unknown result.

## 6. Planned File Map

Exact filenames may be refined by the approved Task brief, but responsibility
boundaries must remain:

```text
Sources/StornautCore/
  QuickScan/
    shared execution-profile evidence integration
  Review/
    CleanupPlanBuilder.swift
    ExecutableEvidenceResolver.swift
    ReviewProjection.swift
  Policy/
    CleanupPolicyGate.swift
    CleanupAuthorization.swift
    ActionPolicyGate.swift
  Actions/
    CleanupExecutionCoordinator.swift
    CleanupExecutionState.swift
    CleanupRunJournal.swift
    ActionExecutor.swift
    TrashMoving.swift
  Domain/
    CleanupPlanning.swift
    CleanupManifest.swift
  Evidence/
    EvidenceStore.swift
  Accounting/
    CleanupAccounting.swift

Rules/
  Schema/
  BuiltIn/

StornautApp/
  Review/
    ReviewState.swift
    ReviewModel.swift
    ReviewView.swift
    ReviewTable.swift
    ReviewInspector.swift
    StalePlanSheet.swift
    CleanupConfirmationSheet.swift
  Cleanup/
    CleanupResultState.swift
    CleanupResultModel.swift
    CleanupResultView.swift
    CleanupAccountingDetails.swift
    CleanupManifestView.swift
  History/
    manifest-aware state/model/detail
  AppState/
    typed dependencies and one workflow coordinator

Tests/StornautCoreTests/
  CleanupPlanBuilderTests.swift
  CleanupPolicyGateTests.swift
  CleanupExecutionCoordinatorTests.swift
  CleanupJournalRecoveryTests.swift
  CleanupAccountingTests.swift

Tests/Fixtures/
  SafeExecution/
  EvidenceStore/
  Rules/

StornautAppTests/
  ReviewStateTests.swift
  ReviewModelTests.swift
  CleanupResultStateTests.swift
  CleanupResultModelTests.swift
  History manifest tests

StornautAppUITests/
  Review, stale, confirmation, result, partial and History acceptance

docs/
  upstream-studies/epic-8-safe-execution.md
  adr/0011-review-policy-authorization.md
  adr/0012-cleanup-execution-journal.md
  reports/epic-8-safe-execution-validation-report.md
```

## 7. Task Sequence

```text
Task 27  Upstream Study, baseline audit and ADR proposals
  ↓
Task 28  Cleanup domain v2, SQLite v3 and crash journal contracts
  ↓
Task 29  Deterministic execution evidence, initial allowlist and Plan Builder
  ↓
Task 30  Pure Policy, fresh revalidation and one-shot authorization
  ↓
Task 31  Serial MoveToTrash coordinator, journal, Manifest and accounting
  ↓
Task 32  Review workflow App state and native UI
  ↓
Task 33  Cleanup Result, Manifest detail and recovery UI
  ↓
Task 34  Manifest-aware History and retention lifecycle
  ↓
Task 35  Signed-App Trash diagnostic, end-to-end gate and Phase C report
```

No Task may enable the production Review CTA before Tasks 27–31 pass. Task 32
may enable Plan/selection/confirmation against a fake or write-disabled
coordinator for UI verification; the real `FileManagerTrashAdapter` dependency
remains unavailable to the normal App workflow until Task 35's signed-App
diagnostic and final gate pass.

---

### Task 27 completion evidence

- [x] Upstream study, current SDK/machine/Store/Catalog/App baseline
- [x] ADR 0011 Review/Policy/authorization
- [x] ADR 0012 journal/Manifest/accounting
- [x] execution profile narrowed to npm/pip Ready + Go Review; uv non-executable
- [x] code/design review with confirmed findings fixed
- [x] final uninterrupted `scripts/verify` exit `0`

Final verifier evidence:

- log SHA-256:
  `a634ca746cee1eef26ea66206281db8a96ea442b17fda48a64eb65b388e4b1e4`;
- XCUITest `9/9`, 17 stable screenshots and theme/content gate;
- SwiftPM `279/279` twice, with three opt-in diagnostics skipped;
- matcher benchmarks `0.231 s`, `0.375 s`, `0.504 s`;
- Phase B evidence gate, App/state/UI boundaries, App contracts, signed bundle,
  Release fixture isolation, localization and docs all passed.

## Task 27: Safe Execution Upstream Study and Architecture Decisions

### Files

- Create: `docs/upstream-studies/epic-8-safe-execution.md`
- Create: `docs/adr/0011-review-policy-authorization.md`
- Create: `docs/adr/0012-cleanup-execution-journal.md`
- Create: `docs/plans/active/task-27-implementation-brief.md`
- Update only if evidence requires factual correction:
  `docs/research/upstream-reference-matrix.md`

### Purpose

Revalidate every external/platform assumption before evolving the Spike or
promoting any rule to default-selected Ready.

### Step 1: Capture the exact baseline

Record:

- Git HEAD and clean worktree;
- macOS/Xcode/Swift/architecture;
- current SDK declaration and Swift signature for
  `FileManager.trashItem`;
- current `NSWorkspace`/FileManager Trash-location/relationship APIs;
- SQLite version and Evidence Store schema/user/application IDs;
- current Rule Catalog hash, count of `moveToTrash` recommendations and count
  of Ready rules;
- current signed App identity and entitlements;
- current unified verifier results.

### Step 2: Refresh required upstream sources

Re-read current exact commits/licenses and relevant files for:

- Apple Foundation Trash and directory relationship;
- Apple SwiftUI Table, Inspector, confirmation/sheet, focus, accessibility and
  Reduce Motion guidance;
- PureMac App-owned Trash, FDA and immediate revalidation;
- ClearDisk postcondition/no-fallback/history behavior;
- devklean root/home/mount/symlink, dry-run, partial outcome and integrity
  tests;
- Cluttered activity-protection and UI/executor divergence risks;
- Pearcleaner Trash/Undo destination behavior as restricted
  behavior-reference-only.

Do not copy GPL/restricted code. Context7 does not provide an authoritative
Apple `trashItem` index; Xcode SDK headers plus Apple documentation remain the
accepted API evidence source.

### Step 3: Validate the proposed four-rule execution profile

For each proposed rule, record:

- exact path and kind;
- why it contains reconstructible cache rather than user source;
- recovery/rebuild source;
- required process/bundle subjects;
- static facts vs runtime facts;
- known counterexamples/lookalikes;
- mount/symlink/user-ownership behavior;
- whether default Ready or explicit Review is justified.

Task 27 result: npm and pip may become Ready, Go build remains explicit Review,
and uv is removed from the executable profile. Do not silently choose
alternatives.

### Step 4: Decide authorization semantics in ADR 0011

ADR 0011 must decide:

- plan vs selection vs Policy vs authorization responsibilities;
- default-selection rule;
- explicit Review selection;
- 30-second one-shot authorization;
- stale reasons and no-bypass transitions;
- layered pure/filesystem Policy;
- overlap conflict behavior;
- scan/settings/history/execution mutual exclusion;
- cancellation before/between actions.

### Step 5: Decide crash/Manifest semantics in ADR 0012

ADR 0012 must decide:

- journal schema and lifecycle;
- write-ahead action states;
- crash recovery and `outcomeUnknown`;
- insert-only Manifest;
- Manifest persistence failure recovery without rerunning actions;
- Trash receipt privacy;
- system observation and unexplained delta;
- evidence expiry and 90-day minimal audit.

### Step 6: Review and verify

Run:

```bash
scripts/check-doc-links
git diff --check
```

Perform code/design review against the live Action/Policy/Store APIs. This Task
adds no product code and does not enable Review.

Suggested commit subject:

```text
docs: define safe execution architecture gates
```

---

## Task 28: Cleanup Domain v2, Evidence Store v3 and Execution Journal

### Files

- Modify: `Sources/StornautCore/Domain/DomainPrimitives.swift`
- Modify: `Sources/StornautCore/Domain/CleanupPlanning.swift`
- Modify: `Sources/StornautCore/Domain/CleanupManifest.swift`
- Create: `Sources/StornautCore/Actions/CleanupRunJournal.swift`
- Modify: `Sources/StornautCore/Evidence/EvidenceStore.swift`
- Add/update anonymous domain and migration fixtures/tests
- Create: `docs/plans/active/task-28-implementation-brief.md`

### Purpose

Make persisted execution records closed, bounded, versioned and crash-safe
before any filesystem action is product-wired.

### Step 1: Write red domain tests

Tests must reject:

- unsupported/future domain versions;
- plans without one session/scope/catalog binding;
- duplicate/overlapping item identities;
- action/profile mismatch;
- missing expected identity or byte facts;
- Policy decisions not bound to a plan item/fingerprint;
- allowed Review decisions without explicit user-selection evidence;
- persisted authorization/capability data;
- journal records containing exact original paths or Trash destination URLs;
- Manifest records that mix Trash and permanent bytes;
- successful Trash records without recovery/result truth;
- failed records without typed error;
- duplicate action IDs;
- inconsistent aggregate totals;
- Manifest mutation/replacement.

### Step 2: Version cleanup records without weakening old decoders

- Add `DomainSchemaVersion.v2`.
- Audit every existing domain decoder so v1-only records explicitly reject
  unsupported versions.
- Cleanup Plan, Policy Decision and Manifest decode v1 historical fixtures and
  migrate into conservative v2 projections.
- New execution writes use v2.
- Do not create `CleanupPlanV2`/`ManifestV2` parallel public types.

### Step 3: Add the execution journal domain

Define internal bounded records for:

- run ID, plan ID, ordered selected IDs and selection generation;
- prepared/started/outcome/finalization states;
- expected identity and action fingerprint;
- typed result plus stable destination identity/recovery state, but not exact
  original or Trash paths;
- stop-after-current request;
- updated/expiry timestamps;
- recovery classification.

The journal contains no raw stdout/stderr, arbitrary command, private content
or authorization token.

### Step 4: Migrate Evidence Store atomically to v3

Add:

- execution journal tables/indexes;
- insert-only final Manifest persistence;
- plan/decision query APIs required by Review/History;
- manifest paging/history APIs;
- corruption isolation;
- separate clear/retention behavior.

Migration requirements:

- fresh, v1, v2 → v3;
- rollback on every injected migration step;
- future schema rejected without mutation;
- existing scan/evidence/local-knowledge data preserved;
- 7-day Plan/path-rich Evidence and 90-day minimal Manifest/audit-pending
  ceilings remain separate;
- deleting scan evidence may remove Plan/decisions, but must not remove a
  retained final Manifest.
- `Clear Evidence` removes Plan/path-rich recovery detail but not a retained
  Manifest or audit-pending journal; `Clear Manifests` removes final Manifests
  and audit-pending journals but never changes user files or Trash.

### Step 5: Add journal recovery tests

Cover every persisted phase:

- prepared: safe to abandon, no write claim;
- started with original identity unchanged: still `outcomeUnknown`; supporting
  observation only, no auto-retry, finalize a conservative Manifest;
- started with original missing/replaced: still `outcomeUnknown`; inspect
  Trash, finalize a conservative Manifest and require a new scan;
- outcome recorded: finalize Manifest without rerunning;
- manifest pending: retry insert-only finalization;
- finalized: delete the journal only after Manifest round-trip verification.

### Step 6: Verify and review

Run focused domain/store/migration/retention tests, then `swift test`,
`scripts/verify`, docs links and diff hygiene. Review for payload bounds,
foreign keys, overwrite paths, authorization persistence and crash windows.

No App CTA is enabled.

Suggested commit subject:

```text
feat: add crash-safe cleanup persistence contracts
```

---

## Task 29: Deterministic Execution Evidence and Cleanup Plan Builder

### Files

- Create: `Sources/StornautCore/Review/ExecutableEvidenceResolver.swift`
- Create: `Sources/StornautCore/Review/CleanupPlanBuilder.swift`
- Create: `Sources/StornautCore/Review/ReviewProjection.swift`
- Modify: `Sources/StornautCore/QuickScan/QuickScanCoordinator.swift`
- Modify: Rule schema/compiler/runtime catalog types
- Modify only the approved exact rule sources
- Add safe-execution rule fixtures and compiler/runtime tests
- Create: `docs/plans/active/task-29-implementation-brief.md`

### Purpose

Produce truthful Review candidates and an immutable Plan without granting
execution authority.

### Step 1: Write compiler/profile rejection tests

An execution profile is rejected unless:

- the rule has one exact non-wildcard directory path;
- `recommendedAction == moveToTrash`;
- recovery guidance and high confidence are present;
- every required evidence/activity key has one closed resolver;
- process/bundle subject lists are bounded, unique and typed;
- no protected/unknown/veto rule has a profile;
- the rule ID is in the explicitly approved Phase C allowlist;
- provenance/positive/lookalike/active fixtures exist.

The compiler must prove that no other rule accidentally gains execution
eligibility.

### Step 2: Add shared closed deterministic resolvers

Resolvers may use only:

- exact rule match/provenance assertions approved by Task 27;
- current file metadata/ownership/identity;
- current process/App snapshot;
- fixed Git provider where a future approved profile requires it.

They may not:

- read arbitrary content;
- use Shell;
- call Codex/Probe/Adapter;
- infer inactivity from absent permission;
- treat stale Evidence as current;
- satisfy an unknown evidence key by naming convention.

The same closed resolver feeds new Quick Scan classification and Review
refresh. Collect one bounded running-activity snapshot per scan/refresh, not
one whole-system enumeration per row. Provider failure makes dependent items
Unknown/denied.

### Step 3: Implement the accepted narrowed initial profile

Task 27 confirms:

- promote `cache-npm-content` and `cache-pip` to
  `readyToReclaim` only when all closed evidence is present;
- keep `cache-go-build` `reviewRecommended`;
- keep `cache-uv` `reviewRecommended` without an execution profile;
- attach explicit process/bundle subjects and deterministic evidence mapping;
- preserve all other rule dispositions/actions.

Any active/unknown/missing-evidence case remains Protected/Unknown.

### Step 4: Build Plans from full persisted candidates

`CleanupPlanBuilder`:

- loads one retained terminal scan session and full candidate pages from
  Evidence Store;
- rejects cancelled/failed/uncommitted or corrupt terminal truth;
- rejects an older catalog/profile generation and asks for `Scan Again`;
- leaves persisted Quick Scan classifications immutable;
- includes only persisted Ready/Review classifications with an approved
  execution profile; fresh Review evaluation may preserve or downgrade them,
  never promote persisted Protected/Unknown;
- binds session, scope, root, catalog version and exact identities;
- limits one plan to at most 100 executable items;
- detects parent/child overlap;
- includes only execution-profile candidates;
- produces deterministic stable order and IDs with injected clock/ID sources;
- persists the proposal and auditable evidence lineage;
- exposes Protected/Unknown and other non-profile candidates separately for
  Review UI without placing them in the executable Plan item list.

### Step 5: Prove default selection policy

Tests cover:

- only current Ready profile items selected;
- Go build Review profile unselected;
- Protected/Unknown disabled;
- old-catalog scans require `Scan Again`;
- fresh Review evidence cannot promote persisted Protected/Unknown;
- unsupported rules visible but non-executable;
- Codex source badge cannot select/promote;
- plan generation contains no authorization;
- limited permission cannot create bytes or eligibility;
- one-root binding;
- empty valid plan state.

### Step 6: Benchmark and verify

Use anonymous 4,000+ candidate fixtures:

- bounded memory and page size;
- plan build under an evidence-defined threshold;
- one running snapshot per refresh;
- deterministic output;
- no target write, Codex, Process outside fixed Activity, Adapter or
  Registered Action.

Run focused tests, compiler gates, `scripts/verify`, review and docs.

Suggested commit subject:

```text
feat: build deterministic reclaim plans
```

---

## Task 30: Pure Cleanup Policy, Fresh Revalidation and Authorization

### Files

- Create: `Sources/StornautCore/Policy/CleanupPolicyGate.swift`
- Create: `Sources/StornautCore/Policy/CleanupAuthorization.swift`
- Modify/harden: `Sources/StornautCore/Policy/ActionPolicyGate.swift`
- Add Policy fixtures and adversarial tests
- Create: `docs/plans/active/task-30-implementation-brief.md`

### Purpose

Turn a selected Plan into explicit allow/deny decisions and a one-shot
authorization without performing a write.

### Step 1: Write pure Policy tests first

Reject:

- expired plan;
- missing/different scan session or scope;
- catalog version drift;
- item/snapshot/classification/rule mismatch;
- identity, kind, size, allocated bytes or mtime drift;
- missing/stale/expired Evidence;
- contradicted/unavailable Activity;
- Protected/Unknown;
- Review without explicit selection;
- action not `moveToTrash`;
- profile/allowlist mismatch;
- symlink/mount/root/HOME/denylist/outside-root;
- overlap conflicts;
- duplicate selected IDs;
- selected count > 100;
- stale selection generation;
- confirmation fingerprint mismatch.

Every deny returns stable localized reason keys and affected item IDs.

### Step 2: Implement pure `CleanupPolicyGate`

The pure gate receives complete typed facts and produces one
`PolicyDecision` per selected item. It performs no filesystem I/O and creates
no executable token.

Allowed Ready requires default/explicit selection. Allowed Review requires
explicit selection. Protected/Unknown always deny.

### Step 3: Add fresh context collection

The product service collects:

- current root access lease;
- current `FileIdentity`;
- one current running App/process snapshot;
- fixed Git status only for profiles that require it;
- current catalog/rule/profile;
- current Evidence freshness;
- current volume identity.

The maximum age of the execution context used to mint authorization is 30
seconds. This age is measured independently from the Plan/Evidence retention
window. Any provider failure blocks dependent items.

### Step 4: Add one-shot authorization

Authorization creation requires:

- all selected decisions allowed;
- final confirmation of exact count/action/bytes;
- current selection generation;
- a deterministic decision fingerprint;
- no active scan/settings/history mutation/execution.

Authorization:

- is non-`Codable`;
- has internal construction;
- must be admitted and consumed within 30 seconds;
- is consumed exactly once;
- does not abort an admitted batch merely because wall time later exceeds 30
  seconds;
- cannot be copied into Local Knowledge/Manifest;
- becomes invalid after refresh or selection change.

### Step 5: Add stale sheet contract

Revalidation failure freezes Review and returns:

- only affected items;
- identity/activity/evidence/catalog/root reason;
- `Refresh Affected Items`;
- `Cancel`.

There is no bypass, retry execution or checkbox mutation inside the sheet.

### Step 6: Verify and review

Run focused Policy/adversarial/concurrency tests, `swift test`,
`scripts/verify`, source-boundary scripts and docs. Review specifically for
capability reuse, clock/TOCTOU windows, fail-open provider errors and hidden
Review promotion.

No filesystem action is product-enabled yet.

Suggested commit subject:

```text
feat: enforce reclaim authorization policy
```

---

## Task 31: Serial Trash Execution, Journal, Manifest and Accounting

### Files

- Create: `Sources/StornautCore/Actions/CleanupExecutionCoordinator.swift`
- Create: `Sources/StornautCore/Actions/CleanupExecutionState.swift`
- Modify: `ActionExecutor.swift`, `ActionExecution.swift`,
  `TrashMoving.swift` only as required by ADR 0011/0012
- Create: `Sources/StornautCore/Accounting/CleanupAccounting.swift`
- Add coordinator/journal/crash/accounting tests
- Create: `docs/plans/active/task-31-implementation-brief.md`

### Purpose

Close the Core vertical slice with injected fake Trash first, while keeping
the real App Trash dependency disabled until the final Task gate.

### Step 1: Write state-machine and no-write tests

Prove:

- missing/expired/consumed authorization performs zero adapter calls;
- any deny performs zero adapter calls;
- journal persistence failure before action performs zero writes;
- cancellation before first action performs zero writes;
- stop-after-current starts no next action;
- selection/order cannot change after authorization;
- concurrent runs are rejected;
- scans/history/settings mutations are rejected while execution is active;
- authorization admission after its deadline performs zero writes, while an
  already admitted batch may continue only through per-item fresh
  revalidation.

### Step 2: Implement serial coordinator

For each ordered selected item:

1. persist prepared journal state;
2. collect fresh context;
3. run pure Policy again;
4. call `ActionExecutor.preflight`;
5. persist `actionStarted`;
6. immediately call `ActionExecutor.execute`, which revalidates
   `ActionPolicyGate`;
7. run typed postflight;
8. persist outcome before moving to the next item.

Only `.moveToTrash` is accepted. Any registered action at this boundary is a
programming/policy error and performs no write.

### Step 3: Preserve partial results

- independent Trash failure records a failed row and may continue;
- continuation after a Trash failure is allowed only when fresh post-failure
  identity proves that exact original remains unchanged;
- stale/revalidation failures, postcondition uncertainty and any
  `outcomeUnknown` stop the batch;
- stop-after-current records remaining items as cancelled/not-started;
- no success is rolled back implicitly;
- no failed row is converted to permanent delete;
- a path with unknown crash outcome is not retried automatically.

### Step 4: Build truthful accounting

Collect:

- planned logical/allocated;
- processed logical/allocated;
- moved-to-Trash logical/allocated;
- permanent release = zero;
- volume free before/after from system source;
- free delta;
- unexplained delta;
- source/sample timestamps.

All arithmetic is checked and bounded. A volume sample failure does not erase
action outcomes; system observation becomes unavailable/partial.

### Step 5: Finalize immutable Manifest

- derive every record and summary from journal outcomes;
- insert once, while allowing idempotent same-ID/same-payload finalization
  retry;
- same ID with different bytes is an integrity error, never an update;
- verify round-trip and identity;
- mark journal finalized;
- emit one immutable result projection.

If Manifest persistence fails:

- keep journal/in-memory outcomes;
- enter `auditPending`;
- allow only idempotent `Retry Saving Audit`;
- never rerun actions;
- do not display normal `Completed`.

### Step 6: Crash recovery

On startup or workflow entry:

- detect unfinished journals;
- classify prepared/started/outcome/manifest-pending states;
- perform read-only identity/Trash relationship checks;
- produce conservative recovery state;
- classify every started-without-outcome action as `outcomeUnknown` regardless
  of its current path observation;
- mark all later not-started actions cancelled, then finalize an immutable
  Manifest containing the Unknown record;
- if that Manifest cannot be persisted, retain `auditPending`; otherwise
  require user inspection plus a new scan before a new plan.

### Step 7: Verify and review

Use only fake Trash and uniquely marked temporary fixtures in the ordinary
suite. Run focused tests, sanitizer-relevant suites, `scripts/verify`, review
and docs. Assert no real Registry definitions, permanent delete, Shell, Codex,
Adapter, background service or target write outside the injected fixture.

Suggested commit subject:

```text
feat: orchestrate crash-safe trash execution
```

---

## Task 32: Review Workflow App State and Native UI

### Files

- Create: `StornautApp/Review/`
- Modify: App state/dependencies and Scan workspace routing
- Modify: `ScanView` disabled Review affordance
- Add App model/reducer/fixture/UI tests and localization
- Create: `scripts/verify-review-boundaries`
- Create: `docs/plans/active/task-32-implementation-brief.md`

### Purpose

Implement the approved Decision Table + optional Evidence Inspector without
making Views the execution boundary.

### Step 1: Add typed App workflow routing

Keep `Scan` selected in the top-level sidebar. Add an internal workflow route:

```text
results → review → cleanupResult → results
```

No new `AppDestination` is created.

Review state covers:

- loading/build failure;
- current plan;
- selection generation;
- preflight;
- stale affected items;
- confirmation;
- executing progress and `Stop After Current Action` intent routed through the
  typed workflow model;
- cancellation/back.

### Step 2: Add deterministic DEBUG fixtures

Fixtures cover:

- two default-selected Ready exact caches;
- one unselected Go build Review item;
- uv visible as non-executable Review context;
- Protected and Unknown disabled;
- empty executable plan;
- overlap conflict;
- stale identity/activity/catalog/evidence;
- limited permission;
- preflight provider failure;
- Registered Actions deferred/empty.

Release bundle gates must prove all fixture markers are absent.

### Step 3: Implement the approved Review composition

Use:

- native grouped high-density `Table`/outline;
- columns Item, Last Active, Recovery, Action, Size;
- five independent groups and canonical one-line explanations;
- focus/highlight separate from checkbox selection;
- Inspector only on demand or `⌥⌘I`;
- one filled `Move N Items to Trash` CTA;
- separate selected count and estimated Trash bytes;
- permanent release shown separately as zero/not available;
- no AI decoration on known rules;
- no row-level cleanup button.

The Registered Actions group is empty/deferred in production and cannot load
the fake fixture.

### Step 4: Implement native confirmation/stale interactions

Final confirmation sheet names:

- item count;
- action `Move to Trash`;
- estimated moved bytes;
- recoverability caveat;
- selected Review items;
- no permanent release claim.

Stale sheet has only refresh/cancel. Keyboard focus moves to the sheet heading
once; it does not trap the user after dismissal.

### Step 5: Accessibility and interaction gates

- full keyboard traversal and Space checkbox behavior;
- visible focus rings;
- VoiceOver state/group/selection/action labels;
- disabled reasons exposed semantically;
- controls use native macOS control sizes and hit regions; no iOS-specific
  44-point rule is imposed on dense macOS Table rows;
- no color-only status;
- Dynamic Type/system text styles;
- one primary action;
- no nested horizontal scrolling at minimum window size.

### Step 6: Actual App verification

Build/test, launch actual signed Debug App, use read-only Peekaboo for:

- Review default Dark/Light;
- Inspector;
- stale plan;
- limited/empty state;
- English/`zh-Hans`.

XCUITest owns interaction and screenshot contracts. Do not execute real Trash
in this Task; dependencies use a fake coordinator.

### Step 7: Verify and review

Run App tests, XCUITest/screenshots, boundary script, `scripts/verify`, review
and docs.

Suggested commit subject:

```text
feat: add evidence-driven reclaim review
```

---

## Task 33: Cleanup Result, Manifest Detail and Recovery UI

### Files

- Create: `StornautApp/Cleanup/`
- Extend typed App state/dependencies
- Add localization, App tests, XCUITest screenshots
- Create: `scripts/verify-cleanup-result-boundaries`
- Create: `docs/plans/active/task-33-implementation-brief.md`

### Purpose

Render execution truth from one immutable Manifest projection, including
partial/audit-failure states.

### Step 1: Write model tests first

Cover:

- Completed;
- Completed with issues;
- Failed before any write;
- stop after current;
- audit pending;
- recovered interrupted run/outcome unknown;
- Trash destination unavailable;
- system observation unavailable;
- linked Evidence expired;
- corrupt Manifest isolated.

Every aggregate must equal the Manifest projection. Tests reject View-side
totals that add Trash to permanent/free delta.

### Step 2: Implement Reversible First layout

- Scan remains selected.
- Header shows outcome and Manifest persistence.
- Hero says literal `Moved to Trash`, count and recovery caveat.
- `Open Trash` appears once.
- Processed, Permanently Released and System Observation are separate.
- Accounting Details is collapsed.
- Result table shows action/result/size/recovery.
- Footer contains `View Manifest` and one filled `Done`.

### Step 3: Implement partial/failure grammar

- amber only for overall partial state;
- red local to actual failed/audit durability rows;
- failed Trash says `Original remains in place` only when known;
- unknown crash outcome says it is unknown and never offers retry;
- retry appears only after returning to Review and fresh revalidation;
- no permanent-delete recovery.

### Step 4: Manifest detail

Show:

- ordered journal-derived action timeline;
- Policy disposition/reasons;
- started/finished timestamps;
- typed errors;
- candidate/processed/Trash/permanent/system measures;
- evidence lineage/expiry and exact path/recovery detail only while linked
  Evidence is retained;
- no raw JSON, stdout/stderr or hidden reasoning.

### Step 5: Open Trash boundary

Use a typed App dependency backed by the system Trash location. The View does
not call `NSWorkspace`. Failure is local and does not change Manifest state.
No restore or Trash emptying action is added.

### Step 6: Motion and accessibility

- one 200–300 ms completion transition;
- `accessibilityReduceMotion` removes it;
- VoiceOver announces terminal status, succeeded/failed counts and Trash vs
  permanent distinction;
- tab order follows the approved hierarchy;
- numbers use localized tabular formatting.

### Step 7: Actual App verification

Use fake execution fixtures for Completed/partial/audit-pending/outcome-unknown
Dark/Light and English/`zh-Hans`. Build, launch, Peekaboo inspect, XCUITest,
screenshots, boundary script, full verifier, review and docs.

Suggested commit subject:

```text
feat: present truthful cleanup results
```

---

## Task 34: Manifest-aware History and Retention

### Files

- Extend Core history store/query types
- Modify `StornautApp/History/`
- Add manifest history fixtures/tests/UI tests
- Create: `docs/plans/active/task-34-implementation-brief.md`

### Purpose

Add real Cleanup Manifest records to History without fabricating causality or
breaking scan-history retention.

### Step 1: Extend typed History union

History supports:

- Quick Scan session;
- Cleanup Manifest;
- corrupt scan row;
- corrupt Manifest row.

No Deep Dive record is fabricated while Deep Dive remains unavailable in this slice.

### Step 2: Add Manifest paging and deletion

- stable date/type paging;
- independent 90-day expiry;
- insert-only identity;
- isolate corrupt Manifest;
- delete one Manifest with confirmation;
- delete the associated audit-pending journal/minimal recovery record, if any,
  in the same local-record transaction;
- scan/evidence deletion does not delete retained Manifest;
- Manifest deletion does not touch files/Trash/Local Knowledge.

### Step 3: Project evidence-expired history

While linked Plan/Evidence exists, show item names/evidence lineage. After
7-day expiry:

- retain minimal action/result/accounting/error;
- retain stable action/item IDs, but not item names, exact original paths or
  Trash destination URLs;
- show `Evidence expired`;
- do not reconstruct paths/evidence from guesses;
- keep 90-day expiry.

### Step 4: Update master-detail UI

Reuse the existing History structure:

- type filter includes Cleanup Manifest;
- navigator key metric is moved-to-Trash bytes, not `Freed`;
- detail keeps Trash/permanent/free/unexplained separate;
- Related Records indicates lineage only;
- Export/Delete remain secondary;
- no filled primary CTA.

### Step 5: Update Storage Trend safely

Manifest event markers may appear on the time axis, but the persistent
non-causality caption remains. Free-space observations do not establish that a
Manifest caused a storage change.

### Step 6: Verify and review

Run retention, migration, corrupt-record, App model, deletion, XCUITest,
Light/Dark/English/`zh-Hans`, boundary, full verifier, review and docs.

Suggested commit subject:

```text
feat: add cleanup manifests to history
```

---

## Task 35: Signed-App Trash Evidence and Phase C Gate

### Files

- Create: `scripts/verify-phase-c-gate`
- Add opt-in signed-App disposable Trash diagnostic harness
- Create: `docs/reports/epic-8-safe-execution-validation-report.md`
- Create: `docs/reports/epic-8-task-35-review.md`
- Update ADRs 0011/0012 with accepted evidence
- Update roadmap/handoff/router after all gates pass
- Move approved plan and Task 27–35 briefs to `plans/completed/`
- Create: `docs/plans/active/task-35-implementation-brief.md`

### Purpose

Prove the complete deterministic product flow without touching existing user
data and close Phase C only with one unified verifier.

### Step 1: Run the full anonymous safety matrix

Required suites:

- rule execution profile/compiler;
- plan/selection/overlap;
- pure Policy/adversarial stale;
- one-shot authorization;
- ActionPolicy filesystem identity;
- fake Trash success/failure/collision;
- journal crash recovery;
- Manifest insert-only/retention/corruption;
- accounting separation;
- Review/Result/History models;
- no Codex/Adapter/Registered Action/permanent delete.

### Step 2: Run deterministic end-to-end product fixtures

Use a uniquely marked temporary tree and injected fake Trash:

```text
Quick Scan
→ evidence refresh
→ plan
→ default/explicit selection
→ policy
→ confirmation fixture
→ authorization
→ execute
→ journal
→ manifest
→ result/history
```

Cover complete, partial, stale, stop-after-current, manifest-persistence
failure and recovered crash.

### Step 3: Run opt-in signed-App real Trash diagnostic

The diagnostic:

- creates an isolated, uniquely marked temporary Primary Scan Root and an
  approved exact-rule-shaped cache fixture beneath it; it never reuses the
  user's real npm, pip, uv or Go cache;
- uses a diagnostic-only store/settings namespace so no product history or
  Primary Root preference is changed;
- runs through the locally signed App product coordinator;
- requires a fresh explicit opt-in at Task 35; approval of this plan alone is
  not that runtime opt-in;
- uses real Foundation Trash;
- records returned destination and identity;
- opens no private user path;
- attempts to restore the disposable item only through an explicit,
  identity-checked move of that uniquely marked fixture;
- removes only fixture data outside Trash; if restoration is unavailable or
  fails, it leaves the marker in Trash, reports the exact residual state, and
  never permanently deletes or empties it merely to make the diagnostic pass;
- never empties Trash;
- changes no TCC/FDA/Accessibility/Event Synthesizing setting;
- reports App identity, entitlement/current permission context and limitations.

A CLI/test-binary probe cannot replace this evidence. Passing the diagnostic
is the gate that allows the normal App dependency graph to receive the real
`FileManagerTrashAdapter`; failure keeps Review useful but write-disabled,
records a no-go report and stops Phase C closure.

The diagnostic uses a diagnostic-only, explicit opt-in dependency injection
through the same product coordinator. After it passes, Task 35 separately
wires the real adapter into the normal App dependency graph, reruns focused
safety/UI tests, and then runs the uninterrupted unified verifier. The
diagnostic path cannot be reachable from a normal launch or Release UI.

The final uninterrupted verifier invokes the diagnostic through one explicit
opt-in environment/input contract defined in the Task 35 brief. It must not
accept a stale receipt from an earlier build as a substitute for the current
signed App run.

### Step 4: Benchmark bounded planning/policy

Record:

- 4,000+ candidate Review load;
- 100 selected-item maximum;
- plan/evidence refresh elapsed/RSS/store;
- one process snapshot per refresh;
- bounded Git invocations;
- Policy/authorization latency;
- journal/Manifest size;
- stop-after-current latency outside synchronous Trash.

Thresholds must be justified in the Task brief and may not be raised merely to
pass.

### Step 5: Run actual App acceptance

Require:

- Review default/Inspector/stale/confirmation;
- Cleanup complete/partial/audit pending/outcome unknown;
- Manifest History/evidence expired/corrupt;
- System/Light/Dark, English/`zh-Hans`;
- keyboard, VoiceOver labels and Reduce Motion contracts;
- XCUITest interactions and all screenshot contracts;
- read-only Peekaboo actual-window inspection.

### Step 6: Audit scope and bundle

Search source, package graph and built Release App for:

- Codex/Probe/Adapter reachability;
- any real Registry definition;
- arbitrary executable/arguments/Shell;
- permanent-delete fallback;
- `removeItem` or write APIs reachable for selected targets;
- authorization persistence;
- background/MenuBar/scheduler/login item;
- telemetry/network/remote rules;
- DEBUG execution fixture leakage;
- new dependency/license drift.

### Step 7: Write separate gate decisions

The report decides:

1. Review/selection;
2. deterministic execution evidence;
3. pure Policy and stale handling;
4. one-shot authorization;
5. MoveToTrash App-context safety;
6. journal/Manifest durability;
7. accounting truth;
8. Review/Result/History UI;
9. Deep Dive — outside Phase C; capability-first runtime gate pending;
10. Registered Actions — remain deferred;
11. release/distribution — remains not evaluated.

### Step 8: Final code review and unified verifier

Run a fresh whole-diff code review. Fix confirmed findings with regressions.
Then run one uninterrupted `scripts/verify` that owns `scripts/verify-phase-c-gate`.
Focused green checks cannot be combined as a proxy.

### Step 9: Close lifecycle

Only after the final gate:

- check every Task 27–35 box;
- archive the plan/briefs;
- leave no executable active plan;
- update docs/handoff/roadmap;
- commit/push Task 35;
- verify `HEAD == origin/main`.

Suggested commit subject:

```text
docs: close safe execution vertical slice
```

## 8. Verification Matrix

| Claim | Required evidence |
| --- | --- |
| Only approved exact rules can execute | compiler allowlist + generated manifest + negative catalog audit |
| Ready defaults are safe | complete fresh evidence + Policy preview + exact two-rule assertion |
| Review requires user intent | selection-generation and confirmation tests |
| Protected/Unknown cannot execute | pure Policy and App disabled-state tests |
| No overlapping actions | plan conflict fixtures and UI blocking state |
| Authorization cannot be replayed | one-shot/expiry/generation/concurrency tests |
| Stale has no bypass | transition tests + XCUITest stale sheet |
| Filesystem identity is fresh | preflight/revalidation/adversarial replacement tests |
| Provider failure fails closed | Git/process/FDA/metadata failure fixtures |
| Trash has no permanent fallback | structural source audit + fake/real diagnostics |
| Cancellation is truthful | before/between actions and synchronous-call UI contract |
| Crash cannot duplicate action | journal recovery tests and no-auto-retry assertions |
| Manifest is immutable | insert-only storage and overwrite rejection |
| Manifest failure is separate | audit-pending flow and persistence retry without execution |
| Accounting is not mixed | domain invariants + Result/History model tests |
| Evidence expiry preserves audit | 7/90-day retention fixtures |
| History isolates corruption | corrupt scan/manifest row tests |
| Views cannot write | source boundary scripts |
| Deep Dive remains outside Phase C | source/package/bundle audit |
| Registered Actions remain deferred | empty production registry and Release bundle audit |
| App context is measured | signed-App disposable real Trash diagnostic |
| UI is native and accessible | App tests, XCUITest, screenshots, Peekaboo, keyboard/VoiceOver/Reduce Motion checks |

## 9. Per-Task Quality Contract

Every Task after approval follows:

```text
Upstream Study / accepted prior study
→ Task implementation brief
→ tests/fixtures first
→ implementation
→ focused safety checks
→ code review
→ confirmed finding regressions
→ actual App/Peekaboo when UI is involved
→ unified scripts/verify
→ docs/provenance
→ dedicated commit
→ push origin/main
```

Before each commit:

```bash
git status --short
git diff --check
```

Commit messages end with exactly one:

```text
Co-authored-by: TRAE CLI <noreply@bytedance.com>
```

Push with:

```bash
env -u GITHUB_TOKEN -u GH_TOKEN git push origin main
```

Do not push known failures, real user-path fixtures, raw databases,
`.xcresult`, screenshots outside approved assets, credentials, raw content,
authorization tokens or temporary Trash receipts.

## 10. Plan Self-Review

### Roadmap alignment

- Implements only Phase C deterministic Epic 8.
- Does not start Phase D Deep Dive or Phase E Adapters/Registered Actions.
- Reuses Phase B facts and Phase A action Spike rather than creating a second
  execution system.

### Safety

- Product write surface is exactly Foundation Trash.
- Two Ready + one Review exact-cache rules are the accepted Task 27 profile;
  uv stays visible but non-executable.
- All other rules remain non-executable.
- Selection is not authority.
- Authorization is one-shot and memory-only.
- Policy and filesystem revalidation are both required.
- The authorization TTL is an admission deadline, not a false mid-batch
  cancellation promise.
- Crash recovery never auto-retries.
- Started-without-outcome is always Unknown, regardless of current path state.
- No permanent fallback exists.

### Privacy

- No content reading is added.
- Journal and Manifest remain bounded, local and typed.
- 7-day path-rich Evidence/Plan and 90-day minimal Manifest/audit-pending
  ceilings remain separate.
- Authorization is never persisted.
- Exact original/Trash paths remain only in bounded linked recovery evidence
  and do not enter the exported minimal audit after that Evidence expires.

### Accounting

- Candidate, processed, Trash, permanent and free delta remain distinct.
- Phase C permanent release is always zero.
- System observations remain non-causal.
- Partial/unavailable samples do not invent zero.

### UI/UX

- Review/Result are Scan workflow pages, not navigation destinations.
- One primary action per page.
- Native Table/Inspector/sheets.
- Focus and checkbox selection remain distinct.
- Stale has no bypass.
- Result is reversible-first and Manifest-derived.
- Light/Dark, localization, keyboard, VoiceOver and Reduce Motion are gates.
- Existing generated images remain composition references; no new asset is
  required by this plan.

### Failure behavior

- Journal failure before action means zero writes.
- Action failure preserves independent successes.
- Manifest failure becomes audit pending.
- Crash uncertainty becomes outcome unknown.
- Retry requires a new Review/fresh authorization.
- No UI claims success when durability or outcome is unknown.

### Performance

- Candidate/Review records are paged and bounded.
- Selection maximum is 100.
- Activity process snapshot is shared per refresh.
- Git calls are deduplicated and bounded.
- No whole-disk in-memory graph is reintroduced.

### Licensing

- Task 27 refreshes exact upstream commits/licenses.
- Apple platform APIs add no package dependency.
- GPL/restricted code remains behavior-only.
- No external action/tool ships in Phase C.

## 11. Approval Checklist

The user should explicitly review these plan decisions before approval:

1. **Scope:** MoveToTrash only; no real Registered Action.
2. **Initial execution profile:** Ready = npm/pip exact caches; Review = Go
   build cache; uv and all other rules non-executable.
3. **Authorization:** final confirmation creates a 30-second, one-shot,
   memory-only authorization.
4. **Selection:** only Ready defaults selected; Review explicit; overlap
   rejected.
5. **Cancellation:** before/between actions only; no false mid-Trash cancel.
6. **Crash model:** private write-ahead journal, immutable final Manifest,
   outcome-unknown with no auto-retry.
7. **Recovery:** Open Trash only; no guaranteed Undo/restore/empty Trash.
8. **Accounting:** Trash/permanent/free delta never combined.
9. **Lifecycle:** Tasks 27–35, one reviewed/verified commit and push each.
10. **Gates:** signed-App disposable real Trash diagnostic before Phase C
    completion; approving this plan accepts the gate but is not the later
    runtime opt-in.

This checklist was approved on 2026-08-11. Task 27 may proceed; every later
Task remains bound to its own study/brief/tests/review/verification/commit/push
gate. The Review button and real Trash dependency remain disabled until the
specific gates above allow them.
