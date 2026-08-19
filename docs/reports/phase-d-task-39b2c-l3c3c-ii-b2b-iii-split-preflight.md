# Phase D Task 39B2c-L3c3c-ii-b2b-iii Split Preflight

> Status: Approved implementation split; iii-a handle-v3/single-quantized
> transfer is current, iii-b live-helper server integration follows
>
> Date: 2026-08-20
>
> Baseline: `b375fe4030fd99af7c3762b43782275365419ffa`
>
> Admission: non-admitting; no App/helper launch, install, privilege, model/auth,
> fixed client, readiness claim or authoritative full verifier

## 1. Why the Existing Fourteen-Path Checkpoint Is Split

The original ii-b2b-iii preflight reached the repository hard ceiling exactly:
fourteen non-document paths and 4,000 changed lines. A fresh post-ii-b2b-ii
call-graph audit confirmed that all fourteen paths remain plausible, but exposed
two independent high-risk domains inside that one review surface:

1. the public `LifecycleMachineRetirementHandle` v2 Date encoding must become
   strict v3 integer-microsecond truth, and the escrow entry, transfer payload,
   handoff handle and interactive retired response must preserve that integer
   without a second quantization; and
2. the external Xcode helper must link a currently package-closed server product,
   consume a narrow public façade, own the physical continuous clock/scheduler/
   terminal action, replace its legacy one-selector service and satisfy exact
   Xcode/final-Mach-O gates.

These domains can be validated independently. Combining them leaves no path or
line-budget margin for a discovered contract correction and would recreate the
large review surfaces prohibited after Tasks 36–38. The split below preserves
the original semantics and strict order while making each checkpoint reviewable.

## 2. Exact Current Call Graph

The live helper still performs:

```text
interactive retire
-> retirementEscrow.record(Date validBefore)
-> LifecycleMachineRetirementHandle v2 JSON Date
-> retired App response

legacy private claim selector
-> JSON LifecycleMachineRetirementClaimRequest
-> retirementEscrow.claim
```

The non-product server already has the intended semantic core:

```text
retirementEscrow.transferReservation()
-> InvestigationMachineClaimServerAdapter
-> LifecycleMachineRetirementEscrowDeadlineState
-> InvestigationMachineClaimServerEffectExecutor
```

However, its adapter, effect protocols and executor are package-scoped; the
external Xcode helper does not link the server product. The helper still owns
legacy `DispatchQueue.asyncAfter` exit timers and consults
`retirementEscrow.isAwaitingClaim`.

## 3. iii-a — Handle v3 and Single-Quantized Transfer

### 3.1 Exact scope and cost

Exactly ten non-document paths, at most 1,800 added-or-changed lines:

1. `Sources/StornautLifecycle/LifecycleMachineRetirementEscrow.swift`;
2. `Sources/StornautInvestigationMachineClaimServer/InvestigationMachineClaimServerAdapter.swift`;
3. `Tests/StornautLifecycleTests/LifecycleMachineRetirementEscrowTests.swift`;
4. `Tests/StornautLifecycleTests/LifecycleMachineClaimXPCContractTests.swift`;
5. `Tests/StornautLifecycleTests/LifecycleInteractiveSessionContractTests.swift`;
6. `Tests/StornautInvestigationTests/InvestigationLifecycleAppServerTransportTests.swift`;
7. `Tests/StornautInvestigationTests/InvestigationMachineClaimServerAdapterTests.swift`;
8. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
9. `scripts/verify-investigation-boundaries`;
10. `scripts/verify-contract`.

No helper, Package, Xcode, App/runtime production source, scheduler/effect source
or release-boundary script changes are allowed. If a production consumer outside
these paths requires a semantic edit, iii-a stops and is split again.

### 3.2 Responsibilities

- raise `LifecycleMachineRetirementHandle.protocolVersion` to `3`;
- store exactly `validBeforeUTCMicroseconds: Int64`;
- keep `validBefore` as a computed `Date` projection, never a CodingKey;
- encode exactly version, token, investigation ID, retire operation ID, lowercase
  configuration SHA-256 and the integer;
- reject unknown, mixed Date+integer, v2 Date-only, nonpositive, non-finite and
  out-of-`Int64` inputs;
- quantize the Date input exactly once with checked
  `floor(timeIntervalSince1970 * 1_000_000)`;
- store the same integer in the escrow entry and package transfer;
- have the server projection consume the integer directly, never convert Date
  back into microseconds; and
- preserve exact nested round-trip through the interactive retired response and
  App transport evidence.

