# Phase D Task 39B2c L3c3c-ii-c0b Non-Root Capsule and Launcher Preflight

> Status: four-checkpoint order frozen; c0b-i implementation complete/non-
> admitting with no unresolved P0-P2; c0b-ii fresh preflight current; c0b-iii/
> c0b-iv still require their own fresh preflights
>
> Date: 2026-08-26
>
> Frozen baseline: `e0ca61b81afc384f0b8ca10b5e671bdb752b34c3`
>
> Scope: current-source documentation, package graph, configuration, capsule,
> file-authority and launcher inspection only. No sudo/root, App/helper/driver
> launch, install, XPC, model/auth/network use, serialized regression or full
> verifier was run for this preflight.

## 1. Decision

The previously named `ii-c0b` checkpoint is not one reviewable implementation
surface. It combines three distinct trust domains—product-semantic decoding,
filesystem write authority and process/TTY/descriptor authority—plus the final
production composition that must join them without collapsing those boundaries.
Current-source
inventory estimates the unsplit work at 11–12 non-document paths and roughly
3,400–5,000 changed lines. The path count may remain below fourteen, but the
line count can exceed the repository's approximately 4,000-line mandatory split
threshold and, more importantly, one review would mix three independent
authorities.

The mandatory implementation order is therefore frozen as:

```text
ii-c0b-i   canonical eight-configuration producer component
-> ii-c0b-ii  owner-only projected-capsule node and one-shot lease
-> ii-c0b-iii retained-parent launcher engine, narrow executable and PTY stub
-> ii-c0b-iv  zero-argument configuration owner and final composition
-> ii-c       unique real no-model privileged machine gate
-> L3c3d      one authenticated real-success pending candidate
-> L3c4       sealed final admission and authoritative full verifier
```

All four c0b checkpoints remain non-root and non-admitting. `ii-c0b` does not
accept ADR 0018. This umbrella decision freezes c0b-i's exact implementation
surface now. Sections 5–7 freeze required trust separations and candidate
deliverables, but each must receive a fresh exact path/cost preflight before its
code changes; unresolved later composition details do not enter c0b-i.

## 2. Superseded Ambiguities

This preflight supersedes only conflicting live c0 wording; historical reports
retain the evidence true at their checkpoints.

1. **Evidence ownership.** c0b proves gate-side behavior with a deterministic
   non-privileged sudo-shaped stub. It does not prove that real sudo or the root
   driver received the same node, bytes, EOF, TTY or descriptors. The unique
   real observation belongs to ii-c.
2. **Close-on-exec.** The source capsule descriptor is held with `FD_CLOEXEC`.
   The fixed child file action maps that descriptor to standard input so FD 0
   crosses the child exec. Root DriverSupport then sets FD 0 close-on-exec
   during admission before any inner App spawn. “CLOEXEC throughout” is not a
   valid description of the two-stage boundary.
3. **Launcher ownership.** The gate is a retained non-root parent supervisor.
   It spawns the exact fixed child command; it is not replaced by `exec`, because
   the same owner must bound stdout, forward the frozen signal set, wait/reap
   the exact child and close its borrowed capsule descriptor. The c0b-ii owner
   remains in c0b-iv and exclusively performs identity-matched capsule cleanup
   after the gate is reaped. No daemon, helper launch operation or second mutable
   mailbox is introduced.
4. **Result trust.** Captured child stdout and a UID-authored gate receipt are
   transport evidence only. c0b cannot mint or validate root semantic success.
   ii-c must bind actual installed identity, raw completion bytes and exit
   status independently.
5. **Configuration timing and owner.** The mandatory c0b-iv zero-argument
   composition is the sole production owner that creates eight configurations.
   During ii-c it does so only after current App/helper/driver installation
   admission. It passes c0b-i eight in-memory canonical bytes and one already
   observed, path-free typed installation binding. c0b-i never reads
   installation state.
   Synthetic or pre-install bytes cannot become final machine evidence.

## 3. Shared Frozen Data Flow

