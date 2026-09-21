# Phase D Task 39B2c L3c3c-ii-c0b-ii Ownership Split Preflight

> Status: ownership mechanism and a1/a2 budget split frozen; ii-c0b-ii-a1 and
> ii-c0b-ii-a2 are complete/non-admitting; retained-base correction split
> frozen; ii-c0b-ii-a3 is the current frontier
>
> Date: 2026-08-27
>
> Baseline: `c337bef01a4207ab1c223de3fe8defd9d617013a` / tree
> `f21b0f2ca31ccdde617f28cc9de8fbc0503be07f`
>
> Scope: split the c0b-ii owner-only capsule checkpoint before coding, bind it
> to a disposable non-root APFS probe, and freeze exact implementation envelopes
> without adding product admission

## 1. Decision

The former seven-path / 2,100-line c0b-ii candidate mixed two independently
reviewable security properties: kernel-released attempt ownership and the
capsule file state machine. That surface is too broad for one checkpoint and
would make a filesystem-liveness defect reopen canonical payload work. It is
superseded by this strict order:

```text
ii-c0b-ii-a1  kernel last-close ownership behavior and focused evidence
-> ii-c0b-ii-a2  structural, component, mutation and replay closure
-> ii-c0b-ii-b  owner-only capsule node and one-shot descriptor lease
-> c0b-iii  retained-parent launcher / TTY / FD hygiene
-> c0b-iv  zero-argument non-root composition
-> ii-c  unique privileged no-model machine attempt
-> L3c3d  authenticated real Codex App Server attempt
-> L3c4  final machine admission and authoritative full verifier
```

Both ii-c0b-ii children and the a1/a2 ownership sub-checkpoints remain non-root
and non-admitting. Neither starts an App,
helper, driver, XPC connection, model, authentication flow or network request.
Neither runs a staged serial or `scripts/verify --full`; c0b-iv owns the one
aggregate c0b staged-only serial and L3c4 owns Task 39's remaining full run.

## 2. Threat and Ownership Boundary

The current local-only candidate serializes cooperating Stornaut attempts under
fixed UID 501. It does not claim protection from an arbitrary malicious
same-UID process. Such protection would require a helper/root-owned namespace
and a new trust/scope preflight; it cannot be silently added to c0b-ii.

The fixed base is:

```text
<getpwuid_r(501).pw_dir>/Library/Caches/com.eriklee.stornaut.task39-machine-gate
```

The ownership inode is the fixed `.owner-lock-v1` regular file. It is created
with mode `0600`, opened descriptor-relatively, and held with
`flock(fd, LOCK_EX | LOCK_NB)`. It is permanent state: no Stornaut code may
unlink, rename, replace or clean it. Removing and recreating that pathname can
produce two simultaneous exclusive locks on different inodes; the physical
probe contains this negative control.

Only `EWOULDBLOCK`/`EAGAIN` from the nonblocking lock maps to typed
`activeAttempt`. Every other syscall error, identity/metadata mismatch, unknown
entry, close failure or ownership transition is uncertainty and performs no
stale cleanup. PID files, mtimes, process names and `kill(pid, 0)` are not
ownership evidence.

The lock descriptor is `FD_CLOEXEC`, is never duplicated through `dup` or
`F_DUPFD*`, is never mapped to a child, and is never borrowed by ii-c0b-iii.
The ii-c0b-ii-a source cannot fork or spawn. The capsule payload descriptor is
a distinct object. Ownership lasts until ii-c0b-iv has reaped the gate and
settled ii-c0b-ii-b. `flock` releases only when the last inherited description
closes; owner death is equivalent to last close only because ii-c0b-ii-a forbids
duplication and ii-c0b-iii/iv must prove that the descriptor is absent from every
child file-action allowlist and closed across exec.

The fixed base plus the validated `.owner-lock-v1` inode are persistent
infrastructure, not per-attempt residue. For this branch, zero attempt residue
means exactly zero `attempt-*` roots, zero pending/final capsule nodes, and no
base entry other than the exact admitted lock inode. L3c4 must observe and bind
that baseline explicitly; existing lifecycle artifact counters are not proxy
evidence for it.

