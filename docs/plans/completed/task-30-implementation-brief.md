# Task 30 Implementation Brief — Pure Cleanup Policy and One-Shot Authorization

> Status: Completed; implementation, review and final gates passed
>
> Date: 2026-08-13
>
> Baseline:
> `cacdc0dbfc1acfa0645f0305e31f284878865ecd`
>
> Parent plan:
> [Epic 8 Safe Execution Vertical Slice](epic-8-safe-execution-vertical-slice.md)
>
> Accepted decisions:
> [ADR 0011](../../adr/0011-review-policy-authorization.md),
> [ADR 0012](../../adr/0012-cleanup-execution-journal.md) and
> [Task 27 Study](../../upstream-studies/epic-8-safe-execution.md)

## 1. Objective

Task 30 creates the deterministic, write-free admission layer between the
immutable Task 29 Cleanup Plan and the Task 31 serial execution coordinator:

```text
retained Cleanup Plan
+ in-memory Review Selection
+ bounded current Store truth
+ fresh read-only filesystem/activity/catalog context
+ App-owned workflow availability
→ pure per-item Policy Decisions
→ typed stale/blocking result
→ exact final-confirmation summary
→ actor-owned one-shot Execution Authorization
```

The Task is complete only when:

- selection, Policy audit facts and execution authority are separate types;
- current facts are collected by a read-only collector and evaluated by a
  pure Policy gate with no filesystem, Store, process or App I/O;
- every selected item receives an explicit allow or deny decision with stable
  reason keys and affected item identity;
- all provider failures, incomplete truth and drift fail closed;
- a final exact confirmation can mint one non-`Codable`, non-persistable,
  one-shot authorization with a maximum 30-second admission window;
- the authorization is consumed by the first admission attempt, including a
  failed or expired attempt;
- persisted Plans and Policy Decisions cannot mint or replay authority;
- stale output exposes only affected items, refresh, and cancel semantics;
- Store schema remains v3 and Task 29 Rule/Profile semantics are unchanged;
- no Trash call, target mutation, execution coordinator, App Review UI,
  Registered Action, Deep Dive or production CTA is added;
- tests-first evidence, adversarial/concurrency tests, code review,
  focused/full verification, an independent report and one commit/push are
  complete.

Task 30 was implemented tests-first and independently reviewed. Completion
evidence is recorded in
[Task 30 Review](../../reports/epic-8-task-30-review.md).

## 2. Planning Corrections

The parent plan and ADR 0011 remain authoritative. This brief makes the
following implementation-level corrections after inspecting the Task 29
Plan Builder, Store v3, existing `ActionPolicyGate` and App lifecycle state.

### 2.1 Current fact collection and Policy evaluation are separate stages

`CleanupPolicyContextCollector` owns read-only I/O:

- bounded Store reads for the selected Plan items;
- current filesystem identity and path-policy observations;
- one current bounded running-process/App snapshot;
- current Rule and Execution Profile Catalog validation;
- Evidence freshness and exact fingerprint recomputation;
- root lease, root/volume identity and workflow-exclusion observations.

`CleanupPolicyGate` is a pure, synchronous and deterministic value type. It
receives a complete typed context plus an explicit evaluation time. It must
not:

- access the filesystem or SQLite;
- enumerate processes or Apps;
- resolve bookmarks;
- load bundled resources;
- consult mutable singleton/App state;
- create an `ActionPreflightToken` or execution authorization.

This split makes provider errors explicit and keeps Policy tests independent
of host timing and permissions.

### 2.2 Product Policy does not replace `ActionPolicyGate`

Task 30 Policy validates Plan/selection/current evidence and produces audit
decisions. The existing `ActionPolicyGate` remains the final filesystem and
executable boundary immediately before every Task 31 write.

`ActionPreflightToken` remains a low-level reusable Spike token. It is not
renamed, persisted, exposed to Review, accepted as user authority or treated
as equivalent to `ExecutionAuthorization`.

Task 30 may harden shared path checks or typed errors only when focused
regressions prove existing Spike behavior remains fail-closed.

### 2.3 Review selection is memory-only workflow state

Create a closed `ReviewSelection` value containing:

