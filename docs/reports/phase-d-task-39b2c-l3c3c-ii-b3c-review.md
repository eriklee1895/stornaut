# Phase D Task 39B2c-L3c3c-ii-b3c Concrete Leaf/Entry Review

> Status: Complete; direct-async process-local one-shot entry, package-closed
> concrete App operations, no-auth Lifecycle retirement, exact evidence joins,
> structural/mutation/final-Mach-O gates and independent post-fix review passed;
> non-admitting
>
> Date: 2026-08-20
>
> Implementation commit: `da36ae022eed2610278b7ed5f8fe2c2119b7f994`
>
> Parent: `18e01e7e7dd0f6d56d97ed05989cdab9697c5e99`
>
> Validated implementation tree: `e333e482ed9416756bdfb96aeb1406ea4c1eb233`
>
> Scope: eleven non-document source/test/script paths plus the approved
> preflight correction; no App/helper launch, real XPC, install, privilege,
> model/auth/network use, readiness claim or authoritative full verifier

## 1. Outcome

L3c3c-ii-b3c is complete. The inherited-handoff App entry is directly async,
no-argument and process-local one-shot. It internally joins ii-b3a's fixed FD 7
peer/bootstrap/identity-drop adapter, the completed pure leaf and ii-b3b's
package-closed `[start, retire]` Lifecycle seam. The public entry exposes no
descriptor, path, authorization, binding or business-I/O input.

The concrete operations actor owns a ticketed `idle -> operation/retiring ->
idle/terminal` state machine. Concurrent use, reentrancy after suspension,
cancellation and any failed operation make the epoch terminal. Configuration
bytes must be canonical, their SHA must equal `machineConfigurationSHA256()`,
the acknowledgement uses the existing `capabilityEvidenceBindingSHA256()`, and
all four machine-driver signing fields must match the same-epoch peer evidence.

The no-auth retirement path creates only the fixed Lifecycle XPC session and
`InvestigationLifecycleAppServerTransport`, emits exactly `start` and `retire`,
consumes one exact Store result, and accepts a handle only when its identity,
configuration digest and completion-relative deadline are exact. The helper
issues the handle at retirement completion plus 30 seconds; the final validator
therefore requires `completedAt < validBefore <= min(configuration.validBefore,
completedAt + 30 seconds)` and also rejects backwards time.

## 2. Scope, Cost and Artifact Identity

The implementation changed exactly the eleven frozen non-document paths and
2,502 added-or-deleted lines (2,475 additions, 27 deletions), below the 11-path /
2,800-line ceiling. Verifier/mutation growth remained below the separate
800-line re-audit threshold. The implementation commit is pushed to
`origin/main`.

Verifier identity at the validated tree is:

- `scripts/verify-investigation-boundaries`: `14a9e4017cd721246286d3cfb49670fe29642554544f69d7463c11a98169b998`;
- `scripts/verify-app-release-boundaries`: `e54f727b2d7fa174c71b4f7672f9b01880e56a46a069e3b171274347fd1cc9e2`; and
- normalized `scripts/verify-contract`: `c911d0c5caadfc628cda6c6fb780d831e7b819ef2a867cfcc45cf71edb9c4cfc`.

## 3. Prompt-to-Artifact Completion Checklist

| Requirement | Direct evidence | Result |
| --- | --- | --- |
| direct-async one-shot entry | sole public async entry, atomic admission and exact status mapping | satisfied |
| b3a peer/bootstrap/drop join | complete concrete fake transcript plus same-epoch identity/signing negatives | satisfied |
| strict configuration reuse | canonical bytes, strict decoder, digest and unknown/mismatch controls | satisfied |
| complete attempt commitments | twelve independent binding-field mutations change capability and configuration commitments | satisfied |
| no-auth/no-business retirement | exact `[start, retire]`, zero line bytes and source/API prohibitions | satisfied |
| exact handle/evidence join | Store one-shot, helper/owner/L1/operation/configuration and deadline checks | satisfied |
| concurrency/cancellation closure | ticketed actor, terminal failures, suspended retirement and 128-way admission pressure | satisfied |
| product/release closure | diagnostic Debug positive; ordinary Debug/Release, preview and release shell negative | satisfied |
| verifier anti-spoofing | comment/string/interpolation-aware Swift gate, exact Mach-O loop and executable mutations | satisfied |
| exact scope/cost | real staged index plus extra, budget, deletion and docs-deletion controls | satisfied |
| no premature admission | no launch/XPC/install/privilege/model/auth/report/readiness/full | satisfied |

## 4. Validation Evidence

| Gate | Result |
| --- | --- |
| focused concrete composition | 10/10 passed |
| focused pure leaf | 10/10 passed |
| affected Investigation regression | 361 tests in 27 suites passed |
| dedicated App diagnostic target | 15/15 passed |
| `scripts/verify-contract` | exit 0; real/synthetic scope, source, mutation and seal controls passed |
| `scripts/verify-investigation-boundaries` | exit 0; authority-closed Debug/Release driver and complete source boundaries passed |
| `scripts/verify-app-release-boundaries --investigation-handoff-only` | exit 0; final-Mach-O positive/negative matrix passed with only existing dependency-scan warnings |
| sole clean staged-only serial | 1,257 tests in 60 suites passed in 84.531 seconds; five maximum benchmarks skipped |
| staged identity | exact 11 non-document paths / 2,502 lines; implementation tree `e333e482...`; no post-serial drift |
| independent review | runtime, tests and verifier groups found and closed all P1/P2; final three groups report no unresolved P0-P2 |
| code guard | seven dimensions; final report contains no P0-P2 and is stored outside the repository |
| diff hygiene | staged and committed `git diff --check` passed |

The sole serial ran once after all focused, structural, artifact and review gates
were green. It was not restarted or retried. `scripts/verify --full` was not run.

## 5. Independent Review and Repairs

Review first found actor reentrancy after suspension, cancellation publication
and an unbound handle deadline. Ticketed phases, cancellation checks and the
completion-relative deadline closed those runtime P1s. A later review found the
old start-relative cap would reject every real helper-issued handle after a
nonzero XPC round trip; the advancing-clock regression now proves the exact
helper completion semantics.

Test review closed same-helper digest self-oracles, frozen completion time,
nondeterministic one-shot contention and incomplete peer-observation negatives.
Verifier review closed synthetic-only real-index checking, comment-preserved
trust guards, fixed-marker Mach-O loops, lock relocation, executable Swift
interpolation camouflage and documentation-deletion scope drift. All repairs
have executable mutation controls. Final independent reviews report no
unresolved P0-P2.

## 6. Non-Admission and Next Gate

ii-b3c is non-admitting. It did not launch the App/helper, invoke real XPC,
install fixed artifacts, execute as root, use the Codex subscription, call a
model, accept ADR 0018 or claim readiness. Production Deep Dive remains
`.implementationUnavailable`.

ADR 0018 remains Proposed and Task 39 remains incomplete. The strict next
checkpoint is ii-b4 fixed helper-claim client. ii-b5 then owns complete
single-epoch composition, ii-c0 owns its fresh privilege-preflight contract,
ii-c alone may accept ADR 0018, and L3c4 alone owns machine readiness and Task
39's remaining authoritative full verifier.
