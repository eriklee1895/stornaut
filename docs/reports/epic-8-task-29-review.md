# Epic 8 Task 29 Code Review and Completion Audit

> Status: Passed; implementation, completion audit, independent review and
> final unified verifier complete
>
> Date: 2026-08-14
>
> Baseline:
> `3d5c32fe8f8edad2aa118b64cd27ae5ec26228df`
>
> Scope: deterministic execution profiles, Rule Catalog v2 promotion,
> one-snapshot Activity, execution Evidence, complete Store joins,
> Cleanup Plan Builder and non-authoritative Review projection

## 1. Objective and Success Criteria

Task 29 had to deliver a deterministic proposal layer:

```text
new current Quick Scan
+ closed Rule Catalog v2
+ separate closed Execution Profile Catalog v1
+ one bounded running-activity snapshot
+ exact filesystem identity
→ immutable classification/evidence truth
→ complete persisted join
→ bounded non-authoritative Review projection
→ immutable Cleanup Plan proposal
```

Completion requires all of the following:

1. only npm and pip become Ready after complete closed evidence;
2. Go build stays Review; uv stays read-only Review with no execution profile;
3. execution profiles remain separate from generic Rules;
4. Quick Scan and Review share one deterministic evidence contract;
5. each scan/refresh enumerates running processes once;
6. Plan building validates complete retained Store truth rather than the
   bounded Quick Scan projection;
7. Plan identity, root, Catalog/Profile generations and fingerprints are
   complete and deterministic;
8. Review exposes suggestions and groups without selection, Policy or
   authority;
9. no target write, App CTA, Trash call, Registered Action, Codex, Probe,
   Adapter, Store v4 or third-party dependency is introduced;
10. tests-first, benchmark, independent review, focused/full verification and
    one independent commit/push are complete.

## 2. Prompt-to-Artifact Checklist

| Requirement | Artifact/evidence | Result |
| --- | --- | --- |
| Separate closed execution catalog | `ExecutionProfileCatalog.swift`, `safe-execution-profiles-v1.json`, strict source schema | Passed |
| Generic Rule schema remains classification-only | no Profile fields in `CompiledRule` or `rule-catalog-source.schema.json`; Review boundary gate | Passed |
| Rule content gets a new generation | closed `package-build-caches-v2.json` promotion; runtime `builtin-runtime-tool-residue-v2` | Passed |
| Only npm/pip Ready | generated Rule resource and compiler gate assert exact Ready set | Passed |
| Go Review, uv no profile | Profile resource contains Go/npm/pip only; Quick Scan product tests assert uv Review | Passed |
| Exact approved paths | compiler/runtime loaders cross-check Rule/Profile path and directory kind | Passed |
| Closed resolver map | exactly three compiler-attested keys, one current-filesystem key and one current-activity key | Passed |
| Closed process families | exact npm/Go names; bounded ASCII case-folded Python/pip version grammar; no regex/substring | Passed |
| One snapshot per scan/refresh | capture/evaluate split plus call-count tests in Quick Scan, resolver and Plan Builder | Passed |
| Active beats incomplete coverage | active exact match remains contradicted/Protected; unmatched incomplete snapshot is unavailable/Unknown | Passed |
| Current Evidence truth | exact kind/source/summary/freshness/time-window validation and stable privacy-safe fingerprints | Passed |
| Complete persisted join | cursor pages for all retained snapshots and joined classifications; full Evidence paging/count checks | Passed |
| Corruption fails closed | first/middle/final joined-page corruption returns `scanAgain.corrupt-truth` | Passed |
| Old catalog is immutable | old-catalog scan returns Scan Again; retained classifications remain unchanged | Passed |
| Root binding | full baseline/root `FileIdentity` equality; sampler now preserves `linkCount` | Passed |
| Plan is non-authoritative | current Cleanup Plan v2 only; no Policy, selection, confirmation or authorization | Passed |
| Deterministic Plan | stable order and canonical fingerprint over full root/item identity, bytes, evidence and activity | Passed |
| Random IDs do not change fingerprint | dedicated two-builder regression | Passed |
| Empty Review is not empty Plan | typed `.empty` projection and zero persisted Plans | Passed |
| Review groups/counts | five closed groups: executable Ready/Review, no-profile, persisted-blocked, current-blocked | Passed |
| Bounded projection | maximum 100 rows while all three late-page profiles remain visible | Passed |
| Store remains v3 | no migration/table/column/index change; Review boundary gate pins Store schema 3 | Passed |
| Compiler outputs are atomic | invalid coverage/profile leaves zero Rule/Profile/manifest/coverage destinations | Passed |
| Runtime resources only | Core packages compiled Rule/Profile JSON; host compiler stays host/test-only | Passed |
| No write/authority surface | `verify-review-boundaries`, Quick Scan boundary and no-Executor gate | Passed |
| No external dependency | package graph and `swift package show-dependencies` | Passed |
| UI not implemented | no Review SwiftUI/App dependency or production CTA | Passed |
| Real Trash remains closed | no Trash/coordinator wiring; Task 35 opt-in remains required | Passed |

