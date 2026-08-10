# Epic 2–4 Task 20 Code Review — 2026-08-10

> 状态：All confirmed findings fixed; post-fix review has no open P0–P2
> finding
>
> 范围：product Quick Scan coordinator/state、runtime catalog、deterministic
> classification/activity/accounting、restart/cancel/backpressure 与 zero-model/
> zero-target-write boundary
>
> 方法：tests-first red baseline + real temporary-tree E2E +
> `bits-code-guard` grouped diff review + machine source/dependency/catalog gate

## 1. Review Scope

- `ScanSessionWriter` product-finalization handoff;
- page-preserving `QuickScanProjection` and product event stream;
- 67-rule immutable runtime catalog resource;
- deterministic classifier and conservative evidence/activity fusion;
- classification/evidence/ledger persistence and restart loading;
- single active intent, immediate/post-scan cancellation and backpressure;
- read-only target, fake Codex and App-bundle catalog audits;
- no repository custom review workflow.

The initial automatic report is retained at
`/tmp/stornaut_task20_review_1786316569/report.html`. The post-fix report is
retained at
`/tmp/stornaut_task20_postfix_review_1786318300/report.html` and reports no open
P0–P2 finding. The final grouped review after the unified-verifier host block
is retained at
`/tmp/stornaut_task20_final_review_1786320088/report.html`; it also reports no
open P0–P2 finding.

## 2. Tests-First Findings and Fixes

| Severity | Finding | Fix | Regression evidence |
| --- | --- | --- | --- |
| P1 | Product coordinator/state/runtime catalog APIs did not exist | Add real end-to-end composition and immutable runtime resource | expected red compile, then focused green |
| P1 | Task 12 emitted placeholder tail stages and completed before classification/activity/accounting | Add deferred-finalization writer mode and coordinator-owned terminal | exact five-stage E2E order |
| P1 | Path-only matching could be mistaken for Ready | Closed deterministic classifier keeps unmet evidence/activity as Unknown | path-only candidate test |
| P1 | Restart had no latest page-preserving product projection | Add paged latest-valid loading with corrupt isolation | persisted reopen tests |

## 3. Code Review Findings and Fixes

