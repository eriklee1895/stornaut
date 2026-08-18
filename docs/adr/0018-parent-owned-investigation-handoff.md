# ADR 0018: Parent-Owned Investigation Handoff and Fixed App Launch

> **Status:** Proposed; i-b2a complete, blocked on one authorized i-b2b B4 run
>
> **Date:** 2026-08-19
>
> **Decision owners:** Stornaut maintainers
>
> **Related study:**
> [L3c3c Parent-Owned Handoff Study](../upstream-studies/phase-d-task-39b2c-l3c3c-parent-owned-handoff.md)
>
> **Governing boundaries:** ADR 0004, ADR 0013, ADR 0016 and the Task 39
> signed-runtime/Machine contracts.

## Context

The installed root Machine driver must obtain one retirement handle from the
exact non-root diagnostic App while that App remains alive for the helper claim
and installed-L2 observation. The App may exit only after the driver-owned
transition. JSON, files, helper replies and caller-selected endpoints cannot
carry the parent handoff.

Two plausible bootstrap designs were unproven. External spikes rejected both
ordinary anonymous-XPC endpoint archival and symmetric inherited-socket peer
authentication. An asymmetrically bound inherited socketpair passed the full
unprivileged transport/lifecycle matrix. Its root-to-UID implementation and
static review are complete, but the administrator-authorized machine run has
not executed. This ADR therefore records a proposed implementation contract,
not an accepted production decision.

## Evidence

The related study records the exact environment, rejected-candidate errors,
B3-v8 two-run matrix, forced-cleanup negative, live Security API behavior and
B4 source/binary hashes. The
[i-b2a review](../reports/phase-d-task-39b2c-l3c3c-i-b2a-reproducibility-contract-review.md)
freezes the three-layer reproducibility contract. Important measured
conclusions are:

- an inherited socket's peer token does not rebind to the child;
- an anonymous XPC endpoint cannot be converted to an ordinary byte archive;
- PID-owned asymmetric binding can close the same-UID transport matrix;
- live code remains valid after path replacement on this macOS, so live
  validity cannot replace fixed-path SHA/static-signing verification;
- WNOWAIT, exact PGID membership, bounded final SIGKILL, reap-last and retained
  identity are required to avoid PGID reuse, hangs and silent residue; and
- B4's static/non-root/forced-cleanup evidence is green, while its privileged
  root-to-UID evidence is absent; and
- a fresh signed build reproduces the normalized unsigned and signed semantic
  projections, while literal whole-file equality is prevented only by 193 bytes
  of non-semantic post-SuperBlob padding.

## Proposed Decision

### 1. Use one prelaunch unnamed duplex socketpair

The root driver creates one `AF_UNIX/SOCK_STREAM` socketpair before launching
the App. It retains one endpoint and maps the other to one compile-time fixed App
descriptor using `POSIX_SPAWN_CLOEXEC_DEFAULT`. Any collision with the fixed
descriptor is relocated before file actions are constructed. No filesystem
socket, Mach registration or persistent endpoint is created.

The launcher is a dedicated narrow authority target. It accepts no executable,
path, arguments, environment, UID, endpoint, PID, signal or action from a
caller. It derives the fixed installed App path, fixed UID and exact launch shape
internally. The authority-free Machine domain receives only opaque non-Codable
results.

### 2. Bind identity in two stages

Before credential drop, the child validates the root parent using the inherited
endpoint's kernel peer token and complete dynamic/static signing identity. It
sends `PRE_DROP_READY`; the root parent freezes the exact spawn PID, PID version,
ASID, path, SHA and signing identity while the child is still root, then sends
`DROP_RELEASE`.

The child executes exactly `initgroups -> setgid -> setuid`, proves real/
effective/saved IDs, exact kernel-bounded supplementary groups and failed root
regain, then sends typed `DROP_EVIDENCE`. The parent independently verifies the
post-drop PID/PPID/PGID and IDs with libproc, ASID with BSM, live signing with
`kSecGuestAttributePid`, and fixed path/SHA/static signing. The reported audit
token is accepted only when all fields match those independent facts and the
pre-drop PID version/ASID.

