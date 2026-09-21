# Phase D Task 40 Review

> Status: Complete for closed-fixture/non-production product development
>
> Date: 2026-09-20
>
> Baseline: `e0e21bbbb32b4ff566f02284ae0492e50f9baa39`
>
> Scope: persisted Investigation report projection, current-Store reconciliation,
> conservative Review projection and Store-owned continuation; no production
> Deep Dive admission, privileged campaign or cleanup execution

## 1. Decision

Task 40 is complete in its approved closed-fixture scope. Persisted Task 38
reports can be rejoined to current Store v4 truth and projected as bounded,
source-labelled evidence. A second rejoin transaction binds the exact
Investigation/run/report immediately before atomically persisting a
deterministically built Cleanup Plan.

The public Review result exposes only an opaque `CleanupPlanID`, sanitized
report data and path-free rows. It never returns raw `CleanupPlan` or
`ReviewProjection` values. Agent-only proposals remain unselected and
non-executable; current Protected and current-evidence blocks take precedence
over historical unresolved state.

Continuation requests accept only typed parent IDs, a caller-created fresh run
ID, a closed budget preset and planning time, then delegate to the existing
Store-owned continuation transaction. They do not resume an old runtime thread
or accept a caller-created target set or Plan.

Production Deep Dive remains unavailable. Task 39 machine admission and Task 44
final product admission are unchanged and unproven.

## 2. Implementation

- Added a bounded public report model with strict source labels, whole-string
  redaction for paths, URIs, markup, shell syntax and unsafe Unicode, plus
  per-row isolation for malformed retained evidence.
- Added exact report reconciliation through Store v4 source rejoin, preserving
  stale historical truth while disabling current Review and distinguishing
  expired, corrupt and missing states.
- Added conservative Review rows that reuse `CleanupPlanBuilder`; model output
  cannot supply an action, path, disposition, Policy result or default
  selection.
- Added a dry-run builder path and one bounded Store transaction that performs
  source rejoin, exact run/report ownership checks and Cleanup Plan persistence
  atomically. The Investigation builder filters the complete Scan to exact
  retained target bindings, and the Store independently rejects any foreign
  Plan item. Cancellation after insert rolls back the Plan.
- Added a thin continuation façade over the existing Store-owned typed
  continuation command.
- Wired a Task 40 structural/mutation gate into the unified source-boundaries
  stage. The gate pins the Investigation source inventory and critical source
  blocks, rejects public authority/path/raw-Plan surfaces, and requires active
  safety tests.
- Repaired four pre-existing aggregate-verifier false failures caused by later
  accepted Task 39 source evolution. Each repair narrows or updates the current
  projection without altering frozen evidence or historical commits.

## 3. Tests First

The generated and extended tests cover:

- all approved evidence source labels and aggressive display-text redaction;
- malformed/duplicate/conflicting report rows and complete target partition;
- stale, expired, corrupt and missing source outcomes;
- Agent-only, deterministic, Protected, Unknown and unresolved Review rows;
- duplicate/mismatched builder output and exact Plan/projection equality;
- dry-run builder non-persistence;
- exact investigation/run/report/source binding at the atomic join;
- post-insert cancellation rollback and the report-read deadline;
- typed continuation delegation and same-run rejection; and
- App-target compilation and consumption of only the public Core façade.

No pre-existing product defect was entered in the test-generation defect map;
the tests specify new Task 40 behavior. Coverage collection was skipped because
the repository and request define no CI incremental-coverage threshold and the
available coverage parser does not support Swift. The mandatory unit-test
report flush completed.

## 4. Validation

| Gate | Result |
| --- | --- |
| Task 40 focused Core selection | 48 tests / 4 suites passed |
| Task 40 Review + builder/Store defense-in-depth rerun | 11 tests passed |
| App public-facade consumption | 1 test passed |
| Task 40 structural and mutation gate | passed |
| final unified `source-boundaries` step | passed in 66.613 seconds |
| stable-tree serialized SwiftPM regression | 2,033 tests / 104 suites passed in 230.873 seconds |
| Markdown links and diff hygiene | passed |

The second implementation slice spans 15 non-document source/test/script paths
and remains below the 4,000-line checkpoint ceiling. The 14-path preflight
ceiling was reached before adding the required App-model test; this one-file
scope adjustment is explicit here rather than hidden. Across both Task 40
commits, 16 unique non-document paths are affected. No privileged/live
opt-in test, machine campaign, real model invocation, Trash operation or full
verifier was run. The final integrated full remains owned by Task 44.

## 5. Independent Review

Independent runtime review found no unresolved P0-P2. Verifier review found
and closed gate/API weaknesses including raw internal Plan exposure,
non-local/string-based join and bounded-operation checks, incomplete recursive
source inventory coverage, implicit public raw types and disabled or vacuous
tests being counted as active.
The implementation removed raw Plan/projection storage from the public outcome
and the verifier now pins critical function bodies, scans the complete
Investigation source inventory, validates public declarations and rejects
disabled required tests. A final post-fix verifier review found no unresolved
P0-P2.

The first attempted final serial ran 2,033 tests but reported seven issues from
one Task 39 boundary test whose active-status hash expectations still named the
pre-Task-40 documents. That failed run remains failed. After updating only those
expected hashes and their owning seal, the exact test passed 1/1, source
boundaries returned green, and the final serial was restarted from the
beginning and passed as recorded above.

## 6. Safety and Next Gate

Task 40 adds no filesystem mutation, process execution, Trash, Registered
Action, Policy, authorization, runtime-thread continuation or production
availability. It does not consume or supersede any Task 39 campaign
authorization.

Task 41 may now consume these public report/status types for first-use
disclosure and typed availability. Tasks 42–43 may continue against closed
fixtures, but Task 44 cannot enable production Deep Dive until a fresh Task 39
machine cohort, L3c3d and L3c4 are independently admitted.
