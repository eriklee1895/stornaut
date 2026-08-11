# Epic 2–4 Task 16 Code Review — 2026-08-10

> **Historical-scope notice (2026-08-11):** Deep Dive paused/no-go references
> record the reviewed Phase B scope, not current Codex policy. See capability-first
> [ADR 0004](../adr/0004-codex-file-read-isolation.md).

> 状态：All confirmed findings fixed; post-fix review has no open P0–P2
> finding
>
> 范围：versioned multi-source catalog compiler、project artifact rules、
> candidate matcher、clean-room fixtures、provenance 与 cumulative benchmark
>
> 方法：tests-first contract probes + `bits-code-guard` working-tree scope +
> 7-dimension safety review + live provenance audit + deterministic CLI gate

## 1. Review Scope

- 19 final Task 16 files after documentation/status updates;
- ten project rules covering nine approved ecosystems;
- 40 positive/safety/root/source fixture cases and five clean-room behavior
  comparisons;
- source-set compiler/manifest/CLI bounds and deterministic order;
- exact/case-insensitive component matcher, exclusions and input bounds;
- recovery, artifact layout, version-control and activity prerequisites;
- no repository custom review workflow.

The post-fix automatic report is retained at
`/tmp/stornaut_task16_review_1786307354/report.html` and reports no open
P0–P2 finding.

## 2. Tests-First Findings and Fixes

| Severity | Finding | Fix | Regression evidence |
| --- | --- | --- | --- |
| P1 | The compiler accepted one source only, forcing later Tasks either to mutate `protected-v1` or copy its rules into a new file | Add bounded versioned source-set compilation with global rule/fixture validation, stable source-version manifest and order-independent output | reordered two-source compile has identical bytes/hash; duplicate versions/rules and 17-source/1 MiB overflow reject |
| P1 | `reviewRecommended + moveToTrash` could omit recovery, evidence or activity requirements because Core only guarded Ready | Apply recovery/evidence/activity requirements to every MoveToTrash recommendation | three direct Core rejection cases |
| P1 | Project source initially existed only as test data without a production matching primitive | Add pure candidate-only `RuleCatalogMatcher`; it never reads evidence or produces final classification | collision, root/source, invalid path, exclusion and benchmark tests |

## 3. Code Review Findings and Fixes

| Severity | Finding | Fix | Regression evidence |
| --- | --- | --- | --- |
| P1 | npm, Bundler and Cargo provenance links used paths that did not exist at the pinned commits | Inspect exact commit trees and use existing official paths | 10/10 official source URLs return content in live audit |
| P1 | Matcher initially folded case/diacritics for every rule, which could classify `Target` or `Vendor` on a case-sensitive volume | Accept explicit volume case sensitivity; default fail-conservative to exact case and precompile both forms | exact-case rejection plus `caseSensitive=false` positive |
| P1 | A marker and artifact name were insufficient to prove the directory was generated output | Require artifact-layout signature, not-versioned status and recovery inputs for every rule | positive fixture equals the complete requirement set |
| P1 | Fixture validation only checked subsets, so missing requirements could be absent from both present and missing lists | Require positive exact equality and safety present/missing disjoint union equality | all 40 cases |
| P1 | Xcode rule matched the whole DerivedData root rather than one project child | Match `**/DerivedData/*` and retain per-project candidate granularity | Xcode positive/root/source cases |
| P1 | CLI singleton flags silently accepted duplicates and source sets could omit an explicit cumulative version | Reject duplicate version/overlay/output/manifest flags and require version for multiple catalogs | machine-level missing/duplicate version rejection |
| P1 | Maven provenance pointed to a general README rather than clean lifecycle behavior | Pin Apache Maven Clean Plugin usage at exact commit | live URL/revision/license audit |
| P1 | Static recovery guidance did not prove the required lockfile/manifest inputs still existed | Add `evidence.recovery.inputs-present` to every project rule | exact fixture requirement assertions |

## 4. Catalog Result

### Families

- Node.js: `node_modules`
- Python: `.venv`
- Rust: Cargo `target`
- Go: vendored modules
- Java: Gradle `build` and Maven `target`
- Ruby: Bundler `vendor/bundle`
- PHP: Composer `vendor`
- Flutter: `build`
- Xcode: per-project DerivedData child

All ten rules are `reviewRecommended`, high-confidence requirements and
MoveToTrash metadata only. None is Ready to Reclaim.

### Mandatory evidence

Every project rule requires:

- ecosystem project marker;
- ecosystem artifact-layout signature;
- artifact not version-controlled;
- recovery inputs present;
- Git clean;
- upstream synchronized;
- no active process.

Go/PHP/Ruby/Python carry high risk where vendored or environment content can be
more ambiguous or expensive to restore. Other rules remain medium risk.

### Cumulative source model

- `protected-v1.json` remains byte-identical with source SHA-256
  `8ad3074f568959ea3b6ae65f90dbe389275a61c71cd68b4c84f2cce3b3a72033`.
- `project-artifacts-v1.json` is independently reviewable.
- The cumulative runtime artifact is explicitly versioned
  `builtin-project-artifacts-v1`.
- Source order does not affect catalog, manifest or SHA-256.
- At most 16 sources and 1 MiB aggregate source data are accepted.

## 5. Clean-Room Comparison

The comparison fixture records documented behavior only:

- kondo taxonomy identifies known artifact names; Stornaut still blocks without
  marker, layout, version-control, recovery and activity evidence.
- ClearDisk risk/recovery metadata is useful; Stornaut does not let static
  taxonomy override dirty or active state.
- Mole running-App protection is retained as a typed process prerequisite,
  without copying GPL code, constants or fixtures.
- project roots and source directories never become candidates merely because
  a descendant or sibling has a known name.

No upstream source or fixture is copied. Official docs and repository commits
provide rule provenance; Mole/ClearDisk/kondo remain behavior references.

## 6. Focused Verification

- RuleCompiler/cumulative/matcher tests: 22/22.
- RuleCatalog contract tests: 6/6.
- 10/10 official source URLs passed live exact-revision audit.
- Debug matcher benchmark: about 0.95–1.07 s for 250 iterations over the 40
  Task 16 cases plus anonymous developer-tree paths against 38 cumulative
  rules; 2 s gate.
- protected catalog compiled hash remains
  `6c51931b3d0f7460edff658b6ad4137eba4396128581439c3d664a042d1ebe96`.
- cumulative project catalog compiled hash:
  `b9f631e9cced76e61842ac629af72b00fe20c8ebff41c89ed75908b90c577335`.

Full `scripts/verify` passed:

- 208 SwiftPM tests (3 opt-in diagnostics skipped by design);
- Xcode App contract tests;
- 2/2 XCUITest cases;
- four Light/Dark screenshots and image checks;
- App signing, bundle verification and localization parity;
- deterministic compiler/hash/schema/source-order/CLI/App-leakage gate;
- docs links and diff checks.

## 7. Remaining Boundaries

- Matcher returns candidate rules only. Task 19 activity fusion and Task 20
  orchestration decide whether requirements are satisfied.
- Task 17–18 add cache/runtime/residue sources and rerun cumulative benchmarks.
- Xcode case behavior must use actual volume metadata at orchestration time.
- No project rule can execute a command or infer Ready from time alone.
- ADR 0010 remains Proposed; Deep Dive remains no-go/paused.