All later boundaries repeat the post-drop independent verification; no cross-UID
task-port lookup is used.

### 3. Use one strict, one-shot binary protocol

The business epoch is `HELLO -> HANDLE -> ACK -> RELEASE -> ALIVE -> strict
write EOF -> EXIT`. Every frame has an exact version/kind/sequence, random nonce,
one monotonic deadline, bounded length and complete identity claims. Trailing
bytes, duplicate frames, wrong versions, stale identity, timeout, partial EOF or
unexpected closure permanently consume the epoch.

The App remains alive after `ALIVE`; the root driver performs the installed-L2
observation and final identity check before sending `EXIT`. No opaque handle is
written to a file, config, receipt or helper claim response.

### 4. Keep lifecycle authority with the root parent

Every process group is created atomically. The root parent uses bounded exact-
member inventory, `waitid(WNOWAIT)`, TERM/KILL and reap-last. A final exact
SIGKILL fallback runs before identity may be released. PID is cleared only after
successful reap; otherwise the exact PID/PGID remains in typed residue evidence
and the result cannot be contained. No global same-UID process discovery or
coordination is permitted.

Parent crash relies on the child detecting endpoint EOF, draining/reaping its
own same-PGID descendant and exiting. An external observer may verify exact
child/descendant/PGID absence but may not signal unrelated processes.

## Consequences

- L3c3c-ii, if this ADR becomes Accepted, must implement only this topology.
- No anonymous-XPC, filesystem mailbox, generic IPC, generic root launcher or
  caller-configurable fallback remains.
- The App needs a fixed inherited-channel leaf and an exit barrier; existing
  helper escrow and Machine-claim XPC remain unchanged.
- The launcher target owns process creation and lifecycle cleanup but no
  Cleanup/Policy/Trash/Executor/Registered Action authority.
- Strict path/SHA plus live and static signing checks remain mandatory because
  running-vnode validity survives path replacement on the measured platform.

## Residual Risks and Acceptance Gate

This ADR cannot become Accepted from same-UID, static or reproducibility
evidence. Its residual gate has two distinct parts: i-b2a is complete; one
explicitly authorized disposable i-b2b B4 run must still prove:

1. root parent and exact fixed UID 501 child;
2. the two-stage identity transition and exact 17-to-16 kernel group rule;
3. irreversible credential drop;
4. the strict happy/replay/deadline/cancellation/crash/hang matrix;
5. zero child, descendant, channel and exact-PGID residue; and
6. exact execution artifact full SHA-256
   `d157241035e9bdda8bd5ed139509fcb23ae45528ae79b89e3d22b98d614e760d`
   before and after execution, with output bound to that same value; and
7. the already-complete i-b2a normalized unsigned and signed semantic
   projections remain independently reproducible without copying reviewed
   signature padding.

The two attempted standard administrator prompts did not start the binary and
were cancelled. They are not evidence. Until the gate above is green,
L3c3c-ii is blocked, production Deep Dive remains unavailable, no readiness
claim is allowed and the remaining full verifier is not consumed.

## Validation Status

| Evidence | Status |
| --- | --- |
| Anonymous-XPC candidate | rejected by measured Foundation encoding contract |
| Symmetric inherited peer-token candidate | rejected by measured kernel identity |
| B3-v8 unprivileged transport/lifecycle matrix | two 19/19 runs passed |
| B3 forced first-drain failure | final fallback passed, zero retained residue |
| Public Security API negative | passed; running-vnode preservation documented |
| B4 strict compile/non-root gate | passed |
| B4 compile-time forced-cleanup negative | passed |
| B4 independent static review | no unresolved P0-P2 |
| i-b2a exact execution-artifact contract | full SHA `d157241035e9bdda8bd5ed139509fcb23ae45528ae79b89e3d22b98d614e760d` frozen |
| i-b2a normalized unsigned projections | complete; both reviewed/rebuilt comparisons matched |
| i-b2a signed semantic projection | complete; fixed identifier/CodeDirectory/prefix matched; only bounded post-SuperBlob padding differed |
| i-b2b privileged root-to-UID machine run | **not executed** |
| ADR status | **Proposed** |
