# Epic 2–4 Task 15 Code Review — 2026-08-10

> 状态：All confirmed findings fixed; post-fix review has no open P0–P2
> finding
>
> 范围：protected/veto built-in catalog、rationale/provenance contracts、
> permanent denylist、collision/bypass fixtures 与 deterministic compiler gate
>
> 方法：tests-first contract probes + `bits-code-guard` working-tree scope +
> 7-dimension safety review + component/canonical-path regression tests

## 1. Review Scope

- 20 final Task 15 files, including routing/study/ADR/report updates;
- 28 immutable protected rules and 70 clean-room path cases;
- browser profiles, credential stores, password managers, personal
  communications/photos and representative secret files;
- system/HOME/filesystem-root/volume-root policy independent of the catalog;
- nested, mixed-case, Unicode, symlink and component-lookalike bypasses;
- provenance completeness and catalog-to-fixture pattern linkage;
- overlay downgrade refusal and deterministic compiler artifacts;
- no repository custom review workflow.

The post-fix automatic report is retained at
`/tmp/stornaut_task15_review_1786305259/report.html` and reports no open
P0–P2 finding.

## 2. Tests-First Findings and Fixes

| Severity | Finding | Fix | Regression evidence |
| --- | --- | --- | --- |
| P1 | `rationaleKey` was optional in Core, compiler and schema even though Task 15 requires a rationale for every rule | Make rationale a required `DomainToken` in source and immutable output | missing, null and invalid rationale rejection plus Codable/overlay round-trip |
| P1 | A Protected/veto rule could carry low, medium or high risk despite ADR 0010 requiring critical policy | Require critical risk whenever disposition is Protected | direct Core construction and compiler mutation rejection |

The red tests were recorded before changing production logic. Legal rationale
round-trip and overlay preservation already passed in the red phase.

## 3. Code Review Findings and Fixes

| Severity | Finding | Fix | Regression evidence |
| --- | --- | --- | --- |
| P1 | The first system denylist implementation protected broad `/private`/`/var` prefixes, which also rejected macOS temporary directories under `/private/var/folders` | Use canonical, component-exact system prefixes; protect only explicit roots and `/var` state subtrees | all seven CanonicalPathPolicy tests and normal temporary-root ActionPolicy tests |
| P1 | Catalog tests originally checked only fixture-ID existence; a wrong path pattern could still pass if the independent denylist recognized the fixture path | Link each rule to one positive and one lookalike fixture and verify component glob/directory-prefix behavior | all 28 rules match their positive case and reject their lookalike |
| P1 | Family-level PRD provenance did not independently explain each concrete path pattern | Require two exact MIT sources per rule: PRD policy plus the pre-Task-15 permanent denylist at commit `766d8e7...` | 56-source manifest and exact revision/license/usage assertions |
| P1 | System-location coverage could not be represented safely as relative catalog rules without inventing `/` or HOME sentinels | Keep system/HOME/root/mount authority in Swift policy and test it with the catalog absent | absolute system, HOME, filesystem-root and injected volume-root cases |

## 4. Catalog and Safety Result

### Immutable catalog

- 28 rules compile to catalog version `protected-v1`.
- Every rule is `category=protected`, `disposition=protected`,
  `risk=critical`, `veto=true`, `recommendedAction=none`.
- Every rule carries a required rationale key, two unique fixture IDs and two
  exact HTTPS/MIT provenance sources.
- The source contains no action path, command, executable, arguments, Shell or
  permanent-delete surface.
- Protected patterns are limited to relative component literals and whole
  component `*`/`**`; no false root sentinel exists.

### Independent policy

- `SensitivePathDenylist` canonicalizes and resolves symlinks before checking.
- Browser, credential, Mail, Messages, Photos and secret paths remain denied
  when no catalog is loaded.
- Absolute system roots use component prefixes, not string-prefix matching.
- `/private/var/folders` remains available for normal temporary work while
  `/etc`, `/System`, `/Library`, `/Applications`, `/usr`, `/opt` and selected
  system state subtrees remain denied.
- `CanonicalPathPolicy` independently denies filesystem root, HOME and volume
  roots; catalog rules are not consulted for these decisions.

### Provenance and reuse

- Policy source: Stornaut PRD at exact commit
  `766d8e7d2b533f5393ea5fac81935f416fb0402b`.
- Concrete independent source: Stornaut permanent denylist at the same commit.
- Both are repository-owned MIT material.
- Mole remains behavior-only GPL research. No upstream code, constants or
  fixtures were copied.
- No dependency or ThirdPartyNotices change was required.

## 5. Focused Verification

- RuleCatalog tests: 5/5.
- RuleCompiler/overlay/catalog tests: 15/15.
- CanonicalPathPolicy tests: 7/7.
- ActionPolicyGate tests: 8/8.
- SensitivePathDenylist suites: 5 test declarations covering 46 parameterized
  path cases.
- Production catalog source SHA-256:
  `8ad3074f568959ea3b6ae65f90dbe389275a61c71cd68b4c84f2cce3b3a72033`.
- Compiled protected catalog SHA-256:
  `6c51931b3d0f7460edff658b6ad4137eba4396128581439c3d664a042d1ebe96`.
- Two host compilations produce identical catalog, manifest and hash bytes.

Full `scripts/verify` passed:

- 200 SwiftPM tests (3 opt-in diagnostics skipped by design);
- Xcode App contract tests;
- 2/2 XCUITest cases;
- four Light/Dark screenshots and image checks;
- App signing, bundle verification and localization parity;
- deterministic compiler/hash/schema/target graph/collision/App-leakage gate;
- docs links and diff checks.

## 6. Remaining Boundaries

- Task 15 defines immutable source and policy evidence; runtime classification
  orchestration remains Task 20.
- Tasks 16–18 add reclaim/review rule families and cumulative matching
  benchmarks.
- Task 19 still owns activity providers, conservative fusion and Local
  Knowledge invalidation; ADR 0010 remains Proposed.
- System path rules remain fixed Swift policy and are not user-overridable.
- Deep Dive remains no-go/paused.
