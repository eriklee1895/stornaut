# Phase D Task 39B2c Fixed-Gate Cleanup Historical Replay Completion Audit

> Status: complete / non-admitting
>
> Date: 2026-08-30
>
> Implementation: `aa8a7f14a60bdfe9cf682d7a1987b0f2e956597a`
>
> Implementation tree: `8176e92a43ae1c91c16de2aec150abbd6c362ca9`
>
> Baseline: `24dba50ed800324e67b58a5e60e679870d303fa9`
>
> Historical checkpoint: `bc42fbc58ea1c6eed52ff646fa2f6043e2af4316`
> / tree `29eb2d048142fb873f0306acc4bfebbbb250b03d`
>
> Next frontier: ii-c -> L3c3d -> L3c4

## 1. Result

The fixed-gate cleanup historical replay repair is complete and remains
non-admitting. Successor work now verifies the completed fixed-gate checkpoint
inside the existing temporary detached-worktree replay, pinned to its exact
accepted commit and tree, instead of applying the old five-path staged-scope
contract to the caller's live index.

The same aggregate audit exposed two historical negative-control fixtures whose
alternate indexes contained older blobs than both current HEAD and the current
worktree. Their `git rm --cached` setup now uses `-f`, still under command-local
`GIT_INDEX_FILE` values pointing below `contract_root`. This mutates only each
copied synthetic index; no worktree path or real Git index is removed. The
existing exact missing-path diagnostics remain required.

## 2. Exact Scope and Diff

The implementation changed exactly one non-document path,
`scripts/verify-contract`, with 13 insertions and 3 deletions (16 changed lines,
within the frozen 28-line ceiling). It adds the ten-line accepted-tree replay
branch, two one-token temporary-index fixes and the normalized self-seal update.
No product, test, boundary-verifier, package, schema, protocol or authority path
changed.

## 3. Validation and Review Evidence

| Evidence | Result |
| --- | --- |
| Shell syntax and normalized self-seal | passed; self-seal `03cdf657dbc124cd12349336f436f45d1ad1f097481eb5e567e3693135d20d9e` |
| Dedicated fixed-gate cleanup contract from successor HEAD | exit 0 through immutable historical replay |
| ii-b3b alternate-index deletion fixture | rejected with exact required-path diagnostic |
| ii-b3c alternate-index deletion fixture | rejected with exact required-path diagnostic |
| Bare Investigation boundary | exit 0 |
| ii-c0b-iv composition/self-seal contract | exit 0 |
| Bare App Release aggregate | exit 0; passed fixed-gate, ii-b3a, ii-b3b, ii-b3c and all later historical/build/binary stages |
| Independent replay and temporary-index reviews | no unresolved P0-P2 |

The aggregate's final line was `Release App fixture boundary verification
passed.` The existing dependency-scan and deprecated-API warnings remained
non-failing and were not introduced by this verifier-only change. No temporary
historical worktree remained registered after validation.

## 4. Non-Claims

This repair changes verifier infrastructure only. It ran no root or sudo
command, installed lifecycle, product XPC, model/auth/network operation,
serialized product regression or `scripts/verify --full`. It does not accept
ADR 0018, establish machine readiness, enable production Deep Dive or complete
Task 39.
