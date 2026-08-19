# Phase D Task 39B2c-L3c3c-ii-b1 Authority-Free App Leaf Preflight

> Status: Exact-path implementation preflight frozen; ii-b0a/ii-b0b/ii-b0c
> complete; ii-b1 current
>
> Date: 2026-08-19
>
> Baseline: `a365bd3a493e5ae9c80380358610a7880c665a2c`
>
> Scope: dedicated diagnostic App inherited-FD shell plus injected pure App-side
> handoff state machine; no concrete credential drop, configuration adapter,
> lifecycle/helper claim, driver composition, install, privilege, model/auth,
> readiness or full verifier
>
> Post-RED topology correction frozen: two independent targeted Release artifact
> runs proved that a Release-only source branch and a Debug-only leaf source do
> not prevent the unconditionally linked static Diagnostic package product from
> pulling HandoffContract into the final Release Mach-O. SwiftPM 6.3 target
> dependency conditions support platform/trait, not build configuration, and the
> measured Debug App link list expands the Diagnostic product plus all transitive
> package objects. Manual object linking is rejected. ii-b1 therefore uses one
> Debug-only diagnostic native target plus one dependency-free Release-shell
> native target, both compiling the same physical harness source. The verifier
> must not be weakened.
>
> Post-topology affected RED correction: the existing Swift structural test
> correctly rejected the native-target count change. The original nine-path
> list omitted that necessary contract owner. The frozen surface is therefore
> corrected to ten non-document paths by adding only
> `InvestigationMachineTargetBoundaryTests.swift`; the 1,900-line ceiling is
> unchanged and the checkpoint remains below the mandatory fourteen-path split
> threshold.

## 1. Decisions Closed Before Coding

### 1.1 The old diagnostic remains intact

The existing `--stornaut-investigation-runtime-config=<absolute path>` Debug
diagnostic remains a separate explicit path. ii-b1 adds a zero-behavior-argument
inherited-FD path; it does not replace, rename or weaken the old config-path
composition. No ordinary App path gains either diagnostic.

The inherited path is selected only in the dedicated diagnostic Debug build when
the process has exactly one command-line argument, the executable itself. Any
behavior argument, environment selector, config path, fallback endpoint or mixed
activation is invalid. Tests may suppress `@main` execution through the existing
XCTest host check, but no production environment variable activates the path.

### 1.2 The SwiftPM leaf is state, not system authority

The package target `StornautInvestigationDiagnostic` gains a dependency only on
`StornautInvestigationHandoffContract`. Its Debug-only new source owns a
package-scoped
state machine over already-admitted values and injected operations. It does not
open, inspect, read or write a descriptor; read a clock; inspect a process; use
Security/XPC; read argv/environment; or create filesystem/network/cleanup state.

The package state machine owns exact protocol order and one terminal result. It
consumes:

- one already-decoded `InvestigationHandoffEpochBootstrap`;
- injected pre-drop and post-drop process claims/evidence;
- injected configuration acknowledgement;
- one injected retirement handle; and
- injected typed incoming/outgoing STNH frames.

The operations seam is package-scoped and closed to the exact transitions. It
does not accept commands, executable names, paths, endpoints, PIDs, signals or
arbitrary bytes. ii-b1 tests use deterministic fakes. Concrete identity drop,
strict configuration decoding, no-auth retirement/handle production and Darwin
I/O remain ii-b3 responsibilities. Therefore the production ii-b1 runner is
allowed to fail closed as implementation-unavailable after shell admission; it
cannot fabricate a successful handle or run.

### 1.3 One thin public entry, no public state machine

The native App cannot access Swift `package` declarations. The new diagnostic
source therefore exposes exactly one public no-argument entry point with a
closed return code/result. In ii-b1 this entry always returns
`concreteAdapterUnavailable`: it does not receive the native FD-admission result,
inspect or consume FD 7, touch mutable/global state, or construct a successful
runner. b3 may change only its internal implementation after adding the concrete
package adapter; it may not widen this public signature. The entry does not
expose the state machine, operations protocol, descriptor, wire bytes, process
claims or transition methods. There is no public initializer that accepts
caller-minted authorization facts.

SwiftPM tests use `@testable import StornautInvestigationDiagnostic` to exercise
the package state machine directly. The dedicated native App tests exercise only
activation, fixed descriptor admission and the thin entry/result mapping.

