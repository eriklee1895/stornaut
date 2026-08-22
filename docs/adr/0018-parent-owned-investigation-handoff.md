# ADR 0018: Parent-Owned Investigation Handoff and Fixed App Launch

> **Status:** Proposed; external root-launch branch rejected; ii-b0a/ii-b0b/
> ii-b0c/ii-b1, the ii-b2 ASID prerequisite, ii-b2a, ii-b2b-i and ii-b2b-ii
> complete; ii-b2b-iii split into iii-a/iii-b and iii-b into iii-b-i/iii-b-ii;
> iii-a/iii-b-i/iii-b-ii complete/non-admitting; ii-b3 split into b3a/b3b/b3c;
> ii-b3a/ii-b3b/ii-b3c/ii-b4/ii-b5a0 complete/non-admitting; ii-b5 split;
> b5a and all b5b-i checkpoints through aggregate i-c2 complete/non-admitting;
> ii-b5b-ii-a/ii-b complete/non-admitting; ii-b5b-ii-c current
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
policy probe to return nonzero. The reviewed ii-c0 gate then maps only its held,
sealed cohort capsule to standard input and execs `/usr/bin/sudo` with this exact
inner argv:

```text
sudo
-kN
-p
"Stornaut Task 39 ii-c administrator authorization: "
--
/Library/Application Support/Stornaut/Stornaut-R5-Diagnostic.app/Contents/MacOS/StornautInvestigationMachineDriver
```

No shell redirection, `-S`, askpass, cache-creating `sudo -v`, environment
override, configurable executable/path, driver argument, UID, endpoint, signal,
action or cleanup input is allowed. ii-c0 freezes the outer gate executable,
source/binary identity, exact argv/env/FD set and controlling-TTY behavior before
this inner argv may be used.
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

After the child independently admits the inherited root peer and before the
first STNH frame, the driver writes one exact 32-byte `STNP` prelude containing
only magic/version/size plus the capsule-owned epoch UUID and absolute deadline.
The child strictly decodes it and must echo those exact values in
`PRE_DROP_READY`; the driver joins that frame to both the sent prelude and the
capsule row. The prelude is not an STNH frame and does not consume sequence zero.

The zero-argument driver receives its bounded cohort input only through the
ii-c0 gate's pre-opened standard-input descriptor. That descriptor must be an
owner-UID-501 regular file with mode `0600`, one link, bounded finite size, no ACL or
unexpected xattrs, initial offset zero and stable initial/final metadata. Root
DriverSupport sets close-on-exec, reads it to exact EOF, hashes it without
opening a path, and repeats descriptor offset/metadata closure. Root code treats
its strict configuration frames as opaque bytes and never uses their contents to select an
executable, path, UID, endpoint, signal, action or cleanup operation. Each App
may decode its frame only after irreversible credential drop is independently
admitted. The capsule never contains a retirement handle or token.

The authority-closed driver runtime accepts no executable, path, arguments,
environment, UID, endpoint, PID, signal or action from a caller. The
authority-free Machine domain receives only opaque non-Codable results.

### 3. Bind identity in two stages

Before credential drop, the child validates the root parent using the inherited
endpoint's kernel peer token and complete dynamic/static signing identity. It
reads the fixed STNP prelude and sends `PRE_DROP_READY` with the exact epoch
UUID/deadline; the root parent freezes the exact spawn PID, PID version,
ASID, path, SHA and signing identity while the child is still root, then sends
`DROP_RELEASE`.

Target UID `501` and primary GID `20` are compile-time constants. Root and App
independently resolve only the exact local `getpwuid_r(501)` account, require
GID 20, preserve the measured 17 unique `getgrouplist` return order and freeze
its first kernel `NGROUPS_MAX == 16` entries. Only that selected set is sorted
for comparison with sorted `getgroups(2)` output after `initgroups`. No identity
or group input comes from capsule, argv or environment; a set mismatch blocks
before `setgid`/`setuid` completion.