```text
c0b-iv creates eight fresh configs after one installed binding observation
-> strips that observation to a path-free typed binding
-> passes eight in-memory canonical bytes plus typed binding to c0b-i
-> c0b-i strict-decodes, canonical-reencodes and orders the closed scenario set
-> the supplied binding is joined to all eight configurations
-> exact epoch/projection/capsule/projected-input values are constructed
-> canonical projected-input bytes only
-> c0b-ii creates and owns one private 0700 root plus one exclusive 0600 file
-> one-shot held read-only descriptor lease at offset zero
-> c0b-iii maps only that descriptor to child FD 0
-> fixed sudo-shaped child; FD 1 bounded opaque output, FD 2 unchanged TTY
-> gate-side transport receipt only
-> c0b-iv joins the narrow gate binary and receipt without semantic promotion
-> ii-c independently validates the real root attempt
```

No public API, CLI argument, environment variable, file path or second mailbox
may select a configuration, scenario, ordinal, projection, capsule, executable,
UID, endpoint, signal, action or cleanup operation. Between checkpoints, only
canonical bytes or an opaque one-shot owned descriptor lease may cross the
boundary.

The accepted c0a contracts remain unchanged:

- exactly eight scenarios in `InvestigationHandoffScenario.allCases` order;
- seventeen nonzero unique UUIDs: one outer attempt, eight epoch UUIDs and
  eight configuration nonces;
- exact epoch UUID, configuration nonce, configuration SHA-256 and signed
  runtime-binding SHA-256 joins;
- nested and enclosing strict decode plus byte-identical canonical re-encode;
- zero-before-hash whole-capsule and whole-input digests; and
- package-only, non-`Codable` HandoffContract values.

Root DriverSupport continues to consume only opaque canonical bytes through its
fixed FD-0 intake. It must not import product JSON, `StornautInvestigation`,
Lifecycle, Core, Codex, Execution or any capsule-author/launcher authority.

## 4. ii-c0b-i — Canonical Producer

### 4.1 Ownership and behavior

The component belongs to the existing `StornautInvestigationDiagnostic` package
target because that target already legally sees both the strict product
configuration and the package-only HandoffContract. Its frozen entry is a
package-only `InvestigationProjectedCohortAuthor.author(configurationData:
installedBinding:)`, with internal clock and UUID-provider seams used only by
tests. The clock is sampled exactly once before any decode. The UUID provider
is called exactly once, after every configuration and installed-binding check
succeeds, and returns one outer-attempt UUID followed by eight epoch UUIDs. It
receives exactly eight in-memory `Data` values and one package-only, non-
`Codable` `InvestigationProjectedCohortInstalledBinding`. That value contains
only the App/helper/driver hashes and fixed identifiers required by the c0a
projection; c0b-iv derives it from the independently validated observation. It
contains no URL or descriptor, and the author accepts no installation, signing
or process-observation closure.

The new source is entirely `#if DEBUG`, matching every existing source in the
diagnostic target. c0b-i is component-only: it requires source and SwiftPM
object/symbol positive evidence. Because Xcode links the complete DEBUG static
diagnostic target, the Debug diagnostic App dylib is also an expected carriage
positive control, but source inspection must prove that no production call site
invokes the producer before c0b-iv. Release objects, ordinary App images, the
Release diagnostic shell and Machine driver remain negative controls. Binary
presence in the isolated Debug diagnostic image is not a production-reachability
or machine-admission claim.

The installed binding initializer accepts only canonical lowercase hashes,
fixed App/helper/driver/service identifiers and a 40- or 64-character machine
driver code-directory hash. Matching the shared signed binding is field-for-
field: App executable SHA and bundle identifier; helper executable SHA and
service identifier; driver executable SHA, signing identifier, designated-
requirement SHA and code-directory hash; and machine-claim service identifier.
The code-directory string is decoded exactly once to 20 or 32 bytes for the c0a
projection. No path-bearing fields from the installed observation are copied.

It must:

1. strict-decode every value with
   `SignedInvestigationRuntimeDiagnosticConfiguration.decodeValidated`;
2. require byte-identical `canonicalJSONData()` and exact configuration SHA;
3. require one instance of every closed diagnostic scenario, then order by the
   fixed Handoff scenario order rather than caller order;
4. require eight unique nonzero configuration nonces and one identical complete
   `SignedInvestigationRuntimeBinding`;
