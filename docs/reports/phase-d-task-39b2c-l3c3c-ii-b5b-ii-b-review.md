# Phase D Task 39B2c L3c3c-ii-b5b-ii-b Review

> Status: complete / non-admitting
> Date: 2026-08-22
> Implementation commit: `c6905e2173b858550078ccc07ac915b67912c3d6`
> Parent: `b7ade4476fc18c3f38683168f8a1488eabd9824d`
> Tree: `83c5880d21e8e5b5a6e4a6c03ae2c6d2700e8ecd`
> Next frontier: ii-b5b-ii-c fixed FD-7 spawn and bounded duplex session

## 1. Result

ii-b5b-ii-b completes the independent Darwin App identity observation needed
by the fixed single-epoch runtime. A root Machine Driver can now validate the
pre-drop App claim and independently re-observe the post-drop UID-501 App
across BSD `proc_pidinfo`, kernel `sysctl` and audit-token sources. The observer
binds one fixed executable path, descriptor identity, SHA-256, static signing,
live signing, UID/GID/groups and complete process identity without exposing a
public, serializable or cleanup-capable surface.

The implementation changes exactly nine non-document paths and 2,790 changed
non-document lines against its frozen parent, within the reviewed nine-path /
2,800-line ceiling. The ninth path is the existing Xcode final-Mach-O verifier,
which is an atomic dependency because the new Security/process imports change
both SwiftPM and Xcode binary projections.

## 2. Implemented Contract

- The pre-drop observation requires root, the exact driver-parent PID, process
  group equal to the App PID, effective UID 0, complete audit-token agreement,
  fixed executable identity and static/live signing agreement.
- The post-drop observation independently samples a narrow audit identity both
  before and after the full observation sandwich. Both samples must exactly
  match PID, PID version, audit session, effective UID and all eight audit-token
  words from the process claim and drop evidence.
- The complete C snapshot cross-checks BSD, kernel and audit sources, then
  rereads BSD identity before returning. Parent/process-group IDs, start time at
  second and microsecond precision, real/effective/saved UID/GID, audit user/
  session and bounded supplementary groups must remain coherent.
- Cross-source contradictions or initial/final identity drift return the
  dedicated `STORNAUT_INVESTIGATION_IDENTITY_MISMATCH` status. Swift maps it to
  phase-exact invalid pre-drop or post-drop identity; ordinary errno failures
  remain unavailable rather than being promoted into identity evidence.
- The executable path, descriptor node, SHA-256, static signature, live
  signature and process identity are observed in a fail-closed sandwich. No
  process launch, signal, write, network, XPC, cleanup or readiness authority is
  added.
- The C ABI is package-internal through DriverSupport. Exact exports/imports,
  complete C/header source bytes, Swift source/test bytes and Debug/Release
  SwiftPM/Xcode final-artifact projections are sealed.

Accepted canonical source SHA-256 values include:

- C implementation: `ee50e6c3c79e19dacdb3c45e39eca68b24b739970b930b8e1110a78d6e6ddb4c`;
- C header: `f58e2ae64440b8061c86b579bdaa207bd27e2a88b3e70350a889ec19687f625e`;
- Swift observer: `2102c17f2f656b6cee197fb66ff0b2b019fb1c49477123d0123c4fddaeeb754a`;
- focused test: `5b2957448d187cdfd3f4b3b628015e2b529758158d0e2e8520120b92f84cb12e`.

## 3. Tests-First and Validation

- The final exact focused selection passed 42 tests in two suites. It covers
  every complete post-drop and pre-drop identity axis, initial/final narrow
  PID-version drift, path/artifact/signing races, exact error classification,
  directory/kernel/reported groups and the target boundary.
- `scripts/verify-contract` passed. It reconstructs the staged tree, verifies
  the fixed parent/path/budget contract and normalized verifier seals, replays
  historical ii-a evidence and runs semantic/scope mutation negatives.
- `scripts/verify-investigation-boundaries` passed, including the exact C
  object export/import allowlist and authority-closed SwiftPM Debug/Release
  Machine Driver binaries.
- `scripts/verify-app-release-boundaries` passed, including ordinary and
  diagnostic App Debug/Release bundle and final-Mach-O projections.
- The final post-fix serial regression passed 1,374 tests in 71 suites with
  zero failures in 128.074 seconds (`131.38` seconds wall time). Twelve explicit
  opt-in machine/model/Trash/capacity diagnostics were skipped as designed.
- `git diff --cached --check` passed, and the final staged tree remained
  `83c5880d21e8e5b5a6e4a6c03ae2c6d2700e8ecd` throughout the final funnel.

`scripts/verify --full` was deliberately not run. This is a bounded,
non-admitting implementation checkpoint; L3c4 alone owns Task 39's remaining
authoritative full verifier.

## 4. Review Closure

Implementation review found no P0-P2 defect. Verifier review found one P1
false-green window: the original gate sealed the C cross-source comparison and
symbol projections but not the final `completed_snapshot` field mapping. The
review reproduced the defect by mapping process-group ID to process ID; the old
contract incorrectly exited zero, and a normal new-session PID-equals-PGID
fixture could conceal that regression.

The repair was tests-first. `c-output-pgid` and `c-output-effective-uid`
behavior-only mutations first failed with `mutation accepted`, then the gate
added exact C/header staged-source seals while retaining the independent C
object import/export allowlist. Both mapping mutations now fail with
`C snapshot output mapping drifted`; a `chmod` authority mutation still fails
separately with `C object import drifted`. Two independent post-fix verifier
reviews and one cross-group ABI/source/test/verifier review report no unresolved
P0-P2 findings.

The generated review artifacts are retained outside the repository at
`/tmp/stornaut_iib5biib_final_review.CIRVQ8/report.html` and `report.md`.

## 5. Completion Checklist

| Requirement | Concrete evidence | Result |
| --- | --- | --- |
| Independent pre/post-drop App identity | C three-source snapshot and Swift observer in implementation tree | complete |
| Same-PID exec / PID-version TOCTOU closure | initial/final narrow sandwich plus negative tests | complete |
| Fixed path/hash/static/live signing | descriptor/signing sandwich and focused mutations | complete |
| UID/GID/groups/audit-token completeness | complete snapshot fields and all-axis tests | complete |
| Fail-closed error semantics | dedicated mismatch status and phase-exact mappings | complete |
| No authority expansion | source denylist, C object allowlist and four final-Mach-O projections | complete |
| Exact scope/cost | 9 non-document paths / 2,790 changed lines | complete |
| Regression and independent review | 42 focused, contract, both binary gates, 1,374 serial, zero P0-P2 | complete |

## 6. Non-Claims and Next Step

This checkpoint did not run as root, install or launch the signed App/helper,
invoke real XPC, read Codex authentication, access a network or call a model.
It does not prove the FD-7 duplex session, owned-PGID retirement, production
composition, privileged installed-driver gate or machine readiness. ADR 0018
remains Proposed, Task 39 remains incomplete and production Deep Dive remains
`.implementationUnavailable`.

The next checkpoint is ii-b5b-ii-c fixed FD-7 spawn and bounded duplex session,
followed by ii-b5b-ii-d exact owned-PGID retirement, ii-b5b-iii production/
artifact composition, ii-c0, the one no-model privileged ii-c gate, L3c3d
authenticated success and L3c4 final admission.
