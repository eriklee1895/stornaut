# Capability-First Runtime R3 Review

> Status: Passed — behaviorReady candidate; R4 later reached `protocolReady`
>
> Date: 2026-08-12
>
> Gate: OS containment, Runtime Home, authentication and lifecycle

## 1. Review Scope

R3 evaluated the R2 configuration candidate against:

- installed `codex-cli 0.147.0`;
- OpenAI Codex tag `rust-v0.147.0`, commit
  `be6e8eac029b183056b7e4402879f15d2c85f61b`;
- macOS Seatbelt, process-group, kqueue and launchd behavior;
- the exact ADR 0013 same-investigation managed-proxy exception;
- owner-only Runtime Home and closed external App Server authentication;
- direct and nested process lifecycle adversarial probes;
- the user-approved privileged audit-session supervisor architecture in
  [ADR 0016](../adr/0016-investigation-lifecycle-supervisor.md).

The final R3 candidate retains the closed runtime implementation and the small
`StornautLifecycle` contract/drainer foundation. It does not retain a generic
root launcher, signed ServiceManagement package, product Deep Dive coordinator
or Executor route.

Final review scope:

```text
Sources/StornautCodex/Runtime/CodexRuntimeProfile.swift
Sources/StornautCodex/Runtime/CodexContainmentPolicy.swift
Sources/StornautCodex/Runtime/CodexRuntimeWorkspace.swift
Sources/StornautCodex/Runtime/CodexRuntimeEnvironment.swift
Sources/StornautCodex/Runtime/CodexRuntimeAuthProjection.swift
Sources/StornautCodex/Runtime/CodexAppServerRuntime.swift
Sources/StornautCodex/Runtime/CodexAppServerSessionRunner.swift
Sources/CLifecycleSupport/
Sources/StornautLifecycle/
Tests/StornautCodexTests/CodexRuntimeProfileTests.swift
Tests/StornautCodexTests/CodexContainmentPolicyTests.swift
Tests/StornautCodexTests/CodexRuntimeWorkspaceTests.swift
Tests/StornautCodexTests/CodexRuntimeEnvironmentTests.swift
Tests/StornautCodexTests/CodexRuntimeAuthProjectionTests.swift
Tests/StornautCodexTests/CodexAppServerRuntimeTests.swift
Tests/StornautCodexTests/CodexAppServerSessionRunnerTests.swift
Tests/StornautCodexTests/RealCodexR3AppServerDiagnosticTests.swift
Tests/StornautLifecycleTests/
scripts/probe-codex-r3-containment
scripts/probe-codex-r3-audit-session-lifecycle
docs/plans/active/task-r3-implementation-brief.md
docs/plans/active/capability-first-codex-runtime-gate.md
docs/adr/0013-capability-first-runtime-containment.md
docs/adr/0016-investigation-lifecycle-supervisor.md
docs/upstream-studies/epic-5-capability-first-runtime.md
R3 status routing and this report
```

## 2. Configuration Erratum

R3 source review found that Codex `0.147.0` defaults
`network.enable_socks5` to true. The approved ADR 0013 exception permits one
managed HTTP listener, not a second SOCKS listener.

The R2 closed profile and R1 probe now set both:

```text
permissions.<profile>.network.enable_socks5=false
features.network_proxy.enable_socks5=false
```

The corrected secret-free profile digest is:

```text
38356703d195834c88ed5b9388f85a5e74737139278bef2c11c9b4cd250f4e65
```

This correction narrows authority. R2 remains configuration evidence; R3
behavioral readiness comes from the separate containment, App Server and
lifecycle proofs below.

## 3. Runtime and Containment Evidence

The final anonymous and external-auth diagnostics observed:

- full-disk read-only access succeeded;
- Runtime Home writes succeeded;
- the complete target mutation matrix failed;
- the auth-source path was unreadable under an explicit deny;
- one managed HTTP proxy allowed public HTTPS;
- direct public, arbitrary loopback/private/link-local, Unix-socket and local
  binding attempts failed;
