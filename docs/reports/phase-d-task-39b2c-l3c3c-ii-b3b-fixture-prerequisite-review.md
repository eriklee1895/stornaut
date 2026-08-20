# Phase D Task 39B2c-L3c3c-ii-b3b Fixture Prerequisite Review

> Status: Complete; deterministic PID-publication/retirement/cleanup causality,
> focused and Codex regressions, one prerequisite-owned staged-only serial and
> independent post-fix review passed; test-only and non-admitting
>
> Date: 2026-08-20
>
> Implementation commit: `18e75f4256ef0dbc890f9a9acd70db3236e77fe4`
>
> Validated tree: `bc0749fbd470a00d27eade336d30796ddf73a7d4`
>
> Staged validation commit: `09925067febe476a0dfb753bf18a226667a58b2e`
>
> Scope: one Swift test-infrastructure file only; no production source, runtime
> timeout, App/helper/XPC launch, install, privilege, model/auth, readiness or
> authoritative full verifier

## 1. Outcome

The ii-b3b fixture prerequisite is complete. The escaped-standard-error test no
longer conflates process startup, PID-file publication and product retirement
latency. A double-forked final owner immediately records a dedicated cleanup PID,
waits for an explicit publication trigger, delays assertion-PID publication past
the historical two-second fixture window, and then waits for a separate hold
trigger. The test records its monotonic retirement start before releasing that
second trigger. The owner retains standard error for six seconds, closes only fd
2 and remains alive for another 24 seconds so every exit path can kill the exact
still-live cleanup PID.

The final five-second readiness bound is test infrastructure only. The product
assertion remains strictly `duration < .seconds(2)`. An implementation that waits
for escaped standard-error EOF therefore still takes at least six seconds after
the measured start and fails the unchanged product gate.

## 2. Scope, Cost and Identity

The implementation changed exactly one frozen non-document path and 41
added-or-deleted lines (30 additions, 11 deletions), below the independently
reviewed 45-line ceiling:

- `Tests/StornautCodexTests/CodexContainedInteractiveSessionTests.swift`.

No product source, package graph, Xcode graph, verifier, runtime timeout or public
surface changed. The implementation and staged validation commits share parent
`110c447b4ad1fc49a2730d6d4ae4008191ce9606` and exact tree
`bc0749fbd470a00d27eade336d30796ddf73a7d4`. The implementation is pushed to
`origin/main`.

## 3. Prompt-to-Artifact Completion Checklist

| Requirement | Direct evidence | Result |
| --- | --- | --- |
| preserve consumed ii-b3b truth | original validation `e8d093d...` remains 1,244/1,245; no ii-b3b serial retry | satisfied |
| deterministic setup-side RED | publication trigger starts the 2.25-second delay after the two-second monotonic deadline is established; exact test throws `.missingPID` before retirement | satisfied |
| bounded GREEN readiness | the escaped PID call alone uses a five-second `ContinuousClock` bound; all other PID waits keep their two-second default | satisfied |
| preserve product performance gate | measured start precedes the hold trigger and the assertion remains `< .seconds(2)` | satisfied |
| expose wait-for-stderr regressions | final owner holds fd 2 for six measured seconds | satisfied |
| exact cleanup on every path | final child immediately records `escaped-cleanup.pid`, closes fd 2 only after the hold, then remains alive 24 seconds for defer cleanup | satisfied |
| test-only scope and cost | exact one path / 41 lines, no production or verifier drift | satisfied |
| independent clean evidence | focused, full contained suite, complete Codex target, clean prerequisite serial and final reviews | satisfied |
| no premature admission | no runtime/report/readiness/full change; ADR 0018 remains Proposed | satisfied |

## 4. Validation Evidence

| Gate | Result |
| --- | --- |
| final deterministic RED | exact test failed with `.missingPID` after 2.035 seconds before `retire()` |
| final exact GREEN | 1/1 passed after 3.908 seconds |
| final contained-session suite | 15/15 passed in 9.211 seconds |
| final complete `StornautCodexTests` | 259 tests in 15 suites passed in 47.513 seconds; only existing explicit opt-in diagnostics skipped |
| sole prerequisite staged-only serial | 1,245 tests in 59 suites passed in 84.541 seconds; five maximum benchmarks skipped |
| serial identity | validation `0992506...`, implementation `18e75f4...`, identical tree `bc0749f...` |
| independent review | initial fixed-sleep P1 and cleanup/stale-PID P2 repaired; final review found no unresolved P0-P2 |
| code-guard review | seven dimensions, no P0-P2; HTML/Markdown report generated outside the repository |
| diff hygiene | exact one path / 41 lines, `git diff --check` passed, no post-serial drift |

No App/helper, XPC service, installer, `sudo`, `launchctl`, model, auth, public
network, Trash/Executor or authoritative full verifier ran.

## 5. Review Findings and Repairs

Independent review rejected the first fixed-sleep design because its delay, test
deadline and escaped-child lifetime had unrelated origins. Under adverse
scheduling it could produce either a false RED or a false GREEN. A first
double-fork repair fixed publication causality but still allowed cleanup to read
a delayed or stale PID. The final design closes both windows with three separate
facts: an immediately published cleanup PID, a publication trigger controlling
the readiness witness, and a hold trigger released only after the monotonic
product timer starts. The final owner remains live after closing stderr, so defer
never intentionally signals a naturally exited PID.

Final independent review reports no unresolved P0-P2.

## 6. Non-Admission and Next Gate

This prerequisite repairs test infrastructure only. It adds no product behavior
and makes no runtime, installed-artifact or readiness claim. Together with the
original ii-b3b implementation and its exact non-green accounting, it closes the
clean-serial evidence gap without relabeling or retrying the consumed ii-b3b
serial.

ADR 0018 remains Proposed. Task 39 and production Deep Dive remain incomplete;
L3c4 still owns machine readiness and Task 39's remaining authoritative full.
The strict next checkpoint is L3c3c-ii-b3c concrete leaf/native entry.
