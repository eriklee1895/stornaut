# Phase D Task 39B2c-L3c1b-i Configuration-Bound Helper Escrow Review

> Status: Complete; non-admitting configuration-bound helper-escrow prerequisite
>
> Date: 2026-08-18
>
> Baseline: `0a59f1f4eda81148e6f5ca35f7298bbabbac1596`
>
> Scope: strict configuration-bound interactive start/retire transport and
> helper-owned memory-only retirement escrow; no Machine claim/collector, root
> claim XPC surface, live install/uninstall, model, report, readiness or full
> verifier

## 1. Decision

L3c1b-i is complete. The strict interactive start request is now protocol v2
and requires the canonical complete `machineConfigurationSHA256()` value. The
interactive response is protocol v4, and an outer owned-resource retirement is
valid only when it carries the exact opaque v2 handle bound to all three of:

- Investigation ID and retire operation;
- the complete signed-runtime configuration SHA-256; and
- the helper-minted random claim token, represented inside escrow only by its
  SHA-256 digest.

The App Server transport propagates the same configuration digest through
start, write, read and retire, rejects a foreign handle on any bound dimension
and never substitutes an optional, empty or narrower capability hash. The
diagnostic composition derives the complete digest once from the already
validated configuration and injects it into the transport. The lifecycle broker
also treats configuration drift as a session-identity mismatch.

The helper records the strict owner-retirement truth before replying to the
App, enters a bounded `awaitingClaim` state and keeps only one memory-resident
`empty -> recorded -> consumed` escrow entry. Record, claim, expiry and replay
are serialized. Restart naturally loses the entry. No capsule, token, claim or
trusted retirement authority is written to disk.

## 2. Tests First and Review Fixes

The tests-first surface covers strict DTO decoding, configuration drift, exact
outer-handle validation, record/claim/expiry/replay, concurrent claim, helper
disconnect, broker state and Runtime propagation. Independent review exposed
several admission and linearization defects in the original combined L3c1b
draft:

1. a capsule could be spliced between two signed-runtime configurations that
   reused the same Investigation ID;
2. the helper could admit legacy work while waiting for the Machine claim;
3. an owned outer retirement could be accepted without the exact handle, and a
   weaker helper validator could bypass the outer contract;
4. interactive activation and queue insertion were not one atomic service-lock
   operation, so disconnect could leave a delayed start creating resources;
5. pre-retire read/write work could cross the retire barrier; and
6. legacy activation and queue insertion had the equivalent race.

The accepted implementation binds the complete configuration hash end to end,
removes the weak public/helper validation path, performs activation and queue
insertion under the same service lock, checks invalidation plus the exact epoch
before any interactive side effect, and revalidates legacy admission before any
legacy side effect. Fresh independent post-fix reviews found no unresolved
P0-P2 findings.

## 3. Validation

| Gate | Result |
| --- | --- |
| clean staged L3c1b-i focused | 58 tests in 5 suites passed |
| final admission/linearization focused | 51 tests in 3 suites passed |
| complete Lifecycle suite | 136 tests in 15 suites passed |
| complete Investigation suite | 168 tests in 16 suites passed |
| targeted Debug diagnostic App/helper build | passed |
| dedicated diagnostic App tests | 11/11 passed; 0 failed; 0 skipped |
| local Markdown links and staged diff hygiene | passed |
| clean staged-only serial regression | 1025 tests in 47 suites passed |
| serial test / wall time | 110.900 / 148.65 seconds |
| independent post-fix review | no unresolved P0-P2 |

The accepted serial ran from exact staged snapshot
`28f344b5530123edd7ec2663d0ee9750fd1f59c9` in a clean physical
`/Users/.../stornaut-validation.*/worktree`. The snapshot tree and the accepted
implementation index tree were independently compared and both equal
`8ac36a1f270157c4197b9618e2b805f0e2b338f5`; the run is therefore not a
superseded pre-fix regression.

The implementation changes exactly twelve non-document source/test paths with
2,012 additions and 105 deletions, within the frozen twelve-path and 2,500-added
line limits. The final local review records are:

- `/tmp/stornaut_l3c1bi_postfix_runtime.jsonl`;
- `/tmp/stornaut_l3c1bi_final_lifecycle_review.jsonl`; and
- `/tmp/stornaut_l3c1bi_fast_final.jsonl`.

Each final record is empty because its reviewer reported no unresolved finding;
an additional independent explorer reached the same conclusion.

## 4. Safety Boundary

This checkpoint does not add a production Machine claim selector, XPC client,
claim sender or signed root-driver authorization. The v2 claim DTO remains a
package-closed helper escrow contract with no production route. L3c1b-i also
adds no filesystem mailbox, persistent recovery, process launch, install or
service mutation, model call, Machine report, Cleanup/Trash/Executor/Registered
Action authority or readiness promotion.

`~/.codex/config.toml` was not modified. Production Deep Dive remains
unavailable. `scripts/verify --full` was not run; L3c4 still exclusively owns
Task 39's remaining authoritative full verifier and readiness claim.

## 5. Next Gate

L3c1b-ii must consume the already isolated synthetic Machine claim surface,
preserve the exact complete configuration digest in a non-`Codable` one-shot
reservation and join it to the lifecycle topology collector before L2 or any
transition work. It must keep the production claim route physically closed.
L3c2, not L3c1b-ii, will separately preflight and implement exact signed
root-driver authorization-before-consume.