### 1.4 Native harness owns one fixed FD 7 admission

Only the existing dedicated diagnostic App harness may inspect descriptor `7`.
The descriptor number is a compile-time constant. Before any byte is consumed,
the harness must prove through one injected/testable Darwin adapter that:

- `fcntl(F_GETFD)` and `fcntl(F_GETFL)` succeed, and
  `(statusFlags & O_ACCMODE) == O_RDWR`;
- the descriptor is open and is not redirected from stdin/stdout/stderr;
- `getsockopt(SOL_SOCKET, SO_TYPE)` is exactly `SOCK_STREAM`;
- `getsockname` and `getpeername` both report `AF_UNIX`;
- the connected peer exists; and
- no caller-selected descriptor or endpoint is used.

The redirection check is exact. The harness captures FD 7's `fstat` file-node
identity, then examines descriptors 0, 1 and 2. An open stdio descriptor must
have a successful `fstat` and a distinct node identity. A closed stdio descriptor
is accepted only when `fcntl(F_GETFD)` fails with `EBADF`; every other lookup or
`fstat` error fails closed. This rejects a duplicated socket endpoint aliased onto
stdio rather than relying on descriptor-number inequality.

After that admission, the harness invokes the no-argument public entry. In b1 the
entry deliberately ignores no result—none is passed—and returns
`concreteAdapterUnavailable` without consuming bytes. The later concrete runner
will independently bind the peer's audit/signing identity before consuming the
STNP prelude. ii-b1 does not pretend socket shape alone proves peer identity.
Failure is terminal and consumes no bytes.

### 1.5 Dedicated Release must build but contain no diagnostic leaf

Current-source measurement found that the dedicated Release target fails to link
with missing `_main` because the only harness source is wholly guarded by
`DEBUG && STORNAUT_INVESTIGATION_DIAGNOSTIC`. ii-b1 fixes this in the same native
harness source with a minimal Release-only `@main` shell that has no import or
reference to `StornautInvestigationDiagnostic`, HandoffContract, FD 7 or any
diagnostic symbol and returns/shows only an empty inert App.

This shell exists solely so Release can be built and inspected. Missing Debug
implementation is never called runtime rejection. Artifact testing then proved
that source guards alone are insufficient: Xcode links the complete static
`StornautInvestigationDiagnostic` product into both configurations when one
native target owns that Frameworks entry. Even after the new leaf source was
entirely wrapped in `#if DEBUG`, the Release Mach-O still contained
`StornautInvestigationHandoffContract`.

The accepted topology is therefore exact:

- existing native target `StornautInvestigationDiagnosticApp` has only its
  Debug configuration, continues to compile the one harness source, owns the
  Diagnostic package product, helper/driver target dependencies and copy phases,
  and hosts the existing Debug tests;
- new native target `StornautInvestigationDiagnosticReleaseShell` has only one
  Release configuration, compiles a second PBX build-file membership referring
  to that same harness source, has empty Frameworks/Resources phases, and has no
  package product, native dependency or Copy Files phase;
- the new target has a unique product/module/bundle identity so its output cannot
  collide with the Debug diagnostic product; and
- no checked-in scheme is added. Xcode's target-generated scheme is used only by
  the targeted verifier; the existing shared diagnostic scheme remains Debug
  and continues to own Debug tests/helper/driver.

The exact matrix becomes:

- ordinary Debug/Release: no inherited-handoff symbols;
- dedicated Debug: public entry + package state machine present;
- dedicated Release shell: builds successfully, contains exactly its native main
  Mach-O, and has no Diagnostic/Handoff/leaf/helper/driver symbol or artifact; and
- both native targets compile exactly the same one physical harness source.

The Release boundary is not accepted from source intent, dead stripping or a
verifier-selected happy path. Structural gates require the old diagnostic target
to have no Release configuration and the new shell target to have no dependency
edge. The final shell Mach-O scan independently proves the leaf and contract are
absent.

## 2. Frozen State Machine

The package state machine consumes the exact ii-b0a/b0c contracts and allows
only this order:

```text
admitted STNP epoch UUID/deadline
-> injected pre-drop root claim
-> emit PRE_DROP_READY using exact STNP facts
-> accept exact DROP_RELEASE
-> injected irreversible drop result
-> emit DROP_EVIDENCE
-> accept CONFIGURATION
-> injected strict configuration result
-> emit CONFIGURATION_ACK
-> emit HELLO
-> injected retirement handle
-> emit HANDLE
-> accept exact ACK for that handle
-> accept RELEASE
-> emit ALIVE
-> injected write half-close / strict EOF proof
-> accept EXIT
-> terminal success result
```

