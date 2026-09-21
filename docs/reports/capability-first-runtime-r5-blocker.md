# Capability-First Runtime R5 External-State Blocker

> Status: Resolved by local-only scope decision; historical evidence retained
>
> Date: 2026-08-12
>
> Gate: packaged LaunchDaemon registration and signed-App topology

## 1. Stop Reason

R5 reached an external-state prerequisite that the approved scope does not
authorize the Coding Agent to change:

```text
SMAppService packaged LaunchDaemon
→ containing App must be notarized
→ notarization requires a valid signing identity and release credentials
```

The current Apple SDK contract in
`ServiceManagement.framework/Headers/SMAppService.h` states:

> Apps that contain LaunchDaemons must be notarized.

The local machine currently has:

```text
macOS 26.5.1 arm64
codex-cli 0.147.0
valid code-signing identities: 0
Developer ID Application identities: 0
sudo -n: unavailable
```

The built Debug App has a valid local ad-hoc signature and exact helper/plist
bundle layout, but:

```text
Signature=adhoc
TeamIdentifier=not set
SMAppService status before registration=notFound
registration attempt=externalFailure
```

R5 therefore cannot prove the actual registered App/helper topology without
expanding into Developer ID/notarization or choosing a different lifecycle
architecture. Both require a new explicit user decision.

## 2. Work Completed Before the Blocker

Tests-first work created red then green pure contracts for:

- configured/invoked/observed/contained evidence separation;
- privacy-safe signed-runtime reports;
- exact `SMAppService.Status` projection;
- external-state versus integrity-failure semantics;
- exact App signing identifier/designated-requirement/CDHash policy;
- system peer code-signing requirement construction;
- `AU_ASSIGN_ASID` operation ordering and fail-closed privilege drop;
- privacy-safe App Server observation of command source, web search, image and
  subagent events.

The in-progress packaging candidate builds:

```text
Stornaut.app/Contents/MacOS/Stornaut
Stornaut.app/Contents/MacOS/StornautLifecycleHelper
Stornaut.app/Contents/Library/LaunchDaemons/
  com.eriklee.stornaut.lifecycle.plist
```

The App and nested helper pass local `codesign --verify --deep --strict`.
The plist contains the exact label/Mach service, `BundleProgram`,
`SessionCreate=true`, on-demand flags and no generic executable/argv input.

These are implementation candidates only. They are not admitted R5 evidence
because the service did not register and run from the supported packaged
topology.

## 3. Safety and Residue

After the failed registration attempt:

- no `system/com.eriklee.stornaut.lifecycle` launchd service exists;
- no exact `StornautLifecycleHelper` or Stornaut App process remains;
- no R5 lease or temporary diagnostic root remains;
- Background Task Management records the App as disabled/allowed and the
  embedded daemon as enabled/disallowed;
- no real model call was made after R4;
- no TCC, FDA, Accessibility or Event Synthesizing state was changed;
- no password or authorization UI was clicked or automated.

The initial `pgrep -f` residue counter matched its own probe command. An exact
`ps` executable-name check found no helper process; that exact check is the
authoritative residue result.

Primary blocker evidence:

```text
/tmp/stornaut-r5-external-blocker-final.log
SHA-256 cbc63a2d1003b5fe576e528ec71ce48fc604a17b71bedbaacab9242abfefb755
```

The log's self-matching `helper.process.count` field is superseded by the exact
follow-up process check described above.

## 4. Gate Consequence

R5 is not complete:

- required signed-App capabilities are unverified;
- signed helper caller authentication is unobserved;
- packaged crash recovery is unobserved;
- FDA/TCC inheritance is unverified;
- no R5 independent review/report/commit/push is allowed;
- R6 must not start.

The worktree intentionally remains dirty with the R5 tests-first and packaging
candidate. `HEAD == origin/main` remains the accepted R4 commit:

```text
89f3a8532b5594632edb66c8e9ad06a313ad9a5c
```