The child executes exactly `initgroups -> setgid -> setuid`, proves real,
effective and saved IDs, that exact kernel-bounded supplementary group set and
failed root regain, then sends typed `DROP_EVIDENCE`. The parent independently
verifies post-drop PID/PPID/PGID and IDs with libproc, ASID with BSM, live signing
with `kSecGuestAttributePid`, and fixed path/SHA/static signing. Reported audit
facts are admitted only when they match independently observed facts and the
pre-drop PID version/ASID.

All later boundaries repeat the post-drop independent verification; no
cross-UID task-port lookup is used.

### 4. Use one strict, one-shot binary protocol

`CONFIGURATION -> CONFIGURATION_ACK` is a pre-business exchange after the
irreversible drop. The product business epoch is App-to-driver `HELLO` and
`HANDLE`, driver-to-App `ACK` and `RELEASE`, then App-to-driver `ALIVE` and
strict write EOF. The historical B4 parent-to-child dummy `HANDLE` proved only
the duplex algorithm and does not define the product direction. Every frame has
an exact version, kind, sequence, random
nonce, one monotonic deadline, bounded length and complete identity claims.
Trailing bytes, duplicate frames, wrong versions, stale identity, timeout,
partial EOF or unexpected closure permanently consume the epoch.

After ALIVE/EOF, the driver presents the handle once to the fixed helper claim
service, requires the handle-free claim evidence, performs an
`installedL2ObservedAt` barrier and a repeated post-drop App identity join, then
sends a handle-free `CLAIM_RELEASE` on the same attested connection epoch. A
successful claim atomically cancels the original claim deadline and installs a
release deadline. Claim evidence binds the request digest, fresh connection-
epoch nonce, complete attested-helper identity digest and absolute monotonic
deadline. `CLAIM_RELEASE` adds a fresh nonzero challenge and echoes all those
facts; release atomically cancels that deadline. `CLAIM_RELEASED` echoes digest,
challenge, helper digest and connection epoch, carries typed `exitScheduled` and
the absolute post-reply exit deadline. The helper replies once, schedules exit
only after reply dispatch, exits within a fixed bound and
may be restarted by launchd for the next epoch. Timer races are terminal and no
untracked exit work item remains. Only then does the driver send `EXIT`. Early
claim-connection loss, release before installed-L2, foreign binding/challenge or
helper survival beyond the bound fails closed. The App therefore remains alive
through helper claim and installed-L2. No opaque handle
is written to a file, configuration or receipt. A claim request presents the
handle once to its original helper, but the helper response contains only a
canonical request-binding digest, challenge/identity evidence and retirement
facts; it never echoes the request, handle, token or a reversible token
projection.

The claim/release protocol uses system-wide `mach_continuous_time` converted to
nanoseconds. The release window and post-reply exit window are each at most
exactly five seconds and are capped by the epoch monotonic deadline plus the
independently checked wall-clock handle/config validity. Release transcripts use
separate domain separators, exact versioned tagged fields and contain no handle
or token; zero/stale challenge, wrong connection/helper identity, digest or
deadline drift and unknown fields fail closed.

After helper exit the installed-L2 observation is historical, not continuously
valid. The driver proves the exact claimed helper and all claim connection/
escrow/listener state are gone. The launchd service remains registered and
activatable but is not called process-loaded; the next epoch attests a different
fresh helper identity and repeats full installed-L2.

The App's no-model retirement path may use only one supervised lifecycle
`start -> retire` pair and no App Server business line. Source review proves it
does not call auth projection, initialize, login, thread, turn, write or read
APIs; ii-c must additionally prove on the signed App that auth content/metadata
remain unchanged and no admitted auth-read/model/network event occurred. Until
that machine evidence exists, source shape alone is not an auth-read claim.

### 5. Keep lifecycle authority with the root parent

Every process group is created atomically. The root parent uses bounded
exact-member inventory, `waitid(WNOWAIT)`, TERM/KILL and reap-last. A final exact
SIGKILL fallback runs before identity may be released. PID is cleared only after
successful reap; otherwise exact PID/PGID remains in typed residue evidence and
the result cannot be contained. No global same-UID discovery or coordination is
permitted.

