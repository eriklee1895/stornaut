# Phase D Task 39B2c L3c3c-ii-b5b-iii-b0 Outer/Inner Protocol Preflight

> Status: architecture, split, protocol and tests-first boundaries frozen;
> implementation not started
>
> Date: 2026-08-23
>
> Baseline: `89a77f9fca78fc762cc60d1f50b2d27fb8217074`
>
> Scope: documentation and current-source/platform inspection only; no
> source/test/script implementation, App/helper/driver launch, install, sudo,
> root mutation, model/auth/network use, serial regression or authoritative full
> verifier

## 1. Decision

The original ii-b5b-iii production-entry checkpoint must split again before
coding. The projection dependency is closed by ii-c0a, but the accepted
outer/inner process topology is not represented by current source:

- `InvestigationMachineFixedEpochPlan.takeNext()` now returns one internally
  selected, non-replayable `epoch + projection` pair and both cohort digests;
- `InvestigationMachineSingleEpochComposer` still hides
  `previousHelperIdentity` by always passing `nil`, and its success result carries
  no helper-continuity evidence;
- `InvestigationMachineDarwinEpochSessionFactory` directly launches the App as
  its own process-group leader in the current process; and
- the public zero-argument driver still performs only root/argument/self
  observation and returns status `78`.

That direct-spawn shape cannot implement ADR 0018's `parent_crash` requirement.
Crashing the current process would kill the only cohort supervisor, while making
the App a separate process-group leader would leave the surviving outer process
unable to retain and reap the exact group leader. The implementation order is
therefore frozen as:

```text
ii-b5b-iii-b0 outer/inner protocol preflight
-> ii-b5b-iii-a typed per-epoch completion and continuity
-> ii-b5b-iii-b1 injected eight-epoch cohort state machine
-> ii-b5b-iii-b2a Darwin outer/inner physical adapter
-> ii-b5b-iii-b2b zero-argument entry and final artifact
-> ii-c0b non-root capsule author and launcher hygiene
-> ii-c one privileged no-model machine gate
-> L3c3d authenticated real-success candidate
-> L3c4 sealed final admission
```

`iii-b2` remains an umbrella only. Combining its physical process adapter with
entry and final-Mach-O admission is estimated at 11–14 non-document paths and
4,500–6,000 changed lines, so it is pre-split into b2a and b2b.

## 2. Frozen Process and Process-Group Topology

One installed driver process is the long-lived root outer supervisor. For every
epoch it uses fixed-path `posix_spawn`, never `fork`, to launch the same signed
driver binary as one disposable root inner scenario-parent:

```text
outer root driver (long lived; own process group)
└─ inner root scenario-parent (PID = PGID; waitable direct child of outer)
   └─ fixed diagnostic App (direct child of inner; joins inner PGID)
      └─ any App descendants remain in that scenario PGID unless the separately
         required audit-session supervisor contains a new-session escape
```

The outer never joins an epoch group and never retains an App-channel endpoint.
The inner creates the App socketpair, is the App's real parent and peer, and
spawns the App without `POSIX_SPAWN_SETPGROUP`, so the App inherits the inner-
led group. The current App identity rule `App PGID == App PID` must later become
`App PGID == independently admitted inner PGID`, while PPID remains the exact
inner PID.

Normal completion has two layers. The inner may wait for and reap its direct App
child after the protocol finishes, but cannot prove its own group absent while
it is still alive. It writes one canonical local result and exits. The outer
retains the inner as a waitable group leader, requires every non-leader group
member gone, reaps the inner last and then requires the same numeric PGID empty.
Only the outer proof can seal an epoch.

For crash or hang, the outer first allows a bounded natural-drain window and then
may apply the already reviewed exact-group TERM/KILL/reap-last algorithm to the
verified inner-owned group. The existing retirement owner must not be weakened:
its `leaderPID == PGID`, direct-child waitability and post-reap empty checks stay
mandatory. A later b2a implementation may add a bounded natural-drain phase in
front of it, but cannot signal after a post-reap reuse observation. PGID evidence
does not replace ADR 0016 audit-session containment for descendants that create a
new session.

Rejected alternatives are: making the outer itself the fault target; launching
the App directly from outer; putting inner and App in separate groups; making
the App the group leader; or placing any epoch process in the outer group. Each
loses either EOF causality, direct-child reap ownership or group isolation.

