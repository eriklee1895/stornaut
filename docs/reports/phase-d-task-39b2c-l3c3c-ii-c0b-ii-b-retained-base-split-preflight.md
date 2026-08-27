# Phase D Task 39B2c L3c3c-ii-c0b-ii-b Retained-Base Split Preflight

> Status: mandatory design-correction split frozen / non-admitting
>
> Date: 2026-08-27
>
> Preflight input baseline: `1f3c37f`
>
> Scope: correct the frozen capsule-owner design to retain the exact
> acquisition-time validated base inode, then split publication, recovery and
> verifier responsibilities before implementation

## 1. Decision and Trigger

The former ii-c0b-ii-b candidate cannot be implemented safely as one exact
six-path / 3,400-line checkpoint. The frozen design requires capsule operations
to execute beneath the **same held base directory descriptor** validated while
the permanent lock was acquired. The completed owner currently transfers only
the lock descriptor into `InvestigationMachineGateOwnership`; its acquisition
ledger closes the base descriptor, and the previous ownership API supplied no
base capability. Reopening the base by pathname in ii-b would prove only the
current pathname target, not continuity with the acquisition-time inode.

Silently changing the completed a1 source would also invalidate a2 source, SIL,
component and mutation seals. The missing retained-base capability is therefore
an explicit prerequisite, not an implementation detail that may be hidden in
ii-b. This corrects a design/implementation mismatch without expanding product
scope or weakening any accepted boundary.

The realistic combined surface is approximately 5,200–7,400 changed lines and
crosses four independently reviewable properties. The mandatory order is now:

```text
ii-c0b-ii-a3  retained-base capability prerequisite
-> ii-c0b-ii-b1  canonical publication and one-shot lease
-> ii-c0b-ii-b2  settlement and stale recovery
-> ii-c0b-ii-b3  structural, mutation and component closure
-> c0b-iii  retained-parent launcher / TTY / FD hygiene
-> c0b-iv  zero-argument non-root composition and aggregate serial
-> ii-c  unique privileged no-model machine attempt
-> L3c3d  authenticated real Codex App Server attempt
-> L3c4  final machine admission and authoritative full verifier
```

Every new child remains non-root and non-admitting. None may launch the App,
helper, driver or gate; open XPC; call sudo, a model, authentication or the
network; accept ADR 0018; enable Deep Dive; or claim readiness.

## 2. Preserved Ownership Invariants

All a1/a2 guarantees remain normative: fixed UID/GID 501:20, the fixed
home-relative base, permanent `.owner-lock-v1`, contention-only
`activeAttempt`, no repair of existing nodes, no lock-node unlink/rename, exact
metadata and held/named identity checks, `FD_CLOEXEC`, no descriptor duplication
or child inheritance, and one mutex for owned operations and release.

The correction strengthens the owner as follows:

- acquisition transfers both the validated base descriptor and the locked
  descriptor into the final owner;
- the owner retains the acquisition-time base descriptor, encapsulated inside
  itself, across its full lifetime until explicit release; the descriptor is
  never returned, duplicated, encoded, converted to a path/URL or stored outside
  the owner;
- the public package surface exposes only explicit release and synchronous
  revalidation. It accepts no caller closure or capability; b1 must add only
  typed high-level operations inside this ownership source when it needs to act
  relative to the retained base;
- before every revalidation or future typed owned operation, the owner
  reopens/reobserves both the fixed
  home-relative base name and `.owner-lock-v1`; it proves held/named identity
  plus complete owner, mode, device, link, size, flags, ACL and xattr invariants
  for every applicable node before continuing;
- explicit release closes the base first and the lock last so kernel ownership
  remains held throughout all base work; both closes are exactly once; and
- any revalidation or close uncertainty is terminal uncertainty. `deinit` is
  best-effort leak prevention only and never manufactures success.

No a3 operation exposes the retained base descriptor, enumerates capsule
entries, creates an attempt root, writes a
payload, renames/unlinks a node, retries busy deletion or performs recovery.

## 3. ii-c0b-ii-a3 — Retained-Base Capability

### 3.1 Exact Scope and Budget