5. require the supplied typed installed binding to match that shared binding;
   c0b-i performs no installation, signing or process observation and no
   filesystem write. The accepted existing configuration decoder still performs
   its documented read-only `lstat` validation of the configuration's own root
   paths; those paths remain inside the canonical configuration bytes and never
   enter the installed-binding or projection fields;
6. generate one fresh outer-attempt UUID and eight fresh epoch UUIDs, with all
   seventeen UUIDs distinct;
7. use the existing capability-evidence binding SHA and the existing UTC
   microsecond conversion;
8. construct eight `InvestigationCohortEpoch` and eight complete
   `InvestigationInstalledL2IdentityProjection` values; and
9. return one canonical `InvestigationProjectedCohortInput`.

The existing private scenario mapping in
`InvestigationRuntimeDiagnosticComposition` becomes one package-scoped,
exhaustive mapping owner reused by both the App-leaf acknowledgement and the
producer. No second switch is accepted.

### 4.2 Exact scope and budget

Exactly seven non-document paths and at most 1,900 changed lines:

1. `Sources/StornautInvestigationDiagnostic/InvestigationProjectedCohortAuthor.swift` (new);
2. `Sources/StornautInvestigationDiagnostic/InvestigationRuntimeDiagnosticComposition.swift`;
3. `Tests/StornautInvestigationTests/InvestigationProjectedCohortAuthorTests.swift` (new);
4. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
5. `scripts/verify-contract`;
6. `scripts/verify-investigation-boundaries`; and
7. `scripts/verify-app-release-boundaries`.

`Package.swift`, the Xcode project, HandoffContract sources, DriverSupport, App
sources, filesystem/process authority and public APIs are excluded. Approaching
the ceiling requires another split before continuing.

### 4.3 Tests-first matrix

- all eight scenarios in adversarial input order produce fixed canonical order;
- missing, duplicate, unknown-field, noncanonical, expired or oversized config
  fails before installed-binding comparison or the single UUID-provider call as
  applicable; all eight decodes use one injected clock sample;
- mixed binding, mismatched installed binding, duplicate/zero UUID and UUID
  provider failure fail closed;
- raw configuration bytes, configuration SHA, binding SHA, validity time and
  every field of the new path-free installed binding map exactly; the driver
  code-directory hash accepts only canonical lowercase hex that decodes to 20
  or 32 bytes and rejects uppercase, odd-length or non-hex input;
- the output strict-decodes and byte-identically re-encodes as the accepted c0a
  projected input;
- no separate path/URL input, installation/signing/process observation closure,
  descriptor, XPC, model, network, cleanup, readiness or filesystem-write
  surface enters; and
- source, scope and mutation gates plus Debug SwiftPM object/symbol and Debug
  diagnostic-image carriage evidence pin the component; Release objects,
  ordinary App images, the Release diagnostic shell and Machine driver remain
  negative. Source gating proves there is no production call site before c0b-iv.

Validation order: RED focused tests -> `scripts/verify-investigation-boundaries`
source/scope gate -> focused and affected tests -> `scripts/verify-contract` ->
`scripts/verify-app-release-boundaries` Debug SwiftPM object and diagnostic-image
carriage positive controls plus Release/closed-image absence gate -> independent implementation, verifier and
cross-boundary review. No serial or full verifier belongs to this component-only
checkpoint; the accepted aggregate c0b tree receives one serial at c0b-iv.

## 5. ii-c0b-ii — Owner-Only Capsule Node

This checkpoint introduces a narrow
`StornautInvestigationMachineLaunchSupport` target depending only on the
HandoffContract. It accepts canonical projected-input bytes, strict-decodes and
re-encodes them, and resolves fixed UID 501 with `getpwuid_r`. From that fixed
home it opens `Library/Caches/com.eriklee.stornaut.task39-machine-gate`
component-by-component through no-follow directory descriptors. Each random
leaf is `attempt-<lowercase outer UUID>` with mode `0700`. Inside the held leaf
descriptor it creates `capsule.pending`, exclusively writes mode `0600`, verifies
and synchronizes it, then descriptor-relatively renames it to
`projected-cohort-<whole-input-sha256>.bin`. The file is fixed-UID-owned, regular
with one link, bounded size, no flags, ACL or unexpected xattrs. Partial writes,
`EINTR`, file/directory sync, read-only reopen/rewind and failure cleanup are
explicit.

