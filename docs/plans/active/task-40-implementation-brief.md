# Task 40 Implementation Brief — Evidence Report and Conservative Review Projection

> **Status:** Approved; blocked on pushed Task 39 Ready baseline.
>
> **Parent plan:**
> [Phase D Conditional Deep Dive](phase-d-conditional-deep-dive.md)

## 1. Objective

Task 40 converts retained, strict advisory Investigation truth into safe
product-readable evidence and conservative Review candidates:

```text
immutable Investigation report + retained IDs
→ Task 37 source rejoin against current Store
→ typed source-aware evidence summaries
→ deterministic current-record reconciliation
→ conservative Review rows
→ existing CleanupPlanBuilder only where deterministic profiles admit
→ unresolved-target continuation Plan
```

Task 40 creates no Agent execution authority. It accepts no model path,
action, disposition, Policy, confirmation or authorization field. Agent-only
rule misses are capped at `Review Recommended`, remain unselected and
non-executable. Only the existing Phase C `CleanupPlanBuilder` may create a
Cleanup Plan, and only from independently current deterministic
Rule/Execution Profile evidence.

It does not add App workflow/UI, disclosure, normal Deep Dive availability,
Trash, Registered Actions or a second Policy/Executor path.

## 2. Preconditions and Inputs

Task 40 starts after Tasks 36–39 are independently committed and pushed. The
Task 39 blocked/no-go disposition does not satisfy that sequential prerequisite;
starting Task 40 requires either a Task 39 Ready baseline or an explicitly
approved plan amendment.
Inputs are:

- one persisted Task 37 immutable partial/final Investigation report;
- exact Investigation/run/report/target/proposal IDs;
- report source labels, uncertainty, counter-evidence, unresolved targets and
  degradations;
- persisted Task 36 Plan/source fingerprints;
- current Store v4 records;
- current built-in Rule Catalog and Execution Profile Catalog;
- current existing `CleanupPlanBuilder`.

No raw model output, raw JSONL, prompt, filesystem path or runtime event is an
input to public projection APIs.

## 3. Core Report Normalization

### 3.1 Typed report view

Add a bounded Core projection, tentatively:

```text
InvestigationReportProjection
InvestigationFindingProjection
InvestigationEvidenceSummary
InvestigationProposalProjection
InvestigationContinuationProjection
```

It contains only:

- retained typed IDs;
- user-facing summary keys or bounded sanitized report text;
- exact evidence source kind;
- uncertainty/confidence as advisory metadata;
- counter-evidence and unresolved reason keys;
- capability/runtime degradation;
- coverage and budget/stop summary;
- current source status;
- Review eligibility.

It never contains an executable absolute path, shell text, arbitrary URL,
action, Policy result, authorization or raw command/tool payload.

### 3.2 Source labels

Preserve exact source distinctions:

- Surveyor/Quick Scan deterministic source;
- Rule Catalog;
- current Activity;
- Probe Broker structured evidence;
- direct read advisory;
- shell/unified exec advisory;
- public web/search/fetch provenance;
- image inspection;
- skill/subagent advisory;
- system/runtime metadata.

Direct tools cannot be relabeled as Probe-audited. Model prose cannot become
system/Policy evidence. Persisted web display uses only Task 37 safe origin and
typed redaction/rejection reason.

### 3.3 Bounded content

All report text:

- has explicit scalar/UTF-8 byte bounds;
- rejects controls, hidden markup and invalid Unicode;
- is displayed as text only;
- is never interpolated into commands/paths/URLs;
- has deterministic truncation with a visible marker;
- carries no hidden reasoning/raw tool transcript.

Unknown/oversized/invalid fields isolate the affected report/finding rather
than mutating unrelated retained truth.

## 4. Exact Current-Store Reconciliation

### 4.1 Rejoin barrier

Before any projection, invoke Task 37 barrier 7:

```text
Review projection source rejoin
```

The Store recomputes exact membership, bytes and fingerprint. Outcomes:

- `matching`: projection may continue;
- `stale`: preserve historical report, disable current Review planning;
- `expired`: preserve bounded History metadata, no current projection;
- `corrupt`: isolate and require safe recovery/rescan;
- `missing`: no current projection.

ID equality alone is insufficient.

### 4.2 Retained-ID resolution

For each finding/proposal:

- target ID must belong to the admitted Plan;
- source binding must match the retained target;
- snapshot/classification IDs are loaded from Store;
- classification must still bind that snapshot/session/scope;
- Space Ledger proposals resolve only their closed measure key and invent no
  path;
- proposal ID must be unique and report-owned;
- every current record must strict-decode and pass storage identity.

