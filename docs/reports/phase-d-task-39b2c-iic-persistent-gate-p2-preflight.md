# Phase D Task 39B2c ii-c persistent Gate P2 preflight

> Status: frozen / non-admitting prerequisite
>
> Date: 2026-09-09
>
> Baseline: `188d40e394a0205bcffd0718050421b09dffb071`

## Problem

P1 moved the future Gate to owner-private Application Support. The current
admitting evidence path is still schema v2: production requires the lost v11
capsule and the independent verifier opens the historical Caches path. Since
that capsule cannot be reconstructed, copied or migrated, a future campaign
cannot legally satisfy the current admission contract.

## Frozen design

- Schema v1 and v2 remain strict read-only compatibility formats. They cannot
  admit a future complete cohort.
- The future producer emits global-post-teardown schema v3. It binds the fixed
  Application Support relative suffix, exact base and owner-lock device/inode/
  generation identities, one-entry inventory, zero-byte lock, and successful
  exclusive nonblocking owner-lock observation.
- The independent verifier opens the fixed persistent base descriptor-
  relatively with no-follow/beneath/unique flags, validates owner/mode/ACL/
  xattr/link/size, acquires the owner lock nonblocking, compares both identities
  to schema v3, watches/revalidates the held path, and accepts no extra entry.
- The coordinator no longer asks the new persistent base to preserve an absent
  historical capsule. Historical capsule code/tests remain available for
  read-only v2 evidence; no old cache is migrated, recreated or deleted.
- P2 remains non-admitting as a checkpoint. It does not authorize or run a new
  privileged campaign, L3c3d, L3c4, Task 40 or the full verifier.

## Scope and validation

The implementation is limited to eight non-document paths: coordinator
composition, campaign producer, Swift evidence decoder, campaign tests, target
boundary tests, independent verifier, Investigation boundary verifier and the
aggregate contract. Expected change is below 2,000 non-document lines. The
current implementation is 1,395 changed non-document lines.

Validation order is structural/mutations, focused campaign tests, affected
Investigation suites, one serialized SwiftPM regression, the existing campaign
Debug/Release boundary, then two independent reviews. `scripts/verify --full`,
sudo, install, model, network and a real campaign remain forbidden here.
