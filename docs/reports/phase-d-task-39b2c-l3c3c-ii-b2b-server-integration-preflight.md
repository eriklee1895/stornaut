# Phase D Task 39B2c-L3c3c-ii-b2b Server Integration Preflight

> Status: Mandatory target/client/server split frozen before code
>
> Date: 2026-08-19
>
> Baseline: `41c03563cb4a58b5f6db6525e7d4f7d26044fb58`
>
> Scope: migrate the helper-side machine-claim path to the shared STNC wire and
> the completed ii-b2a state primitive without adding the future fixed client,
> running a helper/App, installing, using privilege, calling model/auth, claiming
> readiness or consuming the remaining full verifier

## 1. Why ii-b2b Must Split Again

The parent ii-b2 scope assumed one 12-path / 3,000-line migration of escrow,
helper endpoint, broad Lifecycle client and Machine claimant. Later preflights
closed two design contradictions that invalidate that cost/ownership model:

1. broad `StornautLifecycle` must not depend on
   `StornautInvestigationHandoffContract`, because the ordinary App links
   Lifecycle; and
2. ii-b4, not ii-b2b, is the sole owner of the fixed retained-connection NSXPC
   client, helper signing/path admission, claim/release dispatch and helper-exit
   observation.

Current source also contains two legacy facts that cannot survive a one-step
switch:

- `LifecycleMachineRetirementEscrow` consumes immediately after a JSON v2 claim
  and has no release state; and
- `InvestigationMachineDriverHost.production` directly constructs the broad
  Lifecycle `LifecycleMachineClaimXPCClient`.

Switching the helper to STNC while leaving that concrete client callable would
create a compiled path that can only speak the rejected protocol. Adding a new
client here would instead violate ii-b4 ownership. The implementation order is
therefore:

```text
ii-b2b-i    server target + strict translation + injected effects, not connected
ii-b2b-ii   quarantine legacy concrete client; Machine production explicitly unavailable
ii-b2b-iii  link helper only; migrate live escrow/server/timers/reply ordering
```

This preflight supersedes parent ii-b2 §4.3's path/line ceiling, its requirement
to migrate the current concrete client to the new wire, and only the ownership
of the physical observed-helper-disappearance completion row. That machine
observation requires the retained client and is transferred uniquely to ii-b4.
ii-b2b must instead prove that its injected terminal action becomes due no later
than the acknowledged post-reply deadline. Every wire, authorization, deadline,
fail-closed, review, validation and other non-claim requirement remains in force.
ii-b4 remains the only future concrete client implementation and the sole owner
of observed helper disappearance.

## 2. Frozen Link and Ownership Topology

The accepted dependency graph is one-way:

```text
StornautLifecycle -----------------------------> CLifecycleSupport
        ^
        |
StornautInvestigationMachineClaimServer ------> StornautInvestigationHandoffContract
        ^
        | public SwiftPM static library product
        |
Xcode StornautLifecycleHelper only
```

`StornautInvestigationMachineClaimServer` is a new package target and static
library product. It depends exactly on `StornautLifecycle` and
`StornautInvestigationHandoffContract`. It owns the sole shared-wire-to-state
translation and effect executor. Lifecycle continues to depend exactly on
`CLifecycleSupport`; HandoffContract remains the sole STNC codec owner; the
ii-b2a source remains the sole deadline-state owner.

Only the Xcode `StornautLifecycleHelper` target may link the server product. The
ordinary and diagnostic App **main Mach-Os**, dependency-free Release shell,
native driver and DriverSupport must not link or contain server symbols. The
ordinary and diagnostic App bundles may contain the same nested helper binary;
bundle-recursive absence is therefore not a valid assertion. Artifact gates must
distinguish each main Mach-O from the nested helper.

The server target must never be a dependency of `StornautLifecycle`,
`StornautInvestigationDiagnostic`, `StornautInvestigationMachineDriverSupport`
or the native driver. SwiftPM Machine may import it only in an injected,
non-native test seam and may not gain a second concrete client.

