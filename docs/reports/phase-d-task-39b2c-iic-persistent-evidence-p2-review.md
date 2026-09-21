# Phase D Task 39B2c ii-c persistent evidence P2 review

> Status: implementation complete / non-admitting / fresh authorization required
>
> Date: 2026-09-14
>
> Baseline: `8a28c5b0ea36d13ae279c2f804b0a528603ddb23`

## Result

Future production machine raw evidence no longer uses Darwin's purgeable
per-user temporary directory. The campaign resolves the current account's
existing physical `Library/Application Support` directory, validates the
owner/mode and creates one campaign-unique `stornaut-iic-evidence-<UUID>`
sibling through a held directory FD. The raw writer then applies its existing
owner-private, ACL/xattr-free, held-FD and durable-write contract below that
parent.

The production fixed-Gate profile now preserves the exact v13 and v16 historical
capsules. Both are validated before any stale cleanup or fresh publication; an
unlisted stale entry is removable, but neither preserved attempt/capsule can be
removed or substituted. The read-only persistent Gate observer holds and
revalidates both attempts and both capsule files, and returns their ordered
physical identities.

New machine evidence emits strict teardown schema v5 with an exact ordered
`preservedGateCapsules` array for v13 then v16. Schemas v1-v4 remain readable
for historical evidence, but v4 no longer satisfies current admission. The
independent machine verifier admits schema v5 only when the evidence parent is
the exact campaign-named owner-private sibling below the account's physical
`Library/Application Support`. That sibling must contain only the exact evidence
root and `seal.json`, and both paths must resolve through the same held parent
identity. Both live Gate capsules must match their fixed semantic, byte and
physical identities, and all evidence and Gate FDs must remain stable through
the final barrier.

Creating that sibling is now a durable transaction: the containing Application
Support FD is synchronized after `mkdirat`. Open or identity failures remove
only the exact held/named empty inode and synchronize the parent again. Once
writer initialization has produced a partial tree, failure preserves it and
reports a typed `stage + residue` result instead of recursively deleting
uncertain evidence.

## Validation

- Swift parse and targeted campaign build: exit 0.
- P2 source/authority structural gates: exit 0.
- P2 exact 11-path / 2,249-line staged scope: exit 0.
- Existing ii-c aggregate, including immutable v17 and P1 replays plus all
  current source/mutation gates and the P2 scope positive plus nine negative
  fixtures: non-TTY exit 0. An earlier PTY attempt reached the historical
  physical authorization prompt and was immediately interrupted without input.
- Affected focused selection: 226 tests / 3 suites / 0 failures after the one
  stale diagnostic assertion was corrected.
- Final Evidence suite: 124 tests / 1 suite / 0 failures. This includes durable
  create, sync/open/identity failure rollback, typed partial writer residue,
  exact Application Support parent admission, arbitrary sibling and TMPDIR
  rejection, and deterministic live v16 capsule overwrite rejection between
  initial and final observation.
- Post-review first-artifact closure adds a typed `publishInitialEvidence`
  boundary. Seven create/write/sync/rename/reopen/read fault cases preserve the
  partial tree and report `stage=publishInitialEvidence residue=preserved`; the
  focused 7-case test passed.
- Live read-only Application Support Gate matrix: schema-v5 admission passed;
  v4 remained non-admitting; ten missing/extra/bytes/mode/link/xattr/symlink
  mutations failed closed; the Gate tree was byte/metadata/xattr stable.
- One clean staged-only `StornautInvestigationTests` serial executed 1,083 tests
  / 66 suites. 1,081 tests passed. The only two failing unchanged physical
  tests produced 17 issues because `posix_spawn` of the suspended setuid `sudo`
  child returned `EPERM` inside the temporary validation worktree; no matching
  PID/PGID remained. This environmental result was recorded and the serial was
  not repeated.
- No privileged campaign, administrator credential, root action, model/network
  action or `scripts/verify --full` ran.

## Disposition

This checkpoint is non-admitting. v17 remains superseded-before-launch and
unconsumed. After independent review and push, one new explicit authorization
bound to the pushed P2 commit is still required for exactly one replacement
machine campaign. Task 40 and production Deep Dive remain blocked.
