# ADR 0016: Investigation Lifecycle Supervisor

> Status: Accepted for R3 behaviorReady candidate; R5 signed-App packaging
> gate pending
>
> Date: 2026-08-12
>
> Decision owners: Stornaut maintainers
>
> Governing boundaries:
> [ADR 0004](0004-codex-file-read-isolation.md) and
> [ADR 0013](0013-capability-first-runtime-containment.md)

## Context

R3 proved that a normal macOS process group is not a complete investigation
process container. A sandboxed descendant can call `setsid()` directly or use
`POSIX_SPAWN_SETSID`, become a new session/process-group leader, outlive the
Codex wrapper and be reparented to PID 1. Explicit `launchctl bootout --wait`
also leaves that detached descendant alive.

Supported unprivileged alternatives do not close the hard-gate race:

- modern macOS does not support recursive kqueue `NOTE_TRACK`;
- `NOTE_FORK` plus `p_puniqueid` has an unavoidable fast-exit intermediate
  race and relies on a private proc-info flavor;
- PPID, environment and process-name scans lose authority after reparenting;
- Codex cannot be required to cooperate with a parent-death pipe;
- Endpoint Security fork events are notify-only and require a restricted
  entitlement;
- an unprivileged process cannot create or inspect an arbitrary audit session.

On 2026-08-12 the user first approved reopening R3 architecture research, then
explicitly approved full R3 permission to evaluate and implement the required
privileged lifecycle boundary.

## Evidence

Anonymous local Spikes on Apple Silicon macOS 26.5.1 observed:

```text
launchctl bootout --wait:
  leader stopped
  POSIX_SPAWN_SETSID descendant remained live
  descendant heartbeat continued
  descendant PPID became 1

launchd SessionCreate:
  parent and POSIX_SPAWN_SETSID child shared one audit session ID
  the child could not change its audit session (EPERM)
  a relaunched job received a new audit session ID

audit-token identity:
  task_name_for_pid + TASK_AUDIT_TOKEN returned pid, ASID and pidversion
  proc_signal_with_audittoken provides identity-checked signalling
```

These facts make an audit session a stronger membership identity than PPID,
POSIX session or process group. They do not by themselves prove cleanup; the
R3 Spike must still prove a bounded freeze/rescan/kill algorithm and helper
crash recovery.

The final R3 implementation and privileged composition probe proved:

```text
fixed-point freeze/rescan/kill:
  direct setsid descendant drained
  POSIX_SPAWN_SETSID descendant drained
  double-fork/reparented descendant drained

identity reduction:
  non-root UID and primary GID observed
  kernel-bounded supplementary credential groups observed
  outer Codex Seatbelt started only after reduction

recovery:
  managed-proxy owner drained with the investigation
  relaunched supervisor received a distinct ASID
  same-boot stale lease drained
  launchd/process/temporary-root residue was zero
```

Evidence:

```text
scripts/probe-codex-r3-audit-session-lifecycle
/tmp/stornaut-r3-audit-session-combined-final.log
SHA-256 509140cdfc431474e776c3b87a3fd1fc303cc34e420850f4f3dc800282dddb29
probe.verdict=behaviorReadyCandidate
```

macOS documents that `initgroups(3)` stores at most `NGROUPS_MAX` group IDs in
the process credential cache. Additional OpenDirectory memberships are
resolved dynamically and are not required to appear in `getgroups(2)`. The
probe compares the exact kernel-bounded group set and still fails on any
unexpected inherited credential group.

## Decision

### 1. Add a narrow lifecycle supervisor

Stornaut may add one launchd-managed lifecycle supervisor for Codex
investigations. The production candidate is an on-demand LaunchDaemon bundled
with the signed App and registered through the current ServiceManagement API.
R3 may use an explicitly authorized, ephemeral system-domain launchd job to
measure the same process and audit-session behavior before notarized packaging
is available.

The supervisor is not:

- a cleanup Executor;
- a generic root shell;
- a file probe;
- a network proxy;
- a scheduler, monitor or telemetry service;
- a login item;
- a route to Trash, Registered Actions or Policy decisions.

It stays dormant when no investigation or stale lease exists. Its launchd
presence is the user-approved narrow exception required for crash-safe process
lifecycle containment; it does not authorize any other background product
scope.

### 2. Use one kernel audit session per investigation

The trusted supervisor:

1. accepts one closed launch request from an authenticated Stornaut App;
2. creates a new audit session before the untrusted process starts;
3. drops the child to the requesting user's UID/GID and supplementary groups;
4. launches only the closed Codex outer-sandbox/App-Server profile;
5. records a root-owned, versioned lease containing only anonymous
   investigation identity and audit-session identity;
6. retains lifecycle authority while the App drives stdio/App Server.

The child cannot choose an ASID, PID, signal, executable, arbitrary argument
list, path or lease location through the helper protocol. Diagnostic builds
may launch a checked anonymous fixture under a separate Spike-only command;
that command is not part of the product protocol.

### 3. Close cancellation with audit-token identity

Cancellation and recovery enumerate process identities, not names or current
PPIDs. For the target ASID the supervisor performs:

```text
enumerate full audit tokens
→ identity-checked SIGSTOP each member
→ rescan to a fixed point
→ identity-checked SIGKILL each frozen member
→ rescan until the ASID has no process
```

Every signal uses the complete `audit_token_t`, including pidversion. A PID
obtained from a process-table scan is never signalled unless a fresh audit
token still identifies the target ASID. PID-only fallback is forbidden.

The fixed-point loop is bounded. Enumeration failure, token ambiguity,
unexpected UID/session membership, inability to freeze, inability to kill or
remaining membership yields `behaviorBlocked`; it never reports successful
cleanup.

### 4. Recover supervisor/App failure

- App connection invalidation triggers cancellation.
- Supervisor abnormal exit is relaunched by launchd.
- Each supervisor launch has an audit session distinct from stale
  investigation sessions.
- Startup reads only root-owned leases, revalidates their schema/owner/mode
  and drains stale ASIDs before accepting new work.
- Normal completion removes the lease only after the target ASID is empty.
- Reboot makes prior processes nonexistent; stale leases are still validated
  and retired before new work.

R3 tests the corresponding behavioral composition through live cancellation,
forced supervisor exit/relaunch, fixed-point fork pressure and detached
descendants. Merely observing a launchd restart is not a cleanup proof; the
admitting evidence requires the stale ASID to be empty and a new supervisor
ASID to be observed.

### 5. Keep Codex authority unchanged

The helper does not weaken ADR 0004/0013:

- Codex and descendants still cannot write user data.
- Runtime writes stay inside the private ephemeral Runtime Home.
- Public network still uses the one same-investigation managed HTTP proxy.
- Direct public bypass, arbitrary localhost/private/link-local targets and
  unrelated Unix sockets remain blocked.
- The helper's Mach/XPC service is denied to the Codex sandbox and also
  authenticates its caller.
- No Codex event, model output or tool request becomes a helper command.
- No PolicyDecision, authorization, Trash, Registered Action or Executor
  object crosses the helper protocol.

Root authority belongs only to the small trusted supervisor implementation;
the Codex process is always launched after identity and privilege reduction.

## Rejected Alternatives

- accepting orphan risk;
- disabling shell, unified exec, skills or subagents;
- process-group-only cleanup;
- `launchctl bootout` as whole-tree cleanup;
- polling PPID/environment markers;
- `NOTE_FORK`/`p_puniqueid` as an admitting security boundary;
- private coalition APIs;
- Endpoint Security notification as a process container;
- giving Codex root or `danger-full-access`;
- a generic privileged `spawn(argv:)` or `signal(pid:)` API;
- a permanent always-running monitor.

## Consequences

Positive:

- membership survives `setsid()`, double-fork and reparenting;
- identity-checked signals avoid PID-reuse kills;
- helper/App crashes have a launchd-owned recovery path;
- the full capability-first Agent surface remains available;
- no Endpoint Security entitlement or kernel/system extension is required.

Costs:

- the App gains a privileged helper packaging and consent surface;
- production LaunchDaemon packaging requires signed/notarized evidence;
- audit-session APIs are deprecated and must be re-probed on every supported
  macOS release;
- the helper becomes a security-critical, deliberately tiny component;
- install/update/uninstall and stale-lease behavior require their own tests
  and documentation.

## Residual Risks

1. ServiceManagement registration, install/update/uninstall behavior and the
   actual signed App/helper topology are not admitted in R3 and remain R5
   gates.
2. Helper caller authentication has a closed pure contract in R3; audit-token
   code-signing validation and Mach/XPC service denial require signed-App
   adversarial evidence in R5.
3. The privileged probe uses an explicitly authorized ephemeral system-domain
   job. It does not prove FDA/TCC inheritance or distribution viability.
4. App/helper simultaneous crash pressure must be repeated from the packaged
   signed topology rather than inferred from the Spike.
5. Audit-session APIs may be removed in a future macOS release; runtime
   availability failure must fail closed.
6. A root helper implementation defect has higher impact than an
   unprivileged process defect, so zero unresolved P0–P2 is mandatory.

## Validation

R3 changed this ADR to `Accepted for R3 behaviorReady candidate` after:

```text
pure helper protocol and lease tests pass
anonymous root-context ASID lifecycle diagnostic passes
setsid / POSIX_SPAWN_SETSID / double-fork descendants are reclaimed
App-owner and helper-crash recovery pass
PID-reuse and unrelated-process canaries remain untouched
Codex filesystem/network/auth containment diagnostics pass
complete StornautCodexTests and serial swift test pass
Xcode App build/tests and scripts/verify --headless pass
independent review has zero unresolved P0–P2
```

Measured R3 results:

```text
StornautLifecycle focused tests: 30/30 passed
closed Codex runtime focused tests: 35/35 passed
complete StornautCodexTests: 130/130 passed; four opt-in diagnostics skipped
serial SwiftPM: 402/402 passed
anonymous containment matrix: behaviorReadyCandidate
synthetic gpt-5.6-luna App Server diagnostic: observed
scripts/verify --headless: passed
XcodeBuildMCP macOS tests: 123/123 passed
```

R5 still owns signed-App observed capability and helper-packaging evidence. R6
still owns final admission. Deep Dive remains unavailable throughout R3.
