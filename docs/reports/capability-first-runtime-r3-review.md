# Capability-First Runtime R3 Review

> Status: Failed — behaviorBlocked/no-go; R4–R6 not started
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
- owner-only Runtime Home and external App Server auth prototypes;
- direct and nested process lifecycle adversarial probes.

The final checked-in changes intentionally contain no R3 production runtime.
The evaluated App Server, Runtime Home, environment/auth projection and
containment implementations were removed after the hard gate failed.

Final review scope:

```text
Sources/StornautCodex/Runtime/CodexRuntimeProfile.swift
Tests/StornautCodexTests/CodexRuntimeProfileTests.swift
scripts/probe-codex-sandbox-containment
scripts/probe-codex-r3-lifecycle-escape
docs/plans/active/task-r3-implementation-brief.md
docs/plans/active/capability-first-codex-runtime-gate.md
docs/adr/0013-capability-first-runtime-containment.md
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

This correction narrows authority. It does not convert R2
`configurationReady` into behavioral readiness.

## 3. Positive Candidate Evidence

Before the hard blocker was found, anonymous and external-auth prototypes
observed:

- selected and full-disk read-only access succeeded;
- Runtime Home writes succeeded;
- target create/overwrite/append/unlink/chmod/symlink attempts failed;
- the auth-source path was unreadable under an explicit deny;
- one managed HTTP proxy allowed public HTTPS;
- direct public, arbitrary loopback and Unix-socket attempts failed;
- external App Server authentication completed one synthetic
  `gpt-5.6-luna` turn;
- no Runtime Home `auth.json` or session directory was created;
- the source auth file identity, mode and modification time did not change.

Local exploratory logs:

```text
/tmp/stornaut-r3-containment-loop-d.log
SHA-256 ae1fd3712a9695a95c90e4c1c007a179da506ecd14ea00745433230974f4efdb

/tmp/stornaut-r3-external-auth-loop-d.log
SHA-256 9b5eccd610a96691e46719aa2125ecb0022c49f5c91061e36972e04554ea7a47
```

These are positive observations only. The implementation that generated
them was not admitted or retained, and they cannot override a process-tree
escape.

## 4. Blocking Finding

### R3-01 — New-session descendants escape lifecycle containment

**Severity:** P1 hard-gate containment defect
**Status:** Confirmed and unresolved
**Disposition:** behaviorBlocked/no-go

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
| Privileged/root daemon | Reject: major product/permission expansion not approved |
| Disable shell/subagents/process creation | Reject: violates ADR 0004 capability-first requirements |
| Accept orphan risk | Reject: violates mandatory cancellation/crash cleanup |

No alternative both preserved the approved capability surface and supplied a
supported, crash-safe per-investigation process container.

## 6. Gate Result

- P0 unresolved: 0;
- P1 unresolved: 1 (`R3-01`);
- P2 unresolved: 0;
- filesystem integrity observations: positive but non-admitting;
- managed-proxy observations: positive but non-admitting;
- auth projection observation: positive but non-admitting;
- process lifecycle: failed;
- R3 outcome: `behaviorBlocked`;
- overall runtime gate: no-go for the current candidate.

Per the approved stop rule:

- no R3 production runtime is retained;
- R4 protocol v2 is not started;
- R5 signed-App capability admission is not started;
- R6 final admission is not started;
- Task 29 and production Deep Dive remain paused.

Resuming capability-first runtime work requires a separately reviewed
architecture that provides supported, per-investigation whole-process-tree
containment without reducing required investigation capabilities or widening
filesystem/network authority.

## 7. Verification

Required no-go evidence:

```text
scripts/probe-codex-r3-lifecycle-escape
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

The final command results and log hashes are recorded after the documentation
and review diff is complete. A passing baseline verifier demonstrates that
the no-go evidence and narrowed R2 correction do not regress the deterministic
product; it does not change `behaviorBlocked`.

Final results:

```text
CodexRuntimeProfileTests
6/6 passed
/tmp/stornaut-r3-profile-final.log
SHA-256 b28f136f9205054ee2e6542c991e88dce98aee24867845af5a00cc720705ab93

complete StornautCodexTests, serial
91/91 passed; three opt-in diagnostics skipped
/tmp/stornaut-r3-codex-tests-serial-final.log
SHA-256 03ad31041fdc6273e92ca22921160e9fe8089095cb75056170b4d809c5d51a12

complete SwiftPM suite, serial
333/333 passed; opt-in diagnostics skipped
/tmp/stornaut-r3-full-swift-serial-final.log
SHA-256 d20e42b72e2370427e6de5ddd97e21a77faf784d6bdc24c66f2ac3e7e128a100

corrected R1 containment probe
passed; managed public egress retained with direct/local/private/Unix blocked
/tmp/stornaut-r3-r1-containment-corrected-final.log
SHA-256 2c5625b6f94164cc4c238fcd24a3b53d9104b84a340a0e2a9c0a161fb1c3c857

installed no-model diagnostic
1/1 passed; corrected digest; configurationReady only; contained remains false
/tmp/stornaut-r3-installed-diagnostic-final.log
SHA-256 493445ac4f28075f308943115b2d58a4d7a0c634240e9117ee818ba6df43f26e

scripts/verify --headless
330 non-benchmark Swift tests plus App/source/signing/bundle/release/docs gates passed
/tmp/stornaut-r3-headless-commit-final.log
SHA-256 f511844b69915eea3bf709c25a0f8a0c005a2ae048fba63eb2bb1fa34af8d82c
```

The first parallel `StornautCodexTests` run had one load-sensitive timeout in
the existing `concurrentSpawnsDoNotInheritSiblingPipes` test. That test then
passed five consecutive focused runs in 1.31–1.95 seconds and passed in both
serial Codex/full suites. No production or test timeout was changed:

```text
/tmp/stornaut-r3-concurrent-focused-repeat.log
SHA-256 3932d0cf8d8fe9cebe9a6020ff55b4261c74689863594cbf76de8fc12b922098
```

Independent working-tree review used the `bits-code-guard` fallback workflow
because this run did not have user authorization to spawn review subagents.
It reviewed the complete executable/Swift diff, including the intent-to-add
probe, across logic, security, concurrency, robustness, performance and
business-semantics dimensions. Repository custom workflows were absent.

The three harness findings in §4 were fixed and re-reviewed. Final review
output contains no unresolved code defect:

```text
final_comments.json = []
/tmp/stornaut_r3_review_1786480864/report.html
/tmp/stornaut_r3_review_1786480864/report.md
```

The architectural `R3-01` P1 blocker remains intentionally unresolved and is
the reason for the no-go. It is not hidden by the zero-defect review of the
submitted no-go evidence diff.