- hostname/redirect and replacement/mount-boundary variants remained
  contained;
- proxy identity was one random nonzero loopback HTTP listener and proxy crash
  fallback failed closed;
- external App Server authentication completed one synthetic
  `gpt-5.6-luna` turn;
- no Runtime Home `auth.json` was created;
- the source auth descriptor identity, owner, mode and single-link contract
  were bound before projection;
- unmapped inherited writable descriptors were closed before spawn.

Final evidence:

```text
/tmp/stornaut-r3-containment-post-review.log
SHA-256 d5c46588a1d1737eac232b3c44f1a6ed533aba6c003631b7498fff11c5de06a2

/tmp/stornaut-r3-real-app-server-post-review-retry.log
SHA-256 fdd2ea2b00672650719a567c60bcf668a68323050f0165eca8c48bf4d198edf6
```

The real-model result is recorded only as observed App Server/model evidence.
It is not signed-App containment, FDA/TCC inheritance, Browser Use or
no-Executor proof.

## 4. Lifecycle Finding and Resolution

### R3-01 — New-session descendants escape lifecycle containment

**Severity:** P1 hard-gate containment defect
**Status:** Confirmed for process-group design; resolved by ADR 0016 candidate
**Disposition:** original design rejected; audit-session design admitted at R3

The trusted parent used an independent process group and killed that group on
timeout, cancellation, normal leader exit and failure. A sandboxed descendant
could nevertheless call `setsid()` and become leader of a new session and
process group. After the original Codex/sandbox leader exited, the descendant
was reparented to PID 1 and remained live.

Trying to close the direct syscall path with:

```scheme
(deny syscall-unix (syscall-number SYS_setsid SYS_setpgid))
```

was insufficient. A descendant used:

```c
posix_spawnattr_setflags(&attributes, POSIX_SPAWN_SETSID)
```

and still created a new session, survived the sandbox wrapper and continued
updating an anonymous heartbeat.

A temporary per-user launchd job with
`AbandonProcessGroup=false` also failed to reclaim the new-session descendant
after the job leader exited. This matches launchd's documented cleanup of
remaining members of the job's original process group, not arbitrary new
sessions.

Final reproducible evidence:

```text
scripts/probe-codex-r3-lifecycle-escape

lifecycle.direct_setsid_escape=observed
lifecycle.posix_spawn_setsid_escape=observed
lifecycle.launchd_job_escape=observed
lifecycle.cleanup=complete
probe.verdict=behaviorBlocked

/tmp/stornaut-r3-lifecycle-escape-probe-final.log
SHA-256 f25700e0e35178910cda4809468ea1aa37a9936abaec4100fb6b74e49fde3557
```

The probe records only anonymous PIDs and boolean verdicts. It force-cleans
all recorded PIDs and the unique temporary launchd label before returning.

Independent review found and corrected three defects in the evidence harness:

1. the first cleanup implementation could leave its temporary root after
   SIGTERM, even though no helper survived;
2. the first escape assertion proved a live heartbeat but did not also require
   the wrapper/job leader to be stopped and the child to be reparented.
3. the first success path printed `lifecycle.cleanup=complete` before its EXIT
   trap had actually removed the temporary root.

The final harness uses explicit idempotent exit/signal handlers, recovers PIDs
from evidence files and the unique probe-root command line, verifies no PID
reuse before signalling, requires child `PPID == 1`, and requires launchd to
report the temporary job leader as stopped.

SIGTERM cleanup evidence:

```text
interrupt_exit=143
probe_root_residue=0
launchd_job_residue=0
process_residue=0

/tmp/stornaut-r3-lifecycle-interrupt-final.log
SHA-256 196714841f571245c568bf0dbf33ba2ac2a42686ab9e3930ada0e025d803557a
```

### R3-01 Resolution — Audit-session lifecycle supervisor

The user explicitly approved a narrow privileged lifecycle supervisor after
reviewing the process-group no-go. The accepted design:

