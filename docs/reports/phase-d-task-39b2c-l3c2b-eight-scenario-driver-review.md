# Phase D Task 39B2c-L3c2b Eight-Scenario Driver Review

> Status: Complete; deterministic non-admitting Machine scenario checkpoint
>
> Date: 2026-08-18
>
> Baseline: `360ea61bed3cb875683cd052a4b522ca25c7b014`
>
> Scope: fixed eight-scenario Task 38 driving, one-shot Machine matrix assembly
> and structural no-authority gates; no App packaging, live handoff, real model,
> install/uninstall, Ready receipt or full verifier

## 1. Decision

L3c2b is complete. `InvestigationFixedScenarioRunner` validates one in-memory
Task 38 operation and exposes only a terminal non-`Codable` observation.
`InvestigationMachineScenarioDriver` preflights one exact cohort before any
root host is consumed, lets each existing host enforce
`claim -> installed L2 -> transition -> post-teardown L2`, joins the opaque
authority to the observation, and emits only
`SignedInvestigationRuntimeFailureMatrix`.

The eight cases use independent nonce/root/config/Store/plan identities and one
shared exact target set. Success alone carries synthetic capability digest and
denial placeholders; no authoritative R5 evidence is consumed. Cancellation,
wall-clock timeout, invalid envelope, identity mismatch, transport loss,
lifecycle recovery and artifact-cleanup recovery use the real Task 38
coordinator with injected memory-only owners. Each trace is bound to its exact
closing or terminal cause. Recovery starts from a production-eligible
nonterminal Store residue.

## 2. Exact Scope and Cost

The implementation changes exactly eight non-document paths:

1. `Sources/StornautInvestigationMachine/InvestigationFixedScenarioRunner.swift`
2. `Sources/StornautInvestigationMachine/InvestigationMachineDriverHost.swift`
3. `Sources/StornautInvestigationMachine/InvestigationMachineScenarioDriver.swift`
4. `Tests/StornautInvestigationTests/InvestigationLifecycleTopologyTestSupport.swift`
5. `Tests/StornautInvestigationTests/InvestigationMachineScenarioDriverTests.swift`
6. `Tests/StornautInvestigationTests/InvestigationMachineScenarioTestSupport.swift`
7. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`
8. `scripts/verify-investigation-boundaries`

The final implementation tree has 2,660 additions and 11 deletions, below the
approved eight-path / 3,000-added-line ceiling. No package graph, App target,
Xcode project, helper, plist, entitlement, install or release configuration
changed.

## 3. Tests First and Review Fixes

The mandatory Swift unit-test workflow completed its tests-first preparation,
scope, defect analysis, generation/repair loop and report flush. Coverage
enforcement was skipped because neither the user, repository nor execution
source requested an incremental coverage gate. The final focused suite has
eight cases covering all scenarios, one-shot/non-`Codable` state, topology
order, preflight rejection, actor reentrancy, case-insensitive inode aliases
and empty artifacts.

Independent iterative review found and closed all reported P0-P2 issues:

- actor reentrancy could revive a consumed runner after its async operation;
- outcomes initially lacked exact coordinator cause checks;
- recovery initially injected terminal states the real Store never pages;
- path strings could alias the same filesystem objects;
- host/runner/config/plan wiring could fail only after consuming authority;
- empty or oversized artifacts could fail only during post-host hashing;
- cleanup/policy, raw network, access-level and readiness structural gates had
  bypassable partial denylists or baselines.

The final implementation binds host transition and attempt runner with a fresh
memory-only token, opens every preflight path component with `O_NOFOLLOW`, keeps
all root/report/store descriptors alive while comparing device/inode identity,
validates owner/type/mode/link/nonzero/size limits before host execution, and
uses exact cause checks for every Task 38 outcome. The structural verifier scans
all resolved Machine and driver sources, rejects cleanup/process/network/
filesystem authority, handles modifier chains and `package(set)`, and binds the
historical readiness surface to exact line-plus-normalized-text records.

The final independent checklist review reported no unresolved P0-P2 findings.
The local code-review fallback report is available at
`/tmp/stornaut_l3c2b_postfix.ETnzms/report.html`.

## 4. Validation

| Gate | Result |
| --- | --- |
| focused eight-scenario suite | 8/8 passed |
| complete Investigation suite | 197 tests in 19 suites passed |
| exact Investigation structural boundary | passed |
| Machine target build | passed |
| built driver fail-closed behavior | non-root exit 77 |
| targeted Debug diagnostic App build | passed |
| targeted App bundle boundary | driver absent |
| ordinary Debug/Release and diagnostic release boundary | passed |
| clean staged-only serial regression | 1,055 tests in 51 suites passed |
| serial test time | 83.757 seconds |
| accepted staged tree | `dcd6f33e60521a1a6d4adae2173d14e8bb17abc0` |
| final independent review | no unresolved P0-P2 |

The clean staged-only serial ran exactly once from a generated validation commit
over the accepted index tree. The index tree before and after the run is exact.
There was no restart, failed-stage retry or second serial execution. Maximum
Task 36/37 benchmarks remained explicitly skipped.

`scripts/verify --full` was not run. Its remaining use is still reserved only
for L3c4 sealed final admission.

## 5. Safety Boundary and Next Gate

This checkpoint does not package the Machine driver into an App, implement the
real App-to-driver handoff, call a model, consume authoritative capability
evidence, create a Machine report or Ready receipt, install/remove the fixed
topology, enable product Deep Dive, or claim machine readiness. Production Deep
Dive remains unavailable.

L3c3 is next. It must first perform its own scope/cost preflight, then package
the current-source driver and implement the live one-shot in-memory handoff for
one bounded real-success three-plane composition. L3c4 alone owns the complete
eight-attempt authoritative cohort, readiness promotion and the remaining full
verifier.

`~/.codex/config.toml` was not modified. No broad same-UID process discovery or
coordination, dependency or license change was added.
