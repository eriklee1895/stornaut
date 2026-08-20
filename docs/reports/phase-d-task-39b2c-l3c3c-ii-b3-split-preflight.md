# Phase D Task 39B2c-L3c3c-ii-b3 App Adapter Split Preflight

> Status: Split frozen; ii-b3a complete; ii-b3b is the implementation frontier
>
> Date: 2026-08-20
>
> Baseline: `3c3100aae7ed653b62cb7097b81993ae7f759f86`
>
> Scope: documentation and current-source inspection only; no source/test/script
> implementation, real App/helper/XPC launch, install, sudo, model/auth use,
> serial regression or authoritative full verifier

## 1. Decision

The parent ii-b preflight correctly isolated App-side drop and no-auth retirement
from the helper claim client and the driver epoch. Its former thirteen-path /
3,400-line ii-b3 implementation unit is still too broad. It combines three
independently security-sensitive surfaces:

1. Darwin inherited-channel, root-peer and irreversible credential-drop effects;
2. a new Lifecycle start-to-retire-only state transition which must make App
   Server business I/O unrepresentable; and
3. the concrete App leaf/configuration composition and native artifact boundary.

The checkpoint is therefore frozen as:

`ii-b3a fixed-channel/root-peer/drop adapter`
-> `ii-b3b start-to-retire-only Lifecycle seam`
-> `ii-b3c concrete leaf/entrypoint composition`.

All three are non-admitting. They use injected/fake process and session effects
only. The real signed App, real helper/XPC, install, root execution, auth-source
observation, idle Codex child, network/no-model evidence and machine result remain
owned by ii-c/L3c3d/L3c4.

## 2. Current-Source Findings

### 2.1 Driver admission is fresh self-consistency, not an external SHA pin

`LifecycleMachineDriverAdmissionPolicy.authorize` is a strong creation-time
root-peer predicate. It requires an audit-token-consistent root identity, fixed
installed driver path, fixed signing identifier, strict static code validity,
live audit-token code identity and a second stable read of process identity,
path, signing evidence and live code identity. Static signing evidence includes
the actual executable SHA-256 read from the fixed executable.

It does **not**, however, accept an externally expected executable SHA-256 or
complete expected `LifecycleBundleSigningEvidence`. The policy proves that
the fixed current file and live peer agree and remain stable during admission; it
does not prove that the observed whole-file digest equals the driver digest frozen
in the cohort's signed-runtime binding.

This is intentional elsewhere in the design: the zero-argument driver cannot
embed its own whole-file digest without a circular build, and no independent
root-owned binding sidecar exists. The parent installed-driver preflight therefore
already assigns exact expected-SHA comparison to the later static binding/L2
joins, not to an implicit sidecar.

The App adapter preserves the accepted local-only trust model without upgrading
self-consistency into authenticity:

- before consuming STNP, ii-b3a requires the fixed creation-time root peer and
  captures the exact admitted static evidence;
- after receiving the strict configuration, ii-b3c strictly decodes its
  signed-runtime binding and requires its complete machine-driver binding to
  equal that captured evidence: executable SHA-256, signing identifier,
  designated-requirement SHA-256 and CodeDirectory hash, but records this only as
  an epoch-consistency join because both values arrive through the installed
  diagnostic topology; and
- ii-b3c independently canonical-encodes the decoded complete
  `SignedInvestigationRuntimeBinding` with exactly `.sortedKeys` and
  `.withoutEscapingSlashes`, hashes those bytes, and places that digest plus
  the exact configuration digest in the acknowledgement; b5/ii-c compare both
  only to the already-frozen capsule row.

The captured evidence is not a caller-minted Boolean and is never encoded into a
new handoff field. It is an in-memory one-epoch join only. It is **not** an
independent expected-SHA trust anchor: a stable root replacement could control
both the observed peer and configuration. Passing that same value to the policy
earlier would only move the circular comparison.