## 3. Fixed Descriptor and Activation Contract

The outer/inner ABI is fixed and has no argv, environment or path selector:

| Descriptor | Owner and purpose | Rule |
| --- | --- | --- |
| `0` | outer only: sealed projected-cohort input | read once from offset zero to exact EOF; `FD_CLOEXEC`; never inherited by inner |
| `1` | outer only: final ii-c result | no inner/App writes; b2b freezes one bounded canonical output and c0b captures it |
| `2` | outer and explicitly inherited inner diagnostic stream | preserve the controlling Terminal used by the future sudo ceremony; never carry protocol or result bytes |
| `7` | inner and App: existing STNP/STNH duplex session | fresh per epoch; never visible to outer |
| `8` | inner: fixed duplex supervisor-control endpoint | outer retains the other endpoint on one owned descriptor relocated to `>= 10`; request, ownership, acknowledgement and fixed continue/crash decision only |
| `9` | inner: fixed write-only terminal-result endpoint | outer retains the read end on one owned descriptor relocated to `>= 10`; exactly one canonical result on normal completion; EOF without a result is meaningful only for the frozen crash overlay |
| `>= 10` | outer-owned channel endpoints and temporary source descriptors | collision-safe relocation range; closed from unrelated exec descendants |

Self-spawn uses the fixed installed driver path, one-element argv, empty
environment and `POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT`. Only the
child control endpoint mapped to FD 8 and the result-pipe write end mapped to
FD 9 are inherited as protocol descriptors. FD 2 is explicitly inherited with the SDK's
`posix_spawn_file_actions_addinherit_np`; FD 0, FD 1 and every other descriptor
are closed by default. The inner's later App spawn inherits only its mapped FD
7. No process calls `setsid`, creates a filesystem socket, accepts a caller
descriptor or changes the controlling terminal.

Both outer and inner keep `argc == 1`. At entry, exact descriptor provenance
selects the role:

- outer requires FD 8 and FD 9 absent before it consumes FD 0;
- inner requires FD 0 and FD 1 closed, FD 8 to be the admitted connected duplex
  Unix stream, FD 9 to be the admitted write-only result channel and FD 7 absent;
- both roles require FD 2 open and preserve its file identity/TTY state; outer
  additionally requires FD 0 to be the admitted c0a regular-file input and FD 1
  open for the future result, while inner must find no unexpected open descriptor
  in a bounded `0...9` scan; and
- malformed, aliased, incorrectly directed or unexpectedly open fixed
  descriptors fail before an epoch is consumed. Higher descriptors are admitted
  only when they are the process-local endpoints explicitly returned by the
  current spawn operation; neither role attempts a global descriptor scan.

The local macOS 26.5 SDK declares `posix_spawn_file_actions_addinherit_np` and
documents that `POSIX_SPAWN_CLOEXEC_DEFAULT` closes every descriptor not
explicitly manipulated by file actions. b2a must still prove the exact behavior
with a non-privileged physical child rather than relying on headers alone.

## 4. Private Canonical Supervisor Protocol

The protocol is internal to `StornautInvestigationMachineDriverSupport`; it is
not a new App/helper API and must not be public or `Codable`. It reuses
`HandoffBinaryTranscript`, big-endian integers, raw UUIDs and raw 32-byte
`InvestigationHandoffSHA256` values with distinct version-1 domains and hard
length bounds. Every decode must require exact fields, canonical re-encode and
exact EOF.

### 4.1 Epoch request: outer to inner on FD 8

The request binds exactly:

- outer-attempt UUID;
- whole projected-input and unchanged v1 capsule SHA-256 values;
- one complete canonical encoded `InvestigationCohortEpoch`, including its
  ordinal, existing eight-value business scenario, epoch UUID, configuration
  nonce, opaque configuration bytes and configuration/runtime-binding digests;
- one complete canonical encoded `InvestigationInstalledL2IdentityProjection`
  whose four c0a identity axes match that epoch, plus its projection SHA-256;
- one absolute monotonic epoch deadline created by the outer;
- one opaque previous-continuity transcript, using a distinct canonical genesis
  value for ordinal zero rather than an optional or zero-length field; and
- one closed physical fault overlay: `normal` or `parentCrash`.

The request contains no path, descriptor, UID, PID, PGID, signal, endpoint, model
or cleanup command. The epoch's configuration body remains opaque canonical
bytes; the inner passes it to the existing App protocol and never decodes
product JSON. It receives no second epoch/projection source and never reads
FD 0.