| Severity | Finding | Fix | Regression evidence |
| --- | --- | --- | --- |
| P1 | Cancellation before writer activation could be lost | Replay cancellation after writer stream creation | immediate-cancel test |
| P1 | Error paths released Coordinator ownership before writer stopped | Wait for writer termination before clearing active state | concurrent/backpressure tests |
| P1 | Cancellation could arrive across classification/ledger commit points | Revalidate around durable commits and persist cancelled terminal | activity-stage cancellation test |
| P1 | Restart mixed unrelated corrupt session IDs into a healthy projection and retained a dependent ledger | Select latest valid session; isolate current-session corrupt rows and invalidate dependent ledger | corrupt-newer-session test |
| P1 | Projection allowed duplicate classification targets | Enforce one classification per target | contract regression |
| P1 | Unknown classification on every unmatched child hid matched parent owner bytes | Classify rule matches plus root/top-level Unknown owners only | cache owner descendant bytes + legacy hard-link suite |
| P1 | Public generic store/activity seams expanded the no-write dependency graph | Keep injection seams internal; expose production `EvidenceStore` initializer | package/source boundary gate |
| P1 | Post-scan persistence/classification/ledger failures only threw the stream | Persist and emit typed partial projection with healthy facts | classification-store failure test |
| P1 | Activity observations used for decisions were discarded | Persist bounded typed `EvidenceRecord` and reload them | E2E reason + restart evidence checks |
| P1 | Internal writer/product backpressure errors raced into different public errors | Normalize to `QuickScanProductError.eventBufferExceeded` | repeated full-suite backpressure checks |
| P1 | Cancellation accepted while final ledger/session persistence was already committing could still leave Completed | Add an atomic product-finalization commit point; pre-commit cancellation persists Cancelled and post-commit cancellation returns false | blocking-store commit-boundary tests + restart |
| P1 | End-baseline and final-session store failures escaped as raw stream errors despite the typed Partial contract | Map both failures to typed product issues; reload only dependency-complete durable ledger state | end-baseline/final-terminal blocking store tests + restart |
| P1 | Live Partial issues disappeared on restart | Persist bounded provider-failure markers as typed evidence and recover activity/persistence/classification/ledger issues from existing durable facts; no schema migration or raw error text | four live/reopen partial-state tests |
| P1 | Legal macOS filenames containing glob metacharacters made rule matching fail the entire scan | Treat only matcher `invalidPattern` for a scanned candidate as no rule match/Unknown; keep all other catalog errors fail-closed | real temporary-tree literal `*?[]\` directory test |
| P1 | Git clean and upstream requirements were collected in separate probes and could combine facts from different repository states | Collect one Git snapshot per snapshot/rule and select every required Git key from that same observation set | single-snapshot spy test |
| P1 | Settings screenshot captured a window while it was obscured, so Dark pixels were mixed with the Light/main window and failed the real image gate | Before capture, require both Settings content and its owning window to be hittable; activate and click the existing content only when needed, without toggling `⌘,` again | 2/2 XCUITest + four-image luminance gate |

## 4. Runtime Catalog and Classification Result

- Core bundles an immutable compiled `RuleCatalog`, not authoring JSON.
- Regeneration from all four versioned catalog sources is byte-identical.
- SHA-256 is
  `133b3829816fa951f03cb87473e03454c3e561b421c83e6c8efaf8ad89849e99`;
  rule count is 67.
- App bundle verification requires the same resource/hash/count.
- Protected vetoes classify Protected without activity.
- Multiple candidates, rule miss or missing prerequisites remain Unknown.
- Only a closed scan-evidence key set is auto-satisfied; recovery, no-user-data,
  detached, not-current, abandoned and unreferenced are never inferred from
  path/size.
- Default process inactivity remains unavailable without a provenance-bearing
  rule-to-process association.

## 5. Lifecycle, Partial State and Restart

- One actor owns one active intent; a second start is rejected.
- Consumer/navigation lifetime does not cancel the scan.
- Explicit cancellation is idempotent and persists Cancelled.
- Product event buffer overflow fails closed with a stable product error.
- Classification/activity/store/ledger failures preserve valid snapshots and
  expose typed partial issues.
- End-baseline failure keeps durable facts without a ledger; final-session
  persistence failure keeps a previously durable ledger only when all snapshot,
  classification and corruption dependencies remain complete.
- Activity evidence persists only bounded structured facts.
- Provider failures persist as bounded unavailable evidence markers, so restart
  restores the same typed activity issue without raw command output.
- Restart pages the latest valid session, snapshots, classifications, activity
  evidence and ledger; corrupt rows invalidate only dependent projections.
- Completed projection requires non-empty facts, unique classification targets,
  a ledger and no typed issue/corrupt record.

## 6. Zero Model and Zero Target Write

- Quick Scan Core has no StornautCodex, Codex process, Probe Bridge, Adapter,
  Policy, Action or cleanup reference.
- The fake executable named `codex` remains unlaunched and its marker absent.
- Surveyor opens directories with
  `O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC`.
- Quick Scan/Surveyor expose no target-write API.
- Legal filenames containing glob metacharacters remain unmatched/Unknown and
  do not turn the whole session into a classification failure.
- The real E2E target is made read-only and its path/type/identity/size/mtime/
  content digest is identical before and after.
- Writes occur only through the injected Stornaut Application Support/Caches
  configuration.

This is behavioral plus source/dependency evidence, not syscall-level proof.

## 7. Focused and Machine Verification

- final Quick Scan/accounting focused checks: 45/45;
- complete Swift suite: 263/263;
- `scripts/verify-activity-boundaries` passes;
- `scripts/verify-quick-scan-boundaries` passes;
- runtime catalog regenerates byte-identically at the reviewed hash;
- source audit finds no prohibited dependency or target mutation surface;
- no new external package, entitlement, background monitor or permission;
- App contract tests pass independently;
- the signed App bundle contains the 67-rule runtime catalog at SHA-256
  `133b3829816fa951f03cb87473e03454c3e561b421c83e6c8efaf8ad89849e99`;
- localization parity, rule compiler fixtures and documentation links pass;
- `git diff --check` passes.

After Automation Mode authentication, the focused UI rerun executes 2/2 test
methods and exports all four screenshots. The corrected frontmost-window
contract measures:

- shell Light/Dark luminance: 248.61 / 31.85;
- Settings Light/Dark luminance: 244.58 / 29.91.

The user approved the macOS `Enable UI Automation` LocalAuthentication prompt.
The final unified `scripts/verify` then passed end to end:

- 263/263 SwiftPM tests;
- activity and Quick Scan source/dependency/catalog gates;
- 2/2 Xcode App contract tests;
- 2/2 XCUITest methods and four exported screenshot attachments;
- screenshot image verification, including Settings Light/Dark luminance
  244.58/29.98;
- App build, local signing and bundle verification with the reviewed 67-rule
  resource;
- localization parity, deterministic rule compiler/catalog/coverage, local
  documentation links and `git diff --check`.

The initial runner block was host authentication, not a product failure and not
an Accessibility/Event Synthesizing requirement. No root writer daemon, TCC/SIP
setting, credential, state file or
`enable-automationmode-without-authentication` policy was modified. Task 20
Step 6 is accepted.

## 8. Remaining Boundaries

- Current product coordinator is single-root; later product scope selection may
  call it per approved root without weakening one-active-intent ownership.
- Process inactivity remains Unknown where producer/process association is not
  provenance-bearing.
- Real packaged-App FDA coverage and 460 GiB product-path benchmark remain Task
  26.
- Task 21 owns App ViewModel composition; SwiftUI still does not call Core
  services directly.
- Deep Dive remains no-go/paused.
