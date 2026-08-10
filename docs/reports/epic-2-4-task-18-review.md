# Epic 2–4 Task 18 Code Review — 2026-08-10

> 状态：All confirmed findings fixed; post-fix review has no open P0–P2
> finding
>
> 范围：runtime/image/tool/residue catalog、FR-2 coverage compiler、coverage
> manifest CLI、destructive-lookalike fixtures 与 complete benchmark
>
> 方法：tests-first source/coverage probes + `bits-code-guard` diff scope +
> live provenance audit + atomic CLI failure gate

## 1. Review Scope

- 12 remaining catalog rules and 48 clean-room fixtures;
- five Unknown/no-action runtime/image rules;
- seven Review Recommended cache/update/temp residue rules;
- five FR-2 families, 36 subrequirements and four Swift policy keys;
- 67-rule cumulative matching and four-source deterministic compilation;
- no repository custom review workflow.

The post-fix automatic report is retained at
`/tmp/stornaut_task18_review_1786310907/report.html` and reports no open
P0–P2 finding.

## 2. Tests-First Findings and Fixes

| Severity | Finding | Fix | Regression evidence |
| --- | --- | --- | --- |
| P1 | The remaining runtime/tool/update source did not exist | Add an independent immutable source with conservative Unknown vs Review semantics | source-absence red test, 12 compiled rules |
| P1 | Manifest v2 listed existing rules but could not prove every PRD family was represented | Add a strict host-only FR-2 coverage compiler and coverage manifest | unknown/duplicate/missing rule and family failures |

## 3. Code Review Findings and Fixes

| Severity | Finding | Fix | Regression evidence |
| --- | --- | --- | --- |
| P1 | `.colima/*` and `.lima/*` classified whole instance roots including config/logs | Match exact `diffdisk` files and use regular-file kind | real matcher fixtures |
| P1 | Generic `Library/Application Support/*/update` was too broad | Narrow to independently observed Lark update directory and rename the rule | current/update/user-data cases |
| P1 | Five broad coverage families could pass while a named PRD subfamily was absent | Require 36 fixed subrequirements exactly once | missing requirement rejection |
| P1 | Catalog coverage alone overstated root/HOME/mount/system protection | Add four required Swift policy keys to coverage output | missing policy key rejection |
| P1 | CLI wrote catalog/manifest before coverage validation; invalid coverage left partial success artifacts | Compile and encode coverage before any write; add atomic failure gate | invalid coverage leaves zero destinations |
| P1 | Runtime fixtures used a test-local glob and could miss matcher-kind drift | Use real `RuleCatalogMatcher` with directory/regular-file kinds | all 48 cases |
| P1 | Coverage schema accepted non-integral numeric versions through `NSNumber.intValue` | Require exact integer value | `1.5` rejection |
| P1 | Cursor layout was locally verified, not defined by its general documentation page | Mark source usage `blackBoxVerification` and record exact docs snapshot date | provenance entry audit |

## 4. Runtime and Residue Result

### Unknown, no action

- Docker Desktop VM disk
- Colima and Lima instance disks
- Xcode simulator devices
- AI desktop VM bundles

These remain `unknown`, critical risk, no recovery and `recommendedAction=none`.
Even detached/no-user-data evidence is only an investigation prerequisite until
Tasks 19–20 implement conservative fusion and final classification.

### Review Recommended

- Codex runtime cache
- Cursor, JetBrains and VS Code caches
- Lark update downloads
- Codex abandoned temporary storage
- VS Code ShipIt residue

Each requires current-user/tool ownership, no user data, recovery inputs,
inactive process and a specific not-current/reclaimable/abandoned fact.

No rule executes external cleanup or carries a target command.

## 5. Complete FR-2 Audit

The generated coverage manifest contains:

- all 67 compiled rule IDs exactly once;
- five stable family IDs;
- 36 unique PRD subrequirements;
- four fixed Swift policy keys for filesystem root, HOME, mount roots and
  system locations;
- each rule's disposition, risk, action, rationale, provenance and fixtures.

Unknown, duplicate, missing or fractional-version inputs fail. Coverage failure
produces no partial catalog, manifest or coverage output.

## 6. Provenance and Reuse

- 12/12 first-party sources passed live URL/version audit.
- Git-backed sources pin exact commits; Apple/JetBrains/Cursor use explicit
  product/document snapshot versions.
- Cursor CachedData behavior is black-box/local verification, not falsely
  attributed to generic docs.
- Mole remains GPL behavior-only; no upstream code/constants/fixtures copied.
- No package dependency or App-bundle component was added.

## 7. Focused Verification

- RuleCompiler/runtime/coverage/matcher tests: 32/32.
- RuleCatalog contract tests: 6/6.
- Complete 67-rule benchmark: about 1.25–1.30 s under the 2 s debug gate.
- Prior protected/project/cache hashes remain unchanged.
- Complete catalog SHA-256:
  `133b3829816fa951f03cb87473e03454c3e561b421c83e6c8efaf8ad89849e99`.

## 8. Full Verification

Final post-review `scripts/verify` passed on 2026-08-10:

- 218/218 SwiftPM tests;
- 2/2 Xcode App contract tests;
- 2/2 XCUITest cases and four exported Light/Dark screenshots;
- App build, local signing and bundle verification;
- English and Simplified Chinese localization parity;
- deterministic rule compiler, four-source catalog, manifest and coverage
  gates;
- complete catalog SHA-256
  `133b3829816fa951f03cb87473e03454c3e561b421c83e6c8efaf8ad89849e99`;
- local Markdown links and `git diff --check`.

## 9. Remaining Boundaries

- Catalog matching and coverage do not satisfy activity evidence.
- Task 19 still owns Git/App/process providers and fail-conservative fusion.
- Task 20 still owns final Quick Scan classification orchestration.
- ADR 0010 remains Proposed until Task 19 and the Phase B gate pass.
- Deep Dive remains no-go/paused.
