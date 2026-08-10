# ADR 0010: Knowledge Compiler and Activity Policy

> Status: Accepted; Tasks 14–19 compiler, catalog, activity and structured
> knowledge gates validated
>
> Date: 2026-08-10
>
> Decision owners: Stornaut maintainers
>
> Related study:
> [`../upstream-studies/epic-4-knowledge-activity.md`](../upstream-studies/epic-4-knowledge-activity.md)

## Context

The Knowledge Base needs reviewable authoring source, exact provenance,
deterministic runtime bytes and conservative local overlays. It must never
become:

- runtime configuration loaded from scanned disks;
- an arbitrary command/action language;
- a bypass for permanent denylist, rule veto or Policy Gate;
- a source of Ready to Reclaim without recovery and activity evidence.

The accepted Epic 4 study proposed Yams 6.2.2 as a host compiler dependency,
subject to a fresh Task 14 dependency/bundle gate.

## Decision

### Task 14 authoring format

Use strict checked-in JSON source for the Task 14 compiler foundation.

JSON is a YAML 1.2 subset and preserves a future migration to Yams without
changing the immutable runtime schema. Task 14 deliberately does not claim to
parse YAML and rejects all YAML-only syntax.

Yams was revalidated as MIT/no package dependency, but its product includes
Yams plus bundled CYaml/LibYAML targets. Codable decoding does not by itself
prove unknown-key, alias or tag rejection. Adding it now would introduce a C
parser/lockfile/supply-chain surface without a demonstrated authoring need.

If Tasks 15–18 require comments, anchors or other YAML-only features, add Yams
through a separate dependency ADR, notice and App-bundle reachability audit.

### Host-only compiler topology

The Swift package contains:

- `StornautCore`: immutable `RuleCatalog` contracts only;
- `RuleCompilerKit`: strict source parser, validation, overlay reducer and
  deterministic emitter;
- `stornaut-rule-compiler`: host CLI;
- `RuleCompilerTests`: compiler/overlay tests.

Machine verification requires `RuleCompilerKit` consumers to be exactly the CLI
and its tests. Neither StornautCore, StornautCodex nor Stornaut.app can depend on
or bundle the compiler.

Runtime consumes only compiler-produced immutable catalog bytes. It never parses
rule source from a scan target.

### Strict source boundary

Before Foundation decoding, `StrictJSONAuditor` enforces:

- maximum 1 MiB input;
- maximum nesting depth 16;
- maximum scalar length 16 KiB;
- exact JSON grammar and valid UTF-8 strings;
- duplicate object-key rejection.

The compiler then enforces exact allowed/required keys at every object level,
schema version 1, at most 4,096 rules/overlays and bounded lists/scalars.

### Rule safety

Every rule requires:

- stable lowercase ID;
- bounded relative `*`/`**` path pattern with at least one literal component;
- expected kind, producer, category, disposition, risk and confidence;
- a stable rationale key;
- veto, required evidence/activity, recovery, recommended action;
- at least two unique fixture IDs;
- exact HTTPS provenance source, revision, license, usage and non-future
  independent verification date.

Action metadata is a closed enum: `none` or `moveToTrash`. It carries no target
path, executable, arguments, Shell or permanent-delete surface.

Ready to Reclaim requires:

- high confidence requirement;
- recovery guidance;
- non-empty evidence and activity requirements;
- MoveToTrash recommendation;
- no veto.

Protected requires veto, critical risk in source and after protection overlays, and no
recommended action. Unknown cannot recommend an action.

Non-protected rules cannot intersect the permanent sensitive-path examples
using the compiler's component-aware `*`/`**` glob matcher. This is defense in
depth; runtime `SensitivePathDenylist` remains independently authoritative.

### Monotonic overlays

Overlays are sorted by stable ID and may only:

- add exclusions;
- add required evidence/activity;
- raise risk;
- move disposition toward Review, Unknown or Protected;
- force Protected.

They cannot promote Ready, reduce risk, weaken Protected/veto, remove
requirements/provenance, replace an action or target a missing rule.