Per-epoch completion proves exact channel, App, descendant and PGID retirement
with leader reap-last while installed artifacts and launchd registration remain
admitted; helper process identity is covered by the timestamp barrier and exact
post-release exit above. After reap, the driver repeats its installed-path/
static/live self-observation and requires exact equality with the initial typed observation.
Global post-teardown L2 means final bootout/uninstall and occurs once
after all epochs, not inside an epoch.

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
- Product work is split into ii-a authority-closed live driver runtime;
  ii-b0a/ii-b0b/ii-b0c/ii-b1–ii-b5 shared contract/bootstrap/App/helper/client/single-epoch
  implementation;
  ii-c0 TTY/capsule launcher evidence; and ii-c one outer no-model privileged
  driver invocation containing closed scenario epochs.
- No anonymous-XPC, filesystem mailbox, generic IPC, generic root launcher,
  helper launch operation or caller-configurable fallback remains.
- The driver runtime owns only fixed process creation and lifecycle cleanup; it
  has no Cleanup/Policy/Trash/Executor/Registered Action authority.
- Strict path/SHA plus live and static signing checks remain mandatory because
  running-vnode validity survives path replacement on the measured platform.
- ii-c0 proves only gate-side exec/FD hygiene with a non-privileged stub plus
  the local sudo manual. It does not prove real sudo preserves child stdin/TTY/
  FDs. A mismatch in the unique ii-c attempt consumes and fails that gate with
  no retry, readiness or ADR acceptance.
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
3. the two-stage identity transition and exact returned-order-first 17-to-16
   kernel group rule;
4. irreversible credential drop;
5. the strict happy/replay/deadline/cancellation/crash/hang matrix;
6. zero child, descendant, channel and exact-PGID residue;
7. exact installed current-source App/helper/driver/plist/service binding,
   installer ACL proof, runtime ACL self-observation, per-epoch timestamped
   installed L2, exact helper release/exit and fresh helper/full-L2 on the next
   epoch;
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
| ii-a installed-driver self-observation | complete; non-admitting |
| ii-b split preflight | parent split frozen; ii-b0 replaced by exact b0a/b0b wire checkpoints |
| ii-b0 wire preflight | b0a/b0b split frozen after iterative post-fix review |
| ii-b0a frame/capsule contract | complete; non-product and non-admitting |
| ii-b0b claim/release wire contract | complete; non-product and non-admitting |
| ii-b0c epoch bootstrap prelude | complete; closes first-frame origin contradiction |
| ii-b1 authority-free App leaf | complete; non-admitting |
| ii-b2 ASID cohort prerequisite | complete; App/helper independently bound, L1 residue bound to helper; non-admitting |
| ii-b2a typed escrow/deadline state | complete; non-connected/non-admitting |
| ii-b2b-i non-connected machine-claim server | complete; non-admitting |
| ii-b2b-ii legacy-client quarantine / Machine production block | complete; non-admitting |
| ii-b2b-iii-a handle-v3/single-quantized transfer | complete; non-admitting |
| ii-b2b-iii-b-i semantic/live integration closure | complete; non-admitting |
| ii-b2b-iii-b-ii executable physical-adapter closure | complete; non-admitting |
| ii-b3a fixed-channel/root-peer/drop adapter | complete; non-admitting |
| ii-b3b start-to-retire-only Lifecycle seam | complete; non-admitting |
| ii-b3c concrete leaf/native entry | complete; non-admitting |
| ii-b4 fixed helper-claim client | complete; non-admitting |
| ii-b5a0 same-client claim-abort terminal proof | complete; non-admitting |
| ii-b5a typed/injected single-epoch composer | complete; non-admitting |
| ii-b5b-i L2/projection extraction through aggregate i-c2 | complete; non-admitting |
| ii-b5b-ii-a fixed FD-0 capsule intake | complete; non-admitting |
| ii-b5b-ii-b independent Darwin App identity observation | complete; non-admitting |
| ii-b5b-ii-c fixed FD-7 bounded session | current |
| ii-b5b-ii-d exact owned-PGID retirement | pending |
| ii-b5b-iii production/artifact composition | pending |
| ii-c no-model privileged machine gate | not executed |
| ADR status | **Proposed** |
