# ADR 0018: Parent-Owned Investigation Handoff and Fixed App Launch

> **Status:** Proposed; external root-launch branch rejected, installed-driver
> implementation and machine gate pending
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

The root Machine driver must obtain one retirement handle from the exact
non-root diagnostic App while that App remains alive for the helper claim and
installed-L2 observation. The App may exit only after the driver-owned
transition. JSON, files, helper replies and caller-selected endpoints cannot
carry the parent handoff.

External spikes rejected anonymous-XPC endpoint archival and symmetric
inherited-socket peer authentication. An asymmetrically bound inherited
socketpair passed the complete unprivileged transport/lifecycle matrix. The B4
candidate also closed the root-to-UID algorithm statically, but no B4 artifact
ever executed as root.

The subsequent root-launch audit found a more fundamental bootstrap problem. A
UID-controlled sequence of stock `sudo`, hash, copy, chmod and execute commands
cannot make root verification an unskippable prerequisite to root execution. The
old `sudo -v` variant additionally created ambient cached authority. Two
independent reviews rejected the no-cache external WIP. The external staging and
execution checkpoints were superseded before execution; B4 root execution count
remains zero and no root artifact or receipt exists.

The remaining candidate uses the current-source diagnostic Machine driver only
after the accepted installer has moved it into the fixed root-owned App and L2
has independently re-admitted its complete static identity. The driver is not
currently installed. This ADR records a proposed implementation contract, not an
accepted production decision.

## Evidence

The related study records the platform facts, rejected candidates, B3-v8
two-run matrix, forced-cleanup negative, Security API behavior and historical B4
source/binary hashes. The
[i-b2a review](../reports/phase-d-task-39b2c-l3c3c-i-b2a-reproducibility-contract-review.md)
freezes B4's non-admitting reproducibility evidence. The
[root-launch trust-anchor audit](../reports/phase-d-task-39b2c-l3c3c-i-b2b-0a-root-provenance-review.md)
records why the external branch is NO-GO and conditionally selects the installed
driver path. The
[installed-driver preflight](../reports/phase-d-task-39b2c-l3c3c-ii-installed-driver-path-cost-preflight.md)
freezes the implementation split and validation funnel. Important measured
conclusions are:

- an inherited socket's peer token does not rebind to the child;
- an anonymous XPC endpoint cannot be converted to an ordinary byte archive;
- PID-owned asymmetric binding can close the unprivileged transport matrix;
- live code remains valid after path replacement on this macOS, so live
  validity cannot replace fixed-path SHA and static-signing verification;
- WNOWAIT, exact PGID membership, bounded final SIGKILL, reap-last and retained
  identity are required to avoid PGID reuse, hangs and silent residue;
- `sudo -v` is broader than one diagnostic action, while separate no-cache stock
  root commands still lack an atomic verify-and-act relation;
- no public stock macOS `fexecve`/`execveat` path closes that relation; and
- the root-owned installed diagnostic driver already has installer/L2 identity
  contracts, but its current zero-dependency runtime still returns unavailable
  and has not implemented the live handoff.

## Proposed Decision

### 1. Use only the fixed root-owned installed driver as root parent

The only eligible root parent is the diagnostic Machine driver at:

```text
/Library/Application Support/Stornaut/Stornaut-R5-Diagnostic.app/Contents/MacOS/StornautInvestigationMachineDriver
```

Before any App launch, its own runtime must observe real/effective root identity,
the exact fixed path, root-owned node metadata, actual held-descriptor SHA-256,
static and live signing identifier, designated requirement, CodeDirectory hash
and the fixed Machine-claim service binding. A zero-argument executable cannot
embed its expected whole-file SHA without a circular build, so ii-c independently
compares the pre/post observation with the installer/L2 frozen binding. Any
mismatch fails admission. An external staged executable, fallback
path or caller-provided identity is forbidden.

This Proposed ADR is limited to the trusted local-operator/current-checkout
development topology recorded by the installed-driver preflight. It does not
claim provenance against a malicious administrator, malicious pre-install
Coding Agent or arbitrary concurrent same-UID actor.

The future machine-only ceremony first requires the non-executing `sudo -kNnv`
policy probe to return nonzero, then uses the zero-driver-argument command:

```text
/usr/bin/sudo -kN -p 'Stornaut Task 39 ii-c administrator authorization: ' -- /Library/Application\ Support/Stornaut/Stornaut-R5-Diagnostic.app/Contents/MacOS/StornautInvestigationMachineDriver
```

No cache-creating `sudo -v`, environment override, configurable executable/path,
driver argument, UID, endpoint, signal, action or cleanup input is allowed.
Machine evidence cannot prove a prompt occurred: the trusted operator must
observe the exact fixed prompt and record that manual fact; absence of that
prompt is non-admitting.
The long-lived lifecycle helper does not gain driver-launch authority.

### 2. Use one prelaunch unnamed duplex socketpair

The root driver creates one `AF_UNIX/SOCK_STREAM` socketpair before launching
the fixed installed App. It retains one endpoint and maps the other to one
compile-time fixed App descriptor using `POSIX_SPAWN_CLOEXEC_DEFAULT`. Any
collision with the fixed descriptor is relocated before file actions are
constructed. No filesystem socket, Mach registration or persistent endpoint is
created.

The authority-closed driver runtime accepts no executable, path, arguments,
environment, UID, endpoint, PID, signal or action from a caller. The
authority-free Machine domain receives only opaque non-Codable results.

### 3. Bind identity in two stages