## 3. Physical Evidence

`scripts/probe-investigation-capsule-lock` is a non-root, disposable physical
probe. It refuses non-APFS filesystems, UID other than 501, GID other than 20,
optimized Python execution and base metadata other than owner 501:20 / mode
0700. It uses a random `mktemp` root on the Data volume and never touches the
fixed product candidate path.

Observed machine:

- macOS 26.5.1 (`25F80`), Darwin 25.5.0 arm64;
- Xcode 26.6 (`17F113`), macOS SDK 26.5;
- `/usr/bin/python3` 3.9.6;
- APFS, UID 501 and GID 20.

The probe proves:

1. same-process separate-open and independent-process contenders receive
   `EWOULDBLOCK/EAGAIN` (`35`);
2. a duplicated lock description retains ownership until its last close;
3. normal exit, exact `SIGKILL` reap and `FD_CLOEXEC` across `execve` release
   ownership of the same inode;
4. `AT_NODELETEBUSY | AT_UNIQUE | AT_SYMLINK_NOFOLLOW_ANY |
   AT_RESOLVE_BENEATH` returns `EBUSY` (`16`) while a child holds the payload;
5. after exact reap, APFS may transiently retain `EBUSY`; safe cleanup therefore
   requires same-inode revalidation and bounded retry against one monotonic
   deadline. Exhausting that deadline is residue, never permission to use an
   ordinary unlink fallback;
6. `O_UNIQUE` accepts a one-link regular file and rejects a two-link inode with
   `ENOTCAPABLE` (`107`) without mutation;
7. `renameatx_np(RENAME_EXCL | RENAME_NOFOLLOW_ANY |
   RENAME_RESOLVE_BENEATH)` publishes a fresh name while preserving inode and
   bytes, returns `EEXIST` (`17`) without changing either node on collision,
   returns `ELOOP` (`62`) through a symlink component, and returns
   `ENOTCAPABLE` (`107`) on `../` escape;
8. unlinking/recreating the fixed lock pathname permits dual exclusive owners,
   proving why the lock inode must remain permanent; and
9. an inherited macOS extended ACL remains invisible to `flistxattr` but is
   detected by `acl_get_fd_np` / `acl_get_entry`, while the admitted base and
   lock require both an empty ACL and an empty xattr list.

All IPC reads and child reaps use five-second monotonic deadlines. Exceptional
cleanup uses bounded TERM, KILL and exact reap; a remaining PID is a probe
failure. The successful path closes descriptors, validates exact fixture
identities, removes the permanent lock only because the entire random probe root
is disposable, and proves both nested directories can be removed with `rmdir`.
An independent parent-shell check observed zero matching roots and processes.

The final source SHA-256 at preflight review is
`731b613e4b8c1c5c09e34e412b5c7ea25630a8ac2f9e6549131482770bc0acf6`.
Twenty consecutive executions of this final source and one execution with external
`PYTHONOPTIMIZE=1` all exited zero. The isolated interpreter reported
`pythonOptimize: 0`; no correctness condition uses Python `assert`. During the
stability run, post-reap removal required one or two attempts, directly
supporting the bounded-retry correction above.

The probe is a kernel/filesystem-semantic witness, not an end-to-end production
bootstrap. Its duplicated and inherited descriptors are deliberate negative
controls that production source forbids. It creates `.owner-lock-v1` with
`O_CREAT | O_EXCL`, proves a second exclusive create returns `EEXIST`, and then
reopens without chmod, truncate, chown or other repair.

## 4. ii-c0b-ii-a — Kernel Ownership Prerequisite

### 4.1 Preflight Evidence Checkpoint

This preflight commits `scripts/probe-investigation-capsule-lock` as its sole
non-document path, mode `100755`, with a ceiling of 800 changed lines. The
implementation checkpoint starts from that pushed preflight baseline and must
not count or modify the probe.

### 4.2 Exact Scope and Cost

