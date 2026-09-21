# Phase D Task 39B2c L3c3c-ii-b5b-ii-c Review

> Status: complete / non-admitting
> Date: 2026-08-23
> Implementation commit: `d93542283fe5f3c4591b162abbcc69fbd361aa03`
> Parent: `30dc76c450517a3b7a887a7802132087beda147f`
> Tree: `e896a10b0e6cdade862c623178f15673192a89a4`
> Next frontier: ii-b5b-ii-d exact owned-PGID retirement

## 1. Result

ii-b5b-ii-c completes the fixed FD-7 spawn and bounded duplex-session layer of
the Darwin single-epoch runtime. The DriverSupport factory now creates one
unnamed socketpair, launches only the fixed installed diagnostic App with one
child mapping to descriptor 7, sends the canonical STNP bootstrap and exposes a
strict actor-owned session to the existing typed composer. The session joins
the completed Darwin App identity observer, enforces the canonical STNH phase
order and delegates terminal ownership to an opaque injected retirement owner.

The implementation changes exactly eight non-document paths and 3,104 changed
non-document lines against its frozen parent, within the reviewed eight-path /
3,600-line ceiling. No package, App leaf, Lifecycle, handoff-contract, C shim or
installed-L2 source changed.

## 2. Implemented Contract

- Production spawn is fixed to
  `/Library/Application Support/Stornaut/Stornaut-R5-Diagnostic.app/Contents/MacOS/StornautInvestigationDiagnostic`.
  It accepts no caller-selected path, argv, environment, UID, PID, PGID,
  endpoint, descriptor, signal or action. argv contains only that path, the
  environment is empty and the flags are exactly
  `POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT`.
- One `AF_UNIX` / `SOCK_STREAM` pair is created. Endpoints colliding with
  descriptors 0, 1, 2 or 7 are relocated at or above 8 with close-on-exec; the
  child receives exactly descriptor 7 and the parent retains only its endpoint.
- The factory requires a root driver claim, positive spawned PID and a child
  PGID equal to that PID but different from the driver's group. Until that join
  is proved, cleanup is routed only through `retireSpawnedProcess`; group-wide
  authority is available only through the independently validated opaque
  `InvestigationMachineDarwinOwnedEpoch`.
- Pre-spawn failures close owned descriptors and return a terminal proof. A
  post-spawn failure invokes the injected retirement owner once; any inability
  to prove terminal cleanup returns typed `terminalUncertain`, which the
  composer maps to `retirementUncertain` ahead of cancellation or startup error.
- The actor admits only PRE_DROP_READY, DROP_RELEASE, DROP_EVIDENCE, first
  identity, CONFIGURATION, CONFIGURATION_ACK, HELLO, HANDLE, ACK, RELEASE, ALIVE,
  peer write EOF, fresh repeated identity, EXIT and retirement in order. An
  invalid, duplicate or concurrent call poisons the operation before suspension
  and cannot expose an early-retirement race.
- Header kind and bounded payload length are validated before payload reads.
  Physical reads and writes use the monotonic epoch deadline, retry only the
  admitted transient conditions and recheck the deadline after the final
  syscall, including zero-length operations. Cancellation waits for the physical
  worker to finish before the continuation returns, preventing reused descriptor
  numbers from being touched by a stale worker.
- PRE_DROP_READY is bound to the spawned PID. DROP_EVIDENCE completes the
  prepared Darwin observation; only that first typed observation is cached. The
  repeated observation is a fresh full identity sandwich after ALIVE and actual
  peer write EOF. Raw descriptors, PIDs, PGIDs, audit tokens and signing evidence
  remain package-closed and non-`Codable`.

Accepted canonical source SHA-256 values include:

- Darwin session: `3bfdf13654511e06ae4da881f70eb2edb5dd18cd35c0a34af8f007c6b85aff20`;
- single-epoch composer: `8c316f5196ada01bb4a812536fb7653218dfe9fc9b079cb90dfd6d2a5c18b338`;
- focused session tests: `e0d56f54d81505063c145f76fdea0a7b47c103e86e92ec11e6fd76506267c6fb`;
- contract verifier: `ad8aba3a7f9bc1ab3daa664b77045275c09a7c9e7c18126d9b4ee9d5947d30dd`.

## 3. Tests-First and Validation

- The final exact focused selection passed 35 tests in three suites. It covers
  factory state and failure outcomes, descriptor collision/ownership, bounded
  I/O, deadline/cancellation behavior, phase and concurrency rejection, identity
  preparation/freshness, opaque retirement routing and the real same-UID spawn.
