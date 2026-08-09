# Epic 2–4 Task 17 Code Review — 2026-08-10

> 状态：All confirmed findings fixed; post-fix review has no open P0–P2
> finding
>
> 范围：package/build cache catalog、ownership/activity fixtures、
> reviewable provenance manifest 与 cumulative matcher benchmark
>
> 方法：tests-first source/manifest probes + `bits-code-guard` working-tree
> scope + 7-dimension safety review + live provenance audit

## 1. Review Scope

- 17 cache rules covering all 12 approved families and common safe path
  variants;
- 68 clean-room positive/active/config/runtime-source cases;
- five behavior comparisons against documented Mole/ClearDisk/kondo behavior;
- per-rule manifest provenance/rationale/fixture coverage;
- 55-rule cumulative candidate matcher and four-source CLI compilation;
- no repository custom review workflow.

The post-fix automatic report is retained at
`/tmp/stornaut_task17_review_1786309152/report.html` and reports no open
P0–P2 finding.

## 2. Tests-First Finding

| Severity | Finding | Fix | Regression evidence |
| --- | --- | --- | --- |
| P1 | The production catalog had no package/build cache source; category enums and case-study paths were not reviewable rules | Add an independent strict-JSON source plus ownership/activity/recovery fixtures and cumulative compile gate | source-absence red test, 17-rule catalog and 68 fixtures |
| P1 | Manifest only exposed aggregate provenance/fixture counts, so Task 17 could not review every source/license/date/usage | Add schema-v2 per-rule manifest entries containing rationale, provenance and fixture IDs | 55 entry order/completeness and aggregate consistency tests |

## 3. Code Review Findings and Fixes

| Severity | Finding | Fix | Regression evidence |
| --- | --- | --- | --- |
| P1 | Conda only matched `.conda/pkgs`, missing common Miniconda/Anaconda package roots | Add exact `.conda`, `miniconda3` and `anaconda3` rules; never use broad `**/pkgs` | three independent positive/active/config/env groups |
| P1 | pnpm only matched `Library/pnpm/store`, missing legacy and XDG stores | Add exact `Library/pnpm/store`, `.pnpm-store` and `.local/share/pnpm/store` rules | three independent fixture groups |
| P1 | Ownership/layout/inactive facts did not prove cached data was reclaimable | Require `evidence.cache.reclaimable` for every cache rule | exact requirement partition tests |
| P1 | Manifest added fields while keeping schema version 1 | Increment manifest schema to v2 | generated JSON and direct manifest assertion |
| P1 | Homebrew downloads and pnpm stores could contain currently referenced data | Require unreferenced evidence; Conda retains its existing unreferenced gate | source and fixture assertions |
| P1 | Task 17 covered Go build cache but omitted Go module download cache | Add exact `go/pkg/mod` rule with config and `go/bin` lookalikes | Go build/module fixture groups |
| P1 | 54-rule matcher benchmark had only ~50 ms headroom under a 2 s gate | Pre-filter by expected kind and terminal literal before component-glob DP | repeated benchmark improves from 1.95 s to ~0.97–1.21 s |
| P1 | Maven local repository and Conda package stores mix cache-like data with local artifacts or environment references | Require no-local-artifacts / unreferenced evidence and keep high-risk Review Recommended | behavior comparison and requirements |

## 4. Catalog Result

### Families and exact variants

- npm `_cacache`
- pnpm Library, legacy home and XDG stores
- Yarn global cache
- Bun install cache
- uv and pip caches
- Conda `.conda`, Miniconda and Anaconda package roots
- Cargo registry cache
- Go build and module caches
- Gradle dependency modules
- Maven local repository
- Homebrew downloads

The source deliberately excludes:

- installed package-manager runtimes and global binaries;
- virtual environments and Conda envs;
- Cargo credentials/config and `bin`;
- project Yarn offline cache that may be checked into source control;
- Homebrew Cellar;
- package source trees and user-owned config.

### Required evidence

Every cache rule requires:

- exact tool-owned cache layout;
- current user ownership/scope;
- cache data proven reclaimable;
- inactive related tool/process.

Mixed repositories add stronger gates:

- Conda and pnpm: unreferenced data;
- Maven: no locally published artifacts;
- Homebrew downloads: unreferenced artifact.

All rules remain Review Recommended. No cache becomes Ready from a static path
or age.

## 5. Provenance and Reuse

- 16/16 official source URLs passed live exact-revision audit.
- Licenses include MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause,
  Artistic-2.0 and uv's Apache-2.0/MIT dual option.
- Sources are documentation/behavior provenance only; no code or fixture is
  copied and no dependency is distributed.
- Mole remains GPL behavior-only.

Manifest v2 makes every rule's URL, revision, license, usage, verification date,
rationale and fixture IDs machine-reviewable.

## 6. Focused Verification

- RuleCompiler/cache/manifest/matcher tests: 27/27.
- RuleCatalog contract tests: 6/6.
- Four-source catalog is source-order independent.
- Protected and project source hashes remain unchanged.
- Cumulative cache catalog hash:
  `4dd2ed03f74d20d47ec0670310edb1ff1297c188b307c69a71e9c3f25ae54794`.
- 55-rule matcher benchmark: about 0.97–1.21 s under the 2 s debug gate.

Full `scripts/verify` passed:

- 213 SwiftPM tests (3 opt-in diagnostics skipped by design);
- Xcode App contract tests;
- 2/2 XCUITest cases;
- four Light/Dark screenshots and image checks;
- App signing, bundle verification and localization parity;
- manifest-v2/compiler/hash/source-order/CLI/App-leakage gate;
- docs links and diff checks.

## 7. Remaining Boundaries

- Candidate matching does not satisfy ownership/activity facts itself.
- Task 18 adds runtime/image/tool/update/residue families and reruns the
  cumulative benchmark.
- Task 19 owns activity fusion and Task 20 final classification orchestration.
- No rule executes a package-manager cleanup command.
- ADR 0010 remains Proposed; Deep Dive remains no-go/paused.
