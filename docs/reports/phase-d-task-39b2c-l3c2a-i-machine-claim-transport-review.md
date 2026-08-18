# Phase D Task 39B2c-L3c2a-i Machine-Claim Transport Review

> Status: Complete; strict non-admitting Machine-claim transport checkpoint
>
> Date: 2026-08-18
>
> Baseline: `f508fc26f73d1c72ba866f1d6bb4453aa80a8e56`
>
> Scope: second fixed helper-owned Mach service, root-driver identity admission,
> claim-only one-shot XPC transport and authorization-before-consume escrow; no
> Machine host packaging, App-to-driver handoff, model, scenario matrix, report,
> readiness verdict or full verifier

## 1. Decision

L3c2a-i is complete. The existing root lifecycle helper now owns a second,
role-separated Mach service named exactly
`com.eriklee.stornaut.lifecycle.machine-claim`. The original App route remains
an exact App-signed, non-root, one-connection endpoint; the Machine route has a
separate listener, delegate, Objective-C interface and accepted-connection
state, and exposes only
`LifecycleMachineClaimXPCWire.claimMachineRetirement`.

The Machine admission policy requires EUID 0 and binds the complete current
process identity to the fixed driver executable path
`/Library/Application Support/Stornaut/Stornaut-R5-Diagnostic.app/Contents/MacOS/StornautInvestigationMachineDriver`,
the signing identifier
`com.eriklee.stornaut.investigation.machine-driver`, the PID version, audit
session, full audit token and both static and dynamic signing observations. It
repeats the complete observation immediately before the escrow's terminal
consume operation. A rejected or drifting identity does not consume the
memory-only entry.

The root claim client independently pins the fixed helper installation and
signing contract. It is one-shot and non-reconnectable. A failure before request
dispatch is a known transport failure; connection loss, interruption, timeout,
malformed response or other transport failure after dispatch is conservatively
classified as `LifecycleMachineClaimXPCError.outcomeUnknown`, because the
helper may already have consumed the claim.

The helper remains alive after a successful claim so that the next checkpoint
can preserve the required order: claim, installed L2 observation, transition,
then post-teardown L2 observation. The original bounded escrow deadline remains
the fail-safe if that continuation never arrives.

## 2. Exact Scope

The checkpoint changes exactly fourteen non-document source, test and script
paths, matching the frozen preflight ceiling:

1. `Sources/StornautLifecycle/LifecycleAppAuthorization.swift`
2. `Sources/StornautLifecycle/LifecycleMachineRetirementEscrow.swift`
3. `Sources/StornautLifecycle/LifecycleServiceRegistration.swift`
4. `Sources/StornautLifecycle/LifecycleSupervisorXPC.swift`
5. `StornautLifecycleHelper/com.eriklee.stornaut.lifecycle.plist`
6. `StornautLifecycleHelper/main.swift`
7. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`
8. `Tests/StornautLifecycleTests/LifecycleAppAuthorizationTests.swift`
9. `Tests/StornautLifecycleTests/LifecycleMachineClaimXPCContractTests.swift`
10. `Tests/StornautLifecycleTests/LifecycleMachineRetirementEscrowTests.swift`
11. `Tests/StornautLifecycleTests/LifecycleServiceRegistrationTests.swift`
12. `scripts/stornaut-r5-local-lifecycle`
13. `scripts/verify-app-release-boundaries`
14. `scripts/verify-investigation-boundaries`

The implementation diff contains 1,503 additions and 65 deletions, below the
approved 3,000-added-line limit. No fifteenth implementation path was added.

## 3. Tests First and Review Fixes

The focused contracts cover fixed service/path/signing identifiers, full
identity comparison, two-phase revalidation, authorization-before-consume,
rejection without consumption, role separation, one-shot client behavior,
pre/post-dispatch error classification, malformed replies and helper lifetime.
The structural boundaries also pin the exact selector allowlist and prohibit
Executor, Cleanup and readiness authority.

Independent grouped reviews found four material defects, all fixed before the
accepted serial snapshot:

- A P1 classified post-dispatch connection, timeout and malformed-response
  failures as definitely unconsumed. The client now returns `outcomeUnknown`.
- A later P1 found that transport classification and terminal continuation
  extraction used two lock acquisitions, allowing a race with request dispatch.
  `finishTransportFailure` now classifies and finishes atomically under one
  lock.
- A P2 checked only the diagnostic App for premature driver packaging. The
  release boundary now checks ordinary Debug, ordinary Release and diagnostic
  Debug bundles, including both nonexistent-path and non-symlink assertions.
- A P2 found that a structural test could be satisfied by variable declarations
  outside the three-bundle loop. It now extracts the exact loop body and checks
  the expected assertions and occurrence counts there.

Post-fix XPC, release-gate, identity/escrow and cross-group reviews report no
unresolved P0-P2 findings.

## 4. Validation

| Gate | Result |
| --- | --- |
| claim/identity/escrow focused regression | 36 tests in 5 suites passed |
| complete `StornautLifecycleTests` | 144 tests in 16 suites passed |
| complete `StornautInvestigationTests` | 178 tests in 17 suites passed |
| exact Investigation structural boundary | passed |
| verifier contract | passed |
| dedicated diagnostic App/helper Xcode build | passed; final affected build 7.7 seconds |
| ordinary Debug/Release and diagnostic release boundary | passed |
| clean staged-only serial regression | 1,041 tests in 49 suites passed |
| serial test / wall time | 112.092 / 161.43 seconds |
| independent post-fix review | no unresolved P0-P2 |

The accepted serial ran from snapshot commit
`b2ad5903bb545c10155fda91e713d7b1d0ccb8f4`. Its tree and the accepted
implementation index tree both equal
`5f4e58edd25de11c14b37cbb91c5649138eb18c9`, binding the run to the final
post-fix fourteen-path implementation.

The final independent review artifacts are available at:

- `/tmp/stornaut_l3c2ai_review.src1PX/final_comments.json`;
- `/tmp/stornaut_l3c2ai_review.src1PX/report.html`; and
- `/tmp/stornaut_l3c2ai_review.src1PX/report.md`.

| Artifact | SHA-256 |
| --- | --- |
| final findings | `37517e5f3dc66819f61f5a7bb8ace1921282415f10551d2defa5c3eb0985b570` |
| HTML report | `a1c6b297a82c4b20febf060ee04c99af289e534b73e2e3250908d3217cac552e` |
| Markdown report | `e11ff294b8ac3395ef259e6abc63fc9214d46e416b6a51668091460f32e827a8` |

`scripts/verify --full` was not run. Its remaining use is still reserved
exclusively for L3c4 final admission.

## 5. Safety Boundary

This checkpoint deliberately does not package or launch the Machine driver,
implement the real App-to-driver handle handoff, invoke a model, execute the
eight-scenario state machine, install or remove the fixed topology, produce a
machine report, promote readiness or enable product Deep Dive. The intermediate
built and installed App fixtures are required not to contain the driver.

The Machine route cannot select its service, helper, executable path, signing
identifier, PID, signal or cleanup operation. Investigation and Machine targets
gain no Cleanup, Trash, Policy, Executor or Registered Action authority. No
filesystem mailbox or persisted claim authority is introduced.

`~/.codex/config.toml` was not modified. No broad same-UID process discovery or
coordination was added, and no new dependency or license was introduced.
Production Deep Dive remains unavailable.

## 6. Next Gate

L3c2a-ii is next. It adds the non-product, root-only Machine driver host and
composes this strict claimant with the existing topology collector through an
injected one-shot handle source. It must enforce the exact
`claim -> installed L2 -> transition -> post-teardown L2` ordering while
returning only opaque non-`Codable` authority to the Machine module.

L3c2a-ii still may not package the driver into the App, implement the real
App-to-driver handoff, call a model, emit the eight-scenario matrix, produce a
readiness result or consume the final full verifier. Those remain ordered as
L3c2b, L3c3 and L3c4.