- one Plan ID;
- selected item IDs with one origin per item;
- a monotonically increasing generation;
- deterministic overlap/conflict facts.

Selection construction rejects:

- an empty selection at confirmation time;
- unknown or duplicate item IDs;
- more than 100 selected items;
- duplicate canonical targets;
- selected ancestor/descendant overlaps;
- `defaultReady` origin for anything except an eligible persisted Ready item;
- any Protected/Unknown or non-profile item.

`reviewRecommended` is always explicit and unselected by default.
`ReviewSelection` is not `Codable`, is not Local Knowledge, does not mutate
the Plan or classification and grants no authority.

### 2.4 Store reads are bounded by the selected Plan items

Store v3 already persists immutable Plans and Policy Decisions but does not
provide exact by-ID snapshot/classification truth for current Policy.

Add a narrow Store v3 read API that:

- accepts one current Plan plus at most 100 unique selected item IDs;
- reads only their exact snapshot/classification rows and required Evidence;
- checks mirrored columns, payload identity, scan/session/scope ownership and
  Plan joins;
- reports missing, corrupt, duplicate, orphaned or cross-session truth as a
  typed failure;
- returns records in Plan order;
- performs no migration, repair, reinterpretation or disposition update.

The collector must not use the bounded Task 29 `ReviewProjection` as Policy
truth and must not scan unbounded rows merely to resolve a selected batch.

### 2.5 Workflow exclusion is a typed Core snapshot, not App booleans

Introduce a closed `CleanupWorkflowAvailabilitySnapshot` describing whether
authorization admission is excluded by:

- an active Quick Scan;
- root/settings mutation;
- History deletion or retention mutation;
- another cleanup execution;
- an App lifecycle reset or unavailable root lease.

The snapshot is observation, not a lock. Task 31 will own the exclusive
operation lease and recheck admission atomically. Task 30 authorization
minting fails unless the snapshot is available and conflict-free.

Read-only History viewing is not a conflict.

### 2.6 Authorization expiry is an admission deadline

`ExecutionAuthorization` has a maximum 30-second admission deadline measured
from the current context/confirmation boundary. It is consumed on the first
admission attempt whether that attempt succeeds, expires or detects a
conflict.

Expiry does not cancel a batch already admitted before the deadline. Task 31
still performs fresh pure Policy and `ActionPolicyGate` revalidation before
every individual action.

## 3. Closed Domain Contract

### 3.1 Selection

Planned Core types:

```text
ReviewSelection
ReviewSelectionItem
ReviewSelectionConflict
ReviewSelectionError
```

Stable selection order is the immutable Plan item order, never caller Set or
UI row order. The selection fingerprint binds:

- Plan ID and Plan fingerprint;
- generation;
- ordered item IDs and origins;
- exact conflict-free canonical relative targets.

A refresh, item toggle, new Plan, new scan, root/settings mutation or App
lifecycle reset creates a new generation and invalidates any prior
confirmation/authorization.

### 3.2 Current Policy context

Planned typed context layers:

```text
CleanupPolicyContext
CleanupPolicyRootContext
CleanupPolicyItemContext
CleanupPathPolicyFacts
CleanupEvidencePolicyFacts
CleanupActivityPolicyFacts
CleanupWorkflowAvailabilitySnapshot
```

The complete context binds:

- capture time and context fingerprint;
- Plan ID, scan session, scope and Plan fingerprint;
- current root lease identity, filesystem identity, device/volume and access;
- current Rule Catalog and Execution Profile Catalog versions;
- exact selected Store records;
- current item path, owner, kind, identity, logical/allocated bytes and mtime;
- current classification/rule/profile/action facts;
- exact Evidence and Activity fingerprints/freshness;
- one shared activity-capture identity;
- pure path-policy observations;
- workflow availability.

Context initializers reject partial combinations. A provider cannot represent
failure as an empty inactive process set, missing Evidence as fresh, or an
unreadable path as absent-but-allowed.

The context maximum age for authorization is 30 seconds. This is independent
from Plan expiry and the seven-day Evidence retention window.

### 3.3 Policy output

The pure gate returns one closed evaluation:

```text
allowed(decisions, confirmation)
blocked(decisions, stale)
```