The returned package-only owner is one-shot and does not expose a caller-usable
path. It can lend only a held read-only descriptor plus immutable node/digest
identity to c0b-iii. It retains cleanup authority until terminal settlement and
unlinks only the exact identity-matched owned file/root. Path replacement or
cleanup ambiguity fails closed and remains typed residue; it never falls back
to broad recursive deletion. Before a new lease, it must hold one kernel-
released exclusive ownership primitive for the fixed base; failure to acquire
it is typed `activeAttempt` and performs no cleanup. Only while that ownership
remains held may it enumerate immediate exact-format children beneath the base.
An empty valid leaf, a valid `capsule.pending`, or a canonical digest-named stale
capsule is removed only after owner/node/digest verification. A symlink,
unexpected entry, owner/mode/link/ACL/xattr/flag drift, malformed name or digest
mismatch yields typed `staleResidueUncertain` and blocks the attempt. This owner
is also the sole stale-recovery authority after a launcher crash; no second
mailbox exists. Its mandatory fresh preflight must prove that the selected
Darwin ownership primitive is automatically released on owner death and cannot
mistake another live attempt for stale residue.

Candidate seven-path / 2,100-line envelope, to be confirmed or split by the
mandatory c0b-ii fresh preflight:

1. `Package.swift`;
2. `Sources/StornautInvestigationMachineLaunchSupport/InvestigationOwnerOnlyCapsule.swift` (new);
3. `Tests/StornautInvestigationTests/InvestigationOwnerOnlyCapsuleTests.swift` (new);
4. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
5. `scripts/verify-contract`;
6. `scripts/verify-investigation-boundaries`; and
7. `scripts/verify-app-release-boundaries`.

No App/Xcode membership, second launch-support source, process spawn, sudo,
shell or product-configuration dependency belongs here.

## 6. ii-c0b-iii — Fixed Launcher and Physical Stub

The launcher engine and executable use the narrow launch-support target. The
executable is `StornautInvestigationMachineGate`; it accepts zero arguments and
no activation environment. Its production construction freezes this child
command exactly:

```text
/usr/bin/sudo -kN -p 'Stornaut Task 39 ii-c administrator authorization: ' -- /Library/Application\ Support/Stornaut/Stornaut-R5-Diagnostic.app/Contents/MacOS/StornautInvestigationMachineDriver
```

There are zero driver arguments. `-S`, askpass, `sudo -v`, shell composition,
cached authority, environment overrides and caller-selected executable/path/
argv/env/UID/endpoint/signal/action are structurally forbidden. The environment
is exactly empty.

FD-1 capture is capped at 512 bytes plus one overflow byte. One absolute
monotonic launcher deadline is 1,200 seconds. The exact forwarded signal set is
`SIGHUP`, `SIGINT`, `SIGQUIT` and `SIGTERM`; `SIGKILL`/`SIGSTOP` are inherently
unhandled, while terminal job-control signals target the foreground group.

Before spawn, the gate requires fixed UID/GID 501/20, writable character-device
FD 2, a positive inherited process group and
`tcgetpgrp(2) == getpgrp()`. The gate is deliberately **not** required to be
that group's leader: it inherits the coordinator's already-foreground process
group, and `getpid() == getpgrp()` is rejected as a contract requirement. The
coordinator performs no foreground-terminal handoff of its own. The gate is the
single process authorized to call `tcsetpgrp` for this attempt. It records the
inherited foreground PGID, blocks the forwarded set plus `SIGTTOU` across the
transition, atomically creates a suspended child in a new process group whose
PGID equals its PID, verifies that identity, sets only the child's group as the
foreground terminal group and sends `SIGCONT`. It then restores its signal mask
and enters the bounded poll/wait loop. A stopped child is not success: the gate
restores the recorded inherited foreground group, resumes the child only to
perform TERM/KILL cleanup, then reaps it.