The original exactly seven-path / 2,600-line planning envelope was superseded before
implementation continued: the source/test plus verifier surface is now
estimated at 2,720–2,870 lines. The mandatory
[ii-c0b-ii-a budget split](phase-d-task-39b2c-l3c3c-ii-c0b-ii-a-budget-split-preflight.md)
preserves the exact seven-path union but freezes it as:

- **ii-c0b-ii-a1:** exactly three non-document paths / 2,000 lines —
  `Package.swift`, the ownership source and its focused tests; and
- **ii-c0b-ii-a2:** exactly four non-document paths / 1,200 lines — the target-
  boundary tests plus `verify-contract`, `verify-investigation-boundaries` and
  `verify-app-release-boundaries`.

ii-c0b-ii-a2 may start only from the exact pushed a1 commit/tree recorded in
the budget-split report. Each child must remain within its own ceiling and the
exact seven-path union must remain at or below the stricter 2,870-line aggregate
ceiling; neither child may add a non-document path without another split.
ii-c0b-ii-a2 subsequently completed at implementation
`f11eea42ef295f49b20e1c0f3912d4b32448b968` / tree
`d0683495ea37d0692677c98f491f3037eaedba4c`: exact 4 paths / 889 lines and
aggregate 7 paths / 2,870 lines. Bare contract/component/App-Release exited 0,
two independent reviews found no unresolved P0–P2, and no serial/full/root/App/
XPC/model/network run occurred.

In ii-c0b-ii-a1, the new `StornautInvestigationMachineLaunchSupport` target depends only on
`StornautInvestigationHandoffContract`; the Investigation test target adds the
new dependency. It is not a package product. No product, App or Xcode target
gains this dependency in ii-c0b-ii-a.

### 4.3 Frozen API and State

The production shape is a target-internal acquirer plus a non-copyable-in-
practice reference owner:

- `InvestigationMachineGateOwnershipAcquirer` is internal and has a production
  initializer plus an injected-system initializer;
- `InvestigationMachineGateOwnership` is internal, `final` and
  `@unchecked Sendable`, with an `NSLock` protecting its sole live descriptor;
- explicit release is exactly once and reports close uncertainty; `deinit` only
  performs best-effort leak prevention and can never convert a failed explicit
  release into success;
- no package/public API returns the lock FD, path or URL. A future ii-c0b-ii-b method
  may execute a package-only, synchronous owned-base operation, but cannot let a
  raw descriptor escape or survive suspension; and
- no ii-c0b-ii-a owner or evidence conforms to `Codable`; no readiness, containment,
  root, model or cleanup-success vocabulary appears.

The production acquisition sequence is:

1. resolve UID 501 with a bounded `getpwuid_r` buffer loop, require GID 20, and
   copy a canonical absolute home path before the passwd buffer expires;
2. require home, `Library` and `Caches` to exist, and open them
   component-by-component through directory FDs with no-follow/beneath
   constraints; only the final fixed base may be created, and an existing base
   is validated rather than chmod/chown/replaced;
3. first try `.owner-lock-v1` descriptor-relatively with `O_CREAT | O_EXCL |
   O_RDWR | O_CLOEXEC | O_NONBLOCK | O_NOFOLLOW_ANY | O_RESOLVE_BENEATH`; only
   the just-created inode may receive an exact `fchmod(0600)` if required; on
   `EEXIST`, reopen without `O_CREAT`, and never chmod, truncate, chown, unlink,
   rename, replace or otherwise repair the existing inode;
4. validate regular-file type, UID/GID 501:20, mode 0600, link count one, size
   zero, no flags, no ACL/xattrs, and lock/base device consistency;
5. acquire `LOCK_EX | LOCK_NB`; map only contention errno to `activeAttempt`;
6. re-read both the fixed home-relative base entry and named lock entry, prove
   they match the held base/lock device, inode and generation, then revalidate
   flags and all metadata before returning the owner; and
7. close every non-owned descriptor exactly once on every branch.

The fixed lock inode is never deleted, renamed or replaced, including after
close errors, last close, stale residue or successful settlement.

### 4.4 Tests-First and Verifier Matrix