## 3. Tests-First Evidence

The first Task 29 focused command intentionally failed because the Profile
compiler/runtime types did not yet exist:

```text
swift test --no-parallel --filter 'ExecutionProfile'
EXIT_STATUS=1
cannot find type 'CompiledExecutionProfileArtifact' in scope
cannot find 'ExecutionProfileCompiler' in scope
```

Log:

```text
/tmp/stornaut-task29-red-tests.log
SHA-256 689736345bfb4295ebaa125c72548c0bb584130c89ef4e392bb249d303d0e9f2
```

Final Task 29 focused coverage includes:

- compiler/profile deterministic and rejection cases;
- runtime loader cross-validation;
- exact/versioned process-family matching;
- one-snapshot capture/evaluate;
- Quick Scan npm/pip/Go/uv truth and incomplete coverage;
- current Review identity/activity downgrade;
- complete Store joins and corruption;
- empty/old-catalog states;
- complete projection counts;
- deterministic fingerprints.

The final post-review focused set passed. The final Plan Builder subset
contains eight test functions, including a three-case first/middle/final
corruption test.

## 4. Catalog and Compiler Evidence

Runtime Rule Catalog:

```text
catalogVersion: builtin-runtime-tool-residue-v2
ruleCount: 67
Ready: cache-npm-content, cache-pip
SHA-256 d94ef23f9dc0d772499a192e9205d09aafa9618a1adbe7ec41c6aacc927a913a
```

Runtime Execution Profile Catalog:

```text
catalogVersion: safe-execution-v1
ruleCatalogVersion: builtin-runtime-tool-residue-v2
profiles:
  phase-c.go-build-cache-v1
  phase-c.npm-cacache-v1
  phase-c.pip-cache-v1
SHA-256 f43aa94da659fb6b5c64f5e2822e21141cd882390f96cb5f69452f2de5b467f2
```

The implementation keeps `package-build-caches-v1.json` immutable and applies
the exact two-rule `package-build-caches-v2` promotion through the host
compiler. The v1 FR-2 family map is reusable only when the target is the exact
approved v2 Catalog with the exact two Ready rules. Runtime loaders repeat
the Profile allowlist, resolver, process subject, fixture and Rule
cross-validation instead of trusting generated JSON by filename.

## 5. Performance and Boundedness

Anonymous fixture:

```text
4,096 non-profile rows + 3 execution-profile rows = 4,099 joined rows
Store page size = 100
Review projection maximum = 100
Plan items = 3
running-activity captures = 1
```

Three isolated Debug repetitions:

```text
0.732 s
0.653 s
0.673 s
median 0.673 s
```

The test ceiling remains a conservative `5 s`. It also proves that profiles
on the final joined page cannot be starved by the first 100 non-profile rows.
The builder retains only the three profile candidates plus the bounded
projection while still visiting and validating every physical row.

## 6. Confirmed Review Findings and Corrections

### 6.1 Volume baseline omitted directory link count

**Severity before fix:** P1 root identity correctness

**Disposition:** Fixed

`FoundationVolumeBaselineSampler` constructed `FileIdentity` without
`st_nlink`, while `FileIdentity.read` included it. An unchanged root could be
reported as drifted. The sampler now preserves link count and a regression
requires complete identity equality.

### 6.2 uv read-only Review could degrade to Unknown

**Severity before fix:** P1 approved classification semantics

**Disposition:** Fixed

uv intentionally has no execution profile, but still needs closed static
classification facts and exact `uv` process activity. Quick Scan now evaluates
uv against the same captured process context without creating an execution
profile or Plan eligibility.

### 6.3 Persisted execution Evidence state was under-validated

**Severity before fix:** P1 Plan admission integrity

**Disposition:** Fixed

The first builder draft checked Evidence identifiers and freshness but not the
exact satisfied summary, kind, source or time. It now requires the complete
five-row closed map with exact resolver provenance, satisfied state and a
valid scan-to-plan time window.

