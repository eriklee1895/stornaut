# ADR 0010: Knowledge Compiler and Activity Policy

> Status: Proposed; Task 14 compiler boundary validated, Task 19 activity
> acceptance pending
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

## Consequences

Positive:

- no new third-party dependency or shipped notice;
- App/Core have no runtime parser surface;
- source language, output schema and overlay monotonicity are testable;
- generated bytes are reproducible and provenance-bearing;
- future built-in catalog Tasks share one fail-closed compiler.

Costs:

- Task 14 source files cannot use YAML comments/anchors;
- the repository owns a small strict JSON tokenizer in the host compiler;
- Tasks 15–18 must author JSON unless a later dependency ADR changes the
  authoring frontend;
- sensitive-path compile checks are defense-in-depth examples and do not replace
  runtime canonical denylist evaluation.

## Residual Risks

- Tasks 15–17 provide Protected, project-artifact and package/build-cache
  sources; runtime/residue family coverage remains Task 18.
- Candidate matching is measured, but evidence/activity fusion and final
  classification remain Tasks 19–20.
- Activity providers and fail-conservative fusion are Task 19.
- Local overlay file selection/UI is later work; Task 14 only defines compiled
  monotonic semantics.
- `RulePathPattern` supports component literals plus whole-component `*`/`**`,
  not arbitrary regex/glob syntax.
- Deep Dive remains no-go/paused.

## Acceptance Gate

Keep this ADR Proposed until Task 19 proves:

1. built-in Tasks 15–18 catalogs compile deterministically with provenance and
   fixtures;
2. runtime matching remains within the benchmark budget;
3. Git/process/App signals preserve failures as Unknown;
4. activity/veto conflicts choose the conservative result;
5. Local Knowledge cannot lower denylist/veto/Policy;
6. full Phase B verification passes.