Exactly six non-document paths and at most 2,750 added-or-changed lines:

1. `Sources/StornautInvestigationMachineLaunchSupport/InvestigationMachineGateOwnership.swift`;
2. `Tests/StornautInvestigationTests/InvestigationMachineGateOwnershipTests.swift`;
3. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
4. `scripts/verify-contract`;
5. `scripts/verify-investigation-boundaries`; and
6. `scripts/verify-app-release-boundaries`.

A first implementation pass reached 1,444 changed lines across five of the six
frozen paths before `verify-contract` orchestration and final test completion.
The former 1,600-line estimate therefore left no credible repair margin. The
ceiling is corrected before validation to 2,500 lines. Final adversarial review
then required character-depth declaration parsing and diagnostic-bound mutation
evidence, so the ceiling is corrected to 2,750 lines; this remains below the
repository's approximate 4,000-line mandatory split threshold and does not add
a path or responsibility. A seventh non-document path or line 2,751 requires
another split before coding continues.
This checkpoint intentionally supersedes the current-tree a1/a2 source and
component seals. Its verifier must preserve the two historical layers
separately:

1. pin a1 commit `d18354bc7ca7dd2ddb04180298f9fb4f2e7c60e3`,
   its tree, exact three-path scope, Package/source/test identities, and the
   unchanged physical-probe identity and recorded result; a1 had no ii-a shared
   verifier and must not be described as replaying one; and
2. replay a2 commit `f11eea42ef295f49b20e1c0f3912d4b32448b968`
   from its frozen tree using that tree's own `verify-contract`,
   `verify-investigation-boundaries` and `verify-app-release-boundaries`, exact
   four-path scope, source seals and component controls.

Current-tree verification must not substitute for either historical layer or
rewrite history by presenting the new source as old evidence.

### 3.2 Tests-First Matrix

Tests must prove acquisition retains the exact base descriptor; the owner
exposes no descriptor, capability or caller callback; each revalidation checks
held/named base and lock identity and complete metadata; named replacement and
every metadata drift fail closed; concurrent releases are one-shot;
base closes before lock; either close failure is reported; partial release is
terminal; deinitialization attempts only remaining descriptors once; and no
capsule mutation or raw FD/path surface is introduced.

Structural and mutation evidence must reject any descriptor/capability or
caller-closure API, a raw descriptor return, reversed close order, missing revalidation,
duplicate/child-inheritable descriptors, lock mutation and any new product,
process, root, network, Codex, Lifecycle, Core, Execution or readiness reach.
Debug objects remain the positive component control; Release and all product or
privileged images remain negative.

Because a3 changes ownership lifetime semantics, it owns exactly one rerun of
the existing disposable non-root APFS probe after focused tests. The probe must
remain byte-identical and must not touch the fixed product namespace.

## 4. ii-c0b-ii-b1 — Canonical Publication and One-Shot Lease

### 4.1 Exact Scope and Budget

Exactly three non-document paths and at most 2,600 added-or-changed lines:

1. `Sources/StornautInvestigationMachineLaunchSupport/InvestigationMachineGateOwnership.swift`;
2. `Sources/StornautInvestigationMachineLaunchSupport/InvestigationOwnerOnlyCapsule.swift` (new); and
3. `Tests/StornautInvestigationTests/InvestigationOwnerOnlyCapsuleTests.swift` (new).

A mandatory implementation preflight found that the complete publication
failure ledger plus the opaque lease/proof state realistically requires
2,700–3,550 changed lines. The original 2,600-line envelope is therefore split
before coding, while preserving the same exact three-path union:

- **ii-c0b-ii-b1a:** canonical intake, complete pre-mutation inventory,
  publication ledger and verified retained read-only descriptor; at most 2,200
  changed lines; and
- **ii-c0b-ii-b1b:** opaque package lease, one-shot close state, package-closed
  proof shapes and API-escape negatives; at most 1,500 changed lines against the
  pushed b1a implementation.

