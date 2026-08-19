# Phase D Task 39B2c-L3c3c-ii-b Handoff Composition Split Preflight

> Status: Parent split frozen; ii-b0 wire/budget details superseded; ii-b0a
> complete; ii-b0b current
>
> Date: 2026-08-19
>
> Baseline: `9a4c5565ce4b407bb1f9d360ef7b4c6a61e92858`
>
> Scope: documentation and current-source inspection only; no product
> implementation, App/driver launch, install, sudo, model/auth use, serial
> regression or full verifier

This document supersedes unsplit ii-b implementation routing in earlier
handoff/frontier text. The installed-driver path/cost preflight remains the
umbrella checkpoint; this is the authoritative ii-b execution order, budget and
validation reference.

## 1. Decision

The original twelve-path / 3,500-line ii-b checkpoint crosses six independent
security surfaces and cannot remain one reviewable change:

1. one shared binary capsule/frame/claim contract;
2. the authority-free App fixed-FD state machine;
3. the helper response, which currently echoes the opaque handle/token;
4. the concrete App identity-drop and no-auth warm-start/retirement adapter;
5. the root driver's fixed helper-claim transport; and
6. root-side fixed launch, identity joins and exact epoch process retirement.

The existing `InvestigationMachineDriverHost` and
`InvestigationLifecycleTopologyCollector` remain semantic oracles only. They
cannot be linked into the final driver: the complete Machine target pulls Core,
Codex, Investigation, Runtime and Lifecycle, while the native driver remains an
authority-closed DriverSupport binary. Dead stripping is not an authority
argument.

The strict order is:

```text
L3c3c-ii-b0a frame/capsule contract
-> L3c3c-ii-b0b claim/release wire contract
-> L3c3c-ii-b1 authority-free App inherited-FD leaf
-> L3c3c-ii-b2 handle-free helper response migration
-> L3c3c-ii-b3 concrete App drop/no-auth retirement adapter
-> L3c3c-ii-b4 fixed helper-claim client
-> L3c3c-ii-b5 fixed single-epoch driver composition
-> L3c3c-ii-c0 TTY/capsule launcher spike and invocation freeze
-> L3c3c-ii-c one no-model privileged machine gate
```

No ii-b checkpoint may install the topology, use sudo, launch the signed App,
authenticate or call a model, accept ADR 0018, claim readiness or consume the
remaining full verifier.

## 2. Current-Checkout Findings

### 2.1 The real App leaf does not exist

The dedicated diagnostic App currently activates only from one
`--stornaut-investigation-runtime-config=<absolute path>` argument, reads
`config.json`, prepares the composition, immediately retires it and writes a
filesystem receipt. It has no inherited-FD activation and does not remain alive
through installed-L2.

The inherited path must be separate and zero-argument; it must not weaken the
old preflight path. The diagnostic App native target remains exactly one source,
`InvestigationRuntimeDiagnosticHarness.swift`. New leaf code lives in the
existing SwiftPM diagnostic target and adds no Xcode source membership.

### 2.2 The helper response currently carries the handle

`LifecycleMachineRetirementClaimRequest` contains the handle, as required: the
already-authorized driver presents the one-shot capability to its original
helper. But `LifecycleMachineRetirementClaimResponse` embeds the complete
request, the root client requires `response.request == request` and the Machine
claimant repeats that check. The reply therefore contains the token again.

The admitted directions are instead:

- App -> driver: retirement handle over the inherited socket only;
- driver -> helper: one authorized claim request containing that handle; and
- helper -> driver: a request-binding digest plus evidence, never the request,
  handle, token or a reversible token projection.

### 2.3 Per-epoch retirement is not global post-teardown L2

Current `LifecycleRootTopologyObservation.postTeardown` requires the installed
App, helper, driver, plist, service and runtime roots to be absent. It cannot run
after every epoch of a single installed outer driver. Per epoch, a typed
`installedL2ObservedAt` barrier proves the exact App/helper/service identities at
that instant. After claim release, that helper identity exits and the observation
is historical; it is not continuously valid. Between epochs the launchd service
remains registered and activatable, but the helper process may be absent and is
not called loaded-valid. Before the next epoch, a new App activates a fresh
helper identity and the driver repeats full installed-L2. Only ii-c's final
bootout/uninstall may request global post-teardown L2. Historical synthetic
collector evidence is not relabelled; live composition simply does not reuse its
global step per epoch.

### 2.4 Zero-argument driver input needs a real invocation owner

