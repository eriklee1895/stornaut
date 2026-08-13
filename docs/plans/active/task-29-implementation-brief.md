# Task 29 Implementation Brief — Deterministic Execution Evidence and Cleanup Plan Builder

> Status: Completed; implementation, review and final gates passed
>
> Date: 2026-08-13
>
> Baseline:
> `b09e7b37ef325c7389c9d8a02d7b8c05a8a24581`
>
> Parent plan:
> [Epic 8 Safe Execution Vertical Slice](epic-8-safe-execution-vertical-slice.md)
>
> Accepted decisions:
> [ADR 0011](../../adr/0011-review-policy-authorization.md),
> [ADR 0012](../../adr/0012-cleanup-execution-journal.md) and
> [Task 27 Study](../../upstream-studies/epic-8-safe-execution.md)

## 1. Objective

Task 29 creates the deterministic proposal layer between a completed Quick
Scan and the later Policy/authorization pipeline:

```text
closed Rule Catalog
+ separate closed Execution Profile Catalog
+ one bounded current activity snapshot
+ exact current filesystem facts
→ immutable Quick Scan classifications
→ complete persisted candidate join
→ non-authoritative Review projection
→ immutable Cleanup Plan proposal
```

The Task is complete only when:

- npm and pip can become `readyToReclaim` in a **new** Quick Scan only when
  every closed static, filesystem and activity fact is satisfied;
- Go build cache remains `reviewRecommended` and never suggested selected;
- uv and every other Rule have no execution profile;
- the same closed resolver semantics serve Quick Scan and Review refresh;
- one scan/refresh enumerates running processes at most once;
- Plan building consumes complete persisted pages with corruption and count
  checks rather than the bounded UI projection;
- a Plan binds the retained scan, one scope/root, current Catalog/Profile
  generations, exact identities and deterministic fingerprints;
- Review output describes eligibility and suggested defaults but grants no
  selection, Policy or execution authority;
- no target write, Trash call, Registered Action, Codex, Probe, Adapter or
  production App CTA is added;
- tests-first evidence, focused/full verification, benchmark, code review,
  independent report and one commit/push are complete.

Task 29 was implemented tests-first and independently reviewed. Completion
evidence is recorded in
[Task 29 Review](../../reports/epic-8-task-29-review.md).

## 2. Planning Corrections

The parent plan remains authoritative. This brief makes the following
implementation-level corrections after inspecting the current Rule compiler,
Quick Scan, Activity, Cleanup v2 and Store v3 code.

### 2.1 Execution profiles are not generic Rule fields

Do not add privilege-sensitive fields to `CompiledRule` or the generic Rule
source schema.

The Rule Catalog answers:

```text
What is this path, how risky is it, and what classification facts are needed?
```

The separate `ExecutionProfileCatalog` answers:

```text
Which exact approved Rule/path may enter a Cleanup Plan, which closed
resolvers prove its required facts, and what default-selection suggestion
may Review display?
```

Keeping the catalogs separate prevents all 67 Rules from accidentally gaining
an execution surface and preserves the Rule Catalog as classification truth.
The runtime cross-validates both catalogs before exposing any profile.

### 2.2 Rule content changes require a new Catalog generation

Promoting npm and pip changes classification semantics. The implementation
must not rewrite `package-build-caches-v1` or continue emitting
`builtin-runtime-tool-residue-v1` under the old identity.

Create a new closed package-cache promotion generation and compile a new
complete Rule Catalog generation. Update:

- source filename/version;
- merged Catalog version;
- built-in runtime pin;
- generated JSON;
- checksum/manifests;
- tests and verifier constants.

The planned exact identities are:

```text
Rules/BuiltIn/package-build-caches-v2.json
Rule source catalogVersion: package-build-caches-v2
Merged Rule catalogVersion: builtin-runtime-tool-residue-v2
Execution Profile catalogVersion: safe-execution-v1
```

`package-build-caches-v1.json` remains the immutable base source and stays in
the complete-Catalog compiler inputs. `package-build-caches-v2.json` is a
strict, host-only two-rule promotion source that can change only npm and pip
from Review to Ready. The built-in Catalog still contains 67 Rules; only its
version, npm/pip dispositions and resulting hash change.

Historical persisted classifications retain their original Catalog version.
They are never rewritten or reinterpreted as Task 29 Ready results.

