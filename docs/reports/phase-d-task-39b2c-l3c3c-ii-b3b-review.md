# Phase D Task 39B2c-L3c3c-ii-b3b Start-to-Retire Seam Review

> Status: Complete; package-closed start-to-retire-only Lifecycle seam, exact
> request/evidence contract, structural/mutation/artifact gates, independent
> post-fix review and test-infrastructure prerequisite closure; non-admitting
>
> Date: 2026-08-20
>
> Implementation commit: `e60d4e05724314a10792066ad3df8300ff279303`
>
> Validated implementation tree: `069c53c74c5c5149aecfed3b08845020086a76b4`
>
> Implementation validation commit: `e8d093d0a165f43b0cc33794a1ccfbe7a3edabad`
>
> Fixture prerequisite: `18e75f4256ef0dbc890f9a9acd70db3236e77fe4`;
> validated tree `bc0749fbd470a00d27eade336d30796ddf73a7d4`;
> validation `09925067febe476a0dfb753bf18a226667a58b2e`
>
> Scope: package-only Lifecycle transport seam and its tests/verifiers plus one
> independently split test-only fixture prerequisite; no native entry,
> App/helper/XPC launch, privilege, model/auth, readiness or authoritative full
> verifier

## 1. Outcome

L3c3c-ii-b3b is complete.
`InvestigationLifecycleAppServerTransport.startAndRetireWithEvidence()` is one
package-scoped, one-shot operation whose only successful request transcript is
exactly `[start, retire]`. It accepts no business line, invokes neither
`writeLine` nor `readLine`, and returns only validated
`InvestigationLifecycleRetirementEvidence` after owned-resource, L1, helper,
handle and Store joins. The seam remains unreachable from the native App entry
until ii-b3c.

The actor reserves the operation once. Cancellation before start dispatch makes
the epoch terminal without sending a request. Once start dispatch may have
crossed the external boundary, an independent cancellation-insensitive task must
complete retirement and evidence collection. If retirement is unproved, that
failure replaces any underlying start failure. If retirement is proved, the
original start failure or cancellation is returned without publishing false
success. Concurrent or repeated calls have exactly one possible winner.

## 2. Scope, Cost and Artifact Identity

The ii-b3b implementation changed exactly the six frozen non-document paths and
912 added-or-deleted lines (892 additions, 20 deletions), below the 1,500-line
ceiling. Its implementation and validation commits share parent
`a7f827403ee532a5eab335b5f18d6b8103730b1b` and exact tree
`069c53c74c5c5149aecfed3b08845020086a76b4`.

Verifier identity at that tree is sealed as follows:

- `scripts/verify-investigation-boundaries`: `d714fe3f43fbb94b40ef4154dfcd8f5e2afab8fac23853dc25698b93bce1bde5`;
- `scripts/verify-app-release-boundaries`: `585aa61bda997e0cadd6ba9be41d1f2fb8a435a820449d4f1dab227715cbbb0c`; and
- normalized `scripts/verify-contract`: `d371ba2cd9a65c62f7f4c97596b14e6106d86a1d1dd06a375270aeaea30f6d0a`.

The independently split fixture prerequisite changed one test-only path and 41
lines, below its revised 45-line ceiling. Both implementation commits are pushed
to `origin/main`.

## 3. Prompt-to-Artifact Completion Checklist

| Requirement | Direct evidence | Result |
| --- | --- | --- |
| exact successful sequence | behavior tests observe only `[start, retire]` | satisfied |
| exact started/active join | start response identity/state validation precedes retirement | satisfied |
| no business I/O | zero line bytes; source/token gates forbid `writeLine`, `readLine` and aliases/backticks | satisfied |
| exact retirement evidence | owned resource, L1 zero, fresh helper, handle and Store negatives plus success join | satisfied |
| cancellation before dispatch | no request, terminal epoch | satisfied |
| cancellation/uncertainty after dispatch | independent retirement task completes before cancellation/start failure is returned | satisfied |
| cleanup uncertainty priority | unproved retirement replaces dispatched start failure | satisfied |
| one-shot concurrency | concurrent and repeated calls have one winner and cannot resurrect state | satisfied |
| package/source closure | single package declaration; no public/internal forwarding API or broad Codex/auth/model surface | satisfied |
| parser and mutation closure | comment/string-aware parser plus public, forwarding, alias, backtick, brace, write, cleanup and scope mutations | satisfied |
| artifact closure | Debug diagnostic compiles/links while seam remains absent from closed final images until ii-b3c | satisfied |
| exact scope/cost | current real-index b3b gate and historical b3a-tree gate with extra/over/deletion mutations | satisfied |
| honest clean-serial closure | original 1,244/1,245 retained; independent fixture prerequisite passes 1,245/1,245 | satisfied |
| no premature admission | no launch/XPC/install/privilege/model/auth/report/readiness/full; ADR 0018 Proposed | satisfied |