Focused injected tests must cover successful first creation and reopen, exact
component order/flags/modes, real/effective UID/GID 501:20, bounded
`getpwuid_r` `ERANGE`, malformed home, wrong UID/GID,
symlink/type/mode/link/size/flag/ACL/xattr/device drift, named vs
held identity replacement before and after lock, every syscall failure,
EINTR handling where specified, `O_CREAT | O_EXCL` / `EEXIST` reopen races,
contention-only `activeAttempt`, concurrent acquire/release, terminal-state
reuse rejection, explicit close exactly once and close failure, deinit best
effort, and zero enumeration/cleanup before or after failed acquisition. The
real-filesystem cases use only random disposable APFS roots.

The physical probe is a required ii-c0b-ii-a1 focused gate and must retain its complete
positive/negative controls, explicit checks, bounded waits, exact cleanup and
machine constraints. Mutation gates must reject removal/replacement of
`LOCK_NB`, `FD_CLOEXEC`, no-follow/beneath/unique checks, named-FD identity
revalidation, permanent-lock prohibition, contention errno narrowing, explicit
close reporting or probe target-machine assertions.

ii-c0b-ii-a2 owns the structural gates that freeze exact paths/modes/budget, target dependency and
source inventory, package-only/non-Codable surface, no App/Xcode/product call
site, no process spawn/shell/sudo/network/Core/Lifecycle/Codex/Execution import,
and no PID/mtime/process-name ownership heuristic. Debug SwiftPM object is the
positive symbol control; Release/ordinary App/helper/driver/Machine and closed
diagnostic images are negative controls.

The exact verifier entry points are:

- `verify-investigation-boundaries --iic0b-ii-a-ownership-contract-only`;
- `verify-investigation-boundaries --iic0b-ii-a-staged-scope-contract-only`;
- `verify-app-release-boundaries --iic0b-ii-a-source-contract-only`; and
- `verify-app-release-boundaries --iic0b-ii-a-component-boundary-only`.

`verify-contract` owns c0b-i immutable replay, source/test seals and mutation
fixtures, but does not repeat the component build already owned by the last
entry point. Every verifier command failure must fail closed.

Validation order is a1 RED/focused/affected tests, targeted target builds, the
physical probe and independent source/test review; then a2 source/scope,
contract and App/Release boundary gates plus independent verifier/cross-boundary
review. No serial or full run belongs to a1, a2 or aggregate ii-c0b-ii-a.
`verify-contract` must also replay the immutable c0b-i implementation
commit `2493e0f28e0c8d406b4efcdbf17713bde3633449` with that commit's own verifier,
tree, exact scope and source seals before accepting shared-verifier changes.

## 5. ii-c0b-ii-b — Owner-Only Capsule Node

### 5.1 Exact Scope and Cost

Exactly six non-document paths and at most 3,400 added-or-changed lines:

1. `Sources/StornautInvestigationMachineLaunchSupport/InvestigationOwnerOnlyCapsule.swift` (new);
2. `Tests/StornautInvestigationTests/InvestigationOwnerOnlyCapsuleTests.swift` (new);
3. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
4. `scripts/verify-contract`;
5. `scripts/verify-investigation-boundaries`; and
6. `scripts/verify-app-release-boundaries`.

Any need for a seventh source/test/script path or more than 3,400 lines triggers
a new split before coding. Package/target creation belongs exclusively to
ii-c0b-ii-a.

### 5.2 Frozen State Machine

```text
unacquired
-> exclusiveBaseOwned
-> staleSweepComplete
-> pendingCreated
-> finalReopenedReadOnly
-> leased
-> descriptorClosed
-> settledRemoved | settledResidue
```

Before writing, ii-c0b-ii-b strict-decodes and canonical re-encodes c0a bytes and
enforces `InvestigationProjectedCohortInput.maximumByteCount` (`1,069,056`). It
acquires ii-c0b-ii-a ownership before listing or deleting anything, revalidates the
fixed base pathname against the held base FD, and inspects every immediate entry
before the first mutation. More than 64 attempt roots is uncertainty.

