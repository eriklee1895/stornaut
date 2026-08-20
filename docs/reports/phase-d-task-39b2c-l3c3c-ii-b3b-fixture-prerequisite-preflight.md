# Phase D Task 39B2c-L3c3c-ii-b3b Fixture Prerequisite Preflight

> Status: Split frozen; test-infrastructure prerequisite current; non-admitting
>
> Date: 2026-08-20
>
> Baseline: `e60d4e05724314a10792066ad3df8300ff279303`
>
> Scope: documentation and current-source inspection only; no source/test/script
> implementation, App/helper/XPC launch, install, sudo, model/auth use, serial
> regression or authoritative full verifier

## 1. Decision

The ii-b3b implementation is committed and pushed, but its sole staged-only
serial is not clean: 1,244 of 1,245 tests passed. The only issue was
`CodexContainedInteractiveSessionTests.retirementDoesNotWaitForEscapedStandardErrorOwner`,
which threw `.missingPID` while waiting for the test fixture's `escaped.pid`
file before the product retirement assertion ran. The exact case passes on the
pre-b3b baseline and on the ii-b3b tree, and ii-b3b changed none of the Codex
runtime or fixture paths. Those facts exclude an observed ii-b3b regression but
do not turn the consumed result into the clean serial required by the frozen
gate.

Do not rerun or relabel the ii-b3b serial. Insert one narrow, test-only
prerequisite before ii-b3b completion documentation and ii-b3c:

`ii-b3b implementation`
-> `ii-b3b fixture prerequisite`
-> `ii-b3b completion audit`
-> `ii-b3c concrete leaf/native entry`.

## 2. Root Cause and Contract

`session.start()` proves that the contained shell was spawned. It does not prove
that `/usr/bin/python3` has started, forked the escaped standard-error owner and
durably written `escaped.pid`. The fixture currently gives that independent
startup chain the same fixed two-second budget used by the product assertion
that `retire()` must return in less than two seconds. Under the full serialized
suite load, setup can exceed that budget and report `.missingPID` without ever
calling `retire()`.

The prerequisite must separate those contracts:

- fixture readiness gets an explicit, longer but bounded timeout;
- a deterministic delayed-PID fixture proves the old two-second setup budget is
  insufficient;
- a second observation handshake starts the product timer before allowing the
  escaped owner to begin its six-second standard-error hold;
- timeout still throws `.missingPID`; an independently and immediately published
  cleanup PID identifies the still-live exact owner on every exit path; and
- no production source, runtime timeout or containment behavior changes.

## 3. Frozen Scope and Cost

Exactly one non-document path and at most 45 added-or-changed lines. The original
30-line estimate was raised after independent review proved that fixed sleeps
alone could not causally order PID publication, the retirement timer and exact
cleanup without false-green or stale-PID windows:

1. `Tests/StornautCodexTests/CodexContainedInteractiveSessionTests.swift`.

Any production source, a second non-document path, an unbounded wait, removal or
weakening of the two-second retirement assertion, or approach to the line ceiling
forces a new preflight before implementation.

## 4. Tests-First and Validation Funnel

1. RED: after an explicit trigger, make the escaped-standard-error fixture delay
   PID publication beyond two seconds while retaining the existing two-second
   readiness helper; the exact test must fail with `.missingPID` before
   `retire()`.
2. GREEN: give only that readiness call an explicit longer bounded timeout, then
   start the monotonic retirement timer before a second trigger begins a
   six-second standard-error hold. Keep the product retirement bound unchanged.
3. Run the serialized `CodexContainedInteractiveSessionTests` suite.
4. Run the affected serialized `StornautCodexTests` target.
5. Obtain independent review of timeout separation, deterministic failure
   construction, exact cleanup and scope.
6. Consume one prerequisite-owned staged-only serial with the five maximum
   benchmarks skipped. This is not a retry of the ii-b3b serial and must be
   recorded separately.
7. Commit/push the prerequisite, then write the independent ii-b3b completion
   audit recording both the original 1,244/1,245 result and this prerequisite's
   clean serial.

No coverage run is required: this change modifies only test infrastructure and
executes no new production branch. No App/helper launch, real XPC, install,
privilege, model/auth, public network, Trash/Executor, readiness claim or
`scripts/verify --full` is allowed.

## 5. Prompt-to-Artifact Checklist

| Requirement | Direct evidence | Result before implementation |
| --- | --- | --- |
| preserve consumed ii-b3b truth | validation commit `e8d093d...`, tree `069c53c...`, 1,244/1,245 result | frozen |
| deterministic setup-side RED | delayed PID publication fails at `.missingPID` before retirement | pending |
| bounded fixture readiness | explicit per-call startup timeout; no unbounded loop | pending |
| preserve product performance gate | retirement timer begins after PID readiness and remains `< .seconds(2)` | pending |
| exact cleanup | final child immediately records a dedicated cleanup PID and remains alive until killed; fixture root removed | pending |
| test-only scope | one allowed path, no product/source/script changes | pending |
| independent clean evidence | focused, Codex affected, review and prerequisite-owned serial | pending |
| no premature admission | no runtime/report/readiness/full change; ADR 0018 remains Proposed | satisfied by scope |

ii-b3b, ii-b3c, Task 39 and production Deep Dive remain incomplete. L3c4 alone
owns machine readiness and Task 39's remaining authoritative full verifier.