Every selected item receives exactly one `PolicyDecision`. Denied decisions
contain stable sorted reason keys. The aggregate stale contract contains only:

- affected item IDs;
- typed identity/activity/evidence/catalog/root/workflow reason groups;
- `refreshAffectedItems`;
- `cancel`.

There is no `Proceed Anyway`, execution retry, hidden selection mutation or
Policy-side promotion.

Policy Decisions may be persisted through Store v3 for audit, but an allowed
decision remains non-authoritative.

### 3.4 Final confirmation

The gate's confirmation summary binds the exact:

- Plan and selection generation;
- ordered item IDs;
- per-item origin and disposition;
- action count and `moveToTrash` action;
- checked logical and allocated byte totals;
- number of explicitly selected Review items;
- Plan/context/decision/selection fingerprints;
- recovery caveat key.

Confirmation mismatch, overflow, stale generation or a changed fingerprint
blocks authorization.

### 3.5 One-shot authorization

Planned types:

```text
ExecutionAuthorization
ExecutionAuthorizationAdmission
CleanupAuthorizationController  # actor-owned
```

`ExecutionAuthorization`:

- is `Sendable` but deliberately not `Codable`, `Equatable` or `Hashable`;
- has no public/memberwise initializer;
- contains an opaque per-instance nonce not accepted from persistence;
- is issued only by the actor after exact confirmation;
- is bound to one Plan, selection generation, ordered item list and decision
  fingerprint;
- exposes no mutation operation and no action executor;
- cannot be reconstructed from a `PolicyDecision`.

The actor owns issuance and consumption state. Admission:

- consumes the nonce before evaluating expiry or workflow conflicts;
- succeeds at most once;
- rejects unknown, copied-field, expired, invalidated or already consumed
  attempts;
- returns an internal admitted immutable batch value for Task 31;
- does not make authorization persistence possible.

No public API accepts arbitrary IDs/fingerprints and returns a valid
authorization without matching actor-owned pending state.

## 4. Pure Policy Rules

### 4.1 Global hard rejects

Reject all selected items when any global fact fails:

- Plan is legacy, expired, missing or has a different fingerprint;
- scan session or scope is missing/different/non-terminal;
- root lease is missing, stale or inaccessible;
- root identity, owner, directory kind, device or volume changed;
- current Rule Catalog or Profile Catalog differs from the Plan;
- context age exceeds 30 seconds;
- selection Plan/generation/fingerprint differs;
- selection contains unknown/duplicate IDs or exceeds 100;
- selected targets overlap;
- workflow availability is unavailable or conflicted.

### 4.2 Per-item hard rejects

Reject the affected item for:

- snapshot/classification/rule/profile/action mismatch;
- persisted or current Protected/Unknown disposition;
- current disposition promoting the persisted classification;
- Review without `explicitUser` selection;
- Ready with an invalid default/explicit origin;
- action other than `moveToTrash`;
- missing or mismatched exact execution profile;
- path, identity, kind, owner, link, logical bytes, allocated bytes, mtime,
  device or volume drift;
- root, HOME, mount root, symbolic link, denylist or outside-root target;
- missing, malformed, stale, expired or fingerprint-mismatched Evidence;
- active, unavailable, incomplete, contradicted or fingerprint-mismatched
  Activity;
- a provider error or any unrecognized typed state.

Current Review refresh may preserve or downgrade persisted Ready/Review. It
never promotes persisted Protected/Unknown or a no-profile item. Catalog or
profile drift requires Scan Again rather than reinterpretation.

### 4.3 Stable reasons and fingerprints

Reason keys are closed `DomainToken` constants grouped under:

```text
policy.plan.*
policy.selection.*
policy.root.*
policy.catalog.*
policy.item.*
policy.identity.*
policy.evidence.*
policy.activity.*
policy.path.*
policy.workflow.*
policy.confirmation.*
```

Fingerprints use deterministic canonical encodings with domain separators,
stable Plan order and checked byte arithmetic. They contain no absolute home
path, authorization nonce, localized text or process command line.

## 5. Collector and Failure Semantics

`CleanupPolicyContextCollector` accepts injected providers and a clock so
tests can prove call counts and failures. A single collection:

1. loads and verifies the selected Store truth;
2. obtains one root lease/identity observation;
3. validates the current bundled Rule/Profile catalogs;
4. reads each selected current filesystem identity without following a target
   symlink;
5. captures running process/App context exactly once;
6. evaluates every selected profile against that one activity context;
7. validates current Evidence and recomputes fingerprints;
8. snapshots App-owned workflow availability;
9. constructs one immutable context or a typed fail-closed collection result.

Phase C profiles do not require Git. The collector API may carry a closed
future requirement enum, but Task 30 must not invoke Git or add a profile.

Provider failures remain distinguishable for diagnostics while mapping to
stable Policy reason keys. They never synthesize allow facts.

## 6. Tests-First Matrix

Before production implementation, add focused unit/adversarial tests for:

### Selection

- stable Plan ordering independent of caller order;
- Ready default/explicit and Review explicit origins;
- Review default, Protected/Unknown and no-profile rejection;
- unknown/duplicate/empty/over-100 selection;
- exact duplicate and ancestor/descendant overlap;
- generation and fingerprint changes.

### Pure Policy

- every global and per-item hard reject in section 4;
- multiple reasons and affected-item grouping;
- deterministic decisions/fingerprints across random decision IDs;
- checked byte overflow;
- no hidden Ready/Review promotion;
- pure repeatability with identical input and evaluation time.

### Collector

- exact bounded Store joins and Plan order;
- missing/corrupt/cross-session Store truth;
- one activity capture for 100 selected items;
- provider failure, incomplete enumeration and active-process precedence;
- root/catalog/profile/evidence/filesystem drift;
- no process/tool launch and no Store schema change.

### Authorization

- no public/persisted reconstruction path;
- exact confirmation required;
- maximum 30-second deadline;
- first success consumes;
- first expired/failed/conflicted admission also consumes;
- concurrent actor admissions yield at most one success;
- refresh/selection/root/workflow invalidation;
- admitted batch remains valid after wall-clock deadline;
- persisted allowed Policy cannot replay authorization.

### Structural boundaries

- no Trash invocation or target write;
- no App CTA/Review View;
- no Registry definition or shell/Codex/Adapter dependency;
- no `Codable` conformance for selection/authorization;
- production App dependencies remain write-disabled.

The first focused run must fail because Task 30 production types do not yet
exist. Preserve its command and hash in the completion report.

## 7. Verification and Review

Run heavy SwiftPM/Xcode commands serially:

1. focused Task 30 selection/Policy/collector/authorization tests;
2. existing `ActionPolicyGate`, Plan Builder, Cleanup domain and Store v3
   regressions;
3. complete `StornautCoreTests`;
4. serial complete `swift test`;
5. Task 30 structural/boundary verifier;
6. `scripts/check-doc-links`;
7. `scripts/verify`;
8. diff hygiene and secret scan.

Review independently for:

- Policy purity and hidden I/O;
- fail-open provider errors;
- TOCTOU assumptions and stale clocks;
- authorization copy/replay/reconstruction;
- actor consumption races;
- selection origin/generation drift;
- overlap and canonical path mistakes;
- byte overflow and nondeterministic fingerprints;
- accidental Rule/Profile reinterpretation;
- capability reuse between product authorization and low-level preflight;
- target mutation or prematurely enabled App wiring.

Create `docs/reports/epic-8-task-30-review.md` with tests-first evidence,
prompt-to-artifact audit, review findings, focused/full/unified results and
remaining Task 31/35 boundaries.

## 8. Explicit Non-Goals

Task 30 does not add:

- a Trash call or target mutation;
- `CleanupExecutionCoordinator`;
- journal execution or Manifest finalization;
- cleanup accounting;
- SwiftUI Review, confirmation or stale sheet UI;
- an App cleanup CTA;
- production Registered Action definitions;
- Deep Dive or Adapter behavior;
- a Store v4 migration;
- third-party dependencies;
- release signing/notarization work.

The real App Trash dependency remains disabled. Task 35's signed-App
disposable Trash diagnostic still requires separate explicit user opt-in.

Suggested commit subject:

```text
feat: enforce reclaim authorization policy
```