### 6.4 Profile rows could be starved by projection truncation

**Severity before fix:** P1 Review truth completeness

**Disposition:** Fixed

The first 100 non-profile rows could fill the projection before late-page
profiles. The builder now always reserves all profile rows, then fills
remaining capacity with stable non-profile rows.

### 6.5 Process matching was case-sensitive

**Severity before fix:** P2 activity false-negative risk

**Disposition:** Fixed

Bounded ASCII names are case-folded before exact or closed versioned-family
matching. Unicode digits, suffixes, substrings and overlong versions remain
rejected.

### 6.6 Candidate and fingerprint bindings were incomplete

**Severity before fix:** P1 Plan integrity / P2 robustness

**Disposition:** Fixed

- one profile Rule/path may appear only once per session;
- random Plan/item IDs no longer affect the canonical fingerprint;
- complete root and item `FileIdentity`, byte measures, Profile/Catalog,
  Evidence and process subject mapping are fingerprinted;
- Review refresh never promotes retained Protected/Unknown truth.

### 6.7 Review corruption and grouping evidence was incomplete

**Severity before fix:** P2 verification completeness

**Disposition:** Fixed

The completion audit added:

- explicit five-group counts over all rows;
- checked arithmetic;
- first/middle/final joined-page corruption tests;
- invalid Profile CLI five-destination atomic failure;
- exact Surveyor provenance for current-filesystem Evidence.

## 7. Independent Review Result

`bits-code-guard` detected 20 tracked files. Its working-tree mode omitted 17
new untracked files, so the required fallback manually reviewed all 37 changed
files across four groups:

1. Profile authoring/compiler/runtime Catalog;
2. Activity/Quick Scan Evidence;
3. Store/Plan Builder/Projection;
4. packaging/App pins/verifier.

Final unresolved findings:

```text
P0: 0
P1: 0
P2: 0
```

Local report:

```text
/tmp/stornaut_task29_review_1786635801/report.html
/tmp/stornaut_task29_review_1786635801/report.md
```

## 8. Verification Evidence

Post-review focused tests:

```text
22/22 passed before completion-audit additions
```

Final serial SwiftPM:

```text
560/560 passed
opt-in model/Trash/machine diagnostics skipped by contract
/tmp/stornaut-task29-final-serial-swift-test-v2.log
SHA-256 77bc5ede985ea7a4bfa218d4da08a41364eac2fb709766a03b628756b4cc683c
```

Static gates passed:

```text
verify-rule-compiler
verify-activity-boundaries
verify-quick-scan-boundaries
verify-review-boundaries
verify-codex-no-executor-boundary
check-doc-links
git diff --check
```

Final uninterrupted `scripts/verify`:

```text
exit 0
/tmp/stornaut-task29-delivery-unified-verify.log
SHA-256 d6756b677f00f115a9e72d817969b57e66bd8cf8af939bb250988e8beb54eb21
```

It covered:

- XCUITest and all 17 canonical screenshot contracts;
- SwiftPM build and `557/557` selected parallel tests plus three matcher
  benchmarks (`0.265 s`, `0.378 s`, `0.537 s`);
- Phase B product/cancellation evidence;
- Activity, Quick Scan, Review, Codex no-Executor and App/UI source boundaries;
- App contract tests, Debug build/signing and real bundle resource hashes;
- Release fixture isolation and bilingual localization;
- deterministic Rule/Profile compilation and atomic failure checks;
- verifier contract, documentation links and diff hygiene.

## 9. Non-Goals Preserved

Task 29 adds no:

- selection generation;
- Cleanup Policy decision;
- stale-sheet interaction;
- confirmation or authorization;
- execution coordinator, journal transition or Manifest finalization;
- Action Executor or Trash invocation;
- Review/Cleanup Result/History SwiftUI;
- App CTA;
- Registered Action;
- Codex/Probe/Adapter/Deep Dive product flow;
- Store v4;
- permanent deletion, restore, Trash emptying or background behavior;
- release/notarization work;
- third-party dependency.

Task 30 remains the next deterministic task. Task 35's real signed-App
disposable Trash diagnostic still requires separate explicit user opt-in.

## 10. Delivery Identity

Task 29 is delivered by the single Git commit containing this report. Push
completion is proven by `HEAD == origin/main` after that commit; the exact hash
is recorded in Git history rather than embedded here, avoiding a recursive
self-hash.
