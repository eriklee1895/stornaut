# Phase D Task 39B2c Fixed-Gate Cleanup Historical Replay Preflight

> Status: frozen / implementation pending / non-admitting
>
> Date: 2026-08-30
>
> Baseline: `26e785ac2146ca96553ce1d4de870fcd4437fa22`

## 1. Defect

The completed fixed-gate deadline cleanup checkpoint is accepted at commit
`bc42fbc58ea1c6eed52ff646fa2f6043e2af4316`, tree
`29eb2d048142fb873f0306acc4bfebbbb250b03d`. Its bare contract still runs the
original five-path staged-scope gate against the caller's live index. Every
legitimate successor checkpoint therefore fails with `fixed-gate cleanup
checkpoint paths drifted`, even though the completion audit promises immutable
historical verification for successor work.

## 2. Frozen Scope and Budget

This checkpoint may change exactly one non-document path:
`scripts/verify-contract`. The maximum budget is 28 changed lines. It may only:

- branch successor HEADs through the existing `replay_historical_contract`;
- pin the exact accepted commit and tree above;
- invoke the existing fixed-gate contract and staged-scope modes inside the
  detached historical worktree; and
- make the two remaining historical-index deletion fixtures use `git rm -f`
  so Git mutates only their explicitly selected temporary index even when the
  successor worktree contains newer bytes; and
- recompute the normalized `ib2_self_sha`.

It must not change product source, tests, the Investigation/App boundary
verifiers, package graph, schemas, protocols, authority or runtime behavior.

## 3. Validation

First run syntax and normalized self-seal checks. Then require the dedicated
fixed-gate cleanup contract to pass from this successor HEAD, proving that it
replays the accepted tree rather than consuming the live index. Run the current
ii-c0b-iv composition/self-seal contract, bare Investigation boundary, and one
bare App Release boundary (which invokes the bare aggregate contract). Finish
with independent read-only review.

The App Release run may not be waived after the replay passes: it is also the
regression for the ii-b3b and ii-b3c temporary-index deletion fixtures. The
repair must not use the real index, delete a worktree file, or relax the
expected missing-path diagnostics.

No focused/serial product suite, root or sudo command, installed topology,
Codex auth/model/network operation, or `scripts/verify --full` is authorized.
This repair remains non-admitting and does not complete Task 39.
