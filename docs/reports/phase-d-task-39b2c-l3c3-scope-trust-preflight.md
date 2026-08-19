# Phase D Task 39B2c-L3c3 Scope and Trust Preflight

> Status: Split revised; L3c3a/L3c3b/L3c3c-i/L3c3c-ii-a complete; external
> root-launch branch rejected; L3c3c-ii-b split frozen; ii-b0 current
>
> Date: 2026-08-18
>
> Baseline: `2eb977a4a093e5ebaf25c23f3d2866108a8d00eb`
>
> Scope: current-source real-success three-plane composition; no implementation,
> model call, install/uninstall, readiness or full verifier in this preflight

## 1. Decision

L3c3 cannot remain one implementation checkpoint. The live checkout exposes
four independent trust surfaces whose combined review set is larger than the
repository's fourteen-path ceiling:

1. strict driver identity in the signed attempt/runtime schema;
2. a fixed-signing native driver packaged only in the diagnostic App;
3. a parent-owned one-shot launcher/handoff transport established before App
   launch; and
4. one real Task 38 success joined to capability, L1/L2 and owner-retirement
   evidence without promoting readiness.

L3c3 was first split into `L3c3a -> L3c3b -> L3c3c-i -> L3c3c-ii ->
L3c3d`. The root-launch audit then returned NO-GO for external staging and
execution. The current split is `L3c3a -> L3c3b -> L3c3c-i ->
L3c3c-ii-a -> L3c3c-ii-b -> L3c3c-ii-c -> L3c3d`. L3c3d alone may
call the real authenticated model and may emit only a machine-admission-pending
candidate. L3c4 remains the sole readiness and final-full gate.

## 2. Current-Checkout Evidence

The existing SwiftPM executable cannot simply be copied into the App. A local
build produces an ad-hoc executable whose identifier is toolchain-hash-derived
(`StornautInvestigationMachineDriver-...`), while the accepted helper admission
contract requires exactly
`com.eriklee.stornaut.investigation.machine-driver`.

The Xcode diagnostic target currently has only the helper target dependency and
`Copy Investigation Helper` phase. It has no native driver target, dependency or
copy phase. Ordinary Debug/Release and diagnostic bundle gates deliberately
prove the driver absent. The lifecycle install/status/uninstall script likewise
rejects a present driver at built, staging and installed paths.

The current diagnostic App reads `config.json`, prepares the Task 38 facade,
immediately retires it, and writes a filesystem preflight receipt. During
retirement, the helper returns `LifecycleMachineRetirementHandle` inside the
App XPC response. L3c3 explicitly forbids that handle from being the real
App-to-parent handoff, and also forbids JSON, a filesystem mailbox or a
caller-selected endpoint.

The original L3c reasoning mentioned parent-owned IPC and anonymous XPC only as
candidates; no concrete transport or launcher was accepted. Current Foundation
documentation confirms an anonymous `NSXPCListener` endpoint can connect another
process and is `NSSecureCoding`, but that does not by itself prove a safe
ready-before-App-launch endpoint transfer, fixed root-to-user launch, complete
peer identity or teardown ordering. A spike/ADR is mandatory before production
handoff code.

## 3. Frozen Split

### L3c3a — Driver-Bound Signed Attempt Schema

Add a required, strict driver identity binding to the signed runtime attempt. It
must bind at least the driver executable SHA-256, fixed signing identifier,
designated-requirement SHA-256, code-directory hash and fixed machine-claim
service identifier. Configuration and every enclosing serialized machine
contract must receive an explicit strict schema migration; old payloads and
unknown/missing driver fields fail closed. Production diagnostic binding
observation must require the installed driver and compare the complete static
identity. Until L3c3b packages it, the live diagnostic remains blocked.

This prerequisite owns exactly fourteen possible non-document paths and at most 3,000 added
non-document lines:

