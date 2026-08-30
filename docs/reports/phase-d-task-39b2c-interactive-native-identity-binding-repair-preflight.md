# Phase D Task 39B2c Interactive-Native Identity Binding Repair Preflight

> Status: frozen / implementation pending / non-admitting
>
> Date: 2026-08-30
>
> Baseline: `44ddabc278f0b41ad71821ffef4bb9133527bbfb`
>
> Remaining order: interactive-native identity binding repair -> ii-c ->
> L3c3d -> L3c4

## 1. Defect and Required Outcome

The signed Task 39 configuration binds `binding.codexExecutableSHA256` to the
installed native Codex Mach-O. The helper-owned interactive path does not carry
that digest into `CodexContainedInteractiveSession`; its production plan
builder locates and launches the npm `codex.js` wrapper through a pathname-only
`posix_spawn`. A successful interactive run therefore does not prove that the
executed Codex image is the native image named by the signed binding.

The required end-to-end relation is:

`signed binding native digest -> strict Lifecycle request -> broker/helper ->
contained-session expected digest -> live native lease -> suspended child image
identity -> observed start digest -> strict response -> App transport evidence`.

Neither a wrapper digest nor a caller-selected path may substitute for the
signed native digest. The npm wrapper may be used only to discover the fixed
package layout and must never be executed by this path.

## 2. Platform Evidence and Launch Decision

The installed macOS 26 SDK exposes pathname-based `execve`/`posix_spawn`, but
no public `fexecve` or `execveat`. A local no-network/no-root probe confirmed
that invoking a Mach-O through `/dev/fd/N` fails with `EACCES`; that route is
rejected.

The same probe confirmed that a process launched with
`POSIX_SPAWN_START_SUSPENDED` exposes its loaded main-image vnode through
`proc_pidinfo(PROC_PIDREGIONPATHINFO, 0, ...)` before user code is resumed.
The accepted launch sequence is:

1. resolve and retain the installed native executable with the existing
   no-follow identity lease;
2. require its complete SHA-256 to equal the signed expected digest;
3. revalidate the held and named node immediately before spawn;
4. spawn that native pathname suspended, preserving the existing pipes,
   close-on-exec and process-group contract;
5. use deadline-bounded `waitpid(pid, ..., WUNTRACED | WNOHANG)` polling to
   observe the exact child PID's initial suspended stop and require raw status
   `0x7f`;
6. identify exactly one main executable mapping through
   `PROC_PIDREGIONPATHINFO` and compare its device, inode, generation and size
   with the held lease;
7. revalidate held and named identity, then send `SIGCONT` only after every
   check agrees; otherwise kill and exactly reap the child, close all owned
   descriptors and fail start; and
8. retain the lease through retirement and revalidate it after exact reap before
   returning successful retirement evidence.

This closes replace-at-spawn-and-restore for the directly spawned outer image
without claiming a nonexistent descriptor-exec API. It remains within ADR
0018's trusted-local-operator/local-only scope. Complete atomic protection for
the later Codex-internal inner launch would require a root-owned immutable
installation or upstream self-attestation and is not claimed here.

## 3. Exact Scope and Budget

An initial audit enumerated nineteen possible paths. The final design avoids
that oversized surface: it does not modify `CapabilityRuntimeWorker`, does not
add a fixture target, exercises the native identity primitive through its direct
existing test suite, keeps the generic `spawnDiagnosticProcess` implementation
unchanged, and places source/mutation/scope closure in one existing verifier.

The implementation may change exactly these fourteen non-document paths:

1. `Sources/StornautCodex/Runtime/CodexNativeExecutableIdentity.swift`;
2. `Sources/StornautCodex/Runtime/CodexContainedInteractiveSession.swift`;
3. `Sources/StornautLifecycle/LifecycleInteractiveSessionContract.swift`;
4. `Sources/StornautLifecycle/LifecycleInteractiveSessionBroker.swift`;
5. `Sources/StornautInvestigationRuntime/InvestigationLifecycleAppServerTransport.swift`;
6. `Sources/StornautInvestigationDiagnostic/InvestigationRuntimeDiagnosticComposition.swift`;
7. `StornautLifecycleHelper/main.swift`;
8. `Tests/StornautCodexTests/CodexNativeExecutableIdentityTests.swift`;
9. `Tests/StornautCodexTests/CodexContainedInteractiveSessionTests.swift`;
10. `Tests/StornautLifecycleTests/LifecycleInteractiveSessionContractTests.swift`;
11. `Tests/StornautLifecycleTests/LifecycleInteractiveSessionBrokerTests.swift`;
12. `Tests/StornautInvestigationTests/InvestigationLifecycleAppServerTransportTests.swift`;
13. `Tests/StornautInvestigationTests/InvestigationHandoffConcreteCompositionTests.swift`; and
14. `scripts/verify-investigation-boundaries`.