## 4. Validation Evidence

| Gate | Result |
| --- | --- |
| final focused transport suite | 27/27 passed |
| final affected regression | 532 tests in 43 suites passed in 6.486 seconds |
| `scripts/verify-contract` | exit 0; source/self seals and exact seam/scope mutation controls passed |
| `scripts/verify-investigation-boundaries` | exit 0; parser-backed package/source/API/body/scope contracts passed |
| `scripts/verify-app-release-boundaries --investigation-handoff-only` | exit 0; targeted build and closed-image matrix passed with only existing dependency-scan warnings |
| sole ii-b3b staged-only serial | 1,244 of 1,245 tests passed in 59 suites; one setup-side `.missingPID` issue after SwiftPM started |
| ii-b3b serial identity | validation `e8d093d...`, implementation `e60d4e0...`, identical tree `069c53c...` |
| exact failure attribution | unchanged exact case passes on pre-b3b baseline and ii-b3b tree; failure precedes retirement and ii-b3b changed no Codex fixture/runtime path |
| fixture prerequisite | deterministic RED, 1/1 GREEN, 15/15 suite, 259-test Codex target and independent reviews |
| sole prerequisite staged-only serial | 1,245 tests in 59 suites passed in 84.541 seconds |
| prerequisite identity | validation `0992506...`, implementation `18e75f4...`, identical tree `bc0749f...` |
| independent ii-b3b review | final runtime/verifier reviews found no unresolved P0-P2 |
| diff hygiene | exact trees and scopes, no post-validation source drift, `git diff --check` passed |

The ii-b3b serial is deliberately not described as clean and was never rerun.
The exact-case controls prove only that no ii-b3b regression was observed; the
separate prerequisite repaired the historical test-infrastructure race and
supplied its own clean serial. This preserves both evidence records rather than
using the second run to manufacture a green ii-b3b headline.

## 5. Independent Review and Repairs

Review first found that the seam-body parser counted braces in comments and
strings, checked only the declaration and matched only call syntax. It now uses a
comment/string-aware projection, requires exactly one declaration/reference and
scans Swift identifier tokens, including aliases and backtick-escaped names. The
contract exercises public/forwarding, comment-brace, alias, backtick, business
write, caller cleanup, extra-path, over-budget and deleted-path mutations.

The historical b3a scope gate originally inspected the current index and would
have rejected every legal later checkpoint. It now reconstructs the exact b3a
implementation tree relative to its parent, while b3b independently checks the
current real staged index. Final independent runtime and verifier reviews found
no unresolved P0-P2.

The serial then exposed the unrelated PID-file fixture race. The independently
reviewed prerequisite closed publication, observation and cleanup causality; its
completion evidence is recorded in the
[fixture review](phase-d-task-39b2c-l3c3c-ii-b3b-fixture-prerequisite-review.md).

## 6. Non-Admission and Next Gate

ii-b3b is non-admitting. It does not make the package seam reachable from the
native entry, construct the concrete App leaf, launch an App/helper, invoke real
XPC, install or execute a privileged artifact, call a model, consume auth or make
a machine-readiness claim.

ADR 0018 remains Proposed. Task 39 remains incomplete. Production Deep Dive
remains `.implementationUnavailable`; only ii-c may accept ADR 0018, only L3c4
owns machine readiness and Task 39's remaining authoritative full verifier, and
only Task 44 may admit normal-product Deep Dive.

The strict next checkpoint is L3c3c-ii-b3c concrete leaf/native entry.