### 2.3 Plan building is not a Quick Scan UI projection

`QuickScanProjection` intentionally retains at most 100 display records.
`CleanupPlanBuilder` must instead stream complete Store pages and verify:

- terminal session and single completed scope;
- Store summary counts;
- every classification/snapshot join;
- every Evidence row needed for the session and executable candidates;
- zero corrupt, orphaned, duplicated or cross-session records;
- exact volume baseline/root identity.

A Store v3 schema migration is not planned. A narrow, cursor-based,
corruption-isolating planning page API may be added to `EvidenceStore` so the
builder does not hold an unbounded home scan in memory.

### 2.4 Empty Review is valid but an empty `CleanupPlan` is not

Cleanup domain v2 correctly requires at least one Plan item. Therefore the
builder result is a closed outcome such as:

```text
planReady(plan, projection)
empty(projection)
scanAgain(reasons)
unavailable(reasons)
```

An empty valid Review state does not persist a fake or empty Plan.

### 2.5 Task 29 suggests defaults but does not create selection

`ReviewProjection` may expose:

- executable Ready items suggested selected;
- executable Review items suggested unselected;
- disabled/non-executable groups and stable reasons;
- counts and bounded display rows.

It does not create `ReviewSelection`, a selection generation,
`PolicyDecision`, confirmation state or an authorization. Those begin in
Tasks 30 and 32.

## 3. Closed Execution Profile Contract

### 3.1 New source and runtime artifacts

Planned artifacts:

```text
Rules/Schema/execution-profile-source.schema.json
Rules/BuiltIn/safe-execution-profiles-v1.json
Sources/StornautCore/KnowledgeBase/ExecutionProfileCatalog.swift
Sources/StornautCore/KnowledgeBase/BuiltInExecutionProfileCatalog.swift
Sources/StornautCore/Resources/BuiltInExecutionProfileCatalog.json
Tools/RuleCompilerKit/ExecutionProfileCompiler.swift
```

The host-only compiler consumes the complete compiled Rule Catalog plus the
profile source and emits a sorted, strict runtime artifact. The App/Core loads
only the compiled JSON; it never links `RuleCompilerKit`.

The compiled Profile Catalog has its own schema and version. It contains no
command, executable path, shell text, arbitrary arguments, absolute user path
or Registered Action.

Extend the existing `stornaut-rule-compiler` rather than introducing a second
compiler executable. New profile inputs/outputs are explicit flags, all source
and output paths receive the existing collision/symlink protections, and a
failed Rule/Profile cross-validation leaves neither updated runtime artifact.

### 3.2 Exact initial profiles

The only accepted Task 29 profiles are:

| Profile ID | Rule | Exact relative path | Rule disposition | Suggested default |
| --- | --- | --- | --- | --- |
| `phase-c.npm-cacache-v1` | `cache-npm-content` | `.npm/_cacache` | `readyToReclaim` | eligible |
| `phase-c.pip-cache-v1` | `cache-pip` | `Library/Caches/pip` | `readyToReclaim` | eligible |
| `phase-c.go-build-cache-v1` | `cache-go-build` | `Library/Caches/go-build` | `reviewRecommended` | never |

All three require:

- exact non-wildcard directory path;
- `recommendedAction == moveToTrash`;
- high confidence;
- non-veto Rule;
- pinned official provenance and recovery guidance;
- positive, active, configuration-lookalike and other-lookalike fixtures;
- exact Rule/Profile path and kind equality.

`cache-uv` remains `reviewRecommended` Rule evidence with no profile. No
fallback profile or replacement rule is added.

### 3.3 Closed evidence resolver map

Every Rule-required key must have exactly one typed resolver in its profile.
Initial resolver classes are:

| Resolver class | Permitted facts |
| --- | --- |
| compiler-attested | exact approved layout, tool ownership and documented reconstructibility/recovery |
| current filesystem | exact relative path, directory kind, complete identity/bytes/mtime, current-user ownership and same root device |
| current activity | exact approved process/bundle family is inactive in one bounded snapshot |

The initial per-profile key map is exact and identical:

```text
compiler-attested:
  evidence.cache.layout
  evidence.cache.reclaimable
  evidence.cache.tool-owned

current filesystem:
  evidence.scope.user-owned

current activity:
  activity.process.inactive
```

The Profile Catalog stores only a suggestion mode:

```text
readyWhenEligible  # npm and pip
never              # Go build
```

`readyWhenEligible` is not selection. Task 32 may create a default selection
only after Task 30 also supplies an allowed current Policy preview.

The resolver map cannot:

- satisfy unknown keys by string convention;
- infer a fact from the profile merely naming it;
- follow npm/pip/Go configuration overrides;
- inspect file content;
- run npm, pip, Go, uv or another executable;
- use environment variables to expand eligibility;
- convert permission denial or incomplete enumeration into inactivity.

Static attestation is valid only when the loaded Rule/Profile generations,
exact path, kind, provenance, recovery and fixture bindings match the compiled
artifact.

### 3.4 Process subjects and normalization

Initial process families:

- npm: exact `node`, `npm`, `npx`, `corepack`;
- pip: exact `python`/`pip` plus a closed bounded versioned-basename grammar;
- Go: exact `go`, `compile`, `link`, `asm`, `cgo`.

All three initial profiles have an explicitly empty bundle-identifier list.
An empty bundle list means “no approved bundle subjects”, not “match any
bundle”. Process subjects remain mandatory and non-empty.

The implementation must freeze the versioned Python/pip grammar in tests
before production code. Requirements:

- ASCII basename only;
- case behavior explicit and conservative;
- bounded total length, component count and digits per component;
- no substring, suffix-only or arbitrary regex supplied by JSON;
- known versioned positive cases and adversarial lookalikes;
- incomplete process enumeration yields unavailable unless an active subject
  is already observed;
- an observed active subject always protects the candidate.

The profile schema may express only closed typed subject forms supported by
Core. Arbitrary regular expressions are forbidden.

## 4. Shared Deterministic Evidence Resolver

### 4.1 Resolver phases

`ExecutableEvidenceResolver` has two explicit entry modes using one semantic
contract:

1. **Quick Scan resolution**
   - accepts the measured `PathSnapshot`, matched Rule/Profile and one shared
     activity context;
   - attests static facts and derives current filesystem facts only from the
     complete measured snapshot;
   - returns satisfied keys, typed Evidence records, activity observations
     and fingerprints for a newly created immutable Classification.
2. **Review refresh**
   - accepts the retained snapshot plus the exact resolved Primary Root;
   - performs bounded no-follow metadata reads only for exact profile paths;
   - requires current identity/kind/bytes/mtime/owner/device to equal the
     retained scan truth before the item can remain eligible;
   - evaluates all profiles against one newly captured activity context.

The resolver never mutates the retained Classification. Review may preserve
or downgrade Ready/Review eligibility; it never promotes a retained
Protected/Unknown classification.

### 4.2 One activity snapshot

Refactor running-activity evaluation into:

```text
capture once
→ validate bounded snapshot/status
→ evaluate many closed RelatedProcessQuery values
```

Quick Scan captures at most one `RunningActivitySnapshot` for the complete
classification pass. Review refresh captures at most one snapshot for the
complete build. The source-call count is asserted in tests and benchmark
fixtures.

If capture throws, is oversized, has an invalid timestamp or has incomplete
process enumeration with no observed active match, every dependent profile
receives unavailable activity and cannot remain Ready/executable.

Non-profile Rules keep their existing conservative classification path. Git
activity remains outside the initial execution profiles and is not introduced
as a Task 29 dependency.

### 4.3 Evidence records and fingerprints

Quick Scan persists one bounded typed Evidence record per resolved static,
filesystem and activity fact needed by an execution-profile Rule.

Canonical fingerprints:

- exclude random Evidence IDs and localized labels;
- include Profile/Catalog generation, Rule ID, evidence key, resolver kind,
  typed state and stable reason;
- include current activity state/subject mapping through the existing closed
  activity fingerprint contract;
- contain no absolute path, process command line or private content;
- are stable under input ordering;
- change when any bound fact changes.

Review requires the persisted scan Evidence lineage to be complete before it
performs current refresh. A missing, duplicate, stale, corrupt or unexpected
fact produces a non-executable/Scan Again result rather than guessed
eligibility.

## 5. Quick Scan Integration

### 5.1 Tests first

Add red tests before production implementation:

```text
ExecutionProfileCompilerTests
ExecutionProfileCatalogTests
ExecutableEvidenceResolverTests
QuickScanExecutionEvidenceTests
```