Before credential drop, the child validates the root parent using the inherited
endpoint's kernel peer token and complete dynamic/static signing identity. It
sends `PRE_DROP_READY`; the root parent freezes the exact spawn PID, PID version,
ASID, path, SHA and signing identity while the child is still root, then sends
`DROP_RELEASE`.

The child executes exactly `initgroups -> setgid -> setuid`, proves real,
effective and saved IDs, the exact kernel-bounded supplementary groups and
failed root regain, then sends typed `DROP_EVIDENCE`. The parent independently
verifies post-drop PID/PPID/PGID and IDs with libproc, ASID with BSM, live signing
with `kSecGuestAttributePid`, and fixed path/SHA/static signing. Reported audit
facts are admitted only when they match independently observed facts and the
pre-drop PID version/ASID.

All later boundaries repeat the post-drop independent verification; no
cross-UID task-port lookup is used.

### 4. Use one strict, one-shot binary protocol

The business epoch is `HELLO -> HANDLE -> ACK -> RELEASE -> ALIVE -> strict
write EOF -> EXIT`. Every frame has an exact version, kind, sequence, random
nonce, one monotonic deadline, bounded length and complete identity claims.
Trailing bytes, duplicate frames, wrong versions, stale identity, timeout,
partial EOF or unexpected closure permanently consume the epoch.

The App remains alive after `ALIVE`; the root driver performs installed-L2
observation and the final identity check before sending `EXIT`. No opaque handle
is written to a file, configuration, receipt or helper claim response.

### 5. Keep lifecycle authority with the root parent

Every process group is created atomically. The root parent uses bounded
exact-member inventory, `waitid(WNOWAIT)`, TERM/KILL and reap-last. A final exact
SIGKILL fallback runs before identity may be released. PID is cleared only after
successful reap; otherwise exact PID/PGID remains in typed residue evidence and
the result cannot be contained. No global same-UID discovery or coordination is
permitted.

The one outer installed-driver supervisor stays alive across closed, sequential,
fresh scenario epochs. Each epoch has a disposable inner root scenario-parent
that owns the App/child channel and session. The `parent_crash` case crashes only
that inner parent; the child detects endpoint EOF, drains and reaps its own
same-PGID descendant and exits, while the outer fixed supervisor verifies exact
child, descendant and PGID absence and seals the result. The outer supervisor is
not a fault target and may not signal unrelated processes.

## Consequences

- The external B4/stager/evidence-driver branch remains historical,
  non-admitting evidence and must never be root-executed.
- L3c3c-i is complete as a research/root-launch audit with an external NO-GO; it
  does not accept this ADR or prove machine behavior.
- Product work is split into ii-a authority-closed live driver runtime, ii-b
  fixed handoff composition and ii-c one outer no-model privileged driver
  invocation containing closed scenario epochs.
- No anonymous-XPC, filesystem mailbox, generic IPC, generic root launcher,
  helper launch operation or caller-configurable fallback remains.
- The driver runtime owns only fixed process creation and lifecycle cleanup; it
  has no Cleanup/Policy/Trash/Executor/Registered Action authority.
- Strict path/SHA plus live and static signing checks remain mandatory because
  running-vnode validity survives path replacement on the measured platform.
- L3c3d may run one real authenticated model attempt only after ii-c is green.
- L3c4 alone owns Task 39 readiness and the remaining full verifier.

## Residual Risks and Acceptance Gate

Within the explicit trusted-local-operator threat model, this ADR cannot become
Accepted from static, same-UID, reproducibility,
installer-only or synthetic evidence. ii-a and ii-b must first pass their
focused, final-Mach-O, staged-serial and independent-review gates. Then ii-c
must perform exactly one current-source, no-model outer driver invocation with
the closed scenario epochs and prove:

1. exact root-owned installed driver self-observation before App launch and
   independent equality with the installer/L2 frozen binding;
2. root parent and exact fixed UID 501 child;
3. the two-stage identity transition and exact 17-to-16 kernel group rule;
4. irreversible credential drop;
5. the strict happy/replay/deadline/cancellation/crash/hang matrix;
6. zero child, descendant, channel and exact-PGID residue;
7. exact installed current-source App/helper/driver/plist/service binding,
   installer ACL proof, runtime ACL self-observation and full installed L2 after
   App launch;
8. post-run uninstall and zero App/plist/service/runtime/lease/process residue;
   and
9. independent validation of the raw evidence without retrying a started failed
   attempt.

The external staging paths remain absent and B4 root execution count remains
zero. The fixed installed App is also absent at this documentation checkpoint.
Until ii-c is green, ADR 0018 remains Proposed, production Deep Dive remains
unavailable, no readiness claim is allowed and the remaining full verifier is
unconsumed.

## Validation Status

| Evidence | Status |
| --- | --- |
| Anonymous-XPC candidate | rejected by measured Foundation encoding contract |
| Symmetric inherited peer-token candidate | rejected by measured kernel identity |
| B3-v8 unprivileged transport/lifecycle matrix | two 19/19 runs passed |
| B3 forced first-drain failure | final fallback passed, zero retained residue |
| Public Security API negative | passed; running-vnode preservation documented |
| Historical B4 compile/non-root/forced cleanup | passed; non-admitting |
| i-b2a B4 reproducibility projections | complete; historical/non-admitting |
| i-b2b-0a root-launch trust-anchor audit | complete; external staging NO-GO |
| i-b2b-0b external staging | superseded before execution |
| i-b2b-1 external privileged run | superseded before execution; root count 0 |
| installed diagnostic driver | conditionally selected; currently absent |
| ii-a live DriverSupport | not implemented |
| ii-b fixed handoff composition | not implemented |
| ii-c no-model privileged machine gate | not executed |
| ADR status | **Proposed** |