The independent authenticity predicate remains the ii-c prerequisite already
frozen by the installed-driver plan and ADR: before the sole root invocation, the
trusted local operator/current-source installer ceremony must bind built,
root-owned staging and installed artifact identity and repeat static installed-
artifact/service-bootstrap admission. ii-c then compares the driver's pre/post
observation with that frozen static binding and performs full installed L2 after
each App launch. b3 cannot claim that evidence because it performs no install or
machine run.

This is sufficient only for the explicitly accepted trusted-local-operator threat
model, whose adversary begins after root-owned topology establishment. It does not
resist a malicious administrator, malicious pre-install Coding Agent or arbitrary
same-UID mutation before installation. Extending that threat model requires a
distribution/notarization or exclusive root policy gate. Adding a sidecar,
argv/environment value, path-selected manifest or public expected-binding
parameter in b3 would require a new trust preflight and would not by itself create
independent provenance.

### 2.2 The inherited-FD runner must be directly asynchronous

The native diagnostic App already admits only fixed duplex Unix stream FD 7 and
invokes the package's no-argument public entry. The package state machine is an
actor whose `run()` is asynchronous, while the current public entry returns
status 78 synchronously. A blocking bridge would contradict the completed
direct-async/no-blocking work and can deadlock actor/XPC progress.

ii-b3c therefore changes the public signature only from synchronous
`() -> Int32` to directly asynchronous `() async -> Int32`. It remains
no-argument and exposes no descriptor, path, config, identity, authorization or
operation surface. The existing native harness is already async and can await it.

### 2.3 The current transport cannot express the required warm-start

`InvestigationLifecycleAppServerTransport.writeLine` and `readLine`
privately call `startIfNeeded()`, but both expose forbidden App Server
business I/O. `retireWithEvidence()` accepts the ready state and sends
`retire` immediately, so it does not prove a worker ever started. The
current diagnostic owner also turns an unused ready transport into
`retiredWithoutStarting`.

ii-b3b must add a dedicated one-shot method whose only successful request sequence
is exactly `start, retire`. It sends no write/read request and takes no line.
The API cannot contain or return a client capable of `prepareRoot`, auth
projection, initialize/login/thread/turn calls, or capability/model evidence.
Retirement must still validate `retiredOwnedResources`, fresh helper
attestation, exact handle, same-retire L1 zero evidence and one-shot Store transfer.

### 2.4 Configuration decoding is the binding join, not drop authority

The existing `InvestigationRuntimeDiagnosticAppLeaf` and
`SignedInvestigationRuntimeDiagnosticConfiguration` strictly decode the v3
configuration and required v2 binding, including required machine-driver binding.
The existing diagnostic composition independently observes the installed App,
helper and machine driver and matches the complete binding.

ii-b3c reuses those validators. It does not add a second JSON schema or weaken
strict unknown-field rejection. ii-b3a owns only fixed-channel/peer/drop effects;
ii-b3c owns configuration/binding acknowledgement and invokes the ii-b3b seam.

## 3. Frozen Cross-Checkpoint Contract

### 3.1 Fixed order

The concrete App path must execute this order and no other:

```text
admit FD 7 shape in native harness
-> read LOCAL_PEERTOKEN without consuming bytes
-> construct full peer LifecycleProcessIdentity
-> authorize fixed root driver and capture stable signing evidence
-> read exactly 32 STNP bytes and decode once
-> PRE_DROP_READY / DROP_RELEASE
-> initgroups -> verify groups -> setgid(20) -> setuid(501)
-> prove real/effective/saved IDs, groups, audit identity and failed root regain
-> DROP_EVIDENCE
-> receive/decode strict v3 configuration
-> join configuration machine-driver binding to captured peer evidence
   as epoch consistency only
-> CONFIGURATION_ACK / HELLO
-> Lifecycle start -> zero business lines -> retire
-> validate exact retirement evidence and produce handle
-> HANDLE / ACK / RELEASE / ALIVE / write EOF / EXIT
```

