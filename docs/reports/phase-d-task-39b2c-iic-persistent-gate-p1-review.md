# Phase D Task 39B2c ii-c persistent Gate P1 review

> Status: implementation complete / non-admitting
>
> Date: 2026-09-09
>
> Baseline: `3be6da6b97c80943ed657ee1d06ed511ab70f610`

## Scope and decision

The v12 audit proved that security-critical Gate residue cannot remain under
the purgeable `~/Library/Caches` hierarchy. P1 changes only the future
owner-private Gate topology and its non-privileged evidence harnesses:

- the exact base is now
  `~/Library/Application Support/com.eriklee.stornaut.task39-machine-gate`;
- descriptor-relative traversal, no-follow/resolve-beneath flags, UID/GID,
  `0700` base, `0600` permanent lock, empty ACL/xattrs and nonblocking lock
  semantics are unchanged;
- the old cache tree is neither migrated, reconstructed nor deleted;
- v8-v12 historical disposition verification remains read-only and continues
  to describe the path that existed when those attempts ran.

The implementation stayed below the checkpoint ceiling: nine non-document
source/test/verifier paths and 410 changed non-document lines. Future schema/
admission semantics are deliberately deferred to P2 so this checkpoint cannot
claim machine readiness.

## Evidence

- 24/24 ownership tests passed, including identity, path-component, mode,
  descriptor, ACL/xattr, contention and exact-close fault matrices.
- 40/40 owner-only capsule tests passed against the new base topology.
- The physical fixture's non-mutating enablement test passed; the mutating
  physical case remained explicit opt-in and was not run.
- The dedicated target-boundary test passed (67 selected tests total, with the
  one privileged mutating physical case explicitly skipped).
- The current persistent-path structural gate and six mutations passed.
- The current Debug/Release coordinator binary gate passed: Debug contains the
  exact ownership-specific persistent suffix and excludes the old cache suffix;
  Release contains neither Gate suffix nor the Gate base name. The independent
  gate self-seals this entry point, and function/call-edge mutations
  fail closed.
- The enclosing ii-c aggregate contract passed. No sudo, fixed-runtime install,
  model, network, privileged campaign or authoritative full verifier ran.

P1 is complete/non-admitting. P2 must still add the future schema-v3 lock-only
teardown/admission contract before a new campaign can be authorized.