### 4.2 Ownership armed: inner to outer on FD 8

The deliberate crash point is not armed merely by spawning the App. Before the
outer may acknowledge or inject a crash, the inner must send one canonical
ownership record after all of these are true:

1. the App completed irreversible drop and full independent identity admission;
2. peer-write EOF was proved and the same fixed claim client obtained exact
   helper evidence;
3. installed-L2 and the repeated App identity join succeeded; and
4. helper release, App `EXIT` and local retirement have not begun.

The ownership record binds the request SHA-256, complete independently observed
inner identity and inner PGID, complete App identity plus PPID/PGID, complete
claimed-helper identity, claim-evidence SHA-256, installed-L2 proof digest and
the release/epoch deadlines. It carries no retirement handle or reusable token.
The outer independently re-observes the inner/App/group facts before returning
an acknowledgement that echoes both request and ownership digests. Until that
acknowledgement arrives, any inner EOF or death is terminal uncertainty.

### 4.3 Outer decision and normal result

After acknowledgement the outer sends exactly one fixed decision. `continue` is
the only normal decision. `crashNow` is legal only for the frozen physical crash
overlay. Unknown, duplicate, reordered, replayed or foreign decisions consume
the epoch.

On `continue`, the inner performs helper release/absence, sends App `EXIT`, waits
for and reaps its direct App child without group-wide signalling, requires no
non-leader group member and repeats exact installed-driver self-observation. It then writes exactly one
canonical result on FD 9 and exits. The result binds request and ownership
digests, the complete helper identity, claim/release and local-completion
digests, terminal class and successor-continuity candidate. It does not claim
final PGID containment. The outer accepts it only before exact result EOF, then
performs its own waitable-leader/reap-last/post-reap-empty proof before sealing
the epoch and continuity.

An inner error result, nonzero exit, partial/duplicate/trailing result, premature
EOF, control/result ordering drift or outer containment uncertainty terminates
the cohort. An inner self-report never upgrades external uncertainty.

## 5. Parent-Crash Overlay and Eight Business Scenarios

`parentCrash` is a physical lifecycle fault overlay, not a ninth
`InvestigationHandoffScenario`, not a new configuration field and not a new row
in the accepted v1 capsule. The existing eight business rows and their bytes
remain unchanged. The mapping is closed: `.lifecycleRecovery` carries the
`parentCrash` overlay and the other seven rows carry `normal`. This is derived
internally from the ordered scenario and cannot be selected or overridden by a
caller, argv, environment or an extra capsule field. The later ii-c scenario
preflight still freezes all remaining replay/deadline/cancellation/child-crash/
hang injection points before the unique privileged run. A contained physical
parent crash does not by itself prove the Task 38 `.lifecycleRecovered` business
outcome; L3c4 must still join separately authoritative Task 38 evidence.

For `parentCrash`, the outer sends `crashNow` only after independently validating
the ownership record and sending its acknowledgement. The inner immediately
uses the frozen non-returning exit primitive; it writes no result and performs
no release or local cleanup. Closure of its one-shot claim connection drives the
existing helper claim server to terminal `connectionInvalidated`, whose physical
terminal handler schedules helper exit with status `71`; closure of the inner-
owned FD 7 is the real App peer EOF. The outer has neither the claim handle nor
the XPC session and cannot release, cancel or reconstruct either authority. It
only waits for and independently observes both already-armed owners becoming
terminal. Within the fixed deadline it requires:

1. canonical control EOF;
2. FD 9 EOF with zero result bytes;
3. exact waitable inner PID/version and expected non-success exit;
4. exact App PID/version disappearance;
5. no non-leader member in the exact inner-owned PGID, then inner reap-last and
   a second empty inventory of the same numeric PGID;
6. exact claimed-helper absence after the claim connection invalidation, plus
   matching L1/audit-session zero residue; and
7. final installed-driver self-observation equal to the initial observation.

EOF, exit status or an empty group alone never proves containment. If the inner
dies before ownership is armed, if any recorded identity cannot be independently
revalidated, or if any cleanup observation is unavailable, the whole cohort is
terminally uncertain and no next epoch starts.