Any partial read/write, EINTR mishandling, deadline expiry, identity/path/signing
drift, group drift, failed credential transition, root-regain success, unknown
configuration field, binding mismatch, lifecycle request reordering, write/read
request, missing owned-resource retirement, stale helper evidence, nonzero L1,
duplicate/replay or post-terminal call fails the single epoch permanently.

### 3.2 Fixed identity drop

Target UID 501 and primary GID 20 remain compile-time constants. The adapter uses
bounded `getpwuid_r`/`getgrouplist` results and independently freezes
exactly the first `NGROUPS_MAX == 16` directory groups under the same fixed
algorithm as the parent. It calls
`initgroups`, compares the sorted actual supplementary group set, then calls
`setgid(20)` and `setuid(501)` in that order. It reports and validates
real/effective/saved UID and GID values, full supplementary groups, and exact
`EPERM` results for `setuid(0)`, `seteuid(0)` and
`setgid(0)`.

No parent-provided group list exists in the App protocol. The parent independently
observes and joins the same result later in b5/ii-c; b3a proves only the App's
fixed-algorithm result. No rollback exists. Any failure after the first credential
mutation exits the diagnostic path; it cannot retry or proceed with partial
credentials.

### 3.3 Channel and evidence ownership

FD 7 is the sole transport and is never duplicated into stdio, persisted,
encoded into JSON or selected by a caller. Reads/writes are exact-length,
deadline-bounded and retry only `EINTR`. The STNP payload contains the epoch
deadline, so it cannot govern the read needed to discover itself. After peer
admission, the adapter captures continuous time once, computes one checked fixed
bootstrap deadline of `now + 5_000_000_000` nanoseconds, and reads the exact
32-byte STNP under the minimum of that deadline and any independently injected
test cap. After strict decode it captures continuous time again and requires the
STNP absolute deadline to be strictly in the future and no later than the checked
bootstrap-start time plus `140_000_000_000` nanoseconds, matching the maximum
Task 38 wall-clock envelope. Every later operation uses the STNP deadline. An
unbounded first read, a payload-selected bootstrap timeout, an overlong epoch, or
equality at either deadline is forbidden. The adapter owns one channel and one
epoch. It does not close unrelated descriptors or inspect arbitrary endpoints.

Concrete FD waiting must not block Swift's cooperative executor or introduce a
semaphore bridge. The physical adapter uses a private bounded I/O executor or
dispatch source plus checked continuations; cancellation interrupts only owned FD
7 and the one-shot state becomes terminal. Tests inject the clock/readiness/syscall
surface and prove no continuation is resumed twice.

The pre-drop driver evidence is an in-memory, non-`Codable`, one-shot value.
It contains the admitted full process identity and actual stable
`LifecycleBundleSigningEvidence`; it is consumed by the configuration join
and cannot be provided through the public entry point.

## 4. Frozen Checkpoints

### 4.1 L3c3c-ii-b3a — Fixed Channel, Root Peer and Credential Drop

Implement closed concrete Darwin primitives later consumed by the already-pure App
leaf seam. b3a does not yet conform one partial object to the complete
`InvestigationHandoffAppLeafOperations` protocol; b3c owns that final join:

- validate and use only FD 7 after native shape admission;
- read `LOCAL_PEERTOKEN`, derive the complete root peer identity and run the
  fixed machine-driver admission policy before consuming STNP;
- retain the exact stable static driver evidence for the later binding join;
- exact bounded STNP/STNH read/write and half-close/EOF primitives;
- fixed UID/GID/group lookup and irreversible drop in the frozen order; and
- exact post-drop evidence including root-regain denials.

The policy needs a new result-returning admission API named to preserve the trust
classification, for example `authorizeAndObserveStableEvidence(_:)`, whose
existing `authorize(_:)` becomes a Boolean wrapper. The result must be
documented as peer-admission observation, not installer-authenticated provenance,
and created only after all existing first/second reads agree. It must not accept
expected identity/hash input and must not weaken helper callers that only need the
Boolean predicate.

