# Phase D Task 39B2c L3c3c-ii-c0b-ii-a1 Ownership Behavior Completion Audit

> Status: complete / non-admitting
>
> Date: 2026-08-27
>
> Implementation commit:
> `d18354bc7ca7dd2ddb04180298f9fb4f2e7c60e3`
>
> Parent: `842b8daf96e19d3e6f904851d4345543f0464b85`
>
> Tree: `d6a4b0ea9f6ee53101fb986fdab5ac4b509de7ad`
>
> Next frontier: ii-c0b-ii-a2 structural and mutation closure

## 1. Result

ii-c0b-ii-a1 is complete and remains non-admitting. It adds the DEBUG-only,
non-product `StornautInvestigationMachineLaunchSupport` target and the narrow
kernel-backed ownership primitive required before an owner-only capsule can be
implemented. The target has no product or Xcode membership and depends only on
`StornautInvestigationHandoffContract`.

The implementation changes exactly three non-document paths and 1,981 lines
against the frozen parent, below the 2,000-line child ceiling. It does not
create a capsule payload, launch any process, request privilege, call a model or
make a readiness decision.

## 2. Implemented Contract

- Identity is resolved through bounded `getpwuid_r` capacities and requires all
  real/effective/account UID and GID axes to equal the frozen 501:20 machine.
- The acquirer walks from a held root descriptor to the canonical home,
  `Library/Caches`, the fixed base and permanent `.owner-lock-v1` inode using
  close-on-exec, nonblocking and no-follow/beneath/unique constraints.
- Existing base and lock nodes are validated but never repaired. Fresh lock
  creation performs the sole owner-only mode transition before validation.
- Held and named base/lock identities, type, ownership, mode, device, link
  count, size, flags, extended ACL and xattrs are checked before and after the
  nonblocking exclusive `flock`.
- Only `EWOULDBLOCK` or `EAGAIN` from the exact flock operation maps to
  `activeAttempt`; every other ambiguous condition fails closed.
- The final owner retains only the lock descriptor. Explicit release is
  one-shot and terminal; deinitialization performs one best-effort close. A
  package-internal, nonescaping ownership operation and release use the same
  mutex, so release cannot close the kernel lock while capsule work is active.
- The lock inode is permanent. No ownership path enumerates, unlinks, renames,
  truncates or replaces it, and no PID, mtime or process-name heuristic is used.

## 3. Exact Scope and Seals

The three non-document paths are:

1. `Package.swift` — 7 changed lines;
2. `Sources/StornautInvestigationMachineLaunchSupport/InvestigationMachineGateOwnership.swift` — 626 added lines; and
3. `Tests/StornautInvestigationTests/InvestigationMachineGateOwnershipTests.swift` — 1,348 added lines.

Accepted SHA-256 identities are:

- `Package.swift`: `15bc5ce89b4a1c416df9c332cad2306cc26299f7903a0de15707f5e0cfbcab8f`;
- ownership source: `eedda4e3a843a76898ddea4bc8fd243b6357efcbf17a4ea9e8438fdc0d561007`; and
- focused tests: `9ffdfa9d956655b05cf9813658a0d00449f38a075f991737f460b2864c8a1e21`.

The a2 aggregate verifier must bind these exact source/test identities and the
implementation commit/tree above.

## 4. Tests and Physical Evidence

| Evidence | Result |
| --- | --- |
| focused ownership suite | 19 test entries / 132 concrete cases passed |
| exact scope | 3 non-document paths / 1,981 changed lines |
| targeted SwiftPM builds | Debug and Release target builds passed |
| object boundary | Debug ownership semantic positive; Release negative |
| committed APFS probe | exit 0 on APFS / UID 501 / GID 20 |
| last-close evidence | normal exit, SIGKILL, dup and close-on-exec cases passed |
| filesystem negatives | ACL/xattr, hard-link, rename, unlink and replacement controls passed |
| terminal residue | disposable probe directory empty except permanent lock |
| independent final review | no unresolved P0-P2 |

The focused fake invalidates closed descriptors across every descriptor API,
preserves the actual mode of an existing lock, observes deterministic mutex
entry before releasing an active ownership operation, and covers the exact
existing-lock reopen failure. It therefore does not manufacture success by
repairing metadata or by relying on scheduler timing.

No staged serial, shared verifier, App/Xcode build or `scripts/verify --full`
was run. Those omissions are required by the a1/a2 split rather than missing
evidence: a2 owns structural/mutation closure, c0b-iv owns the aggregate c0b
serial, and L3c4 owns Task 39's remaining authoritative full verifier.

## 5. Non-Claims and Next Step

This checkpoint did not use root or `sudo`; launch the App, helper or Machine
Driver; open XPC; call Codex/App Server; access authentication or the network;
publish/recover a capsule; or prove machine readiness. ADR 0018 remains
Proposed, Task 39 remains incomplete and production Deep Dive remains
unavailable.

The next frontier is ii-c0b-ii-a2. It must bind this exact pushed implementation
and close the frozen four-path structural, mutation, historical-replay and
component/final-image gates without a staged serial or full verifier.
