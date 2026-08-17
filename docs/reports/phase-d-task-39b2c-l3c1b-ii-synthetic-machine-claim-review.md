# Phase D Task 39B2c-L3c1b-ii Synthetic Machine Claim Review

> Status: Complete; non-admitting synthetic Machine-claim prerequisite
>
> Date: 2026-08-18
>
> Baseline: `58aed9516c735374099c952d15cdf1fab8011ba5`
>
> Scope: root-only injected synthetic claimant, package-closed non-`Codable`
> one-shot claim store and exact claim-to-L1/L2 collector join; no production
> claim XPC selector/client, live install/uninstall, model, report, readiness or
> full verifier

## 1. Decision

L3c1b-ii is complete, and together with L3c1b-i closes the L3c1 opaque
retirement bridge. The non-product `StornautInvestigationMachine` target now
contains an injected synthetic claimant that requires root authority before it
touches the claim source and binds every claim to:

- the exact Investigation and complete signed-runtime configuration SHA-256;
- a fresh challenge and a window no longer than fifteen seconds, clamped to the
  helper-minted handle deadline;
- the exact App process identity, UID and complete audit token;
- the exact root helper process identity, complete audit token and signing
  verification; and
- the helper-recorded owner-retirement truth plus same-retire L1 zero-residue
  observation.

The resulting `InvestigationMachineRetirementClaim` is module-internal,
non-`Codable` and carries a shared lock-protected reservation. Copying the value
does not duplicate authority: only one claim Store can record it, and every
empty, duplicate, consumed or invalidated path becomes terminal.

The lifecycle topology collector now derives its Investigation, scenario,
binding and complete configuration digest from one validated diagnostic
configuration. It consumes the one-shot claim before reading installed L2
topology or invoking a transition, rejects any claim/configuration/App/helper/
time mismatch, and joins owner retirement, L1 zero, installed L2 and
post-teardown L2 into one bounded synthetic cohort. Root authority,
cancellation and deadline are still revalidated immediately before the
transition.

## 2. Tests First and Review Fix

The mandatory Swift unit-test workflow covered the claimant, Store, collector
and target boundary before final acceptance. Existing tests already exercised
root admission, fresh challenge/window clamping, response and identity drift,
stale helper attestation, cross-Store replay, terminal Store states,
configuration splice, claim-before-L2 ordering, root/deadline revalidation,
transition failure, cancellation and concurrent collection.

The tests-first defect analysis found one P2 error-classification gap: when a
claim task was cancelled while the source was suspended, a source that resumed
with an ordinary transport error was mapped to `.sourceFailed` before task
cancellation was rechecked. The new barrier-based test first failed with that
exact result. The claimant now performs `Task.checkCancellation()` in the
ordinary source-error path before mapping a genuine non-cancellation failure.
The test then passed, preserving cancellation as the authoritative terminal
cause without weakening one-shot consumption.

Two independent grouped reviews plus a cross-group contract review inspected
all seven changed paths across logic, business semantics, security,
concurrency, robustness, performance and test reliability. Final result: no
unresolved P0-P2 findings.

## 3. Validation

| Gate | Result |
| --- | --- |
| cancellation defect probe before fix | 1 expected failure; `.sourceFailed` observed |
| claimant post-fix suite | 9/9 passed |
| claim/collector/target focused | 20 tests in 3 suites passed |
| exact Investigation structural boundary | passed |
| clean staged Lifecycle suite | 139 tests in 15 suites passed |
| clean staged Investigation suite | 178 tests in 17 suites passed |
| targeted Debug diagnostic App build | passed in 11.2 seconds |
| local Markdown links and staged diff hygiene | passed |
| clean staged-only serial regression | 1035 tests in 48 suites passed |
| serial test / wall time | 111.631 / 150.02 seconds |
| independent grouped and cross-group review | no unresolved P0-P2 |

The accepted serial ran from exact staged snapshot
`58376b163ba1cdb5507d90a4e59f72c573505af9` in a clean physical
`/Users/.../stornaut-validation.*/worktree`. The snapshot tree and the accepted
implementation index tree were independently compared and both equal
`0a4bfc22f2e1e3bae253e7536a327ab82a5a11e3`; the run is therefore bound to
the final post-fix implementation.

The checkpoint changes exactly seven non-document source/test/script paths
with 1,452 additions and 153 deletions, within the frozen seven-path and
1,900-added-line limits. The independent review artifacts are available at:

- `/tmp/stornaut_l3c1bii_review.hnFqT3/final_comments.json`;
- `/tmp/stornaut_l3c1bii_review.hnFqT3/report.html`; and
- `/tmp/stornaut_l3c1bii_review.hnFqT3/report.md`.

Artifact SHA-256 values are:

| Artifact | SHA-256 |
| --- | --- |
| final findings | `37517e5f3dc66819f61f5a7bb8ace1921282415f10551d2defa5c3eb0985b570` |
| HTML report | `23c9b43601edc562e55d3775cb984d6a7620bfddb6f96bf5477e67819d45fc87` |
| Markdown report | `4e39780aa76194f0a27d7860d7020585544dd397723da874dd870c3a0988a3ff` |

## 4. Safety Boundary

This checkpoint exposes only an injected synthetic claim source. It does not
add an Objective-C/XPC selector, listener role, concrete client/sender, signed
root-driver authorization or production claim route. It also adds no JSON or
property-list authority reconstruction, filesystem mailbox, persistent escrow,
process launch, fixed-topology mutation, model call, Machine report,
Cleanup/Trash/Executor/Registered Action authority or readiness promotion.

`~/.codex/config.toml` was not modified. Production Deep Dive remains
unavailable. `scripts/verify --full` was not run; L3c4 still exclusively owns
Task 39's remaining authoritative full verifier and readiness claim.

## 5. Next Gate

L3c2 must first freeze a new scope/trust/cost preflight for the non-product
closed deterministic Machine driver and eight-scenario state machine. It alone
may add the exact signed root-driver identity, fixed endpoint and
authorization-before-consume production claim route. L3c2 remains synthetic
and pending-only: it must not call a real model, perform final live admission,
produce a Ready receipt or consume the L3c4 full verifier.