The driver accepts no configuration path, behavior argv, environment-selected
input or caller endpoint. A cohort capsule can travel on standard input because
local `sudo(8)` documents that, without `-S`, authentication is read from the
terminal while stdin is inherited by the command; sudo also normally closes
descriptors above stderr. This is a documented candidate, not machine evidence.

The exact owner and invocation cannot remain implicit. ii-c0 must prove and
freeze a reviewed non-root gate executable that:

- creates and exclusively writes one fresh owner-UID-501 `0600` capsule;
- validates and seals its exact bytes, node identity, ACL/xattrs and digest;
- opens it read-only at offset zero, unlinks no live input before the attempt,
  maps only that held descriptor to sudo stdin and preserves the controlling
  TTY/stderr prompt;
- execs fixed sudo argv with no `-S`, askpass, shell, config path or environment
  override; and
- proves the root driver receives the same node at offset zero, reaches exact
  EOF, repeats final descriptor metadata, and binds the same digest.

No shell redirection or human-entered capsule path is admitted. ii-c0 is
non-root and non-model but gets its own source/binary/argv/env/FD preflight and
review before ii-c. The ii-c administrator prompt remains manual evidence.

### 2.5 No-auth lifecycle warm-start has a narrow candidate seam

The App does not need to call `CodexInteractiveAppServerClient.prepareRoot()`;
that method reads auth and sends initialize/login/thread-start. Instead it can
send one lifecycle `start` request and then `retire` without any App Server
business line. Current Swift `start` constructs the closed workspace/containment
and launches the App Server process without calling an auth projector or sending
initialize, login, thread or turn requests. That source trace does not prove the
idle child process never probes auth by itself. Retirement terminates/reaps the
process group, contains stderr and removes the workspace; the helper then records
L1 evidence and mints the handle.

ii-b3 must expose exactly this start/retire-only adapter, structurally reject
`prepareRoot`, auth projection reads and App Server write/read operations, and
use machine evidence to prove the auth file content/metadata are unchanged and
no admitted auth read or model/network event occurred. Until that evidence is
green, the seam is only a candidate and may not yield a real handle gate.

### 2.6 Successful claim needs an explicit installed-L2 release

The current helper preserves escrow after App disconnect and schedules a claim
deadline, but a successful claim reply does not terminate it. Waiting for the
full deadline between epochs would violate bounded composition and leave the
one-connection listeners unavailable.

The migrated fixed claim wire therefore adds one handle-free `CLAIM_RELEASE` and
an explicit deadline state machine. The helper owns one cancellable,
identity-bound claim-deadline work item. Successful claim atomically transitions
`awaitingClaim -> claimedAwaitingRelease`, cancels the original item and installs
one bounded release deadline before returning evidence. After receiving claim
evidence, the root driver keeps the same attested XPC connection alive,
completes installed-L2 and the repeated App identity join, then sends the
request-binding digest plus fresh release challenge. The helper atomically
consumes `claimedAwaitingRelease`, replies once, cancels the release deadline and
schedules a distinct successful-exit item only after reply dispatch. Any
already-fired timer race, early connection loss, release before installed-L2 on
the driver side, duplicate/foreign digest, release deadline or helper survival
beyond the bound yields terminal typed failure. No unconditional or untracked
`exit(0)` timer may remain. Launchd may start a fresh helper for the next epoch;
no listener or escrow state is reused.

## 3. Canonical Shared Contract

### 3.1 Fixed protocol direction and order

The historical B4 `HANDLE` was parent-to-child dummy spike data. It proved the
duplex transport algorithm, not the product handle direction. The product
protocol is explicitly directional:

```text
App -> driver  PRE_DROP_READY
driver -> App  DROP_RELEASE
App -> driver  DROP_EVIDENCE
driver -> App  CONFIGURATION
App -> driver  CONFIGURATION_ACK
App -> driver  HELLO
App -> driver  HANDLE
driver -> App  ACK
driver -> App  RELEASE
App -> driver  ALIVE
App -> driver  strict write EOF
driver -> helper  CLAIM(handle)
helper -> driver  CLAIM_EVIDENCE(no handle/token)
driver            installed-L2 timestamp barrier + repeated post-drop identity join
driver -> helper  CLAIM_RELEASE(binding digest, fresh challenge)
helper -> driver  CLAIM_RELEASED and bounded helper exit
driver            exact claimed-helper exit / no stale XPC-escrow-listener
driver -> App     EXIT
driver            epoch drain + reap-last + final driver self-observation
```

