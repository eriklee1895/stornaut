# Phase D Task 39B2c-L3c2a-ii Machine Driver Host Review

> Status: Complete; non-admitting root-host/topology composition checkpoint
>
> Date: 2026-08-18
>
> Baseline: `32e6bb3c2638e3392473c8b7aa8a674409cc2daf`
>
> Scope: non-product Machine driver target, root-only one-shot host, strict
> claim/signing adapters and ordered claim-to-L2 composition; no App packaging,
> live App-to-driver handoff, scenario matrix, model, report, readiness or full
> verifier

## 1. Decision

L3c2a-ii is complete. The package now contains a buildable
`StornautInvestigationMachineDriver` executable target whose only direct target
dependency is `StornautInvestigationMachine`. It is omitted from the manifest's
explicit `products` list. SwiftPM 6.3 still materializes the executable target
as an implicit same-name product in the resolved graph; the structural gate
therefore verifies both facts independently: no explicit product declaration,
and exactly one same-name implicit executable membership with no other product
exposure.

The Machine module exposes only one narrow package surface:
`InvestigationMachineDriverEntryPoint.run()`. The current executable accepts no
arguments, environment configuration, JSON, plist, filesystem mailbox, socket,
path, PID, signal or action. It checks root authority and then returns a stable
nonzero unavailable status because the real in-memory parent/App handoff remains
L3c3 scope. On the current non-root validation host the built executable exits
with status `77`; root without a handoff is pinned to status `78`.

Inside the Machine trust boundary, `InvestigationMachineDriverHost` is terminal
one-shot. It changes `ready -> running` before its first suspension and becomes
`consumed` on success, error or cancellation. Its deterministic injected path
performs exactly:

```text
root admission
  -> one-shot handle handoff
  -> strict helper-owned XPC claim
  -> one-shot opaque claim Store
  -> installed L2 observation
  -> typed injected transition
  -> post-teardown L2 observation
  -> opaque non-Codable topology authority
```

The production factory composes the L3c2a-i
`LifecycleMachineClaimXPCClient`, an independent fixed installed-helper signing
verifier, `DarwinInvestigationLifecycleTopologyObserver`,
`InstalledLifecycleTopologyBindingReader` and the existing one-shot collector.
No claim, Store, cohort, handoff or transition authority becomes public or
package-visible.

## 2. Exact Scope and Cost

The final implementation changes exactly seven non-document paths:

1. `Package.swift`
2. `Sources/StornautInvestigationMachine/InvestigationMachineDriverHost.swift`
3. `Sources/StornautInvestigationMachine/InvestigationMachineRetirementClaim.swift`
4. `Tests/StornautInvestigationTests/InvestigationMachineDriverHostTests.swift`
5. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`
6. `scripts/verify-investigation-boundaries`
7. `tools/StornautInvestigationMachineDriver/main.swift`

The implementation diff contains 1,565 additions and 12 deletions. It remains
below the approved L3c2a-ii ceiling of eight non-document paths and 2,400 added
lines. The optional claim-file edit is the preflight-approved narrow seam needed
to preserve post-dispatch external-state uncertainty. No App, Xcode project,
helper, plist, install, signing or release script entered the implementation
scope.

## 3. Tests First and Review Fixes

The mandatory Swift unit-test workflow completed Steps 1-7 before production
implementation. Seven initial host contract cases first failed to compile only
because the approved host, adapters and entrypoint did not yet exist. One
test-only actor initializer defect was separated and fixed before production
code was added. Coverage enforcement was correctly skipped because neither the
user, project nor execution source required a coverage gate.

The final focused suite contains ten host cases and covers:

- root rejection before handoff or claim;
- successful `handoff -> claim -> installed -> transition -> postTeardown`
  ordering;
- concurrent admission with exactly one winner;
- terminal handoff, claim, installed-L2, transition and post-L2 failures;
- cancellation after claim starts;
- strict XPC forwarding without retry;
- independent full helper identity and static/dynamic signing comparison;
- package entrypoint root/unavailable statuses; and
- post-dispatch `outcomeUnknown`, including cancellation racing after dispatch.

Independent grouped and iterative post-fix review found seven P1 defects and
one P2 test-contract defect. All were closed before the accepted serial snapshot:

- P1: post-dispatch connection/timeout/malformed uncertainty was collapsed to
  ordinary `sourceFailed`; Machine now preserves `.outcomeUnknown`.
- P1: cancellation could still mask `.outcomeUnknown` after request dispatch;
  externally uncertain consumption now has priority once reported by the source,
  while ordinary source cancellation remains `CancellationError`.
- P1: two synthetic phase waiters had unbounded continuations and could hang a
  regression indefinitely; every phase wait is now bounded to two seconds.
- P1: the first bounded-wait repair signalled before installing the suspended
  operation continuation, creating a lost-resume race; all three suspended
  helpers now install the operation continuation before signalling the latch.
- P1: the no-authority verifier scanned only host/main and could miss another
  compiled Machine source; it now derives every source from the resolved target
  graph.
- P1: the driver dependency allowlist used bypassable manifest text; it now
  verifies both `swift package dump-package` and
  `swift package describe --type json`.
- P1: the first target-wide denylist omitted direct mutation APIs such as
  `trashItem` and `createDirectory`; the complete resolved-source scan now
  covers FileManager, Data/FileHandle, low-level writable-open, process, network
  and cleanup surfaces.
- P2: installed, transition and post-teardown failure tests did not prove the
  host stayed terminal; each now requires a second run to return `hostConsumed`.

An isolated clean staged-snapshot negative control injected an extra compiled
Machine source containing `FileManager.default.trashItem`. The structural gate
failed with status 1 and identified the exact prohibited source. The probe was
then removed, and the implementation index tree returned exactly to the
pre-probe value with zero residue.

Final independent host and test/gate reviews report no unresolved P0-P2
findings.

## 4. Validation

| Gate | Result |
| --- | --- |
| tests-first red contract | expected compile failure for missing L3c2a-ii production symbols |
| initial host focused | 7/7 passed |
| expanded host focused | 9/9 passed |
| affected post-review suites | 20 tests in 3 suites passed |
| exact outcome/cancellation regression | 2/2 passed after first proving the cancellation-mask failure |
| exact suspended-helper race regression | 3/3 passed |
| complete `StornautInvestigationTests` before final fixes | 187 tests in 18 suites passed |
| exact Investigation structural boundary | passed |
| structural mutation negative control | expected failure; exact prohibited Machine source detected |
| Machine driver target build | passed; incremental target build 0.57 seconds |
| built executable fail-closed behavior | passed; non-root exit 77 |
| targeted Debug diagnostic App build | passed in 6.3 seconds |
| ordinary Debug/Release and diagnostic bundle boundary | passed; driver absent from all three App bundles |
| clean staged-only serial regression | 1,046 tests in 50 suites passed |
| serial test / wall time | 84.801 / 144.78 seconds |
| final independent post-fix review | no unresolved P0-P2 |

The accepted serial ran once from validation commit
`6841e61` over staged tree
`a2578e11ac2faf0005359124e408a03a7fc9422c`. The implementation index tree
before and after the run equals the same value. There was no restart, failed
stage retry or second serial execution.

The bounded, layered funnel kept ordinary iteration fast: focused fixes rebuilt
and ran in approximately 4-8 seconds; the single clean regression took 144.78
seconds, compared with 161.43 seconds for L3c2a-i. The two-second phase latches
also turn future missing-phase regressions into explicit failures instead of
unbounded hangs.

The final code-review artifacts are available at:

- `/tmp/stornaut_l3c2aii_review.uUNBhi/final_comments.json`;
- `/tmp/stornaut_l3c2aii_review.uUNBhi/report.html`; and
- `/tmp/stornaut_l3c2aii_review.uUNBhi/report.md`.

| Artifact | SHA-256 |
| --- | --- |
| final findings | `37517e5f3dc66819f61f5a7bb8ace1921282415f10551d2defa5c3eb0985b570` |
| HTML report | `f134ddeebf2dadb95b9e047cc8a91de40a4f4a8bf05a86bdc255d110fc320f8e` |
| Markdown report | `247783718f3c50436f98eb9e659c3cd5c07b54ce7da91353b5403aac020793cf` |

`scripts/verify --full` was not run. Its remaining use is still reserved
exclusively for L3c4 final admission.

## 5. Safety Boundary

This checkpoint does not package the driver into any App, implement a live
parent/App-to-driver handle handoff, install or remove the lifecycle topology,
invoke a model, run the eight-scenario state machine, create a Machine report,
promote readiness or enable product Deep Dive. The executable is buildable but
deliberately unavailable for a successful standalone run until L3c3 supplies
the exact in-memory handoff.

The driver target directly imports only the Machine module. The host cannot
select a service, helper, executable, path, socket, PID, signal or cleanup
operation. The resolved target-wide structural gate rejects Execution, Cleanup,
Trash, Registered Action, arbitrary process/network access and filesystem
mutation authority. The opaque handle, claim Store, cohort and topology
authority remain memory-only and non-`Codable`.

`~/.codex/config.toml` was not modified. No broad same-UID process discovery or
coordination was added, and no new dependency or license was introduced.
Production Deep Dive remains unavailable.

## 6. Next Gate

L3c2b is next. It adds only the deterministic injected eight-scenario state
machine and fake Task 38/fault controls already frozen in the Task 39 brief. It
may emit a failure matrix or machine-admission-pending candidate, but may not
package the driver, implement the real handoff, call a model, create a Ready
receipt or consume the final full verifier.

The remaining strict order is `L3c2b -> L3c3 -> L3c4`. L3c3 owns the fresh
scope/cost preflight, current-source driver packaging and live in-memory handoff;
L3c4 alone owns authoritative readiness and Task 39's remaining full verifier.
