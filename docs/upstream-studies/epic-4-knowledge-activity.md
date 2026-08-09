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

Rules use versioned YAML because it is reviewable and matches the approved
architecture. YAML is source, not runtime configuration from the scanned disk.

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