The first focused run is expected to fail because the new Profile Catalog and
resolver APIs do not exist. Preserve the command, exit status and relevant
compiler/test output in the Task 29 review report.

Required rejection cases:

- wildcard, absolute, parent-relative or non-directory profile path;
- Rule/Profile path or kind mismatch;
- non-approved Rule ID;
- uv or another Rule receives a profile;
- non-Trash action, veto, missing recovery, non-high confidence;
- missing/duplicate/unknown evidence resolver;
- arbitrary regex/process subject or over-limit subject list;
- missing required fixture family;
- duplicate profile/Rule binding;
- Rule Catalog/Profile generation mismatch;
- compiler output changes with input ordering;
- partial output remains after compiler failure.

### 5.2 New classification truth

Change only the approved Rule source generation:

- npm → `readyToReclaim`;
- pip → `readyToReclaim`;
- Go build → remains `reviewRecommended`;
- uv → remains `reviewRecommended`;
- every other Rule remains byte-semantically unchanged.

New Quick Scan cases:

- npm/pip exact positive + complete evidence + inactive → Ready;
- npm/pip active → Protected;
- process unavailable/incomplete → Unknown;
- missing/changed static or filesystem fact → Unknown;
- Go exact positive + inactive → Review;
- uv exact positive → Review but no execution profile;
- configuration and source/runtime lookalikes never gain profile eligibility;
- old persisted Catalog classifications remain unchanged and later require
  Scan Again;
- no model, Process launch, target write or execution API is called.

The generic Rule schema and `CompiledRule` do not gain Profile fields.

## 6. Cleanup Plan Builder

### 6.1 Store-facing input

Introduce a narrow internal `CleanupPlanBuildingStore` protocol implemented by
`EvidenceStore`. It exposes only the reads and immutable Plan save needed by
the builder.

Prefer a cursor-based joined planning page ordered by stable relative path and
IDs. Each page must report:

- decoded snapshot/classification pairs;
- physical row count;
- corrupt row identities and record kind;
- next cursor.

The builder separately streams Evidence pages, retaining only bounded facts
for matched profile candidates while still validating total row counts and
corruption for the complete session.

No new SQLite table, column, index, trigger or `user_version` is expected. If
implementation evidence proves a schema migration unavoidable, stop Task 29
and propose a revised brief rather than silently creating Store v4.

### 6.2 Admission of retained scan truth

A build requires:

- exact requested `ScanSessionID`;
- `terminalState == completed`;
- exactly one completed scope and no unfinished scope;
- complete aggregate and Store summary agreement;
- one matching `VolumeBaseline`;
- completed scope root path equals baseline root path;
- resolved root path/identity equals the retained baseline;
- current Rule Catalog and Profile Catalog generations;
- all persisted classification Catalog versions equal the current Rule
  Catalog;
- complete, one-to-one snapshot/classification rows;
- zero corrupt/orphan/duplicate rows;
- complete required Evidence lineage.

Cancelled, failed, partial, expired, old-Catalog, old-Profile, root-mismatched
or structurally incomplete truth returns a typed Scan Again/unavailable
outcome. It never writes a partial Plan.

### 6.3 Candidate reduction

For every joined row:

- Protected/Unknown is never executable;
- Ready/Review without an exact Profile remains visible only in a
  non-executable group;
- Profile Ready/Review receives current resolver refresh;
- refresh can preserve or downgrade, never promote;
- exact duplicate relative path, identity, snapshot, classification or Rule
  binding is a build failure;
- ancestor/descendant overlap remains a blocking Plan conflict;
- every Plan item is `MoveToTrash`;
- current initial profile count is at most three, while the domain maximum
  remains 100.

The stable executable order is:

```text
normalized relative path
→ Rule ID
→ snapshot ID
→ classification ID
```

Plan/item IDs, clock and expiry are injected. Tests use deterministic sources.
The Plan fingerprint is a canonical hash over the complete ordered binding,
not a random ID.

Plan expiry cannot outlive linked scan Evidence:

```text
min(createdAt + 7 days, scan.finishedAt + 7 days)
```

An already expired evidence window returns Scan Again.

### 6.4 Review projection

The projection is a read-only value derived from the same build result. It
contains:

- Plan metadata when a non-empty Plan exists;
- executable Ready rows with `suggestedDefault = true`;
- executable Review rows with `suggestedDefault = false`;
- disabled Protected/Unknown rows;
- non-profile Ready/Review rows marked non-executable;
- stable reason keys, counts and bounded display data;
- `empty` and `scanAgain` states.

