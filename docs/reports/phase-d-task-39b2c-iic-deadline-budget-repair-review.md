# Phase D Task 39B2c ii-c-c Deadline-Budget Repair Completion Audit

> Status: complete / non-admitting
>
> Date: 2026-09-07
>
> Baseline: the commit containing this audit
>
> Next frontier: fresh explicit authorization -> replacement machine campaign
> -> L3c3d -> L3c4

## 1. Result

The v10 failure disposition and its bounded deadline repair are complete. The
repair does not admit Task 39 and does not authorize another privileged run.

The v10 campaign durably reached 'armedConsumed' and then recorded
'spawnUncertain -> terminal' after 1,195.056190 seconds. Its enclosing deadline
was 1,200 seconds, while eight legal 140-second epochs alone may use 1,120
seconds. The old contract therefore reserved at most 80 seconds for credential
relay, startup, inter-epoch orchestration, evidence publication, retirement,
uninstall and verification. No epoch artifact was emitted, so the evidence does
not claim which epoch was active when the outer deadline expired.

The accepted source derives a finite machine-only 1,400-second horizon from:

'8 epochs * 140 seconds + 280 seconds orchestration/cleanup reserve'.

The generic configuration ceiling remains 900 seconds and each epoch remains
bounded by 140 seconds. The campaign executable, fixed Gate, raw Gate receipt
validator and independent verifier now consume the same campaign horizon. No
Codex write authority, private/localhost/Unix transport, Executor, Trash,
Policy, Registered Action, release/notarization or product Deep Dive boundary
was widened.

## 2. Failure Evidence Closure

- v8, v9 and v10 remain consumed, non-admitting and non-retryable.
- The v10 schema-v4 disposition binds its nine durable artifacts, exact event
  timeline, source identity and preserved Gate capsule.
- The v9 schema-v3 pre-v10 disposition remains byte-identical in a separate
  checked file. The current schema-v5 v9 disposition records that the prior
  attempt is absent and the later v10 attempt is present; later residue is not
  interpreted as v9 cleanup or success.
- Independent read-only verification of all three external evidence roots
  returned success and the focused tests proved that their trees were unchanged.
- The fixed App, plist and service are absent and no matching fixed runtime
  process remains.

## 3. Exact Non-Document Scope

The repair changes fourteen non-document paths: five production sources, five
Investigation test files and four verifier scripts. Their Git numstat is 536
changed lines: 452 insertions and 84 deletions. No package dependency, target,
schema field, entitlement or authority surface was added.

## 4. Review Closure

The tests-first RED showed that the machine cohort and Gate still exposed the
old 1,200-second ceiling. The implementation made the 1,400-second relationship
green without widening the generic or per-epoch limits.

Independent review found one P2 verifier regression: the live-claim gate still
pinned the pre-repair SHA-256 of
'InvestigationCohortCapsuleContract.swift'. The frozen binding was updated to
the current authority-free contract, and the real
'--live-claim-server-contract-only' entry then passed. Final local serial review
found no unresolved P0-P2. The generic review artifacts are:

- '/tmp/stornaut_task39_review.MYbfaO/final_comments.json';
- '/tmp/stornaut_task39_review.MYbfaO/report.md'; and
- '/tmp/stornaut_task39_review.MYbfaO/report.html'.

The custom review workflow was unavailable because its TLS chain could not be
verified; the required generic review completed locally without subagents.

## 5. Validation Evidence

| Evidence | Result |
| --- | --- |
| Focused affected selection with v8/v9/v10 evidence roots | 246 tests in 6 suites passed in 50.377 seconds |
| Earlier full Investigation target | 1,022 tests in 65 suites passed before the final evidence-only adjustments |
| Later full Investigation target | one unrelated cleanup-fixture failure; exact failed case passed on rerun; not represented as a green full run |
| Source/contract gates | ii-c source, deadline budget, failure disposition, suspended sudo and shared-deadline gates passed |
| Binary/component gates | ii-c-a, ii-c-b2b2 and suspended-sudo component gates passed |
| Historical live-claim gate | passed after the review finding was fixed |
| External failure evidence | v8, v9 and v10 independent read-only verifiers passed |
| Self-seals and formatting | verifier self-seals and 'git diff --check' passed |

The aggregate 'scripts/verify-contract --iic-c-contract-only' path was not
claimed as green: after its non-privileged sub-gates passed it reached an
installation authorization prompt and was immediately interrupted. No
credential was entered, and the fixed App/plist/service remained absent. The
authoritative 'scripts/verify --full' remains reserved for L3c4 and was not run.

## 6. Non-Claims and Remaining Order

This checkpoint ran no new privileged campaign and makes no machine-readiness,
L3c3d, L3c4, Task 39 completion or product Deep Dive claim. A replacement
campaign requires a new explicit authorization, fresh campaign UUID, fresh
attempt UUID and fresh evidence root. Only a green independently verified
replacement cohort may advance to L3c3d; only L3c4 may produce final admission
and run the reserved authoritative full verifier. Task 40 remains blocked.
