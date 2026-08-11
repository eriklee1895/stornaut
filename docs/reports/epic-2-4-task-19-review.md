# Epic 2–4 Task 19 Code Review — 2026-08-10

> **Historical-scope notice (2026-08-11):** Deep Dive paused/no-go references
> record the reviewed Phase B scope, not current Codex policy. See capability-first
> [ADR 0004](../adr/0004-codex-file-read-isolation.md).

> 状态：All confirmed findings fixed; post-fix review has no open P0–P2
> finding
>
> 范围：Git/App/process activity、fail-conservative reducer、structured Local
> Knowledge、v1→v2 migration 与 source boundary gate
>
> 方法：tests-first red baseline + native API/local Git evidence +
> `bits-code-guard` grouped diff review + machine source audit

## 1. Review Scope

- three fixed activity requirements used by the built-in catalog;
- typed observation state/source/origin/reason/time and stable fingerprint;
- fixed `/usr/bin/git` requests, parser and bounded process runner;
- AppKit running-App and current-user `libproc` process providers;
- conservative disposition/risk reduction;
- four closed user-confirmed Local Knowledge payloads;
- scope/identity/activity/catalog staleness and v1→v2 store migration;
- no repository custom review workflow.

The initial automatic report is retained at
`/tmp/stornaut_task19_review_1786313561/report.html`. The post-fix report is
retained at
`/tmp/stornaut_task19_postfix_review_1786314308/report.html` and reports no open
P0–P2 finding.

## 2. Tests-First Findings and Fixes

| Severity | Finding | Fix | Regression evidence |
| --- | --- | --- | --- |
| P1 | Activity types/providers/reducer did not exist, so catalog activity requirements could not be satisfied safely | Add closed typed evidence and bounded providers | expected red compile, then focused green |
| P1 | Existing Local Knowledge accepted generic kind/value/provenance and caller-written stale state | Replace with closed payloads, user-confirmed provenance and applicability bindings | inferred/invalid timeline/stale tests |

The initial focused test command failed compilation only on missing Task 19
symbols. No production code was changed inside the mandatory unit-test-only
generation workflow.

## 3. Code Review Findings and Fixes

| Severity | Finding | Fix | Regression evidence |
| --- | --- | --- | --- |
| P1 | All-process `libproc` enumeration silently skipped unreadable names and could claim inactive | Enumerate current-user PIDs, retain coverage status and make incomplete coverage Unknown | local 253/806 unreadable diagnostic; incomplete snapshot test |
| P1 | Invalid observation time reached `try!` in unavailable fallback | Validate Int64-ms dates and substitute a bounded fallback only for error evidence | invalid-time provider test |
| P1 | Damaged v1 Local Knowledge could change `user_version` before failing schema verification | Verify exact v1 schema before migration transaction | damaged v1 remains version 1 |
| P1 | `Classification` required Protected disposition to use the sensitive `protected` category | Keep category→Protected invariant but permit activity-Protected artifact categories | classification and full accounting tests |
| P1 | Same-key satisfied + unavailable observations could be reduced as satisfied | Apply `contradicted > unavailable > satisfied` | same-key conflict test |
| P1 | Collection time and Stornaut-caused timestamps made stable facts stale on every observation | Exclude collection time and Stornaut timestamps from the activity fingerprint | stable fingerprint regression |

## 4. Git Boundary

- executable is exactly `/usr/bin/git`;
- commands are exactly `status --porcelain=v2` and `log -1 --format=%ct`;
- optional locks, hooks, fsmonitor, untracked-cache writes, global/system config,
  prompts and lazy fetch are disabled;
- stdout/stderr are bounded and timeout is two seconds;
- launch/parse/nonzero/truncated/permission errors never become clean;
- last-commit failure does not erase independently valid dirty evidence;
- a real anonymous repository retains the exact path/type/identity/content state
  after collection.

The internal command runner is not public and is not an Adapter or generic
execution surface.

## 5. App, Process and Fusion Result

- App identity comes from `NSWorkspace.runningApplications`.
- Related non-App process names come from bounded current-user `libproc`.
- A running App/process contradicts inactivity and protects the item.
- Incomplete/denied provider data yields Unknown only when that requirement is
  needed.
- Recent external time can protect; stale or Stornaut-origin time cannot
  promote or manufacture user activity.
- Satisfied activity never promotes Review, Protected or Unknown to Ready.
- Activity protection preserves the original artifact category and raises
  lower risk to at least high.

Task 19 does not inspect open files and introduces no `lsof`, `ps`, Shell,
Adapter, background monitor or target write.

## 6. Structured Local Knowledge Result

The only payloads are producer mapping, path include/exclude preference, keep
decision and verified recovery method. Every fact records:

- explicit user-confirmed provenance;
- scope and file identity;
- stable activity fingerprint;
- catalog version;
- observed and updated timestamps.

Scope, identity, activity or catalog drift returns a typed stale reason without
deleting the fact. No free-text Agent memory or direct disposition override is
representable.

The v2 local database validates the v1 schema before migration. Generic legacy
payloads remain stored but isolated as unusable/corrupt records; damaged v1
schemas are not mutated.

## 7. Machine and Focused Verification

- focused post-fix activity/local-knowledge/domain checks: 26/26;
- complete Swift suite: 241/241;
- `scripts/verify-activity-boundaries` passes;
- source audit finds no Shell, `lsof`, `ps`, scanned-target write API or Git
  command beyond `status`/`log`;
- no package dependency, App-bundle component, entitlement or permission added;
- `git diff --check` passes.

## 8. Full Verification

Final post-review `scripts/verify` passed on 2026-08-10:

- 241/241 SwiftPM tests;
- activity source boundary gate;
- 2/2 Xcode App contract tests;
- 2/2 XCUITest cases and four exported Light/Dark screenshots;
- App build, local signing and bundle verification;
- English and Simplified Chinese localization parity;
- deterministic rule compiler, catalog, manifest and coverage gates;
- local Markdown links and `git diff --check`.

## 9. Remaining Boundaries

- Task 20 still owns deterministic Quick Scan orchestration and final
  classification construction.
- Task 19 does not inspect open files or claim syscall-level read-only proof.
- Local Knowledge UI/edit flows are later App Tasks; this Task defines the
  storage and applicability boundary.
- Deep Dive remains no-go/paused.