Every normal exit, forwarded-signal, cancellation, timeout, stop or I/O failure
first reaches a typed terminal child outcome, including TERM, bounded grace,
KILL fallback, waitable observation and exact reap when required. The gate may
temporarily restore the recorded inherited foreground PGID before cleanup when
required to regain terminal control; after exact reap it must again block
`SIGTTOU`, restore and verify that same recorded PGID, revalidate FD 2 and only
then close its borrowed capsule descriptor and finalize only its transport
outcome. It never settles or removes the c0b-ii-owned node and never substitutes
its PID for the saved PGID.
Process-group or TTY restoration uncertainty dominates cancellation and yields
non-admitting typed residue.

The parent maps the one-shot capsule lease only to child FD 0, captures FD 1 as
opaque bounded bytes, preserves FD 2, closes the original capsule descriptor and
every non-allowlisted descriptor in the child, and proves FD 7/8/9 absent at the
**stub child entry**. Real sudo/root-driver FD 0/1/2/7/8/9, same-node, EOF and
digest observations remain exclusively owned by ii-c.

Tests use an internal injected system and a compile-time test-only,
non-privileged sudo-shaped executable. Production source exposes no stub flag,
environment selector or alternate executable. Physical tests create their own
controlled `openpty`/`setsid`/`TIOCSCTTY` fixture rather than assuming the test
runner has a controlling terminal. The positive fixture must make the gate a
non-leader member of the coordinator's foreground process group; a separate
negative fixture must reject a gate whose group is not foreground. Physical
evidence must prove exact argv/env, FD-0 same-node offset-zero-to-EOF/digest,
bounded FD-1 bytes, unchanged foreground TTY/FD-2 identity, the child-only PGID
handoff, restoration of the exact saved coordinator group, no extra descriptor
inheritance, signal/exit behavior and cleanup. It cannot interpret stdout as a
valid completion artifact.

The package-only, non-`Codable` gate transport receipt contains exactly: schema version;
observed launcher executable SHA-256; outer-attempt UUID; whole-input SHA-256;
capsule device/inode/size; gate PID and inherited process-group ID; stub child
PID/PGID; FD-0 observed node, initial and final offsets, EOF and digest;
initial/child/final FD-2 node and foreground PGIDs; stdout byte count and
SHA-256; raw wait classification; forwarded signal if any; monotonic
start/completion; exact-saved-foreground-group-restored flag; and a typed
borrowed-descriptor-closed outcome. It cannot contain capsule cleanup or residue
claims because the retained c0b-ii owner is settled later by c0b-iv. c0b-iv is
the transport receipt's sole package-internal consumer. This receipt is
transport evidence only and cannot satisfy root semantic admission.

Candidate eight-path / 2,800-line envelope, to be confirmed, narrowed or split
by the mandatory c0b-iii fresh preflight:

1. `Package.swift`;
2. `Sources/StornautInvestigationMachineLaunchSupport/InvestigationSudoShapedDriverLauncher.swift` (new);
3. `Tools/StornautInvestigationMachineGate/main.swift` (new);
4. `Tests/StornautInvestigationTests/InvestigationSudoShapedDriverLauncherTests.swift` (new, including its compiled PTY stub fixture);
5. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
6. `scripts/verify-contract`;
7. `scripts/verify-investigation-boundaries`; and
8. `scripts/verify-app-release-boundaries`.

The gate executable must have exact Debug/Release owned/undefined/load
projections and negative controls for Core, Codex, Lifecycle, Execution, cleanup
and networking. No Xcode membership, alternate executable or production stub
selector is allowed.

Before c0b-iii coding, its fresh preflight must close two fatal recovery races
rather than infer them from the happy-path PTY fixture: (1) gate death or
`SIGKILL` after child foreground handoff, including how the retained coordinator
learns the exact suspended/live child group before handoff and can restore the
saved foreground group and retire that child without a second launcher; and
(2) coordinator handling of group-delivered HUP/INT/QUIT/TERM while the gate
owns normal forwarding, so the coordinator cannot independently die and strand
receipt draining, gate reaping or capsule settlement. The normal gate remains
the sole `tcsetpgrp` owner; any coordinator emergency recovery must be typed,
limited to an already proved-dead gate and independently tested.