Multiple overlays on one rule remain monotonic after every step.

### Deterministic output

The compiler sorts rules and set-like fields, emits `DomainJSON` sorted-key
bytes, computes SHA-256 and emits a coverage/provenance manifest.

`scripts/verify-rule-compiler`:

1. compiles the same source+overlay twice;
2. compares catalog, manifest and hash bytes;
3. validates checked schemas and generated JSON;
4. verifies no external package dependency;
5. verifies host-only target consumers;
6. rejects source/output and symlink collisions;
7. audits Stornaut.app for compiler/YAML leakage.

### Activity provider boundary

Runtime activity evidence is a closed StornautCore contract:

- fixed `ActivityKey` values cover Git clean, Git upstream synchronization and
  related-process inactivity;
- every observation retains state, source, origin, reason and collection time;
- provider failure is explicit and never decodes as clean/inactive;
- a contradiction protects, missing/unavailable dependent evidence yields
  Unknown, and satisfied evidence never promotes the base disposition;
- recent external activity can protect, but time alone cannot produce Ready to
  Reclaim;
- Stornaut-origin timestamps are excluded from user-activity decisions and
  stable activity fingerprints.

Git uses only `/usr/bin/git status` and `git log` behind an internal runner
seam. Arguments, environment, 2-second timeout and output limits are fixed.
Global/system config, hooks, fsmonitor, untracked-cache writes, optional locks,
terminal prompts and lazy fetch are disabled.

Running Apps use `NSWorkspace.runningApplications`. Related non-App processes
use bounded current-user `libproc` enumeration. A truncated PID list or
still-live process without a readable name prevents an inactive conclusion.
Task 19 adds no `lsof`, `ps`, Shell, Adapter, open-file scan or background
monitor.

### Structured Local Knowledge

`LocalKnowledgeFact` accepts only the closed user-confirmed payloads:

- producer mapping;
- include/exclude path preference;
- keep decision;
- verified recovery method and rebuild cost.

Every fact binds its scope, file identity, stable activity fingerprint and
catalog version, plus observed/updated timestamps. Applicability returns typed
stale reasons for any changed binding while retaining the fact for review.
There is no free-text value, Agent-inferred provenance or disposition override.

The local database migrates from the Task 11 v1 skeleton to schema v2 only
after validating the owned v1 table/index signature. Legacy generic payloads
remain stored but are isolated as corrupt/unusable records; malformed v1
schemas are rejected without changing `user_version`.

## Evidence

Task 14 tests cover:

- deterministic sort/hash/manifest and immutable round-trip;
- unknown/duplicate keys, versions, IDs and fixture ownership;
- unsafe root/HOME/traversal/glob patterns;
- denylist intersection including zero-or-more `**`;
- size/depth/scalar/list bounds and malformed numbers;
- provenance completeness, HTTPS source and future verification date;
- Ready confidence/recovery/evidence/activity/action gates;
- Unknown/Protected action gates;
- risk/disposition/veto downgrade attacks;
- multiple overlays on one rule in stable order;
- source/output and symlink collision refusal.

Task 15 evidence adds:

- a required rationale field in source and immutable output;
- 28 built-in Protected/veto rules with exact dual-source provenance;
- 70 clean-room positive/lookalike/case/Unicode/symlink/system fixtures;
- independent `SensitivePathDenylist` coverage when the catalog is absent;
- separate filesystem-root, HOME and volume-root `CanonicalPathPolicy` gates;
- deterministic production catalog hash
  `6c51931b3d0f7460edff658b6ad4137eba4396128581439c3d664a042d1ebe96`.

Task 16 evidence adds:

- bounded, source-order-independent compilation of versioned catalog sources;
- source catalog versions in the generated manifest;
- immutable preservation of `protected-v1`;
- ten conservative project artifact rules with official exact-revision
  provenance and clean-room fixtures;
- recovery, artifact-layout, not-versioned and activity requirements for every
  MoveToTrash recommendation;