`CONFIGURATION/ACK` is pre-business. The business sequence remains
`HELLO -> HANDLE -> ACK -> RELEASE -> ALIVE -> EOF`. The installed-L2 timestamp
barrier occurs only after ALIVE/EOF and the helper claim; EXIT occurs only after
that barrier, claim release/helper exit and the repeated child identity join.
Unexpected EOF before the App half-close,
or any child write after it, is terminal.

The wire constants are closed:

- magic `0x53544e48` (ASCII `STNH`), version `1`;
- one 56-byte big-endian header: magic `UInt32`, version `UInt16`, kind
  `UInt16`, payload length `UInt32`, sequence `UInt32`, epoch UUID 16 bytes,
  monotonic deadline nanoseconds `UInt64`, PID/PID-version/EUID/ASID as four
  `UInt32` values;
- kinds/sequences `1...11` exactly in the frame order above:
  `PRE_DROP_READY`, `DROP_RELEASE`, `DROP_EVIDENCE`, `CONFIGURATION`,
  `CONFIGURATION_ACK`, `HELLO`, `HANDLE`, `ACK`, `RELEASE`, `ALIVE` and
  `EXIT`; and
- no extension/optional frame range in version 1.

`PRE_DROP_READY`, `DROP_RELEASE`, `HELLO`, `RELEASE`, `ALIVE` and `EXIT` have
zero payload. `CONFIGURATION` is `1...65,536` bytes. Every other payload has one
exact versioned fixed-binary shape and is at most 1,024 bytes. The decoder reads
the complete header and admitted payload or fails; it never allocates from an
unadmitted length.

### 3.2 Capsule and epoch commitments

The capsule is one fixed binary transcript, never JSON framing. Its header binds:

- domain separator `stornaut.task39.l3c3cii.cohort`;
- unsigned big-endian version;
- one random outer-attempt UUID;
- exact epoch count equal to the closed scenario count;
- whole-capsule SHA-256 field location and zero-before-hash rule; and
- exact ordered table of epoch ordinal, random epoch UUID, scenario raw value,
  configuration byte length, configuration SHA-256 and signed-binding SHA-256.

Version 1 requires exactly eight epochs in canonical
`SignedInvestigationRuntimeDiagnosticScenario.allCases` order, ordinals `0...7`,
one unique nonzero epoch/config UUID per row, `1...65,536` configuration bytes
per row and at most `1,048,576` bytes for the complete capsule. Hashes are raw
32-byte SHA-256 values in the binary transcript, never hex strings.

Each opaque configuration body immediately follows its table entry. Root code
validates only fixed binary structure, bounds, uniqueness, order and digests; it
does not decode configuration paths or business fields. After irreversible
drop, the App strictly decodes the configuration and returns
`CONFIGURATION_ACK` containing epoch UUID, ordinal, decoded config nonce,
scenario, configuration SHA-256 and binding SHA-256. The driver compares those
values only to the capsule commitment before accepting HELLO. Duplicate,
reordered, missing, foreign or mismatched epoch/config/binding facts consume the
outer attempt. ii-c evidence binds the exact whole-capsule digest.

### 3.3 Request-binding transcript

The claim binding is not JSON and not an unspecified canonical hash. Both
helper and driver compute SHA-256 over this fixed length-prefixed binary
transcript:

All contract transcripts in sections 3.3-3.4 use one common encoding. Bytes
begin with magic `0x53544e43` (ASCII `STNC`) as `UInt32` big-endian, followed by
fields encoded exactly as `UInt16 tag + UInt32 byteLength + payload`. Tag `0` is
the domain separator as bounded ASCII, tag `1` is version `UInt32` big-endian,
and business fields start at tag `2` and increase contiguously. No duplicate,
missing, reordered, zero-length (unless explicitly stated), unknown or trailing
field is allowed. Integers are unsigned/signed big-endian exactly as named;
UUIDs use their canonical 16 raw bytes; digests use raw 32 bytes.

```text
domain = "stornaut.task39.machine-claim.request"
version: UInt32 big-endian
token: raw UUID 16 bytes
investigationID: raw UUID 16 bytes
retireOperationID: raw UUID 16 bytes
configurationSHA256: lowercase ASCII 64 bytes
handleValidBefore: signed Int64 UTC microseconds big-endian
challengeNonce: raw UUID 16 bytes
issuedAt: signed Int64 UTC microseconds big-endian
requestValidBefore: signed Int64 UTC microseconds big-endian
claimConnectionEpochNonce: raw UUID 16 bytes
epochDeadlineNanoseconds: UInt64 big-endian
```

