# Active Plans

The approved executable plan is
[Phase D — Conditional Deep Dive](phase-d-conditional-deep-dive.md).
Tasks 36–38 are complete. Task 38's closed fake-runtime coordinator,
independent review, 811-test serialized regression and 23/23-stage
authoritative full verifier passed. Task 39 is in progress: checkpoints 39A
and 39B1a plus 39B1b-i are complete and independently verified. 39B1a closed
the exact Evidence Store v4 path and directly async lifecycle prerequisites;
39B1b-i closed the package-scoped transport/non-product composition seam.
39B1b-ii strict DEBUG App leaf is next, followed by 39B2 signed-App machine
admission. Tasks 40–44 remain blocked on the pushed completion commit of their
immediate predecessor.

The normative low-level contract is
[Investigation Canonical v1](../../specs/investigation-canonical-v1.md).
Task 36 is deterministic and non-executing: it added the canonical codec,
source projection, v2 Investigation domain, Candidate Planner, budget ledger
and stop evaluator. It did not launch Codex, call a model, migrate the Store,
change App availability or create cleanup authority.

Production Deep Dive remains `.implementationUnavailable` until Task 44 is
the sole normal-product admission gate.

| Task | Scope | Status |
| --- | --- | --- |
| [36](task-36-implementation-brief.md) | Domain, canonical projection, planner, budget and stop contracts | complete; [review](../../reports/phase-d-task-36-review.md) |
| [37](task-37-implementation-brief.md) | Store v4, retention and source rejoin | complete; [review](../../reports/phase-d-task-37-review.md) |
| [38](task-38-implementation-brief.md) | Closed coordinator with fake runtime | complete; [review](../../reports/phase-d-task-38-review.md) |
| [39](task-39-implementation-brief.md) | Signed-App production-runtime admission | in progress; 39A [complete](../../reports/phase-d-task-39a-review.md), 39B1a [complete](../../reports/phase-d-task-39b1a-review.md), 39B1b-i [complete](../../reports/phase-d-task-39b1b-i-review.md), 39B1b-ii next |
| [40](task-40-implementation-brief.md) | Evidence report and conservative Review projection | blocked on Task 39 |
| [41](task-41-implementation-brief.md) | First-use disclosure and typed availability | blocked on Task 40 |
| [42](task-42-implementation-brief.md) | App workflow and recovery state | blocked on Task 41 |
| [43](task-43-implementation-brief.md) | Investigations UI and navigation | blocked on Task 42 |
| [44](task-44-implementation-brief.md) | Production vertical slice and final gate | blocked on Task 43 |
