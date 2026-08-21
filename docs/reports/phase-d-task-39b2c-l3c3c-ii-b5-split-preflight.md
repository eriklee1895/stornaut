# Phase D Task 39B2c-L3c3c-ii-b5 Single-Epoch Composition Split Preflight

> Status: Split, ownership, scope and tests-first contracts frozen; ii-b5a0 is
> the current implementation checkpoint; non-admitting
>
> Date: 2026-08-21
>
> Baseline: `615b48376b017c6d0d17fa721591f77f30cb645a`
>
> Scope: documentation and current-source inspection only; no source/test/script
> implementation, App/helper/XPC launch, install, sudo/root/launchctl mutation,
> model/auth/network use, serial regression or authoritative full verifier

## 1. Decision

The parent ii-b split correctly assigns one complete driver-owned epoch to
ii-b5, but the live source proves that it no longer fits one reviewable
12-path / 3,500-line implementation surface. The native executable links only:

```text
StornautInvestigationMachineDriver
  -> StornautInvestigationMachineDriverSupport
       -> StornautInvestigationHandoffContract
```

`StornautInvestigationMachine` is a synthetic/machine-gate target with a broad
Core/Codex/Runtime/Lifecycle closure. Its `DriverHost` and topology collector
cannot be linked into the native driver or used as a production proxy. The
native DriverSupport target currently has no driver-side frame state machine,
socketpair/spawn/FD-7 runtime, App identity observer, installed-L2 adapter or
PGID reap-last implementation. Implementing all of those together is estimated
at 3,800–4,700 changed lines before verifier repair.

The parent instruction already requires another split when approaching its
ceiling. Independent review also found that claim-abort closure, installed-L2
extraction, physical root syscalls and production entry are separate trust
surfaces. ii-b5 is therefore frozen as:

```text
ii-b5a0 same-client claim-abort terminal proof
->
ii-b5a typed/injected single-epoch composer
-> ii-b5b-i authority-free identity projection + installed-L2 extraction
-> ii-b5b-ii fixed Darwin epoch runtime
-> ii-b5b-iii production entry + artifact composition
-> ii-c0 fresh launcher/TTY/capsule preflight
```

This changes no product scope or protocol order. It separates semantic ordering
from new root-capable physical syscalls so each review surface remains bounded.

## 2. Current-Source Facts and Reuse

The implementation must reuse, not duplicate:

- `InvestigationCohortEpoch`, the exact 32-byte STNP bootstrap and strict STNH
  frame codec from `StornautInvestigationHandoffContract`;
- the completed App-side FD-7 leaf, root-peer admission, irreversible drop and
  `start -> retire` handle production without changing the App target;
- `InvestigationMachineClaimClient` as the sole fixed helper claim/release
  transport, retained across installed-L2; and
- the ii-a installed-driver observer twice, requiring exact initial/final
  equality after process retirement.

The following are semantic references only and must not enter the native graph:

- `StornautInvestigationMachine.DriverHost` and
  `InvestigationLifecycleTopologyCollector`;
- `StornautLifecycle` root-topology implementation;
- generic `StornautProcessSupport` process-group authority; and
- Execution/Codex process launchers.

The capsule carries canonical configuration bytes and existing commitments.
Root DriverSupport treats the configuration body as opaque, as required by ADR
0018. It must not parse product JSON, mirror
`SignedInvestigationRuntimeDiagnosticConfiguration` or become a second schema
owner. ii-c0 may add one closed binary identity projection produced only after
the existing authoritative non-root strict decoder accepts canonical bytes.
HandoffContract may strictly decode that binary projection, while root code may
only join its digest/configuration/binding commitments against independent
App/helper/driver observations and the App acknowledgement. No sidecar, argv,
environment or caller-selected identity is permitted.

## 3. ii-b5a0 — Same-Client Claim-Abort Terminal Proof

The completed b4 client has one successful `claim -> release` path. ii-b5 adds
a new required failure boundary: after claim succeeds, installed-L2, repeated
App identity, cancellation or deadline failure must not send or simulate
`CLAIM_RELEASE`, but also must not abandon a live helper claim epoch.

ii-b5a0 changes claim admission to one client-owned `claimOrProveTerminal`
operation and adds same-client `abortAfterClaimAndProveTerminal`. It:

- is legal only from the retained claimed state and is mutually exclusive with
  release;
- invalidates the exact retained connection without sending release or retrying
  claim;
- proves the exact claimed helper identity absent before the existing bounded
  deadline and proves the local connection/client state permanently terminal;
- treats unknown connection/helper/escrow/listener outcome as terminal-residue
  uncertainty, never as success; and
- preserves the original caller error only after abort proof succeeds; abort
  uncertainty overrides it.

`claimOrProveTerminal` retains the attempt/session inside ClaimClient until its
terminal action is complete. A successful reply returns claimed evidence. A
known strict server rejection keeps its typed rejection. Reply loss, malformed
evidence or cancellation after dispatch first invalidates the exact retained
connection. If trusted evidence already identifies the exact helper, the client
may prove its absence; if no trusted exact identity exists, it returns typed
`terminalResidueUncertain` and must not call a wait/timeout a proof. No external
adapter can reconstruct the missing identity or upgrade uncertainty. No later
checkpoint may rely on an unobserved deadline timeout.