Every variable field is preceded by an unsigned big-endian byte length even
where the current version fixes that length. The wire owns these Int64
microsecond values directly; domain `Date` values are constructed from the
admitted integer and are never independently rounded during hashing. The handle
token appears exactly once
inside the hash input and never in the response. Field permutation, omission,
duplication, version drift, non-exact date precision or digest mismatch fails.

The connection-epoch nonce is generated once by the attested root client before
claim dispatch, is nonzero, and is echoed by claim evidence. The epoch deadline
uses system-wide `mach_continuous_time` converted to nanoseconds with an exact
`mach_timebase_info` ratio; overflow, saturation or a non-future value fails.
Wall-clock handle/config validity is checked independently and is never derived
from the monotonic value. The b3 handle validity is
`min(retirementNow + 30 seconds, configuration.validBefore)`, and claim request
wall validity may not exceed it.

### 3.4 Handle-free claim evidence transcript

Process identity uses domain
`stornaut.task39.machine-claim.process-identity`, version `1` and exact business
tags for role (`0x01` App or `0x02` helper), PID, PID version, ASID and EUID as
`UInt32` big-endian plus all eight audit-token words as one 32-byte payload.
Role is inside the transcript so App/helper records cannot be exchanged. The
process identity digest is SHA-256 of the complete transcript.

Owner retirement uses domain
`stornaut.task39.machine-claim.owner-retirement`, version `1` and exactly four
one-byte business fields: ownership `0x02` (owned), process-group terminated
`0x01`, stderr contained `0x01` and workspace removed `0x01`. No other
combination is admitting.

L1 residue uses domain `stornaut.task39.machine-claim.l1-residue`, version `1`
and exact business fields: investigation UUID, ASID `UInt32`, UID `UInt32`,
observed-at UTC microseconds `Int64`, remaining audit-session members `UInt32`,
matching leases `UInt32`, lease-root entries `UInt32` and investigation
artifacts `UInt32`. All four counts must be zero; investigation/ASID/UID and
timestamp must match the claim cohort and admitted window.

`CLAIM_EVIDENCE` uses domain `stornaut.task39.machine-claim.evidence`, version
`1` and exactly these business fields in order:

1. original request-binding SHA-256, raw 32 bytes;
2. original nonzero claim-challenge UUID, raw 16 bytes;
3. claim connection-epoch nonce, raw 16 bytes;
4. complete App process-identity transcript;
5. complete helper process-identity transcript;
6. App user ID, `UInt32` big-endian;
7. recorded-at UTC microseconds, `Int64` big-endian;
8. claimed-at UTC microseconds, `Int64` big-endian;
9. exact owner-retirement transcript;
10. exact zero-residue transcript; and
11. absolute `releaseDeadlineNanoseconds`, `UInt64` big-endian.

The complete evidence is bounded to 4,096 bytes. DriverSupport independently
hashes the nested helper identity for later release, while the current Lifecycle
client and Machine claimant compare the full nested identities and L1 facts to
their live/static expectations. Evidence contains no request, handle, token or
reversible token projection. Unknown/missing/reordered nested fields, wrong
role/challenge/epoch, nonzero residue, non-owned retirement, invalid timestamp or
digest mismatch fails closed.

### 3.5 Release request and response transcripts

The helper identity digest is SHA-256 over the common tagged-field encoding with
domain `stornaut.task39.machine-claim.helper-identity`, version `1` and these
fields in order: PID, PID version, ASID and EUID as `UInt32` big-endian, followed
by the eight audit-token words as eight `UInt32` big-endian values. It is
computed independently from the already-attested complete helper identity.

`CLAIM_EVIDENCE` echoes the request-binding digest and connection-epoch nonce,
binds that helper identity digest, and includes an absolute monotonic
`releaseDeadlineNanoseconds`. Successful claim atomically sets that deadline to
`min(claimNow + 5_000_000_000, epochDeadlineNanoseconds)` and requires a
strictly positive interval plus current wall time before handle/config validity.

`CLAIM_RELEASE` uses common tagged-field encoding with domain
`stornaut.task39.machine-claim.release`, version `1` and exactly these fields:

1. original request-binding SHA-256, raw 32 bytes;
2. fresh nonzero release-challenge UUID, raw canonical 16 bytes;
3. claimed helper identity digest, raw 32 bytes;
4. claim connection-epoch nonce, raw canonical 16 bytes; and
5. absolute `releaseDeadlineNanoseconds`, `UInt64` big-endian.

`CLAIM_RELEASED` is a distinct transcript with domain
`stornaut.task39.machine-claim.released`, version `1` and exactly:

1. the same request-binding SHA-256;
2. the same release-challenge UUID;
3. the same helper identity digest;
4. the same connection-epoch nonce;
5. `exitScheduled` as the single byte `0x01`; and
6. absolute `postReplyExitDeadlineNanoseconds`, `UInt64` big-endian.

The helper creates the exit deadline only when atomically consuming
`claimedAwaitingRelease`. It is
`min(releaseAcceptedNow + 5_000_000_000, epochDeadlineNanoseconds)` and must be
strictly after reply dispatch. The release window and post-reply exit window are
therefore each at most exactly five seconds. Both are additionally capped by the
stored wall-clock handle/config validity: acceptance after wall expiry fails,
and the scheduled exit cannot be later than the remaining wall interval. One
clock domain is used for all protocol deadlines; wall validity remains a
separate fail-closed cap.

Both transcripts use that common encoding in the listed order, with business
tags `2...6` or `2...7` respectively and no unknown/optional fields.
`CLAIM_RELEASED` must echo digest, challenge, helper and
connection epoch exactly; it contains no handle/token. Zero/stale/replayed
challenge, wrong connection epoch/helper identity, digest/deadline mismatch,
unknown version/tag, length drift, deadline overflow or timeout permanently
consumes the claim connection.

### 3.6 Fixed identity-drop source

Target UID `501` and primary GID `20` are compile-time constants, never capsule,
argv or environment inputs. Before spawn, root code uses `getpwuid_r(501)` and
requires exact UID/GID plus one bounded non-empty local username. It obtains the
directory group vector with one exact bounded `getgrouplist` call, requires the
measured 17 unique values and primary GID 20, preserves the directory-service
return order, freezes the first `NGROUPS_MAX == 16` entries, and only then sorts
that selected set for comparison. The App independently repeats the same bounded
lookup, calls `initgroups`, reads `getgroups(2)` and requires the sorted actual
set to equal the parent-frozen selected set before continuing to
`setgid(20) -> setuid(501)`. It then reports exact real/effective/saved IDs,
groups and three failed root-regain probes. The parent independently observes
IDs/groups and accepts the App report only as corroboration.

This is the local-machine ii-c contract. If account/GID/group membership drifts,
the gate blocks; it does not dynamically broaden the target identity.

### 3.7 Exact build-condition matrix

- ordinary App Debug and Release contain no inherited-FD activation symbols;
- dedicated diagnostic Debug contains the implementation and tests it;
- dedicated diagnostic Release intentionally excludes it because the existing
  source is guarded by `DEBUG && STORNAUT_INVESTIGATION_DIAGNOSTIC`; and
- ii-c uses the dedicated signed Debug App only.

No missing Release implementation may be described as runtime rejection.

## 4. Frozen Implementation Checkpoints

### 4.1 L3c3c-ii-b0 — Shared Wire and Capsule Contract (Superseded)

The exact byte-completeness audit found unresolved digest, nonce, payload and
transcript-join ambiguity before implementation. The authoritative replacement is
the [ii-b0 Wire Contract Preflight](phase-d-task-39b2c-l3c3c-ii-b0-wire-contract-preflight.md),
which splits this checkpoint into b0a and b0b and supersedes the budget, wire
layout and validation details below. The text below is retained only as the parent
split's historical input.

Create exact non-product package target `StornautInvestigationHandoffContract`
owning standalone strict binary capsule,
frame, retirement-handle, claim-request, request-binding and claim-response wire
projections. It may depend on Foundation and CryptoKit only. It owns the single
wire encoding after migration; Lifecycle, Diagnostic, Machine and DriverSupport
adapt to/from it. The leaf imports no Lifecycle types, Lifecycle depends one way
on the leaf, and two independently encoded wire schemas are forbidden.

The same target owns the one exact `@objc` machine-claim XPC selector surface
for `CLAIM` and `CLAIM_RELEASE`. It defines Data-only method signatures and no
connection/listener implementation. Helper and DriverSupport must import this
one interface rather than declaring duplicate Objective-C protocols.

The selector names/signatures are exactly:

```swift
func claimMachineRetirement(
    _ request: Data,
    withReply reply: @escaping (Data?, String?) -> Void
)
func releaseMachineRetirement(
    _ request: Data,
    withReply reply: @escaping (Data?, String?) -> Void
)
```

It contains no socket/XPC connection, Security lookup, filesystem, process,
signal, network, model or cleanup implementation. The claim response/release
wire has no request object, handle, token or reversible token projection.

Frozen ceiling: exactly nine possible non-document paths and at most 2,800
added/changed lines:

1. `Package.swift`;
2. up to three new shared-contract sources (three paths);
3. one focused shared-contract test source;
4. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
5. `scripts/verify-investigation-boundaries`;
6. `scripts/verify-app-release-boundaries`; and
7. `scripts/verify-contract`.

The maximum count is `1 + 3 + 1 + 1 + 3 = 9` paths.

The new target is unused by product targets in b0. Diagnostic, Lifecycle,
Machine and DriverSupport adapter/dependency migrations belong to b1, b2 and b4
respectively; b0 therefore changes no final product Mach-O.

Tests cover every frame/order/direction/bound, partial I/O codec state, capsule
ordinal/nonce/digest uniqueness, unknown versions, claim transcript field
permutation/omission/date precision and proof that response encoding contains no
token bytes. Claim evidence negatives cover nested role/identity/retirement/
residue/timestamp/bound drift. Release codec negatives cover zero/stale challenge, wrong helper or
connection epoch, digest mismatch, unknown version/tag, length drift and
deadline overflow. No concrete helper/XPC/App behavior changes here.

### 4.2 L3c3c-ii-b1 — Authority-Free App Inherited-FD Leaf

Add one package-scoped injected state machine under the existing diagnostic
target. It activates only with zero behavioral arguments and compile-time
descriptor `7` admitted as connected `AF_UNIX/SOCK_STREAM`. No environment,
config path, filesystem probe, XPC/Mach service or caller endpoint selects it.
Parent validation, drop, config decoding, handle production and I/O are injected
operations. After ALIVE it accepts only EXIT or terminal transport loss.

Frozen ceiling: at most nine non-document paths and 1,900 added lines:
`Package.swift` adds only Diagnostic -> HandoffContract; one new diagnostic
source; the one-source harness; App tests; at most one SwiftPM focused test;
target-boundary test; and the three boundary verifiers. Xcode project/scheme,
Runtime, Lifecycle, Machine, DriverSupport and composition remain unchanged. The
native App target remains exactly one source.

Gates include RED-first full frame/order/replay/deadline/partial-I/O/EOF tests,
dedicated Debug App tests/build, exact Debug presence and dedicated Release plus
ordinary Debug/Release absence, one clean staged-only serial and independent
review.

### 4.3 L3c3c-ii-b2 — Handle-Free Helper Response

Migrate escrow, helper endpoint, current Lifecycle root client and Machine
claimant to the shared wire, including `CLAIM_RELEASE`. Authorization remains
before escrow consumption.
Helper and client independently recompute the request binding. Old schema,
digest/challenge mismatch, replay, timeout, cancellation, connection-epoch drift
or outcome ambiguity fails closed. Release is admitted only on the same attested
connection epoch after one successful claim. The original claim deadline is a
cancellable work item atomically replaced by a release deadline; release
atomically cancels that deadline and schedules bounded helper exit only after
reply dispatch. Deterministic tests cover original deadline versus claim, claim
reply versus release, release reply versus exit, cancellation/invalidation and
already-fired races. The helper gains no launch/config/cleanup or success-retry
authority. Tests assert the exact five-second constants and that observed helper
disappearance is no later than the acknowledged post-reply exit deadline.

Frozen ceiling: exactly twelve possible non-document paths and at most 3,000
changed lines: `Package.swift`; escrow; current Lifecycle XPC; helper main;
Machine claimant; focused escrow, Machine-claim XPC and Machine claimant tests;
Machine target-boundary test; and the three boundary verifiers. Only affected
helper/current-client/Machine projections run; the complete diagnostic bundle
gate remains ii-b5.

### 4.4 L3c3c-ii-b3 — Concrete App Drop and No-Auth Retirement Adapter

Bind the injected leaf to the concrete diagnostic App. It validates the
creation-time root parent, performs the fixed identity drop, strictly decodes
and acknowledges the configuration, then uses a new start/retire-only
composition seam:

1. send one Lifecycle interactive `start` to create the contained App Server
   process/workspace;
2. send no App Server line and never call `prepareRoot`, auth projection,
   initialize, login, thread or turn APIs;
3. immediately send Lifecycle `retire`;
4. require `retiredOwnedResources`, same-retire L1 zero, fresh helper identity
   and the exact handle; and
5. send the handle App->driver, then remain alive through RELEASE/ALIVE/EOF/EXIT.