That preflight must not assume stock sudo retains the stub's direct child-PGID
topology. Before ii-c, a separate real-sudo physical-topology preflight must
account for policy-dependent sudo PTY monitor/session descendants and bind their
termination to the existing driver audit-session/lifecycle evidence. Reaping the
direct sudo PID or emptying its initial PGID alone is never containment proof.
The c0b-iii transport receipt candidate must also add typed child-group-empty,
TERM/grace/KILL progression and exact-reap facts. c0b-iv's final receipt must
add the coordinator's exact gate wait/reap classification.

## 7. ii-c0b-iv — Configuration Owner and Final Composition

This mandatory checkpoint closes the production graph before ii-c. Its required
deliverable is a separate zero-argument
`StornautInvestigationMachineGateCoordinator` executable. A fresh scope/cost
preflight must freeze its exact targets, files, dependencies and binary
projections before coding. The coordinator remains same-UID and may depend on
the DEBUG-only diagnostic/configuration graph plus launch support; it is never
the sudo target. The already sealed `StornautInvestigationMachineGate` remains
the distinct narrow executable and may depend only on HandoffContract plus the
minimum launch-support objects admitted by its final-Mach-O gate. Neither
executable becomes an App/Xcode target. After one installed binding observation
it creates all eight fresh diagnostic roots, plans and configurations in the
fixed scenario set, derives the path-free installed binding, invokes c0b-i, and
passes only canonical projected-input bytes into c0b-ii. It then spawns the
already sealed `StornautInvestigationMachineGate` with zero arguments and an
empty environment. The gate inherits the coordinator's current foreground
process group; the coordinator never repeats the gate's child-PGID foreground
handoff. At gate entry, FD 0 is the held read-only capsule at offset zero, FD 1
is the bounded canonical-receipt pipe and FD 2 is the unchanged controlling
terminal; every descriptor at or above 3 is closed. The coordinator retains the
capsule owner and receipt read end, concurrently drains the bounded transport
receipt, waits/reaps the exact gate, strict-decodes that receipt and only then
settles its retained capsule owner. It then creates a distinct package-only final
coordinator receipt binding the gate transport receipt to the post-reap capsule
cleanup/residue outcome. No gate-authored bytes may predict or claim that later
cleanup result. No caller path, argv, environment selector or filesystem mailbox
exists.

Current source has no production builder for the complete
`SignedInvestigationRuntimeBinding`: installation observation covers App/helper/
driver identity, but repository/source/runtime-receipt/prompt/schema/facade/
Codex hashes exist only as contract fields or test fixtures. The c0b-iv
preflight must therefore name the authoritative current-source receipt inputs
and implement one strict binding builder before it can create configurations.
No caller may supply individual binding fields. If those inputs cannot be
obtained from already sealed receipts without a new mutable sidecar, c0b-iv must
split a binding-source prerequisite and stop before composition.

c0b-iv must deliver the exact two-executable chain, target dependency graph and
source/binary identities that ii-c consumes. It is not optional. The broad
diagnostic graph may exist only in the non-privileged coordinator; it must never
be linked into the narrow gate. The gate's final Mach-O must exclude Core, Codex,
Lifecycle, Execution, cleanup and networking authority regardless of static
package dependencies. If object-level dead stripping cannot prove that exact
absence, c0b-iv must extract a smaller launch-only target; it may not waive the
narrow gate boundary. It also owns validation that the same sealed producer is
used for synthetic tests and fresh post-install ii-c inputs.

No path or line budget is inferred here. c0b-iv receives its own mandatory
fresh preflight after c0b-i/ii/iii have fixed their artifacts; that preflight may
split authoritative binding-source construction from composition but may not
reopen the two-executable privilege boundary. ii-c cannot begin until c0b-iv
implementation, final binary gate, review and push are complete.

## 8. Common Non-Claims

No c0b checkpoint may:

- run real sudo, request root or consume an administrator prompt;
- install, launch or mutate the real App/helper/driver topology;
- claim that real sudo preserved stdin, TTY or descriptors;
- treat a UID-authored receipt, stub result or captured stdout as root semantic
  success;
- prove installed-L2, the real multi-epoch matrix, containment or global zero
  residue;
- call a model, use auth/network, touch Trash/Executor or mutate user data;
- accept ADR 0018, enable Deep Dive, claim machine readiness or run
  `scripts/verify --full`.