- a pure bounded candidate matcher with explicit volume case-sensitivity;
- cumulative catalog hash
  `b9f631e9cced76e61842ac629af72b00fe20c8ebff41c89ed75908b90c577335`.

Task 17 evidence adds:

- 17 package/build cache rules with explicit runtime/environment/config
  exclusions and 68 clean-room fixtures;
- user ownership, tool layout, reclaimable and inactive-process requirements;
- stronger unreferenced/no-local-artifact gates for mixed repositories;
- schema-v2 generated manifests with per-rule provenance/rationale/fixture
  entries;
- terminal-literal matcher prefiltering and 55-rule benchmark evidence;
- cumulative catalog hash
  `4dd2ed03f74d20d47ec0670310edb1ff1297c188b307c69a71e9c3f25ae54794`.

Task 18 evidence adds:

- the remaining runtime/image/tool/update/temp source with Unknown/no-action
  defaults for VM/runtime state;
- 48 active/mounted/current/user-data/destructive-lookalike fixtures;
- host-only FR-2 coverage compilation over five families, 36 requirements,
  67 rules and four Swift policy keys;
- atomic CLI coverage validation/output and complete benchmark evidence;
- complete catalog hash
  `133b3829816fa951f03cb87473e03454c3e561b421c83e6c8efaf8ad89849e99`.

Task 19 evidence adds:

- fixed Git requests and a real temporary-repository test proving no path,
  identity or content mutation;
- AppKit and bounded current-user `libproc` providers with incomplete-coverage
  fail-closed behavior;
- conservative fusion tests for dirty/untracked/unpushed, running App/process,
  missing/permission/error, timestamp origin and same-key conflict;
- activity-protected dispositions that preserve the original artifact category;
- closed Local Knowledge payloads, stable applicability bindings and v1→v2
  migration/corrupt isolation;
- `scripts/verify-activity-boundaries`, which rejects Shell, `lsof`, `ps`,
  target-write surfaces, public generic command seams and Git commands beyond
  `status`/`log`;
- post-fix code review with no open P0–P2 finding and 241 passing Swift tests.
- final unified verification with the activity boundary gate, 2/2 App contract
  tests, 2/2 XCUITest cases, four screenshots, App signing/bundle,
  localization, deterministic compiler/catalog and docs gates.

## Consequences

Positive:

- no new third-party dependency or shipped notice;
- App/Core have no runtime parser surface;
- source language, output schema and overlay monotonicity are testable;
- generated bytes are reproducible and provenance-bearing;
- future built-in catalog Tasks share one fail-closed compiler.
- activity failures remain typed and affect only dependent classifications;
- Local Knowledge can become stale but cannot become a policy override.

Costs:

- Task 14 source files cannot use YAML comments/anchors;
- the repository owns a small strict JSON tokenizer in the host compiler;
- Tasks 15–18 must author JSON unless a later dependency ADR changes the
  authoring frontend;
- sensitive-path compile checks are defense-in-depth examples and do not replace
  runtime canonical denylist evaluation.
- Task 19 current-process discovery intentionally returns Unknown when native
  current-user enumeration cannot prove complete coverage.

## Residual Risks

- Tasks 15–18 provide all four planned catalog sources plus the separately
  versioned authoring schema and complete FR-2 coverage manifest.
- Candidate matching and activity fusion are measured/tested, but final Quick
  Scan orchestration and classification remain Task 20.
- Local overlay file selection/UI is later work; Task 14 only defines compiled
  monotonic semantics.
- `RulePathPattern` supports component literals plus whole-component `*`/`**`,
  not arbitrary regex/glob syntax.
- Deep Dive remains no-go/paused.

## Acceptance Gate

Accepted after the final post-review unified verifier proved:

1. built-in Tasks 15–18 catalogs compile deterministically with provenance and
   fixtures;
2. runtime matching remains within the benchmark budget;
3. Git/process/App signals preserve failures as Unknown;
4. activity/veto conflicts choose the conservative result;
5. Local Knowledge cannot lower denylist/veto/Policy;
6. full Phase B verification passes.
