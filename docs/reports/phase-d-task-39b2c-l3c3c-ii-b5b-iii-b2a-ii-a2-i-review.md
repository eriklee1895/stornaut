# Phase D Task 39B2c L3c3c-ii-b5b-iii-b2a-ii-a2-i Review

> Status: complete / non-admitting; a2-i closed
>
> Date: 2026-08-25
>
> Baseline: `8362b47351a7d3b3a141fc78ec03f9575199901d`
>
> Implementation commit: `158f500b558d6c1b6fae4a15fc1f8b7d9298f60d`
>
> Implementation tree: `c7a42ffd4ac4d695f53b86256e033caca13f4ff9`
>
> Next frontier: a2-ii terminal evidence and sole admission join

## 1. Result

a2-i is complete. The existing Darwin epoch session now has a closed topology
policy that preserves the legacy App-owned process-group mode while adding the
approved inherited-inner-PGID mode without copying the STNP/STNH state machine.
The App remains a direct child of the inner driver, inherits the inner process
group, and cannot make the inner signal its own group.

The accepted implementation changes exactly ten non-document paths and 1,965
non-document lines against baseline `8362b47`, plus the a2 scope/trust
preflight amendment. The original eight-path estimate was explicitly amended
after review showed that correct normal-exit handling required the existing
retirement source and its focused test. The 3,200-line ceiling, ownership model,
package graph and product availability boundary did not change.

## 2. Closed Contract

- The legacy mode still sets `POSIX_SPAWN_SETPGROUP` and admits only
  `App.PGID == App.PID` outside the caller's process group.
- The inherited mode uses only `POSIX_SPAWN_CLOEXEC_DEFAULT`, requires the
  inner to be its own process-group leader, and observes exact
  `App.PPID == inner PID` plus `App.PGID == inner PGID` before and after the
  credential drop.
- The pre-drop identity record retains the exact parent/group topology and the
  post-drop observation reuses those immutable expectations.
- Startup or protocol failure for an inherited App closes the owned descriptor
  and may use only the positive direct-child fallback; it never signals the
  inherited process group.
- Normal protocol completion closes the descriptor, waits for the direct App
  child without any signal, reaps its real wait status, and mints the opaque
  retirement proof only for an ordinary exit with status zero.
- The legacy App-owned process-group path retains its exact bounded TERM/KILL,
  waitable-leader, reap-last and post-reap-empty behavior.

## 3. Verification and Review

| Gate | Result |
| --- | --- |
| exact implementation scope | 10 non-document paths / 1,965 changed lines; 11 paths including the preflight amendment |
| focused topology, identity and retirement suites | 66 tests / 3 suites passed |
| a2-i semantic verifier | passed, including 15 exact semantic and vacuity mutations |
| a2-i scope verifier | passed, including path, budget, deletion, binary, mode and baseline negative controls |
| complete `scripts/verify-contract` replay | exit 0 after all historical and current checkpoint gates |
| SwiftPM Debug/Release artifact gate | exact undefined, load and owned projections passed |
| Xcode Debug/Release artifact gate | exact undefined, load and owned projections passed |
| staged-only serial regression | 1,500 tests / 78 suites passed in 98.780 seconds; step 100.205 seconds |
| independent grouped review | topology and retirement groups had no P0-P2; four verifier P1 findings were fixed and post-fix review found none |

The verifier review found four evidence defects: the unrecorded eight-to-ten
path scope change, condition-widening false-green windows for inherited
`SETPGROUP` and zero-exit validation, and incomplete boundary self-test
coverage. The closure records the ten-path amendment, matches both predicates
structurally, adds explicit widened-condition/disjunction mutations, and binds
the Swift self-test to the mutation harness and all four SwiftPM/Xcode
projections.

The final complete contract replay and focused boundary self-test apply to the
accepted implementation commit. The 1,500-test serial preceded the verifier-
only post-review closure; no production source changed afterward, so it was not
repeated. No authoritative headless or full verifier was run.

## 4. Non-Claims and Next Step

a2-i did not launch the installed App/helper/XPC topology, install anything,
request administrator authority, call Codex, consume subscription auth, use a
model or network, accept ADR 0018, claim machine readiness or enable production
Deep Dive.

a2-ii now owns the package-only outer/inner terminal-evidence composition and
the sole admission join. The remaining order is:

```text
a2-ii -> iii-b2b -> ii-c0b -> ii-c -> L3c3d -> L3c4
```

Task 39 remains incomplete, ADR 0018 remains Proposed and production Deep Dive
remains `.implementationUnavailable`.