The existing automatic invalidation/deadline behavior is a source-level
candidate only at b0. iii-a must model it as an injected terminal proof and b2a
must exercise the real same-UID connection-loss path. If that physical evidence
does not show bounded helper/L1 termination, the parent-crash overlay is a
terminal cohort failure and may not mint successor continuity. No new outer
release authority may be introduced as a fallback.

## 6. Continuity and Cohort Advancement

`InvestigationMachineHelperEpochContinuity` is package-only, opaque, `Sendable`
and non-`Codable`. It binds the outer attempt/input/capsule, completed ordinal,
complete helper identity and the outer-sealed terminal proof. A canonical
genesis value exists only for ordinal zero. Each later request consumes exactly
one predecessor continuity; missing, duplicate, replayed, wrong-ordinal, foreign-
cohort or same-helper continuity is terminal. No caller can construct continuity
from a raw PID or digest.

A successor may be sealed only by the outer after either:

- a canonical expected inner result for that business row plus complete outer
  group containment; or
- the fixed `.lifecycleRecovery` parent-crash sequence plus independently proved
  automatic group/helper/L1 containment.

The crash successor uses the helper identity already frozen in the ownership
record; it cannot reuse the older predecessor identity or accept an identity
learned after the inner died. For the other seven rows, a configured failure
outcome may advance only when it is the exact expected result for that row and
the outer independently seals all resources; unexpected error, cancellation,
identity drift or any uncertainty mints no successor and stops the cohort. After
ordinal seven, the runner destroys the last continuity and proves the FD-0 plan
exhausted.

## 7. Frozen Implementation Checkpoints and Budgets

### iii-a — Typed per-epoch completion and continuity

At most 10 non-document paths and 3,200 changed lines:

1. `InvestigationMachineSingleEpoch.swift`;
2. one new per-epoch composition/ownership source;
3. one new continuity source;
4. one new focused composition test;
5. `InvestigationMachineSingleEpochTests.swift`;
6. `InvestigationMachineClaimClientTests.swift`;
7. `InvestigationMachineTargetBoundaryTests.swift`; and
8. the three boundary verifiers.

This checkpoint passes previous helper identity into the existing ClaimClient,
adds the injected post-L2/pre-release ownership suspension, returns an opaque
local completion candidate and lets only an injected outer-containment join mint
successor continuity. It does not instantiate the current direct-spawn Darwin
factory as final production topology, read FD 0, self-spawn or run eight epochs.

### iii-b1 — Injected eight-epoch cohort

At most 8 non-document paths and 3,200 changed lines: one new cohort source, one
new focused test, optional narrow fixed-plan exhaustion API/test changes, the
target-boundary test and three boundary verifiers. It owns a one-shot actor, the
shared c0a plan and continuity store, exact ordinal/scenario/digest joins, one
fresh executor per epoch, fixed overlay selection, stop-on-uncertainty and final
continuity destruction/plan exhaustion. It performs no Darwin spawn or real
FD/App/helper work.

### iii-b2a — Darwin outer/inner physical adapter

At most 10 non-document paths and 3,600 changed lines. The frozen maximum set is:

1. one new supervisor protocol/physical-adapter source;
2. one new driver-child identity source;
3. `InvestigationMachineDarwinEpochSession.swift`;
4. `InvestigationMachineDarwinAppIdentityObservation.swift`;
5. `InvestigationMachineDarwinEpochRetirement.swift`;
6. one focused physical test source;
7. `InvestigationMachineTargetBoundaryTests.swift`; and
8. the three boundary verifiers.

It owns fixed self-spawn, FD 8/9, inner-led PGID, App group inheritance, normal
direct-child reap, parent-crash/hang containment and same-UID physical fixtures.
It does not connect the public `run()`, consume real FD 0, install, use sudo or
launch the signed installed App. A second focused test file, any fourth existing
production source or any other path requires another preflight split.

If b2a needs a C shim, a new package target/dependency or an Xcode membership
change, stop and perform another exact-path preflight before coding.

### iii-b2b — Zero-argument entry and final artifact

At most 8 non-document paths and 2,800 changed lines: the existing public driver
support/its focused tests, at most one final join source, the target-boundary
test, three verifiers and `Tools/StornautInvestigationMachineDriver/main.swift`
only if strictly necessary. Package and Xcode graphs should remain unchanged.