- creates one launchd audit session per investigation;
- records one root-owned, versioned anonymous lease;
- drops supplementary groups, GID and UID before the outer Codex sandbox;
- exposes only authenticated start/cancel by investigation ID;
- exposes no PID, signal, executable, argv, path, file, network, Policy or
  Executor operation;
- enumerates complete audit tokens and performs bounded
  `SIGSTOP → fixed-point rescan → SIGKILL → empty-session confirmation`;
- uses audit-token pidversion for identity-checked signalling;
- recovers same-boot stale leases under a relaunched supervisor with a
  different ASID.

Pure tests cover fork storms, member bounds, PID reuse, UID/ASID mismatch,
protected supervisor identity, vanish-before-freeze, lease symlink/hardlink/
mode/schema/boot binding and authorization-before-dispatch.

The final privileged composition combines:

```text
launchd SessionCreate
→ initgroups / setgid / setuid
→ outer codex sandbox and managed proxy
→ setsid / POSIX_SPAWN_SETSID / double-fork descendants
→ audit-token drain
→ helper restart and stale-lease recovery
```

Final evidence:

```text
/tmp/stornaut-r3-audit-session-combined-final.log
SHA-256 509140cdfc431474e776c3b87a3fd1fc303cc34e420850f4f3dc800282dddb29

lifecycle.live=drained
lifecycle.identity_drop=observed
lifecycle.outer_seatbelt=observed
lifecycle.audit_session_inheritance=observed
lifecycle.proxy_owner_drained=observed
lifecycle.combined=drained
lifecycle.recovery_new_audit_session=observed
lifecycle.recovery=drained
lifecycle.cleanup=complete
probe.verdict=behaviorReadyCandidate
```

An independent post-probe check found zero matching launchd labels, helper
processes or `/private/tmp/stornaut-r3-audit-lifecycle.*` roots.

The first combined run compared `getgroups(2)` against the unlimited
OpenDirectory list from `id -G` and incorrectly required 17 groups in a macOS
credential cache capped at `NGROUPS_MAX == 16`. `initgroups(3)` explicitly
documents this limit and dynamic membership fallback. The final probe compares
the exact kernel-bounded credential set and still rejects inherited root or
unexpected groups.

## 5. Alternatives Reviewed

| Alternative | Result |
| --- | --- |
| Existing process-group termination | Reject: escaped session has a different process group |
| Seatbelt deny `setsid`/`setpgid` | Reject: `POSIX_SPAWN_SETSID` still escapes |
| launchd user job cleanup | Reject: new-session descendant remains live |
| kqueue recursive `NOTE_TRACK` | Reject: unsupported on modern macOS |
| Poll current PPID tree | Reject: loses identity after reparenting and has PID-reuse races |
| Environment marker + global process scan | Reject: environment inspection is incomplete/racy and not crash-safe |
| Private coalition APIs | Reject: unsupported/private distribution surface |
| Endpoint Security/system extension | Reject: major product/permission expansion not approved |
| Generic privileged/root daemon | Reject: authority surface is unbounded |
| Narrow audit-session lifecycle supervisor | Accept after explicit user approval; closed contract and R3 behavior proved |
| Disable shell/subagents/process creation | Reject: violates ADR 0004 capability-first requirements |
| Accept orphan risk | Reject: violates mandatory cancellation/crash cleanup |

Only the narrow audit-session supervisor preserved the approved capability
surface while supplying identity-stable per-investigation lifecycle recovery.
It is not a general process, file or cleanup service.

## 6. Gate Result

- P0 unresolved: 0;
- P1 unresolved: 0;
- P2 unresolved: 0;
- filesystem integrity: contained for anonymous R3 matrix;
- managed-proxy transport: contained for anonymous R3 matrix;
- auth/App Server: observed with synthetic `gpt-5.6-luna` turn;
- process lifecycle: behaviorReady candidate;
- R3 outcome: `behaviorReady`;
- overall runtime gate: incomplete; R4–R6 remain required.