A fourth path, b1a line 2,201 or b1b line 1,501 requires another split. Both
children own behavior and focused evidence only; shared verifier closure remains
in b3. b1 exposes no package-callable generic descriptor closure or raw-FD
borrow. c0b-iii later adds the sole fixed high-level launch operation, so a
caller can never copy or retain the descriptor integer.

### 4.2 Frozen Behavior

b1 strict-decodes and byte-identically re-encodes
`InvestigationProjectedCohortInput`, enforces its 1,069,056-byte maximum, acquires
the corrected owner and inventories every immediate base entry before mutation.
For this child, any nonempty stale inventory fails closed; deletion begins only
in b2. More than 64 attempt roots is uncertainty.

Through owner-internal typed high-level operations it creates exactly one
`attempt-<lowercase UUID>` directory at 0700 and one exclusive 0600
`capsule.pending`, performs bounded EINTR-aware writes, validates full metadata
and identity, fsyncs the file, publishes with
`RENAME_EXCL | RENAME_NOFOLLOW_ANY | RENAME_RESOLVE_BENEATH`, fsyncs the leaf,
reopens the digest-named final file read-only/CLOEXEC/no-follow/beneath/unique,
and verifies canonical bytes and digest with `pread` while preserving offset
zero. Writers close before one opaque package-only lease is created.

The lease exposes only immutable digest/node identity and one synchronous
borrowed read-only descriptor operation. It exposes no path, URL or
caller-selected FD. A second borrow is rejected, and the internal state records
the exact close outcome for later settlement. If the lease is never borrowed or
the borrow operation throws, its terminal path still closes the retained
capsule descriptor exactly once before ownership release; uncertainty remains
typed and cannot be converted into cleanup success. b1 defines, but does not
forge or consume, the package-closed exact-gate-reaped proof required by
b2/c0b-iv.

Tests cover canonical/malformed/oversized input, complete pre-mutation inventory,
the 64-root bound, names/flags/modes, partial/EINTR writes, both fsyncs, rename
collision, symlink/escape/hard-link replacement, reopen/pread/EOF/digest/offset,
one-shot borrow and close success/failure. Every error asserts exact residue and
that unrelated entries were unchanged.

## 5. ii-c0b-ii-b2 — Settlement and Stale Recovery

### 5.1 Exact Scope and Budget

Exactly the same three non-document paths as b1 and at most 2,200 changed lines
against the pushed b1 implementation:

1. `Sources/StornautInvestigationMachineLaunchSupport/InvestigationMachineGateOwnership.swift`;
2. `Sources/StornautInvestigationMachineLaunchSupport/InvestigationOwnerOnlyCapsule.swift`; and
3. `Tests/StornautInvestigationTests/InvestigationOwnerOnlyCapsuleTests.swift`.

A fourth path or line 2,201 requires another split.

### 5.2 Frozen Behavior

b2 classifies only valid empty, pending and canonical digest-named stale leaves.
It validates complete metadata, bytes, digest and node identity before mutation.
Malformed/partial files, unknown entries, symlinks, hard links, metadata drift
or digest mismatch remain typed residue and block a new attempt. There is no
recursive deletion, mtime/PID/process-name heuristic or lock-node cleanup.

Settlement after a handoff advances only from the owner's actual
borrowed-descriptor-close state and a one-shot package-closed proof that binds
the exact gate reap. A distinct package-closed never-handed-off terminal proof
is required when the descriptor was never lent; callers cannot supply a Boolean
or forge either proof. It
uses only `unlinkat(AT_NODELETEBUSY | AT_UNIQUE |
AT_SYMLINK_NOFOLLOW_ANY | AT_RESOLVE_BENEATH)` under one five-second monotonic
deadline. Only `EBUSY` may retry, with complete identity/metadata/content
revalidation before every retry. `ENOENT`, drift, any other errno, clock failure
or deadline exhaustion yields `settledResidue`; ordinary unlink is forbidden.