## 3. Public Surface and Secret Boundary

The helper is an external Xcode target, so the server product needs a narrow
public façade. Public signatures may expose only:

- bounded `Data` request/reply values;
- already-admitted public Lifecycle peer/escrow objects;
- closed public clock, scheduler, scheduled-handle and terminal-effect protocols;
- closed, privacy-safe service/terminal result enums; and
- an XPC interface/service factory added only in ii-b2b-iii.

Public API must not expose HandoffContract package types, ii-b2a private
contexts, a raw retirement token, token hash, path, signing requirement, auth,
configuration bytes, arbitrary executable/signal, Policy, Trash or Executor. A
`LifecycleMachineRetirementEscrow` object may cross into the façade; only the
same-package server target can invoke its package-scoped one-shot transfer. This
avoids publishing the token or an independently mintable reservation.

## 4. ii-b2b-i — Target, Translation and Injected Effects

### 4.1 Exact scope and cost

The post-review implementation plus honest mutation controls measured 2,924
non-document lines and therefore crossed the frozen 2,900-line ceiling by 24.
This is a mandatory pre-validation split, not permission to raise or compress
the original budget:

```text
ii-b2b-i-a1 sealed Lifecycle transfer + response-commit state
ii-b2b-i-a2 target/translation/effects + behavior/structural tests
ii-b2b-i-b  boundary/scope verifier + mutation controls
```

The first i-a staged serial later exposed two review P1s and one P2: callbacks
were outside actor ordering, injected external effects could synchronously wait
for that actor, and the server target could mint its own raw seed. Validation
tree `ec343a21011d0ec6a30f04402a2fcf0061c78ef4` is retained only as rejected
historical evidence and cannot satisfy completion. Closing those findings also
crossed the i-a review surface, so i-a is frozen as a1 then a2.

ii-b2b-i-a1 owns exactly four non-document paths, at most 900
added-or-changed lines:

1. `Sources/StornautLifecycle/LifecycleMachineRetirementEscrow.swift`;
2. `Sources/StornautLifecycle/LifecycleMachineRetirementEscrowDeadlineState.swift`;
3. `Tests/StornautLifecycleTests/LifecycleMachineRetirementEscrowTests.swift`;
4. `Tests/StornautLifecycleTests/LifecycleMachineRetirementEscrowDeadlineStateTests.swift`.

It adds the sealed one-shot escrow transfer plus claim/release response-commit
state only. It runs focused and Lifecycle affected tests plus independent review,
but no staged-only serial.

ii-b2b-i-a2 begins only from the pushed a1 completion tree and owns exactly five
non-document paths, at most 2,650 added-or-changed lines:

1. `Package.swift`;
2. new `Sources/StornautInvestigationMachineClaimServer/InvestigationMachineClaimServerAdapter.swift`;
3. new `Sources/StornautInvestigationMachineClaimServer/InvestigationMachineClaimServerEffects.swift`;
4. new `Tests/StornautInvestigationTests/InvestigationMachineClaimServerAdapterTests.swift`;
5. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`.

ii-b2b-i-b begins only from the pushed i-a2 completion tree and owns exactly two
non-document paths, at most 800 added-or-changed lines:

1. `scripts/verify-investigation-boundaries`;
2. `scripts/verify-contract`.

i-a2 owns server focused/affected tests, combined focused coverage and the
parent's sole staged-only serial after a1 is present. i-b may run the canonical source-contract mode,
the full boundary script, verifier mutation controls and independent review, but
must not repeat the SwiftPM serial. The server source contract tests in i-a stay
as a small independent positive control; i-b adds the parser-backed structural
gate, exact package/scope graph and executable negative mutations. All three commits
must be independently pushed before ii-b2b-i is complete.

Approaching either ceiling requires another split before coding. No Xcode project,
Lifecycle live escrow/XPC, helper main, Machine host/claimant, App, DriverSupport
or app-release verifier changes here.

### 4.2 Responsibilities

The target adds the static library product, but no product target consumes it.
An injected package initializer receives one opaque reservation seed for tests.
The completed ii-b2a core gains one narrow package method,
`rejectBinding(reservationID:)`, so an already-authorized server translation can
terminally report a handle/token/seed mismatch without minting a fake reservation
or maintaining a second terminal state. It accepts only the exact live
reservation, is idempotent after terminal, schedules no work and returns the
existing typed `.bindingMismatch` transition. An armed current ticket produces
one cancel effect. A pending ticket produces that cancel and also records late-
arm cleanup, so a later stale `armSucceeded(ticket)` returns the exact cancel
again when the physical handle arrives. Empty/foreign reservation calls are
stale and cannot create or alter state; a repeated terminal call is stale, has no
effect and cannot replace the original terminal reason. No other ii-b2a state or
public surface changes. The direct Lifecycle test owns pending/armed/foreign/
terminal/effect semantics; server tests prove seed mismatch invokes this seam
without a shadow terminal state; the structural gate freezes both ownerships.
The same source gains one callback-bound package method,
`rejectObservation(ticket:)`, for the executor case where the injected clock
cannot produce any valid observation and therefore cannot legally call
`deadlineFired`. Only the exact current complete ticket may terminate as
`.invalidTimeObservation`: an armed ticket returns one cancel; a pending ticket
returns cancel and records late-arm cleanup. Replaced, foreign and terminal
tickets are stale with no effect and cannot kill a newer generation. The
executor must pass the callback's captured complete ticket, never only a
reservation ID. This keeps clock failure in the sole state owner without
weakening ticket replay identity or creating an executor-side terminal truth.
Direct Lifecycle and server executor tests freeze the seam.
The same source also gains one distinct operation-bound package method,
`rejectOperationObservation(reservationID:)`, for a clock failure while an
adapter claim, release or reply-dispatch operation owns the exact live
reservation but has no callback ticket to present. Only that exact nonterminal
reservation may terminate as `.invalidTimeObservation`; pending/armed cleanup
and late-arm memory are identical to `rejectBinding`. Empty, foreign and
terminal calls are stale and cannot create or replace state. The adapter must
apply this transition before returning `.unavailable` from any of those three
operations. Callback failures remain exclusively ticket-bound through
`rejectObservation(ticket:)`; the operation seam must never be used by a
scheduler callback. Direct Lifecycle tests freeze exact/foreign/empty/terminal,
pending/armed cancellation and late-arm behavior.

Post-serial review rejected actor-stack serialization: synchronous external
`schedule`, `cancel` or terminal callbacks could wait for the occupied adapter
actor, and a deadline callback could terminalize Lifecycle after an adapter phase
guard but before response bytes returned. The corrected adapter is therefore a
package final class with no whole-session actor or mutex. A narrow evidence lock
protects only immutable evidence publication/read/rollback and is never held
across clock, scheduler, handle, terminal or Lifecycle calls.

Lifecycle remains the sole session linearization owner. It adds two explicit
response-commit transitions after the corresponding bytes are fully built:

- arming a release ticket enters internal/public
  `claimResponsePendingCommit`; `commitClaimResponse` binds the exact reservation
  and connection epoch before release becomes legal;
- accepting release enters `releaseResponsePendingCommit`;
  `commitReleaseResponse` binds reservation, connection epoch and release
  challenge before reply-dispatch becomes legal.

Evidence is published before claim commit so an early concurrent release reaches
the state owner; failed commit rolls back that exact evidence. Callback or
reentrant operation first means the response commit is stale and no success bytes
return. Commit first means any later timeout/invalidation is explicitly after the
logical response commitment. `replyDidDispatch` itself is already called only
after the physical reply closure returns, so its state transition is the logical
commit; a post-reply due callback after that commit is valid, while synchronous
arm failure still makes the method unavailable. Controlled two-order state and
adapter tests cover claim-response/callback, release-response/reentry and
reply/post-reply ordering. External terminal-handler reentry is a positive test,
not a forbidden implementation convention. Sequential replay remains terminal
and fail-closed.

The opaque reservation seed carries the exact typed
`LifecycleInteractiveWorkerRetirementObservation` and
`LifecycleInvestigationResidueObservation` received from the escrow; it does not
replace them with Boolean or count summaries. Seed admission requires the exact
owned-retirement four-field tuple, `provedEmpty`, matching investigation UUID,
helper audit-session ID and App UID, a checked floor conversion of the residue
`Date` through `InvestigationHandoffUTCMicroseconds`, `observedAt <= recordedAt`,
and the existing maximum 60-second residue-to-record freshness window. The seed
stores the typed source observations and their one deterministic handoff
projection. Evidence construction uses only that projection. It must not call a
zero-argument owner projection or write literal zero residue counts without
first deriving and validating every field from those source observations.
Non-owned/prepared retirement, every nonzero residue dimension, foreign
investigation/ASID/UID, future/stale timestamps and invalid Date conversion fail
before reservation consumption.

Release translation compares the request digest, recomputed helper-identity
digest, connection epoch and release deadline directly against retained evidence
before entering the Lifecycle state. It must not call the HandoffContract API
with the received challenge as its own `expectedReleaseChallenge`; that is a
self-authenticating check. The release challenge is only required to be a valid
nonzero wire UUID at decode, while freshness against the claim challenge,
connection epoch and reservation UUID remains exclusively in the ii-b2a state.
The adapter must:

- strictly decode claim/release Data with HandoffContract;
- independently recompute the complete request-binding digest and helper-
  identity digest;
- compare token hash and all handle/investigation/retire/config/validity facts
  to the opaque seed without retaining raw request bytes;
- translate complete App/helper identity, owner retirement and L1 residue facts
  once into exact claim evidence;
- translate exact UTC microseconds and monotonic observations into ii-b2a values;
- build exact handle-free evidence/released bytes;
- retain one service/session connection epoch and reject reconnect/foreign epoch;
- apply typed schedule/cancel effects outside the state lock; and
- implement a ticket-keyed cancellation slot where a callback/cancel may win
  before the concrete scheduled handle is returned.

Each cancellation slot has four explicit facts: optional installed handle,
`cancelRequested`, `cancelApplied` and `callbackFinished`. A completed callback
removes a slot immediately when its handle is installed. If completion wins
before `schedule` returns, the slot remains only until install, then cancels the
late handle exactly once and removes itself. Cancellation follows the same
pending-install rule. Scheduler failure removes the slot before applying
`armFailed`. Normal due, early fire, clock failure, stale/replaced callbacks and
callback-before-handle must all converge to zero slots; callback completion and
handle cancellation are never inferred merely from a terminal state.

The façade has injected clock/scheduler/terminal protocols only. It does not use
`NSXPCConnection`, `NSXPCListener`, a Mach service, helper path/signing,
filesystem, process observation, install, model/auth, cleanup or direct exit. It
does not yet consume a live Lifecycle escrow.

### 4.3 Required tests and gates

- exact request bytes -> semantic claim -> exact evidence bytes;
- helper/adapter request-digest and helper-digest recomputation;
- evidence/released contain no handle/token or reversible token projection;
- release echo of digest/challenge/helper/connection/deadline;
- wrong domain/version/tag/order/length/trailing/old JSON v2 rejection;
- malformed request fails before state consumption; decoded handle/token/seed
  mismatch uses the exact `rejectBinding` transition;
- direct rejectBinding tests cover pending/armed cancel, late arm success,
  foreign/empty stale and terminal idempotence with no schedule effect;
- clock failure invokes exact ticket-bound `rejectObservation`; pending/armed/
  late-arm cleanup is preserved while stale/replaced tickets cannot terminate a
  newer state;
- claim/release/reply clock failure invokes exact operation-bound
  `rejectOperationObservation`, terminalizes the matching live reservation and
  cannot be retried; callback failure never uses that seam;
- seed negatives cover both non-owned retirement values, every nonzero residue
  count, foreign investigation/ASID/UID, future and over-60-second-old residue,
  the exact 60-second positive boundary and sub-microsecond floor projection;
- duplicate/replay/foreign epoch/helper/digest/deadline fail terminally;
- release challenges equal to the original claim challenge, connection epoch or
  reservation UUID reach the state and fail terminally; structural tests forbid
  self-challenge validation;
- cancellation-slot callback-before-handle, late handle, arm failure and stale
  callback matrix;
- normal armed due, armed clock failure, replaced old-ticket clock failure and
  callback-before-handle clock failure each prove one terminal delivery where
  applicable, exact late-handle cancellation and `pendingSlotCount == 0`;
- controlled concurrent claim/claim, claim/release and release/reply operations,
  both response-commit orders and synchronous terminal-handler reentry prove no
  pre-commit success/terminal window or callback-induced deadlock;
- pending/armed early callback and reply-dispatch order;
- package graph exactness, public-surface audit and no product consumer;
- focused coverage, affected Investigation/Lifecycle tests, one staged-only
  serial and independent review.

ii-b2b-i-a1, i-a2 and i-b are all non-connected/non-admitting. None alone completes
ii-b2b-i, and ii-b2b-i cannot complete ii-b2b.

## 5. ii-b2b-ii — Legacy Client Quarantine and Machine Block

### 5.1 Exact scope and cost

Exactly ten non-document paths, at most 3,000 added-or-changed lines:

1. `Sources/StornautLifecycle/LifecycleSupervisorXPC.swift`;
2. `Sources/StornautInvestigationMachine/InvestigationMachineRetirementClaim.swift`;
3. `Sources/StornautInvestigationMachine/InvestigationMachineDriverHost.swift`;
4. `Tests/StornautLifecycleTests/LifecycleMachineClaimXPCContractTests.swift`;
5. `Tests/StornautInvestigationTests/InvestigationMachineRetirementClaimTests.swift`;
6. `Tests/StornautInvestigationTests/InvestigationMachineDriverHostTests.swift`;
7. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
8. `scripts/verify-app-release-boundaries`;
9. `scripts/verify-investigation-boundaries`;
10. `scripts/verify-contract`.

No Package/Xcode/helper/server source is changed.

### 5.2 Responsibilities

Before the helper wire changes, remove the old broad Lifecycle concrete client,
reply resolver, concrete connection/signing/path logic and outcome transport.
The legacy one-selector protocol/service-name namespace may remain temporarily
only because the current helper still compiles against it; it must have no client
constructor, `NSXPCConnection` callsite or Machine consumer. ii-b2b-iii removes
the protocol after helper migration.

`InvestigationMachineDriverHost.production` must become explicitly
implementation-unavailable before creating a claimant or consuming a handle.
Injected Machine claimant/source/domain tests may remain as historical semantic
oracles, but there is no concrete XPC source, service selection, helper path/
signing admission or retry fallback. The unavailable state is typed and cannot
be mistaken for provider/transient failure.

The ordinary App Debug/Release **main Mach-O** must no longer carry the old
machine-claim concrete client/service-selection symbols through broad Lifecycle.
The helper still carries the legacy server until iii, so nested-helper negatives
are not used.

### 5.3 Required tests and gates

- no `LifecycleMachineClaimXPCClient()` or concrete `NSXPCConnection` owner in
  Lifecycle/Machine;
- Machine production factory fails typed unavailable before handle/claim/topology;
- injected claimant/store/topology oracle remains deterministic;
- old helper protocol has server-only ownership and no client proxy;
- no caller-selected service/path and no alternative concrete client;
- ordinary App Debug/Release main-Mach-O negative control;
- focused Lifecycle/Machine tests, affected suites, applicable targeted builds,
  one staged-only serial and independent review.

ii-b2b-ii remains non-admitting; the helper still uses the old server until iii.

## 6. ii-b2b-iii — Live Helper Server, Single Escrow and Timers

### 6.1 Exact scope and cost

Exactly fourteen non-document paths, at most 4,000 added-or-changed lines:

1. `Stornaut.xcodeproj/project.pbxproj`;
2. `StornautLifecycleHelper/main.swift`;
3. `Sources/StornautLifecycle/LifecycleMachineRetirementEscrow.swift`;
4. `Sources/StornautLifecycle/LifecycleSupervisorXPC.swift`;
5. `Sources/StornautInvestigationMachineClaimServer/InvestigationMachineClaimServerAdapter.swift`;
6. `Sources/StornautInvestigationMachineClaimServer/InvestigationMachineClaimServerEffects.swift`;
7. `Tests/StornautLifecycleTests/LifecycleMachineRetirementEscrowTests.swift`;
8. `Tests/StornautLifecycleTests/LifecycleMachineClaimXPCContractTests.swift`;
9. `Tests/StornautLifecycleTests/LifecycleInteractiveSessionContractTests.swift`;
10. `Tests/StornautInvestigationTests/InvestigationMachineClaimServerAdapterTests.swift`;
11. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
12. `scripts/verify-app-release-boundaries`;
13. `scripts/verify-investigation-boundaries`;
14. `scripts/verify-contract`.

This reaches but does not exceed the repository 14-path/4,000-line hard split
ceiling. Any additional non-document path or ceiling increase requires another
split before coding. Package.swift and every App/DriverSupport/native-driver
source remain unchanged.

### 6.2 Exact live ownership switch

The Xcode helper links the server product in Debug and Release. Its listener
continues to perform exact machine-driver path/static/dynamic signing and
complete peer identity admission **before** creating a server session. No
caller-supplied authorization Boolean crosses into the adapter.

The server target provides the HandoffContract two-selector XPC interface and
per-connection service object; it does not choose or open the service. One
accepted connection owns one service/session. First claim binds the request's
connection epoch; release must arrive on the same object with the same epoch.
Invalidation is delivered to that session exactly once.

The App retirement path still receives one public Lifecycle handle, but the
legacy escrow performs a package-scoped one-shot transfer of its complete entry
to the server adapter. After transfer:

- the adapter/b2a state is the only live claim/release owner;
- legacy claim APIs fail consumed/unavailable;
- helper route admission consults the server owner, not
  `retirementEscrow.isAwaitingClaim`; and
- helper code never writes both legacy and server states.

Handle/config and recorded timestamps have one checked UTC-microsecond
quantization owner. `LifecycleMachineRetirementHandle` moves to strict protocol
version `3`. Its authoritative encoded field is exactly
`validBeforeUTCMicroseconds: Int64`; `validBefore` remains a computed `Date`
projection only and is not a CodingKey or independently encoded value. The v3
field set is exactly protocol version, token, investigation ID, retire operation
ID, lowercase configuration SHA-256 and the integer. Unknown, mixed Date plus
integer, and v2 Date-based payloads fail strict decoding.

The sole Date-input conversion uses the approved checked rule
`floor(timeIntervalSince1970 * 1_000_000)`, rejecting non-finite, nonpositive or
out-of-`Int64` input. Sub-microsecond input is conservatively floored once. The
stored integer is the only JSON/STNC truth; reading `validBefore` never re-
quantizes it. Tests cover stable integer/Date projection, sub-microsecond
flooring, v2/mixed/unknown rejection, interactive retired-response round-trip and
exact equality with the Handoff handle integer. Old JSON machine-claim request/
response is rejected by the live server.

### 6.3 Physical scheduler and reply ordering

The helper owns the production clock, scheduled handles and terminal action.
Monotonic observations use `mach_continuous_time` with checked
`mach_timebase_info` conversion, exactly matching the wire domain. The scheduler
may use a cancellable `ContinuousClock` relative wait only after computing
remaining time from the exact continuous observation; every callback reads a
fresh observation and re-enters the b2a core, so early/late/suspend behavior is
never trusted from the scheduler alone.

Before arming can expose a callback, the server executor registers the ticket-
keyed cancellation slot. Pending cancellation is applied immediately when the
physical handle arrives. Exactly one claim, release or post-reply ticket is live.
The old unconditional global claim-deadline `asyncAfter { exit(0) }` and generic
success/failure exit timers are removed from the machine-claim path.

Claim success arms the release deadline before evidence reply. Release success
freezes the post-reply deadline and builds `CLAIM_RELEASED(exitScheduled=true)`
as a commitment. The service invokes the reply closure; only after it returns
does the adapter call `replyDidDispatch` and arm the retained deadline. If arm
fails after reply, no second reply/retry is allowed: the terminal handler takes
one fixed bounded failure-exit path.

### 6.4 Required tests and artifact gates

- unauthorized listener peer never decodes or consumes state;
- same-service claim/release and foreign/reconnect/duplicate negatives;
- malformed/old JSON rejected before transfer/claim;
- claim -> release timer replacement; release -> post-reply timer ordering;
- callback-before-handle, arm failure, cancellation/invalidation and already-
  fired races through the physical adapter;
- claim/release/post-reply equality and one-tick-before deadlines;
- wall rollback/forward jump, epoch/handle caps and checked conversion;
- success reply before exit arm, post-reply arm failure and one terminal action;
- injected terminal action is due no later than the acknowledged post-reply
  deadline; physical helper disappearance remains ii-b4 evidence;
- one live escrow/state owner and zero listener/timer-slot residue;
- no launch/config/cleanup/success-retry authority in server target.

Targeted Debug and Release helper builds plus final-Mach-O gates must prove:

- helper positive: server module, Handoff claim domains, two selectors and
  Lifecycle state/effect support;
- ordinary App main negative: server module and machine-claim client/service
  selection absent (nested helper is separately admitted);
- diagnostic App main negative for server module; existing App-leaf Handoff
  symbols are not misclassified;
- dependency-free Release shell negative;
- native driver and DriverSupport negative for server/Lifecycle XPC; and
- helper gains no Machine/Core/Execution/cleanup dependency.

The Xcode structural gate parses `project.pbxproj`: exactly one server product
reference, one matching PBXBuildFile and helper-framework membership, and exact
helper-only `packageProductDependencies`. Ordinary App, diagnostic App, Release
shell and native-driver product/dependency/framework allowlists exclude the
server. Existing schemes are source-sealed with unchanged build/run/archive
membership; no new helper/server scheme is added. Debug and Release helper
Mach-Os are positive, while the other main Mach-Os remain negative.

Run focused adapter/Lifecycle/helper tests, affected suites, coverage, structural
and artifact gates, one staged-only serial and independent review. Do not launch
the helper/App or invoke real XPC; live installed evidence belongs to ii-c/b4/b5.

## 7. Completion Boundary

ii-b2b completes only after all three sub-checkpoints are independently pushed.
At that point the helper server and state/timer owner are migrated, and the old
concrete client is quarantined, but no new client exists. ii-b4 remains the
future sole fixed client and b5 remains the first single-epoch composition.

Therefore ii-b2b does not prove a working end-to-end claim, installed-L2, physical
helper disappearance, next-epoch freshness or signed-App execution. The whole ii-b2 can
complete after ii-b2b because ii-b2a is already complete, but the strict next
order remains ii-b3 -> ii-b4 -> ii-b5 -> ii-c0 -> ii-c -> L3c3d -> L3c4. ADR
0018 remains Proposed until ii-c. Task 39 remains incomplete, Production Deep
Dive remains unavailable, real Trash remains closed and L3c4 exclusively owns
readiness plus the remaining authoritative full verifier.