Every STNH frame must repeat the STNP UUID/deadline. App PID/PID-version/ASID are
stable across the drop, and EUID changes from root to 501 at the exact frozen
transition. Incoming frames must carry the injected admitted driver identity.
Outgoing frames must carry the correct pre/post-drop App claim. The handle ack
must equal SHA-256 of the complete exact HANDLE transcript.

Replay, skip, reorder, duplicate, foreign sender, UUID/deadline drift, payload
drift, wrong handle ack, premature/partial EOF, post-half-close write, or any
operation failure is terminal. Terminal state accepts no further event. After
ALIVE, only write-half-close followed by EXIT is successful; transport loss is
terminal failure and cannot become success.

The state/result is non-`Codable`, non-persisted and non-admitting. It cannot
claim installed-L2, helper claim/release, driver cleanup or readiness.

## 3. Exact Implementation Surface and Budget

ii-b1 may change exactly these ten non-document paths and at most 1,900
added-or-changed lines:

1. `Package.swift` — add only Diagnostic -> HandoffContract;
2. `Sources/StornautInvestigationDiagnostic/InvestigationHandoffAppLeaf.swift`;
3. `StornautApp/Diagnostics/InvestigationRuntimeDiagnosticHarness.swift`;
4. `StornautAppTests/InvestigationRuntimeDiagnosticTests.swift`;
5. `Tests/StornautInvestigationTests/InvestigationHandoffAppLeafTests.swift`;
6. `Stornaut.xcodeproj/project.pbxproj` — only the exact single-configuration
   Release-shell target and removal of the old target's Release configuration;
7. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`
   — update the existing native graph contract for the exact Debug/shell split;
8. `scripts/verify-investigation-boundaries`;
9. `scripts/verify-app-release-boundaries`; and
10. `scripts/verify-contract`.

No scheme file changes. The dedicated Debug App, Release shell and test targets
continue to reuse the existing one-source harness/test files. Existing config-path
composition, Runtime, Lifecycle, Machine, DriverSupport and helper sources remain
unchanged. Approaching the ceiling requires another split before coding.

## 4. Tests-First and Gates

The initial RED suite must exist before business implementation and cover:

- the entire state sequence and exact emitted frames;
- each replay/skip/reorder/duplicate/foreign sender/epoch/deadline/payload drift;
- pre/post-drop claim and handle-ack joins;
- every injected operation failure;
- every partial/premature EOF and post-ALIVE/terminal event;
- zero-argument versus legacy config-path versus mixed activation;
- fixed FD 7 and all socket-shape negatives;
- exact `O_RDWR`, stdio-open/closed/error and same-node alias negatives;
- proof that the no-argument b1 public entry cannot receive admission facts and
  always returns `concreteAdapterUnavailable`;
- Release inert shell/source condition; and
- exact Debug-only diagnostic versus dependency-free Release-shell Xcode graph;
  and structural absence of public state/operations, concrete lifecycle/auth/
  model/cleanup/driver authority and Xcode membership drift.

Validation order is: tests-first RED -> focused SwiftPM leaf tests -> dedicated
App tests -> exact structural/source gates -> affected Investigation/App suites ->
Debug dedicated App build/test -> dependency-free Release-shell build, exact
single-Mach-O topology and symbol absence ->
ordinary Debug/Release absence -> one clean staged-only serial -> independent
review -> commit/push.

The applicable App gate is targeted and may be added as an exact mode/section of
the existing release-boundary script; it must not run unrelated privileged,
installer, real-model or Trash actions. `scripts/verify --full` remains forbidden.

## 5. Non-Claims

ii-b1 does not implement a real identity drop, configuration adapter, retirement
handle, Lifecycle/helper claim, DriverSupport client, spawn, installed-L2, epoch
composition or privileged machine run. It does not install, call sudo, authenticate
or invoke a model, accept ADR 0018, enable production Deep Dive or claim readiness.

ADR 0018 remains Proposed, Task 39 remains incomplete, production Deep Dive
remains unavailable, real Trash remains closed and the remaining authoritative
full verifier remains reserved for L3c4.
