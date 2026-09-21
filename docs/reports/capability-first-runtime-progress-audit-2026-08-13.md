# Capability-First Runtime Progress Audit — 2026-08-13

> Status: Superseded completion audit — R2–R6 artifacts and evidence complete;
> the R6 publication is this report's change set
>
> Audited baseline: R5 commit
> `8b93852d901cc7bd78bf827c21dc4d85ab9d473f`
>
> Purpose: prompt-to-artifact coverage audit for the active R2–R6 objective;
> not an R5 or R6 admission report

## 1. Objective and Success Criteria

The active objective is complete only when:

1. R2, R3, R4, R5 and R6 execute in that order.
2. Every phase has:
   - an implementation brief;
   - tests and required full verification;
   - independent review with zero unresolved P0–P2;
   - a phase review report;
   - an independent commit pushed to `origin/main`.
3. R5 has a fresh `signedRuntimeReady` report produced by the installed signed
   App/helper using only synthetic files, endpoints and images.
4. R6 maps every required capability and ADR 0004 residual risk to
   implementation, deterministic tests, signed-App evidence, adversarial
   evidence, limitations and a final supported decision.
5. Deep Dive remains unavailable after the runtime gate because its production
   implementation is outside this objective.
6. The completed state has a clean worktree and `HEAD == origin/main`.
7. Task 29 and production Deep Dive do not start in this objective.

## 2. Phase Artifact Checklist

| Requirement | Concrete evidence | Current result |
| --- | --- | --- |
| R2 brief | `docs/plans/active/task-r2-implementation-brief.md` | Complete |
| R2 closed profile/report | `CodexRuntimeProfile`, `CodexRuntimeCapabilityReport`, detector and tests | Complete |
| R2 evidence dimensions | `advertised`, `configured`, `observed`, `contained` are separate fields | Complete |
| R2 outcome | `docs/reports/capability-first-runtime-r2-review.md` records `configurationReady` | Complete |
| R2 review | Review report records zero unresolved P0–P2 | Complete |
| R2 commit/push | `1af81872b745cc819dda1e5cac1de88e9c954f49`, ancestor of `origin/main` | Complete |
| R3 brief | `docs/plans/active/task-r3-implementation-brief.md` | Complete |
| Runtime Home/env/auth | `CodexRuntimeWorkspace`, `CodexRuntimeEnvironment`, `CodexRuntimeAuthProjection` | Complete |
| R3 containment | Seatbelt/managed proxy, write/private/Unix denial, descendant and lifecycle probes | Complete |
| R3 hard lifecycle gate | Audit-session supervisor, lease recovery and identity-checked drainer | Complete |
| R3 outcome/review | `capability-first-runtime-r3-review.md` records `behaviorReady`, zero unresolved P0–P2 | Complete |
| R3 commit/push | `428656b5a3e38120d33f30a9e769a66ffdc39965`, ancestor of `origin/main` | Complete |
| R4 brief | `docs/plans/active/task-r4-implementation-brief.md` | Complete |
| Versioned protocol | Strict `InvestigationEnvelopeV2`, schema, identity binding and local decoder | Complete |
| No-Executor seam | Module separation, protocol tests and `scripts/verify-codex-no-executor-boundary` | Complete |
| R4 outcome/review | `capability-first-runtime-r4-review.md` records `protocolReady`, zero unresolved P0–P2 | Complete |
| R4 commit/push | `89f3a8532b5594632edb66c8e9ad06a313ad9a5c == origin/main` | Complete |
| R5 brief | `docs/plans/active/task-r5-implementation-brief.md` | Complete |
| R5 tests-first contracts | Capability report, lifecycle identity/session, fixed topology, XPC and verifier tests | Complete locally |
| R5 real worker | Fresh official `openai` + ChatGPT subscription worker observed 9/9 capabilities and 6/6 worker integrity | Complete |
| R5 signed App/helper report | `/tmp/stornaut-r5-machine-report.json`, SHA-256 `08ba7c30373d4736124f0e507fcc9aa972880235251b8bbf636a7b2fabb1d193` | `signedRuntimeReady`, 9/9 capabilities, 12/12 integrity |
| R5 machine verifier | `scripts/verify-codex-runtime-diagnostic` and `scripts/verify-codex-runtime-gate` | Passed |
| R5 installed topology | Fixed App/plist/service plus lease/runtime roots | Installed from current build, measured, then fully uninstalled with zero residue |
| R5 independent final review | Full `bits-code-guard` plus targeted post-fix review | Zero unresolved P0–P2 |
| R5 review report | `docs/reports/capability-first-runtime-r5-review.md` | Complete |
| R5 commit/push | Independent R5 commit `8b93852d901cc7bd78bf827c21dc4d85ab9d473f` on `origin/main` | Complete |
| R6 brief | `docs/plans/active/task-r6-implementation-brief.md` | Complete |
| R6 status contract/UI | Typed localized runtime/product availability status | Complete |
| R6 final matrix/report | `capability-first-runtime-validation-report.md` | Complete; `go` |
| R6 independent review | `capability-first-runtime-r6-review.md` | Complete; zero unresolved P0–P2 |
| R6 commit/push | Independent R6 change set | Completed by publishing this change set |

The stale sentence at the end of the historical R2 review saying that R2 was
“ready” for commit is superseded by repository fact: commit `1af81872` exists
and is an ancestor of `origin/main`. The historical report is not rewritten.

## 3. R5 Command and Gate Coverage

The R5 brief requires:

| Command/gate | Latest evidence | Result |
| --- | --- | --- |
| Focused Codex/runtime tests | Current focused and headless runs | Passed |
| Focused Lifecycle tests | Current focused and headless runs | Passed |
| `swift test --filter StornautCodexTests` | Latest serial run: 235/235 | Passed |
| `swift test --filter StornautLifecycleTests` | Latest serial run: 60/60 | Passed |
| `swift test --no-parallel` | Latest serial stage: 537/537 | Passed |
| `scripts/verify-app-release-boundaries` | Current source, including canonical outcome-shape regression | Passed |
| `scripts/verify --headless` | Current run: source/docs/rules, 534/534 selected SwiftPM tests and App contracts | Passed |
| `scripts/check-doc-links` | Current source | Passed |
| `git diff --check` | Current source | Passed |
| no-Executor boundary | Current source and machine report repository receipt | Passed |
| XcodeBuildMCP Debug build | Current build, no warnings | Passed |
| Real worker on final source | Official `openai` subscription, 9/9 capability and 6/6 worker integrity | Passed |
| Minimal model health | Official subscription returns the expected bounded response | Passed |
| Signed diagnostic | Current-source installed App/helper with synthetic fixtures | Passed |
| Machine report verification | Swift reconstruction, canonical re-encode/compare and shell metadata gate | Passed; `signedRuntimeReady` |
| Post-machine uninstall/residue | Fixed App/plist/service/lease/runtime/process checks | Passed; zero residue |
| Fresh independent post-fix review | `/tmp/stornaut_r5_postfix_review/` | Passed; zero unresolved P0–P2 |

The signed-App rows are now closed independently of offline tests.

## 4. R5 Capability and Integrity Matrix

| Required row | Implementation/test evidence | Required missing evidence |
| --- | --- | --- |
| Direct read | Fixed command identity plus v2 `directFile` evidence | Signed observed |
| Shell | Closed command source/status/marker observer | Signed observed |
| Unified exec | `unifiedExecStartup`/`unifiedExecInteraction` observer | Signed observed |
| Live search | Live/high config plus idempotent canonical/raw handshake | Signed observed |
| Public command network | Managed-proxy marker contract | Signed observed |
| Browser/direct fetch | Public command marker plus typed v2 evidence | Signed observed |
| Image inspection | Completed image event plus fixed synthetic image token/hash | Signed observed |
| Runtime skill | Structured skill selection plus fixed skill token | Signed observed |
| Subagents | Spawn/receiver/child-turn identity plus drain evidence | Signed observed |
| User-data write denial | Mutation matrix and descendant probes | Signed contained |
| Private/local denial | IPv4/IPv6/private/link-local/ULA errno-only probes | Signed contained |
| Unix-socket denial | Owner-only canary and errno-only probe | Signed contained |
| Auth non-persistence | Source snapshot and Runtime Home checks | Signed contained |
| Runtime cleanup | Workspace/session/lease/root cleanup contracts | Signed contained and post-uninstall absent |
| Helper caller authentication | Exact signing and XPC admission contracts | Signed contained |
| Per-investigation lifecycle | SessionCreate/lease/drainer/crash recovery | Signed contained |
| No Executor reachability | Independent repository receipt verifier | Signed report contained |

`advertised`, `configured`, `invoked`, `observed` and `contained` remain
separate. Earlier real-worker success cannot be promoted into final signed-App
containment after later source repairs.

## 5. Guardrail Audit

| Active constraint | Evidence | Result |
| --- | --- | --- |
| No `danger-full-access` | Runtime arguments/config exclude it; tests assert absence | Preserved |
| No arbitrary user-data writes | Runtime write scope is private ephemeral Runtime Home; mutation tests deny targets | Preserved and signed contained |
| No arbitrary local/private/link-local access | Managed-proxy config disables non-loopback proxy and probes deny other targets | Preserved and signed contained |
| No unrelated Unix sockets | Config disables arbitrary Unix sockets; probe requires denial | Preserved and signed contained |
| No public-domain/executable allowlist | No runtime allowlist implementation; public access uses managed proxy | Preserved |
| No per-command approval | App Server requires `approvalPolicy=never`; outer OS containment remains authoritative | Preserved |
| No Luma MCP | No product/runtime source reference | Preserved |
| No production cleanup/Executor path | XPC is closed to start/cancel; v2 advisory protocol and structural verifier exclude Executor | Preserved |
| Synthetic-only model data | R5 fixtures use generated text, PNG, skill and public endpoint | Preserved |

## 6. Provider and Signed Evidence

The product runtime remains explicitly `openai` with ChatGPT subscription auth.
A fresh model health probe and complete synthetic worker passed. The prior
TeamoRouter and `usageLimitExceeded` evidence is historical and superseded; no
custom provider was admitted.

The current-source App replacement, machine diagnostic and final uninstall
were completed through explicit administrator authentication. No password,
auth token, raw JSONL or private fixture content entered the report or Git.

See
[`capability-first-runtime-r5-review.md`](capability-first-runtime-r5-review.md)
and the historical
[`capability-first-runtime-r5-usage-limit-blocker.md`](capability-first-runtime-r5-usage-limit-blocker.md).

## 7. Remaining Checklist

1. publish the independent R6 change set;
2. verify `HEAD == origin/main` and a clean worktree;
3. stop before Task 29.

## 8. Audit Verdict

The implementation and evidence objective is achieved with a supported
runtime foundation `go`.

- R2–R5 are complete and pushed.
- R6 implementation, validation and independent review are complete.
- production Deep Dive remains unavailable.
- Task 29 remains untouched by R6.