It contains no:

- mutable selected-ID set;
- selection generation;
- Policy allow result;
- confirmation receipt;
- `ExecutionAuthorization`;
- coordinator/Executor/Trash handle;
- closure capable of writing.

No SwiftUI/App wiring is added in Task 29.

## 7. Boundary Verification

Create `scripts/verify-review-boundaries` and add it to `scripts/verify`.

The gate must prove:

- `Sources/StornautCore/Review` has no
  `StornautCodex`, `ProbeBridge`, Adapter, model, network or arbitrary
  `Process` dependency;
- Review has no `ActionExecutor`, `TrashMoving`,
  `FileManager.trashItem`, Registered Action or target-write API;
- Review cannot import App/UI or mint Policy/authorization;
- Quick Scan still has no Codex, Executor, Trash or target write;
- runtime Core/App includes only compiled Rule/Profile resources;
- `RuleCompilerKit` remains host/test-only;
- the compiled Profile Catalog has exactly the three approved IDs and no uv
  profile;
- the production Registered Action registry remains empty;
- no Store schema version change occurred;
- no new external Swift package dependency exists.

Extend `scripts/verify-rule-compiler` to prove:

- deterministic Rule and Profile outputs under reordered inputs;
- exact Catalog/Profile versions and counts;
- generated-resource parity and pinned hashes;
- no partial output on any cross-catalog/profile failure;
- npm/pip are the only Ready Rule changes;
- Profile source/output paths cannot alias or traverse symlinks.

## 8. Performance and Boundedness

Use an anonymous fixture with at least 4,096 joined candidates and complete
Evidence pages.

Measure:

- peak retained candidate rows;
- fixed planning page size;
- activity source call count;
- total Plan build time;
- stable output across reordered Store insertion;
- behavior with corrupt rows at the first, middle and final page.

The first valid implementation run establishes the local arm64 Debug/Release
baseline. The review report then records a conservative regression ceiling
derived from repeated measurements; do not invent a performance claim before
measurement.

Acceptance is structural as well as temporal:

- no page larger than the documented fixed bound;
- no all-session snapshot/evidence array;
- exactly one activity capture per build;
- at most 100 Plan items;
- no target write;
- deterministic Plan items/fingerprint for identical typed inputs.

## 9. Implementation Sequence

Task 29 was executed in this order:

### T29.1 Red compiler/profile tests

- add strict schema/source fixtures and rejection tests;
- run the focused command and preserve the expected failure.

### T29.2 Compile the closed Profile Catalog

- implement host compiler and cross-Catalog checks;
- create the three-profile source and compiled runtime resource;
- bump the Rule Catalog generation and only npm/pip dispositions;
- pass compiler/resource parity gates.

### T29.3 Shared resolver and one-snapshot Activity

- add closed process subject normalization/evaluation;
- split capture from repeated query evaluation;
- implement Quick Scan and Review resolver modes;
- pass failure/incomplete/active/lookalike/fingerprint tests.

### T29.4 Quick Scan integration

- collect one activity context for the classification pass;
- persist complete execution evidence;
- prove new npm/pip/Go/uv classification behavior;
- rerun Quick Scan lifecycle/integration/boundary tests.

### T29.5 Store streaming and Plan Builder

- add cursor-based planning reads without Store migration;
- implement full count/corruption/root/Catalog/Profile checks;
- build immutable Plan or typed empty/Scan Again result;
- implement the non-authoritative projection.

### T29.6 Benchmark and static boundaries

- run the 4,096+ candidate benchmark;
- freeze the measured regression ceiling;
- add and pass `verify-review-boundaries`;
- prove no compiler/runtime dependency leak.

### T29.7 Review, full gate and delivery

- review every production/compiler/schema/fixture/test/doc change;
- fix all confirmed P0–P2 findings;
- create `docs/reports/epic-8-task-29-review.md`;
- refresh all status routers and pinned checksums;
- run the final serial/full verification matrix;
- create one independent Task 29 commit and push `origin/main`.

Do not begin Task 30 in the same commit.

## 10. Tests and Verification

Focused tests are run serially:

```bash
swift test --no-parallel \
  --filter 'ExecutionProfile|ExecutableEvidence|QuickScanExecutionEvidence|CleanupPlanBuilder|ReviewProjection'
swift test --no-parallel --filter 'QuickScanIntegration|QuickScanLifecycle'
swift test --no-parallel --filter 'RuleCompiler'
```

Focused static gates:

```bash
scripts/verify-rule-compiler
scripts/verify-activity-boundaries
scripts/verify-quick-scan-boundaries
scripts/verify-review-boundaries
scripts/check-doc-links
git diff --check
```

Complete gates, run sequentially rather than concurrently:

```bash
swift test --no-parallel
scripts/verify
scripts/check-doc-links
git diff --check
```

`scripts/verify` remains the authoritative repository gate. If a UI/XCUITest
failure contains evidence that another foreground user interaction captured
focus, repeat that case in a fresh undisturbed run; do not weaken assertions
or waive a deterministic failure.

The Task 29 review report records:

- red tests-first command/evidence;
- focused and complete test totals;
- Rule/Profile Catalog versions, counts and SHA-256 values;
- benchmark fixture size, repetitions, median and ceiling;
- one-snapshot call-count evidence;
- static boundary results;
- `scripts/verify` exit status and log hash;
- review findings and corrections;
- final commit and push identity.

## 11. Review Focus

The independent review must challenge:

- any generic Rule field that creates hidden execution eligibility;
- Catalog content changed without a generation bump;
- profile source accepted without the hardcoded Phase C allowlist;
- uv or another unapproved Rule appearing in runtime profiles;
- arbitrary regex, substring or incomplete process-family matching;
- provider failure interpreted as inactivity;
- one process enumeration per row;
- static evidence inferred only from a matching path string;
- Review promoting retained Protected/Unknown truth;
- Plan input truncated to `QuickScanProjection`;
- missing/corrupt/orphan records ignored during paging;
- an empty or partial Plan being persisted;
- random/non-canonical fingerprints;
- exact paths or private process data leaking beyond seven-day Evidence;
- Store migration, App CTA, Policy, authorization or Trash code arriving
  early;
- hidden target writes or compiler dependencies in the runtime package.

## 12. Explicit Non-Goals

Task 29 does not implement or enable:

- `ReviewSelection`;
- `CleanupPolicyGate` or `PolicyDecision` evaluation;
- current Policy preview;
- stale sheet interaction;
- final confirmation;
- `ExecutionAuthorization`;
- `CleanupExecutionCoordinator`;
- journal transitions or Manifest finalization;
- `ActionExecutor` or real/fake Trash calls;
- Review/Cleanup Result/History SwiftUI;
- production App Review CTA;
- Registered Actions;
- Codex, Probe Broker, Adapter or production Deep Dive;
- release signing, Developer ID, notarization or distribution;
- permanent deletion, restore, Trash emptying or background cleanup;
- Store schema v4;
- a third-party dependency.

Tasks 30–35 remain separate gates. Real target mutation remains unavailable
until Task 35 receives its separate explicit diagnostic opt-in and passes the
signed-App disposable Trash gate.

## 13. Task 30 Handoff

Task 30 may start only after Task 29 is reviewed, verified, committed and
pushed. It will consume the immutable Plan and typed current-fact interfaces
to add:

- mutable in-memory selection semantics;
- pure per-item Policy decisions;
- fresh revalidation context;
- stale affected-item results;
- non-`Codable`, one-shot, 30-second admission authorization.

Task 30 must not reinterpret or expand the Task 29 Profile Catalog.

## 14. Implementation Outcome

Delivered:

- `builtin-runtime-tool-residue-v2`, still 67 Rules, with npm/pip as the only
  Ready rules;
- separate `safe-execution-v1` Profile Catalog with exact Go/npm/pip profiles
  and no uv profile;
- one captured running-activity context per complete Quick Scan/Review pass;
- closed static/filesystem/activity Evidence with complete privacy-safe
  fingerprints;
- exact uv read-only Review classification with no Plan eligibility;
- cursor-based complete Store validation and corruption isolation;
- immutable Cleanup Plans or typed empty/Scan Again outcomes;
- bounded five-group Review projection with all execution-profile candidates
  retained;
- new compiler/App resource parity and Review boundary gates.

The completion audit, confirmed findings, hashes, benchmark and verification
matrix are in
[Task 29 Review](../../reports/epic-8-task-29-review.md).