It connects root/argc/role admission, FD-0 projected input, the concrete cohort
and one final canonical stdout result. Existing statuses `77`, `78` and `79`
remain unambiguous; new terminal statuses must distinguish invalid input,
protocol failure and containment uncertainty. Exit `0` requires eight sealed
epochs, exhausted plan, destroyed continuity, terminal children/groups and final
self-observation. Debug and Release driver binaries become positive controls for
the complete intended graph, while ordinary App, diagnostic main, helper and
Release shell remain negative controls.

## 8. Tests-First and Validation Matrix

Before each implementation checkpoint, use the mandatory Swift unit-test
workflow and produce compile/test RED evidence. Across the split, tests and
mutations must cover:

- exact genesis and eight ordered paired selections;
- previous-helper propagation, fresh-helper rejection, successor minting, replay
  and one-shot concurrency;
- ownership before decision, decision before release, and result before inner
  exit;
- every field/domain/tag/length/digest/order/EOF/trailing-byte mutation;
- inner death before ownership, normal death without result and result without
  external containment;
- the exact parent-crash overlay, including no result and an outer-sealed
  successor, without changing the eight-value business enum;
- FD 0/1/2/7/8/9 shape, alias, direction, CLOEXEC and relocation collisions;
- inner PID=PGID, App PPID=inner and App PGID=inner PGID;
- natural drain, TERM/KILL fallback, waitable leader, reap-last, PID/PGID reuse,
  escaped-session handoff to ADR 0016 and no global same-UID signalling;
- cancellation at every suspension, deadline boundaries and uncertainty
  priority;
- zero-argument role detection and exact exit-status mapping; and
- exact SwiftPM/Xcode Debug/Release symbol ownership and all closed-image
  negatives.

Each implementation checkpoint runs:

```text
structural/source/scope RED
-> exact focused tests
-> affected Investigation tests
-> scripts/verify-contract
-> scripts/verify-investigation-boundaries
-> scripts/verify-app-release-boundaries when its binary surface changes
-> applicable SwiftPM/Xcode Debug and Release projections
-> one clean staged-only serialized SwiftPM regression
-> independent implementation/verifier/cross-boundary review
```

No checkpoint in iii-b0/iii-a/iii-b1/iii-b2a/iii-b2b runs the authoritative
full verifier. No root, installed product App/helper, real XPC, sudo, model or
network operation is permitted. Physical tests use only same-UID disposable
fixtures.

## 9. Prompt-to-Artifact Preflight Checklist

| Requirement | Frozen artifact or later evidence | Status |
| --- | --- | --- |
| Split before review surface exceeds limits | five bounded checkpoints and individual path/line ceilings above | frozen |
| Preserve c0a/v1 input | outer-only FD 0 plus exact input/capsule/epoch/projection bindings | frozen |
| Keep outer alive across parent crash | long-lived outer and disposable self-spawned inner topology | frozen |
| Retain a waitable group leader | inner PID=PGID and direct child of outer | frozen |
| Give App real EOF on inner crash | inner solely owns App FD-7 endpoint; outer has no copy | frozen |
| Distinguish crash from result | FD 8 control plus independent one-way FD 9 result | frozen |
| Preserve future sudo TTY | outer stdout result, explicitly inherited inner stderr, unchanged controlling terminal | frozen pending b2a physical proof |
| Keep eight business rows unchanged | `.lifecycleRecovery` maps internally to the parent-crash overlay; no ninth row or v1 change | frozen |
| Arm crash only after sufficient evidence | post-claim, installed-L2, repeated-App ownership record and outer acknowledgement | frozen |
| Prevent self-reported containment | only outer can seal group/helper/L1 absence and continuity | frozen |
| Preserve helper freshness across crash | crash successor binds the pre-crash claimed helper identity | frozen |
| Keep authority narrow | fixed paths/FDs/argv/env/PGID; no arbitrary spawn/signal/open/network/cleanup surface | frozen |
| Preserve admission ownership | ii-c owns privilege/ADR acceptance; L3c4 owns readiness/full | frozen |

## 10. Non-Claims and Next Step

This preflight changed no production or test source and executed no build, test,
App, helper, driver, XPC, install, sudo/root, model, network, Trash or full
verifier. The local SDK declaration is design evidence only; b2a must supply the
physical descriptor and process evidence. Historical B3/B4 matrices are retained
algorithm evidence, not current product execution.

ADR 0018 remains Proposed, Task 39 remains incomplete and production Deep Dive
remains `.implementationUnavailable`. The next checkpoint is iii-a typed per-
epoch completion and continuity.
