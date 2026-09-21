# Phase D Task 39B2c L3c3c-ii-b5b-iii-b2a-ii-a2-ii Review

> Status: complete / non-admitting; a2-ii closed
>
> Date: 2026-08-25
>
> Baseline: `f363fbb67cbfb355ae701a85bba51b92e6db283d`
>
> Implementation commit: `8eac2c4f622055f6afc0bfe90b9fc7c982c4b6d0`
>
> Implementation tree: `9e3bdefd237bcd5bc9c616f54e456e7565f7b03a`
>
> Immutable completion-seal commit:
> `70603a0c914eeb8d48aa4bd16928bdb0856ad558`
>
> Seal tree: `2035f886f5653ca41524741f9c67180da08bdca6`
>
> Next frontier: iii-b2b zero-argument entry and final artifact composition

## 1. Result

a2-ii is complete. The package-only Debug composition now drives one exact
outer/inner epoch from the c0a selection through request, ownership, independent
topology observation, acknowledgement, decision, result-or-parent-crash, both
EOF proofs, exact process-group retirement, terminal absence observations and
the existing sole admission actor. The execution factory constructs one
admission actor and shares it with the continuation prover; no second admitted
token or continuity mint was added.

The implementation changes exactly twelve non-document paths and 3,673 changed
non-document lines against baseline `f363fbb`. It remains below the frozen
3,800-line ceiling. No package or Xcode graph, public product surface, normal App
availability, cleanup authority or release behavior changed.

## 2. Closed Contract

- The inner validates its fixed role before reading FD 8, decodes only the exact
  self-contained request, sends ownership before accepting acknowledgement and
  decision, sends one result only for normal mode and deliberately exits with
  status `72` for the parent-crash scenario.
- The outer independently observes the driver/App topology, requires result or
  zero-byte EOF according to the closed mode, proves result EOF before control
  EOF, and cannot admit until terminal observations and unchanged driver identity
  have been joined.
- Retirement now retains the real `waitpid` status in an opaque outcome. Ordinary
  exit zero and deliberate parent-crash exit `72` are distinct; signals, malformed
  statuses and unrelated non-zero exits cannot impersonate either result.
- The process group receives a one-second natural-drain interval before TERM and
  a second one-second grace before KILL, while retaining the five-second total
  bound, waitable-leader, reap-last and post-reap-empty requirements.
- A real session I/O failure and the outer cleanup path share the same cached
  outcome-retirement task. Cleanup executes once, cleanup failure still wins,
  and successful cleanup no longer masks cancellation as `terminalUncertain`.
- The composition remains package-only and `#if DEBUG`; Release and every closed
  App/helper image remain free of the a2-ii symbols and `_exit` import.

## 3. Verification and Review

| Gate | Result |
| --- | --- |
| exact implementation scope | 12 non-document paths / 3,673 changed lines |
| focused composition/session/protocol/retirement selection | 55 tests / 4 suites passed |
| real-session cancellation regression | RED reproduced `.terminalUncertain`; post-fix passed with one retirement call and `.cancelled` |
| global `scripts/verify-investigation-boundaries` | passed with the exact 19-source DriverSupport graph and narrow fixed authority normalization |
| complete `scripts/verify-contract` replay | exit 0, including semantic mutations and historical checkpoints |
| staged-only serialized SwiftPM regression | 1,516 tests / 79 suites passed; test run 101.049 seconds, step 168.401 seconds |
| staged validation identity | commit `33096219e7129888da4bc61bb9be6becfc542041`; tree `9e3bdefd237bcd5bc9c616f54e456e7565f7b03a` |
| complete App/Release boundary gate | passed, including Xcode Debug/Release builds, diagnostic App tests and final-Mach-O positive/negative controls |
| immutable completion replay | implementation parent/tree, 12 paths, modes and exact line count verified; all 12 same-path tamper cases rejected |
| independent grouped review | three P1 findings repaired; final implementation and seal reviews have no unresolved P0-P2 |
| diff hygiene | `git diff --check` passed |

The first binary-gate attempt exposed a stale Debug owned-symbol projection; two
independent Xcode builds produced the same corrected projection. The final gate
then passed on the implementation tree. Review subsequently found a real-session
double-retirement error path and a missing global DriverSupport source entry.
Both were fixed tests-first before the final 1,516-test serial. The completion
seal then bound the immutable implementation commit rather than reconstructing
evidence from mutable worktree files.

No authoritative `scripts/verify --full` was run. Its sole remaining Task 39 use
is reserved for L3c4.

## 4. Non-Claims and Next Step

a2-ii did not install or launch the signed App/helper topology, invoke real XPC,
request administrator authority, call Codex, consume subscription auth, access
the network, accept ADR 0018, claim machine readiness or enable production Deep
Dive.

The remaining strict order is:

```text
iii-b2b -> ii-c0b -> ii-c -> L3c3d -> L3c4
```

Task 39 remains incomplete, ADR 0018 remains Proposed and production Deep Dive
remains `.implementationUnavailable`.