The maximum changed-line budget is 2,000 non-document lines: production 750,
tests 850 and verifier 400. These category ceilings are independent. A
fifteenth path, line 2,001, a second wire field, a new package target/dependency,
or a change to an excluded path stops implementation for re-preflight.

## 4. Closed Contract

- `LifecycleInteractiveSessionRequest` advances from v2 to v3 and requires
  `codexExecutableSHA256` only on start; write/read/retire require nil and
  remain bound through the existing `configurationSHA256` session identity.
- `LifecycleInteractiveWorkerConfiguration` and
  `CodexContainedInteractiveSessionConfiguration` carry only the expected
  digest, never a path, descriptor, argv or environment choice.
- Both diagnostic composition construction points source the value only from
  the already strict-decoded and receipt-joined
  `configuration.binding.codexExecutableSHA256`.
- The broker retains the expected digest and compares it with a typed
  worker-observed start digest before returning success.
- `LifecycleInteractiveSessionResponse` advances from v4 to v5 and carries
  the observed digest only on `.started`; App transport validates it against
  the request and retains the accepted value through retirement evidence.
- The post-drop worker resolves the fixed installed native from the npm package
  layout, requires the lease digest to equal the expected digest, and never
  executes `codex.js`.
- A dedicated launcher defined with the contained session implements the
  suspended-stop/image/revalidation sequence. Only
  `CodexContainedInteractiveSession` may invoke it.
- The session enters active state only after a typed local launch receipt exists.
  After exact group termination and reap, lease revalidation must succeed before
  owner-retirement evidence can succeed.

The existing `spawnDiagnosticProcess` body and all its callers remain
unchanged. Capability/runtime-diagnostic and App Server runner paths must not be
redirected to the new launcher. The Objective-C XPC method remains a single
Data envelope. Signed binding, diagnostic configuration, machine contract, App
Server JSON-RPC API, package graph and public path/FD authority remain unchanged.

## 5. Tests First and Mutation Matrix

RED evidence must compile against the existing API and demonstrate that encoded
start requests omit the signed native digest, transport accepts a start with no
observed native identity, and contained production code selects
`installation.executableURL` (the wrapper) for both containment argv and
pathname spawn.

GREEN coverage must include:

- request v3 and response v5 round trips plus missing, unknown, uppercase,
  malformed, misplaced and foreign digest rejection;
- exact digest propagation through both composition constructors, transport,
  broker and helper;
- native rather than wrapper selection and identical outer/inner native paths;
- worker-observed digest mismatch rejection before `.started`/active;
- installed lease mismatch/drift and child loaded-image mismatch;
- exact initial-stop observation, wrong PID/status/timeout rejection and resume
  only after child-image and lease agreement;
- replace-and-restore around spawn, cleanup on every pre/post-spawn failure,
  normal retirement and post-reap lease drift; and
- unchanged deadline, byte-budget, process-group and one-shot semantics.

Dedicated mutations must reject removal or substitution of the signed-binding
source edge, request/response digest constraints, broker/transport comparison,
native resolver, suspended flag, exact initial-stop observation, child-image
comparison, pre-resume lease revalidation, mismatch kill/reap, post-reap lease
revalidation and its ordering, retirement digest equality, and promotion of
failed-start digest data into successful retirement evidence. The staged-scope
gate must compare the exact fourteen paths, modes, blobs and binary numstat.

## 6. Validation and Non-Claims

Use structural checks, focused Codex/Lifecycle/Investigation suites, applicable
targeted Debug/Release helper and diagnostic-App builds, one clean staged-only
serial regression, and independent review. Run bare
`scripts/verify-investigation-boundaries`,
`scripts/verify-app-release-boundaries` and `scripts/verify-contract` only
after focused closure; the two unmodified aggregate scripts remain validation
consumers rather than implementation paths.

This checkpoint runs no root/sudo, installed App/helper/driver/gate campaign,
product XPC, Codex auth/model/network or `scripts/verify --full`. It does not
modify `CapabilityRuntimeWorker` or the generic `spawnDiagnosticProcess`,
does not create, read, write or use an install/runtime mutable sidecar as
identity or admission input, does not claim sidecar
`codex-code-mode-host`/`rg`/`zsh` runtime-use identity, change the signed
binding schema, accept ADR 0018, enable production Deep Dive or claim machine
readiness.

After this repair is complete, the remaining order is
`ii-c -> L3c3d -> L3c4`. Task 39 remains incomplete until L3c4.