Every terminal branch, including never-borrowed, borrow-operation failure and
every `settledResidue` classification, closes any retained capsule descriptor
exactly once and then explicitly releases ownership, which closes the base
descriptor before the lock descriptor. Close uncertainty remains terminal and
must not erase or downgrade residue. Success additionally requires post-unlink
ENOENT proof, identity-matched empty leaf removal and directory fsync before
that release. Tests cover all valid stale
forms, crash recovery, transient/repeated busy outcomes, deadline boundaries,
clock failure, proof mismatch/reuse, never-handed-off termination, throwing
borrow operations, close-before-settle, post-unlink proof failure, nonempty/
replaced leaf, rmdir/fsync/release failure, capsule/base/lock exactly-once close
ordering and terminal-state reuse.

## 6. ii-c0b-ii-b3 — Verifier Closure

### 6.1 Exact Scope and Budget

Exactly four non-document paths and at most 1,800 added-or-changed lines:

1. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
2. `scripts/verify-contract`;
3. `scripts/verify-investigation-boundaries`; and
4. `scripts/verify-app-release-boundaries`.

A fifth path or line 1,801 requires another split.

### 6.2 Proof Surface

b3 owns the four frozen entry points:

- `--iic0b-ii-b-capsule-contract-only`;
- `--iic0b-ii-b-staged-scope-contract-only`;
- `--iic0b-ii-b-source-contract-only`; and
- `--iic0b-ii-b-component-boundary-only`.

It pins a3/b1/b2 commits, trees and source/test identities; exact child and
aggregate scopes; package-only/non-Codable APIs; Debug positive objects; and
Release, ordinary App/helper/driver/Machine and closed diagnostic negative
images. Mutations must reject recursive/FileManager cleanup, ordinary unlink,
path/URL/raw-FD exposure, multiple leases, lock mutation, mutation before full
inventory, unbounded/broad retry, wall-clock deadlines, PID/mtime heuristics,
missing close/reap binding, product/privileged reachability and swallowed command
or inventory failures. Standard bare contract and App/Release gates must invoke
the new checks without repeating already-owned builds.

## 7. Validation Ownership

a3 runs the source, scope, mutation and component gates owned by its six-path
checkpoint. b1 and b2, while restricted to their exact three-path envelopes, run
RED focused tests, directly affected tests, targeted Debug/Release
`StornautInvestigationMachineLaunchSupport` builds, and record index-backed
path, mode and numstat evidence against the exact pushed predecessor commit and
tree. They do not claim the four ii-b verifier entry points, mutation closure or
component/final-image closure.

b3 pins and replays the pushed a3, b1 and b2 commits, trees and source/test
identities; implements and runs all four named ii-b verifier modes; proves each
child and aggregate scope; and supplies the first aggregate ii-b structural,
mutation and component closure. If durable automated source/scope gates are
required before b1 or b2 is pushed, this split must be revised to include
verifier paths in that child.

No a3/b1/b2/b3 child runs a staged-only serial or `scripts/verify --full`.
c0b-iv retains the sole aggregate c0b staged-only serial; L3c4 retains Task 39's
remaining authoritative full verifier. Failed focused gates are rerun only at
the precise failing case after repair.

## 8. Prompt-to-Artifact Checklist

| Requirement | Concrete owner/evidence | Status |
| --- | --- | --- |
| preserve acquisition-time base inode | a3 owner-internal retained base FD | current |
| serialize base work with release | a3 mutex and close-order tests | current |
| preserve historical a1/a2 truth | a3 immutable historical replay | current |
| canonical fresh publication | b1 source/tests | pending |
| one-shot path-free lease | b1 source/tests | pending |
| exact settlement and stale recovery | b2 source/tests | pending |
| reject broad or heuristic cleanup | b2 behavior plus b3 mutations | pending |
| exact source/scope/component closure | b3 four verifier/test paths | pending |
| aggregate c0b regression | one staged-only serial in c0b-iv | later |
| privileged and model evidence | ii-c and L3c3d | later |
| machine admission/full verifier | L3c4 | later |

## 9. Non-Claims

This preflight and all four children are local non-root implementation evidence.
They do not prove real sudo topology, installed App/helper/driver behavior, XPC,
Codex capability, public networking, containment, global zero residue or machine
readiness. ADR 0018 remains Proposed, Task 39 remains incomplete and production
Deep Dive remains unavailable.