A model-provided path or mismatched ID fails the proposal. It is never used as
a fallback lookup.

### 4.3 Freshness

Distinguish:

- historical Investigation evidence;
- current deterministic evidence;
- stale/expired/corrupt evidence;
- unavailable current source.

Historical model confidence cannot make a stale current record executable.
Current Activity and file identity remain owned by the existing Phase C
planning/Policy flow.

## 5. Conservative Review Projection

### 5.1 Row classes

Add Review-facing rows with one of:

- deterministic executable candidate;
- Agent-assisted review recommended;
- unresolved/needs another Investigation;
- protected;
- stale/expired/corrupt blocked;
- current evidence blocked;
- no execution profile.

The projection preserves the existing four `ReclaimDisposition` values.
Investigation metadata is a separate evidence/rationale layer.

### 5.2 Agent-only rule miss

If Codex identifies an unknown path/artifact for which current deterministic
Rule/Execution Profile admission does not exist:

- maximum disposition: `Review Recommended`;
- `suggestedDefault == false`;
- `eligibility != executable`;
- no `CleanupPlanItem`;
- no action field;
- no expected path/identity accepted from Codex;
- no auto-generated Rule, Execution Profile or Local Knowledge;
- user may inspect or continue Investigation only.

Confidence, repeated model agreement or large expected bytes cannot promote
it to Ready/default-selected.

### 5.3 Existing deterministic match

If an Investigation finding points to a retained current snapshot that the
current deterministic Rule Catalog and Execution Profile already admit:

1. invoke Task 37 barrier 8 before joining the Agent proposal;
2. discard all Agent action/path/disposition concepts;
3. call the existing `CleanupPlanBuilder` for the source Scan/root;
4. use only builder-produced Plan/Review rows;
5. enrich display with advisory Investigation evidence by retained IDs;
6. preserve builder and Policy results unchanged.

Task 40 must not fork `CleanupPlanBuilder`, `ExecutableEvidenceResolver`,
`CleanupPolicyGate` or selection logic.

### 5.4 Protected and Unknown

- current Protected remains Protected regardless of report;
- current Unknown remains Unknown or Review Recommended, never Ready from
  Agent evidence alone;
- a conflict downgrades, never upgrades;
- missing-size Unknown remains unmeasurable, not `0 B`;
- permission gaps are unavailable/unknown, not `0 B`.

## 6. Continuation Planning

Request Store to generate a new run-owned Task 36 `InvestigationPlan` only
from:

- a verified persisted partial report;
- unresolved retained target IDs;
- current Task 37 continuation rejoin `matching`;
- a new caller-created Investigation run ID;
- a valid selected budget preset;
- remaining finite budget/coverage policy selected by Swift.

The public continuation command contains those typed IDs/preset/time only. It
contains no caller-created Plan, target array, fingerprint, manifest or
freshness token. Inside the pinned Task 37 continuation transaction, Store
loads the immutable parent Plan/report, selects the retained unresolved target
subset, invokes the pure Planner/Plan constructor, and persists the new
run-owned Plan plus ordered run-target membership. The parent Plan remains
immutable.

Continuation:

- never resumes/forks a runtime thread;
- never carries unverified events/evidence;
- preserves parent report/run lineage;
- omits terminally resolved targets;
- includes explicit unresolved/degradation reasons;
- recomputes source/target-set/plan fingerprints inside Store;
- fails closed on stale/expired/corrupt source.

Codex cannot add arbitrary new target IDs. Newly discovered unknowns require a
future fresh Swift planner input from retained Store truth.

## 7. Tests First

### 7.1 Report projection

- valid final and partial report;
- every source label;
- bounded text/control/Unicode/truncation;
- web origin redaction/rejection display;
- capability degradation/counter-evidence/unresolved summaries;
- no raw reasoning/tool payload;
- malformed isolated finding does not erase valid siblings.

### 7.2 Rejoin and identity

- exact current source succeeds;
- drift at source row/column/payload/membership blocks;
- stale/expired/corrupt/missing distinct;
- target/proposal/report/run foreign ID rejection;
- classification/snapshot/session/scope mismatch;
- ledger-only target invents no path;
- forged model path ignored/rejected;
- duplicate/conflicting proposal rejection.

### 7.3 Conservative disposition

- Agent-only rule miss max Review Recommended;
- never default selected/executable;
- high confidence/repetition/large size cannot upgrade;
- Protected never upgrades;
- Unknown never becomes measured zero;
- stale historical evidence cannot execute;
- conflict downgrades;
- no execution profile remains non-executable.

### 7.4 Existing Phase C reuse