At most five non-document paths and 800 changed lines:

1. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineClaimClient.swift`;
2. `Tests/StornautInvestigationTests/InvestigationMachineClaimClientTests.swift`;
3. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
4. `scripts/verify-investigation-boundaries`; and
5. `scripts/verify-contract`.

Tests cover abort-before-claim, abort/release mutual exclusion, known-success
claim followed by each pre-release failure class, exact-helper survival,
connection/terminal ambiguity, cancellation, one-shot concurrency and failure
priority. Claim tests include reply loss after server acceptance, malformed reply
after acceptance and cancellation after dispatch. The App, helper/server, shared
wire, Package/Xcode and final-Mach-O matrix remain unchanged.

## 4. ii-b5a — Typed/Injected Single-Epoch Composer

ii-b5a owns the only canonical order and terminal semantics over typed injected
seams. It is package-scoped and unreachable from the native public entry until
ii-b5b supplies the physical composition.

```text
initial driver self-observation
-> start one epoch session for one admitted epoch
-> STNP
-> PRE_DROP_READY / DROP_RELEASE / DROP_EVIDENCE
-> CONFIGURATION / CONFIGURATION_ACK / HELLO / HANDLE
-> ACK / RELEASE / ALIVE / strict peer-write EOF
-> fixed helper claim on one fresh client
-> installed-L2 barrier + repeated exact post-drop App identity join
-> same-client claim release + bounded helper exit
-> EXIT
-> exact owned channel/process/PGID retirement and reap-last result
-> final driver self-observation exactly equals initial
-> completedNonAdmitting
```

The composer constructs every driver-to-App frame and validates every incoming
kind, sequence, direction, sender, epoch UUID, deadline and payload. It validates
the capsule row against configuration acknowledgement and retirement handle. It
converts the independently observed complete post-drop identity—not the four
frame fields alone—to `InvestigationMachineProcessIdentity`.
The capsule row supplies the epoch UUID but contains no monotonic deadline. The
composer observes continuous time once and internally constructs one checked
deadline no later than `now + 140_000_000_000` nanoseconds. No caller, capsule
field or frame may select that deadline.

Required injected capabilities are semantic, not syscall-shaped:

- initial/final installed-driver observation;
- one fixed epoch session with typed bootstrap/frame/EOF operations;
- complete post-drop App identity observation and repeat observation;
- one claim-client factory owning claim, release and the completed b5a0 abort;
- one typed installed-L2 observation; and
- one terminal `retireAndReap` result.

No seam may accept caller-selected raw authority inputs such as a path,
descriptor, argv, environment, UID, PID/PGID, signal, socket kind or endpoint.
Typed seams may carry only closed identities minted by the designated observer
and cannot expose their scalar fields as caller choices. Failure after a session
starts must await typed terminal retirement. Claim ambiguity is terminal:
there is no retry, second client or best-effort release after an unknown claim.
Failure to prove retirement overrides the underlying failure.
The semantic claim capability consumes the completed b5a0 terminal abort proof.
If claim succeeds but installed-L2 or any later pre-release step fails, b5a
aborts before retiring/reaping the App. Neither path may send `CLAIM_RELEASE`
without installed-L2.

The result is opaque, `Sendable`, non-`Codable` and non-admitting. It contains no
report, receipt, readiness verdict, path, PID, handle or reusable capability.

### ii-b5a scope and cost

At most five non-document paths and 1,500 changed lines after b5a0 is complete:

1. one new
   `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineSingleEpoch.swift`;
2. one new focused `Tests/StornautInvestigationTests/InvestigationMachineSingleEpochTests.swift`;
3. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
4. `scripts/verify-investigation-boundaries`; and
5. `scripts/verify-contract`.

`Package.swift`, the native entry, concrete claim client, Handoff wire, App,
Lifecycle, Machine, Xcode and `verify-app-release-boundaries` remain unchanged.
Needing another implementation path or approaching the ceiling forces a fresh
cost split before coding.

## 5. ii-b5b-i — Installed-L2 Contract and Projection Extraction

The existing full installed-L2 semantic/physical implementation spans broad
Lifecycle and Machine targets and cannot be linked into the native driver or
copied into DriverSupport. ii-b5b-i receives its own exact-path preflight and
extracts/reuses the phase contract, fixed artifact/process/signing checks and
fixed-service observation into an authority-closed dependency consumable by
DriverSupport.

It also defines the closed binary identity projection described above without
parsing configuration JSON. Typed L2 evidence is non-Codable and mintable only
by the concrete observer. It binds exact claimed-helper identity, repeated App
identity, projection/binding commitments and observation window, and proves
`claimedAt <= startedAt <= observedAt <= epochDeadline`. It performs no bootout,
install, process launch, signal or cleanup.

The live L2 implementation is about 1,607 lines before extraction. This split
document does not invent a path/line ceiling for b5b-i; its fresh exact-path
preflight must choose move-versus-target extraction, prove no second L2
implementation and remain below repository hard thresholds before coding.

## 6. ii-b5b-ii — Fixed Darwin Epoch Runtime

ii-b5b-ii supplies the only physical fixed-App implementation. It owns:

- bounded FD-0 capsule read from offset zero to exact EOF and internal fixed
  epoch selection;
- `socketpair(AF_UNIX, SOCK_STREAM)`, collision-safe FD relocation and exactly
  one `dup2(..., 7)`;
- fixed installed diagnostic App path, exact one-element argv, fixed empty or
  separately preflighted environment, `POSIX_SPAWN_SETPGROUP |
  POSIX_SPAWN_CLOEXEC_DEFAULT`, and no shell/`posix_spawnp`/`SETSID`/suspend;
- independent pre/post-drop App PID-version/audit/ASID/PPID/PGID/UID/GID/groups,
  fixed path/SHA and static/live Security identity joins;
- strict bounded socket I/O and peer-write EOF while retaining the write half
  for `EXIT`;
- exact owned PGID inventory, waitable-leader evidence, bounded TERM/KILL, final
  narrow fallback and leader reap last.

The physical API remains fixed and opaque. It cannot expose arbitrary spawn,
write, signal, process inventory or cleanup operations. PGID retirement proves
only the exact owned group; it does not replace the existing audit-session
supervisor or claim containment of descendants that create a new session.

ii-b5b-ii receives a fresh exact-path preflight after b5b-i. The candidate list
currently reaches thirteen paths at its maximum and therefore is not frozen as
one 12-path checkpoint here. Package and Xcode changes must be counted separately
unless proven mutually exclusive. A broad product-target dependency or approach
to a hard ceiling forces another split.

## 7. ii-b5b-iii — Production Entry and Artifact Composition

ii-b5b-iii joins b5a, b5b-i and b5b-ii to the existing zero-argument native
entry, performs the initial/final exact ii-a observation, consumes the internally
selected stdin capsule epoch, and owns native Debug/Release/final-Mach-O gates.
It adds no new semantic or physical authority. Its fresh preflight must prove
that only the reviewed targets/sources enter the final driver and that ordinary
App/helper/diagnostic images remain closed.

## 8. Tests-First and Validation Contracts

ii-b5a focused tests must prove the successful exact order and every boundary:
skip/duplicate/replay/direction/identity/epoch/deadline/configuration/handle drift;
claim-before-EOF, L2-before-claim, release-before-L2 and EXIT-before-release;
claim/release ambiguity; cancellation at each suspension; teardown failure
priority; final self-observation mismatch; one-shot concurrency; and non-Codable
non-admission. A call trace must make every ordering assertion independent of
the implementation's own validator.
The matrix includes every failure after claim: abort-before-App-retire ordering,
abort ambiguity overriding the original error, no release before L2, and proof
that a claim error cannot leave an unobserved helper terminal state.

ii-b5b-i covers strict binary projection shape/digest/join, all installed-L2
axes and a structural negative proving HandoffContract/DriverSupport contain no
product JSON decoder or copied Diagnostic schema. ii-b5b-ii covers FD-7
collisions, descriptor inheritance, fixed path/argv/env, partial I/O/EOF,
pre/post-drop identity races, waitable-leader/descendant/reuse races and
TERM/KILL/reap ordering. ii-b5b-iii owns source/package mutations and native
Debug/Release final-Mach-O positive/negative controls.

Each sub-checkpoint uses structural -> focused -> affected -> one clean staged
serial -> applicable artifact gate -> independent review. ii-b5a/b5b-i/b5b-ii
have no final-Mach-O claim; ii-b5b-iii owns the complete driver/App artifact
gate. None runs
the real installed App/helper, real XPC, install, sudo/root external execution,
model/auth/network or authoritative full verifier.

## 9. Cross-Epoch Continuity, Non-Admission and Next Order

One package-scoped, actor-owned `HelperEpochContinuityStore` is created and held
only by the ii-c outer installed-driver cohort runner. Single-epoch public or
non-admitting results never expose its token. The first epoch requires the store
to be empty. Successful epoch completion commits one opaque, non-Codable
`HelperEpochContinuity` minted from the exact claimed-helper identity plus
terminal proof. The next epoch consumes exactly one value, requires a different
fully attested helper and repeats full installed-L2. Failure/cancellation never
mints a value; missing, replayed, duplicated or same-helper continuity is
terminal. After the final epoch the store destroys the value. No outer caller
reconstructs continuity from a raw PID.

This preflight is documentation-only and consumes no serial. All b5 substeps
remain non-admitting prerequisites. ADR 0018 stays Proposed, Task 39 remains
incomplete and production Deep Dive remains `.implementationUnavailable`.

The strict remaining order is:

```text
ii-b5a0 -> ii-b5a -> ii-b5b-i -> ii-b5b-ii -> ii-b5b-iii
-> ii-c0 -> ii-c -> L3c3d -> L3c4
```

ii-c0 still owns fresh capsule/TTY/sudo-shaped launcher evidence; ii-c alone may
accept ADR 0018; L3c4 alone owns machine readiness and Task 39's remaining full.
