# Epic 2–4 Task 14 Code Review — 2026-08-10

> 状态：All confirmed findings fixed; post-fix review has no open P0–P2
> finding
>
> 范围：rule source schema、strict host compiler、immutable catalog、
> monotonic overlays、dependency/bundle gate 与 compiler CLI
>
> 方法：`bits-code-guard` diff scope + 7-dimension compiler/security manual
> fallback + adversarial parser/overlay tests + deterministic hash gate

## 1. Review Scope

- 23 files in the final Task 14 scope, including routing/ADR/report updates;
- 13 Swift/JSON/script files and 3,016 reviewed changed lines;
- strict JSON grammar and closed schema audit;
- immutable StornautCore rule contracts;
- Ready/Unknown/Protected/action/provenance invariants;
- overlay monotonicity across multiple steps;
- deterministic bytes/hash/manifest;
- host-only package graph and App-bundle exclusion;
- no repository custom workflow.

The post-fix automatic report is retained in the Task 14 `/tmp` review
workspace and reports no open P0–P2 finding.

## 2. Confirmed Findings and Fixes

| Severity | Finding | Fix | Regression evidence |
| --- | --- | --- | --- |
| P1 | Codable/YAML decoding alone would not prove unknown-key/alias/tag rejection and Yams would add CYaml plus supply-chain surface without current authoring need | Use explicit strict JSON authoring (YAML 1.2 subset), defer Yams to a later dependency ADR | dependency graph, Context7/API and package/license evidence |
| P1 | Strict number parser exponent condition lacked parentheses and could evaluate `bytes[index]` after the bounds check failed | Parenthesize exponent alternatives under one bounds guard | malformed exponent input rejects without crash |
| P1 | JSON Schema list bounds were not all enforced by compiler code | Enforce 4,096 rule/overlay, 64 item list, 16 provenance source and scalar/depth/input ceilings | oversized input/list tests |
| P1 | Non-protected rules could match `.ssh`, `.env` and other permanent denylist literals | Intersect component `*`/`**` patterns with permanent sensitive examples; permit only Protected/veto rules | sensitive literal and zero/multi-component `**` tests |
| P1 | Unknown rules could retain MoveToTrash metadata and Ready did not require high confidence | Unknown/Protected action must be none; Ready requires high confidence, evidence, activity, recovery and MoveToTrash | unsafe Ready/Unknown action tests |
| P1 | Overlay behavior around already-Protected rules was implicit and first implementation rejected safe add-only overlays | Explicitly prohibit Protected downgrade while allowing add-only exclusions/evidence; apply sorted overlays step-by-step | protected weakening and add-only extension tests |
| P1 | Multiple overlays for one rule needed deterministic ordering and intermediate monotonicity | Sort by overlay ID and reconstruct/validate after every application | reversed-input multi-overlay test |
| P1 | Fixture IDs could be reused across rules, making coverage/provenance manifest overstate independent evidence | Enforce global fixture ID ownership in `RuleCatalog` | cross-rule fixture collision test |
| P1 | Future independent-verification dates could be accepted | Compare ISO date against injectable/default UTC today | future-date rejection |
| P1 | Host-only intent existed only in comments/package layout | Machine-audit RuleCompilerKit consumers to exactly CLI/tests and inspect Stornaut.app for compiler/YAML leakage | `scripts/verify-rule-compiler` |
| P1 | CLI could overwrite source via direct or symlink-alias destination and did not enforce private output permissions | Canonical collision checks, symlink refusal, owner checks and 0600 output | direct/symlink collision integration checks |
| P2 | Compiler combined strict tokenizer and semantic compiler in one large file | Split `StrictJSONAuditor.swift` from semantic `RuleSourceCompiler.swift` | build/focused verification |

## 3. Compiler and Safety Result

### Source boundary

- Task 14 accepts JSON only; YAML-only syntax fails.
- Input is capped at 1 MiB, depth 16 and scalar 16 KiB.
- Duplicate JSON keys are rejected before `JSONSerialization`.
- Every object has explicit allowed/required keys.
- Unknown versions, enum values, malformed IDs/dates/patterns and oversized
  lists fail closed.

### Rule boundary

- Core catalog has no parser or arbitrary source-loading API.
- Action metadata is only none/MoveToTrash, with no path, command, executable or
  arguments.
- Ready requires high confidence, recovery, evidence, activity and MoveToTrash.
- Protected requires veto and no action.
- Unknown cannot recommend an action.
- Every rule has unique stable ID, at least two unique fixture IDs and HTTPS,
  revision/license/usage/date provenance.
- Non-protected rules cannot intersect permanent sensitive-path examples.
- Runtime denylist remains authoritative and independent.

### Overlay boundary

- Overlays may add exclusions/evidence/activity, raise risk or move disposition
  toward Review/Unknown/Protected.
- They cannot promote Ready, lower risk, reduce requirements/provenance/action
  safety or weaken veto/Protected.
- Multiple overlays remain monotonic and deterministic.

### Host/runtime boundary

- `RuleCompilerKit` consumers are exactly `StornautRuleCompiler` and
  `RuleCompilerTests`.
- StornautCore and StornautCodex have no compiler dependency.
- Stornaut.app bundle contains no compiler/Yams/YAML artifact.
- No third-party dependency, lockfile or notice was added.

## 4. Verification

Focused post-review:

- 35 rule compiler, overlay, domain and permanent denylist tests passed;
- direct compiler/overlay tests: 10/10;
- deterministic output hash:
  `82bf6271f1b1f52be2b1270602dae32984e3aff28fcaf158695f428a70901a59`;
- catalog, manifest and hash bytes match across two host compiler runs;
- direct and symlink source/output collision checks pass;
- JSON schemas and generated artifacts parse successfully.

Full `scripts/verify` passed:

- 190 SwiftPM tests (3 opt-in diagnostics skipped by design);
- Xcode App contract tests;
- 2/2 XCUITest cases;
- four Light/Dark screenshots and image checks;
- App signing, bundle verification and localization parity;
- deterministic compiler/hash/schema/target graph/collision/App-leakage gate;
- docs links and diff checks.

## 5. Remaining Boundaries

- Task 14 ships a minimal fixture catalog, not production rule families.
- Tasks 15–18 add built-in protected/artifact/cache/runtime/residue catalogs.
- Runtime matching and cumulative catalog performance are measured as those
  rules arrive.
- JSON remains the only accepted authoring frontend unless a later Yams ADR is
  approved.
- Task 19 still owns activity providers, conservative fusion and Local
  Knowledge invalidation; ADR 0010 remains Proposed.
- Deep Dive remains no-go/paused.
