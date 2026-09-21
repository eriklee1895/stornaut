# Phase D Task 39B2c-L3b1 Peer and Retirement Handoff Review

> Status: Complete; package-only prerequisite
>
> Date: 2026-08-17
>
> Baseline: `500b20d52335d218b83eebb59dbeb2e13209a69f`
>
> Scope: bind one fixed root helper XPC peer to the exact L1 retirement
> receipt and preserve that pair as opaque, one-shot package evidence; no
> installation, service probe, L2 collection, model run, machine report or
> readiness claim

## 1. Decision

L3b1 is complete. The interactive lifecycle client now challenges the
connected privileged helper for its complete kernel audit-token identity. The
untrusted strict wire response is accepted only when its PID, PID version,
EUID, audit-session ID and all eight token words agree with the current
`NSXPCConnection` metadata and the token verifies the exact installed helper
signing identity.

Every retirement performs a fresh challenge on the same non-reconnectable XPC
connection epoch. The client revalidates the exact connection object, epoch and
generation after both asynchronous replies, then seals the validated helper
peer under the retire operation ID. The runtime consumes that peer once and
combines it with the already validated L1 zero-residue receipt. The combined
evidence and its handoff store are package-only and non-Codable.

The public diagnostic retirement enum remains privacy-safe. A package-only
composition path may consume the opaque evidence once; a never-started
composition returns no evidence. The machine target graph remains unchanged in
this prerequisite. L3b2 will own the trusted L1/L2 collector and fixed-service
transition evidence.

## 2. Tests First

The tests-first pass added coverage for:

- strict challenge and response decoding, bounded freshness and unknown-field
  rejection;
- full audit-token self-consistency and connected PID/EUID/ASID matching;
- exact helper signing and preservation of the existing root-App rejection;
- fresh helper identity plus exact L1 residue retirement evidence;
- rejection of detached/non-evidence sessions; and
- irreversible `empty -> recorded -> consumed` handoff state.

The first focused runs failed only because the new contract did not exist.
After implementation, the helper-attestation suite passed 6/6 and the
transport suite passed 16/16.

## 3. Independent Review Fixes

Independent review found two P1 and one P2 issue before the final snapshot:

1. an old attestation could resume after actor reentrancy and repopulate a new
   connection;
2. separately collected helper identity and residue could cross a helper
   restart; and
3. the first one-shot store allowed recording again after consumption.

The post-fix design uses a shared invalidatable connection epoch, exact
generation checks after every relevant await, no reconnect after invalidation,
operation-bound retire peer transfer, and a terminal consumed state. The same
reviewer confirmed: `No unresolved P0-P2 findings.`

## 4. Validation

| Gate | Result |
| --- | --- |
| helper peer attestation focused | 6/6 passed |
| lifecycle transport focused | 16/16 passed |
| Lifecycle suite | 122 tests passed before final post-fix delta; focused post-fix suites passed |
| Investigation suite | 154 tests passed before final post-fix delta; focused post-fix suite passed |
| exact source-boundaries stage | passed in 4.611 seconds |
| targeted Debug helper build | passed |
| targeted Debug diagnostic App build | passed |
| clean staged-only serial regression | 987 tests in 43 suites passed |
| serial stage time | 121.156 seconds |
| independent post-fix review | no unresolved P0-P2 findings |

The accepted serial ran from exact staged commit `6e4e395` in a clean physical
`/Users/.../stornaut-validation.*/worktree`. The temporary worktree was removed
afterward. An earlier HEAD-only baseline run and an interrupted pre-review
candidate run are explicitly not acceptance evidence.

## 5. Safety Boundary

The checkpoint changes eight non-document source/test/script paths and remains
below the hard scope split limits. It adds no dependency, license, cleanup
authority, process-launch surface, direct network surface or product
availability. The machine target remains non-product and isolated.

`~/.codex/config.toml` was not modified. Production Deep Dive remains
unavailable. `scripts/verify --full` was not run; L3c still owns the single
authoritative full verifier for the enclosing machine admission checkpoint.

## 6. Next Gate

L3b2 may now consume the opaque L1/helper handoff inside the trusted collector,
perform fixed-service L2 installed/post-teardown observations in one sealed
window and exercise synthetic lifecycle transitions. It must not emit final
readiness. L3c remains responsible for live build/install/invoke, the failure
matrix, real bounded Task 38/model execution, final machine evidence and the
authoritative full verifier.
