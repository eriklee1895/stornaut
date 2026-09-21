# Phase D Task 39B2c ii-c v13 raw-evidence loss review

> Status: complete / non-admitting / replacement authorization required
>
> Date: 2026-09-14
>
> Baseline: `35524e5512b9e1f15b1979a22778ad1a75a0c942`

## Result

The v17 pre-launch aggregate detected that all nine v13 raw artifacts had
disappeared from phases 01 through 03 while the enclosing owner-private evidence
root and all six phase directories remained. The original schema-v8 disposition
remains byte-identical at SHA-256
`09c62579bf4a78ce00f491993ccfbeb5f4cd22ed11e0e8744f1e52922080bafd`;
it still proves only a consumed, rejected and non-retryable v13 attempt. It can
no longer be replayed against the missing raw bytes.

The phase directories changed between
`2026-09-13T19:35:36.423385Z` and
`2026-09-13T19:35:36.427750Z`. macOS unified logging records a
`com.apple.cache_delete` low-disk event at
`2026-09-13T19:35:18.065Z`, with 10,730,471,424 bytes free and a
4,087,165,747-byte purge goal. This is strong temporal correlation only: the
privacy-redacted log does not independently bind the exact deleting actor or
the v13 path.

The fixed runtime remained absent. The persistent Application Support Gate was
not modified and still contains exactly the owner lock plus the original v13
and v16 attempts/capsules. The complete v16 raw evidence remains independently
verifiable. No exact v13 raw-artifact copy was found, so no file was
reconstructed or replaced.

## Closure

The new trusted-parent/read-only verifier accepts only the checked loss receipt and
the exact surviving v13 root/phase identities with six empty phase inventories.
If that residual tree is later removed, verification fails closed and requires
a new disposition rather than accepting a pair of absence samples. It holds and
watches every evidence directory, verifies v16
through the existing self-sealed failure verifier, then revalidates all v13
descriptors and inventories before returning. Every accepted result remains
explicitly non-admitting and retry-forbidden.

The already-running boundary opens the parent once with `O_NOFOLLOW`, validates
its fixed raw hash and normalized self-seal, and executes only those verified
in-memory bytes; direct pathname execution of the parent is rejected. The parent
then opens the inner loss verifier and existing failure verifier once, applies
the same fixed-hash/self-seal rule and executes their verified bytes. Its matrix
rejects path replacement, same-inode overwrite, forged child output, four
receipt mutations and five live-tree mutations (including create-then-delete).
It also holds the exact v16 disposition FD and vnode watch across the verified
failure-verifier call, then rejects deterministic path-replacement and
same-inode-overwrite mutations before returning.
The staged-scope verifier has an independent nine-case negative matrix covering
extra/missing/binary/wrong-mode/over-budget/aggregate-budget/index divergence/
wrong-baseline/untracked inputs.

The aggregate verifier now consumes this loss proof plus the standalone v16
positive instead of claiming the deleted v13 raw bytes are still replayable.
The historical v13/v16 joint-verifier entry remains available and fail-closed;
it was not weakened to accept missing evidence. The immutable pushed v17 scope
is replayed from its own Git tree, so later prerequisite work cannot redefine
that checkpoint.

## Validation

- trusted parent plus live read-only loss verifier and 11 evidence/runtime
  mutations: exit 0;
- failure-disposition structural contract: exit 0;
- exact staged-scope gate plus 9 negative fixtures: exit 0;
- `InvestigationMachineTargetBoundaryTests`: 68 tests / 1 suite / 0 failures;
- `scripts/verify-contract --iic-c-contract-only`: exit 0;
- one clean staged-only `StornautInvestigationTests` serial run executed 1,075
  tests / 66 suites: 1,073 tests passed; the only two failing tests (17 issues)
  were the unchanged real suspended-`sudo` physical fixtures, where
  `posix_spawn` returned `EPERM` inside the temporary clean-worktree path. No
  matching child process remained. The focused boundary suite and all P1 gates
  were green, so this environmental result was not hidden or retried as a full
  serial run;
- two independent final post-fix reviews found no unresolved P0-P2; the exact
  non-document scope is 5 paths / 1,125 changed lines against the pushed
  baseline;
- no sudo, root action, campaign launch or authoritative full verifier ran.

This checkpoint is non-admitting. v17 remains superseded-before-launch and
unconsumed. The next prerequisite is to move future campaign raw evidence out
of purgeable TMPDIR and to preserve both retained v13 and v16 Gate capsules.
Only a later pushed repair and fresh explicit authorization can permit another
replacement campaign. Task 40 and production Deep Dive remain blocked.