Frozen ceiling: at most thirteen non-document paths and 3,400 changed lines:
one concrete App adapter; diagnostic composition; Investigation lifecycle
transport; harness; App tests; focused transport/composition/Lifecycle tests;
Machine target-boundary test; and the three boundary verifiers. No root-side
spawn, signed-App execution, auth read or model call occurs in this checkpoint.
Structural tests fail on `prepareRoot`, auth projector, App Server write/read or
capability-evidence references in this seam. Unit tests use an injected fake
contained executable/session. The real signed App/real Codex idle-child auth,
network and no-model observations belong to ii-c, not b3.

### 4.5 L3c3c-ii-b4 — Fixed Helper-Claim Client

DriverSupport cannot reuse the broad Lifecycle XPC file and cannot pretend the
shared wire opens a connection. Add a DriverSupport-owned fixed one-shot
NSXPC client/attestation adapter that selects only
`com.eriklee.stornaut.lifecycle.machine-claim` at compile time. It pins the
installed helper path and complete static/dynamic signing identity, dispatches
exactly one claim, keeps the connection alive until installed-L2 completes,
then sends `CLAIM_RELEASE`, requires `CLAIM_RELEASED`, observes bounded exact
helper exit plus absence of stale connection/escrow/listener state, and
invalidates locally so launchd may start a fresh helper for the next epoch.
Outcome ambiguity after either dispatch is terminal. The next epoch must attest
a different fresh helper process identity and repeat full installed-L2.

Frozen ceiling: at most ten non-document paths and 2,800 changed lines across
`Package.swift` adding only DriverSupport -> HandoffContract, up to two
DriverSupport sources, focused fake-client tests, target-boundary tests,
Xcode framework settings only if required and the three boundary verifiers.
Positive final-Mach-O controls cover the exact Mach service,
NSXPCConnection, audit-token/Security checks, exactly one claim plus one release,
delayed invalidation, helper exit and outcomeUnknown. Caller-selected service/
path and general Lifecycle imports remain forbidden.

### 4.6 L3c3c-ii-b5 — Fixed Single-Epoch Driver Composition

Compose one injected or same-UID non-privileged epoch in the canonical order:

```text
initial installed-driver self-observation
-> admitted capsule/epoch commitment
-> unnamed socketpair + fixed App spawn on FD 7
-> two-stage identity join + CONFIGURATION/ACK
-> HELLO + App-to-driver HANDLE + ACK + RELEASE + ALIVE + strict EOF
-> fixed helper claim
-> installed-L2 timestamp barrier + repeated post-drop App identity join
-> handle-free claim release + bounded helper exit
-> no stale XPC/escrow/listener; next epoch requires fresh helper + fresh L2
-> EXIT
-> exact channel/App/descendant/PGID retirement + reap-last
-> final driver self-observation equal to initial
```

Tests inject OS operations or use non-privileged child processes. They do not
install, use sudo, launch the signed App/helper, authenticate a model or execute
the multi-epoch matrix. The result is opaque, non-`Codable` and non-admitting.

Frozen ceiling: at most twelve non-document paths and 3,500 changed lines across
DriverSupport entry, up to four sources, one or two focused tests,
target-boundary tests, three boundary verifiers and Xcode only if an explicit
system-framework link is unavoidable. Approaching the ceiling requires another
split.

Binary controls require exact Debug/Release undefined/load/owned projections;
socketpair/fixed-spawn/Security/libproc/BSM/read-only-stdin/wait/reap/signal
positive controls; arbitrary open/write/network/caller-XPC/cleanup-authority
negatives; required/forbidden/fixed-FD/argv/env/handle-echo mutation controls;
and the complete diagnostic bundle Mach-O allowlist.

### 4.7 L3c3c-ii-c0 — TTY/Capsule Launcher Spike

After b5, perform a fresh c0 scope/trust/cost preflight before implementation.
That preflight must select who authors the canonical configuration bytes and
how they enter a non-root gate without a caller path, environment-selected
input, generic launcher or second mutable mailbox. The current source has no
accepted answer, so this document inserts c0 but does not pretend its authoring
topology is frozen.

The selected c0 implementation must own capsule creation/sealing and exact sudo
argv construction. Use a deterministic non-privileged sudo-shaped stub to prove
stdin reaches the child at
offset zero, stderr/controlling-TTY plumbing is preserved and no extra FD/env/
argv survives; do not invoke real sudo, gain root, install or invoke the Stornaut
driver. Combine this only as design support with the local `sudo(8)` contract
that authentication uses the terminal when `-S` is absent. Freeze source/binary hash,
fixed argv/env/FD set, capsule node/digest lifecycle, signal forwarding and
post-command cleanup. If the measured platform does not preserve these facts,
stop and redesign before ii-c.