R4 remains not started because the user requested a pause after R3 for review.
R5 still owns signed-App helper packaging, caller authentication in the actual
XPC/Mach topology, FDA/TCC inheritance and capability observation. R6 still
owns final admission. Task 29 and production Deep Dive remain paused.

## 7. Verification

Required R3 evidence:

```text
swift test --filter StornautLifecycleTests
swift test --filter CodexContainmentPolicyTests
swift test --filter CodexRuntimeWorkspaceTests
swift test --filter CodexRuntimeEnvironmentTests
swift test --filter CodexRuntimeAuthProjectionTests
swift test --filter CodexAppServerRuntimeTests
swift test --filter CodexAppServerSessionRunnerTests
scripts/probe-codex-r3-containment
scripts/probe-codex-r3-audit-session-lifecycle
STORNAUT_RUN_R3_APP_SERVER_DIAGNOSTIC=1 swift test \
  --filter realCodexR3ExternalAuthAppServerDiagnostic
```

The phase also runs:

```text
swift test --filter CodexRuntimeProfileTests
swift test --filter StornautCodexTests
swift test --no-parallel
scripts/verify --headless
scripts/check-doc-links
git diff --check
```

Final implementation results:

```text
StornautLifecycle focused tests
30/30 passed
/tmp/stornaut-r3-lifecycle-focused-final.log
SHA-256 920f40aacd66e5b51169cbf81b3dcddcaa463313e44237b6c5fef262d32aee0d

closed R3 runtime focused tests
35/35 passed
/tmp/stornaut-r3-runtime-focused-final.log
SHA-256 ff20812eb019fd684d6483bc9c48306cc153a3a943d63fb52e0e5e4e54d3c94b

complete StornautCodexTests after review fixes, serial
130/130 passed; four opt-in diagnostics skipped
/tmp/stornaut-r3-codex-tests-serial-final.log
SHA-256 594eea4a9bf00d9f38fe67761d54586e99b2708ce251a63e3f1d9c5e738b3f25

complete SwiftPM suite after review fixes, serial
402/402 passed; opt-in diagnostics skipped
/tmp/stornaut-r3-full-swift-final.log
SHA-256 c1a87357f17ab342d1b6d8255625f174f79a2fa830a84173355e0bfa25b1ccf2

anonymous containment diagnostic
passed; probe.verdict=behaviorReadyCandidate
/tmp/stornaut-r3-containment-post-review.log
SHA-256 d5c46588a1d1737eac232b3c44f1a6ed533aba6c003631b7498fff11c5de06a2

privileged combined lifecycle diagnostic
passed; live/combined/recovery drained; residue zero
/tmp/stornaut-r3-audit-session-combined-final.log
SHA-256 509140cdfc431474e776c3b87a3fd1fc303cc34e420850f4f3dc800282dddb29

real external-auth App Server diagnostic
1/1 passed; gpt-5.6-luna; runtime auth file absent
/tmp/stornaut-r3-real-app-server-final-review.log
SHA-256 43462c194f1ff1dfde36a8387362f54dd010cbb4abea4ce29a9155771264a642

scripts/verify --headless
399 non-benchmark Swift tests plus App/source/signing/bundle/release/docs gates passed
/tmp/stornaut-r3-verify-headless-commit.log
SHA-256 646af705f022d0b84eb2a1a64e09a52dc243432fec47afc20066733c7ff46215

Automation Mode readiness
passed; no user authentication required at final check
/tmp/stornaut-r3-automation-mode-final.log
SHA-256 f91d306267165b2e1f27729288675e2a5a31d3e0f6750f64ce775ea4f320abb5

post-rebase lean headless verifier
passed on origin/main 33568d3 plus the R3 commit
/tmp/stornaut-r3-post-rebase-verify.log
SHA-256 d7df9d7362f626efb7a4ed66b8a71ffcefc6905f484c353b3bdece8d0675b0d8

XcodeBuildMCP macOS tests
123/123 passed
xcresult: ~/Library/Developer/XcodeBuildMCP/workspaces/stornaut-26b7f3f69f83/
  result-bundles/test_macos_2026-08-12T05-58-25-946Z_pid51792_ec53dfe8.xcresult

post-review non-UI Xcode tests
114/114 passed
xcresult: ~/Library/Developer/XcodeBuildMCP/workspaces/stornaut-26b7f3f69f83/
  result-bundles/test_macos_2026-08-12T07-03-03-012Z_pid51792_80f985bb.xcresult

post-review focused UI retries
Quick Scan inspector: 1/1 passed
Settings six sections: 1/1 passed
```