Frozen ceiling: at most eight non-document paths and 2,200 added-or-changed lines:

1. `Sources/StornautLifecycle/LifecycleAppAuthorization.swift`;
2. `Sources/StornautInvestigationDiagnostic/InvestigationHandoffAppLeafAdapter.swift`
   (new);
3. `Tests/StornautLifecycleTests/LifecycleAppAuthorizationTests.swift`;
4. `Tests/StornautInvestigationTests/InvestigationHandoffAppLeafAdapterTests.swift`
   (new);
5. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
6. `scripts/verify-investigation-boundaries`;
7. `scripts/verify-app-release-boundaries`; and
8. `scripts/verify-contract`.

Approaching either ceiling or requiring a ninth path forces a new b3a split before
further implementation.

`Package.swift` remains unchanged because Diagnostic already depends on
Lifecycle and HandoffContract. Native harness, pure leaf, Runtime transport,
composition, Xcode graph and helper stay unchanged. Because b3a's concrete
adapter is deliberately not reachable from the native entry until b3c, b3a's
targeted build proves compile/link closure only; the final Debug Mach-O is not
required to retain dead adapter symbols yet.

Tests-first coverage must include every peer-token word/count/UID/PID/version/ASID
drift; fixed-path/static/live signing and second-read drift; expected-SHA absence;
FD/short-read/EOF/trailing/oversize/EINTR failures; exact five-second bootstrap
read bound, checked overflow, early/equal/late fire, post-decode expired epoch and
over-140-second deadline; cancellation/continuation races and no cooperative-
executor blocking; group count/order/set drift; proof that no parent group list is
accepted; each drop syscall failure; saved-ID/group mismatch; each root-regain
probe; partial/duplicate/post-terminal use; and structural absence of
argv/environment, paths/endpoints, persistence, public authorization inputs,
model/network/cleanup or readiness authority.

Validation: RED compile/behavior tests -> focused Lifecycle admission and App
adapter suites -> affected Lifecycle/Investigation suites -> exact structural and
contract mutation gates -> targeted Debug diagnostic compile/link smoke and
ordinary/release-shell absence gate (no positive final-Mach-O symbol claim before
ii-b3c makes the adapter reachable) -> one clean staged-only serial with all five
maximum benchmarks skipped -> independent review ->
implementation commit/push -> completion audit/docs commit/push. No App launch.

### 4.2 L3c3c-ii-b3b — Start-to-Retire-Only Lifecycle Seam

Add one package-scoped, one-shot Lifecycle transport operation which:

1. sends one validated `start` request from ready;
2. requires exact `started` response and active state;
3. sends no `write` or `read` request;
4. immediately performs the existing exact retirement operation; and
5. returns only `InvestigationLifecycleRetirementEvidence` after
   owned-resource, L1, helper and handle validation/store recording.

The seam may reuse private start/retirement internals but cannot be implemented by
calling `writeLine`, `readLine`,
`CodexInteractiveAppServerClient` or `prepareRoot`. Concurrent,
repeated and cancelled calls remain serialized and terminal. Start success
followed by retire failure is failure, never `retiredWithoutStarting`.
Because b3b's seam is not reachable from the native entry until b3c, b3b's
targeted build also proves compile/link closure only; positive final-image
retention belongs to b3c.

Frozen ceiling: at most six non-document paths and 1,500 added-or-changed lines:

1. `Sources/StornautInvestigationRuntime/InvestigationLifecycleAppServerTransport.swift`;
2. `Tests/StornautInvestigationTests/InvestigationLifecycleAppServerTransportTests.swift`;
3. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
4. `scripts/verify-investigation-boundaries`;
5. `scripts/verify-app-release-boundaries`; and
6. `scripts/verify-contract`.

Approaching either ceiling or requiring a seventh path forces a new b3b split
before further implementation.