- The physical spawn fixture exercises the production `posix_spawn` primitive
  and proves FD-7-only inheritance, one-element argv, empty environment, STNP
  receipt, peer write EOF and a still-writable parent half. It is not exposed as
  a caller-selected production executable.
- `scripts/verify-contract` passed, including semantic mutations for fixed
  path/environment/FD/flags, prohibited kill/wait/Process authority, stale
  repeated identity, false terminal outcome, untrusted-PGID routing, final
  post-syscall deadline checks, poisoned concurrent operations, physical-spawn
  coverage, loaded/owned binary projection and staged path/line/mode drift.
- `scripts/verify-investigation-boundaries` passed, including exact source,
  package surface, transport import and SwiftPM Debug/Release projection gates.
- `scripts/verify-app-release-boundaries` passed, including the corresponding
  Xcode Debug/Release Machine Driver and ordinary/diagnostic App projections.
- The single final staged-only serial regression passed 1,396 tests in 72 suites
  with zero failures in 123.550 seconds. Exact staged paths, file modes and the
  3,104-line budget also passed.

`scripts/verify --full` was deliberately not run. This remains a bounded,
non-admitting implementation checkpoint; L3c4 alone owns Task 39's remaining
authoritative full verifier.

## 4. Review Closure

Early independent review found three P1 gaps: physical I/O did not recheck the
deadline after its final syscall, an unverified PGID could be wrapped as an
owned process group, and the tests did not exercise the production spawn/FD-7
primitive. All three were repaired tests-first with final-deadline checks,
separate spawned-process versus validated-owned-group retirement capabilities
and a real same-UID fixture.

Later exact-tree review found a P1 actor race in which a concurrent invalid call
could fail while leaving another suspended operation able to reach retirement.
The session now reserves each operation with a unique ticket and poisoned state
before suspension; an invalid concurrent caller makes the in-flight completion
terminally fail rather than enabling early retirement. Verifier review also
found a P1 staged-mode omission and P2 missing loaded/owned projection
mutations. Exact mode sealing and independent positive/negative binary
projection mutations close those false-green windows.

Final post-fix implementation, verifier and cross-group exact-tree reviews
report no unresolved P0-P2 findings. The generated review artifacts are outside
the repository at `/tmp/stornaut_iib5biic_final_review/report.html` and
`report.md`.

## 5. Prompt-to-Artifact Completion Checklist

| Requirement | Concrete evidence | Result |
| --- | --- | --- |
| Fixed installed App and FD-7-only spawn | fixed request builder, production primitive and real child fixture | complete |
| Empty environment, one-element argv and exact flags | request assertions, physical fixture and contract mutations | complete |
| Collision-safe descriptor ownership | relocation/close-on-exec implementation and injected failure matrix | complete |
| Bounded canonical duplex sequence | actor phase machine, strict frame reads and 35-test focused selection | complete |
| Monotonic deadline and cancellation safety | pre/post-syscall checks, worker completion join and negative tests | complete |
| First and fresh repeated App identity | prepared first observation, fresh observer call and replay mutation | complete |
| Truthful startup/retirement uncertainty | typed outcome mapping and false-terminal mutations | complete |
| No premature PGID authority | spawned/owned capability split and routing tests/mutations | complete |
| No public/raw authority expansion | target-boundary and Debug/Release final-artifact gates | complete |
| Exact scope and file modes | 8 non-document paths / 3,104 changed lines, staged scope/mode gate | complete |
| Regression and independent review | 35 focused, three verifier gates, 1,396 serial, zero unresolved P0-P2 | complete |

## 6. Non-Claims and Next Step

This checkpoint did not run as root, install or launch the signed product
App/helper, invoke real XPC, read Codex authentication, access a network or call
a model. The same-UID fixture proves the physical spawn/transport algorithm, not
the root-to-UID transition or installed artifact. The injected retirement owner
is not a production PGID implementation and this checkpoint does not prove
TERM/KILL, process-group inventory, descendant absence, waitable-leader handling
or reap-last.

ADR 0018 remains Proposed, Task 39 remains incomplete, production Deep Dive
remains `.implementationUnavailable`, and the final full verifier remains
unconsumed. The next checkpoint is ii-b5b-ii-d exact owned-PGID retirement and
aggregate physical proof, followed by ii-b5b-iii production/artifact
composition, ii-c0, the one no-model privileged ii-c gate, L3c3d authenticated
success and L3c4 final admission.