This checkpoint must not run sudo or use `sudo -v`, `-S`, askpass, shell, arbitrary
command/path, cached authority or a generic launcher product. It does not prove
that a real prompt occurred. The sole real sudo command remains ii-c and requires
the existing explicit user/Coding-Agent authorization plus manual prompt
observation. It proves gate-side exec/FD hygiene only and makes no claim about
real sudo preserving child stdin/TTY/FD behavior on this host.

## 5. ii-c and Later Non-Claims

Only after b0-b5 and c0 are independently committed/pushed may ii-c build and
install current source and consume one no-model outer installed-driver attempt.
ii-c owns the exact manual administrator prompt receipt and first real-sudo
transport observation, multi-epoch failure
matrix, installer-binding equality, per-epoch installed L2/process retirement,
one final bootout/uninstall/global post-teardown L2 and raw evidence review. Only
a wholly green result may accept ADR 0018. Real sudo stdin/TTY mismatch is an
explicit residual risk: it fails and consumes the unique started machine gate,
permits no retry, readiness or ADR acceptance, and is not reclassified as an
implementation surprise. Pre-driver policy/static-sudo checks may prove binary
identity and an operator-cancelled prompt path with no command/timestamp update,
but cannot prove child stdin; only the unique driver attempt observes that fact.

ii-c still cannot call a model or claim Task 39 readiness. L3c3d requires a fresh
scope/cost preflight before its one real authenticated Task 38 success. L3c4
alone owns readiness and the remaining authoritative full verifier.

## 6. Validation Accounting

Each implementation checkpoint follows:

```text
tests-first RED evidence
-> structural/source boundary
-> exact focused tests
-> affected suites
-> one clean staged-only serial regression
-> applicable targeted App/helper/driver/final-Mach-O gates
-> independent review
```

The broad `swift test --filter Investigation` selector remains forbidden. No
ii-b checkpoint runs `scripts/verify --full`. A failed staged serial is recorded
honestly and is not rerun merely for a green headline.

## 7. Prompt-to-Artifact Preflight Audit

| Requirement | Current-source evidence | Decision |
| --- | --- | --- |
| continue Task 39 without repeating ii-a | HEAD/origin at ii-a completion | satisfied |
| split before review ceiling | six independent trust surfaces plus b0 wire completeness audit | b0a/b0b/b1-b5/c0 frozen |
| no heavy Machine/Lifecycle graph in driver | package and final-Mach-O gates | mandatory |
| handle direct App->driver only | current helper-response echo identified | b0/b2 repair |
| canonical protocol order | ADR/study plus product direction audit | frozen |
| App alive through installed L2 | current harness exits immediately | b1/b3 repair |
| zero-argument driver/capsule invocation | sudo manual plus unresolved authoring/launcher owner | c0 preflight/evidence required |
| capsule bound to each epoch/config | no current live capsule | b0 contract |
| fixed UID/GID/groups | measured UID 501, GID 20, 17 directory/16 kernel groups | frozen fail-closed |
| concrete fixed claim client | current client trapped in broad Lifecycle file | b4 extraction |
| final self-observation | ii-a supports observation; current flow lacks second call | b5 required |
| no per-epoch global uninstall | postTeardown source semantics | final ii-c only |
| no auth/model in ii-b | start/retire seam inspected; prepareRoot excluded | b3 gate |
| exact build matrix | current DEBUG diagnostic guard | frozen |
| ADR 0018 Proposed; Task 39 incomplete; Deep Dive unavailable | active plan/product gate | preserved |

This preflight is non-admitting and consumes no serial, privileged or full-
verifier evidence.

## 8. Independent Review Closure

Three read-only review rounds found and closed:

- helper-response handle echo and heavy Machine/Lifecycle graph reuse;
- product frame direction/order, capsule-to-epoch binding and fixed UID/GID/
  returned-order-first 17-to-16 group semantics;
- exact request/evidence/release/released transcripts and common STNC encoding;
- claim-deadline versus release-deadline linearization and race cases;
- timestamped installed-L2, exact helper exit and fresh helper/full-L2 next epoch;
- final driver self-observation and exact build-condition/final-Mach-O gates;
- gate-side-only c0 evidence and real-sudo residual uncertainty; and
- active-router, path-budget and non-claim consistency.

Final parent-split review verdict: no unresolved P0–P2 at that scope. The later
wire-completeness preflight supersedes b0 details and closed its own iterative
review findings. No implementation, serial, App, privileged, model or full-
verifier action occurred.
