# Phase D Task 39B2c iii-b2b-1a-0 App Server Fixture Prerequisite Review

> Status: Complete; test-only and non-admitting
>
> Date: 2026-08-26
>
> Baseline: `53c5594da964ff3f6d5fdca4f2825a5e629b01c4`

## 1. Outcome

The historical `timeoutInterruptsBlockedInputWrite` fixture now separates fake
App Server readiness from the product timeout assertion. It starts the runner
asynchronously, waits for the existing child readiness record, captures both
PIDs, then awaits the original `.timedOut` outcome and proves both exact
processes disappear. Readiness or PID parsing failure cancels and drains the
runner before fixture teardown.

The runtime implementation, absolute deadline calculation, process-group
cleanup and public behavior are unchanged. The three-second session deadline
and five-second outer bound match the adjacent timeout lifecycle test and do
not reset while readiness is observed.

## 2. Scope

The implementation changes exactly one non-document test path with 24 changed
lines (18 additions, 6 deletions), below the frozen 60-line limit:

- `Tests/StornautCodexTests/CodexAppServerSessionRunnerTests.swift`

No production, package, Xcode, verifier or authority source changed.

## 3. Verification

| Gate | Result |
| --- | --- |
| original exact case | intermittently failed with missing `parent.pid`, demonstrating the fixture-ordering race |
| repaired exact case | 1/1 passed |
| complete App Server runner suite | 12/12 passed |
| serialized `StornautCodexTests` | 259/259 passed in 15 suites |
| sole prerequisite staged serial | 1,520 tests / 79 suites; five issues in two unrelated stale projection-assertion tests; repaired case passed |
| independent review | cleanup P2 fixed with cancel-and-drain; post-fix review found no unresolved P0-P2 |
| coverage | skipped: no configured threshold, non-Flux run and no new production branch |
| diff hygiene | passed |

The serial is intentionally not rerun or relabelled. Its five issues are exact,
understood fallout from renaming and refreshing the separate SwiftPM/Xcode
Machine Driver projections in iii-b2b-1a-0. The immediately following immutable
seal owns those two boundary-test updates and exact-case validation.

## 4. Non-Claims

This prerequisite does not alter product behavior, run a real App/helper/XPC
topology, install anything, request privilege, call a model, use auth/network,
accept ADR 0018, enable Deep Dive or consume the authoritative full verifier.
