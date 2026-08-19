# Phase D Task 39B2c-L3c3c-ii-b2a Budget Split Preflight

> Status: Mandatory post-focused split frozen before further implementation
>
> Date: 2026-08-19
>
> Baseline: `354ff3b1fce491cbb699a60e5f41f190a3d84985`
>
> Scope: split the already-approved four-path ii-b2a checkpoint without changing
> its domain, safety, validation or non-claim requirements

## 1. Split Trigger

The tests-first state implementation initially reached a green 14-test focused
suite at 1,473 source/test lines. At that trigger point the original 1,800-line
ceiling left only 327 lines for independent-review repairs plus both structural
verifiers, which was not enough for reviewable mutation controls and baseline
seals. The mandatory split was therefore recorded before further coding.

After the required package-access, armed-early cleanup, generation, time-
boundary, binding and deterministic linearization repairs, a-i is currently
1,858 lines and its focused suite passes 19/19. It remains below the superseding
1,900-line a-i ceiling.

The mandatory cost rule therefore applies before more coding. No serial,
affected suite, coverage or completion claim has run.

## 2. Frozen Sub-checkpoints

### ii-b2a-i — Typed state and tests

Exactly two non-document paths, at most 1,900 added-or-changed lines:

1. `Sources/StornautLifecycle/LifecycleMachineRetirementEscrowDeadlineState.swift`;
2. `Tests/StornautLifecycleTests/LifecycleMachineRetirementEscrowDeadlineStateTests.swift`.

It owns the complete deterministic state/deadline API, tests-first RED, focused
suite, complete Lifecycle affected suite, focused coverage and independent
source/test review. It may be committed and pushed only after review is green,
but is an interim non-admitting artifact: it does not complete ii-b2a and does
not run a staged serial.

### ii-b2a-ii — Structural admission and final regression

Exactly two non-document paths, at most 700 added-or-changed lines:

1. `scripts/verify-investigation-boundaries`;
2. `scripts/verify-contract`.

It owns the exact baseline/path/blob seals, source ownership/authority checks,
package-access and no-product-reference checks, executable positive/negative
mutation controls and the sole clean staged-only serial for the combined ii-b2a
tree. The serial protocol is exact:

```text
pushed a-i commit is HEAD
-> index contains exactly the two a-ii verifier paths
-> no unstaged non-document drift
-> create one staged validation snapshot whose parent is exact pushed a-i HEAD
-> record snapshot commit and tree
-> prove snapshot tree equals HEAD plus index
-> run the sole staged-only serial in that snapshot
-> bind completion report and final commit to the same combined tree
```

Final independent review and the ii-b2a completion audit occur only after that
serial passes. No second serial is permitted.

## 3. Preserved Requirements

This budget split supersedes only the parent ii-b2a checkpoint's 1,800-line
aggregate ceiling. The new ceilings are a-i at most 1,900, a-ii at most 700 and
the four-path union at most 2,600 added-or-changed lines.

The split does not change any transition, timer, wall/monotonic, replay, adapter
ownership, product-graph or non-claim requirement in the parent ii-b2a preflight.
The union remains exactly the original four non-document paths. Neither
sub-checkpoint may modify current escrow/XPC/helper/Machine/App/Package/Xcode
paths, launch a helper/App, install, use sudo, call a model/auth, accept ADR 0018,
claim readiness or run authoritative headless/full verification.

ii-b2a remains incomplete until ii-b2a-ii closes the combined prompt-to-artifact
checklist. ii-b2b remains the later server-side adapter/live migration gate.