1. `Sources/StornautInvestigation/SignedInvestigationRuntimeContract.swift`
2. `Sources/StornautInvestigationDiagnostic/InvestigationRuntimeDiagnosticAppLeaf.swift`
3. `Sources/StornautInvestigationDiagnostic/InvestigationRuntimeDiagnosticComposition.swift`
4. `Sources/StornautInvestigationMachine/SignedInvestigationRuntimeMachineContract.swift`
5. `Tests/StornautInvestigationTests/SignedRuntimeContractTests.swift`
6. `Tests/StornautInvestigationTests/SignedRuntimeMachineSerializationTests.swift`
7. `Tests/StornautInvestigationTests/InvestigationLifecycleTopologyTestSupport.swift`
8. `Tests/StornautInvestigationTests/InvestigationLifecycleTopologyCollectorTests.swift`
9. `Tests/StornautInvestigationTests/InvestigationMachineRetirementClaimTests.swift`
10. `Tests/StornautInvestigationTests/InvestigationMachineScenarioTestSupport.swift`
11. `StornautAppTests/InvestigationRuntimeDiagnosticTests.swift`
12. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`
13. `scripts/verify-investigation-boundaries`
14. `scripts/verify-app-release-boundaries` for the exact blocked-until-driver
    contract only; it must not package or sign the driver before L3c3b.

It changes no Xcode target, App bundle, launcher, XPC selector, lifecycle helper,
model flow, report verdict or installation.

### L3c3b — Native Driver Packaging and Installed Topology Admission

Create one fixed-signing native Xcode driver product or another independently
proved equivalent that satisfies the exact accepted identifier. Package it only
in `StornautInvestigationDiagnostic.app`, add it to the fixed install contract,
and make installed/post-teardown L2 observe its executable/signing identity.
Ordinary Debug/Release Apps must remain driver-free. Built, staging and installed
scripts must verify type, owner, mode, link count, arm64 shape, bundle nesting,
complete signing identity and exact hash. This checkpoint gets its own path/line
preflight because choosing a native target versus a narrow package product
changes the trust graph. It performs no live install, handoff or model call.

### L3c3c-i — Parent-Owned Handoff/Launcher Spike and ADR

Prove, outside product code, one fixed topology that satisfies all of:

- root Machine driver owns the channel before App launch;
- only the fixed installed App is launched as the exact non-root user;
- the channel is one-shot, bounded and non-persistent;
- no handle travels through configuration JSON, filesystem, helper claim reply
  or a caller-selected endpoint;
- both peers are bound by complete process/audit/code-signing identity;
- cancellation, App crash, driver crash, descriptor/endpoint replay and deadline
  fail closed with zero residue; and
- the App remains alive through driver claim and installed-L2 observation.

Candidates include an inherited fixed file descriptor carrying a strict binary
capsule or a parent-created anonymous XPC endpoint transferred only through a
fixed inherited descriptor. Repository docs and a Proposed ADR must select one
candidate before implementation; machine behavior, not static study alone,
decides final ADR acceptance. Spike code lives outside the repository and is not
a product implementation checkpoint; only its ADR/study and reproducible
evidence may be committed. This spike adds no product launcher authority.

Final status: the external study rejected anonymous-XPC keyed transfer and
symmetric inherited peer-token authentication, then conditionally selected one
asymmetrically identity-bound fixed socketpair topology. L3c3c-i-a transport/
lifecycle evidence and i-b1 root-to-UID implementation, non-root gate, cleanup
negative and static review are complete. i-b2a separately froze and satisfied
the exact-execution plus normalized-unsigned plus signed-semantic reproducibility
contract. i-b2b-0a subsequently completed the root-launch audit with NO-GO for
all UID-staged external root paths. i-b2b-0b staging and i-b2b-1 execution were
superseded before execution; B4 root execution count is zero and no root
artifact or receipt exists. L3c3c-i is complete as a study/audit, while
[ADR 0018](../adr/0018-parent-owned-investigation-handoff.md) remains Proposed.
See the
[study](../upstream-studies/phase-d-task-39b2c-l3c3c-parent-owned-handoff.md)
and [final review](phase-d-task-39b2c-l3c3c-i-handoff-launcher-spike-review.md),
plus the [i-b2a review](phase-d-task-39b2c-l3c3c-i-b2a-reproducibility-contract-review.md)
and [i-b2b-0a review](phase-d-task-39b2c-l3c3c-i-b2b-0a-root-provenance-review.md).

### L3c3c-ii — Installed-Driver Implementation and Machine Gate

The rejected external branch cannot be used as an implementation shortcut. The
fixed installed driver is conditionally selected and ii is split again:

- **ii-a authority-closed live DriverSupport** adds fixed self-observation and the
  minimum socketpair/launch/lifecycle primitives while preserving the
  Debug/Release final-Mach-O prohibition on Core/Execution/Cleanup/Policy/Trash/
  Executor/Registered Action authority. No install, App launch, sudo or model.
- **ii-b fixed handoff composition** is further split into ii-b0 shared
  wire/capsule, ii-b1 App leaf, ii-b2 handle-free helper response, ii-b3 concrete
  App adapter, ii-b4 fixed claim client and ii-b5 single-epoch composition;
  ii-c0 separately proves the TTY/capsule launcher before privilege. This closes
  the helper-response handle echo and distinguishes per-epoch process retirement
  from final uninstall. See the
  [ii-b split preflight](phase-d-task-39b2c-l3c3c-ii-b-split-preflight.md).
- **ii-c one no-model outer installed-driver gate** follows a fresh ii-c0
  launcher-authoring preflight, then builds and installs the exact
  current-source topology, repeats static artifact/service admission, then
  requires nonzero `sudo -kNnv`, the fixed manual prompt and only the fixed
  root-owned driver with zero driver arguments. Timestamped full installed-L2
  follows each App launch; claim release then proves exact helper exit, and the
  next epoch requires a fresh helper identity/full L2 before transition/`EXIT`
  as applicable. ii-c then uninstalls and proves zero
  residue. One outer invocation contains the closed sequential scenario
  epochs; a started failed outer attempt, including real-sudo stdin/TTY mismatch,
  is not retried to repair implementation.

The launcher accepts no caller executable, path, arguments, environment, UID,
endpoint, PID, signal or action. The live flow linearizes `driver ready -> App
launch -> Task 38 retirement/escrow record -> parent handoff -> claim ->
installed L2 -> driver EXIT transition -> exact epoch process retirement`.
Final App/helper/service bootout/uninstall and post-teardown L2 occur once at
the end of ii-c, not after every epoch. The flow may return only opaque
non-`Codable` authority. Exact path
and cost ceilings are frozen in the
[installed-driver preflight](phase-d-task-39b2c-l3c3c-ii-installed-driver-path-cost-preflight.md).

### L3c3d — One Real-Success Three-Plane Pending Candidate

Reuse one nonce for the current-source signed attempt, the real Task 38 success
flow, R5 9/9 capability worker evidence, 12/12 integrity/denial evidence and the
opaque L1/L2/owner-retirement cohort. Reuse the strict Machine assembler rather
than scripts or a second report schema. It may write privacy-safe raw evidence
and one machine-admission-pending candidate only. It must cleanly uninstall and
prove zero residue, but cannot promote `signedInvestigationRuntimeReady` or run
the remaining full verifier.

## 4. Validation Funnel

Each implementation checkpoint follows structural -> focused -> affected suites
-> one staged serial (or approved headless owner) -> targeted App/binary gate ->
independent review. No checkpoint uses `scripts/verify --full`. L3c3d owns at
most one real model attempt and may not retry it to repair implementation bugs.
L3c3a, L3c3b, L3c3c-i and L3c3c-ii-a/b/c must not authenticate Codex or call a model.

## 5. Safety Boundary

This preflight made no repository code change, installed nothing, launched no
model and did not alter `~/.codex/config.toml`. Production Deep Dive remains
unavailable. L3c3a, L3c3b, L3c3c-i and L3c3c-ii-a are complete; the root-launch
audit closed the external branch with NO-GO and did not accept ADR 0018.
The ii-b split passed three independent review rounds and ii-b0 is current.
ADR 0018 may become Accepted only after
ii-c succeeds. Any
path beyond a frozen ceiling still
requires another split before coding.