The only leaf form is `attempt-<lowercase UUID>` at mode 0700. The pending file
is exactly `capsule.pending`, mode 0600, created exclusive/no-follow/unique.
ii-c0b-ii-b writes with bounded EINTR-aware progress and verifies full
owner/mode/link/size/
flags/ACL/xattr/identity, fsyncs the file, publishes with the exact safe
`renameatx_np` flags to
`projected-cohort-<whole-input-sha256>.bin`, and fsyncs the leaf directory. It
then reopens read-only with CLOEXEC/no-follow/beneath/unique, uses `pread` to
verify canonical bytes and digest while retaining offset zero, closes every
writer, and creates one opaque package-only lease.

The lease exposes immutable digest/node identity and one one-shot borrowed
read-only descriptor operation, never a path, URL or caller-selected FD. A
second borrow is rejected. The borrowed descriptor must be explicitly reported
closed before settlement starts. Settlement cannot accept a caller-supplied
Boolean; it advances only from the actual internal lease-close state and a
package-closed proof that the exact gate was reaped.

Settlement revalidates the exact final name, node identity and complete metadata
under the still-held ii-c0b-ii-a owner. It then attempts
`unlinkat(AT_NODELETEBUSY | AT_UNIQUE | AT_SYMLINK_NOFOLLOW_ANY |
AT_RESOLVE_BENEATH)` against the same inode with a single five-second monotonic
deadline. Only `EBUSY` may retry, and every retry first revalidates device,
inode, generation, UID/GID, mode, link count, size, digest, flags, ACL and
xattrs. `ENOENT`, identity drift, any other errno or deadline expiry yields
`settledResidue`; there is no ordinary unlink fallback. The ownership lock stays
held through final classification and directory fsync. Successful unlink
requires ENOENT proof, identity-matched empty leaf removal, directory fsync and
explicit ii-c0b-ii-a lock release.

Stale recovery is equally strict. Empty valid leaves, exact pending nodes and
canonical digest-named final nodes may be removed only after complete metadata,
content/digest and identity validation. A malformed/partial pending file,
unknown entry, symlink, hard link, unexpected metadata, digest mismatch or busy
node remains typed residue and blocks the new attempt. No recursive deletion,
mtime-based recovery or lock-inode cleanup exists.

### 5.3 Tests-First and Verifier Matrix

Tests must cover strict canonical intake, maximum size, stale enumeration before
mutation, the 64-root cap, every allowed and malformed entry form, partial/
EINTR writes, file and directory fsync failures, exclusive rename collision,
symlink/path escape/hard-link replacement, read-only reopen, `pread` offset zero,
one-shot lease/borrow, close-before-settle, exact cleanup, transient `EBUSY`
retry, deadline residue, identity drift, close failure and crash-style stale
recovery. Every failure path must assert the exact nodes that remain and that no
unrelated node changed.

Mutation and structural gates must reject recursive deletion, `FileManager`
cleanup, ordinary unlink fallback, path/URL exposure, public or Codable owners,
multiple leases, lock inode mutation, mutation before complete enumeration,
unbounded retry, wall-clock deadlines, PID/mtime heuristics, process/network/
root/Executor imports or any readiness/product call site. Debug SwiftPM object
and the future c0b-iv coordinator are the only eventual positive consumers; all
current product and privileged images remain negative in ii-c0b-ii-b.

The exact verifier entry points are the corresponding
`--iic0b-ii-b-capsule-contract-only`,
`--iic0b-ii-b-staged-scope-contract-only`,
`--iic0b-ii-b-source-contract-only` and
`--iic0b-ii-b-component-boundary-only` modes.

Validation order is RED focused tests, source/scope gate, focused/affected tests,
contract and App/Release boundary gates, then independent implementation,
verifier and cross-boundary review. No serial or full run belongs to
ii-c0b-ii-b.

## 6. Stop Conditions and Non-Claims

Stop and re-preflight before coding or before continuing if:

- the fixed path cannot be reached through verified descriptor-relative
  components without broad filesystem APIs;
- lock bootstrap requires replacing or deleting an existing lock inode;
- target APFS does not provide the observed `flock`, unique-open, safe-rename or
  busy-delete semantics;
- an owner or raw descriptor must become public, Codable, path-addressable or
  survive an async suspension outside the locked owner;