Tests-first coverage must prove exact request kinds `[start, retire]`, zero
line bytes and no write/read requests; start/retire response identity joins;
expiry before/after suspension; cancellation at each suspension;
concurrent/repeated calls; helper freshness; owned-resource/L1/handle negatives;
Store one-shot; and source/final-Mach-O absence of `prepareRoot`, auth
projection, initialize/login/thread/turn, capability/model evidence and blocking
bridges in the seam.

Validation: RED focused tests -> complete transport suite -> affected
Investigation/Lifecycle suites -> structural/mutation gates -> targeted package
and Debug diagnostic compile/link smoke (no positive final-Mach-O symbol claim
before ii-b3c makes the seam reachable) -> one clean staged-only serial with five
maximum benchmarks skipped -> independent review -> implementation commit/push ->
completion audit/docs commit/push. No App/helper launch.

### 4.3 L3c3c-ii-b3c — Concrete Leaf and Native Entry Composition

Join ii-b3a and ii-b3b to the completed pure leaf:

- change the sole public no-argument entry to directly async;
- instantiate the one-shot concrete operations adapter internally;
- decode/validate configuration through the existing strict leaf and signed
  configuration types;
- require the decoded complete machine-driver binding to equal ii-b3a's admitted
  evidence before acknowledging configuration;
- construct the existing diagnostic composition in a narrow no-auth retirement
  mode backed by ii-b3b, consume its exact handle/evidence once, and never expose
  the broad App Server client/facade to the handoff adapter;
- await the pure state machine and map only terminal success/failure statuses; and
- keep the native harness responsible only for activation and fixed-FD shape
  admission before awaiting the no-argument entry.

The existing config-path diagnostic and product composition remain unchanged. A
dedicated internal factory may be injected for tests, but no new public initializer
or caller-supplied authorization fact is allowed.

Frozen ceiling: at most eleven non-document paths and 2,800 added-or-changed lines:

1. `Sources/StornautInvestigationDiagnostic/InvestigationHandoffAppLeaf.swift`;
2. `Sources/StornautInvestigationDiagnostic/InvestigationHandoffAppLeafAdapter.swift`;
3. `Sources/StornautInvestigationDiagnostic/InvestigationRuntimeDiagnosticComposition.swift`;
4. `StornautApp/Diagnostics/InvestigationRuntimeDiagnosticHarness.swift`;
5. `StornautAppTests/InvestigationRuntimeDiagnosticTests.swift`;
6. `Tests/StornautInvestigationTests/InvestigationHandoffAppLeafTests.swift`;
7. one new focused concrete-composition test file if required;
8. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
9. `scripts/verify-investigation-boundaries`;
10. `scripts/verify-app-release-boundaries`; and
11. `scripts/verify-contract`.

If ii-b3c needs to change the wire contract, Runtime transport, Lifecycle/helper,
Xcode graph/scheme, more than one new test file, or approaches this ceiling, it
must split again before continuing.

Tests-first coverage must include the full successful pure-leaf sequence through
the concrete factory; strict configuration/unknown-field/machine-driver hash,
signing and CDHash mismatches; admitted-evidence drift before acknowledgement;
independent canonical complete-binding digest computation and one-field binding
mutation versus capsule-commitment rejection;
exact handle/evidence join; every adapter/factory/state failure; one-shot and
post-terminal behavior; async entry result mapping; native activation/FD
admission; existing config-path behavior; and exact Debug diagnostic positive,
ordinary Debug/Release and dependency-free release-shell negative artifacts.

Validation: RED focused package/native tests -> full App leaf/transport/config
focused group -> affected Investigation and dedicated App tests -> structural and
mutation gates -> targeted Debug diagnostic build/test, release-shell build and
ordinary Debug/Release/final-Mach-O matrix -> one clean staged-only serial with
five maximum benchmarks skipped -> independent review -> implementation
commit/push -> completion audit/docs commit/push. This checkpoint still does not
launch the built App.

## 5. Shared Validation Discipline

Each sub-checkpoint consumes at most one valid staged-only serial. The standard
serial command is:

