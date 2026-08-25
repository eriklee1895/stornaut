# Phase D Task 39B2c iii-b2b-1a-0 App Server Fixture Prerequisite Preflight

> Status: scope frozen; test-only repair complete with an honestly retained
> unrelated projection-assertion serial failure
>
> Date: 2026-08-26
>
> Baseline: `53c5594da964ff3f6d5fdca4f2825a5e629b01c4`
>
> Scope: one Swift test-infrastructure path only. No production source, package
> graph, App/helper/XPC launch, install, privilege, model/auth/network use or
> authoritative full verifier.

## 1. Decision

The sole iii-b2b-1a-0 staged-only serial was honestly non-green: 1,520 of
1,521 tests passed in 79 suites. The only issue was the historical
`timeoutInterruptsBlockedInputWrite` fixture reading `parent.pid` after the
one-second session deadline had already expired, before the fake App Server had
necessarily reached its blocked-input state. The production runner returned the
expected `.timedOut` result and performed its bounded process-group cleanup.

The failure is outside the eight-path iii-b2b-1a-0 implementation scope and is
reproducible without changing production source. It is therefore isolated as a
test-only prerequisite rather than folded into or relabelled as a clean
iii-b2b-1a-0 serial.

## 2. Frozen Contract and Scope

Exactly one non-document path and at most 60 changed lines:

1. `Tests/StornautCodexTests/CodexAppServerSessionRunnerTests.swift`

The repair must:

- start the runner asynchronously and wait for the fake server's existing
  `child.pid` readiness record before awaiting the timeout result;
- preserve a single absolute runner deadline and the `.timedOut` expectation;
- use the adjacent timeout test's three-second session / five-second outer
  bound rather than treating a one-second fixture startup race as product
  latency;
- capture both exact PIDs before teardown and still prove both processes exit;
- on any readiness/PID-read failure, cancel and await the runner task before
  fixture removal; and
- change no production code, runtime timeout, process lifecycle or authority.

## 3. Validation Funnel

1. Preserve the original 1,520/1,521 serial result as consumed evidence.
2. Run the exact repaired case.
3. Run the complete serialized `CodexAppServerSessionRunnerTests` suite.
4. Run the affected serialized `StornautCodexTests` target.
5. Obtain independent review of readiness, timeout and cleanup causality.
6. Stage exactly the one test path plus this document and run one
   prerequisite-owned staged-only serialized regression. If an unrelated
   post-iii-b2b-1a-0 verifier assertion fails, retain that result and close it
   only in the following immutable-seal checkpoint; do not rerun this serial.
7. Commit and push the prerequisite independently.

Coverage is skipped because no coverage threshold is configured, this is not a
Flux run, and the change exercises no new production branch. The prerequisite
does not make iii-b2b-1a-0, Task 39, ADR 0018 or production Deep Dive ready.

## 4. Preflight Evidence

- The test and runner source were byte-identical to baseline before the repair.
- Repeated exact execution showed the old case could both fail with a missing
  `parent.pid` and pass, proving an uncontrolled fixture-ordering window.
- The runner uses one absolute dispatch deadline; awaiting readiness outside
  the runner does not reset or extend it.
- The final repair's complete App Server runner suite passed 12/12.
- The complete serialized `StornautCodexTests` target passed 259/259.
- The sole prerequisite serial ran 1,520 tests in 79 suites and retained five
  issues from two stale historical projection assertions in
  `InvestigationMachineTargetBoundaryTests`; the repaired App Server case
  passed in that same run. The following iii-b2b-1a-0 immutable seal owns those
  exact assertion updates.
- Independent review found and closed one cleanup P2 by adding cancel-and-drain
  before rethrow; the post-fix review found no unresolved P0-P2.