The first real-model retry failed before Codex launch because the interactive
shell PATH contained a stale missing Trae arg0 directory. The closed
environment correctly returned `invalidPATH`. A retry with an explicit
existing canonical PATH passed; no policy was loosened.

Independent working-tree review used the `bits-code-guard` serial fallback
because subagent delegation was unavailable. It reviewed 31 executable/Swift
files from a 44-file, 11,151-line diff across logic, security, concurrency,
robustness, performance and business-semantics dimensions. Repository custom
workflows were absent.

The review found and fixed two P1 defects:

1. `FileHandle.write` could block forever when a live App Server stopped
   reading a large turn request, bypassing the session timeout and caller
   cancellation. The runner now uses a nonblocking writer that polls the same
   deadline/cancellation token and zeroizes each outbound buffer. A fake server
   that stops reading after `thread/start` proves timeout and descendant
   cleanup in 1.04 seconds.
2. accepted `SSL_CERT_FILE`/`SSL_CERT_DIR` endpoints were root-owned and
   non-writable, but their parent chain was not checked. A root-owned
   certificate beneath a user-writable directory could therefore be replaced
   after validation. The environment policy now validates both the lexical
   root-owned chain, including root-owned system symlinks, and the resolved
   root-owned non-writable directory chain.

Focused review-fix evidence:

```text
blocked-input writer regression
timeout and caller cancellation: 2/2 passed
/tmp/stornaut-r3-blocked-input-final.log
SHA-256 6b1fdf4d77c647be53a996773198da5dcf6200e26bddf4941b3f665b1f0ca86f

complete App Server runner suite
10/10 passed
/tmp/stornaut-r3-runner-final.log
SHA-256 36c3ee5974def401c85532345087a2bc5079446c9d8417aa9425b4e8f290f2a5

runtime environment suite
5/5 passed
/tmp/stornaut-r3-environment-review-fix-retry.log
SHA-256 be298b08682775c090202d900ab74c8f4f6e697c0718c65e055a5881d108a6ae
```

One parallel Codex suite run observed the pre-existing
`diagnosticProcessTimeoutKillsDescendantsAndReturnsBoundedly` fixture before
its child PID file appeared. The same test passed in the serial Codex/full
suites and five consecutive focused reruns in 1.27–1.28 seconds. No production
or test timeout was changed:

```text
/tmp/stornaut-r3-diagnostic-timeout-repeat.log
SHA-256 1538890a8ebd94c54e2f9e0ca652a95b35e22d375c1ac0361b11c37257af22a4
```

Two post-review full Xcode runs each passed 122/123 UI-inclusive tests but
failed at different focus-sensitive assertions while the user was operating
the desktop: Quick Scan inspector static-text visibility in one run and
Settings `isHittable` in the next. Peekaboo observed a different frontmost App,
and both exact UI tests then passed focused reruns. No App/UI source changed in
R3. The already-completed 123/123 full run, post-review 114/114 non-UI run and
both focused UI passes are the admitting evidence; the two focus-interfered
runs remain recorded rather than hidden.

After fixes, independent review has zero unresolved P0–P2:

```text
final_comments.json = []
/tmp/stornaut_r3_review_1786508539/report.html
SHA-256 3a31afb2ede437bc99f33bec2a23417e957df1955be3e952f910a7c488a53bb5
/tmp/stornaut_r3_review_1786508539/report.md
SHA-256 47aa7c3fbbab40adc378cecdea3790eac75bcc9a9ce4a12cbc6fc31a1c743124
```

Final local Markdown links and `git diff --check` passed after report updates.
