# Phase D Task 39B2c-L3b2 Lifecycle Topology Collector Review

> Status: Complete; synthetic trusted-collector prerequisite
>
> Date: 2026-08-18
>
> Baseline: `320dfec502268e43b3cf97ffa3afe64f33ea0eb8`
>
> Scope: one-shot package-only join of L3b1 retirement evidence and L2
> installed/post-teardown observations; fixed system-service inspection;
> synthetic transition only; no live install/bootout/uninstall, model, machine
> report or readiness claim

## 1. Decision

L3b2 is complete. The non-product `StornautInvestigationMachine` target now
depends one-way on `StornautInvestigationRuntime` and `StornautLifecycle` and
owns a module-internal, non-Codable lifecycle topology collector. The collector
consumes the L3b1 actor-owned retirement evidence store exactly once, validates
the exact Investigation, UID, helper identity, timestamps and signed App/helper
binding, proves installed L2 topology, admits one injected synthetic transition,
then proves post-teardown L2 topology in the same bounded window.

The collector is root-only and terminal one-shot. Every success, failure,
cancellation, replay or concurrent attempt consumes the collector and L1
handoff. Cancellation, EUID and deadline are revalidated immediately before
the transition boundary. The checkpoint deliberately does not create
`SignedInvestigationRuntimeResidue`: L3b2 has no independent managed-proxy
residue authority, so L3c must supply that plane before any final six-dimensional
zero-residue record.

## 2. Fixed Service Observation

The fixed service observer does not parse `launchctl`, enumerate processes or
acquire a Mach service send right. It checks the exact legacy plist status and
the exact system launchd-domain job dictionary for
`com.eriklee.stornaut.lifecycle`. Only these consistent pairs are admitted:

- `notRegistered`/`notFound` plus no exact-label job proves absence;
- `enabled` plus an exact-label job enters PID validation.

The PID must come from that same job dictionary, match the L3b1 attested helper
PID, and resolve to the identical full `LifecycleProcessIdentity`. Missing PID
cannot prove the installed phase. Status/job contradictions, foreign labels,
invalid PID values, excessive fields or unavailable inspection remain
unavailable. The deprecated single-job API is isolated behind a module-internal
inspector because current macOS provides no stable, non-activating replacement
for exact legacy system-domain PID inspection; L3c must re-evaluate any OS drift
as a focused blocker.

## 3. Tests First and Review Fixes

Tests were generated before product implementation under the mandatory Swift
unit-test workflow. Initial compile failures named only the absent service and
collector contracts. The final focused tests cover:

- consistent and contradictory service status/job states;
- exact job PID/full helper identity, PID reuse and unavailable lookup;
- root/binding/L1/window admission before topology work;
- strict L1 -> installed L2 -> transition -> post-teardown L2 order;
- transition failure, deadline drift, EUID drift and cancellation;
- installed/post phase failure; and
- concurrent collector admission plus cross-collector L1 replay.

Independent review first found two P1 and one P2 issue: an activating
`bootstrap_look_up`, unbound service/PID evidence and missing transition-time
EUID/deadline revalidation. The implementation removed the Mach lookup, bound
the PID to the exact job dictionary and added cancellation/root/deadline checks
at the mutation seam. A follow-up consistency matrix also closed ambiguous nil
service observations. Final independent review: `No unresolved P0-P2 findings.`

## 4. Validation

| Gate | Result |
| --- | --- |
| registry/service/collector focused | 14/14 passed |
| Lifecycle suite | 125/125 passed |
| Investigation suite | 167/167 passed |
| exact source-boundaries stage | passed in 5.861 seconds |
| targeted Debug helper build | passed |
| targeted Debug diagnostic App build | passed |
| clean staged-only serial regression | 1001 tests in 46 suites passed |
| serial stage time | 114.702 seconds |
| independent post-fix review | no unresolved P0-P2 findings |

The accepted serial ran from exact staged commit `89cb573` in a clean physical
`/Users/.../stornaut-validation.*/worktree`. The temporary worktree was removed
afterward. The final staged implementation changed ten non-document
source/test/script paths with 2,037 additions and two deletions, below both hard
scope limits.

## 5. Safety Boundary

This checkpoint does not provide a production transition implementation and
does not install, bootout, uninstall, remove or move any fixed topology object.
It adds no process launch, direct network, Cleanup/Trash/Executor/Registered
Action, machine assembler/verifier or readiness surface. L2 artifact/process
test injection seams remain module-internal. Machine remains non-product and no
ordinary Runtime/Diagnostic/App target depends on it.

`~/.codex/config.toml` was not modified. Production Deep Dive remains
unavailable. `scripts/verify --full` was not run; L3c still owns the sole final
authoritative full verifier.

## 6. Next Gate

L3c must implement the live current-source root driver and a closed production
handoff that survives App teardown without making L1 evidence Codable. It also
owns real build/install/invoke/bootout/uninstall, managed-proxy residue, the
eight-case failure matrix, bounded Task 38/model execution, machine report and
receipt assembly, final readiness and the authoritative full verifier.
