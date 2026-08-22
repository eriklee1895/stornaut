# Phase D Task 39B2c L3c3c-ii-b5b-ii-c Preflight

> Status: approved for tests-first implementation / non-admitting
> Date: 2026-08-22
> Frozen source baseline: `ec5c3120b5017aa0a85bff1ec827117c56e9f9a0`
> Admission: none
> Next checkpoint: ii-b5b-ii-d exact owned-PGID retirement

## 1. Decision

ii-b5b-ii-c remains one bounded checkpoint, but its resource-ownership boundary
must be narrower than the aggregate ii-b5b-ii description. This checkpoint
implements the real fixed socketpair, FD-7 spawn, bounded duplex transport and
Darwin App identity integration. It does not implement TERM/KILL, process-group
inventory, waitable-leader handling, descendant absence or reap-last. Those
operations remain solely ii-b5b-ii-d.

The existing `InvestigationMachineSingleEpochSession.retireAndReap()` contract
therefore cannot be satisfied by a synthetic success. The physical session owns
an opaque, non-serializable epoch resource and delegates terminal cleanup to one
injected module-internal retirement owner. A production owner does not exist in
this checkpoint; ii-d must supply it before b5b-iii can compose the runtime.

The current non-throwing factory outcome gains one typed
`terminalUncertain` state. `terminal` means no resource was created or every
created resource was retired with proof. `terminalUncertain` means spawn
succeeded but terminal cleanup could not be proved, and the composer maps it to
`retirementUncertain`, overriding cancellation or the original startup error.
This preserves the existing typed outcome surface without permitting hidden
ownership after a failed start.

## 2. Frozen Scope and Cost

The exact anticipated non-document path set is seven paths, with a hard ceiling
of eight paths and 3,600 changed lines:

1. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineSingleEpoch.swift`;
2. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinEpochSession.swift`;
3. `Tests/StornautInvestigationTests/InvestigationMachineDarwinEpochSessionTests.swift`;
4. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
5. `scripts/verify-investigation-boundaries`;
6. `scripts/verify-app-release-boundaries`; and
7. `scripts/verify-contract`.

No `Package.swift` change is expected because SwiftPM automatically includes the
new source and test files in their existing targets. No App leaf, native entry,
Lifecycle, HandoffContract, C shim, installed-L2 or product source may change.
The Xcode verifier is included because the new DriverSupport implementation
changes the already sealed native Machine Driver image even before b5b-iii owns
its final production composition. If another non-document path becomes
necessary, record why before editing it; exceeding eight paths or approaching
3,600 lines forces another split.

## 3. Fixed Physical Contract

The only production executable is
`InvestigationInstalledL2FixedPaths().appExecutable`. The physical spawn accepts
no package/public path, argv, environment, UID, PID, PGID, endpoint, descriptor,
signal or action input. It creates exactly one unnamed
`AF_UNIX/SOCK_STREAM` pair, relocates any endpoint colliding with `0`, `1`, `2`
or `7`, sets close-on-exec, and creates exactly one child mapping to FD 7. The
child receives one-element argv containing only the fixed executable and an
explicit empty environment. Spawn flags are exactly
`POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT`; there is no shell,
`posix_spawnp`, `SETSID`, suspend or filesystem socket.

After spawn, the parent closes its child endpoint, retains only its endpoint,
requires the child process group to equal the child PID and differ from the
driver's group, and writes the exact 32-byte STNP bootstrap before returning a
session. Any pre-spawn failure closes both endpoints and yields a terminal proof.
Any post-spawn failure invokes the one injected retirement owner exactly once;
failure to obtain its proof yields `terminalUncertain`.

The actor-owned session permits only the canonical operation sequence:

```text
receive PRE_DROP_READY
-> send DROP_RELEASE
-> receive DROP_EVIDENCE
-> first complete App identity
-> send CONFIGURATION
-> receive CONFIGURATION_ACK
-> receive HELLO
-> receive HANDLE
-> send ACK
-> send RELEASE
-> receive ALIVE
-> prove peer write EOF
-> fresh repeated App identity
-> send EXIT
-> retire exactly once
```

Every read first consumes the exact fixed header and then only its admitted
bounded payload. Every write uses canonical frame encoding. Poll/read/write
retry only `EINTR` or readiness races, use the checked epoch deadline and fail
closed on partial input, early EOF, trailing bytes, timeout, cancellation or
descriptor error. `provePeerWriteEOF()` observes an actual zero-byte receive
after ALIVE while retaining the parent write half for EXIT. Concurrent,
duplicate or out-of-order calls terminally consume the session.

## 4. Identity and Ownership Join

The factory obtains the driver's root claim from the existing C narrow-identity
reader. On PRE_DROP_READY the session requires the sender PID to equal the
spawned child and calls the completed Darwin observer's
`prepare(processClaim:projection:)`. On DROP_EVIDENCE it calls
`observe(preDrop:processClaim:dropEvidence:projection:)` and caches only that
typed App observation. The composer's first identity request consumes the cached
value. The second request after installed-L2 and peer EOF performs a fresh full
observer sandwich; it cannot replay the cache. Raw PID/PGID, descriptors, audit
tokens, paths and signing evidence do not cross the session API.

The owned-epoch value and retirement protocol are module-internal, opaque to
package consumers and non-`Codable`. ii-d may inspect their raw fields only
inside DriverSupport to implement exact retirement. The public/package API
cannot obtain or construct arbitrary process or descriptor authority.

## 5. Tests-First Matrix

RED tests precede implementation and must cover:

- the missing physical factory/session and typed `terminalUncertain` outcome;
- exact fixed App path, one-element argv, empty environment and spawn flags;
- FD collisions with standard descriptors and FD 7, exactly one child FD-7
  mapping, CLOEXEC behavior and parent/child endpoint ownership;
- pre-spawn failure versus post-spawn cleanup success/uncertainty;
- strict operation order, duplicate/concurrent use and one-shot retirement;
- bounded fragmented reads/writes, malformed/oversized frames, early EOF,
  trailing data, deadline and cancellation;
- PRE_DROP_READY spawned-PID binding, pre-drop observer failure, DROP_EVIDENCE
  identity failure, cached first observation and fresh repeated observation;
- a same-UID child-process fixture proving real socket inheritance, empty
  environment, one-element argv, peer write EOF and retained parent write half;
- non-public/non-Codable/raw-authority boundary checks; and
- source/verifier mutations for executable/path/env selection, extra descriptor
  mapping, weak spawn flags, cached repeated identity, false terminal proof,
  unbounded I/O and scope/budget drift.

## 6. Validation and Non-Claims

Validation is structural -> focused physical/session tests -> affected
Investigation tests -> one staged-only serial -> SwiftPM and Xcode
Debug/Release binary gates -> independent review. No `scripts/verify --full` is
run. No installed App/helper, real XPC, sudo/root, Codex auth, model, network,
Trash or Executor operation is used. The same-UID fixture proves only the
transport/spawn algorithm, not the root-to-UID transition or installed artifact.

This checkpoint cannot accept ADR 0018, compose the native production entry,
claim PGID retirement, emit readiness or enable Deep Dive. ii-b5b-ii-d remains
mandatory, followed by b5b-iii, ii-c0, the one no-model privileged ii-c gate,
L3c3d authenticated success and L3c4 final admission.
