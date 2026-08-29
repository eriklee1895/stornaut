# Phase D Task 39B2c L3c3c-ii-c0b-iv-a-r Completion Audit

> Status: complete / non-admitting
>
> Date: 2026-08-29
>
> Parent: `6c52836`
>
> Next frontier: ii-c0b-iv-b1 contained handoff and settlement

## 1. Result

ii-c0b-iv-a-r is complete and remains non-admitting. It closes the two
acceptance surfaces deliberately left outside iv-a0's review budget: the
validation-snapshot provenance negative matrix and the actual inherited-handoff
App path's canonical Task 38 receipt join.

The checkpoint dynamically expanded from three to four non-document paths only
after a RED unsupported-tree test exposed an early-failure cleanup defect in
the snapshot helper. Its final scope is 456 changed lines, below the frozen
900-line ceiling. No process-launch, root, model, network, readiness, Cleanup,
Trash or Executor authority was added.

## 2. Closed Behavior

- The concrete App leaf reconstructs the canonical Task 38 receipt from the
  decoded binding before it acknowledges the configuration. Repository commit,
  source fingerprint or shape-valid receipt-digest drift fails closed.
- An immutable package-only accepted projection atomically retains the exact
  configuration, configuration SHA-256 and typed runtime receipt. Retirement
  receives that projection rather than independently supplied values.
- The no-auth retirement path revalidates the typed receipt against the binding
  before creating the lifecycle transport or sending any request.
- Any receipt join failure terminalizes the concrete App actor before
  acknowledgement or retirement. Cancellation and one-shot retirement semantics
  remain unchanged.
- The snapshot contract now proves caller Git/Stornaut poison is scrubbed;
  snapshot/source/Git/other-worktree writes are denied; only `.build` and
  `.derivedData` remain writable; exact `0644`/`0755` modes survive restrictive
  umask; and symlink/gitlink trees are rejected before command execution.
- The snapshot helper now removes its private manifest before removing the
  container on early materialization failure, closing the residue found by the
  new unsupported-tree tests.

## 3. Scope and Validation

The four non-document paths are:

1. `Sources/StornautInvestigationDiagnostic/InvestigationRuntimeDiagnosticComposition.swift`;
2. `Tests/StornautInvestigationTests/InvestigationHandoffConcreteCompositionTests.swift`;
3. `scripts/verify-clean-validation-snapshot-contract`; and
4. `scripts/with-clean-validation-snapshot`.

| Evidence | Result |
| --- | --- |
| pre-fix App receipt drift matrix | 3/3 cases failed as expected; acknowledgement incorrectly succeeded and retirement closure was invoked |
| pre-fix unsupported-tree cleanup | failed reproducibly; exact private manifest residue identified |
| post-fix concrete handoff suite | 11/11 passed |
| post-fix restrictive-umask snapshot contract | exit 0 |
| complete `StornautInvestigationTests` affected suite | 771/771 passed; 54 suites |
| Debug `StornautInvestigationDiagnostic` build | exit 0 |
| Release `StornautInvestigationDiagnostic` build | exit 0 |
| structural no-Executor gate | exit 0 |
| syntax and whitespace | Swift parse, zsh parse and `git diff --check` passed |
| independent Swift review | no unresolved P0-P2 |
| independent snapshot review | no unresolved P0-P2 |

The checkpoint intentionally ran no global staged serial, root/sudo, real App/
XPC, authenticated Codex, network/model attempt or `scripts/verify --full`.
iv-b2 owns the sole c0b aggregate staged serial; ii-c/L3c3d own the two real
machine attempts; L3c4 owns the remaining full verifier.

## 4. Non-Claims and Next Step

This checkpoint does not publish a capsule, spawn the fixed gate, prove root or
TTY topology, observe a real Codex turn, accept ADR 0018 or enable production
Deep Dive. Task 39 remains incomplete.

The next frontier is ii-c0b-iv-b1. It owns one package-closed high-level fixed
gate handoff, exact wait/reap and post-reap capsule settlement without exposing
raw descriptors, paths, settlement tokens, generic callbacks or forgeable
proofs.