c0b-iii behavioral tests invoke only a separately compiled test fixture through
the injected launcher engine. c0b-iii/c0b-iv production verification inspects
the real gate's source, object, target graph and final Mach-O but never executes
its embedded `/usr/bin/sudo` command. ii-c alone executes the final coordinator/
gate chain and observes the real prompt, sudo child and root DriverSupport.

The external B4/stager branch remains NO-GO. The lifecycle helper does not gain
driver-launch authority. Only ii-c owns the single real no-model sudo/driver
attempt and manual prompt evidence; L3c3d owns authenticated model success;
L3c4 owns readiness and the remaining full verifier.

## 9. Prompt-to-Artifact Checklist

| Requirement | Required artifact/evidence | Owner |
| --- | --- | --- |
| strict eight-config semantic producer | package-only author + focused mutation tests | c0b-i |
| fixed scenario order and unique identity set | exhaustive mapper + UUID tests | c0b-i |
| complete installed binding projection | every field of the supplied path-free typed binding joins to all rows; actual observation belongs to c0b-iv/ii-c | c0b-i |
| accepted c0a canonical bytes | strict output decode/re-encode and digest tests | c0b-i |
| no JSON in root driver | source/import/package boundary | c0b-i |
| exclusive owner-only capsule node | narrow author + real disposable filesystem tests | c0b-ii |
| one-shot held FD, no caller path | opaque lease tests and source gate | c0b-ii |
| replacement-safe terminal cleanup | identity mutation/failure matrix | c0b-ii |
| exact fixed sudo-shaped command | constants and source/binary gate | c0b-iii |
| two-stage FD-CLOEXEC behavior | file-action tests plus driver intake regression | c0b-iii |
| TTY/FD/argv/env physical behavior | non-privileged stub receipt | c0b-iii |
| retained-parent signal/wait/reap | injected races and physical stub cases | c0b-iii |
| no root semantic promotion | opaque stdout/receipt negative tests | c0b-iii |
| final production executable chain | mandatory fresh composition/package preflight and final-Mach-O gate | c0b-iv |
| no premature admission | structural no-readiness/no-Executor gate | all |
| bounded review surfaces | exact per-checkpoint scope/budget gates | all |

Every checkpoint receives independent P0–P2 review and its own commit/push.
Only c0b-iv runs the one required staged-only
serial regression for the accepted aggregate c0b tree; earlier package-only
checkpoints use focused/affected/headless gates unless their own frozen brief
requires otherwise.

## 10. Independent Preflight Review

The pre-implementation current-source review found no unresolved P0-P2 in the
frozen c0b-i contract and authorized c0b-i to start. Earlier findings were
closed by:

- making the installed binding an explicit path-free typed input and recording
  the existing configuration decoder's read-only path-metadata validation;
- sampling one clock once and obtaining all nine generated UUIDs in one call,
  only after semantic and installed-binding validation;
- limiting c0b-i evidence to DEBUG component/object and diagnostic-image
  carriage, proving no call site, and requiring Release/closed-image absence;
- separating gate transport evidence from later coordinator-owned capsule
  settlement and final receipt assembly; and
- separating non-privileged stub behavior, production artifact inspection and
  ii-c's unique real-sudo execution.

The review also confirmed that unresolved c0b-ii/iii/iv mechanisms are explicit
fatal stop-before-coding prerequisites rather than claims made by this preflight.
No test, build, root operation, model call, network operation or full verifier
was needed or run for this documentation-only checkpoint.

The subsequent c0b-i implementation is complete/non-admitting at commit
`2493e0f28e0c8d406b4efcdbf17713bde3633449`, parent
`e5ed33e27195d9252f02a89ab39664df3848f1ed` and tree
`8155d64c4966fb83c332f7d195a92095e0af2ba9`. Its exact 7 non-document paths /
1,900 changed lines, 95 tests / 5 suites, full Investigation-boundary gate, exact
staged-scope gate, contract gate and independent no-unresolved-P0–P2 review are
recorded in the
[c0b-i completion audit](phase-d-task-39b2c-l3c3c-ii-c0b-i-review.md). By
design it ran no serial/full/root/sudo, App/helper/driver launch, XPC, model/auth
or network. c0b-ii fresh preflight is now current.
