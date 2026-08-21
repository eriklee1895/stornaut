# Phase D Task 39B2c-L3c3c-ii-b5b-i Exact-Path Preflight

> Status: Trust, clock-domain and cost audit complete; ii-b5b-i split before
> coding; ii-b5b-i-a projection/temporal contract is current
>
> Date: 2026-08-21
>
> Baseline: `a3441612fa31636333620e717f2fe0b7529ecc7b`
>
> Scope: current-source and documentation inspection only; no source/test/script
> implementation, build, App/helper/XPC launch, install, root, model/auth/network,
> serial regression or authoritative full verifier

## 1. Decision

The original ii-b5b-i checkpoint cannot remain one implementation surface. The
only current full installed-L2 implementation spans the Lifecycle semantic
observer, Darwin readers, the Machine fixed-service probe and the broad Machine
collector join. Moving all of that plus the binary projection and DriverSupport
adapter would require approximately 13–15 non-document paths and 2,400–3,200
changed lines before compatibility and verifier repair. It would mix three
separate trust surfaces and approach or exceed the repository's 12-path review
ceiling. Copying any part into DriverSupport would create a second L2 owner.

ii-b5b-i is therefore frozen as:

```text
ii-b5b-i-a strict identity projection + dual-clock semantic contract
-> ii-b5b-i-b authority-closed fixed installed observer extraction
-> ii-b5b-i-c DriverSupport join + legacy-owner elimination/delegation
```

All three checkpoints remain non-admitting. This split changes no product scope,
protocol order, App target, installed topology or cleanup authority.

## 2. Current Ownership and Dependency Facts

There is one full installed-L2 implementation today:

- `Sources/StornautLifecycle/LifecycleRootTopologyObservation.swift` contains
  459 lines of phase, binding, observation-window, installed/post-teardown
  predicates and observer orchestration;
- `Sources/StornautLifecycle/DarwinRootTopologySupport.swift` contains 1,009
  lines of fixed path/node/hash/manifest/signing/process read-only evidence; and
- `Sources/StornautInvestigationMachine/FixedLifecycleServiceProbe.swift`
  contains 139 lines of fixed service and exact helper identity observation.

Those three files total the 1,607-line implementation cited by the parent split.
`InvestigationLifecycleTopologyCollector` adds the product-configuration, claim,
signed-binding and chronology joins, but also owns transition/post-teardown
behavior and depends on broad Machine/Investigation/Runtime/Lifecycle modules. It
is a semantic reference, not a reusable native-driver dependency.

The ii-a `InvestigationMachineInstalledDriverObserver` in DriverSupport proves
only the fixed driver executable and launchd manifest. It is not another full
installed-L2 implementation.

The accepted dependency direction is:

```text
StornautInvestigationHandoffContract        zero dependencies
        ↑
StornautInvestigationInstalledL2            future non-product target
        ↑
StornautInvestigationMachineDriverSupport   existing static product target
        ↑
StornautInvestigationMachineDriver          existing executable
```

The future installed-L2 target may use only HandoffContract, a separately
reviewed narrow read-only C identity target if required, Security.framework and
ServiceManagement.framework. It must not depend on Lifecycle, Machine, Core,
Codex, Runtime, ProcessSupport or Execution. Lifecycle/Machine may consume the
extracted target; the dependency must never point back upward.

The existing `CLifecycleSupport` object combines identity reads with signal
operations. The installed driver must not link that object and rely on dead
stripping. ii-b5b-i-b must either use pure Swift read APIs or introduce a narrow
read-only C target with no signal/process-control symbols.

## 3. ii-b5b-i-a — Projection and Dual-Clock Contract

ii-b5b-i-a owns only a strict binary contract in
`StornautInvestigationHandoffContract`. It does not add a producer, observer,
DriverSupport adapter, target dependency, App flow or production reachability.
The production projection remains deferred to the already-frozen non-root
strict-decoder integration in ii-c0.

### 3.1 Exact projection fields

The projection uses one domain-separated `HandoffBinaryTranscript`, canonical
tag order, canonical re-encoding and a zero-before-hash self digest. It contains
only configuration-derived identity commitments:

1. epoch UUID;
2. configuration nonce;
3. configuration wall-clock `validBefore` as positive UTC microseconds;
4. configuration SHA-256;
5. signed-runtime-binding SHA-256;
6. App executable SHA-256;
7. exact App bundle identifier `com.eriklee.stornaut`;
8. helper executable SHA-256;
9. exact helper service identifier `com.eriklee.stornaut.lifecycle`;
10. machine-driver executable SHA-256;
11. exact machine-driver signing identifier;
12. machine-driver designated-requirement SHA-256;
13. machine-driver CodeDirectory hash, exactly 20 or 32 raw bytes;
14. exact machine-claim service identifier; and
15. projection SHA-256.

App/helper designated-requirement and CodeDirectory hashes are deliberately not
projected: the current signed configuration does not contain those fields. They
remain facts independently observed by the concrete installed-L2 reader. The
projection contains no configuration body, path, opt-in, model/provider, output
path, handle, token, PID, UID, descriptor, endpoint or action.

The transcript version is the existing Handoff binary version. Unknown, missing,
duplicate, reordered, truncated, oversized or trailing fields, malformed UUID/
hash/identifier values, a noncanonical re-encoding or self-digest drift fail
closed. HandoffContract validates binary bytes only and performs no filesystem,
process, service, signing or product-JSON work.

### 3.2 Dual-clock semantics

The parent split's single expression
`claimedAt <= startedAt <= observedAt <= epochDeadline` mixed wall-clock UTC and
`mach_continuous_time` domains and is superseded by two independent chains. The
semantic contract freezes paired samples containing positive UTC microseconds
and continuous nanoseconds, and requires:

```text
claimEvidence.claimedAtUTC
    <= started.wallUTC
    <= observed.wallUTC
    < projection.configurationValidBeforeUTC

started.continuousNanoseconds
    <= observed.continuousNanoseconds
    < claimEvidence.releaseDeadlineNanoseconds
    <= epochDeadlineContinuousNanoseconds
```

No conversion or comparison crosses the two clock domains. Equality is accepted
only at the two same-domain lower-order boundaries shown above. Wall expiry,
release expiry and epoch expiry are strict. Zero, rollback, overflow, foreign
projection/epoch or inconsistent release/epoch deadlines fail closed.

### 3.3 Frozen scope and budget

Exactly five non-document paths and at most 1,200 added-or-deleted lines:

1. new `Sources/StornautInvestigationHandoffContract/InvestigationInstalledL2ProjectionContract.swift`;
2. new `Tests/StornautInvestigationTests/InvestigationInstalledL2ProjectionContractTests.swift`;
3. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
4. `scripts/verify-investigation-boundaries`; and
5. `scripts/verify-contract`.

`Package.swift`, App/Diagnostic, Lifecycle, Machine, DriverSupport and Xcode do
not change. Needing a sixth path or approaching 1,200 lines forces a new split
before coding. This contract checkpoint may use focused Handoff tests and exact
structural/mutation/scope gates; it makes no final-Mach-O claim.

## 4. ii-b5b-i-b — Authority-Closed Observer Extraction

ii-b5b-i-b will receive its own fresh implementation preflight after i-a. Its
provisional ceiling is 12 non-document paths and 3,500 changed lines. The
candidate surface is:

- `Package.swift`;
- a new non-product `StornautInvestigationInstalledL2` target;
- an optional new `CInvestigationIdentitySupport` source/header containing only
  read-only identity operations;
- separate semantic, artifact and process/service observer sources;
- one DriverSupport installed-L2 adapter source;
- focused tests plus TargetBoundary and the two structural verifiers; and
- at most one compatibility/removal path.

i-b must prove fixed paths/services, race-resistant descriptor/node/hash reads,
static/live Security identity, exact App/helper process identity, the eight
artifact roles, installed-phase predicates and dual-clock sampling. It accepts no
caller-selected path, PID, label, descriptor, signing requirement or syscall. It
performs no install, bootout, launch, signal, cleanup, XPC, model or network work.

If a single compatibility/removal path is insufficient, i-b must split before
coding rather than temporarily claiming there is one L2 owner.

## 5. ii-b5b-i-c — Driver Join and Legacy Owner Closure

ii-b5b-i-c will receive a fresh exact-path preflight after i-b. Its provisional
ceiling is 10 non-document paths and 2,500 changed lines. It owns only:

- the one-shot DriverSupport join from projection + claim evidence + repeated
  App identity + extracted observer to opaque non-`Codable` L2 proof;
- migration/delegation of the old Lifecycle/Machine installed branch;
- retargeting the four existing installed-L2 test/support owners; and
- structural proof that exactly one installed-phase contract/observer remains.

The old Machine collector may continue composing installed evidence with its
historical transition/post-teardown flow, but must delegate installed validation
to the extracted target. No copied product schema, copied phase predicate or
parallel physical reader may remain.

## 6. Tests-First and Structural Gates

ii-b5b-i-a RED tests cover:

- exact golden bytes, canonical round trip/re-encoding and self digest;
- every header/domain/version/tag/order/length/trailing-byte mutation;
- each projected commitment independently;
- zero UUID, malformed lowercase digest, 20/32-byte CDHash and fixed identifier
  boundaries;
- absence of configuration body, paths, model/provider, handle/token and raw
  authority inputs; and
- every dual-clock equality, rollback, strict-expiry and deadline-order edge.

Structural gates prove HandoffContract and the focused contract source contain no
product JSON decoder, `SignedInvestigationRuntimeDiagnosticConfiguration`,
`SignedInvestigationRuntimeBinding`, copied Diagnostic schema keys, filesystem/
process/service APIs, readiness/report/receipt or Execution authority. Mutation
controls must reject public/Codable widening, JSON imports, caller-selected raw
authority, self-digest bypass, noncanonical decoding and scope/budget drift.

i-b and i-c later cover the full artifact/process/service/binding matrix, exact
App/helper identity joins, one-shot/cancellation behavior, observer-only proof
minting and single-owner migration. Existing Lifecycle physical tests are moved
or retargeted, not duplicated.

Each implementation checkpoint follows structural -> focused -> affected -> one
clean staged-only serial -> applicable artifact gate -> independent review. No
b5b-i subcheckpoint runs the installed App/helper, real XPC, install, root
external execution, model/auth/network or `scripts/verify --full`.

## 7. Non-Admission and Remaining Order

This preflight is documentation-only and consumes no serial. ii-b5b-i-a/b/c are
non-admitting prerequisites. ADR 0018 remains Proposed, Task 39 remains
incomplete and production Deep Dive remains `.implementationUnavailable`.

The strict remaining order is:

```text
ii-b5b-i-a -> ii-b5b-i-b -> ii-b5b-i-c
-> ii-b5b-ii -> ii-b5b-iii -> ii-c0 -> ii-c -> L3c3d -> L3c4
```

ii-c0 still owns production projection creation/integration plus fresh capsule/
TTY/launcher evidence; ii-c alone may accept ADR 0018; L3c4 alone owns machine
readiness and Task 39's remaining authoritative full verifier.
