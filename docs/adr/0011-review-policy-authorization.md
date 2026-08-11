# ADR 0011: Review, Policy and One-Shot Execution Authorization

> Status: Accepted for Phase C implementation
>
> Date: 2026-08-11
>
> Decision owners: Stornaut maintainers
>
> Related study:
> [`../upstream-studies/epic-8-safe-execution.md`](../upstream-studies/epic-8-safe-execution.md)

## Context

ADR 0006 proved that `ActionPolicyGate`, Foundation Trash and a test-only
registered action can form a constrained action lifecycle. It did not define
product Review, selection, user confirmation, stale transitions or a
non-replayable execution authority.

The current domain has persisted `CleanupPlan` and `PolicyDecision` records,
but:

- a plan does not bind scope, catalog/profile generation or evidence
  fingerprints strongly enough for execution;
- a Policy decision can describe an allow outcome but is not a user-granted
  capability;
- `ActionPreflightToken` is a reusable value-level Spike token;
- the App has no typed Review workflow or global operation exclusion;
- Quick Scan activity can be unavailable and must not be interpreted as
  inactive.

Upstream review reinforces separation:

- ClearDisk rechecks postconditions but does not model a separate authority;
- devklean structurally separates dry-run from the mutation path;
- Cluttered has independent scanner/UI/cleaner paths and demonstrates how
  protection or accounting can drift across them;
- PureMac shows that the App process owns the TCC decision, while its
  privileged/permanent fallbacks are explicitly outside Stornaut's boundary.

## Decision

### Plan, selection, Policy and authorization are different types

`CleanupPlan` is a persisted, immutable proposal bound to:

- one retained terminal `ScanSessionID`;
- one `ScanScopeID` and Primary Scan Root identity;
- one catalog and execution-profile generation;
- bounded item snapshots and expected identities;
- the evidence lineage needed to explain the proposal.

It grants no authority.

`ReviewSelection` is in-memory workflow state containing selected item IDs,
default/explicit selection origin, a monotonically changing generation and
overlap conflicts. It is not Local Knowledge and cannot change a
classification.

`PolicyDecision` is a persisted audit record bound to a plan item, selection
generation, typed facts and a deterministic fingerprint. It grants no
authority.

`ExecutionAuthorization` is an internal, non-`Codable`, non-persistable,
one-shot value minted only by final confirmation. It is the only product-level
authority admitted by `CleanupExecutionCoordinator`.

### Default selection

Only a persisted `readyToReclaim` classification with:

- an accepted exact execution profile;
- complete current static/filesystem/activity evidence;
- an allowed Policy preview;

is selected by default.

`reviewRecommended` is always unselected and requires explicit user selection.
Protected/Unknown are disabled. Review may preserve or downgrade a persisted
Ready/Review classification; it never promotes persisted Protected/Unknown.
A catalog/profile mismatch requires `Scan Again`.

The initial accepted execution profile is:

- Ready: npm `.npm/_cacache`;
- Ready: pip `Library/Caches/pip`;
- Review: Go `Library/Caches/go-build`;
- no profile: uv `.cache/uv`.

uv is excluded because its official documentation says direct cache
modification/removal is never safe and cleanup must use lock-aware uv commands.
No such Registered Action ships in Phase C.

### Evidence boundary

Compiler-attested facts may cover only pinned, closed claims such as:

- exact default path and directory kind;
- documented tool ownership;
- documented cache/rebuild behavior;
- checked-in positive/active/lookalike fixtures.

Current facts are collected at scan/refresh and immediately before execution:

- root access lease and volume;
- owner, kind and complete `FileIdentity`;
- logical/allocated bytes and mtime;
- current catalog/profile;
- one bounded running App/process snapshot;
- Git facts only for a future profile that explicitly requires them.

Phase C profiles do not launch npm, pip, uv or Go to discover configuration
and never follow an override to make another path executable. The exact
built-in path remains eligible only under its pinned cache semantics and
current filesystem/activity checks; an override path remains non-executable.

`activity.process.inactive` requires a checked-in, bounded process-family
mapping. Wrapper-only checks are insufficient. Missing, truncated, unavailable
or unmapped activity fails closed.

### One-shot admission

Final confirmation displays the exact ordered selection, count, action,
estimated moved bytes, Review items and recovery caveat. It mints an
authorization bound to:

- plan ID;
- selection generation;
- ordered item IDs;
- Policy decision fingerprint;
- creation and admission deadline.

The maximum admission window is 30 seconds. The authorization:

- is consumed on the first execution attempt, including a failed admission;
- cannot be copied into SQLite, preferences, logs, Manifest or Local Knowledge;
- is invalidated before use by selection, refresh, new scan, root/settings
  change, App lifecycle reset or another workflow mutation;
- does not falsely cancel a serial batch merely because the admission deadline
  passes after it was consumed.

Every action in an admitted batch still receives fresh pure Policy and
`ActionPolicyGate` revalidation immediately before its write.

### Stale, overlap and exclusion

The following are stale/blocking:

- plan expiry;
- scan/scope/root/catalog/profile mismatch;
- identity, kind, owner, size, allocated bytes, mtime or volume drift;
- missing/stale/contradicted evidence or activity;
- selection-generation/fingerprint mismatch;
- lost root access;
- duplicate or overlapping ancestor/descendant selections.

Stale Review freezes affected execution controls and exposes only Refresh
Affected Items or Cancel. There is no bypass.

Scan, root/settings mutation, History deletion/retention mutation and cleanup
execution are mutually exclusive through one App-owned workflow coordinator.
Read-only History viewing remains allowed when it cannot mutate lifecycle
state.

### Cancellation

- Before authorization or before the first action: cancel performs no target
  write.
- Between actions: a stop request prevents the next action.
- During synchronous Foundation Trash: UI says Stop After Current Action; it
  does not claim to cancel the in-flight call.
- Stale/revalidation failure or uncertain Trash outcome stops the batch,
  regardless of the user's prior continuation preference.

## Evidence

- macOS 26.5 SDK declares collision-aware
  `trashItemAtURL:resultingItemURL:error:` and Trash relationship checks.
- A Swift 6.3.3 typecheck witness confirms the current imported Trash and
  relationship signatures.
- The current RunningActivity provider bounds Apps/processes, returns
  unavailable on incomplete process enumeration and supports closed
  bundle/process queries.
- `ActionPolicyGate` already rejects root, HOME, mount root, symlink,
  denylisted, active, outside-root, missing and identity-changed paths.
- Current Rule Catalog has 67 rules, 34 Trash recommendations and zero Ready;
  selection cannot be inferred from action recommendations.
- Context7's Apple SwiftUI index and a local SDK typecheck witness confirm
  native Table, Inspector, confirmation dialog, FocusState, accessibility and
  Reduce Motion surfaces for later UI work.

## Alternatives Rejected

### Persist confirmation on the plan

Rejected because a retained plan would become replayable authority after
identity/activity/configuration drift.

### Treat allowed Policy as the capability

Rejected because Policy is audit evidence and may outlive the user's exact
selection or confirmation moment.

### Mint one authorization per item

Rejected because it obscures one final batch confirmation and complicates
stop/Manifest ordering. One batch admission plus per-item revalidation is
clearer and no less strict.

### Allow Review to promote Unknown after refresh

Rejected because it would rewrite the semantic meaning of the retained Quick
Scan. A new scan is required for promotion.

### Directly Trash uv's cache

Rejected because pinned uv documentation requires lock-aware uv commands and
explicitly warns that direct cache modification/removal is never safe.

## Consequences

Positive:

- user intent, audit facts and write capability cannot be conflated;
- persisted data cannot replay a cleanup;
- stale execution has no bypass;
- process/provider uncertainty fails closed;
- Deep Dive can later produce proposals without receiving write authority;
- UI can remain a typed projection rather than the safety boundary.

Costs:

- Task 28 must evolve domain records and Store schema before UI work;
- Task 29 needs a shared scan/Review evidence resolver;
- current Activity process names require careful normalized family tests;
- older scans cannot immediately gain new Ready items and must run again;
- serial batches perform repeated fresh checks.

## Residual Risks

- URL-based Foundation Trash retains a narrow final revalidation-to-call race.
- Process basename mapping cannot prove a process has no unrecognized helper;
  incomplete mappings must remain Unknown.
- npm/pip/Go configured cache overrides are not generically discoverable
  without executing tools or reading arbitrary configuration; Phase C never
  follows them and limits profiles to proven exact built-in paths.
- App-context Trash still requires the Task 35 signed-App diagnostic.

## Validation

ADR 0011 is accepted for implementation only while:

- authorization remains non-`Codable` and internally constructed;
- no View, Codex or persisted record can mint it;
- all deny/provider errors perform zero target writes;
- overlap and stale transitions have no bypass;
- Task 30 adds replay/expiry/generation/concurrency adversarial tests;
- Task 32 uses fake/write-disabled execution dependencies;
- the real Trash dependency stays absent from normal App wiring until Task 35.
