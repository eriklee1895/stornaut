# Phase D Task 39B2c ii-c preserved-capsule recovery review

> Status: complete / non-admitting / historical prerequisite for consumed v12
>
> Date: 2026-09-09
>
> Baseline: `4fd9c539dbc2a7d9c659147c041712b945fa3b00`

## Result

The replacement-campaign prerequisite now preserves the exact retained v11
Gate capsule while cleaning only other valid stale attempts and the fresh
campaign attempt. Preservation is bound to the v11 attempt UUID, whole-input
digest, canonical filename, exact byte count and raw SHA-256. Missing, duplicate,
malformed or byte-drifted preservation state fails before cleanup or fresh
publication.

Production teardown emits schema-v2 evidence with zero current-campaign Gate
residue and one exact historical v11 attempt/capsule. The independent verifier
checks that JSON and separately opens the real Gate base descriptor-relatively
with no-follow flags, validates owner/mode/ACL/xattr/link/identity, decodes the
entire projected cohort and revalidates held descriptors before admission.

The repair adds no model, network, cleanup, Executor, Trash, Policy or Registered
Action authority. Production Deep Dive remains unavailable and Task 40 remains
blocked. No privileged campaign or authoritative full verifier ran in this
checkpoint.

## Review closure

Independent runtime review found one P1: a complete eight-epoch corpus could
still use legacy schema-v1 teardown and bypass the live preservation proof. The
final verifier now requires schema v2 for every admitting cohort, while schema
v1 remains readable only for historical/non-admitting evidence. A dedicated
negative regression proves schema-v1 admission is rejected. Post-fix runtime
and verifier reviews found no remaining P0-P2.

## Validation

- focused preservation/schema/real-Gate tests: passed;
- directly affected Investigation selection: 209 tests in 4 suites passed;
- exact preservation source gate and seven mutation controls: passed;
- aggregate ii-c contract: passed;
- targeted Debug/Release campaign component boundary: passed;
- v9/v10/v11 external failure evidence: passed read-only;
- sole serialized SwiftPM run: 1,946 tests in 99 suites, four unrelated
  load-sensitive process timing failures; all four exact failed cases passed on
  the required isolated rerun. The original serial run is not represented as
  green and was not repeated.

## Remaining gate

The user explicitly rebound the one-shot v12 authorization to pushed repair
commit `0a17726176b0cae0839f398da5fae2f09e6ccef5`. This was the state at this
checkpoint. v12 later ran once from descendant `212320f` and is now consumed,
non-admitting and non-retryable; see the v12 failure disposition.