## 5. Required Decision

At the time of the stop, one of the following decisions was required:

1. provide/authorize a valid Developer ID signing and notarization path for
   the R5 diagnostic App/helper; or
2. approve a different supported lifecycle architecture and its revised hard
   gate.

Legacy direct installation into `/Library/LaunchDaemons`, manual `launchctl`
bootstrap, private APIs, PID-only authentication or bypassing ServiceManagement
would not satisfy the current R5 gate and were not attempted.

## 5.1 Resolution

The owner subsequently clarified that the current product needs to run only
for personal use on this Mac and does not need distribution. The owner does
not want to purchase Apple Developer Program membership solely for the R5
diagnostic.

R5 therefore adopted a revised, explicit local-only hard gate:

```text
ad-hoc signed Debug Stornaut.app
→ one administrator-authenticated installation
→ fixed root-owned /Library/Application Support/Stornaut/
  Stornaut-R5-Diagnostic.app
→ fixed root-owned /Library/LaunchDaemons plist
→ exact system launchd label
```

This does not reinterpret the failed packaged registration as success. It is a
different supported local lifecycle topology with its own tests, install/
uninstall evidence, caller authentication, containment and zero-residue gate.
The installer accepts no destination, executable, label, Mach service or argv
override and never replaces a mismatched existing object.

The initially proposed `/Applications` destination was later rejected during
R5 code review because this machine exposes `/Applications` as
`root:admin 0775`, writable by the current administrator without a fresh
authorization prompt. A fixed privileged Program under that parent could be
renamed/replaced. The accepted local-only destination is instead under a
new `root:wheel 0755` `/Library/Application Support/Stornaut` directory whose
ancestor is not user-writable.

Developer ID/notarization remains required before Stornaut can use the modern
packaged LaunchDaemon topology for distribution. Local-only R5 success cannot
be used as release or distribution evidence.

## 6. LaunchAgent Alternative Rejected

After the initial stop, the Coding Agent evaluated the only apparent
unprivileged supported alternative: a per-user `SMAppService` LaunchAgent with
`SessionCreate=true`. This did not require Developer ID/notarization merely to
test its lifecycle behavior, but it also did not preserve the R3 recovery
guarantee.

Three anonymous, synthetic `gui/$UID` launchd Spikes were run under random
labels and random `/private/tmp` roots. The final Spike:

- created a distinct audit session for the first LaunchAgent invocation;
- launched `setsid()` and double-fork descendants in that audit session;
- killed the LaunchAgent to force launchd recovery;
- observed a different audit session for the relaunched agent;
- filtered process-table candidates to the same UID with public
  `proc_pidinfo`;
- attempted to read the old descendants' audit-session identity with public
  `audit_get_pinfo_addr`;
- kept an unrelated same-user canary alive.

The recovery invocation repeatedly observed:

```text
first_asid=124126 first_uid=501
restart_asid=124127 stale_asid=124126
members=0 signals=0 same_uid_errors=1 result=1
unrelated_canary=alive
```

`result=1` is `EPERM`: the recovered same-user LaunchAgent could not inspect
the old audit session's same-user descendants. Earlier variants that queried
all system processes before UID filtering also hit expected `EPERM` results
and were discarded as probe-design errors; filtering by UID removed that
confounder but did not remove the target-session denial.

Ignoring this denial would turn an unknown member set into a false empty set
and leave detached descendants alive. Falling back to PID, PPID, process
group, name or environment matching would reintroduce the races rejected by
ADR 0016. Therefore a LaunchAgent cannot provide the required
identity-checked, crash-safe fixed-point drain and is not an equivalent R5
architecture.

All three random jobs, synthetic descendants, canaries and temporary roots
were removed after the Spikes. Final checks found zero matching launchd jobs,
zero temporary roots and zero exact synthetic probe binaries. No model, TCC,
FDA, Accessibility, Event Synthesizing or system-domain operation was used.