- stale cleanup cannot be limited to exact immediate entries and exact identity;
- the scope exceeds either frozen path/line envelope; or
- implementation needs Core, Lifecycle, Codex, Execution, App/Xcode membership,
  process launch, sudo/root, XPC, model/auth/network or a second mailbox.

This preflight does not prove resistance to malicious same-UID namespace
mutation, real sudo topology, TTY/FD transfer, installed-L2 freshness, model
success, containment, global zero residue or machine readiness. It does not
accept ADR 0018 or enable production Deep Dive.

## 7. Prompt-to-Artifact Checklist

| Requirement | Concrete artifact/evidence | Owner/status |
| --- | --- | --- |
| kernel-released exclusive ownership candidate | disposable APFS probe, fixed-inode `flock`, death/exec/last-close cases | preflight complete |
| unique and replacement-safe node operations | `O_UNIQUE`, safe rename collision/symlink/beneath controls | preflight complete |
| target machine and bounded probe cleanup | APFS/501:20/0700 hard gates, monotonic IPC/reap, exact `rmdir` | preflight complete |
| narrow ownership module | target + internal acquirer/final owner + focused tests | ii-c0b-ii-a1 complete |
| permanent lock inode and contention-only active state | a1 source/physical evidence + a2 mutation gates | a1/a2 complete/non-admitting |
| exact capsule publication | canonical bytes, exclusive rename, fsync/reopen/pread proof | ii-c0b-ii-b pending |
| one-shot path-free descriptor lease | owner/lease state tests and source gate | ii-c0b-ii-b pending |
| replacement-safe settlement/recovery | identity-bound busy retry and residue matrix | ii-c0b-ii-b pending |
| no premature product or privilege reachability | package/source/final-image negative controls | a1/a2 complete; ii-b pending |
| independent no-P0-P2 review and separate commits | review records and pushed commits | a1/a2 complete; ii-b pending |
| aggregate c0b serial | one staged-only run after c0b-iv | later |
| machine readiness/full verifier | ii-c/L3c3d/L3c4 evidence | later |

## 8. Independent Preflight Review

Three independent read-only reviews covered the executable probe, the ownership
contract and cross-file status routing. Initial review findings were closed in
the executable probe or frozen contract as applicable: last-close rather than
generic owner-death semantics, persistent-lock zero-residue accounting,
no-repair existing-lock bootstrap, complete checkpoint names, historical-report
preservation and an extended-ACL false-green window.

The final probe is 793 lines, mode `100755`, SHA-256
`731b613e4b8c1c5c09e34e412b5c7ea25630a8ac2f9e6549131482770bc0acf6`.
Its ACL fix separately observes xattrs and Darwin extended ACLs and includes an
inherited-ACL negative control. Twenty consecutive normal executions plus one
external-`PYTHONOPTIMIZE=1` execution passed, with zero matching temporary roots
or child processes afterward. Final probe, contract and cross-file reviews found
no unresolved P0–P2.

The follow-on budget split is frozen in
[ii-c0b-ii-a Budget Split Preflight](phase-d-task-39b2c-l3c3c-ii-c0b-ii-a-budget-split-preflight.md);
ii-c0b-ii-a1 is complete at `d18354b` / tree `d6a4b0e`; ii-c0b-ii-a2 is
complete/non-admitting at implementation `f11eea42ef295f49b20e1c0f3912d4b32448b968`
/ tree `d0683495ea37d0692677c98f491f3037eaedba4c`, with completion evidence in
the [a2 review](phase-d-task-39b2c-l3c3c-ii-c0b-ii-a2-review.md). The
[retained-base split](phase-d-task-39b2c-l3c3c-ii-c0b-ii-b-retained-base-split-preflight.md)
is frozen; the current frontier is ii-c0b-ii-a3, followed strictly by
ii-c0b-ii-b1 -> ii-c0b-ii-b2 -> ii-c0b-ii-b3 -> c0b-iii -> c0b-iv -> ii-c ->
L3c3d -> L3c4. Task 39 remains incomplete, ADR 0018 remains Proposed
and production Deep Dive remains unavailable.
