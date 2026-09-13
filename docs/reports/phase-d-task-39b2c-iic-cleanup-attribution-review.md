# Phase D Task 39B2c ii-c Cleanup Attribution Repair

> Status: complete / non-privileged / non-admitting
>
> Date: 2026-09-14
>
> Baseline: `1ec24e4d6b35e43c8caa332cf6232cb7b026a0d6`

## Result

The secondary `cleanup-02` ambiguity exposed by the consumed v16 campaign is
closed without rerunning or modifying v16. Production termination now reports a
closed typed deadline or POSIX failure. A schema-v3 `spawnUncertain` event adds
that typed attribution while the existing six-segment schema-v2 grammar remains
byte-compatible for frozen historical evidence.

Only a canonical POSIX failure can be marked `termination-covered-*`, and only
after an exact exited/signaled wait, receipt EOF, terminal EOF, a complete empty
PGID/SID residue observation and no other cleanup issue. A shared-deadline
expiration is permanently unresolved because every subsequent production
cleanup operation uses that same expired deadline. Every unresolved typed
termination restores the `terminateFailed` cleanup bit. None of these outcomes
is admitting; the primary post-arm failure remains authoritative.

## Verifier closure

Swift and the independent Python parser enforce the same schema-v3 grammar,
canonical errno range, exact cleanup mask, EOF and terminal-shape rules. The
dedicated verifier contains fourteen semantic mutations plus the staged-scope
positive and nine scope negatives.

The wrapper and its self-sealed parent use one `O_NOFOLLOW | O_CLOEXEC` open,
validate regular-file owner/mode/link-count and exact bytes, then execute the
already verified in-memory bytes through `zsh -f -s`. Deterministic negatives
cover both pathname replacement and in-place truncate/write after the trusted
bytes have been read. The untracked-path negative uses a randomized `mktemp`
path and a scoped trap, so no pre-existing repository file can be overwritten or
deleted. Historical replay worktrees omit only `docs/assets`, which are visual
references and are not consumed by any replayed source, test or verifier gate.

## Scope

The checkpoint changes exactly ten non-document paths and 966 lines against the
baseline: 908 additions and 58 deletions. It stays below the 14-path / 4,000-line
preflight threshold.

## Validation and review

- cleanup-attribution source, staged-scope and dedicated aggregate: exit 0;
- historical/current ii-c aggregate, including frozen v16 compatibility: exit 0;
- final clean staged targeted regression: 192 tests / 3 suites / 0 failures;
- final staged-only SwiftPM serial: 1,987 tests / 100 suites, with 18 issues in
  two pre-existing environment-sensitive cases only: the SwiftPM validation
  sandbox lacks the app-scope bookmark entitlement and denies the two real
  suspended-sudo cases (`spawnStatus == EPERM`);
- exact ordinary-context reruns on the same staged tree: bookmark 1/1 passed and
  `InvestigationMachineGatePhysicalTests` 7/7 passed; an exact clean-snapshot
  rerun reproduced the same entitlement/sandbox failures;
- independent runtime and verifier post-fix reviews: no unresolved P0-P2 after
  closing covered-mask parity, schema-v3 terminal-shape, deadline coverage,
  untracked-probe safety and pathname/same-inode TOCTOU findings.

No privileged campaign, root action, model call, App launch or authoritative
`scripts/verify --full` ran in this checkpoint.

## Boundary and next action

v16 remains consumed, non-admitting and non-retryable. Its evidence and the
persistent Application Support Gate remain immutable. Production Deep Dive
remains unavailable, Task 40 remains blocked, and L3c3d/L3c4 remain unproven.
After this checkpoint is committed and pushed, exactly one fresh replacement
campaign requires a new user authorization bound to that pushed commit.
