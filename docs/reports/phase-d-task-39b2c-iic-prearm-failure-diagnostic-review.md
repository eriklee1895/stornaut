# Phase D Task 39B2c ii-c Pre-arm Failure Diagnostic Review

> Status: complete / non-privileged / non-admitting
>
> Date: 2026-09-03
>
> Implementation: `2ada395ccf60ec16ab90d845b04c49238825b085`
>
> Accepted tree: `11e1a0a010133bdf63b781d43c128d72ea0aed00`
>
> Next and only frontier: ii-c-c unique real machine campaign

## 1. Result

The pre-arm diagnostic gap is closed without consuming or expanding the unique
privileged campaign. Before the first normal pre-arm frame, the coordinator can
publish one bounded canonical failure frame only after invocation admission and
exact artifact retirement. The frame carries a closed stage, a sanitized reason,
a monotonic verified-checkpoint union and a self-digest. It cannot carry an outer
attempt, capsule, projected input, raw error, path, prompt or credential.

The campaign independently decodes that frame and preserves it only after one
complete frame plus EOF, the exact reason-derived child exit status, closed
channels and zero PGID/SID residue. It never publishes `armedConsumed`, sends ARM
or reads a credential on this path. Production output remains non-admitting and
is emitted only after a verified uninstall receipt and global post-teardown
observation.

The physical fixture drives the real Darwin framing/read/drain/reap path with a
compact failure frame and exit 81. Production and fixture now use the same
complete declared-payload read loop; only fixture truncation may return a partial
legacy frame so the historical `receiptInvalid` regression remains observable.

## 2. Exact Scope

The accepted implementation changes exactly nine non-document paths and 1,834
lines against `51ea8c28b9431280bb0e8b7e6373e2e1ad538298`. The staged-scope gate
binds every path to its expected mode and worktree blob, enforces independent
per-path ceilings and the 2,080-line aggregate ceiling, and rejects extra,
missing, binary, wrong-mode, per-path over-budget, true aggregate-over-budget,
staged/worktree-divergent, untracked and wrong-baseline mutations.

## 3. Validation Evidence

| Evidence | Result |
| --- | --- |
| pre-arm failure source contract | exit 0 |
| exact nine-path staged-scope gate | exit 0 |
| aggregate ii-c-c contract and nine scope mutations | exit 0 |
| focused evidence/harness/coordinator/boundary suites | 161 tests / 4 suites passed |
| final exact repair cases | 3 tests / 3 suites passed |
| ordinary current-tree serialized regression | 1,900 tests / 99 suites passed; 285.549 seconds |
| clean staged-snapshot serialized regression | 1,899 of 1,900 passed; sole failure was `primaryRootBookmarkResolvesExactTemporaryDirectory` because the SwiftPM test host lacked `com.apple.security.files.bookmarks.app-scope` |
| exact failed bookmark case in the normal local test context | 1/1 passed |
| Debug/Release campaign component and final-image boundary | exit 0 |
| final grouped, targeted and cross-group review | no unresolved P0-P2 |

The clean-snapshot run is recorded as non-green rather than promoted by proxy.
Its one failure is outside the changed Investigation paths and is the isolated
SwiftPM host's missing app-scope bookmark entitlement.

## 4. Review Findings and Closure

Review first found that compact fixture frames could be classified as legacy
before domain decoding and that the new staged-scope gate lacked negative
mutation coverage. Post-fix review then found that the aggregate fixture changed
the verifier threshold instead of constructing a real oversized scope, and that
the Swift scope test enumerated only seven paths. All four findings were fixed.
Final targeted reviewers and cross-group review found no unresolved P0-P2.

## 5. Non-Claims and Next Step

This checkpoint ran no root install/uninstall, no privileged driver, no real
Codex/model/network attempt and no authoritative `scripts/verify --full`. The
fixed installed root and service are absent, no new campaign evidence root was
created, and the unique ii-c-c attempt remains unconsumed.

Task 39 remains incomplete, ADR 0018 remains Proposed and production Deep Dive
remains unavailable. The next action is to build the signed diagnostic image
from this immutable source through the clean validation-snapshot path and run
the one ii-c-c machine campaign, followed strictly by `L3c3d -> L3c4`.