- deterministic current Rule/Profile match delegates to existing
  `CleanupPlanBuilder`;
- Task 37 barrier 8 called immediately before join;
- output Plan fingerprint/items equal builder output without Agent mutation;
- existing Policy/selection defaults unchanged;
- no second builder/resolver/gate implementation;
- no model action/path/disposition copied into Plan.

### 7.5 Continuation

- verified partial creates a Store-owned new run/Plan;
- resolved targets omitted;
- unresolved targets retained once;
- source fingerprints recomputed;
- stale/expired/corrupt parent/source rejects;
- old thread/session not resumed;
- unverified evidence excluded;
- foreign/new model target rejected.

### 7.6 Structural

Extend boundary checks so Investigation report/projection code cannot:

- import/name Executor/Trash/authorization construction;
- construct `CleanupPlanItem` directly from Agent proposal;
- call filesystem mutation/process execution;
- persist raw model/runtime data;
- add a second Policy or selection implementation.

## 8. Expected Files

```text
Sources/StornautCore/Investigation/InvestigationReportProjection.swift
Sources/StornautCore/Investigation/InvestigationReportReconciler.swift
Sources/StornautCore/Investigation/InvestigationReviewProjection.swift
Sources/StornautCore/Investigation/InvestigationContinuationPlanner.swift
Sources/StornautCore/Review/CleanupPlanBuilder.swift
Tests/StornautCoreTests/InvestigationReportProjectionTests.swift
Tests/StornautCoreTests/InvestigationReportReconcilerTests.swift
Tests/StornautCoreTests/InvestigationReviewProjectionTests.swift
Tests/StornautCoreTests/InvestigationContinuationTests.swift
StornautAppTests/InvestigationReportModelTests.swift
scripts/verify-investigation-boundaries
docs/plans/active/task-40-implementation-brief.md
docs/reports/phase-d-task-40-review.md
docs/agent/coding-agent-handoff.md
docs/plans/active/README.md
docs/plans/roadmap.md
AGENTS.md
```

App source/UI is out of scope. A focused App-model-only test target may validate
public Core projection consumability without adding navigation/state.

## 9. Focused Validation

Run serially:

```text
swift test --filter InvestigationReportProjection
swift test --filter InvestigationReportReconciler
swift test --filter InvestigationReviewProjection
swift test --filter InvestigationContinuation
swift test --filter CleanupPlanBuilder
swift test --filter CleanupPolicy
scripts/verify-investigation-boundaries
xcodebuild ... -only-testing:StornautAppTests/InvestigationReportModelTests
scripts/check-doc-links
git diff --check
```

Then:

```text
swift test --parallel false
scripts/verify --full
```

No real model or signed runtime diagnostic is required unless a regression in
Task 39's closed report contract is specifically implicated.

## 10. Independent Review

Review for:

- model path/action/disposition/Policy acceptance;
- Agent-only Ready/default selection;
- ID-only rejoin;
- stale/expired/corrupt evidence execution;
- Protected/Unknown upgrade;
- missing-size as zero;
- model confidence overriding deterministic classification;
- direct construction of cleanup Plan items;
- second builder/Policy/Executor path;
- source-label inflation;
- unsafe report text interpolation;
- continuation resuming an old runtime thread;
- unresolved/new target injection;
- Task 41–43 scope creep;
- stale docs/broken links.

Fix all P0–P2 findings and rerun affected checks before the final full
verifier.

## 11. Explicit Non-Goals

- App workflow/state/navigation/UI;
- first-use disclosure/Settings;
- signed runtime diagnostic changes;
- normal product Deep Dive availability;
- selection, confirmation, authorization or execution;
- real Trash or Registered Actions;
- new Rule/Execution Profile generation from model output;
- Local Knowledge auto-write;
- Adapters;
- release work.

## 12. Completion and Git

Task 40 completes only when:

- current-store reconciliation and source barriers pass;
- Agent-only rows are never Ready/default-selected/executable;
- existing `CleanupPlanBuilder` is the only cleanup Plan path;
- continuation contracts pass;
- structural boundary verifier passes;
- independent review has zero unresolved P0–P2;
- one uninterrupted authoritative `scripts/verify --full` exits `0`;
- docs keep normal product Deep Dive unavailable;
- a docs-freshness audit verifies every referenced normative document, task
  dependency/status router, ownership/non-goal claim and product-availability
  claim matches the committed diff and canonical contract;
- docs links, credential/artifact hygiene and `git diff --check` pass;
- one independent commit has no Coding Agent co-author trailer;
- `GITHUB_TOKEN` and `GH_TOKEN` are unset before push;
- `HEAD == origin/main` after push.
