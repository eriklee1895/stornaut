# Phase D Task 39B2c iii-b2b-1a Outer Observation Preflight

> Status: scope, trust boundary and tests-first split frozen; implementation
> not started
>
> Date: 2026-08-25
>
> Baseline: `d643b8fd500be29736a962dcd0c270304b490828`
>
> Scope: source, test and verifier inspection only. No App/helper launch, XPC,
> install, sudo/root operation, model/auth/network use, serialized regression or
> authoritative full verifier was used for this preflight.

## 1. Decision

The post-iii-b2b-0 graph still has no production implementation for either
`InvestigationMachineDarwinOuterOwnershipObserving` or
`InvestigationMachineDarwinOuterTerminalObserving`. The current test double
returns constant `.observed` absence values and a fixed digest; those values are
not product evidence.

The remaining observation work spans two independent trust transitions and
cannot safely fit the original eight-path / 2,800-line checkpoint:

1. the physical ownership wire retains only `claimEvidenceSHA256`, so the outer
   cannot inspect the helper-sealed L1 receipt or prove that it matches the
   selected nonce, App/helper identities and release deadline; and
2. the outer still needs concrete initial/final driver observation, live
   inner/App topology re-observation and exact App/helper identity absence.

iii-b2b-1a therefore splits before production coding:

```text
iii-b2b-1a-0 canonical helper-provenance carriage
-> iii-b2b-1a-1 concrete outer ownership/terminal observers
-> iii-b2b-1b zero-argument entry and final artifact
```

Both checkpoints remain non-admitting. They do not install or run the fixed
topology and cannot accept ADR 0018 or claim machine readiness.

## 2. Trust Contract

### 2.1 Helper evidence carriage

The inner obtains `InvestigationMachineClaimEvidence` only through the existing
fixed helper XPC client, which validates static/dynamic helper signing, complete
connection identity, request/challenge/epoch binding, App/helper identity and
the helper-created zero-residue record. The outer may accept the inner only
after independently observing the exact self-spawned root child and App
topology.

The physical ownership wire may therefore relay the exact canonical claim
evidence, but those bytes alone are not provenance. Their provenance is the
exclusive FD 8 socketpair endpoint inherited by the exact fixed-path
self-spawned child, combined with the outer's independent child/App identity
observation. The relayed value remains untrusted until the outer:

- strict-decodes and canonical re-encodes it;
- recomputes and matches `claimEvidenceSHA256`;
- matches App and helper identities exactly;
- matches L1 investigation UUID to the selected configuration nonce;
- matches L1 audit session to the helper and L1 UID to the App;
- requires the four L1 residue counters to be zero through the closed
  `InvestigationMachineL1Residue` initializer; and
- matches the release deadline to the ownership and epoch deadline.

This receipt never proves App/helper process disappearance or group
containment. It is one input to an outer-owned terminal join.

### 2.2 Physical terminal observation

The concrete outer observer must independently:

- observe the installed driver before spawn and after terminal retirement, hash
  the complete canonical observation and require exact equality;
- re-observe the self-spawned inner and App topology before acknowledgement;
- after group retirement, prove the exact App and helper PID/version/ASID/audit
  identities are absent or numerically reused, never merely unreadable;
- validate the relayed helper evidence against the exact physical ownership;
- use a monotonic observation timestamp strictly before the epoch deadline; and
- mint package-only, non-`Codable` observation values consumed by the existing
  one-shot admission actor.

The observer must not import `StornautLifecycle` or
`StornautInvestigationMachine`, duplicate their global uninstall topology
logic, enumerate unrelated same-UID processes, or treat an inner boolean,
nonzero digest, EOF or empty PGID alone as containment.

## 3. iii-b2b-1a-0 Exact Scope and Cost

Maximum eight non-document paths and 2,200 changed non-document lines:

1. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineSingleEpochComposition.swift`
2. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineSingleEpochPhysicalBridge.swift`
3. `Tests/StornautInvestigationTests/InvestigationMachineSingleEpochPhysicalBridgeTests.swift`
4. `Tests/StornautInvestigationTests/InvestigationMachineDarwinOuterInnerProtocolTests.swift`
5. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`
6. `scripts/verify-contract`
7. `scripts/verify-investigation-boundaries`
8. `scripts/verify-app-release-boundaries`

It may retain the complete canonical claim evidence inside the existing
ownership candidate and physical ownership wire, while preserving the existing
digest and all selection bindings. No protocol file, Package/Xcode graph,
Darwin process source, public entry, App/helper/Lifecycle/Machine target or new
authority is allowed. If another non-document path is required, stop and amend
the split before editing it.

## 4. iii-b2b-1a-1 Exact Scope and Cost

Maximum eight non-document paths and 2,800 changed non-document lines:

1. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinAppIdentityObservation.swift`
2. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinOuterObservation.swift` (new)
3. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinOuterInnerComposition.swift`
4. `Tests/StornautInvestigationTests/InvestigationMachineDarwinOuterObservationTests.swift` (new)
5. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`
6. `scripts/verify-contract`
7. `scripts/verify-investigation-boundaries`
8. `scripts/verify-app-release-boundaries`

The existing C identity support, App identity reader, driver-child observer,
installed-driver observer and session/retirement result must be reused. No new
C shim, Package/Xcode graph, Lifecycle import, product target or second focused
test file is allowed. A required ninth path triggers another split.

## 5. Tests-First Matrix

### iii-b2b-1a-0

- normal and parent-crash ownership round-trip the exact canonical claim
  evidence;
- evidence digest, App/helper identity, nonce, audit session, UID and release
  deadline mismatches fail closed;
- nested field/domain/tag/length/order/trailing-byte mutations fail closed;
- replacing both evidence and its digest still fails when any selection-bound
  axis differs;
- the wire remains non-`Codable` and exposes no admission/continuity mint.

### iii-b2b-1a-1

- ownership observation revalidates exact inner PID/version/PPID/PGID/ASID/
  audit token and exact App identity/topology;
- initial/final installed-driver observations are complete and equal, not just
  nonzero digests;
- App/helper ESRCH and identity reuse prove original-identity absence;
- same identity alive or any unavailable/ambiguous read fails closed;
- L1 receipt mismatches and noncanonical claim evidence fail closed;
- cancellation and deadline expiry never mint terminal evidence;
- production factory constructs only the reviewed session and observers; and
- Debug/Release driver artifacts remain positive controls while all closed
  images remain negative.

## 6. Validation Funnel and Non-Claims

Each checkpoint uses:

```text
structural/source/scope RED
-> exact focused tests
-> affected Investigation tests
-> scripts/verify-contract
-> scripts/verify-investigation-boundaries
-> scripts/verify-app-release-boundaries when projections change
-> one clean staged-only serialized regression
-> independent implementation/verifier/cross-boundary review
```

Neither checkpoint runs `scripts/verify --full`, launches the installed App or
helper, uses real XPC, requests administrator authority, calls a model, accesses
the network, emits a final cohort artifact, enables Deep Dive or claims machine
readiness. Those remain ordered as iii-b2b-1b -> ii-c0b -> ii-c -> L3c3d ->
L3c4.
