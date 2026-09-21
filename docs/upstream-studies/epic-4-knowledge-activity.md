# Epic 4 Knowledge Base and Activity Upstream Study

> 状态：Accepted as the study gate for Epic 4 Tasks 14–19
>
> 日期：2026-08-09
>
> Coding Agent：TRAE CLI
>
> 目标模块：rule compiler、provenance、overlay、catalog、Git/App/process activity、Local Knowledge

## 1. Executive Conclusion

Stornaut's Knowledge Base will use:

- checked-in strict JSON authoring files (a YAML 1.2 subset);
- a host-side build/verification compiler;
- generated deterministic immutable Swift/JSON catalog input for runtime;
- no runtime YAML parsing of scanned-disk files;
- exact schema version, rule IDs and provenance;
- conservative overlay monotonicity;
- separate typed activity providers and a fail-conservative reducer;
- explicit user-confirmed structured Local Knowledge only.

Task 14 revalidated and rejected adding Yams `6.2.2` before a demonstrated
YAML-only authoring need. The host compiler accepts strict JSON only; it does
not claim YAML support, and no parser dependency reaches Core or the App.

## 2. Upstream Snapshots

| Source | Version/commit | License | Material read |
| --- | --- | --- | --- |
| [Mole](https://github.com/tw93/Mole) | `e83f44f8ca56bb49f93c0479c82a984601b22d5d` | GPL-3.0 | analyzer scanner/model/tests, `lib/clean/dev.sh`, `lib/core/app_protection.sh`, whitelist/history tests |
| [ClearDisk](https://github.com/bysiber/cleardisk) | `v1.9.0`, `1aaec92b91c40fdc0c2fce92fef20df08b5f5c43` | MIT | `DiskMonitor.swift`, `MainView.swift`, developer-cache/project behavior |
| [kondo](https://github.com/tbillington/kondo) | `1d351ca80b3d3adfad9bbe7db872c27359190210` | MIT | `kondo-lib/src/lib.rs`, artifact kinds and traversal behavior |
| [Cluttered](https://github.com/gatteo/cluttered) | tag `v1.2.0`, `03b38ad83df47adf0c6eba273e14a27b9f543258` | MIT | `git.ts`, `protectionAnalyzer.ts`, `scanner.ts`, `scanCache.ts`, renderer `scanStore.ts`, package metadata |
| [Yams](https://github.com/jpsim/Yams) | current main `df801bc4f158f107035d2e14f6d0d8d31eb31ddb`; tag `6.2.2` at `a27b21e0c81c5bf42049b897a62aaf387e80f279` | MIT | `Package.swift`, `LICENSE`, Codable/YAMLDecoder API |

### Source fingerprints

| File | SHA-256 |
| --- | --- |
| Mole `app_protection.sh` | `edd7b43ebf80e65911b7b5ed7de04d543dd450eb77bc697d4f9c456760e97b6d` |
| Mole `dev.sh` | `8c1d5a29f12958c4fccaee8f01da2ee55de63333a138ccdf03df2f25c33fae16` |
| ClearDisk `DiskMonitor.swift` | `4e0d766d3f6be1989e7d71efe2104461823c767fcb80735c10f08b18788cc7fb` |
| kondo `kondo-lib/src/lib.rs` | `0ddd4a6e218e3c3a67f37eb7f1f393b946b6b9bf9e907270cdede0409e540d64` |
| Cluttered `git.ts` | `0b62bd331a6f1f88769c04cb4e1fcec88a3d49a40f22d68bed1298477a3a43d3` |
| Cluttered `protectionAnalyzer.ts` | `eb0f873fedf129a5a5e9111a1d18998361b8ea163c19f734c244adb192d10708` |
| Cluttered `scanner.ts` | `66fdbb2dfea1f327a1795ae79f43b03388b429766efea24c0adf469972b4e0eb` |
| Cluttered `scanCache.ts` | `7f091e9ec9ad7907e5989b68384b515af56c08ca8644e86d3eacec2e53a5d322` |
| Yams `Package.swift` | `597593e7a5bbefb6f753d15770463e3a91b1789400b9468a15ae90b140755537` |
| Yams `LICENSE` | `0354b0ea403d2e78059c5ae0510a2cfae9f8eb306fcef094ac9fff5b47e20bed` |

No upstream code or fixture is copied.

## 3. Upstream Findings

### 3.1 Mole

Useful:

- broad developer-cache behavior and real-world test taxonomy;
- running-App protection before cache cleanup;
- whitelist and history behavior show the need for user-specific conservative
  overrides;
- explicit dry-run/cancel paths provide adversarial fixture ideas.

Rejected:

- GPL source/constant/path-list reuse;
- shell cleanup commands or generic whitelist substring matching;
- importing "safe" labels without independent producer/recovery/activity
  evidence;
- using cleanup scripts as the runtime rule format.

### 3.2 ClearDisk

Useful:

- native descriptions, producer labels and rebuild guidance;
- allocated-size awareness;
- Xcode-running warning and stale project views;
- local history deletion clearly says it does not restore files.

Rejected:

- one risk string carrying risk, disposition and action semantics;
- direct UI-to-cleaner calls;
- removing rows before action success;
- broad "clean all safe caches" based on static category alone.

### 3.3 kondo

Useful:

- explicit ecosystem/artifact taxonomy;
- project root detection and nested traversal boundaries;
- shared core and fixture organization.

Rejected:

- artifact-name match as sufficient reclaim evidence;
- logical size and ignored errors as ledger truth;
- permanent deletion model;
- Rust as an implementation requirement.

### 3.4 Cluttered

Useful:

- dirty/untracked Git status and last commit as separate signals;
- explicit protection reasons;
- one active scan guard and progress phases;
- bounded directory discovery count;
- SQLite transaction around batched scan-cache writes.

Important negative evidence:

- Git command failure returns `hasUncommittedChanges=false`, which can turn
  unknown activity into apparent safety;
- protection runs interpolated `lsof +D` shell strings;
- protected-path matching uses raw `startsWith`;
- timestamps alone classify active/recent/stale/dormant;
- renderer recomputes "cleanable" totals from `!isProtected`;
- result rows are mutated after cleanup rather than projected from immutable
  action records;
- optional PostHog/analytics and scheduled scanning are outside Stornaut v1.

Stornaut must preserve provider errors as unknown, use canonical component
containment, fixed executable/argv without Shell, and keep risk/confidence/
disposition independent.

## 4. Rule Source and Compiler Decision

### Authoring format

Rules use versioned strict JSON, a YAML 1.2 subset. Source is checked in and
host-compiled; it is never runtime configuration from the scanned disk.

### Compiler

The host compiler:

1. decodes a closed Codable schema;
2. rejects unknown schema fields/versions and duplicate IDs;
3. normalizes paths/globs without resolving real user paths;
4. validates provenance, recovery and activity requirements;
5. rejects arbitrary executable/args/Shell/permanent deletion;
6. verifies overlay monotonicity;
7. sorts by stable ID and emits deterministic catalog bytes/source;
8. emits a provenance/coverage manifest;
9. runs twice in verification and compares hashes.

### Yams candidate

Yams 6.2.2 is MIT, has no package dependencies, and bundles its `CYaml`
implementation. The current API supports Codable `YAMLDecoder`.

If added in Task 14:

- pin the exact version and lockfile;
- add copyright/license notice;
- keep it reachable only from the host compiler target;
- prove `StornautCore` and `Stornaut.app` do not link or bundle Yams/CYaml;
- reject YAML aliases/tags or other constructs not represented by the closed
  schema after decoding;
- bound input file size, rule count and scalar lengths before generation.

If those product-boundary checks fail, use JSON source or a separate verified
host tool rather than shipping a runtime parser.

## 5. Rule and Overlay Invariants

Every built-in rule requires:

- schema version and unique stable ID;
- match conditions and expected kind;
- producer and lifecycle category;
- disposition, independent risk and confidence requirements;
- veto and activity prerequisites;
- recovery/rebuild method and cost;
- typed recommended action, limited in Phase B to metadata only;
- exact source URL, project, commit/version, license, usage mode;
- independent verification date and fixture IDs.

Overlays may:

- exclude/narrow scope;
- add evidence requirements;
- increase risk;
- change a disposition only toward more conservative;
- add keep/protected decisions.

Overlays may not:

- weaken denylist/veto;
- promote directly to Ready to Reclaim;
- add arbitrary commands/actions;
- reduce activity requirements;
- replace provenance;
- match `/`, HOME or a volume root.

## 6. Activity Provider Brief

### Git

Use fixed `/usr/bin/git` executable and fixed read-only arguments with:

- `--no-optional-locks`;
- `GIT_OPTIONAL_LOCKS=0`;
- no hooks, user aliases or shell;
- bounded stdout/stderr and timeout;
- dirty, staged, untracked, branch, upstream/ahead and last-commit results kept
  as typed signals.

Any launch/parse/timeout/permission error is `unknown`, never clean.

### Running App/IDE/process

Prefer native process/workspace APIs for running App identity. Any open-file
inspection that requires a subprocess remains a later bounded provider with
fixed executable/args; do not copy Cluttered's interpolated shell.

### Reducer

- retains every raw typed signal and observation time;
- conflicts choose the more conservative outcome;
- active/veto evidence can protect but missing data cannot promote;
- staleness alone never produces Ready to Reclaim;
- Stornaut-caused observation timestamps are not user activity.

## 7. Structured Local Knowledge

Only explicit user confirmation can store:

- producer mapping;
- path-scope preference/exclusion;
- keep decision;
- verified recovery method;
- provenance and update time.

File identity, activity, catalog version or scope change makes dependent facts
stale. Local Knowledge is not free-text Agent memory, does not persist raw
content, and cannot override disposition/denylist/Policy.

## 8. Fixture and Benchmark Plan

- one positive and one safety fixture per rule family;
- cross-family collisions and lookalike names;
- case/Unicode/symlink/protected nesting;
- active/dirty/untracked/unpushed Git states;
- missing Git binary, timeout, malformed output and permission denial;
- running IDE/App conflicts;
- overlay downgrade attacks;
- deterministic compiler hash;
- cumulative catalog match benchmark over anonymous snapshots;
- coverage manifest proving every PRD FR-2 family has provenance and tests.

## 9. License and Reuse Boundary

Mole is behavior-only GPL research. ClearDisk, kondo and Cluttered are MIT but
their code and fixtures are not copied. Yams is only a proposed host-tool
dependency and is not added by Task 9.

## 10. Relative Improvement

Stornaut turns upstream path/taxonomy experience into a closed, provenance-
checked data language; turns activity into independent fail-conservative
evidence; and prevents user overlays or Local Knowledge from becoming a policy
bypass.

## 11. Task 14 Dependency Gate Update

Task 14 revalidated Yams 6.2.2 at tag commit
`a27b21e0c81c5bf42049b897a62aaf387e80f279`:

- `Package.swift` declares no package dependencies, but the Yams product links
  both `Yams` and bundled `CYaml`/LibYAML targets;
- the MIT license is compatible and requires retaining the 2016 JP Simard
  copyright/license notice if distributed;
- current documentation confirms `YAMLDecoder.decode(_:from:)` and Yams `Node`,
  but does not promise that Codable decoding rejects unknown keys, aliases or
  tags; Stornaut would still need a separate Node-level strictness audit;
- keeping the product reachable only from a host compiler would avoid App/Core
  linking, but still adds a lockfile, C parser surface and supply-chain input.

For Task 14's intentionally minimal compiler/schema/overlay foundation, that
cost is not yet justified. Task 14 uses strict checked-in **JSON authoring
source**, decoded by Foundation after an explicit unknown-key/type/depth/size
audit. JSON is a YAML 1.2 subset, so a future approved Yams host compiler can
consume the same source without changing the immutable runtime schema.

This revises the earlier rejection of a private YAML subset: Stornaut is not
claiming to parse YAML at all in Task 14. It deliberately accepts only JSON and
fails every YAML-only construct. If Tasks 15-18 establish a real authoring need
for comments, anchors or other YAML syntax, add Yams through a separate
dependency ADR, notice and App-bundle reachability gate.

No third-party dependency or notice is added in Task 14. Runtime still consumes
only compiler-produced immutable catalog bytes; it never parses rule source
from the scanned disk.

## 12. Task 15 Protected Catalog Update

Task 15 adds the first production built-in source:
[`../../Rules/BuiltIn/protected-v1.json`](../../Rules/BuiltIn/protected-v1.json).

### Catalog scope

- 28 immutable Protected/veto rules;
- browser profiles: Arc, Brave, Chrome, Edge, Firefox and Safari;
- credential stores: AWS, Azure, Docker, gcloud, GitHub CLI, GnuPG,
  Keychains, Kubernetes, 1Password CLI and OpenSSH;
- 1Password, Bitwarden and LastPass data locations;
- Mail, Messages and Photos data;
- representative `.env`, `credentials.json` and private-key files.

Every rule is critical, has no action/recovery surface, carries a rationale and
has exactly one positive plus one component-lookalike fixture.

### Provenance decision

Each concrete rule has two exact repository-owned MIT sources at commit
`766d8e7d2b533f5393ea5fac81935f416fb0402b`:

1. the PRD permanent-denylist requirement, as official documentation;
2. the already-implemented Swift permanent denylist, as independently observed
   behavior.

This is intentionally not a claim that an upstream cleaner owns these path
facts. Mole remains behavior-only GPL research; no Mole path table, constant,
code or fixture was copied. The fixtures are independently authored and contain
no user data or secrets.

### Independent policy coverage

The catalog is defense in depth, not authority for sensitive paths:

- `SensitivePathDenylist` rejects catalog families without loading the catalog;
- its absolute system prefixes are canonical component sequences, not raw
  string prefixes;
- symlink-resolved sensitive targets, mixed case and Unicode variants reject;
- lookalike components remain allowed;
- filesystem root, HOME and volume roots remain separate
  `CanonicalPathPolicy` decisions.

No root/HOME/volume sentinel rule is created because relative rule patterns
cannot truthfully represent those absolute boundaries.

### Verification

- 70 clean-room path cases cover positive/lookalike, nested, mixed-case,
  Unicode, symlink and absolute-system behavior;
- overlay downgrade attempts fail;
- source schema now requires rationale and Core requires Protected risk to be
  critical;
- the rule-to-fixture test proves every pattern protects its positive path and
  does not protect its lookalike;
- two compiler runs produce identical catalog, manifest and SHA-256
  `6c51931b3d0f7460edff658b6ad4137eba4396128581439c3d664a042d1ebe96`;
- no dependency or ThirdPartyNotices change is required.

Runtime classification orchestration and cumulative matching performance remain
Tasks 20 and 16–18 respectively. ADR 0010 remains Proposed until Task 19 and
the Phase B acceptance gate complete.

## 13. Task 16 Project Artifact Catalog Update

Task 16 adds
[`../../Rules/BuiltIn/project-artifacts-v1.json`](../../Rules/BuiltIn/project-artifacts-v1.json)
as an independent source instead of mutating Task 15's immutable
`protected-v1.json`.

### Official source snapshot

| Ecosystem | Exact source | License | Verified behavior |
| --- | --- | --- | --- |
| Node.js/npm | npm CLI `4cdcceac047f82571d0ec734e18b87d1d130e042` | Artistic-2.0 | install-managed `node_modules` |
| Python | CPython `5107fd700d70abf62762d09f766200532866e823` | Python-2.0 | venv is disposable and recreated from dependency inputs |
| Rust | Cargo `a07c49a989d565727725e5bb5a8038ff402006a8` | Apache-2.0 | target contains generated artifacts; cargo clean removes them |
| Go | Go `e5ec1263ca5e1428d233206b99dc21c38ea2a124` | BSD-3-Clause | module vendor generation/metadata |
| Java/Gradle | Gradle `f85ff712e07bb79dd122880d87b3b6f0e974a35a` | Apache-2.0 | build-directory lifecycle |
| Java/Maven | Maven Clean Plugin `d4e0c52c730bc88b579ac6fe503bdb96bcdccc76` | Apache-2.0 | clean lifecycle removes generated output |
| Ruby | RubyGems/Bundler `236160535f659cc49b54b7da5e841fe8cafa3c06` | MIT | bundle install path behavior |
| PHP | Composer `c435d285c9120efdca35696769c72ea9fdcc0466` | MIT | install from composer metadata |
| Flutter | Flutter `28e6279c3580382dbd1ba599e19c681d3debcc70` | BSD-3-Clause | generated build output and clean behavior |
| Xcode | Xcode 26.6 official documentation | Apple documentation terms | build/rebuild lifecycle |

All ten official URLs were read at their exact revision during Task 16 review.
No upstream code or fixture was copied.

### Conservative rule policy

Ten rules cover the nine PRD project families (Java has Gradle and Maven).
Every rule remains Review Recommended and requires:

- exact project marker;
- artifact-specific layout signature;
- artifact not tracked by version control;
- recovery/lockfile inputs present;
- Git clean and upstream synchronized;
- inactive related process.

An artifact basename never establishes recovery or safety. `build`, `target`
and `vendor` intentionally return multiple candidate rules; later evidence
selects a family. A project root or source directory never matches these
artifact patterns.

### Multi-source compiler

The host compiler accepts one to 16 independently versioned sources with a
1 MiB aggregate bound. It validates rule IDs and fixture ownership globally,
sorts source versions in the manifest and emits source-order-independent bytes.
The CLI accepts repeated `--catalog` only with an explicit cumulative
`--catalog-version`; duplicate singleton flags fail.

This preserves the Task 15 source hash while producing cumulative version
`builtin-project-artifacts-v1`.

### Candidate matcher

`RuleCatalogMatcher` is a pure candidate matcher:

- component-level `*`/`**`, exclusions and kind matching;
- path byte/component bounds and traversal refusal;
- precompiled exact/case-insensitive forms;
- explicit volume case-sensitivity input;
- no filesystem I/O, evidence reads, activity fusion or disposition promotion.

It does not implement the Task 20 classifier.

### Clean-room behavior comparison

The comparison fixture records documented behavior, not copied implementation:

- kondo known-name taxonomy becomes only a candidate in Stornaut;
- ClearDisk risk/recovery guidance cannot override dirty/active state;
- Mole running-App protection becomes a typed activity prerequisite;
- missing marker/layout/recovery/Git/process evidence blocks recommendation;
- roots and source directories remain non-candidates.

The cumulative matcher benchmark runs the Task 16 cases plus the anonymous
developer-tree paths over 38 rules. Debug runs complete around 0.95–1.07 s for
250 iterations, below the 2 s regression gate.

The reviewed cumulative catalog SHA-256 is
`b9f631e9cced76e61842ac629af72b00fe20c8ebff41c89ed75908b90c577335`.

## 14. Task 17 Package and Build Cache Catalog Update

Task 17 adds
[`../../Rules/BuiltIn/package-build-caches-v1.json`](../../Rules/BuiltIn/package-build-caches-v1.json)
as the third independently versioned catalog source. The shared authoring
schema is versioned separately and is not itself a source catalog.

### Official source snapshot

Exact official commits/documentation were verified for npm, pnpm, Yarn, Bun,
uv, pip, Conda, Cargo, Go, Gradle, Maven and Homebrew. All 16 rule-source URLs
returned content during post-fix review. The source records the relevant MIT,
Apache-2.0, BSD-2/3-Clause, Artistic-2.0 and dual-license identifiers.

No source code, constant table or fixture is copied. These materials establish
cache lifecycle and path ownership only.

### Cache/runtime/config boundary

Seventeen rules cover the 12 PRD families with exact safe variants:

- npm `_cacache`;
- pnpm Library, legacy home and XDG stores;
- Yarn global cache and Bun install cache;
- uv and pip caches;
- Conda `.conda`, Miniconda and Anaconda package roots;
- Cargo registry cache;
- Go build and module caches;
- Gradle dependency modules;
- Maven local repository;
- Homebrew downloads.

The rules intentionally do not match installed package-manager binaries,
virtual environments, Conda envs, Cargo credentials or `bin`, project-owned
Yarn offline caches, Homebrew Cellar, source trees or configuration files.

Every rule requires tool-owned layout, current-user scope, reclaimable cache
evidence and an inactive process. Mixed repositories add:

- Conda/pnpm: unreferenced data;
- Maven: no locally published artifacts;
- Homebrew: unreferenced downloads.

All remain Review Recommended.

### Manifest v2

Task 17 increments the generated compiler manifest to schema v2. In addition to
aggregate counts/hash/source versions, it contains a sorted entry for every
rule with:

- rule ID and rationale;
- complete HTTPS provenance, revision, license, usage and verification date;
- fixture IDs.

Aggregate provenance and fixture counts are verified against these entries.

### Clean-room behavior comparison

- ClearDisk's static cache taxonomy becomes only a candidate; path alone does
  not establish ownership, inactivity or reclaimability.
- Mole's running-App protection becomes a typed process prerequisite.
- kondo-style artifact taxonomy does not make installed runtimes/configuration
  candidates.
- Maven local artifacts and Conda environment references block recommendation.

Mole remains GPL behavior-only.

### Matching performance

The matcher now pre-filters by expected kind and terminal literal before
component-glob evaluation. The 55-rule benchmark over cache, project and
anonymous-developer-tree paths improved from about 1.95 s to 0.97–1.21 s for
the fixed debug workload, preserving the 2 s gate for Task 18 growth.

The cumulative catalog version is `builtin-package-build-caches-v1`, with
reviewed SHA-256
`4dd2ed03f74d20d47ec0670310edb1ff1297c188b307c69a71e9c3f25ae54794`.

## 15. Task 18 Runtime, Tool and Residue Catalog Update

Task 18 adds
[`../../Rules/BuiltIn/runtime-tool-residue-v1.json`](../../Rules/BuiltIn/runtime-tool-residue-v1.json)
as the fourth and final Phase B catalog source.

### Runtime vs reclaimable residue

Five runtime/image rules default to Unknown with no action:

- Docker Desktop VM disk;
- Colima and Lima instance disks;
- Xcode simulator devices;
- AI desktop VM bundles.

Paths and logical size cannot prove detachment, lack of user data or safe
reconstruction. These facts remain typed requirements for later activity/
classification fusion, not an authorization to reclaim.

Seven tool-cache/residue rules remain Review Recommended:

- Codex runtime cache;
- Cursor, JetBrains and VS Code caches;
- Lark update downloads;
- Codex abandoned temporary storage;
- VS Code ShipIt residue.

They require user/tool ownership, no user data, recovery inputs, inactive
process and a specific reclaimable/not-current/abandoned fact.

### Source provenance

Official Docker, Colima, Lima, Apple Xcode, VS Code, Electron/Squirrel and
OpenAI Codex sources are pinned to exact commits or explicit product-document
versions. JetBrains and Cursor are versioned external documentation snapshots.
Cursor CachedData layout is marked black-box verification rather than claimed
as a documented path.

All 12 first-party URLs were live-verified. No code, constants or fixtures are
copied.

### Complete FR-2 audit

Task 18 adds the host-only `RuleCoverageCompiler`. Its strict JSON input maps:

- five stable FR-2 families;
- 36 named PRD subrequirements;
- all 67 compiled rules exactly once;
- four Swift policy keys covering filesystem root, HOME, mount roots and
  system locations.

The output joins every rule with category, disposition, risk, action, rationale,
provenance and fixtures. Unknown, duplicate, missing, fractional-version or
policy-incomplete inputs fail.

The compiler CLI validates and encodes coverage before writing any output, so a
coverage failure cannot leave a successful partial catalog/manifest.

### Clean-room safety comparison

- Sparse VM disks remain Unknown; apparent size is never reclaimability.
- Static IDE cache taxonomy cannot override a running process.
- ShipIt/update paths require a non-current update fact.
- AI runtime bundles remain Unknown if content ownership is unclear.
- user data, credentials, configs, mounted/attached images and current updates
  stay blocked or do not match.

### Complete benchmark

The complete 67-rule catalog stays below the fixed 2 s debug matcher gate
(about 1.25–1.30 s). The complete catalog version is
`builtin-runtime-tool-residue-v1`, with reviewed SHA-256
`133b3829816fa951f03cb87473e03454c3e561b421c83e6c8efaf8ad89849e99`.

## 16. Task 19 Activity and Local Knowledge Gate Refresh

Task 19 revalidated the provider boundary on 2026-08-10 before writing
production code.

### Git provider

The local target is Apple Git `2.50.1 (Apple Git-155)`. Its installed manual
confirms:

- porcelain status output is stable across versions and user configuration;
- porcelain v2 exposes branch OID, branch, upstream and ahead/behind headers;
- `--no-optional-locks` is equivalent to `GIT_OPTIONAL_LOCKS=0` and prevents
  optional side effects such as index refresh;
- `GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_SYSTEM=/dev/null` suppress
  user/global configuration.

The provider will launch only `/usr/bin/git` with fixed commands. It will add
per-command `core.hooksPath=/dev/null`, `core.fsmonitor=false` and
`core.untrackedCache=false`, use a minimal environment, bound both output
streams and apply a fixed timeout. It will parse status and last-commit output
as separate typed observations so loss of an informational timestamp does not
erase valid dirty/untracked/ahead evidence.

A temporary dirty repository probe showed that status plus last-commit reads
left the complete `.git` file path/mtime/size digest unchanged. This is
behavioral evidence, not a claim that arbitrary Git commands are read-only;
the fixed executable, arguments and environment remain the enforceable
boundary.

### App and process providers

The macOS 26.5 SDK headers confirm that
`NSWorkspace.runningApplications` returns an atomic, thread-safe snapshot of
all running applications. `NSRunningApplication` provides optional bundle ID,
localized name and executable URL plus a process identifier; values can change
after the snapshot and therefore remain observation-time evidence, not a
durable assertion.

Related non-App processes use bounded native current-user `libproc` enumeration
through `proc_listpids(PROC_UID_ONLY)` and `proc_name`. Review rejected
all-process enumeration because the local probe could not name 253 of 806 PIDs;
silently dropping those rows could falsely prove inactivity. PID-list
truncation, a still-live PID without a readable name, permission failure or
collection failure therefore produces Unknown only for the dependent process-
activity requirement. Task 19 does not inspect open files and does not invoke
`lsof`, `ps`, Shell or an Adapter.

### Fusion and structured knowledge

- Git dirty, staged, untracked, missing upstream, ahead/behind, running App and
  related process signals are independent typed observations.
- A contradicted activity prerequisite protects the candidate; missing or
  failed prerequisite data yields Unknown, including a same-key
  satisfied/unavailable conflict. Satisfied evidence cannot promote a more
  conservative base disposition.
- Recent external activity can protect, stale time is informational only, and
  Stornaut-caused timestamps never count as user activity.
- Stable activity fingerprints exclude collection time and Stornaut-caused
  timestamps, so re-observation alone does not invalidate Local Knowledge.
- Local Knowledge replaces the earlier generic `kind/value/stale` skeleton
  with closed user-confirmed payloads and applicability bindings. It stores no
  disposition override or free-text Agent memory.
- Scope, file identity, activity fingerprint or catalog-version changes mark a
  retained fact stale with typed reasons rather than deleting or silently
  applying it.

No new dependency, entitlement, TCC permission, background monitor or target
write is introduced.