```sh
scripts/with-clean-validation-snapshot --staged -- \
  swift test --no-parallel \
  --skip '(cumulativeCatalogMatchingBenchmarkStaysBounded|completeCacheCatalogMatchingBenchmarkStaysBounded|completeCatalogMatchingBenchmarkStaysBounded|investigationSourceProjectionMaximumStreamingBenchmark|investigationCandidatePlannerHundredThousandRowBenchmark)'
```

An invocation that fails before creating its validation commit or before starting
SwiftPM is not a consumed serial. Once SwiftPM starts, its result is recorded and
is not rerun merely to obtain a green headline. Debugging uses the exact failed
case or stage only. `scripts/verify --full` remains forbidden before L3c4.

No sub-checkpoint may run install/uninstall, sudo, launchctl mutation, a signed App
or helper, a real XPC service, Codex/model/auth, public network, Trash/Executor, or
claim readiness. They may build and inspect targeted artifacts only.

## 6. Prompt-to-Artifact Checklist

| Obligation | Direct evidence required | Owner |
| --- | --- | --- |
| Fixed creation-time root peer before any byte | LOCAL_PEERTOKEN adapter tests plus Lifecycle admission result | ii-b3a |
| Actual fixed driver evidence is stable | first/second path/static/live signing equality tests | ii-b3a |
| Epoch driver SHA/signing consistency | strict configuration binding compared to captured admitted evidence; explicitly non-authenticating | ii-b3c |
| Independent expected driver authenticity | trusted current-source installer/static binding before root launch, pre/post driver equality and installed L2 | ii-c, not b3 |
| Exact FD 7 STNP/STNH and EOF behavior | concrete channel adapter tests and pure leaf sequence | ii-b3a/ii-b3c |
| Irreversible UID 501/GID 20/groups drop | syscall-order/evidence/regain tests in b3a; reachable Debug Mach-O positives in b3c | ii-b3a/ii-b3c |
| No-auth/no-business-line warm start | exact request trace `[start, retire]` and API/source negatives | ii-b3b |
| Owned retirement/L1/helper/handle evidence | transport behavior tests and one-shot Store join | ii-b3b/ii-b3c |
| Public surface remains one no-argument async entry | source/token structural test and native harness test | ii-b3c |
| Production/ordinary/Release boundaries stay closed | package graph, source recursion and final-Mach-O matrix | every checkpoint |
| No premature admission | no machine report/receipt/readiness state; ADR 0018 remains Proposed | every checkpoint |

## 7. Status and Next Gate

Independent read-only review traced the admission policy and executable SHA from
the installed file through all production callers, then separately reviewed the
accepted local-only threat model. It confirmed that b3 self-consistency plus ii-c
installer/static authenticity is the narrow correct routing and found no P0/P1.
Its two P2 documentation findings are closed here: configuration is described as
strictly decoded rather than independently sourced, and the result-returning API
is named and documented as stable peer observation rather than authentic
provenance. A separate scope/gate audit confirmed the three independent review
surfaces and the need to keep auth-capable normal composition outside the b3 seam.

The SHA audit requires no b3 prerequisite and no root-owned sidecar under the
accepted local-only threat model. It changes the split contract by explicitly
classifying b3's driver-binding comparison as epoch consistency, not independent
authenticity, and preserves ii-c's existing installer/static-binding requirement
as the first admitting trust anchor. The current Boolean admission policy must not
be described as an expected-SHA pin.

ii-b3a is complete; its fixed channel/root peer/drop adapter, exact gates, sole
1,234-test serial and final reviews are recorded in the
[ii-b3a review](phase-d-task-39b2c-l3c3c-ii-b3a-review.md). ii-b3b is next.
After ii-b3b and ii-b3c complete independently, the strict
Task 39 order resumes at ii-b4, ii-b5, ii-c0, ii-c, L3c3d and L3c4. ADR 0018
remains Proposed; Task 39 remains incomplete; production Deep Dive and real Trash
remain closed; and L3c4 alone owns machine readiness and the remaining
authoritative full verifier.