The existing legacy claim route may remain temporarily, but all equality checks
must compare the canonical integer. iii-a does not expose a public server façade
or transfer ownership to a live helper connection.

### 3.3 Tests-first and gates

RED tests first cover exact v3 keys, v2/mixed/unknown rejection, floor-once
sub-microsecond behavior, stable Date projection/re-encoding, escrow/handle/
transfer integer equality, claim-vs-transfer one-winner behavior, interactive
retired-response round-trip and server projection equality.

Then run focused Lifecycle/Investigation suites, affected suites, focused
coverage, structural and executable mutation gates, one staged-only serial and
independent review. No App build is required because no App/Xcode/helper source
changes. No authoritative full verifier is permitted.

## 4. iii-b — Public Live Façade and Helper Integration

### 4.1 Exact scope and cost

Exactly thirteen non-document paths, at most 3,200 added-or-changed lines:

1. `Stornaut.xcodeproj/project.pbxproj`;
2. `StornautLifecycleHelper/main.swift`;
3. `Sources/StornautLifecycle/LifecycleMachineRetirementEscrow.swift`;
4. `Sources/StornautInvestigationMachineClaimServer/InvestigationMachineClaimServerAdapter.swift`;
5. `Sources/StornautInvestigationMachineClaimServer/InvestigationMachineClaimServerEffects.swift`;
6. `Tests/StornautLifecycleTests/LifecycleMachineRetirementEscrowTests.swift`;
7. `Tests/StornautLifecycleTests/LifecycleMachineClaimXPCContractTests.swift`;
8. `Tests/StornautLifecycleTests/LifecycleInteractiveSessionContractTests.swift`;
9. `Tests/StornautInvestigationTests/InvestigationMachineClaimServerAdapterTests.swift`;
10. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
11. `scripts/verify-app-release-boundaries`;
12. `scripts/verify-investigation-boundaries`;
13. `scripts/verify-contract`.

`Package.swift`, HandoffContract, App/runtime/DriverSupport/native-driver source,
schemes and every new file remain frozen. A need for any additional non-document
path or more than 3,200 changed lines forces another split before coding.

### 4.2 Responsibilities

- link the existing static claim-server product only into the Xcode helper;
- keep fixed service selection and complete machine-driver peer admission in the
  helper before server-session construction;
- expose a narrow public server session/factory that accepts the public escrow
  object and internally performs the package-scoped one-shot transfer;
- expose only bounded Data-facing service/session and closed clock/scheduler/
  terminal abstractions or closure wrappers;
- never expose a caller-selected service/path, raw token, authorization Boolean,
  executable/signal, cleanup/Policy/Executor or package Handoff types;
- replace the helper-private legacy one-selector service with the HandoffContract
  two-selector service;
- preserve same-connection claim/release epoch ownership and exactly-once
  invalidation;
- implement checked `mach_continuous_time`/timebase observation, cancellable
  relative scheduling and fresh callback re-observation inside the listed helper
  or server files;
- remove legacy global claim/success/failure exit timers from the machine-claim
  path; and
- invoke the release reply before `replyDidDispatch`, with no second reply/retry
  if post-reply arming fails.

### 4.3 Tests-first and gates

RED tests first cover unauthorized-before-decode, same-session claim/release,
foreign/reconnect/replay, old JSON rejection before transfer, single-owner
transfer, physical scheduler races, timer replacement, reply ordering, terminal
once and zero pending slots. Structural gates then prove exact public surface,
helper-only product linkage, no authority expansion and no legacy route.

Targeted Debug/Release helper builds and final-Mach-O gates must prove helper
positive for server/Handoff/two selectors and all ordinary/diagnostic/Release
shell/driver images negative as specified by the parent preflight. Finish with
focused/affected suites, coverage, one staged-only serial and independent review.
Do not launch the helper/App or invoke real XPC. No authoritative full verifier
is permitted.

## 5. Strict Order and Non-Admission

The order is strict:

```text
ii-b2b-iii-a -> ii-b2b-iii-b -> ii-b3 -> ii-b4 -> ii-b5
-> ii-c0 -> ii-c -> L3c3d -> L3c4
```

iii-a and iii-b are both non-admitting. iii-b completes ii-b2b but creates no
fixed client and proves no installed-L2, helper disappearance, next-epoch
freshness or real signed-App execution. ADR 0018 remains Proposed, Task 39
remains incomplete, production Deep Dive remains unavailable and L3c4 retains
exclusive readiness/final-full ownership.
